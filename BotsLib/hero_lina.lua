-- Lina: skill build, item build, and ability use for this hero.
-- Accidental globals made file-local (#13): every bot shares one Lua state, so these were shared.
local botTarget
local X = {}
local bot = GetBot()
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local AbilityContext = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local Minion = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local NukerRules = require(GetScriptDirectory() .. "/FuncLib/systems/nuker_rules")
local sTalentList = Fu.Skill.GetTalentList(bot)
local sAbilityList = Fu.Skill.GetAbilityList(bot)
local sRole = Fu.Item.GetRoleItemsBuyList(bot)
local tTalentTreeList = {
	{ ["t25"] = { 10, 0 }, ["t20"] = { 10, 0 }, ["t15"] = { 0, 10 }, ["t10"] = { 10, 0 } },
	{ ["t25"] = { 0, 10 }, ["t20"] = { 0, 10 }, ["t15"] = { 10, 0 }, ["t10"] = { 10, 0 } },
}
local tAllAbilityBuildList = {
	{ 2, 3, 3, 1, 3, 6, 3, 2, 2, 2, 6, 1, 1, 1, 6 },
	{ 1, 3, 1, 3, 1, 6, 1, 3, 3, 2, 6, 2, 2, 2, 6 },
	{
		2,
		1,
		1,
		2,
		1,
		6,
		1,
		2,
		2,
		3,
		6,
		3,
		3,
		3,
		6,
	},
}
local nAbilityBuildList
local nTalentBuildList
if sRole == "pos_1" then
	nAbilityBuildList = tAllAbilityBuildList[1]
	nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList[1])
elseif sRole == "pos_2" then
	nAbilityBuildList = tAllAbilityBuildList[2]
	nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList[2])
else
	nAbilityBuildList = tAllAbilityBuildList[3]
	nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList[2])
end
local sRoleItemsBuyList = {}
-- Stratz 7.41f, week of 9 Nov 2026: pos 1, 8,410 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_1"] = {
	"item_tango",
	"item_double_branches",
	"item_faerie_fire",
	"item_circlet",
	"item_mantle",
	"item_null_talisman",
	"item_magic_wand",
	"item_falcon_blade",
	"item_boots",
	"item_maelstrom",
	"item_travel_boots",
	"item_mjollnir",
	"item_invis_sword",
	"item_black_king_bar",
	"item_greater_crit",
	"item_aghanims_shard",
	"item_satanic",
	"item_ultimate_scepter_2",
	"item_moon_shard",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 2, 203,732 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_2"] = {
	"item_tango",
	"item_double_branches",
	"item_faerie_fire",
	"item_circlet",
	"item_mantle",
	"item_null_talisman",
	"item_magic_wand",
	"item_boots",
	"item_kaya",
	"item_travel_boots",
	"item_ultimate_scepter",
	"item_yasha_and_kaya",
	"item_blink",
	"item_black_king_bar",
	"item_aghanims_shard",
	"item_sheepstick",
	"item_ultimate_scepter_2",
	"item_maelstrom",
	"item_mjollnir",
	"item_moon_shard",
	"item_travel_boots_2",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 3, 3,261 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_3"] = {
	"item_tango",
	"item_double_branches",
	"item_circlet",
	"item_mantle",
	"item_faerie_fire",
	"item_null_talisman",
	"item_magic_wand",
	"item_boots",
	"item_kaya",
	"item_travel_boots",
	"item_yasha_and_kaya",
	"item_ultimate_scepter",
	"item_black_king_bar",
	"item_aghanims_shard",
	"item_satanic",
	"item_ultimate_scepter_2",
	"item_cyclone",
	"item_mjollnir",
	"item_moon_shard",
	"item_travel_boots_2",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 4, 29,780 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_4"] = {
	"item_tango",
	"item_blood_grenade",
	"item_branches",
	"item_magic_stick",
	"item_circlet",
	"item_null_talisman",
	"item_magic_wand",
	"item_arcane_boots",
	"item_cyclone",
	"item_travel_boots",
	"item_ultimate_scepter",
	"item_black_king_bar",
	"item_ultimate_scepter_2",
	"item_wind_waker",
	"item_maelstrom",
	"item_silver_edge",
	"item_sphere",
	"item_aghanims_shard",
	"item_moon_shard",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 5, 17,391 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_5"] = {
	"item_tango",
	"item_blood_grenade",
	"item_branches",
	"item_magic_stick",
	"item_circlet",
	"item_null_talisman",
	"item_magic_wand",
	"item_arcane_boots",
	"item_cyclone",
	"item_travel_boots",
	"item_ultimate_scepter",
	"item_sheepstick",
	"item_ultimate_scepter_2",
	"item_rod_of_atos",
	"item_wind_waker",
	"item_sphere",
	"item_glimmer_cape",
	"item_moon_shard",
}
X["sBuyList"] = sRoleItemsBuyList[sRole]
X["sSellList"] = {
	"item_black_king_bar",
	"item_null_talisman",
	"item_silver_edge",
	"item_glimmer_cape",
	-- Sold once the item before it is owned, to keep six slots (Util/item-builds/generate.js):
	"item_satanic",
	"item_falcon_blade",
}
if Fu.Role.IsPvNMode() or Fu.Role.IsAllShadow() then
	X["sBuyList"], X["sSellList"] = { "PvN_mage" }, {}
