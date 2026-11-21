-- Silencer: skill build, item build, and ability use for this hero.
local X = {}
local bot = GetBot()
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local AbilityContext = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local Minion = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local sTalentList = Fu.Skill.GetTalentList(bot)
local sAbilityList = Fu.Skill.GetAbilityList(bot)
local sRole = Fu.Item.GetRoleItemsBuyList(bot)
local tTalentTreeList = {
	{ ["t25"] = { 10, 0 }, ["t20"] = { 0, 10 }, ["t15"] = { 0, 10 }, ["t10"] = { 0, 10 } },
	{ ["t25"] = { 10, 0 }, ["t20"] = { 0, 10 }, ["t15"] = { 0, 10 }, ["t10"] = { 0, 10 } },
}
local tAllAbilityBuildList =
	{ { 2, 1, 3, 1, 1, 6, 1, 3, 3, 3, 6, 2, 2, 2, 6 }, { 1, 3, 1, 2, 1, 6, 1, 3, 3, 3, 6, 2, 2, 2, 6 } }
local nAbilityBuildList = tAllAbilityBuildList[1]
if sRole == "pos_2" then
	nAbilityBuildList = tAllAbilityBuildList[1]
end
if sRole == "pos_4" then
	nAbilityBuildList = tAllAbilityBuildList[2]
end
if sRole == "pos_5" then
	nAbilityBuildList = tAllAbilityBuildList[2]
end
local nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList[1])
if sRole == "pos_2" then
	nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList[1])
end
if sRole == "pos_4" then
	nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList[2])
end
if sRole == "pos_5" then
	nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList[2])
end
local sRoleItemsBuyList = {}
-- Stratz 7.41f, week of 9 Nov 2026: pos 2, 30,187 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_2"] = {
	"item_tango",
	"item_mantle",
	"item_circlet",
	"item_double_branches",
	"item_faerie_fire",
	"item_null_talisman",
	"item_magic_wand",
	"item_power_treads",
	"item_witch_blade",
	"item_force_staff",
	"item_dragon_lance",
	"item_aghanims_shard",
	"item_hurricane_pike",
	"item_invis_sword",
	"item_ultimate_scepter",
	"item_black_king_bar",
	"item_devastator",
	"item_ultimate_scepter_2",
	"item_silver_edge",
	"item_sphere",
	"item_moon_shard",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 3, 3,096 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_3"] = {
	"item_tango",
	"item_circlet",
	"item_double_branches",
	"item_mantle",
	"item_null_talisman",
	"item_magic_wand",
	"item_power_treads",
	"item_witch_blade",
	"item_hurricane_pike",
	"item_aghanims_shard",
	"item_ultimate_scepter",
	"item_black_king_bar",
	"item_devastator",
	"item_travel_boots",
	"item_ultimate_scepter_2",
	"item_silver_edge",
	"item_refresher",
	"item_moon_shard",
	"item_travel_boots_2",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 1, 3,155 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_1"] = {
	"item_tango",
	"item_double_branches",
	"item_circlet",
	"item_mantle",
	"item_faerie_fire",
	"item_null_talisman",
	"item_magic_wand",
	"item_power_treads",
	"item_witch_blade",
	"item_force_staff",
	"item_dragon_lance",
	"item_aghanims_shard",
	"item_hurricane_pike",
	"item_invis_sword",
	"item_black_king_bar",
	"item_devastator",
	"item_silver_edge",
	"item_travel_boots",
	"item_ultimate_scepter_2",
	"item_monkey_king_bar",
	"item_moon_shard",
	"item_travel_boots_2",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 4, 83,656 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_4"] = {
	"item_tango",
	"item_blood_grenade",
	"item_double_branches",
	"item_magic_stick",
	"item_mantle",
	"item_magic_wand",
	"item_null_talisman",
	"item_arcane_boots",
	"item_force_staff",
	"item_ultimate_scepter",
	"item_aghanims_shard",
	"item_refresher",
	"item_ultimate_scepter_2",
	"item_sheepstick",
	"item_devastator",
	"item_hand_of_midas",
	"item_moon_shard",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 5, 86,636 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_5"] = {
	"item_tango",
	"item_blood_grenade",
	"item_double_branches",
	"item_magic_stick",
	"item_mantle",
	"item_null_talisman",
	"item_magic_wand",
	"item_arcane_boots",
	"item_force_staff",
	"item_ultimate_scepter",
	"item_aghanims_shard",
	"item_ultimate_scepter_2",
	"item_hand_of_midas",
	"item_sheepstick",
	"item_cyclone",
	"item_devastator",
	"item_moon_shard",
}
X["sBuyList"] = sRoleItemsBuyList[sRole]
X["sSellList"] = { "item_shivas_guard", "item_magic_wand", "item_sheepstick", "item_magic_wand" }
if Fu.Role.IsPvNMode() or Fu.Role.IsAllShadow() then
	X["sBuyList"], X["sSellList"] = { "PvN_priest" }, {}
