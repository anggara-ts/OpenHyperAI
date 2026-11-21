-- Shared bot system: global overrides.

-- [OHA-*] diagnostics for behaviour already confirmed working in test games. Muted so the
-- console log shows what still needs work. Delete a line here to bring that log back.
local OHA_MUTED = {
	-- Only the 20s laning summary (standoff / last hits). lasthit-skip, harass-step, summons-step-back and
	-- go-home print again: the whole tag was muted, so game 037 could not show them working.
	"^%[OHA%-LANE%] t=%S+ %S+ pos=%d",
	"^%[OHA%-TUSK%] t=%S+ snowball%-launch", -- early launch (median 0.6s)
	"^%[OHA%-TUSK%] t=%S+ punch ", -- Tag Team before Punch
	"^%[OHA%-TUSK%] t=%S+ tag%-team ",
	"^%[OHA%-TUSK%] t=%S+ wave%-", -- Ice Shards / Snowball wave clear
	"^%[OHA%-TUSK%] t=%S+ escape%-snowball",
	"^%[OHA%-TECHIES%] t=%S+ combo ",
	"^%[OHA%-TECHIES%] t=%S+ tower ",
	"^%[OHA%-TECHIES%] t=%S+ tazer%-held",
	"^%[OHA%-ITEM%] t=%S+ %S+ grenade%-throw",
	-- grenade-moved unmuted: game 034, Abaddon's grenade ended in the backpack with a branch in the bag.
	"^%[OHA%-ITEM%] t=%S+ %S+ swap%-", -- engine ignores bot swaps; known
	"^%[OHA%-BUY%] t=%S+ %S+ recipe%-hold", -- courier waits, every 4s
	"^%[OHA%-FIGHT%] t=%S+ %S+ push %S+ lane=", -- post-kill push floor, every 4s
	"^%[OHA%-FIGHT%] t=%S+ %S+ rosh %S+ was=",
	"^%[OHA%-RETREAT%] t=%S+ %S+ summons",
	"^%[OHA%-MEDUSA%]",
	"^%[OHA%-WARLOCK%]",
	"^%[OHA%-QUILL%]",
	-- Proven in games 038/039 (PRs #4 and #5); muted 2026-11-18. Still printed: the triggers of the enemy-half
	-- withdraw, hard-retreat, group-up, flips/stuck (#12), swaps/pull-check/forage (#15), Puck (#36) and lasthit-skip.
	"^%[OHA%-EVASIVE%] t=%S+ %S+ enter", -- 193-212 per game, never without a cause
	"^%[OHA%-RETREAT%] t=%S+ %S+ over%-evasive",
	"^%[OHA%-PUSH%] t=%S+ %S+ behind%-stop", -- 152-211 per game
	"^%[OHA%-FARM%] t=%S+ %S+ base%-siege%-hold", -- 116-134 per game
	"^%[OHA%-FARM%] t=%S+ %S+ enemy%-half%-withdraw why=finish", -- the repeat while walking back
	"^%[OHA%-ATTACK%] t=%S+ %S+ follow%-skip",
	"^%[OHA%-MONKEY_KING%] t=%S+ spring%-skip", -- 127 per game
	"^%[OHA%-NS%] t=%S+ feast result",
	"^%[OHA%-MEEPO%] t=%S+ %S+ rune%-skip",
	"^%[OHA%-MEEPO%] t=%S+ %S+ farm%-skip",
	"^%[OHA%-LANE%] t=%S+ %S+ harass%-step",
	"^%[OHA%-SHREDDER%] t=%S+ retreat",
	"^%[OHA%-EMBER_SPIRIT%] t=%S+ retreat to remnant",
	"^%[OHA%-TUSK%] t=%S+ buddies%-retreat",
	-- Proven in game 040 (PR #20); muted 2026-11-18.
	"^%[OHA%-RETREAT%] t=%S+ %S+ healthy%-fight%-kept", -- 234 per game
	"^%[OHA%-FARM%] t=%S+ %S+ enemy%-camp%-uncovered", -- 622 per game
	-- Proven in game 043 (PR #57); muted 2026-11-18.
	"^%[OHA%-DEFEND%] t=%S+ %S+ chat%-skip why=already%-held", -- 1047 per game
}
if _G.OHA_RAW_PRINT == nil then
	_G.OHA_RAW_PRINT = print
	print = function(msg, ...)
		if type(msg) == "string" and string.sub(msg, 1, 5) == "[OHA-" then
			for i = 1, #OHA_MUTED do
				if string.find(msg, OHA_MUTED[i]) then
					return
				end
			end
		end
		return _G.OHA_RAW_PRINT(msg, ...)
	end
end
if package and package.path then
	local scriptDirectory = GetScriptDirectory()
	if not string.find(package.path, scriptDirectory, 1, true) then
		package.path = package.path .. ";" .. scriptDirectory .. "/?.lua"
		package.path = package.path .. ";" .. scriptDirectory .. "/?/init.lua"
	end
end
local Utils = require(GetScriptDirectory() .. "/FuncLib/systems/utils")
require(GetScriptDirectory() .. "/FuncLib/systems/log")
local hasGetInfo = type(debug) == "table" and type(debug.getinfo) == "function"
local hasTraceback = type(debug) == "table" and type(debug.traceback) == "function"
local function getStackTrace(level)
	level = level or 2
	if hasTraceback then
		return tostring(debug.traceback("", 1 + level))
	end
	if hasGetInfo then
		local frames = {}
		local firstLevel = 1 + level
		for i = firstLevel, firstLevel + 8 do
			local info = debug.getinfo(i, "Sl")
			if not info then
				break
			end
			frames[#frames + 1] =
				string.format("  %s:%d", tostring(info.short_src or info.source), info.currentline or -1)
		end
		if #frames == 0 then
			return "<no frames>"
		end
		return "\n" .. table.concat(frames, "\n")
	end
	local _, errorMessage = pcall(error, "@", 2 + level)
	return tostring(errorMessage or "<no trace>")
end
function ShouldSkipBotThink(bot)
	return bot:IsInvulnerable() or not bot:IsHero() or not bot:IsAlive() or bot:IsIllusion()
end
function HandleIdleBotState(bot)
	local ok, result = pcall(function()
		return _HandleIdleBotStateInner(bot)
	end)
	if ok then
		return result
	end
	return false
end
function _HandleIdleBotStateInner(bot)
	if not bot:IsHero() or not bot:IsAlive() or bot:IsIllusion() then
		return false
	end
	if bot._idleCheck == nil then
		bot._idleCheck = { lastTime = DotaTime(), lastPos = bot:GetLocation(), idleSince = 0 }
	end
	local idleCheck = bot._idleCheck
	local now = DotaTime()
	if now - idleCheck.lastTime < 1.0 then
		return false
	end
	idleCheck.lastTime = now
	local location = bot:GetLocation()
	if not location then
		return false
	end
	local movedDistance = GetUnitToLocationDistance(bot, idleCheck.lastPos)
	idleCheck.lastPos = location
	if movedDistance < 50 and bot:GetCurrentActionType() == BOT_ACTION_TYPE_IDLE then
		if idleCheck.idleSince == 0 then
			idleCheck.idleSince = now
		end
		local idleTime = now - idleCheck.idleSince
		if bot:IsInvulnerable() and bot:DistanceFromFountain() < 500 and idleTime > 3 then
			local lane = bot:GetAssignedLane() or LANE_MID
			local laneFront = GetLaneFrontLocation(GetTeam(), lane, 0)
			bot:Action_MoveToLocation(laneFront)
			idleCheck.idleSince = 0
			return true
		end
		if idleTime > 5 and not bot:IsInvulnerable() then
			local lane = bot:GetAssignedLane() or LANE_MID
			local laneFront = GetLaneFrontLocation(GetTeam(), lane, 0)
			bot:Action_MoveToLocation(laneFront)
			idleCheck.idleSince = 0
			local traceOk, trace = pcall(require, GetScriptDirectory() .. "/FuncLib/systems/match_trace")
			if traceOk and trace.Event then
				trace.Event(bot, "idle", string.format("nudged after standing idle for %.0fs", idleTime))
			end
			return true
		end
	else
		idleCheck.idleSince = 0
	end
	return false
end
if BOT_MODE_WATCHER == nil then
	BOT_MODE_WATCHER = 28
end
if BOT_MODE_WISDOM_SHRINE == nil then
	BOT_MODE_WISDOM_SHRINE = 29
end
if BOT_MODE_LOTUS_POOL == nil then
	BOT_MODE_LOTUS_POOL = 30
end
BOT_MODE_DESIRE_NONE = 0
BOT_MODE_DESIRE_VERYLOW = 0.05
BOT_MODE_DESIRE_LOW = 0.175
BOT_MODE_DESIRE_MODERATE = 0.35
BOT_MODE_DESIRE_HIGH = 0.525
BOT_MODE_DESIRE_VERYHIGH = 0.6
BOT_MODE_DESIRE_ABSOLUTE = 0.7
BOT_DESIRE_OVERRIDE = 1.0
function GetAdjustedDesireValue(desire)
	if desire < 1 then
		return RemapValClamped(desire, 0, 1, 0, BOT_MODE_DESIRE_ABSOLUTE)
	end
	return desire
end
_G.NIL_ABILITY = {}
setmetatable(_G.NIL_ABILITY, {
	__index = function(proxy, key)
		local falseMethods = {
			IsFullyCastable = true,
			IsTrained = true,
			IsHidden = true,
			IsActivated = true,
			IsStealable = true,
			IsInAbilityPhase = true,
			IsChanneling = true,
			IsUltimate = true,
		}
		if falseMethods[key] then
			return function()
				return false
			end
		end
		local zeroMethods = {
			GetLevel = true,
			GetCastRange = true,
			GetCastPoint = true,
			GetManaCost = true,
			GetCooldown = true,
			GetCooldownTimeRemaining = true,
			GetDuration = true,
			GetAbilityDamage = true,
			GetSpecialValueInt = true,
			GetSpecialValueFloat = true,
			GetCurrentCharges = true,
			GetToggleState = true,
			GetAutoCastState = true,
		}
		if zeroMethods[key] then
			return function()
				return 0
			end
		end
		return function()
			return nil
		end
	end,
})
function SafeAbility(ability, abilityName, heroName)
	if ability == nil then
		if abilityName then
			log(
				'[WARN] %s ability "%s" is nil (removed/renamed/innate?) — using safe proxy',
				heroName or "unknown",
				abilityName
			)
		end
		return _G.NIL_ABILITY
	end
	return ability
end
local originalGetTeamPlayers = GetTeamPlayers
local cachedDirePlayers = nil
function GetTeamPlayers(team, useOriginal)
	if useOriginal then
		return originalGetTeamPlayers(team)
	end
	local players = originalGetTeamPlayers(team)
	if team == TEAM_DIRE then
		if cachedDirePlayers ~= nil then
			return cachedDirePlayers
		end
		local humanPlayers = {}
		for _, playerId in pairs(players) do
			if not IsPlayerBot(playerId) then
				table.insert(humanPlayers, playerId)
			end
		end
		if #humanPlayers > 0 then
			local direSlots = { 5, 6, 7, 8, 9 }
			players = {}
			for i = 1, #direSlots do
				table.insert(players, direSlots[i])
			end
			for i = 1, #humanPlayers do
				for j = 1, 5 do
					if humanPlayers[i] + 5 == direSlots[j] then
						players[j] = humanPlayers[i]
					end
				end
			end
			for i = #players, 1, -1 do
				local offset = 0
				if players[i] > 4 then
					for j = 1, #players do
						if players[j + i] ~= nil and players[j + i] < 5 then
							offset = offset + 1
						end
					end
					players[i] = players[i] + offset
				end
			end
		end
		cachedDirePlayers = players
	end
	return players
end
IsDebug = Utils.DebugMode
local SafeCallPerf = nil
local function LoadSafeCallPerf()
	if SafeCallPerf ~= nil then
		return SafeCallPerf
	end
	SafeCallPerf = false
	local ok, MatchTrace = pcall(require, GetScriptDirectory() .. "/FuncLib/systems/match_trace")
	if ok and MatchTrace and MatchTrace.PerfEnabled and MatchTrace.PerfEnabled() and MatchTrace.PerfSample then
		SafeCallPerf = MatchTrace
	end
	return SafeCallPerf
end
-- A mode Think that runs during a cast point or a channel replaces it with its own order. Game 029,
-- 27:48: Techies' escape Blast Off (1s cast point) was cancelled while he was in a defend mode.
-- Every mode Think wrapped here (name ending in _Think) is skipped while the bot casts or
-- channels; farm, ward, Roshan and lotus Thinks call OhaCastGuard themselves.
function OhaCastGuard(bot)
	if bot == nil or not bot:IsAlive() then
		return false
	end
	-- A hero file's own hold (Puck's Phase Shift: the API shows neither the channel nor the modifier, #36).
	if bot._castHoldUntil ~= nil and DotaTime() < bot._castHoldUntil then
		return true
	end
	return bot:IsCastingAbility() or bot:IsChanneling()
end
function SafeCall(fn, fallback, name)
	local isThink = type(name) == "string" and string.sub(name, -6) == "_Think"
	return function(...)
		if isThink then
			local guardOk, guarded = pcall(function()
				return OhaCastGuard(GetBot())
			end)
			if guardOk and guarded then
				return fallback
			end
		end
		local perf = LoadSafeCallPerf()
		local startTime = nil
		if perf and RealTime then
			startTime = RealTime()
		end
		local ok, result1, result2, result3 = pcall(fn, ...)
		if startTime ~= nil and perf then
			perf.PerfSample(name or "SafeCall", RealTime() - startTime)
		end
		if ok then
			return result1, result2, result3
		end
		local heroPrefix = ""
		pcall(function()
			heroPrefix = GetBot():GetUnitName() .. " "
		end)
		log("[ERROR] %s%s: %s", heroPrefix, name or "unknown", tostring(result1))
		-- log() is silent unless debug is on, so these errors were never seen. Print the first 3
		-- per wrapped function as [OHA-ERROR].
		_G.OHA_SAFECALL_ERRS = _G.OHA_SAFECALL_ERRS or {}
		local key = name or "unknown"
		local errorCount = (_G.OHA_SAFECALL_ERRS[key] or 0) + 1
		_G.OHA_SAFECALL_ERRS[key] = errorCount
		if errorCount <= 3 then
			pcall(print, string.format("[OHA-ERROR] t=%.1f %s%s: %s", DotaTime(), heroPrefix, key, tostring(result1)))
		end
		-- First error only: run it once more under xpcall to print the stack trace (the line
		-- above names only the innermost line, e.g. utils.lua:525). Kept off the hot path.
		if errorCount == 1 and debug ~= nil and debug.traceback ~= nil then
			local args = { ... }
			local argCount = select("#", ...)
			local unpackFn = unpack or table.unpack
			local retryOk, retryError = xpcall(function()
				return fn(unpackFn(args, 1, argCount))
			end, function(err)
				local tracebackOk, traceText = pcall(debug.traceback, tostring(err), 2)
				return tracebackOk and traceText or tostring(err)
			end)
			if not retryOk then
				pcall(print, "[OHA-ERROR] trace " .. key .. ": " .. (string.gsub(tostring(retryError), "\n", " | ")))
			end
		end
		return fallback
	end
end
local cachedIsLanMode = nil
function IsLanMode()
	if cachedIsLanMode ~= nil then
		return cachedIsLanMode
	end
	local ok, lanValue = pcall(function()
		return Convars:GetInt("sv_lan")
	end)
	if ok and lanValue ~= nil then
		cachedIsLanMode = lanValue == 1
	else
		cachedIsLanMode = false
	end
	return cachedIsLanMode
end
local originalGetUnitToUnitDistance = GetUnitToUnitDistance
function GetUnitToUnitDistance(unit, target)
	if not unit then
		return 1000
	end
	if target == nil or pcall(function()
		return target:GetLocation()
	end) == false then
		return 1000
	end
	return originalGetUnitToUnitDistance(unit, target)
end
local originalGetUnitToLocationDistance = GetUnitToLocationDistance
function GetUnitToLocationDistance(unit, location)
	if unit == nil then
		log("[OVERRIDE] GetUnitToLocationDistance nil unit\n%s", getStackTrace(2))
		return 1000
	end
	if location == nil or type(location) ~= "userdata" then
		log(
			"[OVERRIDE] GetUnitToLocationDistance bad location (type=%s) for %s\n%s",
			type(location),
			tostring(unit and unit.GetUnitName and unit:GetUnitName()),
			getStackTrace(2)
		)
		return 1000
	end
	return originalGetUnitToLocationDistance(unit, location)
end
local originalWasRecentlyDamagedByAnyHero = CDOTA_Bot_Script.WasRecentlyDamagedByAnyHero
function CDOTA_Bot_Script:WasRecentlyDamagedByAnyHero(interval)
	if not self:IsHero() then
		return nil
	end
	return originalWasRecentlyDamagedByAnyHero(self, interval)
end
local originalGetNearbyTowers = CDOTA_Bot_Script.GetNearbyTowers
function CDOTA_Bot_Script:GetNearbyTowers(radius, isEnemy)
	if not self:IsHero() then
		return nil
	end
	return originalGetNearbyTowers(self, math.min(radius, 1600), isEnemy)
end
local originalIsIllusion = CDOTA_Bot_Script.IsIllusion
function CDOTA_Bot_Script:IsIllusion()
	if not self:IsHero() then
		return nil
	end
	if not self:CanBeSeen() then
		return nil
	end
	-- The engine only answers for teammates and logs a warning on every other call.
	if self:GetTeam() ~= GetTeam() then
		return self:HasModifier("modifier_illusion")
	end
	return originalIsIllusion(self)
end
local originalHasModifier = CDOTA_Bot_Script.HasModifier
function CDOTA_Bot_Script:HasModifier(modifierName)
	if not self:CanBeSeen() then
		return false
	end
	return originalHasModifier(self, modifierName)
end
-- Lotus pools report CanBeSeen() while fogged, then NumModifiers logs a warning.
local lotusPoolNumModifiers = CDOTA_Bot_Script.NumModifiers
function CDOTA_Bot_Script:NumModifiers()
	if self ~= nil and self.GetUnitName ~= nil and self:GetUnitName() == "npc_dota_lotus_pool" then
		return 0
	end
	return lotusPoolNumModifiers(self)
end
local originalGetLocation = CDOTA_Bot_Script.GetLocation
function CDOTA_Bot_Script:GetLocation()
	if self == nil or not self:IsBuilding() and not self:CanBeSeen() then
		return nil
	end
	return originalGetLocation(self)
end
local originalGetMagicResist = CDOTA_Bot_Script.GetMagicResist
function CDOTA_Bot_Script:GetMagicResist()
	if self == nil or not self:CanBeSeen() then
		return 1
	end
	return originalGetMagicResist(self)
end
local originalIsInvulnerable = CDOTA_Bot_Script.IsInvulnerable
function CDOTA_Bot_Script:IsInvulnerable()
	if not self:CanBeSeen() then
		return false
	end
	if self:HasModifier("modifier_dazzle_nothl_projection_soul_debuff") then
		return false
	end
	return originalIsInvulnerable(self)
end
local originalIsAttackImmune = CDOTA_Bot_Script.IsAttackImmune
function CDOTA_Bot_Script:IsAttackImmune()
	if not self:CanBeSeen() then
		return false
	end
	return originalIsAttackImmune(self)
end
local originalIsUsingAbility = CDOTA_Bot_Script.IsUsingAbility
function CDOTA_Bot_Script:IsUsingAbility()
	if not self:CanBeSeen() or not self:IsHero() then
		return false
	end
	return originalIsUsingAbility(self)
end
local originalIsChanneling = CDOTA_Bot_Script.IsChanneling
function CDOTA_Bot_Script:IsChanneling()
	if not self:CanBeSeen() then
		return false
	end
	return originalIsChanneling(self)
end
local originalGetAttackTarget = CDOTA_Bot_Script.GetAttackTarget
function CDOTA_Bot_Script:GetAttackTarget()
	if not self:CanBeSeen() then
		return nil
	end
	return originalGetAttackTarget(self)
end
local originalGetNearbyHeroes = CDOTA_Bot_Script.GetNearbyHeroes
function CDOTA_Bot_Script:GetNearbyHeroes(radius, isEnemy, botMode)
	if not self:CanBeSeen() then
		return nil
	end
	return originalGetNearbyHeroes(self, math.min(radius, 1600), isEnemy, botMode)
end
local originalIsMagicImmune = CDOTA_Bot_Script.IsMagicImmune
function CDOTA_Bot_Script:IsMagicImmune()
	if not self then
		return false
	end
	if self:CanBeSeen() then
		if
			originalIsMagicImmune(self)
			or self:HasModifier("modifier_magic_immune")
			or self:HasModifier("modifier_juggernaut_blade_fury")
			or self:HasModifier("modifier_life_stealer_rage")
			or self:HasModifier("modifier_black_king_bar_immune")
			or self:HasModifier("modifier_huskar_life_break_charge")
			or self:HasModifier("modifier_grimstroke_scepter_buff")
			or self:HasModifier("modifier_pangolier_rollup")
			or self:HasModifier("modifier_lion_mana_drain_immunity")
			or self:HasModifier("modifier_dawnbreaker_fire_wreath_magic_immunity_tooltip")
			or self:HasModifier("modifier_rattletrap_cog_immune")
			or self:HasModifier("modifier_legion_commander_press_the_attack_immunity")
		then
			return true
		end
	end
	return false
end
local originalRandomFloat = RandomFloat
local epsilon = 0.00000001
function RandomFloat(min, max)
	return min + math.random() * (max - min + epsilon)
end
local originalGetNearbyNeutralCreeps = CDOTA_Bot_Script.GetNearbyNeutralCreeps
function CDOTA_Bot_Script:GetNearbyNeutralCreeps(radius)
	return originalGetNearbyNeutralCreeps(self, math.min(radius, 1600))
end
local originalGetNearbyLaneCreeps = CDOTA_Bot_Script.GetNearbyLaneCreeps
function CDOTA_Bot_Script:GetNearbyLaneCreeps(radius, isEnemy)
	return originalGetNearbyLaneCreeps(self, math.min(radius, 1600), isEnemy)
end
local originalGetNearbyCreeps = CDOTA_Bot_Script.GetNearbyCreeps
function CDOTA_Bot_Script:GetNearbyCreeps(radius, isEnemy)
	return originalGetNearbyCreeps(self, math.min(radius, 1600), isEnemy)
end
local originalGetUnitName = CDOTA_Bot_Script.GetUnitName
function CDOTA_Bot_Script:GetUnitName()
	local unitName = originalGetUnitName(self)
	if string.find(unitName, "lone_druid_bear") then
		unitName = "npc_dota_hero_lone_druid_bear"
	end
	return unitName
end
local originalGetCastRange = CDOTABaseAbility_BotScript.GetCastRange
function CDOTABaseAbility_BotScript:GetCastRange()
	local bot = GetBot()
	if self then
		local castRange = self:GetSpecialValueInt("AbilityCastRange")
		if castRange == 0 then
			castRange = originalGetCastRange(self)
		end
		if bot then
			for i = 0, 7 do
				local ability = bot:GetAbilityInSlot(i)
				if ability and ability:IsTrained() then
					local abilityName = ability:GetName()
					if abilityName == "keeper_of_the_light_spirit_form" then
						if bot:HasModifier("modifier_keeper_of_the_light_spirit_form") then
							castRange = castRange + ability:GetSpecialValueInt("cast_range")
						end
					elseif abilityName == "rubick_arcane_supremacy" then
						castRange = castRange + ability:GetSpecialValueInt("cast_range")
					end
				end
			end
			local itemSlots = { 0, 1, 2, 3, 4, 5, 16, 17 }
			for i = 1, #itemSlots do
				local item = bot:GetItemInSlot(itemSlots[i])
				if item then
					local itemName = item:GetName()
					if itemName == "item_aether_lens" then
						castRange = castRange + item:GetSpecialValueInt("cast_range_bonus")
					elseif itemName == "item_ethereal_blade" then
						castRange = castRange + item:GetSpecialValueInt("bonus_cast_range")
					elseif itemName == "item_magnifying_monocle" then
						castRange = castRange + item:GetSpecialValueInt("bonus_cast_range")
					elseif itemName == "item_enhancement_keen_eyed" then
						castRange = castRange + item:GetSpecialValueInt("cast_range_bonus")
					elseif itemName == "item_enhancement_mystical" then
						castRange = castRange + item:GetSpecialValueInt("bonus_cast_range")
					elseif itemName == "item_enhancement_boundless" then
						castRange = castRange + item:GetSpecialValueInt("bonus_cast_range")
					elseif string.find(itemName, "item_dagon") then
						local hasAetherLens = false
						for slot = 0, 5 do
							local otherItem = bot:GetItemInSlot(slot)
							if
								otherItem
								and otherItem ~= item
								and string.find(otherItem:GetName(), "item_aether_lens")
							then
								hasAetherLens = true
								break
							end
						end
						if not hasAetherLens then
							castRange = castRange + item:GetSpecialValueInt("cast_range_bonus")
						end
					end
				end
			end
		end
		return castRange
	end
	return originalGetCastRange(self)
end
local originalGetAbilityByName = CDOTA_Bot_Script.GetAbilityByName
function CDOTA_Bot_Script:GetAbilityByName(abilityName)
	if abilityName == nil or abilityName == "" then
		return nil
	end
	return originalGetAbilityByName(self, abilityName)
end
local originalFindAbilityByName = FindAbilityByName
if originalFindAbilityByName then
	function FindAbilityByName(abilityName)
		if abilityName == nil or abilityName == "" then
			return nil
		end
		return originalFindAbilityByName(abilityName)
	end
end
-- Map and system abilities every hero carries hidden: outpost capture (ability_capture),
-- lamps, Twin Gates (twin_gate_portal_warp), Underlord portals, plus/seasonal. They are
-- meant to be cast while hidden; refusing them left heroes standing at an outpost forever.
local function IsHiddenByDesign(ability)
	local ok, name = pcall(function()
		return ability:GetName()
	end)
	if not ok or type(name) ~= "string" then
		return false
	end
	return string.sub(name, 1, 8) == "ability_"
		or string.find(name, "_portal_warp", 1, true) ~= nil
		or string.sub(name, 1, 5) == "plus_"
		or string.sub(name, 1, 9) == "seasonal_"
end
-- Filled in below, once CastRefused exists.
local CastRefusedEarly = function() end
local originalActionUseAbility = CDOTA_Bot_Script.Action_UseAbility
function CDOTA_Bot_Script:Action_UseAbility(ability)
	if ability == nil or ability:IsHidden() and not IsHiddenByDesign(ability) then
		CastRefusedEarly(self, ability, "Action_UseAbility")
		return nil
	end
	return originalActionUseAbility(self, ability)
end
local originalActionPushUseAbility = CDOTA_Bot_Script.ActionPush_UseAbility
function CDOTA_Bot_Script:ActionPush_UseAbility(ability)
	if ability == nil or ability:IsHidden() and not IsHiddenByDesign(ability) then
		CastRefusedEarly(self, ability, "ActionPush_UseAbility")
		return nil
	end
	return originalActionPushUseAbility(self, ability)
end
-- Every targeted or queued cast refuses a hidden ability or a missing/wrong target before it
-- reaches the server. A hidden ability (Minefield Sign without Scepter) still reports
-- IsFullyCastable, so a hero kept ordering it every think and stood still.
local castRefusedAt = {}
local function CastRefused(self, ability, method, why)
	local name = "nil"
	if ability ~= nil then
		local ok, rawName = pcall(function()
			return ability:GetName()
		end)
		name = ok and tostring(rawName) or "?"
	end
	local hero = (string.gsub(tostring(self:GetUnitName()), "npc_dota_hero_", ""))
	local key = hero .. "|" .. name .. "|" .. why
	if DotaTime() < (castRefusedAt[key] or -999) then
		return
	end
	castRefusedAt[key] = DotaTime() + 30
	pcall(print, string.format("[OHA-CAST] t=%.0f %s %s %s refused=%s", DotaTime(), hero, method, name, why))
end
CastRefusedEarly = function(self, ability, method)
	CastRefused(self, ability, method, ability == nil and "nil-ability" or "hidden")
end
local function IsVector(value)
	if value == nil then
		return false
	end
	local ok, x = pcall(function()
		return value.x
	end)
	return ok and type(x) == "number"
end
local function GuardCast(method, targetKind)
	local original = CDOTA_Bot_Script[method]
	if original == nil then
		return
	end
	CDOTA_Bot_Script[method] = function(self, ability, target, ...)
		if ability == nil then
			CastRefused(self, ability, method, "nil-ability")
			return nil
		end
		local okHidden, hidden = pcall(function()
			return ability:IsHidden()
		end)
		if okHidden and hidden and not IsHiddenByDesign(ability) then
			CastRefused(self, ability, method, "hidden")
			return nil
		end
		if targetKind == "location" and not IsVector(target) then
			CastRefused(self, ability, method, target == nil and "nil-location" or "not-a-location")
			return nil
		end
		if targetKind == "entity" and (target == nil or IsVector(target)) then
			CastRefused(self, ability, method, target == nil and "nil-target" or "location-as-target")
			return nil
		end
		if targetKind == "tree" and target == nil then
			CastRefused(self, ability, method, "nil-tree")
			return nil
		end
		-- A no-target cast takes only the ability. Do not hand the engine an extra nil.
		if targetKind == "none" then
			return original(self, ability)
		end
		return original(self, ability, target, ...)
	end
end
for _, spec in ipairs({
	{ "Action_UseAbilityOnLocation", "location" },
	{ "ActionQueue_UseAbilityOnLocation", "location" },
	{ "ActionPush_UseAbilityOnLocation", "location" },
	{ "Action_UseAbilityOnEntity", "entity" },
	{ "ActionQueue_UseAbilityOnEntity", "entity" },
	{ "ActionPush_UseAbilityOnEntity", "entity" },
	{ "Action_UseAbilityOnTree", "tree" },
	{ "ActionQueue_UseAbilityOnTree", "tree" },
	{ "ActionPush_UseAbilityOnTree", "tree" },
	{ "ActionQueue_UseAbility", "none" },
}) do
	GuardCast(spec[1], spec[2])
end
local originalActionAttackUnit = CDOTA_Bot_Script.Action_AttackUnit
function CDOTA_Bot_Script:Action_AttackUnit(target, isOnce)
	if target == nil then
		log(
			"[OVERRIDE] Action_AttackUnit nil target for %s\n%s",
			tostring(self and self:GetUnitName()),
			getStackTrace(2)
		)
		return
	end
	return originalActionAttackUnit(self, target, isOnce)
end
local originalGetAssignedLane = CDOTA_Bot_Script.GetAssignedLane
function CDOTA_Bot_Script:GetAssignedLane()
	if not self or self:GetTeam() ~= GetTeam() then
		log(
			"[OVERRIDE] GetAssignedLane on non-teammate: unit=%s unitTeam=%s runningTeam=%s\n%s",
			tostring(self and self:GetUnitName()),
			tostring(self and self:GetTeam()),
			tostring(GetTeam()),
			getStackTrace(2)
		)
		return LANE_NONE
	end
	return originalGetAssignedLane(self)
end
local originalGetTarget = CDOTA_Bot_Script.GetTarget
function CDOTA_Bot_Script:GetTarget()
	if not self or not self:IsBot() then
		return nil
	end
	return originalGetTarget(self)
end
local originalGetAttackRange = CDOTA_Bot_Script.GetAttackRange
function CDOTA_Bot_Script:GetAttackRange()
	if not self:CanBeSeen() then
		return 200
	end
	return originalGetAttackRange(self)
end
local originalSwapItems = CDOTA_Bot_Script.ActionImmediate_SwapItems
-- Gap between two swaps of the same pair of items: the game puts an item moved out of the
-- backpack on a 6s cooldown, plus 5s, so two routines that want opposite slots for the same
-- items cannot ping-pong them and keep both on cooldown.
local swapPairGap = 6 + 5
-- Backpack items allowed into the main inventory during a fight (names without "item_").
local SWAP_IN_DURING_FIGHT = {
	dust = true,
	cheese = true,
	famango = true,
	great_famango = true,
	greater_famango = true,
	roshans_banner = true,
	refresher_shard = true,
	blood_grenade = true,
	foragers_health = true,
	foragers_stats = true,
	foragers_mana = true,
	gem = true,
}
local function SwapMovesBranchToBackpack(self, fromSlot, toSlot)
	if toSlot < 6 or toSlot > 8 then
		return false
	end
	local item = self:GetItemInSlot(fromSlot)
	if item == nil or item:GetName() ~= "item_branches" then
		return false
	end
	local other = self:GetItemInSlot(toSlot)
	-- The grenade is only throwable from the main inventory. A branch can sit in the backpack for it.
	if other ~= nil and other:GetName() == "item_blood_grenade" then
		return false
	end
	return true
end
local function SlotName(unit, slot)
	local item = unit:GetItemInSlot(slot)
	return item ~= nil and (string.gsub(item:GetName(), "^item_", "")) or "-"
end
-- [OHA-ITEM]: every swap that touches the blood grenade, and why a blocked one was refused.
-- Swaps logged: the grenade, and (game 031: the banner never left the backpack in 24 tries, with
-- nothing in the log) the banner, Dust and Forager mushrooms.
local SWAP_WATCH = {
	blood_grenade = true,
	roshans_banner = true,
	dust = true,
	foragers_health = true,
	foragers_stats = true,
	foragers_mana = true,
	cheese = true,
	famango = true,
	great_famango = true,
	greater_famango = true,
	refresher_shard = true,
	gem = true,
}
local function LogGrenadeSwap(self, slotA, slotB, result)
	local nameA, nameB = SlotName(self, slotA), SlotName(self, slotB)
	if not SWAP_WATCH[nameA] and not SWAP_WATCH[nameB] then
		return
	end
	if result ~= "ok" then
		local key = result .. slotA .. ":" .. slotB
		if self._grenadeSwapLogKey == key and DotaTime() < (self._grenadeSwapLogAt or -999) then
			return
		end
		self._grenadeSwapLogKey = key
		self._grenadeSwapLogAt = DotaTime() + 5
	end
	pcall(
		print,
		string.format(
			"[OHA-ITEM] t=%.0f %s swap %d(%s)<->%d(%s) %s",
			DotaTime(),
			(string.gsub(self:GetUnitName(), "npc_dota_hero_", "")),
			slotA,
			nameA,
			slotB,
			nameB,
			result
		)
	)
end
-- Checks the last swap half a second later: did the two items actually trade places?
-- Logged for every swap that touched the grenade, and for the first 6 other swaps per bot,
-- to show whether backpack swaps work at all. Call once per think.
function VerifyLastSwap(self)
	local check = self._swapCheck
	if check == nil or DotaTime() < check.at + 0.5 then
		return
	end
	self._swapCheck = nil
	if check.nameA == "-" and check.nameB == "-" then
		return
	end
	local done = SlotName(self, check.a) == check.nameB and SlotName(self, check.b) == check.nameA
	local grenade = check.nameA == "blood_grenade" or check.nameB == "blood_grenade"
	if not done and grenade and not check.reversed then
		self._swapTryReverse = true
	end
	self._swapChecksLogged = self._swapChecksLogged or 0
	if not grenade then
		if self._swapChecksLogged >= 6 then
			return
		end
		self._swapChecksLogged = self._swapChecksLogged + 1
	end
	pcall(
		print,
		string.format(
			"[OHA-ITEM] t=%.0f %s %s %d(%s)<->%d(%s)%s now=%s,%s",
			DotaTime(),
			(string.gsub(self:GetUnitName(), "npc_dota_hero_", "")),
			done and "swap-done" or "swap-noop",
			check.a,
			check.nameA,
			check.b,
			check.nameB,
			check.reversed and " reversed" or "",
			SlotName(self, check.a),
			SlotName(self, check.b)
		)
	)
end
function CDOTA_Bot_Script:ActionImmediate_SwapItems(slotA, slotB)
	local forced = self._swapDespiteEnemies
	self._swapDespiteEnemies = nil
	-- A swap that must not wait for the 11s gap (the banner at the enemy base).
	local urgent = self._swapDespiteCooldown
	self._swapDespiteCooldown = nil
	-- A branch parked for any other item gets pulled straight back, and that round trip
	-- leaves it on cooldown. The grenade is the exception: it has to stay throwable.
	if SwapMovesBranchToBackpack(self, slotA, slotB) or SwapMovesBranchToBackpack(self, slotB, slotA) then
		LogGrenadeSwap(self, slotA, slotB, "blocked-branch-rule")
		return nil
	end
	-- The gap is per pair of items. It used to be one timer for every swap, so a routine that kept
	-- retrying one pair held up all the others (game 033: a Clarity/Dust swap that never took
	-- effect restarted it every 6-13s for 26 minutes). A pair that has not swapped yet starts in
	-- the past, so the pregame swap of a grenade bought into a full bag goes through at once.
	local nameA, nameB = SlotName(self, slotA), SlotName(self, slotB)
	local pairKey = nameA < nameB and (nameA .. "|" .. nameB) or (nameB .. "|" .. nameA)
	self._swapPairTime = self._swapPairTime or {}
	-- Hold swaps only during a fight. An item that comes out of the backpack cannot be used for 6s
	-- and the one sent in cannot be used at all, so a fight is the wrong moment to reshuffle. Any
	-- enemy hero within 1000 used to block every swap, which meant almost none in the laning stage
	-- (game 032: 67 logged swaps refused for enemies).
	local enemies = #(self:GetNearbyHeroes(700, true, BOT_MODE_NONE) or {})
	local mode = self:GetActiveMode()
	local fighting = self:WasRecentlyDamagedByAnyHero(3.0)
		or enemies > 0
			and (mode == BOT_MODE_ATTACK or mode == BOT_MODE_RETREAT or mode == BOT_MODE_TEAM_ROAM or mode == BOT_MODE_DEFEND_ALLY)
	-- Items that are worth bringing in mid-fight: used once and soon, and never moved back out
	-- (they are all in sCanNotSwitchItems, so no other routine picks them to make room).
	local incoming = (slotA >= 6 and slotA <= 8 and slotB <= 5) and nameA
		or ((slotB >= 6 and slotB <= 8 and slotA <= 5) and nameB or nil)
	local fightOk = fighting and incoming ~= nil and SWAP_IN_DURING_FIGHT[incoming] == true
	local cooldown = swapPairGap - (DotaTime() - (self._swapPairTime[pairKey] or -1000))
	if (forced or not fighting or fightOk) and (cooldown < 0 or urgent) then
		self._swapPairTime[pairKey] = DotaTime()
		-- After a swap the engine ignored, try the slots the other way round once.
		local reversed = self._swapTryReverse == true
		self._swapTryReverse = nil
		LogGrenadeSwap(
			self,
			slotA,
			slotB,
			(forced and "ok-forced" or (fighting and "ok-fight" or "ok")) .. (reversed and "-reversed" or "")
		)
		self._swapCheck = { a = slotA, b = slotB, nameA = nameA, nameB = nameB, at = DotaTime(), reversed = reversed }
		if reversed then
			return originalSwapItems(self, slotB, slotA)
		end
		return originalSwapItems(self, slotA, slotB)
	end
	if cooldown >= 0 then
		LogGrenadeSwap(self, slotA, slotB, string.format("blocked-cooldown(%.0fs)", cooldown))
	else
		LogGrenadeSwap(self, slotA, slotB, string.format("blocked-fight(enemies=%d)", enemies))
	end
	return nil
end
local originalMethodGetUnitToLocationDistance = CDOTA_Bot_Script.GetUnitToLocationDistance
function CDOTA_Bot_Script:GetUnitToLocationDistance(unit, location)
	if location == nil then
		log("[WARN] GetUnitToLocationDistance nil location for %s", self:GetUnitName())
		return 200
	end
	return originalMethodGetUnitToLocationDistance(self, unit, location)
end
local originalGetHealth = CDOTA_Bot_Script.GetHealth
function CDOTA_Bot_Script:GetHealth()
	if self == nil or not self:CanBeSeen() then
		return 666
	end
	local health = originalGetHealth(self)
	if self ~= nil and self:GetUnitName() == "npc_dota_hero_medusa" and health > 0 then
		local mana = self:GetMana()
		local absorbRatio = 0.95
		if self:GetLevel() < 12 then
			absorbRatio = 0.5
		end
		local damagePerMana = 2.6
		local bonusHealth = mana * damagePerMana * absorbRatio
		return health + bonusHealth
	end
	return health
end
local originalGetMaxHealth = CDOTA_Bot_Script.GetMaxHealth
function CDOTA_Bot_Script:GetMaxHealth()
	if self ~= nil and self:GetUnitName() == "npc_dota_hero_medusa" then
		local absorbRatio = 0.95
		if self:GetLevel() < 12 then
			absorbRatio = 0.5
		end
		local damagePerMana = 2.6
		local bonusMaxHealth = self:GetMaxMana() * damagePerMana * absorbRatio
		return originalGetMaxHealth(self) + bonusMaxHealth
	end
	return originalGetMaxHealth(self)
end
function CDOTA_Bot_Script:OriginalGetHealth()
	return originalGetHealth(self)
end
function CDOTA_Bot_Script:OriginalGetMaxHealth()
	return originalGetMaxHealth(self)
end
local originalGetMana = CDOTA_Bot_Script.GetMana
function CDOTA_Bot_Script:GetMana()
	if self ~= nil and self:GetUnitName() == "npc_dota_hero_huskar" then
		return 0
	end
	return originalGetMana(self)
end
local originalGetMaxMana = CDOTA_Bot_Script.GetMaxMana
function CDOTA_Bot_Script:GetMaxMana()
	if self ~= nil and self:GetUnitName() == "npc_dota_hero_huskar" then
		return 0
	end
	return originalGetMaxMana(self)
end
-- A team says the same chat text at most once per 30s (FuncLib/systems/chat_guard.lua, issue #56).
local ChatGuard = require(GetScriptDirectory() .. "/FuncLib/systems/chat_guard")
if ChatGuard.originalChat == nil and CDOTA_Bot_Script.ActionImmediate_Chat ~= nil then
	ChatGuard.originalChat = CDOTA_Bot_Script.ActionImmediate_Chat
	ChatGuard.said = {}
	function CDOTA_Bot_Script:ActionImmediate_Chat(text, allChat)
		local key = tostring(self:GetTeam()) .. (allChat and "a:" or "t:") .. tostring(text)
		local allowed, since = ChatGuard.Allow(ChatGuard.said, key, DotaTime())
		if not allowed then
			if DotaTime() >= (self._chatDropLogAt or -999) then
				self._chatDropLogAt = DotaTime() + 5
				pcall(
					print,
					string.format(
						"[OHA-CHAT] t=%.0f %s drop-repeat since=%.0f text=%s",
						DotaTime(),
						(string.gsub(self:GetUnitName(), "npc_dota_hero_", "")),
						since or -1,
						tostring(text)
					)
				)
			end
			return
		end
		return ChatGuard.originalChat(self, text, allChat)
	end
end
local GlobalOverrides = { orig_GetTeamPlayers = originalGetTeamPlayers, GetTeamPlayers = GetTeamPlayers }
return GlobalOverrides
