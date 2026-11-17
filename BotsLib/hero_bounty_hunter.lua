-- Bounty Hunter: skill build, item build, and ability use for this hero.
local X = {}
local bot = GetBot()
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local AbilityContext = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local Minion = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local sTalentList = Fu.Skill.GetTalentList(bot)
local sAbilityList = Fu.Skill.GetAbilityList(bot)
local sRole = Fu.Item.GetRoleItemsBuyList(bot)
local tTalentTreeList = {
	{ ["t25"] = { 10, 0 }, ["t20"] = { 10, 0 }, ["t15"] = { 0, 10 }, ["t10"] = { 10, 0 } },
	{ ["t25"] = { 10, 0 }, ["t20"] = { 10, 0 }, ["t15"] = { 10, 0 }, ["t10"] = { 10, 0 } },
}
local tAllAbilityBuildList = { { 2, 3, 2, 1, 2, 6, 2, 1, 1, 1, 6, 3, 3, 3, 6 }, { 3, 2, 1, 1, 1, 6, 1, 3, 3, 3, 6, 2, 2, 2, 6 } }
local nAbilityBuildList
local nTalentBuildList
if sRole == "pos_2" then
	nAbilityBuildList = tAllAbilityBuildList[1]
	nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList[1])
else
	nAbilityBuildList = tAllAbilityBuildList[2]
	nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList[2])
end
local sUtility = RandomInt(1, 2) == 1 and "item_crimson_guard" or "item_heavens_halberd"
local sRoleItemsBuyList = {}
sRoleItemsBuyList["pos_1"] = {
	"item_double_branches",
	"item_quelling_blade",
	"item_tango",
	"item_faerie_fire",
	"item_magic_wand",
	"item_phase_boots",
	"item_phylactery",
	"item_ultimate_scepter",
	"item_octarine_core",
	"item_black_king_bar",
	"item_angels_demise",
	"item_assault",
	"item_travel_boots",
	"item_monkey_king_bar",
	"item_ultimate_scepter_2",
	"item_travel_boots_2",
	"item_moon_shard",
	"item_aghanims_shard",
}
sRoleItemsBuyList["pos_2"] = {
	"item_double_branches",
	"item_quelling_blade",
	"item_tango",
	"item_faerie_fire",
	"item_bottle",
	"item_phase_boots",
	"item_magic_wand",
	"item_phylactery",
	"item_ultimate_scepter",
	"item_octarine_core",
	"item_black_king_bar",
	"item_angels_demise",
	"item_assault",
	"item_travel_boots",
	"item_moon_shard",
	"item_monkey_king_bar",
	"item_ultimate_scepter_2",
	"item_travel_boots_2",
	"item_aghanims_shard",
}
sRoleItemsBuyList["pos_3"] = {
	"item_double_branches",
	"item_quelling_blade",
	"item_tango",
	"item_faerie_fire",
	"item_magic_wand",
	"item_boots",
	"item_phase_boots",
	"item_phylactery",
	"item_pipe",
	"item_black_king_bar",
	sUtility,
	"item_angels_demise",
	"item_assault",
	"item_travel_boots",
	"item_monkey_king_bar",
	"item_ultimate_scepter_2",
	"item_travel_boots_2",
	"item_moon_shard",
	"item_aghanims_shard",
}
sRoleItemsBuyList["pos_4"] = {
	"item_tango",
	"item_double_branches",
	"item_blood_grenade",
	"item_orb_of_frost",
	"item_magic_wand",
	"item_boots",
	"item_tranquil_boots",
	"item_ancient_janggo",
	"item_boots_of_bearing",
	"item_spirit_vessel",
	"item_aghanims_shard",
	"item_cyclone",
	"item_ultimate_scepter",
	"item_lotus_orb",
	"item_sheepstick",
	"item_moon_shard",
	"item_ultimate_scepter_2",
}
sRoleItemsBuyList["pos_5"] = {
	"item_tango",
	"item_double_branches",
	"item_blood_grenade",
	"item_orb_of_frost",
	"item_magic_wand",
	"item_boots",
	"item_tranquil_boots",
	"item_ancient_janggo",
	"item_pipe",
	"item_spirit_vessel",
	"item_boots_of_bearing",
	"item_cyclone",
	"item_sheepstick",
	"item_moon_shard",
	"item_lotus_orb",
	"item_aghanims_shard",
	"item_ultimate_scepter_2",
}
X["sBuyList"] = sRoleItemsBuyList[sRole]
X["sSellList"] = {
	"item_power_treads",
	"item_quelling_blade",
	"item_heavens_halberd",
	"item_quelling_blade",
	"item_abyssal_blade",
	"item_magic_wand",
	"item_assault",
	"item_ancient_janggo",
}
if Fu.Role.IsPvNMode() then
	X["sBuyList"], X["sSellList"] = { "PvN_BH" }, { "item_power_treads", "item_quelling_blade" }
