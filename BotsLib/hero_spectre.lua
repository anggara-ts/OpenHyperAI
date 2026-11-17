-- Spectre: skill build, item build, and ability use for this hero.
local X = {}
local bot = GetBot()
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local AbilityContext = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local Minion = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local sTalentList = Fu.Skill.GetTalentList(bot)
local sAbilityList = Fu.Skill.GetAbilityList(bot)
local sRole = Fu.Item.GetRoleItemsBuyList(bot)
local tTalentTreeList = { ["t25"] = { 10, 0 }, ["t20"] = { 0, 10 }, ["t15"] = { 0, 10 }, ["t10"] = { 0, 10 } }
local tAllAbilityBuildList = { { 1, 3, 1, 2, 1, 6, 1, 3, 3, 3, 6, 2, 2, 2, 6 } }
local nAbilityBuildList = Fu.Skill.GetRandomBuild(tAllAbilityBuildList)
local nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList)
local sRoleItemsBuyList = {}
sRoleItemsBuyList["pos_1"] = {
	"item_tango",
	"item_double_branches",
	"item_quelling_blade",
	"item_wraith_band",
	"item_power_treads",
	"item_blade_mail",
	"item_magic_wand",
	"item_radiance",
	"item_manta",
	"item_ultimate_scepter",
	"item_orchid",
	"item_skadi",
	"item_basher",
	"item_aghanims_shard",
	"item_bloodthorn",
	"item_ultimate_scepter_2",
	"item_moon_shard",
	"item_abyssal_blade",
	"item_travel_boots_2",
}
sRoleItemsBuyList["pos_2"] = sRoleItemsBuyList["pos_1"]
sRoleItemsBuyList["pos_4"] = sRoleItemsBuyList["pos_1"]
sRoleItemsBuyList["pos_5"] = sRoleItemsBuyList["pos_1"]
sRoleItemsBuyList["pos_3"] = sRoleItemsBuyList["pos_1"]
X["sBuyList"] = sRoleItemsBuyList[sRole]
X["sSellList"] = { "item_black_king_bar", "item_quelling_blade" }
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
local spectralDaggerAbility = SafeAbility(bot:GetAbilityByName("spectre_spectral_dagger"), "spectre_spectral_dagger", "spectre")
local dispersionAbility = SafeAbility(bot:GetAbilityByName("spectre_dispersion"), "spectre_dispersion", "spectre")
local shadowStepAbility = SafeAbility(bot:GetAbilityByName("spectre_shadow_step"), "spectre_shadow_step", "spectre")
local hauntAbility = SafeAbility(bot:GetAbilityByName("spectre_haunt"), "spectre_haunt", "spectre")
local realityAbility = SafeAbility(bot:GetAbilityByName("spectre_reality"), "spectre_reality", "spectre")
local spectralDaggerDesire, spectralDaggerTarget, spectralDaggerTargetType
local dispersionDesire
local shadowStepDesire, shadowStepTarget
local hauntDesire
local realityDesire, realityLocation
local shadowStepCastTime = -1
local shadowStepDuration = 0
local lastShadowStepTarget = nil
local hauntCastTime = -1
local hauntDuration = 0
local botTarget
local isGoingOnSomeone
local isRetreating
local isAttacking
local mpRatio
function X.SkillsComplement()
	if Fu.CanNotUseAbility(bot) then
		return
	end
	isGoingOnSomeone = Fu.IsGoingOnSomeone(bot)
	isRetreating = Fu.IsRetreating(bot)
	isAttacking = Fu.IsAttacking(bot)
	mpRatio = Fu.GetMP(bot)
	realityDesire, realityLocation = X.ConsiderReality()
	if realityDesire > 0 then
		bot:Action_UseAbilityOnLocation(realityAbility, realityLocation)
		return
	end
	shadowStepDesire, shadowStepTarget = X.ConsiderShadowStep()
	if shadowStepDesire > 0 then
		bot:Action_UseAbilityOnEntity(shadowStepAbility, shadowStepTarget)
		shadowStepCastTime = DotaTime()
		return
	end
	hauntDesire = X.ConsiderHaunt()
	if hauntDesire > 0 then
		bot:Action_UseAbility(hauntAbility)
		hauntCastTime = DotaTime()
		return
	end
	spectralDaggerDesire, spectralDaggerTarget, spectralDaggerTargetType = X.ConsiderSpectralDagger()
	if spectralDaggerDesire > 0 then
		if spectralDaggerTargetType == "unit" then
			bot:Action_UseAbilityOnEntity(spectralDaggerAbility, spectralDaggerTarget)
		else
			bot:Action_UseAbilityOnLocation(spectralDaggerAbility, spectralDaggerTarget)
		end
		return
	end
	dispersionDesire = X.ConsiderDispersion()
	if dispersionDesire > 0 then
		bot:Action_UseAbility(dispersionAbility)
		return
	end
