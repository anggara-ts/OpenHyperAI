-- Shared bot system: role.
local Role = {}
local Dota = require(GetScriptDirectory() .. "/ts_libs/dota/index")
local GameMode = Dota.GameMode
local GameState = Dota.GameState
local Lane = Dota.Lane
local Team = Dota.Team
local Utils = require(GetScriptDirectory() .. "/FuncLib/systems/utils")
local NumHumanBotPlayersInTeam = Utils.NumHumanBotPlayersInTeam
local HeroRolesMap = require(GetScriptDirectory() .. "/FuncLib/data/hero_roles_map")
local EnemyRoleEstimation = require(GetScriptDirectory() .. "/FuncLib/hero/enemy_role_estimation")
local GetEnemyPosition = EnemyRoleEstimation.GetEnemyPosition
Role.RoleAssignment = {
	TEAM_RADIANT = { 1, 2, 3, 4, 5, 1, 2, 3, 4, 5, 1, 2, 3, 4, 5 },
	TEAM_DIRE = {
		1,
		2,
		3,
		4,
		5,
		1,
		2,
		3,
		4,
		5,
		1,
		2,
		3,
		4,
		5,
	},
}
Role.IsCarry = function(heroName)
	return HeroRolesMap.IsCarry(heroName)
end
Role.IsDisabler = function(heroName)
	return HeroRolesMap.IsDisabler(heroName)
end
Role.IsDurable = function(heroName)
	return HeroRolesMap.IsDurable(heroName)
end
Role.HasEscape = function(heroName)
	return HeroRolesMap.HasEscape(heroName)
end
Role.IsInitiator = function(heroName)
	return HeroRolesMap.IsInitiator(heroName)
end
Role.IsJungler = function(heroName)
	return HeroRolesMap.IsJungler(heroName)
end
Role.IsNuker = function(heroName)
	return HeroRolesMap.IsNuker(heroName)
end
Role.IsSupport = function(heroName)
	return HeroRolesMap.IsSupport(heroName)
end
Role.IsPusher = function(heroName)
	return HeroRolesMap.IsPusher(heroName)
end
Role.IsRanged = function(heroName)
	return HeroRolesMap.IsRanged(heroName)
end
Role.IsHealer = function(heroName)
	return HeroRolesMap.IsHealer(heroName)
end
Role.IsMelee = function(attackRange)
	return attackRange <= 326
end
Role.CanBeOfflaner = function(heroName)
	return Role.IsInitiator(heroName) and Role.IsDurable(heroName)
end
Role.CanBeMidlaner = function(heroName)
	return HeroRolesMap.IsCarry(heroName)
end
Role.CanBeSafeLaneCarry = function(heroName)
	return HeroRolesMap.IsCarry(heroName)
end
Role.CanBeSupport = function(heroName)
	return HeroRolesMap.IsSupport(heroName)
end
Role.GetCurrentSuitableRole = function(bot, heroName)
	local assignedLane = bot:GetAssignedLane()
	if Role.CanBeSupport(heroName) and assignedLane ~= Lane.Mid then
		return "support"
	elseif Role.CanBeMidlaner(heroName) and assignedLane == Lane.Mid then
		return "midlaner"
	elseif
		Role.CanBeSafeLaneCarry(heroName)
		and (
			GetTeam() == Team.Radiant and assignedLane == Lane.Bot
			or GetTeam() == Team.Dire and assignedLane == Lane.Top
		)
	then
		return "carry"
	elseif
		Role.CanBeOfflaner(heroName)
		and (
			GetTeam() == Team.Radiant and assignedLane == Lane.Top
			or GetTeam() == Team.Dire and assignedLane == Lane.Bot
		)
	then
		return "offlaner"
	else
		return "unknown"
	end
end
Role.GetBestEffortSuitableRole = function(heroName)
	if Role.CanBeSupport(heroName) then
		return 4
	elseif Role.CanBeMidlaner(heroName) then
		return 2
	elseif Role.CanBeSafeLaneCarry(heroName) then
		return 1
	elseif Role.CanBeOfflaner(heroName) then
		return 3
	else
		return 3
	end
