-- Sand King: skill build, item build, and ability use for this hero.
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
local tTalentTreeList = { ["t25"] = { 10, 0 }, ["t20"] = { 0, 10 }, ["t15"] = { 10, 0 }, ["t10"] = { 10, 0 } }
local tAllAbilityBuildList = { { 1, 3, 2, 2, 2, 6, 2, 1, 1, 1, 6, 3, 3, 3, 6 } }
local nAbilityBuildList = Fu.Skill.GetRandomBuild(tAllAbilityBuildList)
local nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList)
local sUtility = RandomInt(1, 2) == 1 and "item_crimson_guard" or "item_pipe"
local sRoleItemsBuyList = {}
-- Stratz 7.41f, week of 9 Nov 2026: pos 3, 44,186 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_3"] = {
	"item_tango",
	"item_double_branches",
	"item_gauntlets",
	"item_quelling_blade",
	"item_circlet",
	"item_bracer",
	"item_magic_wand",
	"item_phase_boots",
	"item_blink",
	"item_ultimate_scepter",
	"item_aghanims_shard",
	sUtility,
	"item_shivas_guard",
	"item_travel_boots",
	"item_ultimate_scepter_2",
	"item_overwhelming_blink",
	"item_refresher",
	"item_basher",
	"item_abyssal_blade",
	"item_moon_shard",
	"item_travel_boots_2",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 1 has 594 matches, built from pos 3 (44,186) (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_1"] = sRoleItemsBuyList["pos_3"]
-- Stratz 7.41f, week of 9 Nov 2026: pos 2, 22,589 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_2"] = {
	"item_tango",
	"item_double_branches",
	"item_quelling_blade",
	"item_faerie_fire",
	"item_gauntlets",
	"item_magic_wand",
	"item_phase_boots",
	"item_blink",
	"item_ultimate_scepter",
	"item_aghanims_shard",
	"item_travel_boots",
	"item_black_king_bar",
	"item_shivas_guard",
	sUtility,
	"item_ultimate_scepter_2",
	"item_overwhelming_blink",
	"item_moon_shard",
	"item_travel_boots_2",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 4, 7,710 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_4"] = {
	"item_tango",
	"item_branches",
	"item_magic_stick",
	"item_gauntlets",
	"item_magic_wand",
	"item_bracer",
	"item_arcane_boots",
	"item_blink",
	"item_aghanims_shard",
	"item_ultimate_scepter",
	"item_shivas_guard",
	"item_travel_boots",
	"item_ultimate_scepter_2",
	"item_veil_of_discord",
	"item_wind_waker",
	"item_overwhelming_blink",
	"item_bloodstone",
	"item_heart",
	"item_moon_shard",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 5, 3,768 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_5"] = {
	"item_tango",
	"item_blood_grenade",
	"item_branches",
	"item_magic_stick",
	"item_enchanted_mango",
	"item_magic_wand",
	"item_arcane_boots",
	"item_blink",
	"item_aghanims_shard",
	"item_cyclone",
	"item_ultimate_scepter",
	"item_shivas_guard",
	"item_ultimate_scepter_2",
	"item_veil_of_discord",
	"item_overwhelming_blink",
	"item_wind_waker",
	"item_heart",
	"item_bloodstone",
	"item_moon_shard",
}
X["sBuyList"] = sRoleItemsBuyList[sRole]
X["sSellList"] = { "item_black_king_bar", "item_quelling_blade" }
if Fu.Role.IsPvNMode() or Fu.Role.IsAllShadow() then
	X["sBuyList"], X["sSellList"] = { "PvN_tank" }, { "item_power_treads", "item_quelling_blade" }
end
nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"] =
	Fu.SetUserHeroInit(nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"])
X["sSkillList"] = Fu.Skill.GetSkillList(sAbilityList, nAbilityBuildList, sTalentList, nTalentBuildList)
X["bDeafaultAbility"] = true
-- Cast when cornered (retreating into 3+ enemies with no way out), before running further.
X["LastStandSpells"] = { { name = "sandking_epicenter", kind = "none" } }
X["bDeafaultItem"] = false
function X.MinionThink(minion)
	Minion.MinionThink(minion)
end
local burrowstrikeAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[1]), "sAbilityList[1]", "sand_king")
local sandStormAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[2]), "sAbilityList[2]", "sand_king")
local thirdSlotAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[3]), "sAbilityList[3]", "sand_king")
local scorpionStrikeAbility =
	SafeAbility(bot:GetAbilityByName("sandking_scorpion_strike"), "sandking_scorpion_strike", "sand_king")
local epicenterAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[6]), "sAbilityList[6]", "sand_king")
local burrowstrikeDesire, burrowstrikeLocation
local sandStormDesire
local scorpionStrikeDesire, scorpionStrikeLocation
local epicenterDesire
local aetherRange = 0
local isAttacking
local mpRatio, hpRatio, nearbyEnemies, nearbyAllies
function X.SkillsComplement()
	if Fu.CanNotUseAbility(bot) then
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
	burrowstrikeDesire, burrowstrikeLocation = X.ConsiderQ()
	if burrowstrikeDesire > 0 then
		Fu.SetQueuePtToINT(bot, true)
		bot:ActionQueue_UseAbilityOnLocation(burrowstrikeAbility, burrowstrikeLocation)
		return
	end
	sandStormDesire = X.ConsiderW()
	if sandStormDesire > 0 then
		Fu.SetQueuePtToINT(bot, true)
		bot:ActionQueue_UseAbility(sandStormAbility)
		return
	end
	epicenterDesire = X.ConsiderR()
	if epicenterDesire > 0 then
		Fu.SetQueuePtToINT(bot, true)
		bot:ActionQueue_UseAbility(epicenterAbility)
		return
	end
	scorpionStrikeDesire, scorpionStrikeLocation = X.ConsiderStinger()
	if scorpionStrikeDesire > 0 then
		Fu.SetQueuePtToINT(bot, false)
		bot:ActionQueue_UseAbilityOnLocation(scorpionStrikeAbility, scorpionStrikeLocation)
		return
	end
