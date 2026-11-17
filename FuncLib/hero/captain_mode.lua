-- Hero-specific helper: captain mode.
local function countArgs(...)
	return select("#", ...)
end
local function tableSplice(self, ...)
	local args = { ... }
	local length = #self
	local argCount = countArgs(...)
	local start = args[1]
	local deleteCountArg = args[2]
	if start < 0 then
		start = length + start
		if start < 0 then
			start = 0
		end
	elseif start > length then
		start = length
	end
	local insertCount = argCount - 2
	if insertCount < 0 then
		insertCount = 0
	end
	local deleteCount
	if argCount == 0 then
		deleteCount = 0
	elseif argCount == 1 then
		deleteCount = length - start
	else
		deleteCount = deleteCountArg or 0
		if deleteCount < 0 then
			deleteCount = 0
		end
		if deleteCount > length - start then
			deleteCount = length - start
		end
	end
	local removed = {}
	for i = 1, deleteCount do
		local fromIndex = start + i
		if self[fromIndex] ~= nil then
			removed[i] = self[fromIndex]
		end
	end
	if insertCount < deleteCount then
		for i = start + 1, length - deleteCount do
			local fromIndex = i + deleteCount
			local toIndex = i + insertCount
			if self[fromIndex] then
				self[toIndex] = self[fromIndex]
			else
				self[toIndex] = nil
			end
		end
		for i = length - deleteCount + insertCount + 1, length do
			self[i] = nil
		end
	elseif insertCount > deleteCount then
		for i = length - deleteCount, start + 1, -1 do
			local fromIndex = i + deleteCount
			local toIndex = i + insertCount
			if self[fromIndex] then
				self[toIndex] = self[fromIndex]
			else
				self[toIndex] = nil
			end
		end
	end
	local insertIndex = start + 1
	for argIndex = 3, argCount do
		self[insertIndex] = args[argIndex]
		insertIndex = insertIndex + 1
	end
	for i = #self, length - deleteCount + insertCount + 1, -1 do
		self[i] = nil
	end
	return removed
end
local X = {}
local banHero, pickHero, isHumanPicked, isExcludedHero, randomAvailableHero, allHumansSelected, selectHeroes, collectPickedHeroes, removeFromPicked, assignLanes, extraHeroPool, pickedHeroes, heroesSelected, banCount, pickCount, excludedHeroes, laneAssignments, heroPool, humanPickedHeroes, positionAssignments
local Dota = require(GetScriptDirectory() .. "/ts_libs/dota/index")
local GameState = Dota.GameState
local HeroPickState = Dota.HeroPickState
local Lane = Dota.Lane
local Team = Dota.Team
local Role = require(GetScriptDirectory() .. "/FuncLib/systems/role")
local CanBeOfflaner = Role.CanBeOfflaner
local CanBeMidlaner = Role.CanBeMidlaner
local CanBeSupport = Role.CanBeSupport
local CanBeSafeLaneCarry = Role.CanBeSafeLaneCarry
function X.PickCaptain()
	if not X.IsHumanPlayerExist() or DotaTime() > -1 then
		if GetCMCaptain() == -1 then
			local firstBot = X.GetFirstBot()
			if firstBot ~= nil and firstBot ~= nil then
				log("CAPTAIN PID : %s", firstBot)
				SetCMCaptain(firstBot)
			end
		end
	end
end
function X.IsHumanPlayerExist()
	local teamPlayers = GetTeamPlayers(GetTeam())
	for _, playerId in ipairs(teamPlayers) do
		if not IsPlayerBot(playerId) then
			return true
		end
	end
	return false
end
function X.GetFirstBot()
	local firstBot = nil
	local teamPlayers = GetTeamPlayers(GetTeam())
	for _, playerId in ipairs(teamPlayers) do
		if IsPlayerBot(playerId) then
			firstBot = playerId
			return firstBot
		end
	end
	return firstBot
end
function banHero()
	if not IsPlayerBot(GetCMCaptain()) or not IsPlayerInHeroSelectionControl(GetCMCaptain()) then
		return
	end
	local heroName = randomAvailableHero()
	log("%s is banned", heroName)
	CMBanHero(heroName)
	banCount = banCount + 1
