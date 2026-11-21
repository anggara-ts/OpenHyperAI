-- Windrunner: skill build, item build, and ability use for this hero.
local X = {}
local bot = GetBot()
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local AbilityContext = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local Minion = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local sTalentList = Fu.Skill.GetTalentList(bot)
local sAbilityList = Fu.Skill.GetAbilityList(bot)
local sRole = Fu.Item.GetRoleItemsBuyList(bot)
local tTalentTreeList = {
	{ ["t25"] = { 10, 0 }, ["t20"] = { 10, 0 }, ["t15"] = { 0, 10 }, ["t10"] = { 10, 0 } },
	{ ["t25"] = { 10, 0 }, ["t20"] = { 10, 0 }, ["t15"] = { 0, 10 }, ["t10"] = { 10, 0 } },
	{ ["t25"] = { 10, 0 }, ["t20"] = { 10, 0 }, ["t15"] = { 0, 10 }, ["t10"] = { 10, 0 } },
}
local tAllAbilityBuildList = {
	{ 2, 3, 2, 1, 2, 6, 2, 3, 3, 3, 6, 1, 1, 1, 6 },
	{ 2, 3, 2, 1, 2, 6, 2, 3, 3, 3, 6, 1, 1, 1, 6 },
	{
		2,
		3,
		2,
		1,
		2,
		6,
		2,
		3,
		3,
		3,
		6,
		1,
		1,
		1,
		6,
	},
}
local nAbilityBuildList
local nTalentBuildList
if sRole == "pos_1" then
	nAbilityBuildList = tAllAbilityBuildList[1]
	nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList[1])
elseif sRole == "pos_2" then
	nAbilityBuildList = tAllAbilityBuildList[2]
	nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList[2])
else
	nAbilityBuildList = tAllAbilityBuildList[3]
	nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList[3])
end
local sUtilityList = { "item_heavens_halberd", "item_nullifier" }
local sUtility = sUtilityList[RandomInt(1, #sUtilityList)]
local sRoleItemsBuyList = {}
-- Stratz 7.41f, week of 9 Nov 2026: pos 1, 49,031 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_1"] = {
	"item_tango",
	"item_double_branches",
	"item_double_circlet",
	"item_faerie_fire",
	"item_magic_wand",
	"item_null_talisman",
	"item_bracer",
	"item_power_treads",
	"item_mjollnir",
	"item_dragon_lance",
	"item_black_king_bar",
	"item_hydras_breath",
	"item_greater_crit",
	"item_aghanims_shard",
	"item_ultimate_scepter",
	"item_ultimate_scepter_2",
	"item_moon_shard",
	"item_swift_blink",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 2, 88,453 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_2"] = {
	"item_tango",
	"item_double_branches",
	"item_faerie_fire",
	"item_circlet",
	"item_magic_wand",
	"item_null_talisman",
	"item_power_treads",
	"item_maelstrom",
	"item_blink",
	"item_black_king_bar",
	"item_lesser_crit",
	"item_mjollnir",
	"item_greater_crit",
	"item_aghanims_shard",
	"item_diffusal_blade",
	"item_moon_shard",
	"item_ultimate_scepter_2",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 3, 33,229 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_3"] = {
	"item_tango",
	"item_double_branches",
	"item_double_circlet",
	"item_faerie_fire",
	"item_null_talisman",
	"item_magic_wand",
	"item_bracer",
	"item_power_treads",
	"item_maelstrom",
	"item_blink",
	"item_mjollnir",
	"item_black_king_bar",
	"item_greater_crit",
	sUtility,
	"item_travel_boots",
	"item_aghanims_shard",
	"item_moon_shard",
	"item_ultimate_scepter_2",
	"item_travel_boots_2",
}
-- Support builds: Dotabuff 7-day meta has Windranger most often at support-off (pos 4).
-- Stratz 7.41f, week of 9 Nov 2026: pos 4, 107,212 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_4"] = {
	"item_tango",
	"item_blood_grenade",
	"item_double_branches",
	"item_circlet",
	"item_faerie_fire",
	"item_magic_wand",
	"item_arcane_boots",
	"item_maelstrom",
	"item_blink",
	"item_aghanims_shard",
	"item_black_king_bar",
	"item_diffusal_blade",
	"item_essence_distiller",
	"item_mjollnir",
	"item_moon_shard",
	"item_ultimate_scepter_2",
}
-- One pair of boots in this build (user rule; Util/boots-check.js).
-- Stratz 7.41f, week of 9 Nov 2026: pos 5, 44,089 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_5"] = {
	"item_tango",
	"item_blood_grenade",
	"item_double_branches",
	"item_circlet",
	"item_faerie_fire",
	"item_magic_wand",
	"item_arcane_boots",
	"item_maelstrom",
	"item_blink",
	"item_aghanims_shard",
	"item_black_king_bar",
	"item_diffusal_blade",
	"item_greater_crit",
	"item_mjollnir",
	"item_moon_shard",
	"item_ultimate_scepter_2",
}
X["sBuyList"] = sRoleItemsBuyList[sRole]
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
local shackleshotAbility =
	SafeAbility(bot:GetAbilityByName("windrunner_shackleshot"), "windrunner_shackleshot", "windrunner")
