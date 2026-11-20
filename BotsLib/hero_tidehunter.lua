-- Tidehunter: skill build, item build, and ability use for this hero.
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
local tTalentTreeList = { ["t25"] = { 0, 10 }, ["t20"] = { 10, 0 }, ["t15"] = { 0, 10 }, ["t10"] = { 0, 10 } }
local tAllAbilityBuildList = { { 3, 1, 2, 3, 3, 6, 3, 2, 2, 2, 6, 1, 1, 1, 6 } }
local nAbilityBuildList = Fu.Skill.GetRandomBuild(tAllAbilityBuildList)
local nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList)
local sUtility = RandomInt(1, 2) == 1 and "item_lotus_orb" or "item_heavens_halberd"
local sRoleItemsBuyList = {}
-- Stratz 7.41f, week of 9 Nov 2026: pos 3, 196,091 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_3"] = {
	"item_tango",
	"item_gauntlets",
	"item_double_branches",
	"item_quelling_blade",
	"item_circlet",
	"item_bracer",
	"item_magic_wand",
	"item_soul_ring",
	"item_phase_boots",
	"item_blink",
	"item_aghanims_shard",
	"item_ultimate_scepter",
	sUtility,
	"item_refresher",
	"item_overwhelming_blink",
	"item_ultimate_scepter_2",
	"item_consecrated_wraps",
	"item_pipe",
	"item_moon_shard",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 1, 2,043 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_1"] = {
	"item_tango",
	"item_quelling_blade",
	"item_double_branches",
	"item_gauntlets",
	"item_circlet",
	"item_bracer",
	"item_magic_wand",
	"item_soul_ring",
	"item_phase_boots",
	"item_vladmir",
	"item_desolator",
	"item_blink",
	"item_lesser_crit",
	"item_aghanims_shard",
	"item_ultimate_scepter",
	"item_greater_crit", -- was "item_great_scepter", not an item in items.txt; Daedalus fills the damage slot (pos_2 has MKB here)
	"item_travel_boots",
	"item_overwhelming_blink",
	"item_ultimate_scepter_2",
	"item_shivas_guard",
	"item_moon_shard",
	"item_travel_boots_2",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 2, 4,844 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_2"] = {
	"item_tango",
	"item_double_branches",
	"item_quelling_blade",
	"item_gauntlets",
	"item_circlet",
	"item_bracer",
	"item_magic_wand",
	"item_soul_ring",
	"item_phase_boots",
	"item_mage_slayer",
	"item_blink",
	"item_aghanims_shard",
	"item_ultimate_scepter",
	"item_shivas_guard",
	"item_overwhelming_blink",
	"item_ultimate_scepter_2",
	"item_vladmir",
	"item_black_king_bar",
	"item_moon_shard",
}
-- No Boots of Travel: this build's Guardian Greaves / Boots of Bearing are its one pair of boots.
-- Stratz 7.41f, week of 9 Nov 2026: pos 4, 8,417 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_4"] = {
	"item_tango",
	"item_double_branches",
	"item_gauntlets",
	"item_quelling_blade",
	"item_circlet",
	"item_bracer",
	"item_magic_wand",
	"item_phase_boots",
	"item_blink",
	"item_aghanims_shard",
	"item_ultimate_scepter",
	"item_shivas_guard",
	"item_ultimate_scepter_2",
	"item_pipe",
	"item_blade_mail",
	"item_heart",
	"item_overwhelming_blink",
	"item_moon_shard",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 5, 4,071 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_5"] = {
	"item_tango",
	"item_blood_grenade",
	"item_branches",
	"item_magic_stick",
	"item_gauntlets",
	"item_bracer",
	"item_magic_wand",
	"item_arcane_boots",
	"item_blink",
	"item_aghanims_shard",
	"item_ultimate_scepter",
	"item_refresher",
	"item_vladmir",
	"item_pipe",
	"item_ultimate_scepter_2",
	"item_heart",
	"item_moon_shard",
}
X["sBuyList"] = sRoleItemsBuyList[sRole]
X["sSellList"] = { "item_black_king_bar", "item_quelling_blade", "item_satanic", "item_vladmir" }
if Fu.Role.IsPvNMode() or Fu.Role.IsAllShadow() then
	X["sBuyList"], X["sSellList"] = { "PvN_tank" }, { "item_heavens_halberd", "item_quelling_blade" }
