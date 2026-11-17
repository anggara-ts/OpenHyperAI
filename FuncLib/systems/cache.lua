-- Shared bot system: cache.
local function arrayFilter(self, predicate, thisArg)
	local result = {}
	local count = 0
	for i = 1, #self do
		if predicate(thisArg, self[i], i - 1, self) then
			count = count + 1
			result[count] = self[i]
		end
	end
	return result
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
			error(newInstance(TypeError, ((("Cannot delete property " .. tostring(key)) .. " of ") .. tostring(target)) .. "."), 0)
		end
		descriptors[key] = nil
		return true
	end
	target[key] = nil
	return true
end
local function objectKeys(object)
	local result = {}
	local count = 0
	for key in pairs(object) do
		count = count + 1
		result[count] = key
	end
	return result
end
local function arrayForEach(self, callback, thisArg)
	for i = 1, #self do
		callback(thisArg, self[i], i - 1, self)
	end
end
local Cache = {}
local Dota = require(GetScriptDirectory() .. "/ts_libs/dota/index")
local Lane = Dota.Lane
local UnitType = Dota.UnitType
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local globalCache = {}
local cacheTtl = 0.5
local gameStateCache = nil
local unitStateCache = nil
local locationStateCache = nil
do
	local Utils = require(GetScriptDirectory() .. "/FuncLib/systems/utils")
	local setCachedVars = Utils.SetCachedVars
	local getCachedVars = Utils.GetCachedVars
	Cache.SetCachedVars = setCachedVars
	Cache.GetCachedVars = getCachedVars
end
Cache.CK = require(GetScriptDirectory() .. "/FuncLib/systems/cache_keys")
function Cache.getGlobalGameState()
	local now = DotaTime()
	if gameStateCache and now - gameStateCache.lastUpdate < cacheTtl then
		return gameStateCache
	end
	local team = GetTeam()
	local enemyTeam = GetOpposingTeam()
	local dotaTime = DotaTime()
	local gameMode = GetGameMode()
	local currentTime = gameMode == 23 and dotaTime * 2 or dotaTime
	local teamNetworth, enemyNetworth = Fu.GetInventoryNetworth()
	gameStateCache = {
		lastUpdate = now,
		currentTime = currentTime,
		gameMode = gameMode,
		team = team,
		enemyTeam = enemyTeam,
		ourAncient = GetAncient(team),
		enemyAncient = GetAncient(enemyTeam),
		aliveAllyCount = Fu.GetNumOfAliveHeroes(false),
		aliveEnemyCount = Fu.GetNumOfAliveHeroes(true),
		aliveAllyCoreCount = Fu.GetAliveCoreCount(false),
		aliveEnemyCoreCount = Fu.GetAliveCoreCount(true),
		teamNetworth = teamNetworth,
		enemyNetworth = enemyNetworth,
		averageLevel = Fu.GetAverageLevel(false),
		hasAegis = Fu.DoesTeamHaveAegis(),
		isEarlyGame = Fu.IsEarlyGame(),
		isMidGame = Fu.IsMidGame(),
		isLateGame = Fu.IsLateGame(),
		isLaningPhase = Fu.IsInLaningPhase(),
	}
	return gameStateCache
end
function Cache.getGlobalUnitState()
	local now = DotaTime()
	if unitStateCache and now - unitStateCache.lastUpdate < cacheTtl then
		return unitStateCache
	end
	local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
	unitStateCache = {
		lastUpdate = now,
		enemyBuildings = GetUnitList(UnitType.EnemyBuildings),
		alliedHeroes = GetUnitList(UnitType.AlliedHeroes),
		enemyHeroes = arrayFilter(GetUnitList(UnitType.Enemies), function(_, unit)
			return Fu.IsValidHero(unit)
		end),
		alliedCreeps = GetUnitList(UnitType.AlliedCreeps),
		enemyCreeps = arrayFilter(GetUnitList(UnitType.Enemies), function(_, unit)
			return unit:IsCreep() or unit:IsAncientCreep()
		end),
	}
	return unitStateCache
end
function Cache.getGlobalLocationState()
	local now = DotaTime()
	if locationStateCache and now - locationStateCache.lastUpdate < cacheTtl then
		return locationStateCache
	end
	local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
	local team = GetTeam()
	locationStateCache = {
		lastUpdate = now,
		laneFronts = {
			[Lane.Top] = GetLaneFrontLocation(team, Lane.Top, 0),
			[Lane.Mid] = GetLaneFrontLocation(team, Lane.Mid, 0),
			[Lane.Bot] = GetLaneFrontLocation(team, Lane.Bot, 0),
		},
		teamFountain = Fu.GetTeamFountain(),
		enemyFountain = Fu.GetTeamFountain(),
		roshanLocation = Fu.GetCurrentRoshanLocation(),
		tormentorLocation = Fu.GetTormentorLocation(team),
		tormentorWaitingLocation = Fu.GetTormentorWaitingLocation(team),
	}
	return locationStateCache
end
function Cache.getCachedData(key, ttl, compute)
	local now = DotaTime()
	local entry = globalCache[key]
	if entry and now - entry.lastUpdate < ttl then
		return entry.data
	end
	local data = compute()
	globalCache[key] = { lastUpdate = now, data = data }
	return data
end
function Cache.cleanupGlobalCache()
	local now = DotaTime()
	local maxAge = 10
	arrayForEach(objectKeys(globalCache), function(_, key)
		if now - globalCache[key].lastUpdate > maxAge then
			deleteProperty(globalCache, key)
		end
	end)
end
function Cache.clearAllCaches()
	arrayForEach(objectKeys(globalCache), function(_, key)
		deleteProperty(globalCache, key)
	end)
	gameStateCache = nil
	unitStateCache = nil
	locationStateCache = nil
end
function Cache.getCachedAlliesNearLoc(location, radius)
	local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
	return Fu.GetAlliesNearLoc(location, radius)
end
function Cache.getCachedEnemiesNearLoc(location, radius)
	local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
	return Fu.GetEnemiesNearLoc(location, radius)
end
local lastCleanupTime = 0
function Cache.autoCleanupCache()
	local now = DotaTime()
	if now - lastCleanupTime > 30 then
		Cache.cleanupGlobalCache()
		lastCleanupTime = now
	end
end
return Cache
