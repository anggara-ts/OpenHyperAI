-- BotsLib/hero_earth_spirit.lua: an ally save (pull or kick) must land the ally away from danger (#47).
local T = ...
local Stub = T.stub

local function earthSpirit()
	Stub.reset({ hero = "npc_dota_hero_earth_spirit", slot = 2 })
	local ok, result = Stub.load("BotsLib/hero_earth_spirit")
	if not ok then
		error(tostring(result), 0)
	end
	return result
end

local function p(x, y)
	return { x = x, y = y }
end

T.test("earth spirit: pull lands the ally farther from the enemies", function()
	local X = earthSpirit()
	local problem = X.SaveLandingProblem
	local ally, enemies = p(0, 0), { p(300, 0) }
	-- Earth Spirit 600 behind the ally, away from the enemy: safe.
	T.eq(problem(ally, p(-600, 0), enemies, {}, {}), nil, "away from the enemy")
	-- Earth Spirit on the enemy's side: the ally would land closer.
	T.eq(problem(ally, p(500, 300), enemies, {}, {}), "closer-to-enemy", "toward the enemy")
	-- A step sideways (360 from the enemy instead of 300): under the 100 gain, not a real save.
	T.eq(problem(ally, p(0, 200), enemies, {}, {}), "closer-to-enemy", "sideways, no gain")
end)

T.test("earth spirit: no pull when Earth Spirit has enemies on him", function()
	local X = earthSpirit()
	local ally, enemies = p(0, 0), { p(300, 0) }
	T.eq(X.SaveLandingProblem(ally, p(-600, 0), enemies, {}, { p(-300, 0) }), "es-in-danger", "enemy 300 from ES")
	T.eq(X.SaveLandingProblem(ally, p(-600, 0), enemies, {}, { p(-1200, 0) }), nil, "enemy 600 from ES")
end)

T.test("earth spirit: no save into enemy tower range", function()
	local X = earthSpirit()
	local ally, enemies = p(0, 0), { p(300, 0) }
	T.eq(X.SaveLandingProblem(ally, p(-600, 0), enemies, { p(-1200, 0) }, nil), "tower", "tower 600 from landing")
	T.eq(X.SaveLandingProblem(ally, p(-600, 0), enemies, { p(-1600, 0) }, nil), nil, "tower 1000 from landing")
end)

T.test("earth spirit: kick lands along the line from him through the ally", function()
	local X = earthSpirit()
	local landing = X.KickLanding(p(-100, 0), p(0, 0), 600)
	T.near(landing.x, 600, 0.01, "x")
	T.near(landing.y, 0, 0.01, "y")
	-- Standing on the enemy side (negative distance puts the point on the near side).
	local stand = X.KickLanding(p(300, 0), p(0, 0), -100)
	T.near(stand.x, 100, 0.01, "stand x")
	T.eq(X.KickLanding(p(0, 0), p(0, 0), 600), nil, "no direction when on top of the ally")
	-- Kick from the enemy side: the ally lands 600 away from the enemy at 300.
	T.eq(X.SaveLandingProblem(p(0, 0), X.KickLanding(p(100, 0), p(0, 0), 600), { p(300, 0) }, {}, nil), nil, "away")
	T.eq(
		X.SaveLandingProblem(p(0, 0), X.KickLanding(p(-100, 0), p(0, 0), 600), { p(300, 0) }, {}, nil),
		"closer-to-enemy",
		"into the enemy"
	)
end)

-- The save scan and Zeus's global Nimbus pick run against the stub API (no "stub missing" call).
T.test("earth spirit and zeus: save scan and nimbus finish pick run", function()
	local X = earthSpirit()
	local bot = Stub.bot
	local ally, enemy
	for _, unit in ipairs(Stub.heroes) do
		if unit ~= bot and unit._team == bot._team and ally == nil then
			ally = unit
		elseif unit._team ~= bot._team and enemy == nil then
			enemy = unit
		end
	end
	bot._loc = Stub.Vector(0, 0, 0)
	ally._loc, ally._hp = Stub.Vector(100, 0, 0), 200
	enemy._loc = Stub.Vector(-200, 0, 0)
	local kind = X.ConsiderAllySave()
	T.ok(kind == nil or kind == "kick" or kind == "kick-move" or kind == "pull", "save kind " .. tostring(kind))

	Stub.reset({ hero = "npc_dota_hero_zuus", slot = 2 })
	local ok, Zeus = Stub.load("BotsLib/hero_zuus")
	if not ok then
		error(tostring(Zeus), 0)
	end
	for _, unit in ipairs(Stub.heroes) do
		if unit._team ~= Stub.bot._team then
			unit._hp = 100
		end
	end
	local target = Zeus.NimbusFinishTarget()
	T.ok(target == nil or target._team ~= Stub.bot._team, "finish target is an enemy")
end)
