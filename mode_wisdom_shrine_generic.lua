-- Wisdom shrine mode. Takes the XP shrine near the 7:00 marks (3:30 turbo) when active.
if
	GetBot():IsInvulnerable()
	or not GetBot():IsHero()
	or not string.find(GetBot():GetUnitName(), "hero")
	or GetBot():IsIllusion()
then
	return
end

local bot = GetBot()
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local MapObj = require(GetScriptDirectory() .. "/FuncLib/systems/map_objectives")
local MatchTrace = require(GetScriptDirectory() .. "/FuncLib/systems/match_trace")

local targetLoc = nil

function GetDesire()
	if ShouldSkipBotThink(GetBot()) then
		return 0
	end
	local desire, loc, kind, eta = MapObj.ConsiderObjectiveDesire(bot)
	if kind ~= "wisdom" or desire <= 0 or loc == nil then
		targetLoc = nil
		return BOT_MODE_DESIRE_NONE
	end
	targetLoc = loc
	MatchTrace.Decide(
		bot,
		"wisdom",
		string.format("%d,%d", math.floor(loc.x), math.floor(loc.y)),
		string.format("eta=%.0f desire=%.2f lvl=%d", eta or 0, desire, bot:GetLevel()),
		8
	)
	return desire
end

function OnStart() end

function OnEnd()
	targetLoc = nil
end

function Think()
	if not bot:IsAlive() or Fu.CanNotUseAction and Fu.CanNotUseAction(bot) then
		return
	end
	local loc = targetLoc
	if loc == nil then
		local _, found = MapObj.ConsiderObjectiveDesire(bot)
		loc = found
	end
	MapObj.ThinkObjective(bot, loc, "wisdom")
end

-- [OHA-ERROR] trap (wisdom shrine). From ~11:20 every game an unwrapped entry point fails and the engine only
-- prints "Script Runtime Error: error in error handling" (its handler cannot run, typically a stack
-- overflow), then squelches it after 10 copies. Caught here and printed with its name, up to 3 times
-- per entry point per bot; the failing call still just stops, as before.
local OHA_TRAP_COUNT = {}
local function OHA_Trap(name, fn, fallback)
	if type(fn) ~= "function" then
		return fn
	end
	return function(...)
		local res = { pcall(fn, ...) }
		if res[1] then
			return unpack(res, 2)
		end
		local errorCount = (OHA_TRAP_COUNT[name] or 0) + 1
		OHA_TRAP_COUNT[name] = errorCount
		if errorCount <= 3 then
			local hero = "?"
			pcall(function()
				hero = GetBot():GetUnitName()
			end)
			pcall(print, string.format("[OHA-ERROR] t=%.1f %s %s: %s", DotaTime(), hero, name, tostring(res[2])))
		end
		return fallback
	end
end
GetDesire = OHA_Trap("WISDOM_GetDesire", GetDesire, 0)
Think = OHA_Trap("WISDOM_Run", Think, nil)
-- [OHA-PERF] timing (#52): FuncLib/systems/perf.lua
do
	local Perf = require(GetScriptDirectory() .. "/FuncLib/systems/perf")
	GetDesire = Perf.Wrap("wisdom_shrine.GetDesire", GetDesire)
	Think = Perf.Wrap("wisdom_shrine.Think", Think)
end
