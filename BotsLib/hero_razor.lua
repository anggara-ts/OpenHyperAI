-- Razor: skill build, item build, and ability use for this hero.
local X = {}
local bot = GetBot()
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local AbilityContext = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local Minion = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local sTalentList = Fu.Skill.GetTalentList(bot)
local sAbilityList = Fu.Skill.GetAbilityList(bot)
local sRole = Fu.Item.GetRoleItemsBuyList(bot)
local tTalentTreeList = {
	{ ["t25"] = { 0, 10 }, ["t20"] = { 10, 0 }, ["t15"] = { 0, 10 }, ["t10"] = { 0, 10 } },
	{ ["t25"] = { 10, 0 }, ["t20"] = { 10, 0 }, ["t15"] = { 10, 0 }, ["t10"] = { 0, 10 } },
}
local tAllAbilityBuildList =
	{ { 2, 1, 2, 1, 2, 6, 2, 3, 1, 1, 6, 3, 3, 3, 6 }, { 1, 2, 2, 1, 1, 6, 1, 3, 3, 3, 6, 3, 2, 2, 6 } }
local nAbilityBuildList
local nTalentBuildList
if sRole == "pos_1" or sRole == "pos_2" then
	nAbilityBuildList = tAllAbilityBuildList[1]
	nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList[1])
else
	nAbilityBuildList = tAllAbilityBuildList[2]
	nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList[2])
end
local sRoleItemsBuyList = {}
-- Stratz 7.41f, week of 9 Nov 2026: pos 1, 19,922 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_1"] = {
	"item_tango",
	"item_double_branches",
	"item_circlet",
	"item_faerie_fire",
	"item_slippers",
	"item_wraith_band",
	"item_magic_wand",
	"item_falcon_blade",
	"item_power_treads",
	"item_sange_and_yasha",
	"item_black_king_bar",
	"item_satanic",
	"item_butterfly",
	"item_ultimate_scepter",
	"item_aghanims_shard",
	"item_ultimate_scepter_2",
	"item_swift_blink",
	"item_moon_shard",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 2, 31,247 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_2"] = {
	"item_tango",
	"item_double_branches",
	"item_circlet",
	"item_faerie_fire",
	"item_slippers",
	"item_wraith_band",
	"item_magic_wand",
	"item_power_treads",
	"item_sange_and_yasha",
	"item_black_king_bar",
	"item_aghanims_shard",
	"item_ultimate_scepter",
	"item_satanic",
	"item_ultimate_scepter_2",
	"item_blink",
	"item_shivas_guard",
	"item_moon_shard",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 3, 68,347 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_3"] = {
	"item_tango",
	"item_double_branches",
	"item_circlet",
	"item_slippers",
	"item_faerie_fire",
	"item_wraith_band",
	"item_magic_wand",
	"item_falcon_blade",
	"item_power_treads",
	"item_sange_and_yasha",
	"item_black_king_bar",
	"item_aghanims_shard",
	"item_ultimate_scepter",
	"item_satanic",
	"item_ultimate_scepter_2",
	"item_consecrated_wraps",
	"item_cyclone",
	"item_moon_shard",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 4, 4,478 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_4"] = {
	"item_tango",
	"item_blood_grenade",
	"item_double_branches",
	"item_magic_stick",
	"item_faerie_fire",
	"item_magic_wand",
	"item_power_treads",
	"item_cyclone",
	"item_sange_and_yasha",
	"item_black_king_bar",
	"item_aghanims_shard",
	"item_ultimate_scepter_2",
	"item_consecrated_wraps",
	"item_shivas_guard",
	"item_moon_shard",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 5, 2,551 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_5"] = {
	"item_tango",
	"item_blood_grenade",
	"item_double_branches",
	"item_magic_stick",
	"item_faerie_fire",
	"item_magic_wand",
	"item_power_treads",
	"item_cyclone",
	"item_sange_and_yasha",
	"item_black_king_bar",
	"item_aghanims_shard",
	"item_ultimate_scepter_2",
	"item_blade_mail",
	"item_consecrated_wraps",
	"item_moon_shard",
}
X["sBuyList"] = sRoleItemsBuyList[sRole]
X["sSellList"] = {
	"item_black_king_bar",
	"item_quelling_blade",
	-- Sold once the item before it is owned, to keep six slots (Util/item-builds/generate.js):
	"item_ultimate_scepter",
	"item_falcon_blade",
}
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
local plasmaFieldAbility, staticLinkAbility, eyeOfTheStormAbility
local plasmaFieldDesire
local staticLinkDesire, staticLinkTarget
local eyeOfTheStormDesire
local aetherRange = 0
local botTarget
local botLevel, reservedMana
function X.SkillsComplement()
	bot = GetBot()
	Fu.ConsiderForMkbDisassembleMask(bot)
	if Fu.CanNotUseAbility(bot) then
		return
	end
	plasmaFieldAbility = SafeAbility(bot:GetAbilityByName("razor_plasma_field"), "plasma_field", "razor")
	staticLinkAbility = SafeAbility(bot:GetAbilityByName("razor_static_link"), "static_link", "razor")
	eyeOfTheStormAbility = SafeAbility(bot:GetAbilityByName("razor_eye_of_the_storm"), "eye_of_the_storm", "razor")
	local context = AbilityContext.Build(bot)
	reservedMana = 300
	aetherRange = context.aetherRange
	botLevel = context.level
	botTarget = context.target
	plasmaFieldDesire = X.ConsiderQ()
	if plasmaFieldDesire > 0 then
		Fu.SetQueuePtToINT(bot, false)
		bot:ActionQueue_UseAbility(plasmaFieldAbility)
		return
	end
	staticLinkDesire, staticLinkTarget = X.ConsiderW()
	if staticLinkDesire > 0 then
		Fu.SetQueuePtToINT(bot, false)
		bot:ActionQueue_UseAbilityOnEntity(staticLinkAbility, staticLinkTarget)
		return
	end
	eyeOfTheStormDesire = X.ConsiderR()
	if eyeOfTheStormDesire > 0 then
		Fu.SetQueuePtToINT(bot, false)
		bot:ActionQueue_UseAbility(eyeOfTheStormAbility)
		return
	end
