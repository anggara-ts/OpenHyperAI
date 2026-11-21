-- FuncLib/systems/refresher_rules.lua: the mana a Refresher Orb / Shard refresh needs (#47).
local T = ...

local function rules()
	T.stub.reset({ hero = "npc_dota_hero_zuus" })
	return require(GetScriptDirectory() .. "/FuncLib/systems/refresher_rules")
end

T.test("refresher: the refresher's own cost counts with the recast", function()
	local R = rules()
	-- 7.42 game files: Orb 325 mana, Shard 200.
	T.eq(R.ManaNeeded(325, { 150 }), 475, "Orb + a 150-mana ultimate")
	T.eq(R.ManaNeeded(200, { 150 }), 350, "Shard + a 150-mana ultimate")
	T.eq(R.ManaNeeded(325, { 150, 100 }), 575, "Orb + ultimate + one more spell")
	T.eq(R.ManaNeeded(325, nil), 325, "no recast list")
end)

T.test("refresher: the old 2x-ultimate check let a refresh through that left no mana to recast", function()
	local R = rules()
	-- 300 mana, 150-mana ultimate: the old rule (mana >= 2 x 150) passed; after the 325-mana Orb nothing is left.
	T.eq(R.ManaOk(300, 325, { 150 }), false, "300 mana is not enough for Orb + ultimate")
	T.eq(R.ManaOk(475, 325, { 150 }), true, "475 mana is exactly enough")
	T.eq(R.ManaOk(400, 200, { 150 }), true, "the Shard is cheaper")
end)
