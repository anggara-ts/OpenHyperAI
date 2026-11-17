-- Hoodwink: skill build, item build, and ability use for this hero.
local X = {}
local bot = GetBot()
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local AbilityContext = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local Minion = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local sTalentList = Fu.Skill.GetTalentList(bot)
local sAbilityList = Fu.Skill.GetAbilityList(bot)
local sRole = Fu.Item.GetRoleItemsBuyList(bot)
local tTalentTreeList = { ["t25"] = { 0, 10 }, ["t20"] = { 10, 0 }, ["t15"] = { 10, 0 }, ["t10"] = { 10, 0 } }
-- Bushwhack first, then Acorn Shot, Scurry last; Sharpshooter at 6/12/18 (it took rank 2 at 13).
local tAllAbilityBuildList = { { 2, 1, 2, 3, 2, 6, 2, 1, 1, 1, 6, 3, 3, 3, 6 } }
local nAbilityBuildList = Fu.Skill.GetRandomBuild(tAllAbilityBuildList)
local nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList)
local sRoleItemsBuyList = {}
sRoleItemsBuyList["pos_4"] = {
	"item_enchanted_mango",
	"item_blood_grenade",
	"item_priest_outfit",
	"item_mekansm",
	"item_glimmer_cape",
	"item_aghanims_shard",
	"item_maelstrom",
	"item_guardian_greaves",
	"item_gungir",
	"item_shivas_guard",
	"item_ultimate_scepter",
	"item_ultimate_scepter_2",
	"item_sheepstick",
	"item_moon_shard",
	"item_octarine_core",
}
sRoleItemsBuyList["pos_5"] = {
	"item_blood_grenade",
	"item_mage_outfit",
	"item_ancient_janggo",
	"item_glimmer_cape",
	"item_boots_of_bearing",
	"item_aghanims_shard",
	"item_shivas_guard",
	"item_cyclone",
	"item_sheepstick",
	"item_wind_waker",
	"item_moon_shard",
	"item_ultimate_scepter_2",
}
sRoleItemsBuyList["pos_3"] = {
	"item_tango",
	"item_double_branches",
	"item_blight_stone",
	"item_tranquil_boots",
	"item_magic_wand",
	"item_mage_slayer",
	"item_maelstrom",
	"item_force_staff",
	"item_mjollnir",
	"item_boots_of_bearing",
	"item_ultimate_scepter",
	"item_sheepstick",
	"item_hurricane_pike",
	"item_aghanims_shard",
	"item_ultimate_scepter_2",
	"item_greater_crit",
	"item_moon_shard",
}
sRoleItemsBuyList["pos_1"] = {
	"item_ranged_carry_outfit",
	"item_dragon_lance",
	"item_rod_of_atos",
	"item_maelstrom",
	"item_black_king_bar",
	"item_mjollnir",
	"item_travel_boots",
	"item_orchid",
	"item_bloodthorn",
	"item_force_staff",
	"item_hurricane_pike",
	"item_ultimate_scepter",
	"item_moon_shard",
	"item_travel_boots_2",
	"item_ultimate_scepter_2",
	"item_butterfly",
}
sRoleItemsBuyList["pos_2"] = sRoleItemsBuyList["pos_1"]
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
local acornShotAbility = SafeAbility(bot:GetAbilityByName("hoodwink_acorn_shot"), "hoodwink_acorn_shot", "hoodwink")
local bushwhackAbility = SafeAbility(bot:GetAbilityByName("hoodwink_bushwhack"), "hoodwink_bushwhack", "hoodwink")
local scurryAbility = SafeAbility(bot:GetAbilityByName("hoodwink_scurry"), "hoodwink_scurry", "hoodwink")
local huntersBoomerangAbility =
	SafeAbility(bot:GetAbilityByName("hoodwink_hunters_boomerang"), "hoodwink_hunters_boomerang", "hoodwink")
local decoyAbility = SafeAbility(bot:GetAbilityByName("hoodwink_decoy"), "hoodwink_decoy", "hoodwink")
local sharpshooterAbility =
	SafeAbility(bot:GetAbilityByName("hoodwink_sharpshooter"), "hoodwink_sharpshooter", "hoodwink")
