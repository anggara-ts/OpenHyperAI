-- FuncLib/systems/straight_cast.lua: curving point abilities are aimed at their full range in the same direction (#36).
local T = ...

local function load()
	T.stub.reset({ hero = "npc_dota_hero_puck" })
	return require(GetScriptDirectory() .. "/FuncLib/systems/straight_cast")
end

local function unitAt(x, y)
	return {
		GetLocation = function()
			return Vector(x, y, 0)
		end,
	}
end

T.test("straight cast: a short aim is pushed out to the full range, same direction", function()
	local S = load()
	local p = S.Point(unitAt(0, 0), Vector(300, 400, 0), 1950)
	T.near(p.x, 1170, 0.5, "x")
	T.near(p.y, 1560, 0.5, "y")
end)

T.test("straight cast: an aim beyond the range is pulled in to it", function()
	local S = load()
	local p = S.Point(unitAt(100, 100), Vector(100, 5100, 0), 1400)
	T.near(p.x, 100, 0.5, "x")
	T.near(p.y, 1500, 0.5, "y")
end)

T.test("straight cast: an aim on the caster stays as it is", function()
	local S = load()
	local aim = Vector(10, 10, 0)
	T.eq(S.Point(unitAt(10, 10), aim, 1950), aim, "same point")
end)

T.test("straight cast: range from the special value, else the cast range, else the fallback", function()
	local S = load()
	local function ability(special, cast)
		return {
			IsNull = function()
				return false
			end,
			GetSpecialValueInt = function()
				return special
			end,
			GetCastRange = function()
				return cast
			end,
		}
	end
	T.eq(S.Range(ability(1950, 1800), "max_distance", 1000), 1950, "special value")
	T.eq(S.Range(ability(0, 1400), nil, 1000), 1400, "cast range")
	T.eq(S.Range(ability(0, 0), "max_distance", 1000), 1000, "fallback")
	T.eq(S.Range(nil, "max_distance", 1000), 1000, "no ability")
end)
