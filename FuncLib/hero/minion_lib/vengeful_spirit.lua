-- Thinking for summoned units: vengeful spirit.
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local MinionUtils = require(GetScriptDirectory() .. "/FuncLib/hero/minion_lib/utils")
local Illusions = require(GetScriptDirectory() .. "/FuncLib/hero/minion_lib/illusions")
local X = {}
local bot
local nearbyAllies, nearbyEnemies
function X.Think(ownerBot, minion)
	bot = ownerBot
	if not MinionUtils.IsValidUnit(minion) or Fu.CanNotUseAbility(minion) then
		return
	end
	if minion.abilities == nil then
		MinionUtils.InitiateAbility(minion)
	end
	nearbyAllies = minion:GetNearbyHeroes(1600, false, BOT_MODE_NONE)
	nearbyEnemies = minion:GetNearbyHeroes(1600, true, BOT_MODE_NONE)
	if minion.abilities[1]:GetName() == "vengefulspirit_magic_missile" then
		minion.cast_desire, minion.cast_target = X.ConsiderMagicMissile(minion, minion.abilities[1])
		if minion.cast_desire > 0 then
			minion:Action_UseAbilityOnEntity(minion.abilities[1], minion.cast_target)
			return
		end
	end
	if minion.abilities[2]:GetName() == "vengefulspirit_wave_of_terror" then
		minion.cast_desire, minion.cast_location = X.ConsiderWaveOfTerror(minion, minion.abilities[2])
		if minion.cast_desire > 0 then
			minion:Action_UseAbilityOnLocation(minion.abilities[2], minion.cast_location)
			return
		end
	end
	if minion.abilities[6]:GetName() == "vengefulspirit_nether_swap" then
		minion.cast_desire, minion.cast_target = X.ConsiderNetherSwap(minion, minion.abilities[6])
		if minion.cast_desire > 0 then
			minion:Action_UseAbilityOnEntity(minion.abilities[6], minion.cast_target)
			return
		end
	end
	Illusions.Think(bot, minion)
