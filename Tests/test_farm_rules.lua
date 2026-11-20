-- FuncLib/systems/farm_rules.lua (camp side, enemy camps while behind, idle fallback, camp keep window) and
-- the camp side in FuncLib/data/site.lua (Site.IsEnemyCamp, Site.SurveyCamps).
local T = ...

local function rules()
	T.stub.reset({ hero = "npc_dota_hero_dazzle" })
	return require(GetScriptDirectory() .. "/FuncLib/systems/farm_rules")
end

-- Tower layout for the tests: rough T1-T3 spots (not game data; the game reads the real towers at runtime),
-- Radiant bottom-left, Dire its mirror through the middle.
local RADIANT_TOWERS = {
	{ x = -6200, y = 1800 },
	{ x = -6100, y = -900 },
	{ x = -6600, y = -3500 },
	{ x = -1650, y = -1500 },
	{ x = -3600, y = -2700 },
	{ x = -4600, y = -4100 },
	{ x = 5100, y = -5900 },
	{ x = -350, y = -6250 },
	{ x = -3950, y = -6100 },
}
local DIRE_TOWERS = {}
for i, tower in ipairs(RADIANT_TOWERS) do
	DIRE_TOWERS[i] = { x = -tower.x, y = -tower.y }
end

T.test("camp side: game 062 edge camps on the Radiant half are Radiant's", function()
	local R = rules()
	-- Radiant dropped these as enemy camps in game 062 ([OHA-FARM] enemy-camp-drop).
	for _, camp in ipairs({ { -8023, -1838 }, { -8313, -553 }, { -2415, -8402 }, { 186, -5197 } }) do
		local side = R.CampSide(camp[1], camp[2], RADIANT_TOWERS, DIRE_TOWERS)
		T.eq(side, "radiant", camp[1] .. "," .. camp[2])
	end
	-- And the Dire ones Dire dropped (8430,1263 and 2016,7896).
	for _, camp in ipairs({ { 8430, 1263 }, { 7928, -120 }, { 2016, 7896 } }) do
		local side = R.CampSide(camp[1], camp[2], RADIANT_TOWERS, DIRE_TOWERS)
		T.eq(side, "dire", camp[1] .. "," .. camp[2])
	end
end)

T.test("camp side: a corner camp past our safe-lane T1 is ours (the closer-Ancient test says enemy)", function()
	local R = rules()
	local side, margin = R.CampSide(6712, -7632, RADIANT_TOWERS, DIRE_TOWERS)
	T.eq(side, "radiant", "6712,-7632")
	T.ok(margin > 1000, "clear margin, got " .. margin)
	-- Site.radiant_ancient / Site.dire_ancient: the corner measures closer to the Dire Ancient.
	local function dist(ax, ay, bx, by)
		return math.sqrt((ax - bx) ^ 2 + (ay - by) ^ 2)
	end
	T.ok(dist(6712, -7632, 5517, 4981) < dist(6712, -7632, -5860, -5328), "closer Ancient would say Dire")
end)

T.test("camp side: no towers gives no side", function()
	local R = rules()
	T.eq(R.CampSide(0, 0, {}, {}), nil, "no towers")
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
T.test("Site.IsEnemyCamp: side by position, through farm's wrapper too", function()
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
		-- The engine's team is deliberately wrong on the first one: the position decides.
		{ type = "large", team = TEAM_DIRE, location = Vector(-8023, -1838, 0) },
		{ type = "ancient", team = TEAM_DIRE, location = Vector(8430, 1263, 0) },
	}
	_G.GetNeutralSpawners = function()
		return spawners
	end
	local Site = require(GetScriptDirectory() .. "/FuncLib/data/site")
	T.eq(Site.IsEnemyCamp(spawners[1]), false, "edge camp on our half, raw spawner")
	T.eq(Site.IsEnemyCamp({ idx = 1, cattr = spawners[1] }), false, "same camp through the wrapper")
	T.eq(Site.IsEnemyCamp({ idx = 2, cattr = spawners[2] }), true, "Dire corner camp")
	T.eq(Site.IsAncientCamp({ idx = 2, cattr = spawners[2] }), true, "ancient through the wrapper")
	T.eq(Site.IsLargeCamp({ idx = 1, cattr = spawners[1] }), true, "large through the wrapper")
	-- Survey: once per team, one line per camp plus a summary.
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
	T.eq(lines, 3, "two camps and a summary, once")
	T.ok(sum ~= nil and string.find(sum, "agree=1 disagree=1", 1, true) ~= nil, "summary: " .. tostring(sum))
end)
