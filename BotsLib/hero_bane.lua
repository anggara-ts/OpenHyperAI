-- Bane: skill build, item build, and ability use for this hero.
local X = {}
local bot = GetBot()
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local AbilityContext = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local Minion = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local sTalentList = Fu.Skill.GetTalentList(bot)
local sAbilityList = Fu.Skill.GetAbilityList(bot)
local sRole = Fu.Item.GetRoleItemsBuyList(bot)
local tTalentTreeList = { ["t25"] = { 10, 0 }, ["t20"] = { 0, 10 }, ["t15"] = { 10, 0 }, ["t10"] = { 10, 0 } }
local tAllAbilityBuildList = { { 2, 3, 2, 3, 2, 6, 2, 3, 3, 1, 6, 1, 1, 1, 6 } }
local nAbilityBuildList = Fu.Skill.GetRandomBuild(tAllAbilityBuildList)
local nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList)
local sRoleItemsBuyList = {}
sRoleItemsBuyList["pos_1"] = {
	"item_crystal_maiden_outfit",
	"item_point_booster",
	"item_aghanims_shard",
	"item_ultimate_scepter",
	"item_shadow_amulet",
	"item_rod_of_atos",
	"item_invis_sword",
	"item_black_king_bar",
	"item_silver_edge",
	"item_shivas_guard",
	"item_gungir",
	"item_mystic_staff",
	"item_ultimate_scepter_2",
	"item_sheepstick",
}
sRoleItemsBuyList["pos_2"] = {
	"item_mage_outfit",
	"item_ancient_janggo",
	"item_glimmer_cape",
	"item_boots_of_bearing",
	"item_pipe",
	"item_aghanims_shard",
	"item_shivas_guard",
	"item_ultimate_scepter",
	"item_wind_waker",
	"item_mystic_staff",
	"item_ultimate_scepter_2",
	"item_sheepstick",
}
sRoleItemsBuyList["pos_3"] = {
	"item_crystal_maiden_outfit",
	"item_point_booster",
	"item_aghanims_shard",
	"item_ultimate_scepter",
	"item_shadow_amulet",
	"item_rod_of_atos",
	"item_invis_sword",
	"item_black_king_bar",
	"item_silver_edge",
	"item_shivas_guard",
	"item_gungir",
	"item_mystic_staff",
	"item_ultimate_scepter_2",
	"item_sheepstick",
}
sRoleItemsBuyList["pos_4"] = {
	"item_priest_outfit",
	"item_aether_lens",
	"item_aghanims_shard",
	"item_blink",
	"item_glimmer_cape",
	"item_ultimate_scepter",
	"item_shivas_guard",
	"item_mystic_staff",
	"item_sheepstick",
	"item_ultimate_scepter_2",
}
sRoleItemsBuyList["pos_5"] = {
	"item_blood_grenade",
	"item_crystal_maiden_outfit",
	"item_aether_lens",
	"item_glimmer_cape",
	"item_aghanims_shard",
	"item_blink",
	"item_ultimate_scepter",
	"item_mystic_staff",
	"item_sheepstick",
	"item_octarine_core",
	"item_moon_shard",
	"item_ultimate_scepter_2",
}
X["sBuyList"] = sRoleItemsBuyList[sRole]
X["sSellList"] = { "item_circlet", "item_magic_wand" }
if Fu.Role.IsPvNMode() or Fu.Role.IsAllShadow() then
	X["sBuyList"], X["sSellList"] = { "PvN_priest" }, {}
