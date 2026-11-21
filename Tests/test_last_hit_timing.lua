-- FuncLib/systems/last_hit_timing.lua (#71): the per-frame wind-up watch on a stub bot, and Fu.GetTurnTime.
local T = ...
local Stub = T.stub

local function setup(creepHp)
	Stub.reset({ hero = "npc_dota_hero_nevermore" })
	local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
	local Timing = require(GetScriptDirectory() .. "/FuncLib/systems/last_hit_timing")
	local bot = GetBot()
	local creep = Stub.newUnit({
		name = "npc_dota_creep_goodguys_melee",
		hp = creepHp,
		maxHp = 550,
		loc = bot:GetLocation() + Vector(100, 0, 0),
	})
	local state = { activity = 0, lastAttack = -50, orders = {} }
	bot.GetActiveMode = function()
		return BOT_MODE_LANING
	end
	bot.GetAnimActivity = function()
		return state.activity
	end
	bot.GetAttackTarget = function()
		return state.activity == 1503 and creep or nil
	end
	bot.GetAttackPoint = function()
		return 0.5
	end
	bot.GetAttackSpeed = function()
		return 1
	end
	bot.GetLastAttackTime = function()
		return state.lastAttack
	end
	bot.Action_ClearActions = function()
		state.orders[#state.orders + 1] = "clear"
	end
	bot.Action_MoveToLocation = function()
		state.orders[#state.orders + 1] = "move"
	end
	bot.Action_AttackUnit = function()
		state.orders[#state.orders + 1] = "attack"
	end
	creep.GetActualIncomingDamage = function(_, damage)
		return damage
	end
	creep.GetHealthRegen = function()
		return 0
	end
	return Fu, Timing, bot, creep, state
end

-- Frames of 1/30s, re-armed by the "laning Think" every frame (the real one does it ~3 times a second).
local function frames(Timing, bot, creep, count, damage, allowEarly)
	for _ = 1, count do
		Stub.time = Stub.time + 1 / 30
		Timing.Arm(bot, creep, { damage = damage, allowEarly = allowEarly ~= false })
		Timing.Tick(bot)
	end
end
-- Frames until the first order (at most 30); returns how many ran.
local function untilOrder(Timing, bot, creep, state, damage)
	for count = 1, 30 do
		frames(Timing, bot, creep, 1, damage)
		if #state.orders > 0 then
			return count
		end
	end
	return 31
end

T.test("turn time: a hero facing away from the creep", function()
	local Fu, _, bot = setup(100)
	-- The stub faces 0 degrees (east). A creep due west is 180 degrees away; Shadow Fiend turns at 0.9.
	local west = Stub.newUnit({ name = "npc_dota_creep_badguys_melee", loc = bot:GetLocation() + Vector(-300, 0, 0) })
	T.near(Fu.GetTurnTime(bot, west), 0.03 * math.rad(180 - 11.5) / 0.9, 1e-6, "180 degrees at 0.9")
	local east = Stub.newUnit({ name = "npc_dota_creep_badguys_melee", loc = bot:GetLocation() + Vector(300, 0, 0) })
	T.eq(Fu.GetTurnTime(bot, east), 0, "already facing it")
	T.eq(Fu.GetTurnTime(west, bot), 0, "creeps: no turn time")
end)

T.test("wind-up: an early swing that would not kill is cancelled before the attack point", function()
	local _, Timing, bot, creep, state = setup(60)
	Stub.time = 100
	Timing.Arm(bot, creep, { damage = 45, allowEarly = true })
	state.activity = 1503
	frames(Timing, bot, creep, 3, 45)
	T.eq(bot._lhTiming.phase, "windup", "watching the wind-up")
	T.eq(#state.orders, 0, "no order while there is time")
	local count = untilOrder(Timing, bot, creep, state, 45)
	T.ok(count < 15, "cancelled inside the 0.5s wind-up (frame " .. count .. ")")
	T.eq(state.orders[1], "clear", "cancelled")
	T.eq(bot._lhTiming.phase, "hold", "holding after the cancel")
	T.eq(bot._lhTiming.cancels, 1)
	-- The swing stops (no release by the attack point): the stop held. Still not one hit and no early restart
	-- allowed: it holds. The creep drops into one hit: attack again.
	state.activity = 0
	frames(Timing, bot, creep, 8, 45, false)
	T.eq(bot._lhtStopOk, 1, "stop counted as held")
	T.eq(#state.orders, 1, "holding, no new order")
	creep._hp = 30
	frames(Timing, bot, creep, 1, 45, false)
	T.eq(state.orders[#state.orders], "attack", "re-attack once the hit is sure")
	T.eq(bot._lhTiming.phase, "attack")
end)

T.test("wind-up: a swing that kills is released, never cancelled", function()
	local _, Timing, bot, creep, state = setup(40)
	Stub.time = 200
	Timing.Arm(bot, creep, { damage = 45, allowEarly = true })
	state.activity = 1503
	frames(Timing, bot, creep, 20, 45)
	T.eq(#state.orders, 0, "no cancel")
	T.eq(bot._lhTiming.phase, "decided", "release decided, kept until the release is seen")
	T.eq(bot._lhtStats.released, 1, "counted once, not again at every re-arm")
	T.ok(Timing.Holding(bot, creep), "the laning Think gives no order meanwhile")
	state.lastAttack = GameTime()
	frames(Timing, bot, creep, 1, 45)
	T.eq(bot._lhTiming.phase, "released", "release seen")
end)

T.test("wind-up: a swing that was sure when it started is never cancelled", function()
	local _, Timing, bot, creep, state = setup(40)
	Stub.time = 300
	Timing.Arm(bot, creep, { damage = 45, allowEarly = true })
	state.activity = 1503
	-- Sure at the start; a heal before the first look would make it short. Simulate by the classification at the
	-- start: the first look releases it at once ("kills"), so later HP changes do not matter.
	frames(Timing, bot, creep, 1, 45)
	creep._hp = 80
	frames(Timing, bot, creep, 20, 45)
	T.eq(#state.orders, 0, "no cancel")
end)

T.test("a stop that does not hold is counted (the attack released anyway)", function()
	local _, Timing, bot, creep, state = setup(60)
	Stub.time = 400
	Timing.Arm(bot, creep, { damage = 45, allowEarly = true })
	state.activity = 1503
	untilOrder(Timing, bot, creep, state, 45)
	T.eq(state.orders[1], "clear", "cancelled")
	state.lastAttack = GameTime()
	frames(Timing, bot, creep, 1, 45)
	T.eq(bot._lhtStopFail, 1, "release after the stop: stopped=no")
	T.eq(bot._lhTiming.phase, "released")
end)

T.test("the laning Think dropping the hit clears the timing", function()
	local _, Timing, bot, creep, state = setup(60)
	Stub.time = 500
	Timing.Arm(bot, creep, { damage = 45, allowEarly = true })
	state.activity = 1503
	Stub.time = Stub.time + 1 / 30
	Timing.BeginThink(bot)
	Timing.Tick(bot)
	T.eq(bot._lhTiming, nil, "a think without Arm drops it")
	T.ok(not Timing.IsTiming(bot))
end)

T.test("the previous attack's backswing (also activity 1503) does not start the wind-up clock", function()
	local _, Timing, bot, creep, state = setup(60)
	Stub.time = 600
	-- Released 0.1s ago; seconds per attack 1.7 (stub), wind-up 0.5: the next swing can start 1.2s after the release.
	state.lastAttack = GameTime() - 0.1
	Timing.Arm(bot, creep, { damage = 45, allowEarly = true })
	state.activity = 1503
	frames(Timing, bot, creep, 20, 45)
	T.eq(bot._lhTiming.phase, "attack", "no wind-up clock in the backswing")
	T.eq(#state.orders, 0, "no cancel in the backswing")
	frames(Timing, bot, creep, 25, 45)
	T.ok(bot._lhTiming.phase == "windup" or bot._lhTiming.phase == "hold", "a real wind-up after the cooldown")
end)

T.test("early swings switch off for a bot whose stops never hold", function()
	local _, Timing, bot, creep, state = setup(60)
	Stub.time = 700
	for round = 1, 4 do
		Timing.Arm(bot, creep, { damage = 45, allowEarly = true })
		bot._lhTiming.phase = "attack"
		state.orders = {}
		state.activity = 1503
		untilOrder(Timing, bot, creep, state, 45)
		T.ok(state.orders[1] == "clear" or state.orders[1] == "move", "round " .. round .. " stopped")
		-- The attack releases anyway, then the backswing ends.
		state.lastAttack = GameTime()
		frames(Timing, bot, creep, 1, 45)
		state.activity = 0
		Stub.time = Stub.time + 2
	end
	T.eq(bot._lhtStopFail, 4)
	T.eq(state.orders[1], "move", "the last rounds used the move-order fallback")
	T.ok(not Timing.EarlyAllowed(bot), "early swings off")
	Timing.Arm(bot, creep, { damage = 45, allowEarly = true })
	T.eq(bot._lhTiming.allowEarly, false, "Arm drops early for this bot")
end)

-- A bot core next to the support, hitting creep (or not).
local function addCore(creep, props)
	local core = Stub.newUnit({
		name = "npc_dota_hero_juggernaut",
		team = GetBot():GetTeam(),
		hero = true,
		loc = creep:GetLocation() + Vector(-100, 0, 0),
	})
	core.GetAttackTarget = function()
		return props.attacking and creep or nil
	end
	core.GetAttackPoint = function()
		return 0.3
	end
	core.GetAttackSpeed = function()
		return 1
	end
	core.GetLastAttackTime = function()
		return -50
	end
	core.GetAttackDamage = function()
		return 50
	end
	core.IsBot = function()
		return true
	end
	core.GetActiveMode = function()
		return props.mode or BOT_MODE_LANING
	end
	return core
end

T.test("backup: the support leaves a creep the core's pending hit kills", function()
	local _, Timing, bot, creep, state = setup(40)
	Stub.time = 800
	local core = addCore(creep, { attacking = true })
	for _ = 1, 10 do
		Stub.time = Stub.time + 1 / 30
		Timing.Arm(bot, creep, { damage = 45, allowEarly = false, walk = true, backupCore = core })
		Timing.Tick(bot)
	end
	T.eq(#state.orders, 0, "no attack: the core's hit lands first and kills it")
end)

T.test("backup: waits for a free core, takes it from a busy one", function()
	local _, Timing, bot, creep, state = setup(40)
	Stub.time = 900
	local props = { attacking = false }
	local core = addCore(creep, props)
	for _ = 1, 5 do
		Stub.time = Stub.time + 1 / 30
		Timing.Arm(bot, creep, { damage = 45, allowEarly = false, walk = true, backupCore = core })
		Timing.Tick(bot)
	end
	T.eq(#state.orders, 0, "the free core is about to take it")
	props.mode = BOT_MODE_RETREAT
	Stub.time = Stub.time + 1 / 30
	Timing.Arm(bot, creep, { damage = 45, allowEarly = false, walk = true, backupCore = core })
	Timing.Tick(bot)
	T.eq(state.orders[1], "attack", "the core left: the support takes it")
end)

T.test("backup: a creep the core's hit leaves alive is taken after the core's hit", function()
	local _, Timing, bot, creep, state = setup(80)
	Stub.time = 1000
	local core = addCore(creep, { attacking = true })
	local facts = Timing.BackupFacts(bot, core, creep, 45)
	T.ok(facts.coreAttacking, "the core's hit is pending")
	T.ok(facts.myDelay >= facts.coreEta, "the support's hit lands later (wind-up 0.5s against 0.3s)")
	T.ok(facts.ourKills, "80 - 50 from the core leaves one support hit")
	Stub.time = Stub.time + 1 / 30
	Timing.Arm(bot, creep, { damage = 45, allowEarly = false, walk = true, backupCore = core })
	Timing.Tick(bot)
	T.eq(state.orders[1], "attack", "backup swing")
end)

T.test("a laning Think that gave another order drops the timing at the next frame's Tick", function()
	local _, Timing, bot, creep, state = setup(60)
	Stub.time = 1100
	-- A walk-in armed by one Think; the next Think (a later frame) denies instead and does not re-arm it. The Tick
	-- after it must not attack the old creep over the deny.
	Timing.Arm(bot, creep, { damage = 45, allowEarly = false, walk = true })
	Stub.time = Stub.time + 0.3
	Timing.BeginThink(bot)
	Stub.time = Stub.time + 1 / 30
	creep._hp = 30
	Timing.Tick(bot)
	T.eq(bot._lhTiming, nil, "dropped")
	T.eq(#state.orders, 0, "no attack over the deny")
end)

T.test("timed hit and keep: a deny passed over keeps the wind-up armed", function()
	local _, Timing, bot, creep, state = setup(60)
	Stub.time = 1200
	Timing.Arm(bot, creep, { damage = 45, allowEarly = true })
	state.activity = 1503
	frames(Timing, bot, creep, 2, 45)
	T.eq(Timing.TimedHit(bot), creep, "the wind-up is timed")
	Stub.time = Stub.time + 1 / 30
	Timing.BeginThink(bot)
	Timing.KeepTimed(bot)
	Timing.Tick(bot)
	T.ok(bot._lhTiming ~= nil, "still armed after a Think that only kept it")
end)

T.test("death estimate: our creeps and towers hitting the creep", function()
	local _, Timing, bot, creep = setup(100)
	local function hitter(target)
		local unit =
			Stub.newUnit({ name = "npc_dota_creep_goodguys_melee", loc = creep:GetLocation() + Vector(50, 0, 0) })
		unit.GetAttackTarget = function()
			return target
		end
		unit.GetAttackDamage = function()
			return 20
		end
		unit.GetSecondsPerAttack = function()
			return 1
		end
		return unit
	end
	local units = { hitter(creep), hitter(creep), hitter(bot) }
	bot.GetNearbyLaneCreeps = function()
		return units
	end
	bot.GetNearbyTowers = function()
		return {}
	end
	creep.GetIncomingTrackingProjectiles = function()
		return {}
	end
	local death, dps = Timing.DeathEta(bot, creep)
	T.near(dps, 40, 1e-9, "two creeps on it, one on something else")
	T.near(death, 100 / 40, 1e-9, "100 HP at 40 a second")
	units = {}
	T.eq((Timing.DeathEta(bot, creep)), math.huge, "nothing hits it")
end)

T.test("team roam's overlay owns a hit (#171 bot._lhOwn): no arm, no order, one skip line", function()
	local _, Timing, bot, creep, state = setup(30)
	Stub.time = 1300
	Timing.Arm(bot, creep, { damage = 45, allowEarly = false, walk = true })
	local other = Stub.newUnit({ name = "npc_dota_creep_badguys_melee", loc = bot:GetLocation() + Vector(80, 0, 0) })
	bot._lhOwn = { unit = other, t = GameTime() }
	for _ = 1, 5 do
		Stub.time = Stub.time + 1 / 30
		T.eq(Timing.Arm(bot, creep, { damage = 45, allowEarly = false, walk = true }), nil, "not armed")
		T.eq(Timing.Tick(bot), false, "the overlay keeps the frame")
	end
	T.eq(#state.orders, 0, "no attack over the overlay's swing (the creep was a sure hit)")
	T.eq(bot._lhTiming, nil, "our timing dropped")
	local lines = 0
	for _, line in ipairs(Stub.printed) do
		if string.find(line, "skip why=overlay-owns", 1, true) then
			lines = lines + 1
		end
	end
	T.eq(lines, 1, "logged once per hold")
	-- The hold ends: the timing works again.
	bot._lhOwn = nil
	Stub.time = Stub.time + 1 / 30
	Timing.Arm(bot, creep, { damage = 45, allowEarly = false, walk = true })
	Timing.Tick(bot)
	T.eq(state.orders[1], "attack", "the sure walk-in attacks once the overlay let go")
end)
