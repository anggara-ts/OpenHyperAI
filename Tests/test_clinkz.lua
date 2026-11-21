-- BotsLib/hero_clinkz.lua: Death Pact charges and the escape pact (#94).
local T = ...
local Stub = T.stub

local function clinkz()
	Stub.reset({ hero = "npc_dota_hero_clinkz", slot = 3 })
	local ok, result = Stub.load("BotsLib/hero_clinkz")
	if not ok then
		error(tostring(result), 0)
	end
	return result
end

T.test("clinkz: Death Pact charge count (1 charge, 40 s restore)", function()
	local X = clinkz()
	local step = X.PactChargeStep
	-- Full at the start, a pact at t=458 (game 063): none left, back at 498.
	local n, nextAt = step(nil, nil, 1, 40, 458, true)
	T.eq(n, 0, "spent")
	T.eq(nextAt, 498, "restore time")
	-- t=476: the three escape orders came with no charge.
	n, nextAt = step(n, nextAt, 1, 40, 476, false)
	T.eq(n, 0, "still empty at 476")
	n, nextAt = step(n, nextAt, 1, 40, 498, false)
	T.eq(n, 1, "back at 498")
	T.eq(nextAt, nil, "full: no timer")
end)

T.test("clinkz: two charges restore one at a time", function()
	local X = clinkz()
	local step = X.PactChargeStep
	local n, nextAt = step(2, nil, 2, 40, 100, true)
	n, nextAt = step(n, nextAt, 2, 40, 110, true)
	T.eq(n, 0, "both spent")
	T.eq(nextAt, 140, "first back at 140")
	n, nextAt = step(n, nextAt, 2, 40, 141, false)
	T.eq(n, 1, "one back")
	T.eq(nextAt, 180, "second 40 s later")
	n = step(n, nextAt, 2, 40, 200, false)
	T.eq(n, 2, "full")
end)

T.test("clinkz: the escape pact and the hunt step run on the stub", function()
	local X = clinkz()
	local ok, err = pcall(X.PactCharges)
	T.ok(ok, "PactCharges: " .. tostring(err))
	local desire = X.ConsiderEscapePact()
	T.ok(desire ~= nil, "escape pact desire")
	local okH, errH = pcall(X.HuntStep)
	T.ok(okH, "HuntStep: " .. tostring(errH))
end)

T.test("clinkz: the last Death Pact charge is kept unless HP is low", function()
	local X = clinkz()
	local ok = X.PactSpendOk
	-- Game 064, t=2195/2431/2597: heal pacts at 82-86% HP on the last charge; at 15% the escape pact had none.
	T.eq(ok("heal", 1, 2, 0.84), false, "heal at 84% on the last charge")
	T.eq(ok("heal", 2, 2, 0.84), true, "heal at 84% with a spare charge")
	T.eq(ok("heal", 1, 2, 0.55), true, "heal under 60% (the heal rule's line)")
	T.eq(ok("other", 1, 2, 0.7), false, "damage pact on the last charge")
	T.eq(ok("hunt", 1, 2, 0.45), true, "under 50% anything may use it")
	T.eq(ok("other", 1, 1, 0.9), true, "levels 1-2 (one charge): the pact is the spell's main use")
	T.eq(ok("hunt", 2, 2, 0.9), true, "two charges: spend one")
end)
