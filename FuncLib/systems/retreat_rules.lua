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

return RetreatRules
