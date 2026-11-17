-- Broodmother: skill build, item build, and ability use for this hero.
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
	{ ["t25"] = { 0, 10 }, ["t20"] = { 10, 0 }, ["t15"] = { 0, 10 }, ["t10"] = { 10, 0 } },
}
local tAllAbilityBuildList =
	{ { 2, 3, 2, 3, 2, 6, 2, 3, 3, 1, 6, 1, 1, 1, 6 }, { 2, 3, 2, 1, 2, 6, 2, 3, 3, 3, 6, 1, 1, 1, 6 } }
local nAbilityBuildList = tAllAbilityBuildList[2]
local nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList[2])
if sRole == "pos_2" then
	nAbilityBuildList = tAllAbilityBuildList[1]
	nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList[1])
elseif sRole == "pos_3" then
	nAbilityBuildList = tAllAbilityBuildList[2]
	nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList[2])
end
local sRoleItemsBuyList = {}
sRoleItemsBuyList["pos_2"] = {
	"item_tango",
	"item_double_branches",
	"item_double_wraith_band",
	"item_power_treads",
	"item_soul_ring",
	"item_magic_wand",
	"item_orchid",
	"item_bloodthorn",
	"item_black_king_bar",
	"item_manta",
	"item_aghanims_shard",
	"item_butterfly",
	"item_skadi",
	"item_travel_boots_2",
	"item_moon_shard",
	"item_ultimate_scepter",
	"item_ultimate_scepter_2",
}
sRoleItemsBuyList["pos_3"] = {
	"item_tango",
	"item_double_branches",
	"item_double_wraith_band",
	"item_power_treads",
	"item_soul_ring",
	"item_magic_wand",
	"item_orchid",
	"item_bloodthorn",
	"item_black_king_bar",
	"item_manta",
	"item_aghanims_shard",
	"item_assault",
	"item_skadi",
	"item_travel_boots_2",
	"item_moon_shard",
	"item_ultimate_scepter",
	"item_ultimate_scepter_2",
}
sRoleItemsBuyList["pos_1"] = sRoleItemsBuyList["pos_3"]
sRoleItemsBuyList["pos_4"] = sRoleItemsBuyList["pos_3"]
sRoleItemsBuyList["pos_5"] = sRoleItemsBuyList["pos_3"]
X["sBuyList"] = sRoleItemsBuyList[sRole]
X["sSellList"] = { "item_power_treads", "item_quelling_blade" }
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
local insatiableHungerAbility =
	SafeAbility(bot:GetAbilityByName("broodmother_insatiable_hunger"), "broodmother_insatiable_hunger", "broodmother")
local spinWebAbility = SafeAbility(bot:GetAbilityByName("broodmother_spin_web"), "broodmother_spin_web", "broodmother")
local spawnSpiderlingsAbility =
	SafeAbility(bot:GetAbilityByName("broodmother_spawn_spiderlings"), "broodmother_spawn_spiderlings", "broodmother")
local insatiableHungerDesire
local spinWebDesire, spinWebLocation
local spawnSpiderlingsDesire, spawnSpiderlingsTarget
local webCastInterval = 1
local lastWebCastTime = 0
local botTarget
local isEngaging
local isRetreating
local isAttacking
function X.SkillsComplement()
	if Fu.CanNotUseAbility(bot) then
		return
	end
	local context = AbilityContext.Build(bot)
	isEngaging = context.isEngaging
	isRetreating = context.isRetreating
	isAttacking = Fu.IsAttacking(bot)
	spawnSpiderlingsDesire, spawnSpiderlingsTarget = X.ConsiderSpawnSpiderlings()
	if spawnSpiderlingsDesire > 0 then
		bot:Action_UseAbilityOnEntity(spawnSpiderlingsAbility, spawnSpiderlingsTarget)
		return
	end
	spinWebDesire, spinWebLocation = X.ConsiderSpinWeb()
	if spinWebDesire > 0 then
		if DotaTime() - lastWebCastTime > webCastInterval then
			bot:Action_UseAbilityOnLocation(spinWebAbility, spinWebLocation)
			lastWebCastTime = DotaTime()
		end
		return
	end
	insatiableHungerDesire = X.ConsiderInsatiableHunger()
	if insatiableHungerDesire > 0 then
		bot:Action_UseAbility(insatiableHungerAbility)
		return
	end
