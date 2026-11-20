-- Shared bot system: pure rules for using a nuke on lane creeps (no bot API calls), so they can be tested
-- with real numbers. First user: Leshrac's Lightning Storm (BotsLib/hero_leshrac.lua).
local LaneNukeRules = {}

-- Mana at or above this share of the maximum counts as "full": the regeneration from here on is mostly
-- wasted, so a spell on a creep costs little.
LaneNukeRules.FULL_MANA_RATIO = 0.9

-- Spare mana for a last-hit nuke in lane (#143, game 062 ~2:40: Leshrac sat at full mana in lane and never
-- used Lightning Storm on creeps)?
--   mana, maxMana  the hero's current and maximum mana
--   cost           the nuke's mana cost
--   reserve        mana to keep after the cast for a fight (the fight spells it has learned)
-- Not "full again before the cooldown ends": with Lightning Storm's 4s cooldown and 80-140 mana (7.42
-- npc_abilities) that needs 20+ mana per second, which no laning hero has, so that rule would never fire.
function LaneNukeRules.SpareManaForLastHit(mana, maxMana, cost, reserve)
	if maxMana == nil or maxMana <= 0 or cost == nil or cost <= 0 or mana == nil then
		return false
	end
	if mana < maxMana * LaneNukeRules.FULL_MANA_RATIO then
		return false
	end
	return mana - cost >= (reserve or 0)
end

-- How good a creep is as the nuke's target: every creep it kills counts (a bounce that kills a second creep
-- beats one kill), and a creep the hero's own attack can't kill right now beats one it could last-hit itself.
-- 0 means no kill.
function LaneNukeRules.LastHitScore(kills, attackCanKill)
	if kills == nil or kills < 1 then
		return 0
	end
	return kills * 2 + (attackCanKill and 0 or 1)
end

return LaneNukeRules
