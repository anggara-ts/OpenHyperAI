-- Necrolyte: skill build, item build, and ability use for this hero.
local X = {}
local bot = GetBot()
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local AbilityContext = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local Minion = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local sTalentList = Fu.Skill.GetTalentList(bot)
local sAbilityList = Fu.Skill.GetAbilityList(bot)
local sRole = Fu.Item.GetRoleItemsBuyList(bot)
local tTalentTreeList = {
	{ ["t25"] = { 0, 10 }, ["t20"] = { 10, 0 }, ["t15"] = { 0, 10 }, ["t10"] = { 0, 10 } },
	{ ["t25"] = { 0, 10 }, ["t20"] = { 10, 0 }, ["t15"] = { 0, 10 }, ["t10"] = { 0, 10 } },
}
local tAllAbilityBuildList =
	{ { 1, 3, 1, 3, 1, 6, 1, 2, 3, 3, 6, 2, 2, 2, 6 }, { 1, 3, 1, 2, 1, 6, 1, 3, 3, 3, 6, 2, 2, 2, 6 } }
local nAbilityBuildList
local nTalentBuildList
if sRole == "pos_2" then
	nAbilityBuildList = tAllAbilityBuildList[1]
	nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList[1])
else
	nAbilityBuildList = tAllAbilityBuildList[2]
	nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList[2])
end
local sUtility = RandomInt(1, 2) == 1 and "item_heavens_halberd" or "item_pipe"
local sRoleItemsBuyList = {}
sRoleItemsBuyList["pos_2"] = {
	"item_tango",
	"item_double_branches",
	"item_faerie_fire",
	"item_circlet",
	"item_circlet",
	"item_magic_wand",
	"item_bracer",
	"item_boots",
	"item_radiance",
	"item_consecrated_wraps",
	"item_kaya_and_sange",
	"item_aghanims_shard",
	"item_heart",
	"item_travel_boots",
	"item_ultimate_scepter",
	"item_shivas_guard",
	"item_crellas_crozier",
	"item_octarine_core",
	"item_moon_shard",
	"item_travel_boots_2",
	"item_ultimate_scepter_2",
	"item_wind_waker",
}
sRoleItemsBuyList["pos_3"] = {
	"item_tango",
	"item_double_branches",
	"item_circlet",
	"item_magic_stick",
	"item_null_talisman",
	"item_magic_wand",
	"item_boots",
	"item_shadow_amulet",
	-- Radiance: bought in nearly every Necrophos game (Dotabuff, last patch); Veil was not.
	"item_radiance",
	"item_consecrated_wraps",
	"item_travel_boots",
	sUtility,
	"item_glimmer_cape",
	"item_crellas_crozier",
	"item_shivas_guard",
	"item_kaya_and_sange",
	"item_aghanims_shard",
	"item_heart",
	"item_sheepstick",
	"item_moon_shard",
	"item_ultimate_scepter_2",
	"item_travel_boots_2",
}
sRoleItemsBuyList["pos_1"] = sRoleItemsBuyList["pos_2"]
sRoleItemsBuyList["pos_4"] = {
	"item_blood_grenade",
	"item_priest_outfit",
	"item_mekansm",
	"item_glimmer_cape",
	"item_guardian_greaves",
	"item_force_staff",
	"item_ultimate_scepter",
	"item_hurricane_pike",
	"item_shivas_guard",
	"item_kaya_and_sange",
	"item_sheepstick",
	"item_moon_shard",
	"item_ultimate_scepter_2",
}
sRoleItemsBuyList["pos_5"] = {
	"item_blood_grenade",
	"item_mage_outfit",
	"item_ancient_janggo",
	"item_glimmer_cape",
	"item_boots_of_bearing",
	"item_pipe",
	"item_ultimate_scepter",
	"item_spirit_vessel",
	"item_shivas_guard",
	"item_sheepstick",
	"item_moon_shard",
	"item_ultimate_scepter_2",
}
X["sBuyList"] = sRoleItemsBuyList[sRole]
X["sSellList"] = { "item_black_king_bar", "item_quelling_blade", "item_wind_waker", "item_radiance" }
if Fu.Role.IsPvNMode() or Fu.Role.IsAllShadow() then
	X["sBuyList"], X["sSellList"] = { "PvN_priest" }, {}
