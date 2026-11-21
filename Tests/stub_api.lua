-- A stub of the Dota 2 bot API, good enough to LOAD the bot scripts outside the game.
--
-- What it does:
--   * Module loading as in the game: GetScriptDirectory() is "bots", and require/dofile accept
--     "bots/FuncLib/x", "bots.FuncLib.x" and a dofile path without ".lua"; all resolve to <repo>/FuncLib/x.lua.
--   * API constants: the values the scripts themselves fall back to (FuncLib/dota/enums.lua and friends)
--     are pinned; any other UPPER_CASE name with an API prefix (BOT_, TEAM_, LANE_, DOTA_, ...) reads as a
--     distinct number, so two unknown constants never compare equal.
--   * API functions: the global functions of the real API (dumped in game) are stubbed with simple
--     defaults. A real API name that has no stub here raises "stub missing: <name>", so a test shows
--     what to add. Any other unknown global reads as nil, as in the game (a nil-global bug fails there too).
--   * Units: GetBot(), GetTeamMember(1..5) and the enemies are fake units. Their methods are the real
--     unit API; methods without an explicit stub return a default by name (Is*/Has*/Was* false,
--     Get* 0, Action* no-op). Fields the scripts set on a unit (bot.foo = 1) work as on a real handle.
--   * Team slots vs player IDs: GetTeamMember(i) takes a slot 1-5 and errors on anything else.
--     Player IDs are deliberately NOT 0-9 or 1-5: Radiant has 10-14, Dire 15-19. Functions that take a
--     player ID (IsPlayerBot, GetSelectedHeroName, IsHeroAlive, ...) error on an unknown ID, so passing
--     a slot where an ID is expected (or the other way round) fails loudly.
--   * RandomInt / RandomFloat / math.random use a fixed generator reseeded by every reset(), so a case
--     takes the same branch on every interpreter.
--   * print / Msg / Warning are captured in Stub.printed (set Stub.echo = true to see them too).
--
-- Usage (see Tests/run.lua): Stub.install(root) once, then Stub.reset({ hero = "npc_dota_hero_lich" })
-- before each case. reset() restores the globals, string/table/math and package.loaded to the state
-- right after install, so every case starts from a clean game.
local Stub = {}

local realLoadfile = loadfile
local unpackArgs = unpack or table.unpack
local searchers = package.loaders or package.searchers

Stub.printed = {}
Stub.echo = false
Stub.time = 0

-- Constants -----------------------------------------------------------------------------------------

local DESIRE = { NONE = 0, VERYLOW = 0.1, LOW = 0.25, MODERATE = 0.5, HIGH = 0.75, VERYHIGH = 0.9, ABSOLUTE = 1 }

-- Values the scripts already fall back to when the engine does not define a constant.
local CONSTANTS = {
	TEAM_RADIANT = 2,
	TEAM_DIRE = 3,
	TEAM_NEUTRAL = 4,
	TEAM_NONE = 5,
	LANE_NONE = 0,
	LANE_TOP = 1,
	LANE_MID = 2,
	LANE_BOT = 3,
	BOT_MODE_NONE = 0,
	BOT_MODE_LANING = 1,
	BOT_MODE_ATTACK = 2,
	BOT_MODE_ROAM = 3,
	BOT_MODE_RETREAT = 4,
	BOT_MODE_SECRET_SHOP = 5,
	BOT_MODE_SIDE_SHOP = 6,
	BOT_MODE_RUNE = 7,
	BOT_MODE_PUSH_TOWER_TOP = 8,
	BOT_MODE_PUSH_TOWER_MID = 9,
	BOT_MODE_PUSH_TOWER_BOT = 10,
	BOT_MODE_DEFEND_TOWER_TOP = 11,
	BOT_MODE_DEFEND_TOWER_MID = 12,
	BOT_MODE_DEFEND_TOWER_BOT = 13,
	BOT_MODE_ASSEMBLE = 14,
	BOT_MODE_TEAM_ROAM = 16,
	BOT_MODE_FARM = 17,
	BOT_MODE_DEFEND_ALLY = 18,
	BOT_MODE_EVASIVE_MANEUVERS = 19,
	BOT_MODE_ROSHAN = 20,
	BOT_MODE_ITEM = 21,
	BOT_MODE_WARD = 22,
	DAMAGE_TYPE_NONE = 0,
	DAMAGE_TYPE_PHYSICAL = 1,
	DAMAGE_TYPE_MAGICAL = 2,
	DAMAGE_TYPE_PURE = 4,
	DAMAGE_TYPE_ALL = 7,
	ATTRIBUTE_INVALID = -1,
	ATTRIBUTE_STRENGTH = 0,
	ATTRIBUTE_AGILITY = 1,
	ATTRIBUTE_INTELLECT = 2,
	ATTRIBUTE_ALL = 3,
	ATTRIBUTE_MAX = 4,
	GAME_STATE_INIT = 0,
	GAME_STATE_WAIT_FOR_MAP_TO_LOAD = 6,
	GAME_STATE_CUSTOM_GAME_SETUP = 2,
	GAME_STATE_HERO_SELECTION = 3,
	GAME_STATE_STRATEGY_TIME = 4,
	GAME_STATE_TEAM_SHOWCASE = 5,
	GAME_STATE_PRE_GAME = 7,
	GAME_STATE_GAME_IN_PROGRESS = 8,
	GAME_STATE_POST_GAME = 9,
	GAME_STATE_DISCONNECT = 10,
	GAMEMODE_NONE = 0,
	GAMEMODE_AP = 1,
	GAMEMODE_CM = 2,
	GAMEMODE_RD = 3,
	GAMEMODE_SD = 4,
	GAMEMODE_AR = 5,
	GAMEMODE_REVERSE_CM = 8,
	GAMEMODE_CD = 16,
	GAMEMODE_ARDM = 20,
	GAMEMODE_1V1MID = 21,
	GAMEMODE_ALL_DRAFT = 22,
	GAMEMODE_TURBO = 23,
	UNIT_LIST_ALL = 0,
	UNIT_LIST_ALLIES = 1,
	UNIT_LIST_ALLIED_HEROES = 2,
	UNIT_LIST_ALLIED_CREEPS = 3,
	UNIT_LIST_ALLIED_WARDS = 4,
	UNIT_LIST_ALLIED_BUILDINGS = 5,
	UNIT_LIST_ENEMIES = 7,
	UNIT_LIST_ENEMY_HEROES = 8,
	UNIT_LIST_ENEMY_CREEPS = 9,
	UNIT_LIST_ENEMY_WARDS = 10,
	UNIT_LIST_ENEMY_BUILDINGS = 11,
	UNIT_LIST_NEUTRAL_CREEPS = 13,
	RUNE_POWERUP_1 = 0,
	RUNE_POWERUP_2 = 1,
	RUNE_BOUNTY_1 = 2,
	RUNE_BOUNTY_2 = 3,
	RUNE_BOUNTY_3 = 4,
	RUNE_BOUNTY_4 = 5,
	SHOP_HOME = 0,
	SHOP_SIDE = 1,
	SHOP_SECRET = 2,
	SHOP_SIDE2 = 4,
	SHOP_SECRET2 = 5,
	TOWER_TOP_1 = 0,
	TOWER_TOP_2 = 1,
	TOWER_TOP_3 = 2,
	TOWER_MID_1 = 3,
	TOWER_MID_2 = 4,
	TOWER_MID_3 = 5,
	TOWER_BOT_1 = 6,
	TOWER_BOT_2 = 7,
	TOWER_BOT_3 = 8,
	TOWER_BASE_1 = 9,
	TOWER_BASE_2 = 10,
	BARRACKS_TOP_MELEE = 0,
	BARRACKS_TOP_RANGED = 1,
	BARRACKS_MID_MELEE = 2,
	BARRACKS_MID_RANGED = 3,
	BARRACKS_BOT_MELEE = 4,
	BARRACKS_BOT_RANGED = 5,
	DOTA_ABILITY_BEHAVIOR_NO_TARGET = 4,
	DOTA_ABILITY_BEHAVIOR_UNIT_TARGET = 8,
	DOTA_ABILITY_BEHAVIOR_POINT = 16,
	DOTA_ABILITY_BEHAVIOR_AOE = 32,
	DOTA_ABILITY_BEHAVIOR_NOT_LEARNABLE = 64,
	DOTA_UNIT_TARGET_HERO = 1,
	DOTA_UNIT_TARGET_TEAM_FRIENDLY = 1,
	DOTA_UNIT_TARGET_TEAM_ENEMY = 2,
	DOTA_UNIT_TARGET_TEAM_BOTH = 3,
}
for level, value in pairs(DESIRE) do
	CONSTANTS["BOT_ACTION_DESIRE_" .. level] = value
	CONSTANTS["BOT_MODE_DESIRE_" .. level] = value