end
function X.ConsiderQ()
	if not burrowstrikeAbility:IsFullyCastable() then
		return 0
	end
	local castRange = burrowstrikeAbility:GetCastRange() + aetherRange
	local tpTarget = Fu.GetTPTarget(bot, castRange)
	if tpTarget and not tpTarget:IsMagicImmune() then
		return BOT_ACTION_DESIRE_HIGH, tpTarget:GetLocation(), "Q-InterruptTP"
	end
	local abilityLevel = burrowstrikeAbility:GetLevel()
	local burrowWidth = burrowstrikeAbility:GetSpecialValueInt("burrow_width")
	local castPoint = burrowstrikeAbility:GetCastPoint()
	local manaCost = burrowstrikeAbility:GetManaCost()
	local damage = burrowstrikeAbility:GetAbilityDamage()
	local damageType = DAMAGE_TYPE_MAGICAL
	local enemiesInRange = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	local enemiesInExtendedRange = Fu.GetNearbyHeroes(bot, castRange + 200, true, BOT_MODE_NONE)
	local nTargetLocation = nil
	for _, enemyHero in pairs(enemiesInExtendedRange) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and Fu.WillMagicKillTarget(bot, enemyHero, damage + bot:GetAttackDamage(), 3.0)
		then
			nTargetLocation = enemyHero:GetLocation()
			return BOT_ACTION_DESIRE_HIGH, nTargetLocation, "Q-击杀" .. Fu.Chat.GetNormName(enemyHero)
		end
	end
	local aoeLocation = bot:FindAoELocation(true, true, bot:GetLocation(), castRange, burrowWidth + 40, 0, 0)
	if aoeLocation.count >= 3 then
		nTargetLocation = aoeLocation.targetloc
		return BOT_ACTION_DESIRE_HIGH, nTargetLocation, "Q-Aoe:" .. aoeLocation.count
	end
	if Fu.IsInTeamFight(bot, 1200) then
		local teamFightLocation = Fu.GetAoeEnemyHeroLocation(bot, castRange, burrowWidth + 30, 2)
		if teamFightLocation ~= nil then
			nTargetLocation = teamFightLocation
			return BOT_ACTION_DESIRE_HIGH, nTargetLocation, "Q-TeamFight"
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidHero(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(botTarget, bot, castRange)
		then
			if abilityLevel >= 2 or mpRatio > 0.68 or Fu.GetHP(botTarget) < 0.38 then
				nTargetLocation = botTarget:GetLocation()
				return BOT_ACTION_DESIRE_HIGH, nTargetLocation, "Q-攻击:" .. Fu.Chat.GetNormName(botTarget)
			end
		end
	end
	if Fu.IsRetreating(bot) and (abilityLevel >= 4 or hpRatio < 0.4) then
		for _, enemyHero in pairs(enemiesInRange) do
			if
				Fu.IsValid(enemyHero)
				and (bot:WasRecentlyDamagedByHero(enemyHero, 5.0) or bot:GetActiveModeDesire() > 0.7)
				and not bot:IsFacingLocation(enemyHero:GetLocation(), 150)
			then
				local distance = GetUnitToUnitDistance(bot, enemyHero)
				nTargetLocation = Fu.GetUnitTowardDistanceLocation(enemyHero, bot, distance + castRange)
				return BOT_ACTION_DESIRE_HIGH, nTargetLocation, "Q-撤退:" .. Fu.Chat.GetNormName(enemyHero)
			end
		end
	end
	if Fu.IsFarming(bot) and abilityLevel >= 3 and Fu.IsAllowedToSpam(bot, manaCost) then
		if
			Fu.IsValid(botTarget)
			and botTarget:GetTeam() == TEAM_NEUTRAL
			and Fu.IsInRange(bot, botTarget, 1000)
			and bot:IsFacingLocation(botTarget:GetLocation(), 45)
			and (botTarget:GetMagicResist() < 0.4 or mpRatio > 0.9)
		then
			local minCreepCount = mpRatio > 0.5 and 3 or 4
			local creepAoeLocation = bot:FindAoELocation(true, false, bot:GetLocation(), castRange, 200, 0, 0)
			if creepAoeLocation.count >= minCreepCount then
				nTargetLocation = creepAoeLocation.targetloc
				return BOT_ACTION_DESIRE_HIGH, nTargetLocation, "Q-打钱:" .. creepAoeLocation.count
			end
		end
	end
	if
		(Fu.IsPushing(bot) or Fu.IsDefending(bot) or Fu.IsFarming(bot))
		and Fu.IsAllowedToSpam(bot, manaCost)
		and abilityLevel >= 2
		and DotaTime() > 8 * 60
		and #nearbyAllies <= 2
		and #nearbyEnemies == 0
	then
		local laneCreeps = bot:GetNearbyLaneCreeps(1300, true)
		if
			#laneCreeps >= 5
			and Fu.IsValid(laneCreeps[1])
			and not laneCreeps[1]:HasModifier("modifier_fountain_glyph")
		then
			local creepAoeLocation =
				bot:FindAoELocation(true, false, bot:GetLocation(), castRange, burrowWidth + 90, 0, 0)
			if creepAoeLocation.count >= 3 then
				nTargetLocation = creepAoeLocation.targetloc
				return BOT_ACTION_DESIRE_HIGH, nTargetLocation, "Q-推线" .. creepAoeLocation.count
			end
		end
	end
	if bot:GetActiveMode() == BOT_MODE_ROSHAN and bot:GetMana() >= 600 then
		if Fu.IsRoshan(botTarget) and Fu.GetHP(botTarget) > 0.15 and Fu.IsInRange(botTarget, bot, castRange) then
			nTargetLocation = botTarget:GetLocation()
			return BOT_ACTION_DESIRE_HIGH, nTargetLocation, "Q-肉山"
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderW()
	if not sandStormAbility:IsFullyCastable() then
		return 0
	end
	local abilityLevel = sandStormAbility:GetLevel()
	local castRange = sandStormAbility:GetCastRange()
	local castPoint = sandStormAbility:GetCastPoint()
	local manaCost = sandStormAbility:GetManaCost()
	local damage = sandStormAbility:GetAbilityDamage()
	local damageType = DAMAGE_TYPE_MAGICAL
	local enemiesInRange = Fu.GetNearbyHeroes(bot, 800, true, BOT_MODE_NONE)
	local radius = sandStormAbility:GetSpecialValueInt("sand_storm_radius")
	if
		Fu.IsNotAttackProjectileIncoming(bot, 400)
		or Fu.IsWithoutTarget(bot) and Fu.GetAttackProjectileDamageByRange(bot, 1600) >= bot:GetHealth()
	then
		return BOT_ACTION_DESIRE_HIGH, vEscapeLoc, "W-躲避"
	end
	if Fu.IsInTeamFight(bot) then
		local teamFightLocation = Fu.GetAoeEnemyHeroLocation(bot, 100, radius * 0.6, 2)
		if teamFightLocation ~= nil then
			return BOT_ACTION_DESIRE_HIGH, "W-团战Aoe"
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidHero(botTarget)
			and Fu.IsInRange(bot, botTarget, radius / 3)
			and Fu.CanCastOnNonMagicImmune(botTarget)
		then
			if abilityLevel >= 3 or mpRatio > 0.88 or Fu.GetHP(botTarget) < 0.4 then
				return BOT_ACTION_DESIRE_HIGH, "W-进攻:" .. Fu.Chat.GetNormName(botTarget)
			end
		end
	end
	if
		(Fu.IsPushing(bot) or Fu.IsDefending(bot) or Fu.IsFarming(bot))
		and Fu.IsAllowedToSpam(bot, manaCost)
		and abilityLevel >= 4
		and DotaTime() > 18 * 60
		and #nearbyAllies <= 1
		and #nearbyEnemies == 0
	then
		local laneCreeps = bot:GetNearbyLaneCreeps(700, true)
		if
			#laneCreeps >= 8
			and Fu.IsValid(laneCreeps[1])
			and Fu.IsValid(botTarget)
			and Fu.IsInRange(botTarget, bot, 300)
			and not laneCreeps[1]:HasModifier("modifier_fountain_glyph")
		then
			return BOT_ACTION_DESIRE_HIGH, "W-推线" .. #laneCreeps
		end
	end
	if Fu.IsFarming(bot) and abilityLevel >= 3 and Fu.IsAllowedToSpam(bot, manaCost) then
		if
			Fu.IsValid(botTarget)
			and botTarget:GetTeam() == TEAM_NEUTRAL
			and Fu.IsInRange(bot, botTarget, 300)
			and bot:IsFacingLocation(botTarget:GetLocation(), 20)
			and (botTarget:GetMagicResist() < 0.4 or mpRatio > 0.8)
		then
			local minCreepCount = mpRatio > 0.5 and 4 or 5
			local creepAoeLocation = bot:FindAoELocation(true, false, bot:GetLocation(), 100, 600, 0, 0)
			if creepAoeLocation.count >= minCreepCount then
				return BOT_ACTION_DESIRE_HIGH, nTargetLocation, "W-打钱:" .. creepAoeLocation.count
			end
		end
	end
	if Fu.IsRetreating(bot) and (abilityLevel >= 3 or hpRatio < 0.5) then
		for _, enemyHero in pairs(enemiesInRange) do
			if
				Fu.IsValid(enemyHero)
				and (bot:WasRecentlyDamagedByHero(enemyHero, 5.0) or bot:GetActiveModeDesire() > 0.7)
			then
				return BOT_ACTION_DESIRE_HIGH, nTargetLocation, "W-撤退:" .. Fu.Chat.GetNormName(enemyHero)
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderStinger()
	if not scorpionStrikeAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local castRange = Fu.GetProperCastRange(false, bot, scorpionStrikeAbility:GetCastRange())
	local radius = scorpionStrikeAbility:GetSpecialValueInt("radius")
	local manaAfterCast = Fu.GetManaAfter(scorpionStrikeAbility:GetManaCost()) * bot:GetMana()
	local abilityLevel = scorpionStrikeAbility:GetLevel()
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			local alliesNearTarget = Fu.GetNearbyHeroes(botTarget, 1200, true, BOT_MODE_NONE)
			local enemiesNearTarget = Fu.GetNearbyHeroes(botTarget, 1200, false, BOT_MODE_NONE)
			if alliesNearTarget ~= nil and enemiesNearTarget ~= nil and #alliesNearTarget >= #enemiesNearTarget then
				enemiesNearTarget = Fu.GetEnemiesNearLoc(botTarget:GetLocation(), castRange + radius)
				if enemiesNearTarget ~= nil and #enemiesNearTarget >= 1 then
					if
						GetUnitToLocationDistance(bot, Fu.GetCenterOfUnits(enemiesNearTarget)) > castRange
						and GetUnitToLocationDistance(bot, Fu.GetCenterOfUnits(enemiesNearTarget))
							< castRange + radius
					then
						return BOT_ACTION_DESIRE_HIGH,
							Fu.Site.GetXUnitsTowardsLocation(bot, Fu.GetCenterOfUnits(enemiesNearTarget), castRange)
					else
						return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(enemiesNearTarget)
					end
				end
				if Fu.IsInRange(bot, botTarget, castRange + radius) and not Fu.IsInRange(bot, botTarget, castRange) then
					return BOT_ACTION_DESIRE_HIGH,
						Fu.Site.GetXUnitsTowardsLocation(bot, botTarget:GetLocation(), castRange)
				else
					return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
				end
			end
		end
	end
	if Fu.IsRetreating(bot) then
		local enemiesInRange = Fu.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE)
		for _, enemyHero in pairs(enemiesInRange) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.IsChasingTarget(enemyHero, bot)
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and not Fu.IsDisabled(enemyHero)
				and (not burrowstrikeAbility:IsFullyCastable() and not sandStormAbility:IsFullyCastable())
			then
				local alliesNearEnemy = Fu.GetNearbyHeroes(enemyHero, 1200, true, BOT_MODE_NONE)
				local enemiesNearEnemy = Fu.GetNearbyHeroes(enemyHero, 1200, false, BOT_MODE_NONE)
				if
					alliesNearEnemy ~= nil
					and enemiesNearEnemy ~= nil
					and (#enemiesNearEnemy > #alliesNearEnemy or bot:WasRecentlyDamagedByAnyHero(2))
					and GetUnitToUnitDistance(bot, enemyHero) < radius
				then
					return BOT_ACTION_DESIRE_HIGH, (bot:GetLocation() + enemyHero:GetLocation()) / 2
				end
			end
		end
	end
	if
		(Fu.IsPushing(bot) or Fu.IsDefending(bot))
		and manaAfterCast > burrowstrikeAbility:GetManaCost() + sandStormAbility:GetManaCost()
	then
		local laneCreeps = bot:GetNearbyLaneCreeps(1600, true)
		if
			laneCreeps ~= nil
			and #laneCreeps >= 5
			and Fu.CanBeAttacked(laneCreeps[1])
			and not Fu.IsRunning(laneCreeps[1])
		then
			return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(laneCreeps)
		end
	end
	if Fu.IsFarming(bot) and manaAfterCast > burrowstrikeAbility:GetManaCost() + sandStormAbility:GetManaCost() then
		if isAttacking then
			local neutralCreeps = bot:GetNearbyNeutralCreeps(700)
			if neutralCreeps ~= nil and #neutralCreeps >= 3 then
				return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(neutralCreeps)
			end
			local laneCreeps = bot:GetNearbyLaneCreeps(700, true)
			if
				laneCreeps ~= nil
				and #laneCreeps >= 3
				and Fu.CanBeAttacked(laneCreeps[1])
				and not Fu.IsRunning(laneCreeps[1])
			then
				return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(laneCreeps)
			end
		end
	end
	if
		Fu.IsLaning(bot)
		and manaAfterCast > burrowstrikeAbility:GetManaCost() + sandStormAbility:GetManaCost()
		and abilityLevel >= 2
	then
		local enemiesInRange = Fu.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE)
		local laneCreeps = bot:GetNearbyLaneCreeps(castRange + radius, true)
		if
			enemiesInRange ~= nil
			and #enemiesInRange == 0
			and laneCreeps ~= nil
			and #laneCreeps >= 4
			and isAttacking
			and Fu.CanBeAttacked(laneCreeps[1])
			and not Fu.IsRunning(laneCreeps[1])
		then
			return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(laneCreeps)
		end
	end
	if Fu.IsDoingRoshan(bot) and manaAfterCast > burrowstrikeAbility:GetManaCost() + sandStormAbility:GetManaCost() then
		if
			Fu.IsRoshan(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, 600)
			and isAttacking
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	if
		Fu.IsDoingTormentor(bot)
		and manaAfterCast > burrowstrikeAbility:GetManaCost() + sandStormAbility:GetManaCost()
	then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, 600) and isAttacking then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.ConsiderR()
	if not epicenterAbility:IsFullyCastable() then
		return 0
	end
	local abilityLevel = epicenterAbility:GetLevel()
	local castRange = epicenterAbility:GetCastRange()
	local castPoint = epicenterAbility:GetCastPoint()
	local manaCost = epicenterAbility:GetManaCost()
	local damage = epicenterAbility:GetAbilityDamage()
	local damageType = DAMAGE_TYPE_MAGICAL
	local enemiesInRange = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	-- datafeed: there is no "epicenter_radius" (it read 0); the radius starts at epicenter_radius_base (450) and
	-- grows by epicenter_radius_increment (13) per pulse.
	local radius = epicenterAbility:GetSpecialValueInt("epicenter_radius_base")
	local pulseCount = epicenterAbility:GetSpecialValueInt("epicenter_pulses")
	local maxRadius = radius + pulseCount * epicenterAbility:GetSpecialValueInt("epicenter_radius_increment")
	if Fu.IsInTeamFight(bot, 1600) then
		local teamFightLocation = Fu.GetAoeEnemyHeroLocation(bot, 1200, 400, 2)
		if teamFightLocation ~= nil and #nearbyAllies >= 2 then
			local firstEnemy = nearbyEnemies[1]
			if
				Fu.IsValidHero(firstEnemy)
				and not Fu.IsInRange(bot, firstEnemy, 800)
				and Fu.IsInRange(bot, firstEnemy, 1200)
				and Fu.CanCastOnNonMagicImmune(firstEnemy)
				and (#nearbyEnemies >= 2 or firstEnemy:GetHealth() > bot:GetAttackDamage() * 5)
			then
				return BOT_ACTION_DESIRE_HIGH, "R-团战1"
			end
		end
		if #nearbyEnemies >= 2 then
			local disabledCount = 0
			local enemyCount = 0
			for _, enemyHero in pairs(nearbyEnemies) do
				if
					Fu.IsValidHero(enemyHero)
					and Fu.IsInRange(bot, enemyHero, 1000)
					and Fu.CanCastOnNonMagicImmune(enemyHero)
				then
					enemyCount = enemyCount + 1
					if Fu.IsDisabled(enemyHero) or enemyHero:IsSilenced() or enemyHero:GetMana() < 50 then
						disabledCount = disabledCount + 1
					end
				end
			end
			if disabledCount == enemyCount and Fu.IsInRange(bot, nearbyEnemies[1], maxRadius * 0.5) then
				return BOT_ACTION_DESIRE_HIGH, "R-团战2"
			end
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidHero(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, 1000)
		then
			local attackDamage = bot:GetEstimatedDamageToTarget(true, botTarget, 6.0, DAMAGE_TYPE_PHYSICAL)
			if not Fu.CanKillTarget(botTarget, attackDamage, DAMAGE_TYPE_PHYSICAL) then
				if (bot:IsInvisible() or bot:IsMagicImmune()) and Fu.IsInRange(bot, botTarget, radius + 200) then
					return BOT_ACTION_DESIRE_HIGH, "R-隐身或魔免开大进攻" .. Fu.Chat.GetNormName(botTarget)
				end
				if
					(Fu.IsDisabled(botTarget) or botTarget:IsSilenced()) and Fu.IsInRange(bot, botTarget, radius + 150)
				then
					return BOT_ACTION_DESIRE_HIGH, "R-找机会开大进攻" .. Fu.Chat.GetNormName(botTarget)
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
return X
