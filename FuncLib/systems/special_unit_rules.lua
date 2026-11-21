-- Pure rules for FuncLib/hero/special_units.lua (#185): plain numbers in, so Tests/test_special_unit_rules.lua can
-- check them without the bot API.
local SpecialUnitRules = {}

local function remap(value, fromLow, fromHigh, toLow, toHigh)
	local ratio = (value - fromLow) / (fromHigh - fromLow)
	ratio = math.max(0, math.min(1, ratio))
	return toLow + (toHigh - toLow) * ratio
end

-- Undying's Tombstone. 7.42 (Valve datafeed hero_id=85 and npc_dota_hero_undying.txt in pak01_dir.vpk): pip health
-- tombstone_health / hits_to_destroy 5/6/7/8 (+4 talent), duration 30, radius 1200, a zombie next to every enemy in
-- the radius every 4/3.6/3.2/2.8s; zombies slow, Deathlust makes them faster on targets under 40% HP.
-- npc_units.txt: npc_dota_unit_tombstone1-4 StatusHealth 20/24/28/32, 4x the hit count. Which scale the bot API's
-- GetHealth reports is unverified, so: max health 20 or more reads 4 health per hero hit, less reads 1 (pips).
SpecialUnitRules.TOMBSTONE_RADIUS = 1200
SpecialUnitRules.TOMBSTONE_CLOSE = 600
SpecialUnitRules.TOMBSTONE_FEW_HITS = 3
SpecialUnitRules.TOMBSTONE_ALLIES = 2
SpecialUnitRules.TOMBSTONE_MIN_HP = 0.25
-- Attack mode tops out at 0.95 (games 064 / 065: 86 of the attack lines read 0.95, none higher).
SpecialUnitRules.TOMBSTONE_PRIORITY_DESIRE = 0.98
-- A bot slowed by the zombies hits a Tombstone this close that dies in TOMBSTONE_FEW_HITS hits instead of running.
SpecialUnitRules.TOMBSTONE_SLOW_HIT_RANGE = 400

function SpecialUnitRules.TombstoneHitsLeft(health, maxHealth)
	if health == nil or health <= 0 then
		return 0
	end
	local perHit = (maxHealth or 0) >= 20 and 4 or 1
	return math.ceil(health / perHit - 1e-6)
end

-- Kill the Tombstone first (above attack mode, no even-fight gate): close (TOMBSTONE_CLOSE), a few hits from dying
-- and inside its radius, or TOMBSTONE_ALLIES+ allied heroes inside its radius. Never while retreating or under
-- TOMBSTONE_MIN_HP. dist: bot to the Tombstone; alliesInRadius: allied heroes (the bot too) within the radius.
function SpecialUnitRules.TombstonePriority(dist, hitsLeft, alliesInRadius, retreating, hpRatio)
	if retreating or hpRatio < SpecialUnitRules.TOMBSTONE_MIN_HP then
		return false
	end
	return dist <= SpecialUnitRules.TOMBSTONE_CLOSE
		or hitsLeft <= SpecialUnitRules.TOMBSTONE_FEW_HITS and dist <= SpecialUnitRules.TOMBSTONE_RADIUS
		or alliesInRadius >= SpecialUnitRules.TOMBSTONE_ALLIES
end

-- The desire for the Tombstone and whether it is the priority case. Outside it the old rule: only when the fight is
-- even (alliesNear >= enemiesNear, heroes within 1600 of the bot) and not retreating; within attack range + 200 0.40
-- to 0.96 by the bot's HP, farther 0.56 (team roam then scales both by HP).
function SpecialUnitRules.TombstoneDesire(
	dist,
	attackRange,
	hitsLeft,
	alliesInRadius,
	alliesNear,
	enemiesNear,
	retreating,
	hpRatio
)
	if SpecialUnitRules.TombstonePriority(dist, hitsLeft, alliesInRadius, retreating, hpRatio) then
		return SpecialUnitRules.TOMBSTONE_PRIORITY_DESIRE, true
	end
	if alliesNear >= enemiesNear and not retreating then
		if dist <= attackRange + 200 then
			return remap(hpRatio, 0.25, 0.9, 0.4, 0.96), false
		end
		return 0.56, false
	end
	return 0, false
end

-- A zombie-slowed bot hits the Tombstone instead of running to the fountain.
function SpecialUnitRules.TombstoneHitWhenSlowed(dist, hitsLeft)
	return dist <= SpecialUnitRules.TOMBSTONE_SLOW_HIT_RANGE and hitsLeft <= SpecialUnitRules.TOMBSTONE_FEW_HITS
end

return SpecialUnitRules
