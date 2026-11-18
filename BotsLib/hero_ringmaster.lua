-- Ringmaster: skill build, item build, and ability use for this hero.
local X = {}
local bot = GetBot()
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local AbilityContext = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local Minion = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local sTalentList = Fu.Skill.GetTalentList(bot)
local sAbilityList = Fu.Skill.GetAbilityList(bot)
local sRole = Fu.Item.GetRoleItemsBuyList(bot)
local tTalentTreeList = { ["t25"] = { 10, 0 }, ["t20"] = { 0, 10 }, ["t15"] = { 0, 10 }, ["t10"] = { 10, 0 } }
local tAllAbilityBuildList = { { 3, 1, 1, 2, 1, 6, 1, 3, 3, 3, 6, 2, 2, 2, 6 } }
local nAbilityBuildList = Fu.Skill.GetRandomBuild(tAllAbilityBuildList)
local nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList)
local sRoleItemsBuyList = {}
sRoleItemsBuyList["pos_4"] = {
	"item_enchanted_mango",
	"item_blood_grenade",
	"item_priest_outfit",
	"item_blink",
	"item_glimmer_cape",
	"item_rod_of_atos",
	"item_aether_lens",
	"item_gungir",
	"item_shivas_guard",
	"item_aghanims_shard",
	"item_ultimate_scepter",
	"item_ultimate_scepter_2",
	"item_sheepstick",
	"item_moon_shard",
	"item_octarine_core",
}
sRoleItemsBuyList["pos_5"] = {
	"item_blood_grenade",
	"item_crystal_maiden_outfit",
	"item_blink",
	"item_glimmer_cape",
	"item_aether_lens",
	"item_pipe",
	"item_rod_of_atos",
	"item_gungir",
	"item_shivas_guard",
	"item_cyclone",
	"item_sheepstick",
	"item_wind_waker",
	"item_moon_shard",
	"item_ultimate_scepter_2",
}
sRoleItemsBuyList["pos_3"] = {
	"item_tango",
	"item_double_branches",
	"item_blight_stone",
	"item_tranquil_boots",
	"item_magic_wand",
	"item_maelstrom",
	"item_force_staff",
	"item_gungir",
	"item_boots_of_bearing",
	"item_shivas_guard",
	"item_ultimate_scepter",
	"item_sheepstick",
	"item_hurricane_pike",
	"item_aghanims_shard",
	"item_ultimate_scepter_2",
	"item_greater_crit",
	"item_moon_shard",
}
sRoleItemsBuyList["pos_1"] = {
	"item_crystal_maiden_outfit",
	"item_rod_of_atos",
	"item_maelstrom",
	"item_aether_lens",
	"item_gungir",
	"item_black_king_bar",
	"item_travel_boots",
	"item_orchid",
	"item_bloodthorn",
	"item_ultimate_scepter",
	"item_moon_shard",
	"item_sheepstick",
	"item_travel_boots_2",
	"item_ultimate_scepter_2",
}
sRoleItemsBuyList["pos_2"] = sRoleItemsBuyList["pos_1"]
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
function X.MinionThink(minionUnit)
	Minion.MinionThink(minionUnit)
end
local tameTheBeastsAbility =
	SafeAbility(bot:GetAbilityByName("ringmaster_tame_the_beasts"), "ringmaster_tame_the_beasts", "ringmaster")
local tameTheBeastsCrackAbility = SafeAbility(
	bot:GetAbilityByName("ringmaster_tame_the_beasts_crack"),
	"ringmaster_tame_the_beasts_crack",
	"ringmaster"
)
local escapeActAbility = SafeAbility(bot:GetAbilityByName("ringmaster_the_box"), "ringmaster_the_box", "ringmaster")
local impalementArtsAbility =
	SafeAbility(bot:GetAbilityByName("ringmaster_impalement"), "ringmaster_impalement", "ringmaster")
local spotlightAbility = SafeAbility(bot:GetAbilityByName("ringmaster_spotlight"), "ringmaster_spotlight", "ringmaster")
local wheelOfWonderAbility = SafeAbility(bot:GetAbilityByName("ringmaster_wheel"), "ringmaster_wheel", "ringmaster")
local emptySouvenirAbility =
	SafeAbility(bot:GetAbilityByName("ringmaster_empty_souvenir"), "ringmaster_empty_souvenir", "ringmaster")
local funhouseMirrorAbility =
	SafeAbility(bot:GetAbilityByName("ringmaster_funhouse_mirror"), "ringmaster_funhouse_mirror", "ringmaster")
local strongmanTonicAbility =
	SafeAbility(bot:GetAbilityByName("ringmaster_strongman_tonic"), "ringmaster_strongman_tonic", "ringmaster")
local whoopeeCushionAbility =
	SafeAbility(bot:GetAbilityByName("ringmaster_whoopee_cushion"), "ringmaster_whoopee_cushion", "ringmaster")
local unicycleAbility =
	SafeAbility(bot:GetAbilityByName("ringmaster_summon_unicycle"), "ringmaster_summon_unicycle", "ringmaster")
