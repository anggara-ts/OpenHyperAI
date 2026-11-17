-- How Rubick plays after stealing a spell from Broodmother.
local bot = GetBot()
local X = {}
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local insatiableHungerAbility
local spinWebAbility
local silkenBolaAbility
local spawnSpiderlingsAbility
local botTarget
function X.ConsiderStolenSpell(ability)
	bot = GetBot()
	if Fu.CanNotUseAbility(bot) then
		return
	end
	botTarget = Fu.GetProperTarget(bot)
	local abilityName = ability:GetName()
	if abilityName == "broodmother_spawn_spiderlings" then
		spawnSpiderlingsAbility = ability
		SpawnSpiderlingsDesire, SpirderlingsTarget = X.ConsiderSpawnSpiderlings()
		if SpawnSpiderlingsDesire > 0 then
			bot:Action_UseAbilityOnEntity(spawnSpiderlingsAbility, SpirderlingsTarget)
			return
		end
	end
	if abilityName == "broodmother_spin_web" then
		spinWebAbility = ability
		SpinWebDesire, SpinWebLocation = X.ConsiderSpinWeb()
		if SpinWebDesire > 0 then
			bot:Action_UseAbilityOnLocation(spinWebAbility, SpinWebLocation)
			return
		end
	end
	if abilityName == "broodmother_silken_bola" then
		silkenBolaAbility = ability
		SilkenBolaDesire, SilkenBolaTarget = X.ConsiderSilkenBola()
		if SilkenBolaDesire > 0 then
			bot:Action_UseAbilityOnEntity(silkenBolaAbility, SilkenBolaTarget)
			return
		end
	end
	if abilityName == "broodmother_insatiable_hunger" then
		insatiableHungerAbility = ability
		InsatiableHungerDesire = X.ConsiderInsatiableHunger()
		if InsatiableHungerDesire > 0 then
			bot:Action_UseAbility(insatiableHungerAbility)
			return
		end
	end
