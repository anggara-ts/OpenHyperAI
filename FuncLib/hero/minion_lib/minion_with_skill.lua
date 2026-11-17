-- Thinking for summoned units: minion with skill.
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local MinionUtils = require(GetScriptDirectory() .. "/FuncLib/hero/minion_lib/utils")
local Illusions = require(GetScriptDirectory() .. "/FuncLib/hero/minion_lib/illusions")
local X = {}
X.ConsiderSpellUsage = {}
local bot
local unusedTarget, botTarget
local nearbyAllies, nearbyEnemies
function X.Think(ownerBot, minion)
	bot = ownerBot
	if MinionUtils.CanNotUseAbility(minion) then
		Illusions.Think(bot, minion)
		return
	end
	if minion.abilities == nil then
		MinionUtils.InitiateAbility(minion)
	end
	if #minion.abilities <= 0 then
		Illusions.Think(bot, minion)
		return
	end
	for i = 1, #minion.abilities do
		local ability = minion:GetAbilityByName(minion.abilities[i]:GetName())
		if Fu.CanCastAbility(ability) then
			botTarget = Fu.GetProperTarget(bot)
			nearbyAllies = minion:GetNearbyHeroes(1600, false, BOT_MODE_NONE)
			nearbyEnemies = minion:GetNearbyHeroes(1600, true, BOT_MODE_NONE)
			local considerSpell = X.ConsiderSpellUsage[ability:GetName()] or X.ConsiderSpellUsage["default"]
			minion.cast_desire, minion.cast_target, minion.cast_type = considerSpell(minion, ability)
			if minion.cast_desire > 0 then
				if minion.cast_type == "unit" then
					minion:Action_UseAbilityOnEntity(ability, minion.cast_target)
					return
				elseif minion.cast_type == "point" then
					minion:Action_UseAbilityOnLocation(ability, minion.cast_target)
					return
				elseif minion.cast_type == "none" then
					minion:Action_UseAbility(ability)
					return
				end
			end
			if Fu.CheckBitfieldFlag(ability:GetBehavior(), ABILITY_BEHAVIOR_UNIT_TARGET) then
				minion.cast_desire, minion.cast_target = X.ConsiderUnitTarget(minion, ability)
				if minion.cast_desire > 0 then
					minion:Action_UseAbilityOnEntity(ability, minion.cast_target)
					return
				end
			end
		end
	end
	Illusions.Think(bot, minion)
end
function X.ConsiderUnitTarget(minion, ability)
	local isAttacking = Fu.IsAttacking(minion)
	local minionHp = Fu.GetHP(minion)
	local castRange = ability:GetCastRange()
	for _, enemyHero in pairs(nearbyEnemies) do
		if Fu.IsValidHero(enemyHero) and Fu.IsInRange(minion, enemyHero, castRange) then
			return BOT_ACTION_DESIRE_HIGH, enemyHero, "unit"
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
X.ConsiderSpellUsage["default"] = function(minion, ability)
	log("[WARN] No function for the usage of ability: %s, for unit owned by: %s", ability:GetName(), bot:GetUnitName())
	return 0, nil, nil
