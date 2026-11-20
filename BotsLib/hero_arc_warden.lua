-- Arc Warden: skill build, item build, and ability use for this hero.
local X = {}
local bot = GetBot()
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local AbilityContext = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local Minion = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local sTalentList = Fu.Skill.GetTalentList(bot)
local sAbilityList = Fu.Skill.GetAbilityList(bot)
local sRole = Fu.Item.GetRoleItemsBuyList(bot)
local sMidBuildType = RandomInt(1, 2) == 1 and "Physical" or "Magical"
local tTalentTreeList = {
	{ ["t25"] = { 10, 0 }, ["t20"] = { 10, 0 }, ["t15"] = { 10, 0 }, ["t10"] = { 10, 0 } },
	{ ["t25"] = { 10, 0 }, ["t20"] = { 0, 10 }, ["t15"] = { 0, 10 }, ["t10"] = { 0, 10 } },
	{ ["t25"] = { 10, 0 }, ["t20"] = { 10, 0 }, ["t15"] = { 10, 0 }, ["t10"] = { 0, 10 } },
}
local tAllAbilityBuildList = {
	{ 3, 1, 3, 1, 3, 6, 3, 1, 1, 2, 6, 2, 2, 2, 6 },
	{ 3, 1, 3, 1, 3, 6, 3, 1, 1, 2, 6, 2, 2, 2, 6 },
	{
		3,
		1,
		3,
		1,
		3,
		6,
		3,
		1,
		1,
		2,
		6,
		2,
		2,
		2,
		6,
	},
}
local nAbilityBuildList = tAllAbilityBuildList[1]
if sRole == "pos_1" then
	nAbilityBuildList = tAllAbilityBuildList[1]
end
if sRole == "pos_2" then
	if sMidBuildType == "Magical" then
		nAbilityBuildList = tAllAbilityBuildList[2]
	end
	if sMidBuildType == "Physical" then
		nAbilityBuildList = tAllAbilityBuildList[3]
	end
end
local nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList[1])
if sRole == "pos_1" then
	nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList[1])
end
if sRole == "pos_2" then
	if sMidBuildType == "Magical" then
		nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList[2])
	end
	if sMidBuildType == "Physical" then
		nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList[3])
	end
end
-- Item check for #9, Stratz 7.41f (week of 5-11 Nov 2026, all ranks). Dropped: Diffusal Blade and Disperser from
-- the pos 1 list (pos 1, 3,870 matches: 2.4% and 1.8%, no Diffusal before minute 25; it was the first item
-- after Midas) and Spirit Vessel from both mid lists (32 of 60,560 pos 2 matches). Hydra's Breath is not added:
-- 32% of pos 1 and 26% of pos 2 matches, at ~33 min, under the ~35% bar used for adding an item.
local sRoleItemsBuyList = {}
-- Stratz 7.41f, week of 9 Nov 2026: pos 1, 5,012 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_1"] = {
	"item_tango",
	"item_double_branches",
	"item_double_circlet",
	"item_faerie_fire",
	"item_magic_wand",
	"item_hand_of_midas",
	"item_boots",
	"item_mjollnir",
	"item_travel_boots",
	"item_orchid",
	"item_manta",
	"item_bloodthorn",
	"item_aghanims_shard",
	"item_skadi",
	"item_sheepstick",
	"item_moon_shard",
	"item_ultimate_scepter_2",
	"item_travel_boots_2",
}
-- One list for pos 2 (maintainer, 2026-11-20: the data's list, not a Magical or Physical list picked at random;
-- items by enemy lineup may come later). The talent tree still follows sMidBuildType.
-- Stratz 7.41f, week of 9 Nov 2026: pos 2, 82,550 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_2"] = {
	"item_tango",
	"item_double_branches",
	"item_double_circlet",
	"item_faerie_fire",
	"item_hand_of_midas",
	"item_boots",
	"item_mjollnir",
	"item_orchid",
	"item_travel_boots",
	"item_manta",
	"item_aghanims_shard",
	"item_bloodthorn",
	"item_skadi",
	"item_moon_shard",
	"item_ultimate_scepter_2",
	"item_travel_boots_2",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 3 has 621 matches, built from pos 2 (82,550) (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_3"] = sRoleItemsBuyList["pos_2"]
-- Stratz 7.41f, week of 9 Nov 2026: pos 4, 1,223 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_4"] = {
	"item_tango",
	"item_blood_grenade",
	"item_double_branches",
	"item_circlet",
	"item_faerie_fire",
	"item_magic_wand",
	"item_boots",
	"item_hand_of_midas",
	"item_maelstrom",
	"item_orchid",
	"item_ultimate_scepter",
	"item_mjollnir",
	"item_travel_boots",
	"item_aghanims_shard",
	"item_bloodthorn",
	"item_sheepstick",
	"item_ultimate_scepter_2",
	"item_moon_shard",
	"item_skadi",
	"item_force_staff",
	"item_hurricane_pike",
	"item_travel_boots_2",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 5, 1,031 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_5"] = {
	"item_tango",
	"item_blood_grenade",
	"item_double_branches",
	"item_circlet",
	"item_faerie_fire",
	"item_magic_wand",
	"item_boots",
	"item_hand_of_midas",
	"item_maelstrom",
	"item_orchid",
	"item_mjollnir",
	"item_ultimate_scepter",
	"item_travel_boots",
	"item_aghanims_shard",
	"item_bloodthorn",
	"item_skadi",
	"item_ultimate_scepter_2",
	"item_force_staff",
	"item_moon_shard",
	"item_travel_boots_2",
}
X["sBuyList"] = sRoleItemsBuyList[sRole]
X["sSellList"] = { "item_travel_boots", "item_magic_wand", "item_sheepstick", "item_hand_of_midas" }
if Fu.Role.IsPvNMode() or Fu.Role.IsAllShadow() then
	X["sBuyList"], X["sSellList"] = { "PvN_ranged_carry" }, {}
