-- How Rubick plays after stealing a spell from Clinkz.
-- Accidental globals made file-local (#13): every bot shares one Lua state, so these were shared.
local SkeletonWalkDesire, TarBombDesire, TarBombTarget, BurningBarrageDesire, BurningBarrageLocation, StrafeDesire, DeathPactDesire, DeathPactTarget
local BurningArmyDesire, BurningArmyLocation
local bot
local X = {}
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local strafeAbility
local tarBombAbility
local deathPactAbility
local burningBarrageAbility
local burningArmyAbility
local skeletonWalkAbility
local botTarget
function X.ConsiderStolenSpell(ability)
	bot = GetBot()
	if Fu.CanNotUseAbility(bot) then
		return
	end
	botTarget = Fu.GetProperTarget(bot)
	local abilityName = ability:GetName()
	if abilityName == "clinkz_wind_walk" then
		skeletonWalkAbility = ability
		SkeletonWalkDesire = X.ConsiderSkeletonWalk()
		if SkeletonWalkDesire > 0 then
			bot:Action_UseAbility(skeletonWalkAbility)
			return
		end
	end
	if abilityName == "clinkz_tar_bomb" then
		tarBombAbility = ability
		TarBombDesire, TarBombTarget = X.ConsiderTarBomb()
		if TarBombDesire > 0 then
			bot:Action_UseAbilityOnEntity(tarBombAbility, TarBombTarget)
			return
		end
	end
	if abilityName == "clinkz_burning_barrage" then
		burningBarrageAbility = ability
		BurningBarrageDesire, BurningBarrageLocation = X.ConsiderBurningBarrage()
		if BurningBarrageDesire > 0 then
			bot:Action_UseAbilityOnLocation(burningBarrageAbility, BurningBarrageLocation)
			return
		end
	end
	if abilityName == "clinkz_strafe" then
		strafeAbility = ability
		StrafeDesire = X.ConsiderStrafe()
		if StrafeDesire > 0 then
			bot:Action_UseAbility(strafeAbility)
			return
		end
	end
	if abilityName == "clinkz_death_pact" then
		deathPactAbility = ability
		DeathPactDesire, DeathPactTarget = X.ConsiderDeathPact()
		if DeathPactDesire > 0 then
			bot:Action_UseAbilityOnEntity(deathPactAbility, DeathPactTarget)
			return
		end
	end
	if abilityName == "clinkz_burning_army" then
		burningArmyAbility = ability
		BurningArmyDesire, BurningArmyLocation = X.ConsiderBurningArmy()
		if BurningArmyDesire > 0 then
			bot:Action_UseAbilityOnLocation(burningArmyAbility, BurningArmyLocation)
			return
		end
	end
end
function X.ConsiderStrafe()
	if not strafeAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
	end
	local attackRange = bot:GetAttackRange()
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidTarget(botTarget)
			and Fu.IsInRange(bot, botTarget, attackRange)
			and not Fu.IsChasingTarget(bot, botTarget)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not botTarget:HasModifier("modifier_abaddon_borrowed_time")
			and not botTarget:HasModifier("modifier_dazzle_shallow_grave")
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			local alliesNearTarget = Fu.GetNearbyHeroes(botTarget, 1200, true, BOT_MODE_NONE)
			local enemiesNearTarget = Fu.GetNearbyHeroes(botTarget, 1200, false, BOT_MODE_NONE)
			if alliesNearTarget ~= nil and enemiesNearTarget ~= nil and #alliesNearTarget >= #enemiesNearTarget then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	if Fu.IsFarming(bot) then
		if Fu.IsAttacking(bot) then
			local neutralCreeps = bot:GetNearbyNeutralCreeps(1000)
			if
				neutralCreeps ~= nil
				and (#neutralCreeps >= 3 or #neutralCreeps >= 2 and neutralCreeps[1]:IsAncientCreep())
			then
				if Fu.GetMP(bot) > 0.25 then
					return BOT_ACTION_DESIRE_HIGH
				end
			end
			local laneCreeps = bot:GetNearbyLaneCreeps(1000, true)
			if laneCreeps ~= nil and #laneCreeps >= 4 then
				if Fu.GetMP(bot) > 0.25 then
					return BOT_ACTION_DESIRE_HIGH
				end
			end
		end
	end
	if Fu.IsPushing(bot) or Fu.IsDefending(bot) then
		local laneCreeps = bot:GetNearbyLaneCreeps(1000, true)
		if laneCreeps ~= nil and #laneCreeps >= 4 then
			if Fu.GetMP(bot) > 0.25 then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	if Fu.IsDoingRoshan(bot) or Fu.IsDoingTormentor(bot) then
		if
			(Fu.IsRoshan(botTarget) or Fu.IsTormentor(botTarget))
			and Fu.IsInRange(bot, botTarget, attackRange)
			and Fu.IsAttacking(bot)
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderTarBomb()
	if not tarBombAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local abilityLevel = tarBombAbility:GetLevel()
	local castRange = Fu.GetProperCastRange(false, bot, tarBombAbility:GetCastRange())
	local damage = 40 + 20 * abilityLevel - 1
	local radius = 325
	local nearbyEnemies = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	-- Allies for the "save a retreating ally" loop at the end (was a second enemy list).
	local nearbyHeroes = Fu.GetNearbyHeroes(bot, castRange, false, BOT_MODE_NONE)
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidTarget(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and Fu.CanKillTarget(enemyHero, damage, DAMAGE_TYPE_MAGICAL)
			and not Fu.IsSuspiciousIllusion(enemyHero)
			and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
			and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
			and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
			and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
			and not enemyHero:HasModifier("modifier_templar_assassin_refraction_absorb")
		then
			return BOT_ACTION_DESIRE_HIGH, enemyHero
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange + radius)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not Fu.IsDisabled(botTarget)
			and not botTarget:HasModifier("modifier_abaddon_borrowed_time")
			and not botTarget:HasModifier("modifier_dazzle_shallow_grave")
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			local alliesNearTarget = Fu.GetNearbyHeroes(botTarget, 1200, true, BOT_MODE_NONE)
			local enemiesNearTarget = Fu.GetNearbyHeroes(botTarget, 1200, false, BOT_MODE_NONE)
			if alliesNearTarget ~= nil and enemiesNearTarget ~= nil and #alliesNearTarget >= #enemiesNearTarget then
				if
					Fu.IsAttacking(bot)
					or Fu.IsChasingTarget(bot, botTarget)
						and bot:GetCurrentMovementSpeed() < botTarget:GetCurrentMovementSpeed()
				then
					return BOT_ACTION_DESIRE_HIGH, botTarget
				end
			end
		end
	end
	if Fu.IsRetreating(bot) and bot:GetActiveModeDesire() > 0.5 then
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.IsChasingTarget(enemyHero, bot)
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and not Fu.IsDisabled(enemyHero)
			then
				local alliesNearEnemy = Fu.GetNearbyHeroes(enemyHero, 1200, true, BOT_MODE_NONE)
				local enemiesNearEnemy = Fu.GetNearbyHeroes(enemyHero, 1200, false, BOT_MODE_NONE)
				if
					alliesNearEnemy ~= nil
					and enemiesNearEnemy ~= nil
					and (#enemiesNearEnemy > #alliesNearEnemy or bot:WasRecentlyDamagedByAnyHero(1.5))
					and bot:GetCurrentMovementSpeed() < enemyHero:GetCurrentMovementSpeed()
				then
					return BOT_ACTION_DESIRE_HIGH, enemyHero
				end
			end
		end
	end
	if Fu.IsPushing(bot) then
		if
			Fu.IsValidBuilding(botTarget)
			and Fu.CanBeAttacked(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and Fu.IsAttacking(botTarget)
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end
	if Fu.IsFarming(bot) then
		if Fu.IsAttacking(bot) then
			local neutralCreeps = bot:GetNearbyNeutralCreeps(1000)
			if neutralCreeps ~= nil and #neutralCreeps >= 1 and neutralCreeps[1]:GetHealth() >= 600 then
				if Fu.GetMP(bot) > 0.4 then
					return BOT_ACTION_DESIRE_HIGH, neutralCreeps[1]
				end
			end
			local laneCreeps = bot:GetNearbyLaneCreeps(1000, true)
			if laneCreeps ~= nil and #laneCreeps >= 1 and laneCreeps[1]:GetHealth() >= 550 then
				if Fu.GetMP(bot) > 0.4 then
					return BOT_ACTION_DESIRE_HIGH, laneCreeps[1]
				end
			end
		end
	end
	if Fu.IsLaning(bot) then
		local laneCreeps = bot:GetNearbyLaneCreeps(castRange, true)
		for _, creep in pairs(laneCreeps) do
			if
				Fu.IsValid(creep)
				and (Fu.IsKeyWordUnit("ranged", creep) or Fu.IsKeyWordUnit("siege", creep) or Fu.IsKeyWordUnit(
					"flagbearer",
					creep
				))
				and creep:GetHealth() <= damage
			then
				local nearbyAllies = Fu.GetNearbyHeroes(bot, 1600, false, BOT_MODE_NONE)
				if
					nearbyAllies ~= nil
					and #nearbyAllies >= 1
					and GetUnitToUnitDistance(creep, nearbyAllies[1]) < 600
					and botTarget ~= creep
					and Fu.GetMP(bot) > 0.3
					and Fu.CanBeAttacked(creep)
					and Fu.IsInLaningPhase()
				then
					return BOT_ACTION_DESIRE_HIGH, creep
				end
			end
		end
	end
	if Fu.IsDoingRoshan(bot) or Fu.IsDoingTormentor(bot) then
		if
			(Fu.IsRoshan(botTarget) or Fu.IsTormentor(botTarget))
			and Fu.IsInRange(bot, botTarget, bot:GetAttackRange())
			and Fu.IsAttacking(bot)
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end
	for _, allyHero in pairs(nearbyHeroes) do
		local allyNearbyEnemies = Fu.GetNearbyHeroes(allyHero, 1200, true, BOT_MODE_NONE)
		if
			Fu.IsValidHero(allyHero)
			and Fu.IsRetreating(allyHero)
			and allyHero:WasRecentlyDamagedByAnyHero(2)
			and not allyHero:IsIllusion()
		then
			if
				allyNearbyEnemies ~= nil
				and #allyNearbyEnemies >= 1
				and Fu.IsValidHero(allyNearbyEnemies[1])
				and Fu.IsInRange(bot, allyNearbyEnemies[1], castRange)
				and Fu.IsChasingTarget(allyNearbyEnemies[1], allyHero)
				and allyHero:GetCurrentMovementSpeed() < allyNearbyEnemies[1]:GetCurrentMovementSpeed()
				and not Fu.IsDisabled(allyNearbyEnemies[1])
				and not Fu.IsTaunted(allyNearbyEnemies[1])
				and not Fu.IsSuspiciousIllusion(allyNearbyEnemies[1])
				and not allyNearbyEnemies[1]:HasModifier("modifier_necrolyte_reapers_scythe")
			then
				return BOT_ACTION_DESIRE_HIGH, allyNearbyEnemies[1]
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function X.ConsiderDeathPact()
	if not deathPactAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castRange = Fu.GetProperCastRange(false, bot, deathPactAbility:GetCastRange())
	local maxCreepLevel = deathPactAbility:GetSpecialValueInt("creep_level")
	local nearbyCreeps = bot:GetNearbyCreeps(castRange, true)
	if Fu.IsInLaningPhase() then
		if Fu.IsLaning(bot) then
			local laneCreeps = bot:GetNearbyLaneCreeps(castRange, true)
			for _, creep in pairs(laneCreeps) do
				if
					Fu.IsValid(creep) and Fu.CanBeAttacked(creep) and Fu.IsKeyWordUnit("ranged", creep)
					or Fu.IsKeyWordUnit("siege", creep) and creep:GetLevel() <= maxCreepLevel
				then
					local nearbyAllies = Fu.GetNearbyHeroes(bot, 1600, false, BOT_MODE_NONE)
					if
						nearbyAllies ~= nil
						and #nearbyAllies >= 1
						and GetUnitToUnitDistance(creep, nearbyAllies[1]) < 600
						and botTarget ~= creep
						and not bot:HasModifier("modifier_clinkz_death_pact")
					then
						return BOT_ACTION_DESIRE_HIGH, creep
					end
				end
			end
		end
	else
		local creep = X.GetMostHPCreepLevel(nearbyCreeps, maxCreepLevel)
		if creep ~= nil and not bot:HasModifier("modifier_clinkz_death_pact") and not creep:IsAncientCreep() then
			return BOT_ACTION_DESIRE_HIGH, creep
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function X.ConsiderSkeletonWalk()
	if
		not skeletonWalkAbility:IsFullyCastable()
		or bot:HasModifier("modifier_clinkz_wind_walk")
		or Fu.IsRealInvisible(bot)
	then
		return BOT_ACTION_DESIRE_NONE
	end
	local roshanLocation = Fu.GetCurrentRoshanLocation()
	local tormentorLocation = Fu.GetTormentorLocation(GetTeam())
	local nearbyEnemies = Fu.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE)
	if Fu.IsGoingOnSomeone(bot) and bot:GetActiveModeDesire() > 0.65 then
		if
			Fu.IsValidTarget(botTarget)
			and GetUnitToUnitDistance(bot, botTarget) > 1600
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			local alliesNearTarget = Fu.GetAlliesNearLoc(botTarget:GetLocation(), 1200)
			local enemiesNearTarget = Fu.GetEnemiesNearLoc(botTarget:GetLocation(), 1200)
			if alliesNearTarget ~= nil and enemiesNearTarget ~= nil and #alliesNearTarget >= #enemiesNearTarget then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	if Fu.IsRetreating(bot) and bot:GetActiveModeDesire() > 0.5 then
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE)
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.IsChasingTarget(enemyHero, bot)
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and not Fu.IsDisabled(enemyHero)
			then
				local alliesNearEnemy = Fu.GetNearbyHeroes(enemyHero, 1200, true, BOT_MODE_NONE)
				local enemiesNearEnemy = Fu.GetNearbyHeroes(enemyHero, 1200, false, BOT_MODE_NONE)
				if
					alliesNearEnemy ~= nil
					and enemiesNearEnemy ~= nil
					and (#enemiesNearEnemy > #alliesNearEnemy or bot:WasRecentlyDamagedByAnyHero(1.5))
				then
					return BOT_ACTION_DESIRE_HIGH
				end
			end
		end
	end
	if Fu.IsFarming(bot) then
		if bot.farmLocation ~= nil then
			if GetUnitToLocationDistance(bot, bot.farmLocation) > 3200 then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	if Fu.IsLaning(bot) then
		if
			Fu.GetManaAfter(skeletonWalkAbility:GetManaCost()) > 0.8
			and bot:DistanceFromFountain() > 100
			and bot:DistanceFromFountain() < 6000
			and Fu.IsInLaningPhase()
			and nearbyEnemies ~= nil
			and #nearbyEnemies == 0
		then
			local assignedLane = bot:GetAssignedLane()
			local laneFrontLocation = GetLaneFrontLocation(GetTeam(), assignedLane, 0)
			local laneFrontDistance = GetUnitToLocationDistance(bot, laneFrontLocation)
			if laneFrontDistance > 1600 then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if GetUnitToLocationDistance(bot, roshanLocation) > 4000 then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if GetUnitToLocationDistance(bot, tormentorLocation) > 4000 then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderBurningBarrage()
	if not burningBarrageAbility:IsTrained() or not burningBarrageAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local castRange = Fu.GetProperCastRange(false, bot, burningBarrageAbility:GetCastRange())
	local radius = burningBarrageAbility:GetSpecialValueInt("radius")
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidTarget(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange - 125)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not botTarget:HasModifier("modifier_abaddon_borrowed_time")
			and not botTarget:HasModifier("modifier_dazzle_shallow_grave")
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			local alliesNearTarget = Fu.GetAlliesNearLoc(botTarget:GetLocation(), 1200)
			local enemiesNearTarget = Fu.GetEnemiesNearLoc(botTarget:GetLocation(), 1200)
			if alliesNearTarget ~= nil and enemiesNearTarget ~= nil and #alliesNearTarget >= #enemiesNearTarget then
				enemiesNearTarget = Fu.GetEnemiesNearLoc(botTarget:GetLocation(), radius - 75)
				if enemiesNearTarget ~= nil and #enemiesNearTarget >= 1 then
					return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(enemiesNearTarget)
				else
					return BOT_ACTION_DESIRE_HIGH, botTarget:GetExtrapolatedLocation(0.5)
				end
			end
		end
	end
	if Fu.IsFarming(bot) then
		local neutralCreeps = bot:GetNearbyNeutralCreeps(1000)
		-- Keep mana for Skeleton Walk only when it was also stolen (the handle is nil otherwise).
		local skeletonWalkMana = 0
		if skeletonWalkAbility ~= nil and not skeletonWalkAbility:IsNull() then
			skeletonWalkMana = skeletonWalkAbility:GetManaCost()
		end
		if
			neutralCreeps ~= nil
			and #neutralCreeps >= 1
			and Fu.IsAttacking(bot)
			and Fu.GetManaAfter(burningBarrageAbility:GetManaCost()) * bot:GetMana() > skeletonWalkMana
		then
			if Fu.IsBigCamp(neutralCreeps) or neutralCreeps[1]:IsAncientCreep() then
				if #neutralCreeps >= 2 then
					return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(neutralCreeps)
				end
			else
				if #neutralCreeps >= 3 then
					return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(neutralCreeps)
				end
			end
		end
		local laneCreeps = bot:GetNearbyLaneCreeps(1000, true)
		if laneCreeps ~= nil and #laneCreeps >= 4 then
			return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(laneCreeps)
		end
	end
	if Fu.IsPushing(bot) or Fu.IsDefending(bot) then
		local laneCreeps = bot:GetNearbyLaneCreeps(1000, true)
		if laneCreeps ~= nil and #laneCreeps >= 4 then
			return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(laneCreeps)
		end
	end
	if Fu.IsDoingRoshan(bot) or Fu.IsDoingTormentor(bot) then
		if
			(Fu.IsRoshan(botTarget) or Fu.IsTormentor(botTarget))
			and Fu.IsInRange(bot, botTarget, bot:GetAttackRange())
			and Fu.IsAttacking(bot)
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.ConsiderBurningArmy()
	if not burningArmyAbility:IsTrained() or not burningArmyAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local attackRange = bot:GetAttackRange()
	local castRange = Fu.GetProperCastRange(false, bot, burningArmyAbility:GetCastRange())
	local radius = 900
	if Fu.IsInTeamFight(bot, 1200) then
		local aoeLocation = bot:FindAoELocation(true, true, bot:GetLocation(), castRange + radius / 2, radius, 0, 0)
		local enemiesInRadius = Fu.GetEnemiesNearLoc(aoeLocation.targetloc, radius)
		if enemiesInRadius ~= nil and #enemiesInRadius >= 2 then
			if GetUnitToLocationDistance(bot, Fu.GetCenterOfUnits(enemiesInRadius)) > castRange then
				return BOT_ACTION_DESIRE_HIGH,
					Fu.Site.GetXUnitsTowardsLocation(bot, Fu.GetCenterOfUnits(enemiesInRadius), castRange)
			else
				return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(enemiesInRadius)
			end
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidTarget(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not botTarget:HasModifier("modifier_abaddon_borrowed_time")
			and not botTarget:HasModifier("modifier_dazzle_shallow_grave")
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			local alliesNearTarget = Fu.GetAlliesNearLoc(botTarget:GetLocation(), 1200)
			local enemiesNearTarget = Fu.GetEnemiesNearLoc(botTarget:GetLocation(), 1200)
			if alliesNearTarget ~= nil and enemiesNearTarget ~= nil and #alliesNearTarget >= #enemiesNearTarget then
				enemiesNearTarget = Fu.GetEnemiesNearLoc(botTarget:GetLocation(), radius)
				if enemiesNearTarget ~= nil and #enemiesNearTarget >= 1 then
					if GetUnitToLocationDistance(bot, Fu.GetCenterOfUnits(enemiesNearTarget)) > castRange then
						return BOT_ACTION_DESIRE_HIGH,
							Fu.Site.GetXUnitsTowardsLocation(bot, Fu.GetCenterOfUnits(enemiesNearTarget), castRange)
					else
						return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(enemiesNearTarget)
					end
				else
					if GetUnitToUnitDistance(bot, botTarget) > castRange then
						return BOT_ACTION_DESIRE_HIGH,
							Fu.Site.GetXUnitsTowardsLocation(bot, botTarget:GetLocation(), castRange)
					else
						return BOT_ACTION_DESIRE_HIGH, botTarget:GetExtrapolatedLocation(0.5)
					end
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.GetMostHPCreepLevel(creeps, maxLevel)
	local bestCreep = nil
	local maxHealth = 0
	for _, creep in pairs(creeps) do
		local health = creep:GetHealth()
		local level = creep:GetLevel()
		if health > maxHealth and level <= maxLevel and not Fu.IsKeyWordUnit("flagbearer", creep) then
			bestCreep = creep
			maxHealth = health
		end
	end
	return bestCreep
end
return X
