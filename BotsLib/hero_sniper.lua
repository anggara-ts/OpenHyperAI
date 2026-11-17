-- Sniper: skill build, item build, and ability use for this hero.
local X = {}
local bot = GetBot()
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local ChargeTracker = require(GetScriptDirectory() .. "/FuncLib/systems/charge_tracker")
local AbilityContext = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local Minion = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local sTalentList = Fu.Skill.GetTalentList(bot)
local sAbilityList = Fu.Skill.GetAbilityList(bot)
local sRole = Fu.Item.GetRoleItemsBuyList(bot)
local tTalentTreeList = { ["t25"] = { 0, 10 }, ["t20"] = { 0, 10 }, ["t15"] = { 0, 10 }, ["t10"] = { 10, 0 } }
local tAllAbilityBuildList = { { 1, 2, 1, 3, 1, 6, 1, 2, 2, 2, 6, 3, 3, 3, 6 } }
local nAbilityBuildList = Fu.Skill.GetRandomBuild(tAllAbilityBuildList)
local nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList)
local sRoleItemsBuyList = {}
sRoleItemsBuyList["pos_1"] = {
	"item_ranged_carry_outfit",
	"item_dragon_lance",
	"item_mask_of_madness",
	"item_aghanims_shard",
	"item_maelstrom",
	"item_force_staff",
	"item_hurricane_pike",
	"item_ultimate_scepter",
	"item_travel_boots",
	"item_monkey_king_bar",
	"item_mjollnir",
	"item_greater_crit",
	"item_broken_satanic",
	"item_moon_shard",
	"item_hydras_breath",
	"item_travel_boots_2",
	"item_ultimate_scepter_2",
}
sRoleItemsBuyList["pos_2"] = {
	"item_mid_outfit",
	"item_dragon_lance",
	"item_mask_of_madness",
	"item_aghanims_shard",
	"item_maelstrom",
	"item_force_staff",
	"item_hurricane_pike",
	"item_ultimate_scepter",
	"item_travel_boots",
	"item_monkey_king_bar",
	"item_mjollnir",
	"item_greater_crit",
	"item_broken_satanic",
	"item_moon_shard",
	"item_hydras_breath",
	"item_travel_boots_2",
	"item_ultimate_scepter_2",
}
sRoleItemsBuyList["pos_4"] = sRoleItemsBuyList["pos_1"]
sRoleItemsBuyList["pos_5"] = sRoleItemsBuyList["pos_1"]
sRoleItemsBuyList["pos_3"] = sRoleItemsBuyList["pos_1"]
X["sBuyList"] = sRoleItemsBuyList[sRole]
X["sSellList"] = { "item_mjollnir", "item_magic_wand", "item_greater_crit", "item_hand_of_midas" }
if Fu.Role.IsPvNMode() or Fu.Role.IsAllShadow() then
	X["sBuyList"], X["sSellList"] = { "PvN_mid" }, {}
end
nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"] = Fu.SetUserHeroInit(nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"])
X["sSkillList"] = Fu.Skill.GetSkillList(sAbilityList, nAbilityBuildList, sTalentList, nTalentBuildList)
X["bDeafaultAbility"] = false
X["bDeafaultItem"] = false
function X.MinionThink(minion)
	Minion.MinionThink(minion)
