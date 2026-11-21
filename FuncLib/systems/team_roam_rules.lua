-- Pure team roam rules (no bot API calls), so Tests/test_team_roam_rules.lua drives them with plain numbers (#165,
-- mode flip-flops). mode_team_roam_generic.lua and FuncLib/systems/last_hit_overlay.lua call them.
local Rules = {}

-- Team roam's cut on its own desire (adjustDesire): above 0.6 -> 0.5 while pushing, above 0.9 -> 0.72 in the laning
-- phase. The last-hit overlay uses the same cut, so a last hit still loses to the modes it lost to as a mode.
function Rules.AdjustDesire(desire, isPushing, inLaningPhase)
	if isPushing and desire > 0.6 then
		return 0.5
	end
	if inLaningPhase and desire > 0.9 then
		return 0.72
	end
	return desire
end

-- The hunt's targets that still need team roam as a mode: an enemy hero or a courier (a chase). Every other hunt
-- target (lane creep, deny, neutral, tower, an ally to deny) is one hit on a unit next to the bot, done by the
-- overlay without a mode change. kind = HuntKind's word in mode_team_roam_generic.lua.
function Rules.HuntNeedsMode(kind)
	return kind == "hero" or kind == "courier"
end

-- How far a running hunt may drift before it stops: 1.5x the snipe's reach (attack range + 300), or 1.5x the distance
-- the hunt started at, whichever is longer (the hero hunt starts at up to 1600: a melee hero's 675 would end it on
-- its first think, the same self-off flip under another name).
function Rules.HuntKeepRange(attackRange, startDist)
	return math.max(1.5 * ((attackRange or 0) + 300), 1.5 * (startDist or 0))
end

