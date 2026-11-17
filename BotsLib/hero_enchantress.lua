-- Enchantress: skill build, item build, and ability use for this hero.
local X = {}
local bot = GetBot()
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local AbilityContext = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local Minion = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local sTalentList = Fu.Skill.GetTalentList(bot)
local sAbilityList = Fu.Skill.GetAbilityList(bot)
local sRole = Fu.Item.GetRoleItemsBuyList(bot)
local tTalentTreeList = {
	{ ["t25"] = { 0, 10 }, ["t20"] = { 0, 10 }, ["t15"] = { 0, 10 }, ["t10"] = { 10, 0 } },
	{ ["t25"] = { 0, 10 }, ["t20"] = { 0, 10 }, ["t15"] = { 0, 10 }, ["t10"] = { 10, 0 } },
}
-- tAllAbilityBuildList[2] (pos 4/5): Impetus first, then Nature's Attendants, Enchant last, as Dotabuff's most picked
-- order (the support Enchantress there is a right-click Impetus build: Treads, Pike, Scepter).
local tAllAbilityBuildList =
	{ { 1, 3, 1, 3, 1, 6, 1, 2, 3, 3, 6, 2, 2, 2, 6 }, { 1, 3, 1, 3, 1, 6, 1, 3, 3, 2, 6, 2, 2, 2, 6 } }
local nAbilityBuildList = tAllAbilityBuildList[1]
if sRole == "pos_3" then
	nAbilityBuildList = tAllAbilityBuildList[1]
end
if sRole == "pos_4" then
	nAbilityBuildList = tAllAbilityBuildList[2]
end
if sRole == "pos_5" then
	nAbilityBuildList = tAllAbilityBuildList[2]
end
local nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList[1])
if sRole == "pos_3" then
	nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList[1])
end
if sRole == "pos_4" then
	nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList[2])
end
if sRole == "pos_5" then
	nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList[2])
