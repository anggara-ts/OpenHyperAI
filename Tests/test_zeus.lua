-- BotsLib/hero_zuus.lua: Nimbus for a fleeing ally (#47, game 064): when, where, and when the cloud's bolt would go
-- to another unit.
local T = ...
local Stub = T.stub

local function zeus()
	Stub.reset({ hero = "npc_dota_hero_zuus", slot = 2 })
	local ok, result = Stub.load("BotsLib/hero_zuus")
	if not ok then
		error(tostring(result), 0)
	end
	return result
end

T.test("zeus: chaser catch time", function()
	local X = zeus()
	T.eq(X.CatchTime(0, 350, 300), 0, "in attack range now")
	T.near(X.CatchTime(500, 350, 300), 10, 1e-6, "gains 50 a second on 500")
	T.near(X.CatchTime(600, 350, 0), 600 / 350, 1e-6, "ally standing")
	T.near(X.CatchTime(600, 350, -100), 600 / 350, 1e-6, "ally walking toward him counts as standing")
	T.eq(X.CatchTime(500, 300, 320), 99, "ally faster: never")
end)

-- Datafeed hero_id=22 (zuus_cloud): radius 450, a bolt every 2.5s, cast point 0.2.
local function input(overrides)
	local c = {
		chaser = { x = 0, y = 0 },
		ally = { x = 1000, y = 0 },
		chaserSpeed = 330,
		allyHp = 0.45,
		catchTime = 3,
		hitting = false,
		inBoltRange = false,
		boltReady = true,
		units = {},
		radius = 450,
		interval = 2.5,
		castPoint = 0.2,
	}
	for key, value in pairs(overrides or {}) do
		c[key] = value
	end
	return c
end

T.test("zeus: Nimbus help plan", function()
	local X = zeus()
	local plan, why = X.NimbusHelpPlan(input())
	T.ok(plan ~= nil, "cast: " .. tostring(why))
	-- 330 speed: 66 walked in the cast point, then one radius more: the aim is 516 along the way to the ally.
	T.near(plan.aim.x, 516, 1e-6, "aim on the chaser's path")
	T.near(plan.aim.y, 0, 1e-6, "on the line to the ally")
	T.near(plan.stay, 900 / 330, 1e-6, "inside for 2 radius / speed")
	T.eq(plan.crowd, 0, "nobody else there")

	plan, why = X.NimbusHelpPlan(input({ allyHp = 0.1 }))
	T.eq(why, "too-late", "ally nearly dead (game 064 Alchemist at 1%)")
	plan, why = X.NimbusHelpPlan(input({ allyHp = 0.1, minHp = 0 }))
	T.ok(plan ~= nil, "Zeus's own flee has no HP floor")
	plan, why = X.NimbusHelpPlan(input({ catchTime = 8 }))
	T.eq(why, "not-yet", "chaser far from catching him")
	plan, why = X.NimbusHelpPlan(input({ catchTime = 8, hitting = true }))
	T.ok(plan ~= nil, "already hitting him")
	plan, why = X.NimbusHelpPlan(input({ inBoltRange = true }))
	T.eq(why, "bolt-range", "Zeus's own bolt reaches the chaser")
	plan, why = X.NimbusHelpPlan(input({ inBoltRange = true, boltReady = false }))
	T.ok(plan ~= nil, "bolt on cooldown: Nimbus")

	local skipped
	plan, why, skipped = X.NimbusHelpPlan(input({ units = { { x = 600, y = 100 } } }))
	T.eq(why, "crowded", "a creep inside the cloud takes the bolt")
	T.eq(skipped.crowd, 1, "one unit counted")
	plan, why = X.NimbusHelpPlan(input({ units = { { x = 1200, y = 0 } } }))
	T.ok(plan ~= nil, "a creep 684 from the centre is outside")

	plan, why = X.NimbusHelpPlan(input({ chaserSpeed = 420 }))
	T.eq(why, "too-fast", "420 speed crosses 900 in 2.1s, under one bolt interval")
	plan, why = X.NimbusHelpPlan(input({ ally = { x = 300, y = 0 }, chaserSpeed = 420 }))
	T.eq(plan, nil, "ally close: aim at the ally, chaser still leaves before a bolt")
	T.eq(why, "too-fast", "stay (300 + 450 - 84) / 420 = 1.6s")
	plan, why = X.NimbusHelpPlan(input({ chaserSpeed = 0 }))
	T.ok(plan ~= nil, "standing chaser")
	T.near(plan.aim.x, 0, 1e-6, "aim on him")
end)

T.test("zeus: fleeing-ally scan and result line run against the stub API", function()
	local X = zeus()
	T.eq(type(X.FleeingAllyChasers()), "table", "a list")
	X.ThinkNimbusResult()
	T.ok(true, "no stub missing call")
end)
