-- Hero-specific helper: hero sub units.
local X = {}
local ownerHero
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local stoneFormAbility
local isFamiliarBusy = false
-- Were accidental globals (shared with every other script in the VM).
local ConsiderStoneForm, ConsiderFamiliarRetreat, ConsiderFamiliarAttack, ConsiderFamiliarMove
local ConsiderReturn, ConsiderBearRetreat, ConsiderBearAttack, ConsiderBearMove
function X.FamiliarThink(hero, familiar)
	if Fu.CanNotUseAbility(familiar) then
		return
	end
	ownerHero = hero
	stoneFormAbility = familiar:GetAbilityByName("visage_summon_familiars_stone_form")
	local Desire = ConsiderStoneForm(familiar, stoneFormAbility)
	if Desire > 0 then
		familiar:Action_UseAbilityOnLocation(stoneFormAbility, familiar:GetLocation())
		return
	end
	local RetreatDesire, RetreatLocation = ConsiderFamiliarRetreat(familiar)
	if RetreatDesire > 0 then
		familiar:Action_MoveToLocation(RetreatLocation)
		return
	end
	local AttackDesire, AttackTarget = ConsiderFamiliarAttack(familiar)
	if AttackDesire > 0 then
		familiar:Action_AttackUnit(AttackTarget, false)
		return
	end
	local MoveDesire, MoveLocation = ConsiderFamiliarMove(familiar)
	if MoveDesire > 0 then
		familiar:Action_MoveToLocation(MoveLocation)
		return
	end