end
nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"] =
	Fu.SetUserHeroInit(nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"])
X["sSkillList"] = Fu.Skill.GetSkillList(sAbilityList, nAbilityBuildList, sTalentList, nTalentBuildList)
X["bDeafaultAbility"] = false
X["bDeafaultItem"] = true
function X.MinionThink(hMinionUnit)
	Minion.MinionThink(hMinionUnit)
end
local enfeebleAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[1]), "sAbilityList[1]", "bane")
local brainSapAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[2]), "sAbilityList[2]", "bane")
local nightmareAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[3]), "sAbilityList[3]", "bane")
local fiendsGripAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[6]), "sAbilityList[6]", "bane")
local talent4 = SafeAbility(bot:GetAbilityByName(sTalentList[4]), "sTalentList[4]", "bane")
local talent7 = SafeAbility(bot:GetAbilityByName(sTalentList[7]), "sTalentList[7]", "bane")
local enfeebleDesire, enfeebleTarget
local brainSapDesire, brainSapTarget
local nightmareDesire, nightmareTarget
local fiendsGripDesire, fiendsGripTarget
local brainSapBonusDamage = 0
local brainSapTargetType = nil
local botLevel, mpRatio, nearbyEnemies, nearbyAllies
local botTarget -- was a global set every think
function X.SkillsComplement()
	if brainSapTargetType == nil and brainSapAbility:IsTrained() then
		brainSapTargetType = brainSapAbility:GetTargetType()
	end
	if Fu.CanNotUseAbility(bot) or bot:IsInvisible() then
		return
	end
	local context = AbilityContext.Build(bot)
	botLevel = context.level
	mpRatio = context.mp
	botTarget = context.target
	nearbyEnemies = context.enemies
	nearbyAllies = context.allies
	if talent7:IsTrained() then
		brainSapBonusDamage = talent7:GetSpecialValueInt("value")
	end
	enfeebleDesire, enfeebleTarget = X.ConsiderQ()
	if enfeebleDesire > 0 then
		Fu.SetQueuePtToINT(bot, true)
		bot:ActionQueue_UseAbilityOnEntity(enfeebleAbility, enfeebleTarget)
		return
	end
	brainSapDesire, brainSapTarget = X.ConsiderW()
	if brainSapDesire > 0 then
		Fu.SetQueuePtToINT(bot, true)
		if brainSapTargetType ~= nil and brainSapTargetType ~= brainSapAbility:GetTargetType() then
			-- A location needs the location order; UseAbilityOnEntity was given a vector here.
			bot:ActionQueue_UseAbilityOnLocation(brainSapAbility, brainSapTarget:GetLocation())
		else
			bot:ActionQueue_UseAbilityOnEntity(brainSapAbility, brainSapTarget)
		end
		return
	end
	fiendsGripDesire, fiendsGripTarget = X.ConsiderR()
	if fiendsGripDesire > 0 then
		Fu.SetQueuePtToINT(bot, true)
		Fu.SetQueueToInvisible(bot)
		bot:ActionQueue_UseAbilityOnEntity(fiendsGripAbility, fiendsGripTarget)
		return
	end
	nightmareDesire, nightmareTarget = X.ConsiderE()
	if nightmareDesire > 0 then
		Fu.SetQueuePtToINT(bot, true)
		bot:ActionQueue_UseAbilityOnEntity(nightmareAbility, nightmareTarget)
		return
	end
