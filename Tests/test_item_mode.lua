-- #141: another player's items (FuncLib/systems/foreign_items.lua) and the item mode's desire
-- (FuncLib/systems/item_mode_rules.lua, mode_item_generic.lua).
local T = ...

local function load(module)
	return require(GetScriptDirectory() .. "/FuncLib/systems/" .. module)
end

T.test("foreign items: owner rule", function()
	T.stub.reset({ hero = "npc_dota_hero_medusa" })
	local F = load("foreign_items")
	-- Game 062: Nature's Prophet's mushroom in Medusa's bag (stub player IDs are not 1-5 on purpose).
	T.eq(F.IsForeignOwner("item_foragers_mana", 11, 12), true, "another player's mushroom")
	T.eq(F.IsForeignOwner("item_foragers_mana", 12, 12), false, "own mushroom")
	-- A mushroom grown by the kit has no owner on the ground (game 062: Kez ate one without a kit).
	T.eq(F.IsForeignOwner("item_foragers_stats", nil, 12), false, "no owner")
	T.eq(F.IsForeignOwner("item_foragers_stats", -1, 12), false, "invalid owner")
	-- Shareable items (7.42 items.txt ItemShareability) and Rapier / Aegis are never foreign.
	T.eq(F.IsForeignOwner("item_ward_observer", 11, 12), false, "ward handed over by an ally")
	T.eq(F.IsForeignOwner("item_greater_famango", 11, 12), false, "lotus fruit")
	T.eq(F.IsForeignOwner("item_rapier", 15, 12), false, "an enemy's Rapier")
	T.eq(F.IsForeignOwner("item_gem", 15, 12), false, "Gem")
	T.eq(F.IsForeignOwner("item_blink", 11, 12), true, "an ally's Blink Dagger")
end)

T.test("foreign items: drop only when it costs nothing", function()
	T.stub.reset({ hero = "npc_dota_hero_medusa" })
	local F = load("foreign_items")
	T.eq(F.SafeToDrop(0, false, false, false, false), true, "calm")
	T.eq(F.SafeToDrop(1, false, false, false, false), false, "enemy hero near")
	T.eq(F.SafeToDrop(0, true, false, false, false), false, "hit by a hero")
	T.eq(F.SafeToDrop(0, false, true, false, false), false, "retreating")
	T.eq(F.SafeToDrop(0, false, false, true, false), false, "fighting")
	T.eq(F.SafeToDrop(0, false, false, false, true), false, "casting")
end)

