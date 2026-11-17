-- Slark: skill build, item build, and ability use for this hero.
local X = {}
local bot = GetBot()
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local AbilityContext = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local Minion = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local sTalentList = Fu.Skill.GetTalentList(bot)
local sAbilityList = Fu.Skill.GetAbilityList(bot)
local sRole = Fu.Item.GetRoleItemsBuyList(bot)
local tTalentTreeList = { ["t25"] = { 0, 10 }, ["t20"] = { 10, 0 }, ["t15"] = { 0, 10 }, ["t10"] = { 0, 10 } }
-- datafeed: Essence Shift is innate now; the learnable basics are Dark Pact (1), Pounce (2) and
-- Saltwater Shiv (3). The old index 4 points went to Shiv, which had only one point.
local tAllAbilityBuildList = { { 1, 2, 3, 1, 1, 6, 1, 3, 2, 2, 6, 2, 3, 3, 6 } }
local nAbilityBuildList = Fu.Skill.GetRandomBuild(tAllAbilityBuildList)
local nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList)
local sRoleItemsBuyList = {}
sRoleItemsBuyList["pos_1"] = {
	"item_melee_carry_outfit",
	"item_diffusal_blade",
	"item_blitz_knuckles",
	"item_invis_sword",
	"item_aghanims_shard",
	"item_black_king_bar",
	"item_ultimate_scepter",
	"item_skadi",
	"item_travel_boots",
	"item_silver_edge",
	"item_disperser",
	"item_basher",
	"item_abyssal_blade",
	"item_moon_shard",
	"item_ultimate_scepter_2",
	"item_butterfly",
	"item_travel_boots_2",
}
sRoleItemsBuyList["pos_2"] = {
	"item_tango",
	"item_double_branches",
	"item_quelling_blade",
	"item_slippers",
	"item_circlet",
	"item_magic_wand",
	"item_wraith_band",
	"item_power_treads",
	"item_diffusal_blade",
	"item_echo_sabre",
	"item_ultimate_scepter",
	"item_aghanims_shard",
	"item_black_king_bar",
	"item_skadi",
	"item_basher",
	"item_disperser",
	"item_abyssal_blade",
	"item_moon_shard",
	"item_ultimate_scepter_2",
	"item_orchid",
	"item_bloodthorn",
	"item_nullifier",
}
sRoleItemsBuyList["pos_3"] = sRoleItemsBuyList["pos_1"]
sRoleItemsBuyList["pos_4"] = sRoleItemsBuyList["pos_2"]
sRoleItemsBuyList["pos_5"] = sRoleItemsBuyList["pos_2"]
X["sBuyList"] = sRoleItemsBuyList[sRole]
X["sSellList"] = { "item_black_king_bar", "item_quelling_blade" }
if Fu.Role.IsPvNMode() or Fu.Role.IsAllShadow() then
	X["sBuyList"], X["sSellList"] = { "PvN_melee_carry" }, { "item_power_treads", "item_quelling_blade" }
