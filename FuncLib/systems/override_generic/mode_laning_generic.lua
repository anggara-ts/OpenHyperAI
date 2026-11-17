-- Override for the built-in mode_laning_generic mode.
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
BotsInit = require("game/botsinit")
local X = BotsInit.CreateGeneric()
local bot = GetBot()
function X.OnStart() end
function X.OnEnd() end
local targetLane
local tangoDesire, tangoTree, tangoSlot
local nextMoveTime = 0
function X.GetDesire()
	local isBear = bot.isBear or string.find(bot:GetUnitName(), "lone_druid_bear")
	if isBear then
		local Utils = require(GetScriptDirectory() .. "/FuncLib/systems/utils")
		local loneDruid = Utils.GetLoneDruid(bot)
		if loneDruid and loneDruid.hero and Fu.IsValidHero(loneDruid.hero) and loneDruid.hero:IsAlive() then
			local druidMode = loneDruid.hero:GetActiveMode()
			if
				druidMode == BOT_MODE_ATTACK
				or druidMode == BOT_MODE_DEFEND_ALLY
				or druidMode == BOT_MODE_TEAM_ROAM
				or druidMode == BOT_MODE_ROSHAN
				or druidMode == BOT_MODE_FARM
			then
				return BOT_MODE_DESIRE_NONE
			end
			local druidTarget = Fu.GetProperTarget(loneDruid.hero)
			if Fu.IsValidHero(druidTarget) and GetUnitToUnitDistance(bot, druidTarget) < 1200 then
				return BOT_MODE_DESIRE_NONE
			end
		end
	end
	tangoDesire, tangoTree = ConsiderTango()
	if tangoDesire > 0 then
		return BOT_MODE_DESIRE_ABSOLUTE
	end
	if not targetLane then
		targetLane = GetBotTargetLane()
	end
	if GetGameMode() == GAMEMODE_1V1MID or GetGameMode() == GAMEMODE_MO then
		return 1
	end
	local time = DotaTime()
	local level = bot:GetLevel()
	if GetGameMode() == 23 then
		time = time * 1.65
	end
	if time <= 10 then
		bot.isInLanePhase = true
		return 0.268
	end
	if time <= 9 * 60 and level <= 7 then
		bot.isInLanePhase = true
		return 0.446
	end
	if time <= 12 * 60 and level <= 11 then
		bot.isInLanePhase = true
		return 0.369
	end
	-- Not after 15:00 (game 032, 22:00: Muerta, level 15 or lower with the cores' average net worth
	-- under 12000, was still laning and followed her wave deep toward the enemy towers alone).
	if time <= 15 * 60 and level <= 15 and Fu.GetCoresAverageNetworth() < 12000 then
		bot.isInLanePhase = true
		return 0.228
	end
	bot.isInLanePhase = false
	return BOT_MODE_DESIRE_VERYLOW
end
function GetBotTargetLane()
	if IsLanMode and IsLanMode() then
		local assignedLane = bot:GetAssignedLane()
		if assignedLane == LANE_TOP or assignedLane == LANE_MID or assignedLane == LANE_BOT then
			targetLane = assignedLane
			return targetLane
		end
	end
	local position = Fu.GetPosition(bot)
	if GetTeam() == TEAM_RADIANT then
		if position == 2 then
			targetLane = LANE_MID
		elseif position == 1 or position == 5 then
			targetLane = LANE_BOT
		elseif position == 3 or position == 4 then
			targetLane = LANE_TOP
		end
	else
		if position == 2 then
			targetLane = LANE_MID
		elseif position == 1 or position == 5 then
			targetLane = LANE_TOP
		elseif position == 3 or position == 4 then
			targetLane = LANE_BOT
		end
	end
	return targetLane