end
X.ConsiderSpellUsage["enraged_wildkin_tornado"] = function(minion, ability)
	local castRange = ability:GetCastRange()
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(minion, botTarget, castRange)
			and not Fu.IsChasingTarget(bot, botTarget)
			and not Fu.IsDisabled(botTarget)
			and not botTarget:HasModifier("modifier_abaddon_borrowed_time")
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation(), "point"
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil, ""
end
X.ConsiderSpellUsage["enraged_wildkin_hurricane"] = function(minion, ability)
	local castRange = ability:GetCastRange()
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(minion, botTarget, castRange)
			and not Fu.IsChasingTarget(bot, botTarget)
			and not Fu.IsDisabled(botTarget)
			and not botTarget:HasModifier("modifier_abaddon_borrowed_time")
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget, "unit"
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil, ""
end
X.ConsiderSpellUsage["polar_furbolg_ursa_warrior_thunder_clap"] = function(minion, ability)
	local radius = ability:GetSpecialValueInt("radius")
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.IsInRange(minion, enemyHero, radius)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and Fu.CanKillTarget(enemyHero, radius, DAMAGE_TYPE_MAGICAL)
			and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
			and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
			and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
			and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
			and not enemyHero:HasModifier("modifier_templar_assassin_refraction_absorb")
		then
			return BOT_ACTION_DESIRE_HIGH, nil, "none"
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(minion, botTarget, radius)
			and not Fu.IsDisabled(botTarget)
			and not botTarget:HasModifier("modifier_abaddon_borrowed_time")
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			return BOT_ACTION_DESIRE_HIGH, nil, "none"
		end
	end
	if Fu.IsRetreating(bot) and not Fu.IsRealInvisible(bot) and bot:WasRecentlyDamagedByAnyHero(3.0) then
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.IsChasingTarget(enemyHero, bot)
				and Fu.IsInRange(minion, enemyHero, radius)
				and not Fu.IsDisabled(enemyHero)
			then
				return BOT_ACTION_DESIRE_HIGH, nil, "none"
			end
		end
	end
	for _, allyHero in pairs(nearbyAllies) do
		if Fu.IsValidHero(allyHero) and Fu.IsRetreating(allyHero) and not allyHero:IsIllusion() then
			local enemiesNearAlly = allyHero:GetNearbyHeroes(1600, true, BOT_MODE_NONE)
			if
				Fu.IsValidHero(enemiesNearAlly[1])
				and Fu.CanCastOnNonMagicImmune(enemiesNearAlly[1])
				and Fu.IsInRange(minion, enemiesNearAlly[1], radius)
				and Fu.IsChasingTarget(enemiesNearAlly[1], allyHero)
				and not Fu.IsDisabled(enemiesNearAlly[1])
			then
				return BOT_ACTION_DESIRE_HIGH, nil, "none"
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil, ""
end
X.ConsiderSpellUsage["ogre_bruiser_ogre_smash"] = function(minion, ability)
	return BOT_ACTION_DESIRE_NONE, nil, ""
end
X.ConsiderSpellUsage["ogre_magi_frost_armor"] = function(minion, ability)
	return BOT_ACTION_DESIRE_NONE, nil, ""
