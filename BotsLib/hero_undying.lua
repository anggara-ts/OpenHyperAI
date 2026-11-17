-- Undying: skill build, item build, and ability use for this hero.
local X = {}
local bot = GetBot()
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local AbilityContext = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local Minion = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local sTalentList = Fu.Skill.GetTalentList(bot)
local sAbilityList = Fu.Skill.GetAbilityList(bot)
local sRole = Fu.Item.GetRoleItemsBuyList(bot)
local tTalentTreeList = { ["t25"] = { 10, 0 }, ["t20"] = { 0, 10 }, ["t15"] = { 10, 0 }, ["t10"] = { 0, 10 } }
local tAllAbilityBuildList = { { 1, 3, 1, 3, 1, 6, 1, 3, 3, 2, 6, 2, 2, 2, 6 } }
local nAbilityBuildList = Fu.Skill.GetRandomBuild(tAllAbilityBuildList)
local nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList)
local sUtility = "item_team_aura"
local sRoleItemsBuyList = {}
-- One pair of boots in this build (user rule; Util/boots-check.js).
-- No Boots of Travel: this build's Guardian Greaves / Boots of Bearing are its one pair of boots.
sRoleItemsBuyList["pos_4"] = {
	"item_blood_grenade",
	"item_tango",
	"item_double_branches",
	"item_magic_wand",
	"item_arcane_boots",
	"item_essence_distiller",
	"item_crimson_guard",
	"item_guardian_greaves",
	"item_aghanims_shard",
	"item_blade_mail",
	"item_lotus_orb",
	"item_assault",
	"item_ultimate_scepter_2",
	"item_moon_shard",
}
sRoleItemsBuyList["pos_5"] = {
	"item_blood_grenade",
	"item_mage_outfit",
	"item_ancient_janggo",
	"item_glimmer_cape",
	"item_boots_of_bearing",
	"item_pipe",
	"item_aghanims_shard",
	"item_ultimate_scepter",
	"item_cyclone",
	"item_lotus_orb",
	"item_shivas_guard",
	"item_sheepstick",
	"item_moon_shard",
	"item_ultimate_scepter_2",
}
sRoleItemsBuyList["pos_1"] = {
	"item_bristleback_outfit",
	"item_aghanims_shard",
	"item_blade_mail",
	"item_heavens_halberd",
	"item_lotus_orb",
	"item_black_king_bar",
	"item_ultimate_scepter",
	"item_travel_boots",
	"item_ultimate_scepter_2",
	"item_heart",
	"item_moon_shard",
	"item_travel_boots_2",
}
sRoleItemsBuyList["pos_2"] = sRoleItemsBuyList["pos_1"]
sRoleItemsBuyList["pos_3"] = {
	"item_tank_outfit",
	"item_blade_mail",
	"item_crimson_guard",
	"item_aghanims_shard",
	"item_ultimate_scepter",
	"item_lotus_orb",
	"item_heavens_halberd",
	"item_sheepstick",
	"item_octarine_core",
	"item_travel_boots",
	"item_moon_shard",
	"item_travel_boots_2",
	"item_ultimate_scepter_2",
}
X["sBuyList"] = sRoleItemsBuyList[sRole]
X["sSellList"] = { "item_power_treads", "item_quelling_blade" }
if Fu.Role.IsPvNMode() or Fu.Role.IsAllShadow() then
	X["sBuyList"], X["sSellList"] = { "PvN_antimage" }, {}
end
nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"] = Fu.SetUserHeroInit(nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"])
X["sSkillList"] = Fu.Skill.GetSkillList(sAbilityList, nAbilityBuildList, sTalentList, nTalentBuildList)
X["bDeafaultAbility"] = false
X["bDeafaultItem"] = false
function X.MinionThink(minionUnit)
	Minion.MinionThink(minionUnit)
