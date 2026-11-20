-- Bloodseeker: skill build, item build, and ability use for this hero.
local X = {}
local bot = GetBot()
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local AbilityContext = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local Minion = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local sTalentList = Fu.Skill.GetTalentList(bot)
local sAbilityList = Fu.Skill.GetAbilityList(bot)
local sRole = Fu.Item.GetRoleItemsBuyList(bot)
local tTalentTreeList = {
	{ ["t25"] = { 0, 10 }, ["t20"] = { 0, 10 }, ["t15"] = { 0, 10 }, ["t10"] = { 0, 10 } },
	{ ["t25"] = { 0, 10 }, ["t20"] = { 0, 10 }, ["t15"] = { 0, 10 }, ["t10"] = { 0, 10 } },
}
local tAllAbilityBuildList =
	{ { 2, 3, 2, 1, 2, 6, 2, 1, 1, 1, 6, 3, 3, 3, 6 }, { 2, 3, 2, 1, 2, 6, 2, 1, 1, 1, 6, 3, 3, 3, 6 } }
local nAbilityBuildList = tAllAbilityBuildList[2]
if sRole == "pos_1" then
	nAbilityBuildList = tAllAbilityBuildList[1]
end
if sRole == "pos_2" then
	nAbilityBuildList = tAllAbilityBuildList[1]
end
if sRole == "pos_3" then
	nAbilityBuildList = tAllAbilityBuildList[2]
end
local nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList[2])
if sRole == "pos_1" then
	nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList[1])
end
if sRole == "pos_2" then
	nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList[1])
end
if sRole == "pos_3" then
	nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList[2])
end
local sUtility = "item_team_aura"
local sRoleItemsBuyList = {}
-- Stratz 7.41f, week of 9 Nov 2026: pos 1, 41,346 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_1"] = {
	"item_tango",
	"item_quelling_blade",
	"item_branches",
	"item_circlet",
	"item_magic_stick",
	"item_wraith_band",
	"item_magic_wand",
	"item_phase_boots",
	"item_mjollnir",
	"item_black_king_bar",
	"item_sange",
	"item_basher",
	"item_aghanims_shard",
	"item_butterfly",
	"item_abyssal_blade",
	"item_travel_boots",
	"item_ultimate_scepter_2",
	"item_moon_shard",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 2, 11,964 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_2"] = {
	"item_tango",
	"item_quelling_blade",
	"item_double_branches",
	"item_circlet",
	"item_slippers",
	"item_wraith_band",
	"item_magic_wand",
	"item_phase_boots",
	"item_blade_mail",
	"item_black_king_bar",
	"item_basher",
	"item_sange",
	"item_ultimate_scepter",
	"item_aghanims_shard",
	"item_abyssal_blade",
	"item_ultimate_scepter_2",
	"item_moon_shard",
	"item_skadi",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 3, 9,596 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_3"] = {
	"item_tango",
	"item_quelling_blade",
	"item_double_branches",
	"item_circlet",
	"item_wraith_band",
	"item_magic_wand",
	"item_phase_boots",
	"item_blade_mail",
	"item_black_king_bar",
	"item_basher",
	"item_ultimate_scepter",
	sUtility,
	"item_aghanims_shard",
	"item_abyssal_blade",
	"item_travel_boots",
	"item_ultimate_scepter_2",
	"item_monkey_king_bar",
	"item_moon_shard",
	"item_travel_boots_2",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 4, 1,748 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_4"] = {
	"item_tango",
	"item_branches",
	"item_magic_stick",
	"item_quelling_blade",
	"item_circlet",
	"item_magic_wand",
	"item_phase_boots",
	"item_blade_mail",
	"item_basher",
	"item_ultimate_scepter",
	"item_black_king_bar",
	sUtility,
	"item_abyssal_blade",
	"item_ultimate_scepter_2",
	"item_rod_of_atos",
	"item_aghanims_shard",
	"item_moon_shard",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 5, 1,114 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_5"] = {
	"item_tango",
	"item_branches",
	"item_quelling_blade",
	"item_circlet",
	"item_magic_stick",
	"item_magic_wand",
	"item_phase_boots",
	"item_maelstrom",
	"item_basher",
	"item_black_king_bar",
	sUtility,
	"item_aghanims_shard",
	"item_abyssal_blade",
	"item_butterfly",
	"item_moon_shard",
	"item_ultimate_scepter_2",
}
X["sBuyList"] = sRoleItemsBuyList[sRole]
X["sSellList"] = { "item_power_treads", "item_quelling_blade", "item_abyssal_blade", "item_magic_wand" }
if Fu.Role.IsPvNMode() or Fu.Role.IsAllShadow() then
	X["sBuyList"], X["sSellList"] = { "PvN_melee_carry" }, { "item_power_treads", "item_quelling_blade" }
