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
	-- Game 065, t=1004: a heal at 54% took the last of two charges; no escape pact at 1022-1028, died at 1030.
	T.eq(ok("heal", 1, 2, 0.54), false, "heal at 54% on the last of two charges")
	T.eq(ok("heal", 1, 2, 0.49), true, "heal under 50% on the last charge")
	T.eq(ok("heal", 1, 1, 0.55), true, "levels 1-2 (one charge): heal under 60%")
	T.eq(ok("heal", 1, 1, 0.65), false, "levels 1-2 (one charge): no heal at 65%")
	T.eq(ok("other", 1, 2, 0.7), false, "damage pact on the last charge")
	T.eq(ok("hunt", 1, 2, 0.45), true, "under 50% anything may use it")
	T.eq(ok("other", 1, 1, 0.9), true, "levels 1-2 (one charge): the pact is the spell's main use")
	T.eq(ok("hunt", 2, 2, 0.9), true, "two charges: spend one")
end)

T.test("clinkz: a hunt target out of vision (null handle) is found again by player ID or waited for", function()
	local X = clinkz()
	local bot = Stub.bot
	local dire = Stub.teams[bot:GetTeam() == 2 and 3 or 2]
	local zeus = dire[2]
	local pid = zeus:GetPlayerID()
	Stub.time = 2000
	X.LockHuntTarget(zeus)
	T.eq(bot._huntPid, pid, "player ID kept at lock")
	T.eq(bot._huntName, "zuus", "name kept at lock")
	bot._huntLockAt, bot._huntLockFor, bot._huntRange = 2000, 30, 3200
	-- Game 065, t=2001: Zeus jumped out of vision, the old handle reads IsNull().
	local gone = Stub.newUnit({ name = zeus:GetUnitName(), team = zeus:GetTeam(), pid = pid })
	gone.IsNull = function()
		return true
	end
	bot._huntTarget = gone
	T.eq(X.RefindHuntTarget(), zeus, "a visible hero with the same player ID replaces the null handle")
	T.eq(bot._huntTarget, zeus, "and is the locked target now")
	-- Not in the enemy list (unseen): wait for it while the player ID says alive.
	bot._huntTarget = gone
	zeus.IsHero = function()
		return false
	end
	T.ok(X.HuntTargetAlive(gone), "alive by player ID")
	Stub.time = 2001
	local target, waiting = X.HuntTarget()
	T.eq(target, gone, "keeps the locked target")
	T.eq(waiting, true, "waits for it")
	-- 2.5 s later: dropped (lost-sight), and the same hero is not picked again for 6 s.
	Stub.time = 2004
	T.eq(X.HuntTarget(), nil, "dropped after 2.5 s")
	T.eq(bot._huntSkipPid, pid, "same hero skipped")
	T.ok(X.HuntSkipped(zeus), "skipped at 2004")
	Stub.time = 2011
	T.eq(X.HuntSkipped(zeus), false, "free again after 6 s")
	-- Dead: no wait.
	zeus._alive = false
	bot._huntPid = pid
	T.eq(X.HuntTargetAlive(gone), false, "dead by player ID")
end)
