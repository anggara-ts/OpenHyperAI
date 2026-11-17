-- Magnataur: skill build, item build, and ability use for this hero.
local X = {}
local bot = GetBot()
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local AbilityContext = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local Minion = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local sTalentList = Fu.Skill.GetTalentList(bot)
local sAbilityList = Fu.Skill.GetAbilityList(bot)
local sRole = Fu.Item.GetRoleItemsBuyList(bot)
local tTalentTreeList = { ["t25"] = { 10, 0 }, ["t20"] = { 10, 0 }, ["t15"] = { 10, 0 }, ["t10"] = { 0, 10 } }
-- Ultimate ranks need levels 6/12/18: entry 10 (level 11) and entry 14 (level 16) could not take
-- it, so those points went to the fallback. Moved to entry 11 (level 12) / entry 15.
local tAllAbilityBuildList = {
	-- Shockwave maxed first, Skewer second, Empower last (Dotabuff most picked order).
	["pos_2"] = { 1, 3, 1, 3, 1, 6, 1, 3, 3, 2, 6, 2, 2, 2, 6 },
	["pos_3"] = { 1, 3, 1, 3, 1, 6, 1, 3, 3, 2, 6, 2, 2, 2, 6 },
	["pos_4"] = { 1, 3, 1, 2, 1, 6, 1, 2, 3, 3, 6, 3, 2, 2, 6 },
	["pos_5"] = { 1, 3, 1, 2, 1, 6, 1, 2, 3, 3, 6, 3, 2, 2, 6 },
}
local nAbilityBuildList = tAllAbilityBuildList[sRole] or { 1, 3, 2, 2, 2, 6, 2, 3, 3, 3, 6, 1, 1, 1, 6 }
local nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList)
local sTeamAuraItem = "item_team_aura"
local sRoleItemsBuyList = {}
sRoleItemsBuyList["pos_3"] = {
	"item_tango",
	"item_double_branches",
	"item_double_circlet",
	"item_bracer",
	"item_wraith_band",
	"item_magic_wand",
	"item_power_treads",
	"item_blink",
	"item_crimson_guard",
	"item_echo_sabre",
	"item_black_king_bar",
	"item_harpoon",
	sTeamAuraItem,
	"item_sheepstick",
	"item_aghanims_shard",
	"item_travel_boots",
	"item_arcane_blink",
	"item_travel_boots_2",
	"item_ultimate_scepter_2",
	"item_moon_shard",
}
sRoleItemsBuyList["pos_1"] = sRoleItemsBuyList["pos_3"]
sRoleItemsBuyList["pos_2"] = {
	"item_quelling_blade",
	"item_double_branches",
	"item_tango",
	"item_circlet",
	"item_bottle",
	"item_wraith_band",
	"item_magic_wand",
	"item_power_treads",
	"item_blink",
	"item_echo_sabre",
	"item_black_king_bar",
	"item_harpoon",
	"item_greater_crit",
	"item_sheepstick",
	"item_aghanims_shard",
	"item_travel_boots",
	"item_moon_shard",
	"item_arcane_blink",
	"item_travel_boots_2",
	"item_ultimate_scepter_2",
}
-- No Boots of Travel: this build's Guardian Greaves / Boots of Bearing are its one pair of boots.
sRoleItemsBuyList["pos_4"] = {
	"item_priest_outfit",
	"item_hand_of_midas",
	"item_mekansm",
	"item_glimmer_cape",
	"item_guardian_greaves",
	"item_blink",
	"item_echo_sabre",
	"item_black_king_bar",
	"item_sheepstick",
	"item_aghanims_shard",
	"item_arcane_blink",
	"item_ultimate_scepter_2",
	"item_moon_shard",
}
sRoleItemsBuyList["pos_5"] = {
	"item_priest_outfit",
	"item_hand_of_midas",
	"item_mekansm",
	"item_glimmer_cape",
	"item_pipe",
	"item_blink",
	"item_echo_sabre",
	"item_black_king_bar",
	"item_sheepstick",
	"item_aghanims_shard",
	"item_travel_boots",
	"item_arcane_blink",
	"item_travel_boots_2",
	"item_ultimate_scepter_2",
	"item_moon_shard",
}
X["sBuyList"] = sRoleItemsBuyList[sRole]
X["sSellList"] = { "item_black_king_bar", "item_quelling_blade" }
if Fu.Role.IsPvNMode() or Fu.Role.IsAllShadow() then
	X["sBuyList"], X["sSellList"] = { "PvN_mid" }, {}
