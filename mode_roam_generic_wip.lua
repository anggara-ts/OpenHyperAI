-- Unfinished roam mode. The _wip suffix keeps Dota from loading it.
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local CustomLoader = require(GetScriptDirectory() .. "/FuncLib/systems/custom_loader")
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
local highPriorityAbility = nil
local shouldTinkerWaitInBase = false
local shouldWaitInBaseToHeal = false
local tpScroll = nil
local isMovingToUnit = false
local moveTargetUnit = nil
local shouldMoveOutsideFountain = false
local lastMoveOutsideFountainTime = 0
local shouldTpToLane = false
local tpToLaneLocation = nil
local fountainExitDistance = 1500
local bearLeashRange = 1100
local tetherRange = 1000
local heroSpecificDesire = {}
local gankLane = nil
local gankLaneStartTime = 0
local gankLaneCommitTime = 30
local twinGates = Fu.Utils.GameStates.twinGates
local twinGateToUse
local twinGatePortalWarpAbility = bot:GetAbilityByName("twin_gate_portal_warp")
local canUseTwinGate = false
local lastNearGankLaneTime = 0
local gankLaneTimeout = 15
local gankCooldown = 3 * 60
local staticLinkStackLimit = 0
local isChainFrostThreat = false
local shouldMoveSafely = false
local shouldSpreadOut = false
local chainFrostBounceRange = 600 + 150
local lastTombstoneSlowTime = 0
local nearbyEnemies, nearbyAllies, nearbyAllyTowers, nearbyEnemyTowers, shouldRetreatToTower, shouldRetreat, botTarget, isReturningToHeal, closeEnemies, closeAllies, hpRatio
local tangoSlot
local laneTier1Towers = { { LANE_TOP, TOWER_TOP_1 }, { LANE_MID, TOWER_MID_1 }, { LANE_BOT, TOWER_BOT_1 } }
local roamReason = "none"
function GetDesire()
	if ShouldSkipBotThink(GetBot()) then
		return 0
	end
	local roamDesire = GetDesireHelper()
	if roamDesire > 0 then
		log(
			"[ROAM] %s t=%.0f desire=%.2f reason=%s hp=%.2f enemies=%d allies=%d",
			bot:GetUnitName(),
			DotaTime(),
			roamDesire,
			roamReason,
			Fu.GetHP(bot),
			nearbyEnemies and #nearbyEnemies or -1,
			nearbyAllies and #nearbyAllies or -1
		)
	end
	return roamDesire
end
function GetDesireHelper()
	botName = bot:GetUnitName()
	if bot:IsInvulnerable() or not bot:IsHero() or not bot:IsAlive() or not string.find(botName, "hero") or bot:IsIllusion() then
		return BOT_MODE_DESIRE_NONE
	end
	shouldRetreatToTower = false
	shouldRetreat = false
	hpRatio = Fu.GetHP(bot)
	tpScroll = Fu.Utils.GetItemFromFullInventory(bot, "item_tpscroll")
	botTarget = Fu.GetProperTarget(bot)
	nearbyEnemies = bot:GetNearbyHeroes(1200, true, BOT_MODE_NONE)
	nearbyAllies = bot:GetNearbyHeroes(1600, false, BOT_MODE_NONE)
	closeEnemies = bot:GetNearbyHeroes(1000, true, BOT_MODE_NONE)
	closeAllies = bot:GetNearbyHeroes(1000, false, BOT_MODE_NONE)
	nearbyAllyTowers = bot:GetNearbyTowers(1600, false)
	nearbyEnemyTowers = bot:GetNearbyTowers(1600, true)
	if
		bot:HasModifier("modifier_skeleton_king_reincarnation_scepter_active")
		or bot:HasModifier("modifier_item_helm_of_the_undying_active")
	then
		local weakestUnit = Fu.GetVulnerableWeakestUnit(bot, true, true, bot:GetAttackRange() + 250)
		if Fu.IsValidHero(weakestUnit) then
			bot:SetTarget(weakestUnit)
			roamReason = "wk_scepter_undying"
			return BOT_MODE_DESIRE_ABSOLUTE * 2
		end
	end
	shouldTinkerWaitInBase = TinkerWaitInBaseAndHeal()
	if shouldTinkerWaitInBase then
		roamReason = "tinker_base_heal"
		return BOT_ACTION_DESIRE_ABSOLUTE
	end
	if bot:HasModifier("modifier_fountain_aura_buff") and DotaTime() > 0 and DotaTime() - lastMoveOutsideFountainTime < 2 then
		roamReason = "fountain_move_outside"
		return Clamp(bot:GetActiveModeDesire() + 0.2, 0, 1.1)
	else
		shouldMoveOutsideFountain = false
	end
	if ConsiderHeroMoveOutsideFountain() then
		shouldMoveOutsideFountain = true
		lastMoveOutsideFountainTime = DotaTime()
		roamReason = "hero_move_outside_fountain"
		return Clamp(bot:GetActiveModeDesire() + 0.2, 0, 1.1)
	end
	local heroDesireFunc = heroSpecificDesire[botName]
	if heroDesireFunc then
		local heroDesire = heroDesireFunc()
		if heroDesire and heroDesire > 0 then
			roamReason = "hero_specific_" .. botName
			if heroDesire <= 1 then
				return Clamp(heroDesire, 0, 0.6)
			else
				return heroDesire
			end
		end
	end
	local generalDesire = ConsiderGeneralRoamingInConditions()
	if generalDesire then
		if generalDesire > 0 and generalDesire <= 1 then
			roamReason = "general_condition"
			return Clamp(generalDesire, 0, 0.6)
		else
			roamReason = "general_condition_override"
			return generalDesire
		end
	end
	return BOT_MODE_DESIRE_NONE
end
function Think()
	if Fu.CanNotUseAction(bot) then
		return
	end
	if bot:HasModifier("modifier_fountain_aura_buff") and shouldTpToLane == false and (Fu.GetHP(bot) < 0.8 or Fu.GetMP(bot) < 0.8) then
		return
	end
	nearbyEnemies = bot:GetNearbyHeroes(1200, true, BOT_MODE_NONE)
	if shouldRetreat and nearbyEnemies and #nearbyEnemies >= 2 then
		local attackRange = bot:GetAttackRange()
		local nearestMeleeAlly = nil
		local nearestDistance = math.huge
		local allies = bot:GetNearbyHeroes(1600, false, BOT_MODE_NONE)
		for _, allyHero in pairs(allies or {}) do
			if Fu.IsValidHero(allyHero) and allyHero ~= bot and allyHero:GetAttackRange() < 350 and allyHero:IsAlive() then
				local distance = GetUnitToUnitDistance(bot, allyHero)
				if distance < nearestDistance then
					nearestDistance = distance
					nearestMeleeAlly = allyHero
				end
			end
		end
		if nearestMeleeAlly ~= nil then
			local enemyCenter = Fu.GetCenterOfUnits(nearbyEnemies)
			local retreatLocation = Fu.VectorAway(nearestMeleeAlly:GetLocation(), enemyCenter, 250)
			local weakestUnit = Fu.GetAttackableWeakestUnit(bot, attackRange, true, true)
			if weakestUnit then
				bot:Action_AttackUnit(weakestUnit, false)
			else
				bot:Action_MoveToLocation(retreatLocation)
			end
			return
		else
			local enemyCenter = Fu.GetCenterOfUnits(nearbyEnemies)
			local retreatLocation = Fu.VectorAway(bot:GetLocation(), enemyCenter, 200)
			local weakestUnit = Fu.GetAttackableWeakestUnit(bot, attackRange, true, true)
			if weakestUnit then
				bot:Action_AttackUnit(weakestUnit, false)
			else
				bot:Action_MoveToLocation(retreatLocation)
			end
			return
		end
	end
	local target = Fu.GetProperTarget(bot)
	if Fu.IsValidHero(target) and target:HasModifier("modifier_item_blade_mail_reflect") and target:GetHealth() > bot:GetHealth() then
		local botLocation = bot:GetLocation()
		if target:IsFacingLocation(botLocation, 40) then
			bot:Action_ClearActions(false)
			bot:Action_MoveToLocation(Fu.AdjustLocationWithOffsetTowardsFountain(botLocation, 400))
			return
		end
		local enemies = bot:GetNearbyHeroes(1000, true, BOT_MODE_NONE)
		local otherEnemyCount = 0
		for _, enemyHero in pairs(enemies or {}) do
			if Fu.IsValidHero(enemyHero) and enemyHero ~= target then
				otherEnemyCount = otherEnemyCount + 1
			end
		end
		if bot:GetHealth() > target:GetHealth() and otherEnemyCount == 0 then
			bot:Action_ClearActions(false)
			bot:Action_MoveToLocation(target:GetLocation())
			return
		end
		bot:Action_ClearActions(false)
		bot:Action_MoveToLocation(Fu.AdjustLocationWithOffsetTowardsFountain(botLocation, 400))
		return
	end
	if ThinkIndividualRoaming() then
		return
	end
	if ThinkGeneralRoaming() then
		return
	end
	if ThinkActualGankingInLanes() then
		return
	end
	if bot:GetCurrentActionType() == BOT_ACTION_TYPE_NONE then
		local enemiesInAttackRange = bot:GetNearbyHeroes(bot:GetAttackRange() + 100, true, BOT_MODE_NONE)
		if enemiesInAttackRange and #enemiesInAttackRange >= 1 and Fu.IsValidHero(enemiesInAttackRange[1]) and Fu.CanBeAttacked(enemiesInAttackRange[1]) then
			bot:Action_AttackUnit(enemiesInAttackRange[1], false)
		else
			bot:Action_MoveToLocation(Fu.AdjustLocationWithOffsetTowardsFountain(bot:GetLocation(), 300))
		end
	end
