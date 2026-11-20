-- Dragon Knight: skill build, item build, and ability use for this hero.
local X = {}
local bot = GetBot()
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local AbilityContext = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local Minion = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local sTalentList = Fu.Skill.GetTalentList(bot)
local sAbilityList = Fu.Skill.GetAbilityList(bot)
local sRole = Fu.Item.GetRoleItemsBuyList(bot)
local tTalentTreeList = {
	{ ["t25"] = { 10, 0 }, ["t20"] = { 0, 10 }, ["t15"] = { 10, 0 }, ["t10"] = { 0, 10 } },
	{ ["t25"] = { 10, 0 }, ["t20"] = { 0, 10 }, ["t15"] = { 10, 0 }, ["t10"] = { 0, 10 } },
}
local tAllAbilityBuildList =
	{ { 1, 2, 1, 3, 1, 6, 1, 3, 3, 3, 6, 2, 2, 2, 6 }, { 1, 2, 1, 3, 1, 6, 1, 3, 3, 3, 6, 2, 2, 2, 6 } }
local nAbilityBuildList
local nTalentBuildList
if sRole == "pos_2" then
	nAbilityBuildList = tAllAbilityBuildList[1]
	nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList[1])
else
	nAbilityBuildList = tAllAbilityBuildList[2]
	nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList[2])
end
local sRoleItemsBuyList = {}
-- Stratz 7.41f, week of 9 Nov 2026: pos 2, 81,132 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_2"] = {
	"item_tango",
	"item_double_gauntlets",
	"item_double_branches",
	"item_quelling_blade",
	"item_bracer",
	"item_magic_wand",
	"item_soul_ring",
	"item_power_treads",
	"item_blink",
	"item_black_king_bar",
	"item_octarine_core",
	"item_buckler",
	"item_ultimate_scepter",
	"item_assault",
	"item_overwhelming_blink",
	"item_ultimate_scepter_2",
	"item_greater_crit",
	"item_aghanims_shard",
	"item_moon_shard",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 1, 20,780 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_1"] = {
	"item_tango",
	"item_double_gauntlets",
	"item_quelling_blade",
	"item_double_branches",
	"item_bracer",
	"item_magic_wand",
	"item_soul_ring",
	"item_power_treads",
	"item_maelstrom",
	"item_blink",
	"item_mjollnir",
	"item_black_king_bar",
	"item_lesser_crit",
	"item_ultimate_scepter",
	"item_greater_crit",
	"item_overwhelming_blink",
	"item_ultimate_scepter_2",
	"item_moon_shard",
	"item_manta",
	"item_aghanims_shard",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 4, 2,069 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_4"] = {
	"item_tango",
	"item_gauntlets",
	"item_branches",
	"item_quelling_blade",
	"item_magic_stick",
	"item_bracer",
	"item_magic_wand",
	"item_soul_ring",
	"item_power_treads",
	"item_aghanims_shard",
	"item_black_king_bar",
	"item_buckler",
	"item_ultimate_scepter",
	"item_assault",
	"item_ultimate_scepter_2",
	"item_lesser_crit",
	"item_greater_crit",
	"item_maelstrom",
	"item_blade_mail",
	"item_mjollnir",
	"item_moon_shard",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 5 has 925 matches, built from pos 4 (2,069) (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_5"] = sRoleItemsBuyList["pos_4"]
-- Stratz 7.41f, week of 9 Nov 2026: pos 3, 183,849 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_3"] = {
	"item_tango",
	"item_double_gauntlets",
	"item_double_branches",
	"item_quelling_blade",
	"item_bracer",
	"item_magic_wand",
	"item_soul_ring",
	"item_power_treads",
	"item_blink",
	"item_black_king_bar",
	"item_octarine_core",
	"item_ultimate_scepter",
	"item_overwhelming_blink",
	"item_ultimate_scepter_2",
	"item_orchid",
	"item_bloodthorn",
	"item_lesser_crit",
	"item_greater_crit",
	"item_aghanims_shard",
	"item_moon_shard",
}
X["sBuyList"] = sRoleItemsBuyList[sRole]
X["sSellList"] = {
	"item_power_treads",
	"item_quelling_blade",
	"item_blink",
	"item_quelling_blade",
	"item_black_king_bar",
	"item_magic_wand",
	"item_heavens_halberd",
	"item_bracer",
}
if Fu.Role.IsPvNMode() or Fu.Role.IsAllShadow() then
	X["sBuyList"], X["sSellList"] = { "PvN_tank" }, { "item_power_treads", "item_quelling_blade" }
