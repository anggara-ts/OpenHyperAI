-- Lion: skill build, item build, and ability use for this hero.
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
local tTalentTreeList = { ["t25"] = { 10, 0 }, ["t20"] = { 10, 0 }, ["t15"] = { 10, 0 }, ["t10"] = { 0, 10 } }
local tAllAbilityBuildList = { { 1, 3, 1, 2, 3, 6, 1, 1, 3, 3, 6, 2, 2, 2, 6 } }
local nAbilityBuildList = Fu.Skill.GetRandomBuild(tAllAbilityBuildList)
local nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList)
local sRoleItemsBuyList = {}
sRoleItemsBuyList["pos_4"] = {
	"item_blood_grenade",
	"item_priest_outfit",
	"item_mekansm",
	"item_glimmer_cape",
	"item_blink",
	"item_guardian_greaves",
	"item_aghanims_shard",
	"item_spirit_vessel",
	"item_ultimate_scepter",
	"item_shivas_guard",
	"item_moon_shard",
	"item_octarine_core",
	"item_overwhelming_blink",
	"item_ultimate_scepter_2",
}
sRoleItemsBuyList["pos_5"] = {
	"item_blood_grenade",
	"item_mage_outfit",
	"item_ancient_janggo",
	"item_glimmer_cape",
	"item_blink",
	"item_boots_of_bearing",
	"item_aghanims_shard",
	"item_ultimate_scepter",
	"item_shivas_guard",
	"item_sheepstick",
	"item_moon_shard",
	"item_overwhelming_blink",
	"item_ultimate_scepter_2",
}
sRoleItemsBuyList["pos_1"] = {
	"item_tango",
	"item_double_branches",
	"item_faerie_fire",
	"item_double_null_talisman",
	"item_power_treads",
	"item_magic_wand",
	"item_kaya",
	"item_ultimate_scepter",
	"item_kaya_and_sange",
	"item_force_staff",
	"item_hurricane_pike",
	"item_orchid",
	"item_aghanims_shard",
	"item_bloodthorn",
	"item_sheepstick",
	"item_moon_shard",
	"item_octarine_core",
	"item_overwhelming_blink",
	"item_ultimate_scepter_2",
}
sRoleItemsBuyList["pos_2"] = {
	"item_tango",
	"item_double_branches",
	"item_faerie_fire",
	"item_double_null_talisman",
	"item_power_treads",
	"item_magic_wand",
	"item_kaya",
	"item_ultimate_scepter",
	"item_kaya_and_sange",
	"item_aether_lens",
	"item_black_king_bar",
	"item_shivas_guard",
	"item_aghanims_shard",
	"item_octarine_core",
	"item_moon_shard",
	"item_ultimate_scepter_2",
	"item_travel_boots_2",
}
sRoleItemsBuyList["pos_3"] = sRoleItemsBuyList["pos_2"]
X["sBuyList"] = sRoleItemsBuyList[sRole]
X["sSellList"] = { "item_black_king_bar", "item_quelling_blade", "item_octarine_core", "item_hand_of_midas" }
if Fu.Role.IsPvNMode() or Fu.Role.IsAllShadow() then
	X["sBuyList"], X["sSellList"] = { "PvN_mage" }, {}
