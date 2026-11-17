-- Pure helpers: FuncLib/general_utils/math_helper.lua and the distance / "towards" helpers of
-- FuncLib/general_utils/positioning.lua and FuncLib/systems/utils.lua.
local T = ...
local Stub = T.stub

local function load()
	Stub.reset({ hero = "npc_dota_hero_lich" })
	local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
	return Fu, Fu.Utils
end

T.test("math_helper: rounding and bitfields", function()
	local Fu = load()
	T.near(Fu.GetOne(0.87), 0.8, 1e-9, "GetOne(0.87)")
	T.near(Fu.GetOne(1), 1, 1e-9, "GetOne(1)")
	T.eq(Fu.ToNearest500(1249), 1000, "ToNearest500(1249)")
	T.eq(Fu.ToNearest500(1250), 1500, "ToNearest500(1250)")
	T.eq(Fu.CheckBitfieldFlag(4 + 16, 16), true, "flag 16 in 20")
	T.eq(Fu.CheckBitfieldFlag(4 + 16, 8), false, "flag 8 in 20")
	T.eq(Fu.CheckBitfieldFlag(64, 64), true, "flag 64 in 64")
end)

T.test("math_helper: HP / MP ratios and ETA", function()
	local Fu = load()
	local unit = Stub.newUnit({ name = "npc_dota_hero_lion", team = TEAM_DIRE, hp = 250, maxHp = 1000, mana = 300 })
	T.near(Fu.GetHP(unit), 0.25, 1e-9, "GetHP")
	T.near(Fu.GetMP(unit), 0.6, 1e-9, "GetMP (maxMana 500)")
	T.eq(Fu.GetHP(nil), 0, "GetHP(nil)")
	unit._alive = false
	T.eq(Fu.GetHP(unit), 0, "GetHP of a dead unit")
	local bot = GetBot()
	bot._mana, bot._maxMana = 400, 800
	T.near(Fu.GetManaAfter(100), 0.375, 1e-9, "GetManaAfter(100)")
	-- (sqrt(2ad + v^2) - v) / a
	T.near(Fu.GetETAWithAcceleration(1000, 0, 2000), 1, 1e-9, "ETA from rest")
	T.near(Fu.GetETAWithAcceleration(1500, 1000, 1000), 1, 1e-9, "ETA with start speed")
end)

T.test("positioning: distances", function()
	local Fu, Utils = load()
	local a, b = Vector(0, 0, 0), Vector(300, 400, 128)
	T.near(Fu.GetLocationToLocationDistance(a, b), 500, 1e-9, "Fu.GetLocationToLocationDistance")
	T.near(Utils.GetLocationToLocationDistance(a, b), 500, 1e-9, "Utils.GetLocationToLocationDistance")
	T.near(Fu.GetDistance({ 0, 0 }, { -6, 8 }), 10, 1e-9, "GetDistance on {x, y} pairs")
end)

T.test("positioning: towards / away", function()
	local Fu, Utils = load()
	local from, to = Vector(100, 100, 0), Vector(100, 1100, 0)
	local p = Fu.VectorTowards(from, to, 250)
	T.near(p.x, 100, 1e-9, "VectorTowards x")
	T.near(p.y, 350, 1e-9, "VectorTowards y")
	p = Fu.VectorAway(from, to, 250)
	T.near(p.y, -150, 1e-9, "VectorAway y")
	p = Fu.GetXUnitsTowardsLocation2(from, Vector(1100, 100, 0), 500)
	T.near(p.x, 600, 1e-9, "GetXUnitsTowardsLocation2 x")
	p = Utils.GetOffsetLocationTowardsTargetLocation(Vector(0, 0, 0), Vector(-30, -40, 0), 10)
	T.near(p.x, -6, 1e-9, "GetOffsetLocationTowardsTargetLocation x")
	T.near(p.y, -8, 1e-9, "GetOffsetLocationTowardsTargetLocation y")

	local bot = GetBot()
	bot._loc = Vector(0, 0, 0)
	local target = Stub.newUnit({ name = "npc_dota_hero_axe", loc = Vector(0, -2000, 0) })
	p = Fu.GetUnitTowardDistanceLocation(bot, target, 500)
	T.near(p.y, -500, 1e-9, "GetUnitTowardDistanceLocation y")
	p = Fu.GetLocationTowardDistanceLocation(bot, Vector(1000, 0, 0), 300)
	T.near(p.x, 300, 1e-9, "GetLocationTowardDistanceLocation x")
end)
