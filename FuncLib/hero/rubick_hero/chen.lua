-- How Rubick plays after stealing a spell from Chen.
local bot
local X = {}
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local penitenceAbility
local holyPersuasionAbility
local divineFavorAbility
local handOfGodAbility
local botTarget
local persuadedCreeps = {}
function X.ConsiderStolenSpell(ability)
	bot = GetBot()
	if Fu.CanNotUseAbility(bot) then
		return
	end
	botTarget = Fu.GetProperTarget(bot)
	local abilityName = ability:GetName()
	if abilityName == "chen_hand_of_god" then
		handOfGodAbility = ability
		HandOfGodDesire = X.ConsiderHandOfGod()
		if HandOfGodDesire > 0 then
			bot:Action_UseAbility(handOfGodAbility)
			return
		end
	end
	if abilityName == "chen_penitence" then
		penitenceAbility = ability
		PenitenceDesire, PenitenceTarget = X.ConsiderPenitence()
		if PenitenceDesire > 0 then
			bot:Action_UseAbilityOnEntity(penitenceAbility, PenitenceTarget)
			return
		end
	end
	if abilityName == "chen_holy_persuasion" then
		holyPersuasionAbility = ability
		HolyPersuasionDesire, HolyPersuasionTarget = X.ConsiderHolyPersuasion()
		if HolyPersuasionDesire > 0 then
			bot:Action_UseAbilityOnEntity(holyPersuasionAbility, HolyPersuasionTarget)
			return
		end
	end
	if abilityName == "chen_divine_favor" then
		divineFavorAbility = ability
		DivineFavorDesire, DivineFavorTarget = X.ConsiderDivineFavor()
		if DivineFavorDesire > 0 then
			bot:Action_UseAbilityOnEntity(divineFavorAbility, DivineFavorTarget)
			return
		end
	end
