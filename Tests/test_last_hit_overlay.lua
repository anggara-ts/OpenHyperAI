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
	-- Farm: a mode whose Think is ours (the overlay holds it).
	function bot:GetActiveMode()
		return BOT_MODE_FARM
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
	T.ok(bot._roamStats ~= nil and #(bot._roamStats.tries or {}) == 1, "an open snipe try for snipeLH")
	T.eq(O.Think(bot), true, "repeated every think until the hit")
	T.eq(printed("overlay-hit"), 1, "one line per unit")
	T.stub.time = 601
	bot._lhOwn = nil
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
	function bot:GetActiveMode()
		return BOT_MODE_FARM
	end
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
	-- A traced hunting spell: no hit while its trace is open (the spell, and up to 3s after the reveal: game 064,
	-- 36:30, a snipe 1.5s after Clinkz's reveal), then the overlay is free again.
	bot.HasModifier = nil
	bot._huntTrace = { offAt = nil, snipe = 0 }
	T.stub.time = 633
	O.Offer(bot, creep, 1.5, "snipe")
	T.eq(O.Think(bot), false, "hunting spell on")
	bot._huntTrace.offAt = 632.5
	T.eq(O.Think(bot), false, "0.5s after the reveal")
	bot._huntTrace.offAt = 631.5
	T.eq(O.Think(bot), false, "1.5s after the reveal, trace still open")
	bot._huntTrace = nil
	T.eq(O.Think(bot), true, "trace closed")
end)

T.test("last-hit overlay: no snipe off an enemy hero in range in attack mode", function()
	local bot, O, creep = setup()
	local enemy = T.stub.newUnit({ name = "npc_dota_hero_hoodwink", team = TEAM_DIRE, loc = bot:GetLocation() })
	function bot:GetActiveMode()
		return BOT_MODE_ATTACK
	end
	function bot:GetAttackTarget()
		return enemy
	end
	O.Offer(bot, creep, 1.5, "snipe")
	T.eq(O.Think(bot), false, "hero in range")
	T.eq(printed("overlay-skip why=fight rule=snipe"), 1, "skip line")
	T.ok(O.FightingHero(bot), "fighting")
	enemy._loc = bot:GetLocation() + Vector(2000, 0, 0)
	T.ok(not O.FightingHero(bot), "hero out of range")
	-- Valve's attack mode cannot be held from Lua: no overlay hit there (team roam wins the mode for it instead).
	T.eq(O.Think(bot), false, "Valve's attack mode")
	T.eq(printed("overlay-skip why=valve rule=snipe"), 1, "skip line")
	bot._ohaAttackOverride = true
	T.eq(O.Think(bot), true, "our attack override, out of range: the snipe goes")
end)

T.test("last-hit overlay: owns the hit, holds the mode Thinks until the release", function()
	local bot, O, creep, orders = setup()
	require(GetScriptDirectory() .. "/FuncLib/systems/global_overrides")
	local lastAttack = 0
	function bot:GetLastAttackTime()
		return lastAttack
	end
	function bot:GetAttackPoint()
		return 0.3
	end
	function bot:GetAttackSpeed()
		return 1
	end
	O.Offer(bot, creep, 1.5, "snipe")
	T.eq(O.Think(bot), true, "first order")
	T.ok(bot._lhOwn ~= nil and bot._lhOwn.unit == creep, "owns the hit")
	T.ok(OhaCastGuard(bot), "mode Think held")
	T.eq(bot._lhOwn.held, 1, "one held Think")
	-- A newer offer (the next creep) does not take the bot off the owned one mid wind-up.
	local creep2 = T.stub.newUnit({ name = "npc_dota_creep_badguys_ranged", hp = 20, loc = bot:GetLocation() })
	O.Offer(bot, creep2, 1.5, "snipe")
	T.eq(O.Think(bot), true, "still ordering")
	T.ok(orders[#orders].unit == creep, "the owned creep")
	-- The attack starts (GetLastAttackTime moves): held through the wind-up, released after it.
	local now = GameTime()
	lastAttack = now
	T.ok(O.Owns(bot), "wind-up: still owned")
	T.stub.time = T.stub.time + 0.4
	T.ok(not O.Owns(bot), "released after the wind-up")
	T.ok(not OhaCastGuard(bot), "mode Think runs again")
	-- Cap: a hit that never comes lets go after 1s, and that unit gets no second hold.
	O.Offer(bot, creep2, 1.5, "snipe")
	T.eq(O.Think(bot), true, "new hold on the next creep")
	T.stub.time = T.stub.time + 1.1
	T.ok(not OhaCastGuard(bot), "cap")
	O.Offer(bot, creep2, 1.5, "snipe")
	T.eq(O.Think(bot), false, "capped unit: the mode keeps the bot")
	-- Retreat frees the bot at once; a dead unit too.
	local creep3 = T.stub.newUnit({ name = "npc_dota_creep_badguys_melee", hp = 20, loc = bot:GetLocation() })
	O.Offer(bot, creep3, 1.5, "snipe")
	T.eq(O.Think(bot), true, "hold on a third creep")
	creep3._alive = false
	T.ok(not OhaCastGuard(bot), "dead unit: released")
end)

T.test("last-hit overlay: a try resolves when its unit dies; a deny counts; one line per result", function()
	local bot, O, creep = setup()
	local lastHits, denies = 10, 2
	function bot:GetLastHits()
		return lastHits
	end
	function bot:GetDenies()
		return denies
	end
	O.Offer(bot, creep, 0.9, "hunt-support/deny")
	T.eq(O.Think(bot), true, "deny hunt")
	-- Another unit's offer while the first is open: no forced miss (game 064 counted one).
	local creep2 = T.stub.newUnit({ name = "npc_dota_creep_badguys_ranged", hp = 20, loc = bot:GetLocation() })
	creep._alive = false
	denies = 3
	T.stub.time = 600.3
	O.Offer(bot, creep2, 1.5, "snipe")
	T.eq(O.Think(bot), true, "snipe on the next creep")
	local c = bot._roamStats.c
	T.eq(c.creepGot .. "/" .. c.creepTries, "1/1", "the deny counts")
	T.eq(printed("overlay-try result=got rule=hunt-support/deny mode="), 1, "result line")
	-- The snipe's creep walks off: no order for 3s while it lives is a drop.
	bot._lhOwn = nil
	T.stub.time = 604
	T.eq(O.Think(bot), false, "no offer")
	T.eq(c.snipeGot .. "/" .. c.snipeTries, "0/1", "dropped")
	T.eq(printed("overlay-try result=drop rule=snipe"), 1, "drop line")
end)

T.test("last-hit overlay: the try line says the walk, the allies near and replaced orders (game 065 pushes)", function()
	local bot, O, creep = setup()
	function bot:GetAttackRange()
		return 150
	end
	creep._loc = bot:GetLocation() + Vector(400, 0, 0)
	-- A hunt-* hit: a snipe here would go to the stub's allied cores (RoamRules.NewHitSkipWhy, tested below).
	local action = BOT_ACTION_TYPE_ATTACK
	function bot:GetCurrentActionType()
		return action
	end
	O.Offer(bot, creep, 1.5, "hunt-carry/lane")
	T.eq(O.Think(bot), true, "first order")
	local try = bot._lhOwn.try
	T.eq(try.gap, 250, "400 away, range 150")
	T.eq(try.allies, 4, "the stub's other four heroes stand within 700, the bot not counted")
	-- A move ordered after the overlay's attack: the next think starts with it; the overlay orders the attack again.
	action = BOT_ACTION_TYPE_MOVE_TO
	O.Offer(bot, creep, 1.5, "hunt-carry/lane")
	T.eq(O.Think(bot), true, "attack ordered again")
	-- A spell: counted, and the bot is busy with it, so the overlay lets go (release=skip-busy).
	action = BOT_ACTION_TYPE_USE_ABILITY
	O.Offer(bot, creep, 1.5, "hunt-carry/lane")
	T.eq(O.Think(bot), false, "busy with the spell")
	T.eq(try.replaced, 2, "two thinks began with another order")
	T.eq(try.cast, 1, "one of them a spell")
	creep._alive = false
	T.stub.time = 600.5
	O.Think(bot)
	T.eq(printed("release=skip-busy gap=250 allies=4 replaced=2 cast=1"), 1, "fields on the try line")
end)

T.test("last-hit overlay: a snipe an allied core reaches first is left to it (game 067 review)", function()
	local bot, O, creep = setup()
	function bot:GetAttackRange()
		return 150
	end
	-- The stub's other four heroes stand on the bot; with a longer attack range they reach their swing first.
	creep._loc = bot:GetLocation() + Vector(400, 0, 0)
	O.Offer(bot, creep, 1.5, "snipe")
	T.eq(O.Think(bot), false, "left to the ally")
	T.eq(bot._lhOwn, nil, "no hold")
	T.eq(printed("overlay-skip why=ally-first rule=snipe"), 1, "skip line")
	-- A hunt-* hit 400 + 150 = 550 away: gap 400, above the 300 cap.
	creep._loc = bot:GetLocation() + Vector(550, 0, 0)
	O.Offer(bot, creep, 1.5, "hunt-carry/lane")
	T.eq(O.Think(bot), false, "too long a walk for a hunt-* hit")
	T.eq(printed("overlay-skip why=far rule=hunt-carry/lane"), 1, "far line")
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