local acornShotDesire, acornShotLocation
local bushwhackDesire, bushwhackLocation
local scurryDesire
local huntersBoomerangDesire, huntersBoomerangTarget
local decoyDesire
local sharpshooterDesire, sharpshooterLocation
local botTarget
local isGoingOnSomeone
local isRetreating
local hpRatio
function X.SkillsComplement()
	local context = AbilityContext.Build(bot)
	isGoingOnSomeone = context.isEngaging
	isRetreating = context.isRetreating
	hpRatio = context.hp
	if Fu.CanNotUseAbility(bot) then
		return
	end
	acornShotDesire, acornShotLocation = X.ConsiderAcornShot()
	if acornShotDesire > 0 then
		bot:Action_UseAbilityOnLocation(acornShotAbility, acornShotLocation)
		return
	end
	bushwhackDesire, bushwhackLocation = X.ConsiderBushwhack()
	if bushwhackDesire > 0 then
		bot:Action_UseAbilityOnLocation(bushwhackAbility, bushwhackLocation)
		return
	end
	scurryDesire = X.ConsiderScurry()
	if scurryDesire > 0 then
		bot:Action_UseAbility(scurryAbility)
		return
	end
	huntersBoomerangDesire, huntersBoomerangTarget = X.ConsiderHuntersBoomerang()
	if huntersBoomerangDesire > 0 then
		bot:Action_UseAbilityOnEntity(huntersBoomerangAbility, huntersBoomerangTarget)
		return
	end
	decoyDesire = X.ConsiderDecoy()
	if decoyDesire > 0 then
		bot:Action_UseAbility(decoyAbility)
		return
	end
	sharpshooterDesire, sharpshooterLocation = X.ConsiderSharpshooter()
	if sharpshooterDesire > 0 then
		bot:Action_UseAbilityOnLocation(sharpshooterAbility, sharpshooterLocation)
		return
	end
