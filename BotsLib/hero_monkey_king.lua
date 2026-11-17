-- Monkey King: skill build, item build, and ability use for this hero.
local X = {}
local bot = GetBot()
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local AbilityContext = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local Minion = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local sTalentList = Fu.Skill.GetTalentList(bot)
-- Fixed list by name. GetAbilityList skips only abilities that are both unlearnable and hidden at
-- spawn, so Primal Spring (slot 3) and Mischief (slot 5) could shift Jingu Mastery's index; the
-- old arrays had 16 entries, the ultimate first at level 9 and 5 points in one basic ability.
local sAbilityList = {
	"monkey_king_boundless_strike",
	"monkey_king_tree_dance",
	"monkey_king_jingu_mastery",
	[6] = "monkey_king_wukongs_command",
}
local sRole = Fu.Item.GetRoleItemsBuyList(bot)
local tTalentTreeList = {
	{ ["t25"] = { 10, 0 }, ["t20"] = { 10, 0 }, ["t15"] = { 0, 10 }, ["t10"] = { 10, 0 } },
	{ ["t25"] = { 10, 0 }, ["t20"] = { 10, 0 }, ["t15"] = { 0, 10 }, ["t10"] = { 10, 0 } },
}
-- User call: one point in each basic ability at levels 1-3, Jingu Mastery maxed, ultimate at
-- 6/12/18, then Boundless Strike, Tree Dance last.
local tAllAbilityBuildList =
	{ { 1, 2, 3, 3, 3, 6, 3, 1, 1, 1, 6, 2, 2, 2, 6 }, { 1, 2, 3, 3, 3, 6, 3, 1, 1, 1, 6, 2, 2, 2, 6 } }
local nAbilityBuildList
local nTalentBuildList
if sRole == "pos_1" then
	nAbilityBuildList = tAllAbilityBuildList[1]
	nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList[1])
else
	nAbilityBuildList = tAllAbilityBuildList[2]
	nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList[2])
end
local sRoleItemsBuyList = {}
sRoleItemsBuyList["pos_1"] = {
	"item_tango",
	"item_double_branches",
	"item_quelling_blade",
	"item_orb_of_frost",
	"item_boots",
	"item_orb_of_corrosion",
	"item_power_treads",
	"item_magic_wand",
	"item_echo_sabre",
	"item_desolator",
	"item_black_king_bar",
	"item_harpoon",
	"item_basher",
	"item_skadi",
	"item_travel_boots",
	"item_abyssal_blade",
	"item_satanic",
	"item_travel_boots_2",
	"item_ultimate_scepter_2",
	"item_moon_shard",
	"item_aghanims_shard",
}
sRoleItemsBuyList["pos_2"] = {
	"item_tango",
	"item_double_branches",
	"item_quelling_blade",
	"item_orb_of_frost",
	"item_power_treads",
	"item_orb_of_corrosion",
	"item_magic_wand",
	"item_echo_sabre",
	"item_desolator",
	"item_black_king_bar",
	"item_harpoon",
	"item_basher",
	"item_skadi",
	"item_travel_boots",
	"item_abyssal_blade",
	"item_satanic",
	"item_travel_boots_2",
	"item_ultimate_scepter_2",
	"item_moon_shard",
	"item_aghanims_shard",
}
sRoleItemsBuyList["pos_3"] = sRoleItemsBuyList["pos_1"]
sRoleItemsBuyList["pos_4"] = sRoleItemsBuyList["pos_1"]
sRoleItemsBuyList["pos_5"] = sRoleItemsBuyList["pos_1"]
X["sBuyList"] = sRoleItemsBuyList[sRole]
X["sSellList"] = { "item_black_king_bar", "item_quelling_blade", "item_satanic", "item_desolator" }
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
local boundlessStrikeAbility =
	SafeAbility(bot:GetAbilityByName("monkey_king_boundless_strike"), "monkey_king_boundless_strike", "monkey_king")
local treeDanceAbility =
	SafeAbility(bot:GetAbilityByName("monkey_king_tree_dance"), "monkey_king_tree_dance", "monkey_king")
local primalSpringAbility =
	SafeAbility(bot:GetAbilityByName("monkey_king_primal_spring"), "monkey_king_primal_spring", "monkey_king")
local primalSpringEarlyAbility = SafeAbility(
	bot:GetAbilityByName("monkey_king_primal_spring_early"),
	"monkey_king_primal_spring_early",
	"monkey_king"
)
local mischiefAbility = SafeAbility(bot:GetAbilityByName("monkey_king_mischief"), "monkey_king_mischief", "monkey_king")
local untransformAbility =
	SafeAbility(bot:GetAbilityByName("monkey_king_untransform"), "monkey_king_untransform", "monkey_king")
local wukongsCommandAbility =
	SafeAbility(bot:GetAbilityByName("monkey_king_wukongs_command"), "monkey_king_wukongs_command", "monkey_king")