local powershotAbility = SafeAbility(bot:GetAbilityByName("windrunner_powershot"), "windrunner_powershot", "windrunner")
local windrunAbility = SafeAbility(bot:GetAbilityByName("windrunner_windrun"), "windrunner_windrun", "windrunner")
local galeForceAbility =
	SafeAbility(bot:GetAbilityByName("windrunner_gale_force"), "windrunner_gale_force", "windrunner")
local focusFireAbility = SafeAbility(bot:GetAbilityByName("windrunner_focusfire"), "windrunner_focusfire", "windrunner")
-- [OHA-WINDRUNNER] lines: throttled per reason, at most once per 5s.
function X.LogWindrunner(why, fmt, ...)
	bot._wrLogAt = bot._wrLogAt or {}
	if DotaTime() < (bot._wrLogAt[why] or -999) then
		return
	end
	bot._wrLogAt[why] = DotaTime() + 5
	pcall(print, string.format("[OHA-WINDRUNNER] t=%.0f " .. why .. " " .. fmt, DotaTime(), ...))
end
local shackleshotDesire, shackleshotTarget
local powershotDesire, powershotLocation
local windrunDesire
local galeForceDesire, galeForceLocation
local focusFireDesire, focusFireTarget
local botTarget
local isGoingOnSomeone
local isRetreating
local isAttacking
local mpRatio
local hpRatio
function X.SkillsComplement()
	if Fu.CanNotUseAbility(bot) then
		return
	end
	isGoingOnSomeone = Fu.IsGoingOnSomeone(bot)
	isRetreating = Fu.IsRetreating(bot)
	isAttacking = Fu.IsAttacking(bot)
	mpRatio = Fu.GetMP(bot)
	-- hpRatio (own HP) was read in ConsiderWindrun but never set: "hpRatio < 0.7" threw (nil compare), which
	-- ended that think before Windrun's last cases and Gale Force whenever 2+ enemies were near
	-- and one was attacking Windranger.
	hpRatio = Fu.GetHP(bot)
	botTarget = Fu.GetProperTarget(bot)
	shackleshotDesire, shackleshotTarget = X.ConsiderShackleShot()
	if shackleshotDesire > 0 then
		Fu.SetQueuePtToINT(bot, false)
		bot:ActionQueue_UseAbilityOnEntity(shackleshotAbility, shackleshotTarget)
		return
	end
	focusFireDesire, focusFireTarget = X.ConsiderFocusFire()
	if focusFireDesire > 0 then
		bot:Action_UseAbilityOnEntity(focusFireAbility, focusFireTarget)
		return
	end
	powershotDesire, powershotLocation = X.ConsiderPowershot()
	if powershotDesire > 0 then
		Fu.SetQueuePtToINT(bot, false)
		bot:ActionQueue_UseAbilityOnLocation(powershotAbility, powershotLocation)
		return
	end
	windrunDesire = X.ConsiderWindrun()
	if windrunDesire > 0 then
		bot:Action_UseAbility(windrunAbility)
		return
	end
	galeForceDesire, galeForceLocation = X.ConsiderGaleForce()
	if galeForceDesire > 0 then
		bot:Action_UseAbilityOnLocation(galeForceAbility, galeForceLocation)
		return
	end
