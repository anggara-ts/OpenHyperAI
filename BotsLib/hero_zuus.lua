-- Zuus: skill build, item build, and ability use for this hero.
-- Accidental globals made file-local (#13): every bot shares one Lua state, so these were shared.
local nManaPercentage, nHealthPercentage
local X = {}
local bot = GetBot()
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local AbilityContext = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local Minion = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local sTalentList = Fu.Skill.GetTalentList(bot)
local sAbilityList = Fu.Skill.GetAbilityList(bot)
local sRole = Fu.Item.GetRoleItemsBuyList(bot)
local tTalentTreeList = { ["t25"] = { 0, 10 }, ["t20"] = { 0, 10 }, ["t15"] = { 0, 10 }, ["t10"] = { 10, 0 } }
-- Build 1 (cores): Arc Lightning maxed first, as 41% of mid Zeus do (Lightning Bolt first: 38%; 92,581 matches).
-- Build 2 (pos 4 / 5): Lightning Bolt first (71%), Heavenly Jump at level 2 (74%), Arc Lightning at 4.
-- Stratz, week of 12-18 Nov 2026 (7.41f).
local tAllAbilityBuildList =
	{ { 1, 3, 1, 2, 1, 6, 1, 2, 2, 2, 6, 3, 3, 3, 6 }, { 2, 3, 2, 1, 2, 6, 2, 1, 1, 1, 6, 3, 3, 3, 6 } }
local nAbilityBuildList = tAllAbilityBuildList[1]
if sRole == "pos_2" then
	nAbilityBuildList = tAllAbilityBuildList[1]
end
if sRole == "pos_4" then
	nAbilityBuildList = tAllAbilityBuildList[2]
end
if sRole == "pos_5" then
	nAbilityBuildList = tAllAbilityBuildList[2]
end
local nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList)
if sRole == "pos_2" then
	nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList)
end
if sRole == "pos_4" then
	nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList)
end
if sRole == "pos_5" then
	nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList)
end
local sRoleItemsBuyList = {}
-- Stratz 7.41f, week of 9 Nov 2026: pos 2, 88,819 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_2"] = {
	"item_tango",
	"item_double_branches",
	"item_faerie_fire",
	"item_mantle",
	"item_enchanted_mango",
	"item_null_talisman",
	"item_magic_wand",
	"item_arcane_boots",
	"item_kaya",
	"item_phylactery",
	"item_ultimate_scepter",
	"item_yasha_and_kaya",
	"item_refresher",
	"item_octarine_core",
	"item_ultimate_scepter_2",
	"item_aether_lens",
	"item_aghanims_shard",
	"item_moon_shard",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 3, 3,673 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_3"] = {
	"item_tango",
	"item_branches",
	"item_circlet",
	"item_enchanted_mango",
	"item_mantle",
	"item_null_talisman",
	"item_magic_wand",
	"item_arcane_boots",
	"item_kaya",
	"item_ultimate_scepter",
	"item_yasha_and_kaya",
	"item_refresher",
	"item_octarine_core",
	"item_travel_boots",
	"item_ultimate_scepter_2",
	"item_aether_lens",
	"item_phylactery",
	"item_aghanims_shard",
	"item_moon_shard",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 1, 1,998 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_1"] = {
	"item_tango",
	"item_double_branches",
	"item_circlet",
	"item_magic_stick",
	"item_null_talisman",
	"item_magic_wand",
	"item_arcane_boots",
	"item_yasha_and_kaya",
	"item_dragon_lance",
	"item_ultimate_scepter",
	"item_hurricane_pike",
	"item_refresher",
	"item_octarine_core",
	"item_travel_boots",
	"item_ultimate_scepter_2",
	"item_aether_lens",
	"item_aghanims_shard",
	"item_moon_shard",
	"item_travel_boots_2",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 4, 103,857 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_4"] = {
	"item_tango",
	"item_blood_grenade",
	"item_enchanted_mango",
	"item_magic_stick",
	"item_branches",
	"item_null_talisman",
	"item_magic_wand",
	"item_arcane_boots",
	"item_kaya",
	"item_ultimate_scepter",
	"item_refresher",
	"item_yasha_and_kaya",
	"item_octarine_core",
	"item_travel_boots",
	"item_ultimate_scepter_2",
	"item_aether_lens",
	"item_phylactery",
	"item_aghanims_shard",
	"item_moon_shard",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 5, 58,402 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_5"] = {
	"item_tango",
	"item_blood_grenade",
	"item_enchanted_mango",
	"item_branches",
	"item_magic_stick",
	"item_null_talisman",
	"item_magic_wand",
	"item_arcane_boots",
	"item_kaya",
	"item_ultimate_scepter",
	"item_refresher",
	"item_yasha_and_kaya",
	"item_octarine_core",
	"item_travel_boots",
	"item_ultimate_scepter_2",
	"item_aether_lens",
	"item_phylactery",
	"item_aghanims_shard",
	"item_moon_shard",
}
X["sBuyList"] = sRoleItemsBuyList[sRole]
X["sSellList"] = { "item_black_king_bar", "item_quelling_blade" }
if Fu.Role.IsPvNMode() or Fu.Role.IsAllShadow() then
	X["sBuyList"], X["sSellList"] = { "PvN_mage" }, {}
