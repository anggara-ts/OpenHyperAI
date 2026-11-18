-- How Rubick plays after stealing a spell from Bane.
-- Accidental globals made file-local (#13): every bot shares one Lua state, so these were shared.
local EnfeebleDesire, EnfeebleTarget, BrainSapDesire, BrainSapTarget, FiendsGripDesire, FiendsGripTarget, NightmareDesire, NightmareTarget
local bot = GetBot()
local X = {}
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local enfeebleAbility
local brainSapAbility
local nightmareAbility
local fiendsGripAbility
local botTarget
local brainSapTargetType
local mpRatio, botLevel, nearbyEnemies, nearbyAllies
function X.ConsiderStolenSpell(ability)
	bot = GetBot()
	if Fu.CanNotUseAbility(bot) then
		return
	end
	botTarget = Fu.GetProperTarget(bot)
	local abilityName = ability:GetName()
	botLevel = bot:GetLevel()
	mpRatio = bot:GetMana() / bot:GetMaxMana()
	botTarget = Fu.GetProperTarget(bot)
	nearbyEnemies = Fu.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE)
	nearbyAllies = Fu.GetAlliesNearLoc(bot:GetLocation(), 1600)
	if abilityName == "bane_enfeeble" then
		enfeebleAbility = ability
		EnfeebleDesire, EnfeebleTarget = X.ConsiderEnfeeble()
		if EnfeebleDesire > 0 then
			bot:ActionQueue_UseAbilityOnEntity(enfeebleAbility, EnfeebleTarget)
			return
		end
	end
	if abilityName == "bane_brain_sap" then
		brainSapAbility = ability
		BrainSapDesire, BrainSapTarget = X.ConsiderBrainSap()
		if BrainSapDesire > 0 then
			brainSapAbility = ability
			if brainSapTargetType == nil and brainSapAbility:IsTrained() then
				brainSapTargetType = brainSapAbility:GetTargetType()
			end
			if brainSapTargetType ~= nil and brainSapTargetType ~= brainSapAbility:GetTargetType() then
				bot:ActionQueue_UseAbilityOnEntity(brainSapAbility, brainSapAbility:GetLocation())
			else
				bot:ActionQueue_UseAbilityOnEntity(brainSapAbility, BrainSapTarget)
			end
			return
		end
	end
	if abilityName == "bane_fiends_grip" then
		fiendsGripAbility = ability
		FiendsGripDesire, FiendsGripTarget = X.ConsiderFiendsGrip()
		if FiendsGripDesire > 0 then
			Fu.SetQueueToInvisible(bot)
			bot:ActionQueue_UseAbilityOnEntity(fiendsGripAbility, FiendsGripTarget)
			return
		end
	end
	if abilityName == "bane_nightmare" then
		nightmareAbility = ability
		NightmareDesire, NightmareTarget = X.ConsiderNightmare()
		if NightmareDesire > 0 then
			bot:ActionQueue_UseAbilityOnEntity(nightmareAbility, NightmareTarget)
			return
		end
	end
