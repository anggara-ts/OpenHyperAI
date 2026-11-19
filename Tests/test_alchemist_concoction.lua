-- Alchemist's Unstable Concoction (#34): the pure helpers behind the brew start, the kill throw and the
-- "losing the last target" throw in BotsLib/hero_alchemist.lua.
local T = ...
local Stub = T.stub

local function load()
	Stub.reset({ hero = "npc_dota_hero_alchemist" })
	local ok, hero = Stub.load("BotsLib/hero_alchemist")
	if not ok then
		error(tostring(hero), 0)
	end
	return hero
end

T.test("alchemist: concoction damage grows with the brew time", function()
	local X = load()
	-- Game data: min_damage 0, max_damage 150/220/290/360 at brew_time 5.0.
	T.near(X.ConcoctionDamageAt(360, 0, 5), 0, 1e-9, "nothing brewed")
	T.near(X.ConcoctionDamageAt(360, 2.5, 5), 180, 1e-9, "half brewed")
	T.near(X.ConcoctionDamageAt(360, 5, 5), 360, 1e-9, "full brew")
	T.near(X.ConcoctionDamageAt(360, 5.4, 5), 360, 1e-9, "past the brew time stays at the maximum")
	T.near(X.ConcoctionDamageAt(360, -1, 5), 0, 1e-9, "a negative time is no damage")
	T.near(X.ConcoctionDamageAt(360, 2, 0), 360, 1e-9, "no brew time known: the maximum")
	T.near(X.ConcoctionDamageAt(360, 2, nil), 360, 1e-9, "nil brew time: the maximum")
end)

T.test("alchemist: the gap to a target only grows when the runner is faster", function()
	local X = load()
	T.near(X.ConcoctionGapAfter(600, 350, 300, 2), 700, 1e-9, "runner 50 faster for 2s")
	T.near(X.ConcoctionGapAfter(600, 300, 350, 2), 600, 1e-9, "a faster chaser keeps the distance")
	T.near(X.ConcoctionGapAfter(600, 300, 300, 5), 600, 1e-9, "equal speeds")
	T.near(X.ConcoctionGapAfter(400, 450, 0, 2), 1300, 1e-9, "a chaser that stands still")
end)

T.test("alchemist: seconds until a target leaves the throw range", function()
	local X = load()
	-- Game data: the throw's cast range is 775.
	T.near(X.ConcoctionSecondsInRange(700, 150, 775), 0.5, 1e-9, "75 left at 150 per second")
	T.near(X.ConcoctionSecondsInRange(650, 50, 775), 2.5, 1e-9, "a slow drift")
	T.eq(X.ConcoctionSecondsInRange(700, 0, 775), math.huge, "not moving apart")
	T.eq(X.ConcoctionSecondsInRange(700, -200, 775), math.huge, "closing in")
	T.eq(X.ConcoctionSecondsInRange(775, 100, 775), 0, "at the edge")
	T.eq(X.ConcoctionSecondsInRange(900, -300, 775), 0, "already out of range")
end)

T.test("alchemist: SkillsComplement and the brew tracker run when he is not brewing", function()
	local X = load()
	local brewing = X.TrackConcoctionBrew()
	T.eq(brewing, false, "not brewing at load")
	X.SkillsComplement()
	T.eq(X.ConcoctionKeepRange(1), false, "no throw target: no keep-range move")
end)

