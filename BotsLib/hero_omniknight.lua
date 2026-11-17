-- Omniknight: skill build, item build, and ability use for this hero.
local X = {}
local bot = GetBot()
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local AbilityContext = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local Minion = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local sTalentList = Fu.Skill.GetTalentList(bot)
local sAbilityList = Fu.Skill.GetAbilityList(bot)
local sRole = Fu.Item.GetRoleItemsBuyList(bot)
local tTalentTreeList = {
	{ ["t25"] = { 10, 0 }, ["t20"] = { 10, 0 }, ["t15"] = { 0, 10 }, ["t10"] = { 10, 0 } },
	{ ["t25"] = { 10, 0 }, ["t20"] = { 0, 10 }, ["t15"] = { 10, 0 }, ["t10"] = { 10, 0 } },
	{ ["t25"] = { 0, 10 }, ["t20"] = { 0, 10 }, ["t15"] = { 10, 0 }, ["t10"] = { 0, 10 } },
}
local tAllAbilityBuildList = { { 3, 1, 1, 2, 1, 6, 1, 2, 2, 2, 6, 3, 3, 3, 6 }, { 3, 1, 1, 2, 1, 6, 1, 2, 2, 2, 6, 3, 3, 3, 6 } }
local nAbilityBuildList = tAllAbilityBuildList[1]
if sRole == "pos_1" then
	nAbilityBuildList = tAllAbilityBuildList[1]
end
if sRole == "pos_2" then
	nAbilityBuildList = tAllAbilityBuildList[1]
end
if sRole == "pos_3" then
	nAbilityBuildList = tAllAbilityBuildList[1]
end
if sRole == "pos_4" then
	nAbilityBuildList = tAllAbilityBuildList[2]
end
if sRole == "pos_5" then
	nAbilityBuildList = tAllAbilityBuildList[2]
end
local nTalentBuildList
if sRole == "pos_3" then
	nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList[2])
elseif sRole == "pos_4" or sRole == "pos_5" then
	nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList[3])
else
	nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList[1])
end
local sUtility = "item_team_aura"
local sRoleItemsBuyList = {}
sRoleItemsBuyList["pos_3"] = {
	"item_tango",
	"item_double_branches",
	"item_quelling_blade",
	"item_gauntlets",
	"item_circlet",
	"item_magic_wand",
	"item_bracer",
	"item_phase_boots",
	"item_soul_ring",
	"item_echo_sabre",
	"item_aghanims_shard",
	"item_consecrated_wraps",
	"item_harpoon",
	"item_blink",
	sUtility,
	"item_black_king_bar",
	"item_shivas_guard",
	"item_assault",
	"item_overwhelming_blink",
	"item_moon_shard",
	"item_ultimate_scepter_2",
}
sRoleItemsBuyList["pos_1"] = sRoleItemsBuyList["pos_3"]
sRoleItemsBuyList["pos_2"] = sRoleItemsBuyList["pos_3"]
sRoleItemsBuyList["pos_4"] = {
	-- Arcane Boots (priest outfit) into Guardian Greaves, plus Holy Locket, instead of a second pair of
	-- boots (Tranquil -> Boots of Bearing): Arcane 47%, Greaves 46%, Locket 22% of his matches (Dotabuff,
	-- last patch); Tranquil and Bearing are not in his top 25.
	"item_priest_outfit",
	"item_holy_locket",
	"item_solar_crest",
	"item_glimmer_cape",
	"item_blink",
	"item_guardian_greaves",
	"item_aghanims_shard",
	"item_consecrated_wraps",
	"item_sheepstick",
	"item_ultimate_scepter",
	"item_shivas_guard",
	"item_moon_shard",
	"item_ultimate_scepter_2",
}
sRoleItemsBuyList["pos_5"] = {
	"item_blood_grenade",
	-- Arcane Boots (crystal_maiden_outfit) into Guardian Greaves and a Blink Dagger instead of Tranquil ->
	-- Boots of Bearing (Drum): Arcane 47%, Greaves 46%, Blink 55% of his matches (Dotabuff, last patch).
	"item_crystal_maiden_outfit",
	"item_glimmer_cape",
	"item_blink",
	"item_consecrated_wraps",
	"item_guardian_greaves",
	"item_pipe",
	"item_ultimate_scepter",
	"item_cyclone",
	"item_shivas_guard",
	"item_sheepstick",
	"item_moon_shard",
	"item_ultimate_scepter_2",
}
X["sBuyList"] = sRoleItemsBuyList[sRole]
X["sSellList"] = { "item_black_king_bar", "item_quelling_blade" }
if Fu.Role.IsPvNMode() or Fu.Role.IsAllShadow() then
	X["sBuyList"], X["sSellList"] = { "PvN_tank" }, { "item_power_treads", "item_quelling_blade" }
