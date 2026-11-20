-- Outpost capture mode.
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
local cachedOutposts = {}
local isOutpostCacheReady = false
local targetOutpost = nil
local targetOutpostDistance = 10000
local outpostMoveLoc = nil
local captureAbility = bot:GetAbilityByName("ability_capture")
local isCapturingOutpost = false
-- Chain Frost bouncing around us (Valve data: bounces to a hero within 550, 10 jumps). The
-- projectile is visible in GetIncomingTrackingProjectiles of whoever it is flying at. Returns the
-- ally (or this bot) it is heading to, when that one is this bot or within 700 of it.
local chainFrostSpread = false
local function ChainFrostNear()
	for _, ally in pairs(GetUnitList(UNIT_LIST_ALLIED_HEROES) or {}) do
		if
			ally ~= nil
			and not ally:IsNull()
			and ally:IsAlive()
			and (ally == bot or GetUnitToUnitDistance(bot, ally) <= 700)
		then
			for _, proj in pairs(ally:GetIncomingTrackingProjectiles() or {}) do
				local projAbility = proj.ability
				if
					projAbility ~= nil
					and not projAbility:IsNull()
					and projAbility:GetName() == "lich_chain_frost"
					and (proj.caster == nil or proj.caster:GetTeam() ~= GetTeam())
				then
					return ally
				end
			end
		end
	end
	return nil
end
local function ConsiderChainFrostSpread()
	local ok, frostTarget = pcall(ChainFrostNear)
	if not ok or frostTarget == nil then
		return false
	end
	-- Only worth moving when another ally hero is close enough to be the next bounce.
	local near = 0
	for _, ally in pairs(bot:GetNearbyHeroes(650, false, BOT_MODE_NONE) or {}) do
		if ally ~= bot and ally:IsAlive() then
			near = near + 1
		end
	end
	if near == 0 then
		return false
	end
	return true
end
-- Never inside the enemy fountain: within 1300 of it, leave (above attack and retreat). Game 019,
-- 52:04-52:21: Dire chased into the Radiant fountain after killing Mirana (Techies planted M.A.D.
-- at -7250,-6845) and four of them died. The Radiant Ancient is ~1860 from its fountain, so
-- fights at the Ancient (even its fountain side, ~1550+) stay outside this radius.
local leaveFountain = nil
-- After pos 5's early mid ward is down (ward mode set bot._earlyWardPending with the observer
-- count): walk to our own jungle's bounty spot, up to 40s.
local wardReturnTo = nil
local function ObserverCount()
	local count = 0
	for slot = 0, 8 do
		local item = bot:GetItemInSlot(slot)
		if item ~= nil then
			local itemName = item:GetName()
			if itemName == "item_ward_observer" or itemName == "item_ward_dispenser" then
				count = count + (item:GetCurrentCharges() or 0)
			end
		end
	end
	return count
end
local function WardReturnTarget()
	local now = DotaTime()
	local pending = bot._earlyWardPending
	if pending ~= nil then
		if ObserverCount() < (pending.obs or 0) then
			bot._wardReturn = { to = pending.to, untilAt = now + (pending.window or 25) }
			-- Ward mode and the horn river hold leave him alone after this (one early ward, then
			-- behind T1 and to lane).
			bot._earlyWardPlantedAt = now
			bot._earlyWardPending = nil
			pcall(
				print,
				string.format(
					"[OHA-WARD] t=%.0f %s return-start to=%.0f,%.0f dist=%.0f",
					now,
					(string.gsub(bot:GetUnitName(), "npc_dota_hero_", "")),
					pending.to.x,
					pending.to.y,
					GetUnitToLocationDistance(bot, pending.to)
				)
			)
		elseif now - pending.at > 6 then
			bot._earlyWardPending = nil
		end
	end
	local wardReturn = bot._wardReturn
	if wardReturn == nil then
		return nil
	end
	if now > wardReturn.untilAt or GetUnitToLocationDistance(bot, wardReturn.to) <= 350 or not bot:IsAlive() then
		pcall(
			print,
			string.format(
				"[OHA-WARD] t=%.0f %s return-done why=%s dist=%.0f",
				now,
				(string.gsub(bot:GetUnitName(), "npc_dota_hero_", "")),
				not bot:IsAlive() and "dead" or (now > wardReturn.untilAt and "timeout" or "reached"),
				GetUnitToLocationDistance(bot, wardReturn.to)
			)
		)
		bot._wardReturn = nil
		return nil
	end
	return wardReturn.to
end
local function EnemyFountainEscape()
	local fountain = Fu.GetEnemyFountain()
	if fountain == nil or not bot:IsAlive() then
		return nil
	end
	local distance = GetUnitToLocationDistance(bot, fountain)
	if distance > 1300 then
		return nil
	end
	local away = bot:GetLocation() - fountain
	if away:Length2D() < 1 then
		away = Fu.GetTeamFountain() - fountain
	end
	local dest = fountain + away:Normalized() * 1800
	return dest
end
function GetDesire()
	if ShouldSkipBotThink(GetBot()) then
		return 0
	end
	leaveFountain = nil
	if bot:IsHero() and not bot:IsIllusion() then
		local okF, dest = pcall(EnemyFountainEscape)
		if okF and dest ~= nil then
			leaveFountain = dest
			return 1.06
		end
	end
	wardReturnTo = nil
	if bot:IsHero() and not bot:IsIllusion() then
		local okW, to = pcall(WardReturnTarget)
		if okW and to ~= nil then
			wardReturnTo = to
			return 0.9
		end
	end
	-- Ahead of everything in this mode, above 1 so it beats attack and retreat: the old spread
	-- rule only knew an enemy Lich had Chain Frost ready, and skipped every fighting bot, so
	-- bots stood together and let the bounces hit them all.
	chainFrostSpread = false
	if bot:IsAlive() and bot:IsHero() and not bot:IsIllusion() and ConsiderChainFrostSpread() then
		chainFrostSpread = true
		return 1.05
	end
	return GetDesireHelper()
