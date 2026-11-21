-- Aghanim's Scepter / Shard abilities with a cast rule (#184). Each is looked up by name: the granted spell is
-- hidden at the start, and a slot-list index (sAbilityList[4]) only points at it while the engine keeps it in the
-- same slot. Each cast prints an [OHA-GRANTED] line so a game shows it. Ability names and slots: the 7.42 game
-- files (Tests/data/hero_abilities.lua).
local T = ...

local granted = {
	{ hero = "sniper", ability = "sniper_concussive_grenade" },
	{ hero = "necrolyte", ability = "necrolyte_death_seeker" },
	{ hero = "phantom_assassin", ability = "phantom_assassin_fan_of_knives" },
	{ hero = "undying", ability = "undying_bite" },
	{ hero = "templar_assassin", ability = "templar_assassin_trap_teleport" },
	{ hero = "dazzle", ability = "dazzle_through_the_realm" },
	{ hero = "beastmaster", ability = "beastmaster_summon_thunderhide" },
}

T.test("granted abilities: each exists in 7.42 and the hero file looks it up by name and logs the cast", function()
	local abilities = assert(loadstring(T.read("Tests/data/hero_abilities.lua"), "hero_abilities"))()
	for _, entry in ipairs(granted) do
		local found = false
		for _, slot in ipairs(abilities[entry.hero] or {}) do
			if string.match(slot, "^[^|]+") == entry.ability then
				found = true
			end
		end
		T.ok(found, entry.ability .. " is one of " .. entry.hero .. "'s 7.42 abilities")
		local src = T.read("BotsLib/hero_" .. entry.hero .. ".lua")
		T.ok(
			string.find(src, 'GetAbilityByName("' .. entry.ability .. '")', 1, true) ~= nil,
			entry.hero .. " looks up " .. entry.ability .. " by name"
		)
		T.ok(string.find(src, "[OHA-GRANTED]", 1, true) ~= nil, entry.hero .. " logs the cast")
	end
end)
