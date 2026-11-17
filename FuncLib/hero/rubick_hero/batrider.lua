-- How Rubick plays after stealing a spell from Batrider.
local bot = GetBot()
local X = {}
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local stickyNapalmAbility
local flamebreakAbility
local fireflyAbility
local flamingLassoAbility
local blinkLassoDesire
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
	if X.HasBlink() and abilityName == "batrider_flaming_lasso" then
		flamingLassoAbility = ability
		blinkLassoDesire, BlinkLassoTarget = X.ConsiderBlinkLasso()
		if blinkLassoDesire > 0 then
			bot:Action_ClearActions(false)
			FireflyDesire = X.ConsiderFirefly()
			if FireflyDesire > 0 then
				bot:ActionQueue_UseAbility(fireflyAbility)
				bot:ActionQueue_Delay(0.1)
			end
			if X.CanBKB() then
				bot:ActionQueue_UseAbility(bkbItem)
				bot:ActionQueue_Delay(0.1)
			end
			bot:ActionQueue_UseAbilityOnLocation(blinkItem, BlinkLassoTarget:GetLocation())
			bot:ActionQueue_Delay(0.1)
			bot:ActionQueue_UseAbilityOnEntity(flamingLassoAbility, BlinkLassoTarget)
			return
		end
	end
	if abilityName == "batrider_firefly" then
		fireflyAbility = ability
		FireflyDesire = X.ConsiderFirefly()
		if FireflyDesire > 0 then
			bot:Action_UseAbility(fireflyAbility)
			return
		end
	end
	if abilityName == "batrider_flaming_lasso" then
		flamingLassoAbility = ability
		FlamingLassoDesire, FlamingLassoTarget = X.ConsiderFlamingLasso()
		if FlamingLassoDesire > 0 then
			bot:Action_UseAbilityOnEntity(flamingLassoAbility, FlamingLassoTarget)
			return
		end
	end
	if abilityName == "batrider_flamebreak" then
		flamebreakAbility = ability
		FlamebreakDesire, FlamebreakLocation = X.ConsiderFlamebreak()
		if FlamebreakDesire > 0 then
			bot:Action_UseAbilityOnLocation(flamebreakAbility, FlamebreakLocation)
			return
		end
	end
	if abilityName == "batrider_sticky_napalm" then
		stickyNapalmAbility = ability
		StickyNapalmDesire, StickyNapalmLocation = X.ConsiderStickyNapalm()
		if StickyNapalmDesire > 0 then
			bot:Action_UseAbilityOnLocation(stickyNapalmAbility, StickyNapalmLocation)
			return
		end
	end