end
nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"] = Fu.SetUserHeroInit(nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"])
X["sSkillList"] = Fu.Skill.GetSkillList(sAbilityList, nAbilityBuildList, sTalentList, nTalentBuildList)
X["bDeafaultAbility"] = false
X["bDeafaultItem"] = false
function X.MinionThink(minionUnit)
	Minion.MinionThink(minionUnit)
end
local purificationAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[1]), "sAbilityList[1]", "omniknight")
local martyrAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[2]), "sAbilityList[2]", "omniknight")
local hammerOfPurityAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[3]), "sAbilityList[3]", "omniknight")
local guardianAngelAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[6]), "sAbilityList[6]", "omniknight")
local slot4Ability = SafeAbility(bot:GetAbilityByName(sAbilityList[4]), "sAbilityList[4]", "omniknight")
local talent7 = SafeAbility(bot:GetAbilityByName(sTalentList[7]), "sTalentList[7]", "omniknight")
local purificationDesire, purificationTarget
local martyrDesire, martyrTarget
local hammerOfPurityDesire, hammerOfPurityTarget
local guardianAngelDesire
local spareDesire, spareTarget
local aetherRange = 0
local botLevel, mpRatio, hpRatio, nearbyEnemies, nearbyAllies
function X.SkillsComplement()
	purificationAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[1]), "sAbilityList[1]", "omniknight")
	martyrAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[2]), "sAbilityList[2]", "omniknight")
	hammerOfPurityAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[3]), "sAbilityList[3]", "omniknight")
	guardianAngelAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[6]), "sAbilityList[6]", "omniknight")
	if hammerOfPurityAbility ~= nil and hammerOfPurityAbility:IsTrained() then
		local shouldAutoCast = false
		local nearbyEnemyHeroes = bot:GetNearbyHeroes(900, true, BOT_MODE_NONE)
		if nearbyEnemyHeroes ~= nil and #nearbyEnemyHeroes >= 1 then
			shouldAutoCast = true
		elseif Fu.IsFarming(bot) or Fu.IsPushing(bot) or Fu.IsDefending(bot) then
			if Fu.GetMP(bot) > 0.4 then
				shouldAutoCast = true
			end
		elseif Fu.IsDoingRoshan(bot) or Fu.IsDoingTormentor(bot) then
			shouldAutoCast = true
		end
		if shouldAutoCast and not hammerOfPurityAbility:GetAutoCastState() then
			hammerOfPurityAbility:ToggleAutoCast()
		elseif not shouldAutoCast and hammerOfPurityAbility:GetAutoCastState() then
			hammerOfPurityAbility:ToggleAutoCast()
		end
	end
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
	nearbyAllies = context.allies
	guardianAngelDesire = X.ConsiderR()
	if guardianAngelDesire > 0 then
		Fu.SetQueuePtToINT(bot, true)
		bot:ActionQueue_UseAbility(guardianAngelAbility)
		return
	end
	purificationDesire, purificationTarget = X.ConsiderQ()
	if purificationDesire > 0 then
		Fu.SetQueuePtToINT(bot, true)
		bot:ActionQueue_UseAbilityOnEntity(purificationAbility, purificationTarget)
		return
	end
	martyrDesire, martyrTarget = X.ConsiderW()
	if martyrDesire > 0 then
		Fu.SetQueuePtToINT(bot, true)
		bot:ActionQueue_UseAbilityOnEntity(martyrAbility, martyrTarget)
		return
	end
	hammerOfPurityDesire, hammerOfPurityTarget = X.ConsiderE()
	if hammerOfPurityDesire > 0 then
		bot:Action_UseAbilityOnEntity(hammerOfPurityAbility, hammerOfPurityTarget)
		return
	end
