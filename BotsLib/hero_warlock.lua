-- Warlock: skill build, item build, and ability use for this hero.
local X = {}
local bot = GetBot()
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local AbilityContext = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local Minion = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local sTalentList = Fu.Skill.GetTalentList(bot)
local sAbilityList = Fu.Skill.GetAbilityList(bot)
local sRole = Fu.Item.GetRoleItemsBuyList(bot)
local tTalentTreeList = { ["t25"] = { 0, 10 }, ["t20"] = { 0, 10 }, ["t15"] = { 0, 10 }, ["t10"] = { 10, 0 } }
local tAllAbilityBuildList = { { 2, 1, 2, 1, 2, 6, 2, 1, 1, 3, 6, 3, 3, 3, 6 } }
local nAbilityBuildList = Fu.Skill.GetRandomBuild(tAllAbilityBuildList)
local nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList)
local sRoleItemsBuyList = {}
sRoleItemsBuyList["pos_4"] = {
	"item_tango",
	"item_tango",
	"item_double_branches",
	"item_blood_grenade",
	"item_magic_wand",
	"item_arcane_boots",
	"item_glimmer_cape",
	"item_guardian_greaves",
	"item_aghanims_shard",
	"item_force_staff",
	"item_ultimate_scepter",
	"item_shivas_guard",
	"item_refresher",
	"item_octarine_core",
	"item_ultimate_scepter_2",
	"item_moon_shard",
}
sRoleItemsBuyList["pos_5"] = {
	"item_tango",
	"item_tango",
	"item_double_branches",
	"item_blood_grenade",
	"item_magic_wand",
	"item_arcane_boots",
	"item_glimmer_cape",
	"item_pipe",
	"item_aghanims_shard",
	"item_force_staff",
	"item_ultimate_scepter",
	"item_shivas_guard",
	"item_aether_lens",
	"item_refresher",
	"item_octarine_core",
	"item_ultimate_scepter_2",
	"item_moon_shard",
}
sRoleItemsBuyList["pos_1"] = {
	"item_tango",
	"item_tango",
	"item_double_branches",
	"item_arcane_boots",
	"item_magic_wand",
	"item_glimmer_cape",
	"item_force_staff",
	"item_aghanims_shard",
	"item_ultimate_scepter",
	"item_shivas_guard",
	"item_maelstrom",
	"item_gungir",
	"item_refresher",
	"item_octarine_core",
	"item_ultimate_scepter_2",
	"item_moon_shard",
}
sRoleItemsBuyList["pos_2"] = {
	"item_mage_outfit",
	"item_shadow_amulet",
	"item_kaya",
	-- Scepter and Refresher come before Shiva's (they replaced Veil of Discord and an early
	-- Maelstrom that sat idle on a hero who barely right-clicks).
	"item_ultimate_scepter",
	"item_glimmer_cape",
	"item_kaya_and_sange",
	"item_refresher",
	"item_shivas_guard",
	"item_aghanims_shard",
	"item_gungir",
	"item_sheepstick",
	"item_heart",
	"item_moon_shard",
	"item_ultimate_scepter_2",
	"item_travel_boots_2",
}
sRoleItemsBuyList["pos_3"] = sRoleItemsBuyList["pos_2"]
X["sBuyList"] = sRoleItemsBuyList[sRole]
X["sSellList"] = { "item_black_king_bar", "item_quelling_blade", "item_heart", "item_glimmer_cape" }
if Fu.Role.IsPvNMode() or Fu.Role.IsAllShadow() then
	X["sBuyList"], X["sSellList"] = { "PvN_priest" }, {}
