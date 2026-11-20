-- Lone Druid: skill build, item build, and ability use for this hero.
local X = {}
local bot = GetBot()
local Utils = require(GetScriptDirectory() .. "/FuncLib/systems/utils")
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local AbilityContext = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local Minion = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local sTalentList = Fu.Skill.GetTalentList(bot)
local sAbilityList = Fu.Skill.GetAbilityList(bot)
if Utils.GetLoneDruid(bot).hero == nil then
	Utils.GetLoneDruid(bot).hero = bot
end
local tTalentTreeList = { ["t25"] = { 0, 10 }, ["t20"] = { 0, 10 }, ["t15"] = { 0, 10 }, ["t10"] = { 0, 10 } }
-- Spirit Link maxed first, Entangle second, Savage Roar last (Dotabuff most picked order).
-- True Form at entries 6/11/15 (levels 6/12/18).
local tAllAbilityBuildList = { { 1, 2, 2, 1, 2, 6, 2, 1, 1, 3, 6, 3, 3, 3, 6 } }
local nBearAbilityBuildList = { 1, 2, 2, 1, 2, 6, 2, 1, 1, 3, 6, 3, 3, 3, 6 }
local nAbilityBuildList = Fu.Skill.GetRandomBuild(tAllAbilityBuildList)
local nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList)
-- One list for every position: the hero-and-bear block (two inventories). It was the only list ever used:
-- the old per-position lists sat behind `GetAbilityByName("lone_druid_spirit_bear") ~= nil`, which is always
-- true (Spirit Bear is on his slots), so they were removed (#13). Util/item-builds/pins.json keeps this block
-- out of the Stratz generator.
local sRoleItemsBuyList = {}
sRoleItemsBuyList["pos_1"] = {
	"item_tango",
	"item_magic_wand",
	"item_phase_boots",
	"item_boots",
	"item_diffusal_blade",
	"item_desolator",
	"item_black_king_bar",
	"item_assault",
	"item_ultimate_scepter",
	"item_monkey_king_bar",
	"item_ultimate_scepter_2",
	"item_butterfly",
	"item_moon_shard",
	"item_satanic",
	"item_travel_boots",
	"item_travel_boots_2",
}
sRoleItemsBuyList["pos_2"] = sRoleItemsBuyList["pos_1"]
sRoleItemsBuyList["pos_3"] = sRoleItemsBuyList["pos_1"]
sRoleItemsBuyList["pos_4"] = sRoleItemsBuyList["pos_1"]
sRoleItemsBuyList["pos_5"] = sRoleItemsBuyList["pos_1"]
X["sBuyList"] = sRoleItemsBuyList["pos_1"]
X["sSellList"] = {}
if Utils.GetLoneDruid(bot).roleType == nil then
	if RandomInt(1, 5) >= 0 then
		Utils.GetLoneDruid(bot).roleType = "pos_1_w_bear"
	else
		Utils.GetLoneDruid(bot).roleType = "pos_1"
	end
else
	if Utils.GetLoneDruid(bot).roleType == "pos_1_w_bear" then
		nAbilityBuildList = nBearAbilityBuildList
	end
end
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
local spiritBearAbility =
	SafeAbility(bot:GetAbilityByName("lone_druid_spirit_bear"), "lone_druid_spirit_bear", "lone_druid")
local savageRoarAbility =
	SafeAbility(bot:GetAbilityByName("lone_druid_savage_roar"), "lone_druid_savage_roar", "lone_druid")
local trueFormAbility = SafeAbility(bot:GetAbilityByName("lone_druid_true_form"), "lone_druid_true_form", "lone_druid")
-- datafeed: Entangle is an active point/AoE spell (behavior 48) and was never cast
local entangle = SafeAbility(bot:GetAbilityByName("lone_druid_entangle"), "lone_druid_entangle", "lone_druid")
local summonSpiritBearDesire
local savageRoarDesire
local trueFormDesire
local botTarget
local hpRatio
function X.SkillsComplement()
	if Fu.CanNotUseAbility(bot) then
		return
	end
	local context = AbilityContext.Build(bot)
	hpRatio = context.hp
	botTarget = context.target
	summonSpiritBearDesire = X.ConsiderSummonSpiritBear()
	if summonSpiritBearDesire > 0 then
		bot:Action_UseAbility(spiritBearAbility)
		return
	end
	trueFormDesire = X.ConsiderTrueForm()
	if trueFormDesire > 0 then
		bot:Action_UseAbility(trueFormAbility)
		return
	end
	local entangleDesire, entangleLoc = X.ConsiderEntangle()
	if entangleDesire > 0 then
		bot:Action_UseAbilityOnLocation(entangle, entangleLoc)
		return
	end
	savageRoarDesire = X.ConsiderSavageRoar()
	if savageRoarDesire > 0 then
		bot:Action_UseAbility(savageRoarAbility)
		return
	end
end
-- datafeed: Entangle, cast range 700, active_radius 350; the cast adds stacks to enemy heroes in the
-- area and empowers Lone Druid's attacks.
function X.ConsiderEntangle()
	if not entangle:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local range = Fu.GetProperCastRange(false, bot, entangle:GetCastRange())
	local radius = entangle:GetSpecialValueInt("active_radius")
	if Fu.IsInTeamFight(bot, 1200) then
		local aoe = bot:FindAoELocation(true, true, bot:GetLocation(), range, radius, 0, 0)
		if aoe.count >= 2 then
			return BOT_ACTION_DESIRE_HIGH, aoe.targetloc
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidHero(botTarget)
			and Fu.IsInRange(bot, botTarget, range)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and not Fu.IsSuspiciousIllusion(botTarget)
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	-- Data: root_heroes_on_cast is 0 without Scepter (the cast only adds 2 stacks, 5 are needed to
	-- root), so a retreat cast without Scepter wasted the spell and did not stop the chaser.
	if Fu.IsRetreating(bot) and bot:HasScepter() then
		for _, enemyHero in pairs(Fu.GetNearbyHeroes(bot, range, true, BOT_MODE_NONE) or {}) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.IsChasingTarget(enemyHero, bot)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and not Fu.IsDisabled(enemyHero)
			then
				return BOT_ACTION_DESIRE_HIGH, enemyHero:GetLocation()
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function X.ConsiderSummonSpiritBear()
	if not spiritBearAbility:IsFullyCastable() or Utils.GetLoneDruid(bot).roleType ~= "pos_1_w_bear" then
		return BOT_ACTION_DESIRE_NONE
	end
	if Utils.GetLoneDruid(bot).bear == nil or not Utils.GetLoneDruid(bot).bear:IsAlive() then
		return BOT_ACTION_DESIRE_HIGH
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderSavageRoar()
	if not savageRoarAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
	end
	local radius = savageRoarAbility:GetSpecialValueInt("radius")
	local nearbyEnemies = Fu.GetNearbyHeroes(bot, radius, true, BOT_MODE_NONE)
	-- Was: any enemy hero in radius that was moving or attacking anything, i.e. nearly always, so the
	-- roar feared Lone Druid's own chase target away from him and the bear. Now only an enemy on Lone
	-- Druid or the bear, chasing him, channeling or casting.
	local bear = Utils.GetLoneDruid(bot).bear
	for _, enemyHero in pairs(nearbyEnemies) do
		local onUs = Fu.IsValidHero(enemyHero)
			and (enemyHero:GetAttackTarget() == bot or (bear ~= nil and enemyHero:GetAttackTarget() == bear))
		if
			Fu.IsValidTarget(enemyHero)
			and (Fu.IsChasingTarget(enemyHero, bot) or onUs or enemyHero:IsChanneling() or enemyHero:IsUsingAbility())
			and not Fu.IsSuspiciousIllusion(enemyHero)
			and not Fu.IsDisabled(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and Fu.CanCastOnTargetAdvanced(enemyHero)
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	-- Removed the "going on someone, target in radius" cast: the fear sends the target toward its
	-- base, out of the bear's reach. A target hitting Lone Druid or the bear is handled above.
	-- Roshan / Tormentor: the ability data sets only_affects_player_units 1, which suggests Roshan and
	-- the Tormentor are not feared, so without Shard the cast likely did nothing. With Shard the roar
	-- grants allies attack speed (datafeed shard text, shard_attack_speed 40).
	local hasShard = bot:HasModifier("modifier_item_aghanims_shard")
	if Fu.IsDoingRoshan(bot) and hasShard then
		if Fu.IsRoshan(botTarget) and Fu.IsInRange(bot, botTarget, 500) and Fu.IsAttacking(bot) then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsDoingTormentor(bot) and hasShard then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, 500) and Fu.IsAttacking(bot) then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderTrueForm()
	if trueFormAbility:IsHidden() or not trueFormAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidTarget(botTarget)
			and Fu.IsInRange(bot, botTarget, bot:GetCurrentVisionRange())
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not botTarget:HasModifier("modifier_faceless_void_chronosphere_freeze")
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			local alliesNearTarget = Fu.GetNearbyHeroes(botTarget, 1200, true, BOT_MODE_NONE)
			local enemiesNearTarget = Fu.GetNearbyHeroes(botTarget, 1200, false, BOT_MODE_NONE)
			if
				alliesNearTarget ~= nil
				and enemiesNearTarget ~= nil
				and #alliesNearTarget >= #enemiesNearTarget
				and hpRatio < 0.85
			then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	if Fu.IsInTeamFight(bot, 1200) and hpRatio < 0.85 then
		return BOT_ACTION_DESIRE_HIGH
	end
	if Fu.IsRetreating(bot) then
		local nearbyEnemies = Fu.GetEnemiesNearLoc(bot:GetLocation(), 1000)
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.IsChasingTarget(enemyHero, bot)
				and hpRatio < 0.45
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and not Fu.IsDisabled(enemyHero)
			then
				local alliesNearChaser = Fu.GetNearbyHeroes(enemyHero, 1200, true, BOT_MODE_NONE)
				local enemiesNearChaser = Fu.GetNearbyHeroes(enemyHero, 1200, false, BOT_MODE_NONE)
				if
					alliesNearChaser ~= nil
					and enemiesNearChaser ~= nil
					and (#enemiesNearChaser > #alliesNearChaser or bot:WasRecentlyDamagedByAnyHero(1.5))
				then
					return BOT_ACTION_DESIRE_HIGH
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
return X
