-- Earthshaker: skill build, item build, and ability use for this hero.
local X = {}
local bot = GetBot()
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local AbilityContext = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local Minion = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local sTalentList = Fu.Skill.GetTalentList(bot)
local sAbilityList = Fu.Skill.GetAbilityList(bot)
local sRole = Fu.Item.GetRoleItemsBuyList(bot)
local tTalentTreeList = { ["t25"] = { 0, 10 }, ["t20"] = { 0, 10 }, ["t15"] = { 10, 0 }, ["t10"] = { 10, 0 } }
local tAllAbilityBuildList = { { 1, 2, 3, 1, 1, 6, 1, 3, 3, 3, 6, 2, 2, 2, 6 } }
local nAbilityBuildList = Fu.Skill.GetRandomBuild(tAllAbilityBuildList)
local nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList)
local sRoleItemsBuyList = {}
sRoleItemsBuyList["pos_1"] = {
	"item_sven_outfit",
	"item_echo_sabre",
	"item_hand_of_midas",
	"item_aghanims_shard",
	"item_blink",
	"item_ultimate_scepter",
	"item_black_king_bar",
	"item_travel_boots",
	"item_satanic",
	"item_overwhelming_blink",
	"item_greater_crit",
	"item_abyssal_blade",
	"item_moon_shard",
	"item_travel_boots_2",
}
-- Mid: Dotabuff has Blink, Shard, Yasha and Kaya, Arcane Boots, Scepter, BKB, Octarine and
-- Refresher on top; the carry list (Midas, Satanic, Daedalus, Abyssal) is outside its top 25.
sRoleItemsBuyList["pos_2"] = {
	"item_tango",
	"item_double_branches",
	"item_bottle",
	"item_magic_wand",
	"item_power_treads",
	"item_blink",
	"item_aghanims_shard",
	"item_yasha_and_kaya",
	"item_ultimate_scepter",
	"item_black_king_bar",
	"item_octarine_core",
	"item_refresher",
	"item_travel_boots",
	"item_ultimate_scepter_2",
	"item_travel_boots_2",
}
sRoleItemsBuyList["pos_3"] = {
	"item_tango",
	"item_double_branches",
	"item_gauntlets",
	"item_quelling_blade",
	"item_circlet",
	"item_bracer",
	"item_magic_wand",
	"item_power_treads",
	"item_blink",
	"item_aghanims_shard",
	"item_yasha_and_kaya",
	"item_black_king_bar",
	"item_ultimate_scepter",
	"item_lotus_orb",
	"item_travel_boots",
	"item_assault",
	"item_ultimate_scepter_2",
	"item_heart",
	"item_moon_shard",
	"item_overwhelming_blink",
	"item_travel_boots_2",
}
sRoleItemsBuyList["pos_4"] = {
	"item_priest_outfit",
	"item_blink",
	"item_mekansm",
	"item_glimmer_cape",
	"item_aghanims_shard",
	"item_guardian_greaves",
	"item_spirit_vessel",
	"item_ultimate_scepter",
	"item_overwhelming_blink",
	"item_ultimate_scepter_2",
	"item_sheepstick",
	"item_moon_shard",
}
sRoleItemsBuyList["pos_5"] = {
	"item_tango",
	"item_blood_grenade",
	"item_magic_stick",
	"item_branches",
	"item_clarity",
	"item_magic_wand",
	"item_arcane_boots",
	"item_blink",
	"item_glimmer_cape",
	"item_guardian_greaves",
	"item_pipe",
	"item_aghanims_shard",
	"item_cyclone",
	"item_shivas_guard",
	"item_sheepstick",
	"item_ultimate_scepter",
	"item_heart",
	"item_octarine_core",
	"item_overwhelming_blink",
	"item_moon_shard",
	"item_ultimate_scepter_2",
}
X["sBuyList"] = sRoleItemsBuyList[sRole]
X["sSellList"] = { "item_travel_boots", "item_quelling_blade", "item_abyssal_blade", "item_magic_wand" }
if Fu.Role.IsPvNMode() or Fu.Role.IsAllShadow() then
	X["sBuyList"], X["sSellList"] = { "PvN_antimage" }, {}
