-- Helpers that walk the team must see all five members. In the stub, team slots are 1-5 and player IDs
-- are 10-14 (Radiant), so a loop that passes a player ID to GetTeamMember (or a slot to an API that takes
-- a player ID) errors, and a loop that skips a slot changes the answer: each case puts the deciding
-- member in slot 5.
local T = ...
local Stub = T.stub

local function setup()
	local bot = Stub.reset({ hero = "npc_dota_hero_lich", slot = 1 })
	local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
	return bot, Fu, Fu.Utils, Fu.Site
end

T.test("GetNearbyAllyAverageHpPercent averages all five allies", function()
	local bot, _, Utils = setup()
	local ratios = { 0.9, 0.7, 0.5, 0.3, 0.1 }
	for slot = 1, 5 do
		local member = GetTeamMember(slot)
		member._loc = Vector(100 * slot, 0, 0)
		member._hp = member._maxHp * ratios[slot]
	end
	T.near(Utils.GetNearbyAllyAverageHpPercent(bot, 1000), 0.5, 1e-9, "average of 0.9 0.7 0.5 0.3 0.1")
	-- Only slot 5 out of range: the average of the first four.
	GetTeamMember(5)._loc = Vector(5000, 0, 0)
	T.near(Utils.GetNearbyAllyAverageHpPercent(bot, 1000), 0.6, 1e-9, "slots 1-4 only")
end)

T.test("IsTeamPushingSecondTierOrHighGround: nobody near the enemy base", function()
	local bot, _, Utils = setup()
	for slot = 1, 5 do
		GetTeamMember(slot)._loc = Vector(-5000, -5000, 0)
	end
	T.eq(Utils.IsTeamPushingSecondTierOrHighGround(bot), false, "nobody near the enemy base")
end)

T.test("IsTeamPushingSecondTierOrHighGround: slots 4 and 5 at the enemy ancient", function()
	local bot, _, Utils = setup()
	local ancient = GetAncient(GetOpposingTeam())
	for slot = 1, 5 do
		GetTeamMember(slot)._loc = Vector(-5000, -5000, 0)
	end
	GetTeamMember(4)._loc = ancient:GetLocation() - Vector(1000, 0, 0)
	GetTeamMember(5)._loc = ancient:GetLocation() - Vector(1100, 0, 0)
	T.eq(Utils.IsTeamPushingSecondTierOrHighGround(bot), true, "two allies within 3000 of the ancient")
end)

T.test("Site.IsTheClosestOne counts a farming ally in slot 5", function()
	local bot, _, _, Site = setup()
	local camp = Vector(0, 0, 0)
	bot._loc = Vector(1000, 0, 0)
	for slot = 2, 5 do
		GetTeamMember(slot)._loc = Vector(3000, 0, 0)
	end
	T.eq(Site.IsTheClosestOne(bot, camp), true, "bot is closest")
	local ally = GetTeamMember(5)
	ally._loc = Vector(200, 0, 0)
	T.eq(Site.IsTheClosestOne(bot, camp), true, "closer ally is not farming")
	ally.GetActiveMode = function()
		return BOT_MODE_FARM
	end
	T.eq(Site.IsTheClosestOne(bot, camp), false, "closer farming ally in slot 5")
end)

T.test("GetMostUltimateCDUnit pairs slots with player IDs", function()
	local _, Fu = setup()
	local silencer = Stub.newUnit({ name = "npc_dota_hero_silencer", team = TEAM_RADIANT, pid = 14 })
	Stub.teams[TEAM_RADIANT][5] = silencer
	T.eq(Fu.GetMostUltimateCDUnit(), silencer, "Silencer in slot 5 (player ID 14)")
end)

T.test("GetAlliesNearLoc returns all five", function()
	local _, Fu = setup()
	for slot = 1, 5 do
		GetTeamMember(slot)._loc = Vector(slot * 10, 0, 0)
	end
	T.eq(#Fu.GetAlliesNearLoc(Vector(0, 0, 0), 500), 5, "allies near the location")
end)
