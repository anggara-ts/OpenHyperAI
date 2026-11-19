-- Lookup table: site.
local function arrayForEach(self, callback, thisArg)
	for i = 1, #self do
		callback(thisArg, self[i], i - 1, self)
	end
end
local function objectValues(object)
	local values = {}
	local length = 0
	for key in pairs(object) do
		length = length + 1
		values[length] = object[key]
	end
	return values
end
local function countArgs(...)
	return select("#", ...)
end
local function arraySplice(self, ...)
	local args = { ... }
	local length = #self
	local argCount = countArgs(...)
	local start = args[1]
	local deleteCountArg = args[2]
	if start < 0 then
		start = length + start
		if start < 0 then
			start = 0
		end
	elseif start > length then
		start = length
	end
	local insertCount = argCount - 2
	if insertCount < 0 then
		insertCount = 0
	end
	local deleteCount
	if argCount == 0 then
		deleteCount = 0
	elseif argCount == 1 then
		deleteCount = length - start
	else
		deleteCount = deleteCountArg or 0
		if deleteCount < 0 then
			deleteCount = 0
		end
		if deleteCount > length - start then
			deleteCount = length - start
		end
	end
	local removed = {}
	for i = 1, deleteCount do
		local fromIndex = start + i
		if self[fromIndex] ~= nil then
			removed[i] = self[fromIndex]
		end
	end
	if insertCount < deleteCount then
		for i = start + 1, length - deleteCount do
			local fromIndex = i + deleteCount
			local toIndex = i + insertCount
			if self[fromIndex] then
				self[toIndex] = self[fromIndex]
			else
				self[toIndex] = nil
			end
		end
		for i = length - deleteCount + insertCount + 1, length do
			self[i] = nil
		end
	elseif insertCount > deleteCount then
		for i = length - deleteCount, start + 1, -1 do
			local fromIndex = i + deleteCount
			local toIndex = i + insertCount
			if self[fromIndex] then
				self[toIndex] = self[fromIndex]
			else
				self[toIndex] = nil
			end
		end
	end
	local insertIndex = start + 1
	for i = 3, argCount do
		self[insertIndex] = args[i]
		insertIndex = insertIndex + 1
	end
	for i = #self, length - deleteCount + insertCount + 1, -1 do
		self[i] = nil
	end
	return removed
end
local Site = {}
local Dota = require(GetScriptDirectory() .. "/FuncLib/dota/index")
local BotModeDesire = Dota.BotModeDesire
local UnitType = Dota.UnitType
local BotMode = Dota.BotMode
local Team = Dota.Team
local Tower = Dota.Tower
local Rune = Dota.Rune
local Shop = Dota.Shop
local Utils = require(GetScriptDirectory() .. "/FuncLib/systems/utils")
local HasItem = Utils.HasItem
local GetLocationToLocationDistance = Utils.GetLocationToLocationDistance
local GetOffsetLocationTowardsTargetLocation = Utils.GetOffsetLocationTowardsTargetLocation
local IsModeTurbo = Utils.IsModeTurbo
local IsValidCreep = Utils.IsValidCreep
local observerWardSpacing = 2000
local trueSightRadius = 1000
local radiantSecondMandatoryLocation = Vector(2606, -1547, 0)
local radiantTop3FallSpot = Vector(-6600, -3072, 0)
local radiantMid3FallSpot = Vector(-4314, -3887, 0)
local radiantBot3FallSpot = Vector(-3586, -6131, 0)
local radiantTop2FallSpot = Vector(-4345, -1018, 663)
local radiantMid2FallSpot = Vector(1283, -5109, 655)
local radiantBot2FallSpot = Vector(-514, -3321, 655)
local radiantTop1FallSpot = Vector(-4089, 1544, 535)
local radiantMid1FallSpot = Vector(2818, -3047, 655)
local radiantBot1FallSpot = Vector(5253, -4844, 0)
local radiantMandatorySpot1 = Vector(-1243, -200, 0)
local radiantMandatorySpot2 = radiantSecondMandatoryLocation
local direSecondMandatoryLocation = Vector(2606, -1547, 0)
local direTop3FallSpot = Vector(3087, 5690, 0)
local direMid3FallSpot = Vector(4024, 3445, 0)
local direBot3FallSpot = Vector(6354, 2606, 0)
local direTop2FallSpot = Vector(514, 4107, 655)
local direMid2FallSpot = Vector(2047, -769, 655)
local direBot2FallSpot = Vector(4620, 788, 655)
local direTop1FallSpot = Vector(-2815, 3565, 256)
local direMid1FallSpot = Vector(-760, 2053, 655)
local direBot1FallSpot = Vector(5122, -1930, 527)
local direMandatorySpot2 = direSecondMandatoryLocation
local direMandatorySpot1 = Vector(-463, 447, 0)
local radiantAggressiveSpot1 = direTop2FallSpot
local radiantAggressiveSpot2 = direMid1FallSpot
local radiantAggressiveSpot3 = direMid2FallSpot
local radiantAggressiveSpot4 = direBot2FallSpot
local direAggressiveSpot1 = radiantTop1FallSpot
local direAggressiveSpot2 = radiantTop2FallSpot
local direAggressiveSpot3 = radiantMid2FallSpot
local direAggressiveSpot4 = radiantBot2FallSpot
local radiantTowerFallSpots = {
	radiantTop1FallSpot,
	radiantMid1FallSpot,
	radiantBot1FallSpot,
	radiantTop2FallSpot,
	radiantMid2FallSpot,
	radiantBot2FallSpot,
	radiantTop3FallSpot,
	radiantMid3FallSpot,
	radiantBot3FallSpot,
}
local direTowerFallSpots = {
	direTop1FallSpot,
	direMid1FallSpot,
	direBot1FallSpot,
	direTop2FallSpot,
	direMid2FallSpot,
	direBot2FallSpot,
	direTop3FallSpot,
	direMid3FallSpot,
	direBot3FallSpot,
}
local campStackSpots = {
	Vector(1854, -4469, 0),
	Vector(1249, -2416, 0),
	Vector(3471, -5841, 0),
	Vector(5153, -3620, 0),
	Vector(-1846, -2996, 0),
	Vector(-4961, 559, 0),
	Vector(-3873, -833, 0),
	Vector(-3146, 702, 0),
	Vector(1141, -3111, 0),
	Vector(660, 2300, 0),
	Vector(3666, 1836, 0),
	Vector(482, 4723, 0),
	Vector(3173, -861, 0),
	Vector(-3443, 6098, 0),
	Vector(-4353, 4842, 0),
	Vector(-1083, 3385, 0),
	Vector(-922, 4299, 0),
	Vector(4136, -1753, 0),
}
local firstOutpost = nil
local secondOutpost = nil
local allUnits = GetUnitList(UnitType.All)
for _, unit in ipairs(allUnits) do
	if unit:GetUnitName() == "#DOTA_OutpostName_North" or unit:GetUnitName() == "#DOTA_OutpostName_South" then
		if firstOutpost == nil then
			firstOutpost = unit
		else
			secondOutpost = unit
		end
	end