end
function GetDesireHelper()
	botName = bot:GetUnitName()
	if
		bot:IsInvulnerable()
		or not bot:IsHero()
		or not bot:IsAlive()
		or not string.find(botName, "hero")
		or bot:IsIllusion()
	then
		return BOT_MODE_DESIRE_NONE
	end
	shouldRetreatToTower = false
	shouldRetreat = false
	isCapturingOutpost = false
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
			return BOT_MODE_DESIRE_ABSOLUTE * 2
		end
	end
	shouldTinkerWaitInBase = TinkerWaitInBaseAndHeal()
	if shouldTinkerWaitInBase then
		return BOT_ACTION_DESIRE_ABSOLUTE
	end
	if
		bot:HasModifier("modifier_fountain_aura_buff")
		and DotaTime() > 0
		and DotaTime() - lastMoveOutsideFountainTime < 2
	then
		return Clamp(bot:GetActiveModeDesire() + 0.2, 0, 1.1)
	else
		shouldMoveOutsideFountain = false
	end
	if ConsiderHeroMoveOutsideFountain() then
		shouldMoveOutsideFountain = true
		lastMoveOutsideFountainTime = DotaTime()
		return Clamp(bot:GetActiveModeDesire() + 0.2, 0, 1.1)
	end
	local heroDesireFunc = heroSpecificDesire[botName]
	if heroDesireFunc then
		local heroDesire = heroDesireFunc()
		if heroDesire and heroDesire > 0 then
			if heroDesire <= 1 then
				return Clamp(heroDesire, 0, 0.6)
			else
				return heroDesire
			end
		end
	end
	-- Capture before roam so a farming/roam desire cannot skip the outpost check.
	local outpostDesire = ConsiderOutpostCapture()
	if outpostDesire > 0 then
		isCapturingOutpost = true
		return outpostDesire
	end
	local generalDesire = ConsiderGeneralRoamingInConditions()
	if generalDesire then
		if generalDesire > 0 and generalDesire <= 1 then
			return Clamp(generalDesire, 0, 0.6)
		else
			return generalDesire
		end
	end
	return BOT_MODE_DESIRE_NONE