local transfigurationAbility =
	SafeAbility(bot:GetAbilityByName("monkey_king_transfiguration"), "monkey_king_transfiguration", "monkey_king")
local boundlessStrikeDesire, boundlessStrikeLocation
local treeDanceDesire, treeDanceTarget
local primalSpringDesire, primalSpringLocation
local untransformDesire
local mischiefDesire
local wukongsCommandDesire, wukongsCommandLocation
local changingOfTheGuardDesire, changingOfTheGuardLocation
local botTarget
local isGoingOnSomeone
local isRetreating
local isAttacking
local hpRatio
local mpRatio
local isInTeamFight
-- In-game check: is the Jingu buff seen, and do the counter stacks build on the hero he hits?
local jinguOn, jinguLogTarget, jinguLogStacks = false, nil, 0
local function LogJingu()
	local isActive = bot:HasModifier("modifier_monkey_king_quadruple_tap_bonuses")
	if isActive ~= jinguOn then
		jinguOn = isActive
		print(
			string.format(
				"[OHA-MONKEY_KING] t=%.0f jingu %s charges=%d hp=%.2f",
				DotaTime(),
				isActive and "active" or "ended",
				Fu.GetModifierCount(bot, "modifier_monkey_king_quadruple_tap_bonuses"),
				Fu.GetHP(bot)
			)
		)
	end
	local attackTarget = bot:GetAttackTarget()
	if Fu.IsValidHero(attackTarget) then
		local stacks = Fu.GetModifierCount(attackTarget, "modifier_monkey_king_quadruple_tap_counter")
		if stacks > 0 and (attackTarget ~= jinguLogTarget or stacks ~= jinguLogStacks) then
			jinguLogTarget, jinguLogStacks = attackTarget, stacks
			print(
				string.format(
					"[OHA-MONKEY_KING] t=%.0f jingu counter target=%s stacks=%d",
					DotaTime(),
					attackTarget:GetUnitName(),
					stacks
				)
			)
		end
	end
end
-- Jingu Mastery (game data): required_hits 4 (3 with the talent) on the same hero within
-- counter_duration gives 4 empowered attacks (bonus damage and lifesteal). The counter sits on the
-- enemy, so keep hitting the marked hero. This lived in the override attack mode, which Monkey King
-- does not load (game 037: dead code). Runs every think, whatever the mode picked as target.
local function JinguFocus()
	if
		Fu.CanNotUseAction(bot)
		or bot:IsDisarmed()
		or not Fu.IsGoingOnSomeone(bot)
		or bot:HasModifier("modifier_monkey_king_quadruple_tap_bonuses")
		-- Perched (Primal Spring is activated only then; on the ground it shows not-activated) or
		-- just hopped: an attack order would drop him off the tree and waste the Spring engage.
		or primalSpringAbility:IsTrained() and primalSpringAbility:IsActivated()
		or DotaTime() - (bot._mkTreeDanceAt or -999) <= 4
	then
		return false
	end
	local current = bot:GetAttackTarget()
	local currentIsHero = Fu.IsValidHero(current)
	local currentStacks = currentIsHero and Fu.GetModifierCount(current, "modifier_monkey_king_quadruple_tap_counter")
		or 0
	if currentStacks > 0 then
		return false
	end
	local best, bestStacks = nil, 0
	local range = bot:GetAttackRange() + 150
	for _, enemyHero in pairs(Fu.GetNearbyHeroes(bot, math.min(range, 1600), true, BOT_MODE_NONE) or {}) do
		if
			Fu.IsValidHero(enemyHero)
			and enemyHero ~= current
			and Fu.CanBeAttacked(enemyHero)
			and not Fu.IsSuspiciousIllusion(enemyHero)
			and not enemyHero:HasModifier("modifier_item_blade_mail_reflect")
		then
			local stacks = Fu.GetModifierCount(enemyHero, "modifier_monkey_king_quadruple_tap_counter")
			if stacks > bestStacks then
				best, bestStacks = enemyHero, stacks
			end
		end
	end
	-- Off a creep (or nothing): any marked hero. Off an unmarked hero: one 2+ hits along.
	if best == nil or currentIsHero and bestStacks < 2 then
		return false
	end
	-- Never cut a wind-up that is playing now (attack activity 1503, as in combat.lua).
	if bot:GetAnimActivity() == 1503 and bot:GetAnimCycle() < bot:GetAttackPoint() + 0.05 then
		return false
	end
	bot:SetTarget(best)
	bot:Action_AttackUnit(best, true)
	if DotaTime() >= (bot._mkJinguFocusLogAt or -99) then
		bot._mkJinguFocusLogAt = DotaTime() + 3
		pcall(
			print,
			string.format(
				"[OHA-MONKEY_KING] t=%.0f jingu-focus target=%s stacks=%d was=%s mode=%d",
				DotaTime(),
				(string.gsub(best:GetUnitName(), "npc_dota_hero_", "")),
				bestStacks,
				current ~= nil and not current:IsNull() and (string.gsub(current:GetUnitName(), "npc_dota_hero_", ""))
					or "none",
				bot:GetActiveMode()
			)
		)
	end
	return true
