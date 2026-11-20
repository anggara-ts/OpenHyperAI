-- Pure rules for the laning harass (#71). No API calls: the laning mode passes plain numbers, so Tests/ can check them.
local LaneHarassRules = {}

-- Heroes with an attack range above this are ranged (the laning mode's own melee / ranged split: LastHitRisk and
-- LaneStandOff use 326). Game files 7.42: the shortest ranged hero attacks are Luna 330, Morphling 350, Gyrocopter
-- 365 and Zeus 380.
LaneHarassRules.RANGED_ABOVE = 326

-- Harass and reset (#71): with fresh enemy creeps near (a hit on their hero turns them on us), a ranged bot still takes
-- one hit and then steps back toward its fountain so they lose it. Returns nil when the reset may go, else the first
-- gate that stops it, for [OHA-HARASS] noreset=:
--   melee     not a ranged hero
--   hp        HP 60% or less
--   fresh     more than 2 fresh creeps near
--   hitting   a creep is already hitting us
--   tower     the target or the bot is by the enemy T1
--   cooldown  a reset ran less than 6s ago
-- Game 059: Zeus (range 365 by the API) skipped it twice (fresh=1, hitting=0, HP 88% and 94%) because the gate wanted
-- range 400 or more.
function LaneHarassRules.ResetBlock(attackRange, hpRatio, fresh, hitting, safeTarget, cooldownReady)
	if attackRange <= LaneHarassRules.RANGED_ABOVE then
		return "melee"
	end
	if hpRatio <= 0.6 then
		return "hp"
	end
	if fresh > 2 then
		return "fresh"
	end
	if hitting > 0 then
		return "hitting"
	end
	if not safeTarget then
		return "tower"
	end
	if not cooldownReady then
		return "cooldown"
	end
	return nil
end

return LaneHarassRules
