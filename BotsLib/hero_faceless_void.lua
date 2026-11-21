-- Faceless Void: skill build, item build, and ability use for this hero.
local X = {}
local bot = GetBot()
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local AbilityContext = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local Minion = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local sTalentList = Fu.Skill.GetTalentList(bot)
local sAbilityList = Fu.Skill.GetAbilityList(bot)
local sRole = Fu.Item.GetRoleItemsBuyList(bot)
local tTalentTreeList = { ["t25"] = { 0, 10 }, ["t20"] = { 0, 10 }, ["t15"] = { 0, 10 }, ["t10"] = { 10, 0 } }
-- Time Walk first, then Time Lock, Time Dilation last; Chronosphere at 6/12/18.
local tAllAbilityBuildList = { { 1, 3, 1, 2, 1, 6, 1, 3, 3, 3, 6, 2, 2, 2, 6 } }
local nAbilityBuildList = Fu.Skill.GetRandomBuild(tAllAbilityBuildList)
local nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList)
local sRoleItemsBuyList = {}
-- Stratz 7.41f, week of 9 Nov 2026: pos 1, 134,662 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_1"] = {
	"item_tango",
	"item_quelling_blade",
	"item_double_branches",
	"item_magic_stick",
	"item_wraith_band",
	"item_magic_wand",
	"item_power_treads",
	"item_bfury",
	"item_manta",
	"item_ultimate_scepter",
	"item_black_king_bar",
	"item_monkey_king_bar",
	"item_aghanims_shard",
	"item_ultimate_scepter_2",
	"item_refresher",
	"item_travel_boots",
	"item_moon_shard",
	"item_travel_boots_2",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 2, 2,771 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_2"] = {
	"item_tango",
	"item_quelling_blade",
	"item_double_branches",
	"item_circlet",
	"item_slippers",
	"item_wraith_band",
	"item_magic_wand",
	"item_power_treads",
	"item_mask_of_madness",
	"item_lesser_crit",
	"item_ultimate_scepter",
	"item_black_king_bar",
	"item_monkey_king_bar",
	"item_greater_crit",
	"item_ultimate_scepter_2",
	"item_refresher",
	"item_aghanims_shard",
	"item_moon_shard",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 3, 6,413 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_3"] = {
	"item_tango",
	"item_quelling_blade",
	"item_double_branches",
	"item_circlet",
	"item_slippers",
	"item_wraith_band",
	"item_magic_wand",
	"item_power_treads",
	"item_mask_of_madness",
	"item_manta",
	"item_ultimate_scepter",
	"item_lesser_crit",
	"item_black_king_bar",
	"item_greater_crit",
	"item_refresher",
	"item_ultimate_scepter_2",
	"item_skadi",
	"item_aghanims_shard",
	"item_moon_shard",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 4, 1,053 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_4"] = {
	"item_tango",
	"item_double_branches",
	"item_magic_stick",
	"item_quelling_blade",
	"item_magic_wand",
	"item_power_treads",
	"item_mask_of_madness",
	"item_maelstrom",
	"item_ultimate_scepter",
	"item_black_king_bar",
	"item_spirit_vessel",
	"item_aghanims_shard",
	"item_moon_shard",
	"item_ultimate_scepter_2",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 5, 1,343 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_5"] = {
	"item_tango",
	"item_double_branches",
	"item_quelling_blade",
	"item_magic_stick",
	"item_magic_wand",
	"item_wraith_band",
	"item_power_treads",
	"item_mask_of_madness",
	"item_maelstrom",
	"item_mjollnir",
	"item_lesser_crit",
	"item_ultimate_scepter",
	"item_black_king_bar",
	"item_greater_crit",
	"item_travel_boots",
	"item_ultimate_scepter_2",
	"item_refresher",
	"item_skadi",
	"item_aghanims_shard",
	"item_moon_shard",
	"item_travel_boots_2",
}
X["sBuyList"] = sRoleItemsBuyList[sRole]
X["sSellList"] = {
	"item_black_king_bar",
	"item_quelling_blade",
	-- Sold once the item before it is owned, to keep six slots (Util/item-builds/generate.js):
	"item_refresher",
	"item_mask_of_madness",
}
if Fu.Role.IsPvNMode() or Fu.Role.IsAllShadow() then
	X["sBuyList"], X["sSellList"] = { "PvN_antimage" }, {}
