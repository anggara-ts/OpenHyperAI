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
-- noStart: set the stub up without the first think (the test changes the enemy before the brew decision).
local function startBrew(X, startTime, noStart)
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
	state.enemy = enemy
	Stub.time = startTime
	if noStart then
		return state
	end
	X.SkillsComplement()
	T.eq(state.brewing, true, "the brew started")
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

T.test("alchemist: a likely disable makes the brew go out early (pure rule)", function()
	local X = load()
	T.eq(X.ConcoctionThreat(1.0, {}), nil, "no threat")
	T.eq(X.ConcoctionThreat(0.5, { projectile = true }), "projectile", "a stun projectile on its way")
	T.eq(X.ConcoctionThreat(0.2, { projectile = true }), nil, "not in the first 0.3s")
	T.eq(X.ConcoctionThreat(1.0, { afterDisable = true }), "after-disable", "disabled earlier in this brew")
	T.eq(X.ConcoctionThreat(0.9, { afterDisable = true }), nil, "after-disable waits for 1.0s")
	T.eq(X.ConcoctionThreat(1.5, { enemyCast = true }), "enemy-cast", "an enemy casting at him")
	T.eq(X.ConcoctionThreat(1.4, { enemyCast = true }), nil, "enemy-cast waits for 1.5s")
	T.eq(X.ConcoctionThreat(2.0, { hpLost = 0.25 }), "hp-drop", "a quarter of his HP in a second")
	T.eq(X.ConcoctionThreat(2.0, { hpLost = 0.2 }), nil, "a smaller HP loss")
	T.eq(X.ConcoctionThreat(2.0, nil), nil, "nil threat table")
end)

T.test("alchemist: which gates a throw may override, and which casts wait for the brew", function()
	local X = load()
	T.eq(X.ConcoctionGateSoft("casting"), true, "another cast")
	T.eq(X.ConcoctionGateSoft("queued"), true, "a queued order")
	T.eq(X.ConcoctionGateSoft("channeling"), false, "a channel (maybe an escape Town Portal)")
	T.eq(X.ConcoctionGateSoft("stunned"), false, "stunned")
	T.eq(X.ConcoctionGateSoft("silenced"), false, "silenced")
	T.eq(X.ConcoctionGateSoft("other"), false, "invulnerable and the rest")
	T.eq(X.ConcoctionHoldsCast("acid_spray", false, 0), false, "not brewing: nothing held")
	T.eq(X.ConcoctionHoldsCast("acid_spray", true, 0.5), true, "Acid Spray waits for the whole brew")
	T.eq(X.ConcoctionHoldsCast("berserk_potion", true, 4.0), true, "Berserk Potion too")
	T.eq(X.ConcoctionHoldsCast("chemical_rage", true, 2.9), false, "Chemical Rage early in the brew")
	T.eq(X.ConcoctionHoldsCast("chemical_rage", true, 3.0), true, "Chemical Rage held from 3.0s")
end)

T.test("alchemist: no kill brew a hit finishes, no brew while retreat wants him out", function()
	local X = load()
	-- Game 063, 3721: Lina at 8%, the kill throw at 0.3s, she died in its cast point.
	T.eq(X.ConcoctionKillTooEasy(0.3), true, "lethal at 0.3s brewed: attack instead")
	T.eq(X.ConcoctionKillTooEasy(0.5), true, "at the 0.5s edge")
	T.eq(X.ConcoctionKillTooEasy(2.6), false, "needs 2.6s of brewing, out of attack range: brew")
	T.eq(X.ConcoctionKillTooEasy(2.6, 0.7), true, "two hits 0.7s apart kill it: attack")
	T.eq(X.ConcoctionKillTooEasy(2.6, 1.8), false, "his attacks need 1.8s: brew")
	-- Game 063, t=2060: retreat 1.10 (line 383, Retreat.ShouldRun) in the start second.
	T.eq(X.ConcoctionRetreatWanted(1.10, 383, 0.0), true, "run line")
	T.eq(X.ConcoctionRetreatWanted(0.55, 210, 0.1), true, "desire 0.5 or more")
	T.eq(X.ConcoctionRetreatWanted(0.2, 374, 0.1), true, "run line 374 at a low desire")
	T.eq(X.ConcoctionRetreatWanted(0.3, 210, 0.1), false, "low desire, no run")
	T.eq(X.ConcoctionRetreatWanted(1.10, 383, 2.0), false, "published 2s ago: stale")
	T.eq(X.ConcoctionRetreatWanted(nil, nil, nil), false, "never published")
end)

