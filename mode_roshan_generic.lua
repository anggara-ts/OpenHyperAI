-- Roshan mode.
local a = GetBot()
local b = a:GetUnitName()
if
	a == nil
	or a:IsInvulnerable()
	or not a:IsHero()
	or not a:IsAlive()
	or not string.find(b, "hero")
	or a:IsIllusion()
then
	return
end
local c = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local KillWindow = require(GetScriptDirectory() .. "/FuncLib/systems/kill_window")
local d = require(GetScriptDirectory() .. "/FuncLib/systems/custom_loader")
local e = 0.0
local f = false
local g = DotaTime()
c.Utils.GameStates = c.Utils.GameStates or {}
c.Utils.GameStates.roshHandle = c.Utils.GameStates.roshHandle or nil
local h = 0
local i = false
local j = false
local k
local l = nil
local m = 0
local n = 0
local o = 15
local p = 3 * 60
local q = 2 * 60
local r = 0
local s = 0
local t = 1.5
local u = 8
local function v(w)
	if w <= 0 then
		return w
	end
	if b == "npc_dota_hero_huskar" then
		return w
	end
	local x = c.GetHP(a)
	local y = c.Utils.IsValidUnit(k) and c.GetHP(k) < 0.9
	if a:WasRecentlyDamagedByAnyHero(2.0) and x < 0.4 and not y then
		return w * RemapValClamped(x, 0.1, 0.4, 0.0, 0.5)
	end
	local z = c.Utils.IsValidUnit(k) and k:GetAttackTarget() == a
	local A = c.Utils.IsValidUnit(k) and GetUnitToUnitDistance(a, k) < 600
	if x < 0.5 and z and DotaTime() > s then
		r = DotaTime() + t
		s = DotaTime() + u
	end
	a._roshDipActive = DotaTime() < r
	if y and (a._roshDipActive or A) then
		return math.max(w, BOT_MODE_DESIRE_HIGH)
	end
	return w
end
local B = 0
local C = 0
function GetDesire()
	if ShouldSkipBotThink(GetBot()) then
		return 0
	end
	local D = GetDesireHelper()
	if DotaTime() > 3 * 60 and DotaTime() > C + 15 then
		C = DotaTime()
		local E = Clamp(v(D), 0, BOT_MODE_DESIRE_VERYHIGH)
		log(
			string.format(
				"[ROSH] t=%.0f %s raw=%.2f final=%.2f alive=%s dps=%s kill=%s hg=%s eA=%d aA=%d",
				DotaTime(),
				string.gsub(a:GetUnitName(), "npc_dota_hero_", ""),
				D,
				E,
				tostring(c.IsRoshanAlive()),
				tostring(j),
				tostring(f),
				tostring(c.Utils.IsTeamPushingSecondTierOrHighGround(a)),
				c.GetNumOfAliveHeroes(true),
				c.GetNumOfAliveHeroes(false)
			)
		)
	end
	D = v(D)
	-- Do not shout here — desire alone is not a commit (caused "Let's Rosh" then nothing).
	return Clamp(D, 0, BOT_MODE_DESIRE_VERYHIGH)
end
local function F()
	if c.IsLateGame() then
		return c.IsCore(a) and 1 or 2
	elseif c.IsMidGame() then
		return 3
	else
		return 4
	end
end
local function G()
	local H = c.Utils.GameStates.roshHandle
	if c.Utils.IsValidUnit(H) then
		k = H
		return
	end
	local I = a:GetNearbyNeutralCreeps(1600)
	for J, K in pairs(I) do
		if K:GetUnitName() == "npc_dota_roshan" then
			k = K
			c.Utils.GameStates.roshHandle = K
			return
		end
	end
