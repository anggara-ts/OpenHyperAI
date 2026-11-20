-- Ancient Apparition: skill build, item build, and ability use for this hero.
-- Accidental globals made file-local (#13): every bot shares one Lua state, so these were shared.
local X = {}
local bot = GetBot()
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local AbilityContext = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local Minion = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local sTalentList = Fu.Skill.GetTalentList(bot)
local sAbilityList = Fu.Skill.GetAbilityList(bot)
local sRole = Fu.Item.GetRoleItemsBuyList(bot)
local tTalentTreeList = { ["t25"] = { 10, 0 }, ["t20"] = { 0, 10 }, ["t15"] = { 10, 0 }, ["t10"] = { 10, 0 } }
local tAllAbilityBuildList = { { 3, 1, 3, 2, 3, 6, 3, 1, 1, 1, 6, 2, 2, 2, 6 } }
local nAbilityBuildList = Fu.Skill.GetRandomBuild(tAllAbilityBuildList)
local nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList)
local sRoleItemsBuyList = {}
-- Stratz 7.41f, week of 9 Nov 2026: pos 1 has 566 matches, built from pos 2 (7,926) (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_1"] = {
	"item_tango",
	"item_double_branches",
	"item_circlet",
	"item_mantle",
	"item_faerie_fire",
	"item_null_talisman",
	"item_magic_wand",
	"item_power_treads",
	"item_witch_blade",
	"item_ultimate_scepter",
	"item_aghanims_shard",
	"item_hurricane_pike",
	"item_moon_shard",
	"item_devastator",
	"item_ultimate_scepter_2",
	"item_rod_of_atos",
	"item_invis_sword",
	"item_yasha_and_kaya",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 2, 7,926 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_2"] = {
	"item_tango",
	"item_double_branches",
	"item_circlet",
	"item_mantle",
	"item_faerie_fire",
	"item_null_talisman",
	"item_magic_wand",
	"item_power_treads",
	"item_witch_blade",
	"item_ultimate_scepter",
	"item_aghanims_shard",
	"item_hurricane_pike",
	"item_moon_shard",
	"item_devastator",
	"item_ultimate_scepter_2",
	"item_rod_of_atos",
	"item_invis_sword",
	"item_yasha_and_kaya",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 3 has 897 matches, built from pos 2 (7,926) (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_3"] = sRoleItemsBuyList["pos_2"]
-- Stratz 7.41f, week of 9 Nov 2026: pos 4, 54,214 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_4"] = {
	"item_tango",
	"item_blood_grenade",
	"item_branches",
	"item_magic_stick",
	"item_clarity",
	"item_magic_wand",
	"item_arcane_boots",
	"item_aghanims_shard",
	"item_glimmer_cape",
	"item_force_staff",
	"item_ultimate_scepter",
	"item_ultimate_scepter_2",
	"item_gungir",
	"item_hurricane_pike",
	"item_witch_blade",
	"item_octarine_core",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 5, 85,039 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_5"] = {
	"item_tango",
	"item_blood_grenade",
	"item_branches",
	"item_magic_stick",
	"item_faerie_fire",
	"item_magic_wand",
	"item_arcane_boots",
	"item_aghanims_shard",
	"item_glimmer_cape",
	"item_force_staff",
	"item_ultimate_scepter",
	"item_gungir",
	"item_dragon_lance",
	"item_ultimate_scepter_2",
	"item_sheepstick",
	"item_hurricane_pike",
	"item_witch_blade",
}
X["sBuyList"] = sRoleItemsBuyList[sRole]
X["sSellList"] = { "item_ultimate_scepter", "item_magic_wand" }
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
local coldFeetAbility = SafeAbility(
	bot:GetAbilityByName("ancient_apparition_cold_feet"),
	"ancient_apparition_cold_feet",
	"ancient_apparition"
)
local iceVortexAbility = SafeAbility(
	bot:GetAbilityByName("ancient_apparition_ice_vortex"),
	"ancient_apparition_ice_vortex",
	"ancient_apparition"
)
local chillingTouchAbility = SafeAbility(
	bot:GetAbilityByName("ancient_apparition_chilling_touch"),
	"ancient_apparition_chilling_touch",
	"ancient_apparition"
)
local iceBlastAbility = SafeAbility(
	bot:GetAbilityByName("ancient_apparition_ice_blast"),
	"ancient_apparition_ice_blast",
	"ancient_apparition"
)
local iceBlastReleaseAbility = SafeAbility(
	bot:GetAbilityByName("ancient_apparition_ice_blast_release"),
	"ancient_apparition_ice_blast_release",
	"ancient_apparition"
)
-- datafeed: the AoE Cold Feet talent is special_bonus_unique_ancient_apparition_1; _7 is now Chilling Touch range
local coldFeetAoeTalent = SafeAbility(
	bot:GetAbilityByName("special_bonus_unique_ancient_apparition_1"),
	"special_bonus_unique_ancient_apparition_1",
	"ancient_apparition"
)
local coldFeetDesire, coldFeetTarget
local iceVortexDesire, iceVortexLocation
local chillingTouchDesire, chillingTouchTarget
local iceBlastDesire, iceBlastLocation
local iceBlastReleaseDesire
local iceBlastCastLocation
local botTarget
local isGoingOnSomeone
local isRetreating
local isAttacking
-- where AA stood when the Ice Blast tracer was launched (for the release-overshoot check)
local iceBlastFrom = nil
function X.SkillsComplement()
	-- fix: Ice Blast Release is IGNORE_SILENCE (game data), but CanNotUseAbility returns on silence,
	-- so a silenced AA let the tracer fly on. Release first when the only problem is a silence.
	if bot:IsAlive() and bot:IsSilenced() and not bot:IsStunned() and not bot:IsHexed() and not bot:IsNightmared() then
		if X.ConsiderIceBlastRelease() > 0 then
			bot:Action_UseAbility(iceBlastReleaseAbility)
			return
		end
	end
	if Fu.CanNotUseAbility(bot) then
		return
	end
	local context = AbilityContext.Build(bot)
	isGoingOnSomeone = context.isEngaging
	isRetreating = context.isRetreating
	isAttacking = Fu.IsAttacking(bot)
	iceBlastReleaseDesire = X.ConsiderIceBlastRelease()
	if iceBlastReleaseDesire > 0 then
		bot:Action_UseAbility(iceBlastReleaseAbility)
		return
	end
	iceBlastDesire, iceBlastLocation = X.ConsiderIceBlast()
	if iceBlastDesire > 0 then
		bot:Action_UseAbilityOnLocation(iceBlastAbility, iceBlastLocation)
		iceBlastCastLocation = iceBlastLocation
		iceBlastFrom = bot:GetLocation()
		return
	end
	iceVortexDesire, iceVortexLocation = X.ConsiderIceVortex()
	if iceVortexDesire > 0 then
		bot:Action_UseAbilityOnLocation(iceVortexAbility, iceVortexLocation)
		return
	end
	coldFeetDesire, coldFeetTarget = X.ConsiderColdFeet()
	if coldFeetDesire > 0 then
		-- fix: Cold Feet is DOTA_ABILITY_BEHAVIOR_UNIT_TARGET (game data and datafeed, the AoE talent only
		-- adds area_of_effect), so the location order given with the talent was refused and Cold Feet
		-- was not cast exactly when 2+ enemies stood together. Only order a location if it really is a point spell.
		if
			coldFeetAoeTalent:IsTrained()
			and Fu.CheckBitfieldFlag(coldFeetAbility:GetBehavior(), ABILITY_BEHAVIOR_POINT)
		then
			local radius = 450
			local castRange = Fu.GetProperCastRange(false, bot, coldFeetAbility:GetCastRange())
			local aoeLocation = bot:FindAoELocation(true, true, bot:GetLocation(), castRange, radius, 0, 0)
			if aoeLocation.count >= 2 then
				bot:Action_UseAbilityOnLocation(coldFeetAbility, aoeLocation.targetloc)
			else
				bot:Action_UseAbilityOnEntity(coldFeetAbility, coldFeetTarget)
			end
		else
			bot:Action_UseAbilityOnEntity(coldFeetAbility, coldFeetTarget)
		end
		return
	end
	chillingTouchDesire, chillingTouchTarget = X.ConsiderChillingTouch()
	if chillingTouchDesire > 0 then
		bot:Action_UseAbilityOnEntity(chillingTouchAbility, chillingTouchTarget)
		return
	end
end
function X.ConsiderColdFeet()
	if not coldFeetAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castRange = Fu.GetProperCastRange(false, bot, coldFeetAbility:GetCastRange())
	botTarget = Fu.GetProperTarget(bot)
	local nearbyAllies = Fu.GetNearbyHeroes(bot, castRange + 150, false, BOT_MODE_NONE)
	for _, allyHero in pairs(nearbyAllies) do
		local enemiesNearAlly = Fu.GetNearbyHeroes(allyHero, 1200, true, BOT_MODE_NONE)
		if
			Fu.IsValidHero(allyHero)
			and Fu.IsRetreating(allyHero)
			and allyHero:WasRecentlyDamagedByAnyHero(1.5)
			and not allyHero:IsIllusion()
		then
			if
				enemiesNearAlly ~= nil
				and #enemiesNearAlly >= 1
				and Fu.IsValidHero(enemiesNearAlly[1])
				and Fu.IsInRange(bot, enemiesNearAlly[1], castRange)
				and Fu.CanCastOnNonMagicImmune(enemiesNearAlly[1])
				and Fu.CanCastOnTargetAdvanced(enemiesNearAlly[1])
				and Fu.IsChasingTarget(enemiesNearAlly[1], allyHero)
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
	if isGoingOnSomeone then
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.CanCastOnTargetAdvanced(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not Fu.IsDisabled(botTarget)
			and not botTarget:HasModifier("modifier_cold_feet")
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			local alliesNearTarget = Fu.GetNearbyHeroes(botTarget, 1000, true, BOT_MODE_NONE)
			local enemiesNearTarget = Fu.GetNearbyHeroes(botTarget, 1000, false, BOT_MODE_NONE)
			if alliesNearTarget ~= nil and enemiesNearTarget ~= nil and #alliesNearTarget >= #enemiesNearTarget then
				return BOT_ACTION_DESIRE_HIGH, botTarget
			end
		end
	end
	if isRetreating then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, 1200, false, BOT_MODE_NONE)
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE)
		if nearbyAllies ~= nil and nearbyEnemies ~= nil then
			for _, enemyHero in pairs(nearbyEnemies) do
				if
					(#nearbyAllies > #nearbyEnemies or bot:WasRecentlyDamagedByHero(enemyHero, 1.5))
					and Fu.CanCastOnNonMagicImmune(enemyHero)
					and Fu.CanCastOnTargetAdvanced(enemyHero)
					and Fu.IsInRange(bot, enemyHero, castRange)
					and not Fu.IsSuspiciousIllusion(enemyHero)
					and not Fu.IsDisabled(enemyHero)
					and not enemyHero:HasModifier("modifier_cold_feet")
					and not enemyHero:HasModifier("modifier_ice_vortex")
				then
					return BOT_ACTION_DESIRE_HIGH, enemyHero
				end
			end
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if
			Fu.IsRoshan(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and isAttacking
			and not botTarget:HasModifier("modifier_cold_feet")
			and not botTarget:HasModifier("modifier_ice_vortex")
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if
			Fu.IsTormentor(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and isAttacking
			and not botTarget:HasModifier("modifier_cold_feet")
			and not botTarget:HasModifier("modifier_ice_vortex")
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function X.ConsiderIceVortex()
	if not iceVortexAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local castRange = Fu.GetProperCastRange(false, bot, iceVortexAbility:GetCastRange())
	local radius = iceVortexAbility:GetSpecialValueInt("radius")
	local castPoint = iceVortexAbility:GetCastPoint()
	botTarget = Fu.GetProperTarget(bot)
	if Fu.IsInTeamFight(bot, 1200) then
		local aoeLocation = bot:FindAoELocation(true, true, bot:GetLocation(), castRange, radius, 0, 0)
		local enemiesInRadius = Fu.GetEnemiesNearLoc(aoeLocation.targetloc, radius)
		-- fix: `#enemiesInRadius` alone is always true; require an enemy hero in the vortex
		if
			enemiesInRadius ~= nil
			and #enemiesInRadius >= 1
			and GetUnitToLocationDistance(bot, aoeLocation.targetloc) <= castRange
		then
			return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
		end
	end
	if isGoingOnSomeone then
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not Fu.IsDisabled(botTarget)
			and not botTarget:HasModifier("modifier_ice_vortex")
		then
			local alliesNearTarget = Fu.GetNearbyHeroes(botTarget, 1000, true, BOT_MODE_NONE)
			local enemiesNearTarget = Fu.GetNearbyHeroes(botTarget, 1000, false, BOT_MODE_NONE)
			if alliesNearTarget ~= nil and enemiesNearTarget ~= nil and #alliesNearTarget >= #enemiesNearTarget then
				return BOT_ACTION_DESIRE_HIGH, botTarget:GetExtrapolatedLocation(castPoint)
			end
		end
	end
	if isRetreating then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, 1200, false, BOT_MODE_NONE)
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE)
		if nearbyAllies ~= nil and nearbyEnemies ~= nil then
			for _, enemyHero in pairs(nearbyEnemies) do
				if
					(#nearbyAllies > #nearbyEnemies or bot:WasRecentlyDamagedByHero(enemyHero, 1.5))
					and Fu.CanCastOnNonMagicImmune(enemyHero)
					and Fu.IsInRange(bot, enemyHero, castRange)
					and not Fu.IsSuspiciousIllusion(enemyHero)
					and not Fu.IsDisabled(enemyHero)
					and not enemyHero:HasModifier("modifier_cold_feet")
					and not enemyHero:HasModifier("modifier_ice_vortex")
				then
					return BOT_ACTION_DESIRE_HIGH, enemyHero:GetExtrapolatedLocation(castPoint)
				end
			end
		end
	end
	if (Fu.IsDefending(bot) or Fu.IsPushing(bot)) and not Fu.IsThereNonSelfCoreNearby(1000) then
		local nearbyLaneCreeps = bot:GetNearbyLaneCreeps(castRange, true)
		local aoeLocation = bot:FindAoELocation(true, false, bot:GetLocation(), castRange, radius, castPoint, 0)
		if
			nearbyLaneCreeps ~= nil
			and #nearbyLaneCreeps >= 4
			and aoeLocation.count >= 4
			and GetUnitToLocationDistance(bot, aoeLocation.targetloc) <= castRange
		then
			return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
		end
		aoeLocation = bot:FindAoELocation(true, true, bot:GetLocation(), castRange, radius, castPoint, 0)
		if aoeLocation.count >= 2 and GetUnitToLocationDistance(bot, aoeLocation.targetloc) <= castRange then
			return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if
			Fu.IsRoshan(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and isAttacking
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, castRange) and isAttacking then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.ConsiderChillingTouch()
	if not chillingTouchAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castRange = Fu.GetProperCastRange(false, bot, chillingTouchAbility:GetCastRange())
		+ chillingTouchAbility:GetSpecialValueInt("attack_range_bonus")
	local damage = chillingTouchAbility:GetSpecialValueInt("damage")
	botTarget = Fu.GetProperTarget(bot)
	local nearbyEnemies = Fu.GetNearbyHeroes(bot, castRange + 50, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and Fu.CanCastOnTargetAdvanced(enemyHero)
			and Fu.CanKillTarget(enemyHero, damage, DAMAGE_TYPE_MAGICAL)
			and not Fu.IsSuspiciousIllusion(enemyHero)
			and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
			and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
			and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
			and not enemyHero:HasModifier("modifier_templar_assassin_refraction_absorb")
		then
			return BOT_ACTION_DESIRE_HIGH, enemyHero
		end
	end
	local nearbyAllies = Fu.GetNearbyHeroes(bot, castRange + 50, false, BOT_MODE_NONE)
	for _, allyHero in pairs(nearbyAllies) do
		local enemiesNearAlly = Fu.GetNearbyHeroes(allyHero, 1200, true, BOT_MODE_NONE)
		if
			Fu.IsValidHero(allyHero)
			and Fu.IsRetreating(allyHero)
			and allyHero:WasRecentlyDamagedByAnyHero(1.5)
			and not allyHero:IsIllusion()
		then
			if
				enemiesNearAlly ~= nil
				and #enemiesNearAlly >= 1
				and Fu.IsValidHero(enemiesNearAlly[1])
				and Fu.CanCastOnNonMagicImmune(enemiesNearAlly[1])
				and Fu.CanCastOnTargetAdvanced(enemiesNearAlly[1])
				and Fu.IsInRange(bot, enemiesNearAlly[1], castRange)
				and Fu.IsChasingTarget(enemiesNearAlly[1], allyHero)
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
	if isGoingOnSomeone then
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.CanCastOnTargetAdvanced(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not Fu.IsDisabled(botTarget)
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
			and not botTarget:HasModifier("modifier_templar_assassin_refraction_absorb")
		then
			local alliesNearTarget = Fu.GetNearbyHeroes(botTarget, 1200, true, BOT_MODE_NONE)
			local enemiesNearTarget = Fu.GetNearbyHeroes(botTarget, 1200, false, BOT_MODE_NONE)
			if alliesNearTarget ~= nil and enemiesNearTarget ~= nil and #alliesNearTarget >= #enemiesNearTarget then
				return BOT_ACTION_DESIRE_HIGH, botTarget
			end
		end
	end
	if isRetreating then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, 1200, false, BOT_MODE_NONE)
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE)
		if nearbyAllies ~= nil and nearbyEnemies ~= nil then
			for _, enemyHero in pairs(nearbyEnemies) do
				if
					(#nearbyAllies > #nearbyEnemies or bot:WasRecentlyDamagedByHero(enemyHero, 1.2))
					and Fu.CanCastOnNonMagicImmune(enemyHero)
					and Fu.CanCastOnTargetAdvanced(enemyHero)
					and Fu.IsInRange(bot, enemyHero, castRange)
					and not Fu.IsSuspiciousIllusion(enemyHero)
					and not Fu.IsDisabled(enemyHero)
				then
					return BOT_ACTION_DESIRE_HIGH, enemyHero
				end
			end
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if
			Fu.IsRoshan(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and isAttacking
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, castRange) and isAttacking then
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function X.ConsiderIceBlast()
	if not iceBlastAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local radiusMin = iceBlastAbility:GetSpecialValueInt("radius_min")
	local radiusGrow = iceBlastAbility:GetSpecialValueInt("radius_grow")
	local radiusMax = iceBlastAbility:GetSpecialValueInt("radius_max")
	if Fu.IsInTeamFight(bot, 1600) then
		local fightLocation = Fu.GetTeamFightLocation(bot)
		if fightLocation ~= nil then
			local distance = GetUnitToLocationDistance(bot, fightLocation)
			local radius = math.min(radiusMin + distance * radiusGrow, radiusMax)
			local aoeLocation = bot:FindAoELocation(true, true, bot:GetLocation(), 1600, radius, 0, 0)
			local enemiesInRadius = Fu.GetEnemiesNearLoc(aoeLocation.targetloc, radius)
			if enemiesInRadius ~= nil and #enemiesInRadius >= 2 then
				return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
			end
		end
	end
	local fightLocation = Fu.GetTeamFightLocation(bot)
	if fightLocation ~= nil then
		local distance = GetUnitToLocationDistance(bot, fightLocation)
		local radius = math.min(radiusMin + distance * radiusGrow, radiusMax)
		local enemiesInRadius = Fu.GetEnemiesNearLoc(fightLocation, radius)
		if enemiesInRadius ~= nil and #enemiesInRadius >= 1 then
			return BOT_ACTION_DESIRE_HIGH, fightLocation
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.ConsiderIceBlastRelease()
	if iceBlastReleaseAbility:IsHidden() or not iceBlastReleaseAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
	end
	local linearProjectiles = GetLinearProjectiles()
	for _, projectile in pairs(linearProjectiles) do
		if
			projectile ~= nil
			and projectile.ability ~= nil
			and projectile.ability:GetName() == "ancient_apparition_ice_blast"
		then
			if
				iceBlastCastLocation ~= nil
				and Fu.GetLocationToLocationDistance(iceBlastCastLocation, projectile.location) < 100
			then
				return BOT_ACTION_DESIRE_HIGH
			end
			-- fix: at 1500 speed the tracer moves ~50-150 units between thinks and could skip the
			-- 100-unit window, then fly past the target with nothing to release it. Release once it
			-- is at or beyond the target distance from where it was launched.
			if
				iceBlastCastLocation ~= nil
				and iceBlastFrom ~= nil
				and Fu.GetLocationToLocationDistance(iceBlastFrom, projectile.location)
					>= Fu.GetLocationToLocationDistance(iceBlastFrom, iceBlastCastLocation) - 50
			then
				if DotaTime() >= (bot._aaReleaseLogAt or -999) then
					bot._aaReleaseLogAt = DotaTime() + 10
					pcall(
						print,
						string.format(
							"[OHA-AA] t=%.0f ice blast release (overshoot check) miss=%d",
							DotaTime(),
							math.floor(Fu.GetLocationToLocationDistance(iceBlastCastLocation, projectile.location))
						)
					)
				end
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
return X
