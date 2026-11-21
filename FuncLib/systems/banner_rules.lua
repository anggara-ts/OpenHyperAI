-- Roshan's Banner: when to plant it (#15). Pure, no bot API calls, so Tests/test_banner_rules.lua can load it.
--
-- 7.42 game file (item_roshans_banner): cast range 1200, duration 120, radius 600/900/1200 and health 6/8/10 by the
-- Banner's level, hp_bonus 75, damage_bonus 50. The maintainer (game 063) says lane creeps in the radius are damage
-- immune and melee heroes take 2 health per hit; the file shows no immunity key, so that part is unconfirmed, but either
-- way the Banner is worth most where our wave stands at a building. Maintainer: plant it while pushing, right after a
-- won fight next to an enemy building (a won fight that is not followed by a push wastes it), and while defending our
-- base ("defending base is as important"); in any mode, not only push mode.
local BannerRules = {}

-- Our lane creeps a plant needs inside the Banner's radius: 5 at an enemy building (maintainer: 3 is too few), 4 at
-- ours (maintainer, game 063).
BannerRules.PUSH_CREEPS = 5
BannerRules.DEFEND_CREEPS = 4

-- s: pushing (a push mode), fightMode (attack or team roam), enemyBuilding (one within 1600), pushCreeps (our creeps in
-- the radius of the push plant point), alliesNear / enemiesNear (heroes within 1600, the bot counted), ownBuilding (our
-- T2, T3, barracks or Ancient within 1600 with enemies at it), defendCreeps (our creeps in the radius of the defend
-- plant point), heroesAtBuilding (enemy heroes within 1200 of that building), heroHitBuilding (a hero hit it in the
-- last 3s). Defend needs an enemy hero there: a lane wave alone at our T2 is a creep clash, and the Banner is used once.
-- Returns "push", "fight-push", "defend" or nil.
function BannerRules.Why(s)
	if s.enemyBuilding and (s.pushCreeps or 0) >= BannerRules.PUSH_CREEPS then
		if s.pushing then
			return "push"
		end
		if s.fightMode and (s.enemiesNear or 0) <= (s.alliesNear or 1) then
			return "fight-push"
		end
	end
	if
		s.ownBuilding
		and ((s.heroesAtBuilding or 0) >= 1 or s.heroHitBuilding)
		and (s.defendCreeps or 0) >= BannerRules.DEFEND_CREEPS
	then
		return "defend"
	end
	return nil
end

return BannerRules
