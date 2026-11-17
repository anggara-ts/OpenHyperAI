-- Axe: skill build, item build, and ability use for this hero.
local X = {}
local bot = GetBot()
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local AbilityContext = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local Minion = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local sTalentList = Fu.Skill.GetTalentList(bot)
local sAbilityList = Fu.Skill.GetAbilityList(bot)
local sRole = Fu.Item.GetRoleItemsBuyList(bot)
local tTalentTreeList = { ["t25"] = { 0, 10 }, ["t20"] = { 0, 10 }, ["t15"] = { 10, 0 }, ["t10"] = { 0, 10 } }
local tAllAbilityBuildList = { { 2, 3, 3, 1, 3, 6, 3, 1, 1, 1, 6, 2, 2, 2, 6 } }
local nAbilityBuildList = Fu.Skill.GetRandomBuild(tAllAbilityBuildList)
local nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList)
local sRoleItemsBuyList = {}
sRoleItemsBuyList["pos_1"] = {
	"item_sven_outfit",
	"item_blade_mail",
	"item_blink",
	"item_aghanims_shard",
	"item_black_king_bar",
	"item_ultimate_scepter",
	"item_travel_boots",
	"item_overwhelming_blink",
	"item_abyssal_blade",
	"item_ultimate_scepter_2",
	"item_moon_shard",
	"item_heart",
	"item_travel_boots_2",
}
sRoleItemsBuyList["pos_3"] = {
	"item_sven_outfit",
	"item_blade_mail",
	"item_blink",
	"item_crimson_guard",
	"item_aghanims_shard",
	"item_black_king_bar",
	"item_travel_boots",
	"item_assault",
	"item_ultimate_scepter_2",
	"item_moon_shard",
	"item_heart",
	"item_overwhelming_blink",
	"item_travel_boots_2",
}
sRoleItemsBuyList["pos_2"] = sRoleItemsBuyList["pos_1"]
sRoleItemsBuyList["pos_4"] = sRoleItemsBuyList["pos_3"]
sRoleItemsBuyList["pos_5"] = sRoleItemsBuyList["pos_3"]
X["sBuyList"] = sRoleItemsBuyList[sRole]
X["sSellList"] = { "item_travel_boots", "item_quelling_blade", "item_abyssal_blade", "item_magic_wand" }
if Fu.Role.IsPvNMode() or Fu.Role.IsAllShadow() then
	X["sBuyList"], X["sSellList"] = { "PvN_tank" }, { "item_heavens_halberd", "item_quelling_blade" }
end
nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"] = Fu.SetUserHeroInit(nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"])
X["sSkillList"] = Fu.Skill.GetSkillList(sAbilityList, nAbilityBuildList, sTalentList, nTalentBuildList)
X["bDeafaultAbility"] = false
-- Cast when cornered (retreating into 3+ enemies with no way out), before running further.
X["LastStandSpells"] = { { name = "axe_berserkers_call", kind = "none" } }
X["bDeafaultItem"] = false
function X.MinionThink(hMinionUnit)
	Minion.MinionThink(hMinionUnit)
