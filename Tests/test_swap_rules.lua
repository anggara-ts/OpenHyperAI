-- #15: FuncLib/systems/swap_rules.lua (backpack pulls the engine undoes) and Item.PartsToBuy (a built part of a held
-- recipe is bought as its basic parts).
local T = ...

local function rules()
	T.stub.reset({ hero = "npc_dota_hero_lich" })
	return require(GetScriptDirectory() .. "/FuncLib/systems/swap_rules")
end

T.test("swap rules: Dust, Clarity or a lotus into an occupied main slot is an undone pull", function()
	local R = rules()
	-- Game 062 t=2016: Dazzle's Dust (slot 8) for a Headdress (slot 1), reverted 2s later.
	local pulled, occupant = R.UndonePull(8, "item_dust", 1, "item_headdress")
	T.eq(pulled, "item_dust", "dust pulled")
	T.eq(occupant, "item_headdress", "headdress in the main slot")
	-- The same swap with the slots the other way round.
	T.eq(R.UndonePull(2, "item_magic_wand", 7, "item_clarity"), "item_clarity", "clarity, slots reversed")
	T.eq(R.UndonePull(6, "item_famango", 5, "item_great_famango"), "item_famango", "lotus onto a lotus")
	-- An Observer Ward costs nothing and the Clarity still came back (two pull-checks).
	T.eq(R.UndonePull(6, "item_clarity", 0, "item_ward_observer"), "item_clarity", "clarity onto a ward")
end)

T.test("swap rules: pulls the engine keeps, and swaps of other items, are left alone", function()
	local R = rules()
	-- Every pull into an empty main slot stayed (game 049 t=2345 Tinker, game 054 t=800 Omniknight).
	T.eq(R.UndonePull(6, "item_famango", 3, nil), nil, "lotus into an empty slot")
	T.eq(R.UndonePull(7, "item_dust", 4, nil), nil, "dust into an empty slot")
	-- Items with their own rules.
	T.eq(R.UndonePull(6, "item_foragers_health", 1, "item_headdress"), nil, "forage mushroom")
	T.eq(R.UndonePull(6, "item_blood_grenade", 0, "item_tango"), nil, "grenade")
	T.eq(R.UndonePull(6, "item_roshans_banner", 2, "item_blink"), nil, "banner")
	-- Main to main and backpack to backpack.
	T.eq(R.UndonePull(1, "item_dust", 2, "item_magic_wand"), nil, "main to main")
	T.eq(R.UndonePull(6, "item_dust", 7, "item_clarity"), nil, "backpack to backpack")
	-- Parking a main item into the backpack is not a pull of the listed items.
	T.eq(R.UndonePull(1, "item_ward_observer", 6, "item_tango"), nil, "ward parked for a tango")
end)

T.test("purchase: a missing Urn for a held Spirit Vessel recipe is bought as its parts", function()
	T.stub.reset({ hero = "npc_dota_hero_chen", slot = 4 })
	local Item = require(GetScriptDirectory() .. "/FuncLib/systems/item")
	local parts = Item.PartsToBuy("item_urn_of_shadows")
	local seen = table.concat(parts, ",")
	local has = {}
	for _, part in ipairs(parts) do
		has[part] = true
	end
	-- 7.42 item_recipe_urn_of_shadows: Sobi Mask, Ring of Protection, Circlet, and the recipe.
	T.ok(not has.item_urn_of_shadows, "the Urn itself is not bought: " .. seen)
	T.ok(has.item_sobi_mask and has.item_ring_of_protection and has.item_circlet, "its parts are: " .. seen)
	T.eq(parts[#parts], "item_recipe_urn_of_shadows", "recipe last: " .. seen)
	-- A basic part stays as it is.
	local diadem = Item.PartsToBuy("item_diadem")
	T.eq(#diadem, 1, "one entry for a Diadem")
	T.eq(diadem[1], "item_diadem", "the Diadem")
end)
