-- #48: FuncLib/systems/illusion_rules.lua and FuncLib/hero/minion_lib/vengeful_spirit.lua (game 066: Vengeful
-- Spirit's Scepter death illusion and her Manta illusions stood without attacking).
local T = ...

local function rules()
	T.stub.reset({ hero = "npc_dota_hero_vengefulspirit" })
	return require(GetScriptDirectory() .. "/FuncLib/systems/illusion_rules")
end

T.test("illusion rules: which Vengeful Spirit illusion casts", function()
	local R = rules()
	T.eq(R.Kind(true, true), "death", "the Scepter modifier")
	T.eq(select(2, R.Kind(true, false)), "modifier", "told by the modifier")
	T.eq(R.Kind(false, false), "death", "hero dead: her illusion is the death illusion")
	T.eq(select(2, R.Kind(false, false)), "owner-dead", "told by the dead hero")
	T.eq(R.Kind(false, true), "manta", "hero alive, no modifier: a Manta illusion")
end)

T.test("illusion rules: a cast that doesn't start in time fails", function()
	local R = rules()
	T.eq(R.CastOutcome(0.1, true), "started", "started")
	T.eq(R.CastOutcome(0.3, false), "pending", "still waiting")
	T.eq(R.CastOutcome(0.5, false), "failed", "0.5s and nothing")
	T.eq(R.CastOutcome(2, true), "started", "started late still counts")
end)

-- A Vengeful Spirit illusion next to an enemy hero; records the orders it gets.
local function setup(ownerAlive)
	T.stub.reset({ hero = "npc_dota_hero_vengefulspirit" })
	local owner = T.stub.bot
	owner._alive = ownerAlive
	local enemy = T.stub.teams[TEAM_DIRE][1]
	local minion = T.stub.newUnit({
		name = "npc_dota_hero_vengefulspirit",
		team = owner:GetTeam(),
		loc = enemy:GetLocation() + Vector(300, 0, 0),
	})
	minion.IsIllusion = function()
		return true
	end
	minion.GetAttackDamage = function()
		return 60
	end
	local orders = { cast = 0, attack = 0 }
	minion.Action_UseAbilityOnEntity = function()
		orders.cast = orders.cast + 1
	end
	minion.Action_AttackUnit = function(_, target)
		orders.attack = orders.attack + 1
		orders.target = target
	end
	-- In range of Magic Missile (the illusion orders only casts it can start now).
	minion:GetAbilityByName("vengefulspirit_magic_missile").GetCastRange = function()
		return 1200
	end
	local VS = require(GetScriptDirectory() .. "/FuncLib/hero/minion_lib/vengeful_spirit")
	-- Magic Missile always wants to go; the illusion never starts it (as an illusion that can't cast).
	VS.ConsiderMagicMissile = function()
		return BOT_ACTION_DESIRE_HIGH, enemy
	end
	VS.ConsiderWaveOfTerror = function()
		return BOT_ACTION_DESIRE_NONE, 0
	end
	VS.ConsiderNetherSwap = function()
		return BOT_ACTION_DESIRE_NONE, nil
	end
	return VS, owner, minion, orders, enemy
end

T.test("vengeful illusion: a Manta illusion attacks and never casts", function()
	local VS, owner, minion, orders, enemy = setup(true)
	T.stub.time = 100
	VS.Think(owner, minion)
	T.eq(orders.cast, 0, "no cast order")
	T.eq(orders.attack, 1, "attack order")
	T.ok(orders.target ~= nil and orders.target:GetTeam() == enemy:GetTeam(), "on an enemy unit")
end)

T.test("vengeful illusion: the death illusion stops casting after a cast that never starts, then attacks", function()
	local VS, owner, minion, orders = setup(false)
	T.stub.time = 100
	VS.Think(owner, minion)
	T.eq(orders.cast, 1, "cast ordered")
	T.eq(orders.attack, 0, "no attack while the cast may start")
	T.stub.time = 100.3
	VS.Think(owner, minion)
	T.eq(orders.attack, 0, "still waiting")
	T.stub.time = 100.6
	VS.Think(owner, minion)
	T.ok(minion._vsSpellsOff, "spells off")
	T.eq(orders.attack, 1, "attack once the cast failed")
	T.stub.time = 101
	VS.Think(owner, minion)
	T.eq(orders.cast, 1, "no new cast order")
	T.eq(orders.attack, 2, "keeps attacking")
	local seen = false
	for _, line in ipairs(T.stub.printed) do
		if string.find(line, "[OHA-ILLUSION]", 1, true) and string.find(line, "kind=death", 1, true) then
			seen = true
		end
	end
	T.ok(seen, "[OHA-ILLUSION] kind=death line")
end)

T.test("vengeful illusion: no ability list index (game 066: abilities[6] was nil and every think errored)", function()
	local VS, owner, minion, orders = setup(false)
	-- The packed list MinionUtils.InitiateAbility makes: Magic Missile, Wave of Terror, Nether Swap; no 6th entry.
	minion.abilities = {
		minion:GetAbilityByName("vengefulspirit_magic_missile"),
		minion:GetAbilityByName("vengefulspirit_wave_of_terror"),
		minion:GetAbilityByName("vengefulspirit_nether_swap"),
	}
	VS.ConsiderMagicMissile = function()
		return BOT_ACTION_DESIRE_NONE, nil
	end
	T.stub.time = 100
	local ok, err = pcall(VS.Think, owner, minion)
	T.ok(ok, "no error: " .. tostring(err))
	T.eq(orders.attack, 1, "no spell wanted: it attacks")
end)

T.test("vengeful illusion: IsUsingAbility alone does not count as a started cast", function()
	local VS, owner, minion, orders = setup(false)
	T.stub.time = 100
	VS.Think(owner, minion)
	T.eq(orders.cast, 1, "cast ordered")
	-- After the order the unit reports "using an ability" but no cast phase, channel or cooldown follows.
	minion.IsUsingAbility = function()
		return true
	end
	T.stub.time = 100.6
	VS.Think(owner, minion)
	T.ok(minion._vsSpellsOff, "spells off: the cast never started")
	T.eq(orders.attack, 1, "attacks")
	local line = nil
	for _, printed in ipairs(T.stub.printed) do
		if string.find(printed, "why=attack", 1, true) then
			line = printed
		end
	end
	T.ok(
		line ~= nil and string.find(line, "attack=none", 1, true) == nil,
		"log names the attack target: " .. tostring(line)
	)
end)

T.test("vengeful illusion: a target out of cast range is not ordered (no false cast failure)", function()
	local VS, owner, minion, orders = setup(false)
	minion:GetAbilityByName("vengefulspirit_magic_missile").GetCastRange = function()
		return 100
	end
	T.stub.time = 100
	VS.Think(owner, minion)
	T.eq(orders.cast, 0, "no cast order out of range")
	T.ok(not minion._vsSpellsOff, "spells stay on")
	T.eq(orders.attack, 1, "attacks meanwhile")
end)