end
Role.invisEnemyExist = false
local checkedEnemyPicks = false
local lastInvisItemCheckTime = -90
Role.UpdateInvisEnemyStatus = function(bot)
	if Role.invisEnemyExist then
		return
	end
	if checkedEnemyPicks == false then
		local enemyPlayerIds = GetTeamPlayers(GetOpposingTeam())
		do
			local i = 0
			while i < #enemyPlayerIds do
				if HeroRolesMap.InvisHeroes[GetSelectedHeroName(enemyPlayerIds[i + 1])] == 1 then
					Role.invisEnemyExist = true
					break
				end
				i = i + 1
			end
		end
		checkedEnemyPicks = true
	elseif checkedEnemyPicks == true and DotaTime() > 10 * 60 and DotaTime() > lastInvisItemCheckTime + 3 then
		local nearbyEnemies = bot:GetNearbyHeroes(1600, true, 0)
		if #nearbyEnemies > 0 then
			do
				local i = 0
				while i < #nearbyEnemies do
					local enemyHero = nearbyEnemies[i + 1]
					if enemyHero ~= nil and enemyHero:CanBeSeen() then
						local shadowAmuletSlot = enemyHero:FindItemSlot("item_shadow_amulet")
						local glimmerCapeSlot = enemyHero:FindItemSlot("item_glimmer_cape")
						local shadowBladeSlot = enemyHero:FindItemSlot("item_invis_sword")
						local silverEdgeSlot = enemyHero:FindItemSlot("item_silver_edge")
						if
							shadowAmuletSlot >= 0
							or glimmerCapeSlot >= 0
							or shadowBladeSlot >= 0
							or silverEdgeSlot >= 0
						then
							Role.invisEnemyExist = true
							break
						end
					end
					i = i + 1
				end
			end
		end
		lastInvisItemCheckTime = DotaTime()
	end
end
Role.supportExist = nil
Role.UpdateSupportStatus = function(bot)
	if Role.supportExist then
		return true
	end
	if Role.GetPosition(bot) >= 4 then
		Role.supportExist = true
		return true
	end
	local teamPlayerIds = GetTeamPlayers(GetTeam())
	do
		local i = 0
		while i < #teamPlayerIds do
			local teamMember = GetTeamMember(i + 1)
			if teamMember ~= nil and teamMember:IsHero() and Role.GetPosition(teamMember) >= 4 then
				Role.supportExist = true
				return true
			end
			i = i + 1
		end
	end
	return false
end
Role.sayRate = false
Role.NotSayRate = function()
	return Role.sayRate == false
end
Role.sayJiDi = false
Role.NotSayJiDi = function()
	return Role.sayJiDi == false
end
Role.replyMemberID = nil
Role.GetReplyMemberID = function()
	if Role.replyMemberID ~= nil then
		return Role.replyMemberID
	end
	local teamPlayerIds = GetTeamPlayers(GetTeam())
	local playerCount = #teamPlayerIds
	local humanCount = 0
	do
		local i = 0
		while i < #teamPlayerIds do
			if not IsPlayerBot(teamPlayerIds[i + 1]) then
				humanCount = humanCount + 1
			end
			i = i + 1
		end
	end
	Role.replyMemberID = teamPlayerIds[RandomInt(humanCount + 1, playerCount)]
	return Role.replyMemberID
end
Role.memberIDIndexTable = nil
Role.IsAllyMemberID = function(playerId)
	if Role.memberIDIndexTable == nil then
		local teamPlayerIds = GetTeamPlayers(GetTeam())
		if #teamPlayerIds > 0 then
			Role.memberIDIndexTable = {}
			do
				local i = 0
				while i < #teamPlayerIds do
					Role.memberIDIndexTable[teamPlayerIds[i + 1]] = true
					i = i + 1
				end
			end
		end
	end
	return Role.memberIDIndexTable and Role.memberIDIndexTable[playerId] == true
end
Role.enemyIDIndexTable = nil
Role.IsEnemyMemberID = function(playerId)
	if Role.enemyIDIndexTable == nil then
		local enemyPlayerIds = GetTeamPlayers(GetOpposingTeam())
		if #enemyPlayerIds > 0 then
			Role.enemyIDIndexTable = {}
			do
				local i = 0
				while i < #enemyPlayerIds do
					Role.enemyIDIndexTable[enemyPlayerIds[i + 1]] = true
					i = i + 1
				end
			end
		else
			return false
		end
	end
	return Role.enemyIDIndexTable and Role.enemyIDIndexTable[playerId] == true
end
Role.sLastChatString = "-0"
Role.sLastChatTime = -90
Role.SetLastChatString = function(chatString)
	Role.sLastChatString = chatString
	Role.sLastChatTime = DotaTime()
end
Role.ShouldTpToDefend = function()
	if Role.sLastChatString == "-都来守家" and Role.sLastChatTime >= DotaTime() - 10 then
		return true
	end
	return false
end
Role.fLastGiveTangoTime = -90
Role.aegisHero = nil
Role.IsAllyHaveAegis = function()
	if Role.aegisHero ~= nil and Role.aegisHero:FindItemSlot("item_aegis") < 0 then
		Role.aegisHero = nil
	end
	return Role.aegisHero ~= nil
end
Role.lastbbtime = -90
Role.ShouldBuyBack = function()
	return DotaTime() > Role.lastbbtime + 1
end
Role.lastFarmTpTime = -90
Role.ShouldTpToFarm = function()
	return DotaTime() > Role.lastFarmTpTime + 4
end
Role.lastPowerRuneTime = 90
Role.IsPowerRuneKnown = function()
	return math.floor(Role.lastPowerRuneTime / 120) == math.floor(DotaTime() / 120)
end
Role.campCount = 18
Role.GetCampCount = function()
	return Role.campCount
