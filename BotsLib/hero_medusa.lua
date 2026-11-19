-- Medusa: skill build, item build, and ability use for this hero.
local X = {}
local bot = GetBot()
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local AbilityContext = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local Minion = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local sTalentList = Fu.Skill.GetTalentList(bot)
local sAbilityList = Fu.Skill.GetAbilityList(bot)
local sRole = Fu.Item.GetRoleItemsBuyList(bot)
local tTalentTreeList = { ["t25"] = { 10, 0 }, ["t20"] = { 0, 10 }, ["t15"] = { 10, 0 }, ["t10"] = { 10, 0 } }
-- 1 Split Shot, 2 Mystic Snake, 3 Gorgon's Grasp, 6 Stone Gaze. Snake maxed first (levels 1/3/5/7),
-- Split Shot second, Grasp last (Dotabuff most picked order). The old order put Snake at levels 4
-- and 5, which the hero level does not allow yet. Ultimate at entries 6/11/15 (levels 6/12/18).
local tAllAbilityBuildList = { { 2, 3, 2, 1, 2, 6, 2, 1, 1, 1, 6, 3, 3, 3, 6 } }
local nAbilityBuildList = Fu.Skill.GetRandomBuild(tAllAbilityBuildList)
local nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList)
local sRoleItemsBuyList = {}
sRoleItemsBuyList["pos_1"] = {
	"item_tango",
	"item_double_branches",
	"item_null_talisman",
	"item_null_talisman",
	"item_magic_wand",
	"item_ring_of_basilius",
	"item_power_treads",
	"item_manta",
	"item_dragon_lance",
	"item_hurricane_pike",
	"item_skadi",
	"item_aghanims_shard",
	"item_butterfly",
	"item_ultimate_scepter",
	"item_greater_crit",
	"item_travel_boots",
	"item_monkey_king_bar",
	"item_moon_shard",
	"item_travel_boots_2",
	"item_ultimate_scepter_2",
}
sRoleItemsBuyList["pos_2"] = {
	"item_medusa_outfit",
	"item_dragon_lance",
	"item_hurricane_pike",
	"item_ultimate_scepter",
	"item_aghanims_shard",
	"item_manta",
	"item_mjollnir",
	"item_travel_boots",
	"item_skadi",
	"item_ultimate_scepter_2",
	"item_moon_shard",
	"item_butterfly",
	"item_hydras_breath",
	"item_travel_boots_2",
}
sRoleItemsBuyList["pos_4"] = sRoleItemsBuyList["pos_2"]
sRoleItemsBuyList["pos_5"] = sRoleItemsBuyList["pos_2"]
sRoleItemsBuyList["pos_3"] = sRoleItemsBuyList["pos_2"]
X["sBuyList"] = sRoleItemsBuyList[sRole]
X["sSellList"] = { "item_black_king_bar", "item_quelling_blade" }
if Fu.Role.IsPvNMode() or Fu.Role.IsAllShadow() then
	X["sBuyList"], X["sSellList"] = { "PvN_mid" }, {}
