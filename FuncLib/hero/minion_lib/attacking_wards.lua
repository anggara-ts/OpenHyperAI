-- Thinking for summoned units: attacking wards.
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local MinionUtils = require(GetScriptDirectory() .. "/FuncLib/hero/minion_lib/utils")
local X = {}
function X.Think(ownerBot, ward)
	local attackRange = ward:GetAttackRange()
	if attackRange == nil or attackRange < 400 then
		attackRange = 500
	end
	-- Priority: heroes > creeps > towers/buildings.
	local target = MinionUtils.GetWeakestHero(attackRange, ward)
	if target == nil then
		target = MinionUtils.GetWeakestCreep(attackRange, ward)
	end
	if target == nil then
		target = MinionUtils.GetWeakestTower(attackRange, ward)
	end
	if target == nil or MinionUtils.IsNotAllowedToAttack(target) then
		return
	end
	if ward._lastWardTarget == target and ward:GetAttackTarget() == target then
		return
	end
	ward._lastWardTarget = target
	ward:Action_AttackUnit(target, false)
end
return X
