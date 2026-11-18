-- Beastmaster: skill build, item build, and ability use for this hero.
-- Accidental globals made file-local (#13): every bot shares one Lua state, so these were shared.
local HasBlink, CanBKB
local X = {}
local bot = GetBot()
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local AbilityContext = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local Minion = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local sTalentList = Fu.Skill.GetTalentList(bot)
local sAbilityList = Fu.Skill.GetAbilityList(bot)
local sRole = Fu.Item.GetRoleItemsBuyList(bot)
local tTalentTreeList = { ["t25"] = { 10, 0 }, ["t20"] = { 10, 0 }, ["t15"] = { 0, 10 }, ["t10"] = { 10, 0 } }
local tAllAbilityBuildList = { { 1, 2, 2, 1, 1, 6, 1, 2, 2, 3, 6, 3, 3, 3, 6 } }
local nAbilityBuildList = tAllAbilityBuildList[1]
local nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList)
local sRoleItemsBuyList = {}
sRoleItemsBuyList["pos_1"] = {
	"item_bristleback_outfit",
	"item_ultimate_scepter",
	"item_echo_sabre",
	"item_harpoon",
	"item_assault",
	"item_black_king_bar",
	"item_blink",
	"item_abyssal_blade",
	"item_aghanims_shard",
	"item_travel_boots",
	"item_overwhelming_blink",
	"item_moon_shard",
	"item_ultimate_scepter_2",
	"item_travel_boots_2",
}
sRoleItemsBuyList["pos_2"] = {
	"item_double_branches",
	"item_tango",
	"item_faerie_fire",
	"item_bottle",
	"item_magic_wand",
	"item_power_treads",
	"item_ultimate_scepter",
	"item_echo_sabre",
	"item_harpoon",
	"item_black_king_bar",
	"item_blink",
	"item_travel_boots",
	"item_assault",
	"item_abyssal_blade",
	"item_aghanims_shard",
	"item_overwhelming_blink",
	"item_moon_shard",
	"item_ultimate_scepter_2",
	"item_travel_boots_2",
}
sRoleItemsBuyList["pos_3"] = {
	"item_tank_outfit",
	"item_helm_of_the_dominator",
	"item_helm_of_the_overlord",
	"item_ultimate_scepter",
	"item_blink",
	"item_black_king_bar",
	"item_aghanims_shard",
	"item_travel_boots",
	"item_assault",
	"item_heart",
	"item_overwhelming_blink",
	"item_moon_shard",
	"item_refresher",
	"item_ultimate_scepter_2",
	"item_travel_boots_2",
}
sRoleItemsBuyList["pos_4"] = {
	"item_priest_outfit",
	"item_hand_of_midas",
	"item_ultimate_scepter",
	"item_mekansm",
	"item_blink",
	"item_guardian_greaves",
	"item_aghanims_shard",
	"item_lotus_orb",
	"item_gungir",
	"item_sheepstick",
	"item_mystic_staff",
	"item_ultimate_scepter_2",
	"item_shivas_guard",
	"item_moon_shard",
	"item_overwhelming_blink",
}
sRoleItemsBuyList["pos_5"] = {
	"item_mage_outfit",
	"item_hand_of_midas",
	"item_glimmer_cape",
	"item_pavise",
	"item_ultimate_scepter",
	"item_pipe",
	"item_blink",
	"item_solar_crest",
	"item_lotus_orb",
	"item_aghanims_shard",
	"item_shivas_guard",
	"item_mystic_staff",
	"item_ultimate_scepter_2",
	"item_moon_shard",
	"item_sheepstick",
	"item_overwhelming_blink",
}
X["sBuyList"] = sRoleItemsBuyList[sRole]
X["sSellList"] = {
	"item_assault",
	"item_quelling_blade",
	"item_abyssal_blade",
	"item_magic_wand",
	"item_black_king_bar",
	"item_magic_wand",
}
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
local wildAxesAbility =
	SafeAbility(bot:GetAbilityByName("beastmaster_wild_axes"), "beastmaster_wild_axes", "beastmaster")
