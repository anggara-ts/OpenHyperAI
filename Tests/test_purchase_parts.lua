-- item_purchase_generic.lua buys every part an item needs, also a part the bot already holds one of (#38).
-- Game 055: Weaver held a Magic Stick and one Iron Branch, bought the Magic Wand recipe and never the second
-- Branch (7.42: Magic Wand = Magic Stick + 2 Iron Branches + recipe), so the Wand never formed.
local T = ...
local Stub = T.stub

-- Weaver pos 4 with her start kit in the bag (one Branch, a Magic Stick) and gold for the rest; runs the buy
-- think until it stops buying and returns what it bought.
local function buyAfterStart(held)
	local unit = Stub.reset({ hero = "npc_dota_hero_weaver", slot = 4 })
	local bag = {}
	local function newItem(name)
		return {
			GetName = function()
				return name
			end,
			IsNull = function()
				return false
			end,
			GetCurrentCharges = function()
				return 1
			end,
		}
	end
	for slot, name in ipairs(held) do
		bag[slot - 1] = newItem(name)
	end
	local bought = {}
	unit.GetItemInSlot = function(_, slot)
		return bag[slot]
	end
	unit.FindItemSlot = function(_, name)
		for slot = 0, 16 do
			if bag[slot] ~= nil and bag[slot]:GetName() == name then
				return slot
			end
		end
		return -1
	end
	unit.GetGold = function()
		return 5000
	end
	unit.ActionImmediate_PurchaseItem = function(_, name)
		bought[#bought + 1] = name
		for slot = 0, 8 do
			if bag[slot] == nil then
				bag[slot] = newItem(name)
				break
			end
		end
		return 0
	end
	local ok, err = Stub.load("item_purchase_generic")
	T.ok(ok, "item_purchase_generic loads: " .. tostring(err))
	for _ = 1, 60 do
		Stub.time = Stub.time + 1
		pcall(_G.ItemPurchaseThink)
	end
	return bought
end

T.test("purchase: a Magic Wand with one Branch held buys the second Branch before the recipe", function()
	local bought =
		buyAfterStart({ "item_tango", "item_blood_grenade", "item_branches", "item_circlet", "item_magic_stick" })
	local seen = table.concat(bought, ",")
	local branch, recipe = nil, nil
	for index, name in ipairs(bought) do
		if name == "item_branches" and branch == nil then
			branch = index
		end
		if name == "item_recipe_magic_wand" and recipe == nil then
			recipe = index
		end
	end
	T.ok(recipe ~= nil, "the recipe is bought: " .. seen)
	T.ok(branch ~= nil and branch < recipe, "a second Branch before the recipe: " .. seen)
end)
