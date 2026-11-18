-- How Rubick plays after stealing a spell from Crystal Maiden.
-- Accidental globals made file-local (#13): every bot shares one Lua state, so these were shared.
local CrystalCloneDesire, CrystalNovaDesire, CrystalNovaLocation, FrostbiteDesire, FrostbiteTarget, FreezingFieldDesire
local bot
local X = {}
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local crystalNovaAbility
local frostbiteAbility
local crystalCloneAbility
local freezingFieldAbility
local manaThreshold, mpRatio, hpRatio, botLevel
local lastShadowAmuletTime = 0
local botTarget
-- Handles of the other Crystal Maiden spells are nil unless Rubick stole that spell too.
local function IsStolenSpellReady(spell)
	return spell ~= nil and not spell:IsNull() and spell:IsFullyCastable()
end
function X.ConsiderStolenSpell(ability)
	bot = GetBot()
	if Fu.CanNotUseAbility(bot) then
		return
	end
	botTarget = Fu.GetProperTarget(bot)
	local abilityName = ability:GetName()
	manaThreshold = 220
	mpRatio = bot:GetMana() / bot:GetMaxMana()
	hpRatio = bot:GetHealth() / bot:GetMaxHealth()
	botLevel = bot:GetLevel()
	X.ConsiderCombo()
	if abilityName == "crystal_maiden_crystal_clone" then
		crystalCloneAbility = ability
		CrystalCloneDesire = X.ConsiderCrystalClone()
		if CrystalCloneDesire > 0 then
			bot:Action_UseAbility(crystalCloneAbility)
			return
		end
	end
	if abilityName == "crystal_maiden_crystal_nova" then
		crystalNovaAbility = ability
		CrystalNovaDesire, CrystalNovaLocation = X.ConsiderCrystalNova()
		if CrystalNovaDesire > 0 then
			bot:Action_UseAbilityOnLocation(crystalNovaAbility, CrystalNovaLocation)
			return
		end
	end
	if abilityName == "crystal_maiden_frostbite" then
		frostbiteAbility = ability
		FrostbiteDesire, FrostbiteTarget = X.ConsiderFrostbite()
		if FrostbiteDesire > 0 then
			bot:Action_UseAbilityOnEntity(frostbiteAbility, FrostbiteTarget)
			return
		end
	end
	if abilityName == "crystal_maiden_freezing_field" then
		freezingFieldAbility = ability
		FreezingFieldDesire = X.ConsiderFreezingField()
		if FreezingFieldDesire > 0 then
			bot:Action_UseAbility(freezingFieldAbility)
			return
		end
	end
end
function X.ConsiderCombo()
	if bot:IsAlive() and bot:IsChanneling() and not bot:IsInvisible() then
		local nearbyTowers = bot:GetNearbyTowers(880, true)
		if nearbyTowers[1] ~= nil then
			return
		end
		local shadowAmulet = Fu.IsItemAvailable("item_shadow_amulet")
		if shadowAmulet ~= nil and shadowAmulet:IsFullyCastable() and lastShadowAmuletTime < DotaTime() - 10 then
			lastShadowAmuletTime = DotaTime()
			bot:Action_UseAbilityOnEntity(shadowAmulet, bot)
			return
		end
		if not bot:HasModifier("modifier_teleporting") then
			local glimmerCape = Fu.IsItemAvailable("item_glimmer_cape")
			if glimmerCape ~= nil and glimmerCape:IsFullyCastable() then
				bot:Action_UseAbilityOnEntity(glimmerCape, bot)
				return
			end
			local shadowBlade = Fu.IsItemAvailable("item_invis_sword")
			if shadowBlade ~= nil and shadowBlade:IsFullyCastable() then
				bot:Action_UseAbility(shadowBlade)
				return
			end
			local silverEdge = Fu.IsItemAvailable("item_silver_edge")
			if silverEdge ~= nil and silverEdge:IsFullyCastable() then
				bot:Action_UseAbility(silverEdge)
				return
			end
		end
	end
end
function X.ConsiderCrystalNova()
	if not crystalNovaAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local radius = crystalNovaAbility:GetSpecialValueInt("radius")
	local castRange = Fu.GetProperCastRange(false, bot, crystalNovaAbility:GetCastRange())
	local damage = crystalNovaAbility:GetSpecialValueInt("nova_damage")
	local abilityLevel = crystalNovaAbility:GetLevel()
	local nearbyAllies = Fu.GetNearbyHeroes(bot, 1200, false, BOT_MODE_NONE)
	local enemiesInCastRange = Fu.GetNearbyHeroes(bot, castRange + radius, true, BOT_MODE_NONE)
	local enemiesNearCastRange = Fu.GetNearbyHeroes(bot, castRange + radius + 150, true, BOT_MODE_NONE)
	local nearbyEnemies = Fu.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE)
	local weakestEnemy, weakestEnemyHealth = X.cm_GetWeakestUnit(enemiesInCastRange)
	local weakestNearEnemy, weakestNearEnemyHealth = X.cm_GetWeakestUnit(enemiesNearCastRange)
	local laneCreepsInRange = bot:GetNearbyLaneCreeps(castRange + radius, true)
	local laneCreepsNearRange = bot:GetNearbyLaneCreeps(castRange + radius + 200, true)
	local weakestCreep, weakestCreepHealth = X.cm_GetWeakestUnit(laneCreepsInRange)
	local weakestNearCreep, weakestNearCreepHealth = X.cm_GetWeakestUnit(laneCreepsNearRange)
	local nearbyTowers = bot:GetNearbyTowers(1000, true)
	local heroKillAoe = bot:FindAoELocation(true, true, bot:GetLocation(), castRange, radius, 0.8, damage)
	local heroAoe = bot:FindAoELocation(true, true, bot:GetLocation(), castRange, radius, 0.8, 0)
	local creepKillAoe = bot:FindAoELocation(true, false, bot:GetLocation(), castRange + radius, radius, 0.5, damage)
	local creepAoe = bot:FindAoELocation(true, false, bot:GetLocation(), castRange + radius, radius, 0.5, 0)
	if heroKillAoe.count ~= nil and heroKillAoe.count >= 1 then
		if Fu.IsValid(weakestNearEnemy) then
			local castLocation = Fu.GetCastLocation(bot, weakestNearEnemy, castRange, radius)
			if castLocation ~= nil then
				return BOT_ACTION_DESIRE_HIGH, castLocation
			end
		end
	end
	if bot:GetActiveMode() == BOT_MODE_LANING and #nearbyTowers <= 0 and hpRatio >= 0.4 then
		if heroAoe.count >= 2 and GetUnitToLocationDistance(bot, heroAoe.targetloc) <= castRange + 50 then
			return BOT_ACTION_DESIRE_HIGH, heroAoe.targetloc
		end
	end
	if bot:GetActiveMode() == BOT_MODE_RETREAT and bot:WasRecentlyDamagedByAnyHero(2.0) then
		local retreatAoe = bot:FindAoELocation(true, true, bot:GetLocation(), castRange - 300, radius, 0.8, 0)
		if retreatAoe.count >= 1 then
			return BOT_ACTION_DESIRE_HIGH, retreatAoe.targetloc
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValid(weakestNearEnemy)
			and heroAoe.count >= 2
			and GetUnitToLocationDistance(bot, heroAoe.targetloc) <= castRange
		then
			return BOT_ACTION_DESIRE_HIGH, heroAoe.targetloc
		end
		local target = Fu.GetProperTarget(bot)
		if Fu.IsValidHero(target) and Fu.CanCastOnNonMagicImmune(target) then
			if mpRatio > 0.75 or bot:GetMana() > manaThreshold * 2 then
				local castLocation = Fu.GetCastLocation(bot, target, castRange, radius)
				if castLocation ~= nil then
					return BOT_ACTION_DESIRE_HIGH, castLocation
				end
			end
			if
				target:GetHealth() / target:GetMaxHealth() < 0.4
				and GetUnitToUnitDistance(target, bot) <= radius + castRange
			then
				local castLocation = Fu.GetCastLocation(bot, target, castRange, radius)
				if castLocation ~= nil then
					return BOT_ACTION_DESIRE_HIGH, castLocation
				end
			end
		end
		target = weakestEnemy
		if
			target ~= nil
			and target:IsAlive()
			and target:GetHealth() / target:GetMaxHealth() < 0.4
			and GetUnitToUnitDistance(target, bot) <= radius + castRange
		then
			local castLocation = Fu.GetCastLocation(bot, target, castRange, radius)
			if castLocation ~= nil then
				return BOT_ACTION_DESIRE_HIGH, castLocation
			end
		end
		if
			Fu.IsValid(weakestNearCreep)
			and creepAoe.count >= 5
			and #enemiesNearCastRange <= 0
			and bot:GetActiveMode() ~= BOT_MODE_ATTACK
			and abilityLevel >= 3
		then
			return BOT_ACTION_DESIRE_HIGH, creepAoe.targetloc
		end
		if
			creepKillAoe.count >= 3
			and (Fu.IsValid(weakestCreep) or botLevel >= 25)
			and #enemiesNearCastRange <= 0
			and bot:GetActiveMode() ~= BOT_MODE_ATTACK
			and abilityLevel >= 3
		then
			return BOT_ACTION_DESIRE_HIGH, creepKillAoe.targetloc
		end
	end
	if bot:GetActiveMode() ~= BOT_MODE_RETREAT then
		if Fu.IsValid(weakestNearEnemy) and weakestNearEnemy ~= nil then
			if heroAoe.count >= 3 and GetUnitToLocationDistance(bot, heroAoe.targetloc) <= castRange then
				return BOT_ACTION_DESIRE_VERYHIGH, heroAoe.targetloc
			end
			if
				heroAoe.count >= 2
				and GetUnitToLocationDistance(bot, heroAoe.targetloc) <= castRange
				and bot:GetMana() > manaThreshold
			then
				return BOT_ACTION_DESIRE_HIGH, heroAoe.targetloc
			end
			if Fu.IsValid(weakestNearEnemy) then
				if mpRatio > 0.8 or bot:GetMana() > manaThreshold * 2 then
					local castLocation = Fu.GetCastLocation(bot, weakestNearEnemy, castRange, radius)
					if castLocation ~= nil then
						return BOT_ACTION_DESIRE_HIGH, castLocation
					end
				end
				if
					weakestNearEnemy:GetHealth() / weakestNearEnemy:GetMaxHealth() < 0.4
					and GetUnitToUnitDistance(weakestNearEnemy, bot) <= radius + castRange
				then
					local castLocation = Fu.GetCastLocation(bot, weakestNearEnemy, castRange, radius)
					if castLocation ~= nil then
						return BOT_ACTION_DESIRE_HIGH, castLocation
					end
				end
			end
		end
	end
	if Fu.IsFarming(bot) and abilityLevel >= 3 then
		if creepKillAoe.count >= 2 and Fu.IsValid(weakestCreep) then
			return BOT_ACTION_DESIRE_HIGH, creepKillAoe.targetloc
		end
		if creepAoe.count >= 4 and Fu.IsValid(weakestCreep) then
			return BOT_ACTION_DESIRE_HIGH, creepAoe.targetloc
		end
	end
	if #nearbyAllies <= 2 and abilityLevel >= 3 and (Fu.IsPushing(bot) or Fu.IsDefending(bot)) then
		if creepAoe.count >= 4 and Fu.IsValid(weakestCreep) then
			return BOT_ACTION_DESIRE_HIGH, creepAoe.targetloc
		end
		if creepKillAoe.count >= 2 and Fu.IsValid(weakestCreep) then
			return BOT_ACTION_DESIRE_HIGH, creepKillAoe.targetloc
		end
	end
	if bot:GetActiveMode() == BOT_MODE_ROSHAN and bot:GetMana() >= 400 then
		local attackTarget = bot:GetAttackTarget()
		if Fu.IsRoshan(attackTarget) and Fu.IsAttacking(bot) then
			return BOT_ACTION_DESIRE_HIGH, attackTarget:GetLocation()
		end
	end
	if Fu.IsDoingTormentor(bot) and bot:GetMana() >= 400 then
		local attackTarget = bot:GetAttackTarget()
		if Fu.IsTormentor(attackTarget) and Fu.IsAttacking(bot) then
			return BOT_ACTION_DESIRE_HIGH, attackTarget:GetLocation()
		end
	end
	local nearbyNeutrals = bot:GetNearbyNeutralCreeps(castRange + radius)
	if Fu.IsValid(nearbyNeutrals[1]) then
		for _, neutral in pairs(nearbyNeutrals) do
			if
				Fu.IsValid(neutral)
				and neutral:HasModifier("modifier_crystal_maiden_frostbite")
				and neutral:GetHealth() / neutral:GetMaxHealth() > 0.3
				and (
					neutral:GetUnitName() == "npc_dota_neutral_dark_troll_warlord"
					or neutral:GetUnitName() == "npc_dota_neutral_satyr_hellcaller"
					or neutral:GetUnitName() == "npc_dota_neutral_polar_furbolg_ursa_warrior"
				)
			then
				local castLocation = Fu.GetCastLocation(bot, neutral, castRange, radius)
				if castLocation ~= nil then
					return BOT_ACTION_DESIRE_HIGH, castLocation
				end
			end
		end
	end
	if #nearbyEnemies == 0 and not Fu.IsGoingOnSomeone(bot) and abilityLevel > 2 then
		if creepKillAoe.count >= 2 and (weakestNearCreep ~= nil or botLevel == 25) then
			return BOT_ACTION_DESIRE_HIGH, creepKillAoe.targetloc
		end
		if creepAoe.count >= 4 and weakestNearCreep ~= nil then
			return BOT_ACTION_DESIRE_HIGH, creepAoe.targetloc
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.ConsiderFrostbite()
	if not frostbiteAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local castRange = Fu.GetProperCastRange(false, bot, frostbiteAbility:GetCastRange())
	local castPoint = frostbiteAbility:GetCastPoint()
	local abilityLevel = frostbiteAbility:GetLevel()
	local damage = 100 + abilityLevel * 50
	local nearbyAllies = Fu.GetNearbyHeroes(bot, 1200, false, BOT_MODE_NONE)
	local nearbyEnemies = Fu.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE)
	if #nearbyEnemies <= 1 and castRange < bot:GetAttackRange() then
		castRange = bot:GetAttackRange() + 60
	end
	local enemiesInCastRange = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	local enemiesNearCastRange = Fu.GetNearbyHeroes(bot, castRange + 200, true, BOT_MODE_NONE)
	local weakestEnemy, weakestEnemyHealth = X.cm_GetWeakestUnit(enemiesInCastRange)
	local weakestNearEnemy, weakestNearEnemyHealth = X.cm_GetWeakestUnit(enemiesNearCastRange)
	local creepsInRange = bot:GetNearbyCreeps(castRange + 100, true)
	local nearbyCreeps = bot:GetNearbyCreeps(1400, true)
	local strongestCreep, strongestCreepHealth = X.cm_GetStrongestUnit(creepsInRange)
	local strongestNearbyCreep, strongestNearbyCreepHealth = X.cm_GetStrongestUnit(nearbyCreeps)
	local nearbyTowers = bot:GetNearbyTowers(900, true)
	if Fu.IsValid(weakestEnemy) and Fu.CanCastOnTargetAdvanced(weakestEnemy) then
		if Fu.WillMagicKillTarget(bot, weakestEnemy, damage, castPoint) then
			return BOT_ACTION_DESIRE_HIGH, weakestEnemy
		end
	end
	for _, enemyHero in pairs(enemiesNearCastRange) do
		if
			Fu.IsValid(enemyHero)
			and enemyHero:IsChanneling()
			and enemyHero:HasModifier("modifier_teleporting")
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and Fu.CanCastOnTargetAdvanced(enemyHero)
		then
			return BOT_ACTION_DESIRE_HIGH, enemyHero
		end
	end
	if Fu.IsInTeamFight(bot, 1200) and DotaTime() > 6 * 60 then
		local mostDangerousEnemy = nil
		local highestDamage = 0
		local fightEnemies = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
		for _, enemyHero in pairs(fightEnemies) do
			if
				Fu.IsValid(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
				and not Fu.IsDisabled(enemyHero)
				and not enemyHero:IsDisarmed()
			then
				local estimatedDamage = enemyHero:GetEstimatedDamageToTarget(false, bot, 3.0, DAMAGE_TYPE_PHYSICAL)
				if estimatedDamage > highestDamage then
					highestDamage = estimatedDamage
					mostDangerousEnemy = enemyHero
				end
			end
		end
		if mostDangerousEnemy ~= nil then
			return BOT_ACTION_DESIRE_HIGH, mostDangerousEnemy
		end
	end
	if bot:WasRecentlyDamagedByAnyHero(3.0) and #enemiesInCastRange >= 1 then
		for _, enemyHero in pairs(enemiesInCastRange) do
			if
				Fu.IsValid(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
				and not Fu.IsDisabled(enemyHero)
				and not enemyHero:IsDisarmed()
				and bot:IsFacingLocation(enemyHero:GetLocation(), 45)
			then
				return BOT_ACTION_DESIRE_HIGH, enemyHero
			end
		end
	end
	if bot:GetActiveMode() == BOT_MODE_LANING and #nearbyTowers == 0 then
		if mpRatio > 0.5 or bot:GetMana() > manaThreshold then
			if Fu.IsValid(weakestEnemy) and not Fu.IsDisabled(weakestEnemy) then
				return BOT_ACTION_DESIRE_HIGH, weakestEnemy
			end
		end
		if mpRatio > 0.78 or bot:GetMana() > manaThreshold then
			if
				Fu.IsValid(weakestNearEnemy)
				and weakestNearEnemy ~= nil
				and hpRatio > 0.6
				and #nearbyTowers == 0
				and #nearbyCreeps + #enemiesNearCastRange <= 5
				and not Fu.IsDisabled(weakestNearEnemy)
				and weakestNearEnemy:GetCurrentMovementSpeed() < bot:GetCurrentMovementSpeed()
			then
				return BOT_ACTION_DESIRE_HIGH, weakestNearEnemy
			end
		end
		if Fu.IsValid(nearbyEnemies[1]) then
			if
				Fu.GetAllyUnitCountAroundEnemyTarget(bot, nearbyEnemies[1], 350) >= 5
				and not Fu.IsDisabled(nearbyEnemies[1])
				and not nearbyEnemies[1]:IsMagicImmune()
				and hpRatio > 0.7
				and bot:GetMana() > manaThreshold
				and #nearbyCreeps + #enemiesNearCastRange <= 3
				and #nearbyTowers == 0
			then
				return BOT_ACTION_DESIRE_HIGH, nearbyEnemies[1]
			end
		end
		if Fu.IsValid(weakestEnemy) and weakestEnemy ~= nil then
			if weakestEnemy:GetHealth() / weakestEnemy:GetMaxHealth() < 0.5 then
				return BOT_ACTION_DESIRE_HIGH, weakestEnemy
			end
		end
	end
	if enemiesInCastRange[1] == nil and creepsInRange[1] ~= nil then
		for _, creep in pairs(creepsInRange) do
			if
				Fu.IsValid(creep)
				and creep:GetTeam() == GetOpposingTeam()
				and creep:GetHealth() > 460
				and not creep:IsMagicImmune()
				and not creep:IsInvulnerable()
				and (creep:IsDominated() or creep:IsMinion())
			then
				return BOT_ACTION_DESIRE_HIGH, creep
			end
		end
	end
	if
		bot:GetActiveMode() ~= BOT_MODE_LANING
		and bot:GetActiveMode() ~= BOT_MODE_RETREAT
		and bot:GetActiveMode() ~= BOT_MODE_ATTACK
		and #nearbyEnemies == 0
		and #nearbyAllies < 3
		and botLevel >= 5
	then
		if
			Fu.IsValid(strongestNearbyCreep)
			and strongestNearbyCreep ~= nil
			and (
				DotaTime() > 10 * 60
				or strongestNearbyCreep:GetUnitName() ~= "npc_dota_creep_badguys_melee"
					and strongestNearbyCreep:GetUnitName() ~= "npc_dota_creep_badguys_ranged"
					and strongestNearbyCreep:GetUnitName() ~= "npc_dota_creep_goodguys_melee"
					and strongestNearbyCreep:GetUnitName() ~= "npc_dota_creep_goodguys_ranged"
			)
		then
			if
				(strongestNearbyCreepHealth > 460 or strongestCreepHealth > 390 and mpRatio > 0.45)
				and strongestNearbyCreepHealth <= 1200
			then
				return BOT_ACTION_DESIRE_LOW, strongestNearbyCreep
			end
		end
		if
			Fu.IsValid(strongestCreep)
			and strongestCreep ~= nil
			and (
				DotaTime() > 10 * 60
				or strongestCreep:GetUnitName() ~= "npc_dota_creep_badguys_melee"
					and strongestCreep:GetUnitName() ~= "npc_dota_creep_badguys_ranged"
					and strongestCreep:GetUnitName() ~= "npc_dota_creep_goodguys_melee"
					and strongestCreep:GetUnitName() ~= "npc_dota_creep_goodguys_ranged"
			)
		then
			if
				(strongestCreepHealth > 410 or strongestCreepHealth > 360 and mpRatio > 0.45)
				and strongestCreepHealth <= 1200
			then
				return BOT_ACTION_DESIRE_LOW, strongestCreep
			end
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		local target = Fu.GetProperTarget(bot)
		if
			Fu.IsValidHero(target)
			and Fu.CanCastOnNonMagicImmune(target)
			and Fu.CanCastOnTargetAdvanced(target)
			and Fu.IsInRange(target, bot, castRange + 50)
			and not Fu.IsDisabled(target)
			and not target:IsDisarmed()
		then
			return BOT_ACTION_DESIRE_HIGH, target
		end
	end
	if Fu.IsRetreating(bot) then
		for _, enemyHero in pairs(enemiesInCastRange) do
			if
				Fu.IsValid(enemyHero)
				and bot:WasRecentlyDamagedByHero(enemyHero, 5.0)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
				and not Fu.IsDisabled(enemyHero)
				and Fu.IsInRange(enemyHero, bot, castRange - 80)
			then
				return BOT_ACTION_DESIRE_HIGH, enemyHero
			end
		end
	end
	if bot:GetActiveMode() == BOT_MODE_ROSHAN and bot:GetMana() >= 400 then
		local attackTarget = bot:GetAttackTarget()
		if
			Fu.IsRoshan(attackTarget)
			and not Fu.IsDisabled(attackTarget)
			and not attackTarget:IsDisarmed()
			and Fu.IsInRange(attackTarget, bot, castRange)
		then
			return BOT_ACTION_DESIRE_HIGH, attackTarget
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.ConsiderFreezingField()
	if not freezingFieldAbility:IsFullyCastable() or bot:DistanceFromFountain() < 300 then
		return BOT_ACTION_DESIRE_NONE
	end
	local radius = freezingFieldAbility:GetAOERadius() * 0.88
	local nearbyAllies = Fu.GetNearbyHeroes(bot, 1200, false, BOT_MODE_NONE)
	local enemiesInRadius = Fu.GetNearbyHeroes(bot, radius, true, BOT_MODE_NONE)
	local weakestEnemy, weakestEnemyHealth = X.cm_GetWeakestUnit(enemiesInRadius)
	local enemiesCaught = 0
	for _, enemyHero in pairs(enemiesInRadius) do
		if
			Fu.IsValid(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and (
				Fu.IsDisabled(enemyHero)
				or Fu.IsInRange(bot, enemyHero, radius * 0.82 - enemyHero:GetCurrentMovementSpeed())
			)
		then
			enemiesCaught = enemiesCaught + 1
		end
	end
	if
		bot:GetActiveMode() ~= BOT_MODE_RETREAT
		or bot:GetActiveMode() == BOT_MODE_RETREAT and bot:GetActiveModeDesire() <= 0.85
	then
		if #enemiesInRadius >= 3 or enemiesCaught >= 2 then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		local target = Fu.GetProperTarget(bot)
		if
			Fu.IsValidHero(target)
			and Fu.CanCastOnNonMagicImmune(target)
			and (Fu.IsDisabled(target) or Fu.IsInRange(bot, target, 280))
			and target:GetHealth() <= target:GetActualIncomingDamage(bot:GetOffensivePower() * 1.5, DAMAGE_TYPE_MAGICAL)
			and GetUnitToUnitDistance(target, bot) <= radius
			and target:GetHealth() > 400
			and #nearbyAllies <= 2
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsRetreating(bot) and hpRatio > 0.38 then
		local closeEnemies = Fu.GetNearbyHeroes(bot, 500, true, BOT_MODE_NONE)
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, 1300, true, BOT_MODE_NONE)
		local chaser = closeEnemies[1]
		if
			Fu.IsValidHero(chaser)
			and Fu.CanCastOnNonMagicImmune(chaser)
			-- fix: abilityQ/abilityW were undefined globals (Crystal Nova / Frostbite in hero_crystal_maiden.lua)
			and not IsStolenSpellReady(crystalNovaAbility)
			and not IsStolenSpellReady(frostbiteAbility)
			and hpRatio > 0.38 * #nearbyEnemies
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderCrystalClone()
	if not crystalCloneAbility:IsTrained() or not crystalCloneAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
	end
	local attackRange = bot:GetAttackRange()
	if
		Fu.IsRetreating(bot)
		and not Fu.IsRealInvisible(bot)
		and not bot:IsFacingLocation(GetAncient(GetTeam()):GetLocation(), 45)
		and not Fu.IsRealInvisible(bot)
		and bot:DistanceFromFountain() > 600
		and bot:WasRecentlyDamagedByAnyHero(4.0)
	then
		return BOT_ACTION_DESIRE_MODERATE
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidHero(botTarget)
			and Fu.IsInRange(bot, botTarget, attackRange - 150)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and bot:IsFacingLocation(botTarget:GetLocation(), 30)
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.cm_GetWeakestUnit(units)
	local weakestUnit = nil
	local weakestHealth = 10000
	for _, unit in pairs(units) do
		if Fu.CanCastOnNonMagicImmune(unit) then
			if unit:GetHealth() < weakestHealth then
				weakestHealth = unit:GetHealth()
				weakestUnit = unit
			end
		end
	end
	return weakestUnit, weakestHealth
end
function X.cm_GetStrongestUnit(units)
	local strongestUnit = nil
	local strongestHealth = GetBot():GetAttackDamage()
	for _, unit in pairs(units) do
		if
			unit ~= nil
			and unit:IsAlive()
			and not unit:HasModifier("modifier_fountain_glyph")
			and not unit:IsMagicImmune()
			and not unit:IsInvulnerable()
			and unit:GetHealth() <= 1100
			and not unit:IsAncientCreep()
			and unit:GetMagicResist() < 1.05 - unit:GetHealth() / 1100
			and not Fu.IsOtherAllysTarget(unit)
			and string.find(unit:GetUnitName(), "siege") == nil
			and (botLevel < 25 or unit:GetTeam() == TEAM_NEUTRAL)
		then
			if
				string.find(unit:GetUnitName(), "ranged") ~= nil
				and unit:GetHealth() > GetBot():GetAttackDamage() * 2
			then
				return unit, 500
			end
			if unit:GetHealth() > strongestHealth then
				strongestHealth = unit:GetHealth()
				strongestUnit = unit
			end
		end
	end
	return strongestUnit, strongestHealth
end
return X
