-- Clinkz: skill build, item build, and ability use for this hero.
local X = {}
local bot = GetBot()
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local AbilityContext = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local Minion = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local sTalentList = Fu.Skill.GetTalentList(bot)
local sAbilityList = Fu.Skill.GetAbilityList(bot)
local sRole = Fu.Item.GetRoleItemsBuyList(bot)
local tTalentTreeList = {
	{ ["t25"] = { 0, 10 }, ["t20"] = { 0, 10 }, ["t15"] = { 0, 10 }, ["t10"] = { 0, 10 } },
	{ ["t25"] = { 0, 10 }, ["t20"] = { 0, 10 }, ["t15"] = { 0, 10 }, ["t10"] = { 0, 10 } },
}
-- tAllAbilityBuildList[2]: Skeleton Walk (ultimate) moved to entry 11 (level 12); it sat at entry 12 (level 13), a level late.
local tAllAbilityBuildList =
	{ { 2, 3, 2, 3, 3, 6, 2, 2, 1, 1, 6, 1, 1, 3, 6 }, { 2, 3, 2, 3, 3, 6, 2, 2, 1, 1, 6, 1, 1, 3, 6 } }
local nAbilityBuildList
local nTalentBuildList
if sRole == "pos_1" then
	nAbilityBuildList = tAllAbilityBuildList[1]
	nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList[1])
else
	nAbilityBuildList = tAllAbilityBuildList[2]
	nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList[2])
end
local sRoleItemsBuyList = {}
-- Stratz 7.41f, week of 9 Nov 2026: pos 1, 38,631 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_1"] = {
	"item_tango",
	"item_double_branches",
	"item_faerie_fire",
	"item_magic_stick",
	"item_magic_wand",
	"item_falcon_blade",
	"item_power_treads",
	"item_desolator",
	"item_dragon_lance",
	"item_lesser_crit",
	"item_hurricane_pike",
	"item_greater_crit",
	"item_black_king_bar",
	"item_ultimate_scepter",
	"item_travel_boots",
	"item_ultimate_scepter_2",
	"item_moon_shard",
	"item_sphere",
	"item_aghanims_shard",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 2, 34,387 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_2"] = {
	"item_tango",
	"item_double_branches",
	"item_faerie_fire",
	"item_magic_stick",
	"item_magic_wand",
	"item_falcon_blade",
	"item_power_treads",
	"item_oblivion_staff",
	"item_desolator",
	"item_orchid",
	"item_hurricane_pike",
	"item_black_king_bar",
	"item_ultimate_scepter",
	"item_travel_boots",
	"item_ultimate_scepter_2",
	"item_nullifier",
	-- removed a second item_dragon_lance here: one lance already listed above, and Hurricane Pike takes only one
	"item_aghanims_shard",
	"item_moon_shard",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 3, 3,106 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_3"] = {
	"item_tango",
	"item_double_branches",
	"item_faerie_fire",
	"item_circlet",
	"item_sobi_mask",
	"item_magic_wand",
	"item_falcon_blade",
	"item_power_treads",
	"item_desolator",
	"item_aghanims_shard",
	"item_hurricane_pike",
	"item_black_king_bar",
	"item_monkey_king_bar",
	"item_ultimate_scepter",
	"item_travel_boots",
	"item_ultimate_scepter_2",
	"item_sphere",
	"item_moon_shard",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 4, 4,261 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_4"] = {
	"item_tango",
	"item_blood_grenade",
	"item_double_branches",
	"item_blight_stone",
	"item_magic_wand",
	"item_falcon_blade",
	"item_power_treads",
	"item_orchid",
	"item_desolator",
	"item_hurricane_pike",
	"item_black_king_bar",
	"item_travel_boots",
	"item_aghanims_shard",
	"item_moon_shard",
	"item_ultimate_scepter_2",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 5, 1,731 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_5"] = {
	"item_tango",
	"item_blood_grenade",
	"item_double_branches",
	"item_magic_stick",
	"item_faerie_fire",
	"item_magic_wand",
	"item_falcon_blade",
	"item_power_treads",
	"item_orchid",
	"item_dragon_lance",
	"item_lesser_crit",
	"item_bloodthorn",
	"item_hurricane_pike",
	"item_black_king_bar",
	"item_aghanims_shard",
	"item_moon_shard",
	"item_ultimate_scepter_2",
}
X["sBuyList"] = sRoleItemsBuyList[sRole]
X["sSellList"] = {
	"item_hurricane_pike",
	"item_urn_of_shadows",
	"item_mjollnir",
	"item_magic_wand",
	"item_hand_of_midas",
	"item_urn_of_shadows",
	"item_greater_crit",
	"item_hand_of_midas",
	"item_greater_crit",
	"item_falcon_blade",
	-- Sold once the item before it is owned, to keep six slots (Util/item-builds/generate.js):
	"item_ultimate_scepter",
	"item_falcon_blade",
}
if Fu.Role.IsPvNMode() or Fu.Role.IsAllShadow() then
	X["sBuyList"], X["sSellList"] = { "PvN_antimage" }, {}
