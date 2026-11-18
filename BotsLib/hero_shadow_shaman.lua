-- Shadow Shaman: skill build, item build, and ability use for this hero.
-- Accidental globals made file-local (#13): every bot shares one Lua state, so these were shared.
local botTarget
local X = {}
local bot = GetBot()
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local AbilityContext = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local Minion = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local sTalentList = Fu.Skill.GetTalentList(bot)
local sAbilityList = Fu.Skill.GetAbilityList(bot)
local sRole = Fu.Item.GetRoleItemsBuyList(bot)
local tTalentTreeList = { ["t25"] = { 10, 0 }, ["t20"] = { 0, 10 }, ["t15"] = { 10, 0 }, ["t10"] = { 10, 0 } }
local tAllAbilityBuildList = { { 3, 1, 3, 2, 3, 6, 3, 2, 2, 2, 6, 1, 1, 1, 6 } }
local nAbilityBuildList = Fu.Skill.GetRandomBuild(tAllAbilityBuildList)
local nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList)
local sRoleItemsBuyList = {}
sRoleItemsBuyList["pos_4"] = {
	"item_tango",
	"item_double_branches",
	"item_faerie_fire",
	"item_blood_grenade",
	"item_magic_wand",
	"item_arcane_boots",
	"item_blink",
	"item_aghanims_shard",
	"item_glimmer_cape",
	"item_ultimate_scepter",
	"item_aether_lens",
	"item_octarine_core",
	"item_black_king_bar",
	"item_refresher",
	"item_ultimate_scepter_2",
	"item_moon_shard",
}
sRoleItemsBuyList["pos_5"] = {
	"item_tango",
	"item_double_branches",
	"item_faerie_fire",
	"item_blood_grenade",
	"item_magic_wand",
	"item_arcane_boots",
	"item_blink",
	"item_aghanims_shard",
	"item_glimmer_cape",
	"item_ultimate_scepter",
	"item_force_staff",
	"item_aether_lens",
	"item_octarine_core",
	"item_refresher",
	"item_ultimate_scepter_2",
	"item_moon_shard",
}
sRoleItemsBuyList["pos_1"] = {
	"item_crystal_maiden_outfit",
	"item_aghanims_shard",
	"item_ultimate_scepter",
	"item_glimmer_cape",
	"item_force_staff",
	"item_cyclone",
	"item_sheepstick",
	"item_wind_waker",
	"item_moon_shard",
	"item_ultimate_scepter_2",
	"item_refresher",
}
sRoleItemsBuyList["pos_2"] = sRoleItemsBuyList["pos_1"]
sRoleItemsBuyList["pos_3"] = sRoleItemsBuyList["pos_1"]
X["sBuyList"] = sRoleItemsBuyList[sRole]
X["sSellList"] = { "item_cyclone", "item_magic_wand", "item_ultimate_scepter", "item_magic_wand" }
if Fu.Role.IsPvNMode() or Fu.Role.IsAllShadow() then
	X["sBuyList"], X["sSellList"] = { "PvN_mage" }, {}
end
nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"] =
	Fu.SetUserHeroInit(nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"])
X["sSkillList"] = Fu.Skill.GetSkillList(sAbilityList, nAbilityBuildList, sTalentList, nTalentBuildList)
X["bDeafaultAbility"] = false
-- Cast when cornered (retreating into 3+ enemies with no way out), before running further.
X["LastStandSpells"] = { { name = "shadow_shaman_voodoo", kind = "unit" } }
X["bDeafaultItem"] = true
function X.MinionThink(hMinionUnit)
	Minion.MinionThink(hMinionUnit)
end
local etherShockAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[1]), "sAbilityList[1]", "shadow_shaman")
local hexAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[2]), "sAbilityList[2]", "shadow_shaman")
local shacklesAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[3]), "sAbilityList[3]", "shadow_shaman")
local serpentWardAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[6]), "sAbilityList[6]", "shadow_shaman")
local urnacondaAbility =
	SafeAbility(bot:GetAbilityByName("shadow_shaman_urnaconda"), "shadow_shaman_urnaconda", "shadow_shaman")