end
function X.ConsiderShackleShot()
	if not Fu.CanCastAbility(shackleshotAbility) then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castRange = Fu.GetProperCastRange(false, bot, shackleshotAbility:GetCastRange())
	local shackleDistance = shackleshotAbility:GetSpecialValueInt("shackle_distance")
	local shackleAngle = shackleshotAbility:GetSpecialValueInt("shackle_angle")
	local stunDuration = shackleshotAbility:GetSpecialValueFloat("stun_duration")
	local nearbyAllies = Fu.GetNearbyHeroes(bot, 1600, false, BOT_MODE_NONE)
	local nearbyEnemies = Fu.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.IsInRange(bot, enemyHero, castRange)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and Fu.CanCastOnTargetAdvanced(enemyHero)
			and enemyHero:IsChanneling()
		then
			return BOT_ACTION_DESIRE_HIGH, enemyHero
		end
	end
	if isGoingOnSomeone then
		-- Own target first: the only fight case below needed a chase with 2 allies in attack mode
		-- or a kill within the stun, so a gank on a standing or fighting hero never opened with
		-- Shackleshot. Only cast when it latches (to a hero, tree or creep), never the 0.6s fail stun.
		if
			Fu.IsValidHero(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.CanCastOnTargetAdvanced(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and not Fu.IsDisabled(botTarget)
			and not botTarget:HasModifier("modifier_enigma_black_hole_pull")
			and not botTarget:HasModifier("modifier_faceless_void_chronosphere_freeze")
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			local shackleUnit = X.GetShackleTarget(bot, botTarget, shackleDistance, shackleAngle)
			if shackleUnit then
				X.LogWindrunner(
					"shackle-target",
					"target=%s via=%s",
					botTarget:GetUnitName(),
					shackleUnit:GetUnitName()
				)
				return BOT_ACTION_DESIRE_HIGH, shackleUnit
			end
		end
		local strongestEnemy = nil
		local highestDps = 0
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValidTarget(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
				and Fu.IsInRange(bot, enemyHero, castRange)
				and not Fu.IsDisabled(enemyHero)
				and not enemyHero:HasModifier("modifier_enigma_black_hole_pull")
				and not enemyHero:HasModifier("modifier_faceless_void_chronosphere_freeze")
				and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
			then
				local dps = enemyHero:GetAttackDamage() * enemyHero:GetAttackSpeed()
				if dps > highestDps then
					strongestEnemy = enemyHero
					highestDps = dps
				end
			end
		end
		if strongestEnemy then
			local attackingAllies = Fu.GetSpecialModeAllies(bot, 900, BOT_MODE_ATTACK)
			if
				Fu.IsChasingTarget(bot, strongestEnemy) and #attackingAllies >= 2
				or isAttacking
					and bot:GetEstimatedDamageToTarget(true, strongestEnemy, stunDuration, DAMAGE_TYPE_ALL) > strongestEnemy:GetHealth()
			then
				local shackleUnit = X.GetShackleTarget(bot, strongestEnemy, shackleDistance, shackleAngle)
				if shackleUnit then
					return BOT_ACTION_DESIRE_HIGH, shackleUnit
				end
			end
		end
	end
	if isRetreating and not Fu.IsRealInvisible(bot) then
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
				and Fu.IsChasingTarget(enemyHero, bot)
				and not Fu.IsDisabled(enemyHero)
				and bot:WasRecentlyDamagedByHero(enemyHero, 3.0)
			then
				local shackleUnit = X.GetShackleTarget(bot, enemyHero, shackleDistance, shackleAngle)
				if shackleUnit ~= nil then
					return BOT_ACTION_DESIRE_HIGH, shackleUnit
				end
			end
		end
	end
	for _, enemyUnit in pairs(nearbyEnemies) do
		if
			Fu.IsValid(enemyUnit)
			and (enemyUnit:IsChanneling() or enemyUnit:HasModifier("modifier_teleporting"))
			and Fu.CanCastOnNonMagicImmune(enemyUnit)
			and Fu.CanCastOnTargetAdvanced(enemyUnit)
		then
			return BOT_ACTION_DESIRE_HIGH, enemyUnit
		end
	end
	for _, allyHero in pairs(nearbyAllies) do
		if
			Fu.IsValidHero(allyHero)
			and Fu.IsRetreating(allyHero)
			and mpRatio > 0.45
			and allyHero:WasRecentlyDamagedByAnyHero(3.0)
			and not Fu.IsRealInvisible(bot)
			and not allyHero:IsIllusion()
		then
			local enemiesNearAlly = allyHero:GetNearbyHeroes(1600, true, BOT_MODE_NONE)
			for _, enemyHero in pairs(enemiesNearAlly) do
				if
					Fu.IsValidHero(enemyHero)
					and Fu.CanCastOnNonMagicImmune(enemyHero)
					and Fu.CanCastOnTargetAdvanced(enemyHero)
					and Fu.IsInRange(bot, enemyHero, castRange)
					and Fu.IsChasingTarget(enemyHero, allyHero)
					and not Fu.IsDisabled(enemyHero)
					and not enemyHero:HasModifier("modifier_enigma_black_hole_pull")
					and not enemyHero:HasModifier("modifier_faceless_void_chronosphere_freeze")
					and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
				then
					local shackleUnit = X.GetShackleTarget(bot, enemyHero, shackleDistance, shackleAngle)
					if shackleUnit ~= nil then
						return BOT_ACTION_DESIRE_HIGH, shackleUnit
					end
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function X.ConsiderPowershot()
	if not Fu.CanCastAbility(powershotAbility) then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local castRange = powershotAbility:GetCastRange()
	local castPoint = powershotAbility:GetCastPoint()
	local arrowWidth = powershotAbility:GetSpecialValueInt("arrow_width")
	local arrowSpeed = powershotAbility:GetSpecialValueInt("arrow_speed")
	local damage = powershotAbility:GetSpecialValueInt("powershot_damage")
	local attackRange = bot:GetAttackRange()
	local manaRatio = mpRatio
	local nearbyAllies = Fu.GetNearbyHeroes(bot, 1600, false, BOT_MODE_NONE)
	local nearbyEnemies = Fu.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.IsInRange(bot, enemyHero, castRange)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and Fu.CanKillTarget(enemyHero, damage, DAMAGE_TYPE_MAGICAL)
			and not Fu.IsInRange(bot, enemyHero, attackRange - 100)
			and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
			and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
			and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
			and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
			and not enemyHero:HasModifier("modifier_templar_assassin_refraction_absorb")
		then
			local hitDelay = GetUnitToUnitDistance(bot, enemyHero) / arrowSpeed + castPoint
			return BOT_ACTION_DESIRE_HIGH, Fu.GetCorrectLoc(enemyHero, hitDelay)
		end
	end
	if isGoingOnSomeone then
		if
			Fu.IsValidHero(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and not Fu.IsInRange(bot, botTarget, attackRange)
			and not botTarget:HasModifier("modifier_dazzle_shallow_grave")
			and not botTarget:HasModifier("modifier_templar_assassin_refraction_absorb")
		then
			local hitDelay = GetUnitToUnitDistance(bot, botTarget) / arrowSpeed + castPoint
			if bot:GetLevel() < 6 then
				if Fu.CanKillTarget(botTarget, damage + bot:GetAttackDamage() * 3, DAMAGE_TYPE_ALL) then
					return BOT_ACTION_DESIRE_HIGH, Fu.GetCorrectLoc(botTarget, hitDelay)
				end
			else
				return BOT_ACTION_DESIRE_HIGH, Fu.GetCorrectLoc(botTarget, hitDelay)
			end
		end
	end
	if Fu.IsPushing(bot) or Fu.IsDefending(bot) then
		local laneCreeps = bot:GetNearbyLaneCreeps(1600, true)
		if
			Fu.IsValid(laneCreeps[1])
			and Fu.CanBeAttacked(laneCreeps[1])
			and not Fu.IsRunning(laneCreeps[1])
			and manaRatio > 0.45
		then
			local aoeLocation = bot:FindAoELocation(true, false, laneCreeps[1]:GetLocation(), 0, arrowWidth, 0, 0)
			if aoeLocation.count >= 4 then
				return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
			end
		end
		local aoeLocation = bot:FindAoELocation(true, true, bot:GetLocation(), castRange, arrowWidth, 0, 0)
		if aoeLocation.count >= 2 then
			return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
		end
	end
	if Fu.IsFarming(bot) and manaRatio > 0.33 then
		local nearbyCreeps = bot:GetNearbyCreeps(1600, true)
		if Fu.IsValid(nearbyCreeps[1]) and Fu.CanBeAttacked(nearbyCreeps[1]) and not Fu.IsRunning(nearbyCreeps[1]) then
			local aoeLocation = bot:FindAoELocation(true, false, nearbyCreeps[1]:GetLocation(), 0, arrowWidth, 0, 0)
			if
				aoeLocation.count >= 3
				or aoeLocation.count >= 2 and nearbyCreeps[1]:IsAncientCreep()
				or aoeLocation.count >= 1 and nearbyCreeps[1]:GetHealth() >= 700
			then
				return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
			end
		end
		local laneCreeps = bot:GetNearbyLaneCreeps(castRange, true)
		local enemyHeroes = Fu.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE)
		if #enemyHeroes == 0 and Fu.IsValid(laneCreeps[1]) and Fu.CanBeAttacked(laneCreeps[1]) then
			local aoeLocation = bot:FindAoELocation(true, false, laneCreeps[1]:GetLocation(), 0, arrowWidth, 0, 0)
			if aoeLocation.count >= 3 then
				return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
			end
		end
	end
	if Fu.IsLaning(bot) and (Fu.IsCore(bot) or not Fu.IsCore(bot) and not Fu.IsThereNonSelfCoreNearby(1200)) then
		local killableCount = 0
		local killableCreeps = {}
		local laneCreeps = bot:GetNearbyLaneCreeps(1600, true)
		for _, creep in pairs(laneCreeps) do
			if
				Fu.IsValid(creep)
				and (Fu.IsKeyWordUnit("ranged", creep) or Fu.IsKeyWordUnit("siege", creep) or Fu.IsKeyWordUnit(
					"flagbearer",
					creep
				))
				and creep:GetHealth() > bot:GetAttackDamage()
				and Fu.CanKillTarget(creep, damage, DAMAGE_TYPE_MAGICAL)
			then
				if mpRatio > 0.3 and Fu.CanBeAttacked(creep) and not Fu.IsRunning(creep) then
					if
						Fu.IsValidHero(nearbyEnemies[1])
						and not Fu.IsSuspiciousIllusion(nearbyEnemies[1])
						and not Fu.IsDisabled(nearbyEnemies[1])
						and not bot:WasRecentlyDamagedByTower(1)
						and GetUnitToUnitDistance(creep, nearbyEnemies[1]) < nearbyEnemies[1]:GetAttackRange()
					then
						return BOT_ACTION_DESIRE_HIGH, creep:GetLocation()
					end
				end
			end
			if Fu.IsValid(creep) and Fu.CanKillTarget(creep, damage, DAMAGE_TYPE_MAGICAL) then
				if #killableCreeps > 0 then
					if Fu.IsInRange(creep, killableCreeps[1], arrowWidth) then
						table.insert(killableCreeps, creep)
					end
				else
					table.insert(killableCreeps, creep)
				end
			end
		end
		if
			#killableCreeps >= 3
			and mpRatio > 0.25
			and Fu.CanBeAttacked(killableCreeps[1])
			and not Fu.IsRunning(killableCreeps[1])
		then
			return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(killableCreeps)
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if
			Fu.IsRoshan(botTarget)
			and Fu.CanBeAttacked(botTarget)
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
function X.ConsiderWindrun()
	if not Fu.CanCastAbility(windrunAbility) or bot:HasModifier("modifier_windrunner_windrun") then
		return BOT_ACTION_DESIRE_NONE
	end
	local manaAfter = Fu.GetManaAfter(windrunAbility:GetManaCost())
	local nearbyAllies = Fu.GetNearbyHeroes(bot, 1600, false, BOT_MODE_NONE)
	local nearbyEnemies = Fu.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE)
	if isGoingOnSomeone then
		if
			Fu.IsValidTarget(botTarget)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not botTarget:HasModifier("modifier_enigma_black_hole_pull")
			and not botTarget:HasModifier("modifier_faceless_void_chronosphere_freeze")
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			if
				Fu.IsChasingTarget(bot, botTarget)
				and not Fu.IsInRange(bot, botTarget, bot:GetAttackRange())
				and (
					botTarget:GetCurrentMovementSpeed() > bot:GetCurrentMovementSpeed() + 10
					or Fu.GetHP(botTarget) < 0.3
				)
			then
				return BOT_ACTION_DESIRE_HIGH
			end
			if bot:WasRecentlyDamagedByAnyHero(1.5) and X.IsBeingAttackedByRealHero(bot) then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	if isRetreating and not Fu.IsRealInvisible(bot) then
		if
			Fu.IsValidHero(nearbyEnemies[1])
			and Fu.CanBeAttacked(bot)
			and Fu.IsChasingTarget(nearbyEnemies[1], bot)
			and not Fu.IsSuspiciousIllusion(nearbyEnemies[1])
			and not Fu.IsDisabled(nearbyEnemies[1])
			and (bot:WasRecentlyDamagedByAnyHero(2.0) and X.IsBeingAttackedByRealHero(bot))
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsLaning(bot) then
		if
			manaAfter > 0.8
			and not bot:HasModifier("modifier_fountain_aura_buff")
			and Fu.IsInLaningPhase()
			and #nearbyEnemies == 0
		then
			local assignedLane = bot:GetAssignedLane()
			local laneFrontLocation = GetLaneFrontLocation(GetTeam(), assignedLane, 0)
			if GetUnitToLocationDistance(bot, laneFrontLocation) > 800 then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if Fu.IsRoshan(botTarget) and Fu.IsInRange(bot, botTarget, bot:GetAttackRange()) and isAttacking then
			if Fu.GetHP(bot) < 0.5 then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, bot:GetAttackRange()) and isAttacking then
			if Fu.GetHP(bot) < 0.5 then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	if bot:WasRecentlyDamagedByTower(1.0) then
		return BOT_ACTION_DESIRE_HIGH
	end
	if #nearbyEnemies >= 2 and X.IsBeingAttackedByRealHero(bot) and hpRatio < 0.7 then
		return BOT_ACTION_DESIRE_HIGH
	end
	local enemyTowers = bot:GetNearbyTowers(900, true)
	if Fu.IsValidBuilding(enemyTowers[1]) and enemyTowers[1]:GetAttackTarget() == bot then
		return BOT_ACTION_DESIRE_HIGH
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderFocusFire()
	if not Fu.CanCastAbility(focusFireAbility) then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castRange = Fu.GetProperCastRange(false, bot, focusFireAbility:GetCastRange())
	local damageMultiplier = 1 + focusFireAbility:GetSpecialValueInt("focusfire_damage_reduction") / 100
	-- Kill check counted one attack per second of the 20s duration (damage * 20), so every hero
	-- in range "died" and the ultimate went out whenever WeAreStronger, e.g. on a full-HP laner.
	-- Now: attacks in about 5s, at twice the current rate for the bonus attack speed (estimate).
	local attackCount = 10 / math.max(0.2, bot:GetSecondsPerAttack())
	local attackDamage = bot:GetAttackDamage()
	local nearbyAllies = Fu.GetNearbyHeroes(bot, 1600, false, BOT_MODE_NONE)
	local nearbyEnemies = Fu.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanBeAttacked(enemyHero)
			and not Fu.IsInEtherealForm(enemyHero)
			and enemyHero:GetHealth() > bot:GetAttackDamage() * 2
			and Fu.CanCastOnTargetAdvanced(enemyHero)
			and Fu.IsInRange(bot, enemyHero, castRange)
			and Fu.CanKillTarget(enemyHero, attackDamage * attackCount * damageMultiplier, DAMAGE_TYPE_PHYSICAL)
			and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
			and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
			and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
			and not enemyHero:HasModifier("modifier_templar_assassin_refraction_absorb")
			and not enemyHero:HasModifier("modifier_item_aeon_disk_buff")
			and not enemyHero:HasModifier("modifier_item_blade_mail_reflect")
		then
			if Fu.WeAreStronger(bot, 1600) then
				bot:SetTarget(enemyHero)
				return BOT_ACTION_DESIRE_HIGH, enemyHero
			end
		end
	end
	if isGoingOnSomeone then
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValidTarget(enemyHero)
				and Fu.CanBeAttacked(enemyHero)
				and not Fu.IsInEtherealForm(enemyHero)
				and enemyHero:GetHealth() > bot:GetAttackDamage() * 3
				and Fu.IsInRange(bot, enemyHero, castRange)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
				and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
				and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
				and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
				and not enemyHero:HasModifier("modifier_item_aeon_disk_buff")
				and not enemyHero:HasModifier("modifier_item_blade_mail_reflect")
			then
				bot:SetTarget(enemyHero)
				return BOT_ACTION_DESIRE_HIGH, enemyHero
			end
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if
			Fu.IsRoshan(botTarget)
			and Fu.IsInRange(bot, botTarget, 500)
			and Fu.GetHP(botTarget) > 0.25
			and isAttacking
			and not botTarget:HasModifier("modifier_roshan_spell_block")
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if
			Fu.IsTormentor(botTarget)
			and Fu.IsInRange(bot, botTarget, 500)
			and Fu.GetHP(botTarget) > 0.3
			and isAttacking
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function X.ConsiderGaleForce()
	if not Fu.CanCastAbility(galeForceAbility) then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local castRange = Fu.GetProperCastRange(false, bot, galeForceAbility:GetCastRange())
	local radius = galeForceAbility:GetSpecialValueInt("radius")
	local castPoint = galeForceAbility:GetCastPoint()
	if isGoingOnSomeone then
		local aoeLocation = bot:FindAoELocation(true, true, bot:GetLocation(), castRange + radius, radius, castPoint, 0)
		local enemiesInAoe = Fu.GetEnemiesNearLoc(aoeLocation.targetloc, radius)
		if
			#enemiesInAoe >= 2
			and not Fu.IsEnemyChronosphereInLocation(aoeLocation.targetloc)
			and not Fu.IsEnemyBlackHoleInLocation(aoeLocation.targetloc)
		then
			return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
		end
	end
	if isRetreating and not Fu.IsRealInvisible(bot) then
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE)
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.IsInRange(bot, enemyHero, 800)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.IsChasingTarget(enemyHero, bot)
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and not Fu.IsDisabled(enemyHero)
			then
				local alliesNearChaser = Fu.GetAlliesNearLoc(enemyHero:GetLocation(), 1200)
				local enemiesNearChaser = Fu.GetEnemiesNearLoc(enemyHero:GetLocation(), 1200)
				if #enemiesNearChaser > #alliesNearChaser and bot:WasRecentlyDamagedByAnyHero(3.0) then
					return BOT_ACTION_DESIRE_HIGH, (bot:GetLocation() + Fu.GetCenterOfUnits(enemiesNearChaser)) / 2
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.GetShackleCreepTarget(caster, target, shackleDistance, shackleAngle)
	local nearbyCreeps = target:GetNearbyCreeps(shackleDistance, false)
	for _, creep in pairs(nearbyCreeps) do
		if Fu.IsValid(creep) then
			local angle = X.GetAngleWithThreeVectors(caster:GetLocation(), creep:GetLocation(), target:GetLocation())
			if angle <= shackleAngle then
				return creep
			end
		end
	end
	return nil