end
local shrapnelAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[1]), "sAbilityList[1]", "sniper")
local takeAimAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[3]), "sAbilityList[3]", "sniper")
local concussiveGrenadeAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[4]), "sAbilityList[4]", "sniper")
local assassinateAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[6]), "sAbilityList[6]", "sniper")
local shrapnelDesire, shrapnelLocation
local takeAimDesire
local assassinateDesire, assassinateTarget
local concussiveGrenadeDesire, concussiveGrenadeLocation
local retainMana, botLevel, nearbyEnemies
local lastShrapnelTime = 0
local lastShrapnelLocation = Vector(0, 0)
local botTarget
function X.SkillsComplement()
	X.ConsiderTarget()
	Fu.ConsiderForMkbDisassembleMask(bot)
	if Fu.CanNotUseAbility(bot) or bot:IsInvisible() then
		return
	end
	local context = AbilityContext.Build(bot)
	retainMana = 280
	aetherRange = context.aetherRange
	botLevel = context.level
	botTarget = context.target
	nearbyEnemies = context.enemies
	assassinateDesire, assassinateTarget = X.ConsiderR()
	if assassinateDesire > 0 then
		Fu.SetQueuePtToINT(bot, true)
		bot:ActionQueue_UseAbilityOnEntity(assassinateAbility, assassinateTarget)
		return
	end
	takeAimDesire = X.ConsiderE()
	if takeAimDesire > 0 then
		bot:Action_ClearActions(false)
		bot:ActionQueue_UseAbility(takeAimAbility)
		return
	end
	shrapnelDesire, shrapnelLocation = X.ConsiderQ()
	if shrapnelDesire > 0 then
		pcall(ChargeTracker.Issued, bot, shrapnelAbility)
		Fu.SetQueuePtToINT(bot, false)
		bot:ActionQueue_UseAbilityOnLocation(shrapnelAbility, shrapnelLocation)
		lastShrapnelTime = DotaTime()
		lastShrapnelLocation = shrapnelLocation
		return
	end
	concussiveGrenadeDesire, concussiveGrenadeLocation = X.ConsiderAS()
	if concussiveGrenadeDesire > 0 then
		Fu.SetQueuePtToINT(bot, true)
		bot:ActionQueue_UseAbilityOnLocation(concussiveGrenadeAbility, concussiveGrenadeLocation)
		return
	end
end
function X.ConsiderTarget()
	if not Fu.IsRunning(bot) or bot:HasModifier("modifier_item_hurricane_pike_range") then
		return
	end
	local attackRange = bot:GetAttackRange() + 60
	if attackRange > 1600 then
		attackRange = 1600
	end
	local weakestUnit = Fu.GetAttackableWeakestUnit(bot, attackRange, true, true)
	local newTarget = nil
	if Fu.IsValidHero(botTarget) and GetUnitToUnitDistance(botTarget, bot) > attackRange and Fu.IsValidHero(weakestUnit) then
		newTarget = weakestUnit
		bot:SetTarget(newTarget)
		return
	end
