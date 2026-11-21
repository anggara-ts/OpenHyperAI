-- Purchase rules (#15). Pure, no bot API calls, so Tests/test_buy_rules.lua can load them.
local BuyRules = {}

-- Plain Boots held beyond what the rest of the build turns into something (#15, game 063, 10:38: Shadow Fiend held
-- two pairs of Boots in his main slots; his build makes one pair into Boots of Travel). held: plain Boots the hero
-- holds (inventory, backpack, stash). planItems: the items still to buy, the current one included. partsOf(name):
-- the item's basic parts, the hero's own items not taken off. A Boots of Travel 2 next to a Boots of Travel in the plan
-- is made from that one, so it needs no Boots of its own. One pair is always kept.
-- Returns the number of extra pairs and the number the plan needs.
function BuyRules.ExtraBoots(held, planItems, partsOf)
	local planned = {}
	for _, name in ipairs(planItems or {}) do
		planned[name] = true
	end
	local needed = 0
	for _, name in ipairs(planItems or {}) do
		if name == "item_boots" then
			needed = needed + 1
		elseif not (name == "item_travel_boots_2" and planned.item_travel_boots) then
			for _, part in ipairs(partsOf(name) or {}) do
				if part == "item_boots" then
					needed = needed + 1
					break
				end
			end
		end
	end
	return math.max(0, (held or 0) - math.max(1, needed)), needed
end

-- The entries of wanted that queued does not cover yet, counted per name (#15). The rebuild of a stuck buy first
-- queues the missing parts of a held recipe, then adds the parts the whole item still needs. Game 065, 40:45: Dark
-- Willow held the Essence Distiller recipe, Chainmail and Wizard Hat but no Urn; the recipe step queued the Urn's four
-- parts and the second step appended the same four again (left=7), so she bought two Sobi Masks, two Rings of
-- Protection and two Urn recipes. queued: the parts already in the buy list. wanted: every part the item still needs
-- (Item.GetBasicItems of the item, the hero's own items taken off). Returns the parts to add, in wanted's order.
function BuyRules.BeyondQueued(queued, wanted)
	local have = {}
	for _, name in ipairs(queued or {}) do
		have[name] = (have[name] or 0) + 1
	end
	local add = {}
	for _, name in ipairs(wanted or {}) do
		if (have[name] or 0) > 0 then
			have[name] = have[name] - 1
		else
			add[#add + 1] = name
		end
	end
	return add
end

-- true when name is the item itself or any part of it at any depth, built parts included (#15). partsOf(item) gives
-- the item's direct parts or nil for a basic item. The old check walked basic parts only, so an Urn of Shadows held
-- for an Essence Distiller did not count as "still needed".
function BuyRules.IsPartOf(item, name, partsOf, depth)
	if item == name then
		return true
	end
	depth = depth or 0
	local parts = depth < 8 and partsOf(item) or nil
	if type(parts) ~= "table" then
		return false
	end
	for _, part in ipairs(parts) do
		if BuyRules.IsPartOf(part, name, partsOf, depth + 1) then
			return true
		end
	end
	return false
end

return BuyRules