local summonRazorbackAbility = SafeAbility(
	bot:GetAbilityByName("beastmaster_summon_razorback"),
	"beastmaster_summon_razorback",
	"beastmaster"
) or sAbilityList[2] and SafeAbility(bot:GetAbilityByName(sAbilityList[2]), "sAbilityList[2]", "beastmaster")
local summonRaptorAbility = SafeAbility(
	bot:GetAbilityByName("beastmaster_summon_raptor"),
	"beastmaster_summon_raptor",
	"beastmaster"
) or sAbilityList[3] and SafeAbility(bot:GetAbilityByName(sAbilityList[3]), "sAbilityList[3]", "beastmaster")
local primalRoarAbility =
	SafeAbility(bot:GetAbilityByName("beastmaster_primal_roar"), "beastmaster_primal_roar", "beastmaster")
local wildAxesDesire, wildAxesLocation
local summonRazorbackDesire
local summonRaptorDesire
local primalRoarDesire, primalRoarTarget
local innerBeastDesire
local bkbItem
local blinkItem
local blinkLocation
local blinkRoarDesire, blinkRoarTarget
local botTarget
local hpRatio
if bot.shouldBlink == nil then
	bot.shouldBlink = false
end
local isGoingOnSomeone
local isAttacking
local isInTeamFight
-- fix: these helpers were globals; Batrider defines globals with the same names (HasBlink, CanBKB),
-- so if both bots share globals one hero's checks read the other's items. Forward-declared
-- locals: the "function X()" definitions at the bottom now assign these.
local CanDoBlinkRoar, HasBlink, CanBKB
function X.SkillsComplement()
	local context = AbilityContext.Build(bot)
	isGoingOnSomeone = context.isEngaging
	isAttacking = Fu.IsAttacking(bot)
	isInTeamFight = context.isTeamFight
	if Fu.CanNotUseAbility(bot) then
		return
	end
	wildAxesAbility = SafeAbility(bot:GetAbilityByName("beastmaster_wild_axes"), "beastmaster_wild_axes", "beastmaster")
	summonRazorbackAbility = SafeAbility(
		bot:GetAbilityByName("beastmaster_summon_razorback"),
		"beastmaster_summon_razorback",
		"beastmaster"
	) or sAbilityList[2] and SafeAbility(bot:GetAbilityByName(sAbilityList[2]), "sAbilityList[2]", "beastmaster")
	summonRaptorAbility = SafeAbility(
		bot:GetAbilityByName("beastmaster_summon_raptor"),
		"beastmaster_summon_raptor",
		"beastmaster"
	) or sAbilityList[3] and SafeAbility(bot:GetAbilityByName(sAbilityList[3]), "sAbilityList[3]", "beastmaster")
	primalRoarAbility =
		SafeAbility(bot:GetAbilityByName("beastmaster_primal_roar"), "beastmaster_primal_roar", "beastmaster")
	botTarget = context.target
	hpRatio = context.hp
	blinkRoarDesire, blinkRoarTarget = X.ConsiderBlinkRoar()
	if blinkRoarDesire > 0 then
		bot:Action_ClearActions(false)
		if CanBKB() then
			bot:ActionQueue_UseAbility(bkbItem)
			bot:ActionQueue_Delay(0.1)
		end
		bot:ActionQueue_UseAbilityOnLocation(blinkItem, blinkLocation)
		bot:ActionQueue_Delay(0.1)
		bot:ActionQueue_UseAbilityOnEntity(primalRoarAbility, blinkRoarTarget)
		return
	end
	primalRoarDesire, primalRoarTarget = X.ConsiderPrimalRoar()
	if primalRoarDesire > 0 then
		bot:Action_UseAbilityOnEntity(primalRoarAbility, primalRoarTarget)
		return
	end
	summonRazorbackDesire = X.ConsiderCallOfTheWildBoar()
	if summonRazorbackDesire > 0 then
		bot:Action_UseAbility(summonRazorbackAbility)
		return
	end
	summonRaptorDesire = X.ConsiderCallOfTheWildHawk()
	if summonRaptorDesire > 0 then
		bot:Action_UseAbility(summonRaptorAbility)
		return
	end
	wildAxesDesire, wildAxesLocation = X.ConsiderWildAxes()
	if wildAxesDesire > 0 then
		bot:Action_UseAbilityOnLocation(wildAxesAbility, wildAxesLocation)
		return
	end
