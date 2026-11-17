-- Huskar: skill build, item build, and ability use for this hero.
local X = {}
local bot = GetBot()
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local AbilityContext = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local Minion = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local sTalentList = Fu.Skill.GetTalentList(bot)
local sAbilityList = Fu.Skill.GetAbilityList(bot)
local sRole = Fu.Item.GetRoleItemsBuyList(bot)
local tTalentTreeList = { ["t25"] = { 10, 0 }, ["t20"] = { 10, 0 }, ["t15"] = { 0, 10 }, ["t10"] = { 0, 10 } }
-- Life Break moved to entry 11 (level 12); it sat at entry 12 (level 13), a level late.
local tAllAbilityBuildList = { { 1, 3, 2, 2, 3, 6, 3, 3, 2, 2, 6, 1, 1, 1, 6 } }
local nAbilityBuildList = Fu.Skill.GetRandomBuild(tAllAbilityBuildList)
local nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList)
local sRoleItemsBuyList = {}
sRoleItemsBuyList["pos_2"] = {
	"item_tango",
	"item_faerie_fire",
	"item_gauntlets",
	"item_gauntlets",
	"item_gauntlets",
	"item_power_treads",
	"item_armlet",
	"item_black_king_bar",
	"item_blink",
	"item_ultimate_scepter",
	"item_sange_and_yasha",
	"item_travel_boots",
	"item_satanic",
	"item_aghanims_shard",
	"item_assault",
	"item_travel_boots_2",
	"item_ultimate_scepter_2",
	"item_sheepstick",
	"item_moon_shard",
}
sRoleItemsBuyList["pos_1"] = sRoleItemsBuyList["pos_2"]
sRoleItemsBuyList["pos_4"] = sRoleItemsBuyList["pos_1"]
sRoleItemsBuyList["pos_5"] = sRoleItemsBuyList["pos_1"]
sRoleItemsBuyList["pos_3"] = sRoleItemsBuyList["pos_1"]
X["sBuyList"] = sRoleItemsBuyList[sRole]
X["sSellList"] = { "item_black_king_bar", "item_quelling_blade" }
if Fu.Role.IsPvNMode() or Fu.Role.IsAllShadow() then
	X["sBuyList"], X["sSellList"] = { "PvN_huskar" }, {}
end
nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"] = Fu.SetUserHeroInit(nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"])
X["sSkillList"] = Fu.Skill.GetSkillList(sAbilityList, nAbilityBuildList, sTalentList, nTalentBuildList)
X["bDeafaultAbility"] = false
X["bDeafaultItem"] = false
function X.MinionThink(minionUnit)
	Minion.MinionThink(minionUnit)
