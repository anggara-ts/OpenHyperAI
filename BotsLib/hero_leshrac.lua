-- Leshrac: skill build, item build, and ability use for this hero.
local X = {}
local bot = GetBot()
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local AbilityContext = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local Minion = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local LaneNukeRules = require(GetScriptDirectory() .. "/FuncLib/systems/lane_nuke_rules")
local sTalentList = Fu.Skill.GetTalentList(bot)
local sAbilityList = Fu.Skill.GetAbilityList(bot)
local sRole = Fu.Item.GetRoleItemsBuyList(bot)
local tTalentTreeList = {
	{ ["t25"] = { 10, 0 }, ["t20"] = { 10, 0 }, ["t15"] = { 0, 10 }, ["t10"] = { 10, 0 } },
	{ ["t25"] = { 10, 0 }, ["t20"] = { 0, 10 }, ["t15"] = { 10, 0 }, ["t10"] = { 10, 0 } },
}
-- Diabolic Edict maxed first, Lightning Storm second, Split Earth last (Dotabuff most picked order).
-- Pulse Nova at entries 6/11/15 (levels 6/12/18).
local tAllAbilityBuildList =
	{ { 3, 2, 3, 2, 2, 6, 2, 3, 3, 1, 6, 1, 1, 1, 6 }, { 3, 2, 3, 2, 2, 6, 2, 3, 3, 1, 6, 1, 1, 1, 6 } }
local nAbilityBuildList
local nTalentBuildList
if sRole == "pos_2" then
	nAbilityBuildList = tAllAbilityBuildList[1]
	nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList[1])
else
	nAbilityBuildList = tAllAbilityBuildList[2]
	nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList[2])
end
local sUtility = "item_team_aura"
local sRoleItemsBuyList = {}
-- Stratz 7.41f, week of 9 Nov 2026: pos 2, 26,088 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_2"] = {
	"item_tango",
	"item_double_branches",
	"item_faerie_fire",
	"item_magic_wand",
	"item_null_talisman",
	"item_arcane_boots",
	"item_blink",
	"item_kaya_and_sange",
	"item_veil_of_discord",
	"item_black_king_bar",
	"item_bloodstone",
	"item_ultimate_scepter",
	"item_aghanims_shard",
	"item_ultimate_scepter_2",
	"item_overwhelming_blink",
	"item_sheepstick",
	"item_moon_shard",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 3, 3,495 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_3"] = {
	"item_tango",
	"item_double_branches",
	"item_circlet",
	"item_faerie_fire",
	"item_mantle",
	"item_null_talisman",
	"item_magic_wand",
	"item_arcane_boots",
	"item_kaya",
	"item_blink",
	"item_kaya_and_sange",
	sUtility,
	"item_black_king_bar",
	"item_ultimate_scepter",
	"item_aghanims_shard",
	"item_ultimate_scepter_2",
	"item_overwhelming_blink",
	"item_consecrated_wraps",
	"item_moon_shard",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 1, 6,576 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_1"] = {
	"item_tango",
	"item_double_branches",
	"item_faerie_fire",
	"item_circlet",
	"item_mantle",
	"item_null_talisman",
	"item_magic_wand",
	"item_arcane_boots",
	"item_bloodstone",
	"item_black_king_bar",
	"item_shivas_guard",
	sUtility,
	"item_ultimate_scepter",
	"item_aghanims_shard",
	"item_ultimate_scepter_2",
	"item_yasha_and_kaya",
	"item_moon_shard",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 4, 3,563 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_4"] = {
	"item_tango",
	"item_blood_grenade",
	"item_double_branches",
	"item_magic_stick",
	"item_faerie_fire",
	"item_null_talisman",
	"item_magic_wand",
	"item_arcane_boots",
	"item_blink",
	"item_kaya",
	"item_cyclone",
	"item_aghanims_shard",
	"item_kaya_and_sange",
	sUtility,
	"item_ultimate_scepter",
	"item_travel_boots",
	"item_ultimate_scepter_2",
	"item_glimmer_cape",
	"item_moon_shard",
	"item_travel_boots_2",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 5, 2,230 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_5"] = {
	"item_tango",
	"item_blood_grenade",
	"item_double_branches",
	"item_magic_stick",
	"item_faerie_fire",
	"item_null_talisman",
	"item_magic_wand",
	"item_arcane_boots",
	"item_blink",
	"item_kaya",
	"item_cyclone",
	"item_kaya_and_sange",
	"item_aghanims_shard",
	sUtility,
	"item_travel_boots",
	"item_wind_waker",
	"item_glimmer_cape",
	"item_moon_shard",
	"item_ultimate_scepter_2",
	"item_travel_boots_2",
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
X["bDeafaultItem"] = false
function X.MinionThink(minionUnit)
	Minion.MinionThink(minionUnit)
