-- Brewmaster: skill build, item build, and ability use for this hero.
local X = {}
local bot = GetBot()
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local AbilityContext = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local Minion = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local sTalentList = Fu.Skill.GetTalentList(bot)
local sAbilityList = Fu.Skill.GetAbilityList(bot)
local sRole = Fu.Item.GetRoleItemsBuyList(bot)
local tTalentTreeList = { ["t25"] = { 10, 0 }, ["t20"] = { 0, 10 }, ["t15"] = { 10, 0 }, ["t10"] = { 0, 10 } }
local tAllAbilityBuildList = { { 1, 3, 1, 3, 1, 6, 1, 3, 3, 2, 6, 2, 2, 2, 6 } }
local nAbilityBuildList = Fu.Skill.GetRandomBuild(tAllAbilityBuildList)
local nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList)
local sRoleItemsBuyList = {}
local sUtilityList = { "item_crimson_guard", "item_pipe" }
local sUtility = sUtilityList[RandomInt(1, #sUtilityList)]
sRoleItemsBuyList["pos_1"] = {
	"item_bristleback_outfit",
	"item_hand_of_midas",
	"item_radiance",
	"item_heavens_halberd",
	"item_black_king_bar",
	"item_travel_boots",
	"item_abyssal_blade",
	"item_aghanims_shard",
	"item_ultimate_scepter_2",
	"item_heart",
	"item_moon_shard",
	"item_travel_boots_2",
}
sRoleItemsBuyList["pos_2"] = {
	"item_tango",
	"item_double_branches",
	"item_quelling_blade",
	"item_magic_wand",
	"item_double_bracer",
	"item_boots",
	"item_radiance",
	"item_assault",
	"item_ultimate_scepter",
	"item_aghanims_shard",
	"item_travel_boots",
	"item_black_king_bar",
	"item_shivas_guard",
	"item_moon_shard",
	"item_travel_boots_2",
	"item_ultimate_scepter_2",
}
sRoleItemsBuyList["pos_3"] = {
	"item_tango",
	"item_double_branches",
	"item_quelling_blade",
	"item_magic_wand",
	"item_double_bracer",
	"item_boots",
	"item_radiance",
	"item_ultimate_scepter",
	"item_blink",
	sUtility,
	"item_aghanims_shard",
	"item_travel_boots",
	"item_assault",
	"item_moon_shard",
	"item_travel_boots_2",
	"item_ultimate_scepter_2",
}
sRoleItemsBuyList["pos_4"] = {
	"item_priest_outfit",
	"item_hand_of_midas",
	"item_mekansm",
	"item_glimmer_cape",
	"item_guardian_greaves",
	"item_aghanims_shard",
	"item_assault",
	"item_heavens_halberd",
	"item_shivas_guard",
	"item_refresher",
	"item_ultimate_scepter_2",
	"item_moon_shard",
}
sRoleItemsBuyList["pos_5"] = {
	"item_priest_outfit",
	"item_hand_of_midas",
	"item_mekansm",
	"item_glimmer_cape",
	"item_pipe",
	"item_aghanims_shard",
	"item_assault",
	"item_heavens_halberd",
	"item_shivas_guard",
	"item_refresher",
	"item_ultimate_scepter_2",
	"item_moon_shard",
}
X["sBuyList"] = sRoleItemsBuyList[sRole]
X["sSellList"] = {
	"item_heavens_halberd",
	"item_quelling_blade",
	"item_assault",
	"item_quelling_blade",
	"item_abyssal_blade",
	"item_magic_wand",
	"item_assault",
	"item_ancient_janggo",
}
if Fu.Role.IsPvNMode() or Fu.Role.IsAllShadow() then
	X["sBuyList"], X["sSellList"] = { "PvN_antimage" }, {}
end
nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"] = Fu.SetUserHeroInit(nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"])
X["sSkillList"] = Fu.Skill.GetSkillList(sAbilityList, nAbilityBuildList, sTalentList, nTalentBuildList)
X["bDeafaultAbility"] = false
X["bDeafaultItem"] = false
function X.MinionThink(hMinionUnit)
	Minion.MinionThink(hMinionUnit)
