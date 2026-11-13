-- Shared bot system: global overrides.
if package and package.path then
	local a = GetScriptDirectory()
	if not string.find(package.path, a, 1, true) then
		package.path = package.path .. ";" .. a .. "/?.lua"
		package.path = package.path .. ";" .. a .. "/?/init.lua"
	end
end
local b = require(GetScriptDirectory() .. "/FuncLib/systems/utils")
require(GetScriptDirectory() .. "/FuncLib/systems/log")
local c = type(debug) == "table" and type(debug.getinfo) == "function"
local d = type(debug) == "table" and type(debug.traceback) == "function"
local function e(f)
	f = f or 2
	if d then
		return tostring(debug.traceback("", 1 + f))
	end
	if c then
		local g = {}
		local h = 1 + f
		for i = h, h + 8 do
			local j = debug.getinfo(i, "Sl")
			if not j then
				break
			end
			g[#g + 1] = string.format("  %s:%d", tostring(j.short_src or j.source), j.currentline or -1)
		end
		if #g == 0 then
			return "<no frames>"
		end
		return "\n" .. table.concat(g, "\n")
	end
	local k, l = pcall(error, "@", 2 + f)
	return tostring(l or "<no trace>")
end
function ShouldSkipBotThink(m)
	return m:IsInvulnerable() or not m:IsHero() or not m:IsAlive() or m:IsIllusion()
end
function HandleIdleBotState(m)
	local n, o = pcall(function()
		return _HandleIdleBotStateInner(m)
	end)
	if n then
		return o
	end
	return false
end
function _HandleIdleBotStateInner(m)
	if not m:IsHero() or not m:IsAlive() or m:IsIllusion() then
		return false
	end
	if m._idleCheck == nil then
		m._idleCheck = { lastTime = DotaTime(), lastPos = m:GetLocation(), idleSince = 0 }
	end
	local p = m._idleCheck
	local q = DotaTime()
	if q - p.lastTime < 1.0 then
		return false
	end
	p.lastTime = q
	local r = m:GetLocation()
	if not r then
		return false
	end
	local s = GetUnitToLocationDistance(m, p.lastPos)
	p.lastPos = r
	if s < 50 and m:GetCurrentActionType() == BOT_ACTION_TYPE_IDLE then
		if p.idleSince == 0 then
			p.idleSince = q
		end
		local t = q - p.idleSince
		if m:IsInvulnerable() and m:DistanceFromFountain() < 500 and t > 3 then
			local u = m:GetAssignedLane() or LANE_MID
			local v = GetLaneFrontLocation(GetTeam(), u, 0)
			m:Action_MoveToLocation(v)
			p.idleSince = 0
			return true
		end
		if t > 5 and not m:IsInvulnerable() then
			local u = m:GetAssignedLane() or LANE_MID
			local v = GetLaneFrontLocation(GetTeam(), u, 0)
			m:Action_MoveToLocation(v)
			p.idleSince = 0
			local traceOk, trace = pcall(require, GetScriptDirectory() .. "/FuncLib/systems/match_trace")
			if traceOk and trace.Event then
				trace.Event(m, "idle", string.format("nudged after standing idle for %.0fs", t))
			end
			return true
		end
	else
		p.idleSince = 0
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
function GetAdjustedDesireValue(w)
	if w < 1 then
		return RemapValClamped(w, 0, 1, 0, BOT_MODE_DESIRE_ABSOLUTE)
	end
	return w
end
_G.NIL_ABILITY = {}
setmetatable(_G.NIL_ABILITY, {
	__index = function(k, x)
		local y = {
			IsFullyCastable = true,
			IsTrained = true,
			IsHidden = true,
			IsActivated = true,
			IsStealable = true,
			IsInAbilityPhase = true,
			IsChanneling = true,
			IsUltimate = true,
		}
		if y[x] then
			return function()
				return false
			end
		end
		local z = {
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
		if z[x] then
			return function()
				return 0
			end
		end
		return function()
			return nil
		end
	end,
})
function SafeAbility(A, B, C)
	if A == nil then
		if B then
			log('[WARN] %s ability "%s" is nil (removed/renamed/innate?) — using safe proxy', C or "unknown", B)
		end
		return _G.NIL_ABILITY
	end
	return A
end
local D = GetTeamPlayers
local E = nil
function GetTeamPlayers(F, G)
	if G then
		return D(F)
	end
	local H = D(F)
	if F == TEAM_DIRE then
		if E ~= nil then
			return E
		end
		local I = {}
		for J, K in pairs(H) do
			if not IsPlayerBot(K) then
				table.insert(I, K)
			end
		end
		if #I > 0 then
			local L = { 5, 6, 7, 8, 9 }
			H = {}
			for i = 1, #L do
				table.insert(H, L[i])
			end
			for i = 1, #I do
				for M = 1, 5 do
					if I[i] + 5 == L[M] then
						H[M] = I[i]
					end
				end
			end
			for i = #H, 1, -1 do
				local N = 0
				if H[i] > 4 then
					for M = 1, #H do
						if H[M + i] ~= nil and H[M + i] < 5 then
							N = N + 1
						end
					end
					H[i] = H[i] + N
				end
			end
		end
		E = H
	end
	return H
end
IsDebug = b.DebugMode
local SafeCallPerf = nil
local function LoadSafeCallPerf()
	if SafeCallPerf ~= nil then
		return SafeCallPerf
	end
	SafeCallPerf = false
	local ok, mt = pcall(require, GetScriptDirectory() .. "/FuncLib/systems/match_trace")
	if ok and mt and mt.PerfEnabled and mt.PerfEnabled() and mt.PerfSample then
		SafeCallPerf = mt
	end
	return SafeCallPerf
end
function SafeCall(O, P, Q)
	return function(...)
		local perf = LoadSafeCallPerf()
		local t0 = nil
		if perf and RealTime then
			t0 = RealTime()
		end
		local n, R, S, T = pcall(O, ...)
		if t0 ~= nil and perf then
			perf.PerfSample(Q or "SafeCall", RealTime() - t0)
		end
		if n then
			return R, S, T
		end
		local U = ""
		pcall(function()
			U = GetBot():GetUnitName() .. " "
		end)
		log("[ERROR] %s%s: %s", U, Q or "unknown", tostring(R))
		return P
	end
end
local V = nil
function IsLanMode()
	if V ~= nil then
		return V
	end
	local n, W = pcall(function()
		return Convars:GetInt("sv_lan")
	end)
	if n and W ~= nil then
		V = W == 1
	else
		V = false
	end
	return V
end
local X = GetUnitToUnitDistance
function GetUnitToUnitDistance(Y, Z)
	if not Y then
		return 1000
	end
	if Z == nil or pcall(function()
		return Z:GetLocation()
	end) == false then
		return 1000
	end
	return X(Y, Z)
end
local _ = GetUnitToLocationDistance
function GetUnitToLocationDistance(a0, a1)
	if a0 == nil then
		log("[OVERRIDE] GetUnitToLocationDistance nil unit\n%s", e(2))
		return 1000
	end
	if a1 == nil or type(a1) ~= "userdata" then
		log(
			"[OVERRIDE] GetUnitToLocationDistance bad location (type=%s) for %s\n%s",
			type(a1),
			tostring(a0 and a0.GetUnitName and a0:GetUnitName()),
			e(2)
		)
		return 1000
	end
	return _(a0, a1)
end
local a2 = CDOTA_Bot_Script.WasRecentlyDamagedByAnyHero
function CDOTA_Bot_Script:WasRecentlyDamagedByAnyHero(a3)
	if not self:IsHero() then
		return nil
	end
	return a2(self, a3)
end
local a4 = CDOTA_Bot_Script.GetNearbyTowers
function CDOTA_Bot_Script:GetNearbyTowers(a5, a6)
	if not self:IsHero() then
		return nil
	end
	return a4(self, math.min(a5, 1600), a6)
end
local a7 = CDOTA_Bot_Script.IsIllusion
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
	return a7(self)
end
local a8 = CDOTA_Bot_Script.HasModifier
function CDOTA_Bot_Script:HasModifier(a9)
	if not self:CanBeSeen() then
		return false
	end
	return a8(self, a9)
end
-- Lotus pools report CanBeSeen() while fogged, then NumModifiers logs a warning.
local lotusPoolNumModifiers = CDOTA_Bot_Script.NumModifiers
function CDOTA_Bot_Script:NumModifiers()
	if self ~= nil and self.GetUnitName ~= nil and self:GetUnitName() == "npc_dota_lotus_pool" then
		return 0
	end
	return lotusPoolNumModifiers(self)
end
local aa = CDOTA_Bot_Script.GetLocation
function CDOTA_Bot_Script:GetLocation()
	if self == nil or not self:IsBuilding() and not self:CanBeSeen() then
		return nil
	end
	return aa(self)
end
local ab = CDOTA_Bot_Script.GetMagicResist
function CDOTA_Bot_Script:GetMagicResist()
	if self == nil or not self:CanBeSeen() then
		return 1
	end
	return ab(self)
end
local ac = CDOTA_Bot_Script.IsInvulnerable
function CDOTA_Bot_Script:IsInvulnerable()
	if not self:CanBeSeen() then
		return false
	end
	if self:HasModifier("modifier_dazzle_nothl_projection_soul_debuff") then
		return false
	end
	return ac(self)
end
local ad = CDOTA_Bot_Script.IsAttackImmune
function CDOTA_Bot_Script:IsAttackImmune()
	if not self:CanBeSeen() then
		return false
	end
	return ad(self)
end
local ae = CDOTA_Bot_Script.IsUsingAbility
function CDOTA_Bot_Script:IsUsingAbility()
	if not self:CanBeSeen() or not self:IsHero() then
		return false
	end
	return ae(self)
end
local af = CDOTA_Bot_Script.IsChanneling
function CDOTA_Bot_Script:IsChanneling()
	if not self:CanBeSeen() then
		return false
	end
	return af(self)
end
local ag = CDOTA_Bot_Script.GetAttackTarget
function CDOTA_Bot_Script:GetAttackTarget()
	if not self:CanBeSeen() then
		return nil
	end
	return ag(self)
end
local ah = CDOTA_Bot_Script.GetNearbyHeroes
function CDOTA_Bot_Script:GetNearbyHeroes(a5, a6, ai)
	if not self:CanBeSeen() then
		return nil
	end
	return ah(self, math.min(a5, 1600), a6, ai)
end
local aj = CDOTA_Bot_Script.IsMagicImmune
function CDOTA_Bot_Script:IsMagicImmune()
	if not self then
		return false
	end
	if self:CanBeSeen() then
		if
			aj(self)
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
local ak = RandomFloat
local al = 0.00000001
function RandomFloat(am, an)
	return am + math.random() * (an - am + al)
end
local ao = CDOTA_Bot_Script.GetNearbyNeutralCreeps
function CDOTA_Bot_Script:GetNearbyNeutralCreeps(a5)
	return ao(self, math.min(a5, 1600))
end
local ap = CDOTA_Bot_Script.GetNearbyLaneCreeps
function CDOTA_Bot_Script:GetNearbyLaneCreeps(a5, a6)
	return ap(self, math.min(a5, 1600), a6)
end
local aq = CDOTA_Bot_Script.GetNearbyCreeps
function CDOTA_Bot_Script:GetNearbyCreeps(a5, a6)
	return aq(self, math.min(a5, 1600), a6)
end
local ar = CDOTA_Bot_Script.GetUnitName
function CDOTA_Bot_Script:GetUnitName()
	local as = ar(self)
	if string.find(as, "lone_druid_bear") then
		as = "npc_dota_hero_lone_druid_bear"
	end
	return as
end
local at = CDOTABaseAbility_BotScript.GetCastRange
function CDOTABaseAbility_BotScript:GetCastRange()
	local m = GetBot()
	if self then
		local au = self:GetSpecialValueInt("AbilityCastRange")
		if au == 0 then
			au = at(self)
		end
		if m then
			for i = 0, 7 do
				local av = m:GetAbilityInSlot(i)
				if av and av:IsTrained() then
					local aw = av:GetName()
					if aw == "keeper_of_the_light_spirit_form" then
						if m:HasModifier("modifier_keeper_of_the_light_spirit_form") then
							au = au + av:GetSpecialValueInt("cast_range")
						end
					elseif aw == "rubick_arcane_supremacy" then
						au = au + av:GetSpecialValueInt("cast_range")
					end
				end
			end
			local ax = { 0, 1, 2, 3, 4, 5, 16, 17 }
			for i = 1, #ax do
				local ay = m:GetItemInSlot(ax[i])
				if ay then
					local az = ay:GetName()
					if az == "item_aether_lens" then
						au = au + ay:GetSpecialValueInt("cast_range_bonus")
					elseif az == "item_ethereal_blade" then
						au = au + ay:GetSpecialValueInt("bonus_cast_range")
					elseif az == "item_magnifying_monocle" then
						au = au + ay:GetSpecialValueInt("bonus_cast_range")
					elseif az == "item_enhancement_keen_eyed" then
						au = au + ay:GetSpecialValueInt("cast_range_bonus")
					elseif az == "item_enhancement_mystical" then
						au = au + ay:GetSpecialValueInt("bonus_cast_range")
					elseif az == "item_enhancement_boundless" then
						au = au + ay:GetSpecialValueInt("bonus_cast_range")
					elseif string.find(az, "item_dagon") then
						local aA = false
						for M = 0, 5 do
							local aB = m:GetItemInSlot(M)
							if aB and aB ~= ay and string.find(aB:GetName(), "item_aether_lens") then
								aA = true
								break
							end
						end
						if not aA then
							au = au + ay:GetSpecialValueInt("cast_range_bonus")
						end
					end
				end
			end
		end
		return au
	end
	return at(self)
end
local aC = CDOTA_Bot_Script.GetAbilityByName
function CDOTA_Bot_Script:GetAbilityByName(aw)
	if aw == nil or aw == "" then
		return nil
	end
	return aC(self, aw)
end
local aD = FindAbilityByName
if aD then
	function FindAbilityByName(aw)
		if aw == nil or aw == "" then
			return nil
		end
		return aD(aw)
	end
end
-- Map and system abilities every hero carries hidden: outpost capture (ability_capture),
-- lamps, Twin Gates (twin_gate_portal_warp), Underlord portals, plus/seasonal. They are
-- meant to be cast while hidden; refusing them left heroes standing at an outpost forever.
local function IsHiddenByDesign(av)
	local ok, name = pcall(function()
		return av:GetName()
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
local aE = CDOTA_Bot_Script.Action_UseAbility
function CDOTA_Bot_Script:Action_UseAbility(av)
	if av == nil or av:IsHidden() and not IsHiddenByDesign(av) then
		CastRefusedEarly(self, av, "Action_UseAbility")
		return nil
	end
	return aE(self, av)
end
local aF = CDOTA_Bot_Script.ActionPush_UseAbility
function CDOTA_Bot_Script:ActionPush_UseAbility(av)
	if av == nil or av:IsHidden() and not IsHiddenByDesign(av) then
		CastRefusedEarly(self, av, "ActionPush_UseAbility")
		return nil
	end
	return aF(self, av)
end
-- Every targeted or queued cast refuses a hidden ability or a missing/wrong target before it
-- reaches the server. A hidden ability (Minefield Sign without Scepter) still reports
-- IsFullyCastable, so a hero kept ordering it every think and stood still.
local castRefusedAt = {}
local function CastRefused(self, av, method, why)
	local name = "nil"
	if av ~= nil then
		local ok, n = pcall(function()
			return av:GetName()
		end)
		name = ok and tostring(n) or "?"
	end
	local hero = (string.gsub(tostring(self:GetUnitName()), "npc_dota_hero_", ""))
	local key = hero .. "|" .. name .. "|" .. why
	if DotaTime() < (castRefusedAt[key] or -999) then
		return
	end
	castRefusedAt[key] = DotaTime() + 30
	pcall(print, string.format("[OHA-CAST] t=%.0f %s %s %s refused=%s", DotaTime(), hero, method, name, why))
end
CastRefusedEarly = function(self, av, method)
	CastRefused(self, av, method, av == nil and "nil-ability" or "hidden")
end
local function IsVector(v)
	if v == nil then
		return false
	end
	local ok, x = pcall(function()
		return v.x
	end)
	return ok and type(x) == "number"
end
local function GuardCast(method, targetKind)
	local original = CDOTA_Bot_Script[method]
	if original == nil then
		return
	end
	CDOTA_Bot_Script[method] = function(self, av, target, ...)
		if av == nil then
			CastRefused(self, av, method, "nil-ability")
			return nil
		end
		local okHidden, hidden = pcall(function()
			return av:IsHidden()
		end)
		if okHidden and hidden and not IsHiddenByDesign(av) then
			CastRefused(self, av, method, "hidden")
			return nil
		end
		if targetKind == "location" and not IsVector(target) then
			CastRefused(self, av, method, target == nil and "nil-location" or "not-a-location")
			return nil
		end
		if targetKind == "entity" and (target == nil or IsVector(target)) then
			CastRefused(self, av, method, target == nil and "nil-target" or "location-as-target")
			return nil
		end
		if targetKind == "tree" and target == nil then
			CastRefused(self, av, method, "nil-tree")
			return nil
		end
		-- A no-target cast takes only the ability. Do not hand the engine an extra nil.
		if targetKind == "none" then
			return original(self, av)
		end
		return original(self, av, target, ...)
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
local aG = CDOTA_Bot_Script.Action_AttackUnit
function CDOTA_Bot_Script:Action_AttackUnit(aH, aI)
	if aH == nil then
		log("[OVERRIDE] Action_AttackUnit nil target for %s\n%s", tostring(self and self:GetUnitName()), e(2))
		return
	end
	return aG(self, aH, aI)
end
local aJ = CDOTA_Bot_Script.GetAssignedLane
function CDOTA_Bot_Script:GetAssignedLane()
	if not self or self:GetTeam() ~= GetTeam() then
		log(
			"[OVERRIDE] GetAssignedLane on non-teammate: unit=%s unitTeam=%s runningTeam=%s\n%s",
			tostring(self and self:GetUnitName()),
			tostring(self and self:GetTeam()),
			tostring(GetTeam()),
			e(2)
		)
		return LANE_NONE
	end
	return aJ(self)
end
local aK = CDOTA_Bot_Script.GetTarget
function CDOTA_Bot_Script:GetTarget()
	if not self or not self:IsBot() then
		return nil
	end
	return aK(self)
end
local aL = CDOTA_Bot_Script.GetAttackRange
function CDOTA_Bot_Script:GetAttackRange()
	if not self:CanBeSeen() then
		return 200
	end
	return aL(self)
end
local aM = CDOTA_Bot_Script.ActionImmediate_SwapItems
local aN = 6 + 5
local function SwapMovesBranchToBackpack(self, fromSlot, toSlot)
	if toSlot < 6 or toSlot > 8 then
		return false
	end
	local it = self:GetItemInSlot(fromSlot)
	if it == nil or it:GetName() ~= "item_branches" then
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
	local it = unit:GetItemInSlot(slot)
	return it ~= nil and (string.gsub(it:GetName(), "^item_", "")) or "-"
end
-- [OHA-ITEM]: every swap that touches the blood grenade, and why a blocked one was refused.
local function LogGrenadeSwap(self, aO, aP, result)
	local a, b = SlotName(self, aO), SlotName(self, aP)
	if a ~= "blood_grenade" and b ~= "blood_grenade" then
		return
	end
	if result ~= "ok" then
		local key = result .. aO .. ":" .. aP
		if self._grenadeSwapLogKey == key and DotaTime() < (self._grenadeSwapLogAt or -999) then
			return
		end
		self._grenadeSwapLogKey = key
		self._grenadeSwapLogAt = DotaTime() + 5
	end
	pcall(print, string.format(
		"[OHA-ITEM] t=%.0f %s swap %d(%s)<->%d(%s) %s",
		DotaTime(),
		(string.gsub(self:GetUnitName(), "npc_dota_hero_", "")),
		aO,
		a,
		aP,
		b,
		result
	))
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
	pcall(print, string.format(
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
	))
end
function CDOTA_Bot_Script:ActionImmediate_SwapItems(aO, aP)
	local forced = self._swapDespiteEnemies
	self._swapDespiteEnemies = nil
	-- A branch parked for any other item gets pulled straight back, and that round trip
	-- leaves it on cooldown. The grenade is the exception: it has to stay throwable.
	if SwapMovesBranchToBackpack(self, aO, aP) or SwapMovesBranchToBackpack(self, aP, aO) then
		LogGrenadeSwap(self, aO, aP, "blocked-branch-rule")
		return nil
	end
	if self.itemSwapTime == nil then
		-- Start in the past. At 0 every swap was refused until 0:11, including the
		-- pregame swap that moves a grenade bought into a full bag.
		self.itemSwapTime = -1000
	end
	local enemies = #(self:GetNearbyHeroes(1000, true, BOT_MODE_NONE) or {})
	local cooldown = aN - (DotaTime() - self.itemSwapTime)
	if (forced or enemies == 0) and cooldown < 0 then
		self.itemSwapTime = DotaTime()
		local nameA, nameB = SlotName(self, aO), SlotName(self, aP)
		-- After a swap the engine ignored, try the slots the other way round once.
		local reversed = self._swapTryReverse == true
		self._swapTryReverse = nil
		LogGrenadeSwap(self, aO, aP, (forced and "ok-forced" or "ok") .. (reversed and "-reversed" or ""))
		self._swapCheck = { a = aO, b = aP, nameA = nameA, nameB = nameB, at = DotaTime(), reversed = reversed }
		if reversed then
			return aM(self, aP, aO)
		end
		return aM(self, aO, aP)
	end
	if cooldown >= 0 then
		LogGrenadeSwap(self, aO, aP, string.format("blocked-cooldown(%.0fs)", cooldown))
	else
		LogGrenadeSwap(self, aO, aP, string.format("blocked-enemies(%d)", enemies))
	end
	return nil
end
local aR = CDOTA_Bot_Script.GetUnitToLocationDistance
function CDOTA_Bot_Script:GetUnitToLocationDistance(a0, a1)
	if a1 == nil then
		log("[WARN] GetUnitToLocationDistance nil location for %s", self:GetUnitName())
		return 200
	end
	return aR(self, a0, a1)
end
local aS = CDOTA_Bot_Script.GetHealth
function CDOTA_Bot_Script:GetHealth()
	if self == nil or not self:CanBeSeen() then
		return 666
	end
	local aT = aS(self)
	if self ~= nil and self:GetUnitName() == "npc_dota_hero_medusa" and aT > 0 then
		local aU = self:GetMana()
		local aV = 0.95
		if self:GetLevel() < 12 then
			aV = 0.5
		end
		local aW = 2.6
		local aX = aU * aW * aV
		return aT + aX
	end
	return aT
end
local aY = CDOTA_Bot_Script.GetMaxHealth
function CDOTA_Bot_Script:GetMaxHealth()
	if self ~= nil and self:GetUnitName() == "npc_dota_hero_medusa" then
		local aV = 0.95
		if self:GetLevel() < 12 then
			aV = 0.5
		end
		local aW = 2.6
		local aZ = self:GetMaxMana() * aW * aV
		return aY(self) + aZ
	end
	return aY(self)
end
function CDOTA_Bot_Script:OriginalGetHealth()
	return aS(self)
end
function CDOTA_Bot_Script:OriginalGetMaxHealth()
	return aY(self)
end
local a_ = CDOTA_Bot_Script.GetMana
function CDOTA_Bot_Script:GetMana()
	if self ~= nil and self:GetUnitName() == "npc_dota_hero_huskar" then
		return 0
	end
	return a_(self)
end
local b0 = CDOTA_Bot_Script.GetMaxMana
function CDOTA_Bot_Script:GetMaxMana()
	if self ~= nil and self:GetUnitName() == "npc_dota_hero_huskar" then
		return 0
	end
	return b0(self)
end
local b1 = { orig_GetTeamPlayers = D, GetTeamPlayers = GetTeamPlayers }
return b1
