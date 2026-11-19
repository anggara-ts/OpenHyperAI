-- Tinker: skill build, item build, and ability use for this hero.
local X = {}
local bot = GetBot()
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local AbilityContext = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local Minion = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local sTalentList = Fu.Skill.GetTalentList(bot)
local sAbilityList = Fu.Skill.GetAbilityList(bot)
local sRole = Fu.Item.GetRoleItemsBuyList(bot)
local tTalentTreeList = { ["t25"] = { 10, 0 }, ["t20"] = { 0, 10 }, ["t15"] = { 0, 10 }, ["t10"] = { 10, 0 } }
local tAllAbilityBuildList = { { 1, 2, 2, 2, 2, 6, 1, 1, 1, 3, 6, 3, 3, 3, 6 } }
local nAbilityBuildList = Fu.Skill.GetRandomBuild(tAllAbilityBuildList)
local nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList)
local sRoleItemsBuyList = {}
sRoleItemsBuyList["pos_2"] = {
	"item_tango",
	"item_double_branches",
	"item_faerie_fire",
	"item_bottle",
	"item_magic_wand",
	"item_blink",
	"item_aether_lens",
	"item_aghanims_shard",
	"item_kaya_and_sange",
	"item_ultimate_scepter",
	"item_black_king_bar",
	"item_shivas_guard",
	"item_ultimate_scepter_2",
	"item_moon_shard",
	"item_sheepstick",
	"item_overwhelming_blink",
}
sRoleItemsBuyList["pos_3"] = {
	"item_tango",
	"item_double_branches",
	"item_faerie_fire",
	"item_double_circlet",
	"item_magic_wand",
	"item_soul_ring",
	"item_blink",
	"item_kaya_and_sange",
	"item_angels_demise",
	"item_shivas_guard",
	"item_ultimate_scepter",
	"item_ultimate_scepter_2",
	"item_moon_shard",
	"item_sheepstick",
	"item_overwhelming_blink",
	"item_aghanims_shard",
}
sRoleItemsBuyList["pos_1"] = sRoleItemsBuyList["pos_3"]
sRoleItemsBuyList["pos_4"] = {
	"item_tango",
	"item_tango",
	"item_double_branches",
	"item_faerie_fire",
	"item_blood_grenade",
	"item_magic_wand",
	"item_arcane_boots",
	"item_rod_of_atos",
	"item_glimmer_cape",
	"item_aether_lens",
	"item_aghanims_shard",
	"item_guardian_greaves",
	"item_ultimate_scepter",
	"item_octarine_core",
	"item_gungir",
	"item_shivas_guard",
	"item_ultimate_scepter_2",
	"item_moon_shard",
}
sRoleItemsBuyList["pos_5"] = {
	"item_double_tango",
	"item_faerie_fire",
	"item_clarity",
	"item_blood_grenade",
	"item_boots",
	"item_urn_of_shadows",
	"item_tranquil_boots",
	"item_pipe",
	"item_spirit_vessel",
	"item_glimmer_cape",
	"item_pavise",
	"item_solar_crest",
	"item_boots_of_bearing",
	"item_octarine_core",
	"item_sheepstick",
	"item_aghanims_shard",
	"item_ultimate_scepter_2",
	"item_moon_shard",
}
X["sBuyList"] = sRoleItemsBuyList[sRole]
X["sSellList"] = { "item_black_king_bar", "item_quelling_blade" }
if Fu.Role.IsPvNMode() or Fu.Role.IsAllShadow() then
	X["sBuyList"], X["sSellList"] = { "PvN_mid" }, {}
