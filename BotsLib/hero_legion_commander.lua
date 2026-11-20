-- Legion Commander: skill build, item build, and ability use for this hero.
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
local tTalentTreeList = { ["t25"] = { 0, 10 }, ["t20"] = { 10, 0 }, ["t15"] = { 10, 0 }, ["t10"] = { 0, 10 } }
local tAllAbilityBuildList = { { 1, 3, 1, 2, 1, 6, 1, 3, 3, 3, 6, 2, 2, 2, 6 } }
local nAbilityBuildList = Fu.Skill.GetRandomBuild(tAllAbilityBuildList)
local nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList)
local sUtility = "item_team_aura"
local sRoleItemsBuyList = {}
-- Stratz 7.41f, week of 9 Nov 2026: pos 3, 274,671 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_3"] = {
	"item_tango",
	"item_quelling_blade",
	"item_double_branches",
	"item_gauntlets",
	"item_circlet",
	"item_bracer",
	"item_magic_wand",
	"item_phase_boots",
	"item_blink",
	"item_blade_mail",
	"item_black_king_bar",
	"item_aghanims_shard",
	sUtility,
	"item_ultimate_scepter_2",
	"item_overwhelming_blink",
	"item_monkey_king_bar",
	"item_moon_shard",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 1, 9,720 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_1"] = {
	"item_tango",
	"item_quelling_blade",
	"item_double_branches",
	"item_gauntlets",
	"item_circlet",
	"item_bracer",
	"item_magic_wand",
	"item_phase_boots",
	"item_blink",
	"item_blade_mail",
	"item_desolator",
	"item_black_king_bar",
	sUtility,
	"item_aghanims_shard",
	"item_travel_boots",
	"item_swift_blink",
	"item_moon_shard",
	"item_ultimate_scepter_2",
	"item_travel_boots_2",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 2, 16,865 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_2"] = {
	"item_tango",
	"item_quelling_blade",
	"item_double_branches",
	"item_gauntlets",
	"item_circlet",
	"item_bracer",
	"item_magic_wand",
	"item_phase_boots",
	"item_blink",
	"item_blade_mail",
	"item_black_king_bar",
	"item_assault",
	"item_aghanims_shard",
	sUtility,
	"item_overwhelming_blink",
	"item_moon_shard",
	"item_ultimate_scepter_2",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 4, 4,218 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_4"] = {
	"item_tango",
	"item_quelling_blade",
	"item_double_branches",
	"item_gauntlets",
	"item_circlet",
	"item_bracer",
	"item_magic_wand",
	"item_phase_boots",
	"item_blink",
	"item_blade_mail",
	"item_black_king_bar",
	"item_aghanims_shard",
	sUtility,
	"item_travel_boots",
	"item_desolator",
	"item_overwhelming_blink",
	"item_moon_shard",
	"item_ultimate_scepter_2",
	"item_travel_boots_2",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 5, 1,446 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_5"] = {
	"item_tango",
	"item_blood_grenade",
	"item_branches",
	"item_gauntlets",
	"item_quelling_blade",
	"item_circlet",
	"item_bracer",
	"item_magic_wand",
	"item_phase_boots",
	"item_blink",
	"item_blade_mail",
	"item_aghanims_shard",
	"item_black_king_bar",
	sUtility,
	"item_travel_boots",
	"item_desolator",
	"item_moon_shard",
	"item_ultimate_scepter_2",
	"item_travel_boots_2",
}
X["sBuyList"] = sRoleItemsBuyList[sRole]
X["sSellList"] = { "item_black_king_bar", "item_quelling_blade" }
if Fu.Role.IsPvNMode() or Fu.Role.IsAllShadow() then
	X["sBuyList"], X["sSellList"] = { "PvN_tank" }, { "item_power_treads", "item_quelling_blade" }
