-- Shared bot system: item.
require(GetScriptDirectory() .. "/FuncLib/systems/global_overrides")
local Role = require(GetScriptDirectory() .. "/FuncLib/systems/role")
local Item = {}
local specifiedItemSet = {
	["item_tpscroll"] = true,
	["item_travel_boots"] = true,
	["item_travel_boots_2"] = true,
	["item_blink"] = true,
	["item_black_king_bar"] = true,
	["item_manta"] = true,
	["item_force_staff"] = true,
}
local sDebugItems = {
	"item_mango_tree",
	"item_arcane_ring",
	"item_royal_jelly",
	"item_trusty_shovel",
	"item_clumsy_net",
	"item_essence_ring",
	"item_repair_kit",
	"item_greater_faerie_fire",
	"item_flicker",
	"item_ninja_gear",
	"item_illusionsts_cape",
	"item_havoc_hammer",
	"item_minotaur_horn",
	"item_force_boots",
	"item_woodland_striders",
	"item_fallen_sky",
	"item_ex_machina",
	"item_abyssal_blade",
	"item_ancient_janggo",
	"item_armlet",
	"item_black_king_bar",
	"item_blade_mail",
	"item_blink",
	"item_bloodstone",
	"item_bloodthorn",
	"item_bottle",
	"item_crimson_guard",
	"item_cyclone",
	"item_dagon",
	"item_dagon_2",
	"item_dagon_3",
	"item_dagon_4",
	"item_dagon_5",
	"item_diffusal_blade",
	"item_enchanted_mango",
	"item_ethereal_blade",
	"item_flask",
	"item_force_staff",
	"item_ghost",
	"item_glimmer_cape",
	"item_guardian_greaves",
	"item_heavens_halberd",
	"item_helm_of_the_dominator",
	"item_hurricane_pike",
	"item_invis_sword",
	"item_lotus_orb",
	"item_manta",
	"item_mekansm",
	"item_meteor_hammer",
	"item_mjollnir",
	"item_moon_shard",
	"item_necronomicon",
	"item_necronomicon_2",
	"item_necronomicon_3",
	"item_nullifier",
	"item_orchid",
	"item_pipe",
	"item_refresher",
	"item_refresher_shard",
	"item_rod_of_atos",
	"item_satanic",
	"item_sheepstick",
	"item_shivas_guard",
	"item_silver_edge",
	"item_solar_crest",
	"item_sphere",
	"item_spirit_vessel",
	"item_tome_of_knowledge",
	"item_tpscroll",
	"item_urn_of_shadows",
	"item_veil_of_discord",
}
local function ToSet(list)
	local set = {}
	for _, value in pairs(list) do
		set[value] = true
	end
	return set
end
local debugItemSet = ToSet(sDebugItems)
Item["sBasicItems"] = {
	"item_aegis",
	"item_boots_of_elves",
	"item_belt_of_strength",
	"item_blade_of_alacrity",
	"item_blades_of_attack",
	"item_blight_stone",
	"item_blink",
	"item_boots",
	"item_bottle",
	"item_branches",
	"item_broadsword",
	"item_chainmail",
	"item_cheese",
	"item_circlet",
	"item_clarity",
	"item_claymore",
	"item_cloak",
	"item_crown",
	"item_demon_edge",
	"item_dust",
	"item_eagle",
	"item_enchanted_mango",
	"item_energy_booster",
	"item_faerie_fire",
	"item_flask",
	"item_gauntlets",
	"item_gem",
	"item_ghost",
	"item_gloves",
	"item_holy_locket",
	"item_hyperstone",
	"item_infused_raindrop",
	"item_javelin",
	"item_lifesteal",
	"item_magic_stick",
	"item_mantle",
	"item_mithril_hammer",
	"item_mystic_staff",
	"item_ogre_axe",
	"item_orb_of_frost",
	"item_platemail",
	"item_point_booster",
	"item_quarterstaff",
	"item_quelling_blade",
	"item_reaver",
	"item_refresher_shard",
	"item_ring_of_health",
	"item_ring_of_protection",
	"item_ring_of_regen",
	"item_robe",
	"item_relic",
	"item_sobi_mask",
	"item_shadow_amulet",
	"item_slippers",
	"item_smoke_of_deceit",
	"item_staff_of_wizardry",
	"item_talisman_of_evasion",
	"item_tango",
	"item_tango_single",
	"item_tome_of_knowledge",
	"item_tpscroll",
	"item_ultimate_orb",
	"item_vitality_booster",
	"item_void_stone",
	"item_wind_lace",
	"item_ward_observer",
	"item_ward_sentry",
	"item_blitz_knuckles",
	"item_voodoo_mask",
	"item_fluffy_hat",
	"item_blood_grenade",
	"item_wizard_hat",
	"item_chasm_stone",
	"item_splintmail",
	"item_shawl",
}
Item["sSeniorItems"] = {
	"item_arcane_boots",
	"item_buckler",
	"item_basher",
	"item_dagon",
	"item_dagon_2",
	"item_dagon_3",
	"item_dagon_4",
	"item_dragon_lance",
	"item_force_staff",
	"item_headdress",
	"item_invis_sword",
	"item_kaya",
	"item_lesser_crit",
	"item_maelstrom",
	"item_mekansm",
	"item_essence_distiller",
	"item_specialists_array",
	"item_ring_of_basilius",
	"item_sange",
	"item_soul_booster",
	"item_travel_boots",
	"item_urn_of_shadows",
	"item_vanguard",
	"item_yasha",
	"item_rod_of_atos",
	"item_blink",
	"item_cyclone",
	"item_helm_of_the_dominator",
	"item_rod_of_atos",
}
Item["sTopItems"] = {
	"item_clarity",
	"item_tango",
	"item_flask",
	"item_faerie_fire",
	"item_enchanted_mango",
	"item_infused_raindrop",
	"item_blood_grenade",
	"item_abyssal_blade",
	"item_aether_lens",
	"item_armlet",
	"item_assault",
	"item_ancient_janggo",
	"item_aeon_disk",
	"item_bfury",
	"item_black_king_bar",
	"item_blade_mail",
	"item_bloodstone",
	"item_bloodthorn",
	"item_bottle",
	"item_bracer",
	"item_butterfly",
	"item_crimson_guard",
	"item_dagon_5",
	"item_desolator",
	"item_diffusal_blade",
	"item_echo_sabre",
	"item_ethereal_blade",
	"item_gem",
	"item_glimmer_cape",
	"item_guardian_greaves",
	"item_greater_crit",
	"item_hand_of_midas",
	"item_heart",
	"item_heavens_halberd",
	"item_hurricane_pike",
	"item_holy_locket",
	"item_kaya_and_sange",
	"item_lotus_orb",
	"item_manta",
	"item_mask_of_madness",
	"item_mjollnir",
	"item_monkey_king_bar",
	"item_moon_shard",
	"item_meteor_hammer",
	"item_null_talisman",
	"item_nullifier",
	"item_orb_of_frost",
	"item_phase_boots",
	"item_pipe",
	"item_power_treads",
	"item_radiance",
	"item_rapier",
	"item_refresher",
	"item_sange_and_yasha",
	"item_satanic",
	"item_sheepstick",
	"item_sphere",
	"item_shivas_guard",
	"item_silver_edge",
	"item_solar_crest",
	"item_soul_ring",
	"item_skadi",
	"item_spirit_vessel",
	"item_tpscroll",
	"item_tranquil_boots",
	"item_travel_boots_2",
	"item_veil_of_discord",
	"item_vladmir",
	"item_wraith_band",
	"item_yasha_and_kaya",
	"item_revenants_brooch",
	"item_boots_of_bearing",
	"item_essence_distiller",
	"item_specialists_array",
	"item_hydras_breath",
	"item_consecrated_wraps",
	"item_crellas_crozier",
}
local topItemSet = ToSet(Item["sTopItems"])
Item["tEarlyItem"] = {
	"item_clarity",
	"item_faerie_fire",
	"item_tango",
	"item_flask",
	"item_infused_raindrop",
	"item_bracer",
	"item_wraith_band",
	"item_null_talisman",
	"item_bottle",
	"item_soul_ring",
	"item_refresher_shard",
	"item_cheese",
	"item_blood_grenade",
	"item_branches",
	"item_gauntlets",
	"item_slippers",
	"item_circlet",
	"item_mantle",
}
Item["tSupportSellWhenFull"] = {
	"item_magic_wand",
	"item_magic_stick",
	"item_bracer",
	"item_wraith_band",
	"item_null_talisman",
	"item_infused_raindrop",
	"item_soul_ring",
	"item_bottle",
	"item_orb_of_frost",
	"item_blood_grenade",
	"item_ring_of_basilius",
	"item_urn_of_shadows",
}
Item["tEarlyConsumableItem"] = {
	"item_clarity",
	"item_faerie_fire",
	"item_tango",
	"item_enchanted_mango",
	"item_flask",
	"item_infused_raindrop",
	"item_magic_stick",
	"item_quelling_blade",
	"item_branches",
	"item_blood_grenade",
	"item_gauntlets",
	"item_slippers",
	"item_circlet",
	"item_mantle",
	"item_magic_wand",
	"item_recipe_magic_wand",
	"item_magic_stick",
	"item_smoke_of_deceit",
}
Item["tEarlyBoots"] =
	{ "item_boots", "item_phase_boots", "item_power_treads", "item_tranquil_boots", "item_arcane_boots" }
