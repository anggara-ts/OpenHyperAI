-- How Rubick plays after stealing a spell from Rattletrap.
-- Accidental globals made file-local (#13): every bot shares one Lua state, so these were shared.
local OverclockingDesire, HookshotDesire, HookshotTarget, PowerCogsDesire, BatteryAssaultDesire, RocketFlareDesire, RocketFlareLocation, JetpackDesire
local bot
local X = {}
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local batteryAssaultAbility
local powerCogsAbility
local rocketFlareAbility
local jetpackAbility
local overclockingAbility
local hookshotAbility
local lastPowerCogsTime = -1
local lastRoshanFlareTime = -1
local botTarget
local lastAllyHookLogTime = -999
-- Handles of the other Clockwerk spells are nil unless Rubick stole that spell too.
local function IsStolenSpellReady(spell)
	return spell ~= nil and not spell:IsNull() and spell:IsFullyCastable()
end
function X.ConsiderStolenSpell(ability)
	bot = GetBot()
	if Fu.CanNotUseAbility(bot) then
		return
	end
	botTarget = Fu.GetProperTarget(bot)
	local abilityName = ability:GetName()
	if abilityName == "rattletrap_overclocking" then
		overclockingAbility = ability
		OverclockingDesire = X.ConsiderOverclocking()
		if OverclockingDesire > 0 then
			bot:Action_UseAbility(overclockingAbility)
			return
		end
	end
	if abilityName == "rattletrap_hookshot" then
		hookshotAbility = ability
		HookshotDesire, HookshotTarget = X.ConsiderHookshot()
		if HookshotDesire > 0 then
			bot:Action_UseAbilityOnLocation(hookshotAbility, HookshotTarget)
			return
		end
	end
	if abilityName == "rattletrap_power_cogs" then
		powerCogsAbility = ability
		PowerCogsDesire = X.ConsiderPowerCogs()
		if PowerCogsDesire > 0 then
			bot:Action_UseAbility(powerCogsAbility)
			lastPowerCogsTime = DotaTime()
			return
		end
	end
	if abilityName == "rattletrap_battery_assault" then
		batteryAssaultAbility = ability
		BatteryAssaultDesire = X.ConsiderBatteryAssault()
		if BatteryAssaultDesire > 0 then
			bot:Action_UseAbility(batteryAssaultAbility)
			return
		end
	end
	if abilityName == "rattletrap_rocket_flare" then
		rocketFlareAbility = ability
		RocketFlareDesire, RocketFlareLocation = X.ConsiderRocketFlare()
		if RocketFlareDesire > 0 then
			bot:Action_UseAbilityOnLocation(rocketFlareAbility, RocketFlareLocation)
			return
		end
	end
	if abilityName == "rattletrap_jetpack" then
		jetpackAbility = ability
		JetpackDesire = X.ConsiderJetpack()
		if JetpackDesire > 0 then
			bot:Action_UseAbility(jetpackAbility)
			return
		end
	end
end
function X.ConsiderBatteryAssault()
	if not batteryAssaultAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
	end
	local radius = batteryAssaultAbility:GetSpecialValueInt("radius")
	local nearbyAllies = Fu.GetNearbyHeroes(bot, radius, false, BOT_MODE_NONE)
	for _, allyHero in pairs(nearbyAllies) do
		local allyNearbyEnemies = Fu.GetNearbyHeroes(allyHero, 1200, true, BOT_MODE_NONE)
		if
			Fu.IsValidHero(allyHero)
			and Fu.IsRetreating(allyHero)
			and Fu.IsCore(allyHero)
			and allyHero:WasRecentlyDamagedByAnyHero(1.5)
			and not allyHero:IsIllusion()
		then
			if
				allyNearbyEnemies ~= nil
				and #allyNearbyEnemies >= 1
				and Fu.IsValidHero(allyNearbyEnemies[1])
				and Fu.CanCastOnNonMagicImmune(allyNearbyEnemies[1])
				and Fu.IsInRange(bot, allyNearbyEnemies[1], radius)
				and Fu.IsChasingTarget(allyNearbyEnemies[1], allyHero)
				and not Fu.IsDisabled(allyNearbyEnemies[1])
				and not Fu.IsTaunted(allyNearbyEnemies[1])
				and not allyNearbyEnemies[1]:HasModifier("modifier_necrolyte_reapers_scythe")
			then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, radius)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			local targetNearbyEnemies = Fu.GetNearbyHeroes(botTarget, 1200, true, BOT_MODE_NONE)
			local targetNearbyAllies = Fu.GetNearbyHeroes(botTarget, 1200, false, BOT_MODE_NONE)
			if
				targetNearbyEnemies ~= nil
				and targetNearbyAllies ~= nil
				and #targetNearbyEnemies >= #targetNearbyAllies
			then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	if Fu.IsRetreating(bot) and bot:GetActiveModeDesire() > 0.5 then
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE)
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.IsInRange(bot, enemyHero, radius)
				and Fu.IsChasingTarget(enemyHero, bot)
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and not Fu.IsDisabled(enemyHero)
			then
				local enemyNearbyEnemies = Fu.GetNearbyHeroes(enemyHero, 1200, true, BOT_MODE_NONE)
				local enemyNearbyAllies = Fu.GetNearbyHeroes(enemyHero, 1200, false, BOT_MODE_NONE)
				if
					enemyNearbyEnemies ~= nil
					and enemyNearbyAllies ~= nil
					and (#enemyNearbyAllies > #enemyNearbyEnemies or bot:WasRecentlyDamagedByAnyHero(1.5))
				then
					return BOT_ACTION_DESIRE_HIGH
				end
			end
		end
	end
	if Fu.IsPushing(bot) or Fu.IsDefending(bot) then
		local nearbyLaneCreeps = bot:GetNearbyLaneCreeps(radius, true)
		if nearbyLaneCreeps ~= nil and #nearbyLaneCreeps >= 3 then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if
			Fu.IsRoshan(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, radius)
			and Fu.IsAttacking(bot)
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, radius) and Fu.IsAttacking(bot) then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderPowerCogs()
	if not powerCogsAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
	end
	local radius = powerCogsAbility:GetSpecialValueInt("cogs_radius")
	local duration = powerCogsAbility:GetSpecialValueFloat("duration")
	if DotaTime() < lastPowerCogsTime + duration then
		return BOT_ACTION_DESIRE_NONE
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidTarget(botTarget)
			and Fu.IsInRange(bot, botTarget, radius - 25)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			local targetNearbyEnemies = Fu.GetNearbyHeroes(botTarget, 1200, true, BOT_MODE_NONE)
			local targetNearbyAllies = Fu.GetNearbyHeroes(botTarget, 1200, false, BOT_MODE_NONE)
			if
				targetNearbyEnemies ~= nil
				and targetNearbyAllies ~= nil
				and #targetNearbyEnemies >= #targetNearbyAllies
			then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	if Fu.IsRetreating(bot) and bot:GetActiveModeDesire() > 0.5 then
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE)
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.IsChasingTarget(enemyHero, bot)
				and Fu.IsInRange(bot, enemyHero, radius + 200)
				and not Fu.IsInRange(bot, enemyHero, radius)
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and not Fu.IsDisabled(enemyHero)
			then
				local enemyNearbyEnemies = Fu.GetNearbyHeroes(enemyHero, 1200, true, BOT_MODE_NONE)
				local enemyNearbyAllies = Fu.GetNearbyHeroes(enemyHero, 1200, false, BOT_MODE_NONE)
				if
					enemyNearbyEnemies ~= nil
					and enemyNearbyAllies ~= nil
					and (#enemyNearbyAllies > #enemyNearbyEnemies or bot:WasRecentlyDamagedByAnyHero(2))
				then
					return BOT_ACTION_DESIRE_HIGH
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderRocketFlare()
	if not rocketFlareAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local castPoint = rocketFlareAbility:GetCastPoint()
	local radius = rocketFlareAbility:GetSpecialValueInt("radius")
	local damage = rocketFlareAbility:GetSpecialValueInt("damage")
	local castRange = 1600
	local roshanLocation = Fu.GetCurrentRoshanLocation()
	local teamFightLocation = Fu.GetTeamFightLocation(bot)
	local nearbyEnemies = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidTarget(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and Fu.CanKillTarget(enemyHero, damage, DAMAGE_TYPE_MAGICAL)
			and not Fu.IsSuspiciousIllusion(enemyHero)
			and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
			and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
			and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
			and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
			and not enemyHero:HasModifier("modifier_templar_assassin_refraction_absorb")
		then
			return BOT_ACTION_DESIRE_HIGH, enemyHero:GetExtrapolatedLocation(castPoint)
		end
	end
	if teamFightLocation ~= nil then
		if GetUnitToLocationDistance(bot, teamFightLocation) > bot:GetCurrentVisionRange() then
			return BOT_ACTION_DESIRE_HIGH, teamFightLocation
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, bot:GetCurrentVisionRange())
			and Fu.IsChasingTarget(bot, botTarget)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not Fu.IsDisabled(botTarget)
			and not botTarget:HasModifier("modifier_dazzle_shallow_grave")
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
			and not botTarget:HasModifier("modifier_oracle_false_promise_timer")
		then
			local targetNearbyEnemies = Fu.GetNearbyHeroes(botTarget, 1200, true, BOT_MODE_NONE)
			local targetNearbyAllies = Fu.GetNearbyHeroes(botTarget, 1200, false, BOT_MODE_NONE)
			if
				targetNearbyEnemies ~= nil
				and targetNearbyAllies ~= nil
				and #targetNearbyEnemies >= #targetNearbyAllies
			then
				targetNearbyAllies = Fu.GetEnemiesNearLoc(botTarget:GetLocation(), radius)
				if targetNearbyAllies ~= nil and #targetNearbyAllies >= 1 then
					return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(targetNearbyAllies)
				else
					return BOT_ACTION_DESIRE_HIGH, botTarget:GetExtrapolatedLocation(castPoint)
				end
			end
		end
	end
	if Fu.IsRetreating(bot) then
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE)
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.IsInRange(bot, enemyHero, radius)
				and Fu.IsChasingTarget(enemyHero, bot)
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and not Fu.IsDisabled(enemyHero)
			then
				local enemyNearbyEnemies = Fu.GetNearbyHeroes(enemyHero, 1200, true, BOT_MODE_NONE)
				local enemyNearbyAllies = Fu.GetNearbyHeroes(enemyHero, 1200, false, BOT_MODE_NONE)
				if
					enemyNearbyEnemies ~= nil
					and enemyNearbyAllies ~= nil
					and (#enemyNearbyAllies > #enemyNearbyEnemies or bot:WasRecentlyDamagedByAnyHero(2))
				then
					return BOT_ACTION_DESIRE_HIGH, enemyHero:GetLocation()
				end
			end
		end
	end
	if Fu.IsPushing(bot) or Fu.IsDefending(bot) then
		local aoeLocation = bot:FindAoELocation(true, true, bot:GetLocation(), castRange, radius, 0, 0)
		local nearbyLaneCreeps = bot:GetNearbyLaneCreeps(castRange, true)
		if aoeLocation.count >= 1 then
			return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
		end
		aoeLocation = bot:FindAoELocation(true, false, bot:GetLocation(), castRange, radius, 0, 0)
		if aoeLocation.count >= 4 and #nearbyLaneCreeps >= 4 then
			return BOT_ACTION_DESIRE_MODERATE, Fu.GetCenterOfUnits(nearbyLaneCreeps)
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if
			Fu.IsRoshan(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, radius)
			and Fu.IsAttacking(bot)
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
		-- Keep mana for Hookshot only when it was also stolen (the handle is nil otherwise).
		local hookshotMana = 0
		if hookshotAbility ~= nil and not hookshotAbility:IsNull() then
			hookshotMana = hookshotAbility:GetManaCost()
		end
		if
			GetUnitToLocationDistance(bot, roshanLocation) > 1600
			and DotaTime() > lastRoshanFlareTime + 15
			and Fu.GetManaAfter(rocketFlareAbility:GetManaCost()) * bot:GetMana() > hookshotMana
		then
			lastRoshanFlareTime = DotaTime()
			return BOT_ACTION_DESIRE_HIGH, roshanLocation
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, radius) and Fu.IsAttacking(bot) then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.ConsiderHookshot()
	if not hookshotAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local castPoint = hookshotAbility:GetCastPoint()
	local castRange = Fu.GetProperCastRange(false, bot, hookshotAbility:GetCastRange())
	local radius = hookshotAbility:GetSpecialValueInt("stun_radius")
	local speed = hookshotAbility:GetSpecialValueInt("speed")
	if Fu.IsGoingOnSomeone(bot) then
		local nearbyEnemies = Fu.GetEnemiesNearLoc(bot:GetLocation(), castRange)
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValidTarget(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.IsInRange(bot, enemyHero, castRange)
				and GetUnitToLocationDistance(enemyHero, Fu.GetEnemyFountain()) > 1000
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and not enemyHero:HasModifier("modifier_faceless_void_chronosphere_freeze")
				and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
			then
				local enemyNearbyEnemies = Fu.GetNearbyHeroes(enemyHero, 1200, true, BOT_MODE_NONE)
				local enemyNearbyAllies = Fu.GetNearbyHeroes(enemyHero, 1200, false, BOT_MODE_NONE)
				local delay = GetUnitToUnitDistance(bot, enemyHero) / speed + castPoint
				local hookLocation = enemyHero:GetExtrapolatedLocation(delay)
				if
					enemyNearbyEnemies ~= nil
					and enemyNearbyAllies ~= nil
					and #enemyNearbyEnemies >= #enemyNearbyAllies
					and not Fu.IsAllyHeroBetweenMeAndTarget(bot, enemyHero, hookLocation, radius)
					and not Fu.IsCreepBetweenMeAndTarget(bot, enemyHero, hookLocation, radius)
					and not Fu.IsLocationInChrono(hookLocation)
					and not Fu.IsLocationInArena(hookLocation, 800)
				then
					if #enemyNearbyEnemies == 0 and #enemyNearbyAllies == 0 then
						if
							bot:GetEstimatedDamageToTarget(true, enemyHero, 5, DAMAGE_TYPE_ALL)
								> enemyHero:GetHealth()
							and IsStolenSpellReady(powerCogsAbility)
							and IsStolenSpellReady(batteryAssaultAbility)
						then
							bot:SetTarget(enemyHero)
							return BOT_ACTION_DESIRE_HIGH, hookLocation
						end
					else
						if #enemyNearbyEnemies >= 1 then
							bot:SetTarget(enemyHero)
							return BOT_ACTION_DESIRE_HIGH, hookLocation
						end
					end
				end
			end
		end
	end
	if Fu.IsRetreating(bot) and bot:GetActiveModeDesire() > 0.75 then
		local nearbyAllies = Fu.GetAlliesNearLoc(bot:GetLocation(), castRange)
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE)
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.IsChasingTarget(enemyHero, bot)
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and not Fu.IsDisabled(enemyHero)
			then
				local enemyNearbyEnemies = Fu.GetNearbyHeroes(enemyHero, 1200, true, BOT_MODE_NONE)
				local enemyNearbyAllies = Fu.GetNearbyHeroes(enemyHero, 1200, false, BOT_MODE_NONE)
				if
					enemyNearbyEnemies ~= nil
					and enemyNearbyAllies ~= nil
					and (#enemyNearbyAllies > #enemyNearbyEnemies or bot:WasRecentlyDamagedByAnyHero(2))
				then
					for _, allyHero in pairs(nearbyAllies) do
						if
							Fu.IsValidHero(allyHero)
							and bot:DistanceFromFountain() > 1600
							and allyHero:DistanceFromFountain() > 1600
							and bot:DistanceFromFountain() > allyHero:DistanceFromFountain()
							and GetUnitToUnitDistance(bot, allyHero) > 1200
							-- fix: was "not Fu.IsNotSelf" (= allyHero is Rubick himself), so the hook-to-ally escape never fired
							and Fu.IsNotSelf(bot, allyHero)
						then
							local delay = GetUnitToUnitDistance(bot, allyHero) / speed + castPoint
							local hookLocation = allyHero:GetExtrapolatedLocation(delay)
							if
								not Fu.IsHeroBetweenMeAndTarget(bot, allyHero, hookLocation, radius)
								and not Fu.IsCreepBetweenMeAndTarget(bot, allyHero, hookLocation, radius)
								and not Fu.IsLocationInChrono(hookLocation)
								and not Fu.IsLocationInArena(hookLocation, 800)
							then
								if DotaTime() >= lastAllyHookLogTime + 5 then
									lastAllyHookLogTime = DotaTime()
									pcall(
										print,
										string.format(
											"[OHA-RUBICK] t=%.0f stolen hookshot escape to ally=%s dist=%.0f",
											DotaTime(),
											allyHero:GetUnitName(),
											GetUnitToUnitDistance(bot, allyHero)
										)
									)
								end
								return BOT_ACTION_DESIRE_HIGH, hookLocation
							end
						end
					end
				end
			end
		end
		local neutralSpawners = GetNeutralSpawners()
		local escapeLocation = Fu.GetEscapeLoc()
		local escapeDistance = GetUnitToLocationDistance(bot, escapeLocation)
		for _, spawner in pairs(neutralSpawners) do
			local spawnerEscapeDistance = Fu.GetDistance(spawner.location, escapeLocation)
			if spawnerEscapeDistance < escapeDistance and GetUnitToLocationDistance(bot, spawner.location) > 700 then
				if
					not Fu.IsHeroBetweenMeAndLocation(bot, spawner.location, radius)
					and not Fu.IsCreepBetweenMeAndLocation(bot, spawner.location, radius)
					and not Fu.IsLocationInChrono(spawner.location)
					and not Fu.IsLocationInArena(spawner.location, 800)
				then
					return BOT_ACTION_DESIRE_HIGH, spawner.location
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.ConsiderJetpack()
	if not jetpackAbility:IsTrained() or not jetpackAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
	end
	if Fu.IsRetreating(bot) and bot:GetActiveModeDesire() > 0.5 then
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE)
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.IsInRange(bot, enemyHero, 800)
				and Fu.IsChasingTarget(enemyHero, bot)
				and not Fu.IsSuspiciousIllusion(enemyHero)
			then
				local enemyNearbyEnemies = Fu.GetNearbyHeroes(enemyHero, 1200, true, BOT_MODE_NONE)
				local enemyNearbyAllies = Fu.GetNearbyHeroes(enemyHero, 1200, false, BOT_MODE_NONE)
				if
					enemyNearbyEnemies ~= nil
					and enemyNearbyAllies ~= nil
					and (#enemyNearbyAllies > #enemyNearbyEnemies or bot:WasRecentlyDamagedByAnyHero(2.5))
				then
					return BOT_ACTION_DESIRE_HIGH
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderOverclocking()
	if not overclockingAbility:IsTrained() or not overclockingAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
	end
	if Fu.IsInTeamFight(bot, 1200) then
		local nearbyEnemies = Fu.GetEnemiesNearLoc(bot:GetLocation(), 1200)
		if nearbyEnemies ~= nil and #nearbyEnemies >= 2 and Fu.IsAttacking(bot) then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
return X