end
local thunderClapAbility = SafeAbility(bot:GetAbilityByName("brewmaster_thunder_clap"), "brewmaster_thunder_clap", "brewmaster")
local cinderBrewAbility = SafeAbility(bot:GetAbilityByName("brewmaster_cinder_brew"), "brewmaster_cinder_brew", "brewmaster")
local drunkenBrawlerAbility = SafeAbility(bot:GetAbilityByName("brewmaster_drunken_brawler"), "brewmaster_drunken_brawler", "brewmaster")
local primalSplitAbility = SafeAbility(bot:GetAbilityByName("brewmaster_primal_split"), "brewmaster_primal_split", "brewmaster")
local liquidCourageAbility = SafeAbility(bot:GetAbilityByName("brewmaster_liquid_courage"), "brewmaster_liquid_courage", "brewmaster")
local thunderClapDesire
local cinderBrewDesire, cinderBrewLocation
local drunkenBrawlerDesire, drunkenBrawlerStance
local primalSplitDesire
local liquidCourageDesire, liquidCourageTarget
local currentBrawlerStance = 1
local botTarget
local isGoingOnSomeone
local isRetreating
local isAttacking
local mpRatio
local isInTeamFight
function X.SkillsComplement()
	if Fu.CanNotUseAbility(bot) then
		return
	end
	local context = AbilityContext.Build(bot)
	isGoingOnSomeone = context.isEngaging
	isRetreating = context.isRetreating
	isAttacking = Fu.IsAttacking(bot)
	mpRatio = context.mp
	isInTeamFight = context.isTeamFight
	cinderBrewDesire, cinderBrewLocation = X.ConsiderCinderBrew()
	if cinderBrewDesire > 0 then
		Fu.SetQueuePtToINT(bot, false)
		bot:ActionQueue_UseAbilityOnLocation(cinderBrewAbility, cinderBrewLocation)
		return
	end
	thunderClapDesire = X.ConsiderThunderClap()
	if thunderClapDesire > 0 then
		Fu.SetQueuePtToINT(bot, false)
		bot:ActionQueue_UseAbility(thunderClapAbility)
		return
	end
	primalSplitDesire = X.ConsiderPrimalSplit()
	if primalSplitDesire > 0 then
		bot:Action_UseAbility(primalSplitAbility)
		return
	end
	drunkenBrawlerDesire, State = X.ConsiderDrunkenBrawler()
	if drunkenBrawlerDesire > 0 then
		if currentBrawlerStance ~= State then
			bot:Action_UseAbility(drunkenBrawlerAbility)
			currentBrawlerStance = currentBrawlerStance % 3 + 1
		end
	end
	liquidCourageDesire, liquidCourageTarget = X.ConsiderLiquidCourage()
	if liquidCourageDesire > 0 then
		Fu.SetQueuePtToINT(bot, false)
		-- datafeed (Shard): the drink is tossed to a teammate or self; liquidCourageTarget is a hero, so cast on the unit
		bot:ActionQueue_UseAbilityOnEntity(liquidCourageAbility, liquidCourageTarget)
		return
	end
