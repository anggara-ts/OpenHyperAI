-- How Rubick plays after stealing a spell from Bloodseeker.
local bot = GetBot()
local X = {}
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local bloodrageAbility
local bloodRiteAbility
local bloodMistAbility
local ruptureAbility
local botTarget
local hpRatio
function X.ConsiderStolenSpell(ability)
	bot = GetBot()
	if Fu.CanNotUseAbility(bot) then
		return
	end
	botTarget = Fu.GetProperTarget(bot)
	local abilityName = ability:GetName()
	hpRatio = bot:GetHealth() / bot:GetMaxHealth()
	if abilityName == "bloodseeker_blood_mist" then
		bloodMistAbility = ability
		BloodMistDesire = X.ConsiderBloodMist()
		if BloodMistDesire > 0 then
			bot:Action_UseAbility(bloodMistAbility)
			return
		end
	end
	if abilityName == "bloodseeker_rupture" then
		ruptureAbility = ability
		RuptureDesire, RuptureTarget = X.ConsiderRupture()
		if RuptureDesire > 0 then
			bot:Action_UseAbilityOnEntity(ruptureAbility, RuptureTarget)
			return
		end
	end
	if abilityName == "bloodseeker_bloodrage" then
		bloodrageAbility = ability
		BloodrageDesire, BloodrageTarget = X.ConsiderBloodrage()
		if BloodrageDesire > 0 then
			bot:Action_UseAbilityOnEntity(bloodrageAbility, BloodrageTarget)
			return
		end
	end
	if abilityName == "bloodseeker_blood_bath" then
		bloodRiteAbility = ability
		BloodRiteDesire, BloodRiteLocation = X.ConsiderBloodRite()
		if BloodRiteDesire > 0 then
			bot:Action_UseAbilityOnLocation(bloodRiteAbility, BloodRiteLocation)
			return
		end
	end
