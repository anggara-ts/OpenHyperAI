-- Gyrocopter: skill build, item build, and ability use for this hero.
local X = {}
local bot = GetBot()
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local AbilityContext = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local Minion = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local sTalentList = Fu.Skill.GetTalentList(bot)
local sAbilityList = Fu.Skill.GetAbilityList(bot)
local sRole = Fu.Item.GetRoleItemsBuyList(bot)
local tTalentTreeList = { ["t25"] = { 0, 10 }, ["t20"] = { 0, 10 }, ["t15"] = { 10, 0 }, ["t10"] = { 10, 0 } }
local tAllAbilityBuildList = { { 2, 3, 3, 2, 3, 6, 3, 2, 2, 1, 6, 1, 1, 1, 6 } }
-- Support (pos 4/5): Rocket Barrage first, then Homing Missile, Flak Cannon last (Dotabuff most
-- picked order, where Gyrocopter is mostly a support). Core keeps Flak Cannon first.
if sRole == "pos_4" or sRole == "pos_5" then
	tAllAbilityBuildList = { { 1, 2, 1, 2, 1, 6, 1, 2, 2, 3, 6, 3, 3, 3, 6 } }
end
local nAbilityBuildList = Fu.Skill.GetRandomBuild(tAllAbilityBuildList)
local nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList)
local sRoleItemsBuyList = {}
-- Stratz 7.41f, week of 9 Nov 2026: pos 1, 18,900 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_1"] = {
	"item_tango",
	"item_double_branches",
	"item_faerie_fire",
	"item_magic_stick",
	"item_quelling_blade",
	"item_magic_wand",
	"item_falcon_blade",
	"item_power_treads",
	"item_lesser_crit",
	"item_ultimate_scepter",
	"item_black_king_bar",
	"item_greater_crit",
	"item_satanic",
	"item_butterfly",
	"item_ultimate_scepter_2",
	"item_travel_boots",
	"item_moon_shard",
	"item_manta",
	"item_aghanims_shard",
	"item_travel_boots_2",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 2, 7,035 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_2"] = {
	"item_tango",
	"item_double_branches",
	"item_faerie_fire",
	"item_circlet",
	"item_slippers",
	"item_magic_wand",
	"item_power_treads",
	"item_dragon_lance",
	"item_lesser_crit",
	"item_ultimate_scepter",
	"item_travel_boots",
	"item_black_king_bar",
	"item_greater_crit",
	"item_satanic",
	"item_ultimate_scepter_2",
	"item_maelstrom",
	"item_hurricane_pike",
	"item_aghanims_shard",
	"item_moon_shard",
	"item_travel_boots_2",
}
-- Support builds: Dotabuff 7-day meta has Gyrocopter mostly at support-off (pos 4).
-- Stratz 7.41f, week of 9 Nov 2026: pos 4, 36,979 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_4"] = {
	"item_tango",
	"item_blood_grenade",
	"item_double_branches",
	"item_magic_stick",
	"item_faerie_fire",
	"item_magic_wand",
	"item_arcane_boots",
	"item_glimmer_cape",
	"item_kaya",
	"item_force_staff",
	"item_cyclone",
	"item_soul_booster",
	"item_yasha_and_kaya",
	"item_octarine_core",
	"item_wind_waker",
	"item_aghanims_shard",
	"item_moon_shard",
	"item_ultimate_scepter_2",
}
-- One pair of boots in this build (user rule; Util/boots-check.js).
-- Stratz 7.41f, week of 9 Nov 2026: pos 5, 19,972 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_5"] = {
	"item_tango",
	"item_blood_grenade",
	"item_double_branches",
	"item_magic_stick",
	"item_faerie_fire",
	"item_magic_wand",
	"item_arcane_boots",
	"item_glimmer_cape",
	"item_kaya",
	"item_force_staff",
	"item_cyclone",
	"item_soul_booster",
	"item_yasha_and_kaya",
	"item_octarine_core",
	"item_aghanims_shard",
	"item_moon_shard",
	"item_ultimate_scepter_2",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 3, 3,083 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_3"] = {
	"item_tango",
	"item_double_branches",
	"item_magic_stick",
	"item_circlet",
	"item_magic_wand",
	"item_power_treads",
	"item_lesser_crit",
	"item_dragon_lance",
	"item_ultimate_scepter",
	"item_black_king_bar",
	"item_greater_crit",
	"item_satanic",
	"item_ultimate_scepter_2",
	"item_phylactery",
	"item_hurricane_pike",
	"item_aghanims_shard",
	"item_moon_shard",
}
X["sBuyList"] = sRoleItemsBuyList[sRole]
X["sSellList"] = {
	"item_black_king_bar",
	"item_quelling_blade",
	-- Sold once the item before it is owned, to keep six slots (Util/item-builds/generate.js):
	"item_butterfly",
	"item_falcon_blade",
}
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
local rocketBarrageAbility =
	SafeAbility(bot:GetAbilityByName("gyrocopter_rocket_barrage"), "gyrocopter_rocket_barrage", "gyrocopter")