end
nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"] =
	Fu.SetUserHeroInit(nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"])
X["sSkillList"] = Fu.Skill.GetSkillList(sAbilityList, nAbilityBuildList, sTalentList, nTalentBuildList)
X["bDeafaultAbility"] = false
X["bDeafaultItem"] = true
function X.MinionThink(minionUnit)
	Minion.MinionThink(minionUnit)
end
local deathPulseAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[1]), "sAbilityList[1]", "necrolyte")
local ghostShroudAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[2]), "sAbilityList[2]", "necrolyte")
local deathSeekerAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[4]), "sAbilityList[4]", "necrolyte")
local reapersScytheAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[6]), "sAbilityList[6]", "necrolyte")
local deathPulseDesire
local ghostShroudDesire
local unusedDesire
local reapersScytheDesire, reapersScytheTarget
local deathSeekerDesire, deathSeekerTarget
local hpRatio
local botTarget
function X.SkillsComplement()
	if Fu.CanNotUseAbility(bot) then
		return
	end
	local abilityContext = AbilityContext.Build(bot)
	hpRatio = abilityContext.hp
	botTarget = abilityContext.target
	reapersScytheDesire, reapersScytheTarget = X.ConsiderR()
	if reapersScytheDesire > 0 then
		Fu.SetQueuePtToINT(bot, false)
		bot:ActionQueue_UseAbilityOnEntity(reapersScytheAbility, reapersScytheTarget)
		return
	end
	ghostShroudDesire = X.ConsiderW()
	if ghostShroudDesire > 0 then
		Fu.SetQueuePtToINT(bot, false)
		bot:ActionQueue_UseAbility(ghostShroudAbility)
		return
	end
	deathSeekerDesire, deathSeekerTarget = X.ConsiderAS()
	if deathSeekerDesire > 0 then
		Fu.SetQueuePtToINT(bot, true)
		bot:ActionQueue_UseAbilityOnEntity(deathSeekerAbility, deathSeekerTarget)
		return
	end
	deathPulseDesire = X.ConsiderQ()
	if deathPulseDesire > 0 then
		Fu.SetQueuePtToINT(bot, false)
		bot:ActionQueue_UseAbility(deathPulseAbility)
		return
	end