end
Role.hasRefreshDone = true
Role.IsCampRefreshDone = function()
	return Role.hasRefreshDone == true
end
Role.availableCampTable = {}
Role.GetAvailableCampCount = function()
	return #Role.availableCampTable
end
Role.nStopWaitTime = RandomInt(3, 8)
Role.GetRuneActionTime = function()
	return Role.nStopWaitTime
end
Role.GetPositionForCM = function(bot)
	local position = nil
	if GetTeam() ~= bot:GetTeam() then
		position = GetEnemyPosition(bot:GetPlayerID())
		if position ~= nil then
			return position
		end
		return 3
	end
	local assignedLane = bot:GetAssignedLane()
	local heroName = bot:GetUnitName()
	if assignedLane == Lane.Mid then
		position = 2
	elseif assignedLane == Lane.Top then
		if bot:GetTeam() == Team.Radiant then
			if Role.CanBeOfflaner(heroName) then
				position = 3
			else
				position = 4
			end
		else
			if Role.CanBeSafeLaneCarry(heroName) then
				position = 1
			else
				position = 5
			end
		end
	elseif assignedLane == Lane.Bot then
		if bot:GetTeam() == Team.Radiant then
			if Role.CanBeSafeLaneCarry(heroName) then
				position = 1
			else
				position = 5
			end
		else
			if Role.CanBeOfflaner(heroName) then
				position = 3
			else
				position = 4
			end
		end
	end
	if position == nil then
		position = 1
		log(
			"[ERROR] Failed to determine role for bot %s in CM. It got assigned lane#: %s. Set it to pos: %s",
			heroName,
			assignedLane,
			position
		)
	end
	return position
end
Role.GetRoleFromId = function(bot)
	local teamPlayerIds = GetTeamPlayers(bot:GetTeam())
	local heroName = bot:GetUnitName()
	local teamKey = bot:GetTeam() == Team.Radiant and "TEAM_RADIANT" or "TEAM_DIRE"
	do
		local i = 0
		while i < #teamPlayerIds do
			if GetSelectedHeroName(teamPlayerIds[i + 1]) == heroName then
				return Role.RoleAssignment[teamKey][i + 1]
			end
			i = i + 1
		end
	end
	return nil
end
Role.HeroPositions = {}
Role.GetPosition = function(bot)
	if bot ~= nil and bot:GetTeam() ~= GetTeam() then
		local enemyPosition = GetEnemyPosition(bot:GetPlayerID())
		return enemyPosition ~= nil and enemyPosition or 3
	end
	local position = bot.assignedRole
	if position == nil and (GetGameMode() == GameMode.Cm or GetGameMode() == GameMode.ReverseCm) then
		local humanCount, botCount = NumHumanBotPlayersInTeam(bot:GetTeam())
		if humanCount == 0 then
			position = Role.GetPositionForCM(bot)
		end
	end
	local playerId = bot:GetPlayerID()
	local heroName = bot:GetUnitName()
	local assignedLane = bot:GetAssignedLane()
	if bot.lastAssignedLane ~= nil and bot.lastAssignedLane ~= assignedLane then
		position = nil
		bot.assignedRole = nil
		if playerId ~= nil then
			Role.HeroPositions[playerId] = nil
		end
	end
	bot.lastAssignedLane = assignedLane
	if (position == nil or GetGameState() == GameState.PreGame) and playerId ~= nil then
		local cachedPosition = Role.HeroPositions[playerId]
		if cachedPosition ~= nil then
			position = cachedPosition
		else
			local teamPlayerIds = GetTeamPlayers(bot:GetTeam())
			local teamKey = bot:GetTeam() == Team.Radiant and "TEAM_RADIANT" or "TEAM_DIRE"
			local heroName = bot:GetUnitName()
			if #teamPlayerIds >= 5 then
				do
					local i = 0
					while i < #teamPlayerIds do
						if GetSelectedHeroName(teamPlayerIds[i + 1]) == heroName then
							position = Role.RoleAssignment[teamKey][i + 1]
							break
						end
						i = i + 1
					end
				end
			end
			if position == nil then
				local slotIndex = bot:GetTeam() == Team.Radiant and playerId + 1 or playerId - 4
				if slotIndex >= 1 and slotIndex <= 5 then
					position = Role.RoleAssignment[teamKey][slotIndex]
				end
			end
			if position ~= nil then
				Role.HeroPositions[playerId] = position
			end
		end
	end
	bot.assignedRole = position
	if position == nil and GetGameState() ~= GameState.PreGame then
		position = Role.GetPositionForCM(bot)
		log(
			"[ERROR] Failed to match bot role for bot: %s, PlayerID: %s, fallback pos: %s",
			heroName,
			playerId,
			position
		)
		bot.assignedRole = position
	end
	if position == nil then
		position = 3
	end
	return position
end
Role.IsPvNMode = function()
	return Role.IsAllShadow()
end
Role.IsAllShadow = function()
	return false
end
return Role
