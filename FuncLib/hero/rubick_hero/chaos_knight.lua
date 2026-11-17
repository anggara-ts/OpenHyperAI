-- How Rubick plays after stealing a spell from Chaos Knight.
local bot
local X = {}
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local chaosBoltAbility
local realityRiftAbility
local phantasmAbility
local hpRatio, nearbyEnemies
local botTarget
function X.ConsiderStolenSpell(stolenAbility)
	bot = GetBot()
	if Fu.CanNotUseAbility(bot) then
		return
	end
	botTarget = Fu.GetProperTarget(bot)
	local abilityName = stolenAbility:GetName()
	hpRatio = bot:GetHealth() / bot:GetMaxHealth()
	nearbyEnemies = Fu.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE)
	if abilityName == "chaos_knight_phantasm" then
		phantasmAbility = stolenAbility
		PhantasmDesire = X.ConsiderPhantasm()
		if PhantasmDesire > 0 then
			bot:ActionQueue_UseAbility(phantasmAbility)
			return
		end
	end
	if abilityName == "chaos_knight_reality_rift" then
		realityRiftAbility = stolenAbility
		RealityRiftDesire, RealityRiftTarget = X.ConsiderRealityRift()
		if RealityRiftDesire > 0 then
			bot:Action_UseAbilityOnEntity(realityRiftAbility, RealityRiftTarget)
			return
		end
	end
	if abilityName == "chaos_knight_chaos_bolt" then
		chaosBoltAbility = stolenAbility
		ChaosBoltDesire, ChaosBoltTarget = X.ConsiderChaosBolt()
		if ChaosBoltDesire > 0 then
			bot:Action_UseAbilityOnEntity(chaosBoltAbility, ChaosBoltTarget)
			return
		end
	end