end
nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"] = Fu.SetUserHeroInit(nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"])
X["sSkillList"] = Fu.Skill.GetSkillList(sAbilityList, nAbilityBuildList, sTalentList, nTalentBuildList)
X["bDeafaultAbility"] = false
-- Cast when cornered (retreating into 3+ enemies with no way out), before running further.
X["LastStandSpells"] = { { name = "warlock_rain_of_chaos", kind = "point" } }
X["bDeafaultItem"] = true
local fatalBondsAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[1]), "sAbilityList[1]", "warlock")
local shadowWordAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[2]), "sAbilityList[2]", "warlock")
local upheavalAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[3]), "sAbilityList[3]", "warlock")
local chaoticOfferingAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[6]), "sAbilityList[6]", "warlock")
local talent2 = SafeAbility(bot:GetAbilityByName(sTalentList[2]), "sTalentList[2]", "warlock")
local talent6 = SafeAbility(bot:GetAbilityByName(sTalentList[6]), "sTalentList[6]", "warlock")
local fatalBondsDesire, fatalBondsTarget
local shadowWordDesire, shadowWordTarget
local upheavalDesire, upheavalLocation
local chaoticOfferingDesire, chaoticOfferingLocation
local refresherComboDesire, refresherComboLocation
local hpRatio
local aetherRange = 0
local refresher = nil
function X.MinionThink(minion)
	if Minion.IsValidUnit(minion) and not Fu.IsKeyWordUnit("npc_dota_warlock_minor_imp", minion) then
		Minion.IllusionThink(minion)
	end
end
function X.SkillsComplement()
	X.WarlockShouldMove()
	if Fu.CanNotUseAbility(bot) or bot:IsInvisible() then
		return
	end
	local context = AbilityContext.Build(bot)
	aetherRange = context.aetherRange
	hpRatio = context.hp
	refresher = Fu.IsItemAvailable("item_refresher")
	refresherComboDesire, refresherComboLocation = X.ConsiderRFR()
	if refresherComboDesire > 0 then
		Fu.SetQueuePtToINT(bot, true)
		bot:ActionQueue_UseAbilityOnLocation(chaoticOfferingAbility, refresherComboLocation + RandomVector(50))
		bot:ActionQueue_UseAbility(refresher)
		bot:ActionQueue_UseAbilityOnLocation(chaoticOfferingAbility, refresherComboLocation + RandomVector(50))
		return
	end
	chaoticOfferingDesire, chaoticOfferingLocation = X.ConsiderR()
	if chaoticOfferingDesire > 0 then
		Fu.SetQueuePtToINT(bot, true)
		bot:ActionQueue_UseAbilityOnLocation(chaoticOfferingAbility, chaoticOfferingLocation)
		return
	end
	fatalBondsDesire, fatalBondsTarget = X.ConsiderQ()
	if fatalBondsDesire > 0 then
		Fu.SetQueuePtToINT(bot, true)
		bot:ActionQueue_UseAbilityOnEntity(fatalBondsAbility, fatalBondsTarget)
		return
	end
	shadowWordDesire, shadowWordTarget = X.ConsiderW()
	if shadowWordDesire > 0 then
		Fu.SetQueuePtToINT(bot, true)
		bot:ActionQueue_UseAbilityOnEntity(shadowWordAbility, shadowWordTarget)
		return
	end
	upheavalDesire, upheavalLocation = X.ConsiderE()
	if upheavalDesire > 0 then
		Fu.SetQueuePtToINT(bot, true)
		bot:ActionQueue_UseAbilityOnLocation(upheavalAbility, upheavalLocation)
		return
	end
end
function X.WarlockShouldMove()
	if
		bot:IsAlive()
		and bot:IsChanneling()
		and not bot:HasModifier("modifier_teleporting")
		and bot:GetActiveMode() ~= BOT_MODE_SIDE_SHOP
		and bot:GetActiveMode() ~= BOT_MODE_WATCHER
		and #Fu.GetNearbyHeroes(bot, 1000, true, BOT_MODE_NONE) >= 1
		and bot:WasRecentlyDamagedByAnyHero(3)
		and Fu.GetHP(bot) < 0.5
	then
		bot:Action_ClearActions(true)
		bot:Action_MoveToLocation(Fu.GetTeamFountain())
		return
	end
