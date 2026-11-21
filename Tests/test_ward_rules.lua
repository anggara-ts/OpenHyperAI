-- #15: FuncLib/systems/ward.lua plant retry points and the maintainer's game 063 spots.
local T = ...

local function ward()
	T.stub.reset({ hero = "npc_dota_hero_zuus" })
	return require(GetScriptDirectory() .. "/FuncLib/systems/ward")
end

T.test("ward: plant retry tries 8 directions at 50, then at 100", function()
	local Ward = ward()
	local center = { x = -4365, y = -1012 }
	local points = Ward.RetryPoints(center)
	T.eq(#points, 16, "16 points")
	for i, point in ipairs(points) do
		local dist = math.sqrt((point[1] - center.x) ^ 2 + (point[2] - center.y) ^ 2)
		T.near(dist, i <= 8 and 50 or 100, 1e-6, "distance of point " .. i)
	end
	T.near(points[1][1], -4315, 1e-6, "first point east")
	T.near(points[3][2], -962, 1e-6, "third point north")
	T.near(points[9][1], -4265, 1e-6, "ninth point east at 100")
end)
