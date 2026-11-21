-- Thinking for summoned units: illusions.
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local MinionUtils = require(GetScriptDirectory() .. "/FuncLib/hero/minion_lib/utils")
local X = {}
local bot
local lanes = { LANE_TOP, LANE_MID, LANE_BOT }
local lastLaneLogTime = -100
function X.Think(ownerBot, minion)
	if not MinionUtils.IsValidUnit(minion) then
		return
	end
	bot = ownerBot
	if minion.isIllusion then
		if X.ConfuseEnemyWithIllusions(ownerBot, minion) > 0 then
			return
		end
	end
	minion.attack_desire, minion.attack_target = X.ConsiderAttack(minion)
	if X.ConsiderRetreat(minion, minion.attack_target) then
		return
	end
	if minion.attack_desire > 0 then
		if MinionUtils.IsValidTarget(minion.attack_target) then
			minion:Action_AttackUnit(minion.attack_target, false)
			return
		end
	end
	local nextMoveTime = minion._nextMoveTime or 0
	if DotaTime() >= nextMoveTime then
		minion.move_desire, minion.move_location = X.ConsiderMove(minion)
		if minion.move_desire > 0 then
			if GetUnitToLocationDistance(minion, minion.move_location) > 400 then
				minion:Action_MoveToLocation(minion.move_location)
			else
				minion:Action_AttackMove(Fu.GetRandomLocationWithinDist(minion.move_location, 0, 300))
			end
			minion._nextMoveTime = DotaTime() + 0.2
			return
		end
		if bot:IsAlive() then
			minion:Action_MoveToLocation(Fu.GetRandomLocationWithinDist(bot:GetLocation(), 400, 800))
		else
			minion:Action_MoveToLocation(Fu.GetClosestTeamLane(minion))
		end
		minion._nextMoveTime = DotaTime() + 0.2
	end
