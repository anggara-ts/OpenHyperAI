-- Earth Spirit: skill build, item build, and ability use for this hero.
local X = {}
local bot = GetBot()
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local AbilityContext = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local Minion = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local sTalentList = Fu.Skill.GetTalentList(bot)
local sAbilityList = Fu.Skill.GetAbilityList(bot)
local sRole = Fu.Item.GetRoleItemsBuyList(bot)
local tTalentTreeList = { ["t25"] = { 0, 10 }, ["t20"] = { 0, 10 }, ["t15"] = { 0, 10 }, ["t10"] = { 0, 10 } }
local tAllAbilityBuildList = { { 1, 2, 1, 2, 1, 6, 1, 2, 2, 3, 6, 3, 3, 3, 6 } }
local nAbilityBuildList = Fu.Skill.GetRandomBuild(tAllAbilityBuildList)
local nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList)
local sRoleItemsBuyList = {}
sRoleItemsBuyList["pos_2"] = {
	"item_tango",
	"item_double_branches",
	"item_faerie_fire",
	"item_quelling_blade",
	"item_bottle",
	"item_magic_wand",
	"item_power_treads",
	"item_urn_of_shadows",
	"item_spirit_vessel",
	"item_blade_mail",
	"item_kaya_and_sange",
	"item_black_king_bar",
	"item_aghanims_shard",
	"item_travel_boots",
	"item_shivas_guard",
	"item_octarine_core",
	"item_ultimate_scepter_2",
	"item_moon_shard",
	"item_sheepstick",
	"item_travel_boots_2",
}
sRoleItemsBuyList["pos_1"] = {
	"item_tango",
	"item_double_branches",
	"item_faerie_fire",
	"item_quelling_blade",
	"item_magic_wand",
	"item_boots",
	"item_urn_of_shadows",
	"item_spirit_vessel",
	"item_blade_mail",
	"item_heart",
	"item_black_king_bar",
	"item_travel_boots",
	"item_shivas_guard",
	"item_octarine_core",
	"item_ultimate_scepter_2",
	"item_moon_shard",
	"item_sheepstick",
	"item_aghanims_shard",
	"item_travel_boots_2",
}
sRoleItemsBuyList["pos_3"] = {
	"item_tank_outfit",
	"item_aghanims_shard",
	"item_crimson_guard",
	"item_heavens_halberd",
	"item_lotus_orb",
	"item_assault",
	"item_travel_boots",
	"item_ultimate_scepter_2",
	"item_moon_shard",
	"item_heart",
	"item_travel_boots_2",
}
sRoleItemsBuyList["pos_4"] = {
	"item_priest_outfit",
	"item_mekansm",
	"item_glimmer_cape",
	"item_aghanims_shard",
	"item_guardian_greaves",
	"item_spirit_vessel",
	"item_ultimate_scepter",
	"item_sheepstick",
	"item_mystic_staff",
	"item_ultimate_scepter_2",
	"item_shivas_guard",
	"item_moon_shard",
	"item_wind_waker",
}
sRoleItemsBuyList["pos_5"] = {
	"item_mage_outfit",
	"item_ancient_janggo",
	"item_glimmer_cape",
	"item_boots_of_bearing",
	"item_pipe",
	"item_aghanims_shard",
	"item_cyclone",
	"item_shivas_guard",
	"item_sheepstick",
	"item_heart",
	"item_octarine_core",
	"item_moon_shard",
	"item_ultimate_scepter_2",
}
X["sBuyList"] = sRoleItemsBuyList[sRole]
X["sSellList"] = { "item_travel_boots", "item_quelling_blade", "item_abyssal_blade", "item_magic_wand" }
if Fu.Role.IsPvNMode() or Fu.Role.IsAllShadow() then
	X["sBuyList"], X["sSellList"] = { "PvN_antimage" }, {}