end
local innerFireAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[1]), "sAbilityList[1]", "huskar")
local burningSpearAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[2]), "sAbilityList[2]", "huskar")
local berserkersBloodAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[3]), "sAbilityList[3]", "huskar")
local lifeBreakAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[6]), "sAbilityList[6]", "huskar")
local talent6 = SafeAbility(bot:GetAbilityByName(sTalentList[6]), "sTalentList[6]", "huskar")
local hurricanePike = nil
local innerFireDesire
local burningSpearDesire, burningSpearTarget
local lifeBreakDesire, lifeBreakTarget
local pikeSpearDesire, pikeSpearTarget
local aetherRange = 0
local bonusCastRange = 0
local botLevel, hpRatio, nearbyEnemies, nearbyAllies
function X.SkillsComplement()
	if Fu.CanNotUseAbility(bot) or bot:IsInvisible() then
		return
	end
	local context = AbilityContext.Build(bot)
	aetherRange = context.aetherRange
	bonusCastRange = 0
	botLevel = context.level
	hpRatio = context.hp
	botTarget = context.target
	nearbyEnemies = context.enemies
	nearbyAllies = context.allies
	hurricanePike = Fu.IsItemAvailable("item_hurricane_pike")
	pikeSpearDesire, pikeSpearTarget = X.ConsiderHW()
	if pikeSpearDesire > 0 then
		bot:Action_ClearActions(true)
		bot:ActionQueue_UseAbilityOnEntity(hurricanePike, pikeSpearTarget)
		bot:ActionQueue_UseAbilityOnEntity(burningSpearAbility, pikeSpearTarget)
		bot:ActionQueue_UseAbilityOnEntity(burningSpearAbility, pikeSpearTarget)
		bot:ActionQueue_UseAbilityOnEntity(burningSpearAbility, pikeSpearTarget)
		bot:ActionQueue_UseAbilityOnEntity(burningSpearAbility, pikeSpearTarget)
		bot:SetTarget(pikeSpearTarget)
		return
	end
	innerFireDesire = X.ConsiderQ()
	if innerFireDesire > 0 then
		Fu.SetQueuePtToINT(bot, true)
		bot:ActionQueue_UseAbility(innerFireAbility)
		return
	end
	lifeBreakDesire, lifeBreakTarget = X.ConsiderR()
	if lifeBreakDesire > 0 then
		bot:Action_ClearActions(true)
		bot:ActionQueue_UseAbilityOnEntity(lifeBreakAbility, lifeBreakTarget)
		return
	end
	burningSpearDesire, burningSpearTarget = X.ConsiderW()
	if burningSpearDesire > 0 then
		bot:Action_ClearActions(true)
		bot:ActionQueue_UseAbilityOnEntity(burningSpearAbility, burningSpearTarget)
		return
	end
