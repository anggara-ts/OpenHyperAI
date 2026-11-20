-- Dawnbreaker: skill build, item build, and ability use for this hero.
-- Accidental globals made file-local (#13): every bot shares one Lua state, so these were shared.
local IsTargetLocInBigUlt, CanBKB
local X = {}
local bot = GetBot()
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local AbilityContext = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local Minion = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local sTalentList = Fu.Skill.GetTalentList(bot)
local sAbilityList = Fu.Skill.GetAbilityList(bot)
local sRole = Fu.Item.GetRoleItemsBuyList(bot)
local tTalentTreeList = { ["t25"] = { 0, 10 }, ["t20"] = { 10, 0 }, ["t15"] = { 0, 10 }, ["t10"] = { 0, 10 } }
local tAllAbilityBuildList = { { 2, 1, 2, 3, 2, 6, 2, 1, 1, 1, 6, 3, 3, 3, 6 } }
local nAbilityBuildList = Fu.Skill.GetRandomBuild(tAllAbilityBuildList)
local nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList)
local sRoleItemsBuyList = {}
-- Stratz 7.41f, week of 9 Nov 2026: pos 3, 157,821 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_3"] = {
	"item_tango",
	"item_double_gauntlets",
	"item_double_branches",
	"item_quelling_blade",
	"item_bracer",
	"item_magic_wand",
	"item_soul_ring",
	"item_phase_boots",
	"item_echo_sabre",
	"item_harpoon",
	"item_desolator",
	"item_black_king_bar",
	"item_ultimate_scepter",
	"item_assault",
	"item_ultimate_scepter_2",
	"item_blade_mail",
	"item_aghanims_shard",
	"item_moon_shard",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 1, 1,150 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_1"] = {
	"item_tango",
	"item_double_gauntlets",
	"item_double_branches",
	"item_quelling_blade",
	"item_bracer",
	"item_magic_wand",
	"item_soul_ring",
	"item_phase_boots",
	"item_echo_sabre",
	"item_desolator",
	"item_harpoon",
	"item_black_king_bar",
	"item_sange",
	"item_assault",
	"item_ultimate_scepter_2",
	"item_sange_and_yasha",
	"item_aghanims_shard",
	"item_moon_shard",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 2, 8,824 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_2"] = {
	"item_tango",
	"item_double_branches",
	"item_double_gauntlets",
	"item_quelling_blade",
	"item_bracer",
	"item_soul_ring",
	"item_magic_wand",
	"item_phase_boots",
	"item_echo_sabre",
	"item_desolator",
	"item_harpoon",
	"item_black_king_bar",
	"item_ultimate_scepter",
	"item_assault",
	"item_ultimate_scepter_2",
	"item_overwhelming_blink",
	"item_aghanims_shard",
	"item_moon_shard",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 4, 5,493 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_4"] = {
	"item_tango",
	"item_blood_grenade",
	"item_double_branches",
	"item_gauntlets",
	"item_magic_stick",
	"item_magic_wand",
	"item_soul_ring",
	"item_ring_of_basilius",
	"item_arcane_boots",
	"item_guardian_greaves",
	"item_aghanims_shard",
	"item_ultimate_scepter",
	"item_black_king_bar",
	"item_ultimate_scepter_2",
	"item_blade_mail",
	"item_shivas_guard",
	"item_desolator",
	"item_lotus_orb",
	"item_moon_shard",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 5, 2,483 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_5"] = {
	"item_tango",
	"item_blood_grenade",
	"item_branches",
	"item_magic_stick",
	"item_gauntlets",
	"item_magic_wand",
	"item_soul_ring",
	"item_ring_of_basilius",
	"item_arcane_boots",
	"item_guardian_greaves",
	"item_aghanims_shard",
	"item_ultimate_scepter",
	"item_black_king_bar",
	"item_ultimate_scepter_2",
	"item_echo_sabre",
	"item_blade_mail",
	"item_shivas_guard",
	"item_harpoon",
	"item_lotus_orb",
	"item_moon_shard",
}
X["sBuyList"] = sRoleItemsBuyList[sRole]
X["sSellList"] = {
	"item_heavens_halberd",
	"item_quelling_blade",
	"item_abyssal_blade",
	"item_magic_wand",
	"item_assault",
	"item_ancient_janggo",
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
local fireWreathAbility =
	SafeAbility(bot:GetAbilityByName("dawnbreaker_fire_wreath"), "dawnbreaker_fire_wreath", "dawnbreaker")
local celestialHammerAbility =
	SafeAbility(bot:GetAbilityByName("dawnbreaker_celestial_hammer"), "dawnbreaker_celestial_hammer", "dawnbreaker")
local convergeAbility = SafeAbility(bot:GetAbilityByName("dawnbreaker_converge"), "dawnbreaker_converge", "dawnbreaker")
local solarGuardianAbility =
	SafeAbility(bot:GetAbilityByName("dawnbreaker_solar_guardian"), "dawnbreaker_solar_guardian", "dawnbreaker")
local hammerCastRangeTalent = SafeAbility(
	bot:GetAbilityByName("special_bonus_unique_dawnbreaker_celestial_hammer_cast_range"),
	"special_bonus_unique_dawnbreaker_celestial_hammer_cast_range",
	"dawnbreaker"
)
local fireWreathDesire, fireWreathLocation
local celestialHammerDesire, celestialHammerLocation
local convergeDesire
local solarGuardianDesire, solarGuardianLocation
local bkbItem
-- Pending BKB after Solar Guardian lands (do not pop before channel — wastes duration).
local isBkbPending = false
local BKBLandDeadline = -1
local hammerLocation = nil
local hammerLandTime = -1
local isHammerAtEnemy = false
local botTarget
local isGoingOnSomeone
local isRetreating
local hpRatio
-- fix: these helpers were globals (Magnus had a global CanBKB too, reading his own bot).
-- Forward-declared locals: the "function X()" definitions at the bottom now assign these.
local IsTargetLocInBigUlt, CanBKB
local function IsSolarGuardianInFlight()
	return bot:IsChanneling()
		or bot:HasModifier("modifier_dawnbreaker_solar_guardian_air_time")
		or bot:HasModifier("modifier_dawnbreaker_solar_guardian_airtime")
end
function X.SkillsComplement()
	local context = AbilityContext.Build(bot)
	isGoingOnSomeone = context.isEngaging
	isRetreating = context.isRetreating
	hpRatio = context.hp
	-- BKB after landing into the fight, not before ult cast.
	if isBkbPending then
		if DotaTime() > BKBLandDeadline then
			isBkbPending = false
		elseif
			CanBKB()
			and not bot:IsMagicImmune()
			and not IsSolarGuardianInFlight()
			and not bot:IsStunned()
			and not bot:IsHexed()
			and not bot:IsMuted()
		then
			local enemies = Fu.GetNearbyHeroes(bot, 1000, true, BOT_MODE_NONE)
			if enemies ~= nil and #enemies >= 1 then
				bot:Action_UseAbility(bkbItem)
				isBkbPending = false
				return
			end
		end
	end
	if Fu.CanNotUseAbility(bot) then
		return
	end
	celestialHammerDesire, celestialHammerLocation = X.ConsiderCelestialHammer()
	if celestialHammerDesire > 0 then
		local projectileSpeed = celestialHammerAbility:GetSpecialValueInt("projectile_speed")
		hammerLocation = celestialHammerLocation
		if hammerCastRangeTalent:IsTrained() then
			projectileSpeed = projectileSpeed * (1 + hammerCastRangeTalent:GetSpecialValueInt("value") / 100)
		end
		bot:Action_UseAbilityOnLocation(celestialHammerAbility, celestialHammerLocation)
		hammerLandTime = DotaTime()
			+ celestialHammerAbility:GetCastPoint()
			+ GetUnitToLocationDistance(bot, celestialHammerLocation) / projectileSpeed
		return
	end
	convergeDesire = X.ConsiderConverge()
	if convergeDesire > 0 then
		bot:Action_UseAbility(convergeAbility)
		return
	end
	fireWreathDesire, fireWreathLocation = X.ConsiderStarBreaker()
	if fireWreathDesire > 0 then
		bot:Action_UseAbilityOnLocation(fireWreathAbility, fireWreathLocation)
		return
	end
	solarGuardianDesire, solarGuardianLocation = X.ConsiderSolarGuardian()
	if solarGuardianDesire > 0 then
		bot:Action_UseAbilityOnLocation(solarGuardianAbility, solarGuardianLocation)
		return
	end
end
function X.ConsiderStarBreaker()
	if not fireWreathAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local radius = fireWreathAbility:GetSpecialValueInt("swipe_radius")
	local duration = fireWreathAbility:GetSpecialValueFloat("duration")
	local castPoint = fireWreathAbility:GetCastPoint()
	local mpRatio = bot:GetMana() / bot:GetMaxMana()
	local damage = bot:GetAttackDamage()
		+ fireWreathAbility:GetSpecialValueInt("swipe_damage")
		+ fireWreathAbility:GetSpecialValueInt("smash_damage")
	botTarget = Fu.GetProperTarget(bot)
	local nearbyEnemies = Fu.GetNearbyHeroes(bot, radius, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and Fu.IsInRange(bot, enemyHero, radius)
			and not Fu.IsSuspiciousIllusion(enemyHero)
			and not Fu.IsDisabled(enemyHero)
		then
			if enemyHero:IsChanneling() or Fu.IsCastingUltimateAbility(enemyHero) then
				return BOT_ACTION_DESIRE_HIGH, enemyHero:GetLocation()
			end
			if
				Fu.CanKillTarget(enemyHero, damage, DAMAGE_TYPE_PHYSICAL)
				and Fu.IsInRange(bot, enemyHero, radius)
				and not enemyHero:HasModifier("modifier_abaddon_aphotic_shield")
				and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
				and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
				and not enemyHero:HasModifier("modifier_faceless_void_chronosphere_freeze")
				and not enemyHero:HasModifier("modifier_templar_assassin_refraction_absorb")
			then
				return BOT_ACTION_DESIRE_HIGH, enemyHero:GetExtrapolatedLocation(duration + castPoint)
			end
		end
	end
	if Fu.IsInTeamFight(bot, 1200) then
		local aoe = bot:FindAoELocation(true, true, bot:GetLocation(), radius, radius, duration + castPoint, 0)
		if aoe.count >= 2 and not IsTargetLocInBigUlt(aoe.targetloc) then
			return BOT_ACTION_DESIRE_HIGH, aoe.targetloc
		end
	end
	if isGoingOnSomeone then
		local alliesAround = Fu.GetNearbyHeroes(bot, radius * 2, false, BOT_MODE_NONE)
		local enemiesAround = Fu.GetNearbyHeroes(bot, radius * 1.5, true, BOT_MODE_NONE)
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, radius)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not Fu.IsDisabled(botTarget)
			and not botTarget:HasModifier("modifier_dazzle_shallow_grave")
			and not botTarget:HasModifier("modifier_faceless_void_chronosphere_freeze")
			and alliesAround ~= nil
			and enemiesAround
			and #alliesAround >= #enemiesAround
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetExtrapolatedLocation(duration + castPoint)
		end
	end
	if Fu.IsFarming(bot) then
		local neutralCreeps = bot:GetNearbyNeutralCreeps(300)
		local aoe = bot:FindAoELocation(true, false, bot:GetLocation(), radius, radius, 0, 0)
		if
			neutralCreeps ~= nil
			and (
				#neutralCreeps >= 3 and aoe.count >= 3
				or #neutralCreeps >= 2 and neutralCreeps[1]:IsAncientCreep() and aoe.count >= 3
			)
		then
			return BOT_ACTION_DESIRE_HIGH, aoe.targetloc
		end
	end
	if Fu.IsPushing(bot) or Fu.IsDefending(bot) then
		local laneCreeps = bot:GetNearbyLaneCreeps(radius, true)
		local aoe = bot:FindAoELocation(true, false, bot:GetLocation(), radius, radius, 0, 0)
		if laneCreeps ~= nil and #laneCreeps >= 4 and aoe.count >= 4 then
			return BOT_ACTION_DESIRE_HIGH, aoe.targetloc
		end
	end
	if Fu.IsLaning(bot) and mpRatio > 0.4 then
		local killableCount = 0
		local lastHitLocation = nil
		local laneCreeps = bot:GetNearbyLaneCreeps(radius, true)
		for _, creep in pairs(laneCreeps) do
			if
				Fu.IsValid(creep)
				and (Fu.IsKeyWordUnit("ranged", creep) or Fu.IsKeyWordUnit("siege", creep))
				and creep:GetHealth() <= damage
			then
				lastHitLocation = creep:GetLocation()
				killableCount = killableCount + 1
			end
		end
		if killableCount >= 2 and lastHitLocation ~= nil then
			return BOT_ACTION_DESIRE_HIGH, lastHitLocation
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if Fu.IsRoshan(botTarget) and Fu.IsInRange(bot, botTarget, radius) then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, radius) and Fu.IsAttacking(bot) then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.ConsiderCelestialHammer()
	if not celestialHammerAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local range = celestialHammerAbility:GetSpecialValueInt("range")
	local castPoint = celestialHammerAbility:GetCastPoint()
	local projectileSpeed = celestialHammerAbility:GetSpecialValueInt("projectile_speed")
	local damage = celestialHammerAbility:GetSpecialValueInt("hammer_damage")
	local mpRatio = bot:GetMana() / bot:GetMaxMana()
	if hammerCastRangeTalent:IsTrained() then
		range = range * (1 + hammerCastRangeTalent:GetSpecialValueInt("value") / 100)
		projectileSpeed = projectileSpeed * (1 + hammerCastRangeTalent:GetSpecialValueInt("value") / 100)
	end
	local nearbyEnemies = Fu.GetNearbyHeroes(bot, range, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and not Fu.IsSuspiciousIllusion(enemyHero)
			and not enemyHero:HasModifier("modifier_abaddon_aphotic_shield")
			and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
			and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
			and not enemyHero:HasModifier("modifier_templar_assassin_refraction_absorb")
			and Fu.CanKillTarget(enemyHero, damage, DAMAGE_TYPE_MAGICAL)
		then
			local travelTime = GetUnitToUnitDistance(bot, enemyHero) / projectileSpeed + castPoint
			-- isHammerAtEnemy = true: this hammer flies at an enemy, so the retreat Converge must not pull her to
			-- it (isHammerAtEnemy kept the value of the last retreat throw).
			isHammerAtEnemy = true
			return BOT_ACTION_DESIRE_HIGH, enemyHero:GetExtrapolatedLocation(travelTime)
		end
	end
	if isGoingOnSomeone then
		botTarget = Fu.GetProperTarget(bot)
		local alliesAround = Fu.GetNearbyHeroes(bot, range, false, BOT_MODE_NONE)
		local enemiesAround = Fu.GetNearbyHeroes(bot, range, true, BOT_MODE_NONE)
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, range)
			and not Fu.IsInRange(bot, botTarget, 300)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not botTarget:HasModifier("modifier_faceless_void_chronosphere_freeze")
			and alliesAround ~= nil
			and enemiesAround ~= nil
			and #alliesAround >= #enemiesAround
		then
			local travelTime = GetUnitToUnitDistance(bot, botTarget) / projectileSpeed + castPoint
			isHammerAtEnemy = true -- hammer at an enemy: no retreat Converge onto it (see the kill branch)
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetExtrapolatedLocation(travelTime)
		end
	end
	if isRetreating then
		local alliesAround = Fu.GetNearbyHeroes(bot, range, false, BOT_MODE_NONE)
		local enemiesAround = Fu.GetNearbyHeroes(bot, range, true, BOT_MODE_NONE)
		if
			alliesAround ~= nil
			and enemiesAround ~= nil
			and (#enemiesAround > #alliesAround or hpRatio < 0.7 and bot:WasRecentlyDamagedByAnyHero(2))
			and Fu.IsValidHero(enemiesAround[1])
			and not Fu.IsSuspiciousIllusion(enemiesAround[1])
			and not Fu.IsDisabled(enemiesAround[1])
			and not Fu.IsRealInvisible(bot)
		then
			local travelTime = GetUnitToUnitDistance(bot, enemiesAround[1]) / projectileSpeed + castPoint
			if GetUnitToUnitDistance(bot, enemiesAround[1]) > 600 then
				isHammerAtEnemy = true
				return BOT_ACTION_DESIRE_HIGH, enemiesAround[1]:GetExtrapolatedLocation(travelTime)
			else
				isHammerAtEnemy = false
				local escapeLocation = Fu.GetEscapeLoc()
				return BOT_ACTION_DESIRE_HIGH, Fu.Site.GetXUnitsTowardsLocation(bot, escapeLocation, range)
			end
		end
	end
	if Fu.IsLaning(bot) and mpRatio > 0.75 then
		local laneCreeps = bot:GetNearbyLaneCreeps(range, true)
		for _, creep in pairs(laneCreeps) do
			if
				Fu.IsValid(creep)
				and (Fu.IsKeyWordUnit("ranged", creep) or Fu.IsKeyWordUnit("siege", creep))
				and creep:GetHealth() <= damage
			then
				local enemiesAround = Fu.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE)
				if
					enemiesAround ~= nil
					and #enemiesAround >= 1
					and GetUnitToUnitDistance(creep, enemiesAround[1]) <= 600
				then
					return BOT_ACTION_DESIRE_HIGH, creep:GetLocation()
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.ConsiderConverge()
	if not convergeAbility:IsFullyCastable() or convergeAbility:IsHidden() then
		return BOT_ACTION_DESIRE_NONE
	end
	local range = celestialHammerAbility:GetSpecialValueInt("range")
	local projectileSpeed = celestialHammerAbility:GetSpecialValueInt("projectile_speed")
	botTarget = Fu.GetProperTarget(bot)
	if hammerCastRangeTalent:IsTrained() then
		range = range * (1 + hammerCastRangeTalent:GetSpecialValueInt("value") / 100)
		projectileSpeed = projectileSpeed * (1 + hammerCastRangeTalent:GetSpecialValueInt("value") / 100)
	end
	if isGoingOnSomeone and hammerLocation ~= nil then
		local alliesAround = Fu.GetNearbyHeroes(bot, range, false, BOT_MODE_NONE)
		local enemiesAround = Fu.GetNearbyHeroes(bot, range, true, BOT_MODE_NONE)
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, range)
			and not Fu.IsInRange(bot, botTarget, 300)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not botTarget:HasModifier("modifier_faceless_void_chronosphere_freeze")
			and alliesAround ~= nil
			and enemiesAround ~= nil
			and #alliesAround >= #enemiesAround
		then
			local targetAllies = Fu.GetNearbyHeroes(botTarget, 600, false, BOT_MODE_NONE)
			if
				targetAllies ~= nil
				and #alliesAround >= #targetAllies
				and GetUnitToLocationDistance(botTarget, hammerLocation) < GetUnitToLocationDistance(
					bot,
					hammerLocation
				)
				and DotaTime() >= hammerLandTime
			then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	if isRetreating and not isHammerAtEnemy then
		local alliesAround = Fu.GetNearbyHeroes(bot, range, false, BOT_MODE_NONE)
		local enemiesAround = Fu.GetNearbyHeroes(bot, range, true, BOT_MODE_NONE)
		if
			alliesAround ~= nil
			and enemiesAround ~= nil
			and (#enemiesAround > #alliesAround or hpRatio < 0.7 and bot:WasRecentlyDamagedByAnyHero(2))
			and Fu.IsValidHero(enemiesAround[1])
			and not Fu.IsSuspiciousIllusion(enemiesAround[1])
			and not Fu.IsDisabled(enemiesAround[1])
			and not Fu.IsRealInvisible(bot)
		then
			local escapeLocation = Fu.GetEscapeLoc()
			if bot:IsFacingLocation(escapeLocation, 30) and DotaTime() >= hammerLandTime then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderSolarGuardian()
	if not solarGuardianAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local channelTime = solarGuardianAbility:GetChannelTime()
	local radius = solarGuardianAbility:GetSpecialValueInt("radius")
	local airTime = solarGuardianAbility:GetSpecialValueFloat("airtime_duration")
	local castPoint = solarGuardianAbility:GetCastPoint()
	local teamFightLocation = Fu.GetTeamFightLocation(bot)
	local totalDelay = channelTime + airTime + castPoint
	if teamFightLocation ~= nil then
		local alliesNearFight = Fu.GetAlliesNearLoc(teamFightLocation, radius)
		if alliesNearFight ~= nil and #alliesNearFight >= 1 then
			local enemiesNearAlly = alliesNearFight[#alliesNearFight]:GetNearbyHeroes(radius, true, BOT_MODE_NONE)
			if not IsTargetLocInBigUlt(teamFightLocation) and (enemiesNearAlly ~= nil and #enemiesNearAlly >= 1) then
				-- Search around the fight (radius), not within Dawnbreaker's distance to it: for a far
				-- fight that radius spanned the map, so the ally cluster could be anywhere (even base).
				-- The enemy check is also made at the chosen spot instead of a separate enemy cluster.
				local allyAoe = bot:FindAoELocation(false, true, teamFightLocation, radius, radius, totalDelay, 0)
				local enemiesAtSpot = allyAoe ~= nil
						and allyAoe.targetloc ~= nil
						and Fu.GetEnemiesNearLoc(allyAoe.targetloc, radius)
					or {}
				local enemyAoe = { count = #enemiesAtSpot }
				local nearbyEnemies = Fu.GetNearbyHeroes(bot, radius, true, BOT_MODE_NONE)
				-- allyDist: closest allied hero other than her to the spot, at current positions (the ally
				-- count uses predicted positions and may include her; game 036 review).
				local spot = allyAoe ~= nil and allyAoe.targetloc or nil
				local allyDist, allyName, nearestAlly = -1, "-", nil
				if spot ~= nil then
					for _, allyHero in pairs(GetUnitList(UNIT_LIST_ALLIED_HEROES) or {}) do
						if Fu.IsValidHero(allyHero) and allyHero ~= bot and not allyHero:IsIllusion() then
							local distance = GetUnitToLocationDistance(allyHero, spot)
							if allyDist < 0 or distance < allyDist then
								allyDist, allyName, nearestAlly =
									distance, (string.gsub(allyHero:GetUnitName(), "npc_dota_hero_", "")), allyHero
							end
						end
					end
				end
				-- Game 037, 33:31: she landed 672 from the nearest ally (radius 500, +150 talent). A spot
				-- farther than radius - 100 from that ally moves to radius - 200 from him, toward the
				-- original spot, and must still have an enemy hero within the radius.
				local fromDist = allyDist
				if nearestAlly ~= nil and allyDist > radius - 100 then
					spot = Fu.GetXUnitsTowardsLocation2(nearestAlly:GetLocation(), spot, radius - 200)
					allyDist = GetUnitToLocationDistance(nearestAlly, spot)
					enemyAoe.count = #Fu.GetEnemiesNearLoc(spot, radius)
				end
				if nearestAlly ~= nil and allyAoe.count >= 1 and enemyAoe.count >= 1 then
					-- Queue BKB for after channel+airtime land, not before cast.
					if nearbyEnemies ~= nil and #nearbyEnemies >= 1 and not bot:IsMagicImmune() and CanBKB() then
						isBkbPending = true
						BKBLandDeadline = DotaTime() + totalDelay + 1.5
					end
					if DotaTime() >= (bot._sgLogAt or -999) then
						bot._sgLogAt = DotaTime() + 5
						pcall(
							print,
							string.format(
								"[OHA-DAWNBREAKER] t=%.0f solar guardian allies=%d enemies=%d dist=%d allyDist=%d ally=%s radius=%d moved-from=%d",
								DotaTime(),
								allyAoe.count,
								enemyAoe.count,
								GetUnitToLocationDistance(bot, spot),
								math.floor(allyDist),
								allyName,
								radius,
								fromDist ~= allyDist and math.floor(fromDist) or -1
							)
						)
					end
					return BOT_ACTION_DESIRE_HIGH, spot
				end
			end
		end
	end
	local nearbyEnemies = Fu.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE)
	if isRetreating and bot:DistanceFromFountain() > 1600 and hpRatio < 0.33 then
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				bot:WasRecentlyDamagedByHero(enemyHero, 2.0)
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and not Fu.IsRealInvisible(bot)
			then
				local nearbyAllies = Fu.GetNearbyHeroes(bot, 1000, false, BOT_MODE_NONE)
				local farthestAlly = nil
				local farthestDistance = 0
				for i = 1, #GetTeamPlayers(GetTeam()) do
					local member = GetTeamMember(i)
					if member ~= nil and member:IsAlive() and GetUnitToUnitDistance(bot, member) > farthestDistance then
						farthestDistance = GetUnitToUnitDistance(bot, member)
						farthestAlly = member
					end
				end
				if
					nearbyAllies ~= nil
					and (#nearbyAllies <= 1 and #nearbyEnemies >= 3)
					and farthestAlly ~= nil
					and GetUnitToUnitDistance(bot, farthestAlly) > 2500
					and bot:IsMagicImmune()
				then
					return BOT_ACTION_DESIRE_MODERATE, farthestAlly:GetLocation()
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function IsTargetLocInBigUlt(location)
	for _, enemyHero in pairs(GetUnitList(UNIT_LIST_ENEMY_HEROES)) do
		if
			Fu.IsValidHero(enemyHero)
			and not Fu.IsSuspiciousIllusion(enemyHero)
			and GetUnitToLocationDistance(enemyHero, location) < 450
			and enemyHero:HasModifier("modifier_faceless_void_chronosphere_freeze")
		then
			return true
		end
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
	if bkb ~= nil and bkb:IsFullyCastable() then
		bkbItem = bkb
		return true
	end
	return false
end
return X
