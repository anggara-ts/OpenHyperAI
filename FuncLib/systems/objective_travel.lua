-- Getting to a far objective (Roshan, Tormentor) faster than walking: a TP to our tower nearest
-- the target, or a Twin Gate. Used by the gather walks, and by the Roshan time estimate so a
-- call counts an ally across the map by how fast they can really get there.
--
-- TP scroll: 3s channel, 80s cooldown (Valve data).
-- Twin Gate warp, 7.42 game data (pak01_dir.vpk scripts/npc/npc_abilities.txt, "twin_gate_portal_warp"):
-- cast on the gate unit, AbilityCastRange 200, AbilityChannelTime 4.0, AbilityManaCost 30, a root
-- interrupts it (DOTA_ABILITY_BEHAVIOR_ROOT_DISABLES). The channel time is read from the ability when the
-- hero has it.
--
-- 7.42 (issue #53): heroes no longer carry twin_gate_portal_warp or abyssal_underlord_portal_warp. The
-- [OHA-API] abilities dump of games 049-062 (slots 0-35) lists no system ability at all; before 7.42 the
-- engine's own ability list (game 043, Rubick) had ability_capture, abyssal_underlord_portal_warp,
-- twin_gate_portal_warp and ability_lamp_use in slots 23-26. That is the change that broke outpost capture
-- (#111, ValveSoftware/Dota2-Gameplay#32850). Without the ability the gate is never part of the plan
-- (Best / Eta); GateProbe tries the other orders on a gate once per game to find out whether any of them
-- warps a bot.
local ObjectiveTravel = {}

local TP_CHANNEL = 3
local MIN_SAVED = 8 -- seconds a TP or gate has to save over walking
local GATE_CHANNEL = 4 -- twin_gate_portal_warp AbilityChannelTime (7.42 game data, above)
local GATE_RANGE = 200 -- twin_gate_portal_warp AbilityCastRange
local PROBE_ORDERS = { "move-to-unit", "use-shrine", "attack" }
local PROBE_STEP = 5 -- seconds per order: a 4s channel started by one order ends inside its step
local PROBE_MAX_TRIES = 3 -- interrupted tries (enemies, damage, the trip ended) per game
local PROBE_ARRIVED = 1500 -- this close to the far gate after a try: the warp worked

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

local function HeroName(unit)
	return (string.gsub(unit:GetUnitName(), "npc_dota_hero_", ""))
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

-- The gate nearer to unit, and the other one.
local function NearFar(unit, list)
	local near, far = list[1], list[2]
	if GetUnitToUnitDistance(unit, list[2]) < GetUnitToUnitDistance(unit, near) then
		near, far = list[2], list[1]
	end
	return near, far
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

-- Seconds for the gate route: walk to the near gate, channel, 1s spare, walk from the far gate.
function ObjectiveTravel.GateSeconds(toNearGate, farGateToTarget, speed, channel)
	if channel == nil or channel <= 0 then
		channel = GATE_CHANNEL
	end
	return toNearGate / speed + channel + 1 + farGateToTarget / speed
end

-- Whether a Fiend's Gate does anything for this team: someone must be able to walk through it (the
-- warp ability, or a human player), or the Scepter puts a Pit of Malice at the far portal.
function ObjectiveTravel.PortalWorthCasting(hasWarpAbility, humanPlayers, hasScepter)
	return hasWarpAbility or (humanPlayers or 0) > 0 or hasScepter == true
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
		local near, far = NearFar(unit, list)
		local gateTime = ObjectiveTravel.GateSeconds(
			GetUnitToUnitDistance(unit, near),
			GetUnitToLocationDistance(far, loc),
			speed,
			warp:GetChannelTime()
		)
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

-- Once per bot: does the engine give this hero the warp abilities (gone in 7.42)?
local function LogWarpAbilities(bot)
	if bot._travelWarpLogged then
		return
	end
	bot._travelWarpLogged = true
	local twin = bot:GetAbilityByName("twin_gate_portal_warp")
	local portal = bot:GetAbilityByName("abyssal_underlord_portal_warp")
	pcall(
		print,
		string.format(
			"[OHA-TRAVEL] t=%.0f %s warp-abilities twin=%s portal=%s",
			DotaTime(),
			HeroName(bot),
			tostring(twin ~= nil),
			tostring(portal ~= nil)
		)
	)
end

-- Gate probe (#53): one bot per game walks to a Twin Gate on a far trip and tries the orders the API
-- still has on the gate unit, PROBE_STEP seconds each, without the warp ability. One log per order and
-- one for the result. A finished try (arrived / failed) ends the probe for the game.
local probe = { tries = 0, done = false }

local function ModifierNames(bot)
	local names = {}
	pcall(function()
		for index = 0, bot:NumModifiers() - 1 do
			names[#names + 1] = tostring(bot:GetModifierName(index))
		end
	end)
	return #names > 0 and table.concat(names, ",") or "-"
end

local function ProbeEnd(result, why)
	local bot = probe.owner
	local arrived = result == "arrived"
	pcall(
		print,
		string.format(
			"[OHA-TRAVEL] t=%.0f %s gate-try result=%s arrived=%s why=%s order=%s channel=%s try=%d for=%s",
			DotaTime(),
			bot ~= nil and HeroName(bot) or "-",
			result,
			tostring(arrived),
			why,
			probe.order or "-",
			tostring(probe.channelSeen == true),
			probe.tries + 1,
			tostring(probe.tag)
		)
	)
	probe.tries = probe.tries + 1
	if result ~= "aborted" or probe.tries >= PROBE_MAX_TRIES then
		probe.done = true
	end
	probe.owner, probe.near, probe.far, probe.order, probe.step, probe.orderStart = nil, nil, nil, nil, nil, nil
	probe.channelSeen = false
end

local function ProbeArrived(bot)
	return probe.far ~= nil and GetUnitToUnitDistance(bot, probe.far) < PROBE_ARRIVED
end

local function ProbeOrder(bot, order, gate)
	if order == "move-to-unit" then
		return pcall(bot.Action_MoveToUnit, bot, gate)
	elseif order == "use-shrine" then
		return pcall(bot.Action_UseShrine, bot, gate)
	end
	return pcall(bot.Action_AttackUnit, bot, gate, true)
end

-- Returns true while the probe drives this bot (the caller does not move it).
function ObjectiveTravel.GateProbe(bot, loc, tag, walkSeconds)
	if probe.done then
		return false
	end
	local now = DotaTime()
	-- The bot running the probe stopped asking (its trip ended or the mode changed).
	if probe.owner ~= nil and probe.owner ~= bot and now - (probe.seenAt or -999) >= 3 then
		if ProbeArrived(probe.owner) then
			ProbeEnd("arrived", "seen-late")
		else
			ProbeEnd("aborted", "trip-ended")
		end
		if probe.done then
			return false
		end
	end
	if probe.owner ~= nil and probe.owner ~= bot then
		return false
	end
	local enemies = bot:GetNearbyHeroes(1200, true, BOT_MODE_NONE) or {}
	local threatened = #enemies > 0 or bot:WasRecentlyDamagedByAnyHero(2) or bot:IsRooted()
	if probe.owner == nil then
		local list = Gates()
		if threatened or GateWarp(bot) ~= nil or #list < 2 then
			return false
		end
		local near, far = NearFar(bot, list)
		local gateTime = ObjectiveTravel.GateSeconds(
			GetUnitToUnitDistance(bot, near),
			GetUnitToLocationDistance(far, loc),
			Speed(bot)
		)
		if gateTime + MIN_SAVED >= walkSeconds then
			return false
		end
		probe.owner, probe.near, probe.far, probe.tag, probe.startAt = bot, near, far, tag, now
		probe.channelSeen = false
	end
	probe.seenAt = now
	if ProbeArrived(bot) then
		ProbeEnd("arrived", "far-gate")
		return false
	end
	if bot:IsChanneling() then
		probe.channelSeen = true
		return true
	end
	if threatened then
		ProbeEnd("aborted", #enemies > 0 and "enemies" or "hit-or-rooted")
		return false
	end
	if GetUnitToUnitDistance(bot, probe.near) > GATE_RANGE + 100 then
		if probe.orderStart ~= nil or now - probe.startAt > 90 then
			ProbeEnd("aborted", probe.orderStart ~= nil and "pushed-off" or "walk-timeout")
			return false
		end
		bot:Action_MoveToLocation(probe.near:GetLocation())
		return true
	end
	probe.orderStart = probe.orderStart or now
	local step = math.floor((now - probe.orderStart) / PROBE_STEP) + 1
	if step > #PROBE_ORDERS then
		ProbeEnd("failed", "no-warp")
		return false
	end
	if probe.step ~= step then
		probe.step = step
		probe.order = PROBE_ORDERS[step]
		local ok, err = ProbeOrder(bot, probe.order, probe.near)
		pcall(
			print,
			string.format(
				"[OHA-TRAVEL] t=%.0f %s gate-try order=%s ok=%s err=%s dist=%.0f far=%.0f mods=%s",
				DotaTime(),
				HeroName(bot),
				probe.order,
				tostring(ok),
				ok and "-" or string.gsub(tostring(err), "%s+", "_"),
				GetUnitToUnitDistance(bot, probe.near),
				GetUnitToUnitDistance(bot, probe.far),
				ModifierNames(bot)
			)
		)
	end
	return true
end

-- Issue a TP or gate order for bot toward loc when it is clearly faster than walking. Returns
-- true when it issued an order (or one is channeling), so the caller does not walk.
function ObjectiveTravel.Go(bot, loc, tag)
	LogWarpAbilities(bot)
	if bot:IsChanneling() then
		if probe.owner == bot then
			probe.channelSeen = true
			probe.seenAt = DotaTime()
		end
		return true
	end
	local ok, seconds, how, extra, spot = pcall(ObjectiveTravel.Best, bot, loc)
	if ok and how == "walk" then
		local probeOk, driving = pcall(ObjectiveTravel.GateProbe, bot, loc, tag, seconds)
		return probeOk and driving == true
	end
	if bot:WasRecentlyDamagedByAnyHero(2) or bot:IsRooted() then
		return false
	end
	if not ok or how == "walk" or extra == nil then
		return false
	end
	local function Log()
		if DotaTime() >= (bot._travelLogAt or -999) then
			bot._travelLogAt = DotaTime() + 5
			pcall(
				print,
				string.format(
					"[OHA-TRAVEL] t=%.0f %s %s for=%s eta=%.0f walk=%.0f",
					DotaTime(),
					HeroName(bot),
					how,
					tostring(tag),
					seconds,
					GetUnitToLocationDistance(bot, loc) / Speed(bot)
				)
			)
		end
	end
	if how == "tp" then
		Log()
		bot:Action_UseAbilityOnLocation(extra, spot)
		return true
	end
	if how == "gate" then
		Log()
		if GetUnitToUnitDistance(bot, spot) > GATE_RANGE + 150 then
			bot:Action_MoveToLocation(spot:GetLocation())
		else
			bot:Action_UseAbilityOnEntity(extra, spot)
		end
		return true
	end
	return false
end

return ObjectiveTravel