local homingMissileAbility =
	SafeAbility(bot:GetAbilityByName("gyrocopter_homing_missile"), "gyrocopter_homing_missile", "gyrocopter")
local flakCannonAbility =
	SafeAbility(bot:GetAbilityByName("gyrocopter_flak_cannon"), "gyrocopter_flak_cannon", "gyrocopter")
local callDownAbility = SafeAbility(bot:GetAbilityByName("gyrocopter_call_down"), "gyrocopter_call_down", "gyrocopter")
local rocketBarrageDesire
local homingMissileDesire, homingMissileTarget
local flakCannonDesire
local callDownDesire, callDownLocation
local botTarget
local isGoingOnSomeone
local isInTeamFight
function X.SkillsComplement()
	if Fu.CanNotUseAbility(bot) then
		return
	end
	isGoingOnSomeone = Fu.IsGoingOnSomeone(bot)
	isInTeamFight = Fu.IsInTeamFight(bot, 1200)
	homingMissileDesire, homingMissileTarget = X.ConsiderHomingMissile()
	if homingMissileDesire > 0 then
		Fu.SetQueuePtToINT(bot, false)
		bot:Action_UseAbilityOnEntity(homingMissileAbility, homingMissileTarget)
		return
	end
	flakCannonDesire = X.ConsiderFlakCannon()
	if flakCannonDesire > 0 then
		Fu.SetQueuePtToINT(bot, false)
		bot:Action_UseAbility(flakCannonAbility)
		return
	end
	callDownDesire, callDownLocation = X.ConsiderCallDown()
	if callDownDesire > 0 then
		bot:Action_UseAbilityOnLocation(callDownAbility, callDownLocation)
		return
	end
	rocketBarrageDesire = X.ConsiderRocketBarrage()
	if rocketBarrageDesire > 0 then
		Fu.SetQueuePtToINT(bot, false)
		bot:Action_UseAbility(rocketBarrageAbility)
		return
	end
