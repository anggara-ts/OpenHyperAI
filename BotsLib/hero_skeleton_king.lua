-- Skeleton King: skill build, item build, and ability use for this hero.
local X = {}
local bot = GetBot()
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local AbilityContext = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local Minion = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local sTalentList = Fu.Skill.GetTalentList(bot)
local sAbilityList = Fu.Skill.GetAbilityList(bot)
local sRole = Fu.Item.GetRoleItemsBuyList(bot)
local tTalentTreeList = { ["t25"] = { 0, 10 }, ["t20"] = { 10, 0 }, ["t15"] = { 10, 0 }, ["t10"] = { 10, 0 } }
local tAllAbilityBuildList = { { 2, 1, 2, 3, 2, 6, 2, 3, 3, 3, 6, 1, 1, 1, 6 } }
local nAbilityBuildList = Fu.Skill.GetRandomBuild(tAllAbilityBuildList)
local nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList)
local sRoleItemsBuyList = {}
-- Stratz 7.41f, week of 9 Nov 2026: pos 1, 73,180 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_1"] = {
	"item_tango",
	"item_quelling_blade",
	"item_double_branches",
	"item_magic_stick",
	"item_bracer",
	"item_magic_wand",
	"item_phase_boots",
	"item_radiance",
	"item_blink",
	"item_aghanims_shard",
	"item_buckler",
	"item_black_king_bar",
	"item_assault",
	"item_ultimate_scepter",
	"item_swift_blink",
	"item_ultimate_scepter_2",
	"item_harpoon",
	"item_moon_shard",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 3, 186,064 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_3"] = {
	"item_tango",
	"item_quelling_blade",
	"item_double_branches",
	"item_gauntlets",
	"item_circlet",
	"item_bracer",
	"item_magic_wand",
	"item_phase_boots",
	"item_radiance",
	"item_blink",
	"item_aghanims_shard",
	"item_black_king_bar",
	"item_assault",
	"item_sange",
	"item_ultimate_scepter_2",
	"item_overwhelming_blink",
	"item_moon_shard",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 2, 6,184 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_2"] = {
	"item_tango",
	"item_quelling_blade",
	"item_double_branches",
	"item_gauntlets",
	"item_circlet",
	"item_magic_wand",
	"item_bracer",
	"item_phase_boots",
	"item_radiance",
	"item_blink",
	"item_desolator",
	"item_aghanims_shard",
	"item_black_king_bar",
	"item_ultimate_scepter",
	"item_ultimate_scepter_2",
	"item_abyssal_blade",
	"item_swift_blink",
	"item_moon_shard",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 4, 4,103 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_4"] = {
	"item_tango",
	"item_quelling_blade",
	"item_branches",
	"item_magic_stick",
	"item_gauntlets",
	"item_bracer",
	"item_magic_wand",
	"item_phase_boots",
	"item_radiance",
	"item_blink",
	"item_aghanims_shard",
	"item_buckler",
	"item_ultimate_scepter",
	"item_assault",
	"item_ultimate_scepter_2",
	"item_sange",
	"item_armlet",
	"item_overwhelming_blink",
	"item_moon_shard",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 5, 1,765 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_5"] = {
	"item_tango",
	"item_branches",
	"item_quelling_blade",
	"item_magic_stick",
	"item_gauntlets",
	"item_bracer",
	"item_magic_wand",
	"item_phase_boots",
	"item_blink",
	"item_aghanims_shard",
	"item_buckler",
	"item_ultimate_scepter",
	"item_black_king_bar",
	"item_assault",
	"item_ultimate_scepter_2",
	"item_echo_sabre",
	"item_sange",
	"item_harpoon",
	"item_moon_shard",
}
X["sBuyList"] = sRoleItemsBuyList[sRole]
X["sSellList"] = { "item_black_king_bar", "item_quelling_blade" }
if Fu.Role.IsPvNMode() or Fu.Role.IsAllShadow() then
	X["sBuyList"], X["sSellList"] = { "PvN_tank" }, { "item_heavens_halberd", "item_quelling_blade" }
