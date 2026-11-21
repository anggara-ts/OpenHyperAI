-- #15: FuncLib/systems/buy_rules.lua (a second pair of plain Boots nothing in the build uses).
local T = ...

local function rules()
	T.stub.reset({ hero = "npc_dota_hero_nevermore" })
	return require(GetScriptDirectory() .. "/FuncLib/systems/buy_rules")
end

-- Basic parts as Item.GetBasicItems lists them with nothing owned.
local PARTS = {
	item_travel_boots = { "item_boots", "item_recipe_travel_boots" },
	item_travel_boots_2 = { "item_boots", "item_recipe_travel_boots", "item_recipe_travel_boots_2" },
	item_power_treads = { "item_boots", "item_gloves", "item_belt_of_strength" },
	item_yasha_and_kaya = { "item_blade_of_alacrity", "item_boots_of_elves", "item_recipe_yasha" },
	item_blink = { "item_blink" },
}
local function partsOf(name)
	return PARTS[name] or { name }
end

T.test("buy rules: Shadow Fiend's second Boots (game 063) is extra", function()
	local R = rules()
	-- His build after Boots: Blink, Yasha and Kaya, Boots of Travel. One pair goes into the Boots of Travel.
	local extra, needed = R.ExtraBoots(2, { "item_travel_boots", "item_yasha_and_kaya", "item_blink" }, partsOf)
	T.eq(extra, 1, "one pair extra")
	T.eq(needed, 1, "Boots of Travel needs one")
end)

T.test("buy rules: Boots the build still uses are kept", function()
	local R = rules()
	T.eq(R.ExtraBoots(1, { "item_travel_boots" }, partsOf), 0, "one pair held")
	-- Nothing left uses Boots: the pair on the feet stays.
	T.eq(R.ExtraBoots(1, { "item_blink" }, partsOf), 0, "the only pair")
	T.eq(R.ExtraBoots(2, { "item_blink" }, partsOf), 1, "two pairs, no upgrade left")
	-- Power Treads and Boots of Travel each take a pair.
	T.eq(R.ExtraBoots(2, { "item_travel_boots", "item_power_treads" }, partsOf), 0, "treads then travel")
	-- Boots of Travel 2 is made from the Boots of Travel before it, not from a new pair.
	local extra, needed = R.ExtraBoots(2, { "item_travel_boots_2", "item_travel_boots" }, partsOf)
	T.eq(needed, 1, "travel 2 after travel needs one pair")
	T.eq(extra, 1, "so the second pair is extra")
	T.eq(R.ExtraBoots(0, {}, partsOf), 0, "no boots")
end)