end
function X.ConsiderAcornShot()
	if not acornShotAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castRange = Fu.GetProperCastRange(false, bot, acornShotAbility:GetCastRange())
	local castPoint = acornShotAbility:GetCastPoint()
	local bounceRange = acornShotAbility:GetSpecialValueInt("bounce_range")
	-- datafeed: an acorn hit is base_damage_pct (80%) of the attack plus acorn_shot_damage
	-- (45-180). It was bonus x attack x 0.75 (thousands), so the "kill" check passed on every
	-- hero in range and Acorn Shot was fired on cooldown at anyone, at any mana.
	local damage = bot:GetAttackDamage() * acornShotAbility:GetSpecialValueInt("base_damage_pct") / 100
		+ acornShotAbility:GetSpecialValueInt("acorn_shot_damage")
	local projectileSpeed = acornShotAbility:GetSpecialValueInt("projectile_speed")
	local abilityLevel = acornShotAbility:GetLevel()
	botTarget = Fu.GetProperTarget(bot)
	local nearbyEnemies = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanBeAttacked(enemyHero)
			and Fu.CanKillTarget(enemyHero, damage, DAMAGE_TYPE_PHYSICAL)
			and not Fu.IsSuspiciousIllusion(enemyHero)
			and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
			and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
			and not enemyHero:HasModifier("modifier_templar_assassin_refraction_absorb")
		then
			local delay = GetUnitToUnitDistance(bot, enemyHero) / projectileSpeed + castPoint
			return BOT_ACTION_DESIRE_HIGH, enemyHero:GetExtrapolatedLocation(delay)
		end
	end
	local nearbyAllies = Fu.GetNearbyHeroes(bot, castRange, false, BOT_MODE_NONE)
	for _, allyHero in pairs(nearbyAllies) do
		local allyNearbyEnemies = Fu.GetNearbyHeroes(allyHero, castRange, true, BOT_MODE_NONE)
		if
			Fu.IsValidHero(allyHero)
			and (Fu.IsRetreating(allyHero) and Fu.GetHP(allyHero) < 0.75 and allyHero:WasRecentlyDamagedByAnyHero(2))
			and not allyHero:IsIllusion()
		then
			if
				allyNearbyEnemies ~= nil
				and #allyNearbyEnemies >= 1
				and Fu.IsValidHero(allyNearbyEnemies[1])
				and Fu.IsInRange(bot, allyNearbyEnemies[1], castRange)
				and not Fu.IsSuspiciousIllusion(allyNearbyEnemies[1])
				and not Fu.IsDisabled(allyNearbyEnemies[1])
			then
				local delay = GetUnitToUnitDistance(bot, allyNearbyEnemies[1]) / projectileSpeed + castPoint
				return BOT_ACTION_DESIRE_HIGH, allyNearbyEnemies[1]:GetExtrapolatedLocation(delay)
			end
		end
	end
	if isGoingOnSomeone then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, castRange + 100, false, BOT_MODE_NONE)
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and not Fu.IsDisabled(botTarget)
			and nearbyAllies ~= nil
			and nearbyEnemies ~= nil
			and #nearbyAllies >= #nearbyEnemies
		then
			local delay = GetUnitToUnitDistance(bot, botTarget) / projectileSpeed + castPoint
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetExtrapolatedLocation(delay)
		end
	end
	if isRetreating then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, castRange + 100, false, BOT_MODE_NONE)
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
		if
			nearbyAllies ~= nil
			and nearbyEnemies
			and (#nearbyEnemies > #nearbyAllies or hpRatio < 0.65 and bot:WasRecentlyDamagedByAnyHero(2.5))
			and Fu.IsValidHero(nearbyEnemies[1])
			and not Fu.IsSuspiciousIllusion(nearbyEnemies[1])
			and not Fu.IsDisabled(nearbyEnemies[1])
		then
			return BOT_ACTION_DESIRE_HIGH, nearbyEnemies[1]:GetLocation()
		end
	end
	if
		(Fu.IsPushing(bot) or Fu.IsDefending(bot))
		and (Fu.HasItem(bot, "item_maelstrom") or Fu.HasItem(bot, "item_mjollnir"))
		and abilityLevel >= 3
		and not Fu.IsThereNonSelfCoreNearby(600)
	then
		local nearbyLaneCreeps = bot:GetNearbyLaneCreeps(castRange, true)
		local aoe = bot:FindAoELocation(true, false, bot:GetLocation(), castRange, bounceRange, castPoint, 0)
		if nearbyLaneCreeps ~= nil and #nearbyLaneCreeps >= 4 and aoe.count >= 4 then
			return BOT_ACTION_DESIRE_HIGH, aoe.targetloc
		end
	end
	if not acornShotAbility:GetAutoCastState() then
		acornShotAbility:ToggleAutoCast()
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.ConsiderBushwhack()
	if not bushwhackAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local castRange = Fu.GetProperCastRange(false, bot, bushwhackAbility:GetCastRange())
	local castPoint = bushwhackAbility:GetCastPoint()
	local damage = bushwhackAbility:GetSpecialValueInt("total_damage")
	local radius = bushwhackAbility:GetSpecialValueInt("trap_radius")
	local projectileSpeed = bushwhackAbility:GetSpecialValueInt("projectile_speed")
	botTarget = Fu.GetProperTarget(bot)
	local nearbyEnemies = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and not Fu.IsSuspiciousIllusion(enemyHero)
		then
			local nearbyTrees = enemyHero:GetNearbyTrees(radius - 25)
			if nearbyTrees ~= nil and #nearbyTrees > 0 then
				if enemyHero:IsChanneling() or Fu.IsCastingUltimateAbility(enemyHero) then
					return BOT_ACTION_DESIRE_HIGH, enemyHero:GetLocation()
				end
				if
					Fu.CanKillTarget(enemyHero, damage, DAMAGE_TYPE_MAGICAL)
					and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
					and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
					and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
					and not enemyHero:HasModifier("modifier_templar_assassin_refraction_absorb")
				then
					local delay = GetUnitToUnitDistance(bot, enemyHero) / projectileSpeed + castPoint
					return BOT_ACTION_DESIRE_HIGH, enemyHero:GetExtrapolatedLocation(delay)
				end
			end
		end
	end
	local nearbyAllies = Fu.GetNearbyHeroes(bot, castRange, false, BOT_MODE_NONE)
	for _, allyHero in pairs(nearbyAllies) do
		local allyNearbyEnemies = Fu.GetNearbyHeroes(allyHero, castRange, true, BOT_MODE_NONE)
		if
			Fu.IsValidHero(allyHero)
			and (Fu.IsRetreating(allyHero) and allyHero:WasRecentlyDamagedByAnyHero(2.5))
			and not allyHero:IsIllusion()
		then
			if
				allyNearbyEnemies ~= nil
				and #allyNearbyEnemies >= 1
				and Fu.IsValidHero(allyNearbyEnemies[1])
				and Fu.IsInRange(bot, allyNearbyEnemies[1], castRange)
				and not Fu.IsSuspiciousIllusion(allyNearbyEnemies[1])
				and not Fu.IsDisabled(allyNearbyEnemies[1])
			then
				local nearbyTrees = allyNearbyEnemies[1]:GetNearbyTrees(radius - 25)
				if nearbyTrees ~= nil and #nearbyTrees > 0 then
					local delay = GetUnitToUnitDistance(bot, allyNearbyEnemies[1]) / projectileSpeed + castPoint
					return BOT_ACTION_DESIRE_HIGH, allyNearbyEnemies[1]:GetExtrapolatedLocation(delay)
				end
			end
		end
	end
	if Fu.IsInTeamFight(bot, 1200) then
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
		local aoe = bot:FindAoELocation(true, true, bot:GetLocation(), castRange, radius, castPoint, 0)
		if aoe.count >= 2 then
			for _, enemyHero in pairs(nearbyEnemies) do
				if
					Fu.IsValidHero(enemyHero)
					and Fu.CanCastOnNonMagicImmune(enemyHero)
					and not Fu.IsSuspiciousIllusion(enemyHero)
					and not Fu.IsDisabled(enemyHero)
					and not enemyHero:HasModifier("modifier_faceless_void_chronosphere_freeze")
					and GetUnitToLocationDistance(enemyHero, aoe.targetloc) <= radius
				then
					local nearbyTrees = enemyHero:GetNearbyTrees(radius - 25)
					if nearbyTrees ~= nil and #nearbyTrees > 0 then
						local delay = GetUnitToUnitDistance(bot, enemyHero) / projectileSpeed + castPoint
						return BOT_ACTION_DESIRE_HIGH, enemyHero:GetExtrapolatedLocation(delay)
					end
				end
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
		then
			local nearbyTrees = botTarget:GetNearbyTrees(radius - 25)
			if nearbyTrees ~= nil and #nearbyTrees > 0 then
				local delay = GetUnitToUnitDistance(bot, botTarget) / projectileSpeed + castPoint
				return BOT_ACTION_DESIRE_HIGH, botTarget:GetExtrapolatedLocation(delay)
			end
		end
	end
	if isRetreating then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, castRange + 100, false, BOT_MODE_NONE)
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
		if
			nearbyAllies ~= nil
			and nearbyEnemies
			and (#nearbyEnemies > #nearbyAllies or hpRatio < 0.65 and bot:WasRecentlyDamagedByAnyHero(2.5))
			and Fu.IsValidHero(nearbyEnemies[1])
			and Fu.CanCastOnNonMagicImmune(nearbyEnemies[1])
			and not Fu.IsSuspiciousIllusion(nearbyEnemies[1])
			and not Fu.IsDisabled(nearbyEnemies[1])
		then
			local nearbyTrees = nearbyEnemies[1]:GetNearbyTrees(radius - 25)
			if nearbyTrees ~= nil and #nearbyTrees > 0 then
				return BOT_ACTION_DESIRE_HIGH, nearbyEnemies[1]:GetLocation()
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.ConsiderScurry()
	if
		not scurryAbility:IsFullyCastable()
		or bot:HasModifier("modifier_hoodwink_scurry_active")
		or Fu.IsRealInvisible(bot)
	then
		return BOT_ACTION_DESIRE_NONE
	end
	if isRetreating then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, 800, false, BOT_MODE_NONE)
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, 600, true, BOT_MODE_NONE)
		local escapeLocation = Fu.GetEscapeLoc()
		if bot:IsFacingLocation(escapeLocation, 30) then
			if
				nearbyAllies ~= nil
				and nearbyEnemies
				and (#nearbyEnemies > #nearbyAllies or hpRatio < 0.55 and bot:WasRecentlyDamagedByAnyHero(2))
				and Fu.IsValidHero(nearbyEnemies[1])
				and not Fu.IsSuspiciousIllusion(nearbyEnemies[1])
				and not Fu.IsDisabled(nearbyEnemies[1])
			then
				return BOT_ACTION_DESIRE_HIGH
			end
			if hpRatio < 0.55 and bot:WasRecentlyDamagedByTower(2.5) then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderSharpshooter()
	if not sharpshooterAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local castRange = 1600
	local attackRange = bot:GetAttackRange()
	local arrowSpeed = sharpshooterAbility:GetSpecialValueInt("arrow_speed")
	botTarget = Fu.GetProperTarget(bot)
	if isGoingOnSomeone then
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and not Fu.IsInRange(bot, botTarget, attackRange)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not botTarget:HasModifier("modifier_dazzle_shallow_grave")
			and not botTarget:HasModifier("modifier_templar_assassin_refraction_absorb")
		then
			local delay = GetUnitToUnitDistance(bot, botTarget) / arrowSpeed
			local directionStability = botTarget:GetMovementDirectionStability()
			local aimLocation = botTarget:GetExtrapolatedLocation(delay)
			if directionStability < 0.95 then
				aimLocation = botTarget:GetLocation()
			end
			return BOT_ACTION_DESIRE_HIGH, aimLocation
		end
	end
	if Fu.IsDefending(bot) then
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.IsInRange(bot, enemyHero, castRange)
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
				and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
				and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
				and not enemyHero:HasModifier("modifier_templar_assassin_refraction_absorb")
			then
				return BOT_ACTION_DESIRE_HIGH, enemyHero:GetLocation()
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.ConsiderHuntersBoomerang()
	if not huntersBoomerangAbility:IsTrained() or not huntersBoomerangAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castRange = Fu.GetProperCastRange(false, bot, huntersBoomerangAbility:GetCastRange())
	local radius = huntersBoomerangAbility:GetSpecialValueInt("radius")
	local castPoint = huntersBoomerangAbility:GetCastPoint()
	if Fu.IsInTeamFight(bot, 1200) then
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
		local aoe = bot:FindAoELocation(true, true, bot:GetLocation(), castRange, radius, castPoint, 0)
		if aoe.count >= 2 then
			for _, enemyHero in pairs(nearbyEnemies) do
				if
					Fu.IsValidHero(enemyHero)
					and Fu.CanCastOnNonMagicImmune(enemyHero)
					and not Fu.IsSuspiciousIllusion(enemyHero)
					and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
					and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
					and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
					and not enemyHero:HasModifier("modifier_templar_assassin_refraction_absorb")
					and not enemyHero:HasModifier("modifier_faceless_void_chronosphere_freeze")
					and GetUnitToLocationDistance(enemyHero, aoe.targetloc) <= radius
				then
					return BOT_ACTION_DESIRE_HIGH, enemyHero
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function X.ConsiderDecoy()
	if not decoyAbility:IsTrained() or not decoyAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
	end
	local nearbyEnemyTowers = bot:GetNearbyTowers(900, true)
	local nearbyEnemies = Fu.GetNearbyHeroes(bot, 900, true, BOT_MODE_NONE)
	botTarget = Fu.GetProperTarget(bot)
	if
		bot:DistanceFromFountain() > 600
		and nearbyEnemyTowers ~= nil
		and #nearbyEnemyTowers == 0
		and not bot:HasModifier("modifier_item_dustofappearance")
		and not bot:HasModifier("modifier_slardar_amplify_damage")
		and not bot:HasModifier("modifier_item_glimmer_cape")
		and not bot:IsInvulnerable()
		and not bot:IsMagicImmune()
	then
		if bot:IsSilenced() or bot:IsRooted() or Fu.IsStunProjectileIncoming(bot, bot:GetAttackRange()) then
			return BOT_ACTION_DESIRE_HIGH
		end
		if
			isRetreating
				and bot:GetActiveModeDesire() >= BOT_MODE_DESIRE_HIGH
				and not bot:HasModifier("modifier_fountain_aura")
			or botTarget == nil
				and nearbyEnemies ~= nil
				and #nearbyEnemies >= 1
				and hpRatio < 0.33 + 0.09 * #nearbyEnemies
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
return X
