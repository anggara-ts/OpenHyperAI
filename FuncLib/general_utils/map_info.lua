-- Shared helper: map info.
local function installMapInfo(Fu)
	local radiantFountain = Vector(-6619, -6336, 384)
	local direFountain = Vector(6928, 6372, 392)
	local tormentorDayLocation = Vector(7714, -6016, 392)
	local tormentorNightLocation = Vector(-7678, 6337, 392)
	function Fu.GetTeamFountain()
		local team = GetTeam()
		if team == TEAM_DIRE then
			return direFountain
		else
			return radiantFountain
		end
	end
	function Fu.GetEnemyFountain()
		local team = GetTeam()
		if team == TEAM_DIRE then
			return radiantFountain
		else
			return direFountain
		end
	end
	function Fu.GetEscapeLoc()
		local bot = GetBot()
		local team = GetTeam()
		if bot:DistanceFromFountain() > 2500 then
			return GetAncient(team):GetLocation()
		else
			if team == TEAM_DIRE then
				return direFountain
			else
				return radiantFountain
			end
		end
	end
	function Fu.GetDistanceFromEnemyFountain(unit)
		local enemyFountain = Fu.GetEnemyFountain()
		local distance = GetUnitToLocationDistance(unit, enemyFountain)
		return distance
	end
	function Fu.GetDistanceFromAllyFountain(unit)
		local allyFountain = Fu.GetTeamFountain()
		local distance = GetUnitToLocationDistance(unit, allyFountain)
		return distance
	end
	function Fu.GetDistanceFromAncient(unit, isEnemy)
		local ancient = GetAncient(GetTeam())
		if isEnemy then
			ancient = GetAncient(GetOpposingTeam())
		end
		return GetUnitToUnitDistance(unit, ancient)
	end
	function Fu.IsRoshanCloseToChangingSides()
		return DotaTime() % 300 >= 300 - 30
	end
	function Fu.IsLocHaveTower(radius, isEnemy, location)
		local team = GetTeam()
		if isEnemy then
			team = GetOpposingTeam()
		end
		if
			not isEnemy and Fu.GetLocationToLocationDistance(location, Fu.GetTeamFountain()) < 2500
			or isEnemy and Fu.GetLocationToLocationDistance(location, Fu.GetEnemyFountain()) < 2500
		then
			return true
		end
		for towerId = 0, 10 do
			local tower = GetTower(team, towerId)
			if tower ~= nil and GetUnitToLocationDistance(tower, location) <= radius then
				return true
			end
		end
		return false
	end
	function Fu.GetNearbyLocationToTp(location)
		local team = GetTeam()
		local fountain = Fu.GetTeamFountain()
		if Fu.GetLocationToLocationDistance(location, fountain) <= 2500 then
			return location
		end
		local bestBuilding = nil
		local bestDistance = 99999
		for towerId = 0, 10, 1 do
			local tower = GetTower(team, towerId)
			if tower ~= nil and GetUnitToLocationDistance(tower, location) < bestDistance then
				bestBuilding = tower
				bestDistance = GetUnitToLocationDistance(tower, location)
			end
		end
		local watchTowers = Fu.Site.GetAllWatchTower()
		for _, watchTower in pairs(watchTowers) do
			if
				watchTower ~= nil
				and watchTower:GetTeam() == team
				and GetUnitToLocationDistance(watchTower, location) < bestDistance - 1300
				and (
					not Fu.IsEnemyHeroAroundLocation(watchTower:GetLocation(), 600)
					or Fu.IsAllyHeroAroundLocation(watchTower:GetLocation(), 600)
				)
			then
				bestBuilding = watchTower
				bestDistance = GetUnitToLocationDistance(watchTower, location) + 1300
			end
		end
		if bestBuilding ~= nil then
			return Fu.GetLocationTowardDistanceLocation(bestBuilding, location, 575)
		end
		return fountain
	end
	function Fu.IsInAllyArea(unit)
		local allyAncient = GetAncient(GetTeam())
		local enemyAncient = GetAncient(GetOpposingTeam())
		if GetUnitToUnitDistance(unit, allyAncient) + 768 < GetUnitToUnitDistance(unit, enemyAncient) then
			return true
		end
		return false
	end
	function Fu.IsInEnemyArea(unit)
		local allyAncient = GetAncient(GetTeam())
		local enemyAncient = GetAncient(GetOpposingTeam())
		if GetUnitToUnitDistance(unit, enemyAncient) + 1280 < GetUnitToUnitDistance(unit, allyAncient) then
			return true
		end
		return false
	end
	function Fu.IsAllyHeroAroundLocation(location, radius)
		for i = 1, #GetTeamPlayers(GetTeam()) do
			local member = GetTeamMember(i)
			if member ~= nil and member:IsAlive() and GetUnitToLocationDistance(member, location) <= radius then
				return true
			end
		end
		return false
	end
	function Fu.IsEnemyHeroAroundLocation(location, radius)
		for _, playerId in pairs(GetTeamPlayers(GetOpposingTeam())) do
			if IsHeroAlive(playerId) then
				local lastSeenInfo = GetHeroLastSeenInfo(playerId)
				if lastSeenInfo ~= nil then
					local lastSeen = lastSeenInfo[1]
					if
						lastSeen ~= nil
						and Fu.GetLocationToLocationDistance(location, lastSeen.location) <= radius
						and lastSeen.time_since_seen < 2.0
					then
						return true
					end
				end
			end
		end
		return false
	end
	function Fu.IsEarlyGame()
		return DotaTime() < (Fu.IsModeTurbo() and 7 * 60 or 12 * 60)
	end
	function Fu.IsMidGame()
		local time = DotaTime()
		local midGameStart = Fu.IsModeTurbo() and 7 * 60 or 12 * 60
		local lateGameStart = Fu.IsModeTurbo() and 20 * 60 or 26 * 60
		return time >= midGameStart and time < lateGameStart
	end
	function Fu.IsLateGame()
		return DotaTime() >= (Fu.IsModeTurbo() and 20 * 60 or 26 * 60)
	end
	function Fu.IsModeTurbo()
		for _, unit in pairs(GetUnitList(UNIT_LIST_ALLIES)) do
			if unit ~= nil and unit:GetUnitName() == "npc_dota_courier" then
				if unit:GetCurrentMovementSpeed() == 1100 then
					return true
				end
			end
		end
		return false
	end
	function Fu.CheckTimeOfDay()
		local dayNightCycle = 600
		local cycleTime = DotaTime() % dayNightCycle
		local dayLength = 300
		if cycleTime < dayLength then
			return "day", cycleTime
		else
			return "night", cycleTime
		end
	end
	local lastRoshanKillTime = 0.0
	function Fu.IsRoshanAlive()
		if GetRoshanKillTime() > lastRoshanKillTime then
			lastRoshanKillTime = GetRoshanKillTime()
		end
		if GetRoshanKillTime() == 0 or DotaTime() - lastRoshanKillTime > (Fu.IsModeTurbo() and 6 * 60 or 11 * 60) then
			return true
		end
		return false
	end
	function Fu.IsInLaningPhase()
		local bot = GetBot()
		if bot.isInLanePhase ~= nil and bot.isInLanePhase then
			return true
		end
		return false
	end
	function Fu.IsLocationInChrono(location)
		for _, enemyHero in pairs(GetUnitList(UNIT_LIST_ENEMY_HEROES)) do
			if
				Fu.IsValidHero(enemyHero)
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and GetUnitToLocationDistance(enemyHero, location) < 300
				and enemyHero:HasModifier("modifier_faceless_void_chronosphere_freeze")
			then
				return true
			end
		end
		for _, allyHero in pairs(GetUnitList(UNIT_LIST_ALLIED_HEROES)) do
			if
				Fu.IsValidHero(allyHero)
				and not allyHero:IsIllusion()
				and GetUnitToLocationDistance(allyHero, location) < 300
				and allyHero:HasModifier("modifier_faceless_void_chronosphere_freeze")
			then
				return true
			end
		end
		return false
	end
	function Fu.IsLocationInBlackHole(location)
		for _, enemyHero in pairs(GetUnitList(UNIT_LIST_ENEMY_HEROES)) do
			if
				Fu.IsValidHero(enemyHero)
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and GetUnitToLocationDistance(enemyHero, location) < 300
				and (
					enemyHero:HasModifier("modifier_enigma_black_hole_pull")
					or enemyHero:HasModifier("modifier_enigma_black_hole_pull_scepter")
				)
			then
				return true
			end
		end
		return false
	end
	function Fu.IsEnemyChronosphereInLocation(location)
		local radius = 500
		for _, unit in pairs(GetUnitList(UNIT_LIST_ALLIES)) do
			if
				Fu.IsValid(unit)
				and GetUnitToLocationDistance(unit, location) <= radius
				and unit:HasModifier("modifier_faceless_void_chronosphere_freeze")
			then
				return true
			end
		end
		return false
	end
	function Fu.IsEnemyBlackHoleInLocation(location)
		local radius = 500
		for _, unit in pairs(GetUnitList(UNIT_LIST_ALLIES)) do
			if
				Fu.IsValid(unit)
				and GetUnitToLocationDistance(unit, location) <= radius
				and (
					unit:HasModifier("modifier_enigma_black_hole_pull")
					or unit:HasModifier("modifier_enigma_black_hole_pull_scepter")
				)
			then
				return true
			end
		end
		return false
	end
	function Fu.IsLocationInArena(location, radius)
		for _, enemyHero in pairs(GetUnitList(UNIT_LIST_ENEMY_HEROES)) do
			if
				Fu.IsValidHero(enemyHero)
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and GetUnitToLocationDistance(enemyHero, location) < radius
				and (
					enemyHero:HasModifier("modifier_mars_arena_of_blood_leash")
					or enemyHero:HasModifier("modifier_mars_arena_of_blood_animation")
				)
			then
				return true
			end
		end
		for _, allyHero in pairs(GetUnitList(UNIT_LIST_ALLIED_HEROES)) do
			if
				Fu.IsValidHero(allyHero)
				and not allyHero:IsIllusion()
				and GetUnitToLocationDistance(allyHero, location) < radius
				and allyHero:HasModifier("modifier_mars_arena_of_blood_animation")
			then
				return true
			end
		end
		return false
	end
	function Fu.IsHumanInLoc(location, radius)
		for i = 1, #GetTeamPlayers(GetTeam()) do
			local member = GetTeamMember(i)
			if
				member ~= nil
				and member:IsAlive()
				and not member:IsBot()
				and not member:IsIllusion()
				and not member:HasModifier("modifier_arc_warden_tempest_double")
				and not Fu.IsMeepoClone(member)
				and GetUnitToLocationDistance(member, location) <= radius
			then
				return true
			end
		end
		return false
	end
	function Fu.GetCurrentRoshanLocation()
		local radiantRoshanLocation = Fu.Utils.RadiantRoshanLoc
		local direRoshanLocation = Fu.Utils.DireRoshanLoc
		if DotaTime() < 15 * 60 then
			return radiantRoshanLocation
		end
		if Fu.CheckTimeOfDay() == "day" then
			return radiantRoshanLocation
		else
			return direRoshanLocation
		end
	end
	function Fu.GetTormentorLocation(_)
		if Fu.CheckTimeOfDay() == "day" then
			return tormentorDayLocation
		else
			return tormentorNightLocation
		end
	end
	local radiantDayWaitLocation = Vector(7090, -7220, 256)
	local direDayWaitLocation = Vector(8280, -5350, 128)
	local radiantNightWaitLocation = Vector(-8130, 5450, 128)
	local direNightWaitLocation = Vector(-6970, 7330, 256)
	-- Game 036, 30:51: two cores went to the Tormentor while Dire took our bottom T2. Returns why
	-- our side needs us (a lane defend desire over 0.5, or enemy heroes within 1200 of one of our
	-- towers or barracks), or nil.
	function Fu.OurLaneThreatened()
		for _, lane in ipairs({ LANE_TOP, LANE_MID, LANE_BOT }) do
			if (GetDefendLaneDesire(lane) or 0) > 0.5 then
				return "defend-lane" .. tostring(lane)
			end
		end
		for _, building in pairs(GetUnitList(UNIT_LIST_ALLIED_BUILDINGS) or {}) do
			if building ~= nil and not building:IsNull() and building:IsAlive() then
				local buildingName = building:GetUnitName() or ""
				if
					(string.find(buildingName, "tower", 1, true) or string.find(buildingName, "rax", 1, true))
					and #Fu.GetEnemiesNearLoc(building:GetLocation(), 1200) >= 1
				then
					return "enemy-at-" .. (string.gsub(buildingName, "npc_dota_", ""))
				end
			end
		end
		return nil
	end
	function Fu.GetTormentorWaitingLocation(_)
		local timeOfDay = Fu.CheckTimeOfDay()
		if timeOfDay == "day" then
			return GetTeam() == TEAM_RADIANT and radiantDayWaitLocation or direDayWaitLocation
		else
			return GetTeam() == TEAM_RADIANT and radiantNightWaitLocation or direNightWaitLocation
		end
	end
	local teamPlayerIds = nil
	function Fu.IsClosestToDustLocation(bot, location)
		if teamPlayerIds == nil then
			teamPlayerIds = GetTeamPlayers(GetTeam())
		end
		local closestMember = nil
		local closestDistance = 100000
		-- GetTeamMember takes a team slot (1-5), not a player ID; this loop used to pass the player ID.
		for i = 1, #teamPlayerIds do
			local member = GetTeamMember(i)
			if
				Fu.IsValidHero(member)
				and member:GetItemSlotType(member:FindItemSlot("item_dust")) == ITEM_SLOT_TYPE_MAIN
				and member:GetItemInSlot(member:FindItemSlot("item_dust")):IsFullyCastable()
				and not Fu.IsSuspiciousIllusion(member)
			then
				local distance = GetUnitToLocationDistance(member, location)
				if distance < closestDistance then
					closestMember = member
					closestDistance = distance
				end
			end
		end
		if closestMember ~= nil then
			return closestMember == bot
		end
	end
	function Fu.GetPushTPLocation(lane)
		local laneFront = GetLaneFrontLocation(GetTeam(), lane, 0)
		local tpLocation = Fu.GetNearbyLocationToTp(laneFront)
		if Fu.GetLocationToLocationDistance(laneFront, tpLocation) < 1600 then
			return tpLocation
		end
	end
	function Fu.GetDefendTPLocation(lane)
		return GetLaneFrontLocation(GetTeam(), lane, -950)
	end
end
return installMapInfo
