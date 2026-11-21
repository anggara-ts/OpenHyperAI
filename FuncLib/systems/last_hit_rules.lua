-- Pure rules for last-hit timing (#71, game 063: 105 got / 103 missed, 71 of the misses with no attack launched before
-- the creep died). No API calls: callers pass plain numbers and names, so Tests/test_last_hit_rules.lua checks them.
-- Used by Fu.GetAttackProDelayTime (turn time), FuncLib/systems/last_hit_timing.lua (wind-up release / cancel) and the
-- laning pickers (creep value, early start).
local LastHitRules = {}

-- Turning (maintainer 2026-11-21: "consider turning time when the hero is not facing the dying creep").
-- Liquipedia "Turn Rate" (Mechanics): turn rate is in radians per 0.03 seconds, so a turn of a radians takes
-- 0.03 * a / turnRate seconds (180 degrees at 0.6: 0.157s). The same page: a unit acts once the target is within 11.5
-- degrees in front of it (Valve's dev blog "Various pathfinding fixes", 2015); the page states it for moving and for
-- casting, not for attacks, so using it for attacks is an assumption (unverified). The page also says the turn
-- ramps up to the full rate, so this is a lower bound.
LastHitRules.TURN_TICK = 0.03
LastHitRules.FACING_TOLERANCE = 11.5
-- Turn rates from Valve's datafeed (https://www.dota2.com/datafeed/herodata?language=english&hero_id=N, field
-- turn_rate, read 2026-11-21 for all 127 heroes; the 7.42 npc_heroes MovementTurnRate values agree). Every hero not
-- listed has the base 0.6. Turn-rate slows (Sticky Napalm, Stone Gaze) are not counted.
LastHitRules.BASE_TURN_RATE = 0.6
LastHitRules.TURN_RATE = {
	npc_dota_hero_arc_warden = 0.7,
	npc_dota_hero_batrider = 0.9,
	npc_dota_hero_bristleback = 0.9,
	npc_dota_hero_dark_willow = 0.7,
	npc_dota_hero_dazzle = 0.7,
	npc_dota_hero_death_prophet = 0.8,
	npc_dota_hero_drow_ranger = 0.7,
	npc_dota_hero_earthshaker = 0.9,
	npc_dota_hero_ember_spirit = 0.8,
	npc_dota_hero_faceless_void = 0.9,
	npc_dota_hero_furion = 0.9,
	npc_dota_hero_hoodwink = 0.9,
	npc_dota_hero_jakiro = 0.8,
	npc_dota_hero_keeper_of_the_light = 0.7,
	npc_dota_hero_kez = 1.0,
	npc_dota_hero_largo = 0.7,
	npc_dota_hero_lich = 0.7,
	npc_dota_hero_life_stealer = 0.9,
	npc_dota_hero_magnataur = 0.8,
	npc_dota_hero_marci = 0.9,
	npc_dota_hero_mars = 0.8,
	npc_dota_hero_meepo = 0.9,
	npc_dota_hero_morphling = 0.7,
	npc_dota_hero_muerta = 0.7,
	npc_dota_hero_nevermore = 0.9,
	npc_dota_hero_oracle = 0.7,
	npc_dota_hero_pangolier = 0.9,
	npc_dota_hero_phantom_assassin = 0.8,
	npc_dota_hero_phoenix = 0.9,
	npc_dota_hero_puck = 0.9,
	npc_dota_hero_pudge = 0.7,
	npc_dota_hero_rubick = 0.7,
	npc_dota_hero_slark = 0.7,
	npc_dota_hero_sniper = 0.7,
	npc_dota_hero_storm_spirit = 0.8,
	npc_dota_hero_templar_assassin = 0.7,
	npc_dota_hero_terrorblade = 0.8,
	npc_dota_hero_tusk = 0.7,
	npc_dota_hero_void_spirit = 0.7,
	npc_dota_hero_windrunner = 0.8,
	npc_dota_hero_wisp = 0.7,
}

function LastHitRules.TurnRate(unitName)
	return LastHitRules.TURN_RATE[unitName] or LastHitRules.BASE_TURN_RATE
end

-- LuaJIT (the game) has math.atan2; Lua 5.3 (the local test runner) has math.atan(y, x).
local atan2 = math.atan2 or math.atan

-- Degrees (0..180) the unit has to turn: facing (GetFacing, degrees) against the direction dx, dy to the target.
function LastHitRules.TurnAngle(facingDeg, dx, dy)
	if dx == 0 and dy == 0 then
		return 0
	end
	local toTarget = math.deg(atan2(dy, dx))
	local diff = math.abs((toTarget - facingDeg) % 360)
	if diff > 180 then
		diff = 360 - diff
	end
	return diff
end

-- Seconds to turn angleDeg at turnRate, after the facing tolerance.
function LastHitRules.TurnTime(angleDeg, turnRate)
	local left = angleDeg - LastHitRules.FACING_TOLERANCE
	if left <= 0 or turnRate == nil or turnRate <= 0 then
		return 0
	end
	return LastHitRules.TURN_TICK * math.rad(left) / turnRate