end
function X.ConsiderQ()
	if not shrapnelAbility:IsFullyCastable() or DotaTime() - lastShrapnelTime < 1.5 then
		return 0
	end
	local castRange = 1600
	local abilityLevel = shrapnelAbility:GetLevel()
	local damage = (15 + 20 * (abilityLevel - 1)) * 11
	local radius = shrapnelAbility:GetAOERadius()
	local castPoint = shrapnelAbility:GetCastPoint()
	local botLocation = bot:GetLocation()
	local laneCreeps = bot:GetNearbyLaneCreeps(1600, true)
	local enemyHeroes = Fu.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE)
	local creepAoe = bot:FindAoELocation(true, false, botLocation, castRange, radius, 0.8, 0)
	local creepAoeCount = creepAoe.count
	if creepAoe == nil or Fu.GetInLocLaneCreepCount(bot, 1600, radius, creepAoe.targetloc) <= 2 then
		creepAoeCount = 0
	end
	local heroAoe = bot:FindAoELocation(true, true, botLocation, castRange, radius - 30, 0.8, 0)
	-- Typo fix: the field is .count (FindAoELocation); .cout was always nil, so this 2+ hero Shrapnel never fired.
	if
		#enemyHeroes >= 2
		and (heroAoe.count ~= nil and heroAoe.count >= 2)
		and bot:GetActiveMode() ~= BOT_MODE_LANING
		and (bot:GetActiveMode() ~= BOT_MODE_RETREAT or bot:GetActiveMode() == BOT_MODE_RETREAT and bot:GetActiveModeDesire() < 0.6)
		and not X.IsAbiltyQCastedHere(heroAoe.targetloc, radius)
	then
		return BOT_ACTION_DESIRE_HIGH, heroAoe.targetloc
	end
	if
		Fu.IsValidHero(botTarget)
		and not botTarget:HasModifier("modifier_sniper_shrapnel_slow")
		and Fu.CanCastOnNonMagicImmune(botTarget)
		and Fu.IsInRange(botTarget, bot, castRange + 300)
		and (abilityLevel >= 3 or bot:GetMana() >= retainMana)
		and not X.IsAbiltyQCastedHere(botTarget:GetLocation(), radius)
	then
		if botTarget:IsFacingLocation(Fu.GetEnemyFountain(), 30) and Fu.GetHP(botTarget) < 0.4 and Fu.IsRunning(botTarget) then
			for offset = 0, 800, 200 do
				local aheadLocation = Fu.GetLocationTowardDistanceLocation(botTarget, Fu.GetEnemyFountain(), radius + 800 - offset)
				if GetUnitToLocationDistance(bot, aheadLocation) <= castRange + 200 then
					return BOT_ACTION_DESIRE_HIGH, aheadLocation
				end
			end
		end
		local predictedLocation = Fu.GetCorrectLoc(botTarget, castPoint + 1.8)
		if Fu.GetLocationToLocationDistance(botTarget:GetLocation(), predictedLocation) > 300 and botTarget:GetMovementDirectionStability() > 0.4 then
			return BOT_ACTION_DESIRE_HIGH, predictedLocation
		end
		local distance = GetUnitToUnitDistance(bot, botTarget)
		if botTarget:IsFacingLocation(botLocation, 30) and Fu.IsMoving(botTarget) then
			if distance > 400 then
				distance = distance - 200
			end
			return BOT_ACTION_DESIRE_HIGH, Fu.GetUnitTowardDistanceLocation(bot, botTarget, distance)
		end
		if bot:IsFacingLocation(botTarget:GetLocation(), 30) then
			if distance <= castRange - 200 then
				distance = distance + 400
			else
				distance = castRange + 300
			end
			return BOT_ACTION_DESIRE_HIGH, Fu.GetUnitTowardDistanceLocation(bot, botTarget, distance)
		end
		return BOT_ACTION_DESIRE_HIGH, Fu.GetLocationTowardDistanceLocation(botTarget, Fu.GetEnemyFountain(), radius / 2)
	end
	if Fu.IsRetreating(bot) and not bot:IsInvisible() then
		local retreatAoe = bot:FindAoELocation(true, true, botLocation, castRange - 400, radius, 1.5, 0)
		if retreatAoe.count >= 2 and not X.IsAbiltyQCastedHere(retreatAoe.targetloc, radius) then
			return BOT_ACTION_DESIRE_HIGH, retreatAoe.targetloc
		end
		if bot:GetActiveModeDesire() > 0.8 then
			local closeEnemies = Fu.GetNearbyHeroes(bot, 800, true, BOT_MODE_NONE)
			for _, enemyHero in pairs(closeEnemies) do
				if Fu.IsValid(enemyHero) and bot:WasRecentlyDamagedByHero(enemyHero, 2.0) and Fu.CanCastOnNonMagicImmune(enemyHero) then
					local midpoint = (botLocation + enemyHero:GetLocation()) / 2
					if not X.IsAbiltyQCastedHere(midpoint, radius) then
						return BOT_ACTION_DESIRE_HIGH, midpoint
					end
				end
			end
		end
	end
	if
		#nearbyEnemies == 0
		and abilityLevel >= 3
		and bot:GetActiveMode() ~= BOT_MODE_ATTACK
		and bot:GetActiveMode() ~= BOT_MODE_LANING
		and bot:GetMana() >= retainMana
		and #laneCreeps >= 2
		and creepAoeCount >= 5
		and (botLevel < 25 or creepAoeCount >= 7)
		and (botLevel < 20 or GetUnitToLocationDistance(bot, creepAoe.targetloc) >= 1100)
		and not X.IsAbiltyQCastedHere(creepAoe.targetloc, radius)
	then
		return BOT_ACTION_DESIRE_HIGH, creepAoe.targetloc
	end
	if Fu.IsFarming(bot) and bot:GetMana() >= retainMana then
		local neutralCreeps = bot:GetNearbyNeutralCreeps(800)
		if #neutralCreeps >= 4 and Fu.IsValid(botTarget) and not Fu.CanKillTarget(botTarget, bot:GetAttackDamage() * 3.88, DAMAGE_TYPE_PHYSICAL) then
			local neutralAoe = bot:FindAoELocation(true, false, botLocation, castRange, radius, 0.8, 0)
			if neutralAoe.count >= 5 then
				return BOT_ACTION_DESIRE_HIGH, neutralAoe.targetloc
			end
		end
	end
	if Fu.IsDoingRoshan(bot) then
		local attackTarget = bot:GetAttackTarget()
		if
			Fu.IsValid(attackTarget)
			and Fu.IsRoshan(attackTarget)
			and Fu.IsInRange(attackTarget, bot, castRange)
			and Fu.GetManaAfter(shrapnelAbility:GetManaCost()) > 0.4
			and not attackTarget:HasModifier("modifier_sniper_shrapnel_slow")
			and not X.IsAbiltyQCastedHere(attackTarget:GetLocation(), radius)
		then
			return BOT_ACTION_DESIRE_HIGH, attackTarget:GetLocation()
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if
			Fu.IsTormentor(botTarget)
			and Fu.IsInRange(botTarget, bot, radius)
			and Fu.IsAttacking(bot)
			and not botTarget:HasModifier("modifier_sniper_shrapnel_slow")
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	if Fu.IsFarming(bot) and #nearbyEnemies == 0 and Fu.GetManaAfter(shrapnelAbility:GetManaCost()) > 0.4 and (ChargeTracker.Count(bot, shrapnelAbility) or 0) >= 2 then
		local neutralCreeps = bot:GetNearbyNeutralCreeps(castRange)
		if #neutralCreeps >= 3 then
			local neutralAoe = bot:FindAoELocation(true, false, botLocation, castRange, radius, 0.8, 0)
			if neutralAoe.count >= 3 and not X.IsAbiltyQCastedHere(neutralAoe.targetloc, radius) then
				return BOT_ACTION_DESIRE_HIGH, neutralAoe.targetloc
			end
		end
	end
	return 0