end
nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"] =
	Fu.SetUserHeroInit(nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"])
X["sSkillList"] = Fu.Skill.GetSkillList(sAbilityList, nAbilityBuildList, sTalentList, nTalentBuildList)
X["bDeafaultAbility"] = false
-- Cast when cornered (retreating into 3+ enemies with no way out), before running further.
X["LastStandSpells"] = { { name = "lion_voodoo", kind = "unit" } }
X["bDeafaultItem"] = true
function X.MinionThink(minionUnit)
	Minion.MinionThink(minionUnit)
end
local earthSpikeAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[1]), "sAbilityList[1]", "lion")
local hexAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[2]), "sAbilityList[2]", "lion")
local manaDrainAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[3]), "sAbilityList[3]", "lion")
local fingerOfDeathAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[6]), "sAbilityList[6]", "lion")
local talent4 = SafeAbility(bot:GetAbilityByName(sTalentList[4]), "sTalentList[4]", "lion")
local talent5 = SafeAbility(bot:GetAbilityByName(sTalentList[5]), "sTalentList[5]", "lion")
-- Hex AoE talent is special_bonus_unique_lion_4 = sTalentList[7] (Valve data: Ability16; it adds
-- "radius" 250 to Voodoo). sTalentList[8] is lion_2, the Earth Spike +600 range talent.
local talent7 = SafeAbility(bot:GetAbilityByName(sTalentList[7]), "sTalentList[7]", "lion")
local earthSpikeDesire, earthSpikeLocation
local hexDesire, hexTarget
local manaDrainDesire, manaDrainTarget
local fingerDesire, fingerTarget
local aetherRange = 0
local lastEarthSpikeTime = -99
local botLevel, mpRatio, hpRatio, nearbyEnemies, nearbyAllies
function X.SkillsComplement()
	if X.ConsiderStopDrain() > 0 then
		bot:Action_ClearActions(true)
		return
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
	manaDrainDesire, manaDrainTarget = X.ConsiderE()
	if manaDrainDesire > 0 then
		bot:Action_ClearActions(false)
		bot:ActionQueue_UseAbilityOnEntity(manaDrainAbility, manaDrainTarget)
		return
	end
	fingerDesire, fingerTarget = X.ConsiderR()
	if fingerDesire > 0 then
		Fu.SetQueuePtToINT(bot, true)
		bot:ActionQueue_UseAbilityOnEntity(fingerOfDeathAbility, fingerTarget)
		return
	end
	earthSpikeDesire, earthSpikeLocation = X.ConsiderQ()
	if earthSpikeDesire > 0 then
		Fu.SetQueuePtToINT(bot, true)
		bot:ActionQueue_UseAbilityOnLocation(earthSpikeAbility, earthSpikeLocation)
		lastEarthSpikeTime = DotaTime()
		return
	end
	hexDesire, hexTarget = X.ConsiderW()
	if hexDesire > 0 then
		Fu.SetQueuePtToINT(bot, true)
		-- ConsiderW returns a unit in every case now. Voodoo is UNIT_TARGET in the game files; in case
		-- the AoE talent turns it into a point cast at runtime, the order follows GetBehavior().
		local beh = hexAbility:GetBehavior()
		local pointOnly = Fu.CheckBitfieldFlag(beh, ABILITY_BEHAVIOR_POINT)
			and not Fu.CheckBitfieldFlag(beh, ABILITY_BEHAVIOR_UNIT_TARGET)
		if DotaTime() >= (bot._hexCastLogAt or -999) then
			bot._hexCastLogAt = DotaTime() + 30
			pcall(print, string.format("[OHA-LION] t=%.0f hex cast as %s", DotaTime(), pointOnly and "point" or "unit"))
		end
		if pointOnly then
			bot:ActionQueue_UseAbilityOnLocation(hexAbility, hexTarget:GetLocation())
		else
			bot:ActionQueue_UseAbilityOnEntity(hexAbility, hexTarget)
		end
		return
	end
end
function X.ConsiderStopDrain()
	if X.IsAbilityEChanneling() and Fu.IsRetreating(bot) then
		return BOT_ACTION_DESIRE_HIGH
	end
	-- An enemy hero (not the one drained) comes within 700 while Earth Spike or Hex is ready: the
	-- 5s channel blocked every other spell, so he kept draining a creep while being jumped.
	if X.IsAbilityEChanneling() and (earthSpikeAbility:IsFullyCastable() or hexAbility:IsFullyCastable()) then
		for _, enemyHero in pairs(Fu.GetNearbyHeroes(bot, 700, true, BOT_MODE_NONE) or {}) do
			if
				Fu.IsValidHero(enemyHero)
				and not enemyHero:HasModifier("modifier_lion_mana_drain")
				and not Fu.IsSuspiciousIllusion(enemyHero)
			then
				if DotaTime() >= (bot._drainStopLogAt or -999) then
					bot._drainStopLogAt = DotaTime() + 5
					pcall(
						print,
						string.format(
							"[OHA-LION] t=%.0f stop drain for %s",
							DotaTime(),
							(string.gsub(enemyHero:GetUnitName(), "npc_dota_hero_", ""))
						)
					)
				end
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.IsAbilityEChanneling()
	if bot:IsChanneling() then
		local creeps = bot:GetNearbyCreeps(1200, true)
		for _, creep in pairs(creeps) do
			if creep:HasModifier("modifier_lion_mana_drain") then
				return true
			end
		end
		local enemies = Fu.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE)
		for _, enemyHero in pairs(enemies) do
			if enemyHero:HasModifier("modifier_lion_mana_drain") then
				return true
			end
		end
	end
	return false
