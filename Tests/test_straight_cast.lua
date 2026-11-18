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

T.test("straight cast: FaceFirst casts when facing the point, else steps toward it", function()
	local S = load()
	local moved = nil
	local unit = {
		GetLocation = function()
			return Vector(0, 0, 0)
		end,
		GetFacing = function()
			return 90 -- facing +y
		end,
		Action_MoveToLocation = function(_, loc)
			moved = loc
		end,
	}
	local angle, ok = S.FaceFirst(unit, Vector(0, 1000, 0), 12)
	T.ok(ok, "facing +y, point on +y")
	T.near(angle, 0, 0.01, "no angle")
	T.eq(moved, nil, "no step")
	angle, ok = S.FaceFirst(unit, Vector(1000, 0, 0), 12)
	T.ok(not ok, "point on +x needs a turn")
	T.near(angle, 90, 0.01, "90 degrees")
	T.near(moved.x, 60, 0.5, "steps 60 toward the point")
	angle = S.FaceFirst(unit, Vector(10, -1000, 0), 12)
	T.ok(angle > 170 and angle <= 180, "behind: about 180")
end)
