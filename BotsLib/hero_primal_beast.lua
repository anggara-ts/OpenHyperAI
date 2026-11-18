-- Primal Beast: skill build, item build, and ability use for this hero.
local X = {}
local bot = GetBot()
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local AbilityContext = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local Minion = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local sTalentList = Fu.Skill.GetTalentList(bot)
local sAbilityList = Fu.Skill.GetAbilityList(bot)
local sRole = Fu.Item.GetRoleItemsBuyList(bot)
local tTalentTreeList = {
	{ ["t25"] = { 10, 0 }, ["t20"] = { 0, 10 }, ["t15"] = { 0, 10 }, ["t10"] = { 10, 0 } },
	{ ["t25"] = { 10, 0 }, ["t20"] = { 10, 0 }, ["t15"] = { 0, 10 }, ["t10"] = { 10, 0 } },
}
local tAllAbilityBuildList =
	{ { 2, 3, 1, 2, 1, 6, 2, 2, 1, 1, 6, 3, 3, 3, 6 }, { 1, 2, 2, 3, 2, 6, 2, 3, 3, 3, 6, 1, 1, 1, 6 } }
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
sRoleItemsBuyList["pos_2"] = {
	"item_tango",
	"item_double_branches",
	"item_faerie_fire",
	"item_quelling_blade",
	"item_bottle",
	"item_phase_boots",
	"item_magic_wand",
	"item_blade_mail",
	"item_ultimate_scepter",
	"item_black_king_bar",
	"item_blink",
	"item_aghanims_shard",
	"item_shivas_guard",
	"item_heart",
	"item_travel_boots",
	"item_overwhelming_blink",
	"item_moon_shard",
	"item_travel_boots_2",
	"item_ultimate_scepter_2",
}
sRoleItemsBuyList["pos_3"] = {
	"item_tango",
	"item_double_branches",
	"item_quelling_blade",
	"item_magic_stick",
	"item_bracer",
	"item_magic_wand",
	"item_phase_boots",
	"item_blade_mail",
	"item_blink",
	"item_ultimate_scepter",
	"item_crimson_guard",
	"item_black_king_bar",
	"item_lotus_orb",
	"item_shivas_guard",
	"item_travel_boots",
	"item_moon_shard",
	"item_aghanims_shard",
	"item_travel_boots_2",
	"item_ultimate_scepter_2",
}
sRoleItemsBuyList["pos_1"] = sRoleItemsBuyList["pos_3"]
sRoleItemsBuyList["pos_4"] = {
	"item_priest_outfit",
	"item_mekansm",
	"item_glimmer_cape",
	"item_aghanims_shard",
	"item_guardian_greaves",
	"item_spirit_vessel",
	"item_lotus_orb",
	"item_gungir",
	"item_sheepstick",
	"item_mystic_staff",
	"item_moon_shard",
	"item_ultimate_scepter_2",
	"item_shivas_guard",
}
sRoleItemsBuyList["pos_5"] = {
	"item_mage_outfit",
	"item_glimmer_cape",
	"item_pavise",
	"item_pipe",
	"item_solar_crest",
	"item_lotus_orb",
	"item_aghanims_shard",
	"item_spirit_vessel",
	"item_shivas_guard",
	"item_mystic_staff",
	"item_ultimate_scepter_2",
	"item_moon_shard",
	"item_sheepstick",
}
X["sBuyList"] = sRoleItemsBuyList[sRole]
X["sSellList"] = { "item_vanguard", "item_quelling_blade" }
if Fu.Role.IsPvNMode() or Fu.Role.IsAllShadow() then
	X["sBuyList"], X["sSellList"] = { "PvN_mid" }, {}
