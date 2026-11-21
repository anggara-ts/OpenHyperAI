-- Shared bot system: [OHA-PERF] timing of our engine entry points (#52).
-- Game 040, 29:33-30:30: the server tick took 115-145ms (~8 FPS) for 30s during and after a big fight, but the
-- engine only prints "Script function ... took Nms" above its own threshold, so small calls that add up were
-- invisible. Perf.Wrap times a function with RealTime(); every 10s, a bot whose total is over the budget prints
-- its total and top 3 functions. Quiet in normal play.
--
-- Games 048-050 (#52): the cost does not follow fights (per minute, over-budget time against deaths: r=-0.10,
-- -0.34, -0.06). In 048 and 050 it grows with game time (r=0.77 and 0.73); 049 was high from the start (47 ms/s at
-- t=400) and flat. ItemUsageThink is on top of every line, about a quarter of it in no part, and the over-budget
-- count swings 7x between two games with the same ten heroes (1971 in 049, 283 in 050), because it only counts
-- windows above the budget. So the lines also carry:
--   top=<fn>=<ms>/<calls>  the call count, to tell many cheap calls from a few dear ones;
--   parts=...,unsplit=<ms> ItemUsageThink's time outside its timed parts;
--   detail=<name>=<ms>     time inside named helpers (each item's use rule, the gates before the item loop);
--   slow=<n> slowTop=      calls of 2ms or more, by function. The engine's warning says only "GetDesire";
--   slowGc=<n> gc=<n>      how many of those slow calls / of all calls ended with less Lua memory than they
--                          started with (a garbage-collection sweep ran inside the call);
--   peak=<fn>=<ms>         the longest single call;
--   kb/s=                  Lua memory allocated by this bot's calls per game second (lower bound).
-- and [OHA-PERFSUM] prints the same for every bot every 5 minutes, over budget or not: the sum of those lines is
-- the whole game's script time, comparable between builds.
local Perf = {}
local WINDOW = 10 -- seconds of game time per report
local BUDGET = 0.020 -- seconds of our code per second of game time, per bot, before it prints
local SUM_WINDOW = 300 -- seconds of game time per [OHA-PERFSUM] line
-- The engine's "Script function '<name>' on bot <hero> took N ms" warnings start at 2.0ms (smallest values in the
-- console logs of games 048, 049 and 050: 2.001, 2.000, 2.001).
local SLOW_CALL = 0.002
local SHORT_LIMITS = { top = 3, parts = 5, detail = 6, slow = 3 }
-- The console cuts a line at about 1024 characters (longest script lines in game 050: 1050 with the time stamp).
local SUM_LIMITS = { top = 6, parts = 5, detail = 10, slow = 4 }

-- collectgarbage("count") is in the game's Lua (Docs/BOT_API_RUNTIME.md lists the global); checked once.
local memoryKb = nil
do
	local ok, kb = pcall(function()
		return collectgarbage("count")
	end)
	if ok and type(kb) == "number" then
		memoryKb = function()
			return collectgarbage("count")
		end
	end
end

local function NewWindow(now)
	return {
		since = now,
		total = 0,
		calls = 0,
		sum = {},
		count = {},
		slow = {},
		slowCalls = 0,
		slowGc = 0,
		gcCalls = 0,
		allocKb = 0,
		peak = 0,
	}
end

local function AddInto(target, source)
	for key, value in pairs(source or {}) do
		target[key] = (target[key] or 0) + value
	end
	return target
end

-- Adds a finished 10s window to the bot's 5-minute sum.
local function Merge(long, perf)
	long.total = long.total + perf.total
	long.calls = long.calls + perf.calls
	long.slowCalls = long.slowCalls + (perf.slowCalls or 0)
	long.slowGc = long.slowGc + (perf.slowGc or 0)
	long.gcCalls = long.gcCalls + (perf.gcCalls or 0)
	long.allocKb = long.allocKb + (perf.allocKb or 0)
	AddInto(long.sum, perf.sum)
	AddInto(long.count, perf.count)
	AddInto(long.slow, perf.slow)
	if perf.parts ~= nil then
		long.parts = AddInto(long.parts or {}, perf.parts)
	end
	if perf.detail ~= nil then
		long.detail = AddInto(long.detail or {}, perf.detail)
	end
	if (perf.peak or 0) > long.peak then
		long.peak = perf.peak
		long.peakName = perf.peakName
	end
end

local function Sorted(map)
	local list = {}
	for key, value in pairs(map or {}) do
		list[#list + 1] = { key, value }
	end
	table.sort(list, function(a, b)
		return a[2] > b[2]
	end)
	return list
end

-- "name=12ms,other=3ms" for the biggest `limit` entries of a seconds map, "-" when empty.
local function TopMs(map, limit)
	local list = Sorted(map)
	local out = {}
	for i = 1, math.min(limit, #list) do
		out[#out + 1] = string.format("%s=%.0fms", list[i][1], list[i][2] * 1000)
	end
	return #out > 0 and table.concat(out, ",") or "-"
end

-- One report line. Pure: tests read it.
function Perf.Format(tag, now, heroName, why, perf, span, limits)
	span = math.max(span, 0.001)
	local names = Sorted(perf.sum)
	local top = {}
	for i = 1, math.min(limits.top, #names) do
		local name = names[i][1]
		top[#top + 1] = string.format("%s=%.0fms/%d", name, names[i][2] * 1000, perf.count and perf.count[name] or 0)
	end
	-- Every part is a stretch of ItemUsageThink, so what is left of it is the code between the parts.
	local parts = nil
	if perf.parts ~= nil then
		parts = {}
		local split = 0
		for key, value in pairs(perf.parts) do
			parts[key] = value
			split = split + value
		end
		if perf.sum.ItemUsageThink ~= nil then
			parts.unsplit = math.max(0, perf.sum.ItemUsageThink - split)
		end
	end
	local slowList = Sorted(perf.slow)
	local slowTop = {}
	for i = 1, math.min(limits.slow, #slowList) do
		slowTop[#slowTop + 1] = string.format("%s=%d", slowList[i][1], slowList[i][2])
	end
	return string.format(
		"[%s] t=%.0f %s why=%s ms/s=%.1f calls=%d window=%.0fs top=%s parts=%s detail=%s slow=%d slowGc=%d slowTop=%s"
			.. " peak=%s=%.1fms kb/s=%.0f gc=%d",
		tag,
		now,
		heroName,
		why,
		perf.total / span * 1000,
		perf.calls,
		span,
		#top > 0 and table.concat(top, ",") or "-",
		TopMs(parts, limits.parts),
		TopMs(perf.detail, limits.detail),
		perf.slowCalls or 0,
		perf.slowGc or 0,
		#slowTop > 0 and table.concat(slowTop, ",") or "-",
		perf.peakName or "-",
		(perf.peak or 0) * 1000,
		(perf.allocKb or 0) / span,
		perf.gcCalls or 0
	)
end

-- [OHA-MEM] once per game minute (maintainer, 2026-11-20: two games froze with Dota at 8.2 GB; is it our scripts?).
-- collectgarbage("count") is the memory of the Lua state this code runs in, shared by the bots that run in it, so
-- the line is per state, not per bot: kb= now, peak= the highest seen, grew= the change since the last line, start=
-- the first reading. A leak shows as kb= climbing line after line; a flat kb= puts the memory in the game client.
local MEMORY_WINDOW = 60
local memoryNextAt = nil
local memoryStart, memoryLast, memoryPeak = nil, nil, 0
function Perf.FormatMemory(now, heroName, kb, last, peak, start)
	return string.format(
		"[OHA-MEM] t=%.0f %s kb=%.0f peak=%.0f grew=%.0f start=%.0f",
		now,
		heroName,
		kb,
		peak,
		last ~= nil and kb - last or 0,
		start or kb
	)
end
local function TrackMemory(bot, now)
	if memoryKb == nil or (memoryNextAt ~= nil and now < memoryNextAt) then
		return
	end
	memoryNextAt = now + MEMORY_WINDOW
	local kb = memoryKb()
	memoryStart = memoryStart or kb
	memoryPeak = math.max(memoryPeak, kb)
	local heroName = string.gsub(bot:GetUnitName(), "npc_dota_hero_", "")
	pcall(print, Perf.FormatMemory(now, heroName, kb, memoryLast, memoryPeak, memoryStart))
	memoryLast = kb
end

local function Record(name, seconds, kbDelta)
	local bot = GetBot()
	if bot == nil then
		return
	end
	local perf = bot._perf
	local now = DotaTime()
	TrackMemory(bot, now)
	if perf == nil then
		perf = NewWindow(now)
		bot._perf = perf
	end
	perf.total = perf.total + seconds
	perf.calls = perf.calls + 1
	perf.sum[name] = (perf.sum[name] or 0) + seconds
	perf.count[name] = (perf.count[name] or 0) + 1
	if seconds > perf.peak then
		perf.peak = seconds
		perf.peakName = name
	end
	-- Memory can only be read before and after: a call that ends lower had a collection sweep inside it (what it
	-- allocated itself is then unknown, so kb/s is a lower bound).
	local swept = kbDelta ~= nil and kbDelta < 0
	if swept then
		perf.gcCalls = perf.gcCalls + 1
	elseif kbDelta ~= nil then
		perf.allocKb = perf.allocKb + kbDelta
	end
	if seconds >= SLOW_CALL then
		perf.slowCalls = perf.slowCalls + 1
		perf.slow[name] = (perf.slow[name] or 0) + 1
		if swept then
			perf.slowGc = perf.slowGc + 1
		end
	end
	local span = now - perf.since
	if span < WINDOW then
		return
	end
	local heroName = string.gsub(bot:GetUnitName(), "npc_dota_hero_", "")
	-- The first window of each bot always prints (why=baseline), so a quiet log means "under budget" and not "the
	-- clock did not advance".
	local baseline = not bot._perfBaselineDone
	bot._perfBaselineDone = true
	if baseline or perf.total / span > BUDGET then
		pcall(
			print,
			Perf.Format("OHA-PERF", now, heroName, baseline and "baseline" or "over-budget", perf, span, SHORT_LIMITS)
		)
	end
	-- Every window goes into the 5-minute sum, printed over budget or not.
	local long = bot._perfSum
	if long == nil then
		long = NewWindow(perf.since)
		bot._perfSum = long
	end
	Merge(long, perf)
	if now - long.since >= SUM_WINDOW then
		pcall(print, Perf.Format("OHA-PERFSUM", now, heroName, "total", long, now - long.since, SUM_LIMITS))
		bot._perfSum = NewWindow(now)
	end
	bot._perf = NewWindow(now)
end

-- A helper timed by Perf.WrapDetail is running: helpers it calls are part of it, not timed again (an alias rule
-- such as item_bfury calls item_quelling_blade's rule through the same table).
local detailRunning = false

local function Finish(name, startedAt, kbBefore, ...)
	local seconds = RealTime() - startedAt
	Record(name, seconds, kbBefore ~= nil and (memoryKb() - kbBefore) or nil)
	return ...
end

-- Time spent in one part of a wrapped function (e.g. ItemUsageThink's item checks vs the hero's ability code).
-- Kept apart from the totals, which already include it; the report lists the top parts (#52, game 043: every
-- over-budget line had ItemUsageThink on top, and it runs both the items and the hero's SkillsComplement).
function Perf.Part(name, seconds)
	local bot = GetBot()
	if bot == nil or bot._perf == nil or seconds == nil then
		return
	end
	bot._perf.parts = bot._perf.parts or {}
	bot._perf.parts[name] = (bot._perf.parts[name] or 0) + seconds
end

-- Time spent inside one named helper, wherever it is called from. Like the parts, apart from the totals.
function Perf.Detail(name, seconds)
	local bot = GetBot()
	if bot == nil or bot._perf == nil or seconds == nil then
		return
	end
	bot._perf.detail = bot._perf.detail or {}
	bot._perf.detail[name] = (bot._perf.detail[name] or 0) + seconds
end

-- The helper runs under pcall so that one that raises an error is still timed and clears the flag (the item think
-- calls its gates under pcall: a gate failing on every think would otherwise leave every later helper untimed).
-- The error is raised again unchanged for the caller.
local function FinishDetail(name, startedAt, ok, ...)
	detailRunning = false
	Perf.Detail(name, RealTime() - startedAt)
	if not ok then
		error((...), 0)
	end
	return ...
end

-- Returns fn wrapped so its time shows under detail= (fn unchanged when nil or when RealTime is missing).
function Perf.WrapDetail(name, fn)
	if type(fn) ~= "function" or RealTime == nil then
		return fn
	end
	return function(...)
		if detailRunning then
			return fn(...)
		end
		detailRunning = true
		return FinishDetail(name, RealTime(), pcall(fn, ...))
	end
end

-- Replaces owner[key] with its Perf.WrapDetail version, once per table: FuncLib modules are shared by every bot
-- of a team, and the file that asks for the wrap runs once per bot.
local wrappedIn = setmetatable({}, { __mode = "k" })
function Perf.WrapDetailIn(owner, key, name)
	if type(owner) ~= "table" or type(owner[key]) ~= "function" then
		return
	end
	local done = wrappedIn[owner]
	if done == nil then
		done = {}
		wrappedIn[owner] = done
	end
	if done[key] then
		return
	end
	done[key] = true
	owner[key] = Perf.WrapDetail(name or key, owner[key])
end

-- Returns fn wrapped with timing (fn unchanged when nil or when RealTime is missing).
function Perf.Wrap(name, fn)
	if type(fn) ~= "function" or RealTime == nil then
		return fn
	end
	return function(...)
		return Finish(name, RealTime(), memoryKb ~= nil and memoryKb() or nil, fn(...))
	end
end

return Perf
