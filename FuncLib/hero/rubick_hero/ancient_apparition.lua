-- How Rubick plays after stealing a spell from Ancient Apparition.
local bot
local X = {}
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local coldFeetAbility
local iceVortexAbility
local chillingTouchAbility
local iceBlastAbility
local iceBlastReleaseAbility
local iceBlastCastLocation
local botTarget
function X.ConsiderStolenSpell(ability)
	bot = GetBot()
	if Fu.CanNotUseAbility(bot) then
		return
	end
	botTarget = Fu.GetProperTarget(bot)
	local abilityName = ability:GetName()
	if abilityName == "ancient_apparition_ice_blast_release" then
		iceBlastReleaseAbility = ability
		IceBlastReleaseDesire = X.ConsiderIceBlastRelease()
		if IceBlastReleaseDesire > 0 then
			bot:Action_UseAbility(iceBlastReleaseAbility)
			return
		end
	end
	if abilityName == "ancient_apparition_ice_blast" then
		iceBlastAbility = ability
		IceBlastDesire, IceBlastLocation = X.ConsiderIceBlast()
		if IceBlastDesire > 0 then
			bot:Action_UseAbilityOnLocation(iceBlastAbility, IceBlastLocation)
			iceBlastCastLocation = IceBlastLocation
			return
		end
	end
	if abilityName == "ancient_apparition_ice_vortex" then
		iceVortexAbility = ability
		IceVortexDesire, IceVortextLocation = X.ConsiderIceVortex()
		if IceVortexDesire > 0 then
			bot:Action_UseAbilityOnLocation(iceVortexAbility, IceVortextLocation)
			return
		end
	end
	if abilityName == "ancient_apparition_cold_feet" then
		coldFeetAbility = ability
		ColdFeetDesire, ColdFeetTarget = X.ConsiderColdFeet()
		if ColdFeetDesire > 0 then
			bot:Action_UseAbilityOnEntity(coldFeetAbility, ColdFeetTarget)
			return
		end
	end
	if abilityName == "ancient_apparition_chilling_touch" then
		chillingTouchAbility = ability
		ChillingTouchDesire, ChillingTouchTarget = X.ConsiderChillingTouch()
		if ChillingTouchDesire > 0 then
			bot:Action_UseAbilityOnEntity(chillingTouchAbility, ChillingTouchTarget)
			return
		end
	end