end
nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"] =
	Fu.SetUserHeroInit(nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"])
X["sSkillList"] = Fu.Skill.GetSkillList(sAbilityList, nAbilityBuildList, sTalentList, nTalentBuildList)
X["bDeafaultAbility"] = false
X["bDeafaultItem"] = true
function X.MinionThink(minion)
	Minion.MinionThink(minion)
end
local dragonSlaveAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[1]), "sAbilityList[1]", "lina")
local lightStrikeArrayAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[2]), "sAbilityList[2]", "lina")
local fierySoulAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[3]), "sAbilityList[3]", "lina")
local lagunaBladeAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[6]), "sAbilityList[6]", "lina")
local flameCloakAbility = SafeAbility(bot:GetAbilityByName("lina_flame_cloak"), "lina_flame_cloak", "lina")
local talent2 = SafeAbility(bot:GetAbilityByName(sTalentList[2]), "sTalentList[2]", "lina")
local talent4 = SafeAbility(bot:GetAbilityByName(sTalentList[4]), "sTalentList[4]", "lina")
local talent7 = SafeAbility(bot:GetAbilityByName(sTalentList[7]), "sTalentList[7]", "lina")
local dragonSlaveDesire, dragonSlaveLocation
local lightStrikeArrayDesire, lightStrikeArrayLocation
local lagunaBladeDesire, lagunaBladeTarget
local flameCloakDesire
local aetherRange = 0
local lsaBonusDamage = 0
local botLevel, mpRatio, hpRatio, nearbyEnemies, nearbyAllies
function X.SkillsComplement()
	if Fu.CanNotUseAbility(bot) or bot:IsInvisible() then
		return
	end
	local context = AbilityContext.Build(bot)
	aetherRange = context.aetherRange
	lsaBonusDamage = 0
	botLevel = context.level
	mpRatio = context.mp
	hpRatio = context.hp
	botTarget = context.target
	nearbyEnemies = context.enemies
	nearbyAllies = context.allies
	if talent4:IsTrained() then
		lsaBonusDamage = lsaBonusDamage + talent4:GetSpecialValueInt("value")
	end
	flameCloakDesire = X.ConsiderFlameCloak()
	if flameCloakDesire > 0 then
		bot:Action_UseAbility(flameCloakAbility)
		return
	end
	lagunaBladeDesire, lagunaBladeTarget = X.ConsiderR()
	if lagunaBladeDesire > 0 then
		Fu.SetQueuePtToINT(bot, true)
		bot:ActionQueue_UseAbilityOnEntity(lagunaBladeAbility, lagunaBladeTarget)
		return
	end
	-- After Laguna's own kill check, before the single-spell rules: the solo combo picks which of the three goes next.
	local comboStep, comboAim = X.ConsiderSoloCombo()
	if comboStep == "lsa" then
		Fu.SetQueuePtToINT(bot, true)
		bot:ActionQueue_UseAbilityOnLocation(lightStrikeArrayAbility, comboAim)
		return
	elseif comboStep == "slave" then
		Fu.SetQueuePtToINT(bot, true)
		bot:ActionQueue_UseAbilityOnLocation(dragonSlaveAbility, comboAim)
		return
	elseif comboStep == "laguna" then
		Fu.SetQueuePtToINT(bot, true)
		bot:ActionQueue_UseAbilityOnEntity(lagunaBladeAbility, comboAim)
		return
	end
	dragonSlaveDesire, dragonSlaveLocation = X.ConsiderQ()
	if dragonSlaveDesire > 0 then
		Fu.SetQueuePtToINT(bot, true)
		bot:ActionQueue_UseAbilityOnLocation(dragonSlaveAbility, dragonSlaveLocation)
		return
	end
	lightStrikeArrayDesire, lightStrikeArrayLocation = X.ConsiderW()
	if lightStrikeArrayDesire > 0 then
		Fu.SetQueuePtToINT(bot, true)
		bot:ActionQueue_UseAbilityOnLocation(lightStrikeArrayAbility, lightStrikeArrayLocation)
		return
	end
