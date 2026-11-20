-- Nevermore: skill build, item build, and ability use for this hero.
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
	{ ["t25"] = { 10, 0 }, ["t20"] = { 0, 10 }, ["t15"] = { 10, 0 }, ["t10"] = { 0, 10 } },
}
local tAllAbilityBuildList = { { 1, 5, 1, 5, 1, 6, 1, 5, 5, 4, 4, 6, 4, 4, 6 } }
local nAbilityBuildList = tAllAbilityBuildList[1]
local nTalentBuildList
if sRole == "pos_1" or sRole == "pos_3" then
	nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList[1])
else
	nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList[2])
end
local sRoleItemsBuyList = {}
sRoleItemsBuyList["pos_1"] = {
	"item_tango",
	"item_double_branches",
	"item_faerie_fire",
	"item_magic_wand",
	"item_power_treads",
	"item_falcon_blade",
	"item_mask_of_madness",
	"item_dragon_lance",
	-- Yasha and Kaya and Blink Dagger: #5 and #3 by matches played (Dotabuff, last patch).
	"item_manta",
	"item_black_king_bar",
	"item_blink",
	"item_greater_crit",
	"item_hurricane_pike",
	"item_aghanims_shard",
	"item_satanic",
	"item_moon_shard",
	"item_travel_boots_2",
	"item_ultimate_scepter_2",
}
sRoleItemsBuyList["pos_2"] = {
	"item_tango",
	"item_double_branches",
	"item_faerie_fire",
	"item_enchanted_mango",
	"item_enchanted_mango",
	"item_bottle",
	"item_magic_wand",
	"item_power_treads",
	"item_dragon_lance",
	-- Yasha and Kaya, Blink Dagger and Aghanim's Scepter: #5, #3 and #6 by matches played (Dotabuff,
	-- last patch); Orchid / Bloodthorn are not in his top 25.
	"item_yasha_and_kaya",
	"item_black_king_bar",
	"item_blink",
	"item_ultimate_scepter",
	"item_greater_crit",
	"item_hurricane_pike",
	"item_aghanims_shard",
	"item_satanic",
	"item_moon_shard",
	"item_travel_boots_2",
	"item_ultimate_scepter_2",
}
-- One pair of boots in this build (user rule; Util/boots-check.js).
sRoleItemsBuyList["pos_4"] = {
	"item_tango",
	"item_tango",
	"item_double_branches",
	"item_clarity",
	"item_magic_wand",
	"item_tranquil_boots",
	"item_null_talisman",
	"item_glimmer_cape",
	"item_force_staff",
	"item_cyclone",
	"item_boots_of_bearing",
	"item_octarine_core",
	"item_hurricane_pike",
	"item_aghanims_shard",
	"item_wind_waker",
	"item_ultimate_scepter_2",
	"item_moon_shard",
}
sRoleItemsBuyList["pos_5"] = {
	"item_tango",
	"item_tango",
	"item_double_branches",
	"item_clarity",
	"item_magic_wand",
	"item_tranquil_boots",
	"item_null_talisman",
	"item_glimmer_cape",
	"item_pipe",
	"item_force_staff",
	"item_cyclone",
	"item_boots_of_bearing",
	"item_octarine_core",
	"item_hurricane_pike",
	"item_aghanims_shard",
	"item_wind_waker",
	"item_ultimate_scepter_2",
	"item_moon_shard",
}
sRoleItemsBuyList["pos_3"] = sRoleItemsBuyList["pos_1"]
X["sBuyList"] = sRoleItemsBuyList[sRole]
X["sSellList"] = { "item_kaya", "item_quelling_blade", "item_octarine_core", "item_bottle" }
if Fu.Role.IsPvNMode() or Fu.Role.IsAllShadow() then
	X["sBuyList"], X["sSellList"] = { "PvN_mid" }, {}