end
function X.ConsiderColdFeet()
	if not coldFeetAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castRange = Fu.GetProperCastRange(false, bot, coldFeetAbility:GetCastRange())
	local nearbyAllies = Fu.GetNearbyHeroes(bot, castRange + 150, false, BOT_MODE_NONE)
	for _, allyHero in pairs(nearbyAllies) do
		local enemiesNearAlly = Fu.GetNearbyHeroes(allyHero, 1200, true, BOT_MODE_NONE)
		if Fu.IsValidHero(allyHero) and Fu.IsRetreating(allyHero) and allyHero:WasRecentlyDamagedByAnyHero(1.5) and not allyHero:IsIllusion() then
			if
				enemiesNearAlly ~= nil
				and #enemiesNearAlly >= 1
				and Fu.IsValidHero(enemiesNearAlly[1])
				and Fu.CanCastOnNonMagicImmune(enemiesNearAlly[1])
				and Fu.CanCastOnTargetAdvanced(enemiesNearAlly[1])
				and Fu.IsInRange(bot, enemiesNearAlly[1], castRange)
				and Fu.IsChasingTarget(enemiesNearAlly[1], allyHero)
				and not Fu.IsDisabled(enemiesNearAlly[1])
				and not Fu.IsTaunted(enemiesNearAlly[1])
				and not Fu.IsSuspiciousIllusion(enemiesNearAlly[1])
				and not enemiesNearAlly[1]:HasModifier("modifier_legion_commander_duel")
				and not enemiesNearAlly[1]:HasModifier("modifier_enigma_black_hole_pull")
				and not enemiesNearAlly[1]:HasModifier("modifier_faceless_void_chronosphere_freeze")
				and not enemiesNearAlly[1]:HasModifier("modifier_necrolyte_reapers_scythe")
			then
				return BOT_ACTION_DESIRE_HIGH, enemiesNearAlly[1]
			end
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.CanCastOnTargetAdvanced(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not Fu.IsDisabled(botTarget)
			and not botTarget:HasModifier("modifier_cold_feet")
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			local alliesNearTarget = Fu.GetNearbyHeroes(botTarget, 1000, true, BOT_MODE_NONE)
			local enemiesNearTarget = Fu.GetNearbyHeroes(botTarget, 1000, false, BOT_MODE_NONE)
			if alliesNearTarget ~= nil and enemiesNearTarget ~= nil and #alliesNearTarget >= #enemiesNearTarget then
				return BOT_ACTION_DESIRE_HIGH, botTarget
			end
		end
	end
	if Fu.IsRetreating(bot) then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, 1200, false, BOT_MODE_NONE)
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE)
		if nearbyAllies ~= nil and nearbyEnemies ~= nil then
			for _, enemyHero in pairs(nearbyEnemies) do
				if
					(#nearbyAllies > #nearbyEnemies or bot:WasRecentlyDamagedByHero(enemyHero, 1.5))
					and Fu.CanCastOnNonMagicImmune(enemyHero)
					and Fu.CanCastOnTargetAdvanced(enemyHero)
					and Fu.IsInRange(bot, enemyHero, castRange)
					and not Fu.IsSuspiciousIllusion(enemyHero)
					and not Fu.IsDisabled(enemyHero)
					and not enemyHero:HasModifier("modifier_cold_feet")
					and not enemyHero:HasModifier("modifier_ice_vortex")
				then
					return BOT_ACTION_DESIRE_HIGH, enemyHero
				end
			end
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if
			Fu.IsRoshan(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and Fu.IsAttacking(bot)
			and not botTarget:HasModifier("modifier_cold_feet")
			and not botTarget:HasModifier("modifier_ice_vortex")
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if
			Fu.IsTormentor(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and Fu.IsAttacking(bot)
			and not botTarget:HasModifier("modifier_cold_feet")
			and not botTarget:HasModifier("modifier_ice_vortex")
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function X.ConsiderIceVortex()
	if not iceVortexAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local castRange = Fu.GetProperCastRange(false, bot, iceVortexAbility:GetCastRange())
	local radius = iceVortexAbility:GetSpecialValueInt("radius")
	local castPoint = iceVortexAbility:GetCastPoint()
	if Fu.IsInTeamFight(bot, 1200) then
		local aoeLocation = bot:FindAoELocation(true, true, bot:GetLocation(), castRange, radius, 0, 0)
		local enemiesInRadius = Fu.GetEnemiesNearLoc(aoeLocation.targetloc, radius)
		if enemiesInRadius ~= nil and #enemiesInRadius then
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
			and not botTarget:HasModifier("modifier_ice_vortex")
		then
			local alliesNearTarget = Fu.GetNearbyHeroes(botTarget, 1000, true, BOT_MODE_NONE)
			local enemiesNearTarget = Fu.GetNearbyHeroes(botTarget, 1000, false, BOT_MODE_NONE)
			if alliesNearTarget ~= nil and enemiesNearTarget ~= nil and #alliesNearTarget >= #enemiesNearTarget then
				return BOT_ACTION_DESIRE_HIGH, botTarget:GetExtrapolatedLocation(castPoint)
			end
		end
	end
	if Fu.IsRetreating(bot) then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, 1200, false, BOT_MODE_NONE)
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE)
		if nearbyAllies ~= nil and nearbyEnemies ~= nil then
			for _, enemyHero in pairs(nearbyEnemies) do
				if
					(#nearbyAllies > #nearbyEnemies or bot:WasRecentlyDamagedByHero(enemyHero, 1.5))
					and Fu.CanCastOnNonMagicImmune(enemyHero)
					and Fu.IsInRange(bot, enemyHero, castRange)
					and not Fu.IsSuspiciousIllusion(enemyHero)
					and not Fu.IsDisabled(enemyHero)
					and not enemyHero:HasModifier("modifier_cold_feet")
					and not enemyHero:HasModifier("modifier_ice_vortex")
				then
					return BOT_ACTION_DESIRE_HIGH, enemyHero:GetExtrapolatedLocation(castPoint)
				end
			end
		end
	end
	if (Fu.IsDefending(bot) or Fu.IsPushing(bot)) and not Fu.IsThereNonSelfCoreNearby(1000) then
		local nearbyLaneCreeps = bot:GetNearbyLaneCreeps(castRange, true)
		local aoeLocation = bot:FindAoELocation(true, false, bot:GetLocation(), castRange, radius, castPoint, 0)
		if nearbyLaneCreeps ~= nil and #nearbyLaneCreeps >= 4 and aoeLocation.count >= 4 then
			return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
		end
		aoeLocation = bot:FindAoELocation(true, true, bot:GetLocation(), castRange, radius, castPoint, 0)
		if aoeLocation.count >= 2 then
			return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if Fu.IsRoshan(botTarget) and Fu.CanCastOnNonMagicImmune(botTarget) and Fu.IsInRange(bot, botTarget, castRange) and Fu.IsAttacking(bot) then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, castRange) and Fu.IsAttacking(bot) then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.ConsiderChillingTouch()
	if not chillingTouchAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castRange = Fu.GetProperCastRange(false, bot, chillingTouchAbility:GetCastRange()) + chillingTouchAbility:GetSpecialValueInt("attack_range_bonus")
	local damage = chillingTouchAbility:GetSpecialValueInt("damage")
	local nearbyEnemies = Fu.GetNearbyHeroes(bot, castRange + 150, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and Fu.CanCastOnTargetAdvanced(enemyHero)
			and Fu.CanKillTarget(enemyHero, damage, DAMAGE_TYPE_MAGICAL)
			and not Fu.IsSuspiciousIllusion(enemyHero)
			and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
			and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
			and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
			and not enemyHero:HasModifier("modifier_templar_assassin_refraction_absorb")
		then
			return BOT_ACTION_DESIRE_HIGH, enemyHero
		end
	end
	local nearbyAllies = Fu.GetNearbyHeroes(bot, castRange + 150, false, BOT_MODE_NONE)
	for _, allyHero in pairs(nearbyAllies) do
		local enemiesNearAlly = Fu.GetNearbyHeroes(allyHero, 1200, true, BOT_MODE_NONE)
		if Fu.IsValidHero(allyHero) and Fu.IsRetreating(allyHero) and allyHero:WasRecentlyDamagedByAnyHero(1.5) and not allyHero:IsIllusion() then
			if
				enemiesNearAlly ~= nil
				and #enemiesNearAlly >= 1
				and Fu.IsValidHero(enemiesNearAlly[1])
				and Fu.CanCastOnNonMagicImmune(enemiesNearAlly[1])
				and Fu.CanCastOnTargetAdvanced(enemiesNearAlly[1])
				and Fu.IsInRange(bot, enemiesNearAlly[1], castRange)
				and Fu.IsChasingTarget(enemiesNearAlly[1], allyHero)
				and not Fu.IsDisabled(enemiesNearAlly[1])
				and not Fu.IsTaunted(enemiesNearAlly[1])
				and not Fu.IsSuspiciousIllusion(enemiesNearAlly[1])
				and not enemiesNearAlly[1]:HasModifier("modifier_legion_commander_duel")
				and not enemiesNearAlly[1]:HasModifier("modifier_enigma_black_hole_pull")
				and not enemiesNearAlly[1]:HasModifier("modifier_faceless_void_chronosphere_freeze")
				and not enemiesNearAlly[1]:HasModifier("modifier_necrolyte_reapers_scythe")
			then
				return BOT_ACTION_DESIRE_HIGH, enemiesNearAlly[1]
			end
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.CanCastOnTargetAdvanced(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not Fu.IsDisabled(botTarget)
			and not botTarget:HasModifier("modifier_abaddon_borrowed_time")
			and not botTarget:HasModifier("modifier_dazzle_shallow_grave")
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
			and not botTarget:HasModifier("modifier_oracle_false_promise_timer")
			and not botTarget:HasModifier("modifier_templar_assassin_refraction_absorb")
		then
			local alliesNearTarget = Fu.GetNearbyHeroes(botTarget, 1200, true, BOT_MODE_NONE)
			local enemiesNearTarget = Fu.GetNearbyHeroes(botTarget, 1200, false, BOT_MODE_NONE)
			if alliesNearTarget ~= nil and enemiesNearTarget ~= nil and #alliesNearTarget >= #enemiesNearTarget then
				return BOT_ACTION_DESIRE_HIGH, botTarget
			end
		end
	end
	if Fu.IsRetreating(bot) then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, 1200, false, BOT_MODE_NONE)
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE)
		if nearbyAllies ~= nil and nearbyEnemies ~= nil then
			for _, enemyHero in pairs(nearbyEnemies) do
				if
					(#nearbyAllies > #nearbyEnemies or bot:WasRecentlyDamagedByHero(enemyHero, 1.2))
					and Fu.CanCastOnNonMagicImmune(enemyHero)
					and Fu.CanCastOnTargetAdvanced(enemyHero)
					and Fu.IsInRange(bot, enemyHero, castRange)
					and not Fu.IsSuspiciousIllusion(enemyHero)
					and not Fu.IsDisabled(enemyHero)
				then
					return BOT_ACTION_DESIRE_HIGH, enemyHero
				end
			end
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if Fu.IsRoshan(botTarget) and Fu.CanCastOnNonMagicImmune(botTarget) and Fu.IsInRange(bot, botTarget, castRange) and Fu.IsAttacking(bot) then
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, castRange) and Fu.IsAttacking(bot) then
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function X.ConsiderIceBlast()
	if not iceBlastAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local radiusMin = iceBlastAbility:GetSpecialValueInt("radius_min")
	local radiusGrow = iceBlastAbility:GetSpecialValueInt("radius_grow")
	local radiusMax = iceBlastAbility:GetSpecialValueInt("radius_max")
	if Fu.IsInTeamFight(bot, 1600) then
		local fightLocation = Fu.GetTeamFightLocation(bot)
		if fightLocation ~= nil then
			local distance = GetUnitToLocationDistance(bot, fightLocation)
			local radius = math.min(radiusMin + distance * radiusGrow, radiusMax)
			local aoeLocation = bot:FindAoELocation(true, true, bot:GetLocation(), 1600, radius, 0, 0)
			local enemiesInRadius = Fu.GetEnemiesNearLoc(aoeLocation.targetloc, radius)
			if enemiesInRadius ~= nil and #enemiesInRadius >= 2 then
				return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
			end
		end
	end
	local fightLocation = Fu.GetTeamFightLocation(bot)
	if fightLocation ~= nil then
		local distance = GetUnitToLocationDistance(bot, fightLocation)
		local radius = math.min(radiusMin + distance * radiusGrow, radiusMax)
		local enemiesInRadius = Fu.GetEnemiesNearLoc(fightLocation, radius)
		if enemiesInRadius ~= nil and #enemiesInRadius >= 1 then
			return BOT_ACTION_DESIRE_HIGH, fightLocation
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.ConsiderIceBlastRelease()
	if iceBlastReleaseAbility:IsHidden() or not iceBlastReleaseAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
	end
	local linearProjectiles = GetLinearProjectiles()
	for _, projectile in pairs(linearProjectiles) do
		if projectile ~= nil and projectile.ability:GetName() == "ancient_apparition_ice_blast" then
			if iceBlastCastLocation ~= nil and Fu.GetLocationToLocationDistance(iceBlastCastLocation, projectile.location) < 100 then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
return X