end
function X.ConsiderQ()
	if not dragonSlaveAbility:IsFullyCastable() then
		return 0
	end
	local abilityLevel = dragonSlaveAbility:GetLevel()
	local castRange = dragonSlaveAbility:GetCastRange() + aetherRange
	local castPoint = dragonSlaveAbility:GetCastPoint()
	local manaCost = dragonSlaveAbility:GetManaCost()
	-- datafeed: Dragon Slave damage is "dragon_slave_damage" (65/125/185/245); it has no AbilityDamage (read 0).
	local damage = dragonSlaveAbility:GetSpecialValueInt("dragon_slave_damage")
	local radius = dragonSlaveAbility:GetSpecialValueInt("dragon_slave_width_end")
	local damageType = DAMAGE_TYPE_MAGICAL
	local enemyHeroes = Fu.GetNearbyHeroes(bot, castRange - 80, true, BOT_MODE_NONE)
	local castLocation = nil
	for _, enemyHero in pairs(enemyHeroes) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and Fu.WillMagicKillTarget(bot, enemyHero, damage, castPoint)
		then
			castLocation = enemyHero:GetLocation()
			return BOT_ACTION_DESIRE_HIGH, castLocation, "Q击杀" .. Fu.Chat.GetNormName(enemyHero)
		end
	end
	local heroAoe = bot:FindAoELocation(true, true, bot:GetLocation(), castRange, radius + 50, 0, 0)
	if heroAoe.count >= 3 and bot:GetActiveMode() ~= BOT_MODE_RETREAT then
		castLocation = heroAoe.targetloc
		return BOT_ACTION_DESIRE_HIGH, castLocation, "Q消耗"
	end
	-- Lane harass keeps the mana for Light Strike Array + Laguna Blade (X.ComboReserve), so the harass never costs
	-- the kill combo; it fired at 30% mana with no reserve.
	if
		Fu.IsLaning(bot)
		and mpRatio > 0.3
		and not Fu.IsRetreating(bot)
		and NukerRules.CanSpend(bot:GetMana(), manaCost, X.ComboReserve())
	then
		local nearestEnemy = nil
		local nearestDistance = 99999
		for _, enemyHero in pairs(enemyHeroes) do
			if Fu.IsValidHero(enemyHero) and Fu.CanCastOnNonMagicImmune(enemyHero) then
				local distance = GetUnitToUnitDistance(bot, enemyHero)
				if distance < nearestDistance then
					nearestDistance = distance
					nearestEnemy = enemyHero
				end
			end
		end
		if nearestEnemy ~= nil then
			local creepAoe = bot:FindAoELocation(true, false, bot:GetLocation(), castRange, radius + 50, 0, damage)
			if creepAoe.count >= 2 and GetUnitToLocationDistance(nearestEnemy, creepAoe.targetloc) < radius + 100 then
				return BOT_ACTION_DESIRE_HIGH, creepAoe.targetloc, "Q补刀+消耗" .. Fu.Chat.GetNormName(nearestEnemy)
			end
			-- Harass a hero only when it pushes them out of the lane (NukerRules.HarassPushesOut: 60% HP or less after
			-- the hit, where the retreat mode sends a bot home); it went at any hero under 70% HP.
			local slaveDamage = damage * X.SpellMultiplier(nearestEnemy)
			if NukerRules.HarassPushesOut(nearestEnemy:GetHealth(), nearestEnemy:GetMaxHealth(), slaveDamage) then
				X.LogCombo("slave", "harass", nearestEnemy, "no", slaveDamage)
				castLocation = nearestEnemy:GetExtrapolatedLocation(castPoint)
				return BOT_ACTION_DESIRE_HIGH, castLocation, "Q对线消耗" .. Fu.Chat.GetNormName(nearestEnemy)
			end
		end
	end
	if Fu.IsInTeamFight(bot, 1200) then
		local aoeLocation = Fu.GetAoeEnemyHeroLocation(bot, castRange, radius, 2)
		if aoeLocation ~= nil then
			castLocation = aoeLocation
			return BOT_ACTION_DESIRE_HIGH, castLocation, "Q团战"
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		-- Light Strike Array first when it is up and the target is in its range and not disabled:
		-- this branch fired first (Q is checked before W), so the stun came after Dragon Slave.
		local lsaFirst = lightStrikeArrayAbility:IsFullyCastable()
			and Fu.IsValidHero(botTarget)
			and Fu.IsInRange(bot, botTarget, lightStrikeArrayAbility:GetCastRange() + aetherRange - 30)
			and not Fu.IsDisabled(botTarget)
		if
			Fu.IsValidHero(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(botTarget, bot, castRange - 80)
			and not lsaFirst
		then
			if abilityLevel >= 2 or mpRatio > 0.68 or Fu.GetHP(botTarget) < 0.38 then
				castLocation = botTarget:GetExtrapolatedLocation(castPoint)
				if Fu.IsInLocRange(bot, castLocation, castRange) then
					return BOT_ACTION_DESIRE_HIGH, castLocation, "Q打架" .. Fu.Chat.GetNormName(botTarget)
				end
			end
		end
	end
	if Fu.IsRetreating(bot) and not bot:HasModifier("modifier_lina_fiery_soul") then
		for _, enemyHero in pairs(enemyHeroes) do
			if
				Fu.IsValid(enemyHero)
				and bot:WasRecentlyDamagedByHero(enemyHero, 5.0)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and bot:IsFacingLocation(enemyHero:GetLocation(), 20)
			then
				castLocation = enemyHero:GetLocation()
				return BOT_ACTION_DESIRE_HIGH, castLocation, "Q撤退" .. Fu.Chat.GetNormName(enemyHero)
			end
		end
	end
	if Fu.IsFarming(bot) and abilityLevel >= 3 and Fu.IsAllowedToSpam(bot, manaCost * 0.25) then
		if
			Fu.IsValid(botTarget)
			and botTarget:GetTeam() == TEAM_NEUTRAL
			and Fu.IsInRange(bot, botTarget, 1000)
			and (botTarget:GetMagicResist() < 0.4 or mpRatio > 0.9)
		then
			local minCount = mpRatio > 0.6 and 2 or 3
			local neutralAoe = bot:FindAoELocation(true, false, bot:GetLocation(), castRange, radius, 0, 0)
			if neutralAoe.count >= minCount then
				castLocation = neutralAoe.targetloc
				return BOT_ACTION_DESIRE_HIGH, castLocation, "Q打钱" .. neutralAoe.count
			end
		end
	end
	if
		(Fu.IsPushing(bot) or Fu.IsDefending(bot) or Fu.IsFarming(bot))
		and Fu.IsAllowedToSpam(bot, manaCost * 0.32)
		and abilityLevel >= 2
		and DotaTime() > 8 * 60
		and #nearbyAllies <= 2
		and #nearbyEnemies == 0
	then
		local laneCreeps = bot:GetNearbyLaneCreeps(1400, true)
		if
			#laneCreeps >= 3
			and Fu.IsValid(laneCreeps[1])
			and not laneCreeps[1]:HasModifier("modifier_fountain_glyph")
		then
			local creepAoe = bot:FindAoELocation(true, false, bot:GetLocation(), castRange, radius, 0, damage)
			if creepAoe.count >= 2 and #nearbyAllies == 1 then
				castLocation = creepAoe.targetloc
				return BOT_ACTION_DESIRE_HIGH, castLocation, "Q带线1" .. creepAoe.count
			end
			local creepAoeWide = bot:FindAoELocation(true, false, bot:GetLocation(), castRange, radius + 50, 0, 0)
			if creepAoeWide.count >= 3 and #laneCreeps >= 4 then
				castLocation = creepAoeWide.targetloc
				return BOT_ACTION_DESIRE_HIGH, castLocation, "Q带线2" .. creepAoeWide.count
			end
		end
	end
	if bot:GetActiveMode() == BOT_MODE_ROSHAN and bot:GetMana() >= 400 then
		if Fu.IsRoshan(botTarget) and Fu.GetHP(botTarget) > 0.15 and Fu.IsInRange(botTarget, bot, castRange) then
			castLocation = botTarget:GetLocation()
			return BOT_ACTION_DESIRE_HIGH, castLocation, "Q肉山"
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, 800) and Fu.IsAttacking(bot) then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation(), ""
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
-- Mana kept for Light Strike Array + Laguna Blade (datafeed hero_id 25: LSA 100/110/120/130, Laguna 150/300/450 with
-- a 70/60/50s cooldown): LSA once learned, Laguna while learned and ready within NukerRules.ULT_SOON seconds.
function X.ComboReserve()
	local reserve = NukerRules.UltReserve(
		lagunaBladeAbility:IsTrained(),
		lagunaBladeAbility:GetManaCost(),
		lagunaBladeAbility:GetCooldownTimeRemaining(),
		false
	)
	if lightStrikeArrayAbility:IsTrained() then
		reserve = reserve + lightStrikeArrayAbility:GetManaCost()
	end
	return reserve