end
function X.ConsiderMagicMissile(minion, ability)
	if not Fu.CanCastAbility(ability) then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castRange = Fu.GetProperCastRange(false, minion, ability:GetCastRange())
	local damage = ability:GetSpecialValueInt("magic_missile_damage")
	for _, enemyHero in pairs(nearbyEnemies) do
		if Fu.IsValidHero(enemyHero) and Fu.CanCastOnNonMagicImmune(enemyHero) and Fu.CanCastOnTargetAdvanced(enemyHero) then
			if enemyHero:IsChanneling() and Fu.IsInRange(minion, enemyHero, castRange + 300) then
				return BOT_ACTION_DESIRE_HIGH, enemyHero
			end
			if
				Fu.CanKillTarget(enemyHero, damage, DAMAGE_TYPE_MAGICAL)
				and Fu.IsInRange(minion, enemyHero, castRange + 150)
				and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
				and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
				and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
				and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
			then
				return BOT_ACTION_DESIRE_HIGH, enemyHero
			end
		end
	end
	for _, allyHero in pairs(nearbyAllies) do
		if Fu.IsValidHero(allyHero) and Fu.IsRetreating(allyHero) and allyHero:WasRecentlyDamagedByAnyHero(3.0) and not allyHero:IsIllusion() then
			local allyNearbyEnemies = allyHero:GetNearbyHeroes(1600, true, BOT_MODE_NONE)
			if
				Fu.IsValidHero(allyNearbyEnemies[1])
				and Fu.CanCastOnNonMagicImmune(allyNearbyEnemies[1])
				and Fu.CanCastOnTargetAdvanced(allyNearbyEnemies[1])
				and Fu.IsInRange(minion, allyNearbyEnemies[1], castRange)
				and Fu.IsChasingTarget(allyNearbyEnemies[1], allyHero)
				and not Fu.IsDisabled(allyNearbyEnemies[1])
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
			and Fu.CanCastOnTargetAdvanced(enemyHero)
			and not Fu.IsDisabled(enemyHero)
			and not enemyHero:HasModifier("modifier_enigma_black_hole_pull")
			and not enemyHero:HasModifier("modifier_faceless_void_chronosphere_freeze")
			and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			local estimatedDamage = enemyHero:GetEstimatedDamageToTarget(false, minion, 5, DAMAGE_TYPE_ALL)
			if maxDamage < estimatedDamage then
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
function X.ConsiderWaveOfTerror(minion, ability)
	if not Fu.CanCastAbility(ability) then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local castRange = Fu.GetProperCastRange(false, minion, ability:GetCastRange())
	local castPoint = ability:GetCastPoint()
	local waveWidth = ability:GetSpecialValueInt("wave_width")
	local waveSpeed = ability:GetSpecialValueInt("wave_speed")
	local damage = ability:GetAbilityDamage()
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and Fu.CanKillTarget(enemyHero, damage, DAMAGE_TYPE_MAGICAL)
			and Fu.IsChasingTarget(minion, enemyHero)
			and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
			and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
			and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
			and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
		then
			local aoeLocation = minion:FindAoELocation(true, true, enemyHero:GetLocation(), waveWidth, waveWidth, 0, 0)
			if aoeLocation.count >= 2 then
				return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
			else
				local delay = GetUnitToUnitDistance(minion, enemyHero) / waveSpeed + castPoint
				return BOT_ACTION_DESIRE_HIGH, Fu.GetCorrectLoc(enemyHero, delay)
			end
		end
	end
	local strongestTarget = nil
	local maxDamage = 0
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and not Fu.IsDisabled(enemyHero)
			and not enemyHero:HasModifier("modifier_enigma_black_hole_pull")
			and not enemyHero:HasModifier("modifier_faceless_void_chronosphere_freeze")
			and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			local estimatedDamage = enemyHero:GetEstimatedDamageToTarget(false, minion, 5, DAMAGE_TYPE_ALL)
			if maxDamage < estimatedDamage then
				maxDamage = estimatedDamage
				strongestTarget = enemyHero
			end
		end
	end
	if strongestTarget ~= nil then
		local aoeLocation = minion:FindAoELocation(true, true, strongestTarget:GetLocation(), waveWidth, waveWidth, 0, 0)
		if aoeLocation.count >= 2 then
			return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
		else
			local delay = GetUnitToUnitDistance(minion, strongestTarget) / waveSpeed + castPoint
			return BOT_ACTION_DESIRE_HIGH, Fu.GetCorrectLoc(strongestTarget, delay)
		end
	end
	local nearbyLaneCreeps = minion:GetNearbyLaneCreeps(castRange, true)
	if #nearbyLaneCreeps >= 3 and Fu.CanBeAttacked(nearbyLaneCreeps[1]) and not Fu.IsRunning(nearbyLaneCreeps[1]) and not Fu.IsThereCoreNearby(1200) then
		return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(nearbyLaneCreeps)
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.ConsiderNetherSwap(minion, ability)
	if not Fu.CanCastAbility(ability) then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castRange = Fu.GetProperCastRange(false, minion, ability:GetCastRange())
	for _, allyHero in pairs(nearbyAllies) do
		if Fu.IsValidHero(allyHero) and Fu.IsInRange(minion, allyHero, castRange + 300) and Fu.IsCore(allyHero) and not Fu.IsSuspiciousIllusion(allyHero) then
			if Fu.IsInTeamFight(allyHero, 1200) and not Fu.IsInRange(minion, allyHero, castRange) and MinionUtils.CantMove(allyHero) then
				return BOT_ACTION_DESIRE_HIGH, allyHero
			end
			if
				allyHero:HasModifier("modifier_faceless_void_chronosphere_freeze")
				or allyHero:HasModifier("modifier_enigma_black_hole_pull")
				or allyHero:HasModifier("modifier_mars_arena_of_blood_leash")
					and not minion:HasModifier("modifier_mars_arena_of_blood_leash")
			then
				return BOT_ACTION_DESIRE_HIGH, allyHero
			end
		end
	end
	local strongestTarget = nil
	local maxDamage = 0
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.IsInRange(minion, enemyHero, castRange)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and Fu.CanCastOnTargetAdvanced(enemyHero)
			and not Fu.IsInRange(minion, enemyHero, castRange / 2)
			and not Fu.IsDisabled(enemyHero)
			and not enemyHero:HasModifier("modifier_enigma_black_hole_pull")
			and not enemyHero:HasModifier("modifier_faceless_void_chronosphere_freeze")
			and not enemyHero:HasModifier("modifier_legion_commander_duel")
			and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
			and not enemyHero:WasRecentlyDamagedByAnyHero(2.0)
		then
			local estimatedDamage = enemyHero:GetEstimatedDamageToTarget(false, minion, 5, DAMAGE_TYPE_ALL)
			if #nearbyAllies >= #nearbyEnemies and #nearbyAllies >= 1 and #nearbyAllies <= #nearbyEnemies + 2 and maxDamage < estimatedDamage then
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
