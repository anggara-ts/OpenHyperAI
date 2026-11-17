-- Queenofpain: skill build, item build, and ability use for this hero.
local X = {}
local bot = GetBot()
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local AbilityContext = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local Minion = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local sTalentList = Fu.Skill.GetTalentList(bot)
local sAbilityList = Fu.Skill.GetAbilityList(bot)
local sRole = Fu.Item.GetRoleItemsBuyList(bot)
local tTalentTreeList = { ["t25"] = { 0, 10 }, ["t20"] = { 0, 10 }, ["t15"] = { 10, 0 }, ["t10"] = { 0, 10 } }
local tAllAbilityBuildList = { { 3, 1, 1, 2, 3, 6, 3, 3, 2, 2, 6, 2, 1, 1, 6 } }
local nAbilityBuildList = Fu.Skill.GetRandomBuild(tAllAbilityBuildList)
local nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList)
local sRoleItemsBuyList = {}
sRoleItemsBuyList["pos_2"] = {
	"item_tango",
	"item_double_branches",
	"item_faerie_fire",
	"item_null_talisman",
	"item_bottle",
	"item_magic_wand",
	"item_null_talisman",
	"item_boots",
	"item_power_treads",
	"item_witch_blade",
	-- Shard right after Witch Blade, before Kaya and Sange (user call).
	"item_aghanims_shard",
	"item_kaya_and_sange",
	"item_ultimate_scepter",
	"item_black_king_bar",
	"item_shivas_guard",
	"item_travel_boots",
	"item_devastator",
	"item_cyclone",
	"item_ultimate_scepter_2",
	"item_moon_shard",
	"item_wind_waker",
	"item_travel_boots_2",
}
sRoleItemsBuyList["pos_1"] = {
	"item_tango",
	"item_double_branches",
	"item_magic_wand",
	"item_boots",
	"item_power_treads",
	"item_witch_blade",
	-- Shard right after Witch Blade, before Kaya and Sange (user call).
	"item_aghanims_shard",
	"item_kaya_and_sange",
	"item_ultimate_scepter",
	"item_black_king_bar",
	"item_shivas_guard",
	"item_travel_boots",
	"item_devastator",
	"item_cyclone",
	"item_ultimate_scepter_2",
	"item_moon_shard",
	"item_wind_waker",
	"item_travel_boots_2",
}
sRoleItemsBuyList["pos_3"] = sRoleItemsBuyList["pos_1"]
sRoleItemsBuyList["pos_4"] = {
	"item_tango",
	"item_tango",
	"item_double_branches",
	"item_enchanted_mango",
	"item_blood_grenade",
	"item_magic_wand",
	"item_boots",
	"item_arcane_boots",
	"item_glimmer_cape",
	"item_aether_lens",
	"item_aghanims_shard",
	"item_force_staff",
	"item_guardian_greaves",
	"item_cyclone",
	"item_lotus_orb",
	"item_gungir",
	"item_moon_shard",
	"item_wind_waker",
	"item_ultimate_scepter_2",
}
sRoleItemsBuyList["pos_5"] = {
	"item_tango",
	"item_tango",
	"item_double_branches",
	"item_enchanted_mango",
	"item_blood_grenade",
	"item_magic_wand",
	"item_boots",
	"item_tranquil_boots",
	"item_glimmer_cape",
	"item_pipe",
	"item_aether_lens",
	"item_aghanims_shard",
	"item_force_staff",
	"item_boots_of_bearing",
	"item_cyclone",
	"item_gungir",
	"item_moon_shard",
	"item_wind_waker",
	"item_ultimate_scepter_2",
}
X["sBuyList"] = sRoleItemsBuyList[sRole]
X["sSellList"] = { "item_black_king_bar", "item_null_talisman" }
if Fu.Role.IsPvNMode() or Fu.Role.IsAllShadow() then
	X["sBuyList"], X["sSellList"] = { "PvN_mage" }, {}
