-- Earth Spirit: skill build, item build, and ability use for this hero.
-- Accidental globals made file-local (#13): every bot shares one Lua state, so these were shared.
local EnchantTarget, IsStoneNearby, IsStoneInPath, IsStoneNearTarget
local X = {}
local bot = GetBot()
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local AbilityContext = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local Minion = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local sTalentList = Fu.Skill.GetTalentList(bot)
local sAbilityList = Fu.Skill.GetAbilityList(bot)
local sRole = Fu.Item.GetRoleItemsBuyList(bot)
local tTalentTreeList = { ["t25"] = { 0, 10 }, ["t20"] = { 0, 10 }, ["t15"] = { 0, 10 }, ["t10"] = { 0, 10 } }
-- Boulder Smash maxed first, one Geomagnetic Grip point at level 4 (67% of pos 4 and 61% of pos 2 Earth
-- Spirits have it by then), Rolling Boulder second. Stratz, week of 12-18 Nov 2026 (7.41f), 24,945 / 30,325 matches.
local tAllAbilityBuildList = { { 1, 2, 1, 3, 1, 6, 1, 2, 2, 2, 6, 3, 3, 3, 6 } }
local nAbilityBuildList = Fu.Skill.GetRandomBuild(tAllAbilityBuildList)
local nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList)
local sRoleItemsBuyList = {}
-- Stratz 7.41f, week of 9 Nov 2026: pos 2, 28,922 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_2"] = {
	"item_tango",
	"item_double_branches",
	"item_faerie_fire",
	"item_quelling_blade",
	"item_magic_wand",
	"item_urn_of_shadows",
	"item_power_treads",
	"item_spirit_vessel",
	"item_kaya",
	"item_veil_of_discord",
	"item_black_king_bar",
	"item_kaya_and_sange",
	"item_shivas_guard",
	"item_ultimate_scepter_2",
	"item_aghanims_shard",
	"item_moon_shard",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 1 has 193 matches, built from pos 2 (28,922) (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_1"] = sRoleItemsBuyList["pos_2"]
-- Stratz 7.41f, week of 9 Nov 2026: pos 3, 10,877 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_3"] = {
	"item_tango",
	"item_double_branches",
	"item_circlet",
	"item_gauntlets",
	"item_quelling_blade",
	"item_bracer",
	"item_magic_wand",
	"item_urn_of_shadows",
	"item_power_treads",
	"item_spirit_vessel",
	"item_black_king_bar",
	"item_kaya_and_sange",
	"item_shivas_guard",
	"item_ultimate_scepter_2",
	"item_blade_mail",
	"item_aghanims_shard",
	"item_moon_shard",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 4, 24,457 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_4"] = {
	"item_tango",
	"item_blood_grenade",
	"item_branches",
	"item_circlet",
	"item_magic_stick",
	"item_magic_wand",
	"item_urn_of_shadows",
	"item_tranquil_boots",
	"item_spirit_vessel",
	"item_aether_lens",
	"item_blink",
	"item_ultimate_scepter",
	"item_essence_distiller",
	"item_ultimate_scepter_2",
	"item_kaya_and_sange",
	"item_aghanims_shard",
	"item_moon_shard",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 5, 8,998 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_5"] = {
	"item_tango",
	"item_blood_grenade",
	"item_branches",
	"item_circlet",
	"item_magic_stick",
	"item_magic_wand",
	"item_urn_of_shadows",
	"item_tranquil_boots",
	"item_spirit_vessel",
	"item_aether_lens",
	"item_blink",
	"item_ultimate_scepter",
	"item_essence_distiller",
	"item_ultimate_scepter_2",
	"item_ancient_janggo",
	"item_aghanims_shard",
	"item_moon_shard",
}
X["sBuyList"] = sRoleItemsBuyList[sRole]
X["sSellList"] = { "item_travel_boots", "item_quelling_blade", "item_abyssal_blade", "item_magic_wand" }
if Fu.Role.IsPvNMode() or Fu.Role.IsAllShadow() then
	X["sBuyList"], X["sSellList"] = { "PvN_antimage" }, {}
