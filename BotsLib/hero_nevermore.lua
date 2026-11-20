-- Nevermore: skill build, item build, and ability use for this hero.
local X = {}
local bot = GetBot()
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local AbilityContext = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local Minion = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local sTalentList = Fu.Skill.GetTalentList(bot)
local sAbilityList = Fu.Skill.GetAbilityList(bot)
local sRole = Fu.Item.GetRoleItemsBuyList(bot)
local tTalentTreeList = {
	{ ["t25"] = { 10, 0 }, ["t20"] = { 0, 10 }, ["t15"] = { 0, 10 }, ["t10"] = { 0, 10 } },
	{ ["t25"] = { 10, 0 }, ["t20"] = { 0, 10 }, ["t15"] = { 10, 0 }, ["t10"] = { 0, 10 } },
}
local tAllAbilityBuildList = { { 1, 5, 1, 5, 1, 6, 1, 5, 5, 4, 4, 6, 4, 4, 6 } }
local nAbilityBuildList = tAllAbilityBuildList[1]
local nTalentBuildList
if sRole == "pos_1" or sRole == "pos_3" then
	nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList[1])
else
	nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList[2])
end
local sRoleItemsBuyList = {}
sRoleItemsBuyList["pos_1"] = {
	"item_tango",
	"item_double_branches",
	"item_faerie_fire",
	"item_magic_wand",
	"item_power_treads",
	"item_falcon_blade",
	"item_mask_of_madness",
	"item_dragon_lance",
	-- Yasha and Kaya and Blink Dagger: #5 and #3 by matches played (Dotabuff, last patch).
	"item_manta",
	"item_black_king_bar",
	"item_blink",
	"item_greater_crit",
	"item_hurricane_pike",
	"item_aghanims_shard",
	"item_satanic",
	"item_moon_shard",
	"item_travel_boots_2",
	"item_ultimate_scepter_2",
}
sRoleItemsBuyList["pos_2"] = {
	"item_tango",
	"item_double_branches",
	"item_faerie_fire",
	"item_enchanted_mango",
	"item_enchanted_mango",
	"item_bottle",
	"item_magic_wand",
	"item_power_treads",
	"item_dragon_lance",
	-- Yasha and Kaya, Blink Dagger and Aghanim's Scepter: #5, #3 and #6 by matches played (Dotabuff,
	-- last patch); Orchid / Bloodthorn are not in his top 25.
	"item_yasha_and_kaya",
	"item_black_king_bar",
	"item_blink",
	"item_ultimate_scepter",
	"item_greater_crit",
	"item_hurricane_pike",
	"item_aghanims_shard",
	"item_satanic",
	"item_moon_shard",
	"item_travel_boots_2",
	"item_ultimate_scepter_2",
}
-- One pair of boots in this build (user rule; Util/boots-check.js).
sRoleItemsBuyList["pos_4"] = {
	"item_tango",
	"item_tango",
	"item_double_branches",
	"item_clarity",
	"item_magic_wand",
	"item_tranquil_boots",
	"item_null_talisman",
	"item_glimmer_cape",
	"item_force_staff",
	"item_cyclone",
	"item_boots_of_bearing",
	"item_octarine_core",
	"item_hurricane_pike",
	"item_aghanims_shard",
	"item_wind_waker",
	"item_ultimate_scepter_2",
	"item_moon_shard",
}
sRoleItemsBuyList["pos_5"] = {
	"item_tango",
	"item_tango",
	"item_double_branches",
	"item_clarity",
	"item_magic_wand",
	"item_tranquil_boots",
	"item_null_talisman",
	"item_glimmer_cape",
	"item_pipe",
	"item_force_staff",
	"item_cyclone",
	"item_boots_of_bearing",
	"item_octarine_core",
	"item_hurricane_pike",
	"item_aghanims_shard",
	"item_wind_waker",
	"item_ultimate_scepter_2",
	"item_moon_shard",
}
sRoleItemsBuyList["pos_3"] = sRoleItemsBuyList["pos_1"]
X["sBuyList"] = sRoleItemsBuyList[sRole]
X["sSellList"] = { "item_kaya", "item_quelling_blade", "item_octarine_core", "item_bottle" }
if Fu.Role.IsPvNMode() or Fu.Role.IsAllShadow() then
	X["sBuyList"], X["sSellList"] = { "PvN_mid" }, {}
