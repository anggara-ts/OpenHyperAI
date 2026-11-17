-- Skywrath Mage: skill build, item build, and ability use for this hero.
-- Accidental globals made file-local (#13): every bot shares one Lua state, so these were shared.
local botTarget, hAllyList, nInRangeEnemyHeroList
local X = {}
local bot = GetBot()
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local AbilityContext = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local Minion = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local sTalentList = Fu.Skill.GetTalentList(bot)
local sAbilityList = Fu.Skill.GetAbilityList(bot)
local sRole = Fu.Item.GetRoleItemsBuyList(bot)
local tTalentTreeList = { ["t25"] = { 10, 0 }, ["t20"] = { 10, 0 }, ["t15"] = { 0, 10 }, ["t10"] = { 0, 10 } }
local tAllAbilityBuildList = { { 2, 1, 1, 3, 2, 6, 1, 1, 3, 3, 6, 3, 2, 2, 6 } }
local nAbilityBuildList = Fu.Skill.GetRandomBuild(tAllAbilityBuildList)
local nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList)
local sRoleItemsBuyList = {}
sRoleItemsBuyList["pos_4"] = {
	"item_tango",
	"item_tango",
	"item_double_branches",
	"item_blood_grenade",
	"item_null_talisman",
	"item_magic_wand",
	"item_arcane_boots",
	"item_rod_of_atos",
	"item_glimmer_cape",
	"item_aether_lens",
	"item_aghanims_shard",
	"item_guardian_greaves",
	"item_ultimate_scepter",
	"item_octarine_core",
	"item_gungir",
	"item_shivas_guard",
	"item_ultimate_scepter_2",
	"item_moon_shard",
}
sRoleItemsBuyList["pos_5"] = {
	"item_tango",
	"item_tango",
	"item_double_branches",
	"item_blood_grenade",
	"item_null_talisman",
	"item_magic_wand",
	"item_arcane_boots",
	"item_glimmer_cape",
	"item_pipe",
	"item_rod_of_atos",
	"item_aghanims_shard",
	"item_guardian_greaves",
	"item_ultimate_scepter",
	"item_octarine_core",
	"item_gungir",
	"item_sheepstick",
	"item_ultimate_scepter_2",
	"item_moon_shard",
}
sRoleItemsBuyList["pos_1"] = {
	"item_crystal_maiden_outfit",
	"item_rod_of_atos",
	"item_kaya",
	"item_ultimate_scepter",
	"item_kaya_and_sange",
	"item_aghanims_shard",
	"item_octarine_core",
	"item_gungir",
	"item_cyclone",
	"item_sheepstick",
	"item_wind_waker",
	"item_moon_shard",
	"item_ultimate_scepter_2",
	"item_travel_boots_2",
}
sRoleItemsBuyList["pos_2"] = {
	"item_tango",
	"item_double_branches",
	"item_double_circlet",
	"item_bottle",
	"item_null_talisman",
	"item_magic_wand",
	"item_null_talisman",
	"item_arcane_boots",
	"item_rod_of_atos",
	"item_kaya",
	"item_ultimate_scepter",
	"item_kaya_and_sange",
	"item_aghanims_shard",
	"item_dagon_2",
	"item_octarine_core",
	"item_gungir",
	"item_sheepstick",
	"item_dagon_5",
	"item_moon_shard",
	"item_ultimate_scepter_2",
	"item_travel_boots_2",
}
sRoleItemsBuyList["pos_3"] = sRoleItemsBuyList["pos_1"]
X["sBuyList"] = sRoleItemsBuyList[sRole]
X["sSellList"] = { "item_black_king_bar", "item_quelling_blade" }
if Fu.Role.IsPvNMode() or Fu.Role.IsAllShadow() then
	X["sBuyList"], X["sSellList"] = { "PvN_mage" }, {}