local tameTheBeastsDesire, tameTheBeastsLocation
local tameTheBeastsCrackDesire
local escapeActDesire, escapeActTarget
local impalementArtsDesire, impalementArtsLocation
local spotlightDesire, spotlightLocation
local wheelOfWonderDesire, wheelOfWonderLocation
local funhouseMirrorDesire
local strongmanTonicDesire, strongmanTonicTarget
local whoopeeCushionDesire
local unicycleDesire
-- Weighted Pie and Crystal Ball souvenirs (#49): never cast before.
local weightedPieAbility =
	SafeAbility(bot:GetAbilityByName("ringmaster_weighted_pie"), "ringmaster_weighted_pie", "ringmaster")
local crystalBallAbility =
	SafeAbility(bot:GetAbilityByName("ringmaster_crystal_ball"), "ringmaster_crystal_ball", "ringmaster")
local whipCastTime
local botTarget, botLevel
local isEngaging
local isRetreating
local isAttacking
local hpRatio
-- Diagnostic (#49): which souvenir Ringmaster holds and whether it can be cast. Game 043: he got Strongman Tonic
-- (~26:26) and Whoopee Cushion (~34:40), the engine warned "trying to unhide in a slot > 5", and no line said
-- whether either was used. Every 30s: each souvenir that is not hidden, with castable / cooldown / level.
function X.LogSouvenirState()
	if DotaTime() < (bot._souvenirStateAt or -999) then
		return
	end
	bot._souvenirStateAt = DotaTime() + 30
	local parts = {}
	for _, pair in ipairs({
		{ "tonic", strongmanTonicAbility },
		{ "cushion", whoopeeCushionAbility },
		{ "mirror", funhouseMirrorAbility },
		{ "unicycle", unicycleAbility },
		{ "pie", weightedPieAbility },
		{ "ball", crystalBallAbility },
	}) do
		local ability = pair[2]
		if ability ~= nil and not ability:IsNull() and not ability:IsHidden() and ability:GetLevel() > 0 then
			parts[#parts + 1] = string.format(
				"%s(castable=%s cd=%.0f lvl=%d)",
				pair[1],
				tostring(ability:IsFullyCastable()),
				ability:GetCooldownTimeRemaining(),
				ability:GetLevel()
			)
		end
	end
	if #parts > 0 then
		pcall(print, string.format("[OHA-RINGMASTER] t=%.0f souvenirs %s", DotaTime(), table.concat(parts, " ")))
	end
end
function X.SkillsComplement()
	pcall(X.LogSouvenirState)
	if Fu.CanNotUseAbility(bot) or bot:IsCastingAbility() or bot:IsChanneling() then
		return
	end
	local abilityContext = AbilityContext.Build(bot)
	isEngaging = abilityContext.isEngaging
	isRetreating = abilityContext.isRetreating
	isAttacking = Fu.IsAttacking(bot)
	hpRatio = abilityContext.hp
	botTarget = abilityContext.target
	botLevel = bot:GetLevel()
	whoopeeCushionDesire = X.ConsiderWhoopeeCushion()
	if whoopeeCushionDesire > 0 then
		X.LogSouvenir("whoopee_cushion", "cast")
		bot:Action_UseAbility(whoopeeCushionAbility)
		return
	end
	wheelOfWonderDesire, wheelOfWonderLocation = X.ConsiderWheelOfWonder()
	if wheelOfWonderDesire > 0 then
		Fu.SetQueuePtToINT(bot, false)
		bot:ActionQueue_UseAbilityOnLocation(wheelOfWonderAbility, wheelOfWonderLocation)
		return
	end
	tameTheBeastsCrackDesire = X.ConsiderTameTheBeastsCrack()
	if tameTheBeastsCrackDesire > 0 then
		bot:Action_UseAbility(tameTheBeastsCrackAbility)
		bot.whip_to_cancel = false
		bot.whip_to_kill = false
		bot.whip_to_kill_target = nil
		bot.whip_to_engage = false
		bot.whip_to_retreat = false
		bot.whip_to_push = false
		bot.whip_to_defend = false
		bot.whip_to_farm = false
		bot.whip_to_miniboss = false
		bot.whip_to_aoe_kill = false
		return
	end
	tameTheBeastsDesire, tameTheBeastsLocation = X.ConsiderTameTheBeasts()
	if tameTheBeastsDesire > 0 then
		Fu.SetQueuePtToINT(bot, true)
		bot:ActionQueue_UseAbilityOnLocation(tameTheBeastsAbility, tameTheBeastsLocation)
		whipCastTime = DotaTime()
		return
	end
	escapeActDesire, escapeActTarget = X.ConsiderEscapeAct()
	-- return after queueing: without it a later Action_* (Tonic, Funhouse Mirror, Unicycle) in the same
	-- think replaced the queue, so the Box save or the dagger was dropped.
	if escapeActDesire > 0 then
		Fu.SetQueuePtToINT(bot, false)
		bot:ActionQueue_UseAbilityOnEntity(escapeActAbility, escapeActTarget)
		return
	end
	impalementArtsDesire, impalementArtsLocation = X.ConsiderImpalementArts()
	if impalementArtsDesire > 0 then
		Fu.SetQueuePtToINT(bot, false)
		bot:ActionQueue_UseAbilityOnLocation(impalementArtsAbility, impalementArtsLocation)
		return
	end
	strongmanTonicDesire, strongmanTonicTarget = X.ConsiderStrongmanTonic()
	if strongmanTonicDesire > 0 then
		X.LogSouvenir("strongman_tonic", "cast")
		bot:Action_UseAbilityOnEntity(strongmanTonicAbility, strongmanTonicTarget)
		return
	end
	spotlightDesire, spotlightLocation = X.ConsiderSpotlight()
	if spotlightDesire > 0 then
		Fu.SetQueuePtToINT(bot, false)
		bot:ActionQueue_UseAbilityOnLocation(spotlightAbility, spotlightLocation)
		return
	end
	funhouseMirrorDesire = X.ConsiderFunhouseMirror()
	if funhouseMirrorDesire > 0 then
		X.LogSouvenir("funhouse_mirror", "cast")
		bot:Action_UseAbility(funhouseMirrorAbility)
		return
	end
	unicycleDesire = X.ConsiderUnicycle()
	if unicycleDesire > 0 then
		X.LogSouvenir("unicycle", "cast")
		bot:Action_UseAbility(unicycleAbility)
		return
	end
	local pieTarget = X.ConsiderWeightedPie()
	if pieTarget ~= nil then
		bot:Action_UseAbilityOnEntity(weightedPieAbility, pieTarget)
		return
	end
	local ballLocation = X.ConsiderCrystalBall()
	if ballLocation ~= nil then
		bot:Action_UseAbilityOnLocation(crystalBallAbility, ballLocation)
		return
	end
end
function X.LogSouvenir(name, why)
	if DotaTime() >= (bot._souvenirLogAt or -999) then
		bot._souvenirLogAt = DotaTime() + 3
		pcall(print, string.format("[OHA-RINGMASTER] t=%.0f souvenir=%s why=%s", DotaTime(), name, why))
	end
end
-- Weighted Pie (game data: hero/creep target, 750 range, pushes 400 over 0.3s, blinds 3s, slows up to 45%):
-- on the closest chaser while retreating, or on a target escaping while engaging.
function X.ConsiderWeightedPie()
	if not Fu.CanCastAbility(weightedPieAbility) then
		return nil
	end
	local castRange = 750
	if isRetreating then
		local closest, closestDistance = nil, castRange + 1
		for _, enemyHero in pairs(bot:GetNearbyHeroes(castRange, true, BOT_MODE_NONE) or {}) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.IsChasingTarget(enemyHero, bot)
				and GetUnitToUnitDistance(bot, enemyHero) < closestDistance
			then
				closest, closestDistance = enemyHero, GetUnitToUnitDistance(bot, enemyHero)
			end
		end
		if closest ~= nil then
			X.LogSouvenir("weighted_pie", "chaser")
			return closest
		end
	end
	if
		isEngaging
		and Fu.IsValidHero(botTarget)
		and Fu.IsInRange(bot, botTarget, castRange)
		and Fu.CanCastOnNonMagicImmune(botTarget)
		and Fu.IsRunning(botTarget)
		and not botTarget:IsFacingLocation(bot:GetLocation(), 90)
	then
		X.LogSouvenir("weighted_pie", "escaping-target")
		return botTarget
	end
	return nil
end
-- Crystal Ball (game data: point AoE, radius 450, 5s true sight): on an invisible enemy hero within 1600, or on
-- an enemy hero last seen in the fog near a fight.
function X.ConsiderCrystalBall()
	if not Fu.CanCastAbility(crystalBallAbility) then
		return nil
	end
	for _, enemyHero in pairs(bot:GetNearbyHeroes(1600, true, BOT_MODE_NONE) or {}) do
		if Fu.IsValidHero(enemyHero) and enemyHero:IsInvisible() then
			X.LogSouvenir("crystal_ball", "invisible")
			return enemyHero:GetLocation()
		end
	end
	if Fu.IsInTeamFight(bot, 1200) then
		for _, playerId in pairs(GetTeamPlayers(GetOpposingTeam())) do
			local info = IsHeroAlive(playerId) and GetHeroLastSeenInfo(playerId) or nil
			local lastSeen = info ~= nil and info[1] or nil
			if
				lastSeen ~= nil
				and lastSeen.time_since_seen > 0.5
				and lastSeen.time_since_seen < 3
				and GetUnitToLocationDistance(bot, lastSeen.location) < 1200
			then
				X.LogSouvenir("crystal_ball", "fog")
				return lastSeen.location
			end
		end
	end
	return nil
end
function X.ConsiderTameTheBeasts()
	if not Fu.CanCastAbility(tameTheBeastsAbility) then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local castRange = Fu.GetProperCastRange(false, bot, tameTheBeastsAbility:GetCastRange())
	local castPoint = tameTheBeastsAbility:GetCastPoint()
	local startWidth = tameTheBeastsAbility:GetSpecialValueInt("start_width")
	local endWidth = tameTheBeastsAbility:GetSpecialValueInt("end_width")
	local minDamage = tameTheBeastsAbility:GetSpecialValueInt("damage_min")
	local maxDamage = tameTheBeastsAbility:GetSpecialValueInt("damage_max")
	local manaCost = tameTheBeastsAbility:GetManaCost()
	local nearbyAllies = bot:GetNearbyHeroes(1600, false, BOT_MODE_NONE)
	local nearbyEnemies = bot:GetNearbyHeroes(1600, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.IsInRange(bot, enemyHero, castRange)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
		then
			if enemyHero:HasModifier("modifier_teleporting") then
				bot.whip_to_cancel = true
				return BOT_ACTION_DESIRE_HIGH, enemyHero:GetLocation()
			end
			if
				Fu.CanKillTarget(enemyHero, maxDamage, DAMAGE_TYPE_MAGICAL)
				and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
				and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
				and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
				and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
			then
				bot.whip_to_kill = true
				bot.whip_to_kill_target = enemyHero
				return BOT_ACTION_DESIRE_HIGH, enemyHero:GetLocation()
			end
		end
	end
	if isEngaging then
		if
			Fu.IsValidHero(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and (not Fu.IsChasingTarget(bot, botTarget) or Fu.IsInRange(bot, botTarget, endWidth))
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and not Fu.IsDisabled(botTarget)
			and not botTarget:HasModifier("modifier_faceless_void_chronosphere_freeze")
			and not botTarget:HasModifier("modifier_legion_commander_duel")
			and #nearbyAllies < #nearbyEnemies + 3
		then
			local aoeLocation = bot:FindAoELocation(true, true, botTarget:GetLocation(), startWidth, startWidth, 0, 0)
			local targetLocation = botTarget:GetLocation()
			if aoeLocation.count > 1 then
				targetLocation = aoeLocation.targetloc
			end
			bot.whip_to_engage = true
			return BOT_ACTION_DESIRE_HIGH, targetLocation
		end
	end
	if isRetreating and not Fu.IsRealInvisible(bot) then
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.IsInRange(bot, enemyHero, startWidth)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and not Fu.IsDisabled(enemyHero)
				and bot:WasRecentlyDamagedByHero(enemyHero, 3.0)
				and (hpRatio < 0.65 or Fu.IsChasingTarget(enemyHero, bot))
			then
				local aoeLocation =
					bot:FindAoELocation(true, true, enemyHero:GetLocation(), startWidth, startWidth, 0, 0)
				local targetLocation = (bot:GetLocation() + enemyHero:GetLocation()) / 2
				if aoeLocation.count > 1 then
					targetLocation = aoeLocation.targetloc
				end
				bot.whip_to_retreat = true
				return BOT_ACTION_DESIRE_HIGH, targetLocation
			end
		end
	end
	local laneCreeps = bot:GetNearbyLaneCreeps(castRange + 150, true)
	if Fu.IsPushing(bot) and Fu.GetManaAfter(manaCost) > 0.45 then
		if
			#laneCreeps >= 4
			and Fu.CanBeAttacked(laneCreeps[1])
			and not Fu.IsRunning(laneCreeps[1])
			and (Fu.IsCore(bot) or not Fu.IsThereNonSelfCoreNearby(1600))
		then
			local aoeLocation = bot:FindAoELocation(true, false, laneCreeps[1]:GetLocation(), endWidth, endWidth, 0, 0)
			local targetLocation = Fu.GetCenterOfUnits(laneCreeps)
			if aoeLocation.count >= 4 then
				targetLocation = aoeLocation.targetloc
			end
			bot.whip_to_push = true
			return BOT_ACTION_DESIRE_HIGH, targetLocation
		end
	end
	if Fu.IsDefending(bot) then
		local aoeLocation = bot:FindAoELocation(true, true, bot:GetLocation(), castRange, endWidth, 0, 0)
		if aoeLocation.count >= 2 then
			bot.whip_to_defend = true
			return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
		end
		if
			#laneCreeps >= 4
			and Fu.CanBeAttacked(laneCreeps[1])
			and not Fu.IsRunning(laneCreeps[1])
			and (Fu.IsCore(bot) or not Fu.IsThereNonSelfCoreNearby(1600))
		then
			aoeLocation = bot:FindAoELocation(true, false, laneCreeps[1]:GetLocation(), endWidth, endWidth, 0, 0)
			local targetLocation = Fu.GetCenterOfUnits(laneCreeps)
			if aoeLocation.count >= 4 then
				targetLocation = aoeLocation.targetloc
			end
			bot.whip_to_defend = true
			return BOT_ACTION_DESIRE_HIGH, targetLocation
		end
	end
	if Fu.IsFarming(bot) and Fu.GetManaAfter(manaCost) > 0.33 then
		local nearbyCreeps = bot:GetNearbyCreeps(castRange + 150, true)
		if
			Fu.CanBeAttacked(nearbyCreeps[1])
			and not Fu.IsRunning(nearbyCreeps[1])
			and (#nearbyCreeps >= 2 or #nearbyCreeps >= 1 and nearbyCreeps[1]:IsAncientCreep())
		then
			local aoeLocation =
				bot:FindAoELocation(true, false, nearbyCreeps[1]:GetLocation(), endWidth, endWidth, 0, 0)
			local targetLocation = Fu.GetCenterOfUnits(nearbyCreeps)
			if aoeLocation.count >= 4 then
				targetLocation = aoeLocation.targetloc
			end
			bot.whip_to_farm = true
			return BOT_ACTION_DESIRE_HIGH, targetLocation
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if
			Fu.IsRoshan(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and isAttacking
		then
			bot.whip_to_miniboss = true
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if
			Fu.IsTormentor(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and isAttacking
		then
			bot.whip_to_miniboss = true
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	if Fu.IsCore(bot) or not Fu.IsThereNonSelfCoreNearby(1600) then
		local nearbyCreeps = bot:GetNearbyCreeps(castRange, true)
		local killableCreeps = {}
		for _, creep in pairs(nearbyCreeps) do
			if
				Fu.IsValid(creep)
				and Fu.CanBeAttacked(creep)
				and not Fu.IsRunning(creep)
				and Fu.CanKillTarget(creep, maxDamage, DAMAGE_TYPE_MAGICAL)
			then
				table.insert(killableCreeps, creep)
			end
		end
		if Fu.IsValid(killableCreeps[1]) then
			local aoeLocation =
				bot:FindAoELocation(true, false, killableCreeps[1]:GetLocation(), endWidth, endWidth, 0, 0)
			if Fu.IsLaning(bot) then
				if
					#killableCreeps >= 2
					or #killableCreeps == 1
						and Fu.GetManaAfter(manaCost) > 0.18
						and string.find(killableCreeps[1]:GetUnitName(), "ranged")
						and Fu.IsValidHero(nearbyEnemies[1])
						and Fu.IsInRange(killableCreeps[1], nearbyEnemies[1], startWidth)
				then
					bot.whip_to_aoe_kill = true
					return BOT_ACTION_DESIRE_HIGH, killableCreeps[1]:GetLocation()
				end
			end
			if aoeLocation.count >= 4 and #killableCreeps >= 3 then
				bot.whip_to_aoe_kill = true
				return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.ConsiderTameTheBeastsCrack()
	if not Fu.CanCastAbility(tameTheBeastsCrackAbility) then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local channelTime = tameTheBeastsAbility:GetChannelTime()
	local castRange = Fu.GetProperCastRange(bot, false, tameTheBeastsAbility:GetCastRange())
	local castPoint = tameTheBeastsAbility:GetCastPoint()
	local startWidth = tameTheBeastsAbility:GetSpecialValueInt("start_width")
	local endWidth = tameTheBeastsAbility:GetSpecialValueInt("end_width")
	local minDamage = tameTheBeastsAbility:GetSpecialValueInt("damage_min")
	local maxDamage = tameTheBeastsAbility:GetSpecialValueInt("damage_max")
	local manaCost = tameTheBeastsAbility:GetManaCost()
	local nearbyAllies = bot:GetNearbyHeroes(1600, false, BOT_MODE_NONE)
	local nearbyEnemies = bot:GetNearbyHeroes(1600, true, BOT_MODE_NONE)
	local channelledTime = math.min(DotaTime() - whipCastTime, channelTime)
	local currentDamage = RemapValClamped(channelledTime, 0, 1, minDamage, maxDamage)
	if bot.whip_to_aoe_kill then
		return BOT_ACTION_DESIRE_NONE
	end
	if bot.whip_to_cancel then
		return BOT_ACTION_DESIRE_HIGH
	end
	if bot.whip_to_kill then
		if Fu.IsValidHero(bot.whip_to_kill_target) and Fu.CanCastOnNonMagicImmune(bot.whip_to_kill_target) then
			if
				Fu.CanKillTarget(bot.whip_to_kill_target, currentDamage, DAMAGE_TYPE_MAGICAL)
				and not bot.whip_to_kill_target:HasModifier("modifier_abaddon_borrowed_time")
				and not bot.whip_to_kill_target:HasModifier("modifier_dazzle_shallow_grave")
				and not bot.whip_to_kill_target:HasModifier("modifier_necrolyte_reapers_scythe")
				and not bot.whip_to_kill_target:HasModifier("modifier_oracle_false_promise_timer")
			then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	if bot.whip_to_engage then
		if Fu.IsValidHero(nearbyEnemies[1]) and botLevel < 15 or hpRatio < 0.15 then
			if Fu.IsInRange(bot, nearbyEnemies[1], 350) then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	if bot.whip_to_retreat then
		if not Fu.IsRealInvisible(bot) or Fu.IsValidHero(nearbyEnemies[1]) and botLevel < 15 or hpRatio < 0.15 then
			if Fu.IsInRange(bot, nearbyEnemies[1], endWidth) then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	if bot.whip_to_push or bot.whip_to_defend or bot.whip_to_farm or bot.whip_to_miniboss then
		if hpRatio < 0.15 then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.ConsiderEscapeAct()
	if not Fu.CanCastAbility(escapeActAbility) then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castRange = Fu.GetProperCastRange(false, bot, escapeActAbility:GetCastRange())
	local leashRadius = escapeActAbility:GetSpecialValueFloat("leash_radius")
	local invisDuration = escapeActAbility:GetSpecialValueFloat("invis_duration")
	local nearbyAllies = bot:GetNearbyHeroes(1600, false, BOT_MODE_NONE)
	local nearbyEnemies = bot:GetNearbyHeroes(1600, true, BOT_MODE_NONE)
	for _, allyHero in pairs(nearbyAllies) do
		if
			Fu.IsValidHero(allyHero)
			and not Fu.IsRealInvisible(allyHero)
			and Fu.IsInRange(bot, allyHero, castRange + 300)
			and Fu.IsCore(allyHero)
			and not allyHero:IsIllusion()
			and not allyHero:HasModifier("modifier_necrolyte_reapers_scythe")
			and Fu.CanBeAttacked(allyHero)
		then
			if
				allyHero:HasModifier("modifier_legion_commander_duel")
				or allyHero:HasModifier("modifier_enigma_black_hole_pull")
				or allyHero:HasModifier("modifier_faceless_void_chronosphere_freeze")
			then
				return BOT_ACTION_DESIRE_HIGH, allyHero
			end
			local alliesNearAlly = allyHero:GetNearbyHeroes(900, false, BOT_MODE_NONE)
			local enemiesNearAlly = allyHero:GetNearbyHeroes(900, true, BOT_MODE_NONE)
			if
				Fu.IsValidHero(enemiesNearAlly[1])
				and not Fu.IsSuspiciousIllusion(enemiesNearAlly[1])
				and (enemiesNearAlly[1]:GetAttackTarget() == allyHero or Fu.IsChasingTarget(
					enemiesNearAlly[1],
					allyHero
				))
				and #enemiesNearAlly >= #alliesNearAlly
				and not allyHero:HasModifier("modifier_teleporting")
				and not Fu.IsInEtherealForm(allyHero)
				and Fu.GetHP(allyHero) < 0.5
			then
				return BOT_ACTION_DESIRE_HIGH, allyHero
			end
		end
	end
	if Fu.IsRoshan(botTarget) or Fu.IsTormentor(botTarget) then
		for _, allyHero in pairs(nearbyAllies) do
			if Fu.IsValidHero(allyHero) and not allyHero:IsIllusion() then
				if
					(Fu.IsDoingRoshan(allyHero) or Fu.IsDoingTormentor(allyHero))
					and Fu.IsInRange(allyHero, botTarget, 900)
				then
					if Fu.GetHP(allyHero) < 0.15 and not allyHero:HasModifier("modifier_teleporting") then
						return BOT_ACTION_DESIRE_HIGH, allyHero
					end
				end
				if
					Fu.GetHP(allyHero) < 0.3
					and not Fu.IsInEtherealForm(allyHero)
					and Fu.CanBeAttacked(allyHero)
					and not allyHero:IsIllusion()
					and not allyHero:HasModifier("modifier_teleporting")
					and not allyHero:HasModifier("modifier_abaddon_borrowed_time")
					and not allyHero:HasModifier("modifier_dazzle_shallow_grave")
					and not allyHero:HasModifier("modifier_templar_assassin_refraction_absorb")
					and not allyHero:HasModifier("modifier_obsidian_destroyer_astral_imprisonment_prison")
				then
					return BOT_ACTION_DESIRE_HIGH, allyHero
				end
			end
		end
	end
	if hpRatio < 0.25 and X.IsBeingAttacked(bot) and not Fu.IsRealInvisible(bot) then
		return BOT_ACTION_DESIRE_HIGH, bot
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function X.ConsiderImpalementArts()
	if not Fu.CanCastAbility(impalementArtsAbility) then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local castRange = Fu.GetProperCastRange(false, bot, impalementArtsAbility:GetCastRange())
	local daggerWidth = impalementArtsAbility:GetSpecialValueInt("dagger_width")
	local castPoint = impalementArtsAbility:GetCastPoint()
	local impactDamage = impalementArtsAbility:GetSpecialValueInt("damage_impact")
	local bleedHealthPct = impalementArtsAbility:GetSpecialValueFloat("bleed_health_pct") / 100
	local bleedDuration = impalementArtsAbility:GetSpecialValueInt("bleed_duration")
	local daggerSpeed = impalementArtsAbility:GetSpecialValueInt("dagger_speed")
	local abilityLevel = impalementArtsAbility:GetLevel()
	local nearbyAllies = bot:GetNearbyHeroes(1600, false, BOT_MODE_NONE)
	local nearbyEnemies = bot:GetNearbyHeroes(1600, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.IsInRange(bot, enemyHero, castRange)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and not enemyHero:HasModifier("modifier_ringmaster_impalement_bleed")
		then
			local travelTime = GetUnitToUnitDistance(bot, enemyHero) / daggerSpeed + castPoint
			local targetLocation = Fu.GetCorrectLoc(enemyHero, travelTime)
			if
				not X.IsUnitBetweenMeAndLocation(bot, enemyHero, targetLocation, daggerWidth)
				and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
				and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
				and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
			then
				if
					Fu.CanKillTarget(enemyHero, impactDamage, DAMAGE_TYPE_MAGICAL)
					or Fu.CanKillTarget(
						enemyHero,
						impactDamage + enemyHero:GetMaxHealth() * bleedHealthPct * bleedDuration,
						DAMAGE_TYPE_MAGICAL
					)
				then
					return BOT_ACTION_DESIRE_HIGH, targetLocation
				end
			end
		end
	end
	if isEngaging then
		if
			Fu.IsValidHero(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and not botTarget:IsInvulnerable()
			and not botTarget:HasModifier("modifier_ringmaster_impalement_bleed")
		then
			local travelTime = GetUnitToUnitDistance(bot, botTarget) / daggerSpeed + castPoint
			local targetLocation = Fu.GetCorrectLoc(botTarget, travelTime)
			local aoeLocation = bot:FindAoELocation(true, true, targetLocation, daggerWidth, daggerWidth, 0, 0)
			if aoeLocation.count > 1 then
				targetLocation = aoeLocation.targetloc
			end
			if not X.IsUnitBetweenMeAndLocation(bot, botTarget, targetLocation, daggerWidth) then
				return BOT_ACTION_DESIRE_HIGH, targetLocation
			end
		end
	end
	if isRetreating and not Fu.IsRealInvisible(bot) then
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.IsInRange(bot, enemyHero, 800)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and bot:WasRecentlyDamagedByHero(enemyHero, 3.0)
				and (hpRatio < 0.5 or Fu.IsChasingTarget(enemyHero, bot))
				and not enemyHero:HasModifier("modifier_ringmaster_impalement_bleed")
			then
				local aoeLocation =
					bot:FindAoELocation(true, true, enemyHero:GetLocation(), daggerWidth, daggerWidth, 0, 0)
				local targetLocation = enemyHero:GetLocation()
				if aoeLocation.count > 1 then
					targetLocation = aoeLocation.targetloc
				end
				if not X.IsUnitBetweenMeAndLocation(bot, enemyHero, targetLocation, daggerWidth) then
					return BOT_ACTION_DESIRE_HIGH, targetLocation
				end
			end
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if
			Fu.IsRoshan(botTarget)
			and Fu.CanBeAttacked(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and botTarget:GetHealth() > impactDamage + botTarget:GetMaxHealth() * bleedHealthPct * bleedDuration
			and not botTarget:HasModifier("modifier_ringmaster_impalement_bleed")
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	if abilityLevel >= 3 and DotaTime() > 12 * 60 and not Fu.IsRealInvisible(bot) then
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValidHero(enemyHero)
				and not Fu.IsInRange(bot, enemyHero, 900)
				and Fu.IsInRange(bot, enemyHero, castRange)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and not enemyHero:HasModifier("modifier_ringmaster_impalement_bleed")
			then
				local travelTime = GetUnitToUnitDistance(bot, enemyHero) / daggerSpeed + castPoint
				if
					not X.IsUnitBetweenMeAndLocation(
						bot,
						enemyHero,
						Fu.GetCorrectLoc(enemyHero, travelTime),
						daggerWidth
					)
				then
					return BOT_ACTION_DESIRE_HIGH, Fu.GetCorrectLoc(enemyHero, travelTime)
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.ConsiderSpotlight()
	if not Fu.CanCastAbility(spotlightAbility) then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local castRange = Fu.GetProperCastRange(false, bot, spotlightAbility:GetCastRange())
	local castPoint = spotlightAbility:GetCastPoint()
	local radius = spotlightAbility:GetSpecialValueInt("radius")
	local duration = spotlightAbility:GetSpecialValueInt("duration")
	local nearbyAllies = bot:GetNearbyHeroes(1600, false, BOT_MODE_NONE)
	local nearbyEnemies = bot:GetNearbyHeroes(1600, true, BOT_MODE_NONE)
	if Fu.IsInTeamFight(bot, 1200) then
		-- datafeed: the light makes ENEMIES miss and reveals them; this searched for a spot with 2+ allies.
		local aoeLocation = bot:FindAoELocation(true, true, bot:GetLocation(), castRange, radius, 0, 0)
		local enemiesInSpotlight = Fu.GetEnemiesNearLoc(aoeLocation.targetloc, radius)
		if #enemiesInSpotlight >= 2 then
			if DotaTime() >= (bot._spotlightLogAt or -999) then
				bot._spotlightLogAt = DotaTime() + 10
				pcall(
					print,
					string.format("[OHA-RINGMASTER] t=%.0f spotlight on %d enemies", DotaTime(), #enemiesInSpotlight)
				)
			end
			return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
		end
	end
	for _, allyHero in pairs(nearbyAllies) do
		if
			Fu.IsValidHero(allyHero)
			and not Fu.IsRealInvisible(allyHero)
			and Fu.IsInRange(bot, allyHero, castRange + 300)
			and not allyHero:IsIllusion()
			and Fu.CanBeAttacked(allyHero)
			and not allyHero:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			if
				allyHero:HasModifier("modifier_legion_commander_duel")
				or allyHero:HasModifier("modifier_enigma_black_hole_pull")
				or allyHero:HasModifier("modifier_faceless_void_chronosphere_freeze")
			then
				return BOT_ACTION_DESIRE_HIGH, allyHero:GetLocation()
			end
			local enemiesNearAlly = allyHero:GetNearbyHeroes(1200, true, BOT_MODE_NONE)
			if
				Fu.IsValidHero(enemiesNearAlly[1])
				and not Fu.IsSuspiciousIllusion(enemiesNearAlly[1])
				and not Fu.IsChasingTarget(enemiesNearAlly[1], allyHero)
				and enemiesNearAlly[1]:GetAttackTarget() == allyHero
				and not Fu.IsInEtherealForm(allyHero)
			then
				return BOT_ACTION_DESIRE_HIGH, allyHero:GetLocation()
			end
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if
			Fu.IsTormentor(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and Fu.GetHP(botTarget) > 0.5
			and isAttacking
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.ConsiderWheelOfWonder()
	if not Fu.CanCastAbility(wheelOfWonderAbility) then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local castRange = Fu.GetProperCastRange(false, bot, wheelOfWonderAbility:GetCastRange())
	local castPoint = wheelOfWonderAbility:GetCastPoint()
	local mesmerizeRadius = wheelOfWonderAbility:GetSpecialValueInt("mesmerize_radius")
	local projectileSpeed = wheelOfWonderAbility:GetSpecialValueInt("projectile_speed")
	if Fu.IsInTeamFight(bot, 1600) then
		local aoeLocation = bot:FindAoELocation(true, true, bot:GetLocation(), castRange, mesmerizeRadius, 0, 0)
		local enemiesInWheel = Fu.GetEnemiesNearLoc(aoeLocation.targetloc, mesmerizeRadius)
		-- datafeed: Wheel has a 700 minimum range (min_range). A spot much closer than that makes the wheel
		-- stop past the group, so skip spots nearer than min_range minus most of the mesmerize radius.
		local minRange = wheelOfWonderAbility:GetSpecialValueInt("min_range")
		if
			#enemiesInWheel >= 2
			and GetUnitToLocationDistance(bot, aoeLocation.targetloc) >= minRange - mesmerizeRadius * 0.6
		then
			return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.ConsiderFunhouseMirror()
	if not Fu.CanCastAbility(funhouseMirrorAbility) or Fu.IsRealInvisible(bot) then
		return BOT_ACTION_DESIRE_NONE
	end
	if Fu.IsStunProjectileIncoming(bot, 350) or Fu.IsUnitTargetProjectileIncoming(bot, 350) then
		return BOT_ACTION_DESIRE_HIGH
	end
	if
		not bot:HasModifier("modifier_sniper_assassinate")
		and not bot:IsMagicImmune()
		and Fu.IsWillBeCastUnitTargetSpell(bot, 300)
	then
		return BOT_ACTION_DESIRE_HIGH
	end
	if isEngaging then
		if Fu.IsValidHero(botTarget) and Fu.IsInRange(bot, botTarget, bot:GetAttackRange() + 300) then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsDoingRoshan(bot) or Fu.IsDoingTormentor(bot) then
		-- was Fu.IsTormentor(bot) (Ringmaster himself), never true
		if
			(Fu.IsRoshan(botTarget) or Fu.IsTormentor(botTarget))
			and Fu.IsInRange(bot, botTarget, 900)
			and isAttacking
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderStrongmanTonic()
	if not Fu.CanCastAbility(strongmanTonicAbility) then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castRange = Fu.GetProperCastRange(false, bot, strongmanTonicAbility:GetCastRange())
	local nearbyAllies = bot:GetNearbyHeroes(1600, false, BOT_MODE_NONE)
	local nearbyEnemies = bot:GetNearbyHeroes(1600, true, BOT_MODE_NONE)
	for _, allyHero in pairs(nearbyAllies) do
		if
			Fu.IsValidHero(allyHero)
			and Fu.IsInRange(bot, allyHero, castRange + 300)
			and not allyHero:IsIllusion()
			and not allyHero:HasModifier("modifier_necrolyte_reapers_scythe")
			and Fu.CanBeAttacked(allyHero)
		then
			if
				allyHero:HasModifier("modifier_legion_commander_duel")
				or allyHero:HasModifier("modifier_enigma_black_hole_pull")
				or allyHero:HasModifier("modifier_faceless_void_chronosphere_freeze")
			then
				return BOT_ACTION_DESIRE_HIGH, allyHero
			end
			local alliesNearAlly = allyHero:GetNearbyHeroes(1600, false, BOT_MODE_NONE)
			local enemiesNearAlly = allyHero:GetNearbyHeroes(1600, true, BOT_MODE_NONE)
			if
				Fu.IsValidHero(enemiesNearAlly[1])
				and Fu.IsRetreating(allyHero)
				and not Fu.IsSuspiciousIllusion(enemiesNearAlly[1])
				and Fu.IsChasingTarget(enemiesNearAlly[1], allyHero)
			then
				return BOT_ACTION_DESIRE_HIGH, allyHero
			end
		end
	end
	if Fu.IsRoshan(botTarget) or Fu.IsTormentor(botTarget) then
		for _, allyHero in pairs(nearbyAllies) do
			if Fu.IsValidHero(allyHero) and Fu.IsInRange(bot, allyHero, castRange) and not allyHero:IsIllusion() then
				if
					(Fu.IsDoingRoshan(allyHero) or Fu.IsDoingTormentor(allyHero))
					and Fu.IsInRange(allyHero, botTarget, 900)
				then
					if Fu.GetHP(allyHero) < 0.15 then
						return BOT_ACTION_DESIRE_HIGH, allyHero
					end
				end
				if
					Fu.GetHP(allyHero) < 0.3
					and not Fu.IsInEtherealForm(allyHero)
					and Fu.CanBeAttacked(allyHero)
					and not allyHero:IsIllusion()
					and not allyHero:HasModifier("modifier_abaddon_borrowed_time")
					and not allyHero:HasModifier("modifier_dazzle_shallow_grave")
					and not allyHero:HasModifier("modifier_templar_assassin_refraction_absorb")
					and not allyHero:HasModifier("modifier_obsidian_destroyer_astral_imprisonment_prison")
				then
					return BOT_ACTION_DESIRE_HIGH, allyHero
				end
			end
		end
	end
	if hpRatio < 0.5 and X.IsBeingAttacked(bot) and not Fu.IsRealInvisible(bot) then
		return BOT_ACTION_DESIRE_HIGH, bot
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function X.ConsiderWhoopeeCushion()
	if not Fu.CanCastAbility(whoopeeCushionAbility) then
		return BOT_ACTION_DESIRE_NONE
	end
	local leapDistance = whoopeeCushionAbility:GetSpecialValueInt("leap_distance")
	local fartCloudRadius = whoopeeCushionAbility:GetSpecialValueInt("fart_cloud_radius")
	local nearbyAllies = bot:GetNearbyHeroes(1600, false, BOT_MODE_NONE)
	local nearbyEnemies = bot:GetNearbyHeroes(1600, true, BOT_MODE_NONE)
	if isEngaging then
		if
			Fu.IsValidHero(botTarget)
			and Fu.IsInRange(bot, botTarget, leapDistance + fartCloudRadius)
			and not Fu.IsInRange(bot, botTarget, leapDistance)
			and Fu.CanBeAttacked(botTarget)
			and Fu.IsChasingTarget(bot, botTarget)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and #nearbyAllies >= #nearbyEnemies
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if isRetreating and not Fu.IsRealInvisible(bot) then
		if Fu.IsValidHero(nearbyEnemies[1]) and not Fu.IsSuspiciousIllusion(nearbyEnemies[1]) then
			if #nearbyEnemies > #nearbyAllies + 1 and bot:IsFacingLocation(Fu.GetTeamFountain(), 30) then
				return BOT_ACTION_DESIRE_HIGH
			end
			if
				Fu.IsInRange(bot, nearbyEnemies[1], fartCloudRadius)
				and Fu.IsChasingTarget(nearbyEnemies[1], bot)
				and bot:IsFacingLocation(Fu.GetTeamFountain(), 45)
			then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderUnicycle()
	if not Fu.CanCastAbility(unicycleAbility) then
		return BOT_ACTION_DESIRE_NONE
	end
	if isEngaging then
		if
			Fu.IsValidHero(botTarget)
			and Fu.IsInRange(bot, botTarget, 2200)
			and not Fu.IsInRange(bot, botTarget, 700)
			and (hpRatio > 0.7 or Fu.IsChasingTarget(bot, botTarget))
			and Fu.CanCastOnNonMagicImmune(botTarget)
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	local nearbyEnemies = bot:GetNearbyHeroes(1600, true, BOT_MODE_NONE)
	if isRetreating and not Fu.IsRealInvisible(bot) then
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.IsInRange(bot, enemyHero, 600)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and (hpRatio < 0.5 or Fu.IsChasingTarget(enemyHero, bot))
			then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
-- It checked Fu.IsValid(unit) instead of the attacker and never asked what the enemy was attacking, so any
-- visible enemy hero or tower made it true: Box on self below 25% HP and Tonic on self below 50% fired
-- anywhere on the map. Now the enemy must be attacking unit.
function X.IsBeingAttacked(unit)
	if not Fu.IsValid(unit) then
		return false
	end
	for _, enemyUnit in pairs(GetUnitList(UNIT_LIST_ENEMIES)) do
		if Fu.IsValid(enemyUnit) then
			local unitName = enemyUnit:GetUnitName()
			if
				(Fu.IsValidHero(enemyUnit) or Fu.IsValidBuilding(enemyUnit) or string.find(unitName, "warlock_golem"))
				and enemyUnit:GetAttackTarget() == unit
			then
				return true
			end
		end
	end
	return false
end
function X.IsUnitBetweenMeAndLocation(caster, target, location, width)
	local startLocation = caster:GetLocation()
	local endLocation = location
	for _, enemyUnit in pairs(GetUnitList(UNIT_LIST_ENEMIES)) do
		if
			enemyUnit ~= nil
			and enemyUnit:CanBeSeen()
			and GetUnitToUnitDistance(GetBot(), enemyUnit) <= 1600
			and not enemyUnit:IsBuilding()
			and not string.find(enemyUnit:GetUnitName(), "ward")
			and caster ~= enemyUnit
			and target ~= enemyUnit
		then
			local lineInfo = PointToLineDistance(startLocation, endLocation, enemyUnit:GetLocation())
			if lineInfo ~= nil and lineInfo.within and lineInfo.distance <= width then
				return true
			end
		end
	end
	return false
end
return X
