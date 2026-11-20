-- FuncLib/general_utils/projectile.lua: the Find* variants (#134, [OHA-DODGE]) return the projectile or the casting
-- enemy that the Is* helpers saw, and the Is* helpers still return exactly true / false.
local T = ...
local Stub = T.stub

local function load()
	local bot = Stub.reset({ hero = "npc_dota_hero_lich" })
	local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
	local enemy = Stub.teams[TEAM_DIRE][1]
	local ally = Stub.teams[TEAM_RADIANT][2]
	return Fu, bot, enemy, ally
end

-- A tracking projectile `distance` units in front of `unit`.
local function projectileAt(unit, distance, abilityName, caster, fields)
	local projectile = {
		is_dodgeable = true,
		is_attack = false,
		location = unit:GetLocation() + Vector(distance, 0, 0),
		caster = caster,
		ability = abilityName and Stub.newAbility(abilityName, caster, false) or nil,
	}
	for key, value in pairs(fields or {}) do
		projectile[key] = value
	end
	return projectile
end

local function incoming(unit, list)
	unit.GetIncomingTrackingProjectiles = function()
		return list
	end
end

T.test("projectile finders: return the projectile the Is* helpers saw", function()
	local Fu, bot, enemy = load()
	local bolt = projectileAt(bot, 300, "sven_storm_bolt", enemy)
	incoming(bot, { bolt })
	T.eq(Fu.FindProjectileIncoming(bot, 1200), bolt, "FindProjectileIncoming")
	T.eq(Fu.FindUnitTargetProjectileIncoming(bot, 800), bolt, "FindUnitTargetProjectileIncoming")
	T.eq(Fu.FindNotAttackProjectileIncoming(bot, 350), bolt, "FindNotAttackProjectileIncoming")
	T.eq(Fu.IsProjectileIncoming(bot, 1200), true, "IsProjectileIncoming")
	T.eq(Fu.IsUnitTargetProjectileIncoming(bot, 800), true, "IsUnitTargetProjectileIncoming")
	T.eq(Fu.IsNotAttackProjectileIncoming(bot, 350), true, "IsNotAttackProjectileIncoming")
	T.eq(Fu.IsStunProjectileSpell(bolt.ability:GetName()), true, "storm bolt is a stun projectile (why=stun)")
	-- Out of range: nil from Find*, false (not nil) from Is*.
	T.eq(Fu.FindNotAttackProjectileIncoming(bot, 250), nil, "out of range")
	T.eq(Fu.IsNotAttackProjectileIncoming(bot, 250), false, "out of range: false")
	T.eq(Fu.IsProjectileIncoming(bot, 200), false, "IsProjectileIncoming out of range")
end)

T.test("projectile finders: skip what the Is* helpers skipped", function()
	local Fu, bot, enemy, ally = load()
	local attack = projectileAt(bot, 300, nil, enemy, { is_attack = true })
	incoming(bot, { attack })
	T.eq(Fu.FindProjectileIncoming(bot, 1200), nil, "attack: FindProjectileIncoming")
	T.eq(Fu.FindUnitTargetProjectileIncoming(bot, 1200), nil, "attack: FindUnitTargetProjectileIncoming")
	T.eq(Fu.FindNotAttackProjectileIncoming(bot, 1200), nil, "attack: FindNotAttackProjectileIncoming")
	-- An ally's spell.
	incoming(bot, { projectileAt(bot, 300, "lich_chain_frost", ally) })
	T.eq(Fu.IsProjectileIncoming(bot, 1200), false, "ally caster: IsProjectileIncoming")
	T.eq(Fu.IsUnitTargetProjectileIncoming(bot, 1200), false, "ally caster: IsUnitTargetProjectileIncoming")
	T.eq(Fu.IsNotAttackProjectileIncoming(bot, 1200), false, "ally caster: IsNotAttackProjectileIncoming")
	-- Death Pulse is on the "only a projectile" list: not worth a dodge item.
	incoming(bot, { projectileAt(bot, 300, "necrolyte_death_pulse", enemy) })
	T.eq(Fu.FindProjectileIncoming(bot, 1200), nil, "death pulse: FindProjectileIncoming")
	T.eq(Fu.IsUnitTargetProjectileIncoming(bot, 1200), false, "death pulse: IsUnitTargetProjectileIncoming")
	-- Not dodgeable: only FindProjectileIncoming checks it.
	local undodgeable = projectileAt(bot, 300, "sven_storm_bolt", enemy, { is_dodgeable = false })
	incoming(bot, { undodgeable })
	T.eq(Fu.FindProjectileIncoming(bot, 1200), nil, "not dodgeable: FindProjectileIncoming")
	T.eq(Fu.FindUnitTargetProjectileIncoming(bot, 1200), undodgeable, "not dodgeable: unit-target still sees it")
	-- Anti-Mage's projectiles are left to the unit-target check's caster filter.
	local antimage = Stub.newUnit({ name = "npc_dota_hero_antimage", team = TEAM_DIRE })
	incoming(bot, { projectileAt(bot, 300, "antimage_mana_void", antimage) })
	T.eq(Fu.FindUnitTargetProjectileIncoming(bot, 1200), nil, "anti-mage caster")
	T.eq(Fu.IsUnitTargetProjectileIncoming(bot, 1200), false, "anti-mage caster: false")
	-- The first match is returned when several fly at once.
	local snake = projectileAt(bot, 500, "medusa_mystic_snake", enemy)
	local bolt = projectileAt(bot, 200, "sven_storm_bolt", enemy)
	incoming(bot, { attack, snake, bolt })
	T.eq(Fu.FindNotAttackProjectileIncoming(bot, 1200), bolt, "snake from a non-Medusa caster is skipped")
end)

T.test("[OHA-DODGE]: the dodge line and its result 1.5s later", function()
	local bot = Stub.reset({ hero = "npc_dota_hero_lich", time = 600 })
	local ok, Usage = Stub.load("ability_item_usage_generic")
	T.ok(ok, "ability_item_usage_generic loads: " .. tostring(Usage))
	local enemy = Stub.teams[TEAM_DIRE][1]
	local bkb = Stub.newAbility("item_black_king_bar", bot, false)
	local bolt = projectileAt(bot, 300, "sven_storm_bolt", enemy)
	Stub.printed = {}
	Usage.LogDodge(bkb, bot, "projectile", bolt)
	Usage.LogDodge(bkb, bot, "projectile", bolt) -- throttled
	T.eq(#Stub.printed, 1, "one line")
	local line = Stub.printed[1] or ""
	T.ok(string.find(line, "[OHA-DODGE] t=600 lich item=black_king_bar target=self", 1, true), line)
	T.ok(string.find(line, "spell=sven_storm_bolt dist=300 why=stun", 1, true), line)
	Stub.time = 601
	Usage.WatchDodgeResults()
	T.eq(#Stub.printed, 1, "no result before 1.5s")
	Stub.time = 601.5
	bot.WasRecentlyDamagedByAnyHero = function()
		return true
	end
	Usage.WatchDodgeResults()
	local result = Stub.printed[2] or ""
	T.ok(string.find(result, "result item=black_king_bar target=self hit=true cast=false alive=true", 1, true), result)
	Usage.WatchDodgeResults()
	T.eq(#Stub.printed, 2, "the result prints once")
end)

T.test("will-cast finders: return the casting enemy and its spell", function()
	local Fu, bot, enemy = load()
	enemy._loc = bot:GetLocation() + Vector(500, 0, 0)
	T.eq(Fu.FindWillBeCastUnitTargetSpell(bot, 1200), nil, "nobody casting")
	T.eq(Fu.IsWillBeCastUnitTargetSpell(bot, 1200), false, "nobody casting: false")
	T.eq(Fu.IsWillBeCastPointSpell(bot, 1200), false, "nobody casting: point false")
	local finger = Stub.newAbility("lion_finger_of_death", enemy, true)
	finger.GetBehavior = function()
		return ABILITY_BEHAVIOR_UNIT_TARGET
	end
	enemy.IsCastingAbility = function()
		return true
	end
	enemy.IsBot = function()
		return true
	end
	enemy.GetCurrentActiveAbility = function()
		return finger
	end
	local caster, ability = Fu.FindWillBeCastUnitTargetSpell(bot, 1200)
	T.eq(caster, enemy, "unit-target caster")
	T.eq(ability, finger, "unit-target ability")
	T.eq(Fu.IsWillBeCastUnitTargetSpell(bot, 1200), true, "unit-target: true")
	T.eq(Fu.FindWillBeCastUnitTargetSpell(bot, 400), nil, "caster out of range")
	-- A point / no-target spell (behaviour 48 is one of the accepted values).
	local blast = Stub.newAbility("lina_light_strike_array", enemy, false)
	blast.GetBehavior = function()
		return 48
	end
	enemy.GetCurrentActiveAbility = function()
		return blast
	end
	caster, ability = Fu.FindWillBeCastPointSpell(bot, 1200)
	T.eq(caster, enemy, "point caster")
	T.eq(ability, blast, "point ability")
	T.eq(Fu.IsWillBeCastPointSpell(bot, 1200), true, "point: true")
end)

-- #134: linear skillshots (GetLinearProjectiles) and tracking projectiles by time to impact.
local function linearAt(unit, offsetX, abilityName, caster, fields)
	local projectile = {
		location = unit:GetLocation() + Vector(offsetX, 0, 0),
		ability = Stub.newAbility(abilityName, caster, false),
		caster = caster,
	}
	for key, value in pairs(fields or {}) do
		projectile[key] = value
	end
	return projectile
end
local function flying(bot, list)
	bot._linearRead = nil
	_G.GetLinearProjectiles = function()
		return list
	end
end

T.test("linear finder: a dangerous skillshot that will hit, by time to impact", function()
	local Fu, bot, enemy, ally = load()
	Stub.time = 600
	enemy._loc = bot:GetLocation() + Vector(1500, 0, 0)
	-- Sacred Arrow 300 away flying at the bot at 900: edge arrives (300 - 115 - 24) / 900 = 0.18s.
	flying(bot, { linearAt(bot, 300, "mirana_arrow", enemy, { velocity = Vector(-900, 0, 0) }) })
	local threat = Fu.FindLinearProjectileIncoming(bot, 0, "blink")
	T.ok(threat ~= nil, "arrow found")
	T.eq(threat.name, "mirana_arrow", "name")
	T.near(threat.tti, (300 - 115 - 24) / 900, 1e-6, "tti")
	T.eq(threat.window, "now", "react now")
	T.eq(threat.src, "api", "velocity from the API field")
	-- 900 away: still coming, wait.
	flying(bot, { linearAt(bot, 900, "mirana_arrow", enemy, { velocity = Vector(-900, 0, 0) }) })
	T.eq(Fu.FindLinearProjectileIncoming(bot, 0, "blink").window, "wait", "far arrow: wait")
	-- Flying past (250 to the side): no threat.
	flying(bot, { linearAt(bot, 300, "mirana_arrow", enemy, { velocity = Vector(-900, 0, 0) }) })
	bot._loc = bot._loc + Vector(0, 250, 0)
	T.eq(Fu.FindLinearProjectileIncoming(bot, 0, "blink"), nil, "misses")
	bot._loc = bot._loc - Vector(0, 250, 0)
	-- An ally's arrow.
	flying(bot, { linearAt(bot, 300, "mirana_arrow", ally, { velocity = Vector(-900, 0, 0) }) })
	T.eq(Fu.FindLinearProjectileIncoming(bot, 0, "blink"), nil, "ally's arrow")
	-- Not on the list (Illuminate is damage only): never a dodge.
	flying(bot, { linearAt(bot, 300, "keeper_of_the_light_illuminate", enemy, { velocity = Vector(-900, 0, 0) }) })
	T.eq(Fu.FindLinearProjectileIncoming(bot, 0, "blink"), nil, "illuminate")
	-- Meat Hook pierces debuff immunity: not a BKB dodge, still a Blink dodge.
	enemy._loc = bot:GetLocation() + Vector(900, 0, 0)
	flying(bot, { linearAt(bot, 300, "pudge_meat_hook", enemy, { velocity = Vector(-1600, 0, 0) }) })
	T.eq(Fu.FindLinearProjectileIncoming(bot, 0, "bkb"), nil, "hook: no BKB")
	T.ok(Fu.FindLinearProjectileIncoming(bot, 0, "blink") ~= nil, "hook: Blink")
	-- A caster farther than the spell flies (hook 1300): no threat.
	enemy._loc = bot:GetLocation() + Vector(2000, 0, 0)
	flying(bot, { linearAt(bot, 300, "pudge_meat_hook", enemy, { velocity = Vector(-1600, 0, 0) }) })
	T.eq(Fu.FindLinearProjectileIncoming(bot, 0, "blink"), nil, "out of the hook's range")
end)

T.test("linear finder: no velocity field -> the move between thinks, or caster -> projectile", function()
	local Fu, bot, enemy = load()
	Stub.time = 600
	-- No caster, no velocity: nothing to tell the direction on the first sight.
	flying(bot, { linearAt(bot, 500, "mirana_arrow", nil) })
	T.eq(Fu.FindLinearProjectileIncoming(bot, 0, "blink"), nil, "first sight")
	Stub.time = 600.1
	flying(bot, { linearAt(bot, 410, "mirana_arrow", nil) })
	local threat = Fu.FindLinearProjectileIncoming(bot, 0, "blink")
	T.ok(threat ~= nil, "second sight")
	T.eq(threat.src, "measured", "measured")
	T.near(threat.tti, (410 - 139) / 900, 1e-6, "tti from the measured 900/s")
	-- A caster behind the projectile gives the direction at the spell's speed.
	Stub.time = 700
	enemy._loc = bot:GetLocation() + Vector(1000, 0, 0)
	flying(bot, { linearAt(bot, 300, "mirana_arrow", enemy) })
	threat = Fu.FindLinearProjectileIncoming(bot, 0, "blink")
	T.ok(threat ~= nil, "caster direction")
	T.eq(threat.src, "caster", "src caster")
	T.near(threat.vx, -900, 1e-6, "Sacred Arrow speed 900 toward the bot")
	-- Nukes only when hurt.
	flying(bot, { linearAt(bot, 300, "queenofpain_sonic_wave", enemy, { velocity = Vector(-900, 0, 0) }) })
	enemy._loc = bot:GetLocation() + Vector(600, 0, 0)
	T.eq(Fu.FindLinearProjectileIncoming(bot, 0, "blink"), nil, "sonic wave at full HP")
	bot._hp = bot._maxHp * 0.3
	T.ok(Fu.FindLinearProjectileIncoming(bot, 0, "blink") ~= nil, "sonic wave when hurt")
end)

T.test("tracking window: closing speed between thinks", function()
	local Fu, bot, enemy = load()
	Stub.time = 600
	local R = Fu.DodgeRules
	-- First sight 900 away: default speed 1000 -> 0.88s: wait.
	local window, tti, src = Fu.TrackingProjectileWindow(bot, projectileAt(bot, 900, "sven_storm_bolt", enemy), 0)
	T.eq(window, "wait", "far")
	T.eq(src, "default", "first sight: default speed")
	T.near(tti, (900 - 24) / R.DEFAULT_SPEED, 1e-6, "tti default")
	-- 0.1s later at 700: closing 2000/s -> (700 - 24) / 2000 = 0.34s: now.
	Stub.time = 600.1
	window, tti, src = Fu.TrackingProjectileWindow(bot, projectileAt(bot, 700, "sven_storm_bolt", enemy), 0)
	T.eq(src, "measured", "measured")
	T.near(tti, (700 - 24) / 2000, 1e-6, "tti measured")
	T.eq(window, "now", "now")
	-- The same think again (another item): same speed.
	local _, _, sameThinkSrc = Fu.TrackingProjectileWindow(bot, projectileAt(bot, 700, "sven_storm_bolt", enemy), 0)
	T.eq(sameThinkSrc, "measured", "same think keeps the speed")
	-- The finder with the time check returns it; without one it still uses the range only.
	incoming(
		bot,
		{ projectileAt(bot, 1500, "lion_finger_of_death", enemy), projectileAt(bot, 700, "sven_storm_bolt", enemy) }
	)
	local found = Fu.FindNotAttackProjectileIncoming(bot, 2000, function(projectile)
		return (Fu.TrackingProjectileWindow(bot, projectile, 0)) == "now"
	end)
	T.eq(found ~= nil and found.ability:GetName(), "sven_storm_bolt", "the near one passes the time check")
end)

T.test("[OHA-DODGE]: Eul's and Blink answer a Sacred Arrow; the line has kind and tti", function()
	local bot = Stub.reset({ hero = "npc_dota_hero_lich", time = 600 })
	local ok, Usage = Stub.load("ability_item_usage_generic")
	T.ok(ok, "ability_item_usage_generic loads: " .. tostring(Usage))
	local enemy = Stub.teams[TEAM_DIRE][1]
	enemy._loc = bot:GetLocation() + Vector(1500, 0, 0)
	flying(bot, { linearAt(bot, 300, "mirana_arrow", enemy, { velocity = Vector(-900, 0, 0) }) })
	local euls = Stub.newAbility("item_cyclone", bot, false)
	Stub.printed = {}
	local desire, target = Usage.ConsiderItemDesire["item_cyclone"](euls)
	T.eq(desire, BOT_ACTION_DESIRE_HIGH, "Eul's on self")
	T.eq(target, bot, "self")
	local line = Stub.printed[#Stub.printed] or ""
	T.ok(string.find(line, "item=cyclone target=self spell=mirana_arrow", 1, true), line)
	T.ok(string.find(line, "why=stun kind=linear tti=0.18 src=api", 1, true), line)
	-- One dodge per target per think: Blink keeps its charge in the think Eul's went out.
	local blink = Stub.newAbility("item_blink", bot, false)
	T.eq((Usage.ConsiderItemDesire["item_blink"](blink)), BOT_ACTION_DESIRE_NONE, "Blink after Eul's, same think")
	bot._dodgeChosen = nil
	local blinkDesire, location = Usage.ConsiderItemDesire["item_blink"](blink)
	T.eq(blinkDesire, BOT_ACTION_DESIRE_HIGH, "Blink")
	local here = bot:GetLocation()
	T.near(math.abs(location.y - here.y), 500, 1e-6, "500 to the side of the arrow's line")
	-- BKB: a stun BKB blocks, with the caster within the 1300 BKB looks at (or a fight / retreat going on).
	local bkb = Stub.newAbility("item_black_king_bar", bot, false)
	T.eq(
		(Usage.ConsiderItemDesire["item_black_king_bar"](bkb)),
		BOT_ACTION_DESIRE_NONE,
		"BKB: caster 1500 away, no fight"
	)
	enemy._loc = bot:GetLocation() + Vector(1200, 0, 0)
	bot._dodgeChosen = nil
	T.eq((Usage.ConsiderItemDesire["item_black_king_bar"](bkb)), BOT_ACTION_DESIRE_HIGH, "BKB")
end)

T.test("[OHA-DODGE]: too-late only on first sight; reader errors print [OHA-ERROR] dodge", function()
	local bot = Stub.reset({ hero = "npc_dota_hero_lich", time = 600 })
	local ok, Usage = Stub.load("ability_item_usage_generic")
	T.ok(ok, "ability_item_usage_generic loads: " .. tostring(Usage))
	local enemy = Stub.teams[TEAM_DIRE][1]
	enemy._loc = bot:GetLocation() + Vector(1000, 0, 0)
	local euls = Stub.newAbility("item_cyclone", bot, false)
	-- First sight 60 away at 900/s: lands in 0 s, before Eul's works: kept, one too-late line.
	flying(bot, { linearAt(bot, 60, "mirana_arrow", enemy, { velocity = Vector(-900, 0, 0) }) })
	Stub.printed = {}
	T.eq(Usage.LinearThreat(euls, bot, "cyclone"), nil, "too late: no dodge")
	T.eq(#Stub.printed, 2, "the one-time [OHA-API] field line and the too-late line")
	T.ok(
		string.find(Stub.printed[1] or "", "[OHA-API] t=600 lich linear-projectile fields: ", 1, true),
		Stub.printed[1]
	)
	T.ok(
		string.find(Stub.printed[2] or "", "too-late item=cyclone target=self spell=mirana_arrow", 1, true),
		Stub.printed[2]
	)
	-- Seen before (in the window, passed up): no too-late line when it gets close.
	Stub.time = 610
	flying(bot, { linearAt(bot, 400, "mirana_arrow", enemy, { velocity = Vector(-900, 0, 0) }) })
	Usage.LinearThreat(euls, bot, "cyclone")
	Stub.time = 610.3
	flying(bot, { linearAt(bot, 130, "mirana_arrow", enemy, { velocity = Vector(-900, 0, 0) }) })
	Stub.printed = {}
	T.eq(Usage.LinearThreat(euls, bot, "cyclone"), nil, "late")
	T.eq(#Stub.printed, 0, "no too-late for a projectile seen before")
	-- A reader that throws: [OHA-ERROR] dodge, once.
	Stub.time = 620
	bot._linearRead = nil
	_G.GetLinearProjectiles = function()
		return { { location = bot:GetLocation(), ability = {
			GetName = function()
				error("boom")
			end,
		} } }
	end
	Stub.printed = {}
	T.eq(Usage.LinearThreat(euls, bot, "cyclone"), nil, "error: no dodge")
	Stub.time = 620.1
	bot._linearRead = nil
	Usage.LinearThreat(euls, bot, "cyclone")
	T.eq(#Stub.printed, 1, "the same error prints once")
	T.ok(
		string.find(Stub.printed[1] or "", "[OHA-ERROR]", 1, true)
			and string.find(Stub.printed[1], "dodge linear", 1, true),
		Stub.printed[1]
	)
	local throwing = function()
		error("bad finder")
	end
	T.eq(Usage.TimedTrackingProjectile(euls, bot, throwing, 2000), nil, "tracking error: no dodge")
	T.ok(string.find(Stub.printed[2] or "", "dodge tracking", 1, true), Stub.printed[2])
end)
