-- How Rubick plays after stealing a spell from Arc Warden.
local bot = GetBot()
local X = {}
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local fluxAbility
local magneticFieldAbility
local sparkWraithAbility
local botTarget
function X.ConsiderStolenSpell(ability)
	bot = GetBot()
	if Fu.CanNotUseAbility(bot) then
		return
	end
	botTarget = Fu.GetProperTarget(bot)
	local abilityName = ability:GetName()
	if abilityName == "arc_warden_flux" then
		fluxAbility = ability
		FluxDesire, FluxTarget = X.ConsiderFlux()
		if FluxDesire > 0 then
			bot:Action_UseAbilityOnEntity(fluxAbility, FluxTarget)
			return
		end
	end
	if abilityName == "arc_warden_magnetic_field" then
		magneticFieldAbility = ability
		MagneticFieldDesire, MagneticFieldLocation = X.ConsiderMagneticField()
		if MagneticFieldDesire > 0 then
			bot:Action_UseAbilityOnLocation(magneticFieldAbility, MagneticFieldLocation)
			return
		end
	end
	if abilityName == "arc_warden_spark_wraith" then
		sparkWraithAbility = ability
		SparkWraithDesire, SparkWraithLocation = X.ConsiderSparkWraith()
		if SparkWraithDesire > 0 then
			bot:Action_UseAbilityOnLocation(sparkWraithAbility, SparkWraithLocation)
			return
		end
	end