end
X.ConsiderSpellUsage["dark_troll_warlord_ensnare"] = function(minion, ability)
	local castRange = ability:GetCastRange()
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and Fu.CanCastOnTargetAdvanced(enemyHero)
			and Fu.IsInRange(minion, enemyHero, castRange)
			and (enemyHero:IsChanneling() or Fu.IsCastingUltimateAbility(enemyHero))
		then
			return BOT_ACTION_DESIRE_HIGH, enemyHero, "unit"
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.CanCastOnTargetAdvanced(botTarget)
			and Fu.IsInRange(minion, botTarget, castRange)
			and not Fu.IsDisabled(botTarget)
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget, "unit"
		end
	end
	if Fu.IsRetreating(bot) and not Fu.IsRealInvisible(bot) and bot:WasRecentlyDamagedByAnyHero(3.0) then
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
				and Fu.IsChasingTarget(enemyHero, bot)
				and Fu.IsInRange(minion, enemyHero, castRange)
				and not Fu.IsDisabled(enemyHero)
			then
				return BOT_ACTION_DESIRE_HIGH, enemyHero, "unit"
			end
		end
	end
	for _, allyHero in pairs(nearbyAllies) do
		if Fu.IsValidHero(allyHero) and Fu.IsRetreating(allyHero) and not allyHero:IsIllusion() then
			local enemiesNearAlly = allyHero:GetNearbyHeroes(1600, true, BOT_MODE_NONE)
			if
				Fu.IsValidHero(enemiesNearAlly[1])
				and Fu.CanCastOnNonMagicImmune(enemiesNearAlly[1])
				and Fu.CanCastOnTargetAdvanced(enemiesNearAlly[1])
				and Fu.IsInRange(minion, enemiesNearAlly[1], castRange)
				and Fu.IsChasingTarget(enemiesNearAlly[1], allyHero)
				and not Fu.IsDisabled(enemiesNearAlly[1])
			then
				return BOT_ACTION_DESIRE_HIGH, enemiesNearAlly[1], "unit"
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil, ""
end
X.ConsiderSpellUsage["dark_troll_warlord_raise_dead"] = function(minion, ability)
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanBeAttacked(botTarget)
			and Fu.IsInRange(minion, botTarget, 700)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not botTarget:HasModifier("modifier_faceless_void_chronosphere_freeze")
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			return BOT_ACTION_DESIRE_HIGH, nil, "none"
		end
	end
	if Fu.IsPushing(bot) then
		if Fu.IsValidBuilding(botTarget) and Fu.IsInRange(minion, botTarget, 700) and Fu.CanBeAttacked(botTarget) then
			return BOT_ACTION_DESIRE_HIGH, nil, "none"
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(minion, botTarget, 800) and Fu.IsAttacking(bot) then
			return BOT_ACTION_DESIRE_HIGH, nil, "none"
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil, ""
end
X.ConsiderSpellUsage["mud_golem_hurl_boulder"] = function(minion, ability)
	local castRange = ability:GetCastRange()
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and Fu.CanCastOnTargetAdvanced(enemyHero)
			and Fu.IsInRange(minion, enemyHero, castRange)
			and (enemyHero:IsChanneling() or Fu.IsCastingUltimateAbility(enemyHero))
		then
			return BOT_ACTION_DESIRE_HIGH, enemyHero, "unit"
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.CanCastOnTargetAdvanced(botTarget)
			and Fu.IsInRange(minion, botTarget, castRange)
			and Fu.IsChasingTarget(bot, botTarget)
			and not Fu.IsDisabled(botTarget)
			and not botTarget:HasModifier("modifier_abaddon_borrowed_time")
			and not botTarget:HasModifier("modifier_dazzle_shallow_grave")
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget, "unit"
		end
	end
	if Fu.IsRetreating(bot) and not Fu.IsRealInvisible(bot) and bot:WasRecentlyDamagedByAnyHero(3.0) then
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
				and Fu.IsChasingTarget(enemyHero, bot)
				and Fu.IsInRange(minion, enemyHero, castRange)
				and not Fu.IsDisabled(enemyHero)
			then
				return BOT_ACTION_DESIRE_HIGH, enemyHero, "unit"
			end
		end
	end
	for _, allyHero in pairs(nearbyAllies) do
		if Fu.IsValidHero(allyHero) and Fu.IsRetreating(allyHero) and not allyHero:IsIllusion() then
			local enemiesNearAlly = allyHero:GetNearbyHeroes(1600, true, BOT_MODE_NONE)
			if
				Fu.IsValidHero(enemiesNearAlly[1])
				and Fu.CanCastOnNonMagicImmune(enemiesNearAlly[1])
				and Fu.CanCastOnTargetAdvanced(enemiesNearAlly[1])
				and Fu.IsInRange(minion, enemiesNearAlly[1], castRange)
				and Fu.IsChasingTarget(enemiesNearAlly[1], allyHero)
				and not Fu.IsDisabled(enemiesNearAlly[1])
			then
				return BOT_ACTION_DESIRE_HIGH, enemiesNearAlly[1], "unit"
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil, ""
end
X.ConsiderSpellUsage["big_thunder_lizard_slam"] = function(minion, ability)
	local radius = ability:GetSpecialValueInt("radius")
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(minion, botTarget, radius)
			and not botTarget:HasModifier("modifier_abaddon_borrowed_time")
			and not botTarget:HasModifier("modifier_dazzle_shallow_grave")
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			local enemiesInRadius = Fu.GetEnemiesNearLoc(minion:GetLocation(), radius)
			if #enemiesInRadius >= 1 then
				return BOT_ACTION_DESIRE_HIGH, nil, "none"
			end
		end
	end
	if Fu.IsRetreating(bot) and not Fu.IsRealInvisible(bot) and bot:WasRecentlyDamagedByAnyHero(3.0) then
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.IsChasingTarget(enemyHero, bot)
				and Fu.IsInRange(minion, enemyHero, radius)
				and not Fu.IsDisabled(enemyHero)
			then
				return BOT_ACTION_DESIRE_HIGH, nil, "none"
			end
		end
	end
	for _, allyHero in pairs(nearbyAllies) do
		if Fu.IsValidHero(allyHero) and Fu.IsRetreating(allyHero) and not allyHero:IsIllusion() then
			local enemiesNearAlly = allyHero:GetNearbyHeroes(1600, true, BOT_MODE_NONE)
			if
				Fu.IsValidHero(enemiesNearAlly[1])
				and Fu.CanCastOnNonMagicImmune(enemiesNearAlly[1])
				and Fu.IsInRange(minion, enemiesNearAlly[1], radius)
				and Fu.IsChasingTarget(enemiesNearAlly[1], allyHero)
				and not Fu.IsDisabled(enemiesNearAlly[1])
			then
				return BOT_ACTION_DESIRE_HIGH, nil, "none"
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil, ""
end
X.ConsiderSpellUsage["big_thunder_lizard_frenzy"] = function(minion, ability)
	local castRange = ability:GetCastRange()
	local bestAlly = nil
	local bestAttackPower = 0
	for _, allyHero in pairs(nearbyAllies) do
		if Fu.IsValidHero(allyHero) and not allyHero:IsIllusion() and Fu.IsInRange(minion, allyHero, castRange) then
			if
				Fu.IsGoingOnSomeone(allyHero)
				or Fu.IsDoingRoshan(allyHero) and Fu.IsRoshan(allyHero:GetAttackTarget()) and Fu.IsAttacking(allyHero) and Fu.GetHP(
					allyHero:GetAttackTarget()
				) > 0.4
				or Fu.IsDoingTormentor(allyHero)
					and Fu.IsTormentor(allyHero:GetAttackTarget())
					and Fu.IsAttacking(allyHero)
					and Fu.GetHP(allyHero:GetAttackTarget()) > 0.4
			then
				local attackPower = allyHero:GetAttackDamage() * allyHero:GetAttackSpeed()
				if attackPower > bestAttackPower then
					bestAlly = allyHero
					bestAttackPower = attackPower
				end
			end
		end
	end
	if bestAlly ~= nil then
		return BOT_ACTION_DESIRE_HIGH, bestAlly, "unit"
	end
	return BOT_ACTION_DESIRE_NONE, nil, ""