end
nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"] = Fu.SetUserHeroInit(nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"])
X["sSkillList"] = Fu.Skill.GetSkillList(sAbilityList, nAbilityBuildList, sTalentList, nTalentBuildList)
X["bDeafaultAbility"] = false
X["bDeafaultItem"] = false
function X.MinionThink(hMinionUnit)
	if Minion.IsValidUnit(hMinionUnit) then
		if Fu.IsValidHero(hMinionUnit) and hMinionUnit:IsIllusion() then
			Minion.IllusionThink(hMinionUnit)
		end
	end
end
local boulderSmashAbility = SafeAbility(bot:GetAbilityByName("earth_spirit_boulder_smash"), "earth_spirit_boulder_smash", "earth_spirit")
local rollingBoulderAbility =
	SafeAbility(bot:GetAbilityByName("earth_spirit_rolling_boulder"), "earth_spirit_rolling_boulder", "earth_spirit")
local geomagneticGripAbility =
	SafeAbility(bot:GetAbilityByName("earth_spirit_geomagnetic_grip"), "earth_spirit_geomagnetic_grip", "earth_spirit")
local stoneRemnantAbility = SafeAbility(bot:GetAbilityByName("earth_spirit_stone_caller"), "earth_spirit_stone_caller", "earth_spirit")
local magnetizeAbility = SafeAbility(bot:GetAbilityByName("earth_spirit_magnetize"), "earth_spirit_magnetize", "earth_spirit")
local talentUnique2 = SafeAbility(
	bot:GetAbilityByName("special_bonus_unique_earth_spirit_2"),
	"special_bonus_unique_earth_spirit_2",
	"earth_spirit"
)
local enchantRemnantAbility = SafeAbility(bot:GetAbilityByName("earth_spirit_petrify"), "earth_spirit_petrify", "earth_spirit")
local boulderSmashDesire, boulderSmashLocation, boulderSmashNeedsStone, boulderSmashReady
local rollingBoulderDesire, rollingBoulderLocation, rollingBoulderNeedsStone
local geomagneticGripDesire, geomagneticGripTarget, geomagneticGripNeedsStone
local unusedDesire
local enchantRemnantDesire
local magnetizeDesire
local unusedState
local stoneCharges = 0
local botTarget
local isGoingOnSomeone
local isRetreating
-- One throttled log line per kind, so the new casts below can be seen in a game.
local esLogAt = {}
local function LogES(kind, fmt, ...)
	if DotaTime() < (esLogAt[kind] or -999) then
		return
	end
	esLogAt[kind] = DotaTime() + 5
	local ok, msg = pcall(string.format, "[OHA-EARTHSPIRIT] t=%.0f " .. kind .. " " .. fmt, DotaTime(), ...)
	if ok then
		pcall(print, msg)
	end