end
local decayAbility = SafeAbility(bot:GetAbilityByName("undying_decay"), "undying_decay", "undying")
local soulRipAbility = SafeAbility(bot:GetAbilityByName("undying_soul_rip"), "undying_soul_rip", "undying")
local tombstoneAbility = SafeAbility(bot:GetAbilityByName("undying_tombstone"), "undying_tombstone", "undying")
local fleshGolemAbility = SafeAbility(bot:GetAbilityByName("undying_flesh_golem"), "undying_flesh_golem", "undying")
local decayDesire, decayLocation
local soulRipDesire, soulRipTarget
local tombstoneDesire, tombstoneLocation
local fleshGolemDesire
local botTarget
local isAttacking
local hpRatio
local mpRatio
local isInTeamFight
function X.SkillsComplement()
	if Fu.CanNotUseAbility(bot) then
		return
	end
	local context = AbilityContext.Build(bot)
	isAttacking = Fu.IsAttacking(bot)
	hpRatio = context.hp
	mpRatio = context.mp
	isInTeamFight = context.isTeamFight
	botTarget = context.target
	fleshGolemDesire = X.ConsiderFleshGolem()
	if fleshGolemDesire > 0 then
		bot:Action_UseAbility(fleshGolemAbility)
		return
	end
	tombstoneDesire, tombstoneLocation = X.ConsiderTombstone()
	if tombstoneDesire > 0 then
		bot:Action_UseAbilityOnLocation(tombstoneAbility, tombstoneLocation)
		return
	end
	decayDesire, decayLocation = X.ConsiderDecay()
	if decayDesire > 0 then
		bot:Action_UseAbilityOnLocation(decayAbility, decayLocation)
		return
	end
	soulRipDesire, soulRipTarget = X.ConsiderSoulRip()
	if soulRipDesire > 0 then
		bot:Action_UseAbilityOnEntity(soulRipAbility, soulRipTarget)
		return
	end