T.test("alchemist: the first open think after a stun during the brew throws it (stun-threat)", function()
	local X = load()
	local state = startBrew(X, 700)
	state.enemy._hp = 1000 -- not a kill
	local stunned = true
	state.bot.IsStunned = function()
		return stunned
	end
	Stub.time = 701.2
	X.SkillsComplement()
	T.eq(#state.orders, 0, "stunned: no order")
	stunned = false
	Stub.time = 701.5
	X.SkillsComplement()
	T.eq(#state.orders, 1, "thrown on the first open think")
	T.eq(state.orders[1].target, state.enemy, "at the brew target")
	T.ok(
		printedLine(
			"concoction throw why=stun%-threat target=npc_dota_hero_%S+ dist=400 brewed=1.5s illusion=false threat=after%-disable gate=open"
		),
		"throw line names the threat"
	)
end)

T.test("alchemist: a queued order does not hold the throw back when the brew target is gone", function()
	local X = load()
	local state = startBrew(X, 800)
	state.enemy._hp = 1000
	-- The brew target dies; another enemy hero stands at 500.
	state.enemy._alive = false
	local other = Stub.teams[GetOpposingTeam()][2]
	other._loc = state.bot._loc + Vector(500, 0, 0)
	other._hp = 1000
	state.bot.NumQueuedActions = function()
		return #state.orders == 0 and 1 or 0
	end
	Stub.time = 801.2
	X.SkillsComplement()
	T.eq(#state.orders, 1, "thrown through the queued order")
	T.eq(state.orders[1].target, other, "at the other hero")
	T.ok(printedLine("concoction throw why=target%-lost target=npc_dota_hero_%S+ dist=500 brewed=1.2s"), "throw line")
	T.ok(printedLine("gate=queued:"), "the throw line names the queued gate")
end)

T.test("alchemist: a brew whose end is seen long after (he died meanwhile) reads died", function()
	local X = load()
	local state = startBrew(X, 900)
	state.enemy._hp = 1000
	state.enemy._loc = state.bot._loc + Vector(9000, 0, 0)
	Stub.time = 901
	X.SkillsComplement()
	-- Dead: the usage file runs no hero script; back after respawn.
	state.brewing = false
	Stub.time = 966
	X.SkillsComplement()
	T.ok(printedLine("concoction brew%-end outcome=died brewed=1.0s seen=1.0s"), "died, not unknown")
	-- Game 064, t=1711: brewed=39.2s counted the time he was dead; that goes to lineDelay= now.
	T.ok(printedLine("outcome=died .* lineDelay=65.0s"), "the time dead is lineDelay=")
end)

T.test("concoction rules: no kill brew on a hero that dies before a throw lands", function()
	Stub.reset({ hero = "npc_dota_hero_alchemist" })
	local R = require(GetScriptDirectory() .. "/FuncLib/systems/concoction_rules")
	-- Game 064, t=2056: Tiny at 7% (about 140 HP), 280 away, Hoodwink's Acorn Shot on its way.
	T.eq(R.FinishedWithoutBrew(140, 160, true, 0), "own-hit", "his next hit kills it")
	T.eq(R.FinishedWithoutBrew(140, 160, false, 0), nil, "out of his reach: his hit does not count")
	T.eq(R.FinishedWithoutBrew(140, 90, true, 150), "ally-damage", "our damage in flight kills it")
	T.eq(R.FinishedWithoutBrew(140, 90, true, 100), nil, "neither kills it: brew")
	T.eq(R.FinishedWithoutBrew(0, 90, true, 0), nil, "no HP read: no rule")
end)

-- A low enemy that runs from him (moving, not facing him): the "runner" escape kind.
local function makeRunner(enemy)
	enemy.GetAnimActivity = function()
		return ACTIVITY_RUN
	end
	enemy.IsFacingLocation = function()
		return false
	end
end

T.test("alchemist: no kill brew on a running hero his next hit kills (game 064)", function()
	local X = load()
	local state = startBrew(X, 1000, true)
	state.bot.GetAttackDamage = function()
		return 160
	end
	state.enemy._hp = 140
	state.enemy._loc = state.bot._loc + Vector(250, 0, 0)
	makeRunner(state.enemy)
	X.SkillsComplement()
	T.eq(state.brewing, false, "no brew")
	T.ok(
		printedLine("concoction no%-brew why=finish%-hit by=own%-hit rule=kill target=npc_dota_hero_%S+ hp=140 hit=160"),
		"line"
	)
	T.ok(printedLine("inReach=true allyPending=0 proj=0 hits=0 dist=250 escape=runner"), "the runner was not exempt")
end)

T.test("alchemist: no kill brew on a hero our damage in flight kills", function()
	local X = load()
	local state = startBrew(X, 1100, true)
	state.enemy._hp = 140
	state.enemy._loc = state.bot._loc + Vector(500, 0, 0)
	local ally = Stub.teams[GetTeam()][2]
	ally.GetAttackDamage = function()
		return 150
	end
	state.enemy.GetIncomingTrackingProjectiles = function()
		return { { is_attack = true, caster = ally, location = state.enemy._loc } }
	end
	X.SkillsComplement()
	T.eq(state.brewing, false, "no brew")
	T.ok(printedLine("concoction no%-brew why=finish%-hit by=ally%-damage rule=kill"), "line")
	T.ok(printedLine("allyPending=150 proj=150 hits=0"), "the pending damage is printed, from the projectile")
end)

T.test("alchemist: target lost mid-brew with a queued order: logged once, walks to the next hero", function()
	local X = load()
	local state = startBrew(X, 1200)
	state.enemy._hp = 1000
	state.enemy._alive = false
	local other = Stub.teams[GetOpposingTeam()][2]
	other._loc = state.bot._loc + Vector(1000, 0, 0)
	other._hp = 1000
	state.bot.NumQueuedActions = function()
		return 1
	end
	Stub.time = 1201.5
	X.SkillsComplement()
	T.eq(#state.orders, 0, "nobody in throw range: no throw")
	T.ok(state.movedTo ~= nil, "keep-range walks him to the other hero through the queued order")
	T.ok(
		printedLine(
			"concoction target%-lost brewed=1.5s target=npc_dota_hero_%S+ nearest=npc_dota_hero_%S+ nearestDist=1000 plan=chase"
		),
		"target-lost line"
	)
	local count = 0
	Stub.time = 1202
	X.SkillsComplement()
	for _, line in ipairs(Stub.printed) do
		if string.find(line, "concoction target%-lost") then
			count = count + 1
		end
	end
	T.eq(count, 1, "once per brew")
end)

T.test("alchemist: a low hero his allies are finishing: save the brew for another hero, else help", function()
	local X = load()
	local bot = GetBot()
	local brew = bot:GetAbilityByName("alchemist_unstable_concoction")
	local throw = bot:GetAbilityByName("alchemist_unstable_concoction_throw")
	local values = { brew_explosion = 5.5, brew_time = 5.0, max_damage = 360, move_speed = 16 }
	brew.GetSpecialValueFloat = function(_, key)
		return values[key] or 0
	end
	brew.GetSpecialValueInt = brew.GetSpecialValueFloat
	brew.IsFullyCastable = function()
		return true
	end
	throw.GetCastRange = function()
		return 775
	end
	throw.IsHidden = function()
		return true
	end
	local started = false
	bot.Action_UseAbility = function(_, ability)
		if ability:GetName() == "alchemist_unstable_concoction" then
			started = true
		end
	end
	for _, enemy in ipairs(Stub.teams[GetOpposingTeam()]) do
		enemy._loc = bot._loc + Vector(9000, 0, 0)
	end
	local ally
	for _, unit in ipairs(Stub.teams[GetTeam()]) do
		if unit ~= bot then
			unit._loc = bot._loc + Vector(-9000, 0, 0)
			ally = ally or unit
		end
	end
	-- 15% HP at 400: max damage kills it, so the kill rule would start a brew.
	local enemy = Stub.teams[GetOpposingTeam()][1]
	enemy._loc = bot._loc + Vector(400, 0, 0)
	enemy._hp = 150
	-- Another enemy hero 1000 away (within 1200): the brew is kept for it.
	local other = Stub.teams[GetOpposingTeam()][2]
	other._loc = bot._loc + Vector(0, 1000, 0)
	enemy.GetActualIncomingDamage = function(_, damage)
		return damage
	end
	ally._loc = enemy._loc + Vector(200, 0, 0)
	-- Game 063: only an ally attacking the target counts.
	ally.GetAttackTarget = function()
		return enemy
	end
	Stub.time = 1000
	X.SkillsComplement()
	T.eq(started, false, "an ally is on it, another enemy hero is near: no brew, kept for that one")
	T.ok(
		printedLine(
			"concoction no%-brew why=save%-for%-next rule=kill target=npc_dota_hero_%S+ hp=0.15 allies=1 other=npc_dota_hero_"
		),
		"save line"
	)
	-- Nobody else near: the cooldown is free, a help brew (thrown at once).
	other._loc = bot._loc + Vector(9000, 0, 0)
	Stub.time = 1010
	X.SkillsComplement()
	T.eq(started, true, "nobody else near: help brew")
	T.ok(
		printedLine("concoction help%-start rule=kill target=npc_dota_hero_%S+ hp=0.15 allies=1 kind=held"),
		"help line"
	)
	-- The ally stops hitting it and walks off: the plain kill brew starts.
	started = false
	ally.GetAttackTarget = function()
		return nil
	end
	ally._loc = bot._loc + Vector(-9000, 0, 0)
	Stub.time = 1030
	X.SkillsComplement()
	T.eq(started, true, "no ally on it: the kill brew starts")
	T.ok(printedLine("concoction start why=kill"), "kill start")
end)

-- Maintainer, 2026-11-21: a hero the allies are finishing that can get away gets an early brew; one that can't is
-- left to them when another enemy hero is near. FuncLib/systems/concoction_rules.lua.
T.test("concoction rules: stun by brew time, land time, save-or-help, when the help throw goes", function()
	Stub.reset({ hero = "npc_dota_hero_alchemist" })
	local R = require(GetScriptDirectory() .. "/FuncLib/systems/concoction_rules")
	-- Datafeed 7.42 hero 73: min_stun 0.25, max_stun 1.7 / 3.2 (levels 1 / 4), brew_time 5.0.
	T.near(R.StunAt(0, 0.25, 3.2, 5), 0.25, 1e-9, "no brew: min stun")
	T.near(R.StunAt(5, 0.25, 3.2, 5), 3.2, 1e-9, "full brew: max stun")
	T.near(R.StunAt(2.5, 0.25, 1.7, 5), 0.975, 1e-9, "half way, level 1")
	T.near(R.StunAt(9, 0.25, 1.7, 5), 1.7, 1e-9, "capped at max")
	-- Throw cast point 0.2, projectile_speed 900 (npc_heroes.txt, 7.42).
	T.near(R.LandTime(450), 0.7, 1e-9, "450 away: 0.2 + 0.5")
	T.eq(R.AlliesFinishing(0.35, 1), true, "35% with an ally on it")
	T.eq(R.AlliesFinishing(0.45, 2), false, "45%: not finishing")
	T.eq(R.AlliesFinishing(0.2, 0), false, "no ally attacking it")
	T.eq(R.FinishingPlan("runner", true), "help", "a runner: help even with another hero near")
	T.eq(R.FinishingPlan("tp", false), "help", "a Town Portal: help")
	T.eq(R.FinishingPlan(nil, true), "save", "held, another hero near: save the brew")
	T.eq(R.FinishingPlan(nil, false), "held", "held, nobody else: throw early anyway")
	-- Runner / Blink: once the stun covers ~1s. Level 4: 0.25 + 2.95 * b / 5 >= 1.0 from b ~1.27s.
	T.eq(R.HelpThrowNow("runner", 1.0, R.StunAt(1.0, 0.25, 3.2, 5), nil, 0.7), false, "1.0s brewed: 0.84s stun")
	T.eq(R.HelpThrowNow("runner", 1.3, R.StunAt(1.3, 0.25, 3.2, 5), nil, 0.7), true, "1.3s brewed: 1.02s stun")
	T.eq(R.HelpThrowNow("blink", 3.0, R.StunAt(3.0, 0.25, 1.7, 5), nil, 0.7), true, "level 1 needs 2.6s")
	-- Town Portal (3.0s channel, items.txt): the stun must land before it ends, with 0.6s to spare.
	T.eq(R.HelpThrowNow("tp", 0.5, 0.4, 2.5, 0.7), false, "2.5s left, lands in 0.7: wait for a longer stun")
	T.eq(R.HelpThrowNow("tp", 1.3, 0.6, 1.2, 0.7), true, "1.2s left: throw")
	T.eq(R.HelpThrowNow("tp", 0.3, 0.3, 0, 0.7), true, "time left unknown: throw")
	T.eq(R.HelpThrowNow("held", 0.1, 0.3, nil, 0.7), false, "the brew has just started")
	T.eq(R.HelpThrowNow("held", 0.3, 0.3, nil, 0.7), true, "held: at once")
end)

T.test("alchemist: a held hero the allies are finishing, nobody else near: help brew thrown at once", function()
	local X = load()
	local bot = GetBot()
	local target = Stub.teams[GetOpposingTeam()][1]
	for _, unit in ipairs(Stub.teams[GetTeam()]) do
		if unit ~= bot then
			unit._loc = bot._loc + Vector(-9000, 0, 0)
		end
	end
	local ally = Stub.teams[GetTeam()][2] ~= bot and Stub.teams[GetTeam()][2] or Stub.teams[GetTeam()][3]
	ally._loc = bot._loc + Vector(500, 0, 0)
	ally.GetAttackTarget = function()
		return target
	end
	local state = startBrew(X, 300)
	T.eq(state.enemy, target, "the brew target")
	T.ok(printedLine("concoction start why=help target=npc_dota_hero_"), "start why=help")
	Stub.time = 300.1
	X.SkillsComplement()
	T.eq(#state.orders, 0, "0.1s brewed: not yet")
	Stub.time = 300.3
	X.SkillsComplement()
	T.eq(#state.orders, 1, "0.3s brewed: thrown")
	T.eq(state.orders[1].target, target, "at the hero the allies are finishing")
	-- Fallbacks min_stun 0.25, max_stun 1.7 (the stub ability has no values): 0.25 + 1.45 * 0.3 / 5 = 0.34.
	T.ok(
		printedLine("concoction throw why=help%-early target=npc_dota_hero_%S+ dist=400 brewed=0.3s .* stun=0.34"),
		"line"
	)
end)

-- Game 063 (t=1834): a Zeus TP read 3.00 left, the full channel; is the read the time left?
T.test("concoction rules: an enemy TP's time left, from a read that drops or from when it was seen", function()
	Stub.reset({ hero = "npc_dota_hero_alchemist" })
	local R = require(GetScriptDirectory() .. "/FuncLib/systems/concoction_rules")
	T.eq(R.TpReadIsReal(2.8, 2.5, 0.3), true, "dropped by the time between the reads: real")
	T.eq(R.TpReadIsReal(3.0, 3.0, 0.3), false, "stayed at 3.0: the full duration, not the time left")
	T.eq(R.TpReadIsReal(3.0, nil, nil), nil, "no second read yet")
	-- 7.42 items.txt: item_tpscroll AbilityChannelTime 3.0, item_travel_boots_2 tp_channel_time 2.
	T.eq(R.TP_CHANNEL, 3.0, "scroll channel")
	T.eq(R.TP_CHANNEL_BOOTS2, 2.0, "Boots of Travel 2 channel")
	T.near(R.TpTimeLeft(100, 101, 3.0, 1.9, true), 1.9, 1e-9, "a real read is used")
	T.near(R.TpTimeLeft(100, 101, 3.0, 3.0, false), 2.0, 1e-9, "a read that does not drop: time since seen")
	T.near(R.TpTimeLeft(100, 100.1, 3.0, 3.0, nil), 2.9, 1e-9, "not proven yet: time since seen")
	T.near(R.TpTimeLeft(100, 100.5, 3.0, 1.0, nil), 1.0, 1e-9, "the read is an upper bound (seen late)")
	T.near(R.TpTimeLeft(100, 101.5, 2.0, 0, nil), 0.5, 1e-9, "Boots 2, no read")
	T.near(R.TpTimeLeft(100, 104, 3.0, 0, nil), 0, 1e-9, "never below 0")
end)

-- Game 065: invisibility escapes, disables mid-brew, the retreat hold.
T.test("concoction rules: spells ready, escape and disable names, retreat brew, disable risk, retreat hold", function()
	Stub.reset({ hero = "npc_dota_hero_alchemist" })
	local R = require(GetScriptDirectory() .. "/FuncLib/systems/concoction_rules")
	T.eq(R.SpellReady(1, 0, 75, 300), true, "learned, off cooldown, mana")
	T.eq(R.SpellReady(0, 0, 75, 300), false, "not learned")
	T.eq(R.SpellReady(2, 4.5, 75, 300), false, "on cooldown")
	T.eq(R.SpellReady(2, 0, 150, 100), false, "not enough mana")
	T.eq(R.SpellReady(2, 0, 150, nil), true, "mana unknown: not checked")
	-- The game 065 escapes and disables.
	for _, name in ipairs({
		"clinkz_wind_walk",
		"nyx_assassin_vendetta",
		"dark_willow_shadow_realm",
		"item_invis_sword",
	}) do
		T.eq(R.ESCAPE_NAMES[name], true, name .. " is an escape")
	end
	T.eq(R.ESCAPE_NAMES["riki_permanent_invisibility"], nil, "a passive is not")
	for _, name in ipairs({ "nyx_assassin_impale", "tiny_avalanche", "death_prophet_silence", "item_cyclone" }) do
		T.eq(R.DISABLE_NAMES[name], true, name .. " is a disable")
	end
	T.eq(R.DISABLE_NAMES["alchemist_unstable_concoction"], nil, "not his own brew")
	T.eq(R.DISABLE_NAMES["clinkz_wind_walk"], nil, "an escape is not a disable")
	-- Game 065 t=126: a retreat brew held to 5.5s.
	T.eq(R.RetreatBrewThrowNow("retreat", 1.4, true), false, "1.4s: not yet")
	T.eq(R.RetreatBrewThrowNow("retreat", 1.5, true), true, "1.5s, a hero in range")
	T.eq(R.RetreatBrewThrowNow("retreat", 3.0, false), false, "nobody in range")
	T.eq(R.RetreatBrewThrowNow("engage", 3.0, true), false, "not a retreat brew")
	T.eq(R.DisableRisk(1.9, "tiny_avalanche", 0), nil, "before 2s")
	T.eq(R.DisableRisk(2.0, "tiny_avalanche", 0), "disable-ready", "a stun ready near him")
	T.eq(R.DisableRisk(2.5, nil, 0.12), "hit", "lost 12% of his HP within 1s")
	T.eq(R.DisableRisk(2.5, nil, 0.05), nil, "a light hit, nothing ready")
	-- Game 065 t=1198-1199: the block lasted one think.
	T.eq(R.RetreatHeld(true, nil, 100), true, "wanted now")
	T.eq(R.RetreatHeld(false, 99, 100), true, "wanted 1s ago")
	T.eq(R.RetreatHeld(false, 97.9, 100), false, "wanted 2.1s ago")
	T.eq(R.RetreatHeld(false, nil, 100), false, "never wanted")
end)

-- A ready spell in an enemy's ability slot (stub): learned, off cooldown, cheap.
local function giveSpell(enemy, slot, name)
	local ability = Stub.newAbility(name, enemy, false)
	ability.cooldown = 0
	ability.GetLevel = function()
		return 1
	end
	ability.GetCooldownTimeRemaining = function(self)
		return self.cooldown
	end
	ability.GetManaCost = function()
		return 50
	end
	enemy._slots[slot] = ability
	enemy.GetMana = function()
		return 500
	end
	return ability
end

T.test("alchemist: no brew on a hero with Skeleton Walk ready, unless it is stunned or on cooldown", function()
	local X = load()
	local state = startBrew(X, 1300, true)
	giveSpell(state.enemy, 5, "clinkz_wind_walk")
	X.SkillsComplement()
	T.eq(state.brewing, false, "Skeleton Walk ready: no kill brew")
	T.ok(
		printedLine("concoction no%-brew why=escape%-ready rule=kill target=npc_dota_hero_%S+ escape=clinkz_wind_walk"),
		"line"
	)
	local stunned = true
	state.enemy.IsStunned = function()
		return stunned
	end
	Stub.time = 1300.5
	X.SkillsComplement()
	T.eq(state.brewing, true, "stunned: it can't walk away, the brew starts")
	-- A fresh setup with the walk on cooldown.
	X = load()
	state = startBrew(X, 1400, true)
	local walk = giveSpell(state.enemy, 5, "clinkz_wind_walk")
	walk.cooldown = 12
	X.SkillsComplement()
	T.eq(state.brewing, true, "on cooldown: the brew starts")
	T.ok(
		printedLine("enemy%-spell%-cd hero=npc_dota_hero_%S+ spell=clinkz_wind_walk cd=12.0 level=1"),
		"cooldown read logged"
	)
	T.ok((state.bot._noTpUntil or -1) > Stub.time, "no Town Portal while brewing")
end)

T.test("alchemist: a stun ready near him throws the brew at 2s (disable-risk)", function()
	local X = load()
	local state = startBrew(X, 1500)
	state.enemy._hp = 1000 -- not a kill
	giveSpell(state.enemy, 0, "nyx_assassin_impale")
	Stub.time = 1501.9
	X.SkillsComplement()
	T.eq(#state.orders, 0, "1.9s: held")
	Stub.time = 1502.0
	X.SkillsComplement()
	T.eq(#state.orders, 1, "2.0s: thrown")
	T.eq(state.orders[1].target, state.enemy, "at the brew target")
	T.ok(
		printedLine(
			"concoction throw why=disable%-risk target=npc_dota_hero_%S+ dist=400 brewed=2.0s .*threat=disable%-ready:nyx_assassin_impale@npc_dota_hero_"
		),
		"line names the spell"
	)
end)

T.test("alchemist: silenced after the brew target is gone, he still walks to the next hero", function()
	local X = load()
	local state = startBrew(X, 1600)
	state.enemy._hp = 1000
	state.enemy._alive = false
	local other = Stub.teams[GetOpposingTeam()][2]
	other._loc = state.bot._loc + Vector(1000, 0, 0)
	other._hp = 1000
	state.bot.IsSilenced = function()
		return true
	end
	Stub.time = 1601.5
	X.SkillsComplement()
	T.ok(state.movedTo ~= nil, "a move order toward the other hero")
	T.ok(printedLine("concoction chase%-gate gate=silenced cast=%S+ brewed=1.5s walked=yes"), "chase-gate line")
	T.ok(
		printedLine("concoction keep%-range target=npc_dota_hero_%S+ dist=1000 brewed=1.5s .*gate=silenced"),
		"keep-range"
	)
end)

T.test("alchemist: a retreat that wanted him out holds the brew for 2s", function()
	local X = load()
	local state = startBrew(X, 1700, true)
	state.bot._retreatDesireNow, state.bot._retreatLineNow, state.bot._retreatDesireAt = 0.51, 533, 1700
	X.SkillsComplement()
	T.eq(state.brewing, false, "retreat 0.51: no brew")
	state.bot._retreatDesireNow, state.bot._retreatDesireAt = 0.2, 1701
	Stub.time = 1701
	X.SkillsComplement()
	T.eq(state.brewing, false, "1s later at 0.2: still held")
	T.ok(printedLine("concoction no%-brew why=retreat%-wanted rule=kill .*held=true"), "held line")
	state.bot._retreatDesireAt = 1702.5
	Stub.time = 1702.5
	X.SkillsComplement()
	T.eq(state.brewing, true, "2.5s after the last want: the brew starts")
end)
