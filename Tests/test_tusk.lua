-- BotsLib/hero_tusk.lua: which allies the snowball picks up, and when an ally counts as carried (#28).
local T = ...
local Stub = T.stub

local function tusk()
	Stub.reset({ hero = "npc_dota_hero_tusk", slot = 4 })
	local ok, result = Stub.load("BotsLib/hero_tusk")
	if not ok then
		error(tostring(result), 0)
	end
	return result
end

T.test("tusk: allies worth adding to the snowball", function()
	local X = tusk()
	-- real hero, hp ratio, channelling, retreating, distance, snowball_grab_radius
	T.eq(X.SnowballAllyOk(true, 0.9, false, false, 200, 325), true, "healthy ally next to him")
	T.eq(X.SnowballAllyOk(false, 0.9, false, false, 200, 325), false, "an illusion is not carried")
	T.eq(X.SnowballAllyOk(true, 0.4, false, false, 200, 325), false, "hurt ally stays out")
	T.eq(X.SnowballAllyOk(true, 0.9, true, false, 200, 325), false, "channelling ally stays out")
	T.eq(X.SnowballAllyOk(true, 0.9, false, true, 200, 325), false, "retreating ally stays out")
	T.eq(X.SnowballAllyOk(true, 0.9, false, false, 320, 325), false, "at the edge of the grab radius")
end)

T.test("tusk: an ally counts as carried", function()
	local X = tusk()
	-- invulnerable at launch, Tusk modifiers at launch, distance now, distance rolled
	T.eq(X.SnowballCarried(true, 0, 0, 0), true, "invulnerable in the snowball")
	T.eq(X.SnowballCarried(false, 1, 300, 50), true, "under a snowball modifier")
	T.eq(X.SnowballCarried(false, 0, 40, 600), true, "still on top of Tusk after 600 of rolling")
	T.eq(X.SnowballCarried(false, 0, 500, 600), false, "left behind")
	T.eq(X.SnowballCarried(false, 0, 40, 60), false, "the snowball hardly moved: no proof")
end)