end
-- Safe to start/continue Roshan: numbers + pit not contested.
-- finishing=true allows a looser gate when Roshan is already low and allies are in the pit.
local function IsRoshanEngageSafe(M, finishing)
	if M == nil then
		return false
	end
	local alliesAlive = c.GetNumOfAliveHeroes(false)
	local enemiesAlive = c.GetNumOfAliveHeroes(true)
	local missing = c.Utils.CountMissingEnemyHeroes and c.Utils.CountMissingEnemyHeroes() or 0
	local alliesNear = c.GetAlliesNearLoc(M, 1600) or {}
	local enemiesNear = c.GetLastSeenEnemiesNearLoc(M, 1600) or {}
	local alliesInPit = #alliesNear
	local enemiesInPit = #enemiesNear
	-- Contested pit: enemies already there in force.
	if enemiesInPit >= 2 and enemiesInPit >= math.max(1, alliesInPit) then
		return false
	end
	if finishing then
		-- Finish only if we already own the pit / have numbers.
		if alliesInPit >= 2 and enemiesInPit <= 1 then
			return true
		end
		if alliesAlive >= enemiesAlive + 1 and enemiesInPit == 0 then
			return true
		end
		return false
	end
	-- Fresh take: need a real numbers edge or missing enemies — never full 5v5.
	if enemiesAlive >= alliesAlive then
		return false
	end
	if enemiesAlive >= 4 and missing < 2 then
		return false
	end
	if enemiesAlive >= 3 and alliesAlive - enemiesAlive < 1 and missing < 2 then
		return false
	end
	return true
end
function GetDesireHelper()
	if a:IsInvulnerable() or not a:IsHero() or not a:IsAlive() or not string.find(b, "hero") or a:IsIllusion() then
		return BOT_MODE_DESIRE_NONE
	end
	local L = GetAncient(GetTeam())
	if
		c.Utils.CountEnemyHeroesOnHighGround(GetTeam()) >= 2
		or L and c.Utils.CountEnemyHeroesNear(L:GetLocation(), 2500) >= 1
	then
		return BOT_MODE_DESIRE_NONE
	end
	if not c.Utils.IsValidUnit(k) then
		G()
	end
	local M = c.GetCurrentRoshanLocation()
	local O = c.GetNumOfAliveHeroes(false)
	local P = c.GetNumOfAliveHeroes(true)
	local Q = {}
	for J, R in pairs(GetUnitList(UNIT_LIST_ALLIED_HEROES)) do
		if R:IsAlive() then
			table.insert(Q, R)
		end
	end
	f = c.IsRoshanAlive()
	if f and not i then
		h = DotaTime()
		i = true
	elseif not f then
		h = 0
		i = false
	end
	if c.HasEnoughDPSForRoshan(Q) then
		j = true
	end
	if c.GetEnemiesAroundAncient(a, 2000) > 2 or c.GetHP(GetAncient(a:GetTeam())) < 0.6 then
		return BOT_MODE_DESIRE_NONE
	end
	if c.Utils.IsValidUnit(k) then
		local S = k:GetHealth() / k:GetMaxHealth()
		if S < 0.8 then
			if IsRoshanEngageSafe(M, true) then
				return RemapValClamped(S, 0.8, 0.0, 0.9, 1.0)
			end
			-- Contested / unsafe finish — do not suicide into the pit.
			return BOT_MODE_DESIRE_NONE
		end
	end
	if not IsRoshanEngageSafe(M, false) then
		return BOT_MODE_DESIRE_NONE
	end
	if O < P then
		return BOT_ACTION_DESIRE_NONE
	end
	local kw = KillWindow.Tick()
	local killRosh = kw.fresh >= 1 and f and j and DotaTime() > 8 * 60
	if l == nil then
		l = c.Utils.IsHumanPlayerInTeam(GetTeam())
	end
	if l and not killRosh then
		if c.IsEarlyGame() then
			return BOT_ACTION_DESIRE_NONE
		end
		if DotaTime() < n then
			return BOT_ACTION_DESIRE_NONE
		end
		local T, U = c.GetHumanPing()
		local V = T ~= nil
			and U ~= nil
			and U.normal_ping
			and c.GetDistance(U.location, c.GetCurrentRoshanLocation()) < 600
			and DotaTime() < U.time + 5.0
		if not V then
			-- Soft invite without shouting: quiet staging desire only while safe.
			-- Old behavior announced then dropped after 15s — looked like false invites.
			if c.IsRoshanAlive() and j then
				if m == 0 then
					m = DotaTime()
				end
				local W = DotaTime() - m
				if W < o then
					return BOT_MODE_DESIRE_LOW
				else
					m = 0
					n = DotaTime() + (c.IsModeTurbo() and q or p)
					return BOT_MODE_DESIRE_NONE
				end
			else
				m = 0
			end
		else
			m = 0
			n = 0
		end
	end
	if f and j then
		local T, U = c.GetHumanPing()
		if T ~= nil and DotaTime() > 5.0 then
			if
				U ~= nil
				and U.normal_ping
				and GetUnitToLocationDistance(T, M) < 4500
				and c.GetDistance(U.location, M) < 600
				and DotaTime() < U.time + 5.0
			then
				if IsRoshanEngageSafe(M, false) then
					return 0.95
				end
				return BOT_MODE_DESIRE_NONE
			end
		end
		if DotaTime() < (c.IsModeTurbo() and 15 * 60 or 20 * 60) and not killRosh then
			return BOT_MODE_DESIRE_NONE
		end
		local X = RemapValClamped(DotaTime(), h, h + 2.5 * 60, 1, 2)
		local Y = RemapValClamped(GetRoshanDesire() * X, 0, 1, 0, BOT_MODE_DESIRE_ABSOLUTE)
		local Z = c.GetAlliesNearLoc(M, 1600)
		if #Z >= 4 then
			Y = 0.9
		end
		local _ = c.Utils.IsTeamPushingSecondTierOrHighGround(a)
		if _ and #Z < 3 then
			Y = Y * 0.6
		end
		if killRosh then
			local floor = BOT_MODE_DESIRE_VERYHIGH
			if Y < floor then
				KillWindow.LogRosh(a, Y, floor, kw)
				Y = floor
			end
		end
		return Clamp(Y, 0, BOT_MODE_DESIRE_VERYHIGH)
	end
	return BOT_ACTION_DESIRE_NONE