end
Site.nWatchTowerList = { firstOutpost, secondOutpost }
Site.nTowerList = {
	Tower.Top1,
	Tower.Mid1,
	Tower.Bot1,
	Tower.Top2,
	Tower.Mid2,
	Tower.Bot2,
	Tower.Top3,
	Tower.Mid3,
	Tower.Bot3,
	Tower.Base1,
	Tower.Base2,
}
Site.nRuneList = { Rune.Power1, Rune.Power2, Rune.Bounty1, Rune.Bounty2 }
Site.nShopList = { Shop.Home, Shop.Side, Shop.Side2, Shop.Secret, Shop.Secret2 }
Site.top_power_rune = Vector(-1767, 1233, 0)
Site.bot_power_rune = Vector(2597, -2014, 0)
Site.roshan = Vector(2980, -2816, 0)
Site.dire_ancient = Vector(5517, 4981, 0)
Site.radiant_ancient = Vector(-5860, -5328, 0)
Site.radiant_base = Vector(-7200, -6666, 0)
Site.dire_base = Vector(7137, 6548, 0)
Site.GetDistance = function(locationA, locationB)
	return GetLocationToLocationDistance(locationA, locationB)
end
Site.GetXUnitsTowardsLocation = function(unit, targetLocation, distance)
	return GetOffsetLocationTowardsTargetLocation(unit:GetLocation(), targetLocation, distance)
end
Site.GetNearestWatchTower = function(bot)
	if GetUnitToUnitDistance(bot, firstOutpost) < GetUnitToUnitDistance(bot, secondOutpost) then
		return firstOutpost
	end
	return secondOutpost
end
Site.GetAllWatchTower = function()
	return Site.nWatchTowerList
end
Site.GetMandatorySpot = function()
	local radiantSpots = { radiantMandatorySpot1, radiantMandatorySpot2 }
	local direSpots = { direMandatorySpot2, direMandatorySpot1 }
	if DotaTime() < 2 * 60 then
		return GetTeam() == Team.Radiant and { radiantMandatorySpot1 } or { direMandatorySpot1 }
	end
	if DotaTime() > 12 * 60 then
		return GetTeam() == Team.Radiant
				and {
					radiantMandatorySpot1,
					radiantMandatorySpot2,
					radiantTop1FallSpot,
					radiantMid1FallSpot,
					radiantBot1FallSpot,
				}
			or { direMandatorySpot2, direMandatorySpot1, direTop1FallSpot, direMid1FallSpot, direBot1FallSpot }
	end
	return GetTeam() == Team.Radiant and radiantSpots or direSpots
