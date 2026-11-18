-- How Rubick plays after stealing a spell from Bristleback.
-- Accidental globals made file-local (#13): every bot shares one Lua state, so these were shared.
local HairBallDesire, HairBallLocation, BristlebackDesire, BristlebackLocation, ViscousNasalGooDesire, ViscousNasalGooTarget, QuillSprayDesire
local bot = GetBot()
local X = {}
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local viscousNasalGooAbility
local quillSprayAbility
local hairballAbility
local bristlebackAbility
local botTarget
local mpRatio, botLevel, nearbyEnemies
function X.ConsiderStolenSpell(ability)
	bot = GetBot()
	if Fu.CanNotUseAbility(bot) then
		return
	end
	botTarget = Fu.GetProperTarget(bot)
	local abilityName = ability:GetName()
	mpRatio = bot:GetMana() / bot:GetMaxMana()
	botLevel = bot:GetLevel()
	nearbyEnemies = Fu.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE)
	if abilityName == "bristleback_hairball" then
		hairballAbility = ability
		HairBallDesire, HairBallLocation = X.ConsiderHairBall()
		if HairBallDesire > 0 then
			bot:Action_UseAbilityOnLocation(hairballAbility, HairBallLocation)
			return
		end
	end
	if abilityName == "bristleback_bristleback" then
		bristlebackAbility = ability
		BristlebackDesire, BristlebackLocation = X.ConsiderBristleback()
		if BristlebackDesire > 0 then
			bot:Action_UseAbilityOnLocation(bristlebackAbility, BristlebackLocation)
			return
		end
	end
	if abilityName == "bristleback_viscous_nasal_goo" then
		viscousNasalGooAbility = ability
		ViscousNasalGooDesire, ViscousNasalGooTarget = X.ConsiderViscousNasalGoo()
		if ViscousNasalGooDesire > 0 then
			bot:Action_UseAbilityOnEntity(viscousNasalGooAbility, ViscousNasalGooTarget)
			return
		end
	end
	if abilityName == "bristleback_quill_spray" then
		quillSprayAbility = ability
		QuillSprayDesire = X.ConsiderQuillSpray()
		if QuillSprayDesire > 0 then
			bot:Action_UseAbility(quillSprayAbility)
			return
		end
	end
