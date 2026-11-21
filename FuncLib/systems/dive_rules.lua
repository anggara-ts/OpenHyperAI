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

-- After a stop the bot keeps out of that tower for HOLD_SECONDS. Game 063, 23:44: Earth Spirit's first stop ran him
-- for the fixed 2.88s, then team roam and farm walked him back past the tower; he was stopped again at 23:50 and died
-- at 23:52. The hold zone is the tower's range + HOLD_MARGIN; once the bot is inside it, it walks out to
-- HOLD_MARGIN + HOLD_RELEASE so the next mode does not flip with retreat right at the edge.
DiveRules.HOLD_SECONDS = 9
DiveRules.HOLD_MARGIN = 200
DiveRules.HOLD_RELEASE = 150

-- dist: the bot's distance to the tower; range: the tower's attack range; inside: the bot was in the zone at the
-- last check. Returns whether to run out now, and the new "inside" state.
function DiveRules.TowerHoldRun(dist, range, inside)
	if dist < range + DiveRules.HOLD_MARGIN then
		return true, true
	end
	if inside and dist < range + DiveRules.HOLD_MARGIN + DiveRules.HOLD_RELEASE then
		return true, true
	end
	return false, false
end

return DiveRules
