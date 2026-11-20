-- Storm Spirit: skill build, item build, and ability use for this hero.
local X = {}
local bot = GetBot()
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local AbilityContext = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local Minion = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local sTalentList = Fu.Skill.GetTalentList(bot)
local sAbilityList = Fu.Skill.GetAbilityList(bot)
local sRole = Fu.Item.GetRoleItemsBuyList(bot)
local tTalentTreeList = { ["t25"] = { 0, 10 }, ["t20"] = { 0, 10 }, ["t15"] = { 0, 10 }, ["t10"] = { 10, 0 } }
local tAllAbilityBuildList = { { 1, 3, 2, 1, 1, 6, 1, 3, 3, 3, 6, 2, 2, 2, 6 } }
local nAbilityBuildList = Fu.Skill.GetRandomBuild(tAllAbilityBuildList)
local nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList)
local sRoleItemsBuyList = {}
sRoleItemsBuyList["pos_2"] = {
	"item_tango",
	"item_double_branches",
	"item_faerie_fire",
	"item_bottle",
	"item_null_talisman",
	"item_magic_wand",
	"item_power_treads_int",
	"item_witch_blade",
	"item_kaya_and_sange",
	"item_devastator",
	"item_black_king_bar",
	"item_ultimate_scepter",
	"item_shivas_guard",
	"item_aghanims_shard",
	"item_sheepstick",
	"item_moon_shard",
	"item_ultimate_scepter_2",
	"item_travel_boots_2",
}
sRoleItemsBuyList["pos_3"] = {
	"item_tango",
	"item_double_branches",
	"item_circlet",
	"item_mantle",
	"item_magic_wand",
	"item_null_talisman",
	"item_power_treads",
	"item_falcon_blade",
	"item_witch_blade",
	"item_kaya_and_sange",
	"item_devastator",
	"item_black_king_bar",
	"item_ultimate_scepter",
	"item_shivas_guard",
	"item_aghanims_shard",
	"item_sheepstick",
	"item_moon_shard",
	"item_ultimate_scepter_2",
	"item_travel_boots_2",
}
sRoleItemsBuyList["pos_1"] = sRoleItemsBuyList["pos_3"]
sRoleItemsBuyList["pos_4"] = {
	"item_tango",
	"item_tango",
	"item_double_branches",
	"item_enchanted_mango",
	"item_enchanted_mango",
	"item_blood_grenade",
	"item_magic_wand",
	"item_arcane_boots",
	"item_glimmer_cape",
	"item_guardian_greaves",
	"item_orchid",
	"item_shivas_guard",
	"item_kaya_and_sange",
	"item_aghanims_shard",
	"item_sheepstick",
	"item_moon_shard",
	"item_bloodthorn",
	"item_ultimate_scepter_2",
}
sRoleItemsBuyList["pos_5"] = {
	"item_tango",
	"item_tango",
	"item_double_branches",
	"item_enchanted_mango",
	"item_enchanted_mango",
	"item_blood_grenade",
	"item_magic_wand",
	"item_arcane_boots",
	"item_orchid",
	"item_glimmer_cape",
	"item_pavise",
	"item_pipe",
	"item_solar_crest",
	"item_aghanims_shard",
	"item_shivas_guard",
	"item_sheepstick",
	"item_moon_shard",
	"item_bloodthorn",
	"item_ultimate_scepter_2",
}
X["sBuyList"] = sRoleItemsBuyList[sRole]
X["sSellList"] = { "item_shivas_guard", "item_magic_wand", "item_cyclone", "item_magic_wand" }
if Fu.Role.IsPvNMode() or Fu.Role.IsAllShadow() then
	X["sBuyList"], X["sSellList"] = { "PvN_mid" }, {}
