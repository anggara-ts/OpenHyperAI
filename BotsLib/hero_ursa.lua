-- Ursa: skill build, item build, and ability use for this hero.
local X = {}
local bot = GetBot()
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local AbilityContext = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local Minion = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local sTalentList = Fu.Skill.GetTalentList(bot)
local sAbilityList = Fu.Skill.GetAbilityList(bot)
local sRole = Fu.Item.GetRoleItemsBuyList(bot)
local tTalentTreeList = { ["t25"] = { 0, 10 }, ["t20"] = { 10, 0 }, ["t15"] = { 0, 10 }, ["t10"] = { 0, 10 } }
local tAllAbilityBuildList = { { 3, 1, 3, 2, 3, 6, 3, 2, 2, 2, 6, 1, 1, 1, 6 } }
local nAbilityBuildList = Fu.Skill.GetRandomBuild(tAllAbilityBuildList)
local nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList)
local sRoleItemsBuyList = {}
-- Stratz 7.41f, week of 9 Nov 2026: pos 1, 120,202 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_1"] = {
	"item_tango",
	"item_quelling_blade",
	"item_double_branches",
	"item_magic_stick",
	"item_magic_wand",
	"item_phase_boots",
	"item_bfury",
	"item_blink",
	"item_basher",
	"item_black_king_bar",
	"item_aghanims_shard",
	"item_monkey_king_bar",
	"item_abyssal_blade",
	"item_swift_blink",
	"item_travel_boots",
	"item_moon_shard",
	"item_ultimate_scepter_2",
	"item_travel_boots_2",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 2, 6,535 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_2"] = {
	"item_tango",
	"item_quelling_blade",
	"item_double_branches",
	"item_magic_stick",
	"item_magic_wand",
	"item_phase_boots",
	"item_blink",
	"item_basher",
	"item_black_king_bar",
	"item_aghanims_shard",
	"item_ultimate_scepter",
	"item_monkey_king_bar",
	"item_abyssal_blade",
	"item_ultimate_scepter_2",
	"item_nullifier",
	"item_moon_shard",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 4 has 892 matches, built from pos 5 (1,058) (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_4"] = {
	"item_tango",
	"item_quelling_blade",
	"item_double_branches",
	"item_magic_stick",
	"item_magic_wand",
	"item_phase_boots",
	"item_bfury",
	"item_blink",
	"item_basher",
	"item_black_king_bar",
	"item_aghanims_shard",
	"item_abyssal_blade",
	"item_diffusal_blade",
	"item_moon_shard",
	"item_ultimate_scepter_2",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 5, 1,058 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_5"] = {
	"item_tango",
	"item_quelling_blade",
	"item_double_branches",
	"item_magic_stick",
	"item_magic_wand",
	"item_phase_boots",
	"item_bfury",
	"item_blink",
	"item_basher",
	"item_black_king_bar",
	"item_aghanims_shard",
	"item_abyssal_blade",
	"item_diffusal_blade",
	"item_moon_shard",
	"item_ultimate_scepter_2",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 3, 10,586 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_3"] = {
	"item_tango",
	"item_quelling_blade",
	"item_double_branches",
	"item_magic_stick",
	"item_magic_wand",
	"item_phase_boots",
	"item_bfury",
	"item_blink",
	"item_basher",
	"item_black_king_bar",
	"item_aghanims_shard",
	"item_ultimate_scepter",
	"item_abyssal_blade",
	"item_ultimate_scepter_2",
	"item_diffusal_blade",
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
function X.MinionThink(minionUnit)
	if Minion.IsValidUnit(minionUnit) then
		if Fu.IsValidHero(minionUnit) and minionUnit:IsIllusion() then
			Minion.IllusionThink(minionUnit)
		end
	end
end
local earthshockAbility = SafeAbility(bot:GetAbilityByName("ursa_earthshock"), "ursa_earthshock", "ursa")
local overpowerAbility = SafeAbility(bot:GetAbilityByName("ursa_overpower"), "ursa_overpower", "ursa")
local enrageAbility = SafeAbility(bot:GetAbilityByName("ursa_enrage"), "ursa_enrage", "ursa")
local earthshockDesire
local overpowerDesire
local enrageDesire
local botTarget
local isGoingOnSomeone
local hpRatio
function X.SkillsComplement()
	if Fu.CanNotUseAbility(bot) then
		return
	end
	isGoingOnSomeone = Fu.IsGoingOnSomeone(bot)
	hpRatio = Fu.GetHP(bot)
	enrageDesire = X.ConsiderEnrage()
	if enrageDesire > 0 then
		bot:Action_UseAbility(enrageAbility)
		return
	end
	overpowerDesire = X.ConsiderOverpower()
	if overpowerDesire > 0 then
		bot:Action_UseAbility(overpowerAbility)
		return
	end
	earthshockDesire = X.ConsiderEarthshock()
	if earthshockDesire > 0 then
		bot:Action_UseAbility(earthshockAbility)
		return
	end
end
function X.ConsiderEarthshock()
	if not earthshockAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
	end
	local radius = earthshockAbility:GetSpecialValueInt("shock_radius")
	-- datafeed: hop_duration is 0.25; GetSpecialValueInt truncated it to 0
	local hopDuration = earthshockAbility:GetSpecialValueFloat("hop_duration")
	local damage = earthshockAbility:GetAbilityDamage()
	local mpRatio = bot:GetMana() / bot:GetMaxMana()
	botTarget = Fu.GetProperTarget(bot)
	local enemiesInRadius = Fu.GetNearbyHeroes(bot, radius, true, BOT_MODE_NONE)
	local nearbyTowers = bot:GetNearbyTowers(radius * 2, true)
	for _, enemyHero in pairs(enemiesInRadius) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and Fu.IsInRange(bot, enemyHero, radius)
			and not Fu.IsSuspiciousIllusion(enemyHero)
			and not enemyHero:HasModifier("modifier_enigma_black_hole_pull")
			and not enemyHero:HasModifier("modifier_faceless_void_chronosphere_freeze")
		then
			if bot:IsFacingLocation(enemyHero:GetExtrapolatedLocation(hopDuration), 15) then
				local alliesNearEnemy = Fu.GetNearbyHeroes(enemyHero, radius + 100, true, BOT_MODE_NONE)
				if
					alliesNearEnemy ~= nil
					and #alliesNearEnemy <= 1
					and Fu.CanKillTarget(enemyHero, damage, DAMAGE_TYPE_MAGICAL)
				then
					return BOT_ACTION_DESIRE_HIGH
				end
			end
		end
	end
	if enemiesInRadius ~= nil and #enemiesInRadius >= 2 then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, radius + 300, false, BOT_MODE_NONE)
		if
			nearbyAllies ~= nil
			and #nearbyAllies >= #enemiesInRadius
			and not bot:HasModifier("modifier_ursa_earthshock_move")
		then
			local enemyCenter = Fu.GetCenterOfUnits(enemiesInRadius)
			if enemyCenter ~= nil and bot:IsFacingLocation(enemyCenter, 25) then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	if isGoingOnSomeone then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, radius + 200, false, BOT_MODE_NONE)
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, radius, true, BOT_MODE_NONE)
		-- datafeed: Earthshock "leaps forward hop_distance (250) units and slams the earth",
		-- shock_radius 385. That the slam is centred on the landing spot is not verified; if it is,
		-- requiring the target within 385 of Ursa skipped a fleeing target 400-535 ahead.
		-- Reach = radius + hop - 100 (margin for his run during the hop); facing check kept.
		local reach = radius + earthshockAbility:GetSpecialValueInt("hop_distance") - 100
		if
			Fu.IsValidTarget(botTarget)
			and Fu.IsInRange(bot, botTarget, math.max(radius, reach))
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not botTarget:HasModifier("modifier_enigma_black_hole_pull")
			and not botTarget:HasModifier("modifier_faceless_void_chronosphere_freeze")
			and not bot:HasModifier("modifier_ursa_earthshock_move")
			and nearbyAllies ~= nil
			and nearbyEnemies ~= nil
			and #nearbyAllies >= #nearbyEnemies
		then
			if bot:IsFacingLocation(botTarget:GetExtrapolatedLocation(hopDuration), 15) then
				-- [OHA-URSA] the new long-reach hop only, at most once per 5s.
				if not Fu.IsInRange(bot, botTarget, radius) and DotaTime() >= (bot._ursaReachLogAt or -999) then
					bot._ursaReachLogAt = DotaTime() + 5
					pcall(
						print,
						string.format(
							"[OHA-URSA] t=%.0f earthshock-reach target=%s dist=%d",
							DotaTime(),
							(string.gsub(botTarget:GetUnitName(), "npc_dota_hero_", "")),
							math.floor(GetUnitToUnitDistance(bot, botTarget))
						)
					)
				end
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	if Fu.IsRetreating(bot) then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, radius * 2.5, false, BOT_MODE_NONE)
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, radius * 2, true, BOT_MODE_NONE)
		if
			nearbyAllies ~= nil
			and nearbyEnemies ~= nil
			and (#nearbyEnemies > #nearbyAllies or hpRatio < 0.55 and bot:WasRecentlyDamagedByAnyHero(2.5))
			and Fu.IsValidHero(nearbyEnemies[1])
			and Fu.IsInRange(bot, nearbyEnemies[1], radius)
			and not Fu.IsSuspiciousIllusion(nearbyEnemies[1])
			and not Fu.IsDisabled(nearbyEnemies[1])
			and not Fu.IsRealInvisible(bot)
		then
			if bot:IsFacingLocation(Fu.GetEscapeLoc(), 30) then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	if Fu.IsFarming(bot) and mpRatio > 0.4 then
		local neutralCreeps = bot:GetNearbyNeutralCreeps(radius)
		if neutralCreeps ~= nil and #neutralCreeps >= 3 then
			if bot:IsFacingLocation(Fu.GetCenterOfUnits(neutralCreeps), 25) then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	if
		Fu.IsLaning(bot)
		and enemiesInRadius ~= nil
		and nearbyTowers ~= nil
		and #enemiesInRadius == 0
		and #nearbyTowers == 0
	then
		local laneCreeps = bot:GetNearbyLaneCreeps(radius, true)
		for _, creep in pairs(laneCreeps) do
			if
				Fu.IsValid(creep)
				and Fu.CanBeAttacked(creep)
				and (Fu.IsKeyWordUnit("ranged", creep) or Fu.IsKeyWordUnit("siege", creep))
				and bot:IsFacingLocation(creep:GetLocation(), 15)
			then
				-- datafeed: Earthshock deals magical damage (damage 2)
				if Fu.WillKillTarget(creep, damage, DAMAGE_TYPE_MAGICAL, 0.25) then
					bot:SetTarget(creep)
					return BOT_ACTION_DESIRE_HIGH
				end
			end
		end
		if mpRatio > 0.89 and bot:DistanceFromFountain() > 100 and bot:DistanceFromFountain() < 6000 then
			local assignedLane = bot:GetAssignedLane()
			local laneFront = GetLaneFrontLocation(GetTeam(), assignedLane, 0)
			local distToLaneFront = GetUnitToLocationDistance(bot, laneFront)
			if distToLaneFront > 1600 then
				local hopLocation = Fu.Site.GetXUnitsTowardsLocation(bot, laneFront, radius)
				if IsLocationPassable(hopLocation) and bot:IsFacingLocation(hopLocation, 30) then
					return BOT_ACTION_DESIRE_HIGH
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderOverpower()
	if not overpowerAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
	end
	local attackRange = bot:GetAttackRange()
	local mpRatio = bot:GetMana() / bot:GetMaxMana()
	botTarget = Fu.GetProperTarget(bot)
	if isGoingOnSomeone then
		if
			Fu.IsValidTarget(botTarget)
			and not bot:HasModifier("modifier_ursa_overpower")
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not botTarget:HasModifier("modifier_abaddon_aphotic_shield")
			and not botTarget:HasModifier("modifier_dazzle_shallow_grave")
			and not botTarget:HasModifier("modifier_templar_assassin_refraction_absorb")
		then
			local nearbyAllies = Fu.GetNearbyHeroes(bot, attackRange * 3, false, BOT_MODE_NONE)
			local nearbyEnemies = Fu.GetNearbyHeroes(bot, attackRange * 2, true, BOT_MODE_NONE)
			if nearbyAllies ~= nil and nearbyEnemies ~= nil and #nearbyAllies >= #nearbyEnemies then
				if
					Fu.IsInRange(bot, botTarget, attackRange * 4) and bot:IsFacingLocation(botTarget:GetLocation(), 30)
				then
					return BOT_ACTION_DESIRE_HIGH
				end
			end
		end
	end
	if Fu.IsPushing(bot) and mpRatio > 0.45 then
		local laneCreeps = bot:GetNearbyLaneCreeps(attackRange, true)
		local nearbyTowers = bot:GetNearbyTowers(600, true)
		if laneCreeps ~= nil and #laneCreeps >= 3 or nearbyTowers ~= nil and #nearbyTowers >= 1 then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsFarming(bot) and mpRatio > 0.25 and not bot:HasModifier("modifier_ursa_overpower") then
		local neutralCreeps = bot:GetNearbyNeutralCreeps(400)
		if neutralCreeps ~= nil and #neutralCreeps >= 2 then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if Fu.IsRoshan(botTarget) and not bot:HasModifier("modifier_ursa_overpower") then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if
			Fu.IsTormentor(botTarget)
			and Fu.IsInRange(botTarget, bot, 600)
			and Fu.IsAttacking(bot)
			and not bot:HasModifier("modifier_ursa_overpower")
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderEnrage()
	if not enrageAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
	end
	local attackRange = bot:GetAttackRange()
	botTarget = Fu.GetProperTarget(bot)
	local nearbyEnemies = Fu.GetNearbyHeroes(bot, 800, true, BOT_MODE_NONE)
	-- No enemy hero within 800 used to return here, so the farming, Roshan and Tormentor branches
	-- below could never fire. The hero branches check nearbyEnemies themselves.
	nearbyEnemies = nearbyEnemies or {}
	if nearbyEnemies ~= nil and #nearbyEnemies >= 2 and bot:WasRecentlyDamagedByAnyHero(1.5) and hpRatio < 0.6 then
		return BOT_ACTION_DESIRE_HIGH
	end
	if hpRatio < 0.5 and bot:WasRecentlyDamagedByAnyHero(2) and nearbyEnemies ~= nil and #nearbyEnemies >= 1 then
		return BOT_ACTION_DESIRE_HIGH
	end
	if isGoingOnSomeone then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, 800, false, BOT_MODE_NONE)
		if
			Fu.IsValidTarget(botTarget)
			and Fu.IsInRange(bot, botTarget, attackRange + 75)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not Fu.IsDisabled(botTarget)
			and not bot:IsMagicImmune()
			and not botTarget:HasModifier("modifier_faceless_void_chronosphere_freeze")
			and not botTarget:HasModifier("modifier_enigma_black_hole_pull")
			and nearbyAllies ~= nil
			and nearbyEnemies ~= nil
			and #nearbyAllies >= #nearbyEnemies
		then
			if bot:WasRecentlyDamagedByAnyHero(1) and hpRatio < 0.75 then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	if Fu.IsRetreating(bot) then
		if hpRatio < 0.3 and bot:WasRecentlyDamagedByAnyHero(1) then
			return BOT_ACTION_DESIRE_HIGH
		end
		local nearbyAllies = Fu.GetNearbyHeroes(bot, 800, false, BOT_MODE_NONE)
		if
			nearbyAllies ~= nil
			and nearbyEnemies ~= nil
			and (#nearbyEnemies > #nearbyAllies or hpRatio < 0.5 and bot:WasRecentlyDamagedByAnyHero(1.5))
			and Fu.IsValidHero(nearbyEnemies[1])
			and Fu.IsInRange(bot, nearbyEnemies[1], attackRange + 100)
			and not Fu.IsSuspiciousIllusion(nearbyEnemies[1])
			and not Fu.IsDisabled(nearbyEnemies[1])
			and not bot:IsMagicImmune()
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsFarming(bot) and hpRatio < 0.25 then
		if Fu.IsValid(botTarget) and botTarget:IsCreep() and Fu.IsInRange(bot, botTarget, attackRange) then
			return BOT_ACTION_DESIRE_MODERATE
		end
	end
	if Fu.IsDoingRoshan(bot) and hpRatio < 0.33 then
		if Fu.IsRoshan(botTarget) then
			return BOT_ACTION_DESIRE_MODERATE
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and hpRatio < 0.3 then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
return X
