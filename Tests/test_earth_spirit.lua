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

T.test("earth spirit: no kick through or toward an enemy hero", function()
	local X = earthSpirit()
	-- He stands behind the ally, a melee enemy in front of it: the landing (500, 0) is 350 from the enemy
	-- (farther than the 150 now), but the ally would fly through it.
	T.eq(X.KickProblem(p(-120, 0), p(0, 0), 500, { p(150, 0) }, {}), "closer-to-enemy", "through the enemy")
	-- Enemy behind the ally (on his side): the kick sends the ally away.
	T.eq(X.KickProblem(p(100, 0), p(0, 0), 500, { p(250, 50) }, {}), nil, "enemy behind, kick away")
	-- Enemy far to the side of the kick line: not in the path.
	T.eq(X.KickProblem(p(-100, 0), p(0, 0), 500, { p(100, 600), p(-300, 0) }, {}), nil, "enemy off the path")
	-- Tower near the landing.
	T.eq(X.KickProblem(p(100, 0), p(0, 0), 500, { p(250, 0) }, { p(-1000, 0) }), "tower", "into tower range")
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

T.test("earth spirit: a retreating ally at high HP needs a hero hitting it before a save", function()
	local X = earthSpirit()
	-- Game 063, 1:15: Weaver at 97% HP, retreating, enemies near but not hit by a hero.
	T.eq(X.AllyNeedsSave(0.97, true, false, 2), false, "retreating, high HP, not hit")
	T.eq(X.AllyNeedsSave(0.97, true, true, 2), true, "retreating, high HP, hit by a hero")
	T.eq(X.AllyNeedsSave(0.97, false, true, 2), false, "not retreating, high HP")
	T.eq(X.AllyNeedsSave(0.4, false, false, 1), true, "low HP with an enemy on it")
	T.eq(X.AllyNeedsSave(0.4, false, false, 0), false, "low HP, nobody near")
end)

T.test("earth spirit: kick bearing is degrees from east, counter-clockwise", function()
	local X = earthSpirit()
	T.near(X.Bearing(p(0, 0), p(100, 0)), 0, 0.01, "east")
	T.near(X.Bearing(p(0, 0), p(0, 100)), 90, 0.01, "north")
	T.near(X.Bearing(p(0, 0), p(0, -100)), 270, 0.01, "south")
end)

local function zeus()
	Stub.reset({ hero = "npc_dota_hero_zuus", slot = 2 })
	local ok, result = Stub.load("BotsLib/hero_zuus")
	if not ok then
		error(tostring(result), 0)
	end
	return result
end

T.test("zeus: Nimbus waits in an ally's fight while Zeus or a hurt ally may need it to flee", function()
	local X = zeus()
	T.eq(X.NimbusFightHold(800, 1.0, 0.9), "zeus-near", "Zeus in the fight")
	T.eq(X.NimbusFightHold(3000, 0.4, 0.9), "ally-low", "an ally there under 50%")
	T.eq(X.NimbusFightHold(800, 0.4, 0.45), nil, "target under 50%: cast")
	T.eq(X.NimbusFightHold(3000, 0.9, 0.9), nil, "far fight, healthy allies: cast")
end)

T.test("zeus: no Heavenly Jump into more enemies than allies or away from the target", function()
	local X = zeus()
	T.eq(X.JumpEngageProblem(false, 1, 2, 0, 1), "not-ahead", "target behind")
	-- Game 063, 15:38: four enemies, Zeus alone.
	T.eq(X.JumpEngageProblem(true, 4, 1, 1, 1), "outnumbered", "4 v 1")
	T.eq(X.JumpEngageProblem(true, 2, 2, 2, 1), "landing-crowded", "two enemies at the landing")
	T.eq(X.JumpEngageProblem(true, 1, 2, 1, 1), nil, "even at the landing")
end)