end
nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"] =
	Fu.SetUserHeroInit(nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"])
X["sSkillList"] = Fu.Skill.GetSkillList(sAbilityList, nAbilityBuildList, sTalentList, nTalentBuildList)
X["bDeafaultAbility"] = false
X["bDeafaultItem"] = false
function X.MinionThink(hMinionUnit)
	Minion.MinionThink(hMinionUnit)
end
local strafeAbility = SafeAbility(bot:GetAbilityByName("clinkz_strafe"), "clinkz_strafe", "clinkz")
local deathPactAbility = SafeAbility(bot:GetAbilityByName("clinkz_death_pact"), "clinkz_death_pact", "clinkz")
local burningBarrageAbility =
	SafeAbility(bot:GetAbilityByName("clinkz_burning_barrage"), "clinkz_burning_barrage", "clinkz")
local burningArmyAbility = SafeAbility(bot:GetAbilityByName("clinkz_burning_army"), "clinkz_burning_army", "clinkz")
local skeletonWalkAbility = SafeAbility(bot:GetAbilityByName("clinkz_wind_walk"), "clinkz_wind_walk", "clinkz")
local searingArrowsAbility =
	SafeAbility(bot:GetAbilityByName("clinkz_searing_arrows"), "clinkz_searing_arrows", "clinkz")
local strafeDesire
local deathPactDesire, deathPactTarget
local burningBarrageDesire, burningBarrageLocation
local burningArmyDesire, burningArmyLocation
local skeletonWalkDesire
local searingArrowsDesire, searingArrowsTarget
local botTarget
local isGoingOnSomeone
local isAttacking
local mpRatio
function X.SkillsComplement()
	if Fu.CanNotUseAbility(bot) then
		return
	end
	local context = AbilityContext.Build(bot)
	isGoingOnSomeone = context.isEngaging
	isAttacking = Fu.IsAttacking(bot)
	mpRatio = context.mp
	botTarget = context.target
	skeletonWalkDesire = X.ConsiderSkeletonWalk()
	if skeletonWalkDesire > 0 then
		bot:Action_UseAbility(skeletonWalkAbility)
		return
	end
	searingArrowsDesire, searingArrowsTarget = X.ConsiderSearingArrows()
	if searingArrowsDesire > 0 then
		bot:Action_UseAbilityOnEntity(searingArrowsAbility, searingArrowsTarget)
		return
	end
	burningBarrageDesire, burningBarrageLocation = X.ConsiderBurningBarrage()
	if burningBarrageDesire > 0 then
		bot:Action_UseAbilityOnLocation(burningBarrageAbility, burningBarrageLocation)
		return
	end
	strafeDesire = X.ConsiderStrafe()
	if strafeDesire > 0 then
		bot:Action_UseAbility(strafeAbility)
		return
	end
	deathPactDesire, deathPactTarget = X.ConsiderDeathPact()
	if deathPactDesire > 0 then
		bot:Action_UseAbilityOnEntity(deathPactAbility, deathPactTarget)
		return
	end
	burningArmyDesire, burningArmyLocation = X.ConsiderBurningArmy()
	if burningArmyDesire > 0 then
		bot:Action_UseAbilityOnLocation(burningArmyAbility, burningArmyLocation)
		return
	end
end
function X.ConsiderStrafe()
	if not strafeAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
	end
	local attackRange = bot:GetAttackRange()
	if isGoingOnSomeone then
		if
			Fu.IsValidTarget(botTarget)
			and Fu.IsInRange(bot, botTarget, attackRange)
			and not Fu.IsChasingTarget(bot, botTarget)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			local alliesNearTarget = Fu.GetNearbyHeroes(botTarget, 1200, true, BOT_MODE_NONE)
			local enemiesNearTarget = Fu.GetNearbyHeroes(botTarget, 1200, false, BOT_MODE_NONE)
			if alliesNearTarget ~= nil and enemiesNearTarget ~= nil and #alliesNearTarget >= #enemiesNearTarget then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	if Fu.IsFarming(bot) then
		if isAttacking then
			local nearbyNeutralCreeps = bot:GetNearbyNeutralCreeps(1000)
			if
				nearbyNeutralCreeps ~= nil
				and (#nearbyNeutralCreeps >= 3 or #nearbyNeutralCreeps >= 2 and nearbyNeutralCreeps[1]:IsAncientCreep())
			then
				if skeletonWalkAbility:IsTrained() then
					if
						Fu.GetManaAfter(strafeAbility:GetManaCost()) * bot:GetMana() > skeletonWalkAbility:GetManaCost()
					then
						return BOT_ACTION_DESIRE_HIGH
					end
				else
					if mpRatio > 0.25 then
						return BOT_ACTION_DESIRE_HIGH
					end
				end
			end
			local nearbyLaneCreeps = bot:GetNearbyLaneCreeps(1000, true)
			if nearbyLaneCreeps ~= nil and #nearbyLaneCreeps >= 4 then
				if skeletonWalkAbility:IsTrained() then
					if
						Fu.GetManaAfter(strafeAbility:GetManaCost()) * bot:GetMana() > skeletonWalkAbility:GetManaCost()
					then
						return BOT_ACTION_DESIRE_HIGH
					end
				else
					if mpRatio > 0.25 then
						return BOT_ACTION_DESIRE_HIGH
					end
				end
			end
		end
	end
	if Fu.IsPushing(bot) or Fu.IsDefending(bot) then
		local nearbyLaneCreeps = bot:GetNearbyLaneCreeps(1000, true)
		if nearbyLaneCreeps ~= nil and #nearbyLaneCreeps >= 4 then
			if skeletonWalkAbility:IsTrained() then
				if Fu.GetManaAfter(strafeAbility:GetManaCost()) * bot:GetMana() > skeletonWalkAbility:GetManaCost() then
					return BOT_ACTION_DESIRE_HIGH
				end
			else
				if mpRatio > 0.25 then
					return BOT_ACTION_DESIRE_HIGH
				end
			end
		end
	end
	if Fu.IsDoingRoshan(bot) or Fu.IsDoingTormentor(bot) then
		if
			(Fu.IsRoshan(botTarget) or Fu.IsTormentor(botTarget))
			and Fu.IsInRange(bot, botTarget, attackRange)
			and isAttacking
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderDeathPact()
	if not deathPactAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castRange = deathPactAbility:GetCastRange()
	local maxCreepLevel = deathPactAbility:GetSpecialValueInt("creep_level")
	local nearbyCreeps = bot:GetNearbyCreeps(castRange, true)
	if Fu.IsInLaningPhase() then
		if Fu.IsLaning(bot) then
			local nearbyLaneCreeps = bot:GetNearbyLaneCreeps(castRange, true)
			for _, creep in pairs(nearbyLaneCreeps) do
				if
					Fu.IsValid(creep)
					and Fu.CanBeAttacked(creep)
					and (
						Fu.IsKeyWordUnit("ranged", creep)
						or Fu.IsKeyWordUnit("siege", creep) and creep:GetLevel() <= maxCreepLevel
					)
				then
					local nearbyAllies = Fu.GetNearbyHeroes(bot, 1600, false, BOT_MODE_NONE)
					if
						nearbyAllies ~= nil
						and #nearbyAllies >= 1
						and GetUnitToUnitDistance(creep, nearbyAllies[1]) < 600
						and botTarget ~= creep
						and not bot:HasModifier("modifier_clinkz_death_pact")
					then
						return BOT_ACTION_DESIRE_HIGH, creep
					end
				end
			end
		end
	else
		local creep = GetMostHPCreepLevel(nearbyCreeps, maxCreepLevel)
		if creep ~= nil and not bot:HasModifier("modifier_clinkz_death_pact") and not creep:IsAncientCreep() then
			return BOT_ACTION_DESIRE_HIGH, creep
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function X.ConsiderSkeletonWalk()
	if
		not skeletonWalkAbility:IsFullyCastable()
		or bot:HasModifier("modifier_clinkz_wind_walk")
		or Fu.IsRealInvisible(bot)
	then
		return BOT_ACTION_DESIRE_NONE
	end
	local roshanLocation = Fu.GetCurrentRoshanLocation()
	local tormentorLocation = Fu.GetTormentorLocation(GetTeam())
	local nearbyEnemies = Fu.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE)
	if isGoingOnSomeone and bot:GetActiveModeDesire() > 0.65 then
		if
			Fu.IsValidTarget(botTarget)
			and GetUnitToUnitDistance(bot, botTarget) > 1600
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			local alliesNearTarget = Fu.GetAlliesNearLoc(botTarget:GetLocation(), 1200)
			local enemiesNearTarget = Fu.GetEnemiesNearLoc(botTarget:GetLocation(), 1200)
			if alliesNearTarget ~= nil and enemiesNearTarget ~= nil and #alliesNearTarget >= #enemiesNearTarget then
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
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and not Fu.IsDisabled(enemyHero)
			then
				local alliesNearEnemy = Fu.GetNearbyHeroes(enemyHero, 1200, true, BOT_MODE_NONE)
				local enemiesNearEnemy = Fu.GetNearbyHeroes(enemyHero, 1200, false, BOT_MODE_NONE)
				if
					alliesNearEnemy ~= nil
					and enemiesNearEnemy ~= nil
					and (#enemiesNearEnemy > #alliesNearEnemy or bot:WasRecentlyDamagedByAnyHero(1.5))
				then
					return BOT_ACTION_DESIRE_HIGH
				end
			end
		end
	end
	if Fu.IsFarming(bot) then
		if bot.farmLocation ~= nil then
			if GetUnitToLocationDistance(bot, bot.farmLocation) > 3200 then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	if Fu.IsLaning(bot) then
		if
			Fu.GetManaAfter(skeletonWalkAbility:GetManaCost()) > 0.8
			and bot:DistanceFromFountain() > 100
			and bot:DistanceFromFountain() < 6000
			and Fu.IsInLaningPhase()
			and nearbyEnemies ~= nil
			and #nearbyEnemies == 0
		then
			local assignedLane = bot:GetAssignedLane()
			local laneFrontLocation = GetLaneFrontLocation(GetTeam(), assignedLane, 0)
			local laneFrontDistance = GetUnitToLocationDistance(bot, laneFrontLocation)
			if laneFrontDistance > 1600 then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if GetUnitToLocationDistance(bot, roshanLocation) > 4000 then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if GetUnitToLocationDistance(bot, tormentorLocation) > 4000 then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderSearingArrows()
	if not Fu.CanCastAbility(searingArrowsAbility) or bot:IsDisarmed() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local attackRange = bot:GetAttackRange()
	local manaCost = searingArrowsAbility:GetManaCost()
	local manaAfter = Fu.GetManaAfter(manaCost)
	local manaThreshold = Fu.GetManaThreshold(
		bot,
		manaCost,
		{ strafeAbility, deathPactAbility, burningBarrageAbility, burningArmyAbility, skeletonWalkAbility }
	)
	local isAutoCastOn = searingArrowsAbility:GetAutoCastState()
	if isGoingOnSomeone then
		if
			Fu.IsValidHero(botTarget)
			and Fu.CanBeAttacked(botTarget)
			and Fu.IsInRange(bot, botTarget, attackRange + 300)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not botTarget:IsMagicImmune()
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			if manaAfter > manaThreshold + 0.1 then
				if not isAutoCastOn then
					searingArrowsAbility:ToggleAutoCast()
				end
				return BOT_ACTION_DESIRE_NONE
			end
		end
	end
	if Fu.IsPushing(bot) or Fu.IsDefending(bot) or Fu.IsFarming(bot) then
		if
			Fu.IsValid(botTarget)
			and Fu.CanBeAttacked(botTarget)
			and Fu.IsInRange(bot, botTarget, attackRange)
			and not Fu.CanKillTarget(botTarget, bot:GetAttackDamage() * 3, DAMAGE_TYPE_PHYSICAL)
			and not Fu.IsRoshan(botTarget)
			and not Fu.IsTormentor(botTarget)
		then
			if manaAfter > manaThreshold + 0.15 then
				if not isAutoCastOn then
					searingArrowsAbility:ToggleAutoCast()
				end
				return BOT_ACTION_DESIRE_NONE
			end
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if Fu.IsRoshan(botTarget) and Fu.CanBeAttacked(botTarget) and Fu.IsInRange(bot, botTarget, attackRange) then
			if manaAfter > manaThreshold + 0.15 then
				if not isAutoCastOn and isAttacking then
					searingArrowsAbility:ToggleAutoCast()
				end
				return BOT_ACTION_DESIRE_NONE
			end
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, attackRange) then
			if manaAfter > manaThreshold + 0.15 then
				if not isAutoCastOn and isAttacking then
					searingArrowsAbility:ToggleAutoCast()
				end
				return BOT_ACTION_DESIRE_NONE
			end
		end
	end
	if
		Fu.IsValidHero(botTarget)
		and Fu.CanBeAttacked(botTarget)
		and Fu.IsInRange(bot, botTarget, attackRange + 100)
		and not botTarget:IsMagicImmune()
		and manaAfter > manaThreshold
	then
		if not isAutoCastOn then
			searingArrowsAbility:ToggleAutoCast()
		end
		return BOT_ACTION_DESIRE_NONE
	end
	if isAutoCastOn then
		searingArrowsAbility:ToggleAutoCast()
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function X.ConsiderBurningBarrage()
	if not burningBarrageAbility:IsTrained() or not burningBarrageAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	-- datafeed: Burning Barrage has no cast range and no "radius"; its arrows fly "range" (850), "projectile_width" (200) wide
	local castRange = Fu.GetProperCastRange(
		false,
		bot,
		math.max(burningBarrageAbility:GetCastRange(), burningBarrageAbility:GetSpecialValueInt("range"))
	)
	local projectileWidth = burningBarrageAbility:GetSpecialValueInt("projectile_width")
	if isGoingOnSomeone then
		if
			Fu.IsValidTarget(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange - 125)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			local alliesNearTarget = Fu.GetAlliesNearLoc(botTarget:GetLocation(), 1200)
			local enemiesNearTarget = Fu.GetEnemiesNearLoc(botTarget:GetLocation(), 1200)
			if alliesNearTarget ~= nil and enemiesNearTarget ~= nil and #alliesNearTarget >= #enemiesNearTarget then
				enemiesNearTarget = Fu.GetEnemiesNearLoc(botTarget:GetLocation(), projectileWidth - 75)
				if enemiesNearTarget ~= nil and #enemiesNearTarget >= 1 then
					return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(enemiesNearTarget)
				else
					return BOT_ACTION_DESIRE_HIGH, botTarget:GetExtrapolatedLocation(0.5)
				end
			end
		end
	end
	if Fu.IsFarming(bot) then
		local nearbyNeutralCreeps = bot:GetNearbyNeutralCreeps(1000)
		if
			nearbyNeutralCreeps ~= nil
			and #nearbyNeutralCreeps >= 1
			and isAttacking
			and Fu.GetManaAfter(burningBarrageAbility:GetManaCost()) * bot:GetMana()
				> skeletonWalkAbility:GetManaCost()
		then
			if Fu.IsBigCamp(nearbyNeutralCreeps) or nearbyNeutralCreeps[1]:IsAncientCreep() then
				if #nearbyNeutralCreeps >= 2 then
					return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(nearbyNeutralCreeps)
				end
			else
				if #nearbyNeutralCreeps >= 3 then
					return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(nearbyNeutralCreeps)
				end
			end
		end
		local nearbyLaneCreeps = bot:GetNearbyLaneCreeps(1000, true)
		if nearbyLaneCreeps ~= nil and #nearbyLaneCreeps >= 4 then
			return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(nearbyLaneCreeps)
		end
	end
	if Fu.IsPushing(bot) or Fu.IsDefending(bot) then
		local nearbyLaneCreeps = bot:GetNearbyLaneCreeps(1000, true)
		if nearbyLaneCreeps ~= nil and #nearbyLaneCreeps >= 4 then
			return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(nearbyLaneCreeps)
		end
	end
	if Fu.IsDoingRoshan(bot) or Fu.IsDoingTormentor(bot) then
		if
			(Fu.IsRoshan(botTarget) or Fu.IsTormentor(botTarget))
			and Fu.IsInRange(bot, botTarget, bot:GetAttackRange())
			and isAttacking
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.ConsiderBurningArmy()
	-- checked burningBarrageAbility by mistake; Burning Army is burningArmyAbility
	if not burningArmyAbility:IsTrained() or not burningArmyAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local attackRange = bot:GetAttackRange()
	local castRange = burningArmyAbility:GetCastRange()
	local radius = 900
	if Fu.IsInTeamFight(bot, 1200) then
		local aoeLocation = bot:FindAoELocation(true, true, bot:GetLocation(), castRange + radius / 2, radius, 0, 0)
		local enemiesNearLocation = Fu.GetEnemiesNearLoc(aoeLocation.targetloc, radius)
		if enemiesNearLocation ~= nil and #enemiesNearLocation >= 2 then
			if GetUnitToLocationDistance(bot, Fu.GetCenterOfUnits(enemiesNearLocation)) > castRange then
				return BOT_ACTION_DESIRE_HIGH,
					Fu.Site.GetXUnitsTowardsLocation(bot, Fu.GetCenterOfUnits(enemiesNearLocation), castRange)
			else
				return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(enemiesNearLocation)
			end
		end
	end
	if isGoingOnSomeone then
		if
			Fu.IsValidTarget(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			local alliesNearTarget = Fu.GetAlliesNearLoc(botTarget:GetLocation(), 1200)
			local enemiesNearTarget = Fu.GetEnemiesNearLoc(botTarget:GetLocation(), 1200)
			if alliesNearTarget ~= nil and enemiesNearTarget ~= nil and #alliesNearTarget >= #enemiesNearTarget then
				enemiesNearTarget = Fu.GetEnemiesNearLoc(botTarget:GetLocation(), radius)
				if enemiesNearTarget ~= nil and #enemiesNearTarget >= 1 then
					if GetUnitToLocationDistance(bot, Fu.GetCenterOfUnits(enemiesNearTarget)) > castRange then
						return BOT_ACTION_DESIRE_HIGH,
							Fu.Site.GetXUnitsTowardsLocation(bot, Fu.GetCenterOfUnits(enemiesNearTarget), castRange)
					else
						return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(enemiesNearTarget)
					end
				else
					if GetUnitToUnitDistance(bot, botTarget) > castRange then
						return BOT_ACTION_DESIRE_HIGH,
							Fu.Site.GetXUnitsTowardsLocation(bot, botTarget:GetLocation(), castRange)
					else
						return BOT_ACTION_DESIRE_HIGH, botTarget:GetExtrapolatedLocation(0.5)
					end
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function GetMostHPCreepLevel(creeps, maxLevel)
	local bestCreep = nil
	local bestHealth = 0
	for _, creep in pairs(creeps) do
		local health = creep:GetHealth()
		local level = creep:GetLevel()
		if health > bestHealth and level <= maxLevel and not Fu.IsKeyWordUnit("flagbearer", creep) then
			bestCreep = creep
			bestHealth = health
		end
	end
	return bestCreep
end
return X
