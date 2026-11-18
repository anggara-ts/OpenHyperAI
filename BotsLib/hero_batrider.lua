-- Batrider: skill build, item build, and ability use for this hero.
-- Accidental globals made file-local (#13): every bot shares one Lua state, so these were shared.
local HasBlink, CanBKB
local X = {}
local bot = GetBot()
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local AbilityContext = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local Minion = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local sTalentList = Fu.Skill.GetTalentList(bot)
local sAbilityList = Fu.Skill.GetAbilityList(bot)
local sRole = Fu.Item.GetRoleItemsBuyList(bot)
local tTalentTreeList = {
	{ ["t25"] = { 10, 0 }, ["t20"] = { 10, 0 }, ["t15"] = { 10, 0 }, ["t10"] = { 0, 10 } },
	{ ["t25"] = { 10, 0 }, ["t20"] = { 10, 0 }, ["t15"] = { 0, 10 }, ["t10"] = { 0, 10 } },
}
local tAllAbilityBuildList =
	{ { 1, 3, 1, 2, 1, 6, 1, 3, 3, 3, 6, 2, 2, 2, 6 }, { 1, 2, 1, 3, 1, 6, 1, 3, 3, 3, 6, 2, 2, 2, 6 } }
-- tAllAbilityBuildList[2]: Flaming Lasso moved to entry 11 (level 12); it sat at entry 12 (level 13), a level late.
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
	"item_double_branches",
	"item_faerie_fire",
	"item_bottle",
	"item_magic_wand",
	"item_travel_boots",
	"item_blink",
	"item_black_king_bar",
	"item_force_staff",
	"item_shivas_guard",
	"item_ultimate_scepter",
	"item_refresher",
	"item_overwhelming_blink",
	"item_ultimate_scepter_2",
	"item_travel_boots_2",
	"item_aghanims_shard",
	"item_moon_shard",
}
sRoleItemsBuyList["pos_3"] = {
	"item_tango",
	"item_gauntlets",
	"item_circlet",
	"item_double_branches",
	"item_bracer",
	"item_boots",
	"item_magic_wand",
	"item_wind_lace",
	"item_blink",
	"item_black_king_bar",
	"item_travel_boots",
	"item_shivas_guard",
	"item_ultimate_scepter",
	"item_force_staff",
	"item_refresher",
	"item_overwhelming_blink",
	"item_ultimate_scepter_2",
	"item_travel_boots_2",
	"item_aghanims_shard",
	"item_moon_shard",
}
sRoleItemsBuyList["pos_1"] = sRoleItemsBuyList["pos_3"]
sRoleItemsBuyList["pos_4"] = {
	"item_tango",
	"item_double_branches",
	"item_circlet",
	"item_blood_grenade",
	"item_boots",
	"item_magic_wand",
	"item_tranquil_boots",
	"item_blink",
	"item_force_staff",
	"item_black_king_bar",
	"item_boots_of_bearing",
	"item_shivas_guard",
	"item_wind_waker",
	"item_arcane_blink",
	"item_aghanims_shard",
	"item_ultimate_scepter_2",
	"item_moon_shard",
}
sRoleItemsBuyList["pos_5"] = {
	"item_tango",
	"item_double_branches",
	"item_circlet",
	"item_blood_grenade",
	"item_boots",
	"item_magic_wand",
	"item_arcane_boots",
	"item_blink",
	"item_force_staff",
	"item_black_king_bar",
	"item_guardian_greaves",
	"item_shivas_guard",
	"item_wind_waker",
	"item_arcane_blink",
	"item_aghanims_shard",
	"item_ultimate_scepter_2",
	"item_moon_shard",
}
X["sBuyList"] = sRoleItemsBuyList[sRole]
-- sSellList is read in pairs {owned, sold}. The per-position lists that used to overwrite it were
-- broken: pos_2 sold the Bottle as soon as Iron Branches were held, the pos_3 one-entry list sold nothing.
X["sSellList"] = {
	"item_shivas_guard",
	"item_branches",
	"item_shivas_guard",
	"item_bottle",
	"item_black_king_bar",
	"item_magic_wand",
}
if Fu.Role.IsPvNMode() or Fu.Role.IsAllShadow() then
	X["sBuyList"], X["sSellList"] = { "PvN_antimage" }, {}
