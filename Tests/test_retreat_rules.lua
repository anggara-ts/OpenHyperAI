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
