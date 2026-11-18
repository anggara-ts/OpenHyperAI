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
