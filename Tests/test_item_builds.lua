-- Item-build decisions from #9, per position: the buy list a hero file returns for a team slot.
local T = ...
local Stub = T.stub

local function buyList(file, slot)
	Stub.reset({ hero = "npc_dota_" .. file, slot = slot })
	local ok, result = Stub.load("BotsLib/" .. file)
	if not ok then
		error(file .. " as pos " .. slot .. ": " .. tostring(result), 0)
	end
	T.eq(type(result.sBuyList), "table", file .. " (pos " .. slot .. ") sBuyList")
	return result.sBuyList
end

local function indexOf(list, itemName)
	for index, name in ipairs(list) do
		if name == itemName then
			return index
		end
	end
	return nil
end

T.test("Night Stalker and Meepo buy a Blink Dagger in every position", function()
	for _, file in ipairs({ "hero_night_stalker", "hero_meepo" }) do
		for slot = 1, 5 do
			T.ok(indexOf(buyList(file, slot), "item_blink") ~= nil, file .. " pos " .. slot .. " has item_blink")
		end
	end
end)

T.test("Night Stalker pos 4/5: Blink before Echo Sabre, no caster-support items", function()
	for slot = 4, 5 do
		local list = buyList("hero_night_stalker", slot)
		T.ok(indexOf(list, "item_blink") < indexOf(list, "item_echo_sabre"), "pos " .. slot .. " Blink first")
		for _, gone in ipairs({ "item_priest_outfit", "item_mage_outfit", "item_mekansm", "item_glimmer_cape" }) do
			T.eq(indexOf(list, gone), nil, "pos " .. slot .. " " .. gone)
		end
	end
end)

T.test("Meepo: Blink right after Sange and Yasha, before the Shard", function()
	for slot = 1, 5 do
		local list = buyList("hero_meepo", slot)
		local blink = indexOf(list, "item_blink")
		T.eq(indexOf(list, "item_sange_and_yasha"), blink - 1, "pos " .. slot .. " Sange and Yasha then Blink")
		T.ok(blink < indexOf(list, "item_aghanims_shard"), "pos " .. slot .. " Blink before the Shard")
	end
end)

T.test("Keeper of the Light pos 4/5: Scepter, Urn and Force Staff, no Solar Crest", function()
	for slot = 4, 5 do
		local list = buyList("hero_keeper_of_the_light", slot)
		for _, gone in ipairs({ "item_solar_crest", "item_mekansm", "item_kaya_and_sange" }) do
			T.eq(indexOf(list, gone), nil, "pos " .. slot .. " " .. gone)
		end
		for _, wanted in ipairs({ "item_magic_wand", "item_urn_of_shadows", "item_force_staff" }) do
			T.ok(indexOf(list, wanted) ~= nil, "pos " .. slot .. " has " .. wanted)
		end
		T.ok(
			indexOf(list, "item_ultimate_scepter") < indexOf(list, "item_ultimate_scepter_2"),
			"pos " .. slot .. " Scepter before the Blessing"
		)
	end
end)

T.test("Arc Warden: no Spirit Vessel, Diffusal Blade or Disperser", function()
	for slot = 1, 5 do
		local list = buyList("hero_arc_warden", slot)
		for _, gone in ipairs({ "item_spirit_vessel", "item_diffusal_blade", "item_disperser" }) do
			T.eq(indexOf(list, gone), nil, "pos " .. slot .. " " .. gone)
		end
	end
end)

T.test("Spectre's sell pair is triggered by an item her list buys", function()
	Stub.reset({ hero = "npc_dota_hero_spectre", slot = 1 })
	local ok, result = Stub.load("BotsLib/hero_spectre")
	T.ok(ok, "hero_spectre loads")
	T.ok(indexOf(result.sBuyList, result.sSellList[1]) ~= nil, "trigger " .. tostring(result.sSellList[1]))
end)

T.test("Weaver: a support list with Urn, Spirit Vessel and the Scepter; no Scepter in the carry list", function()
	for slot = 4, 5 do
		local list = buyList("hero_weaver", slot)
		local urn, vessel = indexOf(list, "item_urn_of_shadows"), indexOf(list, "item_spirit_vessel")
		T.ok(urn ~= nil and vessel ~= nil and urn < vessel, "pos " .. slot .. " Urn then Spirit Vessel")
		T.ok(indexOf(list, "item_ultimate_scepter") ~= nil, "pos " .. slot .. " buys the Scepter (ally Time Lapse)")
		for _, carryItem in ipairs({ "item_satanic", "item_greater_crit", "item_falcon_blade" }) do
			T.eq(indexOf(list, carryItem), nil, "pos " .. slot .. " " .. carryItem)
		end
	end
	for slot = 1, 3 do
		T.eq(indexOf(buyList("hero_weaver", slot), "item_ultimate_scepter"), nil, "pos " .. slot .. " Scepter")
	end
end)

-- One pair of boots per list (#38): a list may name a pair and what it is built into, never two pairs.
local BOOTS = {
	item_boots = "boots",
	item_travel_boots = "boots",
	item_travel_boots_2 = "boots",
	item_arcane_boots = "arcane",
	item_guardian_greaves = "arcane",
	item_tranquil_boots = "tranquil",
	item_boots_of_bearing = "tranquil",
	item_phase_boots = "phase",
	item_power_treads = "treads",
}
T.test("the heroes whose boots changed name one pair of boots, with its upgrade at most", function()
	local changed = {
		{ "hero_grimstroke", 5, "arcane" },
		{ "hero_jakiro", 5, "arcane" },
		{ "hero_hoodwink", 5, "arcane" },
		{ "hero_snapfire", 5, "arcane" },
		{ "hero_tusk", 3, "phase" },
		{ "hero_invoker", 2, "boots" },
		{ "hero_lina", 1, "boots" },
		{ "hero_necrolyte", 3, "boots" },
	}
	for _, case in ipairs(changed) do
		local families = {}
		for _, name in ipairs(buyList(case[1], case[2])) do
			if BOOTS[name] ~= nil and not families[BOOTS[name]] then
				families[BOOTS[name]] = true
				families[#families + 1] = BOOTS[name]
			end
		end
		T.eq(table.concat(families, ","), case[3], case[1] .. " pos " .. case[2] .. " boots")
	end
end)
