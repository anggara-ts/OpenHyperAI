-- Marci: skill build, item build, and ability use for this hero.
local X = {}
local bot = GetBot()
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local AbilityContext = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local Minion = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local sTalentList = Fu.Skill.GetTalentList(bot)
local sAbilityList = Fu.Skill.GetAbilityList(bot)
local sRole = Fu.Item.GetRoleItemsBuyList(bot)
local tTalentTreeList = {
	{ ["t25"] = { 10, 0 }, ["t20"] = { 10, 0 }, ["t15"] = { 0, 10 }, ["t10"] = { 0, 10 } },
	{ ["t25"] = { 10, 0 }, ["t20"] = { 10, 0 }, ["t15"] = { 0, 10 }, ["t10"] = { 10, 0 } },
}
-- Rebound maxed first, Dispose second, Bodyguard last (Dotabuff most picked order).
local tAllAbilityBuildList =
	{ { 1, 2, 2, 1, 2, 6, 2, 1, 1, 3, 6, 3, 3, 3, 6 }, { 1, 2, 2, 1, 2, 6, 2, 1, 1, 3, 6, 3, 3, 3, 6 } }
local nAbilityBuildList
local nTalentBuildList
if sRole == "pos_1" then
	nAbilityBuildList = tAllAbilityBuildList[1]
	nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList[1])
else
	nAbilityBuildList = tAllAbilityBuildList[2]
	nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList[2])
end
local sRoleItemsBuyList = {}
-- Stratz 7.41f, week of 9 Nov 2026: pos 1, 4,828 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_1"] = {
	"item_tango",
	"item_double_branches",
	"item_quelling_blade",
	"item_faerie_fire",
	"item_circlet",
	"item_magic_wand",
	"item_bracer",
	"item_phase_boots",
	"item_lesser_crit",
	"item_black_king_bar",
	"item_basher",
	"item_ultimate_scepter",
	"item_aghanims_shard",
	"item_greater_crit",
	"item_abyssal_blade",
	"item_ultimate_scepter_2",
	"item_desolator",
	"item_moon_shard",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 3, 13,657 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_3"] = {
	"item_tango",
	"item_double_branches",
	"item_quelling_blade",
	"item_circlet",
	"item_magic_wand",
	"item_bracer",
	"item_phase_boots",
	"item_lesser_crit",
	"item_black_king_bar",
	"item_basher",
	"item_aghanims_shard",
	"item_ultimate_scepter",
	"item_greater_crit",
	"item_abyssal_blade",
	"item_ultimate_scepter_2",
	"item_travel_boots",
	"item_monkey_king_bar",
	"item_nullifier",
	"item_moon_shard",
	"item_travel_boots_2",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 2, 34,356 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_2"] = {
	"item_tango",
	"item_double_branches",
	"item_quelling_blade",
	"item_faerie_fire",
	"item_circlet",
	"item_magic_wand",
	"item_bracer",
	"item_phase_boots",
	"item_black_king_bar",
	"item_ultimate_scepter",
	"item_aghanims_shard",
	"item_basher",
	"item_monkey_king_bar",
	"item_abyssal_blade",
	"item_ultimate_scepter_2",
	"item_satanic",
	"item_nullifier",
	"item_moon_shard",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 4, 14,326 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_4"] = {
	"item_tango",
	"item_blood_grenade",
	"item_double_branches",
	"item_magic_stick",
	"item_faerie_fire",
	"item_magic_wand",
	"item_bracer",
	"item_phase_boots",
	"item_black_king_bar",
	"item_basher",
	"item_abyssal_blade",
	"item_greater_crit",
	"item_solar_crest",
	"item_ultimate_scepter_2",
	"item_aghanims_shard",
	"item_moon_shard",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 5, 11,211 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_5"] = {
	"item_tango",
	"item_blood_grenade",
	"item_double_branches",
	"item_magic_stick",
	"item_faerie_fire",
	"item_magic_wand",
	"item_bracer",
	"item_phase_boots",
	"item_black_king_bar",
	"item_basher",
	"item_solar_crest",
	"item_abyssal_blade",
	"item_greater_crit",
	"item_aghanims_shard",
	"item_moon_shard",
	"item_ultimate_scepter_2",
}
X["sBuyList"] = sRoleItemsBuyList[sRole]
local sRoleSellList = {}
-- Pairs are { owned, sold }: the old order sold Daedalus once she held a Wand, Abyssal once she held
-- Armlet, and Nullifier once she held a Wand. Swapped so the late item replaces the early one.
sRoleSellList["pos_1"] = { "item_greater_crit", "item_magic_wand", "item_abyssal_blade", "item_armlet" }
sRoleSellList["pos_2"] = sRoleSellList["pos_1"]
sRoleSellList["pos_3"] = { "item_nullifier", "item_magic_wand" }
sRoleSellList["pos_4"] = { "item_quelling_blade" }
sRoleSellList["pos_5"] = { "item_quelling_blade" }
X["sSellList"] = sRoleSellList[sRole] or {}
if Fu.Role.IsPvNMode() or Fu.Role.IsAllShadow() then
	X["sBuyList"], X["sSellList"] = { "PvN_marci" }, {}
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
local disposeAbility = SafeAbility(bot:GetAbilityByName("marci_grapple"), "marci_grapple", "marci")
local reboundAbility = SafeAbility(bot:GetAbilityByName("marci_companion_run"), "marci_companion_run", "marci")
local unleashAbility = SafeAbility(bot:GetAbilityByName("marci_unleash"), "marci_unleash", "marci")
local bodyguardAbility = SafeAbility(bot:GetAbilityByName("marci_bodyguard"), "marci_bodyguard", "marci")
local specialDeliveryAbility =
	SafeAbility(bot:GetAbilityByName("marci_special_delivery"), "marci_special_delivery", "marci")
