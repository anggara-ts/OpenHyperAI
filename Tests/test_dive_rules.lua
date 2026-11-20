-- FuncLib/systems/dive_rules.lua: after the early game, does a bot an enemy tower is shooting stop its chase?
local T = ...

local function rules()
	T.stub.reset({ hero = "npc_dota_hero_skywrath_mage" })
	return require(GetScriptDirectory() .. "/FuncLib/systems/dive_rules")
end

local function situation(overrides)
	local s = {
		towerOnBot = true,
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

T.test("tower chase: no decision when the tower is not on the bot or a push handles it", function()
	local R = rules()
	T.eq(R.TowerChaseDecision(situation({ towerOnBot = false })), nil, "tower on someone else")
	T.eq(R.TowerChaseDecision(situation({ pushing = true })), nil, "push mode steps out itself")
end)

T.test("tower chase: game 048 17:30, a target the team can't kill in 2 shots: leave", function()
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