end
function X.ConsiderQ()
	if not purificationAbility:IsFullyCastable() then
		return 0
	end
	local abilityLevel = purificationAbility:GetLevel()
	local castRange = purificationAbility:GetCastRange() + aetherRange
	local radius = purificationAbility:GetSpecialValueInt("radius")
	local castPoint = purificationAbility:GetCastPoint()
	local manaCost = purificationAbility:GetManaCost()
	local heal = purificationAbility:GetSpecialValueInt("heal")
	if talent7:IsTrained() then
		heal = heal + talent7:GetSpecialValueInt("value")
	end
	local damageType = DAMAGE_TYPE_PURE
	local enemiesInRange = Fu.GetAroundEnemyHeroList(castRange + radius)
	local enemiesNearby = Fu.GetAroundEnemyHeroList(castRange + 200 + radius)
	local allyHeroes = Fu.GetNearbyHeroes(bot, castRange + 350, false, BOT_MODE_NONE)
	local allyCreeps = bot:GetNearbyCreeps(castRange + 200, false)
	local target = nil
	local reason = nil
	if Fu.GetHP(bot) < 0.3 and bot:WasRecentlyDamagedByAnyHero(2.0) then
		local incomingDamage = Fu.GetAttackProjectileDamageByRange(bot, 1200) * 2
		if
			bot:GetHealth() < bot:GetActualIncomingDamage(incomingDamage, DAMAGE_TYPE_PHYSICAL) + 100
			or Fu.IsStunProjectileIncoming(bot, 1200)
		then
			target = bot
			reason = "Q-self-save"
			return BOT_ACTION_DESIRE_HIGH, target, reason
		end
	end
	for _, enemyHero in pairs(enemiesNearby) do
		if
			Fu.IsValid(enemyHero)
			and Fu.CanCastOnMagicImmune(enemyHero)
			and Fu.CanKillTarget(enemyHero, heal, damageType)
			and not Fu.IsSuspiciousIllusion(enemyHero)
			and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
			and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
			and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
			and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
		then
			local bestUnit = nil
			local lowestHp = 9
			for _, allyHero in pairs(allyHeroes) do
				if Fu.IsInRange(allyHero, enemyHero, radius) and Fu.GetHP(allyHero) < lowestHp then
					bestUnit = allyHero
					lowestHp = Fu.GetHP(allyHero)
				end
			end
			if bestUnit ~= nil then
				target = bestUnit
				reason = "Q-击杀1" .. Fu.Chat.GetNormName(enemyHero)
				return BOT_ACTION_DESIRE_HIGH, target, reason
			end
			for _, allyCreep in pairs(allyCreeps) do
				if Fu.IsInRange(allyCreep, enemyHero, radius) and Fu.GetHP(allyCreep) < lowestHp then
					bestUnit = allyCreep
					lowestHp = Fu.GetHP(allyCreep)
				end
			end
			if bestUnit ~= nil then
				target = bestUnit
				reason = "Q-击杀2" .. Fu.Chat.GetNormName(enemyHero)
				return BOT_ACTION_DESIRE_HIGH, target, reason
			end
		end
	end
	if Fu.IsGoingOnSomeone(bot) or Fu.IsRetreating(bot) then
		local bestUnit = nil
		local bestCount = 0
		for _, allyHero in pairs(nearbyAllies) do
			if Fu.IsInRange(bot, allyHero, castRange) and allyHero:GetMaxHealth() - allyHero:GetHealth() > heal + 50 then
				local enemiesNearAlly = Fu.GetNearbyHeroes(allyHero, radius, true, BOT_MODE_NONE)
				if #enemiesNearAlly > bestCount then
					bestCount = #enemiesNearAlly
					bestUnit = allyHero
				end
			end
		end
		if bestUnit ~= nil then
			local enemiesNearBot = Fu.GetNearbyHeroes(bot, radius, true, BOT_MODE_NONE)
			for _, enemyHero in pairs(enemiesNearBot) do
				if Fu.CanCastOnMagicImmune(enemyHero) then
					target = bestUnit
					reason = "Q-AOE:" .. Fu.Chat.GetNormName(bestUnit)
					return BOT_ACTION_DESIRE_HIGH, target, reason
				end
			end
		end
		if
			Fu.IsValidHero(botTarget)
			and Fu.IsInRange(bot, botTarget, radius)
			and Fu.CanCastOnMagicImmune(botTarget)
			and bot:GetMaxHealth() - bot:GetHealth() > heal
		then
			target = bot
			reason = "Q-攻击时奶自己" .. Fu.Chat.GetNormName(target)
			return BOT_ACTION_DESIRE_HIGH, target, reason
		end
	end
	for i = 1, #GetTeamPlayers(GetTeam()) do
		local allyHero = GetTeamMember(i)
		if
			allyHero ~= nil
			and allyHero:IsAlive()
			and not allyHero:HasModifier("modifier_fountain_aura")
			and Fu.IsInRange(bot, allyHero, castRange)
			and (Fu.GetHP(allyHero) < 0.15 or Fu.GetHP(allyHero) < 0.3 and allyHero:WasRecentlyDamagedByAnyHero(3.0))
		then
			target = allyHero
			reason = "Q-奶队友:" .. Fu.Chat.GetNormName(target)
			return BOT_ACTION_DESIRE_HIGH, target, reason
		end
	end
	if Fu.IsLaning(bot) then
		for _, allyHero in pairs(allyHeroes) do
			if allyHero:GetMaxHealth() - allyHero:GetHealth() > heal * 1.2 then
				local enemiesNearAlly = Fu.GetNearbyHeroes(allyHero, radius - 20, true, BOT_MODE_NONE)
				if Fu.IsValidHero(enemiesNearAlly[1]) and Fu.CanCastOnMagicImmune(enemiesNearAlly[1]) then
					target = allyHero
					reason = "Q-对线治疗" .. Fu.Chat.GetNormName(allyHero)
					return BOT_ACTION_DESIRE_HIGH, target, reason
				end
			end
		end
	end
	local enemyLaneCreeps = bot:GetNearbyLaneCreeps(1600, true)
	if (Fu.IsPushing(bot) or Fu.IsDefending(bot) or Fu.IsFarming(bot)) and Fu.IsAllowedToSpam(bot, manaCost) and #nearbyAllies <= 3 and #enemyLaneCreeps >= 3 then
		local creepsInRadius = bot:GetNearbyLaneCreeps(radius, true)
		if (#creepsInRadius >= 4 or #creepsInRadius >= 3 and mpRatio > 0.82) and not creepsInRadius[1]:HasModifier("modifier_fountain_glyph") then
			target = bot
			reason = "Q-带线AOE" .. #creepsInRadius
			return BOT_ACTION_DESIRE_HIGH, target, reason
		end
		if enemyLaneCreeps[1] ~= nil and not enemyLaneCreeps[1]:HasModifier("modifier_fountain_glyph") then
			local bestUnit = nil
			local bestCount = 0
			for _, allyCreep in pairs(allyCreeps) do
				-- Purification hits enemies within "radius" of the healed unit. The count used to ignore
				-- the candidate creep, so every ally creep scored the same.
				local killableCount = 0
				for i = 1, #enemyLaneCreeps do
					if
						Fu.IsValid(allyCreep)
						and Fu.IsValid(enemyLaneCreeps[i])
						and GetUnitToUnitDistance(enemyLaneCreeps[i], allyCreep) <= radius
						and enemyLaneCreeps[i]:GetHealth() < heal
					then
						killableCount = killableCount + 1
					end
				end
				if killableCount > bestCount then
					bestUnit = allyCreep
					bestCount = killableCount
				end
			end
			if bestUnit ~= nil and bestCount >= 3 then
				target = bestUnit
				reason = "Q-清兵AOE" .. bestCount
				return BOT_ACTION_DESIRE_HIGH, target, reason
			end
		end
	end
	if Fu.IsFarming(bot) and Fu.IsAllowedToSpam(bot, manaCost) and (bot:GetMaxHealth() - bot:GetHealth() > heal or mpRatio > 0.85) then
		local neutralCreeps = bot:GetNearbyNeutralCreeps(radius - 20)
		if #neutralCreeps >= 3 or #neutralCreeps >= 2 and mpRatio > 0.88 then
			target = bot
			reason = "Q-打野AOE" .. #neutralCreeps
			return BOT_ACTION_DESIRE_HIGH, target, reason
		end
	end
	if Fu.IsDoingRoshan(bot) and bot:GetMana() > 660 then
		for _, allyHero in pairs(nearbyAllies) do
			if allyHero:GetMaxHealth() - allyHero:GetHealth() > heal then
				local allyTarget = allyHero:GetAttackTarget()
				if Fu.IsRoshan(allyTarget) and Fu.IsInRange(allyHero, allyTarget, radius) then
					target = allyHero
					reason = "Q-肉山" .. Fu.Chat.GetNormName(target)
					return BOT_ACTION_DESIRE_HIGH, target, reason
				end
			end
		end
	end
	if Fu.IsDoingTormentor(bot) and bot:GetMana() > 660 then
		for _, allyHero in pairs(nearbyAllies) do
			if allyHero:GetMaxHealth() - allyHero:GetHealth() > heal then
				local allyTarget = allyHero:GetAttackTarget()
				if Fu.IsTormentor(allyTarget) and Fu.IsInRange(allyHero, allyTarget, radius) then
					target = allyHero
					reason = "Q-折磨者" .. Fu.Chat.GetNormName(target)
					return BOT_ACTION_DESIRE_HIGH, target, reason
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderW()
	if not martyrAbility:IsFullyCastable() then
		return 0
	end
	local abilityLevel = martyrAbility:GetLevel()
	local castRange = martyrAbility:GetCastRange() + aetherRange
	local radius = 600
	local castPoint = martyrAbility:GetCastPoint()
	local manaCost = martyrAbility:GetManaCost()
	local damage = 0
	local damageType = DAMAGE_TYPE_MAGICAL
	local duration = martyrAbility:GetSpecialValueInt("duration")
	-- datafeed: the Martyr regen key is "base_hpregen" ("hp_regen" read 0, so the missing-HP checks always passed)
	local totalRegen = martyrAbility:GetSpecialValueInt("base_hpregen") * duration
	local target = nil
	local reason = nil
	for _, allyHero in pairs(nearbyAllies) do
		if
			Fu.IsValidHero(allyHero)
			and Fu.IsInRange(bot, allyHero, castRange + 300)
			and not allyHero:HasModifier("modifier_omniknight_repel")
			and not allyHero:IsMagicImmune()
			and not allyHero:IsInvulnerable()
			and not allyHero:IsIllusion()
		then
			if
				not allyHero:IsBot()
				and allyHero:GetLevel() >= 6
				and allyHero:GetAttackTarget() ~= nil
				and allyHero:GetAttackTarget():IsHero()
				and allyHero:GetMaxHealth() - allyHero:GetHealth() >= totalRegen * 0.8
			then
				target = allyHero
				reason = "W-加状态抗性:" .. Fu.Chat.GetNormName(target)
				return BOT_ACTION_DESIRE_HIGH, target, reason
			end
			if Fu.IsDisabled(allyHero) then
				target = allyHero
				reason = "W-解状态:" .. Fu.Chat.GetNormName(target)
				return BOT_ACTION_DESIRE_HIGH, target, reason
			end
			if
				Fu.IsRetreating(allyHero)
				and not allyHero:HasModifier("modifier_fountain_aura")
				and allyHero:GetMaxHealth() - allyHero:GetHealth() >= totalRegen * 0.7
				and allyHero:WasRecentlyDamagedByAnyHero(3.0)
			then
				target = allyHero
				reason = "W-加撤退中的队友:" .. Fu.Chat.GetNormName(target)
				return BOT_ACTION_DESIRE_HIGH, target, reason
			end
			if Fu.IsGoingOnSomeone(allyHero) and allyHero:GetPrimaryAttribute() == ATTRIBUTE_STRENGTH then
				local allyTarget = Fu.GetProperTarget(allyHero)
				if
					Fu.IsValidHero(allyTarget)
					and allyHero:IsFacingLocation(allyTarget:GetLocation(), 20)
					and Fu.IsInRange(allyHero, allyTarget, allyHero:GetAttackRange() + 60)
				then
					target = allyHero
					reason = "W-进攻辅助力量队友:" .. Fu.Chat.GetNormName(target)
					return BOT_ACTION_DESIRE_HIGH, target, reason
				end
			end
			if
				Fu.GetHP(allyHero) < 0.5
				and (allyHero:WasRecentlyDamagedByAnyHero(5.0) or Fu.GetHP(allyHero) < 0.25)
				and not allyHero:HasModifier("modifier_fountain_aura")
			then
				target = allyHero
				reason = "W-为队友回血:" .. Fu.Chat.GetNormName(target)
				return BOT_ACTION_DESIRE_HIGH, target, reason
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderE()
	if not hammerOfPurityAbility:IsFullyCastable() then
		return 0
	end
	local castRange = hammerOfPurityAbility:GetCastRange()
	local castPoint = hammerOfPurityAbility:GetCastPoint()
	local manaCost = hammerOfPurityAbility:GetManaCost()
	local abilityLevel = hammerOfPurityAbility:GetLevel()
	local damage = 25 * abilityLevel + 25 + bot:GetAttackDamage() * (0.5 + abilityLevel * 0.1)
	local damageType = DAMAGE_TYPE_PURE
	local allyHeroes = Fu.GetNearbyHeroes(bot, 1200, false, BOT_MODE_NONE)
	local enemyHeroesFar = Fu.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE)
	local enemiesInRange = Fu.GetNearbyHeroes(bot, castRange + 43, true, BOT_MODE_NONE)
	local enemiesNearRange = Fu.GetNearbyHeroes(bot, castRange + 330, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(enemiesNearRange) do
		if
			Fu.IsValid(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and Fu.CanCastOnTargetAdvanced(enemyHero)
			and not Fu.IsSuspiciousIllusion(enemyHero)
			and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
			and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
			and not enemyHero:HasModifier("modifier_item_blade_mail_reflect")
		then
			if GetUnitToUnitDistance(bot, enemyHero) <= castRange + 80 and Fu.CanKillTarget(enemyHero, damage * 1.18, damageType) then
				return BOT_ACTION_DESIRE_HIGH, enemyHero
			end
		end
	end
	if bot:GetActiveMode() == BOT_MODE_LANING or botLevel <= 5 then
		for _, enemyHero in pairs(enemiesInRange) do
			if
				Fu.IsValid(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and not enemyHero:HasModifier("modifier_item_blade_mail_reflect")
				and Fu.GetHP(enemyHero) < 0.6
			then
				return BOT_ACTION_DESIRE_HIGH, enemyHero
			end
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		local target = Fu.GetProperTarget(bot)
		if
			Fu.IsValidHero(target)
			and Fu.CanCastOnNonMagicImmune(target)
			and Fu.CanCastOnTargetAdvanced(target)
			and Fu.IsInRange(target, bot, castRange + 80)
			and not Fu.IsSuspiciousIllusion(target)
			and not target:HasModifier("modifier_abaddon_borrowed_time")
			and not target:HasModifier("modifier_dazzle_shallow_grave")
			and not target:HasModifier("modifier_item_blade_mail_reflect")
		then
			if abilityLevel >= 3 or mpRatio > 0.68 or Fu.GetHP(target) < 0.4 or hpRatio < 0.25 then
				return BOT_ACTION_DESIRE_HIGH, target
			end
		end
	end
	if Fu.IsRetreating(bot) then
		for _, enemyHero in pairs(enemiesInRange) do
			if
				Fu.IsValid(enemyHero)
				and (bot:WasRecentlyDamagedByHero(enemyHero, 5.0) or mpRatio > 0.8 or GetUnitToUnitDistance(bot, enemyHero) <= 400)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
				and not Fu.IsDisabled(enemyHero)
				and not enemyHero:HasModifier("modifier_item_blade_mail_reflect")
			then
				return BOT_ACTION_DESIRE_HIGH, enemyHero
			end
		end
	end
	if Fu.IsFarming(bot) and abilityLevel >= 3 and (bot:GetAttackDamage() < 200 or mpRatio > 0.88) and mpRatio > 0.71 and #nearbyEnemies == 0 then
		local neutralCreeps = bot:GetNearbyNeutralCreeps(castRange + 100)
		local attackTarget = bot:GetAttackTarget()
		if
			Fu.IsValid(attackTarget)
			and bot:IsFacingLocation(attackTarget:GetLocation(), 46)
			and (#neutralCreeps >= 2 or GetUnitToUnitDistance(attackTarget, bot) <= 400)
			and not Fu.IsRoshan(attackTarget)
			and not Fu.IsOtherAllysTarget(attackTarget)
			and not Fu.CanKillTarget(attackTarget, bot:GetAttackDamage() * 1.68, DAMAGE_TYPE_PHYSICAL)
			and not Fu.CanKillTarget(attackTarget, damage, damageType)
		then
			return BOT_ACTION_DESIRE_HIGH, attackTarget
		end
	end
	if bot:GetActiveMode() == BOT_MODE_ROSHAN and bot:GetMana() >= 600 then
		local target = bot:GetAttackTarget()
		if Fu.IsRoshan(target) and Fu.IsInRange(target, bot, castRange) then
			return BOT_ACTION_DESIRE_HIGH, target
		end
	end
	if Fu.IsDoingTormentor(bot) and bot:GetMana() >= 600 then
		local target = bot:GetAttackTarget()
		if Fu.IsTormentor(target) and Fu.IsInRange(target, bot, castRange) then
			return BOT_ACTION_DESIRE_HIGH, target
		end
	end
	if bot:WasRecentlyDamagedByAnyHero(3.0) and bot:GetActiveMode() ~= BOT_MODE_RETREAT and #enemiesInRange >= 1 and botLevel >= 8 then
		for _, enemyHero in pairs(enemiesInRange) do
			if
				Fu.IsValid(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
				and enemyHero:IsFacingLocation(bot:GetLocation(), 45)
				and not enemyHero:HasModifier("modifier_item_blade_mail_reflect")
			then
				return BOT_ACTION_DESIRE_HIGH, enemyHero
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderR()
	if not guardianAngelAbility:IsFullyCastable() then
		return 0
	end
	local radius = guardianAngelAbility:GetSpecialValueInt("radius")
	for i = 1, #GetTeamPlayers(GetTeam()) do
		local allyHero = GetTeamMember(i)
		if
			Fu.IsValidHero(allyHero)
			and Fu.CanBeAttacked(allyHero)
			and (bot:HasScepter() or Fu.IsInRange(bot, allyHero, radius))
			and not allyHero:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			if Fu.IsInTeamFight(allyHero, 1600) then
				local alliesNearAlly = Fu.GetAlliesNearLoc(allyHero:GetLocation(), radius)
				local enemiesNearAlly = Fu.GetEnemiesNearLoc(allyHero:GetLocation(), 1200)
				if #enemiesNearAlly >= 2 and (#enemiesNearAlly >= #alliesNearAlly or #enemiesNearAlly >= 3) then
					local threatenedCount = 0
					for _, ally in pairs(alliesNearAlly) do
						if
							Fu.IsValidHero(ally)
							and Fu.CanBeAttacked(ally)
							and ally:WasRecentlyDamagedByAnyHero(4.0)
							and not ally:HasModifier("modifier_necrolyte_reapers_scythe")
						then
							threatenedCount = threatenedCount + 1
							if Fu.GetHP(ally) < 0.4 then
								threatenedCount = threatenedCount + 1
							end
						end
					end
					if threatenedCount >= 2 then
						return BOT_ACTION_DESIRE_HIGH
					end
				end
			end
		end
	end
	for i = 1, #GetTeamPlayers(GetTeam()) do
		local allyHero = GetTeamMember(i)
		if
			Fu.IsValidHero(allyHero)
			and Fu.CanBeAttacked(allyHero)
			and (bot:HasScepter() or Fu.IsInRange(bot, allyHero, radius))
			and not allyHero:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			if Fu.IsRetreating(allyHero) and not Fu.IsRealInvisible(allyHero) and allyHero:WasRecentlyDamagedByAnyHero(2.0) then
				local attackingAllies = Fu.GetNearbyHeroes(allyHero, radius, false, BOT_MODE_ATTACK)
				local retreatingAllies = Fu.GetNearbyHeroes(allyHero, radius, false, BOT_MODE_RETREAT)
				if #attackingAllies >= 2 or #attackingAllies >= 1 and #retreatingAllies >= 2 then
					return BOT_ACTION_DESIRE_HIGH
				end
				-- One ally running alone: the counts above are of his own team, so a lone retreating
				-- hero was never saved. Under 30% HP with 2+ enemy heroes within 900 of him, Guardian
				-- Angel (immunity from physical damage, datafeed) covers his escape.
				if Fu.GetHP(allyHero) < 0.3 and #(Fu.GetEnemiesNearLoc(allyHero:GetLocation(), 900) or {}) >= 2 then
					if DotaTime() >= (bot._omniGaLogAt or -999) then
						bot._omniGaLogAt = DotaTime() + 3
						pcall(print, string.format(
							"[OHA-OMNI] t=%.0f angel-save ally=%s hp=%.2f",
							DotaTime(),
							(string.gsub(allyHero:GetUnitName(), "npc_dota_hero_", "")),
							Fu.GetHP(allyHero)
						))
					end
					return BOT_ACTION_DESIRE_HIGH
				end
			end
		end
	end
	if Fu.IsGoingOnSomeone(bot) and hpRatio < (#nearbyEnemies >= 3 and 0.65 or 0.45) and bot:WasRecentlyDamagedByAnyHero(2.0) then
		if
			Fu.IsValidHero(botTarget)
			and Fu.IsInRange(bot, botTarget, 800)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not botTarget:IsDisarmed()
			and botTarget:IsFacingLocation(bot:GetLocation(), 60)
			and not Fu.IsChasingTarget(bot, botTarget)
		then
			if hpRatio < 0.55 then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
return X