end
function X.ConsiderDecay()
	if not decayAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local castRange = Fu.GetProperCastRange(false, bot, decayAbility:GetCastRange())
	local radius = decayAbility:GetSpecialValueInt("radius")
	local damage = decayAbility:GetSpecialValueInt("decay_damage")
	local abilityLevel = decayAbility:GetLevel()
	local nearbyEnemies = Fu.GetNearbyHeroes(bot, castRange + radius, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and Fu.CanKillTarget(enemyHero, damage, DAMAGE_TYPE_MAGICAL)
			and not Fu.IsSuspiciousIllusion(enemyHero)
			and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
			and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
			and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
			and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
		then
			local enemiesInRadius = Fu.GetEnemiesNearLoc(enemyHero:GetLocation(), radius)
			if enemiesInRadius ~= nil and #enemiesInRadius >= 1 then
				if not Fu.IsInRange(bot, enemyHero, castRange) then
					return BOT_ACTION_DESIRE_HIGH, Fu.Site.GetXUnitsTowardsLocation(bot, Fu.GetCenterOfUnits(enemiesInRadius), castRange)
				else
					return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(enemiesInRadius)
				end
			end
			if not Fu.IsInRange(bot, enemyHero, castRange) then
				return BOT_ACTION_DESIRE_HIGH, Fu.Site.GetXUnitsTowardsLocation(bot, enemyHero:GetLocation(), castRange)
			else
				return BOT_ACTION_DESIRE_HIGH, enemyHero:GetLocation()
			end
		end
	end
	if isInTeamFight then
		local aoe = bot:FindAoELocation(true, true, bot:GetLocation(), castRange + radius, radius, 0, 0)
		local enemiesInRadius = Fu.GetEnemiesNearLoc(aoe.targetloc, radius)
		if enemiesInRadius ~= nil and #enemiesInRadius >= 2 then
			return BOT_ACTION_DESIRE_HIGH, Fu.Site.GetXUnitsTowardsLocation(bot, aoe.targetloc, castRange)
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, castRange + radius, true, BOT_MODE_NONE)
		for _, enemyHero in pairs(nearbyEnemies) do
			if Fu.IsValidHero(enemyHero) and Fu.CanCastOnNonMagicImmune(enemyHero) and not Fu.IsSuspiciousIllusion(enemyHero) then
				local alliesNearTarget = Fu.GetNearbyHeroes(enemyHero, 1200, true, BOT_MODE_NONE)
				local enemiesNearTarget = Fu.GetNearbyHeroes(enemyHero, 1200, false, BOT_MODE_NONE)
				if alliesNearTarget ~= nil and enemiesNearTarget ~= nil and #alliesNearTarget >= #enemiesNearTarget then
					nearbyEnemies = Fu.GetEnemiesNearLoc(enemyHero:GetLocation(), radius)
					if nearbyEnemies ~= nil and #nearbyEnemies >= 1 then
						if not Fu.IsInRange(bot, enemyHero, castRange) then
							return BOT_ACTION_DESIRE_HIGH, Fu.Site.GetXUnitsTowardsLocation(bot, Fu.GetCenterOfUnits(nearbyEnemies), castRange)
						else
							return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(nearbyEnemies)
						end
					end
					if not Fu.IsInRange(bot, enemyHero, castRange) then
						return BOT_ACTION_DESIRE_HIGH, Fu.Site.GetXUnitsTowardsLocation(bot, enemyHero:GetLocation(), castRange)
					else
						return BOT_ACTION_DESIRE_HIGH, enemyHero:GetLocation()
					end
				end
			end
		end
	end
	if Fu.IsPushing(bot) or Fu.IsDefending(bot) then
		local laneCreeps = bot:GetNearbyLaneCreeps(castRange + radius, true)
		if laneCreeps ~= nil and #laneCreeps >= 4 and abilityLevel >= 3 and mpRatio > 0.6 then
			return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(laneCreeps)
		end
	end
	if Fu.IsLaning(bot) then
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE)
		local laneCreeps = bot:GetNearbyLaneCreeps(castRange + radius, true)
		if
			nearbyEnemies ~= nil
			and #nearbyEnemies == 0
			and laneCreeps ~= nil
			and #laneCreeps >= 4
			and isAttacking
			and mpRatio > 0.5
			and abilityLevel >= 3
			and not Fu.IsThereNonSelfCoreNearby(1200)
		then
			return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(laneCreeps)
		end
		local aoe = bot:FindAoELocation(true, true, bot:GetLocation(), castRange + radius, radius, 0, 0)
		nearbyEnemies = Fu.GetEnemiesNearLoc(aoe.targetloc, radius)
		if nearbyEnemies ~= nil and #nearbyEnemies >= 2 and Fu.IsInLaningPhase() and abilityLevel >= 2 then
			if GetUnitToLocationDistance(bot, Fu.GetCenterOfUnits(nearbyEnemies)) > castRange then
				return BOT_ACTION_DESIRE_HIGH, Fu.Site.GetXUnitsTowardsLocation(bot, Fu.GetCenterOfUnits(nearbyEnemies), castRange)
			else
				return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(nearbyEnemies)
			end
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if Fu.IsRoshan(botTarget) and Fu.CanCastOnNonMagicImmune(botTarget) and Fu.IsInRange(bot, botTarget, 500) and isAttacking and abilityLevel >= 3 then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, 500) and isAttacking and abilityLevel >= 3 then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.ConsiderSoulRip()
	if not soulRipAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castRange = Fu.GetProperCastRange(false, bot, soulRipAbility:GetCastRange())
	local radius = soulRipAbility:GetSpecialValueInt("radius")
	local damage = soulRipAbility:GetSpecialValueInt("damage_per_unit")
	local nearbyEnemies = Fu.GetNearbyHeroes(bot, radius, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and not Fu.IsSuspiciousIllusion(enemyHero)
			and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
			and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
			and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
			and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
		then
			local enemiesInRadius = Fu.GetEnemiesNearLoc(bot:GetLocation(), radius)
			local enemyCreeps = bot:GetNearbyCreeps(radius, true)
			-- datafeed: damage_per_unit for each unit, up to max_units. It multiplied heroes by
			-- creeps (and kept growing damage across the loop), and then returned Undying himself, so
			-- the "kill" cast healed him. Aim it at the enemy, within cast range.
			local units = (enemiesInRadius ~= nil and #enemiesInRadius or 0) + (enemyCreeps ~= nil and #enemyCreeps or 0)
			local maxUnits = soulRipAbility:GetSpecialValueInt("max_units")
			if maxUnits ~= nil and maxUnits > 0 then
				units = math.min(units, maxUnits)
			end
			if Fu.IsInRange(bot, enemyHero, castRange) and Fu.CanKillTarget(enemyHero, damage * units, DAMAGE_TYPE_MAGICAL) then
				return BOT_ACTION_DESIRE_HIGH, enemyHero
			end
		end
	end
	-- Save heal (new): an ally other than Undying under hero attack below 40% HP. Before this the
	-- heal went to allies only while Undying was engaging, or with 4+ enemy creeps around, so a
	-- dove lane partner got nothing. datafeed: damage_per_unit per unit within radius (1300), up to
	-- max_units; note "Does rip from spell immune allies", so allied creeps are counted (that they
	-- add to the heal is not verified in a game). Logged: [OHA-UNDYING] save-rip.
	do
		local units = #(Fu.GetNearbyHeroes(bot, radius, true, BOT_MODE_NONE) or {})
			+ #(bot:GetNearbyCreeps(radius, true) or {})
			+ #(bot:GetNearbyCreeps(radius, false) or {})
		local maxUnits = soulRipAbility:GetSpecialValueInt("max_units")
		if maxUnits ~= nil and maxUnits > 0 then
			units = math.min(units, maxUnits)
		end
		local save, saveHP = nil, 0.4
		if units >= 2 then
			for _, allyHero in pairs(Fu.GetNearbyHeroes(bot, castRange, false, BOT_MODE_NONE) or {}) do
				if
					allyHero ~= bot
					and Fu.IsValidHero(allyHero)
					and not allyHero:IsIllusion()
					and not Fu.IsMeepoClone(allyHero)
					and Fu.GetHP(allyHero) < saveHP
					and allyHero:WasRecentlyDamagedByAnyHero(2)
				then
					save, saveHP = allyHero, Fu.GetHP(allyHero)
				end
			end
		end
		if save ~= nil then
			if DotaTime() >= (bot._undyingSaveLogAt or -999) then
				bot._undyingSaveLogAt = DotaTime() + 5
				pcall(print, string.format(
					"[OHA-UNDYING] t=%.0f save-rip ally=%s hp=%.2f units=%d heal=%d",
					DotaTime(),
					(string.gsub(save:GetUnitName(), "npc_dota_hero_", "")),
					saveHP,
					units,
					damage * units
				))
			end
			return BOT_ACTION_DESIRE_HIGH, save
		end
	end
	if Fu.IsGoingOnSomeone(bot, 1200) then
		local healTarget = nil
		local lowestHealth = math.huge -- was 1000 (absolute HP): no ally above 1000 HP was ever healed
		local nearbyAllies = Fu.GetNearbyHeroes(bot, castRange, false, BOT_MODE_NONE)
		for _, allyHero in pairs(nearbyAllies) do
			if Fu.IsValidHero(allyHero) and not Fu.IsSuspiciousIllusion(allyHero) then
				local enemiesInRadius = Fu.GetNearbyHeroes(bot, radius, true, BOT_MODE_NONE)
				local enemyCreeps = bot:GetNearbyCreeps(radius, true)
				local allyHealth = allyHero:GetHealth()
				if allyHealth < lowestHealth and Fu.GetHP(allyHero) < 0.75 and (enemiesInRadius ~= nil and #enemiesInRadius >= 1 or enemyCreeps ~= nil and #enemyCreeps >= 2) then
					lowestHealth = allyHealth
					healTarget = allyHero
				end
			end
		end
		if healTarget ~= nil then
			return BOT_ACTION_DESIRE_MODERATE, healTarget
		end
	end
	if Fu.IsRetreating(bot) then
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, radius, true, BOT_MODE_NONE)
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.IsChasingTarget(enemyHero, bot)
				and not Fu.IsSuspiciousIllusion(enemyHero)
			then
				local alliesNearChaser = Fu.GetNearbyHeroes(enemyHero, 1200, true, BOT_MODE_NONE)
				local enemiesNearChaser = Fu.GetNearbyHeroes(enemyHero, 1200, false, BOT_MODE_NONE)
				if alliesNearChaser ~= nil and enemiesNearChaser ~= nil and (#enemiesNearChaser > #alliesNearChaser or bot:WasRecentlyDamagedByAnyHero(1.5) or hpRatio < 0.5) then
					return BOT_ACTION_DESIRE_HIGH, bot
				end
			end
		end
		local enemyCreeps = bot:GetNearbyCreeps(radius, true)
		if enemyCreeps ~= nil and #enemyCreeps >= 4 and hpRatio < 0.6 then
			return BOT_ACTION_DESIRE_HIGH, bot
		end
	end
	if Fu.IsPushing(bot) then
		local laneCreeps = bot:GetNearbyLaneCreeps(radius, true)
		if laneCreeps ~= nil and #laneCreeps >= 4 and mpRatio > 0.7 and hpRatio < 0.6 then
			return BOT_ACTION_DESIRE_HIGH, bot
		end
	end
	if Fu.IsLaning(bot) then
		local laneCreeps = bot:GetNearbyLaneCreeps(radius, true)
		if laneCreeps ~= nil and #laneCreeps >= 3 and isAttacking and mpRatio > 0.5 and hpRatio < 0.6 then
			return BOT_ACTION_DESIRE_HIGH, bot
		end
	end
	if Fu.IsDoingRoshan(bot) or Fu.IsDoingTormentor(bot) then
		if (Fu.IsRoshan(botTarget) or Fu.IsTormentor(botTarget)) and Fu.IsInRange(bot, botTarget, radius) and isAttacking then
			local healTarget = nil
			local lowestHealth = math.huge -- was 1000 (absolute HP): no ally above 1000 HP was ever healed
			local nearbyAllies = Fu.GetNearbyHeroes(bot, castRange, false, BOT_MODE_NONE)
			for _, allyHero in pairs(nearbyAllies) do
				if Fu.IsValidHero(allyHero) and not Fu.IsSuspiciousIllusion(allyHero) then
					local allyHealth = allyHero:GetHealth()
					if allyHealth < lowestHealth and Fu.GetHP(allyHero) < 0.75 then
						lowestHealth = allyHealth
						healTarget = allyHero
					end
				end
			end
			if healTarget ~= nil then
				return BOT_ACTION_DESIRE_MODERATE, healTarget
			end
		end
	end
	local healTarget = nil
	local lowestHealth = math.huge -- was 1000 (absolute HP): no ally above 1000 HP was ever healed
	local nearbyAllies = Fu.GetNearbyHeroes(bot, castRange, false, BOT_MODE_NONE)
	for _, allyHero in pairs(nearbyAllies) do
		if Fu.IsValidHero(allyHero) and not Fu.IsSuspiciousIllusion(allyHero) then
			local enemyCreeps = bot:GetNearbyCreeps(radius, true)
			local allyHealth = allyHero:GetHealth()
			if allyHealth < lowestHealth and Fu.GetHP(allyHero) < 0.75 and mpRatio > 0.35 and enemyCreeps ~= nil and #enemyCreeps >= 4 then
				lowestHealth = allyHealth
				healTarget = allyHero
			end
		end
	end
	if healTarget ~= nil then
		return BOT_ACTION_DESIRE_MODERATE, healTarget
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function X.ConsiderTombstone()
	if not tombstoneAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local castRange = Fu.GetProperCastRange(false, bot, tombstoneAbility:GetCastRange())
	local radius = tombstoneAbility:GetSpecialValueInt("radius")
	if isInTeamFight then
		local aoe = bot:FindAoELocation(true, true, bot:GetLocation(), castRange, radius, 0, 0)
		local enemiesInRadius = Fu.GetEnemiesNearLoc(aoe.targetloc, radius / 2)
		if enemiesInRadius ~= nil and #enemiesInRadius >= 2 then
			local enemyCenter = Fu.GetCenterOfUnits(enemiesInRadius)
			if Fu.IsLocationInChrono(enemyCenter) or Fu.IsLocationInBlackHole(enemyCenter) or Fu.IsLocationInArena(enemyCenter, radius / 2) then
				return BOT_ACTION_DESIRE_HIGH, bot:GetLocation()
			end
			-- datafeed: zombies spawn by every enemy within radius (1200) of the Tombstone, cast range
			-- 500. Aiming at the enemies' centre made Undying walk into them to plant it; plant it
			-- toward them, no farther than the cast range, so it stays out of their reach.
			local castRange = tombstoneAbility:GetCastRange()
			local dist = GetUnitToLocationDistance(bot, enemyCenter)
			if dist > castRange then
				return BOT_ACTION_DESIRE_HIGH, Fu.Site.GetXUnitsTowardsLocation(bot, enemyCenter, castRange)
			end
			return BOT_ACTION_DESIRE_HIGH, enemyCenter
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.ConsiderFleshGolem()
	if not fleshGolemAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
	end
	if isInTeamFight then
		local nearbyEnemies = Fu.GetEnemiesNearLoc(bot:GetLocation(), 1200)
		if nearbyEnemies ~= nil and #nearbyEnemies >= 2 then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
return X