end
function X.SkillsComplement()
	local context = AbilityContext.Build(bot)
	isGoingOnSomeone = context.isEngaging
	isRetreating = context.isRetreating
	if bot:IsUsingAbility() or bot:IsChanneling() or bot:IsSilenced() or bot:NumQueuedActions() > 0 then
		return
	end
	if stoneRemnantAbility:IsFullyCastable() then
		stoneCharges = 1
	else
		stoneCharges = 0
	end
	enchantRemnantDesire, EnchantTarget = X.ConsiderEchantRemnant()
	if enchantRemnantDesire > 0 then
		bot:ActionQueue_UseAbilityOnEntity(enchantRemnantAbility, EnchantTarget)
		bot:ActionQueue_UseAbilityOnLocation(boulderSmashAbility, bot:GetLocation() + RandomVector(800))
		return
	end
	rollingBoulderDesire, rollingBoulderLocation, rollingBoulderNeedsStone = X.ConsiderRollingBoulder()
	if rollingBoulderDesire > 0 then
		if rollingBoulderNeedsStone then
			bot:Action_ClearActions(false)
			bot:ActionQueue_UseAbilityOnLocation(stoneRemnantAbility, bot:GetLocation())
			bot:ActionQueue_UseAbilityOnLocation(rollingBoulderAbility, rollingBoulderLocation)
			return
		else
			bot:Action_UseAbilityOnLocation(rollingBoulderAbility, rollingBoulderLocation)
			return
		end
	end
	magnetizeDesire = X.ConsiderMagnetize()
	if magnetizeDesire > 0 then
		bot:Action_UseAbility(magnetizeAbility)
		return
	end
	boulderSmashDesire, boulderSmashLocation, boulderSmashNeedsStone, boulderSmashReady = X.ConsiderBoulderSmash()
	if boulderSmashDesire > 0 then
		if boulderSmashNeedsStone then
			bot:Action_ClearActions(false)
			bot:ActionQueue_UseAbilityOnLocation(stoneRemnantAbility, bot:GetLocation())
			bot:ActionQueue_UseAbilityOnLocation(boulderSmashAbility, boulderSmashLocation)
			return
		else
			if boulderSmashReady then
				bot:Action_UseAbilityOnLocation(boulderSmashAbility, boulderSmashLocation)
				return
			end
		end
	end
	local onAlly
	geomagneticGripDesire, geomagneticGripTarget, geomagneticGripNeedsStone, onAlly = X.ConsiderGeomagneticGrip()
	if geomagneticGripDesire > 0 then
		if geomagneticGripNeedsStone then
			bot:Action_ClearActions(false)
			bot:ActionQueue_UseAbilityOnLocation(stoneRemnantAbility, geomagneticGripTarget)
			bot:ActionQueue_UseAbilityOnLocation(geomagneticGripAbility, geomagneticGripTarget)
			return
		else
			-- Ally pull is a unit-target cast; it used to depend on Shard, but the base spell
			-- already targets allies (shard only adds range/speed).
			if onAlly == true then
				bot:Action_UseAbilityOnEntity(geomagneticGripAbility, geomagneticGripTarget)
			else
				bot:Action_UseAbilityOnLocation(geomagneticGripAbility, geomagneticGripTarget)
			end
			return
		end
	end
