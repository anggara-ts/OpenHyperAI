-- FuncLib/systems/meepo_trace.lua (#139): the [OHA-MTRACE] wrapper must change nothing when the switch is off, and
-- when on it must pass every value through and print a start line before the call and an end line after it.
local T = ...
local Stub = T.stub

local function setup(hero)
	local bot = Stub.reset({ hero = hero or "npc_dota_hero_meepo", slot = 1 })
	local MeepoTrace = require(GetScriptDirectory() .. "/FuncLib/systems/meepo_trace")
	return bot, MeepoTrace
end

local function traceLines()
	local found = {}
	for _, line in ipairs(Stub.printed) do
		if string.find(line, "[OHA-MTRACE]", 1, true) then
			found[#found + 1] = line
		end
	end
	return found
end

local function sample(a, b)
	return a + b, nil, "third"
end

T.test("Debug_Meepo_Trace is off by default (Customize/general.lua)", function()
	local _, MeepoTrace = setup()
	T.ok(not MeepoTrace.IsOn(), "off without the setting")
	T.eq(MeepoTrace.Wrap("farm.GetDesire", sample), sample, "off: the function itself")
end)

T.test("switch off: the function itself, values through, nothing printed", function()
	local _, MeepoTrace = setup()
	MeepoTrace.SetEnabled(false)
	local wrapped = MeepoTrace.Wrap("farm.GetDesire", sample)
	T.eq(wrapped, sample, "no wrapper")
	local one, two, three = wrapped(2, 3)
	T.eq(one, 5, "first return")
	T.eq(two, nil, "nil in the middle")
	T.eq(three, "third", "value after a nil")
	T.eq(#traceLines(), 0, "no trace lines")
end)

T.test("switch on: values through, start before and end after the call", function()
	local _, MeepoTrace = setup()
	MeepoTrace.SetEnabled(true)
	local linesInside = nil
	local wrapped = MeepoTrace.Wrap("farm.GetDesire", function(a, b)
		linesInside = linesInside or #traceLines()
		return sample(a, b)
	end)
	local one, two, three = wrapped(2, 3)
	MeepoTrace.SetEnabled(false)
	T.eq(one, 5, "first return")
	T.eq(two, nil, "nil in the middle")
	T.eq(three, "third", "value after a nil")
	T.eq(select("#", wrapped(2, 3)), 3, "same number of returns")
	local lines = traceLines()
	T.eq(linesInside, 1, "the start line is out before the call runs")
	T.ok(string.find(lines[1], "^%[OHA%-MTRACE%] main farm%.GetDesire start t=%S+ g=%S+$") ~= nil, lines[1])
	T.ok(string.find(lines[2], "^%[OHA%-MTRACE%] main farm%.GetDesire end ms=%S+ act=%S+ q=%S+$") ~= nil, lines[2])
end)

T.test("switch on: an error prints err= and is raised again unchanged", function()
	local _, MeepoTrace = setup()
	MeepoTrace.SetEnabled(true)
	local wrapped = MeepoTrace.Wrap("rune.Think", function()
		error("boom", 0)
	end)
	local ok, err = pcall(wrapped)
	MeepoTrace.SetEnabled(false)
	T.ok(not ok, "still fails")
	T.eq(err, "boom", "same error")
	local lines = traceLines()
	T.ok(string.find(lines[#lines], "rune.Think end ms=%S+ err=boom$") ~= nil, lines[#lines])
end)

T.test("switch on: other heroes and missing entry points are left alone", function()
	local _, MeepoTrace = setup("npc_dota_hero_lich")
	MeepoTrace.SetEnabled(true)
	T.eq(MeepoTrace.Wrap("farm.GetDesire", sample), sample, "not a Meepo: the function itself")
	T.ok(not MeepoTrace.IsOn(), "IsOn false for other heroes")
	setup()
	MeepoTrace = require(GetScriptDirectory() .. "/FuncLib/systems/meepo_trace")
	MeepoTrace.SetEnabled(true)
	-- Retreat has no Think of its own: wrapping must not create one (Valve's would be replaced).
	T.eq(MeepoTrace.Wrap("retreat.Think", nil), nil, "nil stays nil")
	MeepoTrace.SetEnabled(false)
end)

T.test("switch on: a clone body gets a stable clone<N> tag", function()
	local bot, MeepoTrace = setup()
	MeepoTrace.SetEnabled(true)
	local clone = Stub.newUnit({ name = "npc_dota_hero_meepo", team = bot:GetTeam(), hero = true })
	Stub.bot = clone
	local wrapped = MeepoTrace.Wrap("ItemUsageThink", function() end)
	wrapped()
	wrapped()
	MeepoTrace.Mark("meepo.order-poof")
	Stub.bot = bot
	wrapped()
	MeepoTrace.SetEnabled(false)
	local lines = traceLines()
	T.ok(string.find(lines[1], "] clone1 ItemUsageThink start", 1, true) ~= nil, lines[1])
	T.ok(string.find(lines[3], "] clone1 ItemUsageThink start", 1, true) ~= nil, "same tag on the next call")
	T.ok(string.find(lines[5], "] clone1 meepo.order-poof mark t=", 1, true) ~= nil, lines[5])
	T.ok(string.find(lines[6], "] main ItemUsageThink start", 1, true) ~= nil, lines[6])
end)

T.test("no OHA_MUTED pattern drops an MTRACE line", function()
	setup()
	require(GetScriptDirectory() .. "/FuncLib/systems/global_overrides")
	local printed = {}
	local raw = _G.OHA_RAW_PRINT
	_G.OHA_RAW_PRINT = function(msg)
		printed[#printed + 1] = msg
	end
	local MeepoTrace = require(GetScriptDirectory() .. "/FuncLib/systems/meepo_trace")
	MeepoTrace.SetEnabled(true)
	MeepoTrace.Wrap("laning.Think", function() end)()
	print("[OHA-MTRACE] main laning.Think start t=1.00 g=91.00")
	MeepoTrace.SetEnabled(false)
	_G.OHA_RAW_PRINT = raw
	T.eq(#printed, 3, "start, end and the line through the overridden print")
end)
