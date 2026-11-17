-- Gather the team before a push or fight.
local bot = GetBot()
if bot == nil or bot:IsInvulnerable() or not bot:IsHero() or not string.find(bot:GetUnitName(), "hero") or bot:IsIllusion() then
	return
end
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local Localization = require(GetScriptDirectory() .. "/FuncLib/systems/localization")
local HeroDisplayNames = require(GetScriptDirectory() .. "/FuncLib/data/hero_display_names")
local function getHeroDisplayName(unit)
	if unit == nil then
		return ""
	end
	local unitName = unit:GetUnitName()
	local locale = Localization.GetLocale()
	local localizedNames = HeroDisplayNames[locale] or HeroDisplayNames["en"]
	return localizedNames[unitName] or HeroDisplayNames["en"][unitName] or unitName
end
local function sayModeChat(chatKey, target, cooldown)
	if bot.lastModeChatTime == nil then
		bot.lastModeChatTime = {}
	end
	local lastChatTime = bot.lastModeChatTime[chatKey] or -999
	if GameTime() - lastChatTime < (cooldown or 30) then
		return
	end
	bot.lastModeChatTime[chatKey] = GameTime()
	local lines = Localization.Get(chatKey)
	if lines ~= nil and #lines > 0 then
		local line = lines[RandomInt(1, #lines)]
		if target then
			line = string.gsub(line, "{target}", getHeroDisplayName(target))
		end
		bot:ActionImmediate_Chat(line, false)
	end
end
local PING_MAX_AGE = 8
local ASSEMBLE_HOLD_SECONDS = 5
local ATTACK_HOLD_SECONDS = 6
local PING_DESIRE = 0.8
local HOLD_DESIRE = 0.4
local PING_ATTACK_DESIRE = 0.7
local HOLD_ATTACK_DESIRE = 0.4
local ARRIVE_DISTANCE = 50
local MAX_PING_DISTANCE = 2500
local PING_ENEMY_RADIUS = 500
local TARGET_LEASH_DISTANCE = 3000
local assembleLocation = nil
local holdUntil = 0
local pingTarget = nil
local pingLocation = nil
local groupUpAlly = nil
function GetDesire()
	if ShouldSkipBotThink(GetBot()) then
		return 0
	end
	if not bot:IsAlive() then
		return BOT_MODE_DESIRE_NONE
	end
	local pingingHuman, ping = Fu.GetHumanPing()
	if pingingHuman ~= nil and ping ~= nil and ping.normal_ping and ping.time ~= 0 and GameTime() - ping.time < PING_MAX_AGE then
		local distanceToPing = GetUnitToLocationDistance(bot, ping.location)
		if distanceToPing > ARRIVE_DISTANCE and distanceToPing < MAX_PING_DISTANCE then
			assembleLocation = ping.location
			pingLocation = ping.location
			pingTarget = FindEnemyAtPing()
			if pingTarget ~= nil then
				holdUntil = GameTime() + ATTACK_HOLD_SECONDS
				sayModeChat("say_assemble_attack", pingTarget, ASSEMBLE_HOLD_SECONDS)
			else
				holdUntil = GameTime() + ASSEMBLE_HOLD_SECONDS
				Fu.ModeAnnounce(bot, "say_assemble", ASSEMBLE_HOLD_SECONDS)
			end
			if bot:GetLevel() < 6 then
				local enemyTowers = bot:GetNearbyTowers(1000, true)
				if enemyTowers and #enemyTowers >= 1 then
					return BOT_MODE_DESIRE_NONE
				end
			end
			local baseDesire = pingTarget ~= nil and PING_ATTACK_DESIRE or PING_DESIRE
			return baseDesire * RemapValClamped(Fu.GetHP(bot), 0, 0.6, 0, 1)
		end
	end
	if assembleLocation ~= nil and GameTime() < holdUntil then
		if pingTarget ~= nil then
			if not Fu.IsValidHero(pingTarget) or not Fu.CanBeAttacked(pingTarget) then
				pingTarget = nil
				holdUntil = math.min(holdUntil, GameTime() + 2)
			else
				local targetDistanceFromPing = pingLocation and GetUnitToLocationDistance(pingTarget, pingLocation) or 0
				if targetDistanceFromPing < TARGET_LEASH_DISTANCE then
					holdUntil = math.max(holdUntil, GameTime() + 3)
				end
			end
		end
		if bot:WasRecentlyDamagedByAnyHero(2.0) and Fu.GetHP(bot) < 0.3 then
			assembleLocation = nil
			pingTarget = nil
			return BOT_MODE_DESIRE_NONE
		end
		if groupUpAlly ~= nil then
			return 0.1
		end
		if bot:GetLevel() < 6 then
			local enemyTowers = bot:GetNearbyTowers(1000, true)
			if enemyTowers and #enemyTowers >= 1 then
				return BOT_MODE_DESIRE_NONE
			end
		end
		local baseDesire = pingTarget ~= nil and HOLD_ATTACK_DESIRE or HOLD_DESIRE
		return baseDesire * RemapValClamped(Fu.GetHP(bot), 0, 0.6, 0, 1)
	end
	assembleLocation = nil
	pingTarget = nil
	pingLocation = nil
	if
		not Fu.IsInLaningPhase()
		and DotaTime() > 15 * 60
		and bot:GetActiveModeDesire() < 0.15
		and Fu.GetHP(bot) > 0.5
		and bot:DistanceFromFountain() > 3000
	then
		local bestAlly = nil
		local bestDistance = 99999
		local bestAllyGroupSize = 0
		for i = 1, #GetTeamPlayers(GetTeam()) do
			local teamMember = GetTeamMember(i)
			if teamMember ~= nil and teamMember:IsAlive() and teamMember ~= bot and not teamMember:IsIllusion() then
				local distanceToMember = GetUnitToLocationDistance(bot, teamMember:GetLocation())
				local alliesNearMember = Fu.GetAlliesNearLoc(teamMember:GetLocation(), 1600)
				local allyCount = 0
				for _, ally in pairs(alliesNearMember) do
					if Fu.IsValidHero(ally) and ally ~= bot then
						allyCount = allyCount + 1
					end
				end
				local memberDesire = teamMember:GetActiveModeDesire()
				if allyCount >= 2 and distanceToMember < bestDistance then
					bestAlly = teamMember
					bestDistance = distanceToMember
					bestAllyGroupSize = allyCount
				elseif bestAllyGroupSize < 2 and memberDesire > 0.15 and distanceToMember < bestDistance then
					bestAlly = teamMember
					bestDistance = distanceToMember
				end
			end
		end
		if bestAlly ~= nil and bestDistance > 600 and bestDistance < 8000 then
			groupUpAlly = bestAlly
			assembleLocation = bestAlly:GetLocation()
			holdUntil = GameTime() + 8
			return 0.1
		end
	end
	groupUpAlly = nil
	if
		Fu.GetHP(bot) > 0.5
		and Fu.IsLaning(bot)
		and not Fu.IsRetreating(bot)
		and not bot:WasRecentlyDamagedByAnyHero(2.0)
		and not Fu.IsGoingOnSomeone(bot)
		and not (Fu.IsValidHero(Fu.GetProperTarget(bot)) and bot:GetActiveMode() == BOT_MODE_ATTACK)
		and not Fu.IsInTeamFight(bot, 1200)
	then
		local nearbyAllies = bot:GetNearbyHeroes(1600, false, BOT_MODE_NONE) or {}
		for _, ally in pairs(nearbyAllies) do
			if ally ~= bot and Fu.IsValidHero(ally) and Fu.IsGoingOnSomeone(ally) then
				local allyTarget = Fu.GetProperTarget(ally)
				if
					Fu.IsValidHero(allyTarget)
					and Fu.CanBeAttacked(allyTarget)
					and not Fu.IsSuspiciousIllusion(allyTarget)
					and GetUnitToUnitDistance(bot, allyTarget) < 1200
					and Fu.WeAreStronger(bot, 1200)
				then
					pingTarget = allyTarget
					assembleLocation = allyTarget:GetLocation()
					holdUntil = GameTime() + 3
					bot:SetTarget(allyTarget)
					return RemapValClamped(Fu.GetHP(bot), 0.2, 0.8, 0, HOLD_ATTACK_DESIRE)
				end
			end
		end
	end
	return BOT_MODE_DESIRE_NONE
end
function OnEnd()
	assembleLocation = nil
	holdUntil = 0
	pingTarget = nil
	pingLocation = nil
	groupUpAlly = nil
end
function FindEnemyAtPing()
	if assembleLocation == nil then
		return nil
	end
	local nearbyEnemies = Fu.GetEnemiesNearLoc(assembleLocation, PING_ENEMY_RADIUS)
	for _, enemyHero in pairs(nearbyEnemies) do
		if Fu.IsValidHero(enemyHero) and Fu.CanBeAttacked(enemyHero) then
			return enemyHero
		end
	end
	return nil
end
function Think()
	if Fu.CanNotUseAction(bot) then
		return
	end
	if assembleLocation == nil then
		return
	end
	if pingTarget ~= nil and Fu.IsValidHero(pingTarget) and Fu.CanBeAttacked(pingTarget) then
		assembleLocation = pingTarget:GetLocation()
		local targetDistance = GetUnitToUnitDistance(bot, pingTarget)
		if targetDistance <= bot:GetAttackRange() + 200 then
			bot:Action_AttackUnit(pingTarget, true)
		else
			bot:Action_MoveToLocation(pingTarget:GetLocation() + RandomVector(50))
		end
		return
	end
	pingTarget = nil
	if groupUpAlly ~= nil then
		if not Fu.IsValidHero(groupUpAlly) or not groupUpAlly:IsAlive() then
			groupUpAlly = nil
			assembleLocation = nil
			return
		end
		assembleLocation = groupUpAlly:GetLocation()
		local distanceToAlly = GetUnitToUnitDistance(bot, groupUpAlly)
		if distanceToAlly <= 600 then
			groupUpAlly = nil
			assembleLocation = nil
			return
		end
		local nearbyLaneCreeps = bot:GetNearbyLaneCreeps(bot:GetAttackRange() + 200, true)
		if
			Fu.IsValid(nearbyLaneCreeps[1])
			and Fu.CanBeAttacked(nearbyLaneCreeps[1])
			and Fu.CanKillTarget(nearbyLaneCreeps[1], bot:GetAttackDamage(), DAMAGE_TYPE_PHYSICAL)
		then
			bot:Action_AttackUnit(nearbyLaneCreeps[1], true)
			return
		end
		bot:Action_MoveToLocation(assembleLocation + RandomVector(50))
		return
	end
	local distanceToTarget = GetUnitToLocationDistance(bot, assembleLocation)
	if distanceToTarget <= ARRIVE_DISTANCE then
		assembleLocation = nil
		return
	end
	if distanceToTarget > 4000 and not bot:IsChanneling() then
		local tpScroll = Fu.IsItemAvailable("item_tpscroll")
		if Fu.CanCastAbility(tpScroll) then
			local nearestTower = nil
			local nearestDistance = 99999
			for _, towerId in pairs({
				TOWER_TOP_1,
				TOWER_TOP_2,
				TOWER_TOP_3,
				TOWER_MID_1,
				TOWER_MID_2,
				TOWER_MID_3,
				TOWER_BOT_1,
				TOWER_BOT_2,
				TOWER_BOT_3,
			}) do
				local tower = GetTower(GetTeam(), towerId)
				if tower ~= nil and tower:IsAlive() then
					local towerDistance = GetUnitToLocationDistance(tower, assembleLocation)
					if towerDistance < nearestDistance then
						nearestDistance = towerDistance
						nearestTower = tower
					end
				end
			end
			if nearestTower ~= nil and nearestDistance < 3000 then
				log(
					"[TP] %s t=%.0f ASSEMBLE tp to building at (%.0f,%.0f)",
					bot:GetUnitName(),
					DotaTime(),
					nearestTower:GetLocation().x,
					nearestTower:GetLocation().y
				)
				bot:Action_UseAbilityOnLocation(tpScroll, nearestTower:GetLocation())
				return
			end
		end
	end
	bot:Action_MoveToLocation(assembleLocation + RandomVector(50))
end
-- Hold the desire through short dips while this mode is active (FuncLib/systems/mode_hold.lua).
GetDesire = require(GetScriptDirectory() .. "/FuncLib/systems/mode_hold").Wrap(GetDesire, "assemble", BOT_MODE_ASSEMBLE)
if SafeCall then
	local originalGetDesire = GetDesire
	local originalThink = Think
	if originalGetDesire then
		GetDesire = SafeCall(originalGetDesire, 0, "ASSEMBLE_GetDesire")
	end
	if originalThink then
		Think = SafeCall(originalThink, nil, "ASSEMBLE_Think")
	end
end