end
nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"] =
	Fu.SetUserHeroInit(nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"])
X["sSkillList"] = Fu.Skill.GetSkillList(sAbilityList, nAbilityBuildList, sTalentList, nTalentBuildList)
X["bDeafaultAbility"] = false
X["bDeafaultItem"] = true
function X.MinionThink(hMinionUnit)
	if Minion.IsValidUnit(hMinionUnit) and hMinionUnit:GetUnitName() ~= "npc_dota_zeus_cloud" then
		Minion.IllusionThink(hMinionUnit)
	end
end
local arcLightningAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[1]), "sAbilityList[1]", "zuus")
local lightningBoltAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[2]), "sAbilityList[2]", "zuus")
local heavenlyJumpAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[3]), "sAbilityList[3]", "zuus")
-- Nimbus by name: datafeed lists zuus_cloud as Scepter-granted (hidden until then), so slot index 4 isn't reliable.
local nimbusAbility = SafeAbility(bot:GetAbilityByName("zuus_cloud"), "zuus_cloud", "zuus")
local ability5 = SafeAbility(bot:GetAbilityByName(sAbilityList[5]), "sAbilityList[5]", "zuus")
local wrathAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[6]), "sAbilityList[6]", "zuus")
local talent5 = SafeAbility(bot:GetAbilityByName(sTalentList[5]), "sTalentList[5]", "zuus")
local talent7 = SafeAbility(bot:GetAbilityByName(sTalentList[7]), "sTalentList[7]", "zuus")
local talent8 = SafeAbility(bot:GetAbilityByName(sTalentList[8]), "sTalentList[8]", "zuus")
local arcLightningDesire, arcLightningTarget
local lightningBoltDesire, lightningBoltTarget
local lightningBoltAoeDesire, lightningBoltLocation
local nimbusDesire, nimbusLocation
-- Nimbus help, Valve datafeed hero_id=22 (zuus_cloud): cloud_radius 450, cloud_bolt_interval 2.5, AbilityCastPoint
-- 0.2. Fallbacks for when the API reads 0.
local NIMBUS_RADIUS_FALLBACK = 450
local NIMBUS_INTERVAL_FALLBACK = 2.5
-- A fleeing ally is helped while the chaser is at most this many seconds from reaching him (or already hitting
-- him), and not once he is this low: bolts come every 2.5s, too late then (game 064: Alchemist at 1% HP died 4s
-- after the cast, Puck 1s after one).
local NIMBUS_HELP_CATCH_TIME = 4
local NIMBUS_HELP_MIN_HP = 0.15
-- How far from a fleeing ally a chaser is looked for.
local NIMBUS_HELP_CHASER_RANGE = 1200
local nimbusHelpCast = nil -- { why, ally, allyHp, deaths, chaser, at }
local nextNimbusHelpCheckAt = -100
local fleeingAllyCache = { at = -100, list = {} }
local wrathDesire
local heavenlyJumpDesire, heavenlyJumpTarget
local keepMana, mpRatio
local staticFieldPct = 0
local unusedTarget
function X.SkillsComplement()
	-- The nimbus-result line comes before every gate, so it prints while Zeus is busy too.
	pcall(X.ThinkNimbusResult)
	if Fu.CanNotUseAbility(bot) or bot:IsInvisible() then
		return
	end
	local context = AbilityContext.Build(bot)
	keepMana = 400
	staticFieldPct = 0
	mpRatio = context.mp
	nManaPercentage = context.mp
	nHealthPercentage = context.hp
	-- datafeed: Static Field is now an innate (always on), damage_health_pct 3.45% of current health; it was
	-- 0.09 and only when sAbilityList[5] was trained.
	local staticFieldAbility = bot:GetAbilityByName("zuus_static_field")
	if staticFieldAbility ~= nil then
		staticFieldPct = staticFieldAbility:GetSpecialValueFloat("damage_health_pct") / 100
	end
	wrathDesire = X.ConsiderR()
	if wrathDesire > 0 then
		Fu.SetQueuePtToINT(bot, true)
		bot:ActionQueue_UseAbility(wrathAbility)
		return
	end
	lightningBoltDesire, lightningBoltTarget = X.ConsiderW()
	if lightningBoltDesire > 0 then
		Fu.SetQueuePtToINT(bot, true)
		if talent7:IsTrained() then
			bot:ActionQueue_UseAbilityOnLocation(lightningBoltAbility, lightningBoltTarget:GetLocation())
		else
			bot:ActionQueue_UseAbilityOnEntity(lightningBoltAbility, lightningBoltTarget)
		end
		return
	end
	lightningBoltAoeDesire, lightningBoltLocation = X.ConsiderW2()
	if lightningBoltAoeDesire > 0 then
		Fu.SetQueuePtToINT(bot, true)
		bot:ActionQueue_UseAbilityOnLocation(lightningBoltAbility, lightningBoltLocation)
		return
	end
	arcLightningDesire, arcLightningTarget = X.ConsiderQ()
	if arcLightningDesire > 0 then
		Fu.SetQueuePtToINT(bot, true)
		bot:ActionQueue_UseAbilityOnEntity(arcLightningAbility, arcLightningTarget)
		return
	end
	local nimbusWhy, nimbusTarget, nimbusNote
	nimbusDesire, nimbusLocation, nimbusWhy, nimbusTarget, nimbusNote = X.ConsiderD()
	if nimbusDesire > 0 then
		-- One line per cast (45 s cooldown; the 3 s gate only stops repeats when an order doesn't go through).
		if DotaTime() >= (bot._zeusNimbusLogAt or -999) then
			bot._zeusNimbusLogAt = DotaTime() + 3
			pcall(
				print,
				string.format(
					"[OHA-ZEUS] t=%.0f nimbus why=%s target=%s dist=%d%s",
					DotaTime(),
					tostring(nimbusWhy),
					nimbusTarget ~= nil and nimbusTarget:GetUnitName() or "none",
					nimbusTarget ~= nil and math.floor(GetUnitToUnitDistance(bot, nimbusTarget)) or 0,
					nimbusNote or ""
				)
			)
		end
		Fu.SetQueuePtToINT(bot, true)
		bot:ActionQueue_UseAbilityOnLocation(nimbusAbility, nimbusLocation)
		return
	end
	heavenlyJumpDesire = X.ConsiderE()
	if heavenlyJumpDesire > 0 then
		Fu.SetQueuePtToINT(bot, true)
		bot:ActionQueue_UseAbility(heavenlyJumpAbility)
		return
	end
end
function X.ConsiderQ()
	if not arcLightningAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castRange = arcLightningAbility:GetCastRange()
	local castPoint = arcLightningAbility:GetCastPoint()
	local manaCost = arcLightningAbility:GetManaCost()
	local radius = arcLightningAbility:GetSpecialValueInt("radius")
	local damage = arcLightningAbility:GetSpecialValueInt("arc_damage")
	local enemiesInRange = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	for _, enemy in pairs(enemiesInRange) do
		if
			Fu.IsValidHero(enemy)
			and Fu.CanCastOnNonMagicImmune(enemy)
			and Fu.CanCastOnTargetAdvanced(enemy)
			and Fu.GetHP(enemy) <= 0.2
		then
			return BOT_ACTION_DESIRE_HIGH, enemy
		end
	end
	if bot:GetActiveMode() == BOT_MODE_LANING then
		local laneCreeps = bot:GetNearbyLaneCreeps(castRange + 50, true)
		for _, creep in pairs(laneCreeps) do
			if
				Fu.IsValid(creep)
				and not creep:HasModifier("modifier_fountain_glyph")
				and Fu.IsEnemyTargetUnit(creep, 1400)
				and Fu.WillKillTarget(creep, damage, DAMAGE_TYPE_MAGICAL, castPoint)
			then
				for _, enemy in pairs(Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE) or {}) do
					if Fu.IsValidHero(enemy) and GetUnitToUnitDistance(creep, enemy) < 500 then
						return BOT_ACTION_DESIRE_HIGH, creep, "Q补刀+弹射"
					end
				end
				return BOT_ACTION_DESIRE_HIGH, creep
			end
		end
		if mpRatio > 0.4 then
			local enemiesInRange = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
			for _, enemy in pairs(enemiesInRange or {}) do
				if
					Fu.IsValidHero(enemy)
					and Fu.CanCastOnNonMagicImmune(enemy)
					and Fu.GetHP(enemy) < 0.75
					and not Fu.IsRetreating(bot)
				then
					return BOT_ACTION_DESIRE_HIGH, enemy, "Q对线消耗"
				end
			end
		end
	end
	if Fu.IsRetreating(bot) and bot:WasRecentlyDamagedByAnyHero(2.0) then
		local target = Fu.GetVulnerableWeakestUnit(bot, true, true, castRange)
		if target ~= nil and Fu.CanCastOnTargetAdvanced(target) and bot:IsFacingLocation(target:GetLocation(), 45) then
			return BOT_ACTION_DESIRE_HIGH, target
		end
	end
	if Fu.IsInTeamFight(bot, 1300) then
		local aoe = bot:FindAoELocation(true, true, bot:GetLocation(), castRange, radius, 0, 0)
		if aoe.count >= 2 then
			local target = Fu.GetVulnerableUnitNearLoc(bot, true, true, castRange, radius, aoe.targetloc)
			if target ~= nil and Fu.CanCastOnTargetAdvanced(target) then
				return BOT_ACTION_DESIRE_HIGH, target
			end
		end
	end
	if (Fu.IsPushing(bot) or Fu.IsDefending(bot)) and Fu.IsAllowedToSpam(bot, manaCost) then
		local aoe = bot:FindAoELocation(true, false, bot:GetLocation(), castRange, radius, 0, 0)
		if aoe.count >= 3 then
			local target = Fu.GetVulnerableUnitNearLoc(bot, false, true, castRange, radius, aoe.targetloc)
			if target ~= nil then
				return BOT_ACTION_DESIRE_HIGH, target
			end
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		local target = Fu.GetProperTarget(bot)
		if
			Fu.IsValidHero(target)
			and Fu.CanCastOnNonMagicImmune(target)
			and Fu.CanCastOnTargetAdvanced(target)
			and Fu.IsInRange(target, bot, castRange)
		then
			return BOT_ACTION_DESIRE_HIGH, target
		end
	end
	if Fu.IsFarming(bot) and Fu.GetManaAfter(manaCost) > 0.3 then
		local neutralCreeps = bot:GetNearbyNeutralCreeps(castRange)
		if
			#neutralCreeps >= 2
			or #neutralCreeps >= 1 and Fu.IsValid(neutralCreeps[1]) and neutralCreeps[1]:IsAncientCreep()
		then
			return BOT_ACTION_DESIRE_HIGH, neutralCreeps[1]
		end
		local laneCreeps = bot:GetNearbyLaneCreeps(castRange, true)
		if #laneCreeps >= 3 then
			return BOT_ACTION_DESIRE_HIGH, laneCreeps[1]
		end
	end
	if Fu.IsDoingRoshan(bot) then
		local roshan = Fu.GetProperTarget(bot)
		if Fu.IsRoshan(roshan) and Fu.IsInRange(bot, roshan, castRange) and Fu.GetManaAfter(manaCost) > 0.3 then
			return BOT_ACTION_DESIRE_HIGH, roshan
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function X.ConsiderW()
	if not lightningBoltAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castRange = lightningBoltAbility:GetCastRange()
	local castPoint = lightningBoltAbility:GetCastPoint()
	local manaCost = lightningBoltAbility:GetManaCost()
	-- datafeed: Lightning Bolt damage is the "damage" value (140/220/300/380); it has no AbilityDamage (read 0).
	local damage = lightningBoltAbility:GetSpecialValueInt("damage") * (1 + bot:GetSpellAmp())
	if Fu.IsRetreating(bot) and bot:WasRecentlyDamagedByAnyHero(2.0) then
		local target = Fu.GetVulnerableWeakestUnit(bot, true, true, castRange)
		if target ~= nil and Fu.CanCastOnTargetAdvanced(target) then
			return BOT_ACTION_DESIRE_HIGH, target
		end
	end
	-- A fleeing ally whose chaser Zeus's own bolt reaches (no walk): the bolt is a sure hit with a mini-stun
	-- (ministun_duration 0.35, datafeed hero_id=22), cheaper than Nimbus, whose bolt may go to another unit.
	for _, flee in ipairs(X.FleeingAllyChasers()) do
		if
			(flee.hitting or flee.catchTime <= NIMBUS_HELP_CATCH_TIME)
			and GetUnitToUnitDistance(bot, flee.chaser) <= castRange
			and Fu.CanCastOnTargetAdvanced(flee.chaser)
		then
			if DotaTime() >= (bot._zeusBoltHelpLogAt or -999) then
				bot._zeusBoltHelpLogAt = DotaTime() + 3
				print(
					string.format(
						"[OHA-ZEUS] t=%.0f zuus bolt-help ally=%s allyHp=%.2f chaser=%s dist=%d catch=%.1f",
						DotaTime(),
						flee.ally:GetUnitName(),
						Fu.GetHP(flee.ally),
						flee.chaser:GetUnitName(),
						math.floor(GetUnitToUnitDistance(bot, flee.chaser)),
						flee.catchTime
					)
				)
			end
			return BOT_ACTION_DESIRE_HIGH, flee.chaser
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		local target = Fu.GetProperTarget(bot)
		if
			Fu.IsValidHero(target)
			and Fu.CanCastOnNonMagicImmune(target)
			and Fu.CanCastOnTargetAdvanced(target)
			and Fu.IsInRange(target, bot, castRange)
		then
			return BOT_ACTION_DESIRE_HIGH, target
		end
	end
	local rangedCreep = X.GetRanged(bot, castRange)
	if
		rangedCreep ~= nil
		and rangedCreep:GetHealth()
			< rangedCreep:GetActualIncomingDamage(
				damage + rangedCreep:GetHealth() * staticFieldPct,
				DAMAGE_TYPE_MAGICAL
			)
	then
		return BOT_ACTION_DESIRE_HIGH, rangedCreep
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function X.ConsiderW2()
	if not lightningBoltAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castRange = lightningBoltAbility:GetCastRange()
	local castPoint = lightningBoltAbility:GetCastPoint()
	local manaCost = lightningBoltAbility:GetManaCost()
	local damage = lightningBoltAbility:GetSpecialValueInt("damage") -- datafeed: Lightning Bolt "damage"; no AbilityDamage (read 0)
	local radius = 325
	local nearbyAllies = Fu.GetNearbyHeroes(bot, 800, false, BOT_MODE_NONE)
	local enemiesInRange = Fu.GetNearbyHeroes(bot, castRange + radius, true, BOT_MODE_NONE)
	local weakestEnemy = Fu.GetVulnerableWeakestUnit(bot, true, true, castRange + radius)
	local aoe = bot:FindAoELocation(true, true, bot:GetLocation(), castRange, radius, 0.3, damage)
	if aoe.count >= 1 then
		if Fu.IsValid(weakestEnemy) then
			local castLocation = Fu.GetCastLocation(bot, weakestEnemy, castRange, radius)
			if castLocation ~= nil then
				return BOT_ACTION_DESIRE_HIGH, castLocation
			end
		end
	end
	for _, enemy in pairs(enemiesInRange) do
		if Fu.IsValid(enemy) and enemy:IsChanneling() and not enemy:IsMagicImmune() then
			local castLocation = Fu.GetCastLocation(bot, enemy, castRange, radius)
			if castLocation ~= nil then
				return BOT_ACTION_DESIRE_HIGH, castLocation
			end
		end
	end
	if bot:GetActiveMode() == BOT_MODE_RETREAT and (bot:WasRecentlyDamagedByAnyHero(2.0) or #nearbyAllies >= 3) then
		local aoe = bot:FindAoELocation(true, true, bot:GetLocation(), castRange - 200, radius - 20, 0.8, 0)
		if aoe.count >= 1 then
			return BOT_ACTION_DESIRE_HIGH, aoe.targetloc
		end
	end
	if bot:GetActiveMode() ~= BOT_MODE_RETREAT then
		local target = Fu.GetProperTarget(bot)
		if
			Fu.IsValidHero(target)
			and Fu.CanCastOnNonMagicImmune(target)
			and GetUnitToUnitDistance(target, bot) <= radius + castRange
		then
			if nManaPercentage > 0.65 or bot:GetMana() > keepMana * 2 then
				local castLocation = Fu.GetCastLocation(bot, target, castRange, radius)
				if castLocation ~= nil then
					return BOT_ACTION_DESIRE_HIGH, castLocation
				end
			end
			if target:GetHealth() / target:GetMaxHealth() < 0.45 or #nearbyAllies >= 3 then
				local castLocation = Fu.GetCastLocation(bot, target, castRange, radius)
				if castLocation ~= nil then
					return BOT_ACTION_DESIRE_HIGH, castLocation
				end
			end
		end
		local target = weakestEnemy
		if
			Fu.IsValid(target)
			and DotaTime() > 0
			and (target:GetHealth() / target:GetMaxHealth() < 0.4 or bot:GetMana() > keepMana * 2.3 or #nearbyAllies >= 3)
			and GetUnitToUnitDistance(target, bot) <= radius + castRange
		then
			local castLocation = Fu.GetCastLocation(bot, target, castRange, radius)
			if castLocation ~= nil then
				return BOT_ACTION_DESIRE_HIGH, castLocation
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
-- Pure: seconds until a chaser reaches attack range of the unit he chases. gap: the distance less his attack range;
-- awaySpeed: how fast the chased unit moves straight away from him (negative: toward him). 0 when in range now,
-- 99 when he does not gain.
function X.CatchTime(gap, chaserSpeed, awaySpeed)
	if gap <= 0 then
		return 0
	end
	local closing = chaserSpeed - math.max(0, awaySpeed)
	if closing <= 10 then
		return 99
	end
	return gap / closing
end
-- Pure: where Nimbus goes to slow a chaser, or nil and why not. c holds plain numbers and points ({x, y}):
--   chaser, ally: positions; chaserSpeed; allyHp; allyFleeing (the ally moves away from the chaser); catchTime
--   (seconds until the chaser reaches the ally); hitting (he hit the ally lately); inBoltRange, boltReady (Zeus's own Lightning Bolt
--   reaches him now); units: the other enemy units that a bolt could hit instead (creeps, summons, illusions; no
--   heroes, wards or buildings); radius, interval, castPoint (Nimbus).
-- The cloud goes on the chaser's path toward the ally, at the point he reaches having walked one radius past where
-- he stands when the cloud forms, so he crosses all of it while he follows a fleeing ally: inside for 2 x radius /
-- speed seconds. An ally who is not moving away is where the chaser stops to fight: the cloud goes on the ally's
-- spot then (or the chaser's, if nearer), and the chaser stays in it. He must stay in for one bolt interval. The Dota 2 wiki (not the game files) says a Nimbus bolt strikes the closest enemy unit,
-- creeps and summons included, with no hero priority, so any other enemy unit inside the cloud (nearer the centre
-- than the chaser for most of his walk) can take the bolt: then no cast.
-- Returns plan { aim = {x, y}, crowd, stay }, or nil, why, plan.
function X.NimbusHelpPlan(c)
	if c.allyHp < NIMBUS_HELP_MIN_HP then
		return nil, "too-late"
	end
	if not c.hitting and c.catchTime > NIMBUS_HELP_CATCH_TIME then
		return nil, "not-yet"
	end
	if c.inBoltRange and c.boltReady then
		return nil, "bolt-range"
	end
	local dx, dy = c.ally.x - c.chaser.x, c.ally.y - c.chaser.y
	local gap = math.sqrt(dx * dx + dy * dy)
	local plan = { aim = { x = c.chaser.x, y = c.chaser.y }, crowd = 0, stay = math.huge }
	if c.chaserSpeed >= 50 and gap >= 1 then
		local formWalk = c.chaserSpeed * c.castPoint
		local along = formWalk + c.radius
		if not c.allyFleeing then
			along = math.min(along, gap)
		end
		plan.aim = { x = c.chaser.x + dx / gap * along, y = c.chaser.y + dy / gap * along }
		plan.stay = c.allyFleeing and (along + c.radius - formWalk) / c.chaserSpeed or math.huge
	end
	for _, unit in ipairs(c.units or {}) do
		local ux, uy = unit.x - plan.aim.x, unit.y - plan.aim.y
		if ux * ux + uy * uy <= c.radius * c.radius then
			plan.crowd = plan.crowd + 1
		end
	end
	if plan.stay < c.interval then
		return nil, "too-fast", plan
	end
	if plan.crowd > 0 then
		return nil, "crowded", plan
	end
	return plan
end
-- Allied heroes (not Zeus) fleeing from an enemy hero: retreating, or under 50% HP and hit by a hero in the last 2s,
-- with a chaser within NIMBUS_HELP_CHASER_RANGE that runs after him or hit him. { ally, chaser, catchTime,
-- hitting } each; read once per think (ConsiderW and ConsiderD both use it).
function X.FleeingAllyChasers()
	if fleeingAllyCache.at == DotaTime() then
		return fleeingAllyCache.list
	end
	local list = {}
	-- Slot loop (GetTeamMember takes a slot 1..5, not a player ID).
	for i = 1, 5 do
		local ally = GetTeamMember(i)
		if
			ally ~= bot
			and Fu.IsValidHero(ally)
			and (Fu.IsRetreating(ally) or Fu.GetHP(ally) < 0.5 and ally:WasRecentlyDamagedByAnyHero(2.0))
		then
			local allyLocation = ally:GetLocation()
			for _, chaser in pairs(Fu.GetEnemiesNearLoc(allyLocation, NIMBUS_HELP_CHASER_RANGE) or {}) do
				local hitting = Fu.IsValidHero(chaser) and ally:WasRecentlyDamagedByHero(chaser, 2.0)
				if
					Fu.IsValidHero(chaser)
					and not Fu.IsSuspiciousIllusion(chaser)
					and Fu.CanCastOnNonMagicImmune(chaser)
					and (hitting or Fu.IsChasingTarget(chaser, ally))
				then
					local chaserLocation = chaser:GetLocation()
					local dx, dy = allyLocation.x - chaserLocation.x, allyLocation.y - chaserLocation.y
					local gap = math.sqrt(dx * dx + dy * dy)
					local velocity = ally:GetVelocity()
					local awaySpeed = gap >= 1 and (velocity.x * dx + velocity.y * dy) / gap or 0
					table.insert(list, {
						ally = ally,
						chaser = chaser,
						hitting = hitting,
						fleeing = awaySpeed > 50,
						catchTime = X.CatchTime(
							gap - chaser:GetAttackRange(),
							chaser:GetCurrentMovementSpeed(),
							awaySpeed
						),
					})
				end
			end
		end
	end
	fleeingAllyCache = { at = DotaTime(), list = list }
	return list
end
-- Other enemy units a Nimbus bolt near location could strike: creeps and summons and illusions, not heroes, wards
-- or buildings. Only what Zeus's team sees is listed, so an unseen creep can still take a bolt.
local function NimbusCrowdUnits(location, radius)
	local units = {}
	for _, unit in pairs(GetUnitList(UNIT_LIST_ENEMIES) or {}) do
		if
			Fu.IsValid(unit)
			and GetUnitToLocationDistance(unit, location) <= radius + 600
			and not unit:IsBuilding()
			and (not unit:IsHero() or unit:IsIllusion())
			and not string.find(unit:GetUnitName(), "ward", 1, true)
		then
			local unitLocation = unit:GetLocation()
			table.insert(units, { x = unitLocation.x, y = unitLocation.y })
		end
	end
	return units
end
-- The NimbusHelpPlan input for a fleeing ally's chaser.
local function NimbusHelpInput(chased, chaser, catchTime, hitting, fleeing)
	local radius = nimbusAbility:GetSpecialValueInt("cloud_radius")
	local interval = nimbusAbility:GetSpecialValueFloat("cloud_bolt_interval")
	radius = radius > 0 and radius or NIMBUS_RADIUS_FALLBACK
	interval = interval > 0 and interval or NIMBUS_INTERVAL_FALLBACK
	local chaserLocation, chasedLocation = chaser:GetLocation(), chased:GetLocation()
	return {
		chaser = { x = chaserLocation.x, y = chaserLocation.y },
		ally = { x = chasedLocation.x, y = chasedLocation.y },
		chaserSpeed = chaser:GetCurrentMovementSpeed(),
		allyHp = Fu.GetHP(chased),
		allyFleeing = fleeing,
		catchTime = catchTime,
		hitting = hitting,
		inBoltRange = GetUnitToUnitDistance(bot, chaser) <= lightningBoltAbility:GetCastRange(),
		boltReady = lightningBoltAbility:IsFullyCastable(),
		units = NimbusCrowdUnits(chaserLocation, radius),
		radius = radius,
		interval = interval,
		castPoint = nimbusAbility:GetCastPoint(),
	}
end
local function LogNimbusSkip(why, chased, chaser, plan)
	if why == "not-yet" or DotaTime() < (bot._zeusNimbusSkipLogAt or -999) then
		return
	end
	bot._zeusNimbusSkipLogAt = DotaTime() + 5
	print(
		string.format(
			"[OHA-ZEUS] t=%.0f zuus nimbus-skip why=%s ally=%s allyHp=%.2f chaser=%s units=%d stay=%.1f",
			DotaTime(),
			why,
			chased:GetUnitName(),
			Fu.GetHP(chased),
			chaser:GetUnitName(),
			plan ~= nil and plan.crowd or 0,
			plan ~= nil and math.min(plan.stay, 99) or 0
		)
	)
end
-- Remembers a help cast for the nimbus-result line 5s later (kept while an earlier order has not gone through).
local function RecordNimbusHelp(why, chased, chaser)
	if nimbusHelpCast ~= nil and not nimbusAbility:IsCooldownReady() then
		return
	end
	nimbusHelpCast = {
		why = why,
		ally = chased,
		allyHp = Fu.GetHP(chased),
		deaths = GetHeroDeaths(chased:GetPlayerID()),
		chaser = chaser,
		at = DotaTime(),
	}
end
-- Five seconds after a help cast: is the ally alive (his death count, so it holds while Zeus is dead too)?
function X.ThinkNimbusResult()
	local cast = nimbusHelpCast
	if cast == nil or DotaTime() < cast.at + 5 then
		return
	end
	nimbusHelpCast = nil
	local died = Fu.IsValid(cast.ally) and GetHeroDeaths(cast.ally:GetPlayerID()) > cast.deaths
	print(
		string.format(
			"[OHA-ZEUS] t=%.0f zuus nimbus-result why=%s ally=%s alive=%s allyHp=%.2f->%.2f chaser=%s chaserHp=%.2f cast=%s late=%.0f",
			DotaTime(),
			cast.why,
			Fu.IsValid(cast.ally) and cast.ally:GetUnitName() or "none",
			tostring(not died),
			cast.allyHp,
			Fu.IsValid(cast.ally) and Fu.GetHP(cast.ally) or 0,
			Fu.IsValid(cast.chaser) and cast.chaser:GetUnitName() or "none",
			Fu.IsValid(cast.chaser) and Fu.GetHP(cast.chaser) or 0,
			tostring(not nimbusAbility:IsCooldownReady()),
			DotaTime() - cast.at - 5
		)
	)
end
-- Nimbus (zuus_cloud, Scepter-granted), npc_abilities 7.42: AbilityCastRange 0 (global), AbilityCastPoint 0.2,
-- cloud_radius 450, cloud_bolt_interval 2.5, cloud_duration 30, cooldown 45, mana 275. The file has no
-- separate cloud-forming delay. The ally-flee case aims with NimbusHelpPlan; Zeus's own retreat, the finish and the
-- fight lead the target by 1 s (cast point plus the first bolt's wait).
-- Returns desire, location, why, target, note (extra log fields).
function X.ConsiderD()
	if not bot:HasScepter() or not nimbusAbility:IsFullyCastable() or bot:IsInvisible() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	-- Order: the flee cases first, then the finish, then an ally's fight. An ally going on someone matches in
	-- almost any fight, so checked first it left no 45 s cooldown for the flee cases. The ally-flee case reads every
	-- enemy unit near the chaser, so it runs a few times a second, not every think.
	local fleeCheck = DotaTime() >= nextNimbusHelpCheckAt
	if fleeCheck then
		nextNimbusHelpCheckAt = DotaTime() + 0.3
	end
	if Fu.IsRetreating(bot) then
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE)
		for _, enemy in pairs(nearbyEnemies) do
			if Fu.IsValid(enemy) and bot:WasRecentlyDamagedByHero(enemy, 1.0) and Fu.CanCastOnNonMagicImmune(enemy) then
				-- The bolt strikes an enemy within cloud_radius (450) of the cloud and mini-stuns it. On Zeus's
				-- own spot it misses a chaser more than 450 away, so the cloud goes where the chaser will be.
				return BOT_ACTION_DESIRE_HIGH, enemy:GetExtrapolatedLocation(1.0), "retreat", enemy
			end
		end
	end
	-- Ally flee (maintainer, 2026-11-20 and after game 064): an allied hero fleeing from an enemy hero gets the cloud
	-- on the chaser's path while the chaser is still a few seconds from him, not when he is nearly dead; Zeus's own
	-- bolt goes first when it reaches the chaser (ConsiderW).
	if fleeCheck then
		for _, flee in ipairs(X.FleeingAllyChasers()) do
			local plan, why, skipped =
				X.NimbusHelpPlan(NimbusHelpInput(flee.ally, flee.chaser, flee.catchTime, flee.hitting, flee.fleeing))
			if plan ~= nil then
				RecordNimbusHelp("ally-flee", flee.ally, flee.chaser)
				if DotaTime() >= (bot._zeusNimbusHelpLogAt or -999) then
					bot._zeusNimbusHelpLogAt = DotaTime() + 3
					print(
						string.format(
							"[OHA-ZEUS] t=%.0f zuus nimbus-help ally=%s allyHp=%.2f chaser=%s crowd=%d stay=%.1f catch=%.1f hitting=%s",
							DotaTime(),
							flee.ally:GetUnitName(),
							Fu.GetHP(flee.ally),
							flee.chaser:GetUnitName(),
							plan.crowd,
							math.min(plan.stay, 99),
							flee.catchTime,
							tostring(flee.hitting)
						)
					)
				end
				return BOT_ACTION_DESIRE_HIGH,
					Vector(plan.aim.x, plan.aim.y, flee.chaser:GetLocation().z),
					"ally-flee",
					flee.chaser,
					string.format(" ally=%s allyHp=%.2f", flee.ally:GetUnitName(), Fu.GetHP(flee.ally))
			end
			LogNimbusSkip(why, flee.ally, flee.chaser, skipped)
		end
	end
	-- Finish (#47): the range is global, so also a low or fleeing enemy hero anywhere on the map, while Zeus is
	-- not in danger himself.
	local zeusInDanger = bot:WasRecentlyDamagedByAnyHero(2.0)
		or #(Fu.GetNearbyHeroes(bot, 900, true, BOT_MODE_NONE) or {}) >= 1
	if not zeusInDanger and not Fu.IsRetreating(bot) then
		local finishTarget = X.NimbusFinishTarget()
		if finishTarget ~= nil then
			return BOT_ACTION_DESIRE_HIGH, finishTarget:GetExtrapolatedLocation(1.0), "finish", finishTarget
		end
	end
	-- An ally's fight last, and held while Zeus or a hurt ally there may soon need it to flee (NimbusFightHold).
	-- Slot loop (GetTeamMember takes a slot 1..5, not a player ID).
	for i = 1, 5 do
		local teamMember = GetTeamMember(i)
		if Fu.IsValid(teamMember) and Fu.IsGoingOnSomeone(teamMember) then
			local target = Fu.GetProperTarget(teamMember)
			if
				Fu.IsValidHero(target)
				and Fu.IsInRange(teamMember, target, 1200)
				and Fu.CanCastOnNonMagicImmune(target)
			then
				local targetLoc = target:GetLocation()
				local lowestAllyHp = 1
				for _, ally in pairs(Fu.GetAlliesNearLoc(targetLoc, 1200) or {}) do
					if ally ~= bot and Fu.IsValidHero(ally) then
						lowestAllyHp = math.min(lowestAllyHp, Fu.GetHP(ally))
					end
				end
				local zeusDist = GetUnitToLocationDistance(bot, targetLoc)
				local hold = X.NimbusFightHold(zeusDist, lowestAllyHp, Fu.GetHP(target))
				if hold == nil then
					return BOT_ACTION_DESIRE_HIGH, target:GetExtrapolatedLocation(1.0), "ally-fight", target
				end
				if DotaTime() >= (bot._zeusNimbusHoldLogAt or -999) then
					bot._zeusNimbusHoldLogAt = DotaTime() + 10
					pcall(
						print,
						string.format(
							"[OHA-ZEUS] t=%.0f nimbus-hold why=%s target=%s targetHp=%.2f zeusDist=%d allyHp=%.2f",
							DotaTime(),
							hold,
							target:GetUnitName(),
							Fu.GetHP(target),
							math.floor(zeusDist),
							lowestAllyHp
						)
					)
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
-- Pure: why Nimbus is kept for later in an ally's fight, or nil to cast it now. Game 063: 15 of 18 casts were
-- ally-fight, and every Zeus death after the Scepter came 7-14 s after one, with Nimbus on cooldown as he fled.
-- So with Zeus himself within 1200 of the fight, or an ally there under 50% HP (both may need the cloud on a
-- chaser soon), it waits, unless the target is already under 50% (then the bolts may finish it).
function X.NimbusFightHold(zeusDist, lowestAllyHp, targetHp)
	if targetHp < 0.5 then
		return nil
	end
	if zeusDist <= 1200 then
		return "zeus-near"
	end
	if lowestAllyHp < 0.5 then
		return "ally-low"
	end
	return nil
end
-- A visible enemy hero under 25% HP, or under 50% and fleeing from an allied hero that chases it (a walking
-- enemy alone is not worth a 275-mana, 45 s spell).
function X.NimbusFinishTarget()
	local best, bestHp = nil, math.huge
	for _, enemy in pairs(GetUnitList(UNIT_LIST_ENEMY_HEROES) or {}) do
		if
			Fu.IsValidHero(enemy)
			and enemy:CanBeSeen()
			and not enemy:HasModifier("modifier_fountain_aura_buff")
			and not Fu.IsSuspiciousIllusion(enemy)
			and Fu.CanCastOnNonMagicImmune(enemy)
		then
			local hp = Fu.GetHP(enemy)
			local fleeing = false
			if hp < 0.5 then
				for _, ally in pairs(Fu.GetAlliesNearLoc(enemy:GetLocation(), 1200) or {}) do
					if
						Fu.IsValidHero(ally)
						and (Fu.IsChasingTarget(ally, enemy) or enemy:WasRecentlyDamagedByHero(ally, 2.0))
					then
						fleeing = true
						break
					end
				end
			end
			if (hp < 0.25 or fleeing) and hp < bestHp then
				best, bestHp = enemy, hp
			end
		end
	end
	return best
end
function X.ConsiderR()
	if not wrathAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
	end
	local castRange = 1600
	local castPoint = wrathAbility:GetCastPoint()
	local manaCost = wrathAbility:GetManaCost()
	-- The +damage talent was read from sTalentList[5], which in the current talent order
	-- (Ability10..17) is special_bonus_unique_zeus_2 (+60 Arc Lightning), not the Wrath talent
	-- (special_bonus_unique_zeus_4, +75). Not added any more. The +75 is linked inside Wrath's
	-- "damage" value, so GetSpecialValueInt("damage") may already include it (not verified).
	local damage = wrathAbility:GetSpecialValueInt("damage")
	local damageType = DAMAGE_TYPE_MAGICAL
	if Fu.IsRetreating(bot) and bot:WasRecentlyDamagedByAnyHero(2.0) then
		if bot:GetRespawnTime() > wrathAbility:GetCooldown() and nHealthPercentage <= 0.28 then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsInTeamFight(bot, 1400) then
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, 1400, true, BOT_MODE_NONE)
		local visibleEnemyCount = Fu.GetInvUnitCount(false, nearbyEnemies)
		-- Was 5 visible enemies within 1400: in real fights (3v3, 4v4) Wrath stayed unused unless
		-- it killed someone outright. Now 3.
		if visibleEnemyCount >= 3 then
			if DotaTime() >= (bot._zeusWrathLogAt or -999) then
				bot._zeusWrathLogAt = DotaTime() + 5
				pcall(print, string.format("[OHA-ZEUS] t=%.0f wrath-fight enemies=%d", DotaTime(), visibleEnemyCount))
			end
			return BOT_ACTION_DESIRE_MODERATE
		end
	end
	local killableCount = 0
	local fatalBondsCount = 0
	local canKillBonded = false
	local enemyHeroes = GetUnitList(UNIT_LIST_ENEMY_HEROES)
	for _, enemy in pairs(enemyHeroes) do
		if enemy ~= nil and Fu.CanCastOnNonMagicImmune(enemy) then
			local totalDamage = damage + enemy:GetHealth() * staticFieldPct
			if
				Fu.WillMagicKillTarget(bot, enemy, totalDamage, castPoint)
				and not Fu.IsOtherAllyCanKillTarget(bot, enemy)
			then
				killableCount = killableCount + 1
			end
			if enemy:HasModifier("modifier_warlock_fatal_bonds") then
				fatalBondsCount = fatalBondsCount + 1
				if enemy:GetHealth() <= enemy:GetActualIncomingDamage(totalDamage * 2.28, damageType) then
					canKillBonded = true
				end
			end
		end
	end
	if killableCount >= 1 or fatalBondsCount >= 3 and canKillBonded == true then
		return BOT_ACTION_DESIRE_MODERATE
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.GetRanged(bot, castRange)
	local botMode = bot:GetActiveMode()
	local nearbyEnemies = Fu.GetNearbyHeroes(bot, 1400, true, BOT_MODE_NONE)
	local nearbyAllies = Fu.GetNearbyHeroes(bot, 800, false, BOT_MODE_NONE)
	if
		botMode == BOT_MODE_TEAM_ROAM
		or botMode == BOT_MODE_ATTACK
		or botMode == BOT_MODE_DEFEND_ALLY
		or botMode == BOT_MODE_RETREAT
		or #nearbyEnemies >= 1
		or #nearbyAllies >= 3
		or nManaPercentage <= 0.15
		or bot:WasRecentlyDamagedByAnyHero(2.0)
	then
		return nil
	end
	if botMode == BOT_MODE_LANING or nManaPercentage >= 0.56 then
		local allyTowers = bot:GetNearbyTowers(1600, false)
		if allyTowers[1] ~= nil then
			local towerTarget = allyTowers[1]:GetAttackTarget()
			if
				Fu.IsValid(towerTarget)
				and not towerTarget:HasModifier("modifier_fountain_glyph")
				and Fu.IsKeyWordUnit("ranged", towerTarget)
				and GetUnitToUnitDistance(towerTarget, bot) <= 1400
				and not Fu.IsAllysTarget(towerTarget)
			then
				return towerTarget
			end
		end
		if nManaPercentage > 0.4 and bot:GetMana() > 400 then
			local laneCreeps = bot:GetNearbyLaneCreeps(990, true)
			for _, creep in pairs(laneCreeps) do
				if
					Fu.IsValid(creep)
					and Fu.IsKeyWordUnit("ranged", creep)
					and not creep:HasModifier("modifier_fountain_glyph")
					and not Fu.IsAllysTarget(creep)
					and creep:GetHealth() < bot:GetAttackDamage()
				then
					return creep
				end
			end
		end
	end
	return nil
end
-- Heavenly Jump, datafeed hero 22 (7.42): Zeus hops hop_distance 375/450/525/600 forward (the way he faces) and
-- shocks the closest visible enemy within range 700/800/900/1000 (80% move slow, 1.4 s).
-- How far around the landing spot heroes count for "outnumbered", and for "next to" the landing spot.
local JUMP_AREA_RADIUS = 1200
local JUMP_NEXT_TO_RADIUS = 500
-- Pure: why an engage jump would be wrong, or nil. Ally counts include Zeus. Game 063, 15:38: he jumped into
-- four enemies with no ally near and died.
function X.JumpEngageProblem(targetAhead, enemiesArea, alliesArea, enemiesNextTo, alliesNextTo)
	if not targetAhead then
		return "not-ahead"
	end
	if enemiesArea > alliesArea then
		return "outnumbered"
	end
	if enemiesNextTo > alliesNextTo then
		return "landing-crowded"
	end
	return nil
end
local function CountAlliesNear(location, radius)
	local count = 1 -- Zeus lands there
	for _, ally in pairs(Fu.GetAlliesNearLoc(location, radius) or {}) do
		if ally ~= bot and Fu.IsValidHero(ally) then
			count = count + 1
		end
	end
	return count
end
local function LogJump(kind, why, target, enemies, allies)
	local key = kind == "jump" and "_zeusJumpLogAt" or "_zeusJumpSkipLogAt"
	if DotaTime() < (bot[key] or -999) then
		return
	end
	bot[key] = DotaTime() + 5
	pcall(
		print,
		string.format(
			"[OHA-ZEUS] t=%.0f %s why=%s target=%s enemies=%d allies=%d",
			DotaTime(),
			kind,
			why,
			target ~= nil and target:GetUnitName() or "none",
			enemies,
			allies
		)
	)
end
function X.ConsiderE()
	if not heavenlyJumpAbility:IsFullyCastable() or bot:IsRooted() then
		return BOT_ACTION_DESIRE_NONE
	end
	local abilityLevel = heavenlyJumpAbility:GetLevel()
	local castRange = heavenlyJumpAbility:GetSpecialValueInt("range")
	if castRange <= 0 then
		castRange = 600 + abilityLevel * 100
	end
	local hopDistance = heavenlyJumpAbility:GetSpecialValueInt("hop_distance")
	if hopDistance <= 0 then
		hopDistance = 300 + abilityLevel * 75
	end
	local nearbyEnemies = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	if Fu.IsRetreating(bot) then
		if Fu.IsRunning(bot) then
			local enemy = nearbyEnemies[1]
			if
				Fu.IsValidHero(enemy)
				and Fu.CanCastOnNonMagicImmune(enemy)
				and not bot:IsFacingLocation(enemy:GetLocation(), 120)
			then
				LogJump("jump", "retreat", enemy, #nearbyEnemies, CountAlliesNear(bot:GetLocation(), JUMP_AREA_RADIUS))
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		local target = Fu.GetProperTarget(bot)
		if Fu.IsValidHero(target) and Fu.IsInRange(bot, target, castRange) and Fu.CanCastOnNonMagicImmune(target) then
			local landing = Fu.GetFaceTowardDistanceLocation(bot, hopDistance)
			local enemiesArea = #(Fu.GetEnemiesNearLoc(landing, JUMP_AREA_RADIUS) or {})
			local alliesArea = CountAlliesNear(landing, JUMP_AREA_RADIUS)
			local problem = X.JumpEngageProblem(
				bot:IsFacingLocation(target:GetLocation(), 45),
				enemiesArea,
				alliesArea,
				#(Fu.GetEnemiesNearLoc(landing, JUMP_NEXT_TO_RADIUS) or {}),
				CountAlliesNear(landing, JUMP_NEXT_TO_RADIUS)
			)
			if problem == nil then
				LogJump("jump", "engage", target, enemiesArea, alliesArea)
				return BOT_ACTION_DESIRE_HIGH
			end
			LogJump("jump-skip", problem, target, enemiesArea, alliesArea)
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
return X