end
local splitEarthAbility = SafeAbility(bot:GetAbilityByName("leshrac_split_earth"), "leshrac_split_earth", "leshrac")
local diabolicEdictAbility =
	SafeAbility(bot:GetAbilityByName("leshrac_diabolic_edict"), "leshrac_diabolic_edict", "leshrac")
local lightningStormAbility =
	SafeAbility(bot:GetAbilityByName("leshrac_lightning_storm"), "leshrac_lightning_storm", "leshrac")
local nihilismAbility =
	SafeAbility(bot:GetAbilityByName("leshrac_greater_lightning_storm"), "leshrac_greater_lightning_storm", "leshrac")
local pulseNovaAbility = SafeAbility(bot:GetAbilityByName("leshrac_pulse_nova"), "leshrac_pulse_nova", "leshrac")
local splitEarthDesire, splitEarthLocation
local diabolicEdictDesire
local lightningStormDesire, lightningStormTarget
local nihilismDesire
local pulseNovaDesire
local botTarget
if bot.edictPushing == nil then
	bot.edictPushing = false
end
local isGoingOnSomeone
local isRetreating
local isAttacking
local mpRatio
local isInTeamFight
function X.SkillsComplement()
	X.LogStormLastHitResult()
	if Fu.CanNotUseAbility(bot) then
		return
	end
	isGoingOnSomeone = Fu.IsGoingOnSomeone(bot)
	isRetreating = Fu.IsRetreating(bot)
	isAttacking = Fu.IsAttacking(bot)
	mpRatio = Fu.GetMP(bot)
	isInTeamFight = Fu.IsInTeamFight(bot, 1200)
	botTarget = Fu.GetProperTarget(bot)
	if not bot:HasModifier("modifier_leshrac_diabolic_edict") then
		bot.edictPushing = false
	end
	pulseNovaDesire = X.ConsiderPulseNova()
	if pulseNovaDesire > 0 then
		bot:Action_UseAbility(pulseNovaAbility)
		return
	end
	lightningStormDesire, lightningStormTarget = X.ConsiderLightningStorm()
	if lightningStormDesire > 0 then
		bot:Action_UseAbilityOnEntity(lightningStormAbility, lightningStormTarget)
		return
	end
	splitEarthDesire, splitEarthLocation = X.ConsiderSplitEarth()
	if splitEarthDesire > 0 then
		bot:Action_UseAbilityOnLocation(splitEarthAbility, splitEarthLocation)
		return
	end
	diabolicEdictDesire = X.ConsiderDiabolicEdict()
	if diabolicEdictDesire > 0 then
		bot:Action_UseAbility(diabolicEdictAbility)
		return
	end
	nihilismDesire = X.ConsiderNihilism()
	if nihilismDesire > 0 then
		bot:Action_UseAbility(nihilismAbility)
		return
	end
