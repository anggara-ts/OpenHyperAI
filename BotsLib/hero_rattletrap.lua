-- Rattletrap: skill build, item build, and ability use for this hero.
local X = {}
local bot = GetBot()
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local AbilityContext = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local Minion = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local sTalentList = Fu.Skill.GetTalentList(bot)
local sAbilityList = Fu.Skill.GetAbilityList(bot)
local sRole = Fu.Item.GetRoleItemsBuyList(bot)
local tTalentTreeList = {
	{ ["t25"] = { 10, 0 }, ["t20"] = { 10, 0 }, ["t15"] = { 0, 10 }, ["t10"] = { 10, 0 } },
	{ ["t25"] = { 10, 0 }, ["t20"] = { 0, 10 }, ["t15"] = { 10, 0 }, ["t10"] = { 0, 10 } },
}
local tAllAbilityBuildList = { { 2, 1, 2, 3, 2, 6, 2, 3, 3, 3, 6, 1, 1, 1, 6 }, { 2, 1, 2, 3, 2, 6, 2, 3, 3, 3, 6, 1, 1, 1, 6 } }
local nAbilityBuildList
local nTalentBuildList
if sRole == "pos_4" then
	nAbilityBuildList = tAllAbilityBuildList[1]
	nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList[1])
else
	nAbilityBuildList = tAllAbilityBuildList[2]
	nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList[2])
end
local sRoleItemsBuyList = {}
sRoleItemsBuyList["pos_4"] = {
	"item_double_tango",
	"item_double_branches",
	"item_blood_grenade",
	"item_wind_lace",
	"item_boots",
	"item_magic_wand",
	"item_tranquil_boots",
	"item_force_staff",
	"item_blade_mail",
	"item_ancient_janggo",
	"item_spirit_vessel",
	"item_boots_of_bearing",
	"item_aghanims_shard",
	"item_shivas_guard",
	"item_heavens_halberd",
	"item_ultimate_scepter_2",
	"item_moon_shard",
}
sRoleItemsBuyList["pos_5"] = {
	"item_double_tango",
	"item_double_branches",
	"item_blood_grenade",
	"item_wind_lace",
	"item_boots",
	"item_magic_wand",
	"item_tranquil_boots",
	"item_force_staff",
	"item_blade_mail",
	"item_spirit_vessel",
	"item_solar_crest",
	"item_lotus_orb",
	"item_aghanims_shard",
	"item_shivas_guard",
	"item_heavens_halberd",
	"item_ultimate_scepter_2",
	"item_moon_shard",
}
sRoleItemsBuyList["pos_1"] = sRoleItemsBuyList["pos_4"]
sRoleItemsBuyList["pos_2"] = sRoleItemsBuyList["pos_4"]
sRoleItemsBuyList["pos_3"] = sRoleItemsBuyList["pos_4"]
X["sBuyList"] = sRoleItemsBuyList[sRole]
X["sSellList"] = { "item_heavens_halberd", "item_magic_wand" }
if Fu.Role.IsPvNMode() or Fu.Role.IsAllShadow() then
	X["sBuyList"], X["sSellList"] = { "PvN_antimage" }, {}
end
nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"] = Fu.SetUserHeroInit(nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"])
X["sSkillList"] = Fu.Skill.GetSkillList(sAbilityList, nAbilityBuildList, sTalentList, nTalentBuildList)
X["bDeafaultAbility"] = false
X["bDeafaultItem"] = false
function X.MinionThink(minionUnit)
	Minion.MinionThink(minionUnit)
