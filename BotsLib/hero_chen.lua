-- Chen: skill build, item build, and ability use for this hero.
local X = {}
local bot = GetBot()
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local AbilityContext = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local Minion = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local sTalentList = Fu.Skill.GetTalentList(bot)
local sAbilityList = Fu.Skill.GetAbilityList(bot)
local sRole = Fu.Item.GetRoleItemsBuyList(bot)
local tTalentTreeList = {
	{ ["t25"] = { 0, 10 }, ["t20"] = { 0, 10 }, ["t15"] = { 10, 0 }, ["t10"] = { 0, 10 } },
	{ ["t25"] = { 0, 10 }, ["t20"] = { 0, 10 }, ["t15"] = { 10, 0 }, ["t10"] = { 0, 10 } },
}
local tAllAbilityBuildList =
	{ { 2, 1, 2, 1, 2, 6, 2, 3, 3, 3, 6, 3, 1, 1, 6 }, { 1, 2, 2, 3, 2, 6, 2, 1, 1, 3, 6, 3, 3, 1, 6 } }
local nAbilityBuildList
local nTalentBuildList
if sRole == "pos_4" then
	nAbilityBuildList = tAllAbilityBuildList[1]
	nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList[1])
else
	nAbilityBuildList = tAllAbilityBuildList[2]
	nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList[2])
end
local sRoleItemsBuyList = {}
sRoleItemsBuyList["pos_1"] = {
	"item_tango",
	"item_double_branches",
	"item_faerie_fire",
	"item_boots",
	"item_magic_wand",
	"item_dagon_2",
	"item_travel_boots",
	"item_aghanims_shard",
	"item_cyclone",
	"item_ultimate_scepter",
	"item_octarine_core",
	"item_dagon_5",
	"item_ultimate_scepter_2",
	"item_shivas_guard",
	"item_travel_boots_2",
	"item_wind_waker",
	"item_moon_shard",
}
sRoleItemsBuyList["pos_2"] = sRoleItemsBuyList["pos_1"]
sRoleItemsBuyList["pos_3"] = {
	"item_mage_outfit",
	"item_ancient_janggo",
	"item_glimmer_cape",
	"item_boots_of_bearing",
	"item_rod_of_atos",
	"item_gungir",
	"item_aghanims_shard",
	"item_cyclone",
	"item_shivas_guard",
	"item_sheepstick",
	"item_wind_waker",
	"item_moon_shard",
	"item_ultimate_scepter_2",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 4, 1,558 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_4"] = {
	"item_tango",
	"item_blood_grenade",
	"item_double_branches",
	"item_magic_stick",
	"item_faerie_fire",
	"item_magic_wand",
	"item_ring_of_basilius",
	"item_headdress",
	"item_arcane_boots",
	"item_ancient_janggo",
	"item_mekansm",
	"item_aghanims_shard",
	"item_guardian_greaves",
	"item_ultimate_scepter",
	"item_ultimate_scepter_2",
	"item_glimmer_cape",
	"item_force_staff",
	"item_spirit_vessel",
	"item_shivas_guard",
	"item_moon_shard",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 5, 5,001 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_5"] = {
	"item_tango",
	"item_blood_grenade",
	"item_double_branches",
	"item_magic_stick",
	"item_faerie_fire",
	"item_magic_wand",
	"item_ring_of_basilius",
	"item_headdress",
	"item_arcane_boots",
	"item_ancient_janggo",
	"item_mekansm",
	"item_aghanims_shard",
	"item_guardian_greaves",
	"item_ultimate_scepter",
	"item_glimmer_cape",
	"item_sheepstick",
	"item_ultimate_scepter_2",
}
X["sBuyList"] = sRoleItemsBuyList[sRole]
X["sSellList"] = { "item_shivas_guard", "item_magic_wand", "item_sheepstick", "item_magic_wand" }
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
local penitenceAbility = SafeAbility(bot:GetAbilityByName("chen_penitence"), "chen_penitence", "chen")
local holyPersuasionAbility = SafeAbility(bot:GetAbilityByName("chen_holy_persuasion"), "chen_holy_persuasion", "chen")
local divineFavorAbility = SafeAbility(bot:GetAbilityByName("chen_divine_favor"), "chen_divine_favor", "chen")
local zealotAbility = SafeAbility(bot:GetAbilityByName("chen_zealot"), "chen_zealot", "chen")
local handOfGodAbility = SafeAbility(bot:GetAbilityByName("chen_hand_of_god"), "chen_hand_of_god", "chen")
local penitenceDesire, penitenceTarget
local holyPersuasionDesire, holyPersuasionTarget
local divineFavorDesire, divineFavorTarget
local zealotDesire
local handOfGodDesire
local controlledCreeps = {}
local botTarget
local isAttacking
function X.SkillsComplement()
	if Fu.CanNotUseAbility(bot) then
		return
	end
	local context = AbilityContext.Build(bot)
	isAttacking = Fu.IsAttacking(bot)
	botTarget = context.target
	handOfGodDesire = X.ConsiderHandOfGod()
	if handOfGodDesire > 0 then
		bot:Action_UseAbility(handOfGodAbility)
		return
	end
	penitenceDesire, penitenceTarget = X.ConsiderPenitence()
	if penitenceDesire > 0 then
		bot:Action_UseAbilityOnEntity(penitenceAbility, penitenceTarget)
		return
	end
	zealotDesire = X.ConsiderZealot()
	if zealotDesire > 0 then
		-- datafeed: Zealot is unit-target (behavior 8); targeting Chen teleports all controlled units to him
		bot:Action_UseAbilityOnEntity(zealotAbility, bot)
		return
	end
	holyPersuasionDesire, holyPersuasionTarget = X.ConsiderHolyPersuasion()
	if holyPersuasionDesire > 0 then
		bot:Action_UseAbilityOnEntity(holyPersuasionAbility, holyPersuasionTarget)
		return
	end
	divineFavorDesire, divineFavorTarget = X.ConsiderDivineFavor()
	if divineFavorDesire > 0 then
		bot:Action_UseAbilityOnEntity(divineFavorAbility, divineFavorTarget)
		return
	end
