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

return BuyRules
