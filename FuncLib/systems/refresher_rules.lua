-- Refresher Orb / Refresher Shard: the mana a refresh needs (#47).
-- 7.42 game files (items.txt): item_refresher AbilityManaCost 325, cooldown 180; item_refresher_shard
-- AbilityManaCost 200, one charge. The refresh itself costs that mana, and the spell it brings back has to be
-- cast again after it, so the bot needs both: refresher cost + the cost of every spell it means to recast.
-- The old shared rule asked for 2x the ultimate's cost and left the refresher out: a 150-mana ultimate passed
-- with 300 mana, then the 325-mana Orb left too little to cast it again.
local RefresherRules = {}

-- refresherCost: the refresher's mana cost; recastCosts: a list of mana costs of the spells to cast again.
function RefresherRules.ManaNeeded(refresherCost, recastCosts)
	local total = refresherCost or 0
	for _, cost in ipairs(recastCosts or {}) do
		total = total + (cost or 0)
	end
	return total
end

function RefresherRules.ManaOk(mana, refresherCost, recastCosts)
	return (mana or 0) >= RefresherRules.ManaNeeded(refresherCost, recastCosts)
end

return RefresherRules
