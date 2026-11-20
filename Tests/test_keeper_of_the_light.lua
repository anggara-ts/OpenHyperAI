-- BotsLib/hero_keeper_of_the_light.lua: who gets Chakra Magic (#10).
local T = ...
local Stub = T.stub

local function keeper()
	Stub.reset({ hero = "npc_dota_hero_keeper_of_the_light", slot = 5 })
	local ok, result = Stub.load("BotsLib/hero_keeper_of_the_light")
	if not ok then
		error(tostring(result), 0)
	end
	return result
end

-- mana_restore 170 (level 2), self_bonus 30: 221 on himself.
T.test("keeper: Chakra Magic goes to a low ally first", function()
	local X = keeper()
	local own = { unit = "keeper", missing = 400, ratio = 0.5, spellOnCooldown = true }
	local allies = {
		{ unit = "lion", missing = 300, ratio = 0.4 },
		{ unit = "sven", missing = 250, ratio = 0.2 },
		{ unit = "lich", missing = 100, ratio = 0.1 },
	}
	local target, why = X.ChakraMagicChoice(own, allies, 170, 30)
	T.eq(target, "sven", "the lowest ally that can take the whole restore")
	T.eq(why, "ally-low", "why")
end)

T.test("keeper: Chakra Magic on himself when he is the empty one", function()
	local X = keeper()
	local own = { unit = "keeper", missing = 700, ratio = 0.1, spellOnCooldown = false }
	local allies = { { unit = "lion", missing = 300, ratio = 0.4 } }
	local target, why = X.ChakraMagicChoice(own, allies, 170, 30)
	T.eq(target, "keeper", "Keeper under 30% and lower than the ally")
	T.eq(why, "self-mana", "why")
end)

T.test("keeper: Chakra Magic on himself after a spell", function()
	local X = keeper()
	local allies = { { unit = "lion", missing = 100, ratio = 0.8 } }
	local target, why =
		X.ChakraMagicChoice({ unit = "keeper", missing = 125, ratio = 0.8, spellOnCooldown = true }, allies, 170, 30)
	T.eq(target, "keeper", "Illuminate on cooldown, 125 of 221 used")
	T.eq(why, "after-spell", "why")
	target =
		X.ChakraMagicChoice({ unit = "keeper", missing = 60, ratio = 0.9, spellOnCooldown = true }, allies, 170, 30)
	T.eq(target, nil, "nearly full: keep it")
	target =
		X.ChakraMagicChoice({ unit = "keeper", missing = 125, ratio = 0.8, spellOnCooldown = false }, allies, 170, 30)
	T.eq(target, nil, "nothing on cooldown and not missing 1.2x the restore")
end)

T.test("keeper: Chakra Magic tops up an ally when nobody is low", function()
	local X = keeper()
	local own = { unit = "keeper", missing = 20, ratio = 0.97, spellOnCooldown = false }
	local allies = {
		{ unit = "medusa", missing = 500, ratio = 0.75 },
		{ unit = "zuus", missing = 300, ratio = 0.7 },
	}
	local target, why = X.ChakraMagicChoice(own, allies, 170, 30)
	T.eq(target, "medusa", "the ally missing the most")
	T.eq(why, "ally-top-up", "why")
end)