end
nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"] =
	Fu.SetUserHeroInit(nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"])
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
local boulderSmashAbility =
	SafeAbility(bot:GetAbilityByName("earth_spirit_boulder_smash"), "earth_spirit_boulder_smash", "earth_spirit")
local rollingBoulderAbility =
	SafeAbility(bot:GetAbilityByName("earth_spirit_rolling_boulder"), "earth_spirit_rolling_boulder", "earth_spirit")
local geomagneticGripAbility =
	SafeAbility(bot:GetAbilityByName("earth_spirit_geomagnetic_grip"), "earth_spirit_geomagnetic_grip", "earth_spirit")
local stoneRemnantAbility =
	SafeAbility(bot:GetAbilityByName("earth_spirit_stone_caller"), "earth_spirit_stone_caller", "earth_spirit")
local magnetizeAbility =
	SafeAbility(bot:GetAbilityByName("earth_spirit_magnetize"), "earth_spirit_magnetize", "earth_spirit")
local enchantRemnantAbility =
	SafeAbility(bot:GetAbilityByName("earth_spirit_petrify"), "earth_spirit_petrify", "earth_spirit")
local boulderSmashDesire, boulderSmashLocation, boulderSmashNeedsStone, boulderSmashReady
local rollingBoulderDesire, rollingBoulderLocation, rollingBoulderNeedsStone
local geomagneticGripDesire, geomagneticGripTarget, geomagneticGripNeedsStone
local enchantRemnantDesire
local magnetizeDesire
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
-- Ally saves (#47): a pull (Geomagnetic Grip) brings the ally next to Earth Spirit, a kick (Boulder Smash on
-- the ally) sends it unit_distance away. Either must take the ally AWAY from danger.
-- npc_units.txt 7.42: tower AttackRange 700; +200 margin so the ally doesn't land at the edge of it.
local SAVE_TOWER_GAP = 900
-- No pull when an enemy hero is this close to Earth Spirit (the ally would land next to it).
local SAVE_ES_DANGER = 500
-- The landing spot must be at least this much farther from the nearest enemy hero than the ally is now.
local SAVE_MIN_GAIN = 100
-- When the current kick-move attempt started and when it last moved (the 1.5 s step limit).
local kickMoveSince, kickMoveLast = -999, -999
local function Dist2D(a, b)
	local dx, dy = a.x - b.x, a.y - b.y
	return math.sqrt(dx * dx + dy * dy)
end
local function NearestDist(point, locations)
	local best = math.huge
	for _, location in ipairs(locations or {}) do
		local d = Dist2D(point, location)
		if d < best then
			best = d
		end
	end
	return best
end
-- Pure: why a save that lands the ally at landingLoc would be wrong, or nil when it is safe.
-- enemyLocs: enemy heroes around the ally; towerLocs: living enemy towers; esEnemyLocs (pull only): enemy
-- heroes around Earth Spirit, whose position is the landing spot.
function X.SaveLandingProblem(allyLoc, landingLoc, enemyLocs, towerLocs, esEnemyLocs)
	if esEnemyLocs ~= nil and NearestDist(landingLoc, esEnemyLocs) <= SAVE_ES_DANGER then
		return "es-in-danger"
	end
	if NearestDist(landingLoc, enemyLocs) < NearestDist(allyLoc, enemyLocs) + SAVE_MIN_GAIN then
		return "closer-to-enemy"
	end
	if NearestDist(landingLoc, towerLocs) <= SAVE_TOWER_GAP then
		return "tower"
	end
	return nil
end
-- Pure: where a kicked ally lands. The kick goes the way Earth Spirit faces (datafeed); a unit-target cast is
-- assumed to turn him to the ally first (inferred, not confirmed: save-kick logs face= and bearing=), so the
-- ally flies along the line from him through the ally.
function X.KickLanding(esLoc, allyLoc, kickDist)
	local dx, dy = allyLoc.x - esLoc.x, allyLoc.y - esLoc.y
	local length = math.sqrt(dx * dx + dy * dy)
	if length < 1 then
		return nil
	end
	return { x = allyLoc.x + dx / length * kickDist, y = allyLoc.y + dy / length * kickDist }
end
-- An enemy hero this close to the ally, ahead of the kick and within this distance of its line, is in the path.
local KICK_PATH_RANGE = 700
local KICK_PATH_WIDTH = 350
-- Pure: why kicking the ally (Earth Spirit at esLoc) would be wrong, or nil when it is safe. Besides the
-- landing spot, the ally must not fly through or toward an enemy hero (a landing past the enemy still counts
-- as "farther" by distance alone).
function X.KickProblem(esLoc, allyLoc, kickDist, enemyLocs, towerLocs)
	local landing = X.KickLanding(esLoc, allyLoc, kickDist)
	if landing == nil then
		return "no-direction"
	end
	local dirX, dirY = (landing.x - allyLoc.x) / kickDist, (landing.y - allyLoc.y) / kickDist
	for _, enemyLoc in ipairs(enemyLocs or {}) do
		local ex, ey = enemyLoc.x - allyLoc.x, enemyLoc.y - allyLoc.y
		local ahead = ex * dirX + ey * dirY
		local side = math.abs(ex * dirY - ey * dirX)
		if ahead > 0 and ahead <= KICK_PATH_RANGE and side <= KICK_PATH_WIDTH then
			return "closer-to-enemy"
		end
	end
	return X.SaveLandingProblem(allyLoc, landing, enemyLocs, towerLocs, nil)
end
local ENEMY_TOWER_IDS = {
	TOWER_TOP_1,
	TOWER_TOP_2,
	TOWER_TOP_3,
	TOWER_MID_1,
	TOWER_MID_2,
	TOWER_MID_3,
	TOWER_BOT_1,
	TOWER_BOT_2,
	TOWER_BOT_3,
	TOWER_BASE_1,
	TOWER_BASE_2,
}
local function EnemyTowerLocations()
	local locations = {}
	local enemyTeam = GetOpposingTeam()
	for _, id in ipairs(ENEMY_TOWER_IDS) do
		local tower = GetTower(enemyTeam, id)
		if tower ~= nil then
			table.insert(locations, tower:GetLocation())
		end
	end
	return locations
end
local function HeroLocations(heroes)
	local locations = {}
	for _, hero in pairs(heroes or {}) do
		if Fu.IsValidHero(hero) then
			table.insert(locations, hero:GetLocation())
		end
	end
	return locations
end
-- Returns "kick", ally / "kick-move", standLocation / "pull", ally, or nil. Logs the near-misses (why a
-- hurt ally in danger got no save) once per 5 s.
function X.ConsiderAllySave()
	local smashReady = boulderSmashAbility:IsFullyCastable()
	local gripReady = geomagneticGripAbility:IsFullyCastable()
	local smashRange = boulderSmashAbility:GetCastRange()
	if smashRange <= 0 then
		smashRange = 150
	end
	-- npc_abilities 7.42: unit_distance 500/600/700/800 (how far a kicked unit flies).
	local kickDist = boulderSmashAbility:GetSpecialValueInt("unit_distance")
	if kickDist <= 0 then
		kickDist = 500
	end
	-- npc_abilities 7.42: cast_range_heroes 550/600/650/700 (Shard +50%).
	local gripRange = geomagneticGripAbility:GetSpecialValueInt("cast_range_heroes")
	if gripRange <= 0 then
		gripRange = 550
	end
	local botLoc = bot:GetLocation()
	local towerLocs = nil
	for _, allyHero in pairs(Fu.GetNearbyHeroes(bot, 1200, false, BOT_MODE_NONE) or {}) do
		if allyHero ~= bot and Fu.IsValidHero(allyHero) and not allyHero:IsIllusion() then
			local allyLoc = allyHero:GetLocation()
			local enemiesOnAlly = Fu.GetEnemiesNearLoc(allyLoc, 500)
			local inTrouble = (Fu.GetHP(allyHero) < 0.45 or Fu.IsRetreating(allyHero))
				and (allyHero:WasRecentlyDamagedByAnyHero(2.0) or #enemiesOnAlly >= 1)
			if inTrouble then
				local dist = GetUnitToUnitDistance(bot, allyHero)
				local enemyLocs = HeroLocations(Fu.GetEnemiesNearLoc(allyLoc, 1600))
				towerLocs = towerLocs or EnemyTowerLocations()
				local miss = nil
				if #enemyLocs == 0 then
					miss = "no-enemy-seen"
				end
				-- Kick: the ally must be next to him (cast range 150).
				if miss == nil and smashReady and dist <= smashRange + 100 then
					local problem = X.KickProblem(botLoc, allyLoc, kickDist, enemyLocs, towerLocs)
					if problem == nil then
						LogES(
							"save-kick",
							"ally=%s hp=%.2f dist=%d kick=%d face=%d bearing=%d",
							allyHero:GetUnitName(),
							Fu.GetHP(allyHero),
							math.floor(dist),
							kickDist,
							math.floor(bot:GetFacing() or 0),
							-- Direction from him to the ally (0 = east, like GetFacing): the kick should go this way.
							math.floor(
								math.deg((math.atan2 or math.atan)(allyLoc.y - botLoc.y, allyLoc.x - botLoc.x)) % 360
							)
						)
						return "kick", allyHero
					end
					-- Stand on the enemies' side of the ally, so the next kick sends it away from them.
					local nearestEnemyLoc = nil
					for _, enemyLoc in ipairs(enemyLocs) do
						if nearestEnemyLoc == nil or Dist2D(allyLoc, enemyLoc) < Dist2D(allyLoc, nearestEnemyLoc) then
							nearestEnemyLoc = enemyLoc
						end
					end
					local standLoc = nearestEnemyLoc ~= nil and X.KickLanding(nearestEnemyLoc, allyLoc, -100) or nil
					-- Not while he is fleeing or low himself, and at most 1.5 s of stepping per attempt.
					local now = DotaTime()
					if now - kickMoveLast > 1 then
						kickMoveSince = now
					end
					if
						standLoc ~= nil
						and not isRetreating
						and Fu.GetHP(bot) >= 0.3
						and now - kickMoveSince <= 1.5
						and Dist2D(botLoc, standLoc) <= 400
						and X.KickProblem(standLoc, allyLoc, kickDist, enemyLocs, towerLocs) == nil
					then
						kickMoveLast = now
						LogES(
							"save-kick-move",
							"ally=%s was=%s move=%d",
							allyHero:GetUnitName(),
							problem,
							math.floor(Dist2D(botLoc, standLoc))
						)
						return "kick-move", Vector(standLoc.x, standLoc.y, allyLoc.z)
					end
					LogES(
						"save-skip",
						"why=%s kind=kick ally=%s dist=%d",
						problem,
						allyHero:GetUnitName(),
						math.floor(dist)
					)
				end
				-- Pull: the ally lands next to Earth Spirit.
				if miss == nil then
					if not gripReady then
						miss = "grip-not-ready"
					elseif dist > gripRange then
						miss = "grip-range"
					elseif dist < 250 then
						miss = "too-close"
					elseif
						allyHero:HasModifier("modifier_faceless_void_chronosphere_freeze")
						or allyHero:HasModifier("modifier_enigma_black_hole_pull")
						or allyHero:HasModifier("modifier_legion_commander_duel")
					then
						miss = "pull-blocked"
					else
						local esEnemyLocs = HeroLocations(Fu.GetNearbyHeroes(bot, 800, true, BOT_MODE_NONE))
						local problem = X.SaveLandingProblem(allyLoc, botLoc, enemyLocs, towerLocs, esEnemyLocs)
						if problem == nil then
							LogES(
								"grip",
								"save ally=%s hp=%.2f dist=%d",
								allyHero:GetUnitName(),
								Fu.GetHP(allyHero),
								math.floor(dist)
							)
							return "pull", allyHero
						end
						LogES(
							"save-skip",
							"why=%s kind=pull ally=%s dist=%d",
							problem,
							allyHero:GetUnitName(),
							math.floor(dist)
						)
					end
				end
				if miss ~= nil then
					LogES(
						"save-miss",
						"why=%s ally=%s hp=%.2f dist=%d",
						miss,
						allyHero:GetUnitName(),
						Fu.GetHP(allyHero),
						math.floor(dist)
					)
				end
			end
		end
	end
	return nil, nil
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
	-- Ally saves first: the enemy kick below fired in the same situations and used up Boulder Smash.
	local saveKind, saveTarget = X.ConsiderAllySave()
	if saveKind == "kick" then
		bot:Action_UseAbilityOnEntity(boulderSmashAbility, saveTarget)
		return
	elseif saveKind == "kick-move" then
		bot:Action_MoveToLocation(saveTarget)
		return
	elseif saveKind == "pull" then
		bot:Action_UseAbilityOnEntity(geomagneticGripAbility, saveTarget)
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
	geomagneticGripDesire, geomagneticGripTarget, geomagneticGripNeedsStone = X.ConsiderGeomagneticGrip()
	if geomagneticGripDesire > 0 then
		if geomagneticGripNeedsStone then
			bot:Action_ClearActions(false)
			bot:ActionQueue_UseAbilityOnLocation(stoneRemnantAbility, geomagneticGripTarget)
			bot:ActionQueue_UseAbilityOnLocation(geomagneticGripAbility, geomagneticGripTarget)
			return
		else
			-- The ally pull (a unit-target cast) is in X.ConsiderAllySave.
			bot:Action_UseAbilityOnLocation(geomagneticGripAbility, geomagneticGripTarget)
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
			LogES(
				"smash",
				"kill target=%s dist=%d",
				killableEnemy:GetUnitName(),
				math.floor(GetUnitToUnitDistance(bot, killableEnemy))
			)
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
			LogES(
				"smash",
				"engage target=%s dist=%d",
				botTarget:GetUnitName(),
				math.floor(GetUnitToUnitDistance(bot, botTarget))
			)
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
			if
				nearbyAllies ~= nil
				and nearbyEnemies ~= nil
				and #nearbyAllies <= 1
				and #nearbyEnemies <= 1
				and bot:IsFacingLocation(Fu.GetEscapeLoc(), 30)
			then
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
					if
						nearbyEnemies ~= nil
						and #nearbyEnemies >= 1
						and GetUnitToUnitDistance(creep, nearbyEnemies[1]) <= 600
					then
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
			local castLocation =
				Fu.GetCorrectLoc(killableEnemy, GetUnitToUnitDistance(bot, killableEnemy) / rockSpeed + delay)
			if IsStoneInPath(castLocation, GetUnitToUnitDistance(bot, killableEnemy)) then
				return BOT_ACTION_DESIRE_HIGH, castLocation, false
			else
				return BOT_ACTION_DESIRE_HIGH, castLocation, true
			end
		end
	elseif stoneCharges == 0 then
		local killableEnemy = Fu.GetCanBeKilledUnit(nearbyEnemies, damage, DAMAGE_TYPE_MAGICAL, false)
		if killableEnemy ~= nil and not Fu.IsSuspiciousIllusion(killableEnemy) then
			local castLocation =
				Fu.GetCorrectLoc(killableEnemy, GetUnitToUnitDistance(bot, killableEnemy) / rockSpeed + delay)
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
			if
				nearbyEnemies ~= nil
				and nearbyAllies ~= nil
				and (
					#nearbyAllies >= #nearbyEnemies
					or #nearbyEnemies > #nearbyAllies and Fu.WeAreStronger(bot, distance)
				)
			then
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
	if
		isRetreating
		or isRetreating and (alliesInRange ~= nil and nearbyEnemies ~= nil and #nearbyEnemies > #alliesInRange)
	then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, stoneRange, false, BOT_MODE_NONE)
		local escapeLocation = Fu.GetEscapeLoc()
		local castLocation = Fu.Site.GetXUnitsTowardsLocation(bot, escapeLocation, distance)
		if
			nearbyAllies ~= nil
			and nearbyEnemies ~= nil
			and (#nearbyEnemies > #nearbyAllies or #nearbyAllies >= #nearbyEnemies and Fu.GetHP(bot) < 0.45)
		then
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
	-- The ally save (pull) moved to X.ConsiderAllySave (#47): it fired 0 times in games 055, 057 and 058.
	local nearbyEnemies = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	local killableEnemy = Fu.GetCanBeKilledUnit(nearbyEnemies, rockDamage, DAMAGE_TYPE_MAGICAL, false)
	if
		killableEnemy ~= nil
		and Fu.CanCastOnNonMagicImmune(killableEnemy)
		and Fu.IsInRange(bot, killableEnemy, castRange)
		and not Fu.IsSuspiciousIllusion(killableEnemy)
	then
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
			and (Fu.CanKillTarget(botTarget, rockDamage, DAMAGE_TYPE_MAGICAL) or not botTarget:IsSilenced() and not Fu.IsDisabled(
				botTarget
			))
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
					if
						nearbyEnemies ~= nil
						and #nearbyEnemies >= 1
						and GetUnitToUnitDistance(creep, nearbyEnemies[1]) <= 600
					then
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
