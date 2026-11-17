-- Treant: skill build, item build, and ability use for this hero.
-- Accidental globals made file-local (#13): every bot shares one Lua state, so these were shared.
local CanDoBlinkOvergrowth, HasBlink
local X = {}
local bot = GetBot()
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local AbilityContext = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local Minion = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local sTalentList = Fu.Skill.GetTalentList(bot)
local sAbilityList = Fu.Skill.GetAbilityList(bot)
local sRole = Fu.Item.GetRoleItemsBuyList(bot)
local tTalentTreeList = { ["t25"] = { 0, 10 }, ["t20"] = { 0, 10 }, ["t15"] = { 10, 0 }, ["t10"] = { 10, 0 } }
local tAllAbilityBuildList = { { 2, 1, 3, 1, 3, 6, 3, 1, 1, 3, 6, 2, 2, 2, 6 } }
local nAbilityBuildList = Fu.Skill.GetRandomBuild(tAllAbilityBuildList)
local nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList)
local sRoleItemsBuyList = {}
sRoleItemsBuyList["pos_4"] = {
	"item_double_tango",
	"item_faerie_fire",
	"item_wind_lace",
	"item_arcane_boots",
	"item_magic_wand",
	"item_guardian_greaves",
	"item_blink",
	"item_aghanims_shard",
	"item_meteor_hammer",
	"item_lotus_orb",
	"item_gungir",
	"item_wind_waker",
	"item_ultimate_scepter",
	"item_overwhelming_blink",
	"item_ultimate_scepter_2",
	"item_moon_shard",
}
sRoleItemsBuyList["pos_5"] = {
	"item_tango",
	"item_double_branches",
	"item_enchanted_mango",
	"item_blood_grenade",
	"item_wind_lace",
	"item_boots",
	"item_ring_of_basilius",
	"item_magic_wand",
	"item_arcane_boots",
	"item_pipe",
	"item_aghanims_shard",
	"item_blink",
	"item_glimmer_cape",
	"item_meteor_hammer",
	"item_ultimate_scepter",
	"item_sheepstick",
	"item_overwhelming_blink",
	"item_ultimate_scepter_2",
	"item_moon_shard",
}
sRoleItemsBuyList["pos_3"] = {
	"item_tango",
	"item_double_branches",
	"item_enchanted_mango",
	"item_wind_lace",
	"item_boots",
	"item_ring_of_basilius",
	"item_magic_wand",
	"item_arcane_boots",
	"item_aghanims_shard",
	"item_blink",
	"item_glimmer_cape",
	"item_pipe",
	"item_meteor_hammer",
	"item_ultimate_scepter",
	"item_sheepstick",
	"item_overwhelming_blink",
	"item_ultimate_scepter_2",
	"item_moon_shard",
}
sRoleItemsBuyList["pos_1"] = {
	"item_bristleback_outfit",
	"item_aghanims_shard",
	"item_blade_mail",
	"item_heavens_halberd",
	"item_lotus_orb",
	"item_black_king_bar",
	"item_travel_boots",
	"item_heart",
	"item_moon_shard",
	"item_travel_boots_2",
}
sRoleItemsBuyList["pos_2"] = sRoleItemsBuyList["pos_1"]
X["sBuyList"] = sRoleItemsBuyList[sRole]
X["sSellList"] = { "item_black_king_bar", "item_quelling_blade" }
if Fu.Role.IsPvNMode() or Fu.Role.IsAllShadow() then
	X["sBuyList"], X["sSellList"] = { "PvN_antimage" }, {}