end
nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"] =
	Fu.SetUserHeroInit(nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"])
X["sSkillList"] = Fu.Skill.GetSkillList(sAbilityList, nAbilityBuildList, sTalentList, nTalentBuildList)
X["bDeafaultAbility"] = false
X["bDeafaultItem"] = false
function X.MinionThink(hMinionUnit)
	Minion.MinionThink(hMinionUnit)
end
local onslaughtAbility =
	SafeAbility(bot:GetAbilityByName("primal_beast_onslaught"), "primal_beast_onslaught", "primal_beast")
local trampleAbility = SafeAbility(bot:GetAbilityByName("primal_beast_trample"), "primal_beast_trample", "primal_beast")
local uproarAbility = SafeAbility(bot:GetAbilityByName("primal_beast_uproar"), "primal_beast_uproar", "primal_beast")
local rockThrowAbility =
	SafeAbility(bot:GetAbilityByName("primal_beast_rock_throw"), "primal_beast_rock_throw", "primal_beast")
local pulverizeAbility =
	SafeAbility(bot:GetAbilityByName("primal_beast_pulverize"), "primal_beast_pulverize", "primal_beast")
local onslaughtReleaseAbility = SafeAbility(
	bot:GetAbilityByName("primal_beast_onslaught_release"),
	"primal_beast_onslaught_release",
	"primal_beast"
)
local botTarget, nearbyEnemies, nearbyAllies
local onslaughtDesire, onslaughtLocation
local onslaughtReleaseDesire
local trampleDesire
local uproarDesire
local rockThrowDesire, rockThrowLocation
local pulverizeDesire, pulverizeTarget
local onslaughtCastTime = 0
local onslaughtChargeTime = 0
local isGoingOnSomeone
local isRetreating
local isAttacking
local hpRatio
function X.SkillsComplement()
	isGoingOnSomeone = Fu.IsGoingOnSomeone(bot)
	isRetreating = Fu.IsRetreating(bot)
	isAttacking = Fu.IsAttacking(bot)
	hpRatio = Fu.GetHP(bot)
	onslaughtAbility =
		SafeAbility(bot:GetAbilityByName("primal_beast_onslaught"), "primal_beast_onslaught", "primal_beast")
	trampleAbility = SafeAbility(bot:GetAbilityByName("primal_beast_trample"), "primal_beast_trample", "primal_beast")
	uproarAbility = SafeAbility(bot:GetAbilityByName("primal_beast_uproar"), "primal_beast_uproar", "primal_beast")
	rockThrowAbility =
		SafeAbility(bot:GetAbilityByName("primal_beast_rock_throw"), "primal_beast_rock_throw", "primal_beast")
	pulverizeAbility =
		SafeAbility(bot:GetAbilityByName("primal_beast_pulverize"), "primal_beast_pulverize", "primal_beast")
	onslaughtReleaseAbility = SafeAbility(
		bot:GetAbilityByName("primal_beast_onslaught_release"),
		"primal_beast_onslaught_release",
		"primal_beast"
	)
	botTarget = Fu.GetProperTarget(bot)
	nearbyEnemies = Fu.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE)
	nearbyAllies = Fu.GetNearbyHeroes(bot, 1600, false, BOT_MODE_NONE)
	if not bot:HasModifier("modifier_primal_beast_trample") then
		bot.trample_status = { "", 0, nil }
	end
	-- Uproar (no target, IMMEDIATE, ignores channel) does not break Trample's walk, but the busy check
	-- below blocked it for Trample's whole 5.5s; let it through during Trample only.
	if
		bot:HasModifier("modifier_primal_beast_trample")
		and not Fu.CanNotUseAbility(bot)
		and not bot:HasModifier("modifier_primal_beast_pulverize_self")
	then
		if X.ConsiderUproar() > 0 then
			if DotaTime() >= (bot._uproarTrampleLogAt or -999) then
				bot._uproarTrampleLogAt = DotaTime() + 5
				pcall(
					print,
					string.format("[OHA-PRIMAL_BEAST] t=%.0f uproar during trample hp=%.2f", DotaTime(), hpRatio)
				)
			end
			bot:Action_UseAbility(uproarAbility)
			return
		end
	end
	if
		Fu.CanNotUseAbility(bot)
		or bot:HasModifier("modifier_prevent_taunts")
		or bot:HasModifier("modifier_primal_beast_onslaught_movement_adjustable")
		or bot:HasModifier("modifier_primal_beast_trample")
		or bot:HasModifier("modifier_primal_beast_pulverize_self")
	then
		return
	end
	uproarDesire = X.ConsiderUproar()
	if uproarDesire > 0 then
		bot:Action_UseAbility(uproarAbility)
		return
	end
	pulverizeDesire, pulverizeTarget = X.ConsiderPulverize()
	if pulverizeDesire > 0 then
		if Fu.CanBlackKingBar(bot) and bot.BlackKingBar ~= nil then
			bot:Action_ClearActions(false)
			bot:ActionQueue_UseAbility(bot.BlackKingBar)
			bot:ActionQueue_UseAbilityOnEntity(pulverizeAbility, pulverizeTarget)
			return
		end
		bot:Action_UseAbilityOnEntity(pulverizeAbility, pulverizeTarget)
		return
	end
	trampleDesire = X.ConsiderTrample()
	if trampleDesire > 0 then
		bot:Action_UseAbility(trampleAbility)
		return
	end
	onslaughtReleaseDesire = X.ConsiderBeginOnslaughtDesire()
	if onslaughtReleaseDesire > 0 then
		bot:Action_UseAbility(onslaughtReleaseAbility)
		onslaughtChargeTime = 0
		return
	end
	onslaughtDesire, onslaughtLocation = X.ConsiderOnslaught()
	if onslaughtDesire > 0 then
		bot:Action_UseAbilityOnLocation(onslaughtAbility, onslaughtLocation)
		bot.onslaught_location = onslaughtLocation
		onslaughtCastTime = DotaTime()
		return
	end
	rockThrowDesire, rockThrowLocation = X.ConsiderRockThrow()
	if rockThrowDesire > 0 then
		bot:Action_UseAbilityOnLocation(rockThrowAbility, rockThrowLocation)
		return
	end
