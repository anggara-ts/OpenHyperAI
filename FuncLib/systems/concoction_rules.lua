-- Shared bot system: pure rules for Alchemist's Unstable Concoction (#34), no bot API calls, so they can be tested
-- with plain numbers. Used by BotsLib/hero_alchemist.lua.
--
-- Game data, 7.42: Valve datafeed hero 73 (alchemist_unstable_concoction): brew_time 5.0, brew_explosion 5.5,
-- min_stun 0.25, max_stun 1.7/2.2/2.7/3.2, max_damage 150/220/290/360, radius 250, AbilityCooldown 17,
-- AbilityManaCost 100. npc_heroes.txt in pak01_dir.vpk (read 2026-11-21), alchemist_unstable_concoction_throw:
-- AbilityCastPoint 0.2, projectile_speed 900. The hero file reads the values from the abilities at run time; the
-- numbers here are only the fallbacks and the tests.
local ConcoctionRules = {}

-- Stun of a throw after `brewed` seconds. The datafeed gives only the ends (min_stun at 0s, max_stun at brew_time)
-- and says the stun grows with the brew time; a straight line between them is assumed.
function ConcoctionRules.StunAt(brewed, minStun, maxStun, brewTime)
	if brewTime == nil or brewTime <= 0 then
		return maxStun
	end
	local share = math.max(0, math.min(1, brewed / brewTime))
	return minStun + (maxStun - minStun) * share
end

-- Seconds from the throw order until the stun lands: the cast point, then the projectile's flight.
ConcoctionRules.CAST_POINT = 0.2
ConcoctionRules.PROJECTILE_SPEED = 900
function ConcoctionRules.LandTime(distance, castPoint, projectileSpeed)
	castPoint = castPoint or ConcoctionRules.CAST_POINT
	projectileSpeed = projectileSpeed or ConcoctionRules.PROJECTILE_SPEED
	return castPoint + math.max(0, distance) / math.max(1, projectileSpeed)
end

-- Allies are finishing a low hero: under FINISH_HP of its HP and an allied hero is attacking it (game 063: 30% was
-- too low, Earth Spirit at 35% died in the start second).
ConcoctionRules.FINISH_HP = 0.4
function ConcoctionRules.AlliesFinishing(targetHp, alliesOnTarget)
	return targetHp < ConcoctionRules.FINISH_HP and alliesOnTarget >= 1
end

-- What to do with a brew for a hero the allies are finishing (maintainer, 2026-11-21):
--   escapeKind     "runner" (moving, not facing him), "tp" (teleporting or channeling), "blink" (Blink ready and
--                  moving), or nil (held / not escaping)
--   otherEnemyNear another enemy hero within SAVE_RADIUS of him
-- Returns "help" (brew and throw early, timed to the escape), "save" (no brew: keep it for the other hero), or
-- "held" (nobody else to keep it for, so the cooldown is free: brew and throw early anyway).
ConcoctionRules.SAVE_RADIUS = 1200
function ConcoctionRules.FinishingPlan(escapeKind, otherEnemyNear)
	if escapeKind ~= nil then
		return "help"
	end
	if otherEnemyNear then
		return "save"
	end
	return "held"
end

-- Is a help throw due now?
--   kind      the escape kind ("runner", "blink", "tp") or "held"
--   brewed    seconds brewed; stun the stun a throw now gives (ConcoctionRules.StunAt)
--   tpLeft    seconds left of the target's teleport / channel (nil or 0: unknown)
--   landTime  seconds until a throw now lands (ConcoctionRules.LandTime)
-- runner / blink: once the stun covers about ESCAPE_STUN seconds, enough for the allies to finish it.
-- tp: the latest moment the stun still lands before the teleport ends, with TP_MARGIN to spare (the longer
-- brew gives a longer stun); at once when the time left is unknown or too short already.
-- held: as soon as the brew has started (HELD_MIN_BREWED): nobody else is near, a quick throw only helps.
ConcoctionRules.ESCAPE_STUN = 1.0
ConcoctionRules.TP_MARGIN = 0.6
ConcoctionRules.HELD_MIN_BREWED = 0.3
function ConcoctionRules.HelpThrowNow(kind, brewed, stun, tpLeft, landTime)
	if kind == "tp" then
		if tpLeft == nil or tpLeft <= 0 then
			return true
		end
		return tpLeft - (landTime or 0) <= ConcoctionRules.TP_MARGIN
	end
	if kind == "runner" or kind == "blink" then
		return stun >= ConcoctionRules.ESCAPE_STUN
	end
	return brewed >= ConcoctionRules.HELD_MIN_BREWED
end

return ConcoctionRules