end
function X.Think()
	if not bot:IsAlive() or Fu.CanNotUseAction(bot) or bot:IsChanneling() or bot:IsDisarmed() then
		return
	end
	local attackRange = bot:GetAttackRange()
	local lane = targetLane or bot:GetAssignedLane()
	local allyCreeps = bot:GetNearbyLaneCreeps(1200, false)
	local enemyCreeps = bot:GetNearbyLaneCreeps(1200, true)
	local nearbyEnemies = bot:GetNearbyHeroes(1600, true, BOT_MODE_NONE)
	local enemyTowers = bot:GetNearbyTowers(1200, true)
	if tangoDesire and tangoDesire > 0 and tangoTree then
		local tango = bot:GetItemInSlot(tangoSlot)
		bot:Action_UseAbilityOnTree(tango, tangoTree)
		return
	end
	if
		bot:WasRecentlyDamagedByAnyHero(2.0) and #Fu.GetHeroesTargetingUnit(nearbyEnemies, bot) >= 1
		or Fu.IsValidBuilding(enemyTowers[1]) and enemyTowers[1]:GetAttackTarget() == bot
		or bot:WasRecentlyDamagedByCreep(2.0)
			and not (bot:HasModifier("modifier_tower_aura") or bot:HasModifier("modifier_tower_aura_bonus"))
			and #allyCreeps > 0
	then
		local retreatLocation = Fu.AdjustLocationWithOffsetTowardsFountain(bot:GetLocation(), 500)
		bot:Action_MoveToLocation(retreatLocation + RandomVector(50))
		return
	end
	if bot:WasRecentlyDamagedByTower(1.0) and #enemyCreeps > 0 then
		local closeTowers = bot:GetNearbyTowers(750, true)
		if #closeTowers > 0 then
			for _, creep in pairs(enemyCreeps) do
				if Fu.IsValid(creep) and GetUnitToUnitDistance(creep, closeTowers[1]) < 700 then
					bot:Action_AttackUnit(creep, true)
					return
				end
			end
		end
	end
	if Fu.IsValidBuilding(enemyTowers[1]) then
		local towerDistance = GetUnitToUnitDistance(bot, enemyTowers[1])
		if towerDistance < 800 and #enemyCreeps < 3 then
			bot:Action_MoveToLocation(
				Fu.VectorAway(bot:GetLocation(), enemyTowers[1]:GetLocation(), 950) + RandomVector(75)
			)
			return
		end
		if towerDistance < 900 and bot:WasRecentlyDamagedByTower(2.0) then
			bot:Action_MoveToLocation(Fu.VectorAway(bot:GetLocation(), enemyTowers[1]:GetLocation(), 950))
			return
		end
	end
	local bSupport = Fu.GetPosition(bot) >= 4
	-- Supports deny first and leave the last hits to their core.
	if bSupport then
		local denyCreep = GetBestDenyCreep(allyCreeps)
		if Fu.IsValid(denyCreep) then
			bot:Action_AttackUnit(denyCreep, true)
			return
		end
	end
	local lastHitCreep = GetBestLastHitCreep(enemyCreeps)
	if Fu.IsValid(lastHitCreep) then
		local isBear = bot.isBear or string.find(bot:GetUnitName(), "lone_druid_bear")
		local bCanLastHit
		if bSupport then
			-- Do not compete with a core for last hits.
			bCanLastHit = not Fu.IsThereNonSelfCoreNearby(1000)
		else
			local lanePartner = Fu.GetLanePartner(bot)
			bCanLastHit = isBear
				or lanePartner == nil
				or Fu.IsCore(bot)
				or not Fu.IsCore(bot)
					and Fu.IsCore(lanePartner)
					and (not lanePartner:IsAlive() or not Fu.IsInRange(bot, lanePartner, 800))
		end
		if bCanLastHit then
			if GetUnitToUnitDistance(bot, lastHitCreep) > attackRange then
				bot:Action_MoveToUnit(lastHitCreep)
			else
				bot:Action_AttackUnit(lastHitCreep, true)
			end
			return
		end
	end
	-- Cores deny after looking for a last hit. Supports already denied above.
	if not bSupport then
		local denyCreep = GetBestDenyCreep(allyCreeps)
		if Fu.IsValid(denyCreep) then
			bot:Action_AttackUnit(denyCreep, true)
			return
		end
	end
	-- Aggressive poke on our half; never chase into enemy T1 (rune/tower bait).
	if Fu.IsInLaningPhase and Fu.IsInLaningPhase() and Fu.GetHP(bot) >= 0.55 then
		if not (bot:WasRecentlyDamagedByAnyHero(1.0) and Fu.GetHP(bot) < 0.75) then
			local function laneT1(team, lane)
				if lane == LANE_TOP then
					return GetTower(team, TOWER_TOP_1)
				elseif lane == LANE_MID then
					return GetTower(team, TOWER_MID_1)
				elseif lane == LANE_BOT then
					return GetTower(team, TOWER_BOT_1)
				end
				return nil
			end
			local allyT1 = laneT1(GetTeam(), lane)
			local enemyT1 = laneT1(GetOpposingTeam(), lane)
			local pokeRange = bot:GetAttackRange()
			if allyT1 ~= nil and allyT1:IsAlive() then
				for _, enemy in pairs(nearbyEnemies or {}) do
					if
						Fu.IsValidHero(enemy)
						and Fu.CanBeAttacked(enemy)
						and not Fu.IsSuspiciousIllusion(enemy)
						and Fu.IsInRange(bot, enemy, pokeRange)
						and not CreepAggroUnsafe(bot)
					then
						local selfUnderTower = enemyT1 ~= nil
							and enemyT1:IsAlive()
							and GetUnitToUnitDistance(bot, enemyT1) < (enemyT1:GetAttackRange() or 700) + 180
						local enemyUnderTower = enemyT1 ~= nil
							and enemyT1:IsAlive()
							and GetUnitToUnitDistance(enemy, enemyT1) < (enemyT1:GetAttackRange() or 700) + 250
						if
							not selfUnderTower
							and not enemyUnderTower
							and GetUnitToUnitDistance(enemy, allyT1) <= 3800
							and GetUnitToUnitDistance(bot, allyT1) <= 4000
						then
							local now = DotaTime()
							if bot.sOffsideHarassChatTime == nil or now - bot.sOffsideHarassChatTime >= 10 then
								bot.sOffsideHarassChatTime = now
								local name = string.gsub(enemy:GetUnitName(), "npc_dota_hero_", "")
								name = string.gsub(name, "_(%l)", function(letter)
									return " " .. string.upper(letter)
								end)
								name = string.upper(string.sub(name, 1, 1)) .. string.sub(name, 2)
								bot:ActionImmediate_Chat("Harassing " .. name, false)
							end
							bot:Action_AttackUnit(enemy, true)
							return
						end
					end
				end
			end
		end
	end
	local isBear = bot.isBear or string.find(bot:GetUnitName(), "lone_druid_bear")
	if not Fu.IsCore(bot) and not isBear and Fu.GetHP(bot) > 0.5 and not CreepAggroUnsafe(bot) then
		local harassTarget = GetHarassTarget(nearbyEnemies)
		if Fu.IsValidHero(harassTarget) then
			bot:Action_AttackUnit(harassTarget, true)
			return
		end
	end
	local standOffDistance = GetFurthestEnemyAttackRange(nearbyEnemies)
	if standOffDistance == 0 then
		standOffDistance = math.max(attackRange, 330)
	end
	-- A melee core held back at a ranged laner's attack range cannot walk in for a last hit in time.
	if Fu.IsCore(bot) and attackRange < 326 and Fu.GetHP(bot) >= 0.45 then
		standOffDistance = math.min(standOffDistance, 300)
	end
	local allyFrontAmount = GetLaneFrontAmount(GetTeam(), lane, false)
	local enemyFrontAmount = GetLaneFrontAmount(GetOpposingTeam(), lane, false)
	local moveLocation = GetLaneFrontLocation(GetTeam(), lane, -standOffDistance)
	if enemyFrontAmount < allyFrontAmount then
		moveLocation = GetLaneFrontLocation(GetOpposingTeam(), lane, -standOffDistance)
	end
	if DotaTime() >= nextMoveTime then
		bot:Action_MoveToLocation(moveLocation + RandomVector(300))
		nextMoveTime = DotaTime() + RandomFloat(0.05, 0.2)
	end
