-- Shared bot system: pure kiting rules (no bot API calls), so they can be tested with plain numbers (#72).
-- Used by FuncLib/hero/special_units.lua (X.TryKite, X.TryKiteAny).
local KiteRules = {}

-- Seconds added on both sides of the safe window, see KiteRules.Window.
KiteRules.BUF = 0.1
-- A ranged bot kites; a melee attacker is what it kites from (Dota's melee heroes have 150-300 range).
KiteRules.MELEE_RANGE = 320
-- Longest and shortest step. Shorter than 60 is not worth an order; 250 is the step used since #43.
KiteRules.MAX_STEP = 250
KiteRules.MIN_STEP = 60
-- The step ends at least this far inside our attack range of the target, so the next attack needs no walk back.
KiteRules.RANGE_MARGIN = 30
-- The chase step (a step toward a hero running out of range) is off: in games 065 and 067 the target was in range at
-- the next attack after 5 of 23 and 4 of 19 steps, against 2 of 6 and 4 of 12 without a step, so stepping did not
-- help (#72 tracker item 8, decided in advance: "if it still does not beat no-step, drop the chase step"). The
-- outnumbered skip, stepping away from melee units and the kite steps stay. true turns it back on.
KiteRules.CHASE_STEP_ON = false

-- The safe window between two attacks, in seconds since the last attack. It is not known whether
-- GetLastAttackTime is the start of the attack or the moment it is released, so the window assumes the worst
-- of both:
--   from  point + BUF          (wind-up surely over even if "last" is the start)
--   until spa - point - BUF    (next wind-up can start even if "last" is the release)
-- point = attack point / attack speed (as combat.lua GetAttackProDelayTime), at least 0.25s.
function KiteRules.Window(secondsPerAttack, attackPoint, attackSpeed)
	local point = math.max(attackPoint / math.max(attackSpeed, 0.1), 0.25)
	return point + KiteRules.BUF, secondsPerAttack - point - KiteRules.BUF
end

-- Too fast to kite (maintainer, #96: with Strafe, Mask of Madness or Hurricane Pike stepping only costs attacks):
-- the gap must be at least 0.35s and long enough to walk 100+ units at the hero's speed.
function KiteRules.TooFast(from, to, moveSpeed)
	local gap = to - from
	return gap < 0.35 or gap * math.max(1, moveSpeed) < 100, gap
end

function KiteRules.InWindow(since, from, to)
	return since >= from and since <= to
end

-- How far to step from the bot (bx, by) straight away from the attacker (ax, ay) while the bot's attack target
-- (tx, ty) stays within range - RANGE_MARGIN. Returns the step length (MIN_STEP..MAX_STEP) and the end point, or
-- nil when no step of at least MIN_STEP keeps the target in range. When the attacker is the target this is the
-- old rule min(250, range - dist - 30).
-- Solves |B + s*u - T| <= R for the largest s, u the unit vector from the attacker to the bot:
--   s^2 + 2 s (P.u) + |P|^2 - R^2 <= 0,  P = B - T.
function KiteRules.Step(bx, by, ax, ay, tx, ty, range)
	local ux, uy = bx - ax, by - ay
	local len = math.sqrt(ux * ux + uy * uy)
	if len < 1 then
		return nil
	end
	ux, uy = ux / len, uy / len
	local reach = range - KiteRules.RANGE_MARGIN
	if reach <= 0 then
		return nil
	end
	local px, py = bx - tx, by - ty
	local pu = px * ux + py * uy
	local disc = pu * pu - (px * px + py * py) + reach * reach
	if disc < 0 then
		return nil
	end
	local root = math.sqrt(disc)
	local low, high = -pu - root, -pu + root
	local step = math.min(KiteRules.MAX_STEP, high)
	if step < KiteRules.MIN_STEP or step < low then
		return nil
	end
	return step, bx + ux * step, by + uy * step
end

-- Laning (#72): a last hit is due when the creep's HP, minus what others will deal to it by the time the step and
-- our next attack are over, is within one hit of ours. Then the bot keeps its attack order instead of stepping.
--   hp            the creep's HP now
--   ourHit        what our attack deals to it (after armour)
--   othersDamage  damage the creep takes from others within that time (Fu.GetTotalAttackWillRealDamage)
function KiteRules.LastHitDue(hp, ourHit, othersDamage)
	return hp > 0 and hp - othersDamage <= ourHit
end

-- Seconds the step takes at the bot's movement speed (at least 100, so a slowed bot gives a finite time).
function KiteRules.StepSeconds(step, moveSpeed)
	return step / math.max(100, moveSpeed)
end

-- Chase (#72, maintainer 2026-11-21: "does kite also move forward to chase running enemy?" - "yes please"): the
-- attack target is an enemy hero getting farther away. Between attacks the bot steps toward where the hero will be
-- at our next attack, so the next attack needs no walk.
--   (bx, by)  the bot          (tx, ty)  the target now
--   (px, py)  the target at our next attack (its extrapolated location)
-- Returns the step (MIN_STEP..MAX_STEP) and its end point, or nil and why not:
--   "in-range"  it is within range - RANGE_MARGIN now (game 064 t=2444: Zeus stepped 250 toward Death Prophet at
--               193, already in range), or stays within it anyway
--   "not-away"  it does not get CHASE_AWAY_MIN farther by then (standing, coming at us, circling)
--   "far"       already CHASE_FAR past our range now: the mode walks after it, a step does not keep it in range
KiteRules.CHASE_AWAY_MIN = 20
KiteRules.CHASE_FAR = 200
function KiteRules.ChaseStep(bx, by, tx, ty, px, py, range)
	local nowX, nowY = tx - bx, ty - by
	local nextX, nextY = px - bx, py - by
	local distNow = math.sqrt(nowX * nowX + nowY * nowY)
	local distNext = math.sqrt(nextX * nextX + nextY * nextY)
	local reach = range - KiteRules.RANGE_MARGIN
	if distNow > range + KiteRules.CHASE_FAR then
		return nil, nil, nil, "far"
	end
	if distNow <= reach then
		return nil, nil, nil, "in-range"
	end
	if distNext < distNow + KiteRules.CHASE_AWAY_MIN then
		return nil, nil, nil, "not-away"
	end
	local need = distNext - reach
	if need <= 0 then
		return nil, nil, nil, "in-range"
	end
	local step = math.max(KiteRules.MIN_STEP, math.min(KiteRules.MAX_STEP, need))
	return step, bx + nextX / distNext * step, by + nextY / distNext * step
end

-- A chase step that ends before our next wind-up can start (#72, game 065: in 9 of 23 chase steps no attack of ours came
-- before the check; a 250 step takes about 0.8s at 300 movement speed, longer than the 0.3-0.5s left in Dark Willow's
-- and Clinkz's windows). timeLeft: seconds until the next wind-up may start (the window's end less the time since the
-- last attack). Returns the step cut to what the bot walks in that time, or nil when that is under MIN_STEP.
function KiteRules.FitChaseStep(step, moveSpeed, timeLeft)
	local reach = math.max(0, timeLeft) * math.max(100, moveSpeed)
	if reach < KiteRules.MIN_STEP then
		return nil
	end
	return math.min(step, reach)
end

-- Seconds from now until our next attack is released: the rest of this attack's cycle plus the wind-up. from is
-- KiteRules.Window's first value (wind-up + BUF).
function KiteRules.NextAttackIn(secondsPerAttack, since, from)
	return math.max(0, secondsPerAttack - since) + from - KiteRules.BUF
end

-- How far ahead the target's position is extrapolated for a chase step: the time to our next attack, at most
-- CHASE_HORIZON. Game 064 t=2444: Zeus (seconds per attack 6.2 that moment, window 1.38-4.83) extrapolated Death
-- Prophet about 5s ahead (ahead=680) and stepped 250 toward her; GetExtrapolatedLocation assumes she keeps running
-- straight, which over seconds she does not.
KiteRules.CHASE_HORIZON = 1.0
function KiteRules.ChaseHorizon(nextIn)
	return math.max(0, math.min(nextIn, KiteRules.CHASE_HORIZON))
end

-- No chase step toward a group (game 064: all 3 Zeus deaths came 2-5s after a chase step toward 2-3 enemy heroes):
-- enemies = the most enemy heroes near the target or near us (the target counted), allies = our heroes near us (we
-- counted). Two or more enemies need at least as many allies. Enemies within 1000 of the target or of us, allies within
-- 1200 of us (a fight's reach, not a game value).
KiteRules.CHASE_GROUP_RADIUS = 1000
KiteRules.CHASE_ALLY_RADIUS = 1200
function KiteRules.ChaseOutnumbered(enemies, allies)
	return enemies >= 2 and allies < enemies
end

-- No-step reasons that are not a like-for-like baseline (#72, game 064: 135 of 152 chase base samples were "fast"):
-- a hero with attacks too fast to kite is in a different situation from one a gate (tower, last hit, blocked spot,
-- no room, outnumbered) stopped. They still count in no-step=, not in base=.
-- Outnumbered (#72, game 065 review): the gate now runs before the attack window is checked, so it comes up outside
-- the window too; it counts in no-step= only.
KiteRules.NOT_BASELINE = { fast = true, outnumbered = true }

-- Within attack range at the next attack: Dota measures attack range between the two hulls.
function KiteRules.InAttackRange(dist, range, botRadius, targetRadius)
	return dist <= range + botRadius + targetRadius
end

return KiteRules