end
nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"] =
	Fu.SetUserHeroInit(nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"])
X["sSkillList"] = Fu.Skill.GetSkillList(sAbilityList, nAbilityBuildList, sTalentList, nTalentBuildList)
X["bDeafaultAbility"] = false
X["bDeafaultItem"] = false
function X.MinionThink(minionUnit)
	Minion.MinionThink(minionUnit)
end
local darkPactAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[1]), "sAbilityList[1]", "slark")
local pounceAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[2]), "sAbilityList[2]", "slark")
local abilitySlot3 = SafeAbility(bot:GetAbilityByName(sAbilityList[3]), "sAbilityList[3]", "slark")
local shadowDanceAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[6]), "sAbilityList[6]", "slark")
-- datafeed: Depth Shroud (Shard, point/AoE) by name; g[4] is not a basic ability any more.
local depthShroudAbility = SafeAbility(bot:GetAbilityByName("slark_depth_shroud"), "slark_depth_shroud", "slark")
local talent2 = SafeAbility(bot:GetAbilityByName(sTalentList[2]), "sTalentList[2]", "slark")
local talent6 = SafeAbility(bot:GetAbilityByName(sTalentList[6]), "sTalentList[6]", "slark")
local saltwaterShivAbility = SafeAbility(bot:GetAbilityByName("slark_saltwater_shiv"), "slark_saltwater_shiv", "slark")
local darkPactDesire, darkPactTarget
local pounceDesire, pounceTarget
local spareDesire, spareTarget
local shadowDanceDesire, shadowDanceTarget
local depthShroudDesire, depthShroudLocation
local saltwaterShivDesire, saltwaterShivTarget
local aetherRange = 0
local mpRatio, hpRatio, nearbyAllies
function X.SkillsComplement()
	if Fu.CanNotUseAbility(bot) then
		return
	end
	local context = AbilityContext.Build(bot)
	aetherRange = context.aetherRange
	mpRatio = context.mp
	hpRatio = context.hp
	botTarget = context.target
	nearbyAllies = context.allies
	darkPactDesire = X.ConsiderQ()
	if darkPactDesire > 0 then
		Fu.SetQueuePtToINT(bot, true)
		bot:ActionQueue_UseAbility(darkPactAbility)
		return
	end
	pounceDesire = X.ConsiderW()
	if pounceDesire > 0 then
		Fu.SetQueuePtToINT(bot, true)
		bot:ActionQueue_UseAbility(pounceAbility)
		return
	end
	saltwaterShivDesire, saltwaterShivTarget = X.ConsiderSaltwaterShiv()
	if saltwaterShivDesire > 0 then
		bot:Action_UseAbilityOnEntity(saltwaterShivAbility, saltwaterShivTarget)
		return
	end
	depthShroudDesire, depthShroudLocation = X.ConsiderAS()
	if depthShroudDesire > 0 then
		Fu.SetQueuePtToINT(bot, true)
		bot:ActionQueue_UseAbilityOnLocation(depthShroudAbility, depthShroudLocation)
		return
	end
	shadowDanceDesire = X.ConsiderR()
	if shadowDanceDesire > 0 then
		bot:Action_UseAbility(shadowDanceAbility)
		return
	end
