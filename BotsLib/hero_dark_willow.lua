-- Dark Willow: skill build, item build, and ability use for this hero.
local X = {}
local bot = GetBot()
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local AbilityContext = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local Minion = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local InterruptRules = require(GetScriptDirectory() .. "/FuncLib/systems/interrupt_rules")
local sTalentList = Fu.Skill.GetTalentList(bot)
local sAbilityList = Fu.Skill.GetAbilityList(bot)
local sRole = Fu.Item.GetRoleItemsBuyList(bot)
local tTalentTreeList = { ["t25"] = { 0, 10 }, ["t20"] = { 0, 10 }, ["t15"] = { 0, 10 }, ["t10"] = { 10, 0 } }
local tAllAbilityBuildList = { { 1, 2, 2, 3, 2, 4, 2, 1, 1, 1, 4, 3, 3, 3, 4 } }
local nAbilityBuildList = Fu.Skill.GetRandomBuild(tAllAbilityBuildList)
local nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList)
local sRoleItemsBuyList = {}
-- Stratz 7.41f, week of 9 Nov 2026: pos 4, 68,649 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_4"] = {
	"item_tango",
	"item_blood_grenade",
	"item_double_branches",
	"item_magic_stick",
	"item_faerie_fire",
	"item_magic_wand",
	"item_tranquil_boots",
	"item_cyclone",
	"item_blink",
	"item_aghanims_shard",
	"item_essence_distiller",
	"item_moon_shard",
	"item_wind_waker",
	"item_sheepstick",
	"item_aeon_disk",
	"item_ultimate_scepter_2",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 5, 66,614 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_5"] = {
	"item_tango",
	"item_blood_grenade",
	"item_double_branches",
	"item_magic_stick",
	"item_faerie_fire",
	"item_magic_wand",
	"item_tranquil_boots",
	"item_cyclone",
	"item_blink",
	"item_aghanims_shard",
	"item_essence_distiller",
	"item_sheepstick",
	"item_moon_shard",
	"item_aeon_disk",
	"item_wind_waker",
	"item_ultimate_scepter_2",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 3, 1,096 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_3"] = {
	"item_tango",
	"item_double_branches",
	"item_circlet",
	"item_magic_stick",
	"item_null_talisman",
	"item_magic_wand",
	"item_power_treads",
	"item_blink",
	"item_ultimate_scepter",
	"item_moon_shard",
	"item_ultimate_scepter_2",
	"item_witch_blade",
	"item_force_staff",
	"item_mask_of_madness",
	"item_monkey_king_bar",
	"item_hurricane_pike",
	"item_aghanims_shard",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 1 has 718 matches, built from pos 2 (5,844) (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_1"] = {
	"item_tango",
	"item_double_branches",
	"item_faerie_fire",
	"item_circlet",
	"item_mantle",
	"item_null_talisman",
	"item_magic_wand",
	"item_power_treads",
	"item_blink",
	"item_ultimate_scepter",
	"item_witch_blade",
	"item_moon_shard",
	"item_black_king_bar",
	"item_ultimate_scepter_2",
	"item_hydras_breath",
	"item_bloodthorn",
	"item_devastator",
	"item_aghanims_shard",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 2, 5,844 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_2"] = {
	"item_tango",
	"item_double_branches",
	"item_faerie_fire",
	"item_circlet",
	"item_mantle",
	"item_null_talisman",
	"item_magic_wand",
	"item_power_treads",
	"item_blink",
	"item_ultimate_scepter",
	"item_witch_blade",
	"item_moon_shard",
	"item_black_king_bar",
	"item_ultimate_scepter_2",
	"item_hydras_breath",
	"item_bloodthorn",
	"item_devastator",
	"item_aghanims_shard",
}
X["sBuyList"] = sRoleItemsBuyList[sRole]
X["sSellList"] = { "item_ultimate_scepter", "item_magic_wand" }
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
local brambleMazeAbility =
	SafeAbility(bot:GetAbilityByName("dark_willow_bramble_maze"), "dark_willow_bramble_maze", "dark_willow")
local shadowRealmAbility =
	SafeAbility(bot:GetAbilityByName("dark_willow_shadow_realm"), "dark_willow_shadow_realm", "dark_willow")
local cursedCrownAbility =
	SafeAbility(bot:GetAbilityByName("dark_willow_cursed_crown"), "dark_willow_cursed_crown", "dark_willow")