end
local berserkersCallAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[1]), "sAbilityList[1]", "axe")
local battleHungerAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[2]), "sAbilityList[2]", "axe")
local counterHelixAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[3]), "sAbilityList[3]", "axe")
local cullingBladeAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[6]), "sAbilityList[6]", "axe")
local talent7 = SafeAbility(bot:GetAbilityByName(sTalentList[7]), "sTalentList[7]", "axe")
local talent5 = SafeAbility(bot:GetAbilityByName(sTalentList[5]), "sTalentList[5]", "axe")
local berserkersCallDesire
local battleHungerDesire, battleHungerTarget
local counterHelixDesire, counterHelixTarget
local cullingBladeDesire, cullingBladeTarget
local aetherRange = 0
local isAttacking
local mpRatio, hpRatio, nearbyEnemies, nearbyAllies
function X.SkillsComplement()
	if Fu.CanNotUseAbility(bot) or bot:IsInvisible() then
		return
	end
	isAttacking = Fu.IsAttacking(bot)
	local context = AbilityContext.Build(bot)
	aetherRange = context.aetherRange
	mpRatio = context.mp
	hpRatio = context.hp
	botTarget = context.target
	nearbyEnemies = context.enemies
	nearbyAllies = context.allies
	cullingBladeDesire, cullingBladeTarget = X.ConsiderR()
	if cullingBladeDesire > 0 then
		Fu.SetQueuePtToINT(bot, true)
		bot:ActionQueue_UseAbilityOnEntity(cullingBladeAbility, cullingBladeTarget)
		return
	end
	-- fix (missing combo): Blink + Berserker's Call, the Axe initiation. Before this only the generic
	-- item code blinked him (to a random spot near one target) and Call waited for the next think.
	local blinkCallDesire, blinkCallLoc = X.ConsiderBlinkCall()
	if blinkCallDesire > 0 then
		bot:Action_ClearActions(false)
		bot:ActionQueue_UseAbilityOnLocation(bot.Blink, blinkCallLoc)
		bot:ActionQueue_Delay(0.1)
		bot:ActionQueue_UseAbility(berserkersCallAbility)
		return
	end
	berserkersCallDesire = X.ConsiderQ()
	if berserkersCallDesire > 0 then
		Fu.SetQueuePtToINT(bot, true)
		bot:ActionQueue_UseAbility(berserkersCallAbility)
		return
	end
	battleHungerDesire, battleHungerTarget = X.ConsiderW()
	if battleHungerDesire > 0 then
		Fu.SetQueuePtToINT(bot, true)
		bot:ActionQueue_UseAbilityOnEntity(battleHungerAbility, battleHungerTarget)
		return
	end
