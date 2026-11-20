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
