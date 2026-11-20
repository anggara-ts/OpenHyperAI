-- Juggernaut: skill build, item build, and ability use for this hero.
-- Accidental globals made file-local (#13): every bot shares one Lua state, so these were shared.
local botTarget
local X = {}
local bot = GetBot()
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local AbilityContext = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local Minion = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local sTalentList = Fu.Skill.GetTalentList(bot)
local sAbilityList = Fu.Skill.GetAbilityList(bot)
local sRole = Fu.Item.GetRoleItemsBuyList(bot)
local tTalentTreeList = { ["t25"] = { 0, 10 }, ["t20"] = { 0, 10 }, ["t15"] = { 10, 0 }, ["t10"] = { 0, 10 } }
-- Blade Fury maxed first, Blade Dance second, Healing Ward last after one early point (86% of carry
-- Juggernauts max the Ward last, at 15). Stratz, week of 12-18 Nov 2026 (7.41f), pos 1, 387,059 matches.
local tAllAbilityBuildList = { { 1, 3, 1, 2, 1, 6, 1, 3, 3, 3, 6, 2, 2, 2, 6 } }
local nAbilityBuildList = Fu.Skill.GetRandomBuild(tAllAbilityBuildList)
local nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList)
local sRoleItemsBuyList = {}
sRoleItemsBuyList["pos_1"] = {
	"item_tango",
	"item_double_branches",
	"item_slippers",
	"item_circlet",
	"item_quelling_blade",
	"item_wraith_band",
	"item_magic_wand",
	"item_power_treads",
	"item_bfury",
	"item_manta",
	"item_ultimate_scepter",
	"item_skadi",
	"item_aghanims_shard",
	"item_basher",
	"item_butterfly",
	"item_moon_shard",
	"item_abyssal_blade",
	"item_travel_boots_2",
	"item_ultimate_scepter_2",
}
sRoleItemsBuyList["pos_2"] = sRoleItemsBuyList["pos_1"]
sRoleItemsBuyList["pos_4"] = sRoleItemsBuyList["pos_1"]
sRoleItemsBuyList["pos_5"] = sRoleItemsBuyList["pos_1"]
sRoleItemsBuyList["pos_3"] = sRoleItemsBuyList["pos_1"]
X["sBuyList"] = sRoleItemsBuyList[sRole]
X["sSellList"] = { "item_black_king_bar", "item_quelling_blade" }
if Fu.Role.IsPvNMode() or Fu.Role.IsAllShadow() then
	X["sBuyList"], X["sSellList"] = { "PvN_melee_carry" }, { "item_power_treads", "item_quelling_blade" }
end
nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"] =
	Fu.SetUserHeroInit(nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"])
X["sSkillList"] = Fu.Skill.GetSkillList(sAbilityList, nAbilityBuildList, sTalentList, nTalentBuildList)
X["bDeafaultAbility"] = false
X["bDeafaultItem"] = false
function X.MinionThink(minionUnit)
	if Minion.IsValidUnit(minionUnit) then
		if minionUnit:GetUnitName() == "npc_dota_juggernaut_healing_ward" then
			Minion.HealingWardThink(minionUnit)
		else
			Minion.IllusionThink(minionUnit)
		end
	end
end
local bladeFuryAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[1]), "sAbilityList[1]", "juggernaut")
local healingWardAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[2]), "sAbilityList[2]", "juggernaut")
local bladeDanceAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[3]), "sAbilityList[3]", "juggernaut")
local omnislashAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[6]), "sAbilityList[6]", "juggernaut")
local talent2 = SafeAbility(bot:GetAbilityByName(sTalentList[2]), "sTalentList[2]", "juggernaut")
local talent6 = SafeAbility(bot:GetAbilityByName(sTalentList[6]), "sTalentList[6]", "juggernaut")
local bladeFuryDesire
local healingWardDesire, healingWardLocation
local bladeDanceDesire, bladeDanceTarget
local omnislashDesire, omnislashTarget
local botLevel, mpRatio, hpRatio, nearbyEnemies, nearbyAllies
function X.SkillsComplement()
	if Fu.CanNotUseAbility(bot) or bot:IsInvisible() then
		return
	end
	local context = AbilityContext.Build(bot)
	botLevel = context.level
	mpRatio = context.mp
	hpRatio = context.hp
	botTarget = context.target
	nearbyEnemies = context.enemies
	nearbyAllies = context.allies
	omnislashDesire, omnislashTarget = X.ConsiderR()
	if omnislashDesire > 0 then
		Fu.SetQueuePtToINT(bot, true)
		bot:ActionQueue_UseAbilityOnEntity(omnislashAbility, omnislashTarget)
		return
	end
	bladeFuryDesire = X.ConsiderQ()
	if bladeFuryDesire > 0 then
		Fu.SetQueuePtToINT(bot, true)
		bot:ActionQueue_UseAbility(bladeFuryAbility)
		return
	end
	healingWardDesire, healingWardLocation = X.ConsiderW()
	if healingWardDesire > 0 then
		Fu.SetQueuePtToINT(bot, true)
		bot:ActionQueue_UseAbilityOnLocation(healingWardAbility, healingWardLocation)
		return
	end
