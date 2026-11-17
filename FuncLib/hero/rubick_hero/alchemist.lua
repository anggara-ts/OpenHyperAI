-- How Rubick plays after stealing a spell from Alchemist.
local bot
local X = {}
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local botTarget
local acidSprayAbility
local unstableConcoctionAbility
local unstableConcoctionThrowAbility
local chemicalRageAbility
local berserkPotionAbility
local minThrowDelay = 2
local fullBrewDelay = 4.25
local concoctionStartTime = 0
local lastEngageLogTime = -999
function X.ConsiderStolenSpell(ability)
	bot = GetBot()
	if Fu.CanNotUseAbility(bot) then
		return
	end
	botTarget = Fu.GetProperTarget(bot)
	local abilityName = ability:GetName()
	if abilityName == "alchemist_chemical_rage" then
		chemicalRageAbility = ability
		ChemicalRageDesire = X.ConsiderChemicalRage()
		if ChemicalRageDesire > 0 then
			bot:Action_UseAbility(chemicalRageAbility)
			return
		end
	end
	if abilityName == "alchemist_unstable_concoction_throw" then
		unstableConcoctionThrowAbility = ability
		UnstableConcoctionThrowDesire, UnstableConcoctionThrowTarget = X.ConsiderUnstableConcoctionThrow()
		if UnstableConcoctionThrowDesire > 0 then
			bot:Action_UseAbilityOnEntity(unstableConcoctionThrowAbility, UnstableConcoctionThrowTarget)
			return
		end
	end
	if abilityName == "alchemist_unstable_concoction" then
		unstableConcoctionAbility = ability
		UnstableConcoctionDesire = X.ConsiderUnstableConcoction()
		if UnstableConcoctionDesire > 0 then
			bot:Action_UseAbility(unstableConcoctionAbility)
			concoctionStartTime = DotaTime()
			return
		end
	end
	if abilityName == "alchemist_acid_spray" then
		acidSprayAbility = ability
		AcidSprayDesire, AcidSprayLocation = X.ConsiderAcidSpray()
		if AcidSprayDesire > 0 then
			Fu.SetQueuePtToINT(bot, false)
			bot:Action_UseAbilityOnLocation(acidSprayAbility, AcidSprayLocation)
			return
		end
	end
	if abilityName == "alchemist_berserk_potion" then
		berserkPotionAbility = ability
		BerserkPotionDesire, BerserkPotionTarget = X.ConsiderBerserkPotion()
		if BerserkPotionDesire > 0 then
			bot:Action_UseAbilityOnEntity(berserkPotionAbility, BerserkPotionTarget)
			return
		end
	end