end
local sCrimsonGuardOrHalberd = { "item_heavens_halberd", "item_crimson_guard" }
local sUtility = sCrimsonGuardOrHalberd[RandomInt(1, #sCrimsonGuardOrHalberd)]
local sRoleItemsBuyList = {}
sRoleItemsBuyList["pos_3"] = {
	"item_tango",
	"item_magic_stick",
	"item_double_branches",
	"item_circlet",
	"item_magic_wand",
	"item_bracer",
	"item_power_treads",
	"item_mage_slayer",
	"item_force_staff",
	"item_hurricane_pike",
	sUtility,
	"item_pipe",
	"item_assault",
	"item_moon_shard",
	"item_travel_boots_2",
	"item_aghanims_shard",
	"item_ultimate_scepter_2",
}
sRoleItemsBuyList["pos_4"] = {
	"item_double_tango",
	"item_double_branches",
	"item_faerie_fire",
	"item_blood_grenade",
	"item_magic_wand",
	"item_boots",
	"item_force_staff",
	"item_guardian_greaves",
	"item_hurricane_pike",
	"item_aghanims_shard",
	"item_ultimate_scepter",
	"item_moon_shard",
	"item_bloodthorn",
	"item_sheepstick",
	"item_ultimate_scepter_2",
}
sRoleItemsBuyList["pos_5"] = {
	"item_double_tango",
	"item_double_branches",
	"item_faerie_fire",
	"item_blood_grenade",
	"item_magic_wand",
	"item_boots",
	"item_force_staff",
	"item_pavise",
	"item_pipe",
	"item_solar_crest",
	"item_hurricane_pike",
	"item_aghanims_shard",
	"item_boots_of_bearing",
	"item_ultimate_scepter",
	"item_bloodthorn",
	"item_sheepstick",
	"item_ultimate_scepter_2",
}
sRoleItemsBuyList["pos_1"] = {
	"item_ranged_carry_outfit",
	"item_dragon_lance",
	"item_point_booster",
	"item_force_staff",
	"item_hurricane_pike",
	"item_black_king_bar",
	"item_travel_boots",
	"item_mage_slayer",
	"item_bloodthorn",
	"item_sheepstick",
	"item_aghanims_shard",
	"item_moon_shard",
	"item_travel_boots_2",
	"item_ultimate_scepter_2",
}
sRoleItemsBuyList["pos_2"] = sRoleItemsBuyList["pos_1"]
X["sBuyList"] = sRoleItemsBuyList[sRole]
X["sSellList"] = { "item_ultimate_scepter", "item_magic_wand", "item_cyclone", "item_magic_wand" }
if Fu.Role.IsPvNMode() or Fu.Role.IsAllShadow() then
	X["sBuyList"], X["sSellList"] = { "PvN_antimage" }, {}
end
nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"] =
	Fu.SetUserHeroInit(nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"])
X["sSkillList"] = Fu.Skill.GetSkillList(sAbilityList, nAbilityBuildList, sTalentList, nTalentBuildList)
X["bDeafaultAbility"] = false
X["bDeafaultItem"] = false
function X.MinionThink(minionUnit)
	Minion.MinionThink(minionUnit)
end
local impetusAbility = SafeAbility(bot:GetAbilityByName("enchantress_impetus"), "enchantress_impetus", "enchantress")
local enchantAbility = SafeAbility(bot:GetAbilityByName("enchantress_enchant"), "enchantress_enchant", "enchantress")
local naturesAttendantsAbility =
	SafeAbility(bot:GetAbilityByName("enchantress_natures_attendants"), "enchantress_natures_attendants", "enchantress")
local sproinkAbility =
	SafeAbility(bot:GetAbilityByName("enchantress_bunny_hop"), "enchantress_bunny_hop", "enchantress")
local littleFriendsAbility =
	SafeAbility(bot:GetAbilityByName("enchantress_little_friends"), "enchantress_little_friends", "enchantress")
local impetusDesire
local enchantDesire, enchantTarget
local naturesAttendantsDesire
local sproinkDesire
local littleFriendsDesire, littleFriendsTarget
local botTarget
local isGoingOnSomeone
local isRetreating
local mpRatio
function X.SkillsComplement()
	local context = AbilityContext.Build(bot)
	isGoingOnSomeone = context.isEngaging
	isRetreating = context.isRetreating
	mpRatio = context.mp
	if Fu.CanNotUseAbility(bot) then
		return
	end
	littleFriendsDesire, littleFriendsTarget = X.ConsiderLittleFriends()
	if littleFriendsDesire > 0 then
		bot:Action_UseAbilityOnEntity(littleFriendsAbility, littleFriendsTarget)
		return
	end
	impetusDesire = X.ConsiderImpetus()
	if impetusDesire > 0 then
		return
	end
	sproinkDesire = X.ConsiderSproink()
	if sproinkDesire > 0 then
		bot:Action_UseAbility(sproinkAbility)
		return
	end
	naturesAttendantsDesire = X.ConsiderNaturesAttendant()
	if naturesAttendantsDesire > 0 then
		bot:Action_UseAbility(naturesAttendantsAbility)
		return
	end
	enchantDesire, enchantTarget = X.ConsiderEnchant()
	if enchantDesire > 0 then
		bot:Action_UseAbilityOnEntity(enchantAbility, enchantTarget)
		return
	end
end
function X.ConsiderImpetus()
	if not impetusAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
	end
	local attackRange = bot:GetAttackRange()
	local impetusLevel = impetusAbility:GetLevel()
	botTarget = Fu.GetProperTarget(bot)
	if isGoingOnSomeone then
		local nInRangeAlly = Fu.GetNearbyHeroes(bot, 1200, false, BOT_MODE_NONE)
		local nInRangeEnemy = Fu.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE)
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and nInRangeAlly ~= nil
			and nInRangeEnemy ~= nil
			and #nInRangeAlly >= #nInRangeEnemy
		then
			if not impetusAbility:GetAutoCastState() then
				impetusAbility:ToggleAutoCast()
				return BOT_ACTION_DESIRE_HIGH
			else
				return BOT_ACTION_DESIRE_NONE
			end
		end
	end
	if Fu.IsFarming(bot) and impetusLevel == 4 then
		local nearbyNeutrals = bot:GetNearbyNeutralCreeps(attackRange)
		if nearbyNeutrals ~= nil and #nearbyNeutrals >= 1 and Fu.IsValid(nearbyNeutrals[1]) then
			if not impetusAbility:GetAutoCastState() then
				impetusAbility:ToggleAutoCast()
				return BOT_ACTION_DESIRE_HIGH
			else
				if impetusAbility:GetAutoCastState() and mpRatio < 0.25 then
					impetusAbility:ToggleAutoCast()
					return BOT_ACTION_DESIRE_HIGH
				end
				return BOT_ACTION_DESIRE_NONE
			end
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if Fu.IsRoshan(botTarget) and Fu.IsInRange(bot, botTarget, 500) and Fu.IsAttacking(bot) then
			if not impetusAbility:GetAutoCastState() then
				impetusAbility:ToggleAutoCast()
				return BOT_ACTION_DESIRE_HIGH
			else
				if impetusAbility:GetAutoCastState() and mpRatio < 0.25 then
					impetusAbility:ToggleAutoCast()
					return BOT_ACTION_DESIRE_HIGH
				end
				return BOT_ACTION_DESIRE_NONE
			end
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, 400) and Fu.IsAttacking(bot) then
			if not impetusAbility:GetAutoCastState() then
				impetusAbility:ToggleAutoCast()
				return BOT_ACTION_DESIRE_HIGH
			else
				if impetusAbility:GetAutoCastState() and mpRatio < 0.25 then
					impetusAbility:ToggleAutoCast()
					return BOT_ACTION_DESIRE_HIGH
				end
				return BOT_ACTION_DESIRE_NONE
			end
		end
	end
	if impetusAbility:GetAutoCastState() then
		impetusAbility:ToggleAutoCast()
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderEnchant()
	if not enchantAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castRange = enchantAbility:GetCastRange()
	local maxCreepLevel = enchantAbility:GetSpecialValueInt("level_req")
	local enchantDamage = enchantAbility:GetSpecialValueInt("enchant_damage")
	local duration = enchantAbility:GetSpecialValueFloat("slow_duration")
	local nearbyNeutrals = bot:GetNearbyNeutralCreeps(castRange)
	botTarget = Fu.GetProperTarget(bot)
	local nearbyAllies = Fu.GetNearbyHeroes(bot, castRange, false, BOT_MODE_NONE)
	for _, allyHero in pairs(nearbyAllies) do
		local allyNearbyEnemies = Fu.GetNearbyHeroes(allyHero, castRange, true, BOT_MODE_NONE)
		if
			Fu.IsRetreating(allyHero)
			and allyNearbyEnemies ~= nil
			and Fu.IsValidHero(allyNearbyEnemies[1])
			-- Enchant does not pierce spell immunity: do not waste it on a BKB'd chaser.
			and Fu.CanCastOnNonMagicImmune(allyNearbyEnemies[1])
			and not Fu.IsSuspiciousIllusion(allyNearbyEnemies[1])
			and not Fu.IsDisabled(allyNearbyEnemies[1])
		then
			if Fu.IsInRange(bot, allyNearbyEnemies[1], castRange) then
				return BOT_ACTION_DESIRE_HIGH, allyNearbyEnemies[1]
			end
		end
	end
	if isGoingOnSomeone then
		local nInRangeAlly = Fu.GetNearbyHeroes(bot, castRange + 100, false, BOT_MODE_NONE)
		local nInRangeEnemy = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not botTarget:HasModifier("modifier_faceless_void_chronosphere")
			and nInRangeAlly ~= nil
			and nInRangeEnemy ~= nil
			and (
				#nInRangeAlly >= #nInRangeEnemy
				or #nInRangeEnemy > #nInRangeAlly and Fu.WeAreStronger(bot, castRange + 100)
			)
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end
	local enchantCreepNames = {
		"npc_dota_neutral_alpha_wolf",
		"npc_dota_neutral_centaur_khan",
		"npc_dota_neutral_polar_furbolg_ursa_warrior",
		"npc_dota_neutral_dark_troll_warlord",
		"npc_dota_neutral_satyr_hellcaller",
		"npc_dota_neutral_enraged_wildkin",
		"npc_dota_neutral_warpine_raider",
	}
	for _, creep in pairs(nearbyNeutrals) do
		if Fu.IsValid(creep) and creep:GetLevel() <= maxCreepLevel then
			for _, creepName in pairs(enchantCreepNames) do
				if creep:GetUnitName() == creepName then
					return BOT_ACTION_DESIRE_HIGH, creep
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function X.ConsiderNaturesAttendant()
	if not naturesAttendantsAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
	end
	if isRetreating then
		if Fu.GetHP(bot) < 0.65 and bot:DistanceFromFountain() > 800 then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	-- Also heal in a fight, not only when running: she below half, or a hurt ally hero inside the
	-- wisp radius (datafeed: heals Enchantress and friendly units nearby).
	if isGoingOnSomeone or Fu.IsInTeamFight(bot, 1200) then
		local healRadius = naturesAttendantsAbility:GetSpecialValueInt("radius")
		if Fu.GetHP(bot) < 0.5 and bot:WasRecentlyDamagedByAnyHero(3.0) then
			return BOT_ACTION_DESIRE_HIGH
		end
		for _, ally in pairs(Fu.GetNearbyHeroes(bot, healRadius, false, BOT_MODE_NONE) or {}) do
			if ally ~= bot and Fu.IsValidHero(ally) and not ally:IsIllusion() and Fu.GetHP(ally) < 0.45 then
				pcall(
					print,
					string.format(
						"[OHA-ENCHANTRESS] t=%.0f attendants for %s hp=%.2f",
						DotaTime(),
						ally:GetUnitName(),
						Fu.GetHP(ally)
					)
				)
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderSproink()
	if not sproinkAbility:IsTrained() or not sproinkAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
	end
	local attackRange = bot:GetAttackRange()
	local nearbyAllies = Fu.GetNearbyHeroes(bot, attackRange + 100, false, BOT_MODE_NONE)
	local nearbyEnemies = Fu.GetNearbyHeroes(bot, attackRange, true, BOT_MODE_NONE)
	-- datafeed: Impetus damage per distance is "distance_damage_pct"; "value" read 0, so the kill check never passed
	local impetusDamagePerDistance = impetusAbility:GetSpecialValueFloat("distance_damage_pct") / 100
	botTarget = Fu.GetProperTarget(bot)
	-- Sproink dodges incoming projectiles (datafeed): use it on an incoming stun projectile.
	if Fu.IsStunProjectileIncoming(bot, 400) then
		pcall(print, string.format("[OHA-ENCHANTRESS] t=%.0f sproink dodge", DotaTime()))
		return BOT_ACTION_DESIRE_HIGH
	end
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanKillTarget(
				enemyHero,
				impetusDamagePerDistance * GetUnitToUnitDistance(bot, enemyHero),
				DAMAGE_TYPE_PURE
			)
			and bot:IsFacingLocation(enemyHero:GetLocation(), 15)
			and not Fu.IsSuspiciousIllusion(enemyHero)
			and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
			and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if isGoingOnSomeone then
		if
			Fu.IsValidTarget(botTarget)
			and bot:IsFacingLocation(botTarget:GetLocation(), 15)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not botTarget:HasModifier("modifier_dazzle_shallow_grave")
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if isRetreating then
		if
			nearbyAllies ~= nil
			and nearbyEnemies ~= nil
			and #nearbyEnemies > #nearbyAllies
			and Fu.IsValidHero(nearbyEnemies[1])
			and bot:IsFacingLocation(nearbyEnemies[1]:GetLocation(), 30)
			and not Fu.IsSuspiciousIllusion(nearbyEnemies[1])
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderLittleFriends()
	if not littleFriendsAbility:IsTrained() or not littleFriendsAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castRange = littleFriendsAbility:GetCastRange()
	local radius = littleFriendsAbility:GetSpecialValueInt("radius")
	local duration = littleFriendsAbility:GetSpecialValueInt("duration")
	local nearbyEnemies = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.GetHP(enemyHero) < 0.33
			and not Fu.IsSuspiciousIllusion(enemyHero)
			and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
			and not enemyHero:HasModifier("modifier_faceless_void_chronosphere")
		then
			bot:SetTarget(enemyHero)
			return BOT_ACTION_DESIRE_HIGH, enemyHero
		end
	end
	-- Engage: root the fight target (datafeed: Little Friends roots the enemy and every creep in
	-- 1200 attacks it). The old branch read npcTarget / nInRangeAlly / nTargetInRangeEnemy before
	-- they were defined (nil globals), so it never fired.
	if isGoingOnSomeone then
		local tgt = Fu.GetProperTarget(bot)
		local allies = Fu.GetNearbyHeroes(bot, castRange + 150, false, BOT_MODE_NONE) or {}
		local foes = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE) or {}
		if
			Fu.IsValidHero(tgt)
			and Fu.CanCastOnNonMagicImmune(tgt)
			and Fu.IsInRange(bot, tgt, castRange)
			and #allies >= #foes
			and not Fu.IsSuspiciousIllusion(tgt)
			and not Fu.IsDisabled(tgt)
			and not tgt:HasModifier("modifier_abaddon_borrowed_time")
			and not tgt:HasModifier("modifier_faceless_void_chronosphere")
		then
			pcall(
				print,
				string.format("[OHA-ENCHANTRESS] t=%.0f little friends engage %s", DotaTime(), tgt:GetUnitName())
			)
			return BOT_ACTION_DESIRE_HIGH, tgt
		end
	end
	if isRetreating then
		local nInRangeAlly = Fu.GetNearbyHeroes(bot, castRange + 150, false, BOT_MODE_NONE)
		local nInRangeEnemy = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
		if
			nInRangeAlly ~= nil
			and nInRangeEnemy ~= nil
			and #nInRangeEnemy > #nInRangeAlly
			and Fu.IsValidHero(nInRangeEnemy[1])
			and Fu.IsInRange(bot, nInRangeEnemy[1], castRange)
			and not Fu.IsSuspiciousIllusion(nInRangeEnemy[1])
		then
			return BOT_ACTION_DESIRE_HIGH, nInRangeEnemy[1]
		end
	end
	if Fu.IsDoingRoshan(bot) then
		local attackTarget = bot:GetAttackTarget()
		if
			Fu.IsRoshan(attackTarget)
			and Fu.CanCastOnNonMagicImmune(attackTarget)
			and Fu.IsInRange(bot, attackTarget, castRange)
		then
			return BOT_ACTION_DESIRE_HIGH, attackTarget
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
return X
