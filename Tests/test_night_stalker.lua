-- BotsLib/hero_night_stalker.lua: when Crippling Fear is cast (#11): on heroes in a fight, on creeps only at
-- night with spare mana and no enemy hero in sight.
local T = ...
local Stub = T.stub

local function nightStalker()
	Stub.reset({ hero = "npc_dota_hero_night_stalker", slot = 3 })
	local ok, result = Stub.load("BotsLib/hero_night_stalker")
	if not ok then
		error(tostring(result), 0)
	end
	return result
end

local function situation(changes)
	local s = {
		inFight = false,
		heroesInAura = 0,
		freeHeroesInAura = 0,
		targetClose = false,
		heroesNearby = 0,
		night = true,
		attacking = true,
		manaAfter = 0.8,
		pushing = false,
		farming = false,
		laneCreeps = 0,
		neutrals = 0,
		ancient = false,
	}
	for key, value in pairs(changes) do
		s[key] = value
	end
	return s
end

T.test("night stalker: Crippling Fear on heroes in a fight", function()
	local X = nightStalker()
	local reason = X.CripplingFearReason
	T.eq(
		reason(situation({ inFight = true, heroesInAura = 1, freeHeroesInAura = 1, heroesNearby = 3 })),
		"fight",
		"one hero"
	)
	T.eq(reason(situation({ inFight = true, heroesInAura = 1, heroesNearby = 1 })), nil, "the only hero is stunned")
	T.eq(
		reason(situation({ inFight = true, heroesInAura = 2, heroesNearby = 2 })),
		"fight",
		"two heroes, both disabled"
	)
	T.eq(reason(situation({ inFight = true, heroesNearby = 2 })), nil, "nobody inside the radius")
	T.eq(reason(situation({ inFight = true, targetClose = true, heroesNearby = 1 })), "target", "closing on his target")
	T.eq(reason(situation({ heroesInAura = 1, freeHeroesInAura = 1, heroesNearby = 1 })), nil, "not fighting")
end)

T.test("night stalker: Crippling Fear on creeps", function()
	local X = nightStalker()
	local reason = X.CripplingFearReason
	T.eq(reason(situation({ pushing = true, laneCreeps = 4 })), "creeps-push", "wave at night, mana, no heroes")
	T.eq(reason(situation({ pushing = true, laneCreeps = 4, heroesNearby = 1 })), nil, "a hero in sight: saved")
	T.eq(reason(situation({ pushing = true, laneCreeps = 4, night = false })), nil, "by day")
	T.eq(reason(situation({ pushing = true, laneCreeps = 4, manaAfter = 0.4 })), nil, "no spare mana")
	T.eq(reason(situation({ pushing = true, laneCreeps = 3 })), nil, "small wave")
	T.eq(reason(situation({ farming = true, neutrals = 3 })), "creeps-farm", "camp")
	T.eq(reason(situation({ farming = true, neutrals = 2, ancient = true })), "creeps-farm", "ancients")
	T.eq(reason(situation({ farming = true, neutrals = 3, attacking = false })), nil, "not attacking")
end)
