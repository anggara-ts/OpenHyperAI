-- Mars: skill build, item build, and ability use for this hero.
-- Accidental globals made file-local (#13): every bot shares one Lua state, so these were shared.
local BlinkLocation
local X = {}
local bot = GetBot()
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local AbilityContext = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local Minion = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local sTalentList = Fu.Skill.GetTalentList(bot)
local sAbilityList = Fu.Skill.GetAbilityList(bot)
local sRole = Fu.Item.GetRoleItemsBuyList(bot)
local tTalentTreeList = { ["t25"] = { 0, 10 }, ["t20"] = { 10, 0 }, ["t15"] = { 0, 10 }, ["t10"] = { 0, 10 } }
local tAllAbilityBuildList = { { 2, 1, 1, 2, 1, 6, 1, 2, 2, 3, 6, 3, 3, 3, 6 } }
local nAbilityBuildList = Fu.Skill.GetRandomBuild(tAllAbilityBuildList)
local nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList)
local teamAuraItem = "item_team_aura"
local sRoleItemsBuyList = {}
-- Stratz 7.41f, week of 9 Nov 2026: pos 3, 77,309 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_3"] = {
	"item_tango",
	"item_double_gauntlets",
	"item_double_branches",
	"item_quelling_blade",
	"item_bracer",
	"item_magic_wand",
	"item_soul_ring",
	"item_phase_boots",
	"item_blink",
	"item_desolator",
	"item_aghanims_shard",
	"item_black_king_bar",
	teamAuraItem,
	"item_ultimate_scepter",
	"item_overwhelming_blink",
	"item_ultimate_scepter_2",
	"item_assault",
	"item_moon_shard",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 1 has 434 matches, built from pos 3 (77,309) (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_1"] = sRoleItemsBuyList["pos_3"]
-- Stratz 7.41f, week of 9 Nov 2026: pos 2, 3,350 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_2"] = {
	"item_tango",
	"item_double_branches",
	"item_quelling_blade",
	"item_gauntlets",
	"item_faerie_fire",
	"item_bracer",
	"item_magic_wand",
	"item_soul_ring",
	"item_phase_boots",
	"item_blink",
	"item_desolator",
	"item_aghanims_shard",
	"item_black_king_bar",
	"item_ultimate_scepter",
	"item_refresher",
	"item_overwhelming_blink",
	"item_ultimate_scepter_2",
	"item_satanic",
	"item_moon_shard",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 4, 2,346 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_4"] = {
	"item_tango",
	"item_blood_grenade",
	"item_branches",
	"item_gauntlets",
	"item_magic_stick",
	"item_bracer",
	"item_magic_wand",
	"item_soul_ring",
	"item_phase_boots",
	"item_blink",
	"item_aghanims_shard",
	"item_cyclone",
	"item_black_king_bar",
	teamAuraItem,
	"item_refresher",
	"item_overwhelming_blink",
	"item_wind_waker",
	"item_moon_shard",
	"item_ultimate_scepter_2",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 5, 1,013 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_5"] = {
	"item_tango",
	"item_blood_grenade",
	"item_branches",
	"item_magic_stick",
	"item_gauntlets",
	"item_bracer",
	"item_magic_wand",
	"item_soul_ring",
	"item_phase_boots",
	"item_blink",
	"item_aghanims_shard",
	"item_cyclone",
	"item_black_king_bar",
	teamAuraItem,
	"item_refresher",
	"item_wind_waker",
	"item_moon_shard",
	"item_ultimate_scepter_2",
}
X["sBuyList"] = sRoleItemsBuyList[sRole]
X["sSellList"] = { "item_black_king_bar", "item_quelling_blade" }
if Fu.Role.IsPvNMode() or Fu.Role.IsAllShadow() then
	X["sBuyList"], X["sSellList"] = { "PvN_mid" }, {}
