-- Farm mode. Decides when the bot keeps farming and when it leaves to defend a tower.
if
	GetBot():IsInvulnerable()
	or not GetBot():IsHero()
	or not string.find(GetBot():GetUnitName(), "hero")
	or GetBot():IsIllusion()
then
	return
end
local Utils = require(GetScriptDirectory() .. "/FuncLib/systems/utils")
local Localization = require(GetScriptDirectory() .. "/FuncLib/systems/localization")
local CustomizeGeneral = require(GetScriptDirectory() .. "/Customize/general")
local FarmDefend = require(GetScriptDirectory() .. "/FuncLib/systems/farm_defend")
local MatchTrace = require(GetScriptDirectory() .. "/FuncLib/systems/match_trace")
local bot = GetBot()
local FarmMode = {}
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local radiantBaseLocation = Vector(-7174.000000, -6671.00000, 0.000000)
local direBaseLocation = Vector(7023.000000, 6450.000000, 0.000000)
local botName = bot:GetUnitName()
local secondOfMinute = 0
local preferredCamp = nil
local lastDesireLogTime = 0
local availableCamps = {}
local laneCreeps = {}
local farmState = 0
local farmStateNone = 0
local farmStateCamp = 1
local teamPlayers = nil
local lanes = { LANE_TOP, LANE_MID, LANE_BOT }
local lastAssembleTime = 0
local lastTeamActivityTime = 0
local lastKillCheckTime = 0
local killCheckInterval = 5.0
local allyKills = 0
local enemyKills = 0
local loseKillGap = RandomInt(35, 45)
local winKillGap = RandomInt(24, 34)
local positionChecked = false
local isOfflaner = false
local isMidlaner = false
local isCarry = false
local team = GetTeam()
local enemyHumanCount, enemyBotCount = Fu.Utils.NumHumanBotPlayersInTeam(GetOpposingTeam())
local allyHumanCount, allyBotCount = Fu.Utils.NumHumanBotPlayersInTeam(team)
local lastCacheCleanupTime = -100
local modeLocaleKeys = {
	[BOT_MODE_LANING] = "mode_laning",
	[BOT_MODE_FARM] = "mode_farming",
	[BOT_MODE_PUSH_TOWER_TOP] = "mode_pushing",
	[BOT_MODE_PUSH_TOWER_MID] = "mode_pushing",
	[BOT_MODE_PUSH_TOWER_BOT] = "mode_pushing",
	[BOT_MODE_DEFEND_TOWER_TOP] = "mode_defending",
	[BOT_MODE_DEFEND_TOWER_MID] = "mode_defending",
	[BOT_MODE_DEFEND_TOWER_BOT] = "mode_defending",
	[BOT_MODE_RETREAT] = "mode_retreating",
	[BOT_MODE_ROSHAN] = "mode_roshan",
	[BOT_MODE_ATTACK] = "mode_fighting",
	[BOT_MODE_ROAM] = "mode_roaming",
	[BOT_MODE_TEAM_ROAM] = "mode_fighting",
	[BOT_MODE_SIDE_SHOP] = "mode_tormentor",
}
if BOT_MODE_WATCHER then
	modeLocaleKeys[BOT_MODE_WATCHER] = "mode_tormentor"
end
-- Short modes that used to print as "busy".
if BOT_MODE_WARD then
	modeLocaleKeys[BOT_MODE_WARD] = "mode_warding"
end
if BOT_MODE_RUNE then
	modeLocaleKeys[BOT_MODE_RUNE] = "mode_rune"
end
if BOT_MODE_ITEM then
	modeLocaleKeys[BOT_MODE_ITEM] = "mode_item"
end
function FarmMode.GetModeLocaleKey(mode)
	return modeLocaleKeys[mode] or "mode_other"
end
if bot.farmLocation == nil then
	bot.farmLocation = bot:GetLocation()
