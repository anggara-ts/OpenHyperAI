-- Slardar: skill build, item build, and ability use for this hero.
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
local tTalentTreeList = { ["t25"] = { 0, 10 }, ["t20"] = { 0, 10 }, ["t15"] = { 0, 10 }, ["t10"] = { 10, 0 } }
local tAllAbilityBuildList = { { 2, 3, 2, 1, 2, 6, 2, 1, 1, 1, 6, 3, 3, 3, 6 } }
local nAbilityBuildList = Fu.Skill.GetRandomBuild(tAllAbilityBuildList)
local nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList)
local sRoleItemsBuyList = {}
-- Stratz 7.41f, week of 9 Nov 2026: pos 3, 105,050 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_3"] = {
	"item_tango",
	"item_gauntlets",
	"item_quelling_blade",
	"item_double_branches",
	"item_circlet",
	"item_bracer",
	"item_magic_wand",
	"item_power_treads",
	"item_blink",
	"item_echo_sabre",
	"item_black_king_bar",
	"item_ultimate_scepter",
	"item_assault",
	"item_overwhelming_blink",
	"item_ultimate_scepter_2",
	"item_nullifier",
	"item_aghanims_shard",
	"item_moon_shard",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 1, 2,418 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_1"] = {
	"item_tango",
	"item_quelling_blade",
	"item_double_branches",
	"item_gauntlets",
	"item_circlet",
	"item_bracer",
	"item_magic_wand",
	"item_power_treads",
	"item_blink",
	"item_echo_sabre",
	"item_aghanims_shard",
	"item_black_king_bar",
	"item_harpoon",
	"item_ultimate_scepter",
	"item_assault",
	"item_ultimate_scepter_2",
	"item_travel_boots",
	"item_swift_blink",
	"item_desolator",
	"item_moon_shard",
	"item_travel_boots_2",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 2, 10,353 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_2"] = {
	"item_tango",
	"item_double_branches",
	"item_quelling_blade",
	"item_gauntlets",
	"item_circlet",
	"item_bracer",
	"item_magic_wand",
	"item_power_treads",
	"item_blink",
	"item_echo_sabre",
	"item_black_king_bar",
	"item_harpoon",
	"item_ultimate_scepter",
	"item_assault",
	"item_overwhelming_blink",
	"item_ultimate_scepter_2",
	"item_nullifier",
	"item_aghanims_shard",
	"item_moon_shard",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 4, 3,401 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_4"] = {
	"item_tango",
	"item_gauntlets",
	"item_branches",
	"item_quelling_blade",
	"item_magic_stick",
	"item_bracer",
	"item_magic_wand",
	"item_power_treads",
	"item_blink",
	"item_echo_sabre",
	"item_aghanims_shard",
	"item_black_king_bar",
	"item_ultimate_scepter",
	"item_assault",
	"item_ultimate_scepter_2",
	"item_heart",
	"item_overwhelming_blink",
	"item_moon_shard",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 5, 1,227 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_5"] = {
	"item_tango",
	"item_branches",
	"item_gauntlets",
	"item_magic_stick",
	"item_bracer",
	"item_magic_wand",
	"item_power_treads",
	"item_blink",
	"item_aghanims_shard",
	"item_black_king_bar",
	"item_assault",
	"item_travel_boots",
	"item_moon_shard",
	"item_heart",
	"item_ultimate_scepter_2",
	"item_travel_boots_2",
}
X["sBuyList"] = sRoleItemsBuyList[sRole]
X["sSellList"] = { "item_power_treads", "item_quelling_blade" }
if Fu.Role.IsPvNMode() or Fu.Role.IsAllShadow() then
	X["sBuyList"], X["sSellList"] = { "PvN_tank" }, { "item_power_treads", "item_quelling_blade" }
