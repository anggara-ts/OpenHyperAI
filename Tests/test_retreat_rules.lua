-- FuncLib/systems/retreat_rules.lua: when an attacking bot is outnumbered enough to hard-retreat.
-- Arguments: allies, visible enemies, recently seen enemies, hp ratio, hit by a hero, we are stronger.
local T = ...

local function rules()
	T.stub.reset({ hero = "npc_dota_hero_lich" })
	return require(GetScriptDirectory() .. "/FuncLib/systems/retreat_rules")
end

T.test("hard retreat: healthy cases from game 038 keep fighting", function()
	local R = rules()
	-- Mirana t=29: alone, nobody within 1200, two lane opponents last seen within 2000, full HP.
	T.eq(R.HardRetreatOutnumbered(1, 0, 2, 1.00, false, false), false, "Mirana t=29")
	-- Meepo t=1115: three bodies (clones counted now) against two, full HP.
	T.eq(R.HardRetreatOutnumbered(3, 2, 2, 1.00, true, false), false, "Meepo t=1115")
	-- Healthy, one more enemy than us and being hit: still fight (not two more).
	T.eq(R.HardRetreatOutnumbered(2, 3, 3, 0.85, true, false), false, "2 vs 3 at 85%")
end)

T.test("hard retreat: still breaks off when it should", function()
	local R = rules()
	-- Healthy but alone against three that it can see, and being hit.
	T.eq(R.HardRetreatOutnumbered(1, 3, 3, 0.90, true, false), true, "1 vs 3 at 90%, hit")
	-- Same but not being hit yet: hold (the fight may not be on us).
	T.eq(R.HardRetreatOutnumbered(1, 3, 3, 0.90, false, false), false, "1 vs 3 at 90%, not hit")
	-- Hurt: stale sightings count, as before.
	T.eq(R.HardRetreatOutnumbered(1, 0, 2, 0.45, false, false), true, "alone at 45%, two last seen")
	T.eq(R.HardRetreatOutnumbered(2, 3, 3, 0.50, false, false), true, "2 vs 3 at 50%")
	-- Hurt but our side is stronger (Fu.WeAreStronger): keep fighting unless alone.
	T.eq(R.HardRetreatOutnumbered(2, 3, 3, 0.50, false, true), false, "2 vs 3 at 50%, stronger")
end)

-- RetreatRules.MeepoWeakBody(hp, hit by a hero, enemy heroes within 1200, Meepo bodies alive, rule already on).
T.test("meepo weak body: the cases from games 044-047 leave the fight", function()
	local R = rules()
	-- Game 046, 9:14: 14% HP in attack mode beside a full-HP body, Undying and Clinkz on him.
	T.eq(R.MeepoWeakBody(0.14, true, 2, 2, false), true, "game 046 t=554")
	-- Game 047, 31:28: 8% HP in attack mode, only Puck near, three bodies.
	T.eq(R.MeepoWeakBody(0.08, true, 1, 3, false), true, "game 047 t=1888")
	-- Game 047, 37:37: 34% HP in attack mode against five.
	T.eq(R.MeepoWeakBody(0.34, true, 5, 3, false), true, "game 047 t=2257")
	-- Under 25% with an enemy hero near, not hit in the last 2s: still leaves.
	T.eq(R.MeepoWeakBody(0.20, false, 1, 2, false), true, "20%, enemy near, not hit")
end)

T.test("meepo weak body: healthy, alone or safe bodies keep their mode", function()
	local R = rules()
	T.eq(R.MeepoWeakBody(0.55, true, 3, 3, false), false, "55% and hit: fight on")
	T.eq(R.MeepoWeakBody(0.35, false, 2, 3, false), false, "35%, nobody hitting it: not yet")
	T.eq(R.MeepoWeakBody(0.10, true, 0, 3, false), false, "no enemy hero within 1200")
	-- One body (before Divided We Stand): a normal hero, the usual retreat rules decide.
	T.eq(R.MeepoWeakBody(0.14, true, 2, 1, false), false, "lone body")
end)

T.test("meepo weak body: once on, it holds until 45% or no enemy near", function()
	local R = rules()
	-- Stepped out of range (no hit), 38%: without the hold it would go back to attack.
	T.eq(R.MeepoWeakBody(0.38, false, 1, 2, false), false, "38% not hit, rule off: does not start")
	T.eq(R.MeepoWeakBody(0.38, false, 1, 2, true), true, "38% not hit, rule on: holds")
	T.eq(R.MeepoWeakBody(0.44, false, 2, 3, true), true, "44%: holds")
	T.eq(R.MeepoWeakBody(0.46, true, 2, 3, true), false, "46%: released")
	T.eq(R.MeepoWeakBody(0.30, false, 0, 3, true), false, "enemies gone: released")
end)

T.test("meepo weak body: Poofs to the safe body nearest our fountain", function()
	local R = rules()
	local safeFar = { hp = 0.9, enemies = 0, dist = 3000, fountain = 6000 }
	local safeHome = { hp = 0.7, enemies = 0, dist = 5000, fountain = 2000 }
	T.eq(R.MeepoSafeBody({ safeFar, safeHome }), 2, "two safe bodies: the one nearer home")
	T.eq(R.MeepoSafeBody({ safeFar }), 1, "one safe body")
	T.eq(R.MeepoSafeBody({ { hp = 0.9, enemies = 1, dist = 3000, fountain = 2000 } }), nil, "enemy hero near it")
	T.eq(R.MeepoSafeBody({ { hp = 0.4, enemies = 0, dist = 3000, fountain = 2000 } }), nil, "under half HP")
	T.eq(R.MeepoSafeBody({ { hp = 0.9, enemies = 0, dist = 800, fountain = 2000 } }), nil, "in the same fight")
	T.eq(R.MeepoSafeBody({}), nil, "no other body")
end)
