-- How Rubick plays after stealing a spell from Centaur.
local bot
local X = {}
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local hoofStompAbility
local doubleEdgeAbility
local workHorseAbility
local hitchARideAbility
local stampedeAbility
local botTarget
function X.ConsiderStolenSpell(ability)
	bot = GetBot()
	if Fu.CanNotUseAbility(bot) then
		return
	end
	botTarget = Fu.GetProperTarget(bot)
	local abilityName = ability:GetName()
	if abilityName == "centaur_mount" then
		hitchARideAbility = ability
		HitchARideDesire, HitchARideTarget = X.ConsiderHitchARide()
		if HitchARideDesire > 0 then
			bot:Action_UseAbilityOnEntity(hitchARideAbility, HitchARideTarget)
			return
		end
	end
	if abilityName == "centaur_work_horse" then
		workHorseAbility = ability
		WorkHorseDesire, HitchARideTarget = X.ConsiderWorkHorse()
		if WorkHorseDesire > 0 then
			bot:Action_UseAbility(workHorseAbility)
			return
		end
	end
	if abilityName == "centaur_stampede" then
		stampedeAbility = ability
		StampedeDesire = X.ConsiderStampede()
		if StampedeDesire > 0 then
			bot:Action_UseAbility(stampedeAbility)
			return
		end
	end
	if abilityName == "centaur_hoof_stomp" then
		hoofStompAbility = ability
		HoofStompDesire = X.ConsiderHoofStomp()
		if HoofStompDesire > 0 then
			bot:Action_UseAbility(hoofStompAbility)
			return
		end
	end
	if abilityName == "centaur_double_edge" then
		doubleEdgeAbility = ability
		DoubleEdgeDesire, DoubleEdgeTarget = X.ConsiderDoubleEdge()
		if DoubleEdgeDesire > 0 then
			bot:Action_UseAbilityOnEntity(doubleEdgeAbility, DoubleEdgeTarget)
			return
		end
	end