end
function X.ConsiderSplitEarth()
	if not splitEarthAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local castRange = Fu.GetProperCastRange(false, bot, splitEarthAbility:GetCastRange())
	local castPoint = splitEarthAbility:GetCastPoint()
	local radius = splitEarthAbility:GetSpecialValueInt("radius")
	local delay = splitEarthAbility:GetSpecialValueFloat("delay")
	local damage = splitEarthAbility:GetAbilityDamage()
	local manaCost = splitEarthAbility:GetManaCost()
	local abilityLevel = splitEarthAbility:GetLevel()
	local nearbyEnemies = Fu.GetNearbyHeroes(bot, castRange + radius, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and not Fu.IsSuspiciousIllusion(enemyHero)
		then
			if enemyHero:IsChanneling() or Fu.IsCastingUltimateAbility(enemyHero) then
				return BOT_ACTION_DESIRE_HIGH, enemyHero:GetLocation()
			end
			if
				Fu.CanKillTarget(enemyHero, damage, DAMAGE_TYPE_MAGICAL)
				and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
				and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
				and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
				and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
				and not enemyHero:HasModifier("modifier_templar_assassin_refraction_absorb")
			then
				if not Fu.IsInRange(bot, enemyHero, castRange) then
					local targetLocation = Fu.Site.GetXUnitsTowardsLocation(
						bot,
						enemyHero:GetExtrapolatedLocation(delay + castPoint),
						castRange
					)
					local enemiesAtLocation = Fu.GetEnemiesNearLoc(targetLocation, radius)
					if enemiesAtLocation ~= nil and #enemiesAtLocation >= 1 then
						return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(enemiesAtLocation)
					end
					return BOT_ACTION_DESIRE_HIGH, targetLocation
				end
				local enemiesAtLocation =
					Fu.GetEnemiesNearLoc(enemyHero:GetExtrapolatedLocation(delay + castPoint), radius)
				if enemiesAtLocation ~= nil and #enemiesAtLocation >= 1 then
					return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(enemiesAtLocation)
				end
				return BOT_ACTION_DESIRE_HIGH, enemyHero:GetExtrapolatedLocation(delay + castPoint)
			end
		end
	end
	if isInTeamFight then
		local aoeLocation = bot:FindAoELocation(true, true, bot:GetLocation(), castRange, radius, delay, 0)
		local enemiesInAoe = Fu.GetEnemiesNearLoc(aoeLocation.targetloc, radius)
		if enemiesInAoe ~= nil and #enemiesInAoe >= 2 then
			return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
		end
	end
	if isGoingOnSomeone then
		-- Range cap added: the target can be far beyond reach, and the stun went to a spot castRange units
		-- toward it with nobody there.
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange + radius)
			and not Fu.IsDisabled(botTarget)
			and not botTarget:HasModifier("modifier_faceless_void_chronosphere_freeze")
		then
			local nearbyAllies = Fu.GetNearbyHeroes(bot, 1200, false, BOT_MODE_NONE)
			local nearbyEnemyHeroes = Fu.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE)
			if nearbyAllies ~= nil and nearbyEnemyHeroes ~= nil and #nearbyAllies >= #nearbyEnemyHeroes then
				if Fu.IsChasingTarget(bot, botTarget) then
					nearbyEnemyHeroes =
						Fu.GetEnemiesNearLoc(botTarget:GetExtrapolatedLocation(delay + castPoint), radius)
				else
					nearbyEnemyHeroes = Fu.GetEnemiesNearLoc(botTarget:GetLocation(), radius)
				end
				if nearbyEnemyHeroes ~= nil and #nearbyEnemyHeroes >= 1 then
					if not Fu.IsInRange(bot, botTarget, castRange) then
						return BOT_ACTION_DESIRE_HIGH,
							Fu.Site.GetXUnitsTowardsLocation(bot, Fu.GetCenterOfUnits(nearbyEnemyHeroes), castRange)
					end
				end
				if not Fu.IsInRange(bot, botTarget, castRange) then
					if Fu.IsChasingTarget(bot, botTarget) then
						return BOT_ACTION_DESIRE_HIGH,
							Fu.Site.GetXUnitsTowardsLocation(
								bot,
								botTarget:GetExtrapolatedLocation(delay + castPoint),
								castRange
							)
					else
						return BOT_ACTION_DESIRE_HIGH,
							Fu.Site.GetXUnitsTowardsLocation(bot, botTarget:GetLocation(), castRange)
					end
				else
					if Fu.IsChasingTarget(bot, botTarget) then
						return BOT_ACTION_DESIRE_HIGH, botTarget:GetExtrapolatedLocation(delay + castPoint)
					else
						return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
					end
				end
			end
		end
	end
	if isRetreating then
		local nearbyEnemyHeroes = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
		for _, enemyHero in pairs(nearbyEnemyHeroes) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.IsChasingTarget(enemyHero, bot)
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and not Fu.IsDisabled(enemyHero)
			then
				local enemyTargets = Fu.GetNearbyHeroes(enemyHero, 1200, true, BOT_MODE_NONE)
				local enemyAllies = Fu.GetNearbyHeroes(enemyHero, 1200, false, BOT_MODE_NONE)
				if
					enemyTargets ~= nil
					and enemyAllies ~= nil
					and (#enemyAllies > #enemyTargets or bot:WasRecentlyDamagedByAnyHero(2))
				then
					return BOT_ACTION_DESIRE_HIGH, enemyHero:GetExtrapolatedLocation(delay + castPoint)
				end
			end
		end
	end
	if Fu.IsFarming(bot) then
		local neutralCreeps = bot:GetNearbyNeutralCreeps(castRange)
		if isAttacking then
			if
				neutralCreeps ~= nil
				and (#neutralCreeps >= 3 or #neutralCreeps >= 2 and neutralCreeps[1]:IsAncientCreep())
			then
				return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(neutralCreeps)
			end
			local laneCreeps = bot:GetNearbyLaneCreeps(castRange, true)
			if laneCreeps ~= nil and #laneCreeps >= 4 then
				-- Was GetCenterOfUnits(P), the enemy HEROES list: with no hero near it aimed at (0,0).
				return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(laneCreeps)
			end
		end
	end
	if Fu.IsPushing(bot) or Fu.IsDefending(bot) then
		local aoeLocation = bot:FindAoELocation(true, false, bot:GetLocation(), castRange, radius, 0, 0)
		local laneCreeps = bot:GetNearbyLaneCreeps(castRange, true)
		if laneCreeps ~= nil and #laneCreeps >= 3 and aoeLocation.count >= 3 then
			return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(laneCreeps)
		end
		aoeLocation = bot:FindAoELocation(true, true, bot:GetLocation(), castRange, radius, delay + castPoint, 0)
		if aoeLocation.count >= 1 then
			return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
		end
	end
	if Fu.IsLaning(bot) and abilityLevel >= 2 then
		local killableCreeps = {}
		local nearbyEnemyHeroes = Fu.GetEnemiesNearLoc(bot:GetLocation(), 1200)
		local laneCreeps = bot:GetNearbyLaneCreeps(castRange, true)
		for _, creep in pairs(laneCreeps) do
			if Fu.IsValid(creep) and creep:GetHealth() <= damage then
				table.insert(killableCreeps, creep)
			end
		end
		if
			Fu.GetManaAfter(manaCost) > 0.25
			and nearbyEnemyHeroes ~= nil
			and #nearbyEnemyHeroes >= 1
			and #killableCreeps >= 2
			and Fu.CanBeAttacked(killableCreeps[1])
		then
			return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(killableCreeps)
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if
			Fu.IsRoshan(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, 500)
			and isAttacking
			and not Fu.IsDisabled(botTarget)
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, 500) and isAttacking then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	local nearbyAllyHeroes = Fu.GetNearbyHeroes(bot, castRange, false, BOT_MODE_NONE)
	for _, allyHero in pairs(nearbyAllyHeroes) do
		local enemiesNearAlly = Fu.GetNearbyHeroes(allyHero, 1200, true, BOT_MODE_NONE)
		for _, enemyHero in pairs(enemiesNearAlly) do
			if
				Fu.IsValidHero(allyHero)
				and Fu.IsRetreating(allyHero)
				and Fu.GetManaAfter(manaCost) > 0.4
				and allyHero:WasRecentlyDamagedByAnyHero(2)
				and not Fu.IsSuspiciousIllusion(allyHero)
			then
				if
					Fu.IsValidHero(enemyHero)
					and Fu.CanCastOnNonMagicImmune(enemyHero)
					and Fu.IsInRange(bot, enemyHero, castRange)
					and Fu.IsChasingTarget(enemyHero, allyHero)
					and not Fu.IsDisabled(enemyHero)
					and not Fu.IsTaunted(enemyHero)
					and not Fu.IsSuspiciousIllusion(enemyHero)
					and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
					and not enemyHero:HasModifier("modifier_leshrac_lightning_storm_slow")
				then
					return BOT_ACTION_DESIRE_HIGH, enemyHero:GetExtrapolatedLocation(delay + castPoint)
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.ConsiderDiabolicEdict()
	if not diabolicEdictAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
	end
	local radius = diabolicEdictAbility:GetSpecialValueInt("radius")
	local manaCost = diabolicEdictAbility:GetManaCost()
	if isGoingOnSomeone then
		-- No magic-immunity check: Edict pierces it (Valve data: SPELL_IMMUNITY_ENEMIES_YES, pure
		-- damage), so a BKB'd target no longer stops it.
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, radius + 100)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
			and not botTarget:HasModifier("modifier_templar_assassin_refraction_absorb")
		then
			local targetEnemies = Fu.GetNearbyHeroes(botTarget, 1200, true, BOT_MODE_NONE)
			local targetAllies = Fu.GetNearbyHeroes(botTarget, 1200, false, BOT_MODE_NONE)
			if targetEnemies ~= nil and targetAllies ~= nil and #targetEnemies >= #targetAllies then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	if
		Fu.IsFarming(bot)
		and Fu.GetManaAfter(manaCost) > 0.35
		and not bot:HasModifier("modifier_leshrac_pulse_nova")
	then
		local neutralCreeps = bot:GetNearbyNeutralCreeps(radius)
		if
			neutralCreeps ~= nil
			and #neutralCreeps > 0
			and (#neutralCreeps < 3 or #neutralCreeps <= 2 and neutralCreeps[1]:IsAncientCreep())
		then
			return BOT_ACTION_DESIRE_HIGH
		end
		local laneCreeps = bot:GetNearbyLaneCreeps(radius, true)
		if laneCreeps ~= nil and #laneCreeps <= 3 and #laneCreeps > 0 then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsPushing(bot) and Fu.GetManaAfter(manaCost) > 0.25 then
		local enemyTowers = bot:GetNearbyTowers(1000, true)
		local laneCreeps = bot:GetNearbyLaneCreeps(800, true)
		if enemyTowers ~= nil and #enemyTowers >= 1 and laneCreeps ~= nil and #laneCreeps <= 2 then
			bot.edictPushing = true
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if
			Fu.IsRoshan(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, radius)
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, radius) and isAttacking then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderLightningStorm()
	if not lightningStormAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castRange = Fu.GetProperCastRange(false, bot, lightningStormAbility:GetCastRange())
	local damage = lightningStormAbility:GetSpecialValueInt("damage")
	local radius = lightningStormAbility:GetSpecialValueInt("radius")
	local nearbyEnemies = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
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
	if isInTeamFight then
		local enemiesInRange = Fu.GetEnemiesNearLoc(bot:GetLocation(), castRange)
		local weakestTarget = nil
		local lowestHealth = 100000
		for _, enemyHero in pairs(enemiesInRange) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
				and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
				and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
				and not enemyHero:HasModifier("modifier_templar_assassin_refraction_absorb")
				and not enemyHero:HasModifier("modifier_item_sphere_target")
			then
				local enemiesNearTarget = Fu.GetEnemiesNearLoc(enemyHero:GetLocation(), radius)
				local health = enemyHero:GetHealth()
				if enemiesNearTarget ~= nil and #enemiesNearTarget >= 1 and health < lowestHealth then
					lowestHealth = health
					weakestTarget = enemyHero
				end
			end
		end
		if weakestTarget ~= nil then
			return BOT_ACTION_DESIRE_HIGH, weakestTarget
		end
	end
	if isGoingOnSomeone then
		-- Chase and not-disabled requirements dropped: a target stunned by Split Earth or standing to
		-- fight never got Lightning Storm (4s cooldown, damage spell) outside the kill/team-fight cases.
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
			and not botTarget:HasModifier("modifier_templar_assassin_refraction_absorb")
		then
			local nearbyAllies = Fu.GetNearbyHeroes(bot, 1200, false, BOT_MODE_NONE)
			local nearbyEnemyHeroes = Fu.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE)
			if nearbyAllies ~= nil and nearbyEnemyHeroes ~= nil and #nearbyAllies >= #nearbyEnemyHeroes then
				return BOT_ACTION_DESIRE_HIGH, botTarget
			end
		end
	end
	if isRetreating then
		local nearbyEnemyHeroes = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
		for _, enemyHero in pairs(nearbyEnemyHeroes) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.IsChasingTarget(enemyHero, bot)
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and not Fu.IsDisabled(enemyHero)
			then
				local enemyTargets = Fu.GetNearbyHeroes(enemyHero, 1200, true, BOT_MODE_NONE)
				local enemyAllies = Fu.GetNearbyHeroes(enemyHero, 1200, false, BOT_MODE_NONE)
				if
					enemyTargets ~= nil
					and enemyAllies ~= nil
					and (#enemyAllies > #enemyTargets or bot:WasRecentlyDamagedByAnyHero(2))
				then
					return BOT_ACTION_DESIRE_HIGH, enemyHero
				end
			end
		end
	end
	if Fu.IsFarming(bot) and mpRatio > 0.35 then
		local neutralCreeps = bot:GetNearbyNeutralCreeps(castRange)
		if
			neutralCreeps ~= nil and (#neutralCreeps >= 2 or #neutralCreeps >= 1 and neutralCreeps[1]:IsAncientCreep())
		then
			return BOT_ACTION_DESIRE_HIGH, neutralCreeps[1]
		end
		local laneCreeps = bot:GetNearbyLaneCreeps(castRange, true)
		if laneCreeps ~= nil and #laneCreeps >= 2 then
			return BOT_ACTION_DESIRE_HIGH, laneCreeps[1]
		end
	end
	if Fu.IsLaning(bot) then
		local killableCreeps = {}
		local nearbyEnemyHeroes = Fu.GetEnemiesNearLoc(bot:GetLocation(), 1200)
		local laneCreeps = bot:GetNearbyLaneCreeps(castRange, true)
		for _, creep in pairs(laneCreeps) do
			if Fu.IsValid(creep) and creep:GetHealth() <= damage then
				table.insert(killableCreeps, creep)
			end
		end
		if
			mpRatio > 0.25
			and nearbyEnemyHeroes ~= nil
			and #nearbyEnemyHeroes >= 1
			and #killableCreeps >= 2
			and Fu.CanBeAttacked(killableCreeps[1])
		then
			return BOT_ACTION_DESIRE_HIGH, killableCreeps[1]
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if
			Fu.IsRoshan(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and not Fu.IsDisabled(botTarget)
			and not botTarget:HasModifier("modifier_roshan_spell_block")
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, castRange) and isAttacking then
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end
	local nearbyAllyHeroes = Fu.GetNearbyHeroes(bot, castRange, false, BOT_MODE_NONE)
	for _, allyHero in pairs(nearbyAllyHeroes) do
		local enemiesNearAlly = Fu.GetNearbyHeroes(allyHero, 1200, true, BOT_MODE_NONE)
		for _, enemyHero in pairs(enemiesNearAlly) do
			if
				Fu.IsValidHero(allyHero)
				and Fu.IsRetreating(allyHero)
				and mpRatio > 0.45
				and allyHero:WasRecentlyDamagedByAnyHero(1.5)
				and not Fu.IsSuspiciousIllusion(allyHero)
			then
				if
					Fu.IsValidHero(enemyHero)
					and Fu.CanCastOnNonMagicImmune(enemyHero)
					and Fu.IsInRange(bot, enemyHero, castRange)
					and Fu.IsChasingTarget(enemyHero, allyHero)
					and not Fu.IsDisabled(enemyHero)
					and not Fu.IsTaunted(enemyHero)
					and not Fu.IsSuspiciousIllusion(enemyHero)
					and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
				then
					return BOT_ACTION_DESIRE_HIGH, enemyHero
				end
			end
		end
	end
	-- Last: every fight rule above goes first.
	local lastHitCreep = X.GetStormLastHitCreep(castRange, damage, radius)
	if lastHitCreep ~= nil then
		return BOT_ACTION_DESIRE_HIGH, lastHitCreep
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
-- Lightning Storm on a lane creep with spare mana (#143, game 062 ~2:40: Leshrac sat at full mana in lane and
-- never used it on creeps; the laning rule above needs two killable creeps and an enemy hero near). 7.42
-- npc_abilities leshrac_lightning_storm: cooldown 4, mana 80/100/120/140, damage 90/140/190/240 (magical),
-- jump_count 5/7/9/11, radius 450 (jump range), jump_delay 0.25, cast point 0.3, cast range 600.
-- In the laning phase, in laning mode or in team_roam near its own lane front with no hero target (game 062:
-- laning 0.56 <-> team_roam 0.72 every few seconds in lane, [OHA-FLIP] 2:14 and 2:50).
function X.GetStormLastHitCreep(castRange, damage, radius)
	if not Fu.IsInLaningPhase() or isRetreating then
		return nil
	end
	local inLane = Fu.IsLaning(bot)
	if not inLane and bot:GetActiveMode() == BOT_MODE_TEAM_ROAM and not Fu.IsValidHero(botTarget) then
		local assignedLane = bot:GetAssignedLane()
		if assignedLane ~= nil and assignedLane > 0 then
			inLane = GetUnitToLocationDistance(bot, GetLaneFrontLocation(GetTeam(), assignedLane, 0)) <= 1600
		end
	end
	if not inLane then
		return nil
	end
	-- Keep mana for a fight: one more Lightning Storm plus Diabolic Edict and Split Earth once learned.
	local manaCost = lightningStormAbility:GetManaCost()
	local reserve = manaCost
	if diabolicEdictAbility:IsTrained() then
		reserve = reserve + diabolicEdictAbility:GetManaCost()
	end
	if splitEarthAbility:IsTrained() then
		reserve = reserve + splitEarthAbility:GetManaCost()
	end
	local mana = bot:GetMana()
	if not LaneNukeRules.SpareManaForLastHit(mana, bot:GetMaxMana(), manaCost, reserve) then
		return nil
	end
	local castPoint = lightningStormAbility:GetCastPoint()
	local jumpDelay = lightningStormAbility:GetSpecialValueFloat("jump_delay")
	local jumpCount = lightningStormAbility:GetSpecialValueInt("jump_count")
	local attackDamage = bot:GetAttackDamage()
	-- Bounce candidates: creeps up to one jump beyond the cast range.
	local laneCreeps = bot:GetNearbyLaneCreeps(math.min(castRange + radius, 1600), true) or {}
	local bestCreep, bestScore, bestKills = nil, 0, 0
	for _, creep in pairs(laneCreeps) do
		if
			Fu.IsValid(creep)
			and Fu.CanBeAttacked(creep)
			and GetUnitToUnitDistance(bot, creep) <= castRange
			and Fu.WillKillTarget(creep, damage, DAMAGE_TYPE_MAGICAL, castPoint)
		then
			local kills = 1
			for _, other in pairs(laneCreeps) do
				if
					kills < 1 + jumpCount
					and other ~= creep
					and Fu.IsValid(other)
					and GetUnitToUnitDistance(creep, other) <= radius
					and Fu.WillKillTarget(other, damage, DAMAGE_TYPE_MAGICAL, castPoint + jumpDelay)
				then
					kills = kills + 1
				end
			end
			local attackCanKill = creep:GetActualIncomingDamage(attackDamage, DAMAGE_TYPE_PHYSICAL) >= creep:GetHealth()
			local score = LaneNukeRules.LastHitScore(kills, attackCanKill)
			if score > bestScore then
				bestCreep, bestScore, bestKills = creep, score, kills
			end
		end
	end
	if bestCreep == nil then
		return nil
	end
	if DotaTime() >= (bot._stormLastHitLogAt or -999) then
		bot._stormLastHitLogAt = DotaTime() + 3
		-- Checked about 2s later by X.LogStormLastHitResult: did the last-hit count go up?
		bot._stormLastHit = { at = DotaTime(), lastHits = bot:GetLastHits(), kills = bestKills }
		pcall(
			print,
			string.format(
				"[OHA-LESHRAC] t=%.0f leshrac storm-lasthit why=spare-mana mp=%.2f creepHp=%d dmg=%d kills=%d mode=%d",
				DotaTime(),
				mana / math.max(1, bot:GetMaxMana()),
				bestCreep:GetHealth(),
				damage,
				bestKills,
				bot:GetActiveMode()
			)
		)
	end
	return bestCreep
end
-- The effect of a storm-lasthit cast: last hits gained in the ~2s after it (other last hits in that window
-- count too).
function X.LogStormLastHitResult()
	local pending = bot._stormLastHit
	if pending == nil or DotaTime() - pending.at < 2 then
		return
	end
	bot._stormLastHit = nil
	pcall(
		print,
		string.format(
			"[OHA-LESHRAC] t=%.0f leshrac storm-result got=%d expected=%d",
			DotaTime(),
			bot:GetLastHits() - pending.lastHits,
			pending.kills
		)
	)
end
function X.ConsiderPulseNova()
	if not pulseNovaAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
	end
	local radius = pulseNovaAbility:GetSpecialValueInt("radius")
	if isInTeamFight then
		local enemiesInRadius = Fu.GetEnemiesNearLoc(bot:GetLocation(), radius + 150)
		if enemiesInRadius ~= nil and #enemiesInRadius >= 2 then
			if pulseNovaAbility:GetToggleState() == false then
				return BOT_ACTION_DESIRE_HIGH
			else
				if mpRatio < 0.25 and pulseNovaAbility:GetToggleState() == true then
					return BOT_ACTION_DESIRE_HIGH
				end
				return BOT_ACTION_DESIRE_NONE
			end
		end
	end
	if isGoingOnSomeone then
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, radius + 150)
			and not Fu.IsSuspiciousIllusion(botTarget)
		then
			local targetEnemies = Fu.GetNearbyHeroes(botTarget, 1200, true, BOT_MODE_NONE)
			local targetAllies = Fu.GetNearbyHeroes(botTarget, 1200, false, BOT_MODE_NONE)
			if
				targetEnemies ~= nil
				and targetAllies ~= nil
				and #targetEnemies >= #targetAllies
				and (
					#targetAllies >= 1
					or #targetAllies == 0
						and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
						and not botTarget:HasModifier("modifier_templar_assassin_refraction_absorb")
				)
			then
				if pulseNovaAbility:GetToggleState() == false then
					return BOT_ACTION_DESIRE_HIGH
				else
					if mpRatio < 0.25 and pulseNovaAbility:GetToggleState() == true then
						return BOT_ACTION_DESIRE_HIGH
					end
					return BOT_ACTION_DESIRE_NONE
				end
			end
		end
	end
	if Fu.IsPushing(bot) or Fu.IsDefending(bot) then
		local laneCreeps = bot:GetNearbyLaneCreeps(radius, true)
		if laneCreeps ~= nil then
			if #laneCreeps >= 1 and pulseNovaAbility:GetToggleState() == false and isAttacking and mpRatio > 0.5 then
				return BOT_ACTION_DESIRE_HIGH
			else
				if (#laneCreeps == 0 or mpRatio < 0.25) and pulseNovaAbility:GetToggleState() == true then
					return BOT_ACTION_DESIRE_HIGH
				end
				return BOT_ACTION_DESIRE_NONE
			end
		end
	end
	if Fu.IsFarming(bot) then
		local neutralCreeps = bot:GetNearbyNeutralCreeps(radius)
		if
			neutralCreeps ~= nil and (#neutralCreeps >= 3 or #neutralCreeps >= 2 and neutralCreeps[1]:IsAncientCreep())
		then
			if #neutralCreeps >= 3 and pulseNovaAbility:GetToggleState() == false and isAttacking and mpRatio > 0.5 then
				return BOT_ACTION_DESIRE_HIGH
			else
				if (#neutralCreeps == 0 or mpRatio < 0.25) and pulseNovaAbility:GetToggleState() == true then
					return BOT_ACTION_DESIRE_HIGH
				end
				return BOT_ACTION_DESIRE_NONE
			end
		end
		local laneCreeps = bot:GetNearbyLaneCreeps(radius, true)
		if laneCreeps ~= nil then
			if #laneCreeps >= 3 and pulseNovaAbility:GetToggleState() == false and isAttacking and mpRatio > 0.5 then
				return BOT_ACTION_DESIRE_HIGH
			else
				if (#laneCreeps == 0 or mpRatio < 0.25) and pulseNovaAbility:GetToggleState() == true then
					return BOT_ACTION_DESIRE_HIGH
				end
				return BOT_ACTION_DESIRE_NONE
			end
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if
			Fu.IsRoshan(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, radius)
			and isAttacking
		then
			if pulseNovaAbility:GetToggleState() == false and mpRatio > 0.7 then
				return BOT_ACTION_DESIRE_HIGH
			else
				if mpRatio < 0.25 and pulseNovaAbility:GetToggleState() == true then
					return BOT_ACTION_DESIRE_HIGH
				end
				return BOT_ACTION_DESIRE_NONE
			end
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, radius) and isAttacking then
			if pulseNovaAbility:GetToggleState() == false and mpRatio > 0.75 then
				return BOT_ACTION_DESIRE_HIGH
			else
				if mpRatio < 0.25 and pulseNovaAbility:GetToggleState() == true then
					return BOT_ACTION_DESIRE_HIGH
				end
				return BOT_ACTION_DESIRE_NONE
			end
		end
	end
	if pulseNovaAbility:GetToggleState() == true then
		local nearbyEnemyHeroes = Fu.GetNearbyHeroes(bot, radius + 220, true, BOT_MODE_NONE)
		if #nearbyEnemyHeroes <= 0 then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderNihilism()
	if not nihilismAbility:IsTrained() or not nihilismAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
	end
	local radius = nihilismAbility:GetSpecialValueInt("radius")
	-- 7.42 (Valve patch notes): Nihilism no longer makes Leshrac ethereal. The old rule "cast when the
	-- incoming attack projectiles would kill him" relied on that, so it is gone; the cast now disarms
	-- enemies within the radius (4s) and dispels him, which the retreat and fight rules below use.
	if isRetreating then
		local enemiesInRadius = Fu.GetEnemiesNearLoc(bot:GetLocation(), radius)
		if bot:WasRecentlyDamagedByAnyHero(2) and enemiesInRadius ~= nil and #enemiesInRadius >= 1 then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	-- Fights: Nihilism disarms the enemies within the radius for 4s (7.42; it was an ethereal escape
	-- before, which is why it once waited for "no ally nearby": ethereal enemies could not be hit by
	-- allies either). A disarm does not block allies, so now (1) in a fight while heroes hit him below
	-- 60% HP, and (2) going on a target within the radius, with or without allies near.
	if isGoingOnSomeone or isInTeamFight then
		local enemiesInRadius = Fu.GetEnemiesNearLoc(bot:GetLocation(), radius)
		local enemiesHit = 0
		for _, enemyHero in pairs(enemiesInRadius) do
			if
				Fu.IsValidHero(enemyHero)
				and not enemyHero:IsMagicImmune()
				and not Fu.IsSuspiciousIllusion(enemyHero)
			then
				enemiesHit = enemiesHit + 1
			end
		end
		if enemiesHit >= 1 then
			local castReason = nil
			if bot:WasRecentlyDamagedByAnyHero(1.5) and Fu.GetHP(bot) < 0.6 then
				castReason = "defend"
			elseif
				isGoingOnSomeone
				and Fu.IsValidHero(botTarget)
				and Fu.IsInRange(bot, botTarget, radius)
				and not botTarget:IsMagicImmune()
			then
				castReason = "engage"
			end
			if castReason ~= nil then
				if DotaTime() >= (bot._nihilLogAt or -999) then
					bot._nihilLogAt = DotaTime() + 5
					pcall(
						print,
						string.format("[OHA-LESHRAC] t=%.0f nihilism %s enemies=%d", DotaTime(), castReason, enemiesHit)
					)
				end
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
return X
