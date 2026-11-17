-- Getting to a far objective (Roshan, Tormentor) faster than walking: a TP to our tower nearest
-- the target, or a Twin Gate. Used by the gather walks, and by the Roshan time estimate so a
-- call counts an ally across the map by how fast they can really get there.
--
-- TP scroll: 3s channel, 80s cooldown (Valve data). The Twin Gate warp channel and cooldown are
-- read from the ability (twin_gate_portal_warp) in game.
local ObjectiveTravel = {}

local TP_CHANNEL = 3
local MIN_SAVED = 8 -- seconds a TP or gate has to save over walking

local function Speed(unit)
	local ok, speed = pcall(function()
		return unit:GetCurrentMovementSpeed()
	end)
	return (ok and type(speed) == "number" and speed > 100) and speed or 300
end

local function Dist(locA, locB)
	local dx, dy = locA.x - locB.x, locA.y - locB.y
	return math.sqrt(dx * dx + dy * dy)
end

-- Our tower closest to loc (or the fountain area when loc is in our base).
local function TpSpot(loc)
	local best, bestD = nil, math.huge
	for id = 0, 10 do
		local tower = GetTower(GetTeam(), id)
		if tower ~= nil and tower:IsAlive() then
			local distance = GetUnitToLocationDistance(tower, loc)
			if distance < bestD then
				best, bestD = tower:GetLocation(), distance
			end
		end
	end
	return best, bestD
end

local function TpItem(unit)
	for _, slot in ipairs({ 15, 0, 1, 2, 3, 4, 5 }) do
		local ok, item = pcall(function()
			return unit:GetItemInSlot(slot)
		end)
		if ok and item ~= nil then
			local name = item:GetName()
			if name == "item_tpscroll" or name == "item_travel_boots" or name == "item_travel_boots_2" then
				if item:IsFullyCastable() then
					return item
				end
			end
		end
	end
	return nil
end

local gates = nil
local function Gates()
	if gates == nil or #gates < 2 then
		gates = {}
		for _, unit in pairs(GetUnitList(UNIT_LIST_ALL) or {}) do
			if unit ~= nil and unit:GetUnitName() == "npc_dota_unit_twin_gate" then
				gates[#gates + 1] = unit
			end
		end
	end
	return gates
end

local function GateWarp(unit)
	local ok, warpAbility = pcall(function()
		return unit:GetAbilityByName("twin_gate_portal_warp")
	end)
	if ok and warpAbility ~= nil and warpAbility:IsFullyCastable() then
		return warpAbility
	end
	return nil
end

-- Fastest way for unit to reach loc. Returns seconds, how ("walk" / "tp" / "gate"), and the
-- spot, item / gate to use.
function ObjectiveTravel.Best(unit, loc)
	local speed = Speed(unit)
	local here = unit:GetLocation()
	local walk = Dist(here, loc) / speed
	local best, how, extra, spot = walk, "walk", nil, nil
	local tp = TpItem(unit)
	if tp ~= nil then
		local towerLoc, towerToTarget = TpSpot(loc)
		if towerLoc ~= nil and Dist(here, towerLoc) > 2500 then
			local tpTime = TP_CHANNEL + 1 + towerToTarget / speed
			if tpTime + MIN_SAVED < best then
				best, how, extra, spot = tpTime, "tp", tp, towerLoc
			end
		end
	end
	local warp = GateWarp(unit)
	local list = Gates()
	if warp ~= nil and #list >= 2 then
		local near, far = list[1], list[2]
		if GetUnitToUnitDistance(unit, list[2]) < GetUnitToUnitDistance(unit, near) then
			near, far = list[2], list[1]
		end
		local channel = warp:GetChannelTime()
		if channel == nil or channel <= 0 then
			channel = 6
		end
		local gateTime = GetUnitToUnitDistance(unit, near) / speed + channel + 1 + GetUnitToLocationDistance(far, loc) / speed
		if gateTime + MIN_SAVED < best then
			best, how, extra, spot = gateTime, "gate", warp, near
		end
	end
	return best, how, extra, spot
end

-- Seconds for unit to reach loc the fastest way (for timing estimates).
function ObjectiveTravel.Eta(unit, loc)
	local ok, seconds = pcall(ObjectiveTravel.Best, unit, loc)
	if ok and type(seconds) == "number" then
		return seconds
	end
	return GetUnitToLocationDistance(unit, loc) / Speed(unit)
end

-- Issue a TP or gate order for bot toward loc when it is clearly faster than walking. Returns
-- true when it issued an order (or one is channeling), so the caller does not walk.
function ObjectiveTravel.Go(bot, loc, tag)
	if bot:IsChanneling() then
		return true
	end
	if bot:WasRecentlyDamagedByAnyHero(2) or bot:IsRooted() then
		return false
	end
	local ok, seconds, how, extra, spot = pcall(ObjectiveTravel.Best, bot, loc)
	if not ok or how == "walk" or extra == nil then
		return false
	end
	local function Log()
		if DotaTime() >= (bot._travelLogAt or -999) then
			bot._travelLogAt = DotaTime() + 5
			pcall(print, string.format(
				"[OHA-TRAVEL] t=%.0f %s %s for=%s eta=%.0f walk=%.0f",
				DotaTime(),
				(string.gsub(bot:GetUnitName(), "npc_dota_hero_", "")),
				how,
				tostring(tag),
				seconds,
				GetUnitToLocationDistance(bot, loc) / Speed(bot)
			))
		end
	end
	if how == "tp" then
		Log()
		bot:Action_UseAbilityOnLocation(extra, spot)
		return true
	end
	if how == "gate" then
		Log()
		if GetUnitToUnitDistance(bot, spot) > 350 then
			bot:Action_MoveToLocation(spot:GetLocation())
		else
			bot:Action_UseAbilityOnEntity(extra, spot)
		end
		return true
	end
	return false
end

return ObjectiveTravel