end
function X.ConsiderInnerBeast()
	return BOT_ACTION_DESIRE_NONE, 0
end
local function canReincarnate(hero)
	if Fu.IsHaveAegis(hero) then
		return true
	end
	if hero:HasModifier("modifier_skeleton_king_reincarnation") then
		return true
	end
	return false
end
function X.ConsiderWildAxes()
	if not wildAxesAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local castRange = wildAxesAbility:GetCastRange()
	local castPoint = wildAxesAbility:GetCastPoint()
	local manaCost = wildAxesAbility:GetManaCost()
	local manaRatio = bot:GetMana() / bot:GetMaxMana()
	local radius = wildAxesAbility:GetSpecialValueInt("radius")
	local damage = wildAxesAbility:GetSpecialValueInt("axe_damage")
	local enemiesInRange = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(enemiesInRange) do
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
			return BOT_ACTION_DESIRE_HIGH, enemyHero:GetExtrapolatedLocation(castPoint)
		end
	end
	if Fu.IsInTeamFight(bot, castRange) then
		local aoeLocation = bot:FindAoELocation(true, true, bot:GetLocation(), castRange, radius, castPoint, 0)
		if aoeLocation.count >= 2 then
			local enemiesNearAoe = Fu.GetEnemiesNearLoc(aoeLocation.targetloc, radius)
			if enemiesNearAoe ~= nil and #enemiesNearAoe >= 2 then
				return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
			end
		end
	end
	if isGoingOnSomeone then
		local alliesNearby = Fu.GetNearbyHeroes(bot, 1000, false, BOT_MODE_NONE)
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not botTarget:HasModifier("modifier_dazzle_shallow_grave")
			and not botTarget:HasModifier("modifier_templar_assassin_refraction_absorb")
		then
			local enemiesNearTarget = Fu.GetNearbyHeroes(botTarget, 1000, false, BOT_MODE_NONE)
			if alliesNearby ~= nil and enemiesNearTarget ~= nil and #alliesNearby >= #enemiesNearTarget then
				local axesLocation = Fu.VectorAway(botTarget:GetLocation(), bot:GetLocation(), 350)
				return BOT_ACTION_DESIRE_HIGH, axesLocation
			end
		end
	end
	if Fu.IsRetreating(bot) then
		local alliesNearby = Fu.GetNearbyHeroes(bot, 800, false, BOT_MODE_NONE)
		local enemiesNearby = Fu.GetNearbyHeroes(bot, 800, true, BOT_MODE_NONE)
		if
			alliesNearby ~= nil
			and enemiesNearby
			and Fu.IsValidHero(enemiesNearby[1])
			and Fu.CanCastOnNonMagicImmune(enemiesNearby[1])
			and Fu.IsInRange(bot, enemiesNearby[1], 600)
			and Fu.IsRunning(enemiesNearby[1])
			and enemiesNearby[1]:IsFacingLocation(bot:GetLocation(), 30)
			and not Fu.IsSuspiciousIllusion(enemiesNearby[1])
		then
			local enemiesNearTarget = Fu.GetNearbyHeroes(enemiesNearby[1], 800, false, BOT_MODE_NONE)
			if
				enemiesNearTarget ~= nil
				and (#enemiesNearTarget > #alliesNearby or hpRatio < 0.57 and bot:WasRecentlyDamagedByAnyHero(2.7))
			then
				return BOT_ACTION_DESIRE_HIGH, enemiesNearby[1]:GetExtrapolatedLocation(castPoint)
			end
		end
	end
	if Fu.IsPushing(bot) or Fu.IsDefending(bot) then
		if Fu.GetManaAfter(manaCost) < 0.3 then
			return BOT_ACTION_DESIRE_NONE, 0
		end
		local aoeLocation = bot:FindAoELocation(true, false, bot:GetLocation(), castRange, radius, castPoint, 0)
		if aoeLocation.count >= 4 then
			return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
		end
		aoeLocation = bot:FindAoELocation(true, false, bot:GetLocation(), castRange, radius, castPoint, 0)
		if aoeLocation.count >= 2 then
			return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
		end
	end
	if Fu.IsFarming(bot) then
		if Fu.GetManaAfter(manaCost) < 0.3 then
			return BOT_ACTION_DESIRE_NONE, 0
		end
		local laneCreeps = bot:GetNearbyLaneCreeps(800, true)
		local aoeLocation = bot:FindAoELocation(true, false, bot:GetLocation(), 800, radius, 0, 0)
		if isAttacking then
			if laneCreeps ~= nil and #laneCreeps >= 3 and aoeLocation.count >= 3 then
				return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
			end
			local neutralCreeps = bot:GetNearbyNeutralCreeps(600)
			if
				neutralCreeps ~= nil
				and (#neutralCreeps >= 3 and aoeLocation.count >= 3 or #neutralCreeps >= 2 and aoeLocation.count >= 2 and neutralCreeps[1]:IsAncientCreep())
				and manaRatio > 0.27
			then
				return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
			end
		end
	end
	if Fu.IsLaning(bot) then
		if Fu.GetManaAfter(manaCost) < 0.3 then
			return BOT_ACTION_DESIRE_NONE, 0
		end
		local killableCount = 0
		local killableCreeps = {}
		local laneCreeps = bot:GetNearbyLaneCreeps(castRange, true)
		local enemiesNearby = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
		for _, creep in pairs(laneCreeps) do
			if Fu.IsValid(creep) and creep:GetHealth() <= damage then
				killableCount = killableCount + 1
				table.insert(killableCreeps, creep)
			end
		end
		if killableCount >= 2 and Fu.GetMP(bot) > 0.25 and enemiesNearby ~= nil and #enemiesNearby >= 1 then
			return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(killableCreeps)
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if
			Fu.IsRoshan(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, 500)
			and isAttacking
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, 400) and isAttacking then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.ConsiderCallOfTheWildBoar()
	if not summonRazorbackAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
	end
	local attackRange = bot:GetAttackRange()
	-- Fights: any engage on a hero within 800. It used to need the target outside his attack
	-- range and allies >= enemies, so in melee range or outnumbered he never summoned it.
	if isGoingOnSomeone and Fu.IsValidHero(botTarget) and Fu.IsInRange(bot, botTarget, 800) then
		return BOT_ACTION_DESIRE_HIGH
	end
	-- Running away: an enemy hero chasing him within 700 (the boar fights the chaser).
	if Fu.IsRetreating(bot) then
		for _, enemyHero in pairs(Fu.GetNearbyHeroes(bot, 700, true, BOT_MODE_NONE) or {}) do
			if
				Fu.IsValidHero(enemyHero)
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and Fu.IsChasingTarget(enemyHero, bot)
			then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	if Fu.IsPushing(bot) or Fu.IsDefending(bot) then
		if isAttacking then
			local laneCreeps = bot:GetNearbyLaneCreeps(700, true)
			if laneCreeps ~= nil and #laneCreeps >= 4 then
				return BOT_ACTION_DESIRE_HIGH
			end
			local enemyTowers = bot:GetNearbyTowers(700, true)
			if enemyTowers ~= nil and #enemyTowers > 0 then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	if Fu.IsFarming(bot) and Fu.GetMP(bot) > 0.33 then
		local neutralCreeps = bot:GetNearbyNeutralCreeps(attackRange + 75)
		local laneCreeps = bot:GetNearbyLaneCreeps(attackRange + 75, true)
		if isAttacking then
			if
				neutralCreeps ~= nil
				and (#neutralCreeps >= 3 or #neutralCreeps >= 2 and neutralCreeps[1]:IsAncientCreep())
			then
				return BOT_ACTION_DESIRE_HIGH
			end
			if laneCreeps ~= nil and #laneCreeps >= 3 then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if Fu.IsRoshan(botTarget) and Fu.IsInRange(bot, botTarget, 400) and isAttacking then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, 400) and isAttacking then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderCallOfTheWildHawk()
	if not summonRaptorAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
	end
	if isInTeamFight then
		local aoeLocation = bot:FindAoELocation(true, true, bot:GetLocation(), 500, 500, 0, 0)
		if aoeLocation.count >= 2 then
			local enemiesNearAoe = Fu.GetEnemiesNearLoc(aoeLocation.targetloc, 500)
			if enemiesNearAoe ~= nil and #enemiesNearAoe >= 2 then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	if isGoingOnSomeone then
		local alliesNearby = Fu.GetNearbyHeroes(bot, 800, false, BOT_MODE_NONE)
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, 450)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not Fu.IsDisabled(botTarget)
			and not Fu.IsTaunted(botTarget)
			and not botTarget:HasModifier("modifier_dazzle_shallow_grave")
			and not botTarget:HasModifier("modifier_templar_assassin_refraction_absorb")
		then
			local enemiesNearTarget = Fu.GetNearbyHeroes(botTarget, 800, false, BOT_MODE_NONE)
			if alliesNearby ~= nil and enemiesNearTarget ~= nil and #alliesNearby >= #enemiesNearTarget then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	if Fu.IsRetreating(bot) then
		local alliesNearby = Fu.GetNearbyHeroes(bot, 800, false, BOT_MODE_NONE)
		local enemiesNearby = Fu.GetNearbyHeroes(bot, 800, true, BOT_MODE_NONE)
		if
			alliesNearby ~= nil
			and enemiesNearby
			and Fu.IsValidHero(enemiesNearby[1])
			and Fu.CanCastOnNonMagicImmune(enemiesNearby[1])
			and Fu.IsInRange(bot, enemiesNearby[1], 450)
			and Fu.IsRunning(enemiesNearby[1])
			and enemiesNearby[1]:IsFacingLocation(bot:GetLocation(), 30)
			and not Fu.IsSuspiciousIllusion(enemiesNearby[1])
		then
			local enemiesNearTarget = Fu.GetNearbyHeroes(enemiesNearby[1], 800, false, BOT_MODE_NONE)
			if
				enemiesNearTarget ~= nil
				and (#enemiesNearTarget > #alliesNearby or hpRatio < 0.57 and bot:WasRecentlyDamagedByAnyHero(2.7))
			then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderPrimalRoar()
	if not primalRoarAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castRange = Fu.GetProperCastRange(false, bot, primalRoarAbility:GetCastRange())
	local roarDuration = primalRoarAbility:GetSpecialValueInt("duration")
	local damage = primalRoarAbility:GetSpecialValueInt("damage")
	local enemiesInRange = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(enemiesInRange) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanCastOnMagicImmune(enemyHero)
			and Fu.CanCastOnTargetAdvanced(enemyHero)
			and not Fu.IsSuspiciousIllusion(enemyHero)
			and enemyHero:HasModifier("modifier_teleporting")
		then
			local teleportTime = Fu.GetModifierTime(enemyHero, "modifier_teleporting")
			if teleportTime > 0 then
				return BOT_ACTION_DESIRE_HIGH, enemyHero
			end
		end
	end
	for _, enemyHero in pairs(enemiesInRange) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanCastOnMagicImmune(enemyHero)
			and Fu.CanCastOnTargetAdvanced(enemyHero)
			and not Fu.IsSuspiciousIllusion(enemyHero)
			and not enemyHero:HasModifier("modifier_stunned")
		then
			if Fu.IsCastingUltimateAbility(enemyHero) then
				return BOT_ACTION_DESIRE_HIGH, enemyHero
			end
			if
				Fu.CanKillTarget(enemyHero, damage, DAMAGE_TYPE_MAGICAL)
				and Fu.IsRunning(enemyHero)
				and bot:IsFacingLocation(enemyHero:GetLocation(), 30)
				and not enemyHero:IsFacingLocation(bot:GetLocation(), 30)
				and not wildAxesAbility:IsFullyCastable()
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
		local roarTarget = nil
		local highestDamage = 0
		for _, enemyHero in pairs(enemiesInRange) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.CanCastOnMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
				and Fu.GetHP(enemyHero) > 0.5
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and not Fu.IsDisabled(enemyHero)
				and not Fu.IsTaunted(enemyHero)
				and not enemyHero:HasModifier("modifier_faceless_void_chronosphere_freeze")
				and not enemyHero:HasModifier("modifier_enigma_black_hole_pull")
				and not enemyHero:HasModifier("modifier_legion_commander_duel")
				and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
				and not enemyHero:HasModifier("modifier_stunned")
			then
				local estimatedDamage = enemyHero:GetEstimatedDamageToTarget(true, bot, 5, DAMAGE_TYPE_ALL)
				if canReincarnate(enemyHero) then
					estimatedDamage = estimatedDamage * 0.3
				end
				if estimatedDamage > highestDamage then
					highestDamage = estimatedDamage
					roarTarget = enemyHero
				end
			end
		end
		if roarTarget == nil then
			local strongestEnemy = Fu.GetStrongestUnit(castRange, bot, true, false, roarDuration)
			if strongestEnemy == nil then
				strongestEnemy = Fu.GetStrongestUnit(1199, bot, true, true, roarDuration)
			end
			if
				Fu.IsValidTarget(strongestEnemy)
				and Fu.CanCastOnMagicImmune(strongestEnemy)
				and Fu.CanCastOnTargetAdvanced(strongestEnemy)
				and Fu.GetHP(strongestEnemy) > 0.5
				and not Fu.IsSuspiciousIllusion(strongestEnemy)
				and not Fu.IsDisabled(strongestEnemy)
				and not Fu.IsTaunted(strongestEnemy)
				and not strongestEnemy:HasModifier("modifier_faceless_void_chronosphere_freeze")
				and not strongestEnemy:HasModifier("modifier_enigma_black_hole_pull")
				and not strongestEnemy:HasModifier("modifier_legion_commander_duel")
				and not strongestEnemy:HasModifier("modifier_necrolyte_reapers_scythe")
				and not strongestEnemy:HasModifier("modifier_stunned")
			then
				roarTarget = strongestEnemy
			end
		end
		if roarTarget ~= nil then
			return BOT_ACTION_DESIRE_HIGH, roarTarget
		end
	end
	-- fix: was "isGoingOnSomeone and not CanDoBlinkRoar()". Blink-Roar is considered first and declines a target
	-- at or below 50% HP, so with a Blink ready a finishing Roar was never cast.
	if isGoingOnSomeone then
		local alliesNearby = Fu.GetNearbyHeroes(bot, 800, false, BOT_MODE_NONE)
		local enemiesNearby = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
		local roarTarget = nil
		local targetCanReincarnate = true
		for _, enemyHero in pairs(enemiesNearby) do
			if
				Fu.IsValidTarget(enemyHero)
				and Fu.CanCastOnMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and not Fu.IsDisabled(enemyHero)
				and not Fu.IsTaunted(enemyHero)
				and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
				and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
				and not enemyHero:HasModifier("modifier_enigma_black_hole_pull")
				and not enemyHero:HasModifier("modifier_faceless_void_chronosphere_freeze")
				and not enemyHero:HasModifier("modifier_legion_commander_duel")
				and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
				and not enemyHero:HasModifier("modifier_stunned")
			then
				local enemiesNearTarget = Fu.GetNearbyHeroes(enemyHero, 800, false, BOT_MODE_NONE)
				-- fix: dropped "(HP < 50% and he is alone) or (HP > 50% and strictly more allies)":
				-- alliesNearby includes Beastmaster, so with any ally next to him a hurt target was never roared,
				-- and an even fight never was. Allies >= enemies is the gate, as in the other spells.
				if alliesNearby ~= nil and enemiesNearTarget ~= nil and #alliesNearby >= #enemiesNearTarget then
					local enemyCanReincarnate = canReincarnate(enemyHero)
					if roarTarget == nil or targetCanReincarnate and not enemyCanReincarnate then
						roarTarget = enemyHero
						targetCanReincarnate = enemyCanReincarnate
					end
				end
			end
		end
		if roarTarget ~= nil then
			return BOT_ACTION_DESIRE_HIGH, roarTarget
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function X.ConsiderBlinkRoar()
	if CanDoBlinkRoar() then
		local roarDuration = primalRoarAbility:GetSpecialValueInt("duration")
		if isGoingOnSomeone then
			local alliesNearby = Fu.GetNearbyHeroes(bot, 1200, false, BOT_MODE_NONE)
			local strongestEnemy = Fu.GetStrongestUnit(1199, bot, true, false, roarDuration)
			if strongestEnemy == nil then
				strongestEnemy = Fu.GetStrongestUnit(1199, bot, true, true, roarDuration)
			end
			if
				Fu.IsValidTarget(strongestEnemy)
				-- fix: Primal Roar pierces (MAGIC_IMMUNE_ENEMIES flag, game data), like the plain Roar checks
				and Fu.CanCastOnMagicImmune(strongestEnemy)
				and Fu.CanCastOnTargetAdvanced(strongestEnemy)
				and Fu.IsInRange(bot, strongestEnemy, 1199)
				-- fix: no Blink when the target is already in Roar range (600); plain Roar does it.
				and not Fu.IsInRange(bot, strongestEnemy, primalRoarAbility:GetCastRange())
				and Fu.GetHP(strongestEnemy) > 0.5
				and not Fu.IsSuspiciousIllusion(strongestEnemy)
				and not Fu.IsDisabled(strongestEnemy)
				and not Fu.IsTaunted(strongestEnemy)
				and not strongestEnemy:HasModifier("modifier_abaddon_borrowed_time")
				and not strongestEnemy:HasModifier("modifier_dazzle_shallow_grave")
				and not strongestEnemy:HasModifier("modifier_enigma_black_hole_pull")
				and not strongestEnemy:HasModifier("modifier_faceless_void_chronosphere_freeze")
				and not strongestEnemy:HasModifier("modifier_legion_commander_duel")
				and not strongestEnemy:HasModifier("modifier_necrolyte_reapers_scythe")
			then
				local enemiesNearTarget = Fu.GetNearbyHeroes(strongestEnemy, 1200, false, BOT_MODE_NONE)
				if alliesNearby ~= nil and enemiesNearTarget ~= nil and #alliesNearby >= #enemiesNearTarget then
					bot.shouldBlink = true
					blinkLocation = strongestEnemy:GetLocation()
					return BOT_ACTION_DESIRE_HIGH, strongestEnemy
				end
			end
		end
	end
	bot.shouldBlink = false
	return BOT_ACTION_DESIRE_NONE, nil
end
function CanDoBlinkRoar()
	if primalRoarAbility:IsFullyCastable() and HasBlink() then
		local manaCost = primalRoarAbility:GetManaCost()
		if bot:GetMana() >= manaCost then
			return true
		end
	end
	return false
end
function HasBlink()
	local foundBlink = nil
	for slot = 0, 5 do
		local item = bot:GetItemInSlot(slot)
		if
			item ~= nil
			and (
				item:GetName() == "item_blink"
				or item:GetName() == "item_overwhelming_blink"
				or item:GetName() == "item_arcane_blink"
				or item:GetName() == "item_swift_blink"
			)
		then
			foundBlink = item
			break
		end
	end
	if foundBlink ~= nil and foundBlink:IsFullyCastable() then
		blinkItem = foundBlink
		return true
	end
	return false
end
function CanBKB()
	local foundBkb = nil
	for slot = 0, 5 do
		local item = bot:GetItemInSlot(slot)
		if item ~= nil and item:GetName() == "item_black_king_bar" then
			foundBkb = item
			break
		end
	end
	if foundBkb ~= nil and foundBkb:IsFullyCastable() and bot:GetMana() >= 75 then
		bkbItem = foundBkb
		return true
	end
	return false
end
return X
