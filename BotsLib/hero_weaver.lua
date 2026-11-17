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
nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"] = Fu.SetUserHeroInit(nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"])
X["sSkillList"] = Fu.Skill.GetSkillList(sAbilityList, nAbilityBuildList, sTalentList, nTalentBuildList)
X["bDeafaultAbility"] = false
X["bDeafaultItem"] = false
function X.MinionThink(hMinionUnit)
	Minion.MinionThink(hMinionUnit)
end
local theSwarmAbility = SafeAbility(bot:GetAbilityByName("weaver_the_swarm"), "weaver_the_swarm", "weaver")
local shukuchiAbility = SafeAbility(bot:GetAbilityByName("weaver_shukuchi"), "weaver_shukuchi", "weaver")
local timeLapseAbility = SafeAbility(bot:GetAbilityByName("weaver_time_lapse"), "weaver_time_lapse", "weaver")
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
-- HP fraction about 5s ago (what Time Lapse gives back), sampled every 0.5s.
function X.HpFiveSecondsAgo()
	local now = DotaTime()
	bot._weaverHp = bot._weaverHp or {}
	local history = bot._weaverHp
	if #history == 0 or now - history[#history][1] >= 0.5 then
		table.insert(history, { now, Fu.GetHP(bot) })
		while #history > 0 and now - history[1][1] > 6 do
			table.remove(history, 1)
		end
	end
	for _, sample in ipairs(history) do
		if now - sample[1] <= 5.2 then
			return sample[2]
		end
	end
	return Fu.GetHP(bot)
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
	local hpFiveSecondsAgo = X.HpFiveSecondsAgo()
	if geminateAttackAbility ~= nil and not geminateAttackAbility:IsNull() and geminateAttackAbility:IsTrained() and not geminateAttackAbility:GetAutoCastState() then
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
	-- Time Lapse in a fight: it was only considered in retreat mode, so a Weaver burst down while
	-- attacking (mode not yet retreat) died with it ready. Cast when HP fell hard in the last 5s.
	if timeLapseAbility:IsFullyCastable() and not isRetreating and hpRatio < 0.3 and hpFiveSecondsAgo - hpRatio >= 0.25 and bot:WasRecentlyDamagedByAnyHero(1.5) then
		X.LogWeaver("lapse-fight", "hp=%.2f hp5=%.2f", hpRatio, hpFiveSecondsAgo)
		bot:Action_UseAbility(timeLapseAbility)
		return
	end
	timeLapseDesire, Target = X.ConsiderTimeLapse()
	if timeLapseDesire > 0 then
		if Target == "self" then
			bot:Action_UseAbility(timeLapseAbility)
		else
			if bot:HasScepter() then
				bot:Action_UseAbilityOnEntity(timeLapseAbility, Target)
			end
		end
		return
	end
	-- Shukuchi kill: the cast set tryShukuchiKill but nothing read it, so the bot cast Shukuchi
	-- and kept doing what its mode wanted; the damage only lands on enemies Weaver passes
	-- through (radius 175), so it now walks onto the target, not while retreating, and stops
	-- once inside that radius (the hit has landed).
	if bot.tryShukuchiKill and not isRetreating then
		local killTarget = bot.ShukuchiKillTarget
		if Fu.IsValidHero(killTarget) and GetUnitToUnitDistance(bot, killTarget) > 150 and GetUnitToUnitDistance(bot, killTarget) < 1800 then
			X.LogWeaver("shukuchi-kill-path", "target=%s dist=%d", killTarget:GetUnitName(), GetUnitToUnitDistance(bot, killTarget))
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
				if alliesNearEnemy ~= nil and enemiesNearEnemy ~= nil and (#enemiesNearEnemy > #alliesNearEnemy or bot:WasRecentlyDamagedByAnyHero(2)) then
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
		if Fu.IsRoshan(botTarget) and Fu.CanCastOnMagicImmune(botTarget) and Fu.IsInRange(bot, botTarget, 500) and isAttacking then
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
	local nearbyEnemies = Fu.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidHero(enemyHero)
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
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnMagicImmune(botTarget)
			and not Fu.IsInRange(bot, botTarget, attackRange + 300)
			and not botTarget:HasModifier("modifier_enigma_black_hole_pull")
			and not botTarget:HasModifier("modifier_faceless_void_chronosphere_freeze")
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if isRetreating then
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE)
		for _, enemyHero in pairs(nearbyEnemies) do
			if Fu.IsValidHero(enemyHero) and Fu.IsChasingTarget(enemyHero, bot) and not Fu.IsDisabled(enemyHero) then
				local alliesNearEnemy = Fu.GetNearbyHeroes(enemyHero, 1200, true, BOT_MODE_NONE)
				local enemiesNearEnemy = Fu.GetNearbyHeroes(enemyHero, 1200, false, BOT_MODE_NONE)
				if alliesNearEnemy ~= nil and enemiesNearEnemy ~= nil and (#enemiesNearEnemy > #alliesNearEnemy or bot:WasRecentlyDamagedByAnyHero(1.5)) then
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
		if enemyTowers ~= nil and #enemyTowers >= 1 and enemyTowers[1] ~= nil and Fu.IsInRange(enemyTowers[1], bot, attackRange) then
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
function X.ConsiderTimeLapse()
	if not timeLapseAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	if isRetreating then
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE)
		for _, enemyHero in pairs(nearbyEnemies) do
			if Fu.IsValidHero(enemyHero) and not Fu.IsSuspiciousIllusion(enemyHero) and not Fu.IsDisabled(enemyHero) then
				local alliesNearEnemy = Fu.GetNearbyHeroes(enemyHero, 1200, true, BOT_MODE_NONE)
				local enemiesNearEnemy = Fu.GetNearbyHeroes(enemyHero, 1200, false, BOT_MODE_NONE)
				if alliesNearEnemy ~= nil and enemiesNearEnemy ~= nil and #enemiesNearEnemy > #alliesNearEnemy then
					if
						hpRatio < 0.42
						and shukuchiAbility:IsTrained()
						and shukuchiAbility:GetCooldownTimeRemaining() < 2.5
						and Fu.IsChasingTarget(enemyHero, bot)
					then
						return BOT_ACTION_DESIRE_HIGH, "self"
					end
				end
				if hpRatio < 0.33 and bot:WasRecentlyDamagedByHero(enemyHero, 1) then
					return BOT_ACTION_DESIRE_HIGH, "self"
				end
			end
		end
	end
	if bot:HasScepter() then
		local castRange = timeLapseAbility:GetCastRange()
		local nearbyAllies = Fu.GetNearbyHeroes(bot, castRange, false, BOT_MODE_NONE)
		for _, allyHero in pairs(nearbyAllies) do
			if
				Fu.IsValidHero(allyHero)
				and Fu.IsRetreating(allyHero)
				and Fu.GetHP(allyHero) < 0.33
				and Fu.IsCore(allyHero)
				and hpRatio > 0.75
				and allyHero:WasRecentlyDamagedByAnyHero(2)
				and not Fu.IsSuspiciousIllusion(allyHero)
				and not allyHero:HasModifier("modifier_legion_commander_duel")
				and not allyHero:HasModifier("modifier_necrolyte_reapers_scythe")
			then
				local enemiesNearAlly = Fu.GetNearbyHeroes(allyHero, 1200, true, BOT_MODE_NONE)
				for _, enemyHero in pairs(enemiesNearAlly) do
					if
						Fu.IsValidHero(enemyHero)
						and Fu.IsChasingTarget(enemyHero, allyHero)
						and not Fu.IsSuspiciousIllusion(enemyHero)
						and not Fu.IsDisabled(enemyHero)
					then
						return BOT_ACTION_DESIRE_HIGH, allyHero
					end
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
return X
