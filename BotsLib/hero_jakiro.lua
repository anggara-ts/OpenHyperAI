-- Jakiro: skill build, item build, and ability use for this hero.
local X = {}
local bot = GetBot()
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local AbilityContext = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local Minion = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local sTalentList = Fu.Skill.GetTalentList(bot)
local sAbilityList = Fu.Skill.GetAbilityList(bot)
local sRole = Fu.Item.GetRoleItemsBuyList(bot)
local tTalentTreeList = { ["t25"] = { 10, 0 }, ["t20"] = { 10, 0 }, ["t15"] = { 10, 0 }, ["t10"] = { 0, 10 } }
-- Liquid Fire first (Dotabuff most picked order), Ice Path at 4 and 8, Dual Breath from 9.
local tAllAbilityBuildList = { { 3, 1, 3, 2, 3, 6, 3, 2, 1, 1, 6, 1, 2, 2, 6 } }
local nAbilityBuildList = Fu.Skill.GetRandomBuild(tAllAbilityBuildList)
local nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList)
local sRoleItemsBuyList = {}
sRoleItemsBuyList["pos_3"] = {
	"item_mage_outfit",
	"item_ancient_janggo",
	"item_glimmer_cape",
	"item_boots_of_bearing",
	"item_rod_of_atos",
	"item_mjollnir",
	"item_aghanims_shard",
	"item_veil_of_discord",
	"item_cyclone",
	"item_shivas_guard",
	"item_sheepstick",
	"item_wind_waker",
	"item_moon_shard",
	"item_ultimate_scepter_2",
}
sRoleItemsBuyList["pos_4"] = {
	"item_blood_grenade",
	"item_priest_outfit",
	"item_mekansm",
	"item_glimmer_cape",
	"item_aghanims_shard",
	"item_guardian_greaves",
	"item_cyclone",
	"item_ultimate_scepter",
	"item_shivas_guard",
	"item_moon_shard",
	"item_ultimate_scepter_2",
	"item_sheepstick",
}
sRoleItemsBuyList["pos_5"] = {
	"item_blood_grenade",
	"item_mage_outfit",
	"item_ancient_janggo",
	"item_glimmer_cape",
	"item_boots_of_bearing",
	"item_aghanims_shard",
	"item_ultimate_scepter",
	"item_cyclone",
	"item_sheepstick",
	"item_wind_waker",
	"item_moon_shard",
	"item_ultimate_scepter_2",
}
sRoleItemsBuyList["pos_2"] = {
	"item_crystal_maiden_outfit",
	"item_witch_blade",
	"item_orchid",
	"item_force_staff",
	"item_ultimate_scepter",
	"item_hurricane_pike",
	"item_yasha_and_kaya",
	"item_bloodthorn",
	"item_sphere",
	"item_aghanims_shard",
	"item_skadi",
	"item_moon_shard",
	"item_ultimate_scepter_2",
	"item_travel_boots_2",
}
sRoleItemsBuyList["pos_1"] = sRoleItemsBuyList["pos_2"]
X["sBuyList"] = sRoleItemsBuyList[sRole]
X["sSellList"] = {
	"item_black_king_bar",
	"item_quelling_blade",
	"item_ultimate_scepter",
	"item_magic_wand",
	"item_cyclone",
	"item_magic_wand",
	"item_shivas_guard",
	"item_magic_wand",
	"item_skadi",
	"item_witch_blade",
	"item_ultimate_scepter",
	"item_urn_of_shadows",
}
if Fu.Role.IsPvNMode() or Fu.Role.IsAllShadow() then
	X["sBuyList"], X["sSellList"] = { "PvN_mage" }, {}
end
nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"] = Fu.SetUserHeroInit(nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"])
X["sSkillList"] = Fu.Skill.GetSkillList(sAbilityList, nAbilityBuildList, sTalentList, nTalentBuildList)
X["bDeafaultAbility"] = false
X["bDeafaultItem"] = true
function X.MinionThink(minionUnit)
	Minion.MinionThink(minionUnit)