end
nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"] =
	Fu.SetUserHeroInit(nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"])
X["sSkillList"] = Fu.Skill.GetSkillList(sAbilityList, nAbilityBuildList, sTalentList, nTalentBuildList)
X["bDeafaultAbility"] = false
X["bDeafaultItem"] = true
function X.MinionThink(minion)
	Minion.MinionThink(minion)
end
local arcaneBoltAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[1]), "sAbilityList[1]", "skywrath_mage")
local concussiveShotAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[2]), "sAbilityList[2]", "skywrath_mage")
local ancientSealAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[3]), "sAbilityList[3]", "skywrath_mage")
local mysticFlareAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[6]), "sAbilityList[6]", "skywrath_mage")
local arcaneBoltDesire, arcaneBoltTarget
local concussiveShotDesire
local ancientSealDesire, ancientSealTarget
local mysticFlareDesire, mysticFlareLocation
local aetherRange = 0
local botLevel, mpRatio, hpRatio, nearbyEnemies
function X.SkillsComplement()
	if Fu.CanNotUseAbility(bot) or bot:IsInvisible() then
		return
	end
	local context = AbilityContext.Build(bot)
	aetherRange = context.aetherRange
	botLevel = context.level
	mpRatio = context.mp
	hpRatio = context.hp
	botTarget = context.target
	nearbyEnemies = context.enemies
	hAllyList = context.allies
	nInRangeEnemyHeroList = Fu.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE)
	ancientSealDesire, ancientSealTarget = X.ConsiderE()
	if ancientSealDesire > 0 then
		Fu.SetQueuePtToINT(bot, true)
		bot:ActionQueue_UseAbilityOnEntity(ancientSealAbility, ancientSealTarget)
		return
	end
	mysticFlareDesire, mysticFlareLocation = X.ConsiderR()
	if mysticFlareDesire > 0 then
		Fu.SetQueuePtToINT(bot, true)
		bot:ActionQueue_UseAbilityOnLocation(mysticFlareAbility, mysticFlareLocation)
		return
	end
	concussiveShotDesire = X.ConsiderW()
	if concussiveShotDesire > 0 then
		Fu.SetQueuePtToINT(bot, true)
		bot:ActionQueue_UseAbility(concussiveShotAbility)
		return
	end
	arcaneBoltDesire, arcaneBoltTarget = X.ConsiderQ()
	if arcaneBoltDesire > 0 then
		Fu.SetQueuePtToINT(bot, true)
		bot:ActionQueue_UseAbilityOnEntity(arcaneBoltAbility, arcaneBoltTarget)
		return
	end
