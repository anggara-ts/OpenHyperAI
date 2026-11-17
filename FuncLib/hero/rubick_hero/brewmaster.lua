-- How Rubick plays after stealing a spell from Brewmaster.
local bot = GetBot()
local X = {}
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local thunderClapAbility
local cinderBrewAbility
local botTarget
function X.ConsiderStolenSpell(ability)
	bot = GetBot()
	if Fu.CanNotUseAbility(bot) then
		return
	end
	botTarget = Fu.GetProperTarget(bot)
	local abilityName = ability:GetName()
	if abilityName == "brewmaster_cinder_brew" then
		cinderBrewAbility = ability
		local CinderBrewDesire, CinderBrewLocation = X.ConsiderCinderBrew()
		if CinderBrewDesire > 0 then
			bot:Action_UseAbilityOnLocation(cinderBrewAbility, CinderBrewLocation)
			return
		end
	end
	if abilityName == "brewmaster_thunder_clap" then
		thunderClapAbility = ability
		local ThunderClapDesire = X.ConsiderThunderClap()
		if ThunderClapDesire > 0 then
			bot:Action_UseAbility(thunderClapAbility)
			return
		end
	end
end
function X.ConsiderThunderClap()
	if not thunderClapAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
	end
	local radius = thunderClapAbility:GetSpecialValueInt("radius")
	local damage = thunderClapAbility:GetSpecialValueInt("damage")
	local enemiesInRadius = Fu.GetNearbyHeroes(bot, radius - 75, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(enemiesInRadius) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and Fu.CanKillTarget(enemyHero, damage, DAMAGE_TYPE_MAGICAL)
			and not Fu.IsSuspiciousIllusion(enemyHero)
			and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
			and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
			and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
			and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
			and not enemyHero:HasModifier("modifier_templar_assassin_refraction_absorb")
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, radius - 75)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not Fu.IsDisabled(botTarget)
			and not botTarget:HasModifier("modifier_abaddon_borrowed_time")
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			local nearbyAllies = Fu.GetNearbyHeroes(botTarget, 1200, true, BOT_MODE_NONE)
			local nearbyEnemies = Fu.GetNearbyHeroes(botTarget, 1200, false, BOT_MODE_NONE)
			if nearbyAllies ~= nil and nearbyEnemies ~= nil and #nearbyAllies >= #nearbyEnemies then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	if Fu.IsRetreating(bot) then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, 1200, false, BOT_MODE_NONE)
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE)
		if
			nearbyAllies ~= nil
			and nearbyEnemies ~= nil
			and Fu.IsValidHero(nearbyEnemies[1])
			and Fu.IsInRange(bot, nearbyEnemies[1], radius)
			and Fu.IsChasingTarget(nearbyEnemies[1], bot)
			and not Fu.IsSuspiciousIllusion(nearbyEnemies[1])
			and not Fu.IsDisabled(nearbyEnemies[1])
			and not nearbyEnemies[1]:HasModifier("modifier_brewmaster_cinder_brew")
		then
			local chaserAllies = Fu.GetNearbyHeroes(nearbyEnemies[1], 1200, false, BOT_MODE_NONE)
			if chaserAllies ~= nil and (#chaserAllies > #nearbyAllies or bot:WasRecentlyDamagedByAnyHero(1.5)) then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	if Fu.IsPushing(bot) or Fu.IsDefending(bot) then
		local laneCreeps = bot:GetNearbyLaneCreeps(radius, true)
		if laneCreeps ~= nil and #laneCreeps >= 4 then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsFarming(bot) then
		if Fu.IsAttacking(bot) and Fu.GetMP(bot) > 0.4 then
			local neutralCreeps = bot:GetNearbyNeutralCreeps(radius)
			if
				neutralCreeps ~= nil
				and (#neutralCreeps >= 3 or #neutralCreeps >= 2 and neutralCreeps[1]:IsAncientCreep())
			then
				return BOT_ACTION_DESIRE_HIGH
			end
			local laneCreeps = bot:GetNearbyLaneCreeps(radius, true)
			if laneCreeps ~= nil and #laneCreeps >= 3 then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	if Fu.IsLaning(bot) then
		local killableCreepCount = 0
		local killableCreeps = {}
		local laneCreeps = bot:GetNearbyLaneCreeps(radius, true)
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, 1000, true, BOT_MODE_NONE)
		for _, creep in pairs(laneCreeps) do
			if Fu.IsValid(creep) and creep:GetHealth() <= damage then
				killableCreepCount = killableCreepCount + 1
				table.insert(killableCreeps, creep)
			end
		end
		if killableCreepCount >= 2 and Fu.GetMP(bot) > 0.33 and nearbyEnemies ~= nil and #nearbyEnemies >= 1 then
			return BOT_ACTION_DESIRE_HIGH
		end
		if Fu.IsInLaningPhase() then
			nearbyEnemies = Fu.GetEnemiesNearLoc(bot:GetLocation(), radius)
			if nearbyEnemies ~= nil and #nearbyEnemies >= 1 and Fu.GetMP(bot) > 0.5 then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if
			Fu.IsRoshan(botTarget)
			and Fu.CanCastOnMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, radius)
			and Fu.IsAttacking(bot)
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, radius) and Fu.IsAttacking(bot) then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderCinderBrew()
	if not cinderBrewAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local radius = cinderBrewAbility:GetSpecialValueInt("radius")
	local castRange = Fu.GetProperCastRange(false, bot, cinderBrewAbility:GetCastRange())
	local castPoint = cinderBrewAbility:GetCastPoint()
	if Fu.IsInTeamFight(bot, 1200) then
		local aoeLocation = bot:FindAoELocation(true, true, bot:GetLocation(), castRange, radius, castPoint, 0)
		local nearbyEnemies = Fu.GetEnemiesNearLoc(aoeLocation.targetloc, radius)
		if nearbyEnemies ~= nil and #nearbyEnemies >= 2 then
			return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not Fu.IsDisabled(botTarget)
			and not botTarget:HasModifier("modifier_abaddon_borrowed_time")
			and not botTarget:HasModifier("modifier_brewmaster_cinder_brew")
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			local nearbyAllies = Fu.GetNearbyHeroes(botTarget, 1200, true, BOT_MODE_NONE)
			local nearbyEnemies = Fu.GetNearbyHeroes(botTarget, 1200, false, BOT_MODE_NONE)
			if nearbyAllies ~= nil and nearbyEnemies ~= nil and #nearbyAllies >= #nearbyEnemies then
				return BOT_ACTION_DESIRE_HIGH, botTarget:GetExtrapolatedLocation(castPoint)
			end
		end
	end
	if Fu.IsRetreating(bot) then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, 1200, false, BOT_MODE_NONE)
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE)
		if
			nearbyAllies ~= nil
			and nearbyEnemies ~= nil
			and Fu.IsValidHero(nearbyEnemies[1])
			and Fu.IsInRange(bot, nearbyEnemies[1], radius)
			and Fu.IsChasingTarget(nearbyEnemies[1], bot)
			and not Fu.IsSuspiciousIllusion(nearbyEnemies[1])
			and not Fu.IsDisabled(nearbyEnemies[1])
			and not nearbyEnemies[1]:HasModifier("modifier_brewmaster_cinder_brew")
		then
			local chaserAllies = Fu.GetNearbyHeroes(nearbyEnemies[1], 1200, false, BOT_MODE_NONE)
			if chaserAllies ~= nil and (#chaserAllies > #nearbyAllies or bot:WasRecentlyDamagedByAnyHero(1.5)) then
				return BOT_ACTION_DESIRE_HIGH, nearbyEnemies[1]:GetLocation()
			end
		end
	end
	if Fu.IsPushing(bot) or Fu.IsDefending(bot) then
		local laneCreeps = bot:GetNearbyLaneCreeps(radius, true)
		if laneCreeps ~= nil and #laneCreeps >= 4 then
			return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(laneCreeps)
		end
		local aoeLocation = bot:FindAoELocation(true, true, bot:GetLocation(), castRange, radius, 0, 0)
		if aoeLocation.count >= 1 then
			return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
		end
	end
	if Fu.IsFarming(bot) then
		if Fu.IsAttacking(bot) and Fu.GetMP(bot) > 0.45 then
			local neutralCreeps = bot:GetNearbyNeutralCreeps(radius)
			if
				neutralCreeps ~= nil
				and (#neutralCreeps >= 3 or #neutralCreeps >= 2 and neutralCreeps[1]:IsAncientCreep())
			then
				return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(neutralCreeps)
			end
			local laneCreeps = bot:GetNearbyLaneCreeps(radius, true)
			if laneCreeps ~= nil and #laneCreeps >= 3 then
				return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(laneCreeps)
			end
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if
			Fu.IsRoshan(botTarget)
			and Fu.CanCastOnMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, radius)
			and Fu.IsAttacking(bot)
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, radius) and Fu.IsAttacking(bot) then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
return X