end
function X.ConsiderStickyNapalm()
	if not stickyNapalmAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local castRange = Fu.GetProperCastRange(false, bot, stickyNapalmAbility:GetCastRange())
	local castPoint = stickyNapalmAbility:GetCastPoint()
	local radius = stickyNapalmAbility:GetSpecialValueInt("radius")
	local mpRatio = bot:GetMana() / bot:GetMaxMana()
	if Fu.IsGoingOnSomeone(bot) then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, 800, false, BOT_MODE_NONE)
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not botTarget:HasModifier("modifier_abaddon_borrowed_time")
			and not botTarget:HasModifier("modifier_dazzle_shallow_grave")
		then
			local targetAllies = Fu.GetNearbyHeroes(botTarget, 800, false, BOT_MODE_NONE)
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
			and Fu.IsInRange(bot, nearbyEnemies[1], 350)
			and Fu.IsRunning(nearbyEnemies[1])
			and nearbyEnemies[1]:IsFacingLocation(bot:GetLocation(), 30)
			and not Fu.IsSuspiciousIllusion(nearbyEnemies[1])
		then
			local enemyAllies = Fu.GetNearbyHeroes(nearbyEnemies[1], 800, false, BOT_MODE_NONE)
			if
				enemyAllies ~= nil
				and (#enemyAllies > #nearbyAllies or Fu.GetHP(bot) < 0.57 and bot:WasRecentlyDamagedByAnyHero(2.7))
			then
				return BOT_ACTION_DESIRE_HIGH, nearbyEnemies[1]:GetExtrapolatedLocation(castPoint)
			end
		end
	end
	if Fu.IsDefending(bot) or Fu.IsPushing(bot) then
		local nearbyLaneCreeps = bot:GetNearbyLaneCreeps(castRange, true)
		local aoeLocation = bot:FindAoELocation(true, false, bot:GetLocation(), castRange, radius, 0, 0)
		if nearbyLaneCreeps ~= nil and #nearbyLaneCreeps >= 4 and aoeLocation.count >= 4 then
			return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
		end
		aoeLocation = bot:FindAoELocation(true, true, bot:GetLocation(), castRange, radius, castPoint, 0)
		if aoeLocation.count >= 1 then
			return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
		end
	end
	if Fu.IsFarming(bot) and mpRatio > 0.49 then
		local nearbyNeutralCreeps = bot:GetNearbyNeutralCreeps(castRange)
		local aoeLocation = bot:FindAoELocation(true, false, bot:GetLocation(), castRange, radius, 0, 0)
		if nearbyNeutralCreeps ~= nil and #nearbyNeutralCreeps >= 2 and aoeLocation.count >= 2 then
			return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
		end
		local nearbyLaneCreeps = bot:GetNearbyLaneCreeps(castRange, true)
		if nearbyLaneCreeps ~= nil and #nearbyLaneCreeps >= 3 and aoeLocation.count >= 3 then
			return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
		end
	end
	if Fu.IsLaning(bot) and mpRatio > 0.68 then
		local nearbyLaneCreeps = bot:GetNearbyLaneCreeps(castRange, true)
		local aoeLocation = bot:FindAoELocation(true, false, bot:GetLocation(), castRange, radius, 0, 0)
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
		if nearbyEnemies ~= nil and #nearbyEnemies >= 1 then
			local enemyLaneCreeps = nearbyEnemies[1]:GetNearbyLaneCreeps(castRange / 2, false)
			if enemyLaneCreeps ~= nil and #enemyLaneCreeps >= 2 then
				return BOT_ACTION_DESIRE_HIGH, nearbyEnemies[1]:GetExtrapolatedLocation(castPoint)
			end
		end
		if nearbyLaneCreeps ~= nil and #nearbyLaneCreeps >= 3 and aoeLocation.count >= 3 then
			return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if
			Fu.IsRoshan(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and Fu.IsAttacking(bot)
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if
			Fu.IsTormentor(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and Fu.IsAttacking(bot)
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.ConsiderFlamebreak()
	if not flamebreakAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local castRange = Fu.GetProperCastRange(false, bot, flamebreakAbility:GetCastRange())
	local castPoint = flamebreakAbility:GetCastPoint()
	local radius = flamebreakAbility:GetSpecialValueInt("explosion_radius")
	local speed = flamebreakAbility:GetSpecialValueInt("speed")
	local damage = flamebreakAbility:GetSpecialValueInt("damage_impact")
	local enemiesInRange = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(enemiesInRange) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and Fu.IsInRange(bot, enemyHero, castRange)
			and Fu.CanKillTarget(enemyHero, damage, DAMAGE_TYPE_MAGICAL)
			and not Fu.IsSuspiciousIllusion(enemyHero)
			and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
			and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
			and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
			and not enemyHero:HasModifier("modifier_templar_assassin_refraction_absorb")
		then
			local delay = GetUnitToUnitDistance(bot, enemyHero) / speed + castPoint
			return BOT_ACTION_DESIRE_HIGH, enemyHero:GetExtrapolatedLocation(delay)
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, 800, false, BOT_MODE_NONE)
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not botTarget:HasModifier("modifier_abaddon_borrowed_time")
			and not botTarget:HasModifier("modifier_dazzle_shallow_grave")
			and not botTarget:HasModifier("modifier_enigma_black_hole_pull")
			and not botTarget:HasModifier("modifier_faceless_void_chronosphere_freeze")
			and not botTarget:HasModifier("modifier_legion_commander_duel")
		then
			local targetAllies = Fu.GetNearbyHeroes(botTarget, 800, false, BOT_MODE_NONE)
			if nearbyAllies ~= nil and targetAllies ~= nil and #nearbyAllies >= #targetAllies then
				local delay = GetUnitToUnitDistance(bot, botTarget) / speed + castPoint
				return BOT_ACTION_DESIRE_HIGH, botTarget:GetExtrapolatedLocation(delay)
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
			and Fu.IsInRange(bot, nearbyEnemies[1], 350)
			and Fu.IsRunning(nearbyEnemies[1])
			and nearbyEnemies[1]:IsFacingLocation(bot:GetLocation(), 30)
			and not Fu.IsSuspiciousIllusion(nearbyEnemies[1])
		then
			local enemyAllies = Fu.GetNearbyHeroes(nearbyEnemies[1], 800, false, BOT_MODE_NONE)
			if
				enemyAllies ~= nil
				and (#enemyAllies > #nearbyAllies or Fu.GetHP(bot) < 0.57 and bot:WasRecentlyDamagedByAnyHero(2.7))
			then
				if GetUnitToUnitDistance(bot, nearbyEnemies[1]) < radius - 50 then
					return BOT_ACTION_DESIRE_HIGH, bot:GetLocation()
				else
					local delay = GetUnitToUnitDistance(bot, nearbyEnemies[1]) / speed + castPoint
					return BOT_ACTION_DESIRE_HIGH, nearbyEnemies[1]:GetExtrapolatedLocation(delay)
				end
			end
		end
	end
	if Fu.IsDefending(bot) then
		local aoeLocation = bot:FindAoELocation(true, true, bot:GetLocation(), castRange, radius, castPoint, 0)
		if aoeLocation.count >= 1 then
			return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
		end
	end
	if Fu.IsLaning(bot) and Fu.GetMP(bot) > 0.39 then
		local killableCount = 0
		local killableCreeps = {}
		local nearbyLaneCreeps = bot:GetNearbyLaneCreeps(castRange, true)
		for _, creep in pairs(nearbyLaneCreeps) do
			if Fu.IsValid(creep) and creep:GetHealth() <= damage then
				killableCount = killableCount + 1
				table.insert(killableCreeps, creep)
			end
		end
		if killableCount >= 2 then
			return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(killableCreeps)
		end
	end
	local alliesInRange = Fu.GetNearbyHeroes(bot, castRange, false, BOT_MODE_NONE)
	for _, allyHero in pairs(alliesInRange) do
		local enemiesNearAlly = Fu.GetNearbyHeroes(allyHero, castRange, true, BOT_MODE_NONE)
		if
			Fu.IsRetreating(allyHero)
			and allyHero:WasRecentlyDamagedByAnyHero(2.1)
			and not allyHero:IsIllusion()
			and Fu.GetMP(bot) > 0.48
		then
			if
				enemiesNearAlly ~= nil
				and #enemiesNearAlly >= 1
				and Fu.IsValidHero(enemiesNearAlly[1])
				and Fu.CanCastOnNonMagicImmune(enemiesNearAlly[1])
				and Fu.IsInRange(allyHero, enemiesNearAlly[1], 400)
				and Fu.IsInRange(bot, enemiesNearAlly[1], castRange)
				and Fu.IsRunning(allyHero)
				and enemiesNearAlly[1]:IsFacingLocation(allyHero:GetLocation(), 30)
				and not Fu.IsDisabled(enemiesNearAlly[1])
				and not Fu.IsTaunted(enemiesNearAlly[1])
				and not Fu.IsSuspiciousIllusion(enemiesNearAlly[1])
				and not enemiesNearAlly[1]:HasModifier("modifier_enigma_black_hole_pull")
				and not enemiesNearAlly[1]:HasModifier("modifier_faceless_void_chronosphere_freeze")
			then
				local delay = GetUnitToUnitDistance(bot, botTarget) / speed + castPoint
				return BOT_ACTION_DESIRE_HIGH, enemiesNearAlly[1]:GetExtrapolatedLocation(delay + castPoint)
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.ConsiderFirefly()
	if not fireflyAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
	end
	if Fu.IsStuck(bot) or bot:HasModifier("modifier_batrider_flaming_lasso_self") or blinkLassoDesire > 0 then
		return BOT_ACTION_DESIRE_HIGH
	end
	if Fu.IsGoingOnSomeone(bot) then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, 800, false, BOT_MODE_NONE)
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, 800)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not botTarget:HasModifier("modifier_abaddon_borrowed_time")
			and not botTarget:HasModifier("modifier_dazzle_shallow_grave")
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
			and Fu.IsInRange(bot, nearbyEnemies[1], 350)
			and Fu.IsRunning(nearbyEnemies[1])
			and nearbyEnemies[1]:IsFacingLocation(bot:GetLocation(), 30)
			and not Fu.IsSuspiciousIllusion(nearbyEnemies[1])
		then
			local enemyAllies = Fu.GetNearbyHeroes(nearbyEnemies[1], 800, false, BOT_MODE_NONE)
			if
				enemyAllies ~= nil
				and (#enemyAllies > #nearbyAllies or Fu.GetHP(bot) < 0.57 and bot:WasRecentlyDamagedByAnyHero(2.1))
			then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderFlamingLasso()
	if not flamingLassoAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
	end
	local castRange = Fu.GetProperCastRange(false, bot, flamingLassoAbility:GetCastRange() + bot:GetAttackRange())
	if Fu.IsGoingOnSomeone(bot) and not X.CanDoBlinkLasso() then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, 800, false, BOT_MODE_NONE)
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValidTarget(enemyHero)
				and Fu.CanCastOnMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and not Fu.IsTaunted(enemyHero)
				and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
				and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
				and not enemyHero:HasModifier("modifier_enigma_black_hole_pull")
				and not enemyHero:HasModifier("modifier_faceless_void_chronosphere_freeze")
				and not enemyHero:HasModifier("modifier_legion_commander_duel")
				and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
			then
				local enemyAllies = Fu.GetNearbyHeroes(enemyHero, 800, false, BOT_MODE_NONE)
				if nearbyAllies ~= nil and enemyAllies ~= nil and #nearbyAllies >= #enemyAllies then
					return BOT_ACTION_DESIRE_HIGH, enemyHero
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function X.ConsiderBlinkLasso()
	if X.CanDoBlinkLasso() then
		local duration = flamingLassoAbility:GetSpecialValueInt("duration")
		if Fu.IsGoingOnSomeone(bot) then
			local nearbyAllies = Fu.GetNearbyHeroes(bot, 1199, false, BOT_MODE_NONE)
			local lassoTarget = Fu.GetStrongestUnit(1199, bot, true, false, duration)
			if lassoTarget == nil then
				lassoTarget = Fu.GetStrongestUnit(1199, bot, true, true, duration)
			end
			if
				Fu.IsValidTarget(lassoTarget)
				and Fu.CanCastOnMagicImmune(lassoTarget)
				and Fu.CanCastOnTargetAdvanced(lassoTarget)
				and Fu.IsInRange(bot, lassoTarget, 1199)
				and not Fu.IsSuspiciousIllusion(lassoTarget)
				and not Fu.IsTaunted(lassoTarget)
				and not lassoTarget:HasModifier("modifier_abaddon_borrowed_time")
				and not lassoTarget:HasModifier("modifier_dazzle_shallow_grave")
				and not lassoTarget:HasModifier("modifier_enigma_black_hole_pull")
				and not lassoTarget:HasModifier("modifier_faceless_void_chronosphere_freeze")
				and not lassoTarget:HasModifier("modifier_legion_commander_duel")
				and not lassoTarget:HasModifier("modifier_necrolyte_reapers_scythe")
			then
				local targetAllies = Fu.GetNearbyHeroes(lassoTarget, 1199, false, BOT_MODE_NONE)
				if nearbyAllies ~= nil and targetAllies ~= nil and #nearbyAllies >= #targetAllies then
					bot.shouldBlink = true
					BlinkLocation = lassoTarget:GetLocation()
					return BOT_ACTION_DESIRE_HIGH, lassoTarget
				end
			end
		end
	end
	bot.shouldBlink = false
	return BOT_ACTION_DESIRE_NONE, nil
end
function X.CanDoBlinkLasso()
	if flamingLassoAbility:IsFullyCastable() and X.HasBlink() then
		local manaCost = flamingLassoAbility:GetManaCost()
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