end
nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"] = Fu.SetUserHeroInit(nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"])
X["sSkillList"] = Fu.Skill.GetSkillList(sAbilityList, nAbilityBuildList, sTalentList, nTalentBuildList)
X["bDeafaultAbility"] = false
X["bDeafaultItem"] = false
function X.MinionThink(minionUnit)
	Minion.MinionThink(minionUnit)
end
local shurikenTossAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[1]), "sAbilityList[1]", "bounty_hunter")
local jinadaAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[2]), "sAbilityList[2]", "bounty_hunter")
local shadowWalkAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[3]), "sAbilityList[3]", "bounty_hunter")
local friendlyShadowAbility =
	SafeAbility(bot:GetAbilityByName("bounty_hunter_wind_walk_ally"), "bounty_hunter_wind_walk_ally", "bounty_hunter")
local trackAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[6]), "sAbilityList[6]", "bounty_hunter")
local talent3 = SafeAbility(bot:GetAbilityByName(sTalentList[3]), "sTalentList[3]", "bounty_hunter")
local shurikenTossDesire, shurikenTossTarget
local shadowWalkDesire
local friendlyShadowDesire, friendlyShadowTarget
local trackDesire, trackTarget
local aetherRange = 0
local bonusShurikenDamage = 0
local botLevel, mpRatio, hpRatio, nearbyEnemies, nearbyAllies
function X.SkillsComplement()
	if Fu.CanNotUseAbility(bot) then
		return
	end
	local abilityContext = AbilityContext.Build(bot)
	aetherRange = abilityContext.aetherRange
	botLevel = abilityContext.level
	mpRatio = abilityContext.mp
	hpRatio = abilityContext.hp
	botTarget = abilityContext.target
	nearbyEnemies = abilityContext.enemies
	nearbyAllies = abilityContext.allies
	if talent3:IsTrained() then
		bonusShurikenDamage = talent3:GetSpecialValueInt("value")
	end
	shadowWalkDesire = X.ConsiderE()
	if shadowWalkDesire > 0 then
		Fu.SetQueuePtToINT(bot, false)
		bot:ActionQueue_UseAbility(shadowWalkAbility)
		return
	end
	friendlyShadowDesire, friendlyShadowTarget = X.ConsiderFriendlyShadow()
	if friendlyShadowDesire > 0 then
		Fu.SetQueuePtToINT(bot, false)
		bot:ActionQueue_UseAbilityOnEntity(friendlyShadowAbility, friendlyShadowTarget)
		return
	end
	trackDesire, trackTarget = X.ConsiderR()
	if trackDesire > 0 then
		Fu.SetQueuePtToINT(bot, true)
		bot:ActionQueue_UseAbilityOnEntity(trackAbility, trackTarget)
		return
	end
	shurikenTossDesire, shurikenTossTarget = X.ConsiderQ()
	if shurikenTossDesire > 0 then
		Fu.SetQueuePtToINT(bot, true)
		bot:ActionQueue_UseAbilityOnEntity(shurikenTossAbility, shurikenTossTarget)
		return
	end