end
function X.ConsiderW()
	if not ghostShroudAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
	end
	local slowRadius = ghostShroudAbility:GetSpecialValueInt("slow_aoe")
	local pulseStacks = 0
	local modifierCount = bot:NumModifiers()
	for modifierIndex = 0, modifierCount do
		if bot:GetModifierName(modifierIndex) == "modifier_necrolyte_death_pulse_counter" then
			pulseStacks = bot:GetModifierStackCount(modifierIndex)
			break
		end
	end
	if
		(pulseStacks >= 8 or bot:GetHealthRegen() > 99)
		and bot:GetHealth() / bot:GetMaxHealth() < 0.5
		and bot:GetAttackTarget() == nil
	then
		return BOT_ACTION_DESIRE_LOW
	end
	if Fu.IsRetreating(bot) then
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, slowRadius, true, BOT_MODE_NONE)
		if bot:WasRecentlyDamagedByAnyHero(2.0) and #nearbyEnemies > 0 then
			return BOT_ACTION_DESIRE_MODERATE
		end
	end
	if Fu.IsWithoutTarget(bot) and Fu.GetAttackProjectileDamageByRange(bot, 1600) >= bot:GetHealth() then
		return BOT_ACTION_DESIRE_MODERATE
	end
	-- Was switched off with "and false". Datafeed: Ghost Shroud emits a 700 slow aura, so a lone running
	-- target out of reach is chased with it.
	if Fu.IsGoingOnSomeone(bot) then
		local currentTarget = bot:GetTarget()
		if
			Fu.IsValidHero(currentTarget)
			and Fu.IsRunning(currentTarget)
			and Fu.IsRunning(bot)
			and bot:GetAttackTarget() == nil
			and Fu.CanCastOnNonMagicImmune(currentTarget)
			and Fu.IsInRange(currentTarget, bot, slowRadius - 30)
			and (
				Fu.GetHP(bot) < 0.25
				or not Fu.IsInRange(currentTarget, bot, 430)
					and bot:IsFacingLocation(currentTarget:GetLocation(), 30)
					and not currentTarget:IsFacingLocation(bot:GetLocation(), 120)
			)
		then
			local enemiesNearTarget = Fu.GetNearbyHeroes(currentTarget, 1000, false, BOT_MODE_NONE)
			if enemiesNearTarget == nil then
				enemiesNearTarget = {}
			end
			if #enemiesNearTarget == 1 then
				return BOT_ACTION_DESIRE_MODERATE
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderQ()
	if
		not deathPulseAbility:IsFullyCastable()
		or bot:IsInvisible()
		or Fu.GetHP(bot) > 0.62
			and reapersScytheAbility:GetCooldownTimeRemaining() < 6
			and bot:GetMana() < reapersScytheAbility:GetManaCost()
	then
		return BOT_ACTION_DESIRE_NONE
	end
	local radius = deathPulseAbility:GetSpecialValueInt("area_of_effect")
	local castRange = 0
	local damage = deathPulseAbility:GetAbilityDamage()
	local damageType = DAMAGE_TYPE_MAGICAL
	if Fu.IsRetreating(bot) or Fu.GetHP(bot) < 0.5 then
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, 2 * radius, true, BOT_MODE_NONE)
		if
			bot:WasRecentlyDamagedByAnyHero(2.0) and #nearbyEnemies > 0
			or Fu.GetHP(bot) < 0.75 and bot:DistanceFromFountain() < 400
			or Fu.GetHP(bot) < Fu.GetMP(bot)
			or Fu.GetHP(bot) < 0.25
		then
			return BOT_ACTION_DESIRE_MODERATE
		end
	end
	if deathPulseAbility:GetLevel() >= 3 then
		local laneCreeps = bot:GetNearbyLaneCreeps(radius, true)
		local creepCount = 0
		local killableCount = 0
		for _, creep in pairs(laneCreeps) do
			if Fu.IsValid(creep) and not creep:HasModifier("modifier_fountain_glyph") then
				creepCount = creepCount + 1
				if Fu.CanKillTarget(creep, damage + 2, damageType) then
					killableCount = killableCount + 1
				end
			end
		end
		if
			killableCount >= 2
			or killableCount >= 1 and Fu.GetMP(bot) > 0.9
			or creepCount >= 3 and bot:GetActiveMode() ~= BOT_MODE_LANING
			or creepCount >= 3 and killableCount >= 1 and Fu.IsAllowedToSpam(bot, 190)
			or creepCount >= 3 and Fu.GetMP(bot) > 0.8 and bot:GetLevel() > 10 and #laneCreeps == 3
			or creepCount >= 2 and killableCount >= 1 and bot:GetLevel() > 24 and #laneCreeps == 2
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsInTeamFight(bot, 1200) then
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, radius, true, BOT_MODE_NONE)
		local nearbyAllies = Fu.GetNearbyHeroes(bot, radius, false, BOT_MODE_NONE)
		local hurtAllyCount = 0
		for _, allyHero in pairs(nearbyAllies) do
			if Fu.IsValidHero(allyHero) then
				local allyHpRatio = allyHero:GetHealth() / allyHero:GetMaxHealth()
				if allyHpRatio < 0.5 then
					hurtAllyCount = hurtAllyCount + 1
				end
			end
		end
		if #nearbyEnemies >= 2 or hurtAllyCount >= 1 then
			return BOT_ACTION_DESIRE_MODERATE
		end
	end
	local nearbyAllies = Fu.GetNearbyHeroes(bot, radius, false, BOT_MODE_NONE)
	if #nearbyAllies >= 2 then
		local hurtAllyCount = 0
		for _, allyHero in pairs(nearbyAllies) do
			if Fu.IsValidHero(allyHero) and allyHero:GetMaxHealth() - allyHero:GetHealth() > 220 then
				hurtAllyCount = hurtAllyCount + 1
				if allyHero:GetHealth() / allyHero:GetMaxHealth() < 0.15 then
					return BOT_ACTION_DESIRE_MODERATE
				end
				if hurtAllyCount >= 2 and allyHero:GetHealth() / allyHero:GetMaxHealth() < 0.38 then
					return BOT_ACTION_DESIRE_MODERATE
				end
				if hurtAllyCount >= 3 then
					return BOT_ACTION_DESIRE_MODERATE
				end
			end
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidHero(botTarget)
			and Fu.IsInRange(botTarget, bot, radius)
			and Fu.CanCastOnNonMagicImmune(botTarget)
		then
			return BOT_ACTION_DESIRE_MODERATE
		end
	end
	if Fu.IsFarming(bot) then
		if Fu.IsValid(botTarget) and botTarget:GetTeam() == TEAM_NEUTRAL and Fu.IsInRange(bot, botTarget, 500) then
			local aoeLocation = bot:FindAoELocation(true, false, bot:GetLocation(), castRange, radius, 0, 0)
			if aoeLocation.count >= 2 or botTarget:GetHealth() > damage then
				return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
			end
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if
			Fu.IsRoshan(botTarget)
			and Fu.IsInRange(botTarget, bot, radius)
			and Fu.CanBeAttacked(botTarget)
			and Fu.IsAttacking(bot)
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(botTarget, bot, radius) and Fu.IsAttacking(bot) then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderR()
	if not reapersScytheAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local castRange = reapersScytheAbility:GetCastRange()
	local damagePerHealth = reapersScytheAbility:GetSpecialValueFloat("damage_per_health")
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidHero(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.CanCastOnTargetAdvanced(botTarget)
			and not Fu.IsHaveAegis(botTarget)
			and not botTarget:HasModifier("modifier_arc_warden_tempest_double")
			and botTarget:GetUnitName() ~= "npc_dota_hero_abaddon"
			and Fu.IsInRange(botTarget, bot, castRange + 200)
		then
			local estimatedDamage = X.GetEstDamage(bot, botTarget, damagePerHealth)
			if
				Fu.CanKillTarget(botTarget, estimatedDamage, DAMAGE_TYPE_MAGICAL)
				or botTarget:IsChanneling() and botTarget:HasModifier("modifier_teleporting")
			then
				return BOT_ACTION_DESIRE_HIGH, botTarget
			end
		end
	end
	if Fu.IsInTeamFight(bot, 1200) then
		local killableTarget = nil
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE)
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
				and not Fu.IsHaveAegis(enemyHero)
				and not enemyHero:HasModifier("modifier_arc_warden_tempest_double")
				and enemyHero:GetUnitName() ~= "npc_dota_hero_abaddon"
			then
				local estimatedDamage = X.GetEstDamage(bot, enemyHero, damagePerHealth)
				if Fu.CanKillTarget(enemyHero, estimatedDamage, DAMAGE_TYPE_MAGICAL) then
					killableTarget = enemyHero
					break
				end
			end
		end
		if killableTarget ~= nil then
			return BOT_ACTION_DESIRE_HIGH, killableTarget
		end
	end
	local nearbyEnemies = Fu.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidHero(enemyHero)
			and not Fu.IsHaveAegis(enemyHero)
			and Fu.CanCastOnTargetAdvanced(enemyHero)
			and enemyHero:GetUnitName() ~= "npc_dota_hero_abaddon"
			and not enemyHero:HasModifier("modifier_arc_warden_tempest_double")
		then
			local estimatedDamage = X.GetEstDamage(bot, enemyHero, damagePerHealth)
			if
				Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.CanKillTarget(enemyHero, estimatedDamage, DAMAGE_TYPE_MAGICAL)
			then
				return BOT_ACTION_DESIRE_HIGH, enemyHero
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.GetEstDamage(caster, target, damagePerHealth)
	local maxHealth = target:GetMaxHealth()
	if target:GetHealth() / maxHealth > 0.75 then
		return maxHealth * 0.3
	end
	local targetAllyCount = Fu.GetAroundTargetAllyHeroCount(target, 650)
	local magicMultiplier = 1 - target:GetMagicResist()
	if magicMultiplier < 0.1 then
		magicMultiplier = 0.1
	end
	local regenAmount = target:GetHealthRegen() * 2
	local estimatedDamage = (maxHealth - target:GetHealth() - regenAmount) * damagePerHealth
		- regenAmount / magicMultiplier
	if caster:GetLevel() >= 9 then
		estimatedDamage = estimatedDamage + maxHealth * 0.026
	end
	if caster:GetLevel() >= 12 then
		estimatedDamage = estimatedDamage + maxHealth * 0.032
	end
	if caster:GetLevel() >= 18 then
		estimatedDamage = estimatedDamage + maxHealth * 0.016
	end
	if caster:HasScepter() and Fu.GetHP(caster) < 0.2 then
		estimatedDamage = estimatedDamage + maxHealth * 0.3
	end
	if targetAllyCount >= 2 then
		estimatedDamage = estimatedDamage + maxHealth * 0.08 * (targetAllyCount - 1)
	end
	if target:HasModifier("modifier_medusa_mana_shield") then
		local manaShieldDamage = estimatedDamage * 0.6
		if target:GetMana() * 2.5 >= manaShieldDamage then
			estimatedDamage = estimatedDamage * 0.4
		else
			estimatedDamage = estimatedDamage * 0.4 + manaShieldDamage - target:GetMana() * 2.5
		end
	end
	if
		target:GetUnitName() == "npc_dota_hero_bristleback" and not target:IsFacingLocation(GetBot():GetLocation(), 120)
	then
		estimatedDamage = estimatedDamage * 0.7
	end
	if target:HasModifier("modifier_kunkka_ghost_ship_damage_delay") then
		local ghostShipDelay = Fu.GetModifierTime(target, "modifier_kunkka_ghost_ship_damage_delay")
		if ghostShipDelay > 2.0 then
			estimatedDamage = estimatedDamage * 0.55
		end
	end
	if target:HasModifier("modifier_templar_assassin_refraction_absorb") then
		estimatedDamage = 0
	end
	return estimatedDamage
