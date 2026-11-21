-- Shared bot system: pure safety rules (no bot API calls), so they can be tested with real numbers (#12).
local SafetyRules = {}

-- Should the base defence let go of a hurt bot that enemy heroes are hitting (FuncLib/systems/defend.lua,
-- Defend.GetDefendDesireHelper)? Game 067, 50:47-50:53: Primal Beast at his base was hit by Death Prophet and Nyx
-- (55% at 50:47, 43% at 50:49), the siege group-up held him at 50:49 (`group-up lane=bot siege=4 fountainDist=723`)
-- and defend_tower_bot/0.77 beat retreat at 29% (50:52); he died at 50:53, 732 from the fountain. The group-up only
-- skipped bots under 30%, and the base floors below it had no HP check at all.
--   hp           the bot's HP ratio
--   heroHit      an enemy hero damaged the bot in the last 2s
--   enemiesNear  enemy heroes within 1200
--   alliesNear   allied heroes within 1200, the bot not counted
-- Returns the reason ("low-hp", "hit-outnumbered") or nil (keep defending).
function SafetyRules.DefendLowHpRelease(hp, heroHit, enemiesNear, alliesNear)
	if not heroHit then
		return nil
	end
	if hp < 0.35 then
		return "low-hp"
	end
	if hp < 0.6 and enemiesNear >= 1 and enemiesNear >= alliesNear then
		return "hit-outnumbered"
	end
	return nil
end

local function Rotate(x, y, angle)
	local c, s = math.cos(angle), math.sin(angle)
	return x * c - y * s, x * s + y * c
end

-- A waypoint that keeps a straight walk from B to G out of a tower's range (the circle of radius `ring` around T),
-- or nil when the walk stays out of it. Game 064, 0:32: laning mode walked Dire's Abaddon (level 1, 52% HP) to 393
-- from Radiant's mid T2; he died 3.5s later. The engine's own path ignores towers.
--   - G inside the ring (the walk is meant to end there): nil, the tower rules decide that.
--   - B inside the ring: out of it first, turned 22.5 degrees toward the side G is on (a bigger turn circles inside).
--   - B outside: if the segment B-G clips the ring, walk along the tangent from B to the ring (+50) on G's side and
--     300 past the tangent point, so each think makes progress around the tower until the straight line is clear.
function SafetyRules.TowerDetour(bx, by, gx, gy, tx, ty, ring)
	local ux, uy = bx - tx, by - ty
	local d = math.sqrt(ux * ux + uy * uy)
	local gdx, gdy = gx - tx, gy - ty
	if gdx * gdx + gdy * gdy <= ring * ring then
		return nil
	end
	-- Which way round: the side of the line T-B that G is on (counter-clockwise when G is on the left).
	local cross = ux * gdy - uy * gdx
	local side = cross < 0 and -1 or 1
	if d < 1 then
		-- On the tower itself: out on the side away from G.
		local gl = math.sqrt(gdx * gdx + gdy * gdy)
		ux, uy = -gdx / gl, -gdy / gl
	else
		ux, uy = ux / d, uy / d
	end
	if d <= ring then
		local ex, ey = Rotate(ux, uy, side * math.pi / 8)
		return tx + ex * (ring + 250), ty + ey * (ring + 250)
	end
	-- Closest point of the segment B-G to T.
	local sx, sy = gx - bx, gy - by
	local len2 = sx * sx + sy * sy
	local k = len2 > 0 and math.max(0, math.min(1, ((tx - bx) * sx + (ty - by) * sy) / len2)) or 0
	local cx, cy = bx + sx * k - tx, by + sy * k - ty
	if cx * cx + cy * cy >= ring * ring then
		return nil
	end
	-- Tangent point on a circle 50 wider than the ring, then 300 along the tangent there (the walk direction).
	local outer = ring + 50
	local alpha = d > outer and math.acos(outer / d) or 0
	local qx, qy = Rotate(ux, uy, side * alpha)
	local dx, dy = Rotate(qx, qy, side * math.pi / 2)
	return tx + qx * outer + dx * 300, ty + qy * outer + dy * 300
end

return SafetyRules
