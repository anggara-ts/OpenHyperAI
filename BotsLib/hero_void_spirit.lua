-- Void Spirit: skill build, item build, and ability use for this hero.
local X = {}
local bot = GetBot()
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local AbilityContext = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local Minion = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local sTalentList = Fu.Skill.GetTalentList(bot)
local sAbilityList = Fu.Skill.GetAbilityList(bot)
local sRole = Fu.Item.GetRoleItemsBuyList(bot)
local tTalentTreeList = { ["t25"] = { 0, 10 }, ["t20"] = { 10, 0 }, ["t15"] = { 10, 0 }, ["t10"] = { 10, 0 } }
local tAllAbilityBuildList = { { 3, 1, 3, 2, 3, 6, 3, 1, 1, 1, 6, 2, 2, 2, 6 } }
local nAbilityBuildList = Fu.Skill.GetRandomBuild(tAllAbilityBuildList)
local nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList)
local sRoleItemsBuyList = {}
sRoleItemsBuyList["pos_2"] = {
	"item_tango",
	"item_double_branches",
	"item_bottle",
	"item_bracer",
	"item_boots",
	"item_magic_wand",
	"item_power_treads",
	"item_spirit_vessel",
	"item_ultimate_scepter",
	"item_aghanims_shard",
	"item_manta",
	"item_black_king_bar",
	"item_travel_boots",
	"item_greater_crit",
	"item_sheepstick",
	"item_ultimate_scepter_2",
	"item_moon_shard",
	"item_travel_boots_2",
	"item_orchid",
	"item_bloodthorn",
}
sRoleItemsBuyList["pos_1"] = {
	"item_tango",
	"item_double_branches",
	"item_circlet",
	"item_gauntlets",
	"item_bracer",
	"item_boots",
	"item_magic_wand",
	"item_power_treads",
	"item_spirit_vessel",
	"item_ultimate_scepter",
	"item_aghanims_shard",
	"item_manta",
	"item_black_king_bar",
	"item_travel_boots",
	"item_greater_crit",
	"item_sheepstick",
	"item_ultimate_scepter_2",
	"item_moon_shard",
	"item_travel_boots_2",
	"item_orchid",
	"item_bloodthorn",
}
sRoleItemsBuyList["pos_4"] = sRoleItemsBuyList["pos_1"]
sRoleItemsBuyList["pos_5"] = sRoleItemsBuyList["pos_1"]
sRoleItemsBuyList["pos_3"] = sRoleItemsBuyList["pos_1"]
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
	if Minion.IsValidUnit(hMinionUnit) then
		if Fu.IsValidHero(hMinionUnit) and hMinionUnit:IsIllusion() then
			Minion.IllusionThink(hMinionUnit)
		end
	end
end
local aetherRemnantAbility =
	SafeAbility(bot:GetAbilityByName("void_spirit_aether_remnant"), "void_spirit_aether_remnant", "void_spirit")
local dissimilateAbility =
	SafeAbility(bot:GetAbilityByName("void_spirit_dissimilate"), "void_spirit_dissimilate", "void_spirit")
local resonantPulseAbility =
	SafeAbility(bot:GetAbilityByName("void_spirit_resonant_pulse"), "void_spirit_resonant_pulse", "void_spirit")
local astralStepAbility =
	SafeAbility(bot:GetAbilityByName("void_spirit_astral_step"), "void_spirit_astral_step", "void_spirit")
local aetherRemnantDesire, aetherRemnantLocation
local dissimilateDesire
local resonantPulseDesire
local astralStepDesire, astralStepLocation
local astralStepCastTime = -100
local botTarget
local isGoingOnSomeone
local isRetreating
local hpRatio
-- Throttled trace for the stun-dodge Dissimilate, which used to be overwritten by later casts.
local function LogVoidCast(what)
	if DotaTime() >= (bot._voidCastLogAt or -999) then
		bot._voidCastLogAt = DotaTime() + 10
		pcall(print, string.format("[OHA-VOID_SPIRIT] t=%.0f %s", DotaTime(), what))
	end