end
function X.ConsiderQ()
	if not shurikenTossAbility:IsFullyCastable() then
		return 0
	end
	local abilityLevel = shurikenTossAbility:GetLevel()
	local castRange = shurikenTossAbility:GetCastRange() + aetherRange
	local castPoint = shurikenTossAbility:GetCastPoint()
	local manaCost = shurikenTossAbility:GetManaCost()
	local damage = shurikenTossAbility:GetSpecialValueInt("bonus_damage") + bonusShurikenDamage
	local damageType = DAMAGE_TYPE_MAGICAL
	local enemiesInRange = Fu.GetAroundEnemyHeroList(castRange)
	local castTarget = nil
	local bounceRadius = shurikenTossAbility:GetSpecialValueInt("bounce_aoe")
	local nearbyUnits = Fu.GetAroundBotUnitList(bot, castRange + 100, true)
	local trackedEnemies = {}
	for _, enemyHero in pairs(nearbyEnemies) do
		if enemyHero:HasModifier("modifier_bounty_hunter_track") then
			trackedEnemies[#trackedEnemies + 1] = enemyHero
		end
		if enemyHero:IsChanneling() and not enemyHero:IsMagicImmune() then
			if enemyHero:HasModifier("modifier_bounty_hunter_track") then
				for _, unit in pairs(nearbyUnits) do
					if Fu.IsValid(unit) and Fu.CanCastOnTargetAdvanced(unit) and not unit:IsMagicImmune() then
						castTarget = unit
						return BOT_ACTION_DESIRE_HIGH, castTarget, "Q-通过弹射打断施法:" .. Fu.Chat.GetNormName(enemyHero)
					end
				end
			end
			if Fu.IsInRange(bot, enemyHero, castRange + 200) and Fu.CanCastOnTargetAdvanced(enemyHero) then
				castTarget = enemyHero
				return BOT_ACTION_DESIRE_HIGH, castTarget, "Q-直接打断施法:" .. Fu.Chat.GetNormName(castTarget)
			end
		end
		if Fu.CanCastOnNonMagicImmune(enemyHero) and Fu.WillMagicKillTarget(bot, enemyHero, damage, castPoint + GetUnitToUnitDistance(bot, enemyHero) / 1000) then
			if enemyHero:HasModifier("modifier_bounty_hunter_track") then
				for _, unit in pairs(nearbyUnits) do
					if Fu.IsValid(unit) and Fu.CanCastOnTargetAdvanced(unit) and not unit:IsMagicImmune() then
						castTarget = unit
						return BOT_ACTION_DESIRE_HIGH, castTarget, "Q-通过弹射击杀:" .. Fu.Chat.GetNormName(enemyHero)
					end
				end
			end
			if Fu.IsInRange(bot, enemyHero, castRange + 200) and Fu.CanCastOnTargetAdvanced(enemyHero) then
				castTarget = enemyHero
				return BOT_ACTION_DESIRE_HIGH, castTarget, "Q-直接击杀:" .. Fu.Chat.GetNormName(castTarget)
			end
		end
	end
	if #trackedEnemies >= 2 then
		local bestUnit = nil
		local bestScore = 1.2
		for _, unit in pairs(nearbyUnits) do
			if Fu.IsValid(unit) and not unit:IsMagicImmune() and Fu.CanCastOnTargetAdvanced(unit) then
				local score = 0
				if not unit:HasModifier("modifier_bounty_hunter_track") then
					if unit:IsHero() then
						score = score + 1
					else
						score = score + 0.1
					end
				end
				for _, trackedEnemy in pairs(trackedEnemies) do
					if Fu.IsInRange(unit, trackedEnemy, bounceRadius - 80) then
						score = score + 1
					end
				end
				if score > bestScore then
					bestUnit = unit
					bestScore = score
				end
			end
		end
		if bestUnit ~= nil then
			castTarget = bestUnit
			return BOT_ACTION_DESIRE_HIGH, castTarget, "Q-弹射多个:" .. bestScore
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidHero(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange + bounceRadius + 100)
			and Fu.CanCastOnNonMagicImmune(botTarget)
		then
			if botTarget:HasModifier("modifier_bounty_hunter_track") then
				for _, unit in pairs(nearbyUnits) do
					if
						Fu.IsInRange(unit, botTarget, bounceRadius - 100)
						and not unit:IsMagicImmune()
						and Fu.CanCastOnTargetAdvanced(unit)
						and not unit:HasModifier("modifier_bounty_hunter_track")
					then
						castTarget = unit
						return BOT_ACTION_DESIRE_HIGH, castTarget, "Q-弹射进攻:" .. Fu.Chat.GetNormName(botTarget)
					end
				end
			end
			if Fu.IsInRange(bot, botTarget, castRange) and Fu.CanCastOnTargetAdvanced(botTarget) then
				castTarget = botTarget
				return BOT_ACTION_DESIRE_HIGH, castTarget, "Q-直接进攻:" .. Fu.Chat.GetNormName(botTarget)
			end
		end
	end
	if (bot:GetActiveMode() == BOT_MODE_LANING or botLevel <= 7 and #nearbyAllies <= 2) and bot:GetMana() >= 150 then
		local laneCreeps = bot:GetNearbyLaneCreeps(castRange + 300, true)
		local creepKeyword = "ranged"
		for _, creep in pairs(laneCreeps) do
			if
				Fu.IsValid(creep)
				and not creep:HasModifier("modifier_fountain_glyph")
				and Fu.IsKeyWordUnit(creepKeyword, creep)
				and Fu.WillKillTarget(creep, damage, damageType, castPoint + GetUnitToUnitDistance(bot, creep) / 1100)
				and GetUnitToUnitDistance(creep, bot) > 300
			then
				castTarget = creep
				return BOT_ACTION_DESIRE_HIGH, castTarget, "Q-补远程兵"
			end
		end
	end
	if
		(Fu.IsPushing(bot) or Fu.IsDefending(bot) or Fu.IsFarming(bot))
		and Fu.IsAllowedToSpam(bot, manaCost * 0.52)
		and (bot:GetAttackDamage() < 300 or mpRatio > 0.7)
		and abilityLevel >= 2
		and DotaTime() > 7 * 60
		and #nearbyAllies <= 2
		and #nearbyEnemies == 0
	then
		local laneCreeps = bot:GetNearbyLaneCreeps(castRange + 350, true)
		local creepKeyword = "ranged"
		for _, creep in pairs(laneCreeps) do
			if
				Fu.IsValid(creep)
				and Fu.IsKeyWordUnit(creepKeyword, creep)
				and not creep:HasModifier("modifier_fountain_glyph")
				and Fu.WillKillTarget(creep, damage, damageType, castPoint + GetUnitToUnitDistance(bot, creep) / 1100)
				and not Fu.CanKillTarget(creep, bot:GetAttackDamage() * 1.2, DAMAGE_TYPE_PHYSICAL)
			then
				castTarget = creep
				return BOT_ACTION_DESIRE_HIGH, castTarget, "Q-推线补远程"
			end
		end
	end
	if Fu.IsFarming(bot) and abilityLevel >= 3 and Fu.IsAllowedToSpam(bot, manaCost) then
		local neutralCreeps = bot:GetNearbyNeutralCreeps(castRange + 200)
		local strongestCreep = Fu.GetMostHpUnit(neutralCreeps)
		if
			Fu.IsValid(strongestCreep)
			and not Fu.IsRoshan(strongestCreep)
			and (#neutralCreeps >= 2 or GetUnitToUnitDistance(strongestCreep, bot) <= 400)
			and bot:IsFacingLocation(strongestCreep:GetLocation(), 40)
			and (strongestCreep:GetMagicResist() < 0.3 or mpRatio > 0.9)
			and not Fu.CanKillTarget(strongestCreep, bot:GetAttackDamage() * 1.68, DAMAGE_TYPE_PHYSICAL)
			and not Fu.CanKillTarget(strongestCreep, damage - 50, damageType)
		then
			castTarget = strongestCreep
			return BOT_ACTION_DESIRE_HIGH, castTarget, "Q-打钱"
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if Fu.IsRoshan(botTarget) and Fu.GetHP(botTarget) > 0.2 and Fu.IsInRange(botTarget, bot, castRange) and Fu.IsAttacking(bot) then
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(botTarget, bot, castRange) and Fu.IsAttacking(bot) then
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderE()
	if not shadowWalkAbility:IsFullyCastable() then
		return 0
	end
	local abilityLevel = shadowWalkAbility:GetLevel()
	if Fu.IsGoingOnSomeone(bot) and (botLevel >= 7 or DotaTime() > 6 * 60 or abilityLevel >= 2) then
		if
			Fu.IsValidHero(botTarget)
			and Fu.CanCastOnMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, 2500)
			and (not Fu.IsInRange(bot, botTarget, 1000) or Fu.IsChasingTarget(bot, botTarget))
		then
			return BOT_ACTION_DESIRE_HIGH, "E-隐身进攻:" .. Fu.Chat.GetNormName(botTarget)
		end
	end
	if
		Fu.IsRetreating(bot)
		and bot:WasRecentlyDamagedByAnyHero(3.0)
		and (#nearbyEnemies >= 1 or hpRatio < 0.2)
		and bot:DistanceFromFountain() > 800
	then
		return BOT_ACTION_DESIRE_HIGH, "E-隐身逃跑"
	end
	-- fix: mpRatio is the mana fraction (0-1), so "mpRatio >= 280" was never true, and "enemyTowers == 0" compared the tower
	-- table with a number (never true either): he never went invisible to move in the enemy half.
	-- Now: 280 mana kept, no enemy hero or tower within 1600.
	if Fu.IsInEnemyArea(bot) and botLevel >= 7 and bot:GetMana() >= 280 and not Fu.IsRealInvisible(bot) then
		local enemyHeroes = Fu.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE)
		local enemyTowers = bot:GetNearbyTowers(1600, true)
		if enemyHeroes ~= nil and #enemyHeroes == 0 and enemyTowers ~= nil and #enemyTowers == 0 then
			if DotaTime() >= (bot._bhSneakLogAt or -999) then
				bot._bhSneakLogAt = DotaTime() + 10
				pcall(print, string.format("[OHA-BOUNTY] t=%.0f shadow walk in enemy area mana=%d", DotaTime(), bot:GetMana()))
			end
			return BOT_ACTION_DESIRE_HIGH, "E-潜行"
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderR()
	if not trackAbility:IsFullyCastable() then
		return 0
	end
	local castRange = trackAbility:GetCastRange()
	local enemiesInRange = Fu.GetAroundEnemyHeroList(castRange)
	local bestTarget = nil
	local lowestHealth = 999999
	for _, enemyHero in pairs(enemiesInRange) do
		if
			Fu.IsValidHero(enemyHero)
			and not enemyHero:HasModifier("modifier_bounty_hunter_track")
			and not enemyHero:HasModifier("modifier_arc_warden_tempest_double")
			and Fu.CanCastAbilityOnTarget(enemyHero, false)
			and Fu.CanCastOnTargetAdvanced(enemyHero)
			and enemyHero:GetHealth() < lowestHealth
		then
			bestTarget = enemyHero
			lowestHealth = enemyHero:GetHealth()
		elseif enemyHero:HasModifier("modifier_bounty_hunter_track") then
			lowestHealth = 999999
		end
	end
	if bestTarget ~= nil then
		return BOT_ACTION_DESIRE_HIGH, bestTarget, "R-标记:" .. Fu.Chat.GetNormName(bestTarget)
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderFriendlyShadow()
	if not friendlyShadowAbility:IsTrained() or not friendlyShadowAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castRange = friendlyShadowAbility:GetCastRange()
	local alliesInRange = Fu.GetNearbyHeroes(bot, castRange, false, BOT_MODE_NONE)
	for _, allyHero in pairs(alliesInRange) do
		if Fu.IsGoingOnSomeone(allyHero) and Fu.IsInRange(bot, allyHero, castRange) and Fu.IsNotSelf(bot, allyHero) and not Fu.IsRealInvisible(allyHero) then
			return BOT_ACTION_DESIRE_HIGH, allyHero
		end
		if
			Fu.IsRetreating(allyHero)
			and allyHero:WasRecentlyDamagedByAnyHero(3.0)
			and allyHero:DistanceFromFountain() > 800
			and Fu.IsInRange(bot, allyHero, castRange)
			and Fu.IsNotSelf(bot, allyHero)
			and not Fu.IsRealInvisible(allyHero)
			and #nearbyEnemies >= 1
		then
			return BOT_ACTION_DESIRE_HIGH, allyHero
		end
		if Fu.IsInEnemyArea(bot) then
			local enemyHeroes = Fu.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE)
			local enemyTowers = bot:GetNearbyTowers(1600, true)
			if
				enemyHeroes ~= nil
				and enemyTowers ~= nil
				and #enemyHeroes == 0
				and #enemyTowers == 0
				and Fu.IsInRange(bot, allyHero, castRange)
				and Fu.IsNotSelf(bot, allyHero)
				and not Fu.IsRealInvisible(allyHero)
			then
				return BOT_ACTION_DESIRE_HIGH, allyHero
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
return X