local disposeDesire, disposeTarget
local reboundDesire, reboundTarget
local unleashDesire
local bodyguardDesire, bodyguardTarget
local specialDeliveryDesire
local isAttacking = false
local botTarget, hpRatio
local nearbyAllies, nearbyEnemies
function X.SkillsComplement()
	if Fu.CanNotUseAbility(bot) then
		return
	end
	isAttacking = Fu.IsAttacking(bot)
	hpRatio = Fu.GetHP(bot)
	botTarget = Fu.GetProperTarget(bot)
	nearbyAllies = bot:GetNearbyHeroes(1600, false, BOT_MODE_NONE)
	nearbyEnemies = bot:GetNearbyHeroes(1600, true, BOT_MODE_NONE)
	unleashDesire = X.ConsiderUnleash()
	if unleashDesire > 0 then
		bot:Action_UseAbility(unleashAbility)
		return
	end
	disposeDesire, disposeTarget = X.ConsiderDispose()
	if disposeDesire > 0 then
		Fu.SetQueuePtToINT(bot, false)
		bot:ActionQueue_UseAbilityOnEntity(disposeAbility, disposeTarget)
		return
	end
	reboundDesire, reboundTarget = X.ConsiderRebound()
	if reboundDesire > 0 then
		Fu.SetQueuePtToINT(bot, false)
		bot:ActionQueue_UseAbilityOnEntity(reboundAbility, reboundTarget)
		return
	end
	bodyguardDesire, bodyguardTarget = X.ConsiderBodyguard()
	if bodyguardDesire > 0 then
		Fu.SetQueuePtToINT(bot, false)
		bot:ActionQueue_UseAbilityOnEntity(bodyguardAbility, bodyguardTarget)
		return
	end
