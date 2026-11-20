-- Furion: skill build, item build, and ability use for this hero.
local X = {}
local bot = GetBot()
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local AbilityContext = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local Minion = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local sTalentList = Fu.Skill.GetTalentList(bot)
local sAbilityList = Fu.Skill.GetAbilityList(bot)
local sRole = Fu.Item.GetRoleItemsBuyList(bot)
local tTalentTreeList = {
	{ ["t25"] = { 10, 0 }, ["t20"] = { 10, 0 }, ["t15"] = { 0, 10 }, ["t10"] = { 0, 10 } },
	{ ["t25"] = { 10, 0 }, ["t20"] = { 10, 0 }, ["t15"] = { 0, 10 }, ["t10"] = { 0, 10 } },
	{ ["t25"] = { 0, 10 }, ["t20"] = { 0, 10 }, ["t15"] = { 10, 0 }, ["t10"] = { 10, 0 } },
}
-- tAllAbilityBuildList[1] (pos 1/2): Nature's Call first, then Teleportation, Sprout last (Dotabuff most picked order).
local tAllAbilityBuildList = {
	{ 3, 1, 3, 2, 3, 6, 3, 2, 2, 2, 6, 1, 1, 1, 6 },
	{ 3, 1, 3, 2, 3, 6, 3, 2, 2, 2, 6, 1, 1, 1, 6 },
	{
		2,
		1,
		1,
		2,
		1,
		6,
		1,
		2,
		2,
		3,
		6,
		3,
		3,
		3,
		6,
	},
}
local nAbilityBuildList
local nTalentBuildList
if sRole == "pos_1" or sRole == "pos_2" then
	nAbilityBuildList = tAllAbilityBuildList[1]
	nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList[1])
elseif sRole == "pos_3" then
	nAbilityBuildList = tAllAbilityBuildList[2]
	nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList[2])
else
	nAbilityBuildList = tAllAbilityBuildList[3]
	nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList[3])
end
local sRoleItemsBuyList = {}
-- Stratz 7.41f, week of 9 Nov 2026: pos 1, 44,310 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_1"] = {
	"item_tango",
	"item_double_branches",
	"item_faerie_fire",
	"item_circlet",
	"item_magic_wand",
	"item_power_treads",
	"item_mjollnir",
	"item_hurricane_pike",
	"item_black_king_bar",
	"item_greater_crit",
	"item_satanic",
	"item_aghanims_shard",
	"item_moon_shard",
	"item_ultimate_scepter_2",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 2, 37,747 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_2"] = {
	"item_tango",
	"item_double_branches",
	"item_circlet",
	"item_faerie_fire",
	"item_magic_wand",
	"item_power_treads",
	"item_orchid",
	"item_mjollnir",
	"item_bloodthorn",
	"item_black_king_bar",
	"item_greater_crit",
	"item_satanic",
	"item_moon_shard",
	"item_ultimate_scepter_2",
	"item_aghanims_shard",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 3, 10,707 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_3"] = {
	"item_tango",
	"item_double_branches",
	"item_faerie_fire",
	"item_circlet",
	"item_magic_wand",
	"item_power_treads",
	"item_maelstrom",
	"item_orchid",
	"item_mjollnir",
	"item_invis_sword",
	"item_bloodthorn",
	"item_black_king_bar",
	"item_satanic",
	"item_moon_shard",
	"item_ultimate_scepter_2",
	"item_aghanims_shard",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 4, 46,006 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_4"] = {
	"item_tango",
	"item_blood_grenade",
	"item_double_branches",
	"item_circlet",
	"item_faerie_fire",
	"item_magic_wand",
	"item_power_treads",
	"item_oblivion_staff",
	"item_maelstrom",
	"item_orchid",
	"item_ultimate_scepter",
	"item_bloodthorn",
	"item_black_king_bar",
	"item_ultimate_scepter_2",
	"item_greater_crit",
	"item_hurricane_pike",
	"item_aghanims_shard",
	"item_moon_shard",
}
-- One pair of boots in this build (user rule; Util/boots-check.js).
-- Stratz 7.41f, week of 9 Nov 2026: pos 5, 21,238 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_5"] = {
	"item_tango",
	"item_blood_grenade",
	"item_double_branches",
	"item_circlet",
	"item_faerie_fire",
	"item_magic_wand",
	"item_power_treads",
	"item_oblivion_staff",
	"item_maelstrom",
	"item_orchid",
	"item_ultimate_scepter",
	"item_bloodthorn",
	"item_black_king_bar",
	"item_ultimate_scepter_2",
	"item_greater_crit",
	"item_hurricane_pike",
	"item_aghanims_shard",
	"item_moon_shard",
}
X["sBuyList"] = sRoleItemsBuyList[sRole]
X["sSellList"] = {
	"item_black_king_bar",
	"item_quelling_blade",
	"item_ultimate_scepter",
	"item_null_talisman",
	"item_cyclone",
	"item_magic_wand",
}
if Fu.Role.IsPvNMode() or Fu.Role.IsAllShadow() then
	X["sBuyList"], X["sSellList"] = { "PvN_mid" }, {}
