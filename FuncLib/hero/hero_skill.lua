-- Hero-specific helper: hero skill.
local bot = GetBot()
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local X = {}
function X.ConsiderMagicMissile(unit, magicMissileAbility)
	if not magicMissileAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castRange = Fu.GetProperCastRange(false, unit, magicMissileAbility:GetCastRange())
	local damage = magicMissileAbility:GetSpecialValueInt("magic_missile_damage")
	local nearbyEnemies = unit:GetNearbyHeroes(castRange, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and not Fu.IsSuspiciousIllusion(enemyHero)
		then
			if enemyHero:IsChanneling() then
				return BOT_ACTION_DESIRE_HIGH, enemyHero
			end
			if
				Fu.CanKillTarget(enemyHero, damage, DAMAGE_TYPE_MAGICAL)
				and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
				and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
				and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
				and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
				and not enemyHero:HasModifier("modifier_templar_assassin_refraction_absorb")
			then
				return BOT_ACTION_DESIRE_HIGH, enemyHero
			end
		end
	end
	local nearbyAllies = unit:GetNearbyHeroes(castRange, false, BOT_MODE_NONE)
	for _, allyHero in pairs(nearbyAllies) do
		local allyNearbyEnemies = Fu.GetNearbyHeroes(allyHero, 1200, true, BOT_MODE_NONE)
		if
			Fu.IsValidHero(allyHero)
			and Fu.IsRetreating(allyHero)
			and allyHero:WasRecentlyDamagedByAnyHero(1.5)
			and not allyHero:IsIllusion()
		then
			if
				allyNearbyEnemies ~= nil
				and #allyNearbyEnemies >= 1
				and Fu.IsValidHero(allyNearbyEnemies[1])
				and Fu.CanCastOnNonMagicImmune(allyNearbyEnemies[1])
				and Fu.CanCastOnTargetAdvanced(allyNearbyEnemies[1])
				and Fu.IsInRange(unit, allyNearbyEnemies[1], castRange)
				and Fu.IsChasingTarget(allyNearbyEnemies[1], allyHero)
				and allyNearbyEnemies[1]:IsFacingLocation(allyHero:GetLocation(), 30)
				and not Fu.IsDisabled(allyNearbyEnemies[1])
				and not Fu.IsTaunted(allyNearbyEnemies[1])
				and not Fu.IsSuspiciousIllusion(allyNearbyEnemies[1])
				and not allyNearbyEnemies[1]:HasModifier("modifier_legion_commander_duel")
				and not allyNearbyEnemies[1]:HasModifier("modifier_enigma_black_hole_pull")
				and not allyNearbyEnemies[1]:HasModifier("modifier_faceless_void_chronosphere_freeze")
				and not allyNearbyEnemies[1]:HasModifier("modifier_necrolyte_reapers_scythe")
			then
				return BOT_ACTION_DESIRE_HIGH, allyNearbyEnemies[1]
			end
		end
	end
	local strongestTarget = nil
	local maxDamage = 0
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and not Fu.IsSuspiciousIllusion(enemyHero)
			and not Fu.IsDisabled(enemyHero)
			and not enemyHero:HasModifier("modifier_enigma_black_hole_pull")
			and not enemyHero:HasModifier("modifier_faceless_void_chronosphere_freeze")
			and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			local targetEnemies = Fu.GetNearbyHeroes(enemyHero, 1200, true, BOT_MODE_NONE)
			local targetAllies = Fu.GetNearbyHeroes(enemyHero, 1200, false, BOT_MODE_NONE)
			local estimatedDamage = enemyHero:GetEstimatedDamageToTarget(true, unit, 5, DAMAGE_TYPE_ALL)
			if
				targetEnemies ~= nil
				and targetAllies ~= nil
				and #targetEnemies >= #targetAllies
				and maxDamage < estimatedDamage
			then
				maxDamage = estimatedDamage
				strongestTarget = enemyHero
			end
		end
	end
	if strongestTarget ~= nil then
		return BOT_ACTION_DESIRE_HIGH, strongestTarget
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function X.ConsiderWaveOfTerror(unit, waveOfTerrorAbility)
	if not waveOfTerrorAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local castRange = Fu.GetProperCastRange(false, unit, waveOfTerrorAbility:GetCastRange())
	local waveWidth = waveOfTerrorAbility:GetSpecialValueInt("wave_width")
	local damage = waveOfTerrorAbility:GetAbilityDamage()
	local nearbyEnemies = unit:GetNearbyHeroes(castRange, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(nearbyEnemies) do
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
			local enemiesNearTarget = Fu.GetEnemiesNearLoc(enemyHero:GetLocation(), waveWidth)
			if enemiesNearTarget ~= nil and #enemiesNearTarget >= 1 then
				return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(enemiesNearTarget)
			end
			return BOT_ACTION_DESIRE_HIGH, enemyHero:GetLocation()
		end
	end
	local strongestTarget = nil
	local maxDamage = 0
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and not Fu.IsSuspiciousIllusion(enemyHero)
			and not Fu.IsDisabled(enemyHero)
			and not enemyHero:HasModifier("modifier_enigma_black_hole_pull")
			and not enemyHero:HasModifier("modifier_faceless_void_chronosphere_freeze")
			and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			local targetEnemies = Fu.GetNearbyHeroes(enemyHero, 1200, true, BOT_MODE_NONE)
			local targetAllies = Fu.GetNearbyHeroes(enemyHero, 1200, false, BOT_MODE_NONE)
			local estimatedDamage = enemyHero:GetEstimatedDamageToTarget(true, unit, 5, DAMAGE_TYPE_ALL)
			if
				targetEnemies ~= nil
				and targetAllies ~= nil
				and #targetEnemies >= #targetAllies
				and maxDamage < estimatedDamage
			then
				maxDamage = estimatedDamage
				strongestTarget = enemyHero
			end
		end
	end
	if strongestTarget ~= nil then
		nearbyEnemies = Fu.GetEnemiesNearLoc(strongestTarget:GetLocation(), waveWidth)
		if nearbyEnemies ~= nil and #nearbyEnemies >= 1 then
			return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(nearbyEnemies)
		end
		return BOT_ACTION_DESIRE_HIGH, strongestTarget:GetLocation()
	end
	local aoeLocation = unit:FindAoELocation(true, false, unit:GetLocation(), castRange, waveWidth, 0, 0)
	local nearbyLaneCreeps = unit:GetNearbyLaneCreeps(castRange, true)
	if
		nearbyLaneCreeps ~= nil
		and #nearbyLaneCreeps >= 3
		and aoeLocation.count >= 3
		and not Fu.IsThereNonSelfCoreNearby(1000)
	then
		return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(nearbyLaneCreeps)
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.ConsiderNetherSwap(unit, netherSwapAbility)
	if not netherSwapAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castRange = Fu.GetProperCastRange(false, unit, netherSwapAbility:GetCastRange())
	local nearbyAllies = unit:GetNearbyHeroes(castRange, false, BOT_MODE_NONE)
	for _, allyHero in pairs(nearbyAllies) do
		if Fu.IsValidHero(allyHero) and Fu.IsCore(allyHero) and not Fu.IsSuspiciousIllusion(allyHero) then
			if
				allyHero:HasModifier("modifier_faceless_void_chronosphere_freeze")
				or allyHero:HasModifier("modifier_enigma_black_hole_pull")
				or allyHero:HasModifier("modifier_legion_commander_duel")
				or allyHero:HasModifier("modifier_mars_arena_of_blood_leash")
					and not unit:HasModifier("modifier_mars_arena_of_blood_leash")
			then
				return BOT_ACTION_DESIRE_HIGH, allyHero
			end
		end
	end
	local strongestTarget = nil
	local maxDamage = 0
	local nearbyEnemies = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and not Fu.IsInRange(unit, enemyHero, castRange / 2)
			and not Fu.IsSuspiciousIllusion(enemyHero)
			and not Fu.IsDisabled(enemyHero)
			and not enemyHero:HasModifier("modifier_enigma_black_hole_pull")
			and not enemyHero:HasModifier("modifier_faceless_void_chronosphere_freeze")
			and not enemyHero:HasModifier("modifier_legion_commander_duel")
			and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
			and not enemyHero:WasRecentlyDamagedByAnyHero(2)
		then
			local targetEnemies = Fu.GetNearbyHeroes(enemyHero, 1200, true, BOT_MODE_NONE)
			local targetAllies = Fu.GetNearbyHeroes(enemyHero, 1200, false, BOT_MODE_NONE)
			local estimatedDamage = enemyHero:GetEstimatedDamageToTarget(true, bot, 5, DAMAGE_TYPE_ALL)
			if
				targetEnemies ~= nil
				and targetAllies ~= nil
				and #targetEnemies >= #targetAllies
				and #targetEnemies >= 1
				and #targetEnemies <= #targetAllies + 2
				and maxDamage < estimatedDamage
			then
				maxDamage = estimatedDamage
				strongestTarget = enemyHero
			end
		end
	end
	if strongestTarget ~= nil then
		return BOT_ACTION_DESIRE_HIGH, strongestTarget
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
return X
