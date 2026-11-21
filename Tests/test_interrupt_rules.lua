-- FuncLib/systems/interrupt_rules.lua: does an interrupt land before the enemy's channel ends?
local T = ...

local function rules()
	T.stub.reset({ hero = "npc_dota_hero_dark_willow" })
	return require(GetScriptDirectory() .. "/FuncLib/systems/interrupt_rules")
end

T.test("arrival: cast point + delay + travel", function()
	local R = rules()
	-- Terrorize (datafeed hero 119): cast point 1.0, wisp flies at destination_travel_speed 2000.
	T.near(R.ArrivalTime(1.0, 1200, 2000, 0), 1.6, 1e-9, "Terrorize at 1200")
	T.near(R.ArrivalTime(1.0, 0, 2000, 0), 1.0, 1e-9, "Terrorize on herself")
	-- Cursed Crown: cast point 0.2, stun after delay 4, no travel.
	T.near(R.ArrivalTime(0.2, 700, nil, 4), 4.2, 1e-9, "Cursed Crown")
	-- Pulverize: cast point 0.25, melee range, no travel.
	T.near(R.ArrivalTime(0.25, 150, 0), 0.25, 1e-9, "Pulverize")
	T.near(R.ArrivalTime(1.0, -50, 2000), 1.0, 1e-9, "negative distance counts as 0")
end)

T.test("lands before channel ends: TP scroll (3.0s, game files 7.42)", function()
	local R = rules()
	-- A fresh TP (3.0s left): Terrorize lands in time from her full cast range.
	T.eq(R.LandsBeforeChannelEnds(R.ArrivalTime(1.0, 1200, 2000), 3.0), true, "fresh TP, 1200 away")
	-- 1.65s left, 1200 away (lands at 1.6): inside the 0.1s margin, too late.
	T.eq(R.LandsBeforeChannelEnds(R.ArrivalTime(1.0, 1200, 2000), 1.65), false, "1.65s left")
	T.eq(R.LandsBeforeChannelEnds(R.ArrivalTime(1.0, 1200, 2000), 1.71), true, "1.71s left")
	-- Cursed Crown can never stop a TP: 4.2s against 3.0s.
	T.eq(R.LandsBeforeChannelEnds(R.ArrivalTime(0.2, 0, nil, 4), 3.0), false, "Cursed Crown vs TP")
	-- Unknown or finished channel never counts.
	T.eq(R.LandsBeforeChannelEnds(0.25, 0), false, "left 0")
	T.eq(R.LandsBeforeChannelEnds(0.25, nil), false, "left nil")
	T.eq(R.LandsBeforeChannelEnds(0.25, 0.4, 0), true, "margin 0")
end)

T.test("track channel: time left from the first sighting", function()
	local R = rules()
	local memory = {}
	T.near(R.TrackChannel(memory, "lion", "lion_mana_drain", 5.0, 100.0), 5.0, 1e-9, "first seen")
	T.near(R.TrackChannel(memory, "lion", "lion_mana_drain", 5.0, 100.4), 4.6, 1e-9, "0.4s later")
	T.near(R.TrackChannel(memory, "lion", "lion_mana_drain", 5.0, 100.8), 4.2, 1e-9, "0.8s later")
	-- Another channel by the same hero starts over.
	T.near(R.TrackChannel(memory, "lion", "item_tpscroll", 3.0, 101.0), 3.0, 1e-9, "new ability")
	-- Not seen for more than 0.5s: a new channel.
	T.near(R.TrackChannel(memory, "lion", "item_tpscroll", 3.0, 102.0), 3.0, 1e-9, "gap")
	-- Never below 0.
	T.near(R.TrackChannel(memory, "lion", "item_tpscroll", 3.0, 102.3), 2.7, 1e-9, "running")
	T.eq(R.TrackChannel({ x = { name = "a", seenAt = 0, lastSeen = 9.9 } }, "x", "a", 3.0, 10.0), 0, "over")
end)

-- Compare two short lists element by element.
local function same(actual, expected, what)
	for i = 1, #expected do
		T.eq(actual[i], expected[i], what .. " [" .. i .. "]")
	end
end

T.test("bramble aim: the first (east) inner bramble grows on the target", function()
	local R = rules()
	-- Caster at the origin, target 800 east: cast 200 west of it (600 east), aim east, first bramble.
	local x, y, aim, index = R.BrambleAim(800, 0, 0, 0, 1000)
	same({ x, y, aim, index }, { 600, 0, "east", 0 }, "east")
	-- Target 1100 west (cast range 1000): east spot is 1300 away, north spot (-1100, -200) ~1118 too, west
	-- spot (-900, 0) is in range: aim west, third bramble.
	x, y, aim, index = R.BrambleAim(-1100, 0, 0, 0, 1000)
	same({ x, y, aim, index }, { -900, 0, "west", 2 }, "west")
	-- Target 1150 north: east spot (-200, 1150) ~1167 out, north spot (0, 950) in.
	x, y, aim, index = R.BrambleAim(0, 1150, 0, 0, 1000)
	same({ x, y, aim, index }, { 0, 950, "north", 1 }, "north")
	-- Target 1150 south: south spot (0, -950).
	x, y, aim = R.BrambleAim(0, -1150, 0, 0, 1000)
	same({ x, y, aim }, { 0, -950, "south" }, "south")
	-- Too far for any spot.
	T.eq(R.BrambleAim(1500, 0, 0, 0, 1000), nil, "out of range")
	-- Caster not at the origin.
	x, y, aim = R.BrambleAim(-3000, 2000, -3500, 2000, 1000)
	same({ x, y, aim }, { -3200, 2000, "east" }, "offset caster")
end)

T.test("bramble root time and the TP", function()
	local R = rules()
	-- Datafeed: cast point 0.3, grow 0.3, latch delay 0.1, 0.075 between brambles.
	T.near(R.BrambleRootTime(0.3, 0.3, 0.1, 0.075, 0), 0.7, 1e-9, "east bramble")
	T.near(R.BrambleRootTime(0.3, 0.3, 0.1, 0.075, 2), 0.85, 1e-9, "west bramble")
	-- A fresh TP (3.0s) is cancelled in time; one with 0.75s left is not (0.7 + 0.1 margin).
	T.eq(R.LandsBeforeChannelEnds(R.BrambleRootTime(0.3, 0.3, 0.1, 0.075, 0), 3.0), true, "fresh TP")
	T.eq(R.LandsBeforeChannelEnds(R.BrambleRootTime(0.3, 0.3, 0.1, 0.075, 0), 0.75), false, "0.75s left")
end)

T.test("root-cancellable list: from the game files", function()
	local R = rules()
	T.eq(R.ROOT_CANCELS.item_tpscroll.kind, "channel", "TP scroll")
	T.eq(R.ROOT_CANCELS.furion_teleportation.kind, "cast", "Teleportation cast point")
	-- Ordinary channels are not cancelled by roots (bramble_maze_Note0).
	T.eq(R.ROOT_CANCELS.crystal_maiden_freezing_field, nil, "Freezing Field")
	T.eq(R.ROOT_CANCELS.enigma_black_hole, nil, "Black Hole")
	for name, entry in pairs(R.ROOT_CANCELS) do
		T.ok(entry.kind == "channel" or entry.kind == "cast", name .. " kind")
		T.ok(type(entry.source) == "string" and #entry.source > 0, name .. " source")
	end
end)