end
function X.GetShackleHeroTarget(caster, target, shackleDistance, shackleAngle)
	local nearbyHeroes = target:GetNearbyHeroes(shackleDistance, false, BOT_MODE_NONE)
	for _, hero in pairs(nearbyHeroes) do
		if Fu.IsValidHero(hero) and Fu.CanCastOnNonMagicImmune(hero) and hero ~= target then
			local angle = X.GetAngleWithThreeVectors(caster:GetLocation(), hero:GetLocation(), target:GetLocation())
			if angle <= shackleAngle then
				return hero
			end
		end
	end
	return nil
end
function X.CanShackleToCreep(caster, target, shackleDistance, shackleAngle)
	local nearbyCreeps = target:GetNearbyCreeps(shackleDistance, false)
	for _, creep in pairs(nearbyCreeps) do
		if Fu.IsValid(creep) then
			local angle = X.GetAngleWithThreeVectors(caster:GetLocation(), target:GetLocation(), creep:GetLocation())
			if angle <= shackleAngle then
				return true
			end
		end
	end
	return false
end
function X.CanShackleToHero(caster, target, shackleDistance, shackleAngle)
	local nearbyHeroes = Fu.GetEnemiesNearLoc(target:GetLocation(), shackleDistance)
	for _, hero in pairs(nearbyHeroes) do
		if Fu.IsValidHero(hero) and hero ~= target then
			local angle = X.GetAngleWithThreeVectors(caster:GetLocation(), target:GetLocation(), hero:GetLocation())
			if angle <= shackleAngle then
				return true
			end
		end
	end
	nearbyHeroes = target:GetNearbyHeroes(shackleDistance, false, BOT_MODE_NONE)
	for _, hero in pairs(nearbyHeroes) do
		if Fu.IsValidHero(hero) and hero ~= target then
			local angle = X.GetAngleWithThreeVectors(caster:GetLocation(), target:GetLocation(), hero:GetLocation())
			if angle <= shackleAngle then
				return true
			end
		end
	end
	return false
