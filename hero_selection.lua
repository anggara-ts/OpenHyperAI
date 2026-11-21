-- Draft logic: which heroes bots pick or ban, lane slots, and chat commands such as !pos and !pick.
require(GetScriptDirectory() .. "/FuncLib/systems/global_overrides")
local HeroSelection = {}
local pickState = {
	initialized = false,
	NextPickAt = { [1] = math.huge, [2] = math.huge, [3] = math.huge, [4] = math.huge, [5] = math.huge },
}
local banList = {}
local slotHeroes = {}
local positionHeroPools = {}
local laneAssignments = {}
local skipHumanWait = false
local MatchupsData = require(GetScriptDirectory() .. "/FuncLib/data/matchups_data")
local Role = require(GetScriptDirectory() .. "/FuncLib/systems/role")
local Utils = require(GetScriptDirectory() .. "/FuncLib/systems/utils")
local TeamNames = require(GetScriptDirectory() .. "/FuncLib/data/team_names")
local CaptainMode = require(GetScriptDirectory() .. "/FuncLib/hero/captain_mode")
local Localization = require(GetScriptDirectory() .. "/FuncLib/systems/localization")
local heroPosWeights = require(GetScriptDirectory() .. "/FuncLib/data/hero_pos_weights")
local HeroDisplayNames = require(GetScriptDirectory() .. "/FuncLib/data/hero_display_names")
local CustomLoader = require(GetScriptDirectory() .. "/FuncLib/systems/custom_loader")
local MatchTrace = require(GetScriptDirectory() .. "/FuncLib/systems/match_trace")
heroPosWeights = heroPosWeights.GetHeroPositions()
if GAMEMODE_TURBO == nil then
	GAMEMODE_TURBO = 23
end
local maxWeightRoll = 50
local maxPoolSize = 35
local defaultWeakHeroCap = 1
local defaultWeakPenalty = { type = "exp", base = 0.6 }
local allHeroNames = {}
local radiantLanesSet = false
local direLanesSet = false
local direLaneSlot = {}
local poolCountByPos = {}
local weakHeroPickCount = { [TEAM_RADIANT] = 0, [TEAM_DIRE] = 0 }
local weakHeroes = {
	"npc_dota_hero_chen",
	"npc_dota_hero_ancient_apparition",
	"npc_dota_hero_tinker",
	"npc_dota_hero_pangolier",
	"npc_dota_hero_tusk",
	"npc_dota_hero_morphling",
	"npc_dota_hero_visage",
	"npc_dota_hero_void_spirit",
	"npc_dota_hero_ember_spirit",
	"npc_dota_hero_rubick",
	"npc_dota_hero_brewmaster",
	"npc_dota_hero_puck",
	"npc_dota_hero_marci",
	"npc_dota_hero_lone_druid",
	"npc_dota_hero_primal_beast",
	"npc_dota_hero_dark_willow",
	"npc_dota_hero_hoodwink",
	"npc_dota_hero_wisp",
}
if CustomLoader and not CustomLoader.Enable then
	CustomLoader = nil
end
local ownTeamKey = GetTeam() == TEAM_RADIANT and "TEAM_RADIANT" or "TEAM_DIRE"
local function getKeys(source)
	local keys = {}
	for key, _ in pairs(source) do
		table.insert(keys, key)
	end
	return keys
end
local function fitsCorePool(heroName, pos, durableQuota)
	return poolCountByPos[pos] <= durableQuota and Role.IsDurable(heroName)
		or (Role.IsDisabler(heroName) or Role.IsNuker(heroName))
end
local function fitsOfflanePool(heroName, pos, durableQuota)
	return poolCountByPos[pos] <= durableQuota and Role.IsDurable(heroName)
		or (Role.IsInitiator(heroName) or Role.IsDisabler(heroName) and Role.IsDurable(heroName))
end
local function fitsSoftSupportPool(heroName, pos, durableQuota)
	return poolCountByPos[pos] <= durableQuota and Role.IsDurable(heroName)
		or (Role.IsDisabler(heroName) or Role.IsHealer(heroName) or Role.IsInitiator(heroName))
end
local function buildPositionPool(weightsByHero, pos)
	local candidates = {}
	for name, weights in pairs(weightsByHero) do
		local weight = weights[pos]
		if weight > RandomInt(5, maxWeightRoll) then
			if not Utils.HasValue(weakHeroes, name) or RandomInt(1, 10) > 7 then
				table.insert(candidates, { name = name, weight = weight })
			end
		end
	end
	table.sort(candidates, function(candidateA, candidateB)
		return candidateA.weight > candidateB.weight
	end)
	local pool = {}
	for _, candidate in ipairs(candidates) do
		local heroName = candidate.name
		if poolCountByPos[pos] == nil then
			poolCountByPos[pos] = 0
		end
		if
			pos == 1 and fitsCorePool(heroName, pos, 6)
			or pos == 2 and fitsCorePool(heroName, pos, 6)
			or pos == 3 and (not Role.IsRanged(heroName) or candidate.weight > 50) and fitsOfflanePool(heroName, pos, 6)
			or pos == 4 and Role.IsSupport(heroName) and fitsSoftSupportPool(heroName, pos, 4)
			or pos == 5
				and Role.IsSupport(heroName)
				and (Role.IsRanged(heroName) or candidate.weight >= 60)
				and (Role.IsDisabler(heroName) or Role.IsHealer(heroName) or Role.IsInitiator(heroName))
		then
			table.insert(pool, heroName)
			poolCountByPos[pos] = poolCountByPos[pos] + 1
			if #pool >= maxPoolSize then
				return pool
			end
		end
	end
	if #pool < 6 then
		pool = Utils.CombineTablesUnique(pool, buildPositionPool(weightsByHero, pos))
	end
	return pool
