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

-- Gives the stub bot these items in slots 0.. and a FindItemSlot that finds them.
local function hold(bot, names)
	for i, name in ipairs(names) do
		bot._items[i - 1] = T.stub.newAbility(name, bot)
	end
	bot.FindItemSlot = function(self, name)
		for slot = 0, 16 do
			local it = self._items[slot]
			if it ~= nil and it:GetName() == name then
				return slot
			end
		end
		return -1
	end
end

local function counts(list)
	local c = {}
	for _, name in ipairs(list) do
		c[name] = (c[name] or 0) + 1
	end
	return c
end

-- The rebuild of a stuck buy: the held recipe's missing parts first, then what the whole item still needs (#15).
local function rebuild(R, Item, target, queued)
	local wanted = Item.GetBasicItems({ target })
	local list = {}
	for i, part in ipairs(queued) do
		list[i] = part
	end
	for _, part in ipairs(R.BeyondQueued(list, wanted)) do
		table.insert(list, 1, part)
	end
	return list
end

T.test("buy rules: Dark Willow's Urn for the Essence Distiller is queued once (game 065)", function()
	local R = rules()
	local bot = T.stub.bot
	local Item = require(GetScriptDirectory() .. "/FuncLib/systems/item")
	-- 40:45: Chainmail, Wizard Hat and the Distiller recipe held, the Urn gone.
	hold(bot, { "item_chainmail", "item_wizard_hat", "item_recipe_essence_distiller" })
	-- The held-recipe step queued the Urn's parts (Item.PartsToBuy, recipe first in the list, bought last).
	local urnParts = Item.PartsToBuy("item_urn_of_shadows")
	local queued = {}
	for _, part in ipairs(urnParts) do
		table.insert(queued, 1, part)
	end
	local list = rebuild(R, Item, "item_essence_distiller", queued)
	local c = counts(list)
	T.eq(#list, 4, "four parts for one Urn: " .. table.concat(list, ","))
	T.eq(c.item_sobi_mask, 1, "one Sobi Mask")
	T.eq(c.item_ring_of_protection, 1, "one Ring of Protection")
	T.eq(c.item_circlet, 1, "one Circlet")
	T.eq(c.item_recipe_urn_of_shadows, 1, "one Urn recipe")
	T.eq(c.item_recipe_essence_distiller, nil, "the held Distiller recipe is not bought again")
end)

T.test("buy rules: a held Urn is not broken into parts again, only the missing Chainmail is queued", function()
	local R = rules()
	local bot = T.stub.bot
	local Item = require(GetScriptDirectory() .. "/FuncLib/systems/item")
	hold(bot, { "item_urn_of_shadows", "item_wizard_hat", "item_recipe_essence_distiller" })
	local list = rebuild(R, Item, "item_essence_distiller", { "item_chainmail" })
	T.eq(table.concat(list, ","), "item_chainmail", "Chainmail only")
	-- The old step (ref list less held items) queued the Urn's four parts here as well.
end)

T.test("buy rules: a held Wand recipe, Stick and one Branch still buys one Branch (#38 case)", function()
	local R = rules()
	local bot = T.stub.bot
	local Item = require(GetScriptDirectory() .. "/FuncLib/systems/item")
	hold(bot, { "item_magic_stick", "item_branches", "item_recipe_magic_wand" })
	-- The held-recipe step queued the second Branch.
	local list = rebuild(R, Item, "item_magic_wand", { "item_branches" })
	T.eq(table.concat(list, ","), "item_branches", "one Branch, not two")
	-- With nothing queued by that step the whole-item step adds it.
	T.eq(table.concat(rebuild(R, Item, "item_magic_wand", {}), ","), "item_branches", "the Branch from the item")
end)

T.test("buy rules: BeyondQueued counts per name", function()
	local R = rules()
	local add = R.BeyondQueued({ "a", "b" }, { "a", "a", "b", "c" })
	T.eq(table.concat(add, ","), "a,c", "one more a and the c")
	T.eq(#R.BeyondQueued({}, {}), 0, "nothing")
	T.eq(table.concat(R.BeyondQueued(nil, { "x" }), ","), "x", "nil queue")
end)

T.test("buy rules: IsPartOf sees built parts (an Urn inside the Essence Distiller)", function()
	local R = rules()
	local Item = require(GetScriptDirectory() .. "/FuncLib/systems/item")
	local function direct(name)
		return type(Item[name]) == "table" and Item[name] or nil
	end
	T.ok(R.IsPartOf("item_essence_distiller", "item_urn_of_shadows", direct), "the Urn")
	T.ok(R.IsPartOf("item_essence_distiller", "item_circlet", direct), "the Urn's Circlet")
	T.ok(R.IsPartOf("item_circlet", "item_circlet", direct), "the item itself")
	T.ok(not R.IsPartOf("item_essence_distiller", "item_magic_wand", direct), "not a Wand")
	T.ok(not R.IsPartOf("item_blink", "item_circlet", direct), "a basic item has no parts")
end)
