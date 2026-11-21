-- Death Prophet: skill build, item build, and ability use for this hero.
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
	{ ["t25"] = { 10, 0 }, ["t20"] = { 10, 0 }, ["t15"] = { 0, 10 }, ["t10"] = { 10, 0 } },
}
local tAllAbilityBuildList =
	{ { 1, 3, 1, 3, 1, 6, 1, 3, 3, 2, 6, 2, 2, 2, 6 }, { 1, 3, 1, 3, 1, 6, 1, 3, 3, 2, 6, 2, 2, 2, 6 } }
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
-- No starting Circlet (user report, game 033 20:00: still in her bag): nothing in these builds uses it.
-- Stratz 7.41f, week of 9 Nov 2026: pos 2, 45,531 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_2"] = {
	"item_tango",
	"item_double_branches",
	"item_faerie_fire",
	"item_circlet",
	"item_mantle",
	"item_null_talisman",
	"item_magic_wand",
	"item_boots",
	"item_cyclone",
	"item_travel_boots",
	"item_ultimate_scepter",
	"item_black_king_bar",
	"item_aghanims_shard",
	"item_wind_waker",
	"item_ultimate_scepter_2",
	"item_blink",
	"item_consecrated_wraps",
	"item_octarine_core",
	"item_moon_shard",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 3, 30,577 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_3"] = {
	"item_tango",
	"item_double_branches",
	"item_circlet",
	"item_faerie_fire",
	"item_mantle",
	"item_null_talisman",
	"item_magic_wand",
	"item_phase_boots",
	"item_cyclone",
	"item_ultimate_scepter",
	"item_black_king_bar",
	"item_aghanims_shard",
	"item_wind_waker",
	"item_ultimate_scepter_2",
	"item_blink",
	"item_heart",
	"item_crellas_crozier",
	"item_moon_shard",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 1 has 963 matches, built from pos 2 (45,531) (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_1"] = {
	"item_tango",
	"item_double_branches",
	"item_faerie_fire",
	"item_circlet",
	"item_mantle",
	"item_null_talisman",
	"item_magic_wand",
	"item_boots",
	"item_cyclone",
	"item_travel_boots",
	"item_ultimate_scepter",
	"item_black_king_bar",
	"item_aghanims_shard",
	"item_wind_waker",
	"item_ultimate_scepter_2",
	"item_blink",
	"item_consecrated_wraps",
	"item_octarine_core",
	"item_moon_shard",
	"item_travel_boots_2",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 4, 9,422 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_4"] = {
	"item_tango",
	"item_blood_grenade",
	"item_double_branches",
	"item_circlet",
	"item_faerie_fire",
	"item_null_talisman",
	"item_magic_wand",
	"item_arcane_boots",
	"item_cyclone",
	"item_ultimate_scepter",
	"item_aghanims_shard",
	"item_shivas_guard",
	"item_wind_waker",
	"item_spirit_vessel",
	"item_ultimate_scepter_2",
	"item_rod_of_atos",
	"item_heart",
	"item_moon_shard",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 5, 7,121 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_5"] = {
	"item_tango",
	"item_blood_grenade",
	"item_double_branches",
	"item_circlet",
	"item_faerie_fire",
	"item_magic_wand",
	"item_arcane_boots",
	"item_cyclone",
	"item_consecrated_wraps",
	"item_ultimate_scepter",
	"item_aghanims_shard",
	"item_spirit_vessel",
	"item_wind_waker",
	"item_rod_of_atos",
	"item_ultimate_scepter_2",
	"item_crellas_crozier",
	"item_moon_shard",
}
X["sBuyList"] = sRoleItemsBuyList[sRole]
X["sSellList"] = { "item_ultimate_scepter", "item_magic_wand", "item_black_king_bar", "item_magic_wand" }
if Fu.Role.IsPvNMode() or Fu.Role.IsAllShadow() then
	X["sBuyList"], X["sSellList"] = { "PvN_priest" }, {}
