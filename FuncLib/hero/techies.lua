-- Hero-specific helper: techies.
local X = {}
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
X.nMinMineDistance = 350
X.nProximityMineDmgRadius = 500
local towerOrder =
	{ TOWER_TOP_1, TOWER_MID_1, TOWER_BOT_1, TOWER_TOP_2, TOWER_MID_2, TOWER_BOT_2, TOWER_TOP_3, TOWER_MID_3, TOWER_BOT_3 }
local radiantMineSpots = {
	[TOWER_TOP_1] = { Vector(-5011, 2799, 74), Vector(-4288, 2089, 76), Vector(-3663, 3500, 128) },
	[TOWER_MID_1] = { Vector(-1921, 377, 68), Vector(-1459, 1120, 0), Vector(1030, -1195, 0), Vector(1916, -2890, 128) },
	[TOWER_BOT_1] = { Vector(3821, -3474, 128), Vector(7285, -4665, 128), Vector(7908, -5795, 128) },
	[TOWER_TOP_2] = {
		Vector(-5011, 2799, 74),
		Vector(-4288, 2089, 76),
		Vector(-3663, 3500, 128),
		Vector(-7798, 1156, 256),
		Vector(-4150, -48, 256),
	},
	[TOWER_MID_2] = {
		Vector(-1921, 377, 68),
		Vector(-1459, 1120, 0),
		Vector(1030, -1195, 0),
		Vector(1916, -2890, 128),
		Vector(-3345, -1644, 210),
		Vector(-846, -2191, 256),
		Vector(-1587, -3529, 256),
	},
	[TOWER_BOT_2] = {
		Vector(3821, -3474, 128),
		Vector(7285, -4665, 128),
		Vector(7908, -5795, 128),
		Vector(1241, -7744, 128),
		Vector(1109, -4812, 256),
	},
	[TOWER_TOP_3] = {
		Vector(-5011, 2799, 74),
		Vector(-4288, 2089, 76),
		Vector(-3663, 3500, 128),
		Vector(-7798, 1156, 256),
		Vector(-4150, -48, 256),
		Vector(-5298, -1721, 202),
		Vector(-7723, -2107, 256),
	},
	[TOWER_MID_3] = {
		Vector(-1921, 377, 68),
		Vector(-1459, 1120, 0),
		Vector(1030, -1195, 0),
		Vector(1916, -2890, 128),
		Vector(-3345, -1644, 210),
		Vector(-846, -2191, 256),
		Vector(-1587, -3529, 256),
		Vector(-3057, -4569, 128),
		Vector(-4906, -2730, 128),
	},
	[TOWER_BOT_3] = {
		Vector(3821, -3474, 128),
		Vector(7285, -4665, 128),
		Vector(7908, -5795, 128),
		Vector(1241, -7744, 128),
		Vector(1109, -4812, 256),
		Vector(-969, -4866, 256),
		Vector(-1200, -8400, 128),
		Vector(-2145, -7385, 128),
	},
}
local direMineSpots = {
	[TOWER_TOP_1] = { Vector(-5273, 4810, 128), Vector(5609, 6573, 128), Vector(-3314, 3704, 195) },
	[TOWER_MID_1] = {
		Vector(-1655, 850, 0),
		Vector(-1655, 850, 0),
		Vector(1187, -1476, 0),
		Vector(1187, -1476, 0),
		Vector(3194, -661, 256),
	},
	[TOWER_BOT_1] = { Vector(5108, -2320, 128), Vector(8068, -2248, 256), Vector(4640, -3424, 128) },
	[TOWER_TOP_2] = {
		Vector(-5273, 4810, 128),
		Vector(5609, 6573, 128),
		Vector(-3314, 3704, 195),
		Vector(-2250, 4830, 256),
		Vector(-2737, 6813, 128),
		Vector(-1454, 3012, 256),
	},
	[TOWER_MID_2] = {
		Vector(-1655, 850, 0),
		Vector(-1655, 850, 0),
		Vector(1187, -1476, 0),
		Vector(1187, -1476, 0),
		Vector(3194, -661, 256),
		Vector(683, 1807, 128),
		Vector(2532, 1304, 128),
		Vector(3575, 1481, 128),
	},
	[TOWER_BOT_2] = {
		Vector(5108, -2320, 128),
		Vector(8068, -2248, 256),
		Vector(4640, -3424, 128),
		Vector(5235, -984, 256),
		Vector(5107, 600, 256),
		Vector(8270, -59, 256),
	},
	[TOWER_TOP_3] = {
		Vector(-5273, 4810, 128),
		Vector(5609, 6573, 128),
		Vector(-3314, 3704, 195),
		Vector(-2250, 4830, 256),
		Vector(-2737, 6813, 128),
		Vector(-1454, 3012, 256),
		Vector(1948, 6918, 128),
		Vector(-161, 5172, 128),
	},
	[TOWER_MID_3] = {
		Vector(-1655, 850, 0),
		Vector(-1655, 850, 0),
		Vector(1187, -1476, 0),
		Vector(1187, -1476, 0),
		Vector(3194, -661, 256),
		Vector(683, 1807, 128),
		Vector(2532, 1304, 128),
		Vector(3575, 1481, 128),
		Vector(4248, 1999, 128),
		Vector(2578, 3729, 128),
	},
	[TOWER_BOT_3] = {
		Vector(5108, -2320, 128),
		Vector(8068, -2248, 256),
		Vector(4640, -3424, 128),
		Vector(5235, -984, 256),
		Vector(5107, 600, 256),
		Vector(8270, -59, 256),
		Vector(4248, 1999, 128),
		Vector(7072, 1376, 128),
	},
}
function X.GetMineSpotsBeforeTowerFall()
	local spots = {}
	for towerIndex = 1, #towerOrder do
		local tower = GetTower(GetTeam(), towerOrder[towerIndex])
		if
			tower ~= nil
			or (
				tower == GetTower(GetTeam(), TOWER_TOP_3) == nil
				or tower == GetTower(GetTeam(), TOWER_MID_3) == nil
				or tower == GetTower(GetTeam(), TOWER_BOT_3) == nil
			)
		then
			if
				tower == GetTower(GetTeam(), TOWER_TOP_2) and GetTower(GetTeam(), TOWER_TOP_1) ~= nil
				or tower == GetTower(GetTeam(), TOWER_TOP_3) and GetTower(GetTeam(), TOWER_TOP_2) ~= nil
				or tower == GetTower(GetTeam(), TOWER_MID_2) and GetTower(GetTeam(), TOWER_MID_1) ~= nil
				or tower == GetTower(GetTeam(), TOWER_MID_3) and GetTower(GetTeam(), TOWER_MID_2) ~= nil
				or tower == GetTower(GetTeam(), TOWER_BOT_2) and GetTower(GetTeam(), TOWER_BOT_1) ~= nil
				or tower == GetTower(GetTeam(), TOWER_BOT_3) and GetTower(GetTeam(), TOWER_BOT_2) ~= nil
			then
				break
			end
			if GetTeam() == TEAM_RADIANT then
				for i = 1, #radiantMineSpots[towerOrder[towerIndex]] do
					table.insert(spots, radiantMineSpots[towerOrder[towerIndex]][i])
				end
			else
				for i = 1, #direMineSpots[towerOrder[towerIndex]] do
					table.insert(spots, direMineSpots[towerOrder[towerIndex]][i])
				end
			end
		end
	end
	return spots