T.test("foreign items: the ground owner carries to the bag, and a marked name stays foreign", function()
	local bot = T.stub.reset({ hero = "npc_dota_hero_medusa" })
	local F = load("foreign_items")
	local prophet = T.stub.teams[bot:GetTeam()][2]
	local mushroom = T.stub.newAbility("item_foragers_mana", prophet, false)
	local salve = T.stub.newAbility("item_flask", bot, false)
	_G.GetDroppedItemList = function()
		return {
			{ item = mushroom, owner = prophet, location = T.stub.Vector(0, 0, 0) },
			{ item = salve, owner = bot, location = T.stub.Vector(10, 0, 0) },
		}
	end
	local list = F.DropList()
	T.eq(#list, 2, "two drops read")
	local byName = {}
	for _, entry in ipairs(list) do
		byName[entry.name] = entry
	end
	T.eq(byName.item_foragers_mana.ownerPid, prophet:GetPlayerID(), "owner player read from the owner unit")
	T.eq(byName.item_flask.ownerPid, bot:GetPlayerID(), "own drop")
	local foreign, owner, how = F.Check(bot, mushroom)
	T.eq(foreign, true, "the picked-up mushroom is foreign")
	T.eq(owner, (string.gsub(prophet:GetUnitName(), "^npc_dota_hero_", "")), "owner name")
	T.eq(how, "drop-list", "how")
	T.eq(F.Check(bot, salve), false, "own item")
	local other = T.stub.newAbility("item_foragers_health", bot, false)
	T.eq(F.Check(bot, other), false, "unknown item")
	F.MarkName(bot, "item_foragers_health", "unknown", "not-consumed")
	local again, _, why = F.Check(bot, other)
	T.eq(again, true, "marked by name")
	T.eq(why, "not-consumed", "how it was marked")
	T.eq(F.WasDropped(bot, "item_foragers_health"), false, "not dropped yet")
end)

T.test("item mode: desire rules", function()
	T.stub.reset({ hero = "npc_dota_hero_medusa" })
	local R = load("item_mode_rules")
	local calm = { hp = 1, retreating = false, outnumbered = false }
	-- The horn: a bounty on the river spot under the bot.
	local d, why = R.Decide({ { kind = "river-bounty", dist = 120 } }, calm)
	T.eq(d, R.DESIRE["river-bounty"], "river bounty desire")
	T.eq(why, "river-bounty", "why")
	T.ok(d > 0.66 and d < 0.92, "above the rune mode's 0.6 river hold and farm, below its 0.92 pick-up test (#146)")
	d = R.Decide({ { kind = "river-spawn", dist = 120 } }, calm)
	T.ok(d > 0.6 and d < 0.7, "spawn window: above the 0.6 hold, below a hard retreat (0.7)")
	-- Another hero's item nearer than the own drop: nothing (Valve's Think would walk to the nearest).
	d, why = R.Decide({
		{ kind = "own-drop", dist = 500, item = true },
		{ kind = "foreign", dist = 200, item = true },
	}, calm)
	T.eq(d, 0, "foreign nearest blocks")
	T.eq(why, "foreign-nearest", "why")
	-- The own drop is the nearest: go.
	d, why = R.Decide({
		{ kind = "own-drop", dist = 200, item = true },
		{ kind = "foreign", dist = 500, item = true },
	}, calm)
	T.eq(why, "own-drop", "own drop nearest")
	T.eq(d, R.DESIRE["own-drop"], "own drop desire")
	-- A foreign item also blocks a river rune (it is the nearest dropped item).
	d, why = R.Decide({ { kind = "river-water", dist = 100 }, { kind = "foreign", dist = 300, item = true } }, calm)
	T.eq(d, 0, "foreign item next to the rune spot")
	-- Out of reach.
	d, why = R.Decide({ { kind = "own-drop", dist = 1200, item = true } }, calm)
	T.eq(d, 0, "own drop out of reach")
	d = R.Decide({ { kind = "river-bounty", dist = 500 } }, calm)
	T.eq(d, 0, "river spot out of reach")
	-- The best kind wins: Gem over an own drop.
	d, why =
		R.Decide({ { kind = "own-drop", dist = 100, item = true }, { kind = "gem", dist = 700, item = true } }, calm)
	T.eq(why, "gem", "gem first")
	-- Danger.
	d, why = R.Decide({ { kind = "gem", dist = 100, item = true } }, { hp = 0.2, retreating = false })
	T.eq(why, "unsafe", "low HP")
	d, why = R.Decide({ { kind = "gem", dist = 100, item = true } }, { hp = 1, retreating = true })
	T.eq(why, "unsafe", "retreating")
	d, why = R.Decide({ { kind = "river-bounty", dist = 100 } }, { hp = 1, outnumbered = true })
	T.eq(d, 0, "outnumbered")
	T.eq(why, "outnumbered", "why")
	d, why = R.Decide({}, calm)
	T.eq(why, "none", "nothing near")
end)

T.test("item mode: river spawn windows", function()
	T.stub.reset({ hero = "npc_dota_hero_medusa" })
	local R = load("item_mode_rules")
	T.eq(R.RiverSpawnWindow(0.3), 0, "the horn")
	T.eq(R.RiverSpawnWindow(124), 120, "2:04 water rune")
	T.eq(R.RiverSpawnWindow(250), nil, "4:10 is past the window")
	T.eq(R.RiverSpawnWindow(-5), nil, "before the horn")
	T.eq(R.RiverSpawnWindow(360), nil, "6:00 power rune, not this mode's")
end)

T.test("item mode file: GetDesire only, Valve's Think stays", function()
	T.stub.reset({ hero = "npc_dota_hero_medusa", time = 300 })
	local ok, err = T.stub.load("mode_item_generic")
	T.ok(ok, "mode_item_generic loads: " .. tostring(err))
	T.eq(type(GetDesire), "function", "GetDesire defined")
	T.eq(Think, nil, "no Think (Valve's item Think must run)")
	T.eq(OnStart, nil, "no OnStart")
	T.eq(OnEnd, nil, "no OnEnd")
	T.eq(GetDesire(), 0, "nothing on the ground: 0")
end)
