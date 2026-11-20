-- Shared bot system: pure tower-dive rules (no bot API calls), so they can be tested with real numbers.
local DiveRules = {}

-- After the early game, should a bot that an enemy tower is shooting stop its chase (mode_retreat_generic.lua,
-- Retreat.ShouldRun)? The early-game anti-dive (#83) covers the first 12 minutes; after that nothing pulled a
-- chaser out of tower range (game 048, 17:30: Skywrath chased Sniper past Dire's mid T1, took the tower and died;
-- game 037, 20:30: Radiant dove behind Dire's bottom T1).
--   s.towerOnBot   the tower is attacking this bot or hit it in the last 1.5s
--   s.pushing      the bot is in a push mode (PushThink steps out of tower aggro itself)
--   s.hasTarget    the bot has a hero target it can attack
--   s.teamDamage   damage the bot and the allies near can do to that target in the window (2 tower shots)
--   s.targetHealth the target's HP
--   s.committed    the target is in reach and disabled or under 40% HP (IsCommittedKill)
--   s.botHealth    the bot's HP
--   s.shotDamage   one tower shot on this bot, after armor
-- The chase stays only when the target dies within the tower's next 2 shots (or is a committed kill) and the bot
-- survives those 2 shots plus one more to walk out. Returns "stay" or "leave" and the reason, or nil (no
-- decision: the tower is not on the bot, or a push mode handles it).
function DiveRules.TowerChaseDecision(s)
	if not s.towerOnBot or s.pushing then
		return nil
	end
	if s.botHealth <= s.shotDamage * 3 then
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

return DiveRules
