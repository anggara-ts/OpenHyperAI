-- FuncLib/systems/escape_rules.lua (#36): escape direction, Jaunt side check, lane Orb spare mana.
local T = ...

local function load()
	T.stub.reset({ hero = "npc_dota_hero_puck" })
	return require(GetScriptDirectory() .. "/FuncLib/systems/escape_rules")
end

T.test("escape rules: away from the enemies, toward home", function()
	local R = load()
	-- No enemy: straight home.
	local x, y = R.Direction(0, 0, {}, -1000, 0)
	T.near(x, -1, 0.001, "home x")
	T.near(y, 0, 0.001, "home y")
	-- An enemy north of her, home west: the jump goes south-west, away from the enemy.
	x, y = R.Direction(0, 0, { { x = 0, y = 500 } }, -1000, 0)
	T.ok(y < 0, "away from the enemy (south)")
	T.ok(x < 0, "and toward home (west)")
	-- Game 064, 43:23: the enemy on the home side. The jump must not go into them.
	x = R.Direction(0, 0, { { x = -400, y = 0 } }, -5000, 0)
	T.ok(x > 0, "enemy between her and home: away from the enemy first")
	-- The nearest enemy counts most.
	x = R.Direction(0, 0, { { x = 300, y = 0 }, { x = -1500, y = 0 } }, 0, 5000)
	T.ok(x < 0, "away from the near one, not the far one")
end)

T.test("escape rules: a Jaunt only to an orb on the escape side", function()
	local R = load()
	T.eq(R.IsOnEscapeSide(0, 0, -800, 100, -1, 0), true, "orb ahead on the escape path")
	T.eq(R.IsOnEscapeSide(0, 0, 800, 100, -1, 0), false, "orb behind her (game 064, t=2600)")
end)

T.test("escape rules: lane Orb harass on spare mana", function()
	local R = load()
	-- Datafeed hero 13: Orb 90 mana, 12s cooldown at rank 1; Rift 100.
	T.eq(R.SpareManaOrb(380, 400, 1.5, 90, 100, 12), true, "nearly full")
	T.eq(R.SpareManaOrb(250, 400, 8, 90, 100, 12), true, "regen pays the orb back over its cooldown")
	T.eq(R.SpareManaOrb(250, 400, 1.5, 90, 100, 12), false, "neither")
	T.eq(R.SpareManaOrb(180, 190, 8, 90, 100, 12), false, "no Rift mana left after the orb")
	T.eq(R.SIPHON_BREAK, 750, "Spirit Siphon breaks at 500 + 250")
end)

T.test("escape rules: no lane Orb harass next to a hero or when hurt (game 067, 3:55)", function()
	local R = load()
	T.eq((R.OrbHarassSafe(0.72, 895)), false, "game 067: Death Prophet 895 away")
	T.eq(select(2, R.OrbHarassSafe(0.72, 895)), "threat", "why=threat")
	T.eq(select(2, R.OrbHarassSafe(0.65, nil)), "hp", "under 70% HP")
	T.eq((R.OrbHarassSafe(0.9, 950)), true, "the nearest hero past 900")
	T.eq((R.OrbHarassSafe(0.9, nil)), true, "no hero near")
end)

T.test("escape rules: no TP while siphoned or next to a hitter (game 067, 4:05)", function()
	local R = load()
	T.eq(select(2, R.HoldTp(true, nil)), "siphoned", "siphoned")
	T.eq(select(2, R.HoldTp(false, 82)), "hit-near", "game 067: Death Prophet 82 away hit her")
	T.eq((R.HoldTp(false, 760)), false, "past the break distance")
	T.eq((R.HoldTp(false, nil)), false, "nobody hit her")
end)

T.test("escape rules: Phase Shift at low HP against units (game 067, 42:07)", function()
	local R = load()
	T.eq(R.LowHpUnitsPhase(0.05, 0, false, 3), true, "zombies attacking her")
	T.eq(R.LowHpUnitsPhase(0.05, 0, true, 0), true, "a creep hit")
	T.eq(R.LowHpUnitsPhase(0.12, 0.04, false, 0), true, "HP falling")
	T.eq(R.LowHpUnitsPhase(0.12, 0, false, 0), false, "low but nobody hits her")
	T.eq(R.LowHpUnitsPhase(0.3, 0.1, true, 4), false, "over 20%")
end)

T.test("puck: the escape helpers run on the stub", function()
	T.stub.reset({ hero = "npc_dota_hero_puck", slot = 2 })
	local ok, X = T.stub.load("BotsLib/hero_puck")
	T.ok(ok, "hero_puck loads: " .. tostring(X))
	for _, name in ipairs({
		"ConsiderSiphonEscape",
		"ShiftExit",
		"DangerJaunt",
		"ConsiderIllusoryOrb",
		"ConsiderPhaseShift",
		"HoldTpInDanger",
		"SampleHp",
		"HpLoss",
		"UnitAttackers",
		"TombstoneDistance",
		"CastHoldTick",
		"SkillsComplement",
	}) do
		local okRun, err = pcall(X[name])
		T.ok(okRun, name .. ": " .. tostring(err))
	end
	local point = X.EscapePoint(1150)
	T.ok(point ~= nil and point.x ~= nil, "escape point")
	local okLog, errLog = pcall(X.LogEscapeAction, "blink", "test", point)
	T.ok(okLog, "LogEscapeAction: " .. tostring(errLog))
end)
