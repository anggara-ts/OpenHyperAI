-- Shared bot system: straight casts for point abilities that curve (#36).
-- Bots can't alt-cast: the cast orders have no alt flag, and the autocast toggle sets the button's state but not
-- the cast (game 043: Illusory Orb and Stroke of Fate still curved with it on; discussion #50 item 2).
-- These two curve by where the cast point lies: aimed short of the maximum the path bends (game files:
-- puck_illusory_orb curve_orb 1, curve_orb_pullback_bonus_launch_speed, max_distance 1950;
-- grimstroke_dark_artistry vector_strength 0.6, AbilityCastRange 1400). Cast at the full range in the target's
-- direction and the path is straight (maintainer, game 043: "casting at the furthest point looks straight").
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local StraightCast = {}

-- The cast point at `range` from the unit, in the direction of `aim`. A point on top of the unit stays as it is.
function StraightCast.Point(unit, aim, range)
	if unit == nil or aim == nil or range == nil or range <= 0 then
		return aim
	end
	local from = unit:GetLocation()
	if (aim - from):Length2D() < 1 then
		return aim
	end
	return Fu.VectorTowards(from, aim, range)
end

-- The ability's full range: a special value when the game data has one, else its cast range, else `fallback`.
function StraightCast.Range(ability, valueName, fallback)
	if ability == nil or ability:IsNull() then
		return fallback
	end
	if valueName ~= nil then
		local value = ability:GetSpecialValueInt(valueName)
		if value ~= nil and value > 0 then
			return value
		end
	end
	local castRange = ability:GetCastRange()
	if castRange ~= nil and castRange > 0 then
		return castRange
	end
	return fallback
end

-- Game 044, 2:26: the orb still curved at full range (`orb cast point=max ... cast=1948`). Both abilities' files have
-- facing settings (grimstroke_dark_artistry vector_min_cos_facing_angle; illusory orb curve_strength), so the path
-- likely starts where the caster faces and bends toward the point. Facing the point first should make it straight.
-- Returns the angle (degrees) between the facing and the point; when it's over maxAngle a short step toward the
-- point is issued (the hero turns as it starts moving) and the caller casts on a later think.
function StraightCast.FaceFirst(unit, point, maxAngle)
	local from = unit:GetLocation()
	local dir = point - from
	if dir:Length2D() < 1 then
		return 0, true
	end
	local facing = unit:GetFacing() or 0
	local want = math.deg(math.atan2(dir.y, dir.x))
	local angle = math.abs(((want - facing) + 180) % 360 - 180)
	if angle <= maxAngle then
		return angle, true
	end
	unit:Action_MoveToLocation(Fu.VectorTowards(from, point, 60))
	return angle, false
end

return StraightCast
