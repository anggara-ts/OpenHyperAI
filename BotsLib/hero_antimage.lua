-- Antimage: skill build, item build, and ability use for this hero.
local X = {}
local bot = GetBot()
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local AbilityContext = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local Minion = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local sTalentList = Fu.Skill.GetTalentList(bot)
local sAbilityList = Fu.Skill.GetAbilityList(bot)
local sRole = Fu.Item.GetRoleItemsBuyList(bot)
local tTalentTreeList = { ["t25"] = { 10, 0 }, ["t20"] = { 10, 0 }, ["t15"] = { 10, 0 }, ["t10"] = { 10, 0 } }
local tAllAbilityBuildList = { { 1, 2, 1, 3, 1, 6, 2, 2, 2, 1, 6, 3, 3, 3, 6 } }
local nAbilityBuildList = Fu.Skill.GetRandomBuild(tAllAbilityBuildList)
local nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList)
local sRoleItemsBuyList = {}
-- Stratz 7.41f, week of 9 Nov 2026: pos 1, 300,605 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_1"] = {
	"item_tango",
	"item_quelling_blade",
	"item_double_branches",
	"item_magic_stick",
	"item_faerie_fire",
	"item_magic_wand",
	"item_power_treads",
	"item_bfury",
	"item_manta",
	"item_butterfly",
	"item_black_king_bar",
	"item_sange",
	"item_abyssal_blade",
	"item_aghanims_shard",
	"item_ultimate_scepter_2",
	"item_travel_boots",
	"item_moon_shard",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 2, 13,068 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_2"] = {
	"item_tango",
	"item_quelling_blade",
	"item_double_branches",
	"item_circlet",
	"item_wraith_band",
	"item_magic_wand",
	"item_power_treads",
	"item_bfury",
	"item_manta",
	"item_basher",
	"item_black_king_bar",
	"item_sange",
	"item_abyssal_blade",
	"item_travel_boots",
	"item_ultimate_scepter_2",
	"item_moon_shard",
	"item_vanguard",
	"item_aghanims_shard",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 3, 5,671 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_3"] = {
	"item_tango",
	"item_quelling_blade",
	"item_double_branches",
	"item_circlet",
	"item_wraith_band",
	"item_magic_wand",
	"item_power_treads",
	"item_bfury",
	"item_manta",
	"item_basher",
	"item_sange",
	"item_black_king_bar",
	"item_abyssal_blade",
	"item_travel_boots",
	"item_ultimate_scepter_2",
	"item_diffusal_blade",
	"item_disperser",
	"item_aghanims_shard",
	"item_moon_shard",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 4, 1,632 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_4"] = {
	"item_tango",
	"item_blood_grenade",
	"item_double_branches",
	"item_quelling_blade",
	"item_magic_stick",
	"item_magic_wand",
	"item_power_treads",
	"item_bfury",
	"item_manta",
	"item_basher",
	"item_sange",
	"item_black_king_bar",
	"item_aghanims_shard",
	"item_moon_shard",
	"item_ultimate_scepter_2",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 5, 2,364 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_5"] = {
	"item_tango",
	"item_double_branches",
	"item_quelling_blade",
	"item_magic_stick",
	"item_magic_wand",
	"item_power_treads",
	"item_bfury",
	"item_manta",
	"item_basher",
	"item_black_king_bar",
	"item_sange",
	"item_abyssal_blade",
	"item_ultimate_scepter_2",
	"item_diffusal_blade",
	"item_aghanims_shard",
	"item_moon_shard",
}
X["sBuyList"] = sRoleItemsBuyList[sRole]
X["sSellList"] = {
	"item_skadi",
	"item_magic_wand",
	-- Sold once the item before it is owned, to keep six slots (Util/item-builds/generate.js):
	"item_abyssal_blade",
	"item_sange",
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
	if Minion.IsValidUnit(hMinionUnit) then
		if Fu.IsValidHero(hMinionUnit) and hMinionUnit:IsIllusion() then
			Minion.IllusionThink(hMinionUnit)
		end
	end
end
local blinkAbility = SafeAbility(bot:GetAbilityByName("antimage_blink"), "antimage_blink", "antimage")
local counterspellAbility =
	SafeAbility(bot:GetAbilityByName("antimage_counterspell"), "antimage_counterspell", "antimage")
local manaVoidAbility = SafeAbility(bot:GetAbilityByName("antimage_mana_void"), "antimage_mana_void", "antimage")
local blinkDesire, blinkLocation
local counterspellDesire
local manaVoidDesire, manaVoidTarget
local blinkVoidDesire, blinkVoidLocation, blinkVoidTarget
local botTarget
local isGoingOnSomeone
function X.SkillsComplement()
	if Fu.CanNotUseAbility(bot) then
		return
	end
	local context = AbilityContext.Build(bot)
	isGoingOnSomeone = context.isEngaging
	botTarget = context.target
	blinkVoidDesire, blinkVoidLocation, blinkVoidTarget = X.ConsiderBlinkVoid()
	if blinkVoidDesire > 0 then
		Fu.SetQueuePtToINT(bot, false)
		-- fix: the kill target was blinked to even when already inside Mana Void range (600),
		-- spending Blink (his escape) for nothing. Void directly then.
		if Fu.IsInRange(bot, blinkVoidTarget, manaVoidAbility:GetCastRange()) then
			bot:ActionQueue_UseAbilityOnEntity(manaVoidAbility, blinkVoidTarget)
			return
		end
		bot:ActionQueue_UseAbilityOnLocation(blinkAbility, blinkVoidLocation)
		bot:ActionQueue_Delay(0.1)
		bot:ActionQueue_UseAbilityOnEntity(manaVoidAbility, blinkVoidTarget)
		return
	end
	counterspellDesire = X.ConsiderCounterSpell()
	if counterspellDesire > 0 then
		Fu.SetQueuePtToINT(bot, false)
		bot:ActionQueue_UseAbility(counterspellAbility)
		return
	end
	blinkDesire, blinkLocation = X.ConsiderBlink()
	if blinkDesire > 0 then
		Fu.SetQueuePtToINT(bot, false)
		bot:ActionQueue_UseAbilityOnLocation(blinkAbility, blinkLocation)
		return
	end
	manaVoidDesire, manaVoidTarget = X.ConsiderManaVoid()
	if manaVoidDesire > 0 then
		Fu.SetQueuePtToINT(bot, false)
		bot:ActionQueue_UseAbilityOnEntity(manaVoidAbility, manaVoidTarget)
		return
	end
end
function X.ConsiderBlink()
	if not blinkAbility:IsFullyCastable() or bot:IsRooted() or bot:HasModifier("modifier_bloodseeker_rupture") then
		return BOT_ACTION_DESIRE_NONE
	end
	local blinkRange = blinkAbility:GetSpecialValueInt("AbilityCastRange") - 1
	local castPoint = blinkAbility:GetCastPoint()
	local attackPoint = bot:GetAttackPoint()
	if Fu.IsStuck(bot) then
		local escapeLocation = Fu.GetEscapeLoc()
		return BOT_ACTION_DESIRE_HIGH, Fu.Site.GetXUnitsTowardsLocation(bot, escapeLocation, blinkRange)
	end
	if
		(Fu.IsStunProjectileIncoming(bot, 600) or Fu.IsUnitTargetProjectileIncoming(bot, 400))
		and not counterspellAbility:IsFullyCastable()
	then
		return BOT_ACTION_DESIRE_HIGH, Fu.Site.GetXUnitsTowardsLocation(bot, Fu.GetTeamFountain(), blinkRange)
	end
	if
		not bot:HasModifier("modifier_sniper_assassinate")
		and not bot:IsMagicImmune()
		and not counterspellAbility:IsFullyCastable()
	then
		if Fu.IsWillBeCastUnitTargetSpell(bot, 400) then
			return BOT_ACTION_DESIRE_HIGH, Fu.Site.GetXUnitsTowardsLocation(bot, Fu.GetTeamFountain(), blinkRange)
		end
	end
	if isGoingOnSomeone then
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnMagicImmune(botTarget)
			and not Fu.IsInRange(bot, botTarget, 400)
			and not botTarget:IsAttackImmune()
			and not botTarget:HasModifier("modifier_abaddon_borrowed_time")
			and not botTarget:HasModifier("modifier_faceless_void_chronosphere_freeze")
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			local alliesNearTarget = Fu.GetNearbyHeroes(botTarget, 1200, true, BOT_MODE_NONE)
			local enemiesNearTarget = Fu.GetNearbyHeroes(botTarget, 1200, false, BOT_MODE_NONE)
			if alliesNearTarget ~= nil and enemiesNearTarget ~= nil and #alliesNearTarget >= #enemiesNearTarget then
				local blinkLocation = botTarget:GetExtrapolatedLocation(castPoint + 0.53)
				if GetUnitToUnitDistance(bot, botTarget) > blinkRange then
					blinkLocation = Fu.Site.GetXUnitsTowardsLocation(bot, botTarget:GetLocation(), blinkRange)
				end
				if Fu.IsInLaningPhase() then
					local towersNearTarget = botTarget:GetNearbyTowers(700, false)
					if
						towersNearTarget ~= nil and #towersNearTarget == 0
						or bot:GetHealth() > Fu.GetTotalEstimatedDamageToTarget(enemiesNearTarget, bot)
							and Fu.WillKillTarget(botTarget, bot:GetAttackDamage() * 3, DAMAGE_TYPE_PHYSICAL, 2)
					then
						bot:SetTarget(botTarget)
						return BOT_ACTION_DESIRE_HIGH, blinkLocation
					end
				else
					bot:SetTarget(botTarget)
					return BOT_ACTION_DESIRE_HIGH, blinkLocation
				end
			end
		end
	end
	if Fu.IsRetreating(bot) then
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE)
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValidHero(enemyHero)
				and bot:DistanceFromFountain() > 600
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and not Fu.IsDisabled(enemyHero)
				and not Fu.IsRealInvisible(bot)
			then
				local alliesNearEnemy = Fu.GetNearbyHeroes(enemyHero, 1200, true, BOT_MODE_NONE)
				local enemiesNearEnemy = Fu.GetNearbyHeroes(enemyHero, 1200, false, BOT_MODE_NONE)
				if
					alliesNearEnemy ~= nil
					and enemiesNearEnemy ~= nil
					and (
						#enemiesNearEnemy > #alliesNearEnemy
						or bot:WasRecentlyDamagedByAnyHero(2)
						or Fu.GetHP(bot) < 0.2 and Fu.IsChasingTarget(enemyHero, bot)
					)
				then
					return BOT_ACTION_DESIRE_HIGH,
						Fu.Site.GetXUnitsTowardsLocation(bot, Fu.GetTeamFountain(), blinkRange)
				end
			end
		end
	end
	if Fu.IsLaning(bot) then
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE)
		local enemyTowers = bot:GetNearbyTowers(1600, true)
		if
			Fu.GetManaAfter(blinkAbility:GetManaCost()) > 0.85
			and Fu.IsInLaningPhase()
			and bot:DistanceFromFountain() > 300
			and bot:DistanceFromFountain() < 6000
			and nearbyEnemies ~= nil
			and #nearbyEnemies == 0
			and enemyTowers ~= nil
			and #enemyTowers == 0
		then
			local assignedLane = bot:GetAssignedLane()
			local laneFrontLocation = GetLaneFrontLocation(GetTeam(), assignedLane, 0)
			local laneFrontDistance = GetUnitToLocationDistance(bot, laneFrontLocation)
			if laneFrontDistance > blinkRange then
				local blinkLocation = Fu.Site.GetXUnitsTowardsLocation(bot, laneFrontLocation, blinkRange)
				if IsLocationPassable(blinkLocation) then
					return BOT_ACTION_DESIRE_HIGH, blinkLocation
				end
			end
		end
	end
	if Fu.IsPushing(bot) and bot:GetActiveModeDesire() > BOT_MODE_DESIRE_HIGH then
		local nearbyAllies = Fu.GetAlliesNearLoc(bot:GetLocation(), 600)
		local nearbyEnemies = Fu.GetEnemiesNearLoc(bot:GetLocation(), 1200)
		local enemyTowers = bot:GetNearbyTowers(700, true)
		local enemyLaneCreeps = bot:GetNearbyLaneCreeps(1200, true)
		if
			enemyLaneCreeps ~= nil
			and #enemyLaneCreeps >= 3
			and nearbyEnemies ~= nil
			and #nearbyEnemies == 0
			and nearbyAllies ~= nil
			and #nearbyAllies <= 1
			and GetUnitToLocationDistance(bot, Fu.GetCenterOfUnits(enemyLaneCreeps)) > bot:GetAttackRange()
			and Fu.CanBeAttacked(enemyLaneCreeps[1])
		then
			local towersNearLastCreep = enemyLaneCreeps[#enemyLaneCreeps]:GetNearbyTowers(700, false)
			if towersNearLastCreep ~= nil and #towersNearLastCreep == 0 then
				return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(enemyLaneCreeps)
			end
		end
	end
	if Fu.IsDoingRoshan(bot) then
		local roshanLocation = Fu.GetCurrentRoshanLocation()
		if GetUnitToLocationDistance(bot, roshanLocation) > blinkRange then
			local blinkLocation = Fu.Site.GetXUnitsTowardsLocation(bot, roshanLocation, blinkRange)
			local enemiesNearRoshan = Fu.GetEnemiesNearLoc(roshanLocation, 1600)
			if enemiesNearRoshan ~= nil and #enemiesNearRoshan == 0 and IsLocationPassable(blinkLocation) then
				return BOT_ACTION_DESIRE_HIGH, blinkLocation
			end
		end
	end
	if Fu.IsDoingTormentor(bot) then
		local tormentorLocation = Fu.GetTormentorLocation(GetTeam())
		if GetUnitToLocationDistance(bot, tormentorLocation) > blinkRange then
			local blinkLocation = Fu.Site.GetXUnitsTowardsLocation(bot, tormentorLocation, blinkRange)
			local enemiesNearBlinkLocation = Fu.GetEnemiesNearLoc(blinkLocation, 1600)
			if
				enemiesNearBlinkLocation ~= nil
				and #enemiesNearBlinkLocation == 0
				and IsLocationPassable(blinkLocation)
			then
				return BOT_ACTION_DESIRE_HIGH, blinkLocation
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderCounterSpell()
	if not counterspellAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
	end
	if Fu.IsUnitTargetProjectileIncoming(bot, 400) then
		return BOT_ACTION_DESIRE_HIGH
	end
	if not bot:HasModifier("modifier_sniper_assassinate") and not bot:IsMagicImmune() then
		if Fu.IsWillBeCastUnitTargetSpell(bot, 1400) then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderManaVoid()
	if not manaVoidAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
	end
	local castRange = manaVoidAbility:GetCastRange()
	local aoeRadius = manaVoidAbility:GetSpecialValueInt("mana_void_aoe_radius")
	local damagePerMana = manaVoidAbility:GetSpecialValueFloat("mana_void_damage_per_mana")
	if Fu.IsInTeamFight(bot, 1200) then
		local killTarget = nil
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, castRange + 200, true, BOT_MODE_NONE)
		for _, enemyHero in pairs(nearbyEnemies) do
			local manaVoidDamage = damagePerMana * (enemyHero:GetMaxMana() - enemyHero:GetMana())
			if
				Fu.IsValidHero(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.CanKillTarget(enemyHero, manaVoidDamage, DAMAGE_TYPE_MAGICAL)
				and not Fu.IsHaveAegis(enemyHero)
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and not enemyHero:HasModifier("modifier_arc_warden_tempest_double")
				and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
				and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
				and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
			then
				killTarget = enemyHero
				break
			end
		end
		if killTarget ~= nil then
			bot:SetTarget(killTarget)
			return BOT_ACTION_DESIRE_HIGH, killTarget
		end
	end
	if isGoingOnSomeone then
		if
			Fu.IsValidHero(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.CanCastOnTargetAdvanced(botTarget)
			and not Fu.IsHaveAegis(botTarget)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not botTarget:HasModifier("modifier_arc_warden_tempest_double")
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			local alliesNearTarget = Fu.GetNearbyHeroes(botTarget, 1200, true, BOT_MODE_NONE)
			local enemiesNearTarget = Fu.GetNearbyHeroes(botTarget, 1200, false, BOT_MODE_NONE)
			local manaVoidDamage = damagePerMana * (botTarget:GetMaxMana() - botTarget:GetMana())
			if alliesNearTarget ~= nil and enemiesNearTarget ~= nil and #alliesNearTarget >= #enemiesNearTarget then
				if Fu.CanKillTarget(botTarget, manaVoidDamage, DAMAGE_TYPE_MAGICAL) then
					return BOT_ACTION_DESIRE_HIGH, botTarget
				end
			end
		end
	end
	return 0
end
function X.ConsiderBlinkVoid()
	if not blinkAbility:IsFullyCastable() or not manaVoidAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0, nil
	end
	if blinkAbility:GetManaCost() + manaVoidAbility:GetManaCost() > bot:GetMana() then
		return BOT_ACTION_DESIRE_NONE, 0, nil
	end
	local blinkRange = blinkAbility:GetSpecialValueInt("AbilityCastRange")
	local damagePerMana = manaVoidAbility:GetSpecialValueFloat("mana_void_damage_per_mana")
	local killTarget = nil
	local blinkVoidRange = manaVoidAbility:GetCastRange() + blinkRange
	local enemyHeroes = GetUnitList(UNIT_LIST_ENEMY_HEROES)
	for _, enemyHero in pairs(enemyHeroes) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.IsInRange(bot, enemyHero, blinkVoidRange)
			and Fu.CanCastOnTargetAdvanced(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and not Fu.IsSuspiciousIllusion(enemyHero)
			and not enemyHero:HasModifier("modifier_arc_warden_tempest_double")
			and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
			and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
			and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
		then
			local alliesNearEnemy = Fu.GetNearbyHeroes(enemyHero, 1600, true, BOT_MODE_NONE)
			local enemiesNearEnemy = Fu.GetNearbyHeroes(enemyHero, 1600, false, BOT_MODE_NONE)
			local manaVoidDamage = damagePerMana * (enemyHero:GetMaxMana() - enemyHero:GetMana())
			if alliesNearEnemy ~= nil and enemiesNearEnemy ~= nil and #alliesNearEnemy >= #enemiesNearEnemy then
				if Fu.CanKillTarget(enemyHero, manaVoidDamage, DAMAGE_TYPE_MAGICAL) then
					killTarget = enemyHero
				end
			end
		end
	end
	if killTarget ~= nil then
		return BOT_ACTION_DESIRE_HIGH, killTarget:GetLocation(), killTarget
	end
	return BOT_ACTION_DESIRE_NONE, 0, nil
end
return X
