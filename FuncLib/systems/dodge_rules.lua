-- Shared bot system: pure projectile-dodge rules (no bot API calls), so they can be tested with real numbers (#134).
-- Used by the dodge items in ability_item_usage_generic.lua (Blink, Eul's / Wind Waker, BKB, Lotus Orb, Linken's)
-- through the projectile readers in FuncLib/general_utils/projectile.lua.
local DodgeRules = {}

-- Seconds from "the item think decides" to "the item works": one server tick for the order (~0.033s,
-- THINK_SAMPLE_FRAME in ability_item_usage_generic.lua) plus a margin for the projectile moving while the order
-- goes out. An estimate, not game data; the [OHA-DODGE] result lines (hit=) show whether it is enough.
DodgeRules.LATENCY = 0.1
-- The item think does not run every tick: ShouldThrottleHeavyThink (ability_item_usage_generic.lua) skips up to
-- 3 ticks * Customize ThinkLess while the bot is locked on a safe target, and an earlier item in the same think can
-- take the frame. A dodge fires when the projectile lands within this much time after the reaction time, so one
-- skipped think does not turn "too early" into "too late".
DodgeRules.SLACK = 0.35
-- A tracking projectile seen for the first time has no measured speed; the spell's speed value is used when it
-- has one, this otherwise (the tti= in the log then carries src=default).
DodgeRules.DEFAULT_SPEED = 1000
-- A unit's own radius for the will-hit test when unit:GetBoundingRadius() gives none (an estimate, not game data).
DodgeRules.HERO_HULL = 30

-- Dangerous linear skillshots: a dodge item is worth spending on them. Values from Valve's datafeed
-- (https://www.dota2.com/datafeed/herodata?language=english&hero_id=N, read 2026-11-21):
--   radius  the projectile's width value (the API's own radius field is used first when it has one)
--   speed   its speed value (the API's velocity, or the measured speed, is used first)
--   range   how far it flies from the caster (max level); a caster farther than this cannot hit
--   bkb     BKB blocks it (datafeed immunity 4 = does not pierce debuff immunity; 3 = pierces)
--   nuke    damage only (no disable): dodged only when the bot is hurt (NukeHpRatio)
-- Seen as linear projectiles in OHA match logs ([OHA-EVASIVE] linear=): mirana_arrow, lion_impale,
-- hoodwink_sharpshooter. The others are expected to be linear projectiles from their datafeed behaviour, not yet
-- seen in a log: the [OHA-DODGE] kind=linear line shows them when they are.
DodgeRules.LINEAR = {
	-- hero_id 9: arrow_speed 900, arrow_width 115, arrow_range 3000, stun up to 2.3/3.2/4.1/5s, immunity 4.
	mirana_arrow = { radius = 115, speed = 900, range = 3000, bkb = true, why = "stun" },
	-- hero_id 14: hook_speed 1600, hook_width 100, cast range 1300, 150-360 damage and a pull, immunity 3.
	pudge_meat_hook = { radius = 100, speed = 1600, range = 1300, bkb = false, why = "hook" },
	-- hero_id 123: arrow_speed 2200, arrow_width 125, arrow_range 3000, max_damage 550/875/1200, immunity 4.
	hoodwink_sharpshooter = { radius = 125, speed = 2200, range = 3000, bkb = true, why = "nuke", nuke = true },
	-- hero_id 26: speed 2800, width 140, cast range 650 + length_buffer 275, stun 1.3-2.2s, immunity 4.
	lion_impale = { radius = 140, speed = 2800, range = 925, bkb = true, why = "stun" },
	-- hero_id 88: speed 1600, width 140, length 750, stun 1.25-2s, immunity 4.
	nyx_assassin_impale = { radius = 140, speed = 1600, range = 750, bkb = true, why = "stun" },
	-- hero_id 51: speed 4000/5000/6000, latch_radius 125, range 2000/2500/3000, stun 1.2-1.6s, immunity 3.
	rattletrap_hookshot = { radius = 125, speed = 4000, range = 3000, bkb = false, why = "stun" },
	-- hero_id 129: spear_speed 1400, spear_width 125, spear_range 900-1200, stun 1.3-2.2s when pinned, immunity 4.
	mars_spear = { radius = 125, speed = 1400, range = 1200, bkb = true, why = "stun" },
	-- hero_id 74: travel_speed 1000, area_of_effect 200, travel_distance up to 3900, lift 1.2-2.8s, immunity 4.
	invoker_tornado = { radius = 200, speed = 1000, range = 3900, bkb = true, why = "disable" },
	-- hero_id 39: speed 900, starting_aoe 100 to final_aoe 450 over distance 900, 325-585 damage, immunity 3.
	-- The width grows along the way: the middle (275) is used when the API gives no radius.
	queenofpain_sonic_wave = { radius = 275, speed = 900, range = 900, bkb = false, why = "nuke", nuke = true },
}
-- Below this HP ratio a damage-only skillshot is worth a dodge item.
DodgeRules.NukeHpRatio = 0.6

-- Can this dodge tool answer this linear spell? tool: "blink" | "cyclone" | "bkb".
-- Blink steps out of the line; Eul's / Wind Waker makes the bot invulnerable (the projectile passes); BKB only
-- for spells that do not pierce debuff immunity. Lotus Orb and Linken's work on targeted spells only (Valve
-- item text: "re-casts most targeted spells", "Blocks most targeted spells"), so they never answer a skillshot.
function DodgeRules.ToolAnswers(spec, tool)
	if spec == nil then
		return false
	end
	if tool == "bkb" then
		return spec.bkb == true
	end
	return tool == "blink" or tool == "cyclone"
end

-- Is this linear spell worth a dodge item for a bot at this HP ratio?
function DodgeRules.WorthDodging(spec, hpRatio)
	if spec == nil then
		return false
	end
	if spec.nuke then
		return (hpRatio or 1) < DodgeRules.NukeHpRatio
	end
	return true
end

-- Seconds until a projectile `distance` away at `speed` arrives; nil without a speed.
function DodgeRules.TimeToImpact(distance, speed)
	if speed == nil or speed <= 0 or distance == nil then
		return nil
	end
	return math.max(0, distance) / speed
end

-- The time a dodge tool needs from the decision: its cast point plus the order latency.
function DodgeRules.ReactTime(castPoint)
	return math.max(0, castPoint or 0) + DodgeRules.LATENCY
end

-- When to dodge a projectile `tti` seconds away with a tool of this cast point:
--   "now"   it lands within the reaction time plus SLACK: dodge in this think
--   "wait"  it is still far: dodging now would end the cyclone / waste the BKB time / blink too early
--   "late"  it lands before the tool can work: don't spend the item
function DodgeRules.Window(tti, castPoint)
	if tti == nil then
		return "wait"
	end
	local react = DodgeRules.ReactTime(castPoint)
	if tti < react then
		return "late"
	end
	if tti <= react + DodgeRules.SLACK then
		return "now"
	end
	return "wait"
end

-- Will a linear projectile at (px, py) moving (vx, vy) units per second hit a unit at (bx, by)?
-- radius: the projectile's half-width; hull: the unit's. Returns hit, tti, miss:
--   hit   true when the line passes within radius + hull of the unit and the projectile has not passed it yet
--   tti   seconds until the projectile's edge reaches the unit (nil when it moves away or does not move)
--   miss  the closest the projectile's centre line passes to the unit
function DodgeRules.LinearImpact(px, py, vx, vy, bx, by, radius, hull)
	local speed2 = vx * vx + vy * vy
	if speed2 < 1 then
		return false, nil, nil
	end
	local dx, dy = bx - px, by - py
	local along = (dx * vx + dy * vy) / speed2 -- seconds until the closest approach
	local cx, cy = px + vx * along - bx, py + vy * along - by
	local miss = math.sqrt(cx * cx + cy * cy)
	local reach = (radius or 0) + (hull or 0)
	if along < 0 then
		-- Behind the projectile: only a hit when it already overlaps the unit.
		local overlap = math.sqrt(dx * dx + dy * dy) <= reach
		return overlap, overlap and 0 or nil, miss
	end
	if miss > reach then
		return false, along, miss
	end
	local inside = math.sqrt(math.max(0, reach * reach - miss * miss)) / math.sqrt(speed2)
	return true, math.max(0, along - inside), miss
end

-- Where to Blink to leave a linear projectile's path: `dist` to the side of its line (perpendicular to (vx, vy)),
-- on the side of (hx, hy) (the bot's base), plus the part of the way home that runs along the line (it does not
-- bring the bot back into the path), capped at `along`. Returns x, y.
function DodgeRules.SideStep(vx, vy, bx, by, dist, hx, hy, along)
	local len = math.sqrt(vx * vx + vy * vy)
	if len < 1 then
		return bx, by
	end
	local ux, uy = vx / len, vy / len
	local nx, ny = -uy, ux
	local tx, ty = hx - bx, hy - by
	local side = (tx * nx + ty * ny) >= 0 and 1 or -1
	local home = tx * ux + ty * uy
	local cap = along or 0
	home = math.max(-cap, math.min(cap, home))
	return bx + nx * side * dist + ux * home, by + ny * side * dist + uy * home
end

-- Speed from two samples of a distance (closing speed for a tracking projectile) or nil when they can't tell.
function DodgeRules.ClosingSpeed(prevDistance, prevTime, distance, time)
	if prevDistance == nil or prevTime == nil then
		return nil
	end
	local dt = time - prevTime
	if dt < 0.02 or dt > 0.5 then
		return nil
	end
	local speed = (prevDistance - distance) / dt
	if speed <= 50 then
		return nil
	end
	return speed
end

return DodgeRules