end
X.ConsiderSpellUsage["ice_shaman_incendiary_bomb"] = function(minion, ability)
	local castRange = ability:GetCastRange()
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.CanCastOnTargetAdvanced(botTarget)
			and Fu.IsInRange(minion, botTarget, castRange)
			and Fu.GetHP(botTarget) > 0.4
			and not Fu.IsDisabled(botTarget)
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget, "unit"
		end
	end
	if Fu.IsPushing(bot) then
		if
			Fu.IsValidBuilding(botTarget)
			and Fu.IsInRange(minion, botTarget, 700)
			and Fu.GetHP(botTarget) > 0.35
			and Fu.CanBeAttacked(botTarget)
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget, "unit"
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil, ""
end
X.ConsiderSpellUsage["black_dragon_fireball"] = function(minion, ability)
	local castRange = ability:GetCastRange()
	local radius = ability:GetSpecialValueInt("radius")
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(minion, botTarget, castRange)
			and not botTarget:HasModifier("modifier_abaddon_borrowed_time")
			and not botTarget:HasModifier("modifier_dazzle_shallow_grave")
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			local aoeLocation = minion:FindAoELocation(true, true, botTarget:GetLocation(), 0, radius, 0, 0)
			if aoeLocation.count >= 1 then
				return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc, "point"
			end
		end
	end
	local aoeLocation = minion:FindAoELocation(true, true, minion:GetLocation(), castRange, radius, 0, 0)
	local enemiesInRadius = Fu.GetEnemiesNearLoc(aoeLocation.targetloc, radius)
	if #enemiesInRadius >= 2 then
		return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc, "point"
	end
	return BOT_ACTION_DESIRE_NONE, nil, ""
