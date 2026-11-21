-- Lotus pool mode. Contests pools near the 3:00 marks (1:30 turbo) when a lotus grows.
if
	GetBot():IsInvulnerable()
	or not GetBot():IsHero()
	or not string.find(GetBot():GetUnitName(), "hero")
	or GetBot():IsIllusion()
then
	return
end

local bot = GetBot()
local Utils = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local MapObj = require(GetScriptDirectory() .. "/FuncLib/systems/map_objectives")
local MatchTrace = require(GetScriptDirectory() .. "/FuncLib/systems/match_trace")

local targetLoc = nil
local dbgAt = -100
local dbgWhy = ""
local dbgLoc = nil

local function ModeTag(mode)
	if mode == BOT_MODE_NONE then
		return "none"
	end
	if mode == BOT_MODE_LANING then
		return "laning"
	end
	if mode == BOT_MODE_ATTACK then
		return "attack"
	end
	if mode == BOT_MODE_ROAM then
		return "roam"
	end
	if mode == BOT_MODE_RETREAT then
		return "retreat"
	end
	if mode == BOT_MODE_FARM then
		return "farm"
	end
	if mode == BOT_MODE_WARD then
		return "ward"
	end
	if mode == BOT_MODE_RUNE then
		return "rune"
	end
	if mode == BOT_MODE_TEAM_ROAM then
		return "team_roam"
	end
	if BOT_MODE_LOTUS_POOL ~= nil and mode == BOT_MODE_LOTUS_POOL then
		return "lotus"
	end
	if BOT_MODE_WISDOM_SHRINE ~= nil and mode == BOT_MODE_WISDOM_SHRINE then
		return "wisdom"
	end
	if BOT_MODE_OUTPOST ~= nil and mode == BOT_MODE_OUTPOST then
		return "outpost"
	end
	return "m" .. tostring(mode)
end

local function Num(value, fmt)
	if type(value) ~= "number" then
		return "?"
	end
	return string.format(fmt, value)
end

local function FamangoCount()
	local total = 0
	for slot = 0, 8 do
		local item = bot:GetItemInSlot(slot)
		if item ~= nil and item.GetName ~= nil then
			local itemName = item:GetName()
			if itemName == "item_famango" or itemName == "item_great_famango" or itemName == "item_greater_famango" then
				local charges = item.GetCurrentCharges and item:GetCurrentCharges() or 1
				if type(charges) ~= "number" or charges < 1 then
					charges = 1
				end
				total = total + charges
			end
		end
	end
	return total
end

-- Grep [OHA-LOTUS]. One line a second during the spawn window, plus a line when the reason changes.
local function LotusDbg(desire, kind)
	local ok, err = pcall(function()
		local now = DotaTime()
		local interval = MapObj.LotusInterval()
		local toNext = MapObj.SecondsToNextMark(interval)
		local since = interval - toNext
		local window = toNext <= 40 or (now >= interval - 1 and since <= 50)
		local dist = bot._lotusDist
		if not window and (dist == nil or dist > 1600) then
			return
		end
		local why = bot._lotusWhy or "?"
		local pos = bot:GetLocation()
		local moved = -1
		if dbgLoc ~= nil then
			local dx = pos.x - dbgLoc.x
			local dy = pos.y - dbgLoc.y
			moved = math.sqrt(dx * dx + dy * dy)
		end
		local sinceLastLog = now - dbgAt
		if sinceLastLog < 0.25 or (why == dbgWhy and sinceLastLog < 1) then
			return
		end
		local stuck = (sinceLastLog >= 0.8 and type(dist) == "number" and dist <= 900 and moved >= 0 and moved < 40)
				and 1
			or 0
		dbgAt = now
		dbgWhy = why
		dbgLoc = pos
		local lotusInfo = bot._lotusDbg or {}
		local hero = string.gsub(bot:GetUnitName() or "?", "npc_dota_hero_", "")
		local team = GetTeam() == TEAM_RADIANT and "r" or "d"
		local role = Utils.GetPosition and Utils.GetPosition(bot) or "?"
		local mode = bot:GetActiveMode()
		local modeDesire = bot:GetActiveModeDesire() or 0
		local shown = (kind == "lotus" and desire) or 0
		print(
			string.format(
				"[OHA-LOTUS] %s/%s t=%.1f xy=%.0f,%.0f pos=%s mode=%s/%.2f des=%.2f obj=%s why=%s dist=%s eta=%s beside=%s lost=%s in=%s room=%s hp=%s walk=%s pools=%s count=%s skip=%s toNext=%.0f since=%.0f foes=%s/%s danger=%s mango=%d do=%s moved=%.0f stuck=%d",
				hero,
				team,
				now,
				pos.x,
				pos.y,
				tostring(role),
				ModeTag(mode),
				modeDesire,
				shown,
				tostring(kind or "none"),
				why,
				Num(lotusInfo.dist or dist, "%.0f"),
				Num(lotusInfo.eta, "%.0f"),
				tostring(lotusInfo.beside or 0),
				tostring(lotusInfo.lost or 0),
				tostring(lotusInfo.inwin or 0),
				tostring(lotusInfo.room or 0),
				Num(lotusInfo.hp, "%.2f"),
				Num(lotusInfo.walk, "%.0f"),
				tostring(lotusInfo.pools ~= nil and lotusInfo.pools or "?"),
				lotusInfo.count == nil and "?" or tostring(lotusInfo.count),
				Num(lotusInfo.skip, "%.0f"),
				toNext,
				since,
				tostring(lotusInfo.foes ~= nil and lotusInfo.foes or "?"),
				tostring(lotusInfo.friends ~= nil and lotusInfo.friends or "?"),
				tostring(lotusInfo.danger or 0),
				FamangoCount(),
				tostring(bot._lotusDo or "-"),
				moved,
				stuck
			)
		)
	end)
	if not ok then
		print("[OHA-LOTUS] err " .. tostring(err))
	end