end
function X.ConsiderOnslaught()
	if not Fu.CanCastAbility(onslaughtAbility) or bot:IsRooted() or bot:HasModifier("modifier_bloodseeker_rupture") then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local maxDistance = onslaughtAbility:GetSpecialValueInt("max_distance")
	local knockbackDistance = onslaughtAbility:GetSpecialValueInt("knockback_distance")
	local chargeupTime = onslaughtAbility:GetSpecialValueFloat("chargeup_time")
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.IsInRange(bot, enemyHero, 600)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
		then
			local alliesNearEnemy = Fu.GetAlliesNearLoc(enemyHero:GetLocation(), 1200)
			local enemiesNearEnemy = Fu.GetEnemiesNearLoc(enemyHero:GetLocation(), 1200)
			if #alliesNearEnemy >= #enemiesNearEnemy and enemyHero:HasModifier("modifier_teleporting") then
				local distance = GetUnitToUnitDistance(bot, enemyHero)
				onslaughtChargeTime = RemapValClamped(distance, 100, maxDistance, 0.3, chargeupTime)
				bot.onslaught_status = { "engage", botTarget }
				return BOT_ACTION_DESIRE_HIGH, enemyHero:GetLocation()
			end
		end
	end
	-- Keep Onslaught for the escape when low (#48): game 044, none of his 4 deaths was saved by it.
	if isGoingOnSomeone and hpRatio >= 0.35 then
		if
			Fu.IsValidHero(botTarget)
			and Fu.CanBeAttacked(botTarget)
			and Fu.IsInRange(bot, botTarget, maxDistance)
			and not Fu.IsEnemyBlackHoleInLocation(botTarget:GetLocation())
			and not Fu.IsEnemyChronosphereInLocation(botTarget:GetLocation())
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			local alliesNearTarget = Fu.GetAlliesNearLoc(botTarget:GetLocation(), 1200)
			local enemiesNearTarget = Fu.GetEnemiesNearLoc(botTarget:GetLocation(), 1200)
			if #alliesNearTarget >= #enemiesNearTarget then
				local distance = GetUnitToUnitDistance(bot, botTarget)
				onslaughtChargeTime = RemapValClamped(distance, 100, maxDistance, 0.3, chargeupTime)
				bot.onslaught_status = { "engage", botTarget }
				return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
			end
		end
	end
	-- Game 044: the escape charge started at 10-17% HP (t=326 hp=0.17 died while charging; t=1575 hp=0.10) and stood
	-- 1.3-1.5s charging while hit. Start earlier when chased (under 45% HP with a chaser, at retreat desire 0.5+),
	-- and with an enemy within 300 release after a short charge: game files chargeup_time 2.2 for max_distance 2000.
	local chasers = 0
	for _, enemyHero in pairs(nearbyEnemies) do
		if Fu.IsValidHero(enemyHero) and Fu.IsChasingTarget(enemyHero, bot) then
			chasers = chasers + 1
		end
	end
	local earlyEscape = hpRatio < 0.45 and chasers >= 1 and bot:GetActiveModeDesire() >= 0.5
	-- Game 045: 4 of 9 escape charges were followed by death within 3s: he stands charging (1.3s+) while hit. With an
	-- enemy hero within 600 the charge-up costs more than it gains; he just runs (logged once per 5s).
	local nearestEnemy = math.huge
	for _, enemyHero in pairs(nearbyEnemies) do
		if Fu.IsValidHero(enemyHero) then
			nearestEnemy = math.min(nearestEnemy, GetUnitToUnitDistance(bot, enemyHero))
		end
	end
	local tooClose = nearestEnemy <= 600
	if tooClose and isRetreating and DotaTime() >= (bot._onslaughtSkipLogAt or -999) then
		bot._onslaughtSkipLogAt = DotaTime() + 5
		pcall(
			print,
			string.format(
				"[OHA-PRIMAL_BEAST] t=%.0f onslaught escape-skip why=too-close dist=%d hp=%.2f",
				DotaTime(),
				math.floor(nearestEnemy),
				hpRatio
			)
		)
	end
	if
		isRetreating
		and not Fu.IsRealInvisible(bot)
		and bot:WasRecentlyDamagedByAnyHero(4)
		and (bot:GetActiveModeDesire() > 0.7 or earlyEscape)
		and not tooClose
	then
		if
			Fu.IsValidHero(nearbyEnemies[1])
			and (not Fu.WeAreStronger(bot, 1200) and hpRatio < 0.75 or Fu.IsChasingTarget(nearbyEnemies[1], bot))
		then
			-- chargeTime is already a charge TIME (0.6-1.0 x chargeup_time); remapping it again as a distance
			-- (100..max_distance) always gave the 0.3s floor, so the escape charge went only a few hundred units.
			local chargeTime = RemapValClamped(
				GetUnitToUnitDistance(bot, nearbyEnemies[1]),
				600,
				1200,
				chargeupTime * 0.6,
				chargeupTime
			)
			onslaughtChargeTime = chargeTime
			X.LogOnslaughtRetreat(onslaughtChargeTime, chasers)
			bot.onslaught_status = { "retreat", Fu.GetTeamFountain() }
			return BOT_ACTION_DESIRE_HIGH, Fu.GetTeamFountain()
		end
	end
	if Fu.IsFarming(bot) or Fu.IsPushing(bot) and #nearbyAllies <= 1 or Fu.IsDefending(bot) and #nearbyEnemies == 0 then
		local manaCost = onslaughtAbility:GetManaCost()
		local nearbyCreeps = bot:GetNearbyCreeps(800, true)
		if
			Fu.IsValid(nearbyCreeps[1])
			and Fu.GetMP(bot) > 0.5
			and Fu.GetManaAfter(manaCost) > 0.3
			and not Fu.IsRunning(nearbyCreeps[1])
			and Fu.CanBeAttacked(nearbyCreeps[1])
			and isAttacking
		then
			local aoeLocation =
				bot:FindAoELocation(true, false, nearbyCreeps[1]:GetLocation(), 0, knockbackDistance, 0, 0)
			if
				#nearbyCreeps >= 4 and aoeLocation.count >= 4 and not Fu.HasItem(bot, "item_radiance")
				or #nearbyCreeps >= 2 and aoeLocation.count >= 2 and nearbyCreeps[1]:IsAncientCreep()
			then
				local distance = GetUnitToLocationDistance(bot, aoeLocation.targetloc)
				onslaughtChargeTime = RemapValClamped(distance, 100, maxDistance, 0.3, chargeupTime)
				bot.onslaught_status = { "farm", aoeLocation.targetloc }
				return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
-- [OHA-PRIMAL_BEAST] retreat onslaught charge time, at most once per 5s.
function X.LogOnslaughtRetreat(chargeTime, chasers)
	if DotaTime() < (bot._onslaughtLogAt or -999) then
		return
	end
	bot._onslaughtLogAt = DotaTime() + 5
	pcall(
		print,
		string.format(
			"[OHA-PRIMAL_BEAST] t=%.0f onslaught retreat charge=%.2fs hp=%.2f chasers=%d",
			DotaTime(),
			chargeTime,
			hpRatio,
			chasers or 0
		)
	)
end
function X.ConsiderBeginOnslaughtDesire()
	if not Fu.CanCastAbility(onslaughtReleaseAbility) then
		return BOT_ACTION_DESIRE_NONE
	end
	if DotaTime() >= onslaughtCastTime + onslaughtChargeTime then
		return BOT_ACTION_DESIRE_HIGH
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderTrample()
	if not trampleAbility:IsFullyCastable() or bot:IsRooted() then
		return BOT_ACTION_DESIRE_NONE
	end
	local radius = trampleAbility:GetSpecialValueInt("effect_radius")
	local duration = trampleAbility:GetSpecialValueFloat("duration")
	local baseDamage = trampleAbility:GetSpecialValueInt("base_damage")
	local nearbyTowers = bot:GetNearbyTowers(1600, true)
	if isGoingOnSomeone then
		if
			Fu.IsValidHero(botTarget)
			and Fu.CanBeAttacked(botTarget)
			and Fu.IsInRange(bot, botTarget, radius)
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
			and not botTarget:HasModifier("modifier_item_blade_mail_reflect")
		then
			bot.trample_status = { "engaging", botTarget:GetLocation(), botTarget }
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if isRetreating and not Fu.IsRealInvisible(bot) and bot:WasRecentlyDamagedByAnyHero(3) then
		if
			Fu.IsValidHero(nearbyEnemies[1])
			and Fu.CanBeAttacked(nearbyEnemies[1])
			and Fu.IsInRange(bot, nearbyEnemies[1], radius)
			and not nearbyEnemies[1]:HasModifier("modifier_item_blade_mail_reflect")
		then
			bot.trample_status = { "retreating", Fu.GetTeamFountain(), nil }
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	local nearbyCreeps = bot:GetNearbyCreeps(800, true)
	local alliesNearBot = Fu.GetAlliesNearLoc(bot:GetLocation(), 800)
	if
		(Fu.IsFarming(bot) or Fu.IsPushing(bot) and #alliesNearBot <= 1 or Fu.IsDefending(bot))
		and Fu.GetManaAfter(trampleAbility:GetManaCost()) > 0.35
	then
		if
			Fu.IsValid(nearbyCreeps[1])
			and (#nearbyCreeps >= 3 and not Fu.HasItem(bot, "item_radiance") or #nearbyCreeps >= 2 and nearbyCreeps[1]:IsAncientCreep())
			and not Fu.IsRunning(nearbyCreeps[1])
			and Fu.CanBeAttacked(nearbyCreeps[1])
			and isAttacking
		then
			bot.trample_status = { "farming", 0, nil }
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsLaning(bot) and #nearbyEnemies == 0 then
		if
			#nearbyCreeps >= 3
			and Fu.IsValid(nearbyCreeps[1])
			and not Fu.IsRunning(nearbyCreeps[1])
			and Fu.CanBeAttacked(nearbyCreeps[1])
			and isAttacking
		then
			if
				#nearbyTowers == 0
				or Fu.IsValidBuilding(nearbyTowers[1])
					and GetUnitToUnitDistance(nearbyCreeps[1], nearbyTowers[1]) > 900
			then
				bot.trample_status = { "laning", 0, nil }
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidHero(enemyHero)
			and not enemyHero:IsInvulnerable()
			and Fu.IsInRange(bot, enemyHero, radius)
			-- datafeed: Trample deals magical damage (base + a share of his attack damage).
			and Fu.CanKillTarget(enemyHero, baseDamage * duration, DAMAGE_TYPE_MAGICAL)
			and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
			and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
			and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
			and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
			and not enemyHero:HasModifier("modifier_item_blade_mail_reflect")
		then
			bot.trample_status = { "engaging", enemyHero:GetLocation(), enemyHero }
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if
			Fu.IsRoshan(botTarget)
			and not botTarget:IsAttackImmune()
			and Fu.IsInRange(bot, botTarget, radius)
			and isAttacking
		then
			bot.trample_status = { "miniboss", botTarget:GetLocation(), botTarget }
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, radius) and isAttacking then
			bot.trample_status = { "miniboss", botTarget:GetLocation(), botTarget }
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderUproar()
	if not Fu.CanCastAbility(uproarAbility) then
		return BOT_ACTION_DESIRE_NONE
	end
	local radius = uproarAbility:GetSpecialValueInt("radius")
	local uproarStacks = Fu.GetModifierCount(bot, "modifier_primal_beast_uproar")
	if isGoingOnSomeone then
		if
			Fu.IsValidTarget(botTarget)
			and Fu.IsInRange(bot, botTarget, radius)
			and not Fu.IsDisabled(botTarget)
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			if
				uproarStacks >= 4
				or Fu.IsChasingTarget(bot, botTarget) and uproarStacks >= 2
				or hpRatio < 0.5 and uproarStacks >= 3
				or hpRatio < 0.25 and uproarStacks >= 1
			then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	if isRetreating and not Fu.IsRealInvisible(bot) and bot:WasRecentlyDamagedByAnyHero(3) then
		if
			Fu.IsValidTarget(nearbyEnemies[1])
			and Fu.IsInRange(bot, nearbyEnemies[1], radius)
			and (Fu.IsChasingTarget(nearbyEnemies[1], bot) or hpRatio < 0.5)
			and not Fu.IsDisabled(nearbyEnemies[1])
			and uproarStacks >= 2
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderRockThrow()
	if not Fu.CanCastAbility(rockThrowAbility) then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local castRange = Fu.GetProperCastRange(false, bot, rockThrowAbility:GetCastRange())
	local castPoint = rockThrowAbility:GetCastPoint()
	local radius = rockThrowAbility:GetSpecialValueInt("impact_radius")
	local maxTravelTime = rockThrowAbility:GetSpecialValueFloat("max_travel_time")
	local minRange = rockThrowAbility:GetSpecialValueInt("min_range")
	local damage = rockThrowAbility:GetSpecialValueInt("base_damage")
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and not Fu.IsInRange(bot, enemyHero, minRange)
			and not Fu.IsSuspiciousIllusion(enemyHero)
		then
			if enemyHero:IsChanneling() then
				return BOT_ACTION_DESIRE_HIGH, enemyHero:GetLocation()
			end
			if
				Fu.WillKillTarget(enemyHero, damage, DAMAGE_TYPE_PHYSICAL, castPoint + maxTravelTime)
				and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
				and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
				and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
				and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
			then
				return BOT_ACTION_DESIRE_HIGH, Fu.GetCorrectLoc(enemyHero, castPoint + maxTravelTime)
			end
		end
	end
	if Fu.IsInTeamFight(bot, 1200) then
		local aoeLocation = bot:FindAoELocation(true, true, bot:GetLocation(), castRange, radius, castPoint, 0)
		local enemiesInRadius = Fu.GetEnemiesNearLoc(aoeLocation.targetloc, radius)
		if #enemiesInRadius >= 2 then
			return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
		end
	end
	-- Game data: 325 damage, 1.4s stun in 225, min range 550, travel 0.65-1.75s (taken as growing with
	-- distance over 550-1800). Was never thrown to start a fight or to stop a chaser.
	local function Flight(unit)
		local distance = Clamp(GetUnitToUnitDistance(bot, unit), minRange, 1800)
		return castPoint
			+ rockThrowAbility:GetSpecialValueFloat("min_travel_time")
			+ (distance - minRange)
				/ math.max(1800 - minRange, 1)
				* (maxTravelTime - rockThrowAbility:GetSpecialValueFloat("min_travel_time"))
	end
	local function Usable(unit)
		return Fu.IsValidHero(unit)
			and Fu.CanCastOnNonMagicImmune(unit)
			and not Fu.IsSuspiciousIllusion(unit)
			and not Fu.IsInRange(bot, unit, minRange)
			and Fu.IsInRange(bot, unit, castRange)
	end
	if isGoingOnSomeone and Usable(botTarget) and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe") then
		print(
			string.format(
				"[OHA-PRIMAL_BEAST] rock-throw why=engage target=%s dist=%d",
				botTarget:GetUnitName(),
				GetUnitToUnitDistance(bot, botTarget)
			)
		)
		return BOT_ACTION_DESIRE_HIGH, Fu.GetCorrectLoc(botTarget, Flight(botTarget))
	end
	if isRetreating then
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Usable(enemyHero)
				and Fu.IsInRange(bot, enemyHero, 1200)
				and (bot:WasRecentlyDamagedByHero(enemyHero, 2.0) or Fu.IsChasingTarget(enemyHero, bot))
			then
				print(
					string.format(
						"[OHA-PRIMAL_BEAST] rock-throw why=retreat target=%s dist=%d",
						enemyHero:GetUnitName(),
						GetUnitToUnitDistance(bot, enemyHero)
					)
				)
				return BOT_ACTION_DESIRE_HIGH, Fu.GetCorrectLoc(enemyHero, Flight(enemyHero))
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.ConsiderPulverize()
	if not Fu.CanCastAbility(pulverizeAbility) then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castRange = Fu.GetProperCastRange(false, bot, pulverizeAbility:GetCastRange())
	local bonusDamagePerHit = pulverizeAbility:GetSpecialValueInt("bonus_damage_per_hit")
	local damage = pulverizeAbility:GetSpecialValueInt("damage") + bonusDamagePerHit * 3
	local channelTime = pulverizeAbility:GetSpecialValueFloat("channel_time")
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.IsInRange(bot, enemyHero, castRange * 2)
			and Fu.CanCastOnMagicImmune(enemyHero)
			and Fu.CanCastOnTargetAdvanced(enemyHero)
		then
			if enemyHero:IsChanneling() and not Fu.IsInLaningPhase() then
				return BOT_ACTION_DESIRE_HIGH, enemyHero
			end
			if
				Fu.CanKillTarget(enemyHero, damage * channelTime, DAMAGE_TYPE_MAGICAL)
				and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
				and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
				and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
				and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
			then
				return BOT_ACTION_DESIRE_HIGH, enemyHero
			end
		end
	end
	if isGoingOnSomeone then
		if
			Fu.IsValidTarget(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange * 2)
			and Fu.CanCastOnMagicImmune(botTarget)
			and Fu.CanCastOnTargetAdvanced(botTarget)
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			if Fu.IsInLaningPhase() and not Fu.IsInTeamFight(bot, 1600) then
				local alliesNearTarget = Fu.GetAlliesNearLoc(botTarget:GetLocation(), 800)
				if botTarget:GetHealth() <= Fu.GetTotalEstimatedDamageToTarget(alliesNearTarget, botTarget) then
					return BOT_ACTION_DESIRE_HIGH, botTarget
				end
			else
				return BOT_ACTION_DESIRE_HIGH, botTarget
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
return X
