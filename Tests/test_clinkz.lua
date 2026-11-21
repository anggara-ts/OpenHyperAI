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
