-- Hero-specific helper: minion.
local X = {}
local bot = GetBot()
if bot == nil or bot:IsInvulnerable() or not bot:IsHero() or not string.find(bot:GetUnitName(), "hero") then
	return
end
local MinionUtils = require(GetScriptDirectory() .. "/FuncLib/hero/minion_lib/utils")
local AttackingWards = require(GetScriptDirectory() .. "/FuncLib/hero/minion_lib/attacking_wards")
local PrimalSplit = require(GetScriptDirectory() .. "/FuncLib/hero/minion_lib/primal_split")
local Familiars = require(GetScriptDirectory() .. "/FuncLib/hero/minion_lib/familiars")
local Illusions = require(GetScriptDirectory() .. "/FuncLib/hero/minion_lib/illusions")
local MinionWithSkill = require(GetScriptDirectory() .. "/FuncLib/hero/minion_lib/minion_with_skill")
local VengefulSpirit = require(GetScriptDirectory() .. "/FuncLib/hero/minion_lib/vengeful_spirit")
local Jugg = require(GetScriptDirectory() .. "/FuncLib/hero/minion_lib/jugg")
local CustomLoader = require(GetScriptDirectory() .. "/FuncLib/systems/custom_loader")
local fastThinkInterval = 0.3
local mediumThinkInterval = 0.5
local slowThinkInterval = 0.7
local simpleAttackInterval = 1.0
local function GetThinkInterval(minion)
	if MinionUtils.IsPrimalSplit(minion) then
		return fastThinkInterval
	end
	if minion:IsHero() and minion:IsIllusion() and minion:GetUnitName() == "npc_dota_hero_vengefulspirit" then
		return fastThinkInterval
	end
	if MinionUtils.IsFamiliar(minion) then
		return mediumThinkInterval
	end
	if MinionUtils.IsAttackingWard(minion) then
		return mediumThinkInterval
	end
	if MinionUtils.IsMinionWithSkill(minion) then
		return mediumThinkInterval
	end
	if minion:IsHero() and minion:IsIllusion() then
		return slowThinkInterval
	end
	if MinionUtils.IsMinionWithNoSkill(minion) then
		return slowThinkInterval
	end
	return simpleAttackInterval
end
local function IsAttackable(unit)
	return unit ~= nil and not unit:IsNull() and unit:IsAlive() and not unit:IsInvulnerable() and not unit:IsAttackImmune()
end
local function SimpleAttackThink(bot, minion)
	local currentTarget = minion:GetAttackTarget()
	if IsAttackable(currentTarget) and currentTarget:IsHero() and GetUnitToUnitDistance(minion, currentTarget) < 1200 then
		return
	end
	local nearbyEnemyHeroes = minion:GetNearbyHeroes(1000, true, BOT_MODE_NONE)
	if nearbyEnemyHeroes then
		for i = 1, #nearbyEnemyHeroes do
			if IsAttackable(nearbyEnemyHeroes[i]) then
				if currentTarget ~= nearbyEnemyHeroes[i] then
					minion:Action_AttackUnit(nearbyEnemyHeroes[i], false)
				end
				return
			end
		end
	end
	local botTarget = bot:GetAttackTarget()
	if IsAttackable(botTarget) and GetUnitToUnitDistance(minion, botTarget) < 1200 then
		if currentTarget ~= botTarget then
			minion:Action_AttackUnit(botTarget, false)
		end
		return
	end
	local nearbyEnemyCreeps = minion:GetNearbyCreeps(800, true)
	if nearbyEnemyCreeps then
		for i = 1, #nearbyEnemyCreeps do
			if IsAttackable(nearbyEnemyCreeps[i]) then
				if currentTarget ~= nearbyEnemyCreeps[i] then
					minion:Action_AttackUnit(nearbyEnemyCreeps[i], false)
				end
				return
			end
		end
	end
	minion:Action_MoveToLocation(bot:GetLocation())