end
function X.ConsiderAS()
	if deathSeekerAbility == nil or not deathSeekerAbility:IsTrained() or not deathSeekerAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local radius = 500
	local castRange = deathSeekerAbility:GetCastRange()
	local castPoint = deathSeekerAbility:GetCastPoint()
	local manaCost = deathSeekerAbility:GetManaCost()
	local nearbyEnemies = Fu.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE)
	-- Escape: Death Seeker also targets allies and Necrophos travels to the target (datafeed; root
	-- disables it, game data). Retreating under 50% HP and just hit by a hero: fly to the allied hero or
	-- creep in cast range that is nearest our fountain, if that is 300+ nearer than he is. It was only
	-- ever cast on enemies, so it pulled him into fights and never out of one.
	if Fu.IsRetreating(bot) and bot:WasRecentlyDamagedByAnyHero(2.0) and hpRatio < 0.5 and not bot:IsRooted() then
		local friendlyUnits = Fu.CombineTwoTable(
			Fu.GetNearbyHeroes(bot, castRange, false, BOT_MODE_NONE) or {},
			bot:GetNearbyCreeps(castRange, false) or {}
		)
		local bestUnit, bestDistance = nil, Fu.GetDistanceFromAllyFountain(bot) - 300
		for _, friendlyUnit in pairs(friendlyUnits) do
			if Fu.IsValid(friendlyUnit) and friendlyUnit ~= bot and GetUnitToUnitDistance(bot, friendlyUnit) > 300 then
				local fountainDistance = Fu.GetDistanceFromAllyFountain(friendlyUnit)
				if fountainDistance < bestDistance then
					bestUnit, bestDistance = friendlyUnit, fountainDistance
				end
			end
		end
		if bestUnit ~= nil then
			if DotaTime() >= (bot._necroSeekLogAt or -999) then
				bot._necroSeekLogAt = DotaTime() + 3
				pcall(
					print,
					string.format(
						"[OHA-NECRO] t=%.0f death-seeker-escape to=%s dist=%d hp=%.2f",
						DotaTime(),
						bestUnit:GetUnitName(),
						math.floor(GetUnitToUnitDistance(bot, bestUnit)),
						hpRatio
					)
				)
			end
			return BOT_ACTION_DESIRE_HIGH, bestUnit
		end
	end
	if Fu.IsInTeamFight(bot, 1400) and #nearbyEnemies >= 3 then
		local bestTarget = nil
		local mostHeroes = 2
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValid(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
			then
				local enemiesAroundTarget = Fu.GetNearbyHeroes(enemyHero, 500, false, BOT_MODE_NONE)
				local alliesAroundTarget = Fu.GetNearbyHeroes(enemyHero, 500, true, BOT_MODE_NONE)
				if enemiesAroundTarget == nil then
					enemiesAroundTarget = {}
				end
				if alliesAroundTarget == nil then
					alliesAroundTarget = {}
				end
				local heroCount = #enemiesAroundTarget + #alliesAroundTarget
				if heroCount > mostHeroes then
					mostHeroes = heroCount
					bestTarget = enemyHero
				end
			end
		end
		if bestTarget ~= nil then
			return BOT_ACTION_DESIRE_HIGH, bestTarget, "AS-团战AOE"
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidHero(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.CanCastOnTargetAdvanced(botTarget)
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
return X
