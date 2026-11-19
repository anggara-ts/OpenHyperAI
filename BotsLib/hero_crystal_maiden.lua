-- Crystal Maiden: skill build, item build, and ability use for this hero.
local X = {}
local bot = GetBot()
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local AbilityContext = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local Minion = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local sTalentList = Fu.Skill.GetTalentList(bot)
local sAbilityList = Fu.Skill.GetAbilityList(bot)
local sRole = Fu.Item.GetRoleItemsBuyList(bot)
local tTalentTreeList = { ["t25"] = { 0, 10 }, ["t20"] = { 10, 0 }, ["t15"] = { 0, 10 }, ["t10"] = { 0, 10 } }
local tAllAbilityBuildList = { { 2, 3, 2, 1, 2, 6, 2, 3, 3, 3, 6, 1, 1, 1, 6 } }
local nAbilityBuildList = Fu.Skill.GetRandomBuild(tAllAbilityBuildList)
local nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList)
local sRoleItemsBuyList = {}
sRoleItemsBuyList["pos_4"] = {
	"item_tango",
	"item_blood_grenade",
	"item_magic_stick",
	"item_branches",
	"item_enchanted_mango",
	"item_magic_wand",
	"item_tranquil_boots",
	"item_urn_of_shadows",
	"item_mekansm",
	"item_glimmer_cape",
	"item_blink",
	"item_boots_of_bearing",
	"item_spirit_vessel",
	"item_aghanims_shard",
	"item_sheepstick",
	"item_moon_shard",
	"item_ultimate_scepter_2",
}
sRoleItemsBuyList["pos_5"] = {
	"item_blood_grenade",
	"item_mage_outfit",
	"item_glimmer_cape",
	"item_blink",
	"item_pipe",
	"item_aghanims_shard",
	"item_ultimate_scepter",
	"item_black_king_bar",
	"item_force_staff",
	"item_sheepstick",
	"item_wind_waker",
	"item_moon_shard",
	"item_ultimate_scepter_2",
}
sRoleItemsBuyList["pos_3"] = {
	"item_mage_outfit",
	"item_shadow_amulet",
	"item_veil_of_discord",
	"item_cyclone",
	"item_shivas_guard",
	"item_glimmer_cape",
	"item_sheepstick",
	"item_orchid",
	"item_bloodthorn",
	"item_aghanims_shard",
	"item_wind_waker",
	"item_moon_shard",
	"item_ultimate_scepter_2",
}
sRoleItemsBuyList["pos_1"] = sRoleItemsBuyList["pos_3"]
sRoleItemsBuyList["pos_2"] = sRoleItemsBuyList["pos_3"]
X["sBuyList"] = sRoleItemsBuyList[sRole]
X["sSellList"] = { "item_ultimate_scepter", "item_magic_wand", "item_shivas_guard", "item_magic_wand" }
if Fu.Role.IsPvNMode() or Fu.Role.IsAllShadow() then
	X["sBuyList"], X["sSellList"] = { "PvN_mage" }, {}
end
nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"] =
	Fu.SetUserHeroInit(nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"])
X["sSkillList"] = Fu.Skill.GetSkillList(sAbilityList, nAbilityBuildList, sTalentList, nTalentBuildList)
X["bDeafaultAbility"] = true
X["bDeafaultItem"] = true
function X.MinionThink(minion)
	Minion.MinionThink(minion)
end
local lastShadowAmuletTime = 0
local aetherRange = 0
local crystalNovaAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[1]), "sAbilityList[1]", "crystal_maiden")
local frostbiteAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[2]), "sAbilityList[2]", "crystal_maiden")
local freezingFieldAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[6]), "sAbilityList[6]", "crystal_maiden")
-- datafeed: Crystal Clone is granted by the Shard; fetch it by name, since entry 4 of the ability list is
-- not guaranteed to be it (the hero also has the innate Glacial Guard).
local crystalCloneAbility =
	SafeAbility(bot:GetAbilityByName("crystal_maiden_crystal_clone"), "crystal_maiden_crystal_clone", "crystal_maiden")