end
nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"] =
	Fu.SetUserHeroInit(nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"])
X["sSkillList"] = Fu.Skill.GetSkillList(sAbilityList, nAbilityBuildList, sTalentList, nTalentBuildList)
X["bDeafaultAbility"] = false
X["bDeafaultItem"] = false
function X.MinionThink(minionUnit)
	Minion.MinionThink(minionUnit)
end
local guardianSprintAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[1]), "sAbilityList[1]", "slardar")
local slithereenCrushAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[2]), "sAbilityList[2]", "slardar")
local bashOfTheDeepAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[3]), "sAbilityList[3]", "slardar")
local corrosiveHazeAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[6]), "sAbilityList[6]", "slardar")
local talent2 = SafeAbility(bot:GetAbilityByName(sTalentList[2]), "sTalentList[2]", "slardar")
local talent6 = SafeAbility(bot:GetAbilityByName(sTalentList[6]), "sTalentList[6]", "slardar")
local guardianSprintDesire
local crushDesire
local bashDesire, bashTarget
local hazeDesire, hazeTarget
local botLevel, mpRatio, nearbyEnemies, nearbyAllies
function X.SkillsComplement()
	if Fu.CanNotUseAbility(bot) or bot:IsInvisible() then
		return
	end
	local context = AbilityContext.Build(bot)
	botLevel = context.level
	mpRatio = context.mp
	botTarget = context.target
	nearbyEnemies = context.enemies
	nearbyAllies = context.allies
	crushDesire = X.ConsiderW()
	if crushDesire > 0 then
		Fu.SetQueuePtToINT(bot, true)
		bot:ActionQueue_UseAbility(slithereenCrushAbility)
		return
	end
	hazeDesire, hazeTarget = X.ConsiderR()
	if hazeDesire > 0 then
		Fu.SetQueuePtToINT(bot, false)
		bot:ActionQueue_UseAbilityOnEntity(corrosiveHazeAbility, hazeTarget)
		return
	end
	guardianSprintDesire = X.ConsiderQ()
	if guardianSprintDesire > 0 then
		Fu.SetQueuePtToINT(bot, false)
		bot:ActionQueue_UseAbility(guardianSprintAbility)
		return
	end