end
function X.GetAvailableSpot()
	local spots = {}
	for _, spot in pairs(X.GetMineSpotsBeforeTowerFall()) do
		table.insert(spots, spot)
	end
	return spots
end
local searchMaxRadius = 100
local searchStep = 50
local function FindPassableLocationNear(center, maxRadius, step)
	for searchRadius = step, maxRadius, step do
		for angle = 0, 360, 50 do
			local offsetX = searchRadius * math.cos(math.rad(angle))
			local offsetY = searchRadius * math.sin(math.rad(angle))
			local candidate = center + Vector(offsetX, offsetY, 0)
			if IsLocationPassable(candidate) then
				return candidate
			end
		end
	end
	return nil
end
local mineOffsets = {
	Vector(300, 0, 0),
	Vector(-300, 0, 0),
	Vector(0, 300, 0),
	Vector(0, -300, 0),
	Vector(212, 212, 0),
	Vector(-212, 212, 0),
	Vector(212, -212, 0),
	Vector(-212, -212, 0),
}
function X.GetGoodPlaceForMiningNear(location)
	for _, offset in pairs(mineOffsets) do
		local mineLocation = location + offset
		if not IsLocationPassable(mineLocation) then
			mineLocation = FindPassableLocationNear(mineLocation, searchMaxRadius, searchStep)
		end
		for _ = 0, 2 do
			if mineLocation then
				if not X.IsOtherMinesClose(mineLocation) then
					mineLocation = FindPassableLocationNear(mineLocation, searchMaxRadius, searchStep)
				end
				if Fu.GetLocationToLocationDistance(location, mineLocation) < X.nProximityMineDmgRadius then
					return BOT_ACTION_DESIRE_HIGH, mineLocation
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.IsOtherMinesClose(location)
	for _, unit in pairs(GetUnitList(UNIT_LIST_ALLIES)) do
		if X.IsMines(unit) and GetUnitToLocationDistance(unit, location) <= X.nMinMineDistance then
			return true
		end
	end
	return false
end
function X.GetClosestSpot(bot, spots)
	local closestDistance = 100000
	local closestSpot = nil
	for _, spot in pairs(spots) do
		local distance = GetUnitToLocationDistance(bot, spot)
		if distance < closestDistance then
			closestDistance = distance
			closestSpot = spot
		end
	end
	return closestSpot, closestDistance
end
function X.IsMines(unit)
	return unit:GetUnitName() == "npc_dota_techies_land_mine"
end
return X
