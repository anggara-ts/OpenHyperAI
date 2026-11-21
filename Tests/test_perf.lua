-- FuncLib/systems/perf.lua: the [OHA-PERF] timing wrapper must not change what it wraps.
local T = ...

local function perf()
	T.stub.reset({ hero = "npc_dota_hero_lich" })
	return require(GetScriptDirectory() .. "/FuncLib/systems/perf")
end

T.test("Perf.Wrap passes arguments and every return value through", function()
	local Perf = perf()
	local wrapped = Perf.Wrap("test.fn", function(a, b)
		return a + b, "second", nil, "fourth"
	end)
	local one, two, three, four = wrapped(2, 3)
	T.eq(one, 5, "first return")
	T.eq(two, "second", "second return")
	T.eq(three, nil, "nil in the middle")
	T.eq(four, "fourth", "value after a nil")
end)

T.test("Perf.Wrap leaves a missing entry point missing", function()
	local Perf = perf()
	-- Retreat and attack have no Think of their own: wrapping must not create one (Valve's would be replaced).
	T.eq(Perf.Wrap("retreat.Think", nil), nil, "nil stays nil")
end)

T.test("Perf.Part adds to a part without touching the totals", function()
	local Perf = perf()
	local bot = GetBot()
	bot._perf = { since = DotaTime(), total = 0.5, sum = {}, calls = 3 }
	Perf.Part("items", 0.01)
	Perf.Part("items", 0.02)
	Perf.Part("hero-abilities", 0.04)
	T.near(bot._perf.parts.items, 0.03, 1e-9, "items summed")
	T.near(bot._perf.parts["hero-abilities"], 0.04, 1e-9, "hero part")
	T.eq(bot._perf.total, 0.5, "total unchanged")
	T.eq(bot._perf.calls, 3, "calls unchanged")
end)

T.test("Perf.Part before the first timed call does nothing", function()
	local Perf = perf()
	local bot = GetBot()
	bot._perf = nil
	Perf.Part("items", 0.01)
	T.eq(bot._perf, nil, "no window yet")
end)

-- The lines below are what the next game is read from (#52): call counts, the unsplit rest of ItemUsageThink,
-- detail= for named helpers, slow calls, and the 5-minute [OHA-PERFSUM] line.
local function printedWith(word)
	local found = {}
	for _, line in ipairs(T.stub.printed) do
		if string.find(line, word, 1, true) then
			found[#found + 1] = line
		end
	end
	return found
end

T.test("Perf.Format: call counts, unsplit rest, detail and slow calls", function()
	local Perf = perf()
	local window = {
		total = 0.3,
		calls = 420,
		sum = { ItemUsageThink = 0.21, ["retreat.GetDesire"] = 0.06, ["farm.GetDesire"] = 0.03 },
		count = { ItemUsageThink = 300, ["retreat.GetDesire"] = 60, ["farm.GetDesire"] = 60 },
		parts = { items = 0.09, ["hero-abilities"] = 0.05, watchers = 0.01 },
		detail = { item_tpscroll = 0.04, EatForage = 0.002 },
		slow = { ["retreat.GetDesire"] = 2, ItemUsageThink = 5 },
		slowCalls = 7,
		slowGc = 3,
		gcCalls = 4,
		allocKb = 1500,
		peak = 0.0091,
		peakName = "retreat.GetDesire",
	}
	local limits = { top = 2, parts = 5, detail = 6, slow = 3 }
	local line = Perf.Format("OHA-PERF", 1230, "lich", "over-budget", window, 10, limits)
	T.eq(
		line,
		"[OHA-PERF] t=1230 lich why=over-budget ms/s=30.0 calls=420 window=10s"
			.. " top=ItemUsageThink=210ms/300,retreat.GetDesire=60ms/60"
			.. " parts=items=90ms,unsplit=60ms,hero-abilities=50ms,watchers=10ms"
			.. " detail=item_tpscroll=40ms,EatForage=2ms"
			.. " slow=7 slowGc=3 slowTop=ItemUsageThink=5,retreat.GetDesire=2"
			.. " peak=retreat.GetDesire=9.1ms kb/s=150 gc=4",
		"line"
	)
end)

T.test("Perf.Format: an empty window still gives a full line", function()
	local Perf = perf()
	local line = Perf.Format(
		"OHA-PERFSUM",
		300,
		"lich",
		"total",
		{ total = 0, calls = 0, sum = {} },
		300,
		{ top = 3, parts = 3, detail = 3, slow = 3 }
	)
	T.eq(
		line,
		"[OHA-PERFSUM] t=300 lich why=total ms/s=0.0 calls=0 window=300s top=- parts=- detail=- slow=0 slowGc=0"
			.. " slowTop=- peak=-=0.0ms kb/s=0 gc=0",
		"line"
	)
end)

T.test("Perf.WrapDetail passes everything through and times only the outer helper", function()
	local Perf = perf()
	local bot = GetBot()
	local rules = {}
	rules.base = function(a)
		T.stub.time = T.stub.time + 0.004
		return a * 2, nil, "third"
	end
	-- An alias rule calls the base rule through the table, as item_bfury does with item_quelling_blade.
	rules.alias = function(a)
		return rules.base(a)
	end
	Perf.WrapDetailIn(rules, "base", "base")
	Perf.WrapDetailIn(rules, "alias", "alias")
	local entry = Perf.Wrap("test.entry", function()
		return rules.alias(21)
	end)
	-- The first timed call opens the bot's window; helper times before it are dropped, like the parts.
	Perf.Wrap("test.first", function() end)()
	local one, two, three = entry()
	T.eq(one, 42, "first return")
	T.eq(two, nil, "nil in the middle")
	T.eq(three, "third", "value after a nil")
	T.near(bot._perf.detail.alias, 0.004, 1e-9, "alias timed")
	T.eq(bot._perf.detail.base, nil, "base inside alias not counted twice")
	rules.base(1)
	T.near(bot._perf.detail.base, 0.004, 1e-9, "base timed when called directly")
	T.near(bot._perf.sum["test.entry"], 0.004, 1e-9, "the entry point's own time")
	T.eq(bot._perf.slow["test.entry"], 1, "4ms is a slow call (the engine warns from 2ms)")
end)

T.test("Perf.WrapDetailIn wraps a shared function once, and skips what is missing", function()
	local Perf = perf()
	local shared = { Tick = function() end }
	Perf.WrapDetailIn(shared, "Tick", "Tick")
	local wrappedOnce = shared.Tick
	Perf.WrapDetailIn(shared, "Tick", "Tick")
	T.eq(shared.Tick, wrappedOnce, "second bot's load does not wrap again")
	Perf.WrapDetailIn(shared, "Missing", "Missing")
	T.eq(shared.Missing, nil, "a missing helper stays missing")
	Perf.WrapDetailIn(nil, "Tick", "Tick")
end)

T.test("Perf: a helper that raises an error is timed, raises it unchanged and leaves the next one timed", function()
	local Perf = perf()
	local bot = GetBot()
	local helpers = {
		Bad = function()
			T.stub.time = T.stub.time + 0.002
			error("boom", 0)
		end,
		Good = function()
			T.stub.time = T.stub.time + 0.001
		end,
	}
	Perf.WrapDetailIn(helpers, "Bad", "Bad")
	Perf.WrapDetailIn(helpers, "Good", "Good")
	local ok, err
	local entry = Perf.Wrap("test.entry", function()
		ok, err = pcall(helpers.Bad)
		helpers.Good()
	end)
	Perf.Wrap("test.first", function() end)()
	entry()
	T.eq(ok, false, "the error still reaches the caller")
	T.eq(err, "boom", "with its own message")
	T.near(bot._perf.detail.Bad, 0.002, 1e-9, "the failing helper's time")
	T.near(bot._perf.detail.Good, 0.001, 1e-9, "the helper after it")
end)

T.test("Perf: quiet under budget, but [OHA-PERFSUM] prints every 5 minutes", function()
	local Perf = perf()
	local cheap = Perf.Wrap("test.cheap", function()
		T.stub.time = T.stub.time + 0.0005
	end)
	-- One call a second for 320s: 0.5 ms/s, far under the 20 ms/s budget.
	for _ = 1, 320 do
		cheap()
		T.stub.time = T.stub.time + 1
	end
	local short = printedWith("[OHA-PERF]")
	T.eq(#short, 1, "only the baseline line")
	T.ok(string.find(short[1], "why=baseline", 1, true), "baseline: " .. short[1])
	local sums = printedWith("[OHA-PERFSUM]")
	T.eq(#sums, 1, "one 5-minute line")
	T.ok(string.find(sums[1], "why=total ms/s=0.5 ", 1, true), "whole-window average: " .. sums[1])
	T.ok(string.find(sums[1], "top=test.cheap=", 1, true), "top function: " .. sums[1])
	T.ok(string.find(sums[1], " slow=0 ", 1, true), "no slow call: " .. sums[1])
end)

T.test("the item think still runs end to end with its item rules and gates timed", function()
	T.stub.reset({ hero = "npc_dota_hero_lich" })
	local Usage = dofile("ability_item_usage_generic.lua")
	local bot = GetBot()
	T.ok(type(Usage.ConsiderItemDesire.item_tpscroll) == "function", "the TP rule is still a function")
	-- The first think opens the timing window; the second one's helpers are recorded in it.
	ItemUsageThink()
	ItemUsageThink()
	T.eq(bot._perf.count.ItemUsageThink, 2, "both thinks counted")
	local detail = bot._perf.detail or {}
	for _, name in ipairs({ "EatForage", "DeflectTowerAggro", "BannerFromBackpack", "Dispel.Self", "MatchTrace.Tick" }) do
		T.ok(detail[name] ~= nil, name .. " timed")
	end
end)

T.test("Perf.FormatMemory: the Lua memory line, with peak, growth and the first reading", function()
	local Perf = perf()
	T.eq(
		Perf.FormatMemory(600, "meepo", 51234.4, 50000, 52000, 30000),
		"[OHA-MEM] t=600 meepo kb=51234 peak=52000 grew=1234 start=30000",
		"a later line"
	)
	T.eq(
		Perf.FormatMemory(-80, "lich", 30000, nil, 30000, nil),
		"[OHA-MEM] t=-80 lich kb=30000 peak=30000 grew=0 start=30000",
		"the first line"
	)
end)
