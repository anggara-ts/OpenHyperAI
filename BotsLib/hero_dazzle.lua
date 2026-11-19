-- Dazzle: skill build, item build, and ability use for this hero.
-- Accidental globals made file-local (#13): every bot shares one Lua state, so these were shared.
local botTarget
local X = {}
local bot = GetBot()
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local AbilityContext = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local Minion = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local sTalentList = Fu.Skill.GetTalentList(bot)
local sAbilityList = Fu.Skill.GetAbilityList(bot)
local sRole = Fu.Item.GetRoleItemsBuyList(bot)
if not Fu.Utils.GameStates.dazzleNothl then
	Fu.Utils.GameStates.dazzleNothl = { [bot:GetPlayerID()] = { body = bot } }
end
if not Fu.Utils.GameStates.dazzleNothl[bot:GetPlayerID()] then
	Fu.Utils.GameStates.dazzleNothl[bot:GetPlayerID()] = { body = bot }
end
local tTalentTreeList = {
	{ ["t25"] = { 0, 10 }, ["t20"] = { 10, 0 }, ["t15"] = { 10, 0 }, ["t10"] = { 0, 10 } },
	{ ["t25"] = { 10, 0 }, ["t20"] = { 0, 10 }, ["t15"] = { 0, 10 }, ["t10"] = { 0, 10 } },
}
local tAllAbilityBuildList = { { 1, 3, 1, 2, 1, 6, 1, 3, 3, 3, 6, 2, 2, 2, 6 } }
local nAbilityBuildList = Fu.Skill.GetRandomBuild(tAllAbilityBuildList)
local nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList[2])
if sRole == "pos_1" then
	nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList[1])
end
if sRole == "pos_2" then
	nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList[1])
end
local sRoleItemsBuyList = {}
sRoleItemsBuyList["pos_1"] = {
	"item_crystal_maiden_outfit",
	"item_force_staff",
	"item_hand_of_midas",
	"item_ultimate_scepter",
	"item_aghanims_shard",
	"item_orchid",
	"item_black_king_bar",
	"item_hurricane_pike",
	"item_bloodthorn",
	"item_mystic_staff",
	"item_ultimate_scepter_2",
	"item_sheepstick",
	"item_moon_shard",
	"item_wind_waker",
}
sRoleItemsBuyList["pos_2"] = {
	"item_tango",
	"item_double_branches",
	"item_double_circlet",
	"item_bottle",
	"item_magic_wand",
	"item_power_treads",
	"item_orchid",
	"item_ultimate_scepter",
	"item_aghanims_shard",
	"item_black_king_bar",
	"item_octarine_core",
	"item_force_staff",
	"item_bloodthorn",
	"item_ultimate_scepter_2",
	"item_travel_boots",
	"item_hurricane_pike",
	"item_wind_waker",
	"item_travel_boots_2",
	"item_moon_shard",
}
sRoleItemsBuyList["pos_4"] = {
	"item_priest_outfit",
	"item_mekansm",
	"item_essence_distiller",
	"item_glimmer_cape",
	"item_holy_locket",
	"item_aghanims_shard",
	"item_guardian_greaves",
	"item_spirit_vessel",
	"item_ultimate_scepter",
	"item_sheepstick",
	"item_mystic_staff",
	"item_ultimate_scepter_2",
	"item_moon_shard",
	"item_wind_waker",
}
sRoleItemsBuyList["pos_5"] = {
	"item_tango",
	"item_blood_grenade",
	"item_magic_stick",
	"item_double_branches",
	"item_faerie_fire",
	"item_magic_wand",
	"item_arcane_boots",
	"item_holy_locket",
	"item_glimmer_cape",
	"item_guardian_greaves",
	"item_aghanims_shard",
	"item_spirit_vessel",
	"item_aether_lens",
	"item_ultimate_scepter",
	"item_sheepstick",
	"item_ultimate_scepter_2",
	"item_moon_shard",
	"item_wind_waker",
}
sRoleItemsBuyList["pos_3"] = sRoleItemsBuyList["pos_1"]
X["sBuyList"] = sRoleItemsBuyList[sRole]
X["sSellList"] = { "item_ultimate_scepter", "item_magic_wand" }
if Fu.Role.IsPvNMode() or Fu.Role.IsAllShadow() then
	X["sBuyList"], X["sSellList"] = { "PvN_priest" }, {}