end
function X.ConsiderE()
	if not takeAimAbility:IsFullyCastable() or bot:IsDisarmed() then
		return 0
	end
	local attackRange = bot:GetAttackRange()
	local abilityLevel = takeAimAbility:GetLevel()
	local attackDamage = bot:GetAttackDamage()
	local attackTarget = bot:GetAttackTarget()
	if Fu.IsValidHero(attackTarget) and not attackTarget:IsAttackImmune() and Fu.IsInRange(bot, attackTarget, attackRange) then
		if GetHeightLevel(bot:GetLocation()) < GetHeightLevel(attackTarget:GetLocation()) then
			return BOT_ACTION_DESIRE_HIGH
		end
		if Fu.IsInRange(bot, attackTarget, attackRange - 100) and Fu.IsAttacking(bot) then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderR()
	if not assassinateAbility:IsFullyCastable() then
		return 0
	end
	local castRange = assassinateAbility:GetCastRange()
	local castPoint = assassinateAbility:GetCastPoint()
	local attackRange = bot:GetAttackRange()
	if attackRange > 1550 then
		attackRange = 1550
	end
	local damage = assassinateAbility:GetSpecialValueInt("damage")
	local projectileSpeed = assassinateAbility:GetSpecialValueInt("projectile_speed")
	local damageType = DAMAGE_TYPE_MAGICAL
	local enemyHeroes = GetUnitList(UNIT_LIST_ENEMY_HEROES)
	local enemiesInAttackRange = Fu.GetNearbyHeroes(bot, math.min(attackRange + 50, 1600), true, BOT_MODE_NONE)
	local attackTarget = enemiesInAttackRange[1]
	if Fu.IsValidHero(botTarget) and Fu.IsInRange(bot, botTarget, attackRange + 50) then
		attackTarget = botTarget
	end
	local weakestEnemy = X.GetWeakestUnitInRangeExRadius(enemyHeroes, castRange, attackRange - 300, bot)
	local channelingEnemy = X.GetChannelingUnitInRange(enemyHeroes, castRange, bot)
	local target = nil
	for _, enemyHero in pairs(enemyHeroes) do
		local hitDelay = castPoint
		if projectileSpeed > 0 then
			hitDelay = GetUnitToUnitDistance(bot, enemyHero) / projectileSpeed + castPoint
		end
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanBeAttacked(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and Fu.IsInRange(bot, enemyHero, castRange)
			and not Fu.IsInRange(bot, enemyHero, attackRange)
			and Fu.WillMagicKillTarget(bot, enemyHero, damage, hitDelay)
			and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
			and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
			and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
		then
			return BOT_ACTION_DESIRE_HIGH, enemyHero
		end
	end
	if Fu.IsValid(weakestEnemy) then
		local hitDelay = castPoint
		if projectileSpeed > 0 then
			hitDelay = GetUnitToUnitDistance(bot, weakestEnemy) / projectileSpeed + castPoint
		end
		if
			Fu.WillMagicKillTarget(bot, weakestEnemy, damage, hitDelay) or X.ShouldUseR(attackTarget, weakestEnemy, damage) and (bot:GetMana() > retainMana * 1.28 or bot:HasScepter())
		then
			target = weakestEnemy
			return BOT_ACTION_DESIRE_HIGH, target
		end
	end
	if Fu.IsValid(channelingEnemy) and not bot:IsInvisible() and not Fu.IsRetreating(bot) then
		target = channelingEnemy
		return BOT_ACTION_DESIRE_HIGH, target
	end
	return 0
end
function X.GetWeakestUnitInRangeExRadius(units, range, excludeRadius, bot)
	if units[1] == nil then
		return nil
	end
	local attackRange = bot:GetAttackRange()
	local attackDamage = bot:GetAttackDamage()
	local weakestUnit = nil
	local lowestHealth = 9999
	for _, unit in pairs(units) do
		if
			Fu.IsInRange(unit, bot, range)
			and not Fu.IsInRange(unit, bot, excludeRadius)
			and Fu.CanCastOnNonMagicImmune(unit)
			and not Fu.IsOtherAllyCanKillTarget(bot, unit)
			and unit:GetHealth() < lowestHealth
			and not unit:HasModifier("modifier_teleporting")
			and not (Fu.IsInRange(unit, bot, attackRange) and Fu.CanKillTarget(unit, attackDamage, DAMAGE_TYPE_PHYSICAL))
		then
			weakestUnit = unit
			lowestHealth = unit:GetHealth()
		end
	end
	return weakestUnit
end
function X.GetChannelingUnitInRange(units, range, bot)
	if units[1] == nil then
		return nil
	end
	local channelingUnit = nil
	for _, unit in pairs(units) do
		if
			Fu.IsInRange(unit, bot, range)
			and not unit:IsMagicImmune()
			and unit:IsChanneling()
			and not (
				unit:HasModifier("modifier_teleporting")
				and X.GetCastPoint(bot, unit) > Fu.GetModifierTime(unit, "modifier_teleporting")
			)
		then
			channelingUnit = unit
			break
		end
	end
	return channelingUnit
end
function X.GetCastPoint(bot, target)
	local castPoint = assassinateAbility:GetCastPoint()
	local distance = GetUnitToUnitDistance(bot, target)
	local travelTime = distance / 2500
	return castPoint + travelTime
end
function X.IsAbiltyQCastedHere(location, radius)
	if Fu.GetLocationToLocationDistance(lastShrapnelLocation, location) > radius * 1.14 then
		return false
	end
	return true
end
function X.ShouldUseR(attackTarget, target, damage)
	if
		Fu.IsRetreating(bot)
		or Fu.IsValidHero(attackTarget)
			and Fu.CanBeAttacked(attackTarget)
			and (GetUnitToUnitDistance(bot, attackTarget) <= bot:GetAttackRange() - 300 or Fu.CanKillTarget(
				attackTarget,
				bot:GetAttackDamage(),
				DAMAGE_TYPE_PHYSICAL
			))
	then
		return false
	end
	if Fu.IsValid(target) then
		local teamPlayers = GetTeamPlayers(GetTeam())
		for i = 1, #teamPlayers do
			local teammate = GetTeamMember(i)
			if
				Fu.IsValid(teammate)
				and teammate ~= bot
				and GetUnitToUnitDistance(teammate, target) <= 600
				and (
					teammate:IsFacingLocation(target:GetLocation(), 20)
					or not (Fu.IsValidHero(attackTarget) and GetUnitToUnitDistance(bot, attackTarget) <= bot:GetAttackRange())
				)
			then
				return true
			end
			if Fu.IsValid(teammate) and teammate:GetUnitName() == "npc_dota_hero_zuus" and not Fu.CanNotUseAbility(teammate) then
				local thundergodsWrathAbility = teammate:GetAbilityByName("zuus_thundergods_wrath")
				if thundergodsWrathAbility:IsFullyCastable() then
					local wrathDamage = thundergodsWrathAbility:GetAbilityDamage()
					if target:GetHealth() + 66 < target:GetActualIncomingDamage(wrathDamage + damage, DAMAGE_TYPE_MAGICAL) then
						return true
					end
				end
			end
		end
	end
	return false
end
function X.ConsiderAS()
	if not concussiveGrenadeAbility:IsTrained() or not concussiveGrenadeAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local radius = 375
	local castRange = concussiveGrenadeAbility:GetCastRange()
	local castPoint = concussiveGrenadeAbility:GetCastPoint()
	local manaCost = concussiveGrenadeAbility:GetManaCost()
	if Fu.IsRetreating(bot) then
		local closeEnemies = Fu.GetNearbyHeroes(bot, radius, true, BOT_MODE_NONE)
		local nearestEnemy = closeEnemies[1]
		if Fu.IsValidHero(nearestEnemy) and Fu.CanCastOnNonMagicImmune(nearestEnemy) and not nearestEnemy:IsDisarmed() then
			-- Review fix: the grenade landed on Sniper's own spot, so no knockback direction was defined
			-- for the attacker on top of him. Land it 150 toward the attacker so the attacker is pushed
			-- away from Sniper. Unverified: which way Sniper himself (self_push 1) is pushed.
			if DotaTime() - (X.lastGrenadeLog or -99) > 10 then
				X.lastGrenadeLog = DotaTime()
				pcall(print, string.format("[OHA-SNIPER] t=%.0f grenade-retreat enemy=%s dist=%d", DotaTime(), nearestEnemy:GetUnitName(), GetUnitToUnitDistance(bot, nearestEnemy)))
			end
			return BOT_ACTION_DESIRE_HIGH, Fu.GetUnitTowardDistanceLocation(bot, nearestEnemy, math.min(150, GetUnitToUnitDistance(bot, nearestEnemy)))
		end
	end
	if Fu.IsInTeamFight(bot, 1400) then
		local aoeLocation = Fu.GetAoeEnemyHeroLocation(bot, castRange, radius, 2)
		if aoeLocation ~= nil then
			return BOT_ACTION_DESIRE_HIGH, aoeLocation
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if Fu.IsValidHero(botTarget) and Fu.IsInRange(bot, botTarget, castRange) and Fu.CanCastOnNonMagicImmune(botTarget) then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
return X