end
function GetBestLastHitCreep(creeps)
	local attackDamage = bot:GetAttackDamage()
	if bot:GetItemSlotType(bot:FindItemSlot("item_quelling_blade")) == ITEM_SLOT_TYPE_MAIN then
		if bot:GetAttackRange() > 310 or bot:GetUnitName() == "npc_dota_hero_templar_assassin" then
			attackDamage = attackDamage + 4
		else
			attackDamage = attackDamage + 8
		end
	end
	for _, creep in pairs(creeps) do
		if Fu.IsValid(creep) and Fu.CanBeAttacked(creep) then
			local attackDelay = Fu.GetAttackProDelayTime(bot, creep)
			if Fu.WillKillTarget(creep, attackDamage, DAMAGE_TYPE_PHYSICAL, attackDelay) then
				return creep
			end
		end
	end
	return nil
end
function GetBestDenyCreep(creeps)
	local fallback = nil
	local attackRange = bot:GetAttackRange()
	for _, creep in pairs(creeps) do
		if
			Fu.IsValid(creep)
			and Fu.GetHP(creep) < 0.49
			and Fu.CanBeAttacked(creep)
			and creep:GetHealth() <= bot:GetAttackDamage()
			and Fu.IsDeniableLaneCreep(creep)
		then
			-- Prefer a deny that can be executed immediately. Otherwise keep the
			-- first valid creep so the bot can walk up to it.
			if GetUnitToUnitDistance(bot, creep) <= attackRange + 100 then
				return creep
			elseif fallback == nil then
				fallback = creep
			end
		end
	end
	return fallback