-- A brew in the stub: the throw ability shows in the slot (not hidden, castable, range 775) from `startTime`.
local function startBrew(X, startTime)
	local bot = GetBot()
	local brew = bot:GetAbilityByName("alchemist_unstable_concoction")
	local throw = bot:GetAbilityByName("alchemist_unstable_concoction_throw")
	local state = { brewing = false, bot = bot, orders = {} }
	local values = { brew_explosion = 5.5, brew_time = 5.0, max_damage = 360, move_speed = 16 }
	brew.GetSpecialValueFloat = function(_, key)
		return values[key] or 0
	end
	brew.GetSpecialValueInt = brew.GetSpecialValueFloat
	brew.IsFullyCastable = function()
		return not state.brewing
	end
	throw.GetCastRange = function()
		return 775
	end
	throw.IsHidden = function()
		return not state.brewing
	end
	throw.IsFullyCastable = function()
		return state.brewing
	end
	bot.GetCurrentMovementSpeed = function()
		return 300
	end
	bot.Action_UseAbilityOnEntity = function(_, ability, target)
		state.orders[#state.orders + 1] = { ability = ability:GetName(), target = target }
	end
	bot.Action_MoveToLocation = function(_, location)
		state.movedTo = location
	end
	-- Every enemy far away; a test moves the ones it needs.
	for _, enemy in ipairs(Stub.teams[GetOpposingTeam()]) do
		enemy._loc = bot._loc + Vector(9000, 0, 0)
	end
	-- An enemy at 400 that max damage kills starts the brew ("kill" rule).
	local enemy = Stub.teams[GetOpposingTeam()][1]
	enemy._loc = bot._loc + Vector(400, 0, 0)
	enemy.GetActualIncomingDamage = function(_, damage)
		return damage
	end
	enemy._hp = 300
	bot.Action_UseAbility = function(_, ability)
		if ability:GetName() == "alchemist_unstable_concoction" then
			state.brewing = true
		end
	end
	Stub.time = startTime
	X.SkillsComplement()
	T.eq(state.brewing, true, "the brew started")
	state.enemy = enemy
	return state
end

local function printedLine(pattern)
	for _, line in ipairs(Stub.printed) do
		if string.find(line, pattern) then
			return line
		end
	end
	return nil
end

T.test("alchemist: a kill throw goes out as soon as the brew's damage kills, and the end reads thrown", function()
	local X = load()
	local state = startBrew(X, 100)
	T.ok(printedLine("concoction start why=kill target=npc_dota_hero_"), "start line names the rule and target")
	-- 300 HP against 360 max damage: lethal at 5.0 * 300 / (360 * 0.9) = 4.63s brewed.
	Stub.time = 104
	X.SkillsComplement()
	T.eq(#state.orders, 0, "4.0s brewed: 259 damage with the margin, no throw yet")
	Stub.time = 104.7
	X.SkillsComplement()
	T.eq(#state.orders, 1, "4.7s brewed: thrown")
	T.eq(state.orders[1].ability, "alchemist_unstable_concoction_throw", "the throw ability")
	T.eq(state.orders[1].target, state.enemy, "at the brew target")
	T.ok(printedLine("concoction throw why=kill target=npc_dota_hero_%S+ dist=400 brewed=4.7s"), "throw line")
	state.brewing = false
	Stub.time = 104.9
	X.SkillsComplement()
	T.ok(printedLine("concoction brew%-end outcome=thrown brewed=4.9s seen=4.7s rule=kill"), "end line: thrown")
	T.ok(printedLine("lastThrow=kill@4.7"), "end line names the last throw order")
end)

T.test("alchemist: a brew held to the deadline with nobody in range reads self-explode", function()
	local X = load()
	local state = startBrew(X, 200)
	state.enemy._loc = state.bot._loc + Vector(9000, 0, 0)
	for step = 1, 55 do
		Stub.time = 200 + step * 0.1
		X.SkillsComplement()
	end
	T.eq(#state.orders, 0, "nothing to throw at")
	T.ok(printedLine("concoction throw why=no%-target brewed=5.0s"), "no-target line at 5.0s")
	state.brewing = false
	Stub.time = 205.53
	X.SkillsComplement()
	T.ok(
		printedLine("concoction brew%-end outcome=self%-explode brewed=5.5s seen=5.5s rule=kill"),
		"end line: self-explode"
	)
end)

T.test("alchemist: the last target leaving the range gets the throw early", function()
	local X = load()
	local state = startBrew(X, 300)
	state.enemy._hp = 1000 -- not a kill any more
	-- 640 -> 700 in 0.3s (200 per second): 75 left, out of range in under a second.
	state.enemy._loc = state.bot._loc + Vector(640, 0, 0)
	Stub.time = 301
	X.SkillsComplement()
	T.eq(#state.orders, 0, "first distance sample only")
	state.enemy._loc = state.bot._loc + Vector(700, 0, 0)
	Stub.time = 301.3
	X.SkillsComplement()
	T.eq(#state.orders, 1, "thrown at 1.3s brewed")
	T.ok(printedLine("concoction throw why=last%-target target=npc_dota_hero_%S+ dist=700 brewed=1.3s"), "throw line")
end)

T.test("alchemist: while brewing with the target out of the start distance he walks after it", function()
	local X = load()
	local state = startBrew(X, 400)
	state.enemy._hp = 1000
	state.enemy._loc = state.bot._loc + Vector(650, 0, 0)
	Stub.time = 401
	X.SkillsComplement()
	T.eq(#state.orders, 0, "no throw: the target is not leaving")
	T.ok(state.movedTo ~= nil, "a move order toward the target")
	T.ok(printedLine("concoction keep%-range target=npc_dota_hero_%S+ dist=650 brewed=1.0s mode=%S+ move=yes"), "line")
	-- A hero within the start distance (600): no move.
	state.movedTo = nil
	state.enemy._loc = state.bot._loc + Vector(500, 0, 0)
	Stub.time = 402
	X.SkillsComplement()
	T.eq(state.movedTo, nil, "in range: no move order")
end)

T.test("alchemist: a brew that ends around the deadline with no throw order reads self-explode", function()
	local X = load()
	local state = startBrew(X, 500)
	state.enemy._loc = state.bot._loc + Vector(9000, 0, 0)
	-- The hero script stops being run at 5.3s brewed (the usage file returned before it); the end is seen later.
	for step = 1, 53 do
		Stub.time = 500 + step * 0.1
		X.SkillsComplement()
	end
	T.eq(#state.orders, 0, "no throw order in this brew")
	state.brewing = false
	Stub.time = 505.52
	X.SkillsComplement()
	T.ok(printedLine("concoction brew%-end outcome=self%-explode brewed=5.5s seen=5.3s rule=kill"), "self-explode")
	T.ok(printedLine("lastThrow=none@0.0"), "no throw order named")
end)

T.test("alchemist: a brew that ends early without a throw order reads unknown, not thrown", function()
	local X = load()
	local state = startBrew(X, 600)
	state.enemy._hp = 1000
	Stub.time = 602
	X.SkillsComplement()
	T.eq(#state.orders, 0, "no throw order yet")
	state.brewing = false
	Stub.time = 602.1
	X.SkillsComplement()
	T.ok(printedLine("concoction brew%-end outcome=unknown brewed=2.1s"), "unknown")
end)
