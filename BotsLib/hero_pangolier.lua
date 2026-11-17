-- Pangolier: skill build, item build, and ability use for this hero.
local X = {}
local bot = GetBot()
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local AbilityContext = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local Minion = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local sTalentList = Fu.Skill.GetTalentList(bot)
local sAbilityList = Fu.Skill.GetAbilityList(bot)
local sRole = Fu.Item.GetRoleItemsBuyList(bot)
local tTalentTreeList = {
	{ ["t25"] = { 10, 0 }, ["t20"] = { 0, 10 }, ["t15"] = { 0, 10 }, ["t10"] = { 10, 0 } },
	{ ["t25"] = { 10, 0 }, ["t20"] = { 10, 0 }, ["t15"] = { 0, 10 }, ["t10"] = { 10, 0 } },
}
local tAllAbilityBuildList = { { 2, 1, 2, 1, 1, 6, 1, 2, 2, 3, 6, 3, 3, 3, 6 }, { 2, 1, 3, 2, 2, 6, 2, 1, 1, 1, 6, 3, 3, 3, 6 } }
local nAbilityBuildList
local nTalentBuildList
if sRole == "pos_2" then
	nAbilityBuildList = tAllAbilityBuildList[1]
	nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList[1])
else
	nAbilityBuildList = tAllAbilityBuildList[2]
	nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList[2])
end
local sUtility = "item_team_aura"
local sRoleItemsBuyList = {}
sRoleItemsBuyList["pos_2"] = {
	"item_tango",
	"item_double_branches",
	"item_quelling_blade",
	"item_faerie_fire",
	"item_bottle",
	"item_magic_wand",
	-- Power Treads instead of Arcane Boots: 80% vs 12% of his matches (Dotabuff, last patch).
	"item_power_treads",
	"item_diffusal_blade",
	"item_mage_slayer",
	"item_blink",
	"item_ultimate_scepter",
	"item_aghanims_shard",
	"item_basher",
	"item_disperser",
	"item_octarine_core",
	"item_abyssal_blade",
	"item_ultimate_scepter_2",
	"item_travel_boots",
	"item_moon_shard",
	"item_overwhelming_blink",
	"item_travel_boots_2",
}
sRoleItemsBuyList["pos_3"] = {
	"item_quelling_blade",
	"item_tango",
	"item_double_branches",
	"item_bracer",
	"item_power_treads",
	"item_magic_wand",
	"item_diffusal_blade",
	"item_blink",
	sUtility,
	"item_mage_slayer",
	"item_ultimate_scepter",
	"item_aghanims_shard",
	"item_octarine_core",
	"item_disperser",
	"item_ultimate_scepter_2",
	"item_travel_boots",
	"item_moon_shard",
	"item_overwhelming_blink",
	"item_travel_boots_2",
}
sRoleItemsBuyList["pos_1"] = sRoleItemsBuyList["pos_3"]
sRoleItemsBuyList["pos_4"] = sRoleItemsBuyList["pos_3"]
sRoleItemsBuyList["pos_5"] = sRoleItemsBuyList["pos_3"]
X["sBuyList"] = sRoleItemsBuyList[sRole]
X["sSellList"] = { "item_black_king_bar", "item_quelling_blade" }
if Fu.Role.IsPvNMode() or Fu.Role.IsAllShadow() then
	X["sBuyList"], X["sSellList"] = { "PvN_mid" }, {}
end
nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"] = Fu.SetUserHeroInit(nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"])
X["sSkillList"] = Fu.Skill.GetSkillList(sAbilityList, nAbilityBuildList, sTalentList, nTalentBuildList)
X["bDeafaultAbility"] = false
X["bDeafaultItem"] = false
function X.MinionThink(minionUnit)
	if Minion.IsValidUnit(minionUnit) then
		Minion.IllusionThink(minionUnit)
	end