end
nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"] =
	Fu.SetUserHeroInit(nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"])
X["sSkillList"] = Fu.Skill.GetSkillList(sAbilityList, nAbilityBuildList, sTalentList, nTalentBuildList)
X["bDeafaultAbility"] = false
X["bDeafaultItem"] = false
function X.MinionThink(hMinionUnit)
	Minion.MinionThink(hMinionUnit)
end
local fluxAbility = SafeAbility(bot:GetAbilityByName("arc_warden_flux"), "arc_warden_flux", "arc_warden")
local magneticFieldAbility =
	SafeAbility(bot:GetAbilityByName("arc_warden_magnetic_field"), "arc_warden_magnetic_field", "arc_warden")
local sparkWraithAbility =
	SafeAbility(bot:GetAbilityByName("arc_warden_spark_wraith"), "arc_warden_spark_wraith", "arc_warden")
local tempestDoubleAbility =
	SafeAbility(bot:GetAbilityByName("arc_warden_tempest_double"), "arc_warden_tempest_double", "arc_warden")
local fluxDesire, fluxTarget
local magneticFieldDesire, magneticFieldLocation
local sparkWraithDesire, sparkWraithLocation
local tempestDoubleDesire, tempestDoubleLocation
local tempestDouble = nil
local botTarget
local isGoingOnSomeone
local isAttacking
local mpRatio
local isInTeamFight
function X.SkillsComplement()
	if Fu.CanNotUseAbility(bot) or Fu.IsRealInvisible(bot) then
		return
	end
	local context = AbilityContext.Build(bot)
	isGoingOnSomeone = context.isEngaging
	isAttacking = Fu.IsAttacking(bot)
	mpRatio = context.mp
	isInTeamFight = context.isTeamFight
	botTarget = context.target
	tempestDoubleDesire, tempestDoubleLocation = X.ConsiderTempestDouble()
	if tempestDoubleDesire > 0 then
		bot:Action_UseAbilityOnLocation(tempestDoubleAbility, tempestDoubleLocation)
		return
	end
	magneticFieldDesire, magneticFieldLocation = X.ConsiderMagneticField()
	if magneticFieldDesire > 0 then
		Fu.SetQueuePtToINT(bot, false)
		if Fu.CheckBitfieldFlag(magneticFieldAbility:GetBehavior(), ABILITY_BEHAVIOR_POINT) then
			bot:Action_UseAbilityOnLocation(magneticFieldAbility, magneticFieldLocation)
		else
			bot:ActionQueue_UseAbility(magneticFieldAbility)
		end
		return
	end
	fluxDesire, fluxTarget = X.ConsiderFlux()
	if fluxDesire > 0 then
		Fu.SetQueuePtToINT(bot, false)
		bot:ActionQueue_UseAbilityOnEntity(fluxAbility, fluxTarget)
		return
	end
	sparkWraithDesire, sparkWraithLocation = X.ConsiderSparkWraith()
	if sparkWraithDesire > 0 then
		Fu.SetQueuePtToINT(bot, false)
		bot:ActionQueue_UseAbilityOnLocation(sparkWraithAbility, sparkWraithLocation)
		return
	end
end
function X.ConsiderFlux()
	if not fluxAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castRange = Fu.GetProperCastRange(false, bot, fluxAbility:GetCastRange() + 75)
	local damagePerSecond = fluxAbility:GetSpecialValueInt("damage_per_second")
	local duration = fluxAbility:GetSpecialValueInt("duration")
	local damage = damagePerSecond * duration
	local enemiesInRange = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(enemiesInRange) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and Fu.CanCastOnTargetAdvanced(enemyHero)
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
	if isInTeamFight then
		local strongestEnemy = nil
		local maxDamage = 0
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, castRange + 150, true, BOT_MODE_NONE)
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValid(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and not Fu.IsDisabled(enemyHero)
				and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
				and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
			then
				local estimatedDamage = enemyHero:GetEstimatedDamageToTarget(false, bot, duration, DAMAGE_TYPE_ALL)
				if estimatedDamage > maxDamage then
					maxDamage = estimatedDamage
					strongestEnemy = enemyHero
				end
			end
		end
		if strongestEnemy ~= nil then
			return BOT_ACTION_DESIRE_HIGH, strongestEnemy
		end
	end
	if isGoingOnSomeone then
		if
			Fu.IsValidHero(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.CanCastOnTargetAdvanced(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange + 75)
			and not Fu.IsSuspiciousIllusion(botTarget)
		then
			local alliesNearTarget = Fu.GetNearbyHeroes(botTarget, 1600, true, BOT_MODE_NONE)
			local enemiesNearTarget = Fu.GetNearbyHeroes(botTarget, 1600, false, BOT_MODE_NONE)
			if alliesNearTarget ~= nil and enemiesNearTarget ~= nil and #alliesNearTarget >= #enemiesNearTarget then
				return BOT_ACTION_DESIRE_HIGH, botTarget
			end
		end
	end
	if Fu.IsRetreating(bot) then
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
		if
			Fu.IsValidHero(nearbyEnemies[1])
			and Fu.CanCastOnNonMagicImmune(nearbyEnemies[1])
			and Fu.CanCastOnTargetAdvanced(nearbyEnemies[1])
			and Fu.IsChasingTarget(nearbyEnemies[1], bot)
			and not Fu.IsSuspiciousIllusion(nearbyEnemies[1])
			and not Fu.IsDisabled(nearbyEnemies[1])
		then
			local alliesNearEnemy = Fu.GetNearbyHeroes(nearbyEnemies[1], 1200, true, BOT_MODE_NONE)
			local enemiesNearEnemy = Fu.GetNearbyHeroes(nearbyEnemies[1], 1200, false, BOT_MODE_NONE)
			if
				alliesNearEnemy ~= nil
				and enemiesNearEnemy ~= nil
				and (#enemiesNearEnemy > #alliesNearEnemy or bot:WasRecentlyDamagedByAnyHero(2))
			then
				return BOT_ACTION_DESIRE_HIGH, nearbyEnemies[1]
			end
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if
			Fu.IsRoshan(botTarget)
			and Fu.CanCastOnMagicImmune(botTarget)
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
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.ConsiderMagneticField()
	if not magneticFieldAbility:IsFullyCastable() or X.IsDoubleCasting() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local castRange = Fu.GetProperCastRange(false, bot, magneticFieldAbility:GetCastRange())
	local radius = magneticFieldAbility:GetSpecialValueInt("radius")
	if isInTeamFight then
		local aoeLocation = bot:FindAoELocation(false, true, bot:GetLocation(), castRange, radius, 0, 0)
		if aoeLocation.count >= 2 and GetUnitToLocationDistance(bot, aoeLocation.targetloc) <= bot:GetAttackRange() then
			local alliesNearLocation = Fu.GetAlliesNearLoc(aoeLocation.targetloc, radius)
			if
				Fu.IsValidHero(alliesNearLocation[1])
				and alliesNearLocation[1]:GetAttackTarget() ~= nil
				and GetUnitToUnitDistance(alliesNearLocation[1], alliesNearLocation[1]:GetAttackTarget()) <= alliesNearLocation[1]:GetAttackRange() + 50
				and not alliesNearLocation[1]:HasModifier("modifier_arc_warden_magnetic_field")
			then
				-- fix: the ally group was found, then the field went on Arc's own spot; it is a
				-- POINT spell (cast range 900, game data), so put it on the group.
				return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
			end
		end
	end
	-- fix: the field was never used to survive. It evades attacks from outside the field (datafeed;
	-- 100% evasion, radius 300 in game data): drop it on himself when retreating from a ranged
	-- hero that is right-clicking him from outside that radius.
	if
		Fu.IsRetreating(bot)
		and bot:WasRecentlyDamagedByAnyHero(1.5)
		and not bot:HasModifier("modifier_arc_warden_magnetic_field")
	then
		for _, chaser in pairs(Fu.GetNearbyHeroes(bot, 900, true, BOT_MODE_NONE) or {}) do
			if
				Fu.IsValidHero(chaser)
				and not Fu.IsSuspiciousIllusion(chaser)
				and chaser:GetAttackTarget() == bot
				and GetUnitToUnitDistance(bot, chaser) > radius + 50
			then
				if DotaTime() >= (bot._arcFieldLogAt or -999) then
					bot._arcFieldLogAt = DotaTime() + 10
					pcall(
						print,
						string.format("[OHA-ARC] t=%.0f magnetic field retreat hp=%.2f", DotaTime(), Fu.GetHP(bot))
					)
				end
				return BOT_ACTION_DESIRE_HIGH, bot:GetLocation()
			end
		end
	end
	if isGoingOnSomeone then
		if Fu.IsValidTarget(botTarget) and Fu.IsInRange(bot, botTarget, castRange) then
			local nearbyAllies = Fu.GetNearbyHeroes(bot, castRange, false, BOT_MODE_ATTACK)
			for _, allyHero in pairs(nearbyAllies) do
				local allyTarget = allyHero:GetAttackTarget()
				if
					Fu.IsValidHero(allyHero)
					and (Fu.IsInRange(bot, allyHero, radius) and not allyHero:HasModifier(
						"modifier_arc_warden_magnetic_field"
					))
					and (Fu.IsValidTarget(allyTarget) and GetUnitToUnitDistance(allyHero, allyTarget) <= allyHero:GetAttackRange())
					and not Fu.IsSuspiciousIllusion(allyHero)
					and not Fu.IsSuspiciousIllusion(allyTarget)
					and not allyTarget:HasModifier("modifier_abaddon_borrowed_time")
				then
					local alliesNearTarget = Fu.GetNearbyHeroes(botTarget, 1600, true, BOT_MODE_NONE)
					local enemiesNearTarget = Fu.GetNearbyHeroes(botTarget, 1600, false, BOT_MODE_NONE)
					if
						alliesNearTarget ~= nil
						and enemiesNearTarget ~= nil
						and #alliesNearTarget >= #enemiesNearTarget
					then
						return BOT_ACTION_DESIRE_HIGH, bot:GetLocation()
					end
				end
			end
		end
	end
	if (Fu.IsDefending(bot) or Fu.IsPushing(bot)) and not bot:HasModifier("modifier_arc_warden_magnetic_field") then
		local nearbyLaneCreeps = bot:GetNearbyLaneCreeps(888, true)
		local nearbyTowers = bot:GetNearbyTowers(888, true)
		-- fix: the results were never stored (nearbyBarracks/nearbyFillers stayed nil), so barracks and fillers never
		-- triggered the field while pushing. Both methods exist ([OHA-API] dump).
		local nearbyBarracks = bot:GetNearbyBarracks(888, true)
		local nearbyFillers = bot:GetNearbyFillers(888, true)
		if isAttacking then
			if
				nearbyLaneCreeps ~= nil and #nearbyLaneCreeps >= 3
				or nearbyTowers ~= nil and #nearbyTowers >= 1
				or nearbyBarracks ~= nil and #nearbyBarracks >= 1
				or nearbyFillers ~= nil and #nearbyFillers >= 1
			then
				return BOT_ACTION_DESIRE_HIGH, bot:GetLocation()
			end
		end
	end
	if
		Fu.IsFarming(bot)
		and Fu.GetManaAfter(magneticFieldAbility:GetManaCost()) * bot:GetMana() > magneticFieldAbility:GetManaCost() * 1.5
		and not bot:HasModifier("modifier_arc_warden_magnetic_field")
	then
		local nearbyLaneCreeps = bot:GetNearbyLaneCreeps(888, true)
		if isAttacking then
			if nearbyLaneCreeps ~= nil and #nearbyLaneCreeps >= 3 then
				return BOT_ACTION_DESIRE_HIGH, bot:GetLocation()
			end
			local nearbyNeutrals = bot:GetNearbyNeutralCreeps(888)
			if
				nearbyNeutrals ~= nil
				and (#nearbyNeutrals >= 3 or #nearbyNeutrals >= 2 and nearbyNeutrals[1]:IsAncientCreep())
			then
				return BOT_ACTION_DESIRE_HIGH, bot:GetLocation()
			end
		end
	end
	if Fu.IsDoingRoshan(bot) and not bot:HasModifier("modifier_arc_warden_magnetic_field") then
		if Fu.IsRoshan(botTarget) and Fu.IsInRange(bot, botTarget, bot:GetAttackRange()) and isAttacking then
			return BOT_ACTION_DESIRE_HIGH, bot:GetLocation()
		end
	end
	if Fu.IsDoingTormentor(bot) and not bot:HasModifier("modifier_arc_warden_magnetic_field") then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, bot:GetAttackRange()) and isAttacking then
			return BOT_ACTION_DESIRE_HIGH, bot:GetLocation()
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.ConsiderSparkWraith()
	if not sparkWraithAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local castRange = Fu.GetProperCastRange(false, bot, sparkWraithAbility:GetCastRange())
	local radius = sparkWraithAbility:GetSpecialValueInt("radius")
	-- datafeed: the keys are now spark_damage_base and base_activation_delay (1.5s); the old
	-- "spark_damage"/"activation_delay" read 0, so the kill check never fired and the lead was too short.
	local damage = sparkWraithAbility:GetSpecialValueInt("spark_damage_base")
	local castPoint = sparkWraithAbility:GetCastPoint()
	local delay = sparkWraithAbility:GetSpecialValueFloat("base_activation_delay") + castPoint
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
			return BOT_ACTION_DESIRE_HIGH, enemyHero:GetExtrapolatedLocation(delay)
		end
	end
	if isGoingOnSomeone then
		if
			Fu.IsValidHero(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
			and not botTarget:HasModifier("modifier_templar_assassin_refraction_absorb")
			and not botTarget:HasModifier("modifier_item_aeon_disk_buff")
		then
			local alliesNearTarget = Fu.GetNearbyHeroes(botTarget, 1600, true, BOT_MODE_NONE)
			local enemiesNearTarget = Fu.GetNearbyHeroes(botTarget, 1600, false, BOT_MODE_NONE)
			if alliesNearTarget ~= nil and enemiesNearTarget ~= nil then
				if Fu.IsRunning(botTarget) then
					return BOT_ACTION_DESIRE_MODERATE, botTarget:GetExtrapolatedLocation(delay)
				else
					return BOT_ACTION_DESIRE_MODERATE, botTarget:GetLocation()
				end
			end
		end
		local aoeLocation = bot:FindAoELocation(true, true, bot:GetLocation(), 1400, radius, 2, 0)
		local enemiesNearLocation = Fu.GetEnemiesNearLoc(aoeLocation.targetloc, radius)
		if
			enemiesNearLocation ~= nil
			and #enemiesNearLocation >= 1
			and Fu.GetManaAfter(sparkWraithAbility:GetManaCost()) * bot:GetMana() > fluxAbility:GetManaCost() + magneticFieldAbility:GetManaCost() + sparkWraithAbility:GetManaCost()
			and not bot:HasModifier("modifier_silencer_curse_of_the_silent")
		then
			local vulnerableUnit = Fu.GetVulnerableUnitNearLoc(bot, false, true, 1600, radius, aoeLocation.targetloc)
			if vulnerableUnit == nil or bot:HasModifier("modifier_arc_warden_tempest_double") then
				return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
			end
		end
	end
	if
		Fu.IsRetreating(bot)
		and bot:GetActiveModeDesire() > BOT_ACTION_DESIRE_HIGH
		and not bot:HasModifier("modifier_silencer_curse_of_the_silent")
	then
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, 800, true, BOT_MODE_NONE)
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValid(enemyHero)
				and bot:WasRecentlyDamagedByHero(enemyHero, 1)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
			then
				return BOT_ACTION_DESIRE_HIGH, bot:GetLocation()
			end
		end
	end
	if Fu.IsPushing(bot) or Fu.IsDefending(bot) then
		local aoeLocation = bot:FindAoELocation(true, false, bot:GetLocation(), 1400, radius, 2, 0)
		if aoeLocation.count > 2 and not bot:HasModifier("modifier_silencer_curse_of_the_silent") then
			if bot:HasModifier("modifier_arc_warden_tempest_double") then
				return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
			end
			local nearbyLaneCreeps = bot:GetNearbyLaneCreeps(1400, true)
			if nearbyLaneCreeps ~= nil and #nearbyLaneCreeps >= 2 then
				if mpRatio > 0.62 then
					return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
				end
			else
				if mpRatio > 0.75 then
					return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
				end
			end
		end
	end
	if Fu.IsFarming(bot) then
		local aoeLocation = bot:FindAoELocation(true, false, bot:GetLocation(), 1400, radius, 2, 0)
		if aoeLocation.count >= 1 and not bot:HasModifier("modifier_silencer_curse_of_the_silent") then
			if bot:HasModifier("modifier_arc_warden_tempest_double") then
				return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
			end
			local nearbyLaneCreeps = bot:GetNearbyLaneCreeps(1400, true)
			if nearbyLaneCreeps ~= nil and #nearbyLaneCreeps >= 1 then
				if mpRatio > 0.42 then
					return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
				end
			else
				if mpRatio > 0.55 then
					return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
				end
			end
		end
	end
	if Fu.IsLaning(bot) and Fu.IsInLaningPhase() and bot:GetLevel() < 7 then
		local nearbyLaneCreeps = bot:GetNearbyLaneCreeps(1600, true)
		for _, creep in pairs(nearbyLaneCreeps) do
			if
				Fu.IsValid(creep)
				and Fu.CanBeAttacked(creep)
				and Fu.IsKeyWordUnit("ranged", creep)
				and creep:GetHealth() <= damage
				and botTarget ~= creep
				and not Fu.IsRunning(creep)
			then
				return BOT_ACTION_DESIRE_HIGH, creep:GetLocation()
			end
		end
	end
	if
		sparkWraithAbility:GetLevel() >= 3
		and Fu.GetManaAfter(sparkWraithAbility:GetManaCost()) * bot:GetMana() > fluxAbility:GetManaCost() + magneticFieldAbility:GetManaCost() + sparkWraithAbility:GetManaCost()
		and not Fu.IsLaning(bot)
	then
		local aoeLocation = bot:FindAoELocation(true, true, bot:GetLocation(), 1400, radius, 2, 0)
		local enemiesNearLocation = Fu.GetEnemiesNearLoc(aoeLocation.targetloc, radius)
		if enemiesNearLocation ~= nil and #enemiesNearLocation >= 2 then
			return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(enemiesNearLocation)
		end
	end
	if
		bot:GetLevel() >= 10
		and (Fu.GetManaAfter(sparkWraithAbility:GetManaCost()) * bot:GetMana() > fluxAbility:GetManaCost() + magneticFieldAbility:GetManaCost() + sparkWraithAbility:GetManaCost() or bot:HasModifier(
			"modifier_arc_warden_tempest_double"
		))
		and DotaTime() > 8 * 60
	then
		local enemyHeroes = GetUnitList(UNIT_LIST_ENEMY_HEROES)
		local weakestEnemy = nil
		local minHealth = 99999
		for _, enemyHero in pairs(enemyHeroes) do
			if
				Fu.IsValidHero(enemyHero)
				and GetUnitToUnitDistance(bot, enemyHero) <= castRange
				and enemyHero:GetHealth() < minHealth
			then
				weakestEnemy = enemyHero
				minHealth = enemyHero:GetHealth()
			end
		end
		if weakestEnemy ~= nil then
			for offset = 0, 350, 50 do
				local location = Fu.GetLocationTowardDistanceLocation(weakestEnemy, Fu.GetEnemyFountain(), 350 - offset)
				if GetUnitToLocationDistance(bot, location) <= castRange then
					return BOT_ACTION_DESIRE_HIGH, location
				end
			end
		end
		local nearbyLaneCreeps = bot:GetNearbyLaneCreeps(1600, true)
		if nearbyLaneCreeps ~= nil and #nearbyLaneCreeps >= 3 then
			local furthestCreep = nearbyLaneCreeps[#nearbyLaneCreeps]
			if Fu.IsValid(furthestCreep) and Fu.CanBeAttacked(furthestCreep) then
				local location = Fu.GetFaceTowardDistanceLocation(furthestCreep, 375)
				return BOT_ACTION_DESIRE_HIGH, location
			end
		end
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE)
		local laneFrontLocation = Fu.GetNearestLaneFrontLocation(bot:GetLocation(), true, radius / 2)
		if
			nearbyEnemies ~= nil
			and #nearbyEnemies == 0
			and laneFrontLocation ~= nil
			and GetUnitToLocationDistance(bot, laneFrontLocation) <= castRange + radius
			and GetUnitToLocationDistance(bot, laneFrontLocation) >= 800
		then
			local location = Fu.GetLocationTowardDistanceLocation(bot, laneFrontLocation, castRange)
			if GetUnitToLocationDistance(bot, laneFrontLocation) < castRange then
				location = laneFrontLocation
			end
			return BOT_ACTION_DESIRE_HIGH, location
		end
	end
	local location = Fu.GetLocationTowardDistanceLocation(bot, Fu.GetEnemyFountain(), castRange)
	if
		bot:HasModifier("modifier_arc_warden_tempest_double")
		or mpRatio > 0.92 and bot:GetLevel() > 11 and not IsLocationVisible(location)
		or mpRatio > 0.38 and Fu.GetDistanceFromEnemyFountain(bot) < 4300
	then
		if IsLocationPassable(location) and not bot:HasModifier("modifier_silencer_curse_of_the_silent") then
			return BOT_ACTION_DESIRE_HIGH, location
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if
			Fu.IsRoshan(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and Fu.GetHP(botTarget) > 0.2
			and isAttacking
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if
			Fu.IsTormentor(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and Fu.GetHP(botTarget) > 0.2
			and isAttacking
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.ConsiderTempestDouble()
	X.UpdateDoubleStatus()
	if not tempestDoubleAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local castRange = Fu.GetProperCastRange(false, bot, tempestDoubleAbility:GetCastRange())
	if Fu.IsDefending(bot) or Fu.IsPushing(bot) or Fu.IsFarming(bot) then
		local nearbyLaneCreeps = bot:GetNearbyLaneCreeps(800, true)
		local nearbyTowers = bot:GetNearbyTowers(800, true)
		local nearbyCreeps = bot:GetNearbyCreeps(800, true)
		if isAttacking then
			if
				nearbyLaneCreeps ~= nil and #nearbyLaneCreeps >= 2
				or nearbyTowers ~= nil and #nearbyTowers >= 1
				or nearbyCreeps ~= nil and #nearbyCreeps >= 2
			then
				return BOT_ACTION_DESIRE_HIGH, bot:GetLocation()
			end
		end
	end
	if isInTeamFight then
		local healthiestEnemy = nil
		local maxHealth = 0
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE)
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.IsInRange(bot, enemyHero, castRange)
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and not enemyHero:HasModifier("modifier_faceless_void_chronosphere_freeze")
			then
				local health = enemyHero:GetHealth()
				if maxHealth < health then
					maxHealth = health
					healthiestEnemy = enemyHero
				end
			end
		end
		if healthiestEnemy ~= nil then
			if Fu.IsRunning(healthiestEnemy) then
				return BOT_ACTION_DESIRE_HIGH, healthiestEnemy:GetLocation()
			else
				return BOT_ACTION_DESIRE_HIGH, bot:GetLocation()
			end
		end
	end
	if isGoingOnSomeone then
		if
			Fu.IsValidHero(botTarget)
			and Fu.IsInRange(bot, botTarget, 1600)
			and not Fu.IsSuspiciousIllusion(botTarget)
		then
			local alliesNearTarget = Fu.GetNearbyHeroes(botTarget, 1600, true, BOT_MODE_NONE)
			local enemiesNearTarget = Fu.GetNearbyHeroes(botTarget, 1600, false, BOT_MODE_NONE)
			if alliesNearTarget ~= nil and enemiesNearTarget ~= nil and #alliesNearTarget + 1 >= #enemiesNearTarget then
				if botTarget:HasModifier("modifier_faceless_void_chronosphere_freeze") then
					return BOT_ACTION_DESIRE_HIGH, bot:GetLocation()
				end
				if Fu.IsInRange(bot, botTarget, bot:GetAttackRange()) then
					if Fu.IsRunning(botTarget) then
						return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
					else
						return BOT_ACTION_DESIRE_HIGH, bot:GetLocation()
					end
				end
				if not Fu.IsInRange(bot, botTarget, bot:GetAttackRange()) then
					return BOT_ACTION_DESIRE_HIGH,
						Fu.Site.GetXUnitsTowardsLocation(bot, botTarget:GetLocation(), castRange)
				end
			end
		end
	end
	local handOfMidas = Fu.GetComboItem(bot, "item_hand_of_midas")
	if handOfMidas ~= nil and X.IsDoubleMidasCooldown() and bot:DistanceFromFountain() > 600 then
		local nearbyCreeps = bot:GetNearbyCreeps(1600, true)
		if #nearbyCreeps >= 1 then
			return BOT_ACTION_DESIRE_HIGH, bot:GetLocation()
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if
			Fu.IsRoshan(botTarget)
			and Fu.IsInRange(bot, botTarget, bot:GetAttackRange())
			and Fu.GetHP(botTarget) > 0.5
			and isAttacking
		then
			return BOT_ACTION_DESIRE_HIGH, bot:GetLocation()
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, bot:GetAttackRange()) and isAttacking then
			return BOT_ACTION_DESIRE_HIGH, bot:GetLocation()
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.IsDoubleMidasCooldown()
	if tempestDouble == nil then
		X.UpdateDoubleStatus()
	end
	if tempestDouble ~= nil then
		local handOfMidas = Fu.GetComboItem(tempestDouble, "item_hand_of_midas")
		if handOfMidas ~= nil and (handOfMidas:IsFullyCastable() or handOfMidas:GetCooldownTimeRemaining() <= 3) then
			return true
		end
	end
	return false
end
function X.UpdateDoubleStatus()
	if tempestDouble == nil and bot:GetLevel() >= 6 then
		for _, allyHero in pairs(GetUnitList(UNIT_LIST_ALLIED_HEROES)) do
			if
				allyHero ~= nil
				and allyHero:IsAlive()
				and allyHero:HasModifier("modifier_arc_warden_tempest_double")
			then
				tempestDouble = allyHero
			end
		end
	end
end
function X.IsDoubleCasting()
	if tempestDouble == nil or not tempestDouble:IsAlive() then
		return false
	end
	for _, allyHero in pairs(GetUnitList(UNIT_LIST_ALLIED_HEROES)) do
		if
			Fu.IsValid(allyHero)
			and allyHero ~= bot
			and allyHero:GetUnitName() == "npc_dota_hero_arc_warden"
			and (allyHero:IsCastingAbility() or allyHero:IsUsingAbility())
		then
			return true
		end
	end
	return false
end
return X