end
nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"] =
	Fu.SetUserHeroInit(nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"])
X["sSkillList"] = Fu.Skill.GetSkillList(sAbilityList, nAbilityBuildList, sTalentList, nTalentBuildList)
X["bDeafaultAbility"] = false
X["bDeafaultItem"] = false
function X.MinionThink(minionUnit)
	Minion.MinionThink(minionUnit)
end
local laserAbility = SafeAbility(bot:GetAbilityByName("tinker_laser"), "tinker_laser", "tinker")
local marchOfTheMachinesAbility =
	SafeAbility(bot:GetAbilityByName("tinker_march_of_the_machines"), "tinker_march_of_the_machines", "tinker")
local deployTurretsAbility = SafeAbility(
	bot:GetAbilityByName("tinker_deploy_turrets"),
	"tinker_deploy_turrets",
	"tinker"
) or sAbilityList[3] and SafeAbility(bot:GetAbilityByName(sAbilityList[3]), "sAbilityList[3]", "tinker")
local warpFlareAbility = SafeAbility(bot:GetAbilityByName("tinker_warp_grenade"), "tinker_warp_grenade", "tinker")
local keenConveyanceAbility =
	SafeAbility(bot:GetAbilityByName("tinker_keen_teleport"), "tinker_keen_teleport", "tinker")
local rearmAbility = SafeAbility(bot:GetAbilityByName("tinker_rearm"), "tinker_rearm", "tinker")
local lastMarchTime = -999
local laserDesire, laserTarget
local marchDesire, marchLocation
local deployTurretsDesire, deployTurretsLocation
local warpFlareDesire, warpFlareTarget
local keenConveyanceDesire, keenConveyanceTarget
local lastTeleportTime = DotaTime()
local rearmDesire
local botTarget
if bot.healInBase == nil then
	bot.healInBase = false
end
if bot.shouldBlink == nil then
	bot.shouldBlink = false
end
local isGoingOnSomeone
local isRetreating
local isAttacking
local hpRatio
local mpRatio
local isInTeamFight
function X.SkillsComplement()
	isGoingOnSomeone = Fu.IsGoingOnSomeone(bot)
	isRetreating = Fu.IsRetreating(bot)
	isAttacking = Fu.IsAttacking(bot)
	hpRatio = Fu.GetHP(bot)
	mpRatio = Fu.GetMP(bot)
	isInTeamFight = Fu.IsInTeamFight(bot, 1200)
	if mpRatio > 0.8 or bot:HasModifier("modifier_fountain_invulnerability") then
		bot.healInBase = false
	end
	laserAbility = SafeAbility(bot:GetAbilityByName("tinker_laser"), "tinker_laser", "tinker")
	marchOfTheMachinesAbility =
		SafeAbility(bot:GetAbilityByName("tinker_march_of_the_machines"), "tinker_march_of_the_machines", "tinker")
	deployTurretsAbility = SafeAbility(bot:GetAbilityByName("tinker_deploy_turrets"), "tinker_deploy_turrets", "tinker")
		or sAbilityList[3] and SafeAbility(bot:GetAbilityByName(sAbilityList[3]), "sAbilityList[3]", "tinker")
	warpFlareAbility = SafeAbility(bot:GetAbilityByName("tinker_warp_grenade"), "tinker_warp_grenade", "tinker")
	keenConveyanceAbility = SafeAbility(bot:GetAbilityByName("tinker_keen_teleport"), "tinker_keen_teleport", "tinker")
	rearmAbility = SafeAbility(bot:GetAbilityByName("tinker_rearm"), "tinker_rearm", "tinker")
	if
		Fu.CanNotUseAbility(bot)
		or rearmAbility ~= nil and rearmAbility:IsInAbilityPhase()
		or keenConveyanceAbility ~= nil and keenConveyanceAbility:IsInAbilityPhase()
		or bot:HasModifier("modifier_tinker_rearm")
		or bot:HasModifier("modifier_teleporting")
	then
		return
	end
	botTarget = Fu.GetProperTarget(bot)
	if not isGoingOnSomeone and not Fu.IsDoingRoshan(bot) and not Fu.IsDoingTormentor(bot) then
		if not bot.healInBase then
			if Fu.IsInLaningPhase() then
				if rearmAbility ~= nil and rearmAbility:GetManaCost() > bot:GetMana() or hpRatio < 0.35 then
					bot.healInBase = true
				end
			else
				if mpRatio < 0.3 or hpRatio < 0.35 and mpRatio < 0.5 then
					bot.healInBase = true
				end
			end
		end
	end
	deployTurretsDesire, deployTurretsLocation = X.ConsiderDeployTurrets()
	if deployTurretsDesire > 0 then
		bot:Action_UseAbilityOnLocation(deployTurretsAbility, deployTurretsLocation)
		return
	end
	marchDesire, marchLocation = X.ConsiderMarchOfTheMachines()
	if marchDesire > 0 then
		bot:Action_UseAbilityOnLocation(marchOfTheMachinesAbility, marchLocation)
		lastMarchTime = DotaTime()
		return
	end
	laserDesire, laserTarget = X.ConsiderLaser()
	if laserDesire > 0 then
		bot:Action_UseAbilityOnEntity(laserAbility, laserTarget)
		return
	end
	warpFlareDesire, warpFlareTarget = X.ConsiderWarpFlare()
	if warpFlareDesire > 0 then
		bot:ActionQueue_UseAbilityOnEntity(warpFlareAbility, warpFlareTarget)
		return
	end
	rearmDesire = X.ConsiderRearm()
	if rearmDesire > 0 then
		bot:Action_UseAbility(rearmAbility)
		return
	end
	keenConveyanceDesire, keenConveyanceTarget, Type = X.ConsiderKeenConveyance()
	if keenConveyanceDesire > 0 then
		if Type == "unit" then
			bot:Action_UseAbilityOnEntity(keenConveyanceAbility, keenConveyanceTarget)
		else
			bot:Action_UseAbilityOnLocation(keenConveyanceAbility, keenConveyanceTarget)
		end
		lastTeleportTime = DotaTime()
		return
	end
end
function X.ConsiderLaser()
	if not Fu.CanCastAbility(laserAbility) then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castRange = Fu.GetProperCastRange(false, bot, laserAbility:GetCastRange())
	local damage = laserAbility:GetSpecialValueInt("laser_damage")
	local explosionRadius = laserAbility:GetSpecialValueInt("radius_explosion")
	local manaCost = laserAbility:GetManaCost()
	local nearbyEnemies = Fu.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.IsInRange(bot, enemyHero, castRange)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and Fu.CanCastOnTargetAdvanced(enemyHero)
			and Fu.CanKillTarget(enemyHero, damage, DAMAGE_TYPE_PURE)
			and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
			and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
			and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
			and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
		then
			return BOT_ACTION_DESIRE_HIGH, enemyHero
		end
	end
	if isInTeamFight then
		local strongestTarget = nil
		local highestDps = 0
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.IsInRange(bot, enemyHero, castRange)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
				and not Fu.IsMeepoClone(enemyHero)
				and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
			then
				local dps = enemyHero:GetAttackDamage() * enemyHero:GetAttackSpeed()
				if dps > highestDps then
					highestDps = dps
					strongestTarget = enemyHero
				end
			end
		end
		if strongestTarget ~= nil then
			return BOT_ACTION_DESIRE_HIGH, strongestTarget
		end
	end
	if isGoingOnSomeone then
		local bestTarget = nil
		local highestDps = 0
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.IsInRange(bot, enemyHero, castRange)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
				and not Fu.IsMeepoClone(enemyHero)
			then
				local dps = enemyHero:GetAttackDamage() * enemyHero:GetAttackSpeed()
				if highestDps < dps then
					highestDps = dps
					bestTarget = enemyHero
				end
			end
		end
		if bestTarget ~= nil then
			return BOT_ACTION_DESIRE_HIGH, bestTarget
		end
	end
	if isRetreating and not Fu.IsRealInvisible(bot) then
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.IsInRange(bot, enemyHero, castRange)
				and not Fu.IsInRange(bot, enemyHero, castRange / 2.5)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
				and Fu.IsChasingTarget(enemyHero, bot)
				and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
				and (bot:WasRecentlyDamagedByHero(enemyHero, 3.5) or hpRatio < 0.4)
			then
				return BOT_ACTION_DESIRE_HIGH, enemyHero
			end
		end
	end
	local laneCreeps = bot:GetNearbyLaneCreeps(castRange, true)
	if (Fu.IsPushing(bot) or Fu.IsDefending(bot)) and mpRatio > 0.35 then
		local aoeLocation = bot:FindAoELocation(true, false, bot:GetLocation(), castRange, explosionRadius, 0, 0)
		if isAttacking then
			if
				Fu.CanBeAttacked(laneCreeps[1])
				and not Fu.IsRunning(laneCreeps[1])
				and #laneCreeps >= 2
				and aoeLocation.count >= 2
			then
				return BOT_ACTION_DESIRE_HIGH, laneCreeps[1]
			end
		end
	end
	if Fu.IsFarming(bot) and mpRatio > 0.3 then
		if isAttacking then
			local aoeLocation = bot:FindAoELocation(true, false, bot:GetLocation(), 1200, explosionRadius, 0, 0)
			local neutralCreeps = bot:GetNearbyNeutralCreeps(1000)
			if
				Fu.IsValid(neutralCreeps[1])
				and (
					#neutralCreeps >= 2 and aoeLocation.count >= 2
					or #neutralCreeps == 1
						and (neutralCreeps[1]:IsAncientCreep() or Fu.GetHP(neutralCreeps[1]) > 0.5)
				)
			then
				return BOT_ACTION_DESIRE_HIGH, neutralCreeps[1]
			end
			if
				Fu.CanBeAttacked(laneCreeps[1])
				and not Fu.IsRunning(laneCreeps[1])
				and #laneCreeps >= 2
				and aoeLocation.count >= 2
			then
				return BOT_ACTION_DESIRE_HIGH, laneCreeps[1]
			end
		end
	end
	if Fu.IsLaning(bot) and (Fu.IsCore(bot) or not Fu.IsCore(bot) and not Fu.IsThereNonSelfCoreNearby(1200)) then
		local killableCreeps = {}
		for _, creep in pairs(laneCreeps) do
			if
				Fu.IsValid(creep)
				and Fu.IsInRange(bot, creep, castRange)
				and Fu.CanBeAttacked(creep)
				and (Fu.IsKeyWordUnit("ranged", creep) or Fu.IsKeyWordUnit("siege", creep) or Fu.IsKeyWordUnit(
					"flagbearer",
					creep
				))
				and creep:GetHealth() <= damage
			then
				if
					Fu.IsValidHero(nearbyEnemies[1])
					and GetUnitToUnitDistance(creep, nearbyEnemies[1]) < 600
					and mpRatio > 0.3
				then
					return BOT_ACTION_DESIRE_HIGH, creep
				end
			end
			if Fu.IsValid(creep) and Fu.CanBeAttacked(creep) then
				killableCreeps = Fu.GetCreepListAroundTargetCanKill(creep, explosionRadius, damage, true, false, true)
				if #killableCreeps >= 2 and mpRatio > 0.25 then
					return BOT_ACTION_DESIRE_HIGH, creep
				end
			end
		end
		if Fu.IsValidHero(nearbyEnemies[1]) and Fu.IsInLaningPhase(bot) then
			local allyTowers = bot:GetNearbyTowers(1600, false)
			if
				allyTowers ~= nil
				and #allyTowers >= 1
				and Fu.IsValidBuilding(allyTowers[1])
				and Fu.IsInRange(bot, nearbyEnemies[1], castRange)
				and Fu.CanCastOnNonMagicImmune(nearbyEnemies[1])
				and Fu.CanCastOnTargetAdvanced(nearbyEnemies[1])
				and Fu.GetManaAfter(manaCost) > 0.45
				and not nearbyEnemies[1]:HasModifier("modifier_abaddon_borrowed_time")
				and not nearbyEnemies[1]:HasModifier("modifier_dazzle_shallow_grave")
				and not nearbyEnemies[1]:HasModifier("modifier_necrolyte_reapers_scythe")
				and not nearbyEnemies[1]:HasModifier("modifier_templar_assassin_refraction_absorb")
				and GetUnitToUnitDistance(nearbyEnemies[1], allyTowers[1]) < 600
				and allyTowers[1]:GetAttackTarget() == nearbyEnemies[1]
			then
				return BOT_ACTION_DESIRE_HIGH, nearbyEnemies[1]
			end
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if Fu.IsRoshan(botTarget) and Fu.IsInRange(bot, botTarget, castRange) and isAttacking then
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, castRange) and isAttacking then
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function X.ConsiderMarchOfTheMachines()
	if not Fu.CanCastAbility(marchOfTheMachinesAbility) then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local castRange = Fu.GetProperCastRange(false, bot, marchOfTheMachinesAbility:GetCastRange())
	local castPoint = marchOfTheMachinesAbility:GetCastPoint()
	local marchDistance = marchOfTheMachinesAbility:GetSpecialValueInt("distance")
	local radius = marchOfTheMachinesAbility:GetSpecialValueInt("radius")
	local duration = marchOfTheMachinesAbility:GetSpecialValueInt("duration")
	local damage = marchOfTheMachinesAbility:GetSpecialValueInt("damage")
	if DotaTime() < lastMarchTime + duration / 2 then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local nearbyEnemies = Fu.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.IsInRange(bot, enemyHero, marchDistance)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and Fu.CanKillTarget(enemyHero, damage * duration, DAMAGE_TYPE_MAGICAL)
			and not Fu.IsChasingTarget(enemyHero, bot)
			and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
			and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
			and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
			and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
		then
			return BOT_ACTION_DESIRE_HIGH, Fu.Site.GetXUnitsTowardsLocation(bot, enemyHero:GetLocation(), castRange)
		end
	end
	if isGoingOnSomeone then
		local allyAoeLocation = bot:FindAoELocation(false, true, bot:GetLocation(), marchDistance / 2, radius, 0, 0)
		local enemyAoeLocation = bot:FindAoELocation(true, true, bot:GetLocation(), marchDistance / 2, radius, 0, 0)
		if not Fu.IsCore(bot) then
			if
				allyAoeLocation.count > 0
				and Fu.GetDistance(allyAoeLocation.targetloc, enemyAoeLocation.targetloc) <= marchDistance
			then
				return BOT_ACTION_DESIRE_HIGH,
					Fu.Site.GetXUnitsTowardsLocation(bot, allyAoeLocation.targetloc, castRange)
			end
		end
		if
			#nearbyEnemies <= 1
			and Fu.IsValidTarget(botTarget)
			and Fu.IsInRange(bot, botTarget, marchDistance)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and not botTarget:HasModifier("modifier_dazzle_shallow_grave")
		then
			return BOT_ACTION_DESIRE_HIGH, Fu.Site.GetXUnitsTowardsLocation(bot, botTarget:GetLocation(), castRange)
		end
		if enemyAoeLocation.count > 0 then
			return BOT_ACTION_DESIRE_HIGH, Fu.Site.GetXUnitsTowardsLocation(bot, enemyAoeLocation.targetloc, castRange)
		end
	end
	local laneCreeps = bot:GetNearbyLaneCreeps(1600, true)
	if (Fu.IsPushing(bot) or Fu.IsDefending(bot)) and mpRatio > 0.35 then
		if #laneCreeps >= 2 and Fu.CanBeAttacked(laneCreeps[1]) then
			return BOT_ACTION_DESIRE_HIGH,
				Fu.Site.GetXUnitsTowardsLocation(bot, Fu.GetCenterOfUnits(laneCreeps), castRange)
		end
		local aoeLocation = bot:FindAoELocation(true, true, bot:GetLocation(), marchDistance / 2, radius, castPoint, 0)
		if aoeLocation.count >= 1 then
			return BOT_ACTION_DESIRE_HIGH, Fu.Site.GetXUnitsTowardsLocation(bot, aoeLocation.targetloc, castRange)
		end
	end
	if Fu.IsFarming(bot) and mpRatio > 0.3 then
		if isAttacking then
			local aoeLocation = bot:FindAoELocation(true, false, bot:GetLocation(), 1200, radius, 0, 0)
			local neutralCreeps = bot:GetNearbyNeutralCreeps(1000)
			if
				Fu.CanBeAttacked(neutralCreeps[1])
				and (
					#neutralCreeps >= 2 and aoeLocation.count >= 2
					or #neutralCreeps == 1
						and (neutralCreeps[1]:IsAncientCreep() or Fu.GetHP(neutralCreeps[1]) > 0.5)
				)
			then
				return BOT_ACTION_DESIRE_HIGH,
					Fu.Site.GetXUnitsTowardsLocation(bot, Fu.GetCenterOfUnits(neutralCreeps), castRange)
			end
			if #laneCreeps >= 2 and Fu.CanBeAttacked(laneCreeps[1]) then
				return BOT_ACTION_DESIRE_HIGH,
					Fu.Site.GetXUnitsTowardsLocation(bot, Fu.GetCenterOfUnits(laneCreeps), castRange)
			end
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if
			Fu.IsRoshan(botTarget)
			and Fu.CanBeAttacked(botTarget)
			and Fu.IsInRange(bot, botTarget, marchDistance)
			and isAttacking
		then
			return BOT_ACTION_DESIRE_HIGH, Fu.Site.GetXUnitsTowardsLocation(bot, botTarget:GetLocation(), castRange)
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, marchDistance) and isAttacking then
			return BOT_ACTION_DESIRE_HIGH, Fu.Site.GetXUnitsTowardsLocation(bot, botTarget:GetLocation(), castRange)
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.ConsiderDeployTurrets()
	if not Fu.CanCastAbility(deployTurretsAbility) then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castRange = Fu.GetProperCastRange(false, bot, deployTurretsAbility:GetCastRange())
	local manaCost = deployTurretsAbility:GetManaCost()
	local nearbyEnemies = Fu.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE)
	if not isInTeamFight and Fu.GetManaAfter(manaCost) < 0.25 then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	if isGoingOnSomeone then
		if Fu.IsValidTarget(botTarget) and Fu.IsInRange(bot, botTarget, castRange) then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	if isRetreating and not Fu.IsRealInvisible(bot) then
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.IsInRange(bot, enemyHero, castRange)
				and Fu.IsChasingTarget(enemyHero, bot)
				and not Fu.IsSuspiciousIllusion(enemyHero)
			then
				return BOT_ACTION_DESIRE_HIGH, enemyHero:GetLocation()
			end
		end
	end
	if isInTeamFight then
		local aoeLocation = bot:FindAoELocation(true, true, bot:GetLocation(), castRange, 400, 0, 0)
		if aoeLocation.count >= 2 then
			return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
		end
		if Fu.IsValidHero(nearbyEnemies[1]) and Fu.IsInRange(bot, nearbyEnemies[1], castRange) then
			return BOT_ACTION_DESIRE_HIGH, nearbyEnemies[1]:GetLocation()
		end
	end
	if Fu.IsPushing(bot) then
		local enemyTowers = bot:GetNearbyTowers(castRange, true)
		if enemyTowers ~= nil and #enemyTowers >= 1 and Fu.IsValidBuilding(enemyTowers[1]) then
			return BOT_ACTION_DESIRE_HIGH, enemyTowers[1]:GetLocation()
		end
		local laneCreeps = bot:GetNearbyLaneCreeps(castRange, true)
		if #laneCreeps >= 3 and Fu.CanBeAttacked(laneCreeps[1]) then
			return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(laneCreeps)
		end
	end
	if Fu.IsDefending(bot) then
		if Fu.IsValidHero(nearbyEnemies[1]) and Fu.IsInRange(bot, nearbyEnemies[1], castRange) then
			return BOT_ACTION_DESIRE_HIGH, nearbyEnemies[1]:GetLocation()
		end
		local laneCreeps = bot:GetNearbyLaneCreeps(castRange, true)
		if #laneCreeps >= 3 and Fu.CanBeAttacked(laneCreeps[1]) then
			return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(laneCreeps)
		end
	end
	if Fu.IsDoingRoshan(bot) or Fu.IsDoingTormentor(bot) then
		if
			(Fu.IsRoshan(botTarget) or Fu.IsTormentor(botTarget))
			and Fu.IsInRange(bot, botTarget, castRange)
			and isAttacking
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
local teleportRetryDelay = 7
function X.ConsiderKeenConveyance()
	if
		not Fu.CanCastAbility(keenConveyanceAbility)
		or bot.healInBase and GetUnitToLocationDistance(bot, Fu.GetTeamFountain()) < 1000
	then
		return BOT_ACTION_DESIRE_NONE, nil, ""
	end
	local roshanLocation = Fu.GetCurrentRoshanLocation()
	local tormentorLocation = Fu.GetTormentorLocation(GetTeam())
	local abilityLevel = keenConveyanceAbility:GetLevel()
	local activeMode = bot:GetActiveMode()
	local channelTime = keenConveyanceAbility:GetChannelTime()
	local nearbyEnemies = Fu.GetEnemiesNearLoc(bot:GetLocation(), bot:GetCurrentVisionRange())
	if
		bot.healInBase
		and GetUnitToLocationDistance(bot, Fu.GetTeamFountain()) > 3200
		and nearbyEnemies ~= nil
		and #nearbyEnemies == 0
	then
		if Fu.IsInLaningPhase() then
			if GetLaneFrontAmount(GetTeam(), LANE_MID, true) < 0.28 then
				if bot:GetHealth() > Fu.GetTotalEstimatedDamageToTarget(nearbyEnemies, bot) then
					return BOT_ACTION_DESIRE_HIGH, Fu.GetTeamFountain(), "loc"
				end
			end
		end
		return BOT_ACTION_DESIRE_HIGH, Fu.GetTeamFountain(), "loc"
	end
	if isInTeamFight and not isRetreating then
		return BOT_ACTION_DESIRE_NONE, 0, ""
	end
	local teamFightLocation = Fu.GetTeamFightLocation(bot)
	if teamFightLocation ~= nil and mpRatio > 0.65 and not isRetreating and not Fu.IsInLaningPhase() then
		local alliesNearFight = Fu.GetAlliesNearLoc(teamFightLocation, 1200)
		if GetUnitToLocationDistance(bot, teamFightLocation) > 4100 then
			if abilityLevel <= 2 then
				return BOT_ACTION_DESIRE_HIGH, Fu.GetNearbyLocationToTp(teamFightLocation), "loc"
			else
				return BOT_ACTION_DESIRE_HIGH, alliesNearFight[1], "unit"
			end
		end
	end
	if DotaTime() < lastTeleportTime + teleportRetryDelay then
		return BOT_ACTION_DESIRE_NONE, 0, ""
	end
	if Fu.IsLaning(bot) and Fu.IsInLaningPhase() then
		local laneAmount = GetAmountAlongLane(LANE_MID, bot:GetLocation())
		local laneFrontAmount = GetLaneFrontAmount(GetTeam(), LANE_MID, false)
		if laneAmount.distance > 4100 or laneAmount.amount < laneFrontAmount / 5 then
			return BOT_ACTION_DESIRE_HIGH, GetLaneFrontLocation(GetTeam(), LANE_MID, -300), "loc"
		end
	end
	local laneDistanceSum = { 0, 0, 0 }
	local laneAllyCount = { 0, 0, 0 }
	for _, allyHero in pairs(GetUnitList(UNIT_LIST_ALLIED_HEROES)) do
		if
			Fu.IsValidHero(allyHero)
			and bot ~= allyHero
			and not Fu.IsSuspiciousIllusion(allyHero)
			and not Fu.IsMeepoClone(allyHero)
		then
			if
				allyHero:GetActiveMode() == BOT_MODE_PUSH_TOWER_TOP
				and bot:GetActiveMode() == BOT_MODE_PUSH_TOWER_TOP
			then
				laneAllyCount[1] = laneAllyCount[1] + 1
				laneDistanceSum[1] = laneDistanceSum[1]
					+ GetUnitToLocationDistance(allyHero, GetLaneFrontLocation(GetTeam(), LANE_TOP, 0))
			end
			if
				allyHero:GetActiveMode() == BOT_MODE_PUSH_TOWER_MID
				and bot:GetActiveMode() == BOT_MODE_PUSH_TOWER_MID
			then
				laneAllyCount[2] = laneAllyCount[2] + 1
				laneDistanceSum[2] = laneDistanceSum[2]
					+ GetUnitToLocationDistance(allyHero, GetLaneFrontLocation(GetTeam(), LANE_MID, 0))
			end
			if
				allyHero:GetActiveMode() == BOT_MODE_PUSH_TOWER_BOT
				and bot:GetActiveMode() == BOT_MODE_PUSH_TOWER_BOT
			then
				laneAllyCount[3] = laneAllyCount[3] + 1
				laneDistanceSum[3] = laneDistanceSum[3]
					+ GetUnitToLocationDistance(allyHero, GetLaneFrontLocation(GetTeam(), LANE_BOT, 0))
			end
		end
	end
	if laneAllyCount[1] ~= nil and laneAllyCount[1] >= 3 and laneDistanceSum[1] / laneAllyCount[1] <= 1200 then
		if GetUnitToLocationDistance(bot, GetLaneFrontLocation(GetTeam(), LANE_TOP, 0)) > 4000 then
			if abilityLevel == 3 then
				return BOT_ACTION_DESIRE_HIGH, GetLaneFrontLocation(GetTeam(), LANE_TOP, 0), "loc"
			else
				local pushTpLocation = Fu.GetPushTPLocation(LANE_TOP)
				if pushTpLocation then
					return BOT_ACTION_DESIRE_HIGH, pushTpLocation, "loc"
				end
			end
		end
	elseif laneAllyCount[2] ~= nil and laneAllyCount[2] >= 3 and laneDistanceSum[2] / laneAllyCount[2] <= 1200 then
		if GetUnitToLocationDistance(bot, GetLaneFrontLocation(GetTeam(), LANE_MID, 0)) > 4000 then
			if abilityLevel == 3 then
				return BOT_ACTION_DESIRE_HIGH, GetLaneFrontLocation(GetTeam(), LANE_MID, 0), "loc"
			else
				local pushTpLocation = Fu.GetPushTPLocation(LANE_MID)
				if pushTpLocation then
					return BOT_ACTION_DESIRE_HIGH, pushTpLocation, "loc"
				end
			end
		end
	elseif laneAllyCount[3] ~= nil and laneAllyCount[3] >= 3 and laneDistanceSum[3] / laneAllyCount[3] <= 1200 then
		if GetUnitToLocationDistance(bot, GetLaneFrontLocation(GetTeam(), LANE_BOT, 0)) > 4000 then
			if abilityLevel == 3 then
				return BOT_ACTION_DESIRE_HIGH, GetLaneFrontLocation(GetTeam(), LANE_BOT, 0), "loc"
			else
				local pushTpLocation = Fu.GetPushTPLocation(LANE_BOT)
				if pushTpLocation then
					return BOT_ACTION_DESIRE_HIGH, pushTpLocation, "loc"
				end
			end
		end
	end
	if Fu.IsDefending(bot) and nearbyEnemies ~= nil and #nearbyEnemies == 0 and not Fu.IsInLaningPhase() then
		local defendLane = LANE_MID
		if activeMode == BOT_MODE_DEFEND_TOWER_TOP then
			defendLane = LANE_TOP
		end
		if activeMode == BOT_MODE_DEFEND_TOWER_BOT then
			defendLane = LANE_BOT
		end
		local laneAmount = GetAmountAlongLane(defendLane, bot:GetLocation())
		local laneFrontAmount = GetLaneFrontAmount(GetTeam(), defendLane, false)
		if laneAmount.distance > 3200 or laneAmount.amount < laneFrontAmount / 5 then
			if GetUnitToLocationDistance(bot, Fu.GetDefendTPLocation(defendLane)) > 3200 then
				return BOT_ACTION_DESIRE_HIGH, Fu.GetDefendTPLocation(defendLane), "loc"
			end
		end
	end
	if Fu.IsFarming(bot) then
		local farmLane, farmDesire = Fu.GetMostFarmLaneDesire()
		if farmDesire > 0.75 then
			local laneFrontLocation = GetLaneFrontLocation(GetTeam(), farmLane, 0)
			local tpLocation = Fu.GetNearbyLocationToTp(laneFrontLocation)
			if tpLocation ~= nil and laneFrontLocation ~= nil and GetUnitToLocationDistance(bot, tpLocation) > 4000 then
				return BOT_ACTION_DESIRE_HIGH, laneFrontLocation, "loc"
			end
		end
	end
	if Fu.IsDoingRoshan(bot) then
		local alliesNearRoshan = Fu.GetAlliesNearLoc(roshanLocation, 800)
		if
			alliesNearRoshan ~= nil
			and #alliesNearRoshan >= 1
			and GetUnitToLocationDistance(bot, roshanLocation) > 3800
			and GetUnitToLocationDistance(bot, Fu.GetNearbyLocationToTp(roshanLocation)) > 3800
		then
			if abilityLevel <= 2 then
				return BOT_ACTION_DESIRE_HIGH, Fu.GetNearbyLocationToTp(roshanLocation), "loc"
			else
				return BOT_ACTION_DESIRE_HIGH, alliesNearRoshan[1], "unit"
			end
		end
	end
	if Fu.IsDoingTormentor(bot) then
		local alliesNearTormentor = Fu.GetAlliesNearLoc(tormentorLocation, 800)
		if
			alliesNearTormentor ~= nil
			and #alliesNearTormentor >= 2
			and GetUnitToLocationDistance(bot, tormentorLocation) > 3800
			and GetUnitToLocationDistance(bot, Fu.GetNearbyLocationToTp(tormentorLocation)) > 3800
		then
			if abilityLevel <= 2 then
				return BOT_ACTION_DESIRE_HIGH, Fu.GetNearbyLocationToTp(tormentorLocation), "loc"
			else
				return BOT_ACTION_DESIRE_HIGH, alliesNearTormentor[1], "unit"
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil, ""
end
function X.ConsiderRearm()
	if not Fu.CanCastAbility(rearmAbility) then
		return BOT_ACTION_DESIRE_NONE
	end
	local channelTime = rearmAbility:GetChannelTime()
	local nearbyEnemies = Fu.GetEnemiesNearLoc(bot:GetLocation(), 1600)
	if
		bot.healInBase
		and nearbyEnemies ~= nil
		and #nearbyEnemies == 0
		and keenConveyanceAbility ~= nil
		and keenConveyanceAbility:IsTrained()
		and keenConveyanceAbility:GetCooldownTimeRemaining() > channelTime
	then
		return BOT_ACTION_DESIRE_HIGH
	end
	-- Review fix: Rearm (100-200 mana, 1.25-2.75s channel) fired whenever Laser or March was on
	-- cooldown, in any situation: after a lane last-hit Laser, while walking alone, even while
	-- retreating with enemies on him (a channel there is a death). It also fired in fights and
	-- pushes with nothing on cooldown (game data: Rearm does not refresh items, affects_items 0).
	-- Now it needs a spell to refresh plus a reason: a fight he is in (not retreating), or the
	-- push/farm/Roshan cases below.
	local function spellOnCd()
		return laserAbility ~= nil
				and laserAbility:IsTrained()
				and laserAbility:GetCooldownTimeRemaining() > channelTime
			or marchOfTheMachinesAbility ~= nil and marchOfTheMachinesAbility:IsTrained() and marchOfTheMachinesAbility:GetCooldownTimeRemaining() > channelTime
			or deployTurretsAbility ~= nil
				and deployTurretsAbility:IsTrained()
				and deployTurretsAbility:GetCooldownTimeRemaining() > channelTime
	end
	if
		(isGoingOnSomeone or isInTeamFight)
		and not isRetreating
		and spellOnCd()
		and nearbyEnemies ~= nil
		and #nearbyEnemies >= 1
	then
		if DotaTime() - (X.lastRearmLog or -99) > 10 then
			X.lastRearmLog = DotaTime()
			pcall(
				print,
				string.format("[OHA-TINKER] t=%.0f rearm-fight enemies=%d mp=%.2f", DotaTime(), #nearbyEnemies, mpRatio)
			)
		end
		return BOT_ACTION_DESIRE_HIGH
	end
	local laneCreeps = bot:GetNearbyLaneCreeps(1600, true)
	if Fu.IsPushing(bot) or Fu.IsDefending(bot) then
		if #laneCreeps >= 2 and Fu.CanBeAttacked(laneCreeps[1]) and spellOnCd() then
			return BOT_ACTION_DESIRE_HIGH
		end
		local aoeLocation = bot:FindAoELocation(true, true, bot:GetLocation(), 1600, 900, 0, 0)
		if
			aoeLocation.count > 0
			and GetUnitToLocationDistance(bot, aoeLocation.targetloc) > 880
			and marchOfTheMachinesAbility ~= nil
			and marchOfTheMachinesAbility:GetCooldownTimeRemaining() > channelTime
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsFarming(bot) then
		if isAttacking then
			local neutralCreeps = bot:GetNearbyNeutralCreeps(800)
			if
				neutralCreeps ~= nil
				and (#neutralCreeps >= 2 or #neutralCreeps >= 1 and neutralCreeps[1]:IsAncientCreep())
				and mpRatio > 0.25
				and (
					laserAbility ~= nil and laserAbility:GetCooldownTimeRemaining() > channelTime
					or marchOfTheMachinesAbility ~= nil
						and marchOfTheMachinesAbility:GetCooldownTimeRemaining() > channelTime
				)
			then
				return BOT_ACTION_DESIRE_HIGH
			end
			if
				laneCreeps ~= nil
				and #laneCreeps >= 2
				and mpRatio > 0.25
				and (
					laserAbility ~= nil and laserAbility:GetCooldownTimeRemaining() > channelTime
					or marchOfTheMachinesAbility ~= nil
						and marchOfTheMachinesAbility:GetCooldownTimeRemaining() > channelTime
				)
			then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if
			Fu.IsRoshan(botTarget)
			and Fu.IsInRange(bot, botTarget, 800)
			and isAttacking
			and (
				deployTurretsAbility ~= nil and deployTurretsAbility:GetCooldownTimeRemaining() > channelTime
				or marchOfTheMachinesAbility ~= nil
					and marchOfTheMachinesAbility:GetCooldownTimeRemaining() > channelTime
			)
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if
			Fu.IsTormentor(botTarget)
			and Fu.IsInRange(bot, botTarget, 800)
			and isAttacking
			and (
				deployTurretsAbility ~= nil and deployTurretsAbility:GetCooldownTimeRemaining() > channelTime
				or marchOfTheMachinesAbility ~= nil
					and marchOfTheMachinesAbility:GetCooldownTimeRemaining() > channelTime
			)
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderWarpFlare()
	if not Fu.CanCastAbility(warpFlareAbility) then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castRange = Fu.GetProperCastRange(false, bot, warpFlareAbility:GetCastRange())
	if isRetreating then
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.IsChasingTarget(enemyHero, bot)
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and not Fu.IsDisabled(enemyHero)
				and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
			then
				local alliesNearChaser = enemyHero:GetNearbyHeroes(1200, true, BOT_MODE_NONE)
				local enemiesNearChaser = enemyHero:GetNearbyHeroes(1200, false, BOT_MODE_NONE)
				if
					alliesNearChaser ~= nil
					and enemiesNearChaser ~= nil
					and (#enemiesNearChaser > #alliesNearChaser or bot:WasRecentlyDamagedByAnyHero(2))
				then
					return BOT_ACTION_DESIRE_HIGH, enemyHero
				end
			end
		end
	end
	if Fu.IsPushing(bot) or Fu.IsDefending(bot) then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, 1200, false, BOT_MODE_NONE)
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE)
		if nearbyAllies ~= nil and nearbyEnemies ~= nil and #nearbyEnemies > #nearbyAllies then
			local bestTarget = nil
			local highestDamage = 0
			nearbyEnemies = Fu.GetEnemiesNearLoc(bot:GetLocation(), castRange)
			for _, enemyHero in pairs(nearbyEnemies) do
				if
					Fu.IsValidHero(enemyHero)
					and not Fu.IsSuspiciousIllusion(enemyHero)
					and not Fu.IsDisabled(enemyHero)
					and not enemyHero:HasModifier("modifier_enigma_black_hole_pull")
					and not enemyHero:HasModifier("modifier_faceless_void_chronosphere_freeze")
					and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
				then
					local estimatedDamage = enemyHero:GetEstimatedDamageToTarget(true, bot, 5, DAMAGE_TYPE_ALL)
					if estimatedDamage > highestDamage then
						highestDamage = estimatedDamage
						bestTarget = enemyHero
					end
				end
			end
			if bestTarget ~= nil then
				return BOT_ACTION_DESIRE_HIGH, bestTarget
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
return X