local talent2 = SafeAbility(bot:GetAbilityByName(sTalentList[2]), "sTalentList[2]", "crystal_maiden")
local brillianceAuraAbility = SafeAbility(
	bot:GetAbilityByName("crystal_maiden_brilliance_aura"),
	"crystal_maiden_brilliance_aura",
	"crystal_maiden"
)
local crystalNovaDesire, crystalNovaLocation = 0
local frostbiteDesire, frostbiteTarget = 0
local freezingFieldDesire = 0
local crystalCloneDesire, crystalCloneLocation
local brillianceAuraDesire
local botTarget
local retainMana, mpRatio, hpRatio, botLevel
function X.SkillsComplement()
	X.ConsiderCombo()
	if Fu.CanNotUseAbility(bot) or bot:IsInvisible() then
		return
	end
	local context = AbilityContext.Build(bot)
	retainMana = 220
	aetherRange = context.aetherRange
	botLevel = context.level
	mpRatio = context.mp
	hpRatio = context.hp
	botTarget = context.target
	brillianceAuraDesire = X.ConsiderArcaneAura()
	if brillianceAuraDesire > 0 then
		Fu.SetQueuePtToINT(bot, false)
		bot:ActionQueue_UseAbility(brillianceAuraAbility)
		return
	end
	crystalCloneDesire, crystalCloneLocation = X.ConsiderCrystalClone()
	if crystalCloneDesire > 0 then
		Fu.SetQueuePtToINT(bot, false)
		bot:ActionQueue_UseAbilityOnLocation(crystalCloneAbility, crystalCloneLocation)
		return
	end
	crystalNovaDesire, crystalNovaLocation = X.ConsiderQ()
	if crystalNovaDesire > 0 then
		Fu.SetQueuePtToINT(bot, false)
		bot:ActionQueue_UseAbilityOnLocation(crystalNovaAbility, crystalNovaLocation)
		return
	end
	frostbiteDesire, frostbiteTarget = X.ConsiderW()
	if frostbiteDesire > 0 then
		Fu.SetQueuePtToINT(bot, false)
		bot:ActionQueue_UseAbilityOnEntity(frostbiteAbility, frostbiteTarget)
		return
	end
	freezingFieldDesire = X.ConsiderR()
	if freezingFieldDesire > 0 then
		Fu.SetQueuePtToINT(bot, false)
		bot:ActionQueue_UseAbility(freezingFieldAbility)
		return
	end
end
function X.ConsiderArcaneAura()
	if Fu.IsGoingOnSomeone(bot) and Fu.CanCastAbility(brillianceAuraAbility) then
		local target = Fu.GetProperTarget(bot)
		if
			Fu.IsValidHero(target)
			and Fu.CanCastOnNonMagicImmune(target)
			and Fu.CanCastOnTargetAdvanced(target)
			and Fu.IsInRange(target, bot, 500)
		then
			return BOT_ACTION_DESIRE_HIGH, target
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.ConsiderCombo()
	if bot:IsAlive() and bot:IsChanneling() and not bot:IsInvisible() then
		local enemyTowers = bot:GetNearbyTowers(880, true)
		if enemyTowers[1] ~= nil then
			return
		end
		local shadowAmulet = Fu.IsItemAvailable("item_shadow_amulet")
		if shadowAmulet ~= nil and shadowAmulet:IsFullyCastable() and lastShadowAmuletTime < DotaTime() - 10 then
			lastShadowAmuletTime = DotaTime()
			bot:Action_UseAbilityOnEntity(shadowAmulet, bot)
			return
		end
		if not bot:HasModifier("modifier_teleporting") then
			local glimmerCape = Fu.IsItemAvailable("item_glimmer_cape")
			if glimmerCape ~= nil and glimmerCape:IsFullyCastable() then
				bot:Action_UseAbilityOnEntity(glimmerCape, bot)
				return
			end
			local shadowBlade = Fu.IsItemAvailable("item_invis_sword")
			if shadowBlade ~= nil and shadowBlade:IsFullyCastable() then
				bot:Action_UseAbility(shadowBlade)
				return
			end
			local silverEdge = Fu.IsItemAvailable("item_silver_edge")
			if silverEdge ~= nil and silverEdge:IsFullyCastable() then
				bot:Action_UseAbility(silverEdge)
				return
			end
		end
	end
