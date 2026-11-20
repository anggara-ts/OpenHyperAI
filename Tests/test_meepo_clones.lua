-- Fu.GetNearbyHeroes leaves out clones of our own Meepo only (#132). Game 052: it also left out the enemy's real
-- Meepo and his clones, so every bot was blind to them (Shadow Fiend, rooted and hit by two Meepo bodies, counted
-- enemies=0).
local T = ...
local Stub = T.stub

local function setup()
	local bot = Stub.reset({ hero = "npc_dota_hero_lich", slot = 1 })
	local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
	local enemyTeam = bot:GetTeam() == TEAM_RADIANT and TEAM_DIRE or TEAM_RADIANT
	return bot, Fu, enemyTeam
end

local function addHero(name, team, x)
	local unit = Stub.newUnit({ name = name, team = team, hero = true })
	unit._loc = Vector(x, 0, 0)
	Stub.heroes[#Stub.heroes + 1] = unit
	return unit
end

T.test("Fu.GetNearbyHeroes keeps every enemy Meepo body", function()
	local bot, Fu, enemyTeam = setup()
	bot._loc = Vector(0, 0, 0)
	local main = addHero("npc_dota_hero_meepo", enemyTeam, 150)
	local clone = addHero("npc_dota_hero_meepo", enemyTeam, 200)
	local seen = {}
	for _, hero in ipairs(Fu.GetNearbyHeroes(bot, 800, true, BOT_MODE_NONE) or {}) do
		seen[hero] = true
	end
	T.ok(seen[main], "the enemy's real Meepo is in the list")
	T.ok(seen[clone], "an enemy Meepo clone is in the list")
	T.ok(not Fu.IsMeepoClone(main), "an enemy Meepo is not our clone")
end)

T.test("Fu.IsMeepoClone: a Meepo on our team that is not a team member is a clone", function()
	local bot, Fu = setup()
	local ownClone = Stub.newUnit({ name = "npc_dota_hero_meepo", team = bot:GetTeam(), hero = true })
	T.ok(Fu.IsMeepoClone(ownClone), "our own Meepo's clone")
	T.ok(not Fu.IsMeepoClone(GetTeamMember(2)), "a team member is not a clone")
end)