end
nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"] =
	Fu.SetUserHeroInit(nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"])
X["sSkillList"] = Fu.Skill.GetSkillList(sAbilityList, nAbilityBuildList, sTalentList, nTalentBuildList)
X["bDeafaultAbility"] = false
-- Cast when cornered (retreating into 3+ enemies with no way out), before running further.
X["LastStandSpells"] = { { name = "mars_arena_of_blood", kind = "point" } }
X["bDeafaultItem"] = false
function X.MinionThink(minionUnit)
	Minion.MinionThink(minionUnit)
end
local spearAbility = SafeAbility(bot:GetAbilityByName("mars_spear"), "mars_spear", "mars")
local godsRebukeAbility = SafeAbility(bot:GetAbilityByName("mars_gods_rebuke"), "mars_gods_rebuke", "mars")
local bulwarkAbility = SafeAbility(bot:GetAbilityByName("mars_bulwark"), "mars_bulwark", "mars")
local arenaOfBloodAbility = SafeAbility(bot:GetAbilityByName("mars_arena_of_blood"), "mars_arena_of_blood", "mars")
local spearDesire, spearLocation
local godsRebukeDesire, godsRebukeLocation
local bulwarkDesire
local arenaDesire, arenaLocation
local spearToAllyDesire, spearToAllyLocation
local lastArenaTime = 0
local nearbyAllies, nearbyEnemies
local botTarget
local isGoingOnSomeone
local isRetreating
local isAttacking
local mpRatio
local unused
function X.SkillsComplement()
	if Fu.CanNotUseAbility(bot) then
		return
	end
	isGoingOnSomeone = Fu.IsGoingOnSomeone(bot)
	isRetreating = Fu.IsRetreating(bot)
	isAttacking = Fu.IsAttacking(bot)
	mpRatio = Fu.GetMP(bot)
	spearAbility = SafeAbility(bot:GetAbilityByName("mars_spear"), "mars_spear", "mars")
	godsRebukeAbility = SafeAbility(bot:GetAbilityByName("mars_gods_rebuke"), "mars_gods_rebuke", "mars")
	bulwarkAbility = SafeAbility(bot:GetAbilityByName("mars_bulwark"), "mars_bulwark", "mars")
	arenaOfBloodAbility = SafeAbility(bot:GetAbilityByName("mars_arena_of_blood"), "mars_arena_of_blood", "mars")
	botTarget = Fu.GetProperTarget(bot)
	nearbyAllies = bot:GetNearbyHeroes(1600, false, BOT_MODE_NONE)
	nearbyEnemies = bot:GetNearbyHeroes(1600, true, BOT_MODE_NONE)
	spearToAllyDesire, spearToAllyLocation, BlinkLocation = X.ConsiderSpearToAlly()
	if spearToAllyDesire > 0 then
		bot:Action_ClearActions(false)
		bot:ActionQueue_UseAbilityOnLocation(bot.Blink, BlinkLocation)
		bot:ActionQueue_Delay(0.1)
		bot:ActionQueue_UseAbilityOnLocation(spearAbility, spearToAllyLocation)
		return
	end
	arenaDesire, arenaLocation = X.ConsiderArenaOfBlood()
	if arenaDesire > 0 then
		bot:Action_UseAbilityOnLocation(arenaOfBloodAbility, arenaLocation)
		lastArenaTime = DotaTime()
		return
	end
	godsRebukeDesire, godsRebukeLocation = X.ConsiderGodsRebuke()
	if godsRebukeDesire > 0 then
		bot:Action_UseAbilityOnLocation(godsRebukeAbility, godsRebukeLocation)
		return
	end
	spearDesire, spearLocation = X.ConsiderSpearOfMars()
	if spearDesire > 0 then
		bot:Action_UseAbilityOnLocation(spearAbility, spearLocation)
		return
	end
	bulwarkDesire = X.ConsiderBulwark()
	if bulwarkDesire > 0 then
		bot:Action_UseAbility(bulwarkAbility)
		return
	end
end
function X.ConsiderSpearOfMars()
	if not Fu.CanCastAbility(spearAbility) then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	-- Was GetProperCastRange(spear_range), which adds 200: targets 200 past where the spear stops
	-- passed the range checks and the spear flew short. spear_range is the flight distance.
	local spearRange = spearAbility:GetSpecialValueInt("spear_range")
	local castPoint = spearAbility:GetCastPoint()
	local spearWidth = spearAbility:GetSpecialValueInt("spear_width")
	local spearSpeed = spearAbility:GetSpecialValueInt("spear_speed")
	local damage = spearAbility:GetSpecialValueInt("damage")
	local manaAfter = Fu.GetManaAfter(spearAbility:GetManaCost())
	local abilityLevel = spearAbility:GetLevel()
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.IsInRange(bot, enemyHero, spearRange)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
		then
			if enemyHero:IsChanneling() then
				return BOT_ACTION_DESIRE_HIGH, enemyHero:GetLocation()
			end
			if
				Fu.CanKillTarget(enemyHero, damage, DAMAGE_TYPE_MAGICAL)
				and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
				and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
				and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
				and not enemyHero:HasModifier("modifier_oracle_false_promise")
				and not enemyHero:HasModifier("modifier_templar_assassin_refraction_absorb")
				and not enemyHero:HasModifier("modifier_troll_warlord_battle_trance")
			then
				local delay = GetUnitToUnitDistance(bot, enemyHero) / spearSpeed + castPoint
				return BOT_ACTION_DESIRE_HIGH, Fu.GetCorrectLoc(enemyHero, delay)
			end
		end
	end
	if isGoingOnSomeone then
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, spearRange)
			and not Fu.IsDisabled(botTarget)
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			local spearTargetLocation = X.GetSpearToLocation(spearRange, spearWidth, castPoint, spearSpeed, botTarget)
			if Fu.IsInLaningPhase() then
				local attackingAllies = Fu.GetSpecialModeAllies(bot, 1200, BOT_MODE_ATTACK)
				if X.GetTotalEstimatedDamageToTarget(attackingAllies, botTarget, 5.0) > botTarget:GetHealth() * 1.2 then
					if spearTargetLocation then
						return BOT_ACTION_DESIRE_HIGH, spearTargetLocation
					end
				end
			else
				if spearTargetLocation then
					return BOT_ACTION_DESIRE_HIGH, spearTargetLocation
				end
			end
		end
	end
	if isRetreating and not Fu.IsRealInvisible(bot) and bot:WasRecentlyDamagedByAnyHero(3.0) then
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.IsChasingTarget(enemyHero, bot)
				and Fu.IsInRange(bot, enemyHero, spearRange - 150)
				and not Fu.IsDisabled(enemyHero)
				and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
			then
				return BOT_ACTION_DESIRE_HIGH, enemyHero:GetLocation()
			end
		end
	end
	local laneCreeps = bot:GetNearbyLaneCreeps(spearRange, true)
	if
		(Fu.IsPushing(bot) and not Fu.IsLateGame() or Fu.IsDefending(bot))
		and #nearbyAllies <= 2
		and abilityLevel >= 3
		and manaAfter > 0.5
		and Fu.CanBeAttacked(laneCreeps[1])
		and not Fu.IsRunning(laneCreeps[1])
	then
		local aoe = bot:FindAoELocation(true, false, laneCreeps[1]:GetLocation(), 0, spearWidth, castPoint, 0)
		if #laneCreeps >= 4 and aoe.count >= 4 then
			return BOT_ACTION_DESIRE_HIGH, aoe.targetloc
		end
	end
	if Fu.IsLaning(bot) and bot:GetLevel() < 6 then
		for _, creep in pairs(laneCreeps) do
			if
				Fu.IsValid(creep)
				and Fu.CanBeAttacked(creep)
				and (Fu.IsKeyWordUnit("ranged", creep) or Fu.IsKeyWordUnit("siege", creep) or Fu.IsKeyWordUnit(
					"flagbearer",
					creep
				))
				and Fu.CanKillTarget(creep, damage, DAMAGE_TYPE_MAGICAL)
				and not Fu.IsRunning(creep)
			then
				if
					Fu.IsValidHero(nearbyEnemies[1])
					and GetUnitToUnitDistance(nearbyEnemies[1], creep) < 500
					and mpRatio > 0.75
				then
					return BOT_ACTION_DESIRE_HIGH, creep:GetLocation()
				end
			end
		end
	end
	if Fu.IsFarming(bot) and manaAfter > 0.35 and not Fu.IsLateGame() then
		local creeps = bot:GetNearbyCreeps(spearRange, true)
		if Fu.IsValid(creeps[1]) and Fu.CanBeAttacked(creeps[1]) and not Fu.IsRunning(creeps[1]) then
			local aoe = bot:FindAoELocation(true, false, creeps[1]:GetLocation(), 0, spearWidth, castPoint, 0)
			if #creeps >= 4 and aoe.count >= 4 or #creeps >= 2 and aoe.count >= 2 and creeps[1]:IsAncientCreep() then
				return BOT_ACTION_DESIRE_HIGH, aoe.targetloc
			end
		end
	end
	for _, allyHero in pairs(nearbyAllies) do
		if
			Fu.IsValidHero(allyHero)
			and Fu.IsRetreating(allyHero)
			and bot ~= allyHero
			and allyHero:WasRecentlyDamagedByAnyHero(3)
			and not allyHero:IsIllusion()
			and mpRatio > 0.5
		then
			local enemiesNearAlly = Fu.GetEnemiesNearLoc(allyHero:GetLocation(), 1600)
			if
				Fu.IsValidHero(enemiesNearAlly[1])
				and Fu.CanCastOnNonMagicImmune(enemiesNearAlly[1])
				and Fu.IsChasingTarget(enemiesNearAlly[1], allyHero)
				and Fu.IsInRange(bot, enemiesNearAlly[1], spearRange)
				and not Fu.IsDisabled(enemiesNearAlly[1])
				and not enemiesNearAlly[1]:HasModifier("modifier_necrolyte_reapers_scythe")
			then
				local toAllyDirection = (allyHero:GetLocation() - bot:GetLocation()):Normalized()
				local toEnemyDirection = (enemiesNearAlly[1]:GetLocation() - bot:GetLocation()):Normalized()
				if Fu.DotProduct(toAllyDirection, toEnemyDirection) < 0 then
					local delay = GetUnitToUnitDistance(bot, enemiesNearAlly[1]) / spearSpeed + castPoint
					return BOT_ACTION_DESIRE_HIGH, enemiesNearAlly[1]:GetExtrapolatedLocation(delay)
				end
			end
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if
			Fu.IsRoshan(botTarget)
			and Fu.CanBeAttacked(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, spearRange)
			and isAttacking
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, spearRange) and isAttacking then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function X.ConsiderGodsRebuke()
	if not Fu.CanCastAbility(godsRebukeAbility) then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local radius = godsRebukeAbility:GetSpecialValueInt("radius")
	local critDamage = bot:GetAttackDamage() * godsRebukeAbility:GetSpecialValueInt("crit_mult") / 100
	local abilityLevel = godsRebukeAbility:GetLevel()
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanBeAttacked(enemyHero)
			and Fu.IsInRange(bot, enemyHero, radius)
			and Fu.CanKillTarget(enemyHero, critDamage, DAMAGE_TYPE_PHYSICAL)
			and not Fu.IsSuspiciousIllusion(enemyHero)
			and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
			and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
			and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
			and not enemyHero:HasModifier("modifier_oracle_false_promise")
			and not enemyHero:HasModifier("modifier_templar_assassin_refraction_absorb")
		then
			return BOT_ACTION_DESIRE_HIGH, enemyHero:GetLocation()
		end
	end
	if isGoingOnSomeone then
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanBeAttacked(botTarget)
			and Fu.IsInRange(bot, botTarget, radius - 75)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not botTarget:HasModifier("modifier_abaddon_aphotic_shield")
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
			and not botTarget:HasModifier("modifier_templar_assassin_refraction_absorb")
		then
			local aoe = bot:FindAoELocation(true, true, botTarget:GetLocation(), 0, radius, 0, 0)
			if aoe.count >= 1 then
				return BOT_ACTION_DESIRE_HIGH, aoe.targetloc
			end
		end
	end
	if isRetreating and not Fu.IsRealInvisible(bot) then
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.CanBeAttacked(enemyHero)
				and Fu.IsInRange(bot, enemyHero, radius)
				and Fu.IsChasingTarget(enemyHero, bot)
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and not Fu.IsDisabled(enemyHero)
				and not Fu.CanCastAbility(spearAbility)
				and bot:WasRecentlyDamagedByHero(enemyHero, 3.0)
			then
				return BOT_ACTION_DESIRE_HIGH, enemyHero:GetLocation()
			end
		end
	end
	local creeps = bot:GetNearbyCreeps(radius + 150, true)
	if (Fu.IsPushing(bot) or Fu.IsDefending(bot)) and abilityLevel >= 3 and mpRatio > 0.5 and isAttacking then
		if creeps ~= nil and #creeps >= 4 then
			return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(creeps)
		end
	end
	if Fu.IsFarming(bot) and abilityLevel >= 3 and mpRatio > 0.5 and isAttacking then
		if Fu.CanBeAttacked(creeps[1]) and (#creeps >= 3 or #creeps >= 2 and creeps[1]:IsAncientCreep()) then
			return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(creeps)
		end
	end
	if Fu.IsLaning(bot) and mpRatio > 0.33 then
		local laneCreeps = bot:GetNearbyLaneCreeps(radius, true)
		local totalHealth = 0
		local hittableCreeps = {}
		if laneCreeps ~= nil and #laneCreeps >= 2 then
			for _, creep in pairs(laneCreeps) do
				if Fu.IsValid(creep) and Fu.CanBeAttacked(creep) then
					totalHealth = totalHealth + creep:GetHealth()
					table.insert(hittableCreeps, creep)
					local enemiesNear = Fu.GetEnemiesNearLoc(bot:GetLocation(), radius)
					if
						enemiesNear ~= nil
						and #enemiesNear >= 1
						and Fu.CanKillTarget(creep, critDamage, DAMAGE_TYPE_PHYSICAL)
					then
						return BOT_ACTION_DESIRE_HIGH, enemiesNear[1]:GetLocation()
					end
				end
			end
			if #hittableCreeps >= 1 and totalHealth / #hittableCreeps <= critDamage then
				return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(hittableCreeps)
			end
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if
			Fu.IsRoshan(botTarget)
			and Fu.CanBeAttacked(botTarget)
			and Fu.IsInRange(bot, botTarget, radius)
			and isAttacking
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, radius) and isAttacking then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function X.ConsiderBulwark()
	if not Fu.CanCastAbility(bulwarkAbility) then
		return BOT_ACTION_DESIRE_NONE
	end
	local soldierOffset = bulwarkAbility:GetSpecialValueInt("soldier_offset")
	if isRetreating and not Fu.IsRealInvisible(bot) then
		local alliesNearby = bot:GetNearbyHeroes(800, false, BOT_MODE_NONE)
		if #alliesNearby >= 1 then
			local facingCount = 0
			local enemies = bot:GetNearbyHeroes(1600, true, BOT_MODE_NONE)
			for _, enemyHero in pairs(enemies) do
				if
					Fu.IsValidHero(enemyHero)
					and Fu.CanCastOnMagicImmune(enemyHero)
					and bot:IsFacingLocation(enemyHero:GetLocation(), 15)
					and not Fu.IsSuspiciousIllusion(enemyHero)
					and not Fu.IsDisabled(enemyHero)
				then
					facingCount = facingCount + 1
				end
			end
			if facingCount >= 1 and enemies ~= nil and #enemies > #alliesNearby then
				if bulwarkAbility:GetToggleState() == false then
					return BOT_ACTION_DESIRE_HIGH
				end
				return BOT_ACTION_DESIRE_NONE
			end
		end
	end
	if isGoingOnSomeone and Fu.IsInRange(bot, botTarget, soldierOffset) then
		if bot:HasScepter() then
			if bulwarkAbility:GetToggleState() == false then
				return BOT_ACTION_DESIRE_HIGH
			end
			return BOT_ACTION_DESIRE_NONE
		end
	end
	if bulwarkAbility:GetToggleState() == true then
		return BOT_ACTION_DESIRE_HIGH
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderArenaOfBlood()
	if not Fu.CanCastAbility(arenaOfBloodAbility) then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castRange = Fu.GetProperCastRange(false, bot, arenaOfBloodAbility:GetCastRange())
	local castPoint = arenaOfBloodAbility:GetCastPoint()
	local radius = arenaOfBloodAbility:GetSpecialValueInt("radius")
	local duration = arenaOfBloodAbility:GetSpecialValueInt("duration")
	if Fu.IsInTeamFight(bot, 1300) then
		local aoe = bot:FindAoELocation(true, true, bot:GetLocation(), castRange, radius, castPoint, 0)
		local enemiesInArena = Fu.GetEnemiesNearLoc(aoe.targetloc, radius)
		if
			enemiesInArena ~= nil
			and #enemiesInArena >= 2
			and not Fu.IsLocationInChrono(aoe.targetloc)
			and not Fu.IsLocationInBlackHole(aoe.targetloc)
			and not Fu.IsLocationInArena(aoe.targetloc, radius)
		then
			return BOT_ACTION_DESIRE_HIGH, aoe.targetloc
		end
	end
	if isGoingOnSomeone then
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange + radius)
			and Fu.IsCore(botTarget)
			and (isAttacking or Fu.IsChasingTarget(bot, botTarget))
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not Fu.IsLocationInChrono(botTarget:GetLocation())
			and not Fu.IsLocationInBlackHole(botTarget:GetLocation())
			and not Fu.IsLocationInArena(botTarget:GetLocation(), radius)
		then
			local allies = bot:GetNearbyHeroes(1200, false, BOT_MODE_NONE)
			local enemies = bot:GetNearbyHeroes(1200, true, BOT_MODE_NONE)
			if
				allies ~= nil
				and enemies ~= nil
				and #allies >= #enemies
				and #allies < #enemies + 2
				and bot:GetEstimatedDamageToTarget(true, botTarget, duration, DAMAGE_TYPE_ALL)
					>= botTarget:GetHealth()
			then
				return BOT_ACTION_DESIRE_HIGH, Fu.Site.GetXUnitsTowardsLocation(bot, botTarget:GetLocation(), castRange)
			end
		end
	end
	if isRetreating then
		local allies = bot:GetNearbyHeroes(1200, false, BOT_MODE_NONE)
		local enemies = bot:GetNearbyHeroes(1200, true, BOT_MODE_NONE)
		for _, enemyHero in pairs(enemies) do
			if
				allies ~= nil
				and enemies ~= nil
				and Fu.IsValidHero(enemyHero)
				and Fu.IsChasingTarget(enemyHero, bot)
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and not Fu.IsDisabled(enemyHero)
				and not enemies[1]:HasModifier("modifier_legion_commander_duel")
				and not enemies[1]:HasModifier("modifier_necrolyte_reapers_scythe")
			then
				local chaserAllies = enemies[1]:GetNearbyHeroes(1200, false, BOT_MODE_NONE)
				if chaserAllies ~= nil and #chaserAllies > #allies + 2 and #allies <= 1 then
					local aoe = bot:FindAoELocation(true, true, bot:GetLocation(), castRange, radius, castPoint, 0)
					local enemiesInArena = Fu.GetEnemiesNearLoc(aoe.targetloc, radius)
					if
						enemiesInArena ~= nil
						and #enemiesInArena >= 1
						and not Fu.IsLocationInChrono(aoe.targetloc)
						and not Fu.IsLocationInBlackHole(aoe.targetloc)
						and not Fu.IsLocationInArena(aoe.targetloc, radius)
					then
						return BOT_ACTION_DESIRE_HIGH, aoe.targetloc
					end
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function X.ConsiderSpearToAlly()
	if X.CanSpearToAlly() then
		-- Was spearAbility:GetCastRange(): Spear has no AbilityCastRange in the game data (its reach is the
		-- special value "spear_range", 900-1200), so the ally search radius could read 0.
		local spearRange = spearAbility:GetSpecialValueInt("spear_range")
		local castPoint = spearAbility:GetCastPoint()
		local spearSpeed = spearAbility:GetSpecialValueInt("spear_speed")
		if isGoingOnSomeone then
			if
				Fu.IsValidTarget(botTarget)
				and Fu.CanCastOnNonMagicImmune(botTarget)
				and Fu.IsInRange(bot, botTarget, 1199)
				and not Fu.IsInRange(bot, botTarget, 500)
				and not Fu.IsDisabled(botTarget)
				and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
			then
				local alliesNearTarget = Fu.GetAlliesNearLoc(botTarget:GetLocation(), spearRange)
				local enemiesNearTarget = Fu.GetEnemiesNearLoc(botTarget:GetLocation(), spearRange)
				local furthestAlly = X.GetFurthestAllyFromBot(alliesNearTarget)
				if #alliesNearTarget >= #enemiesNearTarget and #alliesNearTarget >= 2 and furthestAlly ~= nil then
					-- Was: blink onto the ally and throw at the target, which skewers the target AWAY
					-- from the ally (the spear pushes along its flight). Blink to the far side of the
					-- target instead and throw toward the ally, so the target is carried into the team.
					-- Lead was dist / speed / cast point (divided by 0.25); blink is instant, so the
					-- lead is just the cast point plus the short spear flight.
					local tLoc = Fu.GetCorrectLoc(botTarget, castPoint + 0.1)
					local dir = (tLoc - furthestAlly:GetLocation()):Normalized()
					local blinkLoc = tLoc + dir * 150
					if GetUnitToLocationDistance(bot, blinkLoc) <= 1150 and IsLocationPassable(blinkLoc) then
						if DotaTime() >= (bot._spearAllyLogAt or -999) then
							bot._spearAllyLogAt = DotaTime() + 5
							pcall(
								print,
								string.format(
									"[OHA-MARS] t=%.0f blink-spear target=%s toward=%s",
									DotaTime(),
									(string.gsub(botTarget:GetUnitName(), "npc_dota_hero_", "")),
									(string.gsub(furthestAlly:GetUnitName(), "npc_dota_hero_", ""))
								)
							)
						end
						return BOT_ACTION_DESIRE_HIGH, furthestAlly:GetLocation(), blinkLoc
					end
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.CanSpearToAlly()
	if Fu.CanCastAbility(spearAbility) and Fu.CanBlinkDagger(bot) then
		local manaCost = spearAbility:GetManaCost()
		if bot:GetMana() >= manaCost then
			return true
		end
	end
	return false