end
function X.ConsiderInsatiableHunger()
	if not insatiableHungerAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
	end
	local attackRange = bot:GetAttackRange()
	botTarget = Fu.GetProperTarget(bot)
	if Fu.IsInTeamFight(bot, 1200) then
		local enemiesInFight = Fu.GetEnemiesNearLoc(bot:GetLocation(), 1200)
		if enemiesInFight ~= nil and #enemiesInFight >= 2 and Fu.GetHP(bot) < 0.75 and isAttacking then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if isEngaging then
		if
			Fu.IsValidTarget(botTarget)
			and Fu.IsInRange(bot, botTarget, attackRange + 150)
			and isAttacking
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not Fu.IsDisabled(botTarget)
			and not botTarget:HasModifier("modifier_dazzle_shallow_grave")
			and not botTarget:HasModifier("modifier_faceless_void_chronosphere_freeze")
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
			and not botTarget:HasModifier("modifier_templar_assassin_refraction_absorb")
		then
			local alliesNearTarget = Fu.GetNearbyHeroes(botTarget, 1200, true, BOT_MODE_NONE)
			local enemiesNearTarget = Fu.GetNearbyHeroes(botTarget, 1200, false, BOT_MODE_NONE)
			if alliesNearTarget ~= nil and enemiesNearTarget ~= nil and #alliesNearTarget >= #enemiesNearTarget then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	if Fu.IsFarming(bot) then
		local nearbyCreeps = bot:GetNearbyCreeps(700, true)
		if nearbyCreeps ~= nil and #nearbyCreeps > 0 and Fu.GetHP(bot) < 0.4 and isAttacking then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if Fu.IsRoshan(botTarget) and Fu.IsInRange(bot, botTarget, 500) and isAttacking then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, 500) and isAttacking then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderSpinWeb()
	if not spinWebAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local castRange = Fu.GetProperCastRange(false, bot, spinWebAbility:GetCastRange())
	local radius = spinWebAbility:GetSpecialValueInt("radius")
	local laneCreeps = bot:GetNearbyLaneCreeps(castRange, true)
	local enemyTowers = bot:GetNearbyTowers(castRange, true)
	botTarget = Fu.GetProperTarget(bot)
	if Fu.IsStuck(bot) and not DoesLocationHaveWeb(bot:GetLocation(), radius) then
		return BOT_ACTION_DESIRE_HIGH, bot:GetLocation()
	end
	if Fu.IsInTeamFight(bot, 1200) then
		local aoeLocation = bot:FindAoELocation(true, true, bot:GetLocation(), castRange, radius, 0, 0)
		local enemiesInWeb = Fu.GetEnemiesNearLoc(aoeLocation.targetloc, radius / 1.7)
		if
			enemiesInWeb ~= nil
			and #enemiesInWeb >= 2
			and not DoesLocationHaveWeb(aoeLocation.targetloc, radius)
			and not Fu.IsLocationInChrono(aoeLocation.targetloc)
			and not Fu.IsLocationInBlackHole(aoeLocation.targetloc)
		then
			return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
		end
	end
	if isEngaging then
		if
			Fu.IsValidTarget(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not Fu.IsDisabled(botTarget)
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
			and not DoesLocationHaveWeb(botTarget:GetLocation(), radius)
			and not Fu.IsLocationInChrono(botTarget:GetLocation())
			and not Fu.IsLocationInBlackHole(botTarget:GetLocation())
		then
			local alliesNearTarget = Fu.GetNearbyHeroes(botTarget, 1200, true, BOT_MODE_NONE)
			local enemiesNearTarget = Fu.GetNearbyHeroes(botTarget, 1200, false, BOT_MODE_NONE)
			if alliesNearTarget ~= nil and enemiesNearTarget ~= nil and #alliesNearTarget >= #enemiesNearTarget then
				return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
			end
		end
	end
	if isRetreating then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, 1200, false, BOT_MODE_NONE)
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE)
		if
			nearbyAllies ~= nil
			and nearbyEnemies ~= nil
			and Fu.IsValidHero(nearbyEnemies[1])
			and Fu.IsInRange(bot, nearbyEnemies[1], 600)
			and Fu.IsChasingTarget(nearbyEnemies[1], bot)
			and not Fu.IsSuspiciousIllusion(nearbyEnemies[1])
			and not Fu.IsDisabled(nearbyEnemies[1])
			and not DoesLocationHaveWeb(bot:GetLocation(), radius)
		then
			local chaserAllies = Fu.GetNearbyHeroes(nearbyEnemies[1], 1200, false, BOT_MODE_NONE)
			if chaserAllies ~= nil and (#chaserAllies > #nearbyAllies or bot:WasRecentlyDamagedByAnyHero(1.5)) then
				return BOT_ACTION_DESIRE_HIGH, bot:GetLocation()
			end
		end
	end
	if Fu.IsPushing(bot) then
		if
			laneCreeps ~= nil
			and #laneCreeps >= 4
			and not DoesLocationHaveWeb(Fu.GetCenterOfUnits(laneCreeps), radius)
		then
			return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(laneCreeps)
		end
		if
			enemyTowers ~= nil
			and #enemyTowers >= 1
			and Fu.CanBeAttacked(enemyTowers[1])
			and not DoesLocationHaveWeb(enemyTowers[1]:GetLocation(), radius)
		then
			return BOT_ACTION_DESIRE_HIGH, enemyTowers[1]:GetLocation()
		end
	end
	if Fu.IsLaning(bot) then
		if
			laneCreeps ~= nil
			and #laneCreeps >= 4
			and not DoesLocationHaveWeb(Fu.GetCenterOfUnits(laneCreeps), radius)
		then
			return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(laneCreeps)
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if
			Fu.IsRoshan(botTarget)
			and Fu.IsInRange(bot, botTarget, 500)
			and isAttacking
			and not DoesLocationHaveWeb(botTarget:GetLocation(), radius)
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if
			Fu.IsTormentor(botTarget)
			and Fu.IsInRange(bot, botTarget, 500)
			and isAttacking
			and not DoesLocationHaveWeb(botTarget:GetLocation(), radius)
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.ConsiderSpawnSpiderlings()
	if not spawnSpiderlingsAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local castRange = Fu.GetProperCastRange(false, bot, spawnSpiderlingsAbility:GetCastRange())
	local damage = spawnSpiderlingsAbility:GetSpecialValueInt("damage")
	local enemiesInRange = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(enemiesInRange) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
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
	-- fix: on heroes Spawn Spiderlings was only a finisher. Engaging, throw it at the target for its
	-- damage (220-420) and slow (25-45% for 4s, game data); cooldown is only 7-9s.
	local spiderTarget = Fu.GetProperTarget(bot)
	if
		isEngaging
		and Fu.IsValidHero(spiderTarget)
		and Fu.IsInRange(bot, spiderTarget, castRange)
		and Fu.CanCastOnNonMagicImmune(spiderTarget)
		and Fu.CanCastOnTargetAdvanced(spiderTarget)
		and not Fu.IsSuspiciousIllusion(spiderTarget)
		and not spiderTarget:HasModifier("modifier_templar_assassin_refraction_absorb")
		and Fu.GetManaAfter(spawnSpiderlingsAbility:GetManaCost()) > 0.2
	then
		if DotaTime() >= (bot._broodSpawnLogAt or -999) then
			bot._broodSpawnLogAt = DotaTime() + 10
			pcall(
				print,
				string.format(
					"[OHA-BROODMOTHER] t=%.0f spiderlings engage %s",
					DotaTime(),
					(string.gsub(spiderTarget:GetUnitName(), "npc_dota_hero_", ""))
				)
			)
		end
		return BOT_ACTION_DESIRE_HIGH, spiderTarget
	end
	local laneCreeps = bot:GetNearbyLaneCreeps(castRange, true)
	for _, creep in pairs(laneCreeps) do
		if
			Fu.IsValid(creep)
			and Fu.CanBeAttacked(creep)
			and Fu.CanKillTarget(creep, damage, DAMAGE_TYPE_MAGICAL)
			and not isRetreating
		then
			return BOT_ACTION_DESIRE_HIGH, creep
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function DoesLocationHaveWeb(location, radius)
	for _, unit in pairs(GetUnitList(UNIT_LIST_ALLIES)) do
		if
			Fu.IsValid(unit)
			and unit:GetUnitName() == "npc_dota_broodmother_web"
			and GetUnitToLocationDistance(unit, location) < radius
		then
			return true
		end
	end
	return false
end
return X