end
nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"] =
	Fu.SetUserHeroInit(nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"])
X["sSkillList"] = Fu.Skill.GetSkillList(sAbilityList, nAbilityBuildList, sTalentList, nTalentBuildList)
X["bDeafaultAbility"] = false
X["bDeafaultItem"] = false
function X.MinionThink(hMinionUnit)
	Minion.MinionThink(hMinionUnit)
end
local bloodrageAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[1]), "sAbilityList[1]", "bloodseeker")
local bloodRiteAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[2]), "sAbilityList[2]", "bloodseeker")
local ruptureAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[6]), "sAbilityList[6]", "bloodseeker")
local thirstAbility = SafeAbility(bot:GetAbilityByName("bloodseeker_thirst"), "bloodseeker_thirst", "bloodseeker")
local bloodrageDesire = 0
local bloodRiteDesire, bloodRiteLocation = 0
local ruptureDesire, ruptureTarget = 0
local thirstDesire
local botTarget
local isAttacking
function X.SkillsComplement()
	if Fu.CanNotUseAbility(bot) or bot:IsInvisible() then
		return
	end
	isAttacking = Fu.IsAttacking(bot)
	local context = AbilityContext.Build(bot)
	botTarget = context.target
	thirstDesire = X.ConsiderThirst()
	if thirstDesire > 0 then
		Fu.SetQueuePtToINT(bot, false)
		bot:ActionQueue_UseAbility(thirstAbility)
		return
	end
	ruptureDesire, ruptureTarget = X.ConsiderR()
	if ruptureDesire > 0 then
		Fu.SetQueuePtToINT(bot, false)
		bot:ActionQueue_UseAbilityOnEntity(ruptureAbility, ruptureTarget)
		return
	end
	bloodrageDesire = X.ConsiderQ()
	if bloodrageDesire > 0 then
		bot:Action_ClearActions(false)
		bot:ActionQueue_UseAbility(bloodrageAbility)
		return
	end
	bloodRiteDesire, bloodRiteLocation = X.ConsiderW()
	if bloodRiteDesire > 0 then
		Fu.SetQueuePtToINT(bot, false)
		bot:ActionQueue_UseAbilityOnLocation(bloodRiteAbility, bloodRiteLocation)
		return
	end