end
function X.ConsiderQ()
	if not earthSpikeAbility:IsFullyCastable() then
		return 0
	end
	local abilityLevel = earthSpikeAbility:GetLevel()
	local castRange = earthSpikeAbility:GetCastRange() + aetherRange + 20
	local width = earthSpikeAbility:GetSpecialValueInt("width")
	local castPoint = earthSpikeAbility:GetCastPoint()
	local manaCost = earthSpikeAbility:GetManaCost()
	-- datafeed: Earth Spike damage is the "damage" value (105/170/235/300); it has no AbilityDamage (read 0).
	local damage = earthSpikeAbility:GetSpecialValueInt("damage")
	local damageType = DAMAGE_TYPE_MAGICAL
	local enemiesInRange = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	local enemiesInBonusRange = Fu.GetNearbyHeroes(bot, castRange + 200, true, BOT_MODE_NONE)
	local castLocation = nil
	for _, enemyHero in pairs(enemiesInBonusRange) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and Fu.WillMagicKillTarget(bot, enemyHero, damage, 5.0)
		then
			castLocation = enemyHero:GetLocation()
			return BOT_ACTION_DESIRE_HIGH, castLocation, "Q-击杀" .. Fu.Chat.GetNormName(enemyHero)
		end
	end
	local aoe = bot:FindAoELocation(true, true, bot:GetLocation(), castRange, width + 10, 0, 0)
	if aoe.count >= 3 then
		castLocation = aoe.targetloc
		return BOT_ACTION_DESIRE_HIGH, castLocation, "Q-Aoe:" .. aoe.count
	end
	if Fu.IsInTeamFight(bot, 1200) then
		local aoeLocation = Fu.GetAoeEnemyHeroLocation(bot, castRange, width + 20, 2)
		if aoeLocation ~= nil then
			castLocation = aoeLocation
			return BOT_ACTION_DESIRE_HIGH, castLocation, "Q-团控"
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidHero(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(botTarget, bot, castRange + 300)
		then
			if abilityLevel >= 2 or mpRatio > 0.68 or Fu.GetHP(botTarget) < 0.5 then
				local delay = castPoint + GetUnitToUnitDistance(bot, botTarget) / 1600
				castLocation = Fu.GetDelayCastLocation(bot, botTarget, castRange, 260, delay)
				if castLocation ~= nil then
					return BOT_ACTION_DESIRE_HIGH, castLocation, "Q-攻击:" .. Fu.Chat.GetNormName(botTarget)
				end
			end
		end
	end
	if Fu.IsRetreating(bot) then
		for _, enemyHero in pairs(enemiesInRange) do
			if
				Fu.IsValid(enemyHero)
				and (bot:WasRecentlyDamagedByHero(enemyHero, 5.0) or bot:GetActiveModeDesire() > 0.7)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
			then
				castLocation = enemyHero:GetLocation()
				return BOT_ACTION_DESIRE_HIGH, castLocation, "Q-撤退:" .. Fu.Chat.GetNormName(enemyHero)
			end
		end
	end
	if Fu.IsFarming(bot) and abilityLevel >= 2 and Fu.GetManaAfter(manaCost) > 0.3 then
		local neutralCreeps = bot:GetNearbyNeutralCreeps(castRange)
		if #neutralCreeps >= 3 then
			local creepAoe = bot:FindAoELocation(true, false, bot:GetLocation(), castRange, width + 50, 0, 0)
			if creepAoe.count >= 2 then
				castLocation = creepAoe.targetloc
				return BOT_ACTION_DESIRE_HIGH, castLocation, "Q-打钱:" .. creepAoe.count
			end
		end
		local laneCreeps = bot:GetNearbyLaneCreeps(castRange, true)
		if #laneCreeps >= 3 then
			local creepAoe = bot:FindAoELocation(true, false, bot:GetLocation(), castRange, width + 50, 0, 0)
			if creepAoe.count >= 3 then
				castLocation = creepAoe.targetloc
				return BOT_ACTION_DESIRE_HIGH, castLocation, "Q-Farm:" .. creepAoe.count
			end
		end
	end
	if
		(Fu.IsPushing(bot) or Fu.IsDefending(bot) or Fu.IsFarming(bot))
		and Fu.IsAllowedToSpam(bot, manaCost)
		and abilityLevel >= 4
		and DotaTime() > 9 * 60
		and #nearbyAllies <= 2
		and #nearbyEnemies == 0
		and not bot:HasScepter()
	then
		local laneCreeps = bot:GetNearbyLaneCreeps(1300, true)
		if
			#laneCreeps >= 5
			and Fu.IsValid(laneCreeps[1])
			and not laneCreeps[1]:HasModifier("modifier_fountain_glyph")
		then
			local creepAoe = bot:FindAoELocation(true, false, bot:GetLocation(), castRange, width + 90, 0, 0)
			if creepAoe.count >= 3 then
				castLocation = creepAoe.targetloc
				return BOT_ACTION_DESIRE_HIGH, castLocation, "Q-推线" .. creepAoe.count
			end
		end
	end
	if Fu.IsDoingRoshan(bot) and Fu.GetManaAfter(manaCost) > 0.3 then
		if Fu.IsRoshan(botTarget) and Fu.IsInRange(botTarget, bot, castRange) then
			castLocation = botTarget:GetLocation()
			return BOT_ACTION_DESIRE_HIGH, castLocation
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, castRange) and Fu.IsAttacking(bot) then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation(), ""
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
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.IsInRange(bot, enemyHero, castRange)
			then
				castLocation = enemyHero:GetLocation()
				return BOT_ACTION_DESIRE_HIGH, castLocation, "Q-常规"
			end
		end
	end
	if Fu.IsFarming(bot) and Fu.GetManaAfter(manaCost) > 0.3 and abilityLevel >= 2 then
		local neutralCreeps = bot:GetNearbyNeutralCreeps(castRange)
		if neutralCreeps ~= nil and #neutralCreeps >= 3 then
			local creepAoe = bot:FindAoELocation(true, false, bot:GetLocation(), castRange, width + 50, 0, 0)
			if creepAoe.count >= 3 then
				return BOT_ACTION_DESIRE_HIGH, creepAoe.targetloc, "Q-Farm neutrals"
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderW()
	if not hexAbility:IsFullyCastable() or lastEarthSpikeTime > DotaTime() - 0.8 then
		return 0
	end
	local abilityLevel = hexAbility:GetLevel()
	local castRange = hexAbility:GetCastRange() + aetherRange
	local castPoint = hexAbility:GetCastPoint()
	local manaCost = hexAbility:GetManaCost()
	local damage = hexAbility:GetAbilityDamage()
	local damageType = DAMAGE_TYPE_MAGICAL
	local enemiesInRange = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	local enemiesInBonusRange = Fu.GetNearbyHeroes(bot, castRange + 300, true, BOT_MODE_NONE)
	-- The "or talent7:IsTrained()" Linken's bypass is gone here and below: talent7 used to be the wrong talent
	-- (never trained), and whether the AoE hex gets past Linken's is not in the data.
	for _, enemyHero in pairs(enemiesInBonusRange) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanCastOnTargetAdvanced(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
		then
			if enemyHero:IsChanneling() then
				if talent7:IsTrained() then
					return BOT_ACTION_DESIRE_HIGH, enemyHero, "W-打断吟唱:" .. Fu.Chat.GetNormName(enemyHero)
				else
					return BOT_ACTION_DESIRE_HIGH, enemyHero, "W-打断吟唱:" .. Fu.Chat.GetNormName(enemyHero)
				end
			end
			if enemyHero:IsCastingAbility() and Fu.IsInRange(bot, enemyHero, castRange + 50) then
				if talent7:IsTrained() then
					return BOT_ACTION_DESIRE_HIGH, enemyHero, "W-打断施法:" .. Fu.Chat.GetNormName(enemyHero)
				else
					return BOT_ACTION_DESIRE_HIGH, enemyHero, "W-打断施法:" .. Fu.Chat.GetNormName(enemyHero)
				end
			end
		end
	end
	if Fu.IsInTeamFight(bot, 1200) and (#enemiesInBonusRange >= 2 or #nearbyAllies >= 3) then
		if talent7:IsTrained() then
			-- Unit-target even with the AoE talent: hex the castable hero nearest the cluster centre.
			local aoeLocation = Fu.GetAoeEnemyHeroLocation(bot, castRange, 250, 2)
			if aoeLocation ~= nil then
				local best, bestD = nil, 251
				for _, enemyHero in pairs(enemiesInRange) do
					if
						Fu.IsValidHero(enemyHero)
						and Fu.CanCastOnNonMagicImmune(enemyHero)
						and Fu.CanCastOnTargetAdvanced(enemyHero)
						and GetUnitToLocationDistance(enemyHero, aoeLocation) < bestD
					then
						best, bestD = enemyHero, GetUnitToLocationDistance(enemyHero, aoeLocation)
					end
				end
				if best ~= nil then
					return BOT_ACTION_DESIRE_HIGH, best, "W-团控"
				end
			end
		end
		local mostDangerousEnemy = nil
		local maxDamageToBot = 0
		for _, enemyHero in pairs(enemiesInBonusRange) do
			if
				Fu.IsValid(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
				and not Fu.IsDisabled(enemyHero)
				and not Fu.IsTaunted(enemyHero)
				and not enemyHero:IsDisarmed()
			then
				local damageToBot = enemyHero:GetEstimatedDamageToTarget(false, bot, 3.0, DAMAGE_TYPE_PHYSICAL)
				if damageToBot > maxDamageToBot then
					maxDamageToBot = damageToBot
					mostDangerousEnemy = enemyHero
				end
			end
		end
		if mostDangerousEnemy ~= nil and Fu.IsInRange(bot, mostDangerousEnemy, castRange + 50) then
			if talent7:IsTrained() then
				return BOT_ACTION_DESIRE_HIGH,
					mostDangerousEnemy,
					"W-团战:" .. Fu.Chat.GetNormName(mostDangerousEnemy)
			else
				return BOT_ACTION_DESIRE_HIGH,
					mostDangerousEnemy,
					"W-团战:" .. Fu.Chat.GetNormName(mostDangerousEnemy)
			end
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidHero(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.CanCastOnTargetAdvanced(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange + 150)
			and not Fu.IsDisabled(botTarget)
			and not Fu.IsTaunted(botTarget)
			and not botTarget:IsDisarmed()
		then
			if talent7:IsTrained() then
				return BOT_ACTION_DESIRE_HIGH, botTarget, "W-进攻:" .. Fu.Chat.GetNormName(botTarget)
			else
				return BOT_ACTION_DESIRE_HIGH, botTarget, "W-进攻:" .. Fu.Chat.GetNormName(botTarget)
			end
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
				and not Fu.IsTaunted(enemyHero)
				and not enemyHero:IsDisarmed()
			then
				if talent7:IsTrained() then
					return BOT_ACTION_DESIRE_HIGH, enemyHero, "W-保护自己:" .. Fu.Chat.GetNormName(enemyHero)
				else
					return BOT_ACTION_DESIRE_HIGH, enemyHero, "W-保护自己"
				end
			end
		end
	end
	-- Ally save: hex the enemy hitting or chasing a retreating ally Lion can reach. Hex was only
	-- used for his own target, his own safety or in a team fight, never to peel for an ally.
	for _, ally in pairs(Fu.GetNearbyHeroes(bot, castRange + 300, false, BOT_MODE_NONE) or {}) do
		if
			ally ~= bot
			and Fu.IsValidHero(ally)
			and not Fu.IsSuspiciousIllusion(ally)
			and Fu.IsRetreating(ally)
			and ally:WasRecentlyDamagedByAnyHero(2.0)
		then
			for _, enemyHero in pairs(enemiesInRange) do
				if
					Fu.IsValidHero(enemyHero)
					and (enemyHero:GetAttackTarget() == ally or Fu.IsChasingTarget(enemyHero, ally))
					and Fu.CanCastOnNonMagicImmune(enemyHero)
					and Fu.CanCastOnTargetAdvanced(enemyHero)
					and not Fu.IsDisabled(enemyHero)
					and not Fu.IsSuspiciousIllusion(enemyHero)
				then
					if DotaTime() >= (bot._hexSaveLogAt or -999) then
						bot._hexSaveLogAt = DotaTime() + 5
						pcall(
							print,
							string.format(
								"[OHA-LION] t=%.0f hex save %s from %s",
								DotaTime(),
								(string.gsub(ally:GetUnitName(), "npc_dota_hero_", "")),
								(string.gsub(enemyHero:GetUnitName(), "npc_dota_hero_", ""))
							)
						)
					end
					return BOT_ACTION_DESIRE_HIGH, enemyHero, "W-save"
				end
			end
		end
	end
	if Fu.IsRetreating(bot) then
		for _, enemyHero in pairs(enemiesInRange) do
			if
				Fu.IsValidHero(enemyHero)
				and (bot:WasRecentlyDamagedByHero(enemyHero, 4.0) or GetUnitToUnitDistance(bot, enemyHero) <= 600)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
				and not Fu.IsDisabled(enemyHero)
				and not Fu.IsTaunted(enemyHero)
				and not enemyHero:IsDisarmed()
			then
				if talent7:IsTrained() then
					return BOT_ACTION_DESIRE_HIGH, enemyHero, "W-撤退:" .. Fu.Chat.GetNormName(enemyHero)
				else
					return BOT_ACTION_DESIRE_HIGH, enemyHero, "W-撤退:" .. Fu.Chat.GetNormName(enemyHero)
				end
			end
		end
	end
	if Fu.IsDoingRoshan(bot) and mpRatio > 0.6 then
		if
			Fu.IsRoshan(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and not Fu.IsDisabled(botTarget)
			and not botTarget:IsDisarmed()
		then
			if talent7:IsTrained() then
				return BOT_ACTION_DESIRE_HIGH, botTarget, "W-肉山:" .. Fu.Chat.GetNormName(botTarget)
			else
				return BOT_ACTION_DESIRE_HIGH, botTarget, "W-肉山"
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderE()
	if not manaDrainAbility:IsFullyCastable() then
		return 0
	end
	local abilityLevel = manaDrainAbility:GetLevel()
	local castRange = manaDrainAbility:GetCastRange() + aetherRange
	local castPoint = manaDrainAbility:GetCastPoint()
	local manaCost = manaDrainAbility:GetManaCost()
	local damage = manaDrainAbility:GetAbilityDamage()
	local damageType = DAMAGE_TYPE_MAGICAL
	local enemiesInRange = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	local duration = manaDrainAbility:GetSpecialValueFloat("duration")
	local drainAmount = manaDrainAbility:GetSpecialValueInt("mana_per_second") * duration
	local missingMana = bot:GetMaxMana() - bot:GetMana()
	local enemyTowers = bot:GetNearbyTowers(1000, true)
	if
		#nearbyEnemies == 0
		and #enemyTowers == 0
		and not Fu.IsRetreating(bot)
		and not bot:WasRecentlyDamagedByAnyHero(2.0)
		and (missingMana > drainAmount + bot:GetManaRegen() * duration + 50 or missingMana > 500)
	then
		local creeps = bot:GetNearbyCreeps(1600, true)
		for _, creep in pairs(creeps) do
			if
				Fu.IsValid(creep)
				and (creep:GetMana() > drainAmount * 0.8 or creep:GetMana() > 349)
				and Fu.CanCastOnNonMagicImmune(creep)
			then
				return BOT_ACTION_DESIRE_HIGH, creep, "E-补篮"
			end
		end
	end
	if #nearbyEnemies >= 1 then
		local strongestIllusion = nil
		local maxHealth = 0
		local illusionCount = 0
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValidHero(enemyHero)
				and enemyHero:GetUnitName() ~= "npc_dota_hero_chaos_knight"
				and enemyHero:GetUnitName() ~= "npc_dota_hero_vengefulspirit"
				and Fu.IsInRange(enemyHero, bot, castRange + 300)
				and Fu.IsSuspiciousIllusion(enemyHero)
			then
				illusionCount = illusionCount + 1
				if enemyHero:GetHealth() > maxHealth then
					strongestIllusion = enemyHero
					maxHealth = enemyHero:GetHealth()
				end
			end
		end
		if strongestIllusion ~= nil and (illusionCount >= 2 or Fu.GetHP(strongestIllusion) > 0.9) then
			return BOT_ACTION_DESIRE_HIGH,
				strongestIllusion,
				"E-清理幻像:" .. Fu.Chat.GetNormName(strongestIllusion)
		end
	end
	if X.IsOtherAbilityFullyCastable() or abilityLevel <= 1 then
		return 0
	end
	if Fu.IsInTeamFight(bot, 1000) then
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.IsInRange(bot, enemyHero, castRange)
				and not enemyHero:HasModifier("modifier_lion_finger_of_death")
				and enemyHero:GetMana() > 200
				and Fu.CanCastOnMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
				and not Fu.IsDisabled(enemyHero)
				and (not Fu.IsValidHero(botTarget) or not X.MayKillTarget(botTarget))
			then
				return BOT_ACTION_DESIRE_HIGH, enemyHero, "E-团战吸篮:" .. Fu.Chat.GetNormName(enemyHero)
			end
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidHero(botTarget)
			and not botTarget:HasModifier("modifier_lion_finger_of_death")
			and botTarget:GetMana() > 200
			and Fu.IsInRange(bot, botTarget, castRange)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.CanCastOnTargetAdvanced(botTarget)
			and not Fu.IsDisabled(botTarget)
			and not X.MayKillTarget(botTarget)
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget, "E-抽篮:" .. Fu.Chat.GetNormName(botTarget)
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderR()
	if not fingerOfDeathAbility:IsFullyCastable() then
		return 0
	end
	local abilityLevel = fingerOfDeathAbility:GetLevel()
	local splashRadius = 0
	local castRange = fingerOfDeathAbility:GetCastRange() + aetherRange
	if castRange > 1200 then
		castRange = 1200
	end
	local castPoint = fingerOfDeathAbility:GetCastPoint()
	local manaCost = fingerOfDeathAbility:GetManaCost()
	local damageBonus = X.GetAbilityRDamageBonus()
	local baseDamage = fingerOfDeathAbility:GetSpecialValueInt("damage") -- datafeed: 600/725/850 (same as the old 475 + 125 * abilityLevel)
	if bot:HasScepter() then
		-- datafeed: the Scepter adds AoE damage on the initial cast ("splash_radius"), not +100 damage, and
		-- there is no "splash_radius_scepter" value.
		splashRadius = fingerOfDeathAbility:GetSpecialValueInt("splash_radius")
	end
	local damage = baseDamage + damageBonus
	local damageType = DAMAGE_TYPE_MAGICAL
	local enemiesInRange = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	local enemiesInBonusRange = Fu.GetNearbyHeroes(bot, castRange + 400, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(enemiesInBonusRange) do
		if Fu.IsValidHero(enemyHero) and X.CanCastAbilityROnTarget(enemyHero) then
			if Fu.WillMagicKillTarget(bot, enemyHero, damage, castPoint + 0.25) then
				return BOT_ACTION_DESIRE_HIGH, enemyHero, "R击杀" .. Fu.Chat.GetNormName(enemyHero)
			end
		end
	end
	if Fu.IsInTeamFight(bot, 600) or hpRatio < 0.4 and abilityLevel >= 2 then
		local weakestEnemy = nil
		local minHealth = 10000
		for _, enemyHero in pairs(enemiesInBonusRange) do
			if Fu.IsValid(enemyHero) and X.CanCastAbilityROnTarget(enemyHero) then
				local health = enemyHero:GetHealth()
				if health < minHealth then
					minHealth = health
					weakestEnemy = enemyHero
				end
			end
		end
		if weakestEnemy ~= nil and Fu.WillMagicKillTarget(bot, weakestEnemy, damage, castPoint + 0.25) then
			return BOT_ACTION_DESIRE_HIGH, weakestEnemy, "R团战" .. Fu.Chat.GetNormName(weakestEnemy)
		end
		if bot:HasScepter() then
			local enemiesInSplash = Fu.GetEnemyList(bot, castRange + splashRadius + 200)
			local maxHitCount = 1
			local bestSplashTarget = nil
			for _, enemyHero in pairs(enemiesInBonusRange) do
				if
					Fu.IsValidHero(enemyHero)
					and Fu.IsInRange(bot, enemyHero, castRange + 150)
					and not enemyHero:IsMagicImmune()
					and not enemyHero:IsInvulnerable()
				then
					local hitCount = 0
					for _, otherEnemy in pairs(enemiesInSplash) do
						if
							Fu.IsInRange(enemyHero, otherEnemy, splashRadius)
							and not otherEnemy:IsMagicImmune()
							and not otherEnemy:IsInvulnerable()
						then
							hitCount = hitCount + 1
						end
					end
					if hitCount > maxHitCount then
						maxHitCount = hitCount
						bestSplashTarget = enemyHero
					end
				end
			end
			if bestSplashTarget ~= nil and (maxHitCount >= 4 or maxHitCount >= 3 and hpRatio < 0.46) then
				return BOT_ACTION_DESIRE_HIGH, bestSplashTarget, "R团战Aoe:" .. Fu.Chat.GetNormName(bestSplashTarget)
			end
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidHero(botTarget)
			and Fu.IsInRange(botTarget, bot, castRange + 200)
			and X.CanCastAbilityROnTarget(botTarget)
		then
			if
				Fu.WillMagicKillTarget(bot, botTarget, damage, castPoint + 0.25)
				or hpRatio < 0.2 and abilityLevel >= 2
			then
				return BOT_ACTION_DESIRE_HIGH, botTarget, "R打架" .. Fu.Chat.GetNormName(botTarget)
			end
		end
	end
	if Fu.IsRetreating(bot) and abilityLevel >= 2 and hpRatio < 0.3 and bot:WasRecentlyDamagedByAnyHero(3.0) then
		for _, enemyHero in pairs(enemiesInRange) do
			if Fu.IsValidHero(enemyHero) and X.CanCastAbilityROnTarget(enemyHero) then
				return BOT_ACTION_DESIRE_HIGH, enemyHero, "R死前大" .. Fu.Chat.GetNormName(enemyHero)
			end
		end
	end
	if
		bot:HasScepter()
		and (Fu.IsPushing(bot) or Fu.IsFarming(bot) or Fu.IsDefending(bot))
		and abilityLevel >= 3
		and #nearbyEnemies == 0
		and #nearbyAllies <= 2
	then
		local laneCreeps = bot:GetNearbyLaneCreeps(1200, true)
		if #laneCreeps >= 5 and not laneCreeps[1]:HasModifier("modifier_fountain_glyph") then
			local maxHitCount = 4
			local bestCreep = nil
			for _, creep in pairs(laneCreeps) do
				local hitCount = Fu.GetNearbyAroundLocationUnitCount(true, false, splashRadius, creep:GetLocation())
				if hitCount > maxHitCount then
					bestCreep = creep
					maxHitCount = hitCount
				end
			end
			if bestCreep ~= nil then
				return BOT_ACTION_DESIRE_HIGH, bestCreep, "R-带线"
			end
		end
	end
	if Fu.IsDoingRoshan(bot) and Fu.GetManaAfter(manaCost) > 0.3 then
		if Fu.IsRoshan(botTarget) and Fu.GetHP(botTarget) > 0.2 and Fu.IsInRange(bot, botTarget, castRange) then
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.GetAbilityRDamageBonus()
	local talentBonus = talent5:IsTrained() and talent5:GetSpecialValueInt("value") or 0
	local damagePerKill = fingerOfDeathAbility:GetSpecialValueInt("damage_per_kill") + talentBonus
	local killCounterModifier = "modifier_lion_finger_of_death_kill_counter"
	local killCount = Fu.GetModifierCount(bot, killCounterModifier)
	return killCount * damagePerKill
end
function X.CanCastAbilityROnTarget(target)
	if
		Fu.CanCastOnTargetAdvanced(target)
		and not target:HasModifier("modifier_arc_warden_tempest_double")
		and not Fu.IsHaveAegis(target)
	then
		return Fu.CanCastOnNonMagicImmune(target)
	end
	return false
end
function X.IsOtherAbilityFullyCastable()
	return earthSpikeAbility:IsFullyCastable() or hexAbility:IsFullyCastable() or fingerOfDeathAbility:IsFullyCastable()
end
function X.MayKillTarget(target)
	if target:HasModifier("modifier_lion_finger_of_death") then
		return true
	end
	local damage = bot:GetEstimatedDamageToTarget(true, botTarget, 9.0, DAMAGE_TYPE_PHYSICAL)
	if Fu.CanKillTarget(botTarget, damage, DAMAGE_TYPE_PHYSICAL) then
		return true
	end
	return false
end
return X