end
function CreepAggroUnsafe(hero)
	local creeps = hero:GetNearbyLaneCreeps(500, true) or {}
	local fresh, hitting = 0, 0
	for _, creep in pairs(creeps) do
		if Fu.IsValid(creep) then
			if creep:GetAttackTarget() == hero then
				hitting = hitting + 1
			else
				fresh = fresh + 1
			end
		end
	end
	return fresh > 0 or hitting >= 2
end
function GetHarassTarget(enemies)
	local enemyTowers = bot:GetNearbyTowers(1000, true)
	local attackRange = bot:GetAttackRange()
	for _, enemy in pairs(enemies) do
		if
			Fu.IsValidHero(enemy)
			and Fu.IsInRange(bot, enemy, attackRange)
			and Fu.CanBeAttacked(enemy)
			and not Fu.IsSuspiciousIllusion(enemy)
		then
			-- Skip tower-hugging bait.
			if Fu.IsValidBuilding(enemyTowers[1]) then
				local towerRange = (enemyTowers[1]:GetAttackRange() or 700) + 200
				if
					GetUnitToUnitDistance(bot, enemyTowers[1]) < towerRange
					or GetUnitToUnitDistance(enemy, enemyTowers[1]) < towerRange + 80
				then
					goto continue_harass
				end
			end
			return enemy
		end
		::continue_harass::
	end
	return nil
end
function GetFurthestEnemyAttackRange(enemies)
	local maxRange = 0
	for _, enemy in pairs(enemies) do
		if Fu.IsValidHero(enemy) and not Fu.IsSuspiciousIllusion(enemy) then
			local enemyRange = enemy:GetAttackRange()
			if enemyRange > maxRange then
				maxRange = enemyRange
			end
		end
	end
	return maxRange
end
function ConsiderTango()
	if bot:HasModifier("modifier_tango_heal") then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	tangoDesire = 0
	tangoSlot = Fu.FindItemSlotNotInNonbackpack(bot, "item_tango")
	if tangoSlot < 0 then
		tangoSlot = Fu.FindItemSlotNotInNonbackpack(bot, "item_tango_single")
	end
	if
		tangoSlot >= 0
		and bot:OriginalGetMaxHealth() - bot:OriginalGetHealth() > 250
		and Fu.GetHP(bot) > 0.15
		and not Fu.IsAttacking(bot)
		and not bot:WasRecentlyDamagedByAnyHero(2)
	then
		local nearbyTrees = bot:GetNearbyTrees(800)
		local tree = nearbyTrees[1]
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, 1000, true, BOT_MODE_NONE)
		local nearestEnemy = nearbyEnemies[1]
		local enemyTowers = bot:GetNearbyTowers(1400, true)
		local nearestTower = enemyTowers[1]
		if tree ~= nil then
			local treeLocation = GetTreeLocation(tree)
			if
				IsLocationVisible(treeLocation)
				and IsLocationPassable(treeLocation)
				and (#nearbyEnemies == 0 or GetUnitToLocationDistance(bot, treeLocation) * 1.6 < GetUnitToUnitDistance(
					bot,
					nearestEnemy
				))
				and (#enemyTowers == 0 or GetUnitToLocationDistance(nearestTower, treeLocation) > 920)
			then
				return BOT_ACTION_DESIRE_HIGH, tree
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
return X
