-- Shared bot system: pure rules of the item mode's desire (mode_item_generic.lua, #141), no bot API calls, so they
-- can be tested with plain numbers.
local ItemModeRules = {}

-- How far the bot looks: dropped items within 900 (about two seconds of walking), river rune spots within 400 (the
-- rune mode's river hold stands the bot within 200-300 of the spot, mode_rune_generic.lua RuneMode.WaterWalk).
ItemModeRules.ITEM_REACH = 900
ItemModeRules.RIVER_REACH = 400

-- Desire per target kind. Desires this has to fit between (this repo, game 062 log):
--   rune mode river hold 0.35 / 0.6 on the spot, laning up to ~0.6, farm ~0.66, hard retreat 0.7
--   (BOT_MODE_DESIRE_ABSOLUTE in global_overrides.lua), defend / retreat 0.77, attack 0.95, Roshan drops 0.97
--   (team roam, Item.RoshanDropDesire), team roam up to 1.5. Valve's own item mode took the river rune at 0.90.
-- River bounty / water rune the API shows on the spot 0.90: Valve's own item mode took it at about 0.90, and the rune
-- mode's walk back to an untaken river rune (#146, mode_rune_generic.lua) holds the spot at 0.60 and expects the item
-- mode to win there; 0.90 is above that and farm (0.66), below the rune mode's 0.92 pick-up test (1.5s once per
-- spawn). Fights and low HP are handled by Decide (outnumbered, below 30% HP: 0). River spawn window with the rune
-- not shown 0.68: above the 0.6 hold and laning, below a hard retreat, as the API may be wrong. Own drop 0.62: above laning, below farm and fights. Gem and Divine
-- Rapier 0.80: worth more than a defend walk, still below a fight. Aegis / Cheese / Refresher Shard 0.80 only for
-- the bot the Roshan claim picks (team roam already returns 0.97 for it, this is the fallback).
ItemModeRules.DESIRE = {
	["river-bounty"] = 0.90,
	["river-water"] = 0.90,
	["river-spawn"] = 0.68,
	["own-drop"] = 0.62,
	gem = 0.80,
	rapier = 0.80,
	aegis = 0.80,
	cheese = 0.80,
	["refresher-shard"] = 0.80,
}

-- Kinds for items on the ground any bot may take, whoever dropped them (Aegis, Cheese, Refresher Shard only when
-- the Roshan claim picks this bot: the caller checks).
ItemModeRules.VALUABLE = {
	item_gem = "gem",
	item_rapier = "rapier",
	item_aegis = "aegis",
	item_cheese = "cheese",
	item_refresher_shard = "refresher-shard",
}

-- candidates: list of { kind = <DESIRE key or "foreign">, dist = number, item = true for dropped items }
-- ctx: { hp = ratio, retreating = bool, outnumbered = bool (enemies > allies, for items),
--        riverOutnumbered = bool (enemies > allies + 1, for river runes) }
-- Returns desire, why, index of the chosen candidate (nil when the desire is 0).
-- Another player's item that is the nearest dropped item within reach stops it: Valve's item Think picks its own
-- target and would walk to that one (game 062: Medusa and Nyx Assassin ended up with Nature's Prophet's mushrooms).
function ItemModeRules.Decide(candidates, ctx)
	if ctx.hp < 0.3 or ctx.retreating then
		return 0, "unsafe", nil
	end
	local nearestItem, nearestDist = nil, math.huge
	for i, cand in ipairs(candidates) do
		if cand.item and cand.dist <= ItemModeRules.ITEM_REACH and cand.dist < nearestDist then
			nearestItem, nearestDist = i, cand.dist
		end
	end
	if nearestItem ~= nil and candidates[nearestItem].kind == "foreign" then
		return 0, "foreign-nearest", nearestItem
	end
	-- Outnumbered: no walk to an item. A river rune keeps the rune mode's own rule (RuneMode.WaterWalk holds the spot
	-- while enemies <= allies + 1 near it), so the item mode doesn't refuse a spot the rune mode holds.
	local best, bestDesire, bestDist = nil, 0, math.huge
	local blocked = false
	for i, cand in ipairs(candidates) do
		local desire = ItemModeRules.DESIRE[cand.kind] or 0
		local reach = cand.item and ItemModeRules.ITEM_REACH or ItemModeRules.RIVER_REACH
		local unsafe = cand.item and ctx.outnumbered or not cand.item and ctx.riverOutnumbered
		if desire > 0 and cand.dist <= reach and unsafe then
			blocked = true
		elseif
			desire > 0
			and cand.dist <= reach
			and (desire > bestDesire or desire == bestDesire and cand.dist < bestDist)
		then
			best, bestDesire, bestDist = i, desire, cand.dist
		end
	end
	if best == nil then
		return 0, blocked and "outnumbered" or "none", nil
	end
	return bestDesire, candidates[best].kind, best
end

-- River rune spawn times where the API may not show the rune (mode_rune_generic.lua WATER_AT: the bounty at the
-- horn, water runes at 2:00 and 4:00; game 031, a water rune lying on the spot read "missing"). Returns the spawn
-- time when now is within 8s after one, else nil.
ItemModeRules.RIVER_SPAWNS = { 0, 120, 240 }
function ItemModeRules.RiverSpawnWindow(now)
	for _, spawnTime in ipairs(ItemModeRules.RIVER_SPAWNS) do
		if now >= spawnTime and now <= spawnTime + 8 then
			return spawnTime
		end
	end
	return nil
end

return ItemModeRules