local talent3 = SafeAbility(bot:GetAbilityByName(sTalentList[3]), "sTalentList[3]", "shadow_shaman")
local talent7 = SafeAbility(bot:GetAbilityByName(sTalentList[7]), "sTalentList[7]", "shadow_shaman")
local etherShockDesire, etherShockTarget
local hexDesire, hexTarget
local shacklesDesire, shacklesTarget
local serpentWardDesire, serpentWardLocation
local urnacondaDesire, urnacondaLocation
local aetherRange = 0
local bonusDamage = 0
local isAttacking
local botLevel, mpRatio, hpRatio, nearbyEnemies, nearbyAllies
function X.SkillsComplement()
	if Fu.CanNotUseAbility(bot) or bot:IsInvisible() then
		return
	end
	isAttacking = Fu.IsAttacking(bot)
	local context = AbilityContext.Build(bot)
	aetherRange = context.aetherRange
	bonusDamage = 0
	botLevel = context.level
	mpRatio = context.mp
	hpRatio = context.hp
	botTarget = context.target
	nearbyEnemies = context.enemies
	nearbyAllies = context.allies
	if talent7:IsTrained() then
		bonusDamage = talent7:GetSpecialValueInt("value")
	end
	hexDesire, hexTarget = X.ConsiderW()
	if hexDesire > 0 then
		Fu.SetQueuePtToINT(bot, true)
		bot:ActionQueue_UseAbilityOnEntity(hexAbility, hexTarget)
		return
	end
	urnacondaDesire, urnacondaLocation = X.ConsiderUrnaconda()
	if urnacondaDesire > 0 then
		Fu.SetQueuePtToINT(bot, true)
		bot:ActionQueue_UseAbilityOnLocation(urnacondaAbility, urnacondaLocation)
		return
	end
	serpentWardDesire, serpentWardLocation = X.ConsiderR()
	if serpentWardDesire > 0 then
		Fu.SetQueuePtToINT(bot, true)
		bot:ActionQueue_UseAbilityOnLocation(serpentWardAbility, serpentWardLocation)
		return
	end
	etherShockDesire, etherShockTarget = X.ConsiderQ()
	if etherShockDesire > 0 then
		Fu.SetQueuePtToINT(bot, true)
		bot:ActionQueue_UseAbilityOnEntity(etherShockAbility, etherShockTarget)
		return
	end
	shacklesDesire, shacklesTarget = X.ConsiderE()
	if shacklesDesire > 0 then
		Fu.SetQueuePtToINT(bot, true)
		bot:ActionQueue_UseAbilityOnEntity(shacklesAbility, shacklesTarget)
		return
	end
