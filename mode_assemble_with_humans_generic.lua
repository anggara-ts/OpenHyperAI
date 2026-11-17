-- Gather when a human player calls the team together.
local X = {}
local bot = GetBot()
local botName = bot:GetUnitName()
if
	bot == nil
	or bot:IsInvulnerable()
	or not bot:IsHero()
	or not bot:IsAlive()
	or not string.find(botName, "hero")
	or bot:IsIllusion()
then
	return
end
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local Localization = require(GetScriptDirectory() .. "/FuncLib/systems/localization")
local ObjectiveTravel = require(GetScriptDirectory() .. "/FuncLib/systems/objective_travel")
local tormentorUnit = nil
local tormentorLocation = 0
local tormentorWaitingLocation = 0
local lastPingTime = 0
local canDoTormentor = false
if bot.tormentor_state == nil then
	bot.tormentor_state = false
end
if bot.tormentor_kill_time == nil then
	bot.tormentor_kill_time = 0
end
local coresNearTormentor = 0
local supportsNearTormentor = 0
local hasHumanAlly = false
local tormentorStartTime = 0
local tormentorCooldownUntil = 0
local tormentorTimeout = 60
local lastDebugLogTime = 0
local nextWaitMoveTime = 0
local lastScoutCheckTime = 0
local isTormentorSeen = false
function GetDesire()
	if ShouldSkipBotThink(GetBot()) then
		return 0
	end
	local desire, reason = GetDesireHelper()
	if IsDebug and DotaTime() > 60 and DotaTime() > lastDebugLogTime + 15 then
		lastDebugLogTime = DotaTime()
		log(
			"[TORMENTOR] %s t=%.0f desire=%.2f state=%s killTime=%.0f canDo=%s reason=%s",
			bot:GetUnitName(),
			DotaTime(),
			desire,
			tostring(bot.tormentor_state),
			bot.tormentor_kill_time or 0,
			tostring(canDoTormentor),
			tostring(reason or "none")
		)
	end
	return RemapValClamped(Fu.GetHP(bot), 0, 0.8, 0, desire)
