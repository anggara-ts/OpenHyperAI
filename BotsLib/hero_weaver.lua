-- Weaver: skill build, item build, and ability use for this hero.
local X = {}
local bot = GetBot()
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local AbilityContext = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local WeaverRules = require(GetScriptDirectory() .. "/FuncLib/systems/weaver_rules")
local Minion = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local sTalentList = Fu.Skill.GetTalentList(bot)
local sAbilityList = Fu.Skill.GetAbilityList(bot)
local sRole = Fu.Item.GetRoleItemsBuyList(bot)
local tTalentTreeList = { ["t25"] = { 10, 0 }, ["t20"] = { 0, 10 }, ["t15"] = { 0, 10 }, ["t10"] = { 10, 0 } }
local tAllAbilityBuildList = { { 2, 3, 1, 2, 2, 6, 2, 3, 3, 3, 6, 1, 1, 1, 6 } }
local nAbilityBuildList = Fu.Skill.GetRandomBuild(tAllAbilityBuildList)
local nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList)
local sCarryItem = RandomInt(1, 2) == 1 and "item_butterfly" or "item_monkey_king_bar"
local sRoleItemsBuyList = {}
-- No Aghanim's Scepter in this list (maintainer, 2026-11-20): the ally Time Lapse (weaver_time_lapse_ally, game
-- files: IsGrantedByScepter) is not a core pick and the six slots are full without it (Treads, Desolator, Pike,
-- Linken's, Daedalus, Satanic, then Butterfly or MKB). It sat after Magic Wand for the test games only (game
-- 051: 4 ally rewinds, 3 of those allies lived). The Blessing at the end still gives the effect without a slot.
sRoleItemsBuyList["pos_1"] = {
	-- Stratz 7.41f, week of 9 Nov 2026: pos 1, 41,730 matches (Util/item-builds/generate.js).
	"item_tango",
	"item_double_branches",
	"item_circlet",
	"item_faerie_fire",
	"item_slippers",
	"item_wraith_band",
	"item_magic_wand",
	"item_falcon_blade",
	"item_power_treads",
	"item_desolator",
	"item_dragon_lance",
	"item_aghanims_shard",
	"item_lesser_crit",
	"item_black_king_bar",
	"item_greater_crit",
	sCarryItem,
	"item_travel_boots",
	"item_moon_shard",
	"item_hurricane_pike",
	"item_ultimate_scepter_2",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 2, 13,889 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_2"] = {
	"item_tango",
	"item_double_branches",
	"item_circlet",
	"item_slippers",
	"item_wraith_band",
	"item_magic_wand",
	"item_falcon_blade",
	"item_power_treads",
	"item_desolator",
	"item_dragon_lance",
	"item_pers",
	"item_aghanims_shard",
	"item_lesser_crit",
	"item_sphere",
	"item_greater_crit",
	sCarryItem,
	"item_travel_boots",
	"item_moon_shard",
	"item_hurricane_pike",
	"item_ultimate_scepter_2",
}
-- Support Weaver (#38): its own list, it was a copy of the carry list. Stratz 7.41f, week to 11 Nov 2026, pos 4
-- (21,846 matches) / pos 5 (9,450): Urn of Shadows 83% / 78%, Magic Wand 72% / 70%, Blood Grenade 67% / 66%,
-- Spirit Vessel 65% / 61%, Circlet 57% / 53%, Magic Stick 50% / 50%, Perseverance 42% / 40% (Linken's Sphere
-- 24% / 24%), Power Treads 29% / 32% (the most bought boots), Desolator 29% / 32%, Orchid 27% / 25%, Aghanim's
-- Shard 20% / 21%, Aghanim's Scepter 18% / 19% (1% on pos 1; it gives the ally Time Lapse), Bloodthorn 8% / 7%.
-- Stratz 7.41f, week of 9 Nov 2026: pos 4, 25,362 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_4"] = {
	"item_tango",
	"item_blood_grenade",
	"item_branches",
	"item_circlet",
	"item_magic_stick",
	"item_magic_wand",
	"item_urn_of_shadows",
	"item_spirit_vessel",
	"item_power_treads",
	"item_aghanims_shard",
	"item_ultimate_scepter",
	"item_black_king_bar",
	"item_cyclone",
	"item_maelstrom",
	"item_ultimate_scepter_2",
	"item_sheepstick",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 5, 11,197 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_5"] = {
	"item_tango",
	"item_blood_grenade",
	"item_branches",
	"item_circlet",
	"item_magic_stick",
	"item_magic_wand",
	"item_urn_of_shadows",
	"item_power_treads",
	"item_spirit_vessel",
	"item_desolator",
	"item_aghanims_shard",
	"item_ultimate_scepter",
	"item_black_king_bar",
	"item_rod_of_atos",
	"item_ultimate_scepter_2",
	"item_lotus_orb",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 3, 8,346 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_3"] = {
	"item_tango",
	"item_double_branches",
	"item_circlet",
	"item_magic_stick",
	"item_wraith_band",
	"item_magic_wand",
	"item_falcon_blade",
	"item_power_treads",
	"item_desolator",
	"item_pers",
	"item_dragon_lance",
	"item_aghanims_shard",
	"item_sphere",
	"item_greater_crit",
	sCarryItem,
	"item_travel_boots",
	"item_moon_shard",
	"item_hurricane_pike",
	"item_ultimate_scepter_2",
}
X["sBuyList"] = sRoleItemsBuyList[sRole]
X["sSellList"] = {
	"item_black_king_bar",
	"item_quelling_blade",
	-- Sold once the item before it is owned, to keep six slots (Util/item-builds/generate.js):
	"item_butterfly",
	"item_falcon_blade",
	"item_monkey_king_bar",
	"item_falcon_blade",
}
if Fu.Role.IsPvNMode() or Fu.Role.IsAllShadow() then
	X["sBuyList"], X["sSellList"] = { "PvN_antimage" }, {}