end
nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"] =
	Fu.SetUserHeroInit(nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"])
X["sSkillList"] = Fu.Skill.GetSkillList(sAbilityList, nAbilityBuildList, sTalentList, nTalentBuildList)
X["bDeafaultAbility"] = false
-- Cast when cornered (retreating into 3+ enemies with no way out), before running further.
X["LastStandSpells"] = { { name = "tidehunter_ravage", kind = "none" } }
X["bDeafaultItem"] = false
function X.MinionThink(hMinionUnit)
	Minion.MinionThink(hMinionUnit)
end
local gushAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[1]), "sAbilityList[1]", "tidehunter")
local krakenShellAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[2]), "sAbilityList[2]", "tidehunter")
krakenShellAbility =
	SafeAbility(bot:GetAbilityByName("tidehunter_kraken_shell"), "tidehunter_kraken_shell", "tidehunter")
local anchorSmashAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[3]), "sAbilityList[3]", "tidehunter")
local ravageAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[6]), "sAbilityList[6]", "tidehunter")
local deadInTheWaterAbility =
	SafeAbility(bot:GetAbilityByName("tidehunter_dead_in_the_water"), "tidehunter_dead_in_the_water", "tidehunter")
local talent3 = SafeAbility(bot:GetAbilityByName(sTalentList[3]), "sTalentList[3]", "tidehunter")
local gushDesire, gushTarget
local krakenShellDesire, krakenShellTarget
local anchorSmashDesire, anchorSmashTarget
local ravageDesire, ravageTarget
local deadInTheWaterDesire, deadInTheWaterTarget
local aetherRange = 0
local hpRatio
local botLevel, keepMana, mpRatio, nearbyEnemies, nearbyAllies
function X.SkillsComplement()
	if Fu.CanNotUseAbility(bot) or bot:IsInvisible() then
		return
	end
	hpRatio = Fu.GetHP(bot)
	local context = AbilityContext.Build(bot)
	keepMana = 400
	aetherRange = context.aetherRange
	botLevel = context.level
	mpRatio = context.mp
	botTarget = context.target
	nearbyEnemies = context.enemies
	nearbyAllies = context.allies
	ravageDesire = X.ConsiderR()
	if ravageDesire > 0 then
		Fu.SetQueuePtToINT(bot, true)
		bot:ActionQueue_UseAbility(ravageAbility)
		return
	end
	gushDesire, gushTarget = X.ConsiderQ()
	if gushDesire > 0 then
		Fu.SetQueuePtToINT(bot, true)
		if bot:HasScepter() and gushTarget ~= nil then
			bot:ActionQueue_UseAbilityOnLocation(gushAbility, gushTarget:GetLocation())
		else
			bot:ActionQueue_UseAbilityOnEntity(gushAbility, gushTarget)
		end
		return
	end
	anchorSmashDesire = X.ConsiderE()
	if anchorSmashDesire > 0 then
		bot:Action_UseAbility(anchorSmashAbility)
		return
	end
	deadInTheWaterDesire, deadInTheWaterTarget = X.ConsiderDeadInTheWater()
	if deadInTheWaterDesire > 0 then
		Fu.SetQueuePtToINT(bot, true)
		bot:ActionQueue_UseAbilityOnEntity(deadInTheWaterAbility, deadInTheWaterTarget)
		return
	end
	krakenShellDesire = X.ConsiderW()
	if krakenShellDesire > 0 then
		bot:Action_UseAbility(krakenShellAbility)
		return
	end
