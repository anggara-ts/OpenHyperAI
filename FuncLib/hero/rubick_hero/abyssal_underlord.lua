-- How Rubick plays after stealing a spell from Abyssal Underlord.
local bot = GetBot()
local X = {}
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local firestormAbility
local pitOfMaliceAbility
local fiendsGateAbility
local botTarget
function X.ConsiderStolenSpell(ability)
	bot = GetBot()
	if Fu.CanNotUseAbility(bot) then
		return
	end
	botTarget = Fu.GetProperTarget(bot)
	local abilityName = ability:GetName()
	if abilityName == "abyssal_underlord_pit_of_malice" then
		pitOfMaliceAbility = ability
		PitOfMaliceDesire, PitOfMaliceLocation = X.ConsiderPitOfMalice()
		if PitOfMaliceDesire > 0 then
			bot:Action_UseAbilityOnLocation(pitOfMaliceAbility, PitOfMaliceLocation)
			return
		end
	end
	if abilityName == "abyssal_underlord_firestorm" then
		firestormAbility = ability
		FirestormDesire, FirestormLocation = X.ConsiderFirestorm()
		if FirestormDesire > 0 then
			bot:Action_UseAbilityOnLocation(firestormAbility, FirestormLocation)
			return
		end
	end
	if abilityName == "abyssal_underlord_dark_portal" then
		fiendsGateAbility = ability
		FiendsGateDesire, FiendsGateLocation = X.ConsiderFiendsGate()
		if FiendsGateDesire > 0 then
			bot:Action_UseAbilityOnLocation(fiendsGateAbility, FiendsGateLocation)
			return
		end
	end