end
function X.ConsiderQ()
	if
		not bladeFuryAbility:IsFullyCastable()
		or bot:HasModifier("modifier_juggernaut_blade_fury")
		or bot:HasModifier("modifier_juggernaut_omnislash")
	then
		return 0
	end
	local abilityLevel = bladeFuryAbility:GetLevel()
	local creepSearchRadius = bladeFuryAbility:GetSpecialValueInt("blade_fury_radius")
	local radius = bladeFuryAbility:GetSpecialValueInt("blade_fury_radius")
	local castPoint = bladeFuryAbility:GetCastPoint()
	local manaCost = bladeFuryAbility:GetManaCost()
	local damage = 0
	local damageType = DAMAGE_TYPE_MAGICAL
	local enemiesInRange = Fu.GetAroundEnemyHeroList(radius)
	local enemiesNearby = Fu.GetAroundEnemyHeroList(radius + 200)
	local castTarget = nil
	local debugText = nil
	if hpRatio < 0.85 and Fu.IsStunProjectileIncoming(bot, 1000) then
		castTarget = bot
		debugText = "Q-防御眩晕弹道"
		return BOT_ACTION_DESIRE_HIGH, debugText
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidHero(botTarget)
			and Fu.IsInRange(botTarget, bot, radius)
			and Fu.CanCastOnNonMagicImmune(botTarget)
		then
			castTarget = botTarget
			debugText = "Q-攻击:" .. Fu.Chat.GetNormName(castTarget)
			return BOT_ACTION_DESIRE_HIGH, debugText
		end
	end
	if Fu.IsInTeamFight(bot, 1000) then
		local enemyCount = 0
		for _, enemyHero in pairs(enemiesInRange) do
			if Fu.IsValidHero(enemyHero) and Fu.CanCastOnNonMagicImmune(enemyHero) then
				enemyCount = enemyCount + 1
			end
		end
		if enemyCount >= 2 then
			castTarget = botTarget
			debugText = "Q-团战AOE" .. enemyCount
			return BOT_ACTION_DESIRE_HIGH, debugText
		end
	end
	if Fu.IsRetreating(bot) then
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValid(enemyHero)
				and Fu.IsInRange(bot, enemyHero, 1200)
				and bot:WasRecentlyDamagedByHero(enemyHero, 2.0)
				and Fu.CanCastOnMagicImmune(enemyHero)
				and (
					Fu.IsInRange(bot, enemyHero, radius - 120)
					or botLevel >= 9 and bot:GetCurrentMovementSpeed() < 220
				)
			then
				castTarget = enemyHero
				debugText = "Q-撤退" .. Fu.Chat.GetNormName(castTarget)
				return BOT_ACTION_DESIRE_HIGH, debugText
			end
		end
		if Fu.IsNotAttackProjectileIncoming(bot, 700) then
			castTarget = bot
			debugText = "Q-躲避" .. Fu.Chat.GetNormName(castTarget)
			return BOT_ACTION_DESIRE_HIGH, debugText
		end
	end
	if
		(Fu.IsPushing(bot) or Fu.IsDefending(bot) or Fu.IsFarming(bot))
		and Fu.IsAllowedToSpam(bot, manaCost * 0.32)
		and #nearbyAllies <= 2
		and Fu.IsItemAvailable("item_bfury") == nil
	then
		local laneCreeps = bot:GetNearbyLaneCreeps(creepSearchRadius, true)
		if
			(#laneCreeps >= 4 or #laneCreeps >= 3 and mpRatio > 0.82)
			and not laneCreeps[1]:HasModifier("modifier_fountain_glyph")
		then
			castTarget = laneCreeps[1] -- was the undefined global creep (nil); label only
			debugText = "Q-带线AOE" .. #laneCreeps
			return BOT_ACTION_DESIRE_HIGH, debugText
		end
	end
	if
		Fu.IsFarming(bot)
		and DotaTime() > 6 * 60
		and Fu.IsAllowedToSpam(bot, manaCost * 0.25)
		and Fu.IsItemAvailable("item_bfury") == nil
	then
		local neutralCreeps = bot:GetNearbyNeutralCreeps(radius)
		if #neutralCreeps >= 4 and Fu.IsValid(botTarget) then
			castTarget = botTarget
			debugText = "Q-打野AOE" .. #neutralCreeps
			return BOT_ACTION_DESIRE_HIGH, debugText
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderW()
	if not healingWardAbility:IsFullyCastable() then
		return 0
	end
	local abilityLevel = healingWardAbility:GetLevel()
	local castRange = healingWardAbility:GetCastRange()
	local radius = 600
	local castPoint = healingWardAbility:GetCastPoint()
	local manaCost = healingWardAbility:GetManaCost()
	local damage = healingWardAbility:GetSpecialValueInt("dam")
	local damageType = DAMAGE_TYPE_MAGICAL
	local enemiesInRange = Fu.GetAroundEnemyHeroList(castRange)
	local enemiesNearby = Fu.GetAroundEnemyHeroList(castRange + 200)
	local castLocation = nil
	local debugText = nil
	if Fu.IsInTeamFight(bot, 1200) then
		local allyMissingHealth = 0
		for _, allyHero in pairs(nearbyAllies) do
			if Fu.IsValidHero(allyHero) and Fu.IsInRange(bot, allyHero, 1000) then
				allyMissingHealth = allyMissingHealth + 1 - allyHero:GetHealth() / allyHero:GetMaxHealth()
			end
		end
		if allyMissingHealth >= 0.6 then
			castLocation = Fu.GetFaceTowardDistanceLocation(bot, 16)
			debugText = "W-团战辅助"
			return BOT_ACTION_DESIRE_HIGH, castLocation, debugText
		end
	end
	if Fu.IsGoingOnSomeone(bot) and hpRatio < 0.6 then
		if Fu.IsValidHero(botTarget) and Fu.IsInRange(bot, botTarget, 900) and Fu.CanCastOnMagicImmune(botTarget) then
			castLocation = Fu.GetFaceTowardDistanceLocation(bot, 16)
			debugText = "W-辅助进攻:" .. Fu.Chat.GetNormName(botTarget)
			return BOT_ACTION_DESIRE_HIGH, castLocation, debugText
		end
	end
	if Fu.IsRetreating(bot) and hpRatio < 0.5 and bot:DistanceFromFountain() > 800 then
		castLocation = Fu.GetFaceTowardDistanceLocation(bot, 16)
		debugText = "W-撤退回血"
		return BOT_ACTION_DESIRE_HIGH, castLocation, debugText
	end
	return BOT_ACTION_DESIRE_NONE
end
-- Omnislash pierces spell immunity (game files: SPELL_IMMUNITY_ENEMIES_YES,
-- FLAG_MAGIC_IMMUNE_ENEMIES), so ConsiderR checks CanCastOnMagicImmune; it was held
-- on any target under BKB. (Swift Slash was removed in 7.42.)
function X.ConsiderR()
	if
		not omnislashAbility:IsFullyCastable()
		or bot:HasModifier("modifier_juggernaut_blade_fury")
		or bot:HasModifier("modifier_juggernaut_omnislash")
	then
		return 0
	end
	local abilityLevel = omnislashAbility:GetLevel()
	local castRange = omnislashAbility:GetCastRange()
	local radius = 600
	local castPoint = omnislashAbility:GetCastPoint()
	local manaCost = omnislashAbility:GetManaCost()
	local damage = omnislashAbility:GetSpecialValueInt("damage")
	local damageType = DAMAGE_TYPE_MAGICAL
	local enemiesInRange = Fu.GetAroundEnemyHeroList(castRange + 50)
	local enemiesNearby = Fu.GetAroundEnemyHeroList(castRange + 200)
	local castTarget = nil
	local debugText = nil
	if Fu.IsStunProjectileIncoming(bot, 1000) then
		for _, enemyHero in pairs(enemiesNearby) do
			if
				Fu.IsValid(enemyHero)
				and Fu.CanCastOnMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
			then
				castTarget = enemyHero
				debugText = "R-防御:" .. Fu.Chat.GetNormName(castTarget)
				return BOT_ACTION_DESIRE_HIGH, castTarget, debugText
			end
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidHero(botTarget)
			and Fu.IsInRange(botTarget, bot, 900)
			and (botTarget:GetHealth() > bot:GetAttackDamage() * 4 or hpRatio < 0.2 or #enemiesNearby >= 2)
		then
			for _, enemyHero in pairs(enemiesInRange) do
				if
					Fu.IsValid(enemyHero)
					and Fu.CanCastOnMagicImmune(enemyHero)
					and Fu.CanCastOnTargetAdvanced(enemyHero)
				then
					castTarget = enemyHero
					debugText = "R-攻击:" .. Fu.Chat.GetNormName(castTarget)
					return BOT_ACTION_DESIRE_HIGH, castTarget, debugText
				end
			end
		end
	end
	if Fu.IsRetreating(bot) then
		for _, enemyHero in pairs(enemiesInRange) do
			if
				Fu.IsValid(enemyHero)
				and bot:WasRecentlyDamagedByHero(enemyHero, 5.0)
				and Fu.CanCastOnMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
			then
				castTarget = enemyHero
				debugText = "R-撤退" .. Fu.Chat.GetNormName(castTarget)
				return BOT_ACTION_DESIRE_HIGH, castTarget, debugText
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
return X
