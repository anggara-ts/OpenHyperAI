-- Shadow Demon: skill build, item build, and ability use for this hero.
local X = {}
local bot = GetBot()
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local AbilityContext = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local Minion = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local sTalentList = Fu.Skill.GetTalentList(bot)
local sAbilityList = Fu.Skill.GetAbilityList(bot)
local sRole = Fu.Item.GetRoleItemsBuyList(bot)
local tTalentTreeList = { ["t25"] = { 10, 0 }, ["t20"] = { 10, 0 }, ["t15"] = { 10, 0 }, ["t10"] = { 10, 0 } }
local tAllAbilityBuildList = { { 3, 1, 3, 1, 3, 6, 3, 1, 1, 2, 6, 2, 2, 2, 6 } }
local nAbilityBuildList = Fu.Skill.GetRandomBuild(tAllAbilityBuildList)
local nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList)
local sUtility = RandomInt(1, 2) == 1 and "item_glimmer_cape" or "item_force_staff"
local sRoleItemsBuyList = {}
-- Stratz 7.41f, week of 9 Nov 2026: pos 4, 14,595 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_4"] = {
	"item_tango",
	"item_blood_grenade",
	"item_double_branches",
	"item_magic_stick",
	"item_faerie_fire",
	"item_magic_wand",
	"item_arcane_boots",
	"item_blink",
	"item_aether_lens",
	sUtility,
	"item_aghanims_shard",
	"item_aeon_disk",
	"item_cyclone",
	"item_moon_shard",
	"item_ultimate_scepter_2",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 5, 20,850 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_5"] = {
	"item_tango",
	"item_blood_grenade",
	"item_double_branches",
	"item_magic_stick",
	"item_faerie_fire",
	"item_magic_wand",
	"item_arcane_boots",
	"item_blink",
	"item_aether_lens",
	"item_aghanims_shard",
	"item_ultimate_scepter",
	"item_ultimate_scepter_2",
	"item_cyclone",
	"item_sheepstick",
	"item_lotus_orb",
	"item_wind_waker",
	"item_moon_shard",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 3 has 332 matches, built from pos 2 (1,121) (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_3"] = {
	"item_tango",
	"item_double_branches",
	"item_circlet",
	"item_faerie_fire",
	"item_mantle",
	"item_null_talisman",
	"item_magic_wand",
	"item_arcane_boots",
	"item_aether_lens",
	"item_blink",
	"item_travel_boots",
	"item_ultimate_scepter",
	"item_ultimate_scepter_2",
	"item_force_staff",
	"item_bloodthorn",
	"item_meteor_hammer",
	"item_hurricane_pike",
	"item_aghanims_shard",
	"item_moon_shard",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 1 has 182 matches, built from pos 2 (1,121) (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_1"] = {
	"item_tango",
	"item_double_branches",
	"item_circlet",
	"item_faerie_fire",
	"item_mantle",
	"item_null_talisman",
	"item_magic_wand",
	"item_arcane_boots",
	"item_aether_lens",
	"item_blink",
	"item_travel_boots",
	"item_ultimate_scepter",
	"item_ultimate_scepter_2",
	"item_force_staff",
	"item_bloodthorn",
	"item_meteor_hammer",
	"item_hurricane_pike",
	"item_aghanims_shard",
	"item_moon_shard",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 2, 1,121 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_2"] = {
	"item_tango",
	"item_double_branches",
	"item_circlet",
	"item_faerie_fire",
	"item_mantle",
	"item_null_talisman",
	"item_magic_wand",
	"item_arcane_boots",
	"item_aether_lens",
	"item_blink",
	"item_travel_boots",
	"item_ultimate_scepter",
	"item_ultimate_scepter_2",
	"item_force_staff",
	"item_bloodthorn",
	"item_meteor_hammer",
	"item_hurricane_pike",
	"item_aghanims_shard",
	"item_moon_shard",
}
X["sBuyList"] = sRoleItemsBuyList[sRole]
X["sSellList"] = { "item_cyclone", "item_magic_wand", "item_ultimate_scepter", "item_magic_wand" }
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
local disruptionAbility =
	SafeAbility(bot:GetAbilityByName("shadow_demon_disruption"), "shadow_demon_disruption", "shadow_demon")
local disseminateAbility =
	SafeAbility(bot:GetAbilityByName("shadow_demon_disseminate"), "shadow_demon_disseminate", "shadow_demon")
local shadowPoisonAbility =
	SafeAbility(bot:GetAbilityByName("shadow_demon_shadow_poison"), "shadow_demon_shadow_poison", "shadow_demon")
local shadowPoisonReleaseAbility = SafeAbility(
	bot:GetAbilityByName("shadow_demon_shadow_poison_release"),
	"shadow_demon_shadow_poison_release",
	"shadow_demon"
)
local demonicCleanseAbility =
	SafeAbility(bot:GetAbilityByName("shadow_demon_demonic_cleanse"), "shadow_demon_demonic_cleanse", "shadow_demon")
local demonicPurgeAbility =
	SafeAbility(bot:GetAbilityByName("shadow_demon_demonic_purge"), "shadow_demon_demonic_purge", "shadow_demon")
local disruptionDesire, disruptionTarget
local disseminateDesire, disseminateTarget
local shadowPoisonDesire, shadowPoisonLocation
local shadowPoisonReleaseDesire
local demonicCleanseDesire, demonicCleanseTarget
local demonicPurgeDesire, demonicPurgeTarget
local botTarget
local isGoingOnSomeone
local isInTeamFight
function X.SkillsComplement()
	if Fu.CanNotUseAbility(bot) then
		return
	end
	local context = AbilityContext.Build(bot)
	isGoingOnSomeone = context.isEngaging
	isInTeamFight = context.isTeamFight
	-- An enemy under our Disruption: Shadow Poison on the spot right away (Valve data: "Shadow
	-- Poison can affect units under Disruption"); the normal rule waited for the target to show.
	if X.ConsiderPoisonDisrupted() then
		return
	end
	disruptionDesire, disruptionTarget = X.ConsiderDisruption()
	if disruptionDesire > 0 then
		if Fu.IsValidHero(disruptionTarget) and disruptionTarget:GetTeam() ~= GetTeam() then
			local ok, duration = pcall(function()
				return disruptionAbility:GetSpecialValueFloat("disruption_duration")
			end)
			bot._disrupted = {
				loc = disruptionTarget:GetLocation(),
				untilAt = DotaTime()
					+ math.max(0, disruptionAbility:GetCastPoint())
					+ ((ok and type(duration) == "number" and duration > 0) and duration or 2.75),
			}
		end
		bot:Action_UseAbilityOnEntity(disruptionAbility, disruptionTarget)
		return
	end
	demonicCleanseDesire, demonicCleanseTarget = X.ConsiderDemonicCleanse()
	if demonicCleanseDesire > 0 then
		bot:Action_UseAbilityOnEntity(demonicCleanseAbility, demonicCleanseTarget)
		return
	end
	demonicPurgeDesire, demonicPurgeTarget = X.ConsiderDemonicPurge()
	if demonicPurgeDesire > 0 then
		bot:Action_UseAbilityOnEntity(demonicPurgeAbility, demonicPurgeTarget)
		return
	end
	disseminateDesire, disseminateTarget = X.ConsiderDisseminate()
	if disseminateDesire > 0 then
		bot:Action_UseAbilityOnEntity(disseminateAbility, disseminateTarget)
		return
	end
	shadowPoisonDesire, shadowPoisonLocation = X.ConsiderShadowPoison()
	if shadowPoisonDesire > 0 then
		bot:Action_UseAbilityOnLocation(shadowPoisonAbility, shadowPoisonLocation)
		return
	end
	shadowPoisonReleaseDesire = X.ConsiderShadowPoisonRelease()
	if shadowPoisonReleaseDesire > 0 then
		bot:Action_UseAbility(shadowPoisonReleaseAbility)
		return
	end
end
function X.ConsiderPoisonDisrupted()
	local disrupted = bot._disrupted
	if disrupted == nil then
		return false
	end
	if DotaTime() > disrupted.untilAt then
		bot._disrupted = nil
		return false
	end
	if not shadowPoisonAbility:IsFullyCastable() then
		return false
	end
	local range = Fu.GetProperCastRange(false, bot, shadowPoisonAbility:GetCastRange())
	if GetUnitToLocationDistance(bot, disrupted.loc) > range then
		return false
	end
	bot:Action_UseAbilityOnLocation(shadowPoisonAbility, disrupted.loc)
	return true
end
function X.ConsiderDisruption()
	if not disruptionAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castRange = Fu.GetProperCastRange(false, bot, disruptionAbility:GetCastRange())
	local duration = disruptionAbility:GetSpecialValueFloat("disruption_duration")
	botTarget = Fu.GetProperTarget(bot)
	local nearbyEnemies = Fu.GetNearbyHeroes(bot, castRange + 150, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and Fu.CanCastOnTargetAdvanced(enemyHero)
			and (enemyHero:IsChanneling() or Fu.IsCastingUltimateAbility(enemyHero))
			and not Fu.IsSuspiciousIllusion(enemyHero)
		then
			return BOT_ACTION_DESIRE_HIGH, enemyHero
		end
	end
	local nearbyAllies = Fu.GetNearbyHeroes(bot, castRange + 150, false, BOT_MODE_NONE)
	for _, allyHero in pairs(nearbyAllies) do
		if
			Fu.IsValidHero(allyHero)
			and not allyHero:IsIllusion()
			and not allyHero:HasModifier("modifier_obsidian_destroyer_astral_imprisonment_prison")
		then
			if
				allyHero:HasModifier("modifier_enigma_black_hole_pull")
				or allyHero:HasModifier("modifier_faceless_void_chronosphere_freeze")
				or allyHero:HasModifier("modifier_legion_commander_duel")
				or allyHero:HasModifier("modifier_necrolyte_reapers_scythe")
			then
				return BOT_ACTION_DESIRE_HIGH, allyHero
			end
		end
		local enemiesNearAlly = Fu.GetNearbyHeroes(allyHero, 1200, true, BOT_MODE_NONE)
		if Fu.IsRetreating(allyHero) and allyHero:WasRecentlyDamagedByAnyHero(2) and not allyHero:IsIllusion() then
			if
				enemiesNearAlly ~= nil
				and #enemiesNearAlly >= 1
				and Fu.IsValidHero(enemiesNearAlly[1])
				and Fu.CanCastOnNonMagicImmune(enemiesNearAlly[1])
				and Fu.CanCastOnTargetAdvanced(enemiesNearAlly[1])
				and Fu.IsInRange(allyHero, enemiesNearAlly[1], 400)
				and Fu.IsInRange(bot, enemiesNearAlly[1], castRange)
				and Fu.IsRunning(allyHero)
				and enemiesNearAlly[1]:IsFacingLocation(allyHero:GetLocation(), 30)
				and not Fu.IsDisabled(enemiesNearAlly[1])
				and not Fu.IsTaunted(enemiesNearAlly[1])
				and not Fu.IsSuspiciousIllusion(enemiesNearAlly[1])
				and not enemiesNearAlly[1]:HasModifier("modifier_legion_commander_duel")
				and not enemiesNearAlly[1]:HasModifier("modifier_enigma_black_hole_pull")
				and not enemiesNearAlly[1]:HasModifier("modifier_faceless_void_chronosphere_freeze")
				and not enemiesNearAlly[1]:HasModifier("modifier_necrolyte_reapers_scythe")
			then
				return BOT_ACTION_DESIRE_HIGH, enemiesNearAlly[1]
			end
		end
	end
	if Fu.IsRetreating(bot) then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, 1200, false, BOT_MODE_NONE)
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE)
		if
			nearbyAllies ~= nil
			and nearbyEnemies
			and Fu.IsValidHero(nearbyEnemies[1])
			and Fu.CanCastOnNonMagicImmune(nearbyEnemies[1])
			and Fu.CanCastOnTargetAdvanced(nearbyEnemies[1])
			and Fu.IsInRange(bot, nearbyEnemies[1], castRange)
			and not Fu.IsSuspiciousIllusion(nearbyEnemies[1])
			and not Fu.IsDisabled(nearbyEnemies[1])
			and not nearbyEnemies[1]:HasModifier("modifier_enigma_black_hole_pull")
			and not nearbyEnemies[1]:HasModifier("modifier_faceless_void_chronosphere_freeze")
			and not nearbyEnemies[1]:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			local enemyAllies = Fu.GetNearbyHeroes(nearbyEnemies[1], 1000, false, BOT_MODE_NONE)
			if
				enemyAllies ~= nil
				and (#enemyAllies > #nearbyAllies or Fu.GetHP(bot) < 0.75 and bot:WasRecentlyDamagedByAnyHero(2))
			then
				return BOT_ACTION_DESIRE_HIGH, nearbyEnemies[1]
			end
		end
	end
	if isInTeamFight then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, castRange, false, BOT_MODE_NONE)
		for _, allyHero in pairs(nearbyAllies) do
			if Fu.IsValidHero(allyHero) and not allyHero:IsIllusion() then
				if
					allyHero:HasModifier("modifier_enigma_black_hole_pull")
					or allyHero:HasModifier("modifier_faceless_void_chronosphere_freeze")
					or allyHero:HasModifier("modifier_legion_commander_duel")
					or allyHero:HasModifier("modifier_necrolyte_reapers_scythe")
					or Fu.GetHP(allyHero) < 0.33
				then
					return BOT_ACTION_DESIRE_HIGH, allyHero
				end
			end
		end
		local strongestEnemy = Fu.GetStrongestUnit(castRange, bot, true, false, duration)
		if strongestEnemy == nil then
			strongestEnemy = Fu.GetStrongestUnit(castRange, bot, true, true, duration)
		end
		if
			Fu.IsValidTarget(strongestEnemy)
			and Fu.CanCastOnNonMagicImmune(strongestEnemy)
			and Fu.CanCastOnTargetAdvanced(strongestEnemy)
			and Fu.IsInRange(bot, strongestEnemy, castRange)
			and not Fu.IsSuspiciousIllusion(strongestEnemy)
			and not Fu.IsDisabled(strongestEnemy)
			and not Fu.IsTaunted(strongestEnemy)
			and not strongestEnemy:HasModifier("modifier_abaddon_borrowed_time")
			and not strongestEnemy:HasModifier("modifier_dazzle_shallow_grave")
			and not strongestEnemy:HasModifier("modifier_enigma_black_hole_pull")
			and not strongestEnemy:HasModifier("modifier_faceless_void_chronosphere_freeze")
			and not strongestEnemy:HasModifier("modifier_necrolyte_reapers_scythe")
			and not strongestEnemy:HasModifier("modifier_templar_assassin_refraction_absorb")
		then
			return BOT_ACTION_DESIRE_HIGH, strongestEnemy
		end
	end
	if isGoingOnSomeone then
		local strongestEnemy = Fu.GetStrongestUnit(castRange, bot, true, false, duration)
		if
			Fu.IsValidTarget(strongestEnemy)
			and Fu.CanCastOnNonMagicImmune(strongestEnemy)
			and Fu.CanCastOnTargetAdvanced(strongestEnemy)
			and Fu.IsInRange(bot, strongestEnemy, castRange + 150)
			and not Fu.IsSuspiciousIllusion(strongestEnemy)
			and not Fu.IsDisabled(strongestEnemy)
		then
			local targetAllies = Fu.GetNearbyHeroes(strongestEnemy, 1200, false, BOT_MODE_NONE)
			local targetEnemies = Fu.GetNearbyHeroes(strongestEnemy, 1200, true, BOT_MODE_NONE)
			if targetAllies ~= nil and targetEnemies ~= nil and #targetAllies >= #targetEnemies then
				return BOT_ACTION_DESIRE_HIGH, strongestEnemy
			end
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, 400) then
			if Fu.GetHP(bot) < 0.2 then
				return BOT_ACTION_DESIRE_HIGH, bot
			end
			local nearbyAllies = Fu.GetNearbyHeroes(bot, castRange, false, BOT_MODE_NONE)
			for _, allyHero in pairs(nearbyAllies) do
				if
					Fu.IsValidHero(allyHero)
					and Fu.GetHP(allyHero) < 0.3
					and not allyHero:IsIllusion()
					and not allyHero:HasModifier("modifier_abaddon_borrowed_time")
					and not allyHero:HasModifier("modifier_dazzle_shallow_grave")
					and not allyHero:HasModifier("modifier_templar_assassin_refraction_absorb")
					and not allyHero:HasModifier("modifier_obsidian_destroyer_astral_imprisonment_prison")
				then
					return BOT_ACTION_DESIRE_HIGH, allyHero
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function X.ConsiderDisseminate()
	if not disseminateAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castRange = Fu.GetProperCastRange(false, bot, disseminateAbility:GetCastRange())
	local radius = disseminateAbility:GetSpecialValueInt("radius")
	botTarget = Fu.GetProperTarget(bot)
	if isInTeamFight then
		local aoeLocation = bot:FindAoELocation(true, true, bot:GetLocation(), castRange, radius, 0, 0)
		local enemiesNearLocation = Fu.GetEnemiesNearLoc(aoeLocation.targetloc, radius)
		if enemiesNearLocation ~= nil and #enemiesNearLocation >= 2 then
			if
				Fu.IsValidHero(enemiesNearLocation[1])
				and Fu.CanCastOnNonMagicImmune(enemiesNearLocation[1])
				and Fu.CanCastOnTargetAdvanced(enemiesNearLocation[1])
			then
				return BOT_ACTION_DESIRE_HIGH, enemiesNearLocation[1]
			end
		end
	end
	if isGoingOnSomeone then
		if
			Fu.IsValidHero(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.CanCastOnTargetAdvanced(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			if Fu.GetAroundTargetEnemyUnitCount(botTarget, radius) >= 3 then
				return BOT_ACTION_DESIRE_HIGH, botTarget
			end
		end
	end
	if Fu.IsRetreating(bot) then
		botTarget = Fu.GetVulnerableWeakestUnit(bot, true, true, castRange - 100)
		if Fu.IsValidHero(botTarget) and Fu.GetUnitAllyCountAroundEnemyTarget(botTarget, radius) >= 3 then
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function X.ConsiderShadowPoisonRelease()
	if not shadowPoisonReleaseAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local stackMultiplier = { 1, 2, 4, 8, 16 }
	for _, enemyHero in pairs(GetUnitList(UNIT_LIST_ENEMY_HEROES)) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.IsInRange(enemyHero, bot, 3000)
			and not Fu.IsSuspiciousIllusion(enemyHero)
		then
			local stackCount = Fu.GetModifierCount(enemyHero, "modifier_shadow_demon_shadow_poison")
			local stackDamage = shadowPoisonAbility:GetSpecialValueFloat("stack_damage")
			-- datafeed: release deals 1/2/4/8/16 times the stack damage for 1-5 stacks. The extra "* stackCount"
			-- overrated it (3 stacks counted 12x instead of 4x), so Release fired early on targets it could not kill.
			if
				stackCount >= 5
				or stackCount > 0
					and Fu.CanKillTarget(enemyHero, stackDamage * stackMultiplier[stackCount], DAMAGE_TYPE_MAGICAL)
			then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderShadowPoison()
	if not shadowPoisonAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local castRange = Fu.GetProperCastRange(false, bot, shadowPoisonAbility:GetCastRange())
	local castPoint = shadowPoisonAbility:GetCastPoint()
	local speed = shadowPoisonAbility:GetSpecialValueInt("speed")
	local duration = shadowPoisonAbility:GetDuration()
	botTarget = Fu.GetProperTarget(bot)
	if isGoingOnSomeone then
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not botTarget:HasModifier("modifier_dazzle_shallow_grave") -- fix: modifier name typo ("graves")
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			if Fu.IsInRange(bot, botTarget, castRange / 2 - 150) then
				return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
			else
				local delay = GetUnitToUnitDistance(bot, botTarget) / speed + castPoint
				return BOT_ACTION_DESIRE_HIGH, botTarget:GetExtrapolatedLocation(delay)
			end
		end
	end
	if Fu.IsDefending(bot) then
		local nearbyLaneCreeps = bot:GetNearbyLaneCreeps(castRange, true)
		if nearbyLaneCreeps ~= nil and #nearbyLaneCreeps >= 3 then
			return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(nearbyLaneCreeps)
		end
	end
	if Fu.IsLaning(bot) then
		local strongestEnemy = Fu.GetStrongestUnit(castRange, bot, true, false, duration)
		if
			Fu.IsValidTarget(strongestEnemy)
			and Fu.CanCastOnNonMagicImmune(strongestEnemy)
			and not Fu.IsSuspiciousIllusion(strongestEnemy)
			and not strongestEnemy:HasModifier("modifier_abaddon_borrowed_time")
			and not strongestEnemy:HasModifier("modifier_dazzle_shallow_grave")
			and not strongestEnemy:HasModifier("modifier_necrolyte_reapers_scythe")
			and Fu.GetMP(bot) > 0.65
		then
			if Fu.IsInRange(bot, strongestEnemy, castRange / 2 - 150) then
				return BOT_ACTION_DESIRE_HIGH, strongestEnemy:GetLocation()
			else
				local delay = GetUnitToUnitDistance(bot, strongestEnemy) / speed + castPoint
				return BOT_ACTION_DESIRE_HIGH, strongestEnemy:GetExtrapolatedLocation(delay)
			end
		end
		if not Fu.IsInLaningPhase() then
			local nearbyAllies = Fu.GetNearbyHeroes(bot, 1200, false, BOT_MODE_NONE)
			local nearbyLaneCreeps = bot:GetNearbyLaneCreeps(castRange, true)
			if #nearbyAllies <= 1 and nearbyLaneCreeps ~= nil and #nearbyLaneCreeps >= 3 then
				return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(nearbyLaneCreeps)
			end
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if Fu.IsRoshan(botTarget) and Fu.IsInRange(bot, botTarget, 400) and Fu.IsAttacking(bot) then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if
			Fu.IsTormentor(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, 400)
			and Fu.IsAttacking(bot)
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.ConsiderDemonicPurge()
	if not demonicPurgeAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castRange = demonicPurgeAbility:GetCastRange()
	local duration = demonicPurgeAbility:GetDuration()
	if isInTeamFight then
		local strongestEnemy = Fu.GetStrongestUnit(castRange, bot, true, false, duration)
		local nearbyEnemies = Fu.GetEnemiesNearLoc(bot:GetLocation(), castRange + 200)
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValidTarget(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and not Fu.IsDisabled(enemyHero)
				and not Fu.IsTaunted(enemyHero)
				and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
				and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
				and not enemyHero:HasModifier("modifier_doom_bringer_doom")
				and not enemyHero:HasModifier("modifier_legion_commander_duel")
				and not enemyHero:HasModifier("modifier_enigma_black_hole_pull")
				and not enemyHero:HasModifier("modifier_faceless_void_chronosphere_freeze")
				and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
				and bot:HasScepter()
			then
				if
					enemyHero:GetUnitName() == "npc_dota_hero_bristleback"
					or enemyHero:GetUnitName() == "npc_dota_hero_huskar"
					or enemyHero:GetUnitName() == "npc_dota_hero_tidehunter"
				then
					return BOT_ACTION_DESIRE_HIGH, enemyHero
				end
			end
		end
		if
			Fu.IsValidTarget(strongestEnemy)
			and Fu.CanCastOnNonMagicImmune(strongestEnemy)
			and Fu.CanCastOnTargetAdvanced(strongestEnemy)
			and not Fu.IsSuspiciousIllusion(strongestEnemy)
			and not Fu.IsDisabled(strongestEnemy)
			and not Fu.IsTaunted(strongestEnemy)
			and not strongestEnemy:HasModifier("modifier_abaddon_borrowed_time")
			and not strongestEnemy:HasModifier("modifier_dazzle_shallow_grave")
			and not strongestEnemy:HasModifier("modifier_doom_bringer_doom")
			and not strongestEnemy:HasModifier("modifier_legion_commander_duel")
			and not strongestEnemy:HasModifier("modifier_enigma_black_hole_pull")
			and not strongestEnemy:HasModifier("modifier_faceless_void_chronosphere_freeze")
			and not strongestEnemy:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			return BOT_ACTION_DESIRE_HIGH, strongestEnemy
		end
	end
	if isGoingOnSomeone then
		local strongestEnemy = Fu.GetStrongestUnit(castRange, bot, true, false, duration)
		if
			Fu.IsValidTarget(strongestEnemy)
			and Fu.CanCastOnNonMagicImmune(strongestEnemy)
			and Fu.CanCastOnTargetAdvanced(strongestEnemy)
			and Fu.IsInRange(bot, strongestEnemy, castRange + 150)
			and not Fu.IsSuspiciousIllusion(strongestEnemy)
			and not Fu.IsDisabled(strongestEnemy)
		then
			local targetAllies = Fu.GetNearbyHeroes(strongestEnemy, 1200, false, BOT_MODE_NONE)
			local targetEnemies = Fu.GetNearbyHeroes(strongestEnemy, 1200, true, BOT_MODE_NONE)
			if
				targetEnemies ~= nil
				and targetAllies ~= nil
				and #targetEnemies >= #targetAllies
				and (#targetEnemies == 1 or #targetEnemies == 2)
				and #targetAllies <= 1
			then
				return BOT_ACTION_DESIRE_HIGH, strongestEnemy
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function X.ConsiderDemonicCleanse()
	if not demonicCleanseAbility:IsTrained() or not demonicCleanseAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castRange = Fu.GetProperCastRange(false, bot, demonicCleanseAbility:GetCastRange())
	if isInTeamFight then
		-- datafeed: Demonic Cleanse targets allies (target_team 1). It scanned enemies, required
		-- disabled AND taunted, and returned an undefined global; cleanse a disabled ally instead.
		local nearbyAllies = Fu.GetAlliesNearLoc(bot:GetLocation(), castRange)
		for _, allyHero in pairs(nearbyAllies) do
			if
				Fu.IsValidHero(allyHero)
				and (Fu.IsDisabled(allyHero) or Fu.IsTaunted(allyHero))
				and not allyHero:IsIllusion()
				and not allyHero:HasModifier("modifier_abaddon_borrowed_time")
				and not allyHero:HasModifier("modifier_dazzle_shallow_grave")
				and not allyHero:HasModifier("modifier_doom_bringer_doom")
				and not allyHero:HasModifier("modifier_legion_commander_duel")
				and not allyHero:HasModifier("modifier_enigma_black_hole_pull")
				and not allyHero:HasModifier("modifier_faceless_void_chronosphere_freeze")
				and not allyHero:HasModifier("modifier_necrolyte_reapers_scythe")
			then
				return BOT_ACTION_DESIRE_HIGH, allyHero
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
return X
