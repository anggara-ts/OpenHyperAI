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

-- Arguments: hp, creep hit, tower hit, can finish a hero, channeling, holding, creeps/tower still in reach.
T.test("creep-low: game 062 Weaver leaves the creep wave", function()
	local R = rules()
	-- t=1050: 13% HP, creeps hitting her, no enemy hero near.
	T.eq(R.CreepLowRetreat(0.13, true, false, false, false, false, true), true, "Weaver 13%, creep hit")
	-- A tower alone counts too.
	T.eq(R.CreepLowRetreat(0.20, false, true, false, false, false, true), true, "20%, tower hit")
end)

T.test("creep-low: stays when it should", function()
	local R = rules()
	-- Not hit by creeps or a tower: other rules decide.
	T.eq(R.CreepLowRetreat(0.10, false, false, false, false, false, true), false, "10%, not hit")
	-- Healthy enough: 30% (the rule starts under 25%).
	T.eq(R.CreepLowRetreat(0.30, true, false, false, false, false, true), false, "30%, creep hit")
	-- A hero in reach dies to the next hit: finish it.
	T.eq(R.CreepLowRetreat(0.15, true, false, true, false, false, true), false, "15%, kill to finish")
	-- Channeling (a TP home): don't cancel it.
	T.eq(R.CreepLowRetreat(0.15, true, false, false, true, false, true), false, "15%, channeling")
end)

T.test("creep-low: hold after it fired", function()
	local R = rules()
	-- Stepped away: the creep hit flag lapsed, creeps still in reach, 28%: keep retreating.
	T.eq(R.CreepLowRetreat(0.28, false, false, false, false, true, true), true, "held at 28%, creeps near")
	-- Out of creep reach: let go.
	T.eq(R.CreepLowRetreat(0.28, false, false, false, false, true, false), false, "held, nothing in reach")
	-- Healed past the release line (35%): let go.
	T.eq(R.CreepLowRetreat(0.40, true, false, false, false, true, true), false, "held, healed to 40%")
end)
