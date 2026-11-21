-- #15: FuncLib/systems/banner_rules.lua (Roshan's Banner while pushing, after a won fight at a building, and defending).
local T = ...

local function rules()
	T.stub.reset({ hero = "npc_dota_hero_weaver" })
	return require(GetScriptDirectory() .. "/FuncLib/systems/banner_rules")
end

T.test("banner: pushing, or a won fight at an enemy building, with 5+ creeps", function()
	local R = rules()
	T.eq(R.Why({ pushing = true, enemyBuilding = true, pushCreeps = 5 }), "push", "push mode")
	T.eq(R.Why({ pushing = true, enemyBuilding = true, pushCreeps = 4 }), nil, "4 creeps are too few")
	T.eq(R.Why({ pushing = true, enemyBuilding = false, pushCreeps = 8 }), nil, "no building")
	T.eq(
		R.Why({ fightMode = true, enemyBuilding = true, pushCreeps = 6, alliesNear = 3, enemiesNear = 1 }),
		"fight-push",
		"attack mode after the fight"
	)
	T.eq(
		R.Why({ fightMode = true, enemyBuilding = true, pushCreeps = 6, alliesNear = 2, enemiesNear = 3 }),
		nil,
		"fight still going against more heroes"
	)
	T.eq(R.Why({ enemyBuilding = true, pushCreeps = 6 }), nil, "farming next to a tower")
end)

T.test("banner: defending our base with 4+ creeps, in any mode", function()
	local R = rules()
	-- Game 063, ~48:40: Radiant sieged Dire's bottom T3; Weaver held a Banner in defend / attack / team roam.
	T.eq(R.Why({ ownBuilding = true, defendCreeps = 4 }), "defend", "4 creeps at our T3")
	T.eq(R.Why({ ownBuilding = true, defendCreeps = 3 }), nil, "3 creeps")
	T.eq(R.Why({ ownBuilding = false, defendCreeps = 9 }), nil, "no building under attack")
	T.eq(
		R.Why({ pushing = true, enemyBuilding = true, pushCreeps = 3, ownBuilding = true, defendCreeps = 5 }),
		"defend",
		"too few to push, enough to defend"
	)
end)