end
nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"] =
	Fu.SetUserHeroInit(nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"])
X["sSkillList"] = Fu.Skill.GetSkillList(sAbilityList, nAbilityBuildList, sTalentList, nTalentBuildList)
X["bDeafaultAbility"] = true
X["bDeafaultItem"] = true
function X.MinionThink(minionUnit)
	if Minion.IsValidUnit(minionUnit) then
		local unitName = minionUnit:GetUnitName()
		if unitName ~= "npc_dota_death_prophet_torment" and unitName ~= "dota_death_prophet_exorcism_spirit" then
			Minion.IllusionThink(minionUnit)
		end
	end
end
local cryptSwarmAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[1]), "sAbilityList[1]", "death_prophet")
local silenceAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[2]), "sAbilityList[2]", "death_prophet")
local spiritSiphonAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[3]), "sAbilityList[3]", "death_prophet")
local exorcismAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[6]), "sAbilityList[6]", "death_prophet")
local talent4 = SafeAbility(bot:GetAbilityByName(sTalentList[4]), "sTalentList[4]", "death_prophet")
local cryptSwarmDesire, cryptSwarmLocation
local silenceDesire, silenceLocation
local spiritSiphonDesire, spiritSiphonTarget
local exorcismDesire
local aetherRange = 0
local botLevel, mpRatio, nearbyEnemies, nearbyAllies
function X.SkillsComplement()
	if Fu.CanNotUseAbility(bot) or bot:IsInvisible() then
		return
	end
	local context = AbilityContext.Build(bot)
	aetherRange = context.aetherRange
	botLevel = context.level
	mpRatio = context.mp
	botTarget = context.target
	nearbyEnemies = context.enemies
	nearbyAllies = context.allies
	silenceDesire, silenceLocation = X.ConsiderW()
	if silenceDesire > 0 then
		Fu.SetQueuePtToINT(bot, true)
		bot:ActionQueue_UseAbilityOnLocation(silenceAbility, silenceLocation)
		return
	end
	exorcismDesire = X.ConsiderR()
	if exorcismDesire > 0 then
		Fu.SetQueuePtToINT(bot, true)
		bot:ActionQueue_UseAbility(exorcismAbility)
		return
	end
	spiritSiphonDesire, spiritSiphonTarget = X.ConsiderE()
	if spiritSiphonDesire > 0 then
		Fu.SetQueuePtToINT(bot, true)
		bot:ActionQueue_UseAbilityOnEntity(spiritSiphonAbility, spiritSiphonTarget)
		return
	end
	cryptSwarmDesire, cryptSwarmLocation = X.ConsiderQ()
	if cryptSwarmDesire > 0 then
		Fu.SetQueuePtToINT(bot, true)
		bot:ActionQueue_UseAbilityOnLocation(cryptSwarmAbility, cryptSwarmLocation)
		return
	end
end
-- Mana kept for Exorcism (datafeed hero_id 43: 200/300/400 mana, cooldown 145/135/125s) while it is learned, ready
-- within NukerRules.ULT_SOON seconds and not already running, so a fight swarm never leaves her unable to cast it.
function X.ExorcismReserve()
	return NukerRules.UltReserve(
		exorcismAbility:IsTrained(),
		exorcismAbility:GetManaCost(),
		exorcismAbility:GetCooldownTimeRemaining(),
		bot:HasModifier("modifier_death_prophet_exorcism")
	)
end
-- Spam (harass, creeps) keeps Exorcism's mana and one Silence (datafeed: 80/90/100/110) for the fight that follows.
function X.SpamReserve()
	local reserve = X.ExorcismReserve()
	if silenceAbility:IsTrained() then
		reserve = reserve + silenceAbility:GetManaCost()
	end
	return reserve
end
-- Spare mana for a spam swarm (NukerRules.SpareMana): her regen pays the cost back within the cooldown, or she is at
-- full mana. Datafeed hero_id 43: Crypt Swarm 80/90/100/110 mana, cooldown 10/9/8/7s; base mana regen 1.7/s, so early
-- on only full mana counts, and regen items (and levels) open the spam.
function X.SwarmSpare(manaCost)
	return NukerRules.SpareMana(
		bot:GetMana(),
		bot:GetMaxMana(),
		manaCost,
		cryptSwarmAbility:GetCooldown(),
		bot:GetManaRegen(),
		X.SpamReserve()
	)
end
function X.LogSwarm(why, target, count, reserve)
	if DotaTime() < (bot._dpSwarmLogAt or -999) then
		return
	end
	bot._dpSwarmLogAt = DotaTime() + 3
	pcall(
		print,
		string.format(
			"[OHA-DP] t=%.0f death_prophet swarm why=%s target=%s n=%d mp=%.2f regen=%.1f reserve=%d",
			DotaTime(),
			why,
			target,
			count,
			mpRatio,
			bot:GetManaRegen(),
			reserve
		)
	)