end
-- Game 036: engage hops 3-5s apart (1476/1479/1482, 2643/2646, 2703/2708) with no Primal Spring in
-- between (cooldown 18-12s, game data). For 4s after an engage hop, say why Spring was not cast.
local function SpringSkip(why)
	local now = DotaTime()
	if now - (bot._mkTreeDanceAt or -999) <= 4 and now >= (bot._mkSpringSkipLogAt or -99) then
		bot._mkSpringSkipLogAt = now + 1
		print(
			string.format(
				"[OHA-MONKEY_KING] t=%.0f spring-skip why=%s hidden=%s cd=%.1f mana=%d/%d",
				now,
				why,
				tostring(primalSpringAbility:IsHidden()),
				primalSpringAbility:GetCooldownTimeRemaining(),
				bot:GetMana(),
				primalSpringAbility:GetManaCost()
			)
		)
	end
end
-- Game 037: 96 "cannot-use-ability" skips with Spring ready (cd=0.0) for the whole 4s after a hop.
-- CanNotUseAbility ORs a dozen states; name the ones that hold, and once per hop list his modifiers
-- (to see the perched state).
local function CannotUseAbilityWhy()
	local parts = {}
	local function add(flag, name)
		if flag then
			parts[#parts + 1] = name
		end
	end
	add(bot:NumQueuedActions() > 0, "queued" .. bot:NumQueuedActions())
	add(bot:IsInvulnerable(), "invuln")
	add(bot:IsCastingAbility(), "casting")
	add(bot:IsUsingAbility(), "using")
	add(bot:IsChanneling(), "channel")
	add(bot:IsSilenced(), "silenced")
	add(bot:IsStunned(), "stunned")
	add(bot:IsHexed(), "hexed")
	add(bot:IsNightmared(), "nightmared")
	add(bot:HasModifier("modifier_doom_bringer_doom"), "doom")
	add(bot:HasModifier("modifier_item_forcestaff_active"), "forcestaff")
	local why = "cannot-use-ability(" .. table.concat(parts, "+") .. ")"
	local now = DotaTime()
	if now - (bot._mkTreeDanceAt or -999) <= 4 and (bot._mkModsLoggedFor or -1) ~= bot._mkTreeDanceAt then
		bot._mkModsLoggedFor = bot._mkTreeDanceAt
		local active = bot:GetCurrentActiveAbility()
		local mods = {}
		for i = 0, bot:NumModifiers() - 1 do
			mods[#mods + 1] = tostring(bot:GetModifierName(i))
		end
		why = why
			.. " active="
			.. (active ~= nil and tostring(active:GetName()) or "none")
			.. " mods="
			.. table.concat(mods, ",")
	end
	return why
end
-- Wukong's Command: the old line printed when the order was decided, and repeats inside the
-- 100/90/80s cooldown (game data) showed some orders never went off. Log the order once, and
-- the cast when the cooldown has started.
local function LogWukongPending()
	local orderAt = bot._mkWukongOrderAt
	if orderAt == nil then
		return
	end
	if wukongsCommandAbility:GetCooldownTimeRemaining() > 0 then
		bot._mkWukongOrderAt = nil
		pcall(print, string.format("[OHA-MONKEY_KING] t=%.0f wukong cast ordered=%.0f", DotaTime(), orderAt))
	elseif DotaTime() - orderAt > 3 then
		bot._mkWukongOrderAt = nil
		pcall(print, string.format("[OHA-MONKEY_KING] t=%.0f wukong no-cast ordered=%.0f", DotaTime(), orderAt))
	end
end
function X.SkillsComplement()
	LogJingu()
	LogWukongPending()
	-- Attacks still work when silenced or hexed, so this comes before the ability gate; a spell
	-- cast below replaces the attack order.
	local okFocus, focusErr = pcall(JinguFocus)
	if not okFocus and not bot._mkJinguFocusErr then
		bot._mkJinguFocusErr = true
		pcall(print, string.format("[OHA-MONKEY_KING] t=%.0f jingu-focus error %s", DotaTime(), tostring(focusErr)))
	end
	if Fu.CanNotUseAbility(bot) then
		local now = DotaTime()
		if now - (bot._mkTreeDanceAt or -999) <= 4 and now >= (bot._mkSpringSkipLogAt or -99) then
			SpringSkip(CannotUseAbilityWhy())
		end
		return
	end
	isGoingOnSomeone = Fu.IsGoingOnSomeone(bot)
	isRetreating = Fu.IsRetreating(bot)
	isAttacking = Fu.IsAttacking(bot)
	hpRatio = Fu.GetHP(bot)
	mpRatio = Fu.GetMP(bot)
	isInTeamFight = Fu.IsInTeamFight(bot, 1200)
	wukongsCommandDesire, wukongsCommandLocation = X.ConsiderWukongsCommand()
	if wukongsCommandDesire > 0 then
		if bot._mkWukongOrderAt == nil then
			bot._mkWukongOrderAt = DotaTime()
		end
		bot:Action_UseAbilityOnLocation(wukongsCommandAbility, wukongsCommandLocation)
		return
	end
	boundlessStrikeDesire, boundlessStrikeLocation = X.ConsiderBoundlessStrike()
	if boundlessStrikeDesire > 0 then
		bot:Action_UseAbilityOnLocation(boundlessStrikeAbility, boundlessStrikeLocation)
		return
	end
	mischiefDesire = X.ConsiderMischief()
	if mischiefDesire > 0 then
		bot:Action_ClearActions(false)
		bot:ActionQueue_UseAbility(mischiefAbility)
		if not untransformAbility:IsHidden() or untransformAbility:IsFullyCastable() then
			bot:ActionQueue_Delay(0.2)
			bot:ActionQueue_UseAbility(untransformAbility)
		end
		return
	end
	treeDanceDesire, treeDanceTarget = X.ConsiderTreeDance()
	if treeDanceDesire > 0 then
		bot:Action_UseAbilityOnTree(treeDanceAbility, treeDanceTarget)
		return
	end
	primalSpringDesire, primalSpringLocation = X.ConsiderPrimalSpring()
	if primalSpringDesire > 0 then
		bot:Action_UseAbilityOnLocation(primalSpringAbility, primalSpringLocation)
		return
	end
	changingOfTheGuardDesire, changingOfTheGuardLocation = X.ConsiderChangingOfTheGuard()
	if changingOfTheGuardDesire > 0 then
		bot:Action_UseAbilityOnLocation(transfigurationAbility, changingOfTheGuardLocation)
		return
	end
end
function X.ConsiderBoundlessStrike()
	if not boundlessStrikeAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local castRange = Fu.GetProperCastRange(false, bot, boundlessStrikeAbility:GetCastRange())
	local castPoint = boundlessStrikeAbility:GetCastPoint()
	local radius = boundlessStrikeAbility:GetSpecialValueInt("strike_radius")
	local critDamage = bot:GetAttackDamage() * boundlessStrikeAbility:GetSpecialValueInt("strike_crit_mult") / 100
	botTarget = Fu.GetProperTarget(bot)
	local enemiesInRange = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(enemiesInRange) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and not Fu.IsSuspiciousIllusion(enemyHero)
		then
			if bot:HasModifier("modifier_monkey_king_quadruple_tap_bonuses") and Fu.GetHP(enemyHero) < 0.5 then
				return BOT_ACTION_DESIRE_HIGH, enemyHero:GetExtrapolatedLocation(castPoint)
			end
			if enemyHero:IsChanneling() or Fu.IsCastingUltimateAbility(enemyHero) then
				return BOT_ACTION_DESIRE_HIGH, enemyHero:GetLocation()
			end
			-- datafeed: Boundless Strike deals physical damage (a crit on his attack), not magical.
			if
				Fu.CanKillTarget(enemyHero, critDamage, DAMAGE_TYPE_PHYSICAL)
				and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
				and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
				and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
				and not enemyHero:HasModifier("modifier_templar_assassin_refraction_absorb")
			then
				return BOT_ACTION_DESIRE_HIGH, enemyHero:GetExtrapolatedLocation(castPoint)
			end
		end
	end
	-- Was: two heroes inside a 150 circle AND two enemies within 150 of Monkey King himself, which
	-- almost never holds. The staff stuns along a line (datafeed): strike_radius is the line's
	-- half-width and the cast range its length. Aim at the enemy whose line catches the most heroes.
	if isInTeamFight then
		local botLocation = bot:GetLocation()
		local lineLength = boundlessStrikeAbility:GetSpecialValueInt("strike_cast_range")
		if lineLength == nil or lineLength <= 0 then
			lineLength = castRange
		end
		local bestLoc, bestCount = nil, 0
		for _, enemyHero in pairs(enemiesInRange) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and not Fu.IsSuspiciousIllusion(enemyHero)
			then
				local aimLocation = enemyHero:GetExtrapolatedLocation(castPoint)
				local lineEnd = botLocation + (aimLocation - botLocation):Normalized() * lineLength
				local heroesHit = 0
				for _, otherEnemy in pairs(enemiesInRange) do
					if Fu.IsValidHero(otherEnemy) and Fu.CanCastOnNonMagicImmune(otherEnemy) then
						local lineInfo =
							PointToLineDistance(botLocation, lineEnd, otherEnemy:GetExtrapolatedLocation(castPoint))
						if lineInfo ~= nil and lineInfo.within and lineInfo.distance <= radius + 25 then
							heroesHit = heroesHit + 1
						end
					end
				end
				if heroesHit > bestCount then
					bestLoc, bestCount = aimLocation, heroesHit
				end
			end
		end
		if bestLoc ~= nil and bestCount >= 2 then
			if DotaTime() >= (bot._strikeLineLogAt or -999) then
				bot._strikeLineLogAt = DotaTime() + 5
				pcall(
					print,
					string.format("[OHA-MONKEY_KING] t=%.0f boundless-strike line heroes=%d", DotaTime(), bestCount)
				)
			end
			return BOT_ACTION_DESIRE_HIGH, bestLoc
		end
	end
	if isGoingOnSomeone then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, 1000, false, BOT_MODE_NONE)
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not Fu.IsDisabled(botTarget)
			and not botTarget:HasModifier("modifier_dazzle_shallow_grave")
			and not botTarget:HasModifier("modifier_templar_assassin_refraction_absorb")
		then
			local targetNearbyAllies = Fu.GetNearbyHeroes(botTarget, 1000, false, BOT_MODE_NONE)
			if nearbyAllies ~= nil and targetNearbyAllies ~= nil and #nearbyAllies >= #targetNearbyAllies then
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
			and Fu.IsInRange(bot, nearbyEnemies[1], castRange)
			and Fu.IsRunning(nearbyEnemies[1])
			and nearbyEnemies[1]:IsFacingLocation(bot:GetLocation(), 30)
			and not Fu.IsSuspiciousIllusion(nearbyEnemies[1])
		then
			local enemyNearbyAllies = Fu.GetNearbyHeroes(nearbyEnemies[1], 800, false, BOT_MODE_NONE)
			if
				enemyNearbyAllies ~= nil
				and (#enemyNearbyAllies > #nearbyAllies or hpRatio < 0.65 and bot:WasRecentlyDamagedByAnyHero(2.2))
			then
				return BOT_ACTION_DESIRE_HIGH, nearbyEnemies[1]:GetExtrapolatedLocation(castPoint)
			end
		end
	end
	if Fu.IsPushing(bot) or Fu.IsDefending(bot) then
		local aoe = bot:FindAoELocation(true, false, bot:GetLocation(), castRange, radius, castPoint, 0)
		local nearbyLaneCreeps = bot:GetNearbyLaneCreeps(castRange, true)
		if nearbyLaneCreeps ~= nil and #nearbyLaneCreeps >= 4 and aoe.count >= 4 then
			return BOT_ACTION_DESIRE_HIGH, aoe.targetloc
		end
		aoe = bot:FindAoELocation(true, true, bot:GetLocation(), castRange, radius, castPoint, 0)
		if aoe.count >= 1 then
			return BOT_ACTION_DESIRE_HIGH, aoe.targetloc
		end
	end
	if Fu.IsFarming(bot) then
		local aoe = bot:FindAoELocation(true, false, bot:GetLocation(), castRange, radius, castPoint, 0)
		if isAttacking then
			local nearbyNeutrals = bot:GetNearbyNeutralCreeps(castRange)
			if
				nearbyNeutrals ~= nil
				and (
					#nearbyNeutrals >= 3 and aoe.count >= 3
					or #nearbyNeutrals >= 2 and nearbyNeutrals[1]:IsAncientCreep() and aoe.count >= 2
				)
			then
				return BOT_ACTION_DESIRE_HIGH, aoe.targetloc
			end
			local nearbyLaneCreeps = bot:GetNearbyLaneCreeps(castRange, true)
			if nearbyLaneCreeps ~= nil and #nearbyLaneCreeps >= 3 and aoe.count >= 3 then
				return BOT_ACTION_DESIRE_HIGH, aoe.targetloc
			end
		end
	end
	if Fu.IsLaning(bot) then
		local killableCount = 0
		local killableCreeps = {}
		local nearbyLaneCreeps = bot:GetNearbyLaneCreeps(castRange, true)
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
		for _, creep in pairs(nearbyLaneCreeps) do
			if Fu.IsValid(creep) and creep:GetHealth() <= critDamage then
				killableCount = killableCount + 1
				table.insert(killableCreeps, creep)
			end
		end
		if killableCount >= 2 and mpRatio > 0.25 and nearbyEnemies ~= nil and #nearbyEnemies >= 1 then
			return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(killableCreeps)
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if
			Fu.IsRoshan(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, 500)
			and isAttacking
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, 400) and isAttacking then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	local alliesInRange = Fu.GetNearbyHeroes(bot, castRange, false, BOT_MODE_NONE)
	for _, allyHero in pairs(alliesInRange) do
		local allyNearbyEnemies = Fu.GetNearbyHeroes(allyHero, castRange, true, BOT_MODE_NONE)
		if
			Fu.IsRetreating(allyHero)
			and allyHero:WasRecentlyDamagedByAnyHero(2.1)
			and not allyHero:IsIllusion()
			and mpRatio > 0.59
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
				return BOT_ACTION_DESIRE_HIGH, allyNearbyEnemies[1]:GetExtrapolatedLocation(castPoint)
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.ConsiderTreeDance()
	if not treeDanceAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castRange = treeDanceAbility:GetCastRange()
	botTarget = Fu.GetProperTarget(bot)
	local nearbyEnemies = Fu.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE)
	if nearbyEnemies == nil then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	-- Was "J and q:IsFullyCastable()": Primal Spring is only gained while perched (datafeed), so
	-- from the ground this either never held, or (perched) it held again and Tree Dance (cooldown
	-- 0.9 to 0, checked before Spring) hopped to the next tree instead of springing. Now: Spring
	-- trained, off cooldown and affordable; no new hop for 3s after one, so Spring gets its turn;
	-- and the tree must be within Spring's range of the target (it was just the first tree found).
	local springReady = primalSpringAbility:IsTrained()
		and primalSpringAbility:GetCooldownTimeRemaining() <= 0
		and bot:GetMana() >= primalSpringAbility:GetManaCost()
	if isGoingOnSomeone and springReady and DotaTime() - (bot._mkTreeDanceAt or -999) > 3 then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, 1000, false, BOT_MODE_NONE)
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not botTarget:HasModifier("modifier_dazzle_shallow_grave")
			and not botTarget:HasModifier("modifier_templar_assassin_refraction_absorb")
		then
			local nearbyTrees = bot:GetNearbyTrees(castRange)
			local targetNearbyAllies = Fu.GetNearbyHeroes(botTarget, 1000, false, BOT_MODE_NONE)
			local springRange = primalSpringAbility:GetCastRange()
			if springRange == nil or springRange <= 0 then
				springRange = 800
			end
			local tree, treeDistance = nil, math.huge
			for _, treeId in pairs(nearbyTrees or {}) do
				local treeLocation = GetTreeLocation(treeId)
				local distanceToTarget = GetUnitToLocationDistance(botTarget, treeLocation)
				if
					distanceToTarget <= springRange - 100
					and distanceToTarget < treeDistance
					and (IsLocationVisible(treeLocation) or IsLocationPassable(treeLocation))
				then
					tree, treeDistance = treeId, distanceToTarget
				end
			end
			if
				nearbyAllies ~= nil
				and targetNearbyAllies ~= nil
				and #nearbyAllies >= #targetNearbyAllies
				and tree ~= nil
			then
				bot._mkTreeDanceAt = DotaTime()
				pcall(
					print,
					string.format(
						"[OHA-MONKEY_KING] t=%.0f tree-dance engage target=%s tree-to-target=%d",
						DotaTime(),
						(string.gsub(botTarget:GetUnitName(), "npc_dota_hero_", "")),
						math.floor(treeDistance)
					)
				)
				return BOT_ACTION_DESIRE_HIGH, tree
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
			and Fu.IsInRange(bot, nearbyEnemies[1], castRange)
			and Fu.IsRunning(nearbyEnemies[1])
			and nearbyEnemies[1]:IsFacingLocation(bot:GetLocation(), 30)
			and not Fu.IsSuspiciousIllusion(nearbyEnemies[1])
		then
			local enemyNearbyAllies = Fu.GetNearbyHeroes(nearbyEnemies[1], 800, false, BOT_MODE_NONE)
			if
				enemyNearbyAllies ~= nil
				and (#enemyNearbyAllies > #nearbyAllies or hpRatio < 0.65 and bot:WasRecentlyDamagedByAnyHero(2.2))
				and bot:DistanceFromFountain() > 1000
			then
				local nearbyTrees = bot:GetNearbyTrees(castRange)
				local escapeTree = X.GetTreeNearestOurAncient(nearbyTrees)
				if
					escapeTree ~= nil
					and (
						IsLocationVisible(GetTreeLocation(escapeTree))
						or IsLocationPassable(GetTreeLocation(escapeTree))
					)
				then
					return BOT_ACTION_DESIRE_HIGH, escapeTree
				end
			end
		end
	end
	if Fu.IsFarming(bot) and mpRatio > 0.35 then
		local nearbyNeutrals = bot:GetNearbyNeutralCreeps(castRange)
		if
			nearbyNeutrals ~= nil
			and (#nearbyNeutrals >= 3 or #nearbyNeutrals >= 2 and nearbyNeutrals[1]:IsAncientCreep())
		then
			local creepTrees = nearbyNeutrals[1]:GetNearbyTrees(castRange)
			if
				creepTrees ~= nil
				and #creepTrees >= 1
				and (
					IsLocationVisible(GetTreeLocation(creepTrees[1]))
					or IsLocationPassable(GetTreeLocation(creepTrees[1]))
				)
			then
				return BOT_ACTION_DESIRE_HIGH, creepTrees[1]
			end
		end
		local nearbyLaneCreeps = bot:GetNearbyLaneCreeps(castRange, true)
		if nearbyLaneCreeps ~= nil and #nearbyLaneCreeps >= 3 then
			local creepTrees = nearbyLaneCreeps[1]:GetNearbyTrees(castRange)
			if
				creepTrees ~= nil
				and #creepTrees >= 1
				and (
					IsLocationVisible(GetTreeLocation(creepTrees[1]))
					or IsLocationPassable(GetTreeLocation(creepTrees[1]))
				)
			then
				return BOT_ACTION_DESIRE_HIGH, creepTrees[1]
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function X.ConsiderPrimalSpring()
	if
		primalSpringAbility:IsHidden()
		or not primalSpringAbility:IsFullyCastable()
		or not primalSpringAbility:IsActivated()
	then
		SpringSkip(
			primalSpringAbility:IsHidden() and "hidden"
				or not primalSpringAbility:IsActivated() and "not-activated"
				or "not-castable"
		)
		return BOT_ACTION_DESIRE_NONE, 0
	end
	-- Primal Spring has no "max_distance" value (game KV: only impact_damage/slow/radius; the leap
	-- range is its AbilityCastRange, 800), so the old lookup read 0 and the spring never aimed anywhere.
	local castRange = primalSpringAbility:GetCastRange()
	local channelTime = primalSpringAbility:GetChannelTime()
	local radius = primalSpringAbility:GetSpecialValueInt("impact_radius")
	if isInTeamFight then
		local aoe = bot:FindAoELocation(true, true, bot:GetLocation(), castRange, radius, channelTime, 0)
		if aoe.count >= 2 then
			-- Was enemies within impact_radius of Monkey King himself, not of the landing spot (up to
			-- 800 away), so a group out there never counted.
			local enemiesAtLanding = Fu.GetEnemiesNearLoc(aoe.targetloc, radius)
			if enemiesAtLanding ~= nil and #enemiesAtLanding >= 2 then
				return BOT_ACTION_DESIRE_HIGH, aoe.targetloc
			end
		end
	end
	if isGoingOnSomeone then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, 1000, false, BOT_MODE_NONE)
		local weakestTarget = Fu.GetAttackableWeakestUnit(bot, castRange, true, true)
		if
			Fu.IsValidTarget(weakestTarget)
			and not Fu.IsSuspiciousIllusion(weakestTarget)
			and not weakestTarget:HasModifier("modifier_abaddon_borrowed_time")
			and not weakestTarget:HasModifier("modifier_dazzle_shallow_grave")
			and not weakestTarget:HasModifier("modifier_templar_assassin_refraction_absorb")
			and not Fu.IsLocationInChrono(weakestTarget:GetLocation())
			and not Fu.IsLocationInBlackHole(weakestTarget:GetLocation())
		then
			local targetNearbyAllies = Fu.GetNearbyHeroes(weakestTarget, 1000, false, BOT_MODE_NONE)
			if nearbyAllies ~= nil and targetNearbyAllies ~= nil and #nearbyAllies >= #targetNearbyAllies then
				return BOT_ACTION_DESIRE_HIGH, weakestTarget:GetExtrapolatedLocation(channelTime)
			end
			SpringSkip(
				string.format(
					"outnumbered(%d<%d)",
					nearbyAllies ~= nil and #nearbyAllies or -1,
					targetNearbyAllies ~= nil and #targetNearbyAllies or -1
				)
			)
		else
			SpringSkip("no-target-in-" .. tostring(castRange))
		end
	else
		SpringSkip("not-going-on-someone")
	end
	if isRetreating then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, 800, false, BOT_MODE_NONE)
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, 800, true, BOT_MODE_NONE)
		if
			nearbyAllies ~= nil
			and nearbyEnemies
			and Fu.IsValidHero(nearbyEnemies[1])
			and Fu.CanCastOnNonMagicImmune(nearbyEnemies[1])
			and Fu.IsInRange(bot, nearbyEnemies[1], castRange)
			and Fu.IsRunning(nearbyEnemies[1])
			and nearbyEnemies[1]:IsFacingLocation(bot:GetLocation(), 30)
			and not Fu.IsSuspiciousIllusion(nearbyEnemies[1])
		then
			local enemyNearbyAllies = Fu.GetNearbyHeroes(nearbyEnemies[1], 800, false, BOT_MODE_NONE)
			if
				enemyNearbyAllies ~= nil
				and (#enemyNearbyAllies > #nearbyAllies or hpRatio < 0.71 and bot:WasRecentlyDamagedByAnyHero(2.2))
			then
				local escapeLocation = Fu.GetEscapeLoc()
				return BOT_ACTION_DESIRE_MODERATE, Fu.Site.GetXUnitsTowardsLocation(bot, escapeLocation, castRange)
			end
		end
	end
	if Fu.IsPushing(bot) or Fu.IsDefending(bot) then
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, 1000, true, BOT_MODE_NONE)
		local aoe = bot:FindAoELocation(true, false, bot:GetLocation(), castRange, radius, channelTime, 0)
		local nearbyLaneCreeps = bot:GetNearbyLaneCreeps(castRange, true)
		if
			nearbyLaneCreeps ~= nil
			and #nearbyLaneCreeps >= 4
			and aoe.count >= 4
			and nearbyEnemies ~= nil
			and #nearbyEnemies == 0
		then
			return BOT_ACTION_DESIRE_HIGH, aoe.targetloc
		end
	end
	if Fu.IsFarming(bot) and mpRatio > 0.35 then
		local aoe = bot:FindAoELocation(true, false, bot:GetLocation(), castRange, radius, channelTime, 0)
		local nearbyNeutrals = bot:GetNearbyNeutralCreeps(castRange)
		if
			nearbyNeutrals ~= nil
			and (
				#nearbyNeutrals >= 3 and aoe.count >= 3
				or #nearbyNeutrals >= 2 and nearbyNeutrals[1]:IsAncientCreep() and aoe.count >= 2
			)
		then
			return BOT_ACTION_DESIRE_HIGH, aoe.targetloc
		end
		local nearbyLaneCreeps = bot:GetNearbyLaneCreeps(castRange, true)
		if nearbyLaneCreeps ~= nil and #nearbyLaneCreeps >= 3 and aoe.count >= 3 then
			return BOT_ACTION_DESIRE_HIGH, aoe.targetloc
		end
	end
	if Fu.IsLaning(bot) then
		local aoe = bot:FindAoELocation(true, false, bot:GetLocation(), castRange, radius, channelTime, 0)
		local nearbyLaneCreeps = bot:GetNearbyLaneCreeps(castRange, true)
		if nearbyLaneCreeps ~= nil and #nearbyLaneCreeps >= 2 and aoe.count >= 2 then
			return BOT_ACTION_DESIRE_HIGH, aoe.targetloc
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.ConsiderMischief()
	if not mischiefAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
	end
	if Fu.IsStunProjectileIncoming(bot, 600) then
		return BOT_ACTION_DESIRE_HIGH
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderWukongsCommand()
	if not wukongsCommandAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local castRange = wukongsCommandAbility:GetSpecialValueInt("cast_range")
	local radius = wukongsCommandAbility:GetSpecialValueInt("second_radius")
	botTarget = Fu.GetProperTarget(bot)
	if isInTeamFight then
		local aoe = bot:FindAoELocation(true, true, bot:GetLocation(), castRange, radius / 2, 1, 0)
		if aoe.count >= 2 then
			-- fix: count enemies at the cast location (was around the bot)
			local nearbyEnemies = Fu.GetEnemiesNearLoc(aoe.targetloc, radius)
			if
				nearbyEnemies ~= nil
				and #nearbyEnemies >= 2
				and not Fu.IsLocationInChrono(aoe.targetloc)
				and not Fu.IsLocationInBlackHole(aoe.targetloc)
			then
				return BOT_ACTION_DESIRE_HIGH, aoe.targetloc
			end
		end
	end
	if isGoingOnSomeone then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, 1000, false, BOT_MODE_NONE)
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not botTarget:HasModifier("modifier_dazzle_shallow_grave")
			and not botTarget:HasModifier("modifier_templar_assassin_refraction_absorb")
			and not Fu.IsLocationInChrono(botTarget:GetLocation())
			and not Fu.IsLocationInBlackHole(botTarget:GetLocation())
		then
			local targetNearbyAllies = Fu.GetNearbyHeroes(botTarget, 1000, false, BOT_MODE_NONE)
			if nearbyAllies ~= nil and targetNearbyAllies ~= nil and #nearbyAllies >= #targetNearbyAllies then
				return BOT_ACTION_DESIRE_HIGH, botTarget:GetExtrapolatedLocation(1)
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
-- Escape tree for Tree Dance: the one nearest our ancient (was the global GetFurthestTree).
function X.GetTreeNearestOurAncient(trees)
	if GetAncient(GetTeam()) == nil then
		return nil
	end
	local bestTree = nil
	local closestDistance = 10000
	for _, tree in pairs(trees) do
		local distance = GetUnitToLocationDistance(GetAncient(GetTeam()), GetTreeLocation(tree))
		if distance < closestDistance then
			bestTree = tree
			closestDistance = distance
		end
	end
	return bestTree
end
function X.ConsiderChangingOfTheGuard()
	if not Fu.CanCastAbility(transfigurationAbility) or bot:IsRooted() then
		return BOT_ACTION_DESIRE_NONE
	end
	if bot:HasModifier("modifier_monkey_king_fur_army_bonus_damage") then
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE)
		local nearbyAllies = Fu.GetNearbyHeroes(bot, 1600, false, BOT_MODE_NONE)
		if
			Fu.IsStunProjectileIncoming(bot, 550) and #nearbyEnemies > #nearbyAllies
			or Fu.GetAttackProjectileDamageByRange(bot, 900) > bot:GetHealth()
		then
			return BOT_ACTION_DESIRE_HIGH, bot:GetLocation()
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
return X