end
nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"] =
	Fu.SetUserHeroInit(nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"])
X["sSkillList"] = Fu.Skill.GetSkillList(sAbilityList, nAbilityBuildList, sTalentList, nTalentBuildList)
X["bDeafaultAbility"] = false
X["bDeafaultItem"] = false
function X.MinionThink(minionUnit)
	Minion.MinionThink(minionUnit)
end
local sproutAbility, teleportationAbility, naturesCallAbility, curseOfTheOldGrowthAbility, wrathOfNatureAbility
local function refreshAbilities()
	sproutAbility = SafeAbility(bot:GetAbilityByName("furion_sprout"), "furion_sprout", "furion")
	teleportationAbility = SafeAbility(bot:GetAbilityByName("furion_teleportation"), "furion_teleportation", "furion")
	naturesCallAbility = SafeAbility(bot:GetAbilityByName("furion_force_of_nature"), "furion_force_of_nature", "furion")
	curseOfTheOldGrowthAbility =
		SafeAbility(bot:GetAbilityByName("furion_curse_of_the_forest"), "furion_curse_of_the_forest", "furion")
	wrathOfNatureAbility =
		SafeAbility(bot:GetAbilityByName("furion_wrath_of_nature"), "furion_wrath_of_nature", "furion")
end
local botTarget, nearbyAllies, nearbyEnemies, isAttacking
local isGoingOnSomeone
local isInTeamFight
function X.SkillsComplement()
	if Fu.CanNotUseAbility(bot) then
		return
	end
	isGoingOnSomeone = Fu.IsGoingOnSomeone(bot)
	isInTeamFight = Fu.IsInTeamFight(bot, 1200)
	refreshAbilities()
	botTarget = Fu.GetProperTarget(bot)
	nearbyAllies = bot:GetNearbyHeroes(1600, false, BOT_MODE_NONE)
	nearbyEnemies = bot:GetNearbyHeroes(1600, true, BOT_MODE_NONE)
	isAttacking = Fu.IsAttacking(bot)
	if bot.useProphetTP and bot.ProphetTPLocation ~= nil and Fu.CanCastAbility(teleportationAbility) then
		bot:Action_UseAbilityOnLocation(teleportationAbility, bot.ProphetTPLocation)
		bot.useProphetTP = false
		return
	end
	local sproutCallDesire, sproutCallTarget, sproutCallLocation = X.ConsiderSproutCall()
	if sproutCallDesire > 0 and sproutCallTarget ~= nil then
		pcall(
			print,
			string.format(
				"[OHA-FURION] t=%.0f sprout-call dist=%.0f",
				DotaTime(),
				GetUnitToLocationDistance(bot, sproutCallLocation)
			)
		)
		bot:Action_ClearActions(true)
		bot:ActionQueue_UseAbilityOnEntity(sproutAbility, sproutCallTarget)
		bot:ActionQueue_Delay(0.35 + 0.44)
		bot:ActionQueue_UseAbilityOnLocation(naturesCallAbility, sproutCallLocation)
		return
	end
	local teleportationDesire, teleportationLocation = X.ConsiderTeleportation()
	if teleportationDesire > 0 then
		pcall(
			print,
			string.format(
				"[OHA-FURION] t=%.0f teleport to=%.0f,%.0f dist=%.0f hp=%.2f mode=%d foes=%d",
				DotaTime(),
				teleportationLocation.x,
				teleportationLocation.y,
				GetUnitToLocationDistance(bot, teleportationLocation),
				Fu.GetHP(bot),
				bot:GetActiveMode(),
				#(Fu.GetEnemiesNearLoc(teleportationLocation, 1200) or {})
			)
		)
		Fu.SetQueuePtToINT(bot, false)
		bot:ActionQueue_UseAbilityOnLocation(teleportationAbility, teleportationLocation)
		bot.useProphetTP = false
		return
	end
	local sproutDesire, sproutTarget = X.ConsiderSprout()
	if sproutDesire > 0 then
		Fu.SetQueuePtToINT(bot, false)
		bot:ActionQueue_UseAbilityOnEntity(sproutAbility, sproutTarget)
		return
	end
	local naturesCallDesire, naturesCallTree = X.ConsiderNaturesCall()
	if naturesCallDesire > 0 then
		Fu.SetQueuePtToINT(bot, false)
		bot:ActionQueue_UseAbilityOnLocation(naturesCallAbility, GetTreeLocation(naturesCallTree))
		return
	end
	local curseDesire = X.ConsiderCurseOfTheOldGrowth()
	if curseDesire > 0 then
		Fu.SetQueuePtToINT(bot, false)
		bot:ActionQueue_UseAbility(curseOfTheOldGrowthAbility)
		return
	end
	local wrathOfNatureDesire, wrathOfNatureTarget = X.ConsiderWrathOfNature()
	if wrathOfNatureDesire > 0 then
		Fu.SetQueuePtToINT(bot, false)
		bot:ActionQueue_UseAbilityOnEntity(wrathOfNatureAbility, wrathOfNatureTarget)
		return
	end
end
function X.ConsiderSprout()
	if not Fu.CanCastAbility(sproutAbility) then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castRange = Fu.GetProperCastRange(false, bot, sproutAbility:GetCastRange())
	local duration = sproutAbility:GetSpecialValueInt("duration")
	local function isGoodSproutTarget(target)
		return Fu.IsValidTarget(target)
			and not Fu.IsSuspiciousIllusion(target)
			and not target:HasModifier("modifier_hoodwink_scurry_active")
			and not target:HasModifier("modifier_item_spider_legs_active")
			and not target:HasModifier("modifier_enigma_black_hole_pull")
			and not target:HasModifier("modifier_faceless_void_chronosphere_freeze")
			and not target:HasModifier("modifier_legion_commander_duel")
			and not target:HasModifier("modifier_necrolyte_reapers_scythe")
	end
	if isInTeamFight then
		local bestTarget, highestDamage = nil, 0
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				isGoodSproutTarget(enemyHero)
				and not Fu.IsDisabled(enemyHero)
				and Fu.IsInRange(bot, enemyHero, castRange)
			then
				local estimatedDamage = enemyHero:GetEstimatedDamageToTarget(true, bot, 5, DAMAGE_TYPE_ALL)
				if estimatedDamage > highestDamage then
					bestTarget = enemyHero
					highestDamage = estimatedDamage
				end
			end
		end
		if bestTarget then
			return BOT_ACTION_DESIRE_HIGH, bestTarget
		end
	end
	if isGoingOnSomeone then
		if
			isGoodSproutTarget(botTarget)
			and Fu.CanCastOnMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and not Fu.IsDisabled(botTarget)
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end
	if Fu.IsRetreating(bot) and not Fu.IsRealInvisible(bot) then
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.CanCastOnMagicImmune(enemyHero)
				and Fu.IsInRange(bot, enemyHero, castRange)
				and not Fu.IsInRange(bot, enemyHero, sproutAbility:GetSpecialValueInt("radius"))
				and Fu.IsChasingTarget(enemyHero, bot)
				and bot:WasRecentlyDamagedByHero(enemyHero, 2.0)
			then
				return BOT_ACTION_DESIRE_HIGH, enemyHero
			end
		end
	end
	for _, allyHero in pairs(nearbyAllies) do
		if
			Fu.IsValidHero(allyHero)
			and Fu.IsRetreating(allyHero)
			and allyHero:WasRecentlyDamagedByAnyHero(5)
			and not allyHero:IsIllusion()
			and (not Fu.IsCore(bot) or Fu.GetMP(bot) > 0.5)
		then
			local enemiesNearAlly = allyHero:GetNearbyHeroes(castRange, true, BOT_MODE_NONE)
			if
				Fu.IsValidHero(enemiesNearAlly[1])
				and isGoodSproutTarget(enemiesNearAlly[1])
				and Fu.IsInRange(bot, enemiesNearAlly[1], castRange)
				and Fu.IsChasingTarget(enemiesNearAlly[1], allyHero)
			then
				return BOT_ACTION_DESIRE_HIGH, enemiesNearAlly[1]
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function X.ConsiderTeleportation()
	if not Fu.CanCastAbility(teleportationAbility) then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local castPoint = teleportationAbility:GetCastPoint()
	local moveSpeed = bot:GetCurrentMovementSpeed()
	if Fu.IsStunProjectileIncoming and Fu.IsStunProjectileIncoming(bot, 1200) then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	if Fu.IsStuck(bot) then
		return BOT_ACTION_DESIRE_HIGH, Fu.GetTeamFountain()
	end
	-- Game 031, 12:01: at 21% HP he teleported to a fight and fed OD. Joining a fight, a gank, a
	-- push, a defense, Roshan or a Tormentor needs half HP; below it only the fountain is a target.
	local fitToJoin = Fu.GetHP(bot) >= 0.5
	local teamFightLocation = Fu.GetTeamFightLocation(bot)
	if
		fitToJoin
		and teamFightLocation ~= nil
		and (not Fu.IsCore(bot) or not Fu.IsInLaningPhase() or bot:GetNetWorth() > 3500)
	then
		local distance = GetUnitToLocationDistance(bot, teamFightLocation)
		local travelTime = distance / moveSpeed
		if travelTime > castPoint + 2 then
			local alliesNearFight = Fu.GetAlliesNearLoc(teamFightLocation, 1200)
			if
				alliesNearFight ~= nil
				and #alliesNearFight >= 1
				and Fu.IsValidHero(alliesNearFight[#alliesNearFight])
			then
				return BOT_ACTION_DESIRE_HIGH, Fu.GetCorrectLoc(alliesNearFight[#alliesNearFight], castPoint)
			end
		end
	end
	for i = 1, #GetTeamPlayers(GetTeam()) do
		local teamMember = GetTeamMember(i)
		if
			fitToJoin
			and Fu.IsValidHero(teamMember)
			and Fu.IsGoingOnSomeone(teamMember)
			and not teamMember:IsIllusion()
			and (not Fu.IsCore(bot) or not Fu.IsInLaningPhase() or bot:GetNetWorth() > 3500)
		then
			local distance = GetUnitToUnitDistance(bot, teamMember)
			local travelTime = distance / moveSpeed
			if travelTime > castPoint + 2 then
				local allyAttackTarget = teamMember:GetAttackTarget()
				if
					Fu.IsValidTarget(allyAttackTarget)
					and Fu.IsInRange(teamMember, allyAttackTarget, 800)
					and Fu.GetHP(teamMember) > 0.25
					and not Fu.IsSuspiciousIllusion(allyAttackTarget)
				then
					local enemiesNearTarget = allyAttackTarget:GetNearbyHeroes(800, false, BOT_MODE_NONE)
					local alliesNearTeammate = teamMember:GetNearbyHeroes(800, false, BOT_MODE_NONE)
					if
						alliesNearTeammate
						and enemiesNearTarget
						and #alliesNearTeammate + 1 >= #enemiesNearTarget
						and not Fu.IsLocationInChrono(Fu.GetCorrectLoc(teamMember, castPoint))
					then
						return BOT_ACTION_DESIRE_HIGH, Fu.GetCorrectLoc(teamMember, castPoint)
					end
				end
			end
		end
	end
	if
		Fu.IsRetreating(bot)
		and not Fu.IsRealInvisible(bot)
		and bot:WasRecentlyDamagedByAnyHero(4)
		and bot:GetActiveModeDesire() > 0.75
		and bot:GetLevel() >= 6
	then
		if #nearbyEnemies == 0 then
			local timeToFountain = GetUnitToLocationDistance(bot, Fu.GetTeamFountain()) / moveSpeed
			if timeToFountain > castPoint + 1 then
				return BOT_ACTION_DESIRE_HIGH, Fu.GetTeamFountain()
			end
		end
	end
	if not fitToJoin then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	if Fu.IsPushing(bot) and not isAttacking and #nearbyEnemies == 0 then
		local assignedLane = bot:GetAssignedLane()
		if assignedLane ~= nil and assignedLane > 0 then
			local laneFrontLocation = GetLaneFrontLocation(GetTeam(), assignedLane, 0)
			local distance = GetUnitToLocationDistance(bot, laneFrontLocation)
			local travelTime = distance / moveSpeed
			if travelTime > castPoint * 2 and IsLocationPassable(laneFrontLocation) then
				return BOT_ACTION_DESIRE_MODERATE, laneFrontLocation
			end
		end
	end
	if Fu.IsDefending(bot) and #nearbyEnemies == 0 then
		local defendLane, _ = Fu.GetMostDefendLaneDesire()
		if defendLane ~= nil then
			local defendLocation = GetLaneFrontLocation(GetTeam(), defendLane, -1000)
			local distance = GetUnitToLocationDistance(bot, defendLocation)
			local travelTime = distance / moveSpeed
			if travelTime > castPoint * 2 and IsLocationPassable(defendLocation) then
				return BOT_ACTION_DESIRE_MODERATE, defendLocation
			end
		end
	end
	if Fu.IsDoingRoshan(bot) then
		local roshanLocation = Fu.GetCurrentRoshanLocation()
		local alliesNearRoshan = Fu.GetAlliesNearLoc(roshanLocation, 700)
		local distance = GetUnitToLocationDistance(bot, roshanLocation)
		if alliesNearRoshan and #alliesNearRoshan >= 2 and distance / moveSpeed > castPoint + 1 then
			return BOT_ACTION_DESIRE_HIGH, roshanLocation
		end
	end
	if Fu.IsDoingTormentor(bot) then
		local tormentorLocation = Fu.GetTormentorLocation(GetTeam())
		local alliesNearTormentor = Fu.GetAlliesNearLoc(tormentorLocation, 700)
		local distance = GetUnitToLocationDistance(bot, tormentorLocation)
		if alliesNearTormentor and #alliesNearTormentor >= 2 and distance / moveSpeed > castPoint + 1 then
			return BOT_ACTION_DESIRE_HIGH, tormentorLocation
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.ConsiderNaturesCall()
	if not Fu.CanCastAbility(naturesCallAbility) then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local castRange = Fu.GetProperCastRange(false, bot, naturesCallAbility:GetCastRange())
	local nearbyTrees = bot:GetNearbyTrees(castRange)
	if nearbyTrees == nil or #nearbyTrees < 1 then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local laneCreeps = bot:GetNearbyLaneCreeps(castRange, true)
	if isInTeamFight then
		return BOT_ACTION_DESIRE_HIGH, nearbyTrees[1]
	end
	if isGoingOnSomeone then
		if
			Fu.IsValidTarget(botTarget)
			and Fu.IsInRange(bot, botTarget, 900)
			and Fu.CanBeAttacked(botTarget)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not botTarget:HasModifier("modifier_abaddon_borrowed_time")
			and not botTarget:HasModifier("modifier_faceless_void_chronosphere_freeze")
		then
			return BOT_ACTION_DESIRE_HIGH, nearbyTrees[1]
		end
	end
	if Fu.IsPushing(bot) or Fu.IsDefending(bot) then
		if laneCreeps and #laneCreeps >= 4 and Fu.CanBeAttacked(laneCreeps[1]) and #nearbyAllies <= 3 then
			return BOT_ACTION_DESIRE_HIGH, nearbyTrees[1]
		end
	end
	if Fu.IsFarming(bot) and Fu.GetManaAfter(naturesCallAbility:GetManaCost()) > 0.35 and isAttacking then
		local neutralCreeps = bot:GetNearbyNeutralCreeps(castRange)
		if
			neutralCreeps
			and Fu.IsValid(neutralCreeps[1])
			and (#neutralCreeps >= 3 or #neutralCreeps >= 2 and neutralCreeps[1]:IsAncientCreep())
		then
			return BOT_ACTION_DESIRE_HIGH, nearbyTrees[1]
		end
		if laneCreeps and #laneCreeps >= 3 and Fu.CanBeAttacked(laneCreeps[1]) then
			return BOT_ACTION_DESIRE_HIGH, nearbyTrees[1]
		end
	end
	if Fu.IsLaning(bot) and Fu.GetManaAfter(naturesCallAbility:GetManaCost()) > 0.3 and isAttacking then
		if laneCreeps and #laneCreeps >= 2 and Fu.CanBeAttacked(laneCreeps[1]) then
			return BOT_ACTION_DESIRE_HIGH, nearbyTrees[1]
		end
	end
	if
		Fu.IsDoingRoshan(bot)
		and Fu.IsRoshan(botTarget)
		and not botTarget:IsAttackImmune()
		and Fu.IsInRange(bot, botTarget, bot:GetAttackRange())
		and isAttacking
	then
		return BOT_ACTION_DESIRE_HIGH, nearbyTrees[1]
	end
	if
		Fu.IsDoingTormentor(bot)
		and Fu.IsTormentor(botTarget)
		and Fu.IsInRange(bot, botTarget, bot:GetAttackRange())
		and isAttacking
	then
		return BOT_ACTION_DESIRE_HIGH, nearbyTrees[1]
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.ConsiderWrathOfNature()
	if not Fu.CanCastAbility(wrathOfNatureAbility) then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local damage = wrathOfNatureAbility:GetSpecialValueInt("damage")
	for _, enemyHero in pairs(GetUnitList(UNIT_LIST_ENEMY_HEROES)) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and Fu.CanCastOnTargetAdvanced(enemyHero)
			and Fu.CanKillTarget(enemyHero, damage, DAMAGE_TYPE_MAGICAL)
			and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
			and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
			and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
			and not enemyHero:HasModifier("modifier_templar_assassin_refraction_absorb")
		then
			return BOT_ACTION_DESIRE_HIGH, enemyHero
		end
	end
	if isInTeamFight then
		local weakestTarget, lowestHealth = nil, 99999
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValidTarget(enemyHero)
				and Fu.GetHP(enemyHero) < 0.5
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
				and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
				and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
				and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
				and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
			then
				if enemyHero:GetHealth() < lowestHealth then
					weakestTarget = enemyHero
					lowestHealth = enemyHero:GetHealth()
				end
			end
		end
		if weakestTarget then
			return BOT_ACTION_DESIRE_HIGH, weakestTarget
		end
	end
	if isGoingOnSomeone and (isAttacking or bot:HasScepter()) then
		if
			Fu.IsValidHero(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.CanCastOnTargetAdvanced(botTarget)
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
			and not botTarget:HasModifier("modifier_oracle_false_promise_timer")
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function X.ConsiderCurseOfTheOldGrowth()
	if not Fu.CanCastAbility(curseOfTheOldGrowthAbility) then
		return BOT_ACTION_DESIRE_NONE
	end
	local curseRange = curseOfTheOldGrowthAbility:GetSpecialValueInt("range")
	local enemiesInRange = Fu.GetEnemiesNearLoc(bot:GetLocation(), curseRange)
	if (isInTeamFight or isGoingOnSomeone) and #enemiesInRange >= 2 then
		return BOT_ACTION_DESIRE_HIGH
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.CanDoSproutCall()
	return Fu.CanCastAbility(sproutAbility) and Fu.CanCastAbility(naturesCallAbility) and Fu.GetMP(bot) > 0.5
end
function X.ConsiderSproutCall()
	if not X.CanDoSproutCall() then
		return BOT_ACTION_DESIRE_NONE, nil, 0
	end
	local castRange = Fu.GetProperCastRange(false, bot, sproutAbility:GetCastRange())
	local laneCreeps = bot:GetNearbyLaneCreeps(castRange, true)
	-- Sprout is cast on Furion, so its trees ring him; Nature's Call only converts trees within its
	-- area (150-375) of the point. Calling at the creep centre (up to 850 away) found none of the
	-- sprouted trees. Call on Furion, as the farming case already does.
	if
		(Fu.IsPushing(bot) or Fu.IsDefending(bot))
		and laneCreeps
		and #laneCreeps >= 4
		and Fu.CanBeAttacked(laneCreeps[1])
	then
		return BOT_ACTION_DESIRE_HIGH, bot, bot:GetLocation()
	end
	if Fu.IsFarming(bot) and isAttacking then
		local neutralCreeps = bot:GetNearbyNeutralCreeps(castRange)
		if
			neutralCreeps
			and Fu.IsValid(neutralCreeps[1])
			and (#neutralCreeps >= 3 or #neutralCreeps >= 2 and neutralCreeps[1]:IsAncientCreep())
		then
			return BOT_ACTION_DESIRE_HIGH, bot, bot:GetLocation()
		end
		-- Same as the push case: call where the sprouted trees are (around Furion).
		if laneCreeps and #laneCreeps >= 3 and Fu.CanBeAttacked(laneCreeps[1]) then
			return BOT_ACTION_DESIRE_HIGH, bot, bot:GetLocation()
		end
	end
	if Fu.IsLaning(bot) and isAttacking then
		if laneCreeps and #laneCreeps >= 2 and Fu.CanBeAttacked(laneCreeps[1]) then
			return BOT_ACTION_DESIRE_HIGH, bot, bot:GetLocation()
		end
	end
	if Fu.IsDoingRoshan(bot) and Fu.IsRoshan(botTarget) and isAttacking then
		return BOT_ACTION_DESIRE_HIGH, bot, bot:GetLocation()
	end
	if Fu.IsDoingTormentor(bot) and Fu.IsTormentor(botTarget) and isAttacking then
		return BOT_ACTION_DESIRE_HIGH, bot, bot:GetLocation()
	end
	return BOT_ACTION_DESIRE_NONE, nil, 0
end
return X
