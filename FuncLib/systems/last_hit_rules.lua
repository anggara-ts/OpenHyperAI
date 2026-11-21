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
--   backup     a support's backup hit behind its core: when the core's hit (or anything else) kills it first, the
--              swing is stopped ("cancel", "core") instead of released for nothing;
--   coreNext   (backup) the core can still take it first (BackupCoreNext): stopped too ("cancel", "core-next").
function LastHitRules.WindupDecision(s)
	if s.backup and (s.incomingKills or s.coreNext) then
		if s.remaining <= s.frameGap * 1.5 + 0.02 then
			return "cancel", s.incomingKills and "core" or "core-next"
		end
		return "wait", nil
	end
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

-- Backup last hits (maintainer, game 064: "lane supports still don't try to last hit; they must, with a delay slightly
-- longer than the carry, so that when the carry misses the support gets it"). A support next to its core lands its
-- hit BACKUP_MARGIN after the core's. b = {
--   coreKillsFirst  the core's pending hit (or anything else) kills the creep before ours lands;
--   coreState       what the core does about this creep (CORE_IN_PLAY: it can take it, so we land after it):
--                     attacking  swinging at it, or its own last-hit timing / team roam's overlay holds it (walking
--                                in, holding after a cancel, waiting for the moment);
--                     free       alive, laning (or a human), not on a hero, within BACKUP_CORE_NEAR of the creep;
--                     elsewhere  its timing / overlay holds another unit (it may still take this one: its hit time
--                                here is not known, so only a hit that kills counts);  busy  another mode or on a hero;
--                     far        farther than BACKUP_CORE_NEAR;
--   coreTooLate     the core's hit, started now, lands after the creep dies (CoreTooLate);
--   coreCanKill     the core's hit kills it when it lands (not killed by others first);
--   myDelay, coreEta  seconds until our hit / the core's hit would land if started now (walk and turn included);
--   ourKills        our hit kills it (after the core's pending hit, when the core is attacking);
-- }
-- Game 065: 17 of 37 backup releases landed before the core's hit (myEta <= coreEta), and Clinkz (42 -> 31 last hits
-- at 10:00) and Primal Beast (33 -> 27) lost farm to their supports: the support waited only for a core swinging at
-- the creep or whose hit killed it at once, so a core walking in, holding after a cancel or held by the overlay
-- counted as not there.
-- Returns decision, why: "core", "first" (leave it to the core); "wait", "behind" (the core takes it, or ours would
-- not land after the core's) or "hp" (our hit does not kill yet); "go", why (attack now): "behind" (the core's hit
-- does not kill it, ours lands BACKUP_MARGIN after it), "late" (the core's hit is too late), or the core's state
-- (busy / far: it cannot take it; elsewhere: its hit does not kill this one).
LastHitRules.BACKUP_MARGIN = 0.15
-- A core this close to the creep can take it (a walk-in of about one second at 300 movement speed; not a game value).
LastHitRules.BACKUP_CORE_NEAR = 700
LastHitRules.CORE_IN_PLAY = { attacking = true, free = true }
-- States where the core may still take the creep: CORE_IN_PLAY, and a core timing another creep (game 065 t=310 / 754:
-- Clinkz was in team roam overlay holds; when its hit kills this creep too, the support waits as for a free core).
LastHitRules.CORE_MAY_TAKE = { attacking = true, free = true, elsewhere = true }

-- The core's hit is too late: other hits already on their way kill the creep before it lands (othersKill), or the
-- creep's estimated death (DeathEta: our creeps and towers) comes clearly (BACKUP_MARGIN) before it.
function LastHitRules.CoreTooLate(othersKill, deathEta, coreEta)
	return othersKill or deathEta < coreEta - LastHitRules.BACKUP_MARGIN
end

-- True when the support must leave the creep to the core now: the core can take it in time, and either its hit kills
-- it (it is about to go, or it is going) or ours would not land BACKUP_MARGIN after the core's.
function LastHitRules.BackupBehindCore(b)
	if b.coreTooLate then
		return false
	end
	if b.coreState == "elsewhere" then
		return b.coreCanKill == true
	end
	return LastHitRules.CORE_IN_PLAY[b.coreState] == true
		and (b.coreCanKill == true or b.myDelay < b.coreEta + LastHitRules.BACKUP_MARGIN)
end

function LastHitRules.BackupDecision(b)
	if b.coreKillsFirst then
		return "core", "first"
	end
	if LastHitRules.BackupBehindCore(b) then
		return "wait", "behind"
	end
	if not b.ourKills then
		return "wait", "hp"
	end
	if LastHitRules.CORE_MAY_TAKE[b.coreState] and b.coreTooLate then
		return "go", "late"
	end
	if LastHitRules.CORE_IN_PLAY[b.coreState] then
		return "go", "behind"
	end
	return "go", b.coreState or "none"
end

-- A backup swing already winding up while the core (on this creep or free next to it, not one timing another creep)
-- can still take the creep in time and its hit kills it (game 065 t=634: Hoodwink released while Primal Beast's
-- overlay was swinging at the same creep, coreEta 0.59 against myEta 0.54). WindupDecision then stops it at the last
-- look ("core-next").
function LastHitRules.BackupCoreNext(b)
	return b.coreCanKill == true and LastHitRules.CORE_IN_PLAY[b.coreState] == true and LastHitRules.BackupBehindCore(b)
end

-- Walk-ins that cannot arrive (#71, game 064: late= rose from 71 to 137; 120 of them were walk-ins that never launched
-- an attack, and the planned hit time expect= was later than the creep's death took= in 33 of 50 core and 58 of 70
-- support walk-in misses). The sure / early test only counts the attacks already in flight or mid-swing, so on a long
-- walk the creeps' next swings are missing and the creep dies first. The death is estimated from the damage per second
-- of the units hitting the creep: hp is its HP less the hits already flying, dps the sum of each attacker's hit (after
-- armour) per its seconds per attack. math.huge when nothing hits it.
function LastHitRules.DeathEta(hp, dps)
	if hp <= 0 then
		return 0
	end
	if dps == nil or dps <= 0 then
		return math.huge
	end
	return hp / dps
end

-- A walk-in is not opened when our hit (expect: walk, turn, wind-up, flight) lands after the creep's estimated death.
function LastHitRules.WalkTooLate(expect, death)
	return expect > death
end

-- Supports deny first (#71, maintainer game 064), but a deny does not stop a last hit the per-frame timing is holding
-- (a wind-up being watched, holding after a cancel, a release decided) unless the denied creep is worth more
-- (KIND_VALUE: a flagbearer or siege deny over a melee last hit; the same kind: the last hit, it is our gold).
function LastHitRules.DenyBeatsTimedHit(denyKind, hitKind)
	return (LastHitRules.KIND_VALUE[denyKind] or 1) > (LastHitRules.KIND_VALUE[hitKind] or 1)
end

return LastHitRules
