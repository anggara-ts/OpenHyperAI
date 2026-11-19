-- Watcher mode (#111). Replaces Valve's built-in watcher mode (BOT_MODE_WATCHER = 28): in the first 7.42 game
-- (game 049) it took Lich (0:05-0:40) and Ringmaster (0:37-1:07+) to a river spot at 0.48 and held them still.
-- Game files (7.42): a watcher is the neutral unit npc_dota_lantern; a hero turns it on with the hidden hero
-- ability ability_lamp_use (unit target, cast range 200, 1.0s channel); it stays on for 420s, then 120s off.
-- This mode only takes a watcher that is close, safe and not tried recently, and gives up instead of standing.
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local bot = GetBot()

local SEARCH_RANGE = 1200 -- only a watcher close to where the bot already is
local CAST_RANGE = 200 -- game files: ability_lamp_use AbilityCastRange
local ACTIVE_FOR = 420 -- game files: active_duration
local TRY_FOR = 12 -- seconds from the start of a try to the end of the channel
local SKIP_FOR = 120 -- a failed or given-up watcher is left alone this long
local DESIRE = 0.4

local lanterns = { at = -999, units = {} }
local target = nil
local tryStart = nil
local orderAt = nil
local closest = nil
local closestAt = nil
local channelSeen = false

local function Log(what, lantern, extra)
	if bot._watcherLogKey == what .. tostring(lantern) and DotaTime() < (bot._watcherLogAt or -999) then
		return
	end
	bot._watcherLogKey = what .. tostring(lantern)
	bot._watcherLogAt = DotaTime() + 5
	local loc = lantern ~= nil and not lantern:IsNull() and lantern:GetLocation() or nil
	pcall(
		print,
		string.format(
			"[OHA-WATCHER] t=%.0f %s %s at=%s dist=%s %s",
			DotaTime(),
			(string.gsub(bot:GetUnitName(), "npc_dota_hero_", "")),
			what,
			loc ~= nil and string.format("%d,%d", math.floor(loc.x), math.floor(loc.y)) or "-",
			loc ~= nil and tostring(math.floor(GetUnitToLocationDistance(bot, loc))) or "-",
			extra or ""
		)
	)
end

local function Key(lantern)
	local loc = lantern:GetLocation()
	return string.format("%d,%d", math.floor(loc.x / 100), math.floor(loc.y / 100))
end

local function Lanterns()
	if DotaTime() - lanterns.at < 5 and #lanterns.units > 0 then
		return lanterns.units
	end
	local found = {}
	for _, unit in pairs(GetUnitList(UNIT_LIST_ALL) or {}) do
		if unit ~= nil and not unit:IsNull() and unit:GetUnitName() == "npc_dota_lantern" then
			found[#found + 1] = unit
		end
	end
	lanterns.at = DotaTime()
	lanterns.units = found
	return found
end

local function Skip(lantern, seconds, why)
	bot._watcherSkip = bot._watcherSkip or {}
	bot._watcherSkip[Key(lantern)] = DotaTime() + seconds
	Log(why, lantern)
	target, tryStart, orderAt, closest, closestAt, channelSeen = nil, nil, nil, nil, nil, false
	bot._watcherSecondOrder = false
end

local function LampAbility()
	local lamp = bot:GetAbilityByName("ability_lamp_use")
	if lamp ~= nil and not lamp:IsNull() then
		return lamp
	end
	return nil
end

local function Usable(lantern)
	if lantern == nil or lantern:IsNull() or not lantern:IsAlive() then
		return false
	end
	local skipUntil = bot._watcherSkip and bot._watcherSkip[Key(lantern)] or nil
	if skipUntil ~= nil and DotaTime() < skipUntil then
		return false
	end
	local loc = lantern:GetLocation()
	return GetUnitToLocationDistance(bot, loc) <= SEARCH_RANGE and #Fu.GetEnemiesNearLoc(loc, 1200) == 0
end

local function Raw()
	if
		not bot:IsAlive()
		or bot:IsIllusion()
		or Fu.GetHP(bot) < 0.5
		or bot:WasRecentlyDamagedByAnyHero(3.0)
		or #Fu.GetEnemiesNearLoc(bot:GetLocation(), 1200) > 0
	then
		if target ~= nil then
			Skip(target, 30, "give-up why=danger")
		end
		return 0
	end
	local lamp = LampAbility()
	if lamp == nil then
		if not bot._watcherNoLampLogged then
			bot._watcherNoLampLogged = true
			Log("no-lamp-ability", nil)
		end
		return 0
	end
	-- Keep the current try until it ends or times out.
	if target ~= nil then
		if not Usable(target) then
			target, tryStart, orderAt, closest, closestAt, channelSeen = nil, nil, nil, nil, nil, false
		elseif DotaTime() - tryStart > TRY_FOR then
			Skip(target, SKIP_FOR, "give-up why=timeout")
			return 0
		else
			return DESIRE
		end
	end
	if not lamp:IsFullyCastable() then
		return 0
	end
	local best, bestDist = nil, math.huge
	for _, lantern in ipairs(Lanterns()) do
		if Usable(lantern) then
			local dist = GetUnitToUnitDistance(bot, lantern)
			if dist < bestDist then
				best, bestDist = lantern, dist
			end
		end
	end
	if best == nil then
		return 0
	end
	target, tryStart, orderAt, closest, closestAt, channelSeen = best, DotaTime(), nil, bestDist, DotaTime(), false
	bot._watcherSecondOrder = false
	Log("go", best, string.format("team=%d", best:GetTeam()))
	return DESIRE
end

function GetDesire()
	if ShouldSkipBotThink(bot) then
		return 0
	end
	return Raw()
end

function Think()
	if target == nil or target:IsNull() then
		return
	end
	local dist = GetUnitToUnitDistance(bot, target)
	-- Progress check: the walk must get closer every 3s, or the spot is unreachable from here.
	if dist < (closest or math.huge) - 50 then
		closest, closestAt = dist, DotaTime()
	elseif DotaTime() - (closestAt or DotaTime()) > 3 and dist > CAST_RANGE then
		Skip(target, SKIP_FOR, "give-up why=no-progress")
		return
	end
	local active = bot:IsChanneling() and bot:GetCurrentActiveAbility() or nil
	if active ~= nil and not active:IsNull() and active:GetName() == "ability_lamp_use" then
		channelSeen = true
		return
	end
	if channelSeen then
		-- The channel ended: done for this watcher until it can be turned on again.
		Skip(target, ACTIVE_FOR, "done")
		return
	end
	if dist > CAST_RANGE - 20 then
		bot:Action_MoveToLocation(target:GetLocation())
		return
	end
	local lamp = LampAbility()
	if lamp == nil or not lamp:IsFullyCastable() then
		Skip(target, SKIP_FOR, "give-up why=lamp-not-ready")
		return
	end
	-- One order, then wait for the channel; one more order after 2s, then give up after 4s.
	if orderAt ~= nil and DotaTime() - orderAt > 4 then
		Skip(target, SKIP_FOR, "give-up why=no-channel")
		return
	end
	if orderAt == nil or DotaTime() - orderAt > 2 and not bot._watcherSecondOrder then
		bot._watcherSecondOrder = orderAt ~= nil
		orderAt = orderAt or DotaTime()
		Log("cast", target, bot._watcherSecondOrder and "order=2" or "order=1")
		bot:Action_UseAbilityOnEntity(lamp, target)
	end
end

if SafeCall then
	GetDesire = SafeCall(GetDesire, 0, "WATCHER_GetDesire")
	Think = SafeCall(Think, nil, "WATCHER_Think")
end
-- [OHA-PERF] timing (#52): FuncLib/systems/perf.lua
do
	local Perf = require(GetScriptDirectory() .. "/FuncLib/systems/perf")
	GetDesire = Perf.Wrap("watcher.GetDesire", GetDesire)
	Think = Perf.Wrap("watcher.Think", Think)
end