-- A hunt that won team roam keeps the mode while team roam is active (the mode gate used to switch it off on its
-- first think, game 063: 71% of hunts). Why it stops, or nil to keep it:
--   valid       the hunt's target is alive, visible and attackable
--   dist        bot to target
--   keepRange   HuntKeepRange(attack range)
--   allies, enemies   heroes near the bot (team roam's alliesNear / enemiesNear)
-- HP is not here: the hunt's desire already scales down to 0 below 40% HP.
function Rules.HuntExitWhy(valid, dist, keepRange, allies, enemies)
	if not valid then
		return "lost"
	end
	if dist > keepRange then
		return "range"
	end
	if allies < enemies then
		return "outnumbered"
	end
	return nil
end

-- The last-hit overlay: a last hit (team roam's snipe, or a hunt on a creep) issued from the per-think hook while
-- the bot stays in its mode. Why it does not fire this think, or nil to fire. s:
--   desire, modeDesire   the overlay's desire (after AdjustDesire) and the active mode's desire: the overlay only
--                        fires where team roam would have won the mode
--   retreat, evasive     active mode is retreat (any desire) / evasive maneuvers (dodging)
--   invisible            invisible and not a hero that attacks out of it (Riki, PA, TA, Bounty Hunter)
--   charging             Spirit Breaker's Charge, or a hunting spell's [OHA-HUNT] trace is open (from the cast to
--                        its end line, up to HuntTrace.KILL_WINDOW after the reveal)
--   heroFight            attack / team roam is on an enemy hero in attack range: the hit belongs to the hero
--   channeling, busy     channeling / casting, using an ability or a queued order
--   valveMode            the active mode's Think is Valve's (ModeHoldable): it cannot be held, team roam should not
--                        have offered (the mode changed after its GetDesire)
function Rules.OverlaySkipWhy(s)
	if s.retreat then
		return "retreat"
	end
	if s.evasive then
		return "evasive"
	end
	if s.invisible then
		return "invisible"
	end
	if s.charging then
		return "charging"
	end
	if s.heroFight then
		return "fight"
	end
	if s.channeling then
		return "channel"
	end
	if s.busy then
		return "busy"
	end
	if s.valveMode then
		return "valve"
	end
	if s.desire == nil or s.modeDesire == nil or s.desire <= s.modeDesire then
		return "mode"
	end
	return nil
end

-- Modes whose Think is ours (Lua) for every hero: the last-hit overlay can hold them while it owns a hit
-- (OhaCastGuard skips their Think). Defend, item, side shop, roam, defend ally and evasive maneuvers are Valve's
-- (no Think in our files), and so is attack for the heroes not on Utils.BuggyHeroesDueToValveTooLazy. Lotus and
-- wisdom shrine have a Lua Think that does not call the guard. Names as RoamStats.ModeName.
local HOLDABLE_MODES = {
	laning = true,
	farm = true,
	push_tower_top = true,
	push_tower_mid = true,
	push_tower_bot = true,
	assemble = true,
	rune = true,
	secret_shop = true,
	ward = true,
	roshan = true,
	outpost = true,
	team_roam = true,
}
-- attackOverride: the bot runs our attack mode (mode_attack_generic.lua sets bot._ohaAttackOverride).
function Rules.ModeHoldable(modeName, attackOverride)
	if modeName == "attack" then
		return attackOverride == true
	end
	return HOLDABLE_MODES[modeName] == true
end

-- How team roam takes its snipe this think:
--   "overlay"  offer it to the last-hit overlay (the bot stays in its mode; the overlay holds the mode's Think)
--   "mode"     win team roam as a mode, as before #165: the active mode is Valve's and cannot be held from Lua, or
--              team roam already won the mode with the snipe (keep it until the creep is gone, no flip back)
--   "none"     no snipe: a hunting spell's trace is open, or attack / team roam is on an enemy hero in range
function Rules.SnipePath(holdable, heroFight, hunting, modeWinRunning)
	if heroFight or hunting then
		return "none"
	end
	if modeWinRunning then
		return "mode"
	end
	if holdable then
		return "overlay"
	end
	return "mode"
end

-- The overlay owns a hit from its first attack order on the unit; the mode Thinks are held meanwhile. Why it lets
-- go, or nil to keep holding. o (GameTime seconds):
--   now, since       now, and when the hold started
--   alive            the unit is alive
--   lastAttack       bot:GetLastAttackTime() now; ownAttack: the same when the hold started
--   windup           the bot's attack point in seconds (GetAttackPoint / GetAttackSpeed): the hit counts as released
--                    only once lastAttack + windup has passed, as it is not known whether GetLastAttackTime is the
--                    start of the attack or its release (special_units.lua's kiting assumes the same)
--   free             the active mode is retreat or evasive maneuvers: never held
-- HOLD_CAP ends a hold whose hit never comes (the unit walked off, an item or spell order replaced the attack).
local HOLD_CAP = 1.0
Rules.HOLD_CAP = HOLD_CAP
function Rules.OverlayHoldWhy(o)
	if not o.alive then
		return "dead"
	end
	if o.free then
		return "free"
	end
	if o.lastAttack ~= nil and o.ownAttack ~= nil and o.lastAttack > o.ownAttack then
		if o.now >= o.lastAttack + (o.windup or 0) then
			return "hit"
		end
	end
	if o.now - o.since >= HOLD_CAP then
		return "cap"
	end
	return nil
end

-- Special units (wards, Weaver beetles, cogs, ...) when the enemy outnumbers us near the bot: never above retreat.
-- Game 063, 15:38: Zeus went from a hard retreat (4 enemies, no ally near) to team roam 0.96 on a special unit and
-- died 3.5s later. Returns the desire to use and whether it was cut.
--   retreatDesire   retreat's last desire (nil when unknown); exempt: the serpent ward escape (itself an escape)
function Rules.SpecialUnitCap(desire, allies, enemies, retreatDesire, exempt)
	if exempt or allies >= enemies or retreatDesire == nil or retreatDesire <= 0 then
		return desire, false
	end
	local cap = math.max(0, retreatDesire - 0.05)
	if desire > cap then
		return cap, true
	end
	return desire, false
end

-- Courier hunt (#165, game 067: Vengeful Spirit walked to the top power-rune spot past a visible enemy courier). Before,
-- the hunt was off in the laning phase and only looked within attack range + 2x level + 20 (680 for an attack range of
-- 650 at level 5). In the laning phase it now looks within attack range + COURIER_LANE_EXTRA when no enemy hero is within
-- COURIER_LANE_SAFE of the courier. Why the bot leaves the courier, or nil to hunt it. c:
--   dist, attackRange, level   bot to courier, the bot's attack range (team roam's, +50) and level
--   laning, pushing            in the laning phase / pushing a tower
--   enemiesNearCourier         enemy heroes within COURIER_LANE_SAFE of the courier (used in the laning phase)
--   retreating, onRune, hp     retreat mode, rune mode (walking to or holding a rune), HP ratio
Rules.COURIER_LANE_EXTRA = 400
Rules.COURIER_LANE_SAFE = 800
function Rules.CourierRange(attackRange, level, laning)
	if laning then
		return attackRange + Rules.COURIER_LANE_EXTRA
	end
	return attackRange + level * 2 + 20
end
function Rules.CourierSkipWhy(c)
	if c.pushing then
		return "pushing"
	end
	if c.retreating then
		return "retreat"
	end
	if c.hp <= 0.3 then
		return "hp"
	end
	if c.onRune then
		return "rune"
	end
	if c.dist > Rules.CourierRange(c.attackRange, c.level, c.laning) then
		return "range"
	end
	if c.laning and c.enemiesNearCourier > 0 then
		return "enemies"
	end
	return nil
end

return Rules
