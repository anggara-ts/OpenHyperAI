-- Roam with teammates to gank.
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
local Utils = require(GetScriptDirectory() .. "/FuncLib/systems/utils")
local EnemyRoleEstimation = require(GetScriptDirectory() .. "/FuncLib/hero/enemy_role_estimation")
local Localization = require(GetScriptDirectory() .. "/FuncLib/systems/localization")
local CustomLoader = require(GetScriptDirectory() .. "/FuncLib/systems/custom_loader")
CustomLoader.ThinkLess = CustomLoader.Enable and CustomLoader.ThinkLess or 1
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local Item = require(GetScriptDirectory() .. "/FuncLib/systems/item")
local Role = require(GetScriptDirectory() .. "/FuncLib/systems/role")
local SpecialUnits = require(GetScriptDirectory() .. "/FuncLib/hero/special_units")
local TeamRoam = {}
local team = GetTeam()
local engageTarget = nil
local isAttackingTowerCreep, towerCreepTarget = false, nil
local towerCreepStartTime, towerCreepDuration = 0, 0
local spareDuration = 15
local roleInitialized, isSupport, isCore, isPvNMode = false, false, false, false
local hasSpecialUnitTarget = false
local lastIdleCheckTime, isIdle = -1, false
local isHelpingAlly, isHelpingCore = false, false
local alliesNear, enemiesNear
local isAvoidingTower = false
local towerAvoidLocation = nil
local towerAvoidUntil = 0
local towerAvoidDuration = 3
local itemToPickUp = nil
local minPickupItemCost = 200
local ignoredItems, pickupAttempts = {}, 0
local lastItemScanTime = -90
local lastCheeseSwapTime = -90
local lastClaritySwapTime = -90
local lastFlaskSwapTime = -90
local lastRefresherShardSwapTime = -90
local lastMoonShardSwapTime = -90
local lastSellCheckTime = 0
local shouldAvoidEffects = false
local isEscapingTower = false
local towerEscapeUntil = 0
local towerEscapeDuration = 2
local towerEscapeLocation = nil
local lastHitCreep = nil
local engageTargetHoldTime = 1.2
local engageTargetLockedUntil = -90
local function setEngageTarget(target)
	if target == nil then
		return
	end
	if engageTarget ~= nil and engageTarget ~= target and DotaTime() < engageTargetLockedUntil then
		return
	end
	engageTarget = target
	bot:SetTarget(target)
	engageTargetLockedUntil = DotaTime() + engageTargetHoldTime
end
-- Drop sticky chase when outnumbered / alone after enemy backup arrives.
local function ShouldAbortStickyEngage(bot, target)
	if not Fu.IsValidHero(target) then
		return true
	end
	-- Finish a one-hit kill even when more enemies are nearby.
	if Fu.ShouldFinishCommittedKill(bot, target) then
		return false
	end
	local allies = Fu.GetAllyCount(bot, 1400)
	local enemies = Fu.GetEnemyCount(bot, 1400)
	local lastSeen = Fu.GetLastSeenEnemiesNearLoc and Fu.GetLastSeenEnemiesNearLoc(bot:GetLocation(), 2000) or {}
	local pressure = math.max(enemies, #lastSeen)
	if allies <= 1 and pressure >= 2 then
		return true
	end
	if pressure >= allies + 1 and not Fu.WeAreStronger(bot, 1400) then
		return true
	end
	return false
end
local function ClearEngageTarget()
	engageTarget = nil
	engageTargetLockedUntil = -90
	bot:SetTarget(nil)
end
local function adjustDesire(desire)
	if Fu.IsPushing(bot) then
		if desire > 0.6 then
			return 0.5
		end
	end
	if Fu.IsInLaningPhase() then
		if desire > 0.9 then
			return 0.72
		end
	end
	return desire
end
function GetDesire()
	local botMode = bot:GetActiveMode()
	if
		DotaTime() > 0
		and (
			botMode == BOT_MODE_ITEM
			or BOT_MODE_WISDOM_SHRINE and botMode == BOT_MODE_WISDOM_SHRINE
			or BOT_MODE_LOTUS_POOL and botMode == BOT_MODE_LOTUS_POOL
		)
	then
		if bot._stuckModeTime == nil then
			bot._stuckModeTime = DotaTime()
		end
		if DotaTime() - bot._stuckModeTime > 5 then
			if not bot._stuckUnsticking then
				local traceOk, trace = pcall(require, GetScriptDirectory() .. "/FuncLib/systems/match_trace")
				if traceOk and trace.Event then
					trace.Event(bot, "stuck", "held item/shrine/lotus mode for 5s, leaving it")
				end
			end
			bot._stuckUnsticking = true
			local enemyHeroes = bot:GetNearbyHeroes(1200, true, BOT_MODE_NONE) or {}
			if #enemyHeroes > 0 then
				return 0.85
			end
			return 0.8
		end
	else
		bot._stuckModeTime = nil
		bot._stuckUnsticking = false
	end
	if ShouldSkipBotThink(GetBot()) then
		return 0
	end
	if Fu.GetEnemiesAroundAncient(bot, 3200) > 0 then
		return BOT_MODE_DESIRE_NONE
	end
	if bot:WasRecentlyDamagedByTower(3.0) then
		local enemyAncient = GetAncient(GetOpposingTeam())
		if enemyAncient ~= nil and GetUnitToUnitDistance(bot, enemyAncient) < 3000 then
			return BOT_MODE_DESIRE_NONE
		end
	end
	local desire = GetDesireHelper()
	desire = adjustDesire(desire)
	return desire
end
function GetDesireHelper()
	local hpRatio = Fu.GetHP(bot)
	isAvoidingTower = false
	hasSpecialUnitTarget = false
	if bot:IsInvulnerable() or not bot:IsHero() or not bot:IsAlive() or not string.find(botName, "hero") or bot:IsIllusion() then
		return BOT_MODE_DESIRE_NONE
	end
	local dropDesire = Item.RoshanDropDesire(bot)
	if dropDesire > 0 then
		return dropDesire
	end
	if Fu.IsInLaningPhase() then
		if DotaTime() < towerAvoidUntil and towerAvoidLocation ~= nil then
			isAvoidingTower = true
			return bot:GetActiveModeDesire() + 0.05
		end
		if bot:GetActiveMode() == BOT_MODE_WATCHER then
			local enemyTowers = bot:GetNearbyTowers(1000, true)
			if Fu.IsValidBuilding(enemyTowers[1]) then
				local towerDistance = GetUnitToUnitDistance(bot, enemyTowers[1])
				if towerDistance < 1200 then
					isAvoidingTower = true
					towerAvoidLocation = Fu.AdjustLocationWithOffsetTowardsFountain(enemyTowers[1]:GetLocation(), 1200)
					towerAvoidUntil = DotaTime() + towerAvoidDuration
					return bot:GetActiveModeDesire() + 0.05
				end
			end
		end
	end
	Utils.SetFrameProcessTime(bot)
	EnemyRoleEstimation.UpdateEnemyHeroPositions()
	shouldAvoidEffects = false
	bot.laneToPush = Fu.GetMostPushLaneDesire()
	bot.laneToDefend = Fu.GetMostDefendLaneDesire()
	if DotaTime() - lastIdleCheckTime >= 1 or isIdle then
		isIdle = Fu.CheckBotIdleState()
		lastIdleCheckTime = DotaTime()
	end
	if not roleInitialized then
		roleInitialized = true
		isPvNMode = Fu.Role.IsPvNMode()
		isCore = Fu.IsCore(bot)
		isSupport = not isCore
	end
	ItemOpsDesire()
	local helpTarget
	if not Fu.IsInLaningPhase() then
		helpTarget, isHelpingCore = TeamRoam.ConsiderHelpWhenCoreIsTargeted()
		if isHelpingCore and Fu.IsValidHero(helpTarget) then
			local distance = GetUnitToUnitDistance(bot, helpTarget)
			if distance < 3000 or Fu.GetHP(helpTarget) < 0.3 then
				setEngageTarget(helpTarget)
				engageTarget = helpTarget
				local maxDesire = RemapValClamped(distance, 1000, 4000, 0.85, 0.4)
				return RemapValClamped(hpRatio, 0.25, 0.7, BOT_MODE_DESIRE_NONE, maxDesire)
			end
		end
	end
	alliesNear = Fu.GetAlliesNearLoc(bot:GetLocation(), 2200)
	enemiesNear = Fu.GetEnemiesNearLoc(bot:GetLocation(), 2000)
	if not Fu.IsInLaningPhase() then
		helpTarget, isHelpingAlly = ConsiderHelpAlly()
		if isHelpingAlly then
			setEngageTarget(helpTarget)
			engageTarget = helpTarget
			return RemapValClamped(hpRatio, 0.3, 0.7, BOT_MODE_DESIRE_NONE, 0.4)
		end
	end
	isEscapingTower = false
	if Fu.IsLaning(bot) then
		if DotaTime() < towerEscapeUntil and towerEscapeLocation ~= nil then
			isEscapingTower = true
			return 0.7
		end
		local enemyTowers = bot:GetNearbyTowers(900, true)
		if Fu.IsValidBuilding(enemyTowers[1]) then
			local towerTarget = enemyTowers[1]:GetAttackTarget()
			local allyCreeps = bot:GetNearbyLaneCreeps(900, false)
			local properTarget = Fu.GetProperTarget(bot)
			if
				towerTarget == bot
				or #allyCreeps == 0
					and (bot:WasRecentlyDamagedByTower(2.0) or Fu.IsValidHero(properTarget) and Fu.IsRecklesslyDivingTower(bot, properTarget))
			then
				isEscapingTower = true
				towerEscapeLocation = Fu.AdjustLocationWithOffsetTowardsFountain(enemyTowers[1]:GetLocation(), 1200)
				towerEscapeUntil = DotaTime() + towerEscapeDuration
				return 0.7
			end
		end
	end
	if hpRatio > 0.3 then
		lastHitCreep = TeamRoam.GetLastHitCreep()
		if Fu.IsValid(lastHitCreep) and Fu.CanBeAttacked(lastHitCreep) then
			return BOT_DESIRE_OVERRIDE * 1.5
		end
	end
	if not bot:IsAlive() or bot:GetCurrentActionType() == BOT_ACTION_TYPE_DELAY then
		return BOT_MODE_DESIRE_NONE
	end
	if botName == "npc_dota_hero_lone_druid" or bot.isBear and botName == "npc_dota_hero_lone_druid_bear" then
		local loneDruid = Utils.GetLoneDruid(bot)
		local bearItemsMap = loneDruid and loneDruid.bearItemsMap
		if
			bearItemsMap
			and loneDruid.hero
			and loneDruid.bear
			and Fu.IsValidHero(loneDruid.hero)
			and loneDruid.hero:IsAlive()
			and Fu.IsValidHero(loneDruid.bear)
			and loneDruid.bear:IsAlive()
			and bot:DistanceFromFountain() > 3000
		then
			local enemyHeroes = Fu.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE) or {}
			if #enemyHeroes == 0 and not Fu.IsInTeamFight(bot, 1200) then
				local hasItemToTransfer = false
				for slot = 0, 8 do
					local item = loneDruid.hero:GetItemInSlot(slot)
					if item ~= nil and bearItemsMap[item:GetName()] and loneDruid.bear:FindItemSlot(item:GetName()) < 0 then
						hasItemToTransfer = true
						break
					end
				end
				if not hasItemToTransfer then
					for _, droppedItem in pairs(GetDroppedItemList()) do
						if droppedItem and droppedItem.item and droppedItem.owner == loneDruid.hero and not string.find(droppedItem.item:GetName(), "token") then
							hasItemToTransfer = true
							break
						end
					end
				end
				if hasItemToTransfer then
					bot._ldItemTransfer = true
					return 0.6
				end
			end
		end
		bot._ldItemTransfer = false
	end
	if bot.isBear or botName == "npc_dota_hero_lone_druid_bear" then
		bot._bearFollowHero = false
		local loneDruid = Utils.GetLoneDruid(bot)
		local hasScepter = bot:HasModifier("modifier_item_ultimate_scepter_consumed")
			or bot:FindItemSlot("item_ultimate_scepter") >= 0
		if not loneDruid or not loneDruid.hero or not Fu.IsValidHero(loneDruid.hero) or not loneDruid.hero:IsAlive() then
		elseif hasScepter then
			local bearItemsMap = loneDruid.bearItemsMap
			local hasItemToTransfer = false
			if bearItemsMap then
				for slot = 0, 8 do
					local item = loneDruid.hero:GetItemInSlot(slot)
					if item ~= nil and bearItemsMap[item:GetName()] and bot:FindItemSlot(item:GetName()) < 0 then
						hasItemToTransfer = true
						break
					end
				end
			end
			if hasItemToTransfer then
				local heroDistance = GetUnitToUnitDistance(bot, loneDruid.hero)
				if heroDistance > 700 then
					bot._bearFollowHero = true
					return 0.5
				end
			end
		else
			local heroDistance = GetUnitToUnitDistance(bot, loneDruid.hero)
			local bearHp = Fu.GetHP(bot)
			if bearHp < 0.3 then
				bot._bearFollowHero = false
			elseif heroDistance > 990 then
				bot._bearFollowHero = true
				return 0.6
			end
			local heroMode = loneDruid.hero:GetActiveMode()
			if
				(heroMode == BOT_MODE_FARM or heroMode == BOT_MODE_ROSHAN or heroMode == BOT_MODE_SIDE_SHOP or heroMode == BOT_MODE_WATCHER)
				and heroDistance > 700
			then
				bot._bearFollowHero = true
				return 0.5
			end
		end
	end
	local specialUnitDesire = SpecialUnits.GetDesire(bot)
	if specialUnitDesire > 0 then
		hasSpecialUnitTarget = true
		-- Deward / serpent-escape / high-priority specials: keep desire even if HP isn't full.
		if specialUnitDesire >= 0.95 then
			return specialUnitDesire
		end
		return RemapValClamped(hpRatio, 0.1, 0.8, BOT_MODE_DESIRE_NONE, specialUnitDesire)
	end
	if Fu.IsInLaningPhase() and bot:HasModifier("modifier_warlock_upheaval") then
		shouldAvoidEffects = true
		return BOT_ACTION_DESIRE_VERYHIGH + 0.1
	end
	if HasModifierThatNeedToAvoidEffects() then
		shouldAvoidEffects = true
		return RemapValClamped(hpRatio, 0.3, 1, BOT_ACTION_DESIRE_VERYHIGH, BOT_ACTION_DESIRE_NONE)
	end
	if
		not Fu.IsFarming(bot)
		and not Fu.IsPushing(bot)
		and not Fu.IsDefending(bot)
		and not Fu.IsDoingRoshan(bot)
		and not Fu.IsDoingTormentor(bot)
		and bot:GetActiveMode() ~= BOT_MODE_RUNE
		and bot:GetActiveMode() ~= BOT_MODE_SECRET_SHOP
		and bot:GetActiveMode() ~= BOT_MODE_OUTPOST
		and bot:GetActiveMode() ~= BOT_MODE_WARD
		and bot:GetActiveMode() ~= BOT_MODE_ATTACK
		and bot:GetActiveMode() ~= BOT_MODE_DEFEND_ALLY
		and bot:GetActiveMode() ~= BOT_MODE_ROAM
	then
		return BOT_ACTION_DESIRE_NONE
	elseif #alliesNear >= #enemiesNear then
		local maxDesire = BOT_MODE_DESIRE_VERYHIGH + 0.04
		if isCore then
			local attackTarget, targetDesire = TeamRoam.CarryFindTarget()
			if attackTarget ~= nil then
				engageTarget = attackTarget
				bot:SetTarget(attackTarget)
				local clampedDesire = RemapValClamped(hpRatio, 0, 0.4, BOT_MODE_DESIRE_NONE, targetDesire)
				return Clamp(clampedDesire, 0, maxDesire)
			end
		end
		if isSupport then
			local attackTarget, targetDesire = TeamRoam.SupportFindTarget()
			if attackTarget ~= nil then
				engageTarget = attackTarget
				bot:SetTarget(attackTarget)
				local clampedDesire = RemapValClamped(hpRatio, 0, 0.4, BOT_MODE_DESIRE_NONE, targetDesire)
				return Clamp(clampedDesire, 0, maxDesire)
			end
		end
		if bot:IsAlive() and bot:DistanceFromFountain() > 4600 then
			if towerCreepStartTime ~= 0 and TeamRoam.IsValid(towerCreepTarget) and DotaTime() < towerCreepStartTime + towerCreepDuration then
				return BOT_MODE_DESIRE_VERYHIGH
			else
				towerCreepStartTime, isAttackingTowerCreep = 0, false
			end
			towerCreepDuration, towerCreepTarget = TeamRoam.ShouldAttackTowerCreep(bot)
			if towerCreepDuration ~= 0 and towerCreepTarget ~= nil then
				if towerCreepStartTime == 0 then
					towerCreepStartTime = DotaTime()
					isAttackingTowerCreep = true
				end
				bot:SetTarget(towerCreepTarget)
				return BOT_MODE_DESIRE_VERYHIGH
			end
		end
	end
	return 0.0
