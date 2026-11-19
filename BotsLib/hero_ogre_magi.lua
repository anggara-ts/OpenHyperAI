-- Ogre Magi: skill build, item build, and ability use for this hero.
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
local tTalentTreeList = {
	{ ["t25"] = { 10, 0 }, ["t20"] = { 0, 10 }, ["t15"] = { 0, 10 }, ["t10"] = { 0, 10 } },
	{ ["t25"] = { 10, 0 }, ["t20"] = { 10, 0 }, ["t15"] = { 0, 10 }, ["t10"] = { 0, 10 } },
}
local tAllAbilityBuildList =
	{ { 3, 2, 2, 1, 2, 6, 2, 1, 1, 1, 6, 3, 3, 3, 6 }, { 2, 1, 2, 1, 2, 6, 2, 1, 1, 3, 6, 3, 3, 3, 6 } }
local nAbilityBuildList
local nTalentBuildList
if sRole == "pos_2" then
	nAbilityBuildList = tAllAbilityBuildList[1]
	nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList[1])
else
	nAbilityBuildList = tAllAbilityBuildList[2]
	nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList[2])
end
local sRoleItemsBuyList = {}
sRoleItemsBuyList["pos_3"] = {
	"item_tango",
	"item_gauntlets",
	"item_double_branches",
	"item_quelling_blade",
	"item_circlet",
	"item_bracer",
	"item_magic_wand",
	"item_power_treads",
	"item_hand_of_midas",
	"item_crimson_guard",
	"item_aghanims_shard",
	"item_ultimate_scepter",
	"item_blink",
	"item_travel_boots",
	"item_assault",
	"item_sheepstick",
	"item_moon_shard",
	"item_travel_boots_2",
	"item_ultimate_scepter_2",
	"item_octarine_core",
}
sRoleItemsBuyList["pos_1"] = {
	"item_bristleback_outfit",
	"item_hand_of_midas",
	"item_aghanims_shard",
	"item_ultimate_scepter",
	"item_dagon_5",
	"item_travel_boots",
	"item_sheepstick",
	"item_octarine_core",
	"item_moon_shard",
	"item_travel_boots_2",
	"item_ultimate_scepter_2",
	"item_bloodthorn",
}
sRoleItemsBuyList["pos_2"] = {
	"item_tango",
	"item_double_branches",
	"item_bracer",
	"item_bottle",
	"item_phase_boots",
	"item_soul_ring",
	"item_magic_wand",
	"item_hand_of_midas",
	"item_blade_mail",
	"item_heart",
	"item_black_king_bar",
	"item_shivas_guard",
	"item_ultimate_scepter",
	"item_octarine_core",
	"item_travel_boots",
	"item_ultimate_scepter_2",
	"item_sheepstick",
	"item_travel_boots_2",
	"item_moon_shard",
	"item_aghanims_shard",
}
sRoleItemsBuyList["pos_4"] = {
	"item_priest_outfit",
	"item_hand_of_midas",
	"item_mekansm",
	"item_glimmer_cape",
	"item_aghanims_shard",
	"item_guardian_greaves",
	"item_blink",
	"item_lotus_orb",
	"item_gungir",
	"item_ultimate_scepter",
	"item_sheepstick",
	"item_mystic_staff",
	"item_ultimate_scepter_2",
	"item_shivas_guard",
	"item_moon_shard",
}
sRoleItemsBuyList["pos_5"] = {
	-- Arcane Boots (crystal_maiden_outfit) instead of Tranquil Boots, and Blink Dagger instead of
	-- Spirit Vessel: Arcane 71% (#2), Blink 64% (#3) of his matches (Dotabuff, last patch).
	"item_tango",
	"item_blood_grenade",
	"item_magic_stick",
	"item_branches",
	"item_enchanted_mango",
	"item_magic_wand",
	"item_arcane_boots",
	"item_hand_of_midas",
	"item_glimmer_cape",
	"item_blink",
	"item_pavise",
	"item_pipe",
	"item_solar_crest",
	"item_lotus_orb",
	"item_aghanims_shard",
	"item_ultimate_scepter",
	"item_shivas_guard",
	"item_mystic_staff",
	"item_ultimate_scepter_2",
	"item_moon_shard",
	"item_sheepstick",
}
X["sBuyList"] = sRoleItemsBuyList[sRole]
X["sSellList"] = { "item_black_king_bar", "item_quelling_blade", "item_sheepstick", "item_hand_of_midas" }
if Fu.Role.IsPvNMode() or Fu.Role.IsAllShadow() then
	X["sBuyList"], X["sSellList"] = { "PvN_OM" }, { "item_power_treads", "item_quelling_blade" }
end
nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"] =
	Fu.SetUserHeroInit(nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"])
X["sSkillList"] = Fu.Skill.GetSkillList(sAbilityList, nAbilityBuildList, sTalentList, nTalentBuildList)
X["bDeafaultAbility"] = false
X["bDeafaultItem"] = false
function X.MinionThink(hMinionUnit)
	Minion.MinionThink(hMinionUnit)
end
local fireblastAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[1]), "sAbilityList[1]", "ogre_magi")
local igniteAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[2]), "sAbilityList[2]", "ogre_magi")
local bloodlustAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[3]), "sAbilityList[3]", "ogre_magi")
-- datafeed: by name, not by ability-list slot. The Scepter Unrefined Fireblast and the Shard Fire
-- Shield (ogre_magi_smash) are hidden granted abilities, so sAbilityList[4]/sAbilityList[5] need not be them.
local unrefinedFireblastAbility =
	SafeAbility(bot:GetAbilityByName("ogre_magi_unrefined_fireblast"), "ogre_magi_unrefined_fireblast", "ogre_magi")
