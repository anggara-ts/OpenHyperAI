-- Pure rules for Dark Willow's Shadow Realm (#48): plain numbers in, so Tests/test_shadow_realm_rules.lua can check
-- them without the bot API. Datafeed hero 119 (7.42): duration 5s, untargetable; the next attack has
-- attack_range_bonus 600 and up to damage 120/200/280/360 bonus magic damage, the maximum after
-- max_damage_duration 3s; that attack ends the realm. Cooldown 21/19/17/15.
local ShadowRealmRules = {}

ShadowRealmRules.DURATION = 5
ShadowRealmRules.MAX_DAMAGE_TIME = 3
-- 7.42 items_all.txt: item_tpscroll AbilityChannelTime 3.0.
ShadowRealmRules.TP_CHANNEL = 3.0

-- The bonus damage after `since` seconds in the realm. The tooltip says the damage "scales" with the time up to the
-- maximum at maxTime; linear from 0 is an assumption (no game file gives the curve).
function ShadowRealmRules.BonusDamage(maxDamage, since, maxTime)
	maxTime = maxTime or ShadowRealmRules.MAX_DAMAGE_TIME
	if maxTime <= 0 or since >= maxTime then
		return maxDamage
	end
	if since <= 0 then
		return 0
	end
	return maxDamage * since / maxTime
end

-- One think of the offensive hold. o: since (seconds in the realm), maxTime, dist (to the target), holdRange (her
-- attack range at the cast + the bonus), predictedDist (to where the target will be in 0.5s), canFollow (she is
-- faster than the target), killNow (the hit with the bonus so far kills it, or it dies to her allies anyway),
-- allyNeeds (an ally the target is hitting is low). Returns:
--   "attack", why: hit now (why = max | end | kill | ally | leave)
--   "close", nil:  step after the target (it is near the edge of the range or past it)
--   "hold", nil:   keep the range and wait for the damage to grow
function ShadowRealmRules.HoldStep(o)
	local maxTime = o.maxTime or ShadowRealmRules.MAX_DAMAGE_TIME
	if o.since >= maxTime then
		return "attack", "max"
	end
	-- Never let the realm run out without the hit (0.6s left: turn and attack).
	if o.since >= ShadowRealmRules.DURATION - 0.6 then
		return "attack", "end"
	end
	if o.killNow then
		return "attack", "kill"
	end
	if o.allyNeeds then
		return "attack", "ally"
	end
	if o.dist <= o.holdRange then
		-- About to walk out of the range and she can't keep up: hit while it is still in range.
		if o.predictedDist > o.holdRange - 25 and not o.canFollow then
			return "attack", "leave"
		end
		if o.dist > o.holdRange - 100 then
			return "close", nil
		end
		return "hold", nil
	end
	return "close", nil
end

-- A TP started now ends inside the realm (its time left covers the channel and a margin).
function ShadowRealmRules.TpFits(since, duration, channel, margin)
	duration = duration or ShadowRealmRules.DURATION
	channel = channel or ShadowRealmRules.TP_CHANNEL
	return duration - since >= channel + (margin or 0.3)
end

return ShadowRealmRules
