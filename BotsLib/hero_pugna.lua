-- Pugna: skill build, item build, and ability use for this hero.
-- Accidental globals made file-local (#13): every bot shares one Lua state, so these were shared.
local botTarget
local X = {}
local bot = GetBot()
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local AbilityContext = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local Minion = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local CastRules = require(GetScriptDirectory() .. "/FuncLib/systems/hero_cast_rules")
local sTalentList = Fu.Skill.GetTalentList(bot)
local sAbilityList = Fu.Skill.GetAbilityList(bot)
local sRole = Fu.Item.GetRoleItemsBuyList(bot)
local tTalentTreeList = { ["t25"] = { 0, 10 }, ["t20"] = { 0, 10 }, ["t15"] = { 10, 0 }, ["t10"] = { 10, 0 } }
local tAllAbilityBuildList = { { 1, 3, 1, 2, 1, 6, 1, 3, 3, 3, 6, 2, 2, 2, 6 } }
local nAbilityBuildList = Fu.Skill.GetRandomBuild(tAllAbilityBuildList)
local nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList)
local sRoleItemsBuyList = {}
-- Stratz 7.41f, week of 9 Nov 2026: pos 4, 37,515 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_4"] = {
	"item_tango",
	"item_blood_grenade",
	"item_double_branches",
	"item_magic_stick",
	"item_faerie_fire",
	"item_magic_wand",
	"item_arcane_boots",
	"item_aether_lens",
	"item_glimmer_cape",
	"item_aghanims_shard",
	"item_ultimate_scepter",
	"item_travel_boots",
	"item_ultimate_scepter_2",
	"item_aeon_disk",
	"item_cyclone",
	"item_force_staff",
	"item_wind_waker",
	"item_moon_shard",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 5, 34,015 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_5"] = {
	"item_tango",
	"item_blood_grenade",
	"item_double_branches",
	"item_magic_stick",
	"item_faerie_fire",
	"item_magic_wand",
	"item_arcane_boots",
	"item_glimmer_cape",
	"item_aether_lens",
	"item_aghanims_shard",
	"item_ultimate_scepter",
	"item_aeon_disk",
	"item_ultimate_scepter_2",
	"item_force_staff",
	"item_cyclone",
	"item_moon_shard",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 1 has 407 matches, built from pos 2 (16,881) (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_1"] = {
	"item_tango",
	"item_double_branches",
	"item_faerie_fire",
	"item_circlet",
	"item_mantle",
	"item_null_talisman",
	"item_magic_wand",
	"item_arcane_boots",
	"item_aether_lens",
	"item_blink",
	"item_ultimate_scepter",
	"item_aghanims_shard",
	"item_travel_boots",
	"item_ultimate_scepter_2",
	"item_meteor_hammer",
	"item_glimmer_cape",
	"item_sphere",
	"item_moon_shard",
	"item_travel_boots_2",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 2, 16,881 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_2"] = {
	"item_tango",
	"item_double_branches",
	"item_faerie_fire",
	"item_circlet",
	"item_mantle",
	"item_null_talisman",
	"item_magic_wand",
	"item_arcane_boots",
	"item_aether_lens",
	"item_blink",
	"item_ultimate_scepter",
	"item_aghanims_shard",
	"item_travel_boots",
	"item_ultimate_scepter_2",
	"item_meteor_hammer",
	"item_glimmer_cape",
	"item_sphere",
	"item_moon_shard",
	"item_travel_boots_2",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 3, 2,125 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_3"] = {
	"item_tango",
	"item_double_branches",
	"item_circlet",
	"item_magic_stick",
	"item_null_talisman",
	"item_magic_wand",
	"item_arcane_boots",
	"item_aether_lens",
	"item_glimmer_cape",
	"item_blink",
	"item_aghanims_shard",
	"item_ultimate_scepter",
	"item_travel_boots",
	"item_ultimate_scepter_2",
	"item_meteor_hammer",
	"item_sphere",
	"item_moon_shard",
	"item_travel_boots_2",
}
X["sBuyList"] = sRoleItemsBuyList[sRole]
X["sSellList"] = { "item_black_king_bar", "item_quelling_blade" }
if Fu.Role.IsPvNMode() or Fu.Role.IsAllShadow() then
	X["sBuyList"], X["sSellList"] = { "PvN_mage" }, {}
