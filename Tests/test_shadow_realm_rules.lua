-- FuncLib/systems/shadow_realm_rules.lua (#48): Dark Willow's Shadow Realm hold, bonus damage and the escape TP.
local T = ...

local function load()
	T.stub.reset({ hero = "npc_dota_hero_dark_willow" })
	return require(GetScriptDirectory() .. "/FuncLib/systems/shadow_realm_rules")
end

T.test("shadow realm: the bonus grows to its maximum at 3s", function()
	local R = load()
	-- Datafeed hero 119: damage 120/200/280/360, max_damage_duration 3.
	T.eq(R.BonusDamage(360, 0, 3), 0, "at the cast")
	T.near(R.BonusDamage(360, 1.5, 3), 180, 0.01, "half way")
	T.eq(R.BonusDamage(360, 3, 3), 360, "full at 3s")
	T.eq(R.BonusDamage(360, 4.5, 3), 360, "no more after 3s")
end)

T.test("shadow realm: hold, close in or hit", function()
	local R = load()
	local base = {
		since = 1,
		maxTime = 3,
		dist = 700,
		holdRange = 1100,
		predictedDist = 720,
		canFollow = true,
		killNow = false,
		allyNeeds = false,
	}
	local function step(over)
		local o = {}
		for k, v in pairs(base) do
			o[k] = v
		end
		for k, v in pairs(over or {}) do
			o[k] = v
		end
		return R.HoldStep(o)
	end
	T.eq(step(), "hold", "in range, 1s in: wait for the damage")
	T.eq(select(2, step({ since = 3 })), "max", "full bonus: hit")
	T.eq(select(2, step({ since = 4.5, maxTime = 6 })), "end", "the realm is about to end (a longer max time)")
	T.eq(select(2, step({ killNow = true })), "kill", "the hit kills now")
	T.eq(select(2, step({ allyNeeds = true })), "ally", "an ally needs the damage")
	T.eq(step({ dist = 1050, predictedDist = 1060 }), "close", "near the edge, she can follow: step after it")
	T.eq(
		select(2, step({ dist = 1050, predictedDist = 1150, canFollow = false })),
		"leave",
		"walking out of range faster than her: hit now"
	)
	T.eq(step({ dist = 1300, predictedDist = 1320 }), "close", "out of range: close in")
end)

T.test("shadow realm: the escape TP fits inside the realm (game 067, 17:06)", function()
	local R = load()
	-- 5s realm, 3s TP channel (7.42 items_all.txt).
	T.eq(R.TpFits(0.1, 5, 3, 0.3), true, "right after the cast")
	T.eq(R.TpFits(1.7, 5, 3, 0.3), true, "1.7s in: ends at 4.7s")
	T.eq(R.TpFits(4, 5, 3, 0.3), false, "game 067: 4s in, the channel outlasts the realm")
end)

T.test("dark willow: the realm helpers run on the stub", function()
	T.stub.reset({ hero = "npc_dota_hero_dark_willow", slot = 4 })
	local ok, X = T.stub.load("BotsLib/hero_dark_willow")
	T.ok(ok, "hero_dark_willow loads: " .. tostring(X))
	local okC, err = pcall(X.ConsiderShadowRealm)
	T.ok(okC, "ConsiderShadowRealm: " .. tostring(err))
	for _, why in ipairs({ "attack", "retreat" }) do
		local okS, errS = pcall(X.StartShadowRealm, why, nil)
		T.ok(okS, "StartShadowRealm " .. why .. ": " .. tostring(errS))
		local okT, errT = pcall(X.ShadowRealmTick)
		T.ok(okT, "ShadowRealmTick " .. why .. ": " .. tostring(errT))
	end
	local okSk, errSk = pcall(X.SkillsComplement)
	T.ok(okSk, "SkillsComplement: " .. tostring(errSk))
end)

-- Drives the realm tick through the hold, the full-bonus hit and the escape TP (the stub alone stops at "no cast").
local function realmBot()
	local bot = T.stub.reset({ hero = "npc_dota_hero_dark_willow", slot = 4, time = 100 })
	local ok, X = T.stub.load("BotsLib/hero_dark_willow")
	T.ok(ok, "hero_dark_willow loads: " .. tostring(X))
	local realm = bot:GetAbilityByName("dark_willow_shadow_realm")
	realm.GetCooldownTimeRemaining = function()
		return 15
	end
	local orders = {}
	bot.Action_MoveToLocation = function()
		orders[#orders + 1] = "move"
	end
	bot.Action_AttackUnit = function()
		orders[#orders + 1] = "attack"
	end
	bot.Action_UseAbilityOnLocation = function(_, ability)
		orders[#orders + 1] = "use:" .. ability:GetName()
	end
	return bot, X, orders
end

T.test("dark willow: an attack realm holds, then hits at 3s", function()
	local bot, X, orders = realmBot()
	bot.GetActiveMode = function()
		return BOT_MODE_ATTACK
	end
	bot.GetAttackRange = function()
		return 475
	end
	local target = T.stub.teams[TEAM_DIRE][1]
	target._loc = bot._loc + Vector(700, 0, 0)
	X.StartShadowRealm("attack", target)
	T.stub.time = 101
	T.eq(X.ShadowRealmTick(), false, "1s in: a hold move, spells may still go out")
	T.eq(orders[#orders], "move", "she moves, she does not attack")
	T.eq(bot._attackHold(), true, "the attack mode is held")
	T.stub.time = 103.05
	T.eq(X.ShadowRealmTick(), true, "3s in: the hit")
	T.eq(orders[#orders], "attack", "attack order")
	T.eq(bot._dwRealm.released, "max", "release=max")
	T.eq(bot._attackHold(), false, "the attack mode attacks again")
	T.stub.time = 105.5
	X.ShadowRealmTick()
	T.eq(bot._dwRealm, nil, "the realm is over")
	local line = T.stub.printed[#T.stub.printed] or ""
	T.ok(string.find(line, "shadow-realm why=attack held=3.05", 1, true) ~= nil, line)
	T.ok(string.find(line, "release=max", 1, true) ~= nil, line)
end)

T.test("dark willow: an escape realm starts the TP at once (game 067, 17:06)", function()
	local bot, X, orders = realmBot()
	-- 10% HP, alone (the stub's ally list ignores the mode filter: move the allies away).
	bot._hp = 100
	for _, ally in ipairs(T.stub.teams[bot._team]) do
		if ally ~= bot then
			ally._loc = Vector(0, 0, 0)
		end
	end
	bot.DistanceFromFountain = function()
		return 9000
	end
	bot.WasRecentlyDamagedByAnyHero = function()
		return true
	end
	local scroll = T.stub.newAbility("item_tpscroll", bot, false)
	scroll.IsFullyCastable = function()
		return true
	end
	bot._items[15] = scroll
	bot.FindItemSlot = function(_, name)
		return name == "item_tpscroll" and 15 or -1
	end
	X.StartShadowRealm("retreat", nil)
	T.stub.time = 100.1
	T.eq(X.ShadowRealmTick(), true, "the TP order: " .. tostring(bot._dwRealm and bot._dwRealm.tp))
	T.eq(orders[#orders], "use:item_tpscroll", "TP scroll used")
	T.eq(bot._dwRealm.tp, "ordered", "ordered")
	bot.IsChanneling = function()
		return true
	end
	T.stub.time = 100.3
	X.ShadowRealmTick()
	T.eq(bot._dwRealm.tp, "now", "the channel started")
	T.stub.time = 105.3
	X.ShadowRealmTick()
	local line = T.stub.printed[#T.stub.printed] or ""
	T.ok(string.find(line, "why=retreat", 1, true) ~= nil and string.find(line, "tp=now", 1, true) ~= nil, line)
end)