end
function pickHero()
	if not IsPlayerBot(GetCMCaptain()) or not IsPlayerInHeroSelectionControl(GetCMCaptain()) then
		return
	end
	local teamKey = GetTeam() == Team.Radiant and "TEAM_RADIANT" or "TEAM_DIRE"
	local heroName = randomAvailableHero()
	if pickCount == 1 then
		while not CanBeOfflaner(heroName) do
			heroName = randomAvailableHero()
		end
		X.PairsHeroNameNRole[teamKey][heroName] = "offlaner"
	elseif pickCount == 2 then
		while not CanBeSupport(heroName) do
			heroName = randomAvailableHero()
		end
		X.PairsHeroNameNRole[teamKey][heroName] = "support"
	elseif pickCount == 3 then
		while not CanBeMidlaner(heroName) do
			heroName = randomAvailableHero()
		end
		X.PairsHeroNameNRole[teamKey][heroName] = "midlaner"
	elseif pickCount == 4 then
		while not CanBeSupport(heroName) do
			heroName = randomAvailableHero()
		end
		X.PairsHeroNameNRole[teamKey][heroName] = "support"
	elseif pickCount == 5 then
		while not CanBeSafeLaneCarry(heroName) do
			heroName = randomAvailableHero()
		end
		X.PairsHeroNameNRole[teamKey][heroName] = "carry"
	end
	log("%s is picked", heroName)
	CMPickHero(heroName)
	pickCount = pickCount + 1
end
function isHumanPicked(heroName)
	for _, pickedHero in ipairs(humanPickedHeroes) do
		if heroName == pickedHero then
			return true
		end
	end
	return false
end
function isExcludedHero(heroName)
	for _, excludedHero in ipairs(excludedHeroes) do
		if heroName == excludedHero then
			return true
		end
	end
	return false
