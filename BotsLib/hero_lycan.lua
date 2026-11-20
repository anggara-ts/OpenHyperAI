-- Lycan: skill build, item build, and ability use for this hero.
local X = {}
local bot = GetBot()
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local AbilityContext = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local Minion = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local sTalentList = Fu.Skill.GetTalentList(bot)
local sAbilityList = Fu.Skill.GetAbilityList(bot)
local sRole = Fu.Item.GetRoleItemsBuyList(bot)
local tTalentTreeList = { ["t25"] = { 0, 10 }, ["t20"] = { 0, 10 }, ["t15"] = { 10, 0 }, ["t10"] = { 10, 0 } }
-- fix: build 1 had the 2nd Shapeshift point at entry 12 (level 13); entry 11 is level 12
local tAllAbilityBuildList =
	{ { 1, 3, 1, 3, 1, 6, 1, 3, 3, 2, 6, 2, 2, 2, 6 }, { 1, 3, 1, 2, 1, 6, 1, 3, 3, 3, 6, 2, 2, 2, 6 } }
local nAbilityBuildList = tAllAbilityBuildList[1]
if sRole == "pos_1" then
	nAbilityBuildList = tAllAbilityBuildList[1]
end
if sRole == "pos_2" then
	nAbilityBuildList = tAllAbilityBuildList[1]
end
if sRole == "pos_3" then
	nAbilityBuildList = tAllAbilityBuildList[2]
end
local nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList)
if sRole == "pos_1" then
	nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList)
end
if sRole == "pos_2" then
	nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList)
end
if sRole == "pos_3" then
	nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList)
end
local sUtility = "item_team_aura"
local sRoleItemsBuyList = {}
sRoleItemsBuyList["pos_1"] = {
	"item_tango",
	"item_double_branches",
	"item_double_circlet",
	"item_magic_wand",
	"item_double_bracer",
	"item_power_treads",
	"item_ring_of_basilius",
	"item_echo_sabre",
	"item_manta",
	"item_aghanims_shard",
	"item_harpoon",
	"item_orchid",
	"item_black_king_bar",
	"item_bloodthorn",
	"item_skadi",
	"item_moon_shard",
	"item_travel_boots_2",
	"item_ultimate_scepter_2",
}
sRoleItemsBuyList["pos_2"] = {
	"item_tango",
	"item_double_branches",
	"item_double_circlet",
	"item_bottle",
	"item_magic_wand",
	"item_double_bracer",
	"item_power_treads",
	"item_ring_of_basilius",
	"item_echo_sabre",
	"item_manta",
	"item_aghanims_shard",
	"item_harpoon",
	"item_black_king_bar",
	"item_orchid",
	"item_bloodthorn",
	"item_travel_boots",
	"item_skadi",
	"item_moon_shard",
	"item_travel_boots_2",
	"item_ultimate_scepter_2",
}
sRoleItemsBuyList["pos_3"] = {
	"item_tango",
	"item_double_branches",
	"item_magic_stick",
	"item_quelling_blade",
	"item_magic_wand",
	"item_helm_of_the_dominator",
	"item_ring_of_basilius",
	"item_vladmir",
	"item_black_king_bar",
	"item_aghanims_shard",
	"item_assault",
	sUtility,
	"item_travel_boots",
	"item_sheepstick",
	"item_moon_shard",
	"item_travel_boots_2",
	"item_ultimate_scepter_2",
}
sRoleItemsBuyList["pos_4"] = sRoleItemsBuyList["pos_3"]
sRoleItemsBuyList["pos_5"] = sRoleItemsBuyList["pos_3"]
X["sBuyList"] = sRoleItemsBuyList[sRole]
X["sSellList"] = { "item_black_king_bar", "item_quelling_blade" }
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
local summonWolvesAbility = SafeAbility(bot:GetAbilityByName("lycan_summon_wolves"), "lycan_summon_wolves", "lycan")
local howlAbility = SafeAbility(bot:GetAbilityByName("lycan_howl"), "lycan_howl", "lycan")
local feralImpulseAbility = SafeAbility(bot:GetAbilityByName("lycan_feral_impulse"), "lycan_feral_impulse", "lycan")
local wolfBiteAbility = SafeAbility(bot:GetAbilityByName("lycan_wolf_bite"), "lycan_wolf_bite", "lycan")
local shapeshiftAbility = SafeAbility(bot:GetAbilityByName("lycan_shapeshift"), "lycan_shapeshift", "lycan")
local summonWolvesDesire
local howlDesire
local shapeshiftDesire
local botTarget
local isGoingOnSomeone
local isAttacking
function X.SkillsComplement()
	if Fu.CanNotUseAbility(bot) then
		return
	end
	isGoingOnSomeone = Fu.IsGoingOnSomeone(bot)
	isAttacking = Fu.IsAttacking(bot)
	shapeshiftDesire = X.ConsiderShapeShift()
	if shapeshiftDesire > 0 then
		bot:Action_UseAbility(shapeshiftAbility)
		return
	end
	howlDesire = X.ConsiderHowl()
	if howlDesire > 0 then
		bot:Action_UseAbility(howlAbility)
		return
	end
	summonWolvesDesire = X.ConsiderSummonWolves()
	if summonWolvesDesire > 0 then
		bot:Action_UseAbility(summonWolvesAbility)
		return
	end
	-- Wolf Bite (Scepter) was loaded but never cast. Last in the order so it never blocks the rest.
	local biteDesire, biteTarget = X.ConsiderWolfBite()
	if biteDesire > 0 then
		bot:Action_UseAbilityOnEntity(wolfBiteAbility, biteTarget)
		return
	end