end
nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"] =
	Fu.SetUserHeroInit(nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"])
X["sSkillList"] = Fu.Skill.GetSkillList(sAbilityList, nAbilityBuildList, sTalentList, nTalentBuildList)
X["bDeafaultAbility"] = false
-- Cast when cornered (retreating into 3+ enemies with no way out), before running further.
X["LastStandSpells"] = { { name = "queenofpain_sonic_wave", kind = "point" } }
X["bDeafaultItem"] = true
function X.MinionThink(minionUnit)
	if Minion.IsValidUnit(minionUnit) then
		Minion.IllusionThink(minionUnit)
	end
end
local shadowStrikeAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[1]), "sAbilityList[1]", "queenofpain")
local blinkAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[2]), "sAbilityList[2]", "queenofpain")
local screamOfPainAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[3]), "sAbilityList[3]", "queenofpain")
local sonicWaveAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[6]), "sAbilityList[6]", "queenofpain")
local talent6 = SafeAbility(bot:GetAbilityByName(sTalentList[6]), "sTalentList[6]", "queenofpain")
local shadowStrikeDesire, shadowStrikeTarget
local blinkDesire, blinkLocation
local screamOfPainDesire
local sonicWaveDesire, sonicWaveLocation
local isAttacking
local botLevel, mpRatio, hpRatio, nearbyEnemies, nearbyAllies
function X.SkillsComplement()
	if Fu.CanNotUseAbility(bot) or bot:IsInvisible() then
		return
	end
	isAttacking = Fu.IsAttacking(bot)
	local context = AbilityContext.Build(bot)
	botLevel = context.level
	mpRatio = context.mp
	hpRatio = context.hp
	botTarget = context.target
	nearbyEnemies = context.enemies
	nearbyAllies = context.allies
	blinkDesire, blinkLocation = X.ConsiderW()
	if blinkDesire > 0 then
		Fu.SetQueuePtToINT(bot, true)
		bot:ActionQueue_UseAbilityOnLocation(blinkAbility, blinkLocation)
		return
	end
	shadowStrikeDesire, shadowStrikeTarget = X.ConsiderQ()
	if shadowStrikeDesire > 0 then
		Fu.SetQueuePtToINT(bot, true)
		if bot:HasScepter() and shadowStrikeTarget ~= nil then
			bot:ActionQueue_UseAbilityOnLocation(shadowStrikeAbility, shadowStrikeTarget:GetLocation())
			return
		end
		bot:ActionQueue_UseAbilityOnEntity(shadowStrikeAbility, shadowStrikeTarget)
		return
	end
	sonicWaveDesire, sonicWaveLocation = X.ConsiderR()
	if sonicWaveDesire > 0 then
		Fu.SetQueuePtToINT(bot, true)
		bot:ActionQueue_UseAbilityOnLocation(sonicWaveAbility, sonicWaveLocation)
		return
	end
	screamOfPainDesire = X.ConsiderE()
	if screamOfPainDesire > 0 then
		Fu.SetQueuePtToINT(bot, true)
		bot:ActionQueue_UseAbility(screamOfPainAbility)
		return
	end