end
function X.ConsiderQ()
	if not berserkersCallAbility:IsFullyCastable() then
		return 0
	end
	local abilityLevel = berserkersCallAbility:GetLevel()
	local radius = berserkersCallAbility:GetSpecialValueInt("radius")
	if talent7:IsTrained() then
		radius = radius + talent7:GetSpecialValueInt("value")
	end
	local castRange = radius
	local castPoint = berserkersCallAbility:GetCastPoint()
	local manaCost = berserkersCallAbility:GetManaCost()
	local damage = 0
	local damageType = DAMAGE_TYPE_MAGICAL
	local enemiesInRadius = Fu.GetAroundEnemyHeroList(radius - 50)
	local castTarget = nil
	local castReason = nil
	-- fix: Berserker's Call is SPELL_IMMUNITY_ENEMIES_YES (game data): it taunts magic-immune heroes,
	-- so a BKB no longer blocks the channel interrupt or the engage Call.
	for _, enemyHero in pairs(enemiesInRadius) do
		if enemyHero:IsChanneling() and Fu.CanCastOnMagicImmune(enemyHero) then
			castTarget = enemyHero
			castReason = "Q-打断" .. Fu.Chat.GetNormName(castTarget)
			return BOT_ACTION_DESIRE_HIGH, castReason
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidHero(botTarget)
			and Fu.IsInRange(botTarget, bot, radius - 90)
			and Fu.CanCastOnMagicImmune(botTarget)
			and not Fu.IsDisabled(botTarget)
		then
			castTarget = botTarget
			castReason = "Q-先手" .. Fu.Chat.GetNormName(castTarget)
			return BOT_ACTION_DESIRE_HIGH, castReason
		end
	end
	-- fix: in a fight Call only ever went on the chosen target. Call whenever 2+ enemy heroes are inside it.
	if Fu.IsInTeamFight(bot, 1200) or Fu.IsGoingOnSomeone(bot) then
		local heroesInCall = 0
		for _, enemyHero in pairs(enemiesInRadius) do
			if Fu.IsValidHero(enemyHero) and Fu.CanCastOnMagicImmune(enemyHero) and not Fu.IsSuspiciousIllusion(enemyHero) and not Fu.IsDisabled(enemyHero) then
				heroesInCall = heroesInCall + 1
			end
		end
		if heroesInCall >= 2 then
			X.LogAxe("call-multi heroes=" .. heroesInCall)
			return BOT_ACTION_DESIRE_HIGH, "Q-multi"
		end
	end
	if
		(Fu.IsPushing(bot) or Fu.IsDefending(bot) or Fu.IsFarming(bot))
		and Fu.IsAllowedToSpam(bot, manaCost)
		and bot:GetAttackTarget() ~= nil
		and DotaTime() > 6 * 60
		and #nearbyAllies <= 2
		and #nearbyEnemies == 0
	then
		local nearbyLaneCreeps = bot:GetNearbyLaneCreeps(radius - 50, true)
		if #nearbyLaneCreeps >= 4 and not nearbyLaneCreeps[1]:HasModifier("modifier_fountain_glyph") then
			castTarget = creep
			castReason = "Q-带线" .. #nearbyLaneCreeps
			return BOT_ACTION_DESIRE_HIGH, castReason
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if
			Fu.IsRoshan(botTarget)
			and not Fu.IsDisabled(botTarget)
			and not botTarget:IsDisarmed()
			and Fu.IsInRange(bot, botTarget, radius)
			and isAttacking
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, radius) and isAttacking then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsFarming(bot) and #nearbyEnemies == 0 and hpRatio > 0.5 and Fu.GetManaAfter(manaCost) > 0.3 then
		local nearbyNeutrals = bot:GetNearbyNeutralCreeps(radius - 50)
		if #nearbyNeutrals >= 3 then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if bot:GetActiveMode() == BOT_MODE_ROSHAN and Fu.GetManaAfter(manaCost) > 0.3 and hpRatio > 0.3 then
		if Fu.IsRoshan(botTarget) and not Fu.IsDisabled(botTarget) and Fu.IsInRange(bot, botTarget, radius) and isAttacking then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderW()
	if not battleHungerAbility:IsFullyCastable() then
		return 0
	end
	local abilityLevel = battleHungerAbility:GetLevel()
	local castRange = battleHungerAbility:GetCastRange() + aetherRange
	local radius = 600
	local castPoint = battleHungerAbility:GetCastPoint()
	local manaCost = battleHungerAbility:GetManaCost()
	local duration = battleHungerAbility:GetSpecialValueInt("duration")
	local totalDamage = battleHungerAbility:GetSpecialValueInt("damage_per_second") * duration
	-- datafeed: Battle Hunger deals pure damage (damage 4), not magical.
	local damageType = DAMAGE_TYPE_PURE
	local enemiesInRange = Fu.GetAroundEnemyHeroList(castRange)
	local enemiesInRangeWide = Fu.GetAroundEnemyHeroList(castRange + 200)
	local castTarget = nil
	local castReason = nil
	for _, enemyHero in pairs(enemiesInRange) do
		if
			Fu.IsValid(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and Fu.CanCastOnTargetAdvanced(enemyHero)
			and Fu.WillKillTarget(enemyHero, totalDamage, damageType, duration)
			and not enemyHero:HasModifier("modifier_axe_battle_hunger_self")
		then
			castTarget = enemyHero
			castReason = "W-击杀" .. Fu.Chat.GetNormName(castTarget)
			return BOT_ACTION_DESIRE_HIGH, castTarget, castReason
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidHero(botTarget)
			and Fu.IsInRange(botTarget, bot, castRange)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.CanCastOnTargetAdvanced(botTarget)
			and not botTarget:HasModifier("modifier_axe_battle_hunger_self")
		then
			castTarget = botTarget
			castReason = "W-先手" .. Fu.Chat.GetNormName(castTarget)
			return BOT_ACTION_DESIRE_HIGH, castTarget, castReason
		end
	end
	if Fu.IsInTeamFight(bot, 1200) then
		local weakestEnemy = nil
		local lowestHealth = 100000
		for _, enemyHero in pairs(enemiesInRangeWide) do
			if
				Fu.IsValid(enemyHero)
				and not enemyHero:HasModifier("modifier_axe_battle_hunger_self")
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
			then
				local enemyHealth = enemyHero:GetHealth()
				if enemyHealth < lowestHealth then
					lowestHealth = enemyHealth
					weakestEnemy = enemyHero
				end
			end
		end
		if weakestEnemy ~= nil then
			castTarget = weakestEnemy
			castReason = "W-团战" .. Fu.Chat.GetNormName(castTarget)
			return BOT_ACTION_DESIRE_HIGH, castTarget, castReason
		end
	end
	if Fu.IsLaning(bot) and mpRatio > 0.5 then
		for _, enemyHero in pairs(enemiesInRange) do
			if
				Fu.IsValid(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
				and enemyHero:GetAttackTarget() == nil
				and not enemyHero:HasModifier("modifier_axe_battle_hunger_self")
			then
				castTarget = enemyHero
				castReason = "W-对线消耗:" .. Fu.Chat.GetNormName(castTarget)
				return BOT_ACTION_DESIRE_HIGH, castTarget, castReason
			end
		end
	end
	if Fu.IsRetreating(bot) then
		for _, enemyHero in pairs(enemiesInRange) do
			if
				Fu.IsValid(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
				and not enemyHero:HasModifier("modifier_axe_battle_hunger_self")
			then
				castTarget = enemyHero
				castReason = "W-撤退:" .. Fu.Chat.GetNormName(castTarget)
				return BOT_ACTION_DESIRE_HIGH, castTarget, castReason
			end
		end
	end
	if Fu.IsFarming(bot) and abilityLevel >= 2 and Fu.GetManaAfter(manaCost) > 0.3 then
		local nearbyNeutrals = bot:GetNearbyNeutralCreeps(castRange + 100)
		local toughestNeutral = Fu.GetMostHpUnit(nearbyNeutrals)
		if
			Fu.IsValid(toughestNeutral)
			and not Fu.IsRoshan(toughestNeutral)
			and not toughestNeutral:HasModifier("modifier_axe_battle_hunger_self")
			and not Fu.CanKillTarget(toughestNeutral, bot:GetAttackDamage() * 2.88, DAMAGE_TYPE_PHYSICAL)
		then
			castTarget = toughestNeutral
			castReason = "W-打野"
			return BOT_ACTION_DESIRE_HIGH, castTarget, castReason
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if
			Fu.IsRoshan(botTarget)
			and not Fu.IsDisabled(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and isAttacking
			and not botTarget:HasModifier("modifier_axe_battle_hunger_self")
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if
			Fu.IsTormentor(botTarget)
			and not Fu.IsDisabled(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and isAttacking
			and not botTarget:HasModifier("modifier_axe_battle_hunger_self")
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderR()
	if not cullingBladeAbility:IsFullyCastable() then
		return 0
	end
	local abilityLevel = cullingBladeAbility:GetLevel()
	local castRange = cullingBladeAbility:GetCastRange()
	local radius = 600
	local castPoint = cullingBladeAbility:GetCastPoint()
	local manaCost = cullingBladeAbility:GetManaCost()
	-- datafeed: Culling Blade damage is 275/375/475 pure (the old hard-coded 250/350/450 was low). The talent
	-- is no longer added: f[5] is now +15 Strength, not Culling Blade damage.
	local damage = cullingBladeAbility:GetSpecialValueInt("damage")
	if damage <= 0 then
		damage = 175 + 100 * abilityLevel
	end
	local damageType = DAMAGE_TYPE_PURE
	local enemiesInRange = Fu.GetAroundEnemyHeroList(castRange)
	local enemiesInRangeWide = Fu.GetAroundEnemyHeroList(castRange + 200)
	local castTarget = nil
	local castReason = nil
	for _, enemyHero in pairs(enemiesInRangeWide) do
		if
			Fu.IsValidHero(enemyHero)
			and enemyHero:CanBeSeen()
			and enemyHero:GetHealth() + enemyHero:GetHealthRegen() * 0.8 < damage
			and not Fu.IsHaveAegis(enemyHero)
			and not enemyHero:IsInvulnerable()
			-- datafeed: Culling Blade pierces debuff immunity (immunity 3), so magic-immune heroes are valid targets.
			and not X.HasSpecialModifier(enemyHero)
			and not X.IsKillBotAntiMage(enemyHero)
		then
			castTarget = enemyHero
			castReason = "R-击杀" .. Fu.Chat.GetNormName(castTarget)
			return BOT_ACTION_DESIRE_HIGH, castTarget, castReason
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
-- [OHA-AXE]: new casts (multi-hero Call, Blink-Call), at most once per 10s per reason.
function X.LogAxe(why)
	bot._axeLogAt = bot._axeLogAt or {}
	local key = string.match(why, "^%S+") or why
	if DotaTime() < (bot._axeLogAt[key] or -999) then
		return
	end
	bot._axeLogAt[key] = DotaTime() + 10
	pcall(print, string.format("[OHA-AXE] t=%.0f %s hp=%.2f", DotaTime(), why, Fu.GetHP(bot)))
end
-- Blink (item, range 1200) into 2+ enemy heroes, or onto the engage target, then Call at once.
function X.ConsiderBlinkCall()
	if not berserkersCallAbility:IsFullyCastable() or bot:GetMana() < berserkersCallAbility:GetManaCost() or bot:IsRooted() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	if not (Fu.IsGoingOnSomeone(bot) or Fu.IsInTeamFight(bot, 1200)) or Fu.GetHP(bot) < 0.4 then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	if not Fu.CanBlinkDagger(bot) then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local callRadius = berserkersCallAbility:GetSpecialValueInt("radius")
	local blinkRange = 1150
	local spot = nil
	local aoe = bot:FindAoELocation(true, true, bot:GetLocation(), blinkRange, callRadius - 50, 0, 0)
	if aoe.count >= 2 and GetUnitToLocationDistance(bot, aoe.targetloc) > callRadius then
		spot = aoe.targetloc
	elseif
		Fu.IsGoingOnSomeone(bot)
		and Fu.IsValidHero(botTarget)
		and Fu.CanCastOnMagicImmune(botTarget)
		and not Fu.IsSuspiciousIllusion(botTarget)
		and not Fu.IsDisabled(botTarget)
		and Fu.IsInRange(bot, botTarget, blinkRange)
		and not Fu.IsInRange(bot, botTarget, callRadius + 100)
	then
		spot = botTarget:GetLocation()
	end
	if spot == nil or not IsLocationPassable(spot) then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local alliesThere = Fu.GetAlliesNearLoc(spot, 1600)
	local enemiesThere = Fu.GetEnemiesNearLoc(spot, 1200)
	if alliesThere == nil or enemiesThere == nil or #alliesThere + 1 < #enemiesThere then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	X.LogAxe("blink-call enemies=" .. #enemiesThere .. " allies=" .. #alliesThere)
	return BOT_ACTION_DESIRE_HIGH, spot
end
function X.HasSpecialModifier(enemyHero)
	if
		enemyHero:HasModifier("modifier_winter_wyvern_winters_curse")
		or enemyHero:HasModifier("modifier_winter_wyvern_winters_curse_aura")
		or enemyHero:HasModifier("modifier_antimage_spell_shield")
		or enemyHero:HasModifier("modifier_item_lotus_orb_active")
		or enemyHero:HasModifier("modifier_item_aeon_disk_buff")
		or enemyHero:HasModifier("modifier_item_sphere_target")
		or enemyHero:HasModifier("modifier_illusion")
	then
		return true
	else
		return false
	end
end
function X.IsKillBotAntiMage(enemyHero)
	if
		not enemyHero:IsBot()
		or enemyHero:GetUnitName() ~= "npc_dota_hero_antimage"
		or enemyHero:IsStunned()
		or enemyHero:IsHexed()
		or enemyHero:IsNightmared()
		or enemyHero:IsChanneling()
		or Fu.IsTaunted(enemyHero)
	then
		return false
	end
	return true
end
return X
