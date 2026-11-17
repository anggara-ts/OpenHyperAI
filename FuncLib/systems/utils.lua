-- Shared bot system: utils.
local function objectEntries(object)
	local result = {}
	local count = 0
	for key in pairs(object) do
		count = count + 1
		result[count] = { key, object[key] }
	end
	return result
end
local createSymbol, Symbol
do
	local symbolMetatable = {
		__tostring = function(self)
			return ("Symbol(" .. (self.description or "")) .. ")"
		end,
	}
	function createSymbol(description)
		return setmetatable({ description = description }, symbolMetatable)
	end
	Symbol = {
		asyncDispose = createSymbol("Symbol.asyncDispose"),
		dispose = createSymbol("Symbol.dispose"),
		iterator = createSymbol("Symbol.iterator"),
		hasInstance = createSymbol("Symbol.hasInstance"),
		species = createSymbol("Symbol.species"),
		toStringTag = createSymbol("Symbol.toStringTag"),
	}
end
local function arrayEntries(array)
	local index = 0
	return {
		[Symbol.iterator] = function(self)
			return self
		end,
		next = function(self)
			local result = { done = array[index + 1] == nil, value = { index, array[index + 1] } }
			index = index + 1
			return result
		end,
	}
end
local iterate
do
	local function iteratorGeneratorStep(self)
		local coroutineObject = self.____coroutine
		local ok, value = coroutine.resume(coroutineObject)
		if not ok then
			error(value, 0)
		end
		if coroutine.status(coroutineObject) == "dead" then
			return
		end
		return true, value
	end
	local function iteratorIteratorStep(self)
		local result = self:next()
		if result.done then
			return
		end
		return true, result.value
	end
	local function iteratorStringStep(self, index)
		index = index + 1
		if index > #self then
			return
		end
		return index, string.sub(self, index, index)
	end
	function iterate(iterable)
		if type(iterable) == "string" then
			return iteratorStringStep, iterable, 0
		elseif iterable.____coroutine ~= nil then
			return iteratorGeneratorStep, iterable
		elseif iterable[Symbol.iterator] then
			local iterator = iterable[Symbol.iterator](iterable)
			return iteratorIteratorStep, iterator
		else
			return ipairs(iterable)
		end
	end
end
local function numberToFixed(self, fractionDigits)
	if math.abs(self) >= 1e+21 or self ~= self then
		return tostring(self)
	end
	local digits = math.floor(fractionDigits or 0)
	if digits < 0 or digits > 99 then
		error("toFixed() digits argument must be between 0 and 99", 0)
	end
	return string.format(("%." .. tostring(digits)) .. "f", self)
