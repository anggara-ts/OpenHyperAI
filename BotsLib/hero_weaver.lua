-- Weaver: skill build, item build, and ability use for this hero.
local X = {}
local bot = GetBot()
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local AbilityContext = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
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
	"item_tango",
	"item_double_branches",
	"item_faerie_fire",
	"item_wraith_band",
	"item_falcon_blade",
	"item_power_treads",
	"item_magic_wand",
	"item_desolator",
	"item_dragon_lance",
	"item_sphere",
	"item_black_king_bar",
	"item_aghanims_shard",
	"item_greater_crit",
	"item_force_staff",
	"item_hurricane_pike",
	"item_satanic",
	sCarryItem,
	"item_moon_shard",
	"item_ultimate_scepter_2",
}
sRoleItemsBuyList["pos_2"] = sRoleItemsBuyList["pos_1"]
sRoleItemsBuyList["pos_4"] = sRoleItemsBuyList["pos_1"]
sRoleItemsBuyList["pos_5"] = sRoleItemsBuyList["pos_1"]
sRoleItemsBuyList["pos_3"] = sRoleItemsBuyList["pos_1"]
X["sBuyList"] = sRoleItemsBuyList[sRole]
X["sSellList"] = { "item_black_king_bar", "item_quelling_blade" }
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
	if Fu.CanNotUseAbility(bot) then
		return
	end
	isRetreating = Fu.IsRetreating(bot)
	isAttacking = Fu.IsAttacking(bot)
	hpRatio = Fu.GetHP(bot)
	mpRatio = Fu.GetMP(bot)
	botTarget = Fu.GetProperTarget(bot)
	-- Grace of 0.5s after the cast so the flag is not cleared before the buff shows up.
	if not bot:HasModifier("modifier_weaver_shukuchi") and DotaTime() - (bot.ShukuchiKillAt or -99) > 0.5 then
		bot.tryShukuchiKill = false
	end
	local timeLapseTarget
	timeLapseDesire, timeLapseTarget = X.ConsiderTimeLapse()
	if timeLapseDesire > 0 then
		if timeLapseTarget == "self" then
			bot:Action_UseAbility(timeLapseAbility)
		else
			if bot:HasScepter() then
				bot:Action_UseAbilityOnEntity(timeLapseAllyAbility, timeLapseTarget)
			end
		end
		return
	end
	-- Shukuchi kill: the cast set tryShukuchiKill but nothing read it, so the bot cast Shukuchi
	-- and kept doing what its mode wanted; the damage only lands on enemies Weaver passes
	-- through (radius 175), so it now walks onto the target, not while retreating, and stops
	-- once inside that radius (the hit has landed).
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
	shukuchiDesire = X.ConsiderShukuchi()
	if shukuchiDesire > 0 then
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
function X.ConsiderShukuchi()
	if not shukuchiAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
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
					return BOT_ACTION_DESIRE_HIGH
				end
			end
		end
		if bot:WasRecentlyDamagedByTower(2) then
			return BOT_ACTION_DESIRE_HIGH
		end
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