end
nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"] =
	Fu.SetUserHeroInit(nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"])
X["sSkillList"] = Fu.Skill.GetSkillList(sAbilityList, nAbilityBuildList, sTalentList, nTalentBuildList)
X["bDeafaultAbility"] = false
-- Cast when cornered (retreating into 3+ enemies with no way out), before running further.
X["LastStandSpells"] = { { name = "faceless_void_chronosphere", kind = "point" } }
X["bDeafaultItem"] = false
function X.MinionThink(minionUnit)
	Minion.MinionThink(minionUnit)
end
local timeWalkAbility =
	SafeAbility(bot:GetAbilityByName("faceless_void_time_walk"), "faceless_void_time_walk", "faceless_void")
local timeDilationAbility =
	SafeAbility(bot:GetAbilityByName("faceless_void_time_dilation"), "faceless_void_time_dilation", "faceless_void")
local chronosphereAbility =
	SafeAbility(bot:GetAbilityByName("faceless_void_chronosphere"), "faceless_void_chronosphere", "faceless_void")
local timeWalkReverseAbility = SafeAbility(
	bot:GetAbilityByName("faceless_void_time_walk_reverse"),
	"faceless_void_time_walk_reverse",
	"faceless_void"
)
local timeWalkDesire, timeWalkLocation
local timeDilationDesire
local chronosphereDesire, chronosphereLocation
local timeWalkReverseDesire
local lastTimeWalkLocation
local botTarget
local isGoingOnSomeone
local isRetreating
function X.SkillsComplement()
	if Fu.CanNotUseAbility(bot) then
		return
	end
	isGoingOnSomeone = Fu.IsGoingOnSomeone(bot)
	isRetreating = Fu.IsRetreating(bot)
	botTarget = Fu.GetProperTarget(bot)
	timeWalkReverseDesire = X.ConsiderTimeWalkReverse()
	if timeWalkReverseDesire > 0 then
		bot:Action_UseAbility(timeWalkReverseAbility)
		return
	end
	timeWalkDesire, timeWalkLocation = X.ConsiderTimeWalk()
	if timeWalkDesire > 0 and X.IsAllowedToCast(timeWalkAbility:GetManaCost()) then
		Fu.SetQueuePtToINT(bot, false)
		bot:Action_UseAbilityOnLocation(timeWalkAbility, timeWalkLocation)
		lastTimeWalkLocation = timeWalkLocation
		return
	end
	timeDilationDesire = X.ConsiderTimeDilation()
	if timeDilationDesire > 0 and X.IsAllowedToCast(timeDilationAbility:GetManaCost()) then
		Fu.SetQueuePtToINT(bot, false)
		bot:Action_UseAbility(timeDilationAbility)
		return
	end
	chronosphereDesire, chronosphereLocation = X.ConsiderChronosphere()
	if chronosphereDesire > 0 then
		bot:Action_UseAbilityOnLocation(chronosphereAbility, chronosphereLocation)
		return
	end
end
function X.CanUseRefresherShard()
	local searchRadius = 1000
	local castType = "none"
	local castTarget = nil
	local castMotive = "刷新技能"
	local nearbyEnemies = Fu.GetNearbyHeroes(bot, searchRadius, true, BOT_MODE_NONE)
	if
		#nearbyEnemies > 0
		and (isGoingOnSomeone or Fu.IsInTeamFight(bot))
		and Fu.CanUseRefresherShard(bot)
		and not bot:HasModifier("modifier_faceless_void_chronosphere_speed")
	then
		return BOT_ACTION_DESIRE_HIGH, castTarget, castType, castMotive
	end
	return false
end
function X.ConsiderTimeWalk()
	if not timeWalkAbility:IsFullyCastable() or bot:HasModifier("modifier_faceless_void_chronosphere_speed") then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local range = timeWalkAbility:GetSpecialValueInt("range")
	local castPoint = timeWalkAbility:GetCastPoint()
	local speed = timeWalkAbility:GetSpecialValueInt("speed")
	local backtrackDuration = timeWalkAbility:GetSpecialValueInt("backtrack_duration")
	local nearbyEnemies = Fu.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE)
	if Fu.IsStuck(bot) then
		return BOT_ACTION_DESIRE_HIGH, Fu.Site.GetXUnitsTowardsLocation(bot, Fu.GetEscapeLoc(), range)
	end
	if Fu.IsStunProjectileIncoming(bot, 600) or Fu.IsUnitTargetProjectileIncoming(bot, 400) then
		return BOT_ACTION_DESIRE_HIGH, Fu.Site.GetXUnitsTowardsLocation(bot, Fu.GetEscapeLoc(), range)
	end
	if not bot:HasModifier("modifier_sniper_assassinate") and not bot:IsMagicImmune() then
		if Fu.IsWillBeCastUnitTargetSpell(bot, 400) then
			return BOT_ACTION_DESIRE_HIGH, Fu.Site.GetXUnitsTowardsLocation(bot, Fu.GetEscapeLoc(), range)
		end
	end
	if isGoingOnSomeone then
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not Fu.IsDisabled(botTarget)
			and not botTarget:IsAttackImmune()
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			local targetEnemies = Fu.GetNearbyHeroes(botTarget, 1200, true, BOT_MODE_NONE)
			local targetAllies = Fu.GetNearbyHeroes(botTarget, 1200, false, BOT_MODE_NONE)
			local travelTime = GetUnitToUnitDistance(bot, botTarget) / speed + castPoint
			local walkLocation =
				Fu.Site.GetXUnitsTowardsLocation(bot, botTarget:GetExtrapolatedLocation(travelTime), range)
			if
				targetEnemies ~= nil
				and targetAllies ~= nil
				and #targetEnemies >= #targetAllies
				and IsLocationPassable(walkLocation)
				and not Fu.IsLocationInArena(walkLocation, 600)
			then
				if GetUnitToLocationDistance(bot, walkLocation) > bot:GetAttackRange() * 2 then
					if Fu.IsInLaningPhase() then
						local botHpRatio = Fu.GetHP(bot)
						local targetHealth = botTarget:GetHealth()
						local attackDamage = bot:GetAttackDamage()
						-- Target low, not Void low: "botHpRatio < 0.3" (Void's own HP) made him Time Walk in when he
						-- was nearly dead and skip it when the target was.
						local isTargetLow = Fu.GetHP(botTarget) < 0.3
						local isTargetInKillRange = targetHealth <= attackDamage * 3
						local targetTowers = botTarget:GetNearbyTowers(700, false)
						if (isTargetLow or isTargetInKillRange) and targetTowers ~= nil and #targetTowers == 0 then
							return BOT_ACTION_DESIRE_HIGH, walkLocation
						end
					else
						return BOT_ACTION_DESIRE_HIGH, walkLocation
					end
				end
			end
		end
	end
	if isRetreating then
		local nearbyEnemyHeroes = Fu.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE) or {}
		for _, enemyHero in pairs(nearbyEnemyHeroes) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.IsInRange(bot, enemyHero, range)
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and not Fu.IsDisabled(enemyHero)
				and not Fu.IsRealInvisible(bot)
			then
				local enemyTargets = Fu.GetNearbyHeroes(enemyHero, 1200, true, BOT_MODE_NONE)
				local enemyAllies = Fu.GetNearbyHeroes(enemyHero, 1200, false, BOT_MODE_NONE)
				if
					enemyTargets ~= nil
					and enemyAllies ~= nil
					and (#enemyAllies > #enemyTargets or bot:WasRecentlyDamagedByHero(enemyHero, backtrackDuration))
				then
					return BOT_ACTION_DESIRE_HIGH, Fu.Site.GetXUnitsTowardsLocation(bot, Fu.GetEscapeLoc(), range)
				end
			end
		end
	end
	if Fu.IsPushing(bot) then
		local laneCreeps = bot:GetNearbyLaneCreeps(range, true)
		if
			laneCreeps ~= nil
			and #laneCreeps >= 3
			and GetUnitToLocationDistance(bot, Fu.GetCenterOfUnits(laneCreeps)) > 500
		then
			return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(laneCreeps)
		end
	end
	if Fu.IsFarming(bot) then
		if Fu.IsValid(botTarget) and GetUnitToUnitDistance(bot, botTarget) > 500 then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	if Fu.IsLaning(bot) then
		local laneCreeps = bot:GetNearbyLaneCreeps(range, true)
		if
			(bot:GetMana() - timeWalkAbility:GetManaCost()) / bot:GetMaxMana() > 0.85
			and bot:DistanceFromFountain() > 100
			and bot:DistanceFromFountain() < 6000
			and Fu.IsInLaningPhase()
			and #nearbyEnemies == 0
		then
			local assignedLane = bot:GetAssignedLane()
			local laneFrontLocation = GetLaneFrontLocation(GetTeam(), assignedLane, 0)
			local laneFrontDistance = GetUnitToLocationDistance(bot, laneFrontLocation)
			if laneFrontDistance > range then
				local walkLocation = Fu.Site.GetXUnitsTowardsLocation(bot, laneFrontLocation, range)
				if IsLocationPassable(walkLocation) then
					return BOT_ACTION_DESIRE_HIGH, walkLocation
				end
			end
		end
	end
	if Fu.IsDoingRoshan(bot) then
		local roshanLocation = Fu.GetCurrentRoshanLocation()
		if GetUnitToLocationDistance(bot, roshanLocation) > range then
			local walkLocation = Fu.Site.GetXUnitsTowardsLocation(bot, roshanLocation, range)
			local enemiesNearRoshan = Fu.GetEnemiesNearLoc(roshanLocation, 1600)
			if enemiesNearRoshan ~= nil and #enemiesNearRoshan == 0 and IsLocationPassable(walkLocation) then
				return BOT_ACTION_DESIRE_HIGH, walkLocation
			end
		end
	end
	if Fu.IsDoingTormentor(bot) then
		local tormentorLocation = Fu.GetTormentorLocation(GetTeam())
		if GetUnitToLocationDistance(bot, tormentorLocation) > range then
			local walkLocation = Fu.Site.GetXUnitsTowardsLocation(bot, tormentorLocation, range)
			local enemiesNearLocation = Fu.GetEnemiesNearLoc(walkLocation, 1600)
			if enemiesNearLocation ~= nil and #enemiesNearLocation == 0 and IsLocationPassable(walkLocation) then
				return BOT_ACTION_DESIRE_HIGH, walkLocation
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.ConsiderTimeDilation()
	if not timeDilationAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
	end
	local radius = timeDilationAbility:GetSpecialValueInt("radius")
	if Fu.IsInTeamFight(bot, 1200) then
		local enemiesInRadius = Fu.GetEnemiesNearLoc(bot:GetLocation(), radius)
		if enemiesInRadius ~= nil and #enemiesInRadius >= 2 then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if isGoingOnSomeone then
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, radius)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not Fu.IsDisabled(botTarget)
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if isRetreating then
		local nearbyEnemyHeroes = Fu.GetNearbyHeroes(bot, radius, true, BOT_MODE_NONE) or {}
		for _, enemyHero in pairs(nearbyEnemyHeroes) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and not Fu.IsDisabled(enemyHero)
			then
				local enemyTargets = Fu.GetNearbyHeroes(enemyHero, 1200, true, BOT_MODE_NONE)
				local enemyAllies = Fu.GetNearbyHeroes(enemyHero, 1200, false, BOT_MODE_NONE)
				if
					enemyTargets ~= nil
					and enemyAllies ~= nil
					and (#enemyTargets >= #enemyAllies or bot:WasRecentlyDamagedByHero(enemyHero, 2.5))
				then
					return BOT_ACTION_DESIRE_HIGH
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderChronosphere()
	if not chronosphereAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local castRange = chronosphereAbility:GetCastRange()
	local castPoint = chronosphereAbility:GetCastPoint()
	local radius = chronosphereAbility:GetSpecialValueInt("radius")
	local duration = chronosphereAbility:GetSpecialValueInt("duration")
	local attackDamage = bot:GetAttackDamage()
	local attackSpeed = bot:GetAttackSpeed()
	local heroKills = GetHeroKills(bot:GetPlayerID())
	local heroDeaths = GetHeroDeaths(bot:GetPlayerID())
	if Fu.IsInTeamFight(bot, 1200) then
		local aoeLocation = bot:FindAoELocation(true, true, bot:GetLocation(), castRange, radius / 1.2, castPoint, 0)
		local enemiesInSphere = Fu.GetEnemiesNearLoc(aoeLocation.targetloc, radius / 1.2)
		-- Chronosphere pauses allies too (datafeed: "friendly or enemy, except those owned by
		-- Faceless Void"). Skip a sphere that freezes as many of our heroes as enemies.
		local alliesFrozen = X.AlliesInChrono(aoeLocation.targetloc, radius)
		if enemiesInSphere ~= nil and #enemiesInSphere >= 2 and alliesFrozen >= #enemiesInSphere then
			X.LogChrono("skip-allies", #enemiesInSphere, alliesFrozen)
		end
		if enemiesInSphere ~= nil and #enemiesInSphere >= 2 and alliesFrozen < #enemiesInSphere then
			local weakestTarget = nil
			local lowestHealth = 10000
			for _, enemyHero in pairs(enemiesInSphere) do
				if
					Fu.IsValidHero(enemyHero)
					and not Fu.IsSuspiciousIllusion(enemyHero)
					and not enemyHero:IsAttackImmune()
					and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
					and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
					and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
					and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
					and not enemyHero:HasModifier("modifier_templar_assassin_refraction_absorb")
					and enemyHero:GetHealth() < lowestHealth
				then
					lowestHealth = enemyHero:GetHealth()
					weakestTarget = enemyHero
				end
			end
			if weakestTarget ~= nil then
				bot:SetTarget(weakestTarget)
				return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
			end
		end
	end
	if isGoingOnSomeone then
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange + radius)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not botTarget:IsAttackImmune()
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
			and not botTarget:HasModifier("modifier_templar_assassin_refraction_absorb")
		then
			local nearbyAllies = Fu.GetNearbyHeroes(bot, 1200, false, BOT_MODE_NONE)
			local nearbyEnemyHeroes = Fu.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE) or {}
			if
				nearbyAllies ~= nil
				and nearbyEnemyHeroes ~= nil
				and #nearbyAllies >= #nearbyEnemyHeroes
				and #nearbyAllies <= 1
				and #nearbyEnemyHeroes <= 1
			then
				local sphereLocation = Fu.Site.GetXUnitsTowardsLocation(bot, botTarget:GetLocation(), castRange)
				if
					Fu.CanKillTarget(botTarget, attackDamage * attackSpeed * duration, DAMAGE_TYPE_PHYSICAL)
					and not Fu.IsLocationInChrono(sphereLocation)
					and not Fu.IsLocationInBlackHole(sphereLocation)
					and not Fu.IsLocationInArena(sphereLocation, radius)
				then
					bot:SetTarget(botTarget)
					return BOT_ACTION_DESIRE_HIGH, sphereLocation
				end
			end
		end
	end
	if isRetreating then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, 1200, false, BOT_MODE_NONE)
		local nearbyEnemyHeroes = Fu.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE) or {}
		for _, enemyHero in pairs(nearbyEnemyHeroes) do
			if
				nearbyAllies ~= nil
				and nearbyEnemyHeroes ~= nil
				and Fu.IsValidHero(enemyHero)
				and Fu.IsChasingTarget(enemyHero, bot)
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and not Fu.IsDisabled(enemyHero)
				and not enemyHero:HasModifier("modifier_legion_commander_duel")
				and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
			then
				local enemyAllies = Fu.GetNearbyHeroes(enemyHero, 1200, false, BOT_MODE_NONE)
				if enemyAllies ~= nil and #enemyAllies > #nearbyAllies + 2 and #nearbyAllies <= 1 then
					local aoeLocation =
						bot:FindAoELocation(true, true, bot:GetLocation(), castRange, radius, castPoint, 0)
					local enemiesInSphere = Fu.GetEnemiesNearLoc(aoeLocation.targetloc, radius)
					if
						enemiesInSphere ~= nil
						and #enemiesInSphere >= 1
						and not Fu.IsLocationInChrono(aoeLocation.targetloc)
						and not Fu.IsLocationInBlackHole(aoeLocation.targetloc)
						and not Fu.IsLocationInArena(aoeLocation.targetloc, radius)
						and X.AlliesInChrono(aoeLocation.targetloc, radius) < #enemiesInSphere
					then
						return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
					end
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
-- Our heroes (not Void) that a sphere at loc would pause.
function X.AlliesInChrono(loc, radius)
	local count = 0
	for _, ally in pairs(Fu.GetAlliesNearLoc(loc, radius) or {}) do
		if ally ~= bot and Fu.IsValidHero(ally) and not ally:IsIllusion() then
			count = count + 1
		end
	end
	return count