end
function X.ConsiderThirst()
	if not Fu.CanCastAbility(thirstAbility) then
		return BOT_MODE_NONE
	end
	if Fu.IsGoingOnSomeone(bot) then
		if Fu.IsValidHero(botTarget) and Fu.CanCastOnMagicImmune(botTarget) and Fu.IsInRange(botTarget, bot, 600) then
			if not bot:HasModifier("modifier_bloodseeker_thirst") then
				return BOT_ACTION_DESIRE_HIGH, bot
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.ConsiderQ()
	if not bloodrageAbility:IsFullyCastable() then
		return 0
	end
	if bot:HasModifier("modifier_bloodseeker_bloodrage") then
		return 0
	end
	local attackDamage = bot:GetAttackDamage()
	if Fu.IsInTeamFight(bot, 1200) or Fu.IsPushing(bot) or Fu.IsDefending(bot) then
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE)
		if #nearbyEnemies >= 1 then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if Fu.IsValidHero(botTarget) and Fu.CanCastOnMagicImmune(botTarget) and Fu.IsInRange(botTarget, bot, 600) then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsValid(botTarget) and botTarget:GetTeam() == TEAM_NEUTRAL then
		local nearbyCreeps = bot:GetNearbyCreeps(1000, true)
		for _, creep in pairs(nearbyCreeps) do
			if Fu.IsValid(creep) and not Fu.CanKillTarget(creep, attackDamage, DAMAGE_TYPE_PHYSICAL) then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if Fu.IsRoshan(botTarget) and Fu.IsInRange(bot, botTarget, bot:GetAttackRange()) and isAttacking then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, bot:GetAttackRange()) and isAttacking then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderW()
	if not bloodRiteAbility:IsFullyCastable() then
		return 0
	end
	local radius = 600
	local castRange = bloodRiteAbility:GetCastRange()
	local castPoint = bloodRiteAbility:GetCastPoint()
	local delay = bloodRiteAbility:GetSpecialValueFloat("delay")
	local manaCost = bloodRiteAbility:GetManaCost()
	local damage = bloodRiteAbility:GetSpecialValueInt("damage")
	local nearbyEnemies = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	local nearbyAllies = Fu.GetNearbyHeroes(bot, 800, false, BOT_MODE_NONE)
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValid(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and Fu.CanKillTarget(enemyHero, damage, DAMAGE_TYPE_PURE)
		then
			if enemyHero:GetMovementDirectionStability() >= 0.75 then
				return BOT_ACTION_DESIRE_HIGH, enemyHero:GetExtrapolatedLocation(delay)
			else
				return BOT_ACTION_DESIRE_HIGH, enemyHero:GetLocation()
			end
		end
	end
	if bot:GetActiveMode() == BOT_MODE_LANING and Fu.IsAllowedToSpam(bot, manaCost) then
		local aoeLocation = bot:FindAoELocation(true, false, bot:GetLocation(), 1000, radius / 2, castPoint, damage)
		if aoeLocation.count >= 4 then
			return BOT_ACTION_DESIRE_MODERATE, aoeLocation.targetloc
		end
	end
	-- Parenthesised: without them "or" let this fire with no push/defend at all whenever no enemy hero was near.
	if
		(Fu.IsPushing(bot) or Fu.IsDefending(bot))
		and Fu.IsAllowedToSpam(bot, manaCost)
		and (nearbyEnemies == nil or #nearbyEnemies == 0)
		and #nearbyAllies <= 2
	then
		local nearbyLaneCreeps = bot:GetNearbyLaneCreeps(1000, true)
		local aoeLocation = bot:FindAoELocation(true, false, bot:GetLocation(), 1000, radius / 2, castPoint, damage)
		if aoeLocation.count >= 4 and #nearbyLaneCreeps >= 4 then
			return BOT_ACTION_DESIRE_MODERATE, aoeLocation.targetloc
		end
	end
	if Fu.IsRetreating(bot) then
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValid(enemyHero)
				and bot:WasRecentlyDamagedByHero(enemyHero, 1.0)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
			then
				return BOT_ACTION_DESIRE_HIGH, bot:GetLocation()
			end
		end
	end
	if Fu.IsInTeamFight(bot, 1200) then
		local aoeLocation =
			bot:FindAoELocation(true, true, bot:GetLocation(), castRange - 200, radius / 2, castPoint, 0)
		if aoeLocation.count >= 2 then
			local castableEnemyCount = Fu.GetInvUnitInLocCount(bot, castRange, radius / 2, aoeLocation.targetloc, false)
			if castableEnemyCount >= aoeLocation.count then
				return BOT_ACTION_DESIRE_MODERATE, aoeLocation.targetloc
			end
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidHero(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(botTarget, bot, castRange + radius)
		then
			local castLocation = Fu.GetDelayCastLocation(bot, botTarget, castRange, radius, 2.0)
			if castLocation ~= nil then
				return BOT_ACTION_DESIRE_HIGH, castLocation
			end
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if Fu.IsRoshan(botTarget) and Fu.IsInRange(bot, botTarget, castRange) and isAttacking then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, castRange) and isAttacking then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.ConsiderR()
	if not ruptureAbility:IsFullyCastable() then
		return 0
	end
	local castRange = ruptureAbility:GetCastRange()
	local castPoint = ruptureAbility:GetCastPoint()
	local manaCost = ruptureAbility:GetManaCost()
	local nearbyEnemies = Fu.GetNearbyHeroes(bot, castRange + 200, true, BOT_MODE_NONE)
	-- fix: Rupture has DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES / SPELL_IMMUNITY_ENEMIES_YES (game data),
	-- so the three target checks below now accept BKB heroes (was CanCastOnNonMagicImmune).
	if Fu.IsRetreating(bot) then
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				bot:WasRecentlyDamagedByHero(enemyHero, 1.0)
				and Fu.CanCastOnMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
				and not enemyHero:HasModifier("modifier_bloodseeker_bloodrage")
				and not enemyHero:HasModifier("modifier_bloodseeker_rupture")
			then
				return BOT_ACTION_DESIRE_MODERATE, enemyHero
			end
		end
	end
	if Fu.IsInTeamFight(bot, 1200) then
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.CanCastOnMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
				and Fu.Role.IsCarry(enemyHero:GetUnitName())
				and not enemyHero:HasModifier("modifier_bloodseeker_bloodrage")
				and not enemyHero:HasModifier("modifier_bloodseeker_rupture")
				and not Fu.IsDisabled(enemyHero)
			then
				return BOT_ACTION_DESIRE_HIGH, enemyHero
			end
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidHero(botTarget)
			and Fu.CanCastOnMagicImmune(botTarget)
			and Fu.CanCastOnTargetAdvanced(botTarget)
			and Fu.IsInRange(botTarget, bot, castRange + 100)
			and not botTarget:HasModifier("modifier_bloodseeker_bloodrage")
			and not botTarget:HasModifier("modifier_bloodseeker_rupture")
			and not Fu.IsDisabled(botTarget)
		then
			local alliesNearTarget = Fu.GetNearbyHeroes(botTarget, 1200, true, BOT_MODE_NONE)
			if alliesNearTarget ~= nil and #alliesNearTarget >= 2 then
				return BOT_ACTION_DESIRE_HIGH, botTarget
			end
			-- fix: a0 counts Bloodseeker himself, so ">= 2" meant a solo gank never ruptured. Alone,
			-- rupture a target already below half HP (it cannot run without bleeding).
			if Fu.GetHP(botTarget) < 0.5 and not Fu.IsSuspiciousIllusion(botTarget) then
				if DotaTime() >= (bot._bsRuptureLogAt or -999) then
					bot._bsRuptureLogAt = DotaTime() + 10
					pcall(
						print,
						string.format(
							"[OHA-BLOODSEEKER] t=%.0f rupture solo %s hp=%.2f",
							DotaTime(),
							(string.gsub(botTarget:GetUnitName(), "npc_dota_hero_", "")),
							Fu.GetHP(botTarget)
						)
					)
				end
				return BOT_ACTION_DESIRE_HIGH, botTarget
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
return X