end
local batteryAssaultAbility = SafeAbility(bot:GetAbilityByName("rattletrap_battery_assault"), "rattletrap_battery_assault", "rattletrap")
local powerCogsAbility = SafeAbility(bot:GetAbilityByName("rattletrap_power_cogs"), "rattletrap_power_cogs", "rattletrap")
local rocketFlareAbility = SafeAbility(bot:GetAbilityByName("rattletrap_rocket_flare"), "rattletrap_rocket_flare", "rattletrap")
local jetpackAbility = SafeAbility(bot:GetAbilityByName("rattletrap_jetpack"), "rattletrap_jetpack", "rattletrap")
local overclockingAbility = SafeAbility(bot:GetAbilityByName("rattletrap_overclocking"), "rattletrap_overclocking", "rattletrap")
local hookshotAbility = SafeAbility(bot:GetAbilityByName("rattletrap_hookshot"), "rattletrap_hookshot", "rattletrap")
local batteryAssaultDesire
local powerCogsDesire
local rocketFlareDesire, rocketFlareLocation
local jetpackDesire
local overclockingDesire
local hookshotDesire, hookshotLocation
local powerCogsCastTime = -1
local roshanFlareTime = -1
local botTarget
local isGoingOnSomeone
local isRetreating
local isAttacking
function X.SkillsComplement()
	if Fu.CanNotUseAbility(bot) then
		return
	end
	local context = AbilityContext.Build(bot)
	isGoingOnSomeone = context.isEngaging
	isRetreating = context.isRetreating
	isAttacking = Fu.IsAttacking(bot)
	botTarget = context.target
	overclockingDesire = X.ConsiderOverclocking()
	if overclockingDesire > 0 then
		bot:Action_UseAbility(overclockingAbility)
		return
	end
	hookshotDesire, hookshotLocation = X.ConsiderHookshot()
	if hookshotDesire > 0 then
		bot:Action_UseAbilityOnLocation(hookshotAbility, hookshotLocation)
		return
	end
	powerCogsDesire = X.ConsiderPowerCogs()
	if powerCogsDesire > 0 then
		bot:Action_UseAbility(powerCogsAbility)
		powerCogsCastTime = DotaTime()
		return
	end
	batteryAssaultDesire = X.ConsiderBatteryAssault()
	if batteryAssaultDesire > 0 then
		bot:Action_UseAbility(batteryAssaultAbility)
		return
	end
	rocketFlareDesire, rocketFlareLocation = X.ConsiderRocketFlare()
	if rocketFlareDesire > 0 then
		bot:Action_UseAbilityOnLocation(rocketFlareAbility, rocketFlareLocation)
		return
	end
	jetpackDesire = X.ConsiderJetpack()
	if jetpackDesire > 0 then
		bot:Action_UseAbility(jetpackAbility)
		return
	end