end
function X.ConsiderInsatiableHunger()
	if not insatiableHungerAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
	end
	local attackRange = bot:GetAttackRange()
	if Fu.IsInTeamFight(bot, 1200) then
		local nearbyEnemies = Fu.GetEnemiesNearLoc(bot:GetLocation(), 1200)
		if nearbyEnemies ~= nil and #nearbyEnemies >= 2 and Fu.GetHP(bot) < 0.75 and Fu.IsAttacking(bot) then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidTarget(botTarget)
			and Fu.IsInRange(bot, botTarget, attackRange + 150)
			and Fu.IsAttacking(bot)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not Fu.IsDisabled(botTarget)
			and not botTarget:HasModifier("modifier_abaddon_borrowed_time")
			and not botTarget:HasModifier("modifier_dazzle_shallow_grave")
			and not botTarget:HasModifier("modifier_faceless_void_chronosphere_freeze")
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
			and not botTarget:HasModifier("modifier_oracle_false_promise_timer")
			and not botTarget:HasModifier("modifier_templar_assassin_refraction_absorb")
		then
			local alliesNearTarget = Fu.GetNearbyHeroes(botTarget, 1200, true, BOT_MODE_NONE)
			local enemiesNearTarget = Fu.GetNearbyHeroes(botTarget, 1200, false, BOT_MODE_NONE)
			if alliesNearTarget ~= nil and enemiesNearTarget ~= nil and #alliesNearTarget >= #enemiesNearTarget then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	if Fu.IsFarming(bot) then
		local nearbyCreeps = bot:GetNearbyCreeps(700, true)
		if nearbyCreeps ~= nil and #nearbyCreeps > 0 and Fu.GetHP(bot) < 0.4 and Fu.IsAttacking(bot) then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if Fu.IsRoshan(botTarget) and Fu.IsInRange(bot, botTarget, 500) and Fu.IsAttacking(bot) then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, 500) and Fu.IsAttacking(bot) then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderSpinWeb()
	if not spinWebAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local castRange = Fu.GetProperCastRange(false, bot, spinWebAbility:GetCastRange())
	local radius = spinWebAbility:GetSpecialValueInt("radius")
	local nearbyLaneCreeps = bot:GetNearbyLaneCreeps(castRange, true)
	local nearbyTowers = bot:GetNearbyTowers(castRange, true)
	if Fu.IsStuck(bot) and not X.DoesLocationHaveWeb(bot:GetLocation(), radius) then
		return BOT_ACTION_DESIRE_HIGH, bot:GetLocation()
	end
	if Fu.IsInTeamFight(bot, 1200) then
		local aoeLocation = bot:FindAoELocation(true, true, bot:GetLocation(), castRange, radius, 0, 0)
		local enemiesInRadius = Fu.GetEnemiesNearLoc(aoeLocation.targetloc, radius / 1.7)
		if
			enemiesInRadius ~= nil
			and #enemiesInRadius >= 2
			and not X.DoesLocationHaveWeb(aoeLocation.targetloc, radius)
			and not Fu.IsLocationInChrono(aoeLocation.targetloc)
			and not Fu.IsLocationInBlackHole(aoeLocation.targetloc)
		then
			return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidTarget(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not Fu.IsDisabled(botTarget)
			and not botTarget:HasModifier("modifier_abaddon_borrowed_time")
			and not botTarget:HasModifier("modifier_dazzle_shallow_grave")
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
			and not botTarget:HasModifier("modifier_oracle_false_promise_timer")
			and not X.DoesLocationHaveWeb(botTarget:GetLocation(), radius)
			and not Fu.IsLocationInChrono(botTarget:GetLocation())
			and not Fu.IsLocationInBlackHole(botTarget:GetLocation())
		then
			local alliesNearTarget = Fu.GetNearbyHeroes(botTarget, 1200, true, BOT_MODE_NONE)
			local enemiesNearTarget = Fu.GetNearbyHeroes(botTarget, 1200, false, BOT_MODE_NONE)
			if alliesNearTarget ~= nil and enemiesNearTarget ~= nil and #alliesNearTarget >= #enemiesNearTarget then
				return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
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
			and not X.DoesLocationHaveWeb(bot:GetLocation(), radius)
		then
			local enemiesNearChaser = Fu.GetNearbyHeroes(nearbyEnemies[1], 1200, false, BOT_MODE_NONE)
			if
				enemiesNearChaser ~= nil
				and (#enemiesNearChaser > #nearbyAllies or bot:WasRecentlyDamagedByAnyHero(1.5))
			then
				return BOT_ACTION_DESIRE_HIGH, bot:GetLocation()
			end
		end
	end
	if Fu.IsPushing(bot) then
		if
			nearbyLaneCreeps ~= nil
			and #nearbyLaneCreeps >= 4
			and not X.DoesLocationHaveWeb(Fu.GetCenterOfUnits(nearbyLaneCreeps), radius)
		then
			return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(nearbyLaneCreeps)
		end
		if
			nearbyTowers ~= nil
			and #nearbyTowers >= 1
			and Fu.CanBeAttacked(nearbyTowers[1])
			and not X.DoesLocationHaveWeb(nearbyTowers[1]:GetLocation(), radius)
		then
			return BOT_ACTION_DESIRE_HIGH, nearbyTowers[1]:GetLocation()
		end
	end
	if Fu.IsLaning(bot) then
		if
			nearbyLaneCreeps ~= nil
			and #nearbyLaneCreeps >= 4
			and not X.DoesLocationHaveWeb(Fu.GetCenterOfUnits(nearbyLaneCreeps), radius)
		then
			return BOT_MODE_DESIRE_HIGH, Fu.GetCenterOfUnits(nearbyLaneCreeps)
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if
			Fu.IsRoshan(botTarget)
			and Fu.IsInRange(bot, botTarget, 500)
			and Fu.IsAttacking(bot)
			and not X.DoesLocationHaveWeb(botTarget:GetLocation(), radius)
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if
			Fu.IsTormentor(botTarget)
			and Fu.IsInRange(bot, botTarget, 500)
			and Fu.IsAttacking(bot)
			and not X.DoesLocationHaveWeb(botTarget:GetLocation(), radius)
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.ConsiderSilkenBola()
	if not silkenBolaAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castRange = Fu.GetProperCastRange(false, bot, silkenBolaAbility:GetCastRange())
	local damage = silkenBolaAbility:GetSpecialValueInt("impact_damage")
	local nearbyEnemies = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
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
			return BOT_ACTION_DESIRE_HIGH, enemyHero
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidTarget(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not botTarget:HasModifier("modifier_abaddon_borrowed_time")
			and not botTarget:HasModifier("modifier_dazzle_shallow_grave")
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
			and not botTarget:HasModifier("modifier_oracle_false_promise_timer")
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
		if
			nearbyAllies ~= nil
			and nearbyEnemies ~= nil
			and Fu.IsValidHero(nearbyEnemies[1])
			and Fu.IsInRange(bot, nearbyEnemies[1], castRange)
			and Fu.IsChasingTarget(nearbyEnemies[1], bot)
			and not Fu.IsSuspiciousIllusion(nearbyEnemies[1])
			and not nearbyEnemies[1]:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			local enemiesNearChaser = Fu.GetNearbyHeroes(nearbyEnemies[1], 1200, false, BOT_MODE_NONE)
			if
				enemiesNearChaser ~= nil
				and (#enemiesNearChaser > #nearbyAllies or bot:WasRecentlyDamagedByAnyHero(1.5))
			then
				return BOT_ACTION_DESIRE_HIGH, nearbyEnemies[1]
			end
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if Fu.IsRoshan(botTarget) and Fu.IsInRange(bot, botTarget, 500) and Fu.IsAttacking(bot) then
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, 500) and Fu.IsAttacking(bot) then
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end
	local allyHeroes = Fu.GetNearbyHeroes(bot, castRange, false, BOT_MODE_NONE)
	for _, allyHero in pairs(allyHeroes) do
		local enemiesNearAlly = Fu.GetNearbyHeroes(allyHero, 1200, true, BOT_MODE_NONE)
		if
			Fu.IsValidHero(allyHero)
			and Fu.IsRetreating(allyHero)
			and Fu.GetMP(bot) > 0.45
			and allyHero:WasRecentlyDamagedByAnyHero(1.5)
			and not allyHero:IsIllusion()
		then
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
	return BOT_ACTION_DESIRE_NONE, nil
end
function X.ConsiderSpawnSpiderlings()
	if not spawnSpiderlingsAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local castRange = Fu.GetProperCastRange(false, bot, spawnSpiderlingsAbility:GetCastRange())
	local damage = spawnSpiderlingsAbility:GetSpecialValueInt("damage")
	local nearbyEnemies = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
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
			return BOT_ACTION_DESIRE_HIGH, enemyHero
		end
	end
	local nearbyLaneCreeps = bot:GetNearbyLaneCreeps(castRange, true)
	for _, creep in pairs(nearbyLaneCreeps) do
		if
			Fu.IsValid(creep)
			and Fu.CanBeAttacked(creep)
			and Fu.CanKillTarget(creep, damage, DAMAGE_TYPE_MAGICAL)
			and not Fu.IsRetreating(bot)
		then
			return BOT_ACTION_DESIRE_HIGH, creep
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.DoesLocationHaveWeb(location, radius)
	for _, unit in pairs(GetUnitList(UNIT_LIST_ALLIES)) do
		if
			Fu.IsValid(unit)
			and unit:GetUnitName() == "npc_dota_broodmother_web"
			and GetUnitToLocationDistance(unit, location) < radius
		then
			return true
		end
	end
	return false
end
return X
