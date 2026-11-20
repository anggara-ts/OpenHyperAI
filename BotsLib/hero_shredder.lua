-- Shredder: skill build, item build, and ability use for this hero.
local X = {}
local bot = GetBot()
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local AbilityContext = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local Minion = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local sTalentList = Fu.Skill.GetTalentList(bot)
local sAbilityList = Fu.Skill.GetAbilityList(bot)
local sRole = Fu.Item.GetRoleItemsBuyList(bot)
local tTalentTreeList = { ["t25"] = { 0, 10 }, ["t20"] = { 0, 10 }, ["t15"] = { 0, 10 }, ["t10"] = { 10, 0 } }
local tAllAbilityBuildList = { { 1, 3, 1, 2, 1, 6, 1, 2, 2, 2, 6, 3, 3, 3, 6 } }
local nAbilityBuildList = Fu.Skill.GetRandomBuild(tAllAbilityBuildList)
local nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList)
local sUtility = "item_team_aura"
local sRoleItemsBuyList = {}
-- Stratz 7.41f, week of 9 Nov 2026: pos 2, 10,978 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_2"] = {
	"item_tango",
	"item_double_branches",
	"item_quelling_blade",
	"item_gauntlets",
	"item_faerie_fire",
	"item_magic_wand",
	"item_soul_ring",
	"item_arcane_boots",
	"item_kaya",
	"item_blink",
	"item_kaya_and_sange",
	"item_ultimate_scepter",
	"item_shivas_guard",
	"item_aghanims_shard",
	"item_sheepstick",
	"item_overwhelming_blink",
	"item_ultimate_scepter_2",
	"item_consecrated_wraps",
	"item_moon_shard",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 3, 108,570 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_3"] = {
	"item_tango",
	"item_double_gauntlets",
	"item_double_branches",
	"item_quelling_blade",
	"item_bracer",
	"item_magic_wand",
	"item_soul_ring",
	"item_arcane_boots",
	"item_kaya_and_sange",
	"item_blink",
	"item_pers",
	sUtility,
	"item_shivas_guard",
	"item_ultimate_scepter",
	"item_aghanims_shard",
	"item_overwhelming_blink",
	"item_ultimate_scepter_2",
	"item_consecrated_wraps",
	"item_moon_shard",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 1, 1,188 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_1"] = {
	"item_tango",
	"item_double_branches",
	"item_double_gauntlets",
	"item_quelling_blade",
	"item_bracer",
	"item_magic_wand",
	"item_soul_ring",
	"item_arcane_boots",
	"item_kaya_and_sange",
	"item_blink",
	"item_pers",
	sUtility,
	"item_shivas_guard",
	"item_ultimate_scepter",
	"item_aghanims_shard",
	"item_travel_boots",
	"item_overwhelming_blink",
	"item_ultimate_scepter_2",
	"item_consecrated_wraps",
	"item_moon_shard",
	"item_travel_boots_2",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 4, 1,892 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_4"] = {
	"item_tango",
	"item_double_branches",
	"item_gauntlets",
	"item_magic_stick",
	"item_bracer",
	"item_magic_wand",
	"item_soul_ring",
	"item_arcane_boots",
	"item_kaya",
	"item_blink",
	"item_kaya_and_sange",
	"item_pers",
	sUtility,
	"item_aghanims_shard",
	"item_ultimate_scepter",
	"item_heart",
	"item_ultimate_scepter_2",
	"item_consecrated_wraps",
	"item_moon_shard",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 5 has 492 matches, built from pos 4 (1,892) (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_5"] = sRoleItemsBuyList["pos_4"]
X["sBuyList"] = sRoleItemsBuyList[sRole]
X["sSellList"] = {
	"item_black_king_bar",
	"item_quelling_blade",
	-- Sold once the item before it is owned, to keep six slots (Util/item-builds/generate.js):
	"item_ultimate_scepter",
	"item_pers",
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
local whirlingDeathAbility =
	SafeAbility(bot:GetAbilityByName("shredder_whirling_death"), "shredder_whirling_death", "shredder")
local timberChainAbility =
	SafeAbility(bot:GetAbilityByName("shredder_timber_chain"), "shredder_timber_chain", "shredder")
local reactiveArmorAbility =
	SafeAbility(bot:GetAbilityByName("shredder_reactive_armor"), "shredder_reactive_armor", "shredder")
local chakramAbility = SafeAbility(bot:GetAbilityByName("shredder_chakram"), "shredder_chakram", "shredder")
local returnChakramAbility =
	SafeAbility(bot:GetAbilityByName("shredder_return_chakram"), "shredder_return_chakram", "shredder")
local flamethrowerAbility =
	SafeAbility(bot:GetAbilityByName("shredder_flamethrower"), "shredder_flamethrower", "shredder")
local whirlingDeathDesire
local timberChainDesire, timberChainLocation
local reactiveArmorDesire
local chakramDesire, chakramLocation
local returnChakramDesire
local flamethrowerDesire
local chakramTravelTime = 0
local chakramLandLocation
local chakramFlightTime = 0
local chakramCastTime = 0
local botTarget
local isGoingOnSomeone
local isRetreating
local hpRatio
function X.SkillsComplement()
	if Fu.CanNotUseAbility(bot) then
		return
	end
	isGoingOnSomeone = Fu.IsGoingOnSomeone(bot)
	isRetreating = Fu.IsRetreating(bot)
	hpRatio = Fu.GetHP(bot)
	returnChakramDesire = X.ConsiderChakramReturn()
	if returnChakramDesire > 0 then
		bot:Action_UseAbility(returnChakramAbility)
		chakramLandLocation = bot:GetLocation()
		return
	end
	chakramDesire, chakramLocation, chakramTravelTime = X.ConsiderChakram()
	if chakramDesire > 0 then
		bot:Action_UseAbilityOnLocation(chakramAbility, chakramLocation)
		chakramLandLocation = chakramLocation
		chakramCastTime = DotaTime()
		chakramFlightTime = chakramTravelTime
		return
	end
	timberChainDesire, timberChainLocation = X.ConsiderTimberChain()
	if timberChainDesire > 0 then
		bot:Action_UseAbilityOnLocation(timberChainAbility, timberChainLocation)
		return
	end
	whirlingDeathDesire = X.ConsiderWhirlingDeath()
	if whirlingDeathDesire > 0 then
		bot:Action_UseAbility(whirlingDeathAbility)
		return
	end
	reactiveArmorDesire = X.ConsiderReactiveArmor()
	if reactiveArmorDesire > 0 then
		bot:Action_UseAbility(reactiveArmorAbility)
		return
	end
	flamethrowerDesire = X.ConsiderFlamethrower()
	if flamethrowerDesire > 0 then
		bot:Action_UseAbility(flamethrowerAbility)
		return
	end
end
function X.ConsiderWhirlingDeath()
	if not whirlingDeathAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
	end
	local radius = whirlingDeathAbility:GetSpecialValueInt("whirling_radius")
	local damage = whirlingDeathAbility:GetSpecialValueInt("whirling_damage")
	local manaCost = whirlingDeathAbility:GetManaCost()
	local mpRatio = bot:GetMana() / bot:GetMaxMana()
	botTarget = Fu.GetProperTarget(bot)
	local nearbyEnemies = bot:GetNearbyHeroes(radius, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and Fu.IsInRange(bot, enemyHero, radius)
			and Fu.CanKillTarget(enemyHero, damage, DAMAGE_TYPE_PURE)
			and not Fu.IsSuspiciousIllusion(enemyHero)
			and not enemyHero:HasModifier("modifier_abaddon_aphotic_shield")
			and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
			and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
			and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
			and not enemyHero:HasModifier("modifier_templar_assassin_refraction_absorb")
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if isGoingOnSomeone then
		local nearbyAllies = bot:GetNearbyHeroes(700, false, BOT_MODE_NONE)
		local nearbyEnemyHeroes = bot:GetNearbyHeroes(radius, true, BOT_MODE_NONE)
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, radius)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not botTarget:HasModifier("modifier_abaddon_aphotic_shield")
			and not botTarget:HasModifier("modifier_dazzle_shallow_grave")
			and not botTarget:HasModifier("modifier_templar_assassin_refraction_absorb")
			and nearbyAllies ~= nil
			and nearbyEnemyHeroes ~= nil
			and #nearbyAllies >= #nearbyEnemyHeroes
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if isRetreating then
		local nearbyAllies = bot:GetNearbyHeroes(700, false, BOT_MODE_NONE)
		local nearbyEnemyHeroes = bot:GetNearbyHeroes(radius, true, BOT_MODE_NONE)
		if
			nearbyAllies ~= nil
			and nearbyEnemyHeroes
			-- was "hpRatio and ...": a number is always true, so the HP part did nothing; 0.51 as in Reactive Armor.
			and (#nearbyEnemyHeroes > #nearbyAllies or hpRatio < 0.51 and bot:WasRecentlyDamagedByAnyHero(3))
			and Fu.IsValidHero(nearbyEnemyHeroes[1])
			and Fu.CanCastOnNonMagicImmune(nearbyEnemyHeroes[1])
			and Fu.IsInRange(bot, nearbyEnemyHeroes[1], radius)
			and not Fu.IsSuspiciousIllusion(nearbyEnemyHeroes[1])
			and not nearbyEnemyHeroes[1]:HasModifier("modifier_abaddon_aphotic_shield")
			and not nearbyEnemyHeroes[1]:HasModifier("modifier_abaddon_borrowed_time")
			and not nearbyEnemyHeroes[1]:HasModifier("modifier_dazzle_shallow_grave")
			and not nearbyEnemyHeroes[1]:HasModifier("modifier_oracle_false_promise_timer")
			and not nearbyEnemyHeroes[1]:HasModifier("modifier_templar_assassin_refraction_absorb")
		then
			X.LogRetreatHp("whirling-death", #nearbyEnemyHeroes, #nearbyAllies)
			return BOT_ACTION_DESIRE_MODERATE
		end
	end
	if Fu.IsPushing(bot) or Fu.IsDefending(bot) then
		local laneCreeps = bot:GetNearbyLaneCreeps(radius, true)
		if laneCreeps ~= nil and #laneCreeps >= 3 and mpRatio > 0.2 then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsFarming(bot) then
		local laneCreeps = bot:GetNearbyLaneCreeps(radius, true)
		local neutralCreeps = bot:GetNearbyNeutralCreeps(radius)
		if
			neutralCreeps ~= nil and #neutralCreeps >= 2
			or laneCreeps ~= nil and #laneCreeps >= 4 and mpRatio > 0.33
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsLaning(bot) and Fu.IsAllowedToSpam(bot, manaCost) then
		local laneCreeps = bot:GetNearbyLaneCreeps(radius, true)
		for _, creep in pairs(laneCreeps) do
			if
				Fu.IsValid(creep)
				and (Fu.IsKeyWordUnit("ranged", creep) or Fu.IsKeyWordUnit("siege", creep))
				and creep:GetHealth() <= damage
			then
				local nearbyEnemyHeroes = bot:GetNearbyHeroes(1600, true, BOT_MODE_NONE)
				if
					nearbyEnemyHeroes ~= nil
					and #nearbyEnemyHeroes >= 1
					and GetUnitToUnitDistance(creep, nearbyEnemyHeroes[1]) <= 600
				then
					return BOT_ACTION_DESIRE_HIGH
				end
			end
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if
			Fu.IsRoshan(botTarget)
			and Fu.CanBeAttacked(botTarget)
			and Fu.IsInRange(bot, botTarget, radius)
			and Fu.GetHP(botTarget) > 0.25
			and Fu.IsAttacking(bot)
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if
			Fu.IsTormentor(botTarget)
			and Fu.IsInRange(bot, botTarget, radius)
			and Fu.GetHP(botTarget) > 0.5
			and Fu.IsAttacking(bot)
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderTimberChain()
	if not timberChainAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local castPoint = timberChainAbility:GetCastPoint()
	local radius = timberChainAbility:GetSpecialValueInt("chain_radius")
	local speed = timberChainAbility:GetSpecialValueInt("speed")
	local castRange = Fu.GetProperCastRange(false, bot, timberChainAbility:GetCastRange())
	local damage = timberChainAbility:GetSpecialValueInt("damage")
	local whirlingDamage = whirlingDeathAbility:GetSpecialValueInt("whirling_damage")
	botTarget = Fu.GetProperTarget(bot)
	if Fu.IsStuck(bot) then
		local escapeLocation = Fu.GetEscapeLoc()
		return BOT_ACTION_DESIRE_HIGH, Fu.Site.GetXUnitsTowardsLocation(bot, escapeLocation, castRange)
	end
	if isGoingOnSomeone then
		local nearbyAllies = bot:GetNearbyHeroes(castRange, false, BOT_MODE_NONE)
		local nearbyEnemyHeroes = bot:GetNearbyHeroes(castRange, true, BOT_MODE_NONE)
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not botTarget:HasModifier("modifier_faceless_void_chronosphere_freeze")
			and not Fu.AreTreesBetween(bot, botTarget:GetLocation(), radius)
			and nearbyAllies ~= nil
			and nearbyEnemyHeroes ~= nil
			and #nearbyAllies >= #nearbyEnemyHeroes
		then
			local travelTime = GetUnitToUnitDistance(bot, botTarget) / speed + castPoint
			local bestTree =
				Fu.GetBestTree(bot, botTarget:GetExtrapolatedLocation(travelTime), botTarget, castRange, radius)
			if bestTree ~= nil then
				if
					bot:GetLevel() < 6
					and whirlingDeathAbility:IsTrained()
					and not Fu.CanKillTarget(botTarget, damage + whirlingDamage, DAMAGE_TYPE_PURE)
				then
					return BOT_ACTION_DESIRE_LOW, GetTreeLocation(bestTree)
				end
				return BOT_ACTION_DESIRE_HIGH, GetTreeLocation(bestTree)
			end
		end
	end
	if isRetreating and bot:DistanceFromFountain() > 600 then
		local nearbyAllies = bot:GetNearbyHeroes(castRange, false, BOT_MODE_NONE)
		local nearbyEnemyHeroes = bot:GetNearbyHeroes(castRange, true, BOT_MODE_NONE)
		if
			nearbyAllies ~= nil
			and nearbyEnemyHeroes ~= nil
			-- was "hpRatio and ...": a number is always true, so the HP part did nothing; 0.51 as in Reactive Armor.
			and (#nearbyEnemyHeroes > #nearbyAllies or hpRatio < 0.51 and bot:WasRecentlyDamagedByAnyHero(3))
			and Fu.IsValidHero(nearbyEnemyHeroes[1])
			and Fu.IsInRange(bot, nearbyEnemyHeroes[1], 500)
			and not Fu.IsSuspiciousIllusion(nearbyEnemyHeroes[1])
			and not Fu.IsDisabled(nearbyEnemyHeroes[1])
		then
			local retreatTreeLocation = Fu.GetBestRetreatTree(bot, castRange)
			if retreatTreeLocation ~= nil then
				X.LogRetreatHp("timber-chain", #nearbyEnemyHeroes, #nearbyAllies)
				return BOT_ACTION_DESIRE_HIGH, retreatTreeLocation
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.ConsiderReactiveArmor()
	if not reactiveArmorAbility:IsFullyCastable() or reactiveArmorAbility:IsPassive() or not bot:HasScepter() then
		return BOT_ACTION_DESIRE_NONE
	end
	botTarget = Fu.GetProperTarget(bot)
	if isGoingOnSomeone then
		local nearbyAllies = bot:GetNearbyHeroes(800, false, BOT_MODE_NONE)
		local nearbyEnemyHeroes = bot:GetNearbyHeroes(600, true, BOT_MODE_NONE)
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, 500)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not Fu.IsDisabled(botTarget)
			and not botTarget:HasModifier("modifier_faceless_void_chronosphere_freeze")
			and nearbyAllies ~= nil
			and nearbyEnemyHeroes ~= nil
			and (#nearbyAllies >= #nearbyEnemyHeroes or hpRatio < 0.51)
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if isRetreating then
		local nearbyEnemyHeroes = bot:GetNearbyHeroes(600, true, BOT_MODE_NONE)
		if
			nearbyEnemyHeroes ~= nil
			and #nearbyEnemyHeroes >= 1
			and hpRatio < 0.51
			and bot:WasRecentlyDamagedByAnyHero(1.5)
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderChakram()
	if not chakramAbility:IsFullyCastable() or chakramAbility:IsHidden() then
		return BOT_ACTION_DESIRE_NONE, 0, 0
	end
	local castRange = Fu.GetProperCastRange(false, bot, chakramAbility:GetCastRange())
	local castPoint = chakramAbility:GetCastPoint()
	local radius = chakramAbility:GetSpecialValueFloat("radius")
	local speed = chakramAbility:GetSpecialValueFloat("speed")
	local manaCost = chakramAbility:GetManaCost()
	local damage = chakramAbility:GetSpecialValueInt("pass_damage") * (1 + bot:GetSpellAmp())
	local mpRatio = bot:GetMana() / bot:GetMaxMana()
	botTarget = Fu.GetProperTarget(bot)
	if isGoingOnSomeone then
		local nearbyAllies = bot:GetNearbyHeroes(castRange + 100, false, BOT_MODE_NONE)
		local nearbyEnemyHeroes = bot:GetNearbyHeroes(castRange, true, BOT_MODE_NONE)
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not botTarget:HasModifier("modifier_abaddon_aphotic_shield")
			and not botTarget:HasModifier("modifier_dazzle_shallow_grave")
			and not botTarget:HasModifier("modifier_templar_assassin_refraction_absorb")
			and nearbyAllies ~= nil
			and nearbyEnemyHeroes ~= nil
			and #nearbyAllies >= #nearbyEnemyHeroes
		then
			local ultLocation = Fu.GetUltLoc(bot, botTarget, manaCost, castRange, speed)
			if ultLocation ~= nil then
				local travelTime = GetUnitToLocationDistance(bot, ultLocation) / speed + castPoint
				return BOT_ACTION_DESIRE_HIGH, botTarget:GetExtrapolatedLocation(travelTime), travelTime
			end
		end
	end
	if isRetreating then
		local nearbyAllies = bot:GetNearbyHeroes(castRange + 100, false, BOT_MODE_NONE)
		local nearbyEnemyHeroes = bot:GetNearbyHeroes(castRange, true, BOT_MODE_NONE)
		if
			nearbyAllies ~= nil
			and nearbyEnemyHeroes ~= nil
			-- was "hpRatio and ...": a number is always true, so the HP part did nothing; 0.51 as in Reactive Armor.
			and (#nearbyEnemyHeroes > #nearbyAllies or hpRatio < 0.51 and bot:WasRecentlyDamagedByAnyHero(3))
			and Fu.IsValidHero(nearbyEnemyHeroes[1])
			and Fu.CanCastOnNonMagicImmune(nearbyEnemyHeroes[1])
			and Fu.IsInRange(bot, nearbyEnemyHeroes[1], 500)
			and not Fu.IsSuspiciousIllusion(nearbyEnemyHeroes[1])
			and not Fu.IsDisabled(nearbyEnemyHeroes[1])
		then
			local travelTime = GetUnitToUnitDistance(bot, nearbyEnemyHeroes[1]) / speed + castPoint
			X.LogRetreatHp("chakram", #nearbyEnemyHeroes, #nearbyAllies)
			return BOT_ACTION_DESIRE_HIGH, nearbyEnemyHeroes[1]:GetExtrapolatedLocation(travelTime), travelTime
		end
	end
	if Fu.IsDefending(bot) or Fu.IsPushing(bot) then
		local aoeLocation = bot:FindAoELocation(true, false, bot:GetLocation(), castRange, radius, castPoint, 0)
		if aoeLocation.count >= 4 and mpRatio > 0.33 then
			local travelTime = GetUnitToLocationDistance(bot, aoeLocation.targetloc) / speed + castPoint
			return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc, travelTime
		end
	end
	if Fu.IsFarming(bot) then
		local neutralCreeps = bot:GetNearbyNeutralCreeps(castRange)
		local aoeLocation = bot:FindAoELocation(true, false, bot:GetLocation(), castRange, radius, castPoint, 0)
		if neutralCreeps ~= nil and #neutralCreeps >= 3 and aoeLocation.count >= 3 and mpRatio > 0.45 then
			local travelTime = GetUnitToLocationDistance(bot, aoeLocation.targetloc) / speed + castPoint
			return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc, travelTime
		end
	end
	if Fu.IsLaning(bot) then
		local laneCreeps = bot:GetNearbyLaneCreeps(castRange, true)
		for _, creep in pairs(laneCreeps) do
			if
				Fu.IsValid(creep)
				and (Fu.IsKeyWordUnit("ranged", creep) or Fu.IsKeyWordUnit("siege", creep))
				and creep:GetHealth() <= damage
			then
				local nearbyEnemyHeroes = bot:GetNearbyHeroes(1600, true, BOT_MODE_NONE)
				if
					nearbyEnemyHeroes ~= nil
					and #nearbyEnemyHeroes >= 1
					and GetUnitToUnitDistance(creep, nearbyEnemyHeroes[1]) <= 600
				then
					local travelTime = GetUnitToUnitDistance(bot, creep) / speed + castPoint
					return BOT_ACTION_DESIRE_HIGH, creep:GetLocation(), travelTime
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0, 0
end
function X.ConsiderChakramReturn()
	if
		chakramLandLocation == 0
		or chakramLandLocation == nil
		or not returnChakramAbility:IsFullyCastable()
		or returnChakramAbility:IsHidden()
	then
		return BOT_ACTION_DESIRE_NONE
	end
	if DotaTime() < chakramCastTime + chakramFlightTime or X.StillTraveling(1) then
		return BOT_ACTION_DESIRE_NONE
	end
	local castRange = Fu.GetProperCastRange(false, bot, chakramAbility:GetCastRange())
	local radius = chakramAbility:GetSpecialValueFloat("radius")
	local mpRatio = bot:GetMana() / bot:GetMaxMana()
	local creepsUnder = 0
	local nearbyCreeps = bot:GetNearbyCreeps(castRange, true)
	for _, creep in pairs(nearbyCreeps) do
		if GetUnitToLocationDistance(creep, chakramLandLocation) <= radius then
			creepsUnder = creepsUnder + 1
		end
	end
	-- Count enemy heroes under the blade too: "creepsUnder == 0" counted only creeps, so a Chakram thrown at heroes
	-- (no creeps there) was recalled the moment it stopped, wasting its damage over time and slow.
	local heroesUnder = 0
	for _, enemyHero in pairs(Fu.GetEnemiesNearLoc(chakramLandLocation, radius)) do
		if Fu.IsValidHero(enemyHero) then
			heroesUnder = heroesUnder + 1
		end
	end
	if
		heroesUnder > 0
		and creepsUnder == 0
		and mpRatio >= 0.15
		and GetUnitToLocationDistance(bot, chakramLandLocation) <= 1600
	then
		if DotaTime() >= (bot._chakramLogAt or -999) then
			bot._chakramLogAt = DotaTime() + 10
			pcall(print, string.format("[OHA-SHREDDER] t=%.0f chakram kept on %d heroes", DotaTime(), heroesUnder))
		end
	end
	if
		mpRatio < 0.15
		or GetUnitToLocationDistance(bot, chakramLandLocation) > 1600
		or creepsUnder + heroesUnder == 0
	then
		return BOT_ACTION_DESIRE_HIGH
	end
	if isRetreating or isGoingOnSomeone then
		local enemiesUnder = 0
		local nearbyEnemyHeroes = bot:GetNearbyHeroes(castRange, true, BOT_MODE_NONE)
		for _, enemyHero in pairs(nearbyEnemyHeroes) do
			if GetUnitToLocationDistance(enemyHero, chakramLandLocation) <= radius then
				enemiesUnder = enemiesUnder + 1
			end
		end
		if enemiesUnder == 0 then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderFlamethrower()
	if not flamethrowerAbility:IsTrained() or not flamethrowerAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
	end
	local length = flamethrowerAbility:GetSpecialValueInt("length")
	botTarget = Fu.GetProperTarget(bot)
	if isGoingOnSomeone then
		local nearbyAllies = bot:GetNearbyHeroes(800, false, BOT_MODE_NONE)
		local nearbyEnemyHeroes = bot:GetNearbyHeroes(length, true, BOT_MODE_NONE)
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, length)
			and bot:IsFacingLocation(botTarget:GetLocation(), 30)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not botTarget:HasModifier("modifier_abaddon_aphotic_shield")
			and not botTarget:HasModifier("modifier_dazzle_shallow_grave")
			and not botTarget:HasModifier("modifier_templar_assassin_refraction_absorb")
			and nearbyAllies ~= nil
			and nearbyEnemyHeroes ~= nil
			and #nearbyAllies >= #nearbyEnemyHeroes
		then
			return BOT_ACTION_DESIRE_MODERATE
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
-- [OHA-SHREDDER] retreat cast under the new HP < 0.51 rule (the HP part had no effect before).
function X.LogRetreatHp(spell, enemies, allies)
	if DotaTime() < (bot._retreatHpLogAt or -999) then
		return
	end
	bot._retreatHpLogAt = DotaTime() + 5
	pcall(
		print,
		string.format(
			"[OHA-SHREDDER] t=%.0f retreat %s enemies=%d allies=%d hp=%.2f",
			DotaTime(),
			spell,
			enemies,
			allies,
			hpRatio or 0
		)
	)
end
function X.StillTraveling(chakramIndex)
	local linearProjectiles = GetLinearProjectiles()
	for _, projectile in pairs(linearProjectiles) do
		if
			projectile ~= nil
			-- ability can be nil on a linear projectile (hero_ancient_apparition guards it too)
			and projectile.ability ~= nil
			and (
				chakramIndex == 1 and projectile.ability:GetName() == "shredder_chakram"
				or chakramIndex == 2 and projectile.ability:GetName() == "shredder_chakram_2"
			)
		then
			return true
		end
	end
	return false
end
return X
