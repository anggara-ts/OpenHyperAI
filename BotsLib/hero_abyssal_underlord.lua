-- Abyssal Underlord: skill build, item build, and ability use for this hero.
local X = {}
local bot = GetBot()
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local AbilityContext = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local Minion = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local sTalentList = Fu.Skill.GetTalentList(bot)
local sAbilityList = Fu.Skill.GetAbilityList(bot)
local sRole = Fu.Item.GetRoleItemsBuyList(bot)
local tTalentTreeList = { ["t25"] = { 0, 10 }, ["t20"] = { 0, 10 }, ["t15"] = { 10, 0 }, ["t10"] = { 10, 0 } }
local tAllAbilityBuildList = { { 1, 3, 1, 2, 1, 6, 1, 2, 2, 2, 6, 3, 3, 3, 6 } }
local nAbilityBuildList = Fu.Skill.GetRandomBuild(tAllAbilityBuildList)
local nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList)
local sRoleItemsBuyList = {}
local sUtilityList = { "item_lotus_orb", "item_crimson_guard", "item_heavens_halberd" }
local sUtility = sUtilityList[RandomInt(1, #sUtilityList)]
-- Stratz 7.41f, week of 9 Nov 2026: pos 1 has 466 matches, built from pos 3 (83,563) (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_1"] = {
	"item_tango",
	"item_double_gauntlets",
	"item_double_branches",
	"item_quelling_blade",
	"item_bracer",
	"item_soul_ring",
	"item_magic_wand",
	"item_arcane_boots",
	"item_rod_of_atos",
	"item_ultimate_scepter",
	"item_aghanims_shard",
	"item_shivas_guard",
	"item_ultimate_scepter_2",
	"item_blade_mail",
	"item_crimson_guard",
	"item_octarine_core",
	"item_moon_shard",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 2, 2,344 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_2"] = {
	"item_tango",
	"item_double_branches",
	"item_gauntlets",
	"item_quelling_blade",
	"item_circlet",
	"item_soul_ring",
	"item_magic_wand",
	"item_arcane_boots",
	"item_rod_of_atos",
	"item_ultimate_scepter",
	"item_aghanims_shard",
	"item_gungir",
	"item_shivas_guard",
	"item_ultimate_scepter_2",
	"item_heart",
	"item_octarine_core",
	"item_harpoon",
	"item_moon_shard",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 3, 83,563 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_3"] = {
	"item_tango",
	"item_double_gauntlets",
	"item_double_branches",
	"item_quelling_blade",
	"item_bracer",
	"item_soul_ring",
	"item_magic_wand",
	"item_arcane_boots",
	"item_rod_of_atos",
	"item_ultimate_scepter",
	"item_aghanims_shard",
	"item_shivas_guard",
	"item_ultimate_scepter_2",
	"item_blade_mail",
	"item_crimson_guard",
	"item_octarine_core",
	"item_moon_shard",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 4, 6,352 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_4"] = {
	"item_tango",
	"item_magic_stick",
	"item_branches",
	"item_gauntlets",
	"item_magic_wand",
	"item_ring_of_basilius",
	"item_arcane_boots",
	"item_headdress",
	"item_rod_of_atos",
	"item_mekansm",
	"item_aghanims_shard",
	"item_ultimate_scepter",
	"item_guardian_greaves",
	sUtility,
	"item_vanguard",
	"item_ultimate_scepter_2",
	"item_heart",
	"item_veil_of_discord",
	"item_moon_shard",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 5, 3,717 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_5"] = {
	"item_tango",
	"item_magic_stick",
	"item_branches",
	"item_gauntlets",
	"item_magic_wand",
	"item_ring_of_basilius",
	"item_arcane_boots",
	"item_headdress",
	"item_rod_of_atos",
	"item_mekansm",
	"item_aghanims_shard",
	"item_ultimate_scepter",
	"item_guardian_greaves",
	"item_ultimate_scepter_2",
	"item_crimson_guard",
	"item_heart",
	"item_lotus_orb",
	"item_moon_shard",
}
X["sBuyList"] = sRoleItemsBuyList[sRole]
X["sSellList"] = {
	"item_travel_boots",
	"item_quelling_blade",
	"item_abyssal_blade",
	"item_magic_wand",
	"item_shivas_guard",
	"item_bracer",
	"item_assault",
	"item_soul_ring",
}
if Fu.Role.IsPvNMode() or Fu.Role.IsAllShadow() then
	X["sBuyList"], X["sSellList"] = { "PvN_antimage" }, {}
end
nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"] =
	Fu.SetUserHeroInit(nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"])
X["sSkillList"] = Fu.Skill.GetSkillList(sAbilityList, nAbilityBuildList, sTalentList, nTalentBuildList)
X["bDeafaultAbility"] = false
X["bDeafaultItem"] = false
function X.MinionThink(hMinionUnit)
	Minion.MinionThink(hMinionUnit)
end
local firestormAbility =
	SafeAbility(bot:GetAbilityByName("abyssal_underlord_firestorm"), "abyssal_underlord_firestorm", "abyssal_underlord")
local pitOfMaliceAbility = SafeAbility(
	bot:GetAbilityByName("abyssal_underlord_pit_of_malice"),
	"abyssal_underlord_pit_of_malice",
	"abyssal_underlord"
)
local fiendsGateAbility = SafeAbility(
	bot:GetAbilityByName("abyssal_underlord_dark_portal"),
	"abyssal_underlord_dark_portal",
	"abyssal_underlord"
)
local firestormDesire, firestormLocation
local pitOfMaliceDesire, pitOfMaliceLocation
local fiendsGateDesire, fiendsGateLocation
local botTarget
local isGoingOnSomeone
local isAttacking
local mpRatio
function X.SkillsComplement()
	if Fu.CanNotUseAbility(bot) then
		return
	end
	local context = AbilityContext.Build(bot)
	isGoingOnSomeone = context.isEngaging
	isAttacking = Fu.IsAttacking(bot)
	mpRatio = context.mp
	botTarget = context.target
	pitOfMaliceDesire, pitOfMaliceLocation = X.ConsiderPitOfMalice()
	if pitOfMaliceDesire > 0 then
		bot:Action_UseAbilityOnLocation(pitOfMaliceAbility, pitOfMaliceLocation)
		return
	end
	firestormDesire, firestormLocation = X.ConsiderFirestorm()
	if firestormDesire > 0 then
		bot:Action_UseAbilityOnLocation(firestormAbility, firestormLocation)
		return
	end
	fiendsGateDesire, fiendsGateLocation = X.ConsiderFiendsGate()
	if fiendsGateDesire > 0 then
		bot:Action_UseAbilityOnLocation(fiendsGateAbility, fiendsGateLocation)
		return
	end
end
-- fix: Firestorm and Pit were aimed with GetXUnitsTowardsLocation(bot, loc, castRange), which always returns a
-- point exactly castRange (cast range 675 + 200) from Underlord, so a close enemy group was missed by ~400+
-- units (radius 425 / 400). Aim at the spot itself; clamp to castRange only when it is beyond it (far targets as before).
function X.CastSpot(loc, castRange)
	if GetUnitToLocationDistance(bot, loc) <= castRange then
		return loc
	end
	return Fu.Site.GetXUnitsTowardsLocation(bot, loc, castRange)
end
function X.ConsiderFirestorm()
	if not firestormAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local castRange = Fu.GetProperCastRange(false, bot, firestormAbility:GetCastRange())
	local radius = firestormAbility:GetSpecialValueInt("radius")
	local castPoint = firestormAbility:GetCastPoint()
	if Fu.IsInTeamFight(bot, 1200) then
		local aoe = bot:FindAoELocation(true, true, bot:GetLocation(), castRange + radius, radius, castPoint, 0)
		local enemiesInAoe = Fu.GetEnemiesNearLoc(aoe.targetloc, radius)
		if enemiesInAoe ~= nil and #enemiesInAoe >= 2 then
			return BOT_ACTION_DESIRE_HIGH, X.CastSpot(aoe.targetloc, castRange)
		end
	end
	if isGoingOnSomeone then
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange + radius)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			local alliesNearTarget = Fu.GetNearbyHeroes(botTarget, 1200, true, BOT_MODE_NONE)
			local enemiesNearTarget = Fu.GetNearbyHeroes(botTarget, 1200, false, BOT_MODE_NONE)
			if alliesNearTarget ~= nil and enemiesNearTarget ~= nil and #alliesNearTarget >= #enemiesNearTarget then
				enemiesNearTarget = Fu.GetEnemiesNearLoc(botTarget:GetLocation(), castRange + radius)
				if enemiesNearTarget ~= nil and #enemiesNearTarget >= 1 then
					return BOT_ACTION_DESIRE_HIGH, X.CastSpot(Fu.GetCenterOfUnits(enemiesNearTarget), castRange)
				end
				return BOT_ACTION_DESIRE_HIGH, X.CastSpot(botTarget:GetLocation(), castRange)
			end
		end
	end
	if Fu.IsPushing(bot) then
		local enemyLaneCreeps = bot:GetNearbyLaneCreeps(castRange + radius, true)
		if enemyLaneCreeps ~= nil and #enemyLaneCreeps >= 4 then
			return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(enemyLaneCreeps)
		end
	end
	if Fu.IsFarming(bot) then
		if isAttacking then
			local neutralCreeps = bot:GetNearbyNeutralCreeps(castRange + radius)
			if neutralCreeps ~= nil and #neutralCreeps >= 3 and mpRatio > 0.3 then
				return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(neutralCreeps)
			end
			local enemyLaneCreeps = bot:GetNearbyLaneCreeps(castRange + radius, true)
			if enemyLaneCreeps ~= nil and #enemyLaneCreeps >= 3 and mpRatio > 0.3 then
				return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(enemyLaneCreeps)
			end
		end
	end
	if Fu.IsLaning(bot) then
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE)
		local enemyLaneCreeps = bot:GetNearbyLaneCreeps(castRange + radius, true)
		if
			nearbyEnemies ~= nil
			and #nearbyEnemies == 0
			and enemyLaneCreeps ~= nil
			and #enemyLaneCreeps >= 4
			and isAttacking
			and mpRatio > 0.5
		then
			return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(enemyLaneCreeps)
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if
			Fu.IsRoshan(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, 500)
			and isAttacking
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, 500) and isAttacking then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.ConsiderPitOfMalice()
	if not pitOfMaliceAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local castRange = Fu.GetProperCastRange(false, bot, pitOfMaliceAbility:GetCastRange())
	local radius = pitOfMaliceAbility:GetSpecialValueInt("radius")
	local enemiesInRange = Fu.GetNearbyHeroes(bot, castRange + radius, true, BOT_MODE_NONE)
	for _, enemy in pairs(enemiesInRange) do
		if
			Fu.IsValidHero(enemy)
			and Fu.CanCastOnNonMagicImmune(enemy)
			and enemy:IsChanneling()
			and not Fu.IsSuspiciousIllusion(enemy)
		then
			return BOT_ACTION_DESIRE_HIGH, X.CastSpot(enemy:GetLocation(), castRange)
		end
	end
	if isGoingOnSomeone then
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange + radius)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			local alliesNearTarget = Fu.GetNearbyHeroes(botTarget, 1200, true, BOT_MODE_NONE)
			local enemiesNearTarget = Fu.GetNearbyHeroes(botTarget, 1200, false, BOT_MODE_NONE)
			if alliesNearTarget ~= nil and enemiesNearTarget ~= nil and #alliesNearTarget >= #enemiesNearTarget then
				enemiesNearTarget = Fu.GetEnemiesNearLoc(botTarget:GetLocation(), castRange + radius)
				if enemiesNearTarget ~= nil and #enemiesNearTarget >= 1 then
					return BOT_ACTION_DESIRE_HIGH, X.CastSpot(Fu.GetCenterOfUnits(enemiesNearTarget), castRange)
				end
				return BOT_ACTION_DESIRE_HIGH, X.CastSpot(botTarget:GetLocation(), castRange)
			end
		end
	end
	if Fu.IsRetreating(bot) then
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE)
		for _, enemy in pairs(nearbyEnemies) do
			if
				Fu.IsValidHero(enemy)
				and Fu.CanCastOnNonMagicImmune(enemy)
				and Fu.IsChasingTarget(enemy, bot)
				and not Fu.IsSuspiciousIllusion(enemy)
				and not Fu.IsDisabled(enemy)
			then
				local alliesNearChaser = Fu.GetNearbyHeroes(enemy, 1200, true, BOT_MODE_NONE)
				local enemiesNearChaser = Fu.GetNearbyHeroes(enemy, 1200, false, BOT_MODE_NONE)
				if
					alliesNearChaser ~= nil
					and enemiesNearChaser ~= nil
					and (#enemiesNearChaser > #alliesNearChaser or bot:WasRecentlyDamagedByAnyHero(2.5))
					and GetUnitToUnitDistance(bot, enemy) < radius + 100
				then
					return BOT_ACTION_DESIRE_HIGH, bot:GetLocation()
				end
			end
		end
	end
	if Fu.IsPushing(bot) or Fu.IsDefending(bot) then
		local aoe = bot:FindAoELocation(true, true, bot:GetLocation(), castRange + radius, radius, 0, 0)
		local nearbyAllies = Fu.GetNearbyHeroes(bot, 1200, false, BOT_MODE_NONE)
		local enemiesInAoe = Fu.GetEnemiesNearLoc(aoe.targetloc, radius)
		if
			nearbyAllies ~= nil
			and enemiesInAoe ~= nil
			and #enemiesInAoe >= 1
			and #nearbyAllies <= #enemiesInAoe + 1
		then
			return BOT_ACTION_DESIRE_HIGH, aoe.targetloc
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if
			Fu.IsRoshan(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, 500)
			and isAttacking
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.ConsiderFiendsGate()
	if not fiendsGateAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local teamFightLocation = Fu.GetTeamFightLocation(bot)
	if
		teamFightLocation ~= nil
		and GetUnitToLocationDistance(bot, teamFightLocation) > 2500
		and not isGoingOnSomeone
		and not Fu.IsRetreating(bot)
		and not Fu.IsInLaningPhase()
	then
		local alliesNearFight = Fu.GetAlliesNearLoc(teamFightLocation, 1200)
		local enemiesNearFight = Fu.GetEnemiesNearLoc(teamFightLocation, 1200)
		if
			alliesNearFight ~= nil
			and enemiesNearFight ~= nil
			and #alliesNearFight + 1 >= #enemiesNearFight
			and #enemiesNearFight >= 1
		then
			local portalLocation = Fu.GetCenterOfUnits(alliesNearFight)
			if
				IsLocationPassable(portalLocation)
				and not Fu.IsLocationInChrono(portalLocation)
				and not Fu.IsLocationInBlackHole(portalLocation)
				and not Fu.IsLocationInArena(portalLocation, 600)
			then
				bot:SetTarget(enemiesNearFight[1])
				return BOT_ACTION_DESIRE_HIGH, portalLocation
			end
		end
	end
	if isGoingOnSomeone then
		if
			Fu.IsValidTarget(botTarget)
			and GetUnitToUnitDistance(bot, botTarget) > 2500
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not Fu.IsInLaningPhase()
		then
			local alliesNearTarget = Fu.GetNearbyHeroes(botTarget, 1200, true, BOT_MODE_NONE)
			local enemiesNearTarget = Fu.GetNearbyHeroes(botTarget, 1200, false, BOT_MODE_NONE)
			local nearbyAllies = Fu.GetNearbyHeroes(bot, 1600, false, BOT_MODE_NONE)
			local nearbyEnemyTowers = bot:GetNearbyTowers(700, true)
			if
				alliesNearTarget ~= nil
				and enemiesNearTarget ~= nil
				and nearbyAllies ~= nil
				and nearbyEnemyTowers ~= nil
				and #alliesNearTarget >= #enemiesNearTarget
				and #nearbyAllies == 0
				and #nearbyEnemyTowers == 0
			then
				local portalLocation = Fu.GetCenterOfUnits(alliesNearTarget)
				if
					IsLocationPassable(portalLocation)
					and not Fu.IsLocationInChrono(portalLocation)
					and not Fu.IsLocationInBlackHole(portalLocation)
					and not Fu.IsLocationInArena(portalLocation, 600)
				then
					bot:SetTarget(botTarget)
					return BOT_ACTION_DESIRE_HIGH, portalLocation
				end
			end
		end
	end
	local laneDistanceSum = { 0, 0, 0 }
	local lanePusherCount = { 0, 0, 0 }
	for _, allyHero in pairs(GetUnitList(UNIT_LIST_ALLIED_HEROES)) do
		if
			Fu.IsValidHero(allyHero)
			and Fu.IsGoingOnSomeone(allyHero)
			and GetUnitToUnitDistance(bot, allyHero) > 2500
			and not allyHero:IsIllusion()
			and not Fu.IsInLaningPhase()
		then
			local allyTarget = allyHero:GetAttackTarget()
			local alliesNearAlly = Fu.GetNearbyHeroes(allyHero, 800, false, BOT_MODE_NONE)
			if
				Fu.IsValidTarget(allyTarget)
				and Fu.IsInRange(allyHero, allyTarget, 800)
				and Fu.GetHP(allyHero) > 0.5
				and not Fu.IsSuspiciousIllusion(allyTarget)
			then
				local enemiesNearAllyTarget = Fu.GetNearbyHeroes(allyTarget, 800, false, BOT_MODE_NONE)
				local nearbyAllies = Fu.GetNearbyHeroes(bot, 1600, false, BOT_MODE_NONE)
				local nearbyEnemyTowers = bot:GetNearbyTowers(700, true)
				if
					alliesNearAlly ~= nil
					and enemiesNearAllyTarget ~= nil
					and #alliesNearAlly + 1 >= #enemiesNearAllyTarget
					and #enemiesNearAllyTarget >= 1
					and nearbyAllies ~= nil
					and nearbyEnemyTowers ~= nil
					and #nearbyAllies == 0
					and #nearbyEnemyTowers == 0
				then
					-- GetCenterOfUnits takes a unit list; given a Vector it gave Vector(0,0) (map centre)
					-- or errored. Open the portal at the ally's predicted spot instead.
					local portalLocation = allyHero:GetExtrapolatedLocation(1)
					if
						IsLocationPassable(portalLocation)
						and not Fu.IsLocationInChrono(portalLocation)
						and not Fu.IsLocationInBlackHole(portalLocation)
						and not Fu.IsLocationInArena(portalLocation, 600)
					then
						bot:SetTarget(allyTarget)
						return BOT_ACTION_DESIRE_HIGH, portalLocation
					end
				end
			end
		end
		if
			Fu.IsValidHero(allyHero)
			and bot ~= allyHero
			and not Fu.IsSuspiciousIllusion(allyHero)
			and not Fu.IsMeepoClone(allyHero)
		then
			if
				allyHero:GetActiveMode() == BOT_MODE_PUSH_TOWER_TOP
				and bot:GetActiveMode() == BOT_MODE_PUSH_TOWER_TOP
			then
				lanePusherCount[1] = lanePusherCount[1] + 1
				laneDistanceSum[1] = laneDistanceSum[1]
					+ GetUnitToLocationDistance(allyHero, GetLaneFrontLocation(GetTeam(), LANE_TOP, 0))
			end
			if
				allyHero:GetActiveMode() == BOT_MODE_PUSH_TOWER_MID
				and bot:GetActiveMode() == BOT_MODE_PUSH_TOWER_MID
			then
				lanePusherCount[2] = lanePusherCount[2] + 1
				laneDistanceSum[2] = laneDistanceSum[2]
					+ GetUnitToLocationDistance(allyHero, GetLaneFrontLocation(GetTeam(), LANE_MID, 0))
			end
			if
				allyHero:GetActiveMode() == BOT_MODE_PUSH_TOWER_BOT
				and bot:GetActiveMode() == BOT_MODE_PUSH_TOWER_BOT
			then
				lanePusherCount[3] = lanePusherCount[3] + 1
				laneDistanceSum[3] = laneDistanceSum[3]
					+ GetUnitToLocationDistance(allyHero, GetLaneFrontLocation(GetTeam(), LANE_BOT, 0))
			end
		end
	end
	if lanePusherCount[1] ~= nil and lanePusherCount[1] >= 3 and laneDistanceSum[1] / lanePusherCount[1] <= 1200 then
		if GetUnitToLocationDistance(bot, GetLaneFrontLocation(GetTeam(), LANE_TOP, 0)) > 4000 then
			return BOT_ACTION_DESIRE_HIGH, GetLaneFrontLocation(GetTeam(), LANE_TOP, 0)
		end
	elseif
		lanePusherCount[2] ~= nil
		and lanePusherCount[2] >= 3
		and laneDistanceSum[2] / lanePusherCount[2] <= 1200
	then
		if GetUnitToLocationDistance(bot, GetLaneFrontLocation(GetTeam(), LANE_MID, 0)) > 4000 then
			return BOT_ACTION_DESIRE_HIGH, GetLaneFrontLocation(GetTeam(), LANE_MID, 0)
		end
	elseif
		lanePusherCount[3] ~= nil
		and lanePusherCount[3] >= 3
		and laneDistanceSum[3] / lanePusherCount[3] <= 1200
	then
		if GetUnitToLocationDistance(bot, GetLaneFrontLocation(GetTeam(), LANE_BOT, 0)) > 4000 then
			return BOT_ACTION_DESIRE_HIGH, GetLaneFrontLocation(GetTeam(), LANE_BOT, 0)
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
return X