end
X.ConsiderSpellUsage["warpine_raider_seed_shot"] = function(minion, ability)
	local castRange = ability:GetCastRange()
	local damage = ability:GetSpecialValueInt("damage")
	local bounceRange = ability:GetSpecialValueInt("bounce_range")
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.IsInRange(minion, enemyHero, castRange)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and Fu.CanCastOnTargetAdvanced(enemyHero)
			and Fu.CanKillTarget(enemyHero, damage, DAMAGE_TYPE_MAGICAL)
			and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
			and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
			and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
			and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
			and not enemyHero:HasModifier("modifier_templar_assassin_refraction_absorb")
		then
			return BOT_ACTION_DESIRE_HIGH, enemyHero, "unit"
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.CanCastOnTargetAdvanced(botTarget)
			and Fu.IsInRange(minion, botTarget, castRange)
			and Fu.IsChasingTarget(bot, botTarget)
			and not botTarget:HasModifier("modifier_abaddon_borrowed_time")
			and not botTarget:HasModifier("modifier_dazzle_shallow_grave")
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			local aoeLocation = minion:FindAoELocation(true, true, botTarget:GetLocation(), 0, bounceRange, 0, 0)
			if aoeLocation.count >= 2 then
				return BOT_ACTION_DESIRE_HIGH, botTarget, "unit"
			end
			aoeLocation = minion:FindAoELocation(true, false, botTarget:GetLocation(), 0, bounceRange, 0, 0)
			if aoeLocation.count >= 2 then
				return BOT_ACTION_DESIRE_HIGH, botTarget, "unit"
			end
		end
	end
	if Fu.IsRetreating(bot) and not Fu.IsRealInvisible(bot) and bot:WasRecentlyDamagedByAnyHero(3.0) then
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
				and Fu.IsChasingTarget(enemyHero, bot)
				and Fu.IsInRange(minion, enemyHero, castRange)
				and not Fu.IsDisabled(enemyHero)
			then
				return BOT_ACTION_DESIRE_HIGH, enemyHero, "unit"
			end
		end
	end
	for _, allyHero in pairs(nearbyAllies) do
		if Fu.IsValidHero(allyHero) and Fu.IsRetreating(allyHero) and not allyHero:IsIllusion() then
			local enemiesNearAlly = allyHero:GetNearbyHeroes(1600, true, BOT_MODE_NONE)
			if
				Fu.IsValidHero(enemiesNearAlly[1])
				and Fu.CanCastOnNonMagicImmune(enemiesNearAlly[1])
				and Fu.CanCastOnTargetAdvanced(enemiesNearAlly[1])
				and Fu.IsInRange(minion, enemiesNearAlly[1], castRange)
				and Fu.IsChasingTarget(enemiesNearAlly[1], allyHero)
				and not Fu.IsDisabled(enemiesNearAlly[1])
			then
				return BOT_ACTION_DESIRE_HIGH, enemiesNearAlly[1], "unit"
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil, ""
end
X.ConsiderSpellUsage["fel_beast_haunt"] = function(minion, ability)
	local castRange = ability:GetCastRange()
	if Fu.IsGoingOnSomeone(bot) and Fu.IsInRange(bot, minion, 1600) then
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.CanCastOnTargetAdvanced(botTarget)
			and Fu.IsInRange(minion, botTarget, castRange)
			and not Fu.IsDisabled(botTarget)
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
			and not botTarget:HasModifier("modifier_skeleton_king_reincarnation_scepter_active")
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget, "unit"
		end
	end
	if Fu.IsRetreating(bot) and Fu.IsInRange(bot, minion, 1600) then
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.IsInRange(minion, enemyHero, castRange)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
				and Fu.IsChasingTarget(enemyHero, bot)
				and not Fu.IsDisabled(enemyHero)
				and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
				and not enemyHero:HasModifier("modifier_skeleton_king_reincarnation_scepter_active")
			then
				return BOT_ACTION_DESIRE_HIGH, enemyHero, "unit"
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil, ""
end
X.ConsiderSpellUsage["harpy_scout_take_off"] = function(minion, ability)
	if Fu.IsStuck(minion) then
		if ability:GetToggleState() == false then
			return BOT_ACTION_DESIRE_HIGH, nil, "none"
		else
			return BOT_ACTION_DESIRE_NONE, nil, "none"
		end
	end
	if ability:GetToggleState() == true then
		return BOT_ACTION_DESIRE_HIGH, nil, "none"
	end
	return BOT_ACTION_DESIRE_NONE, nil, ""
