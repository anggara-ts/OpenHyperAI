-- How Rubick plays after stealing a spell from Beastmaster.
local bot = GetBot()
local X = {}
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local wildAxesAbility
local callOfTheWildBoarAbility
local callOfTheWildHawkAbility
local primalRoarAbility
local botTarget
local blinkItem
local bkbItem
function X.ConsiderStolenSpell(ability)
	bot = GetBot()
	if Fu.CanNotUseAbility(bot) then
		return
	end
	botTarget = Fu.GetProperTarget(bot)
	local abilityName = ability:GetName()
	if X.HasBlink() and abilityName == "beastmaster_primal_roar" then
		primalRoarAbility = ability
		BlinkRoarDesire, BlinkRoarTarget = X.ConsiderBlinkRoar()
		if BlinkRoarDesire > 0 then
			bot:Action_ClearActions(false)
			if X.CanBKB() then
				bot:ActionQueue_UseAbility(bkbItem)
				bot:ActionQueue_Delay(0.1)
			end
			bot:ActionQueue_UseAbilityOnLocation(blinkItem, BlinkLocation)
			bot:ActionQueue_Delay(0.1)
			bot:ActionQueue_UseAbilityOnEntity(primalRoarAbility, BlinkRoarTarget)
			return
		end
	end
	if abilityName == "beastmaster_primal_roar" then
		primalRoarAbility = ability
		PrimalRoarDesire, PrimalRoarTarget = X.ConsiderPrimalRoar()
		if PrimalRoarDesire > 0 then
			bot:Action_UseAbilityOnEntity(primalRoarAbility, PrimalRoarTarget)
			return
		end
	end
	if abilityName == "beastmaster_summon_razorback" then
		callOfTheWildBoarAbility = ability
		CallOfTheWildBoarDesire = X.ConsiderCallOfTheWildBoar()
		if CallOfTheWildBoarDesire > 0 then
			bot:Action_UseAbility(callOfTheWildBoarAbility)
			return
		end
	end
	if abilityName == "beastmaster_summon_raptor" then
		callOfTheWildHawkAbility = ability
		CallOfTheWildHawkDesire = X.ConsiderCallOfTheWildHawk()
		if CallOfTheWildHawkDesire > 0 then
			bot:Action_UseAbility(callOfTheWildHawkAbility)
			return
		end
	end
	if abilityName == "beastmaster_wild_axes" then
		wildAxesAbility = ability
		WildAxesDesire, WildAxesLocation = X.ConsiderWildAxes()
		if WildAxesDesire > 0 then
			bot:Action_UseAbilityOnLocation(wildAxesAbility, WildAxesLocation)
			return
		end
	end