end
function GetDesireHelper()
	tormentorLocation = Fu.GetTormentorLocation(GetTeam())
	tormentorWaitingLocation = Fu.GetTormentorWaitingLocation(GetTeam())
	local alliesNearTormentor = Fu.GetAlliesNearLoc(tormentorLocation, 900)
	local alliesNearWaitingSpot = Fu.GetAlliesNearLoc(tormentorWaitingLocation, 900)
	local aliveAllyCount = 0
	local respawnMinutes = Fu.IsModeTurbo() and 5 or 10
	local firstSpawnMinutes = Fu.IsModeTurbo() and 10 or 20
	local humansNearTormentor = 0
	local alliesAttackingTormentor = 0
	local coreLevelSum = 0
	local supportLevelSum = 0
	coresNearTormentor = 0
	supportsNearTormentor = 0
	for i = 1, 5 do
		local member = GetTeamMember(i)
		if member ~= nil then
			local memberLevel = member:GetLevel()
			if member:IsAlive() then
				aliveAllyCount = aliveAllyCount + 1
				if not member:IsBot() then
					if bot.tormentor_state == false and Fu.IsValidHero(member) then
						if
							GetUnitToLocationDistance(member, tormentorLocation) <= 1300
							and IsLocationVisible(tormentorLocation)
						then
							local neutralCreeps = member:GetNearbyNeutralCreeps(1300)
							for j = #neutralCreeps, 1, -1 do
								if
									Fu.IsValid(neutralCreeps[j])
									and string.find(neutralCreeps[j]:GetUnitName(), "miniboss")
								then
									bot.tormentor_state = true
								end
							end
						end
					end
					if
						GetUnitToLocationDistance(member, tormentorLocation) <= 1600
						or GetUnitToLocationDistance(member, tormentorWaitingLocation) <= 1600
					then
						humansNearTormentor = humansNearTormentor + 1
					end
				end
				local memberTarget = Fu.GetProperTarget(member)
				if Fu.IsTormentor(memberTarget) and Fu.IsAttacking(member) then
					alliesAttackingTormentor = alliesAttackingTormentor + 1
				end
				if member.tormentor_team_healthy == nil then
					member.tormentor_team_healthy = false
				end
				if member.tormentor_team_healthy == true then
					bot.tormentor_team_healthy = true
				end
				if Fu.IsCore(member) then
					if
						GetUnitToLocationDistance(member, tormentorLocation) <= 900
						or GetUnitToLocationDistance(member, tormentorWaitingLocation) <= 900
					then
						coresNearTormentor = coresNearTormentor + 1
					end
				else
					if
						GetUnitToLocationDistance(member, tormentorLocation) <= 900
						or GetUnitToLocationDistance(member, tormentorWaitingLocation) <= 900
					then
						supportsNearTormentor = supportsNearTormentor + 1
					end
				end
			end
			if Fu.IsCore(member) then
				if memberLevel < 13 then
					coreLevelSum = 0
				else
					coreLevelSum = coreLevelSum + memberLevel
				end
			else
				if memberLevel < 11 then
					supportLevelSum = 0
				else
					supportLevelSum = supportLevelSum + memberLevel
				end
			end
			if member.tormentor_state == true then
				bot.tormentor_state = true
			end
			if
				member.tormentor_kill_time ~= nil
				and member.tormentor_kill_time > 0
				and member.tormentor_kill_time > bot.tormentor_kill_time
			then
				bot.tormentor_kill_time = member.tormentor_kill_time
			end
			if not member:IsBot() and not hasHumanAlly then
				hasHumanAlly = true
			end
		end
	end
	if
		#alliesNearTormentor <= 1
		and humansNearTormentor == 0
		and DotaTime() > (Fu.IsModeTurbo() and 25 * 60 or 40 * 60)
	then
		return BOT_MODE_DESIRE_NONE, "late_no_allies"
	end
	local enemyAncient = GetAncient(GetOpposingTeam())
	if
		#alliesNearTormentor <= 1
		and humansNearTormentor == 0
		and GetUnitToLocationDistance(bot, tormentorLocation) > 1600
		and (
			GetUnitToUnitDistance(bot, enemyAncient) < 4000
				and #Fu.GetEnemiesNearLoc(enemyAncient:GetLocation(), 4000) > 0
			or Fu.IsDoingRoshan(bot) and bot:GetActiveModeDesire() >= BOT_MODE_DESIRE_HIGH
		)
	then
		return BOT_MODE_DESIRE_NONE, "near_enemy_ancient_or_rosh"
	end
	if
		#Fu.GetEnemiesNearLoc(GetAncient(GetTeam()):GetLocation(), 2000) >= 2
		or (
			GetTower(GetTeam(), TOWER_TOP_3) == nil
			or GetTower(GetTeam(), TOWER_MID_3) == nil
			or GetTower(GetTeam(), TOWER_BOT_3) == nil
		)
	then
		return BOT_MODE_DESIRE_NONE, "base_threatened"
	end
	-- Base siege (defend.lua Defend.GetBaseSiege, kept 10s after the last sighting): stay home.
	do
		local states = Fu.Utils.GameStates
		local siege = states ~= nil and states.baseSiege or nil
		if siege ~= nil and DotaTime() - siege.at <= 10 then
			if bot.tormentor_state == true and DotaTime() >= (bot._tormentorStayLogAt or -999) then
				bot._tormentorStayLogAt = DotaTime() + 10
				pcall(
					print,
					string.format(
						"[OHA-TORMENTOR] t=%.0f %s stay why=base-siege(%d)",
						DotaTime(),
						(string.gsub(bot:GetUnitName(), "npc_dota_hero_", "")),
						siege.n
					)
				)
			end
			return BOT_MODE_DESIRE_NONE, "base_siege"
		end
	end
	-- Not only the Ancient and T3s: a lane we should defend or enemy heroes at any of our towers
	-- or barracks keeps us home (game 036, bottom T2 lost at 31:18 during a Tormentor call).
	do
		local why = Fu.OurLaneThreatened()
		if why ~= nil then
			if bot.tormentor_state == true and DotaTime() >= (bot._tormentorStayLogAt or -999) then
				bot._tormentorStayLogAt = DotaTime() + 10
				pcall(
					print,
					string.format(
						"[OHA-TORMENTOR] t=%.0f %s stay why=%s",
						DotaTime(),
						(string.gsub(bot:GetUnitName(), "npc_dota_hero_", "")),
						why
					)
				)
			end
			return BOT_MODE_DESIRE_NONE, "lane_threatened"
		end
	end
	coreLevelSum = coreLevelSum / 3
	supportLevelSum = supportLevelSum / 2
	if supportLevelSum < 11 then
		return BOT_MODE_DESIRE_NONE, "supp_lvl_low"
	end
	local isGoodRightClickDamage = X.IsGoodRighClickDamage()
	if DotaTime() >= firstSpawnMinutes * 60 and DotaTime() - bot.tormentor_kill_time >= respawnMinutes * 60 then
		if not X.IsTormentorAlive() and bot.tormentor_state ~= true then
			if
				coreLevelSum >= 13
				and supportLevelSum >= 11
				and GetUnitToUnitDistance(bot, enemyAncient) > 4000
				and GetUnitToLocationDistance(bot, tormentorLocation) <= 9200
				and isGoodRightClickDamage
			then
				local closestBot = nil
				local closestDistance = 100000
				for i = 1, 5 do
					local member = GetTeamMember(i)
					if Fu.IsValidHero(member) and member:IsBot() then
						local distance = GetUnitToLocationDistance(member, tormentorLocation)
						if distance < closestDistance and (not Fu.IsCore(member) or distance < 2800) then
							closestBot = member
							closestDistance = distance
						end
					end
				end
				if closestBot ~= nil and bot == closestBot and bot.tormentor_state == false then
					if not bot:WasRecentlyDamagedByAnyHero(15) then
						return BOT_MODE_DESIRE_VERYHIGH, "scout_go"
					end
				end
			end
		else
			bot.tormentor_state = true
		end
	else
		bot.tormentor_state = false
	end
	if DotaTime() < tormentorCooldownUntil then
		bot.tormentor_state = false
		return BOT_MODE_DESIRE_NONE, "tormentor_cooldown"
	end
	if bot.tormentor_state == true and tormentorStartTime == 0 then
		tormentorStartTime = DotaTime()
	end
	if tormentorStartTime > 0 and DotaTime() - tormentorStartTime > tormentorTimeout then
		local tormentor = nil
		local neutralCreeps = bot:GetNearbyNeutralCreeps(1600)
		for _, creep in pairs(neutralCreeps) do
			if Fu.IsValid(creep) and Fu.IsTormentor(creep) then
				tormentor = creep
				break
			end
		end
		if tormentor == nil or Fu.GetHP(tormentor) > 0.3 then
			bot.tormentor_kill_time = DotaTime()
			bot.tormentor_state = false
			bot.tormentor_team_healthy = false
			tormentorStartTime = 0
			canDoTormentor = false
			return BOT_MODE_DESIRE_NONE, "tormentor_timeout"
		end
	end
	if bot.tormentor_state == false then
		tormentorStartTime = 0
	end
	if
		bot.tormentor_state == true
		and isGoodRightClickDamage
		and coreLevelSum >= 13
		and supportLevelSum >= 11
		and (not hasHumanAlly or hasHumanAlly and X.DidHumanPingedOrAtLocation())
		and (
			bot.tormentor_kill_time == 0 and aliveAllyCount >= 5
			or bot.tormentor_kill_time == 0 and aliveAllyCount >= 4 and coresNearTormentor >= 3 and supportsNearTormentor >= 1
			or bot.tormentor_kill_time > 0 and aliveAllyCount >= 3 and Fu.GetAliveAllyCoreCount() >= 2
			or alliesAttackingTormentor >= 2 and coresNearTormentor >= 2
		)
	then
		if bot.tormentor_state == true and bot.tormentor_team_healthy == false and bot == Fu.GetFirstBotInTeam() then
			if X.IsTeamHealthy() then
				bot.tormentor_team_healthy = true
			end
		end
		if bot.tormentor_team_healthy == false then
			return BOT_MODE_DESIRE_NONE, "team_not_healthy"
		end
		canDoTormentor = true
		if
			Fu.GetHP(bot) < 0.3
			and not bot:HasModifier("modifier_item_crimson_guard_extra")
			and Fu.IsTormentor(tormentorUnit)
		then
			local tormentorHp = Fu.GetHP(tormentorUnit)
			if tormentorHp > 0.15 and Fu.GetHP(bot) < tormentorHp then
				return BOT_MODE_DESIRE_NONE, "bot_low_hp"
			end
		end
		local desire = BOT_MODE_DESIRE_VERYHIGH
		if
			#alliesNearTormentor >= 2
			or #alliesNearWaitingSpot >= 2
			or coresNearTormentor >= 1
			or supportsNearTormentor >= 2
			or humansNearTormentor >= 1
		then
			desire = BOT_MODE_DESIRE_VERYHIGH
		else
			desire = BOT_MODE_DESIRE_HIGH
		end
		local nearbyEnemies = Fu.GetEnemiesNearLoc(bot:GetLocation(), 1200)
		return desire - #nearbyEnemies * BOT_MODE_DESIRE_VERYHIGH / 5, "do_tormentor"
	end
	if bot.tormentor_state == false then
		bot.tormentor_team_healthy = false
	end
	canDoTormentor = false
	return BOT_MODE_DESIRE_NONE, "state_false_or_conditions_unmet"
