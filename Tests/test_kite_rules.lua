-- FuncLib/systems/kite_rules.lua: the safe window between attacks, the step that keeps the target in range, and
-- the laning last-hit gate (#72).
local T = ...

local function rules()
	T.stub.reset({ hero = "npc_dota_hero_lina" })
	return require(GetScriptDirectory() .. "/FuncLib/systems/kite_rules")
end

T.test("kite window: never inside a wind-up, ends before the next one", function()
	local R = rules()
	-- 1.7s per attack, attack point 0.5 at attack speed 1.0: window 0.6 .. 1.1.
	local from, to = R.Window(1.7, 0.5, 1.0)
	T.near(from, 0.6, 1e-9, "from = point + 0.1")
	T.near(to, 1.1, 1e-9, "to = spa - point - 0.1")
	T.eq(R.InWindow(0.3, from, to), false, "wind-up still playing")
	T.eq(R.InWindow(0.8, from, to), true, "between attacks")
	T.eq(R.InWindow(1.2, from, to), false, "next wind-up may have started")
	-- A tiny attack point still counts as 0.25s.
	local fromFast = R.Window(1.0, 0.1, 2.0)
	T.near(fromFast, 0.35, 1e-9, "point at least 0.25")
end)

T.test("kite window: too fast to kite (Strafe, Mask of Madness)", function()
	local R = rules()
	-- Early game, 1.7s per attack, 300 speed: 0.5s gap, 150 units of room.
	local from, to = R.Window(1.7, 0.5, 1.0)
	T.eq((R.TooFast(from, to, 300)), false, "long gap kites")
	-- 0.6s per attack: the window is empty.
	from, to = R.Window(0.6, 0.3, 2.0)
	local tooFast, gap = R.TooFast(from, to, 350)
	T.eq(tooFast, true, "fast attacks skip")
	T.ok(gap < 0.35, "gap below 0.35s")
	-- A 0.4s gap at 200 speed is only 80 units of room.
	T.eq((R.TooFast(0, 0.4, 200)), true, "slow hero, short room")
end)

T.test("kite step: attacker is the target keeps the old rule", function()
	local R = rules()
	-- Melee hero 150 away, our range 600: min(250, 600 - 150 - 30) = 250.
	local step, x, y = R.Step(0, 0, -150, 0, -150, 0, 600)
	T.near(step, 250, 1e-6, "full step")
	T.near(x, 250, 1e-6, "away from the attacker")
	T.near(y, 0, 1e-6, "straight away")
	-- 400 away with range 600: 600 - 400 - 30 = 170.
	step = R.Step(0, 0, -400, 0, -400, 0, 600)
	T.near(step, 170, 1e-6, "step shrinks to stay in range")
	-- 530 away: 40 left, below the 60 minimum.
	T.eq(R.Step(0, 0, -530, 0, -530, 0, 600), nil, "no room")
end)

T.test("kite step: lane creep hits us while we attack another creep", function()
	local R = rules()
	-- We attack a creep 500 to the east; a melee creep hits us from the west: stepping east only brings the target
	-- closer, so the full step.
	local step = R.Step(0, 0, -100, 0, 500, 0, 550)
	T.near(step, 250, 1e-6, "toward the target")
	-- Target to the west next to the attacker, range 550: like the hero case, 550 - 30 - 150 = 370 -> 250 cap.
	step = R.Step(0, 0, -100, 0, -150, 0, 550)
	T.near(step, 250, 1e-6, "away from both")
	-- Target 500 north, attacker west, range 550: the step east must keep |(s, -500)| <= 520 -> s <= 143.
	step = R.Step(0, 0, -100, 0, 0, 500, 550)
	T.near(step, math.sqrt(520 * 520 - 500 * 500), 1e-6, "sideways step limited by the target")
	-- Target already at the edge north: no room east.
	T.eq(R.Step(0, 0, -100, 0, 0, 518, 550), nil, "target at the edge")
	-- Attacker on top of us: no direction.
	T.eq(R.Step(0, 0, 0, 0, 100, 0, 550), nil, "no direction")
end)

T.test("kite: last hit due keeps the attack", function()
	local R = rules()
	T.eq(R.LastHitDue(60, 55, 0), false, "one hit short, nobody else hits it")
	T.eq(R.LastHitDue(60, 55, 10), true, "a creep hit lands first")
	T.eq(R.LastHitDue(50, 55, 0), true, "killable now")
	T.eq(R.LastHitDue(0, 55, 0), false, "dead creep")
	T.near(R.StepSeconds(250, 250), 1.0, 1e-9, "step time")
	T.near(R.StepSeconds(250, 0), 2.5, 1e-9, "a rooted or 0-speed read stays finite")
end)

-- The per-think hook with stub units: a ranged bot farming a camp, a melee neutral hitting it, between attacks.
local function kiteScene(attackerName, attackerTeam)
	local bot = T.stub.reset({ hero = "npc_dota_hero_lina", time = 300 })
	local SpecialUnits = require(GetScriptDirectory() .. "/FuncLib/hero/special_units")
	local here = bot:GetLocation()
	local attacker = T.stub.newUnit({ name = attackerName, team = attackerTeam, loc = here + Vector(-100, 0, 0) })
	local target = T.stub.newUnit({ name = attackerName, team = attackerTeam, loc = here + Vector(300, 0, 0) })
	attacker.GetAttackTarget = function()
		return bot
	end
	local moves = {}
	bot.GetAttackRange = function()
		return 600
	end
	bot.GetAttackTarget = function()
		return target
	end
	bot.GetActiveMode = function()
		return BOT_MODE_FARM
	end
	bot.WasRecentlyDamagedByCreep = function()
		return true
	end
	bot.GetAttackPoint = function()
		return 0.5
	end
	bot.GetAttackSpeed = function()
		return 1.0
	end
	bot.GetLastAttackTime = function()
		return GameTime() - 0.8
	end
	bot.Action_MoveToLocation = function(_, location)
		moves[#moves + 1] = location
	end
	return bot, SpecialUnits, attacker, target, moves
end

local function printedWith(word)
	for _, line in ipairs(T.stub.printed) do
		if string.find(line, word, 1, true) then
			return line
		end
	end
	return nil
end

T.test("kite hook: jungling steps back from the neutral and reports the result", function()
	local bot, SpecialUnits, attacker, _, moves = kiteScene("npc_dota_neutral_kobold", TEAM_NEUTRAL)
	bot.GetNearbyNeutralCreeps = function()
		return { attacker }
	end
	T.eq(SpecialUnits.TryKiteInAttack(bot), true, "stepped")
	T.eq(#moves, 1, "one move order")
	T.ok(moves[1].x > bot:GetLocation().x, "away from the neutral")
	T.ok(printedWith("kind=jungle") ~= nil, "from line names the kind")
	-- The bot walks the step (a think before the check), then the mode walks it back: still counts as moved.
	local start = bot._loc
	bot._loc = moves[1]
	SpecialUnits.KiteResultTick(bot)
	bot._loc = start
	-- A minute later: the result line for the jungle kind.
	T.stub.time = T.stub.time + 61
	bot.GetLastAttackTime = function()
		return GameTime() - 5
	end
	SpecialUnits.KiteResultTick(bot)
	local result = printedWith("result kind=jungle")
	T.ok(result ~= nil and string.find(result, "steps=1", 1, true) ~= nil, "result line: " .. tostring(result))
	T.ok(string.find(result or "", "moved=1", 1, true) ~= nil, "moved counted: " .. tostring(result))
end)

T.test("kite hook: laning keeps the attack when a last hit is due, and counts it in the baseline", function()
	local bot, SpecialUnits, attacker, target, moves = kiteScene("npc_dota_creep_badguys_melee", TEAM_DIRE)
	bot.GetActiveMode = function()
		return BOT_MODE_LANING
	end
	bot.GetAttackDamage = function()
		return 60
	end
	target._hp = 40
	target.GetActualIncomingDamage = function(_, damage)
		return damage
	end
	bot.GetNearbyLaneCreeps = function(_, _, enemy)
		return enemy and { attacker, target } or {}
	end
	T.eq(SpecialUnits.TryKiteInAttack(bot), false, "no step")
	T.eq(#moves, 0, "no move order")
	-- The same creep at full HP: the step goes ahead.
	bot._kitePending = nil
	target._hp = 550
	T.eq(SpecialUnits.TryKiteInAttack(bot), true, "stepped without a last hit")
	T.ok(printedWith("kind=lane") ~= nil, "from line names the kind")
	T.stub.time = T.stub.time + 61
	SpecialUnits.KiteResultTick(bot)
	local result = printedWith("result kind=lane")
	T.ok(
		result ~= nil and string.find(result, "no-step=last-hit:1", 1, true) ~= nil,
		"result line: " .. tostring(result)
	)
end)

T.test("kite hook: no step in retreat, while invisible or under a hold", function()
	local bot, SpecialUnits, attacker, _, moves = kiteScene("npc_dota_neutral_kobold", TEAM_NEUTRAL)
	bot.GetNearbyNeutralCreeps = function()
		return { attacker }
	end
	bot.GetActiveMode = function()
		return BOT_MODE_RETREAT
	end
	T.eq(SpecialUnits.TryKiteInAttack(bot), false, "retreat")
	bot.GetActiveMode = function()
		return BOT_MODE_FARM
	end
	bot._castHoldUntil = DotaTime() + 1
	T.eq(SpecialUnits.TryKiteInAttack(bot), false, "cast hold")
	bot._castHoldUntil = nil
	bot.IsInvisible = function()
		return true
	end
	T.eq(SpecialUnits.TryKiteInAttack(bot), false, "invisible")
	T.eq(#moves, 0, "no move order")
end)

T.test("kite hook: an error prints once as [OHA-ERROR] instead of vanishing in the call site's pcall", function()
	local bot, SpecialUnits = kiteScene("npc_dota_neutral_kobold", TEAM_NEUTRAL)
	bot.GetActiveMode = function()
		error("boom")
	end
	T.eq(SpecialUnits.TryKiteInAttack(bot), false, "no step")
	T.eq(SpecialUnits.TryKiteInAttack(bot), false, "no step again")
	local count = 0
	for _, line in ipairs(T.stub.printed) do
		if string.find(line, "[OHA-ERROR]", 1, true) and string.find(line, "kite: ", 1, true) then
			count = count + 1
		end
	end
	T.eq(count, 1, "printed once")
end)

T.test("chase step: toward a hero running out of range", function()
	local R = rules()
	-- Range 600; the hero is 590 away now and 700 away at our next attack: step 700 - 570 = 130 toward it.
	local step, x, y = R.ChaseStep(0, 0, 590, 0, 700, 0, 600)
	T.near(step, 130, 1e-6, "just enough")
	T.near(x, 130, 1e-6, "toward where it heads")
	T.near(y, 0, 1e-6, "straight")
	-- Running far: the step is capped at 250.
	T.near((R.ChaseStep(0, 0, 600, 0, 1000, 0, 600)), 250, 1e-6, "capped")
	-- Only a little out of range: at least the 60 minimum.
	T.near((R.ChaseStep(0, 0, 575, 0, 600, 0, 600)), 60, 1e-6, "minimum step")
	-- Running sideways at the same distance, or toward us: no chase.
	T.eq(select(4, R.ChaseStep(0, 0, 580, 0, 575, 100, 600)), "not-away", "sideways")
	T.eq(select(4, R.ChaseStep(0, 0, 580, 0, 300, 0, 600)), "not-away", "coming at us")
	-- In range now (game 064 t=2444: Zeus, range 380, stepped toward Death Prophet at 193): no step, even when the
	-- extrapolation says it runs off.
	T.eq(select(4, R.ChaseStep(0, 0, 193, 0, 680, 0, 380)), "in-range", "in range now")
	T.eq(select(4, R.ChaseStep(0, 0, 300, 0, 450, 0, 600)), "in-range", "stays in range")
	-- Already well past our range: the mode walks after it.
	T.eq(select(4, R.ChaseStep(0, 0, 900, 0, 1100, 0, 600)), "far", "too far")
end)

T.test("chase: next attack time and attack range between hulls", function()
	local R = rules()
	-- 1.7s per attack, 0.8s since the last one, wind-up 0.5s (from = 0.6): 0.9 + 0.5 = 1.4s.
	T.near(R.NextAttackIn(1.7, 0.8, 0.6), 1.4, 1e-9, "rest of the cycle plus the wind-up")
	T.near(R.NextAttackIn(1.7, 2.0, 0.6), 0.5, 1e-9, "attack overdue: only the wind-up")
	T.eq(R.InAttackRange(640, 600, 24, 24), true, "hulls count")
	T.eq(R.InAttackRange(660, 600, 24, 24), false, "out of range")
end)

-- A ranged bot attacking an enemy hero that runs east.
local function chaseScene()
	local bot, SpecialUnits, _, _, moves = kiteScene("npc_dota_neutral_kobold", TEAM_NEUTRAL)
	local here = bot:GetLocation()
	-- A real enemy hero of the stub game (a made-up one has no player and reads as an illusion).
	local runner = T.stub.teams[TEAM_DIRE][2]
	runner._loc = here + Vector(590, 0, 0)
	runner.GetExtrapolatedLocation = function()
		return here + Vector(700, 0, 0)
	end
	bot.GetAttackTarget = function()
		return runner
	end
	bot.WasRecentlyDamagedByCreep = function()
		return false
	end
	bot.GetActiveMode = function()
		return BOT_MODE_ATTACK
	end
	return bot, SpecialUnits, runner, moves
end

T.test("chase hook: steps toward a running hero and reports inRangeNext", function()
	local bot, SpecialUnits, runner, moves = chaseScene()
	T.eq(SpecialUnits.TryKiteInAttack(bot), true, "stepped")
	T.eq(#moves, 1, "one move order")
	T.ok(moves[1].x > bot:GetLocation().x, "toward the runner")
	T.ok(printedWith("kind=chase") ~= nil, "chase line")
	-- At the next attack the runner is 600 away: in range.
	runner._loc = bot:GetLocation() + Vector(600, 0, 0)
	T.stub.time = T.stub.time + 61
	SpecialUnits.KiteResultTick(bot)
	local result = printedWith("result kind=chase")
	T.ok(result ~= nil and string.find(result, "inRangeNext=1", 1, true) ~= nil, "result line: " .. tostring(result))
end)

T.test("chase hook: a melee unit hitting the bot wins, and no chase into a tower", function()
	local bot, SpecialUnits, runner, moves = chaseScene()
	-- The runner still in range, so the step away from the creep keeps it there.
	local runnerAt = runner._loc
	runner._loc = bot:GetLocation() + Vector(550, 0, 0)
	-- A melee creep hits the bot from the north: the step goes south, away from it, not east after the runner.
	local creep = T.stub.newUnit({ name = "npc_dota_creep_badguys_melee", loc = bot:GetLocation() + Vector(0, 100, 0) })
	creep.GetAttackTarget = function()
		return bot
	end
	bot.WasRecentlyDamagedByCreep = function()
		return true
	end
	bot.GetNearbyLaneCreeps = function(_, _, enemy)
		return enemy and { creep } or {}
	end
	T.eq(SpecialUnits.TryKiteInAttack(bot), true, "stepped")
	T.ok(moves[1].y < bot:GetLocation().y, "away from the creep, not after the runner")
	T.ok(printedWith("kind=lane") ~= nil, "lane step")
	-- No creep, but an enemy tower covers the step end: no chase, counted in the baseline.
	bot._kitePending = nil
	runner._loc = runnerAt
	bot.GetNearbyLaneCreeps = function()
		return {}
	end
	bot.WasRecentlyDamagedByCreep = function()
		return false
	end
	local tower = T.stub.newUnit({ name = "npc_dota_badguys_tower1_mid", loc = runner:GetLocation(), hero = false })
	tower.IsBuilding = function()
		return true
	end
	tower.GetAttackRange = function()
		return 700
	end
	bot.GetNearbyTowers = function()
		return { tower }
	end
	T.eq(SpecialUnits.TryKiteInAttack(bot), false, "no chase under the tower")
	T.eq(#moves, 1, "no new move order")
	T.stub.time = T.stub.time + 61
	SpecialUnits.KiteResultTick(bot)
	local result = printedWith("result kind=chase")
	T.ok(result ~= nil and string.find(result, "no-step=tower:1", 1, true) ~= nil, "result line: " .. tostring(result))
end)

T.test("chase: extrapolation horizon and outnumbered gate", function()
	local R = rules()
	T.eq(R.ChaseHorizon(4.83), 1.0, "game 064 t=2444: about 5s ahead capped at 1s")
	T.near(R.ChaseHorizon(0.4), 0.4, 1e-9, "the next attack comes first")
	T.eq(R.ChaseHorizon(-1), 0, "never negative")
	T.ok(R.ChaseOutnumbered(2, 1), "two enemies, alone")
	T.ok(R.ChaseOutnumbered(3, 2), "three against two")
	T.ok(not R.ChaseOutnumbered(2, 2), "allies match")
	T.ok(not R.ChaseOutnumbered(1, 1), "the target alone")
	T.ok(R.NOT_BASELINE.fast and not R.NOT_BASELINE.tower, "fast is not a baseline sample, a gate is")
	T.ok(R.NOT_BASELINE.outnumbered, "outnumbered runs outside the window: no baseline")
end)

T.test("chase hook: no step toward a group, counted as a no-step reason only", function()
	local bot, SpecialUnits, runner, moves = chaseScene()
	-- A second enemy hero next to the runner; the bot alone (the stub's allies stand 100 apart: move them away).
	for _, member in ipairs(T.stub.teams[bot:GetTeam()]) do
		if member ~= bot then
			member._loc = Vector(-7000, -7000, 0)
		end
	end
	local other = T.stub.teams[TEAM_DIRE][3]
	other._loc = runner:GetLocation() + Vector(100, 0, 0)
	T.eq(SpecialUnits.TryKiteInAttack(bot), false, "no chase")
	T.eq(#moves, 0, "no move order")
	T.ok(printedWith("chase-skip why=outnumbered") ~= nil, "chase-skip line")
	T.stub.time = T.stub.time + 61
	SpecialUnits.KiteResultTick(bot)
	local result = printedWith("result kind=chase")
	-- The gate runs before the window check now, so it is no like-for-like baseline (KiteRules.NOT_BASELINE).
	T.ok(result ~= nil and string.find(result, "base=0", 1, true) ~= nil, "not a baseline sample: " .. tostring(result))
	T.ok(string.find(result or "", "no-step=outnumbered:1", 1, true) ~= nil, "reason: " .. tostring(result))
end)

T.test("chase: the step ends before the next wind-up can start", function()
	local R = rules()
	-- Game 065 t=229 Dark Willow: window 0.35-0.73, since 0.37, a 250 step at about 300 speed takes 0.83s.
	T.near(R.FitChaseStep(250, 300, 0.73 - 0.37), 108, 1e-6, "cut to 0.36s of walking")
	T.eq(R.FitChaseStep(250, 300, 1.0), 250, "fits")
	T.eq(R.FitChaseStep(250, 300, 0.1), nil, "30 units: not worth an order")
	T.eq(R.FitChaseStep(250, 300, -0.2), nil, "window over")
end)

T.test("chase hook: the attack follows the step, at once when the target is back in range", function()
	local bot, SpecialUnits, runner, moves = chaseScene()
	local attacks, queued = {}, {}
	bot.Action_AttackUnit = function(_, unit)
		attacks[#attacks + 1] = unit
	end
	bot.ActionQueue_AttackUnit = function(_, unit)
		queued[#queued + 1] = unit
	end
	T.eq(SpecialUnits.TryKiteInAttack(bot), true, "stepped")
	T.eq(#moves, 1, "one move order")
	T.eq(queued[1], runner, "the attack is queued behind the step")
	-- Mid-step the runner is back in range and the bot is walking (no attack target): attack now.
	bot.GetAttackTarget = function()
		return nil
	end
	bot.GetTarget = function()
		return runner
	end
	runner._loc = bot:GetLocation() + Vector(560, 0, 0)
	T.stub.time = T.stub.time + 0.1
	SpecialUnits.KiteResultTick(bot)
	T.eq(attacks[1], runner, "re-attacked once in range")
	SpecialUnits.KiteResultTick(bot)
	T.eq(#attacks, 1, "once per step")
	-- The next frame through the whole hook: the runner still flees, no new step over the attack.
	runner.GetExtrapolatedLocation = function()
		return bot:GetLocation() + Vector(700, 0, 0)
	end
	T.stub.time = T.stub.time + 1 / 30
	T.eq(SpecialUnits.TryKiteInAttack(bot), false, "no step after the attack")
	T.eq(#moves, 1, "still the one move order")
	T.stub.time = T.stub.time + 61
	SpecialUnits.KiteResultTick(bot)
	local line = printedWith("chase-result")
	T.ok(line ~= nil and string.find(line, "result=attacked", 1, true) ~= nil, "result: " .. tostring(line))
	T.ok(string.find(line or "", "reattack=frame", 1, true) ~= nil, "which order: " .. tostring(line))
end)

T.test("chase hook: no re-attack on a target the mode left", function()
	local bot, SpecialUnits, runner = chaseScene()
	local attacks = {}
	bot.Action_AttackUnit = function(_, unit)
		attacks[#attacks + 1] = unit
	end
	bot.ActionQueue_AttackUnit = function() end
	T.eq(SpecialUnits.TryKiteInAttack(bot), true, "stepped")
	local other = T.stub.teams[TEAM_DIRE][3]
	bot.GetAttackTarget = function()
		return nil
	end
	bot.GetTarget = function()
		return other
	end
	runner._loc = bot:GetLocation() + Vector(560, 0, 0)
	T.stub.time = T.stub.time + 0.1
	SpecialUnits.KiteResultTick(bot)
	T.eq(#attacks, 0, "the mode targets another hero")
end)

T.test("chase hook: too-fast attacks are a no-step reason, not a baseline sample", function()
	local bot, SpecialUnits, _, moves = chaseScene()
	bot.GetSecondsPerAttack = function()
		return 0.5
	end
	T.eq(SpecialUnits.TryKiteInAttack(bot), false, "no chase")
	T.eq(SpecialUnits.TryKiteInAttack(bot), false, "no chase again, same attack cycle")
	T.eq(#moves, 0)
	T.stub.time = T.stub.time + 61
	SpecialUnits.KiteResultTick(bot)
	local result = printedWith("result kind=chase")
	T.ok(result ~= nil and string.find(result, "base=0", 1, true) ~= nil, "not in base=: " .. tostring(result))
	T.ok(string.find(result or "", "no-step=fast:1", 1, true) ~= nil, "counted once: " .. tostring(result))
end)

T.test("kite result: fromHit names a hit by the creep we stepped from", function()
	local bot, SpecialUnits, attacker, _, moves = kiteScene("npc_dota_neutral_kobold", TEAM_NEUTRAL)
	bot.GetNearbyNeutralCreeps = function()
		return { attacker }
	end
	local attackerLast = -50
	attacker.GetLastAttackTime = function()
		return attackerLast
	end
	T.eq(SpecialUnits.TryKiteInAttack(bot), true, "stepped")
	T.eq(#moves, 1)
	-- The neutral releases an attack on the bot after the step.
	attackerLast = GameTime() + 0.1
	T.stub.time = T.stub.time + 0.2
	SpecialUnits.KiteResultTick(bot)
	T.stub.time = T.stub.time + 61
	SpecialUnits.KiteResultTick(bot)
	local result = printedWith("result kind=jungle")
	T.ok(result ~= nil and string.find(result, "fromHit=1", 1, true) ~= nil, "fromHit counted: " .. tostring(result))
end)

T.test("kite hook: no step while team roam's overlay owns a hit (#171 bot._lhOwn), one skip line", function()
	local bot, SpecialUnits, attacker, _, moves = kiteScene("npc_dota_neutral_kobold", TEAM_NEUTRAL)
	bot.GetNearbyNeutralCreeps = function()
		return { attacker }
	end
	bot._lhOwn = { unit = attacker, t = GameTime() }
	T.eq(SpecialUnits.TryKiteInAttack(bot), false, "no kite step")
	T.eq(SpecialUnits.TryKiteInAttack(bot), false, "still none")
	T.eq(#moves, 0, "no move order over the overlay's swing")
	local lines = 0
	for _, line in ipairs(T.stub.printed) do
		if string.find(line, "kite-skip why=overlay-owns", 1, true) then
			lines = lines + 1
		end
	end
	T.eq(lines, 1, "logged once per hold")
	bot._lhOwn = nil
	T.eq(SpecialUnits.TryKiteInAttack(bot), true, "kites again once the overlay let go")
end)

T.test("chase hook: no chase step while the overlay owns a hit", function()
	local bot, SpecialUnits, _, moves = chaseScene()
	bot._lhOwn = { t = GameTime() }
	T.eq(SpecialUnits.TryKiteInAttack(bot), false, "no chase")
	T.eq(#moves, 0)
	T.ok(printedWith("kite-skip why=overlay-owns kind=chase") ~= nil, "skip line names the chase")
end)
