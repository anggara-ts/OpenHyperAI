-- FuncLib/systems/dive_rules.lua: after the early game, does a bot an enemy tower is shooting stop its chase?
local T = ...

local function rules()
	T.stub.reset({ hero = "npc_dota_hero_skywrath_mage" })
	return require(GetScriptDirectory() .. "/FuncLib/systems/dive_rules")
end

local function situation(overrides)
	local s = {
		towerOnBot = true,
		outerTower = true,
		pushing = false,
		hasTarget = true,
		teamDamage = 400,
		targetHealth = 900,
		committed = false,
		botHealth = 1200,
		shotDamage = 150,
	}
	for key, value in pairs(overrides or {}) do
		s[key] = value
	end
	return s
end

T.test("tower chase: no decision when the tower is not on the bot, is a T3/T4, or a push handles it", function()
	local R = rules()
	T.eq(R.TowerChaseDecision(situation({ towerOnBot = false })), nil, "tower on someone else")
	T.eq(R.TowerChaseDecision(situation({ pushing = true })), nil, "push mode steps out itself")
	T.eq(R.TowerChaseDecision(situation({ outerTower = false })), nil, "base fight at a T3/T4")
end)

T.test("tower chase: a target the team can't kill in 2 tower shots: leave", function()
	local R = rules()
	local act, why = R.TowerChaseDecision(situation())
	T.eq(act, "leave", "act")
	T.eq(why, "not-killable", "why")
end)

T.test("tower chase: a target that dies within 2 shots keeps the chase while the bot has the HP", function()
	local R = rules()
	local act, why = R.TowerChaseDecision(situation({ teamDamage = 950 }))
	T.eq(act, "stay", "act")
	T.eq(why, "killable", "why")
	act, why = R.TowerChaseDecision(situation({ committed = true }))
	T.eq(act, "stay", "committed act")
	T.eq(why, "committed", "committed why")
end)

T.test("tower chase: too low for 3 tower shots leaves even for a kill", function()
	local R = rules()
	local act, why = R.TowerChaseDecision(situation({ teamDamage = 950, botHealth = 450 }))
	T.eq(act, "leave", "act")
	T.eq(why, "low-hp", "why")
	act = R.TowerChaseDecision(situation({ teamDamage = 950, botHealth = 451 }))
	T.eq(act, "stay", "one HP above 3 shots stays")
end)

T.test("tower chase: shot at with no hero target: leave", function()
	local R = rules()
	local act, why = R.TowerChaseDecision(situation({ hasTarget = false, teamDamage = 0, targetHealth = 0 }))
	T.eq(act, "leave", "act")
	T.eq(why, "no-target", "why")
end)

T.test("tower chase: entering after a target inside the tower's range decides before the first shot", function()
	local R = rules()
	local act, why = R.TowerChaseDecision(situation({ towerOnBot = false, entering = true }))
	T.eq(act, "leave", "not killable: stop outside")
	T.eq(why, "not-killable", "why")
	act = R.TowerChaseDecision(situation({ towerOnBot = false, entering = true, teamDamage = 950 }))
	T.eq(act, "stay", "killable: go in")
	T.eq(
		R.TowerChaseDecision(situation({ towerOnBot = false, entering = true, hasTarget = false })),
		nil,
		"no hero target: walking past a tower is no chase"
	)
	T.eq(R.TowerChaseDecision(situation({ towerOnBot = false, entering = true, pushing = true })), nil, "push mode")
end)

T.test("tower chase: the enemy heroes' damage counts in the survival check (game 063, Earth Spirit)", function()
	local R = rules()
	-- Killable target, 1200 HP, tower 150 a shot: 3 shots (450) alone are fine ...
	T.eq(R.TowerChaseDecision(situation({ teamDamage = 950, enemyDamage = 0 })), "stay", "tower only")
	-- ... but three heroes doing 800 on top are not.
	local act, why = R.TowerChaseDecision(situation({ teamDamage = 950, enemyDamage = 800 }))
	T.eq(act, "leave", "act")
	T.eq(why, "low-hp", "why")
end)

T.test("tower hold: walk out of range + 200, then on to + 350 before letting go", function()
	local R = rules()
	local run, inside = R.TowerHoldRun(850, 700, false)
	T.eq(run, true, "inside range + 200: run")
	T.eq(inside, true, "inside")
	run, inside = R.TowerHoldRun(960, 700, true)
	T.eq(run, true, "between + 200 and + 350 after being inside: keep walking")
	run, inside = R.TowerHoldRun(1060, 700, true)
	T.eq(run, false, "past + 350: free")
	T.eq(inside, false, "outside")
	run = R.TowerHoldRun(960, 700, false)
	T.eq(run, false, "between + 200 and + 350 coming from outside: free (no flip at the edge)")
end)

T.test("tower hold: a push pauses it, it resumes after (game 064, Alchemist at Dire's mid T1)", function()
	local R = rules()
	-- t=744 tower-entry-stop: hold until 753.
	local untilTime = 744 + R.HOLD_SECONDS
	T.eq(R.TowerHoldState(748, untilTime, true, false, nil), "keep", "t=748 attack mode, hold runs")
	-- t=750: one push-mode think. It used to clear the hold.
	T.eq(R.TowerHoldState(750, untilTime, true, true, nil), "pause", "t=750 push: pause")
	T.eq(R.TowerHoldState(750.5, untilTime, true, true, true), "pause", "still pushing: still paused")
	-- t=751: attack mode again, he walked back toward the tower: the hold is back (he was chase-stopped instead).
	T.eq(R.TowerHoldState(751, untilTime, true, false, true), "resume", "t=751 push over: resume")
	T.eq(R.TowerHoldState(751.5, untilTime, true, false, nil), "keep", "after the resume")
	-- The clock kept running through the pause; a dead tower ends it too.
	T.eq(R.TowerHoldState(754, untilTime, true, false, true), "expire", "9s over")
	T.eq(R.TowerHoldState(749, untilTime, false, true, nil), "expire", "tower gone")
	-- The retreat file pauses instead of clearing on a push.
	local src = T.read("mode_retreat_generic.lua")
	T.ok(string.find(src, "DiveRules.TowerHoldState(", 1, true) ~= nil, "retreat uses TowerHoldState")
end)

