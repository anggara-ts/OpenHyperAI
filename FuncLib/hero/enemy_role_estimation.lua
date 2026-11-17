-- Hero-specific helper: enemy role estimation.
local function objectValues(object)
	local result = {}
	local count = 0
	for key in pairs(object) do
		count = count + 1
		result[count] = object[key]
	end
	return result
end
local function arraySort(self, compareFn)
	if compareFn ~= nil then
		table.sort(self, function(left, right)
			return compareFn(nil, left, right) < 0
		end)
	else
		table.sort(self)
	end
	return self
end
local function arrayMap(self, callbackFn, thisArg)
	local result = {}
	for i = 1, #self do
		result[i] = callbackFn(thisArg, self[i], i - 1, self)
	end
	return result
end
local function countVarargs(...)
	return select("#", ...)
end
local function packSpread(...)
	local packed = { ... }
	packed.sparseLength = countVarargs(...)
	return packed
end
local function appendSpread(packed, ...)
	local values = { ... }
	local valueCount = countVarargs(...)
	local length = packed.sparseLength
	for i = 1, valueCount do
		packed[length + i] = values[i]
	end
	packed.sparseLength = length + valueCount
end
local function unpackSpread(packed)
	local unpackFn = unpack or table.unpack
	return unpackFn(packed, 1, packed.sparseLength)
end
local EnemyRoleEstimation = {}
local calculateNetWorth, calculateOffensivePower, normalizeScores, OFFENSIVE_ITEM_VALUES, NET_WORTH_WEIGHT, OFFENSIVE_POWER_WEIGHT, LEVEL_WEIGHT
local Dota = require(GetScriptDirectory() .. "/ts_libs/dota/index")
local UnitType = Dota.UnitType
local AttributeType = Dota.AttributeType
local Utils = require(GetScriptDirectory() .. "/FuncLib/systems/utils")
local IsValidHero = Utils.IsValidHero
function calculateNetWorth(hero)
	local netWorth = 0
	do
		local slot = 0
		while slot <= 15 do
			local item = hero:GetItemInSlot(slot)
			if item ~= nil then
				netWorth = netWorth + GetItemCost(item:GetName())
			end
			slot = slot + 1
		end
	end
	return netWorth
end
function calculateOffensivePower(hero)
	local power = 0
	power = power + hero:GetAttackDamage()
	local primaryAttribute = hero:GetPrimaryAttribute()
	if primaryAttribute == AttributeType.Strength then
		power = power + hero:GetAttributeValue(AttributeType.Strength) * 2
	elseif primaryAttribute == AttributeType.Agility then
		power = power + hero:GetAttributeValue(AttributeType.Agility) * 2
	elseif primaryAttribute == AttributeType.Intellect then
		power = power + hero:GetAttributeValue(AttributeType.Intellect) * 2
	elseif primaryAttribute == AttributeType.All then
		power = power
			+ hero:GetAttributeValue(AttributeType.Strength) * 0.7
			+ hero:GetAttributeValue(AttributeType.Agility) * 0.7
			+ hero:GetAttributeValue(AttributeType.Intellect) * 0.7
	end
	do
		local slot = 0
		while slot <= 8 do
			local item = hero:GetItemInSlot(slot)
			if item ~= nil then
				local itemName = item:GetName()
				local itemValue = OFFENSIVE_ITEM_VALUES[itemName]
				if itemValue ~= nil then
					power = power + itemValue
				end
			end
			slot = slot + 1
		end
	end
	return power
