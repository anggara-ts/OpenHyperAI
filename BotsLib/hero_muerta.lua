-- Muerta: skill build, item build, and ability use for this hero.
local X = {}
local bot = GetBot()
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local AbilityContext = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local Minion = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local sTalentList = Fu.Skill.GetTalentList(bot)
local sAbilityList = Fu.Skill.GetAbilityList(bot)
local sRole = Fu.Item.GetRoleItemsBuyList(bot)
local tTalentTreeList = { ["t25"] = { 0, 10 }, ["t20"] = { 0, 10 }, ["t15"] = { 0, 10 }, ["t10"] = { 10, 0 } }
local tAllAbilityBuildList = { { 1, 2, 1, 3, 1, 6, 1, 3, 3, 3, 2, 6, 2, 2, 6 } }
local nAbilityBuildList = Fu.Skill.GetRandomBuild(tAllAbilityBuildList)
local nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList)
local sRoleItemsBuyList = {}
-- Stratz 7.41f, week of 9 Nov 2026: pos 1, 30,825 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_1"] = {
	"item_tango",
	"item_double_branches",
	"item_faerie_fire",
	"item_magic_stick",
	"item_magic_wand",
	"item_falcon_blade",
	"item_power_treads",
	"item_mjollnir",
	"item_hurricane_pike",
	-- Black King Bar instead of Shadow Blade / Silver Edge (user call: improve her build). Pierce the
	-- Veil turns her damage magical and she stands in fights; she needs the spell immunity.
	"item_black_king_bar",
	"item_blink",
	"item_greater_crit",
	"item_aghanims_shard",
	"item_swift_blink",
	"item_moon_shard",
	"item_travel_boots",
	"item_ultimate_scepter_2",
	"item_travel_boots_2",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 2, 8,036 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_2"] = {
	"item_tango",
	"item_double_branches",
	"item_faerie_fire",
	"item_circlet",
	"item_mantle",
	"item_null_talisman",
	"item_magic_wand",
	"item_falcon_blade",
	"item_power_treads",
	"item_mjollnir",
	"item_blink",
	"item_lesser_crit",
	-- Black King Bar instead of Shadow Blade / Silver Edge (user call: improve her build). Pierce the
	-- Veil turns her damage magical and she stands in fights; she needs the spell immunity.
	"item_black_king_bar",
	"item_greater_crit",
	"item_travel_boots",
	"item_swift_blink",
	"item_hydras_breath",
	"item_aghanims_shard",
	"item_moon_shard",
	"item_ultimate_scepter_2",
	"item_travel_boots_2",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 3, 1,319 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_3"] = {
	"item_tango",
	"item_double_branches",
	"item_faerie_fire",
	"item_magic_stick",
	"item_magic_wand",
	"item_null_talisman",
	"item_falcon_blade",
	"item_power_treads",
	"item_mjollnir",
	"item_lesser_crit",
	-- Black King Bar instead of Shadow Blade / Silver Edge (user call: improve her build). Pierce the
	-- Veil turns her damage magical and she stands in fights; she needs the spell immunity.
	"item_black_king_bar",
	"item_greater_crit",
	"item_monkey_king_bar",
	"item_swift_blink",
	"item_travel_boots",
	"item_aghanims_shard",
	"item_moon_shard",
	"item_ultimate_scepter_2",
	"item_travel_boots_2",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 4, 3,609 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_4"] = {
	"item_tango",
	"item_blood_grenade",
	"item_branches",
	"item_magic_stick",
	"item_circlet",
	"item_null_talisman",
	"item_magic_wand",
	"item_arcane_boots",
	"item_rod_of_atos",
	"item_force_staff",
	"item_ultimate_scepter",
	"item_gungir",
	"item_black_king_bar",
	"item_travel_boots",
	"item_ultimate_scepter_2",
	"item_sheepstick",
	"item_aghanims_shard",
	"item_moon_shard",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 5, 2,052 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_5"] = {
	"item_tango",
	"item_blood_grenade",
	"item_double_branches",
	"item_magic_stick",
	"item_faerie_fire",
	"item_magic_wand",
	"item_arcane_boots",
	"item_rod_of_atos",
	"item_ultimate_scepter",
	"item_dragon_lance",
	"item_blink",
	"item_black_king_bar",
	"item_travel_boots",
	"item_ultimate_scepter_2",
	"item_sheepstick",
	"item_aghanims_shard",
	"item_moon_shard",
}
X["sBuyList"] = sRoleItemsBuyList[sRole]
X["sSellList"] = {
	"item_black_king_bar",
	"item_quelling_blade",
	-- Sold once the item before it is owned, to keep six slots (Util/item-builds/generate.js):
	"item_greater_crit",
	"item_falcon_blade",
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
	Minion.MinionThink(minionUnit)
end
local deadShotAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[1]), "sAbilityList[1]", "muerta")
local theCallingAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[2]), "sAbilityList[2]", "muerta")
local gunslingerAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[3]), "sAbilityList[3]", "muerta")
local pierceTheVeilAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[6]), "sAbilityList[6]", "muerta")
-- Slot 4 of the ability list (ConsiderAS, "AS" = Aghanim's Shard); which ability fills it is not verified here.
local ability4 = SafeAbility(bot:GetAbilityByName(sAbilityList[4]), "sAbilityList[4]", "muerta")
local spectralSlugAbility = SafeAbility(bot:GetAbilityByName("muerta_spectral_slug"), "muerta_spectral_slug", "muerta")
local deadShotDesire, deadShotTarget
local theCallingDesire, theCallingLocation
local gunslingerDesire, pierceTheVeilDesire
local ability4Desire, ability4Target
local spectralSlugDesire, spectralSlugTarget
local minManaForCalling = 280
local botTarget = nil
function X.SkillsComplement()
	X.ConsiderTarget()
	Fu.ConsiderForMkbDisassembleMask(bot)
	if Fu.CanNotUseAbility(bot) or bot:IsInvisible() then
		return
	end
	deadShotAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[1]), "sAbilityList[1]", "muerta")
	theCallingAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[2]), "sAbilityList[2]", "muerta")
	gunslingerAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[3]), "sAbilityList[3]", "muerta")
	pierceTheVeilAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[6]), "sAbilityList[6]", "muerta")
	ability4 = SafeAbility(bot:GetAbilityByName(sAbilityList[4]), "sAbilityList[4]", "muerta")
	botTarget = Fu.GetProperTarget(bot)
	deadShotDesire, deadShotTarget = X.ConsiderQ()
	if deadShotDesire > 0 then
		bot:Action_UseAbilityOnEntity(deadShotAbility, deadShotTarget)
		return
	end
	pierceTheVeilDesire = X.ConsiderR()
	if pierceTheVeilDesire > 0 then
		Fu.SetQueuePtToINT(bot, true)
		bot:ActionQueue_UseAbility(pierceTheVeilAbility)
		return
	end
	theCallingDesire, theCallingLocation = X.ConsiderW()
	if theCallingDesire > 0 then
		Fu.SetQueuePtToINT(bot, false)
		bot:ActionQueue_UseAbilityOnLocation(theCallingAbility, theCallingLocation)
		return
	end
	spectralSlugDesire, spectralSlugTarget = X.ConsiderSpectralSlug()
	if spectralSlugDesire > 0 then
		Fu.SetQueuePtToINT(bot, false)
		bot:ActionQueue_UseAbilityOnEntity(spectralSlugAbility, spectralSlugTarget)
		return
	end
	gunslingerDesire = X.ConsiderE()
	if gunslingerDesire > 0 then
		bot:Action_ClearActions(false)
		bot:ActionQueue_UseAbility(gunslingerAbility)
		return
	end
	ability4Desire, ability4Target = X.ConsiderAS()
	if ability4Desire > 0 then
		Fu.SetQueuePtToINT(bot, true)
		bot:ActionQueue_UseAbilityOnEntity(ability4, ability4Target)
		return
	end
