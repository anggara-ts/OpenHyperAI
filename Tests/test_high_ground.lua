-- FuncLib/systems/utils.lua: which lane a high-ground creep counts for (#12, game 048 52:40: with the bottom T3
-- down, a bottom wave counted for mid too and the team called "defend mid").
local T = ...

local function utils()
	T.stub.reset({ hero = "npc_dota_hero_lich" })
	return require(GetScriptDirectory() .. "/FuncLib/systems/utils")
end

-- Dire T3 spots, roughly where they stand on the map.
local top, mid, bot = Vector(3550, 5780, 0), Vector(4280, 3780, 0), Vector(6260, 2860, 0)
local spots = { top, mid, bot }

T.test("high ground: a bottom creep counts for bottom, not mid", function()
	local U = utils()
	local creep = Vector(6100, 2500, 0)
	T.eq(U.HighGroundCreepOwned(creep, mid, spots), false, "mid T3")
	T.eq(U.HighGroundCreepOwned(creep, bot, spots), true, "bottom T3 (remembered after it fell)")
	-- The bottom barracks behind the fallen T3 owns it too.
	T.eq(U.HighGroundCreepOwned(creep, Vector(6400, 3400, 0), spots), true, "bottom barracks")
end)

T.test("high ground: a T4 or the Ancient takes every creep", function()
	local U = utils()
	T.eq(U.HighGroundCreepOwned(Vector(6100, 2500, 0), Vector(5400, 4400, 0), spots), true, "T4, bottom creep")
	T.eq(U.HighGroundCreepOwned(Vector(3600, 5500, 0), Vector(5400, 4400, 0), spots), true, "T4, top creep")
end)

T.test("high ground: no spots known counts the creep", function()
	local U = utils()
	T.eq(U.HighGroundCreepOwned(Vector(6100, 2500, 0), mid, {}), true, "no spots")
end)