end
allHeroNames = getKeys(heroPosWeights)
positionHeroPools = {
	[1] = buildPositionPool(heroPosWeights, 1),
	[2] = buildPositionPool(heroPosWeights, 2),
	[3] = buildPositionPool(heroPosWeights, 3),
	[4] = buildPositionPool(heroPosWeights, 4),
	[5] = buildPositionPool(heroPosWeights, 5),
}
slotHeroes = {
	[1] = positionHeroPools[1][RandomInt(1, #positionHeroPools[1])],
	[2] = positionHeroPools[2][RandomInt(1, #positionHeroPools[2])],
	[3] = positionHeroPools[3][RandomInt(1, #positionHeroPools[3])],
	[4] = positionHeroPools[4][RandomInt(1, #positionHeroPools[4])],
	[5] = positionHeroPools[5][RandomInt(1, #positionHeroPools[5])],
}
local radiantDefaultLanes = { [1] = LANE_BOT, [2] = LANE_MID, [3] = LANE_TOP, [4] = LANE_TOP, [5] = LANE_BOT }
local direDefaultLanes = { [1] = LANE_TOP, [2] = LANE_MID, [3] = LANE_BOT, [4] = LANE_BOT, [5] = LANE_TOP }
laneAssignments = { TEAM_RADIANT = Utils.Deepcopy(radiantDefaultLanes), TEAM_DIRE = Utils.Deepcopy(direDefaultLanes) }
local allMidLanes = { [1] = LANE_MID, [2] = LANE_MID, [3] = LANE_MID, [4] = LANE_MID, [5] = LANE_MID }
local oneVsOneLanes = { [1] = LANE_MID, [2] = LANE_TOP, [3] = LANE_TOP, [4] = LANE_TOP, [5] = LANE_TOP }
-- Resolve which Customize pick list applies to a team.
-- Debug_Ally/Enemy override Radiant/Dire when that debug list has real hero names.
local function getDebugHumanTeam()
	if Utils.IsHumanPlayerInTeam(TEAM_RADIANT) then
		return TEAM_RADIANT
	end
	if Utils.IsHumanPlayerInTeam(TEAM_DIRE) then
		return TEAM_DIRE
	end
	return TEAM_RADIANT
end
local function hasForcedHeroNames(list)
	if type(list) ~= "table" then
		return false
	end
	for i = 1, #list do
		local heroName = Utils.TrimString(list[i] or "")
		if heroName ~= "" and heroName ~= "Random" then
			return true
		end
	end
	return false
end
local function getForcedPickList(team)
	if not CustomLoader then
		return nil
	end
	local allyList = CustomLoader.Debug_Ally_Heros
	local enemyList = CustomLoader.Debug_Enemy_Heros
	local useAlly = hasForcedHeroNames(allyList)
	local useEnemy = hasForcedHeroNames(enemyList)
	if useAlly or useEnemy then
		local humanTeam = getDebugHumanTeam()
		if team == humanTeam then
			return useAlly and allyList or nil
		end
		return useEnemy and enemyList or nil
	end
	if team == TEAM_RADIANT and CustomLoader.Radiant_Heros then
		return CustomLoader.Radiant_Heros
	end
	if team == TEAM_DIRE and CustomLoader.Dire_Heros then
		return CustomLoader.Dire_Heros
	end
	return nil
end
-- forcedSlot[slot] marks a slot whose hero comes from a pick list, not from the random pool.
-- Checked by slot: a "Random" slot whose roll matches a listed hero is still random.
local forcedSlot = {}
local function applyForcedPicks(list)
	if type(list) ~= "table" then
		return false
	end
	local applied = false
	for slot = 1, math.min(5, #list) do
		local heroName = Utils.TrimString(list[slot] or "")
		if heroName ~= "" and heroName ~= "Random" and Utils.HasValue(allHeroNames, heroName) then
			slotHeroes[slot] = heroName
			forcedSlot[slot] = true
			applied = true
		end
	end
	return applied
end
local forcedPickList = nil
local hasDebugForcedPicks = false
if CustomLoader then
	forcedPickList = getForcedPickList(GetTeam())
	hasDebugForcedPicks = applyForcedPicks(forcedPickList)
		and (hasForcedHeroNames(CustomLoader.Debug_Ally_Heros) or hasForcedHeroNames(CustomLoader.Debug_Enemy_Heros))
end
function HeroSelection.IsInCustomizedPicks(heroName)
	if not CustomLoader then
		return false
	end
	local pickList = forcedPickList or getForcedPickList(GetTeam())
	if type(pickList) ~= "table" then
		return false
	end
	return Utils.HasValue(pickList, heroName)
end
function HeroSelection.ShuffleArray(array)
	if type(array) ~= "table" then
		error("Expected a table, got " .. type(array))
	end
	local count = #array
	for i = count, 2, -1 do
		local swapIndex = RandomInt(1, i)
		array[i], array[swapIndex] = array[swapIndex], array[i]
	end
	return array
end
function HeroSelection.ShufflePickOrder(teamPlayers)
	local order = HeroSelection.ShuffleArray({ 1, 2, 3, 4, 5 })
	for slot = 1, #order do
		local otherSlot = order[slot]
		if
			teamPlayers[slot]
			and teamPlayers[slot] >= 0
			and IsPlayerBot(teamPlayers[slot])
			and IsPlayerBot(teamPlayers[otherSlot])
		then
			slotHeroes[slot], slotHeroes[otherSlot] = slotHeroes[otherSlot], slotHeroes[slot]
			forcedSlot[slot], forcedSlot[otherSlot] = forcedSlot[otherSlot], forcedSlot[slot]
			positionHeroPools[slot], positionHeroPools[otherSlot] =
				positionHeroPools[otherSlot], positionHeroPools[slot]
			laneAssignments["TEAM_RADIANT"][slot], laneAssignments["TEAM_RADIANT"][otherSlot] =
				laneAssignments["TEAM_RADIANT"][otherSlot], laneAssignments["TEAM_RADIANT"][slot]
			laneAssignments["TEAM_DIRE"][slot], laneAssignments["TEAM_DIRE"][otherSlot] =
				laneAssignments["TEAM_DIRE"][otherSlot], laneAssignments["TEAM_DIRE"][slot]
			Role.RoleAssignment["TEAM_RADIANT"][slot], Role.RoleAssignment["TEAM_RADIANT"][otherSlot] =
				Role.RoleAssignment["TEAM_RADIANT"][otherSlot], Role.RoleAssignment["TEAM_RADIANT"][slot]
			Role.RoleAssignment["TEAM_DIRE"][slot], Role.RoleAssignment["TEAM_DIRE"][otherSlot] =
				Role.RoleAssignment["TEAM_DIRE"][otherSlot], Role.RoleAssignment["TEAM_DIRE"][slot]
		end
	end
end
if CustomLoader and CustomLoader.Ban then
	banList = CustomLoader.Ban
end
function HeroSelection.SetChatHeroBan(heroName)
	banList[#banList + 1] = string.lower(heroName)
end
function HeroSelection.IsBannedHero(heroName)
	if not heroName then
		return true
	end
	if (GetGameMode() == GAMEMODE_CM or GetGameMode() == GAMEMODE_REVERSE_CM) and IsCMBannedHero(heroName) then
		return true
	end
	local strictMatch = true
	if CustomLoader and CustomLoader.Strict_Ban_Match ~= nil then
		strictMatch = CustomLoader.Strict_Ban_Match
	end
	for i = 1, #banList do
		local bannedName = banList[i]
		if bannedName ~= nil then
			bannedName = Utils.TrimString(string.lower(bannedName))
			if string.lower(heroName) == bannedName then
				return true
			end
			if not strictMatch then
				if #bannedName >= 6 and string.find(string.lower(heroName), bannedName, 1, true) then
					return true
				end
			end
		end
	end
	return false
end
local function getWeakHeroCap(team)
	if CustomLoader and CustomLoader.Weak_Hero_Cap ~= nil then
		return tonumber(CustomLoader.Weak_Hero_Cap) or defaultWeakHeroCap
	end
	return defaultWeakHeroCap
end
local function getWeakHeroPenalty(team)
	local penaltyConfig = CustomLoader and CustomLoader.Weak_Penalty or defaultWeakPenalty
	local weakCount = weakHeroPickCount[team] or 0
	local cap = math.max(1, getWeakHeroCap(team))
	local capFraction = math.min(1.0, weakCount / cap)
	if penaltyConfig.type == "linear" then
		local slope = penaltyConfig.k ~= nil and tonumber(penaltyConfig.k) or 0.25
		local multiplier = 1.0 - slope * capFraction
		if multiplier < 0 then
			multiplier = 0
		end
		return multiplier
	elseif penaltyConfig.type == "quad" then
		local strength = penaltyConfig.k ~= nil and tonumber(penaltyConfig.k) or 1.0
		local multiplier = (1.0 - capFraction) ^ 2
		return multiplier * strength + 1.0 - strength
	elseif penaltyConfig.type == "exp" then
		local base = penaltyConfig.base ~= nil and tonumber(penaltyConfig.base) or 0.6
		if base < 0.05 then
			base = 0.05
		end
		if base > 0.99 then
			base = 0.99
		end
		return base ^ weakCount
	end
	return defaultWeakPenalty.base ^ weakCount
end
local function isHeroPicked(heroName)
	for playerId = 0, 20 do
		if IsTeamPlayer(playerId) and GetSelectedHeroName(playerId) == heroName then
			return true
		end
	end
	return false
end
local function isWeakHeroCapReached(team, heroName)
	if not Utils.HasValue(weakHeroes, heroName) then
		return false
	end
	return weakHeroPickCount[team] >= getWeakHeroCap(team)
end
function HeroSelection.CanPickHero(team, heroName)
	if not heroName then
		return false
	end
	if HeroSelection.IsBannedHero(heroName) then
		return false
	end
	if isWeakHeroCapReached(team, heroName) then
		return false
	end
	if CustomLoader and CustomLoader.Allow_Repeated_Heroes then
		return true
	end
	return not isHeroPicked(heroName)
end
-- A hero named in either team's pick list is kept for that slot. A random slot that picks
-- first would otherwise take it, and the listed slot then picked it again (two Techies).
function HeroSelection.IsReservedByForcedPick(heroName)
	for _, team in ipairs({ TEAM_RADIANT, TEAM_DIRE }) do
		local list = getForcedPickList(team)
		if type(list) == "table" then
			for slot = 1, math.min(5, #list) do
				if Utils.TrimString(list[slot] or "") == heroName then
					return true
				end
			end
		end
	end
	return false
end
function HeroSelection.CanPickRandomHero(team, heroName)
	return HeroSelection.CanPickHero(team, heroName) and not HeroSelection.IsReservedByForcedPick(heroName)
end
function HeroSelection.GetRandomAvailableHero(team, heroList)
	if type(heroList) ~= "table" or #heroList == 0 then
		return nil
	end
	local shuffled = {}
	for i = 1, #heroList do
		shuffled[i] = heroList[i]
	end
	HeroSelection.ShuffleArray(shuffled)
	for _, heroName in ipairs(shuffled) do
		if HeroSelection.CanPickRandomHero(team, heroName) then
			return heroName
		end
	end
	return nil
end
function HeroSelection.GetNotRepeatHero(heroList)
	if type(heroList) ~= "table" or #heroList == 0 then
		return nil
	end
	local heroName = HeroSelection.GetRandomAvailableHero(GetTeam(), heroList)
	return heroName or heroList[1]
end
function HeroSelection.IsRepeatHero(heroName)
	if CustomLoader and CustomLoader.Allow_Repeated_Heroes then
		return false
	end
	return isHeroPicked(heroName)
end
function HeroSelection.SkipPickingWeakHeroes(heroName)
	return isWeakHeroCapReached(GetTeam(), heroName)
end
function HeroSelection.IsHumanNotReady(team)
	if GameTime() > 20 or skipHumanWait then
		return false
	end
	local humanCount, humanPickedCount = 0, 0
	for _, playerId in pairs(GetTeamPlayers(team)) do
		if not IsPlayerBot(playerId) then
			humanCount = humanCount + 1
			if GetSelectedHeroName(playerId) ~= "" then
				humanPickedCount = humanPickedCount + 1
			end
		end
	end
	return humanPickedCount < humanCount
end
function HeroSelection.GetCurrentTeam(team, useBestRole)
	local currentTeam = {}
	for slot, playerId in pairs(GetTeamPlayers(team)) do
		local heroName = GetSelectedHeroName(playerId)
		if heroName ~= nil and heroName ~= "" then
			if useBestRole then
				table.insert(currentTeam, { name = heroName, pos = Role.GetBestEffortSuitableRole(heroName) })
			else
				table.insert(currentTeam, { name = heroName, pos = Role.RoleAssignment[ownTeamKey][slot] })
			end
		end
	end
	return currentTeam
end
local pickOrderShuffled = { TEAM_RADIANT = false, TEAM_DIRE = false }
local function assignLanes()
	if GetTeam() == TEAM_RADIANT and not radiantLanesSet then
		for slot, _ in pairs(GetTeamPlayers(TEAM_RADIANT)) do
			local role = Role.RoleAssignment["TEAM_RADIANT"][slot]
			laneAssignments.TEAM_RADIANT[slot] = radiantDefaultLanes[role]
		end
		radiantLanesSet = true
	elseif GetTeam() == TEAM_DIRE and not direLanesSet then
		local laneSlot = 1
		for slot, playerId in pairs(GetTeamPlayers(TEAM_DIRE)) do
			local role = Role.RoleAssignment["TEAM_DIRE"][slot]
			if not IsPlayerBot(playerId) then
				laneAssignments.TEAM_DIRE[laneSlot] = direDefaultLanes[role]
				direLaneSlot[slot] = laneSlot
				laneSlot = laneSlot + 1
			end
		end
		for slot, playerId in pairs(GetTeamPlayers(TEAM_DIRE)) do
			local role = Role.RoleAssignment["TEAM_DIRE"][slot]
			if IsPlayerBot(playerId) then
				laneAssignments.TEAM_DIRE[laneSlot] = direDefaultLanes[role]
				direLaneSlot[slot] = laneSlot
				laneSlot = laneSlot + 1
			end
		end
		direLanesSet = true
	end
end
local function getEnemyPicks()
	local enemyPicks = {}
	for _, playerId in pairs(GetTeamPlayers(GetOpposingTeam())) do
		local heroName = GetSelectedHeroName(playerId)
		if heroName ~= nil and heroName ~= "" then
			table.insert(enemyPicks, heroName)
		end
	end
	return enemyPicks
end
local function getAllyPicks()
	local allyPicks = {}
	for _, playerId in pairs(GetTeamPlayers(GetTeam())) do
		local heroName = GetSelectedHeroName(playerId)
		if heroName ~= nil and heroName ~= "" then
			table.insert(allyPicks, heroName)
		end
	end
	return allyPicks
end
local availablePositions = { TEAM_RADIANT = { "1", "2", "3", "4", "5" }, TEAM_DIRE = { "1", "2", "3", "4", "5" } }
local function HeroPosWeight(heroName, pos)
	if heroName == nil or heroName == "" then
		return 10
	end
	local weights = heroPosWeights[heroName]
	if weights == nil then
		return 10
	end
	return weights[pos] or 0
end
-- True when the hero is clearly a 1/2/3 and should not sit on 4/5.
local function IsCorePreferredHero(heroName)
	local coreBest = math.max(HeroPosWeight(heroName, 1), HeroPosWeight(heroName, 2), HeroPosWeight(heroName, 3))
	local suppBest = math.max(HeroPosWeight(heroName, 4), HeroPosWeight(heroName, 5))
	return coreBest >= 30 and coreBest > suppBest and suppBest <= 10
end
local function LaneForRole(radiant, role)
	if role == 1 or role == 5 then
		return radiant and LANE_BOT or LANE_TOP
	elseif role == 2 then
		return LANE_MID
	end
	return radiant and LANE_TOP or LANE_BOT
end
local function ApplyLanesFromRoles(teamKey)
	local radiant = teamKey == "TEAM_RADIANT"
	for idx = 1, 5 do
		local role = Role.RoleAssignment[teamKey][idx]
		if role ~= nil then
			local lane = LaneForRole(radiant, role)
			if teamKey == "TEAM_DIRE" then
				laneAssignments[teamKey][direLaneSlot[idx] or idx] = lane
			else
				laneAssignments[teamKey][idx] = lane
			end
		end
	end
end
-- locked[index] = position. Remaining bot slots filled by hero_pos_weights (cores stay 1-3).
local function ReassignBotRoles(teamKey, locked)
	locked = locked or {}
	local teamId = teamKey == "TEAM_RADIANT" and TEAM_RADIANT or TEAM_DIRE
	local players = GetTeamPlayers(teamId)
	local takenPos = {}
	for idx, pos in pairs(locked) do
		Role.RoleAssignment[teamKey][idx] = pos
		takenPos[pos] = true
	end
	local freePos = {}
	for pos = 1, 5 do
		if not takenPos[pos] then
			freePos[#freePos + 1] = pos
		end
	end
	-- Fill core spots before support spots.
	table.sort(freePos, function(posA, posB)
		local groupA = posA <= 3 and 0 or 1
		local groupB = posB <= 3 and 0 or 1
		if groupA ~= groupB then
			return groupA < groupB
		end
		return posA < posB
	end)
	local freeBots = {}
	for idx, pid in pairs(players) do
		if idx <= 5 and locked[idx] == nil then
			freeBots[#freeBots + 1] = {
				idx = idx,
				pid = pid,
				hero = GetSelectedHeroName(pid),
			}
		end
	end
	local assigned = {}
	for _, pos in ipairs(freePos) do
		local best, bestScore = nil, -99999
		for _, bot in ipairs(freeBots) do
			if not assigned[bot.idx] then
				local score = HeroPosWeight(bot.hero, pos)
				if pos >= 4 and IsCorePreferredHero(bot.hero) then
					score = score - 1000
				elseif pos <= 3 and IsCorePreferredHero(bot.hero) then
					score = score + 80
				end
				if pos >= 4 and not IsCorePreferredHero(bot.hero) then
					score = score + 40
				end
				if score > bestScore then
					bestScore = score
					best = bot
				end
			end
		end
		if best ~= nil then
			assigned[best.idx] = true
			Role.RoleAssignment[teamKey][best.idx] = pos
			log(
				"Reassign role ok. Team: %s idx: %s hero: %s -> pos %s (score %.0f)",
				teamKey,
				best.idx,
				tostring(best.hero),
				pos,
				bestScore
			)
		end
	end
	ApplyLanesFromRoles(teamKey)
	-- Force GetPosition() to re-read RoleAssignment.
	Role.HeroPositions = {}
end
-- Exchange roster slot idx with whoever currently holds newPos. Every other slot stays.
-- Returns "ok", "same", "human", or "missing".
local function SwapRoleWithHolder(teamKey, players, idx, newPos)
	local roles = Role.RoleAssignment[teamKey]
	local oldPos = roles[idx]
	if oldPos == nil then
		return "missing"
	end
	if oldPos == newPos then
		return "same"
	end
	local holder = nil
	for slot = 1, 5 do
		if roles[slot] == newPos then
			holder = slot
			break
		end
	end
	if holder ~= nil and holder ~= idx then
		local pid = players[holder]
		if pid ~= nil and not IsPlayerBot(pid) then
			return "human"
		end
	end
	roles[idx] = newPos
	if holder ~= nil and holder ~= idx then
		roles[holder] = oldPos
	end
	ApplyLanesFromRoles(teamKey)
	Role.HeroPositions = {}
	log("Swap role ok. Team: %s idx %s pos %s <-> idx %s pos %s", teamKey, idx, oldPos, tostring(holder), newPos)
	return "ok"
end
local function countWeakHeroes(team)
	local count = 0
	for _, playerId in pairs(GetTeamPlayers(team)) do
		local heroName = GetSelectedHeroName(playerId)
		if heroName and heroName ~= "" and Utils.HasValue(weakHeroes, heroName) then
			count = count + 1
		end
	end
	return count
end
local function getTeamOfPlayer(playerId)
	return GetTeamForPlayer(playerId)
end
local function scoreCandidates(team, pool, enemyPicks, pos)
	local scored = {}
	local weakPenalty = getWeakHeroPenalty(team)
	local allyPicks = getAllyPicks()
	for _, heroName in ipairs(pool) do
		if HeroSelection.CanPickRandomHero(team, heroName) then
			local score = 0
			if MatchupsData[heroName] then
				for _, enemyHero in ipairs(enemyPicks) do
					local matchup = MatchupsData[heroName][enemyHero]
					if matchup ~= nil then
						local advantage = -1 * matchup
						if advantage >= 0 then
							score = score + math.sqrt(advantage)
						else
							score = score - math.sqrt(math.abs(advantage))
						end
					end
				end
			end
			if MatchupsData.IsSynergy and #allyPicks > 0 then
				for _, allyHero in ipairs(allyPicks) do
					if allyHero ~= heroName then
						if MatchupsData.IsSynergy(heroName, allyHero) then
							score = score + 1.5
						end
						if MatchupsData.IsCounter and MatchupsData.IsCounter(allyHero, heroName) then
							score = score - 0.5
						end
					end
				end
			end
			if pos and heroPosWeights[heroName] then
				local posWeight = heroPosWeights[heroName][pos] or 50
				score = score * posWeight / 100
			end
			if Utils.HasValue(weakHeroes, heroName) then
				score = score * weakPenalty
			end
			table.insert(scored, { name = heroName, score = score })
		end
	end
	table.sort(scored, function(candidateA, candidateB)
		return candidateA.score > candidateB.score
	end)
	return scored
end
local function pickWeightedTop5(scored)
	while #scored > 5 do
		table.remove(scored)
	end
	if #scored == 0 then
		return nil
	end
	local rankWeights = { 35, 25, 20, 12, 8 }
	local roll = RandomInt(1, 100)
	local cumulative = 0
	for rank, rankWeight in ipairs(rankWeights) do
		cumulative = cumulative + rankWeight
		if roll <= cumulative and scored[rank] then
			return scored[rank].name
		end
	end
	return scored[1].name
end
local function chooseHeroForSlot(slot, playerId)
	local team = getTeamOfPlayer(playerId)
	local pool = positionHeroPools[slot]
	local defaultHero = slotHeroes[slot]
	local heroName = defaultHero
	local forced = forcedSlot[slot] == true
	if not forced and RandomInt(1, 5) >= 1 then
		local enemyPicks = getEnemyPicks()
		local scored = scoreCandidates(team, pool, enemyPicks, slot)
		local teamName = team == TEAM_RADIANT and "Radiant" or "Dire"
		log("==== top 5 heroes for team: %s pos: %s id: %s ====", teamName, slot, playerId)
		for rank = 1, math.min(5, #scored) do
			log("%d: score=%s name=%s", rank, scored[rank].score, scored[rank].name)
		end
		heroName = pickWeightedTop5(scored)
		if not heroName then
			heroName = HeroSelection.GetRandomAvailableHero(team, pool) or defaultHero
		end
	end
	local keepForced = forced and defaultHero == heroName
	if not keepForced then
		if not HeroSelection.CanPickRandomHero(team, heroName) then
			heroName = HeroSelection.GetRandomAvailableHero(team, pool) or defaultHero
		end
	end
	if Utils.HasValue(weakHeroes, heroName) then
		weakHeroPickCount[team] = countWeakHeroes(team)
		weakHeroPickCount[team] = weakHeroPickCount[team] + 1
	end
	return heroName
end
local function pickNextBotHero()
	local teamPlayers = GetTeamPlayers(GetTeam(), true)
	-- Keep debug force-pick order stable (pos 1..N as listed).
	if
		not pickOrderShuffled[ownTeamKey]
		and not hasDebugForcedPicks
		and not Utils.IsHumanPlayerInTeam(GetTeam())
		and not IsLanMode()
	then
		HeroSelection.ShufflePickOrder(teamPlayers)
		pickOrderShuffled[ownTeamKey] = true
	elseif not pickOrderShuffled[ownTeamKey] and hasDebugForcedPicks then
		pickOrderShuffled[ownTeamKey] = true
	end
	for slot, playerId in pairs(teamPlayers) do
		if
			IsPlayerBot(playerId)
			and GetSelectedHeroName(playerId) == ""
			and IsPlayerInHeroSelectionControl(playerId)
			and GameTime() >= (pickState.NextPickAt[slot] or math.huge)
		then
			local heroName = chooseHeroForSlot(slot, playerId)
			SelectHero(playerId, heroName)
			pickState.NextPickAt[slot] = math.huge
			break
		end
	end
end
local function isChatCommand(text)
	return string.len(text) > 3 and text:sub(1, 1) == "!"
end
local function splitCommand(text)
	local command, rest = Utils.TrimString(text):match("^(%S+)%s+(.*)$")
	return command, rest
end
local heroPickedByChat = false
local function handleChatCommand(text, senderId, teamOnly)
	local commandWord, commandText = splitCommand(text)
	if commandWord == nil then
		log("[WARN] Invalid command: %s", text)
		return
	end
	local teamPlayers = GetTeamPlayers(GetTeam())
	if (teamPlayers == nil or #teamPlayers == 0) and senderId ~= nil then
		local playerTeam = GetTeamForPlayer(senderId)
		if playerTeam ~= nil then
			teamPlayers = GetTeamPlayers(playerTeam) or {}
		end
		if #teamPlayers == 0 then
			local roster = {}
			for i = 1, 5 do
				local member = GetTeamMember(i)
				if member ~= nil then
					local memberPlayerId = member:GetPlayerID()
					if memberPlayerId ~= nil then
						roster[i] = memberPlayerId
					end
				end
			end
			if #roster > 0 then
				teamPlayers = roster
			end
		end
		if #teamPlayers == 0 and playerTeam ~= nil then
			local roster = {}
			local seen = {}
			for scanPlayerId = 0, 63 do
				local pidTeam = GetTeamForPlayer(scanPlayerId)
				local inSelection = false
				pcall(function()
					inSelection = IsPlayerInHeroSelectionControl(scanPlayerId)
				end)
				local isBot = false
				pcall(function()
					isBot = IsPlayerBot(scanPlayerId)
				end)
				if (inSelection or isBot or pidTeam == playerTeam) and not seen[scanPlayerId] then
					seen[scanPlayerId] = true
					roster[#roster + 1] = scanPlayerId
				end
			end
			if #roster > 0 then
				teamPlayers = roster
				log(
					"[CHAT] roster rebuilt by PID scan (#%s): first=[%s,%s,%s,%s,%s]",
					tostring(#roster),
					tostring(roster[1]),
					tostring(roster[2]),
					tostring(roster[3]),
					tostring(roster[4]),
					tostring(roster[5])
				)
			end
		end
	end
	log("Handling command starting with: %s, text: %s", commandWord, commandText)
	local commands = {}
	for command in text:gmatch("[^;]+") do
		table.insert(commands, command:match("^%s*(.-)%s*$"))
	end
	for _, command in ipairs(commands) do
		local action, argument = command:match("(!%w+)%s*(.*)")
		if action == "!pick" and GetGameMode() ~= GAMEMODE_CM and GetGameMode() ~= GAMEMODE_REVERSE_CM then
			log("Picking hero %s, is-for-ally: %s", argument, teamOnly)
			local heroName = GetHumanChatHero(argument)
			log("Actual picking hero %s ", heroName)
			if heroName ~= "" then
				if not HeroSelection.CanPickHero(GetTeam(), heroName) then
					log("Hero %s cannot be picked now (banned/repeat/weakcap)", heroName)
					return
				end
				local pickForAlly = teamOnly == true or teamOnly == false and GetTeamForPlayer(senderId) ~= GetTeam()
				if pickForAlly then
					for _, playerId in pairs(teamPlayers) do
						if
							IsPlayerBot(playerId)
							and IsPlayerInHeroSelectionControl(playerId)
							and GetSelectedHeroName(playerId) == ""
						then
							SelectHero(playerId, heroName)
							if Utils.HasValue(weakHeroes, heroName) then
								weakHeroPickCount[GetTeam()] = weakHeroPickCount[GetTeam()] + 1
							end
							break
						end
					end
				end
				heroPickedByChat = true
			else
				log(
					"Hero name not found or not supported! See: https://github.com/anggara-ts/Supercharged-OpenHyperAI/blob/main/FuncLib/data/hero_names.lua"
				)
			end
		elseif action == "!ban" and GetGameState() == GAME_STATE_HERO_SELECTION then
			log("Banning hero %s", argument)
			local heroName = GetHumanChatHero(argument)
			if heroName ~= "" then
				if isHeroPicked(heroName) then
					log("Hero  %s has already been picked", heroName)
					return
				end
				HeroSelection.SetChatHeroBan(heroName)
				log("Banned hero %s. Banned list:", heroName)
				Utils.PrintTable(banList)
			else
				log(
					"Hero name not found or not supported! See: https://github.com/anggara-ts/Supercharged-OpenHyperAI/blob/main/FuncLib/data/hero_names.lua"
				)
			end
		elseif action == "!pos" and GetGameState() == GAME_STATE_PRE_GAME then
			log("Selecting pos %s", argument)
			local teamKey = GetTeamForPlayer(senderId) == TEAM_RADIANT and "TEAM_RADIANT" or "TEAM_DIRE"
			local positions = availablePositions[teamKey]
			if Utils.HasValue(positions, argument) then
				local position = tonumber(argument)
				local requesterIndex = senderId + 1
				for index, playerId in pairs(teamPlayers) do
					if playerId == senderId then
						requesterIndex = index
					end
				end
				local ownerIsBot = false
				for index, playerId in pairs(teamPlayers) do
					if Role.RoleAssignment[teamKey][index] == position then
						ownerIsBot = IsPlayerBot(playerId)
						break
					end
				end
				if not ownerIsBot and Role.RoleAssignment[teamKey][requesterIndex] ~= position then
					log("Switch role failed: target role belongs to human.")
				else
					local locked = {}
					-- Lock every human on this team; requester takes the chosen pos.
					for idx, pid in pairs(teamPlayers) do
						if idx <= 5 and not IsPlayerBot(pid) then
							if pid == senderId then
								locked[idx] = position
							elseif Role.RoleAssignment[teamKey][idx] ~= position then
								locked[idx] = Role.RoleAssignment[teamKey][idx]
							end
						end
					end
					locked[requesterIndex] = position
					ReassignBotRoles(teamKey, locked)
					log(
						"Switch role ok (role-aware). Team: %s PID: %s, idx: %s, new role: %s",
						teamKey,
						senderId,
						requesterIndex,
						Role.RoleAssignment[teamKey][requesterIndex]
					)
				end
			else
				log("Cannot select pos: %s (not available).", argument)
			end
		elseif action:match("^!(%d+)pos$") ~= nil and GetGameState() == GAME_STATE_PRE_GAME then
			local botIndexText, positionText = text:match("^!(%d+)pos (%d+)$")
			if botIndexText and positionText then
				log("Swap position for #%s to play pos %s", botIndexText, positionText)
			else
				log("Invalid command format for swapping pos")
				return
			end
			local teamKey = GetTeamForPlayer(senderId) == TEAM_RADIANT and "TEAM_RADIANT" or "TEAM_DIRE"
			local positions = availablePositions[teamKey]
			if Utils.HasValue(positions, positionText) then
				local position = tonumber(positionText)
				local botIndex = tonumber(botIndexText)
				if botIndex == nil or botIndex < 1 or botIndex > 5 then
					log("Invalid bot index for !Npos")
					return
				end
				local targetPid = teamPlayers[botIndex]
				local targetHero = targetPid and GetSelectedHeroName(targetPid) or ""
				-- Don't force a core hero onto 4/5. Leave the roster as it is.
				if position >= 4 and IsCorePreferredHero(targetHero) then
					log("Refuse !%spos %s: %s is a core hero", botIndexText, positionText, targetHero)
				else
					local swapped = SwapRoleWithHolder(teamKey, teamPlayers, botIndex, position)
					if swapped == "human" then
						log("Switch role failed: target role belongs to human.")
					elseif swapped == "same" then
						log("Switch role skipped: idx %s already pos %s", botIndex, position)
					elseif swapped == "missing" then
						log("Switch role failed: idx %s has no role", botIndex)
					end
				end
			else
				log("Cannot select pos: %s (not available).", positionText)
			end
		elseif action == "!sp" or action == "!speak" then
			HandleLocaleSetting(argument)
		else
			log("Unknown action: %s, command text: %s", action, text)
		end
	end
end
function HandleLocaleSetting(locale)
	CustomLoader.Localization = locale
	log("Set to speak: %s", locale)
end
local function initPickTimes()
	if pickState.initialized then
		return
	end
	if
		GameTime() < 3.0 and not skipHumanWait
		or HeroSelection.IsHumanNotReady(GetTeam())
		or HeroSelection.IsHumanNotReady(GetOpposingTeam())
	then
		return
	end
	local startTime = GameTime() + 3
	local slotDelay = GetTeam() * 3
	local minJitter, maxJitter = 1, 3
	local teamPlayers = GetTeamPlayers(GetTeam(), true)
	for slot = 1, #teamPlayers do
		local jitter = RandomFloat(minJitter, maxJitter)
		pickState.NextPickAt[slot] = startTime + (slot - 1) * slotDelay + jitter
	end
	pickState.initialized = true
end
function Think()
	MatchTrace.MatchMarker("start", "mode=" .. tostring(GetGameMode()))
	if GetGameMode() == GAMEMODE_CM or GetGameMode() == GAMEMODE_REVERSE_CM then
		CaptainMode.CaptainModeLogic(allHeroNames)
		CaptainMode.AddToList()
	elseif GetGameMode() == GAMEMODE_1V1MID then
		OneVsOneLogic()
	else
		if
			GameTime() < 3.0 and not skipHumanWait
			or HeroSelection.IsHumanNotReady(GetTeam())
			or HeroSelection.IsHumanNotReady(GetOpposingTeam())
		then
			if GetGameMode() ~= GAMEMODE_TURBO then
				return
			end
		end
		initPickTimes()
		if not pickState.initialized then
			return
		end
		pickNextBotHero()
	end
end
function GetHumanChatHero(heroQuery)
	if heroQuery == nil then
		return ""
	end
	heroQuery = heroQuery:lower()
	for _, heroName in pairs(allHeroNames) do
		if HeroDisplayNames["en"][heroName]:lower() == heroQuery then
			log("Found hero %s for %s", heroName, heroQuery)
			return heroName
		end
	end
	for _, heroName in pairs(allHeroNames) do
		if string.find(heroName, heroQuery) then
			log("Found hero %s for %s", heroName, heroQuery)
			return heroName
		end
	end
	log("Hero not supported with name: %s", heroQuery)
	return ""
end
function SelectHeroChatCallback(senderId, text, teamOnly)
	local lowerText = string.lower(text)
	if GetGameState() == GAME_STATE_HERO_SELECTION and string.len(text) == 2 then
		if Localization.Supported(text) then
			HandleLocaleSetting(text)
		end
	end
	if isChatCommand(lowerText) then
		handleChatCommand(lowerText, senderId, teamOnly)
	end
end
local customBotNames = { Radiant = {}, Dire = {} }
if CustomLoader then
	for i = 1, #CustomLoader.Radiant_Names do
		if CustomLoader.Radiant_Names[i] ~= nil then
			customBotNames.Radiant[i] = Utils.TrimString(CustomLoader.Radiant_Names[i])
		end
	end
	for i = 1, #CustomLoader.Dire_Names do
		if CustomLoader.Dire_Names[i] ~= nil then
			customBotNames.Dire[i] = Utils.TrimString(CustomLoader.Dire_Names[i])
		end
	end
end
local botNames = TeamNames.generateTeams(customBotNames)
function GetBotNames()
	return GetTeam() == TEAM_RADIANT and botNames.Radiant or botNames.Dire
end
local chatCallbackInstalled = false
function UpdateLaneAssignments()
	local teamKey = GetTeam() == TEAM_RADIANT and "TEAM_RADIANT" or "TEAM_DIRE"
	if GetGameMode() == GAMEMODE_MO then
		Role.RoleAssignment[teamKey] = { 2, 2, 2, 2, 2 }
		return allMidLanes
	end
	if GetGameMode() == GAMEMODE_1V1MID then
		return oneVsOneLanes
	end
	if GetGameMode() == GAMEMODE_CM or GetGameMode() == GAMEMODE_REVERSE_CM then
		laneAssignments[teamKey] = CaptainMode.CMLaneAssignment(Role.RoleAssignment, heroPickedByChat)
	end
	if
		not chatCallbackInstalled
		and (
			GetGameState() == GAME_STATE_HERO_SELECTION
			or GetGameState() == GAME_STATE_STRATEGY_TIME
			or GetGameState() == GAME_STATE_PRE_GAME
		)
	then
		InstallChatCallback(function(event)
			SelectHeroChatCallback(event.player_id, event.string, event.team_only)
		end)
		chatCallbackInstalled = true
	end
	assignLanes()
	return laneAssignments[teamKey]
end
function AlignLanesBasedOnRoles(teamKey)
	for index, role in pairs(Role.RoleAssignment[teamKey]) do
		if role == 1 or role == 5 then
			if GetTeam() == TEAM_RADIANT then
				laneAssignments[teamKey][index] = LANE_BOT
			else
				laneAssignments[teamKey][index] = LANE_TOP
			end
		elseif role == 2 then
			laneAssignments[teamKey][index] = LANE_MID
		elseif role == 3 or role == 4 then
			if GetTeam() == TEAM_RADIANT then
				laneAssignments[teamKey][index] = LANE_TOP
			else
				laneAssignments[teamKey][index] = LANE_BOT
			end
		end
	end
end
local oneVsOnePicked = false
function OneVsOneLogic()
	local heroName
	if Utils.IsHumanPlayerInTeam(GetTeam()) then
		oneVsOnePicked = true
	end
	for _, playerId in pairs(GetTeamPlayers(GetTeam())) do
		if
			not oneVsOnePicked
			and IsPlayerBot(playerId)
			and IsPlayerInHeroSelectionControl(playerId)
			and GetSelectedHeroName(playerId) == ""
		then
			if Utils.IsHumanPlayerInAnyTeam() then
				heroName = GetSelectedHumanHero(GetOpposingTeam())
			else
				heroName = HeroSelection.GetRandomAvailableHero(GetTeam(), positionHeroPools[2]) or slotHeroes[2]
			end
			if heroName ~= nil then
				SelectHero(playerId, heroName)
				oneVsOnePicked = true
				if Utils.HasValue(weakHeroes, heroName) then
					weakHeroPickCount[GetTeam()] = weakHeroPickCount[GetTeam()] + 1
				end
			end
			return
		elseif
			oneVsOnePicked
			and IsPlayerBot(playerId)
			and IsPlayerInHeroSelectionControl(playerId)
			and GetSelectedHeroName(playerId) == ""
		then
			local fallbackHero = "npc_dota_hero_techies"
			if HeroSelection.CanPickHero(GetTeam(), fallbackHero) then
				SelectHero(playerId, fallbackHero)
			else
				local heroName = HeroSelection.GetRandomAvailableHero(GetTeam(), positionHeroPools[2]) or slotHeroes[2]
				SelectHero(playerId, heroName)
				if Utils.HasValue(weakHeroes, heroName) then
					weakHeroPickCount[GetTeam()] = weakHeroPickCount[GetTeam()] + 1
				end
			end
			return
		end
	end
end
function GetSelectedHumanHero(team)
	for _, playerId in pairs(GetTeamPlayers(team)) do
		if not IsPlayerBot(playerId) and GetSelectedHeroName(playerId) ~= "" then
			return GetSelectedHeroName(playerId)
		end
	end
end

-- [OHA-ERROR] trap (hero selection). From ~11:20 every game an unwrapped entry point fails and the engine only
-- prints "Script Runtime Error: error in error handling" (its handler cannot run, typically a stack
-- overflow), then squelches it after 10 copies. Caught here and printed with its name, up to 3 times
-- per entry point per bot; the failing call still just stops, as before.
local OHA_TRAP_COUNT = {}
local function OHA_Trap(name, fn, fallback)
	if type(fn) ~= "function" then
		return fn
	end
	return function(...)
		local results = { pcall(fn, ...) }
		if results[1] then
			return unpack(results, 2)
		end
		local trapCount = (OHA_TRAP_COUNT[name] or 0) + 1
		OHA_TRAP_COUNT[name] = trapCount
		if trapCount <= 3 then
			local hero = "?"
			pcall(function()
				hero = GetBot():GetUnitName()
			end)
			pcall(print, string.format("[OHA-ERROR] t=%.1f %s %s: %s", DotaTime(), hero, name, tostring(results[2])))
		end
		return fallback
	end
end
Think = OHA_Trap("HEROSEL_Run", Think, nil)
UpdateLaneAssignments = OHA_Trap("UpdateLaneAssignments", UpdateLaneAssignments, nil)