end
-- Her magical damage on this target per point of spell damage: her spell amp, the target's magic resistance.
function X.SpellMultiplier(target)
	return (1 + bot:GetSpellAmp()) * math.max(0.05, 1 - target:GetMagicResist())
end
function X.LogCombo(step, why, target, disabled, damage)
	bot._linaComboLogAt = bot._linaComboLogAt or {}
	if DotaTime() < (bot._linaComboLogAt[step] or -999) then
		return
	end
	bot._linaComboLogAt[step] = DotaTime() + 2
	pcall(
		print,
		string.format(
			"[OHA-LINA] t=%.0f lina combo step=%s why=%s target=%s disabled=%s mp=%.2f hp=%d dmg=%d",
			DotaTime(),
			step,
			why,
			target:GetUnitName(),
			disabled,
			mpRatio,
			target:GetHealth(),
			damage
		)
	)
end
-- Solo pressure (#47, replaces the level-15 "and false" Dragon Slave branch). The maintainer, 2026-11-21: Lina "can
-- solo enemy hero by spamming her ultimate, preferably when enemy is disabled (stunned) so lina can nuke them and enemy
-- do not run away after being ultimated". On one enemy hero (her target, else the weakest in Dragon Slave's range),
-- not while retreating, with at most 2 enemy heroes near and at most one more than her side: Light Strike Array -> Dragon Slave -> Laguna Blade, when
-- the target is held (stunned, rooted, hexed by anyone, or her own LSA is on its way) or her LSA opens the combo, and the
-- spells she can afford deal NukerRules.NEARLY_KILL of its HP (NukerRules.LinaComboStep). Returns the step and where.
function X.ConsiderSoloCombo()
	if Fu.IsRetreating(bot) then
		return nil
	end
	local lsaRange = lightStrikeArrayAbility:GetCastRange() + aetherRange
	local slaveRange = dragonSlaveAbility:GetCastRange() + aetherRange
	local lagunaRange = lagunaBladeAbility:GetCastRange() + aetherRange
	-- A combo already started (bot._linaCombo, by player ID, for 3s after each step) stays on its target.
	local combo = bot._linaCombo
	local committedId = combo ~= nil and DotaTime() < combo.untilAt and combo.playerId or nil
	local target = nil
	local inRange = Fu.GetNearbyHeroes(bot, slaveRange - 80, true, BOT_MODE_NONE) or {}
	for _, enemyHero in pairs(inRange) do
		if Fu.IsValidHero(enemyHero) and enemyHero:GetPlayerID() == committedId then
			target = enemyHero
		end
	end
	if target == nil and Fu.IsValidHero(botTarget) and Fu.IsInRange(bot, botTarget, slaveRange - 80) then
		target = botTarget
	end
	if target == nil then
		for _, enemyHero in pairs(inRange) do
			if Fu.IsValidHero(enemyHero) and (target == nil or enemyHero:GetHealth() < target:GetHealth()) then
				target = enemyHero
			end
		end
	end
	if
		target == nil
		or not Fu.CanCastOnNonMagicImmune(target)
		or Fu.IsSuspiciousIllusion(target)
		or Fu.IsHaveAegis(target)
	then
		return nil
	end
	local enemiesNear = Fu.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE) or {}
	local alliesNear = Fu.GetNearbyHeroes(bot, 1200, false, BOT_MODE_NONE) or {}
	-- Solo pressure only: with 3+ enemy heroes near, the team-fight rules (Light Strike Array and Dragon Slave on 2+
	-- heroes, Laguna on the weakest) choose the casts.
	if #enemiesNear > 2 or #enemiesNear > #alliesNear + 1 then
		return nil
	end
	-- Her LSA lands 0.45s cast point + 0.5s delay after the order (datafeed): the target counts as held for 1.5s.
	local targetId = target:GetPlayerID()
	local lsaPending = bot._linaLsaTarget == targetId and DotaTime() - (bot._linaLsaAt or -999) < 1.5
	local disabledNow = Fu.IsDisabled(target)
	local disabled = disabledNow and "now" or lsaPending and "lsa" or "no"
	local multiplier = X.SpellMultiplier(target)
	local lsaDamage = (lightStrikeArrayAbility:GetSpecialValueInt("light_strike_array_damage") + lsaBonusDamage)
		* multiplier
	local slaveDamage = dragonSlaveAbility:GetSpecialValueInt("dragon_slave_damage") * multiplier
	local lagunaDamage = lagunaBladeAbility:GetSpecialValueInt("damage") * multiplier
	local step, why = NukerRules.LinaComboStep({
		disabled = disabledNow or lsaPending,
		committed = committedId == targetId,
		hp = target:GetHealth(),
		mana = bot:GetMana(),
		lsaReady = lightStrikeArrayAbility:IsFullyCastable(),
		lsaInRange = Fu.IsInRange(bot, target, lsaRange - 30),
		lsaCost = lightStrikeArrayAbility:GetManaCost(),
		lsaDamage = lsaDamage,
		slaveReady = dragonSlaveAbility:IsFullyCastable(),
		slaveInRange = true,
		slaveCost = dragonSlaveAbility:GetManaCost(),
		slaveDamage = slaveDamage,
		lagunaReady = lagunaBladeAbility:IsFullyCastable() and X.CanCastAbilityROnTarget(target),
		lagunaInRange = Fu.IsInRange(bot, target, lagunaRange),
		lagunaCost = lagunaBladeAbility:GetManaCost(),
		lagunaDamage = lagunaDamage,
	})
	if step ~= nil then
		-- LSA lands ~1s after the order and stuns 1.2-2.4s (datafeed): 3s covers the rest of the combo.
		bot._linaCombo = { playerId = targetId, untilAt = DotaTime() + 3 }
	end
	if step == "lsa" then
		local radius = lightStrikeArrayAbility:GetSpecialValueInt("light_strike_array_aoe")
		local location = disabledNow and target:GetLocation()
			or Fu.GetDelayCastLocation(
				bot,
				target,
				lsaRange,
				radius,
				lightStrikeArrayAbility:GetCastPoint() + 0.5 + 0.3
			)
		if location == nil then
			return nil
		end
		bot._linaLsaTarget = targetId
		bot._linaLsaAt = DotaTime()
		X.LogCombo(step, why, target, disabled, lsaDamage)
		return step, location
	elseif step == "slave" then
		local location = disabledNow and target:GetLocation()
			or target:GetExtrapolatedLocation(dragonSlaveAbility:GetCastPoint())
		X.LogCombo(step, why, target, disabled, slaveDamage)
		return step, location
	elseif step == "laguna" then
		X.LogCombo(step, why, target, disabled, lagunaDamage)
		return step, target
	end
	return nil