end
nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"] =
	Fu.SetUserHeroInit(nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"])
X["sSkillList"] = Fu.Skill.GetSkillList(sAbilityList, nAbilityBuildList, sTalentList, nTalentBuildList)
X["bDeafaultAbility"] = false
-- Cast when cornered (retreating into 3+ enemies with no way out), before running further.
X["LastStandSpells"] = { { name = "legion_commander_duel", kind = "unit" } }
X["bDeafaultItem"] = false
function X.MinionThink(minion)
	Minion.MinionThink(minion)
end
local overwhelmingOddsAbility =
	SafeAbility(bot:GetAbilityByName(sAbilityList[1]), "sAbilityList[1]", "legion_commander")
local pressTheAttackAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[2]), "sAbilityList[2]", "legion_commander")
local momentOfCourageAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[3]), "sAbilityList[3]", "legion_commander")
local duelAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[6]), "sAbilityList[6]", "legion_commander")
local talent2 = SafeAbility(bot:GetAbilityByName(sTalentList[2]), "sTalentList[2]", "legion_commander")
local talent5 = SafeAbility(bot:GetAbilityByName(sTalentList[5]), "sTalentList[5]", "legion_commander")
local overwhelmingOddsDesire
local pressTheAttackDesire, pressTheAttackTarget
local momentOfCourageDesire, momentOfCourageTarget
local duelDesire, duelTarget
local mpRatio, nearbyEnemies, nearbyAllies
function X.SkillsComplement()
	if Fu.CanNotUseAbility(bot) or bot:IsInvisible() then
		return
	end
	local context = AbilityContext.Build(bot)
	mpRatio = context.mp
	botTarget = context.target
	nearbyEnemies = context.enemies
	nearbyAllies = context.allies
	duelDesire, duelTarget = X.ConsiderR()
	if duelDesire > 0 then
		-- Clear once, then queue all three: the old Action_UseAbilityOnEntity for Duel cleared the
		-- queue, so the Press the Attack and Blade Mail queued before it never went out.
		bot:Action_ClearActions(false)
		if
			pressTheAttackAbility:IsTrained()
			and pressTheAttackAbility:IsFullyCastable()
			and bot:GetMana() > pressTheAttackAbility:GetManaCost() + duelAbility:GetManaCost()
		then
			-- datafeed: Press the Attack is unit-target (behavior 8); sTalentList[5] is now the Duel duration
			-- talent, not an AoE talent, so the old point-cast branch could never cast.
			bot:ActionQueue_UseAbilityOnEntity(pressTheAttackAbility, bot)
		end
		local bladeMail = Fu.IsItemAvailable("item_blade_mail")
		if
			bladeMail ~= nil
			and bladeMail:IsFullyCastable()
			and bot:GetMana() > bladeMail:GetManaCost() + duelAbility:GetManaCost()
		then
			bot:ActionQueue_UseAbility(bladeMail)
		end
		bot:ActionQueue_UseAbilityOnEntity(duelAbility, duelTarget)
		return
	end
	-- Blink > Duel (was missing: Duel range is 200, so a target out of reach was only Dueled if the
	-- generic Blink logic happened to land next to it first, without Press the Attack or Blade Mail).
	local blinkTarget = X.ConsiderBlinkDuel()
	if blinkTarget ~= nil then
		bot:Action_ClearActions(false)
		if
			pressTheAttackAbility:IsTrained()
			and pressTheAttackAbility:IsFullyCastable()
			and bot:GetMana() > pressTheAttackAbility:GetManaCost() + duelAbility:GetManaCost()
		then
			bot:ActionQueue_UseAbilityOnEntity(pressTheAttackAbility, bot)
		end
		local bladeMail = Fu.IsItemAvailable("item_blade_mail")
		if
			bladeMail ~= nil
			and bladeMail:IsFullyCastable()
			and bot:GetMana() > bladeMail:GetManaCost() + duelAbility:GetManaCost()
		then
			bot:ActionQueue_UseAbility(bladeMail)
		end
		bot:ActionQueue_UseAbilityOnLocation(bot.Blink, blinkTarget:GetLocation())
		bot:ActionQueue_UseAbilityOnEntity(duelAbility, blinkTarget)
		return
	end
	overwhelmingOddsDesire = X.ConsiderQ()
	if overwhelmingOddsDesire > 0 then
		Fu.SetQueuePtToINT(bot, true)
		bot:ActionQueue_UseAbility(overwhelmingOddsAbility)
		return
	end
	pressTheAttackDesire, pressTheAttackTarget = X.ConsiderW()
	if pressTheAttackDesire > 0 then
		Fu.SetQueuePtToINT(bot, true)
		-- datafeed: Press the Attack is unit-target (behavior 8); no talent makes it point-cast.
		bot:ActionQueue_UseAbilityOnEntity(pressTheAttackAbility, pressTheAttackTarget)
		return
	end
