-- FuncLib/systems/dodge_rules.lua (#134): will a linear skillshot hit, time to impact, and when a dodge item reacts.
local T = ...

local function rules()
	T.stub.reset({ hero = "npc_dota_hero_lich" })
	return require(GetScriptDirectory() .. "/FuncLib/systems/dodge_rules")
end

T.test("dodge rules: time to impact is distance / speed", function()
	local R = rules()
	T.near(R.TimeToImpact(900, 900), 1.0, 1e-9, "Sacred Arrow 900 away")
	T.near(R.TimeToImpact(800, 1600), 0.5, 1e-9, "Meat Hook 800 away")
	T.eq(R.TimeToImpact(-50, 1000), 0, "already inside: 0")
	T.eq(R.TimeToImpact(500, 0), nil, "no speed")
	T.eq(R.TimeToImpact(500, nil), nil, "unknown speed")
end)

T.test("dodge rules: react window (cast point + latency, plus slack)", function()
	local R = rules()
	local react = R.ReactTime(0)
	T.near(react, R.LATENCY, 1e-9, "cast point 0")
	T.eq(R.Window(react - 0.01, 0), "late", "lands before the item works")
	T.eq(R.Window(react, 0), "now", "just in time")
	T.eq(R.Window(react + R.SLACK, 0), "now", "end of the window")
	T.eq(R.Window(react + R.SLACK + 0.01, 0), "wait", "too early: wait")
	T.eq(R.Window(nil, 0), "wait", "unknown time: wait")
	-- A slower tool needs to start earlier.
	T.eq(R.Window(0.3, 0.3), "late", "cast point 0.3 cannot answer 0.3s")
	T.eq(R.Window(0.6, 0.3), "now", "cast point 0.3 answers 0.6s")
	-- The old fixed ranges: a fast spell at 900 lands in 0.3s (now), a slow one at 800 in 1.6s (wait).
	T.eq(R.Window(R.TimeToImpact(900, 3000), 0), "now", "3000 speed from 900")
	T.eq(R.Window(R.TimeToImpact(800, 500), 0), "wait", "500 speed from 800")
end)

T.test("dodge rules: linear projectile will hit", function()
	local R = rules()
	-- Arrow at the origin flying +x at 900, bot 900 ahead on the line: hits, edge arrives (900 - 145) / 900.
	local hit, tti, miss = R.LinearImpact(0, 0, 900, 0, 900, 0, 115, 30)
	T.eq(hit, true, "on the line")
	T.near(tti, (900 - 145) / 900, 1e-6, "tti to the edge")
	T.near(miss, 0, 1e-9, "miss 0")
	-- 100 to the side: still within 115 + 30.
	hit, tti, miss = R.LinearImpact(0, 0, 900, 0, 900, 100, 115, 30)
	T.eq(hit, true, "100 off the line")
	T.near(miss, 100, 1e-9, "miss 100")
	T.ok(tti > (900 - 145) / 900, "a glancing hit arrives later")
	-- 200 to the side: misses.
	local hitFar, _, missFar = R.LinearImpact(0, 0, 900, 0, 900, 200, 115, 30)
	T.eq(hitFar, false, "200 off the line")
	T.near(missFar, 200, 1e-9, "miss 200")
	-- Behind the projectile: it flies away.
	hit, tti = R.LinearImpact(0, 0, 900, 0, -500, 0, 115, 30)
	T.eq(hit, false, "behind")
	T.eq(tti, nil, "behind: no tti")
	-- Overlapping right now.
	hit, tti = R.LinearImpact(0, 0, 900, 0, -20, 0, 115, 30)
	T.eq(hit, true, "overlapping")
	T.eq(tti, 0, "overlapping: 0")
	-- A diagonal shot.
	hit = R.LinearImpact(0, 0, 1000, 1000, 1000, 1000, 100, 30)
	T.eq(hit, true, "diagonal on the line")
	-- Not moving.
	hit, tti = R.LinearImpact(0, 0, 0, 0, 100, 0, 100, 30)
	T.eq(hit, false, "no velocity")
	T.eq(tti, nil, "no velocity: no tti")
end)

T.test("dodge rules: side step leaves the line on the side of the base", function()
	local R = rules()
	-- Shot flying +x through the bot at (0, 0); base at (-3000, 2000): step to +y.
	local x, y = R.SideStep(900, 0, 0, 0, 500, -3000, 2000, 600)
	T.near(y, 500, 1e-9, "500 to the base's side")
	T.near(x, -600, 1e-9, "and 600 home along the line (capped)")
	local hit = R.LinearImpact(-900, 0, 900, 0, x, y, 115, 30)
	T.eq(hit, false, "the arrow misses the new spot")
	-- Base on the other side.
	x, y = R.SideStep(900, 0, 0, 0, 500, 3000, -2000, 600)
	T.near(y, -500, 1e-9, "-y side")
	T.near(x, 600, 1e-9, "home along +x")
	-- Negative distance: the other side (when the first spot is not passable).
	local _, flippedY = R.SideStep(900, 0, 0, 0, -500, -3000, 2000, 600)
	T.near(flippedY, -500, 1e-9, "flipped side")
	-- No velocity: stay.
	x, y = R.SideStep(0, 0, 10, 20, 500, 0, 0, 600)
	T.eq(x, 10, "x")
	T.eq(y, 20, "y")
end)

T.test("dodge rules: closing speed from two samples", function()
	local R = rules()
	T.near(R.ClosingSpeed(1000, 10, 900, 10.1), 1000, 1e-6, "100 in 0.1s")
	T.eq(R.ClosingSpeed(nil, nil, 900, 10.1), nil, "first sample")
	T.eq(R.ClosingSpeed(1000, 10.1, 900, 10.1), nil, "same think")
	T.eq(R.ClosingSpeed(1000, 10, 900, 11), nil, "too old")
	T.eq(R.ClosingSpeed(900, 10, 1000, 10.1), nil, "moving away")
end)

T.test("dodge rules: which tool answers which skillshot, and when it is worth it", function()
	local R = rules()
	local arrow, hook, wave = R.LINEAR.mirana_arrow, R.LINEAR.pudge_meat_hook, R.LINEAR.queenofpain_sonic_wave
	T.eq(R.ToolAnswers(arrow, "bkb"), true, "BKB blocks Sacred Arrow (immunity 4)")
	T.eq(R.ToolAnswers(hook, "bkb"), false, "Meat Hook pierces (immunity 3)")
	T.eq(R.ToolAnswers(hook, "blink"), true, "Blink dodges a hook")
	T.eq(R.ToolAnswers(hook, "cyclone"), true, "Eul's dodges a hook")
	T.eq(R.ToolAnswers(nil, "blink"), false, "not a dangerous spell")
	T.eq(R.WorthDodging(arrow, 1.0), true, "a stun is always worth it")
	T.eq(R.WorthDodging(wave, 1.0), false, "a nuke at full HP is not")
	T.eq(R.WorthDodging(wave, 0.4), true, "a nuke when hurt is")
	-- Every entry has the numbers the finder needs.
	for name, spec in pairs(R.LINEAR) do
		T.ok(spec.radius > 0 and spec.speed > 0 and spec.range > 0 and type(spec.why) == "string", name)
	end
end)
