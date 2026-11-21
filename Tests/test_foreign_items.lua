-- #141: another player's items (FuncLib/systems/foreign_items.lua).
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