end
function X.ConsiderThunderClap()
	if not Fu.CanCastAbility(thunderClapAbility) then
		return BOT_ACTION_DESIRE_NONE
	end
	local radius = thunderClapAbility:GetSpecialValueInt("radius")
	local damage = thunderClapAbility:GetSpecialValueInt("damage")
	botTarget = Fu.GetProperTarget(bot)
	local nearbyEnemies = bot:GetNearbyHeroes(1600, true, BOT_MODE_NONE)
	local nearbyLaneCreeps = bot:GetNearbyLaneCreeps(radius, true)
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.IsInRange(bot, enemyHero, radius - 75)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and Fu.CanKillTarget(enemyHero, damage, DAMAGE_TYPE_MAGICAL)
			and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
			and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
			and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
			and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
			and not enemyHero:HasModifier("modifier_templar_assassin_refraction_absorb")
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if isGoingOnSomeone then
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, radius - 75)
			and not Fu.IsDisabled(botTarget)
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if isRetreating and not Fu.IsRealInvisible(bot) then
		if
			Fu.IsValidHero(nearbyEnemies[1])
			and bot:WasRecentlyDamagedByAnyHero(1.5)
			and Fu.IsInRange(bot, nearbyEnemies[1], radius)
			and Fu.IsChasingTarget(nearbyEnemies[1], bot)
			and not Fu.IsDisabled(nearbyEnemies[1])
			and not nearbyEnemies[1]:HasModifier("modifier_brewmaster_cinder_brew")
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsPushing(bot) or Fu.IsDefending(bot) then
		if nearbyLaneCreeps ~= nil and #nearbyLaneCreeps >= 4 and Fu.CanBeAttacked(nearbyLaneCreeps[1]) then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsFarming(bot) then
		if isAttacking and mpRatio > 0.4 then
			local nearbyNeutrals = bot:GetNearbyNeutralCreeps(radius)
			if nearbyNeutrals ~= nil and Fu.IsValid(nearbyNeutrals[1]) and (#nearbyNeutrals >= 3 or #nearbyNeutrals >= 2 and nearbyNeutrals[1]:IsAncientCreep()) then
				return BOT_ACTION_DESIRE_HIGH
			end
			if nearbyLaneCreeps ~= nil and #nearbyLaneCreeps >= 3 and Fu.CanBeAttacked(nearbyLaneCreeps[1]) then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	if Fu.IsLaning(bot) then
		local killableCreepCount = 0
		local killableCreeps = {}
		for _, creep in pairs(nearbyLaneCreeps) do
			if
				Fu.IsValid(creep)
				and Fu.CanBeAttacked(creep)
				and (Fu.IsKeyWordUnit("ranged", creep) or Fu.IsKeyWordUnit("siege", creep) or Fu.IsKeyWordUnit("flagbearer", creep))
				and creep:GetHealth() <= damage
			then
				if Fu.IsValidHero(nearbyEnemies[1]) and GetUnitToUnitDistance(nearbyEnemies[1], creep) < 500 and mpRatio > 0.35 then
					return BOT_ACTION_DESIRE_HIGH
				end
			end
			if Fu.IsValid(creep) and creep:GetHealth() <= damage then
				killableCreepCount = killableCreepCount + 1
				table.insert(killableCreeps, creep)
			end
		end
		if killableCreepCount >= 2 and mpRatio > 0.33 and nearbyEnemies ~= nil and #nearbyEnemies >= 1 then
			return BOT_ACTION_DESIRE_HIGH
		end
		if Fu.IsInLaningPhase() then
			local enemiesInRadius = Fu.GetEnemiesNearLoc(bot:GetLocation(), radius)
			if enemiesInRadius ~= nil and #enemiesInRadius >= 1 and Fu.GetManaAfter(thunderClapAbility:GetManaCost()) > 0.5 then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if Fu.IsRoshan(botTarget) and not botTarget:IsDisarmed() and Fu.CanCastOnMagicImmune(botTarget) and Fu.IsInRange(bot, botTarget, radius) and isAttacking then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, radius) and isAttacking then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderCinderBrew()
	if not Fu.CanCastAbility(cinderBrewAbility) then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local radius = cinderBrewAbility:GetSpecialValueInt("radius")
	local castRange = Fu.GetProperCastRange(false, bot, cinderBrewAbility:GetCastRange())
	local castPoint = cinderBrewAbility:GetCastPoint()
	botTarget = Fu.GetProperTarget(bot)
	local nearbyEnemies = bot:GetNearbyHeroes(1600, true, BOT_MODE_NONE)
	local nearbyLaneCreeps = bot:GetNearbyLaneCreeps(1600, true)
	if isInTeamFight then
		local aoeLocation = bot:FindAoELocation(true, true, bot:GetLocation(), castRange, radius, castPoint, 0)
		local enemiesNearAoe = Fu.GetEnemiesNearLoc(aoeLocation.targetloc, radius)
		if enemiesNearAoe ~= nil and #enemiesNearAoe >= 2 then
			return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
		end
	end
	if isGoingOnSomeone then
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			-- fix: no range check here, so a target 2000+ away got a brew thrown at a point castRange (cast
			-- range + 200) toward it, landing on nothing. Only when the target is within castRange + radius.
			and Fu.IsInRange(bot, botTarget, castRange + radius)
			and not Fu.IsDisabled(botTarget)
			and not botTarget:HasModifier("modifier_brewmaster_cinder_brew")
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			local castLocation = botTarget:GetLocation()
			if not Fu.IsInRange(bot, botTarget, castRange) then
				castLocation = Fu.Site.GetXUnitsTowardsLocation(bot, botTarget:GetLocation(), castRange)
			else
				if Fu.IsChasingTarget(bot, botTarget) then
					castLocation = Fu.GetCorrectLoc(botTarget, castPoint)
				end
			end
			return BOT_ACTION_DESIRE_HIGH, castLocation
		end
	end
	if isRetreating and not Fu.IsRealInvisible(bot) then
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValidHero(enemyHero)
				and bot:WasRecentlyDamagedByHero(enemyHero, 2)
				and Fu.IsInRange(bot, enemyHero, radius)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.IsChasingTarget(enemyHero, bot)
				and not Fu.IsDisabled(enemyHero)
				and not enemyHero:HasModifier("modifier_brewmaster_cinder_brew")
			then
				return BOT_ACTION_DESIRE_HIGH, (bot:GetLocation() + enemyHero:GetLocation()) / 2
			end
		end
	end
	if Fu.IsPushing(bot) or Fu.IsDefending(bot) then
		if nearbyLaneCreeps ~= nil and #nearbyLaneCreeps >= 4 and Fu.CanBeAttacked(nearbyLaneCreeps[1]) and not Fu.IsRunning(nearbyLaneCreeps[1]) and isAttacking then
			return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(nearbyLaneCreeps)
		end
		local aoeLocation = bot:FindAoELocation(true, true, bot:GetLocation(), castRange, radius, 0, 0)
		if aoeLocation.count >= 1 then
			return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
		end
	end
	if Fu.IsFarming(bot) then
		if isAttacking and mpRatio > 0.45 then
			local nearbyNeutrals = bot:GetNearbyNeutralCreeps(600)
			if nearbyNeutrals ~= nil and Fu.IsValid(nearbyNeutrals[1]) and (#nearbyNeutrals >= 3 or #nearbyNeutrals >= 2 and nearbyNeutrals[1]:IsAncientCreep()) then
				return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(nearbyNeutrals)
			end
			if nearbyLaneCreeps ~= nil and #nearbyLaneCreeps >= 3 and Fu.CanBeAttacked(nearbyLaneCreeps[1]) and not Fu.IsRunning(nearbyLaneCreeps[1]) then
				return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(nearbyLaneCreeps)
			end
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if Fu.IsRoshan(botTarget) and not botTarget:IsInvulnerable() and Fu.CanCastOnNonMagicImmune(botTarget) and Fu.IsInRange(bot, botTarget, radius) and isAttacking then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, radius) and isAttacking then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.ConsiderDrunkenBrawler()
	if not Fu.CanCastAbility(drunkenBrawlerAbility) then
		return BOT_ACTION_DESIRE_NONE, -1
	end
	botTarget = Fu.GetProperTarget(bot)
	local nearbyEnemies = bot:GetNearbyHeroes(1600, true, BOT_MODE_NONE)
	if Fu.GetHP(bot) < 0.33 and Fu.IsValidHero(nearbyEnemies[1]) and bot:WasRecentlyDamagedByAnyHero(3.0) then
		return BOT_ACTION_DESIRE_HIGH, 1
	end
	if isGoingOnSomeone then
		return BOT_ACTION_DESIRE_HIGH, 3
	end
	if isRetreating and not Fu.IsRealInvisible(bot) then
		return BOT_ACTION_DESIRE_HIGH, 2
	end
	if Fu.IsLaning(bot) or Fu.IsFarming(bot) then
		return BOT_ACTION_DESIRE_HIGH, 3
	end
	if Fu.IsDoingRoshan(bot) then
		if Fu.IsRoshan(botTarget) and Fu.CanBeAttacked(botTarget) and Fu.IsInRange(bot, botTarget, 600) then
			return BOT_ACTION_DESIRE_HIGH, 3
		else
			return BOT_ACTION_DESIRE_HIGH, 2
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, 600) then
			return BOT_ACTION_DESIRE_HIGH, 3
		else
			return BOT_ACTION_DESIRE_HIGH, 2
		end
	end
	return BOT_ACTION_DESIRE_NONE, -1
