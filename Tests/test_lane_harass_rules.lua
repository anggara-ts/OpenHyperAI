-- FuncLib/systems/lane_harass_rules.lua: when a ranged laner may hit an enemy hero and step back with fresh enemy
-- creeps near (#71). Arguments: attack range, HP ratio, fresh creeps, creeps hitting us, target safe (not by the
-- enemy T1), reset cooldown over.
local T = ...

local function rules()
	T.stub.reset({ hero = "npc_dota_hero_zuus" })
	return require(GetScriptDirectory() .. "/FuncLib/systems/lane_harass_rules")
end

T.test("harass reset: every ranged hero, not only range 400+", function()
	local R = rules()
	-- Game 059, Zeus t=113 / t=139 / t=336: range 365, HP 94% / 88% / 73%, one fresh creep, none hitting.
	T.eq(R.ResetBlock(365, 0.94, 1, 0, true, true), nil, "Zeus t=113")
	T.eq(R.ResetBlock(365, 0.73, 3, 0, true, true), "fresh", "Zeus t=336 had 3 fresh creeps")
	-- Weaver t=82 (range 425, 96%, 2 fresh) reset in game 059; still does.
	T.eq(R.ResetBlock(425, 0.96, 2, 0, true, true), nil, "Weaver t=82")
	-- Luna 330 is ranged; Templar Assassin's 250 is not counted as ranged here.
	T.eq(R.ResetBlock(330, 0.9, 1, 0, true, true), nil, "Luna")
	T.eq(R.ResetBlock(250, 0.9, 1, 0, true, true), "melee", "range 250")
end)

T.test("harass reset: the gates that still stop it", function()
	local R = rules()
	T.eq(R.ResetBlock(150, 1.0, 1, 0, true, true), "melee", "melee")
	T.eq(R.ResetBlock(600, 0.6, 1, 0, true, true), "hp", "60% HP is not over 60%")
	T.eq(R.ResetBlock(600, 0.9, 3, 0, true, true), "fresh", "three fresh creeps")
	T.eq(R.ResetBlock(600, 0.9, 1, 1, true, true), "hitting", "a creep already on us")
	T.eq(R.ResetBlock(600, 0.9, 1, 0, false, true), "tower", "target by the enemy T1")
	T.eq(R.ResetBlock(600, 0.9, 1, 0, true, false), "cooldown", "a reset less than 6s ago")
end)