end
nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"] =
	Fu.SetUserHeroInit(nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"])
X["sSkillList"] = Fu.Skill.GetSkillList(sAbilityList, nAbilityBuildList, sTalentList, nTalentBuildList)
X["bDeafaultAbility"] = false
-- Cast when cornered (retreating into 3+ enemies with no way out), before running further.
X["LastStandSpells"] = { { name = "treant_overgrowth", kind = "none" } }
X["bDeafaultItem"] = false
function X.MinionThink(minionUnit)
	Minion.MinionThink(minionUnit)
end
local naturesGraspAbility = SafeAbility(bot:GetAbilityByName("treant_natures_grasp"), "treant_natures_grasp", "treant")
local leechSeedAbility = SafeAbility(bot:GetAbilityByName("treant_leech_seed"), "treant_leech_seed", "treant")
local livingArmorAbility = SafeAbility(bot:GetAbilityByName("treant_living_armor"), "treant_living_armor", "treant")
local eyesInTheForestAbility =
	SafeAbility(bot:GetAbilityByName("treant_eyes_in_the_forest"), "treant_eyes_in_the_forest", "treant")
local overgrowthAbility = SafeAbility(bot:GetAbilityByName("treant_overgrowth"), "treant_overgrowth", "treant")
local naturesGraspDesire, naturesGraspLocation
local leechSeedDesire, leechSeedTarget
local livingArmorDesire, livingArmorTarget
local eyesInTheForestDesire, eyesInTheForestTree
local overgrowthDesire
local blinkItem
local blinkOvergrowthDesire, blinkOvergrowthLocation
local botTarget
local isEngaging
local isAttacking
local hpRatio
local isInTeamFight
function X.SkillsComplement()
	if Fu.CanNotUseAbility(bot) then
		return
	end
	local abilityContext = AbilityContext.Build(bot)
	isEngaging = abilityContext.isEngaging
	isAttacking = Fu.IsAttacking(bot)
	hpRatio = abilityContext.hp
	isInTeamFight = abilityContext.isTeamFight
	blinkOvergrowthDesire, blinkOvergrowthLocation = X.ConsiderBlinkOvergrowth()
	if blinkOvergrowthDesire > 0 then
		bot:Action_ClearActions(false)
		bot:ActionQueue_UseAbilityOnLocation(blinkItem, blinkOvergrowthLocation)
		bot:ActionQueue_Delay(0.1)
		bot:ActionQueue_UseAbility(overgrowthAbility)
		return
	end
	overgrowthDesire = X.ConsiderOvergrowth()
	if overgrowthDesire > 0 then
		bot:Action_UseAbility(overgrowthAbility)
		return
	end
	naturesGraspDesire, naturesGraspLocation = X.ConsiderNaturesGrasp()
	if naturesGraspDesire > 0 then
		bot:Action_UseAbilityOnLocation(naturesGraspAbility, naturesGraspLocation)
		return
	end
	leechSeedDesire, leechSeedTarget = X.ConsiderLeechSeed()
	-- datafeed: Leech Seed is now unit-target only (behavior 135176 = unit target + autocast +
	-- attack, range 150); the old point-cast path could never be used, so it always casts on a unit.
	if leechSeedDesire > 0 and Fu.IsValid(leechSeedTarget) then
		bot:Action_UseAbilityOnEntity(leechSeedAbility, leechSeedTarget)
		return
	end
	eyesInTheForestDesire, eyesInTheForestTree = X.ConsiderEyesInTheForest()
	if eyesInTheForestDesire > 0 then
		bot:Action_UseAbilityOnTree(eyesInTheForestAbility, eyesInTheForestTree)
		return
	end
	livingArmorDesire, livingArmorTarget = X.ConsiderLivingArmor()
	if livingArmorDesire > 0 then
		bot:Action_UseAbilityOnEntity(livingArmorAbility, livingArmorTarget)
		return
	end
end
function X.ConsiderNaturesGrasp()
	if not naturesGraspAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local castRange = Fu.GetProperCastRange(false, bot, naturesGraspAbility:GetCastRange())
	local latchRange = naturesGraspAbility:GetSpecialValueInt("latch_range")
	botTarget = Fu.GetProperTarget(bot)
	if isInTeamFight then
		local aoeLocation = bot:FindAoELocation(true, true, bot:GetLocation(), castRange, latchRange, 0, 0)
		local enemiesInAoe = Fu.GetEnemiesNearLoc(aoeLocation.targetloc, latchRange)
		if enemiesInAoe ~= nil and #enemiesInAoe >= 2 then
			return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
		end
	end
	if isEngaging then
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not Fu.IsDisabled(botTarget)
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
			and not Fu.IsLocationInChrono(botTarget:GetLocation())
		then
			local alliesNearTarget = Fu.GetNearbyHeroes(botTarget, 1200, true, BOT_MODE_NONE)
			local enemiesNearTarget = Fu.GetNearbyHeroes(botTarget, 1200, false, BOT_MODE_NONE)
			if alliesNearTarget ~= nil and enemiesNearTarget ~= nil and #alliesNearTarget >= #enemiesNearTarget then
				return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
			end
		end
	end
	if Fu.IsRetreating(bot) then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, 1200, false, BOT_MODE_NONE)
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE)
		if
			nearbyAllies ~= nil
			and nearbyEnemies
			and Fu.IsValidHero(nearbyEnemies[1])
			and Fu.CanCastOnNonMagicImmune(nearbyEnemies[1])
			and Fu.IsChasingTarget(nearbyEnemies[1], bot)
			and not Fu.IsSuspiciousIllusion(nearbyEnemies[1])
			and not Fu.IsDisabled(nearbyEnemies[1])
			and not nearbyEnemies[1]:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			local enemiesNearChaser = Fu.GetNearbyHeroes(nearbyEnemies[1], 1000, false, BOT_MODE_NONE)
			if
				enemiesNearChaser ~= nil
				and (#enemiesNearChaser > #nearbyAllies or hpRatio < 0.75 and bot:WasRecentlyDamagedByAnyHero(1))
			then
				return BOT_ACTION_DESIRE_HIGH, nearbyEnemies[1]:GetLocation()
			end
		end
	end
	if Fu.IsDefending(bot) then
		local aoeLocation = bot:FindAoELocation(true, false, bot:GetLocation(), castRange, latchRange, 0, 0)
		local laneCreeps = bot:GetNearbyLaneCreeps(castRange, true)
		if laneCreeps ~= nil and #laneCreeps >= 3 and aoeLocation.count >= 3 and Fu.CanBeAttacked(laneCreeps[1]) then
			return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(laneCreeps)
		end
		aoeLocation = bot:FindAoELocation(true, true, bot:GetLocation(), castRange, latchRange, 0, 0)
		if aoeLocation.count >= 1 then
			return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
		end
	end
	if Fu.IsLaning(bot) then
		local strongestUnit = Fu.GetStrongestUnit(castRange, bot, true, false, 5)
		if
			Fu.IsValidTarget(strongestUnit)
			and Fu.CanCastOnNonMagicImmune(strongestUnit)
			and not Fu.IsSuspiciousIllusion(strongestUnit)
			and not strongestUnit:HasModifier("modifier_abaddon_borrowed_time")
			and not strongestUnit:HasModifier("modifier_dazzle_shallow_grave")
			and not strongestUnit:HasModifier("modifier_necrolyte_reapers_scythe")
			and Fu.GetMP(bot) > 0.75
		then
			return BOT_ACTION_DESIRE_HIGH, strongestUnit:GetLocation()
		end
		if not Fu.IsInLaningPhase() then
			local aoeLocation = bot:FindAoELocation(true, false, bot:GetLocation(), castRange, latchRange, 0, 0)
			local laneCreeps = bot:GetNearbyLaneCreeps(castRange, true)
			if
				laneCreeps ~= nil
				and #laneCreeps >= 3
				and aoeLocation.count >= 3
				and Fu.CanBeAttacked(laneCreeps[1])
			then
				return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(laneCreeps)
			end
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if
			Fu.IsRoshan(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, 500)
			and isAttacking
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, 500) and isAttacking then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.ConsiderLeechSeed()
	if not leechSeedAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castRange = Fu.GetProperCastRange(false, bot, leechSeedAbility:GetCastRange())
	botTarget = Fu.GetProperTarget(bot)
	local radius = leechSeedAbility:GetSpecialValueInt("radius")
	if isEngaging then
		if
			Fu.IsValidHero(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and not Fu.IsChasingTarget(bot, botTarget)
		then
			local aoeLocation = bot:FindAoELocation(true, true, botTarget:GetLocation(), 0, radius, 0, 0)
			-- datafeed: unit-target now, so seed the hero itself (it was a point cast on the group).
			if aoeLocation.count >= 2 and Fu.IsInRange(bot, botTarget, castRange) then
				return BOT_ACTION_DESIRE_HIGH, botTarget
			end
		end
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE)
		local bestTarget = nil
		local highestDamage = 0
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.IsInRange(bot, enemyHero, castRange)
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and not Fu.IsDisabled(enemyHero)
				and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
				and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
				and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
				and not enemyHero:HasModifier("modifier_treant_natures_grasp_damage")
			then
				local alliesNearEnemy = Fu.GetNearbyHeroes(enemyHero, 1200, true, BOT_MODE_NONE)
				local enemiesNearEnemy = Fu.GetNearbyHeroes(enemyHero, 1200, false, BOT_MODE_NONE)
				local estimatedDamage = enemyHero:GetEstimatedDamageToTarget(false, bot, 5, DAMAGE_TYPE_ALL)
				if
					alliesNearEnemy ~= nil
					and enemiesNearEnemy ~= nil
					and #alliesNearEnemy >= #enemiesNearEnemy
					and estimatedDamage > highestDamage
				then
					highestDamage = estimatedDamage
					bestTarget = enemyHero
				end
			end
		end
		if bestTarget ~= nil then
			return BOT_ACTION_DESIRE_MODERATE, bestTarget
		end
	end
	if Fu.IsRetreating(bot) then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, 1200, false, BOT_MODE_NONE)
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE)
		if
			nearbyAllies ~= nil
			and nearbyEnemies
			and Fu.IsValidHero(nearbyEnemies[1])
			and Fu.CanCastOnNonMagicImmune(nearbyEnemies[1])
			and Fu.IsInRange(bot, nearbyEnemies[1], castRange)
			and Fu.IsChasingTarget(nearbyEnemies[1], bot)
			and not Fu.IsSuspiciousIllusion(nearbyEnemies[1])
			and not Fu.IsDisabled(nearbyEnemies[1])
			and not nearbyEnemies[1]:HasModifier("modifier_treant_natures_grasp_damage")
		then
			if #nearbyEnemies > #nearbyAllies or hpRatio < 0.75 and bot:WasRecentlyDamagedByAnyHero(1.5) then
				return BOT_ACTION_DESIRE_HIGH, nearbyEnemies[1]
			end
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if
			Fu.IsRoshan(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, 500)
			and isAttacking
		then
			-- datafeed: unit-target now; seed Roshan instead of a point at Treant's feet.
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, 500) and isAttacking then
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function X.ConsiderLivingArmor()
	if not livingArmorAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local strongestAlly = nil
	local highestPower = 0
	-- In a fight an ally being focused comes first: the pick below takes the ally with the most
	-- offensive power, at any HP, so a dying support never got the block. Under 50% HP and hit by a
	-- hero in the last 2s, lowest HP first. Logged: [OHA-TREANT] armor-save.
	if isEngaging or Fu.IsInTeamFight(bot, 1600) then
		local save, saveHP = nil, 0.5
		for _, allyHero in pairs(Fu.GetNearbyHeroes(bot, 1600, false, BOT_MODE_NONE) or {}) do
			if
				Fu.IsValidHero(allyHero)
				and not Fu.IsMeepoClone(allyHero)
				and not allyHero:IsIllusion()
				and not allyHero:HasModifier("modifier_arc_warden_tempest_double")
				and not allyHero:HasModifier("modifier_treant_living_armor")
				and Fu.GetHP(allyHero) < saveHP
				and allyHero:WasRecentlyDamagedByAnyHero(2)
			then
				save, saveHP = allyHero, Fu.GetHP(allyHero)
			end
		end
		if save ~= nil then
			if DotaTime() >= (bot._treantArmorLogAt or -999) then
				bot._treantArmorLogAt = DotaTime() + 5
				pcall(
					print,
					string.format(
						"[OHA-TREANT] t=%.0f armor-save ally=%s hp=%.2f",
						DotaTime(),
						(string.gsub(save:GetUnitName(), "npc_dota_hero_", "")),
						saveHP
					)
				)
			end
			return BOT_ACTION_DESIRE_HIGH, save
		end
	end
	if isEngaging or Fu.IsInTeamFight(bot, 1600) then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, 1600, false, BOT_MODE_NONE)
		for _, allyHero in pairs(nearbyAllies) do
			if
				Fu.IsValidHero(allyHero)
				and not Fu.IsMeepoClone(allyHero)
				and not allyHero:IsIllusion()
				and not allyHero:HasModifier("modifier_arc_warden_tempest_double")
				and not allyHero:HasModifier("modifier_treant_living_armor")
				and not allyHero:HasModifier("modifier_fountain_aura")
			then
				if highestPower < allyHero:GetOffensivePower() then
					highestPower = allyHero:GetOffensivePower()
					strongestAlly = allyHero
				end
			end
		end
	end
	if strongestAlly ~= nil then
		return BOT_ACTION_DESIRE_HIGH, strongestAlly
	end
	local weakestAlly = nil
	local lowestHpRatio = 0.7
	for _, allyHero in pairs(GetUnitList(UNIT_LIST_ALLIED_HEROES)) do
		if
			Fu.IsValidHero(allyHero)
			and not Fu.IsMeepoClone(allyHero)
			and not allyHero:IsIllusion()
			and not allyHero:HasModifier("modifier_arc_warden_tempest_double")
			and not allyHero:HasModifier("modifier_treant_living_armor")
			and not allyHero:HasModifier("modifier_fountain_aura")
		then
			if Fu.GetHP(allyHero) < lowestHpRatio and Fu.GetHP(allyHero) < 0.7 then
				lowestHpRatio = Fu.GetHP(allyHero)
				weakestAlly = allyHero
			end
		end
	end
	if weakestAlly ~= nil then
		return BOT_ACTION_DESIRE_HIGH, weakestAlly
	end
	local weakestBuilding = nil
	local lowestBuildingHpRatio = 0.8
	for _, building in pairs(GetUnitList(UNIT_LIST_ALLIED_BUILDINGS)) do
		if Fu.IsValidBuilding(building) and not building:HasModifier("modifier_treant_living_armor") then
			if
				building:GetHealth() / building:GetMaxHealth() < lowestBuildingHpRatio
				and building:GetHealth() / building:GetMaxHealth() < 0.8
			then
				lowestBuildingHpRatio = building:GetHealth() / building:GetMaxHealth()
				weakestBuilding = building
			end
		end
	end
	if weakestBuilding ~= nil then
		return BOT_ACTION_DESIRE_HIGH, weakestBuilding
	end
	if
		hpRatio < 0.75
		and not bot:HasModifier("modifier_treant_living_armor")
		and not bot:HasModifier("modifier_fountain_aura")
	then
		return BOT_ACTION_DESIRE_HIGH, bot
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function X.ConsiderOvergrowth()
	if not overgrowthAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
	end
	local radius = overgrowthAbility:GetSpecialValueInt("radius")
	-- isInTeamFight (2+ allies in attack mode) used to be required, so Overgrowth stayed unused when Treant
	-- was going in on someone with fewer allies in attack mode, or caught by 3 enemies while
	-- defending. Now: 2+ enemies in radius (datafeed 800) in a fight or while engaging, or 3+ anytime.
	-- Logged: [OHA-TREANT] overgrowth.
	local nearbyEnemies = Fu.GetEnemiesNearLoc(bot:GetLocation(), radius)
	if
		nearbyEnemies ~= nil
		and (#nearbyEnemies >= 3 or #nearbyEnemies >= 2 and (isInTeamFight or isEngaging))
		and not Fu.IsLocationInChrono(bot:GetLocation())
		and not Fu.IsLocationInBlackHole(bot:GetLocation())
	then
		if not isInTeamFight and DotaTime() >= (bot._treantOvergrowthLogAt or -999) then
			bot._treantOvergrowthLogAt = DotaTime() + 10
			pcall(
				print,
				string.format(
					"[OHA-TREANT] t=%.0f overgrowth enemies=%d engaging=%s (not a team fight)",
					DotaTime(),
					#nearbyEnemies,
					tostring(isEngaging)
				)
			)
		end
		return BOT_ACTION_DESIRE_HIGH
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderEyesInTheForest()
	if not eyesInTheForestAbility:IsTrained() or not eyesInTheForestAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castRange = Fu.GetProperCastRange(false, bot, eyesInTheForestAbility:GetCastRange())
	local visionRadius = eyesInTheForestAbility:GetSpecialValueInt("vision_aoe")
	botTarget = Fu.GetProperTarget(bot)
	if isEngaging then
		if
			Fu.IsValidTarget(botTarget)
			and Fu.IsInRange(bot, botTarget, visionRadius)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not botTarget:HasModifier("modifier_treant_eyes_in_the_forest")
		then
			local alliesNearTarget = Fu.GetNearbyHeroes(botTarget, 1200, true, BOT_MODE_NONE)
			local enemiesNearTarget = Fu.GetNearbyHeroes(botTarget, 1200, false, BOT_MODE_NONE)
			local nearbyTrees = bot:GetNearbyTrees(castRange)
			if
				alliesNearTarget ~= nil
				and enemiesNearTarget ~= nil
				and #alliesNearTarget >= #enemiesNearTarget
				and #alliesNearTarget >= 1
				and nearbyTrees ~= nil
				and #nearbyTrees >= 1
			then
				return BOT_ACTION_DESIRE_HIGH, nearbyTrees[1]
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function X.ConsiderBlinkOvergrowth()
	if CanDoBlinkOvergrowth() then
		local radius = overgrowthAbility:GetSpecialValueInt("radius")
		if isInTeamFight then
			local aoeLocation = bot:FindAoELocation(true, true, bot:GetLocation(), 1199, radius, 0, 0)
			local enemiesInAoe = Fu.GetEnemiesNearLoc(aoeLocation.targetloc, radius)
			if
				enemiesInAoe ~= nil
				and #enemiesInAoe >= 2
				and not Fu.IsLocationInChrono(aoeLocation.targetloc)
				and not Fu.IsLocationInBlackHole(aoeLocation.targetloc)
				and GetUnitToLocationDistance(bot, aoeLocation.targetloc) > 600
			then
				return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function CanDoBlinkOvergrowth()
	-- datafeed item_blink: blink_damage_cooldown 3, so Blink cannot be used within 3s of hero damage;
	-- the queued Overgrowth would then go off where Treant stood (not verified in a game).
	if overgrowthAbility:IsFullyCastable() and HasBlink() and not bot:WasRecentlyDamagedByAnyHero(3.0) then
		local manaCost = overgrowthAbility:GetManaCost()
		if bot:GetMana() >= manaCost then
			bot.shouldBlink = true
			return true
		end
	end
	bot.shouldBlink = false
	return false
end
function HasBlink()
	local foundBlink = nil
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
			foundBlink = item
			break
		end
	end
	if foundBlink ~= nil and foundBlink:IsFullyCastable() then
		blinkItem = foundBlink
		return true
	end
	return false
end
return X