T.test("tower chase: entering only when the bot can't hit the target from outside the tower's range", function()
	local R = rules()
	-- Tower range 700. Melee (150) after a target 500 from the tower: has to walk in (500 + 150 = 650).
	T.eq(R.MustEnterTowerRange(850, 500, 150, 700), true, "melee")
	-- Melee after a target 600 out: hits him from 750, just outside.
	T.eq(R.MustEnterTowerRange(850, 600, 150, 700), false, "melee at the edge")
	-- Ranged (600) after the same target: hits him from 1200 out, no entry.
	T.eq(R.MustEnterTowerRange(850, 600, 600, 700), false, "ranged from outside")
	-- Already inside the range: entering whatever the attack range.
	T.eq(R.MustEnterTowerRange(650, 600, 600, 700), true, "already inside")
end)

T.test("tower approach: dead on paper before the edge leaves there (game 065, 9 of 30 stops died)", function()
	local R = rules()
	local function approach(overrides)
		local s = { outerTower = true, pushing = false, approaching = true, botHealth = 1800, shotDamage = 148 }
		for key, value in pairs(overrides or {}) do
			s[key] = value
		end
		return s
	end
	-- Zeus t=2150 at Dire's top T2: 4 enemy heroes, enemyDmg 5905. Even at full HP that is death: stop before the edge.
	local act, why = R.TowerApproachDecision(approach({ enemyDamage = 5905 }))
	T.eq(act, "leave", "Zeus t=2150: leave")
	T.eq(why, "low-hp", "Zeus t=2150: why")
	-- Tiny t=1529 at Radiant's bottom T2 (enemyDmg 1629, 3 tower shots 363) with 1028 HP: leave.
	T.eq(R.TowerApproachDecision(approach({ botHealth = 1028, shotDamage = 121, enemyDamage = 1629 })), "leave", "Tiny")
	-- Healthy against one hero: no decision here, the edge rule decides later.
	T.eq(R.TowerApproachDecision(approach({ botHealth = 1800, enemyDamage = 400 })), nil, "healthy: no decision")
	-- Not approaching, a push, or a T3/T4: no decision.
	T.eq(R.TowerApproachDecision(approach({ approaching = false, enemyDamage = 5905 })), nil, "not approaching")
	T.eq(R.TowerApproachDecision(approach({ pushing = true, enemyDamage = 5905 })), nil, "push")
	T.eq(R.TowerApproachDecision(approach({ outerTower = false, enemyDamage = 5905 })), nil, "T3")
	-- After such a stop the hold zone is range + 600: at 1200 from a 700 tower the bot still walks out.
	T.eq(R.TowerHoldRun(1200, 700, true, R.APPROACH_MARGIN), true, "approach hold: 1200 still inside")
	T.eq(R.TowerHoldRun(1500, 700, true, R.APPROACH_MARGIN), false, "approach hold: 1500 out")
	T.eq(R.TowerHoldRun(1200, 700, true), false, "edge hold (default margin): 1200 out")
end)

T.test("tower hold: a team siege of the hold tower ends a no-target hold (game 065, Dark Willow)", function()
	local R = rules()
	local untilTime = 941 + R.HOLD_SECONDS
	-- t=944: Dark Willow pushes top, the hold tower is Radiant's top T1, 4 allies at it, the stop was no-target.
	T.eq(R.TowerHoldState(944, untilTime, true, true, nil, true, 4, "no-target"), "siege", "Dark Willow t=944")
	-- Game 064, Alchemist: the same siege but the stop was a chase (not-killable): still a pause, as before.
	T.eq(R.TowerHoldState(750, 744 + R.HOLD_SECONDS, true, true, nil, true, 4, "not-killable"), "pause", "Alchemist")
	-- A low-HP stop keeps the pause too (Nyx at the same siege, 43-50% HP).
	T.eq(R.TowerHoldState(944, untilTime, true, true, nil, true, 4, "low-hp"), "pause", "Nyx low-hp")
	-- Alone or one ally: no siege. Another lane's tower: no siege.
	T.eq(R.TowerHoldState(944, untilTime, true, true, nil, true, 1, "no-target"), "pause", "one ally")
	T.eq(R.TowerHoldState(944, untilTime, true, true, nil, false, 4, "no-target"), "pause", "other lane")
	-- Not pushing: the hold runs.
	T.eq(R.TowerHoldState(945, untilTime, true, false, nil, true, 4, "no-target"), "keep", "not pushing")
end)

T.test("tower hold: the retreat file checks a live hold ahead of the early NONE returns", function()
	local src = T.read("mode_retreat_generic.lua")
	local earlyAt = string.find(src, "return RetreatTag(250, BOT_DESIRE_OVERRIDE * 1.1)", 1, true)
	local noneAt = string.find(src, "return RetreatTag(272, BOT_MODE_DESIRE_NONE)", 1, true)
	local pushAt = string.find(src, "return RetreatTag(254, BOT_MODE_DESIRE_NONE)", 1, true)
	T.ok(earlyAt ~= nil and noneAt ~= nil and pushAt ~= nil, "tags found")
	T.ok(earlyAt < pushAt and earlyAt < noneAt, "hold check before tags 254 and 272")
end)
