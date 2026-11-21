-- FuncLib/systems/rune_rules.lua (#32): the leftover-rune hold and the capped pick-up retries of mode_rune_generic.lua.
local T = ...

local function load()
	T.stub.reset({ hero = "npc_dota_hero_clinkz" })
	return require(GetScriptDirectory() .. "/FuncLib/systems/rune_rules")
end

T.test("rune rules: what counts as a leftover rune", function()
	local R = load()
	-- Game 063, 30:29: the bottom river spot read available, type -1, in vision, 29s into its cycle.
	T.eq(R.IsLeftover(true, -1, nil, true, 29), true, "available, no type, seen")
	T.eq(R.IsLeftover(true, 9, 9, true, 29), true, "RUNE_INVALID counts as no type")
	T.eq(R.IsLeftover(true, 5, nil, true, 29), false, "a typed rune (bounty) is a normal rune")
	T.eq(R.IsLeftover(false, -1, nil, true, 29), false, "missing")
	T.eq(R.IsLeftover(true, -1, nil, false, 29), false, "spot not in vision: the status is stale")
	-- Game 017: just after a spawn the type reads -1 before the rune shows.
	T.eq(R.IsLeftover(true, -1, nil, true, 3), false, "first 10s of the cycle")
end)

T.test("rune rules: leftover hold steps", function()
	local R = load()
	local hold = { t0 = 100 }
	T.eq(R.LeftoverStep(hold, 100.5, 80, true, false, false), "try", "the one pick-up order has its time")
	T.eq(R.LeftoverStep(hold, 102, 120, true, false, false), "walk", "then onto the spot")
	T.eq(R.LeftoverStep(hold, 102.5, 30, true, false, false), "hold", "on the spot")
	T.eq(R.HeldFor(hold, 104), 1.5, "held 1.5s")
	local phase, why = R.LeftoverStep(hold, 105.6, 30, true, false, false)
	T.eq(phase, "end", "3s on the spot ends it")
	T.eq(why, "held", "why=held")
	local _, gone = R.LeftoverStep({ t0 = 100 }, 101, 80, false, false, false)
	T.eq(gone, "taken", "the rune went (the order or the item mode took it)")
	local _, typed = R.LeftoverStep({ t0 = 100 }, 101, 80, true, true, false)
	T.eq(typed, "typed", "the type showed up: back to the normal pick-up")
	local _, fight = R.LeftoverStep({ t0 = 100 }, 101, 80, true, false, true)
	T.eq(fight, "fight", "enemy heroes at the spot")
	-- Never stuck: a bot that can't get onto the spot ends after GIVE_UP.
	local late, timeout = R.LeftoverStep({ t0 = 100 }, 100 + R.GIVE_UP + 0.1, 500, true, false, false)
	T.eq(late, "end", "timeout ends it")
	T.eq(timeout, "timeout", "why=timeout")
	-- Walking off the spot restarts the on-spot clock.
	local moved = { t0 = 100 }
	R.LeftoverStep(moved, 102, 30, true, false, false)
	R.LeftoverStep(moved, 103, 200, true, false, false)
	T.eq(moved.onSpotAt, nil, "off the spot: clock reset")
end)

T.test("rune rules: pick-up retries capped at 3, 1s apart", function()
	local R = load()
	local try = { n = 0 }
	local orders = 0
	-- Game 063: 19 orders in 3s at distance 0. Thinks every 0.1s for 5s.
	local failedAt
	for i = 0, 50 do
		local now = i * 0.1
		local step = R.PickupStep(try, now)
		if step == "order" then
			orders = orders + 1
			try.n = try.n + 1
			try.last = now
		elseif step == "fail" then
			failedAt = now
			break
		end
	end
	T.eq(orders, 3, "three orders")
	T.ok(
		failedAt ~= nil and failedAt >= 2.9 and failedAt <= 3.1,
		"fails 1s after the third order: " .. tostring(failedAt)
	)
end)

T.test("rune rules: the spawn hold window at a river spot", function()
	local R = load()
	-- Game 064, 2:00: Puck 475 from the top spot at the spawn.
	T.eq(R.SpawnHold(0.1, 475), true, "475 away at the spawn")
	T.eq(R.SpawnHold(-2, 590), true, "2s before the spawn, 590 away")
	T.eq(R.SpawnHold(-2.5, 300), false, "earlier: the normal walk desire")
	T.eq(R.SpawnHold(3, 500), true, "3s after the spawn")
	T.eq(R.SpawnHold(3.2, 500), false, "the hold ends 3s after the spawn")
	T.eq(R.SpawnHold(1, 700), false, "farther than 600")
	T.ok(R.SPAWN_HOLD_DESIRE > 0.56, "above laning's 0.54-0.56 in game 064")
end)

T.test("rune mode: a bot 475 from a river spot at the 2:00 spawn holds above laning (game 064)", function()
	T.stub.reset({ hero = "npc_dota_hero_puck" })
	local ok, err = T.stub.load("mode_rune_generic")
	T.ok(ok, tostring(err))
	local bot = GetBot()
	local spot = bot:GetLocation() + Vector(475, 0, 0)
	bot._waterWalk = { id = 0, loc = spot, t0 = 120 }
	T.stub.time = 120.1
	local desire = GetDesire()
	T.near(desire, 0.6, 1e-9, "spawn hold desire")
	local started, ended = nil, nil
	T.stub.time = 121
	bot._loc = spot + Vector(250, 0, 0)
	GetDesire()
	for _, line in ipairs(T.stub.printed) do
		started = started or (string.find(line, "river%-spawn%-hold spot=0 dist=475 since=0%.1") and line)
		ended = ended or (string.find(line, "river%-spawn%-hold%-end why=on%-spot spot=0 dist=250 held=0%.9") and line)
	end
	T.ok(started ~= nil, "start line")
	T.ok(ended ~= nil, "end line: the on-spot stay takes over")
end)