end
function X.SkillsComplement()
	isGoingOnSomeone = Fu.IsGoingOnSomeone(bot)
	isRetreating = Fu.IsRetreating(bot)
	hpRatio = Fu.GetHP(bot)
	if Fu.CanNotUseAbility(bot) or bot:NumQueuedActions() > 0 then
		return
	end
	-- One order per think. The four casts used to run without a return, so two or more Action_ orders
	-- could go out in the same think, and a later one could replace an earlier one (not verified in
	-- game; e.g. Pulse over a stun-dodge Dissimilate). Order now: stun dodge, Astral Step,
	-- Dissimilate, Pulse, Remnant. Remnant is vector-targeted and the bot API has no vector order;
	-- whether a plain location order on it always goes through is not verified, so it goes last
	-- and cannot hold up the other three.
	if dissimilateAbility:IsFullyCastable() and Fu.IsStunProjectileIncoming(bot, 600) then
		LogVoidCast("dissimilate-dodge")
		bot:Action_UseAbility(dissimilateAbility)
		return
	end
	astralStepDesire, astralStepLocation = X.ConsiderAstralStep()
	if astralStepDesire > 0 then
		bot:Action_UseAbilityOnLocation(astralStepAbility, astralStepLocation)
		astralStepCastTime = DotaTime()
		return
	end
	dissimilateDesire = X.ConsiderDissimilate()
	if dissimilateDesire > 0 then
		bot:Action_UseAbility(dissimilateAbility)
		return
	end
	resonantPulseDesire = X.ConsiderResonantPulse()
	if resonantPulseDesire > 0 then
		bot:Action_UseAbility(resonantPulseAbility)
		return
	end
	aetherRemnantDesire, aetherRemnantLocation = X.ConsiderAetherRemnant()
	if aetherRemnantDesire > 0 then
		bot:Action_UseAbilityOnLocation(aetherRemnantAbility, aetherRemnantLocation)
		return
	end
