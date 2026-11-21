-- Ember Spirit: skill build, item build, and ability use for this hero.
local X = {}
local bot = GetBot()
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local AbilityContext = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local Minion = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local sTalentList = Fu.Skill.GetTalentList(bot)
local sAbilityList = Fu.Skill.GetAbilityList(bot)
local sRole = Fu.Item.GetRoleItemsBuyList(bot)
local nBuildIndex = RandomInt(1, 2)
local tTalentTreeList = {
	{ ["t25"] = { 0, 10 }, ["t20"] = { 10, 0 }, ["t15"] = { 0, 10 }, ["t10"] = { 10, 0 } },
	{ ["t25"] = { 0, 10 }, ["t20"] = { 10, 0 }, ["t15"] = { 0, 10 }, ["t10"] = { 0, 10 } },
}
-- Flame Guard first, then Searing Chains, Sleight of Fist last (Dotabuff most picked order).
local tAllAbilityBuildList =
	{ { 3, 2, 3, 1, 3, 6, 3, 1, 1, 1, 6, 2, 2, 2, 6 }, { 3, 2, 3, 1, 3, 6, 3, 1, 1, 1, 6, 2, 2, 2, 6 } }
local nAbilityBuildList = tAllAbilityBuildList[nBuildIndex]
local nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList[nBuildIndex])
-- One list per position (maintainer, 2026-11-20: the data's list, not one of two picked at random; items by
-- enemy lineup may come later). The skill build still picks one of two talent trees (nBuildIndex).
local sRoleItemsBuyList = {}
-- Stratz 7.41f, week of 9 Nov 2026: pos 1, 2,899 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_1"] = {
	"item_tango",
	"item_double_branches",
	"item_quelling_blade",
	"item_faerie_fire",
	"item_magic_stick",
	"item_magic_wand",
	"item_phase_boots",
	"item_bfury",
	"item_black_king_bar",
	"item_greater_crit",
	"item_ultimate_scepter",
	"item_aghanims_shard",
	"item_ultimate_scepter_2",
	"item_spirit_vessel",
	"item_radiance",
	"item_moon_shard",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 2, 112,181 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_2"] = {
	"item_tango",
	"item_double_branches",
	"item_faerie_fire",
	"item_quelling_blade",
	"item_magic_wand",
	"item_urn_of_shadows",
	"item_phase_boots",
	"item_spirit_vessel",
	"item_kaya",
	"item_aghanims_shard",
	"item_ultimate_scepter",
	"item_black_king_bar",
	"item_kaya_and_sange",
	"item_shivas_guard",
	"item_ultimate_scepter_2",
	"item_octarine_core",
	"item_moon_shard",
}
X["sBuyList"] = sRoleItemsBuyList[sRole]
X["sSellList"] = {
	"item_black_king_bar",
	"item_quelling_blade",
	"item_shivas_guard",
	"item_wraith_band",
	"item_ultimate_scepter",
	"item_magic_wand",
	"item_octarine_core",
	"item_bottle",
}
if Fu.Role.IsPvNMode() or Fu.Role.IsAllShadow() then
	X["sBuyList"], X["sSellList"] = { "PvN_mid" }, {}
