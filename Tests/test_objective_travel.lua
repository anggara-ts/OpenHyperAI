-- FuncLib/systems/objective_travel.lua (issue #53): the gate route time, when a Fiend's Gate is worth casting,
-- and the once-per-game Twin Gate probe (7.42: heroes have no twin_gate_portal_warp).
local T = ...

local function load(opts)
	T.stub.reset(opts or { hero = "npc_dota_hero_lich" })
	return require(GetScriptDirectory() .. "/FuncLib/systems/objective_travel")
end

T.test("travel: gate route = walk to the gate + 4s channel + 1s + walk from the other gate", function()
	local Travel = load()
	-- 7.42 game data: twin_gate_portal_warp AbilityChannelTime 4.0.
	T.near(Travel.GateSeconds(3000, 2000, 300), 3000 / 300 + 4 + 1 + 2000 / 300, 0.001, "default channel")
	T.near(Travel.GateSeconds(3000, 2000, 300, 0), 3000 / 300 + 4 + 1 + 2000 / 300, 0.001, "channel 0 = default")
	T.near(Travel.GateSeconds(600, 600, 300, 6), 2 + 6 + 1 + 2, 0.001, "channel from the ability")
end)

T.test("travel: a Fiend's Gate only helps when someone can walk through it, or with Scepter", function()
	local Travel = load()
	T.eq(Travel.PortalWorthCasting(false, 0, false), false, "7.42, bots only, no Scepter")
	T.eq(Travel.PortalWorthCasting(false, 1, false), true, "a human ally")
	T.eq(Travel.PortalWorthCasting(false, 0, true), true, "Scepter: Pit of Malice at the far portal")
	T.eq(Travel.PortalWorthCasting(true, 0, false), true, "the warp ability is back")
end)

-- Two gates in opposite corners; the bot stands next to the top-left one, the target is near the other.
local function gateWorld(Travel)
	local nearGate = T.stub.newUnit({ name = "npc_dota_unit_twin_gate", team = 4, loc = Vector(-6200, 5200, 0) })
	local farGate = T.stub.newUnit({ name = "npc_dota_unit_twin_gate", team = 4, loc = Vector(6000, -5000, 0) })
	-- The stub's unit list holds heroes only; Stub.reset puts the original back.
	rawset(_G, "GetUnitList", function()
		return { nearGate, farGate }
	end)
	local bot = GetBot()
	bot._loc = Vector(-6000, 5000, 0)
	-- 7.42: the hero has no warp abilities (the stub makes up any name it is asked for).
	local stubGetAbilityByName = bot.GetAbilityByName
	bot.GetAbilityByName = function(self, name)
		if string.find(name, "portal_warp", 1, true) then
			return nil
		end
		return stubGetAbilityByName(self, name)
	end
	return Travel, bot, nearGate, farGate, Vector(5000, -4000, 0)
end

local function printed(pattern)
	local count = 0
	for _, line in ipairs(T.stub.printed or {}) do
		if string.find(tostring(line), pattern) then
			count = count + 1
		end
	end
	return count
end

T.test("travel: the gate probe tries each order for 5s, then gives up for the game", function()
	local Travel, bot, _, _, target = gateWorld(load())
	T.eq(bot:GetAbilityByName("twin_gate_portal_warp"), nil, "stub hero has no warp ability (7.42)")
	T.eq(Travel.Go(bot, target, "tormentor"), true, "probe drives the bot")
	T.eq(printed("gate%-try order=move%-to%-unit"), 1, "first order")
	T.stub.time = 5
	T.eq(Travel.Go(bot, target, "tormentor"), true, "second order")
	T.eq(printed("gate%-try order=use%-shrine"), 1, "second order logged")
	T.stub.time = 10
	T.eq(Travel.Go(bot, target, "tormentor"), true, "third order")
	T.eq(printed("gate%-try order=attack"), 1, "third order logged")
	T.stub.time = 15
	T.eq(Travel.Go(bot, target, "tormentor"), false, "no warp: walk")
	T.eq(printed("gate%-try result=failed arrived=false"), 1, "result logged")
	T.stub.time = 16
	T.eq(Travel.Go(bot, target, "tormentor"), false, "probe done for the game")
	T.eq(printed("warp%-abilities twin=false portal=false"), 1, "ability check logged once")
end)

T.test("travel: the gate probe reports a warp when the bot ends up at the far gate", function()
	local Travel, bot, _, _, target = gateWorld(load())
	T.eq(Travel.Go(bot, target, "roshan"), true, "probe starts")
	bot._loc = Vector(5800, -4800, 0)
	T.stub.time = 4
	T.eq(Travel.Go(bot, target, "roshan"), false, "arrived: carry on walking")
	T.eq(printed("gate%-try result=arrived arrived=true why=far%-gate order=move%-to%-unit"), 1, "arrived logged")
end)

T.test("travel: no probe when the gate is not faster", function()
	local Travel, bot = gateWorld(load())
	T.eq(Travel.Go(bot, Vector(-5000, 3000, 0), "roshan"), false, "short trip: walk")
	T.eq(printed("gate%-try"), 0, "no probe")
end)
