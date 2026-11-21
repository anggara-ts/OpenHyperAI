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
