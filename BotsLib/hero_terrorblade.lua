-- Terrorblade: skill build, item build, and ability use for this hero.
local X = {}
local bot = GetBot()
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local AbilityContext = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local Minion = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local sTalentList = Fu.Skill.GetTalentList(bot)
local sAbilityList = Fu.Skill.GetAbilityList(bot)
local sRole = Fu.Item.GetRoleItemsBuyList(bot)
local tTalentTreeList = { ["t25"] = { 0, 10 }, ["t20"] = { 10, 0 }, ["t15"] = { 0, 10 }, ["t10"] = { 10, 0 } }
local tAllAbilityBuildList = { { 2, 3, 2, 3, 2, 6, 2, 3, 3, 1, 6, 1, 1, 1, 6 } }
local nAbilityBuildList = Fu.Skill.GetRandomBuild(tAllAbilityBuildList)
local nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList)
local sRoleItemsBuyList = {}
-- Stratz 7.41f, week of 9 Nov 2026: pos 1, 55,365 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_1"] = {
	"item_tango",
	"item_double_branches",
	"item_quelling_blade",
	"item_magic_stick",
	"item_faerie_fire",
	"item_magic_wand",
	"item_power_treads",
	"item_falcon_blade",
	"item_manta",
	"item_dragon_lance",
	"item_skadi",
	"item_hurricane_pike",
	"item_black_king_bar",
	"item_greater_crit",
	"item_travel_boots",
	"item_ultimate_scepter_2",
	"item_moon_shard",
	"item_aghanims_shard",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 2 has 644 matches, built from pos 1 (55,365) (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_2"] = sRoleItemsBuyList["pos_1"]
-- Stratz 7.41f, week of 9 Nov 2026: pos 4, 1,172 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_4"] = {
	"item_tango",
	"item_blood_grenade",
	"item_double_branches",
	"item_magic_stick",
	"item_faerie_fire",
	"item_magic_wand",
	"item_power_treads",
	"item_armlet",
	"item_blink",
	"item_dagon",
	"item_dagon_5",
	"item_travel_boots",
	"item_ultimate_scepter_2",
	"item_skadi",
	"item_dragon_lance",
	"item_hurricane_pike",
	"item_aghanims_shard",
	"item_moon_shard",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 5 has 787 matches, built from pos 4 (1,172) (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_5"] = sRoleItemsBuyList["pos_4"]
-- Stratz 7.41f, week of 9 Nov 2026: pos 3, 1,203 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_3"] = {
	"item_tango",
	"item_double_branches",
	"item_quelling_blade",
	"item_circlet",
	"item_wraith_band",
	"item_magic_wand",
	"item_falcon_blade",
	"item_power_treads",
	"item_manta",
	"item_dragon_lance",
	"item_skadi",
	"item_black_king_bar",
	"item_greater_crit",
	"item_travel_boots",
	"item_aghanims_shard",
	"item_moon_shard",
	"item_ultimate_scepter_2",
}
X["sBuyList"] = sRoleItemsBuyList[sRole]
X["sSellList"] = {
	"item_black_king_bar",
	"item_quelling_blade",
	-- Sold once the item before it is owned, to keep six slots (Util/item-builds/generate.js):
	"item_greater_crit",
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
	if Minion.IsValidUnit(hMinionUnit) then
		if Fu.IsValidHero(hMinionUnit) and hMinionUnit:IsIllusion() then
			Minion.IllusionThink(hMinionUnit)
		end
	end
end
local reflectionAbility =
	SafeAbility(bot:GetAbilityByName("terrorblade_reflection"), "terrorblade_reflection", "terrorblade")
local conjureImageAbility =
	SafeAbility(bot:GetAbilityByName("terrorblade_conjure_image"), "terrorblade_conjure_image", "terrorblade")
local metamorphosisAbility =
	SafeAbility(bot:GetAbilityByName("terrorblade_metamorphosis"), "terrorblade_metamorphosis", "terrorblade")
local demonZealAbility =
	SafeAbility(bot:GetAbilityByName("terrorblade_demon_zeal"), "terrorblade_demon_zeal", "terrorblade")
local terrorWaveAbility =
	SafeAbility(bot:GetAbilityByName("terrorblade_terror_wave"), "terrorblade_terror_wave", "terrorblade")
local sunderAbility = SafeAbility(bot:GetAbilityByName("terrorblade_sunder"), "terrorblade_sunder", "terrorblade")
local reflectionDesire, reflectionLocation
local conjureImageDesire
local metamorphosisDesire
local demonZealDesire
local terrorWaveDesire
local sunderDesire, sunderTarget
local botTarget
local isGoingOnSomeone
local hpRatio
local isInTeamFight
function X.SkillsComplement()
	if Fu.CanNotUseAbility(bot) then
		return
	end
	isGoingOnSomeone = Fu.IsGoingOnSomeone(bot)
	hpRatio = Fu.GetHP(bot)
	isInTeamFight = Fu.IsInTeamFight(bot, 1200)
	sunderDesire, sunderTarget = X.ConsiderSunder()
	if sunderDesire > 0 then
		bot:Action_UseAbilityOnEntity(sunderAbility, sunderTarget)
		return
	end
	reflectionDesire, reflectionLocation = X.ConsiderReflection()
	if reflectionDesire > 0 then
		bot:Action_UseAbilityOnLocation(reflectionAbility, reflectionLocation)
		return
	end
	conjureImageDesire = X.ConsiderConjureImage()
	if conjureImageDesire > 0 then
		bot:Action_UseAbility(conjureImageAbility)
		return
	end
	terrorWaveDesire = X.ConsiderTerrorWave()
	if terrorWaveDesire > 0 then
		bot:Action_UseAbility(terrorWaveAbility)
		return
	end
	metamorphosisDesire = X.ConsiderMetamorphosis()
	if metamorphosisDesire > 0 then
		bot:Action_UseAbility(metamorphosisAbility)
		return
	end
	demonZealDesire = X.ConsiderDemonZeal()
	if demonZealDesire > 0 then
		bot:Action_UseAbility(demonZealAbility)
		return
	end
end
function X.ConsiderReflection()
	if not reflectionAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local radius = reflectionAbility:GetSpecialValueInt("range")
	local castRange = reflectionAbility:GetCastRange()
	local castPoint = reflectionAbility:GetCastPoint()
	botTarget = Fu.GetProperTarget(bot)
	if isInTeamFight then
		local aoeLocation = bot:FindAoELocation(true, true, bot:GetLocation(), castRange, radius, castPoint, 0)
		if aoeLocation.count >= 2 then
			return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
		end
	end
	if isGoingOnSomeone then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, castRange + 200, false, BOT_MODE_NONE)
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and nearbyAllies ~= nil
			and nearbyEnemies
			and #nearbyAllies >= #nearbyEnemies
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	if Fu.IsRetreating(bot) then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, castRange + 200, false, BOT_MODE_NONE)
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
		if
			nearbyAllies ~= nil
			and nearbyEnemies ~= nil
			and (#nearbyEnemies > #nearbyAllies or hpRatio < 0.6 and bot:WasRecentlyDamagedByAnyHero(2))
			and Fu.IsValidHero(nearbyEnemies[1])
			and Fu.CanCastOnNonMagicImmune(nearbyEnemies[1])
			and not Fu.IsSuspiciousIllusion(nearbyEnemies[1])
			and not Fu.IsDisabled(nearbyEnemies[1])
		then
			return BOT_ACTION_DESIRE_HIGH, nearbyEnemies[1]:GetLocation()
		end
	end
	local alliesInRange = Fu.GetNearbyHeroes(bot, castRange, false, BOT_MODE_NONE)
	for _, allyHero in pairs(alliesInRange) do
		local enemiesNearAlly = Fu.GetNearbyHeroes(allyHero, castRange, true, BOT_MODE_NONE)
		if
			Fu.IsRetreating(allyHero)
			and Fu.GetHP(allyHero) < 0.6
			and allyHero:WasRecentlyDamagedByAnyHero(2.5)
			and Fu.IsValidHero(enemiesNearAlly[1])
			and Fu.CanCastOnNonMagicImmune(enemiesNearAlly[1])
			and Fu.IsInRange(bot, enemiesNearAlly[1], castRange)
			and not Fu.IsSuspiciousIllusion(enemiesNearAlly[1])
			and not Fu.IsDisabled(enemiesNearAlly[1])
		then
			return BOT_ACTION_DESIRE_HIGH, enemiesNearAlly[1]:GetLocation()
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.ConsiderConjureImage()
	if not conjureImageAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
	end
	local mpRatio = bot:GetMana() / bot:GetMaxMana()
	botTarget = Fu.GetProperTarget(bot)
	if isGoingOnSomeone then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, 800, false, BOT_MODE_NONE)
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, 600, true, BOT_MODE_NONE)
		if
			Fu.IsValidTarget(botTarget)
			and Fu.IsInRange(bot, botTarget, bot:GetAttackRange() + 50)
			and not Fu.IsInEtherealForm(botTarget)
			and not botTarget:HasModifier("modifier_dazzle_shallow_grave")
			and nearbyAllies ~= nil
			and nearbyEnemies ~= nil
			and #nearbyAllies >= #nearbyEnemies
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsRetreating(bot) then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, 800, false, BOT_MODE_NONE)
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, 600, true, BOT_MODE_NONE)
		if
			nearbyAllies ~= nil
			and nearbyEnemies ~= nil
			and (#nearbyEnemies > #nearbyAllies or hpRatio < 0.5 and bot:WasRecentlyDamagedByAnyHero(2))
		then
			return BOT_ACTION_DESIRE_MODERATE
		end
	end
	if Fu.IsDefending(bot) or Fu.IsPushing(bot) then
		local nearbyLaneCreeps = bot:GetNearbyLaneCreeps(700, true)
		local nearbyTowers = bot:GetNearbyTowers(700, true)
		if nearbyLaneCreeps ~= nil and #nearbyLaneCreeps >= 3 or nearbyTowers ~= nil and #nearbyTowers >= 1 then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsFarming(bot) and mpRatio > 0.4 then
		if Fu.IsValid(botTarget) and Fu.CanBeAttacked(botTarget) and botTarget:IsCreep() then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if Fu.IsRoshan(botTarget) and Fu.IsInRange(bot, botTarget, bot:GetAttackRange()) then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, bot:GetAttackRange()) and Fu.IsAttacking(bot) then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderMetamorphosis()
	if not metamorphosisAbility:IsFullyCastable() or bot:HasModifier("modifier_terrorblade_metamorphosis") then
		return BOT_ACTION_DESIRE_NONE
	end
	local attackRange = bot:GetAttackRange() + metamorphosisAbility:GetSpecialValueInt("bonus_range")
	botTarget = Fu.GetProperTarget(bot)
	if isInTeamFight then
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, attackRange, true, BOT_MODE_NONE)
		if nearbyEnemies ~= nil and #nearbyEnemies >= 2 then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if isGoingOnSomeone then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, attackRange + 150, false, BOT_MODE_NONE)
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, attackRange, true, BOT_MODE_NONE)
		if
			Fu.IsValidTarget(botTarget)
			and Fu.IsInRange(bot, botTarget, attackRange)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not Fu.IsInEtherealForm(botTarget)
			and not botTarget:HasModifier("modifier_dazzle_shallow_grave")
			and nearbyAllies ~= nil
			and nearbyEnemies
			and #nearbyAllies >= #nearbyEnemies
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if Fu.IsRoshan(botTarget) and Fu.IsInRange(bot, botTarget, attackRange) and DotaTime() < 30 * 60 then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderSunder()
	if not sunderAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castRange = sunderAbility:GetCastRange()
	local enemiesInRange = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	-- Review fix: Sunder went out even when the target's HP% was no higher than TB's (no gain).
	-- Only swap when it actually gains TB health.
	local swapTarget = Fu.GetMostHPPercent(enemiesInRange, true)
	if
		hpRatio < 0.35
		and swapTarget ~= nil
		and not Fu.IsSuspiciousIllusion(swapTarget)
		and Fu.GetHP(swapTarget) > hpRatio + 0.15
	then
		return BOT_ACTION_DESIRE_HIGH, swapTarget
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function X.ConsiderDemonZeal()
	if not demonZealAbility:IsTrained() or not demonZealAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
	end
	-- datafeed: the HP cost is health_cost_pct (20%) of current HP; "value" no longer exists (read 0).
	local healthCost = bot:GetHealth() * demonZealAbility:GetSpecialValueFloat("health_cost_pct") / 100
	local attackRange = bot:GetAttackRange() + metamorphosisAbility:GetSpecialValueInt("bonus_range")
	botTarget = Fu.GetProperTarget(bot)
	-- datafeed: Demon Zeal can't be cast while in Metamorphosis (and Metamorphosis removes it), so
	-- cast it outside Metamorphosis; it used to require the Metamorphosis modifier and never went out.
	if
		(bot:GetHealth() - healthCost) / bot:GetMaxHealth() > 0.5
		and not bot:HasModifier("modifier_terrorblade_metamorphosis")
		and not bot:HasModifier("modifier_terrorblade_metamorphosis_transform")
	then
		if isInTeamFight then
			local nearbyEnemies = Fu.GetNearbyHeroes(bot, attackRange, true, BOT_MODE_NONE)
			if nearbyEnemies ~= nil and #nearbyEnemies >= 2 then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
		if isGoingOnSomeone then
			local nearbyAllies = Fu.GetNearbyHeroes(bot, attackRange + 150, false, BOT_MODE_NONE)
			local nearbyEnemies = Fu.GetNearbyHeroes(bot, attackRange, true, BOT_MODE_NONE)
			if
				Fu.IsValidTarget(botTarget)
				and Fu.IsInRange(bot, botTarget, attackRange)
				and not Fu.IsSuspiciousIllusion(botTarget)
				and not Fu.IsInEtherealForm(botTarget)
				and not botTarget:HasModifier("modifier_dazzle_shallow_grave")
				and nearbyAllies ~= nil
				and nearbyEnemies
				and #nearbyAllies >= #nearbyEnemies
			then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderTerrorWave()
	if
		not bot:HasScepter()
		or not terrorWaveAbility:IsFullyCastable()
		or bot:HasModifier("modifier_terrorblade_metamorphosis_transform")
	then
		return BOT_ACTION_DESIRE_NONE
	end
	local attackRange = bot:GetAttackRange() + metamorphosisAbility:GetSpecialValueInt("bonus_range")
	botTarget = Fu.GetProperTarget(bot)
	if isInTeamFight then
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, attackRange, true, BOT_MODE_NONE)
		if nearbyEnemies ~= nil and #nearbyEnemies >= 2 then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if isGoingOnSomeone then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, attackRange + 150, false, BOT_MODE_NONE)
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, attackRange, true, BOT_MODE_NONE)
		if
			Fu.IsValidTarget(botTarget)
			and Fu.IsInRange(bot, botTarget, attackRange)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not Fu.IsInEtherealForm(botTarget)
			and not botTarget:HasModifier("modifier_dazzle_shallow_grave")
			and nearbyAllies ~= nil
			and nearbyEnemies
			and #nearbyAllies >= #nearbyEnemies
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if Fu.IsRoshan(botTarget) and Fu.IsInRange(bot, botTarget, attackRange) and DotaTime() < 30 * 60 then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
return X