end
local function stringEndsWith(self, searchString, endPosition)
	if endPosition == nil or endPosition > #self then
		endPosition = #self
	end
	return string.sub(self, endPosition - #searchString + 1, endPosition) == searchString
end
local function stringIncludes(self, searchString, position)
	if not position then
		position = 1
	else
		position = position + 1
	end
	local index = string.find(self, searchString, position, true)
	return index ~= nil
end
local function newInstance(Class, ...)
	local instance = setmetatable({}, Class.prototype)
	instance:____constructor(...)
	return instance
end
local function createClass(self)
	local Class = { prototype = {} }
	Class.prototype.__index = Class.prototype
	Class.prototype.constructor = Class
	return Class
end
local function classExtends(Target, Base)
	Target.____super = Base
	local staticMetatable = setmetatable({ __index = Base }, Base)
	setmetatable(Target, staticMetatable)
	local baseMetatable = getmetatable(Base)
	if baseMetatable then
		if type(baseMetatable.__index) == "function" then
			staticMetatable.__index = baseMetatable.__index
		end
		if type(baseMetatable.__newindex) == "function" then
			staticMetatable.__newindex = baseMetatable.__newindex
		end
	end
	setmetatable(Target.prototype, Base.prototype)
	if type(Base.prototype.__index) == "function" then
		Target.prototype.__index = Base.prototype.__index
	end
	if type(Base.prototype.__newindex) == "function" then
		Target.prototype.__newindex = Base.prototype.__newindex
	end
	if type(Base.prototype.__tostring) == "function" then
		Target.prototype.__tostring = Base.prototype.__tostring
	end
end
local Error, TypeError
do
	local function getErrorStack(self, constructor)
		if debug == nil then
			return nil
		end
		local level = 1
		while true do
			local info = debug.getinfo(level, "f")
			level = level + 1
			if not info then
				level = 1
				break
			elseif info.func == constructor then
				break
			end
		end
		if stringIncludes(_VERSION, "Lua 5.0") then
			return debug.traceback(("[Level " .. tostring(level)) .. "]")
		else
			return debug.traceback(nil, level)
		end
	end
	local function wrapErrorToString(self, toStringFn)
		return function(self)
			local description = toStringFn(self)
			local caller = debug.getinfo(3, "f")
			local isClassicLua = stringIncludes(_VERSION, "Lua 5.0") or _VERSION == "Lua 5.1"
			if isClassicLua or caller and caller.func ~= error then
				return description
			else
				return (description .. "\n") .. tostring(self.stack)
			end
		end
	end
	local function initErrorClass(self, Type, name)
		Type.name = name
		return setmetatable(Type, {
			__call = function(_, _self, message)
				return newInstance(Type, message)
			end,
		})
	end
	local createErrorClass = initErrorClass
	local ErrorClass = createClass()
	ErrorClass.name = ""
	function ErrorClass.prototype.____constructor(self, message)
		if message == nil then
			message = ""
		end
		self.message = message
		self.name = "Error"
		self.stack = getErrorStack(nil, self.constructor.new)
		local metatable = getmetatable(self)
		if metatable and not metatable.__errorToStringPatched then
			metatable.__errorToStringPatched = true
			metatable.__tostring = wrapErrorToString(nil, metatable.__tostring)
		end
	end
	function ErrorClass.prototype.__tostring(self)
		return self.message ~= "" and (self.name .. ": ") .. self.message or self.name
	end
	Error = createErrorClass(nil, ErrorClass, "Error")
	local function createDerivedErrorClass(self, name)
		local initClass = initErrorClass
		local DerivedError = createClass()
		DerivedError.name = DerivedError.name
		classExtends(DerivedError, Error)
		function DerivedError.prototype.____constructor(self, ...)
			DerivedError.____super.prototype.____constructor(self, ...)
			self.name = name
		end
		return initClass(nil, DerivedError, name)
	end
	TypeError = createDerivedErrorClass(nil, "TypeError")
end
local function getDescriptors(target)
	local metatable = getmetatable(target)
	if not metatable then
		return {}
	end
	return rawget(metatable, "_descriptors") or {}
end
local function deleteProperty(target, key)
	local descriptors = getDescriptors(target)
	local descriptor = descriptors[key]
	if descriptor then
		if not descriptor.configurable then
			error(
				newInstance(
					TypeError,
					((("Cannot delete property " .. tostring(key)) .. " of ") .. tostring(target)) .. "."
				),
				0
			)
		end
		descriptors[key] = nil
		return true
	end
	target[key] = nil
	return true
end
local Set
do
	Set = createClass()
	Set.name = "Set"
	function Set.prototype.____constructor(self, values)
		self[Symbol.toStringTag] = "Set"
		self.size = 0
		self.nextKey = {}
		self.previousKey = {}
		if values == nil then
			return
		end
		local iterable = values
		if iterable[Symbol.iterator] then
			local iterator = iterable[Symbol.iterator](iterable)
			while true do
				local result = iterator:next()
				if result.done then
					break
				end
				self:add(result.value)
			end
		else
			local array = values
			for _, value in ipairs(array) do
				self:add(value)
			end
		end
	end
	function Set.prototype.add(self, value)
		local isNewValue = not self:has(value)
		if isNewValue then
			self.size = self.size + 1
		end
		if self.firstKey == nil then
			self.firstKey = value
			self.lastKey = value
		elseif isNewValue then
			self.nextKey[self.lastKey] = value
			self.previousKey[value] = self.lastKey
			self.lastKey = value
		end
		return self
	end
	function Set.prototype.clear(self)
		self.nextKey = {}
		self.previousKey = {}
		self.firstKey = nil
		self.lastKey = nil
		self.size = 0
	end
	function Set.prototype.delete(self, value)
		local contains = self:has(value)
		if contains then
			self.size = self.size - 1
			local next = self.nextKey[value]
			local previous = self.previousKey[value]
			if next ~= nil and previous ~= nil then
				self.nextKey[previous] = next
				self.previousKey[next] = previous
			elseif next ~= nil then
				self.firstKey = next
				self.previousKey[next] = nil
			elseif previous ~= nil then
				self.lastKey = previous
				self.nextKey[previous] = nil
			else
				self.firstKey = nil
				self.lastKey = nil
			end
			self.nextKey[value] = nil
			self.previousKey[value] = nil
		end
		return contains
	end
	function Set.prototype.forEach(self, callback)
		for _, key in iterate(self:keys()) do
			callback(nil, key, key, self)
		end
	end
	function Set.prototype.has(self, value)
		return self.nextKey[value] ~= nil or self.lastKey == value
	end
	Set.prototype[Symbol.iterator] = function(self)
		return self:values()
	end
	function Set.prototype.entries(self)
		local nextKey = self.nextKey
		local key = self.firstKey
		return {
			[Symbol.iterator] = function(self)
				return self
			end,
			next = function(self)
				local result = { done = not key, value = { key, key } }
				key = nextKey[key]
				return result
			end,
		}
	end
	function Set.prototype.keys(self)
		local nextKey = self.nextKey
		local key = self.firstKey
		return {
			[Symbol.iterator] = function(self)
				return self
			end,
			next = function(self)
				local result = { done = not key, value = key }
				key = nextKey[key]
				return result
			end,
		}
	end
	function Set.prototype.values(self)
		local nextKey = self.nextKey
		local key = self.firstKey
		return {
			[Symbol.iterator] = function(self)
				return self
			end,
			next = function(self)
				local result = { done = not key, value = key }
				key = nextKey[key]
				return result
			end,
		}
	end
	function Set.prototype.union(self, other)
		local result = newInstance(Set, self)
		for _, item in iterate(other) do
			result:add(item)
		end
		return result
	end
	function Set.prototype.intersection(self, other)
		local result = newInstance(Set)
		for _, item in iterate(self) do
			if other:has(item) then
				result:add(item)
			end
		end
		return result
	end
	function Set.prototype.difference(self, other)
		local result = newInstance(Set, self)
		for _, item in iterate(other) do
			result:delete(item)
		end
		return result
	end
	function Set.prototype.symmetricDifference(self, other)
		local result = newInstance(Set, self)
		for _, item in iterate(other) do
			if self:has(item) then
				result:delete(item)
			else
				result:add(item)
			end
		end
		return result
	end
	function Set.prototype.isSubsetOf(self, other)
		for _, item in iterate(self) do
			if not other:has(item) then
				return false
			end
		end
		return true
	end
	function Set.prototype.isSupersetOf(self, other)
		for _, item in iterate(other) do
			if not self:has(item) then
				return false
			end
		end
		return true
	end
	function Set.prototype.isDisjointFrom(self, other)
		for _, item in iterate(self) do
			if other:has(item) then
				return false
			end
		end
		return true
	end
	Set[Symbol.species] = Set
end
local function isArray(value)
	return type(value) == "table" and (value[1] ~= nil or next(value) == nil)
end
local function arrayConcat(self, ...)
	local items = { ... }
	local result = {}
	local count = 0
	for i = 1, #self do
		count = count + 1
		result[count] = self[i]
	end
	for i = 1, #items do
		local item = items[i]
		if isArray(item) then
			for j = 1, #item do
				count = count + 1
				result[count] = item[j]
			end
		else
			count = count + 1
			result[count] = item
		end
	end
	return result
end
local function arraySome(self, callback, thisArg)
	for i = 1, #self do
		if callback(thisArg, self[i], i - 1, self) then
			return true
		end
	end
	return false
end
local function stringTrim(self)
	local result = string.gsub(self, "^[%s ﻿]*(.-)[%s ﻿]*$", "%1")
	return result
end
local function arrayFilter(self, callback, thisArg)
	local result = {}
	local count = 0
	for i = 1, #self do
		if callback(thisArg, self[i], i - 1, self) then
			count = count + 1
			result[count] = self[i]
		end
	end
	return result
end
local function arrayIncludes(self, searchElement, fromIndex)
	if fromIndex == nil then
		fromIndex = 0
	end
	local length = #self
	local startIndex = fromIndex
	if fromIndex < 0 then
		startIndex = length + fromIndex
	end
	if startIndex < 0 then
		startIndex = 0
	end
	for i = startIndex + 1, length do
		if self[i] == searchElement then
			return true
		end
	end
	return false
end
local Utils = {}
local dangerZones, humanPlayerInTeam
local Dota = require(GetScriptDirectory() .. "/ts_libs/dota/index")
local Barracks = Dota.Barracks
local BotActionType = Dota.BotActionType
local BotMode = Dota.BotMode
local Lane = Dota.Lane
local Team = Dota.Team
local Tower = Dota.Tower
local UnitType = Dota.UnitType
local BotScriptEnums = Dota.BotScriptEnums
local HttpReq = require(GetScriptDirectory() .. "/ts_libs/utils/http_utils/http_req")
local Request = HttpReq.Request
local NativeOperators = require(GetScriptDirectory() .. "/ts_libs/utils/native-operators")
local add = NativeOperators.add
local dot = NativeOperators.dot
local length2D = NativeOperators.length2D
local length3D = NativeOperators.length3D
local multiply = NativeOperators.multiply
local sub = NativeOperators.sub
local Heroes = require(GetScriptDirectory() .. "/ts_libs/dota/heroes")
local HeroName = Heroes.HeroName
local CacheKeys = require(GetScriptDirectory() .. "/FuncLib/systems/cache_keys")
function Utils.IsValidUnit(unit)
	-- A number reached here from the defend desire in every game ("attempt to index local
	-- E (a number value)", pos 4 heroes, all three lanes); the caller could not be traced (no
	-- debug.traceback in the game sandbox). Not a unit, so not valid.
	if unit == nil or type(unit) == "number" or type(unit) == "string" or type(unit) == "boolean" then
		return false
	end
	return not unit:IsNull() and unit:CanBeSeen() and unit:IsAlive() and not unit:IsInvulnerable()
end
function Utils.IsValidHero(unit)
	if unit == nil then
		return false
	end
	return Utils.IsValidUnit(unit) and unit:IsHero()
end
function Utils.IsValidBuilding(unit)
	if unit == nil then
		return false
	end
	return Utils.IsValidUnit(unit) and unit:IsBuilding()
end
function Utils.GetLocationToLocationDistance(fromLocation, toLocation)
	local x1 = fromLocation.x
	local x2 = toLocation.x
	local y1 = fromLocation.y
	local y2 = toLocation.y
	return math.sqrt((y2 - y1) * (y2 - y1) + (x2 - x1) * (x2 - x1))
end
function Utils.findSafePosition(origin, target)
	local direction = sub(target, origin):Normalized()
	local safeDistance = Utils.getSafeDistance(origin, target)
	return add(origin, multiply(direction, safeDistance))
end
function Utils.getSafeDistance(origin, target)
	local distance = length2D(sub(target, origin))
	for _, zone in ipairs(dangerZones) do
		local projectedPoint = Utils.projectPointOntoLine(origin, target, zone.center)
		local distanceToCenter = length2D(sub(projectedPoint, zone.center))
		if distanceToCenter <= zone.radius then
			local safeDistance = length2D(sub(projectedPoint, origin)) - zone.radius
			return math.max(0, safeDistance)
		end
	end
	return distance
end
function Utils.projectPointOntoLine(lineStart, lineEnd, point)
	local direction = sub(lineEnd, lineStart):Normalized()
	local offset = sub(point, lineStart)
	local projectionLength = dot(offset, direction)
	return add(lineStart, multiply(direction, projectionLength))
end
function Utils.IsAnyOfTheBuildingsAlive(buildings)
	for _, building in ipairs(buildings) do
		if building ~= nil and (not building:CanBeSeen() or building:GetHealth() > 0) then
			return true
		end
	end
	return false
end
function Utils.IsHumanPlayerInTeam(team)
	if humanPlayerInTeam[team] ~= nil then
		return humanPlayerInTeam[team]
	end
	for _, playerId in ipairs(GetTeamPlayers(team)) do
		if not IsPlayerBot(playerId) then
			humanPlayerInTeam[team] = true
			return true
		end
	end
	humanPlayerInTeam[team] = false
	return false
end
function Utils.GetLastSeenEnemyIdsNearLocation(location, radius)
	local enemyIds = {}
	for _, playerId in ipairs(GetTeamPlayers(GetOpposingTeam())) do
		if IsHeroAlive(playerId) then
			local lastSeenInfo = GetHeroLastSeenInfo(playerId)
			if lastSeenInfo ~= nil and lastSeenInfo[1] ~= nil then
				local info = lastSeenInfo[1]
				if
					Utils.GetLocationToLocationDistance(info.location, location) <= radius
					and info.time_since_seen <= 3
				then
					enemyIds[#enemyIds + 1] = playerId
				end
			end
		end
	end
	enemyIds = arrayConcat(enemyIds, Utils.GetEnemyIdsInTpToLocation(location, radius))
	return enemyIds
end
function Utils.GetEnemyIdsInTpToLocation(location, radius)
	local enemyIds = {}
	for _, teleport in ipairs(GetIncomingTeleports()) do
		if
			teleport ~= nil
			and Utils.GetLocationToLocationDistance(location, teleport.location) <= radius
			and not IsTeamPlayer(teleport.playerid)
		then
			enemyIds[#enemyIds + 1] = teleport.playerid
		end
	end
	return enemyIds
end
function Utils.SpreadBotApartDir(bot, distance, units)
	local botLocation = bot:GetLocation()
	for _, unit in ipairs(units) do
		if Utils.IsValidUnit(unit) and unit ~= bot and GetUnitToUnitDistance(bot, unit) <= distance then
			local awayVector = sub(botLocation, unit:GetLocation())
			return multiply(awayVector:Normalized(), distance)
		end
	end
	return nil
end
function Utils.GetItemFromFullInventory(bot, itemName)
	return Utils.GetItemFromCountedInventory(bot, itemName, 16)
end
function Utils.GetItemFromCountedInventory(bot, itemName, slotCount)
	do
		local i = 0
		while i < slotCount do
			local item = bot:GetItemInSlot(i)
			if item and item:GetName() == itemName then
				return item
			end
			i = i + 1
		end
	end
	return nil
end
require(GetScriptDirectory() .. "/ts_libs/utils/json")
Utils.DebugMode = false
Utils.ScriptID = 3246316298
Utils.RadiantFountainTpPoint = Vector(-7172, -6652, 384)
Utils.DireFountainTpPoint = Vector(6982, 6422, 392)
Utils.RadiantRoshanLoc = Vector(-2984, 2349, 384)
Utils.DireRoshanLoc = Vector(2980, -2816, 384)
Utils.BarrackList = {
	Barracks.TopMelee,
	Barracks.TopRanged,
	Barracks.MidMelee,
	Barracks.MidRanged,
	Barracks.BotMelee,
	Barracks.BotRanged,
}
Utils.WisdomRunes = { [Team.Radiant] = Vector(-8126, -320, 256), [Team.Dire] = Vector(8319, 266, 256) }
-- Lotus pool centers (7.41 map). Prefer live npc_dota_lotus_pool discovery in modes.
Utils.LotusPools = {
	top = Vector(-7421, 4238, 0),
	bottom = Vector(7309, -4419, 0),
}
Utils.BuggyHeroesDueToValveTooLazy = {
	[HeroName.Muerta] = true,
	[HeroName.Marci] = true,
	[HeroName.LoneDruidBear] = true,
	[HeroName.PrimalBeast] = true,
	[HeroName.DarkWillow] = true,
	[HeroName.ElderTitan] = true,
	[HeroName.Hoodwink] = true,
	[HeroName.IO] = true,
	[HeroName.Kez] = true,
}
Utils.HighGroundTowers = { Tower.Top3, Tower.Mid3, Tower.Bot3, Tower.Base1, Tower.Base2 }
Utils.FirstTierTowers = { Tower.Top1, Tower.Mid1, Tower.Bot1 }
Utils.SecondTierTowers = { Tower.Top2, Tower.Mid2, Tower.Bot2 }
Utils.AllTowers = {
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
Utils.NonTier1Towers =
	{ Tower.Top2, Tower.Mid2, Tower.Bot2, Tower.Top3, Tower.Mid3, Tower.Bot3, Tower.Base1, Tower.Base2 }
Utils.CachedVarsCleanTime = 5
local initiatorRequirements = {
	[HeroName.Axe] = { minLevel = 4, requiredItems = {}, requiredModifiers = {} },
	[HeroName.Enigma] = { minLevel = 6, requiredItems = {}, requiredModifiers = {} },
	[HeroName.Earthshaker] = { minLevel = 6, requiredItems = { "item_blink" }, requiredModifiers = {} },
	[HeroName.Invoker] = { minLevel = 9, requiredItems = {}, requiredModifiers = {} },
	[HeroName.SandKing] = { minLevel = 6, requiredItems = { "item_blink" }, requiredModifiers = {} },
	[HeroName.TrollWarlord] = {
		minLevel = 6,
		requiredItems = { "item_bfury" },
		requiredModifiers = { "modifier_troll_warlord_battle_trance" },
	},
}
Utils.ImportantSpells = {
	[HeroName.Alchemist] = { "alchemist_chemical_rage" },
	[HeroName.Axe] = { "axe_culling_blade" },
	[HeroName.Bristleback] = { "bristleback_bristleback" },
	[HeroName.Centaur] = { "centaur_stampede" },
	[HeroName.ChaosKnight] = { "chaos_knight_phantasm" },
	[HeroName.Dawnbreaker] = { "dawnbreaker_solar_guardian" },
	[HeroName.Doom] = { "doom_bringer_doom" },
	[HeroName.DragonKnight] = { "dragon_knight_elder_dragon_form" },
	[HeroName.EarthSpirit] = { "earth_spirit_magnetize" },
	[HeroName.Earthshaker] = { "earthshaker_echo_slam" },
	[HeroName.ElderTitan] = { "elder_titan_earth_splitter" },
	[HeroName.Kunkka] = { "kunkka_ghostship" },
	[HeroName.LegionCommander] = { "legion_commander_duel" },
	[HeroName.Lifestealer] = { "life_stealer_rage" },
	[HeroName.Mars] = { "mars_arena_of_blood" },
	[HeroName.NightStalker] = { "night_stalker_darkness" },
	[HeroName.Omniknight] = { "omniknight_guardian_angel" },
	[HeroName.PrimalBeast] = { "primal_beast_pulverize" },
	[HeroName.Sven] = { "sven_gods_strength" },
	[HeroName.Tidehunter] = { "tidehunter_ravage" },
	[HeroName.TreantProtector] = { "treant_overgrowth" },
	[HeroName.Undying] = { "undying_tombstone", "undying_flesh_golem" },
	[HeroName.WraithKing] = { "skeleton_king_reincarnation" },
	[HeroName.Antimage] = { "antimage_mana_void" },
	[HeroName.Bloodseeker] = { "bloodseeker_rupture" },
	[HeroName.Clinkz] = { "clinkz_burning_barrage" },
	[HeroName.FacelessVoid] = { "faceless_void_chronosphere" },
	[HeroName.Gyrocopter] = { "gyrocopter_flak_cannon" },
	[HeroName.Hoodwink] = { "hoodwink_sharpshooter" },
	[HeroName.Juggernaut] = { "juggernaut_omni_slash" },
	[HeroName.Luna] = { "luna_eclipse" },
	[HeroName.Medusa] = { "medusa_stone_gaze" },
	[HeroName.MonkeyKing] = { "monkey_king_wukongs_command" },
	[HeroName.NagaSiren] = { "naga_siren_song_of_the_siren" },
	[HeroName.Razor] = { "razor_static_link" },
	[HeroName.ShadowFiend] = { "nevermore_requiem" },
	[HeroName.Slark] = { "slark_shadow_dance" },
	[HeroName.Spectre] = { "spectre_shadow_step", "spectre_haunt" },
	[HeroName.Terrorblade] = { "terrorblade_metamorphosis", "terrorblade_sunder" },
	[HeroName.TrollWarlord] = { "troll_warlord_battle_trance" },
	[HeroName.Ursa] = { "ursa_enrage" },
	[HeroName.Viper] = { "viper_viper_strike" },
	[HeroName.Weaver] = { "weaver_time_lapse" },
	[HeroName.AncientApparition] = { "ancient_apparition_ice_blast" },
	[HeroName.CrystalMaiden] = { "crystal_maiden_freezing_field" },
	[HeroName.DeathProphet] = { "death_prophet_exorcism" },
	[HeroName.Disruptor] = { "disruptor_static_storm" },
	[HeroName.Grimstroke] = { "grimstroke_dark_portrait", "grimstroke_soul_chain" },
	[HeroName.Jakiro] = { "jakiro_macropyre" },
	[HeroName.Lich] = { "lich_chain_frost" },
	[HeroName.Lina] = { "lina_laguna_blade" },
	[HeroName.Lion] = { "lion_finger_of_death" },
	[HeroName.Muerta] = { "muerta_pierce_the_veil" },
	[HeroName.Necrophos] = { "necrolyte_ghost_shroud", "necrolyte_reapers_scythe" },
	[HeroName.Oracle] = { "oracle_false_promise" },
	[HeroName.OutworldDestroyer] = { "obsidian_destroyer_sanity_eclipse" },
	[HeroName.Puck] = { "puck_dream_coil" },
	[HeroName.Pugna] = { "pugna_life_drain" },
	[HeroName.QueenOfPain] = { "queenofpain_sonic_wave" },
	[HeroName.Ringmaster] = { "ringmaster_wheel" },
	[HeroName.ShadowDeamon] = {
		"shadow_demon_disruption",
		"shadow_demon_demonic_cleanse",
		"shadow_demon_demonic_purge",
	},
	[HeroName.ShadowShaman] = { "shadow_shaman_mass_serpent_ward" },
	[HeroName.Silencer] = { "silencer_global_silence" },
	[HeroName.SkywrathMage] = { "skywrath_mage_mystic_flare" },
	[HeroName.Warlock] = { "warlock_fatal_bonds", "warlock_golem" },
	[HeroName.WitchDoctor] = { "witch_doctor_voodoo_switcheroo", "witch_doctor_death_ward" },
	[HeroName.Zeus] = { "zuus_thundergods_wrath" },
	[HeroName.Abaddon] = { "abaddon_borrowed_time" },
	[HeroName.Bane] = { "bane_fiends_grip" },
	[HeroName.Batrider] = { "batrider_flaming_lasso" },
	[HeroName.Beastmaster] = { "beastmaster_primal_roar" },
	[HeroName.Brewmaster] = { "brewmaster_primal_split" },
	[HeroName.Broodmother] = { "broodmother_insatiable_hunger" },
	[HeroName.Chen] = { "chen_hand_of_god" },
	[HeroName.DarkSeer] = { "dark_seer_wall_of_replica" },
	[HeroName.DarkWillow] = { "dark_willow_terrorize" },
	[HeroName.Enigma] = { "enigma_black_hole" },
	[HeroName.Lycan] = { "lycan_shapeshift" },
	[HeroName.Magnus] = { "magnataur_reverse_polarity" },
	[HeroName.Marci] = { "marci_unleash" },
	[HeroName.Pangolier] = { "pangolier_gyroshell" },
	[HeroName.Phoenix] = { "phoenix_supernova" },
	[HeroName.SandKing] = { "sandking_epicenter" },
	[HeroName.Snapfire] = { "snapfire_mortimer_kisses" },
	[HeroName.VengefulSpirit] = { "vengefulspirit_nether_swap" },
	[HeroName.Venomancer] = { "venomancer_noxious_plague" },
	[HeroName.Windrunner] = { "windrunner_focusfire" },
	[HeroName.WinterWyvern] = { "winter_wyvern_cold_embrace", "winter_wyvern_winters_curse" },
}
Utils.ImportantItems = { "item_black_king_bar", "item_refresher" }
dangerZones = {}
Utils.GameStates = { defendPings = nil, recentDefendTime = -200, cachedVars = nil, twinGates = {} }
Utils.LoneDruid = {}
Utils.FrameProcessTime = 0.01
Utils.EstimatedEnemyRoles = { npc_dota_hero_any = { lane = Lane.Mid, role = 2 } }
function Utils.PrintTable(tbl, depth)
	if depth == nil then
		depth = 0
	end
	if tbl == nil then
		log("nil")
		return
	end
	for _, entry in ipairs(objectEntries(tbl)) do
		local key = entry[1]
		local value = entry[2]
		local indent = string.rep("  ", depth)
		if type(value) == "table" then
			if depth < 3 then
				log("%s%s: ", indent, key)
				Utils.PrintTable(value, depth + 1)
			else
				log("%s%s: [WARN] Table has deep nested tables in it, stop printing more nested tables.", indent, key)
			end
		else
			log("%s%s: %s", indent, key, value)
		end
	end
end
function Utils.PrintUnitModifiers(unit)
	local modifierCount = unit:NumModifiers()
	do
		local i = 0
		while i < modifierCount do
			local modifierName = unit:GetModifierName(i)
			local stackCount = unit:GetModifierStackCount(i)
			log("Unit %s has modifier %s with stack count %s", unit:GetUnitName(), modifierName, stackCount)
			i = i + 1
		end
	end
end
function Utils.PrintPings(maxAge)
	local pings = {}
	for _, entry in iterate(arrayEntries(GetAvoidanceZones())) do
		local zoneIndex = entry[1]
		local zone = entry[2]
		Utils.PrintTable(zone)
	end
	local teamPlayers = GetTeamPlayers(GetTeam())
	do
		local i = 1
		while i <= #teamPlayers do
			do
				local continueLoop
				repeat
					local member = GetTeamMember(i)
					if member == nil or not member:IsAlive() or member:IsIllusion() then
						continueLoop = true
						break
					end
					local ping = member:GetMostRecentPing()
					if ping.time ~= 0 and GameTime() - ping.time < maxAge then
						pings[#pings + 1] = ping
						local pingLocation = ping.location
						log(
							"[PING] Player %d pinged at (%d, %d, %d) normal=%s time=%.1f",
							i,
							math.floor(pingLocation.x),
							math.floor(pingLocation.y),
							math.floor(pingLocation.z),
							tostring(ping.normal_ping),
							ping.time
						)
						for _, unit in ipairs(GetUnitList(UnitType.All)) do
							if Utils.GetLocationToLocationDistance(ping.location, unit:GetLocation()) < 400 then
								log("  nearby: %s", unit:GetUnitName())
							end
						end
					end
					continueLoop = true
				until true
				if not continueLoop then
					break
				end
			end
			i = i + 1
		end
	end
	if #pings > 0 then
		Utils.PrintTable(pings)
	end
end
function Utils.PrintAllAbilities(unit)
	log("Get all abilities of bot %s", unit:GetUnitName())
	for slot = 0, 10 do
		local ability = unit:GetAbilityInSlot(slot)
		if ability and not ability:IsNull() then
			log("Ability At Index %d: %s", slot, ability:GetName())
		else
			log("Ability At Index %d is nil", slot)
		end
	end
end
function Utils.GetEnemyFountainTpPoint()
	if GetTeam() == Team.Dire then
		return Utils.RadiantFountainTpPoint
	end
	return Utils.DireFountainTpPoint
end
function Utils.GetTeamFountainTpPoint()
	if GetTeam() == Team.Dire then
		return Utils.DireFountainTpPoint
	end
	return Utils.RadiantFountainTpPoint
end
function Utils.GetTeamSideDirection(team)
	if team == Team.Radiant then
		return Vector(-1, -1, 0):Normalized()
	else
		return Vector(1, 1, 0):Normalized()
	end
end
function Utils.Shuffle(list)
	do
		local i = #list - 1
		while i > 0 do
			local j = RandomInt(0, i)
			local temp = list[i + 1]
			list[i + 1] = list[j + 1]
			list[j + 1] = temp
			i = i - 1
		end
	end
	return list
end
function Utils.SetFrameProcessTime(bot)
	if bot.frameProcessTime == nil then
		bot.frameProcessTime = Utils.FrameProcessTime
			+ numberToFixed(math.fmod(bot:GetPlayerID() / 1000, Utils.FrameProcessTime / 10) * 3, 2)
	end
end
function Utils.GetHumanPing()
	-- GetTeamMember takes a team slot (1-5), not a player ID (game 037 review); same in the loops below.
	for slot = 1, #GetTeamPlayers(GetTeam()) do
		local member = GetTeamMember(slot)
		if member ~= nil and not member:IsBot() then
			return member, member:GetMostRecentPing()
		end
	end
	return nil, nil
end
function Utils.IsPingedByAnyPlayer(bot, maxAge, minDistance, maxDistance)
	if not bot:IsAlive() then
		return nil
	end
	local pings = {}
	minDistance = minDistance or 1500
	maxDistance = maxDistance or 10000
	for slot = 1, #GetTeamPlayers(GetTeam()) do
		do
			local continueLoop
			repeat
				local member = GetTeamMember(slot)
				if member == nil or member:IsIllusion() or member == bot then
					continueLoop = true
					break
				end
				local ping = member:GetMostRecentPing()
				if ping and ping.time and GameTime() - ping.time < maxAge then
					pings[#pings + 1] = ping
				end
				continueLoop = true
			until true
			if not continueLoop then
				break
			end
		end
	end
	for _, ping in ipairs(pings) do
		local distance = Utils.GetLocationToLocationDistance(ping.location, bot:GetLocation())
		local inRange = minDistance <= distance and distance <= maxDistance
		local isRecent = GameTime() - ping.time < maxAge
		if inRange and isRecent then
			log("Bot %s noticed the ping", bot:GetUnitName())
			return ping
		end
	end
	return nil
end
function Utils.SetCachedVars(key, value)
	if not Utils.GameStates.cachedVars then
		Utils.GameStates.cachedVars = {}
	end
	Utils.GameStates.cachedVars[key] = { t = DotaTime(), v = value }
end
function Utils.GetCachedVars(key, maxAge)
	if not Utils.GameStates.cachedVars then
		return nil
	end
	local entry = Utils.GameStates.cachedVars[key]
	if not entry then
		return nil
	end
	if DotaTime() - entry.t <= maxAge then
		return entry.v
	end
	return nil
end
function Utils.CleanupCachedVars()
	return
end
function Utils.CountEnemyHeroesNear(location, radius)
	local count = 0
	for _, enemyHero in ipairs(GetUnitList(UnitType.EnemyHeroes)) do
		if Utils.IsValidHero(enemyHero) and GetUnitToLocationDistance(enemyHero, location) <= radius then
			count = count + 1
		end
	end
	return count
end
local barracksList = {
	Barracks.TopMelee,
	Barracks.TopRanged,
	Barracks.MidMelee,
	Barracks.MidRanged,
	Barracks.BotMelee,
	Barracks.BotRanged,
}
local highGroundTowers = { Tower.Top3, Tower.Mid3, Tower.Bot3 }
function Utils.CountEnemyHeroesOnHighGround(team)
	local cacheKey = 60000 + (team or 0)
	local cached = Utils.GetCachedVars(cacheKey, 1)
	if cached ~= nil then
		return cached
	end
	local buildings = {}
	for _, towerId in ipairs(highGroundTowers) do
		local tower = GetTower(team, towerId)
		if Utils.IsValidBuilding(tower) then
			buildings[#buildings + 1] = tower
		end
	end
	for _, barracksId in ipairs(barracksList) do
		local barracks = GetBarracks(team, barracksId)
		if Utils.IsValidBuilding(barracks) then
			buildings[#buildings + 1] = barracks
		end
	end
	local ancient = GetAncient(team)
	if Utils.IsValidBuilding(ancient) then
		buildings[#buildings + 1] = ancient
	end
	local maxEnemies = 0
	for _, building in ipairs(buildings) do
		local enemyCount = Utils.CountEnemyHeroesNear(building:GetLocation(), 1600)
		if enemyCount > maxEnemies then
			maxEnemies = enemyCount
		end
	end
	Utils.SetCachedVars(cacheKey, maxEnemies)
	return maxEnemies
end
-- How far out from a high-ground building a creep wave starts to count. Defenders are sent
-- while the wave is still walking up, so they arrive before it hits the building. It was
-- 1600; 1000 more gives a walking hero about 3s more lead.
Utils.HG_WAVE_RADIUS = 2600
-- Enemy creeps within `radius` of loc, counting only those closer to loc than to another of
-- our T3 towers (mid and top T3 are close enough that one wave would count for both).
function Utils.CountHighGroundWave(team, location, radius)
	local others = {}
	for _, id in ipairs(highGroundTowers) do
		local tower = GetTower(team, id)
		if Utils.IsValidBuilding(tower) then
			local towerLocation = tower:GetLocation()
			if (towerLocation.x - location.x) ^ 2 + (towerLocation.y - location.y) ^ 2 > 300 * 300 then
				others[#others + 1] = towerLocation
			end
		end
	end
	local count = 0
	for _, unit in pairs(GetUnitList(UNIT_LIST_ENEMY_CREEPS) or {}) do
		if unit ~= nil and unit:IsAlive() then
			local distance = GetUnitToLocationDistance(unit, location)
			if distance <= radius then
				local mine = true
				for _, towerLocation in ipairs(others) do
					if GetUnitToLocationDistance(unit, towerLocation) < distance then
						mine = false
						break
					end
				end
				if mine then
					count = count + 1
				end
			end
		end
	end
	return count
end
-- A creep wave (2+ enemy creeps within HG_WAVE_RADIUS) at one of our high-ground buildings
-- (T3 or barracks) with no enemy hero that close to it, and that building within `range` of
-- the bot. Returns the building and the creep count, or nil.
function Utils.HighGroundCreepWaveNear(bot, range)
	local team = bot:GetTeam()
	local buildings = {}
	for _, id in ipairs(highGroundTowers) do
		local tower = GetTower(team, id)
		if Utils.IsValidBuilding(tower) then
			buildings[#buildings + 1] = tower
		end
	end
	for _, id in ipairs(barracksList) do
		local rax = GetBarracks(team, id)
		if Utils.IsValidBuilding(rax) then
			buildings[#buildings + 1] = rax
		end
	end
	for _, building in ipairs(buildings) do
		if GetUnitToUnitDistance(bot, building) <= range then
			local location = building:GetLocation()
			if Utils.CountEnemyHeroesNear(location, Utils.HG_WAVE_RADIUS) == 0 then
				local creeps = Utils.CountHighGroundWave(team, location, Utils.HG_WAVE_RADIUS)
				if creeps >= 2 then
					return building, creeps
				end
			end
		end
	end
	return nil
end
function Utils.GetDistanceFromAncient(bot, isEnemy)
	local ancient = GetAncient(isEnemy and GetOpposingTeam() or GetTeam())
	return GetUnitToUnitDistance(bot, ancient)
end
function Utils.IsValidCreep(unit)
	if unit == nil then
		return false
	end
	return Utils.IsValidUnit(unit)
		and unit:GetHealth() < 5000
		and not unit:IsHero()
		and (GetBot():GetLevel() > 9 or not unit:IsAncientCreep())
end
function Utils.IsValidTower(unit)
	if unit == nil then
		return false
	end
	return Utils.IsValidUnit(unit) and unit:IsTower()
end
function Utils.HasItem(bot, itemName)
	local slot = bot:FindItemSlot(itemName)
	return slot >= 0 and slot <= 8
end
function Utils.FindAllyWithName(name)
	for _, ally in ipairs(GetUnitList(UnitType.AlliedHeroes)) do
		if Utils.IsValidHero(ally) and { string.find(ally:GetUnitName(), name) } then
			return ally
		end
	end
	return nil
end
function Utils.Deepcopy(original)
	local originalType = type(original)
	local copy
	if originalType == "table" then
		copy = {}
		for _, entry in ipairs(objectEntries(original)) do
			local key = entry[1]
			local value = entry[2]
			copy[Utils.Deepcopy(key)] = Utils.Deepcopy(value)
		end
		setmetatable(copy, Utils.Deepcopy(getmetatable(original)))
	else
		copy = original
	end
	return copy
end
function Utils.CombineTablesUnique(first, second)
	local uniqueValues = newInstance(Set)
	for _, entry in ipairs(objectEntries(first)) do
		local key = entry[1]
		local value = entry[2]
		uniqueValues:add(value)
	end
	for _, entry in ipairs(objectEntries(second)) do
		local key = entry[1]
		local value = entry[2]
		uniqueValues:add(value)
	end
	local result = {}
	for _, value in iterate(uniqueValues) do
		result[#result + 1] = value
	end
	return result
end
function Utils.MergeLists(first, second)
	return arrayConcat(first, second)
end
function Utils.RemoveValueFromTable(list, valueToRemove, removeAll)
	local i = 0
	while i < #list do
		if list[i + 1] == valueToRemove then
			table.remove(list, i + 1)
			if not removeAll then
				break
			end
		else
			i = i + 1
		end
	end
end
function Utils.NumActionTypeInQueue(bot, actionType)
	local count = 0
	for i = 1, bot:NumQueuedActions() do
		local queuedType = bot:GetQueuedActionType(i)
		if queuedType == actionType then
			count = count + 1
		end
	end
	return count
end
local humanBotCountCache = {}
function Utils.NumHumanBotPlayersInTeam(team)
	if humanBotCountCache[team] == nil then
		local humanCount = 0
		local botCount = 0
		for _, playerId in ipairs(GetTeamPlayers(team)) do
			if IsPlayerBot(playerId) then
				botCount = botCount + 1
			else
				humanCount = humanCount + 1
			end
		end
		humanBotCountCache[team] = { humanCount, botCount }
	end
	return humanBotCountCache[team][1], humanBotCountCache[team][2]
end
function Utils.GetNearbyAllyAverageHpPercent(bot, radius)
	local hpRatioSum = 0
	local allyCount = 0
	for slot = 1, #GetTeamPlayers(bot:GetTeam()) do
		local ally = GetTeamMember(slot)
		if ally and ally:IsAlive() and GetUnitToUnitDistance(ally, bot) <= radius then
			hpRatioSum = hpRatioSum + ally:GetHealth() / ally:GetMaxHealth()
			allyCount = allyCount + 1
		end
	end
	-- Was `allyCount ~= nil` (always true), so no ally in range gave 0/0 = NaN.
	return allyCount > 0 and hpRatioSum / allyCount or 0
end
function Utils.IsWithoutSpellShield(unit)
	return not unit:HasModifier("modifier_item_sphere_target")
		and not unit:HasModifier("modifier_antimage_spell_shield")
		and not unit:HasModifier("modifier_item_lotus_orb_active")
end
function Utils.SetContains(set, key)
	return not not set[key]
end
function Utils.AddToSet(set, key)
	set[key] = true
end
function Utils.RemoveFromSet(set, key)
	deleteProperty(set, key)
end
function Utils.HasValue(set, value)
	for _, item in ipairs(set) do
		if value == item then
			return true
		end
	end
	return false
end
function Utils.CountBackpackEmptySpace(bot)
	local emptySlots = 3
	for _, slot in ipairs({ 6, 7, 8 }) do
		if bot:GetItemInSlot(slot) ~= nil then
			emptySlots = emptySlots - 1
		end
	end
	return emptySlots
end
function Utils.FloatEqual(left, right)
	return math.abs(left - right) < 0.000001
end
local tableMetatable = {}
tableMetatable.__index = tableMetatable
function Utils.NewTable()
	local newTable = {}
	setmetatable(newTable, tableMetatable)
	return newTable
end
function Utils.ForEach(_, list, callback)
	for index, value in ipairs(list) do
		callback(index, value)
	end
end
function Utils.Remove_Modify(list, itemOrPredicate)
	local predicate = itemOrPredicate
	if type(itemOrPredicate) ~= "function" then
		predicate = function(item)
			return item == itemOrPredicate
		end
	end
	local i = 1
	local length = list.length
	while i <= length do
		if predicate(list[i]) then
			table.remove(list, i)
			length = length - 1
		else
			i = i + 1
		end
	end
end
function Utils.AbilityBehaviorHasFlag(behavior, flag)
	return bit.band(behavior, flag) == flag
end
local throttleState = {}
local function throttle(interval, func)
	local funcKey = tostring(func)
	throttleState[funcKey] =
		{ lastCallTime = DotaTime() + RandomInt(0, interval * 1000) / 1000, interval = interval, startup = true }
	return function(...)
		local state = throttleState[funcKey]
		if state.startup then
			state.startup = nil
			return func(...)
		elseif state.lastCallTime <= DotaTime() - state.interval then
			state.lastCallTime = DotaTime()
			return func(...)
		end
		return Utils.NewTable()
	end
end
function Utils.RecentlyTookDamage(bot, duration)
	return bot:WasRecentlyDamagedByAnyHero(duration)
		or bot:WasRecentlyDamagedByTower(duration)
		or bot:WasRecentlyDamagedByCreep(duration)
end
function Utils.IsUnitWithName(unit, name)
	local matches = { string.find(unit:GetUnitName(), name) }
	return matches ~= nil
end
function Utils.IsBear(unit)
	return Utils.IsUnitWithName(unit, "lone_druid_bear")
end
function Utils.GetOffsetLocationTowardsTargetLocation(fromLocation, towardLocation, distance)
	local direction = sub(towardLocation, fromLocation):Normalized()
	return add(fromLocation, multiply(direction, distance))
end
function Utils.TimeNeedToHealHP(bot)
	local regen = bot:GetHealthRegen()
	return regen > 0 and (bot:GetMaxHealth() - bot:GetHealth()) / regen or math.huge
end
function Utils.TimeNeedToHealMP(bot)
	local regen = bot:GetManaRegen()
	return regen > 0 and (bot:GetMaxMana() - bot:GetMana()) / regen or math.huge
end
function Utils.HasAnyEffect(unit, ...)
	local modifierNames = { ... }
	return arraySome(modifierNames, function(_, modifierName)
		return unit:HasModifier(modifierName)
	end)
end
function Utils.IsModeTurbo()
	for _, unit in ipairs(GetUnitList(UnitType.Allies)) do
		if unit and unit:GetUnitName() == "npc_dota_courier" and unit:GetCurrentMovementSpeed() == 1100 then
			return true
		end
	end
	return false
end
function Utils.DetermineEnemyBotRole(bot)
	local unitName = bot:GetUnitName()
	local estimatedRole = Utils.EstimatedEnemyRoles[unitName]
	if estimatedRole == nil then
		log("Enemy bot %s role not cached yet.", unitName)
		return 3
	end
	return estimatedRole.role
end
function Utils.QueryCounters(heroId)
	log("heroId=%s", heroId)
	Request:RawGetRequest(
		("https://api.opendota.com/api/heroes/" .. tostring(heroId)) .. "/matchups",
		function(response)
			Utils.PrintTable(response)
		end
	)
end
function Utils.InitiStats()
	Request:GetUUID(function(uuid)
		log("uuid=%s", uuid)
	end)
end
function Utils.GetLoneDruid(bot)
	local loneDruidState = Utils.LoneDruid[bot:GetPlayerID()]
	if loneDruidState == nil then
		Utils.LoneDruid[bot:GetPlayerID()] = {}
		loneDruidState = Utils.LoneDruid[bot:GetPlayerID()]
	end
	return loneDruidState
end
function Utils.TrimString(text)
	return stringTrim(text)
end
function Utils.addCustomAvoidanceZone(center, radius, duration)
	local now = DotaTime()
	local expirationTime = duration ~= nil and now + duration or math.huge
	dangerZones[#dangerZones + 1] = { center = center, radius = radius, expirationTime = expirationTime }
end
function Utils.cleanExpiredAvoidanceZones()
	local now = DotaTime()
	dangerZones = arrayFilter(dangerZones, function(_, zone)
		return zone.expirationTime > now
	end)
end
function Utils.getCustomAvoidanceZones()
	return dangerZones
end
local specialOffensiveHeroes = { HeroName.ArcWarden, HeroName.Phoenix, HeroName.Terrorblade }
function Utils.IsSpecialOffensiveHero(name)
	return arrayIncludes(specialOffensiveHeroes, name)
end
function Utils.isPositionInAvoidanceZone(position)
	for _, zone in ipairs(dangerZones) do
		local distance = length2D(sub(position, zone.center))
		if distance <= zone.radius then
			return true
		end
	end
	return false
end
function Utils.moveToPositionAvoidingZones(bot, target)
	if Utils.isPositionInAvoidanceZone(target) then
		local safePosition = Utils.findSafePosition(bot:GetLocation(), target)
		bot:Action_MoveToLocation(safePosition)
	else
		bot:Action_MoveToLocation(target)
	end
end
function Utils.drawAvoidanceZones()
	for _, zone in ipairs(dangerZones) do
		DebugDrawCircle(zone.center, zone.radius, 0, 255, 0)
	end
end
function Utils.findPathAvoidingZones(start, goal)
	return {}
end
function Utils.IsBuildingAttackedByEnemy(building)
	for _, enemyHero in ipairs(GetUnitList(UnitType.EnemyHeroes)) do
		if
			Utils.IsValidHero(enemyHero)
			and GetUnitToUnitDistance(building, enemyHero) <= enemyHero:GetAttackRange() + 200
			and enemyHero:GetAttackTarget() == building
		then
			return building
		end
	end
	return nil
end
function Utils.IsAnyBarrackAttackByEnemyHero()
	for _, barracksId in ipairs(Utils.BarrackList) do
		local barracks = GetBarracks(GetTeam(), barracksId)
		if barracks ~= nil and barracks:GetHealth() > 0 then
			local attacked = Utils.IsBuildingAttackedByEnemy(barracks)
			if attacked ~= nil then
				return attacked
			end
		end
	end
	return nil
end
function Utils.IsAnyBarracksOnLaneAlive(isEnemy, lane)
	local barracks = {}
	local team = GetTeam()
	if isEnemy then
		team = GetOpposingTeam()
	end
	if lane == Lane.Top then
		barracks = { GetBarracks(team, Barracks.TopMelee), GetBarracks(team, Barracks.TopRanged) }
	elseif lane == Lane.Mid then
		barracks = { GetBarracks(team, Barracks.MidMelee), GetBarracks(team, Barracks.MidRanged) }
	elseif lane == Lane.Bot then
		barracks = { GetBarracks(team, Barracks.BotMelee), GetBarracks(team, Barracks.BotRanged) }
	end
	return Utils.IsAnyOfTheBuildingsAlive(barracks)
end
humanPlayerInTeam = { [Team.Radiant] = nil, [Team.Dire] = nil }
function Utils.IsHumanPlayerInAnyTeam()
	return Utils.IsHumanPlayerInTeam(Team.Radiant) or Utils.IsHumanPlayerInTeam(Team.Dire)
end
function Utils.GetEnemyHeroByPlayerId(playerId)
	for _, enemyHero in ipairs(GetUnitList(UnitType.EnemyHeroes)) do
		if Utils.IsValidHero(enemyHero) and enemyHero:GetPlayerID() == playerId then
			return enemyHero
		end
	end
	return nil
end
function Utils.IsTruelyInvisible(unit)
	return unit:IsInvisible()
		and not unit:HasModifier("modifier_item_dustofappearance")
		and not Utils.RecentlyTookDamage(unit, 1.5)
end
function Utils.HasModifierContainsName(unit, name)
	if not Utils.IsValidUnit(unit) then
		return false
	end
	local modifierCount = unit:NumModifiers()
	do
		local i = 0
		while i < modifierCount do
			local modifierName = unit:GetModifierName(i)
			if (string.find(modifierName, name, nil, true) or 0) - 1 > -1 then
				return true
			end
			i = i + 1
		end
	end
	return false
end
function Utils.IsNearEnemySecondTierTower(unit, distance)
	for _, towerId in ipairs(Utils.SecondTierTowers) do
		local tower = GetTower(GetOpposingTeam(), towerId)
		if tower ~= nil and Utils.IsValidBuilding(tower) and GetUnitToUnitDistance(unit, tower) < distance then
			return true
		end
	end
	return false
end
function Utils.GetEnemyIdsNearNonTier1Towers(distance)
	local result = {}
	for _, towerId in ipairs(Utils.NonTier1Towers) do
		local tower = GetTower(GetTeam(), towerId)
		if tower ~= nil and Utils.IsValidBuilding(tower) then
			local enemyIds = Utils.GetLastSeenEnemyIdsNearLocation(tower:GetLocation(), distance)
			result[towerId] = { tower = tower, enemyIds = enemyIds }
		end
	end
	return result
end
function Utils.GetNonTier1TowerWithLeastEnemiesAround(distance)
	local towerEnemies = Utils.GetEnemyIdsNearNonTier1Towers(distance)
	local leastEnemies = 999
	local bestTower = nil
	for _, towerId in ipairs(Utils.NonTier1Towers) do
		local towerInfo = towerEnemies[towerId]
		if towerInfo ~= nil and #towerInfo.enemyIds <= leastEnemies then
			bestTower = towerInfo.tower
			leastEnemies = #towerInfo.enemyIds
		end
	end
	if leastEnemies ~= 0 then
		return bestTower
	end
	return nil
end
function Utils.GetClosestTowerOrBarrackToAttack(unit)
	local closestBuilding = nil
	local closestDistance = 2 ^ 1024
	for _, barracksId in ipairs(Utils.BarrackList) do
		local barracks = GetBarracks(GetOpposingTeam(), barracksId)
		if
			barracks ~= nil
			and barracks:GetHealth() > 0
			and not (
				barracks:HasModifier("modifier_fountain_glyph")
				or barracks:HasModifier("modifier_invulnerable")
				or barracks:HasModifier("modifier_backdoor_protection_active")
			)
		then
			local distance = GetUnitToUnitDistance(unit, barracks)
			if distance < closestDistance then
				closestDistance = distance
				closestBuilding = barracks
			end
		end
	end
	for _, towerId in ipairs(Utils.HighGroundTowers) do
		local tower = GetTower(GetOpposingTeam(), towerId)
		if
			tower ~= nil
			and Utils.IsValidBuilding(tower)
			and not (
				tower:HasModifier("modifier_fountain_glyph")
				or tower:HasModifier("modifier_invulnerable")
				or tower:HasModifier("modifier_backdoor_protection_active")
			)
		then
			local distance = GetUnitToUnitDistance(unit, tower)
			if distance < closestDistance then
				closestDistance = distance
				closestBuilding = tower
			end
		end
	end
	return closestBuilding
end
function Utils.IsNearEnemyHighGroundTower(unit, distance)
	for _, towerId in ipairs(Utils.HighGroundTowers) do
		local tower = GetTower(GetOpposingTeam(), towerId)
		if tower ~= nil and Utils.IsValidBuilding(tower) and GetUnitToUnitDistance(unit, tower) < distance then
			return true
		end
	end
	return false
end
function Utils.IsTeamPushingSecondTierOrHighGround(bot)
	local cacheKey = 61000 + bot:GetTeam()
	local cached = Utils.GetCachedVars(cacheKey, 1)
	if cached ~= nil then
		return cached
	end
	local enemyAncient = GetAncient(GetOpposingTeam())
	if enemyAncient ~= nil then
		for slot = 1, #GetTeamPlayers(bot:GetTeam()) do
			local member = GetTeamMember(slot)
			if member ~= nil and member:IsAlive() then
				if
					#(member:GetNearbyHeroes(2000, false, BotMode.None) or {}) >= 2
					and (
						Utils.IsNearEnemySecondTierTower(member, 2000)
						or Utils.IsNearEnemyHighGroundTower(member, 3000)
						or GetUnitToUnitDistance(member, enemyAncient) < 3000
					)
				then
					Utils.SetCachedVars(cacheKey, true)
					return true
				end
			end
		end
	end
	Utils.SetCachedVars(cacheKey, false)
	return false
end
function Utils.GetNumOfAliveHeroes(isEnemy)
	local count = 0
	local targetTeam = GetTeam()
	if isEnemy then
		targetTeam = GetOpposingTeam()
	end
	for _, playerId in ipairs(GetTeamPlayers(targetTeam)) do
		if IsHeroAlive(playerId) then
			count = count + 1
		end
	end
	return count
end
function Utils.CountMissingEnemyHeroes()
	local cacheKey = CacheKeys.COUNT_MISSING_ENEMY + GetTeam()
	local cached = Utils.GetCachedVars(cacheKey, 0.5)
	if cached ~= nil then
		return cached
	end
	local count = 0
	for _, playerId in ipairs(GetTeamPlayers(GetOpposingTeam())) do
		do
			local continueLoop
			repeat
				if IsHeroAlive(playerId) then
					local lastSeenInfo = GetHeroLastSeenInfo(playerId)
					if lastSeenInfo ~= nil and lastSeenInfo[1] ~= nil then
						local info = lastSeenInfo[1]
						if info.time_since_seen >= 2.5 then
							count = count + 1
							continueLoop = true
							break
						end
					end
				end
				continueLoop = true
			until true
			if not continueLoop then
				break
			end
		end
	end
	Utils.SetCachedVars(cacheKey, count)
	return count
end
function Utils.FindAllyWithAtLeastDistanceAway(bot, minDistance)
	if bot:GetTeam() ~= GetTeam() then
		log("[ERROR] Wrong usage of the method")
		return nil
	end
	for slot = 1, #GetTeamPlayers(GetTeam()) do
		local member = GetTeamMember(slot)
		if member ~= nil and member:IsAlive() and GetUnitToUnitDistance(member, bot) >= minDistance then
			return member
		end
	end
	return nil
end
local function meetsInitiatorRequirements(enemyHero, requirements)
	if enemyHero:GetLevel() < requirements.minLevel then
		return false
	end
	for _, itemName in ipairs(requirements.requiredItems) do
		if not Utils.HasItem(enemyHero, itemName) then
			return false
		end
	end
	for _, modifierName in ipairs(requirements.requiredModifiers) do
		if not enemyHero:HasModifier(modifierName) then
			return false
		end
	end
	return true
end
local threatRangeBuffer = 1200
function Utils.IsAnySpecialAOEThreatNearby(bot, range)
	for _, enemyHero in ipairs(GetUnitList(UnitType.EnemyHeroes)) do
		do
			local continueLoop
			repeat
				if not Utils.IsValidHero(enemyHero) then
					continueLoop = true
					break
				end
				local heroName = enemyHero:GetUnitName()
				if initiatorRequirements[heroName] == nil then
					continueLoop = true
					break
				end
				if GetUnitToUnitDistance(bot, enemyHero) > range + threatRangeBuffer then
					continueLoop = true
					break
				end
				if meetsInitiatorRequirements(enemyHero, initiatorRequirements[heroName]) then
					return true
				end
				continueLoop = true
			until true
			if not continueLoop then
				break
			end
		end
	end
	return false
end
function Utils.ShouldBotsSpreadOut(bot, range)
	if #(bot:GetNearbyHeroes(range, false, BotMode.None) or {}) <= 1 then
		return false
	end
	local shouldSpread = false
	local hasThreat = Utils.IsAnySpecialAOEThreatNearby(bot, range)
	if hasThreat then
		shouldSpread = true
	end
	return shouldSpread
end
function Utils.GetNearbyAllyUnits(bot, radius)
	local allyHeroes = bot:GetNearbyHeroes(radius, false, BotMode.None) or {}
	local allyCreeps = bot:GetNearbyLaneCreeps(radius, false) or {}
	local units = arrayConcat(allyHeroes, allyCreeps)
	return units
end
function Utils.SmartSpreadOut(bot, radius, distance, extraUnits, onlyExtraUnits)
	if extraUnits == nil then
		extraUnits = {}
	end
	if onlyExtraUnits == nil then
		onlyExtraUnits = false
	end
	local units = {}
	if onlyExtraUnits then
		units = extraUnits
	else
		units = arrayConcat(Utils.GetNearbyAllyUnits(bot, radius), extraUnits)
	end
	local apartDirection = Utils.SpreadBotApartDir(bot, distance, units)
	if not apartDirection then
		bot:Action_MoveToLocation(add(Utils.GetTeamFountainTpPoint(), RandomVector(50)))
		return
	end
	local botLocation = bot:GetLocation()
	local apartWeight = 0.7
	local teamSideWeight = 0.3
	local teamSideDirection = Utils.GetTeamSideDirection(GetTeam())
	if #extraUnits == 0 then
		teamSideDirection = multiply(teamSideDirection, 0.5)
	end
	local direction =
		add(multiply(apartDirection, apartWeight), multiply(teamSideDirection, teamSideWeight)):Normalized()
	local offset = multiply(direction, distance)
	local towardEnemyDirection = sub(Utils.GetEnemyFountainTpPoint(), botLocation):Normalized()
	if dot(offset:Normalized(), towardEnemyDirection) > 0 then
		offset = multiply(teamSideDirection, distance)
	end
	local destination = add(botLocation, offset)
	if Utils.GetDistanceFromAncient(bot, true) < 2600 then
		if dot(sub(destination, botLocation), towardEnemyDirection) > 0 then
			offset = multiply(teamSideDirection, distance)
			destination = add(botLocation, offset)
		end
	end
	bot:Action_MoveToLocation(add(destination, RandomVector(50)))
end
function Utils.SpreadBotApartDir_2(bot, distance, units)
	local botLocation = bot:GetLocation()
	local sumVector = Vector(0, 0, 0)
	for _, unit in ipairs(units) do
		if Utils.IsValidUnit(unit) and unit ~= bot then
			local unitDistance = GetUnitToUnitDistance(bot, unit)
			if unitDistance <= distance then
				local awayVector = sub(botLocation, unit:GetLocation())
				sumVector = add(sumVector, awayVector)
			end
		end
	end
	local magnitude = length3D(sumVector)
	if magnitude < 0.00001 then
		return nil
	end
	local offset = multiply(sumVector:Normalized(), distance)
	return offset
end
function Utils.GetAllyIdsInTpToLocation(location, radius)
	local allyIds = {}
	for _, teleport in ipairs(GetIncomingTeleports()) do
		if
			teleport ~= nil
			and Utils.GetLocationToLocationDistance(location, teleport.location) <= radius
			and IsTeamPlayer(teleport.playerid)
		then
			allyIds[#allyIds + 1] = teleport.playerid
		end
	end
	return allyIds
end
function Utils.ConsiderTPToTarget(bot, targetLocation, includeAncient)
	local distance = GetUnitToLocationDistance(bot, targetLocation)
	if bot:IsUsingAbility() or bot:HasModifier("modifier_teleporting") then
		return false
	end
	local tpScroll = Utils.GetItemFromFullInventory(bot, "item_tpscroll")
	if tpScroll == nil or not tpScroll:IsFullyCastable() then
		return false
	end
	local alliesTeleporting = Utils.GetAllyIdsInTpToLocation(targetLocation, 2500)
	if #alliesTeleporting >= 2 then
		return false
	end
	local enemiesOnPath = false
	if distance > 2000 then
		local botLocation = bot:GetLocation()
		local midpoint = Vector((botLocation.x + targetLocation.x) / 2, (botLocation.y + targetLocation.y) / 2, 0)
		for _, playerId in ipairs(GetTeamPlayers(GetOpposingTeam())) do
			if IsHeroAlive(playerId) then
				local lastSeenInfo = GetHeroLastSeenInfo(playerId)
				if lastSeenInfo ~= nil and lastSeenInfo[1] ~= nil then
					local info = lastSeenInfo[1]
					if
						Utils.GetLocationToLocationDistance(midpoint, info.location) <= 1600
						and info.time_since_seen <= 5
					then
						enemiesOnPath = true
						break
					end
				end
			end
		end
	end
	if distance <= 4000 and not enemiesOnPath then
		return false
	end
	local team = bot:GetTeam()
	local closestBuilding = nil
	local closestDistance = math.huge
	for _, towerId in ipairs({ 0, 1, 2, 3, 4, 5, 6, 7, 8 }) do
		local tower = GetTower(team, towerId)
		if tower ~= nil and tower:IsAlive() then
			local towerDistance = Utils.GetLocationToLocationDistance(tower:GetLocation(), targetLocation)
			if towerDistance < closestDistance then
				closestDistance = towerDistance
				closestBuilding = tower
			end
		end
	end
	if includeAncient then
		local ancient = GetAncient(team)
		if ancient ~= nil and ancient:IsAlive() then
			local ancientDistance = Utils.GetLocationToLocationDistance(ancient:GetLocation(), targetLocation)
			if ancientDistance < closestDistance then
				closestDistance = ancientDistance
				closestBuilding = ancient
			end
		end
	end
	if closestBuilding ~= nil and closestDistance < 4000 then
		local buildingLocation = closestBuilding:GetLocation()
		local fountain = team == Team.Radiant and Utils.RadiantFountainTpPoint or Utils.DireFountainTpPoint
		local dx = fountain.x - buildingLocation.x
		local dy = fountain.y - buildingLocation.y
		local length = math.max(1, math.sqrt(dx * dx + dy * dy))
		local tpLocation = Vector(buildingLocation.x + dx / length * 200, buildingLocation.y + dy / length * 200, 0)
		log(
			"[TP] %s t=%.0f DEFEND tp to building at (%.0f,%.0f)",
			bot:GetUnitName(),
			DotaTime(),
			tpLocation.x,
			tpLocation.y
		)
		bot:Action_UseAbilityOnLocation(tpScroll, tpLocation)
		return true
	end
	return false
end
function Utils.IsBotPushingTowerInDanger(bot)
	local isNearEnemyTower = #bot:GetNearbyTowers(1100, true) >= 1
	if not isNearEnemyTower then
		return false
	end
	local nearbyAllies = bot:GetNearbyHeroes(1600, false, BotMode.None) or {}
	local aliveEnemyCount = Utils.GetNumOfAliveHeroes(true)
	local nearbyEnemyIds = Utils.GetLastSeenEnemyIdsNearLocation(bot:GetLocation(), 2000)
	if isNearEnemyTower and #nearbyAllies < aliveEnemyCount and #nearbyEnemyIds >= #nearbyAllies then
		return true
	end
	return false
end
function Utils.GetDistanceToCloestEnemyTower(bot)
	local closestTower = nil
	local closestDistance = 99999
	for _, towerId in ipairs(Utils.AllTowers) do
		local tower = GetTower(GetOpposingTeam(), towerId)
		if
			tower ~= nil
			and Utils.IsValidBuilding(tower)
			and not (
				tower:HasModifier("modifier_fountain_glyph")
				or tower:HasModifier("modifier_invulnerable")
				or tower:HasModifier("modifier_backdoor_protection_active")
			)
		then
			local distance = GetUnitToUnitDistance(bot, tower)
			if distance < closestDistance then
				closestTower = tower
				closestDistance = distance
			end
		end
	end
	return closestDistance, closestTower
end
function Utils.GetCirclarPointsAroundCenterPoint(center, radius, pointCount)
	local points = { center }
	local angleStep = 360 / pointCount
	do
		local i = 1
		while i <= pointCount do
			local angle = angleStep * i * math.pi / 180
			local point = Vector(center.x + radius * math.cos(angle), center.y + radius * math.sin(angle), center.z)
			points[#points + 1] = point
			i = i + 1
		end
	end
	return points
end
function Utils.IsValidAbility(ability)
	if
		ability == nil
		or ability:IsNull()
		or ability:GetName() == ""
		or ability:IsHidden()
		or not ability:IsTrained()
		or not ability:IsActivated()
	then
		return false
	end
	return true
end
function Utils.HasCriticalSpellWithCooldown(bot, minCooldown)
	local unitName = bot:GetUnitName()
	if Utils.ImportantSpells[unitName] ~= nil then
		local ability = bot:GetAbilityByName(Utils.ImportantSpells[unitName][1])
		if Utils.IsValidAbility(ability) and ability:GetCooldownTimeRemaining() > minCooldown then
			return true
		end
	end
	return false
end
function Utils.GetItem(bot, itemName)
	return Utils.GetItemFromCountedInventory(bot, itemName, 6)
end
function Utils.HasTeamMemberWithCriticalSpellInCooldown(targetLocation)
	local cacheKey = CacheKeys.HAS_CRITICAL_SPELL_CD + GetTeam()
	local cached = Utils.GetCachedVars(cacheKey, 2)
	if cached ~= nil then
		return cached
	end
	for slot = 1, #GetTeamPlayers(GetTeam()) do
		local member = GetTeamMember(slot)
		if member ~= nil and member:IsAlive() then
			local travelTime = GetUnitToLocationDistance(member, targetLocation) / member:GetCurrentMovementSpeed()
			if Utils.HasCriticalSpellWithCooldown(member, travelTime) then
				Utils.SetCachedVars(cacheKey, true)
				return true
			end
		end
	end
	Utils.SetCachedVars(cacheKey, false)
	return false
end
function Utils.HasTeamMemberWithCriticalItemInCooldown(targetLocation)
	local cacheKey = CacheKeys.HAS_CRITICAL_ITEM_CD + GetTeam()
	local cached = Utils.GetCachedVars(cacheKey, 2)
	if cached ~= nil then
		return cached
	end
	for slot = 1, #GetTeamPlayers(GetTeam()) do
		local member = GetTeamMember(slot)
		if member ~= nil and member:IsAlive() then
			local travelTime = GetUnitToLocationDistance(member, targetLocation) / member:GetCurrentMovementSpeed()
			for _, itemName in ipairs(Utils.ImportantItems) do
				local item = Utils.GetItem(member, itemName)
				if item and item:GetCooldownTimeRemaining() > travelTime then
					Utils.SetCachedVars(cacheKey, true)
					return true
				end
			end
		end
	end
	Utils.SetCachedVars(cacheKey, false)
	return false
end
function Utils.HasPossibleWallOfReplicaAround(bot)
	if bot:HasModifier("modifier_dark_seer_wall_slow") then
		return true
	end
	return false
end
function Utils.GetWallIllusionPositions(bot)
	local illusionPositions = {}
	if Utils.HasPossibleWallOfReplicaAround(bot) then
		local enemyHeroes = bot:GetNearbyHeroes(1600, true, BotMode.None) or {}
		for _, enemyHero in ipairs(enemyHeroes) do
			if enemyHero:HasModifier("modifier_darkseer_wallofreplica_illusion") then
				illusionPositions[#illusionPositions + 1] = enemyHero:GetLocation()
			end
		end
	end
	return illusionPositions
end
function Utils.IsLocationInDangerZone(bot, location)
	local radius = 1000 + 500
	local illusionPositions = Utils.GetWallIllusionPositions(bot)
	for _, illusionPosition in ipairs(illusionPositions) do
		local offset = sub(location, illusionPosition)
		if length2D(offset) < radius then
			return { inDanger = true, dangerCenter = illusionPosition }
		end
	end
	return { inDanger = false }
end
function Utils.RotateVector(vector, angle)
	local cosAngle = math.cos(angle)
	local sinAngle = math.sin(angle)
	return Vector(vector.x * cosAngle - vector.y * sinAngle, vector.x * sinAngle + vector.y * cosAngle, vector.z)
end
function Utils.GetSafeDestination(bot, location)
	local destination = location or add(bot:GetLocation(), RandomVector(260))
	local danger = Utils.IsLocationInDangerZone(bot, destination)
	if danger.inDanger and danger.dangerCenter then
		local dangerRadius = 1000 + 500
		local margin = 250
		local direction = sub(destination, danger.dangerCenter)
		if length2D(direction) == 0 then
			direction = RandomVector(100)
		end
		direction = direction:Normalized()
		local safeLocation = add(danger.dangerCenter, multiply(direction, dangerRadius + margin))
		local maxTries = 5
		local tries = 0
		while not IsLocationPassable(safeLocation) and tries < maxTries do
			direction = Utils.RotateVector(direction, 36 * math.pi / 180)
			safeLocation = add(danger.dangerCenter, multiply(direction, dangerRadius + margin))
			tries = tries + 1
		end
		if not IsLocationPassable(safeLocation) then
			return bot:GetLocation()
		end
		return safeLocation
	end
	return destination
end
function Utils.MoveBotSafely(bot, location)
	local botLocation = bot:GetLocation()
	local safeDestination = Utils.GetSafeDestination(bot, location)
	if length2D(sub(botLocation, safeDestination)) <= 100 then
		bot:Action_MoveToLocation(safeDestination)
		return
	end
	bot:Action_MoveToLocation(safeDestination)
end
local meaningfulActivities = {
	ACTIVITY_RUN,
	ACTIVITY_ATTACK,
	ACTIVITY_ATTACK2,
	ACTIVITY_ATTACK_EVENT,
	ACTIVITY_CAST_ABILITY_1,
	ACTIVITY_CAST_ABILITY_2,
	ACTIVITY_CAST_ABILITY_3,
	ACTIVITY_CAST_ABILITY_4,
	ACTIVITY_CAST_ABILITY_5,
	ACTIVITY_CAST_ABILITY_6,
	ACTIVITY_CHANNEL_ABILITY_1,
	ACTIVITY_CHANNEL_ABILITY_2,
	ACTIVITY_CHANNEL_ABILITY_3,
	ACTIVITY_CHANNEL_ABILITY_4,
	ACTIVITY_CHANNEL_ABILITY_5,
	ACTIVITY_CHANNEL_ABILITY_6,
}
Utils.ThinkActionType = ThinkActionType or {}
Utils.ThinkActionType.All = 0
Utils.ThinkActionType[Utils.ThinkActionType.All] = "All"
Utils.ThinkActionType.Rune = 1
Utils.ThinkActionType[Utils.ThinkActionType.Rune] = "Rune"
Utils.ThinkActionType.Defend = 2
Utils.ThinkActionType[Utils.ThinkActionType.Defend] = "Defend"
Utils.ThinkActionType.Push = 3
Utils.ThinkActionType[Utils.ThinkActionType.Push] = "Push"
Utils.ThinkActionType.Farm = 4
Utils.ThinkActionType[Utils.ThinkActionType.Farm] = "Farm"
function Utils.IsBotThinkingMeaningfulAction(bot, cacheFactor, actionType)
	if cacheFactor == nil then
		cacheFactor = 1
	end
	if actionType == nil then
		actionType = Utils.ThinkActionType.All
	end
	if cacheFactor < 0 then
		cacheFactor = 0
	elseif cacheFactor > 10 then
		cacheFactor = 10
	end
	local cacheKey = 50000 + bot:GetPlayerID() * 10 + actionType
	local cached = Utils.GetCachedVars(cacheKey, 0.11 * cacheFactor)
	if cached ~= nil then
		return cached
	end
	do
		local ok, handled, result = pcall(function()
			if arrayIncludes(meaningfulActivities, bot:GetAnimActivity()) then
				Utils.SetCachedVars(cacheKey, true)
				return true, true
			end
		end)
		if ok and handled then
			return result
		end
	end
	local queuedCount = bot:NumQueuedActions()
	if queuedCount > 0 then
		for i = 1, queuedCount do
			local queuedType = bot:GetQueuedActionType(i)
			if queuedType ~= BotActionType.None then
				Utils.SetCachedVars(cacheKey, true)
				return true
			end
		end
	end
	Utils.SetCachedVars(cacheKey, false)
	return false
end
return Utils
