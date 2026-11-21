-- FuncLib/systems/safety_rules.lua: the base defence lets go of a hurt bot, and walks keep out of enemy towers.
local T = ...

local function rules()
	T.stub.reset({ hero = "npc_dota_hero_primal_beast" })
	return require(GetScriptDirectory() .. "/FuncLib/systems/safety_rules")
end

T.test("defend low-HP release: game 067 Primal Beast is let go at the group-up", function()
	local R = rules()
	-- 50:49 group-up: ~43% HP, Death Prophet (and Nyx) hitting him, no ally within 1200.
	T.eq(R.DefendLowHpRelease(0.43, true, 1, 0), "hit-outnumbered", "50:49 group-up")
	T.eq(R.DefendLowHpRelease(0.29, true, 2, 0), "low-hp", "50:52 defend 0.77 at 29%")
	-- 50:27: 79-89% HP in a 5v2 - the defence keeps him (retreat's own rules decide that fight).
	T.eq(R.DefendLowHpRelease(0.85, true, 5, 2), nil, "healthy bot keeps defending")
end)

T.test("defend low-HP release: no hero damage or more allies keep the bot", function()
	local R = rules()
	T.eq(R.DefendLowHpRelease(0.2, false, 2, 0), nil, "creeps only: the defence clears them")
	T.eq(R.DefendLowHpRelease(0.5, true, 1, 2), nil, "hit at 50% with two allies next to him")
	T.eq(R.DefendLowHpRelease(0.34, true, 1, 3), "low-hp", "under 35% and hit: always let go")
end)

local function dist(x, y, tx, ty)
	return math.sqrt((x - tx) ^ 2 + (y - ty) ^ 2)
end

T.test("tower detour: a walk that clears the tower or ends inside its range is left alone", function()
	local R = rules()
	T.eq(R.TowerDetour(-1500, 1200, 1500, 1200, 0, 0, 900), nil, "passes 1200 from the tower")
	T.eq(R.TowerDetour(-1500, 0, 300, 0, 0, 0, 900), nil, "the walk ends inside the range")
	T.eq(R.TowerDetour(-1500, 0, -2500, 0, 0, 0, 900), nil, "walking away from the tower")
end)

T.test("tower detour: a walk through the range goes round on the goal's side", function()
	local R = rules()
	local x, y = R.TowerDetour(-1500, 0, 1500, 100, 0, 0, 900)
	T.ok(x ~= nil, "detour")
	T.ok(dist(x, y, 0, 0) > 900, "waypoint outside the ring")
	T.ok(y > 0, "same side as the goal (above)")
	x, y = R.TowerDetour(-1500, 0, 1500, -100, 0, 0, 900)
	T.ok(y < 0, "goal below: round the bottom")
	-- Walking the waypoints converges: each step goes 150 toward the waypoint, the line clears within 40 steps.
	local bx, by = -1500, 0
	local clear = false
	for _ = 1, 40 do
		local wx, wy = R.TowerDetour(bx, by, 1500, 100, 0, 0, 900)
		if wx == nil then
			clear = true
			break
		end
		local l = dist(wx, wy, bx, by)
		bx, by = bx + (wx - bx) / l * 150, by + (wy - by) / l * 150
		T.ok(dist(bx, by, 0, 0) > 899, "never inside the ring on the way")
	end
	T.ok(clear, "the straight line to the goal clears")
end)

T.test("tower detour: game 064 Abaddon inside Radiant's mid T2 range steps out", function()
	local R = rules()
	-- T2 at -2898,-2643 (push log), Abaddon at -3024,-2271 (393 away) walking north-west.
	local x, y = R.TowerDetour(-3024, -2271, -6000, 1000, -2898, -2643, 900)
	T.ok(x ~= nil, "detour")
	T.ok(dist(x, y, -2898, -2643) > 900, "out of the range")
	T.ok(dist(x, y, -6000, 1000) < dist(-3024, -2271, -6000, 1000) + 400, "not far off the way")
end)
