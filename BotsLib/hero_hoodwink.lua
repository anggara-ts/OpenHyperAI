-- Hoodwink: skill build, item build, and ability use for this hero.
local X = {}
local bot = GetBot()
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local AbilityContext = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local Minion = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local sTalentList = Fu.Skill.GetTalentList(bot)
local sAbilityList = Fu.Skill.GetAbilityList(bot)
local sRole = Fu.Item.GetRoleItemsBuyList(bot)
local tTalentTreeList = { ["t25"] = { 0, 10 }, ["t20"] = { 10, 0 }, ["t15"] = { 10, 0 }, ["t10"] = { 10, 0 } }
-- Bushwhack first, then Acorn Shot, Scurry last; Sharpshooter at 6/12/18 (it took rank 2 at 13).
local tAllAbilityBuildList = { { 2, 1, 2, 3, 2, 6, 2, 1, 1, 1, 6, 3, 3, 3, 6 } }
local nAbilityBuildList = Fu.Skill.GetRandomBuild(tAllAbilityBuildList)
local nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList)
local sRoleItemsBuyList = {}
sRoleItemsBuyList["pos_4"] = {
	"item_enchanted_mango",
	"item_blood_grenade",
	"item_priest_outfit",
	"item_mekansm",
	"item_glimmer_cape",
	"item_aghanims_shard",
	"item_maelstrom",
	"item_guardian_greaves",
	"item_gungir",
	"item_shivas_guard",
	"item_ultimate_scepter",
	"item_ultimate_scepter_2",
	"item_sheepstick",
	"item_moon_shard",
	"item_octarine_core",
}
sRoleItemsBuyList["pos_5"] = {
	"item_blood_grenade",
	"item_mage_outfit",
	"item_ancient_janggo",
	"item_glimmer_cape",
	"item_boots_of_bearing",
	"item_aghanims_shard",
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
	"item_mage_slayer",
	"item_maelstrom",
	"item_force_staff",
	"item_mjollnir",
	"item_boots_of_bearing",
	"item_ultimate_scepter",
	"item_sheepstick",
	"item_hurricane_pike",
	"item_aghanims_shard",
	"item_ultimate_scepter_2",
	"item_greater_crit",
	"item_moon_shard",
}
sRoleItemsBuyList["pos_1"] = {
	"item_ranged_carry_outfit",
	"item_dragon_lance",
	"item_rod_of_atos",
	"item_maelstrom",
	"item_black_king_bar",
	"item_mjollnir",
	"item_travel_boots",
	"item_orchid",
	"item_bloodthorn",
	"item_force_staff",
	"item_hurricane_pike",
	"item_ultimate_scepter",
	"item_moon_shard",
	"item_travel_boots_2",
	"item_ultimate_scepter_2",
	"item_butterfly",
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
function X.MinionThink(hMinionUnit)
	Minion.MinionThink(hMinionUnit)
end
local acornShotAbility = SafeAbility(bot:GetAbilityByName("hoodwink_acorn_shot"), "hoodwink_acorn_shot", "hoodwink")
local bushwhackAbility = SafeAbility(bot:GetAbilityByName("hoodwink_bushwhack"), "hoodwink_bushwhack", "hoodwink")
local scurryAbility = SafeAbility(bot:GetAbilityByName("hoodwink_scurry"), "hoodwink_scurry", "hoodwink")
local huntersBoomerangAbility =
	SafeAbility(bot:GetAbilityByName("hoodwink_hunters_boomerang"), "hoodwink_hunters_boomerang", "hoodwink")
local decoyAbility = SafeAbility(bot:GetAbilityByName("hoodwink_decoy"), "hoodwink_decoy", "hoodwink")
local sharpshooterAbility =
	SafeAbility(bot:GetAbilityByName("hoodwink_sharpshooter"), "hoodwink_sharpshooter", "hoodwink")
local sharpshooterReleaseAbility =
	SafeAbility(bot:GetAbilityByName("hoodwink_sharpshooter_release"), "hoodwink_sharpshooter_release", "hoodwink")
-- Game data, 7.42 (scripts/npc/heroes/npc_dota_hero_hoodwink.txt) and the Valve datafeed (hero_id=123):
--   Sharpshooter: damage and slow are full after max_charge_time (3s), the bolt fires by itself at misfire_time
--   (5s); she turns turn_rate (60) degrees a second while charging; arrow_range 3000, arrow_width 125.
--   Acorn Shot: on a unit the acorn bounces between enemies within bounce_range (525); on the ground it plants a
--   tree first ("The planted tree lasts for 20 seconds").
local ACORN_TREE_DURATION = 20
-- A tree planted for the combo is thrown at with Bushwhack on that target for this long; after it, only on the
-- attack target.
local ACORN_COMBO_WINDOW = 3
local sharpshooterWindup = nil -- { startedAt, target, startFacing, reaims, released }
local acornTree = nil -- { location, plantedAt, target }
local lastAcornLogAt = -100
local acornShotDesire, acornShotLocation, acornShotTarget, acornShotWhy
local bushwhackDesire, bushwhackLocation
local scurryDesire
local huntersBoomerangDesire, huntersBoomerangTarget
local decoyDesire
local sharpshooterDesire, sharpshooterLocation, sharpshooterTarget
local botTarget
local isGoingOnSomeone
local isRetreating
local hpRatio
function X.SkillsComplement()
	local context = AbilityContext.Build(bot)
	isGoingOnSomeone = context.isEngaging
	isRetreating = context.isRetreating
	hpRatio = context.hp
	-- Charging Sharpshooter: aim and release come before the busy check (it may count the windup as a cast),
	-- and nothing else is cast meanwhile.
	if X.ThinkSharpshooterWindup() then
		return
	end
	if Fu.CanNotUseAbility(bot) then
		return
	end
	acornShotDesire, acornShotLocation, acornShotTarget, acornShotWhy = X.ConsiderAcornShot()
	if acornShotDesire > 0 then
		X.CastAcornShot(acornShotLocation, acornShotTarget, acornShotWhy)
		return
	end
	bushwhackDesire, bushwhackLocation = X.ConsiderBushwhack()
	if bushwhackDesire > 0 then
		bot:Action_UseAbilityOnLocation(bushwhackAbility, bushwhackLocation)
		return
	end
	scurryDesire = X.ConsiderScurry()
	if scurryDesire > 0 then
		bot:Action_UseAbility(scurryAbility)
		return
	end
	huntersBoomerangDesire, huntersBoomerangTarget = X.ConsiderHuntersBoomerang()
	if huntersBoomerangDesire > 0 then
		bot:Action_UseAbilityOnEntity(huntersBoomerangAbility, huntersBoomerangTarget)
		return
	end
	decoyDesire = X.ConsiderDecoy()
	if decoyDesire > 0 then
		bot:Action_UseAbility(decoyAbility)
		return
	end
	sharpshooterDesire, sharpshooterLocation, sharpshooterTarget = X.ConsiderSharpshooter()
	if sharpshooterDesire > 0 then
		bot._sharpshooterTarget = sharpshooterTarget
		bot:Action_UseAbilityOnLocation(sharpshooterAbility, sharpshooterLocation)
		return
	end
end
function X.ConsiderAcornShot()
	if not acornShotAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castRange = Fu.GetProperCastRange(false, bot, acornShotAbility:GetCastRange())
	local castPoint = acornShotAbility:GetCastPoint()
	local bounceRange = acornShotAbility:GetSpecialValueInt("bounce_range")
	-- datafeed: an acorn hit is base_damage_pct (80%) of the attack plus acorn_shot_damage
	-- (45-180). It was bonus x attack x 0.75 (thousands), so the "kill" check passed on every
	-- hero in range and Acorn Shot was fired on cooldown at anyone, at any mana.
	local damage = bot:GetAttackDamage() * acornShotAbility:GetSpecialValueInt("base_damage_pct") / 100
		+ acornShotAbility:GetSpecialValueInt("acorn_shot_damage")
	local projectileSpeed = acornShotAbility:GetSpecialValueInt("projectile_speed")
	local abilityLevel = acornShotAbility:GetLevel()
	botTarget = Fu.GetProperTarget(bot)
	local nearbyEnemies = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanBeAttacked(enemyHero)
			and Fu.CanKillTarget(enemyHero, damage, DAMAGE_TYPE_PHYSICAL)
			and not Fu.IsSuspiciousIllusion(enemyHero)
			and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
			and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
			and not enemyHero:HasModifier("modifier_templar_assassin_refraction_absorb")
		then
			local delay = GetUnitToUnitDistance(bot, enemyHero) / projectileSpeed + castPoint
			return BOT_ACTION_DESIRE_HIGH, enemyHero:GetExtrapolatedLocation(delay), enemyHero, "kill"
		end
	end
	local nearbyAllies = Fu.GetNearbyHeroes(bot, castRange, false, BOT_MODE_NONE)
	for _, allyHero in pairs(nearbyAllies) do
		local allyNearbyEnemies = Fu.GetNearbyHeroes(allyHero, castRange, true, BOT_MODE_NONE)
		if
			Fu.IsValidHero(allyHero)
			and (Fu.IsRetreating(allyHero) and Fu.GetHP(allyHero) < 0.75 and allyHero:WasRecentlyDamagedByAnyHero(2))
			and not allyHero:IsIllusion()
		then
			if
				allyNearbyEnemies ~= nil
				and #allyNearbyEnemies >= 1
				and Fu.IsValidHero(allyNearbyEnemies[1])
				and Fu.IsInRange(bot, allyNearbyEnemies[1], castRange)
				and not Fu.IsSuspiciousIllusion(allyNearbyEnemies[1])
				and not Fu.IsDisabled(allyNearbyEnemies[1])
			then
				local delay = GetUnitToUnitDistance(bot, allyNearbyEnemies[1]) / projectileSpeed + castPoint
				return BOT_ACTION_DESIRE_HIGH,
					allyNearbyEnemies[1]:GetExtrapolatedLocation(delay),
					allyNearbyEnemies[1],
					"save-ally"
			end
		end
	end
	if isGoingOnSomeone then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, castRange + 100, false, BOT_MODE_NONE)
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and not Fu.IsDisabled(botTarget)
			and nearbyAllies ~= nil
			and nearbyEnemies ~= nil
			and #nearbyAllies >= #nearbyEnemies
		then
			local delay = GetUnitToUnitDistance(bot, botTarget) / projectileSpeed + castPoint
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetExtrapolatedLocation(delay), botTarget, "engage"
		end
	end
	if isRetreating then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, castRange + 100, false, BOT_MODE_NONE)
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
		if
			nearbyAllies ~= nil
			and nearbyEnemies
			and (#nearbyEnemies > #nearbyAllies or hpRatio < 0.65 and bot:WasRecentlyDamagedByAnyHero(2.5))
			and Fu.IsValidHero(nearbyEnemies[1])
			and not Fu.IsSuspiciousIllusion(nearbyEnemies[1])
			and not Fu.IsDisabled(nearbyEnemies[1])
		then
			return BOT_ACTION_DESIRE_HIGH, nearbyEnemies[1]:GetLocation(), nearbyEnemies[1], "retreat"
		end
	end
	if
		(Fu.IsPushing(bot) or Fu.IsDefending(bot))
		and (Fu.HasItem(bot, "item_maelstrom") or Fu.HasItem(bot, "item_mjollnir"))
		and abilityLevel >= 3
		and not Fu.IsThereNonSelfCoreNearby(600)
	then
		local nearbyLaneCreeps = bot:GetNearbyLaneCreeps(castRange, true)
		local aoe = bot:FindAoELocation(true, false, bot:GetLocation(), castRange, bounceRange, castPoint, 0)
		if nearbyLaneCreeps ~= nil and #nearbyLaneCreeps >= 4 and aoe.count >= 4 then
			return BOT_ACTION_DESIRE_HIGH, aoe.targetloc, nil, "wave"
		end
	end
	-- Alt-cast off (it was switched on here): alt-cast forces the tree, and CastAcornShot picks tree or bounce
	-- by the order it gives.
	if acornShotAbility:GetAutoCastState() then
		acornShotAbility:ToggleAutoCast()
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
-- Acorn Shot, by the goal. "tree": the acorn goes on the ground by the target and plants a tree for Bushwhack.
-- "bounce": it goes on the unit and bounces between the enemies around it.
function X.AcornShotMode(why, bushwhackReady, manaForBoth, targetCanBeTrapped, treeNearTarget)
	if why == "wave" then
		return "tree"
	end
	if why ~= "kill" and bushwhackReady and manaForBoth and targetCanBeTrapped and not treeNearTarget then
		return "tree"
	end
	return "bounce"
end
-- Where Bushwhack lands so that the enemy and the tree are both inside the net: halfway between them, or nil
-- when they are too far apart for one net (25 less than the radius on each side).
function X.BushwhackCenterForTree(enemyLocation, treeLocation, radius)
	local gap = Fu.GetLocationToLocationDistance(enemyLocation, treeLocation)
	if gap > 2 * (radius - 25) then
		return nil
	end
	return (enemyLocation + treeLocation) / 2
end
function X.CastAcornShot(location, target, why)
	local mode
	local nearCount = 0
	if target == nil then
		mode = "tree"
	else
		local trapRadius = bushwhackAbility:GetSpecialValueInt("trap_radius")
		local trees = target:GetNearbyTrees(trapRadius - 25)
		mode = X.AcornShotMode(
			why,
			bushwhackAbility:IsTrained() and bushwhackAbility:GetCooldownTimeRemaining() <= 0.5,
			bot:GetMana() >= acornShotAbility:GetManaCost() + bushwhackAbility:GetManaCost(),
			Fu.CanCastOnNonMagicImmune(target),
			trees ~= nil and #trees > 0
		)
		local bounceRange = acornShotAbility:GetSpecialValueInt("bounce_range")
		local heroesNear = Fu.GetEnemiesNearLoc(target:GetLocation(), bounceRange)
		nearCount = math.max(0, (heroesNear and #heroesNear or 0) - 1)
		for _, creep in pairs(bot:GetNearbyCreeps(1600, true) or {}) do
			if Fu.IsValid(creep) and GetUnitToUnitDistance(creep, target) <= bounceRange then
				nearCount = nearCount + 1
			end
		end
	end
	if DotaTime() - lastAcornLogAt >= 3 then
		lastAcornLogAt = DotaTime()
		print(
			string.format(
				"[OHA-HOODWINK] t=%.0f hoodwink acorn mode=%s why=%s target=%s near=%d",
				DotaTime(),
				mode,
				tostring(why),
				target ~= nil and (string.gsub(target:GetUnitName(), "npc_dota_hero_", "")) or "ground",
				nearCount
			)
		)
	end
	if mode == "bounce" then
		bot:Action_UseAbilityOnEntity(acornShotAbility, target)
		return
	end
	if target ~= nil then
		acornTree = { location = location, plantedAt = DotaTime(), target = target }
	end
	bot:Action_UseAbilityOnLocation(acornShotAbility, location)
end
-- Bushwhack on the tree her own acorn planted. GetNearbyTrees may not list a planted tree (apiTrees in the log
-- tells), so the spot is remembered: the acorn's target for ACORN_COMBO_WINDOW seconds, then the attack target.
function X.ConsiderBushwhackAtAcornTree(castRange, radius, castPoint, projectileSpeed)
	if acornTree == nil then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local age = DotaTime() - acornTree.plantedAt
	-- The acorn never left (order replaced, stun): it would be on cooldown by now.
	if age > ACORN_TREE_DURATION or age > 0.6 and acornShotAbility:IsCooldownReady() then
		acornTree = nil
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local enemyHero = acornTree.target
	if age > ACORN_COMBO_WINDOW then
		enemyHero = isGoingOnSomeone and botTarget or nil
	end
	if
		not Fu.IsValidHero(enemyHero)
		or not Fu.CanCastOnNonMagicImmune(enemyHero)
		or not Fu.IsInRange(bot, enemyHero, castRange)
		or Fu.IsSuspiciousIllusion(enemyHero)
		or Fu.IsDisabled(enemyHero)
	then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local delay = GetUnitToUnitDistance(bot, enemyHero) / projectileSpeed + castPoint
	local center = X.BushwhackCenterForTree(enemyHero:GetExtrapolatedLocation(delay), acornTree.location, radius)
	if center == nil then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local apiTrees = enemyHero:GetNearbyTrees(radius)
	print(
		string.format(
			"[OHA-HOODWINK] t=%.0f hoodwink bushwhack why=acorn-tree target=%s treeDist=%d treeAge=%.1f apiTrees=%d",
			DotaTime(),
			(string.gsub(enemyHero:GetUnitName(), "npc_dota_hero_", "")),
			math.floor(GetUnitToLocationDistance(enemyHero, acornTree.location)),
			age,
			apiTrees and #apiTrees or 0
		)
	)
	-- One net per tree: a miss is not thrown again.
	acornTree = nil
	return BOT_ACTION_DESIRE_HIGH, center
end
function X.ConsiderBushwhack()
	if not bushwhackAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local castRange = Fu.GetProperCastRange(false, bot, bushwhackAbility:GetCastRange())
	local castPoint = bushwhackAbility:GetCastPoint()
	local damage = bushwhackAbility:GetSpecialValueInt("total_damage")
	local radius = bushwhackAbility:GetSpecialValueInt("trap_radius")
	local projectileSpeed = bushwhackAbility:GetSpecialValueInt("projectile_speed")
	botTarget = Fu.GetProperTarget(bot)
	local acornTreeDesire, acornTreeLocation =
		X.ConsiderBushwhackAtAcornTree(castRange, radius, castPoint, projectileSpeed)
	if acornTreeDesire > 0 then
		return acornTreeDesire, acornTreeLocation
	end
	local nearbyEnemies = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and not Fu.IsSuspiciousIllusion(enemyHero)
		then
			local nearbyTrees = enemyHero:GetNearbyTrees(radius - 25)
			if nearbyTrees ~= nil and #nearbyTrees > 0 then
				if enemyHero:IsChanneling() or Fu.IsCastingUltimateAbility(enemyHero) then
					return BOT_ACTION_DESIRE_HIGH, enemyHero:GetLocation()
				end
				if
					Fu.CanKillTarget(enemyHero, damage, DAMAGE_TYPE_MAGICAL)
					and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
					and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
					and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
					and not enemyHero:HasModifier("modifier_templar_assassin_refraction_absorb")
				then
					local delay = GetUnitToUnitDistance(bot, enemyHero) / projectileSpeed + castPoint
					return BOT_ACTION_DESIRE_HIGH, enemyHero:GetExtrapolatedLocation(delay)
				end
			end
		end
	end
	local nearbyAllies = Fu.GetNearbyHeroes(bot, castRange, false, BOT_MODE_NONE)
	for _, allyHero in pairs(nearbyAllies) do
		local allyNearbyEnemies = Fu.GetNearbyHeroes(allyHero, castRange, true, BOT_MODE_NONE)
		if
			Fu.IsValidHero(allyHero)
			and (Fu.IsRetreating(allyHero) and allyHero:WasRecentlyDamagedByAnyHero(2.5))
			and not allyHero:IsIllusion()
		then
			if
				allyNearbyEnemies ~= nil
				and #allyNearbyEnemies >= 1
				and Fu.IsValidHero(allyNearbyEnemies[1])
				and Fu.IsInRange(bot, allyNearbyEnemies[1], castRange)
				and not Fu.IsSuspiciousIllusion(allyNearbyEnemies[1])
				and not Fu.IsDisabled(allyNearbyEnemies[1])
			then
				local nearbyTrees = allyNearbyEnemies[1]:GetNearbyTrees(radius - 25)
				if nearbyTrees ~= nil and #nearbyTrees > 0 then
					local delay = GetUnitToUnitDistance(bot, allyNearbyEnemies[1]) / projectileSpeed + castPoint
					return BOT_ACTION_DESIRE_HIGH, allyNearbyEnemies[1]:GetExtrapolatedLocation(delay)
				end
			end
		end
	end
	if Fu.IsInTeamFight(bot, 1200) then
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
		local aoe = bot:FindAoELocation(true, true, bot:GetLocation(), castRange, radius, castPoint, 0)
		if aoe.count >= 2 then
			for _, enemyHero in pairs(nearbyEnemies) do
				if
					Fu.IsValidHero(enemyHero)
					and Fu.CanCastOnNonMagicImmune(enemyHero)
					and not Fu.IsSuspiciousIllusion(enemyHero)
					and not Fu.IsDisabled(enemyHero)
					and not enemyHero:HasModifier("modifier_faceless_void_chronosphere_freeze")
					and GetUnitToLocationDistance(enemyHero, aoe.targetloc) <= radius
				then
					local nearbyTrees = enemyHero:GetNearbyTrees(radius - 25)
					if nearbyTrees ~= nil and #nearbyTrees > 0 then
						local delay = GetUnitToUnitDistance(bot, enemyHero) / projectileSpeed + castPoint
						return BOT_ACTION_DESIRE_HIGH, enemyHero:GetExtrapolatedLocation(delay)
					end
				end
			end
		end
	end
	if isGoingOnSomeone then
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not Fu.IsDisabled(botTarget)
		then
			local nearbyTrees = botTarget:GetNearbyTrees(radius - 25)
			if nearbyTrees ~= nil and #nearbyTrees > 0 then
				local delay = GetUnitToUnitDistance(bot, botTarget) / projectileSpeed + castPoint
				return BOT_ACTION_DESIRE_HIGH, botTarget:GetExtrapolatedLocation(delay)
			end
		end
	end
	if isRetreating then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, castRange + 100, false, BOT_MODE_NONE)
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
		if
			nearbyAllies ~= nil
			and nearbyEnemies
			and (#nearbyEnemies > #nearbyAllies or hpRatio < 0.65 and bot:WasRecentlyDamagedByAnyHero(2.5))
			and Fu.IsValidHero(nearbyEnemies[1])
			and Fu.CanCastOnNonMagicImmune(nearbyEnemies[1])
			and not Fu.IsSuspiciousIllusion(nearbyEnemies[1])
			and not Fu.IsDisabled(nearbyEnemies[1])
		then
			local nearbyTrees = nearbyEnemies[1]:GetNearbyTrees(radius - 25)
			if nearbyTrees ~= nil and #nearbyTrees > 0 then
				return BOT_ACTION_DESIRE_HIGH, nearbyEnemies[1]:GetLocation()
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.ConsiderScurry()
	if
		not scurryAbility:IsFullyCastable()
		or bot:HasModifier("modifier_hoodwink_scurry_active")
		or Fu.IsRealInvisible(bot)
	then
		return BOT_ACTION_DESIRE_NONE
	end
	if isRetreating then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, 800, false, BOT_MODE_NONE)
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, 600, true, BOT_MODE_NONE)
		local escapeLocation = Fu.GetEscapeLoc()
		if bot:IsFacingLocation(escapeLocation, 30) then
			if
				nearbyAllies ~= nil
				and nearbyEnemies
				and (#nearbyEnemies > #nearbyAllies or hpRatio < 0.55 and bot:WasRecentlyDamagedByAnyHero(2))
				and Fu.IsValidHero(nearbyEnemies[1])
				and not Fu.IsSuspiciousIllusion(nearbyEnemies[1])
				and not Fu.IsDisabled(nearbyEnemies[1])
			then
				return BOT_ACTION_DESIRE_HIGH
			end
			if hpRatio < 0.55 and bot:WasRecentlyDamagedByTower(2.5) then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderSharpshooter()
	if not sharpshooterAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local castRange = 1600
	local attackRange = bot:GetAttackRange()
	local arrowSpeed = sharpshooterAbility:GetSpecialValueInt("arrow_speed")
	botTarget = Fu.GetProperTarget(bot)
	if isGoingOnSomeone then
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and not Fu.IsInRange(bot, botTarget, attackRange)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not botTarget:HasModifier("modifier_dazzle_shallow_grave")
			and not botTarget:HasModifier("modifier_templar_assassin_refraction_absorb")
		then
			local delay = GetUnitToUnitDistance(bot, botTarget) / arrowSpeed
			local directionStability = botTarget:GetMovementDirectionStability()
			local aimLocation = botTarget:GetExtrapolatedLocation(delay)
			if directionStability < 0.95 then
				aimLocation = botTarget:GetLocation()
			end
			return BOT_ACTION_DESIRE_HIGH, aimLocation, botTarget
		end
	end
	if Fu.IsDefending(bot) then
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.IsInRange(bot, enemyHero, castRange)
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
				and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
				and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
				and not enemyHero:HasModifier("modifier_templar_assassin_refraction_absorb")
			then
				return BOT_ACTION_DESIRE_HIGH, enemyHero:GetLocation(), enemyHero
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
-- Why to fire a charging Sharpshooter now, or nil to keep charging.
--   full: charged for max_charge_time and the bolt line is on the target (or there is no target to aim at);
--   harassed: a hero is hitting her and she is hurt or it stands next to her, after half a second of charge;
--   leaving: the bolt would still reach the target now, but not once the charge is full.
-- Off the line at full charge she keeps turning; the bolt fires by itself at misfire_time.
function X.SharpshooterReleaseReason(charge, maxChargeTime, hasTarget, onLine, harassed, leaving)
	if charge >= maxChargeTime and (onLine or not hasTarget) then
		return "full"
	end
	if harassed and charge >= 0.5 then
		return "harassed"
	end
	if hasTarget and onLine and leaving and charge >= 0.5 then
		return "leaving"
	end
	return nil
end
local function FacingChange(fromDegrees, toDegrees)
	local change = math.abs(toDegrees - fromDegrees) % 360
	if change > 180 then
		change = 360 - change
	end
	return change
end
-- While Sharpshooter charges: turn the bolt line onto the target and release it (see the game data note at the
-- top). Returns true while the windup is on, so nothing else is ordered.
function X.ThinkSharpshooterWindup()
	local charging = bot:HasModifier("modifier_hoodwink_sharpshooter_windup")
	if not charging then
		if sharpshooterWindup ~= nil then
			-- Ended without our release: the bolt fired by itself (misfire_time) or she was interrupted.
			if not sharpshooterWindup.released then
				print(
					string.format(
						"[OHA-HOODWINK] t=%.0f hoodwink sharpshooter-end released=false charge=%.1f reaims=%d turned=%d",
						DotaTime(),
						DotaTime() - sharpshooterWindup.startedAt,
						sharpshooterWindup.reaims,
						math.floor(FacingChange(sharpshooterWindup.startFacing, bot:GetFacing()))
					)
				)
			end
			sharpshooterWindup = nil
		end
		return false
	end
	if sharpshooterWindup == nil then
		sharpshooterWindup = {
			startedAt = DotaTime(),
			target = bot._sharpshooterTarget,
			startFacing = bot:GetFacing(),
			reaims = 0,
			released = false,
		}
	end
	local windup = sharpshooterWindup
	local charge = DotaTime() - windup.startedAt
	local target = windup.target
	local hasTarget = Fu.IsValidHero(target) and target:CanBeSeen()
	if not hasTarget then
		-- The target died or went out of sight: the nearest enemy hero the bolt can still be turned onto.
		local visibleEnemies = Fu.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE)
		if visibleEnemies ~= nil and Fu.IsValidHero(visibleEnemies[1]) then
			target = visibleEnemies[1]
			windup.target = target
			hasTarget = true
		end
	end
	local onLine, leaving, targetDistance = false, false, 0
	local hitLocation = nil
	if hasTarget then
		local arrowSpeed = math.max(1, sharpshooterAbility:GetSpecialValueInt("arrow_speed"))
		local arrowRange = sharpshooterAbility:GetSpecialValueInt("arrow_range")
		local arrowWidth = sharpshooterAbility:GetSpecialValueInt("arrow_width")
		local maxChargeTime = sharpshooterAbility:GetSpecialValueFloat("max_charge_time")
		targetDistance = GetUnitToUnitDistance(bot, target)
		local flightTime = targetDistance / arrowSpeed
		hitLocation = target:GetExtrapolatedLocation(flightTime)
		-- On the line: the bolt (arrow_width wide) passes over where the target will be.
		local tolerance = math.max(3, math.deg(math.atan(arrowWidth / math.max(1, targetDistance))))
		onLine = bot:IsFacingLocation(hitLocation, tolerance)
		local locationAtFullCharge = target:GetExtrapolatedLocation(flightTime + math.max(0, maxChargeTime - charge))
		leaving = targetDistance < arrowRange - 200
			and GetUnitToLocationDistance(bot, locationAtFullCharge) > arrowRange - 200
	end
	local nearbyEnemies = Fu.GetNearbyHeroes(bot, 400, true, BOT_MODE_NONE)
	local harassed = bot:WasRecentlyDamagedByAnyHero(1.0)
		and (hpRatio < 0.6 or nearbyEnemies ~= nil and #nearbyEnemies > 0)
	local reason = X.SharpshooterReleaseReason(
		charge,
		sharpshooterAbility:GetSpecialValueFloat("max_charge_time"),
		hasTarget,
		onLine,
		harassed,
		leaving
	)
	if reason ~= nil and not sharpshooterReleaseAbility:IsHidden() and sharpshooterReleaseAbility:IsFullyCastable() then
		if not windup.released then
			windup.released = true
			print(
				string.format(
					"[OHA-HOODWINK] t=%.0f hoodwink sharpshooter-release reason=%s charge=%.1f target=%s dist=%d onLine=%s reaims=%d turned=%d",
					DotaTime(),
					reason,
					charge,
					hasTarget and (string.gsub(target:GetUnitName(), "npc_dota_hero_", "")) or "none",
					math.floor(targetDistance),
					tostring(onLine),
					windup.reaims,
					math.floor(FacingChange(windup.startFacing, bot:GetFacing()))
				)
			)
		end
		bot:Action_UseAbility(sharpshooterReleaseAbility)
		return true
	end
	-- Re-aim: a move order turns her while she charges (a plain move, not a vector order). Whether a bot's move
	-- order does it is what "reaims" and "turned" in the two log lines show.
	if hasTarget and not onLine and not windup.released then
		local botLocation = bot:GetLocation()
		local direction = Vector(hitLocation.x - botLocation.x, hitLocation.y - botLocation.y, 0)
		if direction:Length2D() > 1 then
			windup.reaims = windup.reaims + 1
			bot:Action_MoveDirectly(botLocation + direction:Normalized() * 300)
		end
	end
	return true
end
function X.ConsiderHuntersBoomerang()
	if not huntersBoomerangAbility:IsTrained() or not huntersBoomerangAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castRange = Fu.GetProperCastRange(false, bot, huntersBoomerangAbility:GetCastRange())
	local radius = huntersBoomerangAbility:GetSpecialValueInt("radius")
	local castPoint = huntersBoomerangAbility:GetCastPoint()
	if Fu.IsInTeamFight(bot, 1200) then
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
		local aoe = bot:FindAoELocation(true, true, bot:GetLocation(), castRange, radius, castPoint, 0)
		if aoe.count >= 2 then
			for _, enemyHero in pairs(nearbyEnemies) do
				if
					Fu.IsValidHero(enemyHero)
					and Fu.CanCastOnNonMagicImmune(enemyHero)
					and not Fu.IsSuspiciousIllusion(enemyHero)
					and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
					and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
					and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
					and not enemyHero:HasModifier("modifier_templar_assassin_refraction_absorb")
					and not enemyHero:HasModifier("modifier_faceless_void_chronosphere_freeze")
					and GetUnitToLocationDistance(enemyHero, aoe.targetloc) <= radius
				then
					return BOT_ACTION_DESIRE_HIGH, enemyHero
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function X.ConsiderDecoy()
	if not decoyAbility:IsTrained() or not decoyAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
	end
	local nearbyEnemyTowers = bot:GetNearbyTowers(900, true)
	local nearbyEnemies = Fu.GetNearbyHeroes(bot, 900, true, BOT_MODE_NONE)
	botTarget = Fu.GetProperTarget(bot)
	if
		bot:DistanceFromFountain() > 600
		and nearbyEnemyTowers ~= nil
		and #nearbyEnemyTowers == 0
		and not bot:HasModifier("modifier_item_dustofappearance")
		and not bot:HasModifier("modifier_slardar_amplify_damage")
		and not bot:HasModifier("modifier_item_glimmer_cape")
		and not bot:IsInvulnerable()
		and not bot:IsMagicImmune()
	then
		if bot:IsSilenced() or bot:IsRooted() or Fu.IsStunProjectileIncoming(bot, bot:GetAttackRange()) then
			return BOT_ACTION_DESIRE_HIGH
		end
		if
			isRetreating
				and bot:GetActiveModeDesire() >= BOT_MODE_DESIRE_HIGH
				and not bot:HasModifier("modifier_fountain_aura")
			or botTarget == nil
				and nearbyEnemies ~= nil
				and #nearbyEnemies >= 1
				and hpRatio < 0.33 + 0.09 * #nearbyEnemies
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
return X
