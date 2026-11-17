-- Night Stalker: skill build, item build, and ability use for this hero.
local X = {}
local bot = GetBot()
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local AbilityContext = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local Minion = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local sTalentList = Fu.Skill.GetTalentList(bot)
local sAbilityList = Fu.Skill.GetAbilityList(bot)
local sRole = Fu.Item.GetRoleItemsBuyList(bot)
local tTalentTreeList = { ["t25"] = { 10, 0 }, ["t20"] = { 10, 0 }, ["t15"] = { 0, 10 }, ["t10"] = { 10, 0 } }
local tAllAbilityBuildList = { { 1, 2, 1, 3, 1, 6, 1, 3, 3, 3, 6, 2, 2, 2, 6 } }
local nAbilityBuildList = Fu.Skill.GetRandomBuild(tAllAbilityBuildList)
local nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList)
local sTeamAuraItem = "item_team_aura"
local sRoleItemsBuyList = {}
sRoleItemsBuyList["pos_3"] = {
	"item_tango",
	"item_double_branches",
	"item_quelling_blade",
	"item_double_gauntlets",
	"item_magic_wand",
	"item_double_bracer",
	"item_phase_boots",
	"item_echo_sabre",
	"item_blink",
	"item_aghanims_shard",
	"item_black_king_bar",
	-- Harpoon (Echo Sabre upgrade): 41% of his matches, #6 (Dotabuff, last patch).
	"item_harpoon",
	sTeamAuraItem,
	"item_basher",
	"item_assault",
	"item_abyssal_blade",
	"item_overwhelming_blink",
	"item_travel_boots_2",
	"item_moon_shard",
	"item_ultimate_scepter_2",
}
sRoleItemsBuyList["pos_1"] = sRoleItemsBuyList["pos_3"]
sRoleItemsBuyList["pos_2"] = sRoleItemsBuyList["pos_3"]
sRoleItemsBuyList["pos_4"] = {
	"item_priest_outfit",
	"item_hand_of_midas",
	"item_mekansm",
	"item_glimmer_cape",
	"item_aghanims_shard",
	"item_guardian_greaves",
	"item_spirit_vessel",
	"item_lotus_orb",
	"item_mjollnir",
	"item_ultimate_scepter",
	"item_sheepstick",
	"item_mystic_staff",
	"item_ultimate_scepter_2",
	"item_shivas_guard",
	"item_moon_shard",
}
sRoleItemsBuyList["pos_5"] = {
	"item_mage_outfit",
	"item_hand_of_midas",
	"item_glimmer_cape",
	"item_pavise",
	"item_pipe",
	"item_solar_crest",
	"item_lotus_orb",
	"item_aghanims_shard",
	"item_spirit_vessel",
	"item_ultimate_scepter",
	"item_shivas_guard",
	"item_mystic_staff",
	"item_ultimate_scepter_2",
	"item_moon_shard",
	"item_sheepstick",
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
function X.MinionThink(hMinionUnit)
	Minion.MinionThink(hMinionUnit)
end
local voidAbility = SafeAbility(bot:GetAbilityByName("night_stalker_void"), "night_stalker_void", "night_stalker")
local cripplingFearAbility =
	SafeAbility(bot:GetAbilityByName("night_stalker_crippling_fear"), "night_stalker_crippling_fear", "night_stalker")
local hunterInTheNightAbility = SafeAbility(
	bot:GetAbilityByName("night_stalker_hunter_in_the_night"),
	"night_stalker_hunter_in_the_night",
	"night_stalker"
)
local midnightFeastAbility =
	SafeAbility(bot:GetAbilityByName("night_stalker_midnight_feast"), "night_stalker_midnight_feast", "night_stalker")
local darknessAbility =
	SafeAbility(bot:GetAbilityByName("night_stalker_darkness"), "night_stalker_darkness", "night_stalker")
local voidDesire, voidTarget
local cripplingFearDesire
local hunterInTheNightDesire, hunterInTheNightTarget
local midnightFeastDesire, midnightFeastTarget
local darkAscensionDesire
local botTarget
local isGoingOnSomeone
local isAttacking
local mpRatio
local isInTeamFight
function X.SkillsComplement()
	if Fu.CanNotUseAbility(bot) then
		return
	end
	isGoingOnSomeone = Fu.IsGoingOnSomeone(bot)
	isAttacking = Fu.IsAttacking(bot)
	mpRatio = Fu.GetMP(bot)
	isInTeamFight = Fu.IsInTeamFight(bot, 1200)
	darkAscensionDesire = X.ConsiderDarkAscension()
	if darkAscensionDesire > 0 then
		-- Noted for Void: Dark Ascension makes night (datafeed), which the clock check cannot see.
		bot._nsDarkAt = DotaTime()
		bot:Action_UseAbility(darknessAbility)
		return
	end
	cripplingFearDesire = X.ConsiderCripplingFear()
	if cripplingFearDesire > 0 then
		bot:Action_UseAbility(cripplingFearAbility)
		return
	end
	voidDesire, voidTarget = X.ConsiderVoid()
	if voidDesire > 0 then
		-- datafeed: Void is unit-target only (behavior 8); the Shard adds its AoE around the target and the
		-- Scepter belongs to Hunter in the Night, so the old Scepter "cast on a point" path failed once he had one.
		bot:Action_UseAbilityOnEntity(voidAbility, voidTarget)
		return
	end
	hunterInTheNightDesire, hunterInTheNightTarget = X.ConsiderHunterInTheNight()
	if hunterInTheNightDesire > 0 then
		bot:Action_UseAbilityOnEntity(hunterInTheNightAbility, hunterInTheNightTarget)
		return
	end
	midnightFeastDesire, midnightFeastTarget = X.ConsiderMidnightFeast()
	if midnightFeastDesire > 0 then
		bot:Action_UseAbilityOnEntity(midnightFeastAbility, midnightFeastTarget)
		return
	end
end
function X.ConsiderVoid()
	if not voidAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castRange = voidAbility:GetCastRange()
	local castPoint = voidAbility:GetCastPoint()
	local radius = 450
	local damage = voidAbility:GetSpecialValueInt("damage")
	local duration = voidAbility:GetSpecialValueFloat("duration_day")
	local timeOfDay = Fu.CheckTimeOfDay()
	botTarget = Fu.GetProperTarget(bot)
	if timeOfDay == "night" then
		duration = voidAbility:GetSpecialValueFloat("duration_night")
	end
	local nearbyEnemies = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and not Fu.IsSuspiciousIllusion(enemyHero)
		then
			-- Void returns a unit everywhere below (unit-target per datafeed; no Scepter point-cast)
			-- Interrupt only at night: Void mini-stuns only then (datafeed, "At night, Void also
			-- mini-stuns, interrupting channeling abilities"). "a or b and night" let any channel through
			-- by day, where Void does not stop it. Night here also counts the 30s after Dark Ascension.
			local darkUntil = (bot._nsDarkAt or -999)
				+ math.max(darknessAbility:GetSpecialValueFloat("duration"), 0)
				+ 0.5
			local isNight = timeOfDay == "night" or DotaTime() < darkUntil
			if (enemyHero:IsChanneling() or Fu.IsCastingUltimateAbility(enemyHero)) and isNight then
				return BOT_ACTION_DESIRE_HIGH, enemyHero
			end
			if
				Fu.CanKillTarget(enemyHero, damage, DAMAGE_TYPE_MAGICAL)
				and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
				and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
				and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
				and not enemyHero:HasModifier("modifier_templar_assassin_refraction_absorb")
			then
				return BOT_ACTION_DESIRE_HIGH, enemyHero
			end
		end
	end
	if isInTeamFight then
		local strongestEnemy = Fu.GetStrongestUnit(castRange, bot, true, false, duration)
		if strongestEnemy == nil then
			strongestEnemy = Fu.GetStrongestUnit(castRange, bot, true, true, duration)
		end
		if
			Fu.IsValidTarget(strongestEnemy)
			and Fu.CanCastOnNonMagicImmune(strongestEnemy)
			and not Fu.IsSuspiciousIllusion(strongestEnemy)
			and not Fu.IsDisabled(strongestEnemy)
			and not Fu.IsTaunted(strongestEnemy)
			and not strongestEnemy:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			return BOT_ACTION_DESIRE_HIGH, strongestEnemy
		end
	end
	if isGoingOnSomeone then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, 800, false, BOT_MODE_NONE)
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not Fu.IsDisabled(botTarget)
			and not Fu.IsTaunted(botTarget)
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
			and not botTarget:HasModifier("modifier_templar_assassin_refraction_absorb")
		then
			local enemiesNearTarget = Fu.GetNearbyHeroes(botTarget, 800, false, BOT_MODE_NONE)
			if nearbyAllies ~= nil and enemiesNearTarget ~= nil and #nearbyAllies >= #enemiesNearTarget then
				return BOT_ACTION_DESIRE_HIGH, botTarget
			end
		end
	end
	if Fu.IsRetreating(bot) then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, 800, false, BOT_MODE_NONE)
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, 800, true, BOT_MODE_NONE)
		if
			nearbyAllies ~= nil
			and nearbyEnemies
			and Fu.IsValidHero(nearbyEnemies[1])
			and Fu.CanCastOnNonMagicImmune(nearbyEnemies[1])
			and Fu.IsRunning(nearbyEnemies[1])
			and nearbyEnemies[1]:IsFacingLocation(bot:GetLocation(), 30)
			and not Fu.IsSuspiciousIllusion(nearbyEnemies[1])
		then
			local enemiesNearChaser = Fu.GetNearbyHeroes(nearbyEnemies[1], 800, false, BOT_MODE_NONE)
			if
				enemiesNearChaser ~= nil
				and (#enemiesNearChaser > #nearbyAllies or Fu.GetHP(bot) < 0.52 and bot:WasRecentlyDamagedByAnyHero(2))
			then
				return BOT_ACTION_DESIRE_HIGH, nearbyEnemies[1]
			end
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if
			Fu.IsRoshan(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, 500)
			and isAttacking
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, 400) and isAttacking then
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end
	local alliesInRange = Fu.GetNearbyHeroes(bot, castRange, false, BOT_MODE_NONE)
	for _, allyHero in pairs(alliesInRange) do
		local enemiesNearAlly = Fu.GetNearbyHeroes(allyHero, castRange, true, BOT_MODE_NONE)
		if
			Fu.IsRetreating(allyHero)
			and allyHero:WasRecentlyDamagedByAnyHero(2.1)
			and not allyHero:IsIllusion()
			and mpRatio > 0.5
		then
			if
				enemiesNearAlly ~= nil
				and #enemiesNearAlly >= 1
				and Fu.IsValidHero(enemiesNearAlly[1])
				and Fu.CanCastOnNonMagicImmune(enemiesNearAlly[1])
				and Fu.IsInRange(allyHero, enemiesNearAlly[1], 400)
				and Fu.IsInRange(bot, enemiesNearAlly[1], castRange)
				and Fu.IsRunning(allyHero)
				and enemiesNearAlly[1]:IsFacingLocation(allyHero:GetLocation(), 30)
				and not Fu.IsDisabled(enemiesNearAlly[1])
				and not Fu.IsTaunted(enemiesNearAlly[1])
				and not Fu.IsSuspiciousIllusion(enemiesNearAlly[1])
				and not enemiesNearAlly[1]:HasModifier("modifier_enigma_black_hole_pull")
				and not enemiesNearAlly[1]:HasModifier("modifier_faceless_void_chronosphere_freeze")
			then
				-- the non-Scepter path returned botTarget (own target) here instead of enemiesNearAlly[1], the enemy chasing that ally
				return BOT_ACTION_DESIRE_HIGH, enemiesNearAlly[1]
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function X.ConsiderCripplingFear()
	if not cripplingFearAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
	end
	local radius = cripplingFearAbility:GetSpecialValueInt("radius")
	botTarget = Fu.GetProperTarget(bot)
	if isInTeamFight then
		-- Enemies near enough to be silenced: Crippling Fear only works on enemies near him (datafeed,
		-- radius 350, game data). radius * 2 started the timed effect with both enemies 700 away.
		local nearbyEnemies = Fu.GetEnemiesNearLoc(bot:GetLocation(), radius + 150)
		if nearbyEnemies ~= nil and #nearbyEnemies >= 2 then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if isGoingOnSomeone then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, 800, false, BOT_MODE_NONE)
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, radius + 150)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not Fu.IsDisabled(botTarget)
			and not Fu.IsTaunted(botTarget)
		then
			local enemiesNearTarget = Fu.GetNearbyHeroes(botTarget, 800, false, BOT_MODE_NONE)
			if nearbyAllies ~= nil and enemiesNearTarget ~= nil and #nearbyAllies >= #enemiesNearTarget then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	if Fu.IsPushing(bot) or Fu.IsDefending(bot) then
		local nearbyLaneCreeps = bot:GetNearbyLaneCreeps(radius, true)
		if isAttacking and nearbyLaneCreeps ~= nil and #nearbyLaneCreeps >= 4 then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsFarming(bot) and mpRatio > 0.25 then
		if isAttacking then
			local nearbyNeutrals = bot:GetNearbyNeutralCreeps(radius)
			if
				nearbyNeutrals ~= nil
				and (#nearbyNeutrals >= 3 or #nearbyNeutrals >= 2 and nearbyNeutrals[1]:IsAncientCreep())
			then
				return BOT_ACTION_DESIRE_HIGH
			end
			local nearbyLaneCreeps = bot:GetNearbyLaneCreeps(radius, true)
			if nearbyLaneCreeps ~= nil and #nearbyLaneCreeps >= 3 then
				return BOT_ACTION_DESIRE_HIGH
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
function X.ConsiderHunterInTheNight()
	if hunterInTheNightAbility:IsPassive() or not hunterInTheNightAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	-- datafeed has no "shard_cast_range" on Hunter in the Night (it read 0, so no creep was ever found);
	-- fall back to the engine cast range for the Shard cast
	local castRange =
		math.max(hunterInTheNightAbility:GetSpecialValueInt("shard_cast_range"), hunterInTheNightAbility:GetCastRange())
	local timeOfDay = Fu.CheckTimeOfDay()
	if Fu.IsFarming(bot) then
		local nearbyCreeps = bot:GetNearbyCreeps(castRange, true)
		if nearbyCreeps ~= nil and #nearbyCreeps >= 1 then
			if
				Fu.IsValid(nearbyCreeps[1])
				and (not nearbyCreeps[1]:IsAncientCreep() or timeOfDay == "night" and nearbyCreeps[1]:IsAncientCreep())
				and (Fu.GetHP(bot) < 0.65 or mpRatio < 0.5)
			then
				return BOT_ACTION_DESIRE_HIGH, nearbyCreeps[1]
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function X.ConsiderDarkAscension()
	if not darknessAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
	end
	botTarget = Fu.GetProperTarget(bot)
	if isInTeamFight then
		local nearbyEnemies = Fu.GetEnemiesNearLoc(bot:GetLocation(), 1000)
		if nearbyEnemies ~= nil and #nearbyEnemies >= 2 then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if isGoingOnSomeone then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, 800, false, BOT_MODE_NONE)
		if
			Fu.IsValidTarget(botTarget)
			and Fu.IsInRange(bot, botTarget, 600)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not botTarget:HasModifier("modifier_dazzle_shallow_grave")
			and not botTarget:HasModifier("modifier_enigma_black_hole_pull")
			and not botTarget:HasModifier("modifier_faceless_void_chronosphere_freeze")
			and not botTarget:HasModifier("modifier_legion_commander_duel")
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
			and not botTarget:HasModifier("modifier_templar_assassin_refraction_absorb")
		then
			local enemiesNearTarget = Fu.GetNearbyHeroes(botTarget, 800, false, BOT_MODE_NONE)
			if nearbyAllies ~= nil and enemiesNearTarget ~= nil and #nearbyAllies >= #enemiesNearTarget then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
-- Midnight Feast (datafeed): heals on attacks; "At night, the ability can be activated to instantly destroy a
-- non-ancient creep and restore a percentage of Night Stalker's maximum health and mana" (10/15/20/25% HP,
-- 10/12/14/16% mana, cooldown 39/36/33/30, range 125, no mana cost). The game file lists it as PASSIVE, so the
-- old Fu.CanCastAbility (rejects IsPassive) may never have let it through. We now try it only at night, at most
-- once per 3s, and log whether the previous try started the cooldown (an order refused by the engine would not).
local feastTryAt, feastTryCd, feastGold = -999, nil, nil
local function FeastIsNight()
	local darkUntil = (bot._nsDarkAt or -999) + math.max(darknessAbility:GetSpecialValueFloat("duration"), 0)
	return Fu.CheckTimeOfDay() == "night" or DotaTime() < darkUntil
