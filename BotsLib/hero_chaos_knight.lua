-- Chaos Knight: skill build, item build, and ability use for this hero.
local X = {}
local bot = GetBot()
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local AbilityContext = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local Minion = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local sTalentList = Fu.Skill.GetTalentList(bot)
local sAbilityList = Fu.Skill.GetAbilityList(bot)
local sRole = Fu.Item.GetRoleItemsBuyList(bot)
local tTalentTreeList = { ["t25"] = { 0, 10 }, ["t20"] = { 10, 0 }, ["t15"] = { 10, 0 }, ["t10"] = { 0, 10 } }
local tAllAbilityBuildList = { { 1, 2, 3, 3, 3, 6, 3, 2, 2, 2, 6, 1, 1, 1, 6 } }
local nAbilityBuildList = Fu.Skill.GetRandomBuild(tAllAbilityBuildList)
local nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList)
local sRoleItemsBuyList = {}
sRoleItemsBuyList["pos_1"] = {
	"item_tango",
	"item_quelling_blade",
	"item_double_branches",
	"item_gauntlets",
	"item_circlet",
	"item_bracer",
	"item_magic_wand",
	"item_power_treads",
	"item_armlet",
	"item_aghanims_shard",
	"item_echo_sabre",
	"item_manta",
	"item_orchid",
	"item_bloodthorn",
	"item_travel_boots",
	"item_heart",
	"item_satanic",
	"item_moon_shard",
	"item_travel_boots_2",
	"item_ultimate_scepter_2",
}
sRoleItemsBuyList["pos_2"] = sRoleItemsBuyList["pos_1"]
sRoleItemsBuyList["pos_3"] = {
	"item_tango",
	"item_quelling_blade",
	"item_gauntlets",
	"item_branches",
	"item_magic_stick",
	"item_bracer",
	"item_magic_wand",
	"item_power_treads",
	"item_aghanims_shard",
	"item_crimson_guard",
	"item_armlet",
	"item_echo_sabre",
	"item_assault",
	"item_travel_boots",
	"item_manta",
	"item_heart",
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
	"item_basher",
	"item_monkey_king_bar",
	"item_assault",
	"item_heavens_halberd",
	"item_aghanims_shard",
	"item_abyssal_blade",
	"item_ultimate_scepter",
	"item_moon_shard",
	"item_ultimate_scepter_2",
}
sRoleItemsBuyList["pos_5"] = {
	"item_priest_outfit",
	"item_hand_of_midas",
	"item_mekansm",
	"item_glimmer_cape",
	"item_pipe",
	"item_basher",
	"item_monkey_king_bar",
	"item_assault",
	"item_heavens_halberd",
	"item_aghanims_shard",
	"item_abyssal_blade",
	"item_ultimate_scepter",
	"item_moon_shard",
	"item_ultimate_scepter_2",
}
X["sBuyList"] = sRoleItemsBuyList[sRole]
X["sSellList"] = { "item_power_treads", "item_quelling_blade", "item_travel_boots", "item_armlet" }
if Fu.Role.IsPvNMode() or Fu.Role.IsAllShadow() then
	X["sBuyList"], X["sSellList"] = { "PvN_tank" }, { "item_power_treads", "item_quelling_blade" }
end
nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"] =
	Fu.SetUserHeroInit(nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"])
X["sSkillList"] = Fu.Skill.GetSkillList(sAbilityList, nAbilityBuildList, sTalentList, nTalentBuildList)
X["bDeafaultAbility"] = true
X["bDeafaultItem"] = false
function X.MinionThink(hMinionUnit)
	Minion.MinionThink(hMinionUnit)
end
local chaosBoltAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[1]), "sAbilityList[1]", "chaos_knight")
local realityRiftAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[2]), "sAbilityList[2]", "chaos_knight")
local phantasmAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[6]), "sAbilityList[6]", "chaos_knight")
local talent6 = SafeAbility(bot:GetAbilityByName(sTalentList[6]), "sTalentList[6]", "chaos_knight")
local armletItem = nil
local chaosBoltDesire, chaosBoltTarget = 0
local realityRiftDesire, realityRiftTarget = 0
local phantasmDesire = 0
local botTarget
local hpRatio, nearbyEnemies
function X.SkillsComplement()
	if Fu.CanNotUseAbility(bot) or bot:IsInvisible() then
		return
	end
	local context = AbilityContext.Build(bot)
	botTarget = context.target
	hpRatio = context.hp
	nearbyEnemies = context.enemies
	armletItem = Fu.IsItemAvailable("item_armlet")
	phantasmDesire = X.ConsiderR()
	if phantasmDesire > 0 then
		if armletItem ~= nil and armletItem:IsFullyCastable() and armletItem:GetToggleState() == false then
			bot:ActionQueue_UseAbility(armletItem)
		end
		bot:ActionQueue_UseAbility(phantasmAbility)
		return
	end
	realityRiftDesire, realityRiftTarget = X.ConsiderW()
	if realityRiftDesire > 0 then
		Fu.SetQueuePtToINT(bot, false)
		bot:ActionQueue_UseAbilityOnEntity(realityRiftAbility, realityRiftTarget)
		return
	end
	chaosBoltDesire, chaosBoltTarget = X.ConsiderQ()
	if chaosBoltDesire > 0 then
		Fu.SetQueuePtToINT(bot, true)
		bot:ActionQueue_UseAbilityOnEntity(chaosBoltAbility, chaosBoltTarget)
		return
	end
