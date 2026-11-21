-- Spirit Breaker: skill build, item build, and ability use for this hero.
local X = {}
local bot = GetBot()
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local AbilityContext = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local Minion = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local sTalentList = Fu.Skill.GetTalentList(bot)
local sAbilityList = Fu.Skill.GetAbilityList(bot)
local sRole = Fu.Item.GetRoleItemsBuyList(bot)
local tTalentTreeList = { ["t25"] = { 0, 10 }, ["t20"] = { 0, 10 }, ["t15"] = { 0, 10 }, ["t10"] = { 0, 10 } }
local tAllAbilityBuildList = { { 3, 1, 2, 3, 3, 6, 3, 1, 1, 1, 6, 2, 2, 2, 6 } }
local nAbilityBuildList = Fu.Skill.GetRandomBuild(tAllAbilityBuildList)
local nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList)
local sRoleItemsBuyList = {}
local sUtilityList = { "item_pipe", "item_lotus_orb", "item_crimson_guard", "item_heavens_halberd" }
local sUtility = sUtilityList[RandomInt(1, #sUtilityList)]
-- Stratz 7.41f, week of 9 Nov 2026: pos 3, 54,078 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_3"] = {
	"item_tango",
	"item_double_branches",
	"item_gauntlets",
	"item_quelling_blade",
	"item_circlet",
	"item_bracer",
	"item_magic_wand",
	"item_phase_boots",
	"item_invis_sword",
	"item_yasha_and_kaya",
	"item_ultimate_scepter",
	"item_silver_edge",
	"item_wind_waker",
	"item_ultimate_scepter_2",
	"item_ancient_janggo",
	"item_blade_mail",
	"item_aghanims_shard",
	"item_moon_shard",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 1, 1,427 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_1"] = {
	"item_tango",
	"item_branches",
	"item_quelling_blade",
	"item_gauntlets",
	"item_circlet",
	"item_bracer",
	"item_magic_wand",
	"item_phase_boots",
	"item_invis_sword",
	"item_yasha_and_kaya",
	"item_ultimate_scepter",
	"item_silver_edge",
	"item_ultimate_scepter_2",
	"item_echo_sabre",
	"item_heart",
	"item_hand_of_midas",
	"item_aghanims_shard",
	"item_moon_shard",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 2, 12,924 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_2"] = {
	"item_tango",
	"item_double_branches",
	"item_quelling_blade",
	"item_gauntlets",
	"item_circlet",
	"item_bracer",
	"item_magic_wand",
	"item_phase_boots",
	"item_invis_sword",
	"item_yasha_and_kaya",
	"item_ultimate_scepter",
	"item_silver_edge",
	"item_cyclone",
	"item_wind_waker",
	"item_ultimate_scepter_2",
	"item_spirit_vessel",
	"item_hand_of_midas",
	"item_aghanims_shard",
	"item_moon_shard",
}
-- Support builds: Dotabuff 7-day meta has Spirit Breaker mostly at support-off (pos 4, S tier).
-- Stratz 7.41f, week of 9 Nov 2026: pos 4, 211,479 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_4"] = {
	"item_tango",
	"item_blood_grenade",
	"item_branches",
	"item_wind_lace",
	"item_gauntlets",
	"item_magic_wand",
	"item_phase_boots",
	"item_invis_sword",
	"item_yasha_and_kaya",
	"item_ultimate_scepter",
	"item_ultimate_scepter_2",
	"item_ancient_janggo",
	"item_spirit_vessel",
	"item_blade_mail",
	"item_aghanims_shard",
	"item_moon_shard",
}
-- One pair of boots in this build (user rule; Util/boots-check.js).
-- Stratz 7.41f, week of 9 Nov 2026: pos 5, 52,381 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_5"] = {
	"item_tango",
	"item_blood_grenade",
	"item_branches",
	"item_wind_lace",
	"item_gauntlets",
	"item_magic_wand",
	"item_phase_boots",
	"item_invis_sword",
	"item_yasha_and_kaya",
	"item_ultimate_scepter",
	"item_ancient_janggo",
	"item_spirit_vessel",
	"item_ultimate_scepter_2",
	"item_wind_waker",
	"item_aghanims_shard",
	"item_moon_shard",
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
local chargeOfDarknessAbility = SafeAbility(
	bot:GetAbilityByName("spirit_breaker_charge_of_darkness"),
	"spirit_breaker_charge_of_darkness",
	"spirit_breaker"
)
local bulldozeAbility =
	SafeAbility(bot:GetAbilityByName("spirit_breaker_bulldoze"), "spirit_breaker_bulldoze", "spirit_breaker")