end
function X.ConsiderQ()
	if not guardianSprintAbility:IsFullyCastable() then
		return 0
	end
	local abilityLevel = guardianSprintAbility:GetLevel()
	local castRange = guardianSprintAbility:GetCastRange()
	local radius = 600
	local castPoint = guardianSprintAbility:GetCastPoint()
	local manaCost = guardianSprintAbility:GetManaCost()
	local damage = 0
	local damageType = DAMAGE_TYPE_MAGICAL
	local enemiesInRange = Fu.GetAroundEnemyHeroList(castRange)
	local enemiesInBonusRange = Fu.GetAroundEnemyHeroList(castRange + 200)
	local castTarget = nil
	local castLog = nil
	if Fu.IsGoingOnSomeone(bot) and Fu.IsRunning(bot) then
		if
			Fu.IsValidHero(botTarget)
			and Fu.IsInRange(bot, botTarget, 1600)
			and not Fu.IsInRange(bot, botTarget, 200)
		then
			castTarget = botTarget
			castLog = "Q-进攻:" .. Fu.Chat.GetNormName(castTarget)
			return BOT_ACTION_DESIRE_HIGH, castTarget, castLog
		end
	end
	if Fu.IsRetreating(bot) and Fu.IsRunning(bot) and bot:WasRecentlyDamagedByAnyHero(5.0) and #nearbyEnemies >= 1 then
		castTarget = bot
		castLog = "Q-撤退了"
		return BOT_ACTION_DESIRE_HIGH, castTarget, castLog
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderW()
	if not slithereenCrushAbility:IsFullyCastable() then
		return 0
	end
	local abilityLevel = slithereenCrushAbility:GetLevel()
	local crushRadius = slithereenCrushAbility:GetSpecialValueInt("crush_radius")
	local radius = slithereenCrushAbility:GetSpecialValueInt("crush_radius")
	local castPoint = slithereenCrushAbility:GetCastPoint()
	local manaCost = slithereenCrushAbility:GetManaCost()
	-- datafeed: Slithereen Crush deals physical damage (1) from "crush_damage" (60/140/220/300); it has no
	-- AbilityDamage (read 0) and was checked as magical.
	local damage = slithereenCrushAbility:GetSpecialValueInt("crush_damage")
	local damageType = DAMAGE_TYPE_PHYSICAL
	local enemiesInRange = Fu.GetAroundEnemyHeroList(crushRadius - 30)
	local enemiesInInnerRange = Fu.GetAroundEnemyHeroList(crushRadius - 100)
	local castTarget = nil
	local castLog = nil
	for _, enemyHero in pairs(enemiesInRange) do
		if
			Fu.IsValid(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and (Fu.CanKillTarget(enemyHero, damage, damageType) or enemyHero:IsChanneling())
		then
			castTarget = enemyHero
			castLog = "W-击杀打断" .. Fu.Chat.GetNormName(castTarget)
			return BOT_ACTION_DESIRE_HIGH, castTarget, castLog
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidHero(botTarget)
			and Fu.IsInRange(botTarget, bot, radius - 99)
			-- Review fix: Crush does not pierce spell immunity (game data SPELL_IMMUNITY_ENEMIES_NO),
			-- so do not waste it on a BKB'd target.
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and not Fu.IsDisabled(botTarget)
		then
			castTarget = botTarget
			castLog = "W-攻击" .. Fu.Chat.GetNormName(castTarget)
			return BOT_ACTION_DESIRE_HIGH, castTarget, castLog
		end
	end
	if Fu.IsInTeamFight(bot, 1000) then
		local hitCount = 0
		for _, enemyHero in pairs(enemiesInInnerRange) do
			if Fu.IsValidHero(enemyHero) and Fu.CanCastOnNonMagicImmune(enemyHero) then
				hitCount = hitCount + 1
			end
		end
		if hitCount >= 2 then
			castTarget = botTarget
			castLog = "W-团战AOE" .. hitCount
			return BOT_ACTION_DESIRE_HIGH, castTarget, castLog
		end
	end
	if Fu.IsRetreating(bot) then
		for _, enemyHero in pairs(enemiesInRange) do
			if
				Fu.IsValid(enemyHero)
				and bot:WasRecentlyDamagedByHero(enemyHero, 5.0)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and not Fu.IsDisabled(enemyHero)
				and not enemyHero:IsDisarmed()
			then
				castTarget = enemyHero
				castLog = "W-撤退" .. Fu.Chat.GetNormName(castTarget)
				return BOT_ACTION_DESIRE_HIGH, castTarget, castLog
			end
		end
	end
	if
		(Fu.IsPushing(bot) or Fu.IsDefending(bot) or Fu.IsFarming(bot))
		and Fu.IsAllowedToSpam(bot, manaCost)
		and #nearbyAllies <= 2
	then
		local nearbyLaneCreeps = bot:GetNearbyLaneCreeps(crushRadius, true)
		if
			(#nearbyLaneCreeps >= 4 or #nearbyLaneCreeps >= 3 and mpRatio > 0.82)
			and not nearbyLaneCreeps[1]:HasModifier("modifier_fountain_glyph")
		then
			castTarget = nearbyLaneCreeps[1] -- was the undefined global creep (nil); Crush is no-target
			castLog = "W-带线AOE" .. #nearbyLaneCreeps
			return BOT_ACTION_DESIRE_HIGH, castTarget, castLog
		end
	end
	if Fu.IsFarming(bot) and DotaTime() > 6 * 60 and Fu.IsAllowedToSpam(bot, manaCost) then
		local nearbyNeutrals = bot:GetNearbyNeutralCreeps(radius)
		if #nearbyNeutrals >= 3 and Fu.IsValid(botTarget) then
			castTarget = botTarget
			castLog = "W-打野AOE" .. #nearbyNeutrals
			return BOT_ACTION_DESIRE_HIGH, castTarget, castLog
		end
	end
	if bot:GetActiveMode() == BOT_MODE_ROSHAN and bot:GetMana() >= 400 then
		local attackTarget = bot:GetAttackTarget()
		if
			Fu.IsRoshan(attackTarget)
			and not Fu.IsDisabled(attackTarget)
			and not attackTarget:IsDisarmed()
			and Fu.IsInRange(attackTarget, bot, crushRadius)
		then
			castTarget = botTarget
			castLog = "W-打肉山"
			return BOT_ACTION_DESIRE_HIGH, castTarget, castLog
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, crushRadius) and Fu.IsAttacking(bot) then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderR()
	if not corrosiveHazeAbility:IsFullyCastable() then
		return 0
	end
	local abilityLevel = corrosiveHazeAbility:GetLevel()
	local castRange = corrosiveHazeAbility:GetCastRange()
	local radius = 600
	local castPoint = corrosiveHazeAbility:GetCastPoint()
	local manaCost = corrosiveHazeAbility:GetManaCost()
	local damage = 0
	local damageType = DAMAGE_TYPE_MAGICAL
	local enemiesInRange = Fu.GetAroundEnemyHeroList(castRange)
	local enemiesInBonusRange = Fu.GetAroundEnemyHeroList(castRange + 200)
	local castTarget = nil
	local castLog = nil
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidHero(botTarget)
			and Fu.IsInRange(botTarget, bot, castRange)
			-- Review fix: Corrosive Haze pierces spell immunity (game data SPELL_IMMUNITY_ENEMIES_YES,
			-- MAGIC_IMMUNE_ENEMIES flag); it was skipped on BKB carries, the targets it matters most on.
			and Fu.CanCastOnMagicImmune(botTarget)
			and Fu.CanCastOnTargetAdvanced(botTarget)
			and not botTarget:HasModifier("modifier_slardar_amplify_damage")
		then
			castTarget = botTarget
			castLog = "R-攻击:" .. Fu.Chat.GetNormName(castTarget)
			return BOT_ACTION_DESIRE_HIGH, castTarget, castLog
		end
	end
	if Fu.IsInTeamFight(bot, 1200) then
		local weakestArmorTarget = nil
		local lowestArmor = 100000
		for _, enemyHero in pairs(enemiesInBonusRange) do
			if
				Fu.IsValid(enemyHero)
				and not enemyHero:HasModifier("modifier_slardar_amplify_damage")
				and Fu.CanCastOnMagicImmune(enemyHero) -- Review fix: Haze pierces spell immunity (see above)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
			then
				local armor = enemyHero:GetArmor()
				if armor < lowestArmor then
					lowestArmor = armor
					weakestArmorTarget = enemyHero
				end
			end
		end
		if weakestArmorTarget ~= nil then
			castTarget = weakestArmorTarget
			castLog = "R-团战" .. Fu.Chat.GetNormName(castTarget)
			return BOT_ACTION_DESIRE_HIGH, castTarget, castLog
		end
	end
	if Fu.IsFarming(bot) and abilityLevel >= 2 and Fu.IsAllowedToSpam(bot, manaCost) then
		local attackTarget = bot:GetAttackTarget()
		if
			Fu.IsValid(attackTarget)
			and Fu.IsInRange(bot, attackTarget, castRange)
			and not attackTarget:HasModifier("modifier_slardar_amplify_damage")
			and not Fu.CanKillTarget(attackTarget, bot:GetAttackDamage() * 3, DAMAGE_TYPE_PHYSICAL)
		then
			castTarget = attackTarget
			castLog = "R-打野"
			return BOT_ACTION_DESIRE_HIGH, castTarget, castLog
		end
	end
	if bot:GetActiveMode() == BOT_MODE_ROSHAN then
		if
			Fu.IsRoshan(botTarget)
			and Fu.IsInRange(botTarget, bot, castRange)
			and not botTarget:HasModifier("modifier_slardar_amplify_damage")
		then
			castTarget = botTarget
			castLog = "R-肉山"
			return BOT_ACTION_DESIRE_HIGH, castTarget, castLog
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, castRange) and Fu.IsAttacking(bot) then
			return BOT_ACTION_DESIRE_HIGH, botTarget, ""
		end
	end
	if botLevel >= 12 and (bot:GetActiveMode() ~= BOT_MODE_RETREAT or #nearbyAllies >= 3) and #enemiesInRange >= 1 then
		for _, enemyHero in pairs(enemiesInRange) do
			if
				Fu.IsValid(enemyHero)
				and not enemyHero:HasModifier("modifier_slardar_amplify_damage")
				and Fu.CanCastOnMagicImmune(enemyHero) -- Review fix: Haze pierces spell immunity (see above)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
			then
				castTarget = enemyHero
				castLog = "R-标记"
				return BOT_ACTION_DESIRE_HIGH, castTarget, castLog
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
return X