end
function ThinkIndividualRoaming()
	local hpRatio = Fu.GetHP(bot)
	if shouldWaitInBaseToHeal then
		if GetUnitToLocationDistance(bot, Fu.GetTeamFountain()) > 150 then
			nearbyEnemies = Fu.GetEnemiesNearLoc(bot:GetLocation(), 1400)
			if Fu.Item.GetItemCharges(bot, "item_tpscroll") >= 1 and nearbyEnemies ~= nil and #nearbyEnemies == 0 then
				if botName == "npc_dota_hero_furion" then
					local teleportationAbility = bot:GetAbilityByName("furion_teleportation")
					if teleportationAbility:IsTrained() and teleportationAbility:IsFullyCastable() then
						bot:Action_UseAbilityOnLocation(teleportationAbility, Fu.GetTeamFountain())
						return true
					end
				end
				if tpScroll ~= nil and not tpScroll:IsNull() and tpScroll:IsFullyCastable() then
					log("[TP] %s t=%.0f ROAM tp to fountain", bot:GetUnitName(), DotaTime())
					bot:Action_UseAbilityOnLocation(tpScroll, Fu.GetTeamFountain())
					return true
				end
			end
		else
			if hpRatio < 0.85 or Fu.GetMP(bot) < 0.85 then
				bot:Action_MoveToLocation(bot:GetLocation() + 150)
				return true
			else
				shouldWaitInBaseToHeal = false
			end
		end
	end
	if shouldTinkerWaitInBase then
		if hpRatio < 0.8 or Fu.GetMP(bot) < 0.8 then
			bot:Action_MoveToLocation(Fu.GetTeamFountain())
			return true
		end
	end
	if bot:HasModifier("modifier_spirit_breaker_charge_of_darkness") then
		if bot.chargeRetreat and #nearbyEnemies == 0 then
			if IsLocationPassable(bot:GetLocation()) then
				bot.chargeRetreat = false
				bot:Action_MoveToLocation(bot:GetLocation() + RandomVector(150))
				return true
			end
		end
	end
	if bot:HasModifier("modifier_batrider_flaming_lasso_self") then
		bot:Action_MoveToLocation(Fu.GetTeamFountain())
		return true
	end
	if bot.canVendettaKill then
		if Fu.IsValid(bot.vendettaTarget) then
			if GetUnitToUnitDistance(bot, bot.vendettaTarget) > bot:GetAttackRange() + 200 then
				bot:Action_MoveToLocation(bot.vendettaTarget:GetLocation())
				return true
			else
				bot:Action_AttackUnit(bot.vendettaTarget, true)
				return true
			end
		end
	end
	if bot:HasModifier("modifier_pangolier_gyroshell") then
		if Fu.IsInTeamFight(bot, 1600) then
			local target = nil
			local maxHealth = 0
			for _, enemyHero in pairs(GetUnitList(UNIT_LIST_ENEMY_HEROES)) do
				if
					Fu.IsValidHero(enemyHero)
					and Fu.IsInRange(bot, enemyHero, 2200)
					and Fu.CanBeAttacked(enemyHero)
					and Fu.CanCastOnNonMagicImmune(enemyHero)
					and not enemyHero:HasModifier("modifier_faceless_void_chronosphere_freeze")
					and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
					and maxHealth < enemyHero:GetHealth()
				then
					maxHealth = enemyHero:GetHealth()
					target = enemyHero
				end
			end
			if target ~= nil then
				local predictedLocation = Fu.GetCorrectLoc(target, 0.2)
				bot:Action_MoveToLocation(predictedLocation)
				return true
			end
		end
		if Fu.IsRetreating(bot) then
			bot:Action_MoveToLocation(Fu.GetTeamFountain())
			return true
		end
		local enemies = bot:GetNearbyHeroes(880, true, BOT_MODE_NONE)
		if Fu.IsValidHero(enemies[1]) and not enemies[1]:HasModifier("modifier_faceless_void_chronosphere_freeze") then
			bot:Action_MoveToLocation(Fu.GetCorrectLoc(enemies[1], 0.2))
			return true
		end
		local creeps = bot:GetNearbyCreeps(880, true)
		if Fu.IsValid(creeps[1]) then
			bot:Action_MoveToLocation(Fu.GetCorrectLoc(creeps[1], 0.2))
			return true
		end
	end
	if bot:HasModifier("modifier_primal_beast_trample") then
		local allies = Fu.GetAlliesNearLoc(bot:GetLocation(), 1200)
		local enemies = Fu.GetEnemiesNearLoc(bot:GetLocation(), 1200)
		if #enemies > #allies + 1 or not Fu.WeAreStronger(bot, 800) and hpRatio < 0.55 or #enemies > 0 and hpRatio < 0.3 then
			TrampleToBase()
			return true
		end
		if bot.trample_status ~= nil and type(bot.trample_status) == "table" then
			if bot.trample_status[1] == "engaging" then
				if Fu.IsValidHero(bot.trample_status[3]) then
					DoTrample(Fu.GetCorrectLoc(bot.trample_status[3], 0.2))
					return true
				elseif #enemies > 0 then
					local target = nil
					local maxHealth = 0
					for _, enemyHero in pairs(enemies) do
						if
							Fu.IsValidHero(enemyHero)
							and Fu.IsInRange(bot, enemyHero, 2200)
							and Fu.CanBeAttacked(enemyHero)
							and Fu.CanCastOnNonMagicImmune(enemyHero)
							and not enemyHero:HasModifier("modifier_faceless_void_chronosphere_freeze")
							and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
							and maxHealth < enemyHero:GetHealth()
						then
							maxHealth = enemyHero:GetHealth()
							target = enemyHero
						end
					end
					if target ~= nil then
						DoTrample(Fu.GetCorrectLoc(target, 0.2))
						return true
					end
				else
					if #allies >= #enemies and Fu.WeAreStronger(bot, 800) then
						for _, allyHero in pairs(allies) do
							if Fu.IsValidHero(allyHero) and not Fu.IsSuspiciousIllusion(allyHero) then
								local allyTarget = allyHero:GetAttackTarget()
								if Fu.IsValidHero(allyTarget) then
									DoTrample(Fu.GetCorrectLoc(allyTarget, 0.2))
									return true
								end
							end
						end
					end
				end
				return false
			elseif bot.trample_status[1] == "retreating" then
				TrampleToBase()
				return true
			elseif bot.trample_status[1] == "farming" or bot.trample_status[1] == "laning" then
				local creeps = bot:GetNearbyCreeps(1200, true)
				if Fu.IsValid(creeps[1]) and Fu.CanBeAttacked(creeps[1]) then
					local aoe = bot:FindAoELocation(true, false, creeps[1]:GetLocation(), 0, 300, 0, 0)
					if aoe.count > 0 then
						DoTrample(aoe.targetloc)
						return true
					end
				else
					TrampleToBase()
					return true
				end
			elseif bot.trample_status[1] == "miniboss" then
				if Fu.IsValid(bot.trample_status[3]) then
					DoTrample(bot.trample_status[2])
					return true
				else
					TrampleToBase()
					return true
				end
			end
		end
		TrampleToBase()
		return true
	end
	if
		bot:HasModifier("modifier_primal_beast_onslaught_windup")
		or bot:HasModifier("modifier_prevent_taunts")
		or bot:HasModifier("modifier_primal_beast_onslaught_movement_adjustable")
	then
		if bot.onslaught_status ~= nil then
			if bot.onslaught_status[1] == "engage" then
				if Fu.IsValidHero(bot.onslaught_status[2]) then
					bot:Action_MoveToLocation(Fu.GetCorrectLoc(bot.onslaught_status[2], 0.3))
					return true
				else
					local target = nil
					local minHealth = math.huge
					for _, enemyHero in pairs(GetUnitList(UNIT_LIST_ENEMY_HEROES)) do
						if
							Fu.IsValidHero(enemyHero)
							and Fu.IsInRange(bot, enemyHero, 1600)
							and Fu.CanBeAttacked(enemyHero)
							and not Fu.IsEnemyBlackHoleInLocation(enemyHero:GetLocation())
							and not Fu.IsEnemyChronosphereInLocation(enemyHero:GetLocation())
							and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
						then
							local health = enemyHero:GetHealth()
							if health < minHealth then
								minHealth = health
								target = enemyHero
							end
						end
					end
					if target ~= nil then
						bot:Action_MoveToLocation(Fu.GetCorrectLoc(target, 0.3))
						return true
					end
					for playerIndex = 1, #GetTeamPlayers(GetTeam()) do
						local teammate = GetTeamMember(playerIndex)
						if Fu.IsValidHero(teammate) and Fu.IsInRange(bot, teammate, 1600) then
							local teammateTarget = teammate:GetAttackTarget()
							if
								Fu.IsValidHero(teammateTarget)
								and Fu.IsInRange(bot, teammateTarget, 1600)
								and not Fu.IsEnemyBlackHoleInLocation(teammateTarget:GetLocation())
								and not Fu.IsEnemyChronosphereInLocation(teammateTarget:GetLocation())
								and not teammateTarget:HasModifier("modifier_necrolyte_reapers_scythe")
							then
								bot:Action_MoveToLocation(Fu.GetCorrectLoc(teammateTarget, 0.3))
								return true
							end
						end
					end
				end
			end
		elseif bot.onslaught_status[1] == "retreat" then
			bot:Action_MoveToLocation(bot.onslaught_status[2])
			return true
		elseif bot.onslaught_status[1] == "farm" then
			local creeps = bot:GetNearbyCreeps(800, true)
			if Fu.IsValid(creeps[1]) and not Fu.IsRunning(creeps[1]) and Fu.CanBeAttacked(creeps[1]) then
				local aoe = bot:FindAoELocation(true, false, creeps[1]:GetLocation(), 0, 200, 0, 0)
				if #creeps >= 4 and aoe.count >= 4 or #creeps >= 2 and aoe.count >= 2 and creeps[1]:IsAncientCreep() then
					bot:Action_MoveToLocation(aoe.targetloc)
					return true
				end
			end
		end
	end
	if bot:HasModifier("modifier_phoenix_sun_ray") then
		local sunRayWidth = 130
		local sunRayRange = 1150
		local faceLocation = Fu.GetFaceTowardDistanceLocation(bot, sunRayRange)
		if Fu.IsValidHero(bot.sun_ray_target) then
			bot:Action_MoveToLocation(bot.sun_ray_target:GetLocation())
			return true
		end
		local enemies = bot:GetNearbyHeroes(sunRayRange, true, BOT_MODE_NONE)
		for _, enemyHero in pairs(enemies) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
				and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
				and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
			then
				bot.sun_ray_target = enemyHero
				bot:Action_MoveToLocation(enemyHero:GetLocation())
				return true
			end
		end
		local allies = bot:GetNearbyHeroes(sunRayRange, false, BOT_MODE_NONE)
		for _, allyHero in pairs(allies) do
			if
				Fu.IsValidHero(allyHero)
				and bot ~= allyHero
				and Fu.GetHP(allyHero) < 0.5
				and allyHero:WasRecentlyDamagedByAnyHero(3.5)
				and not allyHero:IsIllusion()
				and bot:IsFacingLocation(allyHero:GetLocation(), 60)
			then
				if
					not Fu.IsRunning(allyHero)
					or allyHero:IsStunned()
					or allyHero:IsRooted()
					or allyHero:IsHexed()
					or allyHero:HasModifier("modifier_bane_fiends_grip")
					or allyHero:HasModifier("modifier_faceless_void_chronosphere_freeze")
					or allyHero:HasModifier("modifier_enigma_black_hole_pull")
				then
					bot.sun_ray_target = allyHero
					bot:Action_MoveToLocation(allyHero:GetLocation())
					return true
				end
			end
		end
	end
	if bot:HasModifier("modifier_snapfire_mortimer_kisses") then
		local kissesTarget = GetMortimerKissesTarget()
		if kissesTarget ~= nil then
			local travelDelay = GetUnitToUnitDistance(bot, kissesTarget) / 1300 + 0.3
			bot:Action_MoveToLocation(Fu.GetCorrectLoc(kissesTarget, travelDelay))
			return true
		end
	end
	if isMovingToUnit then
		if moveTargetUnit ~= nil then
			if GetUnitToUnitDistance(bot, moveTargetUnit) > 350 then
				bot:Action_MoveToLocation(moveTargetUnit:GetLocation())
				return true
			end
		end
	end
	if bot:HasModifier("modifier_void_spirit_dissimilate_phase") then
		local target = Fu.GetProperTarget(bot)
		if Fu.IsGoingOnSomeone(bot) then
			if Fu.IsValidTarget(target) then
				bot:Action_MoveToLocation(target:GetLocation())
			end
		end
		if Fu.IsRetreating(bot) then
			bot:Action_MoveToLocation(Fu.GetEscapeLoc())
		end
		return true
	end
	if bot:HasModifier("modifier_marci_unleash") then
		local target = Fu.GetProperTarget(bot)
		if Fu.IsValidTarget(target) and GetUnitToUnitDistance(bot, target) > bot:GetAttackRange() + 200 then
			bot:Action_MoveToLocation(target:GetLocation())
			return true
		else
			bot:Action_AttackUnit(target, false)
			return true
		end
	end
	if bot:HasModifier("modifier_muerta_pierce_the_veil_buff") then
		local target = Fu.GetProperTarget(bot)
		if Fu.IsValidTarget(target) and GetUnitToUnitDistance(bot, target) > bot:GetAttackRange() + 200 then
			bot:Action_MoveToLocation(target:GetLocation())
			return true
		else
			bot:Action_AttackUnit(target, false)
			return true
		end
	end
	if bot:HasModifier("modifier_razor_static_link_buff") then
		local target = Fu.GetProperTarget(bot)
		if Fu.IsValidTarget(target) then
			local distance = GetUnitToUnitDistance(bot, target)
			if distance > bot:GetAttackRange() then
				bot:Action_MoveToLocation(target:GetLocation() + RandomVector(200))
				return true
			elseif distance <= bot:GetAttackRange() / 2 then
				bot:Action_AttackUnit(target, false)
				return true
			end
		end
	end
	if bot:HasModifier("modifier_faceless_void_chronosphere") then
		local target = Fu.GetProperTarget(bot)
		if Fu.IsValidTarget(target) and GetUnitToUnitDistance(bot, target) > bot:GetAttackRange() + 200 then
			bot:Action_MoveToLocation(target:GetLocation())
			return true
		else
			bot:Action_AttackUnit(target, false)
			return true
		end
	end
	if bot:HasModifier("modifier_leshrac_pulse_nova") then
		local target = Fu.GetProperTarget(bot)
		if Fu.IsValidTarget(target) and GetUnitToUnitDistance(bot, target) > 400 then
			bot:Action_MoveToLocation(target:GetLocation())
			return true
		else
			bot:ActionQueue_AttackUnit(target, false)
			return true
		end
	end
	if bot:HasModifier("modifier_wisp_tether") and Fu.IsValid(bot.stateTetheredHero) then
		if GetUnitToUnitDistance(bot, bot.stateTetheredHero) > tetherRange - 400 then
			bot:Action_MoveToLocation(bot.stateTetheredHero:GetLocation())
			return true
		else
			local target = Fu.GetProperTarget(bot)
			if Fu.IsValidTarget(target) then
				bot:ActionQueue_AttackUnit(target, false)
				return true
			end
			return false
		end
	end
	if botName == "npc_dota_hero_lone_druid_bear" then
		if Fu.IsTryingtoUseAbility(bot) then
			return false
		end
		local loneDruid = Fu.Utils.GetLoneDruid(bot).hero
		local distanceToHero = GetUnitToUnitDistance(Fu.Utils.GetLoneDruid(bot).hero, bot)
		local target = loneDruid:GetAttackTarget() or Fu.GetProperTarget(loneDruid) or Fu.GetProperTarget(bot)
		if distanceToHero > bearLeashRange then
			bot:Action_MoveToLocation(loneDruid:GetLocation())
			return true
		end
		local canAttack = #bot:GetNearbyLaneCreeps(400, true) < 3 and #bot:GetNearbyTowers(800, true) == 0 or bot:GetLevel() >= 3
		if Fu.Utils.IsValidUnit(target) and distanceToHero <= bearLeashRange and GetUnitToUnitDistance(loneDruid, target) < bearLeashRange + 250 and canAttack then
			if GetUnitToUnitDistance(loneDruid, target) > loneDruid:GetAttackRange() + 200 then
				bot:Action_MoveToLocation(target:GetLocation())
				return true
			else
				bot:Action_AttackUnit(target, false)
				return true
			end
		end
		target = Fu.GetAttackableWeakestUnitFromList(loneDruid, loneDruid:GetNearbyHeroes(bearLeashRange + 250, true, BOT_MODE_NONE))
		if target ~= nil and canAttack then
			bot:Action_AttackUnit(target, false)
			return true
		end
		return false
	end
	if botName == "npc_dota_hero_pudge" then
		local rotAbility = bot:GetAbilityByName("pudge_rot")
		if rotAbility:GetToggleState() then
			local target = Fu.GetProperTarget(bot)
			if Fu.IsValidTarget(target) and GetUnitToUnitDistance(bot, target) > 400 then
				bot:Action_MoveToLocation(target:GetLocation())
				return true
			end
		end
		bot:ActionQueue_AttackUnit(botTarget, false)
		return true
	end
	if botName == "npc_dota_hero_nevermore" then
		if Fu.Utils.IsTruelyInvisible(bot) then
			local target = Fu.GetProperTarget(bot)
			if Fu.IsValidTarget(target) and GetUnitToUnitDistance(bot, target) > 400 then
				bot:Action_MoveToLocation(target:GetLocation())
				return true
			end
		end
	end
	return false