end
function GetDesire()
	if ShouldSkipBotThink(GetBot()) then
		return 0
	end
	if bot.isBear or string.find(bot:GetUnitName(), "lone_druid_bear") then
		local hasScepter = bot:HasModifier("modifier_item_ultimate_scepter_consumed")
			or bot:FindItemSlot("item_ultimate_scepter") >= 0
		if not hasScepter then
			local Utils = require(GetScriptDirectory() .. "/FuncLib/systems/utils")
			local loneDruid = Utils.GetLoneDruid(bot)
			if loneDruid and loneDruid.hero and Fu.IsValidHero(loneDruid.hero) and loneDruid.hero:IsAlive() then
				if loneDruid.hero:GetActiveMode() == BOT_MODE_FARM then
					return loneDruid.hero:GetActiveModeDesire() + 0.05
				end
			end
		end
	end
	local ok, desire = pcall(GetDesireHelper)
	if not ok then
		if IsDebug then
			log("[FARM-ERROR] %s %s", bot:GetUnitName(), tostring(desire))
		end
		return BOT_MODE_DESIRE_VERYLOW
	end
	Fu.Utils["GameStates"] = Fu.Utils["GameStates"] or {}
	Fu.Utils["GameStates"]["defendPings"] = Fu.Utils["GameStates"]["defendPings"] or { pingedTime = GameTime() }
	if IsDebug and DotaTime() > 3 * 60 and DotaTime() > lastDesireLogTime + 10 then
		lastDesireLogTime = DotaTime()
		log(
			"[FARM-DESIRE] %s t=%.0f raw=%.2f exit=%s mode=%s pos=%d prefCamp=%s",
			bot:GetUnitName(),
			DotaTime(),
			desire,
			tostring(bot._farmExitReason or "normal"),
			tostring(bot:GetActiveMode()),
			Fu.GetPosition(bot),
			tostring(preferredCamp ~= nil)
		)
	end
	if desire > 0 and bot:GetUnitName() ~= "npc_dota_hero_huskar" then
		desire = desire * RemapValClamped(Fu.GetHP(bot), 0.3, 0.7, 0, 1)
	end
	if desire > 0 and Fu.IsInTeamFight(bot, 1200) then
		desire = desire * 0.4
	end
	local maxDefendDesire =
		math.max(GetDefendLaneDesire(LANE_TOP), GetDefendLaneDesire(LANE_MID), GetDefendLaneDesire(LANE_BOT))
	local maxPushDesire =
		math.max(GetPushLaneDesire(LANE_TOP), GetPushLaneDesire(LANE_MID), GetPushLaneDesire(LANE_BOT))
	if desire > 0.3 then
		if maxDefendDesire > 0.55 then
			desire = desire * RemapValClamped(maxDefendDesire, 0.4, 0.8, 1, 0.3)
		end
		if maxPushDesire > 0.45 then
			desire = desire * RemapValClamped(maxPushDesire, 0.35, 0.75, 1, 0.35)
		end
	end
	local pushFrequency = CustomizeGeneral.Push_Frequency or 1
	if (enemyHumanCount > 0 or allyHumanCount > 0) and pushFrequency <= 1 then
		pushFrequency = 2
	end
	if pushFrequency >= 3 then
		desire = desire * 0.3
	elseif pushFrequency >= 2 then
		desire = desire * 0.65
	end
	-- Do not lock farm when the team should push or defend.
	local shouldGroup = maxDefendDesire > 0.4
		or maxPushDesire > 0.35
		or (
			Fu.IsLateGame()
			and Fu.GetNumOfAliveHeroes(false) >= 3
			and Fu.GetNumOfAliveHeroes(false) >= Fu.GetNumOfAliveHeroes(true)
		)
	if desire > 0.15 and not shouldGroup then
		bot._farmCommitUntil = DotaTime() + 3.0
		bot._farmCommitFloor = desire * 0.7
	elseif shouldGroup then
		bot._farmCommitUntil = nil
		bot._farmCommitFloor = nil
	end
	if bot._farmCommitUntil and DotaTime() <= bot._farmCommitUntil then
		desire = math.max(desire, bot._farmCommitFloor or 0)
	end
	-- A defend call already treats one hero on the high ground as a base fight.
	-- The 3s farm lock must not put him back in the jungle after that call.
	local ancient = GetAncient(GetTeam())
	if
		Fu.Utils.CountEnemyHeroesOnHighGround(GetTeam()) >= 1
		or ancient and Fu.Utils.CountEnemyHeroesNear(ancient:GetLocation(), 2500) >= 1
	then
		bot._farmCommitUntil = nil
		bot._farmCommitFloor = nil
		return BOT_MODE_DESIRE_NONE
	end
	-- A creep wave at our Ancient while this bot is at base (just respawned, or shopping):
	-- clear it before walking out. Farm (0.66) otherwise beat the defend floor and the bot
	-- walked to the middle of the map and back.
	if ancient ~= nil and GetUnitToUnitDistance(bot, ancient) <= 4500 then
		local creeps = 0
		local loc = ancient:GetLocation()
		for _, unit in pairs(GetUnitList(UNIT_LIST_ENEMY_CREEPS) or {}) do
			if unit ~= nil and unit:IsAlive() and GetUnitToLocationDistance(unit, loc) <= 1400 then
				creeps = creeps + 1
			end
		end
		if creeps >= 2 then
			bot._farmCommitUntil = nil
			bot._farmCommitFloor = nil
			return BOT_MODE_DESIRE_NONE
		end
	end
	-- An ally close by is fighting enemy heroes: no farming. At 30:30 Earthshaker and Centaur
	-- started a fight ~2,100 away and Medusa's farm (0.66) kept beating attack (~0.6), so she
	-- walked back and forth instead of joining.
	for _, ally in pairs(GetUnitList(UNIT_LIST_ALLIED_HEROES) or {}) do
		if
			ally ~= nil
			and ally ~= bot
			and ally:IsAlive()
			and not ally:IsIllusion()
			and GetUnitToUnitDistance(bot, ally) <= 2500
		then
			local target = ally:GetAttackTarget()
			local hitting = target ~= nil
				and not target:IsNull()
				and target:IsHero()
				and target:GetTeam() ~= bot:GetTeam()
			local hit = ally:WasRecentlyDamagedByAnyHero(2.0)
				and #(ally:GetNearbyHeroes(1200, true, BOT_MODE_NONE) or {}) >= 1
			if hitting or hit then
				bot._farmCommitUntil = nil
				bot._farmCommitFloor = nil
				return BOT_MODE_DESIRE_NONE
			end
		end
	end
	-- Same for a creep wave on our high ground (T3 or barracks) with this bot already there.
	-- The defend mode takes it (hg-creeps); farm used to win and walk him away from it.
	if Fu.Utils.HighGroundCreepWaveNear ~= nil and Fu.Utils.HighGroundCreepWaveNear(bot, 2500) then
		bot._farmCommitUntil = nil
		bot._farmCommitFloor = nil
		return BOT_MODE_DESIRE_NONE
	end
	-- Evasive maneuvers is the engine's momentary dodge mode. Replying from it read as
	-- "I'm busy" for a bot that was really about to farm.
	if desire > 0.5 and bot:GetActiveMode() ~= BOT_MODE_EVASIVE_MANEUVERS and FarmDefend.ClaimAnnounce() then
		local localeKey = FarmMode.GetModeLocaleKey(bot:GetActiveMode())
		local modeName = Localization.Get(localeKey) or localeKey
		local message = Localization.Get("say_not_defending")
		if message then
			bot:ActionImmediate_Chat(string.format(message, modeName), false)
		end
	end
	return desire
