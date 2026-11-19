-- Casts abilities and uses items while the bot is already in some other mode.
local Usage = {}
local PerfParts = require(GetScriptDirectory() .. "/FuncLib/systems/perf")
-- Perf.Part helpers for ItemUsageThink (#52).
local function PartStart()
	return RealTime ~= nil and RealTime() or nil
end
local function PartEnd(name, startedAt)
	if startedAt ~= nil then
		PerfParts.Part(name, RealTime() - startedAt)
	end
end
local bot = GetBot()
local botName = bot:GetUnitName()
if bot == nil or bot:IsInvulnerable() or not bot:IsHero() or not string.find(botName, "hero") or bot:IsIllusion() then
	return
end
if not bot.frameProcessTime then
	bot.frameProcessTime = 0.1
end
local team = GetTeam()
local alwaysTrue = 10 == 10
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
-- Logs switched off once their feature works (the TP diag lines, game 029).
local function NoLog() end
local Utils = require(GetScriptDirectory() .. "/FuncLib/systems/utils")
local BotBuild = dofile(GetScriptDirectory() .. "/BotsLib/" .. string.gsub(botName, "npc_dota_", ""))
local Localization = require(GetScriptDirectory() .. "/FuncLib/systems/localization")
local CustomLoader = require(GetScriptDirectory() .. "/FuncLib/systems/custom_loader")
local MatchTrace = require(GetScriptDirectory() .. "/FuncLib/systems/match_trace")
local TeamMemory = require(GetScriptDirectory() .. "/FuncLib/systems/team_memory")
local ChargeTracker = require(GetScriptDirectory() .. "/FuncLib/systems/charge_tracker")
local AbilityContext = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local SpecialUnits = require(GetScriptDirectory() .. "/FuncLib/hero/special_units")
CustomLoader.ThinkLess = CustomLoader.Enable and CustomLoader.ThinkLess or 1
local lastHumanPingTime = -1
local function LogHumanPing()
	local myId = bot:GetPlayerID()
	local loggerId = nil
	-- GetTeamMember takes a team slot (1-5), not a player ID (game 037 review).
	for slot = 1, #GetTeamPlayers(GetTeam()) do
		local member = GetTeamMember(slot)
		if member ~= nil and member:IsBot() and not member:IsIllusion() and member:IsAlive() then
			local id = member:GetPlayerID()
			if loggerId == nil or id < loggerId then
				loggerId = id
			end
		end
	end
	if loggerId ~= myId then
		return
	end
	local human, ping = Utils.GetHumanPing()
	if human == nil or ping == nil or ping.location == nil or ping.time == nil or ping.time == 0 then
		return
	end
	if ping.time == lastHumanPingTime or GameTime() - ping.time > 1.5 then
		lastHumanPingTime = ping.time
		return
	end
	lastHumanPingTime = ping.time
	local loc = ping.location
	print(
		string.format(
			"[OHA-PING] %.0f %.0f %.0f normal=%s t=%.1f",
			loc.x,
			loc.y,
			loc.z or 0,
			tostring(ping.normal_ping),
			DotaTime()
		)
	)
end
-- When already attacking a valid target and not in danger, skip heavy item/ability
-- rescans for ~3 engine frames * ThinkLess (DotaTime-based, not wall clock).
local THINK_SAMPLE_FRAME = 0.033
local function ShouldThrottleHeavyThink()
	local thinkLess = tonumber(CustomLoader.ThinkLess) or 1
	if thinkLess <= 0 then
		return false
	end
	local now = DotaTime()
	local tgt = bot:GetAttackTarget()
	local locked = tgt ~= nil
		and not tgt:IsNull()
		and tgt:IsAlive()
		and not tgt:IsInvulnerable()
		and GetUnitToUnitDistance(bot, tgt) <= 1600
	local urgent = not locked
		or bot:GetHealth() / math.max(1, bot:GetMaxHealth()) < 0.45
		or bot:WasRecentlyDamagedByAnyHero(1.2)
		or bot:WasRecentlyDamagedByTower(1.2)
		or bot:WasRecentlyDamagedByCreep(1.0)
	-- Urgent / no target: every tick. Locked & safe: every ~3 ticks * ThinkLess.
	local interval = urgent and 0 or (THINK_SAMPLE_FRAME * 3 * math.max(1, thinkLess))
	local last = bot._ohaHeavyThinkAt or -100
	if now - last < interval then
		return true
	end
	bot._ohaHeavyThinkAt = now
	return false
end
local hasDispel, Dispel = pcall(require, GetScriptDirectory() .. "/FuncLib/systems/dispel")
if not hasDispel then
	Dispel = nil
end
if GAMEMODE_TURBO == nil then
	GAMEMODE_TURBO = 23
end
if GAMEMODE_ARDM == nil then
	GAMEMODE_ARDM = 20
end
if BotBuild == nil then
	log("[ERROR] BotBuild is nil for %s - hero file failed to load. No items/abilities.", botName)
	return
end
local useDefaultItem = BotBuild["bDeafaultItem"]
local abilityLevelUpList = BotBuild["sSkillList"]
local radiantFountain = Vector(-6619, -6336, 384)
local direFountain = Vector(6928, 6372, 392)
local pendingArdmReload = false
local lastPosition = nil
local kezSwappedAbility = {
	["kez_echo_slash"] = "kez_falcon_rush",
	["kez_falcon_rush"] = "kez_echo_slash",
	["kez_grappling_claw"] = "kez_talon_toss",
	["kez_talon_toss"] = "kez_grappling_claw",
	["kez_kazurai_katana"] = "kez_shodo_sai",
	["kez_shodo_sai"] = "kez_kazurai_katana",
	["kez_raptor_dance"] = "kez_ravens_veil",
	["kez_ravens_veil"] = "kez_raptor_dance",
}
local function ReloadBotBuild(reason)
	local heroFile = string.gsub(botName, "npc_dota_", "")
	log("[Reload] %s for %s, loading BotsLib/%s", reason, botName, heroFile)
	local loaded, build = pcall(dofile, GetScriptDirectory() .. "/BotsLib/" .. heroFile)
	if loaded and build ~= nil then
		BotBuild = build
		useDefaultItem = BotBuild["bDeafaultItem"]
		if build["sSkillList"] ~= nil and #build["sSkillList"] > 0 then
			local fullSkillList = build["sSkillList"]
			local level = bot:GetLevel()
			local pointsSpent = level - bot:GetAbilityPoints()
			local remainingSkills = {}
			for i = pointsSpent + 1, #fullSkillList do
				table.insert(remainingSkills, fullSkillList[i])
			end
			if #remainingSkills > 0 then
				abilityLevelUpList = remainingSkills
			else
				abilityLevelUpList =
					Fu.Utils.CombineTablesUnique(Fu.Skill.GetTalentList(bot), Fu.Skill.GetAbilityList(bot))
			end
			log("[Reload] Skill list: %s entries remaining (spent %s points)", #abilityLevelUpList, pointsSpent)
		end
	else
		log("[Reload] dofile FAILED for %s: %s", heroFile, build)
	end
end
local function CheckArdmHeroSwap()
	local isStale, currentBot, currentName = Fu.IsStaleARDMHero(bot, botName)
	if isStale then
		log("[ARDM] Stale ability script: this=%s, current=%s", botName, currentName)
		return true
	end
	if currentName ~= botName then
		log("[ARDM] Hero swap detected: %s -> %s", botName, currentName)
		bot = currentBot
		botName = currentName
		pendingArdmReload = true
	elseif currentBot ~= bot then
		bot = currentBot
	end
	if pendingArdmReload and bot:IsAlive() then
		pendingArdmReload = false
		local heroFile = string.gsub(botName, "npc_dota_", "")
		log("[ARDM] Loading BotsLib/%s.lua for %s", heroFile, botName)
		local loaded, build = pcall(dofile, GetScriptDirectory() .. "/BotsLib/" .. heroFile)
		if not loaded then
			log("[ARDM] dofile FAILED for %s: %s", heroFile, build)
		end
		if loaded and build ~= nil and build["sSkillList"] ~= nil and #build["sSkillList"] > 0 then
			BotBuild = build
			useDefaultItem = BotBuild["bDeafaultItem"]
			abilityLevelUpList = BotBuild["sSkillList"]
			log(
				"[ARDM] Loaded BotsLib for %s with %s skill entries, first: %s",
				botName,
				#abilityLevelUpList,
				abilityLevelUpList[1]
			)
		else
			local abilityList = Fu.Skill.GetAbilityList(bot)
			local talentList = Fu.Skill.GetTalentList(bot)
			log(
				"[ARDM] BotsLib load failed or empty for %s, abilities: %s, talents: %s",
				botName,
				#abilityList,
				#talentList
			)
			if #abilityList > 0 then
				BotBuild = nil
				useDefaultItem = false
				abilityLevelUpList = Fu.Utils.CombineTablesUnique(talentList, abilityList)
				log("[ARDM] Using generic build for %s with %s entries", botName, #abilityLevelUpList)
			else
				log("[ARDM] Abilities not ready for %s, retrying next frame", botName)
				pendingArdmReload = true
			end
		end
	elseif pendingArdmReload and not bot:IsAlive() then
		log("[ARDM] Waiting for %s to respawn", botName)
	end
	return false
end
local function LevelUpAbilities()
	if GetGameState() ~= GAME_STATE_PRE_GAME and GetGameState() ~= GAME_STATE_GAME_IN_PROGRESS then
		return
	end
	if Fu.CanNotUseAbility(bot) then
		return
	end
	local position = Fu.GetPosition(bot)
	if lastPosition == nil then
		lastPosition = position
		if
			bot.isBear == nil
			and GetGameMode() ~= GAMEMODE_1V1MID
			and GetGameState() == GAME_STATE_PRE_GAME
			and bot.announcedRole ~= position
		then
			pcall(function()
				bot:ActionImmediate_Chat(Localization.Get("say_play_pos") .. tostring(position), false)
				bot.announcedRole = position
			end)
		end
	elseif position ~= lastPosition then
		log("[PosSwap] %s position changed: pos%s -> pos%s", botName, lastPosition, position)
		lastPosition = position
		ReloadBotBuild("Position swap to pos" .. position)
		bot.needPurchaseRebuild = true
		if bot.isBear == nil and bot.announcedRole ~= position then
			pcall(function()
				bot:ActionImmediate_Chat(Localization.Get("say_play_pos") .. tostring(position), false)
				bot.announcedRole = position
			end)
		end
	end
	if bot:GetLevel() >= 30 and botName == "npc_dota_hero_bloodseeker" then
		return
	end
	if DotaTime() < 15 then
		bot.theRole = Fu.Role.GetCurrentSuitableRole(bot, botName)
	end
	local botLocation = bot:GetLocation()
	if
		bot:IsAlive()
		and DotaTime() > 90
		and bot:GetCurrentActionType() == BOT_ACTION_TYPE_MOVE_TO
		and not IsLocationPassable(botLocation)
	then
		if bot.stuckLoc == nil then
			bot.stuckLoc = botLocation
			bot.stuckTime = DotaTime()
		elseif bot.stuckLoc ~= botLocation then
			bot.stuckLoc = botLocation
			bot.stuckTime = DotaTime()
		end
	else
		bot.stuckTime = nil
		bot.stuckLoc = nil
	end
	local level = bot:GetLevel()
	if GetGameMode() == GAMEMODE_ARDM and bot:GetAbilityPoints() > 0 then
		if #abilityLevelUpList > 0 then
			log(
				"[ARDM] %s Lv%s has %s ability points, skill list has %s entries, next: %s",
				botName,
				level,
				bot:GetAbilityPoints(),
				#abilityLevelUpList,
				abilityLevelUpList[1]
			)
		else
			log(
				"[ARDM] %s Lv%s has %s ability points, skill list has %s entries",
				botName,
				level,
				bot:GetAbilityPoints(),
				#abilityLevelUpList
			)
		end
	end
	if #abilityLevelUpList >= 1 and bot:GetAbilityPoints() > 0 then
		if Fu.IsTryingtoUseAbility(bot) then
			return
		end
		local abilityName = abilityLevelUpList[1]
		if abilityName == nil then
			log("[WARN] Nil entry in sAbilityLevelUpList for %s, removing", botName)
			table.remove(abilityLevelUpList, 1)
			return
		end
		local ability = bot:GetAbilityByName(abilityName)
		if ability == nil and GetGameMode() == GAMEMODE_ARDM then
			local abilityList = Fu.Skill.GetAbilityList(bot)
			local talentList = Fu.Skill.GetTalentList(bot)
			if #abilityList >= 3 then
				log(
					"[ARDM] Ability '%s' not found on %s, rebuilding skill list (abilities: %s, talents: %s)",
					abilityName,
					botName,
					#abilityList,
					#talentList
				)
				abilityLevelUpList = Fu.Utils.CombineTablesUnique(talentList, abilityList)
				return
			else
				log("[ARDM] Abilities not ready for %s (%s), waiting", botName, #abilityList)
				return
			end
		end
		if ability ~= nil and ability:IsHidden() then
			local swappedName = kezSwappedAbility[abilityName]
			if swappedName then
				local swappedAbility = bot:GetAbilityByName(swappedName)
				if swappedAbility ~= nil and not swappedAbility:IsHidden() then
					ability = swappedAbility
					abilityName = swappedName
				end
			end
		end
		if abilityName == "phoenix_fire_spirits" then
			local launchFireSpirit = bot:GetAbilityByName("phoenix_launch_fire_spirit")
			if launchFireSpirit ~= nil and not launchFireSpirit:IsHidden() then
				return
			end
		end
		if abilityName == "alchemist_unstable_concoction" then
			local concoctionThrow = bot:GetAbilityByName("alchemist_unstable_concoction_throw")
			if concoctionThrow ~= nil and not concoctionThrow:IsHidden() then
				return
			end
		end
		if ability == nil then
			log("[WARN] Ability %s not found on %s, skipping", abilityName, botName)
			table.remove(abilityLevelUpList, 1)
			return
		end
		-- The server rejects a train order for anything the hero cannot learn right now
		-- ("Ability is not owned by specified unit"). Only send one that will land.
		local function CanLearn(candidate)
			return candidate ~= nil
				and not candidate:IsNull()
				and not candidate:IsHidden()
				and candidate:GetName() ~= "generic_hidden"
				and not Utils.AbilityBehaviorHasFlag(candidate:GetBehavior(), DOTA_ABILITY_BEHAVIOR_NOT_LEARNABLE or 64)
				and candidate:CanAbilityBeUpgraded()
				and candidate:GetLevel() < candidate:GetMaxLevel()
				and level >= candidate:GetHeroLevelRequiredToUpgrade()
		end
		local function FallbackAbility()
			local best = nil
			for slot = 0, 25 do
				local candidate = bot:GetAbilityInSlot(slot)
				if CanLearn(candidate) then
					if candidate:IsUltimate() then
						return candidate
					end
					if
						not candidate:IsTalent()
						and (best == nil or best:IsTalent() or candidate:GetLevel() < best:GetLevel())
					then
						best = candidate
					elseif best == nil then
						best = candidate
					end
				end
			end
			return best
		end
		if CanLearn(ability) then
			bot:ActionImmediate_LevelAbility(ability:GetName())
			table.remove(abilityLevelUpList, 1)
		elseif
			abilityName == "generic_hidden"
			or ability:IsHidden() and level >= 25
			or Utils.AbilityBehaviorHasFlag(ability:GetBehavior(), DOTA_ABILITY_BEHAVIOR_NOT_LEARNABLE or 64)
			or ability:GetLevel() >= ability:GetMaxLevel()
		then
			-- This entry can never be learned. Spend the point on something that can.
			table.remove(abilityLevelUpList, 1)
			local fallback = FallbackAbility()
			log(
				"[WARN] %s cannot learn %s, using %s instead",
				botName,
				abilityName,
				fallback and fallback:GetName() or "nothing"
			)
			if fallback ~= nil then
				bot:ActionImmediate_LevelAbility(fallback:GetName())
			end
		elseif not ability:IsHidden() and level >= ability:GetHeroLevelRequiredToUpgrade() then
			table.remove(abilityLevelUpList, 1)
			local fallback = FallbackAbility()
			log(
				"[WARN] %s cannot upgrade %s now, using %s instead",
				botName,
				abilityName,
				fallback and fallback:GetName() or "nothing"
			)
			if fallback ~= nil then
				bot:ActionImmediate_LevelAbility(fallback:GetName())
			end
		else
			log("[WARN] Skipped to level up ability %s for %s for this time because it may fail.", abilityName, botName)
			if level > 25 then
				log("[WARN] Ignore ability %s for %s because it may always fail.", abilityName, botName)
				table.remove(abilityLevelUpList, 1)
			end
		end
	end
	if level > 25 and level < 30 and bot:GetAbilityPoints() >= 1 and #abilityLevelUpList <= 3 then
		abilityLevelUpList = Fu.Utils.CombineTablesUnique(Fu.Skill.GetTalentList(bot), Fu.Skill.GetAbilityList(bot))
	end
	if GetGameMode() == GAMEMODE_ARDM and #abilityLevelUpList == 0 and bot:GetAbilityPoints() > 0 then
		log(
			"[ARDM] Skill list exhausted for %s at Lv%s with %s points, rebuilding",
			botName,
			level,
			bot:GetAbilityPoints()
		)
		abilityLevelUpList = Fu.Utils.CombineTablesUnique(Fu.Skill.GetTalentList(bot), Fu.Skill.GetAbilityList(bot))
	end
end
function Usage.GetLaneByPosition(unit)
	if IsLanMode and IsLanMode() then
		local assignedLane = unit:GetAssignedLane()
		if assignedLane == LANE_TOP or assignedLane == LANE_MID or assignedLane == LANE_BOT then
			return assignedLane
		end
	end
	local position = Fu.GetPosition(unit)
	if GetTeam() == TEAM_RADIANT then
		if position == 1 then
			return LANE_BOT
		elseif position == 2 then
			return LANE_MID
		elseif position == 3 or position == 4 then
			return LANE_TOP
		elseif position == 5 then
			return LANE_BOT
		end
	else
		if position == 1 then
			return LANE_TOP
		elseif position == 2 then
			return LANE_MID
		elseif position == 3 or position == 4 then
			return LANE_BOT
		elseif position == 5 then
			return LANE_TOP
		end
	end
	return unit:GetAssignedLane() or LANE_MID
end
function Usage.GetNumEnemyNearby(unit)
	local count = 0
	for _, playerId in pairs(GetTeamPlayers(GetOpposingTeam())) do
		if IsHeroAlive(playerId) then
			local lastSeenInfo = GetHeroLastSeenInfo(playerId)
			if lastSeenInfo ~= nil then
				local seen = lastSeenInfo[1]
				if
					seen ~= nil
					and GetUnitToLocationDistance(unit, seen.location) <= 3000
					and seen.time_since_seen < 1.0
				then
					count = count + 1
				end
			end
		end
	end
	return count
end
local deathTime = 0
function Usage.GetRemainingRespawnTime()
	if deathTime == 0 then
		return 0
	else
		return bot:GetRespawnTime() - (DotaTime() - deathTime)
	end
end
local sayEndDeathThreshold = RandomInt(14, 20)
local chatReplyDelay = RandomInt(19, 56) / 10
local killStreakEndedTime = -999
local lastGold = 9999
local lastKills = 999
local lastDeaths = 0
local killStreak = 0
local replyCount = 0
local maxReplies = RandomInt(5, 9)
local chatCallbackInstalled = false
local humanChatTime = nil
local humanChatString = nil
local replyToAllChat = false
function Usage.SetTalkMessage()
	local playerId = bot:GetPlayerID()
	local gold = bot:GetGold()
	local kills = GetHeroKills(playerId)
	local deaths = GetHeroDeaths(playerId)
	local turboGoldScale = GetGameMode() == GAMEMODE_TURBO and 2.0 or 1.0
	if playerId == Fu.Role.GetReplyMemberID() and replyCount <= maxReplies then
		if not chatCallbackInstalled and GetGameState() == GAME_STATE_GAME_IN_PROGRESS then
			chatCallbackInstalled = true
			InstallChatCallback(function(chatEvent)
				Usage.SetReplyHumanTime(chatEvent)
			end)
		end
		if humanChatString ~= nil and humanChatTime ~= nil and DotaTime() > humanChatTime + chatReplyDelay then
			local replyString = Fu.Chat.GetReplyString(humanChatString, replyToAllChat)
			if replyString ~= nil then
				if replyCount == maxReplies then
					replyString = Fu.Chat.GetStopReplyString()
				end
				bot:ActionImmediate_Chat(replyString, replyToAllChat)
				replyCount = replyCount + 1
				chatReplyDelay = RandomInt(6, 30) / 10
				if chatReplyDelay > 2.0 then
					chatReplyDelay = RandomInt(6, 30) / 10
				end
			end
			humanChatString = nil
			humanChatTime = nil
		end
	end
	-- One chat per player: every Meepo body (and Arc Warden's Tempest Double) runs this with its own kill count, and
	-- each rolled its own line (game 043: Meepo said "mostly vici" and "?" for one kill, #8).
	if
		Fu.Customize.Allow_Trash_Talk
		and not Fu.IsMeepoClone(bot)
		and not bot:HasModifier("modifier_arc_warden_tempest_double")
	then
		if
			DotaTime() < 600
			and bot:IsAlive()
			and kills > lastKills
			and Fu.GetNumOfTeamTotalKills(false) == 1
			and Fu.GetNumOfTeamTotalKills(true) == 0
			and RandomInt(1, 9) > 4
		then
			local chatLine = Localization.Get("got_first_blood")[RandomInt(1, #Localization.Get("got_first_blood"))]
			bot:ActionImmediate_Chat(chatLine, true)
		end
		if bot:IsAlive() and gold > lastGold + 300 * turboGoldScale and kills > lastKills then
			local chatLine = "?"
			if Fu.Customize.Trash_Talk_Level and Fu.Customize.Trash_Talk_Level >= 2 then
				-- A normal kill: one of our lines 3 times in 4, "?" once in 4 (#90; it was 2 in 9).
				if RandomInt(1, 4) > 1 then
					chatLine = Localization.Get("got_a_kill")[RandomInt(1, #Localization.Get("got_a_kill"))]
				end
				if gold > lastGold + 800 * turboGoldScale and RandomInt(1, 9) > 4 then
					chatLine = Localization.Get("got_big_kill")[RandomInt(1, #Localization.Get("got_big_kill"))]
				end
				if gold > lastGold + 1000 * turboGoldScale and RandomInt(1, 9) > 3 then
					chatLine = Localization.Get("got_big_kill_2")[RandomInt(1, #Localization.Get("got_big_kill_2"))]
				end
				if gold > lastGold + 1500 * turboGoldScale then
					chatLine = Localization.Get("got_big_kill_3")[RandomInt(1, #Localization.Get("got_big_kill_3"))]
				end
			end
			if RandomInt(1, 9) > 4 then
				bot:ActionImmediate_Chat(chatLine, true)
			end
		end
		if not bot:IsAlive() then
			if killStreak >= 8 and killStreakEndedTime == -999 then
				killStreakEndedTime = DotaTime()
				killStreak = 0
			end
			if killStreakEndedTime ~= -999 and killStreakEndedTime < DotaTime() - chatReplyDelay then
				bot:ActionImmediate_Chat(
					Localization.Get("kill_streak_ended")[RandomInt(1, #Localization.Get("kill_streak_ended"))],
					true
				)
				killStreakEndedTime = -999
				chatReplyDelay = RandomInt(36, 49) / 10
			end
		end
		if kills == 0 and deaths >= sayEndDeathThreshold and Fu.Role.NotSayJiDi() then
			bot:ActionImmediate_Chat(Localization.Get("say_end")[RandomInt(1, #Localization.Get("say_end"))], true)
			Fu.Role["sayJiDi"] = true
		end
	end
	if lastDeaths == deaths then
		if kills >= lastKills + 1 then
			killStreak = killStreak + 1
		end
	else
		killStreak = 0
	end
	lastKills = GetHeroKills(playerId)
	lastDeaths = GetHeroDeaths(playerId)
	lastGold = bot:GetGold()
end
function Usage.SetReplyHumanTime(chatEvent)
	local chatText = chatEvent.string
	local senderPlayerId = chatEvent.player_id
	if string.find(chatText, "!sp") or string.find(chatText, "!speak") then
		local command, language = Fu.Utils.TrimString(chatText):match("^(%S+)%s+(.*)$")
		log("Set to speak: %s", language)
		Fu.Customize.Localization = language
		return
	end
	local chatCommand = Fu.Utils.TrimString(chatText or ""):lower()
	if chatCommand == "!debug" or chatCommand == "!verbose" then
		if not IsPlayerBot(senderPlayerId) and (chatEvent.team_only or Fu.Role.IsAllyMemberID(senderPlayerId)) then
			Fu.Utils.DebugMode = not Fu.Utils.DebugMode
			IsDebug = Fu.Utils.DebugMode
			Fu.Utils.GameStates = Fu.Utils.GameStates or {}
			Fu.Utils.GameStates.verboseChat = Fu.Utils.DebugMode
			local debugReply = Fu.Utils.DebugMode and Localization.Get("say_debug_on")
				or Localization.Get("say_debug_off")
			if type(debugReply) == "table" and #debugReply > 0 then
				debugReply = debugReply[RandomInt(1, #debugReply)]
			end
			bot:ActionImmediate_Chat(
				debugReply or (Fu.Utils.DebugMode and "Verbose debug ON." or "Verbose debug OFF."),
				false
			)
		end
		return
	end
	if chatText ~= "-都来守家" or Fu.Role.IsAllyMemberID(senderPlayerId) then
		Fu.Role.SetLastChatString(chatText)
	end
	if not IsPlayerBot(senderPlayerId) and (chatEvent.team_only or Fu.Role.IsEnemyMemberID(senderPlayerId)) then
		humanChatString = chatText
		humanChatTime = DotaTime()
		replyToAllChat = not chatEvent.team_only
	end
end
-- [OHA-BUYBACK]: every buyback with its reason, and a support's skipped one (once per 10s).
local function BuybackLog(what, why, ancientHp, remaining)
	pcall(
		print,
		string.format(
			"[OHA-BUYBACK] t=%.0f %s %s why=%s pos=%d anc=%.2f remaining=%.0f gold=%d",
			DotaTime(),
			(string.gsub(bot:GetUnitName(), "npc_dota_hero_", "")),
			what,
			why,
			Fu.GetPosition(bot),
			ancientHp,
			remaining,
			bot:GetGold()
		)
	)
end
local function BuybackNow(why, ancientHp, remaining)
	Fu.Role["lastbbtime"] = DotaTime()
	BuybackLog("buyback", why, ancientHp, remaining)
	bot:ActionImmediate_Buyback()
end
local function BuybackSkipLog(why, ancientHp, remaining)
	if DotaTime() < (bot._buybackSkipLogAt or -99) + 10 then
		return
	end
	bot._buybackSkipLogAt = DotaTime()
	BuybackLog("skip", why, ancientHp, remaining)
end
local function ConsiderBuyback()
	if Fu.IsMeepoClone(bot) then
		return
	end
	Usage.SetTalkMessage()
	if bot:GetLevel() <= 15 or bot:HasModifier("modifier_arc_warden_tempest_double") or not Fu.Role.ShouldBuyBack() then
		return
	end
	if bot:IsAlive() and deathTime ~= 0 then
		deathTime = 0
	end
	if not bot:IsAlive() then
		if deathTime == 0 then
			deathTime = DotaTime()
		end
	end
	if bot:IsAlive() then
		return
	end
	if not bot:HasBuyback() then
		return
	end
	local ancient = GetAncient(GetTeam())
	local respawnTime = bot:GetRespawnTime()
	local remainingRespawnTime = Usage.GetRemainingRespawnTime()
	local ancientHp = ancient ~= nil and Fu.GetHP(ancient) or 1
	-- Game 037: this compared the Ancient's absolute HP with 0.8 and a table with 0, so it never fired.
	-- Fu.GetEnemiesAroundLoc returns a threat score, not a count.
	if ancient ~= nil and ancientHp < 0.8 then
		local enemiesNearAncient = Fu.GetEnemiesAroundLoc(ancient:GetLocation(), 1500)
		local alliesNearAncient = Fu.GetAlliesNearLoc(ancient:GetLocation(), 1500)
		if enemiesNearAncient > 1 and #alliesNearAncient == 0 and remainingRespawnTime > 20 then
			BuybackNow("ancient-hp", ancientHp, remainingRespawnTime)
			return
		end
	end
	if respawnTime < 45 then
		return
	end
	local wantWhy = nil
	if bot:GetLevel() > 24 and remainingRespawnTime > 80 and Fu.GetTeamFightLocation(bot) ~= nil then
		wantWhy = "teamfight"
	end
	if wantWhy == nil and remainingRespawnTime >= 40 and ancient ~= nil then
		local enemyCountNearAncient = Usage.GetNumEnemyNearby(ancient)
		local aliveAllyCount = Fu.GetNumOfAliveHeroes(false)
		if enemyCountNearAncient > 0 and enemyCountNearAncient >= aliveAllyCount then
			wantWhy = "enemies-at-base"
		end
	end
	if wantWhy == nil then
		return
	end
	-- Game 037: Lion (pos 5) bought back with five Dire on our high ground and died again 39s later. A
	-- support buys back only for an Ancient defense (the Ancient hurt with enemies at it) or into a
	-- fight we are winning (more allies than enemies at the team fight).
	if Fu.GetPosition(bot) >= 4 then
		local supportWhy = nil
		if ancient ~= nil and ancientHp < 0.8 and #Fu.GetEnemiesNearLoc(ancient:GetLocation(), 1600) > 0 then
			supportWhy = "ancient-defense"
		else
			local fightLocation = Fu.GetTeamFightLocation(bot)
			if
				fightLocation ~= nil
				and #Fu.GetAlliesNearLoc(fightLocation, 1600) > #Fu.GetEnemiesNearLoc(fightLocation, 1600)
			then
				supportWhy = "won-fight"
			end
		end
		if supportWhy == nil then
			BuybackSkipLog("support-" .. wantWhy, ancientHp, remainingRespawnTime)
			return
		end
		wantWhy = wantWhy .. "+" .. supportWhy
	end
	BuybackNow(wantWhy, ancientHp, remainingRespawnTime)
end
local lastCourierActionTime = -90
local courierState = -1
bot.SShopUser = false
local lastCourierReturnTime = -90
local lastCourierBurstTime = -90
local function ManageCourier()
	if
		DotaTime() < -56
		or bot:HasModifier("modifier_arc_warden_tempest_double")
		or lastCourierReturnTime + 5.0 > DotaTime()
	then
		return
	end
	if bot.theCourier == nil then
		bot.theCourier = Usage.GetBotCourier(bot)
		return
	end
	local reportEnabled = 10 == 10
	local courier = bot.theCourier
	courierState = GetCourierState(courier)
	local courierHpRatio = courier:GetHealth() / courier:GetMaxHealth()
	local now = DotaTime()
	local isAlive = bot:IsAlive()
	local botLevel = bot:GetLevel()
	local deliverCooldown = 2.3
	local returnCooldown = 5.0
	if courierState == COURIER_STATE_DEAD then
		return
	end
	if Usage.IsCourierTargetedByUnit(courier) then
		if now > lastCourierReturnTime + returnCooldown then
			lastCourierReturnTime = now
			Fu.SetReportMotive(reportEnabled, "信使可能会被攻击")
			bot:ActionImmediate_Courier(courier, COURIER_ACTION_RETURN_STASH_ITEMS)
			local courierBurst = courier:GetAbilityByName("courier_burst")
			if courierBurst and courierBurst:IsFullyCastable() then
				bot:ActionImmediate_Courier(courier, COURIER_ACTION_BURST)
			end
			return
		end
	end
	if bot.SShopUser and (not isAlive or bot:GetActiveMode() == BOT_MODE_SECRET_SHOP or not bot.SecretShop) then
		bot.SShopUser = false
		Fu.SetReportMotive(reportEnabled, "让信使返回基地避免被卡住")
		bot:ActionImmediate_Courier(courier, COURIER_ACTION_RETURN_STASH_ITEMS)
		return
	end
	if
		(
			courierState == COURIER_STATE_RETURNING_TO_BASE
			or courierState == COURIER_STATE_AT_BASE
			or courierState == COURIER_STATE_IDLE
		) and now > lastCourierReturnTime + returnCooldown
	then
		if courierState == COURIER_STATE_AT_BASE and courierHpRatio < 0.8 then
			return
		end
		if courierState == COURIER_STATE_IDLE and courier:DistanceFromFountain() > 800 then
			Fu.SetReportMotive(reportEnabled, "让空闲的信使返回")
			bot:ActionImmediate_Courier(courier, COURIER_ACTION_RETURN_STASH_ITEMS)
			return
		end
		-- Before 0:20 stash items wait, except wards: supports buy them at -60s (after the
		-- human's 30s on fresh stock) wherever they are, and the courier brings them out.
		if
			isAlive
			and now < 20
			and (
				courierState == COURIER_STATE_AT_BASE
				or courierState == COURIER_STATE_IDLE and courier:DistanceFromFountain() < 800
			)
		then
			local wardInStash = false
			for slot = 9, 14 do
				local stashItem = bot:GetItemInSlot(slot)
				local stashItemName = stashItem ~= nil and stashItem:GetName() or ""
				if
					stashItemName == "item_ward_observer"
					or stashItemName == "item_ward_sentry"
					or stashItemName == "item_ward_dispenser"
				then
					wardInStash = true
					break
				end
			end
			if wardInStash then
				pcall(Usage.LogCourier, "take")
				bot:ActionImmediate_Courier(courier, COURIER_ACTION_TAKE_STASH_ITEMS)
				lastCourierActionTime = now
				return
			end
			if bot:GetCourierValue() > 0 and now > lastCourierActionTime + deliverCooldown then
				pcall(Usage.LogCourier, "deliver")
				bot:ActionImmediate_Courier(courier, COURIER_ACTION_TRANSFER_ITEMS)
				lastCourierActionTime = now
				return
			end
		end
		if
			isAlive
			and (not Usage.IsInvFull(bot) or now <= 5 * 60 or bot.currBuyingBasicItemList ~= nil and #bot.currBuyingBasicItemList == 0 and bot.currBuyingItemInPurchaseList ~= "item_travel_boots")
			and (
				courierState == COURIER_STATE_AT_BASE
				or courierState == COURIER_STATE_IDLE and courier:DistanceFromFountain() < 800
			)
		then
			local stashItemCount = Usage.GetNumStashItem(bot)
			if stashItemCount > 0 and now >= 20 then
				if
					bot.currBuyingBasicItemList ~= nil and #bot.currBuyingBasicItemList == 0
					or bot.currBuyingBasicItem ~= nil
						and (IsItemPurchasedFromSecretShop(bot.currBuyingBasicItem) or Usage.GetNumStashItem(bot) == 6 or bot:GetGold() + 80 < GetItemCost(
							bot.currBuyingBasicItem
						))
				then
					Fu.SetReportMotive(reportEnabled, "信使取出物品并开始运输")
					pcall(Usage.LogCourier, "take")
					bot:ActionImmediate_Courier(courier, COURIER_ACTION_TAKE_STASH_ITEMS)
					lastCourierActionTime = now
					if now > lastCourierBurstTime + returnCooldown then
						lastCourierBurstTime = now
						local courierBurst = courier:GetAbilityByName("courier_burst")
						if courierBurst and courierBurst:IsFullyCastable() then
							Fu.SetReportMotive(reportEnabled, "信使加速配送")
							bot:ActionImmediate_Courier(courier, COURIER_ACTION_BURST)
						end
					end
				end
			end
		end
		if
			isAlive
			and bot.SecretShop
			and courier:DistanceFromFountain() < 7000
			and Fu.Item.GetEmptyInventoryAmount(courier) >= 2
			and not Usage.IsEnemyHeroAroundSecretShop()
			and now > lastCourierActionTime + deliverCooldown
		then
			Fu.SetReportMotive(reportEnabled, "信使前往神秘商店购物")
			bot:ActionImmediate_Courier(courier, COURIER_ACTION_SECRET_SHOP)
			bot.SShopUser = true
			lastCourierActionTime = now
			return
		end
		if
			isAlive
			and now >= 20
			and bot:GetCourierValue() > 0
			and bot:GetStashValue() < 100
			and (not Usage.IsInvFull(bot) or Usage.GetNumStashItem(bot) == 0 and bot.currBuyingBasicItemList ~= nil and #bot.currBuyingBasicItemList == 0)
			and (courier:DistanceFromFountain() < 4000 + botLevel * 200 or GetUnitToUnitDistance(bot, courier) < 1800)
			and now > lastCourierActionTime + deliverCooldown
		then
			Fu.SetReportMotive(reportEnabled, "信使运输背包中的东西")
			pcall(Usage.LogCourier, "deliver")
			bot:ActionImmediate_Courier(courier, COURIER_ACTION_TRANSFER_ITEMS)
			lastCourierActionTime = now
			return
		end
	end
end
function Usage.GetBotCourier(hero)
	local playerId = hero:GetPlayerID()
	for playerIndex = 0, 4 do
		local courier = GetCourier(playerIndex)
		if courier:GetPlayerID() == playerId then
			return courier
		end
	end
end
function Usage.GetNumStashItem(hero)
	local stashItemCount = 0
	for slot = 9, 14 do
		if hero:GetItemInSlot(slot) ~= nil then
			stashItemCount = stashItemCount + 1
		end
	end
	return stashItemCount
end
function Usage.IsThereRecipeInStash(hero)
	local recipeCount = 0
	for slot = 9, 14 do
		local item = hero:GetItemInSlot(slot)
		if item ~= nil then
			if string.find(item:GetName(), "item_recipe_") then
				recipeCount = recipeCount + 1
			end
		end
	end
	return recipeCount > 0
end
function Usage.IsCourierTargetedByUnit(courier)
	if GetGameMode() == GAMEMODE_TURBO then
		return false
	end
	local botLevel = bot:GetLevel()
	if Fu.GetHP(courier) < 0.9 then
		return true
	end
	if courier:DistanceFromFountain() < 900 then
		return false
	end
	for towerIndex = 0, 10 do
		local tower = GetTower(GetOpposingTeam(), towerIndex)
		if tower ~= nil and tower:CanBeSeen() then
			local towerTarget = tower:GetAttackTarget()
			if towerTarget == courier then
				return true
			end
			if towerTarget == nil and GetUnitToUnitDistance(courier, tower) < 999 then
				return true
			end
		end
	end
	for _, playerId in pairs(GetTeamPlayers(GetOpposingTeam())) do
		if IsHeroAlive(playerId) then
			local lastSeenInfo = GetHeroLastSeenInfo(playerId)
			if lastSeenInfo ~= nil then
				local lastSeen = lastSeenInfo[1]
				if
					lastSeen ~= nil
					and GetUnitToLocationDistance(courier, lastSeen.location) <= 800
					and lastSeen.time_since_seen < 1.8
				then
					return true
				end
			end
		end
	end
	local enemyHeroList = GetUnitList(UNIT_LIST_ENEMY_HEROES)
	for _, enemy in pairs(enemyHeroList) do
		if GetUnitToUnitDistance(enemy, courier) <= 700 + botLevel * 15 then
			local alliesNearEnemy = Fu.GetAlliesNearLoc(enemy:GetLocation(), 600)
			if #alliesNearEnemy == 0 or enemy:GetAttackTarget() == courier then
				return true
			end
		end
		if
			enemy:GetUnitName() == "npc_dota_hero_sniper"
			and GetUnitToUnitDistance(enemy, courier) <= 1100 + botLevel * 30
		then
			return true
		end
		if GetUnitToUnitDistance(enemy, courier) <= enemy:GetAttackRange() + 88 then
			return true
		end
	end
	local enemyHeroes = Fu.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE)
	for _, enemy in pairs(enemyHeroes) do
		if enemy ~= nil and Fu.IsValidHero(enemy) and GetUnitToUnitDistance(enemy, courier) <= 700 + botLevel * 15 then
			local alliesNearEnemy = Fu.GetAlliesNearLoc(enemy:GetLocation(), 800)
			if #alliesNearEnemy == 0 or enemy:GetAttackTarget() == courier then
				return true
			end
		end
		if
			enemy ~= nil
			and Fu.IsValidHero(enemy)
			and GetUnitToUnitDistance(enemy, courier) <= enemy:GetAttackRange() + 100
		then
			return true
		end
	end
	local enemyCreeps = GetUnitList(UNIT_LIST_ENEMY_CREEPS)
	local alliesNearCourier = Fu.GetAlliesNearLoc(courier:GetLocation(), 1500)
	local allyCount = #alliesNearCourier
	for _, creep in pairs(enemyCreeps) do
		if
			GetUnitToUnitDistance(courier, creep) <= 800
			and (creep:GetAttackTarget() == courier or botLevel > 10)
			and (allyCount == 0 or creep:GetAttackTarget() == courier)
		then
			return true
		end
	end
	return false
end
function Usage.IsInvFull(hero)
	for slot = 0, 8 do
		if hero:GetItemInSlot(slot) == nil then
			return false
		end
	end
	return true
end
function Usage.IsEnemyHeroAroundSecretShop()
	local secretShop = GetShopLocation(team, SHOP_SECRET)
	local secretShop2 = GetShopLocation(team, SHOP_SECRET2)
	local teamSecretShop = team == TEAM_DIRE and secretShop2 or secretShop
	local secretShopApproach = (teamSecretShop + GetAncient(team):GetLocation()) * 0.5
	if Fu.IsEnemyHeroAroundLocation(secretShopApproach, 2000) then
		return true
	end
	return false
end
local stashItemSeenTime = {}
local castRangeBonus = 0
local unusedCounter = 0
local enemyHasMonkeyKing = false
local lastTreadsSwitchTime = -90
local nearbyEnemies = {}
local nearbyEnemyTowers = {}
local botTarget = nil
local botMode = -1
-- Doom (or its Scepter aura): spells and healing are blocked, items are not (Valve data:
-- does_mute empty). It pierces BKB and cannot be dispelled. Items still work; only uses that
-- heal or restore mana for the doomed hero, or try to cure the silence, are wasted.
function Usage.IsDoomed(unit)
	return unit ~= nil
		and (
			unit:HasModifier("modifier_doom_bringer_doom") or unit:HasModifier("modifier_doom_bringer_doom_aura_enemy")
		)
end
-- Doom's talent special_bonus_unique_doom_10 "Doom applies Mute" (Valve data): with it, a
-- doomed hero cannot use items either. Checked on the enemy Doom, in addition to IsMuted().
function Usage.IsDoomMuted(unit)
	if not Usage.IsDoomed(unit) then
		return false
	end
	if unit:IsMuted() then
		return true
	end
	for _, enemy in pairs(GetUnitList(UNIT_LIST_ENEMY_HEROES) or {}) do
		if enemy ~= nil and not enemy:IsNull() and enemy:GetUnitName() == "npc_dota_hero_doom_bringer" then
			local ok, trained = pcall(function()
				local talent = enemy:GetAbilityByName("special_bonus_unique_doom_10")
				return talent ~= nil and talent:IsTrained()
			end)
			if ok and trained then
				return true
			end
		end
	end
	return false
end
-- Only healing is blocked; mana still pays for item actives (BKB, Force Staff, Shiva's...).
-- Pure heals are skipped; HP+mana items only when mana is not low; mana items are not touched.
local DOOM_HEAL_ONLY = {
	item_flask = true,
	item_tango = true,
	item_tango_single = true,
	item_faerie_fire = true,
	item_greater_faerie_fire = true,
	item_satanic = true,
}
local DOOM_HEAL_AND_MANA = {
	item_magic_stick = true,
	item_magic_wand = true,
	item_holy_locket = true,
	item_bottle = true,
	item_cheese = true,
}
local function DoomWastes(name)
	if DOOM_HEAL_ONLY[name] then
		return true
	end
	return DOOM_HEAL_AND_MANA[name] == true and bot:GetMana() / math.max(1, bot:GetMaxMana()) >= 0.3
end
local function ConsiderItems()
	Usage.SetStashItemTimeUpdate()
	-- WD: cash Gris-Gris before other item logic (bypasses CanCastAbility).
	if Usage.TryConsumeGrisGris and Usage.TryConsumeGrisGris() then
		return BOT_ACTION_DESIRE_HIGH
	end
	-- Shadow Amulet during a teleport channel (item use below is off while channelling).
	if bot:IsAlive() and bot:HasModifier("modifier_teleporting") and Usage.AmuletDuringTeleport() then
		return BOT_ACTION_DESIRE_NONE
	end
	if
		not bot:IsAlive()
		or bot:IsMuted()
		or bot:IsHexed()
		or bot:IsStunned()
		or bot:IsChanneling()
		or bot:IsInvulnerable()
		or bot:IsUsingAbility()
		or bot:IsCastingAbility()
		or bot:NumQueuedActions() > 0
		or bot:HasModifier("modifier_teleporting")
		-- Plain Doom silences and blocks healing but leaves items usable (does_mute empty); its
		-- Mute talent blocks items too.
		or Usage.IsDoomMuted(bot)
		or bot:HasModifier("modifier_phantom_lancer_phantom_edge_boost")
		or bot:HasModifier("modifier_life_stealer_infest")
		or bot:HasModifier("modifier_nyx_assassin_vendetta") and Fu.IsRealInvisible(bot)
		or Usage.WillBreakInvisible(bot)
	then
		return BOT_ACTION_DESIRE_NONE
	end
	nearbyEnemies = Fu.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE)
	nearbyEnemyTowers = bot:GetNearbyTowers(888, true)
	botTarget = Fu.GetProperTarget(bot)
	botMode = bot:GetActiveMode()
	if botMode ~= BOT_MODE_ATTACK and botMode ~= BOT_MODE_RETREAT then
		local isFighting = false
		local attackTarget = bot:GetAttackTarget()
		if attackTarget ~= nil and attackTarget:IsHero() then
			isFighting = true
		elseif #nearbyEnemies > 0 and (bot:WasRecentlyDamagedByAnyHero(2.0) or Fu.IsAttacking(bot)) then
			isFighting = true
		end
		if isFighting then
			botMode = BOT_MODE_ATTACK
		end
	end
	local aetherLens = Fu.IsItemAvailable("item_aether_lens")
	if aetherLens ~= nil then
		castRangeBonus = 250
	else
		castRangeBonus = 0
	end
	pcall(Usage.BannerFromBackpack)
	-- Smoke of Deceit is castable from the backpack. Other items stay in the main slots.
	-- Forage in the main inventory is eaten immediately. A backpack copy is swapped out and eaten.
	for forageSlot = 0, 5 do
		local forage = bot:GetItemInSlot(forageSlot)
		if forage ~= nil and not forage:IsNull() and not Fu.CanCastAbility(forage) then
			local forageItemName = forage:GetName()
			if
				(
					forageItemName == "item_foragers_stats"
					or forageItemName == "item_foragers_health"
					or forageItemName == "item_foragers_mana"
				) and DotaTime() >= (bot._forageStuckLogAt or -999)
			then
				bot._forageStuckLogAt = DotaTime() + 20
				pcall(
					print,
					string.format(
						"[OHA-FORAGE] t=%.0f %s cannot-eat %s slot%d fully=%s cd=%.1f hidden=%s passive=%s mana=%.0f",
						DotaTime(),
						(string.gsub(botName, "npc_dota_hero_", "")),
						forageItemName,
						forageSlot,
						tostring(forage:IsFullyCastable()),
						forage:GetCooldownTimeRemaining(),
						tostring(forage:IsHidden()),
						tostring(forage:IsPassive()),
						bot:GetMana()
					)
				)
			end
		end
		if forage ~= nil and not forage:IsNull() and Fu.CanCastAbility(forage) then
			local forageName = forage:GetName()
			if forageName == "item_foragers_stats" or forageName == "item_foragers_mana" then
				bot:Action_UseAbility(forage)
				return BOT_ACTION_DESIRE_NONE
			elseif forageName == "item_foragers_health" then
				bot:Action_UseAbilityOnEntity(forage, bot)
				return BOT_ACTION_DESIRE_NONE
			end
		end
	end
	local itemSlots = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 15, 16 }
	for _, slot in pairs(itemSlots) do
		local item = bot:GetItemInSlot(slot)
		local itemName = item ~= nil and item:GetName() or nil
		local inBackpack = slot >= 6 and slot <= 8
		local smokeFromBag = inBackpack and itemName == "item_smoke_of_deceit"
		if inBackpack and not smokeFromBag then
			itemName = nil
		end
		local ready = Fu.CanCastAbility(item)
		if smokeFromBag and item ~= nil and not item:IsNull() then
			local cooldown = item:GetCooldownTimeRemaining()
			ready = not (type(cooldown) == "number" and cooldown > 0)
		end
		if ready and itemName ~= nil and Usage.IsDoomed(bot) and DoomWastes(itemName) then
			ready = false
		end
		if ready and itemName ~= nil then
			if Usage.ConsiderItemDesire[itemName] ~= nil and not Usage.IsItemInStash(itemName) then
				local desire, target, castType, castReason = Usage.ConsiderItemDesire[itemName](item)
				if desire > 0 then
					local nearbyAllies = Fu.GetAllyList(bot, 1200) or {}
					MatchTrace.Item(
						bot,
						itemName,
						"use",
						string.format(
							"desire=%.2f cast=%s note=%s mode=%s allies=%d",
							desire,
							tostring(castType),
							tostring(castReason or ""),
							tostring(botMode),
							#nearbyAllies
						)
					)
					if string.find(itemName, "tpscroll", 1, true) or string.find(itemName, "travel_boots", 1, true) then
						Usage.LogTeleport(itemName, target, castReason, botMode)
					end
					Usage.SetUseItem(item, target, castType)
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
-- [OHA-TP]: every teleport with its reason, where from and to, and which lane the target is
-- on next to the lane this bot is laning in (by position) and the engine's assignment.
function Usage.LogTeleport(item, target, reason, mode)
	if target == nil or type(target) ~= "userdata" and type(target) ~= "table" then
		return
	end
	local ok, targetX, targetY = pcall(function()
		return target.x, target.y
	end)
	if not ok or type(targetX) ~= "number" then
		return
	end
	local names = { [LANE_TOP] = "top", [LANE_MID] = "mid", [LANE_BOT] = "bot" }
	local nearestLane, nearestDist = nil, math.huge
	for _, lane in ipairs({ LANE_TOP, LANE_MID, LANE_BOT }) do
		local along = GetAmountAlongLane(lane, target)
		if along ~= nil and along.distance < nearestDist then
			nearestLane, nearestDist = lane, along.distance
		end
	end
	local here = bot:GetLocation()
	pcall(
		print,
		string.format(
			"[OHA-TP] t=%.0f %s %s why=%s mode=%s hp=%.2f foes=%d allies=%d posLane=%s engineLane=%s from=%.0f,%.0f to=%.0f,%.0f targetLane=%s",
			DotaTime(),
			(string.gsub(botName, "npc_dota_hero_", "")),
			(string.gsub(item, "^item_", "")),
			tostring(reason),
			tostring(mode),
			bot:GetHealth() / math.max(1, bot:GetMaxHealth()),
			#(bot:GetNearbyHeroes(1600, true, BOT_MODE_NONE) or {}),
			#(bot:GetNearbyHeroes(1600, false, BOT_MODE_NONE) or {}) - 1,
			tostring(names[Usage.GetLaneByPosition(bot)]),
			tostring(names[bot:GetAssignedLane()]),
			here.x,
			here.y,
			targetX,
			targetY,
			tostring(names[nearestLane])
		)
	)
end
function Usage.SetUseItem(item, target, castType)
	if item == nil or item:IsNull() then
		return
	end
	-- Never issue orders on hidden abilities (server: invalid order 60).
	if item.IsHidden and item:IsHidden() then
		return
	end
	if castType == "none" then
		bot:Action_UseAbility(item)
		return
	elseif castType == "unit" and type(target) == "table" then
		bot:Action_UseAbilityOnEntity(item, target)
		if string.find(item:GetName(), "tango") then
			bot._lastTangoUseTime = DotaTime()
		end
		return
	elseif
		castType == "ground" or target and type(target) ~= "number" and type(target) ~= "table" and target.x ~= nil
	then
		bot:Action_UseAbilityOnLocation(item, target)
		return
	elseif castType == "tree" then
		bot:Action_UseAbilityOnTree(item, target)
		bot._lastTangoUseTime = DotaTime()
		return
	elseif castType == "twice" then
		bot:Action_UseAbility(item)
		bot:ActionQueue_UseAbility(item)
		return
	end
end
function Usage.IsWithoutSpellShield(unit)
	return not unit:HasModifier("modifier_item_sphere_target")
		and not unit:HasModifier("modifier_antimage_spell_shield")
		and not unit:HasModifier("modifier_item_lotus_orb_active")
end
local lastStashCleanTime = -90
function Usage.SetStashItemTimeUpdate()
	local now = DotaTime()
	for slot = 6, 8 do
		local item = bot:GetItemInSlot(slot)
		if item ~= nil then
			stashItemSeenTime[item:GetName()] = now
		end
	end
	if now > lastStashCleanTime + 7.0 then
		lastStashCleanTime = now
		for itemName, seenTime in pairs(stashItemSeenTime) do
			if seenTime ~= nil and seenTime < now - 7.0 then
				stashItemSeenTime[itemName] = nil
			end
		end
	end
end
function Usage.IsItemInStash(itemName)
	if stashItemSeenTime[itemName] ~= nil and DotaTime() < stashItemSeenTime[itemName] + 6.05 then
		return true
	end
	return false
end
function Usage.WillBreakInvisible(unit)
	if not unit:IsInvisible() then
		return false
	end
	local unitName = botName
	if
		unitName == "npc_dota_hero_riki"
		or unitName == "npc_dota_hero_bounty_hunter"
		or unitName == "npc_dota_hero_slark"
	then
		return false
	end
	if unit:HasModifier("modifier_phantom_assassin_blur_active") then
		return false
	end
	if unit:HasModifier("modifier_item_glimmer_cape_fade") then
		return false
	end
	if unit:HasModifier("modifier_item_shadow_amulet_fade") then
		return true
	end
	if
		unit:HasModifier("modifier_item_invisibility_edge_windwalk")
		or unit:HasModifier("modifier_item_silver_edge_windwalk")
	then
		return true
	end
	if unit:HasModifier("modifier_smoke_of_deceit") then
		return true
	end
	return false
end
Usage.ConsiderItemDesire = {}
Usage.ConsiderItemDesire["item_abyssal_blade"] = function(item)
	-- Overwhelm is melee range (150) and pierces debuff immunity. A short
	-- approach is allowed on top of the real range.
	local castRange = 150 + castRangeBonus + 100
	local castType = "unit"
	local hEffectTarget = nil
	local castReason = nil
	local hMenace = Fu.GetRightclickMenaceLock(bot, castRange + 200, "pierce")
	if hMenace ~= nil and Usage.IsWithoutSpellShield(hMenace) then
		return BOT_ACTION_DESIRE_HIGH, hMenace, castType, "stun carry"
	end
	local enemyHeroes = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	for _, enemy in pairs(enemyHeroes) do
		if Fu.IsValid(enemy) and Fu.CanCastOnMagicImmune(enemy) and Usage.IsWithoutSpellShield(enemy) then
			if enemy:IsChanneling() or enemy:IsCastingAbility() then
				hEffectTarget = enemy
				castReason = "打断:" .. Fu.Chat.GetNormName(hEffectTarget)
				return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
			end
			if botMode == BOT_MODE_RETREAT and not Fu.IsDisabled(enemy) then
				hEffectTarget = enemy
				castReason = "撤退:" .. Fu.Chat.GetNormName(hEffectTarget)
				return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
			end
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidHero(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange + 50)
			and Fu.CanCastOnMagicImmune(botTarget)
			and Usage.IsWithoutSpellShield(botTarget)
			and not Fu.IsDisabled(botTarget)
		then
			hEffectTarget = botTarget
			castReason = "进攻:" .. Fu.Chat.GetNormName(hEffectTarget)
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
Usage.ConsiderItemDesire["item_ancient_janggo"] = function(item)
	if item:GetCurrentCharges() <= 0 and item:GetName() == "item_ancient_janggo" then
		return BOT_ACTION_DESIRE_NONE
	end
	local castRange = 680
	local castType = "none"
	local hEffectTarget = nil
	local castReason = nil
	local enemyHeroes = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	if bot:HasModifier("modifier_nyx_assassin_vendetta") then
		return BOT_ACTION_DESIRE_NONE
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidHero(botTarget)
			and Fu.CanCastOnMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
		then
			hEffectTarget = botTarget
			castReason = "进攻:" .. Fu.Chat.GetNormName(hEffectTarget)
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
Usage.ConsiderItemDesire["item_arcane_boots"] = function(item)
	if bot:DistanceFromFountain() < 800 then
		return BOT_ACTION_DESIRE_NONE
	end
	local radius = 1200
	local castType = "none"
	local hEffectTarget = nil
	local castReason = nil
	local enemyHeroes = Fu.GetNearbyHeroes(bot, radius, true, BOT_MODE_NONE)
	local allyHeroes = Fu.GetAllyList(bot, radius)
	if #allyHeroes >= 2 and bot:GetHealth() <= 120 and bot:WasRecentlyDamagedByAnyHero(3.0) then
		castReason = "死前为队友用"
		return BOT_ACTION_DESIRE_HIGH, allyHeroes[2], castType, castReason
	end
	local lowManaAllyCount = 0
	for _, ally in pairs(allyHeroes) do
		if ally ~= nil and ally:IsAlive() and ally:GetMaxMana() - ally:GetMana() > 180 then
			lowManaAllyCount = lowManaAllyCount + 1
		end
		if lowManaAllyCount >= 2 then
			castReason = "团队回蓝"
			return BOT_ACTION_DESIRE_HIGH, allyHeroes[2], castType, castReason
		end
	end
	if bot:GetMana() / bot:GetMaxMana() < 0.65 then
		castReason = "自己补蓝"
		return BOT_ACTION_DESIRE_HIGH, bot, castType, castReason
	end
	return BOT_ACTION_DESIRE_NONE
end
-- Armlet of Mordiggian (Valve data: +35 damage, +25 strength, +4 armor while on, 45 HP/s drain;
-- neither the drain nor switching off can kill; the strength comes in and goes out over 0.6s).
-- Returning HIGH toggles it. On when it pays for the drain, off as soon as it no longer does;
-- the rules below switch it back on when needed.
-- 1. Worth on: an enemy hero within attack range + 300, Roshan, Tormentor, or a building while
--    pushing. Not lane creeps or neutrals (it used to be on through every farm).
-- 2. On early when chasing a hero within attack range + 600, so the strength is in by the hit.
-- 3. Held 3s after the last reason, and while an enemy hero is within 800 in a fight, so it
--    does not flicker off between targets.
-- 4. Not off below 30% HP with an enemy hero within 1200 (switching off takes the strength HP).
-- 5. Toggle trick: on, being hit, HP below what the strength gives (measured when it turns on):
--    off, then straight back on (at most once a second; not under Doom, which blocks the gain).
-- Never toggled under Ancient Apparition's Ice Blast: changing max HP there can drop him under
-- the shatter threshold.
Usage.ConsiderItemDesire["item_armlet"] = function(item)
	local on = item:GetToggleState()
	local now = DotaTime()
	if bot:HasModifier("modifier_ice_blast") then
		return BOT_ACTION_DESIRE_NONE
	end
	-- Strength HP: max HP with it on minus off, measured once it has settled (0.6s+).
	if on and bot._armletOnAt ~= nil and now - bot._armletOnAt > 0.8 and bot._armletMaxOff ~= nil then
		bot._armletHpGain = math.max(0, bot:GetMaxHealth() - bot._armletMaxOff)
	elseif not on and (bot._armletOffAt == nil or now - bot._armletOffAt > 0.8) then
		bot._armletMaxOff = bot:GetMaxHealth()
	end
	local function TurnOn(why)
		bot._armletOnAt = now
		bot._armletWhy = why
		return BOT_ACTION_DESIRE_HIGH, nil, "none"
	end
	local function TurnOff(why)
		bot._armletOffAt = now
		bot._armletWhy = why
		return BOT_ACTION_DESIRE_HIGH, nil, "none"
	end
	-- 5. Second half of the trick: back on right away.
	if not on and bot._armletTrickAt ~= nil and now - bot._armletTrickAt < 0.5 then
		bot._armletTrickAt = nil
		return TurnOn("trick-on")
	end
	local doomed = Usage.IsDoomed(bot)
	local heroNear = Fu.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE) or {}
	local hit = bot:WasRecentlyDamagedByAnyHero(1.5) or Fu.IsAttackProjectileIncoming(bot, 1000)
	if
		on
		and not doomed
		and hit
		and bot._armletHpGain ~= nil
		and bot._armletHpGain > 0
		and bot:GetHealth() < bot._armletHpGain * 0.9
		and now - (bot._armletTrickLast or -99) >= 1
	then
		bot._armletTrickAt = now
		bot._armletTrickLast = now
		return TurnOff("trick-off")
	end
	-- 1 and 2: reasons to be on.
	local want = false
	if Fu.IsValid(botTarget) and Fu.CanBeAttacked(botTarget) and not bot:IsDisarmed() then
		local reach = bot:GetAttackRange() + 300
		if botTarget:IsHero() and botTarget:GetTeam() ~= bot:GetTeam() then
			if Fu.IsInRange(bot, botTarget, reach) then
				want = true
			elseif Fu.IsGoingOnSomeone(bot) and Fu.IsInRange(bot, botTarget, reach + 300) then
				want = true
			end
		elseif (Fu.IsRoshan(botTarget) or Fu.IsTormentor(botTarget)) and Fu.IsInRange(bot, botTarget, reach) then
			want = true
		elseif
			botTarget:IsBuilding()
			and not string.find(botTarget:GetUnitName(), "OutpostName")
			and Fu.IsPushing(bot)
			and Fu.IsInRange(bot, botTarget, reach)
		then
			want = true
		end
	end
	-- Survival: on to gain the strength HP (blocked by Doom, so not then).
	if not doomed then
		if Fu.IsRetreating(bot) and not Fu.IsRealInvisible(bot) and Fu.GetHP(bot) < 0.2 then
			if
				bot:WasRecentlyDamagedByAnyHero(2.0)
				or Fu.IsAttackProjectileIncoming(bot, 1200)
				or Fu.IsStunProjectileIncoming(bot, 550)
			then
				want = true
			end
		end
		if
			Fu.GetAttackProjectileDamageByRange(bot, 600) > bot:GetHealth() * 2
			or Fu.IsStunProjectileIncoming(bot, 600) and Fu.GetHP(bot) < 0.25
		then
			want = true
		end
	end
	-- 3. Hold.
	if want then
		bot._armletHoldUntil = now + 3
	end
	local fightNear = #(Fu.GetNearbyHeroes(bot, 800, true, BOT_MODE_NONE) or {}) > 0
		and (Fu.IsGoingOnSomeone(bot) or Fu.IsInTeamFight(bot, 1200))
	local holding = now < (bot._armletHoldUntil or -99) or fightNear
	-- 4. Low with enemies around: keep it on.
	local lowNearEnemy = Fu.GetHP(bot) < 0.3 and #heroNear > 0
	if not on then
		if want then
			return TurnOn("worth")
		end
		return BOT_ACTION_DESIRE_NONE
	end
	if want or holding or lowNearEnemy then
		return BOT_ACTION_DESIRE_NONE
	end
	return TurnOff("not-worth")
end
Usage.ConsiderItemDesire["item_bfury"] = function(item)
	return Usage.ConsiderItemDesire["item_quelling_blade"](item)
end
Usage.ConsiderItemDesire["item_black_king_bar"] = function(item)
	if bot:HasModifier("modifier_dazzle_nothl_projection_soul_debuff") then
		return BOT_ACTION_DESIRE_NONE
	end
	local radius = 1300
	local castType = "none"
	local hEffectTarget = nil
	local castReason = nil
	local enemyHeroes = Fu.GetNearbyHeroes(bot, radius, true, BOT_MODE_NONE)
	if
		#enemyHeroes > 0
		and not bot:IsMagicImmune()
		and not bot:IsInvulnerable()
		and not bot:HasModifier("modifier_item_lotus_orb_active")
		and not bot:HasModifier("modifier_antimage_spell_shield")
		and (Fu.IsGoingOnSomeone(bot) or Fu.IsRetreating(bot))
	then
		local closeEnemyCount = Fu.GetEnemyCount(bot, 600)
		if bot:IsRooted() then
			castReason = "解缠绕"
			return BOT_ACTION_DESIRE_HIGH, bot, castType, castReason
		end
		if
			bot:IsSilenced()
			and not Usage.IsDoomed(bot)
			and bot:GetMana() > 100
			and not bot:HasModifier("modifier_item_mask_of_madness_berserk")
			and closeEnemyCount >= 2
		then
			castReason = "解沉默"
			return BOT_ACTION_DESIRE_HIGH, bot, castType, castReason
		end
		if Fu.IsNotAttackProjectileIncoming(bot, 350) and closeEnemyCount >= 1 then
			castReason = "防御弹道"
			return BOT_ACTION_DESIRE_HIGH, bot, castType, castReason
		end
		if Fu.IsWillBeCastUnitTargetSpell(bot, radius) and closeEnemyCount >= 1 then
			castReason = "防御指向技能"
			return BOT_ACTION_DESIRE_HIGH, bot, castType, castReason
		end
		if Fu.IsWillBeCastPointSpell(bot, radius) and closeEnemyCount >= 1 then
			castReason = "防御地点技能"
			return BOT_ACTION_DESIRE_HIGH, bot, castType, castReason
		end
		if Fu.GetEnemyCount(bot, 800) >= 3 then
			castReason = "先开BKB切入"
			return BOT_ACTION_DESIRE_HIGH, bot, castType, castReason
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
Usage.ConsiderItemDesire["item_blade_mail"] = function(item)
	local radius = 800
	local castType = "none"
	local hEffectTarget = nil
	local castReason = nil
	local enemyHeroes = Fu.GetNearbyHeroes(bot, radius, true, BOT_MODE_NONE)
	if Fu.IsNotAttackProjectileIncoming(bot, 366) and #enemyHeroes >= 1 then
		hEffectTarget = bot
		castReason = "反弹弹道"
		return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
	end
	for _, enemy in pairs(nearbyEnemies) do
		if
			Fu.IsValidHero(enemy)
			and Fu.CanCastOnNonMagicImmune(enemy)
			and enemy:GetAttackTarget() == bot
			and (bot:WasRecentlyDamagedByHero(enemy, 5.0) or Fu.IsAttackProjectileIncoming(bot, 1000))
		then
			hEffectTarget = enemy
			castReason = "反弹敌人伤害:" .. Fu.Chat.GetNormName(hEffectTarget)
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
Usage.ConsiderItemDesire["item_blink"] = function(item)
	local castRange = 1200
	if item:GetName() == "item_arcane_blink" then
		castRange = 1400
	end
	castRange = castRange + castRangeBonus
	if Fu.HasItemInInventory("item_magnifying_monocle") then
		castRange = castRange + 100
	end
	if Fu.HasItemInInventory("item_enhancement_keen_eyed") then
		if DotaTime() >= (Fu.IsModeTurbo() and 7.5 * 60 or 15 * 60) then
			castRange = castRange + 125
		elseif DotaTime() >= (Fu.IsModeTurbo() and 12.5 * 60 or 25 * 60) then
			castRange = castRange + 135
		end
	end
	if Fu.HasItemInInventory("item_enhancement_mystical") then
		if DotaTime() >= (Fu.IsModeTurbo() and 17.5 * 60 or 35 * 60) then
			castRange = castRange + 100
		end
	end
	if Fu.HasItemInInventory("item_enhancement_boundless") then
		if DotaTime() >= (Fu.IsModeTurbo() and 30 * 60 or 60 * 60) then
			castRange = castRange + 350
		end
	end
	local heroName = bot:GetUnitName()
	if bot:IsRooted() or bot:HasModifier("modifier_nyx_assassin_vendetta") then
		return BOT_ACTION_DESIRE_NONE
	end
	if Fu.IsStuck(bot) then
		local retreatLocation =
			Fu.GetLocationTowardDistanceLocation(bot, GetAncient(GetTeam()):GetLocation(), castRange)
		return BOT_ACTION_DESIRE_HIGH, retreatLocation, "ground", nil
	end
	local attackingAllies = bot:GetNearbyHeroes(800, false, BOT_MODE_ATTACK)
	if
		Fu.IsRetreating(bot)
		and not Fu.IsRealInvisible(bot)
		and bot:GetActiveModeDesire() > BOT_MODE_DESIRE_MODERATE
	then
		local blinkLocation = Fu.GetLocationTowardDistanceLocation(bot, GetAncient(GetTeam()):GetLocation(), castRange)
		local nInRangeEnemy = Fu.GetEnemiesNearLoc(bot:GetLocation(), 1200)
		if
			bot:DistanceFromFountain() > 900
			and IsLocationPassable(blinkLocation)
			and (#attackingAllies <= 1 or bot:GetActiveModeDesire() > BOT_MODE_DESIRE_VERYHIGH * 0.9)
			and nInRangeEnemy ~= nil
			and #nInRangeEnemy >= 1
		then
			return BOT_ACTION_DESIRE_HIGH, blinkLocation, "ground", nil
		end
	end
	attackingAllies = bot:GetNearbyHeroes(1600, false, BOT_MODE_ATTACK)
	if
		#attackingAllies <= 1
		and (botTarget == nil or not botTarget:IsHero())
		and Fu.IsFarming(bot)
		and not bot:WasRecentlyDamagedByAnyHero(3.1)
		and not Fu.IsPushing(bot)
		and not Fu.IsDefending(bot)
	then
		local aoeLocation = bot:FindAoELocation(true, false, bot:GetLocation(), castRange, 500, 0, 0)
		local enemyLaneCreeps = bot:GetNearbyLaneCreeps(1600, true)
		local nInRangeEnemy = Fu.GetEnemiesNearLoc(aoeLocation.targetloc, 1600)
		if
			enemyLaneCreeps ~= nil
			and #enemyLaneCreeps >= 4
			and nInRangeEnemy ~= nil
			and #nInRangeEnemy == 0
			and aoeLocation.count >= 4
		then
			local creepCenter = Fu.GetCenterOfUnits(enemyLaneCreeps)
			local creepDistance = GetUnitToLocationDistance(bot, creepCenter)
			local beyondCreepsLocation = Fu.GetLocationTowardDistanceLocation(bot, creepCenter, creepDistance + 550)
			local blinkLocation = Fu.GetLocationTowardDistanceLocation(bot, creepCenter, creepDistance - 300)
			if creepDistance > castRange then
				blinkLocation = Fu.GetLocationTowardDistanceLocation(bot, creepCenter, castRange)
			end
			if
				IsLocationPassable(blinkLocation)
				and GetUnitToLocationDistance(bot, blinkLocation) > 600
				and IsLocationVisible(beyondCreepsLocation)
				and not Fu.IsLocHaveTower(700, true, blinkLocation)
			then
				return BOT_ACTION_DESIRE_HIGH, blinkLocation, "ground", nil
			end
		end
	end
	if
		Fu.IsProjectileIncoming(bot, 1200)
		and (botTarget == nil or not botTarget:IsHero() or not Fu.IsInRange(bot, botTarget, bot:GetAttackRange() + 100))
	then
		local retreatLocation = Fu.GetLocationTowardDistanceLocation(bot, GetAncient(GetTeam()):GetLocation(), 1199)
		return BOT_ACTION_DESIRE_HIGH, retreatLocation, "ground", nil
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			bot.shouldBlink ~= nil
			and bot.shouldBlink
			and (
				heroName == "npc_dota_hero_batrider"
				or heroName == "npc_dota_hero_beastmaster"
				or heroName == "npc_dota_hero_dark_seer"
				or heroName == "npc_dota_hero_earthshaker"
				or heroName == "npc_dota_hero_magnataur"
				or heroName == "npc_dota_hero_rubick"
				or heroName == "npc_dota_hero_tiny"
				or heroName == "npc_dota_hero_treant"
			)
		then
			return BOT_ACTION_DESIRE_NONE
		end
		if heroName == "npc_dota_hero_nevermore" then
			local requiem = bot:GetAbilityByName("nevermore_requiem")
			if Fu.CanCastAbility(requiem) then
				return BOT_ACTION_DESIRE_NONE
			end
		end
		if
			Fu.IsValidTarget(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and Fu.CanBeAttacked(botTarget)
			and not Fu.IsInRange(bot, botTarget, 500)
			and not botTarget:HasModifier("modifier_faceless_void_chronosphere_freeze")
			and not botTarget:HasModifier("modifier_enigma_black_hole_pull")
		then
			local alliesNearTarget = Fu.GetAlliesNearLoc(botTarget:GetLocation(), 1200)
			local nInRangeEnemy = Fu.GetEnemiesNearLoc(botTarget:GetLocation(), 1200)
			local weAreStronger = Fu.WeAreStronger(bot, 1200)
			local enemyCountNearTarget = 0
			for _, playerId in pairs(GetTeamPlayers(GetOpposingTeam())) do
				if IsHeroAlive(playerId) then
					local lastSeenInfo = GetHeroLastSeenInfo(playerId)
					if lastSeenInfo ~= nil then
						local lastSeen = lastSeenInfo[1]
						if
							lastSeen ~= nil
							and lastSeen.time_since_seen < 3.0
							and GetUnitToLocationDistance(botTarget, lastSeen.location) <= 1200
						then
							enemyCountNearTarget = enemyCountNearTarget + 1
						end
					end
				end
			end
			if #alliesNearTarget >= enemyCountNearTarget and weAreStronger then
				local blinkDistance = Min(castRange, GetUnitToUnitDistance(bot, botTarget))
				local blinkLocation = Fu.GetUnitTowardDistanceLocation(bot, botTarget, blinkDistance)
					+ RandomVector(150)
				if IsLocationPassable(blinkLocation) then
					return BOT_ACTION_DESIRE_HIGH, blinkLocation, "ground", nil
				end
			end
		end
	end
	if Fu.IsDoingTormentor(bot) and not Fu.IsRealInvisible(bot) then
		local tormentorLocation = Fu.GetTormentorLocation(GetTeam())
		if GetUnitToLocationDistance(bot, tormentorLocation) > 2000 then
			local blinkLocation = Fu.VectorTowards(bot:GetLocation(), tormentorLocation, castRange)
			local nInRangeEnemy = Fu.GetEnemiesNearLoc(blinkLocation, 1200)
			if IsLocationPassable(blinkLocation) and #nInRangeEnemy == 0 then
				return BOT_ACTION_DESIRE_HIGH, blinkLocation, "ground", nil
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
Usage.ConsiderItemDesire["item_overwhelming_blink"] = function(item)
	return Usage.ConsiderItemDesire["item_blink"](item)
end
Usage.ConsiderItemDesire["item_swift_blink"] = function(item)
	return Usage.ConsiderItemDesire["item_blink"](item)
end
Usage.ConsiderItemDesire["item_arcane_blink"] = function(item)
	return Usage.ConsiderItemDesire["item_blink"](item)
end
Usage.ConsiderItemDesire["item_cheese"] = function(item)
	if bot:DistanceFromFountain() < 1200 then
		return BOT_ACTION_DESIRE_NONE
	end
	local radius = 800
	local castType = "none"
	local hEffectTarget = nil
	local castReason = nil
	local enemyHeroes = Fu.GetNearbyHeroes(bot, radius, true, BOT_MODE_NONE)
	local missingHealth = bot:GetMaxHealth() - bot:GetHealth()
	local hpRatio = bot:GetHealth() / bot:GetMaxHealth()
	local missingMana = bot:GetMaxMana() - bot:GetMana()
	local mpRatio = bot:GetMana() / bot:GetMaxMana()
	if
		missingHealth > 2500 and missingMana > 1500
		or missingHealth > 2000 and missingHealth + missingMana > 3000
		or hpRatio < 0.4 and mpRatio < 0.4
		or hpRatio < 0.2
		or mpRatio < 0.06
	then
		if Fu.IsGoingOnSomeone(bot) then
			if
				Fu.IsValidHero(botTarget)
				and Fu.IsInRange(bot, botTarget, 2000)
				and Fu.CanCastOnMagicImmune(botTarget)
			then
				hEffectTarget = bot
				castReason = "进攻"
				return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
			end
		end
		if Fu.IsRetreating(bot) and bot:WasRecentlyDamagedByAnyHero(4.0) then
			hEffectTarget = bot
			castReason = "撤退"
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
-- Bloodstone's Bloodpact (Valve data: spell lifesteal 20% -> 60% for 5s, no mana, 35s cooldown).
-- Worth it only when he is hurt and about to cast: HP below 60%, an enemy hero within 900, and
-- at least one spell ready with the mana for it (one that costs mana or deals damage; many
-- spells report 0 ability damage), while fighting, chasing or under fire
-- (or at Roshan / Tormentor). It used to go on every engage and team fight at any HP, and was
-- often on cooldown by the time the hero was low.
local function SpellReadyToCast()
	for slot = 0, 5 do
		local ability = bot:GetAbilityInSlot(slot)
		if ability ~= nil and not ability:IsNull() and ability:IsTrained() and not ability:IsHidden() then
			local okP, passive = pcall(function()
				return ability:IsPassive()
			end)
			local okT, toggle = pcall(function()
				return ability:IsToggle()
			end)
			if
				not (okP and passive)
				and not (okT and toggle)
				and ability:IsFullyCastable()
				and ability:GetManaCost() <= bot:GetMana()
				and (ability:GetManaCost() > 0 or (ability:GetAbilityDamage() or 0) > 0)
			then
				return true
			end
		end
	end
	return false
end
-- A damaging spell ready (mana, castable) with an enemy hero inside its reach. Damage is read
-- from the ability damage or the usual damage values (many spells report 0 ability damage);
-- reach is the cast range, or the radius for a no-target spell.
local DAMAGE_KEYS =
	{ "damage", "aoe_damage", "impale_damage", "damage_per_second", "burn_damage", "tick_damage", "max_damage" }
local function DamagingSpellOnEnemy(foes)
	for slot = 0, 5 do
		local ability = bot:GetAbilityInSlot(slot)
		if ability ~= nil and not ability:IsNull() and ability:IsTrained() and not ability:IsHidden() then
			local okP, passive = pcall(function()
				return ability:IsPassive()
			end)
			if not (okP and passive) and ability:IsFullyCastable() and ability:GetManaCost() <= bot:GetMana() then
				local dmg = ability:GetAbilityDamage() or 0
				if dmg <= 0 then
					for _, key in ipairs(DAMAGE_KEYS) do
						local okV, value = pcall(function()
							return ability:GetSpecialValueFloat(key)
						end)
						if okV and type(value) == "number" and value > 0 then
							dmg = value
							break
						end
					end
				end
				if dmg > 0 then
					local reach = ability:GetCastRange()
					if reach == nil or reach <= 0 then
						local okR, rad = pcall(function()
							return ability:GetSpecialValueInt("radius")
						end)
						reach = (okR and type(rad) == "number" and rad > 0) and rad or 300
					end
					for _, enemy in pairs(foes) do
						if Fu.IsValidHero(enemy) and GetUnitToUnitDistance(bot, enemy) <= reach + 50 then
							return true
						end
					end
				end
			end
		end
	end
	return false
end
Usage.ConsiderItemDesire["item_bloodstone"] = function(item)
	local castType = "none"
	if bot:IsSilenced() or bot:HasModifier("modifier_item_bloodstone_active") then
		return BOT_ACTION_DESIRE_NONE
	end
	if Fu.GetHP(bot) >= 0.6 then
		return BOT_ACTION_DESIRE_NONE
	end
	local objective = Fu.IsDoingRoshan(bot) or Fu.IsDoingTormentor(bot)
	local foes = Fu.GetNearbyHeroes(bot, 900, true, BOT_MODE_NONE) or {}
	if #foes == 0 and not objective then
		return BOT_ACTION_DESIRE_NONE
	end
	local fighting = Fu.IsInTeamFight(bot, 1200)
		or Fu.IsGoingOnSomeone(bot)
		or bot:WasRecentlyDamagedByAnyHero(2)
		or objective
	-- Running away: only with a damaging spell that can reach an enemy now. Bloodpact heals only
	-- from spell damage, so an escape that hits nothing (Leap, Blink, Sinister Gaze) wastes it.
	local spellOk
	if Fu.IsRetreating(bot) then
		spellOk = DamagingSpellOnEnemy(foes)
	else
		spellOk = SpellReadyToCast()
	end
	if fighting and spellOk then
		pcall(
			print,
			string.format(
				"[OHA-ITEM] t=%.0f %s bloodstone hp=%.2f foes=%d",
				DotaTime(),
				(string.gsub(botName, "npc_dota_hero_", "")),
				Fu.GetHP(bot),
				#foes
			)
		)
		return BOT_ACTION_DESIRE_HIGH, bot, castType, "Bloodstone: spell lifesteal while low"
	end
	return BOT_ACTION_DESIRE_NONE
end
Usage.ConsiderItemDesire["item_bloodthorn"] = function(item)
	return Usage.ConsiderItemDesire["item_orchid"](item)
end
Usage.ConsiderItemDesire["item_bottle"] = function(item)
	if item:GetCurrentCharges() == 0 or bot:HasModifier("modifier_bottle_regeneration") then
		return BOT_ACTION_DESIRE_NONE
	end
	if Fu.HasDamageOverTimeDebuff(bot) then
		return BOT_ACTION_DESIRE_NONE
	end
	local castRange = 400 + castRangeBonus
	local castType = "none"
	local hEffectTarget = nil
	local castReason = nil
	local missingMana = bot:GetMaxMana() - bot:GetMana()
	local missingHealth = bot:OriginalGetMaxHealth() - bot:OriginalGetHealth()
	if bot:HasModifier("modifier_fountain_aura") then
		hEffectTarget = bot
		castReason = "在泉水里喝"
		return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
	end
	if not bot:WasRecentlyDamagedByAnyHero(3.0) then
		if missingHealth > 150 and missingMana > 90 then
			hEffectTarget = bot
			castReason = "补血补篮"
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
		end
		if missingHealth > 500 and Fu.GetHP(bot) < 0.5 then
			hEffectTarget = bot
			castReason = "只补血"
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
		end
		if missingMana > 280 and Fu.GetMP(bot) < 0.4 then
			hEffectTarget = bot
			castReason = "只补篮"
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
Usage.ConsiderItemDesire["item_clarity"] = function(item)
	if bot:DistanceFromFountain() < 2000 then
		return BOT_ACTION_DESIRE_NONE
	end
	local castRange = 800 + castRangeBonus
	local castType = "unit"
	local hEffectTarget = nil
	local castReason = nil
	local enemyHeroes = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	if
		Fu.GetMP(bot) < 0.4
		and not bot:HasModifier("modifier_clarity_potion")
		and #enemyHeroes == 0
		and not bot:WasRecentlyDamagedByAnyHero(4.0)
	then
		hEffectTarget = bot
		castReason = "净化自己"
		return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
	end
	if #enemyHeroes == 0 then
		local allyHeroes = Fu.GetNearbyHeroes(bot, 600, false, BOT_MODE_NONE)
		local bestAlly = nil
		local lowestMana = 99999
		for _, ally in pairs(allyHeroes) do
			if
				Fu.IsValid(ally)
				and ally ~= bot
				and not ally:IsIllusion()
				and not ally:IsChanneling()
				and not ally:HasModifier("modifier_clarity_potion")
				and not ally:WasRecentlyDamagedByAnyHero(4.0)
				and ally:GetMaxMana() - ally:GetMana() > 350
			then
				if ally:GetMana() < lowestMana then
					bestAlly = ally
					lowestMana = ally:GetMana()
				end
			end
		end
		if bestAlly ~= nil then
			hEffectTarget = bestAlly
			castReason = "净化队友:" .. Fu.Chat.GetNormName(hEffectTarget)
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
Usage.ConsiderItemDesire["item_crimson_guard"] = function(item)
	if bot:DistanceFromFountain() < 400 then
		return BOT_ACTION_DESIRE_NONE
	end
	local castRange = 1200
	local castType = "none"
	local hEffectTarget = nil
	local castReason = nil
	local enemyHeroes = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	local allyHeroes = Fu.GetAllyList(bot, castRange)
	for _, ally in pairs(allyHeroes) do
		if
			Fu.IsValid(ally)
			and ally:OriginalGetHealth() / ally:OriginalGetMaxHealth() < 0.8
			and ally:WasRecentlyDamagedByAnyHero(2.0)
			and not ally:HasModifier("modifier_item_crimson_guard_nostack")
			and #nearbyEnemies > 0
		then
			hEffectTarget = ally
			castReason = "救救队友:" .. Fu.Chat.GetNormName(hEffectTarget)
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
		end
	end
	local closeEnemies = Fu.GetNearbyHeroes(bot, 1000, true, BOT_MODE_NONE)
	local enemyTowers = bot:GetNearbyTowers(800, true)
	if #allyHeroes >= 2 and (#closeEnemies + #enemyTowers >= 2 or #closeEnemies >= 2) then
		for _, ally in pairs(allyHeroes) do
			if
				ally:WasRecentlyDamagedByAnyHero(2.0) and not ally:HasModifier("modifier_item_crimson_guard_nostack")
			then
				hEffectTarget = ally
				castReason = "保护队友:" .. Fu.Chat.GetNormName(hEffectTarget)
				return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
-- A silence only matters when it blocks a spell the hero could use now: a learned, non-passive ability that is
-- off cooldown and affordable. The self-dispel rules (Eul's, Stormcrafter) used to require an intelligence hero,
-- so universal, strength and agility heroes never dispelled a silence (#15). Eul's self-cast is a basic dispel
-- (datafeed, item 100).
function Usage.SilenceBlocksASpell(unit)
	-- Only when a spell is needed now: retreating (escape) or engaging (disable / nuke). A silenced right-clicker
	-- in a calm moment should not Eul himself out of a fight. The silence's remaining time is not checked: it
	-- needs the silence modifier names (many), left for later (#15).
	if not unit:IsSilenced() or not (Fu.IsRetreating(unit) or Fu.IsGoingOnSomeone(unit)) then
		return false
	end
	for slot = 0, 5 do
		local ability = unit:GetAbilityInSlot(slot)
		if
			ability ~= nil
			and not ability:IsNull()
			and ability:GetLevel() > 0
			and not ability:IsPassive()
			and not ability:IsHidden()
			and ability:GetCooldownTimeRemaining() <= 0
			and ability:GetManaCost() <= unit:GetMana()
		then
			if DotaTime() >= (unit._silenceDispelLogAt or -999) then
				unit._silenceDispelLogAt = DotaTime() + 5
				pcall(
					print,
					string.format(
						"[OHA-ITEM] t=%.0f %s silence-dispel-wanted spell=%s",
						DotaTime(),
						(string.gsub(unit:GetUnitName(), "npc_dota_hero_", "")),
						ability:GetName()
					)
				)
			end
			return true
		end
	end
	return false
end
Usage.ConsiderItemDesire["item_cyclone"] = function(item)
	local castRange = 650 + castRangeBonus
	local castType = "unit"
	local hEffectTarget = nil
	local castReason = nil
	local enemyHeroes = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	if bot:HasModifier("modifier_nyx_assassin_vendetta") then
		return BOT_ACTION_DESIRE_NONE
	end
	-- Doomed: a self-cyclone is 2.5s invulnerable (Valve data), so it skips ~2 Doom ticks and
	-- any other damage in that window. Used when hurt or under fire.
	if Usage.IsDoomed(bot) and (Fu.GetHP(bot) < 0.5 or bot:WasRecentlyDamagedByAnyHero(1.5)) then
		pcall(
			print,
			string.format(
				"[OHA-ITEM] t=%.0f %s cyclone-self why=doom hp=%.2f",
				DotaTime(),
				(string.gsub(botName, "npc_dota_hero_", "")),
				Fu.GetHP(bot)
			)
		)
		return BOT_ACTION_DESIRE_HIGH, bot, castType, "doom"
	end
	if
		Fu.IsValid(botTarget)
		and Fu.CanCastOnNonMagicImmune(botTarget)
		and Usage.IsWithoutSpellShield(botTarget)
		and Fu.IsInRange(bot, botTarget, castRange + 200)
	then
		if botName == "npc_dota_hero_invoker" and Fu.IsGoingOnSomeone(bot) then
			if Fu.IsValidHero(botTarget) and not Fu.IsSuspiciousIllusion(botTarget) and Fu.GetMP(bot) > 0.5 then
				hEffectTarget = botTarget
				castReason = "预设连招:" .. Fu.Chat.GetNormName(hEffectTarget)
				return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
			end
		end
		if
			botTarget:HasModifier("modifier_invoker_cold_snap_freeze")
			or botTarget:HasModifier("modifier_invoker_cold_snap")
			or botTarget:HasModifier("modifier_invoker_chaos_meteor_burn")
		then
			return BOT_ACTION_DESIRE_NONE
		end
		if
			botTarget:HasModifier("modifier_teleporting")
			or botTarget:HasModifier("modifier_abaddon_borrowed_time")
			or botTarget:HasModifier("modifier_ursa_enrage")
			or botTarget:HasModifier("modifier_item_satanic_unholy")
			or botTarget:IsChanneling()
		then
			hEffectTarget = botTarget
			castReason = "驱散Buff:" .. Fu.Chat.GetNormName(hEffectTarget)
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
		end
		if Fu.GetHP(botTarget) > 0.49 and Fu.IsCastingUltimateAbility(botTarget) then
			hEffectTarget = botTarget
			castReason = "打断大招:" .. Fu.Chat.GetNormName(hEffectTarget)
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
		end
		if Fu.IsRunning(botTarget) and botTarget:GetCurrentMovementSpeed() > 440 then
			hEffectTarget = botTarget
			castReason = "阻止逃跑:" .. Fu.Chat.GetNormName(hEffectTarget)
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
		end
	end
	if Fu.CanCastOnNonMagicImmune(bot) and #nearbyEnemies > 0 then
		if Fu.GetHP(bot) < 0.2 and bot:WasRecentlyDamagedByAnyHero(3.0) then
			hEffectTarget = bot
			castReason = "撤退:" .. Fu.Chat.GetNormName(hEffectTarget)
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
		end
		if bot:IsRooted() or Usage.SilenceBlocksASpell(bot) and not Usage.IsDoomed(bot) then
			hEffectTarget = bot
			castReason = "解缠绕:" .. Fu.Chat.GetNormName(hEffectTarget)
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
		end
		if Fu.IsUnitTargetProjectileIncoming(bot, 800) then
			hEffectTarget = bot
			castReason = "防御弹道:" .. Fu.Chat.GetNormName(hEffectTarget)
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
Usage.ConsiderItemDesire["item_wind_waker"] = function(item)
	return Usage.ConsiderItemDesire["item_cyclone"](item)
end
Usage.ConsiderItemDesire["item_dagon"] = function(item)
	local castRange = item:GetCastRange() + castRangeBonus
	local castType = "unit"
	local hEffectTarget = nil
	local castReason = nil
	local enemyHeroes = Fu.GetNearbyHeroes(bot, castRange + 100, true, BOT_MODE_NONE)
	local damage = item:GetSpecialValueInt("damage")
	if bot:HasModifier("modifier_nyx_assassin_vendetta") then
		return BOT_ACTION_DESIRE_NONE
	end
	for _, enemy in pairs(enemyHeroes) do
		if
			Fu.IsValidHero(enemy)
			and Fu.CanCastOnNonMagicImmune(enemy)
			and Usage.IsWithoutSpellShield(enemy)
			and Fu.CanKillTarget(enemy, damage, DAMAGE_TYPE_MAGICAL)
		then
			hEffectTarget = enemy
			castReason = "击杀:" .. Fu.Chat.GetNormName(hEffectTarget)
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidHero(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Usage.IsWithoutSpellShield(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
		then
			hEffectTarget = botTarget
			castReason = "进攻:" .. Fu.Chat.GetNormName(hEffectTarget)
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
Usage.ConsiderItemDesire["item_dagon_2"] = function(item)
	return Usage.ConsiderItemDesire["item_dagon"](item)
end
Usage.ConsiderItemDesire["item_dagon_3"] = function(item)
	return Usage.ConsiderItemDesire["item_dagon"](item)
end
Usage.ConsiderItemDesire["item_dagon_4"] = function(item)
	return Usage.ConsiderItemDesire["item_dagon"](item)
end
Usage.ConsiderItemDesire["item_dagon_5"] = function(item)
	return Usage.ConsiderItemDesire["item_dagon"](item)
end
Usage.ConsiderItemDesire["item_diffusal_blade"] = function(item)
	local castRange = 630 + castRangeBonus
	local castType = "unit"
	local hEffectTarget = nil
	local castReason = nil
	local enemyHeroes = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	if botMode == BOT_MODE_RETREAT then
		for _, enemy in pairs(nearbyEnemies) do
			if
				Fu.IsValid(enemy)
				and Fu.IsMoving(enemy)
				and Fu.IsInRange(enemy, bot, castRange)
				and bot:WasRecentlyDamagedByHero(enemy, 4.0)
				and enemy:GetCurrentMovementSpeed() > 200
				and Fu.CanCastOnNonMagicImmune(enemy)
				and Usage.IsWithoutSpellShield(enemy)
				and not Fu.IsDisabled(enemy)
			then
				hEffectTarget = enemy
				castReason = "撤退:" .. Fu.Chat.GetNormName(hEffectTarget)
				return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
			end
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidHero(botTarget)
			and Fu.IsMoving(botTarget)
			and botTarget:GetCurrentMovementSpeed() > 200
			and Fu.IsInRange(botTarget, bot, castRange)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Usage.IsWithoutSpellShield(botTarget)
			and not Fu.IsDisabled(botTarget)
		then
			hEffectTarget = botTarget
			castReason = "进攻:" .. Fu.Chat.GetNormName(hEffectTarget)
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
		end
	end
	if
		Fu.IsValidHero(botTarget)
		and Fu.IsInRange(botTarget, bot, castRange)
		and Fu.CanCastOnNonMagicImmune(botTarget)
		and Usage.IsWithoutSpellShield(botTarget)
		and not Fu.IsDisabled(botTarget)
		and bot:GetAttackTarget() == botTarget
	then
		hEffectTarget = botTarget
		return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, "diffusal: in combat"
	end
	local firstEnemy = nearbyEnemies[1]
	if
		Fu.IsValidHero(firstEnemy)
		and Fu.IsInRange(bot, firstEnemy, castRange - 100)
		and Fu.CanCastOnNonMagicImmune(firstEnemy)
		and Usage.IsWithoutSpellShield(firstEnemy)
		and not Fu.IsDisabled(firstEnemy)
		and Fu.IsMoving(firstEnemy)
		and Fu.IsRunning(firstEnemy)
		and firstEnemy:GetCurrentMovementSpeed() > bot:GetCurrentMovementSpeed() * 0.8
	then
		hEffectTarget = firstEnemy
		castReason = "减速:" .. Fu.Chat.GetNormName(hEffectTarget)
		return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
	end
	return BOT_ACTION_DESIRE_NONE
end
Usage.ConsiderItemDesire["item_enchanted_mango"] = function(item)
	local castType = "none"
	local hEffectTarget = nil
	local castReason = nil
	-- Game data: Mango restores 100 mana. Also eat it below 30% mana once the 100 fits, so a late-game
	-- pool (Slark, game 036) does not have to fall under 150 first.
	if bot:GetMana() < 150 or Fu.GetMP(bot) < 0.3 and bot:GetMaxMana() - bot:GetMana() >= 100 then
		hEffectTarget = bot
		castReason = "自己吃"
		return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
	end
	return BOT_ACTION_DESIRE_NONE
end
Usage.ConsiderItemDesire["item_ethereal_blade"] = function(item)
	local castRange = 800 + castRangeBonus
	local castType = "unit"
	local hEffectTarget = nil
	local castReason = nil
	local enemyHeroes = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidHero(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.CanCastOnTargetAdvanced(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
		then
			hEffectTarget = botTarget
			castReason = "进攻" .. Fu.Chat.GetNormName(hEffectTarget)
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
Usage.ConsiderItemDesire["item_faerie_fire"] = function(item)
	if bot:DistanceFromFountain() < 1800 then
		return BOT_ACTION_DESIRE_NONE
	end
	local castRange = 300 + castRangeBonus
	local castType = "none"
	local hEffectTarget = nil
	local castReason = nil
	local enemyHeroes = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	if
		botMode == BOT_MODE_RETREAT
		and bot:GetActiveModeDesire() >= BOT_MODE_DESIRE_HIGH
		and bot:WasRecentlyDamagedByAnyHero(3.0)
		and bot:OriginalGetHealth() < 90
	then
		hEffectTarget = bot
		castReason = "撤退"
		return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
	end
	if
		Fu.IsGoingOnSomeone(bot)
		and Fu.GetHP(bot) < 0.3
		and Fu.IsValidHero(botTarget)
		and bot:WasRecentlyDamagedByAnyHero(3.0)
	then
		hEffectTarget = bot
		castReason = "进攻"
		return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
	end
	if
		DotaTime() > 10 * 60
		and item:GetName() == "item_faerie_fire"
		and bot:GetItemInSlot(6) ~= nil
		and bot:GetMaxHealth() - bot:OriginalGetHealth() > 200
	then
		hEffectTarget = bot
		castReason = "自己吃"
		return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
	end
	return BOT_ACTION_DESIRE_NONE
end
Usage.ConsiderItemDesire["item_flask"] = function(item)
	if bot:DistanceFromFountain() < 3000 then
		return BOT_ACTION_DESIRE_NONE
	end
	if Fu.HasDamageOverTimeDebuff(bot) then
		return BOT_ACTION_DESIRE_NONE
	end
	local castRange = 900
	local castType = "unit"
	local hEffectTarget = nil
	local castReason = nil
	local enemyHeroes = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	local hpRatio = Fu.GetHP(bot)
	if
		hpRatio < 0.65
		and #enemyHeroes == 0
		and not bot:WasRecentlyDamagedByAnyHero(2.2)
		and not bot:HasModifier("modifier_filler_heal")
		and not bot:HasModifier("modifier_elixer_healing")
		and not bot:HasModifier("modifier_flask_healing")
		and not bot:HasModifier("modifier_juggernaut_healing_ward_heal")
	then
		hEffectTarget = bot
		castReason = "自己吃"
		return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
	end
	local allyHeroes = Fu.GetAlliesNearLoc(bot:GetLocation(), 700)
	local bestAlly = nil
	local lowestHealth = 99999
	for _, ally in pairs(allyHeroes) do
		if
			Fu.IsValid(ally)
			and ally ~= bot
			and not ally:HasModifier("modifier_filler_heal")
			and not ally:HasModifier("modifier_elixer_healing")
			and not ally:HasModifier("modifier_flask_healing")
			and not ally:HasModifier("modifier_juggernaut_healing_ward_heal")
			and not ally:WasRecentlyDamagedByAnyHero(3.0)
			and not ally:IsIllusion()
			and not ally:IsChanneling()
			and Fu.GetHP(ally) < 0.6
		then
			if ally:OriginalGetHealth() < lowestHealth then
				bestAlly = ally
				lowestHealth = ally:OriginalGetHealth()
			end
		end
	end
	if bestAlly ~= nil and #enemyHeroes == 0 then
		hEffectTarget = bestAlly
		castReason = "给队友贴:" .. Fu.Chat.GetNormName(hEffectTarget)
		return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
	end
	return BOT_ACTION_DESIRE_NONE
end
-- Healing Lotus (item_famango*) — not Lotus Orb. Cannot be sold; use on self or ally (ctrl-click, ~400 range).
-- Pool pickup: supports first, cores low priority. Use: prefer ally if their HP/mana dropped, else self.
-- Late game + full bag: consume (or leave for purchase drop) to free a slot even at high HP/MP.
local function ConsiderHealingLotus(item, label, selfHp, selfMp, allyNeed, fountainDist)
	if bot:DistanceFromFountain() < fountainDist then
		return BOT_ACTION_DESIRE_NONE
	end
	local castType = "unit"
	local enemies = Fu.GetNearbyHeroes(bot, 900, true, BOT_MODE_NONE) or {}
	local hp = Fu.GetHP(bot)
	local mp = bot:GetMaxMana() > 0 and bot:GetMana() / bot:GetMaxMana() or 1
	local isSupport = Fu.GetPosition(bot) >= 4
	-- Only supports (or anyone in real emergency) share/use these liberally.
	local hpGate = isSupport and selfHp or math.max(0.32, selfHp - 0.2)
	local mpGate = isSupport and selfMp or math.max(0.22, selfMp - 0.2)
	local lateGame = (GetGameMode() == GAMEMODE_TURBO or GetGameMode() == 23) and (15 * 60) or (25 * 60)
	local bagFull = Fu.Item.GetEmptyNonBackpackInventoryAmount(bot) <= 0

	-- Ally first when their HP/mana dropped (ctrl+click, range 400).
	local allies = Fu.GetAlliesNearLoc(bot:GetLocation(), 400) or {}
	local bestAlly = nil
	local bestScore = -1
	for _, ally in pairs(allies) do
		if
			Fu.IsValid(ally)
			and ally ~= bot
			and not ally:IsIllusion()
			and not ally:HasModifier("modifier_flask_healing")
			and not ally:HasModifier("modifier_filler_heal")
		then
			local aHp = ally:GetHealth() / math.max(1, ally:GetMaxHealth())
			local aMp = ally:GetMaxMana() > 0 and ally:GetMana() / ally:GetMaxMana() or 1
			local need = aHp < allyNeed or aMp < allyNeed
			local urgent = aHp < 0.4 or (aHp < 0.55 and aMp < 0.35)
			if need or urgent then
				-- Prefer helping even with enemies around if urgent; otherwise wait for calm.
				if urgent or #enemies == 0 then
					local score = (1 - aHp) * 1.2 + (1 - aMp) * 0.7
					if urgent then
						score = score + 0.5
					end
					-- Prefer the neediest ally (cores in a fight are fine targets).
					if Fu.IsCore(ally) then
						score = score + 0.15
					end
					if score > bestScore then
						bestScore = score
						bestAlly = ally
					end
				end
			end
		end
	end
	-- Ally in need beats self top-up (unless we're about to die).
	if bestAlly ~= nil and hp >= 0.28 then
		return BOT_ACTION_DESIRE_HIGH,
			bestAlly,
			castType,
			"Heal ally (" .. label .. "): " .. Fu.Chat.GetNormName(bestAlly)
	end

	-- Emergency self.
	if hp < 0.28 or (hp < 0.4 and mp < 0.25) then
		return BOT_ACTION_DESIRE_HIGH, bot, castType, "Emergency self (" .. label .. ")"
	end
	-- Self when low and no needy ally.
	if
		(hp < hpGate or mp < mpGate)
		and #enemies == 0
		and not bot:WasRecentlyDamagedByAnyHero(2.0)
		and not bot:HasModifier("modifier_flask_healing")
		and not bot:HasModifier("modifier_filler_heal")
	then
		return BOT_ACTION_DESIRE_HIGH, bot, castType, "Self heal (" .. label .. ")"
	end
	-- Late game, main inventory full: consume to free a slot (cannot sell).
	-- Step 0: if greater famango can still stack (2+ piles), skip consume — purchase path merges.
	if
		DotaTime() >= lateGame
		and bagFull
		and #enemies == 0
		and not bot:WasRecentlyDamagedByAnyHero(2.0)
		and not bot:HasModifier("modifier_flask_healing")
	then
		-- Step 0: leave incomplete greater stacks alone if they can still merge (purchase merges).
		if Fu.Item.CanStackGreaterFamango(bot) then
			return BOT_ACTION_DESIRE_NONE
		end
		if item ~= nil and item:GetName() == "item_greater_famango" then
			local charges = Fu.Item.GetLotusCharges(item)
			local freeName = Fu.Item.FindLotusToFreeSlot(bot)
			-- Prefer consuming a lower-tier / full stack over an incomplete greater pile.
			if
				charges < Fu.Item.GREATER_FAMANGO_MAX_STACK
				and freeName ~= nil
				and freeName ~= "item_greater_famango"
			then
				return BOT_ACTION_DESIRE_NONE
			end
		end
		if hp >= 0.9 and mp >= 0.85 then
			return BOT_ACTION_DESIRE_HIGH, bot, castType, "Free slot (" .. label .. ", full)"
		end
		-- Still packed but not full resources — use it, then the slot opens.
		if hp < 0.95 or mp < 0.9 then
			return BOT_ACTION_DESIRE_MODERATE, bot, castType, "Free slot (" .. label .. ")"
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
Usage.ConsiderItemDesire["item_famango"] = function(item)
	return ConsiderHealingLotus(item, "lotus", 0.72, 0.55, 0.65, 2800)
end
Usage.ConsiderItemDesire["item_great_famango"] = function(item)
	return ConsiderHealingLotus(item, "great lotus", 0.65, 0.45, 0.58, 2800)
end
Usage.ConsiderItemDesire["item_greater_famango"] = function(item)
	return ConsiderHealingLotus(item, "greater lotus", 0.55, 0.35, 0.5, 1000)
end
Usage.ConsiderItemDesire["item_force_staff"] = function(item)
	local castRange = 550 + castRangeBonus
	local castType = "unit"
	local hEffectTarget = nil
	local castReason = nil
	local enemyHeroes = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	if bot:HasModifier("modifier_nyx_assassin_vendetta") then
		return BOT_ACTION_DESIRE_NONE
	end
	if bot:HasModifier("modifier_furion_sprout_damage") then
		hEffectTarget = bot
		castReason = "解开先知的树框" .. Fu.Chat.GetNormName(hEffectTarget)
		return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
	end
	local allyHeroes = Fu.GetAlliesNearLoc(bot:GetLocation(), 600)
	for _, ally in pairs(allyHeroes) do
		if ally ~= nil and ally:IsAlive() and Fu.CanCastOnNonMagicImmune(ally) then
			local enemiesNearAlly = Fu.GetNearbyHeroes(ally, 1200, true, BOT_MODE_NONE)
			if
				#enemiesNearAlly >= 1
				and not ally:IsInvisible()
				and ally:GetActiveMode() == BOT_MODE_RETREAT
				and ally:IsFacingLocation(GetAncient(team):GetLocation(), 30)
				and ally:DistanceFromFountain() > 600
				and ally:WasRecentlyDamagedByAnyHero(4.0)
			then
				hEffectTarget = ally
				castReason = "帮队友撤退" .. Fu.Chat.GetNormName(hEffectTarget)
				return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
			end
			if Fu.IsGoingOnSomeone(ally) then
				local allyTarget = Fu.GetProperTarget(ally)
				if
					Fu.IsValidHero(allyTarget)
					and ally:IsFacingLocation(allyTarget:GetLocation(), 15)
					and Fu.CanCastOnNonMagicImmune(allyTarget)
					and GetUnitToUnitDistance(allyTarget, ally) > ally:GetAttackRange() + 50
					and GetUnitToUnitDistance(allyTarget, ally) < ally:GetAttackRange() + 700
					and not allyTarget:IsFacingLocation(ally:GetLocation(), 40)
					and Fu.GetEnemyCount(ally, 1600) <= 3
				then
					hEffectTarget = ally
					castReason = "帮队友进攻" .. Fu.Chat.GetNormName(hEffectTarget)
					return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
				end
			end
			if Fu.IsStuck(ally) or ally:HasModifier("modifier_furion_sprout_damage") then
				hEffectTarget = ally
				castReason = "队友卡地形了" .. Fu.Chat.GetNormName(hEffectTarget)
				return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
			end
		end
	end
	for _, ally in pairs(allyHeroes) do
		if
			ally ~= nil
			and ally:IsAlive()
			and ally:GetUnitName() == "npc_dota_hero_crystal_maiden"
			and Fu.CanCastOnNonMagicImmune(ally)
			and (ally:IsInvisible() or ally:GetHealth() / ally:GetMaxHealth() > 0.8)
			and (ally:IsChanneling() and not ally:HasModifier("modifier_teleporting"))
		then
			local enemiesNearAlly = Fu.GetNearbyHeroes(ally, 1200, true, BOT_MODE_NONE)
			for _, enemy in pairs(enemiesNearAlly) do
				if
					enemy ~= nil
					and enemy:IsAlive()
					and Fu.CanCastOnNonMagicImmune(enemy)
					and GetUnitToUnitDistance(enemy, ally) > 835
					and ally:IsFacingLocation(enemy:GetLocation(), 30)
				then
					hEffectTarget = ally
					castReason = "推冰女"
					return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
				end
			end
		end
	end
	if bot:DistanceFromFountain() < 2600 then
		for _, enemy in pairs(nearbyEnemies) do
			if
				Fu.IsValidHero(enemy)
				and Fu.CanCastOnMagicImmune(enemy)
				and enemy:IsFacingLocation(GetAncient(team):GetLocation(), 40)
				and GetUnitToLocationDistance(enemy, GetAncient(team):GetLocation()) < 1200
			then
				hEffectTarget = enemy
				castReason = "推人入泉" .. Fu.Chat.GetNormName(hEffectTarget)
				return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
			end
		end
	end
	if Fu.IsGoingOnSomeone(bot) and #allyHeroes >= 2 then
		if
			Fu.IsValidHero(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Usage.IsWithoutSpellShield(botTarget)
		then
			local allyCenter = Fu.GetCenterOfUnits(allyHeroes)
			if botTarget:IsFacingLocation(allyCenter, 28) and GetUnitToLocationDistance(bot, allyCenter) >= 500 then
				hEffectTarget = botTarget
				castReason = "推敌人靠近自己" .. Fu.Chat.GetNormName(hEffectTarget)
				return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
Usage.ConsiderItemDesire["item_ghost"] = function(item)
	local castRange = 800
	local castType = "none"
	local hEffectTarget = nil
	local castReason = nil
	local enemyHeroes = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	-- A right-click carry is on me. Ghost now, before the 500 HP line below.
	for _, enemy in pairs(nearbyEnemies) do
		if
			Fu.IsValidHero(enemy)
			and Fu.tRightclickMenace[enemy:GetUnitName()]
			and not Fu.IsSuspiciousIllusion(enemy)
			and enemy:GetAttackTarget() == bot
			and Fu.GetHP(bot) < 0.75
		then
			return BOT_ACTION_DESIRE_HIGH, enemy, castType, "ghost vs carry"
		end
	end
	if bot:GetAttackTarget() == nil or bot:GetHealth() < 500 then
		for _, enemy in pairs(nearbyEnemies) do
			if
				Fu.IsValidHero(enemy)
				and Fu.CanCastOnMagicImmune(enemy)
				and Fu.IsInRange(bot, enemy, enemy:GetAttackRange() + 100)
				and enemy:GetAttackTarget() == bot
				and bot:WasRecentlyDamagedByHero(enemy, 2.0)
				and enemy:GetAttackDamage() > bot:GetAttackDamage()
			then
				hEffectTarget = enemy
				castReason = "撤退" .. Fu.Chat.GetNormName(hEffectTarget)
				return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
Usage.ConsiderItemDesire["item_crellas_crozier"] = function(item)
	local castRange = 800
	local castType = "none"
	local hEffectTarget = nil
	local castReason = nil
	if bot:GetAttackTarget() == nil or bot:GetHealth() < 500 then
		for _, enemy in pairs(nearbyEnemies) do
			if
				Fu.IsValidHero(enemy)
				and Fu.CanCastOnMagicImmune(enemy)
				and Fu.IsInRange(bot, enemy, enemy:GetAttackRange() + 100)
				and enemy:GetAttackTarget() == bot
				and bot:WasRecentlyDamagedByHero(enemy, 2.0)
				and enemy:GetAttackDamage() > bot:GetAttackDamage()
			then
				hEffectTarget = enemy
				castReason = "撤退" .. Fu.Chat.GetNormName(hEffectTarget)
				return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
-- Witch Doctor innate: cash out Gris-Gris when packed and needing space/gold.
-- item_grisgris is often IsPassive/IsHidden so CanCastAbility never lets ConsiderItemDesire fire.
Usage.ConsiderItemDesire["item_grisgris"] = function(item)
	return BOT_ACTION_DESIRE_NONE
end

local GRISGRIS_KEEP = {
	item_grisgris = true,
	item_aegis = true,
	item_rapier = true,
	item_gem = true,
	item_cheese = true,
	item_refresher_shard = true,
	item_tpscroll = true,
	item_ward_observer = true,
	item_ward_sentry = true,
	item_ward_dispenser = true,
	item_smoke_of_deceit = true,
}

local function FindGrisGrisSlot()
	for slot = 0, 16 do
		local item = bot:GetItemInSlot(slot)
		if item ~= nil and not item:IsNull() and item:GetName() == "item_grisgris" then
			return slot, item
		end
	end
	return -1, nil
end

local function PendingBuyName()
	local pendingName = bot.currBuyingBasicItem
	if pendingName == nil and type(bot.currBuyingBasicItemList) == "table" and #bot.currBuyingBasicItemList > 0 then
		pendingName = bot.currBuyingBasicItemList[#bot.currBuyingBasicItemList]
	end
	if pendingName == nil then
		pendingName = bot.currBuyingItemInPurchaseList
	end
	if pendingName == "item_aghanims_shard" then
		return nil
	end
	return pendingName
end

local function InventoryIsPacked()
	return Fu.Item.GetEmptyNonBackpackInventoryAmount(bot) <= 0
end

local function BackpackIsPacked()
	return Fu.Item.GetEmptyBackpackSlot(bot) < 0
end

-- Sell cheapest non-critical item in slots 0-8 so we can shuffle Gris-Gris into a main slot.
local function SellCheapestJunkForGrisGris()
	local bestItem = nil
	local bestCost = 999999
	for slot = 0, 8 do
		local item = bot:GetItemInSlot(slot)
		if item ~= nil and not item:IsNull() then
			local name = item:GetName()
			if not GRISGRIS_KEEP[name] and not string.find(name, "token") then
				local cost = GetItemCost(name) or 0
				if cost < bestCost then
					bestCost = cost
					bestItem = item
				end
			end
		end
	end
	if bestItem == nil then
		return false
	end
	bot:ActionImmediate_SellItem(bestItem)
	return true
end

local function FreeMainSlotForGrisGris()
	local pack = Fu.Item.GetEmptyBackpackSlot(bot)
	if pack < 0 then
		if not SellCheapestJunkForGrisGris() then
			return -1
		end
		pack = Fu.Item.GetEmptyBackpackSlot(bot)
		if pack < 0 then
			-- Sold a main-slot item; find the empty main slot.
			for main = 0, 5 do
				if bot:GetItemInSlot(main) == nil then
					return main
				end
			end
			return -1
		end
	end
	for main = 0, 5 do
		local item = bot:GetItemInSlot(main)
		if item ~= nil and item:GetName() ~= "item_grisgris" then
			bot:ActionImmediate_SwapItems(main, pack)
			return main
		end
	end
	return -1
end

local function TeamUnderPush()
	local ancient = GetAncient(GetTeam())
	if ancient ~= nil and Fu.Utils.CountEnemyHeroesNear(ancient:GetLocation(), 3200) >= 1 then
		return true
	end
	if Fu.Utils.CountEnemyHeroesOnHighGround(GetTeam()) >= 1 then
		return true
	end
	-- High defend desire = lanes/base getting shoved.
	if Fu.IsDefending(bot) and (bot:GetActiveModeDesire() or 0) >= BOT_MODE_DESIRE_HIGH then
		return true
	end
	local maxDefend = math.max(
		GetDefendLaneDesire(LANE_TOP) or 0,
		GetDefendLaneDesire(LANE_MID) or 0,
		GetDefendLaneDesire(LANE_BOT) or 0
	)
	return maxDefend >= 0.55
end

local function AnnounceGrisGrisAllChat(reason)
	local key = "say_consume_grisgris"
	if reason and string.find(reason, "push") then
		key = "say_consume_grisgris_push"
	end
	local chatLines = Localization.Get(key)
	if (chatLines == nil or (type(chatLines) == "table" and #chatLines == 0)) and key ~= "say_consume_grisgris" then
		chatLines = Localization.Get("say_consume_grisgris")
	end
	local msg = nil
	if type(chatLines) == "table" and #chatLines > 0 then
		msg = chatLines[RandomInt(1, #chatLines)]
	elseif type(chatLines) == "string" then
		msg = chatLines
	else
		msg = "Consuming Gris-Gris!"
	end
	-- true = all-chat
	bot:ActionImmediate_Chat(msg, true)
	MatchTrace.Item(bot, "item_grisgris", "announce", reason or "")
end

-- Right-click → Consume equivalent for bots is Action_UseAbility on the item handle.
-- Gris-Gris is NOT sellable (ItemSellable=0); SellItem will not cash it out.
local function DoConsumeGrisGris(gris, slot, reason)
	bot._grisGrisConsumeAt = DotaTime()
	AnnounceGrisGrisAllChat(reason)
	-- Move into a main slot when possible; consume orders from slot 16 are unreliable.
	if slot == 16 or slot >= 6 then
		local freed = FreeMainSlotForGrisGris()
		if freed >= 0 then
			local cur = FindGrisGrisSlot()
			if cur == 16 or cur >= 6 then
				bot:ActionImmediate_SwapItems(cur, freed)
			end
			slot, gris = FindGrisGrisSlot()
		end
	end
	if gris == nil then
		return false
	end
	bot:Action_ClearActions(false)
	bot:Action_UseAbility(gris)
	MatchTrace.Item(bot, "item_grisgris", "consume", string.format("%s slot=%d", reason or "", slot or -1))
	return true
end

-- Early packed bags are starting consumables, not a reason to cash Gris-Gris.
local function GrisGrisMinGameTime()
	-- ~15m normal; turbo compresses the clock (~9m).
	if GetGameMode() == GAMEMODE_TURBO or GetGameMode() == 23 then
		return 9 * 60
	end
	return 15 * 60
end

function Usage.TryConsumeGrisGris()
	if botName ~= "npc_dota_hero_witch_doctor" then
		return false
	end
	if not bot:IsAlive() or bot:IsMuted() or bot:IsHexed() or bot:IsStunned() or bot:IsChanneling() then
		return false
	end
	if DotaTime() < GrisGrisMinGameTime() then
		return false
	end
	if bot._grisGrisConsumeAt ~= nil and DotaTime() - bot._grisGrisConsumeAt < 6.0 then
		return false
	end
	local slot, gris = FindGrisGrisSlot()
	if gris == nil then
		return false
	end
	local buyName = PendingBuyName()
	local bagFull = BackpackIsPacked()
	local underPush = TeamUnderPush()
	local packed = InventoryIsPacked()
	-- 1) Team getting pushed → cash gold for buyback/items (even if inv not full).
	-- 2) Packed + pending buy / bag full → free value when stuck.
	if underPush then
		return DoConsumeGrisGris(gris, slot, "push")
	end
	if not packed then
		return false
	end
	if buyName == nil and not bagFull then
		return false
	end
	return DoConsumeGrisGris(
		gris,
		slot,
		string.format("packed buy=%s bagFull=%s", tostring(buyName), tostring(bagFull))
	)
end
Usage.ConsiderItemDesire["item_glimmer_cape"] = function(item)
	local castRange = 800 + castRangeBonus
	local castType = "unit"
	local hEffectTarget = nil
	local castReason = nil
	if
		bot:DistanceFromFountain() > 600
		and #nearbyEnemyTowers == 0
		and not bot:HasModifier("modifier_item_dustofappearance")
		and not bot:HasModifier("modifier_slardar_amplify_damage")
		and not bot:HasModifier("modifier_item_glimmer_cape")
		and not bot:IsInvulnerable()
		and not bot:IsMagicImmune()
	then
		if bot:IsSilenced() or bot:IsRooted() or Fu.IsStunProjectileIncoming(bot, 1000) then
			hEffectTarget = bot
			castReason = "自己被缠绕或沉默了"
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
		end
		if
			Fu.IsRetreating(bot)
				and bot:GetActiveModeDesire() >= BOT_MODE_DESIRE_HIGH
				and not bot:HasModifier("modifier_fountain_aura")
			or botTarget == nil and #nearbyEnemies > 0 and Fu.GetHP(bot) < 0.36 + 0.09 * #nearbyEnemies
		then
			hEffectTarget = bot
			castReason = "自己撤退"
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
		end
		local allyHeroes = Fu.GetNearbyHeroes(bot, castRange, false, BOT_MODE_NONE)
		for _, ally in pairs(allyHeroes) do
			if
				Fu.IsValid(ally)
				and not ally:IsIllusion()
				and not ally:IsMagicImmune()
				and not ally:IsInvulnerable()
				and not ally:IsInvisible()
				and ally:DistanceFromFountain() > 600
				and not ally:HasModifier("modifier_item_glimmer_cape")
				and not ally:HasModifier("modifier_item_dustofappearance")
				and not ally:HasModifier("modifier_slardar_amplify_damage")
				and not ally:HasModifier("modifier_arc_warden_tempest_double")
			then
				local allyNearbyEnemyTowers = ally:GetNearbyTowers(888, true)
				if #allyNearbyEnemyTowers == 0 then
					if
						Fu.GetHP(ally) < 0.35 + 0.05 * #nearbyEnemies
						and Fu.IsRetreating(ally)
						and ally:WasRecentlyDamagedByAnyHero(4.0)
					then
						hEffectTarget = ally
						castReason = "保护队友撤退:" .. Fu.Chat.GetNormName(hEffectTarget)
						return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
					end
					if Fu.IsDisabled(ally) or Fu.IsStunProjectileIncoming(ally, 1000) then
						hEffectTarget = ally
						castReason = "保护被控队友:" .. Fu.Chat.GetNormName(hEffectTarget)
						return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
					end
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
Usage.ConsiderItemDesire["item_mekansm"] = function(item)
	local radius = 1200
	local castType = "none"
	local hEffectTarget = nil
	local castReason = nil
	local allyHeroes = Fu.GetAllyList(bot, radius)
	for _, ally in pairs(allyHeroes) do
		if ally ~= nil and ally:IsAlive() and Fu.GetHP(ally) < 0.45 and #nearbyEnemies > 0 then
			hEffectTarget = ally
			castReason = "治疗队友" .. Fu.Chat.GetNormName(hEffectTarget)
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
		end
	end
	local injuredAllyCount = 0
	for _, ally in pairs(allyHeroes) do
		if ally ~= nil and ally:GetMaxHealth() - ally:GetHealth() > 400 then
			injuredAllyCount = injuredAllyCount + 1
			if injuredAllyCount >= 2 and ally:GetHealth() / ally:GetMaxHealth() < 0.55 then
				hEffectTarget = ally
				castReason = "治疗二队友:" .. Fu.Chat.GetNormName(hEffectTarget)
				return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
			end
			if injuredAllyCount >= 3 then
				hEffectTarget = ally
				castReason = "治疗多个队友:" .. Fu.Chat.GetNormName(hEffectTarget)
				return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
			end
		end
	end
	if
		not Usage.IsDoomed(bot)
		and (
			bot:GetHealth() / bot:GetMaxHealth() < 0.5
			or bot:IsSilenced()
			or bot:IsRooted()
			or bot:HasModifier("modifier_item_urn_damage")
			or bot:HasModifier("modifier_item_spirit_vessel_damage")
		)
	then
		hEffectTarget = bot
		castReason = "治疗自己:" .. Fu.Chat.GetNormName(hEffectTarget)
		return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
	end
	return BOT_ACTION_DESIRE_NONE
end
Usage.ConsiderItemDesire["item_guardian_greaves"] = function(item)
	local radius = 1200
	local castType = "none"
	local hEffectTarget = nil
	local castReason = nil
	local allyHeroes = Fu.GetAllyList(bot, radius)
	for _, ally in pairs(allyHeroes) do
		if ally ~= nil and ally:IsAlive() and Fu.GetHP(ally) < 0.45 and #nearbyEnemies > 0 then
			hEffectTarget = ally
			castReason = "治疗队友" .. Fu.Chat.GetNormName(hEffectTarget)
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
		end
	end
	local injuredAllyCount = 0
	for _, ally in pairs(allyHeroes) do
		if ally ~= nil and ally:GetMaxHealth() - ally:GetHealth() > 400 then
			injuredAllyCount = injuredAllyCount + 1
			if injuredAllyCount >= 2 and ally:GetHealth() / ally:GetMaxHealth() < 0.55 then
				hEffectTarget = ally
				castReason = "治疗二队友:" .. Fu.Chat.GetNormName(hEffectTarget)
				return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
			end
			if injuredAllyCount >= 3 then
				hEffectTarget = ally
				castReason = "治疗多个队友:" .. Fu.Chat.GetNormName(hEffectTarget)
				return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
			end
		end
	end
	if
		not Usage.IsDoomed(bot)
		and (
			bot:GetHealth() / bot:GetMaxHealth() < 0.5
			or bot:IsSilenced()
			or bot:IsRooted()
			or bot:HasModifier("modifier_item_urn_damage")
			or bot:HasModifier("modifier_item_spirit_vessel_damage")
		)
	then
		hEffectTarget = bot
		castReason = "治疗自己:" .. Fu.Chat.GetNormName(hEffectTarget)
		return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
	end
	local manaLackingAllyCount = 0
	for _, ally in pairs(allyHeroes) do
		if ally ~= nil and ally:GetMaxMana() - ally:GetMana() > 400 then
			manaLackingAllyCount = manaLackingAllyCount + 1
		end
		if manaLackingAllyCount >= 2 and bot:GetMana() / bot:GetMaxMana() < 0.2 then
			hEffectTarget = ally
			castReason = "回蓝二队友:" .. Fu.Chat.GetNormName(hEffectTarget)
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
		end
		if manaLackingAllyCount >= 3 then
			hEffectTarget = ally
			castReason = "回蓝多个队友:" .. Fu.Chat.GetNormName(hEffectTarget)
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
		end
	end
	local allyLaneCreeps = bot:GetNearbyLaneCreeps(1200, false)
	if #allyLaneCreeps >= 9 then
		local aoeLocation = bot:FindAoELocation(false, false, bot:GetLocation(), 100, 1100, 0, 200)
		if aoeLocation.count >= 6 and GetUnitToLocationDistance(bot, aoeLocation.targetloc) <= 200 then
			hEffectTarget = bot
			castReason = "治疗小兵们:" .. Fu.Chat.GetNormName(hEffectTarget)
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
Usage.ConsiderItemDesire["item_hand_of_midas"] = function(item)
	local castRange = 990 + castRangeBonus
	local castType = "unit"
	local hEffectTarget = nil
	local castReason = nil
	if #nearbyEnemies >= 1 then
		castRange = 628
	end
	-- Game data: unit target, enemy creeps, NOT_ANCIENTS, MAGIC_IMMUNE_ENEMIES allowed, 600 range.
	-- Highest level, then highest max HP (ties used to go to whichever creep was listed first).
	local bestCreep = Fu.GetBestCreepToEat(bot:GetNearbyCreeps(castRange, true), nil, false)
	if bestCreep ~= nil then
		hEffectTarget = bestCreep
		castReason = "点金小兵:" .. hEffectTarget:GetUnitName()
		return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
	end
	return BOT_ACTION_DESIRE_NONE
end
Usage.ConsiderItemDesire["item_heavens_halberd"] = function(item)
	local castRange = 750 + castRangeBonus
	local castType = "unit"
	local hEffectTarget = nil
	local castReason = nil
	local hMenace = Fu.GetRightclickMenaceLock(bot, castRange, "disarm")
	if hMenace ~= nil and Usage.IsWithoutSpellShield(hMenace) then
		return BOT_ACTION_DESIRE_HIGH, hMenace, castType, "disarm carry"
	end
	local enemyHeroes = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	local bestTarget = nil
	local bestDamage = 0
	for _, enemy in pairs(enemyHeroes) do
		if
			Fu.IsValidHero(enemy)
			and not enemy:IsDisarmed()
			and not Fu.IsDisabled(enemy)
			and Fu.CanCastOnNonMagicImmune(enemy)
			and Usage.IsWithoutSpellShield(enemy)
			and enemy:GetAttackTarget() ~= nil
			and (enemy:GetPrimaryAttribute() ~= ATTRIBUTE_INTELLECT or enemy:GetAttackDamage() > 180)
		then
			local estimatedDamage = enemy:GetEstimatedDamageToTarget(false, bot, 3.0, DAMAGE_TYPE_PHYSICAL)
			if estimatedDamage > bestDamage then
				bestDamage = estimatedDamage
				bestTarget = enemy
			end
		end
	end
	if bestTarget ~= nil then
		hEffectTarget = bestTarget
		castReason = "缴械敌人:" .. Fu.Chat.GetNormName(hEffectTarget)
		return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
	end
	if bot:GetActiveMode() == BOT_MODE_ROSHAN then
		local attackTarget = bot:GetAttackTarget()
		if Fu.IsRoshan(attackTarget) and not Fu.IsDisabled(attackTarget) and not attackTarget:IsDisarmed() then
			hEffectTarget = attackTarget
			castReason = "缴械肉山"
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
Usage.ConsiderItemDesire["item_helm_of_the_dominator"] = function(item)
	local castRange = 1000 + castRangeBonus
	local castType = "unit"
	local hEffectTarget = nil
	local castReason = nil
	for _, creep in pairs(GetUnitList(UNIT_LIST_ALLIED_CREEPS)) do
		if Fu.IsValid(creep) and creep:HasModifier("modifier_dominated") and creep:IsAncientCreep() then
			return BOT_ACTION_DESIRE_NONE, hEffectTarget, "sCastType", castReason
		end
	end
	local bestHealth = 0
	local bestCreep = nil
	local enemyCreeps = bot:GetNearbyCreeps(castRange, true)
	if #enemyCreeps >= 2 then
		for _, creep in pairs(enemyCreeps) do
			if Fu.IsValid(creep) then
				local creepHealth = creep:GetHealth()
				if
					creepHealth > bestHealth
					and creep:GetHealth() / creep:GetMaxHealth() > 0.75
					and (not creep:IsAncientCreep() or item:GetName() == "item_helm_of_the_overlord")
					and not Fu.IsKeyWordUnit("siege", creep)
				then
					bestCreep = creep
					bestHealth = creepHealth
				end
			end
		end
	end
	if bestCreep ~= nil then
		hEffectTarget = bestCreep
		castReason = "支配:" .. hEffectTarget:GetUnitName()
		return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
	end
	return BOT_ACTION_DESIRE_NONE
end
Usage.ConsiderItemDesire["item_helm_of_the_overlord"] = function(item)
	return Usage.ConsiderItemDesire["item_helm_of_the_dominator"](item)
end
Usage.ConsiderItemDesire["item_hood_of_defiance"] = function(item)
	if bot:HasModifier("modifier_item_pipe_barrier") or Fu.GetHP(bot) > 0.88 then
		return BOT_ACTION_DESIRE_NONE
	end
	local radius = 1000
	local castType = "none"
	local hEffectTarget = nil
	local castReason = nil
	local enemyHeroes = Fu.GetNearbyHeroes(bot, radius, true, BOT_MODE_NONE)
	if #enemyHeroes > 0 then
		hEffectTarget = bot
		castReason = "套盾"
		return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
	end
	return BOT_ACTION_DESIRE_NONE
end
Usage.ConsiderItemDesire["item_holy_locket"] = function(item)
	return Usage.ConsiderItemDesire["item_magic_wand"](item)
end
Usage.ConsiderItemDesire["item_hurricane_pike"] = function(item)
	local castRange = 800 + castRangeBonus
	local pushRange = 450 + castRangeBonus
	local castType = "unit"
	local hEffectTarget = nil
	local castReason = nil
	local enemyHeroes = Fu.GetNearbyHeroes(bot, pushRange, true, BOT_MODE_NONE)
	if botMode == BOT_MODE_RETREAT and bot:GetActiveModeDesire() > BOT_MODE_DESIRE_HIGH then
		for _, enemy in pairs(nearbyEnemies) do
			if Fu.IsInRange(bot, enemy, pushRange) and Fu.CanCastOnNonMagicImmune(enemy) then
				hEffectTarget = enemy
				castReason = "撤退了推敌人"
				return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
			end
		end
		if
			bot:IsFacingLocation(GetAncient(team):GetLocation(), 20)
			and bot:DistanceFromFountain() > 600
			and #nearbyEnemies >= 1
		then
			hEffectTarget = bot
			castReason = "撤退了推自己"
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidHero(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and GetUnitToUnitDistance(botTarget, bot) > bot:GetAttackRange() + 100
			and GetUnitToUnitDistance(botTarget, bot) < bot:GetAttackRange() + 700
			and GetUnitToUnitDistance(botTarget, bot) < GetUnitToLocationDistance(bot, Fu.GetCorrectLoc(botTarget, 1.0)) - 100
			and bot:IsFacingLocation(botTarget:GetLocation(), 20)
			and not botTarget:IsFacingLocation(bot:GetLocation(), 120)
			and Fu.GetEnemyCount(bot, 1600) <= 2
		then
			hEffectTarget = bot
			castReason = "进攻" .. Fu.Chat.GetNormName(hEffectTarget)
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
		end
	end
	if Fu.HasItem(bot, "item_hurricane_pike") then
		for _, enemy in pairs(nearbyEnemies) do
			if
				enemy ~= nil
				and Fu.CanCastOnNonMagicImmune(enemy)
				and GetUnitToUnitDistance(enemy, bot) <= pushRange
				and Fu.CanCastOnNonMagicImmune(enemy)
			then
				bot:SetTarget(enemy)
				hEffectTarget = enemy
				castReason = "推开" .. Fu.Chat.GetNormName(hEffectTarget)
				return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
			end
		end
	end
	local allyHeroes = Fu.GetNearbyHeroes(bot, castRange, false, BOT_MODE_NONE)
	for _, ally in pairs(allyHeroes) do
		if
			ally ~= nil
			and ally:IsAlive()
			and ally:GetUnitName() == "npc_dota_hero_crystal_maiden"
			and Fu.CanCastOnNonMagicImmune(ally)
			and Usage.IsWithoutSpellShield(ally)
			and (ally:IsInvisible() or ally:GetHealth() / ally:GetMaxHealth() > 0.8)
			and (ally:IsChanneling() and not ally:HasModifier("modifier_teleporting"))
		then
			local allyEnemyHeroes = Fu.GetNearbyHeroes(ally, 1200, true, BOT_MODE_NONE)
			for _, enemy in pairs(allyEnemyHeroes) do
				if
					enemy ~= nil
					and enemy:IsAlive()
					and Fu.CanCastOnNonMagicImmune(enemy)
					and GetUnitToUnitDistance(enemy, ally) > 835
					and ally:IsFacingLocation(enemy:GetLocation(), 30)
				then
					hEffectTarget = ally
					castReason = "推CM"
					return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
Usage.ConsiderItemDesire["item_invis_sword"] = function(item)
	if
		bot:IsInvisible()
		or #nearbyEnemyTowers > 0
		or bot:HasModifier("modifier_item_dustofappearance")
		or bot:HasModifier("modifier_slardar_amplify_damage")
	then
		return BOT_ACTION_DESIRE_NONE
	end
	local radius = 800
	local castType = "none"
	local hEffectTarget = nil
	local castReason = nil
	local enemyHeroes = Fu.GetNearbyHeroes(bot, radius, true, BOT_MODE_NONE)
	if Fu.IsRetreating(bot) and bot:GetActiveModeDesire() > BOT_MODE_DESIRE_MODERATE and #nearbyEnemies > 0 then
		hEffectTarget = bot
		castReason = "撤退了"
		return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
	end
	if Fu.GetHP(bot) < 0.166 and (#nearbyEnemies > 0 or bot:WasRecentlyDamagedByAnyHero(5.0)) then
		hEffectTarget = bot
		castReason = "残血了"
		return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidHero(botTarget)
			and Fu.CanCastOnMagicImmune(botTarget)
			and not Fu.IsInRange(bot, botTarget, botTarget:GetCurrentVisionRange())
			and Fu.IsInRange(bot, botTarget, 2600)
		then
			local enemyLaneCreeps = bot:GetNearbyLaneCreeps(800, true)
			if #enemyLaneCreeps == 0 and #nearbyEnemies == 0 then
				hEffectTarget = botTarget
				castReason = "进攻:" .. Fu.Chat.GetNormName(hEffectTarget)
				return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
Usage.ConsiderItemDesire["item_lotus_orb"] = function(item)
	local castRange = 1000 + castRangeBonus
	local castType = "unit"
	local hEffectTarget = nil
	local castReason = nil
	local allyHeroes = Fu.GetNearbyHeroes(bot, castRange, false, BOT_MODE_NONE)
	for _, ally in pairs(allyHeroes) do
		if
			Fu.IsValid(ally)
			and not ally:IsIllusion()
			and not ally:IsMagicImmune()
			and not ally:IsInvulnerable()
			and not ally:HasModifier("modifier_item_lotus_orb_active")
			and not ally:HasModifier("modifier_antimage_spell_shield")
		then
			if Fu.IsUnitTargetProjectileIncoming(ally, 800) then
				hEffectTarget = ally
				castReason = "反弹弹道"
				return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
			end
			if
				ally:IsRooted()
				or ally:IsSilenced() and not ally:HasModifier("modifier_item_mask_of_madness_berserk")
				or ally:IsDisarmed() and not ally:HasModifier("modifier_oracle_fates_edict")
			then
				hEffectTarget = ally
				castReason = "驱散队友:" .. Fu.Chat.GetNormName(hEffectTarget)
				return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
			end
			if Fu.IsWillBeCastUnitTargetSpell(ally, 1200) then
				hEffectTarget = ally
				castReason = "给队友反弹技能:" .. Fu.Chat.GetNormName(hEffectTarget)
				return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
Usage.ConsiderItemDesire["item_magic_stick"] = function(item)
	if item:GetCurrentCharges() <= 0 then
		return BOT_ACTION_DESIRE_NONE
	end
	local castType = "none"
	local enemyHeroes = Fu.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE)
	local enemyCount = #enemyHeroes
	local hpRatio = Fu.GetHP(bot)
	local mpRatio = Fu.GetMP(bot)
	local charges = item:GetCurrentCharges()
	if hpRatio < 0.25 and charges >= 1 then
		return BOT_ACTION_DESIRE_HIGH, bot, castType, "Stick: emergency"
	end
	if Fu.IsRetreating(bot) and hpRatio < 0.6 and charges >= 2 then
		return BOT_ACTION_DESIRE_HIGH, bot, castType, "Stick: retreat"
	end
	if enemyCount >= 1 and charges >= 1 and (hpRatio < 0.6 or mpRatio < 0.35) then
		return BOT_ACTION_DESIRE_HIGH, bot, castType, "Stick: fight"
	end
	if charges >= 5 and enemyCount == 0 and (hpRatio < 0.7 or mpRatio < 0.5) then
		return BOT_ACTION_DESIRE_HIGH, bot, castType, "Stick: proactive heal"
	end
	if charges >= 10 and (hpRatio < 0.85 or mpRatio < 0.75) then
		return BOT_ACTION_DESIRE_HIGH, bot, castType, "Stick: max charges"
	end
	return BOT_ACTION_DESIRE_NONE
end
Usage.ConsiderItemDesire["item_magic_wand"] = function(item)
	if item:GetCurrentCharges() <= 0 then
		return BOT_ACTION_DESIRE_NONE
	end
	local castType = "none"
	if item:GetName() == "item_holy_locket" then
		castType = "unit"
	end
	local enemyHeroes = Fu.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE)
	local enemyCount = #enemyHeroes
	local hpRatio = Fu.GetHP(bot)
	local mpRatio = Fu.GetMP(bot)
	local charges = item:GetCurrentCharges()
	local isRetreating = Fu.IsRetreating(bot)
	if hpRatio < 0.25 and charges >= 1 then
		return BOT_ACTION_DESIRE_HIGH, bot, castType, "Wand: emergency"
	end
	if isRetreating and hpRatio < 0.6 and charges >= 2 then
		return BOT_ACTION_DESIRE_HIGH, bot, castType, "Wand: retreat"
	end
	if enemyCount >= 1 and charges >= 1 and (hpRatio < 0.6 or mpRatio < 0.3) then
		return BOT_ACTION_DESIRE_HIGH, bot, castType, "Wand: fight"
	end
	if charges >= 5 and enemyCount == 0 and (hpRatio < 0.75 or mpRatio < 0.5) then
		return BOT_ACTION_DESIRE_HIGH, bot, castType, "Wand: proactive heal"
	end
	if charges >= 10 and (hpRatio < 0.8 or mpRatio < 0.6) then
		return BOT_ACTION_DESIRE_HIGH, bot, castType, "Wand: high charges"
	end
	if charges >= 20 and (hpRatio < 0.9 or mpRatio < 0.75) then
		return BOT_ACTION_DESIRE_HIGH, bot, castType, "Wand: max charges"
	end
	return BOT_ACTION_DESIRE_NONE
end
Usage.ConsiderItemDesire["item_manta"] = function(item)
	local radius = 800
	local castType = "none"
	local hEffectTarget = nil
	local castReason = nil
	local enemyHeroes = Fu.GetNearbyHeroes(bot, radius, true, BOT_MODE_NONE)
	local attackingAllies = Fu.GetNearbyHeroes(bot, 1000, false, BOT_MODE_ATTACK)
	local enemyHeroesInRange = Fu.GetNearbyHeroes(bot, 1000, true, BOT_MODE_NONE)
	local enemyTowers = bot:GetNearbyTowers(800, true)
	local enemyBarracks = bot:GetNearbyBarracks(600, true)
	local allyLaneCreeps = bot:GetNearbyLaneCreeps(1000, false)
	local enemyLaneCreeps = bot:GetNearbyLaneCreeps(800, true)
	if Fu.IsPushing(bot) then
		if (#enemyTowers >= 1 or #enemyBarracks >= 1) and #allyLaneCreeps >= 1 then
			hEffectTarget = bot
			castReason = "推进"
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
		end
	end
	if
		Fu.IsGoingOnSomeone(bot)
		and Fu.IsValidHero(botTarget)
		and Fu.CanCastOnMagicImmune(botTarget)
		and Fu.IsInRange(bot, botTarget, bot:GetAttackRange() + 80)
	then
		hEffectTarget = botTarget
		castReason = "进攻:" .. Fu.Chat.GetNormName(hEffectTarget)
		return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
	end
	if
		bot:IsRooted()
		or bot:IsSilenced() and not bot:HasModifier("modifier_item_mask_of_madness_berserk")
		or bot:HasModifier("modifier_item_solar_crest_armor_reduction")
		or bot:HasModifier("modifier_item_medallion_of_courage_armor_reduction")
		or bot:HasModifier("modifier_item_spirit_vessel_damage")
		or bot:HasModifier("modifier_dragonknight_breathefire_reduction")
		or bot:HasModifier("modifier_slardar_amplify_damage")
		or bot:HasModifier("modifier_item_dustofappearance")
	then
		hEffectTarget = bot
		castReason = "解Buff"
		return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
	end
	if
		not bot:IsMagicImmune()
		and not bot:HasModifier("modifier_antimage_spell_shield")
		and not bot:HasModifier("modifier_item_sphere_target")
		and not bot:HasModifier("modifier_item_lotus_orb_active")
		and Fu.IsNotAttackProjectileIncoming(bot, 70)
	then
		hEffectTarget = bot
		castReason = "躲弹道"
		return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
	end
	if Fu.IsRetreating(bot) and enemyHeroesInRange[1] ~= nil and bot:DistanceFromFountain() > 600 then
		hEffectTarget = bot
		castReason = "撤退了"
		return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
	end
	if #enemyLaneCreeps >= 8 then
		hEffectTarget = bot
		castReason = "刷小兵"
		return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
	end
	if
		bot:WasRecentlyDamagedByAnyHero(5.0)
		and bot:GetHealth() / bot:GetMaxHealth() < 0.18
		and bot:DistanceFromFountain() > 800
	then
		hEffectTarget = bot
		castReason = "残血了"
		return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
	end
	return BOT_ACTION_DESIRE_NONE
end
Usage.ConsiderItemDesire["item_mjollnir"] = function(item)
	local castRange = 800 + castRangeBonus
	local castType = "unit"
	local hEffectTarget = nil
	local castReason = nil
	local enemyHeroes = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	local allyHeroes = Fu.GetNearbyHeroes(bot, castRange + 100, false, BOT_MODE_NONE)
	if Fu.IsInTeamFight(bot, 900) then
		local bestAlly = nil
		local mostAttackers = 1
		for _, ally in pairs(allyHeroes) do
			if Fu.IsValid(ally) and not ally:IsIllusion() and not ally:HasModifier("modifier_item_mjollnir_static") then
				local attackerCount = 0
				local nEnemyHeroes = Fu.GetNearbyHeroes(ally, 1400, true, BOT_MODE_NONE)
				local allyNearbyEnemyCreeps = ally:GetNearbyCreeps(1000, true)
				for _, enemy in pairs(nEnemyHeroes) do
					if enemy ~= nil and enemy:IsAlive() and enemy:GetAttackTarget() == ally then
						attackerCount = attackerCount + 1
					end
				end
				for _, creep in pairs(allyNearbyEnemyCreeps) do
					if creep ~= nil and creep:IsAlive() and creep:GetAttackTarget() == ally then
						attackerCount = attackerCount + 1
					end
				end
				if attackerCount > mostAttackers then
					mostAttackers = attackerCount
					bestAlly = ally
				end
			end
		end
		if bestAlly ~= nil then
			hEffectTarget = bestAlly
			castReason = "团战中套电锤给队友:" .. Fu.Chat.GetNormName(hEffectTarget)
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
		end
	end
	if Fu.IsValidHero(botTarget) then
		local alliesNearTarget = Fu.GetAlliesNearLoc(botTarget:GetLocation(), 1400)
		if Fu.IsValid(alliesNearTarget[1]) then
			local bestAlly = nil
			local closestDistance = 9999
			for _, ally in pairs(alliesNearTarget) do
				if
					Fu.IsValid(ally)
					and GetUnitToUnitDistance(bot, ally) < castRange + 200
					and GetUnitToUnitDistance(botTarget, ally) < closestDistance
					and not ally:HasModifier("modifier_item_mjollnir_static")
				then
					bestAlly = ally
					closestDistance = GetUnitToUnitDistance(botTarget, ally)
				end
			end
			if bestAlly ~= nil then
				hEffectTarget = bestAlly
				castReason = "攻击前套电锤给队友:" .. Fu.Chat.GetNormName(hEffectTarget)
				return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
			end
		end
	end
	if nearbyEnemies[1] == nil then
		local allyLaneCreeps = bot:GetNearbyLaneCreeps(1000, false)
		local enemyLaneCreeps = bot:GetNearbyLaneCreeps(1000, true)
		if #allyLaneCreeps >= 1 and #enemyLaneCreeps == 0 then
			local frontCreep = nil
			local farthestDistance = 0
			for _, creep in pairs(allyLaneCreeps) do
				if Fu.IsValid(creep) and Fu.GetHP(creep) > 0.6 and creep:DistanceFromFountain() > farthestDistance then
					frontCreep = creep
					farthestDistance = creep:DistanceFromFountain()
				end
			end
			if frontCreep ~= nil then
				hEffectTarget = frontCreep
				castReason = "给前排小兵套上"
				return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
			end
		end
	end
	if Fu.IsValidHero(nearbyEnemies[1]) and nearbyEnemies[1]:GetAttackTarget() == bot then
		if not bot:HasModifier("modifier_item_mjollnir_static") then
			hEffectTarget = bot
			castReason = "给自己套上"
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
Usage.ConsiderItemDesire["item_mask_of_madness"] = function(item)
	if botName == "npc_dota_hero_drow_ranger" then
		return BOT_ACTION_DESIRE_NONE
	end
	local attackTarget = bot:GetAttackTarget()
	local attackRange = bot:GetAttackRange() + 100
	local castType = "none"
	local hEffectTarget = nil
	local castReason = nil
	if
		(Fu.IsValid(attackTarget) or Fu.IsValidBuilding(attackTarget))
		and Fu.CanBeAttacked(attackTarget)
		and Fu.IsInRange(bot, attackTarget, attackRange)
		and (
			not Fu.CanKillTarget(attackTarget, bot:GetAttackDamage() * 2, DAMAGE_TYPE_PHYSICAL)
			or Fu.GetAroundTargetEnemyUnitCount(bot, attackRange) >= 2
		)
	then
		local enemyHeroes = Fu.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE)
		if attackTarget:IsHero() or #enemyHeroes == 0 and not bot:WasRecentlyDamagedByAnyHero(2.0) then
			if
				#enemyHeroes == 0
				or (
					botName ~= "npc_dota_hero_sniper"
					or botName ~= "npc_dota_hero_medusa"
					or botName ~= "npc_dota_hero_faceless_void" and Fu.GetUltimateAbility(bot):GetCooldown() > 0
				)
			then
				bot:SetTarget(attackTarget)
				hEffectTarget = attackTarget
				castReason = "启动"
				return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
Usage.ConsiderItemDesire["item_medallion_of_courage"] = function(item)
	local castRange = 900 + castRangeBonus
	local castType = "unit"
	local hEffectTarget = nil
	local castReason = nil
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidHero(botTarget)
			and not botTarget:HasModifier("modifier_item_solar_crest_armor_reduction")
			and not botTarget:HasModifier("modifier_item_medallion_of_courage_armor_reduction")
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and not botTarget:IsAncientCreep()
			and (
				Fu.IsInRange(bot, botTarget, bot:GetAttackRange() + 150)
				or Fu.IsInRange(bot, botTarget, 1000)
					and Fu.GetAroundTargetOtherAllyHeroCount(bot, botTarget, 600) >= 1
			)
		then
			hEffectTarget = botTarget
			castReason = "进攻:" .. Fu.Chat.GetNormName(hEffectTarget)
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
		end
	end
	if #nearbyEnemies == 0 then
		if
			Fu.IsValid(botTarget)
			and not botTarget:HasModifier("modifier_item_solar_crest_armor_reduction")
			and not botTarget:HasModifier("modifier_item_medallion_of_courage_armor_reduction")
			and not botTarget:HasModifier("modifier_fountain_glyph")
			and not Fu.CanKillTarget(botTarget, bot:GetAttackDamage() * 2.38, DAMAGE_TYPE_PHYSICAL)
			and Fu.IsInRange(bot, botTarget, bot:GetAttackRange() + 150)
		then
			hEffectTarget = botTarget
			castReason = "刷小兵:" .. Fu.Chat.GetNormName(hEffectTarget)
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
		end
	end
	local allyHeroes = Fu.GetNearbyHeroes(bot, 1000, false, BOT_MODE_NONE)
	for _, ally in pairs(allyHeroes) do
		if
			ally ~= bot
			and Fu.IsValidHero(ally)
			and not ally:IsIllusion()
			and Fu.CanCastOnNonMagicImmune(ally)
			and not ally:HasModifier("modifier_item_solar_crest_armor_addition")
			and not ally:HasModifier("modifier_item_medallion_of_courage_armor_addition")
			and not ally:HasModifier("modifier_arc_warden_tempest_double")
			and (
				Fu.IsDisabled(ally)
				or Fu.GetHP(ally) < 0.35 and #nearbyEnemies > 0 and ally:WasRecentlyDamagedByAnyHero(2.0)
				or Fu.IsValidHero(ally:GetAttackTarget())
					and GetUnitToUnitDistance(ally, ally:GetAttackTarget()) <= ally:GetAttackRange()
					and #nearbyEnemies == 0
			)
		then
			hEffectTarget = ally
			castReason = "救队友:" .. Fu.Chat.GetNormName(hEffectTarget)
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
Usage.ConsiderItemDesire["item_moon_shard"] = function(item)
	if bot:GetNetWorth() < 18000 or Utils.CountBackpackEmptySpace(bot) >= 3 then
		return BOT_ACTION_DESIRE_NONE
	end
	local castRange = 2000
	local castType = "unit"
	local hEffectTarget = nil
	local castReason = nil
	if not bot:HasModifier("modifier_item_moon_shard_consumed") then
		if bot.moonSharedTime == nil then
			bot.moonSharedTime = DotaTime()
		elseif bot.moonSharedTime < DotaTime() - 2.0 then
			bot.moonSharedTime = nil
			hEffectTarget = bot
			castReason = "自己吃"
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
		end
	end
	local strongestAlly = nil
	local highestDamage = 0
	for i = 1, #GetTeamPlayers(GetTeam()) do
		local teammate = GetTeamMember(i)
		if
			teammate ~= nil
			and teammate:IsAlive()
			and teammate:GetAttackDamage() > highestDamage
			and not teammate:HasModifier("modifier_item_moon_shard_consumed")
		then
			strongestAlly = teammate
			highestDamage = teammate:GetAttackDamage()
		end
	end
	if strongestAlly ~= nil then
		if bot.moonSharedTime == nil then
			bot.moonSharedTime = DotaTime()
		elseif bot.moonSharedTime < DotaTime() - 3.0 then
			bot.moonSharedTime = nil
			hEffectTarget = strongestAlly
			castReason = "给队友"
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
Usage.ConsiderItemDesire["item_necronomicon"] = function(item)
	local castRange = 750
	local castType = "none"
	local hEffectTarget = nil
	local castReason = nil
	local enemyHeroes = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	if botTarget ~= nil and botTarget:IsAlive() and Fu.IsInRange(bot, botTarget, 1000) then
		hEffectTarget = botTarget
		castReason = "进攻"
		return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
	end
	return BOT_ACTION_DESIRE_NONE
end
Usage.ConsiderItemDesire["item_necronomicon_2"] = function(item)
	return Usage.ConsiderItemDesire["item_necronomicon"](item)
end
Usage.ConsiderItemDesire["item_necronomicon_3"] = function(item)
	return Usage.ConsiderItemDesire["item_necronomicon"](item)
end
Usage.ConsiderItemDesire["item_nullifier"] = function(item)
	local castRange = 800 + castRangeBonus
	local castType = "unit"
	local hEffectTarget = nil
	local castReason = nil
	local enemyHeroes = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidHero(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.CanCastOnTargetAdvanced(botTarget)
			and Fu.IsInRange(botTarget, bot, castRange)
			and not botTarget:HasModifier("modifier_item_nullifier_mute")
		then
			hEffectTarget = botTarget
			castReason = "进攻:" .. Fu.Chat.GetNormName(hEffectTarget)
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
Usage.ConsiderItemDesire["item_orchid"] = function(item)
	local castRange = 900 + castRangeBonus
	local castType = "unit"
	local hEffectTarget = nil
	local castReason = nil
	local hMenace = Fu.GetRightclickMenaceLock(bot, castRange, "silence")
	if hMenace ~= nil and Usage.IsWithoutSpellShield(hMenace) then
		return BOT_ACTION_DESIRE_HIGH, hMenace, castType, "silence carry"
	end
	local enemyHeroes = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	for _, enemy in pairs(enemyHeroes) do
		if Fu.IsValid(enemy) and Fu.CanCastOnNonMagicImmune(enemy) and Usage.IsWithoutSpellShield(enemy) then
			if enemy:IsChanneling() or enemy:IsCastingAbility() then
				hEffectTarget = enemy
				castReason = "打断:" .. Fu.Chat.GetNormName(hEffectTarget)
				return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
			end
			if Fu.IsRetreating(bot) then
				if not Fu.IsDisabled(enemy) then
					hEffectTarget = enemy
					castReason = "撤退:" .. Fu.Chat.GetNormName(hEffectTarget)
					return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
				end
			end
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidHero(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and not Fu.IsDisabled(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Usage.IsWithoutSpellShield(botTarget)
		then
			hEffectTarget = botTarget
			castReason = "进攻:" .. Fu.Chat.GetNormName(hEffectTarget)
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
Usage.ConsiderItemDesire["item_phase_boots"] = function(item)
	local castType = "none"
	local enemyHeroes = Fu.GetNearbyHeroes(bot, 800, true, BOT_MODE_NONE)
	local actionType = bot:GetCurrentActionType()
	if
		actionType == BOT_ACTION_TYPE_MOVE_TO
		or actionType == BOT_ACTION_TYPE_MOVE_TO_DIRECTLY
		or actionType == BOT_ACTION_TYPE_ATTACK_MOVE
		or Fu.IsRunning(bot)
	then
		return BOT_ACTION_DESIRE_HIGH, bot, castType, "phase: moving"
	end
	if Fu.IsGoingOnSomeone(bot) then
		return BOT_ACTION_DESIRE_HIGH, bot, castType, "phase: chasing"
	end
	if Fu.IsRetreating(bot) then
		return BOT_ACTION_DESIRE_HIGH, bot, castType, "phase: retreat"
	end
	if #enemyHeroes > 0 then
		return BOT_ACTION_DESIRE_HIGH, bot, castType, "phase: near enemy"
	end
	return BOT_ACTION_DESIRE_NONE
end
Usage.ConsiderItemDesire["item_pipe"] = function(item)
	local castRange = 1000
	local castType = "none"
	local hEffectTarget = nil
	local castReason = nil
	local enemyHeroes = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	local allyHeroes = Fu.GetNearbyHeroes(bot, 1200, false, BOT_MODE_NONE)
	for _, ally in pairs(allyHeroes) do
		if
			Fu.IsValid(ally)
			and not ally:IsIllusion()
			and ally:GetHealth() / ally:GetMaxHealth() < 0.4
			and #nearbyEnemies > 0
		then
			hEffectTarget = ally
			castReason = "保护队友:" .. Fu.Chat.GetNormName(hEffectTarget)
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
		end
	end
	local alliesAround = Fu.GetNearbyHeroes(bot, 1200, false, BOT_MODE_NONE)
	local enemiesAround = Fu.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE)
	local enemyTowers = bot:GetNearbyTowers(1200, true)
	if #alliesAround >= 2 and #enemiesAround >= 2 or #enemiesAround >= 2 and #alliesAround + #enemyTowers >= 2 then
		hEffectTarget = bot
		castReason = "保护团队"
		return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
	end
	return BOT_ACTION_DESIRE_NONE
end
Usage.ConsiderItemDesire["item_power_treads"] = function(item)
	if useDefaultItem then
		return 0
	end
	local currentStat = item:GetPowerTreadsStat()
	if currentStat == ATTRIBUTE_INTELLECT then
		currentStat = ATTRIBUTE_AGILITY
	elseif currentStat == ATTRIBUTE_AGILITY then
		currentStat = ATTRIBUTE_INTELLECT
	end
	if
		(
			bot:HasModifier("modifier_flask_healing")
			or bot:HasModifier("modifier_clarity_potion")
			or bot:HasModifier("modifier_item_urn_heal")
			or bot:HasModifier("modifier_item_spirit_vessel_heal")
			or bot:HasModifier("modifier_bottle_regeneration")
		)
		and not Fu.IsGoingOnSomeone(bot)
		and not Fu.IsRetreating(bot)
		and not bot:WasRecentlyDamagedByAnyHero(5.0)
	then
		if currentStat ~= ATTRIBUTE_AGILITY then
			lastTreadsSwitchTime = DotaTime()
			return BOT_ACTION_DESIRE_HIGH, nil, "none"
		end
	elseif
		Fu.IsRetreating(bot)
			and not Fu.IsRealInvisible(bot)
			and bot:GetActiveModeDesire() > BOT_MODE_DESIRE_MODERATE
		or Fu.IsNotAttackProjectileIncoming(bot, 1200)
		or botMode == BOT_MODE_EVASIVE_MANEUVERS
		or bot:HasModifier("modifier_sniper_assassinate")
		or Fu.GetHP(bot) < 0.2
		or currentStat == ATTRIBUTE_STRENGTH and Fu.GetHP(bot) < 0.3
	then
		if currentStat ~= ATTRIBUTE_STRENGTH then
			lastTreadsSwitchTime = DotaTime()
			return BOT_ACTION_DESIRE_HIGH, nil, "none"
		end
	elseif DotaTime() - (bot._ptSpellSwitchAt or -999) < 3 then
		-- Switched to Intelligence for a spell: leave it for 3s instead of switching straight back.
		return BOT_ACTION_DESIRE_NONE
	elseif Fu.IsGoingOnSomeone(bot) then
		if Fu.ShouldSwitchPTStat(bot, item) and lastTreadsSwitchTime < DotaTime() - 0.2 then
			return BOT_ACTION_DESIRE_HIGH, nil, "none"
		end
	elseif Fu.ShouldSwitchPTStat(bot, item) and lastTreadsSwitchTime < DotaTime() - 0.2 then
		return BOT_ACTION_DESIRE_HIGH, nil, "none"
	end
	return BOT_ACTION_DESIRE_NONE
end
local lastTreeCutTime = 0
Usage.ConsiderItemDesire["item_quelling_blade"] = function(item)
	local castRange = 450 + castRangeBonus
	local castType = "tree"
	local hEffectTarget = nil
	local castReason = nil
	local enemyHeroes = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	if bot:HasModifier("modifier_furion_sprout_damage") then
		local sproutTrees = bot:GetNearbyTrees(280)
		if
			sproutTrees ~= nil
			and #sproutTrees >= 8
			and IsLocationVisible(GetTreeLocation(sproutTrees[1]))
			and IsLocationPassable(GetTreeLocation(sproutTrees[1]))
		then
			hEffectTarget = sproutTrees[1]
			castReason = "吃先知的树"
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
		end
	end
	if DotaTime() < 0 and not enemyHasMonkeyKing then
		for _, playerId in pairs(GetTeamPlayers(GetOpposingTeam())) do
			if GetSelectedHeroName(playerId) == "npc_dota_hero_monkey_king" then
				enemyHasMonkeyKing = true
			end
		end
	end
	if enemyHasMonkeyKing then
		local monkeyKing = nil
		for _, enemy in pairs(nearbyEnemies) do
			if enemy:IsAlive() and enemy:GetUnitName() == "npc_dota_hero_monkey_king" then
				monkeyKing = enemy
				break
			end
		end
		if monkeyKing ~= nil and Fu.IsInRange(bot, monkeyKing, castRange) then
			local nearbyTrees = bot:GetNearbyTrees(castRange)
			for _, tree in pairs(nearbyTrees) do
				local treeLocation = GetTreeLocation(tree)
				if GetUnitToLocationDistance(monkeyKing, treeLocation) < 30 then
					castReason = "砍大圣的树"
					return BOT_ACTION_DESIRE_HIGH, tree, castType, castReason
				end
			end
		end
	end
	if
		DotaTime() > lastTreeCutTime + 0.8 and (Fu.IsGoingOnSomeone(bot) or Fu.IsFarming(bot) or Fu.IsRetreating(bot))
	then
		lastTreeCutTime = DotaTime()
		local treeRange = 350
		local nearbyTrees = bot:GetNearbyTrees(treeRange)
		local treeCount = #nearbyTrees
		if treeCount >= 1 then
			for i = 1, treeCount do
				local tree = nearbyTrees[i]
				if bot:IsFacingLocation(GetTreeLocation(tree), 7) then
					castReason = "开视野"
					return BOT_ACTION_DESIRE_HIGH, tree, castType, castReason
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
Usage.ConsiderItemDesire["item_refresher"] = function(item)
	local castRange = 1000
	local castType = "none"
	local hEffectTarget = nil
	local castReason = "刷新技能"
	local enemyHeroes = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	if BotBuild ~= nil and BotBuild.CanUseRefresherShard ~= nil and BotBuild.CanUseRefresherShard() then
		return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
	end
	if #enemyHeroes > 0 and (Fu.IsGoingOnSomeone(bot) or Fu.IsInTeamFight(bot)) and Fu.CanUseRefresherShard(bot) then
		return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
	end
	return BOT_ACTION_DESIRE_NONE
end
Usage.ConsiderItemDesire["item_refresher_shard"] = function(item)
	return Usage.ConsiderItemDesire["item_refresher"](item)
end
Usage.ConsiderItemDesire["item_ultimate_scepter_roshan"] = function(item)
	local castRange = 300
	local castType = "none"
	local hEffectTarget = nil
	local castReason = nil
	local enemyHeroes = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	if item:IsFullyCastable() then
		hEffectTarget = bot
		castReason = "吃A杖"
		return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
	end
	return BOT_ACTION_DESIRE_NONE
end
Usage.ConsiderItemDesire["item_aghanims_shard_roshan"] = function(item)
	local castRange = 300
	local castType = "none"
	local hEffectTarget = nil
	local castReason = nil
	local enemyHeroes = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	if item:IsFullyCastable() then
		hEffectTarget = bot
		castReason = "吃魔晶"
		return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
	end
	return BOT_ACTION_DESIRE_NONE
end
Usage.ConsiderItemDesire["item_rod_of_atos"] = function(item)
	local castRange = 1100 + castRangeBonus
	local castType = "unit"
	if item:GetName() == "item_gungir" then
		castType = "ground"
	end
	local hEffectTarget = nil
	local castReason = nil
	local enemyHeroes = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	for _, enemy in pairs(enemyHeroes) do
		if
			Fu.IsValid(enemy)
			and enemy:IsChanneling()
			and enemy:HasModifier("modifier_teleporting")
			and Fu.CanCastOnNonMagicImmune(enemy)
			and Fu.CanCastOnTargetAdvanced(enemy)
		then
			hEffectTarget = enemy
			castReason = "打断:" .. Fu.Chat.GetNormName(hEffectTarget)
			if item:GetName() == "item_gungir" then
				hEffectTarget = hEffectTarget:GetLocation()
			end
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
		end
	end
	if
		botMode == BOT_MODE_RETREAT
		and bot:GetActiveModeDesire() > BOT_MODE_DESIRE_MODERATE
		and Fu.IsValid(enemyHeroes[1])
		and Fu.CanCastOnNonMagicImmune(enemyHeroes[1])
		and Fu.CanCastOnTargetAdvanced(enemyHeroes[1])
		and not Fu.IsDisabled(enemyHeroes[1])
	then
		hEffectTarget = enemyHeroes[1]
		castReason = "撤退了"
		if item:GetName() == "item_gungir" then
			hEffectTarget = hEffectTarget:GetLocation()
		end
		return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidHero(botTarget)
			and not Fu.IsDisabled(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.CanCastOnTargetAdvanced(botTarget)
			and GetUnitToUnitDistance(botTarget, bot) <= castRange
			and Fu.IsMoving(botTarget)
		then
			hEffectTarget = botTarget
			castReason = "进攻:" .. Fu.Chat.GetNormName(hEffectTarget)
			if item:GetName() == "item_gungir" then
				hEffectTarget = hEffectTarget:GetLocation()
			end
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
Usage.ConsiderItemDesire["item_satanic"] = function(item)
	local castRange = bot:GetAttackRange() + 250
	local castType = "none"
	local hEffectTarget = nil
	local castReason = nil
	local enemyHeroes = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	if
		bot:OriginalGetHealth() / bot:OriginalGetMaxHealth() < 0.62
		and #enemyHeroes > 0
		and (
			Fu.IsValidHero(botTarget) and Fu.IsInRange(bot, botTarget, castRange)
			or Fu.IsValidHero(enemyHeroes[1]) and Fu.IsInRange(bot, enemyHeroes[1], castRange)
		)
	then
		hEffectTarget = botTarget
		castReason = "进攻"
		return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
	end
	return BOT_ACTION_DESIRE_NONE
end
-- Shadow Amulet (game files: allied hero target, range 600, cooldown 18s, fade 1.25s).
-- Self: while running away from an enemy hero, or when a stun projectile is coming (invisible
-- while stunned, nothing can target it). Ally in range: stunned, about to be stunned, or running
-- away hurt. Never on a rooted hero or one already revealed (Dust, Amplify Damage), never near an
-- enemy tower. During a teleport it is cast from the top of the item think (AmuletDuringTeleport),
-- since item use is off while channelling.
local function AmuletHidden(unit)
	return unit:IsInvisible()
		or unit:HasModifier("modifier_invisible")
		or unit:HasModifier("modifier_item_glimmer_cape")
		or unit:HasModifier("modifier_item_shadow_amulet_fade")
end
local function AmuletRevealed(unit)
	return unit:IsRooted()
		or unit:HasModifier("modifier_slardar_amplify_damage")
		or unit:HasModifier("modifier_item_dustofappearance")
end
local function AmuletLog(target, why)
	if DotaTime() < (bot._amuletLogAt or -999) then
		return
	end
	bot._amuletLogAt = DotaTime() + 2
	pcall(
		print,
		string.format(
			"[OHA-ITEM] t=%.0f %s shadow-amulet target=%s why=%s",
			DotaTime(),
			(string.gsub(bot:GetUnitName(), "npc_dota_hero_", "")),
			(string.gsub(target:GetUnitName(), "npc_dota_hero_", "")),
			why
		)
	)
end
Usage.ConsiderItemDesire["item_shadow_amulet"] = function(item)
	local castType = "unit"
	local range = 600 + castRangeBonus
	if not AmuletHidden(bot) and not AmuletRevealed(bot) and #(bot:GetNearbyTowers(888, true) or {}) == 0 then
		local foes = Fu.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE) or {}
		if Fu.IsStunProjectileIncoming(bot, 1000) then
			AmuletLog(bot, "stun-incoming")
			return BOT_ACTION_DESIRE_HIGH, bot, castType, "stun-incoming"
		end
		if #foes > 0 and (botMode == BOT_MODE_RETREAT or Fu.IsRetreating(bot)) and not Fu.IsGoingOnSomeone(bot) then
			AmuletLog(bot, "running-away")
			return BOT_ACTION_DESIRE_HIGH, bot, castType, "running-away"
		end
	end
	for _, ally in pairs(Fu.GetNearbyHeroes(bot, range, false, BOT_MODE_NONE) or {}) do
		if
			Fu.IsValid(ally)
			and ally ~= bot
			and not ally:IsIllusion()
			and not ally:IsMagicImmune()
			and not AmuletHidden(ally)
			and not AmuletRevealed(ally)
			and #(ally:GetNearbyTowers(888, true) or {}) == 0
		then
			local why = nil
			if ally:IsStunned() then
				why = "ally-stunned"
			elseif Fu.IsStunProjectileIncoming(ally, 1000) then
				why = "ally-stun-incoming"
			elseif
				Fu.IsRetreating(ally)
				and ally:GetHealth() / math.max(1, ally:GetMaxHealth()) < 0.5
				and #(ally:GetNearbyHeroes(900, true, BOT_MODE_NONE) or {}) > 0
			then
				why = "ally-running-away"
			end
			if why ~= nil then
				AmuletLog(ally, why)
				return BOT_ACTION_DESIRE_HIGH, ally, castType, why
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
-- Teleporting with an enemy hero near: cast it on self during the channel. The amulet does not
-- cancel channels (DOTA_ABILITY_BEHAVIOR_IGNORE_CHANNEL in the game files), so the 1.25s fade
-- runs inside the TP. Casting it before the TP would not work: the TP is an item cast, which
-- breaks the invisibility, and item use is held while the amulet fade is on. True when cast.
function Usage.AmuletDuringTeleport()
	local slot = bot:FindItemSlot("item_shadow_amulet")
	if slot < 0 or slot > 5 then
		return false
	end
	local amulet = bot:GetItemInSlot(slot)
	if amulet == nil or not Fu.CanCastAbility(amulet) or AmuletHidden(bot) or AmuletRevealed(bot) then
		return false
	end
	if #(Fu.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE) or {}) == 0 then
		return false
	end
	AmuletLog(bot, "during-teleport")
	bot:Action_UseAbilityOnEntity(amulet, bot)
	return true
end
Usage.ConsiderItemDesire["item_sheepstick"] = function(item)
	local castRange = 800 + castRangeBonus
	local castType = "unit"
	local hEffectTarget = nil
	local castReason = nil
	local hMenace = Fu.GetRightclickMenaceLock(bot, castRange, "hex")
	if hMenace ~= nil and Usage.IsWithoutSpellShield(hMenace) then
		return BOT_ACTION_DESIRE_HIGH, hMenace, castType, "hex carry"
	end
	local enemyHeroes = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	for _, enemy in pairs(enemyHeroes) do
		if Fu.IsValid(enemy) and Fu.CanCastOnNonMagicImmune(enemy) and Usage.IsWithoutSpellShield(enemy) then
			if enemy:IsChanneling() or enemy:IsCastingAbility() then
				hEffectTarget = enemy
				castReason = "打断:" .. Fu.Chat.GetNormName(hEffectTarget)
				return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
			end
			if Fu.IsRetreating(bot) then
				if not Fu.IsDisabled(enemy) and not enemy:IsDisarmed() then
					hEffectTarget = enemy
					castReason = "撤退:" .. Fu.Chat.GetNormName(hEffectTarget)
					return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
				end
			end
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidHero(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and not Fu.IsDisabled(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Usage.IsWithoutSpellShield(botTarget)
		then
			hEffectTarget = botTarget
			castReason = "进攻:" .. Fu.Chat.GetNormName(hEffectTarget)
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
Usage.ConsiderItemDesire["item_shivas_guard"] = function(item)
	local radius = 800
	local castType = "none"
	local hEffectTarget = nil
	local castReason = nil
	local enemyHeroes = Fu.GetNearbyHeroes(bot, radius + 50, true, BOT_MODE_NONE)
	local enemyCreeps = bot:GetNearbyCreeps(radius, true)
	if #enemyCreeps >= 6 or #enemyHeroes >= 1 then
		hEffectTarget = bot
		castReason = "启动希瓦"
		return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
	end
	return BOT_ACTION_DESIRE_NONE
end
Usage.ConsiderItemDesire["item_silver_edge"] = function(item)
	local castRange = 1600
	local castType = "none"
	local hEffectTarget = nil
	local castReason = nil
	local enemyHeroes = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	if
		Fu.IsGoingOnSomeone(bot)
		and not bot:HasModifier("modifier_slardar_amplify_damage")
		and not bot:HasModifier("modifier_item_dustofappearance")
		and #nearbyEnemyTowers == 0
	then
		if Fu.IsValidHero(botTarget) and Fu.IsInRange(bot, botTarget, 2400) and Fu.CanCastOnMagicImmune(botTarget) then
			local towersNearTarget = botTarget:GetNearbyTowers(888, false)
			if #towersNearTarget == 0 then
				hEffectTarget = botTarget
				castReason = "破坏被动:" .. Fu.Chat.GetNormName(botTarget)
				return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
			end
		end
	end
	return Usage.ConsiderItemDesire["item_invis_sword"](item)
end
Usage.ConsiderItemDesire["item_solar_crest"] = function(item)
	local castRange = 1000
	local castType = "unit"
	local hEffectTarget = nil
	local castReason = nil
	local allyHeroes = Fu.GetAlliesNearLoc(bot:GetLocation(), 1000)
	for _, ally in pairs(allyHeroes) do
		if
			Fu.IsValidHero(ally)
			and Fu.IsInRange(bot, ally, castRange)
			and not ally:HasModifier("modifier_legion_commander_press_the_attack")
			and not ally:IsMagicImmune()
			and not ally:IsInvulnerable()
			and ally:CanBeSeen()
		then
			if not ally:IsBot() and ally:GetAttackTarget() ~= nil and ally:GetMaxHealth() - ally:GetHealth() >= 120 then
				hEffectTarget = ally
				castReason = "Solar Crest"
				return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
			end
			if Fu.IsGoingOnSomeone(ally) then
				local allyTarget = Fu.GetProperTarget(ally)
				if
					Fu.IsValidHero(allyTarget)
					and ally:IsFacingLocation(allyTarget:GetLocation(), 20)
					and Fu.IsInRange(ally, allyTarget, ally:GetAttackRange() + 100)
				then
					hEffectTarget = ally
					castReason = "Solar Crest"
					return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
Usage.ConsiderItemDesire["item_sphere"] = function(item)
	local castRange = 700 + castRangeBonus
	local castType = "unit"
	local hEffectTarget = nil
	local castReason = nil
	local enemyHeroes = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	local allyHeroes = Fu.GetNearbyHeroes(bot, castRange, false, BOT_MODE_NONE)
	for _, ally in pairs(allyHeroes) do
		if
			Fu.IsValidHero(ally)
			and ally ~= bot
			and not ally:IsMagicImmune()
			and not ally:IsInvulnerable()
			and not ally:IsIllusion()
			and not ally:HasModifier("modifier_item_sphere_target")
			and not ally:HasModifier("modifier_antimage_spell_shield")
			and (
				Fu.IsUnitTargetProjectileIncoming(ally, 800)
				or Fu.IsWillBeCastUnitTargetSpell(ally, 1200)
				or bot:GetHealth() < 150
			)
		then
			hEffectTarget = ally
			castReason = "帮助队友"
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
		end
	end
	if Fu.IsValidHero(botTarget) and Fu.IsInRange(bot, botTarget, 2400) and not Fu.IsInRange(bot, botTarget, 800) then
		if #allyHeroes >= 2 then
			local closestAlly = nil
			local closestDistance = 9999
			for _, ally in pairs(allyHeroes) do
				if
					ally ~= bot
					and not ally:IsIllusion()
					and Fu.IsInRange(ally, botTarget, closestDistance)
					and not ally:HasModifier("modifier_item_sphere_target")
					and not ally:HasModifier("modifier_antimage_spell_shield")
				then
					closestAlly = ally
					closestDistance = GetUnitToUnitDistance(botTarget, ally)
					if Fu.IsHumanPlayer(ally) then
						break
					end
				end
			end
			if closestAlly ~= nil then
				hEffectTarget = closestAlly
				castReason = "先给前排套上"
				return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
Usage.ConsiderItemDesire["item_spirit_vessel"] = function(item)
	return Usage.ConsiderItemDesire["item_urn_of_shadows"](item)
end
-- Essence Distiller on the ground (datafeed: placed on the ground it stays dormant 15s, latches onto
-- the first enemy within 450 and gives True Sight and shared vision on it; cast range 1000). Used
-- on an enemy hero seen turning invisible in the last 4s whose last spot is within cast range and
-- still in our vision, when the bot has no Dust ready to do it. [OHA-ITEM] distiller-ground.
-- Enemy heroes seen turning invisible, kept 4s (Dust keeps its own copy with its own logs). The
-- reveal order is Dust, then a Sentry (plain or from a dispenser), then the Distiller: each one
-- holds back while one earlier in the order is ready.
local function TrackFaders()
	local now = DotaTime()
	bot._faders = bot._faders or {}
	for _, enemy in pairs(Fu.GetEnemiesNearLoc(bot:GetLocation(), 1600) or {}) do
		if
			Fu.IsValidHero(enemy)
			and Fu.IsUnitWillGoInvisible(enemy)
			and not Fu.HasInvisCounterBuff(enemy)
			and not Fu.IsSuspiciousIllusion(enemy)
		then
			bot._faders[enemy:GetPlayerID()] = { t = now, loc = enemy:GetLocation(), name = enemy:GetUnitName() }
		end
	end
	for playerId, fader in pairs(bot._faders) do
		if now - fader.t > 4 or not IsHeroAlive(playerId) then
			bot._faders[playerId] = nil
		end
	end
end
local function ReadyMainItem(name)
	local slot = bot:FindItemSlot(name)
	if slot < 0 or slot > 5 then
		return nil
	end
	local item = bot:GetItemInSlot(slot)
	if item ~= nil and Fu.CanCastAbility(item) then
		return item
	end
	return nil
end
local function SentryReady()
	if ReadyMainItem("item_ward_sentry") ~= nil then
		return true
	end
	local dispenser = ReadyMainItem("item_ward_dispenser")
	return dispenser ~= nil and (dispenser:GetSecondaryCharges() or 0) > 0
end
-- A fader out of sight whose last spot is within maxDist and still in our vision. Faders in skip
-- (playerId -> DotaTime until which he is passed over) are passed over.
local function FaderSpot(maxDist, skip)
	TrackFaders()
	local now = DotaTime()
	for playerId, fader in pairs(bot._faders) do
		local info = GetHeroLastSeenInfo(playerId)
		local lastSeen = info ~= nil and info[1] or nil
		local loc = lastSeen ~= nil and lastSeen.location or fader.loc
		local gone = lastSeen == nil or lastSeen.time_since_seen > 0.1
		local skipped = skip ~= nil and (skip[playerId] or -1) > now
		if gone and not skipped and GetUnitToLocationDistance(bot, loc) <= maxDist and IsLocationVisible(loc) then
			return playerId, loc, fader.name
		end
	end
	return nil
end
local function RevealLog(item, who, dist)
	pcall(
		print,
		string.format(
			"[OHA-ITEM] t=%.0f %s %s-reveal on %s dist=%d",
			DotaTime(),
			(string.gsub(bot:GetUnitName(), "npc_dota_hero_", "")),
			item,
			(string.gsub(tostring(who), "npc_dota_hero_", "")),
			math.floor(dist)
		)
	)
end
-- Sentry spot for a fader: cast range 500, True Sight 1050 (game files). The ward goes on his
-- last spot when that is within 500, else 480 toward it.
local function SentrySpotFor(loc)
	local botLocation = bot:GetLocation()
	local dx, dy = loc.x - botLocation.x, loc.y - botLocation.y
	local len = math.sqrt(dx * dx + dy * dy)
	if len <= 500 then
		return loc
	end
	return Vector(botLocation.x + dx / len * 480, botLocation.y + dy / len * 480, loc.z)
end
-- No sentry where True Sight already is (our towers, an allied sentry or Gem: Site.IsLocationHaveTrueSight),
-- and none closer than 1050 (sentry True Sight radius, game files) to an allied sentry, so the circles
-- do not overlap. User rule.
local SENTRY_SIGHT = 1050
local function SentrySpotUseless(spot)
	if Fu.Site.IsLocationHaveTrueSight(spot) then
		return "true-sight"
	end
	for _, ward in pairs(GetUnitList(UNIT_LIST_ALLIED_WARDS) or {}) do
		if
			Fu.IsValid(ward)
			and ward:GetUnitName() == "npc_dota_sentry_wards"
			and GetUnitToLocationDistance(ward, spot) < SENTRY_SIGHT
		then
			return "sentry-near"
		end
	end
	return nil
end
Usage.SentrySpotUseless = SentrySpotUseless
function Usage.ConsiderSentryReveal(item, isDispenser)
	if ReadyMainItem("item_dust") ~= nil then
		return BOT_ACTION_DESIRE_NONE
	end
	-- Game 037: a skip cleared the fader and the next think re-added him (up to 30 lines/s). A skipped
	-- fader is now passed over for 5s, so the skip is logged once per fader per 5s.
	bot._sentrySkipUntil = bot._sentrySkipUntil or {}
	local pid, loc, who = FaderSpot(500 + 1000, bot._sentrySkipUntil)
	if pid == nil then
		return BOT_ACTION_DESIRE_NONE
	end
	do
		local why = SentrySpotUseless(loc) or SentrySpotUseless(SentrySpotFor(loc))
		if why ~= nil then
			bot._sentrySkipUntil[pid] = DotaTime() + 5
			pcall(
				print,
				string.format(
					"[OHA-ITEM] t=%.0f %s sentry-skip on %s why=%s hold=5s",
					DotaTime(),
					(string.gsub(bot:GetUnitName(), "npc_dota_hero_", "")),
					(string.gsub(tostring(who), "npc_dota_hero_", "")),
					why
				)
			)
			return BOT_ACTION_DESIRE_NONE
		end
	end
	if isDispenser then
		if (item:GetSecondaryCharges() or 0) <= 0 then
			return BOT_ACTION_DESIRE_NONE
		end
		-- Toggle state true = observer (game 032). Switch to sentry first and cast on a later think;
		-- not with no observers in it (a sentry-only dispenser plants sentries, c428dc4), and at most
		-- one switch a second.
		local toggleOk, toggleState = pcall(function()
			return item:GetToggleState()
		end)
		if toggleOk and toggleState == true and (item:GetCurrentCharges() or 0) > 0 then
			if DotaTime() < (bot._revealToggleAt or -99) + 1 then
				return BOT_ACTION_DESIRE_NONE
			end
			bot._revealToggleAt = DotaTime()
			return BOT_ACTION_DESIRE_HIGH, bot, "unit", "dispenser-to-sentry"
		end
	end
	bot._faders[pid] = nil
	RevealLog(isDispenser and "dispenser-sentry" or "sentry", who, GetUnitToLocationDistance(bot, loc))
	return BOT_ACTION_DESIRE_HIGH, SentrySpotFor(loc), "ground", "sentry-reveal"
end
Usage.ConsiderItemDesire["item_ward_dispenser"] = function(item)
	return Usage.ConsiderSentryReveal(item, true)
end
local function DistillerGroundSpot()
	if ReadyMainItem("item_dust") ~= nil or SentryReady() then
		return nil
	end
	local pid, loc, who = FaderSpot(1000 + castRangeBonus)
	if pid ~= nil then
		bot._faders[pid] = nil
		return loc, who
	end
	return nil
end
Usage.ConsiderItemDesire["item_essence_distiller"] = function(item)
	if item:GetCurrentCharges() == 0 then
		return BOT_ACTION_DESIRE_NONE
	end
	do
		local spot, who = DistillerGroundSpot()
		if spot ~= nil then
			pcall(
				print,
				string.format(
					"[OHA-ITEM] t=%.0f %s distiller-ground on %s dist=%d",
					DotaTime(),
					(string.gsub(bot:GetUnitName(), "npc_dota_hero_", "")),
					(string.gsub(tostring(who), "npc_dota_hero_", "")),
					math.floor(GetUnitToLocationDistance(bot, spot))
				)
			)
			return BOT_ACTION_DESIRE_HIGH, spot, "ground", "distiller-reveal"
		end
	end
	local castRange = 950 + castRangeBonus
	local castType = "unit"
	local hEffectTarget = nil
	local castReason = nil
	local enemyHeroes = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidHero(botTarget)
			and (
				Fu.CanCastOnNonMagicImmune(botTarget)
					and Fu.IsInRange(bot, botTarget, castRange)
					and not botTarget:HasModifier("modifier_item_urn_damage")
					and not botTarget:HasModifier("modifier_item_spirit_vessel_damage")
					and not botTarget:HasModifier("modifier_item_essence_distiller_damage")
					and not botTarget:HasModifier("modifier_arc_warden_tempest_double")
					and (Fu.GetHP(botTarget) < 0.95 or Fu.IsInRange(bot, botTarget, 700))
				or botTarget:HasModifier("modifier_invoker_cold_snap_freeze")
			)
		then
			hEffectTarget = botTarget
			castReason = "进攻:" .. Fu.Chat.GetNormName(hEffectTarget)
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
		end
	end
	if bot:GetActiveMode() ~= BOT_MODE_ROSHAN then
		local allyHeroes = Fu.GetNearbyHeroes(bot, castRange + 80, false, BOT_MODE_NONE)
		local healTarget = nil
		local lowestHealth = 99999
		for _, ally in pairs(allyHeroes) do
			if
				Fu.IsValid(ally)
				and not ally:IsIllusion()
				and ally:DistanceFromFountain() > 800
				and Fu.CanCastOnNonMagicImmune(ally)
				and not ally:WasRecentlyDamagedByAnyHero(3.1)
				and not ally:HasModifier("modifier_item_spirit_vessel_heal")
				and not ally:HasModifier("modifier_item_urn_heal")
				and not ally:HasModifier("modifier_item_essence_distiller_heal")
				and not ally:HasModifier("modifier_fountain_aura")
				and not ally:HasModifier("modifier_arc_warden_tempest_double")
				and ally:OriginalGetMaxHealth() - ally:OriginalGetHealth() > 450
				and #nearbyEnemies == 0
			then
				if ally:OriginalGetHealth() < lowestHealth then
					healTarget = ally
					lowestHealth = ally:OriginalGetHealth()
				end
			end
		end
		if healTarget ~= nil then
			hEffectTarget = healTarget
			castReason = "治疗:" .. Fu.Chat.GetNormName(hEffectTarget)
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
Usage.ConsiderItemDesire["item_tango"] = function(item)
	if bot:DistanceFromFountain() < 3300 or bot:HasModifier("modifier_tango_heal") then
		return BOT_ACTION_DESIRE_NONE
	end
	if bot._lastTangoUseTime and DotaTime() - bot._lastTangoUseTime < 16 then
		return BOT_ACTION_DESIRE_NONE
	end
	local castRange = 300 + castRangeBonus
	local castType = "unit"
	local hEffectTarget = nil
	local castReason = nil
	local charges = item:GetCurrentCharges()
	if
		bot:GetLevel() <= 12
		and (#nearbyEnemies == 0 or botMode == BOT_MODE_LANING)
		and charges >= 1
		and DotaTime() > 10
		and DotaTime() > Fu.Role["fLastGiveTangoTime"] + 40.0
	then
		local allyHeroes = Fu.GetNearbyHeroes(bot, 800, false, BOT_MODE_NONE)
		for _, ally in pairs(allyHeroes) do
			if ally ~= bot then
				local tangoSlot = ally:FindItemSlot("item_tango")
				if
					tangoSlot == -1
					and not ally:IsIllusion()
					and ally:OriginalGetMaxHealth() - ally:OriginalGetHealth() > 200
					and not ally:HasModifier("modifier_tango_heal")
					and not ally:HasModifier("modifier_arc_warden_tempest_double")
					and not Fu.IsMeepoClone(bot)
					and not Fu.IsMeepoClone(ally)
					and Fu.Item.GetItemCount(ally, "item_tango_single") == 0
					and Fu.Item.GetEmptyInventoryAmount(ally) >= 4
				then
					Fu.Role["fLastGiveTangoTime"] = DotaTime()
					hEffectTarget = ally
					castReason = "分享队友吃树"
					return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
				end
			end
		end
	end
	local tangoSingle = Fu.IsItemAvailable("item_tango_single")
	if tangoSingle ~= nil and tangoSingle:IsFullyCastable() then
		return 0
	end
	return Usage.ConsiderItemDesire["item_tango_single"](item)
end
Usage.ConsiderItemDesire["item_tango_single"] = function(item)
	if bot:DistanceFromFountain() < 3300 or bot:HasModifier("modifier_tango_heal") then
		return 0
	end
	if bot._lastTangoUseTime and DotaTime() - bot._lastTangoUseTime < 16 then
		return 0
	end
	local castRange = 300 + castRangeBonus
	local castType = "tree"
	local hEffectTarget = nil
	local castReason = nil
	local tangoHealAmount = item:GetName() == "item_tango" and 200 or 160
	local missingHealth = bot:OriginalGetMaxHealth() - bot:OriginalGetHealth()
	if bot:HasModifier("modifier_furion_sprout_damage") then
		local closeTrees = bot:GetNearbyTrees(280)
		if
			closeTrees ~= nil
			and #closeTrees >= 8
			and IsLocationVisible(GetTreeLocation(closeTrees[1]))
			and IsLocationPassable(GetTreeLocation(closeTrees[1]))
		then
			hEffectTarget = closeTrees[1]
			castReason = "吃先知的树"
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
		end
	end
	if
		not bot:HasModifier("modifier_flask_healing") and not bot:HasModifier("modifier_juggernaut_healing_ward_heal")
	then
		local nearbyTrees = bot:GetNearbyTrees(800)
		local nearestTree = nearbyTrees[1]
		local enemyHeroes = Fu.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE)
		local nearestEnemy = enemyHeroes[1]
		local enemyTowers = bot:GetNearbyTowers(1400, true)
		local nearestEnemyTower = enemyTowers[1]
		local hpRatio = Fu.GetHP(bot)
		if bot:GetActiveMode() == BOT_MODE_RETREAT and hpRatio > 0.35 and hpRatio < 0.95 and nearestTree ~= nil then
			local treeLocation = GetTreeLocation(nearestTree)
			if
				IsLocationVisible(treeLocation)
				and IsLocationPassable(treeLocation)
				and (#enemyTowers == 0 or GetUnitToLocationDistance(nearestEnemyTower, treeLocation) > 920)
			then
				hEffectTarget = nearestTree
				castReason = "retreat tango"
				return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
			end
		end
		local noEnemyClose = #enemyHeroes == 0 or nearestEnemy ~= nil and not Fu.IsInRange(bot, nearestEnemy, 400)
		if nearestTree ~= nil and missingHealth >= 350 and noEnemyClose then
			local treeLocation = GetTreeLocation(nearestTree)
			if
				IsLocationVisible(treeLocation)
				and IsLocationPassable(treeLocation)
				and (#enemyTowers == 0 or GetUnitToLocationDistance(nearestEnemyTower, treeLocation) > 920)
			then
				hEffectTarget = nearestTree
				castReason = "proactive heal"
				return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
			end
		end
		if nearestTree ~= nil then
			local treeLocation = GetTreeLocation(nearestTree)
			if
				missingHealth > tangoHealAmount
				and IsLocationVisible(treeLocation)
				and IsLocationPassable(treeLocation)
				and (#enemyHeroes == 0 or not Fu.IsInRange(bot, nearestEnemy, 800))
				and (#enemyHeroes == 0 or GetUnitToLocationDistance(bot, treeLocation) * 1.6 < GetUnitToUnitDistance(
					bot,
					nearestEnemy
				))
				and (#enemyTowers == 0 or GetUnitToLocationDistance(nearestEnemyTower, treeLocation) > 920)
			then
				hEffectTarget = nearestTree
				castReason = "800码内的树"
				return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
			end
		end
		local allyTowers = bot:GetNearbyTowers(1100, false)
		if #allyTowers >= 1 and missingHealth > tangoHealAmount + 20 then
			local allyTower = allyTowers[1]
			if allyTower ~= nil then
				local treeSearchRadius = 1100 - GetUnitToUnitDistance(bot, allyTower)
				local towerTrees = bot:GetNearbyTrees(treeSearchRadius)
				local towerTree = towerTrees[1]
				if towerTree ~= nil then
					local treeLocation = GetTreeLocation(towerTree)
					if IsLocationVisible(treeLocation) and IsLocationPassable(treeLocation) then
						hEffectTarget = towerTree
						castReason = "吃塔下的树"
						return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
					end
				end
			end
		end
		local closeTrees = bot:GetNearbyTrees(280)
		if
			closeTrees[1] ~= nil
			and IsLocationVisible(GetTreeLocation(closeTrees[1]))
			and IsLocationPassable(GetTreeLocation(closeTrees[1]))
		then
			if missingHealth > tangoHealAmount then
				hEffectTarget = closeTrees[1]
				castReason = "近处的树"
				return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
			end
			if missingHealth > tangoHealAmount * 0.38 and bot:WasRecentlyDamagedByAnyHero(2.0) then
				hEffectTarget = closeTrees[1]
				castReason = "提前吃树"
				return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
			end
		end
	end
	if
		DotaTime() > 4 * 60 + 30
		and botTarget == nil
		and item:GetName() == "item_tango_single"
		and bot:DistanceFromFountain() > 3000
		and botMode ~= BOT_MODE_RUNE
	then
		local tangoSingleCount = Fu.Item.GetItemCount(bot, "item_tango_single")
		local enemyHeroes = Fu.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE)
		if tangoSingleCount >= 2 then
			local nearbyTrees = bot:GetNearbyTrees(1200)
			if
				nearbyTrees[1] ~= nil
				and IsLocationVisible(GetTreeLocation(nearbyTrees[1]))
				and IsLocationPassable(GetTreeLocation(nearbyTrees[1]))
				and #enemyHeroes == 0
			then
				hEffectTarget = nearbyTrees[1]
				castReason = "消耗共享吃树"
				return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
			end
		end
		if DotaTime() > 7 * 60 + 30 then
			local nearbyTrees = bot:GetNearbyTrees(1200)
			if
				nearbyTrees[1] ~= nil
				and IsLocationVisible(GetTreeLocation(nearbyTrees[1]))
				and IsLocationPassable(GetTreeLocation(nearbyTrees[1]))
				and missingHealth > 60
				and #enemyHeroes == 0
			then
				hEffectTarget = nearbyTrees[1]
				castReason = "用掉共享吃树"
				return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
Usage.ConsiderItemDesire["item_tome_of_knowledge"] = function(item)
	local castRange = 300
	local castType = "none"
	local hEffectTarget = nil
	local castReason = nil
	local enemyHeroes = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	if item:IsFullyCastable() then
		hEffectTarget = bot
		castReason = "读书"
		return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
	end
	return BOT_ACTION_DESIRE_NONE
end
function Usage.GetLaningTPLocation(hero, tpDistance, botLocation)
	if GetGameMode() == GAMEMODE_1V1MID or GetGameMode() == GAMEMODE_MO then
		return nil, false
	end
	local lane
	local farFromLane = false
	if IsLanMode and IsLanMode() then
		local assignedLane = hero:GetAssignedLane()
		if assignedLane == LANE_TOP or assignedLane == LANE_MID or assignedLane == LANE_BOT then
			lane = assignedLane
		end
	end
	if lane == nil then
		local position = Fu.GetPosition(hero)
		if team == TEAM_RADIANT then
			if position == 1 then
				lane = LANE_BOT
			elseif position == 2 then
				lane = LANE_MID
			elseif position == 3 or position == 4 then
				lane = LANE_TOP
			elseif position == 5 then
				lane = LANE_BOT
			end
		elseif team == TEAM_DIRE then
			if position == 1 then
				lane = LANE_TOP
			elseif position == 2 then
				lane = LANE_MID
			elseif position == 3 or position == 4 then
				lane = LANE_BOT
			elseif position == 5 then
				lane = LANE_TOP
			end
		end
	end
	local laneAmount = GetAmountAlongLane(lane, botLocation)
	local laneFrontAmount = GetLaneFrontAmount(team, lane, false)
	if laneAmount.distance > tpDistance or laneAmount.amount < laneFrontAmount / 5 then
		farFromLane = true
	end
	local laneNames = { [LANE_TOP] = "top", [LANE_MID] = "mid", [LANE_BOT] = "bot" }
	if farFromLane then
		pcall(
			NoLog,
			string.format(
				"[OHA-TP] diag-laning %s pos=%s assigned=%s chose=%s lan=%s",
				hero:GetUnitName(),
				tostring(Fu.GetPosition(hero)),
				tostring(laneNames[hero:GetAssignedLane()] or hero:GetAssignedLane()),
				tostring(laneNames[lane] or lane),
				tostring(IsLanMode and IsLanMode())
			)
		)
	end
	return GetLaneFrontLocation(team, lane, 100), farFromLane
end
function Usage.GetDefendTPLocation(lane)
	return GetLaneFrontLocation(team, lane, -950)
end
function Usage.GetPushTPLocation(lane)
	local laneFront = GetLaneFrontLocation(team, lane, 0)
	local tpLocation = Fu.GetNearbyLocationToTp(laneFront)
	if Fu.GetLocationToLocationDistance(laneFront, tpLocation) < 2000 then
		return tpLocation
	end
end
function Usage.CanJuke()
	local allyTowers = bot:GetNearbyTowers(350, false)
	if
		allyTowers[1] ~= nil
		and allyTowers[1]:DistanceFromFountain() > bot:DistanceFromFountain() + 100
		and Fu.GetEnemyCount(bot, 700) == 0
	then
		return true
	end
	if
		Fu.GetModifierTime(bot, "modifier_dazzle_shallow_grave") > 3.0
		or Fu.GetModifierTime(bot, "modifier_oracle_false_promise_timer") > 3.0
	then
		return true
	end
	local enemyPlayers = GetTeamPlayers(GetOpposingTeam())
	local botHeightLevel = GetHeightLevel(bot:GetLocation())
	for i = 1, #enemyPlayers do
		local lastSeenInfo = GetHeroLastSeenInfo(enemyPlayers[i])
		if lastSeenInfo ~= nil then
			local lastSeen = lastSeenInfo[1]
			if lastSeen ~= nil and lastSeen.time_since_seen < 2.0 then
				if
					GetUnitToLocationDistance(bot, lastSeen.location) < 1300
					and GetHeightLevel(lastSeen.location) < botHeightLevel
				then
					return false
				end
				if GetUnitToLocationDistance(bot, lastSeen.location) < 600 then
					local enemyHeroes = Fu.GetNearbyHeroes(bot, 600, true, BOT_MODE_NONE)
					if #enemyHeroes == 0 then
						return false
					end
				end
			end
		end
	end
	local totalDamage = 0
	local enemyHeroes = Fu.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE)
	for _, enemy in pairs(enemyHeroes) do
		local damage = enemy:GetEstimatedDamageToTarget(true, bot, 4.0, DAMAGE_TYPE_ALL)
		totalDamage = totalDamage + damage
		if bot:OriginalGetHealth() <= totalDamage then
			return false
		end
	end
	return true
end
function Usage.GetNumHeroWithinRange(range)
	local enemyPlayers = GetTeamPlayers(GetOpposingTeam())
	local heroCount = 0
	for i = 1, #enemyPlayers do
		local lastSeenInfo = GetHeroLastSeenInfo(enemyPlayers[i])
		if lastSeenInfo ~= nil then
			local lastSeen = lastSeenInfo[1]
			if
				lastSeen ~= nil
				and lastSeen.time_since_seen < 2.0
				and GetUnitToLocationDistance(bot, lastSeen.location) < range
			then
				heroCount = heroCount + 1
			end
		end
	end
	return heroCount
end
function Usage.IsFarmingAlways(hero)
	local attackTarget = hero:GetAttackTarget()
	if
		Fu.IsValid(attackTarget)
		and attackTarget:GetTeam() == TEAM_NEUTRAL
		and not Fu.IsRoshan(attackTarget)
		and not Fu.IsKeyWordUnit("warlock", attackTarget)
		and Usage.GetNumEnemyNearby(GetAncient(team)) >= 2
	then
		return true
	end
	local allyHeroes = Fu.GetNearbyHeroes(hero, 800, false, BOT_MODE_NONE)
	-- Removed: an Intelligence hero hitting an ancient creep with fewer than 2 allies around was
	-- TP'd to its own Ancient, with no danger at all (game 019, 27:52: Lina from an ancient camp
	-- by the Radiant outpost to the Dire top T3). Only enemies at the base send a farmer home now.
	if Usage.GetNumEnemyNearby(GetAncient(team)) >= 4 and hero:DistanceFromFountain() >= 4800 and #allyHeroes < 2 then
		return true
	end
	return false
end
function Usage.IsBaseTowerDestroyed()
	for towerIndex = 9, 10, 1 do
		local tower = GetTower(team, towerIndex)
		if tower == nil or tower:GetHealth() / tower:GetMaxHealth() < 0.99 then
			return true
		end
	end
	return false
end
if bot.useProphetTP == nil then
	bot.useProphetTP = false
end
if bot.ProphetTPLocation == nil then
	bot.ProphetTPLocation = bot:GetLocation()
end
Usage.ConsiderItemDesire["item_tpscroll"] = function(item)
	if
		botMode == BOT_MODE_RUNE
		or bot:IsRooted()
		or bot:HasModifier("modifier_item_armlet_unholy_strength")
		or bot:HasModifier("modifier_kunkka_x_marks_the_spot")
		or bot:HasModifier("modifier_teleporting")
		or bot:HasModifier("modifier_sniper_assassinate")
		or bot:HasModifier("modifier_viper_nethertoxin")
		or bot:HasModifier("modifier_oracle_false_promise_timer") and Fu.GetModifierTime(
			bot,
			"modifier_oracle_false_promise_timer"
		) <= 3.2
		or bot:HasModifier("modifier_jakiro_macropyre_burn") and Fu.GetModifierTime(
			bot,
			"modifier_jakiro_macropyre_burn"
		) >= 1.4
		or bot:HasModifier("modifier_arc_warden_tempest_double") and bot:GetRemainingLifespan() < 3.3
		or Fu.IsDoingRoshan(bot) and GetUnitToLocationDistance(bot, Fu.GetCurrentRoshanLocation()) <= 2800
		or bot._roshDipActive and bot:IsAlive() and GetUnitToLocationDistance(bot, Fu.GetCurrentRoshanLocation()) <= 3000
		or Fu.IsDoingTormentor(bot) and GetUnitToLocationDistance(bot, Fu.GetTormentorLocation(GetTeam())) <= 2800
	then
		return BOT_ACTION_DESIRE_NONE
	end
	if bot:GetHealth() < 240 then
		local projectileDamage = Fu.GetAttackProjectileDamageByRange(bot, 1600) * 2
		if bot:GetHealth() < bot:GetActualIncomingDamage(projectileDamage, DAMAGE_TYPE_PHYSICAL) then
			return BOT_ACTION_DESIRE_NONE
		end
	end
	if bot:HasModifier("modifier_spirit_breaker_charge_of_darkness") or bot.healInBase then
		return BOT_ACTION_DESIRE_NONE
	end
	local enemyTowers = bot:GetNearbyTowers(888, true)
	if #enemyTowers > 0 then
		return BOT_ACTION_DESIRE_NONE
	end
	local tpLocation = nil
	local castType = "ground"
	local hEffectTarget = nil
	local castReason = nil
	local tpDistance = 5500
	local activeMode = bot:GetActiveMode()
	local modeDesire = bot:GetActiveModeDesire()
	local botLocation = bot:GetLocation()
	local hpRatio = Fu.GetHP(bot)
	local mpRatio = Fu.GetMP(bot)
	local nearbyEnemyCount = Usage.GetNumHeroWithinRange(1600)
	local nearbyAllyCount = Fu.GetAllyCount(bot, 1600)
	local flask = Fu.IsItemAvailable("item_flask")
	if bot:GetLevel() > 12 and bot:DistanceFromFountain() < 600 then
		tpDistance = tpDistance + 600
	end
	-- No TP out of the fountain while creeps are hitting our base: at 37:27 Tusk teleported
	-- out to farm with 3 enemy creeps at our Ancient. Walk out and defend instead.
	local baseCreeps = 0
	local ourAncient = GetAncient(GetTeam())
	if ourAncient ~= nil then
		for _, creep in pairs(GetUnitList(UNIT_LIST_ENEMY_CREEPS) or {}) do
			if creep ~= nil and creep:IsAlive() and GetUnitToUnitDistance(creep, ourAncient) <= 1600 then
				baseCreeps = baseCreeps + 1
			end
		end
	end
	local baseUnderCreeps = baseCreeps >= 2
		or Fu.Utils.HighGroundCreepWaveNear ~= nil and Fu.Utils.HighGroundCreepWaveNear(bot, 30000) ~= nil
	if
		bot:DistanceFromFountain() < 1500
		and hpRatio > 0.75
		and nearbyEnemyCount == 0
		and not bot:HasModifier("modifier_teleporting")
		and DotaTime() > 15
		and not baseUnderCreeps
		-- An item waits to be sold (item_purchase_generic SellMarkedItems): reach the fountain first.
		and not (bot._sellPending and bot:DistanceFromFountain() > 500)
	then
		local lane = Usage.GetLaneByPosition(bot)
		if not Fu.IsInLaningPhase() and DotaTime() > 10 * 60 then
			if activeMode == BOT_MODE_DEFEND_TOWER_TOP then
				lane = LANE_TOP
			elseif activeMode == BOT_MODE_DEFEND_TOWER_MID then
				lane = LANE_MID
			elseif activeMode == BOT_MODE_DEFEND_TOWER_BOT then
				lane = LANE_BOT
			elseif activeMode == BOT_MODE_PUSH_TOWER_TOP then
				lane = LANE_TOP
			elseif activeMode == BOT_MODE_PUSH_TOWER_MID then
				lane = LANE_MID
			elseif activeMode == BOT_MODE_PUSH_TOWER_BOT then
				lane = LANE_BOT
			elseif bot.laneToDefend ~= nil then
				lane = bot.laneToDefend
			else
				local mostEnemies = 0
				for _, candidateLane in pairs({ LANE_TOP, LANE_MID, LANE_BOT }) do
					local laneFront = GetLaneFrontLocation(GetOpposingTeam(), candidateLane, 0)
					local enemiesNearFront = Fu.GetLastSeenEnemiesNearLoc(laneFront, 800)
					if #enemiesNearFront > mostEnemies then
						mostEnemies = #enemiesNearFront
						lane = candidateLane
					end
				end
			end
		end
		-- Enemy heroes on our high ground (seen within 3500 of our Ancient): defend on foot. A TP from
		-- the fountain to a lane front only takes the bot out of the base (game 036, 37:09: Primal
		-- Beast TP'd to top while Dire was on the bottom high ground).
		do
			local ancient = GetAncient(GetTeam())
			local enemiesOnHighGround = ancient ~= nil and Fu.GetLastSeenEnemiesNearLoc(ancient:GetLocation(), 3500)
				or {}
			if #enemiesOnHighGround >= 1 then
				if DotaTime() >= (bot._tpHgSkipLogAt or -999) then
					bot._tpHgSkipLogAt = DotaTime() + 10
					pcall(
						print,
						string.format(
							"[OHA-TP] t=%.0f %s fountain-tp skip why=enemies-on-hg n=%d",
							DotaTime(),
							botName,
							#enemiesOnHighGround
						)
					)
				end
				return BOT_ACTION_DESIRE_NONE
			end
		end
		local fountainTpLocation = GetLaneFrontLocation(GetTeam(), lane, -500)
		local laneNames = { [LANE_TOP] = "top", [LANE_MID] = "mid", [LANE_BOT] = "bot" }
		-- Printed every think while at the fountain (6,541 lines in one game); once per 10s now.
		if DotaTime() >= (bot._diagFountainLogAt or -999) then
			bot._diagFountainLogAt = DotaTime() + 10
			pcall(
				NoLog,
				string.format(
					"[OHA-TP] diag-fountain %s pos=%s assigned=%s chose=%s mode=%s lan=%s",
					botName,
					tostring(Fu.GetPosition(bot)),
					tostring(laneNames[bot:GetAssignedLane()] or bot:GetAssignedLane()),
					tostring(laneNames[lane] or lane),
					tostring(activeMode),
					tostring(IsLanMode and IsLanMode())
				)
			)
		end
		if fountainTpLocation ~= nil and GetUnitToLocationDistance(bot, fountainTpLocation) > 3500 then
			local laneLabels = { [LANE_TOP] = "top", [LANE_MID] = "mid", [LANE_BOT] = "bot" }
			local enemiesAtFront = Fu.GetLastSeenEnemiesNearLoc(fountainTpLocation, 1600)
			local alliesAtFront = Fu.GetAlliesNearLoc(fountainTpLocation, 1600)
			if #enemiesAtFront <= 1 or #alliesAtFront >= #enemiesAtFront then
				return BOT_ACTION_DESIRE_HIGH, fountainTpLocation, castType, "fountain TP out"
			end
			local saferLaneFront = GetLaneFrontLocation(GetTeam(), lane, -1500)
			if GetUnitToLocationDistance(bot, saferLaneFront) > 3500 then
				return BOT_ACTION_DESIRE_HIGH, saferLaneFront, castType, "fountain TP safe"
			end
		end
	end
	if activeMode == BOT_MODE_LANING and not Usage.JustTeleported() then
		local shouldTp
		hEffectTarget, shouldTp = Usage.GetLaningTPLocation(bot, tpDistance, botLocation)
		castReason = "出去发育"
		if shouldTp then
			if botName == "npc_dota_hero_furion" then
				local prophetTeleport = bot:GetAbilityByName("furion_teleportation")
				if prophetTeleport:IsTrained() and prophetTeleport:IsFullyCastable() then
					bot.useProphetTP = true
					bot.ProphetTPLocation = hEffectTarget
					return BOT_ACTION_DESIRE_NONE
				end
			end
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
		end
	end
	if
		Usage.IsInvFull(bot)
		and Usage.GetNumStashItem(bot) >= 1
		and (bot:GetStashValue() >= 1200 and Usage.IsThereRecipeInStash(bot) or bot:GetStashValue() >= 2000 and bot:GetGold() > 1100)
		and not Fu.IsPushing(bot)
		and bot:GetActiveMode() ~= BOT_MODE_ATTACK
		and not Fu.IsInTeamFight(bot, 1200)
		and not Fu.Utils.IsTeamPushingSecondTierOrHighGround(bot)
		and nearbyEnemyCount == 0
	then
		hEffectTarget = Fu.GetTeamFountain()
		castReason = "撤退:1"
		if botName == "npc_dota_hero_furion" then
			local prophetTeleport = bot:GetAbilityByName("furion_teleportation")
			if prophetTeleport:IsTrained() and prophetTeleport:IsFullyCastable() then
				bot.useProphetTP = true
				bot.ProphetTPLocation = hEffectTarget
				return BOT_ACTION_DESIRE_NONE
			end
		end
		return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
	end
	if Fu.IsDoingRoshan(bot) and nearbyEnemyCount == 0 and not Fu.IsRoshanCloseToChangingSides() then
		local roshanLocation = Fu.GetCurrentRoshanLocation()
		local roshanTpLocation = Fu.GetNearbyLocationToTp(roshanLocation)
		local roshanTpDistance = GetUnitToLocationDistance(bot, roshanTpLocation)
		local roshanDistance = GetUnitToLocationDistance(bot, roshanLocation)
		if roshanTpDistance > 8000 and roshanDistance > 8000 and roshanDistance > roshanTpDistance then
			if botName == "npc_dota_hero_furion" then
				local prophetTeleport = bot:GetAbilityByName("furion_teleportation")
				if prophetTeleport:IsTrained() and prophetTeleport:IsFullyCastable() then
					bot.useProphetTP = true
					bot.ProphetTPLocation = roshanTpLocation
					return BOT_ACTION_DESIRE_NONE
				end
			end
			return BOT_ACTION_DESIRE_HIGH, roshanTpLocation, "ground", "tp_roshan"
		end
	end
	-- Side shop / watcher mode only means Tormentor once our Tormentor mode can run (20:00,
	-- 10:00 in Turbo). Before that it is the engine's own watcher trip: at 0:10 Snapfire and
	-- earlier Phoenix TP'd to the tower nearest the Tormentor and walked back to their lane.
	if
		(bot:GetActiveMode() == BOT_MODE_SIDE_SHOP or bot:GetActiveMode() == BOT_MODE_WATCHER)
		and DotaTime() >= (Fu.IsModeTurbo() and 10 or 20) * 60
		and nearbyEnemyCount == 0
		-- Was "not A or not B or not C", true almost always (game 036: 7 Tormentor TPs, 0 kills).
		and not Fu.IsInTeamFight(bot, 1200)
		and not Fu.IsGoingOnSomeone(bot)
		and not Fu.IsDefending(bot)
	then
		local tormentorLocation = Fu.GetTormentorLocation(team)
		-- Only TP when 2+ other allies are coming (in Tormentor mode or at the spot) and our lanes
		-- are not under attack; every game-036 gather showed here=0/1 with the rest declined.
		local coming = 0
		for i = 1, 5 do
			local teammate = GetTeamMember(i)
			if
				teammate ~= nil
				and teammate ~= bot
				and teammate:IsAlive()
				and (Fu.IsDoingTormentor(teammate) or GetUnitToLocationDistance(teammate, tormentorLocation) <= 1600)
			then
				coming = coming + 1
			end
		end
		local threat = Fu.OurLaneThreatened()
		if (coming < 2 or threat ~= nil) and GetUnitToLocationDistance(bot, tormentorLocation) > 8000 then
			if DotaTime() >= (bot._tormentorTpSkipLogAt or -999) then
				bot._tormentorTpSkipLogAt = DotaTime() + 10
				pcall(
					print,
					string.format(
						"[OHA-TORMENTOR] t=%.0f %s tp-skip why=%s coming=%d",
						DotaTime(),
						(string.gsub(bot:GetUnitName(), "npc_dota_hero_", "")),
						threat or "few-allies",
						coming
					)
				)
			end
			tormentorLocation = bot:GetLocation()
		end
		if GetUnitToLocationDistance(bot, tormentorLocation) > 8000 then
			hEffectTarget = Fu.GetNearbyLocationToTp(tormentorLocation)
			castReason = "tormentor"
			if Fu.GetLocationToLocationDistance(bot:GetLocation(), hEffectTarget) > 4400 then
				if botName == "npc_dota_hero_furion" then
					local prophetTeleport = bot:GetAbilityByName("furion_teleportation")
					if prophetTeleport:IsTrained() and prophetTeleport:IsFullyCastable() then
						bot.useProphetTP = true
						bot.ProphetTPLocation = hEffectTarget
						return BOT_ACTION_DESIRE_NONE
					end
				end
				return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
			end
		end
	end
	if Fu.IsDefending(bot) and modeDesire > BOT_MODE_DESIRE_LOW and nearbyEnemyCount == 0 then
		local defendLane, towerLabel = LANE_MID, "tower_mid"
		if activeMode == BOT_MODE_DEFEND_TOWER_TOP then
			defendLane, towerLabel = LANE_TOP, "tower_top"
		end
		if activeMode == BOT_MODE_DEFEND_TOWER_BOT then
			defendLane, towerLabel = LANE_BOT, "tower_bot"
		end
		local laneAmount = GetAmountAlongLane(defendLane, botLocation)
		local laneFrontAmount = GetLaneFrontAmount(team, defendLane, false)
		if laneAmount.distance > tpDistance or laneAmount.amount < laneFrontAmount / 5 then
			tpLocation = Usage.GetDefendTPLocation(defendLane)
		end
		if tpLocation ~= nil and GetUnitToLocationDistance(bot, tpLocation) > tpDistance - 500 then
			hEffectTarget = tpLocation
			castReason = "前往守塔:" .. towerLabel
			if botName == "npc_dota_hero_furion" then
				local prophetTeleport = bot:GetAbilityByName("furion_teleportation")
				if prophetTeleport:IsTrained() and prophetTeleport:IsFullyCastable() then
					bot.useProphetTP = true
					bot.ProphetTPLocation = hEffectTarget
					return BOT_ACTION_DESIRE_NONE
				end
			end
			return BOT_ACTION_DESIRE_ABSOLUTE, hEffectTarget, castType, castReason
		end
	end
	if Fu.IsPushing(bot) and modeDesire >= BOT_MODE_DESIRE_LOW and nearbyEnemyCount == 0 then
		local pushLane, towerLabel = LANE_MID, "tower_mid"
		if activeMode == BOT_MODE_PUSH_TOWER_TOP then
			pushLane, towerLabel = LANE_TOP, "tower_top"
		end
		if activeMode == BOT_MODE_PUSH_TOWER_BOT then
			pushLane, towerLabel = LANE_BOT, "tower_bot"
		end
		local laneAmount = GetAmountAlongLane(pushLane, botLocation)
		local laneFrontAmount = GetLaneFrontAmount(team, pushLane, false)
		if
			laneAmount.amount < laneFrontAmount - 0.05
			and (laneAmount.distance > tpDistance or laneAmount.amount < laneFrontAmount / 5)
		then
			tpLocation = Usage.GetPushTPLocation(pushLane)
		end
		if
			tpLocation ~= nil
			and GetUnitToLocationDistance(bot, tpLocation) > tpDistance - 600
			and GetAmountAlongLane(pushLane, tpLocation).amount > laneAmount.amount
		then
			hEffectTarget = tpLocation
			castReason = "前往推塔:" .. towerLabel
			if botName == "npc_dota_hero_furion" then
				local prophetTeleport = bot:GetAbilityByName("furion_teleportation")
				if prophetTeleport:IsTrained() and prophetTeleport:IsFullyCastable() then
					bot.useProphetTP = true
					bot.ProphetTPLocation = hEffectTarget
					return BOT_ACTION_DESIRE_NONE
				end
			end
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
		end
	end
	if
		activeMode == BOT_MODE_DEFEND_ALLY
		and modeDesire >= BOT_MODE_DESIRE_LOW
		and Fu.Role.CanBeSupport(botName)
		and nearbyEnemyCount == 0
	then
		local defendTarget = bot:GetTarget()
		if defendTarget ~= nil and defendTarget:IsHero() and GetUnitToUnitDistance(bot, defendTarget) > tpDistance then
			local nearestTpSpot = Fu.GetNearbyLocationToTp(defendTarget:GetLocation())
			if nearestTpSpot ~= nil and GetUnitToLocationDistance(bot, nearestTpSpot) > tpDistance - 800 then
				tpLocation = nearestTpSpot
			end
		end
		if tpLocation ~= nil then
			hEffectTarget = tpLocation
			castReason = "支援队友:" .. Fu.Chat.GetNormName(defendTarget)
			if botName == "npc_dota_hero_furion" then
				local prophetTeleport = bot:GetAbilityByName("furion_teleportation")
				if prophetTeleport:IsTrained() and prophetTeleport:IsFullyCastable() then
					bot.useProphetTP = true
					bot.ProphetTPLocation = hEffectTarget
					return BOT_ACTION_DESIRE_NONE
				end
			end
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
		end
	end
	if
		activeMode == BOT_MODE_RETREAT
		and modeDesire >= BOT_MODE_DESIRE_LOW
		and bot:GetLevel() >= 3
		and not bot:HasModifier("modifier_arc_warden_tempest_double")
	then
		local function HasTangoToEat()
			if bot:HasModifier("modifier_tango_heal") then
				return true
			end
			for _, name in pairs({ "item_tango", "item_tango_single" }) do
				local slot = bot:FindItemSlot(name)
				if slot >= 0 and slot <= 8 then
					local tangoItem = bot:GetItemInSlot(slot)
					if tangoItem ~= nil then
						local charges = tangoItem:GetCurrentCharges()
						if charges == nil or charges > 0 then
							return true
						end
					end
				end
			end
			return false
		end
		-- Above half health, a tango refills him. A fountain TP spends the scroll for nothing.
		local tangoInstead = hpRatio > 0.5 and HasTangoToEat()
		if
			hpRatio < 0.19
			and (bot:WasRecentlyDamagedByAnyHero(8.0) or hpRatio < 0.12)
			and botName ~= "npc_dota_hero_huskar"
			and (botName ~= "npc_dota_hero_slark" or bot:GetLevel() <= 5)
			and nearbyEnemyCount == 0
			and flask == nil
			and not bot:HasModifier("modifier_tango_heal")
			and not bot:HasModifier("modifier_flask_healing")
			and not bot:HasModifier("modifier_juggernaut_healing_ward_heal")
			and not bot:HasModifier("modifier_item_urn_heal")
			and not bot:HasModifier("modifier_item_spirit_vessel_heal")
			and bot:DistanceFromFountain() > tpDistance
		then
			tpLocation = Fu.GetTeamFountain()
			castReason = "撤退:1"
			if botName == "npc_dota_hero_furion" then
				local prophetTeleport = bot:GetAbilityByName("furion_teleportation")
				if prophetTeleport:IsTrained() and prophetTeleport:IsFullyCastable() then
					bot.useProphetTP = true
					bot.ProphetTPLocation = hEffectTarget
					return BOT_ACTION_DESIRE_NONE
				end
			end
			return BOT_ACTION_DESIRE_HIGH, tpLocation, castType, castReason
		end
		local attackingAllies = Fu.GetNearbyHeroes(bot, 1500, false, BOT_MODE_ATTACK)
		-- Retreat TP home: HP under 15% + 24% per enemy hero within 1600 (two enemies: 63%). In
		-- the laning phase that sent Doom home at 3:57 (game 018) and cost the lane; there it
		-- needs HP under 35% (40% with 3+ enemies), walking back or regen covers the rest.
		local tpHpLine = 0.15 + 0.24 * nearbyEnemyCount
		if Fu.IsInLaningPhase() then
			tpHpLine = math.min(tpHpLine, nearbyEnemyCount >= 3 and 0.4 or 0.35)
		end
		-- Game 038, 8:10: Kez TP'd home at 54% HP / 83% mana against two (line 63%) and lost the lane. Cap the
		-- line at 45%, and with one of our towers within 2500 walk to it instead unless under 35%.
		tpHpLine = math.min(tpHpLine, 0.45)
		local ownTowerNear = false
		for _, building in pairs(GetUnitList(UNIT_LIST_ALLIED_BUILDINGS) or {}) do
			if
				building ~= nil
				and not building:IsNull()
				and building:IsAlive()
				and building:IsTower()
				and GetUnitToUnitDistance(bot, building) < 2500
			then
				ownTowerNear = true
				break
			end
		end
		if ownTowerNear and hpRatio >= 0.35 and hpRatio < tpHpLine then
			if DotaTime() >= (bot._tpWalkLogAt or -999) then
				bot._tpWalkLogAt = DotaTime() + 10
				pcall(
					print,
					string.format(
						"[OHA-TP] t=%.0f %s tp-home-skip why=tower-near hp=%.2f enemies=%d line=%.2f",
						DotaTime(),
						(string.gsub(botName, "npc_dota_hero_", "")),
						hpRatio,
						nearbyEnemyCount,
						tpHpLine
					)
				)
			end
			tpHpLine = 0.35
		end
		if
			hpRatio < tpHpLine
			and #attackingAllies == 0
			and bot:WasRecentlyDamagedByAnyHero(6.0)
			and Usage.CanJuke()
			and nearbyEnemyCount <= (hpRatio < 0.4 and 2 or 3)
			and nearbyAllyCount <= 2
			and flask == nil
			and not tangoInstead
			and not bot:HasModifier("modifier_tango_heal")
			and not bot:HasModifier("modifier_flask_healing")
			and not bot:HasModifier("modifier_item_urn_heal")
			and not bot:HasModifier("modifier_item_spirit_vessel_heal")
			and not bot:HasModifier("modifier_juggernaut_healing_ward_heal")
			and bot:DistanceFromFountain() > tpDistance - 600
		then
			tpLocation = Fu.GetTeamFountain()
			castReason = "撤退:2"
			if botName == "npc_dota_hero_furion" then
				local prophetTeleport = bot:GetAbilityByName("furion_teleportation")
				if prophetTeleport:IsTrained() and prophetTeleport:IsFullyCastable() then
					bot.useProphetTP = true
					bot.ProphetTPLocation = hEffectTarget
					return BOT_ACTION_DESIRE_NONE
				end
			end
			return BOT_ACTION_DESIRE_HIGH, tpLocation, castType, castReason
		end
		if
			(hpRatio < 0.34 or hpRatio + mpRatio < 0.43)
			and #attackingAllies == 0
			and bot:GetLevel() >= 9
			and Usage.CanJuke()
			and nearbyEnemyCount <= 1
			and nearbyAllyCount <= 2
			and flask == nil
			and bot:GetAttackTarget() == nil
			and botName ~= "npc_dota_hero_huskar"
			and botName ~= "npc_dota_hero_slark"
			and not bot:HasModifier("modifier_flask_healing")
			and not bot:HasModifier("modifier_clarity_potion")
			and not bot:HasModifier("modifier_filler_heal")
			and not bot:HasModifier("modifier_item_urn_heal")
			and not bot:HasModifier("modifier_item_spirit_vessel_heal")
			and not bot:HasModifier("modifier_juggernaut_healing_ward_heal")
			and not bot:HasModifier("modifier_bottle_regeneration")
			and not bot:HasModifier("modifier_tango_heal")
			and not tangoInstead
			and bot:DistanceFromFountain() > tpDistance - 600
		then
			tpLocation = Fu.GetTeamFountain()
			castReason = "撤退:3"
			if botName == "npc_dota_hero_furion" then
				local prophetTeleport = bot:GetAbilityByName("furion_teleportation")
				if prophetTeleport:IsTrained() and prophetTeleport:IsFullyCastable() then
					bot.useProphetTP = true
					bot.ProphetTPLocation = hEffectTarget
					return BOT_ACTION_DESIRE_NONE
				end
			end
			return BOT_ACTION_DESIRE_HIGH, tpLocation, castType, castReason
		end
	end
	if
		activeMode == BOT_MODE_FARM
		and bot:DistanceFromFountain() < 800
		and not Usage.IsBaseTowerDestroyed()
		and hpRatio > 0.9
		and mpRatio > 0.8
	then
		local farmLane, farmLaneDesire = Fu.GetMostFarmLaneDesire(bot)
		if farmLaneDesire > 0.1 then
			local farmTpLoc = GetLaneFrontLocation(team, farmLane, 0)
			local nearestTpSpot = Fu.GetNearbyLocationToTp(farmTpLoc)
			if
				nearestTpSpot ~= nil
				and farmTpLoc ~= nil
				and Fu.IsLocHaveTower(2000, false, farmTpLoc)
				and GetUnitToLocationDistance(bot, nearestTpSpot) > tpDistance
			then
				tpLocation = farmTpLoc
			end
		end
		if tpLocation ~= nil and Usage.JustTeleported() then
			tpLocation = nil
		end
		if tpLocation ~= nil then
			hEffectTarget = tpLocation
			castReason = "出去发育"
			if botName == "npc_dota_hero_furion" then
				local prophetTeleport = bot:GetAbilityByName("furion_teleportation")
				if prophetTeleport:IsTrained() and prophetTeleport:IsFullyCastable() then
					bot.useProphetTP = true
					bot.ProphetTPLocation = hEffectTarget
					return BOT_ACTION_DESIRE_NONE
				end
			end
			return BOT_ACTION_DESIRE_ABSOLUTE, hEffectTarget, castType, castReason
		end
	end
	if
		bot:GetLevel() >= 10
		and activeMode ~= BOT_MODE_ROSHAN
		and not Usage.IsBaseTowerDestroyed()
		and Fu.GetAllyCount(bot, 1600) <= 2
		and Fu.Role.ShouldTpToFarm()
		and not Fu.Role.IsAllyHaveAegis()
		and not Fu.Role.CanBeSupport(botName)
		and not Fu.IsEnemyHeroAroundLocation(GetAncient(team):GetLocation(), 3300)
		and Fu.Utils.CountEnemyHeroesOnHighGround(GetTeam()) < 1
	then
		local attackingAllies = Fu.GetNearbyHeroes(bot, 1600, false, BOT_MODE_ATTACK)
		local enemyHeroes = Fu.GetNearbyHeroes(bot, 1400, true, BOT_MODE_NONE)
		local enemyCreeps = bot:GetNearbyCreeps(1600, true)
		local farmLane, farmLaneDesire = Fu.GetMostFarmLaneDesire(bot)
		local hasTravelBoots = false
		if Fu.IsItemAvailable("item_travel_boots") or Fu.IsItemAvailable("item_travel_boots_2") then
			hasTravelBoots = true
		end
		if
			farmLaneDesire > (hasTravelBoots and 0.7 or 0.8)
			and #enemyHeroes == 0
			and #enemyCreeps == 0
			and #attackingAllies == 0
		then
			if hasTravelBoots then
				tpLocation = GetLaneFrontLocation(team, farmLane, -600)
				local alliesNearLane = Fu.GetAlliesNearLoc(tpLocation, 1600)
				if GetUnitToLocationDistance(bot, tpLocation) > tpDistance - 1500 and #alliesNearLane == 0 then
					Fu.Role["lastFarmTpTime"] = DotaTime()
					castReason = "飞鞋带线"
					if botName == "npc_dota_hero_furion" then
						local prophetTeleport = bot:GetAbilityByName("furion_teleportation")
						if prophetTeleport:IsTrained() and prophetTeleport:IsFullyCastable() then
							bot.useProphetTP = true
							bot.ProphetTPLocation = tpLocation
							return BOT_ACTION_DESIRE_NONE
						end
					end
					return BOT_ACTION_DESIRE_HIGH, tpLocation, castType, castReason
				end
			end
			tpLocation = GetLaneFrontLocation(team, farmLane, 0)
			local nearestTpSpot = Fu.GetNearbyLocationToTp(tpLocation)
			local alliesNearLane = Fu.GetAlliesNearLoc(tpLocation, 1600)
			if
				nearestTpSpot ~= nil
				and Fu.IsLocHaveTower(1850, false, tpLocation)
				and GetUnitToLocationDistance(bot, nearestTpSpot) > tpDistance - 800
				and #alliesNearLane == 0
			then
				Fu.Role["lastFarmTpTime"] = DotaTime()
				castReason = "线上打钱"
				if botName == "npc_dota_hero_furion" then
					local prophetTeleport = bot:GetAbilityByName("furion_teleportation")
					if prophetTeleport:IsTrained() and prophetTeleport:IsFullyCastable() then
						bot.useProphetTP = true
						bot.ProphetTPLocation = nearestTpSpot
						return BOT_ACTION_DESIRE_NONE
					end
				end
				return BOT_ACTION_DESIRE_HIGH, nearestTpSpot, castType, castReason
			end
		end
	end
	if
		bot:GetLevel() > 10
		and activeMode ~= BOT_MODE_SECRET_SHOP
		and activeMode ~= BOT_MODE_ROSHAN
		and activeMode ~= BOT_MODE_ATTACK
		and (botTarget == nil or not botTarget:IsHero())
	then
		local enemyHeroes = Fu.GetNearbyHeroes(bot, 1400, true, BOT_MODE_NONE)
		local teamFightLocation = Fu.GetTeamFightLocation(bot)
		local hasTravelBoots = false
		if Fu.IsItemAvailable("item_travel_boots") or Fu.IsItemAvailable("item_travel_boots_2") then
			hasTravelBoots = true
		end
		if botName == "npc_dota_hero_spectre" then
			local shadowStep = bot:GetAbilityByName("spectre_shadow_step")
			local haunt = bot:GetAbilityByName("spectre_haunt")
			if shadowStep:IsFullyCastable() or haunt:IsTrained() and haunt:IsFullyCastable() then
				return BOT_ACTION_DESIRE_NONE
			end
		end
		if
			#enemyHeroes == 0
			and teamFightLocation ~= nil
			and GetUnitToLocationDistance(bot, teamFightLocation) > tpDistance - 1200
		then
			if hasTravelBoots then
				castReason = "飞鞋支援团战距离:" .. GetUnitToLocationDistance(bot, teamFightLocation)
				if botName == "npc_dota_hero_furion" then
					local prophetTeleport = bot:GetAbilityByName("furion_teleportation")
					if prophetTeleport:IsTrained() and prophetTeleport:IsFullyCastable() then
						bot.useProphetTP = true
						bot.ProphetTPLocation = teamFightLocation
						return BOT_ACTION_DESIRE_NONE
					end
				end
				return BOT_ACTION_DESIRE_HIGH, teamFightLocation, castType, castReason
			end
			local nearestTpSpot = Fu.GetNearbyLocationToTp(teamFightLocation)
			if
				nearestTpSpot ~= nil
				and Fu.GetLocationToLocationDistance(nearestTpSpot, teamFightLocation) < 1800
				and GetUnitToLocationDistance(bot, nearestTpSpot) > tpDistance - 1200
			then
				castReason = "支援团战:" .. GetUnitToLocationDistance(bot, teamFightLocation)
				if botName == "npc_dota_hero_furion" then
					local prophetTeleport = bot:GetAbilityByName("furion_teleportation")
					if prophetTeleport:IsTrained() and prophetTeleport:IsFullyCastable() then
						bot.useProphetTP = true
						bot.ProphetTPLocation = nearestTpSpot
						return BOT_ACTION_DESIRE_NONE
					end
				end
				return BOT_ACTION_DESIRE_HIGH, nearestTpSpot, castType, castReason
			end
		end
		local ancient = GetAncient(team)
		if
			bot:GetLevel() >= 15
			and #enemyHeroes == 0
			and Fu.Role.ShouldTpToFarm()
			and bot:DistanceFromFountain() > 2000
			and GetUnitToUnitDistance(bot, ancient) > tpDistance - 200
			and Fu.GetAroundTargetAllyHeroCount(ancient, 1400) == 0
		then
			local laneFrontNearAncient = Fu.GetNearestLaneFrontLocation(ancient:GetLocation(), true, 400)
			if laneFrontNearAncient ~= nil and GetUnitToLocationDistance(ancient, laneFrontNearAncient) <= 1600 then
				Fu.Role["lastFarmTpTime"] = DotaTime()
				castReason = "守护遗迹"
				if botName == "npc_dota_hero_furion" then
					local prophetTeleport = bot:GetAbilityByName("furion_teleportation")
					if prophetTeleport:IsTrained() and prophetTeleport:IsFullyCastable() then
						bot.useProphetTP = true
						bot.ProphetTPLocation = ancient:GetLocation()
						return BOT_ACTION_DESIRE_NONE
					end
				end
				return BOT_ACTION_DESIRE_HIGH, ancient:GetLocation(), castType, castReason
			end
			local baseTower1 = GetTower(team, 9)
			local baseTower2 = GetTower(team, 10)
			if baseTower1 == nil and baseTower2 == nil then
				local enemyCreeps = GetUnitList(UNIT_LIST_ENEMY_CREEPS)
				for _, creep in pairs(enemyCreeps) do
					if
						Fu.IsValid(creep)
						and GetUnitToUnitDistance(ancient, creep) <= 800
						and (creep:GetAttackTarget() == ancient or bot:GetLevel() >= 15)
					then
						Fu.Role["lastFarmTpTime"] = DotaTime()
						castReason = "保护遗迹"
						if botName == "npc_dota_hero_furion" then
							local prophetTeleport = bot:GetAbilityByName("furion_teleportation")
							if prophetTeleport:IsTrained() and prophetTeleport:IsFullyCastable() then
								bot.useProphetTP = true
								bot.ProphetTPLocation = ancient:GetLocation()
								return BOT_ACTION_DESIRE_NONE
							end
						end
						return BOT_ACTION_DESIRE_HIGH, ancient:GetLocation(), castType, castReason
					end
				end
			end
		end
	end
	if
		(hpRatio + mpRatio < 0.3 or hpRatio < 0.2)
		and bot:GetLevel() >= 6
		and botName ~= "npc_dota_hero_huskar"
		and botName ~= "npc_dota_hero_slark"
		and not bot:HasModifier("modifier_arc_warden_tempest_double")
	then
		if
			Usage.CanJuke()
			and bot:DistanceFromFountain() > tpDistance + 200
			and nearbyEnemyCount <= 1
			and nearbyAllyCount <= 1
			and Fu.GetProperTarget(bot) == nil
			and flask == nil
			and bot:GetAttackTarget() == nil
			and not bot:HasModifier("modifier_flask_healing")
			and not bot:HasModifier("modifier_clarity_potion")
			and not bot:HasModifier("modifier_filler_heal")
			and not bot:HasModifier("modifier_item_urn_heal")
			and not bot:HasModifier("modifier_item_spirit_vessel_heal")
			and not bot:HasModifier("modifier_juggernaut_healing_ward_heal")
			and not bot:HasModifier("modifier_bottle_regeneration")
			and not bot:HasModifier("modifier_tango_heal")
		then
			tpLocation = Fu.GetTeamFountain()
		end
		if tpLocation ~= nil then
			hEffectTarget = tpLocation
			castReason = "回复状态"
			if botName == "npc_dota_hero_furion" then
				local prophetTeleport = bot:GetAbilityByName("furion_teleportation")
				if prophetTeleport:IsTrained() and prophetTeleport:IsFullyCastable() then
					bot.useProphetTP = true
					bot.ProphetTPLocation = hEffectTarget
					return BOT_ACTION_DESIRE_NONE
				end
			end
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
		end
	end
	if
		bot:HasModifier("modifier_bloodseeker_rupture")
		and nearbyEnemyCount <= 1
		and Fu.GetModifierTime(bot, "modifier_bloodseeker_rupture") >= 3.1
	then
		local nearbyAllyHeroes = Fu.GetNearbyHeroes(bot, 1000, false, BOT_MODE_NONE)
		if #nearbyAllyHeroes <= 1 and Usage.CanJuke() then
			tpLocation = Fu.GetTeamFountain()
		end
		if tpLocation ~= nil then
			hEffectTarget = tpLocation
			castReason = "躲血魔大"
			if botName == "npc_dota_hero_furion" then
				local prophetTeleport = bot:GetAbilityByName("furion_teleportation")
				if prophetTeleport:IsTrained() and prophetTeleport:IsFullyCastable() then
					bot.useProphetTP = true
					bot.ProphetTPLocation = hEffectTarget
					return BOT_ACTION_DESIRE_NONE
				end
			end
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
		end
	end
	if Usage.IsFarmingAlways(bot) then
		tpLocation = GetAncient(team):GetLocation()
		castReason = "处理特殊情况一"
		if botName == "npc_dota_hero_furion" then
			local prophetTeleport = bot:GetAbilityByName("furion_teleportation")
			if prophetTeleport:IsTrained() and prophetTeleport:IsFullyCastable() then
				bot.useProphetTP = true
				bot.ProphetTPLocation = tpLocation
				return BOT_ACTION_DESIRE_NONE
			end
		end
		return BOT_ACTION_DESIRE_HIGH, tpLocation, castType, castReason
	end
	if Fu.IsStuck(bot) then
		tpLocation = GetAncient(team):GetLocation()
		castReason = "处理特殊情况二"
		if botName == "npc_dota_hero_furion" then
			local prophetTeleport = bot:GetAbilityByName("furion_teleportation")
			if prophetTeleport:IsTrained() and prophetTeleport:IsFullyCastable() then
				bot.useProphetTP = true
				bot.ProphetTPLocation = tpLocation
				return BOT_ACTION_DESIRE_NONE
			end
		end
		return BOT_ACTION_DESIRE_HIGH, tpLocation, castType, castReason
	end
	if Fu.Role.ShouldTpToDefend() and bot:DistanceFromFountain() > 3800 then
		tpLocation = GetAncient(team):GetLocation()
		castReason = "立即TP守家"
		return BOT_ACTION_DESIRE_HIGH, tpLocation, castType, castReason
	end
	return BOT_ACTION_DESIRE_NONE
end
-- Teleports held back (game 037, 24:09-27:28, 15-2 at our bottom lane):
-- - base siege (3+ enemy heroes at a T3, barracks, T4 or the Ancient, kept 10s: defend.lua
--   GetBaseSiege): no TP to a spot more than 5000 from our Ancient (Hoodwink t=1572 TP'd out of the
--   fountain to farm the Dire top while five Dire were at our bottom T3);
-- - group-up (defend.lua): no TP anywhere but the group point;
-- - a lone TP into 3+ enemy heroes waits until 2 allies are there or teleporting there (Night
--   Stalker t=1449 "go to the teamfight", the moment Meepo died there).
-- TPs to the fountain (retreat) are never held.
local function TpHoldReason(target)
	local ok, targetX, targetY = pcall(function()
		return target.x, target.y
	end)
	if not ok or type(targetX) ~= "number" or type(targetY) ~= "number" then
		return nil
	end
	local now = DotaTime()
	if Fu.GetLocationToLocationDistance(target, Fu.GetTeamFountain()) <= 2500 then
		return nil
	end
	local ancient = GetAncient(team)
	local states = Fu.Utils.GameStates
	local siege = states ~= nil and states.baseSiege or nil
	if
		siege ~= nil
		and now - siege.at <= 10
		and ancient ~= nil
		and Fu.GetLocationToLocationDistance(target, ancient:GetLocation()) > 5000
	then
		return "base-siege", siege.n, -1
	end
	if (bot._defendGroupUpUntil or -1) > now and bot._defendGroupUpPoint ~= nil then
		if Fu.GetLocationToLocationDistance(target, bot._defendGroupUpPoint) > 2000 then
			return "group-up", -1, -1
		end
		return nil
	end
	local enemies = #Fu.GetLastSeenEnemiesNearLoc(target, 1800)
	if enemies >= 3 then
		local allies = 0
		for _, ally in ipairs(Fu.GetAlliesNearLoc(target, 1800)) do
			if ally ~= bot then
				allies = allies + 1
			end
		end
		for _, playerId in ipairs(Fu.Utils.GetAllyIdsInTpToLocation(target, 2500)) do
			if playerId ~= bot:GetPlayerID() then
				allies = allies + 1
			end
		end
		local ancientDying = ancient ~= nil
			and Fu.GetHP(ancient) < 0.4
			and Fu.GetLocationToLocationDistance(target, ancient:GetLocation()) <= 2500
		if allies < 2 and not ancientDying then
			return "lone-into-" .. enemies, enemies, allies
		end
	end
	return nil
end
do
	local tpRule = Usage.ConsiderItemDesire["item_tpscroll"]
	Usage.ConsiderItemDesire["item_tpscroll"] = function(item)
		local desire, target, castType, castReason = tpRule(item)
		if desire == nil or desire <= 0 or target == nil then
			return desire, target, castType, castReason
		end
		local why, enemies, allies = TpHoldReason(target)
		if why == nil then
			return desire, target, castType, castReason
		end
		if DotaTime() >= (bot._tpHoldLogAt or -999) then
			bot._tpHoldLogAt = DotaTime() + 5
			pcall(
				print,
				string.format(
					"[OHA-TP] t=%.0f %s tp-hold why=%s reason=%s mode=%s enemies=%d allies=%d to=%.0f,%.0f",
					DotaTime(),
					(string.gsub(botName, "npc_dota_hero_", "")),
					why,
					tostring(castReason),
					tostring(bot:GetActiveMode()),
					enemies,
					allies,
					target.x,
					target.y
				)
			)
		end
		return BOT_ACTION_DESIRE_NONE
	end
end
Usage.ConsiderItemDesire["item_urn_of_shadows"] = function(item)
	if item:GetCurrentCharges() == 0 then
		return BOT_ACTION_DESIRE_NONE
	end
	local castRange = 950 + castRangeBonus
	local castType = "unit"
	local hEffectTarget = nil
	local castReason = nil
	local enemyHeroes = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidHero(botTarget)
			and (
				Fu.CanCastOnNonMagicImmune(botTarget)
					and Fu.IsInRange(bot, botTarget, castRange)
					and not botTarget:HasModifier("modifier_item_urn_damage")
					and not botTarget:HasModifier("modifier_item_spirit_vessel_damage")
					and not botTarget:HasModifier("modifier_arc_warden_tempest_double")
					and (Fu.GetHP(botTarget) < 0.95 or Fu.IsInRange(bot, botTarget, 700))
				or botTarget:HasModifier("modifier_invoker_cold_snap_freeze")
			)
		then
			hEffectTarget = botTarget
			castReason = "进攻:" .. Fu.Chat.GetNormName(hEffectTarget)
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
		end
	end
	if bot:GetActiveMode() ~= BOT_MODE_ROSHAN then
		local allyHeroes = Fu.GetNearbyHeroes(bot, castRange + 80, false, BOT_MODE_NONE)
		local healTarget = nil
		local lowestHealth = 99999
		for _, ally in pairs(allyHeroes) do
			if
				Fu.IsValid(ally)
				and not ally:IsIllusion()
				and ally:DistanceFromFountain() > 800
				and Fu.CanCastOnNonMagicImmune(ally)
				and not ally:WasRecentlyDamagedByAnyHero(3.1)
				and not ally:HasModifier("modifier_item_spirit_vessel_heal")
				and not ally:HasModifier("modifier_item_urn_heal")
				and not ally:HasModifier("modifier_fountain_aura")
				and not ally:HasModifier("modifier_arc_warden_tempest_double")
				and ally:OriginalGetMaxHealth() - ally:OriginalGetHealth() > 450
				and #nearbyEnemies == 0
			then
				if ally:OriginalGetHealth() < lowestHealth then
					healTarget = ally
					lowestHealth = ally:OriginalGetHealth()
				end
			end
		end
		if healTarget ~= nil then
			hEffectTarget = healTarget
			castReason = "治疗:" .. Fu.Chat.GetNormName(hEffectTarget)
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
Usage.ConsiderItemDesire["item_veil_of_discord"] = function(item)
	-- Techies casts it himself when Blast Off lands; keep it while Blast Off is ready.
	if botName == "npc_dota_hero_techies" then
		local blast = bot:GetAbilityByName("techies_suicide")
		if blast ~= nil and blast:IsTrained() and blast:IsFullyCastable() then
			return BOT_ACTION_DESIRE_NONE
		end
	end
	local radius = 900
	local castType = "none"
	local hEffectTarget = nil
	local castReason = nil
	local enemyHeroes = Fu.GetNearbyHeroes(bot, radius + 50, true, BOT_MODE_NONE)
	local enemyCreeps = bot:GetNearbyCreeps(radius, true)
	if #enemyCreeps >= 6 or #enemyHeroes >= 1 then
		hEffectTarget = bot
		castReason = "启动希瓦"
		return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
	end
	return BOT_ACTION_DESIRE_NONE
end
local unusedSentryCounter = 0
Usage.ConsiderItemDesire["item_ward_sentry"] = function(item)
	do
		local desire, spot, kind, why = Usage.ConsiderSentryReveal(item, false)
		if desire ~= nil and desire > 0 then
			return desire, spot, kind, why
		end
	end
	local castRange = 500 + castRangeBonus
	local castType = "ground"
	local hEffectTarget = nil
	local castReason = nil
	local enemyHeroes = Fu.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE)
	local allyTowers = bot:GetNearbyTowers(1200, false)
	if Fu.IsGoingOnSomeone(bot) and #enemyHeroes >= 1 then
		local chosenEnemy = nil
		for _, enemy in pairs(enemyHeroes) do
			if
				Fu.IsValidHero(enemy)
				and Fu.IsInRange(bot, enemy, 900)
				and Fu.CanCastOnMagicImmune(enemy)
				and Fu.HasInvisibilityOrItem(enemy)
				and not enemy:HasModifier("modifier_slardar_amplify_damage")
				and not enemy:HasModifier("modifier_item_dustofappearance")
				and not Fu.Site.IsLocationHaveTrueSight(enemy:GetLocation())
				and SentrySpotUseless(Fu.GetUnitTowardDistanceLocation(bot, enemy, castRange)) == nil
			then
				hEffectTarget = Fu.GetUnitTowardDistanceLocation(bot, enemy, castRange)
				castReason = "插真眼针对:" .. Fu.Chat.GetNormName(enemy)
				return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
local ironwoodKillAssistCount = -1
Usage.ConsiderItemDesire["item_ironwood_tree"] = function(item)
	local castRange = 600
	local castType = "ground"
	local hEffectTarget = nil
	local castReason = nil
	if ironwoodKillAssistCount == -1 then
		ironwoodKillAssistCount = GetHeroKills(bot:GetPlayerID()) + GetHeroAssists(bot:GetPlayerID())
	end
	if ironwoodKillAssistCount < GetHeroKills(bot:GetPlayerID()) + GetHeroAssists(bot:GetPlayerID()) then
		ironwoodKillAssistCount = -1
		hEffectTarget = Fu.GetFaceTowardDistanceLocation(bot, castRange)
		castReason = "GG"
		return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
	end
	return BOT_ACTION_DESIRE_NONE
end
Usage.ConsiderItemDesire["item_essence_ring"] = function(item)
	if bot:DistanceFromFountain() < 1000 then
		return 0
	end
	local castRange = 600
	local castType = "none"
	local hEffectTarget = nil
	local castReason = nil
	local enemyHeroes = Fu.GetNearbyHeroes(bot, 1400, true, BOT_MODE_NONE)
	if bot:GetMaxHealth() - bot:GetHealth() > 600 and Fu.IsAllowedToSpam(bot, 200) then
		hEffectTarget = bot
		castReason = "治疗自己"
		return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
	end
	return Usage.ConsiderItemDesire["item_faerie_fire"](item)
end
Usage.ConsiderItemDesire["item_ash_legion_shield"] = function(item)
	local blockRadius = item:GetSpecialValueInt("block_radius")
	local allyUnits = GetUnitList(UNIT_LIST_ALLIES)
	local summonCount = 0
	local illusionCount = 0
	for _, allyUnit in pairs(allyUnits) do
		if Fu.IsValid(allyUnit) and Fu.IsInRange(bot, allyUnit, blockRadius) then
			local unitName = allyUnit:GetUnitName()
			if allyUnit:IsHero() and (allyUnit:IsIllusion() or string.find(unitName, "bear")) then
				illusionCount = illusionCount + 1
			end
			if string.find(unitName, "golem") then
				return BOT_ACTION_DESIRE_HIGH, bot, "none", nil
			end
			if
				-- Unit names are singular: npc_dota_broodmother_spiderling, npc_dota_invoker_forged_spirit,
				-- npc_dota_visage_familiar. The plural / "forge_spirit" spellings never matched.
				string.find(unitName, "broodmother_spider")
				or string.find(unitName, "forged_spirit")
				or string.find(unitName, "golem")
				or string.find(unitName, "boar")
				or string.find(unitName, "furion_treant")
				or string.find(unitName, "familiar")
				or allyUnit:IsDominated()
				or allyUnit:HasModifier("modifier_chen_holy_persuasion")
			then
				summonCount = summonCount + 1
			end
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if bot:WasRecentlyDamagedByAnyHero(2.0) and (summonCount >= 2 or illusionCount >= 2) then
			return BOT_ACTION_DESIRE_HIGH, bot, "none", nil
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
Usage.ConsiderItemDesire["item_flayers_bota"] = function(item)
	-- These three were undefined globals: the item was never used, and at Roshan the range check
	-- errored (game 034, 45:40 Death Prophet and 46:00 Dragon Knight, ItemUsageThink).
	local bAttacking = Fu.IsAttacking(bot)
	local botAttackRange = bot:GetAttackRange()
	local nEnemyHeroes = Fu.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE) or {}
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidHero(botTarget)
			and Fu.CanBeAttacked(botTarget)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and bAttacking
		then
			return BOT_ACTION_DESIRE_HIGH, nil, ITEM_TARGET_TYPE_NONE
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if
			Fu.IsRoshan(botTarget)
			and Fu.CanBeAttacked(botTarget)
			and Fu.IsInRange(bot, botTarget, botAttackRange + 150)
			and #nEnemyHeroes == 0
			and bAttacking
		then
			return BOT_ACTION_DESIRE_HIGH, nil, ITEM_TARGET_TYPE_NONE
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if
			Fu.IsTormentor(botTarget)
			and Fu.IsInRange(bot, botTarget, botAttackRange + 150)
			and #nEnemyHeroes == 0
			and bAttacking
		then
			return BOT_ACTION_DESIRE_HIGH, nil, ITEM_TARGET_TYPE_NONE
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
Usage.ConsiderItemDesire["item_idol_of_screeauk"] = function(item)
	if Fu.IsGoingOnSomeone(bot) then
		if bot:WasRecentlyDamagedByAnyHero(2.0) and Fu.IsRunning(bot) then
			return BOT_ACTION_DESIRE_HIGH, nil, ITEM_TARGET_TYPE_NONE
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
Usage.ConsiderItemDesire["item_jidi_pollen_bag"] = function(item)
	local debuffRadius = item:GetSpecialValueInt("debuff_radius")
	local nInRangeEnemy = Fu.GetEnemiesNearLoc(botLocation, debuffRadius)
	if Fu.IsInTeamFight(bot, 1200) then
		if #nInRangeEnemy >= 2 then
			local validEnemyCount = 0
			for _, enemy in pairs(nInRangeEnemy) do
				if
					Fu.IsValidHero(enemy)
					and Fu.CanBeAttacked(enemy)
					and Fu.CanCastOnNonMagicImmune(enemy)
					and not enemy:HasModifier("modifier_doom_bringer_doom_aura_enemy")
					and not enemy:HasModifier("modifier_necrolyte_reapers_scythe")
					and not enemy:HasModifier("modifier_ice_blast")
					and not enemy:HasModifier("modifier_item_spirit_vessel_damage")
				then
					validEnemyCount = validEnemyCount + 1
				end
			end
			if validEnemyCount >= 2 then
				return BOT_ACTION_DESIRE_HIGH, nil, ITEM_TARGET_TYPE_NONE
			end
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidHero(botTarget)
			and Fu.CanBeAttacked(botTarget)
			and Fu.IsInRange(bot, botTarget, debuffRadius)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and not botTarget:HasModifier("modifier_doom_bringer_doom_aura_enemy")
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
			and not botTarget:HasModifier("modifier_ice_blast")
			and not botTarget:HasModifier("modifier_item_spirit_vessel_damage")
		then
			return BOT_ACTION_DESIRE_HIGH, nil, ITEM_TARGET_TYPE_NONE
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
Usage.ConsiderItemDesire["item_metamorphic_mandible"] = function(item)
	local duration = item:GetSpecialValueInt("duration")
	if Fu.IsGoingOnSomeone(bot) then
		if bot:WasRecentlyDamagedByAnyHero(2.0) then
			local expectedDamage = 0
			-- nEnemyHeroes was never defined here ("bad argument to pairs", game 020, Pudge).
			for _, enemy in pairs(Fu.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE) or {}) do
				if
					Fu.IsValidHero(enemy)
					and not Fu.IsSuspiciousIllusion(enemy)
					and not enemy:HasModifier("modifier_necrolyte_reapers_scythe")
					and not enemy:IsChanneling()
				then
					if
						enemy:GetAttackTarget() == bot
						or Fu.IsChasingTarget(enemy, bot)
						or enemy:IsFacingLocation(bot:GetLocation(), 15)
						or bot:WasRecentlyDamagedByHero(enemy, 3.0)
					then
						expectedDamage = expectedDamage + enemy:GetAttackDamage() * enemy:GetAttackSpeed() * duration
					end
				end
			end
			if bot:GetActualIncomingDamage(expectedDamage * 1.5, DAMAGE_TYPE_PHYSICAL) < bot:GetHealth() then
				return BOT_ACTION_DESIRE_HIGH, bot, "none", nil
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
Usage.ConsiderItemDesire["item_riftshadow_prism"] = function(item)
	local healthCost = item:GetSpecialValueInt("health_cost")
	if Fu.IsGoingOnSomeone(bot) then
		if bot:WasRecentlyDamagedByAnyHero(2.0) and Fu.GetHealthAfter(bot:GetHealth() * healthCost) > 0.2 then
			return BOT_ACTION_DESIRE_HIGH, bot, "none", nil
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
Usage.ConsiderItemDesire["item_spider_legs"] = function(item)
	return Usage.ConsiderItemDesire["item_phase_boots"](item)
end
Usage.ConsiderItemDesire["item_flicker"] = function(item)
	if bot:DistanceFromFountain() < 600 or bot:IsRooted() then
		return BOT_ACTION_DESIRE_NONE
	end
	local castRange = 600
	local castType = "none"
	local hEffectTarget = nil
	local castReason = nil
	local enemyHeroes = Fu.GetNearbyHeroes(bot, 800, true, BOT_MODE_NONE)
	if Fu.IsGoingOnSomeone(bot) then
		if Fu.IsValidHero(botTarget) and (bot:IsSilenced() or bot:IsRooted()) then
			hEffectTarget = bot
			castReason = "驱散沉默或缠绕"
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
		end
	end
	if Fu.IsRetreating(bot) and bot:WasRecentlyDamagedByAnyHero(3.0) and #enemyHeroes >= 1 then
		hEffectTarget = bot
		castReason = "撤退"
		return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
	end
	return BOT_ACTION_DESIRE_NONE
end
Usage.ConsiderItemDesire["item_illusionsts_cape"] = function(item)
	local castRange = 800
	local castType = "none"
	local hEffectTarget = nil
	local castReason = nil
	if Fu.IsValid(botTarget) and Fu.IsInRange(bot, botTarget, castRange) then
		hEffectTarget = botTarget
		castReason = "辅助攻击"
		return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
	end
	return Usage.ConsiderItemDesire["item_manta"](item)
end
Usage.ConsiderItemDesire["item_woodland_striders"] = function(item)
	if bot:DistanceFromFountain() < 600 then
		return 0
	end
	local castRange = 800
	local castType = "none"
	local hEffectTarget = nil
	local castReason = nil
	if Fu.IsRetreating(bot) and bot:WasRecentlyDamagedByAnyHero(4.0) then
		hEffectTarget = bot
		castReason = "撤退"
		return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
	end
	return BOT_ACTION_DESIRE_NONE
end
Usage.ConsiderItemDesire["item_fallen_sky"] = function(item)
	local castRange = 1600
	local castType = "ground"
	local radius = 315
	local castDelay = 0.5
	local hEffectTarget = nil
	local castReason = nil
	local enemyHeroes = Fu.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE)
	if Fu.IsGoingOnSomeone(bot) then
		local aoeLocation = Fu.GetAoeEnemyHeroLocation(bot, castRange, radius, 2)
		if aoeLocation ~= nil then
			hEffectTarget = aoeLocation
			castReason = "Aoe"
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
		end
		if
			Fu.IsValidHero(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
		then
			local predictedLocation = Fu.GetDelayCastLocation(bot, botTarget, castRange, radius, castDelay)
			if predictedLocation ~= nil then
				hEffectTarget = predictedLocation
				castReason = "进攻"
				return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
			end
		end
	end
	if Fu.IsRetreating(bot) and bot:WasRecentlyDamagedByAnyHero(3.0) then
		local retreatLocation = Fu.GetLocationTowardDistanceLocation(bot, GetAncient(team):GetLocation(), 1600)
		local attackingAllies = Fu.GetNearbyHeroes(bot, 800, false, BOT_MODE_ATTACK)
		if
			bot:DistanceFromFountain() > 800
			and IsLocationPassable(retreatLocation)
			and (#attackingAllies == 0 or bot:GetActiveModeDesire() > BOT_MODE_DESIRE_VERYHIGH * 0.9)
			and #enemyHeroes >= 1
		then
			hEffectTarget = retreatLocation
			castReason = "撤退"
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
Usage.ConsiderItemDesire["item_ex_machina"] = function(item)
	local castRange = 800
	local castType = "none"
	local hEffectTarget = nil
	local castReason = nil
	local enemyHeroes = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	if Fu.IsGoingOnSomeone(bot) then
		if Fu.IsValidHero(botTarget) then
			local inventorySlots = { 0, 1, 2, 3, 4, 5 }
			local totalCooldown = 0
			for _, slot in pairs(inventorySlots) do
				local slotItem = bot:GetItemInSlot(slot)
				if slotItem ~= nil and slotItem:GetName() ~= "item_refresher" then
					local cooldownRemaining = slotItem:GetCooldownTimeRemaining()
					totalCooldown = totalCooldown + cooldownRemaining
				end
			end
			if totalCooldown >= 30 then
				hEffectTarget = botTarget
				castReason = "刷新CD"
				return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
Usage.ConsiderItemDesire["item_stormcrafter"] = function(item)
	local castRange = 300 + castRangeBonus
	local castType = "unit"
	local hEffectTarget = nil
	local castReason = nil
	local enemyHeroes = Fu.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE)
	if Fu.CanCastOnNonMagicImmune(bot) and #enemyHeroes > 0 then
		if bot:IsRooted() or Usage.SilenceBlocksASpell(bot) and not Usage.IsDoomed(bot) then
			hEffectTarget = bot
			castReason = "解缠绕:" .. Fu.Chat.GetNormName(hEffectTarget)
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
		end
		if Fu.IsUnitTargetProjectileIncoming(bot, 400) then
			hEffectTarget = bot
			castReason = "防御弹道:" .. Fu.Chat.GetNormName(hEffectTarget)
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
Usage.ConsiderItemDesire["item_gungir"] = function(item)
	local nInRangeEnemy = Fu.GetEnemiesNearLoc(bot:GetLocation(), 1000)
	for _, enemy in pairs(nInRangeEnemy) do
		if
			Fu.IsValidTarget(enemy)
			and Fu.IsUnitWillGoInvisible(enemy)
			and Fu.IsClosestToDustLocation(bot, enemy:GetLocation())
			and not Fu.HasInvisCounterBuff(enemy)
			and not Fu.IsSuspiciousIllusion(enemy)
		then
			if item:GetName() == "item_gungir" then
				hEffectTarget = enemy:GetLocation()
			end
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, "unit", "Stop invis"
		end
	end
	return Usage.ConsiderItemDesire["item_rod_of_atos"](item)
end
-- Meteor Hammer (Valve data: 2s channel, 600 range, 400 radius, 0.75s stun, burn hits buildings).
-- It had no rule, so it was bought and never cast. A tower or barracks while pushing with no
-- enemy hero near, or a disabled enemy hero in range (the stun lands after the 2s channel).
Usage.ConsiderItemDesire["item_meteor_hammer"] = function(item)
	local range = 600 + castRangeBonus
	if Fu.IsPushing(bot) and #(Fu.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE) or {}) == 0 then
		local buildings = {}
		for _, tower in pairs(bot:GetNearbyTowers(range, true) or {}) do
			buildings[#buildings + 1] = tower
		end
		for _, barracks in pairs(bot:GetNearbyBarracks(range, true) or {}) do
			buildings[#buildings + 1] = barracks
		end
		for _, building in ipairs(buildings) do
			if Fu.IsValidBuilding(building) and Fu.CanBeAttacked(building) then
				return BOT_ACTION_DESIRE_HIGH, building:GetLocation(), "ground", "meteor-building"
			end
		end
	end
	-- Not during OD's timed prison hammer (it lands as the prison ends), and never on an
	-- invulnerable target: game 021, 22:07, OD imprisoned an enemy and this rule cast the hammer
	-- at once on the "disabled" prisoner, which it cannot hit.
	if bot._prison ~= nil then
		return BOT_ACTION_DESIRE_NONE
	end
	for _, enemy in pairs(Fu.GetNearbyHeroes(bot, range, true, BOT_MODE_NONE) or {}) do
		if
			Fu.IsValidHero(enemy)
			and Fu.IsDisabled(enemy)
			and not enemy:IsInvulnerable()
			and Fu.CanCastOnNonMagicImmune(enemy)
			and not Fu.IsSuspiciousIllusion(enemy)
		then
			return BOT_ACTION_DESIRE_HIGH, enemy:GetLocation(), "ground", "meteor-disabled"
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
Usage.ConsiderItemDesire["item_pogo_stick"] = function(item)
	local castRange = 1000
	local castType = "none"
	local hEffectTarget = nil
	local castReason = nil
	local enemyHeroes = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidHero(botTarget)
			and Fu.IsInRange(bot, botTarget, bot:GetAttackRange() + 400)
			and Fu.CanCastOnMagicImmune(botTarget)
			and Fu.IsChasingTarget(bot, botTarget)
		then
			hEffectTarget = botTarget
			castReason = "进攻:" .. Fu.Chat.GetNormName(botTarget)
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
		end
	end
	if botMode == BOT_MODE_RETREAT and bot:GetActiveModeDesire() > BOT_MODE_DESIRE_HIGH then
		if
			bot:IsFacingLocation(GetAncient(team):GetLocation(), 20)
			and bot:DistanceFromFountain() > 600
			and #enemyHeroes >= 1
		then
			hEffectTarget = bot
			castReason = "撤退了推自己"
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
Usage.ConsiderItemDesire["item_paintball"] = function(item)
	local castRange = 900 + castRangeBonus
	local castType = "unit"
	local hEffectTarget = nil
	local castReason = nil
	local enemyHeroes = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	if
		Fu.IsValidHero(botTarget)
		and Fu.CanCastOnNonMagicImmune(botTarget)
		and Fu.CanCastOnTargetAdvanced(botTarget)
		and Fu.IsInRange(botTarget, bot, castRange)
	then
		hEffectTarget = botTarget
		castReason = "仙灵榴弹:" .. Fu.Chat.GetNormName(hEffectTarget)
		return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
	end
	return BOT_ACTION_DESIRE_NONE
end
Usage.ConsiderItemDesire["item_heavy_blade"] = function(item)
	local castRange = item:GetCastRange() + castRangeBonus
	local castType = "unit"
	local hEffectTarget = nil
	local castReason = nil
	local enemyHeroes = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	for i = 1, #GetTeamPlayers(GetTeam()) do
		local ally = GetTeamMember(i)
		if Fu.IsValidHero(ally) and Fu.IsInRange(bot, ally, castRange + 100) then
			if
				(Fu.IsGoingOnSomeone(ally) or Fu.IsRetreating(ally))
				and ally:WasRecentlyDamagedByAnyHero(2.0)
				and Fu.GetHP(ally) < 0.85
			then
				local enemiesNearAlly = Fu.GetNearbyHeroes(ally, 300, true, BOT_MODE_NONE)
				local enemyNearAlly = enemiesNearAlly[1]
				if Fu.IsValidHero(enemyNearAlly) and Fu.CanCastOnMagicImmune(enemyNearAlly) then
					hEffectTarget = ally
					castReason = "行巫之祸驱散友军:" .. Fu.Chat.GetNormName(ally)
					return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
				end
			end
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidHero(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and Fu.CanCastOnNonMagicImmune(botTarget)
		then
			if botTarget:WasRecentlyDamagedByAnyHero(3.0) and Fu.GetHP(botTarget) < 0.7 then
				hEffectTarget = botTarget
				castReason = "行巫之祸驱散敌军:" .. Fu.Chat.GetNormName(botTarget)
				return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
Usage.ConsiderItemDesire["item_revenants_brooch"] = function(item)
	local castRange = bot:GetAttackRange() + 100
	local castType = "none"
	local hEffectTarget = nil
	local castReason = nil
	local enemyHeroes = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	if Fu.IsGoingOnSomeone(bot) then
		if Fu.IsValidHero(botTarget) and Fu.IsInRange(bot, botTarget, castRange) then
			hEffectTarget = bot
			castReason = "亡魂胸针进攻:" .. Fu.Chat.GetNormName(botTarget)
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
Usage.ConsiderItemDesire["item_wraith_pact"] = function(item)
	local castRange = 200 + castRangeBonus
	local castType = "ground"
	local hEffectTarget = nil
	local castReason = nil
	local enemyHeroes = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidHero(botTarget)
			and botTarget:GetAttackTarget() ~= nil
			and Fu.IsInRange(bot, botTarget, 900)
			and Fu.CanCastOnNonMagicImmune(botTarget)
		then
			hEffectTarget = Fu.GetFaceTowardDistanceLocation(bot, 200)
			castReason = "怨灵之契进攻:" .. Fu.Chat.GetNormName(botTarget)
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
Usage.ConsiderItemDesire["item_boots_of_bearing"] = function(item)
	return Usage.ConsiderItemDesire["item_ancient_janggo"](item)
end
Usage.ConsiderItemDesire["item_new"] = function(item)
	local castRange = 300 + castRangeBonus
	local castType = "unit"
	local hEffectTarget = nil
	local castReason = nil
	local enemyHeroes = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	if Fu.IsGoingOnSomeone(bot) then
		if Fu.IsValidHero(botTarget) then
			hEffectTarget = botTarget
			castReason = "进攻:" .. Fu.Chat.GetNormName(botTarget)
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
Usage.ConsiderItemDesire["item_soul_ring"] = function(item)
	local castType = "none"
	local hEffectTarget = bot
	local castReason = nil
	local activeMode = bot:GetActiveMode()
	local mpRatio = bot:GetMana() / bot:GetMaxMana()
	local hpRatio = bot:OriginalGetHealth() / bot:OriginalGetMaxHealth()
	-- Techies uses it in his own script, only right before a Blast Off he cannot afford.
	if botName == "npc_dota_hero_techies" then
		return BOT_ACTION_DESIRE_NONE
	end
	if (activeMode == BOT_MODE_FARM or activeMode == BOT_MODE_LANING) and hpRatio > 0.5 and mpRatio < 0.5 then
		return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
	end
	return BOT_ACTION_DESIRE_NONE
end
Usage.ConsiderItemDesire["item_pavise"] = function(item)
	local castRange = 1000 + castRangeBonus
	local castType = "unit"
	local hEffectTarget = nil
	local castReason = nil
	local enemyHeroes = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	local allyHeroes = Fu.GetNearbyHeroes(bot, castRange, false, BOT_MODE_NONE)
	local hpRatio = bot:OriginalGetHealth() / bot:OriginalGetMaxHealth()
	for _, ally in pairs(allyHeroes) do
		if
			Fu.IsValidHero(ally)
			and ally ~= bot
			and not ally:IsMagicImmune()
			and not ally:IsInvulnerable()
			and not ally:IsIllusion()
			and not ally:HasModifier("modifier_item_pavise_shield")
			and not ally:HasModifier("modifier_antimage_spell_shield")
			and (
				Fu.IsUnitTargetProjectileIncoming(ally, 800)
				or Fu.IsWillBeCastUnitTargetSpell(ally, 1200)
				or hpRatio < 0.2
			)
		then
			hEffectTarget = ally
			castReason = "帮助队友"
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
		end
	end
	if Fu.IsValidHero(botTarget) and Fu.IsInRange(bot, botTarget, 2400) and not Fu.IsInRange(bot, botTarget, 800) then
		if #allyHeroes >= 2 then
			local closestAlly = nil
			local closestDistance = 9999
			for _, ally in pairs(allyHeroes) do
				if
					ally ~= bot
					and not ally:IsIllusion()
					and Fu.IsInRange(ally, botTarget, closestDistance)
					and not ally:HasModifier("modifier_item_pavise_shield")
					and not ally:HasModifier("modifier_antimage_spell_shield")
				then
					closestAlly = ally
					closestDistance = GetUnitToUnitDistance(botTarget, ally)
					if Fu.IsHumanPlayer(ally) then
						break
					end
				end
			end
			if closestAlly ~= nil then
				hEffectTarget = closestAlly
				castReason = "先给前排套上"
				return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
Usage.ConsiderItemDesire["item_harpoon"] = function(item)
	local castRange = 700 + castRangeBonus
	local castType = "unit"
	local hEffectTarget = nil
	local castReason = nil
	local attackRange = bot:GetAttackRange()
	local target = Fu.GetProperTarget(bot)
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidTarget(target)
			and Fu.IsInRange(bot, target, castRange + attackRange)
			and not Fu.IsInRange(bot, target, castRange / 2)
			and not Fu.IsSuspiciousIllusion(target)
		then
			hEffectTarget = target
			castReason = "Harpoon"
			if Fu.WeAreStronger(bot, castRange + attackRange) then
				return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
			else
				return BOT_ACTION_DESIRE_MODERATE, hEffectTarget, castType, castReason
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
Usage.ConsiderItemDesire["item_disperser"] = function(item)
	local castRange = 600 + castRangeBonus
	local castType = "unit"
	local hEffectTarget = nil
	local castReason = nil
	local attackRange = bot:GetAttackRange()
	local target = Fu.GetProperTarget(bot)
	local nAllyHeroes = Fu.GetNearbyHeroes(bot, castRange, false, BOT_MODE_NONE)
	local nEnemyHeroes = Fu.GetNearbyHeroes(bot, castRange + attackRange, true, BOT_MODE_NONE)
	if Fu.IsDisabled(bot) then
		if nEnemyHeroes ~= nil and #nEnemyHeroes >= 1 then
			hEffectTarget = bot
			castReason = "Disperser"
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
		end
	end
	for _, ally in pairs(nAllyHeroes) do
		if
			nEnemyHeroes ~= nil
			and #nEnemyHeroes >= 1
			and ally:WasRecentlyDamagedByAnyHero(2)
			and not Fu.IsSuspiciousIllusion(ally)
		then
			hEffectTarget = ally
			castReason = "Disperser"
			if Fu.IsDisabled(ally) then
				return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
			end
			if ally:GetActiveMode() == BOT_MODE_RETREAT and Fu.GetHP(ally) < 0.42 then
				return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
			end
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidTarget(target)
			and Fu.CanCastOnNonMagicImmune(target)
			and Fu.IsInRange(bot, target, castRange)
			and not Fu.IsSuspiciousIllusion(target)
			and not Fu.IsDisabled(target)
		then
			if
				target:GetCurrentMovementSpeed() > bot:GetCurrentMovementSpeed()
				and bot:IsFacingLocation(target:GetLocation(), 30)
				and not target:IsFacingLocation(bot:GetLocation(), 30)
			then
				hEffectTarget = RandomInt(1, 100) > 20 and target or bot
				castReason = "Disperser"
				if Fu.WeAreStronger(bot, castRange + attackRange) then
					return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
				else
					return BOT_ACTION_DESIRE_MODERATE, hEffectTarget, castType, castReason
				end
			end
		end
	end
	if Fu.IsInTeamFight(bot, castRange + attackRange) then
		local alliesNearBot = Fu.GetAlliesNearLoc(bot:GetLocation(), castRange)
		if alliesNearBot ~= nil and #alliesNearBot >= 1 and nEnemyHeroes ~= nil and #nEnemyHeroes >= 2 then
			hEffectTarget = bot
			castReason = "Disperser"
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
		end
	end
	if Fu.IsRetreating(bot) then
		if nEnemyHeroes ~= nil and #nEnemyHeroes >= 1 then
			if not Fu.WeAreStronger(bot, castRange + attackRange) or Fu.GetHP(bot) < 0.33 then
				hEffectTarget = RandomInt(1, 100) > 10 and bot or target
				castReason = "Disperser"
				return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
Usage.ConsiderItemDesire["item_blood_grenade"] = function(item)
	local castRange = 900
	local radius = 300
	local botHealth = bot:GetHealth()
	local healthCost = 75
	local impactDamage = 50
	local damagePerSecond = 15
	local dotDuration = 5
	local nEnemyHeroes = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	local totalDamage = impactDamage + damagePerSecond * dotDuration
	for _, enemy in pairs(nEnemyHeroes) do
		local canKill = Fu.CanKillTarget(enemy, totalDamage, DAMAGE_TYPE_MAGICAL)
		if Fu.IsInRange(bot, enemy, bot:GetAttackRange()) and bot:IsFacingLocation(enemy:GetLocation(), 15) then
			canKill = canKill or Fu.CanKillTarget(enemy, totalDamage + 150, DAMAGE_TYPE_MAGICAL)
		end
		if
			Fu.IsValidHero(enemy)
			and Fu.CanCastOnNonMagicImmune(enemy)
			and canKill
			and not Fu.IsSuspiciousIllusion(enemy)
			and botHealth > healthCost * 2
		then
			local nInRangeEnemy = Fu.GetEnemiesNearLoc(enemy:GetLocation(), radius)
			if nInRangeEnemy ~= nil and #nInRangeEnemy >= 1 then
				return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(nInRangeEnemy), "ground", "Blood Grenade"
			end
			return BOT_ACTION_DESIRE_HIGH, enemy:GetLocation(), "ground", "Blood Grenade"
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		for _, enemy in pairs(nEnemyHeroes) do
			if
				Fu.IsValidHero(enemy)
				and Fu.CanCastOnNonMagicImmune(enemy)
				and Fu.IsChasingTarget(bot, enemy)
				and not Fu.IsSuspiciousIllusion(enemy)
				and botHealth > healthCost * 2
			then
				local alliesNearTarget = Fu.GetNearbyHeroes(enemy, 1200, true, BOT_MODE_NONE)
				local nInRangeEnemy = Fu.GetNearbyHeroes(enemy, 1200, false, BOT_MODE_NONE)
				if
					alliesNearTarget ~= nil
					and nInRangeEnemy ~= nil
					and #alliesNearTarget >= #nInRangeEnemy
					and #alliesNearTarget >= 1
					and Fu.IsGoingOnSomeone(alliesNearTarget[1])
					and alliesNearTarget[1]:GetAttackTarget() == enemy
					and Fu.IsChasingTarget(alliesNearTarget[1], enemy)
					and not alliesNearTarget[1]:IsIllusion()
					and Fu.GetTotalEstimatedDamageToTarget(alliesNearTarget, enemy) >= enemy:GetHealth()
				then
					local enemiesNearTarget = Fu.GetEnemiesNearLoc(enemy:GetLocation(), radius)
					if enemiesNearTarget ~= nil and #enemiesNearTarget >= 1 then
						return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(enemiesNearTarget), "ground", "Blood Grenade"
					end
					return BOT_ACTION_DESIRE_HIGH, enemy:GetLocation(), "ground", "Blood Grenade"
				end
			end
		end
	end
	-- An early fight item. In any fight, or from 8:00 on anywhere, throw it at an enemy hero in
	-- range instead of waiting for a kill. It otherwise sat in a slot until the game pushed it
	-- into the backpack (bot swaps do not take effect) and it was never thrown.
	local fighting = Fu.IsGoingOnSomeone(bot) or Fu.IsInTeamFight(bot, 1200)
	if (fighting or DotaTime() >= 8 * 60) and botHealth > healthCost * 2 then
		local best, bestCount = nil, 0
		for _, enemy in pairs(nEnemyHeroes) do
			if Fu.IsValidHero(enemy) and Fu.CanCastOnNonMagicImmune(enemy) and not Fu.IsSuspiciousIllusion(enemy) then
				local group = Fu.GetEnemiesNearLoc(enemy:GetLocation(), radius) or {}
				if best == nil or #group > bestCount then
					best, bestCount = enemy, #group
				end
			end
		end
		if best ~= nil then
			local group = Fu.GetEnemiesNearLoc(best:GetLocation(), radius)
			local spot = (group ~= nil and #group >= 2) and Fu.GetCenterOfUnits(group) or best:GetLocation()
			pcall(
				print,
				string.format(
					"[OHA-ITEM] t=%.0f %s grenade-throw why=%s target=%s group=%d",
					DotaTime(),
					(string.gsub(botName, "npc_dota_hero_", "")),
					fighting and "fight" or "late",
					(string.gsub(best:GetUnitName(), "npc_dota_hero_", "")),
					bestCount
				)
			)
			return BOT_ACTION_DESIRE_HIGH, spot, "ground", "Blood Grenade"
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
local smokedRoshanKillTime = 0
-- [OHA-ITEM] smoke: every Smoke of Deceit use with its reason.
local function SmokeLog(why, allies)
	if DotaTime() < (bot._smokeLogAt or -999) then
		return
	end
	bot._smokeLogAt = DotaTime() + 3
	pcall(
		print,
		string.format(
			"[OHA-ITEM] t=%.0f %s smoke why=%s allies=%d",
			DotaTime(),
			(string.gsub(bot:GetUnitName(), "npc_dota_hero_", "")),
			why,
			allies or 0
		)
	)
end
-- The first enemy tower still standing in a lane, outer to inner.
local function SmokeNextEnemyTower(lane)
	local towerIds = lane == LANE_TOP and { TOWER_TOP_1, TOWER_TOP_2, TOWER_TOP_3 }
		or lane == LANE_MID and { TOWER_MID_1, TOWER_MID_2, TOWER_MID_3 }
		or { TOWER_BOT_1, TOWER_BOT_2, TOWER_BOT_3 }
	for _, towerId in ipairs(towerIds) do
		local tower = GetTower(GetOpposingTeam(), towerId)
		if tower ~= nil and tower:IsAlive() then
			return tower
		end
	end
	return nil
end
local function SmokeDesireRaw(item)
	local radius = 1200
	local castType = "none"
	local hEffectTarget = nil
	local castReason = "Smoke Of Deceit"
	local enemyNearby = false
	local allyHeroes = Fu.GetAllyList(bot, radius)
	local nInRangeEnemy = Fu.GetNearbyHeroes(bot, radius, true, BOT_MODE_NONE)
	local enemyTowers = bot:GetNearbyTowers(radius, true)
	-- Not before 10:00 (no build buys Smoke before the horn since 29becd3; pos 5 buys one from
	-- 12:00), and never in a lane fight or under our own tower: at 7:00 Techies popped one in
	-- team roam beside Medusa at our T1, in a creep wave.
	if DotaTime() < 10 * 60 then
		return BOT_ACTION_DESIRE_NONE
	end
	if #(bot:GetNearbyLaneCreeps(1000, true) or {}) >= 3 or #(bot:GetNearbyTowers(1000, false) or {}) >= 1 then
		return BOT_ACTION_DESIRE_NONE
	end
	-- Never smoke alone after horn.
	if allyHeroes == nil or #allyHeroes < 2 then
		MatchTrace.Decide(
			bot,
			"smoke_skip",
			"alone",
			string.format("allies=%d mode=%s", allyHeroes and #allyHeroes or 0, tostring(bot:GetActiveMode())),
			8
		)
		return BOT_ACTION_DESIRE_NONE
	end
	if (nInRangeEnemy ~= nil and #nInRangeEnemy == 0) or (enemyTowers ~= nil and #enemyTowers == 0) then
		for _, ally in pairs(allyHeroes) do
			if Fu.IsValidHero(ally) then
				local enemiesNearAlly = Fu.GetNearbyHeroes(ally, radius, true, BOT_MODE_NONE)
				local towersNearAlly = ally:GetNearbyTowers(radius, true)
				if
					(enemiesNearAlly ~= nil and #enemiesNearAlly >= 1)
					or (towersNearAlly ~= nil and #towersNearAlly >= 1)
				then
					enemyNearby = true
					break
				end
			end
		end
	end
	if not enemyNearby then
		local activeMode = bot:GetActiveMode()
		local timeOfDay = Fu.CheckTimeOfDay()
		hEffectTarget = bot
		-- Game 044, 15:08: Puck smoked a team roam right in front of Radiant's bottom T1 while flipping between team
		-- roam and pushing that tower (16 mode changes); walking on to the tower breaks the Smoke. Like push-group:
		-- not within 2500 of an enemy tower, and not while an ally near is in a push mode.
		local roamMode = activeMode == BOT_MODE_ROAM or activeMode == BOT_MODE_GANK or activeMode == BOT_MODE_TEAM_ROAM
		local roamSkip = nil
		if roamMode then
			for _, towerId in ipairs({
				TOWER_TOP_1,
				TOWER_TOP_2,
				TOWER_TOP_3,
				TOWER_MID_1,
				TOWER_MID_2,
				TOWER_MID_3,
				TOWER_BOT_1,
				TOWER_BOT_2,
				TOWER_BOT_3,
				TOWER_BASE_1,
				TOWER_BASE_2,
			}) do
				local tower = GetTower(GetOpposingTeam(), towerId)
				if tower ~= nil and tower:IsAlive() and GetUnitToUnitDistance(bot, tower) < 2500 then
					roamSkip = "tower-near"
					break
				end
			end
			if roamSkip == nil then
				for _, ally in pairs(allyHeroes) do
					local allyMode = Fu.IsValidHero(ally) and ally:GetActiveMode() or nil
					if
						allyMode == BOT_MODE_PUSH_TOWER_TOP
						or allyMode == BOT_MODE_PUSH_TOWER_MID
						or allyMode == BOT_MODE_PUSH_TOWER_BOT
					then
						roamSkip = "ally-pushing"
						break
					end
				end
			end
			if roamSkip ~= nil and DotaTime() >= (bot._smokeRoamSkipLogAt or -999) then
				bot._smokeRoamSkipLogAt = DotaTime() + 10
				pcall(
					print,
					string.format(
						"[OHA-ITEM] t=%.0f %s smoke-skip why=%s",
						DotaTime(),
						(string.gsub(bot:GetUnitName(), "npc_dota_hero_", "")),
						roamSkip
					)
				)
			end
		end
		if roamMode and roamSkip == nil then
			SmokeLog("team-roam", #allyHeroes)
			MatchTrace.Item(bot, "item_smoke_of_deceit", "team_roam", string.format("allies=%d", #allyHeroes))
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
		end
		-- A group walking to push a lane, still far from the tower (game 034, 16:30-17:15: four Dire
		-- heroes walked together from Radiant's mid tower to its top tower and killed Grimstroke
		-- and Riki on the way). Smoke hides the group until it reaches the wave.
		local pushLane = activeMode == BOT_MODE_PUSH_TOWER_TOP and LANE_TOP
			or activeMode == BOT_MODE_PUSH_TOWER_MID and LANE_MID
			or activeMode == BOT_MODE_PUSH_TOWER_BOT and LANE_BOT
			or nil
		-- Not with an enemy wave ahead (game 043, 13:49: Radiant smoked, hit the wave on the way and showed itself).
		local waveAhead = #(bot:GetNearbyLaneCreeps(1600, true) or {}) >= 1
		if pushLane ~= nil and #allyHeroes >= 3 and not waveAhead then
			local tower = SmokeNextEnemyTower(pushLane)
			local dist = tower ~= nil and GetUnitToUnitDistance(bot, tower) or 0
			if dist > 2500 then
				SmokeLog(string.format("push-group lane=%d tower-dist=%d", pushLane, math.floor(dist)), #allyHeroes)
				return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
			end
		end
		if
			timeOfDay == "day" and GetUnitToLocationDistance(bot, Fu.Utils.RadiantRoshanLoc) < 600
			or timeOfDay == "night" and GetUnitToLocationDistance(bot, Fu.Utils.DireRoshanLoc) < 600
		then
			if GetRoshanKillTime() > smokedRoshanKillTime then
				smokedRoshanKillTime = GetRoshanKillTime()
				SmokeLog("post-roshan", #allyHeroes)
				MatchTrace.Item(bot, "item_smoke_of_deceit", "post_roshan", string.format("allies=%d", #allyHeroes))
				return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
			end
		end
		if activeMode == BOT_MODE_ROSHAN then
			if timeOfDay == "day" and GetUnitToLocationDistance(bot, Fu.Utils.RadiantRoshanLoc) > 3000 then
				SmokeLog("to-roshan", #allyHeroes)
				MatchTrace.Item(bot, "item_smoke_of_deceit", "to_roshan", string.format("allies=%d", #allyHeroes))
				return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
			end
			if timeOfDay == "night" and GetUnitToLocationDistance(bot, Fu.Utils.DireRoshanLoc) > 3000 then
				SmokeLog("to-roshan", #allyHeroes)
				MatchTrace.Item(bot, "item_smoke_of_deceit", "to_roshan", string.format("allies=%d", #allyHeroes))
				return BOT_ACTION_DESIRE_HIGH, hEffectTarget, castType, castReason
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
-- Game 043, 13:49-13:56: Rubick smoked a mid push, the group hit a creep wave (Smoke broke), and Grimstroke smoked
-- again 7s later; Dire's Puck did the same (13:29 and 14:12). One Smoke per team per 60s, and none while this bot or
-- an ally within 1200 is still smoked. Log: [OHA-ITEM] smoke-skip why=recent|smoked.
local SMOKE_TEAM_GAP = 60
Usage.ConsiderItemDesire["item_smoke_of_deceit"] = function(item)
	local why = nil
	local lastSmoke = TeamMemory.Get(GetTeam(), "smokeAt")
	if lastSmoke ~= nil and DotaTime() - lastSmoke < SMOKE_TEAM_GAP then
		why = "recent"
	elseif bot:HasModifier("modifier_smoke_of_deceit") then
		why = "smoked"
	else
		for _, ally in pairs(Fu.GetAllyList(bot, 1200) or {}) do
			if Fu.IsValidHero(ally) and ally:HasModifier("modifier_smoke_of_deceit") then
				why = "smoked"
				break
			end
		end
	end
	if why ~= nil then
		if DotaTime() >= (bot._smokeSkipLogAt or -999) then
			bot._smokeSkipLogAt = DotaTime() + 10
			pcall(
				print,
				string.format(
					"[OHA-ITEM] t=%.0f %s smoke-skip why=%s since=%.0f",
					DotaTime(),
					(string.gsub(bot:GetUnitName(), "npc_dota_hero_", "")),
					why,
					lastSmoke ~= nil and DotaTime() - lastSmoke or -1
				)
			)
		end
		return BOT_ACTION_DESIRE_NONE
	end
	local desire, target, castType, reason = SmokeDesireRaw(item)
	if desire ~= nil and desire > 0 then
		TeamMemory.Set(GetTeam(), "smokeAt", DotaTime())
	end
	return desire, target, castType, reason
end
local enemyPlayerIds = nil
-- Dust only from a main slot (game 036: 308 "item can't be used from stash" refusals, bursts with the
-- Dust loop on Ogre Magi). The rule below is unchanged otherwise.
local DustDesire
Usage.ConsiderItemDesire["item_dust"] = function(item)
	local dustSlot = bot:FindItemSlot("item_dust")
	if dustSlot < 0 or dustSlot > 5 then
		return BOT_ACTION_DESIRE_NONE
	end
	return DustDesire(item)
end
DustDesire = function(item)
	local radius = 1050
	-- Game 031, 28:40: Dazzle used Glimmer Cape (datafeed: 0.5s fade, 5s invisible) and no Dust
	-- came; the rules below only catch the half-second fade, or 0.2-0.5s after he vanished within
	-- 600. An enemy hero seen fading is remembered for 4s; while he is out of sight within 900 of
	-- where he was last seen (Dust: 1050 around the caster), the closest Dust holder reveals.
	do
		local now = DotaTime()
		bot._invisSeen = bot._invisSeen or {}
		for _, enemy in pairs(Fu.GetEnemiesNearLoc(bot:GetLocation(), 1600) or {}) do
			if
				Fu.IsValidHero(enemy)
				and Fu.IsUnitWillGoInvisible(enemy)
				and not Fu.HasInvisCounterBuff(enemy)
				and not Fu.IsSuspiciousIllusion(enemy)
			then
				local playerId = enemy:GetPlayerID()
				if bot._invisSeen[playerId] == nil then
					bot._invisSeen[playerId] =
						{ t = now, loc = enemy:GetLocation(), name = enemy:GetUnitName(), logged = false }
				else
					bot._invisSeen[playerId].loc = enemy:GetLocation()
				end
			end
		end
		for playerId, fader in pairs(bot._invisSeen) do
			if now - fader.t > 4 or not IsHeroAlive(playerId) then
				-- Game 029: 15 fades seen, Grimstroke the closest holder 553-999 away, no Dust at all.
				-- Say which condition held it back the last time it was checked.
				if fader.wasClosest and fader.why ~= nil then
					pcall(
						print,
						string.format(
							"[OHA-DUST] t=%.0f %s no-dust on %s why=%s",
							now,
							(string.gsub(bot:GetUnitName(), "npc_dota_hero_", "")),
							(string.gsub(fader.name, "npc_dota_hero_", "")),
							fader.why
						)
					)
				end
				bot._invisSeen[playerId] = nil
			else
				local info = GetHeroLastSeenInfo(playerId)
				local lastSeen = info ~= nil and info[1] or nil
				local loc = lastSeen ~= nil and lastSeen.location or fader.loc
				local gone = lastSeen == nil or lastSeen.time_since_seen > 0.1
				local dist = GetUnitToLocationDistance(bot, loc)
				local closest = Fu.IsClosestToDustLocation(bot, loc)
				if closest then
					fader.wasClosest = true
				end
				if not gone then
					fader.why = "still-visible"
				elseif dist > 900 then
					fader.why = string.format("far(%.0f)", dist)
				elseif not closest then
					fader.why = "not-closest"
				elseif not IsLocationVisible(loc) then
					fader.why = "spot-in-fog"
				else
					fader.why = "cast-blocked"
				end
				if not fader.logged and bot:FindItemSlot("item_dust") >= 0 then
					fader.logged = true
					pcall(
						print,
						string.format(
							"[OHA-DUST] t=%.0f %s saw %s fade dist=%.0f slot=%d closest=%s",
							now,
							(string.gsub(bot:GetUnitName(), "npc_dota_hero_", "")),
							(string.gsub(fader.name, "npc_dota_hero_", "")),
							dist,
							bot:FindItemSlot("item_dust"),
							tostring(closest)
						)
					)
				end
				-- Only with his last spot still in our vision: a fader who walked into fog, blinked or
				-- teleported is not worth a Dust (user call).
				-- Game 036, t=895-898: the entry was cleared on the decision, so when the Dust did not go
				-- off the fader was found again next tick and both lines printed ~29 times a second. The
				-- entry now stays (it expires after 4s as before); one try per 2s, one log per entry.
				if gone and dist <= 900 and closest and IsLocationVisible(loc) and now >= (fader.dustAt or -99) + 2 then
					fader.dustAt = now
					fader.why = nil
					if not fader.dustLogged then
						fader.dustLogged = true
						pcall(
							print,
							string.format(
								"[OHA-DUST] t=%.0f %s dust on %s dist=%.0f",
								now,
								(string.gsub(bot:GetUnitName(), "npc_dota_hero_", "")),
								(string.gsub(fader.name, "npc_dota_hero_", "")),
								dist
							)
						)
					end
					return BOT_ACTION_DESIRE_HIGH, bot, "none", nil
				end
			end
		end
	end
	if enemyPlayerIds == nil then
		enemyPlayerIds = GetTeamPlayers(GetOpposingTeam())
	end
	local nearbyTrees = bot:GetNearbyTrees(500)
	if #nearbyTrees < 5 then
		for _, playerId in pairs(enemyPlayerIds) do
			local lastSeenInfo = GetHeroLastSeenInfo(playerId)
			if IsHeroAlive(playerId) and lastSeenInfo ~= nil then
				local lastSeen = lastSeenInfo[1]
				if
					lastSeen ~= nil
					and lastSeen.time_since_seen > 0.2
					and lastSeen.time_since_seen < 0.5
					and GetUnitToLocationDistance(bot, lastSeen.location) < radius - 450
					and Fu.IsClosestToDustLocation(bot, lastSeen.location)
				then
					local behindLoc = Fu.GetXUnitsTowardsLocation2(lastSeen.location, direFountain, 200)
					if team == TEAM_DIRE then
						behindLoc = Fu.GetXUnitsTowardsLocation2(lastSeen.location, radiantFountain, 200)
					end
					if IsLocationVisible(behindLoc) and IsLocationPassable(behindLoc) then
						return BOT_ACTION_DESIRE_HIGH, bot, "none", nil
					end
				end
			end
		end
	end
	if
		bot:HasModifier("modifier_sandking_sand_storm_slow")
		or bot:HasModifier("modifier_sandking_sand_storm_slow_aura_thinker")
	then
		return BOT_ACTION_DESIRE_HIGH, bot, "none", nil
	end
	local nInRangeEnemy = Fu.GetEnemiesNearLoc(bot:GetLocation(), radius)
	if nInRangeEnemy ~= nil and #nInRangeEnemy == 0 then
		if bot:HasModifier("modifier_item_radiance_debuff") then
			return BOT_ACTION_DESIRE_HIGH, bot, "none", nil
		end
		for _, playerId in pairs(enemyPlayerIds) do
			if IsHeroAlive(playerId) and bot:WasRecentlyDamagedByPlayer(playerId, 0.5) then
				local lastSeenInfo = GetHeroLastSeenInfo(playerId)
				if lastSeenInfo ~= nil then
					local lastSeen = lastSeenInfo[1]
					if lastSeen ~= nil and GetUnitToLocationDistance(bot, lastSeen.location) < radius then
						return BOT_ACTION_DESIRE_HIGH, bot, "none", nil
					end
				end
			end
		end
	else
		for _, enemy in pairs(nInRangeEnemy) do
			if
				Fu.IsValidTarget(enemy)
				and Fu.IsUnitWillGoInvisible(enemy)
				and Fu.IsClosestToDustLocation(bot, enemy:GetLocation())
				and not Fu.HasInvisCounterBuff(enemy)
				and not Fu.IsSuspiciousIllusion(enemy)
			then
				local towersNearEnemy = enemy:GetNearbyTowers(700, true)
				if towersNearEnemy == nil or #towersNearEnemy == 0 then
					return BOT_ACTION_DESIRE_HIGH, bot, "none", nil
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
-- Roshan's Banner (datafeed: placed within 1200, 120s, buffs our lane creeps in a 600/900/1200
-- radius by level; can be destroyed, melee heroes hit it twice as hard). Bots had no rule for it.
-- Bots carry it in the backpack: a.BannerFromBackpack swaps it into a main slot first.
-- Pushing (user call): planted behind our wave once the wave is at an enemy tower, barracks or
-- the ancient, so the creeps fighting the building get the buff. One banner per push.
-- Pushing, with an enemy tower, barracks or the ancient within 2500: a banner in the backpack goes
-- into a main slot (an empty one, else the cheapest), early enough for any backpack cooldown to run
-- out before the wave reaches the building. Once per 5s.
function Usage.BannerFromBackpack()
	-- Game 036: GetNearbyTowers/GetNearbyBarracks at 2500 ran every tick while pushing (the 5s gate was
	-- set only when a building was found) and the engine warned "querying nearby units with a distance
	-- greater than cached (2500)" 3185 times. Now at most once per 1s, and buildings are read from the
	-- enemy building list by distance, which has no radius cache.
	local now = DotaTime()
	if now < (bot._bannerCheckAt or -999) then
		return
	end
	bot._bannerCheckAt = now + 1
	local slot = bot:FindItemSlot("item_roshans_banner")
	if slot >= 0 and slot <= 5 then
		-- In a main slot: the last swap worked.
		bot._bannerSwapPending, bot._bannerSwapFails = false, 0
	end
	if slot < 6 or slot > 8 or not Fu.IsPushing(bot) or now < (bot._bannerSwapAt or -999) or bot._bannerSwapGaveUp then
		return
	end
	-- A swap was ordered and the banner is still in the backpack: count it. Game 036: 6 swaps, none took.
	if bot._bannerSwapPending then
		bot._bannerSwapPending = false
		bot._bannerSwapFails = (bot._bannerSwapFails or 0) + 1
		if bot._bannerSwapFails >= 3 then
			bot._bannerSwapGaveUp = true
			pcall(
				print,
				string.format(
					"[OHA-BANNER] t=%.0f %s swap-failed tries=%d slot=%d, giving up",
					now,
					(string.gsub(botName, "npc_dota_hero_", "")),
					bot._bannerSwapFails,
					slot
				)
			)
			return
		end
	end
	local nearestBuilding, nearestDist = nil, 2500
	for _, enemyBuilding in pairs(GetUnitList(UNIT_LIST_ENEMY_BUILDINGS) or {}) do
		if Fu.IsValidBuilding(enemyBuilding) then
			local unitName = enemyBuilding:GetUnitName() or ""
			if enemyBuilding:IsTower() or string.find(unitName, "rax", 1, true) ~= nil then
				local dist = GetUnitToUnitDistance(bot, enemyBuilding)
				if dist <= nearestDist then
					nearestBuilding, nearestDist = enemyBuilding, dist
				end
			end
		end
	end
	local enemyAncient = GetAncient(GetOpposingTeam())
	if nearestBuilding == nil and enemyAncient ~= nil and GetUnitToUnitDistance(bot, enemyAncient) <= 2500 then
		nearestBuilding = enemyAncient
	end
	if nearestBuilding == nil then
		return
	end
	local destSlot = require(GetScriptDirectory() .. "/FuncLib/systems/item").GetMainInvLessValItemSlot(bot)
	if destSlot == nil or destSlot < 0 then
		return
	end
	bot._bannerSwapAt = DotaTime() + 5
	local swappedOutItem = bot:GetItemInSlot(destSlot)
	-- Forced: the swap wrapper (global_overrides) refuses a swap with an enemy hero within 1000,
	-- and an enemy base always has one (game 029, 52:33-53:24: 9 tries, the banner never moved).
	bot._swapDespiteEnemies = true
	bot._swapDespiteCooldown = true
	pcall(
		print,
		string.format(
			"[OHA-BANNER] t=%.0f %s swap slot%d->%d out=%s building=%s dist=%.0f",
			DotaTime(),
			(string.gsub(botName, "npc_dota_hero_", "")),
			slot,
			destSlot,
			swappedOutItem ~= nil and swappedOutItem:GetName() or "-",
			(string.gsub(nearestBuilding:GetUnitName(), "npc_dota_", "")),
			GetUnitToUnitDistance(bot, nearestBuilding)
		)
	)
	bot._bannerSwapPending = true
	bot:ActionImmediate_SwapItems(slot, destSlot)
end
Usage.ConsiderItemDesire["item_roshans_banner"] = function(item)
	if not Fu.IsPushing(bot) or bot:WasRecentlyDamagedByAnyHero(1.5) and Fu.GetHP(bot) < 0.4 then
		return BOT_ACTION_DESIRE_NONE
	end
	local building = nil
	local bestDist = 99999
	local candidates = {}
	for _, tower in pairs(bot:GetNearbyTowers(1600, true) or {}) do
		table.insert(candidates, tower)
	end
	for _, barracks in pairs(bot:GetNearbyBarracks(1600, true) or {}) do
		table.insert(candidates, barracks)
	end
	local enemyAncient = GetAncient(GetOpposingTeam())
	if enemyAncient ~= nil and GetUnitToUnitDistance(bot, enemyAncient) <= 1600 then
		table.insert(candidates, enemyAncient)
	end
	for _, candidate in ipairs(candidates) do
		if Fu.IsValidBuilding(candidate) and not candidate:IsInvulnerable() then
			local dist = GetUnitToUnitDistance(bot, candidate)
			if dist < bestDist then
				building, bestDist = candidate, dist
			end
		end
	end
	if building == nil then
		return BOT_ACTION_DESIRE_NONE
	end
	-- Our creeps at the building (within 900 of it).
	local wave = {}
	for _, creep in pairs(bot:GetNearbyLaneCreeps(1600, false) or {}) do
		if Fu.IsValid(creep) and GetUnitToUnitDistance(creep, building) <= 900 then
			table.insert(wave, creep)
		end
	end
	-- 5+ creeps (user call: 3 is too few to be worth it).
	if #wave < 5 then
		return BOT_ACTION_DESIRE_NONE
	end
	-- Not on top of another of our banners.
	for _, allyUnit in pairs(GetUnitList(UNIT_LIST_ALLIES) or {}) do
		if
			allyUnit ~= nil
			and not allyUnit:IsNull()
			and allyUnit:IsAlive()
			and string.find(allyUnit:GetUnitName(), "roshans_banner")
			and GetUnitToUnitDistance(allyUnit, building) <= 1500
		then
			return BOT_ACTION_DESIRE_NONE
		end
	end
	-- Behind the wave, 250 toward our fountain from its center: the creeps stay in the radius,
	-- and the banner is not the first thing the building shoots.
	local loc = Fu.GetXUnitsTowardsLocation2(Fu.GetCenterOfUnits(wave), Fu.GetTeamFountain(), 250)
	if GetUnitToLocationDistance(bot, loc) > 1150 or not IsLocationPassable(loc) then
		return BOT_ACTION_DESIRE_NONE
	end
	pcall(
		print,
		string.format(
			"[OHA-BANNER] t=%.0f %s plant at=%.0f,%.0f building=%s dist=%.0f creeps=%d",
			DotaTime(),
			(string.gsub(botName, "npc_dota_hero_", "")),
			loc.x,
			loc.y,
			(string.gsub(building:GetUnitName(), "npc_dota_", "")),
			bestDist,
			#wave
		)
	)
	return BOT_ACTION_DESIRE_HIGH, loc, "ground", nil
end
Usage.ConsiderItemDesire["item_trusty_shovel"] = function(item)
	if GetTeamMember(1):IsBot() then
		return BOT_ACTION_DESIRE_NONE
	end
	local nInRangeEnemy = Fu.GetEnemiesNearLoc(bot:GetLocation(), 1000)
	if nInRangeEnemy ~= nil and #nInRangeEnemy == 0 then
		return BOT_ACTION_DESIRE_HIGH, bot:GetLocation(), "ground", nil
	end
	return BOT_ACTION_DESIRE_NONE
end
Usage.ConsiderItemDesire["item_arcane_ring"] = function(item)
	return Usage.ConsiderItemDesire["item_arcane_boots"](item)
end
Usage.ConsiderItemDesire["item_unstable_wand"] = function(item)
	local radius = 1600
	local nInRangeEnemy = Fu.GetNearbyHeroes(bot, radius, true, BOT_MODE_NONE)
	if
		nInRangeEnemy ~= nil
		and #nInRangeEnemy == 0
		and Fu.GetMP(bot) > 0.5
		and (Fu.IsRetreating(bot) or Fu.IsGoingOnSomeone(bot))
	then
		return BOT_ACTION_DESIRE_HIGH, bot, "none", nil
	end
	return BOT_ACTION_DESIRE_NONE
end
Usage.ConsiderItemDesire["item_seeds_of_serenity"] = function(item)
	local radius = 400
	local nInRangeEnemy = Fu.GetNearbyHeroes(bot, radius, true, BOT_MODE_NONE)
	local enemyTowers = bot:GetNearbyTowers(700, true)
	if Fu.IsFarming(bot) then
		if Fu.IsAttacking(bot) then
			local neutralCreeps = bot:GetNearbyNeutralCreeps(radius)
			if
				neutralCreeps ~= nil
				and (#neutralCreeps >= 3 or #neutralCreeps >= 2 and neutralCreeps[1]:IsAncientCreep())
			then
				return BOT_ACTION_DESIRE_HIGH, bot:GetLocation()
			end
			local laneCreeps = bot:GetNearbyLaneCreeps(radius, true)
			if laneCreeps ~= nil and #laneCreeps >= 3 then
				return BOT_ACTION_DESIRE_HIGH, bot:GetLocation()
			end
		end
	end
	if Fu.IsPushing(bot) then
		if
			enemyTowers ~= nil
			and #enemyTowers >= 1
			and Fu.IsValidBuilding(botTarget)
			and Fu.IsValidBuilding(enemyTowers[1])
			and Fu.IsAttacking(bot)
			and botTarget == enemyTowers[1]
		then
			return BOT_ACTION_DESIRE_HIGH, bot:GetLocation(), "ground", nil
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if Fu.IsRoshan(botTarget) and Fu.IsInRange(bot, botTarget, radius) and Fu.IsAttacking(bot) then
			return BOT_ACTION_DESIRE_HIGH, bot:GetLocation(), "ground", nil
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, radius) and Fu.IsAttacking(bot) then
			return BOT_ACTION_DESIRE_HIGH, bot:GetLocation(), "ground", nil
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
Usage.ConsiderItemDesire["item_dagger_of_ristul"] = function(item)
	local castType = "none"
	if Fu.GetHP(bot) < 0.4 then
		return BOT_ACTION_DESIRE_NONE
	end
	if Fu.IsGoingOnSomeone(bot) then
		if Fu.IsValidTarget(botTarget) and Fu.IsInRange(bot, botTarget, 800) and Fu.GetHP(bot) > 0.5 then
			return BOT_ACTION_DESIRE_HIGH, bot, castType, nil
		end
	end
	if Fu.IsFarming(bot) and Fu.IsAttacking(bot) and Fu.GetHP(bot) > 0.7 then
		local neutralCreeps = bot:GetNearbyNeutralCreeps(600)
		if neutralCreeps ~= nil and #neutralCreeps >= 2 then
			return BOT_ACTION_DESIRE_HIGH, bot, castType, nil
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
Usage.ConsiderItemDesire["item_stonefeather_satchel"] = function(item)
	local castType = "none"
	local nEnemyHeroes = Fu.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE)
	if
		#nEnemyHeroes >= 1
		and (Fu.IsRetreating(bot) or Fu.GetHP(bot) < 0.5)
		and not bot:HasModifier("modifier_item_stonefeather_satchel_rocks")
	then
		return BOT_ACTION_DESIRE_HIGH, bot, castType, nil
	end
	if #nEnemyHeroes == 0 and not bot:HasModifier("modifier_item_stonefeather_satchel_feathers") then
		return BOT_ACTION_DESIRE_MODERATE, bot, castType, nil
	end
	return BOT_ACTION_DESIRE_NONE
end
local royalJellyWaitStart = nil
Usage.ConsiderItemDesire["item_royal_jelly"] = function(item)
	if royalJellyWaitStart == nil then
		royalJellyWaitStart = DotaTime()
	else
		if royalJellyWaitStart < DotaTime() - 2.0 then
			local jellyTarget = nil
			for i = 1, #GetTeamPlayers(GetTeam()) do
				local teammate = GetTeamMember(i)
				if
					Fu.IsValidHero(teammate)
					and Fu.IsCore(teammate)
					and not teammate:IsIllusion()
					and not teammate:HasModifier("modifier_royal_jelly")
				then
					jellyTarget = teammate
				end
			end
			if jellyTarget ~= nil then
				royalJellyWaitStart = nil
				return BOT_ACTION_DESIRE_HIGH, jellyTarget, "unit", nil
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
Usage.ConsiderItemDesire["item_bullwhip"] = function(item)
	local castRange = 850 + castRangeBonus
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidHero(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsChasingTarget(bot, botTarget)
			and not Fu.IsDisabled(botTarget)
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget, "unit", nil
		end
	end
	local allyHeroes = Fu.GetAlliesNearLoc(bot:GetLocation(), castRange)
	for _, ally in pairs(allyHeroes) do
		if Fu.IsValidHero(ally) and Fu.CanCastOnNonMagicImmune(ally) then
			local enemiesNearAlly = Fu.GetNearbyHeroes(ally, 1200, true, BOT_MODE_NONE)
			if
				enemiesNearAlly ~= nil
				and #enemiesNearAlly >= 1
				and Fu.IsRetreating(ally)
				and ally:DistanceFromFountain() > 1200
				and not Fu.IsRealInvisible(ally)
				and not Fu.IsDisabled(ally)
			then
				return BOT_ACTION_DESIRE_HIGH, ally, "unit", nil
			end
		end
	end
	if item:IsFullyCastable() then
		return BOT_ACTION_DESIRE_HIGH, bot, "unit", nil
	end
	return BOT_ACTION_DESIRE_NONE
end
Usage.ConsiderItemDesire["item_light_collector"] = function(item)
	local radius = 325
	local nearbyTrees = bot:GetNearbyTrees(radius)
	if Fu.IsGoingOnSomeone(bot) then
		if nearbyTrees ~= nil and #nearbyTrees >= 3 then
			return BOT_ACTION_DESIRE_HIGH, bot, "none", nil
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
Usage.ConsiderItemDesire["item_iron_talon"] = function(item)
	local castRange = 350
	if Fu.IsFarming(bot) then
		local neutralCreeps = bot:GetNearbyNeutralCreeps(castRange)
		if #neutralCreeps <= 0 then
			return 0
		end
		local healthiestCreep = Fu.GetMostHpUnit(neutralCreeps)
		if Fu.CanBeAttacked(healthiestCreep) and Fu.GetHP(healthiestCreep) > 0.5 then
			return BOT_ACTION_DESIRE_HIGH, healthiestCreep, "unit", nil
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
Usage.ConsiderItemDesire["item_craggy_coat"] = function(item)
	local radius = 1200
	if Fu.IsInTeamFight(bot) then
		local enemiesNearby = Fu.GetEnemiesNearLoc(bot:GetLocation(), radius)
		if enemiesNearby ~= nil and #enemiesNearby >= 2 and bot:WasRecentlyDamagedByAnyHero(1.5) then
			return BOT_ACTION_DESIRE_HIGH, bot, "none", nil
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		local allyHeroes = Fu.GetNearbyHeroes(bot, 1200, false, BOT_MODE_NONE)
		if
			Fu.IsValidTarget(botTarget)
			and Fu.IsAttacking(botTarget)
			and bot:WasRecentlyDamagedByAnyHero(1.3)
			and Fu.IsInRange(bot, botTarget, 600)
			and not Fu.IsSuspiciousIllusion(botTarget)
		then
			local targetAllies = Fu.GetNearbyHeroes(botTarget, 1200, false, BOT_MODE_NONE)
			if allyHeroes ~= nil and targetAllies ~= nil and #allyHeroes >= #targetAllies then
				return BOT_ACTION_DESIRE_HIGH, bot, "none", nil
			end
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if Fu.IsRoshan(botTarget) and Fu.IsInRange(bot, botTarget, 500) and Fu.IsAttacking(bot) then
			return BOT_ACTION_DESIRE_HIGH, bot, "none", nil
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, 500) and Fu.IsAttacking(bot) then
			return BOT_ACTION_DESIRE_HIGH, bot, "none", nil
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
Usage.ConsiderItemDesire["item_psychic_headband"] = function(item)
	local castRange = 600 + castRangeBonus
	local nInRangeEnemy = Fu.GetEnemiesNearLoc(bot:GetLocation(), castRange)
	if Fu.IsRetreating(bot) then
		if
			Fu.IsValidHero(nInRangeEnemy[1])
			and Fu.CanCastOnNonMagicImmune(nInRangeEnemy[1])
			and Fu.IsRunning(nInRangeEnemy[1])
			and nInRangeEnemy[1]:IsFacingLocation(bot:GetLocation(), 30)
			and not Fu.IsSuspiciousIllusion(nInRangeEnemy[1])
			and not Fu.IsDisabled(nInRangeEnemy[1])
		then
			return BOT_ACTION_DESIRE_HIGH, nInRangeEnemy[1], "unit", nil
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
Usage.ConsiderItemDesire["item_ogre_seal_totem"] = function(item)
	local baseRange = 275
	local nInRangeEnemy = Fu.GetEnemiesNearLoc(bot:GetLocation(), baseRange * 2)
	if Fu.IsGoingOnSomeone(bot) then
		local allyHeroes = Fu.GetNearbyHeroes(bot, 1000, false, BOT_MODE_NONE)
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and bot:IsFacingLocation(botTarget:GetLocation(), 5)
			and Fu.IsInRange(bot, botTarget, baseRange * 2)
			and not Fu.IsInRange(bot, botTarget, baseRange - 75)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not bot:HasModifier("modifier_abaddon_borrowed_time")
			and not bot:HasModifier("modifier_necrolyte_reapers_scythe")
			and not Fu.IsLocationInChrono(botTarget:GetLocation())
			and not Fu.IsLocationInBlackHole(botTarget:GetLocation())
		then
			local targetAllies = Fu.GetNearbyHeroes(botTarget, 1000, false, BOT_MODE_NONE)
			if allyHeroes ~= nil and targetAllies ~= nil and #allyHeroes >= #targetAllies then
				return BOT_ACTION_DESIRE_HIGH, bot, "unit", nil
			end
		end
	end
	if Fu.IsRetreating(bot) then
		if
			Fu.IsValidHero(nInRangeEnemy[1])
			and Fu.IsRunning(nInRangeEnemy[1])
			and bot:IsFacingLocation(Fu.GetEscapeLoc(), 15)
			and nInRangeEnemy[1]:IsFacingLocation(bot:GetLocation(), 30)
		then
			return BOT_ACTION_DESIRE_HIGH, bot, "none", nil
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
local doubloonNextSwap = "health"
Usage.ConsiderItemDesire["item_doubloon"] = function(item)
	local nInRangeEnemy = Fu.GetEnemiesNearLoc(bot:GetLocation(), 1000)
	if Fu.IsGoingOnSomeone(bot) then
		local allyHeroes = Fu.GetNearbyHeroes(bot, 1000, false, BOT_MODE_NONE)
		if
			Fu.IsValidTarget(botTarget)
			and Fu.IsInRange(bot, botTarget, 1000)
			and Fu.GetHP(bot) > 0.8
			and Fu.GetMP(bot) < 0.5
			and doubloonNextSwap == "mana"
			and not Fu.IsSuspiciousIllusion(botTarget)
		then
			doubloonNextSwap = "health"
			return BOT_ACTION_DESIRE_HIGH, bot, "none", nil
		end
	end
	if Fu.IsRetreating(bot) then
		if
			Fu.IsValidHero(nInRangeEnemy[1])
			and Fu.IsRunning(nInRangeEnemy[1])
			and nInRangeEnemy[1]:IsFacingLocation(bot:GetLocation(), 30)
			and bot:WasRecentlyDamagedByAnyHero(1.5)
			and Fu.GetHP(bot) < 0.5
			and Fu.GetMP(bot) > 0.75
			and doubloonNextSwap == "health"
		then
			doubloonNextSwap = "mana"
			return BOT_ACTION_DESIRE_HIGH, bot, "none", nil
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
Usage.ConsiderItemDesire["item_ninja_gear"] = function(item)
	local castRange = 1600
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, 2800)
			and not Fu.IsInRange(bot, botTarget, botTarget:GetCurrentVisionRange() + 200)
			and not Fu.IsSuspiciousIllusion(botTarget)
		then
			local enemyLaneCreeps = bot:GetNearbyLaneCreeps(800, true)
			local enemyTowers = bot:GetNearbyTowers(700, true)
			if enemyLaneCreeps ~= nil and #enemyLaneCreeps == 0 and enemyTowers ~= nil and #enemyTowers == 0 then
				return BOT_ACTION_DESIRE_HIGH, bot, "none", nil
			end
		end
	end
	if Fu.IsDefending(bot) then
		local activeMode = bot:GetActiveMode()
		local lane = LANE_MID
		if activeMode == BOT_MODE_PUSH_TOWER_TOP then
			lane = LANE_TOP
		end
		if activeMode == BOT_MODE_PUSH_TOWER_BOT then
			lane = LANE_BOT
		end
		local laneFront = GetLaneFrontLocation(team, lane, 0)
		if GetUnitToLocationDistance(bot, laneFront) > 3200 then
			return BOT_ACTION_DESIRE_HIGH, bot, "none", nil
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if Fu.CheckTimeOfDay() == "day" and GetUnitToLocationDistance(bot, Fu.Utils.RadiantRoshanLoc) > 3200 then
			return BOT_ACTION_DESIRE_HIGH, bot, "none", nil
		end
		if Fu.CheckTimeOfDay() == "night" and GetUnitToLocationDistance(bot, Fu.Utils.DireRoshanLoc) > 3200 then
			return BOT_ACTION_DESIRE_HIGH, bot, "none", nil
		end
	end
	if Fu.IsDoingTormentor(bot) and GetUnitToLocationDistance(bot, Fu.GetTormentorLocation(GetTeam())) > 3200 then
		return BOT_ACTION_DESIRE_HIGH, bot, "none", nil
	end
	return BOT_ACTION_DESIRE_NONE
end
Usage.ConsiderItemDesire["item_trickster_cloak"] = function(item)
	return Usage.ConsiderItemDesire["item_invis_sword"](item)
end
Usage.ConsiderItemDesire["item_havoc_hammer"] = function(item)
	local radius = 400
	local damage = 175 + bot:GetAttributeValue(ATTRIBUTE_STRENGTH) * 1.5
	local nEnemyHeroes = Fu.GetNearbyHeroes(bot, radius, true, BOT_MODE_NONE)
	for _, enemy in pairs(nEnemyHeroes) do
		if
			Fu.IsValidHero(enemy)
			and Fu.CanCastOnNonMagicImmune(enemy)
			and Fu.CanKillTarget(enemy, damage, DAMAGE_TYPE_MAGICAL)
			and not Fu.IsSuspiciousIllusion(enemy)
			and not enemy:HasModifier("modifier_abaddon_borrowed_time")
			and not enemy:HasModifier("modifier_dazzle_shallow_grave")
			and not enemy:HasModifier("modifier_oracle_false_promise_timer")
			and not enemy:HasModifier("modifier_templar_assassin_refraction_absorb")
		then
			return BOT_ACTION_DESIRE_HIGH, bot, "none", nil
		end
	end
	if Fu.IsInTeamFight(bot, 1200) then
		local nInRangeEnemy = Fu.GetEnemiesNearLoc(bot:GetLocation(), 1000)
		if nInRangeEnemy ~= nil and #nInRangeEnemy >= 2 then
			local enemiesInRadius = Fu.GetEnemiesNearLoc(bot:GetLocation(), radius)
			if
				enemiesInRadius ~= nil
				and #enemiesInRadius >= 2
				and not Fu.IsLocationInChrono(nInRangeEnemy[1]:GetLocation())
				and not Fu.IsLocationInBlackHole(nInRangeEnemy[1]:GetLocation())
			then
				return BOT_ACTION_DESIRE_HIGH, bot, "none", nil
			end
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		local allyHeroes = Fu.GetNearbyHeroes(bot, 1000, false, BOT_MODE_NONE)
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, radius)
			and Fu.IsRunning(botTarget)
			and bot:IsFacingLocation(botTarget:GetLocation(), 30)
			and not botTarget:IsFacingLocation(bot:GetLocation(), 90)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not Fu.IsDisabled(botTarget)
		then
			return BOT_ACTION_DESIRE_HIGH, bot, "none", nil
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if Fu.IsRoshan(botTarget) and Fu.IsInRange(bot, botTarget, radius) and Fu.IsAttacking(bot) then
			return BOT_ACTION_DESIRE_HIGH, bot, "none", nil
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, radius) and Fu.IsAttacking(bot) then
			return BOT_ACTION_DESIRE_HIGH, bot, "none", nil
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
Usage.ConsiderItemDesire["item_martyrs_plate"] = function(item)
	local radius = 900
	if Fu.IsInTeamFight(bot) then
		local allyHeroes = Fu.GetAlliesNearLoc(bot:GetLocation(), radius)
		local nInRangeEnemy = Fu.GetEnemiesNearLoc(bot:GetLocation(), radius)
		if nInRangeEnemy ~= nil and #nInRangeEnemy >= 2 then
			if
				Fu.IsValidHero(nInRangeEnemy[1])
				and Fu.IsValidHero(nInRangeEnemy[2])
				and Fu.IsAttacking(nInRangeEnemy[1])
				and Fu.IsAttacking(nInRangeEnemy[2])
				and Fu.GetHP(bot) > 0.88
				and bot:GetHealth() >= 3800
				and not bot:WasRecentlyDamagedByAnyHero(0.8)
			then
				return BOT_ACTION_DESIRE_HIGH, bot, "none", nil
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
Usage.ConsiderItemDesire["item_force_boots"] = function(item)
	local castRange = 700 + castRangeBonus
	local nInRangeEnemy = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	if Fu.IsStuck(bot) then
		return BOT_ACTION_DESIRE_HIGH, bot, "unit", nil
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidTarget(botTarget)
			and Fu.IsInRange(bot, botTarget, 900)
			and Usage.IsWithoutSpellShield(botTarget)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not Fu.IsLocationInChrono(botTarget:GetLocation())
			and not Fu.IsLocationInBlackHole(botTarget:GetLocation())
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			local allyHeroes = Fu.GetNearbyHeroes(bot, 1200, false, BOT_MODE_NONE)
			local targetAllies = Fu.GetNearbyHeroes(botTarget, 1200, false, BOT_MODE_NONE)
			if allyHeroes ~= nil and targetAllies ~= nil and #allyHeroes >= #targetAllies then
				if bot:IsFacingLocation(botTarget:GetLocation(), 15) and #allyHeroes >= #targetAllies + 1 then
					return BOT_ACTION_DESIRE_HIGH, bot, "unit", nil
				end
				local allyCenter = Fu.GetCenterOfUnits(allyHeroes)
				if botTarget:IsFacingLocation(allyCenter, 15) and GetUnitToLocationDistance(bot, allyCenter) >= 750 then
					return BOT_ACTION_DESIRE_HIGH, botTarget, "unit", nil
				end
			end
		end
	end
	if Fu.IsRetreating(bot) then
		if
			nInRangeEnemy ~= nil
			and #nInRangeEnemy >= 1
			and bot:IsFacingLocation(Fu.GetEscapeLoc(), 30)
			and bot:DistanceFromFountain() > 600
			and not Fu.IsRealInvisible(bot)
		then
			return BOT_ACTION_DESIRE_HIGH, bot, "unit", nil
		end
	end
	local allyHeroes = Fu.GetAlliesNearLoc(bot:GetLocation(), castRange)
	for _, ally in pairs(allyHeroes) do
		if Fu.IsValidHero(ally) and Fu.CanCastOnNonMagicImmune(ally) then
			local enemiesNearAlly = Fu.GetNearbyHeroes(ally, 1200, true, BOT_MODE_NONE)
			if
				enemiesNearAlly ~= nil
				and #enemiesNearAlly >= 1
				and Fu.IsRetreating(ally)
				and ally:IsFacingLocation(Fu.GetEscapeLoc(), 30)
				and ally:DistanceFromFountain() > 600
				and ally:WasRecentlyDamagedByAnyHero(2.2)
				and not Fu.IsRealInvisible(ally)
			then
				return BOT_ACTION_DESIRE_HIGH, ally, "unit", nil
			end
			if Fu.IsGoingOnSomeone(ally) then
				local allyTarget = Fu.GetProperTarget(ally)
				if
					Fu.IsValidHero(allyTarget)
					and Fu.CanCastOnNonMagicImmune(allyTarget)
					and ally:IsFacingLocation(allyTarget:GetLocation(), 15)
					and GetUnitToUnitDistance(ally, allyTarget) > ally:GetAttackRange() + 50
					and GetUnitToUnitDistance(ally, allyTarget) < ally:GetAttackRange() + 700
					and Fu.IsRunning(allyTarget)
					and Fu.GetEnemyCount(ally, 1600) <= 3
					and not allyTarget:IsFacingLocation(ally:GetLocation(), 40)
					and not Fu.IsSuspiciousIllusion(allyTarget)
				then
					return BOT_ACTION_DESIRE_HIGH, ally, "unit", nil
				end
			end
			if Fu.IsStuck(ally) then
				return BOT_ACTION_DESIRE_HIGH, ally, "unit", nil
			end
		end
	end
	if bot:DistanceFromFountain() < 2800 then
		for _, enemy in pairs(nInRangeEnemy) do
			if
				Fu.IsValidHero(enemy)
				and Fu.CanCastOnMagicImmune(enemy)
				and enemy:IsFacingLocation(GetAncient(team):GetLocation(), 30)
				and GetUnitToLocationDistance(enemy, GetAncient(team):GetLocation()) < 1600
				and not Fu.IsSuspiciousIllusion(enemy)
			then
				local allyHeroes = Fu.GetNearbyHeroes(bot, 1000, false, BOT_MODE_NONE)
				local enemyAllies = Fu.GetNearbyHeroes(enemy, 1000, false, BOT_MODE_NONE)
				if allyHeroes ~= nil and enemyAllies ~= nil and #allyHeroes >= #enemyAllies then
					return BOT_ACTION_DESIRE_HIGH, enemy, "unit", nil
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
Usage.ConsiderItemDesire["item_seer_stone"] = function(item)
	local radius = 800
	if Fu.IsGoingOnSomeone(bot) then
		local aoe = bot:FindAoELocation(true, true, bot:GetLocation(), 1600, radius, 0, 0)
		local nInRangeEnemy = Fu.GetEnemiesNearLoc(aoe.targetloc, radius)
		local revealTarget = nil
		for _, enemy in pairs(nInRangeEnemy) do
			if
				Fu.IsValidHero(enemy)
				and Fu.IsInRange(bot, enemy, radius)
				and Fu.CanCastOnMagicImmune(enemy)
				and Fu.HasInvisibilityOrItem(enemy)
				and not enemy:HasModifier("modifier_slardar_amplify_damage")
				and not enemy:HasModifier("modifier_item_dustofappearance")
				and not Fu.Site.IsLocationHaveTrueSight(enemy:GetLocation())
			then
				return BOT_ACTION_DESIRE_HIGH, aoe.targetloc, "ground", nil
			end
		end
	end
	local allyHeroCount = 0
	for _, ally in pairs(GetUnitList(UNIT_LIST_ALLIED_HEROES)) do
		if Fu.IsValidHero(ally) and not Fu.IsSuspiciousIllusion(ally) then
			allyHeroCount = allyHeroCount + 1
		end
	end
	if Fu.IsRoshanAlive() and allyHeroCount == 0 then
		if Fu.CheckTimeOfDay() == "day" and GetUnitToLocationDistance(bot, Fu.Utils.RadiantRoshanLoc) > 1600 then
			return BOT_ACTION_DESIRE_HIGH, Fu.Utils.RadiantRoshanLoc, "ground", nil
		end
		if Fu.CheckTimeOfDay() == "night" and GetUnitToLocationDistance(bot, Fu.Utils.DireRoshanLoc) > 1600 then
			return BOT_ACTION_DESIRE_HIGH, Fu.Utils.DireRoshanLoc, "ground", nil
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
Usage.ConsiderItemDesire["item_demonicon"] = function(item)
	local castRange = 750
	local enemyHeroes = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	if Fu.IsPushing(bot) then
		local enemyTowers = bot:GetNearbyTowers(900, true)
		local allyLaneCreeps = bot:GetNearbyLaneCreeps(900, false)
		if enemyTowers ~= nil and #enemyTowers >= 1 and allyLaneCreeps ~= nil and #allyLaneCreeps >= 3 then
			return BOT_ACTION_DESIRE_HIGH, bot, "none", nil
		end
	end
	if
		Fu.IsValidTarget(botTarget)
		and Fu.IsInRange(bot, botTarget, 1000)
		and not botTarget:HasModifier("modifier_abaddon_borrowed_time")
	then
		local targetAllies = Fu.GetNearbyHeroes(botTarget, 1000, false, BOT_MODE_NONE)
		if targetAllies ~= nil then
			if #targetAllies == 0 then
				return BOT_ACTION_DESIRE_HIGH, bot, "none", nil
			end
			if #targetAllies >= 1 then
				return BOT_ACTION_DESIRE_HIGH, bot, "none", nil
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
Usage.ConsiderItemDesire["item_force_field"] = function(item)
	local radius = 1200
	local nInRangeEnemy = Fu.GetEnemiesNearLoc(bot:GetLocation(), radius)
	for _, enemy in pairs(nInRangeEnemy) do
		if
			Fu.IsValidHero(enemy)
			and enemy:GetAttackTarget() == bot
			and (bot:WasRecentlyDamagedByHero(enemy, 5) or Fu.IsAttackProjectileIncoming(bot, 500))
			and not Fu.IsSuspiciousIllusion(enemy)
		then
			return BOT_ACTION_DESIRE_HIGH, bot, "none", nil
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
Usage.ConsiderItemDesire["item_pirate_hat"] = function(item)
	return Usage.ConsiderItemDesire["item_trusty_shovel"](item)
end
Usage.ConsiderItemDesire["item_mana_draught"] = function(item)
	local nEnemyHeroes = bot:GetNearbyHeroes(1600, true, BOT_MODE_NONE)
	if
		#nEnemyHeroes == 0
		or Fu.IsValidHero(nEnemyHeroes[1])
			and not Fu.IsInRange(bot, nEnemyHeroes[1], 800)
			and not bot:WasRecentlyDamagedByAnyHero(5.0)
	then
		if Fu.GetMP(bot) < 0.5 then
			return BOT_ACTION_DESIRE_HIGH, bot, "none", nil
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
Usage.ConsiderItemDesire["item_polliwog_charm"] = function(item)
	local castRange = 1000
	if bot:GetMana() < 75 + 40 then
		return BOT_ACTION_DESIRE_NONE
	end
	local nAllyHeroes = Fu.GetAlliesNearLoc(bot:GetLocation(), castRange)
	local healTarget = nil
	local lowestHealth = 99999
	for _, ally in pairs(nAllyHeroes) do
		if
			Fu.IsValidHero(ally)
			and not ally:IsIllusion()
			and not ally:HasModifier("modifier_abaddon_borrowed_time")
			and not ally:HasModifier("modifier_necrolyte_reapers_scythe")
			and not ally:HasModifier("modifier_filler_heal")
			and not ally:HasModifier("modifier_elixer_healing")
			and not ally:HasModifier("modifier_flask_healing")
			and not ally:HasModifier("modifier_juggernaut_healing_ward_heal")
			and not ally:HasModifier("modifier_juggernaut_healing_ward_heal")
			and not ally:IsChanneling()
			and ally:GetMaxHealth() - ally:GetHealth() > 100
		then
			if ally:GetHealth() < lowestHealth then
				healTarget = ally
				lowestHealth = ally:GetHealth()
			end
		end
	end
	if healTarget ~= nil then
		return BOT_ACTION_DESIRE_HIGH, healTarget, "unit", nil
	end
	return BOT_ACTION_DESIRE_NONE
end
Usage.ConsiderItemDesire["item_rippers_lash"] = function(item)
	local castRange = 700
	local radius = 200
	local nAllyHeroes = Fu.GetAlliesNearLoc(bot:GetLocation(), castRange)
	for _, ally in pairs(nAllyHeroes) do
		if Fu.IsValidHero(ally) and not ally:IsIllusion() then
			local allyTarget = ally:GetAttackTarget()
			if Fu.IsGoingOnSomeone(ally) and Fu.IsAttacking(ally) then
				if
					Fu.IsValidHero(allyTarget)
					and Fu.CanBeAttacked(allyTarget)
					and Fu.IsInRange(ally, allyTarget, ally:GetAttackRange() + 50)
					and Fu.IsInRange(bot, allyTarget, castRange)
					and not Fu.IsSuspiciousIllusion(allyTarget)
					and not allyTarget:HasModifier("modifier_abaddon_borrowed_time")
					and not allyTarget:HasModifier("modifier_necrolyte_reapers_scythe")
					and not allyTarget:HasModifier("modifier_dazzle_shallow_grave")
				then
					local aoe = bot:FindAoELocation(true, true, allyTarget:GetLocation(), 0, radius, 0, 0)
					if aoe.count >= 2 then
						return BOT_ACTION_DESIRE_HIGH, aoe.targetloc, "point", nil
					else
						return BOT_ACTION_DESIRE_HIGH, allyTarget:GetLocation(), "point", nil
					end
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
Usage.ConsiderItemDesire["item_gale_guard"] = function(item)
	local nAllyHeroes = bot:GetNearbyHeroes(1600, false, BOT_MODE_NONE)
	local nEnemyHeroes = bot:GetNearbyHeroes(1600, true, BOT_MODE_NONE)
	if bot:HasModifier("modifier_abaddon_aphotic_shield") or not Fu.CanBeAttacked(bot) then
		return BOT_ACTION_DESIRE_NONE
	end
	if bot:IsRooted() and #nEnemyHeroes > 0 then
		return BOT_ACTION_DESIRE_HIGH, bot, "none", nil
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidHero(botTarget)
			and Fu.IsInRange(bot, botTarget, bot:GetAttackRange() + 300)
			and (Fu.GetHP(bot) < 0.65 and bot:WasRecentlyDamagedByAnyHero(3.0))
			and not Fu.IsSuspiciousIllusion(botTarget)
		then
			return BOT_ACTION_DESIRE_HIGH, bot, "none", nil
		end
	end
	if Fu.IsRetreating(bot) and not Fu.IsRealInvisible(bot) then
		for _, enemy in pairs(nEnemyHeroes) do
			if
				Fu.IsValidHero(enemy)
				and Fu.IsInRange(bot, enemy, 800)
				and Fu.IsChasingTarget(enemy, bot)
				and not Fu.IsSuspiciousIllusion(enemy)
			then
				if #nEnemyHeroes > #nAllyHeroes or Fu.GetHP(bot) < 0.55 and bot:WasRecentlyDamagedByAnyHero(3.0) then
					return BOT_ACTION_DESIRE_HIGH, bot, "none", nil
				end
			end
		end
	end
	if Fu.IsFarming(bot) then
		local enemyCreeps = bot:GetNearbyCreeps(1600, true)
		if enemyCreeps then
			if
				Fu.IsValid(enemyCreeps[1])
				and Fu.CanBeAttacked(enemyCreeps[1])
				and Fu.GetHP(bot) < 0.25
				and Fu.IsAttacking(bot)
			then
				return BOT_ACTION_DESIRE_HIGH, bot, "none", nil
			end
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if
			Fu.IsRoshan(botTarget)
			and Fu.CanBeAttacked(botTarget)
			and Fu.IsInRange(bot, botTarget, 500)
			and Fu.IsAttacking(bot)
			and Fu.GetHP(bot) < 0.5
		then
			return BOT_ACTION_DESIRE_HIGH, bot, "none", nil
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if
			Fu.IsTormentor(botTarget)
			and Fu.IsInRange(bot, botTarget, 400)
			and Fu.IsAttacking(bot)
			and Fu.GetHP(bot) < 0.5
		then
			return BOT_ACTION_DESIRE_HIGH, bot, "none", nil
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
Usage.ConsiderItemDesire["item_crippling_crossbow"] = function(item)
	local castRange = Fu.GetProperCastRange(false, bot, item:GetCastRange())
	local damage = item:GetSpecialValueInt("damage")
	local nAllyHeroes = bot:GetNearbyHeroes(1600, false, BOT_MODE_NONE)
	local nEnemyHeroes = bot:GetNearbyHeroes(1600, true, BOT_MODE_NONE)
	for _, enemy in pairs(nEnemyHeroes) do
		if
			Fu.IsValidHero(enemy)
			and Fu.IsInRange(bot, enemy, castRange)
			and not Fu.IsInRange(bot, enemy, castRange / 2)
			and Fu.CanCastOnNonMagicImmune(enemy)
			and Fu.CanCastOnTargetAdvanced(enemy)
		then
			if
				Fu.CanKillTarget(enemy, damage, DAMAGE_TYPE_MAGICAL)
				and not enemy:HasModifier("modifier_abaddon_borrowed_time")
				and not enemy:HasModifier("modifier_dazzle_shallow_grave")
				and not enemy:HasModifier("modifier_necrolyte_reapers_scythe")
				and not enemy:HasModifier("modifier_oracle_false_promise_timer")
			then
				return BOT_ACTION_DESIRE_HIGH, enemy, "unit", nil
			end
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidHero(botTarget)
			and Fu.CanBeAttacked(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.CanCastOnTargetAdvanced(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and not Fu.IsInRange(bot, botTarget, castRange / 2)
			and Fu.IsChasingTarget(bot, botTarget)
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget, "unit", nil
		end
	end
	if Fu.IsRetreating(bot) and not Fu.IsRealInvisible(bot) then
		for _, enemy in pairs(nEnemyHeroes) do
			if
				Fu.IsValidHero(enemy)
				and Fu.IsInRange(bot, enemy, castRange)
				and Fu.CanCastOnNonMagicImmune(enemy)
				and Fu.CanCastOnTargetAdvanced(enemy)
				and Fu.IsChasingTarget(enemy, bot)
				and not Fu.IsDisabled(enemy)
			then
				if #nEnemyHeroes > #nAllyHeroes or Fu.GetHP(bot) < 0.55 and bot:WasRecentlyDamagedByAnyHero(3.0) then
					return BOT_ACTION_DESIRE_HIGH, enemy, "unit", nil
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
Usage.ConsiderItemDesire["item_pyrrhic_cloak"] = function(item)
	local castRange = Fu.GetProperCastRange(false, bot, item:GetCastRange())
	local nEnemyHeroes = bot:GetNearbyHeroes(1600, true, BOT_MODE_NONE)
	if
		Fu.IsNotAttackProjectileIncoming(bot, 400)
		and Fu.IsValidHero(nEnemyHeroes[1])
		and Fu.IsInRange(bot, nEnemyHeroes[1], castRange)
		and Fu.CanCastOnNonMagicImmune(nEnemyHeroes[1])
		and Fu.CanCastOnTargetAdvanced(nEnemyHeroes[1])
	then
		return BOT_ACTION_DESIRE_HIGH, nEnemyHeroes[1], "unit", nil
	end
	for _, enemy in pairs(nEnemyHeroes) do
		if
			Fu.IsValidHero(enemy)
			and Fu.IsInRange(bot, enemy, castRange)
			and Fu.CanCastOnNonMagicImmune(enemy)
			and Fu.CanCastOnTargetAdvanced(enemy)
			and enemy:GetAttackTarget() == bot
			and (bot:WasRecentlyDamagedByHero(enemy, 3.0) or Fu.IsAttackProjectileIncoming(bot, 1000))
		then
			return BOT_ACTION_DESIRE_HIGH, enemy, "unit", nil
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
Usage.ConsiderItemDesire["item_minotaur_horn"] = function(item)
	if
		bot:IsMagicImmune()
		or not Fu.CanBeAttacked(bot)
		-- Already protected: skip. Was "or not lotus or not spell shield", which needed BOTH buffs
		-- to get past this check, so the horn was never used.
		or bot:HasModifier("modifier_item_lotus_orb_active")
		or bot:HasModifier("modifier_antimage_spell_shield")
	then
		return BOT_ACTION_DESIRE_NONE
	end
	local nEnemyHeroes = Fu.GetEnemiesNearLoc(bot:GetLocation(), 1200)
	-- Were globals; nAllyHeroes was never set at all (nil count, runtime error).
	local nInRangeEnemy
	local nAllyHeroes = Fu.GetAlliesNearLoc(bot:GetLocation(), 1200)
	if (Fu.IsGoingOnSomeone(bot) or Fu.IsRetreating(bot) and not Fu.IsRealInvisible(bot)) and #nEnemyHeroes > 0 then
		if bot:IsRooted() then
			return BOT_ACTION_DESIRE_HIGH, bot, "none", nil
		end
		nInRangeEnemy = Fu.GetEnemiesNearLoc(bot:GetLocation(), 600)
		if
			bot:IsSilenced()
			and #nInRangeEnemy >= 2
			and not bot:HasModifier("modifier_item_mask_of_madness_berserk")
		then
			return BOT_ACTION_DESIRE_HIGH, bot, "none", nil
		end
		if
			Fu.IsNotAttackProjectileIncoming(bot, 300)
			or Fu.IsWillBeCastUnitTargetSpell(bot, 300)
			or Fu.IsWillBeCastPointSpell(bot, 300)
		then
			return BOT_ACTION_DESIRE_HIGH, bot, "none", nil
		end
		nInRangeEnemy = Fu.GetEnemiesNearLoc(bot:GetLocation(), 1200)
		if
			#nInRangeEnemy > #nAllyHeroes
			and Fu.GetHP(bot) < 0.6
			and Fu.IsValidHero(nInRangeEnemy[1])
			and (Fu.IsChasingTarget(nInRangeEnemy[1], bot) or nInRangeEnemy[1]:GetAttackTarget() == bot)
		then
			return BOT_ACTION_DESIRE_HIGH, bot, "none", nil
		end
	end
	if
		bot:HasModifier("modifier_jakiro_macropyre_burn")
		or bot:HasModifier("modifier_lich_chainfrost_slow")
		or bot:HasModifier("modifier_crystal_maiden_freezing_field_slow")
		or bot:HasModifier("modifier_puck_coiled")
		or bot:HasModifier("modifier_skywrath_mystic_flare_aura_effect")
		or bot:HasModifier("modifier_snapfire_magma_burn_slow")
		or bot:HasModifier("modifier_sand_king_epicenter_slow")
	then
		return BOT_ACTION_DESIRE_HIGH, bot, "none", nil
	end
	return BOT_ACTION_DESIRE_NONE
end
Usage.ConsiderItemDesire["item_book_of_shadows"] = function(item)
	local castRange = 700 + castRangeBonus
	local allyHeroes = Fu.GetAlliesNearLoc(bot:GetLocation(), castRange)
	local nInRangeEnemy = Fu.GetEnemiesNearLoc(bot:GetLocation(), 1200)
	for _, ally in pairs(allyHeroes) do
		if Fu.IsValidHero(ally) and Fu.CanCastOnNonMagicImmune(ally) and ally:WasRecentlyDamagedByAnyHero(3) then
			local enemiesNearAlly = Fu.GetNearbyHeroes(ally, 1200, true, BOT_MODE_NONE)
			if
				enemiesNearAlly ~= nil
				and #enemiesNearAlly >= 1
				and Fu.IsRetreating(ally)
				and not Fu.IsRealInvisible(ally)
				and not Fu.IsDisabled(ally)
				and ally:DistanceFromFountain() > 1200
			then
				return BOT_ACTION_DESIRE_HIGH, ally, "unit", nil
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function Usage.IsTargetedByEnemy(unit)
	local enemyHeroes = GetUnitList(UNIT_LIST_ENEMY_HEROES)
	for _, enemy in pairs(enemyHeroes) do
		if Fu.IsValidHero(enemy) then
			if
				GetUnitToUnitDistance(unit, enemy) <= enemy:GetAttackRange() + 200
				and enemy:GetAttackTarget() == unit
			then
				return true
			end
		end
	end
	return false
end
local function UseGlyphIfNeeded()
	if
		GetGlyphCooldown() > 0
		or DotaTime() < 60
		or bot ~= GetTeamMember(1)
		or not GetTeamMember(2):IsBot()
		or not GetTeamMember(3):IsBot()
		or not GetTeamMember(4):IsBot()
		or not GetTeamMember(5):IsBot()
	then
		return
	end
	local towerIds = {
		TOWER_TOP_1,
		TOWER_MID_1,
		TOWER_BOT_1,
		TOWER_TOP_2,
		TOWER_MID_2,
		TOWER_BOT_2,
		TOWER_TOP_3,
		TOWER_MID_3,
		TOWER_BOT_3,
		TOWER_BASE_1,
		TOWER_BASE_2,
	}
	for _, towerId in pairs(towerIds) do
		local tower = GetTower(team, towerId)
		if
			tower ~= nil
			and tower:GetHealth() > 0
			and tower:GetHealth() / tower:GetMaxHealth() < 0.36
			and tower:CanBeSeen()
			and Usage.IsTargetedByEnemy(tower)
		then
			bot:ActionImmediate_Glyph()
			return
		end
	end
	local barracksIds = { BARRACKS_TOP_MELEE, BARRACKS_MID_MELEE, BARRACKS_BOT_MELEE }
	for _, barracksId in pairs(barracksIds) do
		local barracks = GetBarracks(team, barracksId)
		if
			barracks ~= nil
			and barracks:GetHealth() > 0
			and barracks:GetHealth() / barracks:GetMaxHealth() < 0.5
			and Usage.IsTargetedByEnemy(barracks)
		then
			bot:ActionImmediate_Glyph()
			return
		end
	end
	local ancient = GetAncient(team)
	if
		ancient ~= nil
		and ancient:GetHealth() > 0
		and ancient:GetHealth() / ancient:GetMaxHealth() < 0.5
		and Usage.IsTargetedByEnemy(ancient)
	then
		bot:ActionImmediate_Glyph()
		return
	end
end
-- [OHA-STUCK]: a live hero away from the fountain that has moved less than 300 in 8s while not
-- attacking, casting or channeling. Catches back-and-forth between two orders too, which the
-- idle nudge in global_overrides misses (the hero is never "idle"). At most every 10s per bot.
local STUCK_MODE_NAMES = nil
local function StuckModeName(mode)
	if STUCK_MODE_NAMES == nil then
		STUCK_MODE_NAMES = {}
		for name, id in pairs(_G) do
			if type(name) == "string" and type(id) == "number" and string.sub(name, 1, 9) == "BOT_MODE_" then
				STUCK_MODE_NAMES[id] = string.lower(string.sub(name, 10))
			end
		end
	end
	return STUCK_MODE_NAMES[mode] or tostring(mode)
end
-- [OHA-FLIP] a bot flipping between modes without getting anywhere: 6+ mode changes in 20s with
-- under 800 net movement. Game 019, 40:40-41:20: Gyrocopter by his mid T2 went roam 0.89, retreat
-- 0.29, roam 0.34, push 0.61 while walking back and forth (35 moved over a 2229 path). Lists
-- each mode with its desire at the switch. Once every 30s per bot at most.
function Usage.LogModeFlip()
	if not bot:IsAlive() then
		bot._modeHist = nil
		return
	end
	local now = DotaTime()
	local mode = bot:GetActiveMode()
	local hist = bot._modeHist or {}
	bot._modeHist = hist
	local last = hist[#hist]
	if last == nil or last.mode ~= mode then
		-- Why farm let go, when the switch is away from farm (game 039, 25:10: Rubick cycled farm 0.35 ->
		-- assemble 0.10 -> push 0.13-0.18 26 times in 20s and nothing said why farm kept dropping).
		local farmWhy = last ~= nil and last.mode == BOT_MODE_FARM and bot._farmExitReason or nil
		hist[#hist + 1] =
			{ t = now, mode = mode, des = bot:GetActiveModeDesire(), loc = bot:GetLocation(), farmWhy = farmWhy }
	end
	while #hist > 0 and hist[1].t < now - 20 do
		table.remove(hist, 1)
	end
	if #hist < 7 or now < (bot._modeFlipLogAt or -999) then
		return
	end
	local moved = Fu.GetLocationToLocationDistance(hist[1].loc, bot:GetLocation())
	if moved >= 800 then
		return
	end
	bot._modeFlipLogAt = now + 30
	local parts = {}
	for _, entry in ipairs(hist) do
		parts[#parts + 1] = string.format("%s:%.2f@%.0f", StuckModeName(entry.mode), entry.des or 0, entry.t)
			.. (entry.farmWhy and ("(farm-left:" .. tostring(entry.farmWhy) .. ")") or "")
	end
	local loc = bot:GetLocation()
	pcall(
		print,
		string.format(
			"[OHA-FLIP] t=%.0f %s changes=%d moved=%d at=%.0f,%.0f hp=%.2f enemies=%d modes=%s",
			now,
			(string.gsub(botName, "npc_dota_hero_", "")),
			#hist - 1,
			math.floor(moved),
			loc.x,
			loc.y,
			Fu.GetHP(bot),
			#(Fu.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE) or {}),
			table.concat(parts, ">")
		)
	)
end
function Usage.LogStuck()
	-- Laning holds position between last hits by design (239 of 855 lines in one game).
	if
		not bot:IsAlive()
		or bot:IsChanneling()
		or bot:IsCastingAbility()
		or bot:DistanceFromFountain() < 1200
		or bot:GetActiveMode() == BOT_MODE_LANING
	then
		bot._stuckTrail = nil
		return
	end
	local now = DotaTime()
	if now < (bot._stuckSampleAt or -999) then
		return
	end
	bot._stuckSampleAt = now + 1
	local trail = bot._stuckTrail or {}
	bot._stuckTrail = trail
	trail[#trail + 1] = { t = now, loc = bot:GetLocation() }
	while #trail > 0 and trail[1].t < now - 8.5 do
		table.remove(trail, 1)
	end
	if #trail < 8 or now < (bot._stuckLogAt or -999) then
		return
	end
	local attacking = bot:GetAttackTarget() ~= nil
	local moved = Fu.GetLocationToLocationDistance(trail[1].loc, bot:GetLocation())
	local path = 0
	for k = 2, #trail do
		path = path + Fu.GetLocationToLocationDistance(trail[k - 1].loc, trail[k].loc)
	end
	if moved < 300 and not attacking then
		bot._stuckLogAt = now + 10
		local loc = bot:GetLocation()
		pcall(
			print,
			string.format(
				"[OHA-STUCK] t=%.0f %s mode=%s/%.2f action=%s moved=%d path=%d at=%.0f,%.0f hp=%.2f enemies=%d",
				now,
				(string.gsub(botName, "npc_dota_hero_", "")),
				StuckModeName(bot:GetActiveMode()),
				bot:GetActiveModeDesire(),
				tostring(bot:GetCurrentActionType()),
				math.floor(moved),
				math.floor(path),
				loc.x,
				loc.y,
				Fu.GetHP(bot),
				#(Fu.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE) or {})
			)
		)
	end
end
-- An enemy tower shooting at the bot: an attack order on an allied lane creep that stands inside
-- the tower range makes the tower switch to it. Only a creep already within the bot's attack
-- range (+50) is used, so there is no walk: walking to a creep would keep the hero under the
-- tower longer and break a chase or a run. One order, then 2s before another; the mode's own
-- next order carries on (move, chase). Any HP: the order alone moves the tower's aggro, even on a
-- full-HP creep the hero cannot actually hit.
-- Logs [OHA-AGGRO] tower-deflect, and 0.8s later whether the tower switched target.
function Usage.DeflectTowerAggro()
	local now = DotaTime()
	if bot._deaggroTower ~= nil and now - (bot._deaggroAt or -99) >= 0.8 and not bot._deaggroChecked then
		bot._deaggroChecked = true
		local tower = bot._deaggroTower
		local switched = Fu.IsValidBuilding(tower) and tower:GetAttackTarget() ~= bot
		if not switched then
			bot._deaggroFailedAt = now
		end
		pcall(
			print,
			string.format(
				"[OHA-AGGRO] t=%.0f %s tower-deflect result=%s",
				now,
				(string.gsub(botName, "npc_dota_hero_", "")),
				switched and "switched" or "still-on-me"
			)
		)
	end
	if not bot:IsAlive() or bot:IsInvulnerable() or now < (bot._deaggroAt or -99) + 2 then
		return false
	end
	-- Walk out instead (game 034, 26:47-26:59: Phoenix kept getting a deflect order every 2s after
	-- it failed, each one cancelling the push mode's step out of range; he went from 85% to 9% HP
	-- under the tower, logged idle). No deflect below 60% HP or while retreating (the modes walk
	-- the bot out from there), and none for 6s after one that did not move the tower's aggro.
	if Fu.GetHP(bot) < 0.6 or bot:GetActiveMode() == BOT_MODE_RETREAT or now < (bot._deaggroFailedAt or -99) + 6 then
		return false
	end
	for _, tower in pairs(bot:GetNearbyTowers(1000, true) or {}) do
		if Fu.IsValidBuilding(tower) and tower:GetAttackTarget() == bot then
			local reach = bot:GetAttackRange() + 50
			local towerReach = tower:GetAttackRange() or 700
			local best, bestScore = nil, math.huge
			for _, creep in pairs(bot:GetNearbyLaneCreeps(reach + 200, false) or {}) do
				if
					Fu.IsValid(creep)
					and GetUnitToUnitDistance(bot, creep) <= reach
					and GetUnitToUnitDistance(tower, creep) <= towerReach
				then
					local score = GetUnitToUnitDistance(bot, creep)
					if score < bestScore then
						best, bestScore = creep, score
					end
				end
			end
			if best ~= nil then
				bot._deaggroAt = now
				bot._deaggroTower = tower
				bot._deaggroChecked = false
				pcall(
					print,
					string.format(
						"[OHA-AGGRO] t=%.0f %s tower-deflect creepHp=%.2f dist=%d mode=%s",
						now,
						(string.gsub(botName, "npc_dota_hero_", "")),
						Fu.GetHP(best),
						GetUnitToUnitDistance(bot, best),
						StuckModeName(bot:GetActiveMode())
					)
				)
				bot:Action_AttackUnit(best, true)
				return true
			end
			return false
		end
	end
	return false
end
-- [OHA-HOMEWALK]: a healthy bot (HP 80%+, mana 40%+) closing on its fountain for 4s+ while
-- outside it, after 10:00. Shows the mode and action behind walks home nobody asked for (game
-- 015, 52:20: Medusa walked back to the fountain at full HP after defending the high ground).
-- At most every 15s per bot.
function Usage.LogHomeWalk()
	if DotaTime() < 600 or not bot:IsAlive() then
		bot._homeWalkSince = nil
		return
	end
	local fountainDist = bot:DistanceFromFountain()
	local healthy = Fu.GetHP(bot) >= 0.8 and (bot:GetMaxMana() <= 0 or Fu.GetMP(bot) >= 0.4)
	local closing = bot._homeWalkLast ~= nil and fountainDist < bot._homeWalkLast - 5
	bot._homeWalkLast = fountainDist
	if not healthy or fountainDist < 1200 or fountainDist > 9000 or not closing or Fu.IsRetreating(bot) then
		if not closing then
			bot._homeWalkSince = nil
		end
		return
	end
	bot._homeWalkSince = bot._homeWalkSince or DotaTime()
	if DotaTime() - bot._homeWalkSince < 4 or DotaTime() < (bot._homeWalkLogAt or -999) then
		return
	end
	bot._homeWalkLogAt = DotaTime() + 15
	local loc = bot:GetLocation()
	pcall(
		print,
		string.format(
			"[OHA-HOMEWALK] t=%.0f %s mode=%s/%.2f action=%s fountainDist=%d at=%.0f,%.0f hp=%.2f stash=%d courier=%d",
			DotaTime(),
			(string.gsub(botName, "npc_dota_hero_", "")),
			StuckModeName(bot:GetActiveMode()),
			bot:GetActiveModeDesire(),
			tostring(bot:GetCurrentActionType()),
			math.floor(fountainDist),
			loc.x,
			loc.y,
			Fu.GetHP(bot),
			bot:GetStashValue(),
			bot:GetCourierValue()
		)
	)
end
-- A teleport just landed (TP scroll, Teleportation, Boots of Travel...): 1500+ moved in under
-- 1.5s. The "go farm" TPs wait 20s after it: game 020, 6:02-6:08, Nature's Prophet used
-- Teleportation to help top (team roam 1.50), landed, and laning mode TP'd him back to his
-- bottom lane 6s later ("出去发育").
function Usage.TrackTeleportJump()
	-- A respawn moves him to the fountain too: not a teleport.
	if not bot:IsAlive() then
		bot._jumpTrack = nil
		return
	end
	local now = DotaTime()
	local here = bot:GetLocation()
	local last = bot._jumpTrack
	if last ~= nil and now - last.t <= 1.5 and Fu.GetLocationToLocationDistance(last.loc, here) >= 1500 then
		bot._jumpAt = now
	end
	if last == nil or now - last.t >= 0.5 then
		bot._jumpTrack = { t = now, loc = here }
	end
end
function Usage.JustTeleported()
	return DotaTime() - (bot._jumpAt or -999) < 20
end
-- Stuck order queue: queued orders, not channelling or in a cast, and under 50 moved for 4s.
-- Game 021, 36:51-37:25: Doom stood still 12,500 from his base in defend mode with enemies at
-- his Ancient (current action idle / use-ability); the item think skips everything while
-- orders are queued, so a Forager mushroom in his bag was never eaten either. The orders are
-- cleared so modes and items work again.
function Usage.WatchStuckQueue()
	if not bot:IsAlive() or bot:NumQueuedActions() <= 0 or bot:IsChanneling() or bot:IsCastingAbility() then
		bot._qWatch = nil
		return false
	end
	local now = DotaTime()
	local here = bot:GetLocation()
	local watch = bot._qWatch
	if watch == nil or Fu.GetLocationToLocationDistance(watch.loc, here) >= 50 then
		bot._qWatch = { since = now, loc = here }
		return false
	end
	if now - watch.since < 4 then
		return false
	end
	bot._qWatch = nil
	pcall(
		print,
		string.format(
			"[OHA-STUCK] t=%.0f %s queue-cleared queued=%d action=%s mode=%d",
			now,
			(string.gsub(botName, "npc_dota_hero_", "")),
			bot:NumQueuedActions(),
			tostring(bot:GetCurrentActionType()),
			bot:GetActiveMode()
		)
	)
	bot:Action_ClearActions(true)
	return true
end
-- Game 031, 29:42-29:50: Doom teleported to the bottom lane and stood still while 3 enemies hit
-- him, with nothing in the log. Standing (moved under 40 in 2s) while a hero hit him in the last
-- second, not disabled, not casting: log the mode, desire, action and his debuffs, once per 8s.
function Usage.WatchStillUnderHit()
	if not bot:IsAlive() or not bot:WasRecentlyDamagedByAnyHero(1.0) then
		bot._stillWatch = nil
		return
	end
	local now = DotaTime()
	local here = bot:GetLocation()
	local watch = bot._stillWatch
	if watch == nil or Fu.GetLocationToLocationDistance(watch.loc, here) >= 40 then
		bot._stillWatch = { since = now, loc = here }
		return
	end
	if now - watch.since < 2 or now < (bot._stillLogAt or -999) then
		return
	end
	if
		bot:IsStunned()
		or bot:IsRooted()
		or bot:IsHexed()
		or bot:IsNightmared()
		or bot:IsChanneling()
		or bot:IsCastingAbility()
	then
		return
	end
	-- Attacking in place is fine (game 029, 52:22 and 52:30: Medusa and Pudge hitting a hero).
	local attackTarget = bot:GetAttackTarget()
	if
		attackTarget ~= nil
		and not attackTarget:IsNull()
		and attackTarget:IsAlive()
		and GetUnitToUnitDistance(bot, attackTarget) <= bot:GetAttackRange() + 150
	then
		return
	end
	bot._stillLogAt = now + 8
	local mods = {}
	for i = 0, math.min(bot:NumModifiers(), 24) - 1 do
		local name = bot:GetModifierName(i)
		if name ~= nil then
			table.insert(mods, (string.gsub(name, "^modifier_", "")))
		end
	end
	local target = bot:GetAttackTarget()
	pcall(
		print,
		string.format(
			"[OHA-STILL] t=%.0f %s still=%.1fs mode=%d desire=%.2f action=%s queued=%d target=%s hp=%.2f foes=%d mods=%s",
			now,
			(string.gsub(botName, "npc_dota_hero_", "")),
			now - watch.since,
			bot:GetActiveMode(),
			bot:GetActiveModeDesire(),
			tostring(bot:GetCurrentActionType()),
			bot:NumQueuedActions(),
			target ~= nil and not target:IsNull() and (string.gsub(target:GetUnitName(), "npc_dota_", "")) or "-",
			Fu.GetHP(bot),
			#(Fu.GetEnemiesNearLoc(here, 1200) or {}),
			#mods > 0 and table.concat(mods, ",") or "-"
		)
	)
end
-- Forager mushrooms in a main slot, eaten ahead of the item think's busy gate (queued orders,
-- casting ...). Game 032, 13:14-19:07: Medusa swapped a Vital Toadstool into a main slot every
-- 16s and never ate it; it went back to the backpack each time. Targeting from the datafeed:
-- Vital Toadstool is unit-target (cast on self), Ironwood Nut and Tomo'kan Ringcap are no-target
-- (the Ringcap was being cast on a unit). Once per 0.5s.
local FORAGE_NO_TARGET = { item_foragers_stats = true, item_foragers_mana = true }
function Usage.EatForage()
	if not bot:IsAlive() or DotaTime() < (bot._forageEatAt or -999) then
		return false
	end
	if bot:IsStunned() or bot:IsHexed() or bot:IsChanneling() or bot:IsCastingAbility() or bot:IsInvulnerable() then
		return false
	end
	local okM, muted = pcall(function()
		return bot:IsMuted()
	end)
	if okM and muted then
		return false
	end
	-- Did the last eat order consume anything? Game 039: Keeper ordered 306 eats of a Forager mushroom that was
	-- never used up (most likely another hero's: items owned by another player can't be used). After two
	-- orders that changed nothing, leave that item alone for 60s.
	bot._forageFail = bot._forageFail or {}
	local pending = bot._foragePending
	if pending ~= nil and DotaTime() >= pending.at + 1.0 then
		bot._foragePending = nil
		local item = bot:GetItemInSlot(pending.slot)
		local stillThere = item ~= nil
			and not item:IsNull()
			and item:GetName() == pending.name
			and (item:GetCurrentCharges() or 0) >= pending.charges
		if stillThere then
			local fail = bot._forageFail[pending.name] or { n = 0, untilAt = 0 }
			fail.n = fail.n + 1
			if fail.n >= 2 then
				fail.untilAt = DotaTime() + 60
				fail.n = 0
				pcall(
					print,
					string.format(
						"[OHA-FORAGE] t=%.0f %s cannot-eat %s why=not-consumed backoff=60s",
						DotaTime(),
						(string.gsub(botName, "npc_dota_hero_", "")),
						pending.name
					)
				)
			end
			bot._forageFail[pending.name] = fail
		else
			bot._forageFail[pending.name] = nil
		end
	end
	for slot = 0, 5 do
		local item = bot:GetItemInSlot(slot)
		if item ~= nil and not item:IsNull() then
			local name = item:GetName()
			local backedOff = bot._forageFail[name] ~= nil and DotaTime() < bot._forageFail[name].untilAt
			if
				(FORAGE_NO_TARGET[name] or name == "item_foragers_health")
				and Fu.CanCastAbility(item)
				and not backedOff
				and bot._foragePending == nil
			then
				bot._foragePending =
					{ name = name, slot = slot, charges = item:GetCurrentCharges() or 0, at = DotaTime() }
				bot._forageEatAt = DotaTime() + 0.5
				if DotaTime() >= (bot._forageLogAt or -999) then
					bot._forageLogAt = DotaTime() + 10
					pcall(
						print,
						string.format(
							"[OHA-FORAGE] t=%.0f %s eat %s slot%d",
							DotaTime(),
							(string.gsub(botName, "npc_dota_hero_", "")),
							name,
							slot
						)
					)
				end
				if FORAGE_NO_TARGET[name] then
					bot:Action_UseAbility(item)
				else
					bot:Action_UseAbilityOnEntity(item, bot)
				end
				return true
			end
		end
	end
	return false
end
-- Dust ahead of the item think's busy gate (queued orders and the like), as for the mushrooms:
-- the Dust rule decides, this only makes sure it can act. Dust is no-target (datafeed).
function Usage.UseDustNow()
	if not bot:IsAlive() or bot:IsStunned() or bot:IsHexed() or bot:IsChanneling() or bot:IsCastingAbility() then
		return false
	end
	local okM, muted = pcall(function()
		return bot:IsMuted()
	end)
	if okM and muted then
		return false
	end
	local slot = bot:FindItemSlot("item_dust")
	if slot < 0 or slot > 5 then
		return false
	end
	local dust = bot:GetItemInSlot(slot)
	local rule = Usage.ConsiderItemDesire["item_dust"]
	if dust == nil or rule == nil or not Fu.CanCastAbility(dust) then
		return false
	end
	local desire = rule(dust)
	if type(desire) == "number" and desire > 0 then
		bot:Action_UseAbility(dust)
		return true
	end
	return false
end
-- [OHA-COURIER] what the courier takes and delivers, and what shows up in the inventory (user ask,
-- game 031: Earthshaker's sentry was in the stash / on the courier while he kept switching a
-- dispenser with 1 observer). take: the stash items when the courier is sent for them; deliver:
-- the order with the courier's value; arrived: an item that appears in the inventory away from
-- the shop (or a dispenser whose charges change), checked once a second.
-- [OHA-API] one-time dump of the bot API this game build actually exposes (user ask: the online
-- docs are old and list no vector-target action). Radiant's first bot, once, at the first item
-- think: every global callable by name, every global table with callables (classes such as
-- CDOTA_Bot_Script) with its own and its metatable's callables, 25 names a line, sorted.
local function ApiNames(source)
	local names = {}
	local seen = {}
	local function add(tbl)
		if type(tbl) ~= "table" then
			return
		end
		for k, v in pairs(tbl) do
			if type(k) == "string" and type(v) == "function" and not seen[k] then
				seen[k] = true
				names[#names + 1] = k
			end
		end
	end
	add(source)
	local okM, metatable = pcall(getmetatable, source)
	if okM and type(metatable) == "table" then
		add(metatable)
		if type(metatable.__index) == "table" then
			add(metatable.__index)
		end
	end
	table.sort(names)
	return names
end
local function ApiPrint(label, names)
	for i = 1, #names, 25 do
		local part = {}
		for j = i, math.min(i + 24, #names) do
			part[#part + 1] = names[j]
		end
		pcall(
			print,
			string.format("[OHA-API] %s n=%d %d-%d: %s", label, #names, i, i + #part - 1, table.concat(part, ","))
		)
	end
end
function Usage.DumpBotApi()
	if _G.OHA_API_DUMPED or GetTeam() ~= TEAM_RADIANT then
		return
	end
	local first = GetTeamMember(1)
	if first == nil or first:GetPlayerID() ~= bot:GetPlayerID() then
		return
	end
	_G.OHA_API_DUMPED = true
	local globals, classes = {}, {}
	for k, v in pairs(_G) do
		if type(k) == "string" then
			if type(v) == "function" then
				globals[#globals + 1] = k
			elseif type(v) == "table" and k ~= "_G" and string.sub(k, 1, 1) == "C" then
				classes[#classes + 1] = k
			end
		end
	end
	table.sort(globals)
	table.sort(classes)
	ApiPrint("globals", globals)
	for _, className in ipairs(classes) do
		local names = ApiNames(_G[className])
		if #names > 0 then
			ApiPrint(className, names)
		end
	end
	-- The bot's own handle, in case its class table is not a global.
	ApiPrint("bot-handle", ApiNames(bot))
	-- Every numeric engine constant (#109, 7.42): BOT_MODE_*, ITEM_SLOT_*, RUNE_*, DAMAGE_TYPE_*, UNIT_LIST_*,
	-- SHRINE_*, ABILITY_BEHAVIOR_*, ... to compare with FuncLib/dota/enums.lua and the numbers our logs print.
	-- Then what the old healing-shrine API returns now that 7.33 replaced those shrines with lotus pools and
	-- watchers: GetShrine for every SHRINE_* id on both teams.
	local consts = {}
	for k, v in pairs(_G) do
		if type(k) == "string" and type(v) == "number" and string.find(k, "^[A-Z][A-Z0-9_]+$") then
			consts[#consts + 1] = k .. "=" .. tostring(v)
		end
	end
	table.sort(consts)
	ApiPrint("constants", consts)
	-- 7.42 items (#109): does the engine know the new items and the changed recipes? Cost and components as the
	-- buy code sees them (it buys by GetItemComponents). Names from the installed 7.42 items.txt.
	for _, itemName in ipairs({
		"item_bloodslinger",
		"item_caduceus",
		"item_ristuls_devotion",
		"item_berserkers_sabatons",
		"item_skypiercer",
		"item_starforge",
		"item_horn_of_battle_greater",
		"item_skadi",
		"item_bloodthorn",
		"item_abyssal_blade",
		"item_mjollnir",
		"item_butterfly",
		"item_basher",
		"item_crimson_guard",
		"item_harpoon",
		"item_heavens_halberd",
		"item_angels_demise",
		"item_helm_of_the_overlord",
	}) do
		local okC, cost = pcall(GetItemCost, itemName)
		local okP, parts = pcall(GetItemComponents, itemName)
		local recipes = {}
		if okP and type(parts) == "table" then
			for _, recipe in ipairs(parts) do
				if type(recipe) == "table" then
					recipes[#recipes + 1] = table.concat(recipe, "+")
				end
			end
		end
		pcall(
			print,
			string.format(
				"[OHA-API] item %s cost=%s parts=%s",
				itemName,
				okC and tostring(cost) or "error",
				okP and (#recipes > 0 and table.concat(recipes, " | ") or "-") or "error"
			)
		)
	end
	local shrineIds = {}
	for k, v in pairs(_G) do
		if type(k) == "string" and type(v) == "number" and string.find(k, "^SHRINE_") then
			shrineIds[#shrineIds + 1] = { name = k, id = v }
		end
	end
	table.sort(shrineIds, function(lhs, rhs)
		return lhs.id < rhs.id
	end)
	if #shrineIds == 0 then
		pcall(print, "[OHA-API] shrine no SHRINE_* constants defined")
	end
	for _, shrineTeam in ipairs({ TEAM_RADIANT, TEAM_DIRE }) do
		for _, shrineEntry in ipairs(shrineIds) do
			local ok, shrine = pcall(GetShrine, shrineTeam, shrineEntry.id)
			local detail
			if not ok then
				detail = "error=" .. tostring(shrine)
			elseif shrine == nil then
				detail = "nil"
			else
				local okL, loc = pcall(function()
					return shrine:GetLocation()
				end)
				local okN, name = pcall(function()
					return shrine:GetUnitName()
				end)
				local okC, cooldown = pcall(GetShrineCooldown, shrine)
				local okH, healing = pcall(IsShrineHealing, shrine)
				detail = string.format(
					"unit=%s xy=%s cooldown=%s healing=%s",
					okN and tostring(name) or "?",
					okL and loc ~= nil and string.format("%d,%d", math.floor(loc.x), math.floor(loc.y)) or "?",
					okC and tostring(cooldown) or "error",
					okH and tostring(healing) or "error"
				)
			end
			pcall(
				print,
				string.format(
					"[OHA-API] shrine team=%s %s(%d): %s",
					shrineTeam == TEAM_RADIANT and "radiant" or "dire",
					shrineEntry.name,
					shrineEntry.id,
					detail
				)
			)
		end
	end
end
function Usage.LogCourier(kind)
	local now = DotaTime()
	bot._courierLogAt = bot._courierLogAt or {}
	if now < (bot._courierLogAt[kind] or -999) then
		return
	end
	bot._courierLogAt[kind] = now + 3
	local names = {}
	for slot = 9, 14 do
		local item = bot:GetItemInSlot(slot)
		if item ~= nil and not item:IsNull() then
			names[#names + 1] = (string.gsub(item:GetName(), "^item_", ""))
		end
	end
	pcall(
		print,
		string.format(
			"[OHA-COURIER] t=%.0f %s %s stash=%s stashValue=%d courierValue=%d",
			now,
			(string.gsub(botName, "npc_dota_hero_", "")),
			kind,
			#names > 0 and table.concat(names, ",") or "-",
			bot:GetStashValue(),
			bot:GetCourierValue()
		)
	)
end
local function DispenserCounts(item)
	local obs = item:GetCurrentCharges() or 0
	local okS, sen = pcall(function()
		return item:GetSecondaryCharges()
	end)
	return obs, okS and type(sen) == "number" and sen or -1
end
function Usage.WatchArrivals()
	local now = DotaTime()
	if now < (bot._arrivalAt or -999) or not bot:IsAlive() then
		return
	end
	bot._arrivalAt = now + 1
	local count, disp = {}, nil
	for slot = 0, 8 do
		local item = bot:GetItemInSlot(slot)
		if item ~= nil and not item:IsNull() then
			local itemName = item:GetName()
			count[itemName] = (count[itemName] or 0) + 1
			if itemName == "item_ward_dispenser" then
				local observers, sentries = DispenserCounts(item)
				disp = { obs = observers, sen = sentries, slot = slot }
			end
		end
	end
	local prev = bot._arrivalPrev
	bot._arrivalPrev = { count = count, disp = disp }
	if prev == nil then
		return
	end
	local atShop = bot:DistanceFromFountain() <= 1000
	for itemName, itemCount in pairs(count) do
		if itemCount > (prev.count[itemName] or 0) and not atShop then
			pcall(
				print,
				string.format(
					"[OHA-COURIER] t=%.0f %s arrived %s slot=%d",
					now,
					(string.gsub(botName, "npc_dota_hero_", "")),
					(string.gsub(itemName, "^item_", "")),
					bot:FindItemSlot(itemName)
				)
			)
		end
	end
	local prevDisp = prev.disp
	if disp ~= nil and (prevDisp == nil or prevDisp.obs ~= disp.obs or prevDisp.sen ~= disp.sen) then
		pcall(
			print,
			string.format(
				"[OHA-COURIER] t=%.0f %s dispenser obs=%s->%d sen=%s->%d slot=%d",
				now,
				(string.gsub(botName, "npc_dota_hero_", "")),
				prevDisp ~= nil and tostring(prevDisp.obs) or "-",
				disp.obs,
				prevDisp ~= nil and tostring(prevDisp.sen) or "-",
				disp.sen,
				disp.slot
			)
		)
	end
end
-- Walk out of a Serpent Ward ring through the gap (see GetSerpentWardEscapeDesire in
-- FuncLib/hero/special_units.lua): once the snake on our way out is dead, move 250 past where it
-- stood for 1.5s. Runs from the item think, which acts after the mode thinks, so no mode turns the
-- bot back into the ring. Logged once per escape.
function Usage.WalkOutOfSnakes()
	local now = DotaTime()
	if not bot:IsAlive() then
		bot._snakeExit = nil
		bot._snakeExitWard = nil
		return false
	end
	local ward = bot._snakeExitWard
	if ward ~= nil and now - (bot._snakeExitWardAt or -999) < 6 then
		local dead = ward:IsNull() or not ward:IsAlive()
		if dead and bot._snakeExitWardLoc ~= nil then
			local from = bot:GetLocation()
			local dir = bot._snakeExitWardLoc - from
			if dir:Length2D() < 1 then
				dir = Fu.GetTeamFountain() - from
			end
			bot._snakeExit = { loc = bot._snakeExitWardLoc + dir:Normalized() * 250, untilAt = now + 1.5 }
			bot._snakeExitWard = nil
			pcall(
				print,
				string.format(
					"[OHA-SNAKE] t=%.0f %s walk-out hp=%.2f",
					now,
					(string.gsub(botName, "npc_dota_hero_", "")),
					Fu.GetHP(bot)
				)
			)
		end
	elseif ward ~= nil then
		bot._snakeExitWard = nil
	end
	local exit = bot._snakeExit
	if exit == nil then
		return false
	end
	if now > exit.untilAt or GetUnitToLocationDistance(bot, exit.loc) < 60 then
		bot._snakeExit = nil
		return false
	end
	if bot:IsStunned() or bot:IsRooted() or bot:IsHexed() or bot:IsChanneling() then
		return false
	end
	bot:Action_MoveToLocation(exit.loc)
	return true
end
function Usage.RunePickupLock()
	return bot:IsAlive() and bot:GetActiveMode() == BOT_MODE_RUNE and DotaTime() - (bot._runePickupAt or -999) < 0.5
end
-- Diagnostic (#15): does a bot in a cyclone (Wind Waker or Eul's, ours or an enemy's) drift? Other modes keep giving
-- move orders while it lasts, and Wind Waker's cyclone can be moved. One line when it ends: held time, distance moved
-- and how much closer to the fountain it got.
local CYCLONE_MODIFIERS = { "modifier_wind_waker", "modifier_item_wind_waker", "modifier_eul_cyclone" }
local function TrackCyclone()
	local found = nil
	for _, name in ipairs(CYCLONE_MODIFIERS) do
		if bot:HasModifier(name) then
			found = name
			break
		end
	end
	local cyclone = bot._cycloneTrack
	if found ~= nil and cyclone == nil then
		bot._cycloneTrack =
			{ name = found, at = DotaTime(), loc = bot:GetLocation(), fountain = bot:DistanceFromFountain() }
	elseif found == nil and cyclone ~= nil then
		bot._cycloneTrack = nil
		pcall(
			print,
			string.format(
				"[OHA-ITEM] t=%.0f %s cyclone-end mod=%s held=%.1f moved=%d toFountain=%d mode=%d",
				DotaTime(),
				(string.gsub(bot:GetUnitName(), "npc_dota_hero_", "")),
				cyclone.name,
				DotaTime() - cyclone.at,
				GetUnitToLocationDistance(bot, cyclone.loc),
				cyclone.fountain - bot:DistanceFromFountain(),
				bot:GetActiveMode()
			)
		)
	end
end
-- One voice per player (#8, game 046: Meepo still said "Going for Puck" / "going to mid" twice). Chat comes from many
-- files and every Meepo body runs them; on a clone (or Arc Warden's Tempest Double) the chat order becomes a no-op.
local function MuteCloneChat()
	if bot._chatGateDone then
		return
	end
	bot._chatGateDone = true
	if not (Fu.IsMeepoClone(bot) or bot:HasModifier("modifier_arc_warden_tempest_double")) then
		return
	end
	local ok = pcall(function()
		bot.ActionImmediate_Chat = function() end
	end)
	pcall(
		print,
		string.format(
			"[OHA-MEEPO] t=%.0f %s clone-chat-muted ok=%s",
			DotaTime(),
			(string.gsub(bot:GetUnitName(), "npc_dota_hero_", "")),
			tostring(ok)
		)
	)
end
function ItemUsageThink()
	local _perfT0 = nil
	if MatchTrace.PerfEnabled and MatchTrace.PerfEnabled() and RealTime then
		_perfT0 = RealTime()
	end
	local function _perfDone()
		if _perfT0 then
			MatchTrace.PerfSample("ItemUsageThink", RealTime() - _perfT0)
		end
	end
	MatchTrace.Tick(bot)
	pcall(MuteCloneChat)
	pcall(TrackCyclone)
	-- Ability charges for every bot (the API has no ability-charge read); before any gate below.
	pcall(ChargeTracker.Tick, bot)
	local tWatch = PartStart()
	pcall(Usage.TrackTeleportJump)
	pcall(Usage.WatchStillUnderHit)
	pcall(Usage.WatchArrivals)
	pcall(Usage.DumpBotApi)
	pcall(Usage.LogHomeWalk)
	PartEnd("watchers", tWatch)
	local okQ, cleared = pcall(Usage.WatchStuckQueue)
	if okQ and cleared then
		return
	end
	-- Rune mode just ordered a rune pick-up: no item or spell order this frame, it would replace
	-- the pick-up. The river horn gold stopped being taken from build 043 on, the build that fixed
	-- a crash in this think (before it, this think issued no orders at all for most bots); the
	-- same Dota build (6975) and no rune-mode change in between.
	if Usage.RunePickupLock() then
		return
	end
	do
		local okF, ate = pcall(Usage.EatForage)
		if okF and ate then
			_perfDone()
			return
		end
		local okD, dusted = pcall(Usage.UseDustNow)
		if okD and dusted then
			_perfDone()
			return
		end
		local okS, walking = pcall(Usage.WalkOutOfSnakes)
		if okS and walking then
			_perfDone()
			return
		end
	end
	-- A hero script holding for a cast it just ordered (Techies' M.A.D. plant): no item order
	-- that would replace it.
	if BotBuild ~= nil and BotBuild.MadHoldActive ~= nil then
		local okH, held = pcall(BotBuild.MadHoldActive)
		if okH and held then
			return
		end
	end
	-- Tower aggro: one attack order on an allied lane creep under the tower, never a walk.
	local okDeaggro, deaggroed = pcall(Usage.DeflectTowerAggro)
	if okDeaggro and deaggroed then
		return
	end
	-- Kiting for heroes on Valve's attack mode (the override attack mode kites from its own Think).
	local okKite, kited = pcall(SpecialUnits.TryKiteInAttack, bot)
	if okKite and kited then
		return
	end
	LogHumanPing()
	pcall(Usage.LogStuck)
	pcall(Usage.LogModeFlip)
	-- A hero script can ask to keep thinking while invulnerable (Tusk inside his snowball has
	-- to launch it). Spells only, no items. The return below used to skip it entirely, so the
	-- snowball always rolled its full duration.
	if bot:IsInvulnerable() and bot:IsAlive() and BotBuild ~= nil and BotBuild.bThinkWhileInvulnerable then
		local ok, err = pcall(BotBuild.SkillsComplement)
		if not ok then
			MatchTrace.Event(bot, "error", "SkillsComplement: " .. tostring(err))
			-- Hero spell-script errors were only in the match trace, never on the console (a
			-- Techies M.A.D. rule that never ran left no trace). First 3 distinct ones per bot.
			bot._skillErrs = bot._skillErrs or {}
			local key = tostring(err)
			if not bot._skillErrs[key] and (bot._skillErrCount or 0) < 3 then
				bot._skillErrs[key] = true
				bot._skillErrCount = (bot._skillErrCount or 0) + 1
				pcall(print, string.format("[OHA-ERROR] t=%.1f %s SkillsComplement: %s", DotaTime(), botName, key))
			end
		end
		_perfDone()
		return
	end
	if
		bot:IsInvulnerable()
		or not bot:IsHero()
		or not bot:IsAlive()
		or not string.find(botName, "hero")
		or bot:IsIllusion()
	then
		_perfDone()
		return
	end
	-- A spell or attack cancels an outpost capture. Wisdom and lotus do not care.
	-- Only while the capture is running, so a bot that gave up can still use items.
	if bot:HasModifier("modifier_watch_tower_capturing") then
		_perfDone()
		return
	end
	-- Keep attack orders; only throttle expensive item/ability rescans when target is locked.
	if ShouldThrottleHeavyThink() then
		_perfDone()
		return
	end
	if not Fu.IsNoItemIllution(bot) then
		local tItem = _perfT0 and RealTime() or nil
		local tItems = PartStart()
		ConsiderItems()
		PartEnd("items", tItems)
		if tItem then
			MatchTrace.PerfSample("ItemUsage.bg", RealTime() - tItem)
		end
	end
	-- Last stand: a cornered hero casts the big spells its script lists in LastStandSpells
	-- ({ name, kind = "none" | "unit" | "point" }) before anything else. Running stops working
	-- under heavy slows in a crowd; the spell is worth more than one more step.
	if
		BotBuild ~= nil
		and BotBuild.LastStandSpells ~= nil
		and not Fu.IsNoAbilityIllution(bot)
		and not Fu.CanNotUseAbility(bot)
	then
		local cornered, nearest, foes = AbilityContext.IsCornered(bot)
		if cornered then
			for _, spec in ipairs(BotBuild.LastStandSpells) do
				local ability = bot:GetAbilityByName(spec.name)
				if
					ability ~= nil
					and not ability:IsNull()
					and ability:IsTrained()
					and not ability:IsHidden()
					and ability:IsFullyCastable()
				then
					pcall(
						print,
						string.format(
							"[OHA-CORNERED] t=%.0f %s last-stand %s",
							DotaTime(),
							(string.gsub(botName, "npc_dota_hero_", "")),
							spec.name
						)
					)
					if spec.kind == "unit" and Fu.IsValidHero(nearest) then
						bot:Action_UseAbilityOnEntity(ability, nearest)
					elseif spec.kind == "point" and foes ~= nil and #foes > 0 then
						bot:Action_UseAbilityOnLocation(ability, Fu.GetCenterOfUnits(foes))
					else
						bot:Action_UseAbility(ability)
					end
					_perfDone()
					return
				end
			end
		end
	end
	if BotBuild ~= nil and not Fu.IsNoAbilityIllution(bot) then
		local tSkill = _perfT0 and RealTime() or nil
		local tHero = PartStart()
		local ok, err = pcall(BotBuild.SkillsComplement)
		PartEnd("hero-abilities", tHero)
		if tSkill then
			MatchTrace.PerfSample("SkillsComplement", RealTime() - tSkill)
		end
		if not ok then
			MatchTrace.Event(bot, "error", "SkillsComplement: " .. tostring(err))
			-- Hero spell-script errors were only in the match trace, never on the console (a
			-- Techies M.A.D. rule that never ran left no trace). First 3 distinct ones per bot.
			bot._skillErrs = bot._skillErrs or {}
			local key = tostring(err)
			if not bot._skillErrs[key] and (bot._skillErrCount or 0) < 3 then
				bot._skillErrs[key] = true
				bot._skillErrCount = (bot._skillErrCount or 0) + 1
				pcall(print, string.format("[OHA-ERROR] t=%.1f %s SkillsComplement: %s", DotaTime(), botName, key))
			end
		end
	end
	if Dispel and not bot:IsChanneling() then
		local mantaSlot = Dispel.ShouldMantaDodge(bot)
		if mantaSlot >= 0 then
			local item = bot:GetItemInSlot(mantaSlot)
			if item then
				bot:Action_UseAbility(item)
				_perfDone()
				return
			end
		end
		local selfDispelSlot = Dispel.ShouldUseSelfDispelItem(bot)
		if selfDispelSlot >= 0 then
			local item = bot:GetItemInSlot(selfDispelSlot)
			if item then
				bot:Action_UseAbility(item)
				_perfDone()
				return
			end
		end
		local allyDispelSlot, dispelAlly = Dispel.ShouldUseAllyDispelItem(bot)
		if allyDispelSlot >= 0 and dispelAlly then
			local item = bot:GetItemInSlot(allyDispelSlot)
			if item then
				bot:Action_UseAbilityOnEntity(item, dispelAlly)
				_perfDone()
				return
			end
		end
	end
	for backpackSlot = 6, 8 do
		local backpackItem = bot:GetItemInSlot(backpackSlot)
		if backpackItem ~= nil then
			local itemName = backpackItem:GetName()
			if itemName == "item_famango" or itemName == "item_great_famango" or itemName == "item_greater_famango" then
				for mainSlot = 0, 5 do
					if bot:GetItemInSlot(mainSlot) == nil then
						bot:ActionImmediate_SwapItems(backpackSlot, mainSlot)
						break
					end
				end
				break
			end
		end
	end
	_perfDone()
end
function AbilityUsageThink()
	if Usage.RunePickupLock() then
		return
	end
	HandleIdleBotState(bot)
end
local saidGgLose = false
local willSayGgLose = nil
local ggLoseSayTime = 0
local saidGgWin = false
local willSayGgWin = nil
local ggWinSayTime = 0
local localizationLib = nil
local function PickChatLine(key)
	if localizationLib == nil then
		local ok, loadedLib = pcall(require, GetScriptDirectory() .. "/FuncLib/systems/localization")
		localizationLib = ok and loadedLib or false
	end
	if localizationLib and localizationLib.Get then
		local lines = localizationLib.Get(key)
		if lines and type(lines) == "table" and #lines > 0 then
			return lines[RandomInt(1, #lines)]
		end
		if lines and type(lines) == "string" then
			return lines
		end
	end
	if key == "say_gg_lose" then
		local ggLines = { "gg", "ggwp", "GG" }
		return ggLines[RandomInt(1, #ggLines)]
	end
	local ezLines = { "ez", "gg ez", "EZ" }
	return ezLines[RandomInt(1, #ezLines)]
end
function BuybackUsageThink()
	if CheckArdmHeroSwap() then
		return
	end
	if bot.lastBuybackFrameProcessTime == nil then
		bot.lastBuybackFrameProcessTime = DotaTime()
	end
	if DotaTime() > 30 and DotaTime() - bot.lastBuybackFrameProcessTime < 2 then
		return
	end
	bot.lastBuybackFrameProcessTime = DotaTime()
	if not bot:IsIllusion() then
		ConsiderBuyback()
	end
	if not bot:IsIllusion() then
		UseGlyphIfNeeded()
	end
	if not saidGgLose and not bot:IsIllusion() and DotaTime() > 10 * 60 then
		local ownAncient = GetAncient(GetTeam())
		if ownAncient ~= nil and Fu.GetHP(ownAncient) < 0.2 and Fu.CanBeAttacked(ownAncient) then
			local aliveAllyCount = Fu.GetNumOfAliveHeroes(false)
			if aliveAllyCount <= 2 then
				if willSayGgLose == nil then
					willSayGgLose = RandomInt(1, 5) <= 3
					ggLoseSayTime = DotaTime() + RandomFloat(1, 5)
				end
				if willSayGgLose and DotaTime() >= ggLoseSayTime then
					bot:ActionImmediate_Chat(PickChatLine("say_gg_lose"), true)
					saidGgLose = true
				end
			end
		end
	end
	if not saidGgWin and not bot:IsIllusion() and DotaTime() > 10 * 60 then
		local enemyAncient = GetAncient(GetOpposingTeam())
		if enemyAncient ~= nil and Fu.GetHP(enemyAncient) < 0.2 and Fu.CanBeAttacked(enemyAncient) then
			local aliveAllyCount = Fu.GetNumOfAliveHeroes(false)
			if aliveAllyCount >= 3 then
				if willSayGgWin == nil then
					willSayGgWin = RandomInt(1, 5) <= 3
					ggWinSayTime = DotaTime() + RandomFloat(1, 5)
				end
				if willSayGgWin and DotaTime() >= ggWinSayTime then
					bot:ActionImmediate_Chat(PickChatLine("say_gg_win"), true)
					saidGgWin = true
				end
			end
		end
	end
end
function CourierUsageThink()
	if CheckArdmHeroSwap() then
		return
	end
	if bot.lastCourierFrameProcessTime == nil then
		bot.lastCourierFrameProcessTime = DotaTime()
	end
	if DotaTime() > 30 and DotaTime() - bot.lastCourierFrameProcessTime < 0.5 then
		return
	end
	bot.lastCourierFrameProcessTime = DotaTime()
	if not bot:IsIllusion() then
		ManageCourier()
	end
end
function AbilityLevelUpThink()
	if CheckArdmHeroSwap() then
		return
	end
	if bot.lastLevelUpFrameProcessTime == nil then
		bot.lastLevelUpFrameProcessTime = DotaTime()
	end
	if DotaTime() > 30 and DotaTime() - bot.lastLevelUpFrameProcessTime < 1 then
		return
	end
	bot.lastLevelUpFrameProcessTime = DotaTime()
	if not bot:IsIllusion() then
		LevelUpAbilities()
	end
end
function Usage.SetAbilityItemList(enableDefaultAbility, enableDefaultItem, levelUpList)
	useDefaultItem = enableDefaultItem
	abilityLevelUpList = levelUpList
end
Usage.AbilityLevelUpThink = AbilityLevelUpThink
Usage.BuybackUsageThink = BuybackUsageThink
-- Engine entry points report their own errors. Unwrapped, an error here showed only as
-- "Script Runtime Error: error in error handling" (every bot at -89s), with no message.
-- Up to 3 per function per bot, as [OHA-ERROR].
local OHA_ERR_COUNT = {}
local function OHA_Guard(name, fn)
	if type(fn) ~= "function" then
		return fn
	end
	return function(...)
		local ok, err = pcall(fn, ...)
		if not ok then
			local errCount = (OHA_ERR_COUNT[name] or 0) + 1
			OHA_ERR_COUNT[name] = errCount
			if errCount <= 3 then
				local hero = "?"
				pcall(function()
					hero = GetBot():GetUnitName()
				end)
				pcall(print, string.format("[OHA-ERROR] t=%.1f %s %s: %s", DotaTime(), hero, name, tostring(err)))
			end
		end
	end
end
ItemUsageThink = OHA_Guard("ItemUsageThink", ItemUsageThink)
AbilityUsageThink = OHA_Guard("AbilityUsageThink", AbilityUsageThink)
BuybackUsageThink = OHA_Guard("BuybackUsageThink", BuybackUsageThink)
CourierUsageThink = OHA_Guard("CourierUsageThink", CourierUsageThink)
AbilityLevelUpThink = OHA_Guard("AbilityLevelUpThink", AbilityLevelUpThink)
Usage.AbilityUsageThink = AbilityUsageThink
Usage.ItemUsageThink = ItemUsageThink
-- [OHA-PERF] timing (#52): FuncLib/systems/perf.lua
do
	local Perf = require(GetScriptDirectory() .. "/FuncLib/systems/perf")
	ItemUsageThink = Perf.Wrap("ItemUsageThink", ItemUsageThink)
	AbilityUsageThink = Perf.Wrap("AbilityUsageThink", AbilityUsageThink)
	BuybackUsageThink = Perf.Wrap("BuybackUsageThink", BuybackUsageThink)
	CourierUsageThink = Perf.Wrap("CourierUsageThink", CourierUsageThink)
	AbilityLevelUpThink = Perf.Wrap("AbilityLevelUpThink", AbilityLevelUpThink)
end
return Usage