end
function Think()
	if Fu.CanNotUseAction(bot) then
		return
	end
	if leaveFountain ~= nil then
		bot:Action_MoveToLocation(leaveFountain)
		return
	end
	if wardReturnTo ~= nil then
		bot:Action_MoveToLocation(wardReturnTo)
		return
	end
	if chainFrostSpread then
		Fu.Utils.SmartSpreadOut(bot, 650, 600, {}, false)
		return
	end
	if isCapturingOutpost then
		if bot:IsChanneling() or bot:HasModifier("modifier_watch_tower_capturing") then
			bot._outpostNearSince = nil
			return
		end
		if targetOutpost ~= nil and not targetOutpost:IsNull() and targetOutpost:GetTeam() ~= GetTeam() then
			local dist = GetUnitToUnitDistance(bot, targetOutpost)
			-- Hold still after the capture order so the 6s channel is not restarted every frame.
			if bot.outpostOrderAt ~= nil and DotaTime() - bot.outpostOrderAt < 1.5 and dist <= 650 then
				return
			end
			-- The capture order walks the bot into range by itself. Moving to the outpost centre until
			-- within 250 could never finish against the building edge: game 017, 50:23-52:43,
			-- Invoker stood at the Radiant outpost ordering a move every frame (moved 0). Within
			-- 600 the capture is cast; within 600 for 10s with no capture started, the outpost is
			-- dropped for 90s (logged).
			if dist > 600 then
				bot.outpostOrderAt = nil
				bot._outpostNearSince = nil
				bot:Action_MoveToLocation(targetOutpost:GetLocation())
				return
			end
			bot._outpostNearSince = bot._outpostNearSince or DotaTime()
			if DotaTime() - bot._outpostNearSince >= 15 then
				bot._outpostNearSince = nil
				bot._outpostOffUntil = DotaTime() + 90
				local outpostLocation = targetOutpost:GetLocation()
				pcall(
					print,
					string.format(
						"[OHA-OUTPOST] t=%.0f %s capture-giveup outpost=%s at=%.0f,%.0f dist=%d",
						DotaTime(),
						(string.gsub(bot:GetUnitName(), "npc_dota_hero_", "")),
						targetOutpost:GetUnitName(),
						outpostLocation.x,
						outpostLocation.y,
						math.floor(dist)
					)
				)
				bot:Action_ClearActions(true)
				return
			end
			local capture = bot:GetAbilityByName("ability_capture")
			local castable = capture ~= nil and capture:IsFullyCastable()
			local nearFor = DotaTime() - bot._outpostNearSince
			-- Game 019: Gyrocopter (36:31, ~260 away) and Medusa (40:51, ~140 away) stood at an
			-- outpost with no capture for 10s, from within 600. Log each order (what the bot sees
			-- of ability_capture), and after 3s with no capture, walk to the outpost's edge on
			-- the bot's side (150 from the centre) before ordering again.
			if nearFor >= 3 and dist > 200 then
				local edge = bot:GetLocation()
				local outpostLocation = targetOutpost:GetLocation()
				local dir = (edge - outpostLocation)
				if dir:Length2D() > 1 then
					edge = outpostLocation + dir:Normalized() * 150
				end
				bot.outpostOrderAt = nil
				bot:Action_MoveToLocation(edge)
				return
			end
			if castable then
				bot:Action_UseAbilityOnEntity(capture, targetOutpost)
				bot.outpostOrderAt = DotaTime()
			end
			-- No attack fallback: outposts are invulnerable, an attack order only made him stand.
			return
		end
		if outpostMoveLoc ~= nil then
			bot:Action_MoveToLocation(outpostMoveLoc)
			return
		end
	end
	if
		bot:HasModifier("modifier_fountain_aura_buff")
		and shouldTpToLane == false
		and (Fu.GetHP(bot) < 0.8 or Fu.GetMP(bot) < 0.8)
	then
		return
	end
	nearbyEnemies = bot:GetNearbyHeroes(1200, true, BOT_MODE_NONE)
	if shouldRetreat and nearbyEnemies and #nearbyEnemies >= 2 then
		local attackRange = bot:GetAttackRange()
		local nearestMeleeAlly = nil
		local nearestDistance = math.huge
		local allies = bot:GetNearbyHeroes(1600, false, BOT_MODE_NONE)
		for _, allyHero in pairs(allies or {}) do
			if
				Fu.IsValidHero(allyHero)
				and allyHero ~= bot
				and allyHero:GetAttackRange() < 350
				and allyHero:IsAlive()
			then
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
	if
		Fu.IsValidHero(target)
		and target:HasModifier("modifier_item_blade_mail_reflect")
		and target:GetHealth() > bot:GetHealth()
	then
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
		if
			enemiesInAttackRange
			and #enemiesInAttackRange >= 1
			and Fu.IsValidHero(enemiesInAttackRange[1])
			and Fu.CanBeAttacked(enemiesInAttackRange[1])
		then
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
					pcall(
						print,
						string.format(
							"[OHA-TP] outpost-mode %s t=%.0f ROAM tp to fountain",
							bot:GetUnitName(),
							DotaTime()
						)
					)
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
		if
			#enemies > #allies + 1
			or not Fu.WeAreStronger(bot, 800) and hpRatio < 0.55
			or #enemies > 0 and hpRatio < 0.3
		then
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
				if
					#creeps >= 4 and aoe.count >= 4
					or #creeps >= 2 and aoe.count >= 2 and creeps[1]:IsAncientCreep()
				then
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
		local canAttack = #bot:GetNearbyLaneCreeps(400, true) < 3 and #bot:GetNearbyTowers(800, true) == 0
			or bot:GetLevel() >= 3
		if
			Fu.Utils.IsValidUnit(target)
			and distanceToHero <= bearLeashRange
			and GetUnitToUnitDistance(loneDruid, target) < bearLeashRange + 250
			and canAttack
		then
			if GetUnitToUnitDistance(loneDruid, target) > loneDruid:GetAttackRange() + 200 then
				bot:Action_MoveToLocation(target:GetLocation())
				return true
			else
				bot:Action_AttackUnit(target, false)
				return true
			end
		end
		target = Fu.GetAttackableWeakestUnitFromList(
			loneDruid,
			loneDruid:GetNearbyHeroes(bearLeashRange + 250, true, BOT_MODE_NONE)
		)
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
			pcall(
				print,
				string.format(
					"[OHA-TP] outpost-mode %s t=%.0f ROAM tp to lane at (%.0f,%.0f)",
					bot:GetUnitName(),
					DotaTime(),
					tpToLaneLocation.x,
					tpToLaneLocation.y
				)
			)
			bot:Action_UseAbilityOnLocation(tpScrollItem, tpToLaneLocation)
			shouldTpToLane = false
			return true
		end
	end
	if shouldMoveOutsideFountain then
		bot:Action_AttackMove(
			Fu.Utils.GetOffsetLocationTowardsTargetLocation(
				Fu.GetTeamFountain(),
				Fu.GetEnemyFountain(),
				fountainExitDistance
			)
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
			local teamFountain = Fu.GetTeamFountain()
			bot:Action_MoveToLocation(teamFountain)
		end
	end
end
function MoveAwayFromTarget(target, range)
	if Fu.IsValidHero(target) and GetUnitToUnitDistance(bot, target) < range then
		if
			GetUnitToLocationDistance(target, Fu.GetTeamFountain())
			> GetUnitToLocationDistance(bot, Fu.GetTeamFountain())
		then
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
	if
		Fu.IsInLaningPhase()
		and not bot:WasRecentlyDamagedByAnyHero(2)
		and (botTarget == nil or #nearbyEnemies <= 0 or nearbyEnemies[1] ~= botTarget)
	then
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
-- The lane this bot lanes in, by position (Radiant pos 3/4 top, Dire pos 3/4 bot), the same
-- mapping laning and the laning teleport use. The engine assignment can differ, which sent a
-- support walking or teleporting to the wrong lane.
local function PositionLane()
	if IsLanMode and IsLanMode() then
		return bot:GetAssignedLane()
	end
	local pos = Fu.GetPosition(bot)
	local radiant = GetTeam() == TEAM_RADIANT
	if pos == 2 then
		return LANE_MID
	elseif pos == 1 or pos == 5 then
		return radiant and LANE_BOT or LANE_TOP
	elseif pos == 3 or pos == 4 then
		return radiant and LANE_TOP or LANE_BOT
	end
	return bot:GetAssignedLane()
end
function ThinkActualGankingInLanes()
	if gankLane ~= nil then
		local enemyCount = Fu.GetEnemyCountInLane(gankLane)
		if enemyCount == 0 then
			gankLane = nil
			bot:Action_MoveToLocation(GetLaneFrontLocation(GetTeam(), PositionLane(), 0))
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
	targetOutpost = nil
	targetOutpostDistance = 10000
	isCapturingOutpost = false
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
					goto bk
				end
				if laneTower[1] == PositionLane() then
					goto bk
				end
				local isNearTower = towerToFrontDistance < 2000
				local hasAllyAtFront = #alliesNearFront >= 1
				if isNearTower and hasAllyAtFront then
					local desire = RemapValClamped(
						botToFrontDistance,
						4000,
						600,
						BOT_ACTION_DESIRE_MODERATE,
						BOT_ACTION_DESIRE_HIGH
					)
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
		::bk::
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
	if
		botName == "npc_dota_hero_tinker"
		and bot.healInBase
		and GetUnitToLocationDistance(bot, Fu.GetTeamFountain()) < 500
	then
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
				and (#enemies == 0 or GetUnitToLocationDistance(bot, treeLocation) * 1.6 < GetUnitToUnitDistance(
					bot,
					nearestEnemy
				))
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
		and (
			tpScroll ~= nil and tpScroll:IsFullyCastable()
			or teleportationAbility ~= nil
				and teleportationAbility:IsTrained()
				and teleportationAbility:IsFullyCastable()
		)
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
				if
					not (
						itemName == "item_aegis"
						or itemName == "item_rapier"
						or itemName == "item_cheese"
						or itemName == "item_gem"
					)
				then
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
			if
				enemyHero ~= nil
				and hpRatio - 0.2 < Fu.GetHP(enemyHero)
				and GetUnitToUnitDistance(bot, enemyHero) <= 850
			then
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
			and Fu.IsInRange(
				bot,
				nearbyEnemies[1],
				math.max(bot:GetAttackRange(), nearbyEnemies[1]:GetAttackRange()) - 250
			)
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
			if
				Fu.Utils.IsValidHero(enemyHero)
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and Fu.GetHP(enemyHero) < 0.2
			then
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
			if
				droppedItem ~= nil
				and droppedItem.item:GetName() == "item_aegis"
				and GetUnitToLocationDistance(bot, droppedItem.location) < 300
			then
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
		return 0.91
	end
	if Fu.IsInLaningPhase() then
		-- A Tango heals over 16s a charge. Under 15% the hero sat in lane nibbling for a minute
		-- or more; walking or teleporting home is faster and safer. Above that, a healing item
		-- in the bag still keeps the hero in lane.
		local critical = hpRatio < 0.15
		if
			not bot:WasRecentlyDamagedByAnyHero(1.5)
			-- isReturningToHeal: already on the way home. Regen past 15% must not turn the hero back mid-walk.
			and (isReturningToHeal or critical or not Fu.HasHealingItem(bot))
			and botName ~= "npc_dota_hero_huskar"
			and (
				isReturningToHeal and not IsInHealthyState()
				or (hpRatio < 0.22 or hpRatio < 0.3 and Fu.GetMP(bot) < 0.22)
			)
		then
			if not isReturningToHeal then
				pcall(
					print,
					string.format(
						"[OHA-LANE] t=%.0f %s go-home hp=%.2f mp=%.2f healItem=%s critical=%s",
						DotaTime(),
						(string.gsub(botName, "npc_dota_hero_", "")),
						hpRatio,
						Fu.GetMP(bot),
						tostring(Fu.HasHealingItem(bot)),
						tostring(critical)
					)
				)
			end
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
			if
				enemyHero ~= nil
				and hpRatio < Fu.GetHP(enemyHero)
				and GetUnitToUnitDistance(bot, enemyHero) <= enemyHero:GetAttackRange() * 3
			then
				return BOT_ACTION_DESIRE_HIGH * 1.2
			end
		end
		if Fu.GetModifierCount(bot, "modifier_viper_poison_attack_slow") >= 2 then
			local enemyHero = GetTargetEnemy("npc_dota_hero_viper")
			if
				enemyHero ~= nil
				and hpRatio < Fu.GetHP(enemyHero)
				and GetUnitToUnitDistance(bot, enemyHero) <= enemyHero:GetAttackRange() * 2
			then
				return BOT_ACTION_DESIRE_HIGH * 1.2
			end
		end
		if Fu.GetModifierCount(bot, "modifier_huskar_burning_spear_debuff") >= 3 then
			local enemyHero = GetTargetEnemy("npc_dota_hero_huskar")
			if
				enemyHero ~= nil
				and hpRatio < Fu.GetHP(enemyHero) + 0.2
				and GetUnitToUnitDistance(bot, enemyHero) <= enemyHero:GetAttackRange() * 2
			then
				return BOT_ACTION_DESIRE_HIGH * 1.2
			end
		end
		if Fu.GetModifierCount(bot, "modifier_batrider_sticky_napalm") >= 3 then
			local enemyHero = GetTargetEnemy("npc_dota_hero_batrider")
			if
				enemyHero ~= nil
				and hpRatio < Fu.GetHP(enemyHero) + 0.2
				and GetUnitToUnitDistance(bot, enemyHero) <= enemyHero:GetAttackRange() * 3
			then
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
				if
					enemyHero ~= nil
					and hpRatio < Fu.GetHP(enemyHero) + 0.1
					and GetUnitToUnitDistance(bot, enemyHero) <= 750
				then
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
				if
					enemyHero ~= nil
					and hpRatio < Fu.GetHP(enemyHero) + 0.1
					and GetUnitToUnitDistance(bot, enemyHero) <= 450
				then
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
			if #allyCreeps >= 1 and Fu.IsValid(allyCreeps[1]) then
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
		if
			highPriorityAbility:IsInAbilityPhase()
			or bot:HasModifier("modifier_primal_beast_trample") and hpRatio > 0.3
		then
			-- Game 036: outpost/1.50 in 32 of Primal Beast's base-defence samples. Name the source
			-- (Trample lasts 5.5s, game data) and whether a fight or a lane defence was on.
			if DotaTime() >= (bot._pbOverrideLogAt or -999) then
				bot._pbOverrideLogAt = DotaTime() + 10
				local defend = 0
				for _, lane in ipairs({ LANE_TOP, LANE_MID, LANE_BOT }) do
					defend = math.max(defend, GetDefendLaneDesire(lane) or 0)
				end
				pcall(
					print,
					string.format(
						"[OHA-FLIPSRC] t=%.0f primal_beast override=1.50 why=trample enemies=%d maxDefend=%.2f",
						DotaTime(),
						#Fu.GetEnemiesNearLoc(bot:GetLocation(), 1200),
						defend
					)
				)
			end
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
	if
		highPriorityAbility:IsInAbilityPhase()
		or bot:IsChanneling()
		or bot:HasModifier("modifier_keeper_of_the_light_illuminate")
	then
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
			-- Which channel the hold protects when he is hurt (#48, game 051 9:45: he died in this hold at 8% HP,
			-- 5s after a rearm-skip, and the log could not say whether it was Rearm or a teleport).
			if Fu.GetHP(bot) < 0.5 and DotaTime() >= (bot._tinkerHoldLogAt or -999) then
				bot._tinkerHoldLogAt = DotaTime() + 3
				local active = bot:GetCurrentActiveAbility()
				pcall(
					print,
					string.format(
						"[OHA-TINKER] t=%.0f hold channel=%s rearm-mod=%s hp=%.2f enemies=%d hit=%s",
						DotaTime(),
						active ~= nil and not active:IsNull() and active:GetName() or "-",
						tostring(bot:HasModifier("modifier_tinker_rearm")),
						Fu.GetHP(bot),
						#(bot:GetNearbyHeroes(900, true, BOT_MODE_NONE) or {}),
						tostring(bot:WasRecentlyDamagedByAnyHero(1.0))
					)
				)
			end
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
	local hasScepter = Fu.Item.HasItem(bot, "item_ultimate_scepter")
		or bot:HasModifier("modifier_item_ultimate_scepter_consumed")
	local distanceToHero = GetUnitToUnitDistance(Fu.Utils.GetLoneDruid(bot).hero, bot)
	if Fu.IsValidHero(loneDruid) and hpRatio >= Fu.GetHP(loneDruid) - 0.2 and hpRatio > 0.25 and not hasScepter then
		if distanceToHero > bearLeashRange then
			return BOT_DESIRE_OVERRIDE * 1.2
		end
		local canAttack = #bot:GetNearbyLaneCreeps(400, true) < 3 and #bot:GetNearbyTowers(800, true) == 0
			or bot:GetLevel() >= 3
		if
			Fu.Utils.IsValidUnit(druidTarget)
			and distanceToHero <= bearLeashRange
			and GetUnitToUnitDistance(loneDruid, druidTarget) < bearLeashRange + 250
			and canAttack
		then
			return BOT_DESIRE_OVERRIDE * 1.2
		end
		local target = Fu.GetAttackableWeakestUnitFromList(
			loneDruid,
			loneDruid:GetNearbyHeroes(bearLeashRange + 250, true, BOT_MODE_NONE)
		)
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
		if
			Fu.IsValid(bot.stateTetheredHero)
			and hpRatio > 0.5
			and GetUnitToUnitDistance(bot, bot.stateTetheredHero) > tetherRange - 200
		then
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
			if
				nearbyEnemyTowers == nil
				or #nearbyEnemyTowers == 0
				or GetUnitToUnitDistance(bot, nearbyEnemyTowers[1]) > 850
			then
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
			if
				nearbyEnemyTowers == nil
				or #nearbyEnemyTowers == 0
				or GetUnitToUnitDistance(bot, nearbyEnemyTowers[1]) > 850
			then
				bot.invisUltCombo = true
				return BOT_MODE_DESIRE_VERYHIGH
			end
		end
	end
	return BOT_MODE_DESIRE_NONE
end
-- Primary-jungle outposts (map dump). Live units override these when the scan finds them.
local OUTPOST_FALLBACK = {
	Vector(-4096, -448, 128),
	Vector(3392, -448, 128),
}

local function IsOutpostUnit(unit)
	if unit == nil or unit:IsNull() or unit.GetUnitName == nil then
		return false
	end
	local name = string.lower(unit:GetUnitName() or "")
	if name == "" then
		return false
	end
	-- Watchers are npc_dota_lantern. Outposts are watch_tower / OutpostName.
	return string.find(name, "watch_tower", 1, true) ~= nil or string.find(name, "outpost", 1, true) ~= nil
end

local function AddOutpost(list, unit)
	if not IsOutpostUnit(unit) then
		return
	end
	for i = 1, #list do
		if list[i] == unit then
			return
		end
	end
	list[#list + 1] = unit
end

local outpostCacheAt = -999
-- One-time scan log (first bot of the team, from 0:30): every non-hero unit within 900 of the two
-- fallback outpost spots, and every unit on the map whose name looks like a building of that
-- kind, with team. Game 017: Invoker stood by the Radiant outpost and the scan matched nothing;
-- no game has ever logged an outpost. This shows the real outpost unit name, or that the bot API
-- does not list it.
local outpostScanLogged = false
local function LogOutpostScan()
	if outpostScanLogged or DotaTime() < 30 then
		return
	end
	for i = 1, 5 do
		local member = GetTeamMember(i)
		if member ~= nil and member:IsBot() then
			if member ~= bot then
				outpostScanLogged = true
				return
			end
			break
		end
	end
	outpostScanLogged = true
	local near, named = {}, {}
	for _, unit in pairs(GetUnitList(UNIT_LIST_ALL) or {}) do
		if unit ~= nil and not unit:IsNull() and not unit:IsHero() then
			local unitName = unit:GetUnitName() or "?"
			local lowerName = string.lower(unitName)
			for k = 1, #OUTPOST_FALLBACK do
				if GetUnitToLocationDistance(unit, OUTPOST_FALLBACK[k]) <= 900 then
					near[#near + 1] = unitName .. "/team" .. tostring(unit:GetTeam())
					break
				end
			end
			if
				string.find(lowerName, "watch", 1, true)
				or string.find(lowerName, "outpost", 1, true)
				or string.find(lowerName, "lantern", 1, true)
			then
				named[#named + 1] = unitName .. "/team" .. tostring(unit:GetTeam())
			end
		end
	end
	pcall(
		print,
		string.format(
			"[OHA-OUTPOST] t=%.0f scan near-spots=%s named=%s",
			DotaTime(),
			#near > 0 and table.concat(near, ",") or "-",
			#named > 0 and table.concat(named, ",") or "-"
		)
	)
end
local function RefreshOutpostCache()
	cachedOutposts = {}
	local lists = {
		UNIT_LIST_ALL,
		UNIT_LIST_ENEMY_BUILDINGS,
		UNIT_LIST_ALLIED_BUILDINGS,
	}
	for i = 1, #lists do
		for _, unit in pairs(GetUnitList(lists[i]) or {}) do
			AddOutpost(cachedOutposts, unit)
		end
	end
	isOutpostCacheReady = true
	outpostCacheAt = DotaTime()
end

-- Capture rule (from the user, 2026-11-15): the enemy-side outpost needs one of the enemy's tier-2
-- towers dead. Our own side's outpost, taken by the enemy, can be retaken any time: the rule looks
-- at whose side the outpost is on, not at towers. Our own tier-2 or the 10:00 clock does not
-- unlock the enemy-side one.
-- A tier-2 counts as dead only after that lane's tier-1 is gone too, so a nil tower list at game start does not qualify.
local function EnemyTier2Down()
	local enemy = GetOpposingTeam()
	local lanes = {
		{ TOWER_TOP_1, TOWER_TOP_2 },
		{ TOWER_MID_1, TOWER_MID_2 },
		{ TOWER_BOT_1, TOWER_BOT_2 },
	}
	local anyTower = false
	for i = 1, #lanes do
		if GetTower(enemy, lanes[i][1]) ~= nil or GetTower(enemy, lanes[i][2]) ~= nil then
			anyTower = true
			break
		end
	end
	if not anyTower then
		return false
	end
	for i = 1, #lanes do
		if GetTower(enemy, lanes[i][1]) == nil and GetTower(enemy, lanes[i][2]) == nil then
			return true
		end
	end
	return false
end

local function HeroHp(hero)
	if hero == nil or hero:GetMaxHealth() <= 0 then
		return 0
	end
	return hero:GetHealth() / hero:GetMaxHealth()
end

local function IsBusyPushing(hero)
	if hero == nil or hero:IsNull() then
		return false
	end
	local towers = hero:GetNearbyTowers(900, true)
	if towers == nil or #towers == 0 then
		return false
	end
	local allies = hero:GetNearbyHeroes(1200, false, BOT_MODE_NONE)
	return allies ~= nil and #allies >= 2
end

local function CanThisBotCapture()
	if not bot:IsAlive() or HeroHp(bot) < 0.45 then
		return false
	end
	if Fu.IsRetreating(bot) and bot:GetActiveModeDesire() > BOT_MODE_DESIRE_HIGH then
		return false
	end
	if bot:WasRecentlyDamagedByAnyHero(1.5) then
		local near = bot:GetNearbyHeroes(900, true, BOT_MODE_NONE)
		if near ~= nil and #near >= 1 then
			return false
		end
	end
	local target = Fu.GetProperTarget(bot)
	if Fu.IsDoingRoshan(bot) and Fu.IsRoshan(target) and Fu.IsAttacking(bot) then
		return false
	end
	if Fu.IsDoingTormentor(bot) and Fu.IsTormentor(target) and Fu.IsAttacking(bot) then
		return false
	end
	local fight = bot:GetNearbyHeroes(700, true, BOT_MODE_NONE)
	if fight ~= nil and #fight >= 2 then
		return false
	end
	return true
end

-- Only the closest free hero walks over. A grouped tower siege stays put if someone else can go.
local function AmAssignedCapturer(loc)
	local myDist = GetUnitToLocationDistance(bot, loc)
	local myBusy = IsBusyPushing(bot)
	for i = 1, #GetTeamPlayers(GetTeam()) do
		local ally = GetTeamMember(i)
		if
			ally ~= nil
			and ally ~= bot
			and ally:IsHero()
			and ally:IsAlive()
			and not ally:IsIllusion()
			and HeroHp(ally) >= 0.45
		then
			local allyDist = GetUnitToLocationDistance(ally, loc)
			local allyBusy = IsBusyPushing(ally)
			if not allyBusy and allyDist + 250 < myDist then
				return false
			end
			if myBusy and not allyBusy and allyDist < myDist + 3500 then
				return false
			end
		end
	end
	return true
end

-- Enemies within this of the outpost make walking over a fight, not a capture.
local OUTPOST_CONTEST = 1600

local function OutpostIsTooHot(loc)
	local enemies = Fu.GetEnemiesNearLoc(loc, OUTPOST_CONTEST)
	local enemyCount = enemies ~= nil and #enemies or 0
	if enemyCount == 0 then
		return false
	end
	-- An enemy beside the bot on the walk over is just as much a fight as one on the outpost.
	local beside = bot:GetNearbyHeroes(OUTPOST_CONTEST, true, BOT_MODE_NONE)
	if beside ~= nil and #beside > enemyCount then
		enemyCount = #beside
	end
	local allies = Fu.GetAlliesNearLoc(loc, OUTPOST_CONTEST)
	local allyN = allies ~= nil and #allies or 0
	if GetUnitToLocationDistance(bot, loc) <= OUTPOST_CONTEST then
		allyN = math.max(allyN, 1)
	end
	-- One enemy keeps the nearest ally contesting; two or more needs a clear majority.
	if enemyCount == 1 then
		return allyN < 1
	end
	return allyN <= enemyCount
end

function ConsiderOutpostCapture()
	outpostMoveLoc = nil
	-- Stop a capture in progress once enemy heroes show up and we do not outnumber them. The
	-- 6s channel was never cancelled: Doom kept capturing with Tusk and Enigma on him.
	-- Only the capture itself: a plain IsChanneling() check would also cancel ults like Black Hole.
	if bot:HasModifier("modifier_watch_tower_capturing") then
		local foes = bot:GetNearbyHeroes(1200, true, BOT_MODE_NONE) or {}
		local friends = bot:GetNearbyHeroes(1200, false, BOT_MODE_NONE) or {}
		if #foes >= 1 and #friends <= #foes then
			pcall(
				print,
				string.format(
					"[OHA-OUTPOST] t=%.0f %s capture-abort foes=%d allies=%d hp=%.2f",
					DotaTime(),
					(string.gsub(bot:GetUnitName(), "npc_dota_hero_", "")),
					#foes,
					#friends,
					Fu.GetHP(bot)
				)
			)
			bot:Action_ClearActions(true)
			bot.outpostOrderAt = nil
			return 0
		end
	end
	-- No global tower gate any more: GetClosestOutpost only offers outposts this team may take.
	if Fu.GetEnemiesAroundAncient(bot, 3200) > 0 then
		return 0
	end
	if Fu.Utils.CountEnemyHeroesOnHighGround(GetTeam()) >= 1 then
		return 0
	end
	if not CanThisBotCapture() then
		return 0
	end
	if DotaTime() < (bot._outpostOffUntil or -999) then
		return 0
	end
	if not isOutpostCacheReady or #cachedOutposts == 0 or DotaTime() - outpostCacheAt > 2 then
		RefreshOutpostCache()
	end
	targetOutpost, targetOutpostDistance = GetClosestOutpost()
	local loc = nil
	if targetOutpost ~= nil and not targetOutpost:IsNull() then
		loc = targetOutpost:GetLocation()
	elseif #cachedOutposts > 0 then
		-- Both outposts are already ours.
		targetOutpost = nil
		return 0
	else
		targetOutpost = nil
		-- Without the scan the owner is unknown, so only walk to the enemy-side spot, and only
		-- once it may be taken. Our own side's outpost is retaken only when the scan sees it.
		if not EnemyTier2Down() then
			return 0
		end
		-- Scan missed the buildings. Walk to the outpost closer to the enemy fountain
		-- (their jungle outpost, or ours if they already took it and it is the nearer spot).
		-- Arrived and still no outpost found: drop the fallback for 90s. Game 017, 50:23-52:43:
		-- Invoker stood on the fallback spot by the Radiant outpost at desire 0.98, re-ordering a
		-- move to where he already was, with nothing to capture.
		if DotaTime() < (bot._outpostFallbackOffUntil or -999) then
			return 0
		end
		local enemyFountain = Fu.GetEnemyFountain()
		local best = 100000
		for i = 1, #OUTPOST_FALLBACK do
			local spot = OUTPOST_FALLBACK[i]
			local score = enemyFountain ~= nil and Fu.GetDistance(spot, enemyFountain)
				or GetUnitToLocationDistance(bot, spot)
			if score < best then
				best = score
				loc = spot
			end
		end
		if loc == nil or not CanCaptureOutpostAt(loc) then
			return 0
		end
		targetOutpostDistance = GetUnitToLocationDistance(bot, loc)
		if targetOutpostDistance <= 600 then
			bot._outpostFallbackAt = bot._outpostFallbackAt or DotaTime()
			if DotaTime() - bot._outpostFallbackAt >= 5 then
				bot._outpostFallbackAt = nil
				bot._outpostFallbackOffUntil = DotaTime() + 90
				-- Names of the units near the spot: the outpost scan matched none of them.
				local near = {}
				for _, unit in pairs(GetUnitList(UNIT_LIST_ALL) or {}) do
					if
						unit ~= nil
						and not unit:IsNull()
						and not unit:IsHero()
						and GetUnitToLocationDistance(unit, loc) <= 700
					then
						near[#near + 1] = unit:GetUnitName() .. "/team" .. tostring(unit:GetTeam())
					end
				end
				pcall(
					print,
					string.format(
						"[OHA-OUTPOST] t=%.0f %s fallback-giveup spot=%.0f,%.0f near=%s",
						DotaTime(),
						(string.gsub(bot:GetUnitName(), "npc_dota_hero_", "")),
						loc.x,
						loc.y,
						#near > 0 and table.concat(near, ",") or "-"
					)
				)
				return 0
			end
		else
			bot._outpostFallbackAt = nil
		end
		outpostMoveLoc = loc
	end
	if loc == nil then
		return 0
	end
	if OutpostIsTooHot(loc) then
		return 0
	end
	if not AmAssignedCapturer(loc) then
		-- Already on it: stay and help finish the channel.
		if GetUnitToLocationDistance(bot, loc) > 600 then
			return 0
		end
	end
	local dist = GetUnitToLocationDistance(bot, loc)
	-- Above farm (VERYHIGH ~0.9) so one bot actually leaves the wave. Below retreat.
	-- Far outposts no longer beat a nearby fight or a lane the bot is already in.
	if dist <= 500 then
		return 0.98
	end
	-- Not on the way to Roshan or the Tormentor (game 035, 33:55: Leshrac, walking to the bottom
	-- Tormentor, passed within 2500 of the Dire outpost and the 0.95 here took him off his trip).
	if Fu.IsDoingRoshan(bot) or Fu.IsDoingTormentor(bot) then
		return 0
	end
	-- User call: 2500 pulled bots off whatever they were doing from too far away.
	if dist <= 1200 then
		return 0.95
	end
	return BOT_MODE_DESIRE_MODERATE
end
-- Our side's outpost: the one closer to our fountain than to theirs.
function IsOurSideOutpost(loc)
	local ours, theirs = Fu.GetTeamFountain(), Fu.GetEnemyFountain()
	if loc == nil or ours == nil or theirs == nil then
		return false
	end
	return Fu.GetDistance(loc, ours) < Fu.GetDistance(loc, theirs)
end
-- Living enemy heroes not seen for over 3s (GetHeroLastSeenInfo works without vision).
local function MissingEnemies()
	local count = 0
	for _, pid in pairs(GetTeamPlayers(GetOpposingTeam()) or {}) do
		if IsHeroAlive(pid) then
			local info = GetHeroLastSeenInfo(pid)
			local lastSeen = info ~= nil and info[1] or nil
			if lastSeen == nil or lastSeen.time_since_seen == nil or lastSeen.time_since_seen > 3 then
				count = count + 1
			end
		end
	end
	return count
end
-- The lane whose front is closest to the outpost, and how far our wave has pushed along it
-- (0 = our base, 1 = theirs).
local function OutpostLaneFront(loc)
	local bestLane, bestDist = nil, math.huge
	for _, lane in ipairs({ LANE_TOP, LANE_MID, LANE_BOT }) do
		local front = GetLaneFrontLocation(GetTeam(), lane, 0)
		if front ~= nil then
			local distance = Fu.GetDistance(front, loc)
			if distance < bestDist then
				bestLane, bestDist = lane, distance
			end
		end
	end
	if bestLane == nil then
		return nil, 0
	end
	return bestLane, GetLaneFrontAmount(GetTeam(), bestLane, false) or 0
end
-- The enemy-side outpost sits in their jungle. User call (game 035, 34:04: Leshrac walked alone
-- to the Dire outpost while Radiant was well behind on kills and no wave pushed toward Dire, and
-- Necrophos, Dragon Knight and Winter Wyvern killed him there): besides an enemy lane with T1 and
-- T2 down, our wave must be past the middle of the outpost's lane, and no more than 2 living enemy
-- heroes may be out of sight (the three who killed him were in the fog). This replaced a kill-deficit
-- check (user call: kills say little about who is waiting nearby).
local ENEMY_OUTPOST_MAX_MISSING = 2
local enemyOutpostLogAt = -999
local function EnemyOutpostSafe(loc)
	local why = nil
	if not EnemyTier2Down() then
		why = "no-tier2-down"
	else
		local missing = MissingEnemies()
		local lane, amount = OutpostLaneFront(loc)
		if missing > ENEMY_OUTPOST_MAX_MISSING then
			why = string.format("enemies-unseen(%d)", missing)
		elseif amount <= 0.5 then
			why = string.format("wave-not-pushed(lane=%s front=%.2f)", tostring(lane), amount)
		end
	end
	if why ~= nil and why ~= "no-tier2-down" and DotaTime() >= enemyOutpostLogAt + 60 then
		enemyOutpostLogAt = DotaTime()
		pcall(
			print,
			string.format(
				"[OHA-OUTPOST] t=%.0f %s enemy-outpost-skip why=%s",
				DotaTime(),
				(string.gsub(bot:GetUnitName(), "npc_dota_hero_", "")),
				why
			)
		)
	end
	return why == nil
end
function CanCaptureOutpostAt(loc)
	return IsOurSideOutpost(loc) or EnemyOutpostSafe(loc)
end
function GetClosestOutpost()
	local closestOutpost = nil
	local closestDistance = 10000
	for i = 1, #cachedOutposts do
		local outpost = cachedOutposts[i]
		-- Outposts are permanently invulnerable buildings; capture is a channel, not damage.
		-- Do NOT require not IsInvulnerable() — that filtered every outpost.
		if
			outpost ~= nil
			and not outpost:IsNull()
			and outpost:GetTeam() ~= GetTeam()
			and CanCaptureOutpostAt(outpost:GetLocation())
		then
			local dist = GetUnitToUnitDistance(bot, outpost)
			if dist < closestDistance then
				closestOutpost = outpost
				closestDistance = dist
			end
		end
	end
	return closestOutpost, closestDistance
end
function IsSuitableToCaptureOutpost()
	return CanThisBotCapture()
end
if SafeCall then
	local originalGetDesire = GetDesire
	local originalThink = Think
	if originalGetDesire then
		GetDesire = SafeCall(originalGetDesire, 0, "OUTPOST_GetDesire")
	end
	if originalThink then
		Think = SafeCall(originalThink, nil, "OUTPOST_Think")
	end
end
-- [OHA-PERF] timing (#52): FuncLib/systems/perf.lua
do
	local Perf = require(GetScriptDirectory() .. "/FuncLib/systems/perf")
	GetDesire = Perf.Wrap("outpost.GetDesire", GetDesire)
	Think = Perf.Wrap("outpost.Think", Think)
end