end
function X.ConsiderBodyguard()
	if not Fu.CanCastAbility(bodyguardAbility) then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castRange = Fu.GetProperCastRange(false, bot, bodyguardAbility:GetCastRange())
	local enemyLaneCreeps = bot:GetNearbyLaneCreeps(1200, true)
	-- Save: Bodyguard puts a shared all-damage barrier on the partner (datafeed: shared_barrier
	-- 90/160/230/300), but it was only cast from Marci's own state, never for an ally under fire.
	for _, ally in pairs(nearbyAllies) do
		if
			Fu.IsValidHero(ally)
			and bot ~= ally
			and not ally:IsIllusion()
			and not Fu.IsMeepoClone(ally)
			and Fu.IsInRange(bot, ally, castRange)
			and Fu.GetHP(ally) < 0.5
			and ally:WasRecentlyDamagedByAnyHero(1.5)
			and not ally:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			if DotaTime() >= (bot._ohaMarciGuardLogAt or -999) then
				bot._ohaMarciGuardLogAt = DotaTime() + 5
				pcall(
					print,
					string.format(
						"[OHA-MARCI] t=%.0f bodyguard save on %s hp=%.2f",
						DotaTime(),
						(string.gsub(ally:GetUnitName(), "npc_dota_hero_", "")),
						Fu.GetHP(ally)
					)
				)
			end
			return BOT_ACTION_DESIRE_HIGH, ally
		end
	end
	if
		Fu.IsGoingOnSomeone(bot) and bot:WasRecentlyDamagedByAnyHero(5.0)
		or Fu.IsPushing(bot) and #nearbyEnemies > 0
		or Fu.IsDefending(bot) and #nearbyEnemies > 0
		or Fu.IsLaning(bot) and #enemyLaneCreeps >= 3
		or Fu.IsDoingRoshan(bot) and Fu.IsRoshan(botTarget) and Fu.IsInRange(bot, botTarget, 800) and isAttacking and Fu.CanBeAttacked(
			botTarget
		)
		or Fu.IsDoingTormentor(bot)
			and Fu.IsTormentor(botTarget)
			and Fu.IsInRange(bot, botTarget, 800)
			and isAttacking
			and Fu.CanBeAttacked(botTarget)
	then
		local weakestAlly = nil
		local minHealth = math.huge
		for _, allyHero in pairs(nearbyAllies) do
			if
				Fu.IsValidHero(allyHero)
				and bot ~= allyHero
				and Fu.IsInRange(bot, allyHero, castRange)
				and not allyHero:IsIllusion()
				and not allyHero:HasModifier("modifier_faceless_void_chronosphere_freeze")
				and not allyHero:HasModifier("modifier_marci_guardian_buff")
				and not allyHero:HasModifier("modifier_necrolyte_reapers_scythe")
				and not Fu.IsMeepoClone(allyHero)
			then
				local allyHealth = allyHero:GetHealth()
				if minHealth > allyHealth then
					weakestAlly = allyHero
					minHealth = allyHealth
				end
			end
		end
		if weakestAlly ~= nil then
			return BOT_ACTION_DESIRE_HIGH, weakestAlly
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function X.ConsiderDispose()
	if not Fu.CanCastAbility(disposeAbility) then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castRange = Fu.GetProperCastRange(false, bot, disposeAbility:GetCastRange())
	local castPoint = disposeAbility:GetCastPoint()
	local impactDamage = disposeAbility:GetSpecialValueInt("impact_damage")
	local airDuration = disposeAbility:GetSpecialValueInt("air_duration")
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanBeAttacked(enemyHero)
			and Fu.IsInRange(bot, enemyHero, castRange + 300)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and Fu.CanCastOnTargetAdvanced(enemyHero)
		then
			if Fu.GetModifierTime(enemyHero, "modifier_teleporting") > airDuration + castPoint then
				return BOT_ACTION_DESIRE_HIGH, enemyHero
			end
			if
				Fu.WillKillTarget(enemyHero, impactDamage, DAMAGE_TYPE_MAGICAL, airDuration + castPoint)
				and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
				and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
				and not enemyHero:HasModifier("modifier_enigma_black_hole_pull")
				and not enemyHero:HasModifier("modifier_faceless_void_chronosphere_freeze")
				and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
				and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
			then
				return BOT_ACTION_DESIRE_HIGH, enemyHero
			end
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidHero(botTarget)
			and Fu.CanBeAttacked(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange + 300)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.CanCastOnTargetAdvanced(botTarget)
			and not Fu.IsDisabled(botTarget)
			and not botTarget:HasModifier("modifier_abaddon_borrowed_time")
			and not botTarget:HasModifier("modifier_dazzle_shallow_grave")
			and not botTarget:HasModifier("modifier_enigma_black_hole_pull")
			and not botTarget:HasModifier("modifier_faceless_void_chronosphere_freeze")
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget
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
				and bot:IsFacingLocation(Fu.GetTeamFountain(), 30)
				and bot:IsFacingLocation(enemyHero:GetLocation(), 15)
				and not Fu.IsDisabled(enemyHero)
				and bot:WasRecentlyDamagedByHero(enemyHero, 3.0)
			then
				if
					GetUnitToLocationDistance(bot, Fu.GetTeamFountain())
					> GetUnitToLocationDistance(enemyHero, Fu.GetTeamFountain())
				then
					return BOT_ACTION_DESIRE_HIGH, enemyHero
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function X.ConsiderRebound()
	if
		not Fu.CanCastAbility(reboundAbility)
		or bot:IsRooted()
		or bot:HasModifier("modifier_marci_unleash") and not Fu.IsRetreating(bot)
	then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castRange = reboundAbility:GetCastRange()
	local impactDamage = reboundAbility:GetSpecialValueInt("impact_damage")
	local landingRadius = reboundAbility:GetSpecialValueInt("landing_radius")
	local maxJumpDistance = reboundAbility:GetSpecialValueInt("max_jump_distance")
	local manaCost = reboundAbility:GetManaCost()
	local manaAfter = Fu.GetManaAfter(manaCost)
	local manaThreshold = Fu.GetManaThreshold(bot, manaCost, { reboundAbility, bodyguardAbility, unleashAbility })
	for _, allyUnit in pairs(GetUnitList(UNIT_LIST_ALLIES)) do
		if
			Fu.IsValid(allyUnit)
			and bot ~= allyUnit
			and Fu.IsInRange(bot, allyUnit, castRange)
			and (allyUnit:IsHero() or allyUnit:IsCreep())
			and not allyUnit:HasModifier("modifier_enigma_black_hole_pull")
			and not allyUnit:HasModifier("modifier_faceless_void_chronosphere_freeze")
		then
			if Fu.IsGoingOnSomeone(bot) then
				if
					Fu.IsValidHero(botTarget)
					and Fu.CanBeAttacked(botTarget)
					and Fu.IsInRange(allyUnit, botTarget, landingRadius)
					and Fu.CanCastOnNonMagicImmune(botTarget)
					and not botTarget:HasModifier("modifier_enigma_black_hole_pull")
					and not botTarget:HasModifier("modifier_faceless_void_chronosphere_freeze")
					and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
				then
					return BOT_ACTION_DESIRE_HIGH, allyUnit
				end
			end
			if
				Fu.IsRetreating(bot)
				and not Fu.IsRealInvisible(bot)
				and not Fu.IsInRange(bot, allyUnit, castRange / 2)
				and allyUnit:DistanceFromFountain() < bot:DistanceFromFountain()
			then
				local toFountainDirection = (Fu.GetTeamFountain() - bot:GetLocation()):Normalized()
				local toAllyDirection = (allyUnit:GetLocation() - bot:GetLocation()):Normalized()
				local dot = Fu.DotProduct(toFountainDirection, toAllyDirection)
				local angle = math.deg(math.acos(dot))
				if angle <= 40 then
					for _, enemyHero in pairs(nearbyEnemies) do
						if
							Fu.IsValidHero(enemyHero)
							and Fu.IsInRange(bot, enemyHero, 800)
							and not Fu.IsSuspiciousIllusion(enemyHero)
							and not Fu.IsDisabled(enemyHero)
						then
							-- Was returning the enemy (enemyHero): Rebound targets allied units only (enemies only
							-- with Shard), so the escape cast failed or jumped Marci onto the chaser.
							-- Jump to the ally (allyUnit) that is on the way to the fountain.
							if #nearbyEnemies > #nearbyAllies or bot:WasRecentlyDamagedByHero(enemyHero, 3.0) then
								-- Landing direction can't be set (no vector-target order); log to check it.
								if DotaTime() >= (bot._ohaMarciReboundLogAt or -999) then
									bot._ohaMarciReboundLogAt = DotaTime() + 5
									pcall(
										print,
										string.format(
											"[OHA-MARCI] t=%.0f rebound escape via %s",
											DotaTime(),
											allyUnit:GetUnitName()
										)
									)
								end
								return BOT_ACTION_DESIRE_HIGH, allyUnit
							end
						end
					end
				end
			end
			if allyUnit:IsHero() then
				local creepsNearAlly = allyUnit:GetNearbyCreeps(landingRadius, true)
				if
					Fu.IsPushing(bot)
					and isAttacking
					and manaAfter > manaThreshold
					and #nearbyAllies <= 2
					and #nearbyEnemies == 0
				then
					if Fu.IsValid(creepsNearAlly[1]) and Fu.CanBeAttacked(creepsNearAlly[1]) then
						if #creepsNearAlly >= 4 then
							return BOT_ACTION_DESIRE_HIGH, allyUnit
						end
					end
				end
				if
					Fu.IsDefending(bot)
					and isAttacking
					and manaAfter > manaThreshold
					and #nearbyAllies <= 3
					and #nearbyEnemies == 0
				then
					if Fu.IsValid(creepsNearAlly[1]) and Fu.CanBeAttacked(creepsNearAlly[1]) then
						if #creepsNearAlly >= 4 then
							return BOT_ACTION_DESIRE_HIGH, allyUnit
						end
					end
				end
				if Fu.IsFarming(bot) and isAttacking and manaAfter > manaThreshold then
					if Fu.IsValid(creepsNearAlly[1]) and Fu.CanBeAttacked(creepsNearAlly[1]) then
						if
							#creepsNearAlly >= 3
							or #creepsNearAlly >= 2 and creepsNearAlly[1]:IsAncientCreep()
							or #creepsNearAlly >= 1 and creepsNearAlly[1]:GetHealth() >= 550
						then
							return BOT_ACTION_DESIRE_HIGH, allyUnit
						end
					end
				end
				if Fu.IsLaning(bot) and Fu.IsEarlyGame() and manaAfter > manaThreshold and #nearbyEnemies == 0 then
					local aoe =
						bot:FindAoELocation(true, false, allyUnit:GetLocation(), 0, landingRadius - 75, 0, impactDamage)
					if aoe.count >= 3 then
						return BOT_ACTION_DESIRE_HIGH, allyUnit
					end
				end
				if Fu.IsDoingRoshan(bot) then
					if
						Fu.IsRoshan(botTarget)
						and Fu.CanBeAttacked(botTarget)
						and Fu.IsInRange(allyUnit, botTarget, landingRadius)
						and isAttacking
						and manaAfter > manaThreshold + 0.1
					then
						return BOT_ACTION_DESIRE_HIGH, allyUnit
					end
				end
				if Fu.IsDoingTormentor(bot) then
					if
						Fu.IsTormentor(botTarget)
						and Fu.IsInRange(allyUnit, botTarget, landingRadius)
						and isAttacking
						and manaAfter > manaThreshold + 0.1
					then
						return BOT_ACTION_DESIRE_HIGH, allyUnit
					end
				end
			end
			local enemiesNearAlly = Fu.GetEnemiesNearLoc(allyUnit:GetLocation(), landingRadius)
			for _, enemyHero in pairs(enemiesNearAlly) do
				if
					Fu.IsValidHero(enemyHero)
					and Fu.CanBeAttacked(enemyHero)
					and Fu.CanCastOnNonMagicImmune(enemyHero)
				then
					if enemyHero:HasModifier("modifier_teleporting") then
						return BOT_ACTION_DESIRE_HIGH, allyUnit
					end
					if
						Fu.CanKillTarget(enemyHero, impactDamage, DAMAGE_TYPE_MAGICAL)
						and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
						and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
						and not enemyHero:HasModifier("modifier_enigma_black_hole_pull")
						and not enemyHero:HasModifier("modifier_faceless_void_chronosphere_freeze")
						and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
						and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
					then
						return BOT_ACTION_DESIRE_HIGH, allyUnit
					end
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function X.ConsiderUnleash()
	if not Fu.CanCastAbility(unleashAbility) then
		return BOT_ACTION_DESIRE_NONE
	end
	local pulseDamage = unleashAbility:GetSpecialValueInt("pulse_damage")
	local chargesPerFlurry = unleashAbility:GetSpecialValueInt("charges_per_flurry")
	-- Was: any team fight with an enemy core within 1600, so the 16 s Unleash could start while Marci
	-- was still walking in and lose seconds of it. Now an enemy hero must be within 500.
	local enemyClose = false
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidHero(enemyHero)
			and not Fu.IsSuspiciousIllusion(enemyHero)
			and Fu.IsInRange(bot, enemyHero, 500)
		then
			enemyClose = true
			break
		end
	end
	if Fu.IsInTeamFight(bot, 800) and enemyClose then
		local coreCount = 0
		for _, enemyHero in pairs(nearbyEnemies) do
			if Fu.IsValidHero(enemyHero) and Fu.IsCore(enemyHero) then
				coreCount = coreCount + 1
			end
		end
		if
			coreCount > 0
			or (
				Fu.IsLateGame()
				or bot:HasModifier("modifier_dazzle_shallow_grave")
				or bot:HasModifier("modifier_oracle_false_promise_timer")
			)
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidHero(botTarget)
			and Fu.CanBeAttacked(botTarget)
			and Fu.IsInRange(bot, botTarget, 800)
			and botTarget:GetHealth() > pulseDamage + bot:GetAttackDamage() * (chargesPerFlurry + 2)
			and not Fu.IsChasingTarget(bot, botTarget)
			and not botTarget:HasModifier("modifier_abaddon_borrowed_time")
			and not botTarget:HasModifier("modifier_dazzle_shallow_grave")
			and not botTarget:HasModifier("modifier_faceless_void_chronosphere_freeze")
			and not botTarget:HasModifier("modifier_item_blade_mail_reflect")
			and not botTarget:HasModifier("modifier_item_aeon_disk_buff")
		then
			local alliesNear = Fu.GetAlliesNearLoc(bot:GetLocation(), 800)
			local enemiesNear = Fu.GetEnemiesNearLoc(bot:GetLocation(), 800)
			if #alliesNear < #enemiesNear + 2 then
				if
					Fu.GetTotalEstimatedDamageToTarget(alliesNear, botTarget) > botTarget:GetHealth()
					or isAttacking and hpRatio < 0.35
				then
					return BOT_ACTION_DESIRE_HIGH
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
return X
