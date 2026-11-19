-- Drow Ranger: skill build, item build, and ability use for this hero.
-- Accidental globals made file-local (#13): every bot shares one Lua state, so these were shared.
local botTarget, nDistance
local X = {}
local bot = GetBot()
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local AbilityContext = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local Minion = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local sTalentList = Fu.Skill.GetTalentList(bot)
local sAbilityList = Fu.Skill.GetAbilityList(bot)
local sRole = Fu.Item.GetRoleItemsBuyList(bot)
local tTalentTreeList = { ["t25"] = { 0, 10 }, ["t20"] = { 0, 10 }, ["t15"] = { 10, 0 }, ["t10"] = { 10, 0 } }
local tAllAbilityBuildList = { { 1, 3, 1, 2, 3, 6, 3, 3, 1, 1, 6, 2, 2, 2, 6 } }
local nAbilityBuildList = Fu.Skill.GetRandomBuild(tAllAbilityBuildList)
local nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList)
local sUtility = RandomInt(1, 2) == 1 and "item_black_king_bar" or "item_sphere"
local sRoleItemsBuyList = {}
sRoleItemsBuyList["pos_1"] = {
	"item_tango",
	"item_double_branches",
	"item_slippers",
	"item_circlet",
	"item_magic_wand",
	"item_wraith_band",
	"item_power_treads",
	"item_dragon_lance",
	"item_yasha",
	"item_manta",
	"item_ultimate_scepter",
	"item_force_staff",
	"item_hurricane_pike",
	sUtility,
	"item_butterfly",
	"item_hydras_breath",
	"item_aghanims_shard",
	"item_greater_crit",
	"item_moon_shard",
	"item_satanic",
	"item_ultimate_scepter_2",
	"item_travel_boots",
	"item_travel_boots_2",
}
sRoleItemsBuyList["pos_2"] = sRoleItemsBuyList["pos_1"]
sRoleItemsBuyList["pos_4"] = sRoleItemsBuyList["pos_1"]
sRoleItemsBuyList["pos_5"] = sRoleItemsBuyList["pos_1"]
sRoleItemsBuyList["pos_3"] = sRoleItemsBuyList["pos_1"]
X["sBuyList"] = sRoleItemsBuyList[sRole]
X["sSellList"] = { "item_satanic", "item_magic_wand" }
if Fu.Role.IsPvNMode() or Fu.Role.IsAllShadow() then
	X["sBuyList"], X["sSellList"] = { "PvN_ranged_carry" }, {}
end
nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"] =
	Fu.SetUserHeroInit(nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"])
X["sSkillList"] = Fu.Skill.GetSkillList(sAbilityList, nAbilityBuildList, sTalentList, nTalentBuildList)
X["bDeafaultAbility"] = false
X["bDeafaultItem"] = false
function X.MinionThink(hMinionUnit)
	Minion.MinionThink(hMinionUnit)
end
local frostArrowsAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[1]), "sAbilityList[1]", "drow_ranger")
local gustAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[2]), "sAbilityList[2]", "drow_ranger")
local multishotAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[3]), "sAbilityList[3]", "drow_ranger")
local glacierAbility = SafeAbility(bot:GetAbilityByName("drow_ranger_glacier"), "drow_ranger_glacier", "drow_ranger")
local maskOfMadnessItem = nil
local frostArrowsDesire, frostArrowsTarget
local gustDesire, gustLocation
local multishotDesire, multishotLocation
local glacierDesire
local maskOfMadnessDesire
local unusedDesire, unusedTarget
local botLevel, mpRatio, hpRatio, nearbyEnemies, nearbyAllies
function X.SkillsComplement()
	Fu.ConsiderForMkbDisassembleMask(bot)
	if Fu.CanNotUseAbility(bot) or bot:IsInvisible() then
		return
	end
	local context = AbilityContext.Build(bot)
	botLevel = context.level
	mpRatio = context.mp
	hpRatio = context.hp
	botTarget = context.target
	nearbyEnemies = context.enemies
	nearbyAllies = context.allies
	maskOfMadnessItem = Fu.IsItemAvailable("item_mask_of_madness")
	gustDesire, gustLocation = X.ConsiderW()
	if gustDesire > 0 then
		Fu.SetQueuePtToINT(bot, true)
		bot:ActionQueue_UseAbilityOnLocation(gustAbility, gustLocation)
		return
	end
	glacierDesire = X.ConsiderGlacier()
	if glacierDesire > 0 then
		Fu.SetQueuePtToINT(bot, true)
		bot:ActionQueue_UseAbility(glacierAbility)
		return
	end
	multishotDesire, multishotLocation = X.ConsiderE()
	if multishotDesire > 0 then
		Fu.SetQueuePtToINT(bot, true)
		bot:ActionQueue_UseAbilityOnLocation(multishotAbility, multishotLocation)
		return
	end
	maskOfMadnessDesire = X.ConsiderM()
	if maskOfMadnessDesire > 0 then
		Fu.SetQueuePtToINT(bot, true)
		bot:ActionQueue_UseAbility(maskOfMadnessItem)
		return
	end
	frostArrowsDesire, frostArrowsTarget = X.ConsiderQ()
	if frostArrowsDesire > 0 then
		bot:Action_ClearActions(false)
		bot:ActionQueue_UseAbilityOnEntity(frostArrowsAbility, frostArrowsTarget)
		return
	end