end
nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"] =
	Fu.SetUserHeroInit(nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"])
X["sSkillList"] = Fu.Skill.GetSkillList(sAbilityList, nAbilityBuildList, sTalentList, nTalentBuildList)
X["bDeafaultAbility"] = false
X["bDeafaultItem"] = false
function X.MinionThink(minionUnit)
	Minion.MinionThink(minionUnit)
end
local shadowrazeNearAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[1]), "sAbilityList[1]", "nevermore")
local shadowrazeMediumAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[2]), "sAbilityList[2]", "nevermore")
local shadowrazeFarAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[3]), "sAbilityList[3]", "nevermore")
local feastOfSoulsAbility = SafeAbility(bot:GetAbilityByName("nevermore_frenzy"), "nevermore_frenzy", "nevermore")
local requiemAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[6]), "sAbilityList[6]", "nevermore")
local talent4 = SafeAbility(bot:GetAbilityByName(sTalentList[4]), "sTalentList[4]", "nevermore")
local razeNearDesire
local razeMediumDesire
local razeFarDesire
local feastOfSoulsDesire
local requiemDesire
local razeManaReserve, mpRatio, hpRatio, botLevel, nearbyEnemies, botTarget
local isAttacking
function X.SkillsComplement()
	if bot.invisUltCombo then
		return
	end
	Fu.ConsiderTarget()
	if Fu.CanNotUseAbility(bot) then
		return
	end
	isAttacking = Fu.IsAttacking(bot)
	local context = AbilityContext.Build(bot)
	razeManaReserve = 340
	botLevel = context.level
	mpRatio = context.mp
	hpRatio = context.hp
	nearbyEnemies = context.enemies
	botTarget = context.target
	requiemDesire = X.ConsiderR()
	if requiemDesire > 0 then
		Fu.SetQueuePtToINT(bot, false)
		bot:ActionQueue_UseAbility(requiemAbility)
		return
	end
	if X.ConsiderBlinkRequiem() then
		return
	end
	if requiemAbility:IsFullyCastable() and Fu.Utils.IsTruelyInvisible(bot) then
		return
	end
	razeMediumDesire = X.Consider(shadowrazeMediumAbility, 450)
	if razeMediumDesire > 0 then
		Fu.SetQueuePtToINT(bot, true)
		bot:ActionQueue_UseAbility(shadowrazeMediumAbility)
		return
	end
	razeFarDesire = X.Consider(shadowrazeFarAbility, 700)
	if razeFarDesire > 0 then
		Fu.SetQueuePtToINT(bot, true)
		bot:ActionQueue_UseAbility(shadowrazeFarAbility)
		return
	end
	razeNearDesire = X.Consider(shadowrazeNearAbility, 200)
	if razeNearDesire > 0 then
		Fu.SetQueuePtToINT(bot, true)
		bot:ActionQueue_UseAbility(shadowrazeNearAbility)
		return
	end
	feastOfSoulsDesire = X.ConsiderFeastOfSouls()
	if feastOfSoulsDesire > 0 then
		Fu.SetQueuePtToINT(bot, false)
		bot:ActionQueue_UseAbility(feastOfSoulsAbility)
		return
	end