end
nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"] =
	Fu.SetUserHeroInit(nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"])
X["sSkillList"] = Fu.Skill.GetSkillList(sAbilityList, nAbilityBuildList, sTalentList, nTalentBuildList)
X["bDeafaultAbility"] = false
X["bDeafaultItem"] = false
function X.MinionThink(minionUnit)
	Minion.MinionThink(minionUnit)
end
local stickyNapalmAbility =
	SafeAbility(bot:GetAbilityByName("batrider_sticky_napalm"), "batrider_sticky_napalm", "batrider")
local flamebreakAbility = SafeAbility(bot:GetAbilityByName("batrider_flamebreak"), "batrider_flamebreak", "batrider")
local fireflyAbility = SafeAbility(bot:GetAbilityByName("batrider_firefly"), "batrider_firefly", "batrider")
local flamingLassoAbility =
	SafeAbility(bot:GetAbilityByName("batrider_flaming_lasso"), "batrider_flaming_lasso", "batrider")
local stickyNapalmDesire, stickyNapalmLocation
local flamebreakDesire, flamebreakLocation
local fireflyDesire
local flamingLassoDesire, flamingLassoTarget
local bkbItem
local blinkItem
local blinkLocation
local blinkLassoDesire, blinkLassoTarget
if bot.shouldBlink == nil then
	bot.shouldBlink = false
end
local botTarget
local isGoingOnSomeone
local isRetreating
local hpRatio
-- fix: these helpers were globals; Beastmaster defines globals with the same names (HasBlink,
-- CanBKB), so if both bots share globals one hero's checks read the other's items. Forward-declared
-- locals: the "function X()" definitions at the bottom now assign these.
local CanDoBlinkLasso, HasBlink, CanBKB
function X.SkillsComplement()
	local context = AbilityContext.Build(bot)
	isGoingOnSomeone = context.isEngaging
	isRetreating = context.isRetreating
	hpRatio = context.hp
	if Fu.CanNotUseAbility(bot) then
		return
	end
	blinkLassoDesire, blinkLassoTarget = X.ConsiderBlinkLasso()
	if blinkLassoDesire > 0 then
		bot:Action_ClearActions(false)
		fireflyDesire = X.ConsiderFirefly()
		if fireflyDesire > 0 then
			bot:ActionQueue_UseAbility(fireflyAbility)
		end
		if CanBKB() then
			bot:ActionQueue_UseAbility(bkbItem)
			bot:ActionQueue_Delay(0.1)
		end
		bot:ActionQueue_UseAbilityOnLocation(blinkItem, blinkLocation)
		bot:ActionQueue_Delay(0.1)
		bot:ActionQueue_UseAbilityOnEntity(flamingLassoAbility, blinkLassoTarget)
		return
	end
	fireflyDesire = X.ConsiderFirefly()
	if fireflyDesire > 0 then
		bot:Action_UseAbility(fireflyAbility)
		return
	end
	flamingLassoDesire, flamingLassoTarget = X.ConsiderFlamingLasso()
	if flamingLassoDesire > 0 then
		bot:Action_UseAbilityOnEntity(flamingLassoAbility, flamingLassoTarget)
		return
	end
	flamebreakDesire, flamebreakLocation = X.ConsiderFlamebreak()
	if flamebreakDesire > 0 then
		bot:Action_UseAbilityOnLocation(flamebreakAbility, flamebreakLocation)
		return
	end
	stickyNapalmDesire, stickyNapalmLocation = X.ConsiderStickyNapalm()
	if stickyNapalmDesire > 0 then
		bot:Action_UseAbilityOnLocation(stickyNapalmAbility, stickyNapalmLocation)
		return
	end
end
function X.ConsiderStickyNapalm()
	if not stickyNapalmAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local castRange = stickyNapalmAbility:GetCastRange()
	local castPoint = stickyNapalmAbility:GetCastPoint()
	local radius = stickyNapalmAbility:GetSpecialValueInt("radius")
	local mpRatio = bot:GetMana() / bot:GetMaxMana()
	botTarget = Fu.GetProperTarget(bot)
	if isGoingOnSomeone then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, 800, false, BOT_MODE_NONE)
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not botTarget:HasModifier("modifier_dazzle_shallow_grave")
		then
			local targetAllies = Fu.GetNearbyHeroes(botTarget, 800, false, BOT_MODE_NONE)
			if nearbyAllies ~= nil and targetAllies ~= nil and #nearbyAllies >= #targetAllies then
				return BOT_ACTION_DESIRE_HIGH, botTarget:GetExtrapolatedLocation(castPoint)
			end
		end
	end
	if isRetreating then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, 800, false, BOT_MODE_NONE)
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, 800, true, BOT_MODE_NONE)
		if
			nearbyAllies ~= nil
			and nearbyEnemies
			and Fu.IsValidHero(nearbyEnemies[1])
			and Fu.CanCastOnNonMagicImmune(nearbyEnemies[1])
			and Fu.IsInRange(bot, nearbyEnemies[1], 350)
			and Fu.IsRunning(nearbyEnemies[1])
			and nearbyEnemies[1]:IsFacingLocation(bot:GetLocation(), 30)
			and not Fu.IsSuspiciousIllusion(nearbyEnemies[1])
		then
			local targetAllies = Fu.GetNearbyHeroes(nearbyEnemies[1], 800, false, BOT_MODE_NONE)
			if
				targetAllies ~= nil
				and (#targetAllies > #nearbyAllies or hpRatio < 0.57 and bot:WasRecentlyDamagedByAnyHero(2.7))
			then
				return BOT_ACTION_DESIRE_HIGH, nearbyEnemies[1]:GetExtrapolatedLocation(castPoint)
			end
		end
	end
	if Fu.IsDefending(bot) or Fu.IsPushing(bot) then
		local nearbyLaneCreeps = bot:GetNearbyLaneCreeps(castRange, true)
		local aoeLocation = bot:FindAoELocation(true, false, bot:GetLocation(), castRange, radius, 0, 0)
		if nearbyLaneCreeps ~= nil and #nearbyLaneCreeps >= 4 and aoeLocation.count >= 4 then
			return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
		end
		aoeLocation = bot:FindAoELocation(true, true, bot:GetLocation(), castRange, radius, castPoint, 0)
		if aoeLocation.count >= 1 then
			return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
		end
	end
	if Fu.IsFarming(bot) and mpRatio > 0.49 then
		local nearbyNeutrals = bot:GetNearbyNeutralCreeps(castRange)
		local aoeLocation = bot:FindAoELocation(true, false, bot:GetLocation(), castRange, radius, 0, 0)
		if nearbyNeutrals ~= nil and #nearbyNeutrals >= 2 and aoeLocation.count >= 2 then
			return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
		end
		local nearbyLaneCreeps = bot:GetNearbyLaneCreeps(castRange, true)
		if nearbyLaneCreeps ~= nil and #nearbyLaneCreeps >= 3 and aoeLocation.count >= 3 then
			return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
		end
	end
	if Fu.IsLaning(bot) and mpRatio > 0.68 then
		local nearbyLaneCreeps = bot:GetNearbyLaneCreeps(castRange, true)
		local aoeLocation = bot:FindAoELocation(true, false, bot:GetLocation(), castRange, radius, 0, 0)
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
		if nearbyEnemies ~= nil and #nearbyEnemies >= 1 then
			local enemyNearbyAllyCreeps = nearbyEnemies[1]:GetNearbyLaneCreeps(castRange / 2, false)
			if enemyNearbyAllyCreeps ~= nil and #enemyNearbyAllyCreeps >= 2 then
				return BOT_ACTION_DESIRE_HIGH, nearbyEnemies[1]:GetExtrapolatedLocation(castPoint)
			end
		end
		if nearbyLaneCreeps ~= nil and #nearbyLaneCreeps >= 3 and aoeLocation.count >= 3 then
			return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if
			Fu.IsRoshan(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and Fu.IsAttacking(bot)
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if
			Fu.IsTormentor(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and Fu.IsAttacking(bot)
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.ConsiderFlamebreak()
	if not flamebreakAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local castRange = flamebreakAbility:GetCastRange()
	local castPoint = flamebreakAbility:GetCastPoint()
	local radius = flamebreakAbility:GetSpecialValueInt("explosion_radius")
	local speed = flamebreakAbility:GetSpecialValueInt("speed")
	local damage = flamebreakAbility:GetSpecialValueInt("damage_impact")
	botTarget = Fu.GetProperTarget(bot)
	local enemiesInRange = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(enemiesInRange) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and Fu.IsInRange(bot, enemyHero, castRange)
			and Fu.CanKillTarget(enemyHero, damage, DAMAGE_TYPE_MAGICAL)
			and not Fu.IsSuspiciousIllusion(enemyHero)
			and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
			and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
			and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
			and not enemyHero:HasModifier("modifier_templar_assassin_refraction_absorb")
		then
			local travelTime = GetUnitToUnitDistance(bot, enemyHero) / speed + castPoint
			return BOT_ACTION_DESIRE_HIGH, enemyHero:GetExtrapolatedLocation(travelTime)
		end
	end
	if isGoingOnSomeone then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, 800, false, BOT_MODE_NONE)
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not botTarget:HasModifier("modifier_dazzle_shallow_grave")
			and not botTarget:HasModifier("modifier_enigma_black_hole_pull")
			and not botTarget:HasModifier("modifier_faceless_void_chronosphere_freeze")
			and not botTarget:HasModifier("modifier_legion_commander_duel")
		then
			local targetAllies = Fu.GetNearbyHeroes(botTarget, 800, false, BOT_MODE_NONE)
			if nearbyAllies ~= nil and targetAllies ~= nil and #nearbyAllies >= #targetAllies then
				local travelTime = GetUnitToUnitDistance(bot, botTarget) / speed + castPoint
				return BOT_ACTION_DESIRE_HIGH, botTarget:GetExtrapolatedLocation(travelTime)
			end
		end
	end
	if isRetreating then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, 800, false, BOT_MODE_NONE)
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, 800, true, BOT_MODE_NONE)
		if
			nearbyAllies ~= nil
			and nearbyEnemies
			and Fu.IsValidHero(nearbyEnemies[1])
			and Fu.CanCastOnNonMagicImmune(nearbyEnemies[1])
			and Fu.IsInRange(bot, nearbyEnemies[1], 350)
			and Fu.IsRunning(nearbyEnemies[1])
			and nearbyEnemies[1]:IsFacingLocation(bot:GetLocation(), 30)
			and not Fu.IsSuspiciousIllusion(nearbyEnemies[1])
		then
			local targetAllies = Fu.GetNearbyHeroes(nearbyEnemies[1], 800, false, BOT_MODE_NONE)
			if
				targetAllies ~= nil
				and (#targetAllies > #nearbyAllies or hpRatio < 0.57 and bot:WasRecentlyDamagedByAnyHero(2.7))
			then
				if GetUnitToUnitDistance(bot, nearbyEnemies[1]) < radius - 50 then
					return BOT_ACTION_DESIRE_HIGH, bot:GetLocation()
				else
					local travelTime = GetUnitToUnitDistance(bot, nearbyEnemies[1]) / speed + castPoint
					return BOT_ACTION_DESIRE_HIGH, nearbyEnemies[1]:GetExtrapolatedLocation(travelTime)
				end
			end
		end
	end
	if Fu.IsDefending(bot) then
		local aoeLocation = bot:FindAoELocation(true, true, bot:GetLocation(), castRange, radius, castPoint, 0)
		if aoeLocation.count >= 1 then
			return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
		end
	end
	if Fu.IsLaning(bot) and Fu.GetMP(bot) > 0.39 then
		local killableCount = 0
		local killableCreeps = {}
		local nearbyLaneCreeps = bot:GetNearbyLaneCreeps(castRange, true)
		for _, creep in pairs(nearbyLaneCreeps) do
			if Fu.IsValid(creep) and creep:GetHealth() <= damage then
				killableCount = killableCount + 1
				table.insert(killableCreeps, creep)
			end
		end
		if killableCount >= 2 then
			return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(killableCreeps)
		end
	end
	local alliesInRange = Fu.GetNearbyHeroes(bot, castRange, false, BOT_MODE_NONE)
	for _, allyHero in pairs(alliesInRange) do
		local allyNearbyEnemies = Fu.GetNearbyHeroes(allyHero, castRange, true, BOT_MODE_NONE)
		if
			Fu.IsRetreating(allyHero)
			and allyHero:WasRecentlyDamagedByAnyHero(2.1)
			and not allyHero:IsIllusion()
			and Fu.GetMP(bot) > 0.48
		then
			if
				allyNearbyEnemies ~= nil
				and #allyNearbyEnemies >= 1
				and Fu.IsValidHero(allyNearbyEnemies[1])
				and Fu.CanCastOnNonMagicImmune(allyNearbyEnemies[1])
				and Fu.IsInRange(allyHero, allyNearbyEnemies[1], 400)
				and Fu.IsInRange(bot, allyNearbyEnemies[1], castRange)
				and Fu.IsRunning(allyHero)
				and allyNearbyEnemies[1]:IsFacingLocation(allyHero:GetLocation(), 30)
				and not Fu.IsDisabled(allyNearbyEnemies[1])
				and not Fu.IsTaunted(allyNearbyEnemies[1])
				and not Fu.IsSuspiciousIllusion(allyNearbyEnemies[1])
				and not allyNearbyEnemies[1]:HasModifier("modifier_enigma_black_hole_pull")
				and not allyNearbyEnemies[1]:HasModifier("modifier_faceless_void_chronosphere_freeze")
			then
				local travelTime = GetUnitToUnitDistance(bot, allyNearbyEnemies[1]) / speed + castPoint
				return BOT_ACTION_DESIRE_HIGH, allyNearbyEnemies[1]:GetExtrapolatedLocation(travelTime)
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.ConsiderFirefly()
	if not fireflyAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
	end
	botTarget = Fu.GetProperTarget(bot)
	if Fu.IsStuck(bot) or bot:HasModifier("modifier_batrider_flaming_lasso_self") or blinkLassoDesire > 0 then
		return BOT_ACTION_DESIRE_HIGH
	end
	if isGoingOnSomeone then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, 800, false, BOT_MODE_NONE)
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, 800)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not botTarget:HasModifier("modifier_dazzle_shallow_grave")
		then
			local targetAllies = Fu.GetNearbyHeroes(botTarget, 800, false, BOT_MODE_NONE)
			if nearbyAllies ~= nil and targetAllies ~= nil and #nearbyAllies >= #targetAllies then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	if isRetreating then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, 800, false, BOT_MODE_NONE)
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, 800, true, BOT_MODE_NONE)
		if
			nearbyAllies ~= nil
			and nearbyEnemies
			and Fu.IsValidHero(nearbyEnemies[1])
			and Fu.CanCastOnNonMagicImmune(nearbyEnemies[1])
			and Fu.IsInRange(bot, nearbyEnemies[1], 350)
			and Fu.IsRunning(nearbyEnemies[1])
			and nearbyEnemies[1]:IsFacingLocation(bot:GetLocation(), 30)
			and not Fu.IsSuspiciousIllusion(nearbyEnemies[1])
		then
			local targetAllies = Fu.GetNearbyHeroes(nearbyEnemies[1], 800, false, BOT_MODE_NONE)
			if
				targetAllies ~= nil
				and (#targetAllies > #nearbyAllies or hpRatio < 0.57 and bot:WasRecentlyDamagedByAnyHero(2.1))
			then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
		-- fix: Firefly (bonus move speed, flies over trees) was an escape only vs a chaser within 350
		-- that faced him. Also use it when a hero hurt him recently and one is still within 900.
		if
			bot:WasRecentlyDamagedByAnyHero(2.0)
			and nearbyEnemies ~= nil
			and Fu.IsValidHero(nearbyEnemies[1])
			and Fu.IsInRange(bot, nearbyEnemies[1], 900)
		then
			if DotaTime() >= (bot._batFireflyLogAt or -999) then
				bot._batFireflyLogAt = DotaTime() + 10
				pcall(print, string.format("[OHA-BATRIDER] t=%.0f firefly escape hp=%.2f", DotaTime(), hpRatio))
			end
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderFlamingLasso()
	if not flamingLassoAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
	end
	local castRange = flamingLassoAbility:GetCastRange() + bot:GetAttackRange()
	-- fix: was "isGoingOnSomeone and not CanDoBlinkLasso()". Blink-Lasso is considered first; when it declined
	-- (target conditions failed) a plain Lasso was still blocked just because a Blink was ready.
	if isGoingOnSomeone then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, 800, false, BOT_MODE_NONE)
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValidTarget(enemyHero)
				and Fu.CanCastOnMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and not Fu.IsTaunted(enemyHero)
				and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
				and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
				and not enemyHero:HasModifier("modifier_enigma_black_hole_pull")
				and not enemyHero:HasModifier("modifier_faceless_void_chronosphere_freeze")
				and not enemyHero:HasModifier("modifier_legion_commander_duel")
				and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
			then
				local targetAllies = Fu.GetNearbyHeroes(enemyHero, 800, false, BOT_MODE_NONE)
				if nearbyAllies ~= nil and targetAllies ~= nil and #nearbyAllies >= #targetAllies then
					return BOT_ACTION_DESIRE_HIGH, enemyHero
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function X.ConsiderBlinkLasso()
	if CanDoBlinkLasso() then
		local lassoDuration = flamingLassoAbility:GetSpecialValueInt("duration")
		if isGoingOnSomeone then
			local nearbyAllies = Fu.GetNearbyHeroes(bot, 1199, false, BOT_MODE_NONE)
			local strongestTarget = Fu.GetStrongestUnit(1199, bot, true, false, lassoDuration)
			if strongestTarget == nil then
				strongestTarget = Fu.GetStrongestUnit(1199, bot, true, true, lassoDuration)
			end
			if
				Fu.IsValidTarget(strongestTarget)
				and Fu.CanCastOnMagicImmune(strongestTarget)
				and Fu.CanCastOnTargetAdvanced(strongestTarget)
				and Fu.IsInRange(bot, strongestTarget, 1199)
				-- fix: no Blink when the target is already in Lasso range (200); plain Lasso does it.
				and not Fu.IsInRange(bot, strongestTarget, flamingLassoAbility:GetCastRange() + 50)
				and not Fu.IsSuspiciousIllusion(strongestTarget)
				and not Fu.IsTaunted(strongestTarget)
				and not strongestTarget:HasModifier("modifier_abaddon_borrowed_time")
				and not strongestTarget:HasModifier("modifier_dazzle_shallow_grave")
				and not strongestTarget:HasModifier("modifier_enigma_black_hole_pull")
				and not strongestTarget:HasModifier("modifier_faceless_void_chronosphere_freeze")
				and not strongestTarget:HasModifier("modifier_legion_commander_duel")
				and not strongestTarget:HasModifier("modifier_necrolyte_reapers_scythe")
			then
				local targetAllies = Fu.GetNearbyHeroes(strongestTarget, 1199, false, BOT_MODE_NONE)
				if nearbyAllies ~= nil and targetAllies ~= nil and #nearbyAllies >= #targetAllies then
					bot.shouldBlink = true
					blinkLocation = strongestTarget:GetLocation()
					return BOT_ACTION_DESIRE_HIGH, strongestTarget
				end
			end
		end
	end
	bot.shouldBlink = false
	return BOT_ACTION_DESIRE_NONE, nil
end
function CanDoBlinkLasso()
	if flamingLassoAbility:IsFullyCastable() and HasBlink() then
		local manaCost = flamingLassoAbility:GetManaCost()
		if bot:GetMana() >= manaCost then
			return true
		end
	end
	return false
end
function HasBlink()
	local blink = nil
	for slot = 0, 5 do
		local item = bot:GetItemInSlot(slot)
		if
			item ~= nil
			and (
				item:GetName() == "item_blink"
				or item:GetName() == "item_overwhelming_blink"
				or item:GetName() == "item_arcane_blink"
				or item:GetName() == "item_swift_blink"
			)
		then
			blink = item
			break
		end
	end
	if blink ~= nil and blink:IsFullyCastable() then
		blinkItem = blink
		return true
	end
	return false
end
function CanBKB()
	local bkb = nil
	for slot = 0, 5 do
		local item = bot:GetItemInSlot(slot)
		if item ~= nil and item:GetName() == "item_black_king_bar" then
			bkb = item
			break
		end
	end
	if bkb ~= nil and bkb:IsFullyCastable() and bot:GetMana() >= 75 then
		bkbItem = bkb
		return true
	end
	return false
end
return X