end
nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"] =
	Fu.SetUserHeroInit(nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"])
X["sSkillList"] = Fu.Skill.GetSkillList(sAbilityList, nAbilityBuildList, sTalentList, nTalentBuildList)
X["bDeafaultAbility"] = false
X["bDeafaultItem"] = false
function X.MinionThink(minionUnit)
	Minion.MinionThink(minionUnit)
end
local shadowrazeNearAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[1]), "sAbilityList[1]", "nevermore")
local shadowrazeMediumAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[2]), "sAbilityList[2]", "nevermore")
local shadowrazeFarAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[3]), "sAbilityList[3]", "nevermore")
local feastOfSoulsAbility = SafeAbility(bot:GetAbilityByName("nevermore_frenzy"), "nevermore_frenzy", "nevermore")
local requiemAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[6]), "sAbilityList[6]", "nevermore")
local talent4 = SafeAbility(bot:GetAbilityByName(sTalentList[4]), "sTalentList[4]", "nevermore")
local razeNearDesire
local razeMediumDesire
local razeFarDesire
local feastOfSoulsDesire
local requiemDesire
local razeManaReserve, mpRatio, hpRatio, botLevel, nearbyEnemies, botTarget
local isAttacking
local dangerState
function X.SkillsComplement()
	if bot.invisUltCombo then
		return
	end
	Fu.ConsiderTarget()
	if Fu.CanNotUseAbility(bot) then
		return
	end
	isAttacking = Fu.IsAttacking(bot)
	local context = AbilityContext.Build(bot)
	razeManaReserve = 340
	botLevel = context.level
	mpRatio = context.mp
	hpRatio = context.hp
	nearbyEnemies = context.enemies
	botTarget = context.target
	dangerState = X.DangerSituation()
	local requiemWhy, enemies350
	requiemDesire, requiemWhy, enemies350 = X.ConsiderR()
	if requiemDesire > 0 then
		X.LogRequiem(requiemWhy, enemies350)
		Fu.SetQueuePtToINT(bot, false)
		bot:ActionQueue_UseAbility(requiemAbility)
		return
	end
	if X.ConsiderBlinkRequiem() then
		return
	end
	if requiemAbility:IsFullyCastable() and Fu.Utils.IsTruelyInvisible(bot) then
		return
	end
	if X.ConsiderDangerRaze() then
		return
	end
	local razeWhy, razeTarget
	razeMediumDesire, razeWhy, razeTarget = X.Consider(shadowrazeMediumAbility, 450)
	if razeMediumDesire > 0 then
		X.CastRaze(shadowrazeMediumAbility, "medium", razeWhy, razeTarget)
		return
	end
	razeFarDesire, razeWhy, razeTarget = X.Consider(shadowrazeFarAbility, 700)
	if razeFarDesire > 0 then
		X.CastRaze(shadowrazeFarAbility, "far", razeWhy, razeTarget)
		return
	end
	razeNearDesire, razeWhy, razeTarget = X.Consider(shadowrazeNearAbility, 200)
	if razeNearDesire > 0 then
		X.CastRaze(shadowrazeNearAbility, "near", razeWhy, razeTarget)
		return
	end
	feastOfSoulsDesire = X.ConsiderFeastOfSouls()
	if feastOfSoulsDesire > 0 then
		Fu.SetQueuePtToINT(bot, false)
		bot:ActionQueue_UseAbility(feastOfSoulsAbility)
		return
	end
	X.LogDangerIdle()
end
local function ShortName(unit)
	if unit == nil or unit:IsNull() then
		return "none"
	end
	return (string.gsub(unit:GetUnitName(), "npc_dota_hero_", ""))
end
-- Why a spell is not castable right now, for the danger-idle line.
local function SpellState(ability)
	if not ability:IsTrained() then
		return "untrained"
	end
	if ability:GetCooldownTimeRemaining() > 0 then
		return "cd"
	end
	if bot:GetMana() < ability:GetManaCost() then
		return "mana"
	end
	return ability:IsFullyCastable() and "ready" or "blocked"
end
function X.LogRequiem(why, enemies350)
	if DotaTime() < (bot._sfRequiemLogAt or -999) then
		return
	end
	bot._sfRequiemLogAt = DotaTime() + 3
	pcall(
		print,
		string.format(
			"[OHA-SF] t=%.0f nevermore requiem why=%s enemies350=%d hp=%.2f souls=%d",
			DotaTime(),
			tostring(why),
			enemies350 or 0,
			hpRatio or 0,
			X.SoulCount()
		)
	)