end

function GetDesire()
	if ShouldSkipBotThink(GetBot()) then
		return 0
	end
	local desire, loc, kind, eta = MapObj.ConsiderObjectiveDesire(bot)
	LotusDbg(desire, kind)
	if kind ~= "lotus" or desire <= 0 or loc == nil then
		targetLoc = nil
		return BOT_MODE_DESIRE_NONE
	end
	targetLoc = loc
	MatchTrace.Decide(
		bot,
		"lotus",
		string.format("%d,%d", math.floor(loc.x), math.floor(loc.y)),
		string.format("eta=%.0f desire=%.2f", eta or 0, desire),
		8
	)
	return desire
end

function OnStart() end

function OnEnd()
	targetLoc = nil
end

function Think()
	if not bot:IsAlive() or Utils.CanNotUseAction and Utils.CanNotUseAction(bot) then
		return
	end
	local loc = targetLoc
	if loc == nil then
		local _, found = MapObj.ConsiderObjectiveDesire(bot)
		loc = found
	end
	MapObj.ThinkObjective(bot, loc, "lotus")
end

-- [OHA-ERROR] trap (lotus pool). From ~11:20 every game an unwrapped entry point fails and the engine only
-- prints "Script Runtime Error: error in error handling" (its handler cannot run, typically a stack
-- overflow), then squelches it after 10 copies. Caught here and printed with its name, up to 3 times
-- per entry point per bot; the failing call still just stops, as before.
local OHA_TRAP_COUNT = {}
local function OHA_Trap(name, fn, fallback)
	if type(fn) ~= "function" then
		return fn
	end
	return function(...)
		local results = { pcall(fn, ...) }
		if results[1] then
			return unpack(results, 2)
		end
		local errorCount = (OHA_TRAP_COUNT[name] or 0) + 1
		OHA_TRAP_COUNT[name] = errorCount
		if errorCount <= 3 then
			local hero = "?"
			pcall(function()
				hero = GetBot():GetUnitName()
			end)
			pcall(print, string.format("[OHA-ERROR] t=%.1f %s %s: %s", DotaTime(), hero, name, tostring(results[2])))
		end
		return fallback
	end
end
GetDesire = OHA_Trap("LOTUS_GetDesire", GetDesire, 0)
Think = OHA_Trap("LOTUS_Run", Think, nil)
-- [OHA-PERF] timing (#52): FuncLib/systems/perf.lua
do
	local Perf = require(GetScriptDirectory() .. "/FuncLib/systems/perf")
	GetDesire = Perf.Wrap("lotus_pool.GetDesire", GetDesire)
	Think = Perf.Wrap("lotus_pool.Think", Think)
end
-- [OHA-MTRACE] Meepo call trace (#139): FuncLib/systems/meepo_trace.lua. Off unless Customize.Debug_Meepo_Trace;
-- last, so it is the outermost wrapper and its lines bracket everything the engine calls.
do
	local MeepoTrace = require(GetScriptDirectory() .. "/FuncLib/systems/meepo_trace")
	GetDesire = MeepoTrace.Wrap("lotus_pool.GetDesire", GetDesire)
	Think = MeepoTrace.Wrap("lotus_pool.Think", Think)
	OnStart = MeepoTrace.Wrap("lotus_pool.OnStart", OnStart)
	OnEnd = MeepoTrace.Wrap("lotus_pool.OnEnd", OnEnd)
end