end
function X.ConsiderAetherRemnant()
	if not aetherRemnantAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local radius = aetherRemnantAbility:GetSpecialValueInt("radius")
	local activationDelay = aetherRemnantAbility:GetSpecialValueFloat("activation_delay")
	local damage = aetherRemnantAbility:GetSpecialValueInt("impact_damage")
	local castRange = aetherRemnantAbility:GetCastRange()
	botTarget = Fu.GetProperTarget(bot)
	local nearbyEnemies = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidTarget(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and Fu.IsInRange(bot, enemyHero, castRange)
			and not Fu.IsSuspiciousIllusion(enemyHero)
		then
			if enemyHero:IsChanneling() then
				return BOT_ACTION_DESIRE_HIGH, enemyHero:GetLocation()
			end
			if Fu.CanKillTarget(enemyHero, damage, DAMAGE_TYPE_MAGICAL) then
				return BOT_ACTION_DESIRE_HIGH, enemyHero:GetExtrapolatedLocation(activationDelay)
			end
		end
	end
	if isGoingOnSomeone then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, castRange + 100, false, BOT_MODE_NONE)
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
		if
			Fu.IsValidHero(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and not Fu.IsInRange(bot, botTarget, radius)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not Fu.IsDisabled(botTarget)
			and not botTarget:HasModifier("modifier_faceless_void_chronosphere_freeze")
			and not botTarget:HasModifier("modifier_enigma_black_hole_pull")
			and not botTarget:HasModifier("modifier_legion_commander_duel")
			and nearbyAllies ~= nil
			and nearbyEnemies ~= nil
			and #nearbyAllies >= #nearbyEnemies
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetExtrapolatedLocation(activationDelay)
		end
	end
	if isRetreating then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, castRange + 100, false, BOT_MODE_NONE)
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
		if
			nearbyAllies ~= nil
			and nearbyEnemies ~= nil
			and (#nearbyEnemies > #nearbyAllies or hpRatio < 0.5 and bot:WasRecentlyDamagedByAnyHero(2))
			and Fu.IsValidHero(nearbyEnemies[1])
			and Fu.CanCastOnNonMagicImmune(nearbyEnemies[1])
			and Fu.IsInRange(bot, nearbyEnemies[1], radius)
			and not Fu.IsSuspiciousIllusion(nearbyEnemies[1])
			and not Fu.IsDisabled(nearbyEnemies[1])
		then
			return BOT_ACTION_DESIRE_HIGH, bot:GetLocation()
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.ConsiderDissimilate()
	if not dissimilateAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
	end
	local ringDistance = dissimilateAbility:GetSpecialValueInt("first_ring_distance_offset")
	botTarget = Fu.GetProperTarget(bot)
	if Fu.IsStunProjectileIncoming(bot, 600) then
		return BOT_ACTION_DESIRE_HIGH
	end
	if isGoingOnSomeone then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, ringDistance * 1.5, false, BOT_MODE_NONE)
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, ringDistance, true, BOT_MODE_NONE)
		if
			Fu.IsValidHero(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, ringDistance)
			and not Fu.IsInRange(bot, botTarget, bot:GetAttackRange() + 50)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not Fu.IsDisabled(botTarget)
			and not botTarget:HasModifier("modifier_faceless_void_chronosphere_freeze")
			and nearbyAllies ~= nil
			and nearbyEnemies ~= nil
			and #nearbyAllies >= #nearbyEnemies
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if isRetreating then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, ringDistance * 1.5, false, BOT_MODE_NONE)
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, ringDistance, true, BOT_MODE_NONE)
		if
			nearbyAllies ~= nil
			and nearbyEnemies ~= nil
			and (#nearbyEnemies > #nearbyAllies or hpRatio < 0.65 and bot:WasRecentlyDamagedByAnyHero(2))
			and Fu.IsValidHero(nearbyEnemies[1])
			and Fu.IsInRange(bot, nearbyEnemies[1], bot:GetAttackRange() + 50)
			and not Fu.IsSuspiciousIllusion(nearbyEnemies[1])
			and not Fu.IsDisabled(nearbyEnemies[1])
			and not Fu.IsRealInvisible(bot)
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderResonantPulse()
	if not resonantPulseAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
	end
	local radius = resonantPulseAbility:GetSpecialValueInt("radius")
	local damage = resonantPulseAbility:GetSpecialValueInt("damage")
	local manaCost = resonantPulseAbility:GetManaCost()
	local mpRatio = bot:GetMana() / bot:GetMaxMana()
	botTarget = Fu.GetProperTarget(bot)
	local nearbyEnemies = Fu.GetNearbyHeroes(bot, radius, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidTarget(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and Fu.IsInRange(bot, enemyHero, radius)
			and Fu.CanKillTarget(enemyHero, damage, DAMAGE_TYPE_MAGICAL)
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
		local nearbyAllies = Fu.GetNearbyHeroes(bot, radius + 150, false, BOT_MODE_NONE)
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, radius, true, BOT_MODE_NONE)
		if
			Fu.IsValidHero(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, radius)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not botTarget:HasModifier("modifier_abaddon_aphotic_shield")
			and not botTarget:HasModifier("modifier_dazzle_shallow_grave")
			and not botTarget:HasModifier("modifier_templar_assassin_refraction_absorb")
			and nearbyAllies ~= nil
			and nearbyEnemies ~= nil
			and #nearbyAllies >= #nearbyEnemies
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if isRetreating then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, radius + 150, false, BOT_MODE_NONE)
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, radius, true, BOT_MODE_NONE)
		if
			nearbyAllies ~= nil
			and nearbyEnemies ~= nil
			and (#nearbyEnemies > #nearbyAllies or hpRatio < 0.65 and bot:WasRecentlyDamagedByAnyHero(1.5))
			and Fu.IsValidHero(nearbyEnemies[1])
			and Fu.CanCastOnNonMagicImmune(nearbyEnemies[1])
			and Fu.IsInRange(bot, nearbyEnemies[1], radius)
			and not Fu.IsSuspiciousIllusion(nearbyEnemies[1])
			and not Fu.IsDisabled(nearbyEnemies[1])
			and not Fu.IsRealInvisible(bot)
			and not bot:HasModifier("modifier_void_spirit_resonant_pulse_physical_buff")
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if
		(Fu.IsPushing(bot) or Fu.IsDefending(bot))
		and not bot:HasModifier("modifier_void_spirit_resonant_pulse_physical_buff")
	then
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, radius + 200, true, BOT_MODE_NONE)
		local nearbyLaneCreeps = bot:GetNearbyLaneCreeps(radius, true)
		if nearbyLaneCreeps ~= nil and #nearbyLaneCreeps >= 3 and nearbyEnemies ~= nil and #nearbyEnemies == 0 then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if
		Fu.IsFarming(bot)
		and mpRatio > 0.38
		and not bot:HasModifier("modifier_void_spirit_resonant_pulse_physical_buff")
	then
		local nearbyNeutrals = bot:GetNearbyNeutralCreeps(radius)
		if nearbyNeutrals ~= nil and #nearbyNeutrals >= 3 then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsLaning(bot) and mpRatio > 0.33 then
		local nearbyLaneCreeps = bot:GetNearbyLaneCreeps(radius, true)
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
					return BOT_ACTION_DESIRE_HIGH
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderAstralStep()
	if not astralStepAbility:IsFullyCastable() or bot:IsRooted() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local maxTravelDistance = astralStepAbility:GetSpecialValueInt("max_travel_distance")
	local castPoint = astralStepAbility:GetCastPoint()
	local damage = astralStepAbility:GetSpecialValueInt("pop_damage")
	botTarget = Fu.GetProperTarget(bot)
	if DotaTime() < astralStepCastTime + castPoint then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	if Fu.IsStuck(bot) and not bot:HasModifier("modifier_void_spirit_astral_step_caster") then
		local escapeLocation = Fu.GetEscapeLoc()
		return BOT_ACTION_DESIRE_HIGH, Fu.Site.GetXUnitsTowardsLocation(bot, escapeLocation, maxTravelDistance)
	end
	local nearbyEnemies = Fu.GetNearbyHeroes(bot, maxTravelDistance, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidTarget(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and Fu.CanKillTarget(enemyHero, damage, DAMAGE_TYPE_MAGICAL)
			and not Fu.IsSuspiciousIllusion(enemyHero)
			and not enemyHero:HasModifier("modifier_abaddon_aphotic_shield")
			and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
			and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
			and not enemyHero:HasModifier("modifier_faceless_void_chronosphere_freeze")
			and not enemyHero:HasModifier("modifier_templar_assassin_refraction_absorb")
		then
			return BOT_ACTION_DESIRE_HIGH, enemyHero:GetExtrapolatedLocation(castPoint)
		end
	end
	if isGoingOnSomeone then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, maxTravelDistance + 100, false, BOT_MODE_NONE)
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, maxTravelDistance, true, BOT_MODE_NONE)
		-- Target within max_travel_distance: the step used to fire at a target any distance away,
		-- spending a charge on travel with no pop on him. Astral Step pierces spell immunity
		-- (npc data: SPELL_IMMUNITY_ENEMIES_YES), so a BKB'd target is still a valid engage.
		if
			Fu.IsValidHero(botTarget)
			and Fu.CanCastOnMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, maxTravelDistance)
			and not Fu.IsInRange(bot, botTarget, bot:GetAttackRange() + 100)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not Fu.IsDisabled(botTarget)
			and not botTarget:HasModifier("modifier_faceless_void_chronosphere_freeze")
			and nearbyAllies ~= nil
			and nearbyEnemies ~= nil
			and #nearbyAllies >= #nearbyEnemies
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetExtrapolatedLocation(castPoint)
		end
	end
	if isRetreating then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, maxTravelDistance + 150, false, BOT_MODE_NONE)
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, maxTravelDistance, true, BOT_MODE_NONE)
		if
			nearbyAllies ~= nil
			and nearbyEnemies ~= nil
			and (#nearbyEnemies > #nearbyAllies or hpRatio < 0.65 and bot:WasRecentlyDamagedByAnyHero(2))
			and Fu.IsValidHero(nearbyEnemies[1])
			and Fu.CanCastOnNonMagicImmune(nearbyEnemies[1])
			and Fu.IsInRange(bot, nearbyEnemies[1], maxTravelDistance - 75)
			and not Fu.IsSuspiciousIllusion(nearbyEnemies[1])
			and not Fu.IsDisabled(nearbyEnemies[1])
			and not bot:HasModifier("modifier_void_spirit_astral_step_caster")
		then
			local escapeLocation = Fu.GetEscapeLoc()
			return BOT_ACTION_DESIRE_HIGH, Fu.Site.GetXUnitsTowardsLocation(bot, escapeLocation, maxTravelDistance)
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
return X
