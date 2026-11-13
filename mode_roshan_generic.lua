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
	if b ~= "npc_dota_hero_huskar" and c.ShouldLeaveRoshanFight(a) then
		a._roshDipActive = false
		return 0
	end
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
local function RoshLog(fmt, ...)
	pcall(print, string.format(
		"[OHA-ROSH] t=%.0f %s %s " .. fmt,
		DotaTime(),
		GetTeam() == TEAM_DIRE and "dire" or "radiant",
		(string.gsub(a:GetUnitName(), "npc_dota_hero_", "")),
		...
	))
end
-- One line when this bot's Roshan desire turns on or off, with the reason.
local function LogDesireChange(final)
	local on = final >= 0.3
	if on == (a._roshOn == true) then
		return
	end
	a._roshOn = on
	local M = c.GetCurrentRoshanLocation()
	RoshLog(
		"%s desire=%.2f why=%s mode=%s dist=%d allies=%d enemies=%d fit=%s",
		on and "call" or "drop",
		final,
		tostring(a._roshWhy),
		tostring(a:GetActiveMode()),
		M ~= nil and math.floor(GetUnitToLocationDistance(a, M)) or -1,
		c.GetNumOfAliveHeroes(false),
		c.GetNumOfAliveHeroes(true),
		tostring(a._roshFitWhy)
	)
end
function GetDesire()
	if ShouldSkipBotThink(GetBot()) then
		return 0
	end
	local D, gatherCall = GetDesireHelper()
	local final = v(D)
	-- A live gather has to beat farm and a one-kill push. VERYHIGH in this engine is ~0.6,
	-- so clamping the call there is why the rest of the team never leaves the lane.
	if gatherCall and final >= 0.9 then
		final = 0.96
	else
		final = Clamp(final, 0, BOT_MODE_DESIRE_VERYHIGH)
	end
	if DotaTime() > 3 * 60 and DotaTime() > C + 15 then
		C = DotaTime()
		log(
			string.format(
				"[ROSH] t=%.0f %s raw=%.2f final=%.2f alive=%s dps=%s kill=%s hg=%s eA=%d aA=%d",
				DotaTime(),
				string.gsub(a:GetUnitName(), "npc_dota_hero_", ""),
				D,
				final,
				tostring(c.IsRoshanAlive()),
				tostring(j),
				tostring(f),
				tostring(c.Utils.IsTeamPushingSecondTierOrHighGround(a)),
				c.GetNumOfAliveHeroes(true),
				c.GetNumOfAliveHeroes(false)
			)
		)
	end
	LogDesireChange(final)
	-- Do not shout here — desire alone is not a commit (caused "Let's Rosh" then nothing).
	return final
end
local function AllyActiveMode(hero)
	local ok, mode = pcall(function()
		return hero:GetActiveMode()
	end)
	if ok then
		return mode
	end
	return nil
end
-- A low hero (except Huskar) and anyone already defending the ancient are not part of the call.
local function AllyShouldJoin(ally)
	if ally == nil or not ally:IsAlive() or not ally:IsHero() or ally:IsIllusion() then
		return false
	end
	if ally:GetUnitName() ~= "npc_dota_hero_huskar" and c.GetHP(ally) < 0.45 then
		return false
	end
	local ancient = GetAncient(GetTeam())
	if ancient ~= nil and GetUnitToUnitDistance(ally, ancient) < 2500 then
		if c.Utils.CountEnemyHeroesNear(ancient:GetLocation(), 2500) >= 1 then
			return false
		end
	end
	return true
end
-- grouped: joiners already at the pit or the fountain-side rally.
-- pending: furthest joiner who switched to Roshan and is still outside that ring.
-- required: living allies this call is supposed to wait for.
local function RoshanGather(pit)
	local grouped, pending, required = 0, 0, 0
	local players = GetTeamPlayers(GetTeam())
	for i = 1, #players do
		local ally = GetTeamMember(i)
		if AllyShouldJoin(ally) then
			required = required + 1
			local dist = GetUnitToLocationDistance(ally, pit)
			if dist <= 1800 then
				grouped = grouped + 1
			elseif ally ~= a and AllyActiveMode(ally) == BOT_MODE_ROSHAN and dist > pending then
				pending = dist
			end
		end
	end
	return grouped, pending, required
end
local function GatherMinimum()
	if c.IsLateGame() then
		return 2
	elseif c.IsMidGame() then
		return 3
	end
	return 4