end
function X.ConsiderE()
	if not multishotAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
	end
	local castRange = 850
	local radius = 200
	local damage = 0
	local castPoint = multishotAbility:GetCastPoint()
	local abilityLevel = multishotAbility:GetLevel()
	local manaCost = multishotAbility:GetManaCost()
	local nTargetLocation = nil
	local enemiesInRange = Fu.GetNearbyHeroes(bot, castRange + 100, true, BOT_MODE_NONE)
	if Fu.IsGoingOnSomeone(bot) then
		local target = Fu.GetProperTarget(bot)
		if
			Fu.IsValidHero(target)
			and Fu.CanCastOnNonMagicImmune(target)
			and Fu.IsInRange(target, bot, castRange)
			and (target:IsFacingLocation(bot:GetLocation(), 120) or target:GetAttackTarget() ~= nil)
		then
			nTargetLocation = target:GetExtrapolatedLocation(castPoint)
			return BOT_ACTION_DESIRE_HIGH, nTargetLocation
		end
		local aoe = bot:FindAoELocation(true, true, bot:GetLocation(), 780, radius, castPoint, 0)
		if aoe.count >= 2 then
			nTargetLocation = aoe.targetloc
			return BOT_ACTION_DESIRE_HIGH, nTargetLocation
		end
	end
	if
		(Fu.IsPushing(bot) or Fu.IsDefending(bot) or Fu.IsFarming(bot))
		and Fu.IsAllowedToSpam(bot, 90)
		and DotaTime() > 8 * 60
		and #nearbyAllies <= 2
		and #nearbyEnemies == 0
	then
		local enemyLaneCreeps = bot:GetNearbyLaneCreeps(1400, true)
		if
			#enemyLaneCreeps >= 4
			and Fu.IsValid(enemyLaneCreeps[1])
			and not enemyLaneCreeps[1]:HasModifier("modifier_fountain_glyph")
		then
			local aoe = bot:FindAoELocation(true, false, bot:GetLocation(), 700, radius + 50, 0, 0)
			if aoe.count >= 3 then
				nTargetLocation = aoe.targetloc
				return BOT_ACTION_DESIRE_HIGH, nTargetLocation, "E-带线" .. aoe.count
			end
		end
	end
	if Fu.IsFarming(bot) and Fu.IsAllowedToSpam(bot, manaCost) then
		if Fu.IsValid(botTarget) and botTarget:GetTeam() == TEAM_NEUTRAL and Fu.IsInRange(bot, botTarget, 1000) then
			local requiredCount = mpRatio > 0.6 and 2 or 3
			local aoe = bot:FindAoELocation(true, false, bot:GetLocation(), 750, 300, 0, 0)
			if aoe.count >= requiredCount then
				nTargetLocation = aoe.targetloc
				return BOT_ACTION_DESIRE_HIGH, nTargetLocation, "E-打钱" .. aoe.count
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderWM()
	if
		botLevel < 15
		or maskOfMadnessItem == nil
		or not maskOfMadnessItem:IsFullyCastable()
		or not gustAbility:IsFullyCastable()
		or not frostArrowsAbility:GetAutoCastState()
	then
		return BOT_ACTION_DESIRE_NONE
	end
	local gustManaCost = gustAbility:GetManaCost()
	local maskManaCost = maskOfMadnessItem:GetManaCost()
	if maskManaCost + gustManaCost > bot:GetMana() then
		return 0
	end
	local castRange = gustAbility:GetCastRange()
	local castPoint = gustAbility:GetCastPoint()
	local radius = gustAbility:GetAOERadius()
	local enemyList = nearbyEnemies
	local closeEnemies = Fu.GetNearbyHeroes(bot, 500, true, BOT_MODE_NONE)
	local target = Fu.GetProperTarget(bot)
	local nTargetLocation = nil
	if
		Fu.IsGoingOnSomeone(bot)
		and #closeEnemies == 0
		and not Fu.IsEnemyTargetUnit(bot, 1600)
		and Fu.GetAllyCount(bot, 1000) >= 3
	then
		if
			Fu.IsValidHero(target)
			and not target:IsSilenced()
			and not Fu.IsDisabled(target)
			and Fu.CanCastOnNonMagicImmune(target)
			and Fu.IsInRange(target, bot, castRange)
			and target:IsFacingLocation(bot:GetLocation(), 150)
			and Fu.IsAllyHeroBetweenAllyAndEnemy(bot, target, target:GetLocation(), 500)
		then
			nTargetLocation = target:GetExtrapolatedLocation(castPoint)
			return BOT_ACTION_DESIRE_HIGH, nTargetLocation
		end
		local aoe = bot:FindAoELocation(true, true, bot:GetLocation(), castRange, radius, castPoint, 0)
		if aoe.count >= 2 then
			nTargetLocation = aoe.targetloc
			return BOT_ACTION_DESIRE_HIGH, nTargetLocation
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderW()
	if not gustAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
	end
	local castRange = gustAbility:GetCastRange()
	local radius = gustAbility:GetAOERadius()
	local damage = 0
	local castPoint = gustAbility:GetCastPoint()
	local nTargetLocation = nil
	local enemiesInRange = Fu.GetNearbyHeroes(bot, castRange + 100, true, BOT_MODE_NONE)
	for _, enemy in pairs(enemiesInRange) do
		if Fu.IsValid(enemy) and enemy:IsChanneling() and not enemy:HasModifier("modifier_teleporting") then
			nTargetLocation = enemy:GetLocation()
			return BOT_ACTION_DESIRE_HIGH, nTargetLocation
		end
	end
	if Fu.IsRetreating(bot) and not bot:IsInvisible() then
		for _, enemy in pairs(enemiesInRange) do
			if
				Fu.IsValidHero(enemy)
				and Fu.CanBeAttacked(enemy)
				and Fu.IsInRange(bot, enemy, castRange)
				and Fu.CanCastOnNonMagicImmune(enemy)
				and not Fu.IsDisabled(enemy)
				and not enemy:IsDisarmed()
				and not enemy:IsSilenced()
				and bot:WasRecentlyDamagedByHero(enemy, 2.0)
			then
				nTargetLocation = enemy:GetLocation()
				return BOT_ACTION_DESIRE_HIGH, nTargetLocation
			end
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		local target = Fu.GetProperTarget(bot)
		if
			Fu.IsValidHero(target)
			and Fu.CanBeAttacked(target)
			and Fu.IsInRange(target, bot, castRange)
			and Fu.CanCastOnNonMagicImmune(target)
			and not Fu.IsDisabled(target)
			and not target:IsSilenced()
		then
			nTargetLocation = target:GetLocation()
			return BOT_ACTION_DESIRE_HIGH, nTargetLocation
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function X.ConsiderM()
	if maskOfMadnessItem == nil or not maskOfMadnessItem:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
	end
	local attackRange = bot:GetAttackRange()
	local attackDamage = bot:GetAttackDamage()
	local damage = attackDamage
	local damageType = DAMAGE_TYPE_PHYSICAL
	local target = Fu.GetProperTarget(bot)
	if Fu.IsGoingOnSomeone(bot) and #nearbyEnemies == 1 then
		if
			Fu.IsValidHero(target)
			and Fu.CanBeAttacked(target)
			and Fu.CanCastOnNonMagicImmune(target)
			and not Fu.IsInRange(target, bot, 400)
			and Fu.IsInRange(target, bot, attackRange + 300)
			and bot:IsFacingLocation(target:GetLocation(), 30)
			and not target:IsFacingLocation(bot:GetLocation(), 30)
			and frostArrowsAbility:GetAutoCastState() == true
			and gustAbility:GetCooldownTimeRemaining() > 5.0
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsRunning(bot) or #nearbyEnemies > 0 then
		return BOT_ACTION_DESIRE_NONE
	end
	if bot:GetActiveMode() == BOT_MODE_ROSHAN then
		if Fu.IsRoshan(target) and Fu.IsInRange(target, bot, attackRange + 99) then
			return BOT_ACTION_DESIRE_LOW
		end
	end
	if Fu.IsValidBuilding(target) and Fu.IsInRange(target, bot, attackRange + 199) then
		return BOT_ACTION_DESIRE_LOW
	end
	if Fu.IsPushing(bot) or Fu.IsDefending(bot) or Fu.IsFarming(bot) then
		local nearbyCreeps = bot:GetNearbyCreeps(800, true)
		if
			Fu.IsValid(target)
			and Fu.IsInRange(target, bot, attackRange + 99)
			and (#nearbyCreeps >= 2 or target:GetHealth() > attackDamage * 2.28)
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
local lastAutoCastOnTime = 0
function X.ConsiderQ()
	if not frostArrowsAbility:IsFullyCastable() or bot:IsDisarmed() or Fu.GetDistanceFromEnemyFountain(bot) < 800 then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local attackRange = bot:GetAttackRange() + 40
	local attackDamage = bot:GetAttackDamage() + frostArrowsAbility:GetSpecialValueInt("damage")
	local damageType = DAMAGE_TYPE_PHYSICAL
	local nearbyEnemyTowers = bot:GetNearbyTowers(900, true)
	local laneCreepsInRange = bot:GetNearbyLaneCreeps(attackRange + 30, true)
	local closeLaneCreeps = bot:GetNearbyLaneCreeps(400, true)
	local weakestCreep = Fu.GetAttackableWeakestUnit(bot, attackRange + 30, false, true)
	local weakestCreepHealth = 10000
	if weakestCreep ~= nil then
		weakestCreepHealth = weakestCreep:GetHealth()
	end
	local enemiesInRange = Fu.GetNearbyHeroes(bot, attackRange, true, BOT_MODE_NONE)
	local weakestHeroInRange = Fu.GetAttackableWeakestUnit(bot, attackRange, true, true)
	local weakestHeroNearby = Fu.GetAttackableWeakestUnit(bot, 800, true, true)
	local allyLaneCreeps = bot:GetNearbyLaneCreeps(330, false)
	local target = Fu.GetProperTarget(bot)
	local frostTarget = nil
	local botMode = bot:GetActiveMode()
	if botLevel >= 8 then
		if (nearbyEnemies[1] ~= nil or mpRatio > 0.76) and not frostArrowsAbility:GetAutoCastState() then
			lastAutoCastOnTime = DotaTime()
			frostArrowsAbility:ToggleAutoCast()
		elseif
			nearbyEnemies[1] == nil
			and mpRatio < 0.7
			and lastAutoCastOnTime + 3.0 < DotaTime()
			and frostArrowsAbility:GetAutoCastState()
		then
			frostArrowsAbility:ToggleAutoCast()
		end
	else
		if frostArrowsAbility:GetAutoCastState() then
			frostArrowsAbility:ToggleAutoCast()
		end
	end
	if
		botLevel <= 7
		and hpRatio > 0.55
		and Fu.IsValidHero(target)
		and (not Fu.IsRunning(bot) or Fu.IsInRange(bot, target, attackRange + 18))
	then
		if not target:IsAttackImmune() and Fu.IsInRange(bot, target, attackRange + 99) then
			frostTarget = target
			return BOT_ACTION_DESIRE_HIGH, frostTarget
		end
	end
	if botMode == BOT_MODE_LANING and #nearbyEnemyTowers == 0 then
		if Fu.IsValid(weakestHeroInRange) then
			if
				weakestCreepHealth > 130
				and hpRatio >= 0.6
				and #closeLaneCreeps <= 3
				and #allyLaneCreeps >= 2
				and not bot:WasRecentlyDamagedByCreep(1.5)
				and not bot:WasRecentlyDamagedByAnyHero(1.5)
			then
				frostTarget = weakestHeroInRange
				return BOT_ACTION_DESIRE_HIGH, frostTarget
			end
		end
		if Fu.IsValid(weakestHeroNearby) then
			if
				weakestCreepHealth > 180
				and hpRatio >= 0.7
				and #closeLaneCreeps <= 2
				and #allyLaneCreeps >= 3
				and not bot:WasRecentlyDamagedByCreep(1.5)
				and not bot:WasRecentlyDamagedByAnyHero(1.5)
				and not bot:WasRecentlyDamagedByTower(1.5)
			then
				frostTarget = weakestHeroNearby
				return BOT_ACTION_DESIRE_HIGH, frostTarget
			end
			if
				Fu.GetUnitAllyCountAroundEnemyTarget(weakestHeroNearby, 500) >= 4
				and not bot:WasRecentlyDamagedByCreep(1.5)
				and not bot:WasRecentlyDamagedByAnyHero(1.5)
				and not bot:WasRecentlyDamagedByTower(1.5)
				and hpRatio >= 0.6
			then
				frostTarget = weakestHeroNearby
				return BOT_ACTION_DESIRE_HIGH, frostTarget
			end
		end
		if Fu.IsWithoutTarget(bot) and not Fu.IsAttacking(bot) then
			local enemyLaneCreeps = bot:GetNearbyLaneCreeps(1100, true)
			for _, creep in pairs(enemyLaneCreeps) do
				if
					Fu.IsValid(creep)
					and not creep:HasModifier("modifier_fountain_glyph")
					and creep:GetHealth() < attackDamage + 180
					and not Fu.IsAllysTarget(creep)
				then
					local attackDelay = Fu.GetAttackProDelayTime(bot, creep) * 1.08 + 0.08
					local expectedDamage = attackDamage * 1.0
					if Fu.WillKillTarget(creep, expectedDamage, damageType, attackDelay) then
						return BOT_ACTION_DESIRE_HIGH, creep
					end
				end
			end
		end
	end
	if
		target ~= nil
		and target:IsHero()
		and GetUnitToUnitDistance(target, bot) > attackRange + 160
		and Fu.IsValid(weakestHeroInRange)
		and not weakestHeroInRange:IsAttackImmune()
	then
		frostTarget = weakestHeroInRange
		bot:SetTarget(frostTarget)
		return BOT_ACTION_DESIRE_HIGH, frostTarget
	end
	if bot:HasModifier("modifier_item_hurricane_pike_range") and Fu.IsValid(target) then
		frostTarget = target
		return BOT_ACTION_DESIRE_HIGH, frostTarget
	end
	if
		bot:GetAttackTarget() == nil
		and bot:GetTarget() == nil
		and #nearbyEnemies == 0
		and botMode ~= BOT_MODE_RETREAT
		and botMode ~= BOT_MODE_ATTACK
		and botMode ~= BOT_MODE_ASSEMBLE
		and botMode ~= BOT_MODE_FARM
		and botMode ~= BOT_MODE_TEAM_ROAM
		and Fu.GetTeamFightAlliesCount(bot) < 3
		and bot:GetMana() >= 180
		and not bot:WasRecentlyDamagedByAnyHero(3.0)
	then
		if bot:HasScepter() then
			local nearbyCreeps = bot:GetNearbyCreeps(1600, true)
			if Fu.IsValid(nearbyCreeps[1]) then
				frostTarget = nearbyCreeps[1]
				return BOT_ACTION_DESIRE_HIGH, frostTarget
			end
		end
		local neutralCreeps = bot:GetNearbyNeutralCreeps(1600)
		if
			botMode ~= BOT_MODE_LANING
			and botLevel >= 6
			and hpRatio > 0.25
			and Fu.IsValid(neutralCreeps[1])
			and not Fu.IsRoshan(neutralCreeps[1])
			and (neutralCreeps[1]:IsAncientCreep() == false or botLevel >= 12)
		then
			frostTarget = neutralCreeps[1]
			return BOT_ACTION_DESIRE_HIGH, frostTarget
		end
		local farLaneCreeps = bot:GetNearbyLaneCreeps(1600, true)
		if
			botMode ~= BOT_MODE_LANING
			and botLevel >= 6
			and hpRatio > 0.25
			and Fu.IsValid(farLaneCreeps[1])
			and bot:GetAttackDamage() > 130
		then
			frostTarget = farLaneCreeps[1]
			return BOT_ACTION_DESIRE_HIGH, frostTarget
		end
	end
	if botMode == BOT_MODE_RETREAT then
		nDistance = 999
		local slowTarget = nil
		for _, enemy in pairs(enemiesInRange) do
			if
				Fu.IsValid(enemy)
				and enemy:HasModifier("modifier_drowranger_wave_of_silence_knockback")
				and GetUnitToUnitDistance(enemy, bot) < nDistance
			then
				slowTarget = enemy
				nDistance = GetUnitToUnitDistance(enemy, bot)
			end
		end
		if slowTarget ~= nil and not slowTarget:HasModifier("modifier_drow_ranger_frost_arrows_slow") then
			return BOT_ACTION_DESIRE_HIGH, slowTarget
		end
	end
	if Fu.IsFarming(bot) and mpRatio > 0.55 and not frostArrowsAbility:GetAutoCastState() then
		if
			Fu.IsValid(botTarget)
			and botTarget:GetTeam() == TEAM_NEUTRAL
			and Fu.IsInRange(bot, botTarget, 1000)
			and botTarget:GetHealth() > attackDamage
		then
			return BOT_ACTION_DESIRE_LOW, botTarget, "Q-打野"
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function X.ConsiderGlacier()
	if not glacierAbility:IsTrained() or not glacierAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
	end
	local attackRange = bot:GetAttackRange()
	local enemiesInRange = Fu.GetNearbyHeroes(bot, attackRange, true, BOT_MODE_NONE)
	local attackingEnemies = Fu.GetNearbyHeroes(bot, attackRange, true, BOT_MODE_ATTACK)
	botTarget = Fu.GetProperTarget(bot)
	local nearbyAllies = Fu.GetAlliesNearLoc(bot:GetLocation(), 500)
	-- #enemiesInRange >= 1: an ally within 500 alone cast it (any desire above 0 casts), so Glacier went out every
	-- 25s in lane or while farming with no enemy hero near. Now only with an enemy hero in range.
	if #nearbyAllies > 1 and #enemiesInRange >= 1 then
		return BOT_ACTION_DESIRE_LOW
	end
	if Fu.IsRetreating(bot) and (#enemiesInRange ~= nil and #enemiesInRange >= 2 or Fu.GetHP(bot) < 0.3) then
		if attackingEnemies ~= nil and #attackingEnemies >= 1 then
			return BOT_ACTION_DESIRE_LOW
		end
		return BOT_ACTION_DESIRE_HIGH
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidTarget(botTarget)
			and (multishotAbility:IsFullyCastable() and Fu.CanCastOnNonMagicImmune(botTarget))
			and Fu.IsInRange(bot, botTarget, multishotAbility:GetCastRange() + 200)
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
return X