end
-- Data/datafeed: Wolf Bite is unit-target on an allied hero or creep-hero, cast range 300; the
-- bitten ally gets Shapeshift's properties and shares lifesteal with Lycan. Cast it on the
-- hardest-hitting allied hero in a fight.
function X.ConsiderWolfBite()
	if wolfBiteAbility:IsHidden() or not wolfBiteAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	-- After an attempt, wait 3 s: if the game ever rejects the order, it must not be re-issued every
	-- think and keep replacing Lycan's attack order.
	if DotaTime() < (bot._ohaWolfBiteTryAt or -999) + 3 then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	if not (isGoingOnSomeone or Fu.IsInTeamFight(bot, 1200)) then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local biteRange = wolfBiteAbility:GetCastRange() + 200
	local bestAlly, bestScore = nil, -1
	for _, ally in pairs(Fu.GetNearbyHeroes(bot, biteRange, false, BOT_MODE_NONE) or {}) do
		if
			Fu.IsValidHero(ally)
			and ally ~= bot
			and not ally:IsIllusion()
			and not Fu.IsMeepoClone(ally)
			and (Fu.IsGoingOnSomeone(ally) or Fu.IsInTeamFight(ally, 1200))
			and Fu.IsValidHero(ally:GetAttackTarget())
		then
			local score = ally:GetAttackDamage() * ally:GetAttackSpeed()
			if Fu.IsCore(ally) then
				score = score + 10000
			end
			if score > bestScore then
				bestAlly, bestScore = ally, score
			end
		end
	end
	if bestAlly ~= nil then
		bot._ohaWolfBiteTryAt = DotaTime()
		if DotaTime() >= (bot._ohaWolfBiteLogAt or -999) then
			bot._ohaWolfBiteLogAt = DotaTime() + 5
			pcall(
				print,
				string.format(
					"[OHA-LYCAN] t=%.0f wolf bite on %s",
					DotaTime(),
					(string.gsub(bestAlly:GetUnitName(), "npc_dota_hero_", ""))
				)
			)
		end
		return BOT_ACTION_DESIRE_HIGH, bestAlly
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function X.ConsiderSummonWolves()
	if not summonWolvesAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
	end
	for _, unit in pairs(GetUnitList(UNIT_LIST_ALLIES)) do
		if Fu.IsValid(unit) and string.find(unit:GetUnitName(), "npc_dota_lycan_wolf") then
			return BOT_ACTION_DESIRE_NONE
		end
	end
	botTarget = Fu.GetProperTarget(bot)
	if isGoingOnSomeone then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, 1200, false, BOT_MODE_NONE)
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE)
		if
			Fu.IsValidTarget(botTarget)
			and Fu.IsInRange(bot, botTarget, 800)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and nearbyAllies ~= nil
			and nearbyEnemies
			and #nearbyAllies >= #nearbyEnemies
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsPushing(bot) or Fu.IsDefending(bot) or Fu.IsLaning(bot) then
		local nearbyCreeps = bot:GetNearbyLaneCreeps(800, true)
		if isAttacking then
			if nearbyCreeps ~= nil and #nearbyCreeps >= 1 then
				return BOT_ACTION_DESIRE_HIGH
			end
			local nearbyTowers = bot:GetNearbyTowers(600, true)
			if nearbyTowers ~= nil and #nearbyTowers >= 1 and Fu.CanBeAttacked(nearbyTowers[1]) then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	if Fu.IsFarming(bot) then
		local nearbyNeutrals = bot:GetNearbyNeutralCreeps(600)
		local nearbyCreeps = bot:GetNearbyLaneCreeps(600, true)
		if isAttacking then
			if nearbyNeutrals ~= nil and #nearbyNeutrals >= 2 or nearbyCreeps ~= nil and #nearbyCreeps >= 3 then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if Fu.IsRoshan(botTarget) and Fu.IsInRange(bot, botTarget, 400) and isAttacking then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, 400) and isAttacking then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderHowl()
	if not howlAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
	end
	local timeOfDay = Fu.CheckTimeOfDay()
	botTarget = Fu.GetProperTarget(bot)
	if timeOfDay == "night" then
		for _, allyHero in pairs(GetUnitList(UNIT_LIST_ALLIED_HEROES)) do
			if Fu.IsValidHero(allyHero) and not allyHero:IsIllusion() then
				if Fu.IsCore(allyHero) and Fu.IsGoingOnSomeone(allyHero) then
					local allyTarget = allyHero:GetAttackTarget()
					if
						Fu.IsValidTarget(allyTarget)
						-- Was IsInRange(bot, ...): measured from Lycan, so the global night Howl only
						-- helped an ally core fighting next to Lycan. The ally must be in range.
						and Fu.IsInRange(allyHero, allyTarget, allyHero:GetAttackRange() + 150)
						and allyHero:IsFacingLocation(allyTarget:GetLocation(), 30)
						and Fu.IsAttacking(allyHero)
						and not Fu.IsSuspiciousIllusion(allyTarget)
					then
						return BOT_ACTION_DESIRE_HIGH
					end
				end
			end
		end
		local teamFightLocation = Fu.GetTeamFightLocation(bot)
		if teamFightLocation ~= nil then
			if GetUnitToLocationDistance(bot, teamFightLocation) > 1600 then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	if isGoingOnSomeone then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, 1200, false, BOT_MODE_NONE)
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE)
		if
			Fu.IsValidTarget(botTarget)
			and Fu.IsInRange(bot, botTarget, 800)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and nearbyAllies ~= nil
			and nearbyEnemies
			and #nearbyAllies >= #nearbyEnemies
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsRetreating(bot) then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, 800, false, BOT_MODE_NONE)
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, 800, true, BOT_MODE_NONE)
		if
			nearbyAllies ~= nil
			and nearbyEnemies ~= nil
			and (#nearbyEnemies > #nearbyAllies or Fu.GetHP(bot) < 0.75 and bot:WasRecentlyDamagedByAnyHero(1.7))
			and Fu.IsValidHero(nearbyEnemies[1])
			and Fu.IsInRange(bot, nearbyEnemies[1], 450)
			and bot:IsFacingLocation(Fu.GetEscapeLoc(), 30)
			and nearbyEnemies[1]:IsFacingLocation(bot:GetLocation(), 30)
			and not Fu.IsSuspiciousIllusion(nearbyEnemies[1])
			and not Fu.IsDisabled(nearbyEnemies[1])
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsPushing(bot) or Fu.IsDefending(bot) then
		local nearbyCreeps = bot:GetNearbyCreeps(600, true)
		if isAttacking then
			if nearbyCreeps ~= nil and #nearbyCreeps >= 2 then
				return BOT_ACTION_DESIRE_HIGH
			end
			local nearbyTowers = bot:GetNearbyTowers(600, true)
			if nearbyTowers ~= nil and #nearbyTowers >= 1 and Fu.CanBeAttacked(nearbyTowers[1]) then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
		local alliesNearby = Fu.GetNearbyHeroes(bot, 900, false, BOT_MODE_NONE)
		if alliesNearby ~= nil and #alliesNearby >= 2 and nearbyCreeps ~= nil and #nearbyCreeps >= 1 then
			return BOT_ACTION_DESIRE_MODERATE
		end
	end
	if Fu.IsFarming(bot) then
		local nearbyNeutrals = bot:GetNearbyNeutralCreeps(300)
		local nearbyCreeps = bot:GetNearbyLaneCreeps(600, true)
		if isAttacking then
			if nearbyNeutrals ~= nil and #nearbyNeutrals >= 2 or nearbyCreeps ~= nil and #nearbyCreeps >= 3 then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if Fu.IsRoshan(botTarget) and Fu.IsInRange(bot, botTarget, 400) and isAttacking then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, 400) and isAttacking then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderShapeShift()
	if not shapeshiftAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
	end
	if Fu.IsInTeamFight(bot, 1000) then
		return BOT_ACTION_DESIRE_HIGH
	end
	if isGoingOnSomeone then
		botTarget = Fu.GetProperTarget(bot)
		local nearbyAllies = Fu.GetNearbyHeroes(bot, 1200, false, BOT_MODE_NONE)
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE)
		if
			Fu.IsValidTarget(botTarget)
			and Fu.IsInRange(bot, botTarget, 800)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and nearbyAllies ~= nil
			and nearbyEnemies
			and #nearbyAllies >= #nearbyEnemies
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	local enemiesInRange = Fu.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE)
	if enemiesInRange ~= nil and #enemiesInRange >= 1 then
		for _, enemyHero in pairs(enemiesInRange) do
			if
				Fu.IsValidTarget(enemyHero)
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and Fu.GetHP(enemyHero) < 0.5
				and not enemyHero:IsFacingLocation(bot:GetLocation(), 60)
			then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	if Fu.IsRetreating(bot) then
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, 900, true, BOT_MODE_NONE)
		if
			nearbyEnemies ~= nil
			and #nearbyEnemies >= 1
			and Fu.GetHP(bot) < 0.3
			and bot:WasRecentlyDamagedByAnyHero(2.0)
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
return X