end
-- Razes on heroes at most every 2s; razes on creeps (no target) at most every 20s, he farms with them all game.
function X.LogRaze(which, why, target)
	local key = target == nil and "_sfRazeCreepLogAt" or "_sfRazeLogAt"
	if DotaTime() < (bot[key] or -999) then
		return
	end
	bot[key] = DotaTime() + (target == nil and 20 or 2)
	pcall(
		print,
		string.format(
			"[OHA-SF] t=%.0f nevermore raze which=%s why=%s target=%s hp=%.2f",
			DotaTime(),
			which,
			tostring(why),
			ShortName(target),
			hpRatio or 0
		)
	)
end
function X.CastRaze(razeAbility, which, why, target)
	X.LogRaze(which, why, target)
	Fu.SetQueuePtToINT(bot, true)
	bot:ActionQueue_UseAbility(razeAbility)
end
-- In danger and nothing was cast this think: say why, so a game can tell a missing rule from a spell on cooldown.
function X.LogDangerIdle()
	if dangerState == nil or dangerState.why == nil or DotaTime() < (bot._sfDangerLogAt or -999) then
		return
	end
	bot._sfDangerLogAt = DotaTime() + 3
	pcall(
		print,
		string.format(
			"[OHA-SF] t=%.0f nevermore danger-idle why=%s enemies350=%d hp=%.2f souls=%d requiem=%s raze=%s",
			DotaTime(),
			dangerState.why,
			dangerState.enemies350,
			hpRatio or 0,
			dangerState.souls,
			SpellState(requiemAbility),
			SpellState(shadowrazeNearAbility)
		)
	)
end
-- Near raze in danger (game 052, 10:50: rooted, two Meepo bodies on him, no raze). 7.42 game file
-- (nevermore_shadowraze1): shadowraze_range 200 (the centre, ahead of him), shadowraze_radius 250, cast point 0.55,
-- no target: it lands where he faces. An enemy hero in the raze in front: raze now. One within reach but beside or
-- behind him: turn to it first, like Mirana's Leap and Techies' Force Staff turn, but with a one-shot attack order
-- instead of a move: he turns in place, also while rooted, and does not walk into melee. The next think razes
-- once the enemy is in front. The turn gets 1s, then the normal raze rules take over again for 3s.
function X.ConsiderDangerRaze()
	if dangerState == nil or dangerState.why == nil or not shadowrazeNearAbility:IsFullyCastable() then
		return false
	end
	local range = shadowrazeNearAbility:GetSpecialValueInt("shadowraze_range")
	if range <= 0 then
		range = 200
	end
	local radius = shadowrazeNearAbility:GetSpecialValueInt("shadowraze_radius")
	if radius <= 0 then
		radius = 250
	end
	local razeLocation = Fu.GetFaceTowardDistanceLocation(bot, range)
	local castPoint = shadowrazeNearAbility:GetCastPoint()
	local closest, closestDistance = nil, range + radius - 50
	for _, enemyHero in pairs(X.EnemyHeroesNear(range + radius, false)) do
		if Fu.CanCastOnNonMagicImmune(enemyHero) then
			if X.IsUnitNearLoc(enemyHero, razeLocation, radius - 30, castPoint) then
				X.CastRaze(shadowrazeNearAbility, "near", "danger-" .. dangerState.why, enemyHero)
				return true
			end
			local distance = GetUnitToUnitDistance(bot, enemyHero)
			if distance <= closestDistance then
				closest, closestDistance = enemyHero, distance
			end
		end
	end
	-- Turn only when rooted or not running: a hero running away does not turn back for a raze.
	if closest == nil or not dangerState.rooted and Fu.IsRetreating(bot) then
		return false
	end
	local now = DotaTime()
	if now - (bot._sfTurnAt or -999) > 1 then
		if now - (bot._sfTurnAt or -999) < 4 then
			return false
		end
		bot._sfTurnAt = now
		pcall(
			print,
			string.format(
				"[OHA-SF] t=%.0f nevermore raze which=near why=turn target=%s dist=%d rooted=%s hp=%.2f",
				now,
				ShortName(closest),
				math.floor(closestDistance),
				tostring(dangerState.rooted),
				hpRatio or 0
			)
		)
	end
	if Fu.CanBeAttacked(closest) and not bot:IsDisarmed() then
		bot:Action_AttackUnit(closest, true)
	else
		bot:Action_MoveToLocation(closest:GetLocation())
	end
	return true
