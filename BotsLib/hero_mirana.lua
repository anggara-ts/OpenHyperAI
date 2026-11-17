-- [OHA-MIRANA] logs off: the behaviour they traced works (game 029).
local print = function() end
-- Mirana: skill build, item build, and ability use for this hero.
local X = {}
local bot = GetBot()
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local ChargeTracker = require(GetScriptDirectory() .. "/FuncLib/systems/charge_tracker")
local AbilityContext = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local Minion = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local sTalentList = Fu.Skill.GetTalentList(bot)
local sAbilityList = Fu.Skill.GetAbilityList(bot)
local sRole = Fu.Item.GetRoleItemsBuyList(bot)
local tTalentTreeList = { ["t25"] = { 10, 0 }, ["t20"] = { 10, 0 }, ["t15"] = { 10, 0 }, ["t10"] = { 10, 0 } }
-- Starstorm maxed first, Sacred Arrow second, Leap last (Dotabuff most picked order).
local tAllAbilityBuildList = { { 2, 3, 1, 1, 1, 6, 1, 2, 2, 2, 6, 3, 3, 3, 6 } }
local nAbilityBuildList = Fu.Skill.GetRandomBuild(tAllAbilityBuildList)
local nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList)
local sRoleItemsBuyList = {}
sRoleItemsBuyList["pos_1"] = {
	"item_ranged_carry_outfit",
	"item_dragon_lance",
	"item_maelstrom",
	"item_aghanims_shard",
	"item_mjollnir",
	"item_travel_boots",
	"item_orchid",
	"item_bloodthorn",
	"item_force_staff",
	"item_hurricane_pike",
	"item_ultimate_scepter",
	"item_moon_shard",
	"item_travel_boots_2",
	"item_ultimate_scepter_2",
	"item_butterfly",
}
sRoleItemsBuyList["pos_2"] = sRoleItemsBuyList["pos_1"]
sRoleItemsBuyList["pos_4"] = {
	"item_priest_outfit",
	"item_rod_of_atos",
	"item_aghanims_shard",
	"item_ultimate_scepter",
	"item_cyclone",
	"item_mekansm",
	"item_guardian_greaves",
	"item_glimmer_cape",
	"item_spirit_vessel",
	"item_moon_shard",
	"item_ultimate_scepter_2",
	"item_sheepstick",
}
-- One pair of boots in this build (user rule; Util/boots-check.js).
sRoleItemsBuyList["pos_5"] = {
	"item_blood_grenade",
	"item_crystal_maiden_outfit",
	"item_rod_of_atos",
	"item_aghanims_shard",
	"item_ultimate_scepter",
	"item_ancient_janggo",
	"item_guardian_greaves",
	"item_pipe",
	"item_glimmer_cape",
	"item_cyclone",
	"item_shivas_guard",
	"item_sheepstick",
	"item_moon_shard",
	"item_ultimate_scepter_2",
}
sRoleItemsBuyList["pos_3"] = sRoleItemsBuyList["pos_1"]
X["sBuyList"] = sRoleItemsBuyList[sRole]
X["sSellList"] = { "item_maelstrom", "item_quelling_blade" }
if Fu.Role.IsPvNMode() or Fu.Role.IsAllShadow() then
	X["sBuyList"], X["sSellList"] = { "PvN_ranged_carry" }, {}
end
nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"] = Fu.SetUserHeroInit(nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"])
X["sSkillList"] = Fu.Skill.GetSkillList(sAbilityList, nAbilityBuildList, sTalentList, nTalentBuildList)
X["bDeafaultAbility"] = false
X["bDeafaultItem"] = false
function X.MinionThink(minion)
	if Minion.IsValidUnit(minion) then
		Minion.IllusionThink(minion)
	end