end
function Think()
	if Fu.CanNotUseAction(bot) then
		return
	end
	if
		bot.tormentor_state == true
		and GetUnitToLocationDistance(bot, tormentorLocation) > 800
		and GetUnitToLocationDistance(bot, tormentorLocation) < 1800
	then
		local laneCreeps = bot:GetNearbyLaneCreeps(Min(1600, bot:GetAttackRange() + 300), true)
		if Fu.IsValid(laneCreeps[1]) and Fu.CanBeAttacked(laneCreeps[1]) then
			bot:Action_AttackUnit(laneCreeps[1], false)
			return
		end
	end
	if bot.tormentor_state == true and not X.IsEnoughAllies(tormentorWaitingLocation, 1600) then
		if X.GetClosestBot() == bot and DotaTime() > lastScoutCheckTime + 15.0 then
			if GetUnitToLocationDistance(bot, tormentorLocation) <= 350 then
				local neutralCreeps = bot:GetNearbyNeutralCreeps(900)
				for i = #neutralCreeps, 1, -1 do
					if Fu.IsValid(neutralCreeps[i]) and string.find(neutralCreeps[i]:GetUnitName(), "miniboss") then
						lastScoutCheckTime = DotaTime()
						isTormentorSeen = true
					end
				end
				if not isTormentorSeen then
					bot.tormentor_kill_time = DotaTime()
					bot.tormentor_state = false
					isTormentorSeen = false
				end
			end
			bot:Action_MoveToLocation(tormentorLocation)
			return
		end
		-- Far from the Tormentor gather spot: TP or Twin Gate when clearly faster.
		if
			GetUnitToLocationDistance(bot, tormentorWaitingLocation) > 3000
			and ObjectiveTravel.Go(bot, tormentorWaitingLocation, "tormentor")
		then
			return
		end
		if DotaTime() >= nextWaitMoveTime then
			bot:Action_MoveToLocation(tormentorWaitingLocation + RandomVector(300))
			nextWaitMoveTime = DotaTime() + RandomFloat(0.05, 0.2)
			return
		end
	else
		if GetUnitToLocationDistance(bot, tormentorLocation) > bot:GetAttackRange() + 50 then
			if
				GetUnitToLocationDistance(bot, tormentorLocation) > 3000
				and ObjectiveTravel.Go(bot, tormentorLocation, "tormentor")
			then
				return
			end
			bot:Action_MoveToLocation(tormentorLocation)
			return
		else
			local neutralCreeps = bot:GetNearbyNeutralCreeps(900)
			for _, creep in pairs(neutralCreeps) do
				if Fu.IsValid(creep) and string.find(creep:GetUnitName(), "miniboss") then
					tormentorUnit = creep
					if GetUnitToUnitDistance(bot, creep) > bot:GetAttackRange() + 50 then
						bot:Action_MoveDirectly(tormentorLocation)
						return
					else
						if X.IsEnoughAllies(tormentorLocation, 900) or Fu.GetHP(creep) < 0.25 then
							bot:Action_AttackUnit(creep, true)
							return
						end
					end
					if Fu.GetFirstBotInTeam() == bot and canDoTormentor and DotaTime() > lastPingTime + 15 then
						lastPingTime = DotaTime()
						bot:ActionImmediate_Chat(Localization.Get("can_try_tormentor"), false)
						bot:ActionImmediate_Ping(creep:GetLocation().x, creep:GetLocation().y, true)
						return
					end
				end
			end
		end
	end