end
function X.ConsiderQ()
	if not overwhelmingOddsAbility:IsFullyCastable() then
		return 0
	end
	local abilityLevel = overwhelmingOddsAbility:GetLevel()
	local castRange = 600
	local radius = 600
	local castPoint = overwhelmingOddsAbility:GetCastPoint()
	local manaCost = overwhelmingOddsAbility:GetManaCost()
	local damage = overwhelmingOddsAbility:GetSpecialValueInt("damage") * 2
	local damageType = DAMAGE_TYPE_MAGICAL
	local enemiesInRange = Fu.GetAroundEnemyHeroList(castRange)
	local enemiesInExtendedRange = Fu.GetAroundEnemyHeroList(castRange + 200)
	local castLocation = nil
	local castReason = nil
	for _, enemyHero in pairs(enemiesInRange) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and Fu.WillMagicKillTarget(bot, enemyHero, damage, castPoint)
		then
			castLocation = enemyHero:GetLocation()
			return BOT_ACTION_DESIRE_HIGH, castLocation, "Q-击杀" .. Fu.Chat.GetNormName(enemyHero)
		end
	end
	local aoeLocation = bot:FindAoELocation(true, true, bot:GetLocation(), 10, 590, 0, 0)
	if aoeLocation.count >= 3 then
		castLocation = aoeLocation.targetloc
		return BOT_ACTION_DESIRE_HIGH, castLocation, "Q-消耗"
	end
	if Fu.IsLaning(bot) then
		local enemyAoeLocation = Fu.GetAoeEnemyHeroLocation(bot, 50, 450, 2)
		if enemyAoeLocation ~= nil and mpRatio > 0.38 then
			castLocation = enemyAoeLocation
			return BOT_ACTION_DESIRE_HIGH, castLocation, "Q-对线消耗"
		end
	end
	if Fu.IsInTeamFight(bot, 1200) then
		local enemyAoeLocation = Fu.GetAoeEnemyHeroLocation(bot, 49, 499, 2)
		if enemyAoeLocation ~= nil then
			castLocation = enemyAoeLocation
			return BOT_ACTION_DESIRE_ABSOLUTE, castLocation, "Q-团战"
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidHero(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(botTarget, bot, castRange - 80)
		then
			if abilityLevel >= 2 or mpRatio > 0.68 or Fu.GetHP(botTarget) < 0.38 then
				castLocation = Fu.GetCastLocation(bot, botTarget, 10, 490)
				if castLocation ~= nil then
					return BOT_ACTION_DESIRE_HIGH, castLocation, "Q-攻击" .. Fu.Chat.GetNormName(botTarget)
				end
			end
		end
	end
	if Fu.IsRetreating(bot) and not bot:HasModifier("modifier_legion_commander_overwhelming_odds") then
		for _, enemyHero in pairs(enemiesInRange) do
			if
				Fu.IsValid(enemyHero)
				and bot:WasRecentlyDamagedByHero(enemyHero, 5.0)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
			then
				castLocation = enemyHero:GetLocation()
				return BOT_ACTION_DESIRE_HIGH, castLocation, "Q-撤退" .. Fu.Chat.GetNormName(enemyHero)
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
			local minCreepCount = mpRatio > 0.55 and 3 or 4
			local creepAoeLocation = bot:FindAoELocation(true, false, bot:GetLocation(), 40, 400, 0, 0)
			if creepAoeLocation.count >= minCreepCount then
				castLocation = creepAoeLocation.targetloc
				return BOT_ACTION_DESIRE_HIGH, castLocation, "Q-打钱" .. creepAoeLocation.count
			end
		end
	end
	if
		(Fu.IsPushing(bot) or Fu.IsDefending(bot) or Fu.IsFarming(bot))
		and Fu.IsAllowedToSpam(bot, manaCost * 0.32)
		and abilityLevel >= 2
		and DotaTime() > 6 * 60
		and #nearbyAllies <= 3
		and #nearbyEnemies == 0
	then
		local laneCreeps = bot:GetNearbyLaneCreeps(1400, true)
		if
			#laneCreeps >= 4
			and Fu.IsValid(laneCreeps[1])
			and not laneCreeps[1]:HasModifier("modifier_fountain_glyph")
		then
			local creepAoeLocation = bot:FindAoELocation(true, false, bot:GetLocation(), 30, 400, 0, 0)
			if creepAoeLocation.count >= 4 then
				castLocation = creepAoeLocation.targetloc
				return BOT_ACTION_DESIRE_HIGH, castLocation, "Q-带线" .. creepAoeLocation.count
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderW()
	if not pressTheAttackAbility:IsFullyCastable() then
		return 0
	end
	local abilityLevel = pressTheAttackAbility:GetLevel()
	local castRange = pressTheAttackAbility:GetCastRange()
	local radius = 400
	local castPoint = pressTheAttackAbility:GetCastPoint()
	local manaCost = pressTheAttackAbility:GetManaCost()
	local damage = 0
	local damageType = DAMAGE_TYPE_MAGICAL
	local castTarget = nil
	local castReason = nil
	for _, allyHero in pairs(nearbyAllies) do
		if
			Fu.IsValidHero(allyHero)
			and Fu.IsInRange(bot, allyHero, castRange)
			and not allyHero:HasModifier("modifier_legion_commander_press_the_attack")
			and not allyHero:IsMagicImmune()
			and not allyHero:IsInvulnerable()
			and allyHero:CanBeSeen()
		then
			if
				not allyHero:IsBot()
				and allyHero:GetLevel() >= 6
				and allyHero:GetAttackTarget() ~= nil
				and allyHero:GetMaxHealth() - allyHero:GetHealth() >= 120
			then
				castTarget = allyHero
				castReason = "W-加攻速:" .. Fu.Chat.GetNormName(castTarget)
				return BOT_ACTION_DESIRE_HIGH, castTarget, castReason
			end
			if Fu.IsDisabled(allyHero) then
				castTarget = allyHero
				castReason = "W-解状态:" .. Fu.Chat.GetNormName(castTarget)
				return BOT_ACTION_DESIRE_HIGH, castTarget, castReason
			end
			if
				Fu.IsRetreating(allyHero)
				and Fu.IsRunning(allyHero)
				and allyHero:GetMaxHealth() - allyHero:GetHealth() >= 300
				and allyHero:WasRecentlyDamagedByAnyHero(5.0)
				and allyHero:IsFacingLocation(GetAncient(GetTeam()):GetLocation(), 30)
			then
				castTarget = allyHero
				castReason = "W-加移速:" .. Fu.Chat.GetNormName(castTarget)
				return BOT_ACTION_DESIRE_HIGH, castTarget, castReason
			end
			if Fu.IsGoingOnSomeone(allyHero) then
				local allyTarget = Fu.GetProperTarget(allyHero)
				if
					Fu.IsValidHero(allyTarget)
					and allyHero:IsFacingLocation(allyTarget:GetLocation(), 20)
					and Fu.IsInRange(allyHero, allyTarget, allyHero:GetAttackRange() + 100)
				then
					castTarget = allyHero
					castReason = "W-进攻辅助:" .. Fu.Chat.GetNormName(castTarget)
					return BOT_ACTION_DESIRE_HIGH, castTarget, castReason
				end
			end
			if Fu.GetHP(allyHero) < 0.3 then
				castTarget = allyHero
				castReason = "W-为队友回血:" .. Fu.Chat.GetNormName(castTarget)
				return BOT_ACTION_DESIRE_HIGH, castTarget, castReason
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderR()
	if not duelAbility:IsFullyCastable() then
		return 0
	end
	local abilityLevel = duelAbility:GetLevel()
	local castRange = duelAbility:GetCastRange()
	local radius = 600
	local castPoint = duelAbility:GetCastPoint()
	local manaCost = duelAbility:GetManaCost()
	local duelDuration = duelAbility:GetSpecialValueInt("duration") - 0.3
	local duelDamage = bot:GetAttackDamage() * duelDuration / bot:GetSecondsPerAttack()
	local damageType = DAMAGE_TYPE_PHYSICAL
	local closeEnemies = Fu.GetAroundEnemyHeroList(350)
	local enemiesInRange = Fu.GetAroundEnemyHeroList(650)
	local castTarget = nil
	local castReason = nil
	-- Duel pierces spell immunity (SPELL_IMMUNITY_ENEMIES_YES, MAGIC_IMMUNE_ENEMIES flag in the game KV),
	-- so the old "not IsMagicImmune" tests skipped exactly the BKB'd carries Duel is meant for. Removed in
	-- all three branches. CanCastOnTargetAdvanced added so Duel is not wasted into Linken's/Lotus.
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidHero(botTarget)
			and botTarget:CanBeSeen()
			and not botTarget:IsInvulnerable()
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not Fu.HasForbiddenModifier(botTarget)
			and Fu.CanCastOnTargetAdvanced(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange + 100)
		then
			local botDamage = botTarget:GetActualIncomingDamage(duelDamage, damageType)
			if botDamage > duelDamage then
				botDamage = duelDamage * 0.6
			end
			local allyDamage = X.GetAllyToTargetDamage(botTarget, duelDuration)
			local totalDamage = botDamage * 0.8 + allyDamage * 1.2
			if totalDamage > botTarget:GetHealth() + botTarget:GetHealthRegen() * duelDuration then
				castTarget = botTarget
				castReason = "R-激进的决斗:"
					.. Fu.Chat.GetNormName(castTarget)
					.. " 攻击:"
					.. botDamage
					.. "队友:"
					.. allyDamage
				return BOT_ACTION_DESIRE_HIGH, castTarget, castReason
			end
		end
	end
	for _, enemyHero in pairs(enemiesInRange) do
		-- Channel cut: dropped "IsBot()" (human channellers were never interrupted) and the magic-immune
		-- test (Duel pierces it); added validity and Linken's checks.
		if
			Fu.IsValidHero(enemyHero)
			and enemyHero:IsChanneling()
			and not Fu.IsSuspiciousIllusion(enemyHero)
			and Fu.CanCastOnTargetAdvanced(enemyHero)
		then
			castTarget = enemyHero
			castReason = "R-打断" .. Fu.Chat.GetNormName(castTarget)
			return BOT_ACTION_DESIRE_ABSOLUTE, castTarget, castReason
		end
		if
			Fu.IsValidHero(enemyHero)
			and enemyHero:CanBeSeen()
			and not enemyHero:IsInvulnerable()
			and Fu.CanCastOnTargetAdvanced(enemyHero)
			and not Fu.IsSuspiciousIllusion(enemyHero)
			and not Fu.HasForbiddenModifier(enemyHero)
		then
			local botDamage = enemyHero:GetActualIncomingDamage(duelDamage, DAMAGE_TYPE_PHYSICAL)
			if botDamage > duelDamage then
				botDamage = duelDamage * 0.5
			end
			local allyDamage = X.GetAllyToTargetDamage(enemyHero, duelDuration)
			local totalDamage = botDamage * 0.6 + allyDamage * 0.9
			if totalDamage > enemyHero:GetHealth() then
				local enemyDamageToBot = enemyHero:GetEstimatedDamageToTarget(true, bot, 3.0, DAMAGE_TYPE_PHYSICAL)
				local botDamageToEnemy = bot:GetEstimatedDamageToTarget(true, enemyHero, 3.0, DAMAGE_TYPE_PHYSICAL)
				if bot:GetHealth() * 1.1 / enemyDamageToBot > enemyHero:GetHealth() / botDamageToEnemy then
					castTarget = enemyHero
					castReason = "R-保守的决斗:"
						.. Fu.Chat.GetNormName(castTarget)
						.. " 攻击:"
						.. botDamage
						.. "队友:"
						.. allyDamage
					return BOT_ACTION_DESIRE_HIGH, castTarget, castReason
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
-- Blink-Duel target: going on a hero beyond Duel range but inside Blink range, the same kill estimate
-- as the aggressive Duel above, and not more enemies than allies around the target.
-- [OHA-LC] logs each blink-duel, at most once per 5s.
function X.ConsiderBlinkDuel()
	if not duelAbility:IsFullyCastable() or bot:GetMana() < duelAbility:GetManaCost() or bot:IsRooted() then
		return nil
	end
	if not Fu.IsGoingOnSomeone(bot) or not Fu.CanBlinkDagger(bot) or bot.Blink == nil then
		return nil
	end
	local castRange = duelAbility:GetCastRange()
	local blinkRange = bot.Blink:GetName() == "item_arcane_blink" and 1350 or 1150
	if
		not Fu.IsValidHero(botTarget)
		or not botTarget:CanBeSeen()
		or botTarget:IsInvulnerable()
		or Fu.IsSuspiciousIllusion(botTarget)
		or Fu.HasForbiddenModifier(botTarget)
		or not Fu.CanCastOnTargetAdvanced(botTarget)
		or Fu.IsInRange(bot, botTarget, castRange + 100)
		or not Fu.IsInRange(bot, botTarget, blinkRange)
	then
		return nil
	end
	local duelDuration = duelAbility:GetSpecialValueInt("duration") - 0.3
	local duelDamage = bot:GetAttackDamage() * duelDuration / bot:GetSecondsPerAttack()
	local botDamage = botTarget:GetActualIncomingDamage(duelDamage, DAMAGE_TYPE_PHYSICAL)
	if botDamage > duelDamage then
		botDamage = duelDamage * 0.6
	end
	local allyDamage = X.GetAllyToTargetDamage(botTarget, duelDuration)
	if botDamage * 0.8 + allyDamage * 1.2 <= botTarget:GetHealth() + botTarget:GetHealthRegen() * duelDuration then
		return nil
	end
	local enemiesThere = Fu.GetEnemiesNearLoc(botTarget:GetLocation(), 1200)
	local alliesThere = Fu.GetAlliesNearLoc(botTarget:GetLocation(), 1200)
	if #enemiesThere > #alliesThere + 1 then
		return nil
	end
	if DotaTime() >= (bot._lcLogAt or -999) then
		bot._lcLogAt = DotaTime() + 5
		pcall(
			print,
			string.format(
				"[OHA-LC] t=%.0f blink-duel target=%s dist=%d enemies=%d allies=%d",
				DotaTime(),
				botTarget:GetUnitName(),
				GetUnitToUnitDistance(bot, botTarget),
				#enemiesThere,
				#alliesThere
			)
		)
	end
	return botTarget
end
function X.GetAllyToTargetDamage(target, duration)
	local totalDamage = 0
	local damageType = DAMAGE_TYPE_PHYSICAL
	for i = 1, #GetTeamPlayers(GetTeam()) do
		local teamMember = GetTeamMember(i)
		if
			teamMember ~= nil
			and teamMember ~= bot
			and teamMember:IsAlive()
			and Fu.GetProperTarget(teamMember) == target
			and not Fu.IsDisabled(teamMember)
			and teamMember:IsFacingLocation(target:GetLocation(), 25)
			and GetUnitToUnitDistance(teamMember, target) <= teamMember:GetAttackRange() + 80
		then
			totalDamage = totalDamage + teamMember:GetEstimatedDamageToTarget(true, target, duration, damageType)
		end
	end
	return totalDamage
end
return X
