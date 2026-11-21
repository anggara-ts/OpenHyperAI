-- FuncLib/systems/farm_rules.lua (camp side, enemy camps while behind, idle fallback, camp keep window) and
-- the camp side in FuncLib/data/site.lua (Site.IsEnemyCamp, Site.SurveyCamps).
local T = ...

local function rules()
	T.stub.reset({ hero = "npc_dota_hero_dazzle" })
	return require(GetScriptDirectory() .. "/FuncLib/systems/farm_rules")
end

-- Tower points from game 062 and the games before it: every [OHA-FARM] enemy-half-withdraw to= is one of our
-- T1-T3 moved 400 toward our fountain (mode_farm_generic.lua NearestOwnTower). Radiant bottom T3 never showed
-- up there; it is the Dire top T3 mirrored. The game reads the real towers at runtime.
local RADIANT_TOWERS = {
	{ x = -6350, y = 1456 },
	{ x = -6510, y = -1271 },
	{ x = -6596, y = -3808 },
	{ x = -1524, y = -1507 },
	{ x = -3291, y = -3026 },
	{ x = -4908, y = -4441 },
	{ x = 4460, y = -6378 },
	{ x = -760, y = -6261 },
	{ x = -3946, y = -5845 },
}
local DIRE_TOWERS = {
	{ x = -4875, y = 6047 },
	{ x = 271, y = 6036 },
	{ x = 3946, y = 5845 },
	{ x = 1128, y = 1116 },
	{ x = 2991, y = 2550 },
	{ x = 4557, y = 4039 },
	{ x = 6300, y = -1841 },
	{ x = 6435, y = 782 },
	{ x = 6406, y = 3426 },
}

-- The 26 camps of game 062 (every camp position in its [OHA-FARM] lines) and their side by position.
local CAMPS = {
	{ -1454, -3356, "radiant" },
	{ -1983, -4815, "radiant" },
	{ -2415, -8402, "radiant" },
	{ -4013, 992, "radiant" },
	{ -5024, -96, "radiant" },
	{ -720, -7696, "radiant" },
	{ -8023, -1838, "radiant" },
	{ -8313, -553, "radiant" },
	{ 186, -5197, "radiant" },
	{ 3978, -5027, "radiant" },
	{ 4520, -8336, "radiant" },
	{ 6712, -7632, "radiant" },
	{ -2596, 3850, "dire" },
	{ -3911, 4829, "dire" },
	{ -4228, 8140, "dire" },
	{ -4824, 3915, "dire" },
	{ -852, 4940, "dire" },
	{ 1064, 2580, "dire" },
	{ 1224, 4176, "dire" },
	{ 2016, 7896, "dire" },
	{ 336, 7696, "dire" },
	{ 3392, -1408, "dire" },
	{ 4352, 48, "dire" },
	{ 4649, -3699, "dire" },
	{ 7928, -120, "dire" },
	{ 8430, 1263, "dire" },
}