end
local swashbuckleAbility = SafeAbility(bot:GetAbilityByName("pangolier_swashbuckle"), "pangolier_swashbuckle", "pangolier")
local shieldCrashAbility = SafeAbility(bot:GetAbilityByName("pangolier_shield_crash"), "pangolier_shield_crash", "pangolier")
local rollUpAbility = SafeAbility(bot:GetAbilityByName("pangolier_rollup"), "pangolier_rollup", "pangolier")
local endRollUpAbility = SafeAbility(bot:GetAbilityByName("pangolier_rollup_stop"), "pangolier_rollup_stop", "pangolier")
local rollingThunderAbility = SafeAbility(bot:GetAbilityByName("pangolier_gyroshell"), "pangolier_gyroshell", "pangolier")
local endRollingThunderAbility = SafeAbility(bot:GetAbilityByName("pangolier_gyroshell_stop"), "pangolier_gyroshell_stop", "pangolier")
local swashbuckleDesire, swashbuckleLocation
local shieldCrashDesire
local rollUpDesire
local endRollUpDesire
local rollingThunderDesire
local endRollingThunderDesire
local botTarget
local isRetreating
local isAttacking
local hpRatio
local mpRatio
local isInTeamFight
function X.SkillsComplement()
	if Fu.CanNotUseAbility(bot) then
		return
	end
	isRetreating = Fu.IsRetreating(bot)
	isAttacking = Fu.IsAttacking(bot)
	hpRatio = Fu.GetHP(bot)
	mpRatio = Fu.GetMP(bot)
	isInTeamFight = Fu.IsInTeamFight(bot, 1200)
	swashbuckleAbility = SafeAbility(bot:GetAbilityByName("pangolier_swashbuckle"), "pangolier_swashbuckle", "pangolier")
	shieldCrashAbility = SafeAbility(bot:GetAbilityByName("pangolier_shield_crash"), "pangolier_shield_crash", "pangolier")
	rollUpAbility = SafeAbility(bot:GetAbilityByName("pangolier_rollup"), "pangolier_rollup", "pangolier")
	endRollUpAbility = SafeAbility(bot:GetAbilityByName("pangolier_rollup_stop"), "pangolier_rollup_stop", "pangolier")
	rollingThunderAbility = SafeAbility(bot:GetAbilityByName("pangolier_gyroshell"), "pangolier_gyroshell", "pangolier")
	endRollingThunderAbility = SafeAbility(bot:GetAbilityByName("pangolier_gyroshell_stop"), "pangolier_gyroshell_stop", "pangolier")
	botTarget = Fu.GetProperTarget(bot)
	local botHp = hpRatio
	local allyHeroes = Fu.GetNearbyHeroes(bot, 1600, false, BOT_MODE_NONE)
	local enemyHeroes = Fu.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE)
	endRollUpDesire = X.ConsiderEndRollUp()
	if endRollUpDesire > 0 then
		bot:Action_UseAbility(endRollUpAbility)
		return
	end
	rollUpDesire = X.ConsiderRollUp()
	if rollUpDesire > 0 then
		bot:Action_UseAbility(rollUpAbility)
		return
	end
	endRollingThunderDesire = X.ConsiderEndRollingThunder()
	if endRollingThunderDesire > 0 then
		bot:Action_UseAbility(endRollingThunderAbility)
		return
	end
	rollingThunderDesire = X.ConsiderRollingThunder()
	if rollingThunderDesire > 0 then
		bot:Action_UseAbility(rollingThunderAbility)
		return
	end
	shieldCrashDesire = X.ConsiderShieldCrash()
	if shieldCrashDesire > 0 then
		bot:Action_UseAbility(shieldCrashAbility)
		return
	end
	swashbuckleDesire, swashbuckleLocation = X.ConsiderSwashbuckle()
	if swashbuckleDesire > 0 then
		bot:Action_UseAbilityOnLocation(swashbuckleAbility, swashbuckleLocation)
		return
	end