end
nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"] =
	Fu.SetUserHeroInit(nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"])
X["sSkillList"] = Fu.Skill.GetSkillList(sAbilityList, nAbilityBuildList, sTalentList, nTalentBuildList)
X["bDeafaultAbility"] = false
X["bDeafaultItem"] = true
-- Declared before MinionThink: it was declared below it, so MinionThink set a global and the
-- Decrepify-the-ward check in ConsiderW read a local that was always nil (datafeed notes:
-- Decrepify "Can be used on your Nether Ward").
local hNetherWard = nil
function X.MinionThink(minion)
	if Minion.IsValidUnit(minion) then
		if Fu.IsKeyWordUnit("pugna_nether_ward", minion) then
			hNetherWard = minion
			return
		end
		Minion.IllusionThink(minion)
	end
end
local netherBlastAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[1]), "sAbilityList[1]", "pugna")
local decrepifyAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[2]), "sAbilityList[2]", "pugna")
local netherWardAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[3]), "sAbilityList[3]", "pugna")
local lifeDrainAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[6]), "sAbilityList[6]", "pugna")
local talent7 = SafeAbility(bot:GetAbilityByName(sTalentList[7]), "sTalentList[7]", "pugna")
local netherBlastDesire, netherBlastLocation
local decrepifyDesire, decrepifyTarget
local netherWardDesire, netherWardLocation
local lifeDrainDesire, lifeDrainTarget
local aetherRange = 0
local bonusBlastDamage = 0
local botLevel, mpRatio, nearbyEnemies, nearbyAllies
function X.SkillsComplement()
	if X.ConsiderStopLifeDrainAlly() then
		bot:Action_ClearActions(true)
		return
	end
	if Fu.CanNotUseAbility(bot) or bot:IsInvisible() then
		return
	end
	local context = AbilityContext.Build(bot)
	aetherRange = context.aetherRange
	bonusBlastDamage = 0
	botLevel = context.level
	mpRatio = context.mp
	botTarget = context.target
	nearbyEnemies = context.enemies
	nearbyAllies = context.allies
	if talent7:IsTrained() then
		bonusBlastDamage = talent7:GetSpecialValueInt("value")
	end
	netherBlastDesire, netherBlastLocation = X.ConsiderQ()
	if netherBlastDesire > 0 then
		Fu.SetQueuePtToINT(bot, true)
		bot:ActionQueue_UseAbilityOnLocation(netherBlastAbility, netherBlastLocation)
		return
	end
	decrepifyDesire, decrepifyTarget = X.ConsiderW()
	if decrepifyDesire > 0 then
		Fu.SetQueuePtToINT(bot, true)
		bot:ActionQueue_UseAbilityOnEntity(decrepifyAbility, decrepifyTarget)
		return
	end
	netherWardDesire, netherWardLocation = X.ConsiderE()
	if netherWardDesire > 0 then
		Fu.SetQueuePtToINT(bot, true)
		bot:ActionQueue_UseAbilityOnLocation(netherWardAbility, netherWardLocation)
		return
	end
	local lifeDrainWhy
	lifeDrainDesire, lifeDrainTarget, lifeDrainWhy = X.ConsiderR()
	if lifeDrainDesire > 0 then
		if lifeDrainWhy == "ally" then
			bot._ohaDrainAlly = lifeDrainTarget
			bot._ohaDrainAllyAt = DotaTime()
			pcall(
				print,
				string.format(
					"[OHA-PUGNA] t=%.0f pugna drain-ally-start ally=%s ally-hp=%.2f hp=%.2f",
					DotaTime(),
					(string.gsub(lifeDrainTarget:GetUnitName(), "npc_dota_hero_", "")),
					Fu.GetHP(lifeDrainTarget),
					Fu.GetHP(bot)
				)
			)
		end
		Fu.SetQueuePtToINT(bot, true)
		bot:ActionQueue_UseAbilityOnEntity(lifeDrainAbility, lifeDrainTarget)
		return
	end
