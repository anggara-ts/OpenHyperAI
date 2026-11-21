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
--   charging             Spirit Breaker's Charge, or a hunting spell is running ([OHA-HUNT])
--   channeling, busy     channeling / casting, using an ability or a queued order
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
	if s.channeling then
		return "channel"
	end
	if s.busy then
		return "busy"
	end
	if s.desire == nil or s.modeDesire == nil or s.desire <= s.modeDesire then
		return "mode"
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

return Rules