end
function X.ConsiderFlux()
	if not fluxAbility:IsFullyCastable() then
		return 0
	end
	local castRange = Fu.GetProperCastRange(false, bot, fluxAbility:GetCastRange())
	local damagePerSecond = fluxAbility:GetSpecialValueInt("damage_per_second")
	local duration = fluxAbility:GetSpecialValueInt("duration")
	local damage = damagePerSecond * duration
	if
		Fu.IsValidHero(botTarget)
		and Fu.CanCastOnNonMagicImmune(botTarget)
		and Fu.CanCastOnTargetAdvanced(botTarget)
		and Fu.CanKillTarget(botTarget, damage, DAMAGE_TYPE_MAGICAL)
		and Fu.IsInRange(botTarget, bot, castRange)
	then
		return BOT_ACTION_DESIRE_HIGH, botTarget
	end
	if Fu.IsInTeamFight(bot, 1200) then
		local strongestEnemy = nil
		local maxDamage = 0
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
		for _, enemyHero in pairs(nearbyEnemies) do
			if Fu.IsValid(enemyHero) and Fu.CanCastOnNonMagicImmune(enemyHero) and Fu.CanCastOnTargetAdvanced(enemyHero) then
				local estimatedDamage = enemyHero:GetEstimatedDamageToTarget(false, bot, 3.0, DAMAGE_TYPE_ALL)
				if estimatedDamage > maxDamage then
					maxDamage = estimatedDamage
					strongestEnemy = enemyHero
				end
			end
		end
		if strongestEnemy ~= nil then
			return BOT_ACTION_DESIRE_HIGH, strongestEnemy
		end
	end
	if bot:GetActiveMode() == BOT_MODE_ROSHAN then
		if Fu.IsRoshan(botTarget) and Fu.CanCastOnMagicImmune(botTarget) and Fu.IsInRange(botTarget, bot, castRange) then
			return BOT_ACTION_DESIRE_LOW, botTarget
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidHero(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.CanCastOnTargetAdvanced(botTarget)
			and Fu.IsInRange(botTarget, bot, castRange + 40)
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end
	if Fu.IsRetreating(bot) then
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
		local closeEnemies = Fu.GetNearbyHeroes(bot, 800, true, BOT_MODE_NONE)
		local enemyHero = nearbyEnemies[1]
		if
			Fu.IsValid(enemyHero)
			and (bot:IsFacingLocation(enemyHero:GetLocation(), 10) or #closeEnemies <= 1)
			and bot:WasRecentlyDamagedByHero(enemyHero, 2.0)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and Fu.CanCastOnTargetAdvanced(enemyHero)
		then
			return BOT_ACTION_DESIRE_HIGH, enemyHero
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.ConsiderMagneticField()
	if not magneticFieldAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local radius = magneticFieldAbility:GetSpecialValueInt("radius")
	local castRange = Fu.GetProperCastRange(false, bot, magneticFieldAbility:GetCastRange())
	if Fu.IsRetreating(bot) and not bot:HasModifier("modifier_arc_warden_magnetic_field") then
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
		for _, enemyHero in pairs(nearbyEnemies) do
			if Fu.IsValid(enemyHero) and bot:WasRecentlyDamagedByHero(enemyHero, 2.0) then
				return BOT_ACTION_DESIRE_MODERATE, bot:GetLocation()
			end
		end
	end
	if bot:GetActiveMode() == BOT_MODE_ROSHAN and not bot:HasModifier("modifier_arc_warden_magnetic_field") then
		local attackTarget = bot:GetAttackTarget()
		if Fu.IsRoshan(attackTarget) and Fu.CanCastOnMagicImmune(attackTarget) and Fu.IsInRange(attackTarget, bot, castRange) then
			return BOT_ACTION_DESIRE_LOW, bot:GetLocation()
		end
	end
	if bot:GetActiveMode() == BOT_MODE_FARM and not bot:HasModifier("modifier_arc_warden_magnetic_field") then
		local aoeLocation = bot:FindAoELocation(true, false, bot:GetLocation(), 600, radius, 0, 0)
		if aoeLocation.count >= 3 then
			return BOT_ACTION_DESIRE_HIGH, bot:GetLocation()
		end
	end
	if Fu.IsInTeamFight(bot, 1200) then
		local aoeLocation = bot:FindAoELocation(false, true, bot:GetLocation(), castRange, radius, 0, 0)
		if aoeLocation.count >= 2 then
			local alliesNearLoc = Fu.GetAlliesNearLoc(aoeLocation.targetloc, radius)
			if
				Fu.IsValidHero(alliesNearLoc[1])
				and not alliesNearLoc[1]:HasModifier("modifier_arc_warden_magnetic_field")
				and alliesNearLoc[1]:GetAttackTarget() ~= nil
				and GetUnitToUnitDistance(alliesNearLoc[1], alliesNearLoc[1]:GetAttackTarget()) <= alliesNearLoc[1]:GetAttackRange() + 50
			then
				return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
			end
		end
	end
	if Fu.IsDefending(bot) or Fu.IsPushing(bot) and not bot:HasModifier("modifier_arc_warden_magnetic_field") then
		local nearbyLaneCreeps = bot:GetNearbyLaneCreeps(800, true)
		local nearbyTowers = bot:GetNearbyTowers(800, true)
		if nearbyLaneCreeps ~= nil and #nearbyLaneCreeps >= 3 or nearbyTowers ~= nil and #nearbyTowers >= 1 then
			return BOT_ACTION_DESIRE_LOW, bot:GetLocation()
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		local target = bot:GetTarget()
		if Fu.IsValidHero(target) and Fu.IsInRange(target, bot, castRange) then
			local nearbyAllies = Fu.GetNearbyHeroes(bot, castRange, false, BOT_MODE_ATTACK)
			for _, allyHero in pairs(nearbyAllies) do
				if
					Fu.IsValid(allyHero)
					and (Fu.IsInRange(allyHero, bot, castRange) and not allyHero:HasModifier("modifier_arc_warden_magnetic_field"))
					and (
						Fu.IsValid(allyHero:GetAttackTarget())
						and GetUnitToUnitDistance(allyHero, allyHero:GetAttackTarget()) <= allyHero:GetAttackRange()
					)
				then
					return BOT_ACTION_DESIRE_MODERATE, allyHero:GetLocation()
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.ConsiderSparkWraith()
	if not sparkWraithAbility:IsFullyCastable() then
		return 0
	end
	local radius = sparkWraithAbility:GetSpecialValueInt("radius")
	local castRange = Fu.GetProperCastRange(false, bot, sparkWraithAbility:GetCastRange())
	local damage = sparkWraithAbility:GetSpecialValueInt("spark_damage")
	local activationDelay = sparkWraithAbility:GetSpecialValueInt("activation_delay") + 0.1
	if Fu.IsValidHero(botTarget) and Fu.CanCastOnNonMagicImmune(botTarget) then
		if Fu.CanKillTarget(botTarget, damage, DAMAGE_TYPE_MAGICAL) and Fu.IsInRange(botTarget, bot, castRange) then
			return BOT_ACTION_DESIRE_MODERATE, botTarget:GetExtrapolatedLocation(activationDelay)
		end
	end
	if bot:GetActiveMode() == BOT_MODE_ROSHAN then
		local attackTarget = bot:GetAttackTarget()
		if Fu.IsRoshan(attackTarget) and Fu.IsInRange(attackTarget, bot, castRange) and Fu.GetHP(attackTarget) > 0.2 then
			return BOT_ACTION_DESIRE_LOW, attackTarget:GetLocation()
		end
	end
	if Fu.IsInTeamFight(bot, 1200) then
		local aoeLocation = bot:FindAoELocation(true, true, bot:GetLocation(), 1000, radius, 0, 0)
		if aoeLocation.count >= 2 then
			return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if Fu.IsValidHero(botTarget) and Fu.CanCastOnNonMagicImmune(botTarget) and Fu.IsInRange(botTarget, bot, castRange) then
			return BOT_ACTION_DESIRE_MODERATE, botTarget:GetExtrapolatedLocation(activationDelay)
		end
		local aoeLocation = bot:FindAoELocation(true, true, bot:GetLocation(), 1400, radius, 2.0, 0)
		if aoeLocation.count >= 1 and not bot:HasModifier("modifier_silencer_curse_of_the_silent") then
			local vulnerableUnit = Fu.GetVulnerableUnitNearLoc(bot, false, true, 1600, radius, aoeLocation.targetloc)
			if vulnerableUnit == nil or bot:HasModifier("modifier_arc_warden_tempest_double") then
				return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
			end
		end
	end
	if
		Fu.IsRetreating(bot)
		and bot:GetActiveModeDesire() > BOT_ACTION_DESIRE_HIGH
		and not bot:HasModifier("modifier_silencer_curse_of_the_silent")
	then
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, 800, true, BOT_MODE_NONE)
		for _, enemyHero in pairs(nearbyEnemies) do
			if Fu.IsValid(enemyHero) and bot:WasRecentlyDamagedByHero(enemyHero, 1.0) and Fu.CanCastOnNonMagicImmune(enemyHero) then
				return BOT_ACTION_DESIRE_HIGH, bot:GetLocation()
			end
		end
	end
	if bot:GetActiveMode() == BOT_MODE_FARM or Fu.IsPushing(bot) or Fu.IsDefending(bot) then
		local aoeLocation = bot:FindAoELocation(true, false, bot:GetLocation(), 1400, radius, 2.0, 0)
		if aoeLocation.count > 2 and not bot:HasModifier("modifier_silencer_curse_of_the_silent") then
			if bot:HasModifier("modifier_arc_warden_tempest_double") then
				return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
			end
			local nearbyLaneCreeps = bot:GetNearbyLaneCreeps(1400, true)
			if #nearbyLaneCreeps >= 2 then
				if Fu.GetMP(bot) > 0.62 then
					return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
				end
			else
				if Fu.GetMP(bot) > 0.75 then
					return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
				end
			end
		end
	end
	if sparkWraithAbility:GetLevel() >= 3 and bot:GetActiveMode() ~= BOT_MODE_LANING and Fu.IsAllowedToSpam(bot, 80) then
		local aoeLocation = bot:FindAoELocation(true, true, bot:GetLocation(), 1400, radius, 2.0, 0)
		if aoeLocation.count >= 2 then
			return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
		end
	end
	if
		bot:GetLevel() >= 10
		and (Fu.IsAllowedToSpam(bot, 80) or bot:HasModifier("modifier_arc_warden_tempest_double"))
		and DotaTime() > 8 * 60
	then
		local enemyHeroes = GetUnitList(UNIT_LIST_ENEMY_HEROES)
		local weakestEnemy = nil
		local minHealth = 99999
		for _, enemyHero in pairs(enemyHeroes) do
			if Fu.IsValidHero(enemyHero) and GetUnitToUnitDistance(bot, enemyHero) <= castRange and enemyHero:GetHealth() < minHealth then
				weakestEnemy = enemyHero
				minHealth = enemyHero:GetHealth()
			end
		end
		if weakestEnemy ~= nil then
			for offset = 0, 350, 50 do
				local location = Fu.GetLocationTowardDistanceLocation(weakestEnemy, Fu.GetEnemyFountain(), 350 - offset)
				if GetUnitToLocationDistance(bot, location) <= castRange then
					return BOT_ACTION_DESIRE_MODERATE, location
				end
			end
		end
		local nearbyLaneCreeps = bot:GetNearbyLaneCreeps(1600, true)
		if #nearbyLaneCreeps >= 3 then
			local furthestCreep = nearbyLaneCreeps[#nearbyLaneCreeps]
			if Fu.IsValid(furthestCreep) then
				local location = Fu.GetFaceTowardDistanceLocation(furthestCreep, 375)
				return BOT_ACTION_DESIRE_MODERATE, location
			end
		end
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE)
		local laneFrontLocation = Fu.GetNearestLaneFrontLocation(bot:GetLocation(), true, radius / 2)
		if
			#nearbyEnemies == 0
			and laneFrontLocation ~= nil
			and GetUnitToLocationDistance(bot, laneFrontLocation) <= castRange + radius
			and GetUnitToLocationDistance(bot, laneFrontLocation) >= 800
		then
			local location = Fu.GetLocationTowardDistanceLocation(bot, laneFrontLocation, castRange)
			if GetUnitToLocationDistance(bot, laneFrontLocation) < castRange then
				location = laneFrontLocation
			end
			return BOT_ACTION_DESIRE_MODERATE, location
		end
	end
	local location = Fu.GetLocationTowardDistanceLocation(bot, Fu.GetEnemyFountain(), castRange)
	if
		bot:HasModifier("modifier_arc_warden_tempest_double")
		or Fu.GetMP(bot) > 0.92 and bot:GetLevel() > 11 and not IsLocationVisible(location)
		or Fu.GetMP(bot) > 0.38 and Fu.GetDistanceFromEnemyFountain(bot) < 4300
	then
		if IsLocationPassable(location) and not bot:HasModifier("modifier_silencer_curse_of_the_silent") then
			return BOT_ACTION_DESIRE_MODERATE, location
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
return X