end
nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"] =
	Fu.SetUserHeroInit(nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"])
X["sSkillList"] = Fu.Skill.GetSkillList(sAbilityList, nAbilityBuildList, sTalentList, nTalentBuildList)
X["bDeafaultAbility"] = false
X["bDeafaultItem"] = false
function X.MinionThink(minionUnit)
	if Minion.IsValidUnit(minionUnit) then
		Minion.IllusionThink(minionUnit)
	end
end
local staticRemnantAbility =
	SafeAbility(bot:GetAbilityByName("storm_spirit_static_remnant"), "storm_spirit_static_remnant", "storm_spirit")
local electricVortexAbility =
	SafeAbility(bot:GetAbilityByName("storm_spirit_electric_vortex"), "storm_spirit_electric_vortex", "storm_spirit")
local overloadAbility =
	SafeAbility(bot:GetAbilityByName("storm_spirit_overload"), "storm_spirit_overload", "storm_spirit")
local ballLightningAbility =
	SafeAbility(bot:GetAbilityByName("storm_spirit_ball_lightning"), "storm_spirit_ball_lightning", "storm_spirit")
local staticRemnantDesire, staticRemnantLocation
local electricVortexDesire, electricVortexTarget
local overloadDesire
local ballLightningDesire, ballLightningLocation
local ballVortexDesire, ballVortexLocation, ballVortexDelay
local botTarget
local isGoingOnSomeone
local isAttacking
local hpRatio
local isInTeamFight
function X.SkillsComplement()
	if Fu.CanNotUseAbility(bot) then
		return
	end
	isGoingOnSomeone = Fu.IsGoingOnSomeone(bot)
	isAttacking = Fu.IsAttacking(bot)
	hpRatio = Fu.GetHP(bot)
	isInTeamFight = Fu.IsInTeamFight(bot, 1200)
	botTarget = Fu.GetProperTarget(bot)
	ballVortexDesire, ballVortexLocation, ballVortexDelay = X.ConsiderBallVortex()
	if ballVortexDesire > 0 then
		bot:Action_ClearActions(false)
		bot:ActionQueue_UseAbilityOnLocation(ballLightningAbility, ballVortexLocation)
		bot:ActionQueue_Delay(ballVortexDelay)
		bot:ActionQueue_UseAbility(electricVortexAbility)
		return
	end
	ballLightningDesire, ballLightningLocation = X.ConsiderBallLightning()
	if ballLightningDesire > 0 then
		bot:Action_UseAbilityOnLocation(ballLightningAbility, ballLightningLocation)
		return
	end
	electricVortexDesire, electricVortexTarget = X.ConsiderElectricVortex()
	if electricVortexDesire > 0 then
		if bot:HasScepter() and string.find(GetBot():GetUnitName(), "storm_spirit") then
			bot:Action_UseAbility(electricVortexAbility)
			return
		else
			-- Review fix: the test was reversed (cost > mana + 150), so the Vortex+Remnant follow-up was
			-- queued only when Storm could NOT pay for both. Queue it when he can, with 150 to spare.
			if
				Fu.CanCastAbility(staticRemnantAbility)
				and staticRemnantAbility:GetManaCost() + electricVortexAbility:GetManaCost() + 150 < bot:GetMana()
			then
				Fu.SetQueuePtToINT(bot, true)
				bot:ActionQueue_UseAbilityOnEntity(electricVortexAbility, electricVortexTarget)
				bot:ActionQueue_Delay(0.3 + 0.77)
				-- Review fix: Remnant is point-targeted (game data is_point_targeted, range 800) and every
				-- other Remnant order here is a location order; drop it at Storm's spot, where Vortex pulls.
				bot:ActionQueue_UseAbilityOnLocation(staticRemnantAbility, bot:GetLocation())
				if DotaTime() - (X.lastVortexLog or -99) > 10 then
					X.lastVortexLog = DotaTime()
					pcall(
						print,
						string.format(
							"[OHA-STORM] t=%.0f vortex-remnant target=%s mana=%d",
							DotaTime(),
							electricVortexTarget:GetUnitName(),
							bot:GetMana()
						)
					)
				end
				return
			else
				bot:Action_UseAbilityOnEntity(electricVortexAbility, electricVortexTarget)
				return
			end
		end
	end
	staticRemnantDesire, staticRemnantLocation = X.ConsiderStaticRemnant()
	if staticRemnantDesire > 0 then
		Fu.SetQueuePtToINT(bot, true)
		bot:ActionQueue_UseAbilityOnLocation(staticRemnantAbility, staticRemnantLocation)
		return
	end
	overloadDesire = X.ConsiderOverload()
	if overloadDesire > 0 then
		bot:Action_UseAbility(overloadAbility)
		return
	end
end
function X.ConsiderStaticRemnant()
	if not Fu.CanCastAbility(staticRemnantAbility) then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local castRange = 800
	local radius = staticRemnantAbility:GetSpecialValueInt("static_remnant_radius")
	local abilityLevel = staticRemnantAbility:GetLevel()
	local manaAfter = Fu.GetManaAfter(staticRemnantAbility:GetManaCost())
	local damage = staticRemnantAbility:GetSpecialValueInt("static_remnant_damage")
	local attackRange = bot:GetAttackRange()
	local nearbyAllies = bot:GetNearbyHeroes(1600, false, BOT_MODE_NONE)
	local nearbyEnemies = bot:GetNearbyHeroes(1600, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and Fu.IsInRange(bot, enemyHero, castRange)
			and Fu.CanKillTarget(enemyHero, damage, DAMAGE_TYPE_MAGICAL)
			and not enemyHero:HasModifier("modifier_abaddon_aphotic_shield")
			and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
			and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
			and not enemyHero:HasModifier("modifier_oracle_false_promise")
			and not enemyHero:HasModifier("modifier_templar_assassin_refraction_absorb")
		then
			local isChasing = Fu.IsChasingTarget(bot, enemyHero)
			if not isChasing or isChasing and Fu.IsInRange(bot, enemyHero, attackRange) then
				return BOT_ACTION_DESIRE_HIGH, enemyHero:GetLocation()
			end
		end
	end
	if isGoingOnSomeone then
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
			and not botTarget:HasModifier("modifier_templar_assassin_refraction_absorb")
		then
			local isChasing = Fu.IsChasingTarget(bot, botTarget)
			if not isChasing or isChasing and Fu.IsInRange(bot, botTarget, attackRange) then
				return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
			end
		end
	end
	if Fu.IsRetreating(bot) and not Fu.IsRealInvisible(bot) then
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.IsInRange(bot, enemyHero, castRange)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
			then
				local isChasingBot = Fu.IsChasingTarget(enemyHero, bot)
				if
					isChasingBot and #nearbyAllies < #nearbyEnemies and hpRatio < 0.75
					or hpRatio < 0.5 and bot:WasRecentlyDamagedByHero(enemyHero, 3.0)
				then
					return BOT_ACTION_DESIRE_HIGH, enemyHero:GetLocation()
				end
			end
		end
	end
	local nearbyCreeps = bot:GetNearbyCreeps(1200, true)
	if Fu.IsFarming(bot) and abilityLevel >= 2 and manaAfter > 0.25 and isAttacking then
		if Fu.CanBeAttacked(nearbyCreeps[1]) and not Fu.IsRunning(nearbyCreeps[1]) then
			local aoeLocation = bot:FindAoELocation(true, false, nearbyCreeps[1]:GetLocation(), 0, radius, 0, 0)
			if aoeLocation.count >= 2 or aoeLocation.count == 1 and nearbyCreeps[1]:IsAncientCreep() then
				return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
			end
		end
	end
	if (Fu.IsPushing(bot) or Fu.IsDefending(bot)) and manaAfter > 0.25 then
		if Fu.CanBeAttacked(nearbyCreeps[1]) and not Fu.IsRunning(nearbyCreeps[1]) then
			local aoeLocation = bot:FindAoELocation(true, false, nearbyCreeps[1]:GetLocation(), 0, radius, 0, 0)
			if aoeLocation.count >= 3 then
				return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
			end
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if
			Fu.IsRoshan(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and isAttacking
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, castRange) and isAttacking then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	local aoeLocation = bot:FindAoELocation(true, false, bot:GetLocation(), castRange, radius, 0, damage)
	if Fu.IsInLaningPhase() then
		if aoeLocation.count >= 2 then
			return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
		end
	else
		if aoeLocation.count >= 3 then
			return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.ConsiderElectricVortex()
	if not Fu.CanCastAbility(electricVortexAbility) then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local castRange = Fu.GetProperCastRange(false, bot, electricVortexAbility:GetCastRange())
	local hasScepter = bot:HasScepter()
	local radius = hasScepter and 475 or 0
	local nearbyEnemies = bot:GetNearbyHeroes(1600, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.IsInRange(bot, enemyHero, castRange)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and (hasScepter or Fu.CanCastOnTargetAdvanced(enemyHero))
		then
			if enemyHero:IsChanneling() then
				return BOT_ACTION_DESIRE_HIGH, enemyHero
			end
		end
	end
	if isInTeamFight and bot:HasScepter() then
		local enemiesInRadius = Fu.GetEnemiesNearLoc(bot:GetLocation(), radius)
		if #enemiesInRadius >= 2 then
			return BOT_ACTION_DESIRE_HIGH, nil
		end
	end
	if isGoingOnSomeone then
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and (hasScepter or Fu.CanCastOnTargetAdvanced(botTarget))
			and not Fu.IsDisabled(botTarget)
		then
			if hasScepter then
				if Fu.IsInRange(bot, botTarget, radius) then
					return BOT_ACTION_DESIRE_HIGH, nil
				end
			else
				if Fu.IsInRange(bot, botTarget, castRange) then
					return BOT_ACTION_DESIRE_HIGH, botTarget
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.ConsiderOverload()
	if not Fu.CanCastAbility(overloadAbility) then
		return BOT_ACTION_DESIRE_NONE
	end
	local searchRadius = 750
	if isGoingOnSomeone then
		local alliesInRange = bot:GetNearbyHeroes(searchRadius, false, BOT_MODE_NONE)
		if #alliesInRange >= 2 then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderBallLightning()
	if
		not Fu.CanCastAbility(ballLightningAbility)
		or ballLightningAbility ~= nil and ballLightningAbility:IsInAbilityPhase()
		or bot:IsRooted()
		or bot:HasModifier("modifier_storm_spirit_ball_lightning")
		or bot:HasModifier("modifier_bloodseeker_rupture")
	then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local castPoint = ballLightningAbility:GetCastPoint()
	local mpRatio = bot:GetMana() / bot:GetMaxMana()
	local ballSpeed = ballLightningAbility:GetSpecialValueInt("ball_lightning_move_speed")
	local attackRange = bot:GetAttackRange()
	local nearbyEnemies = bot:GetNearbyHeroes(1600, true, BOT_MODE_NONE)
	if Fu.IsStuck(bot) or Fu.IsStunProjectileIncoming(bot, attackRange) then
		local escapeLocation = Fu.GetEscapeLoc()
		return BOT_ACTION_DESIRE_HIGH, Fu.Site.GetXUnitsTowardsLocation(bot, escapeLocation, 600)
	end
	if isGoingOnSomeone and mpRatio > 0.15 then
		if
			Fu.IsValidTarget(botTarget)
			and Fu.IsInRange(bot, botTarget, 1400)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.CanBeAttacked(botTarget)
			and not Fu.IsDisabled(botTarget)
			and not botTarget:HasModifier("modifier_faceless_void_chronosphere_freeze")
			and Fu.WeAreStronger(bot, 1400)
		then
			local distanceToTarget = GetUnitToUnitDistance(bot, botTarget)
			if distanceToTarget > attackRange or not bot:HasModifier("modifier_storm_spirit_overload") then
				local travelTime = GetUnitToUnitDistance(bot, botTarget) / ballSpeed + castPoint
				return BOT_ACTION_DESIRE_HIGH, Fu.GetCorrectLoc(botTarget, travelTime)
			end
		end
	end
	if Fu.IsRetreating(bot) and not Fu.IsRealInvisible(bot) then
		if
			Fu.IsValidHero(nearbyEnemies[1])
			and Fu.IsInRange(bot, nearbyEnemies[1], 600)
			and (Fu.IsChasingTarget(nearbyEnemies[1], bot) or hpRatio < 0.5 or not Fu.WeAreStronger(bot, 1200))
			and bot:WasRecentlyDamagedByAnyHero(5)
		then
			local escapeLocation = Fu.GetTeamFountain()
			local travelDistance = 1400 * (1 - hpRatio)
			if travelDistance < 700 then
				travelDistance = 700
			end
			return BOT_ACTION_DESIRE_HIGH, Fu.Site.GetXUnitsTowardsLocation(bot, escapeLocation, travelDistance)
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.ConsiderBallVortex()
	if X.CanDoBallVortex() then
		local radius = 475
		local castPoint = ballLightningAbility:GetCastPoint()
		local ballSpeed = ballLightningAbility:GetSpecialValueInt("ball_lightning_move_speed")
		local teamFightLocation = Fu.GetTeamFightLocation(bot)
		if isInTeamFight and teamFightLocation ~= nil and GetUnitToLocationDistance(bot, teamFightLocation) <= 1200 then
			local travelTime = GetUnitToLocationDistance(bot, teamFightLocation) / ballSpeed + castPoint
			local aoeLocation = bot:FindAoELocation(true, true, bot:GetLocation(), 1200, radius, travelTime, 0)
			local enemiesInRadius = Fu.GetEnemiesNearLoc(aoeLocation.targetloc, radius)
			if #enemiesInRadius >= 2 and not Fu.IsLocationInChrono(aoeLocation.targetloc) then
				return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc, travelTime
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0, 0
end
function X.CanDoBallVortex()
	if
		Fu.CanCastAbility(electricVortexAbility)
		and Fu.CanCastAbility(ballLightningAbility)
		and string.find(GetBot():GetUnitName(), "storm_spirit")
		and bot:HasScepter()
		and not bot:HasModifier("modifier_bloodseeker_rupture")
	then
		if isInTeamFight then
			local maxMana = bot:GetMaxMana()
			local initialManaBase = ballLightningAbility:GetSpecialValueInt("ball_lightning_initial_mana_base")
			local initialManaPercentage = ballLightningAbility:GetSpecialValueFloat(
				"ball_lightning_initial_mana_percentage"
			) / 100
			local teamFightLocation = Fu.GetTeamFightLocation(bot)
			if teamFightLocation ~= nil and GetUnitToLocationDistance(bot, teamFightLocation) <= 1200 then
				local distanceToFight = GetUnitToLocationDistance(bot, teamFightLocation)
				local ballManaCost = initialManaBase
					+ initialManaPercentage * maxMana
					+ (10 + 0.0065 * maxMana) * distanceToFight / 100
				local totalManaCost = ballManaCost + electricVortexAbility:GetManaCost()
				if bot:GetMana() >= totalManaCost then
					return true
				end
			end
		end
	end
	return false
end
return X