end
-- Someone is already standing on the call. That is what pulls the rest of the team.
local function TeamRoshanCall(pit)
	local rally = c.AdjustLocationWithOffsetTowardsFountain(pit, 900)
	local players = GetTeamPlayers(GetTeam())
	for i = 1, #players do
		local ally = GetTeamMember(i)
		if ally ~= nil and ally:IsAlive() and ally:IsHero() and not ally:IsIllusion() then
			if GetUnitToLocationDistance(ally, rally) <= 2800 then
				local mode = ally == a and a:GetActiveMode() or AllyActiveMode(ally)
				if mode == BOT_MODE_ROSHAN then
					return true
				end
			end
		end
	end
	return false
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
-- Enemies that can reach the pit now. One who just respawned is still walking back
-- from the fountain, so the numbers a kill bought last a little past the respawn.
local function ContestingEnemies(M)
	local alive = c.GetNumOfAliveHeroes(true)
	local grace = KillWindow.TransitGrace(M)
	local transit = KillWindow.EnemiesInTransit(grace)
	return math.max(0, alive - transit), transit
end
-- Numbers rule for a fresh take. Returns ok, why.
local function FreshTakeNumbers(alliesAlive, enemiesAlive, missing)
	if enemiesAlive >= alliesAlive then
		return false, string.format("even(%dv%d)", alliesAlive, enemiesAlive)
	end
	if enemiesAlive >= 4 and missing < 2 then
		return false, string.format("enemies4(missing=%d)", missing)
	end
	if enemiesAlive >= 3 and alliesAlive - enemiesAlive < 1 and missing < 2 then
		return false, string.format("enemies3(missing=%d)", missing)
	end
	return true, "ok"
end
-- Safe to start/continue Roshan: numbers + pit not contested. Returns ok, why.
local function IsRoshanEngageSafe(M, finishing)
	if M == nil then
		return false, "no-pit"
	end
	local alliesAlive = c.GetNumOfAliveHeroes(false)
	local enemiesAlive = ContestingEnemies(M)
	local missing = c.Utils.CountMissingEnemyHeroes and c.Utils.CountMissingEnemyHeroes() or 0
	local alliesNear = c.GetAlliesNearLoc(M, 1600) or {}
	local enemiesNear = c.GetLastSeenEnemiesNearLoc(M, 1600) or {}
	local alliesInPit = #alliesNear
	local enemiesInPit = #enemiesNear
	-- Contested pit: enemies already there in force.
	if enemiesInPit >= 2 and enemiesInPit >= math.max(1, alliesInPit) then
		return false, string.format("contested(%d)", enemiesInPit)
	end
	if finishing then
		-- Finish only if we already own the pit / have numbers.
		if alliesInPit >= 2 and enemiesInPit <= 1 then
			return true, "ok"
		end
		if alliesAlive >= enemiesAlive + 1 and enemiesInPit == 0 then
			return true, "ok"
		end
		return false, string.format("finish-unsafe(pit=%d foes=%d)", alliesInPit, enemiesInPit)
	end
	-- Fresh take: need a real numbers edge or missing enemies — never full 5v5.
	return FreshTakeNumbers(alliesAlive, enemiesAlive, missing)