end
function X.ConsiderR()
	if not chaoticOfferingAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	-- Hold the ult for Fatal Bonds only when Bonds is going out this think. Waiting on a Bonds
	-- with no valid target (all under BKB) used to stall the ult until HP fell below 50%.
	if bot:GetMana() >= fatalBondsAbility:GetManaCost() + chaoticOfferingAbility:GetManaCost() and hpRatio > 0.5 and X.ConsiderQ() > 0 then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castRange = chaoticOfferingAbility:GetCastRange() + aetherRange
	local castPoint = chaoticOfferingAbility:GetCastPoint()
	local manaCost = chaoticOfferingAbility:GetManaCost()
	local radius = chaoticOfferingAbility:GetSpecialValueInt("aoe")
	local enemyList = Fu.GetEnemyList(bot, 1400)
	local aoe = bot:FindAoELocation(true, true, bot:GetLocation(), castRange, radius, 0, 0)
	if aoe.count >= 2 and #enemyList >= 2 or aoe.count >= 3 then
		return BOT_ACTION_DESIRE_LOW, aoe.targetloc
	end
	if aoe.count >= 1 and Fu.GetHP(bot) < 0.38 and #enemyList >= 1 then
		return BOT_ACTION_DESIRE_LOW, aoe.targetloc
	end
	if Fu.IsGoingOnSomeone(bot) then
		local botTarget = Fu.GetProperTarget(bot)
		if Fu.IsValidHero(botTarget) and Fu.CanCastOnMagicImmune(botTarget) and Fu.IsInRange(botTarget, bot, castRange + 200) then
			if #enemyList >= 2 then
				return BOT_ACTION_DESIRE_HIGH, botTarget:GetExtrapolatedLocation(castPoint)
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function X.ConsiderRFR()
	if not chaoticOfferingAbility:IsFullyCastable() or refresher == nil or not refresher:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	-- Hold the ult for Fatal Bonds only when Bonds is going out this think. Waiting on a Bonds
	-- with no valid target (all under BKB) used to stall the ult until HP fell below 50%.
	if bot:GetMana() >= fatalBondsAbility:GetManaCost() + chaoticOfferingAbility:GetManaCost() and hpRatio > 0.5 and X.ConsiderQ() > 0 then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	if bot:GetMana() < chaoticOfferingAbility:GetManaCost() * 2 + refresher:GetManaCost() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castRange = chaoticOfferingAbility:GetCastRange() + aetherRange
	local castPoint = chaoticOfferingAbility:GetCastPoint()
	local manaCost = chaoticOfferingAbility:GetManaCost()
	local radius = chaoticOfferingAbility:GetSpecialValueInt("aoe")
	local enemyList = Fu.GetEnemyList(bot, 1600)
	if Fu.IsGoingOnSomeone(bot) then
		local botTarget = Fu.GetProperTarget(bot)
		if Fu.IsValidHero(botTarget) and Fu.CanCastOnMagicImmune(botTarget) and Fu.IsInRange(botTarget, bot, castRange + 200) then
			if #enemyList >= 3 then
				return BOT_ACTION_DESIRE_HIGH, botTarget:GetExtrapolatedLocation(castPoint)
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function X.ConsiderE()
	if not upheavalAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	-- Only the ult holds Upheaval now (the channel blocks every cast until it ends). Bonds and Shadow
	-- Word are considered first in SkillsComplement and return when they cast, so a ready-but-unused
	-- Bonds or Word (no target for them) only kept Upheaval from ever going out.
	if chaoticOfferingAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castRange = upheavalAbility:GetCastRange() + 30 + aetherRange
	local castPoint = upheavalAbility:GetCastPoint()
	local manaCost = upheavalAbility:GetManaCost()
	local radius = upheavalAbility:GetSpecialValueInt("aoe")
	if Fu.IsInTeamFight(bot, 1200) then
		local aoe = bot:FindAoELocation(true, true, bot:GetLocation(), castRange, radius / 2, 0, 0)
		if aoe.count >= 2 then
			-- Upheaval does not pierce spell immunity (npc data: SPELL_IMMUNITY_ENEMIES_NO): with the
			-- Bonds/Word gate gone, do not start a 10-16s channel unless 2+ of those heroes can be hit.
			local hittable = 0
			for _, foe in pairs(Fu.GetEnemiesNearLoc(aoe.targetloc, radius / 2)) do
				if Fu.IsValidHero(foe) and Fu.CanCastOnNonMagicImmune(foe) then
					hittable = hittable + 1
				end
			end
			if hittable >= 2 then
				if DotaTime() >= (bot._upheavalLogAt or -999) then
					bot._upheavalLogAt = DotaTime() + 15
					pcall(print, string.format(
						"[OHA-WARLOCK] t=%.0f upheaval heroes=%d bondsReady=%s wordReady=%s",
						DotaTime(),
						hittable,
						tostring(fatalBondsAbility:IsFullyCastable()),
						tostring(shadowWordAbility:IsFullyCastable())
					))
				end
				return BOT_ACTION_DESIRE_LOW, aoe.targetloc
			end
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		local botTarget = Fu.GetProperTarget(bot)
		if Fu.IsValidHero(botTarget) and Fu.CanCastOnNonMagicImmune(botTarget) and Fu.IsInRange(botTarget, bot, castRange + 200) then
			local targetAllies = Fu.GetNearbyHeroes(botTarget, radius, false, BOT_MODE_NONE)
			if #targetAllies >= 2 then
				return BOT_ACTION_DESIRE_HIGH, botTarget:GetExtrapolatedLocation(castPoint)
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
local lastAllyScanTime = -90
function X.ConsiderW()
	if not shadowWordAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castRange = shadowWordAbility:GetCastRange() + 50 + aetherRange
	local castPoint = shadowWordAbility:GetCastPoint()
	local manaCost = shadowWordAbility:GetManaCost()
	local radius = 0
	if talent6:IsTrained() then
		radius = 250
	end
	if DotaTime() >= lastAllyScanTime + 0.5 then
		local healTarget = nil
		local lowestHealth = 100000
		local nearbyAllies = Fu.GetNearbyHeroes(bot, castRange, false, BOT_MODE_NONE)
		if #nearbyAllies > 0 then
			for i = 1, #nearbyAllies do
				if
					not nearbyAllies[i]:HasModifier("modifier_warlock_shadow_word")
					and Fu.CanCastOnNonMagicImmune(nearbyAllies[i])
					and nearbyAllies[i]:GetHealth() <= lowestHealth
					and nearbyAllies[i]:GetHealth() <= 0.65 * nearbyAllies[i]:GetMaxHealth()
				then
					healTarget = nearbyAllies[i]
					lowestHealth = nearbyAllies[i]:GetHealth()
				end
			end
		end
		if healTarget ~= nil then
			return BOT_ACTION_DESIRE_HIGH, healTarget
		end
		lastAllyScanTime = DotaTime()
	end
	if Fu.IsInTeamFight(bot, 1200) then
		if talent6:IsTrained() and false then
			local aoe = bot:FindAoELocation(true, true, bot:GetLocation(), castRange, radius, 0, 0)
			if aoe.count >= 2 then
				return BOT_ACTION_DESIRE_LOW, aoe.targetloc
			end
		else
			local weakestEnemy = nil
			local lowestHealth = 10000
			local nearbyEnemies = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
			for _, enemyHero in pairs(nearbyEnemies) do
				if
					Fu.IsValid(enemyHero)
					and Fu.CanCastOnNonMagicImmune(enemyHero)
					and Fu.CanCastOnTargetAdvanced(enemyHero)
					and not enemyHero:HasModifier("modifier_warlock_shadow_word")
				then
					local health = enemyHero:GetHealth()
					if health < lowestHealth then
						lowestHealth = health
						weakestEnemy = enemyHero
					end
				end
			end
			if weakestEnemy ~= nil then
				return BOT_ACTION_DESIRE_HIGH, weakestEnemy
			end
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		local botTarget = Fu.GetProperTarget(bot)
		if
			Fu.IsValidHero(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.CanCastOnTargetAdvanced(botTarget)
			and Fu.IsInRange(botTarget, bot, castRange)
			and not botTarget:HasModifier("modifier_warlock_shadow_word")
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function X.ConsiderQ()
	if not fatalBondsAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castRange = fatalBondsAbility:GetCastRange() + 50 + aetherRange
	local castPoint = fatalBondsAbility:GetCastPoint()
	local manaCost = fatalBondsAbility:GetManaCost()
	local radius = fatalBondsAbility:GetSpecialValueInt("search_aoe")
	local linkCount = fatalBondsAbility:GetSpecialValueInt("count")
	-- Grouped enemy heroes: Bonds first, on the hero nearest the middle of the group. Every
	-- linked hero then shares the Chaotic Offering stun, the golem's hits and the follow-up.
	local cluster = bot:FindAoELocation(true, true, bot:GetLocation(), castRange, radius, 0, 0)
	if cluster ~= nil and cluster.count >= 2 then
		local best, bestDist = nil, math.huge
		for _, foe in pairs(Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE) or {}) do
			if
				Fu.IsValidHero(foe)
				and Fu.CanCastOnNonMagicImmune(foe)
				and Fu.CanCastOnTargetAdvanced(foe)
				and not Fu.IsSuspiciousIllusion(foe)
			then
				local dist = GetUnitToLocationDistance(foe, cluster.targetloc)
				if dist < bestDist then
					best, bestDist = foe, dist
				end
			end
		end
		if best ~= nil then
			if DotaTime() >= (bot._bondsLogAt or -999) then
				bot._bondsLogAt = DotaTime() + 10
				pcall(print, string.format(
					"[OHA-WARLOCK] t=%.0f fatal-bonds grouped=%d target=%s ultReady=%s",
					DotaTime(),
					cluster.count,
					(string.gsub(best:GetUnitName(), "npc_dota_hero_", "")),
					tostring(chaoticOfferingAbility:IsFullyCastable())
				))
			end
			return BOT_ACTION_DESIRE_HIGH, best
		end
	end
	if Fu.IsInTeamFight(bot, 1000) then
		local aoe = bot:FindAoELocation(true, true, bot:GetLocation(), castRange, radius, 0, 0)
		if aoe.count >= 2 then
			local nearbyEnemies = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
			if Fu.IsValidHero(nearbyEnemies[1]) and Fu.CanCastOnNonMagicImmune(nearbyEnemies[1]) and Fu.CanCastOnTargetAdvanced(nearbyEnemies[1]) then
				return BOT_ACTION_DESIRE_HIGH, nearbyEnemies[1]
			end
		end
	end
	if Fu.IsRetreating(bot) then
		local weakTarget = Fu.GetVulnerableWeakestUnit(bot, true, true, castRange - 100)
		-- Bonds links enemy units, so count enemies around him (GetUnitAllyCountAroundEnemyTarget
		-- counted our own units), as the engage branch below does.
		if weakTarget ~= nil and Fu.GetAroundTargetEnemyUnitCount(weakTarget, radius) >= 3 then
			return BOT_ACTION_DESIRE_HIGH, weakTarget
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		local botTarget = Fu.GetProperTarget(bot)
		if
			Fu.IsValidHero(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.CanCastOnTargetAdvanced(botTarget)
			and Fu.IsInRange(botTarget, bot, castRange)
		then
			if Fu.GetAroundTargetEnemyUnitCount(botTarget, radius) >= 3 then
				return BOT_ACTION_DESIRE_HIGH, botTarget
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
return X