end
local dualBreathAbility = SafeAbility(bot:GetAbilityByName("jakiro_dual_breath"), "jakiro_dual_breath", "jakiro")
local icePathAbility = SafeAbility(bot:GetAbilityByName("jakiro_ice_path"), "jakiro_ice_path", "jakiro")
local liquidFireAbility = SafeAbility(bot:GetAbilityByName("jakiro_liquid_fire"), "jakiro_liquid_fire", "jakiro")
-- datafeed: the internal name of Liquid Frost is jakiro_liquid_ice ("jakiro_liquid_frost" does not exist)
local liquidFrostAbility = SafeAbility(bot:GetAbilityByName("jakiro_liquid_ice"), "jakiro_liquid_ice", "jakiro")
local macropyreAbility = SafeAbility(bot:GetAbilityByName("jakiro_macropyre"), "jakiro_macropyre", "jakiro")
local dualBreathDesire, dualBreathLocation
local icePathDesire, icePathLocation
local liquidFireDesire, liquidFireTarget
local liquidFrostDesire, liquidFrostTarget
local macropyreDesire, macropyreLocation
local botTarget
local isAttacking
function X.SkillsComplement()
	if Fu.CanNotUseAbility(bot) then
		return
	end
	isAttacking = Fu.IsAttacking(bot)
	icePathDesire, icePathLocation = X.ConsiderW()
	if icePathDesire > 0 then
		Fu.SetQueuePtToINT(bot, true)
		bot:ActionQueue_UseAbilityOnLocation(icePathAbility, icePathLocation)
		return
	end
	macropyreDesire, macropyreLocation = X.ConsiderR()
	if macropyreDesire > 0 then
		Fu.SetQueuePtToINT(bot, true)
		bot:ActionQueue_UseAbilityOnLocation(macropyreAbility, macropyreLocation)
		return
	end
	dualBreathDesire, dualBreathLocation = X.ConsiderQ()
	if dualBreathDesire > 0 then
		Fu.SetQueuePtToINT(bot, true)
		bot:ActionQueue_UseAbilityOnLocation(dualBreathAbility, dualBreathLocation)
		return
	end
	liquidFireDesire, liquidFireTarget = X.ConsiderE()
	if liquidFireDesire > 0 then
		Fu.SetQueuePtToINT(bot, true)
		bot:ActionQueue_UseAbilityOnEntity(liquidFireAbility, liquidFireTarget)
		return
	end
	liquidFrostDesire, liquidFrostTarget = X.ConsiderAS()
	if liquidFrostDesire > 0 then
		Fu.SetQueuePtToINT(bot, true)
		bot:ActionQueue_UseAbilityOnEntity(liquidFrostAbility, liquidFrostTarget)
		return
	end
