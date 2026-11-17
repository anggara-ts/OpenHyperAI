-- How Rubick plays after stealing a spell from Abaddon.
local bot = GetBot()
local X = {}
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local botTarget
local mistCoilAbility
local aphoticShieldAbility
function X.ConsiderStolenSpell(ability)
	bot = GetBot()
	if Fu.CanNotUseAbility(bot) then
		return
	end
	botTarget = Fu.GetProperTarget(bot)
	local abilityName = ability:GetName()
	if abilityName == "abaddon_aphotic_shield" then
		aphoticShieldAbility = ability
		AphoticShieldDesire, AphoticShieldTarget = X.ConsiderAphoticShield()
		if AphoticShieldDesire > 0 then
			bot:Action_UseAbilityOnEntity(aphoticShieldAbility, AphoticShieldTarget)
			return
		end
	end
	if abilityName == "abaddon_death_coil" then
		mistCoilAbility = ability
		MistCoilDesire, MistCoilTarget = X.ConsiderMistCoil()
		if MistCoilDesire > 0 then
			bot:Action_UseAbilityOnEntity(mistCoilAbility, MistCoilTarget)
			return
		end
	end
end
function X.ConsiderMistCoil()
	if not mistCoilAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castRange = Fu.GetProperCastRange(false, bot, mistCoilAbility:GetCastRange())
	local damage = mistCoilAbility:GetSpecialValueInt("target_damage")
	local damageType = DAMAGE_TYPE_MAGICAL
	local nearbyEnemies = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanCastOnMagicImmune(enemyHero)
			and Fu.CanKillTarget(enemyHero, damage, damageType)
			and not Fu.IsSuspiciousIllusion(enemyHero)
			and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
			and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
			and not enemyHero:HasModifier("modifier_templar_assassin_refraction_absorb")
		then
			return BOT_ACTION_DESIRE_HIGH, enemyHero
		end
	end
	local alliesInCastRange = Fu.GetNearbyHeroes(bot, castRange, false, BOT_MODE_NONE)
	for _, allyHero in pairs(alliesInCastRange) do
		if
			Fu.IsValidHero(allyHero)
			and not allyHero:IsInvulnerable()
			and not allyHero:IsIllusion()
			and (
				allyHero:HasModifier("modifier_faceless_void_chronosphere_freeze")
				or allyHero:HasModifier("modifier_enigma_black_hole_pull")
			)
		then
			return BOT_ACTION_DESIRE_HIGH, allyHero
		end
		if
			Fu.IsValidHero(allyHero)
			and Fu.IsInRange(bot, allyHero, castRange)
			and not allyHero:HasModifier("modifier_legion_commander_press_the_attack")
			and not allyHero:IsMagicImmune()
			and not allyHero:IsInvulnerable()
			and not allyHero:IsIllusion()
			and allyHero:CanBeSeen()
		then
			if Fu.IsRetreating(allyHero) and Fu.GetHP(allyHero) < 0.6 then
				return BOT_ACTION_DESIRE_HIGH, allyHero
			end
			if Fu.IsGoingOnSomeone(allyHero) then
				local allyTarget = allyHero:GetAttackTarget()
				if
					Fu.IsValidHero(allyTarget)
					and allyHero:IsFacingLocation(allyTarget:GetLocation(), 30)
					and Fu.IsInRange(allyHero, allyTarget, 300)
					and Fu.GetHP(allyHero) < 0.8
					and Fu.GetHP(bot) > 0.2
				then
					return BOT_ACTION_DESIRE_HIGH, allyHero
				end
			end
		end
	end
	if Fu.IsRetreating(bot) and Fu.IsInRange(bot, botTarget, castRange) then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, castRange + 200, false, BOT_MODE_NONE)
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
		if
			nearbyAllies ~= nil
			and nearbyEnemies ~= nil
			and (#nearbyAllies == 0 and #nearbyEnemies >= 1 or #nearbyAllies >= 1 and Fu.GetHP(bot) < 0.25 and bot:WasRecentlyDamagedByAnyHero(
				1
			) and not bot:HasModifier("modifier_abaddon_borrowed_time"))
			and Fu.IsValidHero(nearbyEnemies[1])
			and not Fu.IsSuspiciousIllusion(nearbyEnemies[1])
			and not Fu.IsDisabled(nearbyEnemies[1])
		then
			return BOT_ACTION_DESIRE_HIGH, bot
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if
			Fu.IsRoshan(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, 500)
			and Fu.IsAttacking(bot)
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, 400) and Fu.IsAttacking(bot) then
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function X.ConsiderAphoticShield()
	if not aphoticShieldAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castRange = Fu.GetProperCastRange(false, bot, aphoticShieldAbility:GetCastRange())
	local alliesInCastRange = Fu.GetNearbyHeroes(bot, castRange, false, BOT_MODE_NONE)
	for _, allyHero in pairs(alliesInCastRange) do
		if
			Fu.IsValidHero(allyHero)
			and not allyHero:IsInvulnerable()
			and not allyHero:IsIllusion()
			and (
				allyHero:HasModifier("modifier_faceless_void_chronosphere_freeze")
				or allyHero:HasModifier("modifier_enigma_black_hole_pull")
				or allyHero:HasModifier("modifier_legion_commander_duel")
			)
		then
			return BOT_ACTION_DESIRE_HIGH, allyHero
		end
		if
			Fu.IsValidHero(allyHero)
			and Fu.IsDisabled(allyHero)
			and not allyHero:IsMagicImmune()
			and not allyHero:IsInvulnerable()
			and not allyHero:IsIllusion()
		then
			return BOT_ACTION_DESIRE_HIGH, allyHero
		end
		if
			Fu.IsValidHero(allyHero)
			and not allyHero:HasModifier("modifier_abaddon_aphotic_shield")
			and not allyHero:HasModifier("modifier_item_solar_crest_armor_addition")
			and not allyHero:IsMagicImmune()
			and not allyHero:IsInvulnerable()
			and not allyHero:IsIllusion()
			and Fu.IsNotSelf(bot, allyHero)
		then
			local enemiesNearAlly = Fu.GetNearbyHeroes(allyHero, 800, true, BOT_MODE_NONE)
			if
				Fu.IsRetreating(allyHero)
				and allyHero:WasRecentlyDamagedByAnyHero(1.6)
				and not allyHero:IsIllusion()
			then
				if
					enemiesNearAlly ~= nil
					and #enemiesNearAlly >= 1
					and Fu.IsValidHero(enemiesNearAlly[1])
					and Fu.IsInRange(allyHero, enemiesNearAlly[1], 400)
					and Fu.IsInRange(bot, enemiesNearAlly[1], castRange)
					and Fu.IsRunning(allyHero)
					and enemiesNearAlly[1]:IsFacingLocation(allyHero:GetLocation(), 30)
					and not Fu.IsDisabled(enemiesNearAlly[1])
					and not Fu.IsTaunted(enemiesNearAlly[1])
					and not Fu.IsSuspiciousIllusion(enemiesNearAlly[1])
					and not enemiesNearAlly[1]:HasModifier("modifier_legion_commander_duel")
					and not enemiesNearAlly[1]:HasModifier("modifier_enigma_black_hole_pull")
					and not enemiesNearAlly[1]:HasModifier("modifier_faceless_void_chronosphere_freeze")
					and not enemiesNearAlly[1]:HasModifier("modifier_necrolyte_reapers_scythe")
				then
					return BOT_ACTION_DESIRE_HIGH, allyHero
				end
			end
			if Fu.IsGoingOnSomeone(allyHero) then
				local allyTarget = allyHero:GetAttackTarget()
				if
					Fu.IsValidHero(allyTarget)
					and Fu.IsInRange(allyHero, allyTarget, allyHero:GetAttackRange())
					and not Fu.IsSuspiciousIllusion(allyTarget)
					and not allyTarget:HasModifier("modifier_faceless_void_chronosphere_freeze")
					and not allyTarget:HasModifier("modifier_enigma_black_hole_pull")
					and not allyTarget:HasModifier("modifier_necrolyte_reapers_scythe")
				then
					local alliesNearAlly = Fu.GetNearbyHeroes(allyHero, 800, false, BOT_MODE_NONE)
					local targetAllies = Fu.GetNearbyHeroes(allyTarget, 800, false, BOT_MODE_NONE)
					if alliesNearAlly ~= nil and targetAllies ~= nil and #alliesNearAlly >= #targetAllies then
						return BOT_ACTION_DESIRE_HIGH, allyHero
					end
				end
			end
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, 1000, false, BOT_MODE_NONE)
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, 1000, true, BOT_MODE_NONE)
		if
			Fu.IsValidTarget(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not Fu.IsDisabled(botTarget)
			and not botTarget:HasModifier("modifier_faceless_void_chronosphere_freeze")
			and not botTarget:HasModifier("modifier_enigma_black_hole_pull")
		then
			local targetAllies = Fu.GetNearbyHeroes(botTarget, 800, false, BOT_MODE_NONE)
			if nearbyAllies ~= nil and targetAllies ~= nil and #nearbyAllies >= #targetAllies then
				if
					Fu.IsValidHero(nearbyAllies[1])
					and Fu.IsInRange(bot, nearbyAllies[1], castRange)
					and Fu.IsCore(nearbyAllies[1])
					and not nearbyAllies[1]:HasModifier("modifier_abaddon_aphotic_shield")
					and not nearbyAllies[1]:IsMagicImmune()
					and not nearbyAllies[1]:IsInvulnerable()
					and not nearbyAllies[1]:IsIllusion()
				then
					return BOT_ACTION_DESIRE_HIGH, nearbyAllies[1]
				end
				if
					not bot:HasModifier("modifier_abaddon_aphotic_shield")
					and not bot:HasModifier("modifier_abaddon_borrowed_time")
				then
					return BOT_ACTION_DESIRE_MODERATE, bot
				end
			end
		end
		if
			nearbyAllies ~= nil
			and nearbyEnemies ~= nil
			and #nearbyAllies == 0
			and #nearbyEnemies >= 1
			and Fu.IsValidHero(nearbyEnemies[1])
			and Fu.IsInRange(bot, nearbyEnemies[1], 500)
			and not Fu.IsSuspiciousIllusion(nearbyEnemies[1])
			and not Fu.IsDisabled(nearbyEnemies[1])
			and not bot:HasModifier("modifier_abaddon_aphotic_shield")
			and not bot:HasModifier("modifier_abaddon_borrowed_time")
		then
			return BOT_ACTION_DESIRE_MODERATE, bot
		end
	end
	if Fu.IsRetreating(bot) then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, 800, false, BOT_MODE_NONE)
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, 800, true, BOT_MODE_NONE)
		if
			nearbyAllies ~= nil
			and nearbyEnemies
			and Fu.IsValidHero(nearbyEnemies[1])
			and Fu.CanCastOnNonMagicImmune(nearbyEnemies[1])
			and Fu.IsInRange(bot, nearbyEnemies[1], castRange)
			and Fu.IsRunning(nearbyEnemies[1])
			and nearbyEnemies[1]:IsFacingLocation(bot:GetLocation(), 30)
			and not Fu.IsSuspiciousIllusion(nearbyEnemies[1])
			and not Fu.IsDisabled(nearbyEnemies[1])
			and not nearbyEnemies[1]:HasModifier("modifier_enigma_black_hole_pull")
			and not nearbyEnemies[1]:HasModifier("modifier_faceless_void_chronosphere_freeze")
			and not nearbyEnemies[1]:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			local targetAllies = Fu.GetNearbyHeroes(nearbyEnemies[1], 800, false, BOT_MODE_NONE)
			if
				targetAllies ~= nil
				and (#targetAllies > #nearbyAllies or Fu.GetHP(bot) < 0.55 and bot:WasRecentlyDamagedByAnyHero(2))
			then
				return BOT_ACTION_DESIRE_HIGH, bot
			end
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if Fu.IsRoshan(botTarget) and Fu.IsInRange(bot, botTarget, 500) and Fu.IsAttacking(bot) then
			local weakestAlly = Fu.GetAttackableWeakestUnit(bot, castRange, true, false)
			if weakestAlly ~= nil and not weakestAlly:HasModifier("modifier_abaddon_aphotic_shield") then
				return BOT_ACTION_DESIRE_HIGH, weakestAlly
			end
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, 400) and Fu.IsAttacking(bot) then
			local weakestAlly = Fu.GetAttackableWeakestUnit(bot, castRange, true, false)
			if weakestAlly ~= nil and not weakestAlly:HasModifier("modifier_abaddon_aphotic_shield") then
				return BOT_ACTION_DESIRE_HIGH, weakestAlly
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
return X