end
nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"] =
	Fu.SetUserHeroInit(nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"])
X["sSkillList"] = Fu.Skill.GetSkillList(sAbilityList, nAbilityBuildList, sTalentList, nTalentBuildList)
X["bDeafaultAbility"] = false
X["bDeafaultItem"] = false
function X.MinionThink(hMinionUnit)
	Minion.MinionThink(hMinionUnit)
end
local theSwarmAbility = SafeAbility(bot:GetAbilityByName("weaver_the_swarm"), "weaver_the_swarm", "weaver")
local shukuchiAbility = SafeAbility(bot:GetAbilityByName("weaver_shukuchi"), "weaver_shukuchi", "weaver")
local timeLapseAbility = SafeAbility(bot:GetAbilityByName("weaver_time_lapse"), "weaver_time_lapse", "weaver")
-- 7.42: the Aghanim's Scepter ally cast is its own ability (cast range 500, cooldown shared with Time
-- Lapse); weaver_time_lapse is self-only (Valve datafeed, patch notes).
local timeLapseAllyAbility =
	SafeAbility(bot:GetAbilityByName("weaver_time_lapse_ally"), "weaver_time_lapse_ally", "weaver")
-- Geminate Attack is an autocast attack ability in the current game files (AUTOCAST | ATTACK);
-- nothing in this script turned it on, so the second attack depended on the default state.
local geminateAttackAbility = bot:GetAbilityByName("weaver_geminate_attack")
-- [OHA-WEAVER] lines: throttled per reason, at most once per 5s.
function X.LogWeaver(reason, format, ...)
	bot._weaverLogAt = bot._weaverLogAt or {}
	if DotaTime() < (bot._weaverLogAt[reason] or -999) then
		return
	end
	bot._weaverLogAt[reason] = DotaTime() + 5
	pcall(print, string.format("[OHA-WEAVER] t=%.0f " .. reason .. " " .. format, DotaTime(), ...))
