-- Thinking for summoned units: familiars.
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local MinionUtils = require(GetScriptDirectory() .. "/FuncLib/hero/minion_lib/utils")
local X = {}
local bot
local stoneFormAbility
local isAttackingCreepsOrTowers = false
function X.Think(ownerBot, minion)
	if Fu.CanNotUseAbility(minion) then
		return
	end
	bot = ownerBot
	stoneFormAbility = minion:GetAbilityByName("visage_summon_familiars_stone_form")
	minion.cast_desire = X.ConsiderStoneForm(minion, stoneFormAbility)
	if minion.cast_desire > 0 then
		minion:Action_UseAbilityOnLocation(stoneFormAbility, minion:GetLocation())
		return
	end
	minion.retreat_desire, minion.retreat_location = X.ConsiderFamiliarRetreat(minion)
	if minion.retreat_desire > 0 then
		minion:Action_MoveToLocation(minion.retreat_location + RandomVector(75))
		return
	end
	minion.attack_desire, minion.attack_target = X.ConsiderFamiliarAttack(minion)
	if minion.attack_desire > 0 then
		minion:Action_AttackUnit(minion.attack_target, true)
		return
	end
	minion.move_desire, minion.move_location = X.ConsiderFamiliarMove(minion)
	if minion.move_desire > 0 then
		minion:Action_MoveToLocation(minion.move_location + RandomVector(75))
		return
	end
end
function X.ConsiderStoneForm(minion, ability)
	if not Fu.CanCastAbility(ability) or minion:HasModifier("modifier_visage_summon_familiars_stone_form_buff") then
		return BOT_ACTION_DESIRE_NONE
	end
	local stunRadius = ability:GetSpecialValueInt("stun_radius")
	local nearbyEnemies = minion:GetNearbyHeroes(stunRadius, true, BOT_MODE_NONE)
	if Fu.IsRetreating(bot) then
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.IsChasingTarget(enemyHero, bot)
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and not MinionUtils.CantMove(enemyHero)
				and bot:WasRecentlyDamagedByHero(enemyHero, 3.0)
			then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	if Fu.GetHP(minion) < 0.35 then
		return BOT_ACTION_DESIRE_HIGH
	end
	for _, enemyHero in pairs(nearbyEnemies) do
		if Fu.IsValidHero(enemyHero) and Fu.CanCastOnNonMagicImmune(enemyHero) and enemyHero:IsChanneling() then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	local attackTarget = minion:GetAttackTarget()
	if
		Fu.IsValidHero(attackTarget)
		and not Fu.IsSuspiciousIllusion(attackTarget)
		and not Fu.IsDisabled(attackTarget)
	then
		return BOT_ACTION_DESIRE_HIGH
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderFamiliarRetreat(minion)
	if minion:HasModifier("modifier_visage_summon_familiars_stone_form_buff") then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	if not bot:IsAlive() then
		return BOT_ACTION_DESIRE_HIGH, Fu.GetTeamFountain()
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.ConsiderFamiliarAttack(minion)
	if minion:HasModifier("modifier_visage_summon_familiars_stone_form_buff") then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local ownerTarget = Fu.GetProperTarget(bot)
	if Fu.IsValidHero(ownerTarget) or Fu.IsValidBuilding(ownerTarget) then
		isAttackingCreepsOrTowers = false
		return BOT_ACTION_DESIRE_HIGH, ownerTarget
	end
	local nearbyUnits = bot:GetNearbyCreeps(700, true)
	for _, creep in pairs(nearbyUnits) do
		if Fu.IsValid(creep) and Fu.CanBeAttacked(creep) and GetUnitToUnitDistance(bot, minion) < 1600 then
			isAttackingCreepsOrTowers = true
			return BOT_ACTION_DESIRE_HIGH, creep
		end
	end
	nearbyUnits = bot:GetNearbyTowers(700, true)
	for _, tower in pairs(nearbyUnits) do
		if
			Fu.IsValidBuilding(tower)
			and Fu.CanBeAttacked(tower)
			and tower:GetAttackTarget() ~= minion
			and not minion:WasRecentlyDamagedByTower(3)
		then
			local enemiesNearby = Fu.GetEnemiesNearLoc(tower:GetLocation(), 700)
			if enemiesNearby ~= nil and #enemiesNearby == 0 and GetUnitToUnitDistance(bot, minion) < 1600 then
				isAttackingCreepsOrTowers = true
				return BOT_ACTION_DESIRE_HIGH, tower
			end
		end
	end
	isAttackingCreepsOrTowers = false
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.ConsiderFamiliarMove(minion)
	if minion:HasModifier("modifier_visage_summon_familiars_stone_form_buff") or not bot:IsAlive() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local nearbyEnemies = minion:GetNearbyHeroes(1600, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and enemyHero:IsChanneling()
			and not Fu.IsSuspiciousIllusion(enemyHero)
		then
			local enemyEnemies = enemyHero:GetNearbyHeroes(1600, true, BOT_MODE_NONE)
			local enemiesNearby = enemyHero:GetNearbyHeroes(1600, false, BOT_MODE_NONE)
			if #enemyEnemies >= #enemiesNearby then
				return BOT_ACTION_DESIRE_HIGH, enemyHero:GetLocation()
			end
		end
	end
	if GetUnitToUnitDistance(minion, bot) > minion:GetAttackRange() and not isAttackingCreepsOrTowers then
		return BOT_ACTION_DESIRE_HIGH, bot:GetLocation() + RandomVector(minion:GetAttackRange())
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
return X