end
local trampleIndex = 12
local tramplePoints = {}
function DoTrample(center)
	tramplePoints = Fu.Utils.GetCirclarPointsAroundCenterPoint(center, 300, 12)
	if trampleIndex < 12 then
		bot:Action_MoveToLocation(tramplePoints[trampleIndex])
		trampleIndex = trampleIndex + 1
	else
		trampleIndex = 1
	end
end
function TrampleToBase()
	trampleIndex = 12
	tramplePoints = {}
	bot:Action_MoveToLocation(Fu.GetTeamFountain())
end
function ThinkGeneralRoaming()
	local hpRatio = Fu.GetHP(bot)
	if
		bot:HasModifier("modifier_skeleton_king_reincarnation_scepter_active")
		or bot:HasModifier("modifier_item_helm_of_the_undying_active")
	then
		local target = Fu.GetProperTarget(bot)
		if not Fu.IsValid(target) then
			target = Fu.GetVulnerableWeakestUnit(bot, true, true, bot:GetAttackRange() + 350)
		end
		if GetUnitToUnitDistance(bot, target) > bot:GetAttackRange() + 200 then
			bot:Action_MoveToLocation(target:GetLocation())
			return true
		else
			bot:Action_AttackUnit(target, false)
			return true
		end
	end
	if shouldTpToLane and tpToLaneLocation ~= nil then
		local tpScrollItem = Fu.Utils.GetItemFromFullInventory(bot, "item_tpscroll")
		if Fu.CanCastAbility(tpScrollItem) then
			log("[TP] %s t=%.0f ROAM tp to lane at (%.0f,%.0f)", bot:GetUnitName(), DotaTime(), tpToLaneLocation.x, tpToLaneLocation.y)
			bot:Action_UseAbilityOnLocation(tpScrollItem, tpToLaneLocation)
			shouldTpToLane = false
			return true
		end
	end
	if shouldMoveOutsideFountain then
		bot:Action_AttackMove(
			Fu.Utils.GetOffsetLocationTowardsTargetLocation(Fu.GetTeamFountain(), Fu.GetEnemyFountain(), fountainExitDistance)
		)
		return true
	end
	if isReturningToHeal then
		if bot:HasModifier("modifier_fountain_aura_buff") or hpRatio > 0.8 and Fu.GetMP(bot) > 0.7 then
			isReturningToHeal = false
		end
	end
	if isChainFrostThreat then
		Fu.Utils.SmartSpreadOut(bot, chainFrostBounceRange, chainFrostBounceRange, nearbyEnemies, false)
		return true
	end
	if shouldMoveSafely then
		Fu.Utils.MoveBotSafely(bot)
		return true
	end
	if shouldSpreadOut then
		Fu.Utils.SmartSpreadOut(bot, 450, 450, nearbyEnemies, false)
		return true
	end
	if
		bot:GetActiveMode() == BOT_MODE_ITEM
		and bot:GetActiveModeDesire() > BOT_MODE_DESIRE_VERYHIGH
		and (
			botName == "npc_dota_hero_lone_druid_bear"
			or bot:HasModifier("modifier_arc_warden_tempest_double")
			or Fu.IsMeepoClone(bot)
		)
	then
		bot:Action_MoveToLocation(Fu.GetTeamFountain())
		return true
	end
	if bot:HasModifier("modifier_item_mask_of_madness_berserk") then
		local target = Fu.GetProperTarget(bot)
		if Fu.IsValid(target) then
			if GetUnitToUnitDistance(bot, target) > bot:GetAttackRange() + 200 then
				bot:Action_MoveToLocation(target:GetLocation())
				return true
			else
				bot:Action_AttackUnit(target, false)
				return true
			end
		end
	end
	if Fu.GetModifierTime(bot, "modifier_flask_healing") >= 1 then
		if #(bot:GetNearbyHeroes(1000, true, BOT_MODE_NONE) or {}) >= 1 and hpRatio < 0.8 then
			bot:Action_MoveToLocation(Fu.GetTeamFountain())
			return true
		end
	end
	if bot:HasModifier("modifier_nevermore_shadowraze_debuff") then
		MoveAwayFromTarget(GetTargetEnemy("npc_dota_hero_nevermore"), 1350)
		return true
	end
	if bot:HasModifier("modifier_razor_static_link_debuff") then
		MoveAwayFromTarget(GetTargetEnemy("npc_dota_hero_razor"), 1200)
		return true
	end
	if bot:HasModifier("modifier_primal_beast_trample") then
		MoveAwayFromTarget(GetTargetEnemy("npc_dota_hero_primal_beast"), 1200)
		return true
	end
	if botName == "npc_dota_hero_lone_druid" then
		if hpRatio < 0.65 or Fu.GetMP(bot) < 0.35 then
			bot:Action_MoveToLocation(Fu.GetTeamFountain())
			return true
		end
	end
	if bot:HasModifier("modifier_ursa_fury_swipes_damage_increase") then
		bot:Action_MoveToLocation(Fu.GetTeamFountain())
		return true
	end
	if bot:HasModifier("modifier_monkey_king_quadruple_tap_counter") then
		bot:Action_MoveToLocation(Fu.GetTeamFountain())
		return true
	end
	if bot:HasModifier("modifier_slark_essence_shift_debuff_counter") then
		bot:Action_MoveToLocation(Fu.GetTeamFountain())
		return true
	end
	if bot:HasModifier("modifier_silencer_glaives_of_wisdom_debuff_counter") then
		bot:Action_MoveToLocation(Fu.GetTeamFountain())
		return true
	end
	if bot:HasModifier("modifier_dazzle_poison_touch") then
		bot:Action_MoveToLocation(Fu.GetTeamFountain())
		return true
	end
	if bot:HasModifier("modifier_maledict") then
		bot:Action_MoveToLocation(Fu.GetTeamFountain())
		return true
	end
	if bot:HasModifier("modifier_viper_poison_attack_slow") then
		bot:Action_MoveToLocation(Fu.GetTeamFountain())
		return true
	end
	if Fu.GetModifierCount(bot, "modifier_huskar_burning_spear_debuff") >= 3 then
		bot:Action_MoveToLocation(Fu.GetTeamFountain())
		return true
	end
	if Fu.GetModifierCount(bot, "modifier_batrider_sticky_napalm") >= 3 then
		bot:Action_MoveToLocation(Fu.GetTeamFountain())
		return true
	end
	if bot:HasModifier("modifier_undying_tombstone_zombie_deathstrike_slow") then
		bot:Action_MoveToLocation(Fu.GetTeamFountain())
		return true
	end
	if Fu.GetModifierCount(bot, "modifier_bristleback_quill_spray") >= 3 then
		bot:Action_MoveToLocation(Fu.GetTeamFountain())
		return true
	end
	if shouldRetreatToTower then
		nearbyAllyTowers = bot:GetNearbyTowers(1600, false)
		if nearbyAllyTowers[1] then
			local botFountainDistance = GetUnitToLocationDistance(bot, Fu.GetTeamFountain())
			local towerFountainDistance = GetUnitToLocationDistance(nearbyAllyTowers[1], Fu.GetTeamFountain())
			local towerDistance = GetUnitToUnitDistance(bot, nearbyAllyTowers[1])
			if botFountainDistance > towerFountainDistance and towerDistance > 300 then
				bot:Action_MoveToLocation(nearbyAllyTowers[1]:GetLocation() + RandomVector(150))
			else
				bot:Action_MoveToLocation(Fu.GetTeamFountain())
			end
			return true
		end
	end
	if shouldRetreat then
		bot:Action_MoveToLocation(Fu.GetTeamFountain())
		return true
	end
	if isReturningToHeal then
		bot:Action_MoveToLocation(Fu.GetTeamFountain())
		return true
	end
	return false