end
function X.ConsiderWildAxes()
	if not wildAxesAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local castRange = Fu.GetProperCastRange(false, bot, wildAxesAbility:GetCastRange())
	local castPoint = wildAxesAbility:GetCastPoint()
	local mpRatio = bot:GetMana() / bot:GetMaxMana()
	local radius = wildAxesAbility:GetSpecialValueInt("radius")
	local damage = wildAxesAbility:GetSpecialValueInt("axe_damage")
	local enemiesInRange = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(enemiesInRange) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and Fu.CanKillTarget(enemyHero, damage, DAMAGE_TYPE_MAGICAL)
			and not Fu.IsSuspiciousIllusion(enemyHero)
			and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
			and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
			and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
			and not enemyHero:HasModifier("modifier_templar_assassin_refraction_absorb")
		then
			return BOT_ACTION_DESIRE_HIGH, enemyHero:GetExtrapolatedLocation(castPoint)
		end
	end
	if Fu.IsInTeamFight(bot, castRange) then
		local aoeLocation = bot:FindAoELocation(true, true, bot:GetLocation(), castRange, radius, castPoint, 0)
		if aoeLocation.count >= 2 then
			local enemiesInAoe = Fu.GetEnemiesNearLoc(aoeLocation.targetloc, radius)
			if enemiesInAoe ~= nil and #enemiesInAoe >= 2 then
				return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
			end
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, 1000, false, BOT_MODE_NONE)
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not botTarget:HasModifier("modifier_abaddon_borrowed_time")
			and not botTarget:HasModifier("modifier_dazzle_shallow_grave")
			and not botTarget:HasModifier("modifier_templar_assassin_refraction_absorb")
		then
			local targetAllies = Fu.GetNearbyHeroes(botTarget, 1000, false, BOT_MODE_NONE)
			if nearbyAllies ~= nil and targetAllies ~= nil and #nearbyAllies >= #targetAllies then
				return BOT_ACTION_DESIRE_HIGH, botTarget:GetExtrapolatedLocation(castPoint)
			end
		end
	end
	if Fu.IsRetreating(bot) then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, 800, false, BOT_MODE_NONE)
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, 800, true, BOT_MODE_NONE)
		if
			nearbyAllies ~= nil
			and nearbyEnemies
			and Fu.IsValidHero(nearbyEnemies[1])
			and Fu.CanCastOnNonMagicImmune(nearbyEnemies[1])
			and Fu.IsInRange(bot, nearbyEnemies[1], 600)
			and Fu.IsRunning(nearbyEnemies[1])
			and nearbyEnemies[1]:IsFacingLocation(bot:GetLocation(), 30)
			and not Fu.IsSuspiciousIllusion(nearbyEnemies[1])
		then
			local chaserAllies = Fu.GetNearbyHeroes(nearbyEnemies[1], 800, false, BOT_MODE_NONE)
			if
				chaserAllies ~= nil
				and (#chaserAllies > #nearbyAllies or Fu.GetHP(bot) < 0.57 and bot:WasRecentlyDamagedByAnyHero(2.7))
			then
				return BOT_ACTION_DESIRE_HIGH, nearbyEnemies[1]:GetExtrapolatedLocation(castPoint)
			end
		end
	end
	if Fu.IsPushing(bot) or Fu.IsDefending(bot) then
		local aoeLocation = bot:FindAoELocation(true, false, bot:GetLocation(), castRange, radius, castPoint, 0)
		if aoeLocation.count >= 4 then
			return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
		end
		aoeLocation = bot:FindAoELocation(true, false, bot:GetLocation(), castRange, radius, castPoint, 0)
		if aoeLocation.count >= 2 then
			return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
		end
	end
	if Fu.IsFarming(bot) then
		local laneCreeps = bot:GetNearbyLaneCreeps(800, true)
		local aoeLocation = bot:FindAoELocation(true, false, bot:GetLocation(), 800, radius, 0, 0)
		if Fu.IsAttacking(bot) then
			if laneCreeps ~= nil and #laneCreeps >= 3 and aoeLocation.count >= 3 then
				return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
			end
			local neutralCreeps = bot:GetNearbyNeutralCreeps(600)
			if
				neutralCreeps ~= nil
				and (#neutralCreeps >= 3 and aoeLocation.count >= 3 or #neutralCreeps >= 2 and aoeLocation.count >= 2 and neutralCreeps[1]:IsAncientCreep())
				and mpRatio > 0.27
			then
				return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
			end
		end
	end
	if Fu.IsLaning(bot) then
		local killableCount = 0
		local killableCreeps = {}
		local laneCreeps = bot:GetNearbyLaneCreeps(castRange, true)
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
		for _, creep in pairs(laneCreeps) do
			if Fu.IsValid(creep) and creep:GetHealth() <= damage then
				killableCount = killableCount + 1
				table.insert(killableCreeps, creep)
			end
		end
		if killableCount >= 2 and Fu.GetMP(bot) > 0.25 and nearbyEnemies ~= nil and #nearbyEnemies >= 1 then
			return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(killableCreeps)
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if
			Fu.IsRoshan(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, 500)
			and Fu.IsAttacking(bot)
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, 400) and Fu.IsAttacking(bot) then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.ConsiderCallOfTheWildBoar()
	if not callOfTheWildBoarAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
	end
	local attackRange = bot:GetAttackRange()
	if Fu.IsGoingOnSomeone(bot) then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, 800, false, BOT_MODE_NONE)
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, 800, true, BOT_MODE_NONE)
		if
			Fu.IsValidTarget(botTarget)
			and Fu.IsInRange(bot, botTarget, 800)
			and not Fu.IsInRange(bot, botTarget, attackRange)
			and nearbyAllies ~= nil
			and nearbyEnemies
			and #nearbyAllies >= #nearbyEnemies
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsPushing(bot) or Fu.IsDefending(bot) then
		if Fu.IsAttacking(bot) then
			local laneCreeps = bot:GetNearbyLaneCreeps(700, true)
			if laneCreeps ~= nil and #laneCreeps >= 4 then
				return BOT_ACTION_DESIRE_HIGH
			end
			local enemyTowers = bot:GetNearbyTowers(700, true)
			if enemyTowers ~= nil and #enemyTowers > 0 then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	if Fu.IsFarming(bot) and Fu.GetMP(bot) > 0.33 then
		local neutralCreeps = bot:GetNearbyNeutralCreeps(attackRange + 75)
		local laneCreeps = bot:GetNearbyLaneCreeps(attackRange + 75, true)
		if Fu.IsAttacking(bot) then
			if
				neutralCreeps ~= nil
				and (#neutralCreeps >= 3 or #neutralCreeps >= 2 and neutralCreeps[1]:IsAncientCreep())
			then
				return BOT_ACTION_DESIRE_HIGH
			end
			if laneCreeps ~= nil and #laneCreeps >= 3 then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if Fu.IsRoshan(botTarget) and Fu.IsInRange(bot, botTarget, 400) and Fu.IsAttacking(bot) then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, 400) and Fu.IsAttacking(bot) then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderCallOfTheWildHawk()
	if not callOfTheWildHawkAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
	end
	if Fu.IsInTeamFight(bot, 1200) then
		local aoeLocation = bot:FindAoELocation(true, true, bot:GetLocation(), 500, 500, 0, 0)
		if aoeLocation.count >= 2 then
			local enemiesInAoe = Fu.GetEnemiesNearLoc(aoeLocation.targetloc, 500)
			if enemiesInAoe ~= nil and #enemiesInAoe >= 2 then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, 800, false, BOT_MODE_NONE)
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, 450)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not Fu.IsDisabled(botTarget)
			and not Fu.IsTaunted(botTarget)
			and not botTarget:HasModifier("modifier_abaddon_borrowed_time")
			and not botTarget:HasModifier("modifier_dazzle_shallow_grave")
			and not botTarget:HasModifier("modifier_templar_assassin_refraction_absorb")
		then
			local targetAllies = Fu.GetNearbyHeroes(botTarget, 800, false, BOT_MODE_NONE)
			if nearbyAllies ~= nil and targetAllies ~= nil and #nearbyAllies >= #targetAllies then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	if Fu.IsRetreating(bot) then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, 800, false, BOT_MODE_NONE)
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, 800, true, BOT_MODE_NONE)
		if
			nearbyAllies ~= nil
			and nearbyEnemies
			and Fu.IsValidHero(nearbyEnemies[1])
			and Fu.CanCastOnNonMagicImmune(nearbyEnemies[1])
			and Fu.IsInRange(bot, nearbyEnemies[1], 450)
			and Fu.IsRunning(nearbyEnemies[1])
			and nearbyEnemies[1]:IsFacingLocation(bot:GetLocation(), 30)
			and not Fu.IsSuspiciousIllusion(nearbyEnemies[1])
		then
			local chaserAllies = Fu.GetNearbyHeroes(nearbyEnemies[1], 800, false, BOT_MODE_NONE)
			if
				chaserAllies ~= nil
				and (#chaserAllies > #nearbyAllies or Fu.GetHP(bot) < 0.57 and bot:WasRecentlyDamagedByAnyHero(2.7))
			then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderPrimalRoar()
	if not primalRoarAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castRange = Fu.GetProperCastRange(false, bot, primalRoarAbility:GetCastRange())
	local duration = primalRoarAbility:GetSpecialValueInt("duration")
	local damage = primalRoarAbility:GetSpecialValueInt("damage")
	local enemiesInRange = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(enemiesInRange) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanCastOnMagicImmune(enemyHero)
			and Fu.CanCastOnTargetAdvanced(enemyHero)
			and not Fu.IsSuspiciousIllusion(enemyHero)
		then
			if Fu.IsCastingUltimateAbility(enemyHero) then
				return BOT_ACTION_DESIRE_HIGH, enemyHero
			end
			if
				Fu.CanKillTarget(enemyHero, damage, DAMAGE_TYPE_MAGICAL)
				and Fu.IsRunning(enemyHero)
				and bot:IsFacingLocation(enemyHero:GetLocation(), 30)
				and not enemyHero:IsFacingLocation(bot:GetLocation(), 30)
				and not wildAxesAbility:IsFullyCastable()
				and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
				and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
				and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
				and not enemyHero:HasModifier("modifier_templar_assassin_refraction_absorb")
			then
				return BOT_ACTION_DESIRE_HIGH, enemyHero
			end
		end
	end
	if Fu.IsInTeamFight(bot, 1200) then
		local strongestEnemy = Fu.GetStrongestUnit(castRange, bot, true, false, duration)
		if strongestEnemy == nil then
			strongestEnemy = Fu.GetStrongestUnit(1199, bot, true, true, duration)
		end
		if
			Fu.IsValidTarget(strongestEnemy)
			and Fu.CanCastOnMagicImmune(strongestEnemy)
			and Fu.CanCastOnTargetAdvanced(strongestEnemy)
			and Fu.GetHP(strongestEnemy) > 0.5
			and not Fu.IsSuspiciousIllusion(strongestEnemy)
			and not Fu.IsDisabled(strongestEnemy)
			and not Fu.IsTaunted(strongestEnemy)
			and not strongestEnemy:HasModifier("modifier_faceless_void_chronosphere_freeze")
			and not strongestEnemy:HasModifier("modifier_enigma_black_hole_pull")
			and not strongestEnemy:HasModifier("modifier_legion_commander_duel")
			and not strongestEnemy:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			return BOT_ACTION_DESIRE_HIGH, strongestEnemy
		end
	end
	if Fu.IsGoingOnSomeone(bot) and not X.CanDoBlinkRoar() then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, 800, false, BOT_MODE_NONE)
		local enemiesInRange = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
		for _, enemyHero in pairs(enemiesInRange) do
			if
				Fu.IsValidTarget(enemyHero)
				and Fu.CanCastOnMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
				and Fu.GetHP(enemyHero) > 0.5
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and not Fu.IsDisabled(enemyHero)
				and not Fu.IsTaunted(enemyHero)
				and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
				and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
				and not enemyHero:HasModifier("modifier_enigma_black_hole_pull")
				and not enemyHero:HasModifier("modifier_faceless_void_chronosphere_freeze")
				and not enemyHero:HasModifier("modifier_legion_commander_duel")
				and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
			then
				local targetAllies = Fu.GetNearbyHeroes(enemyHero, 800, false, BOT_MODE_NONE)
				if nearbyAllies ~= nil and targetAllies ~= nil and #nearbyAllies >= #targetAllies then
					return BOT_ACTION_DESIRE_HIGH, enemyHero
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function X.ConsiderBlinkRoar()
	if X.CanDoBlinkRoar() then
		local duration = primalRoarAbility:GetSpecialValueInt("duration")
		if Fu.IsGoingOnSomeone(bot) then
			local nearbyAllies = Fu.GetNearbyHeroes(bot, 1200, false, BOT_MODE_NONE)
			local strongestEnemy = Fu.GetStrongestUnit(1199, bot, true, false, duration)
			if strongestEnemy == nil then
				strongestEnemy = Fu.GetStrongestUnit(1199, bot, true, true, duration)
			end
			if
				Fu.IsValidTarget(strongestEnemy)
				and Fu.CanCastOnNonMagicImmune(strongestEnemy)
				and Fu.CanCastOnTargetAdvanced(strongestEnemy)
				and Fu.IsInRange(bot, strongestEnemy, 1199)
				and Fu.GetHP(strongestEnemy) > 0.5
				and not Fu.IsSuspiciousIllusion(strongestEnemy)
				and not Fu.IsDisabled(strongestEnemy)
				and not Fu.IsTaunted(strongestEnemy)
				and not strongestEnemy:HasModifier("modifier_abaddon_borrowed_time")
				and not strongestEnemy:HasModifier("modifier_dazzle_shallow_grave")
				and not strongestEnemy:HasModifier("modifier_enigma_black_hole_pull")
				and not strongestEnemy:HasModifier("modifier_faceless_void_chronosphere_freeze")
				and not strongestEnemy:HasModifier("modifier_legion_commander_duel")
				and not strongestEnemy:HasModifier("modifier_necrolyte_reapers_scythe")
			then
				local targetAllies = Fu.GetNearbyHeroes(strongestEnemy, 1200, false, BOT_MODE_NONE)
				if nearbyAllies ~= nil and targetAllies ~= nil and #nearbyAllies >= #targetAllies then
					bot.shouldBlink = true
					BlinkLocation = strongestEnemy:GetLocation()
					return BOT_ACTION_DESIRE_HIGH, strongestEnemy
				end
			end
		end
	end
	bot.shouldBlink = false
	return BOT_ACTION_DESIRE_NONE, nil
end
function X.CanDoBlinkRoar()
	if primalRoarAbility:IsFullyCastable() and X.HasBlink() then
		local manaCost = primalRoarAbility:GetManaCost()
		if bot:GetMana() >= manaCost then
			return true
		end
	end
	return false
end
function X.HasBlink()
	local blink = nil
	for slot = 0, 5 do
		local item = bot:GetItemInSlot(slot)
		if
			item ~= nil
			and (
				item:GetName() == "item_blink"
				or item:GetName() == "item_overwhelming_blink"
				or item:GetName() == "item_arcane_blink"
				or item:GetName() == "item_swift_blink"
			)
		then
			blink = item
			break
		end
	end
	if blink ~= nil and blink:IsFullyCastable() then
		blinkItem = blink
		return true
	end
	return false
end
function X.CanBKB()
	local bkb = nil
	for slot = 0, 5 do
		local item = bot:GetItemInSlot(slot)
		if item ~= nil and item:GetName() == "item_black_king_bar" then
			bkb = item
			break
		end
	end
	if bkb ~= nil and bkb:IsFullyCastable() and bot:GetMana() >= 75 then
		bkbItem = bkb
		return true
	end
	return false
end
return X
