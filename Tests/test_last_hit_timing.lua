-- FuncLib/systems/last_hit_timing.lua (#71): the per-frame wind-up watch on a stub bot, and Fu.GetTurnTime.
local T = ...
local Stub = T.stub

local function setup(creepHp)
	Stub.reset({ hero = "npc_dota_hero_nevermore" })
	local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
	local Timing = require(GetScriptDirectory() .. "/FuncLib/systems/last_hit_timing")
	local bot = GetBot()
	local creep = Stub.newUnit({ name = "npc_dota_creep_goodguys_melee", hp = creepHp, maxHp = 550 })
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
	T.eq(bot._lhTiming.phase, "released")
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