end
-- Enemy heroes around him, Meepo bodies included. Fu.GetNearbyHeroes / Fu.GetEnemyList drop every enemy Meepo:
-- Fu.IsMeepoClone calls a Meepo a clone when it is not in one of OUR five team slots, which no enemy is. Game 052,
-- 10:52: two Meepo bodies hit him while his own lines counted enemies=0, so no rule here saw them. keepIllusions
-- keeps suspected illusions (the raze rules counted them before); otherwise they are left out.
function X.EnemyHeroesNear(radius, keepIllusions)
	local result = {}
	for _, enemyHero in pairs(bot:GetNearbyHeroes(math.min(radius, 1600), true, BOT_MODE_NONE) or {}) do
		if Fu.IsValidHero(enemyHero) and (keepIllusions or not Fu.IsSuspiciousIllusion(enemyHero)) then
			table.insert(result, enemyHero)
		end
	end
	return result
end
function X.SoulCount()
	return bot:GetModifierStackCount(bot:GetModifierByName("modifier_nevermore_necromastery"))
end
-- Danger (game 052, 10:50): rooted by Earthbind, or hit by heroes in the last 1.5s, with 2+ enemy heroes within
-- 350, or 1 and his HP under 50%. He cast neither Requiem nor the near raze and went from 97% to 15% in 7s.
-- s: rooted, hitByHeroes, enemies350, hp. Returns "rooted", "melee" or nil.
function X.DangerReason(s)
	if not s.rooted and not s.hitByHeroes then
		return nil
	end
	if s.enemies350 >= 2 or s.enemies350 >= 1 and s.hp < 0.5 then
		return s.rooted and "rooted" or "melee"
	end
	return nil
end
-- Requiem in danger, whatever the 10-soul gate below says, so the fear pushes them off him.
-- 7.42 game file (npc_dota_hero_nevermore.txt, nevermore_requiem): AbilityCastPoint 1.67, requiem_radius 1000,
-- requiem_fear_duration 1.2/1.5/1.8 (+0.1s per extra line that hits), requiem_soul_conversion 1. The tooltip
-- (abilities_english.txt): one line per soul, and only a unit a line damages is feared. So no souls, no fear.
-- requiem_line_width_start is 125: next to him a line covers roughly 60 degrees, so 4 lines (90 degrees apart)
-- give an enemy in melee about a 2-in-3 chance to be hit, and two of them a good chance that one is.
X.REQUIEM_DANGER_MIN_SOULS = 4
function X.RequiemDangerReason(s)
	if (s.souls or 0) < X.REQUIEM_DANGER_MIN_SOULS then
		return nil
	end
	return X.DangerReason(s)
end
-- The danger state for this think: enemies within 350 that Requiem and the razes can hurt (not magic immune).
-- The enemy search only runs when he is rooted or was just hit by a hero.
function X.DangerSituation()
	local s = {
		rooted = bot:IsRooted(),
		hitByHeroes = bot:WasRecentlyDamagedByAnyHero(1.5),
		enemies350 = 0,
		hp = hpRatio,
		souls = X.SoulCount(),
	}
	if s.rooted or s.hitByHeroes then
		for _, enemyHero in pairs(X.EnemyHeroesNear(350, false)) do
			if Fu.CanCastOnNonMagicImmune(enemyHero) then
				s.enemies350 = s.enemies350 + 1
			end
		end
	end
	s.why = X.DangerReason(s)
	return s
