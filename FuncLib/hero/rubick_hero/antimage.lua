-- How Rubick plays after stealing a spell from Antimage.
local bot = GetBot()
local X = {}
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local blinkAbility
local counterspellAbility
local counterspellAllyAbility
local manaOverloadAbility
local manaVoidAbility
local botTarget
local lastBlinkFragmentLogTime = -999
function X.ConsiderStolenSpell(ability)
	bot = GetBot()
	if Fu.CanNotUseAbility(bot) then
		return
	end
	botTarget = Fu.GetProperTarget(bot)
	local abilityName = ability:GetName()
	if abilityName == "antimage_counterspell" then
		counterspellAbility = ability
		CounterSpellDesire = X.ConsiderCounterSpell()
		if CounterSpellDesire > 0 then
			Fu.SetQueuePtToINT(bot, false)
			bot:ActionQueue_UseAbility(counterspellAbility)
			return
		end
	end
	if abilityName == "antimage_mana_overload" then
		manaOverloadAbility = ability
		BlinkFragmentDesire, BlinkFragmentLocation = X.ConsiderBlinkFragment()
		if BlinkFragmentDesire > 0 then
			bot:Action_UseAbilityOnLocation(manaOverloadAbility, BlinkFragmentLocation)
			return
		end
	end
	if abilityName == "antimage_blink" then
		blinkAbility = ability
		BlinkDesire, BlinkLocation = X.ConsiderBlink()
		if BlinkDesire > 0 then
			Fu.SetQueuePtToINT(bot, false)
			bot:ActionQueue_UseAbilityOnLocation(blinkAbility, BlinkLocation)
			return
		end
	end
	if abilityName == "antimage_mana_void" then
		manaVoidAbility = ability
		ManaVoidDesire, ManaVoidTarget = X.ConsiderManaVoid()
		if ManaVoidDesire > 0 then
			Fu.SetQueuePtToINT(bot, false)
			bot:ActionQueue_UseAbilityOnEntity(manaVoidAbility, ManaVoidTarget)
			return
		end
	end
	if abilityName == "antimage_counterspell_ally" then
		counterspellAllyAbility = ability
		CounterSpellAllyDesire, CounterSpellAllyTarget = X.ConsiderCounterSpellAlly()
		if CounterSpellAllyDesire > 0 then
			Fu.SetQueuePtToINT(bot, false)
			bot:ActionQueue_UseAbilityOnEntity(counterspellAllyAbility, CounterSpellAllyTarget)
			return
		end
	end