local fireShieldAbility = SafeAbility(bot:GetAbilityByName("ogre_magi_smash"), "ogre_magi_smash", "ogre_magi")
local talent2 = SafeAbility(bot:GetAbilityByName(sTalentList[2]), "sTalentList[2]", "ogre_magi")
local talent8 = SafeAbility(bot:GetAbilityByName(sTalentList[8]), "sTalentList[8]", "ogre_magi")
local fireblastDesire, fireblastTarget
local igniteDesire, igniteTarget
local bloodlustDesire, bloodlustTarget
local unrefinedFireblastDesire, unrefinedFireblastTarget
local fireShieldDesire, fireShieldTarget
local aetherRange = 0
local fireblastDamageBonus = 0
local isAttacking
local botLevel, manaReserve, mpRatio, hpRatio, nearbyEnemies, nearbyAllies
function X.SkillsComplement()
	if Fu.CanNotUseAbility(bot) or bot:IsInvisible() then
		return
	end
	isAttacking = Fu.IsAttacking(bot)
	local context = AbilityContext.Build(bot)
	manaReserve = 300
	aetherRange = context.aetherRange
	fireblastDamageBonus = 0
	botLevel = context.level
	mpRatio = context.mp
	hpRatio = context.hp
	botTarget = context.target
	nearbyEnemies = context.enemies
	nearbyAllies = context.allies
	if talent8:IsTrained() then
		fireblastDamageBonus = fireblastDamageBonus + talent8:GetSpecialValueInt("value")
	end
	fireblastDesire, fireblastTarget = X.ConsiderQ()
	if fireblastDesire > 0 then
		Fu.SetQueuePtToINT(bot, true)
		bot:ActionQueue_UseAbilityOnEntity(fireblastAbility, fireblastTarget)
		return
	end
	igniteDesire, igniteTarget = X.ConsiderW()
	if igniteDesire > 0 then
		Fu.SetQueuePtToINT(bot, true)
		bot:ActionQueue_UseAbilityOnEntity(igniteAbility, igniteTarget)
		return
	end
	bloodlustDesire, bloodlustTarget = X.ConsiderE()
	if bloodlustDesire > 0 then
		Fu.SetQueuePtToINT(bot, true)
		bot:ActionQueue_UseAbilityOnEntity(bloodlustAbility, bloodlustTarget)
		return
	end
	unrefinedFireblastDesire, unrefinedFireblastTarget = X.ConsiderD()
	if unrefinedFireblastDesire > 0 then
		Fu.SetQueuePtToINT(bot, false)
		bot:ActionQueue_UseAbilityOnEntity(unrefinedFireblastAbility, unrefinedFireblastTarget)
		return
	end
	fireShieldDesire, fireShieldTarget = X.ConsiderFireShield()
	if fireShieldDesire > 0 then
		Fu.SetQueuePtToINT(bot, true)
		bot:ActionQueue_UseAbilityOnEntity(fireShieldAbility, fireShieldTarget)
		return
	end