end

-- Creep value (maintainer 2026-11-21: flagbearer first). Liquipedia "Lane Creeps": a flagbearer killed by an enemy
-- also gives its gold bounty to every enemy hero in an area around it, so the last hitter may get twice the gold;
-- that area gold is not granted when the creep is denied. Order: flagbearer > siege > ranged > melee. Unit names in
-- game 063: npc_dota_creep_goodguys_flagbearer, npc_dota_goodguys_siege (no "creep" in it), *_ranged*.
LastHitRules.KIND_VALUE = { flag = 4, siege = 3, ranged = 2, melee = 1 }

function LastHitRules.CreepKind(unitName)
	unitName = unitName or ""
	if string.find(unitName, "flagbearer", 1, true) then
		return "flag"
	end
	if string.find(unitName, "siege", 1, true) then
		return "siege"
	end
	if string.find(unitName, "ranged", 1, true) then
		return "ranged"
	end
	return "melee"
end

-- A creep that needs a walk-in counts this much less (distance still decides between a sure near creep and a far
-- valuable one): a far flagbearer (2.5) beats a near ranged (2) or melee creep, not a near siege creep (3).
LastHitRules.WALK_PENALTY = 1.5

-- Pick score: a sure kill beats any early start; then value, less the walk penalty.
function LastHitRules.PickScore(kind, sure, walk)
	return (sure and 10 or 0) + (LastHitRules.KIND_VALUE[kind] or 1) - (walk and LastHitRules.WALK_PENALTY or 0)
end

-- True when candidate (score, delay) beats the best so far; a tie goes to the hit that lands first.
function LastHitRules.BetterPick(score, delay, bestScore, bestDelay)
	if bestScore == nil then
		return true
	end
	if score ~= bestScore then
		return score > bestScore
	end
	return delay < (bestDelay or math.huge)
end

-- Early start (maintainer, game 063: "start attacking with extra buffer, e.g. 1.5 last hits"): the attack starts when
-- the creep's HP at the moment our hit would land is within 1.5 of our hits.
LastHitRules.EARLY_HITS = 1.5

-- predictedHp: the creep's HP when our hit lands, after every other hit counted to land before it (and its regen);
-- ourHit: our hit's damage on it (after armour); incomingKills: the other hits alone kill it first.
-- Returns "sure" (our hit kills it), "early" (within EARLY_HITS of our hits), or nil. The sure test is the one
-- Fu.WillKillTarget makes.
function LastHitRules.Classify(predictedHp, ourHit, incomingKills, allowEarly)
	if incomingKills or ourHit <= 0 then
		return nil
	end
	if ourHit > predictedHp then
		return "sure"
	end
	if allowEarly and ourHit * LastHitRules.EARLY_HITS > predictedHp then
		return "early"
	end
	return nil
end

-- An early start needs at least two looks inside the wind-up, or the hit is released before it can be checked.
-- pointTime: the wind-up in seconds (attack point / attack speed); frameGap: seconds between looks.
function LastHitRules.CanTimeWindup(pointTime, frameGap)
	return pointTime >= 2 * frameGap
end

-- Wind-up check, every look while our attack on the creep winds up. s = {
--   predictedHp, ourHit, incomingKills  as Classify, for the moment this hit lands;
--   remaining  seconds left to the attack point (may be negative when the release is late);
--   frameGap   seconds to the next look;
--   early      the attack started early (only those are ever cancelled: never a sure last hit, a deny or a harass hit);
-- }
-- Returns decision, reason:
--   "release", "kills"     our hit kills it: let it go (final);
--   "release", "others"    other hits kill it first: nothing to gain by stopping;
--   "wait", nil            not killable yet and another look comes before the attack point;
--   "cancel", "survives"   an early start that would not kill it, at the last look before the point;
--   "release", "sure"      a sure start that now looks short: kept (never cancelled), counted.
function LastHitRules.WindupDecision(s)
	if s.ourHit > s.predictedHp and not s.incomingKills then
		return "release", "kills"
	end
	if s.incomingKills then
		return "release", "others"
	end
	if s.remaining > s.frameGap * 1.5 + 0.02 then
		return "wait", nil
	end
	if s.early then
		return "cancel", "survives"
	end
	return "release", "sure"
end

-- After a cancel the bot holds (standing, facing the creep) and attacks again: at once when the hit is sure now,
-- early again while it has cancelled fewer than MAX_EARLY_RESTARTS times on this creep, else it waits.
LastHitRules.MAX_EARLY_RESTARTS = 3
function LastHitRules.RestartDecision(kind, cancels)
	if kind == "sure" then
		return "sure"
	end
	if kind == "early" and cancels < LastHitRules.MAX_EARLY_RESTARTS then
		return "early"
	end
	return "hold"
end

return LastHitRules
