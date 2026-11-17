-- Shared helper: hero info.
local function installHeroInfo(Fu)
	function Fu.IsCore(hero)
		return Fu.GetPosition(hero) <= 3
	end
	local isPositionHumanCache = {}
	function Fu.IsPosxHuman(position)
		if isPositionHumanCache[position] ~= nil then
			return isPositionHumanCache[position]
		end
		for _, allyHero in pairs(GetUnitList(UNIT_LIST_ALLIED_HEROES)) do
			if Fu.IsValidHero(allyHero) and Fu.GetPosition(allyHero) == position and not allyHero:IsBot() then
				isPositionHumanCache[position] = true
				return true
			end
		end
		isPositionHumanCache[position] = false
		return false
	end
	function Fu.GetPosition(hero)
		if hero.isBear then
			return Fu.GetPosition(Fu.Utils.GetLoneDruid(hero).hero)
		end
		local position = Fu.Role.GetPosition(hero)
		if position == nil then
			position = 2
		end
		return position
	end
	function Fu.GetExpectedLane(hero)
		if IsLanMode and IsLanMode() then
			local assignedLane = hero:GetAssignedLane()
			if assignedLane == LANE_TOP or assignedLane == LANE_MID or assignedLane == LANE_BOT then
				return assignedLane
			end
		end
		local position = Fu.GetPosition(hero)
		local team = hero:GetTeam()
		if team == TEAM_RADIANT then
			if position == 2 then
				return LANE_MID
			elseif position == 1 or position == 5 then
				return LANE_BOT
			elseif position == 3 or position == 4 then
				return LANE_TOP
			end
		else
			if position == 2 then
				return LANE_MID
			elseif position == 1 or position == 5 then
				return LANE_TOP
			elseif position == 3 or position == 4 then
				return LANE_BOT
			end
		end
		return hero:GetAssignedLane() or LANE_MID
	end
	function Fu.IsNotSelf(unitA, unitB)
		if unitA:GetUnitName() ~= unitB:GetUnitName() then
			return true
		end
		return false
	end
	function Fu.IsThereNonSelfCoreNearby(radius)
		local bot = GetBot()
		local nearbyAllies = Fu.GetNearbyHeroes(bot, radius, false, BOT_MODE_NONE)
		for _, allyHero in pairs(nearbyAllies) do
			if Fu.IsCore(allyHero) and bot ~= allyHero then
				return true
			end
		end
		return false
	end
	function Fu.IsThereCoreNearby(radius)
		for i = 1, #GetTeamPlayers(GetTeam()) do
			local member = GetTeamMember(i)
			if
				member ~= nil
				and member ~= GetBot()
				and Fu.IsCore(member)
				and Fu.IsInRange(GetBot(), member, radius)
			then
				return true
			end
		end
		return false
	end
	function Fu.GetClosestCore(hero, radius)
		for i = 1, #GetTeamPlayers(GetTeam()) do
			local member = GetTeamMember(i)
			if
				member ~= nil
				and member:IsAlive()
				and member ~= hero
				and Fu.IsCore(hero)
				and GetUnitToUnitDistance(hero, member) <= radius
				and not Fu.IsSuspiciousIllusion(member)
			then
				return member
			end
		end
		return nil
	end
	function Fu.GetClosestAlly(hero, radius)
		for i = 1, #GetTeamPlayers(GetTeam()) do
			local member = GetTeamMember(i)
			if
				member ~= nil
				and member:IsAlive()
				and member ~= hero
				and GetUnitToUnitDistance(hero, member) <= radius
				and not Fu.IsSuspiciousIllusion(member)
			then
				return member
			end
		end
		return nil
	end
	function Fu.GetLanePartner(hero)
		if hero:GetAssignedLane() == LANE_MID then
			return nil
		end
		for i = 1, #GetTeamPlayers(GetTeam()) do
			local member = GetTeamMember(i)
			if
				member ~= nil
				and member:IsAlive()
				and member ~= hero
				and member:GetAssignedLane() == hero:GetAssignedLane()
			then
				return member
			end
		end
		return nil
	end
	function Fu.GetFirstBotInTeam()
		for i = 1, #GetTeamPlayers(GetTeam()) do
			local member = GetTeamMember(i)
			if member ~= nil and member:IsBot() then
				return member
			end
		end
	end
	function Fu.GetClosestTeamLane(unit)
		local topFront = GetLocationAlongLane(LANE_TOP, GetLaneFrontAmount(GetTeam(), LANE_TOP, false))
		local midFront = GetLocationAlongLane(LANE_MID, GetLaneFrontAmount(GetTeam(), LANE_MID, false))
		local bottomFront = GetLocationAlongLane(LANE_BOT, GetLaneFrontAmount(GetTeam(), LANE_BOT, false))
		local topDistance = GetUnitToLocationDistance(unit, topFront)
		local midDistance = GetUnitToLocationDistance(unit, midFront)
		local bottomDistance = GetUnitToLocationDistance(unit, bottomFront)
		if topDistance < midDistance and topDistance < bottomDistance then
			return topFront
		elseif midDistance < topDistance and midDistance < bottomDistance then
			return midFront
		elseif bottomDistance < topDistance and bottomDistance < midDistance then
			return bottomFront
		end
		return midFront
	end
	function Fu.GetCoresAverageNetworth()
		local bot = GetBot()
		if bot._coreNWCache and DotaTime() - bot._coreNWCache[1] <= 2.0 then
			return bot._coreNWCache[2]
		end
		local totalNetworth = 0
		local coreCount = 0
		for i = 1, #GetTeamPlayers(GetTeam()) do
			local member = GetTeamMember(i)
			if Fu.IsValidHero(member) and Fu.IsCore(member) then
				totalNetworth = totalNetworth + member:GetNetWorth()
				coreCount = coreCount + 1
			end
		end
		local averageNetworth = totalNetworth / coreCount
		bot._coreNWCache = { DotaTime(), averageNetworth }
		return averageNetworth
	end
	function Fu.IsHaveAegis(hero)
		return hero:FindItemSlot("item_aegis") >= 0
	end
	function Fu.DoesTeamHaveAegis()
		local bot = GetBot()
		if bot._aegisCache and DotaTime() - bot._aegisCache[1] <= 2.0 then
			return bot._aegisCache[2]
		end
		local teamPlayers = GetTeamPlayers(GetTeam())
		for i = 1, #teamPlayers do
			local member = GetTeamMember(i)
			if Fu.IsValidHero(member) and Fu.IsHaveAegis(member) then
				bot._aegisCache = { DotaTime(), true }
				return true
			end
		end
		bot._aegisCache = { DotaTime(), false }
		return false
	end
	function Fu.IsOtherAllysTarget(target)
		local bot = GetBot()
		local nearbyAllies = Fu.GetNearbyHeroes(bot, 800, false, BOT_MODE_NONE)
		if #nearbyAllies <= 1 then
			return false
		end
		for _, allyHero in pairs(nearbyAllies) do
			if
				Fu.IsValid(allyHero)
				and allyHero ~= bot
				and not allyHero:IsIllusion()
				and (
					Fu.GetProperTarget(allyHero) == target
					or not allyHero:IsBot() and allyHero:IsFacingLocation(target:GetLocation(), 20)
				)
			then
				return true
			end
		end
		return false
	end
	function Fu.IsAllysTarget(target)
		local bot = GetBot()
		local nearbyAllies = Fu.GetNearbyHeroes(bot, 800, false, BOT_MODE_NONE)
		for _, allyHero in pairs(nearbyAllies) do
			if
				Fu.IsValid(allyHero)
				and not allyHero:IsIllusion()
				and (
					Fu.GetProperTarget(allyHero) == target
					or not allyHero:IsBot() and allyHero:IsFacingLocation(target:GetLocation(), 12)
				)
			then
				return true
			end
		end
		return false
	end
	function Fu.IsEnemyFacingUnit(unit, radius, facingAngle)
		local unitLocation = unit:GetLocation()
		if radius > 1600 then
			radius = 1600
		end
		local nearbyEnemies = Fu.GetNearbyHeroes(unit, radius, true, BOT_MODE_NONE)
		for _, enemyHero in pairs(nearbyEnemies) do
			if Fu.IsValid(enemyHero) and enemyHero:IsFacingLocation(unitLocation, facingAngle) then
				return true
			end
		end
		return false
	end
	function Fu.IsEnemyTargetUnit(unit, radius)
		if radius > 1600 then
			radius = 1600
		end
		local nearbyEnemies = Fu.GetNearbyHeroes(GetBot(), radius, true, BOT_MODE_NONE)
		for _, enemyHero in pairs(nearbyEnemies) do
			if Fu.IsValid(enemyHero) and Fu.GetProperTarget(enemyHero) == unit then
				return true
			end
		end
		return false
	end
	function Fu.CheckLoneDruid()
		local loneDruid = { hero = nil, bear = nil }
		for _, unit in pairs(GetUnitList(UNIT_LIST_ALL)) do
			if Fu.IsValid(unit) and not Fu.IsSuspiciousIllusion(unit) then
				local unitName = unit:GetUnitName()
				if unitName == "npc_dota_hero_lone_druid" then
					loneDruid.hero = unit
				elseif unitName == "npc_dota_hero_lone_druid_bear" then
					loneDruid.bear = unit
				end
			end
		end
		return loneDruid
	end
	function Fu.GetHumanPing()
		local ping = nil
		for i = 1, #GetTeamPlayers(GetTeam()) do
			local member = GetTeamMember(i)
			if member ~= nil and not member:IsBot() then
				return member, member:GetMostRecentPing()
			end
		end
		return nil, ping
	end
	function Fu.FindEnemyUnit(unitNamePattern)
		for _, unit in pairs(GetUnitList(UNIT_LIST_ENEMIES)) do
			if Fu.IsValid(unit) then
				if string.find(unit:GetUnitName(), unitNamePattern) then
					return unit
				end
			end
		end
		return nil
	end
	function Fu.HasEnemyIceSpireNearby(unit, radius)
		for _, enemyUnit in pairs(GetUnitList(UNIT_LIST_ENEMIES)) do
			if
				Fu.IsValid(enemyUnit)
				and enemyUnit:GetUnitName() == "npc_dota_lich_ice_spire"
				and Fu.IsInRange(unit, enemyUnit, radius)
			then
				return enemyUnit
			end
		end
		return false
	end
	function Fu.AnyAllyAffectedByChainFrost(unit, radius)
		for _, allyUnit in pairs(GetUnitList(UNIT_LIST_ALLIES)) do
			if
				Fu.IsValid(allyUnit)
				and Fu.IsInRange(unit, allyUnit, radius)
				and allyUnit ~= unit
				and allyUnit:HasModifier("modifier_lich_chainfrost_slow")
			then
				return true
			end
		end
		return false
	end
end
return installHeroInfo