end
function X.ConsiderQ()
	if not plasmaFieldAbility:IsFullyCastable() then
		return 0
	end
	local abilityLevel = plasmaFieldAbility:GetLevel()
	-- datafeed: Plasma Field radius is 700; the old 777 counted enemies the field never reaches.
	local radius = plasmaFieldAbility:GetSpecialValueInt("radius")
	if radius <= 0 then
		radius = 700
	end
	local castPoint = plasmaFieldAbility:GetCastPoint()
	local manaCost = plasmaFieldAbility:GetManaCost()
	local damage = plasmaFieldAbility:GetAbilityDamage()
	local minDamage = plasmaFieldAbility:GetSpecialValueInt("damage_min")
	local maxDamage = plasmaFieldAbility:GetSpecialValueInt("damage_max")
	local damageType = DAMAGE_TYPE_MAGICAL
	local enemiesInRadius = Fu.GetNearbyHeroes(bot, radius, true, BOT_MODE_NONE)
	local enemiesNearby = Fu.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE)
	local alliesNearby = Fu.GetNearbyHeroes(bot, 1200, false, BOT_MODE_NONE)
	local botTarget = Fu.GetProperTarget(bot)
	for _, enemyHero in pairs(enemiesInRadius) do
		-- Plasma Field is SPELL_IMMUNITY_ENEMIES_NO (game files): a BKB'd hero is not hit, so it should
		-- not trigger the kill / retreat / fight casts.
		if Fu.IsValidHero(enemyHero) and Fu.CanCastOnNonMagicImmune(enemyHero) then
			local distance = GetUnitToUnitDistance(bot, enemyHero)
			local damage = RemapValClamped(distance, 0, radius, minDamage, maxDamage) * 2
			if Fu.WillMagicKillTarget(bot, enemyHero, damage, castPoint + distance / 636) then
				return BOT_ACTION_DESIRE_HIGH, "Q击杀" .. Fu.Chat.GetNormName(enemyHero)
			end
			if
				enemyHero:HasModifier("modifier_flask_healing")
				and Fu.GetModifierTime(enemyHero, "modifier_flask_healing") > 3.0
			then
				return BOT_ACTION_DESIRE_HIGH, "Q断药" .. Fu.Chat.GetNormName(enemyHero)
			end
			if
				Fu.IsRetreating(bot)
				and (
					bot:WasRecentlyDamagedByHero(enemyHero, 2.0)
					or bot:GetActiveModeDesire() > BOT_MODE_DESIRE_VERYHIGH
				)
			then
				return BOT_ACTION_DESIRE_HIGH, "Q撤退" .. Fu.Chat.GetNormName(enemyHero)
			end
			if Fu.IsGoingOnSomeone(bot) and Fu.IsValidHero(botTarget) and Fu.IsInRange(bot, botTarget, radius) then
				return BOT_ACTION_DESIRE_HIGH, "Q打架" .. Fu.Chat.GetNormName(botTarget)
			end
		end
	end
	if
		(Fu.IsPushing(bot) or Fu.IsDefending(bot) or Fu.IsFarming(bot))
		and #alliesNearby < 3
		and botLevel > 7
		and Fu.IsAllowedToSpam(bot, manaCost)
	then
		local killableCount = 0
		local creepCount = 0
		local laneCreeps = bot:GetNearbyLaneCreeps(radius + 100, true)
		for _, creep in pairs(laneCreeps) do
			if Fu.IsValid(creep) and not creep:HasModifier("modifier_fountain_glyph") then
				creepCount = creepCount + 1
				local distance = GetUnitToUnitDistance(bot, creep)
				local damage = RemapValClamped(distance, 0, radius, minDamage, maxDamage) * 2
				if Fu.WillKillTarget(creep, damage, damageType, distance / 636) then
					killableCount = killableCount + 1
				end
			end
		end
		if killableCount >= 3 or creepCount >= 5 then
			return BOT_ACTION_DESIRE_HIGH, "Q推进" .. creepCount
		end
	end
	if Fu.IsFarming(bot) and botLevel > 7 and bot:GetMana() > reservedMana then
		local neutralCreeps = bot:GetNearbyNeutralCreeps(radius + 200)
		local closeNeutralCreeps = bot:GetNearbyNeutralCreeps(400)
		if #neutralCreeps >= 3 and #closeNeutralCreeps <= 2 or #neutralCreeps >= 5 then
			return BOT_ACTION_DESIRE_HIGH, "Q打野" .. #neutralCreeps
		end
	end
	if Fu.IsLaning(bot) then
		local killableMeleeCount = 0
		local killableRangedCount = 0
		local laneCreeps = bot:GetNearbyLaneCreeps(radius + 100, true)
		for _, creep in pairs(laneCreeps) do
			if Fu.IsValid(creep) and not creep:HasModifier("modifier_fountain_glyph") then
				local distance = GetUnitToUnitDistance(bot, creep)
				local damage = RemapValClamped(distance, 0, radius, minDamage, maxDamage) * 2
				if Fu.WillKillTarget(creep, damage, damageType, distance * 0.9 / 636) then
					if Fu.IsKeyWordUnit("ranged", creep) then
						killableRangedCount = killableRangedCount + 1
						if not Fu.IsInRange(bot, creep, bot:GetAttackRange() + 50) then
							return BOT_ACTION_DESIRE_HIGH, "Q对线1"
						end
					end
					if Fu.IsKeyWordUnit("melee", creep) then
						killableMeleeCount = killableMeleeCount + 1
					end
				end
			end
		end
		if killableMeleeCount + killableRangedCount >= 3 then
			return BOT_ACTION_DESIRE_HIGH, "Q对线2"
		end
		if killableRangedCount >= 1 and killableMeleeCount >= 1 then
			return BOT_ACTION_DESIRE_HIGH, "Q对线3"
		end
	end
	if
		(#enemiesNearby > 0 or bot:WasRecentlyDamagedByAnyHero(3.0))
		and (bot:GetActiveMode() ~= BOT_MODE_RETREAT or #alliesNearby >= 2)
		and #enemiesInRadius >= 1
		and botLevel >= 15
	then
		for _, enemyHero in pairs(enemiesInRadius) do
			if Fu.IsValid(enemyHero) and Fu.CanCastOnNonMagicImmune(enemyHero) then
				return BOT_ACTION_DESIRE_HIGH, "Q通用" .. Fu.Chat.GetNormName(enemyHero)
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderW()
	if not staticLinkAbility:IsFullyCastable() then
		return 0
	end
	local abilityLevel = staticLinkAbility:GetLevel()
	local castRange = staticLinkAbility:GetCastRange() + aetherRange
	local castPoint = staticLinkAbility:GetCastPoint()
	local manaCost = staticLinkAbility:GetManaCost()
	local damage = staticLinkAbility:GetAbilityDamage()
	local damageType = DAMAGE_TYPE_MAGICAL
	local enemiesInRange = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	local enemiesNearby = Fu.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE)
	local alliesNearby = Fu.GetNearbyHeroes(bot, 1200, false, BOT_MODE_NONE)
	local botTarget = Fu.GetProperTarget(bot)
	local validTargetCount = 0
	local bestTarget = nil
	local highestAttackDamage = 0
	for _, enemyHero in pairs(enemiesInRange) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and Fu.CanCastOnTargetAdvanced(enemyHero)
			and not enemyHero:HasModifier("modifier_razor_static_link_debuff")
		then
			validTargetCount = validTargetCount + 1
			if enemyHero:GetAttackDamage() > highestAttackDamage then
				bestTarget = enemyHero
				highestAttackDamage = enemyHero:GetAttackDamage()
			end
		end
	end
	if validTargetCount >= 2 and bestTarget ~= nil then
		return BOT_ACTION_DESIRE_HIGH, bestTarget, "W择优" .. Fu.Chat.GetNormName(bestTarget)
	end
	if Fu.IsLaning(bot) then
		bestTarget = enemiesInRange[1]
		if
			Fu.IsValidHero(bestTarget)
			and Fu.CanCastOnNonMagicImmune(bestTarget)
			and Fu.CanCastOnTargetAdvanced(bestTarget)
			and Fu.IsInRange(bot, bestTarget, castRange - 180)
			and not bestTarget:HasModifier("modifier_razor_static_link_debuff")
		then
			bot:SetTarget(bestTarget)
			return BOT_ACTION_DESIRE_HIGH, bestTarget, "W对线" .. Fu.Chat.GetNormName(bestTarget)
		end
	end
	if
		Fu.IsGoingOnSomeone(bot)
		and Fu.IsValidHero(botTarget)
		and not botTarget:HasModifier("modifier_razor_static_link_debuff")
		and Fu.CanCastOnNonMagicImmune(botTarget)
		and Fu.CanCastOnTargetAdvanced(botTarget)
		and Fu.IsInRange(bot, botTarget, castRange - 100)
		and Fu.GetAllyCount(bot, 1200) - Fu.GetEnemyCount(bot, 1600) < 3
	then
		return BOT_ACTION_DESIRE_HIGH, botTarget, "W进攻" .. Fu.Chat.GetNormName(botTarget)
	end
	if Fu.IsRetreating(bot) then
		for _, enemyHero in pairs(enemiesInRange) do
			if
				Fu.IsValidHero(enemyHero)
				and not enemyHero:HasModifier("modifier_razor_static_link_debuff")
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
				and (
					bot:WasRecentlyDamagedByHero(enemyHero, 3.0)
					or bot:GetActiveModeDesire() > BOT_MODE_DESIRE_VERYHIGH
				)
			then
				return BOT_ACTION_DESIRE_HIGH, enemyHero, "W撤退" .. Fu.Chat.GetNormName(enemyHero)
			end
		end
	end
	if
		(#enemiesNearby > 0 or bot:WasRecentlyDamagedByAnyHero(3.0))
		and (bot:GetActiveMode() ~= BOT_MODE_RETREAT or #alliesNearby >= 2)
		and #enemiesInRange >= 1
		and botLevel >= 15
	then
		for _, enemyHero in pairs(enemiesInRange) do
			if
				Fu.IsValid(enemyHero)
				and not enemyHero:HasModifier("modifier_razor_static_link_debuff")
				and Fu.IsInRange(bot, enemyHero, castRange - 100)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
			then
				return BOT_ACTION_DESIRE_HIGH, enemyHero, "W通用" .. Fu.Chat.GetNormName(enemyHero)
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderR()
	if not eyeOfTheStormAbility:IsFullyCastable() or bot:HasModifier("modifier_razor_eye_of_the_storm") then
		return 0
	end
	local abilityLevel = eyeOfTheStormAbility:GetLevel()
	local radius = 500
	local castPoint = eyeOfTheStormAbility:GetCastPoint()
	local manaCost = eyeOfTheStormAbility:GetManaCost()
	local damage = eyeOfTheStormAbility:GetAbilityDamage()
	local damageType = DAMAGE_TYPE_PHYSICAL
	local enemiesInRadius = Fu.GetNearbyHeroes(bot, radius, true, BOT_MODE_NONE)
	local enemyCount = 0
	for _, enemyHero in pairs(enemiesInRadius) do
		if Fu.IsValidHero(enemyHero) and Fu.CanCastOnMagicImmune(enemyHero) then
			enemyCount = enemyCount + 1
		end
	end
	if enemyCount >= 2 then
		return BOT_ACTION_DESIRE_HIGH, "R两人"
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidHero(botTarget)
			and Fu.IsInRange(bot, botTarget, radius + 200)
			and Fu.CanCastOnMagicImmune(botTarget)
			and (Fu.GetProperTarget(botTarget) ~= nil or Fu.IsInRange(bot, botTarget, radius))
			and Fu.GetAllyCount(bot, 1200) - Fu.GetEnemyCount(bot, 1600) <= 2
		then
			return BOT_ACTION_DESIRE_HIGH, "R进攻" .. Fu.Chat.GetNormName(botTarget)
		end
	end
	if Fu.IsRetreating(bot) then
		for _, enemyHero in pairs(enemiesInRadius) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.CanCastOnMagicImmune(enemyHero)
				and (
					bot:WasRecentlyDamagedByHero(enemyHero, 2.0)
					or bot:GetActiveModeDesire() > BOT_MODE_DESIRE_VERYHIGH
				)
			then
				return BOT_ACTION_DESIRE_HIGH, "R撤退" .. Fu.Chat.GetNormName(enemyHero)
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
return X