end
function X.ConsiderPenitence()
	if not penitenceAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castRange = Fu.GetProperCastRange(false, bot, penitenceAbility:GetCastRange())
	local attackRange = bot:GetAttackRange()
	local nearbyAllies = Fu.GetNearbyHeroes(bot, castRange, false, BOT_MODE_NONE)
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
				and Fu.IsChasingTarget(enemiesNearAlly[1], allyHero)
				and allyHero:GetCurrentMovementSpeed() < enemiesNearAlly[1]:GetCurrentMovementSpeed()
				and not Fu.IsDisabled(enemiesNearAlly[1])
				and not Fu.IsTaunted(enemiesNearAlly[1])
				and not Fu.IsSuspiciousIllusion(enemiesNearAlly[1])
				and not enemiesNearAlly[1]:HasModifier("modifier_necrolyte_reapers_scythe")
			then
				return BOT_ACTION_DESIRE_HIGH, enemiesNearAlly[1]
			end
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidTarget(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and not Fu.IsSuspiciousIllusion(botTarget)
		then
			local alliesNearTarget = Fu.GetNearbyHeroes(botTarget, 1200, true, BOT_MODE_NONE)
			local enemiesNearTarget = Fu.GetNearbyHeroes(botTarget, 1200, false, BOT_MODE_NONE)
			if alliesNearTarget ~= nil and enemiesNearTarget ~= nil and #alliesNearTarget >= #enemiesNearTarget then
				if
					Fu.IsChasingTarget(bot, botTarget)
					and bot:GetCurrentMovementSpeed() < botTarget:GetCurrentMovementSpeed()
				then
					return BOT_ACTION_DESIRE_HIGH, botTarget
				end
				alliesNearTarget = Fu.GetAlliesNearLoc(bot:GetLocation(), 1600)
				if
					Fu.IsInRange(bot, botTarget, attackRange)
					and isAttacking
					and Fu.GetHeroCountAttackingTarget(alliesNearTarget, botTarget) >= 2
				then
					return BOT_ACTION_DESIRE_HIGH, botTarget
				end
			end
		end
	end
	if Fu.IsRetreating(bot) then
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.IsChasingTarget(enemyHero, bot)
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and not Fu.IsDisabled(enemyHero)
			then
				local alliesNearChaser = Fu.GetNearbyHeroes(enemyHero, 1200, true, BOT_MODE_NONE)
				local enemiesNearChaser = Fu.GetNearbyHeroes(enemyHero, 1200, false, BOT_MODE_NONE)
				if
					alliesNearChaser ~= nil
					and enemiesNearChaser ~= nil
					and (#enemiesNearChaser > #alliesNearChaser or bot:WasRecentlyDamagedByAnyHero(1.5))
					and bot:GetCurrentMovementSpeed() < enemyHero:GetCurrentMovementSpeed()
				then
					return BOT_ACTION_DESIRE_HIGH, enemyHero
				end
			end
		end
	end
	if Fu.IsDoingRoshan(bot) or Fu.IsDoingTormentor(bot) then
		local nearbyAllies = Fu.GetAlliesNearLoc(bot:GetLocation(), 800)
		if
			(Fu.IsRoshan(botTarget) or Fu.IsTormentor(botTarget))
			and Fu.IsInRange(bot, botTarget, castRange)
			and isAttacking
			and nearbyAllies ~= nil
			and #nearbyAllies >= 1
			and Fu.GetHeroCountAttackingTarget(nearbyAllies, botTarget) >= 2
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function X.ConsiderHolyPersuasion()
	if not holyPersuasionAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castRange = holyPersuasionAbility:GetCastRange()
	local maxUnits = holyPersuasionAbility:GetSpecialValueInt("max_units")
	local levelReq = holyPersuasionAbility:GetSpecialValueInt("level_req")
	local nearbyNeutrals = bot:GetNearbyNeutralCreeps(castRange)
	local persuadedCreeps = {}
	for _, unit in pairs(GetUnitList(UNIT_LIST_ALLIES)) do
		if string.find(unit:GetUnitName(), "neutral") and unit:HasModifier("modifier_chen_holy_persuasion") then
			table.insert(persuadedCreeps, unit)
		end
	end
	controlledCreeps = persuadedCreeps
	local preferredCreepNames = {
		"npc_dota_neutral_alpha_wolf",
		"npc_dota_neutral_centaur_khan",
		"npc_dota_neutral_polar_furbolg_ursa_warrior",
		"npc_dota_neutral_dark_troll_warlord",
		"npc_dota_neutral_satyr_hellcaller",
		"npc_dota_neutral_enraged_wildkin",
		"npc_dota_neutral_warpine_raider",
	}
	if levelReq < 5 then
		-- Low levels: this took any neutral in range. A creep above level_req cannot be converted
		-- (datafeed level_req 3/4), ancients need the shard, and past max_units each cast just swaps
		-- a creep, so Chen kept re-casting (and returning before Divine Favor). Same limits as below.
		for _, creep in pairs(nearbyNeutrals) do
			if
				Fu.IsValid(creep)
				and controlledCreeps ~= nil
				and #controlledCreeps < maxUnits
				and creep:GetLevel() <= levelReq
				and not creep:IsAncientCreep()
			then
				return BOT_ACTION_DESIRE_HIGH, creep
			end
		end
	else
		if controlledCreeps ~= nil and #controlledCreeps < maxUnits then
			for _, creep in pairs(nearbyNeutrals) do
				if Fu.IsValid(creep) and creep:GetLevel() <= levelReq then
					for _, creepName in pairs(preferredCreepNames) do
						if creep:GetUnitName() == creepName then
							return BOT_ACTION_DESIRE_HIGH, creep
						end
					end
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function X.ConsiderDivineFavor()
	if not divineFavorAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castRange = Fu.GetProperCastRange(false, bot, divineFavorAbility:GetCastRange())
	local nearbyAllies = Fu.GetNearbyHeroes(bot, castRange, false, BOT_MODE_NONE)
	for _, allyHero in pairs(nearbyAllies) do
		if
			Fu.IsValidHero(allyHero)
			and Fu.IsInRange(bot, allyHero, castRange)
			and not allyHero:HasModifier("modifier_abaddon_borrowed_time")
			and not allyHero:HasModifier("modifier_legion_commander_press_the_attack")
			and not allyHero:HasModifier("modifier_necrolyte_reapers_scythe")
			and not allyHero:HasModifier("modifier_chen_penitence_attack_speed_buff")
			and not allyHero:HasModifier("modifier_chen_divine_favor_armor_buff")
			and not allyHero:IsIllusion()
			and not allyHero:IsInvulnerable()
		then
			if Fu.IsGoingOnSomeone(allyHero) then
				local allyTarget = Fu.GetProperTarget(allyHero)
				if
					Fu.IsValidTarget(allyTarget)
					and Fu.IsCore(allyHero)
					and Fu.IsInRange(allyHero, allyTarget, allyHero:GetCurrentVisionRange())
					and not Fu.IsSuspiciousIllusion(allyTarget)
				then
					return BOT_ACTION_DESIRE_HIGH, allyHero
				end
			end
			local enemiesNearAlly = Fu.GetNearbyHeroes(allyHero, 1200, true, BOT_MODE_NONE)
			if Fu.IsRetreating(allyHero) and allyHero:WasRecentlyDamagedByAnyHero(1.5) then
				if
					enemiesNearAlly ~= nil
					and #enemiesNearAlly >= 1
					and Fu.IsValidHero(enemiesNearAlly[1])
					and Fu.IsInRange(bot, enemiesNearAlly[1], castRange)
					and Fu.IsChasingTarget(enemiesNearAlly[1], allyHero)
					and not Fu.IsDisabled(enemiesNearAlly[1])
					and not Fu.IsTaunted(enemiesNearAlly[1])
					and not Fu.IsSuspiciousIllusion(enemiesNearAlly[1])
					and not enemiesNearAlly[1]:HasModifier("modifier_necrolyte_reapers_scythe")
				then
					-- datafeed: Divine Favor targets allies only (target_team 1); buff the retreating ally, not the chaser
					return BOT_ACTION_DESIRE_HIGH, allyHero
				end
			end
		end
	end
	if Fu.IsDoingRoshan(bot) or Fu.IsDoingTormentor(bot) then
		if
			(Fu.IsRoshan(botTarget) or Fu.IsTormentor(botTarget))
			and Fu.IsInRange(bot, botTarget, castRange)
			and isAttacking
		then
			local weakestUnit = Fu.GetAttackableWeakestUnit(bot, castRange, true, false)
			if weakestUnit ~= nil then
				return BOT_ACTION_DESIRE_HIGH, weakestUnit
			end
		end
	end
	if Fu.IsRetreating(bot) then
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.IsChasingTarget(enemyHero, bot)
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and not Fu.IsDisabled(enemyHero)
			then
				local alliesNearChaser = Fu.GetNearbyHeroes(enemyHero, 1200, true, BOT_MODE_NONE)
				local enemiesNearChaser = Fu.GetNearbyHeroes(enemyHero, 1200, false, BOT_MODE_NONE)
				if
					alliesNearChaser ~= nil
					and enemiesNearChaser ~= nil
					and (
						#enemiesNearChaser > #alliesNearChaser and #alliesNearChaser <= 1
						or bot:WasRecentlyDamagedByAnyHero(2)
					)
				then
					-- datafeed: Divine Favor targets allies only; self-cast also buffs all units Chen controls
					return BOT_ACTION_DESIRE_HIGH, bot
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function X.ConsiderZealot()
	if not zealotAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
	end
	if Fu.IsInTeamFight(bot, 1200) then
		local totalDistance = 0
		for _, creep in pairs(controlledCreeps) do
			if Fu.IsValid(creep) then
				totalDistance = totalDistance + GetUnitToUnitDistance(bot, creep)
			end
		end
		if controlledCreeps ~= nil and #controlledCreeps > 0 then
			if totalDistance / #controlledCreeps > 1200 then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderHandOfGod()
	if not handOfGodAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
	end
	local teamFightLocation = Fu.GetTeamFightLocation(bot)
	if teamFightLocation ~= nil then
		local alliesNearFight = Fu.GetAlliesNearLoc(teamFightLocation, 1600)
		for _, allyHero in pairs(alliesNearFight) do
			if
				Fu.IsValidHero(allyHero)
				and Fu.IsCore(allyHero)
				and Fu.GetHP(allyHero) < 0.5
				and not allyHero:IsIllusion()
				and not allyHero:IsAttackImmune()
				and not allyHero:IsInvulnerable()
				and not allyHero:HasModifier("modifier_necrolyte_reapers_scythe")
				and not allyHero:HasModifier("modifier_oracle_false_promise_timer")
			then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	for _, allyHero in pairs(GetUnitList(UNIT_LIST_ALLIED_HEROES)) do
		local enemiesNearAlly = Fu.GetNearbyHeroes(allyHero, 1200, true, BOT_MODE_NONE)
		if
			Fu.IsValidHero(allyHero)
			and Fu.IsRetreating(allyHero)
			and allyHero:GetActiveModeDesire() >= 0.65
			and Fu.IsCore(allyHero)
			and Fu.GetHP(allyHero) < 0.5
			and allyHero:WasRecentlyDamagedByAnyHero(1)
			and not allyHero:IsIllusion()
			and not allyHero:IsAttackImmune()
			and not allyHero:IsInvulnerable()
			and not allyHero:HasModifier("modifier_necrolyte_reapers_scythe")
			and not allyHero:HasModifier("modifier_oracle_false_promise_timer")
		then
			if
				enemiesNearAlly ~= nil
				and #enemiesNearAlly >= 1
				and Fu.IsValidHero(enemiesNearAlly[1])
				and Fu.IsChasingTarget(enemiesNearAlly[1], allyHero)
				and not Fu.IsSuspiciousIllusion(enemiesNearAlly[1])
			then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
return X