end
function X.GetFurthestAllyFromBot(allies)
	local furthestAlly = nil
	local maxDistance = 0
	for _, allyHero in pairs(allies) do
		if Fu.IsValidHero(allyHero) and bot ~= allyHero then
			local distance = GetUnitToUnitDistance(bot, allyHero)
			if distance > maxDistance then
				furthestAlly = allyHero
				maxDistance = distance
			end
		end
	end
	return furthestAlly
end
function X.GetSpearToLocation(range, width, castPoint, speed, target)
	local botLocation = bot:GetLocation()
	local targetLocation = Fu.GetCorrectLoc(target, GetUnitToUnitDistance(bot, target) / speed + castPoint)
	-- Was range * 0.6 (range = spear_range + 200): a tree or building behind the target only counted when
	-- it was within ~650 of Mars, so a target past ~600 was never pinned. The skewered hero rides
	-- the spear to the end of spear_range (Valve data), so anything up to spear_range pins.
	local reach = math.min(spearAbility:GetSpecialValueInt("spear_range"), 1600)
	local trees = bot:GetNearbyTrees(reach)
	if DotaTime() < lastArenaTime + 7 then
		return targetLocation
	end
	for _, tree in pairs(trees) do
		if tree then
			local treeLocation = GetTreeLocation(tree)
			local pointLine = PointToLineDistance(botLocation, treeLocation, targetLocation)
			if
				pointLine ~= nil
				and pointLine.within
				and pointLine.distance <= width
				and Fu.GetDistance(targetLocation, treeLocation) < GetUnitToLocationDistance(bot, treeLocation)
			then
				return treeLocation
			end
		end
	end
	for _, unit in pairs(GetUnitList(UNIT_LIST_ALL)) do
		if Fu.IsValidBuilding(unit) and Fu.IsInRange(bot, unit, reach) then
			local buildingLocation = unit:GetLocation()
			local pointLine = PointToLineDistance(botLocation, buildingLocation, targetLocation)
			if
				pointLine ~= nil
				and pointLine.within
				and pointLine.distance <= width
				and Fu.GetDistance(targetLocation, buildingLocation)
					< GetUnitToLocationDistance(bot, buildingLocation)
			then
				return buildingLocation
			end
		end
	end
	return X.GetAllySpearLocation(range, width, castPoint, speed, target)
