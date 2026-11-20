-- Shared bot system: pure retreat rules (no bot API calls), so they can be tested with real numbers.
local RetreatRules = {}

-- Is a bot that is attacking outnumbered enough to break off (mode_retreat_generic.lua, hard retreat)?
--   allies   heroes of ours near it, itself and Meepo clones included (they fight), illusions not
--   visible  enemy heroes seen near it right now
--   recent   enemy heroes last seen near it in the past few seconds (vision flickers)
--   hp       its HP ratio; hit: damaged by a hero in the last ~2s; stronger: Fu.WeAreStronger
-- Below 60% HP the recent sightings count too: being caught matters more than being sure.
-- At 60%+ only enemies it can see, two more than us, while it is being hit. Game 038: the old rule sent
-- Mirana back at full HP with no enemy within 1200 (two lane opponents last seen within 2000), and Meepo
-- with 3 bodies against 2 (his clones were not counted), 156 times in one game.
function RetreatRules.HardRetreatOutnumbered(allies, visible, recent, hp, hit, stronger)
	local pressure = math.max(visible, recent)
	if hp < 0.6 then
		return allies <= 1 and pressure >= 2 or pressure >= allies + 1 and not stronger
	end
	return hit and visible >= allies + 2 and not stronger
end

-- Low HP and being chewed by creeps or a tower, with no hero kill to finish (mode_retreat_generic.lua, creep-low).
-- Game 062, 17:34: Weaver stood in attack mode (0.71-0.74) in a creep wave and went from 13% to 3% HP in 3.5s
-- with no enemy hero near; the only creep rule (tag 369) needs the laning phase, 4+ creeps and a chase.
-- 25%: that wave took ~3% of her HP per second (10% in 3.5s), so 25% leaves ~8s, enough to walk out of
-- creep reach (and a hero turning up) with room to spare; the file uses 25% as its low line elsewhere too
-- (the Ancient-defence and laning-regen rules).
-- Once it fires, it holds (the caller's 3s window) while HP stays under 35% and creeps or a tower are still in
-- reach: the creep hit flag lapses 2s after the bot steps away, and attack would walk it straight back in.
--   hp          HP ratio
--   creepHit    damaged by a creep in the last ~2s; towerHit: by a tower
--   canFinish   an enemy hero in reach dies to this bot's next hit (Fu.ShouldFinishCommittedKill)
--   channeling  the bot is channeling (a TP home is the escape; a move order would cancel it)
--   holding     the rule fired in the last 3s and retreat is the active mode
--   creepsNear  enemy creeps or an enemy tower still in reach
RetreatRules.CREEP_LOW_HP = 0.25
RetreatRules.CREEP_LOW_RELEASE_HP = 0.35
function RetreatRules.CreepLowRetreat(hp, creepHit, towerHit, canFinish, channeling, holding, creepsNear)
	if channeling or canFinish then
		return false
	end
	if hp < RetreatRules.CREEP_LOW_HP and (creepHit or towerHit) then
		return true
	end
	return holding and hp < RetreatRules.CREEP_LOW_RELEASE_HP and (creepHit or towerHit or creepsNear)
end

return RetreatRules