end
function X.ConsiderQ()
	if not etherShockAbility:IsFullyCastable() then
		return 0
	end
	local abilityLevel = etherShockAbility:GetLevel()
	local castRange = etherShockAbility:GetCastRange()
	local castPoint = etherShockAbility:GetCastPoint()
	local manaCost = etherShockAbility:GetManaCost()
	local damage = etherShockAbility:GetSpecialValueInt("damage") + bonusDamage
	local damageType = DAMAGE_TYPE_MAGICAL
	local enemiesInRange = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	local enemiesInWideRange = Fu.GetNearbyHeroes(bot, castRange + 220, true, BOT_MODE_NONE)
	-- Ether Shock is only worth walking into when it kills. Otherwise stay at range.
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidHero(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.CanCastOnTargetAdvanced(botTarget)
			and (Fu.WillMagicKillTarget(bot, botTarget, damage, castPoint) or Fu.GetHP(botTarget) < 0.3)
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget, "Q-attack:" .. Fu.Chat.GetNormName(botTarget)
		end
	end
	for _, enemy in pairs(enemiesInWideRange) do
		if
			Fu.IsValid(enemy)
			and Fu.CanCastOnNonMagicImmune(enemy)
			and Fu.CanCastOnTargetAdvanced(enemy)
			and Fu.WillMagicKillTarget(bot, enemy, damage, castPoint)
		then
			return BOT_ACTION_DESIRE_HIGH, enemy, "Q-kill" .. Fu.Chat.GetNormName(enemy)
		end
	end
	if Fu.IsInTeamFight(bot, 1200) and botLevel >= 5 then
		local weakestEnemy = nil
		local lowestHealth = 9999
		for _, enemy in pairs(enemiesInRange) do
			if Fu.IsValid(enemy) and Fu.CanCastOnNonMagicImmune(enemy) and Fu.CanCastOnTargetAdvanced(enemy) then
				local health = enemy:GetHealth()
				if health < lowestHealth then
					lowestHealth = health
					weakestEnemy = enemy
				end
			end
		end
		if weakestEnemy ~= nil then
			return BOT_ACTION_DESIRE_HIGH, weakestEnemy, "Q-Battle-Weakest:" .. Fu.Chat.GetNormName(weakestEnemy)
		end
	end
	if Fu.IsRetreating(bot) then
		for _, enemy in pairs(enemiesInRange) do
			if
				Fu.IsValidHero(enemy)
				and (bot:WasRecentlyDamagedByHero(enemy, 4.0) or mpRatio > 0.68 or GetUnitToUnitDistance(bot, enemy) <= 400)
				and Fu.CanCastOnNonMagicImmune(enemy)
				and Fu.CanCastOnTargetAdvanced(enemy)
				and bot:IsFacingLocation(enemy:GetLocation(), 30)
			then
				return BOT_ACTION_DESIRE_HIGH, enemy, "Q-Retreat:" .. Fu.Chat.GetNormName(enemy)
			end
		end
	end
	if Fu.IsLaning(bot) then
		if mpRatio > 0.5 then
			for _, enemy in pairs(enemiesInRange) do
				if
					Fu.IsValid(enemy)
					and Fu.CanCastOnNonMagicImmune(enemy)
					and Fu.CanCastOnTargetAdvanced(enemy)
					and Fu.GetAttackEnemysAllyCreepCount(enemy, 1400) >= 3
				then
					return BOT_ACTION_DESIRE_HIGH, enemy, "Q-Laning:" .. Fu.Chat.GetNormName(enemy)
				end
			end
		end
		if #nearbyAllies <= 1 or Fu.IsCore(bot) then
			local laneCreeps = bot:GetNearbyLaneCreeps(800, true)
			for _, creep in pairs(laneCreeps) do
				if
					Fu.IsValid(creep)
					and not creep:HasModifier("modifier_fountain_glyph")
					and not Fu.IsAllysTarget(creep)
				then
					if
						Fu.IsKeyWordUnit("ranged", creep) and Fu.WillKillTarget(creep, damage, damageType, castPoint)
					then
						return BOT_ACTION_DESIRE_HIGH, creep, "Q-LaneRanged"
					end
					if
						bot:GetMana() > 320
						and Fu.IsKeyWordUnit("melee", creep)
						and Fu.WillKillTarget(creep, damage, damageType, castPoint)
						and not Fu.WillKillTarget(creep, damage * 0.5, damageType, castPoint)
					then
						return BOT_ACTION_DESIRE_HIGH, creep, "Q-LaneMelee"
					end
				end
			end
		end
	end
	if
		(Fu.IsPushing(bot) or Fu.IsDefending(bot) or Fu.IsFarming(bot))
		and Fu.IsAllowedToSpam(bot, 30)
		and abilityLevel >= 3
		and #nearbyEnemies == 0
		and #nearbyAllies <= 3
	then
		local laneCreeps = bot:GetNearbyLaneCreeps(999, true)
		local allyLaneCreeps = bot:GetNearbyLaneCreeps(888, false)
		for _, creep in pairs(laneCreeps) do
			if
				Fu.IsValid(creep)
				and not creep:HasModifier("modifier_fountain_glyph")
				and Fu.IsInRange(creep, bot, castRange + 300)
			then
				if #allyLaneCreeps == 0 and Fu.GetAroundTargetEnemyUnitCount(creep, 380) >= 2 and #laneCreeps >= 4 then
					return BOT_ACTION_DESIRE_HIGH, creep, "Q-PushAoe"
				end
				if Fu.IsKeyWordUnit("ranged", creep) and Fu.WillKillTarget(creep, damage, damageType, castPoint) then
					return BOT_ACTION_DESIRE_HIGH, creep, "Q-PushRanged"
				end
				if
					Fu.IsKeyWordUnit("melee", creep)
					and Fu.WillKillTarget(creep, damage, damageType, castPoint)
					and (Fu.GetAroundTargetEnemyUnitCount(creep, 380) >= 2 or mpRatio > 0.8)
				then
					return BOT_ACTION_DESIRE_HIGH, creep, "Q-PushMelee"
				end
			end
		end
	end
	if
		Fu.IsFarming(bot)
		and abilityLevel >= 3
		and Fu.IsAllowedToSpam(bot, manaCost)
		and #nearbyEnemies == 0
		and #nearbyAllies <= 2
		and not (Fu.IsPushing(bot) or Fu.IsDefending(bot))
	then
		local neutralCreeps = bot:GetNearbyNeutralCreeps(castRange + 200)
		if #neutralCreeps >= 2 or mpRatio >= 0.5 then
			local neutralCreep = neutralCreeps[1]
			if
				Fu.IsValid(neutralCreep)
				and bot:IsFacingLocation(neutralCreep:GetLocation(), 30)
				and neutralCreep:GetHealth() >= 500
				and neutralCreep:GetMagicResist() < 0.3
				and Fu.GetAroundTargetEnemyUnitCount(neutralCreep, 300) >= 2
			then
				return BOT_ACTION_DESIRE_HIGH, neutralCreep, "Q-Farm:" .. #neutralCreeps
			end
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if
			Fu.IsRoshan(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and Fu.CanBeAttacked(botTarget)
			and isAttacking
			and not botTarget:HasModifier("modifier_roshan_spell_block")
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget, ""
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, castRange) and isAttacking then
			return BOT_ACTION_DESIRE_HIGH, botTarget, ""
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderW()
	if not hexAbility:IsFullyCastable() then
		return 0
	end
	local abilityLevel = hexAbility:GetLevel()
	local castRange = hexAbility:GetCastRange() + aetherRange
	local castPoint = hexAbility:GetCastPoint()
	local manaCost = hexAbility:GetManaCost()
	local damage = hexAbility:GetAbilityDamage()
	local damageType = DAMAGE_TYPE_MAGICAL
	local enemiesInRange = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	local enemiesInWideRange = Fu.GetNearbyHeroes(bot, castRange + 240, true, BOT_MODE_NONE)
	-- Hex from the back of its range. Closing in just to land it walks him into the fight.
	local hexRange = math.max(200, castRange - 150)
	for _, enemy in pairs(enemiesInWideRange) do
		if Fu.IsValidHero(enemy) and Fu.CanCastOnTargetAdvanced(enemy) and Fu.CanCastOnNonMagicImmune(enemy) then
			if enemy:IsChanneling() then
				return BOT_ACTION_DESIRE_HIGH, enemy, "W-Check1:" .. Fu.Chat.GetNormName(enemy)
			end
			if enemy:IsCastingAbility() and Fu.IsInRange(bot, enemy, castRange + 50) then
				return BOT_ACTION_DESIRE_HIGH, enemy, "W-Check2:" .. Fu.Chat.GetNormName(enemy)
			end
		end
	end
	if Fu.IsInTeamFight(bot, 1200) and (#enemiesInWideRange >= 2 or #nearbyAllies >= 3) then
		local strongestEnemy = nil
		local maxDamage = 0
		for _, enemy in pairs(enemiesInWideRange) do
			if
				Fu.IsValid(enemy)
				and Fu.CanCastOnNonMagicImmune(enemy)
				and Fu.CanCastOnTargetAdvanced(enemy)
				and not Fu.IsDisabled(enemy)
				and not Fu.IsTaunted(enemy)
				and not enemy:IsDisarmed()
			then
				local estimatedDamage = enemy:GetEstimatedDamageToTarget(false, bot, 3.0, DAMAGE_TYPE_PHYSICAL)
				if estimatedDamage > maxDamage then
					maxDamage = estimatedDamage
					strongestEnemy = enemy
				end
			end
		end
		if strongestEnemy ~= nil and Fu.IsInRange(bot, strongestEnemy, hexRange) then
			return BOT_ACTION_DESIRE_HIGH, strongestEnemy, "W-Battle:" .. Fu.Chat.GetNormName(strongestEnemy)
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidHero(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.CanCastOnTargetAdvanced(botTarget)
			and Fu.IsInRange(bot, botTarget, hexRange)
			and not Fu.IsDisabled(botTarget)
			and not Fu.IsTaunted(botTarget)
			and not botTarget:IsDisarmed()
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget, "W-Attack:" .. Fu.Chat.GetNormName(botTarget)
		end
	end
	if
		bot:WasRecentlyDamagedByAnyHero(3.0)
		and botLevel >= 10
		and bot:GetActiveMode() ~= BOT_MODE_RETREAT
		and #enemiesInRange >= 1
	then
		for _, enemy in pairs(enemiesInRange) do
			if
				Fu.IsValid(enemy)
				and Fu.CanCastOnNonMagicImmune(enemy)
				and Fu.CanCastOnTargetAdvanced(enemy)
				and not Fu.IsDisabled(enemy)
				and not Fu.IsTaunted(enemy)
				and not enemy:IsDisarmed()
			then
				return BOT_ACTION_DESIRE_HIGH, enemy, "W-protect"
			end
		end
	end
	if Fu.IsRetreating(bot) then
		for _, enemy in pairs(enemiesInRange) do
			if
				Fu.IsValidHero(enemy)
				and (bot:WasRecentlyDamagedByHero(enemy, 4.0) or GetUnitToUnitDistance(bot, enemy) <= 500)
				and Fu.CanCastOnNonMagicImmune(enemy)
				and Fu.CanCastOnTargetAdvanced(enemy)
				and not Fu.IsDisabled(enemy)
				and not Fu.IsTaunted(enemy)
				and not enemy:IsDisarmed()
			then
				return BOT_ACTION_DESIRE_HIGH, enemy, "W-Retreat:" .. Fu.Chat.GetNormName(enemy)
			end
		end
	end
	if Fu.IsDoingRoshan(bot) and mpRatio > 0.6 then
		if
			Fu.IsRoshan(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and not Fu.IsDisabled(botTarget)
			and not botTarget:IsDisarmed()
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget, "W-Roshan"
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, castRange) and isAttacking then
			return BOT_ACTION_DESIRE_HIGH, botTarget, ""
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderE()
	if not shacklesAbility:IsFullyCastable() then
		return 0
	end
	local abilityLevel = shacklesAbility:GetLevel()
	local castRange = shacklesAbility:GetCastRange() + aetherRange
	local castPoint = shacklesAbility:GetCastPoint()
	local manaCost = shacklesAbility:GetManaCost()
	local damage = abilityLevel * 100 - 40 + bot:GetAttackDamage() * 2
	local damageType = DAMAGE_TYPE_MAGICAL
	local enemiesInRange = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	local enemiesInWideRange = Fu.GetNearbyHeroes(bot, castRange + 240, true, BOT_MODE_NONE)
	-- Shackles roots him for the whole channel, so only start it with a clear way out.
	local shackleRange = math.max(200, castRange - 150)
	for _, enemy in pairs(enemiesInWideRange) do
		if Fu.IsValidHero(enemy) and Fu.CanCastOnTargetAdvanced(enemy) and Fu.CanCastOnNonMagicImmune(enemy) then
			if enemy:IsChanneling() then
				return BOT_ACTION_DESIRE_HIGH, enemy, "E-Check1:" .. Fu.Chat.GetNormName(enemy)
			end
			if #nearbyAllies >= 2 and enemy:IsCastingAbility() and Fu.IsInRange(bot, enemy, castRange + 30) then
				return BOT_ACTION_DESIRE_HIGH, enemy, "E-Check2:" .. Fu.Chat.GetNormName(enemy)
			end
		end
	end
	if Fu.IsInTeamFight(bot, 1200) and botLevel >= 5 then
		local strongestEnemy = nil
		local maxDamage = 0
		for _, enemy in pairs(enemiesInWideRange) do
			if
				Fu.IsValid(enemy)
				and Fu.CanCastOnNonMagicImmune(enemy)
				and not Fu.IsDisabled(enemy)
				and not Fu.IsTaunted(enemy)
				and not enemy:IsDisarmed()
			then
				local estimatedDamage = enemy:GetEstimatedDamageToTarget(false, bot, 3.0, DAMAGE_TYPE_PHYSICAL)
				if estimatedDamage > maxDamage then
					maxDamage = estimatedDamage
					strongestEnemy = enemy
				end
			end
		end
		if strongestEnemy ~= nil and Fu.IsInRange(bot, strongestEnemy, shackleRange) then
			return BOT_ACTION_DESIRE_HIGH, strongestEnemy, "E-Battle:" .. Fu.Chat.GetNormName(strongestEnemy)
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidHero(botTarget)
			and Fu.IsInRange(bot, botTarget, shackleRange)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.CanCastOnTargetAdvanced(botTarget)
			and not Fu.IsDisabled(botTarget)
			and not Fu.IsTaunted(botTarget)
			and not botTarget:IsDisarmed()
		then
			if abilityLevel >= 2 or mpRatio > 0.68 or Fu.GetHP(botTarget) < 0.35 or hpRatio < 0.28 then
				return BOT_ACTION_DESIRE_HIGH, botTarget, "E-Attack:" .. Fu.Chat.GetNormName(botTarget)
			end
		end
	end
	if Fu.IsRetreating(bot) and abilityLevel >= 3 and #nearbyEnemies == 1 and #nearbyAllies >= 2 then
		for _, enemy in pairs(enemiesInRange) do
			if
				Fu.IsValidHero(enemy)
				and Fu.CanCastOnNonMagicImmune(enemy)
				and Fu.CanCastOnTargetAdvanced(enemy)
				and not Fu.IsDisabled(enemy)
				and not Fu.IsTaunted(enemy)
				and not enemy:IsDisarmed()
			then
				return BOT_ACTION_DESIRE_HIGH, enemy, "E-Retreat:" .. Fu.Chat.GetNormName(enemy)
			end
		end
	end
	if bot:GetActiveMode() == BOT_MODE_ROSHAN and bot:GetMana() >= 800 then
		if
			Fu.IsRoshan(botTarget)
			and Fu.GetHP(botTarget) > 0.2
			and Fu.IsInRange(bot, botTarget, castRange + 100)
			and not Fu.IsDisabled(botTarget)
			and not botTarget:IsDisarmed()
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderR()
	if not serpentWardAbility:IsFullyCastable() then
		return 0
	end
	local abilityLevel = serpentWardAbility:GetLevel()
	local castRange = serpentWardAbility:GetCastRange() + aetherRange + 100
	local radius = 150
	local castPoint = serpentWardAbility:GetCastPoint()
	local manaCost = serpentWardAbility:GetManaCost()
	local damage = serpentWardAbility:GetAbilityDamage()
	local damageType = DAMAGE_TYPE_MAGICAL
	local enemiesInRange = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	local castLocation = nil
	if Fu.IsGoingOnSomeone(bot) then
		local aoeLocation = Fu.GetAoeEnemyHeroLocation(bot, castRange + 100, radius, 2)
		if aoeLocation ~= nil then
			castLocation = aoeLocation
			return BOT_ACTION_DESIRE_HIGH, castLocation, "R-Aoe"
		end
		if
			Fu.IsValidHero(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and Fu.CanCastOnMagicImmune(botTarget)
			and botTarget:GetHealth() > bot:GetAttackDamage() * 3
		then
			castLocation = botTarget:GetExtrapolatedLocation(castPoint)
			return BOT_ACTION_DESIRE_HIGH, castLocation, "R-Attack:" .. Fu.Chat.GetNormName(botTarget)
		end
	end
	if Fu.IsRetreating(bot) then
		for _, enemy in pairs(enemiesInRange) do
			if
				Fu.IsValidHero(enemy)
				and Fu.CanCastOnMagicImmune(enemy)
				and bot:WasRecentlyDamagedByHero(enemy, 3.0)
			then
				castLocation = enemy:GetExtrapolatedLocation(castPoint)
				return BOT_ACTION_DESIRE_HIGH, castLocation, "R-Retreat:" .. Fu.Chat.GetNormName(enemy)
			end
		end
	end
	if Fu.IsPushing(bot) then
		local enemyTowers = bot:GetNearbyTowers(1100, true)
		local enemyBarracks = bot:GetNearbyBarracks(1100, true)
		local enemyAncient = GetAncient(GetOpposingTeam())
		local buildings = { enemyTowers[1], enemyBarracks[1], enemyAncient }
		for _, building in pairs(buildings) do
			if
				Fu.IsValidBuilding(building)
				and Fu.IsInRange(bot, building, castRange + 500)
				and not building:HasModifier("modifier_fountain_glyph")
				and not building:HasModifier("modifier_invulnerable")
				and not building:HasModifier("modifier_backdoor_protection")
			then
				castLocation = Fu.GetUnitTowardDistanceLocation(building, bot, 240)
				if GetUnitToLocationDistance(bot, castLocation) < 180 then
					castLocation = Fu.GetUnitTowardDistanceLocation(bot, building, 240)
				end
				if castLocation ~= nil then
					return BOT_ACTION_DESIRE_HIGH, castLocation, "R-Pushing"
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderUrnaconda()
	if not Fu.CanCastAbility(urnacondaAbility) then
		return BOT_ACTION_DESIRE_NONE
	end
	local castRange = urnacondaAbility:GetCastRange()
	local castPoint = urnacondaAbility:GetCastPoint()
	local damage = urnacondaAbility:GetSpecialValueInt("impact_damage")
	local speed = urnacondaAbility:GetSpecialValueInt("speed")
	local radius = urnacondaAbility:GetSpecialValueInt("impact_radius")
	local manaCost = urnacondaAbility:GetManaCost()
	local manaAfter = Fu.GetManaAfter(manaCost)
	local manaThreshold =
		Fu.GetManaThreshold(bot, manaCost, { etherShockAbility, hexAbility, shacklesAbility, serpentWardAbility })
	local enemyHeroes = bot:GetNearbyHeroes(castRange + 300, true, BOT_MODE_NONE)
	local allyHeroes = bot:GetNearbyHeroes(1600, false, BOT_MODE_NONE)
	for _, enemy in pairs(enemyHeroes) do
		if
			Fu.IsValidHero(enemy)
			and Fu.CanBeAttacked(enemy)
			and Fu.IsInRange(bot, enemy, castRange + 300)
			and not Fu.IsInRange(bot, enemy, 300)
			and Fu.CanCastOnNonMagicImmune(enemy)
			and not Fu.IsChasingTarget(bot, enemy)
			and not enemy:HasModifier("modifier_abaddon_borrowed_time")
			and not enemy:HasModifier("modifier_dazzle_shallow_grave")
			and not enemy:HasModifier("modifier_oracle_false_promise_timer")
			and not enemy:HasModifier("modifier_templar_assassin_refraction_absorb")
		then
			local hitDelay = GetUnitToUnitDistance(bot, enemy) / speed + castPoint
			if Fu.WillKillTarget(enemy, damage, DAMAGE_TYPE_MAGICAL, hitDelay) then
				return BOT_ACTION_DESIRE_HIGH, enemy:GetLocation()
			end
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidHero(botTarget)
			and Fu.CanBeAttacked(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange + 300)
			and not Fu.IsChasingTarget(bot, botTarget)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not botTarget:HasModifier("modifier_abaddon_borrowed_time")
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			if
				Fu.IsDisabled(botTarget)
					and not (botTarget:HasModifier("modifier_enigma_black_hole_pull") or botTarget:HasModifier(
						"modifier_faceless_void_chronosphere_freeze"
					))
				or botTarget:GetCurrentMovementSpeed() <= 250
			then
				if Fu.GetHP(botTarget) > 0.4 then
					if Fu.GetTotalEstimatedDamageToTarget(allyHeroes, botTarget, 8.0) > botTarget:GetHealth() then
						return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
					end
				end
			end
			if Fu.IsInTeamFight(bot, 1200) then
				return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
			end
		end
	end
	if
		Fu.IsRetreating(bot)
		and not Fu.IsRealInvisible(bot)
		and not Fu.CanCastAbilitySoon(hexAbility, 5.0)
		and not Fu.IsInTeamFight(bot, 1200)
		and Fu.IsRunning(bot)
	then
		for _, enemy in pairs(enemyHeroes) do
			if
				Fu.IsValidHero(enemy)
				and Fu.CanBeAttacked(enemy)
				and Fu.IsInRange(bot, enemy, castRange)
				and not Fu.IsInRange(bot, enemy, radius)
				and not Fu.IsSuspiciousIllusion(enemy)
				and not Fu.IsDisabled(enemy)
				and Fu.IsChasingTarget(enemy, bot)
				and bot:WasRecentlyDamagedByHero(enemy, 3.0)
			then
				return BOT_ACTION_DESIRE_HIGH, bot:GetLocation()
			end
		end
	end
	if Fu.IsPushing(bot) and #allyHeroes >= #enemyHeroes and manaAfter > manaThreshold then
		local searchRange = Min(castRange + bot:GetAttackRange(), 1600)
		local enemyTowers = bot:GetNearbyTowers(searchRange, true)
		local enemyBarracks = bot:GetNearbyBarracks(searchRange, true)
		local enemyAncient = GetAncient(GetOpposingTeam())
		local alliesNearby = Fu.GetAlliesNearLoc(bot:GetLocation(), 800)
		local targets = { botTarget, enemyTowers[1], enemyBarracks[1], enemyAncient }
		for _, building in pairs(targets) do
			if
				Fu.IsValidBuilding(building)
				and Fu.CanBeAttacked(building)
				and Fu.IsInRange(bot, building, castRange + bot:GetAttackRange())
				and not Fu.IsKeyWordUnit("DOTA_Outpost", building)
			then
				local unitName = building:GetUnitName()
				if #alliesNearby <= 3 or string.find(unitName, "barracks") or building == enemyAncient then
					if building:GetHealthRegen() == 0 or bot:GetAttackTarget() == building then
						return BOT_ACTION_DESIRE_HIGH,
							Fu.VectorTowards(building:GetLocation(), bot:GetLocation(), radius)
					end
				end
			end
		end
	end
	local enemyCreeps = bot:GetNearbyCreeps(Min(castRange + 300, 1600), true)
	if Fu.IsFarming(bot) and isAttacking and manaAfter > manaThreshold + 0.1 and #allyHeroes <= 1 then
		for _, creep in pairs(enemyCreeps) do
			if Fu.IsValid(creep) and Fu.CanBeAttacked(creep) then
				local aoe = bot:FindAoELocation(true, false, creep:GetLocation(), 0, radius, 0, 0)
				if
					aoe.count >= 3
					or aoe.count >= 2 and creep:IsAncientCreep()
					or aoe.count >= 1 and creep:GetHealth() >= 1000
				then
					return BOT_ACTION_DESIRE_HIGH, aoe.targetloc
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
return X
