-- FuncLib/systems/lane_nuke_rules.lua: when a laning hero has spare mana for a last-hit nuke, and which creep
-- to pick. Numbers: Leshrac in lane without items (7.42 npc_heroes: StatusMana 75 in npc_dota_hero_base,
-- intelligence 22 + 3.5 per level; 12 mana per intelligence point is the engine's constant, not in the files;
-- npc_abilities: Lightning Storm 80/100/120/140 mana, Diabolic Edict 90/120/150/180).
local T = ...

local function rules()
	T.stub.reset({ hero = "npc_dota_hero_leshrac" })
	return require(GetScriptDirectory() .. "/FuncLib/systems/lane_nuke_rules")
end

T.test("spare mana: Leshrac at full mana in lane casts", function()
	local R = rules()
	-- Level 1: 339 max mana, Storm 1 (80), Edict not learned: keep one more Storm.
	T.eq(R.SpareManaForLastHit(339, 339, 80, 80), true, "level 1 full")
	-- Level 3 (game 062, 2:40): 423 max mana, Storm 2 (100) + Edict 1 (90) kept.
	T.eq(R.SpareManaForLastHit(423, 423, 100, 190), true, "level 3 full")
	T.eq(R.SpareManaForLastHit(400, 423, 100, 190), true, "level 3 at 95%")
	-- Level 5: 507 max mana, Storm 2 (100) + Edict 3 (150) kept.
	T.eq(R.SpareManaForLastHit(507, 507, 100, 250), true, "level 5 full")
end)

T.test("spare mana: keeps mana when not full", function()
	local R = rules()
	T.eq(R.SpareManaForLastHit(254, 423, 100, 190), false, "level 3 at 60%")
	T.eq(R.SpareManaForLastHit(370, 423, 100, 190), false, "level 3 at 87%")
	-- Right after a storm-lasthit at full mana (423 - 100): not again until it is near full.
	T.eq(R.SpareManaForLastHit(323, 423, 100, 190), false, "just cast")
end)

T.test("spare mana: keeps the fight reserve even when full", function()
	local R = rules()
	-- A small pool: casting would leave less than Storm + Edict for a fight.
	T.eq(R.SpareManaForLastHit(250, 250, 100, 190), false, "full but small pool")
	T.eq(R.SpareManaForLastHit(nil, 423, 100, 190), false, "no mana value")
	T.eq(R.SpareManaForLastHit(423, 0, 100, 190), false, "no max mana")
	T.eq(R.SpareManaForLastHit(423, 423, 0, 190), false, "no cost (not learned)")
end)

T.test("last-hit score: bounce kills first, then creeps the attack can't take", function()
	local R = rules()
	T.eq(R.LastHitScore(0, false), 0, "no kill")
	T.ok(R.LastHitScore(1, false) > R.LastHitScore(1, true), "one kill: a creep the attack can't take wins")
	T.ok(R.LastHitScore(2, true) > R.LastHitScore(1, false), "a bounce that kills two wins")
	T.ok(R.LastHitScore(1, true) > 0, "a creep the attack could take still counts")
end)
