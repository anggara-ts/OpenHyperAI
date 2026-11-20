-- Backpack swaps the engine undoes (#15). Pure rules, no bot API calls, so Tests/test_swap_rules.lua can load them.
--
-- Games 038-062: 1186 of 1205 checked pulls of Dust, a Clarity or a healing lotus from the backpack into an OCCUPIED main
-- slot were back in the backpack 2s later ([OHA-ITEM] pull-check result=reverted), and the engine already ignored
-- 216 of 217 swaps checked 0.5s later in games 008-012. The occupied main item made no difference (Magic Wand,
-- Tango, an Observer Ward, a Witch Blade) and neither did a fight (ok and ok-fight alike). Every pull into an EMPTY
-- main slot stayed ("swap 6(famango)<->3(-)", "swap 6(famango)<->4(-)", "swap 6(famango)<->1(-)"). The few
-- exchanges that stayed happened in the same second as an item combining (recipe bought, ward stack merged),
-- which frees a main slot. Each undone exchange still sent the main item through the backpack.
local SwapRules = {}

-- The backpack items whose pull was measured. Other items (Forager mushrooms, the Banner, the grenade) have their
-- own rules and are left to them.
SwapRules.PULL_NEEDS_EMPTY_SLOT = {
	item_dust = true,
	item_clarity = true,
	item_famango = true,
	item_great_famango = true,
	item_greater_famango = true,
}

-- Seconds the callers wait before trying the same pull again (they check bot._pullBackoff).
SwapRules.PULL_SKIP_BACKOFF = 15

local function IsMain(slot)
	return slot ~= nil and slot >= 0 and slot <= 5
end

local function IsBackpack(slot)
	return slot ~= nil and slot >= 6 and slot <= 8
end

-- The swap slotA<->slotB (with the item names in them, nil for an empty slot) pulls one of the measured items
-- from the backpack into an occupied main slot, which the engine undoes. Returns the pulled item's name and the
-- main item's name, or nil when the swap is fine.
function SwapRules.UndonePull(slotA, nameA, slotB, nameB)
	local packName, mainName
	if IsBackpack(slotA) and IsMain(slotB) then
		packName, mainName = nameA, nameB
	elseif IsBackpack(slotB) and IsMain(slotA) then
		packName, mainName = nameB, nameA
	else
		return nil
	end
	if packName == nil or mainName == nil or not SwapRules.PULL_NEEDS_EMPTY_SLOT[packName] then
		return nil
	end
	return packName, mainName
end

return SwapRules