end
function X.ConsiderSpectralDagger()
	if not spectralDaggerAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil, nil
	end
	local castRange = Fu.GetProperCastRange(false, bot, spectralDaggerAbility:GetCastRange())
	local castPoint = spectralDaggerAbility:GetCastPoint()
	local radius = spectralDaggerAbility:GetSpecialValueInt("path_radius")
	local damage = spectralDaggerAbility:GetSpecialValueInt("damage")
	local speed = spectralDaggerAbility:GetSpecialValueInt("speed")
	botTarget = Fu.GetProperTarget(bot)
	if Fu.IsStuck(bot) then
		return BOT_ACTION_DESIRE_HIGH, Fu.Site.GetXUnitsTowardsLocation(bot, Fu.GetEscapeLoc(), castRange), "loc"
	end
	local enemyHeroes = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(enemyHeroes) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			-- datafeed: Spectral Dagger deals magical damage (damage 2), not pure
			and Fu.CanKillTarget(enemyHero, damage, DAMAGE_TYPE_MAGICAL)
			and not Fu.IsSuspiciousIllusion(enemyHero)
			and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
			and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
			and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
			and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
			and not enemyHero:HasModifier("modifier_templar_assassin_refraction_absorb")
		then
			if Fu.CanKillTarget(enemyHero, damage, DAMAGE_TYPE_MAGICAL) then
				-- fix: U was a travel time, not a location; aim at the predicted position
				local targetLocation = Fu.GetCorrectLoc(enemyHero, GetUnitToUnitDistance(bot, enemyHero) / speed + castPoint)
				if Fu.IsInRange(bot, enemyHero, castRange / 2 - 150) then
					targetLocation = enemyHero:GetLocation()
				end
				return BOT_ACTION_DESIRE_HIGH, targetLocation, "loc"
			end
			if Fu.CanKillTarget(enemyHero, damage, DAMAGE_TYPE_PURE) then
				return BOT_ACTION_DESIRE_HIGH, enemyHero, "unit"
			end
		end
	end
	if Fu.IsInTeamFight(bot, 1200) then
		local aoe = bot:FindAoELocation(true, true, bot:GetLocation(), castRange, radius, 0, 0)
		local enemiesNearAoe = Fu.GetEnemiesNearLoc(aoe.targetloc, radius)
		if enemiesNearAoe ~= nil and #enemiesNearAoe >= 2 then
			return BOT_ACTION_DESIRE_HIGH, aoe.targetloc, "loc"
		end
	end
	if isGoingOnSomeone then
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not Fu.IsDisabled(botTarget)
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			local targetEnemies = Fu.GetNearbyHeroes(botTarget, 1200, true, BOT_MODE_NONE)
			local targetAllies = Fu.GetNearbyHeroes(botTarget, 1200, false, BOT_MODE_NONE)
			if targetEnemies ~= nil and targetAllies ~= nil and #targetEnemies >= #targetAllies then
				return BOT_ACTION_DESIRE_HIGH, botTarget, "unit"
			end
		end
	end
	if isRetreating then
		local retreatAllies = Fu.GetNearbyHeroes(bot, 1000, false, BOT_MODE_NONE)
		local retreatEnemies = Fu.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE)
		if
			retreatAllies ~= nil
			and retreatEnemies ~= nil
			and Fu.IsValidHero(retreatEnemies[1])
			and not Fu.IsSuspiciousIllusion(retreatEnemies[1])
			and not Fu.IsDisabled(retreatEnemies[1])
		then
			local firstEnemyAllies = Fu.GetNearbyHeroes(retreatEnemies[1], 1200, false, BOT_MODE_NONE)
			if firstEnemyAllies ~= nil and (#firstEnemyAllies > #retreatAllies or bot:WasRecentlyDamagedByAnyHero(1.5)) then
				return BOT_ACTION_DESIRE_HIGH, retreatEnemies[1], "unit"
			end
		end
		for _, enemyHero in pairs(enemyHeroes) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.IsInRange(bot, enemyHero, castRange)
				and Fu.IsChasingTarget(enemyHero, bot)
				and Fu.CanKillTarget(enemyHero, damage, DAMAGE_TYPE_MAGICAL)
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
				and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
				and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
				and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
				and not enemyHero:HasModifier("modifier_templar_assassin_refraction_absorb")
			then
				if Fu.CanKillTarget(enemyHero, damage, DAMAGE_TYPE_MAGICAL) then
					-- fix: U was a travel time, not a location; aim at the predicted position
					local targetLocation = Fu.GetCorrectLoc(enemyHero, GetUnitToUnitDistance(bot, enemyHero) / speed + castPoint)
					if Fu.IsInRange(bot, enemyHero, castRange / 2 - 150) then
						targetLocation = enemyHero:GetLocation()
					end
					return BOT_ACTION_DESIRE_HIGH, targetLocation, "loc"
				end
				if Fu.CanKillTarget(enemyHero, damage, DAMAGE_TYPE_PURE) then
					return BOT_ACTION_DESIRE_HIGH, enemyHero, "unit"
				end
			end
		end
	end
	if Fu.IsPushing(bot) or Fu.IsDefending(bot) then
		local aoe = bot:FindAoELocation(true, false, bot:GetLocation(), castRange, radius, 0, 0)
		local laneCreeps = bot:GetNearbyLaneCreeps(radius, true)
		if laneCreeps ~= nil and #laneCreeps >= 4 and aoe.count >= 4 then
			return BOT_ACTION_DESIRE_HIGH, aoe.targetloc, "loc"
		end
		aoe = bot:FindAoELocation(true, true, bot:GetLocation(), castRange, radius, 0, 0)
		if aoe.count >= 1 then
			return BOT_ACTION_DESIRE_HIGH, aoe.targetloc, "loc"
		end
	end
	if Fu.IsFarming(bot) then
		local aoe = bot:FindAoELocation(true, false, bot:GetLocation(), castRange, radius, 0, 0)
		if isAttacking and mpRatio > 0.45 then
			local neutralCreeps = bot:GetNearbyNeutralCreeps(radius)
			if neutralCreeps ~= nil and (#neutralCreeps >= 3 and aoe.count >= 3 or #neutralCreeps >= 2 and neutralCreeps[1]:IsAncientCreep() and aoe.count >= 2) then
				return BOT_ACTION_DESIRE_HIGH, aoe.targetloc, "loc"
			end
			local laneCreeps = bot:GetNearbyLaneCreeps(radius, true)
			if laneCreeps ~= nil and #laneCreeps >= 3 and aoe.count >= 3 then
				return BOT_ACTION_DESIRE_HIGH, aoe.targetloc, "loc"
			end
		end
	end
	if Fu.IsLaning(bot) then
		local killableCount = 0
		local killableCreeps = {}
		local laneCreeps = bot:GetNearbyLaneCreeps(castRange, true)
		local enemyHeroes = Fu.GetNearbyHeroes(bot, 1000, true, BOT_MODE_NONE)
		for _, creep in pairs(laneCreeps) do
			if Fu.IsValid(creep) and creep:GetHealth() <= damage then
				killableCount = killableCount + 1
				table.insert(killableCreeps, creep)
			end
		end
		if killableCount >= 2 and mpRatio > 0.25 and enemyHeroes ~= nil and #enemyHeroes >= 1 then
			return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(killableCreeps)
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if Fu.IsRoshan(botTarget) and Fu.CanCastOnNonMagicImmune(botTarget) and Fu.IsInRange(bot, botTarget, 500) and isAttacking then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation(), "loc"
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, 400) and isAttacking then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation(), "loc"
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil, nil
end
function X.ConsiderDispersion()
	if dispersionAbility:IsPassive() or dispersionAbility:IsHidden() or not dispersionAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
	end
	botTarget = Fu.GetProperTarget(bot)
	if isGoingOnSomeone then
		if Fu.IsValidTarget(botTarget) then
			local targetEnemies = Fu.GetNearbyHeroes(botTarget, 800, true, BOT_MODE_NONE)
			local targetAllies = Fu.GetNearbyHeroes(botTarget, 800, false, BOT_MODE_NONE)
			if targetEnemies ~= nil and targetAllies ~= nil and #targetEnemies >= #targetAllies then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	if isRetreating and bot:WasRecentlyDamagedByAnyHero(1.5) then
		return BOT_ACTION_DESIRE_HIGH
	end
	if Fu.IsDoingRoshan(bot) then
		if Fu.IsRoshan(botTarget) and Fu.CanCastOnNonMagicImmune(botTarget) and Fu.IsInRange(bot, botTarget, 500) and isAttacking then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, 400) and isAttacking then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderReality()
	if realityAbility:IsHidden() or not realityAbility:IsTrained() or not realityAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	hauntDuration = hauntAbility:GetSpecialValueFloat("duration")
	shadowStepDuration = shadowStepAbility:GetSpecialValueFloat("duration")
	if DotaTime() < shadowStepCastTime + shadowStepDuration then
		if lastShadowStepTarget ~= nil and Fu.IsValidTarget(lastShadowStepTarget) then
			return BOT_ACTION_DESIRE_HIGH, lastShadowStepTarget:GetLocation()
		end
		for _, allyHero in pairs(GetUnitList(UNIT_LIST_ALLIED_HEROES)) do
			local enemiesNearBot = Fu.GetEnemiesNearLoc(bot:GetLocation(), 1600)
			if enemiesNearBot ~= nil and #enemiesNearBot == 0 or bot:WasRecentlyDamagedByAnyHero(2.5) then
				local bestIllusion = nil
				local bestDistance = 100000
				if
					Fu.IsValidHero(allyHero)
					and allyHero:GetUnitName() == "npc_dota_hero_spectre"
					and (allyHero:IsIllusion() or Fu.IsSuspiciousIllusion(allyHero))
					and Fu.IsNotSelf(bot, allyHero)
				then
					local distance = GetUnitToLocationDistance(allyHero, Fu.GetEscapeLoc())
					if distance < bestDistance then
						bestDistance = distance
						bestIllusion = allyHero
					end
				end
				if bestIllusion ~= nil then
					return BOT_ACTION_DESIRE_HIGH, bestIllusion:GetLocation()
				end
			end
		end
	end
	if DotaTime() < hauntCastTime + hauntDuration then
		for _, allyHero in pairs(GetUnitList(UNIT_LIST_ALLIED_HEROES)) do
			if Fu.IsValidHero(allyHero) and not Fu.IsSuspiciousIllusion(allyHero) and not Fu.IsMeepoClone(allyHero) then
				local allyTarget = allyHero:GetAttackTarget()
				if
					Fu.IsGoingOnSomeone(allyHero)
					and not Fu.IsInRange(bot, allyHero, 1300)
					and not isRetreating
					and not isGoingOnSomeone
					and Fu.IsValidTarget(allyTarget)
					and not Fu.IsSuspiciousIllusion(allyTarget)
					and not Fu.IsLocationInChrono(allyTarget:GetLocation())
					and not Fu.IsLocationInBlackHole(allyTarget:GetLocation())
					and GetUnitToLocationDistance(allyTarget, GetAncient(GetOpposingTeam()):GetLocation()) >= 200
				then
					local enemiesNearAlly = Fu.GetNearbyHeroes(allyHero, 1200, true, BOT_MODE_NONE)
					local alliesNearAlly = Fu.GetNearbyHeroes(allyHero, 1200, false, BOT_MODE_NONE)
					if enemiesNearAlly ~= nil and alliesNearAlly ~= nil and #enemiesNearAlly + 1 >= #alliesNearAlly and not (#enemiesNearAlly + 1 >= 2 and #alliesNearAlly <= 1) then
						return BOT_ACTION_DESIRE_HIGH, allyTarget:GetLocation()
					end
				end
			end
			local enemiesNearBot = Fu.GetEnemiesNearLoc(bot:GetLocation(), 1600)
			if enemiesNearBot ~= nil and #enemiesNearBot == 0 or bot:WasRecentlyDamagedByAnyHero(2.5) then
				local bestIllusion = nil
				local bestDistance = 100000
				if
					Fu.IsValidHero(allyHero)
					and allyHero:GetUnitName() == "npc_dota_hero_spectre"
					and (allyHero:IsIllusion() or Fu.IsSuspiciousIllusion(allyHero))
					and Fu.IsNotSelf(bot, allyHero)
				then
					local distance = GetUnitToLocationDistance(allyHero, Fu.GetEscapeLoc())
					if distance < bestDistance then
						bestDistance = distance
						bestIllusion = allyHero
					end
				end
				if bestIllusion ~= nil then
					return BOT_ACTION_DESIRE_HIGH, bestIllusion:GetLocation()
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.ConsiderShadowStep()
	if not shadowStepAbility:IsFullyCastable() or Fu.IsInLaningPhase() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	shadowStepDuration = shadowStepAbility:GetSpecialValueFloat("duration")
	local teamFightLocation = Fu.GetTeamFightLocation(bot)
	-- Review fix: Shadow Step has a 1000 cast range (game data AbilityCastRange), not global. Targets
	-- up to 1600 away, and the far-fight branch below (fight > 1600 away), made Spectre walk across
	-- the map to cast it. Only pick targets inside cast range; Haunt covers far fights.
	local shadowStepRange = Fu.GetProperCastRange(false, bot, shadowStepAbility:GetCastRange())
	if isGoingOnSomeone then
		local weakestTarget = Fu.GetVulnerableWeakestUnit(bot, true, true, shadowStepRange)
		if
			Fu.IsValidTarget(weakestTarget)
			and GetUnitToUnitDistance(bot, weakestTarget) > 600
			and GetUnitToUnitDistance(bot, weakestTarget) <= shadowStepRange
			and not Fu.IsSuspiciousIllusion(weakestTarget)
			and not Fu.IsLocationInChrono(weakestTarget:GetLocation())
			and not Fu.IsLocationInBlackHole(weakestTarget:GetLocation())
		then
			local targetEnemies = Fu.GetNearbyHeroes(weakestTarget, 1200, true, BOT_MODE_NONE)
			local targetAllies = Fu.GetNearbyHeroes(weakestTarget, 1200, false, BOT_MODE_NONE)
			if targetEnemies ~= nil and targetAllies ~= nil and #targetEnemies >= #targetAllies and not (#targetEnemies >= 2 and #targetAllies <= 1) then
				lastShadowStepTarget = weakestTarget
				return BOT_ACTION_DESIRE_HIGH, weakestTarget
			end
		end
	end
	if
		teamFightLocation ~= nil
		and GetUnitToLocationDistance(bot, teamFightLocation) > 1600
		and bot:GetLevel() >= 6
		and bot:GetNetWorth() > 5000
		and not isRetreating
		and not isGoingOnSomeone
	then
		local lowestHealth = 99999
		local weakestTarget = nil
		local fightEnemies = Fu.GetEnemiesNearLoc(teamFightLocation, 1200)
		for _, enemyHero in pairs(fightEnemies) do
			if
				Fu.IsValidHero(enemyHero)
				and GetUnitToUnitDistance(bot, enemyHero) <= shadowStepRange -- Review fix: cast range, see above
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and not Fu.IsLocationInChrono(enemyHero:GetLocation())
				and not Fu.IsLocationInBlackHole(enemyHero:GetLocation())
			then
				local targetEnemies = Fu.GetNearbyHeroes(enemyHero, 1200, true, BOT_MODE_NONE)
				local targetAllies = Fu.GetNearbyHeroes(enemyHero, 1200, false, BOT_MODE_NONE)
				if lowestHealth > enemyHero:GetHealth() and targetEnemies ~= nil and targetAllies ~= nil and #targetEnemies >= #targetAllies then
					lowestHealth = enemyHero:GetHealth()
					weakestTarget = enemyHero
				end
			end
		end
		if weakestTarget ~= nil then
			lastShadowStepTarget = weakestTarget
			return BOT_ACTION_DESIRE_HIGH, weakestTarget
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function X.ConsiderHaunt()
	-- Review fix: Haunt waited for Shadow Step to be on cooldown, but Shadow Step only reaches 1000
	-- and this case needs the ally fight 1300+ away, so a ready Shadow Step blocked Haunt for good.
	if not hauntAbility:IsTrained() or not hauntAbility:IsFullyCastable() or hauntAbility:IsHidden() or Fu.IsInLaningPhase() then
		return BOT_ACTION_DESIRE_NONE
	end
	hauntDuration = hauntAbility:GetSpecialValueFloat("duration")
	for _, allyHero in pairs(GetUnitList(UNIT_LIST_ALLIED_HEROES)) do
		if Fu.IsValidHero(allyHero) and not Fu.IsSuspiciousIllusion(allyHero) and not Fu.IsMeepoClone(allyHero) then
			local allyTarget = allyHero:GetAttackTarget()
			if
				Fu.IsGoingOnSomeone(allyHero)
				and not Fu.IsInRange(bot, allyHero, 1300)
				and not isRetreating
				and not isGoingOnSomeone
				and Fu.IsValidTarget(allyTarget)
				and not Fu.IsSuspiciousIllusion(allyTarget)
				and not Fu.IsLocationInChrono(allyTarget:GetLocation())
				and not Fu.IsLocationInBlackHole(allyTarget:GetLocation())
			then
				local enemiesNearAlly = Fu.GetNearbyHeroes(allyHero, 1200, true, BOT_MODE_NONE)
				local alliesNearAlly = Fu.GetNearbyHeroes(allyHero, 1200, false, BOT_MODE_NONE)
				if enemiesNearAlly ~= nil and alliesNearAlly ~= nil and #enemiesNearAlly + 1 >= #alliesNearAlly and not (#enemiesNearAlly + 1 >= 2 and #alliesNearAlly <= 1) then
					if DotaTime() - (X.lastHauntLog or -99) > 10 then
						X.lastHauntLog = DotaTime()
						pcall(print, string.format("[OHA-SPECTRE] t=%.0f haunt ally=%s target=%s step_ready=%s", DotaTime(), allyHero:GetUnitName(), allyTarget:GetUnitName(), tostring(shadowStepAbility:IsFullyCastable())))
					end
					return BOT_ACTION_DESIRE_HIGH
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
return X
