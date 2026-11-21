-- FuncLib/systems/last_hit_overlay.lua (#165, mode flip-flops): team roam offers its last hit (the snipe, a hunt on a
-- creep) and the per-think hook hits without a mode change, only where team roam would have won the mode, and never
-- while retreating, invisible or charging. Also: team roam and retreat still load and think on the stub, and retreat
-- publishes its desire for team roam's special-unit cap.
local T = ...

local function setup()
	local bot = T.stub.reset({ hero = "npc_dota_hero_zuus", time = 600 })
	local O = require(GetScriptDirectory() .. "/FuncLib/systems/last_hit_overlay")
	local creep = T.stub.newUnit({ name = "npc_dota_creep_badguys_melee", hp = 20, loc = bot:GetLocation() })
	local orders = {}
	function bot:Action_AttackUnit(unit, once)
		orders[#orders + 1] = { unit = unit, once = once }
	end
	function bot:GetActiveModeDesire()
		return 0.6
	end
	return bot, O, creep, orders
end

local function printed(what)
	local n = 0
	for _, line in ipairs(T.stub.printed) do
		if string.find(line, what, 1, true) then
			n = n + 1
		end
	end
	return n
end

T.test("last-hit overlay: hits a fresh offer above the active mode, counts the try", function()
	local bot, O, creep, orders = setup()
	T.eq(O.Think(bot), false, "no offer: nothing")
	O.Offer(bot, creep, 1.5, "snipe")
	T.eq(O.Think(bot), true, "snipe 1.50 over 0.60")
	T.eq(#orders, 1, "one attack order")
	T.ok(orders[1] and orders[1].unit == creep and orders[1].once == true, "attack the creep once")
	T.eq(printed("overlay-hit rule=snipe unit=npc_dota_creep_badguys_melee"), 1, "hit line")
	T.ok(bot._roamStats ~= nil and bot._roamStats.snipe ~= nil, "a pending snipe try for snipeLH")
	T.eq(O.Think(bot), true, "repeated every think until the hit")
	T.eq(printed("overlay-hit"), 1, "one line per unit")
	T.stub.time = 601
	T.eq(O.Think(bot), false, "an offer from an earlier think is dropped")
	T.eq(bot._lhOffer, nil, "cleared")
	O.Offer(bot, creep, 0.5, "hunt-carry/lane")
	T.eq(O.Think(bot), false, "0.50 (cut while pushing) under 0.60: the mode keeps it")
	T.eq(printed("overlay-skip"), 0, "the normal case is not logged")
end)

T.test("last-hit overlay: never while retreating, invisible or charging", function()
	local bot, O, creep, orders = setup()
	function bot:GetActiveMode()
		return BOT_MODE_RETREAT
	end
	O.Offer(bot, creep, 1.5, "snipe")
	T.eq(O.Think(bot), false, "retreat")
	T.eq(printed("overlay-skip why=retreat rule=snipe"), 1, "skip line")
	bot.GetActiveMode = nil
	function bot:IsInvisible()
		return true
	end
	T.stub.time = 611
	O.Offer(bot, creep, 1.5, "snipe")
	T.eq(O.Think(bot), false, "invisible")
	T.eq(printed("overlay-skip why=invisible"), 1, "skip line")
	bot._name = "npc_dota_hero_riki"
	T.eq(O.Think(bot), true, "Riki attacks out of invisibility")
	bot._name = "npc_dota_hero_spirit_breaker"
	bot.IsInvisible = nil
	function bot:HasModifier(name)
		return name == "modifier_spirit_breaker_charge_of_darkness"
	end
	T.stub.time = 622
	O.Offer(bot, creep, 1.5, "snipe")
	T.eq(O.Think(bot), false, "charging")
	T.eq(printed("overlay-skip why=charging"), 1, "skip line")
	T.eq(#orders, 1, "only Riki's hit")
	-- A traced hunting spell: no hit while it runs and for 1s after the reveal, then the overlay is free again.
	bot.HasModifier = nil
	bot._huntTrace = { offAt = nil, snipe = 0 }
	T.stub.time = 633
	O.Offer(bot, creep, 1.5, "snipe")
	T.eq(O.Think(bot), false, "hunting spell on")
	bot._huntTrace.offAt = 632.5
	T.eq(O.Think(bot), false, "0.5s after the reveal")
	bot._huntTrace.offAt = 631.5
	T.eq(O.Think(bot), true, "1.5s after the reveal")
end)

T.test("team roam and retreat load and think; retreat publishes its desire", function()
	local bot = T.stub.reset({ hero = "npc_dota_hero_zuus", time = 600 })
	local ok, err = T.stub.load("mode_team_roam_generic")
	T.ok(ok, tostring(err))
	if ok then
		T.eq(type(GetDesire()), "number", "team roam desire")
		Think()
	end
	T.stub.reset({ hero = "npc_dota_hero_zuus", time = 600 })
	bot = GetBot()
	ok, err = T.stub.load("mode_retreat_generic")
	T.ok(ok, tostring(err))
	if ok then
		local desire = GetDesire()
		T.eq(type(desire), "number", "retreat desire")
		T.ok(bot._retreatFinalDesire ~= nil and bot._retreatFinalDesire.d == desire, "published")
		T.eq(bot._retreatFinalDesire and bot._retreatFinalDesire.t, 600, "with the time")
	end
end)
