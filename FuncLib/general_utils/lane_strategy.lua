-- Shared helper: lane strategy.
local function installLaneStrategy(Fu)
	function Fu.ShouldGoFarmDuringLaning(bot)
		local assignedLane = bot:GetAssignedLane()
		return Fu.IsInLaningPhase()
			and GetHeroDeaths(bot:GetPlayerID()) >= 4
			and (GetHeroKills(bot:GetPlayerID()) == 0 or GetHeroKills(bot:GetPlayerID()) / GetHeroDeaths(
				bot:GetPlayerID()
			) < 0.5)
			and Fu.IsCore(bot)
			and bot:GetLevel() >= 4
			and bot:GetLevel() < 10
			and Fu.GetEnemyCountInLane(assignedLane) >= 1
	end
	function Fu.GetMostFarmLaneDesire(bot)
		local topLaneDesire = GetFarmLaneDesire(LANE_TOP)
		local midLaneDesire = GetFarmLaneDesire(LANE_MID)
		local botLaneDesire = GetFarmLaneDesire(LANE_BOT)
		if topLaneDesire > midLaneDesire and topLaneDesire > botLaneDesire then
			return LANE_TOP, topLaneDesire
		end
		if botLaneDesire > midLaneDesire and botLaneDesire > topLaneDesire then
			return LANE_BOT, botLaneDesire
		end
		if DotaTime() < 8 * 60 then
			return bot:GetAssignedLane(), 0.667
		end
		return LANE_MID, midLaneDesire
	end
	function Fu.GetMostDefendLaneDesire()
		local topLaneDesire = Fu.GetDefendLaneDesire(LANE_TOP)
		local midLaneDesire = Fu.GetDefendLaneDesire(LANE_MID)
		local botLaneDesire = Fu.GetDefendLaneDesire(LANE_BOT)
		if midLaneDesire > topLaneDesire and midLaneDesire > botLaneDesire then
			return LANE_MID, midLaneDesire
		end
		if topLaneDesire > midLaneDesire and topLaneDesire > botLaneDesire then
			return LANE_TOP, topLaneDesire
		end
		if botLaneDesire > midLaneDesire and botLaneDesire > topLaneDesire then
			return LANE_BOT, botLaneDesire
		end
		return LANE_MID, midLaneDesire
	end
	function Fu.GetDefendLaneDesire(lane)
		local defendDesire, customDesires = GetDefendLaneDesire(lane), GetBot().DefendLaneDesire
		if customDesires ~= nil and customDesires[lane] ~= nil and customDesires[lane] > defendDesire then
			return customDesires[lane]
		end
		return defendDesire
	end
	function Fu.IsPingCloseToValidTower(team, ping, maxDistance, maxPingAge)
		if ping and ping.location then
			local buildingList = UNIT_LIST_ALLIED_BUILDINGS
			if team == GetOpposingTeam() then
				buildingList = UNIT_LIST_ENEMY_BUILDINGS
			end
			for _, building in pairs(GetUnitList(buildingList)) do
				if
					building ~= nil
					and building:IsAlive()
					and building:CanBeSeen()
					and not building:IsInvulnerable()
					and not building:HasModifier("modifier_backdoor_protection")
					and not building:HasModifier("modifier_backdoor_protection_in_base")
					and not building:HasModifier("modifier_backdoor_protection_active")
					and not string.find(building:GetUnitName(), "fillers")
				then
					local buildingName = building:GetUnitName()
					if
						Fu.GetDistance(building:GetLocation(), ping.location) <= maxDistance
						and GameTime() < ping.time + maxPingAge
					then
						local lane = LANE_MID
						if string.find(buildingName, "_fort") then
							lane = LANE_MID
						elseif string.find(buildingName, "_top") then
							lane = LANE_TOP
						elseif string.find(buildingName, "_mid") then
							lane = LANE_MID
						elseif string.find(buildingName, "_bot") then
							lane = LANE_BOT
						end
						return true, lane
					end
				end
			end
		end
		return false, -1
	end
	function Fu.GetMostPushLaneDesire()
		local topLaneDesire = GetPushLaneDesire(LANE_TOP)
		local midLaneDesire = GetPushLaneDesire(LANE_MID)
		local botLaneDesire = GetPushLaneDesire(LANE_BOT)
		if topLaneDesire > midLaneDesire and topLaneDesire > botLaneDesire then
			return LANE_TOP, topLaneDesire
		end
		if botLaneDesire > midLaneDesire and botLaneDesire > topLaneDesire then
			return LANE_BOT, botLaneDesire
		end
		return LANE_MID, midLaneDesire
	end
end
return installLaneStrategy
