-- Whole item builds (#38): every list Util/item-builds/generate.js wrote is walked here the way
-- item_purchase_generic.lua buys it. The walk is the Lua twin of Util/item-builds/lib/sim.js: what each entry
-- costs with the parts already held, what combines, what the sell rules take away. A list fails when
--   * the hero would need more than six main slots (items of 600 gold or less and the early items the script
--     sells by itself are backpack filler and do not count),
--   * a sell rule sells something a later entry needs (the buy/sell loop),
--   * an entry is already owned when its turn comes, or is not an item of the game file.
-- Also here: the pins of Util/item-builds/pins.json, the farm rules of FuncLib/data/site.lua (an item a rule
-- waits for without a net-worth cap must be in the list; one with a cap is either bought or on record in
-- status.json), and URN_BUILDS of FuncLib/systems/item_strategy.lua against the lists.
-- Util/item-builds/status.json says what the generator did with each hero and position; lists it kept as they
-- were ("kept") are not walked: they are the old hand-written lists and wait for a decision.
local T = ...
local Stub = T.stub

local RECIPES = assert(loadstring(T.read("Tests/data/item_recipes_742.lua"), "item_recipes_742"))()
local json = assert(loadstring(T.read("FuncLib/lib/json.lua"), "json"))()
local STATUS = json.decode(T.read("Util/item-builds/status.json"))
local PINS = json.decode(T.read("Util/item-builds/pins.json"))

local NO_SLOT = {
	item_tango = true,
	item_clarity = true,
	item_flask = true,
	item_faerie_fire = true,
	item_enchanted_mango = true,
	item_blood_grenade = true,
	item_tpscroll = true,
	item_smoke_of_deceit = true,
	item_dust = true,
	item_ward_observer = true,
	item_ward_sentry = true,
	item_aghanims_shard = true,
	item_moon_shard = true,
	item_ultimate_scepter_2 = true,
	item_tome_of_knowledge = true,
}
local FILLER_COST = 600

-- itemAliases is local to item.lua: read it from the source.
local ALIAS = {}
do
	local source = T.read("FuncLib/systems/item.lua")
	local from = string.find(source, "local itemAliases = {", 1, true)
	local to = string.find(source, "\n}", from, true)
	for name, target in string.gmatch(string.sub(source, from, to), '%["(item_[%w_]+)"%]%s*=%s*"(item_[%w_]+)"') do
		ALIAS[name] = target
	end
end

local function cost(name)
	return RECIPES[name] and RECIPES[name].cost or 0
end

local function isBundle(Item, name)
	return type(Item[name]) == "table" and (string.find(name, "^item_") ~= nil or string.find(name, "^PvN_") ~= nil)
end

local function closure(Item, entry, out)
	out = out or {}
	if out[entry] then
		return out
	end
	out[entry] = true
	if isBundle(Item, entry) then
		for _, part in ipairs(Item[entry]) do
			closure(Item, part, out)
		end
	end
	return out
end

local function toSet(list)
	local set = {}
	for _, name in ipairs(list or {}) do
		set[name] = true
	end
	return set
end

-- Returns the problems of one list (strings) and the items held at the end.
local function simulate(Item, listIn, pos, heroSell)
	local list = {}
	local seenTravel = false
	for _, entry in ipairs(listIn) do
		if entry == "item_travel_boots" then
			seenTravel = true
		elseif entry == "item_travel_boots_2" and not seenTravel then
			list[#list + 1] = "item_travel_boots"
			seenTravel = true
		end
		list[#list + 1] = entry
	end
	local earlyItems = toSet(Item.tEarlyItem)
	local supportSell = toSet(Item.tSupportSellWhenFull)
	local pairsList = {}
	for _, source in ipairs({ Item.sSellList, heroSell or {} }) do
		for index = 2, #source, 2 do
			pairsList[#pairsList + 1] = { source[index - 1], source[index] }
		end
	end
	pairsList[#pairsList + 1] = { "item_satanic", "item_mask_of_madness" }
	local inv = {}
	local blessing, moon = false, false
	local problems = {}
	local function count(name)
		local total = 0
		for _, held in ipairs(inv) do
			if held == name then
				total = total + 1
			end
		end
		return total
	end
	local function remove(name)
		for index, held in ipairs(inv) do
			if held == name then
				table.remove(inv, index)
				return true
			end
		end
		return false
	end
	local function owned(name)
		if ALIAS[name] then
			return owned(ALIAS[name])
		end
		if string.find(name, "^item_double_") then
			return count((string.gsub(name, "_double", ""))) >= 2
		end
		if string.find(name, "^PvN_") then
			return moon
		end
		if name == "item_ultimate_scepter" then
			return blessing or count(name) > 0
		end
		if name == "item_moon_shard" then
			return moon
		end
		if name == "item_ultimate_scepter_2" then
			return blessing and count("item_ultimate_scepter") == 0
		end
		return count(name) > 0
	end
	local function neededLater(name, from)
		for index = from, #list do
			if closure(Item, list[index])[name] then
				return list[index]
			end
		end
		return nil
	end
	local function fodder(name)
		return cost(name) <= FILLER_COST or earlyItems[name] or (pos >= 4 and supportSell[name])
	end
	for index, entry in ipairs(list) do
		local auraBoots = count("item_guardian_greaves") + count("item_boots_of_bearing") > 0
		if owned(entry) then
			problems[#problems + 1] = entry .. " is already owned when its turn comes"
		elseif auraBoots and string.find(entry, "^item_travel_boots") then
			problems[#problems + 1] = entry .. " is skipped in game: Guardian Greaves or Boots of Bearing is owned"
		else
			local ownedLeft = {}
			local basics = {}
			local function expand(name)
				if ownedLeft[name] == nil then
					ownedLeft[name] = owned(name) and math.max(1, count(name)) or 0
				end
				if ownedLeft[name] > 0 then
					ownedLeft[name] = ownedLeft[name] - 1
				elseif isBundle(Item, name) then
					for _, part in ipairs(Item[name]) do
						expand(part)
					end
				else
					basics[#basics + 1] = name
				end
			end
			expand(entry)
			for _, basic in ipairs(basics) do
				if RECIPES[basic] == nil then
					problems[#problems + 1] = entry .. ": " .. basic .. " is not an item a hero can buy"
				else
					if RECIPES[basic].parts ~= nil then
						-- A finished item with no recipe in item.lua would be bought whole, at full price in one go.
						problems[#problems + 1] = entry
							.. ": "
							.. basic
							.. " has no recipe in item.lua (sCompositeItems)"
					end
					inv[#inv + 1] = basic
				end
			end
			-- Combine, parts first.
			local targets = {}
			for name in pairs(closure(Item, entry)) do
				if RECIPES[name] ~= nil and isBundle(Item, name) and not string.find(name, "^item_double_") then
					targets[#targets + 1] = name
				end
			end
			table.sort(targets)
			for _ = 1, 8 do
				local combined = false
				for _, target in ipairs(targets) do
					local need = {}
					for _, part in ipairs(Item[target]) do
						need[part] = (need[part] or 0) + 1
					end
					local complete = true
					for part, wanted in pairs(need) do
						if count(part) < wanted then
							complete = false
						end
					end
					if complete then
						for _, part in ipairs(Item[target]) do
							remove(part)
						end
						inv[#inv + 1] = string.find(target, "^item_power_treads_") and "item_power_treads" or target
						combined = true
					end
				end
				if not combined then
					break
				end
			end
			for at = #inv, 1, -1 do
				if NO_SLOT[inv[at]] then
					if inv[at] == "item_ultimate_scepter_2" then
						blessing = true
					elseif inv[at] == "item_moon_shard" then
						moon = true
					end
					table.remove(inv, at)
				end
			end
			local function sell(victim, why)
				if remove(victim) then
					local later = neededLater(victim, index + 1)
					if later then
						problems[#problems + 1] = victim
							.. " is sold ("
							.. why
							.. ") and "
							.. later
							.. " needs it later"
					elseif closure(Item, entry)[victim] and why ~= "inventory full" then
						-- Bought while the item that sells it is already owned.
						problems[#problems + 1] = victim
							.. " is bought for "
							.. entry
							.. " and sold at once ("
							.. why
							.. ")"
					end
					return true
				end
				return false
			end
			for _ = 1, 4 do
				local any = false
				for _, pair in ipairs(pairsList) do
					if pair[1] ~= pair[2] and count(pair[1]) > 0 and count(pair[2]) > 0 then
						any = sell(pair[2], "pair with " .. pair[1]) or any
					end
				end
				if not any then
					break
				end
			end
			if count("item_travel_boots") + count("item_travel_boots_2") > 0 then
				for _, boots in ipairs(Item.tEarlyBoots) do
					if count(boots) > 0 then
						sell(boots, "Boots of Travel owned")
					end
				end
			end
			local keepers = {}
			for _, held in ipairs(inv) do
				if not fodder(held) then
					keepers[#keepers + 1] = held
				end
			end
			if #keepers > 6 then
				problems[#problems + 1] = entry
					.. ": "
					.. #keepers
					.. " items for six slots ("
					.. table.concat(keepers, ", ")
					.. ")"
			end
			while #inv >= 9 do
				local victim = nil
				for _, name in ipairs(Item.tEarlyItem) do
					if count(name) > 0 then
						victim = name
						break
					end
				end
				if victim == nil and pos >= 4 then
					for _, name in ipairs(Item.tSupportSellWhenFull) do
						if count(name) > 0 then
							victim = name
							break
						end
					end
				end
				if victim == nil then
					for _, held in ipairs(inv) do
						if cost(held) <= FILLER_COST then
							victim = held
							break
						end
					end
				end
				if victim == nil then
					problems[#problems + 1] = entry .. ": the inventory is full (" .. table.concat(inv, ", ") .. ")"
					break
				end
				sell(victim, "inventory full")
			end
		end
	end
	return problems, inv
end

local function load(file, slot, allies)
	Stub.reset({ hero = "npc_dota_" .. file, slot = slot, allies = allies })
	local Item = require(GetScriptDirectory() .. "/FuncLib/systems/item")
	local ok, result = Stub.load("BotsLib/" .. file)
	if not ok then
		error(file .. " as pos " .. slot .. ": " .. tostring(result), 0)
	end
	return result, Item
end

local function indexOf(list, itemName)
	for index, name in ipairs(list) do
		if name == itemName then
			return index
		end
	end
	return nil
end

-- A team of heroes with no Urn build and no flexible team item, so the list under test keeps its own.
local PLAIN_TEAM = {
	"npc_dota_hero_sniper",
	"npc_dota_hero_sniper",
	"npc_dota_hero_sniper",
	"npc_dota_hero_sniper",
	"npc_dota_hero_sniper",
}

local BUILT = { data = true, neighbour = true, alias = true }

for _, path in ipairs(T.files("^BotsLib/hero_[%w_]+%.lua$")) do
	local file = string.match(path, "^BotsLib/(hero_[%w_]+)%.lua$")
	local hero = string.sub(file, 6)
	local heroStatus = STATUS.heroes[hero]
	if heroStatus ~= nil then
		T.test("build walk " .. file, function()
			local problems = {}
			for slot = 1, 5 do
				local info = heroStatus[tostring(slot)]
				if info ~= nil and BUILT[info.status] then
					local result, Item = load(file, slot, PLAIN_TEAM)
					local found = simulate(Item, result.sBuyList, slot, result.sSellList)
					for _, problem in ipairs(found) do
						problems[#problems + 1] = "pos " .. slot .. ": " .. problem
					end
				end
			end
			if #problems > 0 then
				error(table.concat(problems, "\n      "), 0)
			end
		end)
	end
end

T.test("the walk catches a seventh item, a sell loop and a repeated entry", function()
	Stub.reset({ hero = "npc_dota_hero_lich" })
	local Item = require(GetScriptDirectory() .. "/FuncLib/systems/item")
	local seven = {
		"item_power_treads",
		"item_blink",
		"item_black_king_bar",
		"item_sheepstick",
		"item_shivas_guard",
		"item_heart",
		"item_assault",
	}
	local problems = simulate(Item, seven, 1, {})
	T.eq(#problems, 1, table.concat(problems, " | "))
	T.ok(string.find(problems[1], "7 items for six slots", 1, true), problems[1])
	-- Boots of Travel sell the Arcane Boots that Guardian Greaves still needs.
	problems = simulate(Item, { "item_arcane_boots", "item_travel_boots", "item_guardian_greaves" }, 5, {})
	T.ok(string.find(table.concat(problems, " | "), "needs it later", 1, true), table.concat(problems, " | "))
	problems = simulate(Item, { "item_blink", "item_blink" }, 1, {})
	T.ok(string.find(table.concat(problems, " | "), "already owned", 1, true), table.concat(problems, " | "))
	-- An upgrade uses the held item, and the Blessing frees the Scepter's slot.
	local chain = { "item_force_staff", "item_hurricane_pike", "item_ultimate_scepter", "item_ultimate_scepter_2" }
	local held
	problems, held = simulate(Item, chain, 1, {})
	T.eq(#problems, 0, table.concat(problems, " | "))
	T.eq(table.concat(held, ","), "item_hurricane_pike", "held at the end")
	-- Assault Cuirass sells a Drum of Endurance (Item.sSellList): a Drum bought after it is gold thrown away.
	problems = simulate(Item, { "item_assault", "item_ancient_janggo" }, 3, {})
	T.ok(string.find(table.concat(problems, " | "), "sold at once", 1, true), table.concat(problems, " | "))
end)

-- Invoker's second mid list is picked at random in game (Quas-Exort), so no team slot returns it for sure: it is
-- read from the file and walked like the others.
T.test("build walk hero_invoker, the pos_2_qe list", function()
	local source = T.read("BotsLib/hero_invoker.lua")
	local body = string.match(source, 'sRoleItemsBuyList%["pos_2_qe"%] = {(.-)\n}')
	T.ok(body ~= nil, "the pos_2_qe list is in the file")
	local list = {}
	for name in string.gmatch(body, '"(item_[%w_]+)"') do
		list[#list + 1] = name
	end
	T.ok(#list >= 10, "the pos_2_qe list has " .. #list .. " entries")
	local result, Item = load("hero_invoker", 2, PLAIN_TEAM)
	local problems = simulate(Item, list, 2, result.sSellList)
	T.eq(#problems, 0, table.concat(problems, " | "))
	for _, gone in ipairs({ "item_ultimate_scepter", "item_ultimate_scepter_2", "item_aghanims_shard" }) do
		T.eq(indexOf(list, gone), nil, "pos_2_qe " .. gone)
	end
end)

T.test("status.json covers every list the hero files return", function()
	local counted = { data = 0, neighbour = 0, alias = 0, kept = 0 }
	for hero, positions in pairs(STATUS.heroes) do
		for pos, info in pairs(positions) do
			if string.find(pos, "^%d$") then
				T.ok(counted[info.status] ~= nil, hero .. " pos " .. pos .. " status " .. tostring(info.status))
				counted[info.status] = counted[info.status] + 1
				if info.status == "kept" or info.status == "alias" then
					T.ok(type(info.reason) == "string" and #info.reason > 0, hero .. " pos " .. pos .. " has a reason")
				end
				if info.status == "data" then
					T.ok(info.matches >= STATUS.minMatches, hero .. " pos " .. pos .. " has enough matches")
				end
			end
		end
	end
	for status, total in pairs(counted) do
		T.eq(total, STATUS.totals[status], "lists with status " .. status)
	end
end)

local BOOT_FAMILY = {
	item_boots = "item_boots",
	item_arcane_boots = "item_arcane_boots",
	item_guardian_greaves = "item_arcane_boots",
	item_tranquil_boots = "item_tranquil_boots",
	item_boots_of_bearing = "item_tranquil_boots",
	item_phase_boots = "item_phase_boots",
	item_power_treads = "item_power_treads",
}

T.test("the pins of Util/item-builds/pins.json hold in the lists", function()
	T.ok(#PINS.pins >= 10, "pins.json has its pins")
	for _, pin in ipairs(PINS.pins) do
		T.ok(type(pin.reason) == "string" and #pin.reason > 0, pin.hero .. ": a pin has a reason")
		if not pin.keep then
			for _, pos in ipairs(pin.pos or { 1, 2, 3, 4, 5 }) do
				local info = (STATUS.heroes[pin.hero] or {})[tostring(pos)]
				if info ~= nil and BUILT[info.status] then
					local list = load("hero_" .. pin.hero, pos, PLAIN_TEAM).sBuyList
					local where = pin.hero .. " pos " .. pos .. ": "
					for _, name in ipairs(pin.require or {}) do
						T.ok(indexOf(list, name) ~= nil, where .. "buys " .. name)
					end
					for _, name in ipairs(pin.forbid or {}) do
						T.eq(indexOf(list, name), nil, where .. name)
					end
					for _, order in ipairs(pin.before or {}) do
						local first, second = indexOf(list, order[1]), indexOf(list, order[2])
						T.ok(
							first == nil or second == nil or first < second,
							where .. order[1] .. " before " .. order[2]
						)
					end
					for _, order in ipairs(pin.adjacent or {}) do
						T.eq(
							indexOf(list, order[2]),
							indexOf(list, order[1]) + 1,
							where .. order[2] .. " right after " .. order[1]
						)
					end
					if pin.boots then
						for _, name in ipairs(list) do
							if BOOT_FAMILY[name] ~= nil then
								T.eq(BOOT_FAMILY[name], pin.boots, where .. "boots")
							end
						end
					end
				end
			end
		end
	end
end)

-- Must-have items (FuncLib/data/must_have_items.lua, Site.FarmForMustHave): the farm rules wait for these instead of
-- item waits picked by hand (maintainer, 2026-11-20).
local MUST_HAVE = assert(loadstring(T.read("FuncLib/data/must_have_items.lua"), "must_have_items"))()
local OTHER_TEAM = {
	"npc_dota_hero_drow_ranger",
	"npc_dota_hero_drow_ranger",
	"npc_dota_hero_drow_ranger",
	"npc_dota_hero_drow_ranger",
	"npc_dota_hero_drow_ranger",
}
T.test("the must-have items are core items of the hero's own list, in list order, with growing caps", function()
	local positions = 0
	for hero, heroRows in pairs(MUST_HAVE) do
		for pos, rows in pairs(heroRows) do
			T.ok(pos >= 1 and pos <= 3, hero .. ": core positions only, got " .. tostring(pos))
			T.ok(#rows >= 1 and #rows <= 3, hero .. " pos " .. pos .. ": one to three items")
			-- The team of five Snipers gives each slot its position; Sniper himself needs another team.
			local team = hero == "sniper" and OTHER_TEAM or PLAIN_TEAM
			local result = load("hero_" .. hero, pos, team)
			local list = result.sBuyList or {}
			local lastIndex, lastCap = 0, 0
			for _, row in ipairs(rows) do
				local at = indexOf(list, row[1])
				T.ok(at ~= nil, hero .. " pos " .. pos .. ": " .. row[1] .. " is not in the list")
				T.ok(at > lastIndex, hero .. " pos " .. pos .. ": " .. row[1] .. " out of list order")
				T.ok(row[2] > lastCap, hero .. " pos " .. pos .. ": the caps grow")
				for _, other in ipairs(row.done or {}) do
					T.ok(
						indexOf(list, other) ~= nil,
						hero .. " pos " .. pos .. ": done item " .. other .. " is not in the list"
					)
				end
				lastIndex, lastCap = at, row[2]
			end
			positions = positions + 1
		end
	end
	T.ok(positions >= 300, "core positions with must-have items (" .. positions .. ")")
end)

T.test("no hero farm rule waits for an item picked by hand any more", function()
	local source = T.read("FuncLib/data/site.lua")
	local from = string.find(source, "\nSite%.ConsiderIsTimeToFarm = {}")
	T.ok(from ~= nil, "the farm table")
	local _, waits = string.gsub(string.sub(source, from), 'not HasItem%(bot, "item_', "")
	T.eq(waits, 0, "item waits in Site.ConsiderIsTimeToFarm")
	T.ok(
		string.find(source, "isTimeToFarm = Site.FarmForMustHave(bot)", 1, true) ~= nil,
		"the shared farm decision asks the table"
	)
end)

T.test("Site.FarmForMustHave: the next must-have item until its cap, a later one only away from a fight", function()
	local unit = Stub.reset({ hero = "npc_dota_hero_antimage", slot = 1 })
	local Site = require(GetScriptDirectory() .. "/FuncLib/data/site")
	local rows = MUST_HAVE.antimage[1]
	local owned, worth, allies = {}, 1000, 0
	unit.FindItemSlot = function(_, name)
		return owned[name] and 0 or -1
	end
	unit.GetNetWorth = function()
		return worth
	end
	Site.GetPosition = function()
		return 1
	end
	Site.GetAroundAllyCount = function()
		return allies
	end
	local farm, item = Site.FarmForMustHave(unit)
	T.ok(farm, "farms for the first item")
	T.eq(item, rows[1][1], "the first item")
	owned[rows[1][1]] = true
	allies = 3
	farm, item = Site.FarmForMustHave(unit)
	T.eq(item, rows[2][1], "then the second")
	T.ok(not farm, "a later item: not with three allies near")
	allies = 1
	T.ok((Site.FarmForMustHave(unit)), "a later item: farms away from a fight")
	worth = rows[#rows][2] + 1
	farm, item = Site.FarmForMustHave(unit)
	T.ok(not farm and item == nil, "past every cap: no wait")
end)

-- Build-up parts (Util/item-builds/lib/build.js BUILD_PARTS): bought only on the way to an upgrade the list buys
-- later, never kept or sold on their own (maintainer, 2026-11-20: a list sells an early item it replaced, like
-- Falcon Blade or boots for Boots of Travel, not a part).
local BUILD_PARTS =
	{ item_sange = true, item_yasha = true, item_kaya = true, item_pers = true, item_lesser_crit = true }
local function recipeTree(name, out)
	out = out or {}
	if out[name] then
		return out
	end
	out[name] = true
	for _, part in ipairs((RECIPES[name] or {}).parts or {}) do
		recipeTree(part, out)
	end
	return out
end
T.test("a build-up part is bought only before an upgrade the list buys, and no sell pair sells one", function()
	local checked = 0
	for hero, positions in pairs(STATUS.heroes) do
		for slot = 1, 5 do
			local info = positions[tostring(slot)]
			if info ~= nil and BUILT[info.status] then
				local result = load("hero_" .. hero, slot, PLAIN_TEAM)
				local list = result.sBuyList or {}
				for index, name in ipairs(list) do
					if BUILD_PARTS[name] then
						local upgraded = false
						for later = index + 1, #list do
							if
								type(list[later]) == "string"
								and list[later] ~= name
								and recipeTree(list[later])[name]
							then
								upgraded = true
							end
						end
						T.ok(upgraded, hero .. " pos " .. slot .. ": " .. name .. " with no upgrade after it")
					end
				end
				local sell = result.sSellList or {}
				for index = 2, #sell, 2 do
					T.ok(
						not BUILD_PARTS[sell[index]],
						hero .. " pos " .. slot .. ": a sell pair sells " .. tostring(sell[index])
					)
				end
				checked = checked + 1
			end
		end
	end
	T.ok(checked >= 500, "lists checked (" .. checked .. ")")
end)

T.test("URN_BUILDS names the positions whose list buys an Urn, a Spirit Vessel or an Essence Distiller", function()
	local source = T.read("FuncLib/systems/item_strategy.lua")
	local from = string.find(source, "local URN_BUILDS = {", 1, true)
	local to = string.find(source, "\n}", from, true)
	local urn = {}
	for hero, positions in string.gmatch(string.sub(source, from, to), "npc_dota_hero_([%w_]+) = {([^}]*)}") do
		urn[hero] = {}
		for pos in string.gmatch(positions, "%d") do
			urn[hero][tonumber(pos)] = true
		end
	end
	local family = { item_urn_of_shadows = true, item_spirit_vessel = true, item_essence_distiller = true }
	for hero, heroStatus in pairs(STATUS.heroes) do
		for slot = 1, 5 do
			local info = heroStatus[tostring(slot)]
			if info ~= nil and BUILT[info.status] then
				local result, Item = load("hero_" .. hero, slot, PLAIN_TEAM)
				local buys = false
				for _, entry in ipairs(result.sBuyList) do
					for name in pairs(closure(Item, entry)) do
						buys = buys or family[name] == true
					end
				end
				T.eq(buys, (urn[hero] or {})[slot] == true, hero .. " pos " .. slot .. " in URN_BUILDS")
			end
		end
	end
end)