end
function X.ConfuseEnemyWithIllusions(bot, minion)
	-- Not for a dead hero (#48): its retreat mode and 0 HP stay, and the illusion would walk away all the time.
	if bot:IsAlive() and Fu.GetHP(bot) < 0.4 and Fu.IsRetreating(bot) and not Fu.WeAreStronger(bot, 1200) then
		local botFacing = bot:GetFacing()
		local awayAngle = (botFacing + 180) % 360
		local moveDistance = 800
		local moveLocation = minion:GetLocation()
			+ Vector(moveDistance * math.cos(math.rad(awayAngle)), moveDistance * math.sin(math.rad(awayAngle)))
			+ RandomVector(50)
		minion:Action_MoveToLocation(moveLocation)
		return 1
	end
	return 0
end
function X.ConsiderRetreat(minion, hTarget)
	if minion:IsIllusion() then
		return nil
	end
	if
		(
			MinionUtils.IsValidUnit(hTarget)
				and Fu.GetHP(hTarget) > 0.5
				and hTarget:IsFacingLocation(minion:GetLocation(), 20)
			or Fu.GetHP(minion) < 0.25
		)
		and Fu.GetHP(minion) < 0.3
		and minion:GetHealth() < 300
	then
		minion:Action_MoveToLocation(Fu.GetTeamFountain())
		return 1
	end
	return nil
end
function X.IsTargetInShouldAimToAttackRange(minion, target, maxDistance)
	if not MinionUtils.IsValidUnit(target) then
		return false
	end
	return GetUnitToUnitDistance(minion, target) <= minion:GetAttackRange()
		or not MinionUtils.CantMove(minion)
			and GetUnitToUnitDistance(minion, target) < math.min(minion:GetAttackRange() * 3, maxDistance)
end
function X.ConsiderAttack(minion)
	if MinionUtils.CantAttack(minion) then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local hTarget = X.GetAttackTarget(minion)
	if hTarget ~= nil and not MinionUtils.IsNotAllowedToAttack(hTarget) then
		return BOT_ACTION_DESIRE_HIGH, hTarget
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function X.GetAttackTarget(minion)
	local target = nil
	local minionName = minion:GetUnitName()
	if
		bot:HasModifier("modifier_bane_nightmare")
		and not bot:IsInvulnerable()
		and GetUnitToUnitDistance(bot, minion) < 2000
	then
		target = bot
	end
	if Fu.IsInLaningPhase() then
		if
			(
				string.find(minionName, "forge_spirit")
				or string.find(minionName, "eidolon")
				or string.find(minionName, "beastmaster_boar")
				or string.find(minionName, "lycan_wolf")
			) and MinionUtils.IsTargetedByTower(minion)
		then
			return nil
		end
	end
	for _, enemyUnit in pairs(GetUnitList(UNIT_LIST_ENEMIES)) do
		if Fu.IsValid(enemyUnit) then
			local enemyName = enemyUnit:GetUnitName()
			local specialUnits = Fu.GetSpecialUnits()
			if
				specialUnits[enemyName]
				and enemyUnit:GetTeam() ~= minion:GetTeam()
				and GetUnitToUnitDistance(minion, enemyUnit) <= specialUnits[enemyName] * 1600
				and RandomInt(0, 100) <= specialUnits[enemyName] * 100
			then
				return enemyUnit
			end
		end
	end
	-- The hero's own target only while it is alive: a dead hero's spot is its corpse, so the illusion picks around
	-- itself (#48, game 066: Vengeful Spirit's death illusion).
	if bot:IsAlive() and GetUnitToUnitDistance(bot, minion) < 1600 then
		local enemiesNearBot = Fu.GetEnemiesNearLoc(bot:GetLocation(), 1200)
		if #enemiesNearBot > 0 then
			target = bot:GetAttackTarget()
		end
	end
	if target == nil or Fu.IsRetreating(bot) or MinionUtils.IsTargetedByHero(bot) and bot:GetAttackTarget() == nil then
		target = MinionUtils.GetWeakestHero(1600, minion)
		if target == nil then
			target = MinionUtils.GetWeakestCreep(1600, minion)
		end
		if target == nil then
			target = MinionUtils.GetWeakestTower(1600, minion)
		end
	end
	if target ~= nil then
		if
			not target:IsBuilding()
			and not target:IsTower()
			and target ~= GetAncient(GetOpposingTeam())
			and X.IsTargetUnderEnemyTower(minion, target)
		then
			if string.find(minionName, "warlock_golem") then
				local attackDamage = minion:GetAttackDamage()
				if
					Fu.IsChasingTarget(minion, target)
					and not Fu.WillKillTarget(target, attackDamage, DAMAGE_TYPE_PHYSICAL, 6.0)
				then
					return bot:GetAttackTarget()
				end
			end
			if Fu.GetHP(target) > 0.25 and bot:IsAlive() and not Fu.IsChasingTarget(bot, target) then
				return bot:GetAttackTarget()
			end
		end
	end
	return target
end
function X.ConsiderMove(minion)
	if Fu.CanNotUseAction(minion) or MinionUtils.CantMove(minion) then
		return BOT_MODE_DESIRE_NONE, nil
	end
	local minionName = minion:GetUnitName()
	if
		(string.find(minionName, "terrorblade") or string.find(minionName, "naga_siren")) and not Fu.IsInLaningPhase()
	then
		-- Used to return on the first lane every time (always top). Now each illusion takes a lane no
		-- other illusion of the hero holds; with all three taken it falls through to follow the hero.
		for i = 1, #lanes do
			if not X.IsMinionInLane(minion, lanes[i]) then
				if minion.to_farm_lane ~= lanes[i] and DotaTime() > lastLaneLogTime + 5 then
					lastLaneLogTime = DotaTime()
					print(
						string.format(
							"[OHA-ILLUSION] t=%.0f %s illusion farms lane %d",
							DotaTime(),
							minionName,
							lanes[i]
						)
					)
				end
				minion.to_farm_lane = lanes[i]
				return BOT_ACTION_DESIRE_HIGH, GetLaneFrontLocation(GetTeam(), lanes[i], 0)
			end
		end
	end
	if GetUnitToUnitDistance(bot, minion) > 1600 or not bot:IsAlive() or bot:HasModifier("modifier_teleporting") then
		local teamFightLocation = Fu.GetTeamFightLocation(minion)
		if teamFightLocation and GetUnitToLocationDistance(minion, teamFightLocation) < 2200 then
			return BOT_ACTION_DESIRE_HIGH, teamFightLocation
		end
		return BOT_ACTION_DESIRE_HIGH, Fu.GetClosestTeamLane(minion)
	else
		return BOT_ACTION_DESIRE_HIGH, Fu.GetRandomLocationWithinDist(bot:GetLocation(), 400, 800)
	end
end
function X.IsTargetUnderEnemyTower(minion, target)
	local enemyTowers = minion:GetNearbyTowers(1600, true)
	if enemyTowers then
		if
			Fu.IsValidBuilding(enemyTowers[1])
			and MinionUtils.IsValidUnit(target)
			and Fu.IsInRange(target, enemyTowers[1], 880)
		then
			return true
		end
	end
	return false
end
function X.IsMinionInLane(minion, lane)
	for _, allyUnit in pairs(GetUnitList(UNIT_LIST_ALLIES)) do
		if
			Fu.IsValid(allyUnit)
			and minion ~= allyUnit
			and allyUnit:IsIllusion()
			and string.find(bot:GetUnitName(), allyUnit:GetUnitName())
		then
			if
				allyUnit.to_farm_lane == lane
				or GetUnitToLocationDistance(allyUnit, GetLaneFrontLocation(GetTeam(), lane, 0)) < 1600
			then
				return true
			end
		end
	end
	return false
end
return X
