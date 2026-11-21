-- Shared bot system: pure timing rules for interrupting an enemy channel (teleport, channelled spell).
-- No bot API calls, so they can be tested with real numbers (Tests/test_interrupt_rules.lua).
local InterruptRules = {}

-- Safety margin: the effect must land at least this long before the channel ends (order latency, turning).
InterruptRules.MARGIN = 0.1

-- Seconds from the cast order until a spell's effect lands at a point `distance` away:
-- cast point + extra delay + distance / travel speed (travel speed nil or 0: the effect does not travel).
function InterruptRules.ArrivalTime(castPoint, distance, travelSpeed, delay)
	local arrive = (castPoint or 0) + (delay or 0)
	if travelSpeed ~= nil and travelSpeed > 0 then
		arrive = arrive + math.max(distance or 0, 0) / travelSpeed
	end
	return arrive
end

-- Does an effect that lands in `arrive` seconds hit before a channel with `left` seconds remaining ends?
-- left <= 0 (unknown or over) never counts.
function InterruptRules.LandsBeforeChannelEnds(arrive, left, margin)
	if left == nil or left <= 0 then
		return false
	end
	return arrive < left - (margin or InterruptRules.MARGIN)
end

-- Time left of a channel whose start the bot cannot read: remembered from the first think it was seen.
--   memory       a table owned by the caller (one per bot)
--   key          the channelling unit (e.g. its unit name)
--   abilityName  the channelled ability; a different one, or a gap of more than 0.5s, starts a new channel
--   channelTime  the ability's full channel time
-- Seen late (the bot was not looking when it started), this is an upper bound.
function InterruptRules.TrackChannel(memory, key, abilityName, channelTime, now)
	local entry = memory[key]
	if entry == nil or entry.name ~= abilityName or now - entry.lastSeen > 0.5 then
		entry = { name = abilityName, seenAt = now }
		memory[key] = entry
	end
	entry.lastSeen = now
	return math.max((channelTime or 0) - (now - entry.seenAt), 0)
end

return InterruptRules