end
function X.ConsiderViscousNasalGoo()
	if not viscousNasalGooAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local scepterRadius = viscousNasalGooAbility:GetSpecialValueInt("radius_scepter")
	local castRange = Fu.GetProperCastRange(false, bot, viscousNasalGooAbility:GetCastRange())
	local manaCost = viscousNasalGooAbility:GetManaCost()
	local enemiesInScepterRadius = Fu.GetNearbyHeroes(bot, scepterRadius, true, BOT_MODE_NONE)
	local closeEnemies = Fu.GetNearbyHeroes(bot, 800, true, BOT_MODE_NONE)
	if Fu.IsRetreating(bot) then
		local nearestEnemy = enemiesInScepterRadius[1]
		if Fu.IsValid(nearestEnemy) then
			if bot:HasScepter() then
				return BOT_ACTION_DESIRE_LOW, nearestEnemy
			end
			if
				Fu.CanCastOnNonMagicImmune(nearestEnemy)
				and Fu.CanCastOnTargetAdvanced(nearestEnemy)
				and (bot:IsFacingLocation(nearestEnemy:GetLocation(), 10) or #closeEnemies <= 1)
				and (bot:WasRecentlyDamagedByHero(nearestEnemy, 2.0) or botLevel >= 10)
			then
				return BOT_ACTION_DESIRE_LOW, nearestEnemy
			end
		end
	end
	if bot:GetActiveMode() == BOT_MODE_ROSHAN then
		if
			Fu.IsRoshan(botTarget)
			and Fu.CanCastOnMagicImmune(botTarget)
			and Fu.IsInRange(botTarget, bot, castRange)
		then
			return BOT_ACTION_DESIRE_LOW, botTarget
		end
	end
	if Fu.IsInTeamFight(bot, 1400) and bot:HasScepter() then
		if
			enemiesInScepterRadius ~= nil
			and #enemiesInScepterRadius >= 1
			and Fu.IsValidHero(enemiesInScepterRadius[1])
			and Fu.CanCastOnNonMagicImmune(enemiesInScepterRadius[1])
		then
			return BOT_ACTION_DESIRE_HIGH, enemiesInScepterRadius[1]
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidHero(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(botTarget, bot, scepterRadius)
			and Fu.CanCastOnTargetAdvanced(botTarget)
		then
			return BOT_ACTION_DESIRE_ABSOLUTE, botTarget
		end
		if
			Fu.IsValid(botTarget)
			and #nearbyEnemies == 0
			and Fu.IsAllowedToSpam(bot, manaCost)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.CanCastOnTargetAdvanced(botTarget)
			and Fu.IsInRange(botTarget, bot, scepterRadius)
			and not Fu.CanKillTarget(botTarget, bot:GetAttackDamage() * 1.68, DAMAGE_TYPE_PHYSICAL)
		then
			local nearbyCreeps = bot:GetNearbyCreeps(800, true)
			if #nearbyCreeps >= 1 then
				return BOT_ACTION_DESIRE_ABSOLUTE, botTarget
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.ConsiderQuillSpray()
	if not quillSprayAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
	end
	local radius = quillSprayAbility:GetSpecialValueInt("radius")
	local manaCost = quillSprayAbility:GetManaCost()
	local enemiesInRadius = Fu.GetNearbyHeroes(bot, radius, true, BOT_MODE_NONE)
	if Fu.IsRetreating(bot) and #enemiesInRadius > 0 then
		for _, enemyHero in pairs(enemiesInRadius) do
			if
				bot:WasRecentlyDamagedByHero(enemyHero, 4.0)
				or enemyHero:HasModifier("modifier_bristleback_quill_spray")
			then
				return BOT_ACTION_DESIRE_MODERATE
			end
		end
	end
	if Fu.IsPushing(bot) or Fu.IsDefending(bot) or Fu.IsGoingOnSomeone(bot) and botLevel >= 6 then
		local nearbyLaneCreeps = bot:GetNearbyLaneCreeps(radius, true)
		if nearbyLaneCreeps ~= nil and #nearbyLaneCreeps >= 1 and Fu.IsAllowedToSpam(bot, manaCost) then
			return BOT_ACTION_DESIRE_MODERATE
		end
	end
	if Fu.IsFarming(bot) and botLevel > 5 and Fu.IsAllowedToSpam(bot, manaCost) then
		if Fu.IsValid(botTarget) and botTarget:GetTeam() == TEAM_NEUTRAL then
			if botTarget:GetHealth() > bot:GetAttackDamage() * 2.28 then
				return BOT_ACTION_DESIRE_HIGH
			end
			local nearbyCreeps = bot:GetNearbyCreeps(radius, true)
			if #nearbyCreeps >= 2 then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	if Fu.IsInTeamFight(bot, 1200) then
		if #enemiesInRadius >= 1 then
			return BOT_ACTION_DESIRE_LOW
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidHero(botTarget)
			and Fu.CanCastOnMagicImmune(botTarget)
			and Fu.IsInRange(botTarget, bot, radius - 100)
		then
			return BOT_ACTION_DESIRE_MODERATE
		end
		if
			Fu.IsValidHero(botTarget)
			and Fu.IsAllowedToSpam(bot, manaCost)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(botTarget, bot, radius)
		then
			local nearbyCreeps = bot:GetNearbyCreeps(800, true)
			if #nearbyCreeps >= 1 then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	if bot:GetActiveMode() == BOT_MODE_ROSHAN then
		if Fu.IsRoshan(botTarget) and Fu.CanCastOnMagicImmune(botTarget) and Fu.IsInRange(bot, botTarget, radius) then
			return BOT_ACTION_DESIRE_MODERATE
		end
	end
	if mpRatio > 0.95 and botLevel >= 6 and bot:DistanceFromFountain() > 2400 and Fu.IsAllowedToSpam(bot, manaCost) then
		return BOT_ACTION_DESIRE_LOW
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderBristleback()
	if
		bristlebackAbility:IsPassive()
		or not bristlebackAbility:IsTrained()
		or not bristlebackAbility:IsFullyCastable()
	then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	if Fu.IsInTeamFight(bot, 1400) then
		local aoeLocation = Fu.GetAoeEnemyHeroLocation(bot, 700, 700, 2)
		if aoeLocation ~= nil then
			return BOT_ACTION_DESIRE_HIGH, aoeLocation
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		local target = Fu.GetProperTarget(bot)
		if Fu.IsValidHero(target) and Fu.IsInRange(bot, target, 700) and Fu.CanCastOnNonMagicImmune(target) then
			return BOT_ACTION_DESIRE_HIGH, target:GetLocation()
		end
	end
	if Fu.IsRetreating(bot) then
		local enemiesInRange = Fu.GetNearbyHeroes(bot, 700, true, BOT_MODE_NONE)
		if enemiesInRange ~= nil and #enemiesInRange > 0 then
			local enemyHero = enemiesInRange[1]
			if Fu.IsValidHero(enemyHero) and Fu.CanCastOnNonMagicImmune(enemyHero) then
				return BOT_ACTION_DESIRE_MODERATE, enemyHero:GetLocation()
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.ConsiderHairBall()
	if not hairballAbility:IsTrained() or not hairballAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local radius = 700
	local castRange = Fu.GetProperCastRange(false, bot, hairballAbility:GetCastRange())
	if Fu.IsRetreating(bot) then
		local enemiesInRadius = Fu.GetNearbyHeroes(bot, radius, true, BOT_MODE_NONE)
		local enemyHero = enemiesInRadius[1]
		if Fu.IsValidHero(enemyHero) and Fu.CanCastOnNonMagicImmune(enemyHero) then
			return BOT_ACTION_DESIRE_HIGH, bot:GetLocation()
		end
	end
	if Fu.IsInTeamFight(bot, 1400) then
		local aoeLocation = Fu.GetAoeEnemyHeroLocation(bot, castRange, radius, 2)
		if aoeLocation ~= nil then
			return BOT_ACTION_DESIRE_HIGH, aoeLocation
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		local target = Fu.GetProperTarget(bot)
		if Fu.IsValidHero(target) and Fu.IsInRange(bot, target, castRange) and Fu.CanCastOnNonMagicImmune(target) then
			return BOT_ACTION_DESIRE_HIGH, target:GetLocation()
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
return X