end
function X.IsTormentorAlive()
	if IsLocationVisible(tormentorLocation) then
		for i = 1, 5 do
			local member = GetTeamMember(i)
			if member ~= nil and member:IsAlive() then
				if GetUnitToLocationDistance(member, tormentorLocation) <= 350 then
					local neutralCreeps = member:GetNearbyNeutralCreeps(900)
					for j = #neutralCreeps, 1, -1 do
						if Fu.IsValid(neutralCreeps[j]) and string.find(neutralCreeps[j]:GetUnitName(), "miniboss") then
							return true
						end
					end
					member.tormentor_kill_time = DotaTime()
				end
			end
		end
	end
	return false
end
function X.IsEnoughAllies(location, radius)
	local alliesInRange = 0
	local coresInRange = 0
	local supportsInRange = 0
	for i = 1, 5 do
		local member = GetTeamMember(i)
		if member ~= nil and member:IsAlive() then
			if GetUnitToLocationDistance(member, location) <= radius then
				alliesInRange = alliesInRange + 1
				if Fu.IsCore(member) then
					coresInRange = coresInRange + 1
				else
					supportsInRange = supportsInRange + 1
				end
			end
		end
	end
	-- Acks: who the gather waits for. An ally counts when at the spot, in Tormentor mode (bots),
	-- or in the first 5s of the call. One that stayed in another mode after that declined, and
	-- the four-with-two-cores bar drops to the allies who are coming (a core busy elsewhere
	-- used to hold the whole group).
	if bot.tormentor_state then
		bot._tormentorCallAt = bot._tormentorCallAt or DotaTime()
	else
		bot._tormentorCallAt = nil
	end
	local callAge = DotaTime() - (bot._tormentorCallAt or DotaTime())
	local avail, availCores = 0, 0
	local declined = {}
	for i = 1, 5 do
		local member = GetTeamMember(i)
		if member ~= nil and member:IsAlive() then
			local here = GetUnitToLocationDistance(member, tormentorWaitingLocation) <= 1600
				or GetUnitToLocationDistance(member, tormentorLocation) <= 900
			if here or member == bot or (member:IsBot() and Fu.IsDoingTormentor(member)) or callAge < 5 then
				avail = avail + 1
				if Fu.IsCore(member) then
					availCores = availCores + 1
				end
			else
				declined[#declined + 1] = (string.gsub(member:GetUnitName(), "npc_dota_hero_", ""))
			end
		end
	end
	local needCores = math.min(2, math.max(1, availCores))
	local allComing = alliesInRange >= math.max(3, avail) and coresInRange >= needCores
	if radius >= 1600 and #declined > 0 and DotaTime() >= (bot._tormentorAckLogAt or -999) then
		bot._tormentorAckLogAt = DotaTime() + 10
		pcall(
			print,
			string.format(
				"[OHA-TORMENTOR] t=%.0f %s gather here=%d/%d cores=%d/%d declined=%s",
				DotaTime(),
				(string.gsub(bot:GetUnitName(), "npc_dota_hero_", "")),
				alliesInRange,
				avail,
				coresInRange,
				needCores,
				table.concat(declined, ",")
			)
		)
	end
	-- Four heroes with two cores waited ~75s for the fifth (28:00) while a creep wave grew on
	-- our high ground. Once four with two cores have been gathered for 20s, they start.
	-- One timer for the whole gather. Only the wide waiting-spot check (1600) resets it, so the
	-- closer check at the Tormentor (900) does not start a second 20s wait.
	if alliesInRange >= 4 and coresInRange >= 2 then
		bot._tormentorGatherSince = bot._tormentorGatherSince or DotaTime()
	elseif radius >= 1600 then
		bot._tormentorGatherSince = nil
	end
	local since = bot._tormentorGatherSince
	local waitedLong = since ~= nil and DotaTime() - since >= 20 and alliesInRange >= 4 and coresInRange >= 2
	return (
		bot.tormentor_kill_time == 0 and alliesInRange >= 5
		or bot.tormentor_kill_time == 0 and alliesInRange >= 4 and coresInRange >= 3 and supportsInRange >= 1
		or bot.tormentor_kill_time == 0 and waitedLong
		or bot.tormentor_kill_time > 0 and alliesInRange >= 3
		or allComing
	) and coresInRange >= needCores
end
function X.GetClosestBot()
	local alliesNearWaitingSpot = Fu.GetAlliesNearLoc(tormentorWaitingLocation, 2800)
	local closestBot = nil
	local closestScore = math.huge
	for _, allyHero in pairs(alliesNearWaitingSpot) do
		if Fu.IsValidHero(allyHero) and GetUnitToLocationDistance(allyHero, tormentorLocation) < 2000 then
			local distance = GetUnitToLocationDistance(allyHero, tormentorLocation)
			if closestScore > distance * (1 - Fu.GetHP(allyHero)) then
				closestScore = distance
				closestBot = allyHero
			end
		end
	end
	return closestBot
end
function X.IsTeamHealthy()
	local healthyCount = 0
	for i = 1, 5 do
		local member = GetTeamMember(i)
		if Fu.IsValid(member) and (Fu.GetHP(member) > 0.5 or not member:IsBot()) then
			healthyCount = healthyCount + 1
		end
	end
	return healthyCount >= Fu.GetNumOfAliveHeroes(false)
end
local bestRightClickDamage = {}
local lastThresholdChatTime = 0
function X.IsGoodRighClickDamage()
	if bot.tormentor_kill_time > 0 then
		return true
	end
	for i = 1, 5 do
		local member = GetTeamMember(i)
		if member ~= nil and member:CanBeSeen() and Fu.IsCore(member) and not Fu.DoesUnitHaveTemporaryBuff(member) then
			local position = Fu.GetPosition(member)
			local rightClickDamage = member:GetAttackDamage() * member:GetAttackSpeed()
			if position == 1 then
				rightClickDamage = rightClickDamage * 0.50
			elseif position == 2 then
				rightClickDamage = rightClickDamage * 0.25
			elseif position == 3 then
				rightClickDamage = rightClickDamage * 0.25
			end
			local playerId = member:GetPlayerID()
			if bestRightClickDamage[playerId] == nil then
				bestRightClickDamage[playerId] = 0
			end
			if bestRightClickDamage[playerId] < rightClickDamage then
				bestRightClickDamage[playerId] = rightClickDamage
			end
		end
	end
	local totalDamage = 0
	for _, damage in pairs(bestRightClickDamage) do
		totalDamage = totalDamage + damage
	end
	if
		not Fu.IsDoingTormentor(bot)
		and Fu.GetFirstBotInTeam() == bot
		and bot.tormentor_state == true
		and DotaTime() - lastThresholdChatTime < 30
		and totalDamage >= 500.0
	then
		bot:ActionImmediate_Chat("Tormentor threshold met..", false)
		lastThresholdChatTime = DotaTime()
	end
	return totalDamage >= 500.0
end
local humanPinged = false
function X.DidHumanPingedOrAtLocation()
	local humanPlayer, ping = Fu.GetHumanPing()
	if bot.tormentor_state == true and humanPlayer and ping and not humanPinged then
		if
			Fu.GetDistance(ping.location, tormentorWaitingLocation) <= 800
			or Fu.GetDistance(ping.location, tormentorLocation) <= 800
		then
			if GameTime() < ping.time + 15 then
				humanPinged = true
			end
		end
	end
	if bot.tormentor_state == false then
		humanPinged = false
	elseif bot.tormentor_state == true and humanPinged then
		return true
	end
	return false
end
if SafeCall then
	local getDesire = GetDesire
	local think = Think
	if getDesire then
		GetDesire = SafeCall(getDesire, 0, "WATCHER_GetDesire")
	end
	if think then
		Think = SafeCall(think, nil, "WATCHER_Think")
	end
end
