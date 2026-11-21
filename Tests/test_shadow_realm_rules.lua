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