T.test("camp side: every game 062 camp by position, edge and corner camps clear of the river", function()
	local R = rules()
	local river = {}
	for _, camp in ipairs(CAMPS) do
		local side, margin = R.CampSide(camp[1], camp[2], RADIANT_TOWERS, DIRE_TOWERS)
		local name = camp[1] .. "," .. camp[2]
		T.eq(side, camp[3], name)
		if margin < R.RIVER_MARGIN then
			river[#river + 1] = name
		end
	end
	-- Radiant dropped these as enemy camps in game 062 ([OHA-FARM] enemy-camp-drop): ours, by a wide margin.
	for _, camp in ipairs({ { -8023, -1838 }, { -8313, -553 }, { -2415, -8402 }, { 186, -5197 } }) do
		local _, margin = R.CampSide(camp[1], camp[2], RADIANT_TOWERS, DIRE_TOWERS)
		T.ok(margin > 4000, camp[1] .. "," .. camp[2] .. " margin " .. margin)
	end
	-- Only the river camps are close calls (they go by the engine's team, see DecideCampSide).
	table.sort(river)
	T.eq(table.concat(river, " "), "-2596,3850 -4824,3915 4649,-3699", "river camps")
end)

T.test("camp side: a corner camp past our safe-lane T1 is ours (the closer-Ancient test says enemy)", function()
	local R = rules()
	local side, margin = R.CampSide(6712, -7632, RADIANT_TOWERS, DIRE_TOWERS)
	T.eq(side, "radiant", "6712,-7632")
	T.ok(margin > 1500, "clear margin, got " .. margin)
	-- Site.radiant_ancient / Site.dire_ancient: the corner measures closer to the Dire Ancient.
	local function dist(ax, ay, bx, by)
		return math.sqrt((ax - bx) ^ 2 + (ay - by) ^ 2)
	end
	T.ok(dist(6712, -7632, 5517, 4981) < dist(6712, -7632, -5860, -5328), "closer Ancient would say Dire")
end)

T.test("camp side: no side without both teams' towers", function()
	local R = rules()
	T.eq(R.CampSide(0, 0, {}, {}), nil, "no towers")
	T.eq(R.CampSide(0, 0, RADIANT_TOWERS, {}), nil, "no Dire towers")
end)

T.test("camp side decided: position clear of the river, the engine's team by the river", function()
	local R = rules()
	-- -4824,3915 and 4649,-3699 mirror each other but both measure Dire: the engine's team settles them.
	T.eq(R.DecideCampSide("dire", 761, "radiant"), "radiant", "river camp, engine says Radiant")
	T.eq(R.DecideCampSide("dire", 200, "dire"), "dire", "river camp, engine agrees")
	T.eq(R.DecideCampSide("dire", 761, nil), "dire", "river camp, no engine team")
	-- Clear of the river the position wins, whatever the engine says.
	local side, by = R.DecideCampSide("radiant", 6874, "dire")
	T.eq(side, "radiant", "edge camp")
	T.eq(by, "position", "decided by")
	T.eq(R.DecideCampSide(nil, 0, "dire"), "dire", "no towers")
end)

T.test("enemy camp while behind: open only behind our deeper wave, off the behind lane, nobody seen", function()
	local R = rules()
	-- Our wave 3000 from their Ancient, the camp 4000: wave is deeper.
	T.eq(R.EnemyCampOpenWhileBehind(3000, 4000, false, 0), true, "deeper wave, other lane, nobody seen")
	T.eq(R.EnemyCampOpenWhileBehind(3000, 4000, true, 0), false, "camp's lane is the behind lane")
	T.eq(R.EnemyCampOpenWhileBehind(3000, 4000, false, 1), false, "enemy seen near the camp")
	-- No slack while behind (the normal cover check allows 500).
	T.eq(R.EnemyCampOpenWhileBehind(4200, 4000, false, 0), false, "wave 200 behind the camp")
	T.eq(R.EnemyCampOpenWhileBehind(4000, 4000, false, 0), false, "wave level with the camp")
	local _, why = R.EnemyCampOpenWhileBehind(3000, 4000, true, 2)
	T.eq(why, "lane-behind", "lane first")
end)

T.test("enemy camp covered (not behind): wave at most 500 behind the camp", function()
	local R = rules()
	T.eq(R.EnemyCampCovered(4400, 4000), true, "400 behind")
	T.eq(R.EnemyCampCovered(4600, 4000), false, "600 behind")
end)

T.test("idle: fires after 10s under 0.15 doing nothing, once per stretch start", function()
	local R = rules()
	local state = {}
	local fire
	for t = 0, 9 do
		fire = R.IdleStep(state, 1800 + t, 0.10, false)
		T.eq(fire, false, "t+" .. t)
	end
	local idleFor
	fire, idleFor = R.IdleStep(state, 1810, 0.06, false)
	T.eq(fire, true, "10s")
	T.near(idleFor, 10, 0.01, "idle for")
end)

T.test("idle: a busy moment, a real desire or a gap starts over", function()
	local R = rules()
	-- One call per second from `from` to `to`; returns the last result.
	local function run(state, from, to, desire, busy)
		local fire
		for t = from, to do
			fire = R.IdleStep(state, t, desire, busy)
		end
		return fire
	end
	local state = {}
	run(state, 100, 108, 0.10, false)
	T.eq(R.IdleStep(state, 109, 0.10, true), false, "attacking")
	T.eq(run(state, 110, 119, 0.10, false), false, "9s after the attack")
	T.eq(R.IdleStep(state, 120, 0.10, false), true, "10s after the attack")
	-- Desire at the threshold is not idle.
	state = {}
	run(state, 200, 205, 0.10, false)
	T.eq(R.IdleStep(state, 206, 0.15, false), false, "0.15 resets")
	T.eq(run(state, 207, 216, 0.10, false), false, "9s after the reset")
	T.eq(R.IdleStep(state, 217, 0.10, false), true, "10s after the reset")
	-- A gap of more than 2s between calls (the desire returned early) starts over.
	state = {}
	R.IdleStep(state, 300, 0.10, false)
	R.IdleStep(state, 301, 0.10, false)
	T.eq(R.IdleStep(state, 311, 0.10, false), false, "gap of 10s: start over")
	T.eq(R.IdleStep(state, 321, 0.10, false), false, "gap again")
end)

T.test("idle hold: ends on arrival, a higher mode or timeout", function()
	local R = rules()
	T.eq(R.IdleHoldEnds(10, 0, 3000, nil, 0.3), nil, "walking")
	T.eq(R.IdleHoldEnds(10, 0, 500, nil, 0.3), "arrived", "there")
	T.eq(R.IdleHoldEnds(10, 0, 3000, 0.5, 0.3), "other-mode", "push wants more")
	T.eq(R.IdleHoldEnds(10, 0, 3000, 0.2, 0.3), nil, "a lower mode does not end it")
	T.eq(R.IdleHoldEnds(30, 0, 3000, nil, 0.3), "timeout", "25s")
end)

T.test("camp keep window: no switch to a closer camp within 5s, a hard reason switches at once", function()
	local R = rules()
	T.eq(R.CanSwitchCamp(102, 100, false), false, "2s after the pick")
	T.eq(R.CanSwitchCamp(105, 100, false), true, "5s")
	T.eq(R.CanSwitchCamp(102, 100, true), true, "cleared / unsafe")
	T.eq(R.CanSwitchCamp(102, nil, false), true, "nothing picked")
end)

-- Site.IsEnemyCamp read `camp.team` off farm's { idx, cattr } wrapper (nil), so every camp was an enemy camp.
T.test("Site.IsEnemyCamp: side by position (engine team by the river), through farm's wrapper too", function()
	T.stub.reset({ hero = "npc_dota_hero_dazzle", team = TEAM_RADIANT })
	for team, list in pairs({ [TEAM_RADIANT] = RADIANT_TOWERS, [TEAM_DIRE] = DIRE_TOWERS }) do
		for i, spot in ipairs(list) do
			T.stub.towers[team][i - 1] = T.stub.newUnit({
				name = "npc_dota_tower",
				team = team,
				loc = Vector(spot.x, spot.y, 0),
			})
		end
	end
	local spawners = {
		-- The engine's team is deliberately wrong on the first one: clear of the river the position decides.
		{ type = "large", team = TEAM_DIRE, location = Vector(-8023, -1838, 0) },
		{ type = "ancient", team = TEAM_DIRE, location = Vector(8430, 1263, 0) },
		-- A river camp that measures Dire by 761: the engine's Radiant decides.
		{ type = "medium", team = TEAM_RADIANT, location = Vector(-4824, 3915, 0) },
	}
	_G.GetNeutralSpawners = function()
		return spawners
	end
	local Site = require(GetScriptDirectory() .. "/FuncLib/data/site")
	T.eq(Site.IsEnemyCamp(spawners[1]), false, "edge camp on our half, raw spawner")
	T.eq(Site.IsEnemyCamp({ idx = 1, cattr = spawners[1] }), false, "same camp through the wrapper")
	T.eq(Site.IsEnemyCamp({ idx = 2, cattr = spawners[2] }), true, "Dire corner camp")
	T.eq(Site.IsEnemyCamp({ idx = 3, cattr = spawners[3] }), false, "river camp, engine says ours")
	T.eq(Site.IsAncientCamp({ idx = 2, cattr = spawners[2] }), true, "ancient through the wrapper")
	T.eq(Site.IsLargeCamp({ idx = 1, cattr = spawners[1] }), true, "large through the wrapper")
	-- Survey: once per team, one line per camp plus a summary; all 18 towers found.
	Site.SurveyCamps(T.stub.bot)
	Site.SurveyCamps(T.stub.bot)
	local lines, sum = 0, nil
	for _, line in ipairs(T.stub.printed) do
		if string.find(line, "[OHA-CAMP]", 1, true) then
			lines = lines + 1
			if string.find(line, "survey-sum", 1, true) then
				sum = line
			end
		end
	end
	T.eq(lines, 4, "three camps and a summary, once")
	T.ok(sum ~= nil and string.find(sum, "towers=18", 1, true) ~= nil, "towers: " .. tostring(sum))
	-- Position vs engine: the edge camp and the river camp differ, the corner camp agrees.
	T.ok(sum ~= nil and string.find(sum, "agree=1 disagree=2", 1, true) ~= nil, "summary: " .. tostring(sum))
end)

-- Game 063: farm dropped its camp on every mode end and re-picked the nearest camp from where the bot stood
-- (1334 camp switches, 92 back-and-forth pairs within 60s). A softly dropped camp is picked again for 30s.
T.test("camp memory: a camp dropped on mode end is picked again within 30s unless far off or a hard reason", function()
	local R = rules()
	T.eq(R.ReuseDroppedCamp(110, "pick", "mode-end", 100, 1500, 900), true, "mode end 10s ago, camp near")
	T.eq(R.ReuseDroppedCamp(110, "pick", "mode-not-suitable", 100, 1500, 900), true, "mode not suitable")
	T.eq(R.ReuseDroppedCamp(110, "pick", "withdraw", 100, 1500, nil), true, "withdraw, no other camp")
	T.eq(R.ReuseDroppedCamp(131, "pick", "mode-end", 100, 1500, 900), false, "older than 30s")
	T.eq(R.ReuseDroppedCamp(110, "pick", "low-hp", 100, 1500, 900), false, "low hp is a hard drop")
	T.eq(R.ReuseDroppedCamp(110, "cleared", "mode-end", 100, 1500, 900), false, "cleared wants another camp")
	T.eq(R.ReuseDroppedCamp(110, "pick", "mode-end", 100, 6000, 900), false, "far across the map (TP)")
	T.eq(R.ReuseDroppedCamp(110, "pick", "mode-end", nil, 1500, 900), false, "nothing remembered")
end)
