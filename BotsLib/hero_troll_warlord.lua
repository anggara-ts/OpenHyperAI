-- Troll Warlord: skill build, item build, and ability use for this hero.
local X = {}
local bot = GetBot()
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local AbilityContext = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local Minion = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local sTalentList = Fu.Skill.GetTalentList(bot)
local sAbilityList = Fu.Skill.GetAbilityList(bot)
local sRole = Fu.Item.GetRoleItemsBuyList(bot)
local tTalentTreeList = { ["t25"] = { 10, 0 }, ["t20"] = { 0, 10 }, ["t15"] = { 0, 10 }, ["t10"] = { 10, 0 } }
local tAllAbilityBuildList = { { 2, 5, 4, 4, 2, 6, 2, 4, 4, 2, 6, 5, 5, 5, 6 } }
local nAbilityBuildList = Fu.Skill.GetRandomBuild(tAllAbilityBuildList)
local nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList)
local sRoleItemsBuyList = {}
sRoleItemsBuyList["pos_1"] = {
	"item_tango",
	"item_double_branches",
	"item_quelling_blade",
	"item_magic_wand",
	"item_wraith_band",
	"item_phase_boots",
	"item_bfury",
	"item_yasha",
	"item_black_king_bar",
	"item_sange_and_yasha",
	"item_aghanims_shard",
	"item_satanic",
	"item_moon_shard",
	"item_abyssal_blade",
	"item_travel_boots_2",
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
function X.MinionThink(minion)
	Minion.MinionThink(minion)
end
local battleStanceAbility = bot:GetAbilityInSlot(0)
local berserkersRageAbility =
	SafeAbility(bot:GetAbilityByName("troll_warlord_berserkers_rage"), "troll_warlord_berserkers_rage", "troll_warlord")
local whirlingAxesRangedAbility = SafeAbility(
	bot:GetAbilityByName("troll_warlord_whirling_axes_ranged"),
	"troll_warlord_whirling_axes_ranged",
	"troll_warlord"
)
local whirlingAxesMeleeAbility = SafeAbility(
	bot:GetAbilityByName("troll_warlord_whirling_axes_melee"),
	"troll_warlord_whirling_axes_melee",
	"troll_warlord"
)
local battleTranceAbility =
	SafeAbility(bot:GetAbilityByName("troll_warlord_battle_trance"), "troll_warlord_battle_trance", "troll_warlord")
local berserkersRageDesire
local whirlingAxesRangedDesire, whirlingAxesRangedLocation
local whirlingAxesMeleeDesire
local battleTranceDesire
local botTarget
local isGoingOnSomeone
local isRetreating
local isAttacking
local hpRatio
local mpRatio
function X.SkillsComplement()
	-- [OHA-TROLL] Battle Trance cast check: the npc file gives it no AbilityBehavior (datafeed
	-- behavior 0, target team both, range 525), so it is unverified that a no-target order casts it.
	-- 1s after an order, print whether the cooldown started (at most once per 10s).
	if bot._trollTranceAt ~= nil and DotaTime() > bot._trollTranceAt + 1 then
		if DotaTime() >= (bot._trollTranceLogAt or -999) then
			bot._trollTranceLogAt = DotaTime() + 10
			pcall(
				print,
				string.format(
					"[OHA-TROLL] t=%.0f battle-trance order cooldownStarted=%s",
					DotaTime(),
					tostring(battleTranceAbility:GetCooldownTimeRemaining() > 0)
				)
			)
		end
		bot._trollTranceAt = nil
	end
	if Fu.CanNotUseAbility(bot) then
		return
	end
	isGoingOnSomeone = Fu.IsGoingOnSomeone(bot)
	isRetreating = Fu.IsRetreating(bot)
	isAttacking = Fu.IsAttacking(bot)
	hpRatio = Fu.GetHP(bot)
	mpRatio = Fu.GetMP(bot)
	botTarget = Fu.GetProperTarget(bot)
	battleTranceDesire = X.ConsiderBattleTrance()
	if battleTranceDesire > 0 then
		bot._trollTranceAt = bot._trollTranceAt or DotaTime()
		bot:Action_UseAbility(battleTranceAbility)
		return
	end
	if battleStanceAbility:IsFullyCastable() and battleStanceAbility:IsTrained() then
		berserkersRageAbility = battleStanceAbility
	end
	berserkersRageDesire = X.ConsiderBerserkersRage(berserkersRageAbility)
	if berserkersRageDesire > 0 then
		bot:Action_UseAbility(berserkersRageAbility)
		return
	end
	whirlingAxesRangedDesire, whirlingAxesRangedLocation = X.ConsiderWhirlingAxesRanged()
	if whirlingAxesRangedDesire > 0 then
		bot:Action_UseAbilityOnLocation(whirlingAxesRangedAbility, whirlingAxesRangedLocation)
		return
	end
	whirlingAxesMeleeDesire = X.ConsiderWhirlingAxesMelee()
	if whirlingAxesMeleeDesire > 0 then
		bot:Action_UseAbility(whirlingAxesMeleeAbility)
		return
	end
end
function X.ConsiderBerserkersRage(stanceAbility)
	if not stanceAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
	end
	local bonusRange = stanceAbility:GetSpecialValueInt("bonus_range")
	-- datafeed: bonus_move_speed (melee form) is on the passive Berserker's Rage. stanceAbility is the Battle
	-- Stance toggle here (slot 0), which has no such key, so bonusMoveSpeed read 0 and the retreat stance swap
	-- below (enemy faster than Troll, slower than Troll + bonusMoveSpeed) could never fire.
	local rage = bot:GetAbilityByName("troll_warlord_berserkers_rage")
	local bonusMoveSpeed = (rage ~= nil and not rage:IsNull()) and rage:GetSpecialValueInt("bonus_move_speed")
		or stanceAbility:GetSpecialValueInt("bonus_move_speed")
	local enemyHeroes = Fu.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE)
	if isGoingOnSomeone then
		if Fu.IsValidTarget(botTarget) and not Fu.IsSuspiciousIllusion(botTarget) then
			if Fu.IsChasingTarget(bot, botTarget) and not Fu.IsLocationInChrono(botTarget:GetLocation()) then
				if stanceAbility:GetToggleState() == false then
					return BOT_ACTION_DESIRE_HIGH
				else
					return BOT_ACTION_DESIRE_NONE
				end
			else
				if
					isAttacking
					and Fu.IsInRange(bot, botTarget, 150)
					and stanceAbility:GetToggleState() == false
					and not Fu.IsChasingTarget(bot, botTarget)
				then
					if stanceAbility:GetToggleState() == false then
						return BOT_ACTION_DESIRE_HIGH
					else
						return BOT_ACTION_DESIRE_NONE
					end
				end
			end
		end
	end
	if isRetreating then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, 1200, false, BOT_MODE_NONE)
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE)
		if
			nearbyAllies ~= nil
			and nearbyEnemies ~= nil
			and Fu.IsValidHero(nearbyEnemies[1])
			and Fu.IsChasingTarget(nearbyEnemies[1], bot)
			and not Fu.IsSuspiciousIllusion(nearbyEnemies[1])
			and not Fu.IsDisabled(nearbyEnemies[1])
		then
			local enemiesNearChaser = Fu.GetNearbyHeroes(nearbyEnemies[1], 1200, false, BOT_MODE_NONE)
			if
				enemiesNearChaser ~= nil
				and (#enemiesNearChaser > #nearbyAllies or bot:WasRecentlyDamagedByAnyHero(1.5))
			then
				if
					nearbyEnemies[1]:GetCurrentMovementSpeed() > bot:GetCurrentMovementSpeed()
					and nearbyEnemies[1]:GetCurrentMovementSpeed() < bot:GetCurrentMovementSpeed() + bonusMoveSpeed
				then
					if stanceAbility:GetToggleState() == false then
						return BOT_ACTION_DESIRE_HIGH
					else
						return BOT_ACTION_DESIRE_NONE
					end
				end
			end
		end
	end
	if Fu.IsPushing(bot) then
		if enemyHeroes ~= nil and #enemyHeroes == 0 then
			if stanceAbility:GetToggleState() == false then
				return BOT_ACTION_DESIRE_HIGH
			else
				return BOT_ACTION_DESIRE_NONE
			end
		else
			if stanceAbility:GetToggleState() == true then
				return BOT_ACTION_DESIRE_HIGH
			else
				return BOT_ACTION_DESIRE_NONE
			end
		end
	end
	if Fu.IsFarming(bot) then
		if stanceAbility:GetToggleState() == false then
			return BOT_ACTION_DESIRE_HIGH
		else
			return BOT_ACTION_DESIRE_NONE
		end
	end
	if Fu.IsLaning(bot) then
		local maxEnemyAttackRange = 0
		for _, enemyHero in pairs(enemyHeroes) do
			if
				Fu.IsValidHero(enemyHero)
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and enemyHero:GetAttackRange() > maxEnemyAttackRange
			then
				maxEnemyAttackRange = enemyHero:GetAttackRange()
			end
		end
		if maxEnemyAttackRange < 324 then
			if stanceAbility:GetToggleState() == false then
				return BOT_ACTION_DESIRE_HIGH
			else
				return BOT_ACTION_DESIRE_NONE
			end
		end
		if maxEnemyAttackRange > 324 then
			if stanceAbility:GetToggleState() == true then
				return BOT_ACTION_DESIRE_HIGH
			else
				return BOT_ACTION_DESIRE_NONE
			end
		end
	end
	if stanceAbility:GetToggleState() == false then
		return BOT_ACTION_DESIRE_HIGH
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderWhirlingAxesRanged()
	-- CanCastAbility also rejects an unlearned or hidden ability. Whether a stance hides one of the
	-- axes is not verified; if it does, the order failed and the caller returned before the melee axes.
	if not Fu.CanCastAbility(whirlingAxesRangedAbility) then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local castRange = Fu.GetProperCastRange(false, bot, whirlingAxesRangedAbility:GetCastRange())
	local castPoint = whirlingAxesRangedAbility:GetCastPoint()
	local axeWidth = whirlingAxesRangedAbility:GetSpecialValueInt("axe_width")
	local axeSpeed = whirlingAxesRangedAbility:GetSpecialValueInt("axe_speed")
	local damage = whirlingAxesRangedAbility:GetSpecialValueInt("axe_damage")
	local enemiesInRange = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(enemiesInRange) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and Fu.CanKillTarget(enemyHero, damage, DAMAGE_TYPE_MAGICAL)
			and not Fu.IsSuspiciousIllusion(enemyHero)
			and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
			and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
			and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
			and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
			and not enemyHero:HasModifier("modifier_templar_assassin_refraction_absorb")
		then
			local delay = GetUnitToUnitDistance(bot, enemyHero) / axeSpeed + castPoint
			return BOT_ACTION_DESIRE_HIGH, enemyHero:GetExtrapolatedLocation(delay)
		end
	end
	if isGoingOnSomeone then
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not Fu.IsDisabled(botTarget)
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
			and not botTarget:HasModifier("modifier_templar_assassin_refraction_absorb")
		then
			local alliesNearTarget = Fu.GetNearbyHeroes(botTarget, 1200, true, BOT_MODE_NONE)
			local enemiesNearTarget = Fu.GetNearbyHeroes(botTarget, 1200, false, BOT_MODE_NONE)
			if alliesNearTarget ~= nil and enemiesNearTarget ~= nil and #alliesNearTarget >= #enemiesNearTarget then
				local delay = GetUnitToUnitDistance(bot, botTarget) / axeSpeed + castPoint
				return BOT_ACTION_DESIRE_HIGH, botTarget:GetExtrapolatedLocation(delay)
			end
		end
	end
	if isRetreating then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, 1200, false, BOT_MODE_NONE)
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE)
		if
			nearbyAllies ~= nil
			and nearbyEnemies ~= nil
			and Fu.IsValidHero(nearbyEnemies[1])
			and Fu.CanCastOnNonMagicImmune(nearbyEnemies[1])
			and Fu.IsChasingTarget(nearbyEnemies[1], bot)
			-- "and isAttacking" (Troll in his attack animation) removed: a fleeing Troll is not attacking,
			-- so the slow on the chaser almost never went out.
			and not Fu.IsSuspiciousIllusion(nearbyEnemies[1])
			and not Fu.IsDisabled(nearbyEnemies[1])
			and not nearbyEnemies[1]:HasModifier("modifier_enigma_black_hole_pull")
			and not nearbyEnemies[1]:HasModifier("modifier_faceless_void_chronosphere_freeze")
			and not nearbyEnemies[1]:HasModifier("modifier_legion_commander_duel")
			and not nearbyEnemies[1]:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			local enemiesNearChaser = Fu.GetNearbyHeroes(nearbyEnemies[1], 1200, false, BOT_MODE_NONE)
			if
				enemiesNearChaser ~= nil
				and (#enemiesNearChaser > #nearbyAllies or bot:WasRecentlyDamagedByAnyHero(1.5))
			then
				return BOT_ACTION_DESIRE_HIGH, nearbyEnemies[1]:GetLocation()
			end
		end
		for _, enemyHero in pairs(enemiesInRange) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.CanKillTarget(enemyHero, damage, DAMAGE_TYPE_MAGICAL)
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
				and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
				and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
				and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
				and not enemyHero:HasModifier("modifier_templar_assassin_refraction_absorb")
			then
				return BOT_ACTION_DESIRE_HIGH, enemyHero:GetLocation()
			end
		end
	end
	if Fu.IsPushing(bot) then
		local aoeLocation = bot:FindAoELocation(true, false, bot:GetLocation(), castRange, axeWidth, castPoint, 0)
		local laneCreeps = bot:GetNearbyLaneCreeps(castRange, true)
		if laneCreeps ~= nil and #laneCreeps >= 4 and aoeLocation.count >= 4 then
			return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(laneCreeps)
		end
		aoeLocation = bot:FindAoELocation(true, true, bot:GetLocation(), castRange, axeWidth, castPoint, 0)
		if aoeLocation.count >= 1 then
			return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
		end
	end
	if Fu.IsFarming(bot) then
		local aoeLocation = bot:FindAoELocation(true, false, bot:GetLocation(), castRange, axeWidth, castPoint, 0)
		if isAttacking then
			local neutralCreeps = bot:GetNearbyNeutralCreeps(castRange)
			if
				neutralCreeps ~= nil
				and (#neutralCreeps >= 3 and aoeLocation.count >= 3 or #neutralCreeps >= 2 and neutralCreeps[1]:IsAncientCreep() and aoeLocation.count >= 2)
				and mpRatio > 0.3
			then
				return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(neutralCreeps)
			end
			local laneCreeps = bot:GetNearbyLaneCreeps(castRange, true)
			if laneCreeps ~= nil and #laneCreeps >= 3 and aoeLocation.count >= 3 and mpRatio > 0.3 then
				return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(laneCreeps)
			end
		end
	end
	if Fu.IsLaning(bot) then
		local killableCount = 0
		local killableCreeps = {}
		local laneCreeps = bot:GetNearbyLaneCreeps(castRange, true)
		local laneEnemies = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
		for _, creep in pairs(laneCreeps) do
			if Fu.IsValid(creep) and creep:GetHealth() <= damage then
				killableCount = killableCount + 1
				table.insert(killableCreeps, creep)
			end
		end
		if
			killableCount >= 2
			and mpRatio > 0.25
			and laneEnemies ~= nil
			and #laneEnemies >= 1
			and Fu.CanBeAttacked(killableCreeps[1])
		then
			return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(killableCreeps)
		end
		if
			laneEnemies ~= nil
			and #laneEnemies ~= nil
			and Fu.IsValidHero(laneEnemies[1])
			and Fu.IsAttacking(laneEnemies[1])
			and Fu.CanCastOnNonMagicImmune(laneEnemies[1])
			and mpRatio > 0.5
			and hpRatio < Fu.GetHP(laneEnemies[1])
			and laneEnemies[1]:GetAttackTarget() == bot
		then
			return BOT_ACTION_DESIRE_HIGH, laneEnemies[1]:GetLocation()
		end
	end
	-- Roshan branch removed: datafeed note "Does not affect Roshan" (both axes), a wasted cast.
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, 500) and isAttacking then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.ConsiderWhirlingAxesMelee()
	-- CanCastAbility: also rejects the unlearned / hidden melee axes (see the ranged axes).
	if not Fu.CanCastAbility(whirlingAxesMeleeAbility) then
		return BOT_ACTION_DESIRE_NONE
	end
	-- datafeed: max_range and damage belong to Whirling Axes (Melee) (whirlingAxesMeleeAbility); read from the ranged
	-- axes (whirlingAxesRangedAbility) they were 0, so the search radius was 0.
	local maxRange = whirlingAxesMeleeAbility:GetSpecialValueInt("max_range")
	local damage = whirlingAxesMeleeAbility:GetSpecialValueInt("damage")
	local enemiesInRange = Fu.GetNearbyHeroes(bot, maxRange, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(enemiesInRange) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and Fu.CanKillTarget(enemyHero, damage, DAMAGE_TYPE_MAGICAL)
			and not Fu.IsSuspiciousIllusion(enemyHero)
			and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
			and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
			and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
			and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
			and not enemyHero:HasModifier("modifier_templar_assassin_refraction_absorb")
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if isGoingOnSomeone then
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, maxRange)
			and isAttacking
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not Fu.IsDisabled(botTarget)
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
			and not botTarget:HasModifier("modifier_templar_assassin_refraction_absorb")
		then
			local alliesNearTarget = Fu.GetNearbyHeroes(botTarget, 1200, true, BOT_MODE_NONE)
			local enemiesNearTarget = Fu.GetNearbyHeroes(botTarget, 1200, false, BOT_MODE_NONE)
			if alliesNearTarget ~= nil and enemiesNearTarget ~= nil and #alliesNearTarget >= #enemiesNearTarget then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	if isRetreating then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, 1200, false, BOT_MODE_NONE)
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE)
		if
			nearbyAllies ~= nil
			and nearbyEnemies
			and Fu.IsValidHero(nearbyEnemies[1])
			and Fu.IsInRange(bot, nearbyEnemies[1], maxRange)
			and Fu.IsChasingTarget(nearbyEnemies[1], bot)
			and not Fu.IsSuspiciousIllusion(nearbyEnemies[1])
			and not Fu.IsDisabled(nearbyEnemies[1])
			and not nearbyEnemies[1]:HasModifier("modifier_necrolyte_reapers_scythe")
			and not nearbyEnemies[1]:HasModifier("modifier_troll_warlord_whirling_axes_slow")
		then
			local enemiesNearChaser = Fu.GetNearbyHeroes(nearbyEnemies[1], 1200, false, BOT_MODE_NONE)
			if
				enemiesNearChaser ~= nil
				and (#enemiesNearChaser > #nearbyAllies or bot:WasRecentlyDamagedByAnyHero(1.5))
			then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
		for _, enemyHero in pairs(enemiesInRange) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.CanKillTarget(enemyHero, damage, DAMAGE_TYPE_MAGICAL)
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
				and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
				and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
				and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
				and not enemyHero:HasModifier("modifier_templar_assassin_refraction_absorb")
			then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	if Fu.IsPushing(bot) then
		local laneCreeps = bot:GetNearbyLaneCreeps(maxRange, true)
		if laneCreeps ~= nil and #laneCreeps >= 4 then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsFarming(bot) then
		if isAttacking then
			local neutralCreeps = bot:GetNearbyNeutralCreeps(maxRange)
			if
				neutralCreeps ~= nil
				and (#neutralCreeps >= 3 or #neutralCreeps >= 2 and neutralCreeps[1]:IsAncientCreep())
				and mpRatio > 0.3
			then
				return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(neutralCreeps)
			end
			local laneCreeps = bot:GetNearbyLaneCreeps(maxRange, true)
			if laneCreeps ~= nil and #laneCreeps >= 3 and mpRatio > 0.3 then
				return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(laneCreeps)
			end
		end
	end
	if Fu.IsLaning(bot) then
		local killableCount = 0
		local killableCreeps = {}
		local laneCreeps = bot:GetNearbyLaneCreeps(maxRange, true)
		local laneEnemies = Fu.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE)
		for _, creep in pairs(laneCreeps) do
			if Fu.IsValid(creep) and creep:GetHealth() <= damage then
				killableCount = killableCount + 1
				table.insert(killableCreeps, creep)
			end
		end
		if
			killableCount >= 2
			and mpRatio > 0.25
			and laneEnemies ~= nil
			and #laneEnemies >= 1
			and Fu.CanBeAttacked(killableCreeps[1])
		then
			return BOT_ACTION_DESIRE_HIGH
		end
		if
			laneEnemies ~= nil
			and #laneEnemies ~= nil
			and Fu.IsValidHero(laneEnemies[1])
			and Fu.IsAttacking(laneEnemies[1])
			and Fu.CanCastOnNonMagicImmune(laneEnemies[1])
			and mpRatio > 0.5
			and hpRatio < Fu.GetHP(laneEnemies[1])
			and laneEnemies[1]:GetAttackTarget() == bot
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	-- Roshan branch removed: datafeed note "Does not affect Roshan" (both axes), a wasted cast.
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, 500) and isAttacking then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderBattleTrance()
	if not battleTranceAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
	end
	if Fu.IsInTeamFight(bot, 1200) and Fu.IsValidTarget(botTarget) then
		local alliesNearTarget = Fu.GetNearbyHeroes(botTarget, 1200, true, BOT_MODE_NONE)
		local enemiesNearTarget = Fu.GetNearbyHeroes(botTarget, 1200, false, BOT_MODE_NONE)
		if hpRatio < 0.4 and #enemiesNearTarget >= #alliesNearTarget then
			return BOT_ACTION_DESIRE_MODERATE
		end
	end
	local tranceDuration = battleTranceAbility:GetSpecialValueInt("trance_duration")
	if isGoingOnSomeone then
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanBeAttacked(botTarget)
			and Fu.IsInRange(bot, botTarget, 600)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not botTarget:HasModifier("modifier_dazzle_shallow_grave")
			and not botTarget:HasModifier("modifier_faceless_void_chronosphere_freeze")
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
			and not botTarget:HasModifier("modifier_templar_assassin_refraction_absorb")
			and not botTarget:HasModifier("modifier_item_blade_mail_reflect")
		then
			local alliesNearTarget = Fu.GetNearbyHeroes(botTarget, 1200, true, BOT_MODE_NONE)
			local enemiesNearTarget = Fu.GetNearbyHeroes(botTarget, 1200, false, BOT_MODE_NONE)
			local estimatedDamage =
				bot:GetEstimatedDamageToTarget(false, botTarget, tranceDuration, DAMAGE_TYPE_PHYSICAL)
			if
				alliesNearTarget ~= nil
				and enemiesNearTarget ~= nil
				and #alliesNearTarget >= #enemiesNearTarget
				and #alliesNearTarget < #enemiesNearTarget + 2
				and estimatedDamage >= botTarget:GetHealth()
			then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
		local closeEnemies = Fu.GetEnemiesNearLoc(bot:GetLocation(), 600)
		if
			closeEnemies ~= nil
			and #closeEnemies >= 1
			and hpRatio < 0.3
			and Fu.IsValidHero(closeEnemies[1])
			and isAttacking
			and not Fu.IsLocationInChrono(closeEnemies[1]:GetLocation())
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsDoingRoshan(bot) then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, 600, false, BOT_MODE_NONE)
		if
			Fu.IsRoshan(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, 500)
			and isAttacking
			and nearbyAllies ~= nil
			and #nearbyAllies >= 2
			and Fu.IsAttacking(nearbyAllies[1])
			and Fu.IsAttacking(nearbyAllies[2])
			and DotaTime() < 35 * 60
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, 500) and isAttacking and hpRatio < 0.35 then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if isRetreating then
		local closeEnemies = Fu.GetEnemiesNearLoc(bot:GetLocation(), 500)
		if
			closeEnemies ~= nil
			and #closeEnemies >= 1
			and hpRatio < 0.3
			and Fu.IsValidHero(closeEnemies[1])
			and closeEnemies[1]:IsFacingLocation(bot:GetLocation(), 35)
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
return X
