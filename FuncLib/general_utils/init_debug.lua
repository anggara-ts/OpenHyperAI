-- Shared helper: init debug.
local function installDebugHelpers(Fu)
	local isDebugEnabled = 1 == 10
	function Fu.SetUserHeroInit(nAbilityBuildList, nTalentBuildList, sBuyList, sSellList)
		local bot = GetBot()
		local heroName = bot:GetUnitName()
		local modulePath, heroConfig = "game/Customize/hero/" .. string.gsub(heroName, "npc_dota_hero_", ""), nil
		-- The handlers only keep the message. Logging from inside them showed up as
		-- "Script Runtime Error: error in error handling" for every bot at -89s (a per-hero
		-- Customize file is optional, so a failed require is normal).
		local loadErr = nil
		local loaded = xpcall(function()
			heroConfig = require(modulePath)
		end, function(err)
			loadErr = err
			return err
		end)
		if not (loaded and heroConfig) then
			modulePath = GetScriptDirectory() .. "/Customize/hero/" .. string.gsub(heroName, "npc_dota_hero_", "")
			loaded = xpcall(function()
				heroConfig = require(modulePath)
			end, function(err)
				loadErr = err
				return err
			end)
		end
		if not (loaded and heroConfig) and loadErr ~= nil then
			pcall(log, "[WARN] No customized hero file for %s: %s", heroName, tostring(loadErr))
		end
		if loaded and heroConfig and heroConfig.Enable then
			nAbilityBuildList = heroConfig.AbilityUpgrade
			nTalentBuildList = Fu.GetTalentBuildList(heroConfig.Talent)
			sBuyList = heroConfig.PurchaseList
			sSellList = heroConfig.SellList
		elseif type(sBuyList) == "table" then
			local ok, applied = pcall(function()
				return require(GetScriptDirectory() .. "/FuncLib/systems/item_strategy").ApplyTeamItems(bot, sBuyList)
			end)
			if ok and type(applied) == "table" then
				sBuyList = applied
			else
				log("[WARN] Team item plan failed for %s: %s", heroName, tostring(applied))
				local kept = {}
				for i = 1, #sBuyList do
					if sBuyList[i] ~= "item_team_aura" then
						kept[#kept + 1] = sBuyList[i]
					end
				end
				sBuyList = kept
			end
		end
		return nAbilityBuildList, nTalentBuildList, sBuyList, sSellList
	end
	function Fu.GetTalentBuildList(talentList)
		local talentBuild = {}
		for i = 1, #talentList do
			local talentChoice = talentList[i] == "l" and 10 or 0
			if talentChoice == 10 then
				talentBuild[#talentBuild + 1] = i * 2
			else
				talentBuild[#talentBuild + 1] = i * 2 - 1
			end
		end
		for i = 1, #talentList do
			local talentChoice = talentList[i] == "r" and 10 or 0
			if talentChoice ~= 10 then
				talentBuild[#talentBuild + 1] = i * 2
			else
				talentBuild[#talentBuild + 1] = i * 2 - 1
			end
		end
		return talentBuild
	end
	function Fu.SetBotPrint(message, location, shouldChat, shouldPing)
		local bot = GetBot()
		local roundedTime = Fu.GetOne(DotaTime() / 10) * 10
		local clockText = Fu.GetOne(roundedTime / 600) * 10 .. ":" .. roundedTime % 60
		local teamName = GetTeam() == TEAM_DIRE and "夜魇" or "天辉"
		if isDebugEnabled then
			log("%s%s %s %s", teamName, clockText, Fu.Chat.GetNormName(bot), message)
			if shouldChat then
				bot:ActionImmediate_Chat(clockText .. "_" .. message, true)
			end
			if shouldPing then
				bot:ActionImmediate_Ping(location.x, location.y, false)
			end
		end
	end
	function Fu.SetReportMotive(shouldReport, motive)
		if isDebugEnabled and shouldReport and motive ~= nil then
			local roundedTime = Fu.GetOne(DotaTime() / 10) * 10
			local clockText = Fu.GetOne(roundedTime / 600) * 10 .. ":" .. roundedTime % 60
			local teamName = GetTeam() == TEAM_DIRE and "夜魇 " or "天辉 "
			GetBot():ActionImmediate_Chat(clockText .. "_" .. motive, true)
			log("%s%s %s %s", teamName, clockText, Fu.Chat.GetNormName(GetBot()), motive)
		end
	end
	function Fu.IsStuck(bot)
		if bot.stuckLoc ~= nil and bot.stuckTime ~= nil and bot:CanBeSeen() then
			local attackTarget = bot:GetAttackTarget()
			local distanceToEnemyAncient = GetUnitToUnitDistance(bot, GetAncient(GetOpposingTeam()))
			local distanceToOurAncient = GetUnitToUnitDistance(bot, GetAncient(GetTeam()))
			local enemyTowers = bot:GetNearbyTowers(450, true)
			local allyTowers = bot:GetNearbyTowers(450, false)
			if
				bot:GetCurrentActionType() == BOT_ACTION_TYPE_MOVE_TO
				and attackTarget == nil
				and distanceToEnemyAncient > 2200
				and distanceToOurAncient > 2200
				and #enemyTowers == 0
				and #allyTowers == 0
				and DotaTime() > bot.stuckTime + 5.0
				and GetUnitToLocationDistance(bot, bot.stuckLoc) < 25
			then
				log("%s is stuck", bot:GetUnitName())
				return true
			end
		end
		return false
	end
	local idleCheckInterval = 5
	local idleDistance = 30
	local idleStates = {}
	function Fu.CheckBotIdleState()
		if DotaTime() <= 0 then
			return false
		end
		local bot = GetBot()
		if not bot:IsAlive() then
			return false
		end
		local heroName = bot:GetUnitName()
		local playerId = bot:GetPlayerID()
		local activeMode = bot:GetActiveMode()
		local idleState = idleStates[playerId]
		if idleState then
			if DotaTime() - idleState.lastCheckTime >= idleCheckInterval then
				local movedDistance = Fu.GetLocationToLocationDistance(idleState.botLocation, bot:GetLocation())
				if not Fu.IsTryingtoUseAbility(bot) and not Fu.IsAttacking(bot) and movedDistance <= idleDistance then
					idleState.idleCount = idleState.idleCount + 1
					if bot:GetCurrentActionType() == BOT_ACTION_TYPE_IDLE or activeMode == BOT_MODE_ITEM or activeMode == BOT_MODE_FARM then
						local queuedCount = bot:NumQueuedActions()
						if queuedCount > 0 then
							for i = 1, queuedCount do
								local actionType = bot:GetQueuedActionType(i)
								log("Bot %s has enqueued actions i=%s, type=%s", heroName, i, actionType)
							end
						end
						bot:Action_ClearActions(true)
						local laneFront = GetLaneFrontLocation(GetTeam(), bot:GetAssignedLane(), 0)
						bot:ActionQueue_AttackMove(laneFront)
						log(
							"[ERROR] Relocating the idle bot: %s. Sending it to the lane# it was originally assigned: %s",
							heroName,
							bot:GetAssignedLane()
						)
					else
						log("Bot %s is in idle state for unknown reasons. N/A.", heroName)
					end
					return true
				else
					idleState.idleCount = 0
				end
				idleState.botLocation = bot:GetLocation()
				idleState.lastCheckTime = DotaTime()
			end
		else
			local newState = { botLocation = bot:GetLocation(), lastCheckTime = DotaTime(), idleCount = 0 }
			idleStates[playerId] = newState
		end
		return false
	end
	function Fu.IsStaleARDMHero(hero, heroName)
		if GetGameMode() ~= GAMEMODE_ARDM then
			return false, hero, heroName
		end
		local bot = GetBot()
		local currentName = bot:GetUnitName()
		local playerId = hero:GetPlayerID()
		if currentName ~= heroName and bot ~= hero then
			return true, bot, currentName
		end
		if playerId >= 0 and IsHeroAlive(playerId) and not hero:IsAlive() then
			if currentName ~= heroName then
				return true, bot, currentName
			end
		end
		return false, bot, currentName
	end
	function Fu.ModeAnnounce(bot, modeKey, cooldown)
		local Localization = require(GetScriptDirectory() .. "/FuncLib/systems/localization")
		if bot.lastModeChatTime == nil then
			bot.lastModeChatTime = {}
		end
		local lastChatTime = bot.lastModeChatTime[modeKey] or -999
		if GameTime() - lastChatTime < (cooldown or 30) then
			return
		end
		bot.lastModeChatTime[modeKey] = GameTime()
		local lines = Localization.Get(modeKey)
		if lines ~= nil and #lines > 0 then
			bot:ActionImmediate_Chat(lines[RandomInt(1, #lines)], false)
		end
	end
end
return installDebugHelpers
