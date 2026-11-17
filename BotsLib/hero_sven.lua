-- Sven: skill build, item build, and ability use for this hero.
local X = {}
local bot = GetBot()
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local AbilityContext = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local Minion = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local sTalentList = Fu.Skill.GetTalentList(bot)
local sAbilityList = Fu.Skill.GetAbilityList(bot)
local sRole = Fu.Item.GetRoleItemsBuyList(bot)
local tTalentTreeList = { ["t25"] = { 0, 10 }, ["t20"] = { 10, 0 }, ["t15"] = { 0, 10 }, ["t10"] = { 10, 0 } }
local tAllAbilityBuildList = { { 1, 3, 2, 2, 2, 6, 2, 3, 3, 3, 6, 1, 1, 1, 6 } }
local nAbilityBuildList = Fu.Skill.GetRandomBuild(tAllAbilityBuildList)
local nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList)
local sRoleItemsBuyList = {}
sRoleItemsBuyList["pos_1"] = {
	"item_tango",
	"item_double_branches",
	"item_faerie_fire",
	"item_quelling_blade",
	"item_magic_wand",
	"item_power_treads",
	"item_mask_of_madness",
	"item_echo_sabre",
	"item_blink",
	"item_black_king_bar",
	"item_greater_crit",
	"item_harpoon",
	"item_satanic",
	"item_moon_shard",
	"item_swift_blink",
	"item_orchid",
	"item_bloodthorn",
	"item_ultimate_scepter_2",
	"item_aghanims_shard",
}
sRoleItemsBuyList["pos_2"] = sRoleItemsBuyList["pos_1"]
sRoleItemsBuyList["pos_4"] = sRoleItemsBuyList["pos_1"]
sRoleItemsBuyList["pos_5"] = sRoleItemsBuyList["pos_1"]
sRoleItemsBuyList["pos_3"] = sRoleItemsBuyList["pos_1"]
X["sBuyList"] = sRoleItemsBuyList[sRole]
X["sSellList"] = {
	"item_echo_sabre",
	"item_quelling_blade",
	"item_travel_boots",
	"item_magic_wand",
	"item_greater_crit",
	"item_hand_of_midas",
	"item_overwhelming_blink",
	"item_echo_sabre",
}
if Fu.Role.IsPvNMode() or Fu.Role.IsAllShadow() then
	X["sBuyList"], X["sSellList"] = { "PvN_str_carry" }, { "item_power_treads", "item_quelling_blade" }
end
nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"] =
	Fu.SetUserHeroInit(nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"])
X["sSkillList"] = Fu.Skill.GetSkillList(sAbilityList, nAbilityBuildList, sTalentList, nTalentBuildList)
X["bDeafaultAbility"] = false
X["bDeafaultItem"] = false
function X.MinionThink(minionUnit)
	Minion.MinionThink(minionUnit)
end
local stormBoltAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[1]), "sAbilityList[1]", "sven")
local warcryAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[3]), "sAbilityList[3]", "sven")
local godsStrengthAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[6]), "sAbilityList[6]", "sven")
local stormBoltDesire, stormBoltTarget
local warcryDesire
local godsStrengthDesire
local mpRatio, hpRatio, botLevel, nearbyEnemies
local botTarget
function X.SkillsComplement()
	Fu.ConsiderForMkbDisassembleMask(bot)
	X.SvenConsiderTarget()
	if Fu.CanNotUseAbility(bot) or bot:IsInvisible() then
		return
	end
	local context = AbilityContext.Build(bot)
	aetherRange = context.aetherRange
	botLevel = context.level
	mpRatio = context.mp
	hpRatio = context.hp
	botTarget = context.target
	nearbyEnemies = context.enemies
	godsStrengthDesire = X.ConsiderR()
	if godsStrengthDesire > 0 then
		Fu.SetQueuePtToINT(bot, true)
		bot:ActionQueue_UseAbility(godsStrengthAbility)
		return
	end
	stormBoltDesire, stormBoltTarget = X.ConsiderQ()
	if stormBoltDesire > 0 then
		Fu.SetQueuePtToINT(bot, true)
		bot:ActionQueue_UseAbilityOnEntity(stormBoltAbility, stormBoltTarget)
		return
	end
	warcryDesire = X.ConsiderE()
	if warcryDesire > 0 then
		Fu.SetQueuePtToINT(bot, false)
		bot:ActionQueue_UseAbility(warcryAbility)
		return
	end