end
function X.ConsiderBoulderSmash()
	if not boulderSmashAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0, false, false
	end
	local castRange = boulderSmashAbility:GetCastRange()
	local attackRange = bot:GetAttackRange()
	local speed = boulderSmashAbility:GetSpecialValueInt("speed")
	local rockDamage = boulderSmashAbility:GetSpecialValueInt("rock_damage")
	local hasStoneNearby = IsStoneNearby(bot:GetLocation(), attackRange)
	local mpRatio = bot:GetMana() / bot:GetMaxMana()
	-- Rock reach: a smashed remnant travels rock_distance (2000). The kill and engage scans used
	-- the smash cast range (150), so the remnant kick only ever fired at melee range.
	local rockReach = math.min(boulderSmashAbility:GetSpecialValueInt("rock_distance"), 1600)
	if rockReach <= 0 then
		rockReach = 1600
	end
	local enemiesInAttackRange = Fu.GetNearbyHeroes(bot, attackRange, true, BOT_MODE_NONE)
	-- Kick an enemy in melee range into a real ally. The ally list includes Earth Spirit himself,
	-- so its last entry could be his own spot (kick toward his feet). A ground cast also kicks a remnant
	-- within 200 first (datafeed), so skip this when one is next to him.
	local kickTo = nil
	for _, ally in pairs(Fu.GetNearbyHeroes(bot, 1200, false, BOT_MODE_NONE) or {}) do
		if ally ~= bot and Fu.IsValidHero(ally) and not ally:IsIllusion() then
			kickTo = ally
			break
		end
	end
	for _, enemyHero in pairs(enemiesInAttackRange) do
		if
			kickTo ~= nil
			and not IsStoneNearby(bot:GetLocation(), boulderSmashAbility:GetSpecialValueInt("rock_search_aoe"))
			and Fu.IsValidHero(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and Fu.IsInRange(bot, enemyHero, attackRange)
			and not Fu.IsSuspiciousIllusion(enemyHero)
		then
			LogES("kick", "enemy=%s into ally=%s", enemyHero:GetUnitName(), kickTo:GetUnitName())
			return BOT_ACTION_DESIRE_HIGH, kickTo:GetLocation(), false, true
		end
	end
	if hasStoneNearby then
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, rockReach, true, BOT_MODE_NONE)
		local killableEnemy = Fu.GetCanBeKilledUnit(nearbyEnemies, rockDamage, DAMAGE_TYPE_MAGICAL, false)
		if killableEnemy ~= nil and not Fu.IsSuspiciousIllusion(killableEnemy) then
			local castLocation = Fu.GetCorrectLoc(killableEnemy, GetUnitToUnitDistance(bot, killableEnemy) / speed)
			return BOT_ACTION_DESIRE_HIGH, castLocation, false, true
		end
	elseif stoneCharges >= 1 then
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, rockReach, true, BOT_MODE_NONE)
		local killableEnemy = Fu.GetCanBeKilledUnit(nearbyEnemies, rockDamage, DAMAGE_TYPE_MAGICAL, false)
		if killableEnemy ~= nil and not Fu.IsSuspiciousIllusion(killableEnemy) then
			local castLocation = Fu.GetCorrectLoc(killableEnemy, GetUnitToUnitDistance(bot, killableEnemy) / speed)
			LogES("smash", "kill target=%s dist=%d", killableEnemy:GetUnitName(), math.floor(GetUnitToUnitDistance(bot, killableEnemy)))
			return BOT_ACTION_DESIRE_HIGH, castLocation, true, false
		end
	end
	if isGoingOnSomeone then
		botTarget = Fu.GetProperTarget(bot)
		-- Engage kick: remnant at the target from up to 1200 (was the 150 cast range).
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, math.min(rockReach, 1200))
			and not Fu.IsSuspiciousIllusion(botTarget)
		then
			local castLocation = Fu.GetCorrectLoc(botTarget, GetUnitToUnitDistance(bot, botTarget) / speed)
			LogES("smash", "engage target=%s dist=%d", botTarget:GetUnitName(), math.floor(GetUnitToUnitDistance(bot, botTarget)))
			if hasStoneNearby then
				return BOT_ACTION_DESIRE_HIGH, castLocation, false, true
			elseif stoneCharges >= 1 then
				return BOT_ACTION_DESIRE_HIGH, castLocation, true, false
			end
		end
	end
	if isRetreating and bot:WasRecentlyDamagedByAnyHero(2) then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, 1000, false, BOT_MODE_NONE)
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, 800, true, BOT_MODE_NONE)
		local closestEnemy = Fu.GetClosestUnit(nearbyEnemies)
		if closestEnemy ~= nil and hasStoneNearby then
			if nearbyAllies ~= nil and nearbyEnemies ~= nil and #nearbyAllies <= 1 and #nearbyEnemies <= 1 then
				return BOT_ACTION_DESIRE_HIGH, closestEnemy:GetLocation(), false, true
			end
		elseif closestEnemy ~= nil and stoneCharges >= 1 then
			if nearbyAllies ~= nil and nearbyEnemies ~= nil and #nearbyAllies <= 1 and #nearbyEnemies <= 1 and bot:IsFacingLocation(Fu.GetEscapeLoc(), 30) then
				return BOT_ACTION_DESIRE_HIGH, closestEnemy:GetLocation(), true, false
			end
		end
	end
	if Fu.IsLaning(bot) then
		if stoneCharges >= 1 and mpRatio > 0.33 then
			local nearbyLaneCreeps = bot:GetNearbyLaneCreeps(stoneRemnantAbility:GetCastRange(), true)
			for _, creep in pairs(nearbyLaneCreeps) do
				if Fu.IsValid(creep) and Fu.IsKeyWordUnit("ranged", creep) and creep:GetHealth() <= rockDamage then
					local nearbyEnemies = Fu.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE)
					if nearbyEnemies ~= nil and #nearbyEnemies >= 1 and GetUnitToUnitDistance(creep, nearbyEnemies[1]) <= 600 then
						return BOT_ACTION_DESIRE_HIGH, creep:GetLocation(), true, false
					end
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0, false, false
end
function X.ConsiderRollingBoulder()
	if not rollingBoulderAbility:IsFullyCastable() or bot:IsRooted() then
		return BOT_ACTION_DESIRE_NONE, 0, false
	end
	local distance = rollingBoulderAbility:GetSpecialValueInt("distance")
	local delay = rollingBoulderAbility:GetSpecialValueFloat("delay")
	local rockSpeed = rollingBoulderAbility:GetSpecialValueInt("rock_speed")
	local damage = rollingBoulderAbility:GetSpecialValueInt("damage")
	-- Mana ratio (was raw mana, so the "mpRatio > 0.88" travel roll below passed at any mana).
	local mpRatio = bot:GetMana() / bot:GetMaxMana()
	local stoneRange = math.min(distance * 2, 1600)
	local searchRange = distance
	if stoneCharges >= 1 then
		searchRange = searchRange * 2
	end
	local nearbyEnemies = Fu.GetNearbyHeroes(bot, math.min(searchRange, 1600), true, BOT_MODE_NONE)
	for _, enemyHero in pairs(nearbyEnemies) do
		-- Parenthesised: the channel case used to skip the illusion and already-rolling checks.
		if
			(enemyHero:CanBeSeen() and enemyHero:IsChanneling() or Fu.IsCastingUltimateAbility(enemyHero))
			and not Fu.IsSuspiciousIllusion(enemyHero)
			and not bot:HasModifier("modifier_earth_spirit_rolling_boulder_caster")
		then
			local castLocation = Fu.GetCorrectLoc(enemyHero, GetUnitToUnitDistance(bot, enemyHero) / rockSpeed + delay)
			if IsStoneInPath(castLocation, GetUnitToUnitDistance(bot, enemyHero)) or stoneCharges == 0 then
				return BOT_ACTION_DESIRE_HIGH, castLocation, false
			elseif stoneCharges >= 1 then
				return BOT_ACTION_DESIRE_HIGH, castLocation, true
			end
		end
	end
	if Fu.IsStuck(bot) then
		local escapeLocation = Fu.GetEscapeLoc()
		return BOT_ACTION_DESIRE_HIGH, Fu.Site.GetXUnitsTowardsLocation(bot, escapeLocation, distance), false
	end
	if stoneCharges >= 1 then
		local killableEnemy = Fu.GetCanBeKilledUnit(nearbyEnemies, damage, DAMAGE_TYPE_MAGICAL, false)
		if killableEnemy ~= nil and not Fu.IsSuspiciousIllusion(killableEnemy) then
			local castLocation = Fu.GetCorrectLoc(killableEnemy, GetUnitToUnitDistance(bot, killableEnemy) / rockSpeed + delay)
			if IsStoneInPath(castLocation, GetUnitToUnitDistance(bot, killableEnemy)) then
				return BOT_ACTION_DESIRE_HIGH, castLocation, false
			else
				return BOT_ACTION_DESIRE_HIGH, castLocation, true
			end
		end
	elseif stoneCharges == 0 then
		local killableEnemy = Fu.GetCanBeKilledUnit(nearbyEnemies, damage, DAMAGE_TYPE_MAGICAL, false)
		if killableEnemy ~= nil and not Fu.IsSuspiciousIllusion(killableEnemy) then
			local castLocation = Fu.GetCorrectLoc(killableEnemy, GetUnitToUnitDistance(bot, killableEnemy) / rockSpeed + delay)
			return BOT_ACTION_DESIRE_HIGH, castLocation, false
		end
	end
	if isGoingOnSomeone then
		botTarget = Fu.GetProperTarget(bot)
		if
			stoneCharges >= 1
			and Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, stoneRange)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not botTarget:HasModifier("modifier_faceless_void_chronosphere")
		then
			local nearbyAllies = Fu.GetNearbyHeroes(bot, stoneRange, false, BOT_MODE_NONE)
			if nearbyEnemies ~= nil and nearbyAllies ~= nil and (#nearbyAllies >= #nearbyEnemies or #nearbyEnemies > #nearbyAllies and Fu.WeAreStronger(bot, distance)) then
				local castLocation = Fu.GetCorrectLoc(botTarget, GetUnitToUnitDistance(bot, botTarget) / rockSpeed)
				if IsStoneInPath(castLocation, GetUnitToUnitDistance(bot, botTarget)) then
					return BOT_ACTION_DESIRE_HIGH, castLocation, false
				else
					return BOT_ACTION_DESIRE_HIGH, castLocation, true
				end
			end
		elseif
			stoneCharges == 0
			and Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, distance)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not botTarget:HasModifier("modifier_faceless_void_chronosphere")
		then
			local castLocation = Fu.GetCorrectLoc(botTarget, delay)
			return BOT_ACTION_DESIRE_HIGH, castLocation, false
		end
	end
	local alliesInRange = Fu.GetNearbyHeroes(bot, stoneRange, false, BOT_MODE_NONE)
	if isRetreating or isRetreating and (alliesInRange ~= nil and nearbyEnemies ~= nil and #nearbyEnemies > #alliesInRange) then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, stoneRange, false, BOT_MODE_NONE)
		local escapeLocation = Fu.GetEscapeLoc()
		local castLocation = Fu.Site.GetXUnitsTowardsLocation(bot, escapeLocation, distance)
		if nearbyAllies ~= nil and nearbyEnemies ~= nil and (#nearbyEnemies > #nearbyAllies or #nearbyAllies >= #nearbyEnemies and Fu.GetHP(bot) < 0.45) then
			if stoneCharges >= 1 then
				if Fu.IsInRange(bot, nearbyEnemies[1], 600) then
					return BOT_ACTION_DESIRE_HIGH, castLocation, true
				else
					return BOT_ACTION_DESIRE_HIGH, castLocation, false
				end
			elseif stoneCharges == 0 then
				return BOT_ACTION_DESIRE_HIGH, castLocation, false
			end
		end
	end
	if
		mpRatio > 0.88
		and bot:DistanceFromFountain() > 100
		and bot:DistanceFromFountain() < 6000
		and DotaTime() > 0
		and not Fu.IsDoingTormentor(bot)
	then
		local topFront = GetLaneFrontLocation(GetTeam(), LANE_TOP, 0)
		local midFront = GetLaneFrontLocation(GetTeam(), LANE_MID, 0)
		local botFront = GetLaneFrontLocation(GetTeam(), LANE_BOT, 0)
		local frontDistance = GetUnitToLocationDistance(bot, bot:GetLocation())
		local frontLocation = Vector(0, 0, 0)
		if bot:IsFacingLocation(topFront, 45) then
			frontDistance = GetUnitToLocationDistance(bot, topFront)
			frontLocation = topFront
		elseif bot:IsFacingLocation(midFront, 45) then
			frontDistance = GetUnitToLocationDistance(bot, midFront)
			frontLocation = midFront
		elseif bot:IsFacingLocation(botFront, 45) then
			frontDistance = GetUnitToLocationDistance(bot, botFront)
			frontLocation = botFront
		end
		if frontDistance > 1600 then
			local travelLocation = Fu.Site.GetXUnitsTowardsLocation(bot, frontLocation, distance)
			if IsLocationPassable(travelLocation) then
				return BOT_ACTION_DESIRE_HIGH, travelLocation, false
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0, false
end
function X.ConsiderGeomagneticGrip()
	if not geomagneticGripAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0, false
	end
	local castRange = geomagneticGripAbility:GetCastRange()
	local castPoint = geomagneticGripAbility:GetCastPoint()
	local mpRatio = bot:GetMana() / bot:GetMaxMana()
	local rockDamage = geomagneticGripAbility:GetSpecialValueInt("rock_damage")
	-- Ally save. Grip pulls allied heroes without Shard (datafeed: "cast range is reduced when
	-- targeting an ally"; cast_range_heroes 550-700, Shard +50%). It used to be Shard-only, used
	-- the remnant range (1000-1300) and required no ally within 300 of Earth Spirit, but that list
	-- includes himself, so it never fired. Now: a hurt or fleeing ally being hit by heroes, an enemy
	-- hero near him, between 300 and the hero cast range, while Earth Spirit is not running himself.
	local heroRange = geomagneticGripAbility:GetSpecialValueInt("cast_range_heroes")
	if heroRange <= 0 then
		heroRange = 550
	end
	if not isRetreating then
		for _, allyHero in pairs(Fu.GetNearbyHeroes(bot, heroRange, false, BOT_MODE_NONE) or {}) do
			if
				allyHero ~= bot
				and Fu.IsValidHero(allyHero)
				and not allyHero:IsIllusion()
				and Fu.IsInRange(bot, allyHero, heroRange)
				and not Fu.IsInRange(bot, allyHero, 300)
				and allyHero:WasRecentlyDamagedByAnyHero(2.0)
				and (Fu.GetHP(allyHero) < 0.4 or Fu.IsRetreating(allyHero))
				and not allyHero:HasModifier("modifier_faceless_void_chronosphere_freeze")
				and not allyHero:HasModifier("modifier_enigma_black_hole_pull")
				and not allyHero:HasModifier("modifier_legion_commander_duel")
				and #(Fu.GetEnemiesNearLoc(allyHero:GetLocation(), 700) or {}) >= 1
			then
				LogES("grip", "save ally=%s hp=%.2f dist=%d", allyHero:GetUnitName(), Fu.GetHP(allyHero), math.floor(GetUnitToUnitDistance(bot, allyHero)))
				return BOT_ACTION_DESIRE_HIGH, allyHero, false, true
			end
		end
	end
	local nearbyEnemies = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	local killableEnemy = Fu.GetCanBeKilledUnit(nearbyEnemies, rockDamage, DAMAGE_TYPE_MAGICAL, false)
	if killableEnemy ~= nil and Fu.CanCastOnNonMagicImmune(killableEnemy) and Fu.IsInRange(bot, killableEnemy, castRange) and not Fu.IsSuspiciousIllusion(killableEnemy) then
		local castLocation = Fu.GetCorrectLoc(killableEnemy, castPoint)
		local hasStoneNearTarget = IsStoneNearTarget(killableEnemy)
		if hasStoneNearTarget then
			return BOT_ACTION_DESIRE_HIGH, castLocation, false
		elseif stoneCharges >= 1 then
			return BOT_ACTION_DESIRE_HIGH, castLocation, true
		end
	end
	if isGoingOnSomeone then
		botTarget = Fu.GetProperTarget(bot)
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			-- Also for the silence, not only when it kills (a pulled remnant silences whoever it hits).
			and (Fu.CanKillTarget(botTarget, rockDamage, DAMAGE_TYPE_MAGICAL) or not botTarget:IsSilenced() and not Fu.IsDisabled(botTarget))
			and not Fu.IsSuspiciousIllusion(botTarget)
		then
			local enemiesNearTarget = Fu.GetNearbyHeroes(botTarget, castRange, false, BOT_MODE_NONE)
			local alliesNearTarget = Fu.GetNearbyHeroes(botTarget, castRange, true, BOT_MODE_NONE)
			if enemiesNearTarget ~= nil and alliesNearTarget ~= nil and #enemiesNearTarget >= #alliesNearTarget then
				local castLocation = Fu.GetCorrectLoc(botTarget, castPoint)
				-- Check the stone near the engage target (botTarget); killableEnemy (kill-scan result) can be nil here and crash.
				local hasStoneNearTarget = IsStoneNearTarget(botTarget)
				if hasStoneNearTarget then
					return BOT_ACTION_DESIRE_HIGH, castLocation, false
				elseif stoneCharges >= 1 then
					return BOT_ACTION_DESIRE_HIGH, castLocation, true
				end
			end
		end
	end
	if Fu.IsLaning(bot) then
		if stoneCharges >= 1 and mpRatio > 0.33 then
			local nearbyLaneCreeps = bot:GetNearbyLaneCreeps(stoneRemnantAbility:GetCastRange(), true)
			for _, creep in pairs(nearbyLaneCreeps) do
				if Fu.IsValid(creep) and Fu.IsKeyWordUnit("ranged", creep) and creep:GetHealth() <= rockDamage then
					local nearbyEnemies = Fu.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE)
					if nearbyEnemies ~= nil and #nearbyEnemies >= 1 and GetUnitToUnitDistance(creep, nearbyEnemies[1]) <= 600 then
						return BOT_ACTION_DESIRE_HIGH, creep:GetLocation(), true, false
					end
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0, false, false
end
function X.ConsiderEchantRemnant()
	if not enchantRemnantAbility:IsTrained() or not enchantRemnantAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function X.ConsiderMagnetize()
	if not magnetizeAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
	end
	local radius = magnetizeAbility:GetSpecialValueInt("cast_radius")
	botTarget = Fu.GetProperTarget(bot)
	if Fu.IsInTeamFight(bot, 1200) then
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, radius, true, BOT_MODE_NONE)
		if nearbyEnemies ~= nil and #nearbyEnemies >= 2 then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if isGoingOnSomeone then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, radius + 200, false, BOT_MODE_NONE)
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, radius, true, BOT_MODE_NONE)
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, radius)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and nearbyAllies ~= nil
			and nearbyEnemies ~= nil
			and #nearbyAllies <= 1
			and #nearbyEnemies <= 1
		then
			return BOT_ACTION_DESIRE_MODERATE
		end
	end
	if isRetreating then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, radius + 200, false, BOT_MODE_NONE)
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, radius, true, BOT_MODE_NONE)
		if
			nearbyEnemies ~= nil
			and nearbyAllies ~= nil
			and #nearbyEnemies >= 2
			and bot:WasRecentlyDamagedByAnyHero(2)
			and Fu.CanCastOnNonMagicImmune(nearbyEnemies[1])
			and Fu.IsInRange(bot, nearbyEnemies[1], radius)
			and not Fu.IsSuspiciousIllusion(nearbyEnemies[1])
			and #nearbyEnemies > #nearbyAllies
		then
			return BOT_ACTION_DESIRE_MODERATE
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function IsStoneNearby(location, radius)
	local otherUnits = GetUnitList(UNIT_LIST_ALLIED_OTHER)
	for _, unit in pairs(otherUnits) do
		if
			unit ~= nil
			and unit:GetUnitName() == "npc_dota_earth_spirit_stone"
			and GetUnitToLocationDistance(unit, location) < radius
		then
			return true
		end
	end
	return false
end
function IsStoneInPath(location, distance)
	if bot:IsFacingLocation(location, 5) then
		local otherUnits = GetUnitList(UNIT_LIST_ALLIED_OTHER)
		for _, unit in pairs(otherUnits) do
			if
				unit ~= nil
				and unit:GetUnitName() == "npc_dota_earth_spirit_stone"
				and bot:IsFacingLocation(unit:GetLocation(), 5)
				and GetUnitToUnitDistance(unit, bot) < distance
			then
				return true
			end
		end
	end
	return false
end
function IsStoneNearTarget(target)
	local otherUnits = GetUnitList(UNIT_LIST_ALLIED_OTHER)
	for _, unit in pairs(otherUnits) do
		if
			unit ~= nil
			and unit:GetUnitName() == "npc_dota_earth_spirit_stone"
			and GetUnitToLocationDistance(unit, target:GetLocation()) < 100
		then
			return true
		end
	end
	return false
end
return X