end
function X.ConsiderFirestorm()
	if not firestormAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local castRange = Fu.GetProperCastRange(false, bot, firestormAbility:GetCastRange())
	local radius = firestormAbility:GetSpecialValueInt("radius")
	local castPoint = firestormAbility:GetCastPoint()
	if Fu.IsInTeamFight(bot, 1200) then
		local aoeLocation = bot:FindAoELocation(true, true, bot:GetLocation(), castRange + radius, radius, castPoint, 0)
		local nearbyEnemies = Fu.GetEnemiesNearLoc(aoeLocation.targetloc, radius)
		if nearbyEnemies ~= nil and #nearbyEnemies >= 2 then
			return BOT_ACTION_DESIRE_HIGH, Fu.Site.GetXUnitsTowardsLocation(bot, aoeLocation.targetloc, castRange)
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange + radius)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not botTarget:HasModifier("modifier_abaddon_borrowed_time")
			and not botTarget:HasModifier("modifier_dazzle_shallow_grave")
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
			and not botTarget:HasModifier("modifier_oracle_false_promise_timer")
		then
			local alliesNearTarget = Fu.GetNearbyHeroes(botTarget, 1200, true, BOT_MODE_NONE)
			local enemiesNearTarget = Fu.GetNearbyHeroes(botTarget, 1200, false, BOT_MODE_NONE)
			if alliesNearTarget ~= nil and enemiesNearTarget ~= nil and #alliesNearTarget >= #enemiesNearTarget then
				enemiesNearTarget = Fu.GetEnemiesNearLoc(botTarget:GetLocation(), castRange + radius)
				if enemiesNearTarget ~= nil and #enemiesNearTarget >= 1 then
					return BOT_ACTION_DESIRE_HIGH, Fu.Site.GetXUnitsTowardsLocation(bot, Fu.GetCenterOfUnits(enemiesNearTarget), castRange)
				end
				return BOT_ACTION_DESIRE_HIGH, Fu.Site.GetXUnitsTowardsLocation(bot, botTarget:GetLocation(), castRange)
			end
		end
	end
	if Fu.IsPushing(bot) then
		local laneCreeps = bot:GetNearbyLaneCreeps(castRange + radius, true)
		if laneCreeps ~= nil and #laneCreeps >= 4 then
			return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(laneCreeps)
		end
	end
	if Fu.IsFarming(bot) then
		if Fu.IsAttacking(bot) then
			local neutralCreeps = bot:GetNearbyNeutralCreeps(castRange + radius)
			if neutralCreeps ~= nil and #neutralCreeps >= 3 and Fu.GetMP(bot) > 0.3 then
				return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(neutralCreeps)
			end
			local laneCreeps = bot:GetNearbyLaneCreeps(castRange + radius, true)
			if laneCreeps ~= nil and #laneCreeps >= 3 and Fu.GetMP(bot) > 0.3 then
				return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(laneCreeps)
			end
		end
	end
	if Fu.IsLaning(bot) then
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE)
		local laneCreeps = bot:GetNearbyLaneCreeps(castRange + radius, true)
		if nearbyEnemies ~= nil and #nearbyEnemies == 0 and laneCreeps ~= nil and #laneCreeps >= 4 and Fu.IsAttacking(bot) and Fu.GetMP(bot) > 0.5 then
			return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(laneCreeps)
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if Fu.IsRoshan(botTarget) and Fu.CanCastOnNonMagicImmune(botTarget) and Fu.IsInRange(bot, botTarget, 500) and Fu.IsAttacking(bot) then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, 500) and Fu.IsAttacking(bot) then
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
	local nearbyEnemies = Fu.GetNearbyHeroes(bot, castRange + radius, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(nearbyEnemies) do
		if Fu.IsValidHero(enemyHero) and Fu.CanCastOnNonMagicImmune(enemyHero) and enemyHero:IsChanneling() and not Fu.IsSuspiciousIllusion(enemyHero) then
			return BOT_ACTION_DESIRE_HIGH, Fu.Site.GetXUnitsTowardsLocation(bot, enemyHero:GetLocation(), castRange)
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
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
					return BOT_ACTION_DESIRE_HIGH, Fu.Site.GetXUnitsTowardsLocation(bot, Fu.GetCenterOfUnits(enemiesNearTarget), castRange)
				end
				return BOT_ACTION_DESIRE_HIGH, Fu.Site.GetXUnitsTowardsLocation(bot, botTarget:GetLocation(), castRange)
			end
		end
	end
	if Fu.IsRetreating(bot) then
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE)
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.IsChasingTarget(enemyHero, bot)
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and not Fu.IsDisabled(enemyHero)
			then
				local alliesNearEnemy = Fu.GetNearbyHeroes(enemyHero, 1200, true, BOT_MODE_NONE)
				local enemiesNearEnemy = Fu.GetNearbyHeroes(enemyHero, 1200, false, BOT_MODE_NONE)
				if
					alliesNearEnemy ~= nil
					and enemiesNearEnemy ~= nil
					and (#enemiesNearEnemy > #alliesNearEnemy or bot:WasRecentlyDamagedByAnyHero(2.5))
					and GetUnitToUnitDistance(bot, enemyHero) < radius + 100
				then
					return BOT_ACTION_DESIRE_HIGH, bot:GetLocation()
				end
			end
		end
	end
	if Fu.IsPushing(bot) or Fu.IsDefending(bot) then
		local aoeLocation = bot:FindAoELocation(true, true, bot:GetLocation(), castRange + radius, radius, 0, 0)
		local nearbyAllies = Fu.GetNearbyHeroes(bot, 1200, false, BOT_MODE_NONE)
		local enemiesInRadius = Fu.GetEnemiesNearLoc(aoeLocation.targetloc, radius)
		if nearbyAllies ~= nil and enemiesInRadius ~= nil and #enemiesInRadius >= 1 and #nearbyAllies <= #enemiesInRadius + 1 then
			return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if Fu.IsRoshan(botTarget) and Fu.CanCastOnNonMagicImmune(botTarget) and Fu.IsInRange(bot, botTarget, 500) and Fu.IsAttacking(bot) then
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
		and not Fu.IsGoingOnSomeone(bot)
		and not Fu.IsRetreating(bot)
		and not Fu.IsInLaningPhase()
	then
		local alliesNearFight = Fu.GetAlliesNearLoc(teamFightLocation, 1200)
		local enemiesNearFight = Fu.GetEnemiesNearLoc(teamFightLocation, 1200)
		if alliesNearFight ~= nil and enemiesNearFight ~= nil and #alliesNearFight + 1 >= #enemiesNearFight and #enemiesNearFight >= 1 then
			local gateLocation = Fu.GetCenterOfUnits(alliesNearFight)
			if
				IsLocationPassable(gateLocation)
				and not Fu.IsLocationInChrono(gateLocation)
				and not Fu.IsLocationInBlackHole(gateLocation)
				and not Fu.IsLocationInArena(gateLocation, 600)
			then
				bot:SetTarget(enemiesNearFight[1])
				return BOT_ACTION_DESIRE_HIGH, gateLocation
			end
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
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
			if alliesNearTarget ~= nil and enemiesNearTarget ~= nil and nearbyAllies ~= nil and nearbyEnemyTowers ~= nil and #alliesNearTarget >= #enemiesNearTarget and #nearbyAllies == 0 and #nearbyEnemyTowers == 0 then
				local gateLocation = Fu.GetCenterOfUnits(alliesNearTarget)
				if
					IsLocationPassable(gateLocation)
					and not Fu.IsLocationInChrono(gateLocation)
					and not Fu.IsLocationInBlackHole(gateLocation)
					and not Fu.IsLocationInArena(gateLocation, 600)
				then
					bot:SetTarget(botTarget)
					return BOT_ACTION_DESIRE_HIGH, gateLocation
				end
			end
		end
	end
	local laneDistanceSum = { 0, 0, 0 }
	local lanePushCount = { 0, 0, 0 }
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
				and Fu.IsCore(allyTarget)
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
					local gateLocation = Fu.GetCenterOfUnits(allyHero:GetExtrapolatedLocation(1))
					if
						IsLocationPassable(gateLocation)
						and not Fu.IsLocationInChrono(gateLocation)
						and not Fu.IsLocationInBlackHole(gateLocation)
						and not Fu.IsLocationInArena(gateLocation, 600)
					then
						bot:SetTarget(allyTarget)
						return BOT_ACTION_DESIRE_HIGH, gateLocation
					end
				end
			end
		end
		if Fu.IsValidHero(allyHero) and bot ~= allyHero and not Fu.IsSuspiciousIllusion(allyHero) and not Fu.IsMeepoClone(allyHero) then
			if allyHero:GetActiveMode() == BOT_MODE_PUSH_TOWER_TOP and bot:GetActiveMode() == BOT_MODE_PUSH_TOWER_TOP then
				lanePushCount[1] = lanePushCount[1] + 1
				laneDistanceSum[1] = laneDistanceSum[1] + GetUnitToLocationDistance(allyHero, GetLaneFrontLocation(GetTeam(), LANE_TOP, 0))
			end
			if allyHero:GetActiveMode() == BOT_MODE_PUSH_TOWER_MID and bot:GetActiveMode() == BOT_MODE_PUSH_TOWER_MID then
				lanePushCount[2] = lanePushCount[2] + 1
				laneDistanceSum[2] = laneDistanceSum[2] + GetUnitToLocationDistance(allyHero, GetLaneFrontLocation(GetTeam(), LANE_MID, 0))
			end
			if allyHero:GetActiveMode() == BOT_MODE_PUSH_TOWER_BOT and bot:GetActiveMode() == BOT_MODE_PUSH_TOWER_BOT then
				lanePushCount[3] = lanePushCount[3] + 1
				laneDistanceSum[3] = laneDistanceSum[3] + GetUnitToLocationDistance(allyHero, GetLaneFrontLocation(GetTeam(), LANE_BOT, 0))
			end
		end
	end
	if lanePushCount[1] ~= nil and lanePushCount[1] >= 3 and laneDistanceSum[1] / lanePushCount[1] <= 1200 then
		if GetUnitToLocationDistance(bot, GetLaneFrontLocation(GetTeam(), LANE_TOP, 0)) > 4000 then
			return BOT_ACTION_DESIRE_HIGH, GetLaneFrontLocation(GetTeam(), LANE_TOP, 0)
		end
	elseif lanePushCount[2] ~= nil and lanePushCount[2] >= 3 and laneDistanceSum[2] / lanePushCount[2] <= 1200 then
		if GetUnitToLocationDistance(bot, GetLaneFrontLocation(GetTeam(), LANE_MID, 0)) > 4000 then
			return BOT_ACTION_DESIRE_HIGH, GetLaneFrontLocation(GetTeam(), LANE_MID, 0)
		end
	elseif lanePushCount[3] ~= nil and lanePushCount[3] >= 3 and laneDistanceSum[3] / lanePushCount[3] <= 1200 then
		if GetUnitToLocationDistance(bot, GetLaneFrontLocation(GetTeam(), LANE_BOT, 0)) > 4000 then
			return BOT_ACTION_DESIRE_HIGH, GetLaneFrontLocation(GetTeam(), LANE_BOT, 0)
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
return X