end
function X.ConsiderChaosBolt()
	if not chaosBoltAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
	end
	local castRange = Fu.GetProperCastRange(false, bot, chaosBoltAbility:GetCastRange())
	local abilityLevel = chaosBoltAbility:GetLevel()
	local damage = 30 + abilityLevel * 30 + 120 * 0.38
	local enemiesInRange = Fu.GetNearbyHeroes(bot, castRange + 99, true, BOT_MODE_NONE)
	local nearbyEnemyHeroes = Fu.GetNearbyHeroes(bot, 880, true, BOT_MODE_NONE)
	if #enemiesInRange > 0 then
		for i = 1, #enemiesInRange do
			if
				Fu.IsValid(enemiesInRange[i])
				and Fu.CanCastOnNonMagicImmune(enemiesInRange[i])
				and Fu.CanCastOnTargetAdvanced(enemiesInRange[i])
				and enemiesInRange[i]:GetHealth() < enemiesInRange[i]:GetActualIncomingDamage(
					damage,
					DAMAGE_TYPE_MAGICAL
				)
				and GetUnitToUnitDistance(enemiesInRange[i], bot) > bot:GetAttackRange() + 60
				and not Fu.IsDisabled(enemiesInRange[i])
			then
				return BOT_ACTION_DESIRE_HIGH, enemiesInRange[i]
			end
		end
	end
	if #nearbyEnemyHeroes > 0 then
		for i = 1, #nearbyEnemyHeroes do
			if
				Fu.IsValid(nearbyEnemyHeroes[i])
				and Fu.CanCastOnNonMagicImmune(nearbyEnemyHeroes[i])
				and Fu.CanCastOnTargetAdvanced(nearbyEnemyHeroes[i])
				and nearbyEnemyHeroes[i]:IsChanneling()
			then
				return BOT_ACTION_DESIRE_HIGH, nearbyEnemyHeroes[i]
			end
		end
	end
	if Fu.IsInTeamFight(bot, 1200) and DotaTime() > 4 * 60 then
		local strongestEnemy = nil
		local maxDamage = 0
		for _, enemyHero in pairs(enemiesInRange) do
			if
				Fu.IsValid(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
				and not Fu.IsDisabled(enemyHero)
				and not enemyHero:IsDisarmed()
			then
				local estimatedDamage = enemyHero:GetEstimatedDamageToTarget(false, bot, 3.0, DAMAGE_TYPE_ALL)
				if estimatedDamage > maxDamage then
					maxDamage = estimatedDamage
					strongestEnemy = enemyHero
				end
			end
		end
		if strongestEnemy ~= nil then
			return BOT_ACTION_DESIRE_HIGH, strongestEnemy
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		local target = Fu.GetProperTarget(bot)
		if
			Fu.IsValidHero(target)
			and Fu.CanCastOnNonMagicImmune(target)
			and Fu.CanCastOnTargetAdvanced(target)
			and Fu.IsInRange(target, bot, castRange)
			and not Fu.IsDisabled(target)
			and not target:IsDisarmed()
		then
			return BOT_ACTION_DESIRE_HIGH, target
		end
	end
	if Fu.IsRetreating(bot) then
		if
			Fu.IsValid(enemiesInRange[1])
			and Fu.CanCastOnNonMagicImmune(enemiesInRange[1])
			and Fu.CanCastOnTargetAdvanced(enemiesInRange[1])
			and not Fu.IsDisabled(enemiesInRange[1])
			and not enemiesInRange[1]:IsDisarmed()
			and GetUnitToUnitDistance(bot, enemiesInRange[1]) <= castRange - 60
		then
			return BOT_ACTION_DESIRE_HIGH, enemiesInRange[1]
		end
	end
	if bot:GetActiveMode() == BOT_MODE_ROSHAN and bot:GetMana() > 400 then
		local attackTarget = bot:GetAttackTarget()
		if
			attackTarget ~= nil
			and attackTarget:IsAlive()
			and Fu.GetHP(attackTarget) > 0.2
			and not Fu.IsDisabled(attackTarget)
			and not attackTarget:IsDisarmed()
		then
			return BOT_ACTION_DESIRE_LOW, attackTarget
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderRealityRift()
	if not realityRiftAbility:IsFullyCastable() or bot:IsRooted() then
		return BOT_ACTION_DESIRE_NONE
	end
	local castRange = Fu.GetProperCastRange(false, bot, realityRiftAbility:GetCastRange())
	if Fu.IsGoingOnSomeone(bot) then
		local target = Fu.GetProperTarget(bot)
		if
			Fu.IsValidHero(target)
			and Fu.IsInRange(target, bot, castRange + 50)
			and (not Fu.IsInRange(bot, target, 200) or not target:HasModifier("modifier_chaos_knight_reality_rift"))
			and Fu.CanCastOnNonMagicImmune(target)
			and Fu.CanCastOnTargetAdvanced(target)
			and not Fu.IsDisabled(target)
		then
			return BOT_ACTION_DESIRE_HIGH, target
		end
	end
	if Fu.IsRetreating(bot) then
		local chasingEnemies = Fu.GetNearbyHeroes(bot, 800, true, BOT_MODE_NONE)
		local laneCreeps = bot:GetNearbyLaneCreeps(castRange, true)
		if chasingEnemies[1] ~= nil and laneCreeps[1] ~= nil then
			for _, creep in pairs(laneCreeps) do
				if
					chasingEnemies[1]:IsFacingLocation(bot:GetLocation(), 30)
					and bot:IsFacingLocation(creep:GetLocation(), 30)
					and GetUnitToUnitDistance(bot, creep) >= 650
				then
					return BOT_ACTION_DESIRE_LOW, creep
				end
			end
		end
	end
	if nearbyEnemies[1] == nil and bot:GetAttackDamage() >= 150 then
		local enemyCreeps = bot:GetNearbyLaneCreeps(1000, true)
		for i = 1, #enemyCreeps do
			local creep = enemyCreeps[#enemyCreeps - i + 1]
			if
				Fu.IsValid(creep)
				and not creep:HasModifier("modifier_fountain_glyph")
				and Fu.IsKeyWordUnit("ranged", creep)
				and GetUnitToUnitDistance(bot, creep) >= 350
			then
				return BOT_ACTION_DESIRE_LOW, creep
			end
		end
	end
	if bot:GetActiveMode() == BOT_MODE_ROSHAN and bot:GetMana() > 400 then
		local attackTarget = bot:GetAttackTarget()
		if attackTarget ~= nil and not Fu.IsDisabled(attackTarget) and not attackTarget:IsDisarmed() then
			return BOT_ACTION_DESIRE_LOW, attackTarget
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderPhantasm()
	if not phantasmAbility:IsFullyCastable() or bot:DistanceFromFountain() < 500 then
		return BOT_ACTION_DESIRE_NONE
	end
	local enemyList = Fu.GetEnemyList(bot, 1600)
	local enemyTowers = bot:GetNearbyTowers(700, true)
	local enemyBarracks = bot:GetNearbyBarracks(400, true)
	local allyCreeps = bot:GetNearbyLaneCreeps(1000, false)
	local castRange = 900
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidHero(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and Fu.CanCastOnMagicImmune(botTarget)
			and (Fu.GetHP(botTarget) > 0.5 or hpRatio < 0.7 or #enemyList >= 2)
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsInTeamFight(bot, 1200) then
		if #enemyList >= 2 then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsPushing(bot) and DotaTime() > 8 * 30 then
		if (#enemyTowers >= 1 or #enemyBarracks >= 1) and #allyCreeps >= 2 then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if
		bot:GetActiveMode() == BOT_MODE_RETREAT
		and hpRatio >= 0.5
		and Fu.IsValidHero(enemyList[1])
		and GetUnitToUnitDistance(bot, enemyList[1]) <= 700
	then
		return BOT_ACTION_DESIRE_HIGH
	end
	return BOT_ACTION_DESIRE_NONE
end
return X
