-- Viper: skill build, item build, and ability use for this hero.
local X = {}
local bot = GetBot()
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local AbilityContext = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local Minion = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local sTalentList = Fu.Skill.GetTalentList(bot)
local sAbilityList = Fu.Skill.GetAbilityList(bot)
local sRole = Fu.Item.GetRoleItemsBuyList(bot)
local tTalentTreeList = {
	{ ["t25"] = { 0, 10 }, ["t20"] = { 10, 0 }, ["t15"] = { 10, 0 }, ["t10"] = { 0, 10 } },
	{ ["t25"] = { 0, 10 }, ["t20"] = { 10, 0 }, ["t15"] = { 10, 0 }, ["t10"] = { 10, 0 } },
}
local tAllAbilityBuildList =
	{ { 1, 3, 1, 2, 1, 6, 1, 2, 2, 3, 6, 3, 2, 3, 6 }, { 1, 3, 1, 3, 1, 6, 1, 2, 3, 3, 6, 2, 2, 2, 6 } }
local nAbilityBuildList
local nTalentBuildList
if sRole == "pos_2" then
	nAbilityBuildList = tAllAbilityBuildList[1]
	nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList[1])
else
	nAbilityBuildList = tAllAbilityBuildList[2]
	nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList[2])
end
local sSphereOrLotus = RandomInt(1, 9) > 5 and "item_sphere" or "item_lotus_orb"
local sMkbOrButterfly = RandomInt(1, 9) > 6 and "item_monkey_king_bar" or "item_butterfly"
local sRoleItemsBuyList = {}
-- Stratz 7.41f, week of 9 Nov 2026: pos 1, 11,742 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_1"] = {
	"item_tango",
	"item_double_branches",
	"item_circlet",
	"item_faerie_fire",
	"item_slippers",
	"item_wraith_band",
	"item_magic_wand",
	"item_power_treads",
	"item_dragon_lance",
	"item_manta",
	"item_hurricane_pike",
	"item_travel_boots",
	"item_black_king_bar",
	"item_aghanims_shard",
	sSphereOrLotus,
	sMkbOrButterfly,
	"item_moon_shard",
	"item_travel_boots_2",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 2, 72,518 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_2"] = {
	"item_tango",
	"item_double_branches",
	"item_circlet",
	"item_faerie_fire",
	"item_slippers",
	"item_wraith_band",
	"item_magic_wand",
	"item_boots",
	"item_dragon_lance",
	"item_travel_boots",
	"item_hurricane_pike",
	"item_ultimate_scepter",
	sSphereOrLotus,
	"item_black_king_bar",
	"item_aghanims_shard",
	sMkbOrButterfly,
	"item_ultimate_scepter_2",
	"item_blink",
	"item_moon_shard",
	"item_travel_boots_2",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 3, 47,885 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_3"] = {
	"item_tango",
	"item_circlet",
	"item_double_branches",
	"item_faerie_fire",
	"item_slippers",
	"item_wraith_band",
	"item_magic_wand",
	"item_power_treads",
	"item_hurricane_pike",
	"item_ultimate_scepter",
	sSphereOrLotus,
	"item_black_king_bar",
	"item_aghanims_shard",
	"item_ultimate_scepter_2",
	"item_blade_mail",
	"item_blink",
	"item_moon_shard",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 4, 12,528 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_4"] = {
	"item_tango",
	"item_blood_grenade",
	"item_double_branches",
	"item_circlet",
	"item_enchanted_mango",
	"item_magic_wand",
	"item_power_treads",
	"item_rod_of_atos",
	"item_dragon_lance",
	"item_hurricane_pike",
	"item_aghanims_shard",
	sSphereOrLotus,
	"item_blade_mail",
	"item_blink",
	"item_moon_shard",
	"item_ultimate_scepter_2",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 5, 7,921 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_5"] = {
	"item_tango",
	"item_blood_grenade",
	"item_double_branches",
	"item_circlet",
	"item_enchanted_mango",
	"item_magic_wand",
	"item_power_treads",
	"item_rod_of_atos",
	"item_dragon_lance",
	"item_force_staff",
	"item_travel_boots",
	"item_hurricane_pike",
	"item_aghanims_shard",
	sSphereOrLotus,
	"item_blink",
	"item_blade_mail",
	"item_moon_shard",
	"item_ultimate_scepter_2",
}
X["sBuyList"] = sRoleItemsBuyList[sRole]
X["sSellList"] = { "item_black_king_bar", "item_quelling_blade", "item_mage_slayer", "item_butterfly" }
if Fu.Role.IsPvNMode() or Fu.Role.IsAllShadow() then
	X["sBuyList"], X["sSellList"] = { "PvN_mid" }, {}