end
function X.ConsiderHoofStomp()
	if not hoofStompAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
	end
	local radius = hoofStompAbility:GetSpecialValueInt("radius")
	local damage = hoofStompAbility:GetSpecialValueInt("stomp_damage")
	local enemiesInRadius = Fu.GetNearbyHeroes(bot, radius, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(enemiesInRadius) do
		if Fu.IsValidHero(enemyHero) and Fu.CanCastOnNonMagicImmune(enemyHero) and not Fu.IsSuspiciousIllusion(enemyHero) then
			if enemyHero:IsChanneling() or Fu.IsCastingUltimateAbility(enemyHero) then
				return BOT_ACTION_DESIRE_HIGH
			end
			if
				Fu.CanKillTarget(enemyHero, damage, DAMAGE_TYPE_MAGICAL)
				and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
				and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
				and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
				and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
				and not enemyHero:HasModifier("modifier_templar_assassin_refraction_absorb")
			then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, radius - 100)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not Fu.IsDisabled(botTarget)
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			local alliesNearTarget = Fu.GetNearbyHeroes(botTarget, 1200, true, BOT_MODE_NONE)
			local enemiesNearTarget = Fu.GetNearbyHeroes(botTarget, 1200, false, BOT_MODE_NONE)
			if alliesNearTarget ~= nil and enemiesNearTarget ~= nil and #alliesNearTarget >= #enemiesNearTarget then
				if stampedeAbility:IsTrained() and stampedeAbility:IsFullyCastable() then
					if bot:GetMana() - hoofStompAbility:GetManaCost() > stampedeAbility:GetManaCost() then
						return BOT_ACTION_DESIRE_HIGH
					end
				else
					return BOT_ACTION_DESIRE_HIGH
				end
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
			and Fu.CanCastOnNonMagicImmune(nearbyEnemies[1])
			and Fu.IsInRange(bot, nearbyEnemies[1], radius)
			and Fu.IsChasingTarget(nearbyEnemies[1], bot)
			and not Fu.IsSuspiciousIllusion(nearbyEnemies[1])
			and not Fu.IsDisabled(nearbyEnemies[1])
			and not nearbyEnemies[1]:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			local chaserAllies = Fu.GetNearbyHeroes(nearbyEnemies[1], 1200, false, BOT_MODE_NONE)
			if chaserAllies ~= nil and (#chaserAllies > #nearbyAllies or bot:WasRecentlyDamagedByAnyHero(1.5)) then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if
			Fu.IsRoshan(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, radius)
			and Fu.IsAttacking(bot)
			and not Fu.IsDisabled(botTarget)
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
function X.ConsiderDoubleEdge()
	if not doubleEdgeAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local strength = bot:GetAttributeValue(ATTRIBUTE_STRENGTH)
	local castRange = Fu.GetProperCastRange(false, bot, doubleEdgeAbility:GetCastRange())
	local attackRange = bot:GetAttackRange()
	local strengthDamageRatio = doubleEdgeAbility:GetSpecialValueInt("strength_damage") / 100
	local damage = doubleEdgeAbility:GetSpecialValueInt("edge_damage") + strength * strengthDamageRatio
	local enemiesInRange = Fu.GetNearbyHeroes(bot, castRange + attackRange, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(enemiesInRange) do
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
			and bot:GetHealth() > damage * 1.2
		then
			return BOT_ACTION_DESIRE_HIGH, enemyHero
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange * 2)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not botTarget:HasModifier("modifier_abaddon_borrowed_time")
			and not botTarget:HasModifier("modifier_dazzle_shallow_grave")
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
			and not botTarget:HasModifier("modifier_oracle_false_promise_timer")
			and not botTarget:HasModifier("modifier_templar_assassin_refraction_absorb")
			and bot:GetHealth() > damage * 1.5
		then
			local alliesNearTarget = Fu.GetNearbyHeroes(botTarget, 1200, true, BOT_MODE_NONE)
			local enemiesNearTarget = Fu.GetNearbyHeroes(botTarget, 1200, false, BOT_MODE_NONE)
			if alliesNearTarget ~= nil and enemiesNearTarget ~= nil and #alliesNearTarget >= #enemiesNearTarget then
				return BOT_ACTION_DESIRE_HIGH, botTarget
			end
		end
	end
	if Fu.IsPushing(bot) or Fu.IsDefending(bot) then
		local laneCreeps = bot:GetNearbyLaneCreeps(castRange * 2, true)
		if
			laneCreeps ~= nil
			and #laneCreeps >= 3
			and Fu.CanBeAttacked(laneCreeps[1])
			and Fu.IsAttacking(bot)
			and bot:GetHealth() > damage * 1.5
			and (bot:GetHealth() - damage) / bot:GetMaxHealth() > 0.5
			and Fu.GetHP(laneCreeps[1]) > 0.33
		then
			return BOT_ACTION_DESIRE_HIGH, laneCreeps[1]
		end
	end
	if Fu.IsFarming(bot) then
		if
			Fu.IsAttacking(bot)
			and Fu.GetHP(bot) > 0.3
			and bot:GetHealth() > damage * 1.5
			and (bot:GetHealth() - damage) / bot:GetMaxHealth() > 0.3
		then
			local neutralCreeps = bot:GetNearbyNeutralCreeps(castRange * 2)
			if neutralCreeps ~= nil and #neutralCreeps >= 1 and Fu.GetHP(neutralCreeps[1]) > 0.33 then
				return BOT_ACTION_DESIRE_HIGH, neutralCreeps[1]
			end
			local laneCreeps = bot:GetNearbyLaneCreeps(castRange * 2, true)
			if laneCreeps ~= nil and #laneCreeps >= 3 and Fu.CanBeAttacked(laneCreeps[1]) and Fu.GetHP(laneCreeps[1]) > 0.33 then
				return BOT_ACTION_DESIRE_HIGH, laneCreeps[1]
			end
		end
	end
	if Fu.IsLaning(bot) then
		local killableCount = 0
		local killableCreeps = {}
		local laneCreeps = bot:GetNearbyLaneCreeps(castRange * 2, true)
		for _, creep in pairs(laneCreeps) do
			if Fu.IsValid(creep) and creep:GetHealth() <= damage then
				killableCount = killableCount + 1
				table.insert(killableCreeps, creep)
			end
		end
		if
			killableCount >= 2
			and Fu.CanBeAttacked(killableCreeps[1])
			and Fu.GetHP(bot) > 0.3
			and bot:GetHealth() > damage * 1.5
			and (bot:GetHealth() - damage) / bot:GetMaxHealth() > 0.3
		then
			return BOT_ACTION_DESIRE_HIGH, killableCreeps[1]
		end
		local nearbyEnemies = Fu.GetEnemiesNearLoc(bot:GetLocation(), castRange + 75)
		if nearbyEnemies ~= nil and #nearbyEnemies >= 1 and Fu.IsValidTarget(nearbyEnemies[1]) and (bot:GetHealth() - damage) / bot:GetMaxHealth() > 0.65 then
			return BOT_ACTION_DESIRE_HIGH, nearbyEnemies[1]
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if
			Fu.IsRoshan(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange * 2)
			and Fu.IsAttacking(bot)
			and bot:GetHealth() > damage * 1.5
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if
			Fu.IsTormentor(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange * 2)
			and Fu.IsAttacking(bot)
			and bot:GetHealth() > damage * 1.5
			and (bot:GetHealth() - damage) / bot:GetMaxHealth() > 0.45
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.ConsiderStampede()
	if
		not stampedeAbility:IsFullyCastable()
		or bot:HasModifier("modifier_centaur_cart")
		or bot:HasModifier("modifier_centaur_stampede")
	then
		return BOT_ACTION_DESIRE_NONE
	end
	if Fu.IsInTeamFight(bot, 1200) then
		local teamFightLocation = Fu.GetTeamFightLocation(bot)
		local nearbyEnemies = Fu.GetEnemiesNearLoc(bot:GetLocation(), 1200)
		if nearbyEnemies ~= nil and #nearbyEnemies >= 2 and teamFightLocation ~= nil then
			if Fu.GetLocationToLocationDistance(bot:GetLocation(), teamFightLocation) < 600 then
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
			and Fu.IsInRange(bot, nearbyEnemies[1], 600)
			and Fu.IsChasingTarget(nearbyEnemies[1], bot)
			and not Fu.IsSuspiciousIllusion(nearbyEnemies[1])
			and not Fu.IsDisabled(nearbyEnemies[1])
		then
			local chaserAllies = Fu.GetNearbyHeroes(nearbyEnemies[1], 1200, false, BOT_MODE_NONE)
			if chaserAllies ~= nil and #chaserAllies > #nearbyAllies and #chaserAllies >= 2 and #nearbyAllies <= 1 and Fu.GetHP(bot) < 0.5 then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderWorkHorse()
	if not workHorseAbility:IsTrained() or not workHorseAbility:IsFullyCastable() or bot:HasModifier("modifier_centaur_stampede") then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	if Fu.IsInTeamFight(bot, 1200) then
		local teamFightLocation = Fu.GetTeamFightLocation(bot)
		local nearbyEnemies = Fu.GetEnemiesNearLoc(bot:GetLocation(), 1200)
		if nearbyEnemies ~= nil and #nearbyEnemies >= 2 and teamFightLocation ~= nil then
			if Fu.GetLocationToLocationDistance(bot:GetLocation(), teamFightLocation) < 600 then
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
			and Fu.IsInRange(bot, nearbyEnemies[1], 600)
			and Fu.IsChasingTarget(nearbyEnemies[1], bot)
			and not Fu.IsSuspiciousIllusion(nearbyEnemies[1])
			and not Fu.IsDisabled(nearbyEnemies[1])
		then
			local chaserAllies = Fu.GetNearbyHeroes(nearbyEnemies[1], 1200, false, BOT_MODE_NONE)
			if chaserAllies ~= nil and #chaserAllies > #nearbyAllies and #chaserAllies >= 2 and #nearbyAllies <= 1 and Fu.GetHP(bot) < 0.5 then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function X.ConsiderHitchARide()
	if hitchARideAbility:IsHidden() or not hitchARideAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castRange = Fu.GetProperCastRange(false, bot, hitchARideAbility:GetCastRange())
	if Fu.IsGoingOnSomeone(bot) or Fu.IsInTeamFight(bot, 1200) then
		local alliesInRange = Fu.GetAlliesNearLoc(bot:GetLocation(), castRange)
		for _, allyHero in pairs(alliesInRange) do
			if
				Fu.IsValidHero(allyHero)
				and allyHero:WasRecentlyDamagedByAnyHero(1.1)
				and Fu.GetHP(allyHero) < 0.5
				and not allyHero:IsIllusion()
				and not allyHero:HasModifier("modifier_arc_warden_tempest_double")
			then
				return BOT_ACTION_DESIRE_HIGH, allyHero
			end
		end
	end
	if Fu.IsRetreating(bot) then
		local alliesInRange = Fu.GetAlliesNearLoc(bot:GetLocation(), castRange)
		for _, allyHero in pairs(alliesInRange) do
			if
				Fu.IsValidHero(allyHero)
				and Fu.IsRetreating(allyHero)
				and allyHero:WasRecentlyDamagedByAnyHero(1.1)
				and not allyHero:IsIllusion()
				and not allyHero:HasModifier("modifier_arc_warden_tempest_double")
			then
				return BOT_ACTION_DESIRE_HIGH, allyHero
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
return X