end
function X.CanShackleToTree(caster, target, shackleDistance, shackleAngle)
	local nearbyTrees = target:GetNearbyTrees(shackleDistance)
	for _, tree in pairs(nearbyTrees) do
		if tree then
			local angle = X.GetAngleWithThreeVectors(caster:GetLocation(), target:GetLocation(), GetTreeLocation(tree))
			if angle <= shackleAngle then
				return true
			end
		end
	end
	return false
end
function X.GetShackleTarget(caster, target, shackleDistance, shackleAngle)
	local shackleUnit = nil
	if
		X.CanShackleToHero(caster, target, shackleDistance, shackleAngle)
		or X.CanShackleToTree(caster, target, shackleDistance, shackleAngle)
		or X.CanShackleToCreep(caster, target, shackleDistance, shackleAngle)
	then
		shackleUnit = target
	else
		shackleUnit = X.GetShackleCreepTarget(caster, target, shackleDistance, shackleAngle)
		if shackleUnit == nil then
			shackleUnit = X.GetShackleHeroTarget(caster, target, shackleDistance, shackleAngle)
		end
	end
	return shackleUnit
end
function X.GetAngleWithThreeVectors(pointA, pointB, vertex)
	local vectorA = Vector(vertex.x - pointA.x, vertex.y - pointA.y, vertex.z - pointA.z)
	local vectorB = Vector(vertex.x - pointB.x, vertex.y - pointB.y, vertex.z - pointB.z)
	local lengthA = math.sqrt(vectorA.x ^ 2 + vectorA.y ^ 2 + vectorA.z ^ 2)
	local lengthB = math.sqrt(vectorB.x ^ 2 + vectorB.y ^ 2 + vectorB.z ^ 2)
	local dotProduct = vectorA.x * vectorB.x + vectorA.y * vectorB.y + vectorA.z * vectorB.z
	return math.acos(dotProduct / (lengthA * lengthB)) * 180 / math.pi
end
function X.IsBeingAttackedByRealHero(hero)
	for _, enemyUnit in pairs(GetUnitList(UNIT_LIST_ENEMIES)) do
		if
			Fu.IsValidHero(enemyUnit)
			and not Fu.IsSuspiciousIllusion(enemyUnit)
			and (enemyUnit:GetAttackTarget() == hero or Fu.IsChasingTarget(enemyUnit, hero))
		then
			return true
		end
	end
	return false
end
return X
