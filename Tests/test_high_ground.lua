-- FuncLib/systems/utils.lua: which lane a high-ground creep counts for (#12, game 048 52:40: with the bottom T3
-- down, a bottom wave counted for mid too and the team called "defend mid").
local T = ...

local function utils()
	T.stub.reset({ hero = "npc_dota_hero_lich" })
	return require(GetScriptDirectory() .. "/FuncLib/systems/utils")
end

-- Dire T3 spots, roughly where they stand on the map. open = the lane's T3 and barracks are gone.
local top, mid, bot = Vector(3550, 5780, 0), Vector(4280, 3780, 0), Vector(6260, 2860, 0)
local function spots(openTop, openMid, openBot)
	return { { loc = top, open = openTop }, { loc = mid, open = openMid }, { loc = bot, open = openBot } }
end
local t4 = Vector(5400, 4400, 0)

T.test("high ground: a bottom creep counts for bottom, not mid", function()
	local U = utils()
	local creep = Vector(6100, 2500, 0)
	T.eq(U.HighGroundCreepOwned(creep, mid, spots(false, false, false)), false, "mid T3")
	T.eq(U.HighGroundCreepOwned(creep, bot, spots(false, false, false)), true, "bottom T3 (remembered after it fell)")
	-- The bottom barracks behind the fallen T3 owns it too.
	T.eq(U.HighGroundCreepOwned(creep, Vector(6400, 3400, 0), spots(false, false, false)), true, "bottom barracks")
end)

T.test("high ground: a T4 takes only the creeps of an open lane", function()
	local U = utils()
	local topCreep = Vector(3600, 5500, 0)
	-- Top T3 or barracks still up: those call it, not the T4 (a small wave there is no T4 threat).
	T.eq(U.HighGroundCreepOwned(topCreep, t4, spots(false, false, true)), false, "T4, top creep, top lane closed")
	-- Bottom lane open (T3 and barracks gone): its creeps are the T4's.
	T.eq(U.HighGroundCreepOwned(Vector(6100, 2500, 0), t4, spots(false, false, true)), true, "T4, bottom creep, open")
end)

T.test("high ground: no spots known counts the creep", function()
	local U = utils()
	T.eq(U.HighGroundCreepOwned(Vector(6100, 2500, 0), mid, {}), true, "no spots")
end)
