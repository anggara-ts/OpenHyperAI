-- Every entry of every hero's buy list, in every position, is an item a hero can buy in 7.42 (#9, #38).
-- A game only shows the ten heroes that played; this checks all of them, so one game per changed build is not
-- needed. An entry is fine when it is a purchasable item of the game file (Tests/data/item_names_742.lua, made
-- from scripts/npc/items.txt) or one of our own bundles (Item["item_mid_outfit"] and the like in
-- FuncLib/systems/item.lua) whose parts are. Removed items (Helm of the Overlord, Khanda, Javelin) fail here.
local T = ...
local Stub = T.stub

local ITEMS = assert(loadstring(T.read("Tests/data/item_names_742.lua"), "item_names_742"))()

-- The problems of one list entry, added to `problems`. Bundles are followed into their parts.
local function check(Item, name, where, problems, depth)
	if type(name) ~= "string" then
		problems[#problems + 1] = where .. ": entry is a " .. type(name)
		return
	end
	local bundle = Item[name]
	if type(bundle) == "table" and depth < 4 then
		for _, part in ipairs(bundle) do
			check(Item, part, where .. " > " .. name, problems, depth + 1)
		end
		return
	end
	if ITEMS[name] == nil then
		problems[#problems + 1] = where .. ": " .. name .. " is not an item in 7.42"
	elseif ITEMS[name] == false then
		problems[#problems + 1] = where .. ": " .. name .. " cannot be bought in 7.42"
	end
end

for _, path in ipairs(T.files("^BotsLib/hero_[%w_]+%.lua$")) do
	local file = string.match(path, "^BotsLib/(hero_[%w_]+)%.lua$")
	T.test("item names " .. file, function()
		local problems = {}
		local checked = 0
		for slot = 1, 5 do
			Stub.reset({ hero = "npc_dota_" .. file, slot = slot })
			local Item = require(GetScriptDirectory() .. "/FuncLib/systems/item")
			local ok, result = Stub.load("BotsLib/" .. file)
			if not ok then
				error(file .. " as pos " .. slot .. ": " .. tostring(result), 0)
			end
			for _, listName in ipairs({ "sBuyList", "sSellList" }) do
				for index, name in ipairs(result[listName] or {}) do
					checked = checked + 1
					check(Item, name, "pos " .. slot .. " " .. listName .. "[" .. index .. "]", problems, 0)
				end
			end
		end
		if #problems > 0 then
			error(table.concat(problems, "\n      "), 0)
		end
		-- The bear's own file has 2 entries per position; every hero has many more.
		T.ok(checked >= 10, file .. ": only " .. checked .. " list entries were read")
	end)
end

T.test("the item name check catches a removed item and follows a bundle", function()
	Stub.reset({ hero = "npc_dota_hero_lich" })
	local Item = require(GetScriptDirectory() .. "/FuncLib/systems/item")
	local problems = {}
	check(Item, "item_helm_of_the_overlord", "x", problems, 0)
	check(Item, "item_not_a_thing", "x", problems, 0)
	check(Item, "item_blink", "x", problems, 0)
	check(Item, "item_double_branches", "x", problems, 0)
	T.eq(#problems, 2, table.concat(problems, " | "))
	T.ok(string.find(problems[1], "cannot be bought", 1, true), problems[1])
	T.ok(string.find(problems[2], "is not an item", 1, true), problems[2])
end)

-- #109: item names Dota 7.42 no longer has stay out of the scripts. Each one is marked IsObsolete "1" in the 7.42
-- scripts/npc/items.txt, or is not in it at all (item_desolator_2, item_drum_of_endurance: Drum of Endurance is
-- item_ancient_janggo). They can never be held or bought, so a handler, dictionary entry or list entry for them
-- is dead code that hides what the bots really use.
local REMOVED_ITEMS = {
	"item_angels_demise",
	"item_desolator_2",
	"item_drum_of_endurance",
	"item_eternal_shroud",
	"item_helm_of_the_overlord",
	"item_hood_of_defiance",
	"item_iron_talon",
	"item_javelin",
	"item_necronomicon",
	"item_necronomicon_2",
	"item_necronomicon_3",
	"item_nether_shawl",
	"item_tome_of_knowledge",
	"item_wraith_pact",
}
-- Neutral items that are still in the 7.42 pool but whose AbilityBehavior is DOTA_ABILITY_BEHAVIOR_PASSIVE:
-- a cast rule for them never runs (Fu.CanCastAbility rejects a passive). Their names stay in the dictionaries.
local PASSIVE_NEUTRALS = { "item_stormcrafter", "item_revenants_brooch" }

-- The game scripts: every tracked Lua file outside the tests, the developer tools and the local test lineup.
local function scriptFiles()
	local result = {}
	for _, path in ipairs(T.files("%.lua$")) do
		if
			not string.find(path, "^Tests/")
			and not string.find(path, "^Util/")
			and path ~= "Customize/general.lua"
			and path ~= "Customize/build_info.lua"
		then
			result[#result + 1] = path
		end
	end
	return result
end

T.test("removed 7.42 items: the test's list matches the game file", function()
	for _, name in ipairs(REMOVED_ITEMS) do
		T.ok(ITEMS[name] ~= true, name .. " is buyable in Tests/data/item_names_742.lua: it is not removed")
	end
	for _, name in ipairs(PASSIVE_NEUTRALS) do
		T.eq(ITEMS[name], false, name .. " in Tests/data/item_names_742.lua")
	end
end)

T.test("removed 7.42 items: no script names them", function()
	local found = {}
	for _, path in ipairs(scriptFiles()) do
		local source = T.read(path)
		for _, name in ipairs(REMOVED_ITEMS) do
			if string.find(source, '"' .. name .. '"', 1, true) or string.find(source, "%f[%w_]" .. name .. "%s*=") then
				found[#found + 1] = path .. ": " .. name
			end
		end
	end
	T.ok(#found == 0, table.concat(found, "\n      "))
end)

T.test("passive 7.42 neutrals have no cast rule", function()
	local source = T.read("ability_item_usage_generic.lua")
	for _, name in ipairs(PASSIVE_NEUTRALS) do
		T.ok(
			not string.find(source, 'ConsiderItemDesire["' .. name .. '"]', 1, true),
			name .. " has a ConsiderItemDesire rule, but its 7.42 active is gone"
		)
	end
end)