end
function X.ConsiderRocketBarrage()
	if not rocketBarrageAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
	end
	local radius = rocketBarrageAbility:GetSpecialValueInt("radius")
	-- datafeed: per-rocket damage is "rocket_damage"; "value" does not exist (read 0, no kill check)
	local rocketDamage = rocketBarrageAbility:GetSpecialValueInt("rocket_damage")
	local rocketsPerSecond = rocketBarrageAbility:GetSpecialValueInt("rockets_per_second")
	local duration = 3
	local abilityLevel = rocketBarrageAbility:GetLevel()
	local mpRatio = bot:GetMana() / bot:GetMaxMana()
	botTarget = Fu.GetProperTarget(bot)
	local enemiesInRadius = Fu.GetNearbyHeroes(bot, radius, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(enemiesInRadius) do
		local nearbyCreeps = bot:GetNearbyCreeps(radius, true)
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and Fu.CanKillTarget(enemyHero, rocketDamage * rocketsPerSecond * duration, DAMAGE_TYPE_MAGICAL)
			and not Fu.IsSuspiciousIllusion(enemyHero)
			and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
			and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
			and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
			and not enemyHero:HasModifier("modifier_templar_assassin_refraction_absorb")
			and nearbyCreeps ~= nil
			and #nearbyCreeps <= 1
		then
			bot:SetTarget(enemyHero)
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if isInTeamFight then
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, radius - 75, true, BOT_MODE_NONE)
		if nearbyEnemies ~= nil and #nearbyEnemies >= 1 then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if isGoingOnSomeone then
		local nearbyCreeps = bot:GetNearbyCreeps(radius, true)
		local nearbyAllies = Fu.GetNearbyHeroes(bot, radius + 150, false, BOT_MODE_NONE)
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, radius - 75, true, BOT_MODE_NONE)
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not botTarget:HasModifier("modifier_dazzle_shallow_grave")
			and not botTarget:HasModifier("modifier_templar_assassin_refraction_absorb")
			and nearbyAllies ~= nil
			and nearbyEnemies
			and #nearbyAllies >= #nearbyEnemies
			and nearbyCreeps ~= nil
			and #nearbyCreeps <= 1
		then
			bot:SetTarget(botTarget)
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsRetreating(bot) then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, radius + 200, false, BOT_MODE_NONE)
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, radius - 25, true, BOT_MODE_NONE)
		if
			nearbyAllies ~= nil
			and nearbyEnemies
			and (#nearbyEnemies > #nearbyAllies or Fu.GetHP(bot) < 0.7 and bot:WasRecentlyDamagedByAnyHero(2))
			and Fu.IsValidHero(nearbyEnemies[1])
			and Fu.CanCastOnNonMagicImmune(nearbyEnemies[1])
			and Fu.IsInRange(bot, nearbyEnemies[1], radius)
			and not Fu.IsSuspiciousIllusion(nearbyEnemies[1])
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsFarming(bot) and mpRatio > 0.5 and abilityLevel >= 2 then
		local nearbyNeutrals = bot:GetNearbyNeutralCreeps(radius)
		if nearbyNeutrals ~= nil and #nearbyNeutrals >= 2 then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if
			Fu.IsRoshan(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, radius)
			and Fu.IsAttacking(bot)
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, radius) and Fu.IsAttacking(bot) then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderHomingMissile()
	if not homingMissileAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castRange = homingMissileAbility:GetCastRange()
	local preFlightTime = homingMissileAbility:GetSpecialValueFloat("pre_flight_time")
	-- datafeed: Homing Missile damage is "hit_damage" (90/180/270/360); there is no AbilityDamage
	local damage = homingMissileAbility:GetSpecialValueInt("hit_damage")
	local mpRatio = bot:GetMana() / bot:GetMaxMana()
	botTarget = Fu.GetProperTarget(bot)
	local enemiesInRange = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(enemiesInRange) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and Fu.WillKillTarget(enemyHero, damage, DAMAGE_TYPE_MAGICAL, preFlightTime)
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
		local strongestEnemy = Fu.GetStrongestUnit(castRange, bot, true, false, 5)
		if
			strongestEnemy ~= nil
			and Fu.IsValidHero(strongestEnemy)
			and Fu.IsInRange(bot, strongestEnemy, castRange)
			and not Fu.IsSuspiciousIllusion(strongestEnemy)
			and not Fu.IsDisabled(strongestEnemy)
			and not Fu.IsTaunted(strongestEnemy)
			and not strongestEnemy:HasModifier("modifier_faceless_void_chronosphere_freeze")
			and not strongestEnemy:HasModifier("modifier_enigma_black_hole_pull")
		then
			return BOT_ACTION_DESIRE_HIGH, strongestEnemy
		end
	end
	if isGoingOnSomeone then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, castRange + 200, false, BOT_MODE_NONE)
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
		if
			Fu.IsValidHero(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not Fu.IsDisabled(botTarget)
			and not Fu.IsTaunted(botTarget)
			and not botTarget:HasModifier("modifier_faceless_void_chronosphere_freeze")
			and not botTarget:HasModifier("modifier_enigma_black_hole_pull")
			and nearbyAllies ~= nil
			and nearbyEnemies ~= nil
			and #nearbyAllies >= #nearbyEnemies
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end
	if Fu.IsRetreating(bot) then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, castRange + 200, false, BOT_MODE_NONE)
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
		if
			nearbyAllies ~= nil
			and nearbyEnemies
			and (#nearbyEnemies > #nearbyAllies or Fu.GetHP(bot) < 0.6 and bot:WasRecentlyDamagedByAnyHero(2))
			and Fu.IsValidHero(nearbyEnemies[1])
			and Fu.CanCastOnNonMagicImmune(nearbyEnemies[1])
			and not Fu.IsSuspiciousIllusion(nearbyEnemies[1])
			and not Fu.IsDisabled(nearbyEnemies[1])
			and not Fu.IsTaunted(nearbyEnemies[1])
		then
			return BOT_ACTION_DESIRE_HIGH, nearbyEnemies[1]
		end
	end
	if Fu.IsLaning(bot) and mpRatio > 0.45 then
		local nearbyLaneCreeps = bot:GetNearbyLaneCreeps(castRange, true)
		for _, creep in pairs(nearbyLaneCreeps) do
			if
				Fu.IsValid(creep)
				and (Fu.IsKeyWordUnit("ranged", creep) or Fu.IsKeyWordUnit("siege", creep))
				and creep:GetHealth() <= damage
			then
				local nearbyEnemies = Fu.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE)
				if
					nearbyEnemies ~= nil
					and #nearbyEnemies >= 1
					and GetUnitToUnitDistance(creep, nearbyEnemies[1]) <= 500
				then
					return BOT_ACTION_DESIRE_HIGH, creep
				end
			end
		end
	end
	local alliesInRange = Fu.GetNearbyHeroes(bot, castRange, false, BOT_MODE_NONE)
	for _, allyHero in pairs(alliesInRange) do
		local allyNearbyEnemies = Fu.GetNearbyHeroes(allyHero, castRange, true, BOT_MODE_NONE)
		if Fu.IsValidHero(allyHero) and Fu.IsRetreating(allyHero) and not allyHero:IsIllusion() then
			if
				allyNearbyEnemies ~= nil
				and #allyNearbyEnemies >= 1
				and Fu.IsValidHero(allyNearbyEnemies[1])
				and Fu.CanCastOnNonMagicImmune(allyNearbyEnemies[1])
				and Fu.IsInRange(bot, allyNearbyEnemies[1], castRange)
				and not Fu.IsSuspiciousIllusion(allyNearbyEnemies[1])
				and not Fu.IsDisabled(allyNearbyEnemies[1])
				and not Fu.IsTaunted(allyNearbyEnemies[1])
				and mpRatio > 0.4
			then
				return BOT_ACTION_DESIRE_HIGH, allyNearbyEnemies[1]
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function X.ConsiderFlakCannon()
	if not flakCannonAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
	end
	local radius = flakCannonAbility:GetSpecialValueInt("radius")
	local mpRatio = bot:GetMana() / bot:GetMaxMana()
	local abilityLevel = flakCannonAbility:GetLevel()
	botTarget = Fu.GetProperTarget(bot)
	local enemiesInRadius = Fu.GetNearbyHeroes(bot, radius, true, BOT_MODE_NONE)
	if isInTeamFight then
		if enemiesInRadius ~= nil and #enemiesInRadius >= 2 then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if isGoingOnSomeone then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, radius + 100, false, BOT_MODE_NONE)
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, radius, true, BOT_MODE_NONE)
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not botTarget:HasModifier("modifier_dazzle_shallow_grave")
			and not botTarget:HasModifier("modifier_templar_assassin_refraction_absorb")
			and nearbyAllies ~= nil
			and nearbyEnemies
			and #nearbyAllies >= #nearbyEnemies
		then
			if #nearbyEnemies == 1 then
				return BOT_ACTION_DESIRE_LOW
			else
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	if (Fu.IsPushing(bot) or Fu.IsDefending(bot)) and abilityLevel >= 2 then
		local nearbyLaneCreeps = bot:GetNearbyLaneCreeps(radius, true)
		if nearbyLaneCreeps ~= nil and #nearbyLaneCreeps >= 4 then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsFarming(bot) and abilityLevel >= 2 and mpRatio > 0.35 then
		local nearbyNeutrals = bot:GetNearbyNeutralCreeps(radius)
		local nearbyLaneCreeps = bot:GetNearbyLaneCreeps(radius, true)
		enemiesInRadius = Fu.GetNearbyHeroes(bot, 600, true, BOT_MODE_NONE)
		if enemiesInRadius ~= nil and #enemiesInRadius == 0 then
			if
				nearbyNeutrals ~= nil
				and (#nearbyNeutrals >= 3 or #nearbyNeutrals >= 2 and nearbyNeutrals[1]:IsAncientCreep())
			then
				return BOT_ACTION_DESIRE_HIGH
			end
			if nearbyLaneCreeps ~= nil and #nearbyLaneCreeps >= 4 then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderCallDown()
	if not callDownAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local castRange = callDownAbility:GetCastRange()
	local castPoint = callDownAbility:GetCastPoint()
	local radius = callDownAbility:GetSpecialValueInt("radius")
	-- datafeed: per-strike damage is "damage" (200/350/500); "damage_first" no longer exists
	local damage = callDownAbility:GetSpecialValueInt("damage")
	if isInTeamFight then
		local aoeLocation = bot:FindAoELocation(true, true, bot:GetLocation(), castRange, radius / 2, castPoint, 0)
		if aoeLocation.count >= 2 then
			local enemiesNearLocation = Fu.GetEnemiesNearLoc(aoeLocation.targetloc, radius)
			if enemiesNearLocation ~= nil and #enemiesNearLocation >= 2 then
				return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
			end
		end
	end
	if isGoingOnSomeone then
		local aoeLocation = bot:FindAoELocation(true, true, bot:GetLocation(), castRange, radius / 2, castPoint, 0)
		if aoeLocation.count >= 2 then
			local enemiesNearLocation = Fu.GetEnemiesNearLoc(aoeLocation.targetloc, radius)
			if enemiesNearLocation ~= nil and #enemiesNearLocation >= 2 then
				return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
			end
		end
	end
	local enemiesInRange = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(enemiesInRange) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and Fu.IsInRange(bot, enemyHero, castRange)
			and Fu.CanKillTarget(enemyHero, damage, DAMAGE_TYPE_MAGICAL)
			and not Fu.IsSuspiciousIllusion(enemyHero)
			and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
			and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
			and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
			and not enemyHero:HasModifier("modifier_templar_assassin_refraction_absorb")
		then
			return BOT_ACTION_DESIRE_HIGH, enemyHero:GetExtrapolatedLocation(1 + castPoint)
		end
	end
	if Fu.IsPushing(bot) or Fu.IsDefending(bot) then
		local nearbyLaneCreeps = bot:GetNearbyLaneCreeps(castRange, true)
		if nearbyLaneCreeps ~= nil and #nearbyLaneCreeps >= 5 then
			local aoeLocation = bot:FindAoELocation(true, false, bot:GetLocation(), castRange, radius / 2, castPoint, 0)
			if aoeLocation.count >= 4 then
				return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
return X