end
function X.ConsiderAcidSpray()
	if not acidSprayAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local castRange = Fu.GetProperCastRange(false, bot, acidSprayAbility:GetCastRange())
	local castPoint = acidSprayAbility:GetCastPoint()
	local radius = acidSprayAbility:GetSpecialValueInt("radius")
	if Fu.IsInTeamFight(bot, 1200) then
		local aoeLocation = bot:FindAoELocation(true, true, bot:GetLocation(), castRange, radius, castPoint, 0)
		if aoeLocation.count >= 2 then
			local enemiesNearAoe = Fu.GetEnemiesNearLoc(aoeLocation.targetloc, radius)
			if enemiesNearAoe ~= nil and #enemiesNearAoe >= 2 then
				return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
			end
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, 900, false, BOT_MODE_NONE)
		-- fix: nInRangeEnemy was an undefined global here, so engaging never used Acid Spray
		local nInRangeEnemy = Fu.GetNearbyHeroes(bot, 900, true, BOT_MODE_NONE)
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and Fu.IsAttacking(botTarget)
			and botTarget:IsFacingLocation(bot:GetLocation(), 45)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not botTarget:HasModifier("modifier_abaddon_borrowed_time")
			and not botTarget:HasModifier("modifier_dazzle_shallow_grave")
			and nearbyAllies ~= nil
			and nInRangeEnemy ~= nil
			and #nearbyAllies >= #nInRangeEnemy
		then
			local enemiesNearTarget = Fu.GetNearbyHeroes(botTarget, 900, false, BOT_MODE_NONE)
			if nearbyAllies ~= nil and enemiesNearTarget ~= nil and #nearbyAllies >= #enemiesNearTarget then
				if DotaTime() >= lastEngageLogTime + 5 then
					lastEngageLogTime = DotaTime()
					pcall(
						print,
						string.format(
							"[OHA-RUBICK] t=%.0f stolen acid spray engage target=%s",
							DotaTime(),
							botTarget:GetUnitName()
						)
					)
				end
				return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
			end
		end
	end
	if Fu.IsRetreating(bot) then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, 1000, false, BOT_MODE_NONE)
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, 1000, true, BOT_MODE_NONE)
		if
			nearbyAllies ~= nil
			and nearbyEnemies
			and Fu.IsValidHero(nearbyEnemies[1])
			and Fu.CanCastOnNonMagicImmune(nearbyEnemies[1])
			and Fu.IsInRange(bot, nearbyEnemies[1], 600)
			and Fu.IsRunning(nearbyEnemies[1])
			and nearbyEnemies[1]:IsFacingLocation(bot:GetLocation(), 30)
			and not Fu.IsSuspiciousIllusion(nearbyEnemies[1])
			and not Fu.IsDisabled(nearbyEnemies[1])
		then
			local enemiesNearEnemy = Fu.GetNearbyHeroes(nearbyEnemies[1], 800, false, BOT_MODE_NONE)
			if
				enemiesNearEnemy ~= nil
				and (#enemiesNearEnemy > #nearbyAllies or Fu.GetHP(bot) < 0.45 and bot:WasRecentlyDamagedByAnyHero(2.5))
			then
				return BOT_ACTION_DESIRE_HIGH, bot:GetLocation()
			end
		end
	end
	if Fu.IsDefending(bot) or Fu.IsPushing(bot) then
		local nearbyLaneCreeps = bot:GetNearbyLaneCreeps(castRange, true)
		local aoeLocation = bot:FindAoELocation(true, false, bot:GetLocation(), castRange, radius, 0, 0)
		local allyLaneFront = GetLaneFrontLocation(GetTeam(), bot:GetAssignedLane(), 0)
		local enemyLaneFront = GetLaneFrontLocation(GetOpposingTeam(), bot:GetAssignedLane(), 0)
		if
			nearbyLaneCreeps ~= nil
			and #nearbyLaneCreeps >= 5
			and aoeLocation.count >= 5
			and Fu.GetLocationToLocationDistance(allyLaneFront, enemyLaneFront) < 150
		then
			return BOT_ACTION_DESIRE_MODERATE, aoeLocation.targetloc
		end
	end
	if Fu.IsFarming(bot) then
		local aoeLocation = bot:FindAoELocation(true, false, bot:GetLocation(), castRange, radius, 0, 0)
		local nearbyNeutrals = bot:GetNearbyNeutralCreeps(600)
		local nearbyLaneCreeps = bot:GetNearbyLaneCreeps(600, true)
		if Fu.IsAttacking(bot) and Fu.GetMP(bot) > 0.33 then
			if
				nearbyNeutrals ~= nil
				and (
					#nearbyNeutrals >= 3 and aoeLocation.count >= 3
					or #nearbyNeutrals >= 2 and aoeLocation.count >= 2 and nearbyNeutrals[1]:IsAncientCreep()
				)
			then
				return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
			end
			if nearbyLaneCreeps ~= nil and #nearbyLaneCreeps >= 4 and aoeLocation.count >= 4 then
				return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
			end
		end
	end
	if Fu.IsLaning(bot) then
		local nearbyLaneCreeps = bot:GetNearbyLaneCreeps(600, true)
		local aoeLocation = bot:FindAoELocation(true, false, bot:GetLocation(), castRange, radius, 0, 0)
		if Fu.IsAttacking(bot) and Fu.GetMP(bot) > 0.65 then
			if nearbyLaneCreeps ~= nil and #nearbyLaneCreeps >= 4 and aoeLocation.count >= 4 then
				return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
			end
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if
			Fu.IsRoshan(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, 500)
			and Fu.IsAttacking(bot)
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, 400) and Fu.IsAttacking(bot) then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.ConsiderUnstableConcoction()
	if not unstableConcoctionAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
	end
	local castRange = Fu.GetProperCastRange(false, bot, unstableConcoctionAbility:GetCastRange())
	local maxDamage = unstableConcoctionAbility:GetSpecialValueInt("max_damage")
	local nearbyEnemies = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and Fu.IsInRange(bot, enemyHero, castRange - 200)
			and not Fu.IsSuspiciousIllusion(enemyHero)
		then
			if enemyHero:IsChanneling() then
				return BOT_ACTION_DESIRE_HIGH
			end
			if
				Fu.CanKillTarget(enemyHero, maxDamage, DAMAGE_TYPE_PHYSICAL)
				and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
				and not enemyHero:HasModifier("modifier_abaddon_aphotic_shield")
				and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
				and not enemyHero:HasModifier("modifier_enigma_black_hole_pull")
				and not enemyHero:HasModifier("modifier_faceless_void_chronosphere_freeze")
				and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
				and not enemyHero:HasModifier("modifier_item_solar_crest_armor_addition")
			then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, 1000, false, BOT_MODE_NONE)
		local enemiesInRange = Fu.GetNearbyHeroes(bot, castRange - 175, true, BOT_MODE_NONE)
		for _, enemyHero in pairs(enemiesInRange) do
			if
				Fu.IsValidTarget(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and not Fu.IsDisabled(enemyHero)
				and not enemyHero:HasModifier("modifier_enigma_black_hole_pull")
				and not enemyHero:HasModifier("modifier_faceless_void_chronosphere_freeze")
				and not enemyHero:HasModifier("modifier_legion_commander_duel")
				and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
			then
				local enemiesNearEnemy = Fu.GetNearbyHeroes(enemyHero, 1000, false, BOT_MODE_NONE)
				if nearbyAllies ~= nil and enemiesNearEnemy ~= nil and #nearbyAllies >= #enemiesNearEnemy then
					return BOT_ACTION_DESIRE_HIGH, enemyHero
				end
			end
		end
	end
	if Fu.IsRetreating(bot) then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, castRange + 175, false, BOT_MODE_NONE)
		local enemiesInRange = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
		if
			nearbyAllies ~= nil
			and enemiesInRange ~= nil
			and Fu.IsValidHero(enemiesInRange[1])
			and Fu.CanCastOnNonMagicImmune(enemiesInRange[1])
			and Fu.IsInRange(bot, enemiesInRange[1], castRange - 175)
			and Fu.IsRunning(enemiesInRange[1])
			and enemiesInRange[1]:IsFacingLocation(bot:GetLocation(), 30)
			and not Fu.IsSuspiciousIllusion(enemiesInRange[1])
			and not Fu.IsDisabled(enemiesInRange[1])
			and not enemiesInRange[1]:HasModifier("modifier_enigma_black_hole_pull")
			and not enemiesInRange[1]:HasModifier("modifier_faceless_void_chronosphere_freeze")
			and not enemiesInRange[1]:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			local enemiesNearEnemy = Fu.GetNearbyHeroes(enemiesInRange[1], 800, false, BOT_MODE_NONE)
			if
				enemiesNearEnemy ~= nil
				and (#enemiesNearEnemy > #nearbyAllies or Fu.GetHP(bot) < 0.6 and bot:WasRecentlyDamagedByAnyHero(2.2))
			then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderUnstableConcoctionThrow()
	if unstableConcoctionThrowAbility:IsHidden() or not unstableConcoctionThrowAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castRange = Fu.GetProperCastRange(false, bot, unstableConcoctionThrowAbility:GetCastRange())
	-- The concoction handle is set only after its own branch ran; without it, 0 skips the kill check.
	local maxDamage = 0
	if unstableConcoctionAbility ~= nil and not unstableConcoctionAbility:IsNull() then
		maxDamage = unstableConcoctionAbility:GetSpecialValueInt("max_damage")
	end
	local nearbyEnemies = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and not Fu.IsSuspiciousIllusion(enemyHero)
			and DotaTime() >= concoctionStartTime + fullBrewDelay
		then
			if enemyHero:IsChanneling() then
				return BOT_ACTION_DESIRE_HIGH, enemyHero
			end
			if
				Fu.CanKillTarget(enemyHero, maxDamage, DAMAGE_TYPE_PHYSICAL)
				and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
				and not enemyHero:HasModifier("modifier_abaddon_aphotic_shield")
				and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
				and not enemyHero:HasModifier("modifier_enigma_black_hole_pull")
				and not enemyHero:HasModifier("modifier_faceless_void_chronosphere_freeze")
				and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
				and not enemyHero:HasModifier("modifier_item_solar_crest_armor_addition")
			then
				return BOT_ACTION_DESIRE_HIGH, enemyHero
			end
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, 1000, false, BOT_MODE_NONE)
		local enemiesInRange = Fu.GetNearbyHeroes(bot, castRange - 175, true, BOT_MODE_NONE)
		for _, enemyHero in pairs(enemiesInRange) do
			if
				Fu.IsValidTarget(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and not Fu.IsDisabled(enemyHero)
				and not enemyHero:HasModifier("modifier_enigma_black_hole_pull")
				and not enemyHero:HasModifier("modifier_faceless_void_chronosphere_freeze")
				and not enemyHero:HasModifier("modifier_legion_commander_duel")
				and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
				and DotaTime() >= concoctionStartTime + fullBrewDelay
			then
				local enemiesNearEnemy = Fu.GetNearbyHeroes(enemyHero, 1000, false, BOT_MODE_NONE)
				if nearbyAllies ~= nil and enemiesNearEnemy ~= nil and #nearbyAllies >= #enemiesNearEnemy then
					return BOT_ACTION_DESIRE_HIGH, enemyHero
				end
			end
		end
	end
	if Fu.IsRetreating(bot) then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, 800, false, BOT_MODE_NONE)
		local enemiesInRange = Fu.GetNearbyHeroes(bot, 1000, true, BOT_MODE_NONE)
		if
			nearbyAllies ~= nil
			and enemiesInRange ~= nil
			and Fu.IsValidHero(enemiesInRange[1])
			and Fu.CanCastOnNonMagicImmune(enemiesInRange[1])
			and Fu.IsInRange(bot, enemiesInRange[1], castRange)
			and not Fu.IsSuspiciousIllusion(enemiesInRange[1])
			and not enemiesInRange[1]:HasModifier("modifier_enigma_black_hole_pull")
			and not enemiesInRange[1]:HasModifier("modifier_faceless_void_chronosphere_freeze")
			and not enemiesInRange[1]:HasModifier("modifier_necrolyte_reapers_scythe")
			and DotaTime() >= concoctionStartTime + minThrowDelay
		then
			local enemiesNearEnemy = Fu.GetNearbyHeroes(enemiesInRange[1], 800, false, BOT_MODE_NONE)
			if
				enemiesNearEnemy ~= nil
				and (#enemiesNearEnemy > #nearbyAllies or Fu.GetHP(bot) < 0.6 and bot:WasRecentlyDamagedByAnyHero(2.2))
			then
				return BOT_ACTION_DESIRE_HIGH, enemiesInRange[1]
			end
		end
	end
	if nearbyEnemies ~= nil and #nearbyEnemies >= 1 and DotaTime() >= concoctionStartTime + minThrowDelay then
		return BOT_ACTION_DESIRE_HIGH, nearbyEnemies[1]
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function X.ConsiderChemicalRage()
	if not chemicalRageAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
	end
	if Fu.IsInTeamFight(bot, 1200) then
		local nearbyEnemies = Fu.GetEnemiesNearLoc(bot:GetLocation(), 700)
		if nearbyEnemies ~= nil and #nearbyEnemies >= 2 then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, 1000, false, BOT_MODE_NONE)
		if
			Fu.IsValidTarget(botTarget)
			and Fu.IsInRange(bot, botTarget, 800)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not botTarget:HasModifier("modifier_enigma_black_hole_pull")
			and not botTarget:HasModifier("modifier_faceless_void_chronosphere_freeze")
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			local enemiesNearTarget = Fu.GetNearbyHeroes(botTarget, 1000, false, BOT_MODE_NONE)
			if nearbyAllies ~= nil and enemiesNearTarget ~= nil and #nearbyAllies >= #enemiesNearTarget then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	if Fu.IsRetreating(bot) then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, 800, false, BOT_MODE_NONE)
		local enemiesInRange = Fu.GetNearbyHeroes(bot, 800, true, BOT_MODE_NONE)
		if
			nearbyAllies ~= nil
			and enemiesInRange ~= nil
			and Fu.IsValidHero(enemiesInRange[1])
			and Fu.IsRunning(enemiesInRange[1])
			and enemiesInRange[1]:IsFacingLocation(bot:GetLocation(), 30)
			and not Fu.IsSuspiciousIllusion(enemiesInRange[1])
			and not Fu.IsDisabled(enemiesInRange[1])
			and not enemiesInRange[1]:HasModifier("modifier_enigma_black_hole_pull")
			and not enemiesInRange[1]:HasModifier("modifier_faceless_void_chronosphere_freeze")
			and not enemiesInRange[1]:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			local enemiesNearEnemy = Fu.GetNearbyHeroes(enemiesInRange[1], 800, false, BOT_MODE_NONE)
			if
				enemiesNearEnemy ~= nil
				and (#enemiesNearEnemy > #nearbyAllies or Fu.GetHP(bot) < 0.35 and bot:WasRecentlyDamagedByAnyHero(1.5))
			then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	if Fu.IsFarming(bot) then
		if Fu.IsAttacking(bot) and Fu.IsValid(botTarget) and botTarget:IsCreep() and Fu.GetHP(bot) < 0.3 then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if
			Fu.IsRoshan(botTarget)
			and Fu.IsInRange(bot, botTarget, 500)
			and Fu.IsAttacking(bot)
			and (Fu.IsModeTurbo() and DotaTime() < 15 * 60 or DotaTime() < 30 * 60)
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if
			Fu.IsTormentor(botTarget)
			and Fu.IsInRange(bot, botTarget, 400)
			and Fu.IsAttacking(bot)
			and (Fu.IsModeTurbo() and DotaTime() < 16 * 60 or DotaTime() < 32 * 60)
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderBerserkPotion()
	if not berserkPotionAbility:IsTrained() or not berserkPotionAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castRange = Fu.GetProperCastRange(false, bot, berserkPotionAbility:GetCastRange())
	local nearbyAllies = Fu.GetNearbyHeroes(bot, castRange, false, BOT_MODE_NONE)
	for _, allyHero in pairs(nearbyAllies) do
		if
			Fu.IsValidHero(allyHero)
			and Fu.IsInRange(bot, allyHero, castRange)
			and not allyHero:HasModifier("modifier_legion_commander_press_the_attack")
			and not allyHero:HasModifier("modifier_item_satanic_unholy")
			and not allyHero:IsMagicImmune()
			and not allyHero:IsInvulnerable()
			and not allyHero:IsIllusion()
			and allyHero:CanBeSeen()
		then
			if Fu.IsDisabled(allyHero) then
				return BOT_ACTION_DESIRE_HIGH, allyHero
			end
			if
				Fu.IsRetreating(allyHero)
				and Fu.IsRunning(allyHero)
				and Fu.GetHP(allyHero) < 0.6
				and allyHero:WasRecentlyDamagedByAnyHero(2.5)
				and allyHero:IsFacingLocation(GetAncient(GetTeam()):GetLocation(), 45)
			then
				return BOT_ACTION_DESIRE_HIGH, allyHero
			end
			if Fu.IsGoingOnSomeone(allyHero) then
				local allyTarget = Fu.GetProperTarget(allyHero)
				if
					Fu.IsValidHero(allyTarget)
					and allyHero:IsFacingLocation(allyTarget:GetLocation(), 20)
					and Fu.IsInRange(allyHero, allyTarget, allyHero:GetAttackRange() + 100)
				then
					return BOT_ACTION_DESIRE_HIGH, allyHero
				end
				if Fu.GetHP(allyHero) < 0.33 then
					return BOT_ACTION_DESIRE_HIGH, allyHero
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
return X
