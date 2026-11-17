-- How Rubick plays after stealing a spell from Bounty Hunter.
local bot = GetBot()
local X = {}
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local shurikenTossAbility
local jinadaAbility
local shadowWalkAbility
local friendlyShadowAbility
local trackAbility
local botTarget
local mpRatio, hpRatio, botLevel, nearbyEnemies, nearbyAllies
local lastSneakLogTime = -999
function X.ConsiderStolenSpell(ability)
	bot = GetBot()
	if Fu.CanNotUseAbility(bot) then
		return
	end
	botTarget = Fu.GetProperTarget(bot)
	local abilityName = ability:GetName()
	botLevel = bot:GetLevel()
	mpRatio = bot:GetMana() / bot:GetMaxMana()
	hpRatio = bot:GetHealth() / bot:GetMaxHealth()
	nearbyEnemies = Fu.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE)
	nearbyAllies = Fu.GetAlliesNearLoc(bot:GetLocation(), 1600)
	if abilityName == "bounty_hunter_wind_walk" then
		shadowWalkAbility = ability
		local ShadowWalkDesire = X.ConsiderShadowWalk()
		if ShadowWalkDesire > 0 then
			bot:Action_UseAbility(shadowWalkAbility)
			return
		end
	end
	if abilityName == "bounty_hunter_wind_walk_ally" then
		friendlyShadowAbility = ability
		local FriendlyShadowDesire, FriendlyShadowTarget = X.ConsiderFriendlyShadow()
		if FriendlyShadowDesire > 0 then
			bot:Action_UseAbilityOnEntity(friendlyShadowAbility, FriendlyShadowTarget)
			return
		end
	end
	if abilityName == "bounty_hunter_track" then
		trackAbility = ability
		local TrackDesire, TrackTarget = X.ConsiderTrack()
		if TrackDesire > 0 then
			bot:Action_UseAbilityOnEntity(trackAbility, TrackTarget)
			return
		end
	end
	if abilityName == "bounty_hunter_shuriken_toss" then
		shurikenTossAbility = ability
		local ShurikenTossDesire, ShurikenTossTarget = X.ConsiderShurikenToss()
		if ShurikenTossDesire > 0 then
			-- fix: the target was the ability handle itself
			bot:ActionQueue_UseAbilityOnEntity(shurikenTossAbility, ShurikenTossTarget)
			return
		end
	end
