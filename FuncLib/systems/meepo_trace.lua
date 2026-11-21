-- Shared bot system: [OHA-MTRACE] call trace for Meepo bodies (#139, diagnostic).
-- Since 7.42 every game with a bot Meepo froze (Windows "Application Hang") with no script error and normal Lua
-- memory; the console log just stops. With Customize.Debug_Meepo_Trace = true every entry point the engine calls
-- for a Meepo body (main and clones) prints a line before the call and one after it returns:
--   [OHA-MTRACE] <body> <fn> start t=<DotaTime> g=<GameTime>
--   [OHA-MTRACE] <body> <fn> end ms=<elapsed> act=<GetCurrentActionType> q=<NumQueuedActions>
--   [OHA-MTRACE] <body> <what> mark t=<DotaTime>         (a point inside a call, e.g. just before an order)
-- Read the tail after a freeze: grep -a "OHA-MTRACE" <log> | tail -200. A `start` with no `end` for that body
-- names the call that hung (the last `mark` before it says where); only `end`s at the tail means the engine hung
-- between our calls. <body> is `main` or `clone<N>` (N in the order the clones were first seen, stable for the game).
-- Off (the default): Wrap returns the function itself and Mark is never called, so nothing changes and nothing runs.
-- On: every call prints two lines (thousands of lines per second with several bodies); only for a test game.
local MeepoTrace = {}

local MEEPO = "npc_dota_hero_meepo"

-- Read once, the way match_trace.lua reads its switches: only an explicit true turns it on.
local enabled = false
do
	local settingsOk, settings = pcall(require, GetScriptDirectory() .. "/FuncLib/systems/custom_loader")
	if settingsOk and type(settings) == "table" and settings.Debug_Meepo_Trace == true then
		enabled = true
	end
end

-- Clone numbers, in the order the clones are first seen. FuncLib modules are shared by the bots of a team, so the
-- count is shared by every body of the team's Meepo.
local cloneCount = 0

-- The plain print: global_overrides.lua replaces print with one that scans OHA_MUTED on every [OHA- line; the raw
-- one skips that scan and cannot be muted. Looked up per call (the override may load after this module).
local function Out(line)
	local out = _G.OHA_RAW_PRINT or print
	pcall(out, line)
end

-- main = one of the team's five members, a clone = any other Meepo body. Worked out at the first call, not at
-- load: the team slots may not be filled yet when a file loads.
local function BodyTag(bot)
	local tag = bot._mtraceTag
	if tag ~= nil then
		return tag
	end
	for i = 1, 5 do
		local member = GetTeamMember(i)
		if member ~= nil and member == bot then
			tag = "main"
			break
		end
	end
	if tag == nil then
		cloneCount = cloneCount + 1
		tag = "clone" .. cloneCount
	end
	bot._mtraceTag = tag
	return tag
end

local function IsMeepo(bot)
	if bot == nil then
		return false
	end
	local ok, name = pcall(bot.GetUnitName, bot)
	return ok and name == MEEPO
end

function MeepoTrace.IsOn()
	return enabled and IsMeepo(GetBot())
end

-- Tests only: turns the switch on or off for the next Wrap.
function MeepoTrace.SetEnabled(on)
	enabled = on == true
end

local function Ask(bot, method)
	local ok, value = pcall(bot[method], bot)
	if ok and value ~= nil then
		return tostring(value)
	end
	return "?"
end

local function Done(tag, name, bot, startedAt, ok, ...)
	local ms = RealTime ~= nil and (RealTime() - startedAt) * 1000 or -1
	if ok then
		Out(
			string.format(
				"[OHA-MTRACE] %s %s end ms=%.2f act=%s q=%s",
				tag,
				name,
				ms,
				Ask(bot, "GetCurrentActionType"),
				Ask(bot, "NumQueuedActions")
			)
		)
		return ...
	end
	local err = ...
	Out(string.format("[OHA-MTRACE] %s %s end ms=%.2f err=%s", tag, name, ms, tostring(err)))
	error(err, 0)
end

-- fn wrapped with the trace when the switch is on and the running bot is a Meepo body; otherwise fn itself (a nil
-- entry point stays nil: defining one would replace Valve's).
function MeepoTrace.Wrap(name, fn)
	if type(fn) ~= "function" or not enabled or not IsMeepo(GetBot()) then
		return fn
	end
	return function(...)
		local bot = GetBot()
		local tag = BodyTag(bot)
		Out(string.format("[OHA-MTRACE] %s %s start t=%.2f g=%.2f", tag, name, DotaTime(), GameTime()))
		return Done(tag, name, bot, RealTime ~= nil and RealTime() or 0, pcall(fn, ...))
	end
end

-- A point inside a traced call (e.g. just before an order). Callers check IsOn() first.
function MeepoTrace.Mark(what)
	local bot = GetBot()
	if bot == nil then
		return
	end
	Out(string.format("[OHA-MTRACE] %s %s mark t=%.2f", BodyTag(bot), what, DotaTime()))
end

return MeepoTrace