end
function X.ConsiderBloodrage()
	if not bloodrageAbility:IsFullyCastable() then
		return 0
	end
	local castRange = Fu.GetProperCastRange(false, bot, bloodrageAbility:GetCastRange())
	local attackDamage = bot:GetAttackDamage()
	if Fu.IsInTeamFight(bot, 1200) or Fu.IsPushing(bot) or Fu.IsDefending(bot) then
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE)
		if #nearbyEnemies >= 1 then
			local nearbyAllies = Fu.GetNearbyHeroes(bot, castRange + 200, false, BOT_MODE_NONE)
			local bestAttackDamage = 0
			local bestAlly = nil
			for _, ally in pairs(nearbyAllies) do
				local allyAttackDamage = ally:GetAttackDamage()
				if
					Fu.IsValid(ally)
					and ally:GetAttackTarget() ~= nil
					and Fu.CanCastOnNonMagicImmune(ally)
					and (Fu.GetHP(ally) > 0.18 or Fu.GetHP(ally:GetAttackTarget()) < 0.18)
					and not ally:HasModifier("modifier_bloodseeker_bloodrage")
					and allyAttackDamage > bestAttackDamage
				then
					bestAttackDamage = allyAttackDamage
					bestAlly = ally
				end
			end
			if bestAlly ~= nil then
				return BOT_ACTION_DESIRE_HIGH, bestAlly
			end
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if Fu.IsValidHero(botTarget) and Fu.CanCastOnMagicImmune(botTarget) and Fu.IsInRange(botTarget, bot, 600) then
			if not bot:HasModifier("modifier_bloodseeker_bloodrage") then
				return BOT_ACTION_DESIRE_HIGH, bot
			end
		end
	end
	if
		Fu.IsValid(botTarget)
		and botTarget:GetTeam() == TEAM_NEUTRAL
		and not bot:HasModifier("modifier_bloodseeker_bloodrage")
	then
		local nearbyCreeps = bot:GetNearbyCreeps(1000, true)
		for _, creep in pairs(nearbyCreeps) do
			if Fu.IsValid(creep) and not Fu.CanKillTarget(creep, attackDamage, DAMAGE_TYPE_PHYSICAL) then
				return BOT_ACTION_DESIRE_HIGH, bot
			end
		end
	end
	if bot:GetActiveMode() == BOT_MODE_ROSHAN then
		if not bot:HasModifier("modifier_bloodseeker_bloodrage") and bot:GetAttackTarget() ~= nil then
			return BOT_ACTION_DESIRE_HIGH, bot
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.ConsiderBloodRite()
	if not bloodRiteAbility:IsFullyCastable() then
		return 0
	end
	local radius = 600
	local castRange = Fu.GetProperCastRange(false, bot, bloodRiteAbility:GetCastRange())
	local castPoint = bloodRiteAbility:GetCastPoint()
	local delay = bloodRiteAbility:GetSpecialValueFloat("delay")
	local manaCost = bloodRiteAbility:GetManaCost()
	local damage = bloodRiteAbility:GetSpecialValueInt("damage")
	local nearbyEnemies = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	local nearbyAllies = Fu.GetNearbyHeroes(bot, 800, false, BOT_MODE_NONE)
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValid(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and Fu.CanKillTarget(enemyHero, damage, DAMAGE_TYPE_PURE)
		then
			if enemyHero:GetMovementDirectionStability() >= 0.75 then
				return BOT_ACTION_DESIRE_HIGH, enemyHero:GetExtrapolatedLocation(delay)
			else
				return BOT_ACTION_DESIRE_HIGH, enemyHero:GetLocation()
			end
		end
	end
	if bot:GetActiveMode() == BOT_MODE_LANING and Fu.IsAllowedToSpam(bot, manaCost) then
		local aoeLocation = bot:FindAoELocation(true, false, bot:GetLocation(), 1000, radius / 2, castPoint, damage)
		if aoeLocation.count >= 4 then
			return BOT_ACTION_DESIRE_MODERATE, aoeLocation.targetloc
		end
	end
	if
		(Fu.IsPushing(bot) or Fu.IsDefending(bot)) and Fu.IsAllowedToSpam(bot, manaCost) and nearbyEnemies == nil
		or #nearbyEnemies == 0 and #nearbyAllies <= 2
	then
		local nearbyLaneCreeps = bot:GetNearbyLaneCreeps(1000, true)
		local aoeLocation = bot:FindAoELocation(true, false, bot:GetLocation(), 1000, radius / 2, castPoint, damage)
		if aoeLocation.count >= 4 and #nearbyLaneCreeps >= 4 then
			return BOT_ACTION_DESIRE_MODERATE, aoeLocation.targetloc
		end
	end
	if Fu.IsRetreating(bot) then
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValid(enemyHero)
				and bot:WasRecentlyDamagedByHero(enemyHero, 1.0)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
			then
				return BOT_ACTION_DESIRE_HIGH, bot:GetLocation()
			end
		end
	end
	if Fu.IsInTeamFight(bot, 1200) then
		local aoeLocation =
			bot:FindAoELocation(true, true, bot:GetLocation(), castRange - 200, radius / 2, castPoint, 0)
		if aoeLocation.count >= 2 then
			local castableEnemyCount = Fu.GetInvUnitInLocCount(bot, castRange, radius / 2, aoeLocation.targetloc, false)
			if castableEnemyCount >= aoeLocation.count then
				return BOT_ACTION_DESIRE_MODERATE, aoeLocation.targetloc
			end
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidHero(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(botTarget, bot, castRange + radius)
		then
			local castLocation = Fu.GetDelayCastLocation(bot, botTarget, castRange, radius, 2.0)
			if castLocation ~= nil then
				return BOT_ACTION_DESIRE_HIGH, castLocation
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.ConsiderRupture()
	if not ruptureAbility:IsFullyCastable() then
		return 0
	end
	local castRange = ruptureAbility:GetCastRange()
	local nearbyEnemies = Fu.GetNearbyHeroes(bot, castRange + 200, true, BOT_MODE_NONE)
	if Fu.IsRetreating(bot) then
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				bot:WasRecentlyDamagedByHero(enemyHero, 1.0)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
				and not enemyHero:HasModifier("modifier_bloodseeker_rupture")
			then
				return BOT_ACTION_DESIRE_MODERATE, enemyHero
			end
		end
	end
	if Fu.IsInTeamFight(bot, 1200) then
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
				and Fu.Role.IsCarry(enemyHero:GetUnitName())
				and not enemyHero:HasModifier("modifier_bloodseeker_rupture")
				and not Fu.IsDisabled(enemyHero)
			then
				return BOT_ACTION_DESIRE_HIGH, enemyHero
			end
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidHero(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.CanCastOnTargetAdvanced(botTarget)
			and Fu.IsInRange(botTarget, bot, castRange + 100)
			and not botTarget:HasModifier("modifier_bloodseeker_rupture")
			and not Fu.IsDisabled(botTarget)
		then
			local alliesNearTarget = Fu.GetNearbyHeroes(botTarget, 1200, true, BOT_MODE_NONE)
			if alliesNearTarget ~= nil and #alliesNearTarget >= 2 then
				return BOT_ACTION_DESIRE_HIGH, botTarget
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.ConsiderBloodMist()
	if not bot:HasScepter() or not bloodMistAbility:IsFullyCastable() then
		return BOT_MODE_NONE
	end
	local radius = 450
	local nearbyEnemies = Fu.GetNearbyHeroes(bot, radius, true, BOT_MODE_NONE)
	if bloodMistAbility:GetToggleState() == true then
		if hpRatio < 0.2 then
			return BOT_ACTION_DESIRE_HIGH
		end
		if #nearbyEnemies == 0 then
			return BOT_ACTION_DESIRE_ABSOLUTE
		end
	end
	-- Toggle Blood Mist on (it was `not toggle == false`, which only fired while it was already on)
	if bloodMistAbility:GetToggleState() == false and hpRatio > 0.5 then
		if
			Fu.IsValidHero(botTarget)
			and Fu.IsInRange(bot, botTarget, radius * 0.8)
			and Fu.CanCastOnNonMagicImmune(botTarget)
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	return BOT_MODE_NONE
end
return X