end
function X.ConsiderPenitence()
	if not penitenceAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castRange = Fu.GetProperCastRange(false, bot, penitenceAbility:GetCastRange())
	local attackRange = bot:GetAttackRange()
	local nearbyAllies = Fu.GetNearbyHeroes(bot, castRange, false, BOT_MODE_NONE)
	for _, allyHero in pairs(nearbyAllies) do
		local allyNearbyEnemies = Fu.GetNearbyHeroes(allyHero, 1200, true, BOT_MODE_NONE)
		if Fu.IsValidHero(allyHero) and Fu.IsRetreating(allyHero) and allyHero:WasRecentlyDamagedByAnyHero(1.5) and not allyHero:IsIllusion() then
			if
				allyNearbyEnemies ~= nil
				and #allyNearbyEnemies >= 1
				and Fu.IsValidHero(allyNearbyEnemies[1])
				and Fu.IsInRange(bot, allyNearbyEnemies[1], castRange)
				and Fu.IsChasingTarget(allyNearbyEnemies[1], allyHero)
				and allyHero:GetCurrentMovementSpeed() < allyNearbyEnemies[1]:GetCurrentMovementSpeed()
				and not Fu.IsDisabled(allyNearbyEnemies[1])
				and not Fu.IsTaunted(allyNearbyEnemies[1])
				and not Fu.IsSuspiciousIllusion(allyNearbyEnemies[1])
				and not allyNearbyEnemies[1]:HasModifier("modifier_necrolyte_reapers_scythe")
			then
				return BOT_ACTION_DESIRE_HIGH, allyNearbyEnemies[1]
			end
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidTarget(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not botTarget:HasModifier("modifier_abaddon_borrowed_time")
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			local targetNearbyEnemies = Fu.GetNearbyHeroes(botTarget, 1200, true, BOT_MODE_NONE)
			local targetNearbyAllies = Fu.GetNearbyHeroes(botTarget, 1200, false, BOT_MODE_NONE)
			if targetNearbyEnemies ~= nil and targetNearbyAllies ~= nil and #targetNearbyEnemies >= #targetNearbyAllies then
				if Fu.IsChasingTarget(bot, botTarget) and bot:GetCurrentMovementSpeed() < botTarget:GetCurrentMovementSpeed() then
					return BOT_ACTION_DESIRE_HIGH, botTarget
				end
				targetNearbyEnemies = Fu.GetAlliesNearLoc(bot:GetLocation(), 1600)
				if Fu.IsInRange(bot, botTarget, attackRange) and Fu.IsAttacking(bot) and Fu.GetHeroCountAttackingTarget(targetNearbyEnemies, botTarget) >= 2 then
					return BOT_ACTION_DESIRE_HIGH, botTarget
				end
			end
		end
	end
	if Fu.IsRetreating(bot) then
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.IsChasingTarget(enemyHero, bot)
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and not Fu.IsDisabled(enemyHero)
			then
				local enemyNearbyEnemies = Fu.GetNearbyHeroes(enemyHero, 1200, true, BOT_MODE_NONE)
				local enemyNearbyAllies = Fu.GetNearbyHeroes(enemyHero, 1200, false, BOT_MODE_NONE)
				if
					enemyNearbyEnemies ~= nil
					and enemyNearbyAllies ~= nil
					and (#enemyNearbyAllies > #enemyNearbyEnemies or bot:WasRecentlyDamagedByAnyHero(1.5))
					and bot:GetCurrentMovementSpeed() < enemyHero:GetCurrentMovementSpeed()
				then
					return BOT_ACTION_DESIRE_HIGH, enemyHero
				end
			end
		end
	end
	if Fu.IsDoingRoshan(bot) or Fu.IsDoingTormentor(bot) then
		local nearbyAllies = Fu.GetAlliesNearLoc(bot:GetLocation(), 800)
		if
			(Fu.IsRoshan(botTarget) or Fu.IsTormentor(botTarget))
			and Fu.IsInRange(bot, botTarget, castRange)
			and Fu.IsAttacking(bot)
			and nearbyAllies ~= nil
			and #nearbyAllies >= 1
			and Fu.GetHeroCountAttackingTarget(nearbyAllies, botTarget) >= 2
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function X.ConsiderHolyPersuasion()
	if not holyPersuasionAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castRange = Fu.GetProperCastRange(false, bot, holyPersuasionAbility:GetCastRange())
	local maxUnits = holyPersuasionAbility:GetSpecialValueInt("max_units")
	local levelRequirement = holyPersuasionAbility:GetSpecialValueInt("level_req")
	local nearbyCreeps = bot:GetNearbyNeutralCreeps(castRange)
	local ownedCreeps = {}
	for _, unit in pairs(GetUnitList(UNIT_LIST_ALLIES)) do
		if string.find(unit:GetUnitName(), "neutral") and unit:HasModifier("modifier_chen_holy_persuasion") then
			table.insert(ownedCreeps, unit)
		end
	end
	persuadedCreeps = ownedCreeps
	local bigCampCreepNames = {
		"npc_dota_neutral_alpha_wolf",
		"npc_dota_neutral_centaur_khan",
		"npc_dota_neutral_polar_furbolg_ursa_warrior",
		"npc_dota_neutral_dark_troll_warlord",
		"npc_dota_neutral_satyr_hellcaller",
		"npc_dota_neutral_enraged_wildkin",
		"npc_dota_neutral_warpine_raider",
	}
	if levelRequirement < 5 then
		for _, creep in pairs(nearbyCreeps) do
			if Fu.IsValid(creep) then
				return BOT_ACTION_DESIRE_HIGH, creep
			end
		end
	else
		if persuadedCreeps ~= nil and #persuadedCreeps < maxUnits then
			for _, creep in pairs(nearbyCreeps) do
				if Fu.IsValid(creep) and creep:GetLevel() <= levelRequirement then
					for _, creepName in pairs(bigCampCreepNames) do
						if creep:GetUnitName() == creepName then
							return BOT_ACTION_DESIRE_HIGH, creep
						end
					end
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function X.ConsiderDivineFavor()
	if not divineFavorAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castRange = Fu.GetProperCastRange(false, bot, divineFavorAbility:GetCastRange())
	local nearbyAllies = Fu.GetNearbyHeroes(bot, castRange, false, BOT_MODE_NONE)
	for _, allyHero in pairs(nearbyAllies) do
		if
			Fu.IsValidHero(allyHero)
			and Fu.IsInRange(bot, allyHero, castRange)
			and not allyHero:HasModifier("modifier_abaddon_borrowed_time")
			and not allyHero:HasModifier("modifier_legion_commander_press_the_attack")
			and not allyHero:HasModifier("modifier_necrolyte_reapers_scythe")
			and not allyHero:HasModifier("modifier_chen_penitence_attack_speed_buff")
			and not allyHero:HasModifier("modifier_chen_divine_favor_armor_buff")
			and not allyHero:IsIllusion()
			and not allyHero:IsInvulnerable()
		then
			if Fu.IsGoingOnSomeone(allyHero) then
				local allyTarget = Fu.GetProperTarget(allyHero)
				if
					Fu.IsValidTarget(allyTarget)
					and Fu.IsCore(allyHero)
					and Fu.IsInRange(allyHero, allyTarget, allyHero:GetCurrentVisionRange())
					and not Fu.IsSuspiciousIllusion(allyTarget)
				then
					return BOT_ACTION_DESIRE_HIGH, allyHero
				end
			end
			local allyNearbyEnemies = Fu.GetNearbyHeroes(allyHero, 1200, true, BOT_MODE_NONE)
			if Fu.IsRetreating(allyHero) and allyHero:WasRecentlyDamagedByAnyHero(1.5) then
				if
					allyNearbyEnemies ~= nil
					and #allyNearbyEnemies >= 1
					and Fu.IsValidHero(allyNearbyEnemies[1])
					and Fu.IsInRange(bot, allyNearbyEnemies[1], castRange)
					and Fu.IsChasingTarget(allyNearbyEnemies[1], allyHero)
					and not Fu.IsDisabled(allyNearbyEnemies[1])
					and not Fu.IsTaunted(allyNearbyEnemies[1])
					and not Fu.IsSuspiciousIllusion(allyNearbyEnemies[1])
					and not allyNearbyEnemies[1]:HasModifier("modifier_necrolyte_reapers_scythe")
				then
					return BOT_ACTION_DESIRE_HIGH, allyNearbyEnemies[1]
				end
			end
		end
	end
	if Fu.IsDoingRoshan(bot) or Fu.IsDoingTormentor(bot) then
		if (Fu.IsRoshan(botTarget) or Fu.IsTormentor(botTarget)) and Fu.IsInRange(bot, botTarget, castRange) and Fu.IsAttacking(bot) then
			local weakestUnit = Fu.GetAttackableWeakestUnit(bot, castRange, true, false)
			if weakestUnit ~= nil then
				return BOT_ACTION_DESIRE_HIGH, weakestUnit
			end
		end
	end
	if Fu.IsInTeamFight(bot, 1200) then
		local totalDistance = 0
		for _, creep in pairs(persuadedCreeps) do
			local distance = GetUnitToUnitDistance(bot, creep)
			if distance > 1600 then
				totalDistance = totalDistance + distance
			end
		end
		if persuadedCreeps ~= nil and #persuadedCreeps > 0 then
			if totalDistance / #persuadedCreeps > 1600 then
				return BOT_ACTION_DESIRE_HIGH, bot
			end
		end
	end
	if Fu.IsRetreating(bot) then
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.IsChasingTarget(enemyHero, bot)
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and not Fu.IsDisabled(enemyHero)
			then
				local enemyNearbyEnemies = Fu.GetNearbyHeroes(enemyHero, 1200, true, BOT_MODE_NONE)
				local enemyNearbyAllies = Fu.GetNearbyHeroes(enemyHero, 1200, false, BOT_MODE_NONE)
				if enemyNearbyEnemies ~= nil and enemyNearbyAllies ~= nil and (#enemyNearbyAllies > #enemyNearbyEnemies and #enemyNearbyEnemies <= 1 or bot:WasRecentlyDamagedByAnyHero(2)) then
					return BOT_ACTION_DESIRE_HIGH, enemyHero
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function X.ConsiderHandOfGod()
	if not handOfGodAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
	end
	local teamFightLocation = Fu.GetTeamFightLocation(bot)
	if teamFightLocation ~= nil then
		local alliesNearFight = Fu.GetAlliesNearLoc(teamFightLocation, 1600)
		for _, allyHero in pairs(alliesNearFight) do
			if
				Fu.IsValidHero(allyHero)
				and Fu.IsCore(allyHero)
				and Fu.GetHP(allyHero) < 0.5
				and not allyHero:IsIllusion()
				and not allyHero:IsAttackImmune()
				and not allyHero:IsInvulnerable()
				and not allyHero:HasModifier("modifier_necrolyte_reapers_scythe")
				and not allyHero:HasModifier("modifier_oracle_false_promise_timer")
			then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	for _, allyHero in pairs(GetUnitList(UNIT_LIST_ALLIED_HEROES)) do
		local allyNearbyEnemies = Fu.GetNearbyHeroes(allyHero, 1200, true, BOT_MODE_NONE)
		if
			Fu.IsValidHero(allyHero)
			and Fu.IsCore(allyHero)
			and Fu.GetHP(allyHero) < 0.5
			and allyHero:WasRecentlyDamagedByAnyHero(1)
			and not allyHero:IsIllusion()
			and not allyHero:IsAttackImmune()
			and not allyHero:IsInvulnerable()
			and not allyHero:HasModifier("modifier_necrolyte_reapers_scythe")
			and not allyHero:HasModifier("modifier_oracle_false_promise_timer")
		then
			if
				allyNearbyEnemies ~= nil
				and #allyNearbyEnemies >= 1
				and Fu.IsValidHero(allyNearbyEnemies[1])
				and Fu.IsChasingTarget(allyNearbyEnemies[1], allyHero)
				and not Fu.IsSuspiciousIllusion(allyNearbyEnemies[1])
			then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
return X