end
nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"] =
	Fu.SetUserHeroInit(nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"])
X["sSkillList"] = Fu.Skill.GetSkillList(sAbilityList, nAbilityBuildList, sTalentList, nTalentBuildList)
X["bDeafaultAbility"] = false
X["bDeafaultItem"] = false
function X.MinionThink(minionUnit)
	Minion.MinionThink(minionUnit)
end
local breatheFireAbility =
	SafeAbility(bot:GetAbilityByName("dragon_knight_breathe_fire"), "dragon_knight_breathe_fire", "dragon_knight")
local dragonTailAbility =
	SafeAbility(bot:GetAbilityByName("dragon_knight_dragon_tail"), "dragon_knight_dragon_tail", "dragon_knight")
local fireballAbility =
	SafeAbility(bot:GetAbilityByName("dragon_knight_fireball"), "dragon_knight_fireball", "dragon_knight")
local elderDragonFormAbility = SafeAbility(
	bot:GetAbilityByName("dragon_knight_elder_dragon_form"),
	"dragon_knight_elder_dragon_form",
	"dragon_knight"
)
local breatheFireDesire, breatheFireLocation
local dragonTailDesire, dragonTailTarget
local fireballDesire, fireballLocation
local elderDragonFormDesire
local isInDragonForm = false
local isAttacking = false
local botTarget, hpRatio
local nearbyAllies, nearbyEnemies
local isEngaging
local isRetreating
local isInTeamFight
function X.SkillsComplement()
	bot = GetBot()
	if Fu.CanNotUseAbility(bot) then
		return
	end
	local abilityContext = AbilityContext.Build(bot)
	isEngaging = abilityContext.isEngaging
	isRetreating = abilityContext.isRetreating
	isInTeamFight = abilityContext.isTeamFight
	breatheFireAbility =
		SafeAbility(bot:GetAbilityByName("dragon_knight_breathe_fire"), "dragon_knight_breathe_fire", "dragon_knight")
	dragonTailAbility =
		SafeAbility(bot:GetAbilityByName("dragon_knight_dragon_tail"), "dragon_knight_dragon_tail", "dragon_knight")
	fireballAbility =
		SafeAbility(bot:GetAbilityByName("dragon_knight_fireball"), "dragon_knight_fireball", "dragon_knight")
	elderDragonFormAbility = SafeAbility(
		bot:GetAbilityByName("dragon_knight_elder_dragon_form"),
		"dragon_knight_elder_dragon_form",
		"dragon_knight"
	)
	isInDragonForm = bot:HasModifier("modifier_dragon_knight_dragon_form")
	isAttacking = Fu.IsAttacking(bot)
	hpRatio = abilityContext.hp
	botTarget = abilityContext.target
	nearbyAllies = abilityContext.allies
	nearbyEnemies = abilityContext.enemies
	elderDragonFormDesire = X.ConsiderElderDragonForm()
	if elderDragonFormDesire > 0 then
		Fu.SetQueuePtToINT(bot, false)
		bot:ActionQueue_UseAbility(elderDragonFormAbility)
		return
	end
	breatheFireDesire, breatheFireLocation = X.ConsiderBreatheFire()
	if breatheFireDesire > 0 then
		Fu.SetQueuePtToINT(bot, false)
		bot:ActionQueue_UseAbilityOnLocation(breatheFireAbility, breatheFireLocation)
		return
	end
	dragonTailDesire, dragonTailTarget = X.ConsiderDragonTail()
	if dragonTailDesire > 0 then
		Fu.SetQueuePtToINT(bot, false)
		bot:ActionQueue_UseAbilityOnEntity(dragonTailAbility, dragonTailTarget)
		return
	end
	fireballDesire, fireballLocation = X.ConsiderFireball()
	if fireballDesire > 0 then
		Fu.SetQueuePtToINT(bot, false)
		bot:ActionQueue_UseAbilityOnLocation(fireballAbility, fireballLocation)
		return
	end
end
function X.ConsiderBreatheFire()
	if not Fu.CanCastAbility(breatheFireAbility) then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local castRange = Fu.GetProperCastRange(false, bot, breatheFireAbility:GetCastRange())
	local castPoint = breatheFireAbility:GetCastPoint()
	local radius = breatheFireAbility:GetSpecialValueInt("end_radius")
	local damage = breatheFireAbility:GetSpecialValueInt("damage")
	local projectileSpeed = breatheFireAbility:GetSpecialValueInt("speed")
	local manaCost = breatheFireAbility:GetManaCost()
	local manaAfter = Fu.GetManaAfter(manaCost)
	local manaThresholdAll = Fu.GetManaThreshold(
		bot,
		manaCost,
		{ breatheFireAbility, dragonTailAbility, fireballAbility, elderDragonFormAbility }
	)
	local manaThresholdTailUlt = Fu.GetManaThreshold(bot, manaCost, { dragonTailAbility, elderDragonFormAbility })
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanBeAttacked(enemyHero)
			and Fu.IsInRange(bot, enemyHero, castRange + 150)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
			and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
			and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
			and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
		then
			local travelTime = GetUnitToUnitDistance(bot, enemyHero) / projectileSpeed + castPoint
			if Fu.WillKillTarget(enemyHero, damage, DAMAGE_TYPE_MAGICAL, travelTime) then
				return BOT_ACTION_DESIRE_HIGH, enemyHero:GetLocation()
			end
		end
	end
	if isInTeamFight then
		local bestTarget = nil
		local highestDamage = 0
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.CanBeAttacked(enemyHero)
				and Fu.IsInRange(bot, enemyHero, castRange - 150)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
				and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
				and not enemyHero:HasModifier("modifier_dragonknight_breathefire_reduction")
				and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
				and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
			then
				local estimatedDamage = enemyHero:GetEstimatedDamageToTarget(false, bot, 3.0, DAMAGE_TYPE_PHYSICAL)
				if estimatedDamage > highestDamage then
					bestTarget = enemyHero
					highestDamage = estimatedDamage
				end
			end
		end
		if bestTarget ~= nil then
			return BOT_ACTION_DESIRE_HIGH, Fu.GetCorrectLoc(bestTarget, castPoint)
		end
		local aoeLocation = bot:FindAoELocation(true, true, bot:GetLocation(), castRange, radius - 30, 0, 0)
		if aoeLocation.count >= 2 and manaAfter > manaThresholdTailUlt then
			return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
		end
	end
	if isEngaging then
		if
			Fu.IsValidHero(botTarget)
			and Fu.CanBeAttacked(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange - 150)
			and not botTarget:HasModifier("modifier_dazzle_shallow_grave")
			and not botTarget:HasModifier("modifier_dragonknight_breathefire_reduction")
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			if Fu.CanCastAbility(elderDragonFormAbility) then
				if manaAfter > manaThresholdTailUlt then
					return BOT_ACTION_DESIRE_HIGH, Fu.GetCorrectLoc(botTarget, castPoint)
				end
			else
				return BOT_ACTION_DESIRE_HIGH, Fu.GetCorrectLoc(botTarget, castPoint)
			end
		end
	end
	if isRetreating and not Fu.IsRealInvisible(bot) and bot:WasRecentlyDamagedByAnyHero(4.0) then
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.CanBeAttacked(enemyHero)
				and Fu.IsInRange(bot, enemyHero, castRange)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and not enemyHero:IsDisarmed()
				and not enemyHero:HasModifier("modifier_dragonknight_breathefire_reduction")
			then
				if
					Fu.IsChasingTarget(enemyHero, bot)
					or #nearbyEnemies > #nearbyAllies and enemyHero:GetAttackTarget() == bot
				then
					return BOT_ACTION_DESIRE_HIGH, enemyHero:GetLocation()
				end
			end
		end
		local aoeLocation = bot:FindAoELocation(true, true, bot:GetLocation(), castRange - 100, radius, 0, 0)
		local enemiesInAoe = Fu.GetEnemiesNearLoc(aoeLocation.targetloc, radius)
		if #enemiesInAoe >= 2 then
			return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
		end
	end
	local nearbyCreeps = bot:GetNearbyCreeps(Min(castRange + 300, 1600), true)
	if
		Fu.IsPushing(bot)
		and isAttacking
		and #nearbyAllies <= 2
		and manaAfter > manaThresholdAll
		and not isInDragonForm
	then
		for _, creep in pairs(nearbyCreeps) do
			if Fu.IsValid(creep) and Fu.CanBeAttacked(creep) and not Fu.IsRunning(creep) then
				local aoeLocation = bot:FindAoELocation(true, false, creep:GetLocation(), 0, radius, 0, 0)
				if aoeLocation.count >= 4 then
					return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
				end
			end
		end
	end
	if
		Fu.IsDefending(bot)
		and isAttacking
		and #nearbyEnemies == 0
		and manaAfter > manaThresholdAll
		and not isInDragonForm
	then
		for _, creep in pairs(nearbyCreeps) do
			if Fu.IsValid(creep) and Fu.CanBeAttacked(creep) and not Fu.IsRunning(creep) then
				local aoeLocation = bot:FindAoELocation(true, false, creep:GetLocation(), 0, radius, 0, 0)
				if aoeLocation.count >= 4 then
					return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
				end
			end
		end
	end
	if Fu.IsFarming(bot) and isAttacking and manaAfter > manaThresholdTailUlt then
		for _, creep in pairs(nearbyCreeps) do
			if Fu.IsValid(creep) and Fu.CanBeAttacked(creep) and not Fu.IsRunning(creep) then
				local aoeLocation = bot:FindAoELocation(true, false, creep:GetLocation(), 0, radius, 0, 0)
				if
					aoeLocation.count >= 3 and not isInDragonForm
					or aoeLocation.count >= 2 and creep:IsAncientCreep()
					or aoeLocation.count >= 2 and manaAfter > manaThresholdAll
				then
					return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
				end
			end
		end
	end
	if Fu.IsLaning(bot) and not Fu.IsInLaningPhase() and manaAfter > manaThresholdTailUlt then
		for _, creep in ipairs(nearbyCreeps) do
			if
				Fu.IsValid(creep)
				and Fu.CanBeAttacked(creep)
				and (
					string.find(creep:GetUnitName(), "range")
					or string.find(creep:GetUnitName(), "flagbearer")
					or string.find(creep:GetUnitName(), "siege")
				)
			then
				local travelTime = GetUnitToUnitDistance(bot, creep) / projectileSpeed + castPoint
				if Fu.WillKillTarget(creep, damage, DAMAGE_TYPE_MAGICAL, travelTime) then
					if
						Fu.IsValidHero(nearbyEnemies[1])
							and Fu.IsInRange(nearbyEnemies[1], creep, radius)
							and not Fu.IsSuspiciousIllusion(nearbyEnemies[1])
						or Fu.IsUnitTargetedByTower(creep, false)
					then
						return BOT_ACTION_DESIRE_HIGH, creep:GetLocation()
					end
				end
			end
		end
		local aoeLocation = bot:FindAoELocation(true, false, bot:GetLocation(), castRange, radius, 0, damage)
		if aoeLocation.count >= 2 then
			return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if
			Fu.IsRoshan(botTarget)
			and Fu.CanBeAttacked(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and not botTarget:HasModifier("modifier_dragonknight_breathefire_reduction")
			and isAttacking
			and manaAfter > manaThresholdAll
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if
			Fu.IsTormentor(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and not botTarget:HasModifier("modifier_dragonknight_breathefire_reduction")
			and isAttacking
			and manaAfter > manaThresholdAll
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	if manaAfter > manaThresholdTailUlt and not Fu.IsLateGame() and isAttacking and not isInDragonForm then
		for _, creep in ipairs(nearbyCreeps) do
			if Fu.IsValid(creep) and Fu.CanBeAttacked(creep) and not Fu.IsRunning(creep) then
				local aoeLocation = bot:FindAoELocation(true, false, creep:GetLocation(), 0, radius, 0, damage)
				if aoeLocation.count >= 3 then
					return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.ConsiderDragonTail()
	if not Fu.CanCastAbility(dragonTailAbility) then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castRange = Fu.GetProperCastRange(false, bot, dragonTailAbility:GetCastRange())
	local damage = dragonTailAbility:GetSpecialValueInt("damage")
	local projectileSpeed = dragonTailAbility:GetSpecialValueInt("projectile_speed")
	local manaCost = dragonTailAbility:GetManaCost()
	local manaAfter = Fu.GetManaAfter(manaCost)
	local manaThreshold = Fu.GetManaThreshold(bot, manaCost, { elderDragonFormAbility })
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanBeAttacked(enemyHero)
			and Fu.IsInRange(bot, enemyHero, castRange + 300)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and Fu.CanCastOnTargetAdvanced(enemyHero)
			and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			if enemyHero:HasModifier("modifier_teleporting") then
				local teleportTimeLeft = Fu.GetModifierTime(enemyHero, "modifier_teleporting")
				if not isInDragonForm then
					local travelTime = GetUnitToUnitDistance(bot, enemyHero) / bot:GetCurrentMovementSpeed()
					if travelTime < teleportTimeLeft then
						return BOT_ACTION_DESIRE_HIGH, enemyHero
					end
				else
					local travelTime = GetUnitToUnitDistance(bot, enemyHero) / projectileSpeed
					if travelTime < teleportTimeLeft then
						return BOT_ACTION_DESIRE_HIGH, enemyHero
					end
				end
			elseif enemyHero:IsChanneling() then
				if manaAfter > manaThreshold then
					return BOT_ACTION_DESIRE_HIGH, enemyHero
				end
			end
			local travelTime = GetUnitToUnitDistance(bot, enemyHero) / bot:GetCurrentMovementSpeed()
			if isInDragonForm then
				travelTime = GetUnitToUnitDistance(bot, enemyHero) / projectileSpeed
			end
			if not Fu.CanCastAbility(breatheFireAbility) then
				if
					Fu.WillKillTarget(enemyHero, damage, DAMAGE_TYPE_MAGICAL, travelTime)
					and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
					and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
					and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
					and not enemyHero:HasModifier("modifier_templar_assassin_refraction_absorb")
				then
					return BOT_ACTION_DESIRE_HIGH, enemyHero
				end
			end
		end
	end
	if isInTeamFight then
		if isInDragonForm and true then
			for _, enemyHero in pairs(nearbyEnemies) do
				if
					Fu.IsValidHero(enemyHero)
					and Fu.CanBeAttacked(enemyHero)
					and Fu.IsInRange(bot, enemyHero, castRange + 300)
					and Fu.CanCastOnNonMagicImmune(enemyHero)
					and Fu.CanCastOnTargetAdvanced(enemyHero)
					and not enemyHero:IsDisarmed()
					and not enemyHero:HasModifier("modifier_faceless_void_chronosphere_freeze")
					and not enemyHero:HasModifier("modifier_enigma_black_hole_pull")
					and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
				then
					local enemiesNearTarget = Fu.GetEnemiesNearLoc(enemyHero:GetLocation(), 100)
					if #enemiesNearTarget >= 2 then
						return BOT_ACTION_DESIRE_HIGH, enemyHero
					end
				end
			end
		end
		local bestTarget = nil
		local highestDamage = 0
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.CanBeAttacked(enemyHero)
				and Fu.IsInRange(bot, enemyHero, castRange + 300)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
				and not Fu.IsDisabled(enemyHero)
				and not enemyHero:IsDisarmed()
				and not enemyHero:HasModifier("modifier_dragonknight_breathefire_reduction")
				and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
				and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
			then
				local estimatedDamage = enemyHero:GetEstimatedDamageToTarget(false, bot, 3.0, DAMAGE_TYPE_ALL)
				if estimatedDamage > highestDamage then
					bestTarget = enemyHero
					highestDamage = estimatedDamage
				end
			end
		end
		if bestTarget ~= nil then
			return BOT_ACTION_DESIRE_HIGH, bestTarget
		end
	end
	if isEngaging then
		if
			Fu.IsValidHero(botTarget)
			and Fu.CanBeAttacked(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange + 300)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.CanCastOnTargetAdvanced(botTarget)
			and not Fu.IsDisabled(botTarget)
			and not botTarget:IsDisarmed()
			and not botTarget:HasModifier("modifier_faceless_void_chronosphere_freeze")
			and not botTarget:HasModifier("modifier_enigma_black_hole_pull")
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end
	if isRetreating and not Fu.IsRealInvisible(bot) and bot:WasRecentlyDamagedByAnyHero(3.0) then
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.IsInRange(bot, enemyHero, castRange + 300)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
				and not Fu.IsDisabled(enemyHero)
				and not enemyHero:IsDisarmed()
				and not enemyHero:HasModifier("modifier_dragonknight_breathefire_reduction")
			then
				if
					Fu.IsChasingTarget(enemyHero, bot)
					or #nearbyEnemies > #nearbyAllies and enemyHero:GetAttackTarget() == bot
					or hpRatio < 0.5
				then
					return BOT_ACTION_DESIRE_HIGH, enemyHero
				end
			end
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if
			Fu.IsRoshan(botTarget)
			and Fu.CanBeAttacked(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and Fu.CanCastOnTargetAdvanced(botTarget)
			and not botTarget:HasModifier("modifier_dragonknight_breathefire_reduction")
			and isAttacking
			and manaAfter > 0.4
			and manaAfter > manaThreshold
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if
			Fu.IsTormentor(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and not botTarget:HasModifier("modifier_dragonknight_breathefire_reduction")
			and isAttacking
			and manaAfter > 0.4
			and manaAfter > manaThreshold
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function X.ConsiderFireball()
	if not Fu.CanCastAbility(fireballAbility) then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local castRange = Fu.GetProperCastRange(false, bot, fireballAbility:GetCastRange())
	local radius = fireballAbility:GetSpecialValueInt("radius")
	local manaCost = fireballAbility:GetManaCost()
	local manaAfter = Fu.GetManaAfter(manaCost)
	local manaThreshold = Fu.GetManaThreshold(bot, manaCost, { elderDragonFormAbility })
	if isInTeamFight then
		local aoeLocation = Fu.GetAoeEnemyHeroLocation(bot, castRange, radius, 2)
		if aoeLocation ~= nil and manaAfter > manaThreshold then
			return BOT_ACTION_DESIRE_HIGH, aoeLocation
		end
	end
	if isEngaging then
		if
			Fu.IsValidHero(botTarget)
			and Fu.CanBeAttacked(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.GetHP(botTarget) > 0.15
			and not Fu.IsChasingTarget(bot, botTarget)
			and manaAfter > manaThreshold
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	if isRetreating and not Fu.IsRealInvisible(bot) and bot:WasRecentlyDamagedByAnyHero(3.0) then
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.CanBeAttacked(enemyHero)
				and Fu.IsInRange(bot, enemyHero, castRange - 100)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.GetHP(enemyHero) < 0.5
				and not Fu.IsDisabled(enemyHero)
				and not enemyHero:IsDisarmed()
				and not enemyHero:HasModifier("modifier_dragonknight_breathefire_reduction")
			then
				if Fu.IsChasingTarget(enemyHero, bot) and #nearbyEnemies >= 2 then
					return BOT_ACTION_DESIRE_HIGH, bot:GetLocation()
				end
				if #nearbyEnemies > #nearbyAllies and enemyHero:GetAttackTarget() == bot then
					return BOT_ACTION_DESIRE_HIGH, (bot:GetLocation() + enemyHero:GetLocation()) / 2
				end
			end
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if
			Fu.IsRoshan(botTarget)
			and Fu.CanBeAttacked(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and Fu.GetHP(botTarget) > 0.4
			and not Fu.IsDisabled(botTarget)
			and not botTarget:HasModifier("modifier_dragonknight_breathefire_reduction")
			and isAttacking
			and manaAfter > 0.5
			and manaAfter > manaThreshold
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if
			Fu.IsTormentor(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and not botTarget:HasModifier("modifier_dragonknight_breathefire_reduction")
			and isAttacking
			and manaAfter > 0.5
			and manaAfter > manaThreshold
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.ConsiderElderDragonForm()
	if not Fu.CanCastAbility(elderDragonFormAbility) or hpRatio < 0.25 then
		return BOT_ACTION_DESIRE_NONE
	end
	if isEngaging then
		if
			Fu.IsValidHero(botTarget)
			and Fu.IsInRange(bot, botTarget, 800)
			and Fu.CanBeAttacked(botTarget)
			and not Fu.IsSuspiciousIllusion(botTarget)
		then
			local alliesNearBot = Fu.GetAlliesNearLoc(bot:GetLocation(), 1200)
			local enemiesNearBot = Fu.GetEnemiesNearLoc(bot:GetLocation(), 1200)
			if #alliesNearBot < #enemiesNearBot + 2 then
				if #enemiesNearBot >= 2 then
					return BOT_ACTION_DESIRE_HIGH
				else
					if not botTarget:HasModifier("modifier_necrolyte_reapers_scythe") then
						return BOT_ACTION_DESIRE_HIGH
					end
				end
			end
		end
	end
	local laneCreeps = bot:GetNearbyLaneCreeps(800, true)
	if Fu.IsPushing(bot) then
		if
			Fu.IsValidBuilding(botTarget)
			and Fu.CanBeAttacked(botTarget)
			and Fu.GetHP(botTarget) > 0.2
			and not botTarget:HasModifier("modifier_backdoor_protection")
			and not botTarget:HasModifier("modifier_backdoor_protection_active")
			and not botTarget:HasModifier("modifier_backdoor_protection_in_base")
			and #laneCreeps >= 2
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsDefending(bot) then
		local enemiesNearBot = Fu.GetEnemiesNearLoc(bot:GetLocation(), 1200)
		if #laneCreeps >= 6 and #enemiesNearBot == 0 then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsDoingRoshan(bot) and bot:GetNetWorth() < 20000 then
		if
			Fu.IsRoshan(botTarget)
			and Fu.CanBeAttacked(botTarget)
			and Fu.IsInRange(bot, botTarget, 600)
			and Fu.GetHP(botTarget) > 0.4
			and isAttacking
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsDoingTormentor(bot) and bot:GetNetWorth() < 15000 then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, 600) and isAttacking then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
return X