end
function X.ConsiderSwashbuckle()
	if
		not swashbuckleAbility:IsFullyCastable()
		or bot:HasModifier("modifier_pangolier_gyroshell")
		or bot:HasModifier("modifier_pangolier_swashbuckle_stunned")
	then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local dashRange = swashbuckleAbility:GetSpecialValueInt("dash_range")
	local strikeRange = swashbuckleAbility:GetSpecialValueInt("range")
	local radius = 140
	local damage = swashbuckleAbility:GetSpecialValueInt("damage")
	local strikes = swashbuckleAbility:GetSpecialValueInt("strikes")
	botTarget = Fu.GetProperTarget(bot)
	local enemyHeroes = Fu.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(enemyHeroes) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanKillTarget(enemyHero, damage * strikes, DAMAGE_TYPE_PHYSICAL)
			and not Fu.IsSuspiciousIllusion(enemyHero)
			and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
			and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
			and not enemyHero:HasModifier("modifier_enigma_black_hole_pull")
			and not enemyHero:HasModifier("modifier_faceless_void_chronosphere_freeze")
			and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
			and not enemyHero:HasModifier("modifier_templar_assassin_refraction_absorb")
		then
			if bot:IsFacingLocation(enemyHero:GetLocation(), 25) then
				if Fu.IsInRange(bot, enemyHero, dashRange) then
					return BOT_ACTION_DESIRE_HIGH, bot:GetLocation()
				end
				if
					Fu.IsInRange(bot, enemyHero, dashRange + strikeRange)
					and not Fu.IsInRange(bot, enemyHero, dashRange)
					and not enemyHero:HasModifier("modifier_faceless_void_chronosphere_freeze")
				then
					return BOT_ACTION_DESIRE_HIGH, Fu.Site.GetXUnitsTowardsLocation(bot, enemyHero:GetLocation(), dashRange)
				end
			end
		end
	end
	if Fu.IsStuck(bot) then
		local escapeLocation = Fu.GetEscapeLoc()
		return BOT_ACTION_DESIRE_HIGH, Fu.Site.GetXUnitsTowardsLocation(bot, escapeLocation, dashRange)
	end
	if Fu.IsGoingOnSomeone(bot) then
		local weakestTarget = Fu.GetVulnerableWeakestUnit(bot, true, true, 1200)
		local allyHeroes = Fu.GetNearbyHeroes(bot, 1000, false, BOT_MODE_NONE)
		if
			Fu.IsValidTarget(weakestTarget)
			and not Fu.IsSuspiciousIllusion(weakestTarget)
			and not weakestTarget:HasModifier("modifier_abaddon_borrowed_time")
			and not weakestTarget:HasModifier("modifier_dazzle_shallow_grave")
			and not weakestTarget:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			local targetAllies = Fu.GetNearbyHeroes(weakestTarget, 800, false, BOT_MODE_NONE)
			if allyHeroes ~= nil and targetAllies ~= nil and #allyHeroes >= #targetAllies and bot:IsFacingLocation(weakestTarget:GetLocation(), 30) then
				if Fu.IsInRange(bot, weakestTarget, dashRange) then
					if #allyHeroes >= #targetAllies + 2 then
						return BOT_ACTION_DESIRE_HIGH, weakestTarget:GetLocation()
					else
						return BOT_ACTION_DESIRE_HIGH, bot:GetLocation()
					end
				end
				if
					Fu.IsInRange(bot, weakestTarget, dashRange + strikeRange)
					and not Fu.IsInRange(bot, weakestTarget, dashRange)
					and not weakestTarget:HasModifier("modifier_faceless_void_chronosphere_freeze")
				then
					return BOT_ACTION_DESIRE_HIGH, Fu.Site.GetXUnitsTowardsLocation(bot, weakestTarget:GetLocation(), dashRange)
				end
			end
		end
	end
	if isRetreating then
		local allyHeroes = Fu.GetNearbyHeroes(bot, 800, false, BOT_MODE_NONE)
		local enemyHeroes = Fu.GetNearbyHeroes(bot, 1000, true, BOT_MODE_NONE)
		if
			allyHeroes ~= nil
			and enemyHeroes
			and Fu.IsValidHero(enemyHeroes[1])
			and not Fu.IsSuspiciousIllusion(enemyHeroes[1])
			and not Fu.IsDisabled(enemyHeroes[1])
			and not enemyHeroes[1]:HasModifier("modifier_enigma_black_hole_pull")
			and not enemyHeroes[1]:HasModifier("modifier_faceless_void_chronosphere_freeze")
			and not enemyHeroes[1]:HasModifier("modifier_legion_commander_duel")
			and not enemyHeroes[1]:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			local firstEnemyAllies = Fu.GetNearbyHeroes(enemyHeroes[1], 1000, false, BOT_MODE_NONE)
			if firstEnemyAllies ~= nil and (#firstEnemyAllies > #allyHeroes or hpRatio < 0.68 and bot:WasRecentlyDamagedByAnyHero(1.6)) then
				local escapeLocation = Fu.GetEscapeLoc()
				return BOT_ACTION_DESIRE_HIGH, Fu.Site.GetXUnitsTowardsLocation(bot, escapeLocation, dashRange)
			end
		end
	end
	if Fu.IsPushing(bot) or Fu.IsDefending(bot) then
		local aoe = bot:FindAoELocation(true, false, bot:GetLocation(), strikeRange, radius, 0, 0)
		local laneCreeps = bot:GetNearbyLaneCreeps(strikeRange, true)
		local enemyHeroes = Fu.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE)
		if laneCreeps ~= nil and #laneCreeps >= 4 and aoe.count >= 4 and enemyHeroes ~= nil and #enemyHeroes == 0 and bot:IsFacingLocation(aoe.targetloc, 10) then
			return BOT_ACTION_DESIRE_HIGH, bot:GetLocation()
		end
		aoe = bot:FindAoELocation(true, true, bot:GetLocation(), strikeRange, radius, 0, 0)
		if aoe.count >= 1 and bot:IsFacingLocation(aoe.targetloc, 10) then
			return BOT_ACTION_DESIRE_HIGH, bot:GetLocation()
		end
	end
	if Fu.IsFarming(bot) and mpRatio > 0.33 then
		local aoe = bot:FindAoELocation(true, false, bot:GetLocation(), strikeRange, radius, 0, 0)
		local neutralCreeps = bot:GetNearbyNeutralCreeps(strikeRange)
		if
			neutralCreeps ~= nil
			and (#neutralCreeps >= 3 and aoe.count >= 3 or #neutralCreeps >= 2 and neutralCreeps[1]:IsAncientCreep() and aoe.count >= 2)
			and bot:IsFacingLocation(aoe.targetloc, 10)
		then
			return BOT_ACTION_DESIRE_HIGH, aoe.targetloc
		end
		local laneCreeps = bot:GetNearbyLaneCreeps(strikeRange, true)
		if laneCreeps ~= nil and #laneCreeps >= 3 and aoe.count >= 3 and bot:IsFacingLocation(aoe.targetloc, 10) then
			return BOT_ACTION_DESIRE_HIGH, bot:GetLocation()
		end
	end
	if Fu.IsLaning(bot) and mpRatio > 0.33 then
		local killableCount = 0
		local enemyHeroes = Fu.GetNearbyHeroes(bot, 800, true, BOT_MODE_NONE)
		local searchRange = dashRange + strikeRange
		if searchRange > 1600 then
			searchRange = 1600
		end
		local laneCreeps = bot:GetNearbyLaneCreeps(searchRange, true)
		for _, creep in pairs(laneCreeps) do
			if Fu.IsValid(creep) and creep:GetHealth() <= damage * strikes then
				killableCount = killableCount + 1
			end
		end
		local aoe = bot:FindAoELocation(true, false, bot:GetLocation(), 1000, radius, 0, 0)
		if killableCount >= 2 and enemyHeroes ~= nil and #enemyHeroes >= 1 and aoe.count >= 2 and bot:IsFacingLocation(aoe.targetloc, 15) then
			if GetUnitToLocationDistance(bot, aoe.targetloc) <= dashRange then
				return BOT_ACTION_DESIRE_HIGH, bot:GetLocation()
			end
			if
				GetUnitToLocationDistance(bot, aoe.targetloc) <= dashRange + strikeRange
				and GetUnitToLocationDistance(bot, aoe.targetloc) > dashRange
			then
				return BOT_ACTION_DESIRE_HIGH, Fu.Site.GetXUnitsTowardsLocation(bot, aoe.targetloc, dashRange)
			end
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if Fu.IsRoshan(botTarget) and Fu.IsInRange(bot, botTarget, 500) and isAttacking and bot:IsFacingLocation(botTarget:GetLocation(), 10) then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, 400) and isAttacking and bot:IsFacingLocation(botTarget:GetLocation(), 10) then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.ConsiderShieldCrash()
	if not shieldCrashAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
	end
	local radius = shieldCrashAbility:GetSpecialValueInt("radius")
	local damage = shieldCrashAbility:GetSpecialValueInt("damage")
	local abilityLevel = shieldCrashAbility:GetLevel()
	botTarget = Fu.GetProperTarget(bot)
	if Fu.IsStuck(bot) then
		return BOT_ACTION_DESIRE_HIGH
	end
	if bot:HasModifier("modifier_pangolier_rollup") then
		local enemiesNear = Fu.GetEnemiesNearLoc(bot:GetLocation(), radius)
		if enemiesNear ~= nil and #enemiesNear >= 2 then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if isInTeamFight then
		local enemiesNear = Fu.GetEnemiesNearLoc(bot:GetLocation(), radius)
		if enemiesNear ~= nil and #enemiesNear >= 2 and not bot:HasModifier("modifier_pangolier_gyroshell") then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		local weakestTarget = Fu.GetVulnerableWeakestUnit(bot, true, true, radius)
		local allyHeroes = Fu.GetNearbyHeroes(bot, 800, false, BOT_MODE_NONE)
		if
			Fu.IsValidTarget(weakestTarget)
			and bot:HasModifier("modifier_pangolier_gyroshell")
			and bot:IsFacingLocation(weakestTarget:GetLocation(), 5)
		then
			local targetLocation = weakestTarget:GetLocation()
			if IsLocationPassable(targetLocation) then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
		if
			Fu.IsValidTarget(weakestTarget)
			and not Fu.IsSuspiciousIllusion(weakestTarget)
			and not weakestTarget:HasModifier("modifier_abaddon_borrowed_time")
			and not weakestTarget:HasModifier("modifier_dazzle_shallow_grave")
			and not weakestTarget:HasModifier("modifier_necrolyte_reapers_scythe")
			and not weakestTarget:HasModifier("modifier_templar_assassin_refraction_absorb")
		then
			local targetAllies = Fu.GetNearbyHeroes(weakestTarget, 1200, false, BOT_MODE_NONE)
			if allyHeroes ~= nil and targetAllies ~= nil and #allyHeroes >= #targetAllies and bot:IsFacingLocation(weakestTarget:GetLocation(), 30) then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	if isRetreating then
		local allyHeroes = Fu.GetNearbyHeroes(bot, 800, false, BOT_MODE_NONE)
		local enemyHeroes = Fu.GetNearbyHeroes(bot, 1000, true, BOT_MODE_NONE)
		if
			allyHeroes ~= nil
			and enemyHeroes
			and Fu.IsValidHero(enemyHeroes[1])
			and not Fu.IsSuspiciousIllusion(enemyHeroes[1])
			and not enemyHeroes[1]:HasModifier("modifier_enigma_black_hole_pull")
			and not enemyHeroes[1]:HasModifier("modifier_faceless_void_chronosphere_freeze")
			and not enemyHeroes[1]:HasModifier("modifier_legion_commander_duel")
			and not enemyHeroes[1]:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			local firstEnemyAllies = Fu.GetNearbyHeroes(enemyHeroes[1], 1000, false, BOT_MODE_NONE)
			if
				firstEnemyAllies ~= nil
				and (#firstEnemyAllies > #allyHeroes or hpRatio < 0.68 and bot:WasRecentlyDamagedByAnyHero(1.6))
				and bot:IsFacingLocation(Fu.GetEscapeLoc(), 30)
			then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	if Fu.IsPushing(bot) or Fu.IsDefending(bot) then
		local laneCreeps = bot:GetNearbyLaneCreeps(radius, true)
		if isAttacking then
			if laneCreeps ~= nil and #laneCreeps >= 4 and bot:IsFacingLocation(laneCreeps[1]:GetLocation(), 30) then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	if Fu.IsFarming(bot) and mpRatio > 0.33 and abilityLevel >= 2 then
		if isAttacking then
			local neutralCreeps = bot:GetNearbyNeutralCreeps(radius)
			if
				neutralCreeps ~= nil
				and (#neutralCreeps >= 3 or #neutralCreeps >= 2 and neutralCreeps[1]:IsAncientCreep())
				and bot:IsFacingLocation(neutralCreeps[1]:GetLocation(), 15)
			then
				return BOT_ACTION_DESIRE_HIGH
			end
			local laneCreeps = bot:GetNearbyLaneCreeps(radius, true)
			if laneCreeps ~= nil and #laneCreeps >= 3 and bot:IsFacingLocation(laneCreeps[1]:GetLocation(), 15) then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	if Fu.IsLaning(bot) then
		local killableCount = 0
		local killableCreeps = {}
		local laneCreeps = bot:GetNearbyLaneCreeps(radius, true)
		local enemyHeroes = Fu.GetNearbyHeroes(bot, 800, true, BOT_MODE_NONE)
		for _, creep in pairs(laneCreeps) do
			if Fu.IsValid(creep) and creep:GetHealth() <= damage then
				if
					mpRatio > 0.33
					and bot:IsFacingLocation(creep:GetLocation(), 15)
					and not Fu.IsInRange(bot, creep, bot:GetAttackRange())
					and not isAttacking
				then
					return BOT_ACTION_DESIRE_HIGH
				end
				killableCount = killableCount + 1
				table.insert(killableCreeps, creep)
			end
		end
		if killableCount >= 2 and mpRatio > 0.25 and enemyHeroes ~= nil and #enemyHeroes >= 1 and bot:IsFacingLocation(Fu.GetCenterOfUnits(killableCreeps), 15) then
			return BOT_ACTION_DESIRE_HIGH
		end
		if enemyHeroes ~= nil and #enemyHeroes >= 1 and bot:IsFacingLocation(enemyHeroes[1]:GetLocation(), 15) and Fu.IsInRange(bot, enemyHeroes[1], radius) then
			local enemyTowers = enemyHeroes[1]:GetNearbyTowers(700, false)
			if enemyTowers ~= nil and #enemyTowers == 0 then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if Fu.IsRoshan(botTarget) and Fu.IsInRange(bot, botTarget, 500) and isAttacking and bot:IsFacingLocation(botTarget:GetLocation(), 15) then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, 400) and isAttacking and bot:IsFacingLocation(botTarget:GetLocation(), 15) then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderRollingThunder()
	if not rollingThunderAbility:IsFullyCastable() or bot:HasModifier("modifier_bloodseeker_rupture") then
		return BOT_ACTION_DESIRE_NONE
	end
	if isInTeamFight then
		local enemiesNear = Fu.GetEnemiesNearLoc(bot:GetLocation(), 1200)
		if enemiesNear ~= nil and #enemiesNear >= 2 then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if isRetreating then
		local allyHeroes = Fu.GetNearbyHeroes(bot, 800, false, BOT_MODE_NONE)
		local enemyHeroes = Fu.GetNearbyHeroes(bot, 1000, true, BOT_MODE_NONE)
		if
			allyHeroes ~= nil
			and enemyHeroes
			and Fu.IsValidHero(enemyHeroes[1])
			and Fu.IsRunning(enemyHeroes[1])
			and enemyHeroes[1]:IsFacingLocation(bot:GetLocation(), 30)
			and not Fu.IsSuspiciousIllusion(enemyHeroes[1])
		then
			local firstEnemyAllies = Fu.GetNearbyHeroes(enemyHeroes[1], 1000, false, BOT_MODE_NONE)
			if firstEnemyAllies ~= nil and (#firstEnemyAllies > #allyHeroes and (hpRatio < 0.55 and bot:WasRecentlyDamagedByAnyHero(2))) then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderEndRollingThunder()
	if endRollingThunderAbility:IsHidden() or not endRollingThunderAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
	end
	local enemyHeroes = Fu.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE)
	if enemyHeroes ~= nil and #enemyHeroes == 0 then
		return BOT_ACTION_DESIRE_HIGH
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderRollUp()
	if not rollUpAbility:IsTrained() or rollUpAbility:IsHidden() or not rollUpAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
	end
	if Fu.IsUnitTargetProjectileIncoming(bot, 400) then
		return BOT_ACTION_DESIRE_HIGH
	end
	if not bot:HasModifier("modifier_sniper_assassinate") and not bot:IsMagicImmune() then
		if Fu.IsWillBeCastUnitTargetSpell(bot, 1400) then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if isInTeamFight then
		local enemiesNear = Fu.GetEnemiesNearLoc(bot:GetLocation(), 800)
		if enemiesNear ~= nil and #enemiesNear >= 3 then
			return BOT_ACTION_DESIRE_HIGH
		end
		local weakestTarget = Fu.GetVulnerableWeakestUnit(bot, true, true, 1200)
		if Fu.IsValidTarget(weakestTarget) and not Fu.IsSuspiciousIllusion(weakestTarget) then
			if bot:HasModifier("modifier_pangolier_gyroshell") and not bot:IsFacingLocation(weakestTarget:GetLocation(), 90) then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderEndRollUp()
	if endRollUpAbility:IsHidden() or not endRollUpAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
	end
	if isInTeamFight then
		local weakestTarget = Fu.GetVulnerableWeakestUnit(bot, true, true, 1200)
		if Fu.IsValidTarget(weakestTarget) and not Fu.IsSuspiciousIllusion(weakestTarget) then
			if bot:HasModifier("modifier_pangolier_roll") and bot:IsFacingLocation(weakestTarget:GetLocation(), 15) then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
return X