end
function GetDesireHelper()
	bot._farmExitReason = nil
	if preferredCamp == nil then
		preferredCamp = Fu.Site.GetClosestNeutralSpwan(bot, availableCamps)
	end
	if DotaTime() - lastCacheCleanupTime > Utils.CachedVarsCleanTime then
		Utils.CleanupCachedVars()
		lastCacheCleanupTime = DotaTime()
	end
	Fu.Utils["GameStates"] = Fu.Utils["GameStates"] or {}
	Fu.Utils["GameStates"]["defendPings"] = Fu.Utils["GameStates"]["defendPings"] or { pingedTime = GameTime() }
	if FarmDefend.ShouldLeaveFarm(bot) then
		bot._farmExitReason = "defend_ping"
		MatchTrace.Decide(bot, "farm_exit", "defend_ping", "leave farm for defend ping", 8)
		if FarmDefend.ClaimDecisionChat("leave_farm_defend") then
			local chatLines = Localization.Get("say_leave_farm_defend")
			if type(chatLines) == "table" and #chatLines > 0 then
				bot:ActionImmediate_Chat(chatLines[RandomInt(1, #chatLines)], false)
			elseif type(chatLines) == "string" then
				bot:ActionImmediate_Chat(chatLines, false)
			end
		end
		return BOT_MODE_DESIRE_VERYLOW
	end
	local ancient = GetAncient(GetTeam())
	if
		Fu.Utils.CountEnemyHeroesOnHighGround(GetTeam()) >= 1
		or ancient and Fu.Utils.CountEnemyHeroesNear(ancient:GetLocation(), 2500) >= 1
	then
		bot._farmExitReason = "enemies_on_hg"
		MatchTrace.Decide(bot, "farm_exit", "enemies_on_hg", "leave farm: enemies on high ground / ancient", 8)
		if FarmDefend.ClaimDecisionChat("leave_farm_base") then
			local chatLines = Localization.Get("say_base_defend")
			if type(chatLines) == "table" and #chatLines > 0 then
				bot:ActionImmediate_Chat(chatLines[RandomInt(1, #chatLines)], false)
			elseif type(chatLines) == "string" then
				bot:ActionImmediate_Chat(chatLines, false)
			end
		end
		return BOT_MODE_DESIRE_NONE
	end
	if not positionChecked then
		positionChecked = true
		isOfflaner = Fu.GetPosition(bot) == 3
		isMidlaner = Fu.GetPosition(bot) == 2
		isCarry = Fu.GetPosition(bot) == 1
	end
	if DotaTime() < 50 then
		bot._farmExitReason = "too_early"
		return 0.0
	end
	local maxDefendDesire =
		math.max(GetDefendLaneDesire(LANE_TOP), GetDefendLaneDesire(LANE_MID), GetDefendLaneDesire(LANE_BOT))
	if maxDefendDesire > 0.5 then
		local defendLane, defendDesire = Fu.GetMostDefendLaneDesire()
		local defendFrontLocation = GetLaneFrontLocation(GetTeam(), defendLane, 0)
		local alliesAtFront = Fu.GetAlliesNearLoc(defendFrontLocation, 2500)
		if #alliesAtFront >= 3 then
			local frontDistance = GetUnitToLocationDistance(bot, defendFrontLocation)
			local hasTp = Fu.Item.GetItemCharges(bot, "item_tpscroll") >= 1
			if frontDistance <= 3500 or hasTp then
				bot._farmExitReason = "serious_defend"
				return BOT_MODE_DESIRE_VERYLOW
			end
		end
	end
	local loneDruid = Fu.CheckLoneDruid()
	local botMode = bot:GetActiveMode()
	local botModeDesire = bot:GetActiveModeDesire()
	local isAlive = bot:IsAlive()
	local isMainHero = not bot:HasModifier("modifier_arc_warden_tempest_double") and not Fu.IsMeepoClone(bot)
	local nearbyEnemies = Fu.GetEnemiesNearLoc(bot:GetLocation(), 1600)
	local alliesAtTormentor = Fu.GetAlliesNearLoc(Fu.GetTormentorLocation(GetTeam()), 1600)
	local alliesAtRoshan = Fu.GetAlliesNearLoc(Fu.GetCurrentRoshanLocation(), 1200)
	local isRoshanAlive = Fu.IsRoshanAlive()
	local allyNetworth, enemyNetworth = Fu.GetInventoryNetworth()
	local networthLead = allyNetworth - enemyNetworth
	local aliveEnemies = Fu.GetNumOfAliveHeroes(true)
	local aliveAllies = Fu.GetNumOfAliveHeroes(false)
	if
		not isAlive
		or Fu.IsInLaningPhase()
		or Fu.IsDefending(bot) and botModeDesire > BOT_MODE_DESIRE_MODERATE
		or Fu.IsDoingRoshan(bot) and isMainHero
		or Fu.IsDoingTormentor(bot) and isMainHero
		or DotaTime() < 50
		or (botMode == BOT_MODE_SECRET_SHOP or botMode == BOT_MODE_RUNE or botMode == BOT_MODE_WARD or botMode == BOT_MODE_RETREAT or botMode == BOT_MODE_OUTPOST) and botModeDesire > 0
		or #alliesAtTormentor >= 2 and bot.tormentor_state == true
		or #alliesAtRoshan >= 2 and isRoshanAlive and isMainHero
		or Fu.DoesTeamHaveAegis() and not Fu.IsEarlyGame() and aliveAllies >= 4
		or FarmMode.IsUnitAroundLocation(GetAncient(GetTeam()):GetLocation(), 3200)
		or #nearbyEnemies > 0
		or aliveEnemies <= 1 and networthLead > 10000
	then
		if DotaTime() > 10 * 60 and DotaTime() > (bot._lastFarmEarlyLog or 0) + 15 then
			bot._lastFarmEarlyLog = DotaTime()
			log(
				string.format(
					"[FARM-EARLY] %s t=%.0f laning=%s defend=%s rosh=%s tor=%s enemies=%d ancient=%s aegis=%s nwAdv=%s alive=%dv%d",
					bot:GetUnitName(),
					DotaTime(),
					tostring(Fu.IsInLaningPhase()),
					tostring(Fu.IsDefending(bot) and botModeDesire > BOT_MODE_DESIRE_MODERATE),
					tostring(Fu.IsDoingRoshan(bot) and isMainHero),
					tostring(Fu.IsDoingTormentor(bot) and isMainHero),
					#nearbyEnemies,
					tostring(FarmMode.IsUnitAroundLocation(GetAncient(GetTeam()):GetLocation(), 3200)),
					tostring(Fu.DoesTeamHaveAegis() and not Fu.IsEarlyGame() and aliveAllies >= 4),
					tostring(aliveEnemies <= 1 and networthLead > 10000),
					aliveAllies,
					aliveEnemies
				)
			)
		end
		bot._farmExitReason = "early_exit"
		return BOT_MODE_DESIRE_NONE
	end
	if not isAlive then
		bot._farmExitReason = "dead"
		return BOT_MODE_DESIRE_NONE
	end
	for i = 1, #GetTeamPlayers(GetTeam()) do
		local teamMember = GetTeamMember(i)
		if
			bot ~= teamMember
			and Fu.IsValidHero(teamMember)
			and Fu.IsInRange(bot, teamMember, 2000)
			and Fu.IsRetreating(teamMember)
		then
			local enemiesTargetingAlly = Fu.GetHeroesTargetingUnit(nearbyEnemies, teamMember)
			if #enemiesTargetingAlly >= 2 or teamMember:WasRecentlyDamagedByAnyHero(1.0) then
				bot._farmExitReason = "retreating_ally"
				return BOT_MODE_DESIRE_NONE
			end
		end
	end
	local teamFightLocation = Fu.GetTeamFightLocation(bot)
	if teamFightLocation ~= nil and GetUnitToLocationDistance(bot, teamFightLocation) < 2500 then
		if bot:GetLevel() >= 18 or not Fu.IsCore(bot) then
			bot._farmExitReason = "teamfight_nearby"
			return BOT_MODE_DESIRE_NONE
		end
	end
	local aliveEnemyCount = Fu.GetNumOfAliveHeroes(true)
	local aliveAllyCount = Fu.GetNumOfAliveHeroes(false)
	local roshanAlive = Fu.IsRoshanAlive()
	local alliesNearRoshan = Fu.GetAlliesNearLoc(Fu.GetCurrentRoshanLocation(), 1200)
	if teamPlayers == nil then
		teamPlayers = GetTeamPlayers(GetTeam())
	end
	if FarmMode.IsUnitAroundLocation(GetAncient(GetTeam()):GetLocation(), 3000) then
		bot._farmExitReason = "enemies_at_ancient"
		return BOT_MODE_DESIRE_NONE
	end
	secondOfMinute = math.floor(DotaTime()) % 60
	if
		not Fu.Role.IsCampRefreshDone()
		and Fu.Role.GetAvailableCampCount() < Fu.Role.GetCampCount()
		and (DotaTime() > 20 and secondOfMinute > 0 and secondOfMinute < 2)
	then
		Fu.Role["availableCampTable"], Fu.Role["campCount"] = Fu.Site.RefreshCamp(bot)
		Fu.Role["hasRefreshDone"] = true
	end
	if Fu.Role.IsCampRefreshDone() and secondOfMinute > 52 then
		Fu.Role["hasRefreshDone"] = false
	end
	availableCamps = Fu.Role["availableCampTable"]
	if isAlive and bot:HasModifier("modifier_arc_warden_tempest_double") then
		if roshanAlive then
			for _, allyHero in pairs(alliesNearRoshan) do
				if
					allyHero ~= bot
					and Fu.IsValidHero(allyHero)
					and allyHero:GetUnitName() == "npc_dota_hero_arc_warden"
					and Fu.IsDoingRoshan(allyHero)
				then
					local allyTarget = allyHero:GetAttackTarget()
					if Fu.IsRoshan(allyTarget) and Fu.GetHP(allyTarget) < 0.4 or botMode == BOT_MODE_ITEM then
						if preferredCamp == nil then
							preferredCamp = Fu.Site.GetClosestNeutralSpwan(bot, availableCamps)
						end
						return RemapValClamped(
							Fu.GetHP(bot),
							0.2,
							0.7,
							BOT_MODE_DESIRE_MODERATE,
							BOT_MODE_DESIRE_VERYHIGH
						)
					end
				end
			end
		end
	end
	if isAlive and Fu.IsMeepoClone(bot) then
		if roshanAlive then
			for _, allyHero in pairs(alliesNearRoshan) do
				if
					allyHero ~= bot
					and Fu.IsValidHero(allyHero)
					and not Fu.IsMeepoClone(allyHero)
					and allyHero:GetUnitName() == "npc_dota_hero_meepo"
					and Fu.IsDoingRoshan(allyHero)
				then
					local allyTarget = allyHero:GetAttackTarget()
					if Fu.IsRoshan(allyTarget) and Fu.GetHP(allyTarget) < 0.25 or botMode == BOT_MODE_ITEM then
						if preferredCamp == nil then
							preferredCamp = Fu.Site.GetClosestNeutralSpwan(bot, availableCamps)
						end
						return RemapValClamped(
							Fu.GetHP(bot),
							0.2,
							0.7,
							BOT_MODE_DESIRE_MODERATE,
							BOT_MODE_DESIRE_VERYHIGH
						)
					end
				end
			end
		end
	end
	if Fu.DoesTeamHaveAegis() and not Fu.IsEarlyGame() and aliveAllyCount >= 4 then
		bot._farmExitReason = "aegis_push"
		return BOT_MODE_DESIRE_VERYLOW
	end
	if DotaTime() > lastKillCheckTime + killCheckInterval then
		lastKillCheckTime = DotaTime()
		allyKills = Fu.GetNumOfTeamTotalKills(false)
		enemyKills = Fu.GetNumOfTeamTotalKills(true)
		if enemyKills > allyKills + loseKillGap and Fu.Role.NotSayRate() then
			Fu.Role["sayRate"] = true
			if RandomInt(1, 6) < 3 then
				bot:ActionImmediate_Chat(Localization.Get("say_will_lose"), true)
			else
				bot:ActionImmediate_Chat(Localization.Get("say_will_lose_2"), true)
			end
		end
		if allyKills > enemyKills + winKillGap and Fu.Role.NotSayRate() then
			Fu.Role["sayRate"] = true
			if RandomInt(1, 6) < 3 then
				bot:ActionImmediate_Chat(Localization.Get("say_will_win"), true)
			else
				bot:ActionImmediate_Chat(Localization.Get("say_will_win_2"), true)
			end
		end
	end
	local allyCount = Fu.GetAllyCount(bot, 1400)
	if allyCount >= 4 or bot:GetLevel() >= 23 and allyCount >= 3 or GetRoshanDesire() > BOT_MODE_DESIRE_VERYHIGH then
		local nearbyNeutrals = bot:GetNearbyNeutralCreeps(bot:GetAttackRange())
		if #nearbyNeutrals == 0 then
			lastTeamActivityTime = DotaTime()
		end
	end
	local handOfMidas = Fu.IsItemAvailable("item_hand_of_midas")
	if Fu.IsInAllyArea(bot) and Fu.CanCastAbility(handOfMidas) then
		if preferredCamp == nil then
			preferredCamp = Fu.Site.GetClosestNeutralSpwan(bot, availableCamps)
		end
		return RemapValClamped(Fu.GetHP(bot), 0.2, 0.7, BOT_MODE_DESIRE_MODERATE, BOT_MODE_DESIRE_VERYHIGH)
	end
	if Fu.IsDefending(bot) and botModeDesire >= 0.75 then
		local defendLane, defendDesire = Fu.GetMostDefendLaneDesire()
		local defendFrontLocation = GetLaneFrontLocation(GetTeam(), defendLane, -600)
		local alliesAtFront = Fu.GetAlliesNearLoc(defendFrontLocation, 2200)
		local nearbyNeutrals = bot:GetNearbyNeutralCreeps(Min(bot:GetAttackRange(), 1600))
		if
			#nearbyNeutrals == 0
			and #alliesAtFront >= 2
			and (not isCarry or bot:GetLevel() >= 15 or Fu.IsLateGame())
		then
			lastTeamActivityTime = DotaTime()
		end
	end
	if lastTeamActivityTime > DotaTime() - 3.0 and not isCarry and not isMidlaner then
		bot._farmExitReason = "team_activity"
		return BOT_MODE_DESIRE_VERYLOW
	end
	local pushingAllies = 0
	for i = 1, #GetTeamPlayers(GetTeam()) do
		local teamMember = GetTeamMember(i)
		if teamMember ~= nil and teamMember ~= bot and teamMember:IsAlive() then
			local mode = teamMember:GetActiveMode()
			if
				mode == BOT_MODE_PUSH_TOWER_TOP
				or mode == BOT_MODE_PUSH_TOWER_MID
				or mode == BOT_MODE_PUSH_TOWER_BOT
			then
				pushingAllies = pushingAllies + 1
			end
		end
	end
	if isOfflaner and Fu.IsLateGame() then
		if bot:GetActiveMode() == BOT_MODE_ASSEMBLE then
			lastAssembleTime = DotaTime()
		end
		if DotaTime() - lastAssembleTime < 5 then
			bot._farmExitReason = "assemble"
			return BOT_MODE_DESIRE_VERYLOW
		end
		if Fu.IsTeamActivityCount(bot, 3) then
			bot._farmExitReason = "team_activity_3"
			return BOT_MODE_DESIRE_VERYLOW
		end
	end
	if pushingAllies >= 4 then
		bot._farmExitReason = "4_allies_pushing"
		return BOT_MODE_DESIRE_VERYLOW
	end
	local isTimeToFarm = Fu.Site.IsTimeToFarm(bot)
	local isDefending = Fu.IsDefending(bot)
	local armor = bot:GetArmor()
	local canFarm = GetGameMode() ~= GAMEMODE_MO
		and isTimeToFarm
		and (not isDefending or botModeDesire < BOT_MODE_DESIRE_MODERATE)
		and (
			bot:GetUnitName() ~= "npc_dota_hero_lone_druid_bear"
			or bot:HasScepter() and not Fu.IsValid(loneDruid.hero)
		)
	if IsDebug and DotaTime() > 3 * 60 and not canFarm and DotaTime() > (bot._lastFarmBlockLog or 0) + 10 then
		bot._lastFarmBlockLog = DotaTime()
		log(
			"[FARM-BLOCK] %s t=%.0f SKIPPED: isTimeToFarm=%s defending=%s armor=%.0f pos=%s",
			bot:GetUnitName(),
			DotaTime(),
			tostring(isTimeToFarm),
			tostring(isDefending),
			armor,
			tostring(Fu.GetPosition(bot))
		)
	end
	if canFarm then
		if preferredCamp == nil then
			preferredCamp = Fu.Site.GetClosestNeutralSpwan(bot, availableCamps)
		end
		if Fu.GetDistanceFromEnemyFountain(bot) > 4000 then
			laneCreeps = bot:GetNearbyLaneCreeps(1600, true)
			if #laneCreeps == 0 and Fu.IsInAllyArea(bot) and FarmMode.IsNearLaneFront(bot) then
				laneCreeps = bot:GetNearbyLaneCreeps(1600, false)
			end
		end
		if #laneCreeps > 0 then
			local enemiesNearCreeps = Fu.GetEnemiesNearLoc(Fu.GetCenterOfUnits(laneCreeps), 1600)
			if #enemiesNearCreeps == 0 then
				bot.farmLocation = Fu.GetCenterOfUnits(laneCreeps)
				return BOT_MODE_DESIRE_VERYHIGH
			end
		end
		if #laneCreeps == 0 then
			local teamFountain = Fu.GetTeamFountain()
			local enemyFountain = Fu.GetEnemyFountain()
			local bestLane = nil
			local bestScore = 0
			for _, lane in pairs({ LANE_TOP, LANE_MID, LANE_BOT }) do
				local laneFront = GetLaneFrontLocation(GetTeam(), lane, 0)
				local frontDistance = GetUnitToLocationDistance(bot, laneFront)
				local distanceToOurFountain = Fu.GetDistance(laneFront, teamFountain)
				local distanceToEnemyFountain = Fu.GetDistance(laneFront, enemyFountain)
				if distanceToOurFountain < distanceToEnemyFountain and frontDistance < 6000 then
					local lastSeenEnemies = Fu.GetLastSeenEnemiesNearLoc(laneFront, 1600)
					if #lastSeenEnemies == 0 then
						local score = 1
							/ math.max(1, frontDistance)
							* distanceToEnemyFountain
							/ math.max(1, distanceToOurFountain)
						if score > bestScore then
							bestScore = score
							bestLane = lane
						end
					end
				end
			end
			if bestLane ~= nil then
				local farmLaneLocation = GetLaneFrontLocation(GetTeam(), bestLane, 0)
				if not IsLocationPassable(farmLaneLocation) then
					farmLaneLocation = Fu.AdjustLocationWithOffsetTowardsFountain(farmLaneLocation, 200)
				end
				if IsLocationPassable(farmLaneLocation) then
					bot.farmLocation = farmLaneLocation
					return BOT_MODE_DESIRE_VERYHIGH
				end
			end
		end
		if #laneCreeps == 0 then
			if preferredCamp == nil then
				preferredCamp = Fu.Site.GetClosestNeutralSpwan(bot, availableCamps)
			end
			if IsDebug then
				log(
					"[FARM-CAMP] %s t=%.0f prefCamp=%s farmState=%d",
					bot:GetUnitName(),
					DotaTime(),
					tostring(preferredCamp ~= nil),
					farmState
				)
			end
			if preferredCamp ~= nil then
				if not Fu.Site.IsModeSuitableToFarm(bot) then
					preferredCamp = nil
					bot._farmExitReason = "mode_not_suitable_" .. tostring(botMode)
					return BOT_MODE_DESIRE_VERYLOW
				elseif bot:GetHealth() <= 200 then
					preferredCamp = nil
					lastTeamActivityTime = DotaTime()
					bot._farmExitReason = "low_hp"
					return BOT_MODE_DESIRE_VERYLOW
				elseif farmState == farmStateCamp then
					bot._farmExitReason = "farming_camp"
					return BOT_MODE_DESIRE_ABSOLUTE
				else
					bot.farmLocation = preferredCamp.cattr.location
					bot._farmExitReason = "walk_to_camp"
					return BOT_MODE_DESIRE_VERYHIGH
				end
			end
		end
	end
	if preferredCamp == nil then
		preferredCamp = Fu.Site.GetClosestNeutralSpwan(bot, availableCamps)
		if preferredCamp ~= nil then
			bot.farmLocation = preferredCamp.cattr.location
		end
	end
	if not Fu.IsInLaningPhase() and Fu.IsCore(bot) and DotaTime() > 5 * 60 then
		if preferredCamp == nil then
			preferredCamp = Fu.Site.GetClosestNeutralSpwan(bot, availableCamps)
		end
		if preferredCamp ~= nil then
			local maxPushDesire =
				math.max(GetPushLaneDesire(LANE_TOP), GetPushLaneDesire(LANE_MID), GetPushLaneDesire(LANE_BOT))
			local maxDefendDesire =
				math.max(GetDefendLaneDesire(LANE_TOP), GetDefendLaneDesire(LANE_MID), GetDefendLaneDesire(LANE_BOT))
			local aliveAllyHeroes = Fu.GetNumOfAliveHeroes(false)
			local aliveEnemyHeroes = Fu.GetNumOfAliveHeroes(true)
			-- Do not let this fallback beat push/defend: it used to always return VERYHIGH.
			local shouldGroup = maxDefendDesire > 0.4
				or maxPushDesire > 0.35
				or (Fu.IsLateGame() and aliveAllyHeroes >= 3 and aliveAllyHeroes >= aliveEnemyHeroes)
			if shouldGroup then
				bot._farmExitReason = "yield_to_push_defend"
				MatchTrace.Decide(
					bot,
					"farm_exit",
					"yield_to_push_defend",
					string.format(
						"yield farm push=%.2f defend=%.2f allies=%d enemies=%d",
						maxPushDesire,
						maxDefendDesire,
						aliveAllyHeroes,
						aliveEnemyHeroes
					),
					8
				)
				local chatKey = maxDefendDesire >= maxPushDesire and "say_leave_farm_defend" or "say_leave_farm_push"
				local chatKind = maxDefendDesire >= maxPushDesire and "leave_farm_defend" or "leave_farm_push"
				if FarmDefend.ClaimDecisionChat(chatKind) then
					local chatLines = Localization.Get(chatKey)
					if type(chatLines) == "table" and #chatLines > 0 then
						bot:ActionImmediate_Chat(chatLines[RandomInt(1, #chatLines)], false)
					elseif type(chatLines) == "string" then
						bot:ActionImmediate_Chat(chatLines, false)
					end
				end
				return BOT_MODE_DESIRE_LOW
			end
			if not isTimeToFarm then
				bot._farmExitReason = "core_fallback_not_time"
				return BOT_MODE_DESIRE_MODERATE
			end
			return BOT_MODE_DESIRE_VERYHIGH
		end
	end
	if not Fu.IsInLaningPhase() and (Fu.IsLateGame() or bot:GetLevel() >= 18) then
		if preferredCamp == nil then
			preferredCamp = Fu.Site.GetClosestNeutralSpwan(bot, availableCamps)
		end
		if preferredCamp ~= nil then
			return BOT_MODE_DESIRE_LOW
		end
	end
	if botModeDesire < 0.1 and DotaTime() > 5 * 60 then
		if preferredCamp ~= nil then
			return BOT_MODE_DESIRE_MODERATE
		end
		laneCreeps = bot:GetNearbyLaneCreeps(1600, true)
		if #laneCreeps > 0 then
			return BOT_MODE_DESIRE_MODERATE
		end
	end
	bot._farmExitReason = "end_fallback"
	return BOT_MODE_DESIRE_VERYLOW
end
function OnStart() end
function OnEnd()
	preferredCamp = nil
	farmState = farmStateNone
	laneCreeps = {}
	bot._farmCommitKind = nil
	bot._farmCommitAt = 0
	bot:SetTarget(nil)
end
local lastThinkLogTime = 0
local function IsNeutralCreep(creep)
	if not Fu.IsValid(creep) or Fu.IsRoshan(creep) or Fu.IsTormentor(creep) then
		return false
	end
	if creep.IsNeutralUnitType and creep:IsNeutralUnitType() then
		return true
	end
	return creep.GetTeam and creep:GetTeam() == TEAM_NEUTRAL
end
-- Creeps kite off the camp box. A 900 scan from the hero marks the camp empty
-- while the last one is still alive, then a lane wave steals the bot.
local function CampNeutrals(bot, campLoc)
	local found = {}
	local seen = {}
	local function add(list)
		if list == nil then
			return
		end
		for _, creep in pairs(list) do
			if IsNeutralCreep(creep) and seen[creep] == nil then
				local nearBot = GetUnitToUnitDistance(bot, creep) <= 1400
				local nearCamp = campLoc ~= nil and GetUnitToLocationDistance(creep, campLoc) <= 1100
				if nearBot or nearCamp then
					seen[creep] = true
					found[#found + 1] = creep
				end
			end
		end
	end
	add(bot:GetNearbyNeutralCreeps(1600))
	add(bot:GetNearbyCreeps(1600, true))
	return found
end
function Think()
	if OhaCastGuard ~= nil and OhaCastGuard(GetBot()) then
		return
	end
	if IsDebug then
		local now = DotaTime()
		if now > lastThinkLogTime + 3 then
			lastThinkLogTime = now
			local canNotUseAction = Fu.CanNotUseAction(bot)
			local laneCreepsNearby = bot:GetNearbyLaneCreeps(1200, true)
			local neutralsNearby = bot:GetNearbyNeutralCreeps(900)
			log(
				"[FARM-THINK] %s t=%.0f desire=%.2f canNotUse=%s farmState=%d prefCamp=%s laneCreeps=%d neutrals=%d",
				bot:GetUnitName(),
				now,
				bot:GetActiveModeDesire(),
				tostring(canNotUseAction),
				farmState,
				tostring(preferredCamp ~= nil),
				#(laneCreepsNearby or {}),
				#(neutralsNearby or {})
			)
		end
	end
	if Fu.CanNotUseAction(bot) then
		return
	end
	if Fu.GetHP(bot) < 0.35 and bot:WasRecentlyDamagedByAnyHero(3.0) then
		local fountain = Fu.GetTeamFountain()
		bot:Action_MoveToLocation(fountain)
		return
	end
	local pushingAllies = {}
	for i = 1, #GetTeamPlayers(GetTeam()) do
		local teamMember = GetTeamMember(i)
		if teamMember ~= nil and teamMember ~= bot and teamMember:IsAlive() then
			local mode = teamMember:GetActiveMode()
			if
				mode == BOT_MODE_PUSH_TOWER_TOP
				or mode == BOT_MODE_PUSH_TOWER_MID
				or mode == BOT_MODE_PUSH_TOWER_BOT
			then
				if GetUnitToUnitDistance(bot, teamMember) < 5000 then
					table.insert(pushingAllies, teamMember)
				end
			end
		end
	end
	if #pushingAllies >= 3 then
		local pushCenter = Fu.GetCenterOfUnits(pushingAllies)
		local offset = math.max(bot:GetAttackRange() / 2, 150)
		local followLocation = Fu.AdjustLocationWithOffsetTowardsFountain(pushCenter, offset)
		bot:Action_MoveToLocation(followLocation)
		return
	end
	if bot.isBear or string.find(bot:GetUnitName(), "lone_druid_bear") then
		local Utils = require(GetScriptDirectory() .. "/FuncLib/systems/utils")
		local loneDruid = Utils.GetLoneDruid(bot)
		if loneDruid and loneDruid.hero and Fu.IsValidHero(loneDruid.hero) then
			local druidTarget = loneDruid.hero:GetAttackTarget()
			if
				Fu.IsValid(druidTarget)
				and Fu.CanBeAttacked(druidTarget)
				and GetUnitToUnitDistance(bot, druidTarget) < 1200
			then
				bot:Action_AttackUnit(druidTarget, true)
				return
			end
			local druidDistance = GetUnitToUnitDistance(bot, loneDruid.hero)
			if druidDistance > 500 then
				bot:Action_MoveToLocation(loneDruid.hero:GetLocation())
				return
			end
		end
	end
	secondOfMinute = math.floor(DotaTime()) % 60
	if
		preferredCamp == nil
		and bot.farmLocation
		and IsLocationPassable(bot.farmLocation)
		and GetUnitToLocationDistance(bot, bot.farmLocation) > 1200
	then
		local nearbyLaneCreeps = bot:GetNearbyLaneCreeps(900, true)
		local nearbyNeutrals = bot:GetNearbyNeutralCreeps(500)
		if #nearbyLaneCreeps == 0 and #nearbyNeutrals == 0 then
			bot:Action_MoveToLocation(bot.farmLocation)
			return
		end
	end
	local commitDuration = 4.0
	bot._farmCommitKind = bot._farmCommitKind or nil
	bot._farmCommitAt = bot._farmCommitAt or 0
	local now = GameTime()
	local isCommitted = bot._farmCommitKind ~= nil and now - bot._farmCommitAt < commitDuration
	local campLoc = preferredCamp ~= nil and preferredCamp.cattr.location or nil
	local campCreeps = CampNeutrals(bot, campLoc)
	local finishingCamp = #campCreeps > 0
		and (bot._farmCommitKind == "camp" or (campLoc ~= nil and GetUnitToLocationDistance(bot, campLoc) <= 1200))
	local nearbyLaneCreeps = bot:GetNearbyLaneCreeps(900, true)
	local preferLane = true
	if preferredCamp ~= nil and nearbyLaneCreeps ~= nil and #nearbyLaneCreeps > 0 then
		local campLocation = preferredCamp.cattr.location
		local campDistance = GetUnitToLocationDistance(bot, campLocation)
		local creepDistance = GetUnitToUnitDistance(bot, nearbyLaneCreeps[1])
		preferLane = creepDistance * 1.3 < campDistance
	end
	if isCommitted and bot._farmCommitKind == "camp" or finishingCamp then
		preferLane = false
	end
	if nearbyLaneCreeps ~= nil and #nearbyLaneCreeps > 0 and farmState ~= farmStateCamp and preferLane then
		bot._farmCommitKind = "lane"
		bot._farmCommitAt = now
		local enemyTowers = bot:GetNearbyTowers(1600, true)
		if Fu.IsValidBuilding(enemyTowers[1]) then
			if enemyTowers[1]:GetAttackTarget() == bot or bot:WasRecentlyDamagedByTower(5.0) then
				bot:Action_MoveToLocation(Fu.VectorAway(bot:GetLocation(), enemyTowers[1]:GetLocation(), 1600))
				return
			end
		end
		local weakestCreep = nil
		local minHealth = math.huge
		for _, creep in pairs(nearbyLaneCreeps) do
			if
				Fu.IsValid(creep)
				and Fu.CanBeAttacked(creep)
				and not Fu.IsRoshan(creep)
				and not Fu.IsTormentor(creep)
			then
				local health = creep:GetHealth()
				if health < minHealth then
					weakestCreep = creep
					minHealth = health
				end
			end
		end
		if Fu.IsValid(weakestCreep) then
			local attackRange = bot:GetAttackRange()
			if GetUnitToUnitDistance(bot, weakestCreep) > attackRange then
				bot:Action_MoveToLocation(weakestCreep:GetLocation())
				return
			else
				bot:Action_AttackUnit(weakestCreep, false)
				return
			end
		end
	end
	bot._farm_repick_at = bot._farm_repick_at or 0
	if GameTime() >= (bot._farm_repick_at or 0) then
		bot._farm_repick_at = GameTime() + 3.0
		if preferredCamp == nil then
			preferredCamp = Fu.Site.GetClosestNeutralSpwan(bot, availableCamps)
		else
			local campDistance = GetUnitToLocationDistance(bot, preferredCamp.cattr.location)
			if campDistance > 1500 then
				local closerCamp = Fu.Site.GetClosestNeutralSpwan(bot, Fu.Role["availableCampTable"])
				if closerCamp and closerCamp ~= preferredCamp then
					local closerCampDistance = GetUnitToLocationDistance(bot, closerCamp.cattr.location)
					if closerCampDistance + 1000 < campDistance and not Fu.Site.IsCampDangerous(bot, closerCamp) then
						preferredCamp = closerCamp
					end
				end
			end
		end
	end
	if preferredCamp == nil then
		preferredCamp = Fu.Site.GetClosestNeutralSpwan(bot, availableCamps)
	end
	if preferredCamp ~= nil then
		local campLocation = preferredCamp.cattr.location
		local campDistance = GetUnitToLocationDistance(bot, campLocation)
		local laneCreepsNear = bot:GetNearbyLaneCreeps(1200, true)
		if #laneCreepsNear > 0 and not finishingCamp then
			local creepCenter = Fu.GetCenterOfUnits(laneCreepsNear)
			local creepCenterDistance = GetUnitToLocationDistance(bot, creepCenter)
			local enemiesNearCreeps = Fu.GetEnemiesNearLoc(creepCenter, 1600)
			local creepsOnEnemySide = GetUnitToLocationDistance(laneCreepsNear[1], Fu.GetEnemyFountain())
				< GetUnitToLocationDistance(laneCreepsNear[1], Fu.GetTeamFountain())
			if #enemiesNearCreeps == 0 and creepCenterDistance < campDistance and not creepsOnEnemySide then
				local targetCreep = laneCreepsNear[1]
				if Fu.IsValid(targetCreep) and Fu.CanBeAttacked(targetCreep) then
					if GetUnitToUnitDistance(bot, targetCreep) > bot:GetAttackRange() then
						bot:Action_MoveToLocation(targetCreep:GetLocation())
					else
						bot:Action_AttackUnit(targetCreep, false)
					end
					return
				end
			end
		end
		local campNeutrals = bot:GetNearbyCreeps(900, true)
		local alliesAtCamp = Fu.GetAlliesNearLoc(campLocation, 800)
		local allyFarmingCamp = false
		for _, allyHero in pairs(alliesAtCamp) do
			if
				allyHero ~= bot
				and Fu.IsValidHero(allyHero)
				and not allyHero:IsIllusion()
				and Fu.IsFarming(allyHero)
				and Fu.IsAttacking(allyHero)
			then
				allyFarmingCamp = true
				break
			end
		end
		-- Another ally is already on this camp: join it unless it is far (game 016: two bots near
		-- one camp kept turning away from each other; this gave way at 400).
		if allyFarmingCamp and campDistance > 1200 then
			Fu.Role["availableCampTable"], preferredCamp =
				Fu.Site.UpdateAvailableCamp(bot, preferredCamp, Fu.Role["availableCampTable"])
			availableCamps = Fu.Role["availableCampTable"]
			preferredCamp = Fu.Site.GetClosestNeutralSpwan(bot, availableCamps)
		end
		if preferredCamp == nil then
		else
			campLocation = preferredCamp.cattr.location
			campDistance = GetUnitToLocationDistance(bot, campLocation)
			campNeutrals = CampNeutrals(bot, campLocation)
			local campLooksEmpty = (FarmMode.IsLocCanBeSeen(campLocation) and campDistance <= 700)
				or campDistance <= 300
			if #campNeutrals > 0 then
				bot._campEmptySince = 0
			elseif campLooksEmpty then
				if (bot._campEmptySince or 0) == 0 then
					bot._campEmptySince = now
				end
				if now - bot._campEmptySince > 1.2 then
					bot._campEmptySince = 0
					bot._farmCommitKind = nil
					Fu.Role["availableCampTable"], preferredCamp =
						Fu.Site.UpdateAvailableCamp(bot, preferredCamp, Fu.Role["availableCampTable"])
					availableCamps = Fu.Role["availableCampTable"]
					preferredCamp = Fu.Site.GetClosestNeutralSpwan(bot, availableCamps)
					farmState = farmStateNone
				end
			end
			if preferredCamp ~= nil and #campNeutrals > 0 then
				local weakestCreep = nil
				local minHealth = math.huge
				local ancientCreep = nil
				local anyAlive = nil
				for _, creep in pairs(campNeutrals) do
					if IsNeutralCreep(creep) then
						if
							anyAlive == nil
							or GetUnitToUnitDistance(bot, creep) < GetUnitToUnitDistance(bot, anyAlive)
						then
							anyAlive = creep
						end
						if Fu.CanBeAttacked(creep) then
							if not creep:IsAncientCreep() or bot:GetLevel() >= 10 and bot:GetArmor() >= 6 then
								local health = creep:GetHealth()
								if health < minHealth then
									weakestCreep = creep
									minHealth = health
								end
							elseif GetUnitToUnitDistance(bot, creep) < 700 then
								ancientCreep = creep
							end
						end
					end
				end
				local targetCreep = weakestCreep or ancientCreep
				if Fu.IsValid(targetCreep) then
					farmState = farmStateCamp
					bot._farmCommitKind = "camp"
					bot._farmCommitAt = now
					bot:SetTarget(targetCreep)
					bot:Action_AttackUnit(targetCreep, false)
					return
				elseif Fu.IsValid(anyAlive) then
					farmState = farmStateCamp
					bot._farmCommitKind = "camp"
					bot._farmCommitAt = now
					bot:Action_MoveToLocation(anyAlive:GetLocation())
					return
				end
			elseif preferredCamp ~= nil and campDistance > 200 then
				bot._farmCommitKind = "camp"
				bot._farmCommitAt = now
				bot:Action_MoveToLocation(campLocation)
				return
			elseif preferredCamp ~= nil and (bot._campEmptySince or 0) > 0 and now - bot._campEmptySince <= 1.2 then
				bot._farmCommitKind = "camp"
				bot._farmCommitAt = now
				bot:Action_MoveToLocation(campLocation)
				return
			end
		end
	end
	log(
		"[FARM-FALLBACK] %s t=%.0f prefCamp=%s laneCreeps=%d",
		bot:GetUnitName(),
		DotaTime(),
		tostring(preferredCamp ~= nil),
		#(laneCreeps or {})
	)
	local minDistance = 99999
	local nearestFront = nil
	for _, lane in pairs({ LANE_TOP, LANE_MID, LANE_BOT }) do
		local laneFront = GetLaneFrontLocation(GetTeam(), lane, 0)
		local distance = GetUnitToLocationDistance(bot, laneFront)
		if distance < minDistance then
			minDistance = distance
			nearestFront = laneFront
		end
	end
	if nearestFront ~= nil then
		bot:Action_AttackMove(nearestFront)
	else
		bot:Action_AttackMove((radiantBaseLocation + direBaseLocation) / 2)
	end
	return
end
function FarmMode.IsNearLaneFront(bot)
	local maxDistance = 1600
	for _, lane in pairs(lanes) do
		local laneFront = GetLaneFrontLocation(GetTeam(), lane, 0)
		if GetUnitToLocationDistance(bot, laneFront) <= maxDistance then
			return true
		end
	end
	return false
end
function FarmMode.IsUnitAroundLocation(location, radius)
	for i, playerId in pairs(GetTeamPlayers(GetOpposingTeam())) do
		if IsHeroAlive(playerId) and i <= 3 then
			local lastSeenInfo = GetHeroLastSeenInfo(playerId)
			if lastSeenInfo ~= nil then
				local seenInfo = lastSeenInfo[1]
				if
					seenInfo ~= nil
					and Fu.GetDistance(location, seenInfo.location) <= radius
					and seenInfo.time_since_seen < 1.0
				then
					return true
				end
			end
		end
	end
	return false
end
function FarmMode.CouldBlade(bot, location)
	local quellingBlade = Fu.IsItemAvailable("item_quelling_blade")
	if quellingBlade == nil then
		quellingBlade = Fu.IsItemAvailable("item_bfury")
	end
	if quellingBlade ~= nil and quellingBlade:IsFullyCastable() then
		local trees = bot:GetNearbyTrees(380)
		local distance = GetUnitToLocationDistance(bot, location)
		local startLocation = Fu.Site.GetXUnitsTowardsLocation(bot, location, 32)
		local endLocation = Fu.Site.GetXUnitsTowardsLocation(bot, location, distance - 32)
		for _, tree in pairs(trees) do
			if tree ~= nil then
				local treeLocation = GetTreeLocation(tree)
				local lineInfo = PointToLineDistance(startLocation, endLocation, treeLocation)
				if
					lineInfo ~= nil
					and lineInfo.within
					and lineInfo.distance <= 96
					and Fu.GetLocationToLocationDistance(treeLocation, location) < distance
				then
					bot:Action_UseAbilityOnTree(quellingBlade, tree)
					return true
				end
			end
		end
	end
	return false
end
function FarmMode.CouldBlink(bot, location)
	local blinkRange = 1199
	local blinkAbility = Fu.IsItemAvailable("item_blink")
	if botName == "npc_dota_hero_antimage" then
		blinkAbility = bot:GetAbilityByName("antimage_blink")
		blinkRange = blinkAbility:GetSpecialValueInt("AbilityCastRange")
	end
	if botName == "npc_dota_hero_queenofpain" then
		blinkAbility = bot:GetAbilityByName("queenofpain_blink")
		blinkRange = Fu.GetProperCastRange(false, bot, blinkAbility:GetCastRange())
	end
	if blinkAbility ~= nil and blinkAbility:IsFullyCastable() and Fu.IsRunning(bot) then
		local distance = GetUnitToLocationDistance(bot, location)
		local blinkLocation = Fu.Site.GetXUnitsTowardsLocation(bot, location, blinkRange)
		if distance <= 600 then
			return false
		elseif distance < blinkRange + 1 then
			if botName == "npc_dota_hero_antimage" then
				bot:Action_ClearActions(true)
				if not Fu.IsPTReady(bot, ATTRIBUTE_INTELLECT) then
					Fu.SetQueueSwitchPtToINT(bot)
				end
				bot:ActionQueue_UseAbilityOnLocation(blinkAbility, location)
				return true
			end
			bot:Action_UseAbilityOnLocation(blinkAbility, location)
			return true
		elseif IsLocationPassable(blinkLocation) then
			if botName == "npc_dota_hero_antimage" then
				bot:Action_ClearActions(true)
				if not Fu.IsPTReady(bot, ATTRIBUTE_INTELLECT) then
					Fu.SetQueueSwitchPtToINT(bot)
				end
				bot:ActionQueue_UseAbilityOnLocation(blinkAbility, blinkLocation)
				return true
			end
			bot:Action_UseAbilityOnLocation(blinkAbility, blinkLocation)
			return true
		end
	end
	return false
end
function FarmMode.IsLocCanBeSeen(location)
	if GetUnitToLocationDistance(GetBot(), location) < 180 then
		return true
	end
	local rightOffset = location + Vector(5, 0)
	local upOffset = location + Vector(0, 10)
	local leftOffset = location + Vector(-15, 0)
	local downOffset = location + Vector(0, -20)
	return IsLocationVisible(downOffset)
		and IsLocationVisible(leftOffset)
		and IsLocationVisible(rightOffset)
		and IsLocationVisible(upOffset)
		and IsRadiusVisible(location, 10)
end
-- Hold the desire through short dips while this mode is active (FuncLib/systems/mode_hold.lua).
GetDesire = require(GetScriptDirectory() .. "/FuncLib/systems/mode_hold").Wrap(GetDesire, "farm", BOT_MODE_FARM)

-- [OHA-ERROR] trap (farm). From ~11:20 every game an unwrapped entry point fails and the engine only
-- prints "Script Runtime Error: error in error handling" (its handler cannot run, typically a stack
-- overflow), then squelches it after 10 copies. Caught here and printed with its name, up to 3 times
-- per entry point per bot; the failing call still just stops, as before.
local OHA_TRAP_COUNT = {}
local function OHA_Trap(name, fn, fallback)
	if type(fn) ~= "function" then
		return fn
	end
	return function(...)
		local res = { pcall(fn, ...) }
		if res[1] then
			return unpack(res, 2)
		end
		local errorCount = (OHA_TRAP_COUNT[name] or 0) + 1
		OHA_TRAP_COUNT[name] = errorCount
		if errorCount <= 3 then
			local hero = "?"
			pcall(function()
				hero = GetBot():GetUnitName()
			end)
			pcall(print, string.format("[OHA-ERROR] t=%.1f %s %s: %s", DotaTime(), hero, name, tostring(res[2])))
		end
		return fallback
	end
end
GetDesire = OHA_Trap("FARM_GetDesire", GetDesire, 0)
Think = OHA_Trap("FARM_Run", Think, nil)