end
function X.ConsiderQ()
	if not stormBoltAbility:IsFullyCastable() then
		return 0
	end
	local castRange = stormBoltAbility:GetCastRange()
	if castRange > 1000 then
		castRange = 1000
	end
	local castPoint = stormBoltAbility:GetCastPoint()
	local manaCost = stormBoltAbility:GetManaCost()
	local abilityLevel = stormBoltAbility:GetLevel()
	local damage = 80 * abilityLevel
	local boltRadius = 255
	local damageType = DAMAGE_TYPE_MAGICAL
	local nearbyAllyHeroes = Fu.GetNearbyHeroes(bot, 1200, false, BOT_MODE_NONE)
	if
		#nearbyEnemies == 1
		and Fu.IsValidHero(nearbyEnemies[1])
		and Fu.IsInRange(nearbyEnemies[1], bot, castRange + 350)
		and nearbyEnemies[1]:IsFacingLocation(bot:GetLocation(), 30)
		and nearbyEnemies[1]:GetAttackRange() > castRange
		and nearbyEnemies[1]:GetAttackRange() < 1250
	then
		castRange = castRange + 260
	end
	local enemiesInRange = Fu.GetNearbyHeroes(bot, castRange + 43, true, BOT_MODE_NONE)
	local enemiesInBonusRange = Fu.GetNearbyHeroes(bot, castRange + 350, true, BOT_MODE_NONE)
	local nearbyCreeps = bot:GetNearbyCreeps(castRange + 43, true)
	for _, enemyHero in pairs(enemiesInBonusRange) do
		if
			Fu.IsValid(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and Fu.CanCastOnTargetAdvanced(enemyHero)
			and not Fu.IsDisabled(enemyHero)
		then
			if enemyHero:IsChanneling() or Fu.CanKillTarget(enemyHero, damage, damageType) then
				local boltTarget = nil
				local unitsInRange = Fu.CombineTwoTable(enemiesInRange, nearbyCreeps)
				for _, nearbyUnit in pairs(unitsInRange) do
					if
						Fu.IsValid(nearbyUnit)
						and Fu.IsInRange(enemyHero, nearbyUnit, boltRadius)
						and Fu.CanCastOnNonMagicImmune(nearbyUnit)
						and Fu.CanCastOnTargetAdvanced(nearbyUnit)
					then
						boltTarget = nearbyUnit
						break
					end
				end
				if boltTarget ~= nil and not Fu.IsInRange(enemyHero, bot, castRange) then
					return BOT_ACTION_DESIRE_HIGH, boltTarget
				else
					return BOT_ACTION_DESIRE_HIGH, enemyHero
				end
			end
		end
	end
	if Fu.IsInTeamFight(bot, 1200) then
		local bestAoeTarget = nil
		local maxHeroCount = 1
		local unitsInRange = Fu.CombineTwoTable(enemiesInRange, nearbyCreeps)
		local mostDangerousHero = nil
		local maxDamageToBot = 0
		for _, unit in pairs(unitsInRange) do
			if
				Fu.IsValid(unit)
				and Fu.CanCastOnNonMagicImmune(unit)
				and Fu.CanCastOnTargetAdvanced(unit)
				and not Fu.IsDisabled(unit)
				and not unit:IsDisarmed()
			then
				local heroCount = Fu.GetAroundTargetEnemyHeroCount(unit, boltRadius)
				if heroCount > maxHeroCount then
					maxHeroCount = heroCount
					bestAoeTarget = unit
				end
				if unit:IsHero() then
					local damageToBot = unit:GetEstimatedDamageToTarget(false, bot, 3.0, DAMAGE_TYPE_PHYSICAL)
					if damageToBot > maxDamageToBot then
						maxDamageToBot = damageToBot
						mostDangerousHero = unit
					end
				end
			end
		end
		if bestAoeTarget ~= nil then
			return BOT_ACTION_DESIRE_HIGH, bestAoeTarget
		end
		if mostDangerousHero ~= nil then
			return BOT_ACTION_DESIRE_HIGH, mostDangerousHero
		end
	end
	if bot:GetActiveMode() == BOT_MODE_LANING or botLevel <= 5 then
		for _, enemyHero in pairs(enemiesInRange) do
			if
				Fu.IsValid(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
				and not Fu.IsDisabled(enemyHero)
				and Fu.GetAttackEnemysAllyCreepCount(enemyHero, 1400) >= 5
			then
				return BOT_ACTION_DESIRE_HIGH, enemyHero
			end
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidHero(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.CanCastOnTargetAdvanced(botTarget)
			and Fu.IsInRange(botTarget, bot, castRange + 60)
			and not Fu.IsDisabled(botTarget)
			and not botTarget:IsDisarmed()
		then
			if abilityLevel >= 3 or mpRatio > 0.88 or Fu.GetHP(botTarget) < 0.38 or hpRatio < 0.25 then
				return BOT_ACTION_DESIRE_HIGH, botTarget
			end
		end
	end
	if Fu.IsRetreating(bot) then
		for _, enemyHero in pairs(enemiesInRange) do
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
	if Fu.IsFarming(bot) and Fu.GetManaAfter(manaCost) > 0.3 then
		local neutralCreeps = bot:GetNearbyNeutralCreeps(700)
		if #neutralCreeps >= 3 then
			for _, creep in pairs(neutralCreeps) do
				if
					Fu.IsValid(creep)
					and Fu.IsInRange(creep, bot, castRange)
					and Fu.GetAroundTargetEnemyUnitCount(creep, boltRadius) >= 3
				then
					return BOT_ACTION_DESIRE_HIGH, creep
				end
			end
		end
		local laneCreeps = bot:GetNearbyLaneCreeps(castRange, true)
		if #laneCreeps >= 3 then
			for _, creep in pairs(laneCreeps) do
				if
					Fu.IsValid(creep)
					and not creep:HasModifier("modifier_fountain_glyph")
					and Fu.IsInRange(creep, bot, castRange)
					and Fu.GetAroundTargetEnemyUnitCount(creep, boltRadius) >= 3
				then
					return BOT_ACTION_DESIRE_HIGH, creep
				end
			end
		end
	end
	if
		(Fu.IsPushing(bot) or Fu.IsDefending(bot) or Fu.IsFarming(bot))
		and (bot:GetAttackDamage() < 200 or mpRatio > 0.9)
		and abilityLevel >= 4
		and #nearbyEnemies == 0
		and mpRatio > 0.68
		and not Fu.IsInEnemyArea(bot)
	then
		local laneCreeps = bot:GetNearbyLaneCreeps(1000, true)
		if #laneCreeps >= 5 then
			for _, creep in pairs(laneCreeps) do
				if
					Fu.IsValid(creep)
					and creep:GetHealth() >= 500
					and not creep:HasModifier("modifier_fountain_glyph")
					and Fu.IsInRange(creep, bot, castRange + 100)
					and Fu.GetAroundTargetEnemyUnitCount(creep, boltRadius) >= 5
				then
					return BOT_ACTION_DESIRE_HIGH, creep
				end
			end
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if Fu.IsRoshan(botTarget) and Fu.IsInRange(botTarget, bot, castRange) and Fu.GetManaAfter(manaCost) > 0.3 then
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, castRange) and Fu.IsAttacking(bot) then
			return BOT_ACTION_DESIRE_HIGH, botTarget, ""
		end
	end
	if
		bot:WasRecentlyDamagedByAnyHero(3.0)
		and bot:GetActiveMode() ~= BOT_MODE_RETREAT
		and #enemiesInRange >= 1
		and botLevel >= 7
	then
		for _, enemyHero in pairs(enemiesInRange) do
			if
				Fu.IsValidHero(enemyHero)
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
		(#nearbyEnemies > 0 or bot:WasRecentlyDamagedByAnyHero(3.0))
		and (bot:GetActiveMode() ~= BOT_MODE_RETREAT or #nearbyAllyHeroes >= 2)
		and #enemiesInRange >= 1
		and botLevel >= 7
	then
		for _, enemyHero in pairs(enemiesInRange) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
				and not Fu.IsDisabled(enemyHero)
			then
				return BOT_ACTION_DESIRE_HIGH, enemyHero
			end
		end
	end
	if Fu.IsFarming(bot) and #nearbyEnemies == 0 and Fu.GetManaAfter(manaCost) > 0.3 then
		local neutralCreeps = bot:GetNearbyNeutralCreeps(castRange)
		if #neutralCreeps >= 3 then
			local mostHpCreep = Fu.GetMostHpUnit(neutralCreeps)
			if
				Fu.IsValid(mostHpCreep)
				and not Fu.IsRoshan(mostHpCreep)
				and Fu.CanCastOnNonMagicImmune(mostHpCreep)
				and Fu.CanCastOnTargetAdvanced(mostHpCreep)
			then
				return BOT_ACTION_DESIRE_HIGH, mostHpCreep
			end
		end
	end
	return 0, nil
end
function X.ConsiderE()
	if not warcryAbility:IsFullyCastable() or #nearbyEnemies == 0 and hpRatio > 0.2 then
		return 0
	end
	local searchRadius = 700
	local allies = Fu.GetAllyList(bot, searchRadius)
	local allyCount = #allies
	local weakestAlly = Fu.GetLeastHpUnit(allies)
	if weakestAlly == nil then
		weakestAlly = bot
	end
	local allyHp = Fu.GetHP(weakestAlly)
	local allyEnemies = weakestAlly:GetNearbyHeroes(800, true, BOT_MODE_NONE)
	local enemyBonus = #allyEnemies / 20
	local requiredAllies = 1
	if allyHp > 0.35 + enemyBonus then
		requiredAllies = requiredAllies + 1
	end
	if allyHp > 0.50 + enemyBonus then
		requiredAllies = requiredAllies + 1
	end
	if allyHp > 0.65 + enemyBonus then
		requiredAllies = requiredAllies + 1
	end
	if allyHp > 0.9 + enemyBonus then
		requiredAllies = requiredAllies + 1
	end
	if allyCount >= requiredAllies and #allyEnemies >= 1 and weakestAlly:WasRecentlyDamagedByAnyHero(4.0) then
		return BOT_ACTION_DESIRE_HIGH
	end
	if
		Fu.IsRetreating(weakestAlly)
		and weakestAlly:GetHealth() < 800
		and Fu.IsRunning(weakestAlly)
		and weakestAlly:WasRecentlyDamagedByAnyHero(3.0)
	then
		return BOT_ACTION_DESIRE_HIGH
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidHero(botTarget)
			and Fu.IsInRange(botTarget, bot, 600)
			and bot:IsFacingLocation(botTarget:GetLocation(), 15)
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if
		Fu.IsRetreating(bot)
		and bot:WasRecentlyDamagedByAnyHero(3.0)
		and #allyEnemies >= 1
		and bot:GetHealth() / bot:GetMaxHealth() < 0.85
	then
		return BOT_ACTION_DESIRE_HIGH
	end
	return 0
end
function X.ConsiderR()
	if not godsStrengthAbility:IsFullyCastable() then
		return 0
	end
	local enemiesInRange = Fu.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE)
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidHero(botTarget)
			and (Fu.GetHP(botTarget) > 0.25 or #enemiesInRange >= 2)
			and (Fu.IsInRange(botTarget, bot, 700) or Fu.IsInRange(botTarget, bot, botTarget:GetAttackRange() + 80))
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if
		bot:GetActiveMode() == BOT_MODE_RETREAT
		and bot:DistanceFromFountain() > 800
		and hpRatio > 0.5
		and bot:WasRecentlyDamagedByAnyHero(3.0)
		and #enemiesInRange >= 1
	then
		return BOT_ACTION_DESIRE_HIGH
	end
	if bot:GetActiveMode() == BOT_MODE_ROSHAN then
		if Fu.IsRoshan(botTarget) and Fu.IsInRange(botTarget, bot, 400) then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, 400) and Fu.IsAttacking(bot) then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	return 0
end
function X.SvenConsiderTarget()
	local bot = GetBot()
	if not Fu.IsRunning(bot) then
		return
	end
	if not Fu.IsValidHero(botTarget) then
		return
	end
	local searchRange = bot:GetAttackRange() + 50
	local enemiesInRange = Fu.GetNearbyHeroes(bot, searchRange, true, BOT_MODE_NONE)
	local newTarget = enemiesInRange[1]
	-- Review fix: this read nInAttackRangeWeakestEnemyHero, a global that is never set (always nil),
	-- so Sven never switched off a far or untouchable target. Use the weakest attackable hero in
	-- attack range (same helper as Sniper's ConsiderTarget), else the nearest one.
	newTarget = Fu.GetAttackableWeakestUnit(bot, searchRange, true, true) or newTarget
	if
		Fu.IsValidHero(newTarget)
		and newTarget ~= botTarget
		and Fu.CanBeAttacked(newTarget)
		and (GetUnitToUnitDistance(botTarget, bot) > 350 or Fu.HasForbiddenModifier(botTarget))
	then
		if DotaTime() - (X.lastRetargetLog or -99) > 10 then
			X.lastRetargetLog = DotaTime()
			pcall(
				print,
				string.format(
					"[OHA-SVEN] t=%.0f retarget from=%s to=%s",
					DotaTime(),
					botTarget:GetUnitName(),
					newTarget:GetUnitName()
				)
			)
		end
		bot:SetTarget(newTarget)
		return
	end
end
return X