end
function X.ConsiderQ()
	if not chaosBoltAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
	end
	local castRange = chaosBoltAbility:GetCastRange()
	local castPoint = chaosBoltAbility:GetCastPoint()
	local abilityLevel = chaosBoltAbility:GetLevel()
	-- datafeed: damage is random between damage_min (90/120/150/180) and damage_max; a sure kill needs the
	-- minimum (the old hard-coded formula ran above it)
	local damage = chaosBoltAbility:GetSpecialValueInt("damage_min")
	local enemiesInCastRange = Fu.GetNearbyHeroes(bot, castRange + 99, true, BOT_MODE_NONE)
	local enemiesNearby = Fu.GetNearbyHeroes(bot, 880, true, BOT_MODE_NONE)
	if #enemiesInCastRange > 0 then
		for i = 1, #enemiesInCastRange do
			if
				Fu.IsValid(enemiesInCastRange[i])
				and Fu.CanCastOnNonMagicImmune(enemiesInCastRange[i])
				and Fu.CanCastOnTargetAdvanced(enemiesInCastRange[i])
				and enemiesInCastRange[i]:GetHealth() < enemiesInCastRange[i]:GetActualIncomingDamage(
					damage,
					DAMAGE_TYPE_MAGICAL
				)
				and GetUnitToUnitDistance(enemiesInCastRange[i], bot) > bot:GetAttackRange() + 60
				and not Fu.IsDisabled(enemiesInCastRange[i])
			then
				return BOT_ACTION_DESIRE_HIGH, enemiesInCastRange[i]
			end
		end
	end
	if #enemiesNearby > 0 then
		for i = 1, #enemiesNearby do
			if
				Fu.IsValid(enemiesNearby[i])
				and Fu.CanCastOnNonMagicImmune(enemiesNearby[i])
				and Fu.CanCastOnTargetAdvanced(enemiesNearby[i])
				and enemiesNearby[i]:IsChanneling()
			then
				return BOT_ACTION_DESIRE_HIGH, enemiesNearby[i]
			end
		end
	end
	if Fu.IsInTeamFight(bot, 1200) and DotaTime() > 4 * 60 then
		local strongestEnemy = nil
		local maxDamage = 0
		for _, enemy in pairs(enemiesInCastRange) do
			if
				Fu.IsValid(enemy)
				and Fu.CanCastOnNonMagicImmune(enemy)
				and Fu.CanCastOnTargetAdvanced(enemy)
				and not Fu.IsDisabled(enemy)
				and not enemy:IsDisarmed()
			then
				local estimatedDamage = enemy:GetEstimatedDamageToTarget(false, bot, 3.0, DAMAGE_TYPE_ALL)
				if estimatedDamage > maxDamage then
					maxDamage = estimatedDamage
					strongestEnemy = enemy
				end
			end
		end
		if strongestEnemy ~= nil then
			return BOT_ACTION_DESIRE_HIGH, strongestEnemy
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidHero(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.CanCastOnTargetAdvanced(botTarget)
			and Fu.IsInRange(botTarget, bot, castRange)
			and not Fu.IsDisabled(botTarget)
			and not botTarget:IsDisarmed()
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end
	if Fu.IsRetreating(bot) then
		if
			Fu.IsValid(enemiesInCastRange[1])
			and Fu.CanCastOnNonMagicImmune(enemiesInCastRange[1])
			and Fu.CanCastOnTargetAdvanced(enemiesInCastRange[1])
			and not Fu.IsDisabled(enemiesInCastRange[1])
			and not enemiesInCastRange[1]:IsDisarmed()
			and GetUnitToUnitDistance(bot, enemiesInCastRange[1]) <= castRange - 60
		then
			return BOT_ACTION_DESIRE_HIGH, enemiesInCastRange[1]
		end
	end
	if bot:GetActiveMode() == BOT_MODE_ROSHAN and bot:GetMana() > 400 then
		local attackTarget = bot:GetAttackTarget()
		if
			attackTarget ~= nil
			and attackTarget:IsAlive()
			and Fu.GetHP(attackTarget) > 0.2
			and not Fu.IsDisabled(attackTarget)
			and not attackTarget:IsDisarmed()
		then
			return BOT_ACTION_DESIRE_LOW, attackTarget
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderW()
	if not realityRiftAbility:IsFullyCastable() or bot:IsRooted() then
		return BOT_ACTION_DESIRE_NONE
	end
	local castRange = realityRiftAbility:GetCastRange()
	local castPoint = realityRiftAbility:GetCastPoint()
	local abilityLevel = realityRiftAbility:GetLevel()
	local damage = 0
	local hasTalent6 = talent6:IsTrained()
	local enemiesInCastRange = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidHero(botTarget)
			and Fu.IsInRange(botTarget, bot, castRange + 50)
			and (not Fu.IsInRange(bot, botTarget, 200) or not botTarget:HasModifier(
				"modifier_chaos_knight_reality_rift"
			))
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.CanCastOnTargetAdvanced(botTarget)
			and not Fu.IsDisabled(botTarget)
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end
	if Fu.IsRetreating(bot) then
		local retreatEnemies = Fu.GetNearbyHeroes(bot, 800, true, BOT_MODE_NONE)
		local laneCreepsInRange = bot:GetNearbyLaneCreeps(castRange, true)
		if retreatEnemies[1] ~= nil and laneCreepsInRange[1] ~= nil then
			for _, creep in pairs(laneCreepsInRange) do
				if
					retreatEnemies[1]:IsFacingLocation(bot:GetLocation(), 30)
					and bot:IsFacingLocation(creep:GetLocation(), 30)
					and GetUnitToUnitDistance(bot, creep) >= 650
				then
					return BOT_ACTION_DESIRE_LOW, creep
				end
			end
		end
	end
	if nearbyEnemies[1] == nil and bot:GetAttackDamage() >= 150 then
		local enemyLaneCreeps = bot:GetNearbyLaneCreeps(1000, true)
		for i = 1, #enemyLaneCreeps do
			local creep = enemyLaneCreeps[#enemyLaneCreeps - i + 1]
			if
				Fu.IsValid(creep)
				and not creep:HasModifier("modifier_fountain_glyph")
				and Fu.IsKeyWordUnit("ranged", creep)
				and GetUnitToUnitDistance(bot, creep) >= 350
			then
				return BOT_ACTION_DESIRE_LOW, creep
			end
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if
			Fu.IsRoshan(botTarget)
			and Fu.IsInRange(bot, botTarget, 800)
			and Fu.CanBeAttacked(botTarget)
			and Fu.GetHP(botTarget) > 0.5
			and Fu.IsAttacking(bot)
			and (Fu.IsEarlyGame() or Fu.IsMidGame())
			and Fu.GetManaAfter(phantasmAbility:GetManaCost()) > 0.35
		then
			-- fix: Reality Rift is unit-target (behavior 8); this returned no target
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if
			Fu.IsTormentor(botTarget)
			and Fu.IsInRange(bot, botTarget, 800)
			and Fu.CanBeAttacked(botTarget)
			and Fu.GetHP(botTarget) > 0.5
			and Fu.IsAttacking(bot)
			and (Fu.IsEarlyGame() or Fu.IsMidGame())
		then
			-- fix: Reality Rift is unit-target (behavior 8); this returned no target
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderR()
	if not phantasmAbility:IsFullyCastable() or bot:DistanceFromFountain() < 500 then
		return BOT_ACTION_DESIRE_NONE
	end
	local nearbyAllies = Fu.GetAlliesNearLoc(bot:GetLocation(), 1200)
	local nearbyEnemyList = Fu.GetEnemyList(bot, 1600)
	local nearbyTowers = bot:GetNearbyTowers(700, true)
	local nearbyBarracks = bot:GetNearbyBarracks(400, true)
	local allyLaneCreeps = bot:GetNearbyLaneCreeps(1000, false)
	local engageRange = realityRiftAbility:IsFullyCastable() and 1200 or 900
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidHero(botTarget)
			and Fu.IsInRange(bot, botTarget, engageRange)
			and Fu.CanCastOnMagicImmune(botTarget)
			and (Fu.GetHP(botTarget) > 0.5 or hpRatio < 0.7 or #nearbyEnemyList >= 2)
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsInTeamFight(bot, 1200) then
		if #nearbyEnemyList >= 2 then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsPushing(bot) and DotaTime() > 8 * 30 then
		if (#nearbyTowers >= 1 or #nearbyBarracks >= 1) and #allyLaneCreeps >= 2 then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if
		bot:GetActiveMode() == BOT_MODE_RETREAT
		and hpRatio >= 0.5
		and Fu.IsValidHero(nearbyEnemyList[1])
		and GetUnitToUnitDistance(bot, nearbyEnemyList[1]) <= 700
	then
		return BOT_ACTION_DESIRE_HIGH
	end
	return BOT_ACTION_DESIRE_NONE
end
return X