end
function TeamRoam.GetLastHitCreep()
	if Fu.IsRetreating(bot) or not Fu.IsCore(bot) and Fu.IsThereCoreNearby(800) or Fu.IsInTeamFight(bot, 1200) then
		return nil
	end
	local enemyTowers = bot:GetNearbyTowers(1000, true)
	local enemyCreeps = bot:GetNearbyCreeps(1200, true)
	for _, creep in pairs(enemyCreeps) do
		if
			Fu.IsValid(creep)
			and Fu.CanBeAttacked(creep)
			and Fu.IsInRange(bot, creep, bot:GetAttackRange() + 300)
			and not Fu.IsRoshan(creep)
			and not Fu.IsTormentor(creep)
		then
			local attackDelay = Fu.GetAttackProDelayTime(bot, creep)
			if
				Fu.WillKillTarget(creep, bot:GetAttackDamage() - 1, DAMAGE_TYPE_PHYSICAL, attackDelay)
				and (#enemyTowers == 0 or Fu.IsValidBuilding(enemyTowers[1]) and not Fu.IsInRange(creep, enemyTowers[1], 750))
			then
				local alliesNearCreep = Fu.GetAlliesNearLoc(creep:GetLocation(), 1000)
				local enemiesNearCreep = Fu.GetEnemiesNearLoc(creep:GetLocation(), 1000)
				if #alliesNearCreep >= #enemiesNearCreep then
					return creep
				end
			end
		end
	end
	return nil
end
function HasModifierThatNeedToAvoidEffects()
	return bot:HasModifier("modifier_jakiro_macropyre_burn")
		or bot:HasModifier("modifier_dark_seer_wall_slow")
		or (
				bot:HasModifier("modifier_sandking_sand_storm_slow") or bot:HasModifier("modifier_sand_king_epicenter_slow")
			)
			and (not bot:HasModifier("modifier_black_king_bar_immune") or not bot:HasModifier("modifier_magic_immune") or not bot:HasModifier(
				"modifier_omniknight_repel"
			))
end
function ConsiderHelpAlly()
	if Fu.GetHP(bot) < 0.5 then
		return nil, false
	end
	if bot:WasRecentlyDamagedByAnyHero(2.0) and Fu.GetHP(bot) < 0.6 then
		return nil, false
	end
	local searchRange = 3500
	local modeDesire = bot:GetActiveModeDesire()
	local ally = Fu.GetClosestAlly(bot, searchRange)
	if
		ally ~= nil
		and Fu.GetHP(bot) >= Fu.GetHP(ally)
		and (not Fu.IsCore(bot) or Fu.IsCore(bot) and (not Fu.IsInLaningPhase() or Fu.IsInRange(bot, ally, 1600)))
		and not Fu.IsGoingOnSomeone(bot)
		and not (Fu.IsRetreating(bot) and modeDesire > 0.8)
	then
		local alliesNearAlly = Fu.GetAlliesNearLoc(ally:GetLocation(), 1200)
		local enemiesNearAlly = Fu.GetEnemiesNearLoc(ally:GetLocation(), 1600)
		if #enemiesNearAlly > #alliesNearAlly + 1 then
			return nil, false
		end
		for _, enemyHero in pairs(enemiesNearAlly) do
			if Fu.IsValidHero(enemyHero) and GetUnitToUnitDistance(enemyHero, ally) <= 1600 and #alliesNearAlly + 1 >= #enemiesNearAlly then
				if enemyHero:GetAttackTarget() == ally or Fu.IsChasingTarget(enemyHero, ally) or ally:WasRecentlyDamagedByHero(enemyHero, 2.5) then
					return enemyHero, true
				end
			end
		end
	end
	return nil, false
end
function OnStart() end
function OnEnd()
	towerCreepStartTime = 0
	isAttackingTowerCreep = false
	itemToPickUp = nil
end
function Think()
	if bot._stuckUnsticking then
		local enemyHeroes = bot:GetNearbyHeroes(1200, true, BOT_MODE_NONE) or {}
		if #enemyHeroes > 0 and Fu.IsValidHero(enemyHeroes[1]) and Fu.CanBeAttacked(enemyHeroes[1]) then
			bot:Action_AttackUnit(enemyHeroes[1], false)
			bot._stuckModeTime = nil
			bot._stuckUnsticking = false
			return
		end
		local lane = bot:GetAssignedLane() or LANE_MID
		bot:Action_MoveToLocation(GetLaneFrontLocation(GetTeam(), lane, 0))
		bot._stuckModeTime = nil
		bot._stuckUnsticking = false
		return
	end
	if Fu.CanNotUseAction(bot) then
		return
	end
	if Item.TryPickupRoshanDrop(bot) then
		return
	end
	if isAvoidingTower and towerAvoidLocation ~= nil then
		bot:Action_MoveToLocation(towerAvoidLocation + RandomVector(50))
		return
	end
	if bot._bearFollowHero then
		local loneDruid = Utils.GetLoneDruid(bot)
		if loneDruid and loneDruid.hero and Fu.IsValidHero(loneDruid.hero) and loneDruid.hero:IsAlive() then
			local heroTarget = Fu.GetProperTarget(loneDruid.hero)
			if Fu.IsValid(heroTarget) and Fu.CanBeAttacked(heroTarget) then
				local distance = GetUnitToUnitDistance(bot, heroTarget)
				local heroDistance = GetUnitToUnitDistance(bot, loneDruid.hero)
				if distance < 1000 and heroDistance < 900 then
					bot:Action_AttackUnit(heroTarget, true)
					return
				end
			end
			bot:Action_MoveToLocation(loneDruid.hero:GetLocation())
			return
		end
	end
	ItemOpsThink()
	if Fu.IsValid(lastHitCreep) then
		bot:Action_AttackUnit(lastHitCreep, true)
		return
	end
	if engageTarget ~= nil then
		if not Fu.Utils.IsValidUnit(engageTarget) or not TeamRoam.CanBeAttacked(engageTarget) then
			engageTarget = nil
		end
	end
	if shouldAvoidEffects then
		bot:Action_MoveToLocation(
			Utils.GetOffsetLocationTowardsTargetLocation(bot:GetLocation(), Fu.GetTeamFountain(), 600) + RandomVector(200)
		)
		return
	end
	if isEscapingTower then
		if towerEscapeLocation ~= nil then
			bot:Action_MoveToLocation(towerEscapeLocation)
			return
		end
		local enemyTowers = bot:GetNearbyTowers(900, true)
		if Fu.IsValidBuilding(enemyTowers[1]) then
			bot:Action_MoveToLocation(Fu.AdjustLocationWithOffsetTowardsFountain(enemyTowers[1]:GetLocation(), 900))
			return
		end
	end
	if bot._ldItemTransfer then
		local loneDruid = Utils.GetLoneDruid(bot)
		local bearItemsMap = loneDruid and loneDruid.bearItemsMap
		if bearItemsMap and loneDruid.hero and loneDruid.bear and Fu.IsValidHero(loneDruid.hero) and Fu.IsValidHero(loneDruid.bear) then
			if bot.isBear then
				for _, droppedItem in pairs(GetDroppedItemList()) do
					if droppedItem and droppedItem.item and droppedItem.owner == loneDruid.hero and not string.find(droppedItem.item:GetName(), "token") then
						local distance = GetUnitToLocationDistance(bot, droppedItem.location)
						if distance <= 100 then
							bot:Action_PickUpItem(droppedItem.item)
							return
						elseif distance < 800 then
							bot:Action_MoveToLocation(droppedItem.location)
							return
						end
					end
				end
				local heroDistance = GetUnitToUnitDistance(bot, loneDruid.hero)
				if heroDistance > 250 then
					bot:Action_MoveToLocation(loneDruid.hero:GetLocation())
					return
				end
			else
				local bearDistance = GetUnitToUnitDistance(bot, loneDruid.bear)
				if bearDistance > 400 then
					bot:Action_MoveToLocation(loneDruid.bear:GetLocation())
					return
				end
				for slot = 0, 8 do
					local item = bot:GetItemInSlot(slot)
					if item ~= nil and bearItemsMap[item:GetName()] and loneDruid.bear:FindItemSlot(item:GetName()) < 0 then
						bot:Action_DropItem(item, loneDruid.bear:GetLocation())
						return
					end
				end
			end
		end
	end
	if hasSpecialUnitTarget then
		if Fu.IsValid(bot.special_unit_target) then
			bot:Action_AttackUnit(bot.special_unit_target, false)
			return
		end
	end
	if isAttackingTowerCreep then
		bot:Action_AttackUnit(towerCreepTarget, false)
		return
	end
	if isIdle then
		isIdle = Fu.CheckBotIdleState()
	end
	if Fu.Utils.IsValidUnit(engageTarget) and (isHelpingAlly or isCore or isSupport) then
		if Fu.IsValidHero(engageTarget) and ShouldAbortStickyEngage(bot, engageTarget) then
			ClearEngageTarget()
			return
		end
		local distance = GetUnitToUnitDistance(bot, engageTarget)
		local attackRange = bot:GetAttackRange()
		if attackRange >= 400 and distance > attackRange + 100 then
			local attackLocation = Fu.VectorTowards(engageTarget:GetLocation(), bot:GetLocation(), attackRange - 50)
			bot:Action_MoveToLocation(attackLocation)
		else
			bot:Action_AttackUnit(engageTarget, false)
		end
		return
	end
end
function TeamRoam.SupportFindTarget()
	local hpRatio = Fu.GetHP(bot)
	if TeamRoam.CanNotUseAttack(bot) or DotaTime() < 0 then
		return nil, 0
	end
	local enemyTowers = bot:GetNearbyTowers(800, true)
	if Fu.IsValidBuilding(enemyTowers[1]) then
		local properTarget = Fu.GetProperTarget(bot)
		if Fu.IsValidHero(properTarget) and Fu.IsRecklesslyDivingTower(bot, properTarget) then
			return nil, 0
		end
	end
	local canHitCreep = TeamRoam.IsModeSuitToHitCreep(bot)
	local attackRange = math.min(bot:GetAttackRange() + 50, 1200)
	local target = Fu.GetProperTarget(bot)
	local botMode = bot:GetActiveMode()
	local botLevel = bot:GetLevel()
	local attackDamage = bot:GetAttackDamage()
	local creepDamage = TeamRoam.GetAttackDamageToCreep(bot) - 1
	if TeamRoam.CanBeAttacked(target) and target == engageTarget and GetUnitToUnitDistance(bot, target) <= 1600 then
		if target:GetTeam() == bot:GetTeam() then
			if target:GetHealth() > TeamRoam.GetLastHitHealth(bot, target) then
				return target, BOT_MODE_DESIRE_VERYHIGH * 1.08
			end
			return target, BOT_MODE_DESIRE_VERYHIGH * 1.04
		end
		if target:IsCourier() and GetUnitToUnitDistance(bot, target) <= attackRange + 300 and hpRatio > 0.3 and not Fu.IsRetreating(bot) then
			return target, BOT_DESIRE_OVERRIDE * 1.5
		end
		if target:IsHero() and not Fu.IsInLaningPhase() and (bot:GetCurrentMovementSpeed() < 300 or botLevel >= 25) then
			if ShouldAbortStickyEngage(bot, target) then
				ClearEngageTarget()
				return nil, 0
			end
			return target, BOT_MODE_DESIRE_ABSOLUTE
		end
		if Fu.IsPushing(bot) and not target:IsHero() then
			return nil, 0
		end
		if not target:IsHero() and GetUnitToUnitDistance(bot, target) < attackRange + 50 then
			return target, BOT_DESIRE_OVERRIDE * 0.98
		end
		if not target:IsHero() and GetUnitToUnitDistance(bot, target) > attackRange + 300 then
			return target, BOT_DESIRE_OVERRIDE * 0.7
		end
		return target, BOT_DESIRE_OVERRIDE * 0.96
	end
	if not Fu.IsInLaningPhase() and not Fu.IsPushing(bot) then
		local enemyCourier = TeamRoam.GetEnemyCourier(bot, attackRange + botLevel * 2 + 20)
		if enemyCourier ~= nil and not enemyCourier:IsAttackImmune() and not enemyCourier:IsInvulnerable() and hpRatio > 0.3 and not Fu.IsRetreating(bot) then
			return enemyCourier, BOT_DESIRE_OVERRIDE * 1.2
		end
	end
	if botMode == BOT_MODE_RETREAT and botLevel > 9 and not TeamRoam.CanBeInVisible(bot) and TeamRoam.ShouldNotRetreat(bot) then
		target = Fu.GetAttackableWeakestUnit(bot, attackRange + 50, true, true)
		if target ~= nil then
			return target, BOT_DESIRE_OVERRIDE * 1.09
		end
	end
	local lastHitDamage = creepDamage - 1
	if canHitCreep and not TeamRoam.HasHumanAlly(bot) and (hpRatio > 0.5 or not bot:WasRecentlyDamagedByAnyHero(2.0)) then
		local extraRange = botLevel > 20 and 200 or (botLevel > 12 and 300 or 400)
		target = TeamRoam.GetNearbyLastHitCreep(false, true, lastHitDamage, attackRange + extraRange, bot)
		if target ~= nil then
			return target, BOT_MODE_DESIRE_ABSOLUTE
		end
		local enemyTowers = bot:GetNearbyTowers(attackRange + 150, true)
		if TeamRoam.CanBeAttacked(enemyTowers[1]) and Fu.IsWithoutTarget(bot) and TeamRoam.IsLastHitCreep(enemyTowers[1], attackDamage * 2) then
			return enemyTowers[1], BOT_MODE_DESIRE_ABSOLUTE
		end
		local neutralCreeps = bot:GetNearbyNeutralCreeps(attackRange + 150)
		local allyHeroes = Fu.GetNearbyHeroes(bot, 1300, false, BOT_MODE_NONE)
		if Fu.IsWithoutTarget(bot) and botMode ~= BOT_MODE_FARM and #neutralCreeps > 0 and #allyHeroes <= 1 then
			for i = 1, #neutralCreeps do
				if
					TeamRoam.CanBeAttacked(neutralCreeps[i])
					and not TeamRoam.IsAllysTarget(neutralCreeps[i])
					and not Fu.IsTormentor(neutralCreeps[i])
					and not Fu.IsRoshan(neutralCreeps[i])
					and TeamRoam.IsLastHitCreep(neutralCreeps[i], lastHitDamage)
				then
					return neutralCreeps[i], BOT_MODE_DESIRE_ABSOLUTE
				end
			end
		end
	end
	local denyDamage = attackDamage + 3
	local enemyHeroes = Fu.GetNearbyHeroes(bot, 750, true, BOT_MODE_NONE)
	if
		canHitCreep
		and bot:GetLevel() <= 8
		and bot:GetNetWorth() < 13998
		and (hpRatio > 0.38 or not bot:WasRecentlyDamagedByAnyHero(3.0))
		and (enemyHeroes[1] == nil or enemyHeroes[1]:GetLevel() < 10)
		and bot:DistanceFromFountain() > 3800
		and Fu.GetDistanceFromEnemyFountain(bot) > 5000
	then
		local rangeLastHitCreep = TeamRoam.GetExceptRangeLastHitCreep(true, lastHitDamage * 1.1, 0, attackRange + 60, bot)
		if rangeLastHitCreep == nil or denyDamage > 130 or not TeamRoam.IsOthersTarget(rangeLastHitCreep) or not TeamRoam.IsMostAttackDamage(bot) then
			target = TeamRoam.GetNearbyLastHitCreep(false, false, denyDamage, attackRange + 300, bot)
			if target ~= nil then
				return target, BOT_DESIRE_OVERRIDE * 0.97
			end
		end
		local allyTowers = bot:GetNearbyTowers(attackRange + 300, false)
		if Fu.IsWithoutTarget(bot) and #allyTowers > 0 then
			if TeamRoam.CanBeAttacked(allyTowers[1]) and Fu.GetHP(allyTowers[1]) < 0.08 and TeamRoam.IsLastHitCreep(allyTowers[1], denyDamage * 3) then
				return allyTowers[1], BOT_MODE_DESIRE_ABSOLUTE
			end
		end
	end
	return nil, 0
end
function TeamRoam.CarryFindTarget()
	local hpRatio = Fu.GetHP(bot)
	if TeamRoam.CanNotUseAttack(bot) or DotaTime() < 0 then
		return nil, 0
	end
	local enemyTowers = bot:GetNearbyTowers(800, true)
	if Fu.IsValidBuilding(enemyTowers[1]) then
		local properTarget = Fu.GetProperTarget(bot)
		if Fu.IsValidHero(properTarget) and Fu.IsRecklesslyDivingTower(bot, properTarget) then
			return nil, 0
		end
	end
	local canHitCreep = TeamRoam.IsModeSuitToHitCreep(bot)
	local attackRange = math.min(bot:GetAttackRange() + 50, 1170)
	if botName == "npc_dota_hero_templar_assassin" then
		attackRange = attackRange + 100
	end
	local target = Fu.GetProperTarget(bot)
	local healthRatio = bot:GetHealth() / bot:GetMaxHealth()
	local botMode = bot:GetActiveMode()
	local botLevel = bot:GetLevel()
	local attackDamage = bot:GetAttackDamage() - 0.8
	local creepDamage = TeamRoam.GetAttackDamageToCreep(bot) - 1.2
	if TeamRoam.CanBeAttacked(target) and target == engageTarget and GetUnitToUnitDistance(bot, target) <= 1600 then
		if target:GetTeam() == bot:GetTeam() then
			if target:GetHealth() > TeamRoam.GetLastHitHealth(bot, target) then
				return target, BOT_MODE_DESIRE_VERYHIGH * 1.08
			end
			return target, BOT_MODE_DESIRE_VERYHIGH * 1.04
		end
		if target:IsCourier() and GetUnitToUnitDistance(bot, target) <= attackRange + 300 and hpRatio > 0.3 and not Fu.IsRetreating(bot) then
			return target, BOT_DESIRE_OVERRIDE * 1.5
		end
		if target:IsHero() and not Fu.IsInLaningPhase() and (bot:GetCurrentMovementSpeed() < 300 or botLevel >= 25) then
			if botName == "npc_dota_hero_antimage" then
				local blinkAbility = bot:GetAbilityByName("antimage_blink")
				if blinkAbility ~= nil and blinkAbility:IsFullyCastable() then
					return nil, BOT_MODE_DESIRE_NONE
				end
			end
			if ShouldAbortStickyEngage(bot, target) then
				ClearEngageTarget()
				return nil, 0
			end
			return target, BOT_MODE_DESIRE_ABSOLUTE
		end
		if Fu.IsPushing(bot) and not target:IsHero() then
			return nil, 0
		end
		if not target:IsHero() and GetUnitToUnitDistance(bot, target) < attackRange + 50 then
			return target, BOT_DESIRE_OVERRIDE * 0.98
		end
		if not target:IsHero() and GetUnitToUnitDistance(bot, target) > attackRange + 300 then
			return target, BOT_DESIRE_OVERRIDE * 0.7
		end
		return target, BOT_DESIRE_OVERRIDE * 0.96
	end
	if bot:HasModifier("modifier_phantom_lancer_phantom_edge_boost") then
		return nil, 0
	end
	if not Fu.IsInLaningPhase() and not Fu.IsPushing(bot) then
		local enemyCourier = TeamRoam.GetEnemyCourier(bot, attackRange + botLevel * 2 + 20)
		if enemyCourier ~= nil and not enemyCourier:IsAttackImmune() and not enemyCourier:IsInvulnerable() and hpRatio > 0.3 and not Fu.IsRetreating(bot) then
			return enemyCourier, BOT_DESIRE_OVERRIDE * 1.2
		end
	end
	if
		botMode == BOT_MODE_RETREAT
		and botName ~= "npc_dota_hero_bristleback"
		and botLevel > 9
		and not TeamRoam.CanBeInVisible(bot)
		and TeamRoam.ShouldNotRetreat(bot)
	then
		target = Fu.GetAttackableWeakestUnit(bot, attackRange + 50, true, true)
		if target ~= nil then
			return target, BOT_DESIRE_OVERRIDE * 1.09
		end
	end
	local echoSabre = Fu.IsItemAvailable("item_echo_sabre")
	if
		echoSabre ~= nil
		and (echoSabre:IsFullyCastable() or echoSabre:GetCooldownTimeRemaining() < bot:GetAttackPoint() + 0.8)
		and canHitCreep
		and (healthRatio > 0.35 or not bot:WasRecentlyDamagedByAnyHero(1.0))
	then
		local echoDamage = creepDamage * 2
		if echoSabre:IsFullyCastable() or echoSabre:GetCooldownTimeRemaining() < bot:GetAttackPoint() then
			target = TeamRoam.GetNearbyLastHitCreep(true, true, echoDamage, 350, bot)
			if target ~= nil then
				return target, BOT_MODE_DESIRE_ABSOLUTE * 0.98
			end
		end
		local enemyTowers = bot:GetNearbyTowers(1000, true)
		if (echoSabre:IsFullyCastable() or echoSabre:GetCooldownTimeRemaining() < bot:GetAttackPoint() + 0.8) and #enemyTowers == 0 then
			for searchRange = 400, 580, 60 do
				target = TeamRoam.GetExceptRangeLastHitCreep(true, echoDamage, 350, searchRange, bot)
				if target ~= nil then
					return target, BOT_MODE_DESIRE_HIGH
				end
			end
		end
	end
	local lastHitDamage = creepDamage
	if canHitCreep and not TeamRoam.HasHumanAlly(bot) and (healthRatio > 0.5 or not bot:WasRecentlyDamagedByAnyHero(2.0)) then
		local extraRange = 430
		if botLevel > 12 then
			extraRange = 380
		end
		if botLevel > 20 then
			extraRange = 330
		end
		target = TeamRoam.GetNearbyLastHitCreep(true, true, lastHitDamage, attackRange + extraRange, bot)
		if target ~= nil then
			return target, BOT_MODE_DESIRE_ABSOLUTE
		end
	end
	local denyDamage = attackDamage + 3
	local enemyHeroes = bot:GetNearbyHeroes(650, true, BOT_MODE_NONE)
	if
		canHitCreep
		and (healthRatio > 0.38 or not bot:WasRecentlyDamagedByAnyHero(3.0))
		and (enemyHeroes[1] == nil or enemyHeroes[1]:GetLevel() < 12)
		and bot:DistanceFromFountain() > 3800
		and Fu.GetDistanceFromEnemyFountain(bot) > 5000
	then
		if bot:GetLevel() <= 8 then
			local rangeLastHitCreep = TeamRoam.GetExceptRangeLastHitCreep(true, lastHitDamage * 1.5, 0, attackRange + 60, bot)
			if rangeLastHitCreep == nil or denyDamage > 130 or not TeamRoam.IsOthersTarget(rangeLastHitCreep) or not TeamRoam.IsMostAttackDamage(bot) then
				target = TeamRoam.GetNearbyLastHitCreep(false, false, denyDamage, attackRange + 300, bot)
				if target ~= nil then
					return target, BOT_MODE_DESIRE_ABSOLUTE * 0.97
				end
			end
		end
		local allyTowers = bot:GetNearbyTowers(attackRange + 300, false)
		if Fu.IsWithoutTarget(bot) and #allyTowers > 0 then
			if TeamRoam.CanBeAttacked(allyTowers[1]) and Fu.GetHP(allyTowers[1]) < 0.05 and TeamRoam.IsLastHitCreep(allyTowers[1], denyDamage * 3) then
				return allyTowers[1], BOT_MODE_DESIRE_ABSOLUTE
			end
		end
	end
	if
		canHitCreep
		and bot:GetLevel() <= 8
		and TeamRoam.CanAttackTogether(bot)
		and (enemyHeroes[1] == nil or enemyHeroes[1]:GetLevel() < 12)
		and bot:DistanceFromFountain() > 3800
		and Fu.GetDistanceFromEnemyFountain(bot) > 5000
	then
		local allyHeroes = bot:GetNearbyHeroes(1200, false, BOT_MODE_NONE)
		local togetherCount = TeamRoam.GetCanTogetherCount(allyHeroes)
		local mostDamageAlly = TeamRoam.GetMostDamageUnit(allyHeroes)
		if mostDamageAlly ~= nil and togetherCount >= 2 then
			local enemyLaneCreeps = mostDamageAlly:GetNearbyLaneCreeps(1600, true)
			local allyTowers = bot:GetNearbyTowers(1400, false)
			if allyTowers[1] ~= nil and allyTowers[1]:GetAttackTarget() ~= nil then
				local towerDamage = allyTowers[1]:GetAttackDamage()
				local towerTarget = allyTowers[1]:GetAttackTarget()
				for _, creep in pairs(enemyLaneCreeps) do
					if
						towerTarget == creep
						and TeamRoam.CanBeAttacked(creep)
						and creep:GetHealth() < TeamRoam.GetLastHitHealth(allyTowers[1], creep)
						and creep:GetHealth() > TeamRoam.GetLastHitHealth(bot, creep)
					then
						local totalDamage = 0
						local attackerCount = 0
						for _, ally in pairs(allyHeroes) do
							if
								TeamRoam.CanAttackTogether(ally) and GetUnitToUnitDistance(ally, creep) <= ally:GetAttackRange() + 50
							then
								totalDamage = ally:GetAttackDamage() + totalDamage
								attackerCount = attackerCount + 1
							end
						end
						if
							TeamRoam.IsLastHitCreep(creep, totalDamage)
							and attackerCount >= 2
							and GetUnitToUnitDistance(bot, creep) <= bot:GetAttackRange() + 50
						then
							return creep, BOT_MODE_DESIRE_ABSOLUTE
						end
					end
				end
			end
			local rangeLastHitCreep = TeamRoam.GetExceptRangeLastHitCreep(true, mostDamageAlly:GetAttackDamage() * 1.2, 0, 800, mostDamageAlly)
			if rangeLastHitCreep == nil or not TeamRoam.IsOthersTarget(rangeLastHitCreep) then
				local allyCreeps = mostDamageAlly:GetNearbyCreeps(1600, false)
				for _, creep in pairs(allyCreeps) do
					if
						TeamRoam.CanBeAttacked(creep)
						and creep:GetHealth() / creep:GetMaxHealth() < 0.5
						and not TeamRoam.IsLastHitCreep(creep, denyDamage)
						and not Fu.IsTormentor(creep)
						and not Fu.IsRoshan(creep)
						and Fu.IsDeniableLaneCreep(creep)
					then
						local totalDamage = 0
						local attackerCount = 0
						for _, ally in pairs(allyHeroes) do
							if
								TeamRoam.CanAttackTogether(ally) and GetUnitToUnitDistance(ally, creep) <= ally:GetAttackRange() + 150
							then
								totalDamage = ally:GetAttackDamage() + totalDamage
								attackerCount = attackerCount + 1
							end
						end
						if
							TeamRoam.IsLastHitCreep(creep, totalDamage)
							and attackerCount >= 2
							and GetUnitToUnitDistance(bot, creep) <= bot:GetAttackRange() + 150
						then
							return creep, BOT_MODE_DESIRE_HIGH
						end
					end
				end
			end
		end
	end
	local enemyHeroes = bot:GetNearbyHeroes(1600, true, BOT_MODE_NONE)
	local enemyLaneCreepsNear = bot:GetNearbyLaneCreeps(1200, true)
	local rangeLastHitCreep = TeamRoam.GetExceptRangeLastHitCreep(true, lastHitDamage * 1.2, 0, attackRange + 120, bot)
	if
		canHitCreep
		and botLevel >= 8
		and enemyHeroes[1] == nil
		and (lastHitDamage > 118 or bot:GetSecondsPerAttack() < 0.7)
		and (rangeLastHitCreep == nil or not TeamRoam.IsMostAttackDamage(bot) or not TeamRoam.IsOthersTarget(rangeLastHitCreep))
	then
		local enemyTowers = bot:GetNearbyTowers(900, true)
		if botName ~= "npc_dota_hero_templar_assassin" then
			local laneCreepsInRange = bot:GetNearbyLaneCreeps(attackRange + 150, true)
			for _, creep in pairs(laneCreepsInRange) do
				if TeamRoam.CanBeAttacked(creep) and not TeamRoam.IsLastHitCreep(creep, lastHitDamage * 1.2) and not TeamRoam.IsOthersTarget(creep) then
					local allyLaneCreeps = bot:GetNearbyLaneCreeps(600, false)
					if TeamRoam.IsLastHitCreep(creep, lastHitDamage * 2) then
						return creep, BOT_MODE_DESIRE_ABSOLUTE
					elseif TeamRoam.IsLastHitCreep(creep, lastHitDamage * 3 - 5) and #allyLaneCreeps == 0 and botLevel >= 3 then
						return creep, BOT_MODE_DESIRE_ABSOLUTE * 0.9
					end
				end
			end
		end
		if
			bot:DistanceFromFountain() > 3800
			and not isPvNMode
			and bot:GetLevel() <= 6
			and Fu.GetDistanceFromEnemyFountain(bot) > 5000
			and enemyTowers[1] == nil
			and bot:GetNetWorth() < 19800
			and denyDamage > 110
		then
			local allyCreeps = bot:GetNearbyCreeps(attackRange + 120, false)
			for _, creep in pairs(allyCreeps) do
				if
					TeamRoam.CanBeAttacked(creep)
					and creep:GetHealth() / creep:GetMaxHealth() < 0.5
					and TeamRoam.IsLastHitCreep(creep, denyDamage * 2)
					and (not TeamRoam.IsLastHitCreep(creep, denyDamage * 1.2) or #enemyLaneCreepsNear == 0)
					and not TeamRoam.IsOthersTarget(creep)
					and not Fu.IsTormentor(creep)
					and not Fu.IsRoshan(creep)
					and Fu.IsDeniableLaneCreep(creep)
				then
					return creep, BOT_MODE_DESIRE_ABSOLUTE
				end
			end
		end
		local enemyCreeps = bot:GetNearbyCreeps(1600, true)
		local attackingAllies = Fu.GetSpecialModeAllies(bot, 2500, BOT_MODE_ATTACK)
		local teamFightLocation = Fu.GetTeamFightLocation(bot)
		local defendLane, defendDesire = Fu.GetMostDefendLaneDesire()
		if
			TeamRoam.CanBeAttacked(enemyCreeps[1])
			and bot:GetHealth() > 300
			and not TeamRoam.IsAllysTarget(enemyCreeps[1])
			and not Fu.IsRoshan(enemyCreeps[1])
			and (enemyCreeps[1]:GetTeam() == TEAM_NEUTRAL or lastHitDamage > 110)
			and (not enemyCreeps[1]:IsAncientCreep() or lastHitDamage > 150)
			and (not Fu.IsKeyWordUnit("warlock", enemyCreeps[1]) or hpRatio > 0.58)
			and (teamFightLocation == nil or GetUnitToLocationDistance(bot, teamFightLocation) >= 3000)
			and defendDesire <= 0.8
			and botMode ~= BOT_MODE_FARM
			and botMode ~= BOT_MODE_RUNE
			and botMode ~= BOT_MODE_LANING
			and botMode ~= BOT_MODE_ASSEMBLE
			and botMode ~= BOT_MODE_SECRET_SHOP
			and botMode ~= BOT_MODE_SIDE_SHOP
			and botMode ~= BOT_MODE_WATCHER
			and botMode ~= BOT_MODE_WARD
			and GetRoshanDesire() < BOT_MODE_DESIRE_HIGH
			and not bot:WasRecentlyDamagedByAnyHero(2.0)
			and bot:GetAttackTarget() == nil
			and botLevel >= 10
			and #attackingAllies == 0
			and #enemyTowers == 0
			and not Fu.IsTormentor(enemyCreeps[1])
			and not Fu.IsRoshan(enemyCreeps[1])
		then
			if
				enemyCreeps[1]:GetTeam() == TEAM_NEUTRAL
				and Fu.IsInRange(bot, enemyCreeps[1], attackRange + 100)
				and (#enemyCreeps <= 2 or lastHitDamage > 220 or botName == "npc_dota_hero_antimage")
			then
				Fu.Role["availableCampTable"] = TeamRoam.UpdateCommonCamp(enemyCreeps[1], Fu.Role["availableCampTable"])
			end
			return enemyCreeps[1], BOT_MODE_DESIRE_ABSOLUTE
		end
		if bot:GetHealth() > 160 and Fu.IsWithoutTarget(bot) then
			local neutralCreeps = bot:GetNearbyNeutralCreeps(attackRange + 150)
			if #neutralCreeps > 0 and botMode ~= BOT_MODE_FARM then
				for i = 1, #neutralCreeps do
					if
						TeamRoam.CanBeAttacked(neutralCreeps[i])
						and not TeamRoam.IsAllysTarget(neutralCreeps[i])
						and not Fu.IsTormentor(neutralCreeps[i])
						and not Fu.IsRoshan(neutralCreeps[i])
						and TeamRoam.IsLastHitCreep(neutralCreeps[i], lastHitDamage * 2)
					then
						return neutralCreeps[i], BOT_MODE_DESIRE_ABSOLUTE
					end
				end
			end
		end
	end
	return nil, 0
end
local hasHumanTeammate = nil
function TeamRoam.HasHumanAlly(unit)
	if hasHumanTeammate == false then
		return false
	end
	if hasHumanTeammate == nil then
		local players = GetTeamPlayers(GetTeam())
		for i = 1, #players do
			if not IsPlayerBot(players[i]) then
				hasHumanTeammate = true
				break
			end
		end
		if hasHumanTeammate ~= true then
			hasHumanTeammate = false
		end
	end
	local allyHeroes = unit:GetNearbyHeroes(900, false, BOT_MODE_NONE)
	for _, ally in pairs(allyHeroes) do
		if not ally:IsBot() then
			return true
		end
	end
	return false
end
function TeamRoam.IsCreepTarget(unit)
	local bot = GetBot()
	local creeps = bot:GetNearbyCreeps(1200, true)
	for _, creep in pairs(creeps) do
		if TeamRoam.IsValid(creep) and creep:GetAttackTarget() == unit and not Fu.IsTormentor(creep) and not Fu.IsRoshan(creep) then
			return true
		end
	end
	local creeps = bot:GetNearbyCreeps(1200, false)
	for _, creep in pairs(creeps) do
		if TeamRoam.IsValid(creep) and creep:GetAttackTarget() == unit and not Fu.IsTormentor(creep) and not Fu.IsRoshan(creep) then
			return true
		end
	end
	return false
end
function TeamRoam.IsValid(unit)
	return unit ~= nil and not unit:IsNull() and unit:IsAlive() and unit:CanBeSeen()
end
function TeamRoam.GetAttackDamageToCreep(unit)
	if unit:GetItemSlotType(unit:FindItemSlot("item_quelling_blade")) == ITEM_SLOT_TYPE_MAIN then
		if unit:GetAttackRange() > 310 or unit:GetUnitName() == "npc_dota_hero_templar_assassin" then
			return unit:GetAttackDamage() + 4
		else
			return unit:GetAttackDamage() + 8
		end
	end
	if unit:FindItemSlot("item_bfury") >= 0 then
		return unit:GetAttackDamage() + 15
	end
	return unit:GetAttackDamage()
end
function TeamRoam.CanNotUseAttack(unit)
	return not unit:IsAlive()
		or Fu.HasQueuedAction(unit)
		or unit:IsInvulnerable()
		or unit:IsCastingAbility()
		or unit:IsUsingAbility()
		or unit:IsChanneling()
		or unit:IsStunned()
		or unit:IsDisarmed()
		or unit:IsHexed()
		-- Not IsRooted: a rooted hero still attacks what is in range.
		or TeamRoam.WillBreakInvisible(unit)
end
function TeamRoam.WillBreakInvisible(unit)
	-- Game 031, 46:50: under Moonlight Shadow Doom hit OD with Infernal Blade, faded again and then
	-- stood still: an invisible bot was treated as unable to attack. Moonlight Shadow is an engage,
	-- and going on someone or in a team fight any invisibility is fine to attack out of.
	if unit:IsInvisible() then
		if unit:HasModifier("modifier_mirana_moonlight_shadow") then
			return false
		end
		local okF, fighting = pcall(function()
			return Fu.IsGoingOnSomeone(unit) or Fu.IsInTeamFight(unit, 1200)
		end)
		if okF and fighting then
			return false
		end
	end
	local invisibleAttackers = {
		["npc_dota_hero_riki"] = true,
		["npc_dota_hero_phantom_assassin"] = true,
		["npc_dota_hero_templar_assassin"] = true,
		["npc_dota_hero_bounty_hunter"] = true,
	}
	if unit:IsInvisible() and not invisibleAttackers[unit:GetUnitName()] then
		return true
	end
	return false
end
function TeamRoam.CanBeAttacked(unit)
	return unit ~= nil
		and unit:IsAlive()
		and unit:CanBeSeen()
		and not unit:IsNull()
		and not unit:IsAttackImmune()
		and not unit:IsInvulnerable()
		and not unit:HasModifier("modifier_fountain_glyph")
		and (unit:GetTeam() == team or not unit:HasModifier("modifier_crystal_maiden_frostbite"))
		and (
			unit:GetTeam() ~= team
			or unit:GetUnitName() ~= "npc_dota_wraith_king_skeleton_warrior" and unit:GetHealth() / unit:GetMaxHealth() < 0.5
		)
end
local courierCheckInterval, lastCourierCheckTime = 0.1, -90
function TeamRoam.GetEnemyCourier(unit, range)
	if GetGameMode() == 23 then
		return nil
	end
	if Fu.GetDistanceFromEnemyFountain(unit) < 1400 then
		return nil
	end
	if DotaTime() > lastCourierCheckTime + courierCheckInterval then
		lastCourierCheckTime = DotaTime()
		for _, courier in pairs(GetUnitList(UNIT_LIST_ENEMIES)) do
			if
				courier
				and courier:IsCourier()
				and courier:IsAlive()
				and GetUnitToUnitDistance(unit, courier) <= range
				and not courier:IsInvulnerable()
				and not courier:IsAttackImmune()
				and not courier:HasModifier("modifier_fountain_aura")
			then
				return courier
			end
		end
	end
	return nil
end
function TeamRoam.WeakestUnitExceptRangeCanBeAttacked(isHero, isEnemy, minDistance, range, unit)
	local units = {}
	local weakest = nil
	local lowestHealth = 4999
	local health = 0
	if range > 1600 then
		range = 1600
	end
	if isHero then
		units = unit:GetNearbyHeroes(range, isEnemy, BOT_MODE_NONE)
	else
		units = unit:GetNearbyLaneCreeps(range, isEnemy)
	end
	for _, candidate in pairs(units) do
		if
			TeamRoam.IsValid(candidate)
			and GetUnitToUnitDistance(unit, candidate) > minDistance
			and TeamRoam.CanBeAttacked(candidate)
			and not candidate:HasModifier("modifier_crystal_maiden_frostbite")
		then
			health = candidate:GetHealth() / 1
			if health < lowestHealth then
				weakest = candidate
				lowestHealth = health
			end
		end
	end
	return weakest
end
function TeamRoam.GetNearbyLastHitCreep(ignoreAllyTargets, isEnemy, damage, range, unit)
	if range > 1600 then
		range = 1600
	end
	local creeps = unit:GetNearbyLaneCreeps(range, isEnemy)
	local damageType = DAMAGE_TYPE_PHYSICAL
	local unitName = unit:GetUnitName()
	if
		isEnemy
		and unitName == "npc_dota_hero_templar_assassin"
		and unit:HasModifier("modifier_templar_assassin_refraction_damage")
	then
		local ability = unit:GetAbilityByName("templar_assassin_refraction")
		local bonusDamage = ability:GetSpecialValueInt("bonus_damage")
		damage = damage + bonusDamage
	end
	if isEnemy and unitName == "npc_dota_hero_kunkka" then
		local ability = unit:GetAbilityByName("kunkka_tidebringer")
		if ability:IsFullyCastable() then
			local bonusDamage = ability:GetSpecialValueInt("damage_bonus")
			damage = damage + bonusDamage
		end
	end
	for _, creep in pairs(creeps) do
		if
			TeamRoam.CanBeAttacked(creep)
			and creep:GetHealth() < damage + 256
			and (ignoreAllyTargets or not TeamRoam.IsAllysTarget(creep))
			and (isEnemy or Fu.IsDeniableLaneCreep(creep))
		then
			local attackDelay = Fu.GetAttackProDelayTime(unit, creep)
			if isEnemy and unitName == "npc_dota_hero_antimage" and Fu.IsKeyWordUnit("ranged", creep) then
				local ability = unit:GetAbilityByName("antimage_mana_break")
				if ability:IsTrained() then
					local bonusDamage = 0.5 * ability:GetSpecialValueInt("mana_per_hit")
					damage = damage + bonusDamage
				end
			end
			local totalDamage = damage * 1
			if Fu.WillKillTarget(creep, totalDamage, damageType, attackDelay) then
				return creep
			end
		end
	end
	return nil
end
function TeamRoam.GetExceptRangeLastHitCreep(isEnemy, damage, minDistance, range, unit)
	local creep = TeamRoam.WeakestUnitExceptRangeCanBeAttacked(false, isEnemy, minDistance, range, unit)
	local damageType = DAMAGE_TYPE_PHYSICAL
	if TeamRoam.IsValid(creep) then
		if not isEnemy and creep:GetHealth() / creep:GetMaxHealth() >= 0.5 then
			return nil
		end
		damage = damage * 1
		local attackDelay = Fu.GetAttackProDelayTime(unit, creep)
		if Fu.WillKillTarget(creep, damage, damageType, attackDelay) then
			return creep
		end
	end
	return nil
end
function TeamRoam.IsLastHitCreep(creep, damage)
	if TeamRoam.CanBeAttacked(creep) then
		damage = damage * 1
		if
			creep:GetActualIncomingDamage(damage, DAMAGE_TYPE_PHYSICAL) + Fu.GetCreepAttackProjectileWillRealDamage(creep, 0.66)
			> creep:GetHealth() + 1
		then
			return true
		end
	end
	return false
end
function TeamRoam.GetLastHitHealth(attacker, creep)
	if TeamRoam.CanBeAttacked(creep) then
		local damage = TeamRoam.GetAttackDamageToCreep(attacker) * 1
		return creep:GetActualIncomingDamage(damage, DAMAGE_TYPE_PHYSICAL)
	end
	return attacker:GetAttackDamage()
end
function TeamRoam.IsAllysTarget(unit)
	local bot = GetBot()
	local allyHeroes = bot:GetNearbyHeroes(1000, false, BOT_MODE_NONE)
	if #allyHeroes < 2 then
		return false
	end
	for _, ally in pairs(allyHeroes) do
		if ally ~= bot and not ally:IsIllusion() and (ally:GetTarget() == unit or ally:GetAttackTarget() == unit) then
			return true
		end
	end
	return false
end
function TeamRoam.IsEnemysTarget(unit)
	local bot = GetBot()
	local enemyHeroes = bot:GetNearbyHeroes(1600, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(enemyHeroes) do
		if TeamRoam.IsValid(enemyHero) and Fu.GetProperTarget(enemyHero) == unit then
			return true
		end
	end
	return false
end
function TeamRoam.CanAttackTogether(unit)
	local allyHeroes = unit:GetNearbyHeroes(1200, false, BOT_MODE_NONE)
	local enemyHeroes = unit:GetNearbyHeroes(600, true, BOT_MODE_NONE)
	return unit ~= nil
		and unit:IsAlive()
		and not unit:IsIllusion()
		and Fu.GetProperTarget(unit) == nil
		and #allyHeroes >= 2
		and (enemyHeroes[1] == nil or enemyHeroes[1]:GetLevel() < 10)
end
function TeamRoam.GetMostDamageUnit(units)
	local mostDamage = 0
	local mostDamageUnit = nil
	for _, unit in pairs(units) do
		if unit ~= nil and unit:IsAlive() and Fu.GetProperTarget(unit) == nil and unit:GetAttackDamage() > mostDamage then
			mostDamage = unit:GetAttackDamage()
			mostDamageUnit = unit
		end
	end
	return mostDamageUnit
end
function TeamRoam.GetCanTogetherCount(allyHeroes)
	local count = 0
	for _, ally in pairs(allyHeroes) do
		if TeamRoam.IsValid(ally) and TeamRoam.CanAttackTogether(ally) then
			count = count + 1
		end
	end
	return count
end
function TeamRoam.IsOthersTarget(unit)
	local bot = GetBot()
	if TeamRoam.IsValid(unit) then
		if TeamRoam.IsAllysTarget(unit) then
			return true
		end
		if TeamRoam.IsEnemysTarget(unit) then
			return true
		end
		if TeamRoam.IsCreepTarget(unit) then
			return true
		end
		local enemyTowers = bot:GetNearbyTowers(1600, true)
		for _, tower in pairs(enemyTowers) do
			if Fu.IsValidBuilding(tower) and tower:GetAttackTarget() == unit then
				return true
			end
		end
		local allyTowers = bot:GetNearbyTowers(1600, false)
		for _, tower in pairs(allyTowers) do
			if Fu.IsValidBuilding(tower) and tower:GetAttackTarget() == unit then
				return true
			end
		end
	end
	return false
end
function TeamRoam.CanBeInVisible(unit)
	local enemyTowers = unit:GetNearbyTowers(800, true)
	if #enemyTowers > 0 or unit:HasModifier("modifier_item_dustofappearance") then
		return false
	end
	if unit:IsInvisible() then
		return true
	end
	local glimmerCape = Fu.IsItemAvailable("item_glimmer_cape")
	if glimmerCape ~= nil and glimmerCape:IsFullyCastable() then
		return true
	end
	local shadowBlade = Fu.IsItemAvailable("item_invis_sword")
	if shadowBlade ~= nil and shadowBlade:IsFullyCastable() then
		return true
	end
	local silverEdge = Fu.IsItemAvailable("item_silver_edge")
	if silverEdge ~= nil and silverEdge:IsFullyCastable() then
		return true
	end
	return false
end
local lastCampUpdateTime = 0
function TeamRoam.UpdateCommonCamp(creep, camps)
	if lastCampUpdateTime < DotaTime() - 3.0 then
		lastCampUpdateTime = DotaTime()
		for i = 1, #camps do
			if GetUnitToLocationDistance(creep, camps[i].cattr.location) < 500 then
				table.remove(camps, i)
				return camps
			end
		end
	end
	return camps
end
function TeamRoam.ConsiderHelpWhenCoreIsTargeted()
	if Fu.GetHP(bot) < 0.4 then
		return nil, false
	end
	if bot:WasRecentlyDamagedByAnyHero(2.0) and Fu.GetHP(bot) < 0.55 then
		return nil, false
	end
	local searchRange = 3500
	local modeDesire = bot:GetActiveModeDesire()
	local core = Fu.GetClosestCore(bot, searchRange)
	if
		core ~= nil
		and Fu.GetHP(core) > 0.2
		and (not Fu.IsCore(bot) or bot.isBear or Fu.IsCore(bot) and (not Fu.IsInLaningPhase() or Fu.IsInRange(bot, core, 1600)))
		and not Fu.IsGoingOnSomeone(bot)
		and not (Fu.IsRetreating(bot) and modeDesire > 0.8)
	then
		local alliesNearCore = Fu.GetAlliesNearLoc(core:GetLocation(), 1200)
		local enemiesNearCore = Fu.GetEnemiesNearLoc(core:GetLocation(), 1600)
		if #enemiesNearCore > #alliesNearCore + 1 then
			return nil, false
		end
		for _, enemyHero in pairs(enemiesNearCore) do
			if Fu.IsValidHero(enemyHero) and GetUnitToUnitDistance(enemyHero, core) <= 1600 and #alliesNearCore + 1 >= #enemiesNearCore then
				if enemyHero:GetAttackTarget() == core or Fu.IsChasingTarget(enemyHero, core) or core:WasRecentlyDamagedByHero(enemyHero, 2.5) then
					return enemyHero, true
				end
			end
		end
	end
	return nil, false
end
function TeamRoam.IsModeSuitToHitCreep(unit)
	local botMode = unit:GetActiveMode()
	local enemies = Fu.GetEnemyList(unit, 750)
	if #enemies >= 3 or enemies[1] ~= nil and enemies[1]:GetLevel() >= 8 then
		return false
	end
	if unit:HasModifier("modifier_axe_battle_hunger") then
		if #unit:GetNearbyLaneCreeps(unit:GetAttackRange() + 180, true) > 0 then
			return true
		end
	end
	if
		unit:GetLevel() <= 3
		and botMode ~= BOT_MODE_EVASIVE_MANEUVERS
		and (botMode ~= BOT_MODE_RETREAT or botMode == BOT_MODE_RETREAT and unit:GetActiveModeDesire() < 0.78)
	then
		return true
	end
	return botMode ~= BOT_MODE_ATTACK
		and botMode ~= BOT_MODE_EVASIVE_MANEUVERS
		and (botMode ~= BOT_MODE_RETREAT or botMode == BOT_MODE_RETREAT and unit:GetActiveModeDesire() < 0.68)
end
function TeamRoam.IsMostAttackDamage(unit)
	for _, ally in pairs(Fu.GetNearbyHeroes(unit, 800, false, BOT_MODE_NONE)) do
		if ally ~= unit and not TeamRoam.CanNotUseAttack(ally) and ally:GetAttackDamage() > unit:GetAttackDamage() then
			return false
		end
	end
	return true
end
function TeamRoam.ShouldNotRetreat(unit)
	do
		local alliesNearUnit = Fu.GetAlliesNearLoc(unit:GetLocation(), 1000)
		local enemiesNearUnit = Fu.GetEnemiesNearLoc(unit:GetLocation(), 1000)
		local isOutmatched = #alliesNearUnit < #enemiesNearUnit or not Fu.WeAreStronger(unit, 1000)
		if (unit:WasRecentlyDamagedByAnyHero(1.2) or unit:WasRecentlyDamagedByTower(1.2)) and isOutmatched then
			return false
		end
	end
	if
		unit:HasModifier("modifier_item_satanic_unholy")
		or unit:HasModifier("modifier_abaddon_borrowed_time")
		or unit:GetCurrentMovementSpeed() < 240 and not unit:HasModifier("modifier_arc_warden_spark_wraith_purge")
	then
		return true
	end
	local attackingAllies = Fu.GetNearbyHeroes(unit, 1000, false, BOT_MODE_ATTACK)
	if
		(unit:HasModifier("modifier_item_mask_of_madness_berserk") or Fu.CanIgnoreLowHp(unit))
		and (#attackingAllies >= 1 or Fu.GetHP(unit) > 0.6)
		and (unit:WasRecentlyDamagedByAnyHero(1) or unit:WasRecentlyDamagedByTower(1))
	then
		return true
	end
	local allies = Fu.GetAllyList(unit, 800)
	if #allies <= 1 then
		return false
	end
	if
		botName == "npc_dota_hero_medusa"
		or unit:FindItemSlot("item_abyssal_blade") >= 0
		or unit:HasModifier("modifier_muerta_pierce_the_veil_buff")
			and (unit:WasRecentlyDamagedByAnyHero(1) or Fu.GetHP(unit) > 0.2 or unit:WasRecentlyDamagedByTower(1))
			and #allies >= 3
			and #attackingAllies >= 1
	then
		return true
	end
	if botName == "npc_dota_hero_skeleton_king" and unit:GetLevel() >= 6 and #attackingAllies >= 1 then
		local reincarnationAbility = unit:GetAbilityByName("skeleton_king_reincarnation")
		if reincarnationAbility and reincarnationAbility:GetCooldownTimeRemaining() <= 1.0 and unit:GetMana() >= 160 then
			return true
		end
	end
	for _, ally in pairs(allies) do
		if Fu.IsValid(ally) then
			if
				Fu.GetHP(unit) >= 0.3
				and (
					Fu.GetHP(ally) > 0.88 and ally:GetLevel() >= 12 and ally:GetActiveMode() ~= BOT_MODE_RETREAT
					or ally:HasModifier("modifier_black_king_bar_immune")
					or ally:IsMagicImmune()
					or ally:HasModifier("modifier_item_mask_of_madness_berserk") and ally:GetAttackTarget() ~= nil
					or ally:HasModifier("modifier_abaddon_borrowed_time")
					or ally:HasModifier("modifier_item_satanic_unholy")
					or Fu.CanIgnoreLowHp(ally)
				)
			then
				return true
			end
		end
	end
	return false
end
local lastTowerAttackTime = 0
function TeamRoam.ShouldAttackTowerCreep(unit)
	if TeamRoam.CanNotUseAttack(unit) then
		return 0
	end
	if
		unit:GetLevel() > 2
		and unit:GetAnimActivity() == 1502
		and unit:GetTarget() == nil
		and unit:GetAttackTarget() == nil
		and TeamRoam.IsModeSuitToHitCreep(unit)
		and Fu.GetHP(unit) > 0.38
		and not unit:WasRecentlyDamagedByAnyHero(2.0)
	then
		local searchRange = math.min(unit:GetAttackRange() + 150, 1250)
		local allyLaneCreeps = unit:GetNearbyLaneCreeps(800, false)
		local enemyLaneCreeps = unit:GetNearbyLaneCreeps(800, true)
		local attackTime = unit:GetSecondsPerAttack() * 0.75
		local attackTarget = nil
		local enemyTowers = unit:GetNearbyTowers(searchRange, true)
		local moveSpeed = unit:GetCurrentMovementSpeed()
		if
			TeamRoam.CanBeAttacked(enemyTowers[1])
			and (enemyTowers[1]:GetAttackTarget() ~= unit or Fu.GetHP(unit) > 0.8)
			and #allyLaneCreeps > 0
			and lastTowerAttackTime < DotaTime() - 1.0
		then
			attackTarget = enemyTowers[1]
			local extraDistance = GetUnitToUnitDistance(unit, attackTarget) - unit:GetAttackRange()
			if extraDistance > 0 then
				attackTime = attackTime + extraDistance / moveSpeed
			end
			lastTowerAttackTime = DotaTime()
			return attackTime, attackTarget
		end
		local enemyBarracks = unit:GetNearbyBarracks(searchRange, true)
		if TeamRoam.CanBeAttacked(enemyBarracks[1]) and #allyLaneCreeps > 0 then
			attackTarget = enemyBarracks[1]
			local extraDistance = GetUnitToUnitDistance(unit, attackTarget) - unit:GetAttackRange()
			if extraDistance > 0 then
				attackTime = attackTime + extraDistance / moveSpeed
			end
			return attackTime, attackTarget
		end
		local enemyAncient = GetAncient(GetOpposingTeam())
		if Fu.IsInRange(unit, enemyAncient, searchRange + 80) and TeamRoam.CanBeAttacked(enemyAncient) and #enemyLaneCreeps == 0 then
			attackTarget = enemyAncient
			local extraDistance = GetUnitToUnitDistance(unit, attackTarget) - unit:GetAttackRange()
			if extraDistance > 0 then
				attackTime = attackTime + extraDistance / moveSpeed
			end
			return attackTime, attackTarget
		end
	end
	local allyTowers = unit:GetNearbyTowers(1600, false)
	if allyTowers[1] == nil or not TeamRoam.IsMostAttackDamage(unit) or unit:GetLevel() > 12 then
		return 0, nil
	end
	if allyTowers[1] ~= nil and allyTowers[1]:GetAttackTarget() ~= nil then
		local towerTarget = allyTowers[1]:GetAttackTarget()
		local allyCreepsNear = unit:GetNearbyLaneCreeps(500, false)
		if
			not towerTarget:IsHero()
			and TeamRoam.CanBeAttacked(towerTarget)
			and #allyCreepsNear == 0
			and not TeamRoam.IsCreepTarget(towerTarget)
			and GetUnitToUnitDistance(unit, towerTarget) < unit:GetAttackRange() + 100
		then
			local towerHitDamage = TeamRoam.GetLastHitHealth(allyTowers[1], towerTarget)
			local unitHitDamage = TeamRoam.GetLastHitHealth(unit, towerTarget)
			local attackTime = unit:GetSecondsPerAttack() - 0.3
			local health = towerTarget:GetHealth()
			if towerHitDamage > unitHitDamage and health > towerHitDamage and health % towerHitDamage > unitHitDamage then
				return attackTime, towerTarget
			end
		end
	end
	return 0, nil
end
function ItemOpsDesire()
	if DotaTime() >= lastItemScanTime + 2.0 then
		for _, droppedItem in pairs(GetDroppedItemList()) do
			if droppedItem ~= nil then
				local itemName = droppedItem.item:GetName()
				if not Fu.Utils.SetContains(itemName) and not Fu.Utils.HasValue(Item["tEarlyConsumableItem"], itemName) then
					if
						(itemName == "item_aegis" or itemName == "item_roshans_banner")
						and Item.ShouldClaimRoshanDrop(bot, droppedItem.location, itemName)
					then
						itemToPickUp = droppedItem
					end
					if itemName == "item_cheese" and Fu.GetPosition(bot) <= 3 and not Fu.HasItem(bot, "item_aegis") then
						itemToPickUp = droppedItem
					end
					if itemName == "item_refresher_shard" then
						local mostUltimateCdUnit = Fu.GetMostUltimateCDUnit()
						if mostUltimateCdUnit ~= nil and mostUltimateCdUnit:IsBot() and bot == mostUltimateCdUnit then
							itemToPickUp = droppedItem
						end
					end
					local owner = droppedItem.owner
					-- Don't chase own lotuses/wards (handoffs / old lotus drops).
					if
						owner ~= nil
						and owner == bot
						and not string.find(itemName, "token")
						and itemName ~= "item_famango"
						and itemName ~= "item_great_famango"
						and itemName ~= "item_greater_famango"
						and itemName ~= "item_ward_observer"
						and itemName ~= "item_ward_sentry"
						and itemName ~= "item_ward_dispenser"
						and Item.RoshanClaimKind(itemName) == nil
					then
						itemToPickUp = droppedItem
					end
					if itemToPickUp ~= nil and GetItemCost(itemName) > minPickupItemCost then
						return RemapValClamped(
							Fu.Utils.GetLocationToLocationDistance(droppedItem.location, bot:GetLocation()),
							5000,
							0,
							BOT_ACTION_DESIRE_NONE,
							BOT_ACTION_DESIRE_VERYHIGH
						)
					end
				end
			end
		end
		lastItemScanTime = DotaTime()
	end
	TrySellOrDropItem()
	TrySwapInvItemForCheese()
	TrySwapInvItemForRefresherShard()
	TrySwapInvItemForClarity()
	TrySwapInvItemForFlask()
	TrySwapInvItemForMoonshard()
end
function ItemOpsThink()
	if itemToPickUp ~= nil then
		if Fu.Item.GetEmptyInventoryAmount(bot) > 0 and not itemToPickUp.item:IsNull() then
			local itemName = itemToPickUp.item:GetName()
			if pickupAttempts >= 3 and not Utils.SetContains(itemName) then
				pickupAttempts = 0
				Utils.AddToSet(ignoredItems, itemToPickUp.item)
			end
			if not Utils.SetContains(itemName) and not Utils.HasValue(Item["tEarlyConsumableItem"], itemName) then
				if itemName == "item_aegis" or itemName == "item_roshans_banner" then
					if Item.ShouldClaimRoshanDrop(bot, itemToPickUp.location, itemName) then
						GoPickUpItem(itemToPickUp)
					end
				elseif itemName == "item_cheese" then
					if Fu.GetPosition(bot) <= 3 and not Fu.HasItem(bot, "item_aegis") then
						GoPickUpItem(itemToPickUp)
					end
				else
					GoPickUpItem(itemToPickUp)
				end
			end
		end
	end
end
function GoPickUpItem(droppedItem)
	local distance = GetUnitToLocationDistance(bot, droppedItem.location)
	if distance > 200 and distance < 2000 then
		bot:Action_MoveToLocation(droppedItem.location)
	elseif distance <= 100 then
		pickupAttempts = pickupAttempts + 1
		bot:Action_PickUpItem(droppedItem.item)
		return
	end
end
function TrySwapInvItemForClarity()
	if DotaTime() >= lastClaritySwapTime + 6.3 and bot:GetActiveMode() ~= BOT_MODE_WARD then
		local slot = bot:FindItemSlot("item_clarity")
		if slot and bot:GetItemSlotType(slot) == ITEM_SLOT_TYPE_BACKPACK then
			local targetSlot = Fu.Item.GetMainInvLessValItemSlot(bot)
			if targetSlot ~= -1 then
				bot:ActionImmediate_SwapItems(slot, targetSlot)
			end
		end
		lastClaritySwapTime = DotaTime()
	end
end
function TrySwapInvItemForFlask()
	if DotaTime() >= lastFlaskSwapTime + 6.2 and bot:GetActiveMode() ~= BOT_MODE_WARD then
		local slot = bot:FindItemSlot("item_flask")
		if slot and bot:GetItemSlotType(slot) == ITEM_SLOT_TYPE_BACKPACK then
			local targetSlot = Fu.Item.GetMainInvLessValItemSlot(bot)
			if targetSlot ~= -1 then
				bot:ActionImmediate_SwapItems(slot, targetSlot)
			end
		end
		lastFlaskSwapTime = DotaTime()
	end
end
function TrySwapInvItemForMoonshard()
	if DotaTime() >= lastMoonShardSwapTime + 10.0 and bot:GetActiveMode() ~= BOT_MODE_WARD then
		local slot = bot:FindItemSlot("item_moon_shard")
		if slot and bot:GetItemSlotType(slot) == ITEM_SLOT_TYPE_BACKPACK then
			local targetSlot = Fu.Item.GetMainInvLessValItemSlot(bot)
			if targetSlot ~= -1 then
				bot:ActionImmediate_SwapItems(slot, targetSlot)
			end
		end
		lastMoonShardSwapTime = DotaTime()
	end
end
function TrySwapInvItemForCheese()
	if DotaTime() >= lastCheeseSwapTime + 2.3 and bot:GetActiveMode() ~= BOT_MODE_WARD then
		local slot = bot:FindItemSlot("item_cheese")
		if bot:GetItemSlotType(slot) == ITEM_SLOT_TYPE_BACKPACK then
			local targetSlot = Fu.Item.GetMainInvLessValItemSlot(bot)
			if targetSlot ~= -1 then
				bot:ActionImmediate_SwapItems(slot, targetSlot)
			end
		end
		lastCheeseSwapTime = DotaTime()
	end
end
function TrySwapInvItemForRefresherShard()
	if DotaTime() >= lastRefresherShardSwapTime + 2.2 and bot:GetActiveMode() ~= BOT_MODE_WARD then
		local slot = bot:FindItemSlot("item_refresher_shard")
		if bot:GetItemSlotType(slot) == ITEM_SLOT_TYPE_BACKPACK then
			local targetSlot = Fu.Item.GetMainInvLessValItemSlot(bot)
			if targetSlot ~= -1 then
				bot:ActionImmediate_SwapItems(slot, targetSlot)
			end
		end
		lastRefresherShardSwapTime = DotaTime()
	end
end
function TrySellOrDropItem()
	if DotaTime() > 0 and DotaTime() - lastSellCheckTime > 3 then
		lastSellCheckTime = DotaTime()
		if bot:GetLevel() >= 6 and bot:GetNetWorth() >= 14000 and Utils.CountBackpackEmptySpace(bot) <= 1 then
			for i = 1, #Item["tEarlyConsumableItem"] do
				local itemName = Item["tEarlyConsumableItem"][i]
				local slot = bot:FindItemSlot(itemName)
				-- Sell only. A consumable dropped in the field was picked straight back up
				-- (by the engine's own item mode, nothing of ours picks these), then dropped
				-- again 3s later: Bristleback looped a Clarity at 55:30.
				if slot >= 6 and slot <= 8 and bot:DistanceFromFountain() <= 300 then
					pcall(print, string.format(
						"[OHA-ITEM] t=%.0f %s consumable-sold %s",
						DotaTime(),
						(string.gsub(bot:GetUnitName(), "npc_dota_hero_", "")),
						(string.gsub(itemName, "^item_", ""))
					))
					bot:ActionImmediate_SellItem(bot:GetItemInSlot(slot))
				end
			end
		end
	end
end
function Fu.FindLeastExpensiveItemSlot()
	local lowestCost = 100000
	local cheapestSlot = -1
	for slot = 0, 5 do
		if
			bot:GetItemInSlot(slot) ~= nil
			and bot:GetItemInSlot(slot):GetName() ~= "item_aegis"
			and bot:GetItemInSlot(slot):GetName() ~= "item_rapier"
		then
			local itemName = bot:GetItemInSlot(slot):GetName()
			if GetItemCost(itemName) < lowestCost and not (itemName == "item_ward_observer" or itemName == "item_ward_sentry") then
				lowestCost = GetItemCost(itemName)
				cheapestSlot = slot
			end
		end
	end
	return cheapestSlot
end
-- Hold the desire through short dips while this mode is active (FuncLib/systems/mode_hold.lua).
GetDesire = require(GetScriptDirectory() .. "/FuncLib/systems/mode_hold").Wrap(GetDesire, "team_roam", BOT_MODE_TEAM_ROAM)
if SafeCall then
	local originalGetDesire = GetDesire
	local originalThink = Think
	if originalGetDesire then
		GetDesire = SafeCall(originalGetDesire, 0, "TEAM_ROAM_GetDesire")
	end
	if originalThink then
		Think = SafeCall(originalThink, nil, "TEAM_ROAM_Think")
	end
end
TeamRoam.GetDesire = GetDesire
TeamRoam.Think = Think
return TeamRoam