local greaterBashAbility =
	SafeAbility(bot:GetAbilityByName("spirit_breaker_greater_bash"), "spirit_breaker_greater_bash", "spirit_breaker")
local planarPocketAbility =
	SafeAbility(bot:GetAbilityByName("spirit_breaker_planar_pocket"), "spirit_breaker_planar_pocket", "spirit_breaker")
local netherStrikeAbility =
	SafeAbility(bot:GetAbilityByName("spirit_breaker_nether_strike"), "spirit_breaker_nether_strike", "spirit_breaker")
local chargeOfDarknessDesire, chargeOfDarknessTarget
local bulldozeDesire
local planarPocketDesire
local netherStrikeDesire, netherStrikeTarget
local nearbyEnemies
if bot.chargeRetreat == nil then
	bot.chargeRetreat = false
end
local botTarget
local isEngaging
local isRetreating
local isAttacking
function X.SkillsComplement()
	if Fu.CanNotUseAbility(bot) then
		return
	end
	local context = AbilityContext.Build(bot)
	isEngaging = context.isEngaging
	isRetreating = context.isRetreating
	isAttacking = Fu.IsAttacking(bot)
	nearbyEnemies = context.enemies
	if bot:HasModifier("modifier_spirit_breaker_charge_of_darkness") or chargeOfDarknessAbility:IsInAbilityPhase() then
		if bot.chargeRetreat and #nearbyEnemies == 0 then
			bot:Action_MoveToLocation(bot:GetLocation() + RandomVector(150))
			bot.chargeRetreat = false
		end
		return
	end
	chargeOfDarknessDesire, chargeOfDarknessTarget = X.ConsiderChargeOfDarkness()
	if chargeOfDarknessDesire > 0 then
		if
			chargeOfDarknessAbility:GetLevel() >= 3
			and bulldozeAbility:IsTrained()
			and bulldozeAbility:IsFullyCastable()
		then
			bot:Action_UseAbility(bulldozeAbility)
		end
		-- Read only by the [OHA-HUNT] trace (FuncLib/systems/hunt_trace.lua, #165).
		bot._chargeTarget = chargeOfDarknessTarget
		bot:Action_UseAbilityOnEntity(chargeOfDarknessAbility, chargeOfDarknessTarget)
		return
	end
	bulldozeDesire = X.ConsiderBulldoze()
	if bulldozeDesire > 0 then
		bot:Action_UseAbility(bulldozeAbility)
		return
	end
	-- datafeed: Planar Pocket is unit-target (behavior 8, target team both), not no-target
	local pocketTarget
	planarPocketDesire, pocketTarget = X.ConsiderPlanarPocket()
	if planarPocketDesire > 0 and pocketTarget ~= nil then
		bot:Action_UseAbilityOnEntity(planarPocketAbility, pocketTarget)
		return
	end
	netherStrikeDesire, netherStrikeTarget = X.ConsiderNetherStrike()
	if netherStrikeDesire > 0 then
		bot:Action_UseAbilityOnEntity(netherStrikeAbility, netherStrikeTarget)
		return
	end
end
function X.ConsiderChargeOfDarkness()
	if
		not chargeOfDarknessAbility:IsFullyCastable() or bot:HasModifier("modifier_spirit_breaker_charge_of_darkness")
	then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	if not isRetreating then
		bot.chargeRetreat = false
	end
	local bashRadius = chargeOfDarknessAbility:GetSpecialValueInt("bash_radius")
	botTarget = Fu.GetProperTarget(bot)
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and not Fu.IsSuspiciousIllusion(enemyHero)
			and not Fu.IsLocationInChrono(enemyHero:GetLocation())
		then
			local alliesNearEnemy = Fu.GetNearbyHeroes(enemyHero, 1600, true, BOT_MODE_NONE)
			if alliesNearEnemy ~= nil and nearbyEnemies and #alliesNearEnemy >= #nearbyEnemies then
				if enemyHero:IsChanneling() then
					return BOT_ACTION_DESIRE_HIGH, enemyHero
				end
			end
		end
	end
	local teamFightLocation = Fu.GetTeamFightLocation(bot)
	if
		teamFightLocation ~= nil
		and GetUnitToLocationDistance(bot, teamFightLocation) > 1600
		and not Fu.IsInLaningPhase()
	then
		-- Review fix: this charged nearbyEnemies[1], the nearest enemy within 1600 of Spirit Breaker, i.e. NOT
		-- one at the fight (which is 1600+ away), and needed an enemy next to him to fire at all.
		-- Charge (global cast range) an enemy hero standing at the fight instead.
		if not Fu.IsLocationInChrono(teamFightLocation) and not isRetreating then
			for _, enemyHero in pairs(Fu.GetEnemiesNearLoc(teamFightLocation, 1200)) do
				if
					Fu.IsValidHero(enemyHero)
					and Fu.CanCastOnNonMagicImmune(enemyHero)
					and not Fu.IsSuspiciousIllusion(enemyHero)
					and not Fu.IsLocationInChrono(enemyHero:GetLocation())
				then
					if DotaTime() - (X.lastChargeLog or -99) > 10 then
						X.lastChargeLog = DotaTime()
						pcall(
							print,
							string.format(
								"[OHA-SB] t=%.0f charge-fight target=%s dist=%d",
								DotaTime(),
								enemyHero:GetUnitName(),
								GetUnitToUnitDistance(bot, enemyHero)
							)
						)
					end
					return BOT_ACTION_DESIRE_HIGH, enemyHero
				end
			end
		end
	end
	if isEngaging then
		local bestTarget = nil
		local highestDamage = 0
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and not Fu.IsDisabled(enemyHero)
				and not Fu.IsLocationInChrono(enemyHero:GetLocation())
				and not enemyHero:HasModifier("modifier_legion_commander_duel")
				and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
			then
				local alliesNearTarget = Fu.GetNearbyHeroes(enemyHero, 1200, true, BOT_MODE_NONE)
				local enemiesNearTarget = Fu.GetNearbyHeroes(enemyHero, 1200, false, BOT_MODE_NONE)
				local estimatedDamage = enemyHero:GetEstimatedDamageToTarget(true, bot, 5, DAMAGE_TYPE_ALL)
				if
					alliesNearTarget ~= nil
					and enemiesNearTarget
					and #alliesNearTarget >= #enemiesNearTarget
					and estimatedDamage > highestDamage
				then
					highestDamage = estimatedDamage
					bestTarget = enemyHero
				end
			end
		end
		if bestTarget ~= nil then
			return BOT_ACTION_DESIRE_HIGH, bestTarget
		end
	end
	if
		isRetreating
		and Fu.GetHP(bot) < 0.5
		and Fu.IsValidHero(nearbyEnemies[1])
		and Fu.IsInRange(bot, nearbyEnemies[1], 500)
	then
		-- Review fix: the escape charge took the first creep 1600+ away in any direction, often
		-- one deeper in enemy territory. Only charge a creep that is clearly nearer our escape spot.
		local escape = Fu.GetEscapeLoc()
		local myEscDist = GetUnitToLocationDistance(bot, escape)
		for _, creep in pairs(GetUnitList(UNIT_LIST_ENEMY_CREEPS)) do
			if
				Fu.IsValid(creep)
				and GetUnitToUnitDistance(creep, bot) > 1600
				and GetUnitToLocationDistance(creep, escape) < myEscDist - 1000
			then
				bot.chargeRetreat = true
				return BOT_ACTION_DESIRE_HIGH, creep
			end
		end
		for _, creep in pairs(GetUnitList(UNIT_LIST_NEUTRAL_CREEPS)) do
			if
				Fu.IsValid(creep)
				and GetUnitToUnitDistance(creep, bot) > 1600
				and GetUnitToLocationDistance(creep, escape) < myEscDist - 1000
			then
				bot.chargeRetreat = true
				return BOT_ACTION_DESIRE_HIGH, creep
			end
		end
	end
	if Fu.IsPushing(bot) then
		local aoeLocation =
			bot:FindAoELocation(true, false, bot:GetLocation(), bot:GetCurrentVisionRange(), bashRadius, 0, 0)
		local laneCreeps = bot:GetNearbyLaneCreeps(bashRadius, true)
		if laneCreeps ~= nil and #laneCreeps >= 4 and aoeLocation.count >= 4 then
			return BOT_ACTION_DESIRE_HIGH, laneCreeps[4]
		end
	end
	if Fu.IsFarming(bot) then
		local aoeLocation =
			bot:FindAoELocation(true, false, bot:GetLocation(), bot:GetCurrentVisionRange(), bashRadius, 0, 0)
		if isAttacking and Fu.GetMP(bot) > 0.25 then
			local neutralCreeps = bot:GetNearbyNeutralCreeps(bashRadius)
			if
				neutralCreeps ~= nil
				and (
					#neutralCreeps >= 3 and aoeLocation.count >= 3
					or #neutralCreeps >= 2 and neutralCreeps[1]:IsAncientCreep() and aoeLocation.count >= 2
				)
			then
				if Fu.CanBeAttacked(neutralCreeps[1]) then
					return BOT_ACTION_DESIRE_HIGH, neutralCreeps[2]
				end
			end
			local laneCreeps = bot:GetNearbyLaneCreeps(bashRadius, true)
			if laneCreeps ~= nil and #laneCreeps >= 3 and aoeLocation.count >= 3 then
				if Fu.CanBeAttacked(laneCreeps[1]) then
					-- fix: returned neutralCreeps[3] (may be nil) instead of the lane creep laneCreeps[3]
					return BOT_ACTION_DESIRE_HIGH, laneCreeps[3]
				end
			end
		end
	end
	if Fu.IsLaning(bot) then
		local lowHpCreepCount = 0
		local lowHpCreeps = {}
		local laneCreeps = bot:GetNearbyLaneCreeps(1000, true)
		for _, creep in pairs(laneCreeps) do
			if Fu.IsValid(creep) and Fu.GetHP(creep) <= 0.33 then
				local nearbyTowers = creep:GetNearbyTowers(700, false)
				if nearbyTowers ~= nil and #nearbyTowers == 0 then
					lowHpCreepCount = lowHpCreepCount + 1
					table.insert(lowHpCreeps, creep)
				end
			end
		end
		if
			lowHpCreepCount >= 2
			and Fu.GetMP(bot) > 0.25
			and Fu.CanBeAttacked(lowHpCreeps[1])
			and nearbyEnemies ~= nil
			and #nearbyEnemies == 0
			and greaterBashAbility:IsTrained()
			and greaterBashAbility:GetLevel() >= 2
		then
			return BOT_ACTION_DESIRE_HIGH, lowHpCreeps[2]
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if Fu.IsRoshan(botTarget) and Fu.IsInRange(bot, botTarget, 500) and isAttacking then
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, 500) and isAttacking then
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end
	for _, allyHero in pairs(GetUnitList(UNIT_LIST_ALLIED_HEROES)) do
		if
			Fu.IsValidHero(allyHero)
			and Fu.IsGoingOnSomeone(allyHero)
			and not Fu.IsMeepoClone(allyHero)
			and not allyHero:IsIllusion()
			and not allyHero:HasModifier("modifier_arc_warden_tempest_double")
		then
			local allyTarget = allyHero:GetAttackTarget()
			if
				Fu.IsValidTarget(allyTarget)
				and Fu.CanCastOnNonMagicImmune(allyTarget)
				and not Fu.IsSuspiciousIllusion(allyTarget)
				and not Fu.IsLocationInChrono(allyTarget:GetLocation())
			then
				local distance = GetUnitToUnitDistance(bot, allyTarget)
				if
					(Fu.IsChasingTarget(allyHero, allyTarget) or Fu.IsAttacking(allyHero))
					and distance > 600
					and distance < 1900
				then
					-- fix: charge the ally's validated target allyTarget, not our own (possibly nil) botTarget
					return BOT_ACTION_DESIRE_HIGH, allyTarget
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function X.ConsiderBulldoze()
	if not bulldozeAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
	end
	botTarget = Fu.GetProperTarget(bot)
	if bot:HasModifier("modifier_spirit_breaker_charge_of_darkness") then
		return BOT_ACTION_DESIRE_HIGH
	end
	if isEngaging then
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, 600)
			and bot:WasRecentlyDamagedByAnyHero(1)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not Fu.IsDisabled(botTarget)
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if isRetreating then
		if
			Fu.IsValidHero(nearbyEnemies[1])
			and Fu.IsInRange(bot, nearbyEnemies[1], 600)
			and Fu.IsChasingTarget(nearbyEnemies[1], bot)
			and not Fu.IsSuspiciousIllusion(nearbyEnemies[1])
			and not Fu.IsDisabled(nearbyEnemies[1])
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderNetherStrike()
	if not netherStrikeAbility:IsFullyCastable() or bot:HasModifier("modifier_spirit_breaker_charge_of_darkness") then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castRange = netherStrikeAbility:GetCastRange()
	-- datafeed: Nether Strike damage is the "damage" special value (150/250/350); there is no AbilityDamage
	local damage = netherStrikeAbility:GetSpecialValueInt("damage")
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.IsInRange(bot, enemyHero, castRange)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and not Fu.IsSuspiciousIllusion(enemyHero)
			and not Fu.IsLocationInChrono(enemyHero:GetLocation())
		then
			if enemyHero:IsChanneling() then
				return BOT_ACTION_DESIRE_HIGH, enemyHero
			end
			if
				Fu.CanKillTarget(enemyHero, damage, DAMAGE_TYPE_MAGICAL)
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
	end
	if isEngaging then
		local bestTarget = nil
		local highestDamage = 0
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.IsInRange(bot, enemyHero, castRange)
				and Fu.CanCastOnMagicImmune(enemyHero)
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and not Fu.IsDisabled(enemyHero)
				and not Fu.IsLocationInChrono(enemyHero:GetLocation())
				and not enemyHero:HasModifier("modifier_legion_commander_duel")
				and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
			then
				local alliesNearTarget = Fu.GetNearbyHeroes(enemyHero, 1200, true, BOT_MODE_NONE)
				local enemiesNearTarget = Fu.GetNearbyHeroes(enemyHero, 1200, false, BOT_MODE_NONE)
				local estimatedDamage = enemyHero:GetEstimatedDamageToTarget(true, bot, 5, DAMAGE_TYPE_ALL)
				if
					alliesNearTarget ~= nil
					and enemiesNearTarget
					and #alliesNearTarget >= #enemiesNearTarget
					and estimatedDamage > highestDamage
				then
					highestDamage = estimatedDamage
					bestTarget = enemyHero
				end
			end
		end
		if bestTarget ~= nil then
			return BOT_ACTION_DESIRE_HIGH, bestTarget
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function X.ConsiderPlanarPocket()
	if
		not planarPocketAbility:IsTrained()
		or not planarPocketAbility:IsFullyCastable()
		or bot:HasModifier("modifier_spirit_breaker_charge_of_darkness")
	then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local radius = planarPocketAbility:GetSpecialValueInt("radius")
	-- datafeed: cast range 700; Barathrum gets the magic resistance whichever hero is targeted
	local castRange = Fu.GetProperCastRange(false, bot, planarPocketAbility:GetCastRange())
	botTarget = Fu.GetProperTarget(bot)
	if Fu.IsInTeamFight(bot, 1200) then
		local enemiesInRadius = Fu.GetEnemiesNearLoc(bot:GetLocation(), radius)
		if enemiesInRadius ~= nil and #enemiesInRadius >= 2 and bot:WasRecentlyDamagedByAnyHero(1) then
			-- pocket the most hurt ally so enemy unit-target spells on it go to Spirit Breaker
			local ally, allyHp = nil, 1
			for _, allyHero in pairs(Fu.GetNearbyHeroes(bot, castRange, false, BOT_MODE_NONE) or {}) do
				if
					Fu.IsValidHero(allyHero)
					and allyHero ~= bot
					and not allyHero:IsIllusion()
					and allyHero:WasRecentlyDamagedByAnyHero(2)
					and Fu.GetHP(allyHero) < allyHp
				then
					ally, allyHp = allyHero, Fu.GetHP(allyHero)
				end
			end
			if ally ~= nil then
				return BOT_ACTION_DESIRE_HIGH, ally
			end
			-- no hurt ally: still cast for the magic resistance, on a nearby enemy hero
			for _, enemyHero in pairs(enemiesInRadius) do
				if
					Fu.IsValidHero(enemyHero)
					and Fu.IsInRange(bot, enemyHero, castRange)
					and not Fu.IsSuspiciousIllusion(enemyHero)
				then
					return BOT_ACTION_DESIRE_HIGH, enemyHero
				end
			end
		end
	end
	if isEngaging then
		if
			Fu.IsValidHero(botTarget) -- datafeed: Planar Pocket targets heroes only (target_type 1)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, 600)
			and bot:WasRecentlyDamagedByAnyHero(1)
			and not Fu.IsChasingTarget(bot, botTarget)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not Fu.IsDisabled(botTarget)
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end
	if isRetreating then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, 1200, false, BOT_MODE_NONE)
		if
			nearbyAllies ~= nil
			and nearbyEnemies ~= nil
			and Fu.IsValidHero(nearbyEnemies[1])
			and Fu.IsInRange(bot, nearbyEnemies[1], 600)
			and Fu.IsChasingTarget(nearbyEnemies[1], bot)
			and not Fu.IsSuspiciousIllusion(nearbyEnemies[1])
			and not Fu.IsDisabled(nearbyEnemies[1])
		then
			local chaserAllies = Fu.GetNearbyHeroes(nearbyEnemies[1], 1200, false, BOT_MODE_NONE)
			if chaserAllies ~= nil and (#chaserAllies > #nearbyAllies or bot:WasRecentlyDamagedByAnyHero(1)) then
				return BOT_ACTION_DESIRE_HIGH, nearbyEnemies[1]
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
return X