local bedlamAbility = SafeAbility(bot:GetAbilityByName("dark_willow_bedlam"), "dark_willow_bedlam", "dark_willow")
local terrorizeAbility =
	SafeAbility(bot:GetAbilityByName("dark_willow_terrorize"), "dark_willow_terrorize", "dark_willow")
local brambleMazeDesire, brambleMazeLocation
local shadowRealmDesire
local cursedCrownDesire, cursedCrownTarget
local bedlamDesire
local terrorizeDesire, terrorizeLocation
local lastBedlamTime = 0
local lastTerrorizeTime = 0
local botTarget
local isGoingOnSomeone
local isRetreating
local hpRatio
local isInTeamFight
function X.SkillsComplement()
	local context = AbilityContext.Build(bot)
	isGoingOnSomeone = context.isEngaging
	isRetreating = context.isRetreating
	hpRatio = context.hp
	isInTeamFight = context.isTeamFight
	if Fu.CanNotUseAbility(bot) then
		return
	end
	brambleMazeDesire, brambleMazeLocation = X.ConsiderBrambleMaze()
	if brambleMazeDesire > 0 then
		bot:Action_UseAbilityOnLocation(brambleMazeAbility, brambleMazeLocation)
		return
	end
	-- Terrorize is considered before Bedlam: casting one puts the other on cooldown (shared levels
	-- and cooldown), and Bedlam fired on any enemy near Dark Willow in a fight, so the fear was
	-- almost never cast.
	terrorizeDesire, terrorizeLocation = X.ConsiderTerrorize()
	if terrorizeDesire > 0 then
		bot:Action_UseAbilityOnLocation(terrorizeAbility, terrorizeLocation)
		lastTerrorizeTime = DotaTime()
		return
	end
	bedlamDesire = X.ConsiderBedlam()
	if bedlamDesire > 0 then
		bot:Action_UseAbility(bedlamAbility)
		lastBedlamTime = DotaTime()
		return
	end
	shadowRealmDesire = X.ConsiderShadowRealm()
	if shadowRealmDesire > 0 then
		bot:Action_UseAbility(shadowRealmAbility)
		-- return: without it the Cursed Crown order below replaced Shadow Realm in the same frame.
		return
	end
	cursedCrownDesire, cursedCrownTarget = X.ConsiderCurseCrown()
	if cursedCrownDesire > 0 then
		bot:Action_UseAbilityOnEntity(cursedCrownAbility, cursedCrownTarget)
		return
	end