end
nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"] =
	Fu.SetUserHeroInit(nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"])
X["sSkillList"] = Fu.Skill.GetSkillList(sAbilityList, nAbilityBuildList, sTalentList, nTalentBuildList)
X["bDeafaultAbility"] = false
-- Cast when cornered (retreating into 3+ enemies with no way out), before running further.
X["LastStandSpells"] = { { name = "magnataur_reverse_polarity", kind = "none" } }
X["bDeafaultItem"] = false
function X.MinionThink(hMinionUnit)
	Minion.MinionThink(hMinionUnit)
end
local shockwaveAbility = SafeAbility(bot:GetAbilityByName("magnataur_shockwave"), "magnataur_shockwave", "magnataur")
local empowerAbility = SafeAbility(bot:GetAbilityByName("magnataur_empower"), "magnataur_empower", "magnataur")
local skewerAbility = SafeAbility(bot:GetAbilityByName("magnataur_skewer"), "magnataur_skewer", "magnataur")
local hornTossAbility = SafeAbility(bot:GetAbilityByName("magnataur_horn_toss"), "magnataur_horn_toss", "magnataur")
local reversePolarityAbility =
	SafeAbility(bot:GetAbilityByName("magnataur_reverse_polarity"), "magnataur_reverse_polarity", "magnataur")
local shockwaveDesire, shockwaveLocation
local empowerDesire, empowerTarget
local skewerDesire, skewerLocation
local hornTossDesire
local reversePolarityDesire
local blinkItem
local blinkLocation
local blinkRPDesire
local blinkSkewerDesire
local blinkRPSkewerDesire
local blinkHornTossSkewerDesire
local bkbItem
-- fix: these helpers were globals; Dark Seer, Treant and Tiny also define a global HasBlink, so one
-- hero could run another's copy (reading that hero's bot). Forward-declared locals: the
-- "function X()" definitions at the bottom now assign these.
local CanDoBlinkRP, CanDoBlinkSkewer, CanDoBlinkRPSkewer, CanDoBlinkHornTossSkewer, HasBlink, CanBKB
if bot.shouldBlink == nil then
	bot.shouldBlink = false