end
function normalizeScores(heroInfos)
	local netWorths = arrayMap(heroInfos, function(_, info)
		return info.netWorth
	end)
	local offensivePowers = arrayMap(heroInfos, function(_, info)
		return info.offensivePower
	end)
	local levels = arrayMap(heroInfos, function(_, info)
		return info.level
	end)
	local netWorthArgs = packSpread(unpack(netWorths))
	appendSpread(netWorthArgs, 1)
	local maxNetWorth = math.max(unpackSpread(netWorthArgs))
	local powerArgs = packSpread(unpack(offensivePowers))
	appendSpread(powerArgs, 1)
	local maxPower = math.max(unpackSpread(powerArgs))
	local levelArgs = packSpread(unpack(levels))
	appendSpread(levelArgs, 1)
	local maxLevel = math.max(unpackSpread(levelArgs))
	for _, info in ipairs(heroInfos) do
		local netWorthScore = info.netWorth / maxNetWorth
		local powerScore = info.offensivePower / maxPower
		local levelScore = info.level / maxLevel
		info.totalScore = netWorthScore * NET_WORTH_WEIGHT
			+ powerScore * OFFENSIVE_POWER_WEIGHT
			+ levelScore * LEVEL_WEIGHT
	end
end
local heroInfoByPlayer = {}
local positionByPlayer = {}
local lastUpdateTime = 0
local UPDATE_INTERVAL = 5
OFFENSIVE_ITEM_VALUES = {
	item_desolator = 60,
	item_desolator_2 = 80,
	item_daedalus = 88,
	item_greater_crit = 88,
	item_bfury = 55,
	item_monkey_king_bar = 66,
	item_satanic = 25,
	item_butterfly = 30,
	item_abyssal_blade = 25,
	item_nullifier = 80,
	item_radiance = 60,
	item_bloodthorn = 70,
	item_silver_edge = 52,
	item_ethereal_blade = 40,
	item_rapier = 150,
	item_revenants_brooch = 45,
	item_overwhelming_blink = 25,
	item_swift_blink = 25,
	item_arcane_blink = 25,
	item_ultimate_scepter = 20,
	item_ultimate_scepter_2 = 20,
	item_aeon_disk = 10,
	item_kaya = 16,
	item_kaya_and_sange = 24,
	item_yasha_and_kaya = 24,
	item_moon_shard = 60,
	item_dragon_lance = 14,
	item_hurricane_pike = 20,
	item_orchid = 25,
	item_dagon_5 = 50,
	item_fallen_sky = 25,
	item_pirate_hat = 80,
	item_stormcrafter = 20,
}
NET_WORTH_WEIGHT = 0.3
OFFENSIVE_POWER_WEIGHT = 0.3
LEVEL_WEIGHT = 0.4
local function updateHeroInfos(heroes)
	for _, hero in ipairs(heroes) do
		if IsValidHero(hero) then
			local netWorth = calculateNetWorth(hero)
			local offensivePower = calculateOffensivePower(hero)
			local level = hero:GetLevel()
			local playerId = hero:GetPlayerID()
			local totalScore = netWorth * NET_WORTH_WEIGHT
				+ offensivePower * OFFENSIVE_POWER_WEIGHT
				+ level * LEVEL_WEIGHT
			heroInfoByPlayer[playerId] = {
				hero = hero,
				netWorth = netWorth,
				offensivePower = offensivePower,
				level = level,
				totalScore = totalScore,
			}
		end
	end
end
local function estimatePositions()
	local heroInfos = {}
	for _, info in ipairs(objectValues(heroInfoByPlayer)) do
		heroInfos[#heroInfos + 1] = info
	end
	normalizeScores(heroInfos)
	arraySort(heroInfos, function(_, left, right)
		return right.totalScore - left.totalScore
	end)
	do
		local index = 0
		while index < #heroInfos do
			local info = heroInfos[index + 1]
			local position = index + 1
			if position > 5 then
				position = 5
			end
			if IsValidHero(info.hero) then
				positionByPlayer[info.hero:GetPlayerID()] = position
			end
			index = index + 1
		end
	end
	return positionByPlayer
end
function EnemyRoleEstimation.UpdateEnemyHeroPositions()
	if DotaTime() - lastUpdateTime > UPDATE_INTERVAL then
		lastUpdateTime = DotaTime()
		local enemyHeroes = GetUnitList(UnitType.EnemyHeroes)
		updateHeroInfos(enemyHeroes)
		estimatePositions()
	end
end
function EnemyRoleEstimation.GetEnemyPosition(playerId)
	return positionByPlayer[playerId]
end
return EnemyRoleEstimation
