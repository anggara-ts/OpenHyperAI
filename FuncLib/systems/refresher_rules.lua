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

-- Which spells a refresh is for (maintainer, 2026-11-21, #47): learned, not passive, not a toggle, a cooldown of
-- MIN_COOLDOWN seconds or more, and not the refresher itself. Hidden slots and talents are not spells.
-- spell: { name, learned, passive, toggle, hidden, talent, cooldown, ultimate, ready, onCooldown, cost }
--   ready: castable now (off cooldown, enough mana); onCooldown: cooling down; cost: mana cost.
RefresherRules.MIN_COOLDOWN = 8
local REFRESHERS = { item_refresher = true, item_refresher_shard = true }
-- Movement spells are not what a refresh is for (#47, game 067 t=3818: Zeus held his Refresher 1s for a ready
-- Heavenly Jump). Spells whose main effect is moving the caster (names from the 7.42 hero files; Heavenly Jump also
-- shocks one enemy per the Valve datafeed, hero_id=22, but it is a jump). Neither waited for nor paid for.
RefresherRules.MOVEMENT = {
	antimage_blink = true,
	queenofpain_blink = true,
	zuus_heavenly_jump = true,
	mirana_leap = true,
	faceless_void_time_walk = true,
	puck_ethereal_jaunt = true,
	hoodwink_scurry = true,
	monkey_king_tree_dance = true,
}
function RefresherRules.IsUseful(spell)
	return spell ~= nil
		and spell.learned == true
		and not spell.passive
		and not spell.toggle
		and not spell.hidden
		and not spell.talent
		and (spell.cooldown or 0) >= RefresherRules.MIN_COOLDOWN
		and not REFRESHERS[spell.name or ""]
		and not RefresherRules.MOVEMENT[spell.name or ""]
end

-- The combo a refresh pays for: the useful spells (besides the ultimate) still ready, and the mana needed: the
-- refresher, the ultimate once, and every useful spell on cooldown (each cast again after the refresh). A ready
-- spell is not refreshed, so its mana is not counted. Returns othersReady (count), needed (mana), the names of the
-- ready spells and the names of the spells in the combo (ultimate first).
function RefresherRules.Combo(refresherCost, ultimateName, ultimateCost, spells)
	local othersReady, readyNames = 0, {}
	local recastCosts, comboNames = { ultimateCost or 0 }, { ultimateName or "ult" }
	for _, spell in ipairs(spells or {}) do
		if RefresherRules.IsUseful(spell) and not spell.ultimate and spell.name ~= ultimateName then
			if spell.ready then
				othersReady = othersReady + 1
				readyNames[#readyNames + 1] = spell.name
			elseif spell.onCooldown then
				recastCosts[#recastCosts + 1] = spell.cost or 0
				comboNames[#comboNames + 1] = spell.name
			end
		end
	end
	return othersReady, RefresherRules.ManaNeeded(refresherCost, recastCosts), readyNames, comboNames
end

-- Hold the refresh up to HOLD_FOR seconds while a useful spell is still ready, so the hero's own rules can cast it
-- first. state: per bot ({ holdAt }); a hold older than HOLD_STALE (a new fight) starts again. "hold" or "go";
-- also true when this step started the hold (for a once-per-hold log line).
RefresherRules.HOLD_FOR = 1.0
RefresherRules.HOLD_STALE = 5
function RefresherRules.HoldStep(state, now, othersReady)
	if othersReady <= 0 then
		return "go", false
	end
	local started = false
	if state.holdAt == nil or now - state.holdAt > RefresherRules.HOLD_STALE then
		state.holdAt = now
		started = true
	end
	if now - state.holdAt < RefresherRules.HOLD_FOR then
		return "hold", started
	end
	return "go", false
end

-- The refresh went out, or its conditions (enemies, fight, the ultimate's cooldown) lapsed: the next one holds again.
function RefresherRules.ResetHold(state)
	state.holdAt = nil
end

return RefresherRules
