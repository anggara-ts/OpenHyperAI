-- Shared bot system: pure farm rules (no bot API calls), so they can be tested with plain numbers.
-- Used by FuncLib/data/site.lua (camp side) and mode_farm_generic.lua (enemy camps while behind, idle
-- fallback, camp keep window).
local FarmRules = {}

-- Which half a neutral camp is on, by position: the side of the lane tower (T1-T3, both teams) nearest to
-- it. The river runs between the two teams' towers on every lane, so the tower map splits the jungles along
-- it, including the corner and map-edge camps. The plain "closer Ancient" test does not: the Ancients sit on
-- the diagonal, so the bottom-right corner past our safe-lane T1 measures closer to the Dire Ancient (game
-- 062: 5886,-5478 next to our bottom T1 counted as the enemy half).
--   x, y          camp position
--   radiantTowers list of {x=, y=} for Radiant towers, direTowers the same for Dire
-- Returns "radiant" or "dire" (nil without towers) and the margin: how much closer the nearest tower of the
-- winning side is than the other side's nearest one (small = a camp by the river).
function FarmRules.CampSide(x, y, radiantTowers, direTowers)
	local function nearest(towers)
		local best = math.huge
		for _, tower in ipairs(towers or {}) do
			local dx, dy = tower.x - x, tower.y - y
			local d = math.sqrt(dx * dx + dy * dy)
			if d < best then
				best = d
			end
		end
		return best
	end
	local radiant, dire = nearest(radiantTowers), nearest(direTowers)
	if radiant == math.huge or dire == math.huge then
		return nil, 0
	end
	if radiant <= dire then
		return "radiant", dire - radiant
	end
	return "dire", radiant - dire
end

-- The side the farm uses. Clear of the river (margin of RIVER_MARGIN or more) the position decides. A camp by
-- the river is close to both teams' towers, so there the engine's spawner team decides when it names one
-- (game 062 towers, recovered from the withdraw targets: the river camps at -4824,3915 and 4649,-3699 are
-- each other's mirror image, yet both measured Dire, by 761 and 200).
--   posSide, margin  from CampSide; engineSide "radiant", "dire" or nil
-- Returns the side and what decided it ("position" or "engine").
FarmRules.RIVER_MARGIN = 1500
function FarmRules.DecideCampSide(posSide, margin, engineSide)
	if (posSide == nil or margin < FarmRules.RIVER_MARGIN) and (engineSide == "radiant" or engineSide == "dire") then
		return engineSide, "engine"
	end
	return posSide, "position"
end

-- An enemy camp is covered when our wave on its lane is at least as deep toward their Ancient as the camp
-- (500 slack): the wave gives vision and draws them (game 039).
function FarmRules.EnemyCampCovered(waveToAncient, campToAncient)
	return waveToAncient <= campToAncient + 500
end

-- While a lane is marked behind (push.lua GameStates.enemyHalfOff) or we have fewer heroes alive, an enemy
-- camp is still open when all three hold (game 062, maintainer: "top lane creep has pushed so they may use
-- enemy jungle camps nearby"):
--   our wave on the camp's lane is deeper than the camp (no slack here),
--   the camp's lane is not the lane marked behind,
--   no enemy hero was seen near the camp recently.
-- Returns open, why.
function FarmRules.EnemyCampOpenWhileBehind(waveToAncient, campToAncient, campLaneBehind, enemiesNear)
	if campLaneBehind then
		return false, "lane-behind"
	end
	if enemiesNear > 0 then
		return false, "enemy-seen"
	end
	if waveToAncient >= campToAncient then
		return false, "wave-not-deeper"
	end
	return true, "wave-deeper"
end

-- Idle fallback. A bot whose best (active) mode desire stays under maxDesire while it does nothing (not
-- attacking or casting) for `after` seconds is idle (game 062, 30:30-31:50: Medusa, Leshrac and Nature's
-- Prophet stood still ~80s with farm 0.06 and assemble 0.10 as the best modes).
--   state  table kept per bot ({since=, last=}), changed in place
--   busy   true when the bot attacks, casts, is dead, healing in the fountain or not a bot
-- A gap of more than 2s between two calls (the caller returned early, e.g. a base siege) starts over: the
-- stretch must be seen as one.
-- Returns fire (true once the stretch is long enough) and the seconds idle so far.
FarmRules.IDLE_DESIRE_MAX = 0.15
FarmRules.IDLE_AFTER = 10
function FarmRules.IdleStep(state, now, bestDesire, busy, maxDesire, after)
	maxDesire = maxDesire or FarmRules.IDLE_DESIRE_MAX
	after = after or FarmRules.IDLE_AFTER
	local gap = state.last ~= nil and now - state.last > 2
	state.last = now
	if busy or bestDesire >= maxDesire then
		state.since = nil
		return false, 0
	end
	if state.since == nil or gap then
		state.since = now
	end
	local idleFor = now - state.since
	return idleFor >= after, idleFor
end

-- Once the idle fallback fires, farm holds the walk until the bot is there, another mode took over with a
-- higher desire, or the walk timed out.
FarmRules.IDLE_HOLD = 25
FarmRules.IDLE_ARRIVE = 600
function FarmRules.IdleHoldEnds(now, startedAt, distance, otherModeDesire, idleDesire)
	if now - startedAt > FarmRules.IDLE_HOLD then
		return "timeout"
	end
	if distance <= FarmRules.IDLE_ARRIVE then
		return "arrived"
	end
	if otherModeDesire ~= nil and otherModeDesire > idleDesire then
		return "other-mode"
	end
	return nil
end

-- Camp keep window: a camp picked less than CAMP_KEEP seconds ago is not swapped for a closer one. A hard
-- reason (cleared, unsafe, no longer allowed, taken by an ally) switches at once.
FarmRules.CAMP_KEEP = 5
function FarmRules.CanSwitchCamp(now, chosenAt, hard)
	return hard or chosenAt == nil or now - chosenAt >= FarmRules.CAMP_KEEP
end

return FarmRules