end
function X.ConsiderBatteryAssault()
	if not Fu.CanCastAbility(batteryAssaultAbility) then
		return BOT_ACTION_DESIRE_NONE
	end
	local radius = batteryAssaultAbility:GetSpecialValueInt("radius")
	local nearbyAllies = Fu.GetNearbyHeroes(bot, radius, false, BOT_MODE_NONE)
	for _, allyHero in pairs(nearbyAllies) do
		local allyNearbyEnemies = allyHero:GetNearbyHeroes(1200, true, BOT_MODE_NONE)
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
	if isGoingOnSomeone then
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, radius)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			local ourHeroesNearby = botTarget:GetNearbyHeroes(1200, true, BOT_MODE_NONE)
			local theirHeroesNearby = botTarget:GetNearbyHeroes(1200, false, BOT_MODE_NONE)
			if ourHeroesNearby ~= nil and theirHeroesNearby ~= nil and #ourHeroesNearby >= #theirHeroesNearby then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	if isRetreating and bot:GetActiveModeDesire() > 0.5 then
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE)
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.IsInRange(bot, enemyHero, radius)
				and Fu.IsChasingTarget(enemyHero, bot)
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and not Fu.IsDisabled(enemyHero)
			then
				local ourHeroesNearby = enemyHero:GetNearbyHeroes(1200, true, BOT_MODE_NONE)
				local theirHeroesNearby = enemyHero:GetNearbyHeroes(1200, false, BOT_MODE_NONE)
				if ourHeroesNearby ~= nil and theirHeroesNearby ~= nil and (#theirHeroesNearby > #ourHeroesNearby or bot:WasRecentlyDamagedByAnyHero(1.5)) then
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
		if Fu.IsRoshan(botTarget) and Fu.CanCastOnNonMagicImmune(botTarget) and Fu.IsInRange(bot, botTarget, radius) and isAttacking then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsDoingTormentor(bot) then
		-- was Fu.IsRoshan(botTarget), which is never true at the Tormentor
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, radius) and isAttacking then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderPowerCogs()
	if not Fu.CanCastAbility(powerCogsAbility) then
		return BOT_ACTION_DESIRE_NONE
	end
	local radius = powerCogsAbility:GetSpecialValueInt("cogs_radius")
	local duration = powerCogsAbility:GetSpecialValueFloat("duration")
	if DotaTime() < powerCogsCastTime + duration then
		return BOT_ACTION_DESIRE_NONE
	end
	if isGoingOnSomeone then
		if
			Fu.IsValidTarget(botTarget)
			and Fu.IsInRange(bot, botTarget, radius - 25)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			local ourHeroesNearby = botTarget:GetNearbyHeroes(1200, true, BOT_MODE_NONE)
			local theirHeroesNearby = botTarget:GetNearbyHeroes(1200, false, BOT_MODE_NONE)
			if ourHeroesNearby ~= nil and theirHeroesNearby ~= nil and #ourHeroesNearby >= #theirHeroesNearby then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	if isRetreating and bot:GetActiveModeDesire() > 0.5 then
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
				local ourHeroesNearby = enemyHero:GetNearbyHeroes(1200, true, BOT_MODE_NONE)
				local theirHeroesNearby = enemyHero:GetNearbyHeroes(1200, false, BOT_MODE_NONE)
				if ourHeroesNearby ~= nil and theirHeroesNearby ~= nil and (#theirHeroesNearby > #ourHeroesNearby or bot:WasRecentlyDamagedByAnyHero(2)) then
					return BOT_ACTION_DESIRE_HIGH
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderRocketFlare()
	if not Fu.CanCastAbility(rocketFlareAbility) then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local castPoint = rocketFlareAbility:GetCastPoint()
	local radius = rocketFlareAbility:GetSpecialValueInt("radius")
	local damage = rocketFlareAbility:GetSpecialValueInt("damage")
	local castRange = 1600
	local roshanLocation = Fu.GetCurrentRoshanLocation()
	local teamFightLocation = Fu.GetTeamFightLocation(bot)
	local enemiesInRange = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(enemiesInRange) do
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
	if isGoingOnSomeone then
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, bot:GetCurrentVisionRange())
			and Fu.IsChasingTarget(bot, botTarget)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not Fu.IsDisabled(botTarget)
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			local ourHeroesNearby = botTarget:GetNearbyHeroes(1200, true, BOT_MODE_NONE)
			local theirHeroesNearby = botTarget:GetNearbyHeroes(1200, false, BOT_MODE_NONE)
			if ourHeroesNearby ~= nil and theirHeroesNearby ~= nil and #ourHeroesNearby >= #theirHeroesNearby then
				theirHeroesNearby = Fu.GetEnemiesNearLoc(botTarget:GetLocation(), radius)
				if theirHeroesNearby ~= nil and #theirHeroesNearby >= 1 then
					return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(theirHeroesNearby)
				else
					return BOT_ACTION_DESIRE_HIGH, botTarget:GetExtrapolatedLocation(castPoint)
				end
			end
		end
	end
	if isRetreating then
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
				local ourHeroesNearby = enemyHero:GetNearbyHeroes(1200, true, BOT_MODE_NONE)
				local theirHeroesNearby = enemyHero:GetNearbyHeroes(1200, false, BOT_MODE_NONE)
				if ourHeroesNearby ~= nil and theirHeroesNearby ~= nil and (#theirHeroesNearby > #ourHeroesNearby or bot:WasRecentlyDamagedByAnyHero(2)) then
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
		if Fu.IsRoshan(botTarget) and Fu.CanCastOnNonMagicImmune(botTarget) and Fu.IsInRange(bot, botTarget, radius) and isAttacking then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
		if
			GetUnitToLocationDistance(bot, roshanLocation) > 1600
			and DotaTime() > roshanFlareTime + 15
			and Fu.GetManaAfter(rocketFlareAbility:GetManaCost()) * bot:GetMana() > hookshotAbility:GetManaCost()
		then
			roshanFlareTime = DotaTime()
			return BOT_ACTION_DESIRE_HIGH, roshanLocation
		end
	end
	if Fu.IsDoingTormentor(bot) then
		-- was Fu.IsRoshan(botTarget), which is never true at the Tormentor
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, radius) and isAttacking then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.ConsiderHookshot()
	if not Fu.CanCastAbility(hookshotAbility) then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local castPoint = hookshotAbility:GetCastPoint()
	local castRange = Fu.GetProperCastRange(false, bot, hookshotAbility:GetCastRange())
	local radius = hookshotAbility:GetSpecialValueInt("stun_radius")
	local speed = hookshotAbility:GetSpecialValueInt("speed")
	if isGoingOnSomeone then
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
				local ourHeroesNearby = enemyHero:GetNearbyHeroes(1200, true, BOT_MODE_NONE)
				local theirHeroesNearby = enemyHero:GetNearbyHeroes(1200, false, BOT_MODE_NONE)
				local travelTime = GetUnitToUnitDistance(bot, enemyHero) / speed + castPoint
				local hookLocation = Fu.GetCorrectLoc(enemyHero, travelTime)
				if
					ourHeroesNearby ~= nil
					and theirHeroesNearby ~= nil
					and #ourHeroesNearby >= #theirHeroesNearby
					and not Fu.IsUnitBetweenMeAndLocation(bot, enemyHero, hookLocation, radius)
					and not Fu.IsLocationInChrono(hookLocation)
					and not Fu.IsLocationInArena(hookLocation, 800)
				then
					if #ourHeroesNearby == 0 and #theirHeroesNearby == 0 then
						if
							bot:GetEstimatedDamageToTarget(true, enemyHero, 5, DAMAGE_TYPE_ALL) > enemyHero:GetHealth()
							and Fu.CanCastAbility(powerCogsAbility)
							and Fu.CanCastAbility(batteryAssaultAbility)
						then
							bot:SetTarget(enemyHero)
							return BOT_ACTION_DESIRE_HIGH, hookLocation
						end
					else
						if #ourHeroesNearby >= 1 then
							bot:SetTarget(enemyHero)
							return BOT_ACTION_DESIRE_HIGH, hookLocation
						end
					end
				end
			end
		end
	end
	if isRetreating and bot:GetActiveModeDesire() > 0.75 then
		local nearbyAllies = Fu.GetAlliesNearLoc(bot:GetLocation(), castRange)
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE)
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.IsChasingTarget(enemyHero, bot)
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and not Fu.IsDisabled(enemyHero)
			then
				local ourHeroesNearby = enemyHero:GetNearbyHeroes(1200, true, BOT_MODE_NONE)
				local theirHeroesNearby = enemyHero:GetNearbyHeroes(1200, false, BOT_MODE_NONE)
				if ourHeroesNearby ~= nil and theirHeroesNearby ~= nil and (#theirHeroesNearby > #ourHeroesNearby or bot:WasRecentlyDamagedByAnyHero(2)) then
					for _, allyHero in pairs(nearbyAllies) do
						if
							Fu.IsValidHero(allyHero)
							and bot:DistanceFromFountain() > 1600
							and allyHero:DistanceFromFountain() > 1600
							and bot:DistanceFromFountain() > allyHero:DistanceFromFountain()
							and GetUnitToUnitDistance(bot, allyHero) > 1200
							-- was "not Fu.IsNotSelf" (= allyHero is Clockwerk himself), so the hook-to-ally escape never fired
							and Fu.IsNotSelf(bot, allyHero)
						then
							local travelTime = GetUnitToUnitDistance(bot, allyHero) / speed + castPoint
							local hookLocation = Fu.GetCorrectLoc(allyHero, travelTime)
							if
								not Fu.IsUnitBetweenMeAndLocation(bot, allyHero, hookLocation, radius)
								and not Fu.IsLocationInChrono(hookLocation)
								and not Fu.IsLocationInArena(hookLocation, 800)
							then
								return BOT_ACTION_DESIRE_HIGH, hookLocation
							end
						end
					end
				end
			end
		end
		-- Hookshot latches onto a unit, not a spot. The old loop aimed at any neutral SPAWNER nearer the
		-- escape point with no range check, so it hooked empty camps or walked Clockwerk toward a camp
		-- far beyond cast range. Now: a visible neutral creep inside hook range, nearer safety, path clear.
		local escapeLocation = Fu.GetEscapeLoc()
		local escapeDistance = GetUnitToLocationDistance(bot, escapeLocation)
		for _, neutralCreep in pairs(GetUnitList(UNIT_LIST_NEUTRAL_CREEPS) or {}) do
			if
				Fu.IsValid(neutralCreep)
				and neutralCreep:CanBeSeen()
				and GetUnitToUnitDistance(bot, neutralCreep) > 700
				and GetUnitToUnitDistance(bot, neutralCreep) <= castRange
				and Fu.GetDistance(neutralCreep:GetLocation(), escapeLocation) < escapeDistance - 500
			then
				local creepLocation = neutralCreep:GetLocation()
				if
					not Fu.IsUnitBetweenMeAndLocation(bot, neutralCreep, creepLocation, radius)
					and not Fu.IsLocationInChrono(creepLocation)
					and not Fu.IsLocationInArena(creepLocation, 800)
				then
					if DotaTime() >= (bot._hookCampLogAt or -999) then
						bot._hookCampLogAt = DotaTime() + 10
						pcall(print, string.format(
							"[OHA-RATTLETRAP] t=%.0f hookshot escape onto %s dist=%d",
							DotaTime(),
							neutralCreep:GetUnitName(),
							math.floor(GetUnitToUnitDistance(bot, neutralCreep))
						))
					end
					return BOT_ACTION_DESIRE_HIGH, creepLocation
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.ConsiderJetpack()
	if not Fu.CanCastAbility(jetpackAbility) then
		return BOT_ACTION_DESIRE_NONE
	end
	if isRetreating and bot:GetActiveModeDesire() > 0.5 then
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE)
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.IsInRange(bot, enemyHero, 800)
				and Fu.IsChasingTarget(enemyHero, bot)
				and not Fu.IsSuspiciousIllusion(enemyHero)
			then
				local ourHeroesNearby = enemyHero:GetNearbyHeroes(1200, true, BOT_MODE_NONE)
				local theirHeroesNearby = enemyHero:GetNearbyHeroes(1200, false, BOT_MODE_NONE)
				if ourHeroesNearby ~= nil and theirHeroesNearby ~= nil and (#theirHeroesNearby > #ourHeroesNearby or bot:WasRecentlyDamagedByAnyHero(2.5)) then
					return BOT_ACTION_DESIRE_HIGH
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderOverclocking()
	if not Fu.CanCastAbility(overclockingAbility) then
		return BOT_ACTION_DESIRE_NONE
	end
	if Fu.IsInTeamFight(bot, 1200) then
		local nearbyEnemies = Fu.GetEnemiesNearLoc(bot:GetLocation(), 1200)
		if nearbyEnemies ~= nil and #nearbyEnemies >= 2 and isAttacking then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
return X