end
function X.ConsiderSaltwaterShiv()
	if not Fu.CanCastAbility(saltwaterShivAbility) then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castRange = saltwaterShivAbility:GetCastRange()
	if Fu.IsGoingOnSomeone(bot) or Fu.IsInTeamFight(bot, 1200) then
		if
			Fu.IsValidHero(botTarget)
			and Fu.CanBeAttacked(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not Fu.HasForbiddenModifier(botTarget)
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end
	if Fu.IsRetreating(bot) and hpRatio < 0.6 then
		local enemyHeroes = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
		for _, enemyHero in pairs(enemyHeroes) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.CanBeAttacked(enemyHero)
				and enemyHero:IsFacingLocation(bot:GetLocation(), 30)
			then
				return BOT_ACTION_DESIRE_HIGH, enemyHero
			end
		end
	end
	-- Removed the Roshan / Tormentor branch: Saltwater Shiv targets heroes only (game data
	-- AbilityUnitTargetType DOTA_UNIT_TARGET_HERO). Game 036, t=1187-1266: 53 "cannot target creeps"
	-- refusals, all while the Radiant Roshan call/gather/attempt ran (gather counts as doing Roshan,
	-- which explains the 9 before Slark's mode showed roshan).
	return BOT_ACTION_DESIRE_NONE, nil
end
function X.ConsiderQ()
	if not darkPactAbility:IsFullyCastable() then
		return 0
	end
	local abilityLevel = darkPactAbility:GetLevel()
	local castRange = darkPactAbility:GetCastRange()
	local radius = darkPactAbility:GetSpecialValueInt("radius")
	local castPoint = darkPactAbility:GetCastPoint()
	local manaCost = darkPactAbility:GetManaCost()
	local damage = 0
	-- Review fix: "delay" is 1.5 in the game data; the Int read cut it to 1, so the pulse position
	-- was predicted half a second early.
	local delay = darkPactAbility:GetSpecialValueFloat("delay")
	local damageType = DAMAGE_TYPE_MAGICAL
	local enemiesInRadius = Fu.GetAroundEnemyHeroList(radius)
	local enemiesNearby = Fu.GetAroundEnemyHeroList(800)
	local target = nil
	local reason = nil
	local botFutureLocation = bot:GetExtrapolatedLocation(delay)
	if Fu.IsInTeamFight(bot, 1200) then
		local enemyCount = 0
		for _, enemyHero in pairs(enemiesNearby) do
			if Fu.IsValidHero(enemyHero) and Fu.CanCastOnMagicImmune(enemyHero) then
				local enemyFutureLocation = enemyHero:GetExtrapolatedLocation(delay)
				if Fu.GetLocationToLocationDistance(botFutureLocation, enemyFutureLocation) < radius - 30 then
					enemyCount = enemyCount + 1
				end
			end
		end
		if enemyCount >= 2 then
			target = botTarget
			reason = "Q-团战AOE" .. enemyCount
			return BOT_ACTION_DESIRE_HIGH, reason
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidHero(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, 400)
		then
			local enemyFutureLocation = botTarget:GetExtrapolatedLocation(delay)
			if Fu.GetLocationToLocationDistance(botFutureLocation, enemyFutureLocation) < radius - 50 then
				target = botTarget
				reason = "Q-攻击:" .. Fu.Chat.GetNormName(target)
				return BOT_ACTION_DESIRE_HIGH, reason
			end
		end
	end
	if Fu.IsRetreating(bot) then
		for _, enemyHero in pairs(enemiesNearby) do
			if
				Fu.IsValid(enemyHero)
				and Fu.CanCastOnMagicImmune(enemyHero)
				and (
					bot:WasRecentlyDamagedByHero(enemyHero, 3.0)
					or bot:GetCurrentMovementSpeed() < 200
					or bot:IsRooted()
				)
			then
				target = enemyHero
				reason = "Q-撤退" .. Fu.Chat.GetNormName(target)
				return BOT_ACTION_DESIRE_HIGH, reason
			end
		end
	end
	if (Fu.IsPushing(bot) or Fu.IsDefending(bot) or Fu.IsFarming(bot)) and Fu.IsAllowedToSpam(bot, manaCost * 0.32) then
		local laneCreeps = bot:GetNearbyLaneCreeps(radius + 50, true)
		if
			(#laneCreeps >= 3 or #laneCreeps >= 2 and mpRatio > 0.7)
			and Fu.IsValid(laneCreeps[1])
			and not laneCreeps[1]:HasModifier("modifier_fountain_glyph")
		then
			reason = "Q-带线AOE" .. #laneCreeps
			return BOT_ACTION_DESIRE_HIGH, reason
		end
	end
	if Fu.IsFarming(bot) and DotaTime() > 6 * 60 and Fu.IsAllowedToSpam(bot, manaCost) then
		local neutralCreeps = bot:GetNearbyNeutralCreeps(radius + 300)
		if
			(
				#neutralCreeps >= 3
				or #neutralCreeps >= 2 and Fu.IsValid(neutralCreeps[1]) and neutralCreeps[1]:IsAncientCreep()
			) and Fu.IsValid(botTarget)
		then
			target = botTarget
			reason = "Q-打野AOE" .. #neutralCreeps
			return BOT_ACTION_DESIRE_HIGH, reason
		end
	end
	if bot:IsDisarmed() or bot:IsRooted() or bot:IsBlind() then
		return BOT_ACTION_DESIRE_HIGH, "Q-self-dispel"
	end
	if
		(Fu.IsDoingRoshan(bot) or Fu.IsDoingTormentor(bot))
		and Fu.IsAttacking(bot)
		and Fu.IsAllowedToSpam(bot, manaCost)
	then
		return BOT_ACTION_DESIRE_HIGH, "Q-roshan/tormentor"
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderW()
	if not pounceAbility:IsFullyCastable() or bot:IsRooted() then
		return 0
	end
	local abilityLevel = pounceAbility:GetLevel()
	local pounceDistance = pounceAbility:GetSpecialValueInt("pounce_distance")
	local castRange = pounceDistance
	local castPoint = pounceAbility:GetCastPoint()
	local manaCost = pounceAbility:GetManaCost()
	local damage = 0
	local damageType = DAMAGE_TYPE_MAGICAL
	local enemiesInRange = Fu.GetAroundEnemyHeroList(pounceDistance)
	local enemiesNearby = Fu.GetAroundEnemyHeroList(pounceDistance + 200)
	local target = nil
	local reason = nil
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidHero(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange - 80)
			and not Fu.IsDisabled(botTarget)
			and not botTarget:HasModifier("modifier_slark_pounce_leash")
			and bot:IsFacingLocation(botTarget:GetLocation(), 10)
			and Fu.CanCastOnNonMagicImmune(botTarget)
		then
			target = botTarget
			reason = "W-控制:" .. Fu.Chat.GetNormName(target)
			return BOT_ACTION_DESIRE_HIGH, reason
		end
	end
	if Fu.IsRetreating(bot) and Fu.IsRunning(bot) and (abilityLevel >= 2 or hpRatio < 0.7) then
		for _, enemyHero in pairs(enemiesNearby) do
			if Fu.IsValid(enemyHero) and (bot:WasRecentlyDamagedByHero(enemyHero, 5.0) or #enemiesNearby >= 3) then
				local firstEnemy = enemiesNearby[1]
				if
					bot:IsFacingLocation(GetAncient(GetTeam()):GetLocation(), 20)
					and not Fu.IsInRange(bot, firstEnemy, 100)
				then
					target = enemyHero
					reason = "W-逃离:" .. Fu.Chat.GetNormName(target)
					return BOT_ACTION_DESIRE_HIGH, reason
				end
			end
		end
	end
	if Fu.IsStuck(bot) then
		target = bot
		reason = "W-卡住了" .. Fu.Chat.GetNormName(target)
		return BOT_ACTION_DESIRE_HIGH, reason
	end
	if #enemiesInRange == 0 and abilityLevel >= 2 then
		local botMode = bot:GetActiveMode()
		if
			(
				botMode == BOT_MODE_PUSH_TOWER_TOP
				or botMode == BOT_MODE_PUSH_TOWER_MID
				or botMode == BOT_MODE_PUSH_TOWER_BOT
				or botMode == BOT_MODE_DEFEND_TOWER_TOP
				or botMode == BOT_MODE_DEFEND_TOWER_MID
				or botMode == BOT_MODE_DEFEND_TOWER_BOT
				or botMode == BOT_MODE_ROSHAN
				or botMode == BOT_MODE_RUNE
			)
			and bot:GetCurrentMovementSpeed() > 0
			and bot:GetMovementDirectionStability() > 0.9
		then
			return BOT_ACTION_DESIRE_LOW, "W-mobility"
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderAS()
	if
		not depthShroudAbility:IsTrained()
		or not depthShroudAbility:IsFullyCastable()
		or bot:HasModifier("modifier_slark_shadow_dance")
		or bot:HasModifier("modifier_slark_depth_shroud")
	then
		return 0
	end
	local castRange = depthShroudAbility:GetCastRange() + aetherRange
	local enemiesNear = Fu.GetAroundEnemyHeroList(600)
	local enemiesNearby = Fu.GetAroundEnemyHeroList(800)
	for _, allyHero in pairs(nearbyAllies) do
		if
			Fu.IsValidHero(allyHero)
			and not allyHero:IsIllusion()
			and Fu.GetHP(allyHero) < 0.5
			and Fu.IsInRange(bot, allyHero, castRange)
			and allyHero:WasRecentlyDamagedByAnyHero(2.0)
			and not allyHero:HasModifier("modifier_slark_depth_shroud")
		then
			if Fu.IsDisabled(allyHero) or Fu.GetHP(allyHero) < 0.3 or Fu.IsStunProjectileIncoming(allyHero, 1000) then
				return BOT_ACTION_DESIRE_HIGH, allyHero:GetLocation(), "AS-protect-" .. Fu.Chat.GetNormName(allyHero)
			end
		end
	end
	if Fu.IsGoingOnSomeone(bot) and hpRatio < 0.7 then
		if Fu.IsValidHero(botTarget) and Fu.IsInRange(botTarget, bot, 300) and bot:GetAttackTarget() == botTarget then
			return BOT_ACTION_DESIRE_HIGH, bot:GetLocation(), "AS-fight"
		end
	end
	if Fu.IsRetreating(bot) and hpRatio < 0.6 and bot:WasRecentlyDamagedByAnyHero(1.5) then
		for _, enemyHero in pairs(enemiesNearby) do
			if Fu.IsValid(enemyHero) and enemyHero:GetAttackTarget() == bot then
				return BOT_ACTION_DESIRE_HIGH, bot:GetLocation(), "AS-retreat"
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderR()
	if not shadowDanceAbility:IsFullyCastable() or hpRatio > 0.8 or Fu.IsRealInvisible(bot) then
		return 0
	end
	local abilityLevel = shadowDanceAbility:GetLevel()
	local castRange = shadowDanceAbility:GetCastRange()
	local radius = 600
	local castPoint = shadowDanceAbility:GetCastPoint()
	local manaCost = shadowDanceAbility:GetManaCost()
	local damage = 0
	local damageType = DAMAGE_TYPE_MAGICAL
	local enemiesNear = Fu.GetAroundEnemyHeroList(600)
	local enemiesNearby = Fu.GetAroundEnemyHeroList(1000)
	local target = nil
	local reason = nil
	if Fu.IsGoingOnSomeone(bot) then
		if
			hpRatio < 0.76
			and Fu.IsValidHero(botTarget)
			and Fu.CanCastOnMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, 300)
			and (#enemiesNearby >= 2 or hpRatio < 0.55)
		then
			target = botTarget
			reason = "R-攻击:" .. Fu.Chat.GetNormName(target)
			return BOT_ACTION_DESIRE_HIGH, reason
		end
	end
	if
		Fu.IsRetreating(bot)
		and hpRatio < 0.6
		and bot:WasRecentlyDamagedByAnyHero(5.0)
		and (X.IsEnemyCastAbility() or hpRatio < 0.5 or Fu.IsStunProjectileIncoming(bot, 800))
		and #enemiesNearby >= 1
	then
		target = bot
		reason = "R-跑路:" .. Fu.Chat.GetNormName(target)
		return BOT_ACTION_DESIRE_HIGH, reason
	end
	return BOT_ACTION_DESIRE_NONE
end
local ignoredEnemyAbilities = {
	["antimage_blink"] = true,
	["arc_warden_magnetic_field"] = true,
	["arc_warden_spark_wraith"] = true,
	["arc_warden_tempest_double"] = true,
	["chaos_knight_phantasm"] = true,
	["clinkz_burning_army"] = true,
	["death_prophet_exorcism"] = true,
	["dragon_knight_elder_dragon_form"] = true,
	["juggernaut_healing_ward"] = true,
	["necrolyte_death_pulse"] = true,
	["necrolyte_sadist"] = true,
	["omniknight_guardian_angel"] = true,
	["phantom_assassin_blur"] = true,
	["pugna_nether_ward"] = true,
	["skeleton_king_mortal_strike"] = true,
	["sven_warcry"] = true,
	["sven_gods_strength"] = true,
	["templar_assassin_refraction"] = true,
	["templar_assassin_psionic_trap"] = true,
	["windrunner_windrun"] = true,
	["witch_doctor_voodoo_restoration"] = true,
}
function X.IsEnemyCastAbility()
	local enemyHeroes = Fu.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(enemyHeroes) do
		if
			enemyHero ~= nil
			and enemyHero:IsAlive()
			and (enemyHero:IsCastingAbility() or enemyHero:IsUsingAbility())
			and enemyHero:IsFacingLocation(bot:GetLocation(), 30)
		then
			local activeAbility = enemyHero:GetCurrentActiveAbility()
			if activeAbility ~= nil then
				local behavior = activeAbility:GetBehavior()
				local abilityName = activeAbility:GetName()
				if
					behavior ~= ABILITY_BEHAVIOR_UNIT_TARGET
					and (enemyHero:IsBot() or enemyHero:GetLevel() >= 5)
					and ignoredEnemyAbilities[abilityName] ~= true
				then
					return true
				end
				if
					behavior == ABILITY_BEHAVIOR_UNIT_TARGET
					and not enemyHero:IsBot()
					and enemyHero:GetLevel() >= 6
					and not Fu.IsAllyUnitSpell(abilityName)
					and (not Fu.IsProjectileUnitSpell(abilityName) or Fu.IsInRange(bot, enemyHero, 400))
				then
					return true
				end
			end
		end
	end
	return false
end
return X