end
function randomAvailableHero()
	local heroName = heroPool[RandomInt(1, #heroPool)]
	while
		isExcludedHero(heroName)
		or IsCMPickedHero(GetTeam(), heroName)
		or IsCMPickedHero(GetOpposingTeam(), heroName)
		or IsCMBannedHero(heroName)
	do
		heroName = heroPool[RandomInt(1, #heroPool)]
	end
	return heroName
end
function allHumansSelected()
	local teamPlayers = GetTeamPlayers(GetTeam())
	for _, playerId in ipairs(teamPlayers) do
		if not IsPlayerBot(playerId) then
			local selectedName = GetSelectedHeroName(playerId)
			if selectedName == nil or selectedName == "" then
				return false
			end
		end
	end
	return true
end
function selectHeroes()
	if not heroesSelected and (allHumansSelected() or GetCMPhaseTimeRemaining() < 1) then
		local teamPlayers = GetTeamPlayers(GetTeam())
		local unselectedPlayers = {}
		collectPickedHeroes()
		for _, playerId in ipairs(teamPlayers) do
			local heroName = GetSelectedHeroName(playerId)
			if heroName ~= nil and heroName ~= "" then
				removeFromPicked(heroName)
				log("%s Removed", heroName)
			else
				unselectedPlayers[#unselectedPlayers + 1] = playerId
			end
		end
		do
			local i = 0
			while i < #unselectedPlayers do
				SelectHero(unselectedPlayers[i + 1], pickedHeroes[i + 1])
				i = i + 1
			end
		end
		heroesSelected = true
	end
end
function collectPickedHeroes()
	for _, heroName in ipairs(heroPool) do
		if IsCMPickedHero(GetTeam(), heroName) then
			pickedHeroes[#pickedHeroes + 1] = heroName
		end
	end
	for _, heroName in ipairs(extraHeroPool) do
		if IsCMPickedHero(GetTeam(), heroName) then
			pickedHeroes[#pickedHeroes + 1] = heroName
		end
	end
end
function removeFromPicked(heroName)
	do
		local i = 0
		while i < #pickedHeroes do
			if pickedHeroes[i + 1] == heroName then
				tableSplice(pickedHeroes, i, 1)
				break
			end
			i = i + 1
		end
	end
end
function assignLanes()
	local teamPlayers = GetTeamPlayers(GetTeam())
	local teamKey = GetTeam() == Team.Radiant and "TEAM_RADIANT" or "TEAM_DIRE"
	local supportAssigned = { TEAM_RADIANT = false, TEAM_DIRE = false }
	do
		local i = 0
		while i < #teamPlayers do
			local member = GetTeamMember(i + 1)
			if member ~= nil and member:IsHero() then
				local unitName = member:GetUnitName()
				local role = X.PairsHeroNameNRole[teamKey][unitName]
				if role == "support" then
					if GetTeam() == Team.Radiant then
						if not supportAssigned.TEAM_RADIANT then
							laneAssignments[teamKey][i + 1] = Lane.Bot
							supportAssigned.TEAM_RADIANT = true
							positionAssignments[teamKey][i + 1] = 5
						else
							laneAssignments[teamKey][i + 1] = Lane.Top
							positionAssignments[teamKey][i + 1] = 4
						end
					else
						if not supportAssigned.TEAM_DIRE then
							laneAssignments[teamKey][i + 1] = Lane.Top
							supportAssigned.TEAM_DIRE = true
							positionAssignments[teamKey][i + 1] = 5
						else
							laneAssignments[teamKey][i + 1] = Lane.Bot
							positionAssignments[teamKey][i + 1] = 4
						end
					end
				elseif role == "midlaner" then
					laneAssignments[teamKey][i + 1] = Lane.Mid
					positionAssignments[teamKey][i + 1] = 2
				elseif role == "offlaner" then
					if GetTeam() == Team.Radiant then
						laneAssignments[teamKey][i + 1] = Lane.Top
					else
						laneAssignments[teamKey][i + 1] = Lane.Bot
					end
					positionAssignments[teamKey][i + 1] = 3
				elseif role == "carry" then
					if GetTeam() == Team.Radiant then
						laneAssignments[teamKey][i + 1] = Lane.Bot
					else
						laneAssignments[teamKey][i + 1] = Lane.Top
					end
					positionAssignments[teamKey][i + 1] = 1
				end
			end
			i = i + 1
		end
	end
end
extraHeroPool = {}
pickedHeroes = {}
heroesSelected = false
banCount = 1
pickCount = 1
local pickDelay = 28
local minPickDelay = 15
local maxPickDelay = 20
local useFixedPickDelay = true
excludedHeroes = { "npc_dota_hero_techies" }
laneAssignments = {
	TEAM_RADIANT = { [1] = Lane.Bot, [2] = Lane.Mid, [3] = Lane.Top, [4] = Lane.Top, [5] = Lane.Bot },
	TEAM_DIRE = { [1] = Lane.Top, [2] = Lane.Mid, [3] = Lane.Bot, [4] = Lane.Bot, [5] = Lane.Top },
}
heroPool = {}
X.PairsHeroNameNRole = { TEAM_RADIANT = {}, TEAM_DIRE = {} }
humanPickedHeroes = {}
function X.CaptainModeLogic(heroList)
	heroPool = heroList
	if GetGameState() ~= GameState.HeroSelection then
		return
	end
	if not useFixedPickDelay then
		pickDelay = RandomInt(minPickDelay, maxPickDelay)
	elseif useFixedPickDelay then
		pickDelay = 25
	end
	local pickState = GetHeroPickState()
	if pickState == HeroPickState.CmCaptainPick then
		X.PickCaptain()
	elseif pickState >= HeroPickState.CmBan1 and pickState <= 20 and GetCMPhaseTimeRemaining() <= pickDelay then
		banHero()
		pickDelay = 0
	elseif
		pickState >= HeroPickState.CmSelect1
		and pickState <= HeroPickState.CmSelect10
		and GetCMPhaseTimeRemaining() <= pickDelay
	then
		pickHero()
		pickDelay = 0
	elseif pickState == HeroPickState.CmPick then
		selectHeroes()
	end
end
function X.AddToList()
	if not IsPlayerBot(GetCMCaptain()) then
		for _, heroName in ipairs(heroPool) do
			if IsCMPickedHero(GetTeam(), heroName) and not isHumanPicked(heroName) then
				humanPickedHeroes[#humanPickedHeroes + 1] = heroName
			end
		end
	end
end
-- positionAssignments is the caller's role table, set in CMLaneAssignment; assignLanes fills it in.
function X.CMLaneAssignment(roleAssignment)
	local teamKey = GetTeam() == Team.Radiant and "TEAM_RADIANT" or "TEAM_DIRE"
	positionAssignments = roleAssignment
	if IsPlayerBot(GetCMCaptain()) then
		assignLanes()
	else
	end
	return laneAssignments[teamKey]
end
return X