end
-- Interrupt probes (#48): after an interrupt cast, look at the target once the effect should have landed and log
-- whether the teleport/channel stopped. [OHA-DARK_WILLOW] interrupt-result spell= target= rooted= feared= tp= channel=
local interruptProbes = {}
function X.StartInterruptProbe(spell, target, delay)
	interruptProbes[spell] = { target = target, checkAt = DotaTime() + delay }
end
function X.CheckInterruptProbes()
	for spell, probe in pairs(interruptProbes) do
		if DotaTime() >= probe.checkAt then
			interruptProbes[spell] = nil
			local target = probe.target
			if Fu.IsValidHero(target) then
				pcall(
					print,
					string.format(
						"[OHA-DARK_WILLOW] t=%.0f interrupt-result spell=%s target=%s rooted=%s feared=%s tp=%s channel=%s",
						DotaTime(),
						spell,
						target:GetUnitName(),
						tostring(target:HasModifier("modifier_dark_willow_bramble_maze")),
						tostring(target:HasModifier("modifier_dark_willow_debuff_fear")),
						tostring(target:HasModifier("modifier_teleporting")),
						tostring(target:IsChanneling())
					)
				)
			end
		end
	end
end
-- Time left of an enemy's channel: the TP modifier's remaining time, else the channelled ability's channel time
-- counted from the first think this bot saw it (an upper bound if she saw it late). src: tp|channel|unknown.
local channelMemory = {}
function X.EnemyChannelLeft(enemy)
	if enemy:HasModifier("modifier_teleporting") then
		return Fu.GetModifierTime(enemy, "modifier_teleporting"), "tp"
	end
	local active = enemy:GetCurrentActiveAbility()
	if active == nil or active:IsNull() then
		return 0, "unknown"
	end
	local channelTime = active:GetChannelTime() or 0
	if channelTime <= 0 then
		return 0, "unknown"
	end
	return InterruptRules.TrackChannel(channelMemory, enemy:GetUnitName(), active:GetName(), channelTime, DotaTime()),
		"channel"
end
function X.ConsiderBrambleMaze()
	X.CheckInterruptProbes()
	if not brambleMazeAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local castRange = brambleMazeAbility:GetCastRange()
	local nearbyEnemies = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	botTarget = Fu.GetProperTarget(bot)
	-- Only on a teleport (#48): Bramble's root "does not interrupt channeling spells upon rooting" (7.42
	-- abilities_english, dark_willow_bramble_maze_Note0), so it was wasted on other channels and ultimate cast
	-- points; the TP scroll "can be prevented or canceled by Root abilities" (item_tpscroll_Note1, ROOT_DISABLES
	-- in items.txt). Whether a bramble latches onto a hero standing still in the maze is logged (interrupt-result).
	for _, enemy in pairs(nearbyEnemies) do
		if
			Fu.IsValidHero(enemy)
			and enemy:HasModifier("modifier_teleporting")
			and Fu.CanCastOnNonMagicImmune(enemy)
			and not Fu.IsSuspiciousIllusion(enemy)
		then
			if DotaTime() >= (bot._brambleLogAt or -999) then
				bot._brambleLogAt = DotaTime() + 3
				local left = Fu.GetModifierTime(enemy, "modifier_teleporting")
				-- Game data: cast point 0.3, brambles grow after initial_creation_delay 0.3, latch after 0.1.
				X.StartInterruptProbe("bramble", enemy, 1.0)
				pcall(
					print,
					string.format(
						"[OHA-DARK_WILLOW] t=%.0f bramble why=tp target=%s left=%.2f",
						DotaTime(),
						enemy:GetUnitName(),
						left
					)
				)
			end
			return BOT_ACTION_DESIRE_HIGH, enemy:GetLocation()
		end
	end
	if isGoingOnSomeone then
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and Fu.IsMoving(botTarget)
			and not Fu.IsDisabled(botTarget)
			and not Fu.IsSuspiciousIllusion(botTarget)
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	if
		isRetreating
		and Fu.IsValid(nearbyEnemies[1])
		and Fu.CanCastOnNonMagicImmune(nearbyEnemies[1])
		and not Fu.IsDisabled(nearbyEnemies[1])
		and not Fu.IsRealInvisible(bot)
		and not Fu.IsSuspiciousIllusion(nearbyEnemies[1])
	then
		return BOT_ACTION_DESIRE_HIGH, nearbyEnemies[1]:GetLocation()
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.ConsiderShadowRealm()
	if not shadowRealmAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
	end
	local attackRangeBonus = shadowRealmAbility:GetSpecialValueInt("attack_range_bonus")
	local attackRange = bot:GetAttackRange()
	local nearbyEnemies = Fu.GetNearbyHeroes(bot, attackRange + attackRangeBonus, true, BOT_MODE_NONE)
	botTarget = Fu.GetProperTarget(bot)
	if isGoingOnSomeone then
		if
			hpRatio < 0.5
			and Fu.IsValidHero(botTarget)
			and Fu.CanCastOnMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, bot:GetAttackRange())
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not botTarget:HasModifier("modifier_abaddon_borrowed_time")
			and not Fu.IsRealInvisible(bot)
			and nearbyEnemies ~= nil
			and #nearbyEnemies >= 2
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if
		(isRetreating or isRetreating and hpRatio < 0.6 and bot:WasRecentlyDamagedByAnyHero(2))
		and not Fu.IsRealInvisible(bot)
		and nearbyEnemies ~= nil
		and #nearbyEnemies >= 1
	then
		if Fu.DidEnemyCastAbility() or hpRatio < 0.5 or Fu.IsStunProjectileIncoming(bot, 800) then
			return BOT_ACTION_DESIRE_HIGH
		end
		return BOT_ACTION_DESIRE_MODERATE
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderCurseCrown()
	if not cursedCrownAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castRange = Fu.GetProperCastRange(false, bot, cursedCrownAbility:GetCastRange())
	local mpRatio = bot:GetMana() / bot:GetMaxMana()
	local enemiesInRange = Fu.GetNearbyHeroes(bot, castRange + 50, true, BOT_MODE_NONE)
	local enemiesInWideRange = Fu.GetNearbyHeroes(bot, castRange + 150, true, BOT_MODE_NONE)
	local weakestEnemy = Fu.GetWeakestUnit(enemiesInRange)
	local weakestWideEnemy = Fu.GetWeakestUnit(enemiesInWideRange)
	local nearbyEnemyTowers = bot:GetNearbyTowers(900, true)
	if isInTeamFight then
		local strongestEnemy = nil
		local maxDamage = 0
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, castRange + 100, true, BOT_MODE_NONE)
		for _, enemy in pairs(nearbyEnemies) do
			if
				Fu.IsValidHero(enemy)
				and Fu.CanCastOnNonMagicImmune(enemy)
				and Fu.CanCastOnTargetAdvanced(enemy)
				and not Fu.IsDisabled(enemy)
			then
				local estimatedDamage = enemy:GetEstimatedDamageToTarget(false, bot, 3.5, DAMAGE_TYPE_ALL)
				if estimatedDamage > maxDamage then
					maxDamage = estimatedDamage
					strongestEnemy = enemy
				end
			end
		end
		if strongestEnemy ~= nil then
			return BOT_ACTION_DESIRE_HIGH, strongestEnemy
		end
	end
	if isGoingOnSomeone then
		botTarget = Fu.GetProperTarget(bot)
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.CanCastOnTargetAdvanced(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and not Fu.IsDisabled(botTarget)
			and not Fu.IsSuspiciousIllusion(botTarget)
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end
	if isRetreating then
		for _, enemy in pairs(enemiesInRange) do
			if
				Fu.IsValidHero(enemy)
				and Fu.CanCastOnNonMagicImmune(enemy)
				and Fu.CanCastOnTargetAdvanced(enemy)
				and Fu.IsInRange(bot, enemy, castRange)
				and bot:WasRecentlyDamagedByHero(enemy, 3.5)
				and bot:IsFacingLocation(enemy:GetLocation(), 45)
				and not Fu.IsDisabled(enemy)
				and not Fu.IsSuspiciousIllusion(enemy)
			then
				return BOT_ACTION_DESIRE_HIGH, enemy
			end
		end
	end
	if bot:WasRecentlyDamagedByAnyHero(2) and enemiesInRange[1] ~= nil and #enemiesInRange >= 1 then
		for _, enemy in pairs(enemiesInRange) do
			if
				Fu.IsValidHero(enemy)
				and Fu.CanCastOnNonMagicImmune(enemy)
				and Fu.CanCastOnTargetAdvanced(enemy)
				and bot:IsFacingLocation(enemy:GetLocation(), 30)
				and not Fu.IsDisabled(enemy)
				and not Fu.IsSuspiciousIllusion(enemy)
			then
				return BOT_ACTION_DESIRE_HIGH, enemy
			end
		end
	end
	if Fu.IsLaning(bot) and #nearbyEnemyTowers == 0 or DotaTime() > 12 * 60 then
		if mpRatio > 0.7 then
			if Fu.IsValidHero(weakestEnemy) and not Fu.IsDisabled(weakestEnemy) then
				return BOT_ACTION_DESIRE_HIGH, weakestEnemy
			end
		end
		if mpRatio > 0.88 then
			local nearbyEnemyCreeps = bot:GetNearbyCreeps(1200, true)
			if
				Fu.IsValidHero(weakestWideEnemy)
				and hpRatio > 0.6
				and #nearbyEnemyTowers == 0
				and (#nearbyEnemyCreeps + #enemiesInWideRange <= 5 or DotaTime() > 12 * 60)
				and not Fu.IsDisabled(weakestWideEnemy)
			then
				return BOT_ACTION_DESIRE_HIGH, weakestWideEnemy
			end
		end
		if Fu.IsValidHero(weakestEnemy) and Fu.GetHP(weakestEnemy) < 0.4 then
			return BOT_ACTION_DESIRE_HIGH, weakestEnemy
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function X.ConsiderBedlam()
	if not bedlamAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	if terrorizeAbility:IsTrained() then
		local fearDuration = bedlamAbility:GetSpecialValueInt("destination_status_duration")
		if DotaTime() - lastTerrorizeTime <= fearDuration then
			return BOT_ACTION_DESIRE_NONE, nil
		end
	end
	-- Bedlam has no cast range: the wisp circles 200 around her and hits within 300 (datafeed
	-- roaming_radius, attack_radius). GetProperCastRange(0) gave attack range + 200, so it was cast
	-- on heroes the wisp could not reach.
	local castRange = bedlamAbility:GetSpecialValueInt("roaming_radius")
		+ bedlamAbility:GetSpecialValueInt("attack_radius")
	if castRange <= 0 then
		castRange = 500
	end
	botTarget = Fu.GetProperTarget(bot)
	local nearbyEnemies = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	if isInTeamFight then
		if #nearbyEnemies >= 1 then
			return BOT_ACTION_DESIRE_HIGH, bot
		end
	end
	if isGoingOnSomeone then
		if Fu.IsInRange(bot, botTarget, castRange) and Fu.IsValidTarget(botTarget) then
			return BOT_ACTION_DESIRE_HIGH, bot -- was the undefined global allyTarget; Bedlam is no-target
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function X.ConsiderTerrorize()
	if not terrorizeAbility:IsFullyCastable() or DotaTime() - lastBedlamTime <= 5 then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local castRange = Fu.GetProperCastRange(false, bot, terrorizeAbility:GetCastRange())
	local radius = terrorizeAbility:GetSpecialValueInt("destination_radius")
	local enemiesInWideRange = Fu.GetNearbyHeroes(bot, castRange + 150, true, BOT_MODE_NONE)
	if isInTeamFight then
		local teamFightLocation = Fu.GetTeamFightLocation(bot)
		local nearbyAllies = Fu.GetNearbyHeroes(bot, castRange, false, BOT_MODE_NONE)
		local disabledAllyCount = 0
		local arenaEnemyCount = 0
		local hasChronoAlly = false
		local chronoAlly = nil
		if teamFightLocation ~= nil then
			nearbyAllies = Fu.GetAlliesNearLoc(teamFightLocation, radius)
		end
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE)
		for _, enemy in pairs(nearbyEnemies) do
			if
				Fu.IsValidHero(enemy)
				and not Fu.IsSuspiciousIllusion(enemy)
				and enemy:HasModifier("modifier_mars_arena_of_blood")
			then
				arenaEnemyCount = arenaEnemyCount + 1
			end
		end
		if arenaEnemyCount >= 2 then
			local aoe = bot:FindAoELocation(true, true, bot:GetLocation(), castRange, radius, 0, 0)
			if aoe.count >= 2 then
				return BOT_ACTION_DESIRE_HIGH, aoe.targetloc
			end
		end
		for _, ally in pairs(nearbyAllies) do
			if Fu.IsValidHero(ally) and Fu.IsDisabled(ally) and not ally:IsIllusion() then
				disabledAllyCount = disabledAllyCount + 1
			end
			if
				Fu.IsValidHero(ally)
				and Fu.IsCore(ally)
				and ally:HasModifier("modifier_faceless_void_chronosphere_freeze")
			then
				local enemiesNearAlly = Fu.GetNearbyHeroes(ally, 400, true, BOT_MODE_NONE)
				if enemiesNearAlly ~= nil and #enemiesNearAlly >= 1 then
					hasChronoAlly = true
					chronoAlly = ally
					break
				end
			end
		end
		if chronoAlly ~= nil and hasChronoAlly then
			-- was ChronodAlly (an undefined global), a runtime error every time this case matched
			return BOT_ACTION_DESIRE_HIGH, chronoAlly:GetLocation()
		end
		if disabledAllyCount >= 2 then
			local aoe = bot:FindAoELocation(true, true, bot:GetLocation(), castRange, radius, 0, 0)
			if aoe.count >= 2 then
				return BOT_ACTION_DESIRE_HIGH, aoe.targetloc
			end
		end
		-- Plain team fight: fear 3+ enemies standing in one Terrorize area (1s cast point, so
		-- predict 1s ahead). Without this the fear only went out for disabled allies, Chrono or
		-- Arena, and Bedlam took the shared cooldown first.
		local aoe = bot:FindAoELocation(true, true, bot:GetLocation(), castRange, radius * 0.8, 1.0, 0)
		if aoe ~= nil and aoe.count ~= nil and aoe.count >= 3 then
			local realFeared = Fu.GetEnemiesNearLoc(aoe.targetloc, radius * 0.8)
			if realFeared ~= nil and #realFeared >= 3 then
				if DotaTime() >= (bot._terrorizeLogAt or -999) then
					bot._terrorizeLogAt = DotaTime() + 5
					pcall(
						print,
						string.format("[OHA-DARK_WILLOW] t=%.0f terrorize fight heroes=%d", DotaTime(), #realFeared)
					)
				end
				return BOT_ACTION_DESIRE_HIGH, aoe.targetloc
			end
		end
	end
	if isRetreating then
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
		if bot:WasRecentlyDamagedByAnyHero(2.0) and #nearbyEnemies >= 2 then
			local aoe = bot:FindAoELocation(true, true, bot:GetLocation(), castRange, radius, 0, 0)
			if aoe.count >= 2 then
				return BOT_ACTION_DESIRE_MODERATE, aoe.targetloc
			end
		end
	end
	-- A teleporting or channelling enemy (#48): only when the fear lands before the channel ends. Datafeed (hero
	-- 119): cast point 1.0, the wisp flies from her to the point at destination_travel_speed 2000, no other delay.
	-- TP scroll channel 3.0s (7.42 items.txt). The old branch also aimed at a 2-hero spot that need not hold
	-- the teleporter, and took enemies 150 past cast range.
	local castPoint = terrorizeAbility:GetCastPoint()
	local travelSpeed = terrorizeAbility:GetSpecialValueInt("destination_travel_speed")
	for _, enemy in pairs(enemiesInWideRange) do
		if
			Fu.IsValidHero(enemy)
			and not Fu.IsSuspiciousIllusion(enemy)
			and (enemy:IsChanneling() or enemy:HasModifier("modifier_teleporting"))
			and Fu.CanCastOnNonMagicImmune(enemy)
			and Fu.CanCastOnTargetAdvanced(enemy)
		then
			local location = enemy:GetLocation()
			local aoe = bot:FindAoELocation(true, true, bot:GetLocation(), castRange, radius * 0.8, 0, 0)
			if
				aoe ~= nil
				and aoe.count ~= nil
				and aoe.count >= 2
				and Fu.GetLocationToLocationDistance(aoe.targetloc, location) <= radius * 0.8
			then
				location = aoe.targetloc
			end
			local distance = GetUnitToLocationDistance(bot, location)
			if distance <= castRange then
				local left, src = X.EnemyChannelLeft(enemy)
				local arrive = InterruptRules.ArrivalTime(castPoint, distance, travelSpeed, 0)
				if InterruptRules.LandsBeforeChannelEnds(arrive, left) then
					X.LogTerrorize("interrupt", enemy, arrive, left, src)
					X.StartInterruptProbe("terrorize", enemy, arrive + 0.2)
					return BOT_ACTION_DESIRE_HIGH, location
				end
				X.LogTerrorize("too-late", enemy, arrive, left, src)
			end
		end
	end
	local nearbyAllies = Fu.GetNearbyHeroes(bot, 1200, false, BOT_MODE_NONE)
	for _, ally in pairs(nearbyAllies) do
		-- was "valid and retreating OR retreating and hurt and core and hit": the first half alone matched, so
		-- any retreating ally (even at full HP) drew the fear. Now a hurt core that is being hit (#48).
		if
			Fu.IsValidHero(ally)
			and not ally:IsIllusion()
			and Fu.IsRetreating(ally)
			and Fu.GetHP(ally) < 0.4
			and Fu.IsCore(ally)
			and ally:WasRecentlyDamagedByAnyHero(2)
		then
			local aoe = bot:FindAoELocation(true, true, ally:GetLocation(), castRange, radius, 0, 0)
			if aoe.count >= 2 and GetUnitToLocationDistance(bot, aoe.targetloc) <= castRange then
				X.LogTerrorize("save-ally", ally, 0, Fu.GetHP(ally), "ally")
				return BOT_ACTION_DESIRE_HIGH, aoe.targetloc
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
-- [OHA-DARK_WILLOW] terrorize why=interrupt ... / terrorize-skip why=too-late ... / terrorize why=save-ally ...,
-- each at most once per 3s. arrive: seconds until the fear lands; left: channel time left; margin = left - arrive.
local terrorizeLogAt = {}
function X.LogTerrorize(why, unit, arrive, left, src)
	if DotaTime() < (terrorizeLogAt[why] or -999) then
		return
	end
	terrorizeLogAt[why] = DotaTime() + 3
	if why == "save-ally" then
		pcall(
			print,
			string.format(
				"[OHA-DARK_WILLOW] t=%.0f terrorize why=save-ally ally=%s hp=%.2f",
				DotaTime(),
				unit:GetUnitName(),
				left
			)
		)
		return
	end
	local what = "terrorize"
	if why == "too-late" then
		what = "terrorize-skip"
	end
	pcall(
		print,
		string.format(
			"[OHA-DARK_WILLOW] t=%.0f %s why=%s target=%s arrive=%.2f left=%.2f margin=%.2f src=%s",
			DotaTime(),
			what,
			why,
			unit:GetUnitName(),
			arrive,
			left,
			left - arrive,
			src
		)
	)
end
return X
