-- Lone Druid Bear: skill build, item build, and ability use for this hero.
local X = {}
local bot = GetBot()
local Utils = require(GetScriptDirectory() .. "/FuncLib/systems/utils")
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local AbilityContext = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local Minion = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local loneDruid = Utils.GetLoneDruid(bot)
if loneDruid then
	if loneDruid.bear == nil or not loneDruid.bear:IsAlive() then
		loneDruid.bear = bot
	end
	if loneDruid.hero and loneDruid.hero.assignedRole then
		bot.assignedRole = loneDruid.hero.assignedRole
	else
		bot.assignedRole = 1
	end
end
bot.isBear = true
local sTalentList = Fu.Skill.GetTalentList(bot)
local sAbilityList = Fu.Skill.GetAbilityList(bot)
local sRole = Fu.Item.GetRoleItemsBuyList(bot)
local tTalentTreeList = { ["t25"] = { 0, 0 }, ["t20"] = { 0, 0 }, ["t15"] = { 0, 0 }, ["t10"] = { 0, 0 } }
local tAllAbilityBuildList = { {} }
local nAbilityBuildList = Fu.Skill.GetRandomBuild(tAllAbilityBuildList)
local nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList)
local sRoleItemsBuyList = {}
sRoleItemsBuyList["pos_1"] = {}
sRoleItemsBuyList["pos_2"] = sRoleItemsBuyList["pos_1"]
sRoleItemsBuyList["pos_3"] = sRoleItemsBuyList["pos_1"]
sRoleItemsBuyList["pos_4"] = sRoleItemsBuyList["pos_1"]
sRoleItemsBuyList["pos_5"] = sRoleItemsBuyList["pos_1"]
X["sBuyList"] = sRoleItemsBuyList[sRole]
X.BearItemsList = {
	"item_orb_of_venom",
	"item_phase_boots",
	"item_diffusal_blade",
	"item_desolator",
	"item_assault",
	"item_monkey_king_bar",
	"item_ultimate_scepter",
	"item_ultimate_scepter_2",
	"item_moon_shard",
}
X.BearItemsMap = {}
for _, itemName in ipairs(X.BearItemsList) do
	X.BearItemsMap[itemName] = true
end
Utils.GetLoneDruid(bot).bearItemsMap = X.BearItemsMap
X["sSellList"] = { "item_black_king_bar", "item_quelling_blade" }
if Fu.Role.IsPvNMode() or Fu.Role.IsAllShadow() then
	X["sBuyList"], X["sSellList"] = { "PvN_antimage" }, {}
end
nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"] =
	Fu.SetUserHeroInit(nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"])
X["sSkillList"] = Fu.Skill.GetSkillList(sAbilityList, nAbilityBuildList, sTalentList, nTalentBuildList)
X["bDeafaultAbility"] = false
X["bDeafaultItem"] = false
function X.MinionThink(hMinionUnit)
	Minion.MinionThink(hMinionUnit)
end
local returnAbility = bot:GetAbilityByName(sAbilityList[1])
local savageRoarAbility = bot:GetAbilityByName("lone_druid_savage_roar_bear")
local returnDesire
local savageRoarDesire
local mpRatio, hpRatio, botTarget, distanceFromHero
function X.SkillsComplement()
	if Fu.CanNotUseAbility(bot) or bot:IsInvisible() then
		return
	end
	botTarget = Fu.GetProperTarget(Utils.GetLoneDruid(bot).hero)
	if botTarget ~= nil then
		bot:SetTarget(botTarget)
	end
	botTarget = Fu.GetProperTarget(bot)
	distanceFromHero = GetUnitToUnitDistance(Utils.GetLoneDruid(bot).hero, bot)
	returnDesire = X.ConsiderQ()
	if returnDesire > 0 then
		bot:Action_UseAbility(returnAbility)
		return
	end
	savageRoarDesire = X.ConsiderSavageRoar()
	if savageRoarDesire > 0 then
		bot:Action_UseAbility(savageRoarAbility)
		return
	end
end
function X.ConsiderQ()
	if not returnAbility:IsFullyCastable() then
		return 0
	end
	if not Utils.GetLoneDruid(bot).hero:IsAlive() then
		return 0
	end
	if Fu.GetHP(bot) < 0.9 and bot:DistanceFromFountain() < 450 then
		return 0
	end
	if
		distanceFromHero > 3000
		and Fu.GetHP(bot) > 0.25
		and not Fu.IsRetreating(bot)
		and not Fu.Item.HasItem(bot, "item_ultimate_scepter")
	then
		return BOT_ACTION_DESIRE_HIGH
	end
	if
		Utils.GetLoneDruid(bot).hero:WasRecentlyDamagedByAnyHero(2)
		and Fu.GetHP(Utils.GetLoneDruid(bot).hero) < 0.9
		and Fu.GetHP(bot) > 0.25
		and not Fu.IsRetreating(bot)
		and distanceFromHero > 3000
	then
		local nearbyEnemies = Fu.GetNearbyHeroes(Utils.GetLoneDruid(bot).hero, 1000, true, BOT_MODE_NONE)
		if #nearbyEnemies >= 1 then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderSavageRoar()
	if not savageRoarAbility:IsFullyCastable() then
		return 0
	end
	local radius = savageRoarAbility:GetSpecialValueInt("radius")
	local nearbyEnemies = Fu.GetNearbyHeroes(bot, radius, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidTarget(enemyHero)
			and (Fu.IsChasingTarget(enemyHero, bot) or Fu.IsAttacking(enemyHero) or Fu.IsMoving(enemyHero) or enemyHero:IsChanneling() or enemyHero:IsUsingAbility())
			and not Fu.IsSuspiciousIllusion(enemyHero)
			and not Fu.IsDisabled(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and Fu.CanCastOnTargetAdvanced(enemyHero)
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidTarget(botTarget)
			and Fu.IsInRange(bot, botTarget, radius)
			and not Fu.IsSuspiciousIllusion(botTarget)
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if Fu.IsRoshan(botTarget) and Fu.IsInRange(bot, botTarget, 500) and Fu.IsAttacking(bot) then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, 500) and Fu.IsAttacking(bot) then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
return X