end
nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"] =
	Fu.SetUserHeroInit(nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"])
X["sSkillList"] = Fu.Skill.GetSkillList(sAbilityList, nAbilityBuildList, sTalentList, nTalentBuildList)
X["bDeafaultAbility"] = false
-- Cast when cornered (retreating into 3+ enemies with no way out), before running further.
X["LastStandSpells"] = { { name = "medusa_stone_gaze", kind = "none" } }
X["bDeafaultItem"] = false
function X.MinionThink(minionUnit)
	Minion.MinionThink(minionUnit)
end
local splitShotAbility = SafeAbility(bot:GetAbilityByName("medusa_split_shot"), "medusa_split_shot", "medusa")
local mysticSnakeAbility = SafeAbility(bot:GetAbilityByName("medusa_mystic_snake"), "medusa_mystic_snake", "medusa")
local stoneGazeAbility = SafeAbility(bot:GetAbilityByName("medusa_stone_gaze"), "medusa_stone_gaze", "medusa")
local unusedAbility = nil
local gorgonGraspAbility = SafeAbility(bot:GetAbilityByName("medusa_gorgon_grasp"), "medusa_gorgon_grasp", "medusa")
local splitShotDesire
local mysticSnakeDesire, mysticSnakeTarget
local unusedDesire
local stoneGazeDesire
local gorgonGraspDesire, gorgonGraspLocation
local hpRatio
local aetherRange = 0
local botTarget
function X.SkillsComplement()
	Fu.ConsiderForMkbDisassembleMask(bot)
	Fu.ConsiderTarget()
	if Fu.CanNotUseAbility(bot) or bot:IsInvisible() then
		return
	end
	splitShotAbility = SafeAbility(bot:GetAbilityByName("medusa_split_shot"), "medusa_split_shot", "medusa")
	mysticSnakeAbility = SafeAbility(bot:GetAbilityByName("medusa_mystic_snake"), "medusa_mystic_snake", "medusa")
	stoneGazeAbility = SafeAbility(bot:GetAbilityByName("medusa_stone_gaze"), "medusa_stone_gaze", "medusa")
	gorgonGraspAbility = SafeAbility(bot:GetAbilityByName("medusa_gorgon_grasp"), "medusa_gorgon_grasp", "medusa")
	local context = AbilityContext.Build(bot)
	hpRatio = context.hp
	mysticSnakeDesire, mysticSnakeTarget = X.ConsiderW()
	if mysticSnakeDesire > 0 then
		Fu.SetQueuePtToINT(bot, true)
		bot:ActionQueue_UseAbilityOnEntity(mysticSnakeAbility, mysticSnakeTarget)
		return
	end
	stoneGazeDesire = X.ConsiderR()
	if stoneGazeDesire > 0 then
		Fu.SetQueuePtToINT(bot, true)
		bot:ActionQueue_UseAbility(stoneGazeAbility)
		return
	end
	gorgonGraspDesire, gorgonGraspLocation = X.ConsiderGorgonGrasp()
	if gorgonGraspDesire > 0 then
		Fu.SetQueuePtToINT(bot, false)
		bot:ActionQueue_UseAbilityOnLocation(gorgonGraspAbility, gorgonGraspLocation)
		return
	end
	splitShotDesire = X.ConsiderQ()
	if splitShotDesire > 0 then
		bot:Action_UseAbility(splitShotAbility)
		return
	end
end
function X.ConsiderGorgonGrasp()
	if not gorgonGraspAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local castRange = Fu.GetProperCastRange(false, bot, gorgonGraspAbility:GetCastRange())
	local castPoint = gorgonGraspAbility:GetCastPoint()
	local delay = gorgonGraspAbility:GetSpecialValueInt("delay")
	local damage = gorgonGraspAbility:GetSpecialValueInt("damage")
	local damagePerSecond = gorgonGraspAbility:GetSpecialValueInt("damage_pers")
	-- Float: duration is 0.8/1.2/1.6/2.0 (game data); the Int read gave 0/1/1/2 and undercounted the kill damage.
	local duration = gorgonGraspAbility:GetSpecialValueFloat("duration")
	botTarget = Fu.GetProperTarget(bot)
	local nearbyAllyHeroes = bot:GetNearbyHeroes(1600, false, BOT_MODE_NONE)
	local nearbyEnemyHeroes = bot:GetNearbyHeroes(1600, true, BOT_MODE_NONE)
	local totalDelay = castPoint + delay
	for _, enemyHero in pairs(nearbyEnemyHeroes) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.IsInRange(bot, enemyHero, castRange)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
		then
			if enemyHero:HasModifier("modifier_teleporting") then
				if Fu.GetModifierTime(enemyHero, "modifier_teleporting") > delay + castPoint then
					return BOT_ACTION_DESIRE_HIGH, enemyHero:GetLocation()
				end
			elseif enemyHero:IsChanneling() then
				return BOT_ACTION_DESIRE_HIGH, enemyHero:GetLocation()
			end
			if
				Fu.CanKillTarget(enemyHero, damage + damagePerSecond * duration, DAMAGE_TYPE_PHYSICAL)
				and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
				and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
				and not enemyHero:HasModifier("modifier_enigma_black_hole_pull")
				and not enemyHero:HasModifier("modifier_faceless_void_chronosphere_freeze")
				and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
			then
				return BOT_ACTION_DESIRE_HIGH, enemyHero:GetLocation()
			end
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidHero(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and not Fu.IsDisabled(botTarget)
			and not botTarget:HasModifier("modifier_enigma_black_hole_pull")
			and not botTarget:HasModifier("modifier_faceless_void_chronosphere_freeze")
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
			and (botTarget:GetCurrentMovementSpeed() <= 250 or Fu.IsInRange(bot, botTarget, castRange * 0.55))
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	if Fu.IsRetreating(bot) and not Fu.IsRealInvisible(bot) then
		for _, enemyHero in pairs(nearbyEnemyHeroes) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.IsInRange(bot, enemyHero, castRange)
				and not Fu.IsInRange(bot, enemyHero, castRange * 0.3)
				and bot:WasRecentlyDamagedByHero(enemyHero, 3.0)
				and (Fu.IsChasingTarget(enemyHero, bot) or Fu.GetHP(bot) < 0.5)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and not Fu.IsDisabled(enemyHero)
				and not enemyHero:HasModifier("modifier_enigma_black_hole_pull")
				and not enemyHero:HasModifier("modifier_faceless_void_chronosphere_freeze")
				and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
			then
				return BOT_ACTION_DESIRE_HIGH, (bot:GetLocation() + enemyHero:GetLocation()) / 2
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.ConsiderQ()
	if not splitShotAbility:IsFullyCastable() then
		return 0
	end
	local splitShotRange = bot:GetAttackRange() + 150
	local abilityLevel = splitShotAbility:GetLevel()
	local enemyHeroesInRange = Fu.GetNearbyHeroes(bot, splitShotRange, true, BOT_MODE_NONE)
	local creepsInRange = bot:GetNearbyCreeps(splitShotRange, true)
	local laneCreepsInRange = bot:GetNearbyLaneCreeps(splitShotRange, true)
	local allyLaneCreeps = bot:GetNearbyLaneCreeps(800, false)
	botTarget = Fu.GetProperTarget(bot)
	-- Off when only one enemy unit (hero or creep) is in Split Shot reach (attack range + 150,
	-- Valve data): the extra arrows have nothing to hit and the main one loses damage.
	local units = #enemyHeroesInRange + #creepsInRange
	if
		Fu.IsLaning(bot)
		or units <= 1
		or Fu.IsGoingOnSomeone(bot) and Fu.IsValidHero(botTarget) and abilityLevel <= 2 and #enemyHeroesInRange == 2
		or #enemyHeroesInRange == 0 and #laneCreepsInRange >= 2 and #allyLaneCreeps >= 1 and abilityLevel <= 3
	then
		if splitShotAbility:GetToggleState() then
			return BOT_ACTION_DESIRE_HIGH
		end
	else
		if not splitShotAbility:GetToggleState() then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
local function FindSnakeBounceCreep(castRange, radius, jumpCount)
	local bounceCreep = nil
	local bounceCount = 0
	local searchRadius = radius * 1.2
	local creeps = bot:GetNearbyCreeps(castRange + searchRadius, true)
	if #creeps < jumpCount then
		local firstCreep = creeps[1]
		if Fu.IsValid(firstCreep) then
			local enemiesNearCreep = #Fu.GetEnemiesNearLoc(firstCreep:GetLocation(), searchRadius)
			if enemiesNearCreep >= 1 then
				bounceCreep = firstCreep
				bounceCount = math.min(#creeps + enemiesNearCreep, jumpCount)
			end
		end
	elseif #creeps >= jumpCount then
		if (Fu.IsFarming(bot) or Fu.IsPushing(bot)) and Fu.IsValid(creeps[1]) then
			return creeps[1], #creeps
		end
	end
	return bounceCreep, bounceCount
end
function X.ConsiderW()
	if not mysticSnakeAbility:IsFullyCastable() then
		return 0
	end
	local castRange = mysticSnakeAbility:GetCastRange() + 20
	local snakeJumps = mysticSnakeAbility:GetSpecialValueInt("snake_jumps")
	local snakeDamage = mysticSnakeAbility:GetSpecialValueInt("snake_damage")
	local radius = mysticSnakeAbility:GetSpecialValueInt("radius")
	local abilityLevel = mysticSnakeAbility:GetLevel()
	if Fu.IsRetreating(bot) then
		local enemiesInRange = Fu.GetNearbyHeroes(bot, castRange - 200, true, BOT_MODE_NONE)
		for _, enemyHero in pairs(enemiesInRange) do
			if
				Fu.IsValidHero(enemyHero)
				and bot:WasRecentlyDamagedByHero(enemyHero, 3.0)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
			then
				return BOT_ACTION_DESIRE_MODERATE, enemyHero
			end
		end
	end
	-- Grouped heroes: the snake jumps between enemies within 450 and gains 25% per jump.
	-- Start it on the hero nearest the middle of the group, in any fight, not only a team fight.
	local group = bot:FindAoELocation(true, true, bot:GetLocation(), castRange, radius, 0, 0)
	if group ~= nil and group.count >= 2 then
		local best, bestDist = nil, math.huge
		for _, enemyHero in pairs(Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE) or {}) do
			if
				Fu.IsValidHero(enemyHero)
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
			then
				local dist = GetUnitToLocationDistance(enemyHero, group.targetloc)
				if dist < bestDist then
					best, bestDist = enemyHero, dist
				end
			end
		end
		if best ~= nil then
			X.LogSnake("group", best, group.count)
			return BOT_ACTION_DESIRE_HIGH, best
		end
	end
	-- Lane poke: the snake gives back mana from what it hits, so a hero in range is worth it
	-- while she keeps enough mana for Mana Shield.
	if Fu.IsInLaningPhase() and Fu.GetManaAfter(mysticSnakeAbility:GetManaCost()) >= 0.45 then
		for _, enemyHero in pairs(Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE) or {}) do
			if
				Fu.IsValidHero(enemyHero)
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
			then
				X.LogSnake("lane-poke", enemyHero, 1)
				return BOT_ACTION_DESIRE_MODERATE, enemyHero
			end
		end
	end
	if Fu.IsInTeamFight(bot, 1200) then
		local maxManaTarget = nil
		local maxMana = 0
		local enemiesInRange = Fu.GetNearbyHeroes(bot, castRange + 50, true, BOT_MODE_NONE)
		for _, enemyHero in pairs(enemiesInRange) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
			then
				local enemyMaxMana = enemyHero:GetMaxMana()
				if enemyMaxMana > maxMana then
					maxMana = enemyMaxMana
					maxManaTarget = enemyHero
				end
			end
		end
		if maxManaTarget ~= nil then
			return BOT_ACTION_DESIRE_HIGH, maxManaTarget
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		local target = Fu.GetProperTarget(bot)
		if Fu.IsValidHero(target) and Fu.CanCastOnNonMagicImmune(target) and Fu.CanCastOnTargetAdvanced(target) then
			local bounceCreep, bounceCount = FindSnakeBounceCreep(castRange, radius, snakeJumps)
			if bounceCreep and Fu.IsInRange(bounceCreep, bot, castRange + 50) then
				return BOT_ACTION_DESIRE_HIGH, bounceCreep
			end
			-- Was "return ..., bounceCreep": bounceCreep is nil when no creep bounce exists, which sent a cast
			-- with no target (refused=nil-target). The target itself is the fallback.
			if Fu.IsInRange(target, bot, castRange + 50) then
				return BOT_ACTION_DESIRE_HIGH, target
			end
		end
	end
	local bounceCreep, bounceCount = FindSnakeBounceCreep(castRange, radius, snakeJumps)
	if bounceCreep and Fu.IsInRange(bounceCreep, bot, castRange + 50) then
		return BOT_ACTION_DESIRE_HIGH, bounceCreep
	end
	if abilityLevel >= 3 then
		local aoe = bot:FindAoELocation(true, false, bot:GetLocation(), castRange * 2, radius * 1.2, 0, 0)
		local requiredCount = 5
		local nearbyCreeps = bot:GetNearbyCreeps(castRange, true)
		local enemyLaneCreeps = bot:GetNearbyLaneCreeps(1600, true)
		if abilityLevel == 4 then
			requiredCount = 4
		end
		if bot:GetLevel() >= 20 or Fu.GetMP(bot) > 0.88 then
			requiredCount = 3
		end
		if aoe.count >= requiredCount then
			if
				Fu.IsValid(nearbyCreeps[1])
				and Fu.CanCastOnNonMagicImmune(nearbyCreeps[1])
				and not (nearbyCreeps[1]:GetTeam() == TEAM_NEUTRAL and #enemyLaneCreeps >= 1)
				and Fu.GetAroundTargetEnemyUnitCount(nearbyCreeps[1], 470) >= 2
			then
				return BOT_ACTION_DESIRE_HIGH, nearbyCreeps[1]
			end
		end
		if #nearbyCreeps >= 2 and abilityLevel >= 3 then
			local creepsIn1400 = bot:GetNearbyCreeps(1400, true)
			local enemiesIn1000 = Fu.GetNearbyHeroes(bot, 1000, true, BOT_MODE_NONE)
			if
				Fu.IsValid(nearbyCreeps[1])
				and #creepsIn1400 + #enemiesIn1000 >= 4
				and Fu.CanCastOnNonMagicImmune(nearbyCreeps[1])
				and not (nearbyCreeps[1]:GetTeam() == TEAM_NEUTRAL and #enemyLaneCreeps >= 1)
				and Fu.GetAroundTargetEnemyUnitCount(nearbyCreeps[1], 470) >= 2
			then
				return BOT_ACTION_DESIRE_HIGH, nearbyCreeps[1]
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
-- [OHA-MEDUSA]: Mystic Snake casts from the group and lane-poke rules, once per 10s per rule.
function X.LogSnake(why, target, heroes)
	bot._snakeLogAt = bot._snakeLogAt or {}
	if DotaTime() < (bot._snakeLogAt[why] or -999) then
		return
	end
	bot._snakeLogAt[why] = DotaTime() + 10
	pcall(
		print,
		string.format(
			"[OHA-MEDUSA] t=%.0f mystic-snake why=%s target=%s heroes=%d mp=%.2f",
			DotaTime(),
			why,
			(string.gsub(target:GetUnitName(), "npc_dota_hero_", "")),
			heroes,
			Fu.GetMP(bot)
		)
	)
end
-- [OHA-MEDUSA]: each Stone Gaze with why and how many heroes were looking at her.
function X.LogGaze(why, looking)
	pcall(
		print,
		string.format(
			"[OHA-MEDUSA] t=%.0f stone-gaze why=%s looking=%d hp=%.2f mp=%.2f",
			DotaTime(),
			why,
			looking,
			Fu.GetHP(bot),
			Fu.GetMP(bot)
		)
	)
end
function X.ConsiderR()
	if not stoneGazeAbility:IsFullyCastable() then
		return 0
	end
	local radius = stoneGazeAbility:GetSpecialValueInt("radius")
	if radius == nil or radius <= 0 then
		radius = 1200
	end
	local attackRange = bot:GetAttackRange()
	-- Stone Gaze works on anyone in 1200 who looks at her: slowed at once, stone after 2s of
	-- looking. A hero attacking or chasing her is looking at her by definition. The old gate
	-- only counted enemies inside her attack range facing her within 50 degrees.
	local looking = 0
	for _, enemyHero in pairs(Fu.GetNearbyHeroes(bot, radius, true, BOT_MODE_NONE) or {}) do
		if
			Fu.IsValidHero(enemyHero)
			and not Fu.IsSuspiciousIllusion(enemyHero)
			-- Was CanCastOnNonMagicImmune: Stone Gaze is SPELL_IMMUNITY_ENEMIES_YES in the game data
			-- (it pierces debuff immunity), so a BKB carry hitting her counts as looking too.
			and not enemyHero:IsInvulnerable()
			and (
				enemyHero:GetAttackTarget() == bot
				or Fu.IsChasingTarget(enemyHero, bot)
				or enemyHero:IsFacingLocation(bot:GetLocation(), 45)
			)
		then
			looking = looking + 1
		end
	end
	if looking == 0 then
		return 0
	end
	local fighting = Fu.IsInTeamFight(bot, 1200) or Fu.IsGoingOnSomeone(bot) or bot:WasRecentlyDamagedByAnyHero(2.0)
	-- Two or more heroes looking at her in a fight: that is most of the ult's value.
	if fighting and looking >= 2 then
		X.LogGaze("group", looking)
		return BOT_ACTION_DESIRE_HIGH
	end
	-- Low and being hit: petrify the attacker and take the speed boost.
	if looking >= 1 and hpRatio < 0.45 and bot:WasRecentlyDamagedByAnyHero(2.0) then
		X.LogGaze("survive", looking)
		return BOT_ACTION_DESIRE_HIGH
	end
	if Fu.IsRetreating(bot) then
		local enemies = Fu.GetNearbyHeroes(bot, 1000, true, BOT_MODE_NONE)
		for _, enemyHero in pairs(enemies) do
			if bot:WasRecentlyDamagedByHero(enemyHero, 2.0) and enemyHero:IsFacingLocation(bot:GetLocation(), 20) then
				return BOT_ACTION_DESIRE_MODERATE
			end
		end
	end
	if Fu.IsInTeamFight(bot, 1200) or Fu.IsGoingOnSomeone(bot) then
		local aoe = bot:FindAoELocation(true, true, bot:GetLocation(), attackRange, 400, 0, 0)
		if aoe.count >= 2 then
			local unitsInAoe = Fu.GetInvUnitInLocCount(bot, attackRange + 200, 400, aoe.targetloc, true)
			if unitsInAoe >= aoe.count then
				return BOT_ACTION_DESIRE_MODERATE
			end
		end
		local enemiesIn800 = Fu.GetNearbyHeroes(bot, 800, true, BOT_MODE_NONE)
		if #enemiesIn800 >= 3 then
			return BOT_ACTION_DESIRE_HIGH
		end
		local aoeNear = bot:FindAoELocation(true, true, bot:GetLocation(), 10, 700, 1.0, 0)
		if aoeNear.count >= 3 then
			return BOT_ACTION_DESIRE_HIGH
		end
		local target = Fu.GetProperTarget(bot)
		if
			Fu.IsValidHero(target)
			and Fu.CanCastOnNonMagicImmune(target)
			and not Fu.IsDisabled(target)
			and GetUnitToUnitDistance(target, bot) <= bot:GetAttackRange()
			and target:GetHealth() > 600
			and target:GetPrimaryAttribute() ~= ATTRIBUTE_INTELLECT
			and target:IsFacingLocation(bot:GetLocation(), 30)
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.GetHurtCount(startUnit, maxJumps)
	local enemyHeroes = Fu.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE)
	local enemyCreeps = bot:GetNearbyCreeps(1600, true, BOT_MODE_NONE)
	local hitUnits = {}
	table.insert(hitUnits, startUnit)
	local hurtCount = 1
	for _ = 1, maxJumps do
		local nextUnit = X.GetNearestUnit(startUnit, enemyHeroes, enemyCreeps, hitUnits)
		if nextUnit ~= nil and GetUnitToUnitDistance(startUnit, nextUnit) <= 475 then
			hurtCount = hurtCount + 1
			table.insert(hitUnits, nextUnit)
		else
			break
		end
	end
	return hurtCount
end
function X.GetNearestUnit(unit, heroes, creeps, excluded)
	local nearestUnit = nil
	local nearestDistance = 9999
	for _, candidate in pairs(heroes) do
		if
			candidate ~= nil
			and candidate:IsAlive()
			and not X.IsExistInTable(candidate, excluded)
			and GetUnitToUnitDistance(unit, candidate) < nearestDistance
		then
			nearestUnit = candidate
			nearestDistance = GetUnitToUnitDistance(unit, candidate)
		end
	end
	for _, candidate in pairs(creeps) do
		if
			candidate ~= nil
			and candidate:IsAlive()
			and not X.IsExistInTable(candidate, excluded)
			and GetUnitToUnitDistance(unit, candidate) < nearestDistance
		then
			nearestUnit = candidate
			nearestDistance = GetUnitToUnitDistance(unit, candidate)
		end
	end
	return nearestUnit
end
function X.IsExistInTable(value, list)
	for _, element in pairs(list) do
		if element == value then
			return true
		end
	end
	return false
end
return X
