-- BotsLib/hero_hoodwink.lua: when a charging Sharpshooter is released, how Acorn Shot is cast (tree for the
-- Bushwhack combo or bounce), and where Bushwhack lands for a planted tree.
local T = ...
local Stub = T.stub

local function hoodwink()
	Stub.reset({ hero = "npc_dota_hero_hoodwink", slot = 4 })
	local ok, result = Stub.load("BotsLib/hero_hoodwink")
	if not ok then
		error(tostring(result), 0)
	end
	return result
end

T.test("hoodwink: Sharpshooter release reason", function()
	local X = hoodwink()
	-- charge, max_charge_time, has target, on the bolt line, harassed, leaving, move orders turn her
	local reason = X.SharpshooterReleaseReason
	T.eq(reason(1.0, 3, true, true, false, false, true), nil, "still charging")
	T.eq(reason(3.0, 3, true, true, false, false, true), "full", "full charge, on the line")
	T.eq(reason(3.4, 3, true, false, false, false, true), nil, "full charge, off the line: keep turning")
	T.eq(reason(3.0, 3, true, false, false, false, false), "full-noturn", "off the line and she cannot be turned")
	T.eq(reason(2.0, 3, true, false, false, false, false), nil, "cannot be turned, but not charged yet")
	T.eq(reason(3.0, 3, false, false, false, false, true), "full", "full charge, nobody to aim at")
	T.eq(reason(1.2, 3, true, false, true, false, true), "harassed", "hit while charging")
	T.eq(reason(0.2, 3, true, true, true, true, true), nil, "no release in the first half second")
	T.eq(reason(1.5, 3, true, true, false, true, true), "leaving", "target about to outrun the bolt")
	T.eq(reason(1.5, 3, true, false, false, true, true), nil, "leaving but off the line: a miss anyway")
end)

T.test("hoodwink: Acorn Shot mode", function()
	local X = hoodwink()
	-- why, Bushwhack ready, mana for both, target can be trapped, a tree already by the target
	T.eq(X.AcornShotMode("engage", true, true, true, false), "tree", "combo: plant the tree")
	T.eq(X.AcornShotMode("retreat", true, true, true, false), "tree", "combo on the chaser")
	T.eq(X.AcornShotMode("engage", false, true, true, false), "bounce", "Bushwhack on cooldown")
	T.eq(X.AcornShotMode("engage", true, false, true, false), "bounce", "mana for one spell only")
	T.eq(X.AcornShotMode("engage", true, true, false, false), "ground", "spell-immune target: no unit cast")
	T.eq(X.AcornShotMode("retreat", false, false, false, false), "ground", "spell-immune chaser")
	T.eq(X.AcornShotMode("engage", true, true, true, true), "bounce", "a tree is there already")
	T.eq(X.AcornShotMode("kill", true, true, true, false), "bounce", "the acorn itself kills")
	T.eq(X.AcornShotMode("wave", false, false, false, false), "tree", "ground cast on a creep wave")
end)

T.test("hoodwink: Bushwhack centre for a planted tree", function()
	local X = hoodwink()
	-- trap_radius 275: the enemy and the tree may be up to 500 apart.
	local center = X.BushwhackCenterForTree(Vector(0, 0, 0), Vector(400, 0, 0), 275)
	T.near(center.x, 200, 1e-6, "halfway x")
	T.near(center.y, 0, 1e-6, "halfway y")
	T.eq(X.BushwhackCenterForTree(Vector(0, 0, 0), Vector(520, 0, 0), 275), nil, "too far apart for one net")
end)

T.test("hoodwink: Scurry heading check", function()
	local X = hoodwink()
	local origin = Vector(0, 0, 0)
	T.eq(X.HeadingWithin(Vector(300, 0, 0), origin, Vector(1000, 0, 0), 90), true, "straight at it")
	T.eq(X.HeadingWithin(Vector(300, 250, 0), origin, Vector(1000, 0, 0), 90), true, "40 degrees off: moving toward")
	T.eq(X.HeadingWithin(Vector(300, 250, 0), origin, Vector(1000, 0, 0), 30), false, "40 degrees off: not facing")
	T.eq(X.HeadingWithin(Vector(-300, 10, 0), origin, Vector(1000, 0, 0), 90), false, "moving away")
	T.eq(X.HeadingWithin(Vector(10, 0, 0), origin, Vector(1000, 0, 0), 90), false, "standing")
end)

T.test("hoodwink: Scurry reason", function()
	local X = hoodwink()
	local function chase(overrides)
		-- Level 1 Scurry (20% for 3.5s, game file) at 315 speed: 220 extra reach past attack range 625.
		local s = {
			charges = 2,
			engaging = true,
			targetDist = 750,
			attackRange = 625,
			headingToTarget = true,
			targetRunningAway = true,
			targetSpeed = 320,
			mySpeed = 315,
			speedPct = 20,
			duration = 3.5,
		}
		for key, value in pairs(overrides or {}) do
			s[key] = value
		end
		return X.ScurryReason(s)
	end
	T.eq(chase(), "chase", "just out of attack range, as fast as her")
	T.eq(chase({ charges = 1 }), nil, "last charge kept for an escape")
	-- (false stands in for nil here: pairs skips a nil override; ScurryReason reads both through "or 1".)
	T.eq(chase({ charges = false }), nil, "unknown count: counted as the last charge")
	T.eq(chase({ targetSpeed = 280 }), nil, "slower target: caught without Scurry")
	T.eq(chase({ targetDist = 600 }), nil, "in attack range")
	T.eq(chase({ targetDist = 900 }), nil, "beyond the reach Scurry buys")
	T.eq(chase({ targetRunningAway = false }), nil, "target not running from her")
	T.eq(chase({ headingToTarget = false }), nil, "she is not going toward it")
	T.eq(chase({ targetDist = 1400, castWalk = 700 }), "position", "Bushwhack range 2.2s away")
	T.eq(chase({ targetDist = 1400, castWalk = 500 }), nil, "walk under 2s")
	T.eq(chase({ targetDist = 2400, castWalk = 1400 }), nil, "Scurry ends before she gets there")
	T.eq(chase({ targetDist = 1400, castWalk = 700, charges = 1 }), nil, "position keeps the last charge too")
	local escape = { retreating = true, headingHome = true, inDanger = true, charges = 1 }
	T.eq(X.ScurryReason(escape), "escape", "escape spends the last charge")
	escape.charges = 0
	T.eq(X.ScurryReason(escape), "escape", "tracker lags behind a restored charge: castable is enough")
	escape.headingHome = false
	T.eq(X.ScurryReason(escape), nil, "not heading home")
	T.eq(X.ScurryReason({ retreating = true, headingHome = true, inDanger = false, charges = 2 }), nil, "safe")
	T.eq(
		X.ScurryReason({ retreating = true, headingHome = true, inDanger = false, charges = 2, engaging = true }),
		nil,
		"retreat wins over engage"
	)
end)