end
-- Once-per-event lines (an escape's end and result, a death), not throttled, at game time t.
function X.PrintWeaver(t, reason, format, ...)
	pcall(print, string.format("[OHA-WEAVER] t=%.0f " .. reason .. " " .. format, t, ...))
end
-- HP fractions over the last 6s, sampled every 0.5s, for Weaver and every allied hero within 1200 (Time Lapse
-- gives back the HP of 5s ago; the ally version needs the ally's history).
function X.TrackHp()
	local now = DotaTime()
	bot._lapseHp = bot._lapseHp or {}
	if now - (bot._lapseHpAt or -99) < 0.5 then
		return
	end
	bot._lapseHpAt = now
	local units = { bot }
	for _, allyHero in pairs(bot:GetNearbyHeroes(1200, false, BOT_MODE_NONE) or {}) do
		if Fu.IsValidHero(allyHero) and allyHero ~= bot and not allyHero:IsIllusion() then
			units[#units + 1] = allyHero
		end
	end
	for _, unit in ipairs(units) do
		local playerId = unit:GetPlayerID()
		local history = bot._lapseHp[playerId] or {}
		bot._lapseHp[playerId] = history
		history[#history + 1] = { now, Fu.GetHP(unit) }
		while #history > 0 and now - history[1][1] > 6 do
			table.remove(history, 1)
		end
	end
end
-- HP fraction about 5s ago; the current HP when there is no history yet.
function X.HpFiveSecondsAgo(unit)
	unit = unit or bot
	local history = bot._lapseHp and bot._lapseHp[unit:GetPlayerID()] or nil
	local now = DotaTime()
	for _, sample in ipairs(history or {}) do
		if now - sample[1] <= 5.2 then
			return sample[2]
		end
	end
	return Fu.GetHP(unit)
end
-- Time Lapse on burst (#103, maintainer's rule, game 050 38:50: Ringmaster went 61% -> 9% in 3.5s beside her and the
-- ally rule, which wanted a retreating core and Weaver above 75%, could not pick him). Burst = 30%+ of max HP lost
-- in the last 5s, now under 40%, hit by a hero in the last 1.5s (or under 20% after losing 15%+). Any mode, any
-- role; never a channelling hero (the rewind would cut the channel). Self and allies are judged alike; with
-- several, cores first by position (1, 2, 3, then 4, 5), then the bigger loss. Game files: the ally version
-- (weaver_time_lapse_ally) comes with Aghanim's Scepter, 500 cast range, and shares the cooldown.
function X.LapseCandidate(unit)
	if not Fu.IsValidHero(unit) or unit:IsIllusion() or unit:IsChanneling() then
		return nil
	end
	local hpNow = Fu.GetHP(unit)
	local lost = X.HpFiveSecondsAgo(unit) - hpNow
	if
		unit:WasRecentlyDamagedByAnyHero(1.5)
		and (hpNow < 0.4 and lost >= 0.3 or hpNow < 0.2 and lost >= 0.15)
		and not unit:HasModifier("modifier_necrolyte_reapers_scythe")
	then
		return { unit = unit, hp = hpNow, lost = lost, pos = Fu.GetPosition(unit) or 5 }
	end
	return nil
end
function X.ConsiderTimeLapse()
	local candidates = {}
	if timeLapseAbility:IsFullyCastable() then
		candidates[#candidates + 1] = X.LapseCandidate(bot)
	end
	if bot:HasScepter() and timeLapseAllyAbility:IsFullyCastable() then
		local castRange = timeLapseAllyAbility:GetCastRange()
		for _, allyHero in pairs(bot:GetNearbyHeroes(math.max(castRange, 500), false, BOT_MODE_NONE) or {}) do
			if allyHero ~= bot then
				candidates[#candidates + 1] = X.LapseCandidate(allyHero)
			end
		end
	end
	if #candidates == 0 then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	table.sort(candidates, function(lhs, rhs)
		if lhs.pos ~= rhs.pos then
			return lhs.pos < rhs.pos
		end
		return lhs.lost > rhs.lost
	end)
	local pick = candidates[1]
	X.LogWeaver(
		"lapse",
		"target=%s pos=%d hp=%.2f hp5=%.2f candidates=%d",
		pick.unit == bot and "self" or (string.gsub(pick.unit:GetUnitName(), "npc_dota_hero_", "")),
		pick.pos,
		pick.hp,
		pick.hp + pick.lost,
		#candidates
	)
	return BOT_ACTION_DESIRE_HIGH, pick.unit == bot and "self" or pick.unit
end
local theSwarmDesire, theSwarmLocation
local shukuchiDesire
local timeLapseDesire
local botTarget
if bot.tryShukuchiKill == nil then
	bot.tryShukuchiKill = false
end
if bot.ShukuchiKillTarget == nil then
	bot.ShukuchiKillTarget = nil
end
local isRetreating
local isAttacking
local hpRatio
local mpRatio
function X.SkillsComplement()
	-- Sample HP before the early return so the 5s history has no gaps while stunned.
	pcall(X.TrackHp)
	if
		geminateAttackAbility ~= nil
		and not geminateAttackAbility:IsNull()
		and geminateAttackAbility:IsTrained()
		and not geminateAttackAbility:GetAutoCastState()
	then
		geminateAttackAbility:ToggleAutoCast()
		X.LogWeaver("geminate-autocast-on", "")
	end
	-- Read before the early return: the escape bookkeeping and the skip log below use them.
	isRetreating = Fu.IsRetreating(bot)
	isAttacking = Fu.IsAttacking(bot)
	hpRatio = Fu.GetHP(bot)
	mpRatio = Fu.GetMP(bot)
	botTarget = Fu.GetProperTarget(bot)
	pcall(X.WatchShukuchi)
	if Fu.CanNotUseAbility(bot) then
		pcall(X.LogEscapeBlocked)
		return
	end
	-- Grace of 0.5s after the cast so the flag is not cleared before the buff shows up.
	if not bot:HasModifier("modifier_weaver_shukuchi") and DotaTime() - (bot.ShukuchiKillAt or -99) > 0.5 then
		bot.tryShukuchiKill = false
	end
	local timeLapseTarget
	timeLapseDesire, timeLapseTarget = X.ConsiderTimeLapse()
	if timeLapseDesire > 0 then
		-- Time Lapse stays first (it gives the HP back); an escape-end line says whether it was cast during the escape.
		if bot._shukuchiEscape ~= nil then
			bot._shukuchiEscape.lapse = true
		end
		if timeLapseTarget == "self" then
			bot:Action_UseAbility(timeLapseAbility)
		else
			if bot:HasScepter() then
				bot:Action_UseAbilityOnEntity(timeLapseAllyAbility, timeLapseTarget)
			end
		end
		return
	end
	-- Escape Shukuchi (#48): the first hit ends the invisibility, so while it lasts she only walks to the fountain, in
	-- every mode. Game 063: 7 of 9 escapes ended 1-2s after the cast, 8 of them cast in retreat mode, where this
	-- block fell through to the rest of the script: The Swarm's retreat cast has the same trigger as the escape
	-- (one beetle shows in the log, t=289 after the t=280 escape); what ended the others is not logged. The
	-- retreat mode holds its desire above every other mode while the escape lasts (mode_retreat_generic.lua) and
	-- item use waits (ability_item_usage_generic.lua, Usage.WillBreakInvisible). X.WatchShukuchi detects the end.
	if bot._shukuchiEscape ~= nil and bot:HasModifier("modifier_weaver_shukuchi") then
		bot:Action_MoveToLocation(Fu.GetTeamFountain())
		return
	end
	-- Chase Shukuchi (#48, maintainer): stopping at attack range left the target at the edge, and the first hit (which
	-- ends the invisibility) let him walk out again. While it lasts, go through him to a point 150 past (Shukuchi's
	-- damage lands on the way), then attack. Attack at once when the right-clicks in the time left kill him.
	do
		local chase = bot._shukuchiChase
		if chase ~= nil then
			local target = chase.target
			if
				DotaTime() > chase.untilTime
				or isRetreating
				or not bot:HasModifier("modifier_weaver_shukuchi") and DotaTime() > chase.untilTime - 3.5
				or not Fu.IsValidHero(target)
				or not target:IsAlive()
			then
				bot._shukuchiChase = nil
			else
				local timeLeft = math.max(0.5, chase.untilTime - DotaTime())
				local hitKill = (bot:GetEstimatedDamageToTarget(true, target, timeLeft, DAMAGE_TYPE_PHYSICAL) or 0)
					>= target:GetHealth()
				local dist = GetUnitToUnitDistance(bot, target)
				if hitKill or dist <= 120 then
					bot._shukuchiChase = nil
					X.LogWeaver(
						"shukuchi-chase",
						"target=%s through=%s dist=%d",
						target:GetUnitName(),
						hitKill and "attack-kill" or "yes",
						dist
					)
					bot:Action_AttackUnit(target, true)
					return
				end
				bot:Action_MoveToLocation(
					Fu.VectorTowards(bot:GetLocation(), target:GetExtrapolatedLocation(0.3), dist + 150)
				)
				return
			end
		end
	end
	-- Shukuchi kill: the cast set tryShukuchiKill but nothing read it, so the bot cast Shukuchi
	-- and kept doing what its mode wanted; the damage only lands on enemies Weaver passes
	-- through (radius 175), so it now walks onto the target, not while retreating, and stops
	-- once inside that radius (the hit has landed).
	if bot.tryShukuchiKill and not isRetreating then
		local killTarget = bot.ShukuchiKillTarget
		if
			Fu.IsValidHero(killTarget)
			and GetUnitToUnitDistance(bot, killTarget) > 150
			and GetUnitToUnitDistance(bot, killTarget) < 1800
		then
			X.LogWeaver(
				"shukuchi-kill-path",
				"target=%s dist=%d",
				killTarget:GetUnitName(),
				GetUnitToUnitDistance(bot, killTarget)
			)
			bot:Action_MoveToLocation(killTarget:GetExtrapolatedLocation(0.3))
			return
		end
		bot.tryShukuchiKill = false
	end
	local shukuchiEscapeWhy
	shukuchiDesire, shukuchiEscapeWhy = X.ConsiderShukuchi()
	if shukuchiDesire > 0 then
		if shukuchiEscapeWhy ~= nil then
			local enemiesNear = #Fu.GetNearbyHeroes(bot, WeaverRules.ESCAPE_ENEMY_RANGE, true, BOT_MODE_NONE)
			bot._shukuchiChase = nil
			bot.tryShukuchiKill = false
			bot._shukuchiEscape = {
				why = shukuchiEscapeWhy,
				hp = hpRatio,
				castAt = DotaTime(),
				-- GetLastAttackTime is on the GameTime clock (FuncLib/general_utils/combat.lua reads it so).
				castGame = GameTime(),
				untilTime = DotaTime() + shukuchiAbility:GetSpecialValueFloat("duration") + 0.5,
				deaths = GetHeroDeaths(bot:GetPlayerID()),
			}
			bot._shukuchiEscapeAt = DotaTime()
			-- "-cast": the cast line has its own word, so a check can match it without the -end / -skip lines.
			X.LogWeaver(
				"shukuchi-escape-cast",
				"why=%s hp=%.2f mp=%.2f enemies=%d mode=%d",
				shukuchiEscapeWhy,
				hpRatio,
				mpRatio,
				enemiesNear,
				bot:GetActiveMode()
			)
		end
		Fu.SetQueuePtToINT(bot, false)
		bot:Action_UseAbility(shukuchiAbility)
		return
	end
	theSwarmDesire, theSwarmLocation = X.ConsiderTheSwarm()
	if theSwarmDesire > 0 then
		Fu.SetQueuePtToINT(bot, false)
		bot:Action_UseAbilityOnLocation(theSwarmAbility, theSwarmLocation)
		return
	end
end
function X.ConsiderTheSwarm()
	if not theSwarmAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local castRange = theSwarmAbility:GetCastRange()
	local spawnRadius = theSwarmAbility:GetSpecialValueInt("spawn_radius")
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidTarget(botTarget)
			-- The Swarm is SPELL_IMMUNITY_ENEMIES_NO: beetles do not latch a magic-immune hero.
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange * 0.8)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			local alliesNearTarget = Fu.GetNearbyHeroes(botTarget, 1200, true, BOT_MODE_NONE)
			local enemiesNearTarget = Fu.GetNearbyHeroes(botTarget, 1200, false, BOT_MODE_NONE)
			if alliesNearTarget ~= nil and enemiesNearTarget ~= nil and #alliesNearTarget >= #enemiesNearTarget then
				enemiesNearTarget = Fu.GetEnemiesNearLoc(botTarget:GetLocation(), spawnRadius)
				if enemiesNearTarget ~= nil and #enemiesNearTarget >= 1 then
					return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(enemiesNearTarget)
				end
				return BOT_ACTION_DESIRE_HIGH, botTarget:GetExtrapolatedLocation(0.5)
			end
		end
	end
	if isRetreating then
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE)
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.IsChasingTarget(enemyHero, bot)
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
					nearbyEnemies = Fu.GetEnemiesNearLoc(enemyHero:GetLocation(), spawnRadius)
					if nearbyEnemies ~= nil and #nearbyEnemies >= 1 then
						return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(nearbyEnemies)
					end
					return BOT_ACTION_DESIRE_HIGH, enemyHero:GetLocation()
				end
			end
		end
	end
	if Fu.IsPushing(bot) or Fu.IsDefending(bot) then
		-- Heroes first: the creep case returned before it, so with 5 creeps in range the swarm
		-- went on the wave even with enemy heroes standing there.
		local aoeLocation = bot:FindAoELocation(true, true, bot:GetLocation(), 1600, spawnRadius, 0, 0)
		local enemiesNearAoe = Fu.GetEnemiesNearLoc(aoeLocation.targetloc, spawnRadius)
		if enemiesNearAoe ~= nil and #enemiesNearAoe >= 1 then
			return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(enemiesNearAoe)
		end
		-- Creeps only with spare mana: the swarm is Weaver's fight spell (20-44s cooldown).
		local nearbyLaneCreeps = bot:GetNearbyLaneCreeps(1600, true)
		if nearbyLaneCreeps ~= nil and #nearbyLaneCreeps >= 5 and mpRatio > 0.5 then
			return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(nearbyLaneCreeps)
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if
			Fu.IsRoshan(botTarget)
			and Fu.CanCastOnMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, 500)
			and isAttacking
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, 500) and isAttacking then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
-- Why Weaver should Shukuchi away now, or nil: "retreat" (chased while retreating), "tower" (hit by a tower while
-- retreating) or "low-hp" (any mode, retreat included: WeaverRules.EscapeOutOfRetreat).
function X.ShukuchiEscapeReason()
	if isRetreating then
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE)
		for _, enemyHero in pairs(nearbyEnemies) do
			if Fu.IsValidHero(enemyHero) and Fu.IsChasingTarget(enemyHero, bot) and not Fu.IsDisabled(enemyHero) then
				local alliesNearEnemy = Fu.GetNearbyHeroes(enemyHero, 1200, true, BOT_MODE_NONE)
				local enemiesNearEnemy = Fu.GetNearbyHeroes(enemyHero, 1200, false, BOT_MODE_NONE)
				if
					alliesNearEnemy ~= nil
					and enemiesNearEnemy ~= nil
					and (#enemiesNearEnemy > #alliesNearEnemy or bot:WasRecentlyDamagedByAnyHero(1.5))
				then
					return "retreat"
				end
			end
		end
		if bot:WasRecentlyDamagedByTower(2) then
			return "tower"
		end
	end
	if hpRatio >= WeaverRules.ESCAPE_HP or not bot:WasRecentlyDamagedByAnyHero(1.5) then
		return nil
	end
	local enemiesNear = 0
	for _, enemyHero in pairs(Fu.GetNearbyHeroes(bot, WeaverRules.ESCAPE_ENEMY_RANGE, true, BOT_MODE_NONE)) do
		if Fu.IsValidHero(enemyHero) and not Fu.IsSuspiciousIllusion(enemyHero) and not Fu.IsDisabled(enemyHero) then
			enemiesNear = enemiesNear + 1
		end
	end
	local targetDiesSoon = Fu.IsValidHero(botTarget)
		and Fu.IsInRange(bot, botTarget, bot:GetAttackRange() + 100)
		and (bot:GetEstimatedDamageToTarget(true, botTarget, 1.5, DAMAGE_TYPE_PHYSICAL) or 0)
			>= botTarget:GetHealth()
	if WeaverRules.EscapeOutOfRetreat(hpRatio, true, enemiesNear, targetDiesSoon) then
		return "low-hp"
	end
	return nil
end
-- Escape bookkeeping, every think, before the early return (game 063, #161): the end of an escape with how long the
-- invisibility lasted and what she was doing, died-after= 5s after the end, and one line per death with the
-- Shukuchi state. The think does not run while she is dead, so a death shows as a higher GetHeroDeaths at the next
-- think after the respawn, and its lines carry t= of the last think alive (as [OHA-DEATH] does).
function X.WatchShukuchi()
	local now = DotaTime()
	local deaths = GetHeroDeaths(bot:GetPlayerID()) or 0
	local last = bot._shukuchiLast
	local enemiesNear = #Fu.GetNearbyHeroes(bot, WeaverRules.ESCAPE_ENEMY_RANGE, true, BOT_MODE_NONE)
	if last ~= nil and deaths > last.deaths then
		X.PrintWeaver(
			last.t,
			"shukuchi-death",
			"cd=%.1f mana=%d cost=%d level=%d want=%s wantAgo=%s skip=%s escapeAgo=%s hp=%.2f mode=%d",
			last.cd,
			last.mana,
			last.cost,
			last.level,
			last.want,
			last.wantAgo,
			last.skip,
			last.escapeAgo,
			last.hp,
			last.mode
		)
		local escape = bot._shukuchiEscape
		if escape ~= nil then
			bot._shukuchiEscape = nil
			X.PrintWeaver(
				last.t,
				"shukuchi-escape-end",
				"why=%s hp=%.2f->%.2f died=yes lasted=%.1f attacked=%s lapse=%s mode=%d",
				escape.why,
				escape.hp,
				last.hp,
				last.t - escape.castAt,
				tostring(escape.attacked == true),
				tostring(escape.lapse == true),
				last.mode
			)
		end
		local after = bot._shukuchiAfter
		if after ~= nil then
			bot._shukuchiAfter = nil
			X.PrintWeaver(
				last.t,
				"shukuchi-escape-result",
				"why=%s died-after=%s endAgo=%.1f lasted=%.1f",
				after.why,
				last.t <= after.endAt + 5 and "yes" or "no",
				last.t - after.endAt,
				after.lasted
			)
		end
	end
	local escape = bot._shukuchiEscape
	if escape ~= nil then
		local invisible = bot:HasModifier("modifier_weaver_shukuchi")
		if invisible and (bot:GetLastAttackTime() or -999) > escape.castGame then
			escape.attacked = true
		end
		if now > escape.untilTime or not invisible and now > escape.castAt + 0.75 then
			bot._shukuchiEscape = nil
			local attackTarget = bot:GetAttackTarget()
			local lasted = now - escape.castAt
			X.PrintWeaver(
				now,
				"shukuchi-escape-end",
				"why=%s hp=%.2f->%.2f died=no lasted=%.1f attacked=%s lapse=%s mode=%d action=%d target=%s casting=%s enemies=%d",
				escape.why,
				escape.hp,
				hpRatio,
				lasted,
				tostring(escape.attacked == true or (bot:GetLastAttackTime() or -999) > escape.castGame),
				tostring(escape.lapse == true),
				bot:GetActiveMode(),
				bot:GetCurrentActionType() or -1,
				attackTarget ~= nil and (string.gsub(attackTarget:GetUnitName() or "?", "npc_dota_", "")) or "none",
				tostring(bot:IsCastingAbility() or bot:IsUsingAbility()),
				enemiesNear
			)
			bot._shukuchiAfter = { why = escape.why, endAt = now, lasted = lasted }
		end
	end
	local after = bot._shukuchiAfter
	if after ~= nil and now >= after.endAt + 5 then
		bot._shukuchiAfter = nil
		X.PrintWeaver(
			now,
			"shukuchi-escape-result",
			"why=%s died-after=no hp=%.2f lasted=%.1f enemies=%d",
			after.why,
			hpRatio,
			after.lasted,
			enemiesNear
		)
	end
	bot._shukuchiLast = {
		t = now,
		deaths = deaths,
		hp = hpRatio,
		mode = bot:GetActiveMode(),
		cd = shukuchiAbility:GetCooldownTimeRemaining(),
		mana = bot:GetMana(),
		cost = shukuchiAbility:GetManaCost(),
		level = shukuchiAbility:GetLevel(),
		want = bot._shukuchiWant or "none",
		wantAgo = bot._shukuchiWantAt and string.format("%.1f", now - bot._shukuchiWantAt) or "-",
		skip = bot._shukuchiSkip or "-",
		escapeAgo = bot._shukuchiEscapeAt and string.format("%.1f", now - bot._shukuchiEscapeAt) or "-",
	}
end
-- An escape wanted while a disable blocks every cast (the early return in SkillsComplement). Her own orders
-- (queued, casting) are not a block and print nothing.
function X.LogEscapeBlocked()
	if not bot:IsAlive() or bot:HasModifier("modifier_weaver_shukuchi") then
		return
	end
	local blockedBy = WeaverRules.DisabledReason(
		bot:IsStunned(),
		bot:IsHexed(),
		bot:IsSilenced(),
		bot:IsNightmared(),
		bot:HasModifier("modifier_doom_bringer_doom")
	)
	if blockedBy == nil then
		return
	end
	local escapeWhy = X.ShukuchiEscapeReason()
	if escapeWhy == nil then
		return
	end
	bot._shukuchiWant = escapeWhy
	bot._shukuchiWantAt = DotaTime()
	bot._shukuchiSkip = blockedBy
	X.LogWeaver(
		"shukuchi-escape-skip",
		"why=%s want=%s hp=%.2f mana=%d cd=%.1f",
		blockedBy,
		escapeWhy,
		hpRatio,
		bot:GetMana(),
		shukuchiAbility:GetCooldownTimeRemaining()
	)
end
function X.ConsiderShukuchi()
	local escapeWhy = X.ShukuchiEscapeReason()
	if escapeWhy ~= nil then
		bot._shukuchiWant = escapeWhy
		bot._shukuchiWantAt = DotaTime()
	end
	if not shukuchiAbility:IsFullyCastable() then
		if escapeWhy ~= nil and not bot:HasModifier("modifier_weaver_shukuchi") then
			bot._shukuchiSkip = WeaverRules.EscapeBlocked(
				shukuchiAbility:GetCooldownTimeRemaining(),
				bot:GetMana(),
				shukuchiAbility:GetManaCost()
			)
			X.LogWeaver(
				"shukuchi-escape-skip",
				"why=%s want=%s hp=%.2f mana=%d cd=%.1f",
				bot._shukuchiSkip,
				escapeWhy,
				hpRatio,
				bot:GetMana(),
				shukuchiAbility:GetCooldownTimeRemaining()
			)
		end
		return BOT_ACTION_DESIRE_NONE
	end
	if escapeWhy ~= nil then
		return BOT_ACTION_DESIRE_HIGH, escapeWhy
	end
	local attackRange = bot:GetAttackRange()
	local shukuchiDamage = shukuchiAbility:GetSpecialValueInt("damage")
	local shukuchiDuration = shukuchiAbility:GetSpecialValueFloat("duration")
	local shukuchiSpeed = 550
	local roshanLocation = Fu.GetCurrentRoshanLocation()
	local tormentorLocation = Fu.GetTormentorLocation(GetTeam())
	-- A kill or chase Shukuchi keeps the mana for one more, the escape (game 050, 17:11-17:15: two chase casts
	-- from 21% mana left none when three heroes turned on her). Game files: 65 mana, cooldown 15/12/9/6s.
	local keepsEscape = bot:GetMana() >= 2 * shukuchiAbility:GetManaCost()
	local nearbyEnemies = Fu.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			keepsEscape
			and Fu.IsValidHero(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and Fu.CanKillTarget(enemyHero, shukuchiDamage, DAMAGE_TYPE_MAGICAL)
			and enemyHero:DistanceFromFountain() > 600
			and not Fu.IsSuspiciousIllusion(enemyHero)
			and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
			and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
			and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
			and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
			and not enemyHero:HasModifier("modifier_templar_assassin_refraction_absorb")
		then
			local travelTime = GetUnitToUnitDistance(bot, enemyHero) / shukuchiSpeed
			if travelTime + 1 < shukuchiDuration then
				if Fu.IsInLaningPhase() then
					local towersNearEnemy = enemyHero:GetNearbyTowers(700, false)
					if towersNearEnemy ~= nil and #towersNearEnemy == 0 then
						bot.tryShukuchiKill = true
						bot.ShukuchiKillTarget = enemyHero
						bot.ShukuchiKillAt = DotaTime()
						return BOT_ACTION_DESIRE_HIGH
					end
				else
					bot.tryShukuchiKill = true
					bot.ShukuchiKillTarget = enemyHero
					bot.ShukuchiKillAt = DotaTime()
					return BOT_ACTION_DESIRE_HIGH
				end
			end
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			keepsEscape
			and Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnMagicImmune(botTarget)
			and not Fu.IsInRange(bot, botTarget, attackRange + 300)
			and not botTarget:HasModifier("modifier_enigma_black_hole_pull")
			and not botTarget:HasModifier("modifier_faceless_void_chronosphere_freeze")
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			bot._shukuchiChase = { target = botTarget, untilTime = DotaTime() + shukuchiDuration }
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if isRetreating then
		if (Fu.IsTormentor(botTarget) or Fu.IsRoshan(botTarget)) and Fu.IsInRange(bot, botTarget, 500) then
			if hpRatio < 0.4 then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	if Fu.IsPushing(bot) and mpRatio > 0.3 then
		local enemyTowers = bot:GetNearbyTowers(800, true)
		if
			enemyTowers ~= nil
			and #enemyTowers >= 1
			and enemyTowers[1] ~= nil
			and Fu.IsInRange(enemyTowers[1], bot, attackRange)
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsFarming(bot) and hpRatio > 0.25 and mpRatio > 0.25 then
		local attackTarget = bot:GetAttackTarget()
		-- Only as a gap closer to a farther target: cast while standing and attacking, Shukuchi
		-- passed through nothing and its invisibility broke on the next attack (65 mana wasted).
		if attackTarget ~= nil and GetUnitToUnitDistance(bot, attackTarget) > attackRange + 200 then
			return BOT_ACTION_DESIRE_MODERATE
		end
	end
	if Fu.IsDoingRoshan(bot) and mpRatio > 0.4 then
		local travelTime = GetUnitToLocationDistance(bot, roshanLocation) / shukuchiSpeed
		if travelTime > shukuchiDuration then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsDoingTormentor(bot) and mpRatio > 0.4 then
		local travelTime = GetUnitToLocationDistance(bot, tormentorLocation) / shukuchiSpeed
		if travelTime > shukuchiDuration then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
return X