end
function X.ConsiderQ()
	if not crystalNovaAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local radius = crystalNovaAbility:GetSpecialValueInt("radius")
	local castRange = crystalNovaAbility:GetCastRange() + aetherRange + 32
	local castPoint = crystalNovaAbility:GetCastPoint()
	local manaCost = crystalNovaAbility:GetManaCost()
	local damage = crystalNovaAbility:GetSpecialValueInt("nova_damage")
	local abilityLevel = crystalNovaAbility:GetLevel()
	local nearbyAllyHeroes = Fu.GetNearbyHeroes(bot, 1200, false, BOT_MODE_NONE)
	local enemiesInRange = Fu.GetNearbyHeroes(bot, castRange + radius, true, BOT_MODE_NONE)
	local enemiesInExtendedRange = Fu.GetNearbyHeroes(bot, castRange + radius + 150, true, BOT_MODE_NONE)
	local enemiesNearby = Fu.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE)
	local weakestEnemy, weakestEnemyHealth = X.cm_GetWeakestUnit(enemiesInRange)
	local weakestExtendedEnemy, weakestExtendedEnemyHealth = X.cm_GetWeakestUnit(enemiesInExtendedRange)
	local laneCreeps = bot:GetNearbyLaneCreeps(castRange + radius, true)
	local extendedLaneCreeps = bot:GetNearbyLaneCreeps(castRange + radius + 200, true)
	local weakestCreep, weakestCreepHealth = X.cm_GetWeakestUnit(laneCreeps)
	local weakestExtendedCreep, weakestExtendedCreepHealth = X.cm_GetWeakestUnit(extendedLaneCreeps)
	local enemyTowers = bot:GetNearbyTowers(1000, true)
	local killHeroAoe = bot:FindAoELocation(true, true, bot:GetLocation(), castRange, radius, 0.8, damage)
	local heroAoe = bot:FindAoELocation(true, true, bot:GetLocation(), castRange, radius, 0.8, 0)
	local killCreepAoe = bot:FindAoELocation(true, false, bot:GetLocation(), castRange + radius, radius, 0.5, damage)
	local creepAoe = bot:FindAoELocation(true, false, bot:GetLocation(), castRange + radius, radius, 0.5, 0)
	if
		creepAoe == nil
		or creepAoe.targetloc == nil
		or Fu.GetInLocLaneCreepCount(bot, 1600, radius, creepAoe.targetloc) <= 2
	then
		creepAoe.count = 0
	end
	if killHeroAoe.count ~= nil and killHeroAoe.count >= 1 then
		if Fu.IsValid(weakestExtendedEnemy) then
			local castLocation = Fu.GetCastLocation(bot, weakestExtendedEnemy, castRange, radius)
			if castLocation ~= nil then
				return BOT_ACTION_DESIRE_HIGH, castLocation
			end
		end
	end
	if bot:GetActiveMode() == BOT_MODE_LANING and #enemyTowers <= 0 and hpRatio >= 0.4 then
		if heroAoe.count >= 2 and GetUnitToLocationDistance(bot, heroAoe.targetloc) <= castRange + 50 then
			return BOT_ACTION_DESIRE_HIGH, heroAoe.targetloc
		end
	end
	if bot:GetActiveMode() == BOT_MODE_RETREAT and bot:WasRecentlyDamagedByAnyHero(2.0) then
		local retreatAoe = bot:FindAoELocation(true, true, bot:GetLocation(), castRange - 300, radius, 0.8, 0)
		if retreatAoe.count >= 1 then
			return BOT_ACTION_DESIRE_HIGH, retreatAoe.targetloc
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValid(weakestExtendedEnemy)
			and heroAoe.count >= 2
			and GetUnitToLocationDistance(bot, heroAoe.targetloc) <= castRange
		then
			return BOT_ACTION_DESIRE_HIGH, heroAoe.targetloc
		end
		local target = Fu.GetProperTarget(bot)
		if Fu.IsValidHero(target) and Fu.CanCastOnNonMagicImmune(target) then
			if mpRatio > 0.75 or bot:GetMana() > retainMana * 2 then
				local castLocation = Fu.GetCastLocation(bot, target, castRange, radius)
				if castLocation ~= nil then
					return BOT_ACTION_DESIRE_HIGH, castLocation
				end
			end
			if
				target:GetHealth() / target:GetMaxHealth() < 0.4
				and GetUnitToUnitDistance(target, bot) <= radius + castRange
			then
				local castLocation = Fu.GetCastLocation(bot, target, castRange, radius)
				if castLocation ~= nil then
					return BOT_ACTION_DESIRE_HIGH, castLocation
				end
			end
		end
		target = weakestEnemy
		if
			target ~= nil
			and target:IsAlive()
			and target:GetHealth() / target:GetMaxHealth() < 0.4
			and GetUnitToUnitDistance(target, bot) <= radius + castRange
		then
			local castLocation = Fu.GetCastLocation(bot, target, castRange, radius)
			if castLocation ~= nil then
				return BOT_ACTION_DESIRE_HIGH, castLocation
			end
		end
		if
			Fu.IsValid(weakestExtendedCreep)
			and creepAoe.count >= 5
			and #enemiesInExtendedRange <= 0
			and bot:GetActiveMode() ~= BOT_MODE_ATTACK
			and abilityLevel >= 3
		then
			return BOT_ACTION_DESIRE_HIGH, creepAoe.targetloc
		end
		if
			killCreepAoe.count >= 3
			and (Fu.IsValid(weakestCreep) or botLevel >= 25)
			and #enemiesInExtendedRange <= 0
			and bot:GetActiveMode() ~= BOT_MODE_ATTACK
			and abilityLevel >= 3
		then
			return BOT_ACTION_DESIRE_HIGH, killCreepAoe.targetloc
		end
	end
	if bot:GetActiveMode() ~= BOT_MODE_RETREAT then
		if Fu.IsValid(weakestExtendedEnemy) then
			if heroAoe.count >= 3 and GetUnitToLocationDistance(bot, heroAoe.targetloc) <= castRange then
				return BOT_ACTION_DESIRE_VERYHIGH, heroAoe.targetloc
			end
			if
				heroAoe.count >= 2
				and GetUnitToLocationDistance(bot, heroAoe.targetloc) <= castRange
				and bot:GetMana() > retainMana
			then
				return BOT_ACTION_DESIRE_HIGH, heroAoe.targetloc
			end
			if Fu.IsValid(weakestExtendedEnemy) then
				if mpRatio > 0.8 or bot:GetMana() > retainMana * 2 then
					local castLocation = Fu.GetCastLocation(bot, weakestExtendedEnemy, castRange, radius)
					if castLocation ~= nil then
						return BOT_ACTION_DESIRE_HIGH, castLocation
					end
				end
				if
					weakestExtendedEnemy:GetHealth() / weakestExtendedEnemy:GetMaxHealth() < 0.4
					and GetUnitToUnitDistance(weakestExtendedEnemy, bot) <= radius + castRange
				then
					local castLocation = Fu.GetCastLocation(bot, weakestExtendedEnemy, castRange, radius)
					if castLocation ~= nil then
						return BOT_ACTION_DESIRE_HIGH, castLocation
					end
				end
			end
		end
	end
	if Fu.IsFarming(bot) and abilityLevel >= 3 then
		if killCreepAoe.count >= 2 and Fu.IsValid(weakestCreep) then
			return BOT_ACTION_DESIRE_HIGH, killCreepAoe.targetloc
		end
		if creepAoe.count >= 4 and Fu.IsValid(weakestCreep) then
			return BOT_ACTION_DESIRE_HIGH, creepAoe.targetloc
		end
	end
	if #nearbyAllyHeroes <= 2 and abilityLevel >= 3 and (Fu.IsPushing(bot) or Fu.IsDefending(bot)) then
		if creepAoe.count >= 4 and Fu.IsValid(weakestCreep) then
			return BOT_ACTION_DESIRE_HIGH, creepAoe.targetloc
		end
		if killCreepAoe.count >= 2 and Fu.IsValid(weakestCreep) then
			return BOT_ACTION_DESIRE_HIGH, killCreepAoe.targetloc
		end
	end
	if bot:GetActiveMode() == BOT_MODE_ROSHAN and bot:GetMana() >= 400 then
		if Fu.IsRoshan(botTarget) then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	local neutralCreeps = bot:GetNearbyNeutralCreeps(castRange + radius)
	if Fu.IsValid(neutralCreeps[1]) then
		for _, neutralCreep in pairs(neutralCreeps) do
			if
				Fu.IsValid(neutralCreep)
				and neutralCreep:HasModifier("modifier_crystal_maiden_frostbite")
				and neutralCreep:GetHealth() / neutralCreep:GetMaxHealth() > 0.3
				and (
					neutralCreep:GetUnitName() == "npc_dota_neutral_dark_troll_warlord"
					or neutralCreep:GetUnitName() == "npc_dota_neutral_satyr_hellcaller"
					or neutralCreep:GetUnitName() == "npc_dota_neutral_polar_furbolg_ursa_warrior"
				)
			then
				local castLocation = Fu.GetCastLocation(bot, neutralCreep, castRange, radius)
				if castLocation ~= nil then
					return BOT_ACTION_DESIRE_HIGH, castLocation
				end
			end
		end
	end
	if #enemiesNearby == 0 and not Fu.IsGoingOnSomeone(bot) and abilityLevel > 2 then
		if killCreepAoe.count >= 2 and (weakestExtendedCreep ~= nil or botLevel == 25) then
			return BOT_ACTION_DESIRE_HIGH, killCreepAoe.targetloc
		end
		if creepAoe.count >= 4 and weakestExtendedCreep ~= nil then
			return BOT_ACTION_DESIRE_HIGH, creepAoe.targetloc
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if Fu.IsRoshan(botTarget) and Fu.IsInRange(bot, botTarget, castRange) and Fu.IsAttacking(bot) then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, castRange) and Fu.IsAttacking(bot) then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.ConsiderW()
	if not frostbiteAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local castRange = frostbiteAbility:GetCastRange() + 30 + aetherRange
	local castPoint = frostbiteAbility:GetCastPoint()
	local manaCost = frostbiteAbility:GetManaCost()
	local abilityLevel = frostbiteAbility:GetLevel()
	local damage = 100 + abilityLevel * 50
	local nearbyAllyHeroes = Fu.GetNearbyHeroes(bot, 1200, false, BOT_MODE_NONE)
	local enemiesNearby = Fu.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE)
	if #enemiesNearby <= 1 and castRange < bot:GetAttackRange() then
		castRange = bot:GetAttackRange() + 60
	end
	local enemiesInRange = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	local enemiesInExtendedRange = Fu.GetNearbyHeroes(bot, castRange + 200, true, BOT_MODE_NONE)
	local weakestEnemy, weakestEnemyHealth = X.cm_GetWeakestUnit(enemiesInRange)
	local weakestExtendedEnemy, weakestExtendedEnemyHealth = X.cm_GetWeakestUnit(enemiesInExtendedRange)
	local creepsInRange = bot:GetNearbyCreeps(castRange + 100, true)
	local creepsNearby = bot:GetNearbyCreeps(1400, true)
	local strongestCreep, strongestCreepHealth = X.cm_GetStrongestUnit(creepsInRange)
	local strongestNearbyCreep, strongestNearbyCreepHealth = X.cm_GetStrongestUnit(creepsNearby)
	local enemyTowers = bot:GetNearbyTowers(900, true)
	if Fu.IsValid(weakestEnemy) and Fu.CanCastOnTargetAdvanced(weakestEnemy) then
		if Fu.WillMagicKillTarget(bot, weakestEnemy, damage, castPoint) then
			return BOT_ACTION_DESIRE_HIGH, weakestEnemy
		end
	end
	for _, enemyHero in pairs(enemiesInExtendedRange) do
		if
			Fu.IsValid(enemyHero)
			and enemyHero:IsChanneling()
			and enemyHero:HasModifier("modifier_teleporting")
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and Fu.CanCastOnTargetAdvanced(enemyHero)
		then
			return BOT_ACTION_DESIRE_HIGH, enemyHero
		end
	end
	if Fu.IsInTeamFight(bot, 1200) and DotaTime() > 6 * 60 then
		local mostDangerousEnemy = nil
		local highestDamage = 0
		local enemiesInCastRange = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
		for _, enemyHero in pairs(enemiesInCastRange) do
			if
				Fu.IsValid(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
				and not Fu.IsDisabled(enemyHero)
				and not enemyHero:IsDisarmed()
			then
				local estimatedDamage = enemyHero:GetEstimatedDamageToTarget(false, bot, 3.0, DAMAGE_TYPE_PHYSICAL)
				if estimatedDamage > highestDamage then
					highestDamage = estimatedDamage
					mostDangerousEnemy = enemyHero
				end
			end
		end
		if mostDangerousEnemy ~= nil then
			return BOT_ACTION_DESIRE_HIGH, mostDangerousEnemy
		end
	end
	if bot:WasRecentlyDamagedByAnyHero(3.0) and #enemiesInRange >= 1 then
		for _, enemyHero in pairs(enemiesInRange) do
			if
				Fu.IsValid(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
				and not Fu.IsDisabled(enemyHero)
				and not enemyHero:IsDisarmed()
				and bot:IsFacingLocation(enemyHero:GetLocation(), 45)
			then
				return BOT_ACTION_DESIRE_HIGH, enemyHero
			end
		end
	end
	if bot:GetActiveMode() == BOT_MODE_LANING and #enemyTowers == 0 then
		if mpRatio > 0.5 or bot:GetMana() > retainMana then
			if Fu.IsValid(weakestEnemy) and not Fu.IsDisabled(weakestEnemy) then
				return BOT_ACTION_DESIRE_HIGH, weakestEnemy
			end
		end
		if mpRatio > 0.78 or bot:GetMana() > retainMana then
			if
				Fu.IsValid(weakestExtendedEnemy)
				and hpRatio > 0.6
				and #enemyTowers == 0
				and #creepsNearby + #enemiesInExtendedRange <= 5
				and not Fu.IsDisabled(weakestExtendedEnemy)
				and weakestExtendedEnemy:GetCurrentMovementSpeed() < bot:GetCurrentMovementSpeed()
			then
				return BOT_ACTION_DESIRE_HIGH, weakestExtendedEnemy
			end
		end
		if Fu.IsValid(enemiesNearby[1]) then
			if
				Fu.GetAllyUnitCountAroundEnemyTarget(bot, enemiesNearby[1], 350) >= 5
				and not Fu.IsDisabled(enemiesNearby[1])
				and not enemiesNearby[1]:IsMagicImmune()
				and hpRatio > 0.7
				and bot:GetMana() > retainMana
				and #creepsNearby + #enemiesInExtendedRange <= 3
				and #enemyTowers == 0
			then
				return BOT_ACTION_DESIRE_HIGH, enemiesNearby[1]
			end
		end
		if Fu.IsValid(weakestEnemy) then
			if weakestEnemy:GetHealth() / weakestEnemy:GetMaxHealth() < 0.5 then
				return BOT_ACTION_DESIRE_HIGH, weakestEnemy
			end
		end
	end
	if enemiesInRange[1] == nil and creepsInRange[1] ~= nil then
		for _, creep in pairs(creepsInRange) do
			if
				Fu.IsValid(creep)
				and creep:GetTeam() == GetOpposingTeam()
				and creep:GetHealth() > 460
				and not creep:IsMagicImmune()
				and not creep:IsInvulnerable()
				and creep:IsDominated()
			then
				return BOT_ACTION_DESIRE_HIGH, creep
			end
		end
	end
	if
		bot:GetActiveMode() ~= BOT_MODE_LANING
		and bot:GetActiveMode() ~= BOT_MODE_RETREAT
		and bot:GetActiveMode() ~= BOT_MODE_ATTACK
		and #enemiesNearby == 0
		and #nearbyAllyHeroes < 3
		and botLevel >= 5
	then
		if
			Fu.IsValid(strongestNearbyCreep)
			and (
				DotaTime() > 10 * 60
				or strongestNearbyCreep:GetUnitName() ~= "npc_dota_creep_badguys_melee"
					and strongestNearbyCreep:GetUnitName() ~= "npc_dota_creep_badguys_ranged"
					and strongestNearbyCreep:GetUnitName() ~= "npc_dota_creep_goodguys_melee"
					and strongestNearbyCreep:GetUnitName() ~= "npc_dota_creep_goodguys_ranged"
			)
		then
			if
				(strongestNearbyCreepHealth > 460 or strongestCreepHealth > 390 and mpRatio > 0.45)
				and strongestNearbyCreepHealth <= 1200
			then
				return BOT_ACTION_DESIRE_LOW, strongestNearbyCreep
			end
		end
		if
			Fu.IsValid(strongestCreep)
			and (
				DotaTime() > 10 * 60
				or strongestCreep:GetUnitName() ~= "npc_dota_creep_badguys_melee"
					and strongestCreep:GetUnitName() ~= "npc_dota_creep_badguys_ranged"
					and strongestCreep:GetUnitName() ~= "npc_dota_creep_goodguys_melee"
					and strongestCreep:GetUnitName() ~= "npc_dota_creep_goodguys_ranged"
			)
		then
			if
				(strongestCreepHealth > 410 or strongestCreepHealth > 360 and mpRatio > 0.45)
				and strongestCreepHealth <= 1200
			then
				return BOT_ACTION_DESIRE_LOW, strongestCreep
			end
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		local target = Fu.GetProperTarget(bot)
		if
			Fu.IsValidHero(target)
			and Fu.CanCastOnNonMagicImmune(target)
			and Fu.CanCastOnTargetAdvanced(target)
			and Fu.IsInRange(target, bot, castRange + 50)
			and not Fu.IsDisabled(target)
			and not target:IsDisarmed()
		then
			return BOT_ACTION_DESIRE_HIGH, target
		end
	end
	if Fu.IsRetreating(bot) then
		for _, enemyHero in pairs(enemiesInRange) do
			if
				Fu.IsValid(enemyHero)
				and bot:WasRecentlyDamagedByHero(enemyHero, 5.0)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
				and not Fu.IsDisabled(enemyHero)
				and Fu.IsInRange(enemyHero, bot, castRange - 80)
			then
				return BOT_ACTION_DESIRE_HIGH, enemyHero
			end
		end
	end
	if bot:GetActiveMode() == BOT_MODE_ROSHAN and bot:GetMana() >= 400 then
		if
			Fu.IsRoshan(botTarget)
			and not Fu.IsDisabled(botTarget)
			and not botTarget:IsDisarmed()
			and Fu.IsInRange(botTarget, bot, castRange)
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.ConsiderR()
	if not freezingFieldAbility:IsFullyCastable() or bot:DistanceFromFountain() < 300 then
		return BOT_ACTION_DESIRE_NONE
	end
	local radius = freezingFieldAbility:GetAOERadius() * 0.88
	local nearbyAllyHeroes = Fu.GetNearbyHeroes(bot, 1200, false, BOT_MODE_NONE)
	local enemiesInRange = Fu.GetNearbyHeroes(bot, radius, true, BOT_MODE_NONE)
	local weakestEnemy, weakestEnemyHealth = X.cm_GetWeakestUnit(enemiesInRange)
	local trappedEnemyCount = 0
	for _, enemyHero in pairs(enemiesInRange) do
		if
			Fu.IsValid(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and (
				Fu.IsDisabled(enemyHero)
				or Fu.IsInRange(bot, enemyHero, radius * 0.82 - enemyHero:GetCurrentMovementSpeed())
			)
		then
			trappedEnemyCount = trappedEnemyCount + 1
		end
	end
	if
		bot:GetActiveMode() ~= BOT_MODE_RETREAT
		or bot:GetActiveMode() == BOT_MODE_RETREAT and bot:GetActiveModeDesire() <= 0.85
	then
		if #enemiesInRange >= 3 or trappedEnemyCount >= 2 then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		local target = Fu.GetProperTarget(bot)
		if
			Fu.IsValidHero(target)
			and Fu.CanCastOnNonMagicImmune(target)
			and (Fu.IsDisabled(target) or Fu.IsInRange(bot, target, 280))
			and target:GetHealth() <= target:GetActualIncomingDamage(bot:GetOffensivePower() * 1.5, DAMAGE_TYPE_MAGICAL)
			and GetUnitToUnitDistance(target, bot) <= radius
			and target:GetHealth() > 400
			and #nearbyAllyHeroes <= 2
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsRetreating(bot) and hpRatio > 0.38 then
		local closeEnemies = Fu.GetNearbyHeroes(bot, 500, true, BOT_MODE_NONE)
		local enemiesNearby = Fu.GetNearbyHeroes(bot, 1300, true, BOT_MODE_NONE)
		local nearestEnemy = closeEnemies[1]
		if
			Fu.IsValidHero(nearestEnemy)
			and Fu.CanCastOnNonMagicImmune(nearestEnemy)
			and not crystalNovaAbility:IsFullyCastable()
			and not frostbiteAbility:IsFullyCastable()
			and hpRatio > 0.38 * #enemiesNearby
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderCrystalClone()
	if not crystalCloneAbility:IsTrained() or not crystalCloneAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
	end
	local cloneDistance = 450
	botTarget = Fu.GetProperTarget(bot)
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidTarget(botTarget)
			and Fu.IsInRange(bot, botTarget, cloneDistance)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and not Fu.IsSuspiciousIllusion(botTarget)
		then
			local alliesNearTarget = Fu.GetNearbyHeroes(botTarget, 1200, true, BOT_MODE_NONE)
			local enemiesNearTarget = Fu.GetNearbyHeroes(botTarget, 1200, false, BOT_MODE_NONE)
			if alliesNearTarget ~= nil and enemiesNearTarget ~= nil and #alliesNearTarget >= #enemiesNearTarget then
				return BOT_ACTION_DESIRE_HIGH,
					Fu.Site.GetXUnitsTowardsLocation(bot, Fu.GetTeamFountain(), cloneDistance)
			end
		end
	end
	if Fu.IsRetreating(bot) then
		local enemiesNearby = Fu.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE)
		if
			enemiesNearby ~= nil
			and #enemiesNearby >= 1
			and Fu.IsValidHero(enemiesNearby[1])
			and Fu.IsInRange(bot, enemiesNearby[1], cloneDistance)
			and not Fu.IsSuspiciousIllusion(enemiesNearby[1])
		then
			local alliesNearEnemy = Fu.GetNearbyHeroes(enemiesNearby[1], 1200, true, BOT_MODE_NONE)
			local enemiesNearEnemy = Fu.GetNearbyHeroes(enemiesNearby[1], 1200, false, BOT_MODE_NONE)
			if
				alliesNearEnemy ~= nil
				and enemiesNearEnemy ~= nil
				and (#enemiesNearEnemy > #alliesNearEnemy or bot:WasRecentlyDamagedByAnyHero(1))
			then
				return BOT_ACTION_DESIRE_HIGH,
					Fu.Site.GetXUnitsTowardsLocation(bot, Fu.GetTeamFountain(), cloneDistance)
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.cm_GetWeakestUnit(units)
	local weakestUnit = nil
	local lowestHealth = 10000
	for _, unit in pairs(units) do
		if Fu.CanCastOnNonMagicImmune(unit) then
			if unit:GetHealth() < lowestHealth then
				lowestHealth = unit:GetHealth()
				weakestUnit = unit
			end
		end
	end
	return weakestUnit, lowestHealth
end
function X.cm_GetStrongestUnit(units)
	local strongestUnit = nil
	local highestHealth = GetBot():GetAttackDamage()
	for _, unit in pairs(units) do
		if
			unit ~= nil
			and unit:IsAlive()
			and not unit:HasModifier("modifier_fountain_glyph")
			and not unit:IsMagicImmune()
			and not unit:IsInvulnerable()
			and unit:GetHealth() <= 1100
			and not unit:IsAncientCreep()
			and unit:GetMagicResist() < 1.05 - unit:GetHealth() / 1100
			and not Fu.IsOtherAllysTarget(unit)
			and string.find(unit:GetUnitName(), "siege") == nil
			and (botLevel < 25 or unit:GetTeam() == TEAM_NEUTRAL)
		then
			if
				string.find(unit:GetUnitName(), "ranged") ~= nil
				and unit:GetHealth() > GetBot():GetAttackDamage() * 2
			then
				return unit, 500
			end
			if unit:GetHealth() > highestHealth then
				highestHealth = unit:GetHealth()
				strongestUnit = unit
			end
		end
	end
	return strongestUnit, highestHealth
end
return X