end
function X.ConsiderBlink()
	if not blinkAbility:IsFullyCastable() or bot:IsRooted() or bot:HasModifier("modifier_bloodseeker_rupture") then
		return BOT_ACTION_DESIRE_NONE
	end
	local castRange = blinkAbility:GetSpecialValueInt("AbilityCastRange") - 1
	local castPoint = blinkAbility:GetCastPoint()
	local attackPoint = bot:GetAttackPoint()
	if Fu.IsStuck(bot) then
		local escapeLocation = Fu.GetEscapeLoc()
		return BOT_ACTION_DESIRE_HIGH, Fu.Site.GetXUnitsTowardsLocation(bot, escapeLocation, castRange)
	end
	if
		(Fu.IsStunProjectileIncoming(bot, 600) or Fu.IsUnitTargetProjectileIncoming(bot, 400))
		and counterspellAbility ~= nil
		and not counterspellAbility:IsFullyCastable()
	then
		return BOT_ACTION_DESIRE_HIGH, Fu.Site.GetXUnitsTowardsLocation(bot, Fu.GetTeamFountain(), castRange)
	end
	if
		not bot:HasModifier("modifier_sniper_assassinate")
		and not bot:IsMagicImmune()
		and counterspellAbility ~= nil
		and not counterspellAbility:IsFullyCastable()
	then
		if Fu.IsWillBeCastUnitTargetSpell(bot, 400) then
			return BOT_ACTION_DESIRE_HIGH, Fu.Site.GetXUnitsTowardsLocation(bot, Fu.GetTeamFountain(), castRange)
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnMagicImmune(botTarget)
			and not Fu.IsInRange(bot, botTarget, 400)
			and not botTarget:IsAttackImmune()
			and not botTarget:HasModifier("modifier_abaddon_borrowed_time")
			and not botTarget:HasModifier("modifier_faceless_void_chronosphere_freeze")
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			local targetNearbyEnemies = Fu.GetNearbyHeroes(botTarget, 1200, true, BOT_MODE_NONE)
			local targetNearbyAllies = Fu.GetNearbyHeroes(botTarget, 1200, false, BOT_MODE_NONE)
			if
				targetNearbyEnemies ~= nil
				and targetNearbyAllies ~= nil
				and #targetNearbyEnemies >= #targetNearbyAllies
			then
				local blinkLocation = botTarget:GetExtrapolatedLocation(castPoint + 0.53)
				if GetUnitToUnitDistance(bot, botTarget) > castRange then
					blinkLocation = Fu.Site.GetXUnitsTowardsLocation(bot, botTarget:GetLocation(), castRange)
				end
				if Fu.IsInLaningPhase() then
					local targetTowers = botTarget:GetNearbyTowers(700, false)
					if
						targetTowers ~= nil and #targetTowers == 0
						or bot:GetHealth() > Fu.GetTotalEstimatedDamageToTarget(targetNearbyAllies, bot)
							and Fu.WillKillTarget(botTarget, bot:GetAttackDamage() * 3, DAMAGE_TYPE_PHYSICAL, 2)
					then
						bot:SetTarget(botTarget)
						return BOT_ACTION_DESIRE_HIGH, blinkLocation
					end
				else
					bot:SetTarget(botTarget)
					return BOT_ACTION_DESIRE_HIGH, blinkLocation
				end
			end
		end
	end
	if Fu.IsRetreating(bot) then
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE)
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValidHero(enemyHero)
				and bot:DistanceFromFountain() > 600
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and not Fu.IsDisabled(enemyHero)
				and not Fu.IsRealInvisible(bot)
			then
				local enemyNearbyEnemies = Fu.GetNearbyHeroes(enemyHero, 1200, true, BOT_MODE_NONE)
				local enemyNearbyAllies = Fu.GetNearbyHeroes(enemyHero, 1200, false, BOT_MODE_NONE)
				if
					enemyNearbyEnemies ~= nil
					and enemyNearbyAllies ~= nil
					and (
						#enemyNearbyAllies > #enemyNearbyEnemies
						or bot:WasRecentlyDamagedByAnyHero(2)
						or Fu.GetHP(bot) < 0.2 and Fu.IsChasingTarget(enemyHero, bot)
					)
				then
					return BOT_ACTION_DESIRE_HIGH,
						Fu.Site.GetXUnitsTowardsLocation(bot, Fu.GetTeamFountain(), castRange)
				end
			end
		end
	end
	if Fu.IsLaning(bot) then
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE)
		local nearbyEnemyTowers = bot:GetNearbyTowers(1600, true)
		if
			Fu.GetManaAfter(blinkAbility:GetManaCost()) > 0.85
			and Fu.IsInLaningPhase()
			and bot:DistanceFromFountain() > 300
			and bot:DistanceFromFountain() < 6000
			and nearbyEnemies ~= nil
			and #nearbyEnemies == 0
			and nearbyEnemyTowers ~= nil
			and #nearbyEnemyTowers == 0
		then
			local assignedLane = bot:GetAssignedLane()
			local laneFront = GetLaneFrontLocation(GetTeam(), assignedLane, 0)
			local distanceToLaneFront = GetUnitToLocationDistance(bot, laneFront)
			if distanceToLaneFront > castRange then
				local blinkLocation = Fu.Site.GetXUnitsTowardsLocation(bot, laneFront, castRange)
				if IsLocationPassable(blinkLocation) then
					return BOT_ACTION_DESIRE_HIGH, blinkLocation
				end
			end
		end
	end
	if Fu.IsPushing(bot) and bot:GetActiveModeDesire() > BOT_MODE_DESIRE_HIGH then
		local nearbyAllies = Fu.GetAlliesNearLoc(bot:GetLocation(), 600)
		local nearbyEnemies = Fu.GetEnemiesNearLoc(bot:GetLocation(), 1200)
		local nearbyEnemyTowers = bot:GetNearbyTowers(700, true)
		local nearbyLaneCreeps = bot:GetNearbyLaneCreeps(1200, true)
		if
			nearbyLaneCreeps ~= nil
			and #nearbyLaneCreeps >= 3
			and nearbyEnemies ~= nil
			and #nearbyEnemies == 0
			and nearbyAllies ~= nil
			and #nearbyAllies <= 1
			and GetUnitToLocationDistance(bot, Fu.GetCenterOfUnits(nearbyLaneCreeps)) > bot:GetAttackRange()
			and Fu.CanBeAttacked(nearbyLaneCreeps[1])
		then
			local creepTowers = nearbyLaneCreeps[#nearbyLaneCreeps]:GetNearbyTowers(700, false)
			if creepTowers ~= nil and #creepTowers == 0 then
				return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(nearbyLaneCreeps)
			end
		end
	end
	if Fu.IsDoingRoshan(bot) then
		local roshanLocation = Fu.GetCurrentRoshanLocation()
		if GetUnitToLocationDistance(bot, roshanLocation) > castRange then
			local blinkLocation = Fu.Site.GetXUnitsTowardsLocation(bot, roshanLocation, castRange)
			local nearbyEnemies = Fu.GetEnemiesNearLoc(roshanLocation, 1600)
			if nearbyEnemies ~= nil and #nearbyEnemies == 0 and IsLocationPassable(blinkLocation) then
				return BOT_ACTION_DESIRE_HIGH, blinkLocation
			end
		end
	end
	if Fu.IsDoingTormentor(bot) then
		local tormentorLocation = Fu.GetTormentorLocation(GetTeam())
		if GetUnitToLocationDistance(bot, tormentorLocation) > castRange then
			local blinkLocation = Fu.Site.GetXUnitsTowardsLocation(bot, tormentorLocation, castRange)
			local nearbyEnemies = Fu.GetEnemiesNearLoc(blinkLocation, 1600)
			if nearbyEnemies ~= nil and #nearbyEnemies == 0 and IsLocationPassable(blinkLocation) then
				return BOT_ACTION_DESIRE_HIGH, blinkLocation
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderCounterSpell()
	if not counterspellAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
	end
	if Fu.IsUnitTargetProjectileIncoming(bot, 400) then
		return BOT_ACTION_DESIRE_HIGH
	end
	if not bot:HasModifier("modifier_sniper_assassinate") and not bot:IsMagicImmune() then
		if Fu.IsWillBeCastUnitTargetSpell(bot, 1400) then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderManaVoid()
	if not manaVoidAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
	end
	local castRange = Fu.GetProperCastRange(false, bot, manaVoidAbility:GetCastRange())
	local radius = manaVoidAbility:GetSpecialValueInt("mana_void_aoe_radius")
	local damagePerMana = manaVoidAbility:GetSpecialValueFloat("mana_void_damage_per_mana")
	if Fu.IsInTeamFight(bot, 1200) then
		local killTarget = nil
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, castRange + 200, true, BOT_MODE_NONE)
		for _, enemyHero in pairs(nearbyEnemies) do
			local damage = damagePerMana * (enemyHero:GetMaxMana() - enemyHero:GetMana())
			if
				Fu.IsValidHero(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.CanKillTarget(enemyHero, damage, DAMAGE_TYPE_MAGICAL)
				and not Fu.IsHaveAegis(enemyHero)
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and not enemyHero:HasModifier("modifier_arc_warden_tempest_double")
				and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
				and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
				and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
			then
				killTarget = enemyHero
				break
			end
		end
		if killTarget ~= nil then
			bot:SetTarget(killTarget)
			return BOT_ACTION_DESIRE_HIGH, killTarget
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidHero(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.CanCastOnTargetAdvanced(botTarget)
			and not Fu.IsHaveAegis(botTarget)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not botTarget:HasModifier("modifier_arc_warden_tempest_double")
			and not botTarget:HasModifier("modifier_dazzle_shallow_grave")
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
			and not botTarget:HasModifier("modifier_oracle_false_promise_timer")
		then
			local targetNearbyEnemies = Fu.GetNearbyHeroes(botTarget, 1200, true, BOT_MODE_NONE)
			local targetNearbyAllies = Fu.GetNearbyHeroes(botTarget, 1200, false, BOT_MODE_NONE)
			local damage = damagePerMana * (botTarget:GetMaxMana() - botTarget:GetMana())
			if
				targetNearbyEnemies ~= nil
				and targetNearbyAllies ~= nil
				and #targetNearbyEnemies >= #targetNearbyAllies
			then
				if Fu.CanKillTarget(botTarget, damage, DAMAGE_TYPE_MAGICAL) then
					return BOT_ACTION_DESIRE_HIGH, botTarget
				end
			end
		end
	end
	return 0
end
function X.ConsiderCounterSpellAlly()
	if not counterspellAllyAbility:IsTrained() or not counterspellAllyAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castRange = Fu.GetProperCastRange(false, bot, counterspellAllyAbility:GetCastRange())
	local nearbyAllies = Fu.GetNearbyHeroes(bot, castRange, false, BOT_MODE_NONE)
	for _, allyHero in pairs(nearbyAllies) do
		if
			Fu.IsValidHero(allyHero)
			and not Fu.IsSuspiciousIllusion(allyHero)
			and not allyHero:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			if Fu.IsUnitTargetProjectileIncoming(allyHero, 400) and not allyHero:IsMagicImmune() then
				return BOT_ACTION_DESIRE_HIGH, allyHero
			end
			if not allyHero:HasModifier("modifier_sniper_assassinate") and not allyHero:IsMagicImmune() then
				if Fu.IsWillBeCastUnitTargetSpell(allyHero, castRange) then
					return BOT_ACTION_DESIRE_HIGH, allyHero
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function X.ConsiderBlinkFragment()
	if not bot:HasScepter() or not manaOverloadAbility:IsTrained() or not manaOverloadAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local castRange = Fu.GetProperCastRange(false, bot, manaOverloadAbility:GetCastRange())
	if Fu.IsGoingOnSomeone(bot) then
		local blinkTarget = nil
		local targetHealth = 99999
		local nearbyEnemies = Fu.GetEnemiesNearLoc(bot:GetLocation(), castRange)
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValidTarget(enemyHero)
				and Fu.CanCastOnMagicImmune(enemyHero)
				and not Fu.IsInRange(bot, enemyHero, castRange / 2)
				and not enemyHero:IsAttackImmune()
				and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
				and not enemyHero:HasModifier("modifier_faceless_void_chronosphere_freeze")
				and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
			then
				local enemyNearbyEnemies = Fu.GetNearbyHeroes(enemyHero, 1200, true, BOT_MODE_NONE)
				local enemyNearbyAllies = Fu.GetNearbyHeroes(enemyHero, 1200, false, BOT_MODE_NONE)
				if
					enemyNearbyEnemies ~= nil
					and enemyNearbyAllies ~= nil
					and #enemyNearbyEnemies >= #enemyNearbyAllies
					-- fix: was "targetHealth < GetHealth()" with targetHealth starting at 99999, so no target was
					-- ever picked; now the lowest-health enemy, as the 99999 start means.
					and enemyHero:GetHealth() < targetHealth
				then
					targetHealth = enemyHero:GetHealth()
					blinkTarget = enemyHero
				end
			end
		end
		if blinkTarget ~= nil then
			if DotaTime() >= lastBlinkFragmentLogTime + 5 then
				lastBlinkFragmentLogTime = DotaTime()
				pcall(
					print,
					string.format(
						"[OHA-RUBICK] t=%.0f stolen blink fragment engage target=%s hp=%d",
						DotaTime(),
						blinkTarget:GetUnitName(),
						targetHealth
					)
				)
			end
			return BOT_ACTION_DESIRE_HIGH, blinkTarget:GetLocation()
		end
	end
	if Fu.IsRetreating(bot) then
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE)
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.IsChasingTarget(enemyHero, bot)
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and not Fu.IsDisabled(enemyHero)
				and not Fu.IsRealInvisible(bot)
			then
				local enemyNearbyEnemies = Fu.GetNearbyHeroes(enemyHero, 1200, true, BOT_MODE_NONE)
				local enemyNearbyAllies = Fu.GetNearbyHeroes(enemyHero, 1200, false, BOT_MODE_NONE)
				if
					enemyNearbyEnemies ~= nil
					and enemyNearbyAllies ~= nil
					and (#enemyNearbyAllies > #enemyNearbyEnemies or bot:WasRecentlyDamagedByAnyHero(1.2))
				then
					return BOT_ACTION_DESIRE_HIGH, enemyHero:GetLocation()
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
return X
