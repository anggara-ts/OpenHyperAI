-- Riki: skill build, item build, and ability use for this hero.
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
local tTalentTreeList = { ["t25"] = { 0, 10 }, ["t20"] = { 0, 10 }, ["t15"] = { 0, 10 }, ["t10"] = { 0, 10 } }
local tAllAbilityBuildList = { { 2, 3, 2, 1, 2, 6, 2, 3, 3, 3, 6, 1, 1, 1, 6 } }
local nAbilityBuildList = Fu.Skill.GetRandomBuild(tAllAbilityBuildList)
local nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList)
local sRoleItemsBuyList = {}
sRoleItemsBuyList["pos_1"] = {
	"item_tango",
	"item_double_branches",
	"item_quelling_blade",
	"item_slippers",
	"item_circlet",
	"item_magic_wand",
	"item_wraith_band",
	"item_power_treads",
	"item_diffusal_blade",
	"item_manta",
	"item_greater_crit",
	"item_aghanims_shard",
	"item_basher",
	"item_sphere",
	"item_ultimate_scepter",
	"item_disperser",
	"item_abyssal_blade",
	"item_ultimate_scepter_2",
	"item_moon_shard",
	"item_monkey_king_bar",
}
sRoleItemsBuyList["pos_2"] = sRoleItemsBuyList["pos_1"]
sRoleItemsBuyList["pos_4"] = sRoleItemsBuyList["pos_1"]
sRoleItemsBuyList["pos_5"] = sRoleItemsBuyList["pos_1"]
sRoleItemsBuyList["pos_3"] = sRoleItemsBuyList["pos_1"]
X["sBuyList"] = sRoleItemsBuyList[sRole]
X["sSellList"] = {
	"item_black_king_bar",
	"item_quelling_blade",
	"item_ultimate_scepter",
	"item_magic_wand",
	"item_cyclone",
	"item_magic_wand",
	"item_shivas_guard",
	"item_magic_wand",
	"item_power_treads",
	"item_quelling_blade",
	"item_lotus_orb",
	"item_quelling_blade",
	"item_assault",
	"item_magic_wand",
	"item_travel_boots",
	"item_magic_wand",
	"item_assault",
	"item_ancient_janggo",
	"item_vladmir",
	"item_magic_wand",
}
if Fu.Role.IsPvNMode() then
	X["sBuyList"], X["sSellList"] =
		{ "PvN_BH" }, { { "item_power_treads", "item_quelling_blade" }, "item_quelling_blade" }
end
nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"] =
	Fu.SetUserHeroInit(nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"])
X["sSkillList"] = Fu.Skill.GetSkillList(sAbilityList, nAbilityBuildList, sTalentList, nTalentBuildList)
X["bDeafaultAbility"] = false
X["bDeafaultItem"] = false
function X.MinionThink(minionUnit)
	Minion.MinionThink(minionUnit)
end
local smokeScreenAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[1]), "sAbilityList[1]", "riki")
local blinkStrikeAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[2]), "sAbilityList[2]", "riki")
local tricksOfTheTradeAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[3]), "sAbilityList[3]", "riki")
local slot4Ability = SafeAbility(bot:GetAbilityByName(sAbilityList[4]), "sAbilityList[4]", "riki")
local cloakAndDaggerAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[6]), "sAbilityList[6]", "riki")
local talent5 = SafeAbility(bot:GetAbilityByName(sTalentList[5]), "sTalentList[5]", "riki")
local talent6 = SafeAbility(bot:GetAbilityByName(sTalentList[6]), "sTalentList[6]", "riki")
local talent8 = SafeAbility(bot:GetAbilityByName(sTalentList[8]), "sTalentList[8]", "riki")
local smokeScreenDesire, smokeScreenLocation
local blinkStrikeDesire, blinkStrikeTarget
local tricksDesire, tricksLocation
local slot4Desire, slot4Target
local aetherRange = 0
local lastBlinkStrikeTime = -90
local secondsPerAttack = 0
local botLevel, mpRatio, hpRatio, nearbyEnemies, nearbyAllies
function X.SkillsComplement()
	if Fu.CanNotUseAbility(bot) or DotaTime() < lastBlinkStrikeTime + secondsPerAttack + 0.3 then
		return
	end
	local context = AbilityContext.Build(bot)
	aetherRange = context.aetherRange
	botLevel = context.level
	mpRatio = context.mp
	hpRatio = context.hp
	botTarget = context.target
	nearbyEnemies = context.enemies
	nearbyAllies = context.allies
	secondsPerAttack = bot:GetSecondsPerAttack()
	smokeScreenDesire, smokeScreenLocation = X.ConsiderQ()
	if smokeScreenDesire > 0 then
		Fu.SetQueuePtToINT(bot, true)
		bot:ActionQueue_UseAbilityOnLocation(smokeScreenAbility, smokeScreenLocation)
		return
	end
	blinkStrikeDesire, blinkStrikeTarget = X.ConsiderW()
	if blinkStrikeDesire > 0 then
		Fu.SetQueuePtToINT(bot, true)
		bot:ActionQueue_UseAbilityOnEntity(blinkStrikeAbility, blinkStrikeTarget)
		return
	end
	tricksDesire, tricksLocation = X.ConsiderE()
	if tricksDesire > 0 then
		Fu.SetQueuePtToINT(bot, true)
		bot:ActionQueue_UseAbilityOnLocation(tricksOfTheTradeAbility, tricksLocation)
		return
	end
	slot4Desire, slot4Target = X.ConsiderAS()
	if slot4Desire > 0 then
		bot:Action_UseAbilityOnEntity(slot4Ability, slot4Target)
		return
	end