end
nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"] =
	Fu.SetUserHeroInit(nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"])
X["sSkillList"] = Fu.Skill.GetSkillList(sAbilityList, nAbilityBuildList, sTalentList, nTalentBuildList)
X["bDeafaultAbility"] = false
X["bDeafaultItem"] = true
function X.MinionThink(minion)
	if Minion.IsValidUnit(minion) then
		Minion.IllusionThink(minion)
	end
end
local poisonTouchAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[1]), "sAbilityList[1]", "dazzle")
local shallowGraveAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[2]), "sAbilityList[2]", "dazzle")
local shadowWaveAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[3]), "sAbilityList[3]", "dazzle")
local ultimateAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[6]), "sAbilityList[6]", "dazzle")
local nothlProjectionAbility =
	SafeAbility(bot:GetAbilityByName("dazzle_nothl_projection"), "dazzle_nothl_projection", "dazzle")
local nothlProjectionEndAbility =
	SafeAbility(bot:GetAbilityByName("dazzle_nothl_projection_end"), "dazzle_nothl_projection_end", "dazzle")
local talent3 = SafeAbility(bot:GetAbilityByName(sTalentList[3]), "sTalentList[3]", "dazzle")
local talent4 = SafeAbility(bot:GetAbilityByName(sTalentList[4]), "sTalentList[4]", "dazzle")
local talent6 = SafeAbility(bot:GetAbilityByName(sTalentList[6]), "sTalentList[6]", "dazzle")
local poisonTouchDesire, poisonTouchTarget
local shallowGraveDesire, shallowGraveTarget
local shadowWaveDesire, shadowWaveTarget
local ultimateDesire, ultimateTarget
local unusedDesire, unusedTarget
local nothlProjectionDesire, nothlProjectionLocation, nothlProjectionEndDesire
local aetherRange = 0
local shadowWaveBonusDamage = 0
local mpRatio, hpRatio, nearbyEnemies, nearbyAllies
function X.SkillsComplement()
	local hasBodyDebuff = bot:HasModifier("modifier_dazzle_nothl_projection_physical_body_debuff")
	if hasBodyDebuff then
		Fu.Utils.GameStates.dazzleNothl[bot:GetPlayerID()].body = bot
	end
	if Fu.CanNotUseAbility(bot) or hasBodyDebuff then
		return
	end
	-- Invisible (Glimmer Cape is in his build): keep other spells quiet so the invisibility is not
	-- broken, but still allow Shallow Grave. The old early return let allies die next to an
	-- invisible Dazzle.
	local invisOnlyGrave = bot:IsInvisible()
	poisonTouchAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[1]), "sAbilityList[1]", "dazzle")
	shallowGraveAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[2]), "sAbilityList[2]", "dazzle")
	shadowWaveAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[3]), "sAbilityList[3]", "dazzle")
	ultimateAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[6]), "sAbilityList[6]", "dazzle")
	nothlProjectionAbility =
		SafeAbility(bot:GetAbilityByName("dazzle_nothl_projection"), "dazzle_nothl_projection", "dazzle")
	nothlProjectionEndAbility =
		SafeAbility(bot:GetAbilityByName("dazzle_nothl_projection_end"), "dazzle_nothl_projection_end", "dazzle")
	local context = AbilityContext.Build(bot)
	aetherRange = context.aetherRange
	mpRatio = context.mp
	hpRatio = context.hp
	botTarget = context.target
	nearbyEnemies = context.enemies
	nearbyAllies = context.allies
	shallowGraveDesire, shallowGraveTarget = X.ConsiderW()
	if shallowGraveDesire > 0 then
		if invisOnlyGrave and DotaTime() >= (bot._graveInvisLogAt or -999) then
			bot._graveInvisLogAt = DotaTime() + 5
			pcall(
				print,
				string.format(
					"[OHA-DAZZLE] t=%.0f grave while invisible on=%s",
					DotaTime(),
					shallowGraveTarget:GetUnitName()
				)
			)
		end
		Fu.SetQueuePtToINT(bot, true)
		bot:ActionQueue_UseAbilityOnEntity(shallowGraveAbility, shallowGraveTarget)
		return
	end
	if invisOnlyGrave then
		return
	end
	nothlProjectionDesire, nothlProjectionLocation = X.ConsiderNothlProjection()
	if nothlProjectionDesire > 0 then
		Fu.SetQueuePtToINT(bot, true)
		bot:ActionQueue_UseAbilityOnLocation(nothlProjectionAbility, nothlProjectionLocation)
		return
	end
	nothlProjectionEndDesire = X.ConsiderNothlProjectionEnd()
	if nothlProjectionEndDesire > 0 then
		bot:ActionQueue_UseAbility(nothlProjectionEndAbility)
		return
	end
	poisonTouchDesire, poisonTouchTarget = X.ConsiderQ()
	if poisonTouchDesire > 0 then
		Fu.SetQueuePtToINT(bot, true)
		bot:ActionQueue_UseAbilityOnEntity(poisonTouchAbility, poisonTouchTarget)
		return
	end
	shadowWaveDesire, shadowWaveTarget = X.ConsiderE()
	if shadowWaveDesire > 0 then
		Fu.SetQueuePtToINT(bot, true)
		bot:ActionQueue_UseAbilityOnEntity(shadowWaveAbility, shadowWaveTarget)
		return
	end