end
nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"] =
	Fu.SetUserHeroInit(nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"])
X["sSkillList"] = Fu.Skill.GetSkillList(sAbilityList, nAbilityBuildList, sTalentList, nTalentBuildList)
X["bDeafaultAbility"] = false
-- Cast when cornered (retreating into 3+ enemies with no way out), before running further.
X["LastStandSpells"] = { { name = "earthshaker_echo_slam", kind = "none" } }
X["bDeafaultItem"] = false
function X.MinionThink(minionUnit)
	Minion.MinionThink(minionUnit)
end
local fissureAbility = SafeAbility(bot:GetAbilityByName("earthshaker_fissure"), "earthshaker_fissure", "earthshaker")
local enchantTotemAbility =
	SafeAbility(bot:GetAbilityByName("earthshaker_enchant_totem"), "earthshaker_enchant_totem", "earthshaker")
local aftershockAbility =
	SafeAbility(bot:GetAbilityByName("earthshaker_aftershock"), "earthshaker_aftershock", "earthshaker")
local echoSlamAbility =
	SafeAbility(bot:GetAbilityByName("earthshaker_echo_slam"), "earthshaker_echo_slam", "earthshaker")
local fissureDesire, fissureLocation
local enchantTotemDesire, enchantTotemLocation, isTotemLeap
local echoSlamDesire
local blinkSlamDesire, blinkSlamLocation
local totemSlamDesire, totemSlamLocation
local blinkItem
local botTarget
local isGoingOnSomeone
local isAttacking
local isInTeamFight
function X.SkillsComplement()
	local context = AbilityContext.Build(bot)
	isGoingOnSomeone = context.isEngaging
	isAttacking = Fu.IsAttacking(bot)
	isInTeamFight = context.isTeamFight
	if Fu.CanNotUseAbility(bot) or bot:NumQueuedActions() > 0 then
		return
	end
	botTarget = context.target
	blinkSlamDesire, blinkSlamLocation = X.ConsiderBlinkSlam()
	if blinkSlamDesire > 0 then
		bot:Action_ClearActions(false)
		bot:ActionQueue_UseAbilityOnLocation(blinkItem, blinkSlamLocation)
		bot:ActionQueue_Delay(0.1)
		bot:ActionQueue_UseAbility(echoSlamAbility)
		return
	end
	totemSlamDesire, totemSlamLocation = X.ConsiderTotemSlam()
	if totemSlamDesire > 0 then
		local leapDuration = enchantTotemAbility:GetSpecialValueFloat("scepter_leap_duration")
		bot:Action_ClearActions(false)
		bot:ActionQueue_UseAbilityOnLocation(enchantTotemAbility, totemSlamLocation)
		bot:ActionQueue_Delay(leapDuration + 0.1)
		bot:ActionQueue_UseAbility(echoSlamAbility)
		return
	end
	echoSlamDesire = X.ConsiderEchoSlam()
	if echoSlamDesire > 0 then
		bot:Action_UseAbility(echoSlamAbility)
		return
	end
	enchantTotemDesire, enchantTotemLocation, isTotemLeap = X.ConsiderEnchantTotem()
	if enchantTotemDesire > 0 then
		if bot:HasScepter() then
			if isTotemLeap then
				bot:Action_UseAbilityOnLocation(enchantTotemAbility, enchantTotemLocation)
			else
				bot:Action_UseAbilityOnEntity(enchantTotemAbility, bot)
			end
			return
		else
			bot:Action_UseAbility(enchantTotemAbility)
			return
		end
	end
	fissureDesire, fissureLocation = X.ConsiderFissure()
	if fissureDesire > 0 then
		bot:Action_UseAbilityOnLocation(fissureAbility, fissureLocation)
		return
	end
end
function X.ConsiderFissure()
	if not fissureAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local castRange = Fu.GetProperCastRange(false, bot, fissureAbility:GetCastRange())
	local tpTarget = Fu.GetTPTarget(bot, castRange)
	if tpTarget and not tpTarget:IsMagicImmune() then
		return BOT_ACTION_DESIRE_HIGH, tpTarget:GetLocation()
	end
	local castPoint = fissureAbility:GetCastPoint()
	local radius = fissureAbility:GetSpecialValueInt("fissure_radius")
	local damage = fissureAbility:GetSpecialValueInt("fissure_damage")
	local abilityLevel = fissureAbility:GetLevel()
	local nearbyEnemies = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
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
				return BOT_ACTION_DESIRE_HIGH, enemyHero:GetExtrapolatedLocation(castPoint)
			end
		end
	end
	local nearbyAllies = Fu.GetNearbyHeroes(bot, 1400, false, BOT_MODE_NONE)
	for _, allyHero in pairs(nearbyAllies) do
		local enemiesNearAlly = Fu.GetNearbyHeroes(allyHero, 1200, true, BOT_MODE_NONE)
		if
			Fu.IsValidHero(allyHero)
			and Fu.IsRetreating(allyHero)
			and allyHero:GetActiveModeDesire() >= 0.5
			and not allyHero:IsIllusion()
		then
			if
				enemiesNearAlly ~= nil
				and #enemiesNearAlly >= 1
				and Fu.IsValidHero(enemiesNearAlly[1])
				and Fu.CanCastOnNonMagicImmune(enemiesNearAlly[1])
				and Fu.IsInRange(bot, enemiesNearAlly[1], castRange)
				and Fu.IsChasingTarget(enemiesNearAlly[1], allyHero)
				and not Fu.IsChasingTarget(enemiesNearAlly[1], bot)
				and not Fu.IsDisabled(enemiesNearAlly[1])
				and not Fu.IsTaunted(enemiesNearAlly[1])
				and not Fu.IsSuspiciousIllusion(enemiesNearAlly[1])
				and not enemiesNearAlly[1]:HasModifier("modifier_enigma_black_hole_pull")
				and not enemiesNearAlly[1]:HasModifier("modifier_faceless_void_chronosphere_freeze")
				and not enemiesNearAlly[1]:HasModifier("modifier_necrolyte_reapers_scythe")
			then
				return BOT_ACTION_DESIRE_HIGH, enemiesNearAlly[1]:GetExtrapolatedLocation(castPoint + 0.1)
			end
		end
	end
	if Fu.IsInTeamFight(bot) then
		local enemiesInRange = Fu.GetEnemiesNearLoc(bot:GetLocation(), castRange + 300)
		local strongestEnemy = nil
		local highestDamage = 0
		for _, enemyHero in pairs(enemiesInRange) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and not Fu.IsDisabled(enemyHero)
				and not enemyHero:HasModifier("modifier_faceless_void_chronosphere")
				and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
			then
				local estimatedDamage = enemyHero:GetEstimatedDamageToTarget(false, bot, 5, DAMAGE_TYPE_ALL)
				if estimatedDamage > highestDamage then
					highestDamage = estimatedDamage
					strongestEnemy = enemyHero
				end
			end
		end
		if strongestEnemy ~= nil then
			enemiesInRange = Fu.GetEnemiesNearLoc(strongestEnemy:GetLocation(), radius)
			if enemiesInRange ~= nil and #enemiesInRange >= 1 then
				return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(enemiesInRange)
			else
				return BOT_ACTION_DESIRE_HIGH, strongestEnemy:GetExtrapolatedLocation(castPoint)
			end
		end
	end
	if isGoingOnSomeone then
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not Fu.IsDisabled(botTarget)
			and not botTarget:HasModifier("modifier_faceless_void_chronosphere")
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			local alliesNearTarget = Fu.GetNearbyHeroes(botTarget, 1200, true, BOT_MODE_NONE)
			local enemiesNearTarget = Fu.GetNearbyHeroes(botTarget, 1200, false, BOT_MODE_NONE)
			if alliesNearTarget ~= nil and enemiesNearTarget ~= nil and #alliesNearTarget >= #enemiesNearTarget then
				enemiesNearTarget = Fu.GetEnemiesNearLoc(botTarget:GetLocation(), radius)
				if enemiesNearTarget ~= nil and #enemiesNearTarget >= 1 then
					return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(enemiesNearTarget)
				else
					return BOT_ACTION_DESIRE_HIGH, botTarget:GetExtrapolatedLocation(castPoint)
				end
			end
		end
	end
	if Fu.IsRetreating(bot) then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, 1200, false, BOT_MODE_NONE)
		local enemiesAround = Fu.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE)
		if
			nearbyAllies ~= nil
			and enemiesAround ~= nil
			and #enemiesAround > #nearbyAllies
			and Fu.IsValidHero(enemiesAround[1])
			and Fu.CanCastOnNonMagicImmune(enemiesAround[1])
			and Fu.IsInRange(bot, enemiesAround[1], castRange)
			and Fu.IsChasingTarget(enemiesAround[1], bot)
			and bot:WasRecentlyDamagedByAnyHero(2)
			and not Fu.IsInRange(bot, enemiesAround[1], 300)
			and not Fu.IsSuspiciousIllusion(enemiesAround[1])
			and not Fu.IsDisabled(enemiesAround[1])
		then
			-- fix: keep the chaser; the else branch indexed the (empty) re-fetched list
			local chaser = enemiesAround[1]
			local enemiesNearChaser = Fu.GetEnemiesNearLoc(chaser:GetLocation(), radius)
			if enemiesNearChaser ~= nil and #enemiesNearChaser >= 1 then
				return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(enemiesNearChaser)
			else
				return BOT_ACTION_DESIRE_HIGH, chaser:GetLocation()
			end
		end
	end
	nearbyEnemies = Fu.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE)
	if
		(Fu.IsPushing(bot) or Fu.IsDefending(bot))
		and Fu.GetManaAfter(fissureAbility:GetManaCost()) * bot:GetMana() > echoSlamAbility:GetManaCost()
		and abilityLevel >= 3
		and nearbyEnemies ~= nil
		and #nearbyEnemies == 0
		and not Fu.IsThereNonSelfCoreNearby(1000)
	then
		local laneCreeps = bot:GetNearbyLaneCreeps(1600, true)
		if laneCreeps ~= nil and #laneCreeps >= 4 and Fu.CanBeAttacked(laneCreeps[1]) then
			return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(laneCreeps)
		end
	end
	if Fu.IsFarming(bot) and Fu.GetManaAfter(fissureAbility:GetManaCost()) > 0.4 and abilityLevel >= 2 then
		local neutralCreeps = bot:GetNearbyNeutralCreeps(castRange)
		if neutralCreeps ~= nil and #neutralCreeps >= 3 then
			return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(neutralCreeps)
		end
		local laneCreeps = bot:GetNearbyLaneCreeps(castRange, true)
		if laneCreeps ~= nil and #laneCreeps >= 4 and Fu.CanBeAttacked(laneCreeps[1]) then
			return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(laneCreeps)
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if
			Fu.IsRoshan(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and Fu.GetManaAfter(fissureAbility:GetManaCost()) > 0.4
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.ConsiderEnchantTotem()
	if not enchantTotemAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0, false
	end
	local leapDistance = bot:HasScepter() and enchantTotemAbility:GetSpecialValueInt("distance_scepter") or 0
	local radius = aftershockAbility:GetSpecialValueInt("aftershock_range")
	local leapDuration = enchantTotemAbility:GetSpecialValueFloat("scepter_leap_duration")
	if bot:HasScepter() and Fu.IsStuck(bot) then
		return BOT_ACTION_DESIRE_HIGH, Fu.Site.GetXUnitsTowardsLocation(bot, Fu.GetTeamFountain(), leapDistance), true
	end
	if Fu.IsInTeamFight(bot) then
		local enemiesInRadius = Fu.GetEnemiesNearLoc(bot:GetLocation(), radius)
		local nearbyIllusions = Fu.GetIllusionsNearLoc(bot:GetLocation(), radius)
		if bot:HasScepter() then
			local aoe = bot:FindAoELocation(true, true, bot:GetLocation(), leapDistance, radius, leapDuration, 0)
			enemiesInRadius = Fu.GetEnemiesNearLoc(aoe.targetloc, radius)
			if enemiesInRadius ~= nil and #enemiesInRadius >= 2 then
				return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(enemiesInRadius), true
			end
			enemiesInRadius = Fu.GetEnemiesNearLoc(bot:GetLocation(), 1600)
			if
				nearbyIllusions ~= nil
				and #nearbyIllusions >= 2
				and enemiesInRadius ~= nil
				and #enemiesInRadius == 0
			then
				return BOT_ACTION_DESIRE_HIGH, 0, false
			end
		else
			if enemiesInRadius ~= nil and #enemiesInRadius >= 2 then
				return BOT_ACTION_DESIRE_HIGH, 0, false
			end
			enemiesInRadius = Fu.GetEnemiesNearLoc(bot:GetLocation(), 1600)
			if
				nearbyIllusions ~= nil
				and #nearbyIllusions >= 2
				and enemiesInRadius ~= nil
				and #enemiesInRadius == 0
			then
				return BOT_ACTION_DESIRE_HIGH, 0, false
			end
		end
	end
	if isGoingOnSomeone then
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not Fu.IsDisabled(botTarget)
		then
			local nearbyAllies = Fu.GetNearbyHeroes(bot, 1000, false, BOT_MODE_NONE)
			local nearbyEnemies = Fu.GetNearbyHeroes(bot, 800, true, BOT_MODE_NONE)
			if nearbyAllies ~= nil and nearbyEnemies ~= nil and #nearbyAllies >= #nearbyEnemies then
				if bot:HasScepter() then
					if
						Fu.IsInRange(bot, botTarget, leapDistance)
						and not Fu.IsInRange(bot, botTarget, radius)
						and not botTarget:HasModifier("modifier_faceless_void_chronosphere")
					then
						return BOT_ACTION_DESIRE_HIGH, botTarget:GetExtrapolatedLocation(leapDuration), true
					else
						if Fu.IsInRange(bot, botTarget, radius - 50) then
							return BOT_ACTION_DESIRE_HIGH, 0, false
						end
					end
				else
					if Fu.IsInRange(bot, botTarget, radius - 50) then
						return BOT_ACTION_DESIRE_HIGH, 0, false
					end
				end
			end
		end
	end
	if Fu.IsRetreating(bot) and bot:GetActiveModeDesire() > 0.7 then
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE)
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
					and (#enemiesNearChaser > #alliesNearChaser or bot:WasRecentlyDamagedByAnyHero(2))
				then
					if bot:HasScepter() then
						return BOT_ACTION_DESIRE_HIGH,
							Fu.Site.GetXUnitsTowardsLocation(bot, Fu.GetTeamFountain(), leapDistance),
							true
					else
						if Fu.IsInRange(bot, enemyHero, radius) then
							return BOT_ACTION_DESIRE_HIGH, 0, false
						end
					end
				end
			end
		end
	end
	if
		(Fu.IsPushing(bot) or Fu.IsDefending(bot))
		and Fu.GetManaAfter(enchantTotemAbility:GetManaCost()) * bot:GetMana() > fissureAbility:GetManaCost() * 2
		and Fu.GetManaAfter(enchantTotemAbility:GetManaCost()) * bot:GetMana() > echoSlamAbility:GetManaCost()
		and not bot:HasModifier("modifier_earthshaker_enchant_totem")
	then
		local laneCreeps = bot:GetNearbyLaneCreeps(1400, true)
		if bot:HasScepter() then
			if
				laneCreeps ~= nil
				and #laneCreeps >= 3
				and Fu.CanBeAttacked(laneCreeps[1])
				and not Fu.IsRunning(laneCreeps[1])
			then
				local unitCountNearCreep =
					Fu.GetNearbyAroundLocationUnitCount(true, false, radius, laneCreeps[1]:GetLocation())
				if unitCountNearCreep >= 3 then
					return BOT_ACTION_DESIRE_HIGH, laneCreeps[1]:GetLocation(), true
				end
			end
			if Fu.IsValidBuilding(botTarget) and Fu.CanBeAttacked(botTarget) and isAttacking then
				return BOT_ACTION_DESIRE_HIGH, 0, false
			end
		else
			laneCreeps = bot:GetNearbyLaneCreeps(radius, true)
			if laneCreeps ~= nil and #laneCreeps >= 3 and Fu.CanBeAttacked(laneCreeps[1]) then
				return BOT_ACTION_DESIRE_HIGH, 0, false
			end
			if Fu.IsValidBuilding(botTarget) and Fu.CanBeAttacked(botTarget) and isAttacking then
				return BOT_ACTION_DESIRE_HIGH, 0, false
			end
		end
	end
	if Fu.IsLaning(bot) and Fu.IsInLaningPhase() then
		local enemiesInRadius = Fu.GetEnemiesNearLoc(bot:GetLocation(), radius)
		if
			enemiesInRadius ~= nil
			and #enemiesInRadius >= 1
			and Fu.IsValidHero(enemiesInRadius[1])
			and Fu.CanCastOnNonMagicImmune(enemiesInRadius[1])
			and not Fu.IsSuspiciousIllusion(enemiesInRadius[1])
			and not Fu.IsDisabled(enemiesInRadius[1])
			and not enemiesInRadius[1]:HasModifier("modifier_abaddon_borrowed_time")
		then
			return BOT_ACTION_DESIRE_HIGH, 0, false
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if
			Fu.IsRoshan(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, radius)
			and isAttacking
		then
			return BOT_ACTION_DESIRE_HIGH, 0, false
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, radius) and isAttacking then
			return BOT_ACTION_DESIRE_HIGH, 0, false
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0, false
end
-- Echo Slam (datafeed: 100/140/180 to enemies within 700; each enemy hit sends an echo for 70/90/110,
-- real heroes two; 110-130s). It used to count only enemy heroes within 350 (half the radius) and
-- nothing else, so slams into heroes with a creep wave, illusions or summons were held. Now the
-- echoes are counted (user call): creeps, neutrals, summons and illusions 1 each, real heroes 2.
-- A hero's own echoes do not hit him. The estimate per enemy hero: initial + echo damage x the
-- other echoes, as magic damage after his resistance.
local SLAM_RADIUS = 650
function X.EchoSlamValue(loc)
	local initial = echoSlamAbility:GetSpecialValueInt("echo_slam_initial_damage")
	local echo = echoSlamAbility:GetSpecialValueInt("echo_slam_echo_damage")
	local heroes, others = {}, 0
	for _, unit in pairs(Fu.GetEnemiesNearLoc(loc, SLAM_RADIUS) or {}) do
		if Fu.IsValidHero(unit) and not unit:IsMagicImmune() then
			if Fu.IsSuspiciousIllusion(unit) then
				others = others + 1
			else
				heroes[#heroes + 1] = unit
			end
		end
	end
	for _, unit in pairs(GetUnitList(UNIT_LIST_ENEMIES) or {}) do
		if
			unit ~= nil
			and not unit:IsNull()
			and unit:IsAlive()
			and not unit:IsHero()
			and not unit:IsBuilding()
			and not unit:IsMagicImmune()
			and not string.find(unit:GetUnitName(), "ward", 1, true)
			and (unit:GetLocation() - loc):Length2D() <= SLAM_RADIUS
		then
			others = others + 1
		end
	end
	for _, unit in pairs(GetUnitList(UNIT_LIST_NEUTRAL_CREEPS) or {}) do
		if
			unit ~= nil
			and not unit:IsNull()
			and unit:IsAlive()
			and (unit:GetLocation() - loc):Length2D() <= SLAM_RADIUS
		then
			others = others + 1
		end
	end
	local echoes = others + 2 * #heroes
	local kills, total = 0, 0
	for _, enemyHero in ipairs(heroes) do
		local raw = initial + echo * math.max(0, echoes - 2)
		local dmg = enemyHero:GetActualIncomingDamage(raw, DAMAGE_TYPE_MAGICAL)
		total = total + math.min(dmg, enemyHero:GetHealth())
		if
			dmg >= enemyHero:GetHealth()
			and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
			and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
		then
			kills = kills + 1
		end
	end
	return #heroes, echoes, kills, total
end
-- Worth it: a kill, 2+ heroes with 6+ echoes, 3+ heroes, or 1 hero taking 70%+ of his HP.
function X.EchoSlamWorth(loc)
	local heroCount, echoes, kills, total = X.EchoSlamValue(loc)
	if heroCount == 0 then
		return false, heroCount, echoes, kills
	end
	if kills >= 1 or heroCount >= 3 or heroCount >= 2 and echoes >= 6 then
		return true, heroCount, echoes, kills
	end
	return false, heroCount, echoes, kills
end
local function LogSlam(why, heroCount, echoes, kills)
	pcall(
		print,
		string.format(
			"[OHA-ES] t=%.0f slam why=%s heroes=%d echoes=%d kills=%d",
			DotaTime(),
			why,
			heroCount,
			echoes,
			kills
		)
	)
end
function X.ConsiderEchoSlam()
	if not echoSlamAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
	end
	if not (isInTeamFight or isGoingOnSomeone) then
		return BOT_ACTION_DESIRE_NONE
	end
	local worth, heroCount, echoes, kills = X.EchoSlamWorth(bot:GetLocation())
	if worth then
		LogSlam(isInTeamFight and "fight" or "engage", heroCount, echoes, kills)
		return BOT_ACTION_DESIRE_HIGH
	end
	-- Interrupt a channel (Black Hole, a teleport, ...) on his target in range.
	if
		isGoingOnSomeone
		and Fu.IsValidHero(botTarget)
		and botTarget:IsChanneling()
		and Fu.IsInRange(bot, botTarget, SLAM_RADIUS)
		and Fu.CanCastOnNonMagicImmune(botTarget)
	then
		LogSlam("channel", heroCount, echoes, kills)
		return BOT_ACTION_DESIRE_HIGH
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderBlinkSlam()
	if X.CanDoBlinkSlam() then
		local blinkRange = 1199
		local radius = echoSlamAbility:GetSpecialValueInt("echo_slam_echo_range")
		if isGoingOnSomeone or isInTeamFight then
			local aoe = bot:FindAoELocation(true, true, bot:GetLocation(), blinkRange, radius, 0, 0)
			local enemiesNearSpot = Fu.GetEnemiesNearLoc(aoe.targetloc, SLAM_RADIUS)
			if enemiesNearSpot ~= nil and #enemiesNearSpot >= 1 then
				local spot = Fu.GetCenterOfUnits(enemiesNearSpot)
				local worth, heroCount, echoes, kills = X.EchoSlamWorth(spot)
				if worth then
					LogSlam("blink", heroCount, echoes, kills)
					return BOT_ACTION_DESIRE_HIGH, spot
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.CanDoBlinkSlam()
	if X.HasBlink() and echoSlamAbility:IsFullyCastable() then
		local manaNeeded = echoSlamAbility:GetManaCost()
		if bot:GetMana() >= manaNeeded then
			bot.shouldBlink = true
			return true
		end
	end
	bot.shouldBlink = false
	return false
end
function X.ConsiderTotemSlam()
	if X.CanDoTotemSlam() then
		local leapDistance = enchantTotemAbility:GetSpecialValueInt("distance_scepter")
		local leapDuration = enchantTotemAbility:GetSpecialValueFloat("scepter_leap_duration")
		local radius = echoSlamAbility:GetSpecialValueInt("echo_slam_echo_range")
		if isInTeamFight then
			local aoe = bot:FindAoELocation(true, true, bot:GetLocation(), leapDistance, radius, leapDuration, 0)
			local enemiesNearSpot = Fu.GetEnemiesNearLoc(aoe.targetloc, SLAM_RADIUS)
			if enemiesNearSpot ~= nil and #enemiesNearSpot >= 1 then
				local spot = Fu.GetCenterOfUnits(enemiesNearSpot)
				local worth, heroCount, echoes, kills = X.EchoSlamWorth(spot)
				if worth then
					LogSlam("totem", heroCount, echoes, kills)
					return BOT_ACTION_DESIRE_HIGH, spot
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.CanDoTotemSlam()
	if bot:HasScepter() and enchantTotemAbility:IsFullyCastable() and echoSlamAbility:IsFullyCastable() then
		local manaNeeded = enchantTotemAbility:GetManaCost() + echoSlamAbility:GetManaCost()
		if bot:GetMana() >= manaNeeded then
			return true
		end
	end
	return false
end
function X.CanJump()
	if bot:HasScepter() and enchantTotemAbility:IsFullyCastable() then
		return true
	end
	return false
end
function X.HasBlink()
	local blink = nil
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
			blink = item
			break
		end
	end
	if blink ~= nil and blink:IsFullyCastable() then
		blinkItem = blink
		return true
	end
	return false
end
return X