end
-- Lane, siege and neutral creeps only (not summons, couriers or ancients: "non-ancient creep").
local function IsFeastCreep(creep)
	if not Fu.IsValid(creep) or not Fu.CanBeAttacked(creep) or creep:IsAncientCreep() or creep:IsDominated() then
		return false
	end
	local unitName = creep:GetUnitName() or ""
	return string.find(unitName, "creep", 1, true) ~= nil
		or string.find(unitName, "neutral", 1, true) ~= nil
		or string.find(unitName, "siege", 1, true) ~= nil
end
-- Highest level, then highest max HP creep in range (same rule as Midas and Devour).
local function BestFeastCreep(range)
	local list = {}
	for _, creep in pairs(bot:GetNearbyCreeps(range, true) or {}) do
		if IsFeastCreep(creep) then
			list[#list + 1] = creep
		end
	end
	return Fu.GetBestCreepToEat(list, nil, false)
end
function X.ConsiderMidnightFeast()
	local now = DotaTime()
	-- Did the last try start the cooldown? Logs the gold change once so we learn if eating gives bounty.
	if feastTryCd ~= nil and now - feastTryAt > 1 then
		local cdNow = midnightFeastAbility:GetCooldownTimeRemaining()
		print(
			string.format(
				"[OHA-NS] feast result started=%s goldDelta=%d",
				tostring(cdNow > 0),
				bot:GetGold() - (feastGold or bot:GetGold())
			)
		)
		feastTryCd, feastGold = nil, nil
	end
	if
		midnightFeastAbility == nil
		or midnightFeastAbility:IsNull()
		or not midnightFeastAbility:IsTrained()
		or midnightFeastAbility:IsHidden()
		or not midnightFeastAbility:IsActivated()
		or midnightFeastAbility:GetCooldownTimeRemaining() > 0
		or now - feastTryAt < 3
		or not FeastIsNight()
		or Fu.IsRetreating(bot)
			and Fu.IsRealInvisible(bot)
			and #Fu.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE) > 0
	then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local hp = Fu.GetHP(bot)
	local enemies = Fu.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE)
	local nEnemies = enemies ~= nil and #enemies or 0
	local why, creep = nil, nil
	-- Heal: HP under 75% or mana under 50% (no mana cost, 30-39s cooldown, so no need to wait for 50% HP).
	-- Only a creep next to him while heroes are around.
	if hp < 0.75 or mpRatio < 0.5 then
		creep = BestFeastCreep(nEnemies > 0 and 300 or 600)
		why = "heal"
	end
	-- Farm: no enemy hero near, use it on cooldown like Devour / Midas (it also tops up HP and mana).
	if
		creep == nil
		and nEnemies == 0
		and (Fu.IsFarming(bot) or Fu.IsLaning(bot) or Fu.IsPushing(bot) or hp < 0.9 or mpRatio < 0.9)
	then
		creep = BestFeastCreep(450)
		why = "farm"
	end
	if creep ~= nil and Fu.CanCastOnTargetAdvanced(creep) then
		feastTryAt, feastTryCd, feastGold = now, midnightFeastAbility:GetCooldownTimeRemaining(), bot:GetGold()
		print(
			string.format(
				"[OHA-NS] feast try why=%s creep=%s passive=%s castable=%s hp=%.2f mp=%.2f",
				why,
				creep:GetUnitName(),
				tostring(midnightFeastAbility:IsPassive()),
				tostring(midnightFeastAbility:IsFullyCastable()),
				hp,
				mpRatio
			)
		)
		return BOT_ACTION_DESIRE_HIGH, creep
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
return X