end
function X.ConsiderLiquidCourage()
	if not Fu.CanCastAbility(liquidCourageAbility) then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castRange = liquidCourageAbility:GetCastRange()
	-- fix: nearbyAllies was the undefined global nAllyHeroes here (pairs(nil) errors once the Shard is owned)
	local nearbyAllies = Fu.GetNearbyHeroes(bot, 1600, false, BOT_MODE_NONE) or {}
	for _, allyHero in pairs(nearbyAllies) do
		if
			Fu.IsValidHero(allyHero)
			and Fu.IsInRange(bot, allyHero, castRange)
			and not allyHero:IsIllusion()
			and not allyHero:IsChanneling()
			and not allyHero:HasModifier("modifier_necrolyte_reapers_scythe")
			and not Fu.IsAttacking(allyHero)
			and Fu.IsRunning(allyHero)
			and allyHero:WasRecentlyDamagedByAnyHero(2.0)
		then
			if Fu.IsGoingOnSomeone(allyHero) or Fu.IsRetreating(allyHero) and Fu.GetHP(allyHero) < 0.75 then
				return BOT_ACTION_DESIRE_HIGH, allyHero
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function X.ConsiderPrimalSplit()
	if not Fu.CanCastAbility(primalSplitAbility) then
		return BOT_ACTION_DESIRE_NONE
	end
	local nearbyAllies = bot:GetNearbyHeroes(1600, false, BOT_MODE_NONE)
	local nearbyEnemies = Fu.GetEnemiesNearLoc(bot:GetLocation(), 1600)
	botTarget = Fu.GetProperTarget(bot)
	if nearbyAllies ~= nil and #nearbyAllies == 0 then
		return BOT_ACTION_DESIRE_NONE
	end
	-- fix: GetNearbyHeroes(allies) includes Brewmaster himself, so "#nearbyAllies == 0" never held
	-- and this low-HP split (save) never fired. "<= 1" = no ally but himself.
	if Fu.GetHP(bot) < 0.33 and nearbyEnemies ~= nil and #nearbyEnemies >= 2 and nearbyAllies ~= nil and #nearbyAllies <= 1 then
		if DotaTime() >= (bot._brewSplitLogAt or -999) then
			bot._brewSplitLogAt = DotaTime() + 10
			pcall(print, string.format("[OHA-BREWMASTER] t=%.0f primal split save hp=%.2f enemies=%d", DotaTime(), Fu.GetHP(bot), #nearbyEnemies))
		end
		return BOT_ACTION_DESIRE_HIGH
	end
	if isInTeamFight then
		if nearbyEnemies ~= nil and #nearbyEnemies >= 2 then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if isGoingOnSomeone then
		if
			Fu.IsValidTarget(botTarget)
			and not botTarget:IsAttackImmune()
			and Fu.IsInRange(bot, botTarget, 888)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not Fu.IsDisabled(botTarget)
			and not Fu.IsMeepoClone(botTarget)
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
			and not Fu.IsLocationInChrono(botTarget:GetLocation())
		then
			if
				nearbyAllies ~= nil
				and nearbyEnemies ~= nil
				and (#nearbyAllies >= #nearbyEnemies or Fu.WeAreStronger(bot, 1200))
				and Fu.IsCore(botTarget)
				and not (#nearbyAllies >= 2 and #nearbyEnemies <= 1)
			then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	if isRetreating and not Fu.IsRealInvisible(bot) then
		if nearbyEnemies ~= nil and nearbyAllies ~= nil and #nearbyEnemies >= 3 and #nearbyAllies <= 1 then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
return X