end
X.ConsiderSpellUsage["harpy_storm_chain_lightning"] = function(minion, ability)
	local castRange = ability:GetCastRange()
	local damage = ability:GetSpecialValueInt("initial_damage")
	local jumpRange = ability:GetSpecialValueInt("jump_range")
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.IsInRange(minion, enemyHero, castRange)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and Fu.CanCastOnTargetAdvanced(enemyHero)
			and Fu.CanKillTarget(enemyHero, damage, DAMAGE_TYPE_MAGICAL)
			and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
			and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
			and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
			and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
			and not enemyHero:HasModifier("modifier_templar_assassin_refraction_absorb")
		then
			return BOT_ACTION_DESIRE_HIGH, enemyHero, "unit"
		end
	end
	if Fu.IsGoingOnSomeone(bot) and Fu.IsInRange(bot, minion, 1600) then
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.CanCastOnTargetAdvanced(botTarget)
			and Fu.IsInRange(minion, botTarget, castRange)
			and not Fu.IsDisabled(botTarget)
			and not botTarget:HasModifier("modifier_abaddon_borrowed_time")
			and not botTarget:HasModifier("modifier_dazzle_shallow_grave")
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
			and not botTarget:HasModifier("modifier_templar_assassin_refraction_absorb")
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget, "unit"
		end
	end
	if Fu.IsRetreating(bot) and Fu.IsInRange(bot, minion, 1600) then
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.IsInRange(minion, enemyHero, castRange)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
				and Fu.IsChasingTarget(enemyHero, bot)
				and not Fu.IsDisabled(enemyHero)
			then
				return BOT_ACTION_DESIRE_HIGH, enemyHero, "unit"
			end
		end
	end
	if Fu.IsFarming(bot) and Fu.IsInRange(bot, minion, 1600) then
		local nearbyCreeps = bot:GetNearbyCreeps(1600, true)
		if
			nearbyCreeps ~= nil
			and (#nearbyCreeps >= 3 or #nearbyCreeps >= 2 and nearbyCreeps[1]:IsAncientCreep())
			and Fu.IsAttacking(bot)
		then
			for _, creep in pairs(nearbyCreeps) do
				if Fu.IsValid(creep) and Fu.CanBeAttacked(creep) then
					local unitCount = Fu.GetNearbyAroundLocationUnitCount(true, false, jumpRange, creep:GetLocation())
					if unitCount >= 2 then
						return BOT_ACTION_DESIRE_HIGH, creep, "unit"
					end
				end
			end
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if
			Fu.IsRoshan(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(minion, botTarget, castRange)
			and Fu.IsAttacking(bot)
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget, "unit"
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(minion, botTarget, castRange) and Fu.IsAttacking(bot) then
			return BOT_ACTION_DESIRE_HIGH, botTarget, "unit"
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil, ""
end
X.ConsiderSpellUsage["satyr_soulstealer_mana_burn"] = function(minion, ability)
	local castRange = ability:GetCastRange()
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.IsInRange(minion, enemyHero, castRange + 300)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and Fu.CanCastOnTargetAdvanced(enemyHero)
			and Fu.GetMP(enemyHero) > 0.5
			and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			return BOT_ACTION_DESIRE_HIGH, enemyHero, "unit"
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil, ""
end
X.ConsiderSpellUsage["satyr_trickster_purge"] = function(minion, ability)
	local castRange = ability:GetCastRange()
	for _, allyHero in pairs(nearbyAllies) do
		if
			Fu.IsValidHero(allyHero)
			and Fu.IsInRange(minion, allyHero, castRange + 300)
			and not allyHero:IsIllusion()
			and Fu.IsDisabled(allyHero)
		then
			return BOT_ACTION_DESIRE_HIGH, allyHero, "unit"
		end
	end
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.IsInRange(minion, enemyHero, castRange + 300)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and Fu.CanCastOnTargetAdvanced(enemyHero)
		then
			if
				enemyHero:HasModifier("modifier_flask_healing")
				or enemyHero:HasModifier("modifier_clarity_potion")
				or enemyHero:HasModifier("modifier_item_pavise_shield")
				or enemyHero:HasModifier("modifier_item_solar_crest_armor_addition")
				or enemyHero:HasModifier("modifier_disperser_movespeed_buff")
			then
				return BOT_ACTION_DESIRE_HIGH, enemyHero, "unit"
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil, ""
end
X.ConsiderSpellUsage["satyr_hellcaller_shockwave"] = function(minion, ability)
	local castRange = ability:GetCastRange()
	local castPoint = ability:GetCastPoint()
	local projectileSpeed = ability:GetSpecialValueInt("speed")
	local damage = ability:GetSpecialValueInt("#AbilityDamage")
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.IsInRange(minion, enemyHero, castRange)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and Fu.CanKillTarget(enemyHero, damage, DAMAGE_TYPE_MAGICAL)
			and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
			and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
			and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
			and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
			and not enemyHero:HasModifier("modifier_templar_assassin_refraction_absorb")
		then
			local delay = GetUnitToUnitDistance(minion, enemyHero) / projectileSpeed + castPoint
			return BOT_ACTION_DESIRE_HIGH, Fu.GetCorrectLoc(minion, delay), "point"
		end
	end
	if Fu.IsGoingOnSomeone(bot) and Fu.IsInRange(bot, minion, 1300) then
		local aoeLocation = minion:FindAoELocation(true, true, minion:GetLocation(), castRange, 200, castPoint, 0)
		local enemiesInRadius = Fu.GetEnemiesNearLoc(aoeLocation.targetloc, 200)
		if #enemiesInRadius >= 1 then
			return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc, "point"
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil, ""
end
X.ConsiderSpellUsage["giant_wolf_intimidate"] = function(minion, ability)
	local radius = ability:GetSpecialValueInt("radius")
	if Fu.IsGoingOnSomeone(bot) then
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.IsInRange(minion, enemyHero, radius)
				and Fu.CanBeAttacked(enemyHero)
				and not Fu.IsChasingTarget(bot, enemyHero)
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
				and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
				and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
			then
				return BOT_ACTION_DESIRE_HIGH, nil, "none"
			end
		end
	end
	local enemiesInRadius = Fu.GetEnemiesNearLoc(minion:GetLocation(), radius)
	if #enemiesInRadius >= 2 then
		return BOT_ACTION_DESIRE_HIGH, nil, "none"
	end
	return BOT_ACTION_DESIRE_NONE, nil, ""
end
X.ConsiderSpellUsage["centaur_khan_war_stomp"] = function(minion, ability)
	local radius = ability:GetSpecialValueInt("radius")
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(minion, botTarget, radius)
			and not Fu.IsDisabled(botTarget)
			and not botTarget:HasModifier("modifier_abaddon_borrowed_time")
			and not botTarget:HasModifier("modifier_dazzle_shallow_grave")
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			return BOT_ACTION_DESIRE_HIGH, nil, "none"
		end
	end
	if Fu.IsRetreating(bot) and not Fu.IsRealInvisible(bot) and bot:WasRecentlyDamagedByAnyHero(3.0) then
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.IsChasingTarget(enemyHero, bot)
				and Fu.IsInRange(minion, enemyHero, radius)
				and not Fu.IsDisabled(enemyHero)
			then
				return BOT_ACTION_DESIRE_HIGH, nil, "none"
			end
		end
	end
	for _, allyHero in pairs(nearbyAllies) do
		if
			Fu.IsValidHero(allyHero)
			and Fu.IsRetreating(allyHero)
			and not Fu.IsRealInvisible(allyHero)
			and not allyHero:IsIllusion()
		then
			local enemiesNearAlly = allyHero:GetNearbyHeroes(1600, true, BOT_MODE_NONE)
			if
				Fu.IsValidHero(enemiesNearAlly[1])
				and Fu.CanCastOnNonMagicImmune(enemiesNearAlly[1])
				and Fu.IsInRange(minion, enemiesNearAlly[1], radius)
				and Fu.IsChasingTarget(enemiesNearAlly[1], allyHero)
				and not Fu.IsDisabled(enemiesNearAlly[1])
			then
				return BOT_ACTION_DESIRE_HIGH, nil, "none"
			end
		end
	end
	local enemiesInRadius = Fu.GetEnemiesNearLoc(minion:GetLocation(), radius)
	if #enemiesInRadius >= 2 then
		return BOT_ACTION_DESIRE_HIGH, nil, "none"
	end
	return BOT_ACTION_DESIRE_NONE, nil, ""
end
X.ConsiderSpellUsage["forest_troll_high_priest_heal"] = function(minion, ability)
	local castRange = ability:GetSpecialValueInt("AbilityCastRange")
	local bot = GetBot()
	local nearbyAllies = minion:GetNearbyHeroes(castRange, false, BOT_MODE_NONE) or {}
	for _, allyHero in pairs(nearbyAllies) do
		if
			Fu.IsValidHero(allyHero)
			and Fu.CanBeAttacked(allyHero)
			and Fu.IsInRange(minion, allyHero, castRange)
			and not allyHero:IsIllusion()
			and not allyHero:HasModifier("modifier_abaddon_borrowed_time")
			and Fu.GetHP(allyHero) < 0.5
		then
			return BOT_ACTION_DESIRE_HIGH, allyHero, "unit"
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
X.ConsiderSpellUsage["chen_martyrdom"] = function(minion, ability)
	local bot = GetBot()
	local minionHp = Fu.GetHP(minion)
	local nearbyAllies = minion:GetNearbyHeroes(900, false, BOT_MODE_NONE) or {}
	if minionHp < 0.2 and #nearbyAllies >= 1 then
		for _, allyHero in pairs(nearbyAllies) do
			if Fu.IsValidHero(allyHero) and Fu.GetHP(allyHero) < 0.6 then
				return BOT_ACTION_DESIRE_HIGH, nil, "none"
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
X.ConsiderSpellUsage["necronomicon_archer_purge"] = function(minion, ability)
	local castRange = ability:GetCastRange()
	local nearbyEnemies = minion:GetNearbyHeroes(castRange, true, BOT_MODE_NONE) or {}
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanBeAttacked(enemyHero)
			and Fu.IsInRange(minion, enemyHero, castRange)
			and not enemyHero:IsMagicImmune()
			and (
				enemyHero:GetCurrentMovementSpeed() > 400
				or enemyHero:HasModifier("modifier_ghost_state")
				or enemyHero:HasModifier("modifier_item_ghost")
			)
		then
			return BOT_ACTION_DESIRE_HIGH, enemyHero, "unit"
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
X.ConsiderSpellUsage["spawnlord_master_freeze"] = function(minion, ability)
	local castRange = ability:GetCastRange()
	local nearbyEnemies = minion:GetNearbyHeroes(castRange, true, BOT_MODE_NONE) or {}
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanBeAttacked(enemyHero)
			and Fu.IsInRange(minion, enemyHero, castRange)
			and not enemyHero:IsMagicImmune()
			and not Fu.IsDisabled(enemyHero)
		then
			return BOT_ACTION_DESIRE_HIGH, enemyHero, "unit"
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
X.ConsiderSpellUsage["spawnlord_master_stomp"] = function(minion, ability)
	local radius = ability:GetSpecialValueInt("radius")
	local nearbyEnemies = minion:GetNearbyHeroes(radius, true, BOT_MODE_NONE) or {}
	if #nearbyEnemies >= 2 then
		return BOT_ACTION_DESIRE_HIGH, nil, "none"
	end
	for _, enemyHero in pairs(nearbyEnemies) do
		if Fu.IsValidHero(enemyHero) and Fu.IsInRange(minion, enemyHero, radius) and enemyHero:IsChanneling() then
			return BOT_ACTION_DESIRE_HIGH, nil, "none"
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
return X