end
function X.ConsiderR()
	if not requiemAbility:IsFullyCastable() then
		return 0
	end
	local danger = dangerState or X.DangerSituation()
	local dangerWhy = X.RequiemDangerReason(danger)
	if dangerWhy ~= nil then
		return BOT_ACTION_DESIRE_VERYHIGH, dangerWhy, danger.enemies350
	end
	local soulCount = danger.souls
	if soulCount < 10 and hpRatio > 0.5 then
		return 0
	end
	local enemiesIn1200 = X.EnemyHeroesNear(1200, false)
	local enemiesIn750 = X.EnemyHeroesNear(750, false)
	local enemiesIn350 = X.EnemyHeroesNear(350, false)
	-- Follow-through of ConsiderBlinkRequiem: just blinked in, 2+ enemies within 750.
	if DotaTime() - (bot._sfBlinkAt or -999) <= 1.5 and #enemiesIn750 >= 2 then
		bot._sfBlinkAt = nil
		return BOT_ACTION_DESIRE_HIGH, "blink", #enemiesIn350
	end
	for _, enemyHero in pairs(enemiesIn350) do
		local cycloneTime = Fu.GetModifierTime(enemyHero, "modifier_brewmaster_storm_cyclone")
		if
			Fu.IsValidHero(enemyHero)
			and (cycloneTime > 0 and cycloneTime <= 1.66 or Fu.Utils.IsTruelyInvisible(bot))
			and enemyHero:GetHealth() > 700
		then
			return BOT_ACTION_DESIRE_HIGH, cycloneTime > 0 and "cyclone" or "invisible", #enemiesIn350
		end
	end
	if Fu.IsInTeamFight(bot, 1000) or Fu.IsGoingOnSomeone(bot) then
		if
			#enemiesIn750 >= 3
			or #enemiesIn350 >= 1 and #enemiesIn750 >= 2
			or #enemiesIn1200 >= 3 and #enemiesIn750 >= 2
			or #enemiesIn1200 >= 4 and #enemiesIn350 >= 1
		then
			return BOT_ACTION_DESIRE_HIGH, "teamfight", #enemiesIn350
		end
		local aoe = bot:FindAoELocation(true, true, bot:GetLocation(), 100, 800, 1.67, 0)
		if aoe.count >= 3 then
			return BOT_ACTION_DESIRE_HIGH, "aoe", #enemiesIn350
		end
		local target = Fu.GetProperTarget(bot)
		if
			Fu.IsValidHero(target)
			and Fu.CanCastOnNonMagicImmune(target)
			and not Fu.IsDisabled(target)
			and GetUnitToUnitDistance(target, bot) <= 400
			and target:GetHealth() > 700
		then
			return BOT_ACTION_DESIRE_HIGH, "target", #enemiesIn350
		end
	end
	return 0
end
-- Blink -> Requiem (review): his build buys a Blink Dagger, but Requiem was only cast where he
-- already stood. In a team fight (2+ of our heroes attacking within 1600, so he never blinks in
-- alone), with Requiem and its mana ready, 10+ souls and 40%+ HP, blink (1200, Arcane 1400, item
-- data) onto a spot 500+ away with 3+ enemy heroes within 450. ConsiderR casts Requiem for 1.5s
-- after the blink (bot._sfBlinkAt) whatever its own fight gates say.
function X.ConsiderBlinkRequiem()
	if not requiemAbility:IsFullyCastable() or bot:GetMana() < requiemAbility:GetManaCost() or bot:IsRooted() then
		return false
	end
	if Fu.IsRetreating(bot) or Fu.GetHP(bot) < 0.4 or not Fu.IsInTeamFight(bot, 1600) then
		return false
	end
	if bot:GetModifierStackCount(bot:GetModifierByName("modifier_nevermore_necromastery")) < 10 then
		return false
	end
	if not Fu.CanBlinkDagger(bot) or bot.Blink == nil then
		return false
	end
	local range = bot.Blink:GetName() == "item_arcane_blink" and 1400 or 1200
	local aoe = bot:FindAoELocation(true, true, bot:GetLocation(), range - 100, 450, 0, 0)
	if aoe == nil or aoe.count == nil or aoe.count < 3 or aoe.targetloc == nil then
		return false
	end
	if GetUnitToLocationDistance(bot, aoe.targetloc) < 500 or not IsLocationPassable(aoe.targetloc) then
		return false
	end
	local foes = 0
	for _, enemyHero in pairs(Fu.GetEnemiesNearLoc(aoe.targetloc, 450) or {}) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and not Fu.IsSuspiciousIllusion(enemyHero)
		then
			foes = foes + 1
		end
	end
	if foes < 3 then
		return false
	end
	if DotaTime() >= (bot._sfBlinkLogAt or -999) then
		bot._sfBlinkLogAt = DotaTime() + 3
		pcall(
			print,
			string.format(
				"[OHA-SF] t=%.0f blink-requiem foes=%d dist=%d",
				DotaTime(),
				foes,
				math.floor(GetUnitToLocationDistance(bot, aoe.targetloc))
			)
		)
	end
	bot._sfBlinkAt = DotaTime()
	bot:Action_UseAbilityOnLocation(bot.Blink, aoe.targetloc)
	return true