end
function X.ConsiderQ()
	if not shadowStrikeAbility:IsFullyCastable() then
		return 0
	end
	local abilityLevel = shadowStrikeAbility:GetLevel()
	local castRange = shadowStrikeAbility:GetCastRange()
	local castPoint = shadowStrikeAbility:GetCastPoint()
	local manaCost = shadowStrikeAbility:GetManaCost()
	local damage = 75 + 125 * abilityLevel
	local damageType = DAMAGE_TYPE_MAGICAL
	local enemiesInRange = Fu.GetAroundEnemyHeroList(castRange + 20)
	local enemiesNearby = Fu.GetAroundEnemyHeroList(castRange + 100)
	local castTarget = nil
	local debugText = nil
	for _, enemyHero in pairs(enemiesNearby) do
		if
			Fu.IsValid(enemyHero)
			and not enemyHero:HasModifier("modifier_queenofpain_shadow_strike")
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and Fu.CanCastOnTargetAdvanced(enemyHero)
			and Fu.CanKillTarget(enemyHero, damage, damageType)
		then
			castTarget = enemyHero
			debugText = "Q-击杀" .. Fu.Chat.GetNormName(castTarget)
			return BOT_ACTION_DESIRE_HIGH, castTarget, debugText
		end
	end
	if Fu.IsGoingOnSomeone(bot) or Fu.IsLaning(bot) and Fu.IsAllowedToSpam(bot, manaCost) then
		if
			Fu.IsValidHero(botTarget)
			and not botTarget:HasModifier("modifier_queenofpain_shadow_strike")
			and Fu.IsInRange(botTarget, bot, castRange)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.CanCastOnTargetAdvanced(botTarget)
		then
			castTarget = botTarget
			debugText = "Q-先手" .. Fu.Chat.GetNormName(castTarget)
			return BOT_ACTION_DESIRE_HIGH, castTarget, debugText
		end
		for _, enemyHero in pairs(enemiesNearby) do
			if
				Fu.IsValid(enemyHero)
				and not enemyHero:HasModifier("modifier_queenofpain_shadow_strike")
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
			then
				castTarget = enemyHero
				debugText = "Q-标" .. Fu.Chat.GetNormName(castTarget)
				return BOT_ACTION_DESIRE_HIGH, castTarget, debugText
			end
		end
	end
	if Fu.IsRetreating(bot) then
		for _, enemyHero in pairs(enemiesInRange) do
			if
				Fu.IsValid(enemyHero)
				and Fu.IsInRange(bot, enemyHero, castRange - 100)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
			then
				castTarget = enemyHero
				debugText = "Q-撤退" .. Fu.Chat.GetNormName(castTarget)
				return BOT_ACTION_DESIRE_HIGH, castTarget, debugText
			end
		end
	end
	if Fu.IsFarming(bot) and Fu.IsAllowedToSpam(bot, manaCost) then
		local neutralCreeps = bot:GetNearbyNeutralCreeps(castRange)
		local mostHpCreep = Fu.GetMostHpUnit(neutralCreeps)
		if
			Fu.IsValid(mostHpCreep)
			and #neutralCreeps >= 2
			and not Fu.IsOtherAllysTarget(mostHpCreep)
			and mostHpCreep:GetMagicResist() < 0.4
			and not Fu.CanKillTarget(mostHpCreep, bot:GetAttackDamage() * 5, DAMAGE_TYPE_PHYSICAL)
		then
			castTarget = mostHpCreep
			debugText = "Q-打野:" .. Fu.Chat.GetNormName(castTarget)
			return BOT_ACTION_DESIRE_HIGH, castTarget, debugText
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if
			Fu.IsRoshan(botTarget)
			and Fu.IsInRange(botTarget, bot, castRange)
			and Fu.CanBeAttacked(botTarget)
			and isAttacking
			and not botTarget:HasModifier("modifier_roshan_spell_block")
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget, ""
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(botTarget, bot, castRange) and isAttacking then
			return BOT_ACTION_DESIRE_HIGH, botTarget, ""
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderW()
	if not blinkAbility:IsFullyCastable() or bot:IsRooted() or bot:HasModifier("modifier_bloodseeker_rupture") then
		return 0
	end
	local abilityLevel = blinkAbility:GetLevel()
	local castRange = 1000 + abilityLevel * 75
	local attackRange = bot:GetAttackRange()
	local castPoint = blinkAbility:GetCastPoint()
	local manaCost = blinkAbility:GetManaCost()
	local damage = blinkAbility:GetAbilityDamage()
	-- datafeed: Scream of Pain has no AbilityDamage; its damage is the special value "damage" (90/175/260/345).
	local screamDamage = screamOfPainAbility:GetSpecialValueInt("damage")
	local damageType = DAMAGE_TYPE_MAGICAL
	local enemiesInRange = Fu.GetAroundEnemyHeroList(castRange)
	local castLocation = nil
	local debugText = nil
	if Fu.IsStuck(bot) then
		castLocation = Fu.GetEscapeLoc()
		debugText = "W-被卡住"
		return BOT_ACTION_DESIRE_ABSOLUTE, castLocation, debugText
	end
	if
		Fu.IsRetreating(bot)
		or bot:GetActiveMode() == BOT_MODE_RETREAT and hpRatio < 0.2 and bot:DistanceFromFountain() > 1100
	then
		if Fu.ShouldEscape(bot) or bot:DistanceFromFountain() > 600 and bot:DistanceFromFountain() < 3800 then
			castLocation = Fu.GetEscapeLoc()
			debugText = "W-逃跑"
			return BOT_ACTION_DESIRE_ABSOLUTE, castLocation, debugText
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidHero(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange + 500)
			and not Fu.IsInRange(bot, botTarget, attackRange + 50)
			and Fu.CanCastOnMagicImmune(botTarget)
			and not botTarget:IsAttackImmune()
		then
			local enemiesNearTarget = Fu.GetNearbyHeroes(botTarget, 1100, false, BOT_MODE_NONE)
			local alliesNearTarget = Fu.GetNearbyHeroes(botTarget, 1000, true, BOT_MODE_NONE)
			local aliveEnemyCount = Fu.GetNumOfAliveHeroes(true)
			if
				aliveEnemyCount <= 1
				or #enemiesNearTarget <= 1
				or #enemiesNearTarget < #alliesNearTarget
				or Fu.WillKillTarget(botTarget, bot:GetAttackDamage() * 2, DAMAGE_TYPE_PHYSICAL, 2.0)
			then
				castLocation = Fu.Site.GetXUnitsTowardsLocation(botTarget, bot:GetLocation(), 330)
				debugText = "W-进攻:" .. Fu.Chat.GetNormName(botTarget)
				return BOT_ACTION_DESIRE_HIGH, castLocation, debugText
			end
		end
	end
	local enemyTowers = bot:GetNearbyTowers(1600, true)
	if
		(bot:GetActiveMode() == BOT_MODE_LANING or botLevel <= 7)
		and #nearbyEnemies == 0
		and #enemyTowers == 0
		and DotaTime() < 12 * 60
	then
		if
			mpRatio > 0.96
			and bot:DistanceFromFountain() > 60
			and bot:DistanceFromFountain() < 6000
			and bot:GetAttackTarget() == nil
			and bot:GetActiveMode() == BOT_MODE_LANING
		then
			local assignedLane = bot:GetAssignedLane()
			local laneFrontLocation = GetLaneFrontLocation(GetTeam(), assignedLane, 0)
			local laneFrontDistance = GetUnitToLocationDistance(bot, laneFrontLocation)
			if laneFrontDistance > 2000 then
				local blinkTargetLocation = Fu.Site.GetXUnitsTowardsLocation(bot, laneFrontLocation, castRange)
				if IsLocationPassable(blinkTargetLocation) then
					castLocation = blinkTargetLocation
					debugText = "W-对线赶路"
					if Fu.IsValidHero(bot:GetTarget()) then
						if
							Fu.CanKillTarget(bot:GetTarget(), screamDamage, DAMAGE_TYPE_MAGICAL)
							and screamOfPainAbility:IsFullyCastable()
						then
							-- Return the blink location too: the caller casts Blink on blinkLocation, and nil there broke the cast.
							return BOT_ACTION_DESIRE_VERYHIGH, castLocation, debugText
						end
					end
					return BOT_ACTION_DESIRE_MODERATE, castLocation, debugText
				end
			end
		end
	end
	if Fu.IsFarming(bot) and botLevel >= 6 then
		if
			botTarget ~= nil
			and botTarget:IsAlive()
			and not Fu.IsInRange(bot, botTarget, 900)
			and Fu.IsInRange(bot, botTarget, 1600)
		then
			castLocation = botTarget:GetLocation()
			debugText = "W-打钱赶路"
			return BOT_ACTION_DESIRE_HIGH, castLocation, debugText
		end
	end
	local attackingAllies = Fu.GetNearbyHeroes(bot, 1600, false, BOT_MODE_ATTACK)
	if
		#nearbyEnemies == 0
		and not bot:WasRecentlyDamagedByAnyHero(3.0)
		and botLevel >= 9
		and #attackingAllies == 0
		and #nearbyAllies <= 3
		and (botTarget ~= nil and not botTarget:IsHero())
	then
		local aoeLocation = bot:FindAoELocation(true, false, bot:GetLocation(), 1400, 400, 0, 0)
		local laneCreeps = bot:GetNearbyLaneCreeps(1400, true)
		if aoeLocation.count >= 3 and #laneCreeps >= 3 then
			local creepCenter = Fu.GetCenterOfUnits(laneCreeps)
			local targetToCenterDistance = GetUnitToLocationDistance(botTarget, creepCenter)
			if
				targetToCenterDistance <= 500
				and IsLocationPassable(creepCenter)
				and IsLocationVisible(creepCenter)
				and GetUnitToLocationDistance(bot, creepCenter) >= 700
			then
				castLocation = creepCenter
				debugText = "W-跳兵堆"
				return BOT_ACTION_DESIRE_HIGH, castLocation, debugText
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderE()
	if not screamOfPainAbility:IsFullyCastable() then
		return 0
	end
	local abilityLevel = screamOfPainAbility:GetLevel()
	local castRange = screamOfPainAbility:GetCastRange()
	local castPoint = screamOfPainAbility:GetCastPoint()
	local radius = screamOfPainAbility:GetSpecialValueInt("area_of_effect")
	local manaCost = screamOfPainAbility:GetManaCost()
	-- datafeed: Scream of Pain has no AbilityDamage; its damage is the special value "damage" (90/175/260/345).
	-- GetAbilityDamage() gave 0, so the kill and lane last-hit checks never fired.
	local damage = screamOfPainAbility:GetSpecialValueInt("damage")
	local damageType = DAMAGE_TYPE_MAGICAL
	local enemiesInRange = Fu.GetAroundEnemyHeroList(radius - 30)
	local enemiesNearby = Fu.GetAroundEnemyHeroList(radius + 200)
	local castTarget = nil
	local debugText = nil
	for _, enemyHero in pairs(enemiesInRange) do
		if
			Fu.IsValid(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and Fu.CanKillTarget(enemyHero, damage, damageType)
		then
			castTarget = enemyHero
			debugText = "E-击杀" .. Fu.Chat.GetNormName(castTarget)
			return BOT_ACTION_DESIRE_HIGH, castTarget, debugText
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		-- Scream of Pain is SPELL_IMMUNITY_ENEMIES_NO (game files): a magic-immune target takes nothing.
		if
			Fu.IsValidHero(botTarget)
			and Fu.IsInRange(botTarget, bot, radius - 20)
			and Fu.CanCastOnNonMagicImmune(botTarget)
		then
			castTarget = botTarget
			debugText = "E-攻击" .. Fu.Chat.GetNormName(castTarget)
			return BOT_ACTION_DESIRE_HIGH, castTarget, debugText
		end
	end
	if Fu.IsInTeamFight(bot, 1000) then
		local enemyCount = 0
		for _, enemyHero in pairs(enemiesInRange) do
			if Fu.IsValidHero(enemyHero) and Fu.CanCastOnNonMagicImmune(enemyHero) then
				enemyCount = enemyCount + 1
			end
		end
		if enemyCount >= 2 then
			castTarget = botTarget
			debugText = "E-团战AOE" .. enemyCount
			return BOT_ACTION_DESIRE_HIGH, castTarget, debugText
		end
	end
	if Fu.IsRetreating(bot) then
		for _, enemyHero in pairs(enemiesInRange) do
			if
				Fu.IsValid(enemyHero)
				and bot:WasRecentlyDamagedByHero(enemyHero, 5.0)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
			then
				castTarget = enemyHero
				debugText = "E-撤退" .. Fu.Chat.GetNormName(castTarget)
				return BOT_ACTION_DESIRE_HIGH, castTarget, debugText
			end
		end
	end
	if Fu.IsLaning(bot) and Fu.IsAllowedToSpam(bot, manaCost) then
		local killableMeleeCount = 0
		local killableRangedCount = 0
		local laneCreeps = bot:GetNearbyLaneCreeps(radius, true)
		for _, creep in pairs(laneCreeps) do
			if
				Fu.IsValid(creep)
				and not creep:HasModifier("modifier_fountain_glyph")
				and not Fu.IsOtherAllysTarget(creep)
			then
				local creepDamage = damage
				local hitTime = castPoint + GetUnitToUnitDistance(bot, creep) / 900
				if Fu.WillKillTarget(creep, creepDamage, damageType, hitTime) then
					if Fu.IsKeyWordUnit("ranged", creep) then
						killableRangedCount = killableRangedCount + 1
					end
					if Fu.IsKeyWordUnit("melee", creep) then
						killableMeleeCount = killableMeleeCount + 1
					end
				end
			end
		end
		if killableMeleeCount + killableRangedCount >= 3 then
			return BOT_ACTION_DESIRE_HIGH, bot, "E对线1"
		end
		if killableRangedCount >= 1 and killableMeleeCount >= 1 then
			return BOT_ACTION_DESIRE_HIGH, bot, "E对线2"
		end
		if
			#laneCreeps == 0
			and Fu.IsValidHero(enemiesInRange[1])
			and Fu.CanCastOnNonMagicImmune(enemiesInRange[1])
			and mpRatio > 0.5
		then
			return BOT_ACTION_DESIRE_HIGH, bot, "E消耗"
		end
	end
	if
		(Fu.IsPushing(bot) or Fu.IsDefending(bot))
		and Fu.IsAllowedToSpam(bot, manaCost * 0.32)
		and #nearbyAllies <= 3
	then
		local laneCreeps = bot:GetNearbyLaneCreeps(radius, true)
		if
			(#laneCreeps >= 4 or #laneCreeps >= 3 and mpRatio > 0.82)
			and not laneCreeps[1]:HasModifier("modifier_fountain_glyph")
		then
			castTarget = laneCreeps[1] -- was the undefined global creep (nil); Scream is no-target
			debugText = "E-带线AOE" .. #laneCreeps
			return BOT_ACTION_DESIRE_HIGH, castTarget, debugText
		end
	end
	if Fu.IsFarming(bot) and Fu.IsAllowedToSpam(bot, manaCost * 0.25) then
		local neutralCreeps = bot:GetNearbyNeutralCreeps(radius)
		if #neutralCreeps >= 2 and Fu.IsValid(botTarget) then
			castTarget = botTarget
			debugText = "E-打野AOE" .. #neutralCreeps
			return BOT_ACTION_DESIRE_HIGH, castTarget, debugText
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if
			Fu.IsRoshan(botTarget)
			and Fu.IsInRange(botTarget, bot, radius)
			and Fu.CanBeAttacked(botTarget)
			and isAttacking
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(botTarget, bot, radius) and isAttacking then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderR()
	if not sonicWaveAbility:IsFullyCastable() then
		return 0
	end
	local abilityLevel = sonicWaveAbility:GetLevel()
	local castRange = sonicWaveAbility:GetCastRange()
	local castPoint = sonicWaveAbility:GetCastPoint()
	local manaCost = sonicWaveAbility:GetManaCost()
	local damage = sonicWaveAbility:GetSpecialValueInt("damage")
	local radius = sonicWaveAbility:GetSpecialValueInt("final_aoe") * 0.88
	-- datafeed: Sonic Wave has no "damage_scepter" (the Scepter now upgrades Shadow Strike), so the old
	-- Scepter override set the damage to 0 and broke the kill check; it is removed.
	local damageType = DAMAGE_TYPE_PURE
	local enemiesInRange = Fu.GetAroundEnemyHeroList(castRange)
	local castLocation = nil
	local debugText = nil
	if Fu.IsInTeamFight(bot, 1200) then
		local aoeLocation = Fu.GetAoeEnemyHeroLocation(bot, castRange, radius, 2)
		if aoeLocation ~= nil then
			castLocation = aoeLocation
			debugText = "R-团战AOE"
			return BOT_ACTION_DESIRE_HIGH, castLocation, debugText
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidHero(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange + radius * 0.5)
			and Fu.CanCastOnMagicImmune(botTarget)
		then
			local enemiesNearTarget = Fu.GetNearbyHeroes(botTarget, radius, false, BOT_MODE_NONE)
			if Fu.CanKillTarget(botTarget, damage * 1.3, damageType) or #enemiesNearTarget >= 2 then
				local targetCastLocation = Fu.GetCastLocation(bot, botTarget, castRange, radius)
				if targetCastLocation ~= nil then
					castLocation = targetCastLocation
					debugText = "R-攻击目标:" .. Fu.Chat.GetNormName(botTarget)
					return BOT_ACTION_DESIRE_HIGH, castLocation, debugText
				end
			end
		end
	end
	if Fu.IsRetreating(bot) and #nearbyAllies >= 2 and #nearbyEnemies >= 2 and bot:WasRecentlyDamagedByAnyHero(3.0) then
		for _, enemyHero in pairs(enemiesInRange) do
			if Fu.IsValid(enemyHero) and Fu.CanCastOnMagicImmune(enemyHero) and not Fu.IsDisabled(enemyHero) then
				castLocation = enemyHero:GetExtrapolatedLocation(castPoint)
				debugText = "R-保护团队撤退"
				return BOT_ACTION_DESIRE_HIGH, castLocation, debugText
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
return X