end
Stub.CONSTANTS = CONSTANTS

-- Other UPPER_CASE names with these prefixes are API constants: each reads as its own number.
local API_CONSTANT_PREFIXES = {
	"BOT_",
	"TEAM_",
	"LANE_",
	"DAMAGE_TYPE_",
	"UNIT_LIST_",
	"ATTRIBUTE_",
	"RUNE_",
	"GAMEMODE_",
	"GAME_STATE_",
	"ITEM_SLOT_TYPE_",
	"COURIER_",
	"ABILITY_",
	"DOTA_",
	"TOWER_",
	"BARRACKS_",
	"SHOP_",
	"HEROPICK_",
	"HERO_PICK_",
	"PURCHASE_ITEM_",
	"GLYPH_",
	"ACTIVITY_",
}
local fabricated, nextFabricated = {}, 100000
local function apiConstant(name)
	if fabricated[name] then
		return fabricated[name]
	end
	if not string.find(name, "^[A-Z][A-Z0-9_]*$") then
		return nil
	end
	for i = 1, #API_CONSTANT_PREFIXES do
		local prefix = API_CONSTANT_PREFIXES[i]
		if string.sub(name, 1, #prefix) == prefix then
			nextFabricated = nextFabricated + 1
			fabricated[name] = nextFabricated
			return nextFabricated
		end
	end
	return nil
end

-- Vector ---------------------------------------------------------------------------------------------

-- In the game a Vector is userdata (global_overrides.lua checks type(location) == "userdata"), so the
-- stub makes one with newproxy (LuaJIT / Lua 5.1) and keeps x, y, z in a side table. Without newproxy
-- (plain Lua 5.2+) vectors are tables.
local VectorMethods = {}
local vectorProto = newproxy and newproxy(true) or nil
local VectorMeta = vectorProto and getmetatable(vectorProto) or {}
local vectorData = setmetatable({}, { __mode = "k" })
local function newVector(x, y, z)
	local data = { x = x or 0, y = y or 0, z = z or 0 }
	if vectorProto == nil then
		return setmetatable(data, VectorMeta)
	end
	local v = newproxy(vectorProto)
	vectorData[v] = data
	return v
end
local function isVector(v)
	return getmetatable(v) == VectorMeta
end
VectorMeta.__index = function(v, key)
	local data = vectorData[v]
	if data ~= nil and data[key] ~= nil then
		return data[key]
	end
	local method = VectorMethods[key]
	if method == nil then
		error("stub missing: Vector:" .. tostring(key), 2)
	end
	return method
end
VectorMeta.__newindex = function(v, key, value)
	if key ~= "x" and key ~= "y" and key ~= "z" then
		error("Vector has no field " .. tostring(key), 2)
	end
	local data = vectorData[v]
	if data ~= nil then
		data[key] = value
	else
		rawset(v, key, value)
	end
end
VectorMeta.__add = function(a, b)
	return newVector(a.x + b.x, a.y + b.y, a.z + b.z)
end
VectorMeta.__sub = function(a, b)
	return newVector(a.x - b.x, a.y - b.y, a.z - b.z)
end
VectorMeta.__mul = function(a, b)
	if type(a) == "number" then
		return newVector(b.x * a, b.y * a, b.z * a)
	elseif type(b) == "number" then
		return newVector(a.x * b, a.y * b, a.z * b)
	end
	return newVector(a.x * b.x, a.y * b.y, a.z * b.z)
end
VectorMeta.__div = function(a, b)
	if type(b) == "number" then
		return newVector(a.x / b, a.y / b, a.z / b)
	end
	return newVector(a.x / b.x, a.y / b.y, a.z / b.z)
end
VectorMeta.__unm = function(a)
	return newVector(-a.x, -a.y, -a.z)
end
VectorMeta.__eq = function(a, b)
	return a.x == b.x and a.y == b.y and a.z == b.z
end
VectorMeta.__tostring = function(a)
	return string.format("Vector(%s, %s, %s)", tostring(a.x), tostring(a.y), tostring(a.z))
end
function VectorMethods.Length(a)
	return math.sqrt(a.x * a.x + a.y * a.y + a.z * a.z)
end
function VectorMethods.Length2D(a)
	return math.sqrt(a.x * a.x + a.y * a.y)
end
function VectorMethods.Normalized(a)
	local length = VectorMethods.Length(a)
	if length == 0 then
		return newVector(0, 0, 0)
	end
	return newVector(a.x / length, a.y / length, a.z / length)
end
function VectorMethods.Dot(a, b)
	return a.x * b.x + a.y * b.y + a.z * b.z
end
function VectorMethods.Cross(a, b)
	return newVector(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x)
end
Stub.Vector = newVector
Stub.isVector = isVector

-- Abilities ------------------------------------------------------------------------------------------

-- The real ability API (CDOTABaseAbility_BotScript, dumped in game).
local ABILITY_METHODS = {}
for name in
	string.gmatch(
		"CanAbilityBeUpgraded CanBeDisassembled GetAOERadius GetAbilityDamage GetAutoCastState GetBehavior "
			.. "GetCastPoint GetCastRange GetCaster GetChannelTime GetChannelledManaCostPerSecond GetCooldown "
			.. "GetCooldownTimeRemaining GetCurrentCharges GetDamageType GetDuration GetEstimatedDamageToTarget "
			.. "GetHeroLevelRequiredToUpgrade GetInitialCharges GetLevel GetManaCost GetMaxLevel GetName "
			.. "GetPowerTreadsStat GetSecondaryCharges GetSpecialValueFloat GetSpecialValueInt GetTargetFlags "
			.. "GetTargetTeam GetTargetType GetToggleState IsActivated IsChanneling IsCombineLocked IsCooldownReady "
			.. "IsFullyCastable IsHidden IsInAbilityPhase IsItem IsNull IsOwnersManaEnough IsPassive IsStealable "
			.. "IsStolen IsTalent IsToggle IsTrained IsUltimate ProcsMagicStick ToggleAutoCast",
		"%S+"
	)
do
	ABILITY_METHODS[name] = true
end

local AbilityImpl = {}
function AbilityImpl:GetName()
	return self._name
end
function AbilityImpl:GetCaster()
	return self._caster
end
function AbilityImpl:IsTalent()
	return string.find(self._name, "^special_bonus") ~= nil
end
function AbilityImpl:IsUltimate()
	return self._ultimate == true
end
function AbilityImpl:IsItem()
	return string.find(self._name, "^item_") ~= nil
end
function AbilityImpl:IsHidden()
	return self._hidden == true or self._name == "generic_hidden"
end
function AbilityImpl:GetBehavior()
	return self._behavior or 0
end
function AbilityImpl:GetMaxLevel()
	return self._maxLevel or (self._ultimate and 3 or 4)
end
function AbilityImpl:GetHeroLevelRequiredToUpgrade()
	return 1
end
function AbilityImpl:IsActivated()
	return true
end
function AbilityImpl:IsCooldownReady()
	return true
end
function AbilityImpl:IsOwnersManaEnough()
	return true
end

local function defaultMethod(name)
	if string.find(name, "^Is") or string.find(name, "^Has") or string.find(name, "^Was") then
		return function()
			return false
		end
	elseif string.find(name, "^Can") or string.find(name, "^Using") or string.find(name, "^Procs") then
		return function()
			return false
		end
	elseif string.find(name, "^Action") or string.find(name, "^Set") or string.find(name, "^Toggle") then
		return function() end
	end
	return function()
		return 0
	end
end
local defaultCache = {}
local function cachedDefault(name)
	local f = defaultCache[name]
	if f == nil then
		f = defaultMethod(name)
		defaultCache[name] = f
	end
	return f
end

-- The game exposes the ability class as CDOTABaseAbility_BotScript (global_overrides.lua patches it).
local AbilityClass = {}
for name in pairs(ABILITY_METHODS) do
	AbilityClass[name] = AbilityImpl[name] or cachedDefault(name)
end
local AbilityMeta = { __index = AbilityClass }
local function newAbility(name, caster, ultimate)
	return setmetatable({ _name = name, _caster = caster, _ultimate = ultimate }, AbilityMeta)
end
Stub.newAbility = newAbility

-- Units ----------------------------------------------------------------------------------------------

-- The real unit API (CDOTA_Bot_Script, dumped in game).
local UNIT_METHODS = {}
for name in
	string.gmatch(
		"ActionImmediate_Buyback ActionImmediate_Chat ActionImmediate_Courier ActionImmediate_DisassembleItem "
			.. "ActionImmediate_Glyph ActionImmediate_LevelAbility ActionImmediate_Ping ActionImmediate_PurchaseItem "
			.. "ActionImmediate_SellItem ActionImmediate_SetItemCombineLock ActionImmediate_SwapItems "
			.. "ActionPush_AttackMove ActionPush_AttackUnit ActionPush_Delay ActionPush_DropItem "
			.. "ActionPush_MoveDirectly ActionPush_MovePath ActionPush_MoveToLocation ActionPush_MoveToUnit "
			.. "ActionPush_PickUpItem ActionPush_PickUpRune ActionPush_UseAbility ActionPush_UseAbilityOnEntity "
			.. "ActionPush_UseAbilityOnLocation ActionPush_UseAbilityOnTree ActionPush_UseShrine "
			.. "ActionQueue_AttackMove ActionQueue_AttackUnit ActionQueue_Delay ActionQueue_DropItem "
			.. "ActionQueue_MoveDirectly ActionQueue_MovePath ActionQueue_MoveToLocation ActionQueue_MoveToUnit "
			.. "ActionQueue_PickUpItem ActionQueue_PickUpRune ActionQueue_UseAbility ActionQueue_UseAbilityOnEntity "
			.. "ActionQueue_UseAbilityOnLocation ActionQueue_UseAbilityOnTree ActionQueue_UseShrine "
			.. "Action_AttackMove Action_AttackUnit Action_ClearActions Action_Delay Action_DropItem "
			.. "Action_MoveDirectly Action_MovePath Action_MoveToLocation Action_MoveToUnit Action_PickUpItem "
			.. "Action_PickUpRune Action_UseAbility Action_UseAbilityOnEntity Action_UseAbilityOnLocation "
			.. "Action_UseAbilityOnTree Action_UseShrine CanBeSeen DistanceFromFountain DistanceFromSecretShop "
			.. "DistanceFromSideShop FindAoELocation FindItemSlot GetAbilityByName GetAbilityInSlot GetAbilityPoints "
			.. "GetAbilityTarget GetAcquisitionRange GetActiveMode GetActiveModeDesire GetActualIncomingDamage "
			.. "GetAnimActivity GetAnimCycle GetArmor GetAssignedLane GetAttackDamage GetAttackPoint "
			.. "GetAttackProjectileSpeed GetAttackRange GetAttackSpeed GetAttackTarget GetAttributeValue "
			.. "GetBaseDamage GetBaseDamageVariance GetBaseHealthRegen GetBaseManaRegen GetBaseMovementSpeed "
			.. "GetBoundingRadius GetBountyGoldMax GetBountyGoldMin GetBountyXP GetBuybackCooldown GetBuybackCost "
			.. "GetCourierValue GetCurrentActionType GetCurrentActiveAbility GetCurrentMovementSpeed "
			.. "GetCurrentVisionRange GetDayTimeVisionRange GetDenies GetDifficulty GetEstimatedDamageToTarget "
			.. "GetEvasion GetExtrapolatedLocation GetFacing GetGold GetGroundHeight GetHealth GetHealthRegen "
			.. "GetHealthRegenPerStr GetIncomingTrackingProjectiles GetItemInSlot GetItemSlotType "
			.. "GetLastAttackTime GetLastHits GetLevel GetLocation GetMagicResist GetMana GetManaRegen "
			.. "GetManaRegenPerInt GetMaxHealth GetMaxMana GetModifierAuxiliaryUnits GetModifierByName "
			.. "GetModifierList GetModifierName GetModifierRemainingDuration GetModifierStackCount "
			.. "GetMostRecentPing GetMovementDirectionStability GetNearbyBarracks GetNearbyCreeps "
			.. "GetNearbyFillers GetNearbyHeroes GetNearbyLaneCreeps GetNearbyNeutralCreeps GetNearbyShrines "
			.. "GetNearbyTowers GetNearbyTrees GetNetWorth GetNextItemPurchaseValue GetNightTimeVisionRange "
			.. "GetOffensivePower GetPlayerID GetPrimaryAttribute GetQueuedActionType GetRawOffensivePower "
			.. "GetRemainingLifespan GetRespawnTime GetSecondsPerAttack GetSlowDuration GetSpellAmp "
			.. "GetStashValue GetStunDuration GetTalent GetTarget GetTeam GetUnitName GetUnitToLocationDistance "
			.. "GetVelocity GetXPNeededToLevel HasBlink HasBuyback HasInvisibility HasMinistunOnAttack "
			.. "HasModifier HasScepter HasSilence IsAlive IsAncientCreep IsAttackImmune IsBlind IsBlockDisabled "
			.. "IsBot IsBuilding IsCastingAbility IsChanneling IsCourier IsCreep IsDisarmed IsDominated "
			.. "IsEvadeDisabled IsFacingLocation IsFort IsHero IsHexed IsIllusion IsInvisible IsInvulnerable "
			.. "IsMagicImmune IsMinion IsMuted IsNightmared IsNull IsRooted IsSilenced IsSpeciallyDeniable "
			.. "IsSpeciallyUndeniable IsStunned IsTower IsUnableToMiss IsUsingAbility NumModifiers "
			.. "NumQueuedActions OriginalGetHealth OriginalGetMaxHealth SetNextItemPurchaseValue SetTarget "
			.. "TimeSinceDamagedByAnyHero TimeSinceDamagedByCreep TimeSinceDamagedByHero TimeSinceDamagedByPlayer "
			.. "TimeSinceDamagedByTower UsingItemBreaksInvisibility WasRecentlyDamagedByAnyHero "
			.. "WasRecentlyDamagedByCreep WasRecentlyDamagedByHero WasRecentlyDamagedByPlayer "
			.. "WasRecentlyDamagedByTower",
		"%S+"
	)
do
	UNIT_METHODS[name] = true
end

local function emptyList()
	return {}
end
local UnitImpl = {}
function UnitImpl:GetUnitName()
	return self._name
end
function UnitImpl:GetTeam()
	return self._team
end
function UnitImpl:GetPlayerID()
	return self._pid
end
function UnitImpl:GetLocation()
	return self._loc
end
function UnitImpl:GetExtrapolatedLocation()
	return self._loc
end
function UnitImpl:GetVelocity()
	return newVector(0, 0, 0)
end
function UnitImpl:GetHealth()
	return self._hp
end
UnitImpl.OriginalGetHealth = UnitImpl.GetHealth
function UnitImpl:GetMaxHealth()
	return self._maxHp
end
UnitImpl.OriginalGetMaxHealth = UnitImpl.GetMaxHealth
function UnitImpl:GetMana()
	return self._mana
end
function UnitImpl:GetMaxMana()
	return self._maxMana
end
function UnitImpl:GetLevel()
	return self._level
end
function UnitImpl:IsAlive()
	return self._alive
end
function UnitImpl:IsHero()
	return self._hero
end
function UnitImpl:IsBot()
	return true
end
function UnitImpl:CanBeSeen()
	return true
end
function UnitImpl:GetAssignedLane()
	return self._lane
end
function UnitImpl:GetActiveMode()
	return CONSTANTS.BOT_MODE_NONE
end
function UnitImpl:GetDifficulty()
	return 4
end
function UnitImpl:GetAttackRange()
	return 150
end
function UnitImpl:GetCurrentMovementSpeed()
	return 300
end
UnitImpl.GetBaseMovementSpeed = UnitImpl.GetCurrentMovementSpeed
function UnitImpl:GetSecondsPerAttack()
	return 1.7
end
function UnitImpl:GetBoundingRadius()
	return 24
end
function UnitImpl:GetCurrentVisionRange()
	return 1800
end
UnitImpl.GetDayTimeVisionRange = UnitImpl.GetCurrentVisionRange
function UnitImpl:GetNightTimeVisionRange()
	return 800
end
function UnitImpl:GetPrimaryAttribute()
	return CONSTANTS.ATTRIBUTE_STRENGTH
end
function UnitImpl:GetModifierByName()
	return -1
end
function UnitImpl:GetModifierName()
	return ""
end
function UnitImpl:GetItemInSlot(slot)
	return self._items[slot]
end
function UnitImpl:FindItemSlot()
	return -1
end
function UnitImpl:GetItemSlotType(slot)
	if slot <= 5 then
		return 0
	elseif slot <= 8 then
		return 1
	end
	return 2
end
function UnitImpl:GetAbilityInSlot(slot)
	return self._slots[slot]
end
function UnitImpl:GetAbilityByName(name)
	if type(name) ~= "string" then
		error("GetAbilityByName expects a string, got " .. type(name), 2)
	end
	for _, ability in pairs(self._slots) do
		if ability:GetName() == name then
			return ability
		end
	end
	local ability = self._byName[name]
	if ability == nil then
		ability = newAbility(name, self, false)
		self._byName[name] = ability
	end
	return ability
end
function UnitImpl:GetUnitToLocationDistance(location)
	return (self._loc - location):Length2D()
end
function UnitImpl:GetFacing()
	return 0
end
function UnitImpl:IsFacingLocation()
	return true
end
function UnitImpl:GetAttackTarget()
	return nil
end
UnitImpl.GetTarget = UnitImpl.GetAttackTarget
UnitImpl.GetAbilityTarget = UnitImpl.GetAttackTarget
UnitImpl.GetCurrentActiveAbility = UnitImpl.GetAttackTarget
UnitImpl.GetTalent = UnitImpl.GetAttackTarget
function UnitImpl:FindAoELocation()
	return { count = 0, targetloc = self._loc }
end
function UnitImpl:GetMostRecentPing()
	return { time = -100, location = newVector(0, 0, 0), normal_ping = true }
end
function UnitImpl:GetNearbyHeroes(radius, enemy)
	local result = {}
	local team = enemy and (self._team == CONSTANTS.TEAM_RADIANT and CONSTANTS.TEAM_DIRE or CONSTANTS.TEAM_RADIANT)
		or self._team
	for _, unit in ipairs(Stub.heroes) do
		if unit._team == team and unit._alive and (unit._loc - self._loc):Length2D() <= math.min(radius, 1600) then
			result[#result + 1] = unit
		end
	end
	return result
end
for _, name in ipairs({
	"GetNearbyBarracks",
	"GetNearbyCreeps",
	"GetNearbyFillers",
	"GetNearbyLaneCreeps",
	"GetNearbyNeutralCreeps",
	"GetNearbyShrines",
	"GetNearbyTowers",
	"GetNearbyTrees",
	"GetModifierList",
	"GetModifierAuxiliaryUnits",
	"GetIncomingTrackingProjectiles",
}) do
	UnitImpl[name] = emptyList
end

-- The game exposes the unit class as CDOTA_Bot_Script (global_overrides.lua patches it). Keys that are
-- not API methods read as nil: fields the scripts set on a handle (bot.assignedRole, ...) work as in game.
local UnitClass = {}
for name in pairs(UNIT_METHODS) do
	UnitClass[name] = UnitImpl[name] or cachedDefault(name)
end
local UnitMeta = { __index = UnitClass }
UnitMeta.__tostring = function(unit)
	return "unit(" .. tostring(unit._name) .. ")"
end

-- Q W E, two hidden slots, R in slot 5, talents in slots 10-17 (the usual hero layout).
local function heroSlots(unit)
	local short = string.gsub(unit._name, "^npc_dota_hero_", "")
	local slots = {}
	for slot = 0, 2 do
		slots[slot] = newAbility(short .. "_ability_" .. (slot + 1), unit, false)
	end
	slots[3] = newAbility("generic_hidden", unit, false)
	slots[4] = newAbility("generic_hidden", unit, false)
	slots[5] = newAbility(short .. "_ultimate", unit, true)
	for slot = 10, 17 do
		slots[slot] = newAbility("special_bonus_" .. short .. "_" .. (slot - 9), unit, false)
	end
	return slots
end

-- Gives a unit real ability slots (slot 0 first) in place of the usual layout. Each entry is a table:
-- name, ultimate, hidden, behavior (ABILITY_BEHAVIOR_* bits), maxLevel.
function Stub.setSlots(unit, entries)
	local slots = {}
	for index, entry in ipairs(entries) do
		local ability = newAbility(entry.name, unit, entry.ultimate == true)
		ability._hidden = entry.hidden
		ability._behavior = entry.behavior
		ability._maxLevel = entry.maxLevel
		slots[index - 1] = ability
	end
	unit._slots = slots
	unit._byName = {}
end

-- props: name, team, pid, loc, hp, maxHp, mana, maxMana, level, alive, hero, lane.
function Stub.newUnit(props)
	local unit = {
		_name = props.name or "npc_dota_creep_badguys_melee",
		_team = props.team or CONSTANTS.TEAM_DIRE,
		_pid = props.pid or -1,
		_loc = props.loc or newVector(0, 0, 0),
		_maxHp = props.maxHp or 1000,
		_maxMana = props.maxMana or 500,
		_level = props.level or 1,
		_lane = props.lane or CONSTANTS.LANE_MID,
		_items = {},
		_byName = {},
	}
	unit._hp = props.hp or unit._maxHp
	unit._mana = props.mana or unit._maxMana
	if props.alive == nil then
		unit._alive = true
	else
		unit._alive = props.alive
	end
	if props.hero == nil then
		unit._hero = string.find(unit._name, "^npc_dota_hero_") ~= nil
	else
		unit._hero = props.hero
	end
	setmetatable(unit, UnitMeta)
	unit._slots = unit._hero and heroSlots(unit) or {}
	return unit
end

-- The game -------------------------------------------------------------------------------------------

local RADIANT, DIRE = CONSTANTS.TEAM_RADIANT, CONSTANTS.TEAM_DIRE
Stub.PLAYER_IDS = { [RADIANT] = { 10, 11, 12, 13, 14 }, [DIRE] = { 15, 16, 17, 18, 19 } }
local DEFAULT_HEROES = {
	[RADIANT] = {
		"npc_dota_hero_juggernaut",
		"npc_dota_hero_lina",
		"npc_dota_hero_tidehunter",
		"npc_dota_hero_rubick",
		"npc_dota_hero_lion",
	},
	[DIRE] = {
		"npc_dota_hero_sven",
		"npc_dota_hero_zuus",
		"npc_dota_hero_axe",
		"npc_dota_hero_earthshaker",
		"npc_dota_hero_crystal_maiden",
	},
}
local FOUNTAIN = { [RADIANT] = newVector(-7000, -6500, 384), [DIRE] = newVector(7000, 6400, 384) }

local function playerTeam(pid)
	for team, ids in pairs(Stub.PLAYER_IDS) do
		for slot = 1, 5 do
			if ids[slot] == pid then
				return team, slot
			end
		end
	end
	return nil
end
-- Every API function that takes a player ID goes through this: a team slot (1-5) or a made-up
-- number is an error, not a silent nil.
local function checkPlayer(pid, fname)
	local team, slot = playerTeam(pid)
	if team == nil then
		error(
			string.format(
				"%s expects a player ID (Radiant 10-14, Dire 15-19 in the stub), got %s (a team slot?)",
				fname,
				tostring(pid)
			),
			3
		)
	end
	return Stub.teams[team][slot]
end

local function opposing(team)
	return team == RADIANT and DIRE or RADIANT
end

-- Random numbers: a fixed generator (Park-Miller, exact in doubles), reseeded by Stub.reset, so a test
-- takes the same branch under LuaJIT and any other interpreter. Replaces math.random too.
local randomState = 1
local function nextRandom()
	randomState = (randomState * 16807) % 2147483647
	return randomState / 2147483647
end
local function stubRandom(m, n)
	if m == nil then
		return nextRandom()
	end
	if n == nil then
		m, n = 1, m
	end
	return m + math.floor(nextRandom() * (n - m + 1))
end
local function stubRandomseed(seed)
	randomState = math.floor(seed or 1) % 2147483646 + 1
end

local api = {}
function api.GetScriptDirectory()
	return "bots"
end
function api.DotaTime()
	return Stub.time
end
function api.GameTime()
	return Stub.time + 90
end
function api.RealTime()
	return Stub.time + 90
end
function api.GetGameState()
	return CONSTANTS.GAME_STATE_GAME_IN_PROGRESS
end
function api.GetGameStateTimeRemaining()
	return 0
end
function api.GetGameMode()
	return CONSTANTS.GAMEMODE_AP
end
function api.GetHeroPickState()
	return 0
end
function api.GetBot()
	return Stub.bot
end
function api.GetTeam()
	return Stub.bot._team
end
function api.GetOpposingTeam()
	return opposing(Stub.bot._team)
end
function api.GetTeamPlayers(team)
	local ids = Stub.PLAYER_IDS[team]
	if ids == nil then
		error("GetTeamPlayers: unknown team " .. tostring(team), 2)
	end
	return { ids[1], ids[2], ids[3], ids[4], ids[5] }
end
function api.GetTeamMember(slot)
	if type(slot) ~= "number" or slot < 1 or slot > 5 or slot % 1 ~= 0 then
		error("GetTeamMember expects a team slot 1-5, got " .. tostring(slot) .. " (a player ID?)", 2)
	end
	return Stub.teams[Stub.bot._team][slot]
end
function api.GetTeamForPlayer(pid)
	return checkPlayer(pid, "GetTeamForPlayer")._team
end
function api.IsPlayerBot(pid)
	checkPlayer(pid, "IsPlayerBot")
	return true
end
function api.IsTeamPlayer(pid)
	return checkPlayer(pid, "IsTeamPlayer")._team == Stub.bot._team
end
function api.GetSelectedHeroName(pid)
	return checkPlayer(pid, "GetSelectedHeroName")._name
end
function api.IsHeroAlive(pid)
	return checkPlayer(pid, "IsHeroAlive")._alive
end
function api.GetHeroLevel(pid)
	return checkPlayer(pid, "GetHeroLevel")._level
end
function api.GetHeroKills(pid)
	checkPlayer(pid, "GetHeroKills")
	return 0
end
function api.GetHeroDeaths(pid)
	checkPlayer(pid, "GetHeroDeaths")
	return 0
end
function api.GetHeroAssists(pid)
	checkPlayer(pid, "GetHeroAssists")
	return 0
end
function api.GetHeroLastSeenInfo(pid)
	local unit = checkPlayer(pid, "GetHeroLastSeenInfo")
	return { { location = unit._loc, time_since_seen = 0 } }
end
function api.GetUnitList(listType)
	local own, other = Stub.teams[Stub.bot._team], Stub.teams[opposing(Stub.bot._team)]
	local result = {}
	local function add(list)
		for i = 1, #list do
			result[#result + 1] = list[i]
		end
	end
	if listType == CONSTANTS.UNIT_LIST_ALLIED_HEROES or listType == CONSTANTS.UNIT_LIST_ALLIES then
		add(own)
	elseif listType == CONSTANTS.UNIT_LIST_ENEMY_HEROES or listType == CONSTANTS.UNIT_LIST_ENEMIES then
		add(other)
	elseif listType == CONSTANTS.UNIT_LIST_ALL then
		add(own)
		add(other)
	end
	return result
end
function api.GetUnitToUnitDistance(a, b)
	return (a._loc - b._loc):Length2D()
end
function api.GetUnitToUnitDistanceSqr(a, b)
	local d = a._loc - b._loc
	return d.x * d.x + d.y * d.y
end
function api.GetUnitToLocationDistance(unit, location)
	return (unit._loc - location):Length2D()
end
function api.GetUnitToLocationDistanceSqr(unit, location)
	local d = unit._loc - location
	return d.x * d.x + d.y * d.y
end
function api.PointToLineDistance(a, b, p)
	local ab, ap = b - a, p - a
	local len2 = ab.x * ab.x + ab.y * ab.y
	local t = len2 > 0 and (ap.x * ab.x + ap.y * ab.y) / len2 or 0
	local within = t >= 0 and t <= 1
	t = math.max(0, math.min(1, t))
	local closest = a + ab * t
	return { distance = (p - closest):Length2D(), closest_point = closest, within = within }
end
function api.Vector(x, y, z)
	return newVector(x, y, z)
end
function api.RandomInt(a, b)
	return math.random(a, b)
end
function api.RandomFloat(a, b)
	return a + (b - a) * math.random()
end
api.Script_RandomFloat = api.RandomFloat
function api.RandomVector(length)
	return newVector(length or 0, 0, 0)
end
function api.RollPercentage(p)
	return math.random(1, 100) <= p
end
function api.Clamp(v, lo, hi)
	return math.max(lo, math.min(hi, v))
end
function api.Max(a, b)
	return math.max(a, b)
end
function api.Min(a, b)
	return math.min(a, b)
end
function api.RemapValClamped(v, a, b, c, d)
	if a == b then
		return v >= b and d or c
	end
	local t = math.max(0, math.min(1, (v - a) / (b - a)))
	return c + (d - c) * t
end
function api.Script_RemapVal(v, a, b, c, d)
	if a == b then
		return v >= b and d or c
	end
	return c + (d - c) * (v - a) / (b - a)
end
function api.GetAncient(team)
	return Stub.ancients[team]
end
function api.GetTower(team, id)
	return Stub.towers[team][id]
end
function api.GetBarracks()
	return nil
end
function api.GetShrine()
	return nil
end
function api.GetShrineCooldown()
	return 0
end
function api.IsShrineHealing()
	return false
end
function api.GetOutpost()
	return nil
end
function api.GetShopLocation(team)
	return FOUNTAIN[team] or newVector(0, 0, 0)
end
function api.GetLocationAlongLane(lane, amount)
	local y = (lane == CONSTANTS.LANE_TOP and 1 or lane == CONSTANTS.LANE_BOT and -1 or 0) * 3000
	return newVector(-6000 + 12000 * (amount or 0), y, 0)
end
function api.GetLaneFrontLocation(_, lane)
	return api.GetLocationAlongLane(lane, 0.5)
end
function api.GetLaneFrontAmount()
	return 0.5
end
function api.GetAmountAlongLane()
	return { amount = 0.5, distance = 0 }
end
function api.GetRuneSpawnLocation()
	return newVector(0, 0, 0)
end
function api.GetRuneStatus()
	return 0
end
function api.GetRuneType()
	return 0
end
function api.GetRuneTimeSinceSeen()
	return 0
end
function api.GetRoshanKillTime()
	return 0
end
function api.GetGlyphCooldown()
	return 0
end
function api.GetItemCost()
	return 500
end
-- Recipes as the engine reports them: one set of parts per item, from the game file (Tests/data/item_recipes_742.lua).
local itemRecipes = nil
function api.GetItemComponents(itemName)
	if itemRecipes == nil then
		itemRecipes = assert(realLoadfile(Stub.root .. "/Tests/data/item_recipes_742.lua"))()
	end
	local recipe = itemRecipes[itemName]
	if recipe == nil or recipe.parts == nil then
		return {}
	end
	return { recipe.parts }
end
function api.GetItemStockCount()
	return 1
end
function api.IsItemPurchasedFromSecretShop()
	return false
end
function api.IsItemPurchasedFromSideShop()
	return false
end
function api.GetTimeOfDay()
	return 0.5
end
function api.GetWorldBounds()
	return { -8288, -8288, 8288, 8288 }
end
function api.IsLocationPassable()
	return true
end
function api.IsLocationVisible()
	return true
end
function api.IsRadiusVisible()
	return true
end
function api.GetHeightLevel()
	return 1
end
function api.GetTreeLocation()
	return newVector(0, 0, 0)
end
for _, name in ipairs({
	"GetAllTrees",
	"GetNeutralSpawners",
	"GetDroppedItemList",
	"GetLinearProjectiles",
	"GetIncomingTeleports",
	"GetAvoidanceZones",
}) do
	api[name] = emptyList
end
function api.GetNumCouriers()
	return 0
end
function api.GetCourier()
	return nil
end
function api.IsCourierAvailable()
	return false
end
function api.IsFlyingCourier()
	return false
end
function api.IsLanMode()
	return false
end
for _, name in ipairs({
	"GetPushLaneDesire",
	"GetDefendLaneDesire",
	"GetFarmLaneDesire",
	"GetRoamDesire",
	"GetRoshanDesire",
	"GetUnitPotentialValue",
	"AddAvoidanceZone",
}) do
	api[name] = function()
		return 0
	end
end
function api.GetRoamTarget()
	return nil
end
for _, name in ipairs({
	"DebugDrawCircle",
	"DebugDrawLine",
	"DebugDrawText",
	"DebugPause",
	"DebuggerBreak",
	"InstallCastCallback",
	"InstallChatCallback",
	"InstallCourierDeathCallback",
	"InstallDamageCallback",
	"InstallRoshanDeathCallback",
	"RemoveAvoidanceZone",
	"SelectHero",
}) do
	api[name] = function() end
end
local function capture(...)
	local parts = {}
	for i = 1, select("#", ...) do
		parts[#parts + 1] = tostring((select(i, ...)))
	end
	local line = table.concat(parts, "\t")
	Stub.printed[#Stub.printed + 1] = line
	if Stub.echo then
		io.write(line, "\n")
	end
end
api.print = capture
api.Msg = capture
api.Warning = capture

-- Real API globals with no stub above: reading one raises "stub missing: <name>". Names the scripts
-- define themselves (AttackUnits, ConsiderMove, GetAdjustedDesireValue, HandleIdleBotState, ...) are not
-- listed: before their definition they read as nil, as in game.
local UNSTUBBED_API = {}
for name in
	string.gmatch(
		"AddConditionalAvoidanceZone CMBanHero CMPickHero CreateHTTPRequest CreateRemoteHTTPRequest GeneratePath "
			.. "GetBotAbilityByHandle GetBotByHandle GetCMCaptain GetCMPhaseTimeRemaining GetCourierForPlayer "
			.. "GetCourierState GetLinearProjectileByHandle GetTowerAttackTarget IsCMBannedHero IsCMPickedHero "
			.. "IsInCMBanPhase IsInCMPickPhase IsPlayerInHeroSelectionControl QAngle RandomFloatWrapper SetCMCaptain "
			.. "printstack",
		"%S+"
	)
do
	UNSTUBBED_API[name] = true
end

-- Module loading -------------------------------------------------------------------------------------

-- "bots/FuncLib/x", "bots.FuncLib.x" or "bots/BotsLib/hero_x.lua" -> "<root>/FuncLib/x.lua".
local function modulePath(name)
	local rest = string.match(name, "^bots[/.\\](.+)$")
	if rest == nil then
		return nil
	end
	rest = string.gsub(rest, "%.lua$", "")
	rest = string.gsub(rest, "[.\\]", "/")
	return Stub.root .. "/" .. rest .. ".lua"
end
Stub.modulePath = modulePath

local function fileExists(path)
	local f = io.open(path, "r")
	if f then
		f:close()
		return true
	end
	return false
end
Stub.fileExists = fileExists

local function searcher(name)
	local path = modulePath(name)
	if path == nil then
		return "\n\tno bots/ module '" .. name .. "'"
	end
	if not fileExists(path) then
		return "\n\tno file '" .. path .. "'"
	end
	local chunk, err = realLoadfile(path)
	if chunk == nil then
		error(err, 0)
	end
	return chunk
end

-- The game's dofile takes the same paths as require (no ".lua"), and does not cache.
local function stubDofile(name)
	local path = modulePath(name) or name
	local chunk, err = realLoadfile(path)
	if chunk == nil then
		error(err, 2)
	end
	return chunk()
end

-- Install / reset ------------------------------------------------------------------------------------

local function shallowCopy(t)
	local copy = {}
	for k, v in pairs(t) do
		copy[k] = v
	end
	return copy
end
local function restore(t, saved)
	for k in pairs(t) do
		if saved[k] == nil then
			rawset(t, k, nil)
		end
	end
	for k, v in pairs(saved) do
		rawset(t, k, v)
	end
end

local baseline = nil

function Stub.install(root)
	if baseline ~= nil then
		return Stub
	end
	Stub.root = root or "."
	for name, f in pairs(api) do
		rawset(_G, name, f)
	end
	rawset(_G, "dofile", stubDofile)
	rawset(_G, "CDOTA_Bot_Script", UnitClass)
	rawset(_G, "CDOTABaseAbility_BotScript", AbilityClass)
	math.random = stubRandom
	math.randomseed = stubRandomseed
	table.insert(searchers, 2, searcher)
	-- Valve's own file, loaded by the override_generic modes; the bots only call into it at run time.
	package.preload["game/botsinit"] = function()
		return {
			CreateGeneric = function()
				return {}
			end,
		}
	end
	setmetatable(_G, {
		__index = function(_, key)
			if type(key) ~= "string" then
				return nil
			end
			local value = CONSTANTS[key]
			if value ~= nil then
				return value
			end
			if UNSTUBBED_API[key] then
				error("stub missing: " .. key, 2)
			end
			return apiConstant(key)
		end,
	})
	baseline = {
		globals = shallowCopy(_G),
		string = shallowCopy(string),
		table = shallowCopy(table),
		math = shallowCopy(math),
		unitClass = shallowCopy(UnitClass),
		abilityClass = shallowCopy(AbilityClass),
		loaded = shallowCopy(package.loaded),
	}
	return Stub
end

-- opts: hero (unit name of GetBot()), team (default TEAM_RADIANT), slot (bot's team slot, default 1),
-- time (DotaTime, default 0), allies / enemies (lists of unit names for the other slots).
function Stub.reset(opts)
	opts = opts or {}
	restore(_G, baseline.globals)
	restore(string, baseline.string)
	restore(table, baseline.table)
	restore(math, baseline.math)
	restore(UnitClass, baseline.unitClass)
	restore(AbilityClass, baseline.abilityClass)
	restore(package.loaded, baseline.loaded)
	randomState = 1
	Stub.printed = {}
	Stub.time = opts.time or 0
	local team = opts.team or RADIANT
	local slot = opts.slot or 1
	local names = {
		[team] = shallowCopy(opts.allies or DEFAULT_HEROES[team]),
		[opposing(team)] = shallowCopy(opts.enemies or DEFAULT_HEROES[opposing(team)]),
	}
	names[team][slot] = opts.hero or names[team][slot]
	Stub.teams, Stub.heroes, Stub.ancients, Stub.towers = {}, {}, {}, {}
	for _, t in ipairs({ RADIANT, DIRE }) do
		Stub.teams[t] = {}
		local sign = t == RADIANT and -1 or 1
		for i = 1, 5 do
			local unit = Stub.newUnit({
				name = names[t][i],
				team = t,
				pid = Stub.PLAYER_IDS[t][i],
				loc = newVector(sign * (5000 - i * 100), sign * (5000 - i * 50), 0),
				lane = (i == 2 and CONSTANTS.LANE_MID)
					or ((i == 1 or i == 5) == (t == RADIANT) and CONSTANTS.LANE_BOT)
					or CONSTANTS.LANE_TOP,
			})
			Stub.teams[t][i] = unit
			Stub.heroes[#Stub.heroes + 1] = unit
		end
		Stub.ancients[t] = Stub.newUnit({
			name = t == RADIANT and "npc_dota_goodguys_fort" or "npc_dota_badguys_fort",
			team = t,
			loc = newVector(sign * 5500, sign * 5000, 0),
			maxHp = 4500,
			hero = false,
		})
		Stub.towers[t] = {}
	end
	Stub.bot = Stub.teams[team][slot]
	return Stub.bot
end

-- Loads a bot script the way the game does (dofile with a "bots/..." path); returns ok, result.
function Stub.load(name)
	return xpcall(function()
		return stubDofile("bots/" .. name)
	end, function(err)
		return debug and debug.traceback and debug.traceback(tostring(err), 2) or tostring(err)
	end)
end

Stub.unpack = unpackArgs
return Stub