end
function X.Consider(razeAbility, razeDistance)
	if not razeAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
	end
	local razeRadius = 248
	local razeLocation = Fu.GetFaceTowardDistanceLocation(bot, razeDistance)
	local castPoint = razeAbility:GetCastPoint()
	local damageType = DAMAGE_TYPE_MAGICAL
	local abilityLevel = razeAbility:GetLevel()
	-- datafeed: Shadowraze deals shadowraze_damage 85/150/215/280 plus damage_per_soul (2) per Necromastery soul;
	-- the old 20 + 70 * level was too high and ignored souls. The talent sTalentList[4] is now a Feast of Souls talent, so it
	-- is no longer added here.
	local damage = razeAbility:GetSpecialValueInt("shadowraze_damage")
	if damage <= 0 then
		damage = 20 + 65 * abilityLevel
	end
	local aSouls = bot:GetModifierStackCount(bot:GetModifierByName("modifier_nevermore_necromastery"))
	damage = damage + aSouls * razeAbility:GetSpecialValueInt("damage_per_soul")
	local stackBonusDamage = razeAbility:GetSpecialValueInt("stack_bonus_damage")
	local creepKeyword = "ranged"
	local enemiesInRange = X.EnemyHeroesNear(1000, true)
	local target = Fu.GetProperTarget(bot)
	if
		Fu.IsValidHero(target)
		and Fu.CanCastOnNonMagicImmune(target)
		and X.IsUnitNearLoc(target, razeLocation, razeRadius - 20, castPoint)
		and (
			bot:GetMana() > razeManaReserve * (1 - abilityLevel / 4)
			or X.IsUnitCanBeKill(target, damage, stackBonusDamage, castPoint)
			or target:HasModifier("modifier_nevermore_requiem_fear")
		)
	then
		return BOT_ACTION_DESIRE_HIGH, "target", target
	end
	for _, enemyHero in pairs(enemiesInRange) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and X.IsUnitNearLoc(enemyHero, razeLocation, razeRadius - 30, castPoint)
			and (
				bot:GetMana() > razeManaReserve * (1 - abilityLevel / 4)
				or X.IsUnitCanBeKill(enemyHero, damage, stackBonusDamage, castPoint)
				or enemyHero:HasModifier("modifier_nevermore_requiem_fear")
			)
		then
			return BOT_ACTION_DESIRE_HIGH, "hero", enemyHero
		end
	end
	if botLevel <= 12 then
		local laneCreeps = bot:GetNearbyLaneCreeps(1000, true)
		local killableCount = 0
		for _, creep in pairs(laneCreeps) do
			if
				Fu.IsValid(creep)
				and not creep:HasModifier("modifier_fountain_glyph")
				and Fu.IsKeyWordUnit(creepKeyword, creep)
				and X.IsUnitNearLoc(creep, razeLocation, razeRadius, castPoint)
				and X.IsUnitCanBeKill(creep, damage, stackBonusDamage, castPoint)
			then
				killableCount = killableCount + 1
			end
		end
		if killableCount >= 2 then
			return BOT_ACTION_DESIRE_HIGH, "creeps-lane"
		end
	end
	if not Fu.IsRetreating(bot) then
		local nearbyCreeps = bot:GetNearbyCreeps(1200, true)
		local laneCreepsInRange = bot:GetNearbyLaneCreeps(razeDistance + razeRadius * 1.5, true)
		local hitCount = 0
		local killCount = 0
		for _, creep in pairs(nearbyCreeps) do
			if
				Fu.IsValid(creep)
				and not creep:HasModifier("modifier_fountain_glyph")
				and (creep:GetMagicResist() < 0.4 or mpRatio > 0.9)
				and X.IsUnitNearLoc(creep, razeLocation, razeRadius, castPoint)
			then
				hitCount = hitCount + 1
				if X.IsUnitCanBeKill(creep, damage, stackBonusDamage, castPoint) then
					killCount = killCount + 1
				end
			end
		end
		if botLevel >= 8 and enemiesInRange[1] == nil then
			if
				hitCount >= 4 and mpRatio > 0.6
				or hitCount >= 3 and bot:GetActiveMode() ~= BOT_MODE_LANING and mpRatio > 0.78
				or killCount >= 2 and hitCount == #laneCreepsInRange
				or hitCount >= 2 and mpRatio > 0.8 and botLevel > 10 and #nearbyCreeps == 2
				or hitCount >= 2 and botLevel > 24 and #nearbyCreeps == 2 and Fu.IsAllowedToSpam(bot, 180)
			then
				return BOT_ACTION_DESIRE_HIGH, "creeps-wave"
			end
		end
		if botLevel <= 10 then
			if killCount >= 2 and (hitCount == #laneCreepsInRange or mpRatio > 0.8) then
				return BOT_ACTION_DESIRE_HIGH, "creeps-kill"
			end
		end
		if killCount >= 3 then
			return BOT_ACTION_DESIRE_HIGH, "creeps-kill"
		end
	end
	return 0
end
function X.ConsiderFeastOfSouls()
	if not feastOfSoulsAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
	end
	local attackRange = bot:GetAttackRange()
	local soulCount = bot:GetModifierStackCount(bot:GetModifierByName("modifier_nevermore_necromastery"))
	local manaAfter = Fu.GetManaAfter(feastOfSoulsAbility:GetManaCost()) * bot:GetMana()
	-- datafeed: Necromastery max souls is 20 and Feast of Souls (nevermore_frenzy) gathers souls rather than
	-- spending them, so the old "soulCount < 25" gate kept it unused unless max souls were raised. Gate removed.
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidTarget(botTarget)
			and Fu.IsInRange(bot, botTarget, attackRange)
			and not Fu.IsChasingTarget(bot, botTarget)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			local targetEnemies = Fu.GetNearbyHeroes(botTarget, 1200, true, BOT_MODE_NONE)
			local targetAllies = Fu.GetNearbyHeroes(botTarget, 1200, false, BOT_MODE_NONE)
			if targetEnemies ~= nil and targetAllies ~= nil and #targetEnemies >= #targetAllies then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	if Fu.IsFarming(bot) and manaAfter > 0.3 then
		if isAttacking then
			local neutralCreeps = bot:GetNearbyNeutralCreeps(1000)
			if
				neutralCreeps ~= nil
				and (#neutralCreeps >= 3 or #neutralCreeps >= 2 and neutralCreeps[1]:IsAncientCreep())
			then
				return BOT_ACTION_DESIRE_HIGH
			end
			local laneCreeps = bot:GetNearbyLaneCreeps(1000, true)
			if laneCreeps ~= nil and #laneCreeps >= 4 then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	if Fu.IsPushing(bot) or Fu.IsDefending(bot) then
		local laneCreeps = bot:GetNearbyLaneCreeps(1000, true)
		if
			laneCreeps ~= nil
			and #laneCreeps >= 4
			and nearbyEnemies ~= nil
			and #nearbyEnemies == 0
			and manaAfter > 0.3
		then
			return BOT_ACTION_DESIRE_HIGH
		end
		if Fu.IsValidBuilding(botTarget) and Fu.CanBeAttacked(botTarget) and isAttacking then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsDoingRoshan(bot) or Fu.IsDoingTormentor(bot) then
		if
			(Fu.IsRoshan(botTarget) or Fu.IsTormentor(botTarget))
			and Fu.IsInRange(bot, botTarget, attackRange)
			and isAttacking
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.IsUnitNearLoc(unit, location, radius, delay)
	if GetUnitToLocationDistance(unit, location) > 250 then
		return false
	end
	local stability = unit:GetMovementDirectionStability()
	if stability < 0.98 then
		radius = radius - 14
	end
	if stability < 0.91 then
		radius = radius - 26
	end
	if stability < 0.81 then
		radius = radius - 30
	end
	local predictedLocation = Fu.GetCorrectLoc(unit, delay)
	if Fu.GetLocationToLocationDistance(predictedLocation, location) < radius then
		return true
	end
	return false
end
function X.IsUnitCanBeKill(unit, damage, stackBonusDamage, castPoint)
	local damageType = DAMAGE_TYPE_MAGICAL
	local debuffStacks = Fu.GetModifierCount(unit, "modifier_nevermore_shadowraze_debuff")
	local totalDamage = damage + debuffStacks * stackBonusDamage
	return Fu.WillKillTarget(unit, totalDamage, damageType, castPoint)
end
return X