end
local function HawkScoutPoint(owner)
	local ancient = GetAncient(GetOpposingTeam())
	local origin = owner:GetLocation()
	if ancient == nil then
		return origin
	end
	local aLoc = ancient:GetLocation()
	local dx = aLoc.x - origin.x
	local dy = aLoc.y - origin.y
	local len = math.sqrt(dx * dx + dy * dy)
	if len < 1 then
		return origin
	end
	local dist = 1500
	return Vector(origin.x + dx / len * dist, origin.y + dy / len * dist, 0)
end
local function HawkThink(owner, hawk)
	if not owner:IsAlive() then
		local home = GetAncient(GetTeam())
		if home ~= nil then
			hawk:Action_MoveToLocation(home:GetLocation())
		end
		return
	end
	local enemies = hawk:GetNearbyHeroes(1000, true, BOT_MODE_NONE)
	if enemies ~= nil and #enemies > 0 or GetUnitToUnitDistance(hawk, owner) > 2200 then
		hawk:Action_MoveToLocation(owner:GetLocation())
		return
	end
	local goal = HawkScoutPoint(owner)
	if GetUnitToLocationDistance(hawk, goal) > 400 then
		hawk:Action_MoveToLocation(goal)
	end
end
function X.IllusionThink(minion)
	return X.MinionThink(minion)
end
function X.IsValidUnit(minion)
	return MinionUtils.IsValidUnit(minion)
end
function X.HealingWardThink(ward)
	Jugg.HealingWardThink(ward)
end
function X.MinionThink(minion)
	if not minion or minion:IsNull() or not minion:IsAlive() then
		return
	end
	if MinionUtils.IsHawk(minion) then
		local owner = GetBot()
		if owner == nil or owner:GetUnitName() ~= "npc_dota_hero_beastmaster" then
			return
		end
		local now = DotaTime()
		if minion._hawkThink ~= nil and now - minion._hawkThink < 0.4 then
			return
		end
		minion._hawkThink = now
		HawkThink(owner, minion)
		return
	end
	local thinkInterval = minion._minionTier
	if thinkInterval == nil then
		thinkInterval = GetThinkInterval(minion)
		minion._minionTier = thinkInterval
		minion._minionThinkTime = 0
	end
	local lastThinkTime = minion._minionThinkTime or 0
	local scaledInterval = thinkInterval * (1 + (CustomLoader.ThinkLess or 0))
	local elapsed = DotaTime() - lastThinkTime
	if elapsed < scaledInterval then
		local attackTarget = minion:GetAttackTarget()
		local needsNewTarget = attackTarget == nil
			or attackTarget:IsNull()
			or not attackTarget:IsAlive()
			or attackTarget:IsInvulnerable()
			or attackTarget:IsAttackImmune()
			or GetUnitToUnitDistance(minion, attackTarget) > 1600
		if not needsNewTarget or elapsed < 0.2 then
			return
		end
	end
	minion._minionThinkTime = DotaTime()
	local bot = GetBot()
	if bot == nil then
		return
	end
	if not MinionUtils.IsValidUnit(minion) then
		return
	end
	if MinionUtils.CantBeControlled(minion) or MinionUtils.IsShamanFowlPlayChicken(minion) then
		return
	end
	if thinkInterval >= simpleAttackInterval then
		SimpleAttackThink(bot, minion)
		return
	end
	if
		minion:IsHero() and minion:IsIllusion() and minion:GetUnitName() ~= "npc_dota_hero_vengefulspirit" or MinionUtils.IsMinionWithNoSkill(minion)
	then
		Illusions.Think(bot, minion)
		return
	end
	if minion:IsHero() and minion:IsIllusion() and minion:GetUnitName() == "npc_dota_hero_vengefulspirit" then
		VengefulSpirit.Think(bot, minion)
		return
	end
	if MinionUtils.IsAttackingWard(minion) then
		AttackingWards.Think(bot, minion)
		return
	end
	if MinionUtils.IsPrimalSplit(minion) then
		PrimalSplit.MinionThink(bot, minion)
		return
	end
	if MinionUtils.IsFamiliar(minion) then
		Familiars.Think(bot, minion)
		return
	end
	MinionWithSkill.Think(bot, minion)
end
return X
