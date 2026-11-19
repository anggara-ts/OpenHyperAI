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