end
function X.ConsiderShurikenToss()
	if not shurikenTossAbility:IsFullyCastable() then
		return 0
	end
	local abilityLevel = shurikenTossAbility:GetLevel()
	local castRange = Fu.GetProperCastRange(false, bot, shurikenTossAbility:GetCastRange())
	local castPoint = shurikenTossAbility:GetCastPoint()
	local manaCost = shurikenTossAbility:GetManaCost()
	local damage = shurikenTossAbility:GetSpecialValueInt("bonus_damage")
	local damageType = DAMAGE_TYPE_MAGICAL
	local bounceRadius = shurikenTossAbility:GetSpecialValueInt("bounce_aoe")
	local nearbyEnemyUnits = Fu.GetAroundBotUnitList(bot, castRange + 100, true)
	local trackedEnemies = {}
	for _, npcEnemy in pairs(nearbyEnemies) do
		if npcEnemy:HasModifier("modifier_bounty_hunter_track") then
			trackedEnemies[#trackedEnemies + 1] = npcEnemy
		end
		if npcEnemy:IsChanneling() and not npcEnemy:IsMagicImmune() then
			if npcEnemy:HasModifier("modifier_bounty_hunter_track") then
				for _, enemyUnit in pairs(nearbyEnemyUnits) do
					if
						Fu.IsValid(enemyUnit)
						and Fu.CanCastOnTargetAdvanced(enemyUnit)
						and not enemyUnit:IsMagicImmune()
					then
						return BOT_ACTION_DESIRE_HIGH, enemyUnit
					end
				end
			end
			if Fu.IsInRange(bot, npcEnemy, castRange + 200) and Fu.CanCastOnTargetAdvanced(npcEnemy) then
				return BOT_ACTION_DESIRE_HIGH, npcEnemy
			end
		end
		if
			Fu.CanCastOnNonMagicImmune(npcEnemy)
			and Fu.WillMagicKillTarget(bot, npcEnemy, damage, castPoint + GetUnitToUnitDistance(bot, npcEnemy) / 1000)
		then
			if npcEnemy:HasModifier("modifier_bounty_hunter_track") then
				for _, enemyUnit in pairs(nearbyEnemyUnits) do
					if
						Fu.IsValid(enemyUnit)
						and Fu.CanCastOnTargetAdvanced(enemyUnit)
						and not enemyUnit:IsMagicImmune()
					then
						return BOT_ACTION_DESIRE_HIGH, enemyUnit
					end
				end
			end
			if Fu.IsInRange(bot, npcEnemy, castRange + 200) and Fu.CanCastOnTargetAdvanced(npcEnemy) then
				return BOT_ACTION_DESIRE_HIGH, npcEnemy
			end
		end
	end
	if #trackedEnemies >= 2 then
		local bestBounceUnit = nil
		local bestBounceScore = 1.2
		for _, enemyUnit in pairs(nearbyEnemyUnits) do
			if Fu.IsValid(enemyUnit) and not enemyUnit:IsMagicImmune() and Fu.CanCastOnTargetAdvanced(enemyUnit) then
				local bounceScore = 0
				if not enemyUnit:HasModifier("modifier_bounty_hunter_track") then
					if enemyUnit:IsHero() then
						bounceScore = bounceScore + 1
					else
						bounceScore = bounceScore + 0.1
					end
				end
				for _, npcEnemy in pairs(trackedEnemies) do
					if Fu.IsInRange(enemyUnit, npcEnemy, bounceRadius - 80) then
						bounceScore = bounceScore + 1
					end
				end
				if bounceScore > bestBounceScore then
					bestBounceUnit = enemyUnit
					bestBounceScore = bounceScore
				end
			end
		end
		if bestBounceUnit ~= nil then
			return BOT_ACTION_DESIRE_HIGH, bestBounceUnit
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidHero(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange + bounceRadius + 100)
			and Fu.CanCastOnNonMagicImmune(botTarget)
		then
			if botTarget:HasModifier("modifier_bounty_hunter_track") then
				for _, enemyUnit in pairs(nearbyEnemyUnits) do
					if
						-- fix: read npcEnemy outside its loop (nil global); the bounce is measured from the target
						Fu.IsInRange(enemyUnit, botTarget, bounceRadius - 100)
						and not enemyUnit:IsMagicImmune()
						and Fu.CanCastOnTargetAdvanced(enemyUnit)
						and not enemyUnit:HasModifier("modifier_bounty_hunter_track")
					then
						return BOT_ACTION_DESIRE_HIGH, enemyUnit
					end
				end
			end
			if Fu.IsInRange(bot, botTarget, castRange) and Fu.CanCastOnTargetAdvanced(botTarget) then
				return BOT_ACTION_DESIRE_HIGH, botTarget
			end
		end
	end
	if (bot:GetActiveMode() == BOT_MODE_LANING or botLevel <= 7 and #nearbyAllies <= 2) and bot:GetMana() >= 150 then
		local nearbyLaneCreeps = bot:GetNearbyLaneCreeps(castRange + 300, true)
		local creepKeyword = "ranged"
		for _, creep in pairs(nearbyLaneCreeps) do
			if
				Fu.IsValid(creep)
				and not creep:HasModifier("modifier_fountain_glyph")
				and Fu.IsKeyWordUnit(creepKeyword, creep)
				and Fu.WillKillTarget(creep, damage, damageType, castPoint + GetUnitToUnitDistance(bot, creep) / 1100)
				and GetUnitToUnitDistance(creep, bot) > 300
			then
				return BOT_ACTION_DESIRE_HIGH, creep
			end
		end
	end
	if
		(Fu.IsPushing(bot) or Fu.IsDefending(bot) or Fu.IsFarming(bot))
		and Fu.IsAllowedToSpam(bot, manaCost * 0.52)
		and (bot:GetAttackDamage() < 300 or mpRatio > 0.7)
		and abilityLevel >= 2
		and DotaTime() > 7 * 60
		and #nearbyAllies <= 2
		and #nearbyEnemies == 0
	then
		local nearbyLaneCreeps = bot:GetNearbyLaneCreeps(castRange + 350, true)
		local creepKeyword = "ranged"
		for _, creep in pairs(nearbyLaneCreeps) do
			if
				Fu.IsValid(creep)
				and Fu.IsKeyWordUnit(creepKeyword, creep)
				and not creep:HasModifier("modifier_fountain_glyph")
				and Fu.WillKillTarget(creep, damage, damageType, castPoint + GetUnitToUnitDistance(bot, creep) / 1100)
				and not Fu.CanKillTarget(creep, bot:GetAttackDamage() * 1.2, DAMAGE_TYPE_PHYSICAL)
			then
				return BOT_ACTION_DESIRE_HIGH, creep
			end
		end
	end
	if Fu.IsFarming(bot) and abilityLevel >= 3 and Fu.IsAllowedToSpam(bot, manaCost) then
		local nearbyNeutrals = bot:GetNearbyNeutralCreeps(castRange + 200)
		local strongestCreep = Fu.GetMostHpUnit(nearbyNeutrals)
		if
			Fu.IsValid(strongestCreep)
			and not Fu.IsRoshan(strongestCreep)
			and (#nearbyNeutrals >= 2 or GetUnitToUnitDistance(strongestCreep, bot) <= 400)
			and bot:IsFacingLocation(strongestCreep:GetLocation(), 40)
			and (strongestCreep:GetMagicResist() < 0.3 or mpRatio > 0.9)
			and not Fu.CanKillTarget(strongestCreep, bot:GetAttackDamage() * 1.68, DAMAGE_TYPE_PHYSICAL)
			and not Fu.CanKillTarget(strongestCreep, damage - 50, damageType)
		then
			return BOT_ACTION_DESIRE_HIGH, strongestCreep
		end
	end
	if bot:GetActiveMode() == BOT_MODE_ROSHAN and bot:GetMana() >= 460 then
		if Fu.IsRoshan(botTarget) and Fu.GetHP(botTarget) > 0.2 and Fu.IsInRange(botTarget, bot, castRange) then
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderShadowWalk()
	if not shadowWalkAbility:IsFullyCastable() then
		return 0
	end
	local abilityLevel = shadowWalkAbility:GetLevel()
	if Fu.IsGoingOnSomeone(bot) and (botLevel >= 7 or DotaTime() > 6 * 60 or abilityLevel >= 2) then
		if
			Fu.IsValidHero(botTarget)
			and Fu.CanCastOnMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, 2500)
			and (not Fu.IsInRange(bot, botTarget, 1000) or Fu.IsChasingTarget(bot, botTarget))
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if
		Fu.IsRetreating(bot)
		and bot:WasRecentlyDamagedByAnyHero(3.0)
		and (#nearbyEnemies >= 1 or hpRatio < 0.2)
		and bot:DistanceFromFountain() > 800
	then
		return BOT_ACTION_DESIRE_HIGH
	end
	-- fix: mpRatio is the mana fraction (0-1), so "mpRatio >= 280" was never true, and "enemyTowers == 0" compared the
	-- tower table with a number. Same rule as hero_bounty_hunter.lua: 280 mana, no enemy hero or tower within 1600.
	if Fu.IsInEnemyArea(bot) and botLevel >= 7 and bot:GetMana() >= 280 and not Fu.IsRealInvisible(bot) then
		local enemyHeroes = Fu.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE)
		local enemyTowers = bot:GetNearbyTowers(1600, true)
		if enemyHeroes ~= nil and #enemyHeroes == 0 and enemyTowers ~= nil and #enemyTowers == 0 then
			if DotaTime() >= lastSneakLogTime + 10 then
				lastSneakLogTime = DotaTime()
				pcall(
					print,
					string.format(
						"[OHA-RUBICK] t=%.0f stolen shadow walk in enemy area mana=%d",
						DotaTime(),
						bot:GetMana()
					)
				)
			end
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderTrack()
	if not trackAbility:IsFullyCastable() then
		return 0
	end
	local castRange = Fu.GetProperCastRange(false, bot, trackAbility:GetCastRange())
	local enemiesInRange = Fu.GetAroundEnemyHeroList(castRange + 100)
	local trackTarget = nil
	local lowestHealth = 999999
	for _, npcEnemy in pairs(enemiesInRange) do
		if
			Fu.IsValidHero(npcEnemy)
			and not npcEnemy:HasModifier("modifier_bounty_hunter_track")
			and not npcEnemy:HasModifier("modifier_arc_warden_tempest_double")
			and Fu.CanCastAbilityOnTarget(npcEnemy, false)
			and Fu.CanCastOnTargetAdvanced(npcEnemy)
			and npcEnemy:GetHealth() < lowestHealth
		then
			trackTarget = npcEnemy
			lowestHealth = npcEnemy:GetHealth()
		end
	end
	if trackTarget ~= nil then
		return BOT_ACTION_DESIRE_HIGH, trackTarget
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderFriendlyShadow()
	if not friendlyShadowAbility:IsTrained() or not friendlyShadowAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castRange = Fu.GetProperCastRange(false, bot, friendlyShadowAbility:GetCastRange())
	local alliesInRange = Fu.GetNearbyHeroes(bot, castRange, false, BOT_MODE_NONE)
	for _, allyHero in pairs(alliesInRange) do
		if
			Fu.IsGoingOnSomeone(allyHero)
			and Fu.IsInRange(bot, allyHero, castRange)
			and Fu.IsNotSelf(bot, allyHero)
			and not Fu.IsRealInvisible(allyHero)
		then
			return BOT_ACTION_DESIRE_HIGH, allyHero
		end
		if
			Fu.IsRetreating(allyHero)
			and allyHero:WasRecentlyDamagedByAnyHero(3.0)
			and allyHero:DistanceFromFountain() > 800
			and Fu.IsInRange(bot, allyHero, castRange)
			and Fu.IsNotSelf(bot, allyHero)
			and not Fu.IsRealInvisible(allyHero)
			and #nearbyEnemies >= 1
		then
			return BOT_ACTION_DESIRE_HIGH, allyHero
		end
		if Fu.IsInEnemyArea(bot) then
			local enemyHeroes = Fu.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE)
			local enemyTowers = bot:GetNearbyTowers(1600, true)
			if
				enemyHeroes ~= nil
				and enemyTowers ~= nil
				and #enemyHeroes == 0
				and #enemyTowers == 0
				and Fu.IsInRange(bot, allyHero, castRange)
				and Fu.IsNotSelf(bot, allyHero)
				and not Fu.IsRealInvisible(allyHero)
			then
				return BOT_ACTION_DESIRE_HIGH, allyHero
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
return X