end
function X.ConsiderEnfeeble()
	if not enfeebleAbility:IsFullyCastable() then
		return 0
	end
	local abilityLevel = enfeebleAbility:GetLevel()
	local castRange = Fu.GetProperCastRange(false, bot, enfeebleAbility:GetCastRange())
	local enemiesInRange = Fu.GetAroundEnemyHeroList(castRange)
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidHero(botTarget)
			and not botTarget:HasModifier("modifier_bane_enfeeble")
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.CanCastOnTargetAdvanced(botTarget)
			and Fu.IsInRange(botTarget, bot, castRange + 50)
		then
			if abilityLevel >= 2 or mpRatio > 0.6 then
				return BOT_ACTION_DESIRE_HIGH, botTarget
			end
		end
		for _, enemyHero in pairs(enemiesInRange) do
			if
				Fu.IsValid(enemyHero)
				and not enemyHero:HasModifier("modifier_bane_enfeeble")
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
			then
				return BOT_ACTION_DESIRE_HIGH, enemyHero
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderBrainSap()
	if not brainSapAbility:IsFullyCastable() then
		return 0
	end
	local abilityLevel = brainSapAbility:GetLevel()
	local castRange = brainSapAbility:GetCastRange()
	local castPoint = brainSapAbility:GetCastPoint()
	local manaCost = brainSapAbility:GetManaCost()
	local damage = brainSapAbility:GetSpecialValueInt("brain_sap_damage")
	local damageType = DAMAGE_TYPE_MAGICAL
	local enemiesInRange = Fu.GetAroundEnemyHeroList(castRange)
	local enemiesInWideRange = Fu.GetAroundEnemyHeroList(castRange + 200)
	local missingHealth = bot:GetMaxHealth() - bot:GetHealth()
	for _, enemyHero in pairs(enemiesInWideRange) do
		if
			Fu.IsValid(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and Fu.CanCastOnTargetAdvanced(enemyHero)
		then
			if Fu.WillMagicKillTarget(bot, enemyHero, damage, castPoint) then
				return BOT_ACTION_DESIRE_HIGH, enemyHero
			end
		end
	end
	if botLevel <= 7 and mpRatio < 0.72 and missingHealth < damage * 0.8 then
		return BOT_ACTION_DESIRE_NONE
	end
	if Fu.IsInTeamFight(bot, 1200) then
		local weakestTarget = nil
		local lowestHealth = 99999
		for _, enemyHero in pairs(enemiesInRange) do
			if
				Fu.IsValid(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
			then
				local health = enemyHero:GetHealth()
				if health < lowestHealth then
					lowestHealth = health
					weakestTarget = enemyHero
				end
			end
		end
		if weakestTarget ~= nil then
			return BOT_ACTION_DESIRE_HIGH, weakestTarget
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidHero(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.CanCastOnTargetAdvanced(botTarget)
			and Fu.IsInRange(botTarget, bot, castRange + 50)
		then
			if abilityLevel >= 2 or mpRatio > 0.78 or Fu.GetHP(botTarget) < 0.38 then
				return BOT_ACTION_DESIRE_HIGH, botTarget
			end
		end
	end
	if
		bot:WasRecentlyDamagedByAnyHero(3.0)
		and botLevel >= 10
		and bot:GetActiveMode() ~= BOT_MODE_RETREAT
		and #enemiesInRange >= 1
		and missingHealth >= damage
	then
		for _, enemyHero in pairs(enemiesInRange) do
			if
				Fu.IsValid(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and not Fu.IsDisabled(enemyHero)
				and not enemyHero:IsDisarmed()
				and bot:IsFacingLocation(enemyHero:GetLocation(), 45)
			then
				return BOT_ACTION_DESIRE_HIGH, enemyHero
			end
		end
	end
	if Fu.IsRetreating(bot) and missingHealth > damage then
		for _, enemyHero in pairs(enemiesInRange) do
			if
				Fu.IsValid(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
				and (bot:WasRecentlyDamagedByHero(enemyHero, 5.0) or missingHealth > damage * 2)
			then
				return BOT_ACTION_DESIRE_HIGH, enemyHero
			end
		end
		if
			#nearbyEnemies == 0
			and botLevel >= 10
			and not bot:WasRecentlyDamagedByAnyHero(3.0)
			and missingHealth > damage * 1.5
		then
			local nearbyCreeps = bot:GetNearbyCreeps(1000, true)
			for _, creep in pairs(nearbyCreeps) do
				if Fu.IsValid(creep) and Fu.CanCastOnNonMagicImmune(creep) then
					return BOT_ACTION_DESIRE_HIGH, creep
				end
			end
		end
	end
	if Fu.IsFarming(bot) and abilityLevel >= 3 and Fu.IsAllowedToSpam(bot, manaCost) then
		local farmTarget = botTarget
		if
			Fu.IsValid(farmTarget)
			and Fu.IsInRange(bot, farmTarget, castRange + 100)
			and farmTarget:GetTeam() == TEAM_NEUTRAL
			and not Fu.IsRoshan(farmTarget)
			and (farmTarget:GetMagicResist() < 0.3 or mpRatio > 0.8)
			and not Fu.CanKillTarget(farmTarget, bot:GetAttackDamage() * 2, DAMAGE_TYPE_PHYSICAL)
		then
			return BOT_ACTION_DESIRE_HIGH, farmTarget
		end
	end
	if
		(Fu.IsPushing(bot) or Fu.IsDefending(bot) or Fu.IsFarming(bot))
		and Fu.IsAllowedToSpam(bot, manaCost * 0.32)
		and abilityLevel >= 3
		and DotaTime() > 8 * 60
		and #nearbyAllies <= 2
		and #nearbyEnemies == 0
	then
		local laneCreeps = bot:GetNearbyLaneCreeps(1200, true)
		local creepKeyword = "ranged"
		for _, creep in pairs(laneCreeps) do
			if
				Fu.IsValid(creep)
				and (Fu.IsKeyWordUnit(creepKeyword, creep) or mpRatio > 0.6)
				and not creep:HasModifier("modifier_fountain_glyph")
				and Fu.WillKillTarget(creep, damage, damageType, castPoint)
				and not Fu.CanKillTarget(creep, bot:GetAttackDamage() * 1.38, DAMAGE_TYPE_PHYSICAL)
			then
				return BOT_ACTION_DESIRE_HIGH, creep
			end
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if Fu.IsRoshan(botTarget) and Fu.IsInRange(bot, botTarget, castRange - 200) then
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end
	if
		(#nearbyEnemies > 0 or bot:WasRecentlyDamagedByAnyHero(3.0))
		and (bot:GetActiveMode() ~= BOT_MODE_RETREAT or #nearbyAllies >= 2)
		and #enemiesInRange >= 1
		and botLevel >= 12
		and missingHealth > damage
	then
		for _, enemyHero in pairs(enemiesInRange) do
			if
				Fu.IsValid(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
			then
				return BOT_ACTION_DESIRE_HIGH, enemyHero
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderNightmare()
	if not nightmareAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castRange = Fu.GetProperCastRange(false, bot, nightmareAbility:GetCastRange())
	local enemiesInRange = Fu.GetNearbyHeroes(bot, castRange + 150, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(enemiesInRange) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and Fu.CanCastOnTargetAdvanced(enemyHero)
			and enemyHero:IsChanneling()
			and not Fu.IsSuspiciousIllusion(enemyHero)
			and not enemyHero:HasModifier("modifier_legion_commander_duel")
			and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			return BOT_ACTION_DESIRE_HIGH, enemyHero
		end
	end
	if Fu.IsInTeamFight(bot, 1200) then
		local bestTarget = nil
		local highestDamage = 0
		local enemyCount = 0
		local enemiesInCastRange = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
		for _, enemyHero in pairs(enemiesInCastRange) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and not Fu.IsSuspiciousIllusion(enemyHero)
			then
				enemyCount = enemyCount + 1
				if
					Fu.CanCastOnTargetAdvanced(enemyHero)
					and not Fu.IsDisabled(enemyHero)
					and not enemyHero:IsDisarmed()
					and not enemyHero:HasModifier("modifier_legion_commander_duel")
					and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
				then
					local estimatedDamage = enemyHero:GetEstimatedDamageToTarget(true, bot, 6.0, DAMAGE_TYPE_ALL)
					if estimatedDamage > highestDamage then
						highestDamage = estimatedDamage
						bestTarget = enemyHero
					end
				end
			end
		end
		if bestTarget ~= nil and enemyCount >= 2 then
			return BOT_ACTION_DESIRE_HIGH, bestTarget
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if Fu.IsValidHero(botTarget) then
			local enemyHeroes = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
			for _, enemyHero in pairs(enemyHeroes) do
				if
					Fu.IsValid(enemyHero)
					and Fu.CanCastOnNonMagicImmune(enemyHero)
					and Fu.CanCastOnTargetAdvanced(enemyHero)
					and enemyHero:GetPlayerID() ~= botTarget:GetPlayerID()
					and not enemyHero:IsDisarmed()
					and not Fu.IsDisabled(enemyHero)
					and not Fu.IsSuspiciousIllusion(enemyHero)
					and not enemyHero:HasModifier("modifier_legion_commander_duel")
					and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
				then
					return BOT_ACTION_DESIRE_HIGH, enemyHero
				end
			end
			if
				Fu.IsInRange(bot, botTarget, castRange)
				and Fu.CanCastOnNonMagicImmune(botTarget)
				and Fu.CanCastOnTargetAdvanced(botTarget)
				and Fu.IsChasingTarget(bot, botTarget)
				and not Fu.IsDisabled(botTarget)
				and not Fu.IsSuspiciousIllusion(botTarget)
				and not botTarget:HasModifier("modifier_legion_commander_duel")
				and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
			then
				local alliesNearTarget = Fu.GetNearbyHeroes(botTarget, 1200, true, BOT_MODE_NONE)
				enemyHeroes = Fu.GetNearbyHeroes(botTarget, 1200, false, BOT_MODE_NONE)
				if
					alliesNearTarget ~= nil
					and enemyHeroes ~= nil
					and #alliesNearTarget >= #enemyHeroes
					and #alliesNearTarget < #enemyHeroes + 2
				then
					return BOT_ACTION_DESIRE_HIGH, botTarget
				end
			end
		end
	end
	if Fu.IsRetreating(bot) and bot:GetActiveModeDesire() > 0.7 then
		for _, enemyHero in pairs(enemiesInRange) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and not Fu.IsDisabled(enemyHero)
				and not enemyHero:IsDisarmed()
			then
				local alliesNearChaser = Fu.GetNearbyHeroes(enemyHero, 1200, true, BOT_MODE_NONE)
				local enemiesNearChaser = Fu.GetNearbyHeroes(enemyHero, 1200, false, BOT_MODE_NONE)
				if
					alliesNearChaser ~= nil
					and enemiesNearChaser ~= nil
					and (#enemiesNearChaser > #alliesNearChaser or bot:WasRecentlyDamagedByAnyHero(2))
				then
					return BOT_ACTION_DESIRE_HIGH, enemyHero
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function X.ConsiderFiendsGrip()
	if not fiendsGripAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castRange = Fu.GetProperCastRange(false, bot, fiendsGripAbility:GetCastRange())
	local damage = fiendsGripAbility:GetSpecialValueInt("fiend_grip_damage") * 6
	local enemiesInRange = Fu.GetNearbyHeroes(bot, castRange + 150, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(enemiesInRange) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and Fu.CanCastOnTargetAdvanced(enemyHero)
			and not Fu.IsSuspiciousIllusion(enemyHero)
		then
			if enemyHero:IsChanneling() then
				return BOT_ACTION_DESIRE_HIGH, enemyHero
			end
			if
				Fu.CanKillTarget(enemyHero, damage, DAMAGE_TYPE_PURE)
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
	if Fu.IsInTeamFight(bot, 1200) then
		local bestTarget = nil
		local highestDamage = 0
		local enemiesInCastRange = Fu.GetNearbyHeroes(bot, castRange + 150, true, BOT_MODE_NONE)
		for _, enemyHero in pairs(enemiesInCastRange) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
				and not Fu.IsDisabled(enemyHero)
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
				and not enemyHero:HasModifier("modifier_legion_commander_duel")
				and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
			then
				local estimatedDamage = enemyHero:GetEstimatedDamageToTarget(true, bot, 6.0, DAMAGE_TYPE_ALL)
				if estimatedDamage > highestDamage then
					highestDamage = estimatedDamage
					bestTarget = enemyHero
				end
			end
		end
		if bestTarget ~= nil then
			return BOT_ACTION_DESIRE_HIGH, bestTarget
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidHero(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.CanCastOnTargetAdvanced(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not Fu.IsDisabled(botTarget)
			and not botTarget:IsAttackImmune()
			and not botTarget:IsInvulnerable()
			and not botTarget:HasModifier("modifier_abaddon_borrowed_time")
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
return X
