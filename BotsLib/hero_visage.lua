-- Visage: skill build, item build, and ability use for this hero.
local X = {}
local bot = GetBot()
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local AbilityContext = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local Minion = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local sTalentList = Fu.Skill.GetTalentList(bot)
local sAbilityList = Fu.Skill.GetAbilityList(bot)
local sRole = Fu.Item.GetRoleItemsBuyList(bot)
local tTalentTreeList = { ["t25"] = { 10, 0 }, ["t20"] = { 10, 0 }, ["t15"] = { 10, 0 }, ["t10"] = { 0, 10 } }
local tAllAbilityBuildList = { { 2, 1, 1, 3, 1, 6, 1, 3, 3, 3, 6, 2, 2, 2, 6 } }
local nAbilityBuildList = Fu.Skill.GetRandomBuild(tAllAbilityBuildList)
local nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList)
local sRoleItemsBuyList = {}
local sUtilityList = { "item_pipe", "item_crimson_guard" }
local sUtility = sUtilityList[RandomInt(1, #sUtilityList)]
sRoleItemsBuyList["pos_2"] = {
	"item_tango",
	"item_double_branches",
	"item_double_circlet",
	"item_enchanted_mango",
	"item_bottle",
	"item_magic_wand",
	"item_double_bracer",
	"item_boots",
	"item_vladmir",
	"item_aghanims_shard",
	"item_orchid",
	"item_ancient_janggo",
	"item_ultimate_scepter",
	"item_bloodthorn",
	"item_boots_of_bearing",
	"item_assault",
	"item_black_king_bar",
	"item_sheepstick",
	"item_ultimate_scepter_2",
	"item_moon_shard",
}
sRoleItemsBuyList["pos_3"] = {
	"item_tango",
	"item_double_branches",
	"item_double_circlet",
	"item_enchanted_mango",
	"item_magic_wand",
	"item_double_bracer",
	"item_boots",
	"item_vladmir",
	"item_aghanims_shard",
	"item_orchid",
	"item_ancient_janggo",
	"item_ultimate_scepter",
	sUtility,
	"item_boots_of_bearing",
	"item_assault",
	"item_black_king_bar",
	"item_ultimate_scepter_2",
	"item_bloodthorn",
	"item_moon_shard",
}
sRoleItemsBuyList["pos_1"] = sRoleItemsBuyList["pos_3"]
sRoleItemsBuyList["pos_4"] = {
	"item_enchanted_mango",
	"item_blood_grenade",
	"item_priest_outfit",
	"item_mekansm",
	"item_glimmer_cape",
	"item_rod_of_atos",
	"item_guardian_greaves",
	"item_gungir",
	"item_shivas_guard",
	"item_aghanims_shard",
	"item_ultimate_scepter",
	"item_ultimate_scepter_2",
	"item_sheepstick",
	"item_moon_shard",
	"item_octarine_core",
}
sRoleItemsBuyList["pos_5"] = {
	"item_blood_grenade",
	"item_mage_outfit",
	"item_ancient_janggo",
	"item_glimmer_cape",
	"item_boots_of_bearing",
	"item_pipe",
	"item_rod_of_atos",
	"item_gungir",
	"item_shivas_guard",
	"item_cyclone",
	"item_sheepstick",
	"item_wind_waker",
	"item_moon_shard",
	"item_ultimate_scepter_2",
}
X["sBuyList"] = sRoleItemsBuyList[sRole]
X["sSellList"] = { "item_black_king_bar", "item_quelling_blade" }
if Fu.Role.IsPvNMode() or Fu.Role.IsAllShadow() then
	X["sBuyList"], X["sSellList"] = { "PvN_antimage" }, {}
end
nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"] =
	Fu.SetUserHeroInit(nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"])
X["sSkillList"] = Fu.Skill.GetSkillList(sAbilityList, nAbilityBuildList, sTalentList, nTalentBuildList)
X["bDeafaultAbility"] = false
X["bDeafaultItem"] = false
function X.MinionThink(minionUnit)
	Minion.MinionThink(minionUnit)
end
local graveChillAbility = SafeAbility(bot:GetAbilityByName("visage_grave_chill"), "visage_grave_chill", "visage")
local soulAssumptionAbility =
	SafeAbility(bot:GetAbilityByName("visage_soul_assumption"), "visage_soul_assumption", "visage")
local gravekeepersCloakAbility =
	SafeAbility(bot:GetAbilityByName("visage_gravekeepers_cloak"), "visage_gravekeepers_cloak", "visage")
local silentAsTheGraveAbility =
	SafeAbility(bot:GetAbilityByName("visage_silent_as_the_grave"), "visage_silent_as_the_grave", "visage")
local summonFamiliarsAbility =
	SafeAbility(bot:GetAbilityByName("visage_summon_familiars"), "visage_summon_familiars", "visage")
local graveChillDesire, graveChillTarget
local soulAssumptionDesire, soulAssumptionTarget
local gravekeepersCloakDesire
local silentAsTheGraveDesire
local summonFamiliarsDesire
local botTarget
local isEngaging
local isAttacking
function X.SkillsComplement()
	if Fu.CanNotUseAbility(bot) then
		return
	end
	local context = AbilityContext.Build(bot)
	isEngaging = context.isEngaging
	isAttacking = Fu.IsAttacking(bot)
	botTarget = context.target
	graveChillDesire, graveChillTarget = X.ConsiderGraveChill()
	if graveChillDesire > 0 then
		bot:Action_UseAbilityOnEntity(graveChillAbility, graveChillTarget)
		return
	end
	soulAssumptionDesire, soulAssumptionTarget = X.ConsiderSoulAssumption()
	if soulAssumptionDesire > 0 then
		bot:Action_UseAbilityOnEntity(soulAssumptionAbility, soulAssumptionTarget)
		return
	end
	gravekeepersCloakDesire = X.ConsiderGravekeepersCloak()
	if gravekeepersCloakDesire > 0 then
		bot:Action_UseAbility(gravekeepersCloakAbility)
		return
	end
	silentAsTheGraveDesire = X.ConsiderSilentAsTheGrave()
	if silentAsTheGraveDesire > 0 then
		bot:Action_UseAbility(silentAsTheGraveAbility)
		return
	end
	summonFamiliarsDesire = X.ConsiderSummonFamiliars()
	if summonFamiliarsDesire > 0 then
		bot:Action_UseAbility(summonFamiliarsAbility)
		return
	end
end
function X.ConsiderGraveChill()
	if not graveChillAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castRange = Fu.GetProperCastRange(false, bot, graveChillAbility:GetCastRange())
	if isEngaging then
		local bestTarget = nil
		local highestAttackSpeed = 0
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValidTarget(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.IsInRange(bot, enemyHero, castRange)
				and not Fu.IsSuspiciousIllusion(enemyHero)
			then
				local alliesNearTarget = Fu.GetNearbyHeroes(enemyHero, 1200, true, BOT_MODE_NONE)
				local enemiesNearTarget = Fu.GetNearbyHeroes(enemyHero, 1200, false, BOT_MODE_NONE)
				local attackSpeed = enemyHero:GetAttackSpeed()
				if
					alliesNearTarget ~= nil
					and enemiesNearTarget ~= nil
					and #alliesNearTarget >= #enemiesNearTarget
					and attackSpeed > highestAttackSpeed
				then
					highestAttackSpeed = attackSpeed
					bestTarget = enemyHero
				end
			end
		end
		if bestTarget ~= nil then
			return BOT_ACTION_DESIRE_HIGH, bestTarget
		end
	end
	if Fu.IsRetreating(bot) then
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.IsChasingTarget(enemyHero, bot)
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and not Fu.IsDisabled(enemyHero)
			then
				local alliesNearTarget = Fu.GetNearbyHeroes(enemyHero, 1200, true, BOT_MODE_NONE)
				local enemiesNearTarget = Fu.GetNearbyHeroes(enemyHero, 1200, false, BOT_MODE_NONE)
				if
					alliesNearTarget ~= nil
					and enemiesNearTarget ~= nil
					and (#enemiesNearTarget > #alliesNearTarget or bot:WasRecentlyDamagedByAnyHero(1.5))
				then
					return BOT_ACTION_DESIRE_HIGH, enemyHero
				end
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
function X.ConsiderSoulAssumption()
	if not soulAssumptionAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local soulStacks = 0
	for modifierIndex = 0, bot:NumModifiers() do
		if bot:GetModifierName(modifierIndex) == "modifier_visage_soul_assumption" then
			soulStacks = bot:GetModifierStackCount(modifierIndex)
			break
		end
	end
	local castRange = Fu.GetProperCastRange(false, bot, soulAssumptionAbility:GetCastRange())
	local stackLimit = soulAssumptionAbility:GetSpecialValueInt("stack_limit")
	local soulBaseDamage = soulAssumptionAbility:GetSpecialValueInt("soul_base_damage")
	local soulChargeDamage = soulAssumptionAbility:GetSpecialValueInt("soul_charge_damage")
	local damage = soulBaseDamage + soulStacks * soulChargeDamage
	local nearbyEnemies = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and Fu.CanCastOnTargetAdvanced(enemyHero)
			and Fu.CanKillTarget(enemyHero, damage, DAMAGE_TYPE_MAGICAL)
			and not Fu.IsSuspiciousIllusion(enemyHero)
			and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
			and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
			and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
			and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
			and not enemyHero:HasModifier("modifier_templar_assassin_refraction_absorb")
		then
			return BOT_ACTION_DESIRE_HIGH, enemyHero
		end
	end
	if isEngaging then
		local bestTarget = nil
		local lowestHealth = 20000
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValidTarget(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
				and Fu.IsInRange(bot, enemyHero, castRange)
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
				and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
				and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
				and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
				and not enemyHero:HasModifier("modifier_templar_assassin_refraction_absorb")
				and soulStacks == stackLimit
			then
				local alliesNearTarget = Fu.GetNearbyHeroes(enemyHero, 1200, true, BOT_MODE_NONE)
				local enemiesNearTarget = Fu.GetNearbyHeroes(enemyHero, 1200, false, BOT_MODE_NONE)
				local health = enemyHero:GetHealth()
				-- Lowest-HP target: it read "lowestHealth < health" with lowestHealth = 20000, so only a hero above 20000 HP
				-- qualified and the full-stack engage cast never fired.
				if
					alliesNearTarget ~= nil
					and enemiesNearTarget ~= nil
					and #alliesNearTarget >= #enemiesNearTarget
					and health < lowestHealth
				then
					lowestHealth = health
					bestTarget = enemyHero
				end
			end
		end
		if bestTarget ~= nil then
			return BOT_ACTION_DESIRE_HIGH, bestTarget
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if
			Fu.IsRoshan(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.CanCastOnTargetAdvanced(botTarget)
			and Fu.IsInRange(bot, botTarget, 500)
			and isAttacking
			and soulStacks == stackLimit
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if
			Fu.IsTormentor(botTarget)
			and Fu.IsInRange(bot, botTarget, 500)
			and isAttacking
			and soulStacks == stackLimit
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function X.ConsiderGravekeepersCloak()
	if gravekeepersCloakAbility:IsPassive() or not gravekeepersCloakAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
	end
	if Fu.GetHP(bot) < 0.49 then
		return BOT_ACTION_DESIRE_HIGH
	end
	return BOT_ACTION_DESIRE_NONE
end
local lastSummonCheckTime = 0
local summonCheckInterval = 20
function X.ConsiderSummonFamiliars()
	if not summonFamiliarsAbility:IsFullyCastable() or DotaTime() - lastSummonCheckTime <= summonCheckInterval then
		return BOT_ACTION_DESIRE_NONE
	end
	lastSummonCheckTime = DotaTime()
	local familiarCount = summonFamiliarsAbility:GetSpecialValueInt("familiar_count")
	local familiarsAlive = 0
	for _, allyUnit in pairs(GetUnitList(UNIT_LIST_ALLIES)) do
		if string.find(allyUnit:GetUnitName(), "npc_dota_visage_familiar") then
			familiarsAlive = familiarsAlive + 1
		end
	end
	if familiarCount > familiarsAlive then
		return BOT_ACTION_DESIRE_HIGH
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderSilentAsTheGrave()
	if not silentAsTheGraveAbility:IsTrained() or not silentAsTheGraveAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
	end
	local roshanLocation = Fu.GetCurrentRoshanLocation()
	local tormentorLocation = Fu.GetTormentorLocation(GetTeam())
	if isEngaging then
		if
			Fu.IsValidTarget(botTarget)
			and Fu.IsInRange(bot, botTarget, 1200)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not Fu.IsDisabled(botTarget)
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			local alliesNearTarget = Fu.GetNearbyHeroes(botTarget, 1200, true, BOT_MODE_NONE)
			local enemiesNearTarget = Fu.GetNearbyHeroes(botTarget, 1200, false, BOT_MODE_NONE)
			if alliesNearTarget ~= nil and enemiesNearTarget ~= nil and #alliesNearTarget >= #enemiesNearTarget then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	if Fu.IsRetreating(bot) then
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE)
		-- Silent as the Grave is a no-target self cast, so the chaser's BKB or Linken's does not
		-- matter; those checks only stopped the escape when the chaser had one.
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.IsChasingTarget(enemyHero, bot)
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and not Fu.IsDisabled(enemyHero)
			then
				local alliesNearTarget = Fu.GetNearbyHeroes(enemyHero, 1200, true, BOT_MODE_NONE)
				local enemiesNearTarget = Fu.GetNearbyHeroes(enemyHero, 1200, false, BOT_MODE_NONE)
				if
					alliesNearTarget ~= nil
					and enemiesNearTarget ~= nil
					and (#enemiesNearTarget > #alliesNearTarget or bot:WasRecentlyDamagedByAnyHero(2.5))
				then
					return BOT_ACTION_DESIRE_HIGH, enemyHero
				end
			end
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if GetUnitToLocationDistance(bot, roshanLocation) > 3200 then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if GetUnitToLocationDistance(bot, tormentorLocation) > 3200 then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
return X