end
local starstormAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[1]), "sAbilityList[1]", "mirana")
local sacredArrowAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[2]), "sAbilityList[2]", "mirana")
local leapAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[3]), "sAbilityList[3]", "mirana")
local moonlightShadowAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[6]), "sAbilityList[6]", "mirana")
local celestialQuiverAbility = SafeAbility(bot:GetAbilityByName("mirana_celestial_quiver"), "mirana_celestial_quiver", "mirana")
local starstormDesire
local sacredArrowDesire, sacredArrowLocation
local leapDesire, leapLocation
local moonlightShadowDesire
local celestialQuiverDesire, celestialQuiverTarget
local aetherRange = 0
local botLevel, mpRatio, hpRatio, nearbyEnemies, nearbyAllies
function X.SkillsComplement()
	if Fu.CanNotUseAbility(bot) then
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
	starstormDesire = X.ConsiderQ()
	if starstormDesire > 0 then
		Fu.SetQueuePtToINT(bot, true)
		bot:ActionQueue_UseAbility(starstormAbility)
		return
	end
	X._heldArrow = false
	sacredArrowDesire, sacredArrowLocation = X.ConsiderW()
	if sacredArrowDesire > 0 then
		Fu.SetQueuePtToINT(bot, true)
		bot:ActionQueue_UseAbilityOnLocation(sacredArrowAbility, sacredArrowLocation)
		return
	end
	if X._heldArrow then
		return
	end
	local leapWhy
	leapDesire, leapLocation, leapWhy = X.ConsiderE()
	if leapDesire > 0 and leapWhy == "turn" then
		bot:Action_MoveToLocation(leapLocation)
		return
	end
	if leapDesire > 0 then
		pcall(ChargeTracker.Issued, bot, leapAbility)
		pcall(print, string.format(
			"[OHA-MIRANA] t=%.0f leap-cast charges=%s",
			DotaTime(),
			tostring(ChargeTracker.Count(bot, leapAbility))
		))
		-- Game 036: Leap re-ordered 10-26 times per burst with "can't be used while rooted" although
		-- IsRooted() was false. A second order within 1.5s means the first did not go off: list her
		-- modifiers (once per 10s) to find the root-like state the check misses.
		local now = DotaTime()
		if now - (bot._leapOrderAt or -99) < 1.5 and now >= (bot._leapModLogAt or -99) then
			bot._leapModLogAt = now + 10
			local mods = {}
			for i = 0, bot:NumModifiers() - 1 do
				mods[#mods + 1] = tostring(bot:GetModifierName(i))
			end
			pcall(_G.print, string.format("[OHA-MIRANA] t=%.0f leap-reorder rooted=%s mods=%s", now,
				tostring(bot:IsRooted()), table.concat(mods, ",")))
		end
		bot._leapOrderAt = now
		Fu.SetQueuePtToINT(bot, false)
		bot:ActionQueue_UseAbility(leapAbility)
		return
	end
	moonlightShadowDesire = X.ConsiderR()
	if moonlightShadowDesire > 0 then
		Fu.SetQueuePtToINT(bot, true)
		bot:ActionQueue_UseAbility(moonlightShadowAbility)
		return
	end
	celestialQuiverDesire, celestialQuiverTarget = X.ConsiderCelestialQuiver()
	if celestialQuiverDesire > 0 then
		bot:Action_UseAbilityOnEntity(celestialQuiverAbility, celestialQuiverTarget)
		return
	end
end
function X.ConsiderQ()
	if not starstormAbility:IsFullyCastable() then
		return 0
	end
	local abilityLevel = starstormAbility:GetLevel()
	local radius = starstormAbility:GetSpecialValueInt("starfall_radius")
	local secondaryRadius = starstormAbility:GetSpecialValueInt("starfall_secondary_radius")
	local castPoint = starstormAbility:GetCastPoint()
	local manaCost = starstormAbility:GetManaCost()
	-- Starstorm has no AbilityDamage in the game data; its damage is the special value "damage"
	-- (75/150/225/300). GetAbilityDamage() gave 0, so the kill and lane last-hit casts never fired.
	local damage = starstormAbility:GetSpecialValueInt("damage")
	local damageType = DAMAGE_TYPE_MAGICAL
	local enemiesInSecondaryRadius = Fu.GetAroundEnemyHeroList(secondaryRadius)
	local enemiesInRadius = Fu.GetAroundEnemyHeroList(radius)
	local castTarget = nil
	local castReason = nil
	for _, enemyHero in pairs(enemiesInRadius) do
		if Fu.IsValid(enemyHero) and Fu.CanCastOnNonMagicImmune(enemyHero) and Fu.WillMagicKillTarget(bot, enemyHero, damage, castPoint) then
			castTarget = enemyHero
			castReason = "Q-击杀:" .. Fu.Chat.GetNormName(castTarget)
			return BOT_ACTION_DESIRE_HIGH, castTarget, castReason
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidHero(botTarget)
			and Fu.IsInRange(bot, botTarget, radius)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and (#enemiesInSecondaryRadius >= 1 or #enemiesInRadius >= 2 or hpRatio < 0.4)
		then
			castTarget = botTarget
			castReason = "Q-攻击:" .. Fu.Chat.GetNormName(castTarget)
			return BOT_ACTION_DESIRE_HIGH, castTarget, castReason
		end
	end
	if Fu.IsRetreating(bot) and bot:WasRecentlyDamagedByAnyHero(3.0) and (#enemiesInSecondaryRadius >= 1 or hpRatio < 0.6) then
		for _, enemyHero in pairs(enemiesInRadius) do
			if Fu.IsValid(enemyHero) and Fu.CanCastOnNonMagicImmune(enemyHero) then
				castTarget = enemyHero
				castReason = "Q-撤退" .. Fu.Chat.GetNormName(castTarget)
				return BOT_ACTION_DESIRE_HIGH, castTarget, castReason
			end
		end
	end
	if bot:GetActiveMode() == BOT_MODE_LANING or botLevel <= 7 and #nearbyAllies <= 2 then
		local meleeKillCount = 0
		local rangedKillCount = 0
		local laneCreeps = bot:GetNearbyLaneCreeps(radius, true)
		for _, creep in pairs(laneCreeps) do
			if
				Fu.IsValid(creep)
				and not creep:HasModifier("modifier_fountain_glyph")
				and not Fu.IsOtherAllysTarget(creep)
			then
				local creepDamage = damage
				if Fu.WillKillTarget(creep, creepDamage, damageType, castPoint + 0.57) then
					if Fu.IsKeyWordUnit("ranged", creep) then
						rangedKillCount = rangedKillCount + 1
					end
					if Fu.IsKeyWordUnit("melee", creep) then
						meleeKillCount = meleeKillCount + 1
					end
				end
			end
		end
		if (meleeKillCount + rangedKillCount >= 3 or rangedKillCount >= 1 and meleeKillCount >= 1) and DotaTime() >= (bot._starLaneLogAt or -999) then
			-- [OHA-MIRANA]: lane last-hit Starstorm (dead before the "damage" key fix), every 10s at most.
			bot._starLaneLogAt = DotaTime() + 10
			-- _G.print: the file mutes print (line 2) and this log checks the build-122 fix (game 036 review).
			pcall(_G.print, string.format("[OHA-MIRANA] t=%.0f starstorm-lane melee=%d ranged=%d dmg=%d", DotaTime(), meleeKillCount, rangedKillCount, damage))
		end
		if meleeKillCount + rangedKillCount >= 3 then
			castTarget = bot
			castReason = "Q对线1"
			return BOT_ACTION_DESIRE_HIGH, castTarget, castReason
		end
		if rangedKillCount >= 1 and meleeKillCount >= 1 then
			castTarget = bot
			castReason = "Q对线2"
			return BOT_ACTION_DESIRE_HIGH, castTarget, castReason
		end
		if #laneCreeps == 0 and #enemiesInSecondaryRadius >= 1 and mpRatio > 0.5 then
			castTarget = enemiesInSecondaryRadius[1]
			castReason = "Q对线消耗:" .. Fu.Chat.GetNormName(castTarget)
			return BOT_ACTION_DESIRE_HIGH, castTarget, castReason
		end
	end
	if
		(Fu.IsPushing(bot) or Fu.IsDefending(bot) or Fu.IsFarming(bot))
		and Fu.IsAllowedToSpam(bot, manaCost * 0.32)
		and #nearbyAllies <= 3
		and #nearbyEnemies == 0
	then
		local laneCreeps = bot:GetNearbyLaneCreeps(radius - 50, true)
		if
			Fu.IsValid(laneCreeps[1])
			and not laneCreeps[1]:HasModifier("modifier_fountain_glyph")
			and (#laneCreeps >= 5 or mpRatio > 0.88 and #laneCreeps >= 4)
		then
			castTarget = laneCreeps[1] -- was the undefined global creep (nil); Starstorm is no-target
			castReason = "Q-带线"
			return BOT_ACTION_DESIRE_HIGH, castTarget, castReason
		end
	end
	if Fu.IsFarming(bot) and DotaTime() > 8 * 60 and Fu.IsAllowedToSpam(bot, manaCost) then
		local neutralCreeps = bot:GetNearbyNeutralCreeps(secondaryRadius)
		if #neutralCreeps >= 3 and Fu.IsValid(botTarget) and botTarget:GetMagicResist() < 0.51 then
			castTarget = botTarget
			castReason = "Q-打野AOE" .. #neutralCreeps
			return BOT_ACTION_DESIRE_HIGH, castReason
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(botTarget, bot, radius) and Fu.IsAttacking(bot) then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
-- [OHA-MIRANA] arrow-skip: an enemy hero is teleporting within arrow range and no arrow goes,
-- with the reason (cooldown, mana, untrained, blocked). At most every 5s.
function X.LogTeleportArrowSkip(why, target)
	if DotaTime() < (bot._arrowSkipLogAt or -999) then
		return
	end
	bot._arrowSkipLogAt = DotaTime() + 5
	pcall(print, string.format(
		"[OHA-MIRANA] t=%.0f arrow-skip why=%s target=%s dist=%d mp=%.2f",
		DotaTime(),
		why,
		(string.gsub(target:GetUnitName(), "npc_dota_hero_", "")),
		math.floor(GetUnitToUnitDistance(bot, target)),
		bot:GetMana() / math.max(1, bot:GetMaxMana())
	))
end
function X.ConsiderW()
	if not sacredArrowAbility:IsFullyCastable() then
		for _, enemyHero in pairs(Fu.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE) or {}) do
			if Fu.IsValidHero(enemyHero) and enemyHero:HasModifier("modifier_teleporting") then
				local why = not sacredArrowAbility:IsTrained() and "untrained"
					or sacredArrowAbility:GetCooldownTimeRemaining() > 0 and "cooldown"
					or bot:GetMana() < sacredArrowAbility:GetManaCost() and "mana"
					or "not-castable"
				X.LogTeleportArrowSkip(why, enemyHero)
				break
			end
		end
		return 0
	end
	local arrowRange = sacredArrowAbility:GetSpecialValueInt("arrow_range")
	if arrowRange == nil or arrowRange <= 0 then
		arrowRange = sacredArrowAbility:GetCastRange()
	end
	if arrowRange == nil or arrowRange <= 0 then
		arrowRange = 3000
	end
	arrowRange = arrowRange + aetherRange
	local arrowWidth = sacredArrowAbility:GetSpecialValueInt("arrow_width")
	if arrowWidth == nil or arrowWidth <= 0 then
		arrowWidth = 115
	end
	local arrowSpeed = sacredArrowAbility:GetSpecialValueInt("arrow_speed")
	if arrowSpeed == nil or arrowSpeed <= 0 then
		arrowSpeed = 900
	end
	local castPoint = sacredArrowAbility:GetCastPoint()
	local manaCost = sacredArrowAbility:GetManaCost()
	local minUseful = 350
	local enemiesInArrowRange = Fu.GetNearbyHeroes(bot, math.min(arrowRange, 3500), true, BOT_MODE_NONE)
	local castTarget = nil

	local function arrowLoc(target)
		local dist = GetUnitToUnitDistance(bot, target)
		local travel = castPoint + dist / arrowSpeed
		return Fu.GetCorrectLoc(target, travel)
	end

	local function clearShot(target, loc)
		if X.IsEnemyUnitBetweenArrow(bot, target, loc, arrowWidth) then
			return false
		end
		return true
	end

	-- Root first so the arrow cannot be dodged. Hold the shot until the root lands.
	local function releaseArrow(target, loc)
		if X.HoldArrowForAtos(target) then
			return 0
		end
		pcall(print, string.format(
			"[OHA-MIRANA] t=%.0f arrow target=%s dist=%d mode=%d",
			DotaTime(),
			(string.gsub(target:GetUnitName(), "npc_dota_hero_", "")),
			math.floor(GetUnitToUnitDistance(bot, target)),
			bot:GetActiveMode()
		))
		return BOT_ACTION_DESIRE_HIGH, loc
	end

	-- TP interrupt / already disabled: highest priority.
	for _, enemyHero in pairs(enemiesInArrowRange) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.IsInRange(bot, enemyHero, arrowRange)
			and not Fu.IsInRange(bot, enemyHero, 80)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and not Fu.IsSuspiciousIllusion(enemyHero)
		then
			local loc = arrowLoc(enemyHero)
			if enemyHero:HasModifier("modifier_teleporting") and not clearShot(enemyHero, loc) then
				X.LogTeleportArrowSkip("blocked", enemyHero)
			end
			if clearShot(enemyHero, loc) then
				if enemyHero:HasModifier("modifier_teleporting") then
					return releaseArrow(enemyHero, loc)
				end
				if Fu.IsDisabled(enemyHero) and not Fu.IsInRange(bot, enemyHero, minUseful) then
					return releaseArrow(enemyHero, loc)
				end
			end
		end
	end

	-- Engage: lead the target when the lane/path is clear. A fight while pushing or defending
	-- counts too: at 47:40 the post-kill push floor kept her in push mode and no arrow went.
	local nearHeroes = Fu.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE) or {}
	local fighting = Fu.IsGoingOnSomeone(bot)
		or Fu.IsInTeamFight(bot, 1200)
		or (Fu.IsPushing(bot) or Fu.IsDefending(bot)) and #nearHeroes >= 1
	if fighting then
		if
			Fu.IsValidHero(botTarget)
			and Fu.IsInRange(bot, botTarget, arrowRange)
			and not Fu.IsInRange(bot, botTarget, minUseful)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not botTarget:HasModifier("modifier_abaddon_borrowed_time")
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
			and not botTarget:HasModifier("modifier_oracle_false_promise_timer")
		then
			local loc = arrowLoc(botTarget)
			if clearShot(botTarget, loc) then
				return releaseArrow(botTarget, loc)
			end
		end
		-- Secondary: any visible enemy with a clean long shot.
		for _, enemyHero in pairs(enemiesInArrowRange) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.IsInRange(bot, enemyHero, arrowRange)
				and not Fu.IsInRange(bot, enemyHero, minUseful)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
			then
				local loc = arrowLoc(enemyHero)
				if clearShot(enemyHero, loc) then
					return releaseArrow(enemyHero, loc)
				end
			end
		end
	end

	-- Free shot, in any mode: an enemy hero with a clear line (our own creeps never block; enemy
	-- and neutral units do). Game 014, 27:20-27:35: defending and retreating at full HP with
	-- enemies on our high ground, no arrow, because the rules above need a fight, a retreat
	-- under fire, or an enemy within 1600. Close enough to lead (1800), or standing / attacking /
	-- slow from further. Keeps 15% mana (30% in lane) unless defending or retreating.
	do
		-- In lane keep 30% mana for last-hit Starstorms and escape Leaps.
		local keepMana = (Fu.IsDefending(bot) or Fu.IsRetreating(bot)) and 0 or (Fu.IsLaning(bot) and 0.3 or 0.15)
		if Fu.GetManaAfter(manaCost) >= keepMana then
			local blocked = nil
			for _, enemyHero in pairs(enemiesInArrowRange) do
				if
					Fu.IsValidHero(enemyHero)
					and Fu.IsInRange(bot, enemyHero, arrowRange)
					and not Fu.IsInRange(bot, enemyHero, 600)
					and Fu.CanCastOnNonMagicImmune(enemyHero)
					and not Fu.IsSuspiciousIllusion(enemyHero)
					and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
					and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
				then
					local dist = GetUnitToUnitDistance(bot, enemyHero)
					local easy = dist <= 1800
						or enemyHero:GetCurrentMovementSpeed() < 200
						or enemyHero:IsChanneling()
						or Fu.IsAttacking(enemyHero)
						or Fu.IsDisabled(enemyHero)
					if easy then
						local loc = arrowLoc(enemyHero)
						if clearShot(enemyHero, loc) then
							pcall(print, string.format(
								"[OHA-MIRANA] t=%.0f arrow-free target=%s dist=%d",
								DotaTime(),
								(string.gsub(enemyHero:GetUnitName(), "npc_dota_hero_", "")),
								dist
							))
							return releaseArrow(enemyHero, loc)
						end
						blocked = blocked or enemyHero
					end
				end
			end
			if blocked ~= nil and DotaTime() >= (bot._arrowBlockedLogAt or -999) then
				bot._arrowBlockedLogAt = DotaTime() + 5
				pcall(print, string.format(
					"[OHA-MIRANA] t=%.0f arrow-skip why=blocked target=%s dist=%d",
					DotaTime(),
					(string.gsub(blocked:GetUnitName(), "npc_dota_hero_", "")),
					GetUnitToUnitDistance(bot, blocked)
				))
			end
		end
	end
	-- Retreat: stun chasing heroes.
	if Fu.IsRetreating(bot) and bot:WasRecentlyDamagedByAnyHero(3.0) then
		for _, enemyHero in pairs(enemiesInArrowRange) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.IsInRange(bot, enemyHero, arrowRange)
				and not Fu.IsInRange(bot, enemyHero, 200)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and (Fu.IsChasingTarget(enemyHero, bot) or bot:WasRecentlyDamagedByHero(enemyHero, 2.5))
			then
				local loc = arrowLoc(enemyHero)
				if clearShot(enemyHero, loc) then
					return releaseArrow(enemyHero, loc)
				end
			end
		end
	end

	-- Laning / mid-game poke when mana is fine and shot is clean.
	if (Fu.IsLaning(bot) or botLevel <= 12) and mpRatio > 0.45 and #nearbyAllies <= 3 then
		for _, enemyHero in pairs(enemiesInArrowRange) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.IsInRange(bot, enemyHero, math.min(arrowRange, 2200))
				and not Fu.IsInRange(bot, enemyHero, 500)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and not Fu.IsOtherAllyCanKillTarget(bot, enemyHero)
			then
				local loc = arrowLoc(enemyHero)
				if clearShot(enemyHero, loc) then
					return releaseArrow(enemyHero, loc)
				end
			end
		end
	end

	-- The first non-ancient creep hit dies outright, lane or jungle, at any travel distance.
	-- Hero shots above already had priority. Ancient creeps are not instant-killed.
	local nearEnemy = Fu.GetNearbyHeroes(bot, 1400, true, BOT_MODE_NONE)
	if
		not Fu.IsGoingOnSomeone(bot)
		and not Fu.IsRetreating(bot)
		and Fu.IsAllowedToSpam(bot, manaCost)
		and (nearEnemy == nil or #nearEnemy == 0)
	then
		local search = math.min(arrowRange, 1600)
		local function aimCreep(creep)
			if creep == nil or not Fu.IsValid(creep) or creep:IsHero() then
				return nil
			end
			if creep.IsAncientCreep ~= nil and creep:IsAncientCreep() then
				return nil
			end
			if not Fu.IsInRange(bot, creep, arrowRange) or Fu.IsInRange(bot, creep, 80) then
				return nil
			end
			if Fu.IsOtherAllysTarget(creep) then
				return nil
			end
			local loc = creep:GetLocation()
			if X.IsEnemyUnitBetweenArrow(bot, creep, loc, arrowWidth) then
				return nil
			end
			return loc
		end
		if Fu.IsLaning(bot) or Fu.IsFarming(bot) or Fu.IsPushing(bot) or Fu.IsDefending(bot) then
			local lane = bot:GetNearbyLaneCreeps(search, true)
			local siege, ranged, fat
			for _, creep in pairs(lane or {}) do
				if Fu.IsValid(creep) and not creep:IsHero() then
					local far = not Fu.IsInRange(bot, creep, bot:GetAttackRange() + 80)
					if Fu.IsKeyWordUnit("siege", creep) then
						if siege == nil or creep:GetHealth() > siege:GetHealth() then
							siege = creep
						end
					elseif Fu.IsKeyWordUnit("ranged", creep) and far then
						if ranged == nil or creep:GetHealth() > ranged:GetHealth() then
							ranged = creep
						end
					elseif far and creep:GetHealth() >= 400 and (fat == nil or creep:GetHealth() > fat:GetHealth()) then
						fat = creep
					end
				end
			end
			local loc = aimCreep(siege)
			if loc == nil then
				loc = aimCreep(ranged)
			end
			if loc == nil then
				loc = aimCreep(fat)
			end
			if loc ~= nil then
				return BOT_ACTION_DESIRE_HIGH, loc
			end
		end
		if Fu.IsFarming(bot) or Fu.IsPushing(bot) or (not Fu.IsLaning(bot) and DotaTime() > 3 * 60) then
			-- Arrow kills a non-ancient creep outright (Valve data), so spend it on a large camp,
			-- the biggest creep there. It went on small-camp creeps before.
			local neutrals = bot:GetNearbyNeutralCreeps(search)
			local spawners = GetNeutralSpawners() or {}
			local function CampType(creep)
				local best, bestDist = nil, 900
				for _, spawner in pairs(spawners) do
					if spawner.location ~= nil then
						local spawnerDist = GetUnitToLocationDistance(creep, spawner.location)
						if spawnerDist < bestDist then
							best, bestDist = spawner.type, spawnerDist
						end
					end
				end
				return best
			end
			local best, bestHp = nil, 0
			for _, creep in pairs(neutrals or {}) do
				if
					Fu.IsValid(creep)
					and not creep:IsHero()
					and (creep.IsAncientCreep == nil or not creep:IsAncientCreep())
					and creep:GetMaxHealth() > bestHp
					and CampType(creep) == "large"
				then
					best = creep
					bestHp = creep:GetMaxHealth()
				end
			end
			-- Not on one an attack or two would finish anyway.
			if best ~= nil and bestHp >= 450 and best:GetHealth() >= 300 then
				local loc = aimCreep(best)
				if loc ~= nil then
					return BOT_ACTION_DESIRE_HIGH, loc
				end
			end
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if Fu.IsRoshan(botTarget) and Fu.IsInRange(bot, botTarget, arrowRange) and not Fu.IsInRange(bot, botTarget, 300) then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(botTarget, bot, arrowRange) and Fu.IsAttacking(bot) then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.HoldArrowForAtos(target)
	if not Fu.IsValidHero(target) or Fu.IsDisabled(target) or target:IsRooted() then
		return false
	end
	local slot = bot:FindItemSlot("item_rod_of_atos")
	if slot < 0 or slot > 5 then
		return false
	end
	local item = bot:GetItemInSlot(slot)
	if item == nil or item:IsNull() then
		return false
	end
	if not Fu.CanCastOnNonMagicImmune(target) or not Fu.CanCastOnTargetAdvanced(target) then
		return false
	end
	local range = 1100 + (aetherRange or 0)
	local castRange = item:GetCastRange()
	if type(castRange) == "number" and castRange > 200 then
		range = castRange + (aetherRange or 0)
	end
	if GetUnitToUnitDistance(bot, target) > range then
		return false
	end
	if item:IsFullyCastable() then
		bot:Action_UseAbilityOnEntity(item, target)
		X._heldArrow = true
		return true
	end
	local cd = item:GetCooldown()
	local remain = item:GetCooldownTimeRemaining()
	-- Atos was just thrown. Wait for the root instead of firing the arrow over it.
	if type(cd) == "number" and type(remain) == "number" and cd > 0 and remain > cd - 2.5 then
		X._heldArrow = true
		return true
	end
	return false
end
function X.LeapReady()
	if leapAbility == nil or leapAbility:IsNull() or leapAbility:IsHidden() or not leapAbility:IsTrained() or not leapAbility:IsActivated() then
		return false
	end
	if bot:GetMana() < leapAbility:GetManaCost() then
		return false
	end
	-- Leap has 2 charges (Valve data, no Shard needed). Castable means a charge is left; the
	-- old Shard-only branch read GetCurrentCharges, which is documented for items only.
	return leapAbility:IsFullyCastable()
end
function X.ConsiderE()
	if not X.LeapReady() or bot:IsRooted() then
		return 0
	end
	local abilityLevel = leapAbility:GetLevel()
	local leapDistance = leapAbility:GetSpecialValueInt("leap_distance")
	local attackRange = bot:GetAttackRange()
	local castPoint = leapAbility:GetCastPoint()
	local manaCost = leapAbility:GetManaCost()
	local damage = 0
	local damageType = DAMAGE_TYPE_MAGICAL
	local closeEnemies = Fu.GetAroundEnemyHeroList(800)
	local enemiesInRange = Fu.GetAroundEnemyHeroList(1200)
	local castTarget = nil
	local castReason = nil
	-- Chase: Leap goes 650 the way she faces and gives attack/move speed for 5s (Valve data). It
	-- used to need the target 620-1380 away and facing within 6 degrees, so a target running
	-- just ahead never got leapt on (5:00, game 014). Now: where she lands is checked against
	-- where the target will be, and a fleeing target inside 620 counts too.
	local chaseWhy = nil
	if Fu.IsGoingOnSomeone(bot) and Fu.IsValidHero(botTarget) and Fu.IsInRange(bot, botTarget, leapDistance + attackRange + 300) then
		local fleeing = not botTarget:IsFacingLocation(bot:GetLocation(), 90)
		local dist = GetUnitToUnitDistance(bot, botTarget)
		local face = bot:GetFacing() * math.pi / 180
		local me = bot:GetLocation()
		local land = Vector(me.x + math.cos(face) * leapDistance, me.y + math.sin(face) * leapDistance, me.z)
		local there = botTarget:GetExtrapolatedLocation(0.6)
		local landDist = math.sqrt((land.x - there.x) ^ 2 + (land.y - there.y) ^ 2)
		-- Game 031: one leap brought her next to the target, the next one carried her past him (650
		-- forward, wherever he is) and a third brought her back: two charges wasted. No chase leap
		-- with the target already in attack range, unless the landing is at least 150 closer than
		-- she is now, or within 3s of the last chase leap (its speed bonus lasts 5s).
		if botTarget:IsAttackImmune() or not Fu.CanCastOnMagicImmune(botTarget) then
			chaseWhy = "target-immune"
		elseif dist <= attackRange + 50 then
			chaseWhy = "in-attack-range"
		elseif DotaTime() - (bot._chaseLeapAt or -999) < 3 then
			chaseWhy = "recent-leap"
		elseif landDist > dist - 150 then
			chaseWhy = string.format("no-gain(%d->%d)", dist, landDist)
		elseif landDist > attackRange - 80 then
			chaseWhy = string.format("lands-far(%d)", landDist)
		elseif dist < leapDistance - 30 and not fleeing then
			chaseWhy = "close-not-fleeing"
		end
		-- Logged again (the other Mirana lines stay off) while this rule is new.
		if chaseWhy ~= nil and DotaTime() >= (bot._leapChaseLogAt or -999) then
			bot._leapChaseLogAt = DotaTime() + 5
			pcall(_G.print, string.format(
				"[OHA-MIRANA] t=%.0f leap-skip why=chase-%s target=%s dist=%d",
				DotaTime(),
				chaseWhy,
				(string.gsub(botTarget:GetUnitName(), "npc_dota_hero_", "")),
				dist
			))
		end
	end
	if Fu.IsGoingOnSomeone(bot) and chaseWhy == nil then
		if Fu.IsValidHero(botTarget) and Fu.IsInRange(bot, botTarget, leapDistance + attackRange + 300) then
			local enemiesNearTarget = Fu.GetNearbyHeroes(botTarget, 900, false, BOT_MODE_NONE)
			local alliesNearTarget = Fu.GetNearbyHeroes(botTarget, 1300, true, BOT_MODE_NONE)
			local aliveEnemyCount = Fu.GetNumOfAliveHeroes(true)
			if
				aliveEnemyCount <= 2
				or #enemiesNearTarget <= 1
				or #enemiesNearTarget <= #alliesNearTarget
				or Fu.WillKillTarget(botTarget, bot:GetAttackDamage() * 3, DAMAGE_TYPE_PHYSICAL, 2.0)
			then
				castTarget = botTarget
				castReason = "E-进攻:" .. Fu.Chat.GetNormName(castTarget)
				bot._chaseLeapAt = DotaTime()
				pcall(_G.print, string.format(
					"[OHA-MIRANA] t=%.0f leap why=chase target=%s dist=%d",
					DotaTime(),
					(string.gsub(botTarget:GetUnitName(), "npc_dota_hero_", "")),
					GetUnitToUnitDistance(bot, botTarget)
				))
				return BOT_ACTION_DESIRE_HIGH, castTarget, castReason
			end
		end
	end
	if Fu.IsStuck(bot) then
		castTarget = bot
		castReason = "E-被卡住"
		return BOT_ACTION_DESIRE_HIGH, castTarget, castReason
	end
	-- Escape. Also out of retreat mode when low and outnumbered: at 31:14 (game 014) she had both
	-- charges, 27% HP and three enemies on her, but was not in retreat mode, so no Leap.
	local lowAndOutnumbered = Fu.GetHP(bot) < 0.4 and #enemiesInRange >= 2
	if (Fu.IsRetreating(bot) or lowAndOutnumbered) and bot:WasRecentlyDamagedByAnyHero(3.0) then
		local why = #closeEnemies == 0 and "no-enemy-in-800" or "facing-enemy"
		-- Judge the landing spot (650 along her facing) against every enemy unit near her, illusions
		-- included: farther from the closest one, farther from their centre, and no more of them
		-- around it. It used to be enough to face away from one enemy: at 7:30 (game 016) she
		-- leapt out from Phantom Lancer, then 2s later "away from" one Lancer straight into the
		-- others.
		if #closeEnemies > 0 then
			local foes = {}
			for _, enemyHero in pairs(GetUnitList(UNIT_LIST_ENEMY_HEROES) or {}) do
				if Fu.IsValid(enemyHero) and enemyHero:IsAlive() and GetUnitToUnitDistance(bot, enemyHero) <= 1400 then
					foes[#foes + 1] = enemyHero
				end
			end
			local me = bot:GetLocation()
			local face = bot:GetFacing() * math.pi / 180
			local land = Vector(me.x + math.cos(face) * leapDistance, me.y + math.sin(face) * leapDistance, me.z)
			local function Closest(point)
				local best = math.huge
				for _, foe in ipairs(foes) do
					local foeLocation = foe:GetLocation()
					best = math.min(best, math.sqrt((foeLocation.x - point.x) ^ 2 + (foeLocation.y - point.y) ^ 2))
				end
				return best
			end
			local function Around(point)
				local count = 0
				for _, foe in ipairs(foes) do
					local foeLocation = foe:GetLocation()
					if (foeLocation.x - point.x) ^ 2 + (foeLocation.y - point.y) ^ 2 <= 600 * 600 then
						count = count + 1
					end
				end
				return count
			end
			local center = Fu.GetCenterOfUnits(foes)
			local fromCenterNow = math.sqrt((me.x - center.x) ^ 2 + (me.y - center.y) ^ 2)
			local fromCenterLand = math.sqrt((land.x - center.x) ^ 2 + (land.y - center.y) ^ 2)
			if
				IsLocationPassable(land)
				and Closest(land) > Closest(me) + 200
				and fromCenterLand > fromCenterNow + 300
				and Around(land) <= Around(me)
			then
				castTarget = closeEnemies[1]
				castReason = "E-逃跑"
				pcall(print, string.format(
					"[OHA-MIRANA] t=%.0f leap why=escape foes=%d closest=%d->%d hp=%.2f",
					DotaTime(),
					#foes,
					math.floor(Closest(me)),
					math.floor(Closest(land)),
					Fu.GetHP(bot)
				))
				return BOT_ACTION_DESIRE_HIGH, castTarget, castReason
			end
		end
		-- Facing them while low: turn away first (Leap goes the way she faces); the next think
		-- leaps once she faces away.
		if why == "facing-enemy" and Fu.GetHP(bot) < 0.4 then
			local center = Fu.GetCenterOfUnits(closeEnemies)
			local me = bot:GetLocation()
			local dx, dy = me.x - center.x, me.y - center.y
			local len = math.sqrt(dx * dx + dy * dy)
			if len < 1 then
				local fountain = GetTeam() == TEAM_RADIANT and Vector(-7172, -6652, 0) or Vector(6982, 6422, 0)
				dx, dy = fountain.x - me.x, fountain.y - me.y
				len = math.max(1, math.sqrt(dx * dx + dy * dy))
			end
			if DotaTime() >= (bot._leapTurnLogAt or -999) then
				bot._leapTurnLogAt = DotaTime() + 3
				pcall(print, string.format(
					"[OHA-MIRANA] t=%.0f leap-turn enemies800=%d hp=%.2f",
					DotaTime(),
					#closeEnemies,
					Fu.GetHP(bot)
				))
			end
			return BOT_ACTION_DESIRE_HIGH, Vector(me.x + dx / len * 300, me.y + dy / len * 300, me.z), "turn"
		end
		-- Retreating under fire without a Leap: say why (no enemy hero within 800, or not yet
		-- turned away; Leap goes the way she faces). At most every 5s.
		if DotaTime() >= (bot._leapSkipLogAt or -999) then
			bot._leapSkipLogAt = DotaTime() + 5
			pcall(print, string.format(
				"[OHA-MIRANA] t=%.0f leap-skip why=%s enemies1200=%d hp=%.2f",
				DotaTime(),
				why,
				#enemiesInRange,
				Fu.GetHP(bot)
			))
		end
	end
	if Fu.IsFarming(bot) and botLevel >= 12 then
		if
			botTarget ~= nil
			and botTarget:IsAlive()
			and Fu.IsInRange(bot, botTarget, leapDistance + attackRange + 400)
			and not Fu.IsInRange(bot, botTarget, 1080)
			and bot:IsFacingLocation(botTarget:GetLocation(), 6)
		then
			castTarget = botTarget:GetLocation()
			castReason = "E-打钱赶路"
			return BOT_ACTION_DESIRE_HIGH, castTarget, castReason
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderR()
	if not moonlightShadowAbility:IsFullyCastable() then
		return 0
	end
	local abilityLevel = moonlightShadowAbility:GetLevel()
	local castRange = moonlightShadowAbility:GetCastRange()
	local radius = 600
	local castPoint = moonlightShadowAbility:GetCastPoint()
	local manaCost = moonlightShadowAbility:GetManaCost()
	local damage = moonlightShadowAbility:GetSpecialValueInt("dam")
	local damageType = DAMAGE_TYPE_MAGICAL
	local enemiesInRange = Fu.GetAroundEnemyHeroList(castRange)
	local enemiesInExtendedRange = Fu.GetAroundEnemyHeroList(castRange + 200)
	local castTarget = nil
	local castReason = nil
	for i = 1, #GetTeamPlayers(GetTeam()) do
		local teamMember = GetTeamMember(i)
		if teamMember ~= nil and teamMember:IsAlive() and not teamMember:IsInvisible() then
			if Fu.IsGoingOnSomeone(teamMember) then
				local memberTarget = Fu.GetProperTarget(teamMember)
				if Fu.IsValidHero(memberTarget) and not Fu.IsInRange(teamMember, memberTarget, 1600) and Fu.IsInRange(teamMember, memberTarget, 2800) then
					local alliesNearMember = Fu.GetAlliesNearLoc(teamMember:GetLocation(), 1000)
					if #alliesNearMember >= 2 then
						castTarget = teamMember
						castReason = "R-潜行准备进攻的队友:" .. Fu.Chat.GetNormName(castTarget)
						return BOT_ACTION_DESIRE_HIGH, castTarget, castReason
					end
				end
			end
			if Fu.IsRetreating(teamMember) then
				local memberNearbyEnemies = Fu.GetNearbyHeroes(teamMember, 900, true, BOT_MODE_NONE)
				for _, enemyHero in pairs(memberNearbyEnemies) do
					if teamMember:WasRecentlyDamagedByHero(enemyHero, 3.0) then
						castTarget = teamMember
						castReason = "R-隐身撤退的队友:" .. Fu.Chat.GetNormName(castTarget)
						return BOT_ACTION_DESIRE_HIGH, castTarget, castReason
					end
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.IsEnemyCreepBetweenEnemyHero(caster, target, width)
	return X.IsEnemyUnitBetweenArrow(caster, target, target:GetLocation(), width)
end

-- Sacred Arrow only collides with enemy units (not allies).
function X.IsEnemyUnitBetweenArrow(caster, target, aimLoc, width)
	local origin = caster:GetLocation()
	local dest = aimLoc or target:GetLocation()
	local radius = (width or 115) + 25

	local function blocks(unit)
		if not Fu.IsValid(unit) or unit == target or unit == caster then
			return false
		end
		if unit:GetTeam() == caster:GetTeam() then
			return false
		end
		-- No IsBarracks / IsFort in the bot API ("attempt to call method IsBarracks", game 018);
		-- IsBuilding covers towers, barracks and the Ancient.
		if unit:IsBuilding() or unit:IsTower() then
			return false
		end
		local name = unit:GetUnitName()
		if string.find(name, "ward") or string.find(name, "tome") then
			return false
		end
		local hit = PointToLineDistance(origin, dest, unit:GetLocation())
		if hit ~= nil and hit.within and hit.distance <= radius + unit:GetBoundingRadius() then
			-- Only block if the blocker is closer than the intended target.
			if GetUnitToLocationDistance(caster, unit:GetLocation()) < GetUnitToLocationDistance(caster, dest) - 30 then
				return true
			end
		end
		return false
	end

	local creeps = caster:GetNearbyCreeps(1600, true)
	for _, creep in pairs(creeps) do
		if blocks(creep) then
			return true
		end
	end
	if target ~= nil and target.GetNearbyCreeps ~= nil then
		local nearTarget = target:GetNearbyCreeps(1200, false)
		if nearTarget then
			for _, creep in pairs(nearTarget) do
				if blocks(creep) then
					return true
				end
			end
		end
	end
	local enemies = Fu.GetNearbyHeroes(caster, 1600, true, BOT_MODE_NONE)
	for _, hero in pairs(enemies) do
		if blocks(hero) then
			return true
		end
	end
	return false
end
function X.ConsiderCelestialQuiver()
	if not Fu.CanCastAbility(celestialQuiverAbility) or bot:IsDisarmed() then
		return BOT_ACTION_DESIRE_NONE
	end
	local bonusDamage = celestialQuiverAbility:GetSpecialValueInt("bonus_damage")
	local isAutoCastOn = celestialQuiverAbility:GetAutoCastState()
	local enemiesInRange = bot:GetNearbyHeroes(bot:GetAttackRange() + 300, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(enemiesInRange) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanBeAttacked(enemyHero)
			and Fu.IsInRange(bot, enemyHero, bot:GetAttackRange() + 150)
			and not Fu.IsSuspiciousIllusion(enemyHero)
			and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
			and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
			and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
			and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
			and not enemyHero:HasModifier("modifier_templar_assassin_refraction_absorb")
		then
			if
				Fu.WillKillTarget(enemyHero, bot:GetAttackDamage() + bonusDamage, DAMAGE_TYPE_MAGICAL, bot:GetAttackSpeed())
				and not Fu.WillKillTarget(enemyHero, bot:GetAttackDamage(), DAMAGE_TYPE_PHYSICAL, bot:GetAttackSpeed())
			then
				return BOT_ACTION_DESIRE_HIGH, enemyHero
			end
		end
	end
	local harass = false
	for _, enemyHero in pairs(enemiesInRange) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanBeAttacked(enemyHero)
			and Fu.IsInRange(bot, enemyHero, bot:GetAttackRange() + 150)
			and not Fu.IsSuspiciousIllusion(enemyHero)
			and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
			and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
			and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
			and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
			and not enemyHero:HasModifier("modifier_templar_assassin_refraction_absorb")
		then
			harass = true
			break
		end
	end
	-- Mid game onward the orb stays on. Early, it stays on only while a hero is in attack range.
	if not Fu.IsEarlyGame() or (harass and mpRatio ~= nil and mpRatio > 0.35) then
		if not isAutoCastOn then
			celestialQuiverAbility:ToggleAutoCast()
		end
		return BOT_ACTION_DESIRE_NONE
	end
	local nearbyCreeps = bot:GetNearbyCreeps(Min(bot:GetAttackRange() + 300, 1600), true)
	if Fu.IsLaning(bot) then
		for _, creep in pairs(nearbyCreeps) do
			if
				Fu.IsValid(creep)
				and Fu.CanBeAttacked(creep)
				and Fu.IsKeyWordUnit("ranged", creep)
				and not Fu.CanKillTarget(creep, bot:GetAttackDamage(), DAMAGE_TYPE_PHYSICAL)
			then
				local aoeLocation = bot:FindAoELocation(true, true, creep:GetLocation(), 0, 650, 0, 0)
				if Fu.WillKillTarget(creep, bot:GetAttackDamage() + bonusDamage, DAMAGE_TYPE_MAGICAL, bot:GetAttackSpeed()) then
					if aoeLocation.count > 0 or Fu.IsUnitTargetedByTower(creep, false) or Fu.IsEnemyTargetUnit(creep, 1200) then
						return BOT_ACTION_DESIRE_HIGH, creep
					end
				end
			end
		end
	end
	if isAutoCastOn then
		celestialQuiverAbility:ToggleAutoCast()
	end
	return BOT_ACTION_DESIRE_NONE
end
return X
