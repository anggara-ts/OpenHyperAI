-- Pure rules for escape jumps (#36, Puck): plain numbers in, so Tests/test_escape_rules.lua can check them without
-- the bot API.
local EscapeRules = {}

-- Death Prophet's Spirit Siphon breaks beyond cast range + siphon_buffer (datafeed hero 43, 7.42:
-- AbilityCastRange 500, siphon_buffer 250).
EscapeRules.SIPHON_BREAK = 500 + 250

-- Unit vector for an escape jump from (bx, by): away from the enemies (each weighted by 1 / distance, so the
-- nearest counts most) and toward home (hx, hy, our fountain). Game 064, 43:23: Puck's escapes aimed at our
-- Ancient (Fu.GetEscapeLoc) and she died moving away from the fountain (4200 -> 5180 in 3.5s). enemies: a list of
-- { x, y }. homeWeight: share of the home direction (default 0.4). With no enemy, straight home.
function EscapeRules.Direction(bx, by, enemies, hx, hy, homeWeight)
	homeWeight = homeWeight or 0.4
	local awayX, awayY = 0, 0
	for _, enemy in ipairs(enemies or {}) do
		local dx, dy = bx - enemy.x, by - enemy.y
		local dist = math.sqrt(dx * dx + dy * dy)
		if dist < 1 then
			dist = 1
		end
		-- (dx, dy) / dist is the unit vector, another / dist weights it.
		awayX, awayY = awayX + dx / (dist * dist), awayY + dy / (dist * dist)
	end
	local homeX, homeY = hx - bx, hy - by
	local homeLen = math.sqrt(homeX * homeX + homeY * homeY)
	if homeLen > 1 then
		homeX, homeY = homeX / homeLen, homeY / homeLen
	else
		homeX, homeY = 0, 0
	end
	local awayLen = math.sqrt(awayX * awayX + awayY * awayY)
	if awayLen <= 0 then
		return homeX, homeY
	end
	awayX, awayY = awayX / awayLen, awayY / awayLen
	local x = awayX * (1 - homeWeight) + homeX * homeWeight
	local y = awayY * (1 - homeWeight) + homeY * homeWeight
	local len = math.sqrt(x * x + y * y)
	if len < 0.01 then
		-- Enemies straight between her and home: sideways (any perpendicular beats a step into them).
		return -awayY, awayX
	end
	return x / len, y / len
end

-- Is a point (px, py) on the escape side of (bx, by) for the direction (dx, dy)? For a Jaunt to the orb: it must
-- take her the way the escape goes (game 064, t=2600: a danger Jaunt to an orb flying away from base).
function EscapeRules.IsOnEscapeSide(bx, by, px, py, dx, dy)
	return (px - bx) * dx + (py - by) * dy > 0
end

-- Spare mana for an Illusory Orb harass in lane (#36, game 064: 3 orbs in 5 minutes of lane). After the orb, mana
-- for Waning Rift stays (Phase Shift costs no mana, datafeed hero 13), and either the pool is nearly full or the
-- regen over the orb's cooldown pays the orb back.
function EscapeRules.SpareManaOrb(mana, maxMana, regen, orbCost, riftCost, orbCooldown)
	if mana - orbCost < riftCost or maxMana <= 0 then
		return false
	end
	return mana / maxMana >= 0.9 or regen * orbCooldown >= orbCost
end

return EscapeRules
