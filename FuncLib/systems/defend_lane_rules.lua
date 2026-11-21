-- Shared bot system: pure rules for which lane a defender takes and when it teleports there (#53). No bot API calls,
-- so they can be tested with game numbers.
local DefendLaneRules = {}

-- How long a defender keeps the lane it picked (s), and how close counts as "at" that lane.
DefendLaneRules.HOLD_SECONDS = 10
DefendLaneRules.AT_LANE_DISTANCE = 2500

-- Keep the held lane over another threatened lane? Game 066, 81:41-81:55: Elder Titan defended the bottom high ground
-- (11-21 enemy creeps, 712-998 from his spot); when the base-lane gate let go for a moment, mid (8 creeps) read 0.85
-- against bottom's 0.37 and he took the mid defence, TP'd away and walked back for 34s. The desire alone can't tell:
-- mid's 0.85 came from a different rule than bottom's.
--   held / other: { desire = lane defend desire, creeps = enemy creeps at the lane's threat, hp = HP ratio of the
--                   lane's furthest building, dist = the bot's distance to the lane's threat }
--   heldAge       seconds since the bot was last in the held lane's defend mode
-- Returns true (keep the held lane; the other lane is capped below it), false (the other lane may win), and the
-- reason.
function DefendLaneRules.KeepLane(held, other, heldAge)
	if held == nil or other == nil or (held.desire or 0) <= 0.1 then
		return false, "no-held"
	end
	if
		(heldAge or math.huge) > DefendLaneRules.HOLD_SECONDS
		and (held.dist or math.huge) > DefendLaneRules.AT_LANE_DISTANCE
	then
		return false, "not-at-held"
	end
	local heldCreeps, otherCreeps = held.creeps or 0, other.creeps or 0
	if otherCreeps >= heldCreeps + 4 and otherCreeps >= heldCreeps * 1.5 then
		return false, "more-creeps"
	end
	if (other.hp or 1) + 0.25 < (held.hp or 1) then
		return false, "building-low"
	end
	return true, "hold"
end

-- Skip a defend teleport? Game 066, 81:55 and 82:35: Elder Titan TP'd to mid's far end (our own lane front, deep in
-- the enemy half), walked 10,000 back to his high ground in 34s, and TP'd out the same way again: the walk back
-- re-tripped the same condition.
--   now, lastLane, lastAt  the bot's last defend TP (lane and time), if any
--   lane                    the lane of this TP
--   baseThreat              enemy creeps or heroes are at our base (within 4000 of our Ancient)
--   botToAncient            the bot's distance to our Ancient
--   targetToAncient         the TP target's distance to our Ancient
-- Returns the reason ("recent", "away-from-base") or nil.
DefendLaneRules.TP_REPEAT_SECONDS = 20
function DefendLaneRules.DefendTpBlock(now, lastLane, lastAt, lane, baseThreat, botToAncient, targetToAncient)
	if lastLane == lane and lastAt ~= nil and now - lastAt < DefendLaneRules.TP_REPEAT_SECONDS then
		return "recent"
	end
	if baseThreat and targetToAncient > botToAncient + 1500 then
		return "away-from-base"
	end
	return nil
end

return DefendLaneRules