end
function X.ConsiderQ()
	if not netherBlastAbility:IsFullyCastable() then
		return 0
	end
	local abilityLevel = netherBlastAbility:GetLevel()
	local castRange = netherBlastAbility:GetCastRange() + aetherRange
	local radius = netherBlastAbility:GetSpecialValueInt("radius")
	-- datafeed: Nether Blast delay is 0.8s; GetSpecialValueInt truncated it to 0.
	local castDelay = netherBlastAbility:GetCastPoint() + netherBlastAbility:GetSpecialValueFloat("delay")
	local manaCost = netherBlastAbility:GetManaCost()
	local damage = netherBlastAbility:GetSpecialValueInt("blast_damage") + bonusBlastDamage
	local damageType = DAMAGE_TYPE_MAGICAL
	local enemiesInRange = Fu.GetNearbyHeroes(bot, castRange + radius * 0.8, true, BOT_MODE_NONE)
	local castLocation = nil
	for _, enemyHero in pairs(enemiesInRange) do
		if Fu.IsValidHero(enemyHero) and Fu.CanCastOnNonMagicImmune(enemyHero) then
			if Fu.WillMagicKillTarget(bot, enemyHero, damage, castDelay) then
				castLocation = Fu.GetDelayCastLocation(bot, enemyHero, castRange, radius, castDelay)
				if castLocation ~= nil then
					return BOT_ACTION_DESIRE_HIGH, castLocation, "Q击杀" .. Fu.Chat.GetNormName(enemyHero)
				end
			end
		end
	end
	local aoeLocation = bot:FindAoELocation(true, true, bot:GetLocation(), castRange + 50, radius + 20, 0, 0)
	if aoeLocation.count >= 3 then
		castLocation = aoeLocation.targetloc
		return BOT_ACTION_DESIRE_HIGH, castLocation, "Q消耗"
	end
	if Fu.IsInTeamFight(bot, 1200) then
		local teamFightLocation = Fu.GetAoeEnemyHeroLocation(bot, castRange, radius, 2)
		if teamFightLocation ~= nil then
			castLocation = teamFightLocation
			return BOT_ACTION_DESIRE_HIGH, castLocation, "Q团战"
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidHero(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(botTarget, bot, castRange + radius - 120)
		then
			castLocation = Fu.GetDelayCastLocation(bot, botTarget, castRange, radius - 60, castDelay + 0.3)
			if castLocation ~= nil then
				return BOT_ACTION_DESIRE_HIGH, castLocation, "Q打架" .. Fu.Chat.GetNormName(botTarget)
			end
		end
	end
	if Fu.IsRetreating(bot) then
		local retreatAoeLocation = Fu.GetAoeEnemyHeroLocation(bot, castRange - 120, radius - 30, 2)
		if retreatAoeLocation ~= nil then
			castLocation = retreatAoeLocation
			return BOT_ACTION_DESIRE_HIGH, castLocation, "Q撤退Aoe"
		end
		for _, enemyHero in pairs(enemiesInRange) do
			if
				Fu.IsValid(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and (
					bot:WasRecentlyDamagedByHero(enemyHero, 4.0)
					or bot:GetActiveModeDesire() > BOT_ACTION_DESIRE_VERYHIGH
				)
			then
				castLocation = Fu.GetDelayCastLocation(bot, enemyHero, castRange - 140, radius, castDelay + 0.3)
				if not bot:IsFacingLocation(enemyHero:GetLocation(), 50) then
					castLocation = bot:GetLocation()
				end
				if castLocation ~= nil then
					return BOT_ACTION_DESIRE_HIGH, castLocation, "Q撤退消耗:" .. Fu.Chat.GetNormName(enemyHero)
				end
			end
		end
	end
	if
		bot:WasRecentlyDamagedByAnyHero(3.0)
		and botLevel >= 6
		and bot:GetActiveMode() ~= BOT_MODE_RETREAT
		and #enemiesInRange >= 1
	then
		for _, enemyHero in pairs(enemiesInRange) do
			if
				Fu.IsValid(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and bot:IsFacingLocation(enemyHero:GetLocation(), 60)
			then
				castLocation = Fu.GetDelayCastLocation(bot, enemyHero, castRange, radius - 30, castDelay + 0.2)
				if castLocation ~= nil then
					return BOT_ACTION_DESIRE_HIGH, castLocation, "Q自保" .. Fu.Chat.GetNormName(enemyHero)
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
			local minCreepCount = mpRatio > 0.6 and 2 or 3
			local creepAoeLocation = bot:FindAoELocation(true, false, bot:GetLocation(), castRange + 220, radius, 0, 0)
			if creepAoeLocation.count >= minCreepCount then
				castLocation = creepAoeLocation.targetloc
				return BOT_ACTION_DESIRE_HIGH, castLocation, "Q打钱" .. creepAoeLocation.count
			end
		end
	end
	if
		(Fu.IsPushing(bot) or Fu.IsDefending(bot) or Fu.IsFarming(bot))
		and Fu.IsAllowedToSpam(bot, manaCost * 0.32)
		and abilityLevel >= 3
		and DotaTime() > 9 * 60
		and #nearbyAllies <= 3
		and #nearbyEnemies == 0
	then
		local laneCreeps = bot:GetNearbyLaneCreeps(castRange + 400, true)
		if
			#laneCreeps >= 4
			and Fu.IsValid(laneCreeps[1])
			and not laneCreeps[1]:HasModifier("modifier_fountain_glyph")
		then
			local lastHitAoeLocation =
				bot:FindAoELocation(true, false, bot:GetLocation(), castRange + 220, radius, castDelay, damage)
			if lastHitAoeLocation.count >= 3 then
				castLocation = lastHitAoeLocation.targetloc
				return BOT_ACTION_DESIRE_HIGH, castLocation, "Q带线补刀" .. lastHitAoeLocation.count
			end
			local clearAoeLocation =
				bot:FindAoELocation(true, false, bot:GetLocation(), castRange + 220, radius + 50, 0.8, 0)
			if clearAoeLocation.count >= 4 then
				castLocation = clearAoeLocation.targetloc
				return BOT_ACTION_DESIRE_HIGH, castLocation, "Q带线清兵" .. clearAoeLocation.count
			end
		end
	end
	if bot:GetActiveMode() == BOT_MODE_ROSHAN and bot:GetMana() >= 600 then
		if Fu.IsRoshan(botTarget) and Fu.GetHP(botTarget) > 0.2 and Fu.IsInRange(botTarget, bot, castRange + 300) then
			castLocation = botTarget:GetLocation()
			return BOT_ACTION_DESIRE_HIGH, castLocation, "Q肉山"
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(botTarget, bot, castRange) and Fu.IsAttacking(bot) then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	if
		Fu.IsAllowedToSpam(bot, 120)
		and abilityLevel >= 4
		and (botLevel >= 8 or DotaTime() > 8 * 60)
		and bot:GetMana() > lifeDrainAbility:GetManaCost() + 200
	then
		local enemyTowers = bot:GetNearbyTowers(990, true)
		local enemyBarracks = bot:GetNearbyBarracks(990, true)
		local enemyAncient = GetAncient(GetOpposingTeam())
		local buildingCandidates = { botTarget, enemyTowers[1], enemyBarracks[1], enemyAncient }
		for _, building in pairs(buildingCandidates) do
			if
				Fu.IsValidBuilding(building)
				and Fu.IsInRange(bot, building, castRange + radius - 50)
				and not building:HasModifier("modifier_fountain_glyph")
				and not building:HasModifier("modifier_invulnerable")
				and not building:HasModifier("modifier_backdoor_protection")
				and not Fu.IsKeyWordUnit("DOTA_Outpost", building)
			then
				local buildingLocation = building:GetLocation()
				if not Fu.IsInLocRange(bot, buildingLocation, castRange) then
					buildingLocation = Fu.GetUnitTowardDistanceLocation(bot, building, castRange)
				end
				if buildingLocation ~= nil then
					return BOT_ACTION_DESIRE_HIGH, buildingLocation, "Q推塔"
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderW()
	if not decrepifyAbility:IsFullyCastable() then
		return 0
	end
	local abilityLevel = decrepifyAbility:GetLevel()
	local castRange = decrepifyAbility:GetCastRange() + aetherRange
	local castPoint = decrepifyAbility:GetCastPoint()
	local manaCost = decrepifyAbility:GetManaCost()
	local damage = decrepifyAbility:GetAbilityDamage()
	local damageType = DAMAGE_TYPE_MAGICAL
	local enemiesInRange = Fu.GetNearbyHeroes(bot, castRange + 50, true, BOT_MODE_NONE)
	if Fu.IsValid(hNetherWard) and Fu.IsInRange(bot, hNetherWard, castRange) and Fu.GetHP(hNetherWard) < 0.9 then
		for _, enemyHero in pairs(nearbyEnemies) do
			if Fu.IsValid(enemyHero) and enemyHero:GetAttackTarget() == hNetherWard then
				return BOT_ACTION_DESIRE_HIGH, hNetherWard, "W-NetherWard"
			end
		end
	end
	if Fu.IsInTeamFight(bot, 900) and #nearbyEnemies >= 3 then
		local strongestEnemy = nil
		local maxDamage = 0
		for _, enemyHero in pairs(enemiesInRange) do
			if
				Fu.IsValid(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
				and not Fu.IsDisabled(enemyHero)
				and not enemyHero:IsDisarmed()
			then
				local estimatedDamage = enemyHero:GetEstimatedDamageToTarget(false, bot, 3.0, DAMAGE_TYPE_PHYSICAL)
				if estimatedDamage > maxDamage then
					maxDamage = estimatedDamage
					strongestEnemy = enemyHero
				end
			end
		end
		if strongestEnemy ~= nil then
			return BOT_ACTION_DESIRE_HIGH, strongestEnemy, "W-Battle" .. Fu.Chat.GetNormName(strongestEnemy)
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidHero(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange - 60)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.CanCastOnTargetAdvanced(botTarget)
			and Fu.IsAttacking(botTarget)
			and not Fu.IsDisabled(botTarget)
			and not botTarget:IsDisarmed()
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget, "W-attack:" .. Fu.Chat.GetNormName(botTarget)
		end
	end
	for _, allyHero in pairs(nearbyAllies) do
		if
			Fu.IsValidHero(allyHero)
			and Fu.IsRetreating(allyHero)
			and Fu.IsRunning(allyHero)
			and allyHero:WasRecentlyDamagedByAnyHero(4.0)
		then
			local allyNearbyEnemies = Fu.GetEnemyList(allyHero, 1000)
			if #allyNearbyEnemies >= 2 then
				for _, enemyHero in pairs(nearbyEnemies) do
					if
						Fu.IsValidHero(enemyHero)
						and Fu.IsInRange(allyHero, enemyHero, enemyHero:GetAttackRange() + 60)
						and (enemyHero:GetAttackTarget() == allyHero or Fu.IsInRange(allyHero, enemyHero, 500))
					then
						return BOT_ACTION_DESIRE_HIGH, allyHero, "W-protect:" .. Fu.Chat.GetNormName(allyHero)
					end
				end
			else
				local enemyHero = allyNearbyEnemies[1]
				if
					Fu.IsValidHero(enemyHero)
					and Fu.IsInRange(bot, enemyHero, castRange)
					and Fu.CanCastOnNonMagicImmune(enemyHero)
				then
					return BOT_ACTION_DESIRE_HIGH, enemyHero, "W-Retreat:" .. Fu.Chat.GetNormName(enemyHero)
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderE()
	if not netherWardAbility:IsFullyCastable() then
		return 0
	end
	local abilityLevel = netherWardAbility:GetLevel()
	local castRange = netherWardAbility:GetCastRange() + aetherRange
	local radius = netherWardAbility:GetSpecialValueInt("radius")
	local castPoint = netherWardAbility:GetCastPoint()
	local manaCost = netherWardAbility:GetManaCost()
	local damage = netherWardAbility:GetAbilityDamage()
	local damageType = DAMAGE_TYPE_MAGICAL
	local enemiesInRange = Fu.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE)
	local wardLocation = Fu.GetLocationTowardDistanceLocation(bot, Fu.GetTeamFountain(), castRange * 0.8)
	if Fu.IsInTeamFight(bot, 1400) then
		if #enemiesInRange >= 2 then
			local enemyCenter = Fu.GetCenterOfUnits(enemiesInRange)
			if Fu.GetLocationToLocationDistance(wardLocation, enemyCenter) < radius - 300 then
				return BOT_ACTION_DESIRE_HIGH, wardLocation, "E-Battle"
			end
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidHero(botTarget)
			and Fu.IsInLocRange(botTarget, wardLocation, radius - 500)
			and (botTarget:IsFacingLocation(bot:GetLocation(), 50) or Fu.IsInLocRange(botTarget, wardLocation, 800))
			and Fu.CanCastOnNonMagicImmune(botTarget)
		then
			return BOT_ACTION_DESIRE_HIGH, wardLocation, "E-Attack:" .. Fu.Chat.GetNormName(botTarget)
		end
	end
	if Fu.IsRetreating(bot) and botLevel >= 8 then
		local wardLocation = Fu.GetFaceTowardDistanceLocation(bot, castRange)
		for _, enemyHero in pairs(enemiesInRange) do
			if
				Fu.IsValidHero(enemyHero)
				and bot:WasRecentlyDamagedByHero(enemyHero, 3.0)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.IsInLocRange(enemyHero, wardLocation, radius - 400)
			then
				return BOT_ACTION_DESIRE_HIGH, wardLocation, "E-Retreat:" .. Fu.Chat.GetNormName(enemyHero)
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderR()
	if not lifeDrainAbility:IsFullyCastable() then
		return 0
	end
	local abilityLevel = lifeDrainAbility:GetLevel()
	local castRange = lifeDrainAbility:GetCastRange() + aetherRange
	local castPoint = lifeDrainAbility:GetCastPoint()
	local manaCost = lifeDrainAbility:GetManaCost()
	local damage = lifeDrainAbility:GetAbilityDamage()
	local damageType = DAMAGE_TYPE_MAGICAL
	local enemiesInRange = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	local enemiesInFightRange = Fu.GetNearbyHeroes(bot, 1400, true, BOT_MODE_NONE)
	if Fu.IsInTeamFight(bot, 1400) and Fu.HasAghanimsShard(bot) then
		if #enemiesInFightRange >= 2 then
			local alliedUnits = GetUnitList(UNIT_LIST_ALLIES)
			for _, alliedUnit in pairs(alliedUnits) do
				if
					string.find(alliedUnit:GetUnitName(), "nether_ward") and Fu.IsInRange(bot, alliedUnit, castRange)
				then
					-- The debug label read GetNormName(botTarget), which errors when botTarget is nil
					-- and aborted the whole think; the ward's own name is enough.
					return BOT_ACTION_DESIRE_HIGH, alliedUnit, "Nether Ward"
				end
			end
		end
	end
	local drainAllyDesire, drainAlly = X.ConsiderLifeDrainAlly(castRange)
	if drainAllyDesire > 0 then
		return drainAllyDesire, drainAlly, "ally"
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidHero(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.CanCastOnTargetAdvanced(botTarget)
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget, "R-Attack:" .. Fu.Chat.GetNormName(botTarget)
		end
	end
	if Fu.IsRetreating(bot) then
		local attackingAllies = Fu.GetNearbyHeroes(bot, 1400, false, BOT_MODE_ATTACK)
		local defendingAllies = Fu.GetNearbyHeroes(bot, 1600, false, BOT_MODE_DEFEND_ALLY)
		if #attackingAllies >= 1 or #defendingAllies >= 1 or #nearbyEnemies <= 1 then
			for _, enemyHero in pairs(enemiesInRange) do
				if
					Fu.IsValidHero(enemyHero)
					and Fu.IsInRange(bot, enemyHero, castRange - 100)
					and Fu.CanCastOnNonMagicImmune(enemyHero)
					and Fu.CanCastOnTargetAdvanced(enemyHero)
				then
					return BOT_ACTION_DESIRE_HIGH, enemyHero, "R-Retreat:" .. Fu.Chat.GetNormName(enemyHero)
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
-- Life Drain on an ally (#47): 7.42 pugna_life_drain targets BOTH teams; on an ally "Pugna heals his ally and
-- takes magical damage equal to the amount healed. This damage cannot kill Pugna" (datafeed). It was only
-- ever cast on enemies. Heal a hurt ally who is being hit, while Pugna is healthy (CastRules.LifeDrainAllyWorth).
function X.ConsiderLifeDrainAlly(castRange)
	if Fu.GetHP(bot) < CastRules.DRAIN_SELF_MIN_HP then
		return BOT_ACTION_DESIRE_NONE
	end
	local best, bestHp = nil, math.huge
	for _, allyHero in pairs(Fu.GetNearbyHeroes(bot, castRange, false, BOT_MODE_NONE) or {}) do
		if
			Fu.IsValidHero(allyHero)
			and allyHero ~= bot
			and not allyHero:IsIllusion()
			and not allyHero:HasModifier("modifier_necrolyte_reapers_scythe")
			and not allyHero:HasModifier("modifier_ice_blast")
		then
			local allyHp = Fu.GetHP(allyHero)
			local enemiesNearAlly = Fu.GetEnemiesNearLoc(allyHero:GetLocation(), 900) or {}
			if
				allyHp < bestHp
				and CastRules.LifeDrainAllyWorth(
					allyHp,
					Fu.GetHP(bot),
					allyHero:WasRecentlyDamagedByAnyHero(2),
					#enemiesNearAlly
				)
			then
				best, bestHp = allyHero, allyHp
			end
		end
	end
	if best ~= nil then
		return BOT_ACTION_DESIRE_HIGH, best
	end
	return BOT_ACTION_DESIRE_NONE
end
-- While draining an ally: stop once the ally is healed, gone or out of range, or Pugna is low.
function X.ConsiderStopLifeDrainAlly()
	local ally = bot._ohaDrainAlly
	if ally == nil then
		return false
	end
	if not bot:IsChanneling() then
		if DotaTime() > (bot._ohaDrainAllyAt or -999) + 1 then
			bot._ohaDrainAlly = nil
		end
		return false
	end
	local why = nil
	if not Fu.IsValidHero(ally) then
		why = "ally-gone"
	elseif not Fu.IsInRange(bot, ally, 1100) then
		why = "ally-far"
	elseif CastRules.LifeDrainAllyStop(Fu.GetHP(ally), Fu.GetHP(bot)) then
		why = "healed-or-low"
	end
	if why ~= nil then
		pcall(
			print,
			string.format(
				"[OHA-PUGNA] t=%.0f pugna drain-ally-stop why=%s ally-hp=%.2f hp=%.2f",
				DotaTime(),
				why,
				Fu.IsValidHero(ally) and Fu.GetHP(ally) or -1,
				Fu.GetHP(bot)
			)
		)
		bot._ohaDrainAlly = nil
		return true
	end
	return false
end
return X