end
nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"] =
	Fu.SetUserHeroInit(nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"])
X["sSkillList"] = Fu.Skill.GetSkillList(sAbilityList, nAbilityBuildList, sTalentList, nTalentBuildList)
X["bDeafaultAbility"] = false
X["bDeafaultItem"] = false
function X.MinionThink(minionUnit)
	if Minion.IsValidUnit(minionUnit) then
		Minion.IllusionThink(minionUnit)
	end
end
local searingChainsAbility =
	SafeAbility(bot:GetAbilityByName("ember_spirit_searing_chains"), "ember_spirit_searing_chains", "ember_spirit")
local sleightOfFistAbility =
	SafeAbility(bot:GetAbilityByName("ember_spirit_sleight_of_fist"), "ember_spirit_sleight_of_fist", "ember_spirit")
local flameGuardAbility =
	SafeAbility(bot:GetAbilityByName("ember_spirit_flame_guard"), "ember_spirit_flame_guard", "ember_spirit")
local activateFireRemnantAbility = SafeAbility(
	bot:GetAbilityByName("ember_spirit_activate_fire_remnant"),
	"ember_spirit_activate_fire_remnant",
	"ember_spirit"
)
local fireRemnantAbility =
	SafeAbility(bot:GetAbilityByName("ember_spirit_fire_remnant"), "ember_spirit_fire_remnant", "ember_spirit")
local searingChainsDesire
local sleightOfFistDesire, sleightOfFistLocation
local flameGuardDesire
local activateFireRemnantDesire, activateFireRemnantLocation
local fireRemnantDesire, fireRemnantLocation
local lastRemnant = { time = -100, initialLocation = nil, targetLocation = nil }
local lastSleight = { time = -100, location = nil }
local hasFarmItem = false
local isAttacking = false
local botTarget
local isGoingOnSomeone
local isRetreating
local hpRatio
local nearbyAllies, nearbyEnemies
function X.SkillsComplement()
	if Fu.CanNotUseAbility(bot) and not bot:HasModifier("modifier_ember_spirit_sleight_of_fist_caster") then
		return
	end
	local context = AbilityContext.Build(bot)
	isGoingOnSomeone = context.isEngaging
	isRetreating = context.isRetreating
	hpRatio = context.hp
	hasFarmItem = Fu.HasItem(bot, "item_maelstrom")
		or Fu.HasItem(bot, "item_mjollnir")
		or Fu.HasItem(bot, "item_bfury")
		or Fu.HasItem(bot, "item_radiance")
	isAttacking = Fu.IsAttacking(bot)
	botTarget = Fu.GetProperTarget(bot)
	nearbyAllies = bot:GetNearbyHeroes(1600, false, BOT_MODE_NONE) or {}
	nearbyEnemies = bot:GetNearbyHeroes(1600, true, BOT_MODE_NONE) or {}
	local chainAfterSleight
	sleightOfFistDesire, sleightOfFistLocation, chainAfterSleight = X.ConsiderSleightOfFist()
	if sleightOfFistDesire > 0 then
		lastSleight.time = DotaTime()
		lastSleight.location = chainAfterSleight and sleightOfFistLocation or nil
		bot:ActionQueue_UseAbilityOnLocation(sleightOfFistAbility, sleightOfFistLocation)
		return
	end
	searingChainsDesire = X.ConsiderSearingChains()
	if searingChainsDesire > 0 then
		bot:Action_UseAbility(searingChainsAbility)
		return
	end
	activateFireRemnantDesire, activateFireRemnantLocation = X.ConsiderActivateFireRemnant()
	if activateFireRemnantDesire > 0 then
		bot:ActionQueue_UseAbilityOnLocation(activateFireRemnantAbility, activateFireRemnantLocation)
		return
	end
	fireRemnantDesire, fireRemnantLocation = X.ConsiderFireRemnant()
	if fireRemnantDesire > 0 then
		lastRemnant.time = DotaTime()
		lastRemnant.initialLocation = bot:GetLocation()
		lastRemnant.targetLocation = fireRemnantLocation
		bot:Action_UseAbilityOnLocation(fireRemnantAbility, fireRemnantLocation)
		return
	end
	flameGuardDesire = X.ConsiderFlameGuard()
	if flameGuardDesire > 0 then
		bot:ActionQueue_UseAbility(flameGuardAbility)
		return
	end
end
function X.ConsiderSearingChains()
	if not Fu.CanCastAbility(searingChainsAbility) then
		return BOT_ACTION_DESIRE_NONE
	end
	local radius = searingChainsAbility:GetSpecialValueInt("radius")
	local damagePerSecond = searingChainsAbility:GetSpecialValueInt("damage_per_second")
	local duration = searingChainsAbility:GetSpecialValueFloat("duration")
	local totalDamage = damagePerSecond * duration
	if bot:HasModifier("modifier_ember_spirit_sleight_of_fist_caster") and lastSleight.location ~= nil then
		if GetUnitToLocationDistance(bot, lastSleight.location) <= radius then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanBeAttacked(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and Fu.IsInRange(bot, enemyHero, radius)
			and not Fu.IsSuspiciousIllusion(enemyHero)
		then
			if enemyHero:IsChanneling() then
				return BOT_ACTION_DESIRE_HIGH
			end
			if
				Fu.CanKillTarget(enemyHero, totalDamage, DAMAGE_TYPE_MAGICAL)
				and not Fu.CanCastAbility(sleightOfFistAbility)
				and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
				and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
				and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
				and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
			then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	if isGoingOnSomeone and not Fu.CanCastAbilitySoon(sleightOfFistAbility, 3.0) then
		if
			Fu.IsValidHero(botTarget)
			and Fu.CanBeAttacked(botTarget)
			and Fu.IsInRange(bot, botTarget, radius)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and not Fu.IsDisabled(botTarget)
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			return BOT_ACTION_DESIRE_HIGH
		end
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.CanBeAttacked(enemyHero)
				and Fu.IsInRange(bot, enemyHero, radius)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
			then
				if
					enemyHero:HasModifier("modifier_item_glimmer_cape")
					or enemyHero:HasModifier("modifier_invisible")
					or enemyHero:HasModifier("modifier_item_shadow_amulet_fade")
				then
					if
						not enemyHero:HasModifier("modifier_item_dustofappearance")
						and not enemyHero:HasModifier("modifier_slardar_amplify_damage")
						and not enemyHero:HasModifier("modifier_bloodseeker_thirst_vision")
						and not enemyHero:HasModifier("modifier_sniper_assassinate")
						and not enemyHero:HasModifier("modifier_bounty_hunter_track")
					then
						return BOT_ACTION_DESIRE_HIGH
					end
				end
			end
		end
	end
	if isRetreating and not Fu.IsRealInvisible(bot) then
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.CanBeAttacked(enemyHero)
				and Fu.IsInRange(bot, enemyHero, radius)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and not enemyHero:IsDisarmed()
				and not Fu.IsDisabled(enemyHero)
				and bot:WasRecentlyDamagedByHero(enemyHero, 3.0)
			then
				if
					Fu.IsChasingTarget(enemyHero, bot)
					or #nearbyEnemies > #nearbyAllies
					or #(bot:GetNearbyHeroes(radius - 50, true, BOT_MODE_NONE) or {}) >= 2
				then
					return BOT_ACTION_DESIRE_HIGH
				end
			end
		end
	end
	local nearbyCreeps = bot:GetNearbyCreeps(radius, true)
	if
		not hasFarmItem
		and not Fu.CanCastAbility(sleightOfFistAbility)
		and not bot:HasModifier("modifier_ember_spirit_flame_guard")
	then
		if Fu.IsPushing(bot) and #nearbyAllies <= 2 and isAttacking and #nearbyEnemies <= 1 then
			if #nearbyCreeps >= 4 then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
		if Fu.IsDefending(bot) and #nearbyAllies <= 3 and isAttacking and #nearbyEnemies == 0 then
			if #nearbyCreeps >= 4 then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
		if Fu.IsFarming(bot) and isAttacking then
			if
				#nearbyCreeps >= 3
				or #nearbyCreeps >= 2 and Fu.IsValid(nearbyCreeps[1]) and nearbyCreeps[1]:IsAncientCreep()
				or #nearbyCreeps >= 1 and Fu.IsValid(nearbyCreeps[1]) and nearbyCreeps[1]:GetHealth() >= 1000
			then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if
			Fu.IsRoshan(botTarget)
			and Fu.CanBeAttacked(botTarget)
			and Fu.IsInRange(bot, botTarget, radius)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and not Fu.IsDisabled(botTarget)
			and Fu.GetHP(botTarget) > 0.2
			and isAttacking
			and #nearbyEnemies == 0
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if
			Fu.IsTormentor(botTarget)
			and Fu.IsInRange(bot, botTarget, radius)
			and isAttacking
			and #nearbyEnemies == 0
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderSleightOfFist()
	if
		not Fu.CanCastAbility(sleightOfFistAbility)
		or bot:IsRooted()
		or bot:HasModifier("modifier_ember_spirit_sleight_of_fist_caster")
	then
		return BOT_ACTION_DESIRE_NONE, 0, false
	end
	local castRange = sleightOfFistAbility:GetCastRange()
	local castPoint = sleightOfFistAbility:GetCastPoint()
	local radius = sleightOfFistAbility:GetSpecialValueInt("radius")
	local bonusHeroDamage = sleightOfFistAbility:GetSpecialValueInt("bonus_hero_damage")
	local chargeRestoreTime = sleightOfFistAbility:GetSpecialValueInt("AbilityChargeRestoreTime")
	local attackDamage = bot:GetAttackDamage() + bonusHeroDamage
	local abilityLevel = sleightOfFistAbility:GetLevel()
	local manaCost = sleightOfFistAbility:GetManaCost()
	botTarget = Fu.GetProperTarget(bot)
	local hasManaForChains = false
	if Fu.CanCastAbility(searingChainsAbility) then
		hasManaForChains = bot:GetMana() > searingChainsAbility:GetManaCost() + manaCost + 75
	end
	local nearbyCreeps = bot:GetNearbyCreeps(Min(castRange, 1600), true)
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanBeAttacked(enemyHero)
			and Fu.IsInRange(bot, enemyHero, castRange + radius)
			and Fu.CanKillTarget(enemyHero, attackDamage, DAMAGE_TYPE_PHYSICAL)
			and not Fu.IsSuspiciousIllusion(enemyHero)
			and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
			and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
			and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
			and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
			and not enemyHero:HasModifier("modifier_templar_assassin_refraction_absorb")
		then
			local castLocation = Fu.IsInRange(bot, enemyHero, castRange) and enemyHero:GetLocation()
				or Fu.Site.GetXUnitsTowardsLocation(bot, enemyHero:GetLocation(), castRange)
			return BOT_ACTION_DESIRE_HIGH, castLocation, false
		end
	end
	if Fu.IsStunProjectileIncoming(bot, 300) then
		if Fu.IsValid(nearbyCreeps[1]) then
			return BOT_ACTION_DESIRE_HIGH, nearbyCreeps[1]:GetLocation(), false
		end
		if Fu.IsValidHero(nearbyEnemies[1]) and Fu.IsInRange(bot, nearbyEnemies[1], castRange + radius) then
			local castLocation = Fu.IsInRange(bot, nearbyEnemies[1], castRange) and nearbyEnemies[1]:GetLocation()
				or Fu.Site.GetXUnitsTowardsLocation(bot, nearbyEnemies[1]:GetLocation(), castRange)
			return BOT_ACTION_DESIRE_HIGH, castLocation, false
		end
	end
	if Fu.IsInTeamFight(bot, 1200) then
		local aoe = bot:FindAoELocation(true, true, bot:GetLocation(), castRange, radius, 0, 0)
		local enemiesNearAoe = Fu.GetEnemiesNearLoc(aoe.targetloc, radius)
		if aoe.count >= 3 or #enemiesNearAoe >= 2 then
			return BOT_ACTION_DESIRE_HIGH, aoe.targetloc, true
		end
	end
	if isGoingOnSomeone then
		if
			Fu.IsValidHero(botTarget)
			and Fu.CanBeAttacked(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange + radius)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not botTarget:HasModifier("modifier_abaddon_borrowed_time")
			and not botTarget:HasModifier("modifier_faceless_void_chronosphere_freeze")
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			local canChain = not botTarget:IsMagicImmune() and not Fu.IsDisabled(botTarget)
			if
				not Fu.CanCastAbility(searingChainsAbility)
				and Fu.CanCastAbilitySoon(searingChainsAbility, 3.0)
				and Fu.GetHP(botTarget) > 0.25
				and hasManaForChains
			then
				return BOT_ACTION_DESIRE_NONE, 0, false
			end
			if Fu.CanCastAbility(searingChainsAbility) and hasManaForChains then
				if Fu.IsInRange(bot, botTarget, castRange + radius / 2) then
					local castLocation = Fu.IsInRange(bot, botTarget, castRange) and botTarget:GetLocation()
						or Fu.Site.GetXUnitsTowardsLocation(bot, botTarget:GetLocation(), castRange)
					return BOT_ACTION_DESIRE_HIGH, castLocation, canChain
				end
			else
				if Fu.IsInRange(bot, botTarget, castRange) then
					return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation(), canChain
				end
			end
		end
	end
	if isRetreating and not Fu.IsRealInvisible(bot) then
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.CanBeAttacked(enemyHero)
				and Fu.IsInRange(bot, enemyHero, castRange)
				and not Fu.IsInRange(bot, enemyHero, 400)
				and not enemyHero:IsDisarmed()
				and bot:WasRecentlyDamagedByHero(enemyHero, 3.0)
			then
				local canChain = not enemyHero:IsMagicImmune() and not Fu.IsDisabled(enemyHero)
				if
					Fu.IsChasingTarget(enemyHero, bot)
						and not Fu.IsSuspiciousIllusion(enemyHero)
						and Fu.CanCastAbility(searingChainsAbility)
						and hasManaForChains
					or #nearbyEnemies > #nearbyAllies
				then
					return BOT_ACTION_DESIRE_HIGH, enemyHero:GetLocation(), canChain
				end
			end
		end
	end
	if
		Fu.IsPushing(bot)
		and #nearbyAllies <= 3
		and isAttacking
		and DotaTime() >= lastSleight.time + chargeRestoreTime / 2
	then
		for _, creep in pairs(nearbyCreeps) do
			if Fu.IsValid(creep) and Fu.CanBeAttacked(creep) then
				local aoe = bot:FindAoELocation(true, false, creep:GetLocation(), 0, radius, 0, 0)
				if aoe.count >= 4 then
					return BOT_ACTION_DESIRE_HIGH, aoe.targetloc, false
				end
			end
		end
	end
	if Fu.IsDefending(bot) and isAttacking then
		if DotaTime() >= lastSleight.time + chargeRestoreTime / 2 then
			for _, creep in pairs(nearbyCreeps) do
				if Fu.IsValid(creep) and Fu.CanBeAttacked(creep) then
					local aoe = bot:FindAoELocation(true, false, creep:GetLocation(), 0, radius, 0, 0)
					if aoe.count >= 4 then
						return BOT_ACTION_DESIRE_HIGH, aoe.targetloc, false
					end
				end
			end
		end
		local aoe = bot:FindAoELocation(true, true, bot:GetLocation(), castRange, radius, 0, 0)
		if aoe.count >= 3 then
			return BOT_ACTION_DESIRE_HIGH, aoe.targetloc, false
		end
	end
	if
		Fu.IsFarming(bot)
		and isAttacking
		and abilityLevel >= 3
		and DotaTime() >= lastSleight.time + chargeRestoreTime / 2
	then
		for _, creep in pairs(nearbyCreeps) do
			if Fu.IsValid(creep) and Fu.CanBeAttacked(creep) and not Fu.IsRunning(creep) then
				local aoe = bot:FindAoELocation(true, false, creep:GetLocation(), 0, radius, 0, 0)
				if aoe.count >= 3 or aoe.count >= 2 and creep:IsAncientCreep() then
					return BOT_ACTION_DESIRE_HIGH, aoe.targetloc, false
				end
			end
		end
	end
	if Fu.IsLaning(bot) and Fu.IsInLaningPhase() and Fu.AllowedToSpam(bot, manaCost) then
		local laneCreeps = bot:GetNearbyLaneCreeps(castRange, true)
		for _, creep in pairs(laneCreeps) do
			if
				Fu.IsValid(creep)
				and Fu.CanBeAttacked(creep)
				and Fu.CanKillTarget(creep, bonusHeroDamage, DAMAGE_TYPE_PHYSICAL)
			then
				local unitName = creep:GetUnitName()
				if string.find(unitName, "ranged") then
					local aoe = bot:FindAoELocation(true, true, creep:GetLocation(), 0, radius, 0, 0)
					if aoe.count > 0 or Fu.IsUnitTargetedByTower(creep, false) then
						return BOT_ACTION_DESIRE_HIGH, creep:GetLocation(), false
					end
				end
			end
		end
		local aoe = bot:FindAoELocation(true, true, bot:GetLocation(), castRange, radius, 0, bot:GetAttackDamage())
		if aoe.count >= 2 and #nearbyEnemies > 0 then
			return BOT_ACTION_DESIRE_HIGH, aoe.targetloc, false
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if
			Fu.IsRoshan(botTarget)
			and Fu.CanBeAttacked(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and Fu.GetHP(botTarget) > 0.2
			and isAttacking
			and #nearbyEnemies == 0
			and DotaTime() >= lastSleight.time + chargeRestoreTime / 1.5
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation(), false
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if
			Fu.IsTormentor(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and isAttacking
			and #nearbyEnemies == 0
			and DotaTime() >= lastSleight.time + chargeRestoreTime / 1.5
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation(), false
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0, false
end
function X.ConsiderFlameGuard()
	if not Fu.CanCastAbility(flameGuardAbility) or bot:HasModifier("modifier_ember_spirit_sleight_of_fist_caster") then
		return BOT_ACTION_DESIRE_NONE
	end
	local radius = flameGuardAbility:GetSpecialValueInt("radius")
	botTarget = Fu.GetProperTarget(bot)
	if Fu.IsInTeamFight(bot, 1200) then
		if bot:WasRecentlyDamagedByAnyHero(1.0) then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if isGoingOnSomeone then
		if Fu.IsValidHero(botTarget) and not Fu.IsSuspiciousIllusion(botTarget) then
			if
				Fu.CanBeAttacked(botTarget)
				and Fu.CanCastOnNonMagicImmune(botTarget)
				and Fu.IsInRange(bot, botTarget, radius)
				and not botTarget:HasModifier("modifier_abaddon_borrowed_time")
			then
				return BOT_ACTION_DESIRE_HIGH
			end
			if bot:WasRecentlyDamagedByAnyHero(2.0) or hpRatio < 0.5 and bot:WasRecentlyDamagedByTower(2.0) then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	if isRetreating and not Fu.IsRealInvisible(bot) and bot:WasRecentlyDamagedByAnyHero(3.0) then
		if hpRatio < 0.6 or #nearbyEnemies > #nearbyAllies and bot:WasRecentlyDamagedByAnyHero(1.0) then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	local nearbyCreeps = bot:GetNearbyCreeps(radius, true)
	if not bot:HasModifier("modifier_ember_spirit_flame_guard") then
		if Fu.IsPushing(bot) and #nearbyAllies <= 2 and isAttacking and #nearbyEnemies == 0 then
			if Fu.IsValid(nearbyCreeps[1]) and Fu.CanBeAttacked(nearbyCreeps[1]) and not hasFarmItem then
				if #nearbyCreeps >= 4 then
					return BOT_ACTION_DESIRE_HIGH
				end
			end
		end
		if Fu.IsDefending(bot) and #nearbyAllies <= 3 and isAttacking and #nearbyEnemies == 0 then
			if Fu.IsValid(nearbyCreeps[1]) and Fu.CanBeAttacked(nearbyCreeps[1]) then
				if #nearbyCreeps >= 4 and not hasFarmItem or #nearbyCreeps >= 6 then
					return BOT_ACTION_DESIRE_HIGH
				end
			end
		end
		if Fu.IsFarming(bot) and isAttacking and #nearbyEnemies <= 1 then
			if Fu.IsValid(nearbyCreeps[1]) and Fu.CanBeAttacked(nearbyCreeps[1]) then
				if
					#nearbyCreeps >= 3
					or #nearbyCreeps >= 2 and nearbyCreeps[1]:IsAncientCreep() and hasFarmItem
					or #nearbyCreeps >= 5
				then
					return BOT_ACTION_DESIRE_HIGH
				end
			end
			if Fu.IsValid(nearbyCreeps[1]) and Fu.CanBeAttacked(nearbyCreeps[1]) and not hasFarmItem then
				if #nearbyCreeps >= 3 or #nearbyCreeps >= 2 and nearbyCreeps[1]:IsAncientCreep() then
					return BOT_ACTION_DESIRE_HIGH
				end
			end
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if
			Fu.IsRoshan(botTarget)
			and Fu.CanBeAttacked(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, radius)
			and isAttacking
			and #nearbyEnemies == 0
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if
			Fu.IsTormentor(botTarget)
			and Fu.IsInRange(bot, botTarget, radius)
			and isAttacking
			and #nearbyEnemies == 0
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderActivateFireRemnant()
	if not Fu.CanCastAbility(activateFireRemnantAbility) or bot:IsRooted() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	if lastRemnant.initialLocation ~= nil and Fu.CanCastAbility(fireRemnantAbility) then
		local remnantSpeed = bot:GetCurrentMovementSpeed()
			* fireRemnantAbility:GetSpecialValueInt("speed_multiplier")
			/ (bot:HasScepter() and 50 or 100)
		local activateSpeed = activateFireRemnantAbility:GetSpecialValueInt("speed")
			* activateFireRemnantAbility:GetSpecialValueInt("speed_multiplier")
			/ (bot:HasScepter() and 50 or 100)
		if
			DotaTime()
			< lastRemnant.time
				+ Fu.GetDistance(lastRemnant.initialLocation, lastRemnant.targetLocation) / remnantSpeed
				+ fireRemnantAbility:GetCastPoint()
				- (Fu.GetDistance(lastRemnant.initialLocation, lastRemnant.targetLocation) / activateSpeed + activateFireRemnantAbility:GetCastPoint())
		then
			return BOT_ACTION_DESIRE_NONE, 0
		end
	end
	if isGoingOnSomeone then
		if
			Fu.IsValidHero(botTarget)
			and Fu.CanBeAttacked(botTarget)
			and GetUnitToLocationDistance(botTarget, Fu.GetEnemyFountain()) > 600
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not botTarget:HasModifier("modifier_faceless_void_chronosphere_freeze")
		then
			local bestRemnant = nil
			local bestDistance = math.huge
			for _, remnant in pairs(GetUnitList(UNIT_LIST_ALLIES)) do
				if Fu.IsValid(remnant) and remnant:GetUnitName() == "npc_dota_ember_spirit_remnant" then
					local distanceToTarget = GetUnitToUnitDistance(remnant, botTarget)
					if
						bestDistance > distanceToTarget
						and distanceToTarget <= 600
						and GetUnitToUnitDistance(bot, remnant) >= GetUnitToUnitDistance(bot, botTarget)
					then
						bestRemnant = remnant
						bestDistance = distanceToTarget
					end
				end
			end
			local nearbyAllies = Fu.GetAlliesNearLoc(bot:GetLocation(), 1200)
			if bestRemnant ~= nil then
				if Fu.IsEarlyGame() then
					if Fu.GetHP(botTarget) < 0.3 or Fu.GetHP(botTarget) < 0.5 and #nearbyAllies >= 2 then
						return BOT_ACTION_DESIRE_HIGH, bestRemnant:GetLocation()
					end
				else
					return BOT_ACTION_DESIRE_HIGH, bestRemnant:GetLocation()
				end
			end
		end
	end
	if isRetreating and not Fu.IsRealInvisible(bot) then
		local bestRemnant = nil
		local bestDistance = -math.huge
		for _, remnant in pairs(GetUnitList(UNIT_LIST_ALLIES)) do
			if Fu.IsValid(remnant) and remnant:GetUnitName() == "npc_dota_ember_spirit_remnant" then
				local remnantFountainDistance = GetUnitToLocationDistance(remnant, Fu.GetTeamFountain())
				local botFountainDistance = GetUnitToLocationDistance(bot, Fu.GetTeamFountain())
				local distanceToRemnant = GetUnitToUnitDistance(bot, remnant)
				if remnantFountainDistance < botFountainDistance and bestDistance < distanceToRemnant then
					bestRemnant = remnant
					-- fix: store the distance that is compared (was the remnant's fountain distance)
					bestDistance = distanceToRemnant
				end
			end
		end
		if bestRemnant ~= nil then
			for _, enemyHero in pairs(nearbyEnemies) do
				if
					Fu.IsValidHero(enemyHero)
					and Fu.IsInRange(bot, enemyHero, 1600)
					and not Fu.IsSuspiciousIllusion(enemyHero)
					and not enemyHero:IsDisarmed()
				then
					if Fu.IsChasingTarget(enemyHero, bot) or #nearbyEnemies > #nearbyAllies or hpRatio < 0.5 then
						if DotaTime() >= (bot._ohaRemnantRetreatLogAt or -999) then
							bot._ohaRemnantRetreatLogAt = DotaTime() + 5
							pcall(
								print,
								string.format(
									"[OHA-EMBER_SPIRIT] t=%.0f retreat to remnant %.0f away (farthest toward fountain)",
									DotaTime(),
									bestDistance
								)
							)
						end
						return BOT_ACTION_DESIRE_HIGH, bestRemnant:GetLocation()
					end
				end
			end
		end
	end
	for _, remnant in pairs(GetUnitList(UNIT_LIST_ALLIES)) do
		if Fu.IsValid(remnant) and remnant:GetUnitName() == "npc_dota_ember_spirit_remnant" then
			local alliesNearRemnant = Fu.GetAlliesNearLoc(remnant:GetLocation(), 1200)
			local enemiesNearRemnant = Fu.GetEnemiesNearLoc(remnant:GetLocation(), 1200)
			local distanceToRemnant = GetUnitToUnitDistance(bot, remnant)
			if isGoingOnSomeone and #alliesNearRemnant + 1 >= #enemiesNearRemnant then
				local canKill = X.CanRemnantKill(remnant)
				if canKill then
					return BOT_ACTION_DESIRE_HIGH, remnant:GetLocation()
				end
			end
			if
				not isRetreating
				and bot:HasModifier("modifier_fountain_aura_buff")
				and hpRatio > 0.9
				and Fu.GetMP(bot) > 0.9
			then
				if #enemiesNearRemnant == 0 and distanceToRemnant > 4000 then
					return BOT_ACTION_DESIRE_HIGH, remnant:GetLocation()
				end
			end
			local teamFightLocation = Fu.GetTeamFightLocation(bot)
			if
				isGoingOnSomeone
				and #nearbyEnemies == 0
				and teamFightLocation ~= nil
				and GetUnitToLocationDistance(bot, teamFightLocation) > 1600
			then
				if GetUnitToLocationDistance(remnant, teamFightLocation) <= 1200 then
					return BOT_ACTION_DESIRE_HIGH, remnant:GetLocation()
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.ConsiderFireRemnant()
	if not Fu.CanCastAbility(fireRemnantAbility) or not Fu.CanCastAbility(activateFireRemnantAbility) then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local castRange = fireRemnantAbility:GetCastRange()
	local castPoint = fireRemnantAbility:GetCastPoint()
	local damage = fireRemnantAbility:GetSpecialValueInt("damage")
	local travelSpeed = bot:GetCurrentMovementSpeed()
		* fireRemnantAbility:GetSpecialValueInt("speed_multiplier")
		/ (bot:HasScepter() and 50 or 100)
	if lastRemnant.initialLocation ~= nil then
		if
			DotaTime()
			< lastRemnant.time
				+ Fu.GetDistance(lastRemnant.initialLocation, lastRemnant.targetLocation) / travelSpeed
				+ castPoint
		then
			return BOT_ACTION_DESIRE_NONE, 0
		end
	end
	botTarget = Fu.GetProperTarget(bot)
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanBeAttacked(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and GetUnitToLocationDistance(enemyHero, Fu.GetTeamFountain()) > 1200
			and Fu.IsInRange(bot, enemyHero, 1400)
			and not Fu.IsInRange(bot, enemyHero, 400)
			and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
			and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
			and not enemyHero:HasModifier("modifier_faceless_void_chronosphere")
			and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
			and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
			and not enemyHero:HasModifier("modifier_templar_assassin_refraction_absorb")
		then
			local travelTime = GetUnitToUnitDistance(bot, enemyHero) / travelSpeed + castPoint
			if Fu.CanKillTarget(enemyHero, damage, DAMAGE_TYPE_MAGICAL) then
				if Fu.IsChasingTarget(bot, enemyHero) and enemyHero:GetMovementDirectionStability() >= 0.9 then
					local castLocation = Fu.Site.GetXUnitsTowardsLocation(enemyHero, Fu.GetEnemyFountain(), 500)
					if
						GetUnitToLocationDistance(bot, castLocation) <= 1400
						and not X.IsThereRemnantInLocation(castLocation, 500)
					then
						return BOT_ACTION_DESIRE_HIGH, castLocation
					end
				else
					if not X.IsThereRemnantInLocation(enemyHero:GetLocation(), 500) then
						return BOT_ACTION_DESIRE_HIGH, enemyHero:GetLocation()
					end
				end
			end
		end
	end
	if isGoingOnSomeone then
		if
			Fu.IsValidHero(botTarget)
			and Fu.CanBeAttacked(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and GetUnitToLocationDistance(botTarget, Fu.GetTeamFountain()) > 1200
			and not Fu.IsInRange(bot, botTarget, bot:GetAttackRange() + 150)
			and not botTarget:HasModifier("modifier_abaddon_borrowed_time")
			and not botTarget:HasModifier("modifier_faceless_void_chronosphere_freeze")
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			local travelTime = GetUnitToUnitDistance(bot, botTarget) / travelSpeed + castPoint
			local alliesTargetingTarget = Fu.GetHeroesTargetingUnit(nearbyAllies, botTarget)
			if
				Fu.CanCastAbility(searingChainsAbility) and Fu.CanCastAbility(sleightOfFistAbility)
				or #alliesTargetingTarget >= 2 and (Fu.IsChasingTarget(bot, botTarget) or not Fu.IsInRange(
					bot,
					botTarget,
					550
				))
				or hpRatio > 0.3 and Fu.GetHP(botTarget) < 0.15
			then
				local castLocation = botTarget:GetExtrapolatedLocation(travelTime)
				if
					GetUnitToLocationDistance(bot, castLocation) <= castRange
					and not X.IsThereRemnantInLocation(castLocation, 500)
				then
					return BOT_ACTION_DESIRE_HIGH, castLocation
				end
			end
		end
	end
	if isRetreating and not Fu.IsRealInvisible(bot) and bot:WasRecentlyDamagedByAnyHero(4.0) then
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValidHero(enemyHero)
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and not Fu.IsDisabled(enemyHero)
			then
				if Fu.IsChasingTarget(enemyHero, bot) or #nearbyEnemies > #nearbyAllies or hpRatio < 0.4 then
					local castLocation = Fu.Site.GetXUnitsTowardsLocation(
						bot,
						Fu.GetTeamFountain(),
						RandomInt(math.floor(castRange * 0.75), castRange)
					)
					if not X.IsThereRemnantInLocation(bot:GetLocation(), castRange) then
						return BOT_ACTION_DESIRE_HIGH, castLocation
					end
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.IsThereRemnantInLocation(location, radius)
	for _, remnant in pairs(GetUnitList(UNIT_LIST_ALLIES)) do
		if
			remnant ~= nil
			and remnant:GetUnitName() == "npc_dota_ember_spirit_remnant"
			and GetUnitToLocationDistance(remnant, location) <= radius
		then
			return true
		end
	end
	return false
end
function X.CanRemnantKill(remnant)
	if not Fu.CanCastAbility(fireRemnantAbility) then
		return false
	end
	local castPoint = fireRemnantAbility:GetCastPoint()
	local travelSpeed = activateFireRemnantAbility:GetSpecialValueInt("speed")
	local damage = fireRemnantAbility:GetSpecialValueInt("damage")
	local radius = fireRemnantAbility:GetSpecialValueInt("radius")
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanBeAttacked(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and GetUnitToLocationDistance(enemyHero, Fu.GetTeamFountain()) > 600
			and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
			and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
			and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
			and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
			and not enemyHero:HasModifier("modifier_templar_assassin_refraction_absorb")
		then
			local travelTime = GetUnitToUnitDistance(bot, enemyHero) / travelSpeed + castPoint
			if Fu.CanKillTarget(enemyHero, damage, DAMAGE_TYPE_MAGICAL) then
				local distanceToRemnant = GetUnitToUnitDistance(enemyHero, remnant)
				if distanceToRemnant <= radius and GetUnitToUnitDistance(bot, enemyHero) <= 1400 then
					return true
				end
			end
		end
	end
	return false
end
return X