end
local a0 = 1000
local a1 = 900
local a2 = 300
function Think()
	if not a:IsAlive() or c.CanNotUseAction(a) then
		return
	end
	local M = c.GetCurrentRoshanLocation()
	if M == nil then
		return
	end
	if a._roshDipActive then
		local a3 = c.AdjustLocationWithOffsetTowardsFountain(M, 300)
		a:Action_MoveToLocation(a3)
		return
	end
	if not c.Utils.IsValidUnit(k) then
		G()
	end
	local a4 = GetUnitToLocationDistance(a, M)
	local a5 = a4 <= a2
	local finishing = c.Utils.IsValidUnit(k) and c.GetHP(k) < 0.9
	local safe = IsRoshanEngageSafe(M, finishing)
	local function a7()
		a:Action_MoveToLocation(M)
	end
	local function a8()
		if a5 and c.Utils.IsValidUnit(k) and c.CanBeAttacked(k) then
			a:Action_AttackUnit(k, true)
		else
			a7()
		end
	end
	-- Unsafe: hold fountain-side of pit, do not walk in or shout.
	if not safe then
		local hold = c.AdjustLocationWithOffsetTowardsFountain(M, a1)
		if GetUnitToLocationDistance(a, hold) > 80 then
			a:Action_MoveToLocation(hold + RandomVector(80))
		end
		return
	end
	if finishing then
		a8()
		return
	end
	local a9 = c.AdjustLocationWithOffsetTowardsFountain(M, a1)
	local aa = c.GetAlliesNearLoc(a9, a0)
	local ab = 0
	for J, ac in pairs(aa) do
		if c.IsValidHero(ac) and ac:IsAlive() and not ac:IsIllusion() then
			ab = ab + 1
		end
	end
	local ad = F()
	local ae = GetUnitToLocationDistance(a, a9)
	if ab < ad then
		if ae > 50 then
			a:Action_MoveToLocation(a9 + RandomVector(100))
		end
		-- Shout only when nearly ready to go (not while alone waiting forever).
		if ab >= ad - 1 and DotaTime() > (a._lastRoshGatherPing or 0) + 12 then
			a._lastRoshGatherPing = DotaTime()
			c.ModeAnnounce(a, "say_roshan", 12)
		end
		return
	end
	-- Commit: team gathered and safe — announce once, then enter pit.
	if not a._roshCommitAnnounced or DotaTime() - (a._roshCommitAnnounced or 0) > 45 then
		a._roshCommitAnnounced = DotaTime()
		c.ModeAnnounce(a, "say_roshan", 20)
	end
	if not a5 then
		a7()
		return
	end
	if c.Utils.IsValidUnit(k) and c.CanBeAttacked(k) then
		a:Action_AttackUnit(k, true)
	else
		a:Action_MoveToLocation(M + RandomVector(50))
	end
end
