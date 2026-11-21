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

-- Channels and cast phases a root cancels (7.42 game files, read from pak01_dir.vpk on 2026-11-21).
--   kind "channel": the enemy is channelling it (IsChanneling); time left from the TP modifier or the channel time
--   kind "cast": a long cast point (the enemy is in its ability phase); time left from the cast point
-- Rule: these carry DOTA_ABILITY_BEHAVIOR_ROOT_DISABLES, and the TP scroll, which has the same flag, says
-- "Teleport can be prevented or canceled by Root abilities" (item_tpscroll_Note1). Only the TP is confirmed by
-- a note; the others follow from the flag. Cast-phase entries: only cast points long enough for a root to land
-- (Bramble takes 0.7s). Ordinary channels are not here: "Does not interrupt channeling spells upon rooting"
-- (dark_willow_bramble_maze_Note0).
InterruptRules.ROOT_CANCELS = {
	item_tpscroll = { kind = "channel", source = "items.txt CHANNELLED|ROOT_DISABLES 3.0s (BoT2 2s); Note1" },
	abyssal_underlord_portal_warp = {
		kind = "channel",
		source = "npc_dota_hero_abyssal_underlord CHANNELLED|ROOT_DISABLES 3.5s",
	},
	twin_gate_portal_warp = { kind = "channel", source = "npc_abilities.txt CHANNELLED|ROOT_DISABLES 4.0s" },
	stone_of_recall_teleport = { kind = "channel", source = "npc_abilities.txt CHANNELLED|ROOT_DISABLES 5s" },
	templar_assassin_hidden_gates = {
		kind = "channel",
		source = "npc_dota_hero_templar_assassin CHANNELLED|ROOT_DISABLES 3.0s",
	},
	tinker_keen_teleport = { kind = "channel", source = "npc_dota_hero_tinker CHANNELLED|ROOT_DISABLES" },
	monkey_king_primal_spring = {
		kind = "channel",
		source = "npc_dota_hero_monkey_king CHANNELLED|ROOT_DISABLES 1.75s",
	},
	furion_teleportation = { kind = "cast", source = "npc_dota_hero_furion ROOT_DISABLES, cast point 3" },
	meepo_poof = { kind = "cast", source = "npc_dota_hero_meepo ROOT_DISABLES, cast point 1.5" },
	pangolier_gyroshell = { kind = "cast", source = "npc_dota_hero_pangolier ROOT_DISABLES, cast point 1.2" },
	spirit_breaker_nether_strike = {
		kind = "cast",
		source = "npc_dota_hero_spirit_breaker ROOT_DISABLES, cast point 1.0",
	},
	techies_suicide = { kind = "cast", source = "npc_dota_hero_techies ROOT_DISABLES, cast point 1.0" },
}

-- Bramble Maze formation (Dota 2 Fandom wiki "Dark Willow", Liquipedia "Dark_Willow"; not in the game files): 4
-- inner brambles 200 from the cast point toward world east/north/west/south, spawning in that order (east first,
-- then counter-clockwise), 4 outer ones 500 out on the diagonals. Latch range 90 (datafeed).
InterruptRules.BRAMBLE_INNER = {
	{ aim = "east", x = 200, y = 0 },
	{ aim = "north", x = 0, y = 200 },
	{ aim = "west", x = -200, y = 0 },
	{ aim = "south", x = 0, y = -200 },
}

-- Where to cast Bramble Maze so an inner bramble grows right on a hero standing at (tx, ty): the cast point is the
-- target minus that bramble's offset. East first (it spawns first); the first one within castRange of the caster
-- at (bx, by). Returns x, y, aim name, spawn index (0 = first) or nil when none is in range.
function InterruptRules.BrambleAim(tx, ty, bx, by, castRange)
	for i, bramble in ipairs(InterruptRules.BRAMBLE_INNER) do
		local x, y = tx - bramble.x, ty - bramble.y
		local dx, dy = x - bx, y - by
		if dx * dx + dy * dy <= castRange * castRange then
			return x, y, bramble.aim, i - 1
		end
	end
	return nil
end

-- Seconds from the order until that bramble roots a hero standing on it: cast point + grow delay + latch delay +
-- the spawn index times the interval between brambles (datafeed: 0.3, initial_creation_delay 0.3,
-- latch_creation_delay 0.1, latch_creation_interval 0.075).
function InterruptRules.BrambleRootTime(castPoint, growDelay, latchDelay, interval, index)
	return (castPoint or 0) + (growDelay or 0) + (latchDelay or 0) + (interval or 0) * (index or 0)
end

return InterruptRules