end
nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"] =
	Fu.SetUserHeroInit(nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"])
X["sSkillList"] = Fu.Skill.GetSkillList(sAbilityList, nAbilityBuildList, sTalentList, nTalentBuildList)
X["bDeafaultAbility"] = true
X["bDeafaultItem"] = false
function X.MinionThink(minionUnit)
	if Minion.IsValidUnit(minionUnit) and minionUnit:GetUnitName() ~= "npc_dota_wraith_king_skeleton_warrior" then
		Minion.IllusionThink(minionUnit)
	end
end
local hellfireBlastAbility =
	SafeAbility(bot:GetAbilityByName("skeleton_king_hellfire_blast"), "skeleton_king_hellfire_blast", "skeleton_king")
-- datafeed: skeleton_king_spectral_blade no longer exists; W is skeleton_king_bone_guard. The old
-- fallback below never ran (the safe proxy's IsHidden() returns false), so ConsiderW could not cast it.
local boneGuardAbility =
	SafeAbility(bot:GetAbilityByName("skeleton_king_bone_guard"), "skeleton_king_bone_guard", "skeleton_king")
local mortalStrikeAbility =
	SafeAbility(bot:GetAbilityByName("skeleton_king_mortal_strike"), "skeleton_king_mortal_strike", "skeleton_king")
local reincarnationAbility =
	SafeAbility(bot:GetAbilityByName("skeleton_king_reincarnation"), "skeleton_king_reincarnation", "skeleton_king")
local talent5 = SafeAbility(bot:GetAbilityByName(sTalentList[5]), "sTalentList[5]", "skeleton_king")
local talent6 = SafeAbility(bot:GetAbilityByName(sTalentList[6]), "sTalentList[6]", "skeleton_king")
local hellfireBlastDesire, hellfireBlastTarget
local boneGuardDesire
local mortalStrikeDesire
local mpRatio, hpRatio, botLevel, nearbyEnemies
function X.SkillsComplement()
	if Fu.CanNotUseAbility(bot) or bot:IsInvisible() then
		return
	end
	if not boneGuardAbility or boneGuardAbility:IsHidden() then
		boneGuardAbility =
			SafeAbility(bot:GetAbilityByName("skeleton_king_bone_guard"), "skeleton_king_bone_guard", "skeleton_king")
	end
	local abilityContext = AbilityContext.Build(bot)
	botLevel = abilityContext.level
	mpRatio = abilityContext.mp
	hpRatio = abilityContext.hp
	nearbyEnemies = abilityContext.enemies
	hellfireBlastDesire, hellfireBlastTarget = X.ConsiderQ()
	if hellfireBlastDesire > 0 then
		Fu.SetQueuePtToINT(bot, false)
		bot:ActionQueue_UseAbilityOnEntity(hellfireBlastAbility, hellfireBlastTarget)
		return
	end
	boneGuardDesire = X.ConsiderW()
	if boneGuardDesire > 0 then
		Fu.SetQueuePtToINT(bot, false)
		bot:ActionQueue_UseAbility(boneGuardAbility)
		return
	end
end
function X.ConsiderQ()
	if not hellfireBlastAbility:IsFullyCastable() or X.ShouldSaveMana(hellfireBlastAbility) then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local castRange = hellfireBlastAbility:GetCastRange()
	local castPoint = hellfireBlastAbility:GetCastPoint()
	local manaCost = hellfireBlastAbility:GetManaCost()
	local abilityLevel = hellfireBlastAbility:GetLevel()
	local damage = 40 * (abilityLevel - 1) + 100
	local damageType = DAMAGE_TYPE_MAGICAL
	local nearbyAllies = Fu.GetNearbyHeroes(bot, 1200, false, BOT_MODE_NONE)
	local enemyHeroes = Fu.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE)
	if
		#enemyHeroes == 1
		and Fu.IsValidHero(enemyHeroes[1])
		and Fu.IsInRange(enemyHeroes[1], bot, castRange + 350)
		and enemyHeroes[1]:IsFacingLocation(bot:GetLocation(), 30)
		and enemyHeroes[1]:GetAttackRange() > castRange
		and enemyHeroes[1]:GetAttackRange() < 1250
	then
		castRange = castRange + 260
	end
	local enemiesInCastRange = Fu.GetNearbyHeroes(bot, castRange + 43, true, BOT_MODE_NONE)
	local enemiesInWideRange = Fu.GetNearbyHeroes(bot, castRange + 330, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(enemiesInWideRange) do
		if
			Fu.IsValid(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and Fu.CanCastOnTargetAdvanced(enemyHero)
		then
			if enemyHero:IsChanneling() then
				return BOT_ACTION_DESIRE_HIGH, enemyHero
			end
			if
				GetUnitToUnitDistance(bot, enemyHero) <= castRange + 80
				and Fu.CanKillTarget(enemyHero, damage * 1.68, damageType)
			then
				return BOT_ACTION_DESIRE_HIGH, enemyHero
			end
		end
	end
	if Fu.IsInTeamFight(bot, 1200) then
		local bestTarget = nil
		local highestDamage = 0
		for _, enemyHero in pairs(enemiesInCastRange) do
			if
				Fu.IsValid(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
				and not Fu.IsDisabled(enemyHero)
				and not enemyHero:IsDisarmed()
			then
				local estimatedDamage = enemyHero:GetEstimatedDamageToTarget(false, bot, 3.0, DAMAGE_TYPE_PHYSICAL)
				if estimatedDamage > highestDamage then
					highestDamage = estimatedDamage
					bestTarget = enemyHero
				end
			end
		end
		if bestTarget ~= nil then
			return BOT_ACTION_DESIRE_HIGH, bestTarget
		end
	end
	if bot:GetActiveMode() == BOT_MODE_LANING or botLevel <= 5 then
		for _, enemyHero in pairs(enemiesInWideRange) do
			if
				Fu.IsValid(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
				and not Fu.IsDisabled(enemyHero)
				and Fu.GetAttackEnemysAllyCreepCount(enemyHero, 1400) >= 4
			then
				return BOT_ACTION_DESIRE_HIGH, enemyHero
			end
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		local botTarget = Fu.GetProperTarget(bot)
		if
			Fu.IsValidHero(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.CanCastOnTargetAdvanced(botTarget)
			and Fu.IsInRange(botTarget, bot, castRange + 80)
			and not Fu.IsDisabled(botTarget)
			and not botTarget:IsDisarmed()
		then
			if abilityLevel >= 3 or mpRatio > 0.68 or Fu.GetHP(botTarget) < 0.38 or hpRatio < 0.25 then
				return BOT_ACTION_DESIRE_HIGH, botTarget
			end
		end
	end
	if Fu.IsRetreating(bot) then
		for _, enemyHero in pairs(enemiesInCastRange) do
			if
				Fu.IsValid(enemyHero)
				and (bot:WasRecentlyDamagedByHero(enemyHero, 5.0) or mpRatio > 0.8 or GetUnitToUnitDistance(
					bot,
					enemyHero
				) <= 400)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
				and not Fu.IsDisabled(enemyHero)
				and not enemyHero:IsDisarmed()
			then
				return BOT_ACTION_DESIRE_HIGH, enemyHero
			end
		end
	end
	if
		Fu.IsFarming(bot)
		and abilityLevel >= 3
		and (bot:GetAttackDamage() < 200 or mpRatio > 0.88)
		and mpRatio > 0.71
		and #nearbyEnemies == 0
	then
		local neutralCreeps = bot:GetNearbyNeutralCreeps(castRange + 100)
		local strongestCreep = Fu.GetMostHpUnit(neutralCreeps)
		if
			Fu.IsValid(strongestCreep)
			and bot:IsFacingLocation(strongestCreep:GetLocation(), 46)
			and (#neutralCreeps >= 2 or GetUnitToUnitDistance(strongestCreep, bot) <= 400)
			and not Fu.IsRoshan(strongestCreep)
			and not Fu.IsOtherAllysTarget(strongestCreep)
			and strongestCreep:GetMagicResist() < 0.3
			and not Fu.CanKillTarget(strongestCreep, bot:GetAttackDamage() * 1.68, DAMAGE_TYPE_PHYSICAL)
			and not Fu.CanKillTarget(strongestCreep, damage, damageType)
		then
			return BOT_ACTION_DESIRE_HIGH, strongestCreep
		end
	end
	if bot:GetActiveMode() == BOT_MODE_ROSHAN and bot:GetMana() >= 600 then
		local attackTarget = bot:GetAttackTarget()
		if
			Fu.IsRoshan(attackTarget)
			and not Fu.IsDisabled(attackTarget)
			and not attackTarget:IsDisarmed()
			and Fu.IsInRange(attackTarget, bot, castRange)
		then
			return BOT_ACTION_DESIRE_HIGH, attackTarget
		end
	end
	if
		bot:WasRecentlyDamagedByAnyHero(3.0)
		and bot:GetActiveMode() ~= BOT_MODE_RETREAT
		and not bot:IsInvisible()
		and #enemiesInCastRange >= 1
		and botLevel >= 6
	then
		for _, enemyHero in pairs(enemiesInCastRange) do
			if
				Fu.IsValid(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
				and not Fu.IsDisabled(enemyHero)
				and not enemyHero:IsDisarmed()
				and bot:IsFacingLocation(enemyHero:GetLocation(), 45)
			then
				return BOT_ACTION_DESIRE_HIGH, enemyHero
			end
		end
	end
	if
		(#enemyHeroes > 0 or bot:WasRecentlyDamagedByAnyHero(3.0))
		and (bot:GetActiveMode() ~= BOT_MODE_RETREAT or #nearbyAllies >= 2)
		and #enemiesInCastRange >= 1
		and botLevel >= 7
	then
		for _, enemyHero in pairs(enemiesInCastRange) do
			if
				Fu.IsValid(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
				and not Fu.IsDisabled(enemyHero)
			then
				return BOT_ACTION_DESIRE_HIGH, enemyHero
			end
		end
	end
	return 0
end
function X.ConsiderW()
	if
		not boneGuardAbility:IsFullyCastable()
		or not bot:HasModifier("modifier_skeleton_king_bone_guard")
		or X.ShouldSaveMana(boneGuardAbility)
		or boneGuardAbility:GetName() ~= "skeleton_king_bone_guard"
	then
		return 0
	end
	local skeletonCharges = 0
	local boneGuardModifier = bot:GetModifierByName("modifier_skeleton_king_bone_guard")
	if boneGuardModifier > -1 then
		skeletonCharges = bot:GetModifierStackCount(boneGuardModifier)
	end
	local maxCharges = boneGuardAbility:GetSpecialValueInt("max_skeleton_charges")
	local enemyHeroes = Fu.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE)
	local botTarget = Fu.GetProperTarget(bot)
	if
		Fu.IsValidHero(botTarget)
		and #enemyHeroes == 1
		and Fu.IsInRange(botTarget, bot, 650)
		and (skeletonCharges / maxCharges >= 0.6 or talent6:IsTrained())
	then
		return BOT_ACTION_DESIRE_HIGH
	end
	-- Review fix: the fight case above needs exactly one enemy hero within 1600, so in a real
	-- teamfight (2+ enemies) Bone Guard was never cast and the stored skeletons were wasted.
	-- Spend them when fighting a hero target in range, whatever the enemy count.
	if
		(Fu.IsGoingOnSomeone(bot) or Fu.IsInTeamFight(bot, 1200))
		and Fu.IsValidHero(botTarget)
		and Fu.IsInRange(botTarget, bot, 700)
		and (skeletonCharges >= 2 or talent6:IsTrained())
	then
		if DotaTime() - (X.lastBoneGuardLog or -99) > 10 then
			X.lastBoneGuardLog = DotaTime()
			pcall(
				print,
				string.format(
					"[OHA-WK] t=%.0f bone-guard fight charges=%d enemies=%d",
					DotaTime(),
					skeletonCharges,
					#enemyHeroes
				)
			)
		end
		return BOT_ACTION_DESIRE_HIGH
	end
	if
		(skeletonCharges == maxCharges or talent6:IsTrained())
		and botLevel >= 4
		and (X.IsNearLaneFront(bot) or Fu.IsFarming(bot))
	then
		return BOT_ACTION_DESIRE_HIGH
	end
	return 0
end
function X.IsNearLaneFront(unit)
	local nearDistance = 600
	local lanes = { LANE_TOP, LANE_MID, LANE_BOT }
	for _, lane in pairs(lanes) do
		local laneFrontLocation = GetLaneFrontLocation(GetTeam(), lane, 0)
		if GetUnitToLocationDistance(unit, laneFrontLocation) <= nearDistance then
			return true
		end
	end
	return false
end
function X.ShouldSaveMana(ability)
	if
		botLevel >= 6
		and ability ~= nil
		and reincarnationAbility ~= nil
		and reincarnationAbility:GetCooldownTimeRemaining() <= 3.0
		and bot:GetMana() - ability:GetManaCost() < reincarnationAbility:GetManaCost()
	then
		return true
	end
	return false
end
return X