end
function X.ConsiderW()
	if not lightStrikeArrayAbility:IsFullyCastable() then
		return 0
	end
	local abilityLevel = lightStrikeArrayAbility:GetLevel()
	local castRange = lightStrikeArrayAbility:GetCastRange() + aetherRange
	local castPoint = lightStrikeArrayAbility:GetCastPoint() + 0.5
	local manaCost = lightStrikeArrayAbility:GetManaCost()
	local damage = lightStrikeArrayAbility:GetSpecialValueInt("light_strike_array_damage") + lsaBonusDamage
	local damageType = DAMAGE_TYPE_MAGICAL
	local radius = lightStrikeArrayAbility:GetSpecialValueInt("light_strike_array_aoe")
	local enemyHeroes = Fu.GetNearbyHeroes(bot, castRange + radius * 0.5, true, BOT_MODE_NONE)
	local castLocation = nil
	for _, enemyHero in pairs(enemyHeroes) do
		if Fu.IsValidHero(enemyHero) and Fu.CanCastOnNonMagicImmune(enemyHero) then
			if enemyHero:IsChanneling() then
				castLocation = Fu.GetDelayCastLocation(bot, enemyHero, castRange, radius, castPoint)
				if castLocation ~= nil then
					return BOT_ACTION_DESIRE_HIGH, castLocation, "W打断" .. Fu.Chat.GetNormName(enemyHero)
				end
			end
			if Fu.WillMagicKillTarget(bot, enemyHero, damage, castPoint) then
				castLocation = Fu.GetDelayCastLocation(bot, enemyHero, castRange, radius, castPoint + 0.2)
				if castLocation ~= nil then
					return BOT_ACTION_DESIRE_HIGH, castLocation, "W击杀" .. Fu.Chat.GetNormName(enemyHero)
				end
			end
		end
	end
	local heroAoe = bot:FindAoELocation(true, true, bot:GetLocation(), castRange, radius + 20, 0, 0)
	if heroAoe.count >= 3 then
		castLocation = heroAoe.targetloc
		return BOT_ACTION_DESIRE_HIGH, castLocation, "W消耗"
	end
	if Fu.IsInTeamFight(bot, 1200) then
		local aoeLocation = Fu.GetAoeEnemyHeroLocation(bot, castRange, radius, 2)
		if aoeLocation ~= nil then
			castLocation = aoeLocation
			return BOT_ACTION_DESIRE_HIGH, castLocation, "W团战"
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidHero(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(botTarget, bot, castRange - 30)
		then
			castLocation = Fu.GetDelayCastLocation(bot, botTarget, castRange, radius, castPoint + 0.3)
			if castLocation ~= nil then
				return BOT_ACTION_DESIRE_HIGH, castLocation, "W打架" .. Fu.Chat.GetNormName(botTarget)
			end
		end
	end
	if Fu.IsRetreating(bot) then
		local aoeLocation = Fu.GetAoeEnemyHeroLocation(bot, castRange - 100, radius - 20, 2)
		if aoeLocation ~= nil then
			castLocation = aoeLocation
			return BOT_ACTION_DESIRE_HIGH, castLocation, "W撤退1"
		end
		for _, enemyHero in pairs(enemyHeroes) do
			if
				Fu.IsValid(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and (
					bot:WasRecentlyDamagedByHero(enemyHero, 4.0)
					or bot:GetActiveModeDesire() > BOT_ACTION_DESIRE_VERYHIGH
				)
			then
				castLocation = Fu.GetDelayCastLocation(bot, enemyHero, castRange, radius, castPoint + 0.3)
				if castLocation ~= nil then
					return BOT_ACTION_DESIRE_HIGH, castLocation, "W撤退2" .. Fu.Chat.GetNormName(enemyHero)
				end
			end
		end
	end
	if
		bot:WasRecentlyDamagedByAnyHero(3.0)
		and botLevel >= 10
		and bot:GetActiveMode() ~= BOT_MODE_RETREAT
		and #enemyHeroes >= 1
	then
		for _, enemyHero in pairs(enemyHeroes) do
			if
				Fu.IsValid(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and bot:IsFacingLocation(enemyHero:GetLocation(), 45)
			then
				castLocation = Fu.GetDelayCastLocation(bot, enemyHero, castRange, radius - 30, castPoint + 0.3)
				if castLocation ~= nil then
					return BOT_ACTION_DESIRE_HIGH, castLocation, "W自保" .. Fu.Chat.GetNormName(enemyHero)
				end
			end
		end
	end
	if Fu.IsFarming(bot) and abilityLevel >= 3 and Fu.IsAllowedToSpam(bot, manaCost * 0.25) then
		if
			Fu.IsValid(botTarget)
			and botTarget:GetTeam() == TEAM_NEUTRAL
			and Fu.IsInRange(bot, botTarget, 1000)
			and (botTarget:GetMagicResist() < 0.4 or mpRatio > 0.9)
		then
			local minCount = mpRatio > 0.6 and 3 or 4
			local neutralAoe = bot:FindAoELocation(true, false, bot:GetLocation(), castRange, radius, 0, 0)
			if neutralAoe.count >= minCount then
				castLocation = neutralAoe.targetloc
				return BOT_ACTION_DESIRE_HIGH, castLocation, "W打钱" .. neutralAoe.count
			end
		end
	end
	if
		(Fu.IsPushing(bot) or Fu.IsDefending(bot) or Fu.IsFarming(bot))
		and Fu.IsAllowedToSpam(bot, manaCost * 0.32)
		and abilityLevel >= 3
		and DotaTime() > 9 * 60
		and #nearbyAllies <= 1
		and #nearbyEnemies == 0
	then
		local laneCreeps = bot:GetNearbyLaneCreeps(castRange + 200, true)
		if
			#laneCreeps >= 4
			and Fu.IsValid(laneCreeps[1])
			and not laneCreeps[1]:HasModifier("modifier_fountain_glyph")
		then
			local creepAoe = bot:FindAoELocation(true, false, bot:GetLocation(), castRange, radius, castPoint, damage)
			if creepAoe.count >= 3 then
				castLocation = creepAoe.targetloc
				return BOT_ACTION_DESIRE_HIGH, castLocation, "W带线1" .. creepAoe.count
			end
			local creepAoeWide = bot:FindAoELocation(true, false, bot:GetLocation(), castRange, radius + 50, 0.5, 0)
			if creepAoeWide.count >= 4 then
				castLocation = creepAoeWide.targetloc
				return BOT_ACTION_DESIRE_HIGH, castLocation, "W带线2" .. creepAoeWide.count
			end
		end
	end
	if bot:GetActiveMode() == BOT_MODE_ROSHAN and bot:GetMana() >= 600 then
		if Fu.IsRoshan(botTarget) and Fu.GetHP(botTarget) > 0.3 and Fu.IsInRange(botTarget, bot, castRange) then
			castLocation = botTarget:GetLocation()
			return BOT_ACTION_DESIRE_HIGH, castLocation, "W肉山"
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, 800) and Fu.IsAttacking(bot) then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation(), ""
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderR()
	if not lagunaBladeAbility:IsFullyCastable() then
		return 0
	end
	local abilityLevel = lagunaBladeAbility:GetLevel()
	local castRange = lagunaBladeAbility:GetCastRange() + aetherRange
	local castPoint = lagunaBladeAbility:GetCastPoint()
	local manaCost = lagunaBladeAbility:GetManaCost()
	local damage = lagunaBladeAbility:GetSpecialValueInt("damage")
	-- datafeed: Laguna Blade is magical (2) with no Scepter upgrade (the Scepter now grants Flame Cloak).
	local damageType = DAMAGE_TYPE_MAGICAL
	local enemyHeroes = Fu.GetNearbyHeroes(bot, castRange + 80, true, BOT_MODE_NONE)
	local enemiesInKillRange = Fu.GetNearbyHeroes(bot, castRange + 240, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(enemiesInKillRange) do
		if Fu.IsValidHero(enemyHero) and not Fu.IsHaveAegis(enemyHero) and X.CanCastAbilityROnTarget(enemyHero) then
			if Fu.WillMagicKillTarget(bot, enemyHero, damage, castPoint + 0.25) then
				return BOT_ACTION_DESIRE_HIGH, enemyHero, "R击杀" .. Fu.Chat.GetNormName(enemyHero)
			end
		end
	end
	if Fu.IsInTeamFight(bot, 600) or hpRatio < 0.3 and abilityLevel >= 2 then
		local weakestEnemy = nil
		local lowestHealth = 10000
		for _, enemyHero in pairs(enemyHeroes) do
			if Fu.IsValid(enemyHero) and X.CanCastAbilityROnTarget(enemyHero) then
				local health = enemyHero:GetHealth()
				if health < lowestHealth then
					lowestHealth = health
					weakestEnemy = enemyHero
				end
			end
		end
		if weakestEnemy ~= nil then
			return BOT_ACTION_DESIRE_HIGH, weakestEnemy, "R团战" .. Fu.Chat.GetNormName(weakestEnemy)
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidHero(botTarget)
			and X.CanCastAbilityROnTarget(botTarget)
			and Fu.IsInRange(botTarget, bot, castRange + 100)
		then
			if Fu.WillMagicKillTarget(bot, botTarget, damage * 1.88, castPoint + 0.25) then
				return BOT_ACTION_DESIRE_HIGH, botTarget, "R打架" .. Fu.Chat.GetNormName(botTarget)
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.CanCastAbilityROnTarget(target)
	if Fu.CanCastOnTargetAdvanced(target) and not target:HasModifier("modifier_arc_warden_tempest_double") then
		-- datafeed: Laguna has no Scepter upgrade any more, so it never goes through magic immunity.
		return Fu.CanCastOnNonMagicImmune(target)
	end
	return false
end
function X.ConsiderFlameCloak()
	if not flameCloakAbility:IsTrained() or not flameCloakAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
	end
	local attackRange = bot:GetAttackRange()
	local enemiesInRange = Fu.GetNearbyHeroes(bot, attackRange, true, BOT_MODE_NONE)
	local alliesInRange = Fu.GetNearbyHeroes(bot, attackRange, false, BOT_MODE_NONE)
	if
		Fu.IsRetreating(bot)
		and (enemiesInRange ~= nil and alliesInRange ~= nil and #enemiesInRange >= #alliesInRange)
		and not Fu.WeAreStronger(bot, attackRange)
	then
		return BOT_ACTION_DESIRE_HIGH
	end
	-- Before Laguna Blade: Flame Cloak gives 35% spell amp (Valve data), and it is ordered before
	-- ConsiderR, so the blade gets the amp. It only went with 2+ enemies in attack range.
	if
		Fu.IsGoingOnSomeone(bot)
		and lagunaBladeAbility:IsFullyCastable()
		and bot:GetMana() >= flameCloakAbility:GetManaCost() + lagunaBladeAbility:GetManaCost()
		and Fu.IsValidHero(botTarget)
		and not Fu.IsSuspiciousIllusion(botTarget)
		and X.CanCastAbilityROnTarget(botTarget)
		and Fu.IsInRange(bot, botTarget, lagunaBladeAbility:GetCastRange() + aetherRange)
		and Fu.GetHP(botTarget) < 0.6
	then
		if DotaTime() >= (bot._cloakLogAt or -999) then
			bot._cloakLogAt = DotaTime() + 5
			pcall(print, string.format("[OHA-LINA] t=%.0f flame cloak before laguna", DotaTime()))
		end
		return BOT_ACTION_DESIRE_HIGH
	end
	if Fu.IsGoingOnSomeone(bot) and (enemiesInRange ~= nil and #enemiesInRange >= 2) then
		local botTarget = bot:GetTarget()
		if Fu.IsValidTarget(botTarget) and Fu.CanCastOnNonMagicImmune(botTarget) then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
return X
