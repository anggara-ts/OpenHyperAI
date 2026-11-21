-- Dark Willow: skill build, item build, and ability use for this hero.
local X = {}
local bot = GetBot()
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local AbilityContext = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local Minion = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
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
local ShadowRealmRules = require(GetScriptDirectory() .. "/FuncLib/systems/shadow_realm_rules")
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
-- Shadow Realm hold (#48): runs inside the realm, even when the item think counts her as invulnerable
-- (bThinkWhileInvulnerable lets only this tick run then).
X["bThinkWhileInvulnerable"] = true
function X.SkillsComplement()
	local okRealm, realmOrder = pcall(X.ShadowRealmTick)
	if okRealm and realmOrder or bot:IsInvulnerable() then
		return
	end
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
	local shadowRealmWhy, shadowRealmTarget
	shadowRealmDesire, shadowRealmWhy, shadowRealmTarget = X.ConsiderShadowRealm()
	if shadowRealmDesire > 0 then
		X.StartShadowRealm(shadowRealmWhy, shadowRealmTarget)
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
function X.ConsiderBrambleMaze()
	if not brambleMazeAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local castRange = brambleMazeAbility:GetCastRange()
	local nearbyEnemies = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	botTarget = Fu.GetProperTarget(bot)
	for _, enemy in pairs(nearbyEnemies) do
		if
			Fu.IsValid(enemy)
			and (enemy:IsChanneling() or Fu.IsCastingUltimateAbility(enemy))
			and Fu.CanCastOnNonMagicImmune(enemy)
			and not Fu.IsSuspiciousIllusion(enemy)
		then
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
	if attackRangeBonus <= 0 then
		attackRangeBonus = 600
	end
	local attackRange = bot:GetAttackRange()
	local nearbyEnemies = Fu.GetNearbyHeroes(bot, attackRange + attackRangeBonus, true, BOT_MODE_NONE)
	botTarget = Fu.GetProperTarget(bot)
	if isGoingOnSomeone then
		-- Dodge: hurt in a fight against 2+ (the old rule, kept). The hit after it still ends the realm.
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
			return BOT_ACTION_DESIRE_HIGH, "dodge", botTarget
		end
		-- Attack (#48, maintainer game 067 4:50): go on the target within attack range + 600, hold the hit up to 3s
		-- for the full bonus (X.ShadowRealmTick). Only in the attack mode, the one whose attack order the hold
		-- replaces (override_generic/mode_attack_generic.lua); another mode's attack would end the realm at once.
		-- The bonus is magic damage: not on a magic-immune target. Mana for Cursed Crown stays.
		local crownCost = cursedCrownAbility:IsTrained() and cursedCrownAbility:GetManaCost() or 0
		if
			bot:GetActiveMode() == BOT_MODE_ATTACK
			and Fu.IsValidHero(botTarget)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and not botTarget:IsAttackImmune()
			and not botTarget:HasModifier("modifier_abaddon_borrowed_time")
			and not botTarget:HasModifier("modifier_dazzle_shallow_grave")
			and GetUnitToUnitDistance(bot, botTarget) <= attackRange + attackRangeBonus
			and not Fu.IsRealInvisible(bot)
			and bot:GetMana() - shadowRealmAbility:GetManaCost() >= crownCost
			and botTarget:GetHealth()
				> botTarget:GetActualIncomingDamage(bot:GetAttackDamage() * 2, DAMAGE_TYPE_PHYSICAL)
		then
			return BOT_ACTION_DESIRE_HIGH, "attack", botTarget
		end
	end
	if
		(isRetreating or isRetreating and hpRatio < 0.6 and bot:WasRecentlyDamagedByAnyHero(2))
		and not Fu.IsRealInvisible(bot)
		and nearbyEnemies ~= nil
		and #nearbyEnemies >= 1
	then
		if Fu.DidEnemyCastAbility() or hpRatio < 0.5 or Fu.IsStunProjectileIncoming(bot, 800) then
			return BOT_ACTION_DESIRE_HIGH, "retreat", nil
		end
		return BOT_ACTION_DESIRE_MODERATE, "retreat", nil
	end
	return BOT_ACTION_DESIRE_NONE
end
-- The realm she is in (bot._dwRealm): why (attack | dodge | retreat), the cast time, the target, her attack range
-- at the cast (GetAttackRange may already add the +600 inside the realm) and the bonus values from the ability.
function X.StartShadowRealm(why, target)
	local bonusRange = shadowRealmAbility:GetSpecialValueInt("attack_range_bonus")
	if bonusRange <= 0 then
		bonusRange = 600
	end
	local maxTime = shadowRealmAbility:GetSpecialValueFloat("max_damage_duration")
	if maxTime <= 0 then
		maxTime = ShadowRealmRules.MAX_DAMAGE_TIME
	end
	local duration = shadowRealmAbility:GetSpecialValueFloat("duration")
	if duration <= 0 then
		duration = ShadowRealmRules.DURATION
	end
	bot._dwRealm = {
		why = why or "retreat",
		at = DotaTime(),
		target = target,
		baseRange = bot:GetAttackRange(),
		bonusRange = bonusRange,
		maxDamage = shadowRealmAbility:GetSpecialValueInt("damage"),
		maxTime = maxTime,
		duration = duration,
		tp = "-",
	}
	pcall(
		print,
		string.format(
			"[OHA-DW] t=%.0f dark_willow shadow-realm-cast why=%s target=%s dist=%d hp=%.2f mode=%d",
			DotaTime(),
			tostring(why),
			target ~= nil and (string.gsub(target:GetUnitName(), "npc_dota_hero_", "")) or "-",
			target ~= nil and GetUnitToUnitDistance(bot, target) or -1,
			Fu.GetHP(bot),
			bot:GetActiveMode()
		)
	)
end
-- [OHA-DW] t= dark_willow shadow-realm why=attack|dodge|retreat held= release= tp= dist= mod= invuln=, one line
-- per realm when it ends. held: seconds from the cast to the release order (attack) or to the end.
function X.EndShadowRealm(realm, since)
	bot._dwRealm = nil
	local target = realm.target
	local dist = -1
	if target ~= nil and not target:IsNull() and target:IsAlive() and target:CanBeSeen() then
		dist = GetUnitToUnitDistance(bot, target)
	end
	pcall(
		print,
		string.format(
			"[OHA-DW] t=%.0f dark_willow shadow-realm why=%s held=%.2f release=%s tp=%s target=%s dist=%d mod=%s invuln=%s",
			DotaTime(),
			realm.why,
			realm.releasedAt or since,
			tostring(realm.released or "-"),
			tostring(realm.tp),
			target ~= nil and not target:IsNull() and (string.gsub(target:GetUnitName(), "npc_dota_hero_", "")) or "-",
			dist,
			realm.modSeen ~= nil and string.format("%.2f", realm.modSeen) or "no",
			tostring(realm.invuln == true)
		)
	)
end
-- Her TP: the TP slot (15) or Boots of Travel in the main slots, ready.
function X.TeleportItem()
	for _, name in ipairs({ "item_tpscroll", "item_travel_boots", "item_travel_boots_2" }) do
		local slot = bot:FindItemSlot(name)
		if slot == 15 or slot >= 0 and slot <= 5 then
			local item = bot:GetItemInSlot(slot)
			if item ~= nil and not item:IsNull() and item:IsFullyCastable() then
				return item
			end
		end
	end
	return nil
end
-- An escape realm: TP home at once, so the 3s channel ends inside the 5s untargetable time (#48, game 067 17:06:
-- realm, then a walk, a TP 4s later, dead after the realm ended). The generic TP rule waits out an enemy tower
-- within 888 (she was 320 from one); towers can't target her in the realm. HP under 0.45 and over 4900 from the
-- fountain, the limits of the TP rule's own retreat TP (ability_item_usage_generic.lua 撤退:2). Once per realm.
function X.ShadowRealmTeleport(realm, since, castDone)
	if realm.tp ~= "-" or not castDone then
		return false
	end
	local tp = X.TeleportItem()
	if tp == nil then
		realm.tp = "none"
	elseif not ShadowRealmRules.TpFits(since, realm.duration, ShadowRealmRules.TP_CHANNEL, 0.3) then
		realm.tp = "late"
	elseif Fu.GetHP(bot) >= 0.45 then
		realm.tp = "skip-hp"
	elseif bot:DistanceFromFountain() <= 4900 then
		realm.tp = "skip-near"
	else
		realm.tp = "now"
		realm.tpAt = since
		bot:Action_UseAbilityOnLocation(tp, Fu.GetTeamFountain())
		return true
	end
	return false
end
-- Every think while she is in a realm. Attack realm: keep within attack range + 600 of the target and hold the hit
-- until the bonus is full (ShadowRealmRules.HoldStep), then one attack. Retreat realm: the TP. Returns true when it
-- gave an order the spells below must not replace (the hit, the TP); hold moves return false so a spell can still go
-- out. Also called by the attack mode's Think (bot._attackHold), in place of its attack order.
function X.ShadowRealmTick()
	local realm = bot._dwRealm
	if realm == nil then
		return false
	end
	local since = DotaTime() - realm.at
	local inRealm = bot:HasModifier("modifier_dark_willow_shadow_realm_buff")
	if inRealm and realm.modSeen == nil then
		realm.modSeen = since
		realm.invuln = bot:IsInvulnerable()
	end
	-- The cast went out: the modifier is on, or the ability went on cooldown (in case the modifier name is wrong).
	local castDone = inRealm or shadowRealmAbility:GetCooldownTimeRemaining() > 0
	if since > 0.5 and not castDone then
		realm.released = realm.released or "no-cast"
		X.EndShadowRealm(realm, since)
		return false
	end
	if since > realm.duration + 0.2 or realm.modSeen ~= nil and not inRealm then
		X.EndShadowRealm(realm, since)
		return false
	end
	if bot:IsChanneling() or bot:IsCastingAbility() or Fu.CanNotUseAction(bot) then
		return false
	end
	if realm.why == "retreat" then
		return X.ShadowRealmTeleport(realm, since, castDone)
	end
	if realm.why ~= "attack" or realm.released ~= nil or not castDone then
		return false
	end
	local target = realm.target
	if not Fu.IsValidHero(target) or not target:CanBeSeen() then
		realm.released, realm.releasedAt = "target-gone", since
		return false
	end
	if bot:GetActiveMode() ~= BOT_MODE_ATTACK then
		realm.released, realm.releasedAt = "mode", since
		return false
	end
	local holdRange = realm.baseRange + realm.bonusRange
	local dist = GetUnitToUnitDistance(bot, target)
	local bonusNow = ShadowRealmRules.BonusDamage(realm.maxDamage, since, realm.maxTime)
	local hitNow = target:GetActualIncomingDamage(bonusNow, DAMAGE_TYPE_MAGICAL)
		+ target:GetActualIncomingDamage(bot:GetAttackDamage(), DAMAGE_TYPE_PHYSICAL)
	local killNow = target:GetHealth() <= hitNow
	local allyNeeds = false
	for _, ally in pairs(Fu.GetNearbyHeroes(target, 900, true, BOT_MODE_NONE) or {}) do
		if Fu.IsValidHero(ally) and ally ~= bot and not ally:IsIllusion() then
			-- An ally next to a nearly dead target finishes it anyway.
			if Fu.GetHP(target) < 0.15 and GetUnitToUnitDistance(ally, target) <= 700 then
				killNow = true
			end
			if
				Fu.GetHP(ally) < 0.35
				and (target:GetAttackTarget() == ally or ally:WasRecentlyDamagedByHero(target, 1.0))
			then
				allyNeeds = true
			end
		end
	end
	local action, why = ShadowRealmRules.HoldStep({
		since = since,
		maxTime = realm.maxTime,
		dist = dist,
		holdRange = holdRange,
		predictedDist = GetUnitToLocationDistance(bot, target:GetExtrapolatedLocation(0.5)),
		canFollow = bot:GetCurrentMovementSpeed() > target:GetCurrentMovementSpeed() + 10,
		killNow = killNow,
		allyNeeds = allyNeeds,
	})
	if action == "attack" then
		realm.released, realm.releasedAt = why, since
		bot:Action_AttackUnit(target, true)
		return true
	end
	-- A move order every think, so she never stands idle (an idle unit's own attack would end the realm early).
	local targetLocation = target:GetLocation()
	local point
	if action == "close" then
		point = target:GetExtrapolatedLocation(0.5)
	else
		-- Hold: circle the target at her distance, 25 degrees per order.
		local here = bot:GetLocation()
		local dx, dy = here.x - targetLocation.x, here.y - targetLocation.y
		local angle = math.rad(25)
		point = Vector(
			targetLocation.x + dx * math.cos(angle) - dy * math.sin(angle),
			targetLocation.y + dx * math.sin(angle) + dy * math.cos(angle),
			here.z
		)
	end
	bot:Action_MoveToLocation(point)
	return false
end
-- The attack mode asks this before its own attack order (override_generic/mode_attack_generic.lua): true when the
-- realm gave the order (the hold move or the hit), or the realm cast is still going out (an attack order would
-- replace it).
bot._attackHold = function()
	local realm = bot._dwRealm
	if realm == nil or realm.why ~= "attack" or realm.released ~= nil then
		return false
	end
	if X.ShadowRealmTick() then
		return true
	end
	realm = bot._dwRealm
	return realm ~= nil and realm.released == nil
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
	for _, enemy in pairs(enemiesInWideRange) do
		if
			Fu.IsValid(enemy)
			and (enemy:IsChanneling() or enemy:HasModifier("modifier_teleporting"))
			and Fu.CanCastOnNonMagicImmune(enemy)
			and Fu.CanCastOnTargetAdvanced(enemy)
		then
			local aoe = bot:FindAoELocation(true, true, bot:GetLocation(), castRange, 300, 0, 0)
			if aoe.count >= 2 then
				return BOT_ACTION_DESIRE_HIGH, aoe.targetloc
			end
			return BOT_ACTION_DESIRE_HIGH, enemy:GetLocation()
		end
	end
	local nearbyAllies = Fu.GetNearbyHeroes(bot, 1200, false, BOT_MODE_NONE)
	for _, ally in pairs(nearbyAllies) do
		if
			Fu.IsValidHero(ally) and Fu.IsRetreating(ally)
			or Fu.IsRetreating(ally)
				and Fu.GetHP(ally) < 0.4
				and Fu.IsCore(ally)
				and ally:WasRecentlyDamagedByAnyHero(2)
		then
			local aoe = bot:FindAoELocation(true, true, ally:GetLocation(), castRange, radius, 0, 0)
			if aoe.count >= 2 then
				return BOT_ACTION_DESIRE_HIGH, aoe.targetloc
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
return X