end
-- Crypt Swarm (#47). The maintainer, 2026-11-21: "my bad, i thought crypt swarm is the ultimate. okay death prophet
-- can spam crypt swarm to enemy hero and lane creep to push when the mana regen is enough". So: kills on any hero,
-- 2+ heroes and fights with Exorcism's mana kept, and harass on one hero or a creep wave whenever the mana is spare.
function X.ConsiderQ()
	if not cryptSwarmAbility:IsFullyCastable() then
		return 0
	end
	local abilityLevel = cryptSwarmAbility:GetLevel()
	local castRange = cryptSwarmAbility:GetCastRange() + aetherRange + 100
	local castPoint = cryptSwarmAbility:GetCastPoint()
	local manaCost = cryptSwarmAbility:GetManaCost()
	-- datafeed: Crypt Swarm has no AbilityDamage, its damage is the special value "damage" (100/175/250/325);
	-- GetAbilityDamage() gave 0, so the kill check never fired and the last-hit AoE had no HP cap.
	local damage = cryptSwarmAbility:GetSpecialValueInt("damage")
	-- datafeed hero_id 43: start_radius 110, end_radius 300, range 900, speed 1100, slow_movement_pct 0.
	local radius = cryptSwarmAbility:GetSpecialValueInt("end_radius")
	local enemiesInRange = Fu.GetNearbyHeroes(bot, castRange - 50, true, BOT_MODE_NONE)
	local castLocation = nil
	-- A kill: no mana kept.
	for _, enemyHero in pairs(enemiesInRange) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and Fu.WillMagicKillTarget(bot, enemyHero, damage, castPoint)
		then
			X.LogSwarm("kill", enemyHero:GetUnitName(), 1, 0)
			castLocation = enemyHero:GetLocation()
			return BOT_ACTION_DESIRE_HIGH, castLocation, "Q-击杀" .. Fu.Chat.GetNormName(enemyHero)
		end
	end
	-- Fights: keep Exorcism's mana. Before, a fight swarm could take the mana Exorcism needed a moment later.
	local fightReserve = X.ExorcismReserve()
	local fightSpend = NukerRules.CanSpend(bot:GetMana(), manaCost, fightReserve)
	local aoeLocation = bot:FindAoELocation(true, true, bot:GetLocation(), castRange, radius + 50, 0, 0)
	if fightSpend and aoeLocation.count >= 3 and bot:GetActiveMode() ~= BOT_MODE_RETREAT then
		X.LogSwarm("teamfight", "heroes", aoeLocation.count, fightReserve)
		castLocation = aoeLocation.targetloc
		return BOT_ACTION_DESIRE_HIGH, castLocation, "Q-Aoe:" .. aoeLocation.count
	end
	if Fu.IsLaning(bot) and fightSpend then
		local heroAoeLocation = Fu.GetAoeEnemyHeroLocation(bot, castRange - 80, radius, 2)
		if heroAoeLocation ~= nil and mpRatio > 0.58 then
			X.LogSwarm("teamfight", "lane-heroes", 2, fightReserve)
			castLocation = heroAoeLocation
			return BOT_ACTION_DESIRE_HIGH, castLocation, "Q对线消耗"
		end
		if #nearbyAllies == 1 and mpRatio > 0.38 then
			local creepAoeLocation =
				bot:FindAoELocation(true, false, bot:GetLocation(), castRange, radius + 50, 0, damage)
			if creepAoeLocation.count >= 3 then
				X.LogSwarm("push", "lane-creeps", creepAoeLocation.count, fightReserve)
				castLocation = creepAoeLocation.targetloc
				return BOT_ACTION_DESIRE_HIGH, castLocation, "Q对线补刀" .. creepAoeLocation.count
			end
		end
	end
	if Fu.IsInTeamFight(bot, 1200) and fightSpend then
		local heroAoeLocation = Fu.GetAoeEnemyHeroLocation(bot, castRange, radius, 2)
		if heroAoeLocation ~= nil then
			X.LogSwarm("teamfight", "heroes", 2, fightReserve)
			castLocation = heroAoeLocation
			return BOT_ACTION_DESIRE_HIGH, castLocation, "Q团战"
		end
	end
	if Fu.IsGoingOnSomeone(bot) and fightSpend then
		if
			Fu.IsValidHero(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(botTarget, bot, castRange - 80)
		then
			if abilityLevel >= 2 or mpRatio > 0.68 or Fu.GetHP(botTarget) < 0.38 then
				castLocation = botTarget:GetExtrapolatedLocation(castPoint)
				if Fu.IsInLocRange(bot, castLocation, castRange) then
					X.LogSwarm("attack", botTarget:GetUnitName(), 1, fightReserve)
					return BOT_ACTION_DESIRE_HIGH, castLocation, "Q打架" .. Fu.Chat.GetNormName(botTarget)
				end
			end
		end
	end
	if Fu.IsRetreating(bot) then
		for _, enemyHero in pairs(enemiesInRange) do
			if
				Fu.IsValid(enemyHero)
				and bot:WasRecentlyDamagedByHero(enemyHero, 5.0)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and bot:IsFacingLocation(enemyHero:GetLocation(), 30)
			then
				castLocation = enemyHero:GetLocation()
				return BOT_ACTION_DESIRE_HIGH, castLocation, "Q撤退:" .. Fu.Chat.GetNormName(enemyHero)
			end
		end
	end
	-- Spam on one enemy hero (replaces the level-15 "and false" branch, which had no mana guard): any hero in range,
	-- not while retreating, when the mana is spare (X.SwarmSpare keeps Exorcism + Silence).
	local spare = X.SwarmSpare(manaCost)
	if spare and not Fu.IsRetreating(bot) then
		local harassTarget = nil
		for _, enemyHero in pairs(enemiesInRange) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and Fu.IsInRange(bot, enemyHero, castRange - 80)
				and (harassTarget == nil or enemyHero:GetHealth() < harassTarget:GetHealth())
			then
				harassTarget = enemyHero
			end
		end
		if harassTarget ~= nil then
			castLocation = harassTarget:GetExtrapolatedLocation(castPoint)
			if Fu.IsInLocRange(bot, castLocation, castRange) then
				X.LogSwarm("harass", harassTarget:GetUnitName(), 1, X.SpamReserve())
				return BOT_ACTION_DESIRE_HIGH, castLocation, "Q消耗" .. Fu.Chat.GetNormName(harassTarget)
			end
		end
	end
	if Fu.IsFarming(bot) and abilityLevel >= 3 and Fu.IsAllowedToSpam(bot, manaCost * 0.25) then
		if
			Fu.IsValid(botTarget)
			and botTarget:GetTeam() == TEAM_NEUTRAL
			and Fu.IsInRange(bot, botTarget, 1000)
			and bot:IsFacingLocation(botTarget:GetLocation(), 45)
			and (botTarget:GetMagicResist() < 0.4 or mpRatio > 0.9)
		then
			local minCreepCount = mpRatio > 0.6 and 2 or 3
			local neutralAoeLocation = bot:FindAoELocation(true, false, bot:GetLocation(), castRange, radius, 0, 0)
			if neutralAoeLocation.count >= minCreepCount then
				castLocation = neutralAoeLocation.targetloc
				return BOT_ACTION_DESIRE_HIGH, castLocation, "Q打钱" .. neutralAoeLocation.count
			end
		end
	end
	-- Creep waves while laning, pushing, defending or farming a lane: with spare mana (X.SwarmSpare) any time, or with
	-- the old spam rule (39% mana left) after 8:00 with no enemy hero near. By a tower (an enemy one while pushing,
	-- ours while defending) the 8:00 and no-hero gates are dropped: that wave is what holds the tower. The swarm does
	-- not hit buildings, so it is the creeps it clears.
	local pushing = Fu.IsPushing(bot)
	local defending = Fu.IsDefending(bot)
	if
		(pushing or defending or Fu.IsFarming(bot) or Fu.IsLaning(bot))
		and not Fu.IsRetreating(bot)
		and abilityLevel >= 2
		and #nearbyAllies <= 3
	then
		local nearTower = pushing and #bot:GetNearbyTowers(1200, true) > 0
			or defending and #bot:GetNearbyTowers(1200, false) > 0
		local oldSpam = Fu.IsAllowedToSpam(bot, manaCost * 0.32)
			and NukerRules.CanSpend(bot:GetMana(), manaCost, fightReserve)
			and (DotaTime() > 8 * 60 and #nearbyEnemies == 0 or nearTower)
		if spare or oldSpam then
			local laneCreeps = bot:GetNearbyLaneCreeps(castRange + 400, true)
			if
				#laneCreeps >= 3
				and Fu.IsValid(laneCreeps[1])
				and not laneCreeps[1]:HasModifier("modifier_fountain_glyph")
			then
				local what = nearTower and "tower-wave" or spare and "spare-wave" or "wave"
				local creepAoeLocation =
					bot:FindAoELocation(true, false, bot:GetLocation(), castRange, radius, 0, damage)
				if creepAoeLocation.count >= 2 and #nearbyAllies == 1 then
					X.LogSwarm("push", what, creepAoeLocation.count, fightReserve)
					castLocation = creepAoeLocation.targetloc
					return BOT_ACTION_DESIRE_HIGH, castLocation, "Q带线1" .. creepAoeLocation.count
				end
				local wideAoeLocation =
					bot:FindAoELocation(true, false, bot:GetLocation(), castRange, radius + 50, 0, 0)
				if wideAoeLocation.count >= 3 and #laneCreeps >= 4 then
					X.LogSwarm("push", what, wideAoeLocation.count, fightReserve)
					castLocation = wideAoeLocation.targetloc
					return BOT_ACTION_DESIRE_HIGH, castLocation, "Q带线2" .. wideAoeLocation.count
				end
			end
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if
			Fu.IsRoshan(botTarget)
			and Fu.GetHP(botTarget) > 0.15
			and Fu.IsInRange(botTarget, bot, castRange)
			and Fu.IsAttacking(bot)
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(botTarget, bot, castRange) and Fu.IsAttacking(bot) then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderW()
	if not silenceAbility:IsFullyCastable() then
		return 0
	end
	local abilityLevel = silenceAbility:GetLevel()
	local castRange = silenceAbility:GetCastRange() + aetherRange
	local radius = silenceAbility:GetSpecialValueInt("radius")
	local castPoint = silenceAbility:GetCastPoint()
	local manaCost = silenceAbility:GetManaCost()
	local damage = silenceAbility:GetAbilityDamage()
	local damageType = DAMAGE_TYPE_MAGICAL
	local enemiesInRange = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	local castLocation = nil
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			enemyHero:IsChanneling()
			and not enemyHero:HasModifier("modifier_teleporting")
			and Fu.IsInRange(bot, enemyHero, castRange + radius)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
		then
			castLocation = Fu.GetCastLocation(bot, enemyHero, castRange, radius)
			if castLocation ~= nil then
				return BOT_ACTION_DESIRE_HIGH, castLocation, "W-Check:" .. Fu.Chat.GetNormName(enemyHero)
			end
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		local heroAoeLocation = Fu.GetAoeEnemyHeroLocation(bot, castRange, radius, 2)
		if heroAoeLocation ~= nil then
			castLocation = heroAoeLocation
			return BOT_ACTION_DESIRE_HIGH, castLocation, "W-Aoe"
		end
		if
			Fu.IsValidHero(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange + radius - 200)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and (Fu.IsInRange(bot, botTarget, 700) or botTarget:IsFacingLocation(bot:GetLocation(), 40))
			and not Fu.IsDisabled(botTarget)
		then
			castLocation = Fu.GetCastLocation(bot, botTarget, castRange, radius)
			if castLocation ~= nil then
				return BOT_ACTION_DESIRE_HIGH, castLocation, "W-Attack:" .. Fu.Chat.GetNormName(botTarget)
			end
		end
	end
	-- Silence was only cast on channelers and while going on someone. Also cast it in a team fight
	-- (2+ heroes in the area) and while retreating on a hero chasing her, so the chaser cannot
	-- cast his stun or gap closer.
	if Fu.IsInTeamFight(bot, 1200) then
		local heroAoeLocation = Fu.GetAoeEnemyHeroLocation(bot, castRange, radius, 2)
		if heroAoeLocation ~= nil then
			if DotaTime() >= (bot._dpSilenceFightLogAt or -999) then
				bot._dpSilenceFightLogAt = DotaTime() + 5
				pcall(print, string.format("[OHA-DEATH_PROPHET] t=%.0f silence fight", DotaTime()))
			end
			return BOT_ACTION_DESIRE_HIGH, heroAoeLocation, "W-Fight"
		end
	end
	if Fu.IsRetreating(bot) and bot:WasRecentlyDamagedByAnyHero(3.0) then
		for _, enemyHero in pairs(enemiesInRange) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.IsChasingTarget(enemyHero, bot)
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and not Fu.IsDisabled(enemyHero)
				and not enemyHero:IsSilenced()
			then
				castLocation = Fu.GetCastLocation(bot, enemyHero, castRange, radius)
				if castLocation ~= nil then
					if DotaTime() >= (bot._dpSilenceLogAt or -999) then
						bot._dpSilenceLogAt = DotaTime() + 5
						pcall(
							print,
							string.format(
								"[OHA-DEATH_PROPHET] t=%.0f silence chaser=%s",
								DotaTime(),
								enemyHero:GetUnitName()
							)
						)
					end
					return BOT_ACTION_DESIRE_HIGH, castLocation, "W-Retreat:" .. Fu.Chat.GetNormName(enemyHero)
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderE()
	if not spiritSiphonAbility:IsFullyCastable() then
		return 0
	end
	local abilityLevel = spiritSiphonAbility:GetLevel()
	local castRange = spiritSiphonAbility:GetCastRange() + aetherRange + 99
	local castPoint = spiritSiphonAbility:GetCastPoint()
	local manaCost = spiritSiphonAbility:GetManaCost()
	local damage = spiritSiphonAbility:GetAbilityDamage()
	local damageType = DAMAGE_TYPE_MAGICAL
	local enemiesInRange = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidHero(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.CanCastOnTargetAdvanced(botTarget)
			and not botTarget:HasModifier("modifier_death_prophet_spirit_siphon_slow")
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget, "E-Attack:" .. Fu.Chat.GetNormName(botTarget)
		end
	end
	if Fu.IsInTeamFight(bot, 1200) then
		for _, enemyHero in pairs(enemiesInRange) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
				and not enemyHero:HasModifier("modifier_death_prophet_spirit_siphon_slow")
			then
				return BOT_ACTION_DESIRE_HIGH, enemyHero, "E-Battle:" .. Fu.Chat.GetNormName(enemyHero)
			end
		end
	end
	if Fu.IsRetreating(bot) then
		for _, enemyHero in pairs(enemiesInRange) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
				and not enemyHero:HasModifier("modifier_death_prophet_spirit_siphon_slow")
			then
				return BOT_ACTION_DESIRE_HIGH, enemyHero, "E-Retreat:" .. Fu.Chat.GetNormName(enemyHero)
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderR()
	if not exorcismAbility:IsFullyCastable() or bot:HasModifier("modifier_death_prophet_exorcism") then
		return 0
	end
	local abilityLevel = exorcismAbility:GetLevel()
	local castRange = exorcismAbility:GetCastRange()
	local castPoint = exorcismAbility:GetCastPoint()
	local manaCost = exorcismAbility:GetManaCost()
	local damage = exorcismAbility:GetAbilityDamage()
	local damageType = DAMAGE_TYPE_MAGICAL
	local enemiesInRange = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidHero(botTarget)
			and (Fu.IsInRange(bot, botTarget, 700) or #nearbyEnemies >= 3 and Fu.IsInRange(bot, botTarget, 1200))
			and Fu.CanCastOnMagicImmune(botTarget)
		then
			return BOT_ACTION_DESIRE_HIGH, "R-Attack:" .. Fu.Chat.GetNormName(botTarget)
		end
	end
	-- Team fight with 2+ enemy heroes inside the spirits' radius (700, datafeed): Exorcism was only
	-- cast while going on a target, so a fight that came to her was fought without the ultimate.
	if Fu.IsInTeamFight(bot, 1200) then
		local nearFoes = Fu.GetNearbyHeroes(bot, 700, true, BOT_MODE_NONE)
		if nearFoes ~= nil and #nearFoes >= 2 then
			if DotaTime() >= (bot._dpExorcismLogAt or -999) then
				bot._dpExorcismLogAt = DotaTime() + 5
				pcall(
					print,
					string.format("[OHA-DEATH_PROPHET] t=%.0f exorcism fight heroes=%d", DotaTime(), #nearFoes)
				)
			end
			return BOT_ACTION_DESIRE_HIGH, "R-Fight"
		end
	end
	local allyLaneCreeps = bot:GetNearbyLaneCreeps(1000, false)
	if Fu.IsPushing(bot) and #allyLaneCreeps >= 1 then
		if
			Fu.IsValidBuilding(botTarget)
			and Fu.IsInRange(bot, botTarget, 800)
			and not botTarget:HasModifier("modifier_fountain_glyph")
			and not botTarget:HasModifier("modifier_backdoor_protection")
		then
			return BOT_ACTION_DESIRE_HIGH, "R-Push"
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
return X
