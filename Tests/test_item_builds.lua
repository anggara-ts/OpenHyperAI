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