end
function X.ConsiderW()
	if not Fu.CanCastAbility(krakenShellAbility) then
		return BOT_ACTION_DESIRE_NONE
	end
	local allyHeroes = bot:GetNearbyHeroes(1200, false, BOT_MODE_NONE)
	local enemyHeroes = bot:GetNearbyHeroes(800, true, BOT_MODE_NONE)
	if Fu.IsRetreating(bot) and not Fu.IsRealInvisible(bot) and (hpRatio < 0.4 or #enemyHeroes > #allyHeroes + 2) then
		for _, enemy in pairs(enemyHeroes) do
			if
				Fu.IsValidHero(enemy)
				and bot:WasRecentlyDamagedByHero(enemy, 5.0)
				and Fu.CanCastOnNonMagicImmune(enemy)
				and not Fu.IsDisabled(enemy)
				and not enemy:IsDisarmed()
				and Fu.IsChasingTarget(enemy, bot)
			then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if Fu.IsRoshan(botTarget) and Fu.IsInRange(botTarget, bot, 600) and Fu.IsAttacking(bot) and hpRatio < 0.25 then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if
			Fu.IsTormentor(botTarget)
			and Fu.IsInRange(botTarget, bot, 600)
			and Fu.IsAttacking(bot)
			and hpRatio < 0.25
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderQ()
	if not gushAbility:IsFullyCastable() then
		return 0
	end
	local abilityLevel = gushAbility:GetLevel()
	local castRange = gushAbility:GetCastRange() + aetherRange
	if bot:HasScepter() then
		castRange = 1400
	end
	local radius = 600
	local castPoint = gushAbility:GetCastPoint()
	local manaCost = gushAbility:GetManaCost()
	local damage = gushAbility:GetSpecialValueInt("gush_damage")
	if talent3:IsTrained() then
		damage = damage + talent3:GetSpecialValueInt("value")
	end
	local damageType = DAMAGE_TYPE_MAGICAL
	local enemiesInRange = Fu.GetAroundEnemyHeroList(castRange)
	local enemiesInWideRange = Fu.GetAroundEnemyHeroList(castRange + 200)
	local target = nil
	local reason = nil
	for _, enemy in pairs(enemiesInWideRange) do
		if
			Fu.IsValid(enemy)
			and Fu.CanCastOnNonMagicImmune(enemy)
			and Fu.CanCastOnTargetAdvanced(enemy)
			and Fu.WillMagicKillTarget(bot, enemy, damage, castPoint)
		then
			target = enemy
			reason = "Q-击杀" .. Fu.Chat.GetNormName(target)
			return BOT_ACTION_DESIRE_HIGH, target, reason
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidHero(botTarget)
			and Fu.IsInRange(botTarget, bot, castRange)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.CanCastOnTargetAdvanced(botTarget)
		then
			target = botTarget
			reason = "Q-先手" .. Fu.Chat.GetNormName(target)
			return BOT_ACTION_DESIRE_HIGH, target, reason
		end
	end
	if Fu.IsRetreating(bot) and bot:WasRecentlyDamagedByAnyHero(5.0) then
		for _, enemy in pairs(enemiesInRange) do
			if
				Fu.IsValid(enemy)
				and Fu.CanCastOnNonMagicImmune(enemy)
				and Fu.CanCastOnTargetAdvanced(enemy)
				and not Fu.IsDisabled(enemy)
				and not enemy:IsDisarmed()
			then
				target = enemy
				reason = "Q-撤退" .. Fu.Chat.GetNormName(target)
				return BOT_ACTION_DESIRE_HIGH, target, reason
			end
		end
	end
	if bot:GetActiveMode() == BOT_MODE_LANING or botLevel <= 7 and #nearbyAllies <= 2 then
		local laneCreeps = bot:GetNearbyLaneCreeps(castRange + 200, true)
		local creepType = "ranged"
		for _, creep in pairs(laneCreeps) do
			if
				Fu.IsValid(creep)
				and not creep:HasModifier("modifier_fountain_glyph")
				and not Fu.IsOtherAllysTarget(creep)
				and Fu.IsKeyWordUnit(creepType, creep)
				and Fu.WillKillTarget(creep, damage, damageType, castPoint)
				and GetUnitToUnitDistance(creep, bot) > 280
			then
				target = creep
				reason = "Q-补远"
				return BOT_ACTION_DESIRE_HIGH, target, reason
			end
		end
		if abilityLevel >= 2 and (bot:GetMana() > keepMana or mpRatio > 0.9) then
			local creepType = "melee"
			for _, creep in pairs(laneCreeps) do
				if
					Fu.IsValid(creep)
					and not creep:HasModifier("modifier_fountain_glyph")
					and not Fu.IsOtherAllysTarget(creep)
					and Fu.IsKeyWordUnit(creepType, creep)
					and Fu.WillKillTarget(creep, damage, damageType, castPoint)
					and GetUnitToUnitDistance(creep, bot) > 350
				then
					target = creep
					reason = "Q-补近"
					return BOT_ACTION_DESIRE_HIGH, target, reason
				end
			end
		end
	end
	if
		(Fu.IsPushing(bot) or Fu.IsDefending(bot) or Fu.IsFarming(bot))
		and Fu.IsAllowedToSpam(bot, manaCost * 0.32)
		and #nearbyAllies <= 2
		and #nearbyEnemies == 0
	then
		local laneCreeps = bot:GetNearbyLaneCreeps(castRange, true)
		local creepType = "ranged"
		for _, creep in pairs(laneCreeps) do
			if
				Fu.IsValid(creep)
				and (Fu.IsKeyWordUnit(creepType, creep) or mpRatio > 0.8)
				and not creep:HasModifier("modifier_fountain_glyph")
				and Fu.WillKillTarget(creep, damage, damageType, castPoint)
				and not Fu.CanKillTarget(creep, bot:GetAttackDamage() * 1.38, DAMAGE_TYPE_PHYSICAL)
			then
				target = creep
				reason = "Q-带线"
				return BOT_ACTION_DESIRE_HIGH, target, reason
			end
		end
	end
	if Fu.IsFarming(bot) and DotaTime() > 6 * 60 and Fu.IsAllowedToSpam(bot, manaCost * 0.25) then
		local attackTarget = bot:GetAttackTarget()
		if
			Fu.IsValid(attackTarget)
			and attackTarget:GetTeam() == TEAM_NEUTRAL
			and Fu.IsInRange(bot, attackTarget, castRange)
			and not Fu.CanKillTarget(attackTarget, bot:GetAttackDamage() * 2.2, DAMAGE_TYPE_PHYSICAL)
		then
			target = attackTarget
			reason = "Q-打野"
			return BOT_ACTION_DESIRE_HIGH, target, reason
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if Fu.IsRoshan(botTarget) and Fu.IsInRange(botTarget, bot, castRange) then
			target = botTarget
			reason = "Q-肉山"
			return BOT_ACTION_DESIRE_HIGH, target, reason
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderE()
	if not anchorSmashAbility:IsFullyCastable() then
		return 0
	end
	local abilityLevel = anchorSmashAbility:GetLevel()
	-- datafeed: Anchor Smash has no "radius" value (it read 0, so E never found a target); its radius is
	-- Tidehunter's attack range + additional_range (225).
	local radius = bot:GetAttackRange() + anchorSmashAbility:GetSpecialValueInt("additional_range")
	local castRange = radius
	local castPoint = anchorSmashAbility:GetCastPoint()
	local manaCost = anchorSmashAbility:GetManaCost()
	local damage = anchorSmashAbility:GetSpecialValueInt("attack_damage") + bot:GetAttackDamage()
	local damageType = DAMAGE_TYPE_PHYSICAL
	local enemiesInRange = Fu.GetAroundEnemyHeroList(castRange - 40)
	local enemiesInWideRange = Fu.GetAroundEnemyHeroList(castRange + 200)
	local target = nil
	local reason = nil
	for _, enemy in pairs(enemiesInRange) do
		if Fu.IsValid(enemy) and Fu.CanCastOnMagicImmune(enemy) and Fu.CanKillTarget(enemy, damage, damageType) then
			target = enemy
			reason = "E-击杀" .. Fu.Chat.GetNormName(target)
			return BOT_ACTION_DESIRE_HIGH, reason
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidHero(botTarget)
			and Fu.IsInRange(botTarget, bot, radius - 50)
			and Fu.CanCastOnMagicImmune(botTarget)
		then
			target = botTarget
			reason = "E-攻击" .. Fu.Chat.GetNormName(target)
			return BOT_ACTION_DESIRE_HIGH, reason
		end
	end
	if Fu.IsInTeamFight(bot, 1000) then
		local heroCount = 0
		for _, enemy in pairs(enemiesInRange) do
			if Fu.IsValidHero(enemy) and Fu.CanCastOnMagicImmune(enemy) then
				heroCount = heroCount + 1
			end
		end
		if heroCount >= 2 then
			target = botTarget
			reason = "E-团战AOE" .. heroCount
			return BOT_ACTION_DESIRE_HIGH, reason
		end
	end
	if Fu.IsRetreating(bot) then
		for _, enemy in pairs(enemiesInRange) do
			if
				Fu.IsValid(enemy)
				and bot:WasRecentlyDamagedByHero(enemy, 5.0)
				and Fu.CanCastOnNonMagicImmune(enemy)
				and not Fu.IsDisabled(enemy)
				and not enemy:IsDisarmed()
			then
				target = enemy
				reason = "E-撤退" .. Fu.Chat.GetNormName(target)
				return BOT_ACTION_DESIRE_HIGH, reason
			end
		end
	end
	if Fu.IsLaning(bot) then
		local meleeKillCount = 0
		local rangedKillCount = 0
		local laneCreeps = bot:GetNearbyLaneCreeps(castRange, true)
		for _, creep in pairs(laneCreeps) do
			if Fu.IsValid(creep) and not creep:HasModifier("modifier_fountain_glyph") then
				local creepDamage = damage
				if Fu.IsItemAvailable("item_quelling_blade") then
					creepDamage = creepDamage + 12
				end
				if Fu.WillKillTarget(creep, creepDamage, damageType, castPoint) then
					if Fu.IsKeyWordUnit("ranged", creep) then
						rangedKillCount = rangedKillCount + 1
					end
					if Fu.IsKeyWordUnit("melee", creep) then
						meleeKillCount = meleeKillCount + 1
					end
				end
			end
		end
		if meleeKillCount + rangedKillCount >= 3 then
			return BOT_ACTION_DESIRE_HIGH, "E对线1"
		end
		if rangedKillCount >= 1 and meleeKillCount >= 1 then
			return BOT_ACTION_DESIRE_HIGH, "E对线2"
		end
		if #laneCreeps == 0 and #enemiesInRange >= 1 and mpRatio > 0.6 then
			return BOT_ACTION_DESIRE_HIGH, "E消耗"
		end
	end
	if
		(Fu.IsPushing(bot) or Fu.IsDefending(bot) or Fu.IsFarming(bot))
		and Fu.IsAllowedToSpam(bot, manaCost * 0.32)
		and #nearbyAllies <= 3
	then
		local laneCreeps = bot:GetNearbyLaneCreeps(castRange, true)
		if
			(#laneCreeps >= 3 or #laneCreeps >= 2 and mpRatio > 0.82)
			and not laneCreeps[1]:HasModifier("modifier_fountain_glyph")
		then
			target = laneCreeps[1] -- was the undefined global creep (nil); Anchor Smash is no-target
			reason = "E-带线AOE" .. #laneCreeps
			return BOT_ACTION_DESIRE_HIGH, reason
		end
	end
	if Fu.IsFarming(bot) and DotaTime() > 6 * 60 and Fu.IsAllowedToSpam(bot, manaCost * 0.25) then
		local neutralCreeps = bot:GetNearbyNeutralCreeps(radius)
		if #neutralCreeps >= 2 and Fu.IsValid(botTarget) then
			target = botTarget
			reason = "E-打野AOE" .. #neutralCreeps
			return BOT_ACTION_DESIRE_HIGH, reason
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderR()
	if not ravageAbility:IsFullyCastable() then
		return 0
	end
	local abilityLevel = ravageAbility:GetLevel()
	local castRange = ravageAbility:GetSpecialValueInt("radius")
	local radius = ravageAbility:GetSpecialValueInt("radius")
	local castPoint = ravageAbility:GetCastPoint()
	local manaCost = ravageAbility:GetManaCost()
	local damage = ravageAbility:GetAbilityDamage()
	local damageType = DAMAGE_TYPE_MAGICAL
	local enemiesInRange = Fu.GetAroundEnemyHeroList(castRange - 80)
	local closeEnemies = Fu.GetAroundEnemyHeroList(castRange - 260)
	local target = nil
	local reason = nil
	for _, enemy in pairs(enemiesInRange) do
		if enemy:IsChanneling() and not enemy:IsMagicImmune() then
			target = enemy
			reason = "R-打断" .. Fu.Chat.GetNormName(target)
			return BOT_ACTION_DESIRE_HIGH, reason
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		-- Review fix: Ravage (1250 radius, 140-150s cooldown) went out on any single target within 600,
		-- so a lane gank spent the teamfight ult. Now only when it also hits a second hero, or the
		-- lone target is below half HP (a kill).
		local inRavage = 0
		for _, enemy in pairs(enemiesInRange) do
			if Fu.IsValidHero(enemy) and Fu.CanCastOnNonMagicImmune(enemy) and not Fu.IsSuspiciousIllusion(enemy) then
				inRavage = inRavage + 1
			end
		end
		if
			Fu.IsValidHero(botTarget)
			and Fu.IsInRange(botTarget, bot, 600)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and not Fu.IsDisabled(botTarget)
			and (inRavage >= 2 or Fu.GetHP(botTarget) < 0.5)
		then
			if DotaTime() - (X.lastRavageLog or -99) > 10 then
				X.lastRavageLog = DotaTime()
				pcall(
					print,
					string.format(
						"[OHA-TIDE] t=%.0f ravage-engage heroes=%d targetHp=%.2f",
						DotaTime(),
						inRavage,
						Fu.GetHP(botTarget)
					)
				)
			end
			target = botTarget
			reason = "R-先手" .. Fu.Chat.GetNormName(target)
			return BOT_ACTION_DESIRE_HIGH, reason
		end
	end
	if Fu.IsInTeamFight(bot, 1200) then
		local heroCount = 0
		for _, enemy in pairs(enemiesInRange) do
			if Fu.IsValidHero(enemy) and Fu.CanCastOnNonMagicImmune(enemy) and not Fu.IsDisabled(enemy) then
				heroCount = heroCount + 1
			end
		end
		if heroCount >= 2 then
			target = botTarget
			reason = "R-团战AOE" .. heroCount
			return BOT_ACTION_DESIRE_HIGH, reason
		end
	end
	if Fu.IsRetreating(bot) and #closeEnemies >= 1 and #nearbyAllies >= 2 then
		local heroCount = 0
		for _, enemy in pairs(closeEnemies) do
			if
				Fu.IsValidHero(enemy)
				and Fu.IsInRange(bot, enemy, 450)
				and Fu.CanCastOnNonMagicImmune(enemy)
				and not Fu.IsDisabled(enemy)
				and bot:WasRecentlyDamagedByHero(enemy, 3.0)
			then
				heroCount = heroCount + 1
			end
		end
		if heroCount >= 1 then
			target = botTarget
			reason = "R-撤退AOE" .. heroCount
			return BOT_ACTION_DESIRE_HIGH, reason
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderDeadInTheWater()
	if not deadInTheWaterAbility:IsTrained() or not deadInTheWaterAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castRange = deadInTheWaterAbility:GetCastRange()
	local enemiesInRange = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	if Fu.IsRetreating(bot) then
		for _, enemy in pairs(enemiesInRange) do
			if
				Fu.IsValid(enemy)
				and Fu.IsMoving(enemy)
				and Fu.IsInRange(enemy, bot, castRange)
				and bot:WasRecentlyDamagedByHero(enemy, 4.0)
				and Fu.CanCastOnNonMagicImmune(enemy)
				and IsWithoutSpellShield(enemy)
				and not Fu.IsDisabled(enemy)
			then
				return BOT_ACTION_DESIRE_HIGH, enemy
			end
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidHero(botTarget)
			and Fu.IsMoving(botTarget)
			and Fu.IsInRange(botTarget, bot, castRange)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and IsWithoutSpellShield(botTarget)
			and not Fu.IsDisabled(botTarget)
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end
	local firstEnemy = enemiesInRange[1]
	if
		Fu.IsValidHero(firstEnemy)
		and Fu.IsMoving(firstEnemy)
		and Fu.IsInRange(bot, firstEnemy, castRange - 100)
		and Fu.CanCastOnNonMagicImmune(firstEnemy)
		and IsWithoutSpellShield(firstEnemy)
		and not Fu.IsDisabled(firstEnemy)
		and Fu.IsRunning(firstEnemy)
	then
		return BOT_ACTION_DESIRE_HIGH, firstEnemy
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function IsWithoutSpellShield(unit)
	return not unit:HasModifier("modifier_item_sphere_target")
		and not unit:HasModifier("modifier_antimage_spell_shield")
		and not unit:HasModifier("modifier_item_lotus_orb_active")
end
return X