end
function ConsiderStoneForm(familiar, stoneFormAbility)
	if
		not stoneFormAbility:IsFullyCastable()
		or familiar:HasModifier("modifier_visage_summon_familiars_stone_form_buff")
	then
		return BOT_ACTION_DESIRE_NONE
	end
	local stunRadius = stoneFormAbility:GetSpecialValueInt("stun_radius")
	if Fu.IsRetreating(ownerHero) then
		local nearbyEnemies = Fu.GetNearbyHeroes(ownerHero, 1600, true, BOT_MODE_NONE)
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
				and Fu.IsChasingTarget(enemyHero, ownerHero)
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and not Fu.IsDisabled(enemyHero)
			then
				local alliesNearEnemy = Fu.GetNearbyHeroes(enemyHero, 1200, true, BOT_MODE_NONE)
				local enemiesNearEnemy = Fu.GetNearbyHeroes(enemyHero, 1200, false, BOT_MODE_NONE)
				if
					alliesNearEnemy ~= nil
					and enemiesNearEnemy ~= nil
					and (#enemiesNearEnemy > #alliesNearEnemy or ownerHero:WasRecentlyDamagedByAnyHero(2.5))
				then
					local enemiesInStunRadius = familiar:GetNearbyHeroes(stunRadius, true, BOT_MODE_NONE)
					if enemiesInStunRadius ~= nil and #enemiesInStunRadius >= 1 then
						return BOT_ACTION_DESIRE_HIGH
					end
				end
			end
		end
	end
	if Fu.GetHP(familiar) < 0.49 then
		return BOT_ACTION_DESIRE_HIGH
	end
	local nearbyEnemies = familiar:GetNearbyHeroes(stunRadius, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and enemyHero:IsChanneling()
			and not Fu.IsSuspiciousIllusion(enemyHero)
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	local attackTarget = familiar:GetAttackTarget()
	if
		Fu.IsValidHero(attackTarget)
		and not Fu.IsSuspiciousIllusion(attackTarget)
		and not Fu.IsDisabled(attackTarget)
	then
		return BOT_ACTION_DESIRE_HIGH
	end
	return BOT_ACTION_DESIRE_NONE
end
function ConsiderFamiliarRetreat(familiar)
	if familiar:HasModifier("modifier_visage_summon_familiars_stone_form_buff") then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	if not ownerHero:IsAlive() then
		return BOT_ACTION_DESIRE_HIGH, Fu.GetEscapeLoc()
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function ConsiderFamiliarAttack(familiar)
	if familiar:HasModifier("modifier_visage_summon_familiars_stone_form_buff") then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local heroTarget = Fu.GetProperTarget(ownerHero)
	if Fu.IsValidHero(heroTarget) or Fu.IsValidBuilding(heroTarget) then
		isFamiliarBusy = false
		return BOT_ACTION_DESIRE_HIGH, heroTarget
	end
	local nearbyUnits = ownerHero:GetNearbyCreeps(700, true)
	for _, creep in pairs(nearbyUnits) do
		if Fu.IsValid(creep) and Fu.CanBeAttacked(creep) and GetUnitToUnitDistance(ownerHero, familiar) < 1600 then
			isFamiliarBusy = true
			return BOT_ACTION_DESIRE_HIGH, creep
		end
	end
	nearbyUnits = ownerHero:GetNearbyTowers(700, true)
	for _, tower in pairs(nearbyUnits) do
		if
			Fu.IsValidBuilding(tower)
			and Fu.CanBeAttacked(tower)
			and tower:GetAttackTarget() ~= familiar
			and not familiar:WasRecentlyDamagedByTower(1)
		then
			local enemiesNearTower = Fu.GetEnemiesNearLoc(tower:GetLocation(), 700)
			if
				enemiesNearTower ~= nil
				and #enemiesNearTower == 0
				and GetUnitToUnitDistance(ownerHero, familiar) < 1600
			then
				isFamiliarBusy = true
				return BOT_ACTION_DESIRE_HIGH, tower
			end
		end
	end
	isFamiliarBusy = false
	return BOT_ACTION_DESIRE_NONE, 0
end
function ConsiderFamiliarMove(familiar)
	if familiar:HasModifier("modifier_visage_summon_familiars_stone_form_buff") or not ownerHero:IsAlive() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local nearbyEnemies = familiar:GetNearbyHeroes(1600, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and enemyHero:IsChanneling()
			and not Fu.IsSuspiciousIllusion(enemyHero)
		then
			local alliesNearEnemy = Fu.GetNearbyHeroes(enemyHero, 1200, true, BOT_MODE_NONE)
			local enemiesNearEnemy = Fu.GetNearbyHeroes(enemyHero, 1200, false, BOT_MODE_NONE)
			if alliesNearEnemy ~= nil and enemiesNearEnemy ~= nil and #alliesNearEnemy >= #enemiesNearEnemy then
				return BOT_ACTION_DESIRE_HIGH, enemyHero:GetLocation()
			end
		end
	end
	if GetUnitToUnitDistance(familiar, ownerHero) > familiar:GetAttackRange() and not isFamiliarBusy then
		return BOT_ACTION_DESIRE_HIGH, ownerHero:GetLocation() + RandomVector(familiar:GetAttackRange())
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
local bearItemList = {
	"item_six_branches",
	"item_phase_boots",
	"item_diffusal_blade",
	"item_harpoon",
	"item_aghanims_shard",
	"item_assault",
	"item_basher",
	"item_skadi",
	"item_disperser",
	"item_monkey_king_bar",
	"item_bloodthorn",
}
local returnAbility
local bearTarget
function X.BearThink(hero, bear)
	ownerHero = hero
	bearTarget = Fu.GetProperTarget(ownerHero)
	returnAbility = bear:GetAbilityByName("lone_druid_spirit_bear_return")
	local Desire = ConsiderReturn(bear, returnAbility)
	if Desire > 0 then
		bear:Action_UseAbility(returnAbility)
		return
	end
	local RetreatDesire, RetreatLocation = ConsiderBearRetreat(bear)
	if RetreatDesire > 0 then
		bear:Action_MoveToLocation(RetreatLocation)
		return
	end
	local AttackDesire, AttackTarget = ConsiderBearAttack(bear)
	if AttackDesire > 0 then
		bear:Action_AttackUnit(AttackTarget, false)
		return
	end
	local MoveDesire, MoveLocation = ConsiderBearMove(bear)
	if MoveDesire > 0 then
		bear:Action_MoveToLocation(MoveLocation)
		return
	end
end
function ConsiderReturn(bear, returnAbility)
	if not returnAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
	end
	if GetUnitToUnitDistance(ownerHero, bear) > 1100 then
		bear:SetTarget(nil)
		return BOT_ACTION_DESIRE_HIGH
	end
	return BOT_ACTION_DESIRE_NONE
end
function ConsiderBearRetreat(bear)
	if Fu.IsRetreating(ownerHero) then
		local nearbyAllies = bear:GetNearbyHeroes(1600, false, BOT_MODE_NONE)
		local nearbyEnemies = bear:GetNearbyHeroes(1600, true, BOT_MODE_NONE)
		if nearbyAllies ~= nil and nearbyEnemies ~= nil and #nearbyEnemies > #nearbyAllies then
			return BOT_ACTION_DESIRE_HIGH, ownerHero:GetLocation()
		end
	end
	if bear:WasRecentlyDamagedByTower(1) and Fu.GetHP(bear) < 0.5 then
		local nearbyTowers = bear:GetNearbyTowers(700, true)
		if nearbyTowers ~= nil and #nearbyTowers >= 1 and GetUnitToUnitDistance(bear, nearbyTowers[1]) < 700 then
			return BOT_ACTION_DESIRE_HIGH, ownerHero:GetLocation()
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function ConsiderBearAttack(bear)
	if Fu.IsPushing(ownerHero) or Fu.IsDefending(ownerHero) then
		local nearbyTowers = bear:GetNearbyTowers(1200, true)
		if nearbyTowers ~= nil and #nearbyTowers >= 1 then
			return BOT_ACTION_DESIRE_HIGH, nearbyTowers[1]
		end
		local nearbyLaneCreeps = bear:GetNearbyLaneCreeps(1600, true)
		if nearbyLaneCreeps ~= nil and #nearbyLaneCreeps >= 1 then
			return BOT_ACTION_DESIRE_HIGH, nearbyLaneCreeps[1]
		end
	end
	if Fu.IsLaning(ownerHero) then
		local nearbyLaneCreeps = bear:GetNearbyLaneCreeps(ownerHero:GetAttackRange(), true)
		if nearbyLaneCreeps ~= nil and #nearbyLaneCreeps >= 1 then
			for _, creep in pairs(nearbyLaneCreeps) do
				if Fu.IsValid(creep) and Fu.CanBeAttacked(creep) and creep:GetHealth() <= bear:GetAttackDamage() then
					return BOT_ACTION_DESIRE_HIGH, creep
				end
			end
		end
	end
	if Fu.IsFarming(ownerHero) then
		local nearbyCreeps = bear:GetNearbyCreeps(1600, true)
		if nearbyCreeps ~= nil and #nearbyCreeps >= 1 and Fu.IsAttacking(ownerHero) then
			local strongestCreep = nil
			local strongestHealth = 0
			for _, creep in pairs(nearbyCreeps) do
				if Fu.IsValid(creep) and Fu.CanBeAttacked(creep) and strongestHealth < creep:GetHealth() then
					strongestHealth = creep:GetHealth()
					strongestCreep = creep
				end
			end
			if strongestCreep ~= nil then
				return BOT_ACTION_DESIRE_HIGH, strongestCreep
			end
		end
	end
	if Fu.IsDoingRoshan(ownerHero) or Fu.IsDoingTormentor(ownerHero) then
		if
			(Fu.IsRoshan(bearTarget) or Fu.IsTormentor(bearTarget))
			and Fu.IsInRange(ownerHero, bearTarget, 500)
			and Fu.IsAttacking(ownerHero)
		then
			bear:SetTarget(bearTarget)
			return BOT_ACTION_DESIRE_HIGH, bearTarget
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function ConsiderBearMove(bear)
	if not Fu.IsInRange(ownerHero, bear, 700) then
		return BOT_ACTION_DESIRE_HIGH, ownerHero:GetLocation()
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
return X