end
function X.ConsiderTarget()
	if not Fu.IsRunning(bot) or bot:HasModifier("modifier_item_hurricane_pike_range") then
		return
	end
	local searchRange = math.max(1600, bot:GetAttackRange() + 60)
	local weakestUnit = Fu.GetAttackableWeakestUnit(bot, searchRange, true, true)
	local currentTarget = Fu.GetProperTarget(bot)
	local newTarget = nil
	if
		Fu.IsValidHero(currentTarget)
		and GetUnitToUnitDistance(currentTarget, bot) > searchRange
		and Fu.IsValidHero(weakestUnit)
	then
		newTarget = weakestUnit
		bot:SetTarget(newTarget)
		return
	end
end
function X.ConsiderQ()
	if not deadShotAbility:IsFullyCastable() then
		return 0
	end
	local castRange = Fu.GetProperCastRange(false, bot, deadShotAbility:GetCastRange())
	local damage = deadShotAbility:GetSpecialValueInt("damage")
	local nearbyEnemies = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.IsInRange(bot, enemyHero, castRange)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and Fu.CanCastOnTargetAdvanced(enemyHero)
			and enemyHero:IsChanneling()
			and not Fu.IsSuspiciousIllusion(enemyHero)
		then
			return BOT_ACTION_DESIRE_HIGH, enemyHero, "Q-InterruptChannel"
		end
	end
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.IsInRange(bot, enemyHero, castRange)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and Fu.CanCastOnTargetAdvanced(enemyHero)
			-- Dead Shot is magic damage (datafeed); this used to check physical.
			and Fu.CanKillTarget(enemyHero, damage, DAMAGE_TYPE_MAGICAL)
			and not Fu.IsSuspiciousIllusion(enemyHero)
		then
			return BOT_ACTION_DESIRE_HIGH, enemyHero, "Q-Kill"
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidHero(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.CanCastOnTargetAdvanced(botTarget)
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget, "Q-Attack"
		end
	end
	if Fu.IsRetreating(bot) then
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
				and bot:WasRecentlyDamagedByHero(enemyHero, 3.0)
			then
				-- On the hero hitting her (it used to go on her attack target botTarget).
				return BOT_ACTION_DESIRE_HIGH, enemyHero, "Q-Retreat"
			end
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if Fu.IsRoshan(botTarget) and Fu.IsInRange(bot, botTarget, castRange) and Fu.IsAttacking(bot) then
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, castRange) and Fu.IsAttacking(bot) then
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderW()
	if not theCallingAbility:IsFullyCastable() then
		return 0
	end
	local castRange = theCallingAbility:GetCastRange() + 200
	local abilityLevel = theCallingAbility:GetLevel()
	local radius = theCallingAbility:GetAOERadius()
	local castPoint = theCallingAbility:GetCastPoint()
	local botLocation = bot:GetLocation()
	local nearbyEnemies = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.IsInRange(bot, enemyHero, castRange)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and enemyHero:IsChanneling()
			and not Fu.IsSuspiciousIllusion(enemyHero)
		then
			return BOT_ACTION_DESIRE_HIGH, enemyHero:GetLocation()
		end
	end
	local aoe = bot:FindAoELocation(true, true, botLocation, castRange, radius - 30, 0.8, 0)
	-- FindAoELocation's field is "count"; the old ".cout" typo was always nil, so this never fired.
	if
		#nearbyEnemies >= 2
		and (aoe.count ~= nil and aoe.count >= 2)
		and bot:GetActiveMode() ~= BOT_MODE_LANING
		and (
			bot:GetActiveMode() ~= BOT_MODE_RETREAT
			or bot:GetActiveMode() == BOT_MODE_RETREAT and bot:GetActiveModeDesire() < 0.6
		)
	then
		return BOT_ACTION_DESIRE_HIGH, aoe.targetloc
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidHero(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(botTarget, bot, castRange + 300)
			and (abilityLevel >= 3 or bot:GetMana() >= minManaForCalling)
		then
			if
				botTarget:IsFacingLocation(Fu.GetEnemyFountain(), 30)
				and Fu.GetHP(botTarget) < 0.4
				and Fu.IsRunning(botTarget)
			then
				for offset = 0, 800, 200 do
					local location =
						Fu.GetLocationTowardDistanceLocation(botTarget, Fu.GetEnemyFountain(), radius + 800 - offset)
					if GetUnitToLocationDistance(bot, location) <= castRange + 200 then
						return BOT_ACTION_DESIRE_HIGH, location
					end
				end
			end
			local predictedLocation = Fu.GetCorrectLoc(botTarget, castPoint + 1.8)
			if
				Fu.GetLocationToLocationDistance(botTarget:GetLocation(), predictedLocation) > 300
				and botTarget:GetMovementDirectionStability() > 0.4
			then
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
			return BOT_ACTION_DESIRE_HIGH,
				Fu.GetLocationTowardDistanceLocation(botTarget, Fu.GetEnemyFountain(), radius / 2)
		end
	end
	if Fu.IsRetreating(bot) and not bot:IsInvisible() then
		local retreatAoe = bot:FindAoELocation(true, true, botLocation, castRange - 400, radius, 1.5, 0)
		if retreatAoe.count >= 2 then
			return BOT_ACTION_DESIRE_HIGH, retreatAoe.targetloc
		end
		if bot:GetActiveModeDesire() > 0.8 then
			local nearbyEnemies = Fu.GetNearbyHeroes(bot, 800, true, BOT_MODE_NONE)
			for _, enemyHero in pairs(nearbyEnemies) do
				if
					Fu.IsValid(enemyHero)
					and bot:WasRecentlyDamagedByHero(enemyHero, 2.0)
					and Fu.CanCastOnNonMagicImmune(enemyHero)
				then
					local location = (botLocation + enemyHero:GetLocation()) / 2
					return BOT_ACTION_DESIRE_HIGH, location
				end
			end
		end
	end
	if Fu.IsFarming(bot) and bot:GetMana() >= minManaForCalling then
		local neutralCreeps = bot:GetNearbyNeutralCreeps(800)
		if
			#neutralCreeps >= 4
			and Fu.IsValid(botTarget)
			and not Fu.CanKillTarget(botTarget, bot:GetAttackDamage() * 3.88, DAMAGE_TYPE_PHYSICAL)
		then
			local creepAoe = bot:FindAoELocation(true, false, botLocation, castRange, radius, 0.8, 0)
			if creepAoe.count >= 5 then
				return BOT_ACTION_DESIRE_HIGH, creepAoe.targetloc
			end
		end
	end
	if bot:GetActiveMode() == BOT_MODE_ROSHAN then
		local attackTarget = bot:GetAttackTarget()
		if Fu.IsValid(attackTarget) and Fu.GetHP(attackTarget) > 0.5 and Fu.IsInRange(attackTarget, bot, 600) then
			local nearbyAllies = Fu.GetNearbyHeroes(bot, 800, false, BOT_MODE_ROSHAN)
			if #nearbyAllies >= 4 then
				return BOT_ACTION_DESIRE_HIGH, attackTarget:GetLocation()
			end
		end
	end
	return 0
end
function X.ConsiderE()
	if not gunslingerAbility:IsTrained() or not gunslingerAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
	end
	if not gunslingerAbility:GetToggleState() then
		return BOT_ACTION_DESIRE_HIGH
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderR()
	if not pierceTheVeilAbility:IsFullyCastable() then
		return 0
	end
	local attackRange = bot:GetAttackRange()
	local nearbyEnemies = Fu.GetNearbyHeroes(bot, 1000, true, BOT_MODE_NONE)
	if Fu.IsRetreating(bot) then
		if bot:WasRecentlyDamagedByAnyHero(2.0) and #nearbyEnemies > 0 and Fu.GetHP(bot) < 0.5 then
			return BOT_ACTION_DESIRE_MODERATE
		end
	end
	if Fu.IsWithoutTarget(bot) and Fu.GetAttackProjectileDamageByRange(bot, 800) >= bot:GetHealth() then
		return BOT_ACTION_DESIRE_MODERATE
	end
	-- Engage (was switched off with "and false"): her target in attack range with 40-90% HP left,
	-- not magic immune (Pierce the Veil turns her attacks into magic damage, datafeed).
	if Fu.IsGoingOnSomeone(bot) then
		local target = Fu.GetProperTarget(bot)
		if
			Fu.IsValidHero(target)
			and Fu.IsInRange(target, bot, attackRange + 50)
			and not target:IsMagicImmune()
			and not Fu.IsSuspiciousIllusion(target)
		then
			local targetHpRatio = Fu.GetHP(target)
			if targetHpRatio >= 0.4 and targetHpRatio <= 0.9 then
				return BOT_ACTION_DESIRE_HIGH
			end
			if
				target:HasModifier("modifier_item_ethereal_blade_ethereal")
				or target:HasModifier("modifier_necrophos_death_seeker_ethereal")
				or target:HasModifier("modifier_necrolyte_sadist_active")
				or target:HasModifier("modifier_pugna_decrepify")
				or target:HasModifier("modifier_ghost_state")
			then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	if not bot:IsMagicImmune() and not bot:IsInvulnerable() and Fu.IsInTeamFight(bot) then
		if Fu.GetEnemyCount(bot, 1000) >= 2 then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	return 0
end
function X.ConsiderAS()
	if not ability4:IsTrained() or not ability4:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local castRange = ability4:GetCastRange() + 200
	local nearbyEnemies = Fu.GetAroundEnemyHeroList(castRange + 200)
	if Fu.IsRetreating(bot) and (bot:WasRecentlyDamagedByAnyHero(3.0) or bot:GetActiveModeDesire() > 0.7) then
		for _, enemyHero in pairs(nearbyEnemies) do
			-- Only an enemy already in Spectral Slug's cast range (500, game data): the list reaches 900, so
			-- she used to walk up to 400 toward the enemy while retreating to cast it.
			if
				Fu.IsValid(enemyHero)
				and Fu.IsInRange(bot, enemyHero, ability4:GetCastRange())
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
				and not Fu.IsDisabled(enemyHero)
				and not enemyHero:IsDisarmed()
			then
				local castTarget = enemyHero
				local castReason = "撤退"
				return BOT_ACTION_DESIRE_HIGH, castTarget, castReason
			end
		end
	end
	if Fu.IsInTeamFight(bot, 1200) then
		local bestTarget = nil
		local highestDamage = 0
		local targetableCount = 0
		for _, enemyHero in pairs(nearbyEnemies) do
			if Fu.IsValid(enemyHero) and Fu.CanCastOnNonMagicImmune(enemyHero) then
				targetableCount = targetableCount + 1
				if
					Fu.CanCastOnTargetAdvanced(enemyHero)
					and not Fu.IsDisabled(enemyHero)
					and not enemyHero:IsDisarmed()
				then
					local estimatedDamage = enemyHero:GetEstimatedDamageToTarget(true, bot, 6.0, DAMAGE_TYPE_ALL)
					if estimatedDamage > highestDamage then
						highestDamage = estimatedDamage
						bestTarget = enemyHero
					end
				end
			end
		end
		if bestTarget ~= nil and targetableCount >= 2 and Fu.IsInRange(bot, bestTarget, castRange + 150) then
			local castTarget = bestTarget
			local castReason = "团战控制输出"
			return BOT_ACTION_DESIRE_HIGH, castTarget, castReason
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		local target = Fu.GetProperTarget(bot)
		if Fu.IsValidHero(target) and Fu.IsInRange(bot, target, castRange) and Fu.CanCastOnNonMagicImmune(target) then
			return BOT_ACTION_DESIRE_HIGH, target
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.ConsiderSpectralSlug()
	if not Fu.CanCastAbility(spectralSlugAbility) then
		return BOT_ACTION_DESIRE_NONE
	end
	local castRange = spectralSlugAbility:GetCastRange()
	local castPoint = spectralSlugAbility:GetCastPoint()
	local damage = spectralSlugAbility:GetSpecialValueInt("damage")
	local projectileSpeed = spectralSlugAbility:GetSpecialValueInt("projectile_speed")
	local nearbyEnemies = bot:GetNearbyHeroes(castRange + 300, true, BOT_MODE_NONE)
	local nearbyAllies = bot:GetNearbyHeroes(1600, false, BOT_MODE_NONE)
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanBeAttacked(enemyHero)
			and Fu.IsInRange(bot, enemyHero, castRange + 300)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and Fu.CanCastOnTargetAdvanced(enemyHero)
			and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
			and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
			and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
			and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
		then
			local hitDelay = GetUnitToUnitDistance(bot, enemyHero) / projectileSpeed + castPoint
			if Fu.WillKillTarget(enemyHero, damage, DAMAGE_TYPE_MAGICAL, hitDelay) then
				return BOT_ACTION_DESIRE_HIGH, enemyHero
			end
			local alliesTargetingEnemy = Fu.GetHeroesTargetingUnit(nearbyAllies, enemyHero)
			if Fu.IsGoingOnSomeone(bot) then
				if
					not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
					and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
					and Fu.GetHP(enemyHero) < 0.5
					and #alliesTargetingEnemy <= 1
				then
					return BOT_ACTION_DESIRE_HIGH, enemyHero
				end
			end
		end
	end
	if Fu.IsRetreating(bot) and not Fu.IsRealInvisible(bot) then
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.CanBeAttacked(enemyHero)
				and Fu.IsInRange(bot, enemyHero, castRange)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
				and bot:WasRecentlyDamagedByHero(enemyHero, 3.0)
				and not Fu.IsDisabled(enemyHero)
				and not enemyHero:IsDisarmed()
				and not enemyHero:HasModifier("modifier_muerta_spectral_slug_ethereal")
			then
				local alliesTargetingEnemy = Fu.GetHeroesTargetingUnit(nearbyAllies, enemyHero)
				if #alliesTargetingEnemy == 0 then
					return BOT_ACTION_DESIRE_HIGH, enemyHero
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
return X