end
function X.ConsiderR()
	if not requiemAbility:IsFullyCastable() then
		return 0
	end
	local soulCount = bot:GetModifierStackCount(bot:GetModifierByName("modifier_nevermore_necromastery"))
	if soulCount < 10 and hpRatio > 0.5 then
		return 0
	end
	local enemiesIn1200 = Fu.GetEnemyList(bot, 1200)
	local enemiesIn750 = Fu.GetEnemyList(bot, 750)
	local enemiesIn350 = Fu.GetEnemyList(bot, 350)
	-- Follow-through of ConsiderBlinkRequiem: just blinked in, 2+ enemies within 750.
	if DotaTime() - (bot._sfBlinkAt or -999) <= 1.5 and #enemiesIn750 >= 2 then
		bot._sfBlinkAt = nil
		return BOT_ACTION_DESIRE_HIGH
	end
	for _, enemyHero in pairs(enemiesIn350) do
		local cycloneTime = Fu.GetModifierTime(enemyHero, "modifier_brewmaster_storm_cyclone")
		if
			Fu.IsValidHero(enemyHero)
			and (cycloneTime > 0 and cycloneTime <= 1.66 or Fu.Utils.IsTruelyInvisible(bot))
			and enemyHero:GetHealth() > 700
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsInTeamFight(bot, 1000) or Fu.IsGoingOnSomeone(bot) then
		if
			#enemiesIn750 >= 3
			or #enemiesIn350 >= 1 and #enemiesIn750 >= 2
			or #enemiesIn1200 >= 3 and #enemiesIn750 >= 2
			or #enemiesIn1200 >= 4 and #enemiesIn350 >= 1
		then
			return BOT_ACTION_DESIRE_HIGH
		end
		local aoe = bot:FindAoELocation(true, true, bot:GetLocation(), 100, 800, 1.67, 0)
		if aoe.count >= 3 then
			return BOT_ACTION_DESIRE_HIGH
		end
		local target = Fu.GetProperTarget(bot)
		if
			Fu.IsValidHero(target)
			and Fu.CanCastOnNonMagicImmune(target)
			and not Fu.IsDisabled(target)
			and GetUnitToUnitDistance(target, bot) <= 400
			and target:GetHealth() > 700
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	return 0
end
-- Blink -> Requiem (review): his build buys a Blink Dagger, but Requiem was only cast where he
-- already stood. In a team fight (2+ of our heroes attacking within 1600, so he never blinks in
-- alone), with Requiem and its mana ready, 10+ souls and 40%+ HP, blink (1200, Arcane 1400, item
-- data) onto a spot 500+ away with 3+ enemy heroes within 450. ConsiderR casts Requiem for 1.5s
-- after the blink (bot._sfBlinkAt) whatever its own fight gates say.
function X.ConsiderBlinkRequiem()
	if not requiemAbility:IsFullyCastable() or bot:GetMana() < requiemAbility:GetManaCost() or bot:IsRooted() then
		return false
	end
	if Fu.IsRetreating(bot) or Fu.GetHP(bot) < 0.4 or not Fu.IsInTeamFight(bot, 1600) then
		return false
	end
	if bot:GetModifierStackCount(bot:GetModifierByName("modifier_nevermore_necromastery")) < 10 then
		return false
	end
	if not Fu.CanBlinkDagger(bot) or bot.Blink == nil then
		return false
	end
	local range = bot.Blink:GetName() == "item_arcane_blink" and 1400 or 1200
	local aoe = bot:FindAoELocation(true, true, bot:GetLocation(), range - 100, 450, 0, 0)
	if aoe == nil or aoe.count == nil or aoe.count < 3 or aoe.targetloc == nil then
		return false
	end
	if GetUnitToLocationDistance(bot, aoe.targetloc) < 500 or not IsLocationPassable(aoe.targetloc) then
		return false
	end
	local foes = 0
	for _, enemyHero in pairs(Fu.GetEnemiesNearLoc(aoe.targetloc, 450) or {}) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and not Fu.IsSuspiciousIllusion(enemyHero)
		then
			foes = foes + 1
		end
	end
	if foes < 3 then
		return false
	end
	if DotaTime() >= (bot._sfBlinkLogAt or -999) then
		bot._sfBlinkLogAt = DotaTime() + 3
		pcall(
			print,
			string.format(
				"[OHA-SF] t=%.0f blink-requiem foes=%d dist=%d",
				DotaTime(),
				foes,
				math.floor(GetUnitToLocationDistance(bot, aoe.targetloc))
			)
		)
	end
	bot._sfBlinkAt = DotaTime()
	bot:Action_UseAbilityOnLocation(bot.Blink, aoe.targetloc)
	return true