end
function GeneralReactToStackedDebuff(heroName)
	local enemyHero = GetTargetEnemy(heroName)
	if enemyHero ~= nil then
		if Fu.GetHP(bot) > 0.6 and Fu.Utils.NumActionTypeInQueue(bot, BOT_ACTION_TYPE_ATTACK) <= 2 then
			bot:ActionImmediate_Ping(enemyHero:GetLocation().x, enemyHero:GetLocation().y, true)
			bot:ActionQueue_AttackUnit(enemyHero, false)
		else
			local fountainLocation = Fu.GetTeamFountain()
			bot:Action_MoveToLocation(fountainLocation)
		end
	end
end
function MoveAwayFromTarget(target, range)
	if Fu.IsValidHero(target) and GetUnitToUnitDistance(bot, target) < range then
		if GetUnitToLocationDistance(target, Fu.GetTeamFountain()) > GetUnitToLocationDistance(bot, Fu.GetTeamFountain()) then
			bot:Action_MoveToLocation(Fu.GetTeamFountain())
		else
			bot:Action_MoveToLocation(
				Fu.Utils.GetOffsetLocationTowardsTargetLocation(target:GetLocation(), bot:GetLocation(), range * 2)
			)
		end
	end
end
function ActualGankDesire()
	SetupTwinGates()
	if Fu.IsInLaningPhase() and not bot:WasRecentlyDamagedByAnyHero(2) and (botTarget == nil or #nearbyEnemies <= 0 or nearbyEnemies[1] ~= botTarget) then
		local level = bot:GetLevel()
		if
			Fu.GetPosition(bot) == 2 and level >= 6 and Fu.GetHP(bot) > 0.8 and Fu.GetMP(bot) > 0.6
			or Fu.GetPosition(bot) == 4 and level >= 5 and Fu.GetHP(bot) > 0.7 and Fu.GetMP(bot) > 0.6
			or Fu.GetPosition(bot) == 5 and level >= 4 and Fu.GetHP(bot) > 0.7 and Fu.GetMP(bot) > 0.6
		then
			return CheckLaneToGank(Fu.GetPosition(bot))
		end
	end
	return BOT_MODE_DESIRE_NONE
end
function SetupTwinGates()
	if #twinGates == 0 then
		for _, unit in pairs(GetUnitList(UNIT_LIST_ALL)) do
			local unitName = unit:GetUnitName()
			if unitName == "npc_dota_unit_twin_gate" then
				table.insert(twinGates, unit)
				log("Twin gate: %s. %s", unitName, unit:GetLocation())
			end
			if #twinGates >= 2 then
				break
			end
		end
	end
end
function ThinkActualGankingInLanes()
	if gankLane ~= nil then
		local enemyCount = Fu.GetEnemyCountInLane(gankLane)
		if enemyCount == 0 then
			gankLane = nil
			bot:Action_MoveToLocation(GetLaneFrontLocation(GetTeam(), bot:GetAssignedLane(), 0))
			return true
		end
		local laneFront = GetLaneFrontLocation(GetTeam(), gankLane, -300)
		local laneFrontDistance = GetUnitToLocationDistance(bot, laneFront)
		if laneFrontDistance > 5000 then
			if Fu.GetPosition(bot) > 3 and twinGateToUse ~= nil and canUseTwinGate then
				log("Trying to use gate %s", botName)
				local gateDistance = GetUnitToUnitDistance(bot, twinGateToUse)
				if gateDistance > 350 then
					bot:Action_MoveToLocation(twinGateToUse:GetLocation())
					return true
				elseif twinGatePortalWarpAbility:IsFullyCastable() then
					bot:Action_UseAbilityOnEntity(twinGatePortalWarpAbility, twinGateToUse)
					return true
				end
			end
		end
		if laneFrontDistance > bot:GetAttackRange() + 300 and bot:WasRecentlyDamagedByAnyHero(1.5) then
			bot:Action_MoveToLocation(laneFront)
		end
		if laneFrontDistance < 600 and DotaTime() - lastNearGankLaneTime > gankLaneTimeout * 1.1 then
			lastNearGankLaneTime = DotaTime()
		end
		if DotaTime() - lastNearGankLaneTime > gankLaneTimeout then
			gankLane = nil
		end
	end
	return false
end
function OnStart() end
function OnEnd()
	gankLane = nil
	twinGateToUse = nil
	if isReturningToHeal and IsInHealthyState() then
		isReturningToHeal = false
	end
end
function IsInHealthyState()
	return botName ~= "npc_dota_hero_huskar" and Fu.GetHP(bot) > 0.7 and Fu.GetMP(bot) > 0.6
end
function CheckLaneToGank(position)
	if #Fu.GetEnemiesNearLoc(bot:GetLocation(), 800) > 0 then
		return BOT_MODE_DESIRE_NONE
	end
	if DotaTime() - gankLaneStartTime <= gankLaneCommitTime and gankLane ~= nil then
		local enemyCount = Fu.GetEnemyCountInLane(gankLane)
		if enemyCount == 0 then
			gankLane = nil
			gankLaneStartTime = 0
			return BOT_MODE_DESIRE_NONE
		end
		return BOT_ACTION_DESIRE_VERYHIGH
	end
	local position = Fu.GetPosition(bot)
	if Fu.IsInLaningPhase() then
		if position == 1 or position == 2 then
			return BOT_MODE_DESIRE_NONE
		end
	end
	local isTooLowLevel = position == 1 and botLevel < 10
		or position == 2 and botLevel < 8
		or position == 3 and botLevel < 8
		or position == 4 and botLevel < 5
		or position == 5 and botLevel < 4
	if DotaTime() - gankLaneStartTime < gankCooldown and gankLaneStartTime ~= 0 or isTooLowLevel then
		return BOT_MODE_DESIRE_NONE
	end
	if not HasSufficientMana(300) then
		return BOT_MODE_DESIRE_NONE
	end
	local bestLane = nil
	local bestDesire = 0
	for _, laneTower in pairs(laneTier1Towers) do
		local enemyCount = Fu.GetEnemyCountInLane(laneTower[1])
		if enemyCount > 0 then
			local tower = GetTower(GetTeam(), laneTower[2])
			if tower ~= nil then
				local laneFront = GetLaneFrontLocation(GetTeam(), laneTower[1], 0)
				local towerToFrontDistance = GetUnitToLocationDistance(tower, laneFront)
				local alliesNearFront = Fu.GetAlliesNearLoc(laneFront, 1200)
				local botToFrontDistance = GetUnitToLocationDistance(bot, laneFront)
				if botToFrontDistance > 4000 and not Fu.HasItem(bot, "item_tpscroll") then
					goto bc
				end
				if laneTower[1] == bot:GetAssignedLane() then
					goto bc
				end
				local isNearTower = towerToFrontDistance < 2000
				local hasAllyAtFront = #alliesNearFront >= 1
				if isNearTower and hasAllyAtFront then
					local desire = RemapValClamped(botToFrontDistance, 4000, 600, BOT_ACTION_DESIRE_MODERATE, BOT_ACTION_DESIRE_HIGH)
					if enemyCount <= #alliesNearFront then
						desire = desire + 0.1
					end
					if desire > bestDesire then
						bestDesire = desire
						bestLane = laneTower[1]
					end
				end
			end
		end
		::bc::
	end
	if bestLane then
		gankLane = bestLane
		gankLaneStartTime = DotaTime()
		return Clamp(bestDesire, 0, BOT_ACTION_DESIRE_VERYHIGH)
	end
	return BOT_MODE_DESIRE_NONE
end
function HasSufficientMana(manaThreshold)
	return bot:GetMana() > manaThreshold and botName ~= "npc_dota_hero_huskar"
end
function GetGateNearLane(location)
	local minDistance = 99999
	local nearestGate
	for _, gate in pairs(twinGates) do
		local distance = GetUnitToLocationDistance(gate, location)
		if distance < minDistance then
			nearestGate = gate
			minDistance = distance
		end
	end
	return nearestGate
end
function TinkerWaitInBaseAndHeal()
	if botName == "npc_dota_hero_tinker" and bot.healInBase and GetUnitToLocationDistance(bot, Fu.GetTeamFountain()) < 500 then
		return true
	end
	return false
end
function GetMortimerKissesTarget()
	for _, enemyHero in pairs(GetUnitList(UNIT_LIST_ENEMY_HEROES)) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.IsInRange(bot, enemyHero, 3000 + 275 / 2)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and not Fu.IsInRange(bot, enemyHero, 600)
		then
			if Fu.IsLocationInChrono(enemyHero:GetLocation()) or Fu.IsLocationInBlackHole(enemyHero:GetLocation()) then
				return enemyHero
			end
		end
		if
			Fu.IsValidHero(enemyHero)
			and Fu.IsInRange(bot, enemyHero, 3000 + 275 / 2)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and not Fu.IsInRange(bot, enemyHero, 600)
			and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
			and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
			and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
			and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			return enemyHero
		end
	end
	local creeps = bot:GetNearbyCreeps(1600, true)
	if Fu.IsValid(creeps[1]) then
		return creeps[1]
	end
	return nil
end
-- Not called anywhere yet: it returns a desire and the tree to eat a tango on, for a caller to cast.
function ConsiderUseTango()
	if bot:HasModifier("modifier_tango_heal") then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	tangoSlot = Fu.FindItemSlotNotInNonbackpack(bot, "item_tango")
	if tangoSlot < 0 then
		tangoSlot = Fu.FindItemSlotNotInNonbackpack(bot, "item_tango_single")
	end
	if tangoSlot >= 0 and bot:OriginalGetMaxHealth() - bot:OriginalGetHealth() > 150 and Fu.GetHP(bot) < 0.75 then
		local trees = bot:GetNearbyTrees(800)
		local tree = trees[1]
		local enemies = Fu.GetNearbyHeroes(bot, 1000, true, BOT_MODE_NONE)
		local nearestEnemy = enemies[1]
		local enemyTowers = bot:GetNearbyTowers(1400, true)
		local enemyTower = enemyTowers[1]
		if tree ~= nil then
			local treeLocation = GetTreeLocation(tree)
			if
				IsLocationVisible(treeLocation)
				and IsLocationPassable(treeLocation)
				and (#enemies == 0 or GetUnitToLocationDistance(bot, treeLocation) * 1.6 < GetUnitToUnitDistance(bot, nearestEnemy))
				and (#enemyTowers == 0 or GetUnitToLocationDistance(enemyTower, treeLocation) > 920)
			then
				return BOT_ACTION_DESIRE_HIGH, tree
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function ConsiderWaitInBaseToHeal()
	local teleportationAbility = nil
	if botName == "npc_dota_hero_furion" then
		teleportationAbility = bot:GetAbilityByName("furion_teleportation")
	end
	if
		not Fu.IsInLaningPhase()
		and not (Fu.IsFarming(bot) and Fu.IsAttacking(bot))
		and nearbyEnemies ~= nil
		and #nearbyEnemies == 0
		and GetUnitToUnitDistance(bot, GetAncient(GetOpposingTeam())) > 2400
		and (tpScroll ~= nil and tpScroll:IsFullyCastable() or teleportationAbility ~= nil and teleportationAbility:IsTrained() and teleportationAbility:IsFullyCastable())
	then
		if
			Fu.GetHP(bot) < 0.25
				and bot:GetHealthRegen() < 15
				and botName ~= "npc_dota_hero_huskar"
				and botName ~= "npc_dota_hero_slark"
				and botName ~= "npc_dota_hero_necrolyte"
				and not bot:HasModifier("modifier_tango_heal")
				and not bot:HasModifier("modifier_flask_healing")
				and not bot:HasModifier("modifier_alchemist_chemical_rage")
				and not bot:HasModifier("modifier_arc_warden_tempest_double")
				and not bot:HasModifier("modifier_juggernaut_healing_ward_heal")
				and not bot:HasModifier("modifier_oracle_purifying_flames")
				and not bot:HasModifier("modifier_warlock_fatal_bonds")
				and not bot:HasModifier("modifier_item_satanic_unholy")
				and not bot:HasModifier("modifier_item_spirit_vessel_heal")
				and not bot:HasModifier("modifier_item_urn_heal")
			or (
					Fu.IsCore(bot) and Fu.GetMP(bot) < 0.25 and (Fu.GetHP(bot) < 0.75 and bot:GetHealthRegen() < 10)
					or not Fu.IsCore(bot) and Fu.GetMP(bot) < 0.25 and bot:GetHealthRegen() < 10
				)
				and botName ~= "npc_dota_hero_necrolyte"
				and not (Fu.IsPushing(bot) and #Fu.GetAlliesNearLoc(bot:GetLocation(), 900) >= 3)
		then
			shouldWaitInBaseToHeal = true
			return true
		end
	end
	return false
end
function ConsiderHeroMoveOutsideFountain()
	if DotaTime() < 0 then
		return false
	end
	if bot:DistanceFromFountain() > fountainExitDistance then
		return false
	end
	if Fu.GetEnemiesAroundAncient(bot, 3200) > 0 then
		return false
	end
	if
		bot:HasModifier("modifier_fountain_aura_buff")
		and Fu.GetHP(bot) > 0.95
		and (botName == "npc_dota_hero_huskar" or bot:GetActiveMode() == BOT_MODE_ITEM and Fu.GetMP(bot) > 0.95)
	then
		return true
	end
	if bot:GetActiveMode() == BOT_MODE_ITEM then
		for _, droppedItem in pairs(GetDroppedItemList()) do
			if droppedItem ~= nil and GetUnitToLocationDistance(bot, droppedItem.location) < 1200 then
				local itemName = droppedItem.item:GetName()
				if not (itemName == "item_aegis" or itemName == "item_rapier" or itemName == "item_cheese" or itemName == "item_gem") then
					return true
				end
			end
		end
	end
	return false
end
function CanBeAffectedByChainFrost()
	if bot:HasModifier("modifier_black_king_bar_immune") or bot:IsMagicImmune() then
		return false
	end
	local range = chainFrostBounceRange
	if Fu.HasEnemyIceSpireNearby(bot, range) then
		return true
	end
	if bot:HasModifier("modifier_lich_chainfrost_slow") then
		local allyCreeps = bot:GetNearbyCreeps(range, false)
		if #allyCreeps > 0 then
			return true
		end
		local allies = bot:GetNearbyHeroes(range, false, BOT_MODE_NONE)
		if #allies > 1 then
			return true
		end
	end
	return Fu.AnyAllyAffectedByChainFrost(bot, range)
end
function ConsiderGeneralRoamingInConditions()
	local hpRatio = Fu.GetHP(bot)
	if hpRatio < 0.35 then
		return BOT_ACTION_DESIRE_NONE
	end
	if nearbyEnemies and nearbyAllies and #nearbyEnemies > #nearbyAllies + 1 and not Fu.WeAreStronger(bot, 1200) then
		return BOT_ACTION_DESIRE_NONE
	end
	if bot:HasModifier("modifier_item_mask_of_madness_berserk") then
		if Fu.IsValid(botTarget) and hpRatio > 0.3 then
			return BOT_ACTION_DESIRE_VERYHIGH
		end
	end
	if Fu.GetModifierTime(bot, "modifier_flask_healing") >= 1.5 then
		if #closeEnemies >= 1 and hpRatio < 0.8 then
			return BOT_ACTION_DESIRE_VERYHIGH
		end
	end
	if
		bot:HasModifier("modifier_skeleton_king_reincarnation_scepter_active")
		or bot:HasModifier("modifier_item_helm_of_the_undying_active")
	then
		if not Fu.IsValidHero(botTarget) then
			botTarget = Fu.GetAttackableWeakestUnit(bot, 1600, true, true)
		end
		if Fu.IsValidHero(botTarget) then
			bot:SetTarget(botTarget)
			return BOT_ACTION_DESIRE_ABSOLUTE * 2
		end
	end
	if bot:HasModifier("modifier_razor_static_link_debuff") then
		local staticLinkStacks = Fu.GetModifierCount(bot, "modifier_razor_static_link_debuff")
		if staticLinkStacks > staticLinkStackLimit then
			local enemyHero = GetTargetEnemy("npc_dota_hero_razor")
			if enemyHero ~= nil and hpRatio - 0.2 < Fu.GetHP(enemyHero) and GetUnitToUnitDistance(bot, enemyHero) <= 850 then
				return BOT_ACTION_DESIRE_ABSOLUTE * 1.1
			end
		end
	end
	if bot:HasModifier("modifier_bloodseeker_rupture") then
		if Fu.IsRunning(bot) and not Fu.IsAttacking(bot) then
			return 0.4
		end
		if not closeEnemies or #closeEnemies == 0 then
			return 0.5
		end
	end
	if botName == "npc_dota_hero_lone_druid" and not bot:HasModifier("modifier_lone_druid_true_form") then
		if
			nearbyEnemies
			and Fu.IsValidHero(nearbyEnemies[1])
			and Fu.IsInRange(bot, nearbyEnemies[1], math.max(bot:GetAttackRange(), nearbyEnemies[1]:GetAttackRange()) - 250)
		then
			return 0.4
		end
	end
	if Fu.IsInLaningPhase() then
		local quillStacks = Fu.GetModifierCount(bot, "modifier_bristleback_quill_spray")
		if quillStacks >= 3 then
			local enemyHero = GetTargetEnemy("npc_dota_hero_bristleback")
			if
				enemyHero ~= nil
				and (#nearbyEnemies >= #nearbyAllies or enemyHero:GetLevel() >= bot:GetLevel())
				and hpRatio < Fu.GetHP(enemyHero) + 0.2
				and GetUnitToUnitDistance(bot, enemyHero) <= 900
				and GetUnitToLocationDistance(bot, Fu.GetTeamFountain()) > 1000
			then
				return RemapValClamped(quillStacks / hpRatio, 10, 50, BOT_ACTION_DESIRE_LOW, BOT_ACTION_DESIRE_VERYHIGH)
			end
		end
	end
	if bot:HasModifier("modifier_primal_beast_trample") then
		local enemyHero = GetTargetEnemy("npc_dota_hero_primal_beast")
		local distance = GetUnitToUnitDistance(bot, enemyHero)
		if enemyHero ~= nil and hpRatio - 0.2 < Fu.GetHP(enemyHero) and distance <= 500 and distance > 250 then
			return BOT_ACTION_DESIRE_VERYHIGH
		end
	end
	isChainFrostThreat = CanBeAffectedByChainFrost()
	if isChainFrostThreat then
		local hasLowHpEnemy = false
		for _, enemyHero in pairs(closeEnemies) do
			if Fu.Utils.IsValidHero(enemyHero) and not Fu.IsSuspiciousIllusion(enemyHero) and Fu.GetHP(enemyHero) < 0.2 then
				hasLowHpEnemy = true
			end
		end
		if not hasLowHpEnemy then
			local allyCount = #closeAllies
			local currentHp = hpRatio
			return Clamp(0.35 + 0.35 * (allyCount >= 2 and 1 or 0) + 0.3 * (currentHp < 0.6 and 1 or 0), 0.35, 0.55)
		end
		isChainFrostThreat = false
	end
	if
		bot:GetActiveMode() == BOT_MODE_ITEM
		and bot:GetActiveModeDesire() > BOT_MODE_DESIRE_VERYHIGH
		and (
			botName == "npc_dota_hero_lone_druid_bear"
			or bot:HasModifier("modifier_arc_warden_tempest_double")
			or Fu.IsMeepoClone(bot)
		)
	then
		for _, droppedItem in pairs(GetDroppedItemList()) do
			if droppedItem ~= nil and droppedItem.item:GetName() == "item_aegis" and GetUnitToLocationDistance(bot, droppedItem.location) < 300 then
				return BOT_ACTION_DESIRE_VERYHIGH
			end
		end
	end
	local isFighting = Fu.IsAttacking(bot)
		or bot:GetActiveMode() == BOT_MODE_ATTACK and bot:GetActiveModeDesire() > 0.5
		or bot:WasRecentlyDamagedByAnyHero(2.0)
		or Fu.IsGoingOnSomeone(bot)
		or Fu.IsInTeamFight(bot, 1200)
	shouldSpreadOut = not isFighting and not Fu.IsInLaningPhase() and Fu.Utils.ShouldBotsSpreadOut(bot, 450)
	if shouldSpreadOut then
		roamReason = "spread_out_aoe"
		return 0.91
	end
	if Fu.IsInLaningPhase() then
		if
			not bot:WasRecentlyDamagedByAnyHero(1.5)
			and not Fu.HasHealingItem(bot)
			and botName ~= "npc_dota_hero_huskar"
			and (isReturningToHeal and not IsInHealthyState() or (hpRatio < 0.22 or hpRatio < 0.3 and Fu.GetMP(bot) < 0.22))
		then
			isReturningToHeal = true
			return BOT_ACTION_DESIRE_ABSOLUTE * 1.5
		end
		if Fu.GetModifierCount(bot, "modifier_nevermore_shadowraze_debuff") >= 2 then
			local enemyHero = GetTargetEnemy("npc_dota_hero_nevermore")
			if enemyHero ~= nil and hpRatio < Fu.GetHP(enemyHero) and GetUnitToUnitDistance(bot, enemyHero) <= 1200 then
				return BOT_ACTION_DESIRE_HIGH * 1.2
			end
		end
		if Fu.GetModifierCount(bot, "modifier_monkey_king_quadruple_tap_counter") >= 2 then
			local enemyHero = GetTargetEnemy("npc_dota_hero_monkey_king")
			if enemyHero ~= nil and hpRatio < Fu.GetHP(enemyHero) and GetUnitToUnitDistance(bot, enemyHero) <= enemyHero:GetAttackRange() * 3 then
				return BOT_ACTION_DESIRE_HIGH * 1.2
			end
		end
		if Fu.GetModifierCount(bot, "modifier_viper_poison_attack_slow") >= 2 then
			local enemyHero = GetTargetEnemy("npc_dota_hero_viper")
			if enemyHero ~= nil and hpRatio < Fu.GetHP(enemyHero) and GetUnitToUnitDistance(bot, enemyHero) <= enemyHero:GetAttackRange() * 2 then
				return BOT_ACTION_DESIRE_HIGH * 1.2
			end
		end
		if Fu.GetModifierCount(bot, "modifier_huskar_burning_spear_debuff") >= 3 then
			local enemyHero = GetTargetEnemy("npc_dota_hero_huskar")
			if enemyHero ~= nil and hpRatio < Fu.GetHP(enemyHero) + 0.2 and GetUnitToUnitDistance(bot, enemyHero) <= enemyHero:GetAttackRange() * 2 then
				return BOT_ACTION_DESIRE_HIGH * 1.2
			end
		end
		if Fu.GetModifierCount(bot, "modifier_batrider_sticky_napalm") >= 3 then
			local enemyHero = GetTargetEnemy("npc_dota_hero_batrider")
			if enemyHero ~= nil and hpRatio < Fu.GetHP(enemyHero) + 0.2 and GetUnitToUnitDistance(bot, enemyHero) <= enemyHero:GetAttackRange() * 3 then
				return BOT_ACTION_DESIRE_HIGH * 1.2
			end
		end
		if bot:HasModifier("modifier_undying_tombstone_zombie_deathstrike_slow") then
			lastTombstoneSlowTime = DotaTime()
			if Fu.IsValidTarget(botTarget) and not Fu.Utils.IsUnitWithName(botTarget, "tombstone") then
				local tombstone = Fu.FindEnemyUnit("tombstone")
				if not tombstone then
					tombstone = GetTargetEnemy("npc_dota_hero_undying")
				end
				if
					hpRatio < 0.8
					and (Fu.IsValid(tombstone) and GetUnitToUnitDistance(tombstone, bot) < 1200 or DotaTime() - lastTombstoneSlowTime < 3)
					and Fu.IsValidHero(nearbyEnemies[1])
					and Fu.GetHP(nearbyEnemies) > 0.35
				then
					return BOT_ACTION_DESIRE_HIGH * 1.2
				end
			end
		end
		if not Fu.WeAreStronger(bot, 1200) then
			if Fu.GetModifierCount(bot, "modifier_slark_essence_shift_debuff_counter") >= 2 then
				local enemyHero = GetTargetEnemy("npc_dota_hero_slark")
				if enemyHero ~= nil and hpRatio < Fu.GetHP(enemyHero) + 0.1 and GetUnitToUnitDistance(bot, enemyHero) <= 750 then
					return BOT_ACTION_DESIRE_ABSOLUTE * 1.1
				end
			end
			if Fu.GetModifierCount(bot, "modifier_silencer_glaives_of_wisdom_debuff_counter") >= 2 then
				local enemyHero = GetTargetEnemy("npc_dota_hero_silencer")
				if
					enemyHero ~= nil
					and hpRatio < 0.5
					and hpRatio < Fu.GetHP(enemyHero) + 0.1
					and GetUnitToUnitDistance(bot, enemyHero) <= enemyHero:GetAttackRange() * 2.5
				then
					return BOT_ACTION_DESIRE_HIGH
				end
			end
			if Fu.GetModifierCount(bot, "modifier_ursa_fury_swipes_damage_increase") >= 2 then
				local enemyHero = GetTargetEnemy("npc_dota_hero_ursa")
				if enemyHero ~= nil and hpRatio < Fu.GetHP(enemyHero) + 0.1 and GetUnitToUnitDistance(bot, enemyHero) <= 450 then
					return BOT_ACTION_DESIRE_HIGH
				end
			end
			if bot:HasModifier("modifier_dazzle_poison_touch") then
				local enemyHero = GetTargetEnemy("npc_dota_hero_dazzle")
				if
					enemyHero ~= nil
					and hpRatio < 0.6
					and hpRatio < Fu.GetHP(enemyHero) + 0.1
					and GetUnitToUnitDistance(bot, enemyHero) <= enemyHero:GetAttackRange() * 2
				then
					return BOT_ACTION_DESIRE_HIGH
				end
			end
			if bot:HasModifier("modifier_maledict") then
				local enemyHero = GetTargetEnemy("npc_dota_hero_witch_doctor")
				if
					enemyHero ~= nil
					and hpRatio < 0.6
					and hpRatio < Fu.GetHP(enemyHero) + 0.1
					and GetUnitToUnitDistance(bot, enemyHero) <= enemyHero:GetAttackRange() * 2
				then
					return BOT_ACTION_DESIRE_HIGH * 1.2
				end
			end
		end
		if
			#nearbyEnemies >= 1
			and #nearbyAllyTowers >= 1
			and GetUnitToUnitDistance(nearbyAllyTowers[1], bot) < 1600
			and bot:GetActiveModeDesire() < 0.9
			and #nearbyAllies <= #nearbyEnemies
		then
			for _, enemyHero in pairs(nearbyEnemies) do
				if Fu.Utils.IsValidHero(enemyHero) then
					if
						enemyHero:IsFacingLocation(bot:GetLocation(), 45)
						and Fu.IsInRange(bot, enemyHero, enemyHero:GetAttackRange() * 1.5 + 550)
						and Fu.GetHP(enemyHero) > hpRatio - 0.15
						and bot:WasRecentlyDamagedByAnyHero(5)
						and hpRatio < 0.75
						and hpRatio > 0.3
					then
						shouldRetreatToTower = true
						return BOT_ACTION_DESIRE_HIGH
					end
				end
			end
		end
	end
	if bot:WasRecentlyDamagedByTower(0.2) then
		if #closeAllies >= 2 and Fu.GetHP(closeAllies[2]) > hpRatio then
			bot:Action_AttackUnit(closeAllies[2], true)
		else
			local allyCreeps = bot:GetNearbyCreeps(1000, false)
			if #allyCreeps >= 1 and Fu.IsValid(allyCreeps[1]) and Fu.IsDeniableLaneCreep(allyCreeps[1]) then
				bot:Action_AttackUnit(allyCreeps[1], true)
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function GetTargetEnemy(heroName)
	for _, enemyHero in pairs(nearbyEnemies) do
		if Fu.IsValidHero(enemyHero) and enemyHero:GetUnitName() == heroName then
			return enemyHero
		end
	end
	return nil
end
function CheckHighPriorityChannelAbility(abilityName)
	if highPriorityAbility == nil then
		highPriorityAbility = bot:GetAbilityByName(abilityName)
	end
	if highPriorityAbility:IsTrained() and (highPriorityAbility:IsInAbilityPhase() or bot:IsChanneling()) then
		return BOT_DESIRE_OVERRIDE * 1.5
	end
	return BOT_MODE_DESIRE_NONE
end
heroSpecificDesire["npc_dota_hero_pugna"] = function()
	return CheckHighPriorityChannelAbility("pugna_life_drain")
end
heroSpecificDesire["npc_dota_hero_drow_ranger"] = function()
	return CheckHighPriorityChannelAbility("drow_ranger_multishot")
end
heroSpecificDesire["npc_dota_hero_shadow_shaman"] = function()
	return CheckHighPriorityChannelAbility("shadow_shaman_shackles")
end
heroSpecificDesire["npc_dota_hero_clinkz"] = function()
	return CheckHighPriorityChannelAbility("clinkz_burning_barrage")
end
heroSpecificDesire["npc_dota_hero_tiny"] = function()
	return CheckHighPriorityChannelAbility("tiny_tree_channel")
end
heroSpecificDesire["npc_dota_hero_hoodwink"] = function()
	if highPriorityAbility == nil then
		highPriorityAbility = bot:GetAbilityByName("hoodwink_sharpshooter")
	end
	if highPriorityAbility:IsTrained() then
		if highPriorityAbility:IsInAbilityPhase() or bot:HasModifier("modifier_hoodwink_sharpshooter_windup") then
			return BOT_DESIRE_OVERRIDE * 1.5
		end
	end
end
heroSpecificDesire["npc_dota_hero_void_spirit"] = function()
	if highPriorityAbility == nil then
		highPriorityAbility = bot:GetAbilityByName("void_spirit_dissimilate")
	end
	if highPriorityAbility:IsTrained() then
		if highPriorityAbility:IsInAbilityPhase() or bot:HasModifier("modifier_void_spirit_dissimilate_phase") then
			return BOT_DESIRE_OVERRIDE * 1.5
		end
	end
	return BOT_MODE_DESIRE_NONE
end
heroSpecificDesire["npc_dota_hero_elder_titan"] = function()
	return CheckHighPriorityChannelAbility("elder_titan_echo_stomp")
end
heroSpecificDesire["npc_dota_hero_primal_beast"] = function()
	highPriorityAbility = bot:GetAbilityByName("primal_beast_onslaught")
	if highPriorityAbility:IsTrained() then
		if
			highPriorityAbility:IsInAbilityPhase()
			or bot:HasModifier("modifier_primal_beast_onslaught_windup")
			or bot:HasModifier("modifier_prevent_taunts")
			or bot:HasModifier("modifier_primal_beast_onslaught_movement_adjustable")
		then
			return BOT_DESIRE_OVERRIDE * 1.5
		end
	end
	highPriorityAbility = bot:GetAbilityByName("primal_beast_trample")
	if highPriorityAbility:IsTrained() then
		if highPriorityAbility:IsInAbilityPhase() or bot:HasModifier("modifier_primal_beast_trample") and hpRatio > 0.3 then
			return BOT_DESIRE_OVERRIDE * 1.5
		end
	end
	highPriorityAbility = bot:GetAbilityByName("primal_beast_pulverize")
	if highPriorityAbility:IsTrained() then
		if highPriorityAbility:IsInAbilityPhase() or bot:HasModifier("modifier_primal_beast_pulverize_self") then
			return BOT_DESIRE_OVERRIDE * 1.5
		end
	end
	return BOT_MODE_DESIRE_NONE
end
heroSpecificDesire["npc_dota_hero_batrider"] = function()
	if highPriorityAbility == nil then
		highPriorityAbility = bot:GetAbilityByName("batrider_flaming_lasso")
	end
	if highPriorityAbility:IsTrained() then
		if highPriorityAbility:IsInAbilityPhase() or bot:HasModifier("modifier_batrider_flaming_lasso_self") then
			return BOT_DESIRE_OVERRIDE * 1.5
		end
	end
	return BOT_MODE_DESIRE_NONE
end
heroSpecificDesire["npc_dota_hero_enigma"] = function()
	return CheckHighPriorityChannelAbility("enigma_black_hole")
end
heroSpecificDesire["npc_dota_hero_keeper_of_the_light"] = function()
	if highPriorityAbility == nil then
		highPriorityAbility = bot:GetAbilityByName("keeper_of_the_light_illuminate")
	end
	if highPriorityAbility:IsInAbilityPhase() or bot:IsChanneling() or bot:HasModifier("modifier_keeper_of_the_light_illuminate") then
		return BOT_DESIRE_OVERRIDE * 1.5
	end
	return BOT_MODE_DESIRE_NONE
end
heroSpecificDesire["npc_dota_hero_meepo"] = function()
	return CheckHighPriorityChannelAbility("meepo_poof")
end
heroSpecificDesire["npc_dota_hero_monkey_king"] = function()
	highPriorityAbility = bot:GetAbilityByName("monkey_king_primal_spring")
	if highPriorityAbility ~= nil and highPriorityAbility:IsTrained() then
		if highPriorityAbility:IsInAbilityPhase() or bot:IsChanneling() then
			return BOT_DESIRE_OVERRIDE * 1.5
		end
	end
	if not bot:IsChanneling() and bot.tree_dance_status then
		local eta = bot.tree_dance_status.eta or 0
		local elapsed = DotaTime() - (bot.tree_dance_status.cast_time or 0)
		if elapsed > 3.0 + eta and elapsed < 4.0 + eta then
			return BOT_DESIRE_OVERRIDE * 1.5
		end
	end
	return BOT_MODE_DESIRE_NONE
end
heroSpecificDesire["npc_dota_hero_nyx_assassin"] = function()
	if highPriorityAbility == nil then
		highPriorityAbility = bot:GetAbilityByName("nyx_assassin_vendetta")
	end
	if highPriorityAbility:IsTrained() then
		if highPriorityAbility:IsInAbilityPhase() or bot:HasModifier("modifier_nyx_assassin_vendetta") then
			if bot.canVendettaKill then
				return BOT_DESIRE_OVERRIDE * 1.5
			end
		end
	end
	return BOT_MODE_DESIRE_NONE
end
heroSpecificDesire["npc_dota_hero_pangolier"] = function()
	if highPriorityAbility == nil then
		highPriorityAbility = bot:GetAbilityByName("pangolier_gyroshell")
	end
	if highPriorityAbility:IsTrained() then
		if highPriorityAbility:IsInAbilityPhase() or bot:HasModifier("modifier_pangolier_gyroshell") then
			return BOT_DESIRE_OVERRIDE * 1.5
		end
	end
	return BOT_MODE_DESIRE_NONE
end
heroSpecificDesire["npc_dota_hero_phoenix"] = function()
	highPriorityAbility = bot:GetAbilityByName("phoenix_supernova")
	if highPriorityAbility:IsTrained() then
		if bot:HasModifier("modifier_phoenix_supernova_hiding") then
			return BOT_DESIRE_OVERRIDE * 1.5
		end
	end
	highPriorityAbility = bot:GetAbilityByName("phoenix_sun_ray")
	if highPriorityAbility:IsTrained() then
		if bot:HasModifier("modifier_phoenix_sun_ray") then
			return BOT_DESIRE_OVERRIDE * 1.5
		end
	end
end
heroSpecificDesire["npc_dota_hero_puck"] = function()
	if highPriorityAbility == nil then
		highPriorityAbility = bot:GetAbilityByName("puck_phase_shift")
	end
	if highPriorityAbility:IsTrained() then
		if highPriorityAbility:IsInAbilityPhase() or bot:HasModifier("modifier_puck_phase_shift") then
			return BOT_DESIRE_OVERRIDE * 1.5
		end
	end
	return BOT_MODE_DESIRE_NONE
end
heroSpecificDesire["npc_dota_hero_ringmaster"] = function()
	if highPriorityAbility == nil then
		highPriorityAbility = bot:GetAbilityByName("ringmaster_tame_the_beasts")
	end
	if highPriorityAbility:IsTrained() then
		if highPriorityAbility:IsInAbilityPhase() or bot:HasModifier("modifier_ringmaster_tame_the_beasts") then
			return BOT_DESIRE_OVERRIDE * 1.5
		end
	end
	return BOT_MODE_DESIRE_NONE
end
heroSpecificDesire["npc_dota_hero_snapfire"] = function()
	if highPriorityAbility == nil then
		highPriorityAbility = bot:GetAbilityByName("snapfire_mortimer_kisses")
	end
	if highPriorityAbility:IsTrained() then
		if highPriorityAbility:IsInAbilityPhase() or bot:HasModifier("modifier_snapfire_mortimer_kisses") then
			return BOT_DESIRE_OVERRIDE * 1.5
		end
	end
	return BOT_MODE_DESIRE_NONE
end
heroSpecificDesire["npc_dota_hero_spirit_breaker"] = function()
	if highPriorityAbility == nil then
		highPriorityAbility = bot:GetAbilityByName("spirit_breaker_charge_of_darkness")
	end
	if highPriorityAbility:IsTrained() then
		if highPriorityAbility:IsInAbilityPhase() or bot:HasModifier("modifier_spirit_breaker_charge_of_darkness") then
			return BOT_DESIRE_OVERRIDE * 1.2
		end
	end
	return BOT_MODE_DESIRE_NONE
end
heroSpecificDesire["npc_dota_hero_windrunner"] = function()
	return CheckHighPriorityChannelAbility("windrunner_powershot")
end
heroSpecificDesire["npc_dota_hero_invoker"] = function()
	if
		Fu.IsValid(botTarget)
		and GetUnitToUnitDistance(bot, botTarget) < bot:GetAttackRange() - 100
		and (botTarget:HasModifier("modifier_invoker_tornado") or botTarget:HasModifier("modifier_item_wind_waker") or botTarget:HasModifier(
			"modifier_eul_cyclone"
		) or botTarget:HasModifier("modifier_item_cyclone") or botTarget:IsInvulnerable())
		and (Fu.GetHP(botTarget) > 0.3 or Fu.GetHP(botTarget) > hpRatio)
	then
		return BOT_DESIRE_OVERRIDE * 0.96
	end
end
heroSpecificDesire["npc_dota_hero_tinker"] = function()
	if highPriorityAbility == nil then
		highPriorityAbility = bot:GetAbilityByName("tinker_rearm")
	end
	if highPriorityAbility:IsTrained() then
		if highPriorityAbility:IsInAbilityPhase() or bot:IsChanneling() or bot:HasModifier("modifier_tinker_rearm") then
			return BOT_DESIRE_OVERRIDE * 1.5
		end
	end
	return BOT_MODE_DESIRE_NONE
end
heroSpecificDesire["npc_dota_hero_leshrac"] = function()
	if bot:HasModifier("modifier_leshrac_diabolic_edict") then
		local edictAbility = bot:GetAbilityByName("leshrac_diabolic_edict")
		if edictAbility:IsTrained() then
			local radius = edictAbility:GetSpecialValueInt("radius")
			if Fu.IsPushing(bot) then
				local enemyTowers = bot:GetNearbyTowers(1600, true)
				local enemyCreeps = bot:GetNearbyLaneCreeps(radius, true)
				if
					enemyTowers ~= nil
					and #enemyTowers >= 1
					and Fu.IsValidBuilding(enemyTowers[1])
					and Fu.CanBeAttacked(enemyTowers[1])
					and not Fu.IsInRange(bot, enemyTowers[1], radius - 75)
					and enemyCreeps ~= nil
					and #enemyCreeps <= 2
				then
					moveTargetUnit = enemyTowers[1]
					return BOT_MODE_DESIRE_VERYHIGH
				end
			end
		end
	end
	if bot:HasModifier("modifier_leshrac_pulse_nova") then
		local target = Fu.GetProperTarget(bot)
		if Fu.IsValidTarget(target) and hpRatio > Fu.GetHP(target) then
			if GetUnitToUnitDistance(bot, target) > 400 then
				return BOT_MODE_DESIRE_VERYHIGH
			end
		end
	end
	return BOT_MODE_DESIRE_NONE
end
heroSpecificDesire["npc_dota_hero_lone_druid_bear"] = function()
	if Fu.IsTryingtoUseAbility(bot) then
		return BOT_MODE_DESIRE_NONE
	end
	local loneDruid = Fu.Utils.GetLoneDruid(bot).hero
	local druidTarget = loneDruid:GetAttackTarget()
	local hasScepter = Fu.Item.HasItem(bot, "item_ultimate_scepter") or bot:HasModifier("modifier_item_ultimate_scepter_consumed")
	local distanceToHero = GetUnitToUnitDistance(Fu.Utils.GetLoneDruid(bot).hero, bot)
	if Fu.IsValidHero(loneDruid) and hpRatio >= Fu.GetHP(loneDruid) - 0.2 and hpRatio > 0.25 and not hasScepter then
		if distanceToHero > bearLeashRange then
			return BOT_DESIRE_OVERRIDE * 1.2
		end
		local canAttack = #bot:GetNearbyLaneCreeps(400, true) < 3 and #bot:GetNearbyTowers(800, true) == 0 or bot:GetLevel() >= 3
		if Fu.Utils.IsValidUnit(druidTarget) and distanceToHero <= bearLeashRange and GetUnitToUnitDistance(loneDruid, druidTarget) < bearLeashRange + 250 and canAttack then
			return BOT_DESIRE_OVERRIDE * 1.2
		end
		local target = Fu.GetAttackableWeakestUnitFromList(loneDruid, loneDruid:GetNearbyHeroes(bearLeashRange + 250, true, BOT_MODE_NONE))
		if target ~= nil and canAttack then
			return BOT_DESIRE_OVERRIDE * 1.2
		end
	end
	return BOT_MODE_DESIRE_NONE
end
heroSpecificDesire["npc_dota_hero_marci"] = function()
	if bot:HasModifier("modifier_marci_unleash") then
		local target = Fu.GetProperTarget(bot)
		if Fu.IsValidTarget(target) and hpRatio > Fu.GetHP(target) then
			if Fu.IsInTeamFight(bot, 1500) then
				return BOT_MODE_DESIRE_VERYHIGH
			end
			if Fu.IsGoingOnSomeone(bot) and #nearbyEnemies >= 1 then
				return BOT_DESIRE_OVERRIDE * 1.5
			end
		end
	end
	return BOT_MODE_DESIRE_NONE
end
heroSpecificDesire["npc_dota_hero_wisp"] = function()
	if bot:HasModifier("modifier_wisp_tether") and DotaTime() > 60 then
		if Fu.IsValid(bot.stateTetheredHero) and hpRatio > 0.5 and GetUnitToUnitDistance(bot, bot.stateTetheredHero) > tetherRange - 200 then
			return BOT_DESIRE_OVERRIDE * 0.85
		end
	end
	return BOT_MODE_DESIRE_NONE
end
heroSpecificDesire["npc_dota_hero_pudge"] = function()
	local rotAbility = bot:GetAbilityByName("pudge_rot")
	if rotAbility ~= nil and rotAbility:GetToggleState() and Fu.WeAreStronger(bot, 1200) then
		local target = Fu.GetProperTarget(bot)
		if Fu.IsValidTarget(target) and hpRatio > Fu.GetHP(target) then
			return BOT_DESIRE_OVERRIDE * 0.85
		end
	end
	return BOT_MODE_DESIRE_NONE
end
heroSpecificDesire["npc_dota_hero_muerta"] = function()
	if bot:HasModifier("modifier_muerta_pierce_the_veil_buff") then
		local target = Fu.GetProperTarget(bot)
		if Fu.IsValidTarget(target) and hpRatio > 0.2 then
			if Fu.IsInTeamFight(bot, 1500) then
				return BOT_MODE_DESIRE_VERYHIGH
			end
			if Fu.IsGoingOnSomeone(bot) and #nearbyEnemies >= 1 then
				return BOT_DESIRE_OVERRIDE * 1.5
			end
		end
	end
	return BOT_MODE_DESIRE_NONE
end
heroSpecificDesire["npc_dota_hero_razor"] = function()
	if bot:HasModifier("modifier_razor_static_link_buff") then
		local target = Fu.GetProperTarget(bot)
		if Fu.IsValidHero(target) and hpRatio > 0.3 and hpRatio >= Fu.GetHP(target) then
			if nearbyEnemyTowers == nil or #nearbyEnemyTowers == 0 or GetUnitToUnitDistance(bot, nearbyEnemyTowers[1]) > 850 then
				return BOT_MODE_DESIRE_VERYHIGH
			end
		end
	end
	return BOT_MODE_DESIRE_NONE
end
heroSpecificDesire["npc_dota_hero_faceless_void"] = function()
	if bot:HasModifier("modifier_faceless_void_chronosphere") then
		local target = Fu.GetProperTarget(bot)
		if Fu.IsValidTarget(target) and hpRatio > 0.25 and Fu.IsLocationInChrono(target:GetLocation()) then
			return BOT_MODE_DESIRE_VERYHIGH
		end
	end
	return BOT_MODE_DESIRE_NONE
end
heroSpecificDesire["npc_dota_hero_nevermore"] = function()
	bot.invisUltCombo = false
	if Fu.Utils.IsTruelyInvisible(bot) and bot:GetAbilityByName("nevermore_requiem"):IsFullyCastable() then
		local target = Fu.GetProperTarget(bot)
		if Fu.IsValidHero(target) and hpRatio > 0.5 and Fu.GetHP(target) > 0.5 and target:GetHealth() > 800 then
			if nearbyEnemyTowers == nil or #nearbyEnemyTowers == 0 or GetUnitToUnitDistance(bot, nearbyEnemyTowers[1]) > 850 then
				bot.invisUltCombo = true
				return BOT_MODE_DESIRE_VERYHIGH
			end
		end
	end
	return BOT_MODE_DESIRE_NONE
end
if SafeCall then
	local originalGetDesire = GetDesire
	local originalThink = Think
	if originalGetDesire then
		GetDesire = SafeCall(originalGetDesire, 0, "ROAM_GetDesire")
	end
	if originalThink then
		Think = SafeCall(originalThink, nil, "ROAM_Think")
	end
end