end
Site.GetWardSpotWhenTowerFall = function()
	local wardSpots = {}
	do
		local i = 0
		while i < #Site.nTowerList do
			local tower = GetTower(GetTeam(), Site.nTowerList[i + 1])
			if not tower then
				wardSpots[#wardSpots + 1] = GetTeam() == Team.Radiant and radiantTowerFallSpots[i + 1]
					or direTowerFallSpots[i + 1]
			end
			i = i + 1
		end
	end
	return wardSpots
end
Site.GetAggressiveSpot = function()
	local direSpots = { direAggressiveSpot1, direAggressiveSpot2, direAggressiveSpot3, direAggressiveSpot4 }
	local radiantSpots =
		{ radiantAggressiveSpot1, radiantAggressiveSpot2, radiantAggressiveSpot3, radiantAggressiveSpot4 }
	return GetTeam() == Team.Radiant and radiantSpots or direSpots
end
Site.GetItemWard = function(bot)
	do
		local i = 0
		while i < 9 do
			local item = bot:GetItemInSlot(i)
			if
				item
				and (
					item:GetName() == "item_ward_observer"
					or item:GetName() == "item_ward_sentry"
					or item:GetName() == "item_ward_dispenser"
				)
			then
				return item
			end
			i = i + 1
		end
	end
	return nil
end
Site.GetAvailableSpot = function(bot)
	local availableSpots = {}
	if DotaTime() < 38 * 60 then
		arrayForEach(Site.GetMandatorySpot(), function(_, spot)
			if not Site.IsCloseToAvailableWard(spot) then
				availableSpots[#availableSpots + 1] = spot
			end
		end)
	end
	arrayForEach(Site.GetWardSpotWhenTowerFall(), function(_, spot)
		if not Site.IsCloseToAvailableWard(spot) then
			availableSpots[#availableSpots + 1] = spot
		end
	end)
	if DotaTime() > 10 * 60 then
		arrayForEach(Site.GetAggressiveSpot(), function(_, spot)
			if GetUnitToLocationDistance(bot, spot) <= 1200 and not Site.IsCloseToAvailableWard(spot) then
				availableSpots[#availableSpots + 1] = spot
			end
		end)
	end
	return availableSpots
end
Site.IsCloseToAvailableWard = function(location)
	local wards = GetUnitList(UnitType.AlliedWards)
	for _, ward in ipairs(wards) do
		if Site.IsObserver(ward) and GetUnitToLocationDistance(ward, location) <= observerWardSpacing then
			return true
		end
	end
	return false
end
Site.IsLocationHaveTrueSight = function(location)
	local wards = GetUnitList(UnitType.AlliedWards)
	for _, ward in ipairs(wards) do
		if Site.IsSentry(ward) and GetUnitToLocationDistance(ward, location) <= trueSightRadius then
			return true
		end
	end
	-- Our towers anywhere on the map (was only towers within 1600 of the bot, so a spot under a far
	-- tower looked uncovered and the ward mode walked a sentry there).
	for _, tower in ipairs(GetUnitList(UNIT_LIST_ALLIED_BUILDINGS) or {}) do
		if
			tower ~= nil
			and not tower:IsNull()
			and tower:IsAlive()
			and string.find(tower:GetUnitName(), "tower", 1, true) ~= nil
			and GetUnitToLocationDistance(tower, location) < trueSightRadius
		then
			return true
		end
	end
	return false
end
Site.GetClosestSpot = function(bot, spots)
	local closestSpot = nil
	local closestDistance = 100000
	for _, spot in ipairs(spots) do
		local distance = GetUnitToLocationDistance(bot, spot)
		if distance < closestDistance then
			closestDistance = distance
			closestSpot = spot
		end
	end
	return closestSpot, closestDistance
end
Site.IsObserver = function(ward)
	return ward:GetUnitName() == "npc_dota_observer_wards"
end
Site.IsSentry = function(ward)
	return ward:GetUnitName() == "npc_dota_sentry_wards"
end
Site.GetCampMoveToStack = function(campIndex)
	return campStackSpots[campIndex + 1]
end
Site.GetCampStackTime = function(camp)
	if camp.cattr.speed == "fast" then
		return 56
	elseif camp.cattr.speed == "slow" then
		return 55
	end
	return 56
end
-- Farm mode (mode_farm_generic.lua, switching to a closer camp) has called this since the base
-- import, but it never existed: every call crashed the farm Think (game 032: [OHA-ERROR] FARM_Run
-- "attempt to call field IsCampDangerous" from ~10:00 for every bot; before build 077 only
-- "error in error handling" showed). A camp with an enemy hero seen within 1200 of it in the last 5s.
Site.IsCampDangerous = function(bot, camp)
	if camp == nil or camp.cattr == nil or camp.cattr.location == nil then
		return false
	end
	local loc = camp.cattr.location
	for _, pid in ipairs(GetTeamPlayers(GetOpposingTeam()) or {}) do
		if IsHeroAlive(pid) then
			local info = GetHeroLastSeenInfo(pid)
			local lastSeen = info ~= nil and info[1] or nil
			if lastSeen ~= nil and lastSeen.time_since_seen <= 5 and (lastSeen.location - loc):Length2D() <= 1200 then
				return true
			end
		end
	end
	return false
end
Site.IsEnemyCamp = function(camp)
	return camp.team ~= GetTeam()
end
local campBehindGatesCache = {}
Site.IsCampBehindEnemyGates = function(camp)
	local cacheKey = camp.idx ~= nil and tostring(camp.idx)
		or (camp.cattr and camp.cattr.idx ~= nil and tostring(camp.cattr.idx) or nil)
	if cacheKey ~= nil and campBehindGatesCache[cacheKey] ~= nil then
		return campBehindGatesCache[cacheKey]
	end
	local campLocation
	if camp.cattr then
		campLocation = camp.cattr.location
	else
		campLocation = camp.location
	end
	local location = campLocation
	if not location then
		return false
	end
	local enemyTeam = GetTeam() == Team.Radiant and Team.Dire or Team.Radiant
	local enemyAncient = GetAncient(enemyTeam)
	if not enemyAncient then
		return false
	end
	local ancientLocation = enemyAncient:GetLocation()
	local deltaX = location.x - ancientLocation.x
	local deltaY = location.y - ancientLocation.y
	local isBehindGates
	if deltaX * deltaX + deltaY * deltaY > 5000 * 5000 then
		isBehindGates = false
	elseif GetTeam() == Team.Radiant then
		isBehindGates = location.x > 6500 or location.y > 6000
	else
		isBehindGates = location.x < -6500 or location.y < -6500
	end
	if cacheKey ~= nil then
		campBehindGatesCache[cacheKey] = isBehindGates
	end
	return isBehindGates
end
Site.IsAncientCamp = function(camp)
	return camp.type == "ancient"
end
Site.IsSmallCamp = function(camp)
	return camp.type == "small"
end
Site.IsMediumCamp = function(camp)
	return camp.type == "medium"
end
Site.IsLargeCamp = function(camp)
	return camp.type == "large"
end
Site.RefreshCamp = function(bot)
	local neutralSpawners = GetNeutralSpawners()
	local camps = {}
	local botLevel = bot:GetLevel()
	for _, spawner in ipairs(objectValues(neutralSpawners)) do
		do
			local shouldContinue
			repeat
				local camp = spawner
				if Site.IsCampBehindEnemyGates({ cattr = camp }) then
					shouldContinue = true
					break
				end
				if
					(botLevel <= 7 or bot:GetAttackDamage() <= 80)
					and not Site.IsEnemyCamp(camp)
					and not Site.IsLargeCamp(camp)
					and not Site.IsAncientCamp(camp)
				then
					camps[#camps + 1] = { idx = camp.idx, cattr = camp }
				elseif botLevel <= 11 and not Site.IsEnemyCamp(camp) and not Site.IsAncientCamp(camp) then
					camps[#camps + 1] = { idx = camp.idx, cattr = camp }
				elseif botLevel <= 14 and not Site.IsEnemyCamp(camp) then
					camps[#camps + 1] = { idx = camp.idx, cattr = camp }
				else
					camps[#camps + 1] = { idx = camp.idx, cattr = camp }
				end
				shouldContinue = true
			until true
			if not shouldContinue then
				break
			end
		end
	end
	return camps, #camps
end
Site.GetPosition = function(bot)
	if bot.assignedRole then
		return bot.assignedRole
	end
	return 1
end
Site.IsSpecialFarmer = function(bot)
	return Site.GetPosition(bot) == 1
end
Site.IsShouldFarmHero = function(bot)
	return Site.GetPosition(bot) <= 3
end
Site.HasArmorReduction = function(unit)
	return unit:HasModifier("modifier_templar_assassin_meld_armor")
		or unit:HasModifier("modifier_item_medallion_of_courage_armor_reduction")
		or unit:HasModifier("modifier_item_solar_crest_armor_reduction")
		or unit:HasModifier("modifier_slardar_amplify_damage")
end
Site.GetClosestNeutralSpwan = function(bot, camps)
	local closestDistance = 15000
	local closestCamp = nil
	for _, camp in ipairs(camps) do
		local distance = GetUnitToLocationDistance(bot, camp.cattr.location)
		if Site.IsEnemyCamp(camp) then
			distance = distance * 1.5
		end
		if
			Site.IsTheClosestOne(bot, camp.cattr.location)
			and distance < closestDistance
			and (not Site.IsAncientCamp(camp) or bot:GetLevel() >= 10 and bot:GetArmor() >= 6)
		then
			closestDistance = distance
			closestCamp = camp
		end
	end
	return closestCamp
end
Site.IsTheClosestOne = function(bot, location)
	local closestDistance = GetUnitToLocationDistance(bot, location)
	local closestBot = bot
	-- GetTeamMember takes a team slot (1-5), not a player ID (game 037 review).
	for slot = 1, #GetTeamPlayers(GetTeam()) do
		local teammate = GetTeamMember(slot)
		if teammate and teammate:IsAlive() and teammate:GetActiveMode() == BotMode.Farm then
			local teammateDistance = GetUnitToLocationDistance(teammate, location)
			if teammateDistance < closestDistance then
				closestDistance = teammateDistance
				closestBot = teammate
			end
		end
	end
	return closestBot == bot
end
Site.GetNearestCreep = function(creeps)
	if IsValidCreep(creeps[1]) then
		return creeps[1]
	end
	return nil
end
Site.GetMaxHPCreep = function(creeps)
	local maxHealth = 0
	local target = nil
	for _, creep in ipairs(creeps) do
		if not creep:IsNull() and Site.HasArmorReduction(creep) then
			return creep
		end
		if IsValidCreep(creep) and creep:GetHealth() > maxHealth then
			maxHealth = creep:GetHealth()
			target = creep
		end
	end
	return target
end
Site.GetMinHPCreep = function(creeps)
	local minHealth = 4000
	local target = nil
	for _, creep in ipairs(creeps) do
		if not creep:IsNull() and Site.HasArmorReduction(creep) then
			return creep
		end
		if IsValidCreep(creep) and creep:GetHealth() < minHealth then
			minHealth = creep:GetHealth()
			target = creep
		end
	end
	return target
end
Site.FindFarmNeutralTarget = function(creeps)
	local bot = GetBot()
	local botName = bot:GetUnitName()
	local target = nil
	if Site.ConsiderFarmNeutralType[botName] ~= nil then
		local farmType = Site.ConsiderFarmNeutralType[botName]()
		if farmType == "nearest" then
			target = Site.GetNearestCreep(creeps)
		elseif farmType == "maxHP" then
			target = Site.GetMaxHPCreep(creeps)
		else
			target = Site.GetMinHPCreep(creeps)
		end
	end
	if
		HasItem(bot, "item_bfury")
		or HasItem(bot, "item_maelstrom")
		or HasItem(bot, "item_mjollnir")
		or HasItem(bot, "item_radiance")
	then
		target = Site.GetMaxHPCreep(creeps)
	end
	return target or Site.GetMinHPCreep(creeps)
end
Site.ConsiderFarmNeutralType = {
	npc_dota_hero_templar_assassin = function()
		return "nearest"
	end,
	npc_dota_hero_sven = function()
		return "nearest"
	end,
	npc_dota_hero_drow_ranger = function()
		return "nearest"
	end,
	npc_dota_hero_phantom_lancer = function()
		return "nearest"
	end,
	npc_dota_hero_naga_siren = function()
		return "maxHP"
	end,
	npc_dota_hero_viper = function()
		return "maxHP"
	end,
	npc_dota_hero_huskar = function()
		return "maxHP"
	end,
	npc_dota_hero_phantom_assassin = function()
		local bot = GetBot()
		return HasItem(bot, "item_bfury") and "nearest" or "minHP"
	end,
	npc_dota_hero_medusa = function()
		local bot = GetBot()
		local splitShotAbility = bot:GetAbilityByName("medusa_split_shot")
		return splitShotAbility:IsTrained() and "maxHP" or "minHP"
	end,
	npc_dota_hero_luna = function()
		local bot = GetBot()
		local moonGlaiveAbility = bot:GetAbilityByName("luna_moon_glaive")
		return moonGlaiveAbility:IsTrained() and "maxHP" or "minHP"
	end,
	npc_dota_hero_tidehunter = function()
		local bot = GetBot()
		local anchorSmashAbility = bot:GetAbilityByName("tidehunter_anchor_smash")
		local ravageAbility = bot:GetAbilityByName("tidehunter_ravage")
		if
			anchorSmashAbility:IsTrained()
			and ravageAbility:IsTrained()
			and bot:GetMana() > ravageAbility:GetManaCost() + 200
		then
			return "maxHP"
		end
		return "minHP"
	end,
	npc_dota_hero_nevermore = function()
		local bot = GetBot()
		return bot:GetMana() > 200 and bot:GetLevel() >= 13 and "maxHP" or "minHP"
	end,
	npc_dota_hero_dragon_knight = function()
		return GetBot():GetAttackRange() > 330 and "maxHP" or "minHP"
	end,
}
Site.GetFarmLaneTarget = function(creeps)
	local bot = GetBot()
	local botName = bot:GetUnitName()
	local target = nil
	local nearbyLaneCreeps = bot:GetNearbyLaneCreeps(1000, false)
	if botName ~= "npc_dota_hero_medusa" and #nearbyLaneCreeps > 0 then
		target = Site.GetNearestCreep(creeps)
	end
	if botName == "npc_dota_hero_medusa" then
		target = Site.GetMinHPCreep(creeps)
	end
	return target or Site.GetMaxHPCreep(creeps)
end
Site.IsSuitableFarmMode = function(mode)
	return mode ~= BotMode.Rune
		and mode ~= BotMode.Attack
		and mode ~= BotMode.SecretShop
		and mode ~= BotMode.SideShop
		and mode ~= BotMode.DefendAlly
		and mode ~= BotMode.EvasiveManeuvers
end
Site.IsModeSuitableToFarm = function(bot)
	local mode = bot:GetActiveMode()
	local botLevel = bot:GetLevel()
	if
		botLevel <= 8
		and (
			mode == BotMode.PushTowerTop
			or mode == BotMode.PushTowerMid
			or mode == BotMode.PushTowerBot
			or mode == BotMode.Laning
		)
	then
		local enemyAncient = GetAncient(GetOpposingTeam())
		if GetUnitToUnitDistance(bot, enemyAncient) > 6300 then
			return false
		end
	end
	if
		Site.IsSpecialFarmer(bot)
		and botLevel >= 8
		and botLevel <= 24
		and Site.IsSuitableFarmMode(mode)
		and mode ~= BotMode.Roshan
		and mode ~= BotMode.TeamRoam
		and mode ~= BotMode.Laning
		and mode ~= BotMode.Ward
	then
		return true
	end
	if
		Site.IsSuitableFarmMode(mode)
		and mode ~= BotMode.Ward
		and mode ~= BotMode.Laning
		and mode ~= BotMode.DefendTowerTop
		and mode ~= BotMode.DefendTowerMid
		and mode ~= BotMode.DefendTowerBot
		and mode ~= BotMode.Assemble
		and mode ~= BotMode.TeamRoam
		and mode ~= BotMode.Roshan
		and botLevel >= 8
	then
		return true
	end
	return false
end
Site.IsTimeToFarm = function(bot)
	local farmStartTime = IsModeTurbo() and 3 * 60 or 5 * 60
	if DotaTime() < farmStartTime or DotaTime() > 90 * 60 then
		return false
	end
	local botName = bot:GetUnitName()
	if
		bot:GetActiveMode() == BotMode.PushTowerTop
		or bot:GetActiveMode() == BotMode.PushTowerMid
		or bot:GetActiveMode() == BotMode.PushTowerBot
	then
		local enemyAncient = GetAncient(GetOpposingTeam())
		local nearbyAllies = bot:GetNearbyHeroes(1400, false, BotMode.None)
		local distanceToEnemyAncient = GetUnitToUnitDistance(bot, enemyAncient)
		if
			distanceToEnemyAncient < 2800
			and distanceToEnemyAncient > 1400
			and bot:GetActiveModeDesire() < BotModeDesire.High
			and #nearbyAllies <= 1
		then
			return true
		end
		if Site.IsShouldFarmHero(bot) then
			if
				bot:GetActiveModeDesire() < BotModeDesire.Moderate
				and distanceToEnemyAncient > 1600
				and distanceToEnemyAncient < 5600
				and #nearbyAllies <= 1
			then
				return true
			end
		end
	end
	local isTimeToFarm = false
	local heroFarmCheck = Site.ConsiderIsTimeToFarm[botName]
	if heroFarmCheck ~= nil then
		isTimeToFarm = heroFarmCheck()
	end
	if not isTimeToFarm and Site.GetPosition(bot) <= 3 then
		local netWorth = bot:GetNetWorth()
		local botLevel = bot:GetLevel()
		if botLevel < 10 and netWorth < 5000 then
			isTimeToFarm = true
		elseif botLevel < 15 and netWorth < 10000 then
			isTimeToFarm = true
		elseif botLevel < 20 and netWorth < 16000 then
			isTimeToFarm = true
		elseif botLevel < 25 and netWorth < 21000 then
			isTimeToFarm = true
		end
	end
	return isTimeToFarm
end
Site.UpdateAvailableCamp = function(bot, currentCamp, camps)
	if currentCamp ~= nil then
		do
			local i = 0
			while i < #camps do
				if
					camps[i + 1].cattr.location == currentCamp.cattr.location
					or GetUnitToLocationDistance(bot, camps[i + 1].cattr.location) < 500
				then
					arraySplice(camps, i, 1)
					return camps, nil
				end
				i = i + 1
			end
		end
	end
	return camps, nil
end
local lastCommonCampUnit = nil
Site.UpdateCommonCamp = function(unit, camps)
	if lastCommonCampUnit ~= unit then
		lastCommonCampUnit = unit
		do
			local i = 0
			while i < #camps do
				if GetUnitToLocationDistance(unit, camps[i + 1].cattr.location) < 500 then
					arraySplice(camps, i, 1)
					return camps
				end
				i = i + 1
			end
		end
	end
	return camps
end
Site.GetAroundAllyCount = function(bot, radius)
	local allyCount = 0
	do
		local i = 1
		while i <= 5 do
			local teammate = GetTeamMember(i)
			if teammate and teammate:IsAlive() and GetUnitToUnitDistance(bot, teammate) <= radius then
				allyCount = allyCount + 1
			end
			i = i + 1
		end
	end
	return allyCount
end
Site.IsInLaningPhase = function()
	return IsModeTurbo() and DotaTime() < 8 * 60 or DotaTime() < 12 * 60
end
Site.ConsiderIsTimeToFarm = {}
Site.ConsiderIsTimeToFarm.npc_dota_hero_antimage = function()
	local bot = GetBot()
	local netWorth = bot:GetNetWorth()
	local gameTime = DotaTime()
	if gameTime > 9 * 60 and (bot:GetLevel() < 25 or netWorth < 23000) then
		return true
	end
	if not HasItem(bot, "item_black_king_bar") and netWorth < 18000 then
		return true
	end
	if not HasItem(bot, "item_satanic") and netWorth < 28000 then
		if Site.GetAroundAllyCount(bot, 1200) <= 2 then
			return true
		end
	end
	return false
end
Site.ConsiderIsTimeToFarm.npc_dota_hero_arc_warden = function()
	local bot = GetBot()
	local netWorth = bot:GetNetWorth()
	if DotaTime() > 15 * 60 and (bot:GetLevel() < 25 or netWorth < 22000) then
		return true
	end
	if HasItem(bot, "item_gloves") and not HasItem(bot, "item_hand_of_midas") and bot:GetGold() > 800 then
		return true
	end
	if HasItem(bot, "item_yasha") and not HasItem(bot, "item_manta") and bot:GetGold() > 1000 then
		return true
	end
	if HasItem(bot, "item_hand_of_midas") and Site.GetAroundAllyCount(bot, 1200) <= 3 and netWorth <= 26000 then
		return true
	end
	return false
end
Site.ConsiderIsTimeToFarm.npc_dota_hero_axe = function()
	local bot = GetBot()
	local netWorth = bot:GetNetWorth()
	if DotaTime() > 7 * 60 and (bot:GetLevel() < 25 or netWorth < 20000) then
		return true
	end
	if not HasItem(bot, "item_echo_sabre") and netWorth < 12000 then
		return true
	end
	if not HasItem(bot, "item_heart") and netWorth < 21000 then
		if Site.GetAroundAllyCount(bot, 1100) <= 1 then
			return true
		end
	end
	return false
end
Site.ConsiderIsTimeToFarm.npc_dota_hero_bloodseeker = function()
	local bot = GetBot()
	local netWorth = bot:GetNetWorth()
	if DotaTime() > 9 * 60 and (bot:GetLevel() < 25 or netWorth < 22000) then
		return true
	end
	if not HasItem(bot, "item_black_king_bar") and netWorth < 16000 then
		return true
	end
	if not HasItem(bot, "item_abyssal_blade") and netWorth < 26000 then
		if Site.GetAroundAllyCount(bot, 1200) <= 1 then
			return true
		end
	end
	return false
end
Site.ConsiderIsTimeToFarm.npc_dota_hero_bristleback = function()
	local bot = GetBot()
	local netWorth = bot:GetNetWorth()
	local kills = GetHeroKills(bot:GetPlayerID())
	local deaths = GetHeroDeaths(bot:GetPlayerID())
	local nearbyAllyCount = Site.GetAroundAllyCount(bot, 1200)
	if kills >= deaths + 4 and deaths <= 3 then
		return false
	end
	if bot:GetLevel() >= 10 and nearbyAllyCount <= 2 and netWorth < 15000 then
		return true
	end
	if bot:GetLevel() >= 20 and nearbyAllyCount <= 1 and netWorth < 21000 then
		return true
	end
	return false
end
Site.ConsiderIsTimeToFarm.npc_dota_hero_chaos_knight = function()
	return Site.ConsiderIsTimeToFarm.npc_dota_hero_bristleback()
end
Site.ConsiderIsTimeToFarm.npc_dota_hero_clinkz = function()
	return Site.ConsiderIsTimeToFarm.npc_dota_hero_templar_assassin()
end
Site.ConsiderIsTimeToFarm.npc_dota_hero_dragon_knight = function()
	local bot = GetBot()
	local netWorth = bot:GetNetWorth()
	if not HasItem(bot, "item_assault") and netWorth < 22000 then
		local nearbyAllyCount = Site.GetAroundAllyCount(bot, 1200)
		if bot:GetAttackRange() > 300 and nearbyAllyCount <= 2 then
			return true
		end
		if bot:GetMana() > 450 and bot:GetCurrentVisionRange() < 1000 and nearbyAllyCount < 2 then
			return true
		end
	end
	return false
end
Site.ConsiderIsTimeToFarm.npc_dota_hero_drow_ranger = function()
	local bot = GetBot()
	local netWorth = bot:GetNetWorth()
	if bot:GetLevel() >= 6 and (bot:GetLevel() < 25 or netWorth < 20000) then
		return true
	end
	if HasItem(bot, "item_mask_of_madness") and netWorth < 9999 then
		return true
	end
	if HasItem(bot, "item_blade_of_alacrity") and not HasItem(bot, "item_ultimate_scepter") then
		return true
	end
	if HasItem(bot, "item_shadow_amulet") and not HasItem(bot, "item_invis_sword") and bot:GetGold() > 400 then
		return true
	end
	if HasItem(bot, "item_yasha") and not HasItem(bot, "item_manta") and bot:GetGold() > 1000 then
		return true
	end
	if HasItem(bot, "item_ultimate_scepter") and netWorth < 23000 then
		if Site.GetAroundAllyCount(bot, 1100) <= 2 then
			return true
		end
	end
	return false
end
Site.ConsiderIsTimeToFarm.npc_dota_hero_huskar = function()
	local bot = GetBot()
	local netWorth = bot:GetNetWorth()
	if DotaTime() > 9 * 60 and (bot:GetLevel() < 25 or netWorth < 20000) then
		return true
	end
	if not HasItem(bot, "item_hurricane_pike") and netWorth < 18000 then
		return true
	end
	if not HasItem(bot, "item_black_king_bar") and netWorth < 26000 then
		if Site.GetAroundAllyCount(bot, 1100) < 2 then
			return true
		end
	end
	if bot:GetLevel() > 20 and netWorth < 23333 then
		if Site.GetAroundAllyCount(bot, 1100) <= 1 then
			return true
		end
	end
	return false
end
Site.ConsiderIsTimeToFarm.npc_dota_hero_juggernaut = function()
	local bot = GetBot()
	local netWorth = bot:GetNetWorth()
	if DotaTime() > 9 * 60 and (bot:GetLevel() < 25 or netWorth < 20000) then
		return true
	end
	if not HasItem(bot, "item_black_king_bar") and netWorth < 20000 then
		if Site.GetAroundAllyCount(bot, 1100) <= 2 then
			return true
		end
	end
	if not HasItem(bot, "item_satanic") and netWorth < 24000 then
		if Site.GetAroundAllyCount(bot, 1000) <= 1 then
			return true
		end
	end
	return false
end
Site.ConsiderIsTimeToFarm.npc_dota_hero_kunkka = function()
	return Site.ConsiderIsTimeToFarm.npc_dota_hero_bristleback()
end
Site.ConsiderIsTimeToFarm.npc_dota_hero_luna = function()
	return Site.ConsiderIsTimeToFarm.npc_dota_hero_huskar()
end
Site.ConsiderIsTimeToFarm.npc_dota_hero_mirana = function()
	return Site.ConsiderIsTimeToFarm.npc_dota_hero_templar_assassin()
end
Site.ConsiderIsTimeToFarm.npc_dota_hero_medusa = function()
	local bot = GetBot()
	local netWorth = bot:GetNetWorth()
	if DotaTime() > 9 * 60 and (bot:GetLevel() < 25 or netWorth < 20000) then
		return true
	end
	if not HasItem(bot, "item_black_king_bar") and netWorth < 16000 then
		return true
	end
	if not HasItem(bot, "item_satanic") and netWorth < 28000 then
		if Site.GetAroundAllyCount(bot, 1100) <= 1 then
			return true
		end
	end
	return false
end
Site.ConsiderIsTimeToFarm.npc_dota_hero_nevermore = function()
	local bot = GetBot()
	local netWorth = bot:GetNetWorth()
	if DotaTime() > 9 * 60 and (bot:GetLevel() < 25 or netWorth < 22000) then
		return true
	end
	if not HasItem(bot, "item_skadi") and netWorth < 16000 then
		return true
	end
	if not HasItem(bot, "item_sphere") and netWorth < 28000 then
		if Site.GetAroundAllyCount(bot, 1100) <= 2 then
			return true
		end
	end
	return false
end
Site.ConsiderIsTimeToFarm.npc_dota_hero_omniknight = function()
	return Site.ConsiderIsTimeToFarm.npc_dota_hero_bristleback()
end
Site.ConsiderIsTimeToFarm.npc_dota_hero_ogre_magi = function()
	return Site.ConsiderIsTimeToFarm.npc_dota_hero_bristleback()
end
Site.ConsiderIsTimeToFarm.npc_dota_hero_phantom_assassin = function()
	local bot = GetBot()
	local netWorth = bot:GetNetWorth()
	if DotaTime() > 9 * 60 and (bot:GetLevel() < 25 or netWorth < 20000) then
		return true
	end
	if not HasItem(bot, "item_desolator") and netWorth < 16000 then
		return true
	end
	if not HasItem(bot, "item_black_king_bar") and netWorth < 24000 then
		if Site.GetAroundAllyCount(bot, 1000) <= 2 then
			return true
		end
	end
	if not HasItem(bot, "item_satanic") and netWorth < 26000 then
		if Site.GetAroundAllyCount(bot, 1100) <= 1 then
			return true
		end
	end
	return false
end
Site.ConsiderIsTimeToFarm.npc_dota_hero_phantom_lancer = function()
	local bot = GetBot()
	local netWorth = bot:GetNetWorth()
	if DotaTime() > 9 * 60 and (bot:GetLevel() < 25 or netWorth < 23000) then
		return true
	end
	if not HasItem(bot, "item_skadi") and netWorth < 18000 then
		return true
	end
	if not HasItem(bot, "item_sphere") and netWorth < 22000 then
		if Site.GetAroundAllyCount(bot, 1300) <= 3 then
			return true
		end
	end
	if not HasItem(bot, "item_heart") and netWorth < 26000 then
		if Site.GetAroundAllyCount(bot, 1100) <= 1 then
			return true
		end
	end
	return false
end
Site.ConsiderIsTimeToFarm.npc_dota_hero_naga_siren = function()
	return Site.ConsiderIsTimeToFarm.npc_dota_hero_phantom_lancer()
end
Site.ConsiderIsTimeToFarm.npc_dota_hero_razor = function()
	local bot = GetBot()
	local netWorth = bot:GetNetWorth()
	if DotaTime() > 7 * 60 and (bot:GetLevel() < 25 or netWorth < 20000) then
		return true
	end
	if not HasItem(bot, "item_black_king_bar") and netWorth < 15000 then
		return true
	end
	if not HasItem(bot, "item_satanic") and netWorth < 25000 then
		if Site.GetAroundAllyCount(bot, 1100) <= 1 then
			return true
		end
	end
	return false
end
Site.ConsiderIsTimeToFarm.npc_dota_hero_sand_king = function()
	return Site.ConsiderIsTimeToFarm.npc_dota_hero_bristleback()
end
Site.ConsiderIsTimeToFarm.npc_dota_hero_slardar = function()
	return Site.ConsiderIsTimeToFarm.npc_dota_hero_bristleback()
end
Site.ConsiderIsTimeToFarm.npc_dota_hero_legion_commander = function()
	local bot = GetBot()
	local netWorth = bot:GetNetWorth()
	if DotaTime() > 7 * 60 and (bot:GetLevel() < 25 or netWorth < 20000) then
		return true
	end
	if not HasItem(bot, "item_echo_sabre") and netWorth < 12000 then
		return true
	end
	if not HasItem(bot, "item_heart") and netWorth < 21000 then
		if Site.GetAroundAllyCount(bot, 1100) <= 1 then
			return true
		end
	end
	return false
end
Site.ConsiderIsTimeToFarm.npc_dota_hero_slark = function()
	local bot = GetBot()
	local netWorth = bot:GetNetWorth()
	if DotaTime() > 9 * 60 and (bot:GetLevel() < 25 or netWorth < 20000) then
		return true
	end
	if not HasItem(bot, "item_invis_sword") and netWorth < 18000 then
		return true
	end
	if not HasItem(bot, "item_silver_edge") and netWorth < 21000 then
		if Site.GetAroundAllyCount(bot, 1100) <= 2 then
			return true
		end
	end
	if not HasItem(bot, "item_abyssal_blade") and netWorth < 25000 then
		if Site.GetAroundAllyCount(bot, 1300) <= 1 then
			return true
		end
	end
	return false
end
Site.ConsiderIsTimeToFarm.npc_dota_hero_skeleton_king = function()
	return Site.ConsiderIsTimeToFarm.npc_dota_hero_bristleback()
end
Site.ConsiderIsTimeToFarm.npc_dota_hero_sven = function()
	local bot = GetBot()
	local netWorth = bot:GetNetWorth()
	if DotaTime() > 9 * 60 and (bot:GetLevel() < 25 or netWorth < 20000) then
		return true
	end
	if not HasItem(bot, "item_black_king_bar") then
		return true
	end
	if not HasItem(bot, "item_satanic") and netWorth < 22000 then
		if Site.GetAroundAllyCount(bot, 1000) <= 2 then
			return true
		end
	end
	if not HasItem(bot, "item_greater_crit") and netWorth < 26000 then
		if Site.GetAroundAllyCount(bot, 1100) <= 1 then
			return true
		end
	end
	return false
end
Site.ConsiderIsTimeToFarm.npc_dota_hero_sniper = function()
	local bot = GetBot()
	local netWorth = bot:GetNetWorth()
	if bot:GetLevel() >= 10 and not HasItem(bot, "item_monkey_king_bar") and netWorth < 22000 then
		local kills = GetHeroKills(bot:GetPlayerID())
		local deaths = GetHeroDeaths(bot:GetPlayerID())
		if kills - 3 <= deaths and deaths > 2 and Site.GetAroundAllyCount(bot, 1200) <= 2 then
			return true
		end
	end
	return false
end
Site.ConsiderIsTimeToFarm.npc_dota_hero_templar_assassin = function()
	local bot = GetBot()
	local netWorth = bot:GetNetWorth()
	if DotaTime() > 9 * 60 and (bot:GetLevel() < 25 or netWorth < 20000) then
		return true
	end
	if not HasItem(bot, "item_black_king_bar") and netWorth < 16000 then
		return true
	end
	if not HasItem(bot, "item_hurricane_pike") and netWorth < 20000 then
		if Site.GetAroundAllyCount(bot, 1300) <= 3 then
			return true
		end
	end
	if not HasItem(bot, "item_satanic") and netWorth < 26000 then
		if Site.GetAroundAllyCount(bot, 1100) <= 1 then
			return true
		end
	end
	return false
end
Site.ConsiderIsTimeToFarm.npc_dota_hero_tidehunter = function()
	return Site.ConsiderIsTimeToFarm.npc_dota_hero_sven()
end
Site.ConsiderIsTimeToFarm.npc_dota_hero_viper = function()
	local bot = GetBot()
	local netWorth = bot:GetNetWorth()
	if bot:GetLevel() >= 10 and not HasItem(bot, "item_mjollnir") and netWorth < 20000 then
		local kills = GetHeroKills(bot:GetPlayerID())
		local deaths = GetHeroDeaths(bot:GetPlayerID())
		local nearbyAllyCount = Site.GetAroundAllyCount(bot, 1300)
		if kills - 4 <= deaths and deaths > 2 and nearbyAllyCount < 3 then
			return true
		end
		if bot:GetMana() > 650 and bot:GetCurrentVisionRange() < 1000 and nearbyAllyCount <= 1 then
			return true
		end
	end
	return false
end
Site.ConsiderIsTimeToFarm.npc_dota_hero_earthshaker = function()
	local bot = GetBot()
	local netWorth = bot:GetNetWorth()
	if not HasItem(bot, "item_blink") and netWorth < 8000 then
		return true
	end
	if not HasItem(bot, "item_ultimate_scepter") and netWorth < 16000 then
		return true
	end
	return false
end
Site.ConsiderIsTimeToFarm.npc_dota_hero_tiny = function()
	local bot = GetBot()
	local netWorth = bot:GetNetWorth()
	if DotaTime() > 10 * 60 and (bot:GetLevel() < 25 or netWorth < 22000) then
		return true
	end
	if not HasItem(bot, "item_echo_sabre") and netWorth < 12000 then
		return true
	end
	if not HasItem(bot, "item_silver_edge") and netWorth < 18000 then
		return true
	end
	return false
end
Site.ConsiderIsTimeToFarm.npc_dota_hero_beastmaster = function()
	local bot = GetBot()
	local netWorth = bot:GetNetWorth()
	local why = nil
	if not HasItem(bot, "item_helm_of_the_dominator") and netWorth < 14000 then
		why = "no-helm"
	elseif not HasItem(bot, "item_black_king_bar") and netWorth < 18000 then
		why = "no-bkb"
	end
	-- One line when the answer changes (#105: the farm-only switch had no log, so a game could not show it).
	if why ~= bot._bmFarmWhy then
		bot._bmFarmWhy = why
		pcall(
			print,
			string.format(
				"[OHA-FARM] t=%.0f beastmaster farm-rule %s nw=%d",
				DotaTime(),
				why ~= nil and ("on why=" .. why) or "off",
				netWorth
			)
		)
	end
	return why ~= nil
end
Site.ConsiderIsTimeToFarm.npc_dota_hero_rattletrap = function()
	local bot = GetBot()
	local netWorth = bot:GetNetWorth()
	if not HasItem(bot, "item_blade_mail") and netWorth < 8000 then
		return true
	end
	if not HasItem(bot, "item_aghanims_shard") and netWorth < 12000 then
		return true
	end
	return false
end
Site.ConsiderIsTimeToFarm.npc_dota_hero_alchemist = function()
	local bot = GetBot()
	local netWorth = bot:GetNetWorth()
	if bot:GetLevel() < 25 or netWorth < 35000 then
		return true
	end
	return false
end
Site.ConsiderIsTimeToFarm.npc_dota_hero_brewmaster = function()
	local bot = GetBot()
	local netWorth = bot:GetNetWorth()
	if not HasItem(bot, "item_blink") and netWorth < 8000 then
		return true
	end
	if not HasItem(bot, "item_ultimate_scepter") and netWorth < 16000 then
		return true
	end
	return false
end
Site.ConsiderIsTimeToFarm.npc_dota_hero_treant = function()
	local bot = GetBot()
	local netWorth = bot:GetNetWorth()
	if not HasItem(bot, "item_meteor_hammer") and netWorth < 8000 then
		return true
	end
	if not HasItem(bot, "item_blink") and netWorth < 12000 then
		return true
	end
	return false
end
Site.ConsiderIsTimeToFarm.npc_dota_hero_wisp = function()
	local bot = GetBot()
	local netWorth = bot:GetNetWorth()
	if not HasItem(bot, "item_mekansm") and netWorth < 6000 then
		return true
	end
	if not HasItem(bot, "item_guardian_greaves") and netWorth < 10000 then
		return true
	end
	return false
end
Site.ConsiderIsTimeToFarm.npc_dota_hero_centaur = function()
	local bot = GetBot()
	local netWorth = bot:GetNetWorth()
	if not HasItem(bot, "item_blink") and netWorth < 8000 then
		return true
	end
	if not HasItem(bot, "item_pipe") and netWorth < 14000 then
		return true
	end
	return false
end
Site.ConsiderIsTimeToFarm.npc_dota_hero_shredder = function()
	local bot = GetBot()
	local netWorth = bot:GetNetWorth()
	if not HasItem(bot, "item_bloodstone") and netWorth < 14000 then
		return true
	end
	if not HasItem(bot, "item_lotus_orb") and netWorth < 18000 then
		return true
	end
	return false
end
Site.ConsiderIsTimeToFarm.npc_dota_hero_tusk = function()
	local bot = GetBot()
	local netWorth = bot:GetNetWorth()
	if not HasItem(bot, "item_blink") and netWorth < 8000 then
		return true
	end
	if not HasItem(bot, "item_desolator") and netWorth < 14000 then
		return true
	end
	return false
end
Site.ConsiderIsTimeToFarm.npc_dota_hero_elder_titan = function()
	local bot = GetBot()
	local netWorth = bot:GetNetWorth()
	if not HasItem(bot, "item_spirit_vessel") and netWorth < 8000 then
		return true
	end
	if not HasItem(bot, "item_blink") and netWorth < 12000 then
		return true
	end
	return false
end
Site.ConsiderIsTimeToFarm.npc_dota_hero_earth_spirit = function()
	local bot = GetBot()
	local netWorth = bot:GetNetWorth()
	if not HasItem(bot, "item_spirit_vessel") and netWorth < 8000 then
		return true
	end
	if not HasItem(bot, "item_blink") and netWorth < 12000 then
		return true
	end
	return false
end
Site.ConsiderIsTimeToFarm.npc_dota_hero_phoenix = function()
	local bot = GetBot()
	local netWorth = bot:GetNetWorth()
	if not HasItem(bot, "item_mekansm") and netWorth < 6000 then
		return true
	end
	if not HasItem(bot, "item_shivas_guard") and netWorth < 14000 then
		return true
	end
	return false
end
Site.ConsiderIsTimeToFarm.npc_dota_hero_mars = function()
	local bot = GetBot()
	local netWorth = bot:GetNetWorth()
	if not HasItem(bot, "item_blink") and netWorth < 8000 then
		return true
	end
	if not HasItem(bot, "item_black_king_bar") and netWorth < 14000 then
		return true
	end
	return false
end
Site.ConsiderIsTimeToFarm.npc_dota_hero_abyssal_underlord = function()
	local bot = GetBot()
	local netWorth = bot:GetNetWorth()
	if not HasItem(bot, "item_pipe") and netWorth < 10000 then
		return true
	end
	if not HasItem(bot, "item_guardian_greaves") and netWorth < 14000 then
		return true
	end
	return false
end
Site.ConsiderIsTimeToFarm.npc_dota_hero_snapfire = function()
	local bot = GetBot()
	local netWorth = bot:GetNetWorth()
	if not HasItem(bot, "item_aether_lens") and netWorth < 6000 then
		return true
	end
	if not HasItem(bot, "item_solar_crest") and netWorth < 10000 then
		return true
	end
	return false
end
Site.ConsiderIsTimeToFarm.npc_dota_hero_dawnbreaker = function()
	local bot = GetBot()
	local netWorth = bot:GetNetWorth()
	if not HasItem(bot, "item_echo_sabre") and netWorth < 8000 then
		return true
	end
	if not HasItem(bot, "item_desolator") and netWorth < 14000 then
		return true
	end
	return false
end
Site.ConsiderIsTimeToFarm.npc_dota_hero_primal_beast = function()
	local bot = GetBot()
	local netWorth = bot:GetNetWorth()
	if not HasItem(bot, "item_vanguard") and netWorth < 6000 then
		return true
	end
	if not HasItem(bot, "item_blink") and netWorth < 10000 then
		return true
	end
	return false
end
Site.ConsiderIsTimeToFarm.npc_dota_hero_marci = function()
	local bot = GetBot()
	local netWorth = bot:GetNetWorth()
	if not HasItem(bot, "item_armlet") and netWorth < 6000 then
		return true
	end
	if not HasItem(bot, "item_black_king_bar") and netWorth < 14000 then
		return true
	end
	return false
end
Site.ConsiderIsTimeToFarm.npc_dota_hero_bounty_hunter = function()
	local bot = GetBot()
	local netWorth = bot:GetNetWorth()
	if not HasItem(bot, "item_spirit_vessel") and netWorth < 8000 then
		return true
	end
	if not HasItem(bot, "item_guardian_greaves") and netWorth < 12000 then
		return true
	end
	return false
end
Site.ConsiderIsTimeToFarm.npc_dota_hero_broodmother = function()
	local bot = GetBot()
	local netWorth = bot:GetNetWorth()
	if bot:GetLevel() < 25 or netWorth < 25000 then
		return true
	end
	return false
end
Site.ConsiderIsTimeToFarm.npc_dota_hero_ember_spirit = function()
	local bot = GetBot()
	local netWorth = bot:GetNetWorth()
	if not HasItem(bot, "item_maelstrom") and netWorth < 12000 then
		return true
	end
	if not HasItem(bot, "item_black_king_bar") and netWorth < 18000 then
		return true
	end
	if netWorth < 25000 then
		return true
	end
	return false
end
Site.ConsiderIsTimeToFarm.npc_dota_hero_faceless_void = function()
	local bot = GetBot()
	local netWorth = bot:GetNetWorth()
	if not HasItem(bot, "item_mask_of_madness") and netWorth < 6000 then
		return true
	end
	if not HasItem(bot, "item_maelstrom") and netWorth < 10000 then
		return true
	end
	if netWorth < 22000 then
		return true
	end
	return false
end
Site.ConsiderIsTimeToFarm.npc_dota_hero_gyrocopter = function()
	local bot = GetBot()
	local netWorth = bot:GetNetWorth()
	if bot:GetLevel() < 25 or netWorth < 22000 then
		return true
	end
	return false
end
Site.ConsiderIsTimeToFarm.npc_dota_hero_hoodwink = function()
	local bot = GetBot()
	local netWorth = bot:GetNetWorth()
	if not HasItem(bot, "item_maelstrom") and netWorth < 12000 then
		return true
	end
	if not HasItem(bot, "item_gleipnir") and netWorth < 18000 then
		return true
	end
	return false
end
Site.ConsiderIsTimeToFarm.npc_dota_hero_lone_druid = function()
	local bot = GetBot()
	local netWorth = bot:GetNetWorth()
	if netWorth < 20000 then
		return true
	end
	return false
end
Site.ConsiderIsTimeToFarm.npc_dota_hero_meepo = function()
	local bot = GetBot()
	local netWorth = bot:GetNetWorth()
	if bot:GetLevel() < 25 or netWorth < 24000 then
		return true
	end
	return false
end
Site.ConsiderIsTimeToFarm.npc_dota_hero_monkey_king = function()
	local bot = GetBot()
	local netWorth = bot:GetNetWorth()
	if not HasItem(bot, "item_echo_sabre") and netWorth < 8000 then
		return true
	end
	if not HasItem(bot, "item_black_king_bar") and netWorth < 16000 then
		return true
	end
	if netWorth < 24000 then
		return true
	end
	return false
end
Site.ConsiderIsTimeToFarm.npc_dota_hero_morphling = function()
	local bot = GetBot()
	local netWorth = bot:GetNetWorth()
	if bot:GetLevel() < 25 or netWorth < 26000 then
		return true
	end
	return false
end
Site.ConsiderIsTimeToFarm.npc_dota_hero_nyx_assassin = function()
	local bot = GetBot()
	local netWorth = bot:GetNetWorth()
	if not HasItem(bot, "item_blink") and netWorth < 8000 then
		return true
	end
	if not HasItem(bot, "item_ultimate_scepter") and netWorth < 14000 then
		return true
	end
	return false
end
Site.ConsiderIsTimeToFarm.npc_dota_hero_pangolier = function()
	local bot = GetBot()
	local netWorth = bot:GetNetWorth()
	if not HasItem(bot, "item_maelstrom") and netWorth < 12000 then
		return true
	end
	if not HasItem(bot, "item_blink") and netWorth < 16000 then
		return true
	end
	return false
end
Site.ConsiderIsTimeToFarm.npc_dota_hero_riki = function()
	local bot = GetBot()
	local netWorth = bot:GetNetWorth()
	if not HasItem(bot, "item_diffusal_blade") and netWorth < 10000 then
		return true
	end
	if not HasItem(bot, "item_abyssal_blade") and netWorth < 18000 then
		return true
	end
	return false
end
Site.ConsiderIsTimeToFarm.npc_dota_hero_spectre = function()
	local bot = GetBot()
	local netWorth = bot:GetNetWorth()
	if not HasItem(bot, "item_radiance") and netWorth < 15000 then
		return true
	end
	if not HasItem(bot, "item_manta") and netWorth < 20000 then
		return true
	end
	if netWorth < 28000 then
		return true
	end
	return false
end
Site.ConsiderIsTimeToFarm.npc_dota_hero_terrorblade = function()
	local bot = GetBot()
	local netWorth = bot:GetNetWorth()
	if not HasItem(bot, "item_manta") and netWorth < 16000 then
		return true
	end
	if not HasItem(bot, "item_skadi") and netWorth < 22000 then
		return true
	end
	if netWorth < 30000 then
		return true
	end
	return false
end
Site.ConsiderIsTimeToFarm.npc_dota_hero_troll_warlord = function()
	local bot = GetBot()
	local netWorth = bot:GetNetWorth()
	if not HasItem(bot, "item_maelstrom") and netWorth < 10000 then
		return true
	end
	if not HasItem(bot, "item_black_king_bar") and netWorth < 16000 then
		return true
	end
	if netWorth < 24000 then
		return true
	end
	return false
end
Site.ConsiderIsTimeToFarm.npc_dota_hero_kez = function()
	local bot = GetBot()
	local netWorth = bot:GetNetWorth()
	if not HasItem(bot, "item_maelstrom") and netWorth < 10000 then
		return true
	end
	if not HasItem(bot, "item_black_king_bar") and netWorth < 16000 then
		return true
	end
	if netWorth < 24000 then
		return true
	end
	return false
end
Site.ConsiderIsTimeToFarm.npc_dota_hero_ursa = function()
	local bot = GetBot()
	local netWorth = bot:GetNetWorth()
	if not HasItem(bot, "item_blink") and netWorth < 8000 then
		return true
	end
	if not HasItem(bot, "item_black_king_bar") and netWorth < 14000 then
		return true
	end
	if netWorth < 22000 then
		return true
	end
	return false
end
Site.ConsiderIsTimeToFarm.npc_dota_hero_vengefulspirit = function()
	local bot = GetBot()
	local netWorth = bot:GetNetWorth()
	if Site.GetPosition(bot) >= 4 and netWorth < 8000 then
		return true
	end
	return false
end
Site.ConsiderIsTimeToFarm.npc_dota_hero_venomancer = function()
	local bot = GetBot()
	local netWorth = bot:GetNetWorth()
	if Site.GetPosition(bot) >= 4 and netWorth < 8000 then
		return true
	end
	return false
end
Site.ConsiderIsTimeToFarm.npc_dota_hero_weaver = function()
	local bot = GetBot()
	local netWorth = bot:GetNetWorth()
	if not HasItem(bot, "item_maelstrom") and netWorth < 12000 then
		return true
	end
	if not HasItem(bot, "item_black_king_bar") and netWorth < 18000 then
		return true
	end
	return false
end
Site.ConsiderIsTimeToFarm.npc_dota_hero_ringmaster = function()
	local bot = GetBot()
	local netWorth = bot:GetNetWorth()
	if not HasItem(bot, "item_ethereal_blade") and netWorth < 15000 then
		return true
	end
	if not HasItem(bot, "item_dagon_5") and netWorth < 22000 then
		return true
	end
	return false
end
return Site