end
function X.Consider(razeAbility, razeDistance)
	if not razeAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local razeRadius = 248
	local razeLocation = Fu.GetFaceTowardDistanceLocation(bot, razeDistance)
	local castPoint = razeAbility:GetCastPoint()
	local damageType = DAMAGE_TYPE_MAGICAL
	local abilityLevel = razeAbility:GetLevel()
	-- datafeed: Shadowraze deals shadowraze_damage 85/150/215/280 plus damage_per_soul (2) per Necromastery soul;
	-- the old 20 + 70 * level was too high and ignored souls. The talent sTalentList[4] is now a Feast of Souls talent, so it
	-- is no longer added here.
	local damage = razeAbility:GetSpecialValueInt("shadowraze_damage")
	if damage <= 0 then
		damage = 20 + 65 * abilityLevel
	end
	local aSouls = bot:GetModifierStackCount(bot:GetModifierByName("modifier_nevermore_necromastery"))
	damage = damage + aSouls * razeAbility:GetSpecialValueInt("damage_per_soul")
	local stackBonusDamage = razeAbility:GetSpecialValueInt("stack_bonus_damage")
	local creepKeyword = "ranged"
	local enemiesInRange = Fu.GetNearbyHeroes(bot, 1000, true, BOT_MODE_NONE)
	local target = Fu.GetProperTarget(bot)
	if
		Fu.IsValidHero(target)
		and Fu.CanCastOnNonMagicImmune(target)
		and X.IsUnitNearLoc(target, razeLocation, razeRadius - 20, castPoint)
		and (
			bot:GetMana() > razeManaReserve * (1 - abilityLevel / 4)
			or X.IsUnitCanBeKill(target, damage, stackBonusDamage, castPoint)
			or target:HasModifier("modifier_nevermore_requiem_fear")
		)
	then
		return BOT_ACTION_DESIRE_HIGH
	end
	for _, enemyHero in pairs(enemiesInRange) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and X.IsUnitNearLoc(enemyHero, razeLocation, razeRadius - 30, castPoint)
			and (
				bot:GetMana() > razeManaReserve * (1 - abilityLevel / 4)
				or X.IsUnitCanBeKill(enemyHero, damage, stackBonusDamage, castPoint)
				or enemyHero:HasModifier("modifier_nevermore_requiem_fear")
			)
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if botLevel <= 12 then
		local laneCreeps = bot:GetNearbyLaneCreeps(1000, true)
		local killableCount = 0
		for _, creep in pairs(laneCreeps) do
			if
				Fu.IsValid(creep)
				and not creep:HasModifier("modifier_fountain_glyph")
				and Fu.IsKeyWordUnit(creepKeyword, creep)
				and X.IsUnitNearLoc(creep, razeLocation, razeRadius, castPoint)
				and X.IsUnitCanBeKill(creep, damage, stackBonusDamage, castPoint)
			then
				killableCount = killableCount + 1
			end
		end
		if killableCount >= 2 then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if not Fu.IsRetreating(bot) then
		local nearbyCreeps = bot:GetNearbyCreeps(1200, true)
		local laneCreepsInRange = bot:GetNearbyLaneCreeps(razeDistance + razeRadius * 1.5, true)
		local hitCount = 0
		local killCount = 0
		for _, creep in pairs(nearbyCreeps) do
			if
				Fu.IsValid(creep)
				and not creep:HasModifier("modifier_fountain_glyph")
				and (creep:GetMagicResist() < 0.4 or mpRatio > 0.9)
				and X.IsUnitNearLoc(creep, razeLocation, razeRadius, castPoint)
			then
				hitCount = hitCount + 1
				if X.IsUnitCanBeKill(creep, damage, stackBonusDamage, castPoint) then
					killCount = killCount + 1
				end
			end
		end
		if botLevel >= 8 and enemiesInRange[1] == nil then
			if
				hitCount >= 4 and mpRatio > 0.6
				or hitCount >= 3 and bot:GetActiveMode() ~= BOT_MODE_LANING and mpRatio > 0.78
				or killCount >= 2 and hitCount == #laneCreepsInRange
				or hitCount >= 2 and mpRatio > 0.8 and botLevel > 10 and #nearbyCreeps == 2
				or hitCount >= 2 and botLevel > 24 and #nearbyCreeps == 2 and Fu.IsAllowedToSpam(bot, 180)
			then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
		if botLevel <= 10 then
			if killCount >= 2 and (hitCount == #laneCreepsInRange or mpRatio > 0.8) then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
		if killCount >= 3 then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	return 0
end
function X.ConsiderFeastOfSouls()
	if not feastOfSoulsAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
	end
	local attackRange = bot:GetAttackRange()
	local soulCount = bot:GetModifierStackCount(bot:GetModifierByName("modifier_nevermore_necromastery"))
	local manaAfter = Fu.GetManaAfter(feastOfSoulsAbility:GetManaCost()) * bot:GetMana()
	-- datafeed: Necromastery max souls is 20 and Feast of Souls (nevermore_frenzy) gathers souls rather than
	-- spending them, so the old "soulCount < 25" gate kept it unused unless max souls were raised. Gate removed.
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidTarget(botTarget)
			and Fu.IsInRange(bot, botTarget, attackRange)
			and not Fu.IsChasingTarget(bot, botTarget)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			local targetEnemies = Fu.GetNearbyHeroes(botTarget, 1200, true, BOT_MODE_NONE)
			local targetAllies = Fu.GetNearbyHeroes(botTarget, 1200, false, BOT_MODE_NONE)
			if targetEnemies ~= nil and targetAllies ~= nil and #targetEnemies >= #targetAllies then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	if Fu.IsFarming(bot) and manaAfter > 0.3 then
		if isAttacking then
			local neutralCreeps = bot:GetNearbyNeutralCreeps(1000)
			if
				neutralCreeps ~= nil
				and (#neutralCreeps >= 3 or #neutralCreeps >= 2 and neutralCreeps[1]:IsAncientCreep())
			then
				return BOT_ACTION_DESIRE_HIGH
			end
			local laneCreeps = bot:GetNearbyLaneCreeps(1000, true)
			if laneCreeps ~= nil and #laneCreeps >= 4 then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	if Fu.IsPushing(bot) or Fu.IsDefending(bot) then
		local laneCreeps = bot:GetNearbyLaneCreeps(1000, true)
		if
			laneCreeps ~= nil
			and #laneCreeps >= 4
			and nearbyEnemies ~= nil
			and #nearbyEnemies == 0
			and manaAfter > 0.3
		then
			return BOT_ACTION_DESIRE_HIGH
		end
		if Fu.IsValidBuilding(botTarget) and Fu.CanBeAttacked(botTarget) and isAttacking then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsDoingRoshan(bot) or Fu.IsDoingTormentor(bot) then
		if
			(Fu.IsRoshan(botTarget) or Fu.IsTormentor(botTarget))
			and Fu.IsInRange(bot, botTarget, attackRange)
			and isAttacking
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.IsUnitNearLoc(unit, location, radius, delay)
	if GetUnitToLocationDistance(unit, location) > 250 then
		return false
	end
	local stability = unit:GetMovementDirectionStability()
	if stability < 0.98 then
		radius = radius - 14
	end
	if stability < 0.91 then
		radius = radius - 26
	end
	if stability < 0.81 then
		radius = radius - 30
	end
	local predictedLocation = Fu.GetCorrectLoc(unit, delay)
	if Fu.GetLocationToLocationDistance(predictedLocation, location) < radius then
		return true
	end
	return false
end
function X.IsUnitCanBeKill(unit, damage, stackBonusDamage, castPoint)
	local damageType = DAMAGE_TYPE_MAGICAL
	local debuffStacks = Fu.GetModifierCount(unit, "modifier_nevermore_shadowraze_debuff")
	local totalDamage = damage + debuffStacks * stackBonusDamage
	return Fu.WillKillTarget(unit, totalDamage, damageType, castPoint)
end
return X
