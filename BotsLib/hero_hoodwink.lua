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
-- Stratz 7.41f, week of 9 Nov 2026: pos 4, 110,885 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_4"] = {
	"item_tango",
	"item_blood_grenade",
	"item_double_branches",
	"item_magic_stick",
	"item_faerie_fire",
	"item_magic_wand",
	"item_urn_of_shadows",
	"item_arcane_boots",
	"item_essence_distiller",
	"item_rod_of_atos",
	"item_glimmer_cape",
	"item_gungir",
	"item_sheepstick",
	"item_blink",
	"item_spirit_vessel",
	"item_aghanims_shard",
	"item_moon_shard",
	"item_ultimate_scepter_2",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 5, 90,294 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_5"] = {
	"item_tango",
	"item_blood_grenade",
	"item_double_branches",
	"item_magic_stick",
	"item_faerie_fire",
	"item_magic_wand",
	"item_arcane_boots",
	"item_rod_of_atos",
	"item_glimmer_cape",
	"item_force_staff",
	"item_gungir",
	"item_sheepstick",
	"item_essence_distiller",
	"item_aghanims_shard",
	"item_moon_shard",
	"item_ultimate_scepter_2",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 3, 1,591 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_3"] = {
	"item_tango",
	"item_blood_grenade",
	"item_double_branches",
	"item_faerie_fire",
	"item_circlet",
	"item_magic_wand",
	"item_arcane_boots",
	"item_maelstrom",
	"item_rod_of_atos",
	"item_desolator",
	"item_ultimate_scepter",
	"item_greater_crit",
	"item_mjollnir",
	"item_ultimate_scepter_2",
	"item_aether_lens",
	"item_aghanims_shard",
	"item_moon_shard",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 1, 1,518 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_1"] = {
	"item_tango",
	"item_double_branches",
	"item_faerie_fire",
	"item_circlet",
	"item_slippers",
	"item_wraith_band",
	"item_magic_wand",
	"item_falcon_blade",
	"item_power_treads",
	"item_maelstrom",
	"item_desolator",
	"item_lesser_crit",
	"item_mjollnir",
	"item_greater_crit",
	"item_skadi",
	"item_ultimate_scepter_2",
	"item_moon_shard",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 2, 4,974 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_2"] = {
	"item_tango",
	"item_double_branches",
	"item_faerie_fire",
	"item_circlet",
	"item_slippers",
	"item_magic_wand",
	"item_power_treads",
	"item_maelstrom",
	"item_desolator",
	"item_lesser_crit",
	"item_travel_boots",
	"item_greater_crit",
	"item_ultimate_scepter",
	"item_mjollnir",
	"item_ultimate_scepter_2",
	"item_meteor_hammer",
	"item_skadi",
	"item_moon_shard",
	"item_travel_boots_2",
}
X["sBuyList"] = sRoleItemsBuyList[sRole]
X["sSellList"] = {
	"item_black_king_bar",
	"item_quelling_blade",
	-- Sold once the item before it is owned, to keep six slots (Util/item-builds/generate.js):
	"item_spirit_vessel",
	"item_essence_distiller",
}
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
-- An Acorn Shot or Bushwhack order that another order (a mode's move) replaced before it left is given again for
-- this long; after it the cast is logged as lost.
local CAST_REISSUE_WINDOW = 1.0
-- A pending cast is still waited for while she walks into range or casts it, up to this long after the order.
local CAST_HOLD_CAP = 3.0
-- No acorn-tree combo with an enemy hero this close to her: it takes two casts (0.2s cast point each, datafeed
-- hero_id=123) from Acorn range (675-750), and a hero that close hits her first. The acorn bounces instead.
local ACORN_COMBO_MIN_ENEMY_DIST = 500
-- Bushwhack save: an ally under this HP who took damage from an enemy hero within the last SAVE_RECENT_HIT seconds,
-- in any mode (a retreating ally who was hit still counts at any HP, as before).
local SAVE_ALLY_HP = 0.5
local SAVE_RECENT_HIT = 2.5
local sharpshooterWindup = nil -- { startedAt, target, startFacing, reaims, released }
local acornTree = nil -- { location, plantedAt, target }
local acornTreeProbe = nil -- { location, castAt }
local acornPending = nil -- { mode, location, target, why, orderedAt, reissues }
local bushwhackPending = nil -- { center, why, target, expected, orderedAt, reissues, castAt, checkAt }
local scurryRun = nil -- { why, target, startedAt, duration, startDist, minDist, reach, ready, used, active, deaths, hp }
local lastAcornLogAt = -100
local lastAcornLostLogAt = -100
local lastBushwhackSkipLogAt = -100
local lastBushwhackSaveCheckAt = -100
local acornShotDesire, acornShotLocation, acornShotTarget, acornShotWhy
local bushwhackDesire, bushwhackLocation, bushwhackWhy, bushwhackTarget, bushwhackExpected, bushwhackNote
local scurryDesire, scurryPlan
local ChargeTracker = require(GetScriptDirectory() .. "/FuncLib/systems/charge_tracker")
-- Scurry, game data 7.42 (npc_dota_hero_hoodwink.txt): 2 charges (restore 30/24/18/12s), 35 mana,
-- movement_speed_pct 20/24/28/32 for duration 3.5/4/4.5/5s. Fallbacks when the API reads 0: level 1 values.
local SCURRY_FALLBACK_SPEED_PCT = 20
local SCURRY_FALLBACK_DURATION = 3.5
-- Sharpshooter is cast from this range (ConsiderSharpshooter), not its 3000 game-file range.
local SHARPSHOOTER_CAST_RANGE = 1600
-- Scurry to reach a cast spot only for a walk up to this long (game 064: a 2049 walk after Abaddon, who was faster
-- than her, ended with no spell on him).
local SCURRY_POSITION_MAX_WALK = 1000
local lastScurryOrderAt = -100
local lastScurryLogAt = -100
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
	-- Results of earlier casts (acorn-cast / acorn-lost, bushwhack-result, scurry-result) come before every gate, so
	-- they print while she is stunned or casting too.
	pcall(X.ThinkCastResults)
	pcall(X.ProbeAcornTree)
	if X.ThinkSharpshooterWindup() then
		return
	end
	if Fu.CanNotUseAbility(bot) then
		return
	end
	if X.ReissuePendingCast() then
		return
	end
	acornShotDesire, acornShotLocation, acornShotTarget, acornShotWhy = X.ConsiderAcornShot()
	if acornShotDesire > 0 then
		X.CastAcornShot(acornShotLocation, acornShotTarget, acornShotWhy)
		return
	end
	bushwhackDesire, bushwhackLocation, bushwhackWhy, bushwhackTarget, bushwhackExpected, bushwhackNote =
		X.ConsiderBushwhack()
	if bushwhackDesire > 0 then
		X.CastBushwhack(bushwhackLocation, bushwhackWhy, bushwhackTarget, bushwhackExpected, bushwhackNote)
		return
	end
	scurryDesire, scurryPlan = X.ConsiderScurry()
	if scurryDesire > 0 then
		bot:Action_UseAbility(scurryAbility)
		-- No cast point, so the charge tracker only sees the cast through this mark and the mana drop.
		pcall(ChargeTracker.Issued, bot, scurryAbility)
		lastScurryOrderAt = DotaTime()
		X.StartScurryRun(scurryPlan)
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
		-- Only a target in range. Game 064: 12 of 25 tree-mode acorns never left; 6 of them came in the same second as
		-- attack mode picking that target 2100-6900 away from her to follow an ally, so she walked toward it until
		-- another order replaced the cast.
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
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
-- "bounce": it goes on the unit and bounces between the enemies around it. "ground": on the ground, no combo.
-- enemyClose: an enemy hero within ACORN_COMBO_MIN_ENEMY_DIST of her (no time for the two-cast combo).
function X.AcornShotMode(why, bushwhackReady, manaForBoth, targetCanBeTrapped, treeNearTarget, enemyClose)
	if why == "wave" then
		return "tree"
	end
	-- A unit cast is not allowed on a spell-immune enemy (game files: SPELL_IMMUNITY_ENEMIES_NO), and an order the
	-- engine refuses would repeat every think: the ground by it, as before this rule, and no Bushwhack follow-up.
	if not targetCanBeTrapped then
		return "ground"
	end
	if why ~= "kill" and bushwhackReady and manaForBoth and not treeNearTarget and not enemyClose then
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
-- The Bushwhack centre that nets the most enemies, or nil. The net only stuns what it pulls to a tree, so a centre
-- counts only with a tree inside it. Candidates: each enemy, the midpoint of two enemies, and the point halfway
-- between an enemy and a tree. Everything is counted 25 inside the radius. mustNet: an index into enemyLocations
-- that the net has to hold (the acorn's target), or nil. Returns centre, count.
function X.BestNetSpot(enemyLocations, treeLocations, radius, mustNet)
	local reach = radius - 25
	local candidates = {}
	for i, enemyLocation in ipairs(enemyLocations) do
		table.insert(candidates, enemyLocation)
		for j = i + 1, #enemyLocations do
			if Fu.GetLocationToLocationDistance(enemyLocation, enemyLocations[j]) <= 2 * reach then
				table.insert(candidates, (enemyLocation + enemyLocations[j]) / 2)
			end
		end
		for _, treeLocation in ipairs(treeLocations) do
			local center = X.BushwhackCenterForTree(enemyLocation, treeLocation, radius)
			if center ~= nil then
				table.insert(candidates, center)
			end
		end
	end
	local bestCenter, bestCount = nil, 0
	for _, center in ipairs(candidates) do
		local hasTree = false
		for _, treeLocation in ipairs(treeLocations) do
			if Fu.GetLocationToLocationDistance(center, treeLocation) <= reach then
				hasTree = true
				break
			end
		end
		if hasTree then
			local count, holdsMust = 0, mustNet == nil
			for i, enemyLocation in ipairs(enemyLocations) do
				if Fu.GetLocationToLocationDistance(center, enemyLocation) <= reach then
					count = count + 1
					if i == mustNet then
						holdsMust = true
					end
				end
			end
			if holdsMust and count > bestCount then
				bestCenter, bestCount = center, count
			end
		end
	end
	return bestCenter, bestCount
end
-- Where to plant the acorn tree for the combo: at the target, or halfway to another enemy within one net of it so
-- that Bushwhack on the planted tree holds both. otherLocations: the other enemy heroes. Returns spot, count.
function X.AcornTreeSpot(targetLocation, otherLocations, radius)
	local reach = radius - 25
	local bestSpot, bestCount = targetLocation, 1
	for _, otherLocation in ipairs(otherLocations) do
		if Fu.GetLocationToLocationDistance(targetLocation, otherLocation) <= 2 * reach then
			local spot = (targetLocation + otherLocation) / 2
			local count = 1
			for _, location in ipairs(otherLocations) do
				if Fu.GetLocationToLocationDistance(spot, location) <= reach then
					count = count + 1
				end
			end
			if count > bestCount then
				bestSpot, bestCount = spot, count
			end
		end
	end
	return bestSpot, bestCount
end
-- Enemy heroes Bushwhack could net, at where they will be when the net lands: locations, units.
local function NetCandidates(nearLocation, nearRadius, castRange, radius, castPoint, projectileSpeed)
	local locations, units = {}, {}
	for _, enemyHero in pairs(Fu.GetEnemiesNearLoc(nearLocation, nearRadius)) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and not Fu.IsSuspiciousIllusion(enemyHero)
			and not Fu.IsDisabled(enemyHero)
			and Fu.IsInRange(bot, enemyHero, castRange + radius)
		then
			local delay = GetUnitToUnitDistance(bot, enemyHero) / math.max(1, projectileSpeed) + castPoint
			table.insert(locations, enemyHero:GetExtrapolatedLocation(delay))
			table.insert(units, enemyHero)
		end
	end
	return locations, units
end
-- Tree locations within one net of any of the locations (GetNearbyTrees is read once, around her).
local function TreesNear(locations, radius)
	local trees = {}
	if #locations == 0 then
		return trees
	end
	for _, tree in pairs(bot:GetNearbyTrees(1600) or {}) do
		local treeLocation = GetTreeLocation(tree)
		for _, location in ipairs(locations) do
			if Fu.GetLocationToLocationDistance(treeLocation, location) <= 2 * radius then
				table.insert(trees, treeLocation)
				break
			end
		end
	end
	return trees
end
local function ShortName(unit)
	if unit == nil or not Fu.IsValid(unit) then
		return "none"
	end
	return (string.gsub(unit:GetUnitName(), "npc_dota_hero_", ""))
end
local function IssueAcornShot(pending)
	if pending.mode == "bounce" then
		bot:Action_UseAbilityOnEntity(acornShotAbility, pending.target)
	else
		bot:Action_UseAbilityOnLocation(acornShotAbility, pending.location)
	end
end
function X.CastAcornShot(location, target, why)
	local mode
	local nearCount = 0
	local netCount = 0
	local enemyClose = false
	if target == nil then
		mode = "tree"
	else
		local trapRadius = bushwhackAbility:GetSpecialValueInt("trap_radius")
		local trees = target:GetNearbyTrees(trapRadius - 25)
		for _, enemyHero in pairs(Fu.GetNearbyHeroes(bot, ACORN_COMBO_MIN_ENEMY_DIST, true, BOT_MODE_NONE) or {}) do
			if Fu.IsValidHero(enemyHero) and not Fu.IsSuspiciousIllusion(enemyHero) then
				enemyClose = true
				break
			end
		end
		mode = X.AcornShotMode(
			why,
			bushwhackAbility:IsTrained() and bushwhackAbility:GetCooldownTimeRemaining() <= 0.5,
			bot:GetMana() >= acornShotAbility:GetManaCost() + bushwhackAbility:GetManaCost(),
			Fu.CanCastOnNonMagicImmune(target),
			trees ~= nil and #trees > 0,
			enemyClose
		)
		local bounceRange = acornShotAbility:GetSpecialValueInt("bounce_range")
		local heroesNear = Fu.GetEnemiesNearLoc(target:GetLocation(), bounceRange)
		nearCount = math.max(0, (heroesNear and #heroesNear or 0) - 1)
		for _, creep in pairs(bot:GetNearbyCreeps(1600, true) or {}) do
			if Fu.IsValid(creep) and GetUnitToUnitDistance(creep, target) <= bounceRange then
				nearCount = nearCount + 1
			end
		end
		if mode == "tree" then
			-- A spot that nets a second enemy too, if one stands within one net of the target and in Acorn range.
			local otherLocations = {}
			for _, enemyHero in pairs(Fu.GetEnemiesNearLoc(target:GetLocation(), 2 * trapRadius)) do
				if
					Fu.IsValidHero(enemyHero)
					and enemyHero ~= target
					and Fu.CanCastOnNonMagicImmune(enemyHero)
					and not Fu.IsSuspiciousIllusion(enemyHero)
				then
					local delay = GetUnitToUnitDistance(bot, enemyHero)
							/ math.max(1, acornShotAbility:GetSpecialValueInt("projectile_speed"))
						+ acornShotAbility:GetCastPoint()
					table.insert(otherLocations, enemyHero:GetExtrapolatedLocation(delay))
				end
			end
			local spot, count = X.AcornTreeSpot(location, otherLocations, trapRadius)
			netCount = 1
			if
				count >= 2
				and GetUnitToLocationDistance(bot, spot)
					<= Fu.GetProperCastRange(false, bot, acornShotAbility:GetCastRange())
			then
				location, netCount = spot, count
			end
		end
	end
	if DotaTime() - lastAcornLogAt >= 3 then
		lastAcornLogAt = DotaTime()
		print(
			string.format(
				"[OHA-HOODWINK] t=%.0f hoodwink acorn mode=%s why=%s target=%s near=%d net=%d close=%s dist=%d",
				DotaTime(),
				mode,
				tostring(why),
				target ~= nil and ShortName(target) or "ground",
				nearCount,
				netCount,
				tostring(enemyClose),
				math.floor(
					target ~= nil and GetUnitToUnitDistance(bot, target) or GetUnitToLocationDistance(bot, location)
				)
			)
		)
	end
	acornPending = {
		mode = mode,
		location = location,
		target = target,
		why = why,
		net = netCount,
		orderedAt = DotaTime(),
		reissues = 0,
	}
	IssueAcornShot(acornPending)
end
-- A pending Acorn Shot or Bushwhack whose order was replaced (she is free to act, the spell is still ready) is
-- ordered again, for CAST_REISSUE_WINDOW seconds. True when an order was given.
function X.ReissuePendingCast()
	local acorn = acornPending
	if
		acorn ~= nil
		and DotaTime() - acorn.orderedAt <= CAST_REISSUE_WINDOW
		and acornShotAbility:IsFullyCastable()
		and (acorn.target == nil or Fu.IsValid(acorn.target) and acorn.target:IsAlive())
	then
		acorn.reissues = acorn.reissues + 1
		IssueAcornShot(acorn)
		return true
	end
	local net = bushwhackPending
	if
		net ~= nil
		and net.castAt == nil
		and DotaTime() - net.orderedAt <= CAST_REISSUE_WINDOW
		and bushwhackAbility:IsFullyCastable()
	then
		net.reissues = net.reissues + 1
		bot:Action_UseAbilityOnLocation(bushwhackAbility, net.center)
		return true
	end
	return false
end
-- Why a pending cast did not leave in time.
local function LostReason(target, location, castRange)
	if not bot:IsAlive() then
		return "dead"
	end
	if bot:IsStunned() or bot:IsSilenced() or bot:IsHexed() then
		return "disabled"
	end
	if target ~= nil and not (Fu.IsValid(target) and target:IsAlive()) then
		return "target-gone"
	end
	local distance = target ~= nil and Fu.IsValid(target) and GetUnitToUnitDistance(bot, target)
		or GetUnitToLocationDistance(bot, location)
	if distance > castRange + 100 then
		return "out-of-range"
	end
	return "replaced"
end
-- The Hoodwink spells whose cast after a Scurry is checked (scurry-result spell=).
local function ScurrySpells()
	return {
		{ "acorn", acornShotAbility },
		{ "bushwhack", bushwhackAbility },
		{ "sharpshooter", sharpshooterAbility },
	}
end
function X.ThinkCastResults()
	local now = DotaTime()
	local acorn = acornPending
	if acorn ~= nil then
		if not acornShotAbility:IsCooldownReady() then
			print(
				string.format(
					"[OHA-HOODWINK] t=%.0f hoodwink acorn-cast mode=%s why=%s target=%s net=%d after=%.2f reissues=%d",
					now,
					acorn.mode,
					tostring(acorn.why),
					acorn.target ~= nil and ShortName(acorn.target) or "ground",
					acorn.net or 0,
					now - acorn.orderedAt,
					acorn.reissues
				)
			)
			-- The tree is remembered from the moment the acorn left (its cooldown runs), not from the order.
			if acorn.mode == "tree" and acorn.target ~= nil then
				acornTree = { location = acorn.location, plantedAt = now, target = acorn.target }
				acornTreeProbe = { location = acorn.location, castAt = now }
			end
			acornPending = nil
		elseif
			now - acorn.orderedAt > CAST_REISSUE_WINDOW
				and not acornShotAbility:IsInAbilityPhase()
				and not (bot:IsUsingAbility() or bot:IsCastingAbility())
			or now - acorn.orderedAt > CAST_HOLD_CAP
		then
			if now - lastAcornLostLogAt >= 3 then
				lastAcornLostLogAt = now
				print(
					string.format(
						"[OHA-HOODWINK] t=%.0f hoodwink acorn-lost why=%s mode=%s target=%s reissues=%d",
						now,
						LostReason(
							acorn.target,
							acorn.location,
							Fu.GetProperCastRange(false, bot, acornShotAbility:GetCastRange())
						),
						acorn.mode,
						acorn.target ~= nil and ShortName(acorn.target) or "ground",
						acorn.reissues
					)
				)
			end
			acornPending = nil
		end
	end
	local net = bushwhackPending
	if net ~= nil then
		if net.castAt == nil then
			if not bushwhackAbility:IsCooldownReady() then
				net.castAt = now
				-- The net flies at projectile_speed (1200, datafeed); the stun (debuff_duration 1.4-2s) is read
				-- 0.4s after it lands.
				local speed = math.max(1, bushwhackAbility:GetSpecialValueInt("projectile_speed"))
				net.checkAt = now + GetUnitToLocationDistance(bot, net.center) / speed + 0.4
			elseif
				now - net.orderedAt > CAST_REISSUE_WINDOW
					and not bushwhackAbility:IsInAbilityPhase()
					and not (bot:IsUsingAbility() or bot:IsCastingAbility())
				or now - net.orderedAt > CAST_HOLD_CAP
			then
				print(
					string.format(
						"[OHA-HOODWINK] t=%.0f hoodwink bushwhack-result kind=%s cast=false lost=%s netted=0 expect=%d target=%s",
						now,
						net.why,
						LostReason(nil, net.center, Fu.GetProperCastRange(false, bot, bushwhackAbility:GetCastRange())),
						net.expected,
						ShortName(net.target)
					)
				)
				bushwhackPending = nil
			end
		elseif now >= net.checkAt then
			local radius = bushwhackAbility:GetSpecialValueInt("trap_radius")
			local netted = 0
			for _, enemyHero in pairs(Fu.GetEnemiesNearLoc(net.center, radius + 150)) do
				if Fu.IsValidHero(enemyHero) and enemyHero:IsStunned() then
					netted = netted + 1
				end
			end
			-- The net's modifier name is not in the game data we have: list the target's Hoodwink modifiers so a
			-- game shows it.
			local mods = {}
			if Fu.IsValidHero(net.target) then
				for i = 0, net.target:NumModifiers() - 1 do
					local name = net.target:GetModifierName(i)
					if name ~= nil and string.find(name, "hoodwink", 1, true) then
						table.insert(mods, name)
					end
				end
			end
			print(
				string.format(
					"[OHA-HOODWINK] t=%.0f hoodwink bushwhack-result kind=%s cast=true netted=%d expect=%d target=%s targetStunned=%s mods=%s late=%.1f",
					now,
					net.why,
					netted,
					net.expected,
					ShortName(net.target),
					tostring(Fu.IsValidHero(net.target) and net.target:IsStunned()),
					#mods > 0 and table.concat(mods, ",") or "-",
					now - net.checkAt
				)
			)
			bushwhackPending = nil
		end
	end
	local run = scurryRun
	if run ~= nil then
		if bot:HasModifier("modifier_hoodwink_scurry_active") then
			run.active = true
		end
		if Fu.IsValidHero(run.target) and run.target:CanBeSeen() then
			run.minDist = math.min(run.minDist, GetUnitToUnitDistance(bot, run.target))
		end
		for _, spell in ipairs(ScurrySpells()) do
			if run.used == nil and run.ready[spell[1]] and not spell[2]:IsCooldownReady() then
				run.used = spell[1]
			end
		end
		if now >= run.startedAt + run.duration then
			local died = GetHeroDeaths(bot:GetPlayerID()) > run.deaths
			print(
				string.format(
					"[OHA-HOODWINK] t=%.0f hoodwink scurry-result kind=%s target=%s reached=%s startDist=%d minDist=%d reach=%d spell=%s cast=%s died=%s hp=%.2f->%.2f late=%.1f",
					now,
					run.why,
					ShortName(run.target),
					tostring(run.minDist <= run.reach),
					math.floor(run.startDist),
					math.floor(run.minDist),
					math.floor(run.reach),
					run.used or "none",
					tostring(run.active),
					tostring(died),
					run.hp,
					Fu.GetHP(bot),
					now - run.startedAt - run.duration
				)
			)
			scurryRun = nil
		end
	end
end
-- Does the API list a planted tree? One second after the acorn left, the distance from the planted spot to the
-- nearest tree GetNearbyTrees returns. Tree mode is only used with no tree within 250 of the target, so a tree
-- within 60 of the spot is the planted one.
function X.ProbeAcornTree()
	local probe = acornTreeProbe
	if probe == nil or DotaTime() < probe.castAt + 1 then
		return
	end
	acornTreeProbe = nil
	local nearest = -1
	for _, tree in pairs(bot:GetNearbyTrees(1300) or {}) do
		local distance = Fu.GetLocationToLocationDistance(GetTreeLocation(tree), probe.location)
		if nearest < 0 or distance < nearest then
			nearest = distance
		end
	end
	print(
		string.format(
			"[OHA-HOODWINK] t=%.0f hoodwink planted-tree listed=%s nearest=%d fromBot=%d",
			DotaTime(),
			tostring(nearest >= 0 and nearest <= 60),
			math.floor(nearest),
			math.floor(GetUnitToLocationDistance(bot, probe.location))
		)
	)
end
-- Bushwhack on the tree her own acorn planted. GetNearbyTrees may not list a planted tree (the planted-tree log
-- tells), so the spot is remembered from the cast: the acorn's target for ACORN_COMBO_WINDOW seconds, then the
-- attack target. The net goes where it holds that target and as many other enemies as possible.
function X.ConsiderBushwhackAtAcornTree(castRange, radius, castPoint, projectileSpeed)
	if acornTree == nil then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local age = DotaTime() - acornTree.plantedAt
	if age > ACORN_TREE_DURATION then
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
	local locations = { enemyHero:GetExtrapolatedLocation(delay) }
	local others, otherUnits =
		NetCandidates(acornTree.location, 2 * radius, castRange, radius, castPoint, projectileSpeed)
	for i, unit in ipairs(otherUnits) do
		if unit ~= enemyHero then
			table.insert(locations, others[i])
		end
	end
	local center, count = X.BestNetSpot(locations, { acornTree.location }, radius, 1)
	if center == nil or GetUnitToLocationDistance(bot, center) > castRange then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local note = string.format(
		" treeDist=%d treeAge=%.1f",
		math.floor(GetUnitToLocationDistance(enemyHero, acornTree.location)),
		age
	)
	-- One net per tree: a miss is not thrown again.
	acornTree = nil
	return BOT_ACTION_DESIRE_HIGH, center, "acorn-tree", enemyHero, count, note
end
-- Is an ally in trouble enough for a save net? Under SAVE_ALLY_HP and hit by an enemy hero lately, in any mode, or
-- retreating and hit (the rule before game 064, which missed a 40% HP ally whose mode was not retreat).
function X.AllyNeedsSave(allyHp, hitByHeroLately, retreating)
	if not hitByHeroLately then
		return false
	end
	return allyHp < SAVE_ALLY_HP or retreating
end
-- Bushwhack for an ally in trouble: every enemy hero near him is checked, and the net goes where it holds the most
-- of them with a tree inside. Returns desire, centre, target, count, note.
function X.ConsiderBushwhackSave(castRange, radius, castPoint, projectileSpeed)
	-- The tree search reads every tree around her: a few times a second is enough.
	if DotaTime() - lastBushwhackSaveCheckAt < 0.25 then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	lastBushwhackSaveCheckAt = DotaTime()
	local skipWhy, skipAlly, skipChasers = nil, nil, 0
	for _, allyHero in pairs(Fu.GetNearbyHeroes(bot, math.min(1600, castRange + radius), false, BOT_MODE_NONE) or {}) do
		if
			Fu.IsValidHero(allyHero)
			and allyHero ~= bot
			and not allyHero:IsIllusion()
			and X.AllyNeedsSave(
				Fu.GetHP(allyHero),
				allyHero:WasRecentlyDamagedByAnyHero(SAVE_RECENT_HIT),
				Fu.IsRetreating(allyHero)
			)
		then
			local locations, units =
				NetCandidates(allyHero:GetLocation(), 900, castRange, radius, castPoint, projectileSpeed)
			if #units == 0 then
				skipWhy = skipWhy or "no-chaser"
			else
				local center, count = X.BestNetSpot(locations, TreesNear(locations, radius), radius, nil)
				if center ~= nil and GetUnitToLocationDistance(bot, center) <= castRange then
					local target = units[1]
					for i, location in ipairs(locations) do
						if Fu.GetLocationToLocationDistance(center, location) <= radius - 25 then
							target = units[i]
							break
						end
					end
					return BOT_ACTION_DESIRE_HIGH,
						center,
						"save",
						target,
						count,
						string.format(
							" ally=%s allyHp=%.2f chasers=%d",
							ShortName(allyHero),
							Fu.GetHP(allyHero),
							#units
						)
				end
				skipWhy = center ~= nil and "out-of-range" or "no-tree"
			end
			skipAlly, skipChasers = skipAlly or allyHero, math.max(skipChasers, #units)
		end
	end
	if skipWhy ~= nil and DotaTime() - lastBushwhackSkipLogAt >= 3 then
		lastBushwhackSkipLogAt = DotaTime()
		print(
			string.format(
				"[OHA-HOODWINK] t=%.0f hoodwink bushwhack-skip why=%s ally=%s allyHp=%.2f chasers=%d",
				DotaTime(),
				skipWhy,
				ShortName(skipAlly),
				skipAlly ~= nil and Fu.GetHP(skipAlly) or 0,
				skipChasers
			)
		)
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
-- Gives the Bushwhack order and remembers it for the reissue and the bushwhack-result line.
function X.CastBushwhack(location, why, target, expected, note)
	if bushwhackPending == nil or bushwhackPending.castAt == nil and DotaTime() - bushwhackPending.orderedAt > 3 then
		bushwhackPending = {
			center = location,
			why = why,
			target = target,
			expected = expected or 1,
			orderedAt = DotaTime(),
			reissues = 0,
		}
		print(
			string.format(
				"[OHA-HOODWINK] t=%.0f hoodwink bushwhack why=%s target=%s expect=%d dist=%d%s",
				DotaTime(),
				why,
				ShortName(target),
				expected or 1,
				math.floor(GetUnitToLocationDistance(bot, location)),
				note or ""
			)
		)
	end
	bot:Action_UseAbilityOnLocation(bushwhackAbility, location)
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
	local acornTreeDesire, acornTreeLocation, acornWhy, acornTarget, acornCount, acornNote =
		X.ConsiderBushwhackAtAcornTree(castRange, radius, castPoint, projectileSpeed)
	if acornTreeDesire > 0 then
		return acornTreeDesire, acornTreeLocation, acornWhy, acornTarget, acornCount, acornNote
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
					return BOT_ACTION_DESIRE_HIGH, enemyHero:GetLocation(), "channel", enemyHero, 1
				end
				if
					Fu.CanKillTarget(enemyHero, damage, DAMAGE_TYPE_MAGICAL)
					and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
					and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
					and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
					and not enemyHero:HasModifier("modifier_templar_assassin_refraction_absorb")
				then
					local delay = GetUnitToUnitDistance(bot, enemyHero) / projectileSpeed + castPoint
					return BOT_ACTION_DESIRE_HIGH, enemyHero:GetExtrapolatedLocation(delay), "kill", enemyHero, 1
				end
			end
		end
	end
	local saveDesire, saveCenter, saveWhy, saveTarget, saveCount, saveNote =
		X.ConsiderBushwhackSave(castRange, radius, castPoint, projectileSpeed)
	if saveDesire > 0 then
		return saveDesire, saveCenter, saveWhy, saveTarget, saveCount, saveNote
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
						return BOT_ACTION_DESIRE_HIGH,
							enemyHero:GetExtrapolatedLocation(delay),
							"teamfight",
							enemyHero,
							aoe.count
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
				return BOT_ACTION_DESIRE_HIGH, botTarget:GetExtrapolatedLocation(delay), "engage", botTarget, 1
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
				return BOT_ACTION_DESIRE_HIGH, nearbyEnemies[1]:GetLocation(), "retreat", nearbyEnemies[1], 1
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
-- Is a unit moving at velocity from one spot within maxDegrees of the direction to another? False when it stands
-- (under 50 speed).
function X.HeadingWithin(velocity, fromLocation, toLocation, maxDegrees)
	local speed = math.sqrt(velocity.x * velocity.x + velocity.y * velocity.y)
	local toX, toY = toLocation.x - fromLocation.x, toLocation.y - fromLocation.y
	local gap = math.sqrt(toX * toX + toY * toY)
	if speed < 50 or gap < 1 then
		return false
	end
	return (velocity.x * toX + velocity.y * toY) / (speed * gap) >= math.cos(math.rad(maxDegrees))
end
-- Why to use Scurry now (the caller checked it is castable), or nil. Escape may spend the last charge; chase and
-- position only a spare one, so one charge is always kept for an escape. s: charges (tracked count, nil = unknown,
-- counted as 1), retreating, headingHome, inDanger, engaging, targetDist, attackRange, headingToTarget,
-- targetRunningAway, targetSpeed, mySpeed, speedPct, duration, castWalk (the shortest walk until a ready spell
-- reaches the target, or nil).
--   escape: retreating, heading home, and in danger;
--   chase: the target is out of attack range but within the extra distance Scurry's speed buys over its duration,
--     running from her and not slower than her (a slower one is caught without it), but slower than her Scurry speed;
--   position: the walk to a spell's cast range takes over 2s but is at most SCURRY_POSITION_MAX_WALK, she still
--     arrives while Scurry lasts, and the target is not running from her faster than she walks (game 064: Abaddon
--     at 380 against her 365 ran out of every cast range).
function X.ScurryReason(s)
	local charges = s.charges or 1
	if s.retreating then
		if s.headingHome and s.inDanger then
			return "escape"
		end
		return nil
	end
	if not s.engaging or charges < 2 or s.targetDist == nil or not s.headingToTarget or s.mySpeed <= 0 then
		return nil
	end
	local extraReach = s.mySpeed * s.speedPct / 100 * s.duration
	if
		s.targetDist > s.attackRange
		and s.targetDist <= s.attackRange + extraReach
		and s.targetRunningAway
		and s.targetSpeed >= s.mySpeed
		and s.targetSpeed < s.mySpeed * (1 + s.speedPct / 100)
	then
		return "chase"
	end
	if
		s.castWalk ~= nil
		and s.castWalk / s.mySpeed > 2
		and s.castWalk <= SCURRY_POSITION_MAX_WALK
		and s.castWalk <= s.mySpeed * (1 + s.speedPct / 100) * s.duration
		and not (s.targetRunningAway and (s.targetSpeed or 0) > s.mySpeed)
	then
		return "position"
	end
	return nil
end
-- The shortest walk until a ready spell she would cast on the target has it in range (nil: none ready, or one is in
-- range already). The cast ranges are the ones the Consider functions use; mana is kept for the spell and Scurry.
function X.ScurryCastWalk(target, targetDist)
	local spareMana = bot:GetMana() - scurryAbility:GetManaCost()
	local walk = nil
	local function Add(ability, castRange)
		if ability:IsFullyCastable() and spareMana >= ability:GetManaCost() then
			local need = targetDist - castRange
			walk = walk == nil and need or math.min(walk, need)
		end
	end
	Add(acornShotAbility, Fu.GetProperCastRange(false, bot, acornShotAbility:GetCastRange()))
	if Fu.CanCastOnNonMagicImmune(target) then
		Add(bushwhackAbility, Fu.GetProperCastRange(false, bot, bushwhackAbility:GetCastRange()))
		Add(sharpshooterAbility, SHARPSHOOTER_CAST_RANGE)
	end
	if walk == nil or walk <= 0 then
		return nil
	end
	return walk
end
function X.ConsiderScurry()
	if
		not scurryAbility:IsFullyCastable()
		or bot:HasModifier("modifier_hoodwink_scurry_active")
		or Fu.IsRealInvisible(bot)
	then
		return BOT_ACTION_DESIRE_NONE
	end
	local speedPct = scurryAbility:GetSpecialValueInt("movement_speed_pct")
	local duration = scurryAbility:GetSpecialValueFloat("duration")
	speedPct = speedPct > 0 and speedPct or SCURRY_FALLBACK_SPEED_PCT
	duration = duration > 0 and duration or SCURRY_FALLBACK_DURATION
	-- The order just given is still running (the tracker and the modifier can lag a think behind it).
	if DotaTime() - lastScurryOrderAt < duration then
		return BOT_ACTION_DESIRE_NONE
	end
	local botLocation = bot:GetLocation()
	local s = {
		charges = ChargeTracker.Count(bot, scurryAbility),
		retreating = isRetreating,
		engaging = isGoingOnSomeone,
		mySpeed = bot:GetCurrentMovementSpeed(),
		speedPct = speedPct,
		duration = duration,
	}
	local logDist, logTarget = -1, "none"
	local planTarget = nil
	if isRetreating then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, 800, false, BOT_MODE_NONE)
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, 600, true, BOT_MODE_NONE)
		local escapeLocation = Fu.GetEscapeLoc()
		-- Moving toward home is enough (the retreat path bends); facing it within 30 degrees also counts.
		s.headingHome = X.HeadingWithin(bot:GetVelocity(), botLocation, escapeLocation, 90)
			or bot:IsFacingLocation(escapeLocation, 30)
		s.inDanger = nearbyAllies ~= nil
				and nearbyEnemies ~= nil
				and (#nearbyEnemies > #nearbyAllies or hpRatio < 0.55 and bot:WasRecentlyDamagedByAnyHero(2))
				and Fu.IsValidHero(nearbyEnemies[1])
				and not Fu.IsSuspiciousIllusion(nearbyEnemies[1])
				and not Fu.IsDisabled(nearbyEnemies[1])
			or hpRatio < 0.55 and bot:WasRecentlyDamagedByTower(2.5)
		if nearbyEnemies ~= nil and Fu.IsValidHero(nearbyEnemies[1]) then
			logDist = GetUnitToUnitDistance(bot, nearbyEnemies[1])
			logTarget = (string.gsub(nearbyEnemies[1]:GetUnitName(), "npc_dota_hero_", ""))
			planTarget = nearbyEnemies[1]
		end
	elseif isGoingOnSomeone then
		botTarget = Fu.GetProperTarget(bot)
		if Fu.IsValidHero(botTarget) and not Fu.IsSuspiciousIllusion(botTarget) and not Fu.IsDisabled(botTarget) then
			local targetLocation = botTarget:GetLocation()
			s.targetDist = GetUnitToUnitDistance(bot, botTarget)
			-- Attack range is counted from the hull edges; 50 more before she is really out of range.
			s.attackRange = bot:GetAttackRange() + 50
			s.headingToTarget = X.HeadingWithin(bot:GetVelocity(), botLocation, targetLocation, 45)
				or bot:IsFacingLocation(targetLocation, 30)
			-- Running from her: moving within 90 degrees of straight away from her.
			local awayLocation =
				Vector(2 * targetLocation.x - botLocation.x, 2 * targetLocation.y - botLocation.y, targetLocation.z)
			s.targetRunningAway = X.HeadingWithin(botTarget:GetVelocity(), targetLocation, awayLocation, 90)
			s.targetSpeed = botTarget:GetCurrentMovementSpeed()
			s.castWalk = X.ScurryCastWalk(botTarget, s.targetDist)
			logDist = s.targetDist
			logTarget = (string.gsub(botTarget:GetUnitName(), "npc_dota_hero_", ""))
			planTarget = botTarget
		end
	end
	local why = X.ScurryReason(s)
	if why == nil then
		return BOT_ACTION_DESIRE_NONE
	end
	-- What the scurry-result line checks: chase reaches attack range, position the cast range of the spell it was
	-- for (the target distance less the walk); escape has no reach (read died= and hp= there).
	local reach = 0
	if why == "chase" then
		reach = s.attackRange
	elseif why == "position" then
		reach = s.targetDist - s.castWalk
	end
	local plan = { why = why, target = planTarget, duration = duration, startDist = logDist, reach = reach }
	if DotaTime() - lastScurryLogAt >= 3 then
		lastScurryLogAt = DotaTime()
		print(
			string.format(
				"[OHA-HOODWINK] t=%.0f hoodwink scurry why=%s charges=%s dist=%d hp=%.2f target=%s speed=%d targetSpeed=%d walk=%d",
				DotaTime(),
				why,
				tostring(s.charges),
				math.floor(logDist),
				hpRatio,
				logTarget,
				math.floor(s.mySpeed),
				math.floor(s.targetSpeed or 0),
				math.floor(s.castWalk or 0)
			)
		)
	end
	return BOT_ACTION_DESIRE_HIGH, plan
end
-- Starts the scurry-result check for the Scurry just ordered (ThinkCastResults prints it when Scurry ends).
function X.StartScurryRun(plan)
	if plan == nil then
		return
	end
	local ready = {}
	for _, spell in ipairs(ScurrySpells()) do
		ready[spell[1]] = spell[2]:IsTrained() and spell[2]:IsCooldownReady()
	end
	scurryRun = {
		why = plan.why,
		target = plan.target,
		startedAt = DotaTime(),
		duration = plan.duration,
		startDist = plan.startDist,
		minDist = plan.startDist >= 0 and plan.startDist or 99999,
		reach = plan.reach,
		ready = ready,
		active = false,
		deaths = GetHeroDeaths(bot:GetPlayerID()),
		hp = hpRatio,
	}
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
--   full-noturn: charged, off the line, and the move orders are not turning her: waiting would only reach the
--     automatic fire;
--   harassed: a hero is hitting her and she is hurt or it stands next to her, after half a second of charge;
--   leaving: the bolt would still reach the target now, but not once the charge is full.
-- Off the line at full charge she keeps turning while that works; the bolt fires by itself at misfire_time.
function X.SharpshooterReleaseReason(charge, maxChargeTime, hasTarget, onLine, harassed, leaving, canTurn)
	if charge >= maxChargeTime and (onLine or not hasTarget) then
		return "full"
	end
	if charge >= maxChargeTime and not canTurn then
		return "full-noturn"
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
		leaving,
		-- Turning works until five move orders have moved her facing by less than 3 degrees.
		windup.reaims < 5 or FacingChange(windup.startFacing, bot:GetFacing()) >= 3
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