end
function X.LogChrono(why, enemies, allies)
	if DotaTime() < (bot._chronoLogAt or -999) then
		return
	end
	bot._chronoLogAt = DotaTime() + 5
	pcall(print, string.format("[OHA-VOID] t=%.0f chrono %s enemies=%d allies=%d", DotaTime(), why, enemies, allies))
end
function X.ConsiderTimeWalkReverse()
	if
		not timeWalkReverseAbility:IsTrained()
		or not timeWalkReverseAbility:IsFullyCastable()
		or not timeWalkReverseAbility:IsActivated()
	then
		return BOT_ACTION_DESIRE_NONE
	end
	if Fu.IsStunProjectileIncoming(bot, 600) or Fu.IsUnitTargetProjectileIncoming(bot, 400) then
		return BOT_ACTION_DESIRE_HIGH
	end
	if not bot:HasModifier("modifier_sniper_assassinate") and not bot:IsMagicImmune() then
		if Fu.IsWillBeCastUnitTargetSpell(bot, 400) then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if
		not bot:HasModifier("modifier_faceless_void_chronosphere_speed")
		and Fu.IsValidTarget(botTarget)
		and Fu.IsInRange(bot, botTarget, bot:GetCurrentVisionRange())
		and not Fu.IsSuspiciousIllusion(botTarget)
	then
		local targetEnemies = Fu.GetNearbyHeroes(botTarget, 1200, true, BOT_MODE_NONE)
		local targetAllies = Fu.GetNearbyHeroes(botTarget, 1200, false, BOT_MODE_NONE)
		-- lastTimeWalkLocation is nil until this bot has cast Time Walk itself.
		if targetEnemies ~= nil and targetAllies ~= nil and lastTimeWalkLocation ~= nil then
			if
				#targetAllies > #targetEnemies
				and GetUnitToLocationDistance(bot, lastTimeWalkLocation) > GetUnitToLocationDistance(
					botTarget,
					lastTimeWalkLocation
				)
				and GetUnitToLocationDistance(bot, lastTimeWalkLocation) > GetUnitToUnitDistance(bot, botTarget)
			then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.IsAllowedToCast(manaCost)
	if
		chronosphereAbility ~= nil
		and not chronosphereAbility:IsNull()
		and chronosphereAbility:IsTrained()
		and chronosphereAbility:IsFullyCastable()
	then
		local chronosphereManaCost = chronosphereAbility:GetManaCost()
		if bot:GetMana() - manaCost * 2 > chronosphereManaCost then
			return true
		else
			return false
		end
	end
	return true
end
return X