Item["sCanNotSwitchItems"] = {
	"item_aegis",
	-- Swapped in from the backpack for a push; other swaps must not send it back.
	"item_roshans_banner",
	-- Game 032: every swap that would move a Ward Dispenser into the backpack was sent and had no
	-- effect (110 for Dust, 2 for the banner); wards are never the item moved out to make room.
	"item_ward_dispenser",
	"item_ward_observer",
	"item_ward_sentry",
	-- Swapped in to be eaten (game 032: Medusa's Vital Toadstool went back to the backpack).
	"item_foragers_health",
	"item_foragers_stats",
	"item_foragers_mana",
	"item_refresher_shard",
	"item_cheese",
	"item_bloodstone",
	"item_gem",
	"item_moon_shard",
	"item_black_king_bar",
	"item_famango",
	"item_great_famango",
	"item_greater_famango",
	-- A branch is a wand component. Parking it and pulling it back starts the backpack cooldown.
	"item_branches",
	-- Thrown from the main inventory only. Do not park it to make room for something else.
	"item_blood_grenade",
	-- Cast from a main slot only. Game 033: Witch Doctor and Shadow Shaman tried to swap a backpack
	-- Clarity in for their Dust every 6-13s from 7:21 to 33:39 (31 sent, none ever swapped back, so none took effect),
	-- and each one restarted the 11s swap gap for every other swap.
	"item_dust",
}
Item["sSellList"] = {
	"item_black_king_bar",
	"item_quelling_blade",
	"item_ultimate_scepter",
	"item_magic_wand",
	"item_cyclone",
	"item_magic_wand",
	"item_shivas_guard",
	"item_magic_wand",
	"item_lotus_orb",
	"item_quelling_blade",
	"item_assault",
	"item_magic_wand",
	"item_assault",
	"item_quelling_blade",
	"item_assault",
	"item_orb_of_corrosion",
	"item_travel_boots",
	"item_magic_wand",
	"item_travel_boots",
	"item_phase_boots",
	"item_travel_boots_2",
	"item_phase_boots",
	"item_travel_boots",
	"item_arcane_boots",
	"item_assault",
	"item_ancient_janggo",
	"item_vladmir",
	"item_magic_wand",
	"item_solar_crest",
	"item_pavise",
	"item_boots_of_bearing",
	"item_drum_of_endurance",
	"item_spirit_vessel",
	"item_urn_of_shadows",
	"item_magic_wand",
	"item_recipe_magic_wand",
	"item_splintmail",
	"item_chainmail",
	"item_wizard_hat",
	"item_circlet",
}
local canNotSwitchItemSet = ToSet(Item["sCanNotSwitchItems"])
local sConsumableItems = {
	"item_clarity",
	"item_tango",
	"item_flask",
	"item_faerie_fire",
	"item_enchanted_mango",
	"item_infused_raindrop",
	"item_blood_grenade",
	"item_mango_tree",
	"item_royal_jelly",
	"item_greater_faerie_fire",
	"item_repair_kit",
	"item_cheese",
	"item_refresher_shard",
	"item_aegis",
}
local consumableItemSet = ToSet(sConsumableItems)
local sNotSellItems = {
	"item_abyssal_blade",
	"item_assault",
	"item_black_king_bar",
	"item_bloodstone",
	"item_bloodthorn",
	"item_butterfly",
	"item_bfury",
	"item_cheese",
	"item_crimson_guard",
	"item_pipe",
	"item_dust",
	"item_gem",
	"item_greater_crit",
	"item_guardian_greaves",
	"item_heart",
	"item_heavens_halberd",
	"item_hyperstone",
	"item_manta",
	"item_hurricane_pike",
	"item_mjollnir",
	"item_nullifier",
	"item_octarine_core",
	"item_radiance",
	"item_rapier",
	"item_refresher",
	"item_refresher_shard",
	"item_satanic",
	"item_sheepstick",
	"item_shivas_guard",
	"item_silver_edge",
	"item_skadi",
	"item_sphere",
	"item_ultimate_scepter",
	"item_travel_boots",
	"item_travel_boots_2",
	"item_ward_observer",
}
local notSellItemSet = ToSet(sNotSellItems)
local smallItemSet = { ["item_tpscroll"] = 1, ["item_flask"] = 1, ["item_enchanted_mango"] = 1 }
function Item.GetComponentList(itemName)
	local components = {}
	local componentSets = GetItemComponents(itemName)
	if #componentSets == 0 then
		components = { itemName }
	else
		local firstComponentSet = componentSets[1]
		for _, component in pairs(firstComponentSet) do
			components[#components + 1] = component
		end
	end
	return components
end
local sCompositeItems = {
	"item_abyssal_blade",
	"item_aether_lens",
	"item_arcane_boots",
	"item_armlet",
	"item_assault",
	"item_ancient_janggo",
	"item_aeon_disk",
	"item_bfury",
	"item_black_king_bar",
	"item_blade_mail",
	"item_bloodstone",
	"item_bloodthorn",
	"item_bracer",
	"item_buckler",
	"item_butterfly",
	"item_basher",
	"item_crimson_guard",
	"item_cyclone",
	"item_dagon",
	"item_dagon_2",
	"item_dagon_3",
	"item_dagon_4",
	"item_dagon_5",
	"item_desolator",
	"item_diffusal_blade",
	"item_dragon_lance",
	"item_echo_sabre",
	"item_ethereal_blade",
	"item_force_staff",
	"item_glimmer_cape",
	"item_guardian_greaves",
	"item_greater_crit",
	"item_hand_of_midas",
	"item_headdress",
	"item_heart",
	"item_heavens_halberd",
	"item_helm_of_the_dominator",
	"item_hurricane_pike",
	"item_holy_locket",
	"item_invis_sword",
	"item_kaya",
	"item_kaya_and_sange",
	"item_lotus_orb",
	"item_lesser_crit",
	"item_maelstrom",
	"item_magic_wand",
	"item_manta",
	"item_mask_of_madness",
	"item_mekansm",
	"item_mjollnir",
	"item_monkey_king_bar",
	"item_moon_shard",
	"item_meteor_hammer",
	"item_necronomicon",
	"item_necronomicon_2",
	"item_necronomicon_3",
	"item_null_talisman",
	"item_nullifier",
	"item_oblivion_staff",
	"item_octarine_core",
	"item_orchid",
	"item_pers",
	"item_pipe",
	"item_radiance",
	"item_rapier",
	"item_refresher",
	"item_ring_of_basilius",
	"item_rod_of_atos",
	"item_sange",
	"item_sange_and_yasha",
	"item_satanic",
	"item_sheepstick",
	"item_sphere",
	"item_shivas_guard",
	"item_silver_edge",
	"item_solar_crest",
	"item_soul_booster",
	"item_soul_ring",
	"item_skadi",
	"item_spirit_vessel",
	"item_tranquil_boots",
	"item_travel_boots",
	"item_travel_boots_2",
	"item_urn_of_shadows",
	"item_ultimate_scepter_2",
	"item_vanguard",
	"item_veil_of_discord",
	"item_vladmir",
	"item_wraith_band",
	"item_yasha_and_kaya",
	"item_falcon_blade",
	"item_orb_of_corrosion",
	"item_witch_blade",
	"item_gungir",
	"item_mage_slayer",
	"item_helm_of_the_overlord",
	"item_overwhelming_blink",
	"item_swift_blink",
	"item_arcane_blink",
	"item_wind_waker",
	"item_revenants_brooch",
	"item_boots_of_bearing",
	"item_pavise",
	"item_phylactery",
	"item_harpoon",
	"item_disperser",
	"item_blood_grenade",
	"item_angels_demise",
	"item_devastator",
	"item_essence_distiller",
	"item_specialists_array",
	"item_hydras_breath",
	"item_consecrated_wraps",
	"item_crellas_crozier",
	"item_new_1",
	"item_new_2",
	"item_new_3",
	"item_new_4",
	"item_new_5",
	"item_new_6",
}
-- The engine lists some recipes ahead of their ingredients. Buy the ingredients first.
local function RecipesLast(parts)
	if type(parts) ~= "table" then
		return parts
	end
	local ordered = {}
	for _, part in ipairs(parts) do
		if not string.find(part, "item_recipe_", 1, true) then
			ordered[#ordered + 1] = part
		end
	end
	for _, part in ipairs(parts) do
		if string.find(part, "item_recipe_", 1, true) then
			ordered[#ordered + 1] = part
		end
	end
	return ordered
end
for _, itemName in pairs(sCompositeItems) do
	Item[itemName] = RecipesLast(GetItemComponents(itemName)[1])
end
-- Boots of Travel 2 is Boots of Travel plus the recipe again (the recipe name the game reported
-- for it in game 020's purchases). Spelled out so the planner keeps level 1 as a step toward it.
Item["item_travel_boots_2"] = { "item_travel_boots", "item_recipe_travel_boots" }
Item["item_phase_boots"] = { "item_blades_of_attack", "item_boots", "item_chainmail" }
Item["item_power_treads_agi"] = { "item_boots", "item_boots_of_elves", "item_gloves" }
Item["item_power_treads_int"] = { "item_boots", "item_robe", "item_gloves" }
Item["item_power_treads_str"] = { "item_boots", "item_belt_of_strength", "item_gloves" }
Item["item_power_treads"] = { "item_boots", "item_belt_of_strength", "item_gloves" }
Item["item_ultimate_scepter"] =
	{ "item_point_booster", "item_ogre_axe", "item_blade_of_alacrity", "item_staff_of_wizardry" }
-- Stick and two branches do not combine on their own. The recipe has to be bought
-- with them, before the build moves on to boots.
Item["item_magic_wand"] = { "item_magic_stick", "item_branches", "item_branches", "item_recipe_magic_wand" }
-- Claymore and Blades of Attack do not combine on their own.
Item["item_lesser_crit"] = { "item_claymore", "item_blades_of_attack", "item_recipe_lesser_crit" }
Item["item_yasha"] = { "item_boots_of_elves", "item_blade_of_alacrity", "item_recipe_yasha" }
local itemAliases = {
	["item_double_tango"] = "item_tango",
	["item_double_clarity"] = "item_clarity",
	["item_double_flask"] = "item_flask",
	["item_double_enchanted_mango"] = "item_enchanted_mango",
	["item_broken_satanic"] = "item_satanic",
	["item_power_treads_agi"] = "item_power_treads",
	["item_power_treads_int"] = "item_power_treads",
	["item_power_treads_str"] = "item_power_treads",
	["item_mid_outfit"] = "item_power_treads",
	["item_medusa_outfit"] = "item_power_treads",
	["item_templar_assassin_outfit"] = "item_power_treads",
	["item_ranged_carry_outfit"] = "item_power_treads",
	["item_melee_carry_outfit"] = "item_power_treads",
	["item_phantom_assassin_outfit"] = "item_power_treads",
	["item_juggernaut_outfit"] = "item_phase_boots",
	["item_huskar_outfit"] = "item_phase_boots",
	["item_sven_outfit"] = "item_phase_boots",
	["item_bristleback_outfit"] = "item_power_treads",
	["item_tank_outfit"] = "item_power_treads",
	["item_dragon_knight_outfit"] = "item_soul_ring",
	["item_mage_outfit"] = "item_tranquil_boots",
	["item_crystal_maiden_outfit"] = "item_magic_wand",
	["item_priest_outfit"] = "item_arcane_boots",
}
Item["item_double_branches"] = { "item_branches", "item_branches" }
-- Two Gauntlets as one build entry. Two separate "item_gauntlets" entries do not work: the
-- second reads as done as soon as the first is owned.
Item["item_double_gauntlets"] = { "item_gauntlets", "item_gauntlets" }
Item["item_double_tango"] = { "item_tango", "item_tango" }
Item["item_double_clarity"] = { "item_clarity", "item_clarity" }
Item["item_double_flask"] = { "item_flask", "item_flask" }
Item["item_double_enchanted_mango"] = { "item_enchanted_mango", "item_enchanted_mango" }
Item["item_double_circlet"] = { "item_circlet", "item_circlet" }
Item["item_double_slippers"] = { "item_slippers", "item_slippers" }
Item["item_double_mantle"] = { "item_mantle", "item_mantle" }
Item["item_double_gauntlets"] = { "item_gauntlets", "item_gauntlets" }
Item["item_double_wraith_band"] = { "item_wraith_band", "item_wraith_band" }
Item["item_double_null_talisman"] = { "item_null_talisman", "item_null_talisman" }
Item["item_double_bracer"] = { "item_bracer", "item_bracer" }
Item["item_double_crown"] = { "item_crown", "item_crown" }
Item["item_broken_hurricane_pike"] = { "item_force_staff", "item_recipe_hurricane_pike" }
Item["item_broken_silver_edge"] = { "item_blitz_knuckles", "item_broadsword", "item_recipe_silver_edge" }
Item["item_broken_bfury"] = { "item_ring_of_health", "item_void_stone", "item_broadsword", "item_claymore" }
Item["item_broken_satanic"] = { "item_reaver", "item_claymore" }
Item["item_broken_soul_ring"] = { "item_ring_of_protection", "item_recipe_soul_ring" }
Item["item_four_branches"] = { "item_branches", "item_branches", "item_branches", "item_branches" }
Item["item_six_branches"] =
	{ "item_branches", "item_branches", "item_branches", "item_branches", "item_branches", "item_branches" }
Item["item_mid_outfit"] = {
	"item_tango",
	"item_faerie_fire",
	"item_double_branches",
	"item_wraith_band",
	"item_flask",
	"item_magic_stick",
	"item_recipe_magic_wand",
	"item_power_treads_agi",
}
Item["item_medusa_outfit"] = {
	"item_null_talisman",
	"item_double_branches",
	"item_null_talisman",
	"item_null_talisman",
	"item_magic_stick",
	"item_recipe_magic_wand",
	"item_power_treads_int",
}
Item["item_templar_assassin_outfit"] = {
	"item_tango",
	"item_faerie_fire",
	"item_double_branches",
	"item_wraith_band",
	"item_flask",
	"item_magic_stick",
	"item_recipe_magic_wand",
	"item_power_treads_agi",
	"item_blight_stone",
}
Item["item_ranged_carry_outfit"] = {
	"item_tango",
	"item_flask",
	"item_double_branches",
	"item_slippers",
	"item_circlet",
	"item_magic_stick",
	"item_recipe_magic_wand",
	"item_recipe_wraith_band",
	"item_power_treads_agi",
	"item_infused_raindrop",
}
Item["item_melee_carry_outfit"] = {
	"item_tango",
	"item_flask",
	"item_quelling_blade",
	"item_double_branches",
	"item_circlet",
	"item_magic_stick",
	"item_slippers",
	"item_recipe_wraith_band",
	"item_recipe_magic_wand",
	"item_power_treads_agi",
}
Item["item_phantom_assassin_outfit"] = {
	"item_tango",
	"item_flask",
	"item_quelling_blade",
	"item_double_branches",
	"item_circlet",
	"item_magic_stick",
	"item_slippers",
	"item_recipe_wraith_band",
	"item_recipe_magic_wand",
	"item_power_treads_agi",
	"item_blight_stone",
}
Item["item_juggernaut_outfit"] = {
	"item_tango",
	"item_flask",
	"item_quelling_blade",
	"item_double_branches",
	"item_circlet",
	"item_magic_stick",
	"item_slippers",
	"item_recipe_wraith_band",
	"item_recipe_magic_wand",
	"item_phase_boots",
	"item_wraith_band",
}
Item["item_huskar_outfit"] = {
	"item_tango",
	"item_flask",
	"item_double_branches",
	"item_gauntlets",
	"item_circlet",
	"item_magic_stick",
	"item_recipe_magic_wand",
	"item_recipe_bracer",
	"item_boots",
	"item_bracer",
	"item_blades_of_attack",
	"item_chainmail",
}
Item["item_sven_outfit"] = {
	"item_tango",
	"item_flask",
	"item_quelling_blade",
	"item_double_branches",
	"item_circlet",
	"item_magic_stick",
	"item_gauntlets",
	"item_recipe_bracer",
	"item_recipe_magic_wand",
	"item_phase_boots",
}
Item["item_bristleback_outfit"] = {
	"item_tango",
	"item_flask",
	"item_quelling_blade",
	"item_double_branches",
	"item_circlet",
	"item_magic_stick",
	"item_gauntlets",
	"item_recipe_bracer",
	"item_recipe_magic_wand",
	"item_power_treads_str",
}
Item["item_tank_outfit"] = {
	"item_tango",
	"item_flask",
	"item_quelling_blade",
	"item_double_branches",
	"item_circlet",
	"item_magic_stick",
	"item_gauntlets",
	"item_recipe_bracer",
	"item_recipe_magic_wand",
	"item_power_treads_str",
}
Item["item_dragon_knight_outfit"] = {
	"item_tango",
	"item_flask",
	"item_quelling_blade",
	"item_double_branches",
	"item_gauntlets",
	"item_magic_stick",
	"item_recipe_magic_wand",
	"item_gauntlets",
	"item_power_treads_str",
	"item_broken_soul_ring",
}
Item["item_priest_outfit"] = {
	"item_tango",
	"item_tango",
	"item_branches",
	"item_magic_stick",
	"item_branches",
	"item_recipe_magic_wand",
	"item_arcane_boots",
	"item_flask",
	"item_urn_of_shadows",
}
Item["item_mage_outfit"] = {
	"item_tango",
	"item_tango",
	"item_double_branches",
	"item_circlet",
	"item_mantle",
	"item_magic_stick",
	"item_recipe_magic_wand",
	"item_recipe_null_talisman",
	"item_tranquil_boots",
	"item_flask",
}
Item["item_crystal_maiden_outfit"] = {
	"item_tango",
	"item_double_branches",
	"item_circlet",
	"item_mantle",
	"item_magic_stick",
	"item_recipe_magic_wand",
	"item_recipe_null_talisman",
	"item_arcane_boots",
	"item_flask",
}
Item["PvN_priest"] = {
	"item_tango",
	"item_flask",
	"item_bracer",
	"item_power_treads_int",
	"item_bracer",
	"item_ghost",
	"item_glimmer_cape",
	"item_aeon_disk",
	"item_cyclone",
	"item_sphere",
	"item_sheepstick",
	"item_moon_shard",
}
Item["PvN_mage"] = {
	"item_tango",
	"item_flask",
	"item_bracer",
	"item_power_treads_int",
	"item_bracer",
	"item_ghost",
	"item_glimmer_cape",
	"item_aeon_disk",
	"item_lotus_orb",
	"item_force_staff",
	"item_sheepstick",
	"item_moon_shard",
}
Item["PvN_melee_carry"] = {
	"item_tango",
	"item_flask",
	"item_quelling_blade",
	"item_wraith_band",
	"item_wraith_band",
	"item_power_treads_agi",
	"item_blade_mail",
	"item_heavens_halberd",
	"item_diffusal_blade",
	"item_travel_boots",
	"item_abyssal_blade",
	"item_moon_shard",
}
Item["PvN_str_carry"] = {
	"item_tango",
	"item_flask",
	"item_quelling_blade",
	"item_bracer",
	"item_bracer",
	"item_power_treads_str",
	"item_blade_mail",
	"item_heavens_halberd",
	"item_travel_boots",
	"item_abyssal_blade",
	"item_moon_shard",
}
Item["PvN_ranged_carry"] = {
	"item_tango",
	"item_flask",
	"item_wraith_band",
	"item_wraith_band",
	"item_power_treads_agi",
	"item_wraith_band",
	"item_dragon_lance",
	"item_ghost",
	"item_heavens_halberd",
	"item_travel_boots",
	"item_broken_hurricane_pike",
	"item_bloodthorn",
	"item_moon_shard",
	"item_travel_boots_2",
}
Item["PvN_tank"] = {
	"item_tango",
	"item_flask",
	"item_quelling_blade",
	"item_bracer",
	"item_bracer",
	"item_power_treads_str",
	"item_blade_mail",
	"item_crimson_guard",
	"item_heavens_halberd",
	"item_travel_boots",
	"item_assault",
	"item_moon_shard",
	"item_travel_boots_2",
}
Item["PvN_mid"] = {
	"item_tango",
	"item_flask",
	"item_wraith_band",
	"item_wraith_band",
	"item_power_treads_agi",
	"item_dragon_lance",
	"item_ghost",
	"item_heavens_halberd",
	"item_travel_boots",
	"item_broken_hurricane_pike",
	"item_bloodthorn",
	"item_moon_shard",
	"item_travel_boots_2",
}
Item["PvN_antimage"] = {
	"item_tango",
	"item_flask",
	"item_quelling_blade",
	"item_wraith_band",
	"item_wraith_band",
	"item_power_treads_agi",
	"item_blade_mail",
	"item_broken_bfury",
	"item_manta",
	"item_heavens_halberd",
	"item_travel_boots",
	"item_abyssal_blade",
	"item_skadi",
	"item_moon_shard",
	"item_travel_boots_2",
}
Item["PvN_huskar"] = {
	"item_tango",
	"item_flask",
	"item_bracer",
	"item_bracer",
	"item_bracer",
	"item_power_treads_agi",
	"item_dragon_lance",
	"item_blade_mail",
	"item_heavens_halberd",
	"item_travel_boots",
	"item_broken_hurricane_pike",
	"item_heart",
	"item_moon_shard",
	"item_travel_boots_2",
}
Item["PvN_clinkz"] = {
	"item_tango",
	"item_flask",
	"item_wraith_band",
	"item_wraith_band",
	"item_power_treads_agi",
	"item_dragon_lance",
	"item_blade_mail",
	"item_heavens_halberd",
	"item_travel_boots",
	"item_solar_crest",
	"item_broken_hurricane_pike",
	"item_bloodthorn",
	"item_moon_shard",
	"item_travel_boots_2",
}
Item["PvN_BH"] = {
	"item_tango",
	"item_flask",
	"item_wraith_band",
	"item_wraith_band",
	"item_power_treads_agi",
	"item_ghost",
	"item_heavens_halberd",
	"item_travel_boots",
	"item_solar_crest",
	"item_abyssal_blade",
	"item_bloodthorn",
	"item_moon_shard",
	"item_travel_boots_2",
}
Item["PvN_TA"] = {
	"item_tango",
	"item_flask",
	"item_wraith_band",
	"item_wraith_band",
	"item_power_treads_agi",
	"item_dragon_lance",
	"item_ghost",
	"item_heavens_halberd",
	"item_travel_boots",
	"item_desolator",
	"item_broken_hurricane_pike",
	"item_bloodthorn",
	"item_moon_shard",
	"item_travel_boots_2",
}
Item["PvN_PA"] = {
	"item_tango",
	"item_flask",
	"item_quelling_blade",
	"item_wraith_band",
	"item_wraith_band",
	"item_power_treads_agi",
	"item_blade_mail",
	"item_heavens_halberd",
	"item_travel_boots",
	"item_desolator",
	"item_abyssal_blade",
	"item_nullifier",
	"item_moon_shard",
	"item_travel_boots_2",
}
Item["PvN_PL"] = {
	"item_tango",
	"item_flask",
	"item_quelling_blade",
	"item_wraith_band",
	"item_wraith_band",
	"item_power_treads_agi",
	"item_diffusal_blade",
	"item_blade_mail",
	"item_manta",
	"item_heavens_halberd",
	"item_travel_boots",
	"item_abyssal_blade",
	"item_moon_shard",
	"item_travel_boots_2",
}
Item["PvN_OM"] = {
	"item_tango",
	"item_flask",
	"item_quelling_blade",
	"item_bracer",
	"item_bracer",
	"item_power_treads_int",
	"item_ghost",
	"item_hand_of_midas",
	"item_heavens_halberd",
	"item_travel_boots",
	"item_sheepstick",
	"item_moon_shard",
	"item_travel_boots_2",
}
function Item.IsConsumableItem(itemName)
	return consumableItemSet[itemName] == true
end
function Item.IsSmallItem(itemName)
	return smallItemSet[itemName] ~= nil
end
function Item.IsNeutralItem(itemName)
	return tNeutralItemLevelList[itemName] ~= nil
end
function Item.GetNeutralItemLevel(itemName)
	return tNeutralItemLevelList[itemName] or 0
end
function Item.GetMinTeamNeutralItemLevel()
	local minLevel = 999
	for i = 1, #GetTeamPlayers(GetTeam()) do
		local member = GetTeamMember(i)
		if member ~= nil then
			local neutralItem = member:GetItemInSlot(16)
			if neutralItem ~= nil then
				local neutralItemName = neutralItem:GetName()
				if Item.GetNeutralItemLevel(neutralItemName) < minLevel then
					minLevel = Item.GetNeutralItemLevel(neutralItemName)
				end
			else
				minLevel = 0
				break
			end
		end
	end
	return minLevel
end
function Item.GetInUseNeutralItemLevel(hero)
	local neutralItem = hero:GetItemInSlot(16)
	if neutralItem ~= nil then
		local neutralItemName = neutralItem:GetName()
		return Item.GetNeutralItemLevel(neutralItemName)
	end
	return 0
end
function Item.IsNotSellItem(itemName)
	return notSellItemSet[itemName] == true
end
function Item.IsCanNotSwitchItem(itemName)
	return canNotSwitchItemSet[itemName] == true
end
function Item.IsDebugItem(itemName)
	return debugItemSet[itemName] == true
end
function Item.IsSpecifiedItem(itemName)
	return specifiedItemSet[itemName] == true
end
function Item.IsTopItem(itemName)
	return topItemSet[itemName] == true
end
function Item.HasItem(hero, itemName)
	return hero:FindItemSlot(itemName) >= 0
end
function Item.HasItemWithName(hero, namePattern)
	for slot = 0, 8 do
		local item = hero:GetItemInSlot(slot)
		if item ~= nil then
			if string.find(item:GetName(), namePattern) then
				return true
			end
		end
	end
	return false
end
function Item.IsItemInHero(itemName)
	return Item.IsItemInTargetHero(itemName, GetBot())
end
function Item.IsItemInTargetHero(itemName, hero)
	if itemName == "item_double_flask" then
		return Item.IsItemInHero("item_flask")
	end
	if itemName == "item_flask" and GetItemStockCount("item_flask") == 0 then
		return true
	end
	if itemAliases[itemName] ~= nil then
		return Item.IsItemInHero(itemAliases[itemName])
	end
	if string.find(itemName, "item_double") ~= nil then
		return Item.GetItemCountInSolt(hero, string.gsub(itemName, "_double", ""), 0, 8) >= 2
	end
	if string.find(itemName, "PvN_") ~= nil then
		return Item.IsItemInHero("item_moon_shard")
	end
	if itemName == "item_ultimate_scepter" and hero:HasScepter() then
		return true
	end
	if itemName == "item_moon_shard" and hero:HasModifier("modifier_item_moon_shard_consumed") then
		return true
	end
	if itemName == "item_ultimate_scepter_2" then
		return hero:HasScepter() and hero:FindItemSlot("item_ultimate_scepter") < 0
	end
	local slot = hero:FindItemSlot(itemName)
	return slot >= 0 and (slot <= 8 or Item.IsTopItem(itemName))
end
-- Basic items still to buy for a list. Owned copies are counted, and each owned copy covers
-- one entry only, so a recipe that needs two of a part (Soul Ring: two Gauntlets) buys the
-- second one. The old single "last repeat item" flag was shared with every other call and
-- often lost, so a Techies with one Gauntlets got only the Soul Ring recipe.
function Item.GetBasicItems(itemList, owned)
	local bot = GetBot()
	owned = owned or {}
	local basicItems = {}
	for _, itemName in pairs(itemList) do
		if owned[itemName] == nil then
			if Item.IsItemInHero(itemName) then
				owned[itemName] = math.max(1, Item.GetItemCountInSolt(bot, itemName, 0, 8))
			else
				owned[itemName] = 0
			end
		end
		if owned[itemName] > 0 then
			owned[itemName] = owned[itemName] - 1
		elseif Item[itemName] ~= nil then
			for _, basicItem in pairs(Item.GetBasicItems(Item[itemName], owned)) do
				basicItems[#basicItems + 1] = basicItem
			end
		else
			basicItems[#basicItems + 1] = itemName
		end
	end
	return basicItems
end
function Item.GetMainInvLessValItemSlot(hero)
	local lowestCost = 10000
	local lowestSlot = -1
	for slot = 0, 5 do
		local item = hero:GetItemInSlot(slot)
		if item == nil then
			return slot
		end
		if item ~= nil and not Item.IsCanNotSwitchItem(item:GetName()) then
			local cost = GetItemCost(item:GetName())
			if cost < lowestCost then
				lowestCost = cost
				lowestSlot = slot
			end
		end
	end
	return lowestSlot
end
function Item.GetBodyInvLessValItemSlot(hero)
	local lowestCost = 10000
	local lowestSlot = -1
	for slot = 0, 8 do
		local item = hero:GetItemInSlot(slot)
		if item == nil then
			return slot, -1
		end
		if item ~= nil and not Item.IsCanNotSwitchItem(item:GetName()) then
			local cost = GetItemCost(item:GetName())
			if cost < lowestCost then
				lowestCost = cost
				lowestSlot = slot
			end
		end
	end
	return lowestSlot, lowestCost
end
function Item.GetItemCharges(hero, itemName)
	local charges = 0
	for slot = 0, 16 do
		local item = hero:GetItemInSlot(slot)
		if item ~= nil and item:GetName() == itemName then
			charges = charges + item:GetCurrentCharges()
		end
	end
	return charges
end
-- Observer and sentry wards merge into item_ward_dispenser. An exact-name
-- count then reads 0, so a support carrying both re-buys wards every tick.
-- Dispenser current charges are observers. Secondary charges are sentries.
function Item.GetWardCharges(hero, wardType)
	local charges = 0
	for slot = 0, 16 do
		local item = hero:GetItemInSlot(slot)
		if item ~= nil and item:GetName() == wardType then
			-- One ward often reports 0 charges, so a cap of 1 still bought a second.
			local currentCharges = item:GetCurrentCharges()
			charges = charges + ((currentCharges ~= nil and currentCharges > 0) and currentCharges or 1)
		elseif item ~= nil and item:GetName() == "item_ward_dispenser" then
			if wardType == "item_ward_observer" then
				charges = charges + item:GetCurrentCharges()
			else
				local ok, nSentry = pcall(function()
					return item:GetSecondaryCharges()
				end)
				charges = charges + ((ok and type(nSentry) == "number") and nSentry or 1)
			end
		end
	end
	return charges
end
function Item.GetNeutralItemCount(hero)
	local count = 0
	local slots = { 6, 7, 8, 16 }
	for _, slot in pairs(slots) do
		local item = hero:GetItemInSlot(slot)
		if item ~= nil then
			local itemName = item:GetName()
			if Item.IsNeutralItem(itemName) and not Item.IsConsumableItem(itemName) then
				count = count + 1
			end
		end
	end
	return count
end
local function CountEmptySlots(hero, firstSlot, lastSlot)
	local count = 0
	for slot = firstSlot, lastSlot do
		if hero:GetItemInSlot(slot) == nil then
			count = count + 1
		end
	end
	return count
end
function Item.GetEmptyInventoryAmount(hero)
	return CountEmptySlots(hero, 0, 8)
end
function Item.GetEmptyNonBackpackInventoryAmount(hero)
	return CountEmptySlots(hero, 0, 5)
end
-- Greater Healing Lotus (item_greater_famango) stacks up to 3 per slot.
Item.GREATER_FAMANGO = "item_greater_famango"
Item.GREATER_FAMANGO_MAX_STACK = 3
function Item.GetLotusCharges(item)
	if item == nil or item:IsNull() then
		return 0
	end
	local charges = item:GetCurrentCharges()
	if charges == nil or charges <= 0 then
		return 1
	end
	return charges
end
function Item.CollectGreaterFamangoStacks(bot)
	local stacks = {}
	if bot == nil then
		return stacks
	end
	for slot = 0, 8 do
		local item = bot:GetItemInSlot(slot)
		if item ~= nil and not item:IsNull() and item:GetName() == Item.GREATER_FAMANGO then
			stacks[#stacks + 1] = {
				slot = slot,
				item = item,
				charges = Item.GetLotusCharges(item),
			}
		end
	end
	return stacks
end
-- True if inventory has 2+ greater-famango piles that can merge (frees a slot).
function Item.CanStackGreaterFamango(bot)
	local stacks = Item.CollectGreaterFamangoStacks(bot)
	if #stacks < 2 then
		return false
	end
	for i = 1, #stacks do
		if stacks[i].charges < Item.GREATER_FAMANGO_MAX_STACK then
			return true
		end
	end
	return false
end
-- Drop a spare greater-famango so the next pick-up merges into an incomplete stack (max 3).
-- Returns true if a drop was issued (caller should pick up on a later think).
function Item.TryStackGreaterFamango(bot)
	if bot == nil or not Item.CanStackGreaterFamango(bot) then
		return false
	end
	local stacks = Item.CollectGreaterFamangoStacks(bot)
	local sink = nil
	for i = 1, #stacks do
		local stack = stacks[i]
		if stack.charges < Item.GREATER_FAMANGO_MAX_STACK then
			if sink == nil or stack.charges < sink.charges then
				sink = stack
			end
		end
	end
	if sink == nil then
		return false
	end
	local donor = nil
	for i = 1, #stacks do
		local stack = stacks[i]
		if stack.slot ~= sink.slot then
			donor = stack
			break
		end
	end
	if donor == nil or donor.item == nil then
		return false
	end
	bot:Action_DropItem(donor.item, bot:GetLocation())
	bot._lotusStackPickupUntil = DotaTime() + 3.0
	return true
end
-- After TryStackGreaterFamango drop: pick the ground greater back up to merge stacks.
function Item.TryPickupStackedGreaterFamango(bot)
	if bot == nil or bot._lotusStackPickupUntil == nil then
		return false
	end
	if DotaTime() > bot._lotusStackPickupUntil then
		bot._lotusStackPickupUntil = nil
		return false
	end
	local stacks = Item.CollectGreaterFamangoStacks(bot)
	local hasRoom = false
	for i = 1, #stacks do
		if stacks[i].charges < Item.GREATER_FAMANGO_MAX_STACK then
			hasRoom = true
			break
		end
	end
	if not hasRoom and Item.GetEmptyInventoryAmount(bot) <= 0 then
		bot._lotusStackPickupUntil = nil
		return false
	end
	for _, drop in pairs(GetDroppedItemList() or {}) do
		if drop ~= nil and drop.item ~= nil and drop.item:GetName() == Item.GREATER_FAMANGO then
			local dist = GetUnitToLocationDistance(bot, drop.location)
			if dist <= 400 then
				if dist > 100 then
					bot:Action_MoveToLocation(drop.location)
				else
					bot:Action_PickUpItem(drop.item)
					bot._lotusStackPickupUntil = nil
				end
				return true
			end
		end
	end
	return false
end
-- Prefer freeing a lotus that cannot stack further (full greater stack, or lower tiers).
function Item.FindLotusToFreeSlot(bot)
	if bot == nil then
		return nil, -1, nil
	end
	local prefer = {
		"item_famango",
		"item_great_famango",
		"item_greater_famango",
	}
	-- First pass: greater at max stack, then lower tiers.
	for pass = 1, 2 do
		for _, name in ipairs(prefer) do
			for slot = 0, 8 do
				local item = bot:GetItemInSlot(slot)
				if item ~= nil and not item:IsNull() and item:GetName() == name then
					if name == Item.GREATER_FAMANGO then
						local charges = Item.GetLotusCharges(item)
						if pass == 1 and charges >= Item.GREATER_FAMANGO_MAX_STACK then
							return name, slot, item
						end
						if pass == 2 then
							return name, slot, item
						end
					elseif pass == 1 then
						return name, slot, item
					end
				end
			end
		end
	end
	return nil, -1, nil
end
function Item.GetEmptyNeutralBackpackAmount(hero)
	return CountEmptySlots(hero, 6, 8) + (hero:GetItemInSlot(16) == nil and 1 or 0)
end
function Item.GetEmptyBackpackSlot(hero)
	for slot = 6, 8 do
		if hero:GetItemInSlot(slot) == nil then
			return slot
		end
	end
	return -1
end
function Item.GetItemCount(unit, itemName)
	return Item.GetItemCountInSolt(unit, itemName, 0, 16)
end
function Item.GetItemCountInSolt(unit, itemName, firstSlot, lastSlot)
	local count = 0
	for slot = firstSlot, lastSlot do
		local item = unit:GetItemInSlot(slot)
		if item ~= nil and item:GetName() == itemName then
			count = count + 1
		end
	end
	return count
end
function Item.HasBasicItem(hero)
	local slot = -1
	for i = 1, #Item["sBasicItems"] do
		slot = hero:FindItemSlot(Item["sBasicItems"][i])
		if slot >= 0 and slot <= 5 then
			return true
		end
	end
	return false
end
local function HasBootsInSlots(hero, lastSlot)
	for _, bootsName in pairs(Item["tEarlyBoots"]) do
		local slot = hero:FindItemSlot(bootsName)
		if slot >= 0 and slot <= lastSlot then
			return true
		end
	end
	return false
end
function Item.HasBuyBoots(hero)
	return HasBootsInSlots(hero, 16)
end
function Item.HasBootsInMainSolt(hero)
	return HasBootsInSlots(hero, 8)
end
function Item.GetItemTotalWorthInSlots(unit)
	local totalWorth = 0
	for slot = 0, 16 do
		local item = unit:GetItemInSlot(slot)
		if item ~= nil then
			totalWorth = totalWorth + GetItemCost(item:GetName())
		end
	end
	return totalWorth
end
function Item.GetTheItemSolt(hero, firstSlot, lastSlot, findMostExpensive)
	local bestCost = findMostExpensive and -9999 or 99999
	local bestSlot = -1
	for slot = firstSlot, lastSlot do
		local item = hero:GetItemInSlot(slot)
		if item ~= nil then
			local cost = GetItemCost(item:GetName())
			if findMostExpensive and cost > bestCost or not findMostExpensive and cost < bestCost then
				bestCost = cost
				bestSlot = slot
			end
		end
	end
	return bestSlot
end
function Item.GetOutfitType(hero)
	local outfitByPosition =
		{ [1] = "outfit_mid", [2] = "outfit_tank", [3] = "outfit_carry", [4] = "outfit_mage", [5] = "outfit_priest" }
	local teamPlayers = GetTeamPlayers(GetTeam())
	for i = 1, #GetTeamPlayers(GetTeam()) do
		local playerId = teamPlayers[i]
		if hero:GetPlayerID() == playerId then
			return outfitByPosition[i]
		end
	end
	return "outfit_carry"
end
function Item.GetRoleItemsBuyList(hero)
	return "pos_" .. tostring(Role.GetPosition(hero))
end
function Item.HasTargetItemCompositByItems(hero, purchaseList)
	local ownedComponents = {}
	for slot = 0, 8 do
		local item = hero:GetItemInSlot(slot)
		if item ~= nil then
			local basicItems = Item.GetBasicItems({ item:GetName() })
			local intersection, isSubset = Item.GetIntersection(purchaseList, basicItems)
			if isSubset then
				ownedComponents = Item.MergeLists(ownedComponents, intersection)
			end
		end
	end
	return ownedComponents
end
function Item.GetReducedPurchaseList(hero, purchaseList)
	local ownedComponents = Item.HasTargetItemCompositByItems(hero, purchaseList)
	return Item.RemoveIntersectedItems(purchaseList, ownedComponents)
end
function Item.GetIntersection(firstList, secondList)
	local firstSet = {}
	for _, itemName in ipairs(firstList) do
		firstSet[itemName] = true
	end
	local intersection = {}
	local isSubset = true
	for _, itemName in ipairs(secondList) do
		if firstSet[itemName] then
			table.insert(intersection, itemName)
		else
			isSubset = false
		end
	end
	return intersection, isSubset
end
function Item.MergeLists(firstList, secondList)
	local merged = {}
	for _, itemName in ipairs(firstList) do
		table.insert(merged, itemName)
	end
	for _, itemName in ipairs(secondList) do
		table.insert(merged, itemName)
	end
	return merged
end
function Item.RemoveIntersectedItems(firstList, secondList)
	local secondSet = {}
	for _, itemName in ipairs(secondList) do
		secondSet[itemName] = true
	end
	local remaining = {}
	for _, itemName in ipairs(firstList) do
		if not secondSet[itemName] then
			table.insert(remaining, itemName)
		end
	end
	return remaining
end
function Item.GetItemWardSolt()
	local bot = GetBot()
	local wardNames = { "item_ward_observer", "item_ward_sentry", "item_ward_dispenser" }
	for _, wardName in pairs(wardNames) do
		local slot = bot:FindItemSlot(wardName)
		if slot ~= -1 then
			return slot
		end
	end
	return -1
end
-- Aegis: a nearby human, then a core, then anyone else.
-- Roshan's Banner: a nearby support, then anyone else.
-- Cheese / Refresher Shard: a core with a free main slot, then a support with one, then anyone.
-- Game 034, 63:38: Roshan died, Phoenix took the Aegis and the Cheese (into his backpack, full
-- bag) and nobody took the Refresher Shard: these two were never claimed by anyone. A free main
-- slot matters: bot swaps do not take effect, so an item that lands in the backpack stays there.
function Item.RoshanClaimKind(name)
	if name == "item_aegis" then
		return "aegis"
	end
	if name == "item_roshans_banner" then
		return "banner"
	end
	if name == "item_cheese" or name == "item_refresher_shard" then
		return "consumable"
	end
	return nil
end
local function RoshanDropTier(hero, kind)
	local human = hero.IsBot ~= nil and not hero:IsBot()
	local pos = Role.GetPosition(hero) or 3
	if kind == "consumable" then
		if Item.GetEmptyNonBackpackInventoryAmount(hero) <= 0 then
			return 3
		end
		return pos <= 3 and 1 or 2
	end
	if kind == "aegis" then
		if human then
			return 1
		end
		if pos <= 3 then
			return 2
		end
		return 3
	end
	if pos >= 4 then
		return 1
	end
	return 2
end
local function RoshanDropCandidate(hero, itemName)
	if hero == nil or not hero:IsAlive() or not hero:IsHero() or hero:IsIllusion() then
		return false
	end
	if Item.HasItem(hero, itemName) then
		return false
	end
	return true
end
function Item.ShouldClaimRoshanDrop(bot, loc, itemName)
	local kind = Item.RoshanClaimKind(itemName)
	if kind == nil or loc == nil or not RoshanDropCandidate(bot, itemName) then
		return false
	end
	local tiers = (kind == "aegis" or kind == "consumable") and { 1, 2, 3 } or { 1, 2 }
	local function closest(tier, maxDist)
		local best, bestDist, bestId = nil, maxDist, math.huge
		local players = GetTeamPlayers(GetTeam())
		for i = 1, #players do
			local ally = GetTeamMember(i)
			if RoshanDropCandidate(ally, itemName) and RoshanDropTier(ally, kind) == tier then
				local dist = GetUnitToLocationDistance(ally, loc)
				local id = ally:GetPlayerID() or 99
				if dist <= bestDist and (dist < bestDist or id < bestId) then
					best = ally
					bestDist = dist
					bestId = id
				end
			end
		end
		return best
	end
	local function winner(maxDist)
		for tierIndex = 1, #tiers do
			local ally = closest(tiers[tierIndex], maxDist)
			if ally ~= nil then
				return ally
			end
		end
		return nil
	end
	-- Someone of a better tier within walking range keeps the claim. Otherwise it falls through.
	local ally = winner(4000) or winner(math.huge)
	return ally == bot
end
function Item.RoshanDropDesire(bot)
	for _, drop in pairs(GetDroppedItemList() or {}) do
		if drop ~= nil and drop.item ~= nil and not drop.item:IsNull() then
			local name = drop.item:GetName()
			if
				Item.RoshanClaimKind(name) ~= nil
				and Item.ShouldClaimRoshanDrop(bot, drop.location, name)
				and GetUnitToLocationDistance(bot, drop.location) <= 4500
			then
				return 0.97
			end
		end
	end
	return 0
end
function Item.TryPickupRoshanDrop(bot)
	if bot == nil or not bot:IsAlive() then
		return false
	end
	local best, bestDist = nil, math.huge
	for _, drop in pairs(GetDroppedItemList() or {}) do
		if drop ~= nil and drop.item ~= nil and not drop.item:IsNull() then
			local name = drop.item:GetName()
			if Item.RoshanClaimKind(name) ~= nil and Item.ShouldClaimRoshanDrop(bot, drop.location, name) then
				local dist = GetUnitToLocationDistance(bot, drop.location)
				if dist < bestDist then
					best = drop
					bestDist = dist
				end
			end
		end
	end
	if best == nil or bestDist > 4500 then
		-- Nothing left to claim: pick back up the item dropped to make room (20s, within 1500).
		local ret = bot._roshReturn
		if ret ~= nil then
			if DotaTime() - ret.at > 20 then
				bot._roshReturn = nil
				return false
			end
			for _, drop in pairs(GetDroppedItemList() or {}) do
				if drop ~= nil and drop.item ~= nil and not drop.item:IsNull() and drop.item:GetName() == ret.name then
					local distance = GetUnitToLocationDistance(bot, drop.location)
					if distance <= 1500 then
						if distance > 120 then
							bot:Action_MoveToLocation(drop.location)
						else
							bot:Action_PickUpItem(drop.item)
							bot._roshReturn = nil
						end
						return true
					end
				end
			end
			bot._roshReturn = nil
		end
		return false
	end
	if Item.GetEmptyNonBackpackInventoryAmount(bot) <= 0 then
		local cheap = Item.GetMainInvLessValItemSlot(bot)
		-- Bot swaps do not take effect (216 of 217 checked swaps did nothing), so moving the
		-- cheapest item to the backpack never made room. Drop it at his feet instead, pick up the
		-- Roshan item into the freed main slot, then pick the dropped item back up (it goes to the
		-- backpack). Game 021, 32:48: nobody took the Aegis, the claimant's bag was full.
		if cheap ~= nil and cheap >= 0 and bestDist <= 600 then
			local item = bot:GetItemInSlot(cheap)
			if item ~= nil then
				pcall(
					print,
					string.format(
						"[OHA-ROSH] t=%.0f %s %s-room dropped %s",
						DotaTime(),
						(string.gsub(bot:GetUnitName(), "npc_dota_hero_", "")),
						Item.RoshanClaimKind(best.item:GetName()) or "drop",
						(string.gsub(item:GetName(), "^item_", ""))
					)
				)
				bot._roshReturn = { name = item:GetName(), at = DotaTime() }
				bot:Action_DropItem(item, bot:GetLocation())
				return true
			end
		end
	end
	if bestDist > 120 then
		bot:Action_MoveToLocation(best.location)
	else
		bot:Action_PickUpItem(best.item)
	end
	return true
end
return Item