end
function X.ConsiderQ()
	if not smokeScreenAbility:IsFullyCastable() then
		return 0
	end
	local abilityLevel = smokeScreenAbility:GetLevel()
	local castRange = smokeScreenAbility:GetCastRange() + aetherRange
	local castPoint = smokeScreenAbility:GetCastPoint() + 0.5
	local manaCost = smokeScreenAbility:GetManaCost()
	local damage = smokeScreenAbility:GetAbilityDamage()
	local damageType = DAMAGE_TYPE_MAGICAL
	local enemiesInRange = Fu.GetAroundEnemyHeroList(castRange)
	-- sTalentList[8] is special_bonus_unique_riki_9 (+500 Blink Strike range, game files), not a Smoke Screen
	-- radius talent, so adding it here made the smoke AoE search 925 wide for a 425 cloud. Radius as read.
	local radius = smokeScreenAbility:GetSpecialValueInt("radius")
	local castLocation = nil
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.IsInRange(bot, enemyHero, castRange + radius)
			and enemyHero:IsChanneling()
			and not enemyHero:HasModifier("modifier_teleporting")
			and Fu.CanCastOnNonMagicImmune(enemyHero)
		then
			castLocation = Fu.GetDelayCastLocation(bot, enemyHero, castRange, radius, castPoint)
			if castLocation ~= nil then
				return BOT_ACTION_DESIRE_HIGH, castLocation, "Q-打断吟唱:" .. Fu.Chat.GetNormName(enemyHero)
			end
		end
	end
	if Fu.IsInTeamFight(bot, 1200) then
		local aoeLocation = Fu.GetAoeEnemyHeroLocation(bot, castRange, radius, 2)
		if aoeLocation ~= nil then
			castLocation = aoeLocation
			return BOT_ACTION_DESIRE_HIGH, castLocation, "Q-团战Aoe"
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidHero(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(botTarget, bot, castRange)
		then
			castLocation = Fu.GetDelayCastLocation(bot, botTarget, castRange, radius, castPoint + 0.3)
			if castLocation ~= nil then
				return BOT_ACTION_DESIRE_HIGH, castLocation, "Q-进攻" .. Fu.Chat.GetNormName(botTarget)
			end
		end
	end
	if Fu.IsRetreating(bot) then
		local aoeLocation = Fu.GetAoeEnemyHeroLocation(bot, castRange - 100, radius - 20, 2)
		if aoeLocation ~= nil then
			castLocation = aoeLocation
			return BOT_ACTION_DESIRE_HIGH, castLocation, "Q-撤退Aoe"
		end
		for _, enemyHero in pairs(enemiesInRange) do
			if
				Fu.IsValid(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and (
					bot:WasRecentlyDamagedByHero(enemyHero, 4.0)
					or bot:GetActiveModeDesire() > BOT_ACTION_DESIRE_VERYHIGH
				)
			then
				castLocation = Fu.GetDelayCastLocation(bot, enemyHero, castRange, radius, castPoint + 0.2)
				if castLocation ~= nil then
					return BOT_ACTION_DESIRE_HIGH, castLocation, "Q-撤退撒雾" .. Fu.Chat.GetNormName(enemyHero)
				end
			end
		end
	end
	if bot:GetActiveMode() == BOT_MODE_ROSHAN and bot:GetMana() >= 370 then
		if Fu.IsRoshan(botTarget) and Fu.GetHP(botTarget) > 0.3 and Fu.IsInRange(botTarget, bot, castRange) then
			castLocation = botTarget:GetLocation()
			return BOT_ACTION_DESIRE_HIGH, castLocation, "Q-肉山"
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderW()
	if not blinkStrikeAbility:IsFullyCastable() or bot:IsRooted() then
		return 0
	end
	local abilityLevel = blinkStrikeAbility:GetLevel()
	-- sTalentList[6] is special_bonus_unique_riki_5 (Blink Strike cooldown -1, game files), not a range talent;
	-- the range talent (riki_9) is an AbilityCastRange bonus, left to GetCastRange().
	local castRange = blinkStrikeAbility:GetCastRange() + aetherRange
	local castPoint = blinkStrikeAbility:GetCastPoint()
	local manaCost = blinkStrikeAbility:GetManaCost()
	local attackDamage = bot:GetAttackDamage()
	-- datafeed: Backstab is now the innate riki_innate_backstab (damage_multiplier 0.55); the ultimate (riki_backstab,
	-- Cloak and Dagger) has no damage_multiplier, so the bonus read 0.
	local innateBackstabAbility = bot:GetAbilityByName("riki_innate_backstab")
	if innateBackstabAbility ~= nil then
		local backstabMultiplier = innateBackstabAbility:GetSpecialValueFloat("damage_multiplier")
		if talent5:IsTrained() then
			backstabMultiplier = backstabMultiplier + talent5:GetSpecialValueFloat("value")
		end
		attackDamage = attackDamage + bot:GetAttributeValue(ATTRIBUTE_AGILITY) * backstabMultiplier
	end
	local bonusDamage = blinkStrikeAbility:GetSpecialValueInt("bonus_damage")
	-- datafeed: Blink Strike damage is physical (1), so its bonus_damage goes in the physical slot of
	-- WillMixedDamageKillTarget below (it was counted as magical).
	local damageType = DAMAGE_TYPE_PHYSICAL
	local enemiesInRange = Fu.GetAroundEnemyHeroList(castRange)
	local aliveEnemyCount = Fu.GetNumOfAliveHeroes(true)
	local target = nil
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidHero(enemyHero)
			and not enemyHero:IsAttackImmune()
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and Fu.CanCastOnTargetAdvanced(enemyHero)
			and Fu.IsInRange(bot, enemyHero, castRange + 100)
			and (
				Fu.WillMixedDamageKillTarget(enemyHero, attackDamage + bonusDamage, 0, 0, castPoint)
				or enemyHero:IsChanneling()
					and Fu.WillMixedDamageKillTarget(enemyHero, attackDamage * 3 + bonusDamage, 0, 0, castPoint * 3)
			)
		then
			target = enemyHero
			bot:SetTarget(target)
			lastBlinkStrikeTime = DotaTime()
			return BOT_ACTION_DESIRE_HIGH, target, "W-击杀:" .. Fu.Chat.GetNormName(target)
		end
	end
	if Fu.IsInTeamFight(bot, 1000) then
		local weakestEnemy = nil
		local lowestHealth = 10000
		for _, enemyHero in pairs(enemiesInRange) do
			if
				Fu.IsValid(enemyHero)
				and not enemyHero:IsAttackImmune()
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
			then
				local health = enemyHero:GetHealth()
				local ourHeroesNearEnemy = Fu.GetNearbyHeroes(enemyHero, 600, true, BOT_MODE_NONE)
				if health < lowestHealth and (#ourHeroesNearEnemy >= 1 or aliveEnemyCount <= 2) then
					lowestHealth = health
					weakestEnemy = enemyHero
				end
			end
		end
		if weakestEnemy ~= nil then
			target = weakestEnemy
			bot:SetTarget(target)
			lastBlinkStrikeTime = DotaTime()
			return BOT_ACTION_DESIRE_HIGH, target, "W-团战攻击最弱的:" .. Fu.Chat.GetNormName(target)
		end
	end
	if
		Fu.IsGoingOnSomeone(bot)
		and (botLevel >= 2 or #nearbyEnemies <= 1)
		and (#nearbyAllies >= 2 or #nearbyEnemies <= 1 or botLevel >= 20)
	then
		if
			Fu.IsValidHero(botTarget)
			and not botTarget:IsAttackImmune()
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.CanCastOnTargetAdvanced(botTarget)
			and Fu.IsInRange(botTarget, bot, castRange + 50)
		then
			local targetAllies = Fu.GetNearbyHeroes(botTarget, 800, false, BOT_MODE_NONE)
			local targetEnemies = Fu.GetNearbyHeroes(botTarget, 800, true, BOT_MODE_NONE)
			local targetAlliesFar = Fu.GetNearbyHeroes(botTarget, 1600, false, BOT_MODE_NONE)
			if
				Fu.WillKillTarget(botTarget, attackDamage * 3, DAMAGE_TYPE_PHYSICAL, 1.0)
				or #targetAllies <= #targetEnemies
				or #targetAlliesFar <= 1
				or GetUnitToUnitDistance(bot, botTarget) <= 400
				or aliveEnemyCount <= 2
			then
				target = botTarget
				bot:SetTarget(target)
				lastBlinkStrikeTime = DotaTime()
				return BOT_ACTION_DESIRE_HIGH, target, "W-进攻:" .. Fu.Chat.GetNormName(target)
			end
		end
	end
	if Fu.IsRetreating(bot) and bot:WasRecentlyDamagedByAnyHero(3.0) then
		local attackingAllies = Fu.GetNearbyHeroes(bot, 800, false, BOT_MODE_ATTACK)
		if #attackingAllies == 0 or hpRatio < 0.16 then
			local allyHeroes = Fu.GetNearbyHeroes(bot, castRange, false, BOT_MODE_NONE)
			local allyCreeps = bot:GetNearbyCreeps(castRange, false)
			local enemyCreeps = bot:GetNearbyCreeps(castRange, true)
			local allyUnits = Fu.CombineTwoTable(allyHeroes, allyCreeps)
			local blinkUnits = Fu.CombineTwoTable(allyUnits, enemyCreeps)
			local bestUnit = nil
			local bestFountainDistance = Fu.GetDistanceFromAllyFountain(bot)
			for _, unit in pairs(blinkUnits) do
				if
					Fu.IsValid(unit)
					and not unit:IsMagicImmune()
					and GetUnitToUnitDistance(unit, bot) > 300
					and Fu.GetDistanceFromAllyFountain(unit) < bestFountainDistance
				then
					bestUnit = unit
					bestFountainDistance = Fu.GetDistanceFromAllyFountain(unit)
				end
			end
			if bestUnit ~= nil then
				target = bestUnit
				return BOT_ACTION_DESIRE_HIGH, target, "W-撤退了:" .. Fu.Chat.GetNormName(target)
			end
		end
	end
	if
		(Fu.IsPushing(bot) or Fu.IsDefending(bot) or Fu.IsFarming(bot))
		and Fu.IsAllowedToSpam(bot, manaCost)
		and (bot:GetAttackDamage() < 300 or mpRatio > 0.7)
		and abilityLevel >= 2
		and DotaTime() > 8 * 60
		and #nearbyAllies <= 2
		and #nearbyEnemies == 0
	then
		local laneCreeps = bot:GetNearbyLaneCreeps(castRange + 200, true)
		local creepKeyword = "ranged"
		for _, creep in pairs(laneCreeps) do
			if
				Fu.IsValid(creep)
				and Fu.IsKeyWordUnit(creepKeyword, creep)
				and not creep:HasModifier("modifier_fountain_glyph")
				and Fu.WillMixedDamageKillTarget(creep, attackDamage + bonusDamage, 0, 0, castPoint)
				and not Fu.CanKillTarget(creep, bot:GetAttackDamage() * 1.3, DAMAGE_TYPE_PHYSICAL)
			then
				target = creep
				bot:SetTarget(target)
				lastBlinkStrikeTime = DotaTime()
				return BOT_ACTION_DESIRE_HIGH, target, "W-推线补远程"
			end
		end
		local firstCreep = laneCreeps[1]
		if
			Fu.IsValid(firstCreep)
			and not Fu.IsInRange(bot, firstCreep, 650)
			and not firstCreep:HasModifier("modifier_fountain_glyph")
		then
			target = firstCreep
			lastBlinkStrikeTime = DotaTime()
			return BOT_ACTION_DESIRE_HIGH, target, "W-推线闪烁"
		end
	end
	if Fu.IsFarming(bot) and abilityLevel >= 3 and Fu.IsAllowedToSpam(bot, manaCost) then
		local neutralCreeps = bot:GetNearbyNeutralCreeps(800)
		if Fu.IsValid(botTarget) then
			if
				(#neutralCreeps >= 2 or GetUnitToUnitDistance(botTarget, bot) <= 400)
				and not Fu.CanKillTarget(botTarget, bot:GetAttackDamage() * 2.3, DAMAGE_TYPE_PHYSICAL)
			then
				target = botTarget
				lastBlinkStrikeTime = DotaTime()
				return BOT_ACTION_DESIRE_HIGH, target, "W-打钱输出"
			end
			if bot:GetMana() >= 240 and GetUnitToUnitDistance(botTarget, bot) >= 600 then
				target = botTarget
				lastBlinkStrikeTime = DotaTime()
				return BOT_ACTION_DESIRE_HIGH, target, "W-打钱闪烁"
			end
		end
	end
	if bot:GetActiveMode() == BOT_MODE_ROSHAN and bot:GetMana() >= 460 then
		if Fu.IsRoshan(botTarget) and Fu.GetHP(botTarget) > 0.2 and Fu.IsInRange(botTarget, bot, castRange) then
			target = botTarget
			lastBlinkStrikeTime = DotaTime()
			return BOT_ACTION_DESIRE_HIGH, target, "W-肉山"
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderE()
	if not tricksOfTheTradeAbility:IsFullyCastable() then
		return 0
	end
	local abilityLevel = tricksOfTheTradeAbility:GetLevel()
	local castRange = tricksOfTheTradeAbility:GetCastRange() + aetherRange
	local castPoint = tricksOfTheTradeAbility:GetCastPoint()
	local manaCost = tricksOfTheTradeAbility:GetManaCost()
	local damage = tricksOfTheTradeAbility:GetAbilityDamage()
	local damageType = DAMAGE_TYPE_MAGICAL
	local enemiesInRange = Fu.GetAroundEnemyHeroList(castRange)
	local radius = tricksOfTheTradeAbility:GetSpecialValueInt("radius") -- datafeed: Tricks of the Trade has "radius" (425), no "range" (read 0)
	local retreatLocation = Fu.GetLocationTowardDistanceLocation(bot, Fu.GetTeamFountain(), castRange)
	local castLocation = nil
	if
		Fu.IsNotAttackProjectileIncoming(bot, 1000)
		or Fu.IsWithoutTarget(bot) and Fu.GetAttackProjectileDamageByRange(bot, 1600) >= bot:GetHealth()
	then
		return BOT_ACTION_DESIRE_HIGH, retreatLocation, "E-躲避"
	end
	if Fu.IsInTeamFight(bot, 1000) then
		local aoeLocation = Fu.GetAoeEnemyHeroLocation(bot, castRange, radius, 2)
		if aoeLocation ~= nil then
			return BOT_ACTION_DESIRE_HIGH, aoeLocation, "E-团战Aoe"
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidHero(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange + radius)
			and Fu.CanCastOnMagicImmune(botTarget)
		then
			local targetLocation = Fu.GetCorrectLoc(botTarget, castPoint)
			if Fu.IsInLocRange(bot, targetLocation, castRange) then
				return BOT_ACTION_DESIRE_HIGH, targetLocation, "E-进攻:" .. Fu.Chat.GetNormName(botTarget)
			end
		end
	end
	if
		Fu.IsRetreating(bot)
		and (bot:WasRecentlyDamagedByAnyHero(3.0) or bot:GetActiveModeDesire() > BOT_MODE_DESIRE_VERYHIGH)
	then
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.IsInRange(bot, enemyHero, 560)
				and bot:WasRecentlyDamagedByHero(enemyHero, 5.0)
			then
				local distance = GetUnitToUnitDistance(bot, enemyHero)
				castLocation = Fu.GetUnitTowardDistanceLocation(enemyHero, bot, distance + castRange)
				return BOT_ACTION_DESIRE_HIGH, castLocation, "E-撤退:" .. Fu.Chat.GetNormName(enemyHero)
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderAS()
	-- datafeed: Riki has no Shard active any more (the Shard upgrades Smoke Screen), so sAbilityList[4] is the passive
	-- innate Backstab or nothing. CanCastAbility skips passive/hidden/untrained abilities instead of ordering a cast.
	if not Fu.CanCastAbility(slot4Ability) then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local radius = 700
	local castRange = slot4Ability:GetCastRange()
	local castPoint = slot4Ability:GetCastPoint()
	local manaCost = slot4Ability:GetManaCost()
	local enemyHeroes = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(enemyHeroes) do
		if
			Fu.CanCastOnNonMagicImmune(enemyHero)
			and Fu.CanCastOnTargetAdvanced(enemyHero)
			and enemyHero:IsChanneling()
		then
			return BOT_ACTION_DESIRE_HIGH, enemyHero, "AS-打断"
		end
	end
	if Fu.IsRetreating(bot) then
		local nearbyEnemyHeroes = Fu.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE)
		local firstEnemy = nearbyEnemyHeroes[1]
		if
			Fu.IsValidHero(firstEnemy)
			and Fu.CanCastOnNonMagicImmune(firstEnemy)
			and Fu.CanCastOnTargetAdvanced(firstEnemy)
			and not Fu.IsDisabled(firstEnemy)
		then
			return BOT_ACTION_DESIRE_HIGH, firstEnemy, "AS-撤退了"
		end
	end
	if Fu.IsInTeamFight(bot, 1400) and #nearbyEnemies >= 3 then
		local bestTarget = nil
		local highestDamage = 0
		for _, enemyHero in pairs(nearbyEnemies) do
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
			return BOT_ACTION_DESIRE_HIGH, bestTarget, "AS-团战控制"
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if Fu.IsValidHero(botTarget) and Fu.CanCastOnNonMagicImmune(botTarget) then
			if
				Fu.IsInRange(bot, botTarget, castRange)
				and not Fu.IsInRange(bot, botTarget, 600)
				and not Fu.IsDisabled(botTarget)
				and bot:IsFacingLocation(botTarget:GetLocation(), 30)
				and not botTarget:IsFacingLocation(bot:GetLocation(), 100)
			then
				return BOT_ACTION_DESIRE_HIGH, botTarget, "AS-追击"
			end
			local enemyHeroesInRange = Fu.GetNearbyHeroes(bot, castRange, true, BOT_ACTION_DESIRE_NONE)
			if #enemyHeroesInRange >= 2 then
				for _, enemyHero in pairs(enemyHeroesInRange) do
					if
						enemyHero ~= botTarget
						and Fu.CanCastOnNonMagicImmune(enemyHero)
						and not Fu.IsDisabled(enemyHero)
					then
						return BOT_ACTION_DESIRE_HIGH, enemyHero, "AS-睡眠敌方"
					end
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
return X