end
function X.ConsiderE()
	if not nightmareAbility:IsFullyCastable() then
		return 0
	end
	local abilityLevel = nightmareAbility:GetLevel()
	local castRange = nightmareAbility:GetCastRange()
	local radius = 600
	local castPoint = nightmareAbility:GetCastPoint()
	local manaCost = nightmareAbility:GetManaCost()
	local damage = nightmareAbility:GetSpecialValueInt("damage")
	local damageType = DAMAGE_TYPE_MAGICAL
	local enemiesInRange = Fu.GetAroundEnemyHeroList(castRange)
	local enemiesInRangeWide = Fu.GetAroundEnemyHeroList(castRange + 200)
	local castTarget = nil
	local castReason = nil
	for _, enemyHero in pairs(enemiesInRangeWide) do
		if
			Fu.IsValid(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and Fu.CanCastOnTargetAdvanced(enemyHero)
		then
			if enemyHero:IsChanneling() then
				castTarget = enemyHero
				castReason = "E-打断" .. Fu.Chat.GetNormName(castTarget)
				return BOT_ACTION_DESIRE_HIGH, castTarget, castReason
			end
		end
	end
	if Fu.IsRetreating(bot) and (bot:WasRecentlyDamagedByAnyHero(3.0) or bot:GetActiveModeDesire() > 0.7) then
		for _, enemyHero in pairs(enemiesInRangeWide) do
			if
				Fu.IsValid(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
				and not Fu.IsDisabled(enemyHero)
				and not enemyHero:IsDisarmed()
			then
				castTarget = enemyHero
				castReason = "E-撤退" .. Fu.Chat.GetNormName(castTarget)
				return BOT_ACTION_DESIRE_HIGH, castTarget, castReason
			end
		end
	end
	if Fu.IsInTeamFight(bot, 1200) then
		local bestTarget = nil
		local maxEstimatedDamage = 0
		local castableEnemyCount = 0
		for _, enemyHero in pairs(nearbyEnemies) do
			if Fu.IsValid(enemyHero) and Fu.CanCastOnNonMagicImmune(enemyHero) then
				castableEnemyCount = castableEnemyCount + 1
				if
					Fu.CanCastOnTargetAdvanced(enemyHero)
					and not Fu.IsDisabled(enemyHero)
					and not enemyHero:IsDisarmed()
				then
					local estimatedDamage = enemyHero:GetEstimatedDamageToTarget(true, bot, 6.0, DAMAGE_TYPE_ALL)
					if estimatedDamage > maxEstimatedDamage then
						maxEstimatedDamage = estimatedDamage
						bestTarget = enemyHero
					end
				end
			end
		end
		if bestTarget ~= nil and castableEnemyCount >= 2 and Fu.IsInRange(bot, bestTarget, castRange + 150) then
			castTarget = bestTarget
			castReason = "E-团战控制" .. Fu.Chat.GetNormName(castTarget)
			return BOT_ACTION_DESIRE_HIGH, castTarget, castReason
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if Fu.IsValidHero(botTarget) and Fu.IsInRange(bot, botTarget, 1200) then
			for _, enemyHero in pairs(enemiesInRange) do
				if
					Fu.IsValid(enemyHero)
					and enemyHero:GetPlayerID() ~= botTarget:GetPlayerID()
					and Fu.CanCastOnNonMagicImmune(enemyHero)
					and Fu.CanCastOnTargetAdvanced(enemyHero)
					and not Fu.IsDisabled(enemyHero)
					and not enemyHero:IsDisarmed()
				then
					castTarget = enemyHero
					castReason = "E-睡眠:" .. Fu.Chat.GetNormName(castTarget)
					return BOT_ACTION_DESIRE_HIGH, castTarget, castReason
				end
			end
			if
				Fu.IsInRange(bot, botTarget, castRange)
				and not Fu.IsInRange(bot, botTarget, 530)
				and Fu.IsRunning(botTarget)
				and bot:IsFacingLocation(botTarget:GetLocation(), 20)
				and not botTarget:IsFacingLocation(bot:GetLocation(), 150)
				and Fu.CanCastOnNonMagicImmune(botTarget)
				and Fu.CanCastOnTargetAdvanced(botTarget)
			then
				local alliesNearTarget = Fu.GetNearbyHeroes(botTarget, 500, true, BOT_MODE_NONE)
				if #alliesNearTarget == 0 then
					castTarget = botTarget
					castReason = "E-留人" .. Fu.Chat.GetNormName(castTarget)
					return BOT_ACTION_DESIRE_HIGH, castTarget, castReason
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderW()
	if not brainSapAbility:IsFullyCastable() then
		return 0
	end
	local abilityLevel = brainSapAbility:GetLevel()
	local castRange = brainSapAbility:GetCastRange()
	local radius = 600
	local castPoint = brainSapAbility:GetCastPoint()
	local manaCost = brainSapAbility:GetManaCost()
	local damage = brainSapAbility:GetSpecialValueInt("brain_sap_damage") + brainSapBonusDamage
	-- datafeed: Brain Sap deals pure damage (damage 4), not magical.
	local damageType = DAMAGE_TYPE_PURE
	local enemiesInRange = Fu.GetAroundEnemyHeroList(castRange)
	local enemiesInRangeWide = Fu.GetAroundEnemyHeroList(castRange + 200)
	local castTarget = nil
	local castReason = nil
	local missingHealth = bot:GetMaxHealth() - bot:GetHealth()
	for _, enemyHero in pairs(enemiesInRangeWide) do
		if
			Fu.IsValid(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and Fu.CanCastOnTargetAdvanced(enemyHero)
		then
			if Fu.CanKillTarget(enemyHero, damage, damageType) then
				castTarget = enemyHero
				castReason = "W-击杀敌人" .. Fu.Chat.GetNormName(castTarget)
				return BOT_ACTION_DESIRE_HIGH, castTarget, castReason
			end
		end
	end
	if botLevel <= 7 and mpRatio < 0.72 and missingHealth < damage * 0.8 then
		return BOT_ACTION_DESIRE_NONE
	end
	if Fu.IsInTeamFight(bot, 1200) then
		local weakestEnemy = nil
		local lowestHealth = 99999
		for _, enemyHero in pairs(enemiesInRange) do
			if
				Fu.IsValid(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
			then
				local enemyHealth = enemyHero:GetHealth()
				if enemyHealth < lowestHealth then
					lowestHealth = enemyHealth
					weakestEnemy = enemyHero
				end
			end
		end
		if weakestEnemy ~= nil then
			castTarget = weakestEnemy
			castReason = "W-团战最弱" .. Fu.Chat.GetNormName(castTarget)
			return BOT_ACTION_DESIRE_HIGH, castTarget, castReason
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidHero(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.CanCastOnTargetAdvanced(botTarget)
			and Fu.IsInRange(botTarget, bot, castRange + 50)
		then
			if abilityLevel >= 2 or mpRatio > 0.78 or Fu.GetHP(botTarget) < 0.38 then
				castTarget = botTarget
				castReason = "W-攻击" .. Fu.Chat.GetNormName(castTarget)
				return BOT_ACTION_DESIRE_HIGH, castTarget, castReason
			end
		end
	end
	if
		bot:WasRecentlyDamagedByAnyHero(3.0)
		and botLevel >= 10
		and bot:GetActiveMode() ~= BOT_MODE_RETREAT
		and #enemiesInRange >= 1
		and missingHealth >= damage
	then
		for _, enemyHero in pairs(enemiesInRange) do
			if
				Fu.IsValid(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and not Fu.IsDisabled(enemyHero)
				and not enemyHero:IsDisarmed()
				and bot:IsFacingLocation(enemyHero:GetLocation(), 45)
			then
				castTarget = enemyHero
				castReason = "W-自我保护" .. Fu.Chat.GetNormName(castTarget)
				return BOT_ACTION_DESIRE_HIGH, castTarget, castReason
			end
		end
	end
	if Fu.IsRetreating(bot) and missingHealth > damage then
		for _, enemyHero in pairs(enemiesInRange) do
			if
				Fu.IsValid(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
				and (bot:WasRecentlyDamagedByHero(enemyHero, 5.0) or missingHealth > damage * 2)
			then
				castTarget = enemyHero
				castReason = "W-通过敌人回血" .. Fu.Chat.GetNormName(castTarget)
				return BOT_ACTION_DESIRE_HIGH, castTarget, castReason
			end
		end
		if
			#nearbyEnemies == 0
			and botLevel >= 10
			and not bot:WasRecentlyDamagedByAnyHero(3.0)
			and missingHealth > damage * 1.5
		then
			local nearbyCreeps = bot:GetNearbyCreeps(1000, true)
			for _, creep in pairs(nearbyCreeps) do
				if Fu.IsValid(creep) and Fu.CanCastOnNonMagicImmune(creep) then
					castTarget = creep
					castReason = "W-通过小兵回血"
					return BOT_ACTION_DESIRE_HIGH, castTarget, castReason
				end
			end
		end
	end
	if Fu.IsFarming(bot) and abilityLevel >= 3 and Fu.IsAllowedToSpam(bot, manaCost) then
		local neutralTarget = botTarget
		if
			Fu.IsValid(neutralTarget)
			and Fu.IsInRange(bot, neutralTarget, castRange + 100)
			and neutralTarget:GetTeam() == TEAM_NEUTRAL
			and not Fu.IsRoshan(neutralTarget)
			and (neutralTarget:GetMagicResist() < 0.3 or mpRatio > 0.8)
			and not Fu.CanKillTarget(neutralTarget, bot:GetAttackDamage() * 2, DAMAGE_TYPE_PHYSICAL)
		then
			castTarget = neutralTarget
			castReason = "W-打野"
			return BOT_ACTION_DESIRE_HIGH, castTarget, castReason
		end
	end
	if
		(Fu.IsPushing(bot) or Fu.IsDefending(bot) or Fu.IsFarming(bot))
		and Fu.IsAllowedToSpam(bot, manaCost * 0.32)
		and abilityLevel >= 3
		and DotaTime() > 8 * 60
		and #nearbyAllies <= 2
		and #nearbyEnemies == 0
	then
		local nearbyLaneCreeps = bot:GetNearbyLaneCreeps(1200, true)
		local rangedKeyword = "ranged"
		for _, creep in pairs(nearbyLaneCreeps) do
			if
				Fu.IsValid(creep)
				and (Fu.IsKeyWordUnit(rangedKeyword, creep) or mpRatio > 0.6)
				and not creep:HasModifier("modifier_fountain_glyph")
				and Fu.WillKillTarget(creep, damage, damageType, castPoint)
				and not Fu.CanKillTarget(creep, bot:GetAttackDamage() * 1.38, DAMAGE_TYPE_PHYSICAL)
			then
				castTarget = creep
				castReason = "W-带线"
				return BOT_ACTION_DESIRE_HIGH, castTarget, castReason
			end
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if
			Fu.IsRoshan(botTarget)
			and not Fu.IsDisabled(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and Fu.IsAttacking(bot)
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, castRange) and Fu.IsAttacking(bot) then
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end
	if
		(#nearbyEnemies > 0 or bot:WasRecentlyDamagedByAnyHero(3.0))
		and (bot:GetActiveMode() ~= BOT_MODE_RETREAT or #nearbyAllies >= 2)
		and #enemiesInRange >= 1
		and botLevel >= 12
		and missingHealth > damage
	then
		for _, enemyHero in pairs(enemiesInRange) do
			if
				Fu.IsValid(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
			then
				castTarget = enemyHero
				castReason = "W-通用情况"
				return BOT_ACTION_DESIRE_HIGH, castTarget, castReason
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderQ()
	if not enfeebleAbility:IsFullyCastable() then
		return 0
	end
	local abilityLevel = enfeebleAbility:GetLevel()
	local castRange = enfeebleAbility:GetCastRange()
	local radius = 600
	local castPoint = enfeebleAbility:GetCastPoint()
	local manaCost = enfeebleAbility:GetManaCost()
	local damage = 0
	local damageType = DAMAGE_TYPE_MAGICAL
	local enemiesInRange = Fu.GetAroundEnemyHeroList(castRange)
	local enemiesInRangeWide = Fu.GetAroundEnemyHeroList(castRange + 200)
	local castTarget = nil
	local castReason = nil
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidHero(botTarget)
			and not botTarget:HasModifier("modifier_bane_enfeeble")
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.CanCastOnTargetAdvanced(botTarget)
			and Fu.IsInRange(botTarget, bot, castRange + 50)
		then
			if abilityLevel >= 2 or mpRatio > 0.6 then
				castTarget = botTarget
				castReason = "Q-攻击" .. Fu.Chat.GetNormName(castTarget)
				return BOT_ACTION_DESIRE_HIGH, castTarget, castReason
			end
		end
		for _, enemyHero in pairs(enemiesInRange) do
			if
				Fu.IsValid(enemyHero)
				and not enemyHero:HasModifier("modifier_bane_enfeeble")
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
			then
				castTarget = enemyHero
				castReason = "Q-虚弱其他人" .. Fu.Chat.GetNormName(castTarget)
				return BOT_ACTION_DESIRE_HIGH, castTarget, castReason
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderR()
	if not fiendsGripAbility:IsFullyCastable() then
		return 0
	end
	local abilityLevel = fiendsGripAbility:GetLevel()
	local castRange = fiendsGripAbility:GetCastRange()
	local radius = 600
	local castPoint = fiendsGripAbility:GetCastPoint()
	local manaCost = fiendsGripAbility:GetManaCost()
	local damage = fiendsGripAbility:GetSpecialValueInt("fiend_grip_damage") * 6
	local damageType = DAMAGE_TYPE_PURE
	local enemiesInRange = Fu.GetAroundEnemyHeroList(castRange)
	local enemiesInRangeWide = Fu.GetAroundEnemyHeroList(castRange + 200)
	local castTarget = nil
	local castReason = nil
	-- fix: Fiend's Grip has DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES / SPELL_IMMUNITY_ENEMIES_YES (game
	-- data), so the three target checks in this function now accept magic-immune heroes.
	for _, enemyHero in pairs(enemiesInRangeWide) do
		if Fu.IsValid(enemyHero) and Fu.CanCastOnMagicImmune(enemyHero) and Fu.CanCastOnTargetAdvanced(enemyHero) then
			if enemyHero:IsChanneling() then
				castTarget = enemyHero
				castReason = "R-打断" .. Fu.Chat.GetNormName(castTarget)
				return BOT_ACTION_DESIRE_HIGH, castTarget, castReason
			end
			if Fu.IsInRange(bot, enemyHero, castRange + 80) and Fu.CanKillTarget(enemyHero, damage, damageType) then
				castTarget = enemyHero
				castReason = "R-击杀" .. Fu.Chat.GetNormName(castTarget)
				return BOT_ACTION_DESIRE_HIGH, castTarget, castReason
			end
		end
	end
	-- fix: removed "Brain Sap castable and mana for both -> no Grip". Brain Sap is considered first
	-- anyway; when it declined (e.g. its level <= 7 / mana < 72% early exit), this block also
	-- blocked Grip, so a level-6/7 gank never used the ultimate.
	if Fu.IsInTeamFight(bot, 1200) then
		local bestTarget = nil
		local maxEstimatedDamage = 0
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValid(enemyHero)
				and Fu.CanCastOnMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
				and not Fu.IsDisabled(enemyHero)
			then
				local estimatedDamage = enemyHero:GetEstimatedDamageToTarget(true, bot, 6.0, DAMAGE_TYPE_ALL)
				if estimatedDamage > maxEstimatedDamage then
					maxEstimatedDamage = estimatedDamage
					bestTarget = enemyHero
				end
			end
		end
		if bestTarget ~= nil and Fu.IsInRange(bot, bestTarget, castRange + 100) then
			castTarget = bestTarget
			castReason = "R-团战控制" .. Fu.Chat.GetNormName(castTarget)
			return BOT_ACTION_DESIRE_HIGH, castTarget, castReason
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidHero(botTarget)
			and Fu.IsInRange(botTarget, bot, castRange + 50)
			and Fu.CanCastOnMagicImmune(botTarget)
			and Fu.CanCastOnTargetAdvanced(botTarget)
		then
			castTarget = botTarget
			castReason = "R-攻击" .. Fu.Chat.GetNormName(castTarget)
			return BOT_ACTION_DESIRE_HIGH, castTarget, castReason
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
return X