end
function X.GetAllySpearLocation(range, width, castPoint, speed, target)
	local allies = Fu.GetAlliesNearLoc(bot:GetLocation(), range)
	local targetLocation = Fu.GetCorrectLoc(target, GetUnitToUnitDistance(bot, target) / speed + castPoint)
	for _, allyHero in pairs(allies) do
		if
			Fu.IsValidHero(allyHero)
			and bot ~= allyHero
			and not Fu.IsRetreating(allyHero)
			and bot:DistanceFromFountain() > allyHero:DistanceFromFountain()
		then
			local allyAllies = allyHero:GetNearbyHeroes(1200, false, BOT_MODE_NONE)
			local allyEnemies = allyHero:GetNearbyHeroes(1200, true, BOT_MODE_NONE)
			local pointLine = PointToLineDistance(bot:GetLocation(), allyHero:GetLocation(), targetLocation)
			if
				#allyAllies >= #allyEnemies
				and (pointLine ~= nil and pointLine.within and pointLine.distance <= width)
				and GetUnitToUnitDistance(target, allyHero) < GetUnitToUnitDistance(bot, allyHero)
			then
				return allyHero:GetLocation()
			end
		end
	end
	return nil
end
function X.GetTotalEstimatedDamageToTarget(units, target, duration)
	local totalDamage = 0
	for _, unit in pairs(units) do
		local isOnBotTeam = true
		if unit:GetTeam() ~= GetBot():GetTeam() then
			isOnBotTeam = false
		end
		totalDamage = totalDamage + unit:GetEstimatedDamageToTarget(isOnBotTeam, target, duration, DAMAGE_TYPE_ALL)
	end
	return totalDamage
end
return X
