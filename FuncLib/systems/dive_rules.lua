-- Shared bot system: pure tower-dive rules (no bot API calls), so they can be tested with real numbers.
local DiveRules = {}

-- After the early game, should a bot that an enemy T1/T2 is shooting stop its chase (mode_retreat_generic.lua,
-- Retreat.ShouldRun)? The early-game anti-dive (#83) covers the first 12 minutes; after that nothing pulled a
-- chaser out of tower range, and most heroes run Valve's attack mode, which has no tower check (#12: game 048,
-- 17:30, Skywrath took Dire's mid T1 while chasing Sniper; game 037, 20:30, Radiant fought behind Dire's bottom
-- T1 - whether the tower was on them there is not in that game's log).
--   s.towerOnBot   the tower is attacking this bot or hit it in the last 1.5s
--   s.entering     the tower is not on the bot yet, but its hero target stands inside the tower's range and the bot
--                  is close enough to follow it in. Game 063: 6 of 23 chase-stops died within 5s, all in retreat:
--                  the stop came once the tower already shot, with 2-3 heroes on the bot.
--   s.outerTower   the tower is a T1 or T2 (fights at a T3/T4 are base fights: no decision there)
--   s.pushing      the bot is in a push mode (PushThink steps out of tower aggro itself)
--   s.hasTarget    the bot has a hero target it can attack
--   s.teamDamage   damage the bot and the allies near can do to that target in the window (2 tower shots)
--   s.targetHealth the target's HP
--   s.committed    the target is in reach and disabled or under 40% HP (IsCommittedKill)
--   s.botHealth    the bot's HP
--   s.shotDamage   one tower shot on this bot, after armor
--   s.enemyDamage  what the visible enemy heroes near the bot can do to it in the same window. Game 063, 23:44-23:52:
--                  Earth Spirit was stopped twice at 85-100% HP with the tower doing 60-80 a shot, and three heroes
--                  killed him 2s after the second stop.
-- The chase stays only when the target dies within the tower's next 2 shots (or is a committed kill) and the bot
-- survives those 2 shots plus one more to walk out, plus the enemy heroes' damage. Returns "stay" or "leave" and
-- the reason, or nil (no decision: the tower is not on the bot and it is not entering after a target, the tower is
-- a T3/T4, or a push mode handles it).
function DiveRules.TowerChaseDecision(s)
	if not s.outerTower or s.pushing then
		return nil
	end
	-- Entering needs a hero target inside the tower's range: a bot walking past a T1/T2 is no chase.
	if not s.towerOnBot and not (s.entering and s.hasTarget) then
		return nil
	end
	if s.botHealth <= s.shotDamage * 3 + (s.enemyDamage or 0) then
		return "leave", "low-hp"
	end
	if not s.hasTarget then
		return "leave", "no-target"
	end
	if s.teamDamage >= s.targetHealth then
		return "stay", "killable"
	end
	if s.committed then
		return "stay", "committed"
	end
	return "leave", "not-killable"
end

-- Before the tower edge: a bot going on someone (attack / roam / team roam / defend ally) toward an enemy T1/T2,
-- up to the tower's range + APPROACH_MARGIN away and not in range yet, while what the visible enemy heroes near can
-- do to it in the window plus 3 tower shots is its HP or more ("dead on paper"). Game 065: 9 of 30 chase-stop /
-- tower-entry-stop lines were followed by the bot's death within 5s, all why=low-hp at the tower edge with 1-4 enemy
-- heroes whose damage was above the bot's HP (e.g. Zeus t=2150 tower-entry-stop hp=396 enemyDmg=5905 enemies=4 at
-- Dire's top T2, dead the same second): by the edge it was too late to walk out.
--   s.outerTower, s.pushing   as in TowerChaseDecision
--   s.approaching  the bot is outside the tower's range, within range + APPROACH_MARGIN, going on someone, and its
--                  hero target is nearer the tower than it is, or it is moving toward the tower
--   s.botHealth, s.shotDamage, s.enemyDamage   as in TowerChaseDecision
-- Returns "leave", "low-hp", or nil (no decision here: the edge rule decides once the bot gets there).
DiveRules.APPROACH_MARGIN = 600
function DiveRules.TowerApproachDecision(s)
	if not s.outerTower or s.pushing or not s.approaching then
		return nil
	end
	if s.botHealth <= s.shotDamage * 3 + (s.enemyDamage or 0) then
		return "leave", "low-hp"
	end
	return nil
end

-- Does a chase after a target inside the tower's range take the bot into it? Yes when the bot already stands inside,
-- or when even the spot on the far side of the target (target distance + the bot's attack range) is inside: a ranged
-- bot that can hit the target from outside the range is not entering. Distances are to the tower.
function DiveRules.MustEnterTowerRange(botDist, targetDist, attackRange, towerRange)
	return botDist <= towerRange or targetDist + attackRange <= towerRange
end

-- After a stop the bot keeps out of that tower for HOLD_SECONDS. Game 063, 23:44: Earth Spirit's first stop ran him
-- for the fixed 2.88s, then team roam and farm walked him back past the tower; he was stopped again at 23:50 and died
-- at 23:52. The hold zone is the tower's range + HOLD_MARGIN; once the bot is inside it, it walks out to
-- HOLD_MARGIN + HOLD_RELEASE so the next mode does not flip with retreat right at the edge.
DiveRules.HOLD_SECONDS = 9
DiveRules.HOLD_MARGIN = 200
DiveRules.HOLD_RELEASE = 150

-- dist: the bot's distance to the tower; range: the tower's attack range; inside: the bot was in the zone at the
-- last check; margin: the zone beyond the range (HOLD_MARGIN, or APPROACH_MARGIN after a stop before the edge).
-- Returns whether to run out now, and the new "inside" state.
function DiveRules.TowerHoldRun(dist, range, inside, margin)
	margin = margin or DiveRules.HOLD_MARGIN
	if dist < range + margin then
		return true, true
	end
	if inside and dist < range + margin + DiveRules.HOLD_RELEASE then
		return true, true
	end
	return false, false
end

-- What the hold does at this check. A push pauses it instead of ending it: PushThink steps out of tower aggro itself,
-- and retreat must not pull a bot out of a team siege. Game 064, 12:24-12:31: Alchemist was stopped at Dire's mid T1
-- (tower-entry-stop), one push-mode think during the hold cleared it, and attack mode walked him back under the
-- tower 7s later (chase-stop). The 9s clock keeps running while paused; when the push ends the hold resumes.
--   now, untilTime   game time and the hold's end; towerValid: the tower still stands
--   pushing          the bot is in a push mode now; paused: the last check paused the hold
-- A team siege of the hold tower ends the hold ("siege"): the bot pushes the hold tower's lane, 2+ allied heroes
-- stand at that tower, and the stop was why=no-target (no hero chase: the tower simply shot it during the siege).
-- Game 065, t=941-948: Dark Willow was stopped (no-target) at Radiant's top T1 while her team pushed it; pause and
-- resume alternated with push 0.90 / attack 0.65 / retreat 1.10 and the 9s ran out with her inside the zone. A chase
-- stop (low-hp, not-killable) keeps the pause: game 064, Alchemist was stopped chasing Tiny at the mid T1 his team
-- was pushing, and attack mode walked him back under it once the hold was gone.
--   pushLaneTower    the hold tower is in the lane the bot pushes; alliesAtTower: other allied heroes at it
--   why              the stop's reason
-- Returns "expire" (drop the hold), "siege" (drop it: team siege), "pause", "resume" (first check after a pause)
-- or "keep".
DiveRules.SIEGE_ALLIES = 2
function DiveRules.TowerHoldState(now, untilTime, towerValid, pushing, paused, pushLaneTower, alliesAtTower, why)
	if now > untilTime or not towerValid then
		return "expire"
	end
	if pushing and pushLaneTower and (alliesAtTower or 0) >= DiveRules.SIEGE_ALLIES and why == "no-target" then
		return "siege"
	end
	if pushing then
		return "pause"
	end
	if paused then
		return "resume"
	end
	return "keep"
end

return DiveRules