end
nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"] =
	Fu.SetUserHeroInit(nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"])
X["sSkillList"] = Fu.Skill.GetSkillList(sAbilityList, nAbilityBuildList, sTalentList, nTalentBuildList)
X["bDeafaultAbility"] = false
X["bDeafaultItem"] = true
function X.MinionThink(hMinionUnit)
	Minion.MinionThink(hMinionUnit)
end
local curseOfTheSilentAbility =
	SafeAbility(bot:GetAbilityByName("silencer_curse_of_the_silent"), "silencer_curse_of_the_silent", "silencer")
local glaivesOfWisdomAbility =
	SafeAbility(bot:GetAbilityByName("silencer_glaives_of_wisdom"), "silencer_glaives_of_wisdom", "silencer")
local lastWordAbility = SafeAbility(bot:GetAbilityByName("silencer_last_word"), "silencer_last_word", "silencer")
local globalSilenceAbility =
	SafeAbility(bot:GetAbilityByName("silencer_global_silence"), "silencer_global_silence", "silencer")
local talent4 = nil
local curseDesire, curseLocation = 0
local glaivesDesire, glaivesTarget = 0
local lastWordDesire, lastWordTarget = 0
local globalSilenceDesire = 0
local manaReserve, mpRatio, hpRatio, botLevel, nearbyEnemies
local aetherRange = 0
local botTarget
function X.SkillsComplement()
	if Fu.CanNotUseAbility(bot) or bot:IsInvisible() then
		return
	end
	talent4 = SafeAbility(
		bot:GetAbilityByName("special_bonus_unique_silencer_4"),
		"special_bonus_unique_silencer_4",
		"silencer"
	)
	local context = AbilityContext.Build(bot)
	manaReserve = 300
	aetherRange = context.aetherRange
	mpRatio = context.mp
	hpRatio = context.hp
	botLevel = context.level
	nearbyEnemies = context.enemies
	globalSilenceDesire = X.ConsiderR()
	if globalSilenceDesire > 0 then
		Fu.SetQueuePtToINT(bot, false)
		bot:ActionQueue_UseAbility(globalSilenceAbility)
		return
	end
	curseDesire, curseLocation = X.ConsiderQ()
	if curseDesire > 0 then
		Fu.SetQueuePtToINT(bot, false)
		bot:ActionQueue_UseAbilityOnLocation(curseOfTheSilentAbility, curseLocation)
		return
	end
	local lastWordIsAoe
	lastWordDesire, lastWordTarget, lastWordIsAoe = X.ConsiderE()
	if lastWordDesire > 0 then
		Fu.SetQueuePtToINT(bot, false)
		if lastWordIsAoe then
			bot:ActionQueue_UseAbilityOnLocation(lastWordAbility, lastWordTarget)
		else
			bot:ActionQueue_UseAbilityOnEntity(lastWordAbility, lastWordTarget)
		end
		return
	end
	glaivesDesire, glaivesTarget = X.ConsiderW()
	if glaivesDesire > 0 then
		Fu.SetQueuePtToINT(bot, false)
		bot:ActionQueue_UseAbilityOnEntity(glaivesOfWisdomAbility, glaivesTarget)
		return
	end
end
function X.ConsiderQ()
	if not Fu.CanCastAbility(curseOfTheSilentAbility) then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local radius = curseOfTheSilentAbility:GetSpecialValueInt("radius")
	local castRange = curseOfTheSilentAbility:GetCastRange() + aetherRange
	local castPoint = curseOfTheSilentAbility:GetCastPoint()
	local manaCost = curseOfTheSilentAbility:GetManaCost()
	local totalDamage = curseOfTheSilentAbility:GetSpecialValueInt("duration")
		* curseOfTheSilentAbility:GetSpecialValueInt("damage")
	local abilityLevel = curseOfTheSilentAbility:GetLevel()
	local enemiesInRange = bot:GetNearbyHeroes(castRange + radius, true, BOT_MODE_NONE)
	local enemiesInRangeWide = bot:GetNearbyHeroes(castRange + radius + 80, true, BOT_MODE_NONE)
	local widerEnemies = bot:GetNearbyHeroes(1600, true, BOT_MODE_NONE)
	local weakestEnemy, weakestEnemyHealth = X.sil_GetWeakestUnit(enemiesInRange)
	local weakestEnemyWide, weakestEnemyWideHealth = X.sil_GetWeakestUnit(enemiesInRangeWide)
	local creepsInRange = bot:GetNearbyLaneCreeps(castRange + radius, true)
	local creepsInRangeWide = bot:GetNearbyLaneCreeps(castRange + radius + 80, true)
	local weakestCreep, weakestCreepHealth = X.sil_GetWeakestUnit(creepsInRange)
	local weakestCreepWide, _ = X.sil_GetWeakestUnit(creepsInRangeWide)
	local nearbyEnemyTowers = bot:GetNearbyTowers(1000, true)
	local heroKillAoe = bot:FindAoELocation(true, true, bot:GetLocation(), castRange, radius, 0, 0.7 * totalDamage)
	local heroAoe = bot:FindAoELocation(true, true, bot:GetLocation(), castRange, radius, 0, 0)
	local creepKillAoe = bot:FindAoELocation(true, false, bot:GetLocation(), castRange, radius, 0, totalDamage)
	local creepAoe = bot:FindAoELocation(true, false, bot:GetLocation(), castRange, radius, 0, 0)
	if creepAoe == nil then
		creepAoe = { count = 0 }
	elseif Fu.GetInLocLaneCreepCount(bot, 1600, radius, creepAoe.targetloc) <= 2 then
		creepAoe.count = 0
	end
	if heroKillAoe.count ~= nil and heroKillAoe.count >= 1 then
		if Fu.IsValidHero(weakestEnemyWide) and Fu.CanCastOnNonMagicImmune(weakestEnemyWide) then
			local castLocation = Fu.GetCastLocation(bot, weakestEnemyWide, castRange, radius)
			if castLocation ~= nil then
				return BOT_ACTION_DESIRE_HIGH, castLocation
			end
		end
	end
	if bot:GetActiveMode() == BOT_MODE_LANING and hpRatio >= 0.4 then
		if heroAoe.count >= 2 and Fu.IsValidHero(weakestEnemyWide) then
			return BOT_ACTION_DESIRE_HIGH, heroAoe.targetloc
		end
	end
	if bot:GetActiveMode() == BOT_MODE_RETREAT then
		local retreatAoe = bot:FindAoELocation(true, true, bot:GetLocation(), castRange - 300, radius, 0.8, 0)
		if retreatAoe.count >= 1 and Fu.IsValidHero(weakestEnemyWide) then
			return BOT_ACTION_DESIRE_HIGH, retreatAoe.targetloc
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			heroAoe.count >= 2
			and GetUnitToLocationDistance(bot, heroAoe.targetloc) <= castRange
			and Fu.IsValidHero(weakestEnemyWide)
		then
			return BOT_ACTION_DESIRE_HIGH, heroAoe.targetloc
		end
		local target = Fu.GetProperTarget(bot)
		if Fu.IsValidHero(target) and Fu.CanCastOnNonMagicImmune(target) then
			if mpRatio > 0.8 or bot:GetMana() > manaReserve * 2 then
				local castLocation = Fu.GetCastLocation(bot, target, castRange, radius)
				if castLocation ~= nil then
					return BOT_ACTION_DESIRE_HIGH, castLocation
				end
			end
			if
				target:GetHealth() / target:GetMaxHealth() < 0.4
				and GetUnitToUnitDistance(target, bot) <= radius + castRange
			then
				local castLocation = Fu.GetCastLocation(bot, target, castRange, radius)
				if castLocation ~= nil then
					return BOT_ACTION_DESIRE_HIGH, castLocation
				end
			end
		end
		target = weakestEnemy
		if
			target ~= nil
			and target:IsAlive()
			and target:GetHealth() / target:GetMaxHealth() < 0.4
			and GetUnitToUnitDistance(target, bot) <= radius + castRange
		then
			local castLocation = Fu.GetCastLocation(bot, target, castRange, radius)
			if castLocation ~= nil then
				return BOT_ACTION_DESIRE_HIGH, castLocation
			end
		end
		if
			creepAoe.count >= 5
			and weakestCreepWide ~= nil
			and #enemiesInRangeWide <= 0
			and bot:GetActiveMode() ~= BOT_MODE_ATTACK
			and abilityLevel >= 3
			and DotaTime() >= 10 * 60
		then
			return BOT_ACTION_DESIRE_HIGH, creepAoe.targetloc
		end
		if
			creepKillAoe.count >= 3
			and (weakestCreep ~= nil or botLevel == 25)
			and #enemiesInRangeWide <= 0
			and bot:GetActiveMode() ~= BOT_MODE_ATTACK
			and abilityLevel >= 3
			and DotaTime() >= 10 * 60
		then
			return BOT_ACTION_DESIRE_HIGH, creepKillAoe.targetloc
		end
	end
	if bot:GetActiveMode() ~= BOT_MODE_RETREAT then
		if Fu.IsValidHero(weakestEnemyWide) then
			if heroAoe.count >= 3 and GetUnitToLocationDistance(bot, heroAoe.targetloc) <= castRange then
				return BOT_ACTION_DESIRE_VERYHIGH, heroAoe.targetloc
			end
			if
				heroAoe.count >= 2
				and GetUnitToLocationDistance(bot, heroAoe.targetloc) <= castRange
				and bot:GetMana() > manaReserve
			then
				return BOT_ACTION_DESIRE_HIGH, heroAoe.targetloc
			end
			if Fu.IsValidHero(weakestEnemyWide) then
				if mpRatio > 0.8 or bot:GetMana() > manaReserve * 2 then
					local castLocation = Fu.GetCastLocation(bot, weakestEnemyWide, castRange, radius)
					if castLocation ~= nil then
						return BOT_ACTION_DESIRE_HIGH, castLocation
					end
				end
				if
					weakestEnemyWide:GetHealth() / weakestEnemyWide:GetMaxHealth() <= 0.4
					and GetUnitToUnitDistance(weakestEnemyWide, bot) <= radius + castRange
				then
					local castLocation = Fu.GetCastLocation(bot, weakestEnemyWide, castRange, radius)
					if castLocation ~= nil then
						return BOT_ACTION_DESIRE_HIGH, castLocation
					end
				end
			end
		end
	end
	if bot:GetActiveMode() == BOT_MODE_FARM and abilityLevel >= 3 then
		if creepKillAoe.count >= 3 and weakestCreep ~= nil then
			return BOT_ACTION_DESIRE_HIGH, creepKillAoe.targetloc
		end
		if creepAoe.count >= 5 and weakestCreep ~= nil then
			return BOT_ACTION_DESIRE_HIGH, creepAoe.targetloc
		end
	end
	if
		(
			bot:GetActiveMode() == BOT_MODE_PUSH_TOWER_TOP
			or bot:GetActiveMode() == BOT_MODE_PUSH_TOWER_MID
			or bot:GetActiveMode() == BOT_MODE_PUSH_TOWER_BOT
			or bot:GetActiveMode() == BOT_MODE_DEFEND_TOWER_TOP
			or bot:GetActiveMode() == BOT_MODE_DEFEND_TOWER_MID
			or bot:GetActiveMode() == BOT_MODE_DEFEND_TOWER_BOT
		)
		and abilityLevel >= 3
		and DotaTime() >= 10 * 60
	then
		if creepAoe.count >= 5 and weakestCreep ~= nil then
			return BOT_ACTION_DESIRE_HIGH, creepAoe.targetloc
		end
		if creepKillAoe.count >= 3 and weakestCreep ~= nil then
			return BOT_ACTION_DESIRE_HIGH, creepKillAoe.targetloc
		end
	end
	if bot:GetActiveMode() == BOT_MODE_ROSHAN and bot:GetMana() >= 600 then
		local attackTarget = bot:GetAttackTarget()
		if Fu.IsRoshan(attackTarget) then
			return BOT_ACTION_DESIRE_HIGH, attackTarget:GetLocation()
		end
	end
	if #widerEnemies == 0 and DotaTime() > 9 * 60 and bot:GetActiveMode() ~= BOT_MODE_ATTACK and abilityLevel > 2 then
		if creepKillAoe.count >= 3 and (weakestCreepWide ~= nil or botLevel >= 20) then
			return BOT_ACTION_DESIRE_HIGH, creepKillAoe.targetloc
		end
		if creepAoe.count >= 5 and weakestCreepWide ~= nil then
			return BOT_ACTION_DESIRE_HIGH, creepAoe.targetloc
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.ConsiderW()
	if not Fu.CanCastAbility(glaivesOfWisdomAbility) or bot:IsDisarmed() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local attackRange = bot:GetAttackRange() + 50
	local attackDamage = bot:GetAttackDamage()
	local glaiveDamage = glaivesOfWisdomAbility:GetSpecialValueInt("intellect_damage_pct")
		/ 100
		* bot:GetAttributeValue(ATTRIBUTE_INTELLECT)
		* (1 + bot:GetSpellAmp())
	local castRange = attackRange
	local nearbyEnemyTowers = bot:GetNearbyTowers(900, true)
	local creepsInRange = bot:GetNearbyLaneCreeps(attackRange + 100, true)
	local closeEnemyCreeps = bot:GetNearbyLaneCreeps(400, true)
	local weakestCreep = Fu.GetVulnerableWeakestUnit(bot, false, true, attackRange + 100)
	local enemiesInRange = bot:GetNearbyHeroes(attackRange, true, BOT_MODE_NONE)
	local weakestEnemyHero = Fu.GetVulnerableWeakestUnit(bot, true, true, attackRange)
	local harassTarget = Fu.GetVulnerableWeakestUnit(bot, true, true, attackRange + 40)
	local nearbyAllyCreeps = bot:GetNearbyLaneCreeps(350, false)
	local botTarget = Fu.GetProperTarget(bot)
	if bot:GetActiveMode() ~= BOT_MODE_RETREAT or bot:GetActiveModeDesire() < 0.6 then
		if Fu.IsValidHero(weakestEnemyHero) then
			if weakestEnemyHero:GetHealth() <= X.sil_RealDamage(attackDamage, glaiveDamage, weakestEnemyHero) then
				-- fix: returned an undefined global (WeakestEnemy = nil); the checked target is ad
				return BOT_ACTION_DESIRE_HIGH, weakestEnemyHero
			end
		end
	end
	if
		botLevel <= 9
		and hpRatio > 0.55
		and Fu.IsValidHero(botTarget)
		and (not Fu.IsRunning(bot) or Fu.IsInRange(bot, botTarget, attackRange + 29))
	then
		if not botTarget:IsAttackImmune() and GetUnitToUnitDistance(bot, botTarget) < attackRange + 99 then
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end
	if bot:GetActiveMode() == BOT_MODE_LANING and #nearbyEnemyTowers == 0 then
		if Fu.IsValid(harassTarget) then
			if
				hpRatio >= 0.62
				and #closeEnemyCreeps <= 6
				and #nearbyAllyCreeps >= 2
				and not bot:WasRecentlyDamagedByCreep(1.5)
				and not bot:WasRecentlyDamagedByAnyHero(1.5)
			then
				return BOT_ACTION_DESIRE_HIGH, harassTarget
			end
			if
				Fu.GetAllyUnitCountAroundEnemyTarget(bot, harassTarget, 500) >= 3
				and hpRatio >= 0.6
				and not bot:WasRecentlyDamagedByCreep(1.5)
				and not bot:WasRecentlyDamagedByAnyHero(1.5)
			then
				return BOT_ACTION_DESIRE_HIGH, harassTarget
			end
		end
	end
	if
		Fu.IsValidHero(botTarget)
		and GetUnitToUnitDistance(botTarget, bot) > attackRange + 200
		and Fu.IsValidHero(enemiesInRange[1])
		and Fu.CanBeAttacked(enemiesInRange[1])
		and bot:GetActiveMode() ~= BOT_MODE_RETREAT
	then
		return BOT_ACTION_DESIRE_HIGH, enemiesInRange[1]
	end
	if
		botTarget == nil
		and bot:GetActiveMode() ~= BOT_MODE_RETREAT
		and bot:GetActiveMode() ~= BOT_MODE_ATTACK
		and bot:GetActiveMode() ~= BOT_MODE_ASSEMBLE
		and Fu.GetTeamFightAlliesCount(bot) <= 2
	then
		if Fu.IsValid(weakestCreep) and not Fu.IsOtherAllysTarget(weakestCreep) then
			local creep = weakestCreep
			local attackDelay = Fu.GetAttackProDelayTime(bot, creep)
			local incomingDamage = Fu.GetTotalAttackWillRealDamage(creep, attackDelay)
			local glaiveHitDamage = X.sil_RealDamage(attackDamage, glaiveDamage, creep)
			if
				incomingDamage + glaiveHitDamage > creep:GetHealth() + 1
				and not Fu.CanKillTarget(creep, attackDamage, DAMAGE_TYPE_PHYSICAL)
			then
				return BOT_ACTION_DESIRE_HIGH, creep
			end
		end
		if (bot:HasScepter() or attackDamage > 160) and #nearbyEnemies == 0 then
			local nearbyCreeps = bot:GetNearbyCreeps(800, true)
			if Fu.IsValid(nearbyCreeps[1]) then
				return BOT_ACTION_DESIRE_HIGH, nearbyCreeps[1]
			end
		end
		local nearbyNeutrals = bot:GetNearbyNeutralCreeps(800)
		if
			DotaTime() % 60 > 52
			and DotaTime() % 60 < 54.5
			and Fu.IsValid(nearbyNeutrals[1])
			and not nearbyNeutrals[1]:WasRecentlyDamagedByAnyHero(3.0)
		then
			return BOT_ACTION_DESIRE_HIGH, nearbyNeutrals[1]
		end
		local farNeutrals = bot:GetNearbyNeutralCreeps(1600)
		local activeMode = bot:GetActiveMode()
		if
			activeMode ~= BOT_MODE_LANING
			and activeMode ~= BOT_MODE_FARM
			and activeMode ~= BOT_MODE_RUNE
			and activeMode ~= BOT_MODE_ASSEMBLE
			and activeMode ~= BOT_MODE_SECRET_SHOP
			and activeMode ~= BOT_MODE_SIDE_SHOP
			and activeMode ~= BOT_MODE_WATCHER
			and activeMode ~= BOT_MODE_WARD
			and GetRoshanDesire() < BOT_MODE_DESIRE_HIGH
			and not bot:WasRecentlyDamagedByAnyHero(2.0)
			and #nearbyEnemies == 0
			and attackDamage > 140
			and Fu.IsValid(farNeutrals[1])
			and not Fu.IsRoshan(farNeutrals[1])
			and (not farNeutrals[1]:IsAncientCreep() or attackDamage > 180)
		then
			return BOT_ACTION_DESIRE_HIGH, farNeutrals[1]
		end
	end
	if Fu.IsGoingOnSomeone(bot) and not glaivesOfWisdomAbility:GetAutoCastState() then
		if
			Fu.IsValidHero(botTarget)
			and not botTarget:IsAttackImmune()
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(botTarget, bot, attackRange + 80)
		then
			return BOT_ACTION_DESIRE_MODERATE, botTarget
		end
	end
	if bot:GetActiveMode() == BOT_MODE_ROSHAN and not glaivesOfWisdomAbility:GetAutoCastState() then
		local attackTarget = bot:GetAttackTarget()
		if Fu.IsRoshan(attackTarget) and Fu.IsInRange(attackTarget, bot, attackRange) then
			return BOT_ACTION_DESIRE_HIGH, attackTarget
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function X.ConsiderE()
	if not Fu.CanCastAbility(lastWordAbility) then
		return BOT_ACTION_DESIRE_NONE, 0, false
	end
	local castRange = Fu.GetProperCastRange(false, bot, lastWordAbility:GetCastRange())
	local damage = lastWordAbility:GetSpecialValueInt("damage")
	botTarget = Fu.GetProperTarget(bot)
	local radius = 0
	local hasAoeTalent = talent4 ~= nil and talent4:IsTrained()
	if hasAoeTalent then
		radius = talent4:GetSpecialValueInt("value")
	end
	local nearbyEnemies = bot:GetNearbyHeroes(1600, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and Fu.CanCastOnTargetAdvanced(enemyHero)
			and Fu.IsInRange(bot, enemyHero, castRange)
			and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
			and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
			and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
			and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
			and not enemyHero:HasModifier("modifier_troll_warlord_battle_trance")
			and not enemyHero:HasModifier("modifier_ursa_enrage")
		then
			-- datafeed: extra damage = int_multiplier (1/1.5/2/2.5) x the INT difference. The old math.abs()
			-- also counted a target with MORE INT as bonus, and the multiplier was left out. Negative
			-- difference counted as 0 (the feed does not say how it is handled).
			local totalDamage = damage
				+ lastWordAbility:GetSpecialValueFloat("int_multiplier")
					* math.max(
						0,
						bot:GetAttributeValue(ATTRIBUTE_INTELLECT) - enemyHero:GetAttributeValue(ATTRIBUTE_INTELLECT)
					)
			if Fu.CanKillTarget(enemyHero, totalDamage, DAMAGE_TYPE_MAGICAL) then
				if hasAoeTalent then
					local aoe = bot:FindAoELocation(true, true, enemyHero:GetLocation(), 0, radius, 0, 0)
					if aoe.count >= 2 then
						return BOT_ACTION_DESIRE_HIGH, aoe.targetloc, true
					else
						return BOT_ACTION_DESIRE_HIGH, enemyHero, false
					end
				else
					return BOT_ACTION_DESIRE_HIGH, enemyHero, false
				end
			end
		end
	end
	if Fu.IsInTeamFight(bot, 1200) then
		local mostDangerousEnemy = nil
		local highestDamage = 0
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.CanBeAttacked(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
				and Fu.IsInRange(bot, enemyHero, castRange)
				and not Fu.IsDisabled(enemyHero)
				and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
				and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
				and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
				and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
				and not enemyHero:HasModifier("modifier_troll_warlord_battle_trance")
				and not enemyHero:HasModifier("modifier_ursa_enrage")
			then
				local estimatedDamage = enemyHero:GetEstimatedDamageToTarget(false, bot, 3.0, DAMAGE_TYPE_ALL)
				if estimatedDamage > highestDamage then
					highestDamage = estimatedDamage
					mostDangerousEnemy = enemyHero
				end
			end
		end
		if mostDangerousEnemy ~= nil then
			if hasAoeTalent then
				local aoe = bot:FindAoELocation(true, true, mostDangerousEnemy:GetLocation(), 0, radius, 0, 0)
				if aoe.count >= 2 then
					return BOT_ACTION_DESIRE_HIGH, aoe.targetloc, true
				else
					return BOT_ACTION_DESIRE_HIGH, mostDangerousEnemy, false
				end
			else
				return BOT_ACTION_DESIRE_HIGH, mostDangerousEnemy, false
			end
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidHero(botTarget)
			and Fu.CanBeAttacked(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.CanCastOnTargetAdvanced(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and not Fu.IsDisabled(botTarget)
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
			and not botTarget:HasModifier("modifier_troll_warlord_battle_trance")
			and not botTarget:HasModifier("modifier_ursa_enrage")
		then
			if hasAoeTalent then
				local aoe = bot:FindAoELocation(true, true, botTarget:GetLocation(), 0, radius, 0, 0)
				if aoe.count >= 2 then
					return BOT_ACTION_DESIRE_HIGH, aoe.targetloc, true
				else
					return BOT_ACTION_DESIRE_HIGH, botTarget, false
				end
			else
				return BOT_ACTION_DESIRE_HIGH, botTarget, false
			end
		end
	end
	if Fu.IsRetreating(bot) and not Fu.IsRealInvisible(bot) then
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.IsInRange(bot, enemyHero, castRange)
				and bot:WasRecentlyDamagedByHero(enemyHero, 3.0)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
				and not Fu.IsDisabled(enemyHero)
			then
				if hasAoeTalent then
					local aoe = bot:FindAoELocation(true, true, enemyHero:GetLocation(), 0, radius, 0, 0)
					if aoe.count >= 2 then
						return BOT_ACTION_DESIRE_HIGH, aoe.targetloc, true
					else
						return BOT_ACTION_DESIRE_HIGH, enemyHero, false
					end
				else
					return BOT_ACTION_DESIRE_HIGH, enemyHero, false
				end
			end
		end
	end
	if Fu.IsDoingRoshan(bot) and bot:GetMana() >= 500 then
		if
			Fu.IsRoshan(botTarget)
			and Fu.CanBeAttacked(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and Fu.IsAttacking(bot)
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget, false
		end
	end
	if Fu.IsDoingTormentor(bot) and bot:GetMana() >= 500 then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, castRange) and Fu.IsAttacking(bot) then
			return BOT_ACTION_DESIRE_HIGH, botTarget, false
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0, false
end
function X.ConsiderR()
	if not Fu.CanCastAbility(globalSilenceAbility) then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local nearbyEnemies = bot:GetNearbyHeroes(1400, true, BOT_MODE_NONE)
	local closeAllies = bot:GetNearbyHeroes(800, false, BOT_MODE_NONE)
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValid(enemyHero)
			and enemyHero:IsChanneling()
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and not enemyHero:HasModifier("modifier_teleporting")
			and enemyHero:GetHealth() > 500
			and X.IsChannelingUltimate(enemyHero)
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsRetreating(bot) then
		if #nearbyEnemies >= 2 and #closeAllies > 2 then
			return BOT_ACTION_DESIRE_MODERATE
		end
	end
	local teamPlayers = GetTeamPlayers(GetTeam())
	for i = 1, #teamPlayers do
		local member = GetTeamMember(i)
		if member ~= nil and member:IsAlive() then
			if Fu.IsInTeamFight(member, 1200) then
				local aoe = member:FindAoELocation(true, true, member:GetLocation(), 1400, 600, 0, 0)
				if aoe.count >= 2 then
					return BOT_ACTION_DESIRE_HIGH
				end
			end
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		local target = bot:GetTarget()
		if
			Fu.IsValidHero(target)
			and Fu.CanCastOnNonMagicImmune(target)
			and Fu.IsInRange(target, bot, 1200)
			and not Fu.IsDisabled(target)
		then
			local widerAllies = bot:GetNearbyHeroes(1600, false, BOT_MODE_NONE)
			if #widerAllies >= 2 then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
-- Global Silence (120s) only to stop an ULTIMATE channel (Black Hole, Freezing Field, Death Ward...): any
-- channel over 500 HP set it off before, e.g. a Life Drain, Shackles or a Tricks of the Trade.
function X.IsChannelingUltimate(unit)
	local activeAbility = unit:GetCurrentActiveAbility()
	if activeAbility == nil or not activeAbility:IsUltimate() then
		return false
	end
	if DotaTime() >= (bot._globalLogAt or -999) then
		bot._globalLogAt = DotaTime() + 10
		pcall(
			print,
			string.format("[OHA-SILENCER] t=%.0f global-silence vs channel %s", DotaTime(), activeAbility:GetName())
		)
	end
	return true
end
function X.sil_GetWeakestUnit(units)
	local weakestUnit = nil
	local lowestHealth = 10000
	for _, unit in pairs(units) do
		if
			Fu.IsValid(unit)
			and unit:IsAlive()
			and Fu.CanCastOnNonMagicImmune(unit)
			and Fu.CanCastOnTargetAdvanced(unit)
		then
			if unit:GetHealth() < lowestHealth then
				lowestHealth = unit:GetHealth()
				weakestUnit = unit
			end
		end
	end
	return weakestUnit, lowestHealth
end
function X.sil_RealDamage(attackDamage, bonusDamage, target)
	-- datafeed: Glaives of Wisdom bonus damage is magical (damage 2), not pure
	local totalDamage = target:GetActualIncomingDamage(attackDamage, DAMAGE_TYPE_PHYSICAL)
		+ target:GetActualIncomingDamage(bonusDamage, DAMAGE_TYPE_MAGICAL)
	return totalDamage
end
return X