end
local botTarget
local isGoingOnSomeone
local isRetreating
local hpRatio
local isInTeamFight
-- Where a Skewer started at fromLoc should end: toward the nearest allied hero (not Magnus) at least
-- 300 away from fromLoc, else toward the escape location. If the ally list includes Magnus himself
-- (the file's own `ally ~= bot` guards assume it can), the old "last ally in the list" could be Magnus,
-- giving a zero-length Skewer onto his own spot, and the escape fallback (#nearbyAllies == 0) could never run.
local function SkewerDestination(fromLoc, skewerRange)
	local towardLoc = nil
	local nearest = math.huge
	for _, ally in pairs(Fu.GetNearbyHeroes(bot, 1600, false, BOT_MODE_NONE) or {}) do
		if Fu.IsValidHero(ally) and ally ~= bot and not ally:IsIllusion() then
			local dist = GetUnitToLocationDistance(ally, fromLoc)
			if dist >= 300 and dist < nearest then
				nearest = dist
				towardLoc = ally:GetLocation()
			end
		end
	end
	if towardLoc == nil then
		towardLoc = Fu.GetEscapeLoc()
	end
	return Fu.Utils.GetOffsetLocationTowardsTargetLocation(fromLoc, towardLoc, skewerRange)
end
local function LogCombo(what)
	if DotaTime() >= (bot._ohaMagnusComboLogAt or -999) then
		bot._ohaMagnusComboLogAt = DotaTime() + 5
		pcall(print, string.format("[OHA-MAGNUS] t=%.0f %s", DotaTime(), what))
	end
end
function X.SkillsComplement()
	if Fu.CanNotUseAbility(bot) then
		return
	end
	isGoingOnSomeone = Fu.IsGoingOnSomeone(bot)
	isRetreating = Fu.IsRetreating(bot)
	hpRatio = Fu.GetHP(bot)
	isInTeamFight = Fu.IsInTeamFight(bot, 1200)
	blinkRPSkewerDesire = X.ConsiderBlinkRPSkewer()
	if blinkRPSkewerDesire > 0 then
		bot:Action_ClearActions(false)
		if CanBKB() then
			bot:ActionQueue_UseAbility(bkbItem)
		end
		bot:ActionQueue_UseAbilityOnLocation(blinkItem, blinkLocation)
		bot:ActionQueue_Delay(0.1)
		bot:ActionQueue_UseAbility(reversePolarityAbility)
		bot:ActionQueue_Delay(0.3)
		-- Was ConsiderSkewer2(), evaluated now at the pre-blink spot (no enemy within 145 there), so the
		-- Skewer after Blink + RP was never queued. Aim it from the blink spot blinkLocation toward allies instead.
		bot:ActionQueue_UseAbilityOnLocation(
			skewerAbility,
			SkewerDestination(blinkLocation, skewerAbility:GetSpecialValueInt("range"))
		)
		LogCombo("blink + RP + skewer")
		return
	end
	blinkSkewerDesire = X.ConsiderBlinkForSkewer()
	if blinkSkewerDesire > 0 then
		bot:Action_ClearActions(false)
		if CanBKB() then
			bot:ActionQueue_UseAbility(bkbItem)
		end
		bot:ActionQueue_UseAbilityOnLocation(blinkItem, blinkLocation)
		bot:ActionQueue_Delay(0.1)
		-- Same pre-blink evaluation bug as above: Skewer from the blink spot (on the target) to allies.
		bot:ActionQueue_UseAbilityOnLocation(
			skewerAbility,
			SkewerDestination(blinkLocation, skewerAbility:GetSpecialValueInt("range"))
		)
		LogCombo("blink + skewer")
		return
	end
	blinkRPDesire = X.ConsiderBlinkRP()
	if blinkRPDesire > 0 then
		bot:Action_ClearActions(false)
		if CanBKB() then
			bot:ActionQueue_UseAbility(bkbItem)
		end
		bot:ActionQueue_UseAbilityOnLocation(blinkItem, blinkLocation)
		bot:ActionQueue_Delay(0.1)
		bot:ActionQueue_UseAbility(reversePolarityAbility)
		return
	end
	blinkHornTossSkewerDesire = X.ConsiderBlinkForHornTossSkewer()
	if blinkHornTossSkewerDesire > 0 then
		bot:Action_ClearActions(false)
		if CanBKB() then
			bot:ActionQueue_UseAbility(bkbItem)
		end
		bot:ActionQueue_UseAbilityOnLocation(blinkItem, blinkLocation)
		hornTossDesire = X.ConsiderHornToss()
		if hornTossDesire > 0 then
			bot:ActionQueue_UseAbility(hornTossAbility)
			return
		end
		bot:ActionQueue_Delay(0.6)
		skewerDesire, skewerLocation = X.ConsiderSkewer2()
		if skewerDesire > 0 then
			bot:ActionQueue_UseAbilityOnLocation(skewerAbility, skewerLocation)
		end
		return
	end
	reversePolarityDesire = X.ConsiderReversePolarity()
	if reversePolarityDesire > 0 then
		bot:Action_UseAbility(reversePolarityAbility)
		return
	end
	hornTossDesire = X.ConsiderHornToss()
	if hornTossDesire > 0 then
		bot:Action_UseAbility(hornTossAbility)
		return
	end
	skewerDesire, skewerLocation = X.ConsiderSkewer()
	if skewerDesire > 0 then
		bot:Action_UseAbilityOnLocation(skewerAbility, skewerLocation)
		return
	end
	empowerDesire, empowerTarget = X.ConsiderEmpower()
	if empowerDesire > 0 then
		bot:Action_UseAbilityOnEntity(empowerAbility, empowerTarget)
		return
	end
	shockwaveDesire, shockwaveLocation = X.ConsiderShockwave()
	if shockwaveDesire > 0 then
		bot:Action_UseAbilityOnLocation(shockwaveAbility, shockwaveLocation)
		return
	end
end
function X.ConsiderShockwave()
	if not shockwaveAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local castRange = Fu.GetProperCastRange(false, bot, shockwaveAbility:GetCastRange())
	local castPoint = shockwaveAbility:GetCastPoint()
	local shockWidth = shockwaveAbility:GetSpecialValueInt("shock_width")
	local damage = shockwaveAbility:GetSpecialValueInt("shock_damage")
	local speed = shockwaveAbility:GetSpecialValueInt("shock_speed")
	local mpRatio = bot:GetMana() / bot:GetMaxMana()
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
			local eta = GetUnitToUnitDistance(bot, enemyHero) / speed + castPoint
			return BOT_ACTION_DESIRE_HIGH, enemyHero:GetExtrapolatedLocation(eta)
		end
	end
	if isGoingOnSomeone then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, 1000, false, BOT_MODE_NONE)
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, 800, true, BOT_MODE_NONE)
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange - 200)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not Fu.IsDisabled(botTarget)
			and not Fu.IsTaunted(botTarget)
			and not botTarget:HasModifier("modifier_enigma_black_hole_pull")
			and not botTarget:HasModifier("modifier_faceless_void_chronosphere_freeze")
			and nearbyAllies ~= nil
			and nearbyEnemies
			and #nearbyAllies >= #nearbyEnemies
		then
			local eta = GetUnitToUnitDistance(bot, botTarget) / speed + castPoint
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetExtrapolatedLocation(eta)
		end
	end
	if Fu.IsDefending(bot) or Fu.IsPushing(bot) then
		local nearbyLaneCreeps = bot:GetNearbyLaneCreeps(castRange - 200, true)
		local aoeLocation = bot:FindAoELocation(true, false, bot:GetLocation(), castRange - 200, shockWidth, 0, 0)
		if nearbyLaneCreeps ~= nil and #nearbyLaneCreeps >= 4 and aoeLocation.count >= 4 then
			return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
		end
		aoeLocation = bot:FindAoELocation(true, true, bot:GetLocation(), castRange - 200, shockWidth, 0, 0)
		if aoeLocation.count >= 1 then
			return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
		end
	end
	if Fu.IsFarming(bot) then
		local nearbyLaneCreeps = bot:GetNearbyLaneCreeps(800, true)
		local aoeLocation = bot:FindAoELocation(true, false, bot:GetLocation(), 800, shockWidth, 0, 0)
		if Fu.IsAttacking(bot) then
			if nearbyLaneCreeps ~= nil and #nearbyLaneCreeps >= 3 and aoeLocation.count >= 3 then
				return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
			end
			local nearbyNeutrals = bot:GetNearbyNeutralCreeps(600)
			if
				nearbyNeutrals ~= nil
				and (#nearbyNeutrals >= 3 and aoeLocation.count >= 3 or #nearbyNeutrals >= 2 and aoeLocation.count >= 2 and nearbyNeutrals[1]:IsAncientCreep())
				and mpRatio > 0.27
			then
				return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
			end
		end
	end
	if Fu.IsLaning(bot) and mpRatio > 0.39 then
		local nearbyLaneCreeps = bot:GetNearbyLaneCreeps(castRange, true)
		for _, creep in pairs(nearbyLaneCreeps) do
			if
				Fu.IsValid(creep)
				and (Fu.IsKeyWordUnit("ranged", creep) or Fu.IsKeyWordUnit("siege", creep) or Fu.IsKeyWordUnit(
					"flagbearer",
					creep
				))
				and creep:GetHealth() <= damage
			then
				local nearbyEnemies = Fu.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE)
				if
					nearbyEnemies ~= nil
					and #nearbyEnemies >= 1
					and GetUnitToUnitDistance(creep, nearbyEnemies[1]) <= 500
				then
					return BOT_ACTION_DESIRE_HIGH, creep:GetLocation()
				end
			end
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, 400) and Fu.IsAttacking(bot) then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	local alliesInRange = Fu.GetNearbyHeroes(bot, castRange, false, BOT_MODE_NONE)
	for _, allyHero in pairs(alliesInRange) do
		local enemiesNearAlly = Fu.GetNearbyHeroes(allyHero, castRange, true, BOT_MODE_NONE)
		if
			Fu.IsRetreating(allyHero)
			and allyHero:WasRecentlyDamagedByAnyHero(2.1)
			and not allyHero:IsIllusion()
			and mpRatio > 0.48
		then
			if
				enemiesNearAlly ~= nil
				and #enemiesNearAlly >= 1
				and Fu.IsValidHero(enemiesNearAlly[1])
				and Fu.CanCastOnNonMagicImmune(enemiesNearAlly[1])
				and Fu.IsInRange(allyHero, enemiesNearAlly[1], 400)
				and Fu.IsInRange(bot, enemiesNearAlly[1], castRange)
				and Fu.IsRunning(allyHero)
				and enemiesNearAlly[1]:IsFacingLocation(allyHero:GetLocation(), 30)
				and not Fu.IsDisabled(enemiesNearAlly[1])
				and not Fu.IsTaunted(enemiesNearAlly[1])
				and not Fu.IsSuspiciousIllusion(enemiesNearAlly[1])
				and not enemiesNearAlly[1]:HasModifier("modifier_enigma_black_hole_pull")
				and not enemiesNearAlly[1]:HasModifier("modifier_faceless_void_chronosphere_freeze")
			then
				local eta = GetUnitToUnitDistance(bot, enemiesNearAlly[1]) / speed + castPoint
				return BOT_ACTION_DESIRE_HIGH, enemiesNearAlly[1]:GetExtrapolatedLocation(eta + castPoint)
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.ConsiderEmpower()
	if not empowerAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	-- Casting on an ally also empowers Magnus. Keep enough mana to still Reverse Polarity.
	if
		reversePolarityAbility ~= nil
		and reversePolarityAbility:GetLevel() > 0
		and reversePolarityAbility:GetCooldownTimeRemaining() < 2
	then
		if bot:GetMana() < empowerAbility:GetManaCost() + reversePolarityAbility:GetManaCost() + 30 then
			return BOT_ACTION_DESIRE_NONE, nil
		end
	end
	local castRange = Fu.GetProperCastRange(false, bot, empowerAbility:GetCastRange())
	local best = nil
	local bestScore = -1
	local allies = Fu.GetNearbyHeroes(bot, castRange, false, BOT_MODE_NONE)
	for _, ally in pairs(allies) do
		if
			Fu.IsValidHero(ally)
			and ally ~= bot
			and not ally:IsIllusion()
			and Fu.IsInRange(bot, ally, castRange)
			and not ally:HasModifier("modifier_magnataur_empower")
		then
			local score = ally:GetAttackDamage() * ally:GetAttackSpeed()
			if Fu.IsCore(ally) then
				score = score + 10000
			end
			if score > bestScore then
				bestScore = score
				best = ally
			end
		end
	end
	if best ~= nil then
		return BOT_ACTION_DESIRE_HIGH, best
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function X.ConsiderSkewer()
	if not skewerAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local skewerRange = skewerAbility:GetSpecialValueInt("range")
	local castPoint = skewerAbility:GetCastPoint()
	local speed = skewerAbility:GetSpecialValueInt("skewer_speed")
	local radius = skewerAbility:GetSpecialValueInt("skewer_radius")
	botTarget = Fu.GetProperTarget(bot)
	if Fu.IsStuck(bot) then
		local escapeLocation = Fu.GetEscapeLoc()
		return BOT_ACTION_DESIRE_HIGH, Fu.Site.GetXUnitsTowardsLocation(bot, escapeLocation, skewerRange)
	end
	if isGoingOnSomeone and (not CanDoBlinkSkewer() or not CanDoBlinkRPSkewer() or not CanDoBlinkHornTossSkewer()) then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, 1000, false, BOT_MODE_NONE)
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, 1000, true, BOT_MODE_NONE)
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not botTarget:HasModifier("modifier_enigma_black_hole_pull")
			and not botTarget:HasModifier("modifier_faceless_void_chronosphere_freeze")
			and nearbyAllies ~= nil
			and nearbyEnemies
			and #nearbyAllies >= #nearbyEnemies
		then
			if
				Fu.IsEnemyBetweenMeAndLocation(bot, Fu.GetEscapeLoc(), skewerRange)
				and Fu.IsInRange(bot, botTarget, radius)
			then
				-- nearbyAllies[#nearbyAllies] could be Magnus himself (see SkewerDestination). Skewer toward a real ally, else
				-- toward safety.
				return BOT_ACTION_DESIRE_HIGH, SkewerDestination(bot:GetLocation(), skewerRange)
			end
			if
				Fu.IsRunning(bot)
				and Fu.IsRunning(botTarget)
				and Fu.IsInRange(bot, botTarget, skewerRange)
				and bot:IsFacingLocation(botTarget:GetLocation(), 30)
				and not botTarget:IsFacingLocation(bot:GetLocation(), 30)
			then
				local eta = GetUnitToUnitDistance(bot, botTarget) / speed + castPoint
				return BOT_ACTION_DESIRE_HIGH, botTarget:GetExtrapolatedLocation(eta)
			end
		end
	end
	if isRetreating then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, 800, false, BOT_MODE_NONE)
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, 600, true, BOT_MODE_NONE)
		if
			nearbyAllies ~= nil
			and nearbyEnemies
			and (#nearbyEnemies > #nearbyAllies or hpRatio < 0.68 and bot:WasRecentlyDamagedByAnyHero(1.9))
			and Fu.IsValidHero(nearbyEnemies[1])
			and Fu.IsInRange(bot, nearbyEnemies[1], 575)
			and not Fu.IsSuspiciousIllusion(nearbyEnemies[1])
			and not Fu.IsDisabled(nearbyEnemies[1])
			and not Fu.IsTaunted(nearbyEnemies[1])
		then
			local escapeLocation = Fu.GetEscapeLoc()
			return BOT_ACTION_DESIRE_HIGH, Fu.Site.GetXUnitsTowardsLocation(bot, escapeLocation, skewerRange)
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.ConsiderReversePolarity()
	if not reversePolarityAbility:IsFullyCastable() or bot:HasModifier("modifier_magnataur_skewer_movement") then
		return BOT_ACTION_DESIRE_NONE
	end
	local pullRadius = reversePolarityAbility:GetSpecialValueInt("pull_radius")
	local damage = reversePolarityAbility:GetSpecialValueInt("polarity_damage")
	if isInTeamFight and (not CanDoBlinkRP() or not CanDoBlinkRPSkewer()) then
		local enemiesInPull = Fu.GetNearbyHeroes(bot, pullRadius, true, BOT_MODE_NONE)
		if enemiesInPull ~= nil and #enemiesInPull >= 2 then
			local enemiesNearBot = Fu.GetEnemiesNearLoc(bot:GetLocation(), pullRadius)
			if
				enemiesNearBot ~= nil
				and #enemiesNearBot >= 2
				and not Fu.IsLocationInChrono(enemiesInPull[1]:GetLocation())
				and not Fu.IsLocationInBlackHole(enemiesInPull[1]:GetLocation())
			then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	if isRetreating then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, pullRadius + 200, false, BOT_MODE_NONE)
		local enemiesInPull = Fu.GetNearbyHeroes(bot, pullRadius, true, BOT_MODE_NONE)
		if
			nearbyAllies ~= nil
			and enemiesInPull
			and (#enemiesInPull > #nearbyAllies or hpRatio < 0.5 and bot:WasRecentlyDamagedByAnyHero(1.6))
		then
			for _, enemyHero in pairs(enemiesInPull) do
				if
					Fu.IsValidHero(enemyHero)
					and Fu.CanCastOnMagicImmune(enemyHero)
					and Fu.IsInRange(bot, enemyHero, pullRadius)
					and Fu.CanKillTarget(enemyHero, damage, DAMAGE_TYPE_MAGICAL)
					and not Fu.IsSuspiciousIllusion(enemyHero)
					and not Fu.IsDisabled(enemyHero)
					and not Fu.IsTaunted(enemyHero)
					and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
					and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
					and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
					and not enemyHero:HasModifier("modifier_templar_assassin_refraction_absorb")
				then
					return BOT_ACTION_DESIRE_HIGH
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderHornToss()
	if not hornTossAbility:IsTrained() or not hornTossAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
	end
	local radius = hornTossAbility:GetSpecialValueInt("radius")
	botTarget = Fu.GetProperTarget(bot)
	if isGoingOnSomeone and not CanDoBlinkHornTossSkewer() then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, 800, false, BOT_MODE_NONE)
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, 800, true, BOT_MODE_NONE)
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, radius)
			and bot:IsFacingLocation(botTarget:GetLocation(), 15)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not botTarget:HasModifier("modifier_enigma_black_hole_pull")
			and not botTarget:HasModifier("modifier_faceless_void_chronosphere_freeze")
			and not botTarget:HasModifier("modifier_legion_commander_duel")
			and nearbyAllies ~= nil
			and nearbyEnemies
			and #nearbyAllies >= #nearbyEnemies
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if isRetreating then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, radius + 200, false, BOT_MODE_NONE)
		local enemiesInRadius = Fu.GetNearbyHeroes(bot, radius, true, BOT_MODE_NONE)
		if
			nearbyAllies ~= nil
			and enemiesInRadius
			and (#enemiesInRadius > #nearbyAllies or hpRatio < 0.61 and bot:WasRecentlyDamagedByAnyHero(2))
		then
			for _, enemyHero in pairs(enemiesInRadius) do
				if
					Fu.IsValidHero(enemyHero)
					and Fu.CanCastOnNonMagicImmune(enemyHero)
					and Fu.IsInRange(bot, enemyHero, radius)
					and Fu.IsEnemyBetweenMeAndLocation(bot, Fu.GetEscapeLoc(), radius)
					and not Fu.IsSuspiciousIllusion(enemyHero)
				then
					return BOT_ACTION_DESIRE_HIGH
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderBlinkRP()
	if CanDoBlinkRP() then
		local blinkRange = 1199
		local castPoint = skewerAbility:GetCastPoint() + reversePolarityAbility:GetCastPoint()
		local pullRadius = reversePolarityAbility:GetSpecialValueInt("pull_radius")
		if isInTeamFight then
			local aoeLocation = bot:FindAoELocation(true, true, bot:GetLocation(), blinkRange, pullRadius, castPoint, 0)
			if aoeLocation.count >= 2 then
				local enemiesInRadius = Fu.GetEnemiesNearLoc(aoeLocation.targetloc, pullRadius)
				if
					enemiesInRadius ~= nil
					and #enemiesInRadius >= 2
					and not Fu.IsLocationInChrono(aoeLocation.targetloc)
					and not Fu.IsLocationInBlackHole(aoeLocation.targetloc)
				then
					blinkLocation = aoeLocation.targetloc
					return BOT_ACTION_DESIRE_HIGH
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function CanDoBlinkRP()
	if reversePolarityAbility:IsFullyCastable() and HasBlink() then
		local manaCost = reversePolarityAbility:GetManaCost()
		if bot:GetMana() >= manaCost then
			bot.shouldBlink = true
			return true
		end
	end
	bot.shouldBlink = false
	return false
end
function X.ConsiderBlinkForSkewer()
	if CanDoBlinkSkewer() then
		botTarget = Fu.GetProperTarget(bot)
		if isGoingOnSomeone then
			local nearbyAllies = Fu.GetNearbyHeroes(bot, 1000, false, BOT_MODE_NONE)
			local nearbyEnemies = Fu.GetNearbyHeroes(bot, 800, true, BOT_MODE_NONE)
			if
				Fu.IsValidTarget(botTarget)
				and Fu.CanCastOnNonMagicImmune(botTarget)
				and Fu.IsInRange(bot, botTarget, 1199)
				and not Fu.IsSuspiciousIllusion(botTarget)
				and not botTarget:HasModifier("modifier_enigma_black_hole_pull")
				and not botTarget:HasModifier("modifier_faceless_void_chronosphere_freeze")
				and nearbyAllies ~= nil
				and nearbyEnemies
				and #nearbyAllies >= #nearbyEnemies
			then
				blinkLocation = botTarget:GetLocation()
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderSkewer2()
	local radius = skewerAbility:GetSpecialValueInt("skewer_radius")
	local skewerRange = skewerAbility:GetSpecialValueInt("range")
	local nearbyAllies = Fu.GetNearbyHeroes(bot, 800, false, BOT_MODE_NONE)
	local nearbyEnemies = Fu.GetNearbyHeroes(bot, 800, true, BOT_MODE_NONE)
	local enemiesInRadius = Fu.GetNearbyHeroes(bot, radius, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(enemiesInRadius) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and not Fu.IsSuspiciousIllusion(enemyHero)
			and not enemyHero:HasModifier("modifier_enigma_black_hole_pull")
			and not enemyHero:HasModifier("modifier_faceless_void_chronosphere_freeze")
			and nearbyAllies ~= nil
			and nearbyEnemies
			and #nearbyAllies >= #nearbyEnemies
		then
			if
				Fu.IsEnemyBetweenMeAndLocation(bot, Fu.GetEscapeLoc(), skewerRange)
				and Fu.IsInRange(bot, enemyHero, radius)
			then
				-- Same Magnus-in-his-own-ally-list bug as in ConsiderSkewer.
				return BOT_ACTION_DESIRE_HIGH, SkewerDestination(bot:GetLocation(), skewerRange)
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function CanDoBlinkSkewer()
	if skewerAbility:IsFullyCastable() and HasBlink() then
		local manaCost = skewerAbility:GetManaCost()
		if bot:GetMana() >= manaCost then
			bot.shouldBlink = true
			return true
		end
	end
	bot.shouldBlink = false
	return false
end
function X.ConsiderBlinkRPSkewer()
	if CanDoBlinkRPSkewer() then
		local blinkRange = 1199
		local castPoint = skewerAbility:GetCastPoint() + reversePolarityAbility:GetCastPoint()
		local pullRadius = reversePolarityAbility:GetSpecialValueInt("pull_radius")
		if isInTeamFight then
			local aoeLocation = bot:FindAoELocation(true, true, bot:GetLocation(), blinkRange, pullRadius, castPoint, 0)
			if aoeLocation.count >= 2 then
				blinkLocation = aoeLocation.targetloc
				local enemiesInRadius = Fu.GetEnemiesNearLoc(aoeLocation.targetloc, pullRadius)
				if
					enemiesInRadius ~= nil
					and #enemiesInRadius >= 2
					and not Fu.IsLocationInChrono(aoeLocation.targetloc)
					and not Fu.IsLocationInBlackHole(aoeLocation.targetloc)
				then
					return BOT_ACTION_DESIRE_HIGH
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function CanDoBlinkRPSkewer()
	if skewerAbility:IsFullyCastable() and reversePolarityAbility:IsFullyCastable() and HasBlink() then
		local manaCost = skewerAbility:GetManaCost() + reversePolarityAbility:GetManaCost()
		if bot:GetMana() >= manaCost then
			bot.shouldBlink = true
			return true
		end
	end
	bot.shouldBlink = false
	return false
end
function X.ConsiderBlinkForHornTossSkewer()
	if CanDoBlinkHornTossSkewer() then
		botTarget = Fu.GetProperTarget(bot)
		if isGoingOnSomeone then
			local nearbyAllies = Fu.GetNearbyHeroes(bot, 800, false, BOT_MODE_NONE)
			local nearbyEnemies = Fu.GetNearbyHeroes(bot, 800, true, BOT_MODE_NONE)
			if
				Fu.IsValidTarget(botTarget)
				and Fu.CanCastOnNonMagicImmune(botTarget)
				and Fu.IsInRange(bot, botTarget, 1199)
				and not Fu.IsSuspiciousIllusion(botTarget)
				and not botTarget:HasModifier("modifier_enigma_black_hole_pull")
				and not botTarget:HasModifier("modifier_faceless_void_chronosphere_freeze")
				and not botTarget:HasModifier("modifier_legion_commander_duel")
				and nearbyAllies ~= nil
				and nearbyEnemies
				and #nearbyAllies >= #nearbyEnemies
			then
				blinkLocation = botTarget:GetLocation()
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function CanDoBlinkHornTossSkewer()
	if
		hornTossAbility:IsTrained()
		and hornTossAbility:IsFullyCastable()
		and skewerAbility:IsFullyCastable()
		and reversePolarityAbility:IsFullyCastable()
		and HasBlink()
	then
		local manaCost = skewerAbility:GetManaCost()
			+ reversePolarityAbility:GetManaCost()
			+ hornTossAbility:GetManaCost()
		if bot:GetMana() >= manaCost then
			bot.shouldBlink = true
			return true
		end
	end
	bot.shouldBlink = false
	return false
end
function HasBlink()
	local foundBlink = nil
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
			foundBlink = item
			break
		end
	end
	if foundBlink ~= nil and foundBlink:IsFullyCastable() then
		blinkItem = foundBlink
		return true
	end
	return false
end
function CanBKB()
	local foundBlackKingBar = nil
	for slot = 0, 5 do
		local item = bot:GetItemInSlot(slot)
		if item ~= nil and item:GetName() == "item_black_king_bar" then
			foundBlackKingBar = item
			break
		end
	end
	if foundBlackKingBar ~= nil and foundBlackKingBar:IsFullyCastable() and bot:GetMana() >= 75 then
		bkbItem = foundBlackKingBar
		return true
	end
	return false
end
return X