end
-- Time the group needs: the GatherMinimum-th closest joiner walks to the rally, then the
-- group kills Roshan. Everyone computes the same number, so the team goes or stays together.
local function TakeTimeNeeded(M)
	local rally = c.AdjustLocationWithOffsetTowardsFountain(M, 900)
	local etas = {}
	local dps = {}
	local players = GetTeamPlayers(GetTeam())
	for i = 1, #players do
		local ally = GetTeamMember(i)
		if AllyShouldJoin(ally) then
			local speed = math.max(250, ally:GetCurrentMovementSpeed())
			local eta = GetUnitToLocationDistance(ally, rally) / speed
			local spa = ally:GetSecondsPerAttack()
			local hit = (spa ~= nil and spa > 0) and ally:GetAttackDamage() / spa or 0
			etas[#etas + 1] = { eta = eta, dps = hit }
		end
	end
	if #etas == 0 then
		return 999, 999, 999
	end
	table.sort(etas, function(x, y)
		return x.eta < y.eta
	end)
	local n = math.min(#etas, GatherMinimum())
	local groupDps = 0
	for i = 1, n do
		groupDps = groupDps + etas[i].dps
	end
	local roshHp = 6000 + 130 * math.max(0, DotaTime() / 60)
	if c.Utils.IsValidUnit(k) and k:CanBeSeen() then
		roshHp = k:GetHealth()
	end
	-- Roshan's armor takes roughly half of right-click damage.
	local killTime = math.max(8, math.min(60, roshHp / math.max(1, groupDps * 0.5)))
	return etas[n].eta + killTime, etas[n].eta, killTime
end
-- A take that only works because of a kill must fit inside that kill's window.
-- Returns ok, why.
local function TakeFitsWindow(M)
	local alliesAlive = c.GetNumOfAliveHeroes(false)
	local missing = c.Utils.CountMissingEnemyHeroes and c.Utils.CountMissingEnemyHeroes() or 0
	local kw = KillWindow.Tick()
	local everyone = c.GetNumOfAliveHeroes(true) + (kw.fresh or 0)
	if FreshTakeNumbers(alliesAlive, everyone, missing) then
		return true, "no-window-needed"
	end
	local left = KillWindow.WindowLeft()
	if left == nil then
		-- Only the transit grace is left. Not enough to start a walk.
		return false, "window-closed"
	end
	local window = left + KillWindow.TransitGrace(M)
	local need, eta, kill = TakeTimeNeeded(M)
	if need + 3 > window then
		return false, string.format("window-short(need=%.0f eta=%.0f kill=%.0f left=%.0f)", need, eta, kill, window)
	end
	return true, string.format("window(need=%.0f left=%.0f)", need, window)
end
-- Records why the desire came out as it did, for the [OHA-ROSH] call/abort lines.
local function Ret(d, why, call)
	a._roshWhy = why
	return d, call
end
function GetDesireHelper()
	if a:IsInvulnerable() or not a:IsHero() or not a:IsAlive() or not string.find(b, "hero") or a:IsIllusion() then
		return Ret(BOT_MODE_DESIRE_NONE, "invalid")
	end
	local L = GetAncient(GetTeam())
	if
		c.Utils.CountEnemyHeroesOnHighGround(GetTeam()) >= 2
		or L and c.Utils.CountEnemyHeroesNear(L:GetLocation(), 2500) >= 1
	then
		return Ret(BOT_MODE_DESIRE_NONE, "base-threat")
	end
	if not c.Utils.IsValidUnit(k) then
		G()
	end
	local M = c.GetCurrentRoshanLocation()
	local O = c.GetNumOfAliveHeroes(false)
	local P = ContestingEnemies(M)
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
	-- Re-checked every think. A team that was strong enough once is not strong enough for the rest of the game.
	j = c.HasEnoughDPSForRoshan(Q)
	if c.GetEnemiesAroundAncient(a, 2000) > 2 or c.GetHP(GetAncient(a:GetTeam())) < 0.6 then
		return Ret(BOT_MODE_DESIRE_NONE, "base-threat")
	end
	local alliesInPit = #(c.GetAlliesNearLoc(M, 1600) or {})
	local roshLow = c.Utils.IsValidUnit(k) and (k:GetHealth() / k:GetMaxHealth()) < 0.8
	-- Early game: no fresh pit. Only stay if Roshan is already low and allies are in it.
	if c.IsEarlyGame() and not (roshLow and alliesInPit >= 2 and IsRoshanEngageSafe(M, true)) then
		return Ret(BOT_MODE_DESIRE_NONE, "early-game")
	end
	if roshLow then
		local safeFinish, finishWhy = IsRoshanEngageSafe(M, true)
		if safeFinish and (j or alliesInPit >= 2) then
			local S = k:GetHealth() / k:GetMaxHealth()
			return Ret(RemapValClamped(S, 0.8, 0.0, 0.9, 1.0), "finishing")
		end
		-- Contested / unsafe finish — do not suicide into the pit.
		return Ret(BOT_MODE_DESIRE_NONE, safeFinish and "finish-no-dps" or finishWhy)
	end
	local safeTake, takeWhy = IsRoshanEngageSafe(M, false)
	if not safeTake then
		return Ret(BOT_MODE_DESIRE_NONE, takeWhy)
	end
	if O < P then
		return Ret(BOT_ACTION_DESIRE_NONE, "outnumbered")
	end
	-- A take that only works because of a kill has to fit in that kill's window. Once the
	-- group has committed at the rally, finish the walk in.
	local committed = a._roshCommitUntil ~= nil and DotaTime() < a._roshCommitUntil
	if not committed then
		local fits, fitWhy = TakeFitsWindow(M)
		a._roshFitWhy = fitWhy
		if not fits then
			return Ret(BOT_MODE_DESIRE_NONE, fitWhy)
		end
	end
	if f and j and TeamRoshanCall(M) and not a:WasRecentlyDamagedByAnyHero(2.0) then
		local enemiesHere = a:GetNearbyHeroes(1000, true, BOT_MODE_NONE) or {}
		if #enemiesHere == 0 then
			return Ret(0.96, "team-call", true)
		end
	end
	local kw = KillWindow.Tick()
	-- The kill window stays open until a respawned enemy could be back at the pit.
	local inTransit = KillWindow.EnemiesInTransit(KillWindow.TransitGrace(M))
	local killRosh = (kw.fresh >= 1 or inTransit >= 1) and f and j and not c.IsEarlyGame() and DotaTime() > 8 * 60
	if l == nil then
		l = c.Utils.IsHumanPlayerInTeam(GetTeam())
	end
	if l and not killRosh then
		if c.IsEarlyGame() then
			return Ret(BOT_ACTION_DESIRE_NONE, "early-game")
		end
		if DotaTime() < n then
			return Ret(BOT_ACTION_DESIRE_NONE, "human-cooldown")
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
					return Ret(BOT_MODE_DESIRE_LOW, "human-invite")
				else
					m = 0
					n = DotaTime() + (c.IsModeTurbo() and q or p)
					return Ret(BOT_MODE_DESIRE_NONE, "human-invite-expired")
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
					return Ret(0.95, "ping")
				end
				return Ret(BOT_MODE_DESIRE_NONE, "ping-unsafe")
			end
		end
		if DotaTime() < (c.IsModeTurbo() and 15 * 60 or 20 * 60) and not killRosh then
			return Ret(BOT_MODE_DESIRE_NONE, "too-early-no-kill")
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
		local why = "timer"
		if killRosh then
			local floor = BOT_MODE_DESIRE_VERYHIGH
			if Y < floor then
				KillWindow.LogRosh(a, Y, floor, kw)
				Y = floor
			end
			why = "kill-window"
		end
		return Ret(Clamp(Y, 0, BOT_MODE_DESIRE_VERYHIGH), why)
	end
	return Ret(BOT_ACTION_DESIRE_NONE, f and "no-dps" or "rosh-dead")
end
local a1 = 900
local a2 = 300
function Think()
	if not a:IsAlive() or c.CanNotUseAction(a) then
		return
	end
	if c.Item.TryPickupRoshanDrop(a) then
		return
	end
	local M = c.GetCurrentRoshanLocation()
	if M == nil then
		return
	end
	if c.ShouldLeaveRoshanFight(a) then
		local away = c.AdjustLocationWithOffsetTowardsFountain(M, 1600)
		a:Action_MoveToLocation(away)
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
	local rally = c.AdjustLocationWithOffsetTowardsFountain(M, a1)
	local pitAllies = c.GetAlliesNearLoc(M, 700) or {}
	local pitCount = 0
	for _, ally in pairs(pitAllies) do
		if c.IsValidHero(ally) and ally:IsAlive() and not ally:IsIllusion() then
			pitCount = pitCount + 1
		end
	end
	-- Fight is already going with a group in the pit. Join it.
	if finishing and pitCount >= 2 and safe then
		a8()
		return
	end
	-- A gank on the rally must not leave them idle. Fight if the local fight is ours,
	-- otherwise step toward the fountain instead of holding the spot.
	local function RallyThreat()
		local enemy = nil
		local enemyDist = 1200
		local near = c.GetEnemyList(a, 1200) or {}
		for _, hero in pairs(near) do
			if c.IsValidHero(hero) then
				local dist = GetUnitToUnitDistance(a, hero)
				if dist < enemyDist then
					enemy = hero
					enemyDist = dist
				end
			end
		end
		local seenLoc = nil
		local seenDist = 1400
		for _, pid in pairs(GetTeamPlayers(GetOpposingTeam())) do
			if IsHeroAlive(pid) then
				local info = GetHeroLastSeenInfo(pid)
				local spot = info and info[1]
				if spot ~= nil and spot.time_since_seen < 2.5 then
					local dist = GetUnitToLocationDistance(a, spot.location)
					if dist < seenDist then
						seenLoc = spot.location
						seenDist = dist
					end
				end
			end
		end
		local hit = a:WasRecentlyDamagedByAnyHero(2.0)
		if enemy == nil and seenLoc == nil and not hit then
			return false
		end
		local allies = #(c.GetAlliesNearLoc(a:GetLocation(), 1200) or {})
		if allies < 1 then
			allies = 1
		end
		local threats = #near
		if seenLoc ~= nil then
			threats = math.max(threats, 1)
		end
		local run = threats > allies or not c.WeAreStronger(a, 1200)
		a._roshThinkAt = DotaTime() - 4
		if run then
			local away = c.AdjustLocationWithOffsetTowardsFountain(a:GetLocation(), 700)
			if enemy ~= nil then
				away = c.VectorAway(a:GetLocation(), enemy:GetLocation(), 600)
				away = (away + c.AdjustLocationWithOffsetTowardsFountain(a:GetLocation(), 400)) / 2
			elseif seenLoc ~= nil then
				away = c.VectorAway(a:GetLocation(), seenLoc, 600)
			end
			a:Action_MoveToLocation(away)
			return true
		end
		if enemy ~= nil then
			if enemyDist <= a:GetAttackRange() + 150 then
				a:Action_AttackUnit(enemy, true)
			else
				a:Action_MoveToLocation(enemy:GetLocation())
			end
			return true
		end
		if seenLoc ~= nil or hit then
			a:Action_MoveToLocation(c.AdjustLocationWithOffsetTowardsFountain(a:GetLocation(), 400))
			return true
		end
		return false
	end
	if RallyThreat() then
		return
	end
	-- Hold the fountain side until the living team is in the ring, then go in together.
	-- Two at the rally used to count as ready, so the rest never had to arrive.
	local now = DotaTime()
	if a._roshGatherAt == nil or now - (a._roshThinkAt or 0) > 3 then
		a._roshGatherAt = now
		a._roshCommitUntil = nil
	end
	a._roshThinkAt = now
	local grouped, pending, required = RoshanGather(M)
	local elapsed = now - a._roshGatherAt
	local othersWalking = pending > 1800
	local minimum = math.min(GatherMinimum(), math.max(required, 1))
	local full = required > 0 and grouped >= required
	local committed = a._roshCommitUntil ~= nil and now < a._roshCommitUntil
	-- A short wait lets allies switch into the call. After that, the minimum group goes
	-- in as soon as nobody else is still walking. The old flat 22s wait was where kill
	-- windows ran out and the whole group walked away again.
	local arrived = not othersWalking and grouped >= minimum and elapsed >= 6
	-- Waiting for a straggler would outlast the kill window: go with who is here.
	local windowTight = false
	local left = KillWindow.WindowLeft()
	if othersWalking and grouped >= minimum and left ~= nil then
		local _, _, killTime = TakeTimeNeeded(M)
		local window = left + KillWindow.TransitGrace(M)
		windowTight = window < pending / 320 + killTime + 3
	end
	local capped = elapsed >= 40 and grouped >= math.min(2, math.max(required, 1))
	if safe and (full or arrived or windowTight or capped) then
		local fresh = not committed
		a._roshCommitUntil = now + 25
		committed = true
		if fresh then
			RoshLog(
				"commit grouped=%d/%d min=%d pending=%d elapsed=%.0f by=%s",
				grouped,
				required,
				minimum,
				math.floor(pending),
				elapsed,
				full and "full" or (arrived and "arrived" or (windowTight and "window" or "cap"))
			)
		end
	end
	local ready = safe and (committed or full or arrived or windowTight or capped)
	if not ready and now >= (a._roshGatherLogAt or -999) then
		a._roshGatherLogAt = now + 5
		local _, safeWhy = IsRoshanEngageSafe(M, finishing)
		RoshLog(
			"gather grouped=%d/%d min=%d pending=%d elapsed=%.0f safe=%s window=%s",
			grouped,
			required,
			minimum,
			math.floor(pending),
			elapsed,
			safe and "ok" or tostring(safeWhy),
			left ~= nil and string.format("%.0f", left) or "-"
		)
	end
	if not ready then
		a._roshCommitUntil = nil
		if GetUnitToLocationDistance(a, rally) > 50 then
			a:Action_MoveToLocation(rally + RandomVector(80))
		end
		if elapsed < 2 then
			local myId = a:GetPlayerID()
			local caller = true
			local players = GetTeamPlayers(GetTeam())
			for i = 1, #players do
				local ally = GetTeamMember(i)
				if
					ally ~= nil
					and ally ~= a
					and ally:IsAlive()
					and not ally:IsIllusion()
					and AllyActiveMode(ally) == BOT_MODE_ROSHAN
					and ally:GetPlayerID() < myId
				then
					caller = false
					break
				end
			end
			if caller then
				c.ModeAnnounce(a, "say_roshan", 20)
			end
		end
		return
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