end
nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"] =
	Fu.SetUserHeroInit(nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"])
X["sSkillList"] = Fu.Skill.GetSkillList(sAbilityList, nAbilityBuildList, sTalentList, nTalentBuildList)
X["bDeafaultAbility"] = true
X["bDeafaultItem"] = false
function X.MinionThink(hMinionUnit)
	Minion.MinionThink(hMinionUnit)
end
local poisonAttackAbility = SafeAbility(bot:GetAbilityByName("viper_poison_attack"), "viper_poison_attack", "viper")
local nethertoxinAbility = SafeAbility(bot:GetAbilityByName("viper_nethertoxin"), "viper_nethertoxin", "viper")
local noseDiveAbility = SafeAbility(bot:GetAbilityByName("viper_nose_dive"), "viper_nose_dive", "viper")
local viperStrikeAbility = SafeAbility(bot:GetAbilityByName("viper_viper_strike"), "viper_viper_strike", "viper")
local poisonAttackDesire, poisonAttackTarget
local nethertoxinDesire, nethertoxinLocation
local noseDiveDesire, noseDiveLocation
local viperStrikeDesire, viperStrikeTarget
local botTarget
local isGoingOnSomeone
local isRetreating
local isAttacking
local mpRatio
function X.SkillsComplement()
	if Fu.CanNotUseAbility(bot) or bot:IsInvisible() then
		return
	end
	isGoingOnSomeone = Fu.IsGoingOnSomeone(bot)
	isRetreating = Fu.IsRetreating(bot)
	isAttacking = Fu.IsAttacking(bot)
	mpRatio = Fu.GetMP(bot)
	botTarget = Fu.GetProperTarget(bot)
	if Fu.IsValidHero(botTarget) then
		if not poisonAttackAbility:GetAutoCastState() then
			poisonAttackAbility:ToggleAutoCast()
		end
	else
		if poisonAttackAbility:GetAutoCastState() then
			poisonAttackAbility:ToggleAutoCast()
		end
	end
	viperStrikeDesire, viperStrikeTarget = X.ConsiderViperStrike()
	if viperStrikeDesire > 0 then
		if Fu.HasPowerTreads(bot) then
			Fu.SetQueuePtToINT(bot, true)
			bot:ActionQueue_UseAbilityOnEntity(viperStrikeAbility, viperStrikeTarget)
		else
			bot:Action_UseAbilityOnEntity(viperStrikeAbility, viperStrikeTarget)
		end
		return
	end
	noseDiveDesire, noseDiveLocation = X.ConsiderNosedive()
	if noseDiveDesire > 0 then
		if Fu.HasPowerTreads(bot) then
			Fu.SetQueuePtToINT(bot, true)
			bot:ActionQueue_UseAbilityOnLocation(noseDiveAbility, noseDiveLocation)
		else
			bot:Action_UseAbilityOnLocation(noseDiveAbility, noseDiveLocation)
		end
		return
	end
	nethertoxinDesire, nethertoxinLocation = X.ConsiderNetherToxin()
	if nethertoxinDesire > 0 then
		if Fu.HasPowerTreads(bot) then
			Fu.SetQueuePtToINT(bot, true)
			bot:ActionQueue_UseAbilityOnLocation(nethertoxinAbility, nethertoxinLocation)
		else
			bot:Action_UseAbilityOnLocation(nethertoxinAbility, nethertoxinLocation)
		end
		return
	end
	poisonAttackDesire, poisonAttackTarget = X.ConsiderPoisonAttack()
	if poisonAttackDesire > 0 then
		-- The autocast branches toggle autocast and return no target: nothing to cast then (game
		-- 034, 25:27 and 63:20: two casts refused for a nil target).
		if poisonAttackTarget ~= nil then
			bot:Action_UseAbilityOnEntity(poisonAttackAbility, poisonAttackTarget)
		end
		return
	end
end
function X.ConsiderPoisonAttack()
	if not poisonAttackAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castRange = Fu.GetProperCastRange(false, bot, poisonAttackAbility:GetCastRange())
	local attackRange = bot:GetAttackRange()
	local damage = poisonAttackAbility:GetSpecialValueInt("damage")
	local duration = poisonAttackAbility:GetSpecialValueInt("duration")
	if not isRetreating then
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.CanKillTarget(enemyHero, damage * duration, DAMAGE_TYPE_MAGICAL)
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
				and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
				and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
				and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
				and not enemyHero:HasModifier("modifier_templar_assassin_refraction_absorb")
			then
				return BOT_ACTION_DESIRE_HIGH, enemyHero
			end
		end
	end
	-- Lane poke with Poison Attack (user call; Viper Strike is no longer used for that). Laning, not
	-- retreating, over 40% mana and HP: an enemy hero within cast range, not standing under his
	-- tower, gets one (20 mana, 600 range, slows and stacks).
	if not isRetreating and Fu.IsInLaningPhase() and mpRatio > 0.4 and Fu.GetHP(bot) > 0.4 then
		for _, enemyHero in pairs(Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE) or {}) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and not enemyHero:IsAttackImmune()
				and #(enemyHero:GetNearbyTowers(750, false) or {}) == 0
			then
				return BOT_ACTION_DESIRE_HIGH, enemyHero
			end
		end
	end
	if isGoingOnSomeone then
		if
			Fu.IsValidTarget(botTarget)
			and botTarget:CanBeSeen()
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not botTarget:IsMagicImmune()
			and not botTarget:IsInvulnerable()
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			local alliesNearTarget = Fu.GetNearbyHeroes(botTarget, 1200, true, BOT_MODE_NONE)
			local enemiesNearTarget = Fu.GetNearbyHeroes(botTarget, 1200, false, BOT_MODE_NONE)
			if
				alliesNearTarget ~= nil
				and enemiesNearTarget ~= nil
				and #alliesNearTarget >= #enemiesNearTarget
				and Fu.GetManaAfter(poisonAttackAbility:GetManaCost()) * bot:GetMana()
					> viperStrikeAbility:GetManaCost()
			then
				if Fu.IsInRange(bot, botTarget, attackRange) and not botTarget:IsAttackImmune() then
					if not poisonAttackAbility:GetAutoCastState() then
						poisonAttackAbility:ToggleAutoCast()
						return BOT_ACTION_DESIRE_HIGH, nil
					else
						return BOT_ACTION_DESIRE_NONE, nil
					end
				end
				if Fu.IsInRange(bot, botTarget, castRange) and not Fu.IsInRange(bot, botTarget, attackRange) then
					return BOT_ACTION_DESIRE_HIGH, botTarget
				end
			end
		end
	end
	if isRetreating then
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
		if
			Fu.IsValidHero(nearbyEnemies[1])
			and Fu.IsChasingTarget(nearbyEnemies[1], bot)
			and not nearbyEnemies[1]:HasModifier("modifier_viper_poison_attack_slow")
			and not nearbyEnemies[1]:IsMagicImmune()
			and not nearbyEnemies[1]:IsInvulnerable()
		then
			return BOT_ACTION_DESIRE_HIGH, nearbyEnemies[1]
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if Fu.IsRoshan(botTarget) and Fu.IsInRange(bot, botTarget, 500) and isAttacking then
			if not poisonAttackAbility:GetAutoCastState() and mpRatio > 0.25 then
				poisonAttackAbility:ToggleAutoCast()
				return BOT_ACTION_DESIRE_HIGH, nil
			else
				if poisonAttackAbility:GetAutoCastState() and mpRatio < 0.25 then
					poisonAttackAbility:ToggleAutoCast()
					return BOT_ACTION_DESIRE_HIGH, nil
				end
				return BOT_ACTION_DESIRE_NONE, nil
			end
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, 500) and isAttacking then
			if not poisonAttackAbility:GetAutoCastState() and mpRatio > 0.25 then
				poisonAttackAbility:ToggleAutoCast()
				return BOT_ACTION_DESIRE_HIGH, nil
			else
				if poisonAttackAbility:GetAutoCastState() and mpRatio < 0.25 then
					poisonAttackAbility:ToggleAutoCast()
					return BOT_ACTION_DESIRE_HIGH, nil
				end
				return BOT_ACTION_DESIRE_NONE, nil
			end
		end
	end
	local nearbyAllies = Fu.GetNearbyHeroes(bot, castRange, false, BOT_MODE_NONE)
	for _, allyHero in pairs(nearbyAllies) do
		local allyNearbyEnemies = Fu.GetNearbyHeroes(allyHero, 1200, true, BOT_MODE_NONE)
		for _, enemyHero in pairs(allyNearbyEnemies) do
			if
				Fu.IsValidHero(allyHero)
				and Fu.IsRetreating(allyHero)
				and allyHero:WasRecentlyDamagedByAnyHero(2)
				and not allyHero:IsIllusion()
			then
				if
					Fu.IsValidHero(enemyHero)
					and Fu.CanCastOnNonMagicImmune(enemyHero)
					and Fu.IsInRange(bot, enemyHero, castRange)
					and Fu.IsChasingTarget(enemyHero, allyHero)
					and not Fu.IsDisabled(enemyHero)
					and not Fu.IsTaunted(enemyHero)
					and not Fu.IsSuspiciousIllusion(enemyHero)
					and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
					and not enemyHero:HasModifier("modifier_viper_poison_attack_slow")
				then
					return BOT_ACTION_DESIRE_HIGH, enemyHero
				end
			end
		end
	end
	if poisonAttackAbility:GetAutoCastState() then
		poisonAttackAbility:ToggleAutoCast()
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function X.ConsiderNetherToxin()
	if not nethertoxinAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local castRange = Fu.GetProperCastRange(false, bot, nethertoxinAbility:GetCastRange())
	local radius = nethertoxinAbility:GetSpecialValueInt("radius")
	local abilityLevel = nethertoxinAbility:GetLevel()
	if isGoingOnSomeone then
		if
			Fu.IsValidHero(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
			and not botTarget:HasModifier("modifier_viper_nethertoxin")
		then
			local alliesNearTarget = Fu.GetNearbyHeroes(botTarget, 1200, true, BOT_MODE_NONE)
			local enemiesNearTarget = Fu.GetNearbyHeroes(botTarget, 1200, false, BOT_MODE_NONE)
			if alliesNearTarget ~= nil and enemiesNearTarget ~= nil and #alliesNearTarget >= #enemiesNearTarget then
				if Fu.IsInRange(bot, botTarget, castRange) then
					return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
				end
				if Fu.IsInRange(bot, botTarget, castRange + radius) and not Fu.IsInRange(bot, botTarget, castRange) then
					return BOT_ACTION_DESIRE_HIGH,
						Fu.Site.GetXUnitsTowardsLocation(bot, botTarget:GetLocation(), castRange)
				end
			end
		end
	end
	if isRetreating and bot:GetActiveModeDesire() > 0.5 then
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and not Fu.IsDisabled(enemyHero)
			then
				local alliesNearEnemy = Fu.GetNearbyHeroes(enemyHero, 1200, true, BOT_MODE_NONE)
				local enemiesNearEnemy = Fu.GetNearbyHeroes(enemyHero, 1200, false, BOT_MODE_NONE)
				if
					alliesNearEnemy ~= nil
					and enemiesNearEnemy ~= nil
					and (#enemiesNearEnemy > #alliesNearEnemy or bot:WasRecentlyDamagedByAnyHero(2))
				then
					return BOT_ACTION_DESIRE_HIGH, enemyHero:GetExtrapolatedLocation(0.5)
				end
			end
		end
	end
	if Fu.IsPushing(bot) or Fu.IsDefending(bot) then
		local nearbyLaneCreeps = bot:GetNearbyLaneCreeps(1000, true)
		if nearbyLaneCreeps ~= nil and #nearbyLaneCreeps >= 4 and not Fu.IsRunning(nearbyLaneCreeps[1]) then
			return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(nearbyLaneCreeps)
		end
	end
	if
		Fu.IsFarming(bot)
		and Fu.GetManaAfter(nethertoxinAbility:GetManaCost()) * bot:GetMana() > viperStrikeAbility:GetManaCost()
		and abilityLevel >= 2
	then
		if isAttacking then
			local nearbyNeutrals = bot:GetNearbyNeutralCreeps(bot:GetAttackRange() + 200)
			local unitsAroundCenter =
				Fu.GetNearbyAroundLocationUnitCount(true, false, radius, Fu.GetCenterOfUnits(nearbyNeutrals))
			if
				nearbyNeutrals ~= nil
				and #nearbyNeutrals >= 1
				and Fu.GetManaAfter(nethertoxinAbility:GetManaCost()) * bot:GetMana()
					> viperStrikeAbility:GetManaCost()
			then
				if Fu.IsBigCamp(nearbyNeutrals) or nearbyNeutrals[1]:IsAncientCreep() then
					if #nearbyNeutrals >= 2 and unitsAroundCenter >= 2 then
						return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(nearbyNeutrals)
					end
				else
					if #nearbyNeutrals >= 3 and unitsAroundCenter >= 2 then
						return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(nearbyNeutrals)
					end
				end
			end
			local nearbyLaneCreeps = bot:GetNearbyLaneCreeps(bot:GetAttackRange() + 200, true)
			unitsAroundCenter =
				Fu.GetNearbyAroundLocationUnitCount(true, false, radius, Fu.GetCenterOfUnits(nearbyLaneCreeps))
			if nearbyLaneCreeps ~= nil and #nearbyLaneCreeps >= 3 and unitsAroundCenter >= 2 then
				return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(nearbyLaneCreeps)
			end
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if
			Fu.IsRoshan(botTarget)
			and Fu.IsInRange(bot, botTarget, 500)
			and isAttacking
			and not botTarget:IsMagicImmune()
			and not botTarget:HasModifier("modifier_viper_nethertoxin")
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if
			Fu.IsTormentor(botTarget)
			and Fu.IsInRange(bot, botTarget, 500)
			and isAttacking
			and not botTarget:HasModifier("modifier_viper_nethertoxin")
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
-- Viper Strike (datafeed: 750 range, 70/110/150 per second for 6s, breaks passives, 50/40/30s).
-- Rework (user call, game 031: he ulted a hero to poke in lane and then did nothing; lane pokes are
-- for Poison Attack). It used to go on any enemy hero within ~830. Now only:
-- 1. a kill: the full poison kills an enemy hero in range;
-- 2. a team fight: the best target in range, a core first (estimated position 1-2), then a hero
--    whose passive matters (the list below), then his attack target;
-- 3. going on someone: his target in range; while laning only when it is an all-in (target under
--    60% HP, or our heroes there outnumber his);
-- 4. Roshan.
local PASSIVE_HEROES = {
	npc_dota_hero_bristleback = true,
	npc_dota_hero_spectre = true,
	npc_dota_hero_huskar = true,
	npc_dota_hero_dragon_knight = true,
	npc_dota_hero_tidehunter = true,
	npc_dota_hero_phantom_assassin = true,
	npc_dota_hero_antimage = true,
	npc_dota_hero_mars = true,
	npc_dota_hero_centaur = true,
	npc_dota_hero_necrolyte = true,
}
-- Viper Strike pierces spell immunity (npc data: SPELL_IMMUNITY_ENEMIES_YES and the
-- MAGIC_IMMUNE_ENEMIES target flag), so a BKB'd carry is a valid target; the old
-- CanCastOnNonMagicImmune check skipped exactly the cores the ult is best on.
local function StrikeOk(enemyHero)
	return Fu.IsValidHero(enemyHero)
		and Fu.CanCastOnMagicImmune(enemyHero)
		and Fu.CanCastOnTargetAdvanced(enemyHero)
		and not Fu.IsSuspiciousIllusion(enemyHero)
		and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
		and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
		and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
		and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
		and not enemyHero:HasModifier("modifier_item_aeon_disk_buff")
		and not enemyHero:HasModifier("modifier_item_sphere_target")
end
local function LogStrike(why, enemyHero)
	pcall(
		print,
		string.format(
			"[OHA-VIPER] t=%.0f strike why=%s target=%s hp=%.2f",
			DotaTime(),
			why,
			(string.gsub(enemyHero:GetUnitName(), "npc_dota_hero_", "")),
			Fu.GetHP(enemyHero)
		)
	)
end
function X.ConsiderViperStrike()
	if not viperStrikeAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castRange = viperStrikeAbility:GetCastRange() + 50
	local total = viperStrikeAbility:GetSpecialValueInt("damage") * viperStrikeAbility:GetSpecialValueInt("duration")
	local inRange = {}
	for _, enemyHero in pairs(Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE) or {}) do
		if StrikeOk(enemyHero) then
			inRange[#inRange + 1] = enemyHero
		end
	end
	if #inRange == 0 then
		if
			Fu.IsDoingRoshan(bot)
			and Fu.IsRoshan(botTarget)
			and Fu.IsInRange(bot, botTarget, 500)
			and isAttacking
			and not botTarget:HasModifier("modifier_roshan_spell_block")
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
		return BOT_ACTION_DESIRE_NONE, nil
	end
	-- 1. A kill (GetActualIncomingDamage already applies the target's magic resistance / immunity).
	for _, enemyHero in ipairs(inRange) do
		if enemyHero:GetHealth() < enemyHero:GetActualIncomingDamage(total, DAMAGE_TYPE_MAGICAL) then
			LogStrike("kill", enemyHero)
			return BOT_ACTION_DESIRE_HIGH, enemyHero
		end
	end
	-- 2. A team fight: a core, then a passive hero, then his target.
	if Fu.IsInTeamFight(bot, 1200) then
		local core, passive = nil, nil
		for _, enemyHero in ipairs(inRange) do
			local positionOk, position = pcall(Fu.GetPosition, enemyHero)
			if core == nil and positionOk and type(position) == "number" and position <= 2 then
				core = enemyHero
			end
			if passive == nil and PASSIVE_HEROES[enemyHero:GetUnitName()] then
				passive = enemyHero
			end
		end
		local pick = core or passive
		if pick == nil and Fu.IsValidHero(botTarget) then
			for _, enemyHero in ipairs(inRange) do
				if enemyHero == botTarget then
					pick = enemyHero
				end
			end
		end
		if pick ~= nil then
			LogStrike(pick == core and "fight-core" or (pick == passive and "fight-passive" or "fight-target"), pick)
			return BOT_ACTION_DESIRE_HIGH, pick
		end
	end
	-- 3. Going on someone: his target; while laning only on an all-in.
	if isGoingOnSomeone and Fu.IsValidHero(botTarget) then
		for _, enemyHero in ipairs(inRange) do
			if enemyHero == botTarget then
				local allIn = true
				if Fu.IsInLaningPhase() then
					local ours = #(Fu.GetNearbyHeroes(botTarget, 1200, true, BOT_MODE_NONE) or {})
					local theirs = #(Fu.GetNearbyHeroes(botTarget, 1200, false, BOT_MODE_NONE) or {})
					allIn = Fu.GetHP(botTarget) < 0.6 or ours > theirs
				end
				if allIn then
					LogStrike("engage", enemyHero)
					return BOT_ACTION_DESIRE_HIGH, enemyHero
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function X.ConsiderNosedive()
	if not noseDiveAbility:IsTrained() or not noseDiveAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local castRange = Fu.GetProperCastRange(false, bot, noseDiveAbility:GetCastRange())
	local radius = 500
	if isGoingOnSomeone then
		if Fu.IsValidTarget(botTarget) and not Fu.IsSuspiciousIllusion(botTarget) and not botTarget:IsMagicImmune() then
			local alliesNearTarget = Fu.GetNearbyHeroes(botTarget, 1200, true, BOT_MODE_NONE)
			local enemiesNearTarget = Fu.GetNearbyHeroes(botTarget, 1200, false, BOT_MODE_NONE)
			if alliesNearTarget ~= nil and enemiesNearTarget ~= nil and #alliesNearTarget >= #enemiesNearTarget then
				enemiesNearTarget = Fu.GetEnemiesNearLoc(botTarget:GetLocation(), radius)
				if enemiesNearTarget ~= nil and #enemiesNearTarget >= 1 then
					if Fu.IsInRange(bot, botTarget, castRange) then
						return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(enemiesNearTarget)
					end
					if
						Fu.IsInRange(bot, botTarget, castRange + radius) and not Fu.IsInRange(bot, botTarget, castRange)
					then
						return BOT_ACTION_DESIRE_HIGH,
							Fu.Site.GetXUnitsTowardsLocation(bot, Fu.GetCenterOfUnits(enemiesNearTarget), castRange)
					end
				end
				if Fu.IsInRange(bot, botTarget, castRange) then
					return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
				end
				if Fu.IsInRange(bot, botTarget, castRange + radius) and not Fu.IsInRange(bot, botTarget, castRange) then
					return BOT_ACTION_DESIRE_HIGH,
						Fu.Site.GetXUnitsTowardsLocation(bot, botTarget:GetLocation(), castRange)
				end
			end
		end
	end
	if isRetreating and bot:GetActiveModeDesire() > 0.75 then
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.IsChasingTarget(enemyHero, bot)
				and bot:IsFacingLocation(Fu.GetTeamFountain(), 30)
				and bot:DistanceFromFountain() > 600
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and not Fu.IsDisabled(enemyHero)
				and not Fu.IsRealInvisible(bot)
			then
				local alliesNearEnemy = Fu.GetNearbyHeroes(enemyHero, 1200, true, BOT_MODE_NONE)
				local enemiesNearEnemy = Fu.GetNearbyHeroes(enemyHero, 1200, false, BOT_MODE_NONE)
				if
					alliesNearEnemy ~= nil
					and enemiesNearEnemy ~= nil
					and (#enemiesNearEnemy > #alliesNearEnemy or bot:WasRecentlyDamagedByAnyHero(2))
				then
					return BOT_ACTION_DESIRE_HIGH,
						Fu.Site.GetXUnitsTowardsLocation(bot, Fu.GetTeamFountain(), castRange)
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
return X
