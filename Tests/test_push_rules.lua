-- FuncLib/systems/push_rules.lua: advantage window, the all-alive push cap, Roshan over push, respawn estimate;
-- and FuncLib/systems/kill_window.lua learning respawn times from our own deaths (#12).
local T = ...

local function rules()
	T.stub.reset({ hero = "npc_dota_hero_lich" })
	return require(GetScriptDirectory() .. "/FuncLib/systems/push_rules")
end

T.test("advantage: Aegis and dead enemies open the window, a base threat closes it", function()
	local R = rules()
	-- Game 066 21:44: Dire held the Aegis, 5 alive each.
	local desire, why = R.Advantage({ aegis = true, alliesAlive = 5, enemiesAlive = 5, dead = 0, deadLong = 0 })
	T.eq(desire, 0.8, "aegis desire")
	T.eq(why, "aegis", "aegis why")
	-- Aegis with only 3 alive: no window.
	T.eq(R.Advantage({ aegis = true, alliesAlive = 3, enemiesAlive = 5, dead = 0, deadLong = 0 }), nil, "aegis 3 alive")
	-- Three dead for 20s+: 0.9.
	desire, why = R.Advantage({ alliesAlive = 4, enemiesAlive = 2, dead = 3, deadLong = 3 })
	T.eq(desire, 0.9, "dead3 desire")
	T.eq(why, "dead3", "dead3 why")
	-- Two dead with 4-5 of ours alive: 0.8; with 3 of ours alive: no window.
	T.eq(R.Advantage({ alliesAlive = 4, enemiesAlive = 3, dead = 2, deadLong = 0 }), 0.8, "dead2 with 4")
	T.eq(R.Advantage({ alliesAlive = 3, enemiesAlive = 3, dead = 2, deadLong = 2 }), nil, "dead2 with 3")
	-- Every enemy dead (#87's wipe push).
	T.eq(select(2, R.Advantage({ alliesAlive = 2, enemiesAlive = 0, dead = 5, deadLong = 5 })), "wipe", "wipe")
	-- Aegis on top of a dead window.
	desire, why = R.Advantage({ aegis = true, alliesAlive = 5, enemiesAlive = 3, dead = 2, deadLong = 1 })
	T.eq(desire, 0.85, "dead2+aegis desire")
	T.eq(why, "dead2+aegis", "dead2+aegis why")
	-- Our base is being hit: nothing.
	T.eq(
		R.Advantage({ aegis = true, alliesAlive = 5, enemiesAlive = 0, dead = 5, deadLong = 5, baseThreat = true }),
		nil,
		"base threat"
	)
end)

T.test("five-alive cap: 0.41 for an even game, joiners when ahead or at a T1/T2", function()
	local R = rules()
	-- Game 067 33:00: Radiant mid T1 (tier 1), 5 alive each, about even.
	local cap, joiners, why =
		R.FiveAliveCap({ enemiesAlive = 5, alliesAlive = 5, nwLead = -500, levelLead = 0.2, tier = 1 })
	T.eq(cap, 0.7, "outer cap")
	T.eq(joiners, 3, "outer joiners")
	T.eq(why, "outer", "outer why")
	cap, joiners = R.FiveAliveCap({ enemiesAlive = 5, alliesAlive = 5, nwLead = 2500, levelLead = 0, tier = 2 })
	T.eq(cap, 0.75, "ahead+outer cap")
	T.eq(joiners, 4, "ahead+outer joiners")
	cap, joiners = R.FiveAliveCap({ enemiesAlive = 5, alliesAlive = 5, nwLead = 0, levelLead = 1.2, tier = 3 })
	T.eq(cap, 0.7, "ahead at the high ground")
	T.eq(joiners, 3, "ahead at the high ground joiners")
	cap, joiners, why = R.FiveAliveCap({ enemiesAlive = 5, alliesAlive = 5, nwLead = 0, levelLead = 0, tier = 3 })
	T.eq(cap, 0.41, "even high ground cap")
	T.eq(joiners, 2, "even high ground joiners")
	T.eq(why, "even", "even why")
	-- An enemy dead: the cap is off.
	T.eq(R.FiveAliveCap({ enemiesAlive = 4, alliesAlive = 5, tier = 3 }), nil, "4 alive")
end)

T.test("Roshan over push: a live call wins unless the tower is about to fall", function()
	local R = rules()
	-- Game 067 32:11: 0.99 kill push, the call now goes in at 0.96.
	local desire, yielded = R.PushUnderRosh(0.99, 0.96, 0.1, false)
	T.near(desire, 0.91, 1e-9, "push under the call")
	T.eq(yielded, true, "yielded")
	T.eq(select(2, R.PushUnderRosh(0.99, 0.96, 0.1, true)), false, "finishing a tower")
	T.eq(select(2, R.PushUnderRosh(0.99, 0.96, 3.0, false)), false, "stale Roshan desire")
	T.eq(select(2, R.PushUnderRosh(0.99, 0.3, 0.1, false)), false, "call off")
	-- A plain 0.60 call (held back on the high ground, or a timer call) does not cut a 0.99 push.
	T.eq(select(2, R.PushUnderRosh(0.99, 0.60, 0.1, false)), false, "0.60 call")
	T.eq(R.PushUnderRosh(0.4, 0.6, 0.1, false), 0.4, "push already lower")
end)

T.test("lock branch with every enemy dead: the wipe push goes at 0.9 through the lock", function()
	local R = rules()
	-- Game 067 t=1376: Dire bots in the mid lock, all five Radiant dead, `lock-capped why=cap desire=0.25 alive=4/0`
	-- and no wipe push. Now the own-HP cap starts at 30% in a wipe, and the lock raises to the window.
	T.eq(R.OwnHpCapBelow(true), 0.3, "wipe HP floor")
	T.eq(R.OwnHpCapBelow(false), 0.5, "normal HP floor")
	local wipe = R.Advantage({ alliesAlive = 4, enemiesAlive = 0, dead = 5, deadLong = 5 })
	local desire, cap, raised = R.LockDesire({
		base = 0.55,
		advantage = wipe,
		maxPush = wipe,
		alliesNear = 2,
		enemiesNear = 0,
		enemiesAlive = 0,
		tier = 3,
		nearAncient = true,
		groupHurt = true,
	})
	T.eq(desire, 0.9, "wipe desire in the lock")
	T.eq(cap, nil, "no cap: group-hurt and fewer-than-alive skipped")
	T.eq(raised, "advantage", "raised")
	-- The same bot under 30%: maxPush holds the 0.25 cap.
	desire, cap = R.LockDesire({ base = 0.55, advantage = wipe, maxPush = 0.25, alliesNear = 2, enemiesAlive = 0 })
	T.eq(desire, 0.25, "low HP still capped")
	T.eq(cap, "cap", "cap reason")
end)

T.test("lock branch: the old caps still hold without a window", function()
	local R = rules()
	-- 5 alive each, 3 bots at a T2 within 6000 of the Ancient, no window: fewer-than-alive 0.4.
	local desire, cap = R.LockDesire({
		base = 0.55,
		maxPush = 0.41,
		alliesNear = 3,
		enemiesNear = 0,
		enemiesAlive = 5,
		tier = 2,
		nearAncient = true,
	})
	T.eq(desire, 0.4, "fewer-than-alive")
	T.eq(cap, "fewer-than-alive", "reason")
	-- A joiner (ahead, T2) is past it below the high ground.
	desire, cap = R.LockDesire({
		base = 0.55,
		joinCap = 0.75,
		maxPush = 0.75,
		alliesNear = 3,
		enemiesAlive = 5,
		tier = 2,
		nearAncient = true,
	})
	T.eq(desire, 0.75, "joiner at a T2")
	T.eq(cap, nil, "joiner no cap")
	-- Alone against two, and a hurt group with enemies alive.
	T.eq(
		R.LockDesire({ base = 0.55, advantage = 0.9, maxPush = 0.9, alliesNear = 1, enemiesNear = 2 }),
		0.2,
		"alone-vs-2"
	)
	T.eq(
		R.LockDesire({ base = 0.55, maxPush = 0.65, alliesNear = 3, enemiesAlive = 2, groupHurt = true }),
		0.15,
		"group-hurt"
	)
end)

T.test("respawn estimate: nearest learned level, else the default", function()
	local R = rules()
	T.eq(R.RespawnEstimate({}, 14, 30), 30, "nothing learned")
	T.eq(R.RespawnEstimate({ [12] = 44, [20] = 70 }, nil, 30), 30, "no level")
	T.eq(R.RespawnEstimate({ [12] = 44, [20] = 70 }, 13, 30), 44, "nearest below")
	T.eq(R.RespawnEstimate({ [12] = 44, [20] = 70 }, 18, 30), 70, "nearest above")
	T.eq(R.RespawnEstimate({ [12] = 44, [14] = 52 }, 13, 30), 52, "tie takes the higher level")
	-- Only an early sample (level 3, 14s) for a level-20 enemy: not under the 30s default.
	T.eq(R.RespawnEstimate({ [3] = 14 }, 20, 30), 30, "lower sample floored")
	T.eq(R.RespawnEstimate({ [25] = 20 }, 20, 30), 20, "higher sample as is")
	local seconds, source, level = R.RespawnEstimate({ [25] = 100 }, 25, 30)
	T.eq(seconds, 100, "exact")
	T.eq(source, "learned", "source")
	T.eq(level, 25, "level used")
end)

T.test("kill window: an enemy death uses the respawn time our own death at that level showed", function()
	T.stub.reset({ hero = "npc_dota_hero_lich", time = 1800 })
	local KillWindow = require(GetScriptDirectory() .. "/FuncLib/systems/kill_window")
	KillWindow.Tick()
	-- Our slot 2 dies at level 14; GetRespawnTime() says 52.
	local ally = GetTeamMember(2)
	ally._level = 14
	ally.GetRespawnTime = function()
		return 52
	end
	ally._alive = false
	T.stub.time = 1810
	KillWindow.Tick()
	-- An enemy at level 14 dies: no API answer on enemies, so 52 from what we learned.
	local enemy = T.stub.teams[GetOpposingTeam()][1]
	enemy._level = 14
	enemy._alive = false
	T.stub.time = 1900
	KillWindow.Tick()
	local dead, deadLong, minLeft = KillWindow.DeadCounts()
	T.eq(dead, 1, "one dead")
	T.eq(deadLong, 1, "20s+ left")
	T.near(minLeft, 52, 0.01, "left")
	T.stub.time = 1940
	dead, deadLong = KillWindow.DeadCounts()
	T.eq(dead, 1, "still dead at 40s")
	T.eq(deadLong, 0, "under 20s left")
	local logged = false
	for _, line in ipairs(T.stub.printed) do
		if string.find(tostring(line), "src=learned", 1, true) then
			logged = true
		end
	end
	T.ok(logged, "death line names the learned source")
end)