end
function X.ConsiderHW()
	if hurricanePike == nil or not hurricanePike:IsFullyCastable() or not burningSpearAbility:IsFullyCastable() or bot:IsDisarmed() then
		return BOT_ACTION_DESIRE_NONE
	end
	local pikeRange = 400 + aetherRange + 50
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidHero(botTarget)
			and Fu.IsInRange(bot, botTarget, pikeRange)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.GetHP(botTarget) > 0.25
			and not botTarget:IsAttackImmune()
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget, "飓风之力:" .. Fu.Chat.GetNormName(botTarget)
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderQ()
	if not innerFireAbility:IsFullyCastable() then
		return 0
	end
	local abilityLevel = innerFireAbility:GetLevel()
	local castRange = innerFireAbility:GetCastRange()
	local castPoint = innerFireAbility:GetCastPoint()
	local manaCost = innerFireAbility:GetManaCost()
	local damage = innerFireAbility:GetSpecialValueInt("damage")
	local radius = innerFireAbility:GetSpecialValueInt("radius")
	local damageType = DAMAGE_TYPE_MAGICAL
	local enemyHeroes = Fu.GetNearbyHeroes(bot, radius - 32, true, BOT_MODE_NONE)
	local enemyCount = 0
	for _, enemyHero in pairs(enemyHeroes) do
		if Fu.IsValidHero(enemyHero) and Fu.CanCastOnNonMagicImmune(enemyHero) then
			enemyCount = enemyCount + 1
			if enemyCount >= 2 then
				return BOT_ACTION_DESIRE_HIGH, "Q缴械两人:" .. Fu.Chat.GetNormName(enemyHero)
			end
			if Fu.WillMagicKillTarget(bot, enemyHero, damage, castPoint) then
				return BOT_ACTION_DESIRE_HIGH, "Q击杀:" .. Fu.Chat.GetNormName(enemyHero)
			end
			if Fu.IsRetreating(bot) and not Fu.IsDisabled(enemyHero) and not enemyHero:IsDisarmed() then
				return BOT_ACTION_DESIRE_HIGH, "Q撤退:" .. Fu.Chat.GetNormName(enemyHero)
			end
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidHero(botTarget)
			and Fu.IsInRange(bot, botTarget, radius - 32)
			and (not Fu.IsInRange(bot, botTarget, 200) or Fu.IsAttacking(botTarget) or botTarget:GetAttackTarget() ~= nil)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and not Fu.IsDisabled(botTarget)
			and not botTarget:IsDisarmed()
		then
			return BOT_ACTION_DESIRE_HIGH, "Q进攻:" .. Fu.Chat.GetNormName(botTarget)
		end
	end
	if Fu.IsLaning(bot) then
		local laneCreeps = bot:GetNearbyLaneCreeps(radius, true)
		local killableCount = 0
		for _, creep in pairs(laneCreeps) do
			if Fu.IsValid(creep) and not creep:HasModifier("modifier_fountain_glyph") and Fu.WillKillTarget(creep, damage, damageType, castPoint) then
				killableCount = killableCount + 1
			end
		end
		if killableCount >= 2 then
			return BOT_ACTION_DESIRE_HIGH, "Q对线补刀:" .. killableCount
		end
	end
	if Fu.IsFarming(bot) and botLevel >= 8 and Fu.IsAllowedToSpam(bot, manaCost) then
		local neutralCreeps = bot:GetNearbyNeutralCreeps(radius)
		local firstNeutral = neutralCreeps[1]
		if #neutralCreeps >= 2 and Fu.IsValid(firstNeutral) and not Fu.CanKillTarget(firstNeutral, bot:GetAttackDamage() * 2.2, DAMAGE_TYPE_PHYSICAL) then
			return BOT_ACTION_DESIRE_HIGH, "Q打钱:" .. #neutralCreeps
		end
	end
	if
		#nearbyEnemies == 0
		and #nearbyAllies <= 2
		and abilityLevel >= 3
		and botLevel >= 8
		and Fu.IsAllowedToSpam(bot, manaCost)
		and (Fu.IsPushing(bot) or Fu.IsDefending(bot) or Fu.IsFarming(bot))
	then
		local laneCreeps = bot:GetNearbyLaneCreeps(radius, true)
		local killableCount = 0
		local creepCount = 0
		for _, creep in pairs(laneCreeps) do
			if Fu.IsValid(creep) and not creep:HasModifier("modifier_fountain_glyph") then
				creepCount = creepCount + 1
				if Fu.WillKillTarget(creep, damage, damageType, castPoint) then
					killableCount = killableCount + 1
				end
			end
		end
		if killableCount >= 2 then
			return BOT_ACTION_DESIRE_HIGH, "Q带线补兵:" .. killableCount
		end
		if creepCount >= 4 then
			return BOT_ACTION_DESIRE_HIGH, "Q带线清兵:" .. creepCount
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if
			Fu.IsRoshan(botTarget)
			and Fu.IsInRange(bot, botTarget, radius)
			and Fu.GetHP(botTarget) > 0.3
			and Fu.GetHP(bot) > 0.45
			and Fu.IsAttacking(bot)
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, radius) and Fu.GetHP(bot) > 0.45 and Fu.IsAttacking(bot) then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
local lastAutoCastOnTime = 0
function X.ConsiderW()
	if not burningSpearAbility:IsFullyCastable() or bot:IsDisarmed() then
		return 0
	end
	local abilityLevel = burningSpearAbility:GetLevel()
	local attackRange = bot:GetAttackRange() + 50
	local castPoint = burningSpearAbility:GetCastPoint()
	local manaCost = burningSpearAbility:GetManaCost()
	local damage = burningSpearAbility:GetAbilityDamage()
	local damageType = DAMAGE_TYPE_MAGICAL
	local enemyHeroes = Fu.GetNearbyHeroes(bot, attackRange, true, BOT_MODE_NONE)
	local attackDamage = bot:GetAttackDamage()
	local enemyTowers = bot:GetNearbyTowers(800, true)
	local enemyHeroesInRange = Fu.GetNearbyHeroes(bot, attackRange, true, BOT_MODE_NONE)
	local weakestUnit = Fu.GetAttackableWeakestUnit(bot, attackRange, true, true)
	if botLevel >= 7 then
		if (nearbyEnemies[1] ~= nil or botLevel >= 15 and hpRatio > 0.38) and not burningSpearAbility:GetAutoCastState() then
			lastAutoCastOnTime = DotaTime()
			burningSpearAbility:ToggleAutoCast()
		elseif nearbyEnemies[1] == nil and lastAutoCastOnTime < DotaTime() - 3.0 and burningSpearAbility:GetAutoCastState() then
			burningSpearAbility:ToggleAutoCast()
		end
	else
		if burningSpearAbility:GetAutoCastState() then
			burningSpearAbility:ToggleAutoCast()
		end
	end
	if
		botLevel <= 6
		and not burningSpearAbility:GetAutoCastState()
		and Fu.IsValidHero(botTarget)
		and Fu.IsInRange(bot, botTarget, attackRange + 99)
		and (not Fu.IsRunning(bot) or Fu.IsInRange(bot, botTarget, attackRange + 39))
		and not botTarget:IsMagicImmune()
		and not botTarget:IsAttackImmune()
	then
		return BOT_ACTION_DESIRE_HIGH, botTarget
	end
	if Fu.IsLaning(bot) and #enemyTowers == 0 and hpRatio > 0.5 then
		if Fu.IsWithoutTarget(bot) and not Fu.IsAttacking(bot) then
			local laneCreeps = bot:GetNearbyLaneCreeps(666, true)
			for _, creep in pairs(laneCreeps) do
				if
					Fu.IsValid(creep)
					and not creep:HasModifier("modifier_fountain_glyph")
					and creep:GetHealth() < attackDamage * 2.8
					and not Fu.IsAllysTarget(creep)
				then
					local attackDelay = Fu.GetAttackProDelayTime(bot, creep) * 1.12 + 0.05
					local hitDamage = attackDamage * 1.0
					if Fu.WillKillTarget(creep, hitDamage, DAMAGE_TYPE_PHYSICAL, attackDelay) then
						return BOT_ACTION_DESIRE_HIGH, creep, hitDamage .. "W对线补刀:" .. creep:GetHealth()
					end
				end
			end
		end
		local harassTarget = Fu.GetAttackableWeakestUnit(bot, 600, true, true)
		local allyCreepsNear = bot:GetNearbyCreeps(500, false)
		local allyCreepsFar = bot:GetNearbyCreeps(800, false)
		if
			harassTarget ~= nil
			and #allyCreepsNear >= 1
			and #allyCreepsFar - #allyCreepsNear <= 4
			and not harassTarget:IsMagicImmune()
			and not bot:WasRecentlyDamagedByCreep(1.5)
		then
			return BOT_ACTION_DESIRE_HIGH, harassTarget, "W对线进攻:" .. Fu.Chat.GetNormName(harassTarget)
		end
	end
	if
		botTarget ~= nil
		and botTarget:IsHero()
		and not Fu.IsInRange(bot, botTarget, attackRange + 120)
		and Fu.IsValid(weakestUnit)
		and not weakestUnit:IsAttackImmune()
		and not weakestUnit:IsMagicImmune()
	then
		bot:SetTarget(weakestUnit)
		return BOT_ACTION_DESIRE_HIGH, weakestUnit, "W修改目标"
	end
	if Fu.IsGoingOnSomeone(bot) and not burningSpearAbility:GetAutoCastState() then
		if
			Fu.IsValidHero(botTarget)
			and not botTarget:IsAttackImmune()
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, attackRange + 80)
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end
	if Fu.IsFarming(bot) and botLevel >= 7 and not burningSpearAbility:GetAutoCastState() then
		local neutralCreeps = bot:GetNearbyNeutralCreeps(attackRange + 80)
		local mostHpCreep = Fu.GetMostHpUnit(neutralCreeps)
		local bestCreep = nil
		local bestHealth = 0
		for _, creep in pairs(neutralCreeps) do
			if Fu.IsValid(creep) and not creep:HasModifier("modifier_huskar_burning_spear_debuff") and creep:GetHealth() > bestHealth then
				bestCreep = creep
				bestHealth = creep:GetHealth()
			end
		end
		if bestCreep ~= nil then
			return BOT_ACTION_DESIRE_HIGH, bestCreep, "W打野buff"
		end
		if mostHpCreep ~= nil and not Fu.CanKillTarget(mostHpCreep, attackDamage * 2.6, DAMAGE_TYPE_PHYSICAL) then
			return BOT_ACTION_DESIRE_HIGH, mostHpCreep, "W打野消耗"
		end
	end
	if (Fu.IsPushing(bot) or Fu.IsDefending(bot) or Fu.IsFarming(bot)) and botLevel > 9 and #nearbyEnemies <= 1 and not burningSpearAbility:GetAutoCastState() then
		local enemyLaneCreeps = bot:GetNearbyLaneCreeps(attackRange + 80, true)
		local allyLaneCreeps = bot:GetNearbyLaneCreeps(1200, false)
		local weakestAllyUnit = Fu.GetAttackableWeakestUnit(bot, attackRange + 200, false, true)
		if (#allyLaneCreeps == 0 or weakestAllyUnit ~= nil and weakestAllyUnit:GetHealth() > bot:GetAttackDamage() + 88) and #enemyLaneCreeps >= 2 then
			local bestCreep = nil
			local bestHealth = 0
			for _, creep in pairs(enemyLaneCreeps) do
				if
					Fu.IsValid(creep)
					and not Fu.IsKeyWordUnit("siege", creep)
					and not creep:HasModifier("modifier_huskar_burning_spear_debuff")
					and not Fu.CanKillTarget(creep, attackDamage * 1.68, DAMAGE_TYPE_PHYSICAL)
					and creep:GetHealth() > bestHealth
				then
					bestCreep = creep
					bestHealth = creep:GetHealth()
				end
			end
			if bestCreep ~= nil then
				return BOT_ACTION_DESIRE_HIGH, bestCreep, "W带线"
			end
		end
	end
	if Fu.IsDoingRoshan(bot) and not burningSpearAbility:GetAutoCastState() then
		if Fu.IsRoshan(bot:GetAttackTarget()) and Fu.IsInRange(bot, botTarget, attackRange - 40) then
			return BOT_ACTION_DESIRE_HIGH, botTarget, "W肉山"
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderR()
	if not lifeBreakAbility:IsFullyCastable() then
		return 0
	end
	local abilityLevel = lifeBreakAbility:GetLevel()
	local castRange = lifeBreakAbility:GetCastRange() + bonusCastRange + aetherRange
	local castPoint = lifeBreakAbility:GetCastPoint()
	local manaCost = lifeBreakAbility:GetManaCost()
	local damage = lifeBreakAbility:GetAbilityDamage()
	local damageType = DAMAGE_TYPE_MAGICAL
	local enemyHeroes = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidHero(botTarget)
			-- Life Break pierces spell immunity (game files: SPELL_IMMUNITY_ENEMIES_YES and
			-- FLAG_MAGIC_IMMUNE_ENEMIES); it was held whenever the target popped BKB.
			and Fu.CanCastOnMagicImmune(botTarget)
			and (Fu.IsInRange(bot, botTarget, castRange + 88) or Fu.IsInRange(bot, botTarget, bot:GetAttackRange() + 99))
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget, "R进攻" .. Fu.Chat.GetNormName(botTarget)
		end
	end
	if botLevel >= 12 and #nearbyEnemies == 0 and hpRatio > 0.38 and #nearbyAllies < 3 and castRange > bot:GetAttackRange() + 58 then
		if
			Fu.IsValid(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and not Fu.IsInRange(bot, botTarget, castRange - 80)
			and Fu.GetHP(botTarget) > 0.9
			and not botTarget:IsHero()
			and not Fu.IsRoshan(botTarget)
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget, "R跳跃"
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
return X