end
function X.ConsiderQ()
	if not Fu.CanCastAbility(dualBreathAbility) then
		return 0
	end
	local castRange = Fu.GetProperCastRange(false, bot, dualBreathAbility:GetCastRange())
	local castPoint = dualBreathAbility:GetCastPoint()
	local manaCost = dualBreathAbility:GetManaCost()
	local radius = dualBreathAbility:GetSpecialValueInt("start_radius")
	local duration = dualBreathAbility:GetDuration()
	local speed = dualBreathAbility:GetSpecialValueInt("speed")
	local damage = dualBreathAbility:GetSpecialValueInt("burn_damage")
	local botTarget = Fu.GetProperTarget(bot)
	local nearbyEnemies = bot:GetNearbyHeroes(1600, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.IsInRange(bot, enemyHero, castRange)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and Fu.WillKillTarget(enemyHero, damage, DAMAGE_TYPE_MAGICAL, duration)
			and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
			and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
			and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
			and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
			and not enemyHero:HasModifier("modifier_templar_assassin_refraction_absorb")
		then
			return BOT_ACTION_DESIRE_HIGH, Fu.GetCorrectLoc(enemyHero, castPoint)
		end
	end
	if Fu.IsInTeamFight(bot, 1300) then
		local aoeLocation = bot:FindAoELocation(true, true, bot:GetLocation(), castRange, radius, 0, 0)
		local enemiesNearLocation = Fu.GetEnemiesNearLoc(aoeLocation.targetloc, radius)
		if #enemiesNearLocation >= 2 then
			return BOT_ACTION_DESIRE_LOW, aoeLocation.targetloc
		end
	end
	if Fu.IsGoingOnSomeone(bot) and #nearbyEnemies == 1 then
		if
			Fu.IsValidHero(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(botTarget, bot, castRange)
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			return BOT_ACTION_DESIRE_HIGH, Fu.GetCorrectLoc(botTarget, castPoint)
		end
	end
	if Fu.IsRetreating(bot) and not Fu.IsRealInvisible(bot) and bot:WasRecentlyDamagedByAnyHero(3.0) then
		if
			Fu.IsValidHero(nearbyEnemies[1])
			and Fu.CanCastOnNonMagicImmune(nearbyEnemies[1])
			and Fu.IsInRange(bot, nearbyEnemies[1], castRange)
			and Fu.IsChasingTarget(nearbyEnemies[1], bot)
			and not nearbyEnemies[1]:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			return BOT_ACTION_DESIRE_HIGH, nearbyEnemies[1]:GetLocation()
		end
		local aoeLocation = bot:FindAoELocation(true, true, bot:GetLocation(), castRange - 100, radius * 1.6, castPoint, 0)
		if aoeLocation.count >= 2 and #nearbyEnemies >= 2 then
			return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
		end
	end
	local nearbyLaneCreeps = bot:GetNearbyLaneCreeps(castRange, true)
	if Fu.IsPushing(bot) and Fu.GetManaAfter(manaCost) >= 0.5 and not Fu.IsThereCoreNearby(1400) then
		if #nearbyLaneCreeps > 3 and Fu.CanBeAttacked(nearbyLaneCreeps[1]) then
			return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(nearbyLaneCreeps)
		end
	end
	if Fu.IsDefending(bot) and Fu.GetManaAfter(manaCost) >= 0.35 then
		if #nearbyLaneCreeps > 3 and Fu.CanBeAttacked(nearbyLaneCreeps[1]) then
			return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(nearbyLaneCreeps)
		end
	end
	if Fu.IsFarming(bot) and Fu.GetManaAfter(manaCost) >= 0.4 then
		local nearbyCreeps = bot:GetNearbyCreeps(castRange, true)
		if #nearbyCreeps > 2 and Fu.CanBeAttacked(nearbyCreeps[1]) then
			return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(nearbyCreeps)
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if Fu.IsRoshan(botTarget) and Fu.CanCastOnNonMagicImmune(botTarget) and Fu.IsInRange(bot, botTarget, castRange) and isAttacking then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, castRange) and isAttacking then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.ConsiderW()
	if not Fu.CanCastAbility(icePathAbility) then
		return 0
	end
	local castRange = Fu.GetProperCastRange(false, bot, icePathAbility:GetCastRange())
	local castPoint = icePathAbility:GetCastPoint()
	local manaCost = icePathAbility:GetManaCost()
	local radius = icePathAbility:GetSpecialValueInt("path_radius")
	local pathDelay = icePathAbility:GetSpecialValueFloat("path_delay")
	local damage = icePathAbility:GetSpecialValueInt("damage")
	local botTarget = Fu.GetProperTarget(bot)
	local nearbyEnemies = bot:GetNearbyHeroes(castRange + 200, true, BOT_MODE_NONE)
	local enemiesInRange = bot:GetNearbyHeroes(castRange, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(nearbyEnemies) do
		if Fu.IsValidHero(enemyHero) and Fu.IsInRange(bot, enemyHero, castRange + 200) and Fu.CanCastOnNonMagicImmune(enemyHero) then
			if enemyHero:IsChanneling() then
				return BOT_ACTION_DESIRE_HIGH, enemyHero:GetLocation()
			end
		end
	end
	if Fu.IsRetreating(bot) and not Fu.IsRealInvisible(bot) then
		if #nearbyEnemies > 0 and bot:WasRecentlyDamagedByAnyHero(2.0) then
			local aoeLocation = bot:FindAoELocation(true, true, bot:GetLocation(), castRange - 100, radius * 1.6, castPoint, 0)
			if aoeLocation.count >= 1 and #enemiesInRange >= 1 then
				return BOT_ACTION_DESIRE_LOW, aoeLocation.targetloc
			end
		end
	end
	if (Fu.IsPushing(bot) or Fu.IsDefending(bot)) and Fu.IsAllowedToSpam(bot, manaCost) then
		local nearbyLaneCreeps = bot:GetNearbyLaneCreeps(castRange, true)
		local aoeLocation = bot:FindAoELocation(true, false, bot:GetLocation(), castRange, radius, castPoint, 0)
		if aoeLocation.count >= 6 and #nearbyLaneCreeps >= 6 then
			return BOT_ACTION_DESIRE_LOW, aoeLocation.targetloc
		end
	end
	if Fu.IsInTeamFight(bot, 1300) then
		local aoeLocation = bot:FindAoELocation(true, true, bot:GetLocation(), castRange, radius, pathDelay + castPoint, 0)
		local enemiesNearLocation = Fu.GetEnemiesNearLoc(aoeLocation.targetloc, radius)
		if #enemiesNearLocation >= 2 then
			return BOT_ACTION_DESIRE_LOW, aoeLocation.targetloc
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidHero(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(botTarget, bot, castRange - 150)
			and not Fu.IsDisabled(botTarget)
			and not botTarget:HasModifier("modifier_faceless_void_chronosphere_freeze")
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			return BOT_ACTION_DESIRE_HIGH, Fu.GetCorrectLoc(botTarget, pathDelay + castPoint)
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderE()
	if not Fu.CanCastAbility(liquidFireAbility) then
		return 0
	end
	local castRange = bot:GetAttackRange() + 200
	if castRange > 1300 then
		castRange = 1300
	end
	local botTarget = Fu.GetProperTarget(bot)
	local attackTarget = bot:GetAttackTarget()
	local nearbyEnemies = bot:GetNearbyHeroes(castRange, true, BOT_MODE_NONE)
	local radius = 300
	if Fu.IsInTeamFight(bot, 1200) then
		local bestAoeTarget = nil
		local bestAoeCount = 1
		local _ = bot:GetNearbyHeroes(castRange + 299, true, BOT_MODE_NONE)
		local enemiesInCastRange = bot:GetNearbyHeroes(castRange + 43, true, BOT_MODE_NONE)
		local creepsInCastRange = bot:GetNearbyCreeps(castRange + 43, true)
		local candidateUnits = Fu.CombineTwoTable(enemiesInCastRange, creepsInCastRange)
		local mostDangerousHero = nil
		local mostDamage = 0
		for _, unit in pairs(candidateUnits) do
			if Fu.IsValid(unit) and Fu.CanCastOnNonMagicImmune(unit) then
				local enemyCount = Fu.GetAroundTargetEnemyHeroCount(unit, radius)
				if enemyCount > bestAoeCount then
					bestAoeCount = enemyCount
					bestAoeTarget = unit
				end
				if unit:IsHero() then
					local estimatedDamage = unit:GetEstimatedDamageToTarget(false, bot, 3.0, DAMAGE_TYPE_PHYSICAL)
					if estimatedDamage > mostDamage then
						mostDamage = estimatedDamage
						mostDangerousHero = unit
					end
				end
			end
		end
		if bestAoeTarget ~= nil then
			return BOT_ACTION_DESIRE_HIGH, bestAoeTarget
		end
		if mostDangerousHero ~= nil then
			return BOT_ACTION_DESIRE_HIGH, mostDangerousHero
		end
	end
	if Fu.IsValidBuilding(attackTarget) and Fu.IsInRange(attackTarget, bot, castRange) then
		return BOT_ACTION_DESIRE_HIGH, attackTarget
	end
	if attackTarget == nil and #nearbyEnemies == 0 then
		local nearbyTowers = bot:GetNearbyTowers(castRange + 36, true)
		local nearbyBarracks = bot:GetNearbyBarracks(castRange + 36, true)
		local building = nearbyTowers[1]
		if building == nil then
			building = nearbyBarracks[1]
		end
		if
			building ~= nil
			and not building:IsAttackImmune()
			and not building:IsInvulnerable()
			and not building:HasModifier("modifier_fountain_glyph")
			and not building:HasModifier("modifier_backdoor_protection_active")
		then
			return BOT_ACTION_DESIRE_HIGH, building
		end
	end
	if Fu.IsPushing(bot) or Fu.IsDefending(bot) then
		local nearbyTowers = bot:GetNearbyTowers(castRange, true)
		if Fu.IsValidBuilding(nearbyTowers[1]) and Fu.CanBeAttacked(nearbyTowers[1]) then
			return BOT_ACTION_DESIRE_HIGH, nearbyTowers[1]
		end
		local nearbyBarracks = bot:GetNearbyBarracks(castRange, true)
		if Fu.IsValidBuilding(nearbyBarracks[1]) and Fu.CanBeAttacked(nearbyBarracks[1]) then
			return BOT_ACTION_DESIRE_HIGH, nearbyBarracks[1]
		end
		local nearbyLaneCreeps = bot:GetNearbyLaneCreeps(castRange, true)
		if #nearbyLaneCreeps >= 2 and Fu.IsValid(nearbyLaneCreeps[1]) and Fu.CanBeAttacked(nearbyLaneCreeps[1]) then
			return BOT_ACTION_DESIRE_HIGH, nearbyLaneCreeps[1]
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if Fu.IsValidHero(botTarget) and Fu.CanCastOnNonMagicImmune(botTarget) and Fu.IsInRange(botTarget, bot, castRange) then
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if Fu.IsRoshan(botTarget) and Fu.CanCastOnNonMagicImmune(botTarget) and Fu.IsInRange(bot, botTarget, radius) and isAttacking then
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, radius) and isAttacking then
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderAS()
	if not Fu.CanCastAbility(liquidFrostAbility) then
		return 0
	end
	local castRange = bot:GetAttackRange() + 200
	if castRange > 1300 then
		castRange = 1300
	end
	local botTarget = Fu.GetProperTarget(bot)
	-- datafeed: Liquid Frost "does not apply to buildings", so the tower/barracks branches copied from
	-- Liquid Fire (ConsiderE, which already covers buildings) were removed; heroes only.
	if Fu.IsGoingOnSomeone(bot) then
		if Fu.IsValidHero(botTarget) and Fu.CanCastOnNonMagicImmune(botTarget) and Fu.IsInRange(botTarget, bot, castRange) then
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderR()
	if not Fu.CanCastAbility(macropyreAbility) then
		return 0
	end
	local castRange = Fu.GetProperCastRange(false, bot, macropyreAbility:GetCastRange())
	if castRange > 1500 then
		castRange = 1500
	end
	local castPoint = macropyreAbility:GetCastPoint()
	local manaCost = macropyreAbility:GetManaCost()
	-- datafeed: Macropyre has no "path_radius" (it read 0, killing the AoE checks); half its "path_width" (500)
	local radius = macropyreAbility:GetSpecialValueInt("path_width") / 2
	local damage = macropyreAbility:GetSpecialValueInt("damage")
	local botTarget = Fu.GetProperTarget(bot)
	local nearbyEnemies = bot:GetNearbyHeroes(castRange, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(nearbyEnemies) do
		if Fu.IsValidHero(enemyHero) and Fu.GetHP(bot) > 0.5 and not Fu.IsSuspiciousIllusion(enemyHero) then
			if
				enemyHero:HasModifier("modifier_faceless_void_chronosphere_freeze")
				or enemyHero:HasModifier("modifier_enigma_black_hole_pull")
			then
				return BOT_ACTION_DESIRE_HIGH, enemyHero:GetLocation()
			end
		end
	end
	if Fu.IsRetreating(bot) and not Fu.IsRealInvisible(bot) then
		if #nearbyEnemies > 0 and bot:WasRecentlyDamagedByAnyHero(2.0) then
			local aoeLocation = bot:FindAoELocation(true, true, bot:GetLocation(), castRange - 100, radius * 1.6, castPoint, 0)
			local enemiesNearLocation = Fu.GetEnemiesNearLoc(aoeLocation.targetloc, radius)
			if #enemiesNearLocation >= 2 then
				return BOT_ACTION_DESIRE_LOW, aoeLocation.targetloc
			end
		end
	end
	if Fu.IsPushing(bot) or Fu.IsDefending(bot) then
		local aoeLocation = bot:FindAoELocation(true, true, bot:GetLocation(), castRange, radius, castPoint, 0)
		if aoeLocation.count >= 2 then
			local enemyList = Fu.GetEnemyList(bot, 1200)
			if #enemyList >= 2 then
				return BOT_ACTION_DESIRE_LOW, aoeLocation.targetloc
			end
		end
	end
	if Fu.IsInTeamFight(bot, 1300) then
		local aoeLocation = bot:FindAoELocation(true, true, bot:GetLocation(), castRange, radius, castPoint, 0)
		if aoeLocation.count >= 2 then
			local enemyList = Fu.GetEnemyList(bot, 1300)
			if #enemyList >= 2 then
				return BOT_ACTION_DESIRE_LOW, aoeLocation.targetloc
			end
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidHero(botTarget)
			and botTarget:GetHealth() > 600
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(botTarget, bot, castRange - 200)
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			local targetAllies = botTarget:GetNearbyHeroes(2 * radius, false, BOT_MODE_NONE)
			if #targetAllies >= 2 or Fu.IsInRange(botTarget, bot, 600) then
				return BOT_ACTION_DESIRE_HIGH, Fu.GetCorrectLoc(botTarget, castPoint)
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
return X