end
function X.ConsiderNothlProjection()
	if
		not Fu.CanCastAbility(nothlProjectionAbility) or bot:HasModifier("modifier_dazzle_nothl_projection_soul_debuff")
	then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local closeEnemies = Fu.GetNearbyHeroes(bot, 400, true, BOT_MODE_NONE)
	if #closeEnemies >= 1 then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidHero(botTarget)
			and Fu.IsInRange(bot, botTarget, 600)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.CanBeAttacked(botTarget)
			and Fu.GetHP(botTarget) < 0.7
			and not Fu.IsChasingTarget(bot, botTarget)
			and not Fu.CannotBeKilled(bot, botTarget)
		then
			local alliesNearTarget = Fu.GetAlliesNearLoc(botTarget:GetLocation(), 1200)
			local enemiesNearTarget = Fu.GetEnemiesNearLoc(botTarget:GetLocation(), 1200)
			local enemyTowers = bot:GetNearbyTowers(900, true)
			if
				#alliesNearTarget >= #enemiesNearTarget
				and #alliesNearTarget < #enemiesNearTarget + 2
				and #enemyTowers == 0
			then
				if #enemiesNearTarget <= 1 then
					local nDamage = bot:GetEstimatedDamageToTarget(true, botTarget, 5.0, DAMAGE_TYPE_ALL)
					if botTarget:GetActualIncomingDamage(nDamage, DAMAGE_TYPE_ALL) / bot:GetHealth() >= 0.4 then
						return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
					end
				else
					return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
				end
			end
		end
	end
	local castRange = nothlProjectionAbility:GetCastRange()
	if Fu.IsInTeamFight(bot, 1200) then
		if
			Fu.IsValidHero(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(botTarget, bot, castRange)
			and Fu.CanCastOnTargetAdvanced(botTarget)
			and Fu.GetHP(botTarget) < 0.7
			and Fu.GetHP(bot) > 0.5
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation() + RandomVector(100)
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function X.ConsiderNothlProjectionEnd()
	if not Fu.CanCastAbility(nothlProjectionEndAbility) then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	if #nearbyEnemies <= 0 then
		return BOT_ACTION_DESIRE_HIGH
	end
	local physicalBody = Fu.Utils.GameStates.dazzleNothl[bot:GetPlayerID()].body
	if Fu.IsValid(bot) then
		if Fu.IsRetreating(physicalBody) and Fu.GetHP(physicalBody) < 0.6 and #nearbyEnemies >= 1 then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function X.ConsiderR()
	if not ultimateAbility:IsFullyCastable() then
		return 0
	end
	if
		not poisonTouchAbility:IsFullyCastable()
		and not shallowGraveAbility:IsFullyCastable()
		and not shadowWaveAbility:IsFullyCastable()
	then
		local enemiesInRange = Fu.GetNearbyHeroes(bot, 900, true, BOT_MODE_NONE)
		if #enemiesInRange >= 1 then
			return BOT_ACTION_DESIRE_HIGH, "none", "R-refresh"
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderQ()
	if not poisonTouchAbility:IsFullyCastable() then
		return 0
	end
	local abilityLevel = poisonTouchAbility:GetLevel()
	local castRange = poisonTouchAbility:GetCastRange()
	local searchRadius = 600
	local castPoint = poisonTouchAbility:GetCastPoint()
	local manaCost = poisonTouchAbility:GetManaCost()
	local damagePerSecond = poisonTouchAbility:GetSpecialValueInt("damage")
	if talent6:IsTrained() then
		damagePerSecond = damagePerSecond + talent6:GetSpecialValueInt("value")
	end
	local duration = poisonTouchAbility:GetSpecialValueInt("duration")
	local nDamage = damagePerSecond * duration
	local damageType = DAMAGE_TYPE_PHYSICAL
	local enemiesInCastRange = Fu.GetAroundEnemyHeroList(castRange)
	local enemiesInExtendedRange = Fu.GetAroundEnemyHeroList(castRange + 200)
	local castTarget = nil
	local castReason = nil
	for _, enemyHero in pairs(enemiesInExtendedRange) do
		if
			Fu.IsValid(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and Fu.CanCastOnTargetAdvanced(enemyHero)
			and Fu.CanKillTarget(enemyHero, nDamage, damageType)
		then
			castTarget = enemyHero
			castReason = "Q-击杀:" .. Fu.Chat.GetNormName(castTarget)
			return BOT_ACTION_DESIRE_HIGH, castTarget, castReason
		end
	end
	if (Fu.IsLaning(bot) or Fu.IsPushing(bot)) and mpRatio > 0.4 and #nearbyEnemies == 0 then
		local laneCreeps = bot:GetNearbyLaneCreeps(castRange, true)
		if #laneCreeps >= 3 then
			local creep = laneCreeps[1]
			if Fu.IsValid(creep) and not creep:HasModifier("modifier_fountain_glyph") then
				castTarget = creep
				castReason = "Q-farming creeps"
				return BOT_ACTION_DESIRE_HIGH, castTarget, castReason
			end
		end
	end
	if Fu.IsInTeamFight(bot, 1200) then
		local weakestEnemy = nil
		local lowestHealth = 10000
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValid(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
			then
				local health = enemyHero:GetHealth()
				if health < lowestHealth then
					lowestHealth = health
					weakestEnemy = enemyHero
				end
			end
		end
		if weakestEnemy ~= nil and Fu.IsInRange(bot, weakestEnemy, castRange + 100) then
			castTarget = weakestEnemy
			castReason = "Q-团战:" .. Fu.Chat.GetNormName(castTarget)
			return BOT_ACTION_DESIRE_HIGH, castTarget, castReason
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidHero(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(botTarget, bot, castRange + 50)
			and Fu.CanCastOnTargetAdvanced(botTarget)
		then
			if abilityLevel >= 2 or mpRatio > 0.68 or Fu.GetHP(botTarget) < 0.43 or hpRatio <= 0.4 then
				castTarget = botTarget
				castReason = "Q-进攻:" .. Fu.Chat.GetNormName(castTarget)
				return BOT_ACTION_DESIRE_HIGH, castTarget, castReason
			end
		end
	end
	if Fu.IsRetreating(bot) then
		for _, enemyHero in pairs(enemiesInCastRange) do
			if
				Fu.IsValid(enemyHero)
				and bot:WasRecentlyDamagedByHero(enemyHero, 5.0)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
			then
				castTarget = enemyHero
				castReason = "Q-撤退时减速:" .. Fu.Chat.GetNormName(castTarget)
				return BOT_ACTION_DESIRE_HIGH, castTarget, castReason
			end
		end
	end
	if Fu.IsFarming(bot) and abilityLevel >= 3 and #nearbyAllies <= 1 and Fu.IsAllowedToSpam(bot, manaCost * 0.25) then
		local neutralCreeps = bot:GetNearbyNeutralCreeps(castRange + 200)
		local healthiestCreep = Fu.GetMostHpUnit(neutralCreeps)
		if
			Fu.IsValid(healthiestCreep)
			and not Fu.IsRoshan(healthiestCreep)
			and #neutralCreeps >= 3
			and bot:IsFacingLocation(healthiestCreep:GetLocation(), 40)
			and (healthiestCreep:GetMagicResist() < 0.3 or mpRatio > 0.9)
			and not Fu.CanKillTarget(healthiestCreep, bot:GetAttackDamage() * 1.88, DAMAGE_TYPE_PHYSICAL)
		then
			castTarget = healthiestCreep
			castReason = "Q-打野"
			return BOT_ACTION_DESIRE_HIGH, castTarget, castReason
		end
	end
	if
		(Fu.IsPushing(bot) or Fu.IsDefending(bot) or Fu.IsFarming(bot))
		and Fu.IsAllowedToSpam(bot, manaCost)
		and abilityLevel >= 3
		and DotaTime() > 6 * 60
		and #nearbyAllies <= 2
		and #nearbyEnemies == 0
	then
		local laneCreeps = bot:GetNearbyLaneCreeps(castRange + 300, true)
		local creep = laneCreeps[3]
		if
			#laneCreeps >= 4
			and Fu.IsValid(creep)
			and not creep:HasModifier("modifier_fountain_glyph")
			and not Fu.CanKillTarget(creep, bot:GetAttackDamage() * 1.88, DAMAGE_TYPE_PHYSICAL)
		then
			castTarget = creep
			castReason = "Q-推线"
			return BOT_ACTION_DESIRE_HIGH, castTarget, castReason
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if
			Fu.IsRoshan(botTarget)
			and Fu.CanBeAttacked(botTarget)
			and Fu.IsInRange(botTarget, bot, castRange)
			and Fu.IsAttacking(bot)
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(botTarget, bot, castRange) and Fu.IsAttacking(bot) then
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end
	if
		(#nearbyEnemies > 0 or bot:WasRecentlyDamagedByAnyHero(3.0))
		and (bot:GetActiveMode() ~= BOT_MODE_RETREAT or #nearbyAllies >= 2)
		and #enemiesInCastRange >= 1
		and abilityLevel >= 4
	then
		for _, enemyHero in pairs(enemiesInCastRange) do
			if
				Fu.IsValid(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
			then
				castTarget = enemyHero
				castReason = "Q-常规:" .. Fu.Chat.GetNormName(castTarget)
				return BOT_ACTION_DESIRE_HIGH, castTarget, castReason
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderW()
	if not shallowGraveAbility:IsFullyCastable() then
		return 0
	end
	local abilityLevel = shallowGraveAbility:GetLevel()
	local castRange = shallowGraveAbility:GetCastRange() + aetherRange
	local searchRadius = 600
	local castPoint = shallowGraveAbility:GetCastPoint()
	local manaCost = shallowGraveAbility:GetManaCost()
	local nDamage = shallowGraveAbility:GetAbilityDamage()
	local damageType = DAMAGE_TYPE_PHYSICAL
	local enemiesInCastRange = Fu.GetAroundEnemyHeroList(castRange)
	local enemiesInExtendedRange = Fu.GetAroundEnemyHeroList(castRange + 200)
	local castTarget = nil
	local castReason = nil
	for _, ally in pairs(nearbyAllies) do
		if
			Fu.IsValidHero(ally)
			and Fu.IsInRange(bot, ally, castRange + 200)
			and not ally:HasModifier("modifier_dazzle_shallow_grave")
			and Fu.GetHP(ally) < 0.5
		then
			local incomingDamage = Fu.GetAttackProjectileDamageByRange(ally, 1600)
			if incomingDamage > 0 and incomingDamage >= ally:GetHealth() then
				castTarget = ally
				castReason = "W-incoming projectile kill on:" .. Fu.Chat.GetNormName(castTarget)
				return BOT_ACTION_DESIRE_HIGH, castTarget, castReason
			end
		end
	end
	for _, ally in pairs(nearbyAllies) do
		if
			Fu.IsValidHero(ally)
			and Fu.IsInRange(bot, ally, castRange + 600)
			and not ally:HasModifier("modifier_dazzle_shallow_grave")
			and Fu.GetHP(ally) < 0.4
			and ally:WasRecentlyDamagedByAnyHero(3.5)
		then
			local castDelay = X.GetCastAbilityWDelay(ally, castRange) * 1.1
			if X.GetEnemyFacingAllyDamage(ally, 1100, castDelay) > ally:GetHealth() then
				castTarget = ally
				castReason = "W-保护可能被击杀的队友:" .. Fu.Chat.GetNormName(castTarget)
				return BOT_ACTION_DESIRE_HIGH, castTarget, castReason
			end
			if ally:GetHealth() < 200 then
				if ally:HasModifier("modifier_sniper_assassinate") then
					castTarget = ally
					castReason = "W-保护被暗杀的队友:" .. Fu.Chat.GetNormName(castTarget)
					return BOT_ACTION_DESIRE_HIGH, castTarget, castReason
				end
				if
					ally:HasModifier("modifier_huskar_burning_spear_counter")
					or ally:HasModifier("modifier_jakiro_macropyre_burn")
					or ally:HasModifier("modifier_necrolyte_reapers_scythe")
					or ally:HasModifier("modifier_viper_viper_strike_slow")
					or ally:HasModifier("modifier_viper_nethertoxin")
					or ally:HasModifier("modifier_viper_poison_attack_slow")
					or ally:HasModifier("modifier_maledict")
				then
					castTarget = ally
					castReason = "W-防止队友被Debuff击杀:" .. Fu.Chat.GetNormName(castTarget)
					return BOT_ACTION_DESIRE_HIGH, castTarget, castReason
				end
			end
			if
				Fu.GetHP(ally) < 0.13
				and Fu.IsInRange(bot, ally, castRange + 200)
				and Fu.GetEnemyCount(ally, 600) >= 1
			then
				castTarget = ally
				castReason = "W-防止低血量队友被击杀:" .. Fu.Chat.GetNormName(castTarget)
				return BOT_ACTION_DESIRE_HIGH, castTarget, castReason
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderE()
	if not shadowWaveAbility:IsFullyCastable() then
		return 0
	end
	local abilityLevel = shadowWaveAbility:GetLevel()
	local castRange = shadowWaveAbility:GetCastRange() + aetherRange
	local radius = shadowWaveAbility:GetSpecialValueInt("damage_radius")
	local castPoint = shadowWaveAbility:GetCastPoint()
	local manaCost = shadowWaveAbility:GetManaCost()
	local nDamage = shadowWaveAbility:GetSpecialValueInt("damage") + shadowWaveBonusDamage
	local maxTargets = shadowWaveAbility:GetSpecialValueInt("tooltip_max_targets_inc_dazzle")
	local damageType = DAMAGE_TYPE_PHYSICAL
	local alliesNearby = Fu.GetAlliesNearLoc(bot:GetLocation(), castRange + 300)
	local castTarget = nil
	local castReason = nil
	local weakestAlly = Fu.GetLeastHpUnit(alliesNearby)
	local injuredAllyCount = 0
	for _, ally in pairs(nearbyAllies) do
		if ally:GetMaxHealth() - ally:GetHealth() > nDamage then
			injuredAllyCount = injuredAllyCount + 1
		end
	end
	if weakestAlly ~= nil then
		if Fu.GetHP(weakestAlly) < 0.8 and (injuredAllyCount >= maxTargets - 2 or injuredAllyCount >= 4) then
			castTarget = weakestAlly
			castReason = "E-治疗多个队友:" .. Fu.Chat.GetNormName(castTarget)
			return BOT_ACTION_DESIRE_HIGH, castTarget, castReason
		end
		if
			Fu.GetHP(weakestAlly) < 0.6
			and (mpRatio > 0.9 or injuredAllyCount >= maxTargets - 3 or injuredAllyCount >= 3)
		then
			castTarget = weakestAlly
			castReason = "E-治疗半血队友:" .. Fu.Chat.GetNormName(castTarget)
			return BOT_ACTION_DESIRE_HIGH, castTarget, castReason
		end
		if Fu.GetHP(weakestAlly) < 0.35 or Fu.GetHP(weakestAlly) < 0.5 and injuredAllyCount >= 2 then
			castTarget = weakestAlly
			castReason = "E-紧急治疗队友:" .. Fu.Chat.GetNormName(castTarget)
			return BOT_ACTION_DESIRE_HIGH, castTarget, castReason
		end
	end
	if #nearbyAllies <= 2 and #nearbyEnemies == 0 and abilityLevel >= 3 and Fu.IsAllowedToSpam(bot, 90) then
		local allyCreeps = bot:GetNearbyLaneCreeps(1400, false)
		local injuredCreepCount = 0
		for _, creep in pairs(allyCreeps) do
			if creep:GetMaxHealth() - creep:GetHealth() > nDamage then
				injuredCreepCount = injuredCreepCount + 1
			elseif creep:GetMaxHealth() - creep:GetHealth() > nDamage * 0.6 then
				injuredCreepCount = injuredCreepCount + 0.6
			end
		end
		if injuredCreepCount >= maxTargets - 1 then
			local weakestCreep = Fu.GetLeastHpUnit(allyCreeps)
			if weakestCreep ~= nil then
				castTarget = weakestCreep
				castReason = "E-治疗兵线:" .. injuredCreepCount
				return BOT_ACTION_DESIRE_HIGH, castTarget, castReason
			end
		end
	end
	local totalAoeDamage = 0
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.IsInRange(bot, enemyHero, castRange + 300)
			and Fu.CanCastOnMagicImmune(enemyHero)
		then
			local alliesAroundEnemy = Fu.GetUnitAllyCountAroundEnemyTarget(enemyHero, radius)
			if Fu.CanKillTarget(enemyHero, alliesAroundEnemy * nDamage, damageType) then
				castTarget = X.GetBestHealTarget(enemyHero, radius)
				if castTarget ~= nil then
					castReason = "E-击杀敌人:" .. Fu.Chat.GetNormName(enemyHero)
					return BOT_ACTION_DESIRE_HIGH, castTarget, castReason
				end
			end
			if alliesAroundEnemy >= 1 and abilityLevel >= 3 then
				totalAoeDamage = totalAoeDamage + alliesAroundEnemy * nDamage
			end
			if totalAoeDamage >= 800 and weakestAlly ~= nil and Fu.IsInRange(bot, weakestAlly, castRange + 50) then
				castTarget = weakestAlly
				castReason = "E-Aoe伤害:" .. totalAoeDamage
				return BOT_ACTION_DESIRE_HIGH, castTarget, castReason
			end
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidHero(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange + 200)
			and Fu.CanCastOnMagicImmune(botTarget)
		then
			local alliesAroundTarget = Fu.GetUnitAllyCountAroundEnemyTarget(botTarget, radius)
			if alliesAroundTarget >= maxTargets - 2 or alliesAroundTarget >= 4 then
				castTarget = X.GetBestHealTarget(botTarget, radius)
				if castTarget ~= nil then
					castReason = "E-伤害目标:" .. Fu.Chat.GetNormName(botTarget)
					return BOT_ACTION_DESIRE_HIGH, castTarget, castReason
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.GetBestHealTarget(enemyTarget, radius)
	local bestTarget = nil
	local mostMissingHealth = -1
	local allyCreeps = bot:GetNearbyCreeps(1600, false)
	local allyHeroes = Fu.GetNearbyHeroes(bot, 1600, false, BOT_MODE_NONE)
	local allyUnits = Fu.CombineTwoTable(allyCreeps, allyHeroes)
	for _, unit in pairs(allyUnits) do
		if
			Fu.IsInRange(enemyTarget, unit, radius + 9)
			and unit:GetMaxHealth() - unit:GetHealth() > mostMissingHealth
		then
			mostMissingHealth = unit:GetMaxHealth() - unit:GetHealth()
			bestTarget = unit
		end
	end
	return bestTarget
end
function X.GetCastAbilityWDelay(ally, castRange)
	if not Fu.IsInRange(bot, ally, castRange) then
		local distanceOutside = GetUnitToUnitDistance(bot, ally) - castRange
		local travelTime = distanceOutside / bot:GetCurrentMovementSpeed()
		return 0.4 + travelTime + 1.3
	end
	return 0.4 + 1.1
end
function X.GetAbilityEMaxDamage(enemyTarget)
	local radius = shadowWaveAbility:GetSpecialValueInt("damage_radius")
	local alliesAroundTarget = Fu.GetUnitAllyCountAroundEnemyTarget(enemyTarget, radius)
	local maxDamage = shadowWaveAbility:GetSpecialValueInt("damage") + shadowWaveBonusDamage
	-- Each ally Shadow Wave heals near the target hits it for "damage" (game data; was the undefined global nDamage).
	return alliesAroundTarget * maxDamage
end
function X.GetEnemyFacingAllyDamage(ally, radius, duration)
	local enemyList = Fu.GetEnemyList(ally, radius)
	local totalDamage = 0
	for _, enemyHero in pairs(enemyList) do
		if enemyHero:IsFacingLocation(ally:GetLocation(), 15) or enemyHero:GetAttackTarget() == ally then
			local estimatedDamage = enemyHero:GetEstimatedDamageToTarget(false, ally, duration, DAMAGE_TYPE_ALL)
			totalDamage = totalDamage + estimatedDamage
		end
	end
	return totalDamage
end
return X