end
function X.ConsiderQ()
	if not fireblastAbility:IsFullyCastable() then
		return 0
	end
	local abilityLevel = fireblastAbility:GetLevel()
	local castRange = fireblastAbility:GetCastRange() + aetherRange
	if #nearbyEnemies <= 1 then
		castRange = castRange + 200
	end
	local castPoint = fireblastAbility:GetCastPoint()
	local manaCost = fireblastAbility:GetManaCost()
	local damage = fireblastAbility:GetSpecialValueInt("fireblast_damage") + fireblastDamageBonus
	local damageType = DAMAGE_TYPE_MAGICAL
	local enemiesInRange = Fu.GetNearbyHeroes(bot, castRange + 50, true, BOT_MODE_NONE)
	local enemiesInSearchRange = Fu.GetNearbyHeroes(bot, castRange + 200, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(enemiesInSearchRange) do
		if
			Fu.IsValid(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and Fu.CanCastOnTargetAdvanced(enemyHero)
		then
			if enemyHero:IsChanneling() then
				return BOT_ACTION_DESIRE_HIGH, enemyHero, "Q打断" .. Fu.Chat.GetNormName(enemyHero)
			end
			if
				Fu.IsInRange(bot, enemyHero, castRange + 80)
				and Fu.WillMagicKillTarget(bot, enemyHero, damage * 2.38, castPoint)
			then
				return BOT_ACTION_DESIRE_HIGH, enemyHero, "Q击杀" .. Fu.Chat.GetNormName(enemyHero)
			end
		end
	end
	if Fu.IsInTeamFight(bot, 1200) then
		local strongestEnemy = nil
		local maxDamage = 0
		for _, enemyHero in pairs(enemiesInRange) do
			if
				Fu.IsValid(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
				and not Fu.IsDisabled(enemyHero)
			then
				local estimatedDamage = enemyHero:GetEstimatedDamageToTarget(false, bot, 3.0, DAMAGE_TYPE_PHYSICAL)
				if estimatedDamage > maxDamage then
					maxDamage = estimatedDamage
					strongestEnemy = enemyHero
				end
			end
		end
		if strongestEnemy ~= nil then
			return BOT_ACTION_DESIRE_HIGH, strongestEnemy, "Q团战" .. Fu.Chat.GetNormName(strongestEnemy)
		end
	end
	if
		bot:WasRecentlyDamagedByAnyHero(3.0)
		and botLevel >= 10
		and bot:GetActiveMode() ~= BOT_MODE_RETREAT
		and #enemiesInRange >= 1
	then
		for _, enemyHero in pairs(enemiesInRange) do
			if
				Fu.IsValid(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
				and not Fu.IsDisabled(enemyHero)
				and not enemyHero:IsDisarmed()
				and bot:IsFacingLocation(enemyHero:GetLocation(), 60)
			then
				return BOT_ACTION_DESIRE_HIGH, enemyHero, "Q自保" .. Fu.Chat.GetNormName(enemyHero)
			end
		end
	end
	if bot:GetActiveMode() == BOT_MODE_LANING or (#nearbyAllies <= 1 or Fu.IsCore(bot)) and #nearbyEnemies == 0 then
		local nearbyLaneCreeps = bot:GetNearbyLaneCreeps(castRange + 200, true)
		local creepType = "ranged"
		for _, creep in pairs(nearbyLaneCreeps) do
			if
				Fu.IsValid(creep)
				and not creep:HasModifier("modifier_fountain_glyph")
				and Fu.IsKeyWordUnit(creepType, creep)
				and not Fu.IsOtherAllysTarget(creep)
				and Fu.WillKillTarget(creep, damage, damageType, castPoint)
				and GetUnitToUnitDistance(creep, bot) > 280
			then
				return BOT_ACTION_DESIRE_HIGH, creep, "Q补远"
			end
		end
		if abilityLevel >= 2 and (bot:GetMana() > manaReserve or mpRatio > 0.9) then
			local creepType = "melee"
			for _, creep in pairs(nearbyLaneCreeps) do
				if
					Fu.IsValid(creep)
					and not creep:HasModifier("modifier_fountain_glyph")
					and Fu.IsKeyWordUnit(creepType, creep)
					and not Fu.IsOtherAllysTarget(creep)
					and Fu.WillKillTarget(creep, damage, damageType, castPoint)
					and GetUnitToUnitDistance(creep, bot) > 350
				then
					return BOT_ACTION_DESIRE_HIGH, creep, "Q补近"
				end
			end
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidHero(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.CanCastOnTargetAdvanced(botTarget)
			and Fu.IsInRange(botTarget, bot, castRange + 50)
			and not Fu.IsDisabled(botTarget)
			and not botTarget:IsDisarmed()
		then
			if abilityLevel >= 3 or mpRatio > 0.78 or Fu.GetHP(botTarget) < 0.38 or botLevel >= 7 then
				return BOT_ACTION_DESIRE_HIGH, botTarget, "Q先手" .. Fu.Chat.GetNormName(botTarget)
			end
		end
	end
	if Fu.IsRetreating(bot) then
		for _, enemyHero in pairs(enemiesInRange) do
			if
				Fu.IsValid(enemyHero)
				and bot:WasRecentlyDamagedByHero(enemyHero, 5.0)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
				and not Fu.IsDisabled(enemyHero)
			then
				return BOT_ACTION_DESIRE_HIGH, enemyHero, "Q撤退" .. Fu.Chat.GetNormName(enemyHero)
			end
		end
	end
	if Fu.IsFarming(bot) and abilityLevel >= 3 and Fu.IsAllowedToSpam(bot, manaCost * 0.25) then
		local nearbyNeutrals = bot:GetNearbyNeutralCreeps(castRange + 100)
		local targetCreep = Fu.GetMostHpUnit(nearbyNeutrals)
		if
			Fu.IsValid(targetCreep)
			and not Fu.IsRoshan(targetCreep)
			and (#nearbyNeutrals >= 2 or GetUnitToUnitDistance(targetCreep, bot) <= 400)
			and bot:IsFacingLocation(targetCreep:GetLocation(), 60)
			and (targetCreep:GetMagicResist() < 0.3 or mpRatio > 0.9)
			and not Fu.CanKillTarget(targetCreep, bot:GetAttackDamage() * 2.28, DAMAGE_TYPE_PHYSICAL)
			and not Fu.CanKillTarget(targetCreep, damage - 10, damageType)
		then
			return BOT_ACTION_DESIRE_HIGH, targetCreep, "Q打野"
		end
	end
	if
		(Fu.IsPushing(bot) or Fu.IsDefending(bot) or Fu.IsFarming(bot))
		and Fu.IsAllowedToSpam(bot, manaCost * 0.32)
		and (bot:GetAttackDamage() < 200 or mpRatio > 0.8)
		and abilityLevel >= 2
		and DotaTime() > 6 * 60
		and #nearbyAllies <= 2
		and #nearbyEnemies == 0
	then
		local nearbyLaneCreeps = bot:GetNearbyLaneCreeps(castRange + 50, true)
		local creepType = "ranged"
		for _, creep in pairs(nearbyLaneCreeps) do
			if
				Fu.IsValid(creep)
				and (Fu.IsKeyWordUnit(creepType, creep) or mpRatio > 0.6)
				and not creep:HasModifier("modifier_fountain_glyph")
				and Fu.WillKillTarget(creep, damage, damageType, castPoint)
				and not Fu.CanKillTarget(creep, bot:GetAttackDamage() * 1.38, DAMAGE_TYPE_PHYSICAL)
			then
				return BOT_ACTION_DESIRE_HIGH, creep, "Q带线"
			end
		end
	end
	if bot:GetActiveMode() == BOT_MODE_ROSHAN and bot:GetMana() >= 400 then
		if
			Fu.IsRoshan(botTarget)
			and not Fu.IsDisabled(botTarget)
			and not botTarget:IsDisarmed()
			and Fu.IsInRange(botTarget, bot, castRange)
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget, "Q肉山"
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(botTarget, bot, 800) and isAttacking then
			return BOT_ACTION_DESIRE_HIGH, botTarget, ""
		end
	end
	if
		(#nearbyEnemies > 0 or bot:WasRecentlyDamagedByAnyHero(3.0))
		and (bot:GetActiveMode() ~= BOT_MODE_RETREAT or #nearbyAllies >= 2)
		and #enemiesInRange >= 1
		and botLevel >= 15
	then
		for _, enemyHero in pairs(enemiesInRange) do
			if
				Fu.IsValid(enemyHero)
				and Fu.IsInRange(bot, enemyHero, 600)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
				and not Fu.IsDisabled(enemyHero)
			then
				return BOT_ACTION_DESIRE_HIGH, enemyHero, "Q通用"
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderW()
	if not igniteAbility:IsFullyCastable() then
		return 0
	end
	local abilityLevel = igniteAbility:GetLevel()
	local castRange = igniteAbility:GetCastRange() + aetherRange
	local castPoint = igniteAbility:GetCastPoint()
	local manaCost = igniteAbility:GetManaCost()
	local duration = igniteAbility:GetSpecialValueInt("duration")
	local damage = igniteAbility:GetSpecialValueInt("burn_damage") * duration
	local damageType = DAMAGE_TYPE_MAGICAL
	local enemiesInRange = Fu.GetNearbyHeroes(bot, castRange + 32, true, BOT_MODE_NONE)
	local enemiesInSearchRange = Fu.GetNearbyHeroes(bot, castRange + 200, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(enemiesInSearchRange) do
		if
			Fu.IsValid(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and Fu.CanCastOnTargetAdvanced(enemyHero)
			and Fu.WillMagicKillTarget(bot, enemyHero, damage, duration)
		then
			return BOT_ACTION_DESIRE_HIGH, enemyHero, "W击杀" .. Fu.Chat.GetNormName(enemyHero)
		end
	end
	if Fu.IsInTeamFight(bot, 1200) then
		local healthiestEnemy = nil
		local maxHealth = 0
		for _, enemyHero in pairs(enemiesInRange) do
			if
				Fu.IsValid(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
			then
				local health = enemyHero:GetHealth()
				if health > maxHealth then
					maxHealth = health
					healthiestEnemy = enemyHero
				end
			end
		end
		if healthiestEnemy ~= nil then
			return BOT_ACTION_DESIRE_HIGH, healthiestEnemy, "W团战" .. Fu.Chat.GetNormName(healthiestEnemy)
		end
	end
	if
		bot:WasRecentlyDamagedByAnyHero(3.0)
		and botLevel >= 10
		and bot:GetActiveMode() ~= BOT_MODE_RETREAT
		and #enemiesInRange >= 1
	then
		for _, enemyHero in pairs(enemiesInRange) do
			if
				Fu.IsValid(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
				and bot:IsFacingLocation(enemyHero:GetLocation(), 30)
			then
				return BOT_ACTION_DESIRE_HIGH, enemyHero, "W保护" .. Fu.Chat.GetNormName(enemyHero)
			end
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidHero(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.CanCastOnTargetAdvanced(botTarget)
			and Fu.IsInRange(botTarget, bot, castRange)
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget, "W先手" .. Fu.Chat.GetNormName(botTarget)
		end
	end
	if Fu.IsRetreating(bot) then
		for _, enemyHero in pairs(enemiesInRange) do
			if
				Fu.IsValid(enemyHero)
				and bot:WasRecentlyDamagedByHero(enemyHero, 5.0)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
			then
				return BOT_ACTION_DESIRE_HIGH, enemyHero, "W撤退" .. Fu.Chat.GetNormName(enemyHero)
			end
		end
	end
	if Fu.IsFarming(bot) and abilityLevel >= 2 and botLevel >= 6 and Fu.IsAllowedToSpam(bot, manaCost * 0.25) then
		local nearbyNeutrals = bot:GetNearbyNeutralCreeps(castRange + 100)
		local targetCreep = Fu.GetMostHpUnit(nearbyNeutrals)
		if
			Fu.IsValid(targetCreep)
			and not Fu.IsRoshan(targetCreep)
			and (#nearbyNeutrals >= 2 or GetUnitToUnitDistance(targetCreep, bot) <= 400)
			and bot:IsFacingLocation(targetCreep:GetLocation(), 40)
			and (targetCreep:GetMagicResist() < 0.3 or mpRatio > 0.8)
			and not Fu.CanKillTarget(targetCreep, bot:GetAttackDamage() * 2.28, DAMAGE_TYPE_PHYSICAL)
			and not Fu.CanKillTarget(targetCreep, damage * 0.38, damageType)
		then
			return BOT_ACTION_DESIRE_HIGH, targetCreep, "W打野"
		end
	end
	if
		(Fu.IsPushing(bot) or Fu.IsDefending(bot) or Fu.IsFarming(bot))
		and Fu.IsAllowedToSpam(bot, manaCost * 0.32)
		and (bot:GetAttackDamage() < 200 or mpRatio > 0.8)
		and abilityLevel >= 2
		and DotaTime() > 8 * 60
		and #nearbyAllies <= 2
	then
		local enemyLaneCreeps = bot:GetNearbyLaneCreeps(1600, true)
		if #enemyLaneCreeps >= 3 then
			local nearbyLaneCreeps = bot:GetNearbyLaneCreeps(castRange + 50, true)
			local allyLaneCreeps = bot:GetNearbyLaneCreeps(1000, false)
			local creepType = "ranged"
			for _, creep in pairs(nearbyLaneCreeps) do
				if
					Fu.IsValid(creep)
					and (Fu.IsKeyWordUnit(creepType, creep) or #allyLaneCreeps == 0)
					and not creep:HasModifier("modifier_fountain_glyph")
					and not Fu.CanKillTarget(creep, bot:GetAttackDamage() * 1.68, DAMAGE_TYPE_PHYSICAL)
				then
					return BOT_ACTION_DESIRE_HIGH, creep, "W带线"
				end
			end
		end
	end
	if
		(#nearbyEnemies > 0 or bot:WasRecentlyDamagedByAnyHero(3.0))
		and (bot:GetActiveMode() ~= BOT_MODE_RETREAT or #nearbyAllies >= 2)
		and #enemiesInRange >= 1
		and botLevel >= 18
	then
		for _, enemyHero in pairs(enemiesInRange) do
			if
				Fu.IsValid(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
			then
				return BOT_ACTION_DESIRE_HIGH, enemyHero, "W通用"
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderE()
	if not bloodlustAbility:IsFullyCastable() then
		return 0
	end
	local abilityLevel = bloodlustAbility:GetLevel()
	local castRange = bloodlustAbility:GetCastRange() + aetherRange
	local castPoint = bloodlustAbility:GetCastPoint()
	local manaCost = bloodlustAbility:GetManaCost()
	local attackDamage = bot:GetAttackDamage()
	local damageType = DAMAGE_TYPE_MAGICAL
	local allyCreeps = bot:GetNearbyCreeps(castRange + 100, false)
	local allyTowers = bot:GetNearbyTowers(castRange + 50, false)
	local alliesNearby = Fu.GetAlliesNearLoc(bot:GetLocation(), castRange + 52)
	local strongestAlly = nil
	local maxAttackDamage = 0
	for _, allyHero in pairs(alliesNearby) do
		if
			Fu.IsValidHero(allyHero)
			and not allyHero:HasModifier("modifier_ogre_magi_bloodlust")
			and not Fu.IsDisabled(allyHero)
			and not Fu.IsWithoutTarget(allyHero)
			and allyHero:GetAttackDamage() > maxAttackDamage
		then
			strongestAlly = allyHero
			maxAttackDamage = allyHero:GetAttackDamage()
		end
	end
	if Fu.IsGoingOnSomeone(bot) and Fu.IsValidHero(botTarget) and strongestAlly ~= nil then
		if strongestAlly == bot and Fu.IsInRange(bot, botTarget, 900) then
			return BOT_ACTION_DESIRE_HIGH, strongestAlly, "E自己"
		end
		if strongestAlly ~= bot and Fu.IsInRange(bot, botTarget, 2000) then
			return BOT_ACTION_DESIRE_HIGH, strongestAlly, "E队友" .. Fu.Chat.GetNormName(strongestAlly)
		end
	end
	if #nearbyEnemies > 0 then
		local targetAlly = nil
		local maxFountainDistance = 300
		for _, allyHero in pairs(alliesNearby) do
			if
				Fu.IsValidHero(allyHero)
				and not allyHero:HasModifier("modifier_ogre_magi_bloodlust")
				and Fu.IsRetreating(allyHero)
				and allyHero:WasRecentlyDamagedByAnyHero(5.0)
				and allyHero:DistanceFromFountain() > maxFountainDistance
			then
				targetAlly = allyHero
				maxFountainDistance = allyHero:DistanceFromFountain()
			end
		end
		if targetAlly ~= nil then
			return BOT_ACTION_DESIRE_HIGH, targetAlly, "E撤退" .. Fu.Chat.GetNormName(targetAlly)
		end
	end
	if botLevel >= 6 then
		local targetAlly = nil
		local minAttackDamage = 108
		for _, allyHero in pairs(alliesNearby) do
			if
				Fu.IsValidHero(allyHero)
				and not allyHero:HasModifier("modifier_ogre_magi_bloodlust")
				and (Fu.IsFarming(allyHero) or Fu.IsPushing(allyHero) or Fu.IsDefending(allyHero))
				and allyHero:GetAttackDamage() > minAttackDamage
			then
				targetAlly = allyHero
				minAttackDamage = allyHero:GetAttackDamage()
			end
		end
		if targetAlly ~= nil then
			return BOT_ACTION_DESIRE_HIGH, targetAlly, "E打钱" .. Fu.Chat.GetNormName(targetAlly)
		end
		local allyTower = allyTowers[1]
		if
			Fu.IsValidBuilding(allyTower)
			and not allyTower:HasModifier("modifier_ogre_magi_bloodlust")
			and not Fu.IsWithoutTarget(allyTower)
			and #nearbyEnemies >= 1
		then
			return BOT_ACTION_DESIRE_HIGH, allyTower, "E守塔"
		end
		if #allyCreeps > 0 then
			for _, creep in pairs(allyCreeps) do
				if Fu.IsValid(creep) and not creep:HasModifier("modifier_ogre_magi_bloodlust") then
					if Fu.IsKeyWordUnit("siege", creep) and not Fu.IsWithoutTarget(creep) then
						local creepTarget = creep:GetAttackTarget()
						if Fu.IsValidBuilding(creepTarget) and creepTarget:GetAttackTarget() ~= creep then
							return BOT_ACTION_DESIRE_HIGH, creep, "E攻城车"
						end
					end
					if Fu.IsKeyWordUnit("warlock", creep) and #nearbyEnemies > 0 then
						return BOT_ACTION_DESIRE_HIGH, creep, "E地狱火"
					end
					if
						Fu.IsKeyWordUnit("ranged", creep)
						and Fu.GetHP(creep) > 0.8
						and botLevel >= 12
						and #nearbyEnemies == 0
						and #nearbyAllies == 1
					then
						local enemyLaneCreeps = bot:GetNearbyLaneCreeps(1600, true)
						if #enemyLaneCreeps == 0 then
							return BOT_ACTION_DESIRE_HIGH, creep, "E远程兵"
						end
					end
				end
			end
		end
	end
	if bot:GetActiveMode() == BOT_MODE_ROSHAN and strongestAlly ~= nil then
		if Fu.IsRoshan(botTarget) and Fu.IsInRange(botTarget, bot, 1000) and isAttacking then
			return BOT_ACTION_DESIRE_HIGH, strongestAlly, "E打肉" .. Fu.Chat.GetNormName(strongestAlly)
		end
	end
	if Fu.IsDoingTormentor(bot) and strongestAlly ~= nil then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(botTarget, bot, 800) and isAttacking then
			return BOT_ACTION_DESIRE_HIGH, strongestAlly, ""
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderD()
	if
		fireblastAbility:IsFullyCastable()
		or not unrefinedFireblastAbility:IsFullyCastable()
		or not bot:HasScepter()
	then
		return 0
	end
	local abilityLevel = unrefinedFireblastAbility:GetLevel()
	local castRange = unrefinedFireblastAbility:GetCastRange() + aetherRange
	if #nearbyEnemies <= 1 then
		castRange = castRange + 200
	end
	local castPoint = unrefinedFireblastAbility:GetCastPoint()
	local manaCost = unrefinedFireblastAbility:GetManaCost()
	-- Unrefined Fireblast has no "fireblast_damage" key (it read 0, so every kill check here was false):
	-- its damage is base_damage + str_multiplier x Ogre's Strength (game data and datafeed).
	local damage = unrefinedFireblastAbility:GetSpecialValueInt("base_damage")
		+ unrefinedFireblastAbility:GetSpecialValueFloat("str_multiplier")
			* bot:GetAttributeValue(ATTRIBUTE_STRENGTH)
	local damageType = DAMAGE_TYPE_MAGICAL
	local enemiesInRange = Fu.GetNearbyHeroes(bot, castRange + 50, true, BOT_MODE_NONE)
	local enemiesInSearchRange = Fu.GetNearbyHeroes(bot, castRange + 200, true, BOT_MODE_NONE)
	if manaCost / bot:GetMaxMana() > 0.45 and hpRatio > 0.25 then
		return 0
	end
	for _, enemyHero in pairs(enemiesInSearchRange) do
		if
			Fu.IsValid(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and Fu.CanCastOnTargetAdvanced(enemyHero)
		then
			if enemyHero:IsChanneling() then
				return BOT_ACTION_DESIRE_HIGH, enemyHero, "D打断" .. Fu.Chat.GetNormName(enemyHero)
			end
			if
				Fu.IsInRange(bot, enemyHero, castRange + 80)
				and Fu.WillMagicKillTarget(bot, enemyHero, damage * 2.38, castPoint)
			then
				return BOT_ACTION_DESIRE_HIGH, enemyHero, "D击杀" .. Fu.Chat.GetNormName(enemyHero)
			end
		end
	end
	if Fu.IsInTeamFight(bot, 1200) then
		local weakestEnemy = nil
		local minHealth = 10000
		for _, enemyHero in pairs(enemiesInRange) do
			if
				Fu.IsValid(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
				and not Fu.IsDisabled(enemyHero)
			then
				local health = enemyHero:GetHealth()
				if health < minHealth then
					minHealth = health
					weakestEnemy = enemyHero
				end
			end
		end
		if weakestEnemy ~= nil then
			return BOT_ACTION_DESIRE_HIGH, weakestEnemy, "D团战" .. Fu.Chat.GetNormName(weakestEnemy)
		end
	end
	if
		bot:WasRecentlyDamagedByAnyHero(3.0)
		and botLevel >= 15
		and bot:GetActiveMode() ~= BOT_MODE_RETREAT
		and #enemiesInRange >= 1
	then
		for _, enemyHero in pairs(enemiesInRange) do
			if
				Fu.IsValid(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
				and not Fu.IsDisabled(enemyHero)
				and not enemyHero:IsDisarmed()
				and bot:IsFacingLocation(enemyHero:GetLocation(), 45)
			then
				return BOT_ACTION_DESIRE_HIGH, enemyHero, "D保护" .. Fu.Chat.GetNormName(enemyHero)
			end
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidHero(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.CanCastOnTargetAdvanced(botTarget)
			and Fu.IsInRange(botTarget, bot, castRange + 50)
			and not Fu.IsDisabled(botTarget)
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget, "D打架" .. Fu.Chat.GetNormName(botTarget)
		end
	end
	if Fu.IsRetreating(bot) then
		for _, enemyHero in pairs(enemiesInRange) do
			if
				Fu.IsValid(enemyHero)
				and bot:WasRecentlyDamagedByHero(enemyHero, 5.0)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
				and not Fu.IsDisabled(enemyHero)
				and not enemyHero:IsDisarmed()
				and (#enemiesInSearchRange <= 2 or bot:IsFacingLocation(enemyHero:GetLocation(), 30))
			then
				return BOT_ACTION_DESIRE_HIGH, enemyHero, "D撤退" .. Fu.Chat.GetNormName(enemyHero)
			end
		end
	end
	if Fu.IsFarming(bot) and manaCost < bot:GetMaxMana() * 0.1 then
		local nearbyNeutrals = bot:GetNearbyNeutralCreeps(castRange + 100)
		local targetCreep = Fu.GetMostHpUnit(nearbyNeutrals)
		if
			Fu.IsValid(targetCreep)
			and not Fu.IsRoshan(targetCreep)
			and (#nearbyNeutrals >= 2 or GetUnitToUnitDistance(targetCreep, bot) <= 400)
			and bot:IsFacingLocation(targetCreep:GetLocation(), 40)
			and (targetCreep:GetMagicResist() < 0.3 or mpRatio > 0.9)
			and not Fu.CanKillTarget(targetCreep, bot:GetAttackDamage() * 1.88, DAMAGE_TYPE_PHYSICAL)
			and not Fu.CanKillTarget(targetCreep, damage - 10, damageType)
		then
			return BOT_ACTION_DESIRE_HIGH, targetCreep, "D打野"
		end
	end
	if
		(Fu.IsPushing(bot) or Fu.IsDefending(bot) or Fu.IsFarming(bot))
		and manaCost < 120
		and #nearbyAllies <= 2
		and #nearbyEnemies == 0
	then
		local nearbyLaneCreeps = bot:GetNearbyLaneCreeps(castRange + 50, true)
		local creepType = "ranged"
		for _, creep in pairs(nearbyLaneCreeps) do
			if
				Fu.IsValid(creep)
				and (Fu.IsKeyWordUnit(creepType, creep) or mpRatio > 0.6)
				and not creep:HasModifier("modifier_fountain_glyph")
				and Fu.WillKillTarget(creep, damage, damageType, castPoint)
				and not Fu.CanKillTarget(creep, bot:GetAttackDamage() * 1.38, DAMAGE_TYPE_PHYSICAL)
			then
				return BOT_ACTION_DESIRE_HIGH, creep, "D带线"
			end
		end
	end
	if bot:GetActiveMode() == BOT_MODE_ROSHAN and manaCost < 100 then
		if
			Fu.IsRoshan(botTarget)
			and not Fu.IsDisabled(botTarget)
			and not botTarget:IsDisarmed()
			and Fu.IsInRange(botTarget, bot, castRange)
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget, "D肉山"
		end
	end
	if
		(#nearbyEnemies > 0 or bot:WasRecentlyDamagedByAnyHero(3.0))
		and (bot:GetActiveMode() ~= BOT_MODE_RETREAT or #nearbyAllies >= 2)
		and #enemiesInRange >= 1
		and botLevel >= 15
	then
		for _, enemyHero in pairs(enemiesInRange) do
			if
				Fu.IsValid(enemyHero)
				and Fu.IsInRange(bot, enemyHero, 600)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
				and not Fu.IsDisabled(enemyHero)
			then
				return BOT_ACTION_DESIRE_HIGH, enemyHero, "D通用"
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderFireShield()
	if not fireShieldAbility:IsTrained() or not fireShieldAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local searchRadius = 600
	local castRange = fireShieldAbility:GetCastRange() + aetherRange
	local castPoint = fireShieldAbility:GetCastPoint()
	local manaCost = fireShieldAbility:GetManaCost()
	for _, enemyHero in pairs(nearbyEnemies) do
		if Fu.IsValidHero(enemyHero) and Fu.CanCastOnNonMagicImmune(enemyHero) then
			local attackTarget = enemyHero:GetAttackTarget()
			if
				attackTarget ~= nil
				and Fu.IsInRange(bot, attackTarget, castRange)
				and not attackTarget:HasModifier("modifier_fountain_glyph")
				and not attackTarget:HasModifier("modifier_ogre_magi_smash_buff")
			then
				if attackTarget:IsTower() and enemyHero:IsBot() then
					return BOT_ACTION_DESIRE_HIGH, attackTarget, "AS-守塔"
				end
				if attackTarget:IsHero() and not attackTarget:IsIllusion() then
					return BOT_ACTION_DESIRE_HIGH, attackTarget, "AS-保护队友:" .. Fu.Chat.GetNormName(attackTarget)
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
return X