end
function X.ConsiderQ()
	if not arcaneBoltAbility:IsFullyCastable() then
		return 0
	end
	local abilityLevel = arcaneBoltAbility:GetLevel()
	local castRange = arcaneBoltAbility:GetCastRange() + aetherRange
	local castPoint = arcaneBoltAbility:GetCastPoint()
	local manaCost = arcaneBoltAbility:GetManaCost()
	-- datafeed: Arcane Bolt int_multiplier=1.5 (was 1.6)
	local damage = arcaneBoltAbility:GetSpecialValueInt("bolt_damage")
		+ bot:GetAttributeValue(ATTRIBUTE_INTELLECT) * 1.5
	local damageType = DAMAGE_TYPE_MAGICAL
	local nInRangeEnemyHeroList = Fu.GetNearbyHeroes(bot, math.min(castRange + 50, 1600), true, BOT_MODE_NONE)
	local attackDamage = bot:GetAttackDamage()
	local hAllyList = Fu.GetNearbyHeroes(bot, 1300, false, BOT_MODE_NONE)
	if not Fu.IsValidHero(botTarget) or Fu.GetHP(botTarget) > 0.2 then
		for _, enemyHero in pairs(nInRangeEnemyHeroList) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
				and Fu.GetHP(enemyHero) <= 0.2
			then
				return BOT_ACTION_DESIRE_HIGH, enemyHero, "Q击杀" .. enemyHero:GetUnitName()
			end
		end
	end
	if Fu.IsLaning(bot) then
		if not Fu.IsThereNonSelfCoreNearby(castRange) then
			local laneCreeps = bot:GetNearbyLaneCreeps(math.min(castRange + 50, 1600), true)
			for _, creep in pairs(laneCreeps) do
				if
					Fu.IsValid(creep)
					and not creep:HasModifier("modifier_fountain_glyph")
					and Fu.IsKeyWordUnit("ranged", creep)
					and not Fu.IsOtherAllysTarget(creep)
					and creep:GetHealth() > damage * 0.68
				then
					local hitDelay = castPoint + GetUnitToUnitDistance(bot, creep) / 500
					if
						Fu.WillKillTarget(creep, damage, damageType, hitDelay * 0.9)
						and not Fu.WillKillTarget(creep, attackDamage, DAMAGE_TYPE_PHYSICAL, hitDelay)
					then
						return BOT_ACTION_DESIRE_HIGH, creep, "Q对线"
					end
				end
			end
		end
		if #nInRangeEnemyHeroList >= 1 and mpRatio > 0.5 and abilityLevel >= 2 then
			local enemyHero = nInRangeEnemyHeroList[1]
			if Fu.IsValidHero(enemyHero) and Fu.IsInRange(bot, enemyHero, castRange) then
				return BOT_ACTION_DESIRE_HIGH, enemyHero, "Q消耗" .. enemyHero:GetUnitName()
			end
		end
	end
	if Fu.IsRetreating(bot) and bot:WasRecentlyDamagedByAnyHero(2.0) then
		local weakestEnemy = Fu.GetVulnerableWeakestUnit(bot, true, true, castRange)
		if
			weakestEnemy ~= nil
			and bot:IsFacingLocation(weakestEnemy:GetLocation(), 30)
			and Fu.CanCastOnTargetAdvanced(weakestEnemy)
		then
			return BOT_ACTION_DESIRE_HIGH, weakestEnemy, "Q撤退"
		end
	end
	if
		(Fu.IsPushing(bot) or Fu.IsDefending(bot) or Fu.IsFarming(bot))
		and #hAllyList < 3
		and botLevel > 7
		and Fu.IsAllowedToSpam(bot, 30)
	then
		local laneCreeps = bot:GetNearbyLaneCreeps(math.min(castRange + 150, 1600), true)
		for _, creep in pairs(laneCreeps) do
			if
				Fu.IsValid(creep)
				and not creep:HasModifier("modifier_fountain_glyph")
				and (Fu.IsKeyWordUnit("ranged", creep) or mpRatio > 0.5 and Fu.IsKeyWordUnit("melee", creep))
				and not Fu.IsOtherAllysTarget(creep)
				and creep:GetHealth() > damage * 0.68
			then
				local hitDelay = castPoint + GetUnitToUnitDistance(bot, creep) / 500
				if
					Fu.WillKillTarget(creep, damage, damageType, hitDelay * 0.8)
					and not Fu.WillKillTarget(creep, attackDamage, DAMAGE_TYPE_PHYSICAL, hitDelay)
				then
					return BOT_ACTION_DESIRE_HIGH, creep, "Q推进"
				end
			end
		end
	end
	if Fu.IsFarming(bot) and botLevel >= 3 then
		if
			Fu.IsValid(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and botTarget:GetTeam() == TEAM_NEUTRAL
			and (botTarget:GetMagicResist() < 0.3 or mpRatio > 0.7)
			and mpRatio > 0.4
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget, "Q打野"
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidHero(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.CanCastOnTargetAdvanced(botTarget)
			and Fu.IsInRange(botTarget, bot, castRange + 50)
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget, "Q进攻"
		end
	end
	if bot:GetActiveMode() == BOT_MODE_ROSHAN and botLevel > 15 and mpRatio > 0.4 then
		if Fu.IsRoshan(botTarget) and Fu.GetHP(botTarget) > 0.2 and Fu.IsInRange(botTarget, bot, castRange) then
			return BOT_ACTION_DESIRE_HIGH, botTarget, "Q肉山"
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, castRange) and Fu.IsAttacking(bot) then
			return BOT_ACTION_DESIRE_HIGH, botTarget, ""
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderW()
	if not concussiveShotAbility:IsFullyCastable() then
		return 0
	end
	local abilityLevel = concussiveShotAbility:GetLevel()
	local castRange = 1600
	local castPoint = concussiveShotAbility:GetCastPoint()
	local manaCost = concussiveShotAbility:GetManaCost()
	local damage = concussiveShotAbility:GetAbilityDamage()
	local damageType = DAMAGE_TYPE_MAGICAL
	local nearestEnemy = nearbyEnemies[1]
	if Fu.IsValidHero(nearestEnemy) and Fu.CanCastOnNonMagicImmune(nearestEnemy) then
		local distance = GetUnitToUnitDistance(bot, nearestEnemy)
		if Fu.WillMagicKillTarget(bot, nearestEnemy, damage, castPoint + distance / 1200) then
			return BOT_ACTION_DESIRE_HIGH, "W击杀" .. Fu.Chat.GetNormName(nearestEnemy)
		end
	end
	if Fu.IsLaning(bot) then
		if #nInRangeEnemyHeroList >= 1 and mpRatio > 0.5 and (abilityLevel >= 2 or botLevel <= 2) then
			local enemyHero = nInRangeEnemyHeroList[1]
			if Fu.IsValidHero(enemyHero) and Fu.IsInRange(bot, enemyHero, castRange) then
				return BOT_ACTION_DESIRE_HIGH, "W消耗" .. enemyHero:GetUnitName()
			end
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidHero(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsValidHero(nearestEnemy)
			and Fu.CanCastOnNonMagicImmune(nearestEnemy)
			and Fu.IsInRange(bot, nearestEnemy, castRange + 50)
			and Fu.IsInRange(botTarget, nearestEnemy, 250)
		then
			return BOT_ACTION_DESIRE_HIGH, "W进攻"
		end
	end
	if Fu.IsRetreating(bot) then
		if
			Fu.IsValidHero(nearestEnemy)
			and Fu.CanCastOnNonMagicImmune(nearestEnemy)
			and Fu.IsInRange(bot, nearestEnemy, castRange + 50)
			and (bot:WasRecentlyDamagedByHero(nearestEnemy, 5.0) or hpRatio < 0.4)
		then
			return BOT_ACTION_DESIRE_HIGH, "W撤退"
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderE()
	if not ancientSealAbility:IsFullyCastable() then
		return 0
	end
	local abilityLevel = ancientSealAbility:GetLevel()
	local castRange = ancientSealAbility:GetCastRange() + aetherRange
	local castPoint = ancientSealAbility:GetCastPoint()
	local manaCost = ancientSealAbility:GetManaCost()
	local damage = ancientSealAbility:GetAbilityDamage()
	local damageType = DAMAGE_TYPE_MAGICAL
	local nInRangeEnemyHeroList = Fu.GetNearbyHeroes(bot, math.min(castRange + 50, 1600), true, BOT_MODE_NONE)
	for _, enemyHero in pairs(nInRangeEnemyHeroList) do
		if
			(enemyHero:IsCastingAbility() or enemyHero:IsChanneling())
			and not enemyHero:HasModifier("modifier_teleporting")
			and not enemyHero:HasModifier("modifier_boots_of_travel_incoming")
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and Fu.CanCastOnTargetAdvanced(enemyHero)
		then
			return BOT_ACTION_DESIRE_HIGH, enemyHero, "E打断"
		end
	end
	if Fu.IsInTeamFight(bot, 700) then
		local bestTarget = nil
		local highestDamage = 0
		local enemiesInRange = Fu.GetNearbyHeroes(bot, math.min(castRange + 100, 1600), true, BOT_MODE_NONE)
		for _, enemyHero in pairs(enemiesInRange) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
				and not Fu.IsDisabled(enemyHero)
				and not enemyHero:IsSilenced()
			then
				local estimatedDamage = enemyHero:GetEstimatedDamageToTarget(false, bot, 3.0, DAMAGE_TYPE_MAGICAL)
				if estimatedDamage > highestDamage then
					highestDamage = estimatedDamage
					bestTarget = enemyHero
				end
			end
		end
		if bestTarget ~= nil then
			return BOT_ACTION_DESIRE_HIGH, bestTarget, "E团战"
		end
	end
	if bot:WasRecentlyDamagedByAnyHero(3.0) and nInRangeEnemyHeroList[1] ~= nil and #nInRangeEnemyHeroList >= 1 then
		for _, enemyHero in pairs(nInRangeEnemyHeroList) do
			if
				Fu.IsValid(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
				and not Fu.IsDisabled(enemyHero)
				and not enemyHero:IsSilenced()
				and bot:IsFacingLocation(enemyHero:GetLocation(), 40)
			then
				return BOT_ACTION_DESIRE_HIGH, enemyHero, "E自保"
			end
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidHero(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.CanCastOnTargetAdvanced(botTarget)
			and Fu.IsInRange(botTarget, bot, castRange)
			and not Fu.IsDisabled(botTarget)
			and not botTarget:IsSilenced()
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget, "E进攻"
		end
	end
	if Fu.IsRetreating(bot) then
		for _, enemyHero in pairs(nInRangeEnemyHeroList) do
			if
				Fu.IsValid(enemyHero)
				and bot:WasRecentlyDamagedByHero(enemyHero, 3.1)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
				and not Fu.IsDisabled(enemyHero)
				and not enemyHero:IsSilenced()
				and Fu.IsInRange(enemyHero, bot, castRange)
				and (not Fu.IsInRange(enemyHero, bot, 450) or bot:IsFacingLocation(enemyHero:GetLocation(), 45))
			then
				return BOT_ACTION_DESIRE_HIGH, enemyHero, "E撤退"
			end
		end
	end
	if bot:GetActiveMode() == BOT_MODE_ROSHAN and bot:GetMana() >= 1200 and ancientSealAbility:GetLevel() >= 3 then
		if Fu.IsRoshan(botTarget) and Fu.IsInRange(botTarget, bot, castRange) then
			return BOT_ACTION_DESIRE_HIGH, botTarget, "E肉山"
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, castRange) and Fu.IsAttacking(bot) then
			return BOT_ACTION_DESIRE_HIGH, botTarget, ""
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderR()
	if not mysticFlareAbility:IsFullyCastable() then
		return 0
	end
	local castRange = mysticFlareAbility:GetCastRange() + aetherRange
	if castRange > 1400 then
		castRange = 1400
	end
	local radius = 170
	local castPoint = mysticFlareAbility:GetCastPoint()
	local manaCost = mysticFlareAbility:GetManaCost()
	local damage = mysticFlareAbility:GetAbilityDamage()
	local damageType = DAMAGE_TYPE_MAGICAL
	local nInRangeEnemyHeroList = Fu.GetNearbyHeroes(bot, math.min(castRange + 200, 1600), true, BOT_MODE_NONE)
	if Fu.IsInTeamFight(bot, 1200) then
		local aoeLocation = Fu.GetAoeEnemyHeroLocation(bot, castRange, radius, 2)
		if aoeLocation ~= nil then
			return BOT_ACTION_DESIRE_HIGH, aoeLocation, "R团战"
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidHero(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange + 200)
		then
			-- Review fix: a standing or disabled target was flared 148 units ahead of where it faces,
			-- near the edge of the 170 radius, so one step took it out. Centre on it then, and lead
			-- the shot only for a slowed target that is still moving.
			if (not Fu.IsRunning(botTarget) and not Fu.IsMoving(botTarget)) or Fu.IsDisabled(botTarget) then
				return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation(), "R进攻"
			end
			if botTarget:GetCurrentMovementSpeed() < 180 then
				return BOT_ACTION_DESIRE_HIGH, Fu.GetFaceTowardDistanceLocation(botTarget, 148), "R进攻"
			end
		end
	end
	if Fu.IsRetreating(bot) and hpRatio < 0.78 then
		for _, enemyHero in pairs(nInRangeEnemyHeroList) do
			-- Review fix: the ult (300-800 mana) was thrown at any chaser, which just walks out of the
			-- 170 radius. Only flare a chaser that is disabled or slowed (e.g. by Concussive Shot).
			if
				Fu.IsValidHero(enemyHero)
				and bot:WasRecentlyDamagedByHero(enemyHero, 3.1)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and (Fu.IsDisabled(enemyHero) or enemyHero:GetCurrentMovementSpeed() < 200)
				and Fu.IsInRange(bot, enemyHero, castRange)
			then
				if DotaTime() - (X.lastFlareLog or -99) > 10 then
					X.lastFlareLog = DotaTime()
					pcall(
						print,
						string.format(
							"[OHA-SKYWRATH] t=%.0f flare-retreat target=%s ms=%d",
							DotaTime(),
							enemyHero:GetUnitName(),
							enemyHero:GetCurrentMovementSpeed()
						)
					)
				end
				return BOT_ACTION_DESIRE_HIGH, enemyHero:GetLocation(), "R撤退"
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
return X
