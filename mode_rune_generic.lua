-- Rune mode. Walks to bounty and power runes. Wisdom shrine is not handled here.
local a = {}
local b = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local c = require(GetScriptDirectory() .. "/FuncLib/systems/custom_loader")
c.ThinkLess = c.Enable and c.ThinkLess or 1
local d = GetBot()
local e = 0
local f = 0
local g = false
local h = { RUNE_BOUNTY_1, RUNE_BOUNTY_2, RUNE_POWERUP_1, RUNE_POWERUP_2 }
local i, j, k, l, m, n
local o, p
local q = {}
-- Early-game console trace. Grep [OHA-RUNE]. One line a second while a bot is
-- within 1600 of a rune before 1:40, plus a line whenever the reason changes.
local RUNE_DBG_UNTIL = 100
local runeWhy = "none"
local dbgAt = -100
local dbgWhy = ""
local dbgLoc = nil
local function give(desire, why)
	if why ~= nil then
		runeWhy = why
	end
	return desire
end
local function ModeTag(mode)
	if mode == BOT_MODE_NONE then return "none" end
	if mode == BOT_MODE_LANING then return "laning" end
	if mode == BOT_MODE_ATTACK then return "attack" end
	if mode == BOT_MODE_ROAM then return "roam" end
	if mode == BOT_MODE_RETREAT then return "retreat" end
	if mode == BOT_MODE_FARM then return "farm" end
	if mode == BOT_MODE_WARD then return "ward" end
	if mode == BOT_MODE_RUNE then return "rune" end
	if mode == BOT_MODE_TEAM_ROAM then return "team_roam" end
	if BOT_MODE_LOTUS_POOL ~= nil and mode == BOT_MODE_LOTUS_POOL then return "lotus" end
	if BOT_MODE_WISDOM_SHRINE ~= nil and mode == BOT_MODE_WISDOM_SHRINE then return "wisdom" end
	if BOT_MODE_OUTPOST ~= nil and mode == BOT_MODE_OUTPOST then return "outpost" end
	return "m" .. tostring(mode)
end
local function RuneTag(id)
	if id == RUNE_BOUNTY_1 then return "b1" end
	if id == RUNE_BOUNTY_2 then return "b2" end
	if id == RUNE_POWERUP_1 then return "p1" end
	if id == RUNE_POWERUP_2 then return "p2" end
	return tostring(id)
end
local function StatusTag(st)
	if st == RUNE_STATUS_AVAILABLE then return "up" end
	if st == RUNE_STATUS_MISSING then return "miss" end
	if st == RUNE_STATUS_UNKNOWN then return "unk" end
	return tostring(st)
end
local function ActTag(action)
	if action == BOT_ACTION_TYPE_IDLE then return "idle" end
	if action == BOT_ACTION_TYPE_MOVE_TO then return "move" end
	if action == BOT_ACTION_TYPE_ATTACK then return "attack" end
	if action == BOT_ACTION_TYPE_PICK_UP_RUNE then return "pickup" end
	if action == BOT_ACTION_TYPE_USE_ABILITY then return "ability" end
	return "a" .. tostring(action)
end
local function HeroTag()
	local name = string.gsub(d:GetUnitName() or "?", "npc_dota_hero_", "")
	local team = GetTeam() == TEAM_RADIANT and "r" or "d"
	return name .. "/" .. team
end
local function NearRune()
	local bestId, bestDist = nil, math.huge
	local parts = {}
	for idx = 1, #h do
		local rune = h[idx]
		local dist = GetUnitToLocationDistance(d, GetRuneSpawnLocation(rune))
		parts[#parts + 1] = string.format("%s:%s:%.0f", RuneTag(rune), StatusTag(GetRuneStatus(rune)), dist)
		if dist < bestDist then
			bestId, bestDist = rune, dist
		end
	end
	return bestId, bestDist, table.concat(parts, " ")
end
function a.RuneDbg(desire)
	local ok, err = pcall(function()
		local t = DotaTime()
		if t > RUNE_DBG_UNTIL then
			return
		end
		local nearId, nearDist, runeList = NearRune()
		local why = runeWhy or "?"
		local inRune = l == BOT_MODE_RUNE
		if nearDist > 1600 and not inRune and (desire or 0) <= 0 then
			return
		end
		local loc = d:GetLocation()
		local moved = dbgLoc and b.GetDistance(dbgLoc, loc) or -1
		local dt = t - dbgAt
		if dt < 0.25 or (why == dbgWhy and dt < 1) then
			return
		end
		local stuck = (dt >= 0.8 and nearDist <= 900 and moved >= 0 and moved < 40) and 1 or 0
		dbgAt = t
		dbgWhy = why
		dbgLoc = loc
		local D = d.rune and d.rune.normal
		local best = "none"
		if D ~= nil and D.location ~= nil then
			best = string.format("%s:%s:%.0f", RuneTag(D.location), StatusTag(D.status), D.distance or -1)
		end
		print(string.format(
			"[OHA-RUNE] %s t=%.1f xy=%.0f,%.0f pos=%s mode=%s/%.2f des=%.2f why=%s best=%s near=%s:%.0f commit=%s n=%d/%d act=%s runeDo=%s moved=%.0f stuck=%d hp=%.2f cant=%s q=%d runes=%s",
			HeroTag(), t, loc.x, loc.y, tostring(k),
			ModeTag(l), m or 0, desire or 0, why, best,
			RuneTag(nearId), nearDist,
			d._earlyRuneCommit and "1" or "0",
			#(p or {}), #(o or {}),
			ActTag(d:GetCurrentActionType()),
			tostring(d._runeDo or "-"),
			moved, stuck, i or 0,
			b.CanNotUseAction(d) and "1" or "0",
			d.NumQueuedActions and d:NumQueuedActions() or 0,
			runeList
		))
	end)
	if not ok then
		print("[OHA-RUNE] err " .. tostring(err))
	end
end
local function doing(name)
	d._runeDo = name
	if DotaTime() > RUNE_DBG_UNTIL or name == d._runeDoPrev then
		return
	end
	local nearDist = select(2, NearRune())
	if nearDist > 1600 and DotaTime() > 0 then
		return
	end
	d._runeDoPrev = name
	local loc = d:GetLocation()
	print(string.format(
		"[OHA-RUNE] %s t=%.1f do=%s xy=%.0f,%.0f mode=%s",
		HeroTag(), DotaTime(), name, loc.x, loc.y, ModeTag(d:GetActiveMode())
	))
end
local function r(s)
	local t = GetRuneSpawnLocation(s)
	if q[s] and GameTime() - q[s] < 5 then
		return true
	end
	for u = 1, #GetTeamPlayers(GetTeam()) do
		local v = GetTeamMember(u)
		if v ~= nil and v:IsAlive() and not v:IsBot() then
			if GetUnitToLocationDistance(v, t) < 2000 then
				q[s] = GameTime()
				return true
			end
			local w = v:GetMostRecentPing()
			if w ~= nil and w.normal_ping and b.GetDistance(w.location, t) < 800 and GameTime() - w.time < 5 then
				q[s] = GameTime()
				return true
			end
		end
	end
	return false
end
function GetDesire()
	if ShouldSkipBotThink(GetBot()) then
		runeWhy = "skip"
		a.RuneDbg(0)
		return 0
	end
	local desire = GetDesireRaw()
	a.RuneDbg(desire)
	return desire
end
function GetDesireRaw()
	a.InitRune()
	d._mapObjKind = nil
	d._mapObjLoc = nil
	g = d:FindItemSlot("item_bottle") >= 0
	i = b.GetHP(d)
	j = b.GetMP(d)
	k = b.GetPosition(d)
	l = d:GetActiveMode()
	m = d:GetActiveModeDesire()
	n = d:GetAssignedLane()
	o = d:GetNearbyHeroes(1600, false, BOT_MODE_NONE) or {}
	p = d:GetNearbyHeroes(1600, true, BOT_MODE_NONE) or {}
	if d:IsInvulnerable() and i > 0.9 and d:DistanceFromFountain() < 500 then
		return give(BOT_MODE_DESIRE_ABSOLUTE, "fountain")
	end
	-- Before the fight bailouts. An enemy near the pool was returning NONE and lotus never started.
	do
		local MapObj = require(GetScriptDirectory() .. "/FuncLib/systems/map_objectives")
		local desire, loc, kind = MapObj.ConsiderObjectiveDesire(d)
		if desire > 0 and loc ~= nil and kind ~= nil then
			d._mapObjKind = kind
			d._mapObjLoc = loc
			return give(desire, "mapobj-" .. tostring(kind))
		end
	end
	if DotaTime() > 0 and #p > 0 then
		if #p > #o then
			return give(BOT_MODE_DESIRE_NONE, "outnumbered")
		end
		if d:WasRecentlyDamagedByAnyHero(2.0) and i < 0.4 then
			return give(BOT_MODE_DESIRE_NONE, "hurt")
		end
	end
	if b.Utils.IsTeamPushingSecondTierOrHighGround(d) then
		return give(BOT_MODE_DESIRE_NONE, "team-push")
	end
	local x = b.Utils.CountEnemyHeroesNear(GetAncient(GetTeam()):GetLocation(), 3200)
	if x >= 1 then
		return give(BOT_MODE_DESIRE_NONE, "ancient")
	end
	if b.Utils.CountEnemyHeroesOnHighGround(GetTeam()) >= 2 then
		return give(BOT_MODE_DESIRE_NONE, "highground")
	end
	-- A rune underfoot still beats a leftover fight. Farther than the bank, lotus and wisdom win.
	local runeId, runeDist = a.ClosestAvailableRune(400)
	local dying = i < 0.25 and #p > 0 and d:WasRecentlyDamagedByAnyHero(1.2)
	if
		runeId ~= nil
		and not dying
		and not a.SidelaneSkipsRiver(runeId, runeDist)
		and not a.SkipSecondLaningRune(runeId)
	then
		local D = d.rune.normal
		D.location = runeId
		D.distance = runeDist
		D.status = RUNE_STATUS_AVAILABLE
		D.type = GetRuneType(runeId)
		return give(BOT_MODE_DESIRE_ABSOLUTE + 0.02, "underfoot")
	end
	-- A leftover bounty sits beside the spawn, not on a second rune id. Stay and walk the ring.
	local sweepDesire = a.BountySweepDesire()
	if sweepDesire ~= nil then
		return give(sweepDesire, "bounty-sweep")
	end
	if not b.IsInLaningPhase() then
		if b.IsPushing(d) or b.IsDefending(d) then
			return give(BOT_MODE_DESIRE_NONE, "pushing")
		end
		local y = d:GetActiveMode()
		if y == BOT_MODE_PUSH_TOWER_TOP or y == BOT_MODE_PUSH_TOWER_MID or y == BOT_MODE_PUSH_TOWER_BOT then
			return give(BOT_MODE_DESIRE_NONE, "push-mode")
		end
	end
	if DotaTime() >= 60 and DotaTime() < 7 * 60 then
		local z = 2500
		if
			l == BOT_MODE_RUNE
			and d.rune
			and d.rune.normal
			and d.rune.normal.location ~= nil
			and d.rune.normal.location ~= -1
			and GetUnitToLocationDistance(d, GetRuneSpawnLocation(d.rune.normal.location)) < z
		then
			local A = GetRuneStatus(d.rune.normal.location)
			local here = GetUnitToLocationDistance(d, GetRuneSpawnLocation(d.rune.normal.location))
			-- 2:00 and 4:00 river runes are the mid's. A sidelaner who camped the
			-- 0:00 gold stays through the water spawn and picks up both.
			if A == RUNE_STATUS_AVAILABLE or A == RUNE_STATUS_UNKNOWN then
				if a.SidelaneSkipsRiver(d.rune.normal.location, here) or a.SkipSecondLaningRune(d.rune.normal.location) then
					-- fall through and let lane desire win
				elseif A == RUNE_STATUS_AVAILABLE and here <= 800 then
					return give(BOT_MODE_DESIRE_ABSOLUTE, "laning-close")
				else
					return give(BOT_MODE_DESIRE_VERYHIGH, "laning-hold")
				end
			end
		end
		local B = a.GetLaningRuneDesire(z)
		if B > 0 then
			return give(B, "laning")
		end
	end
	if d.rune and d.rune.normal then
		local C = b.IsInLaningPhase() and 1600 or 1200
		local D = d.rune.normal
		D.location, D.distance = a.GetBestRune()
		if D.distance > 4000 and DotaTime() >= 60 * 2 then
			return give(BOT_MODE_DESIRE_NONE, "too-far")
		end
		if DotaTime() < 0 and not d:WasRecentlyDamagedByAnyHero(10.0) then
			return give(BOT_MODE_DESIRE_MODERATE, "pre-horn")
		end
		if not b.IsInLaningPhase() and D.distance > 2000 then
			return give(BOT_MODE_DESIRE_NONE, "post-lane-far")
		end
		if D.location ~= -1 then
			D.type = GetRuneType(D.location)
			D.status = GetRuneStatus(D.location)
			local E = GetRuneSpawnLocation(D.location)
			if D.distance < 1200 then
				for F, G in pairs(o) do
					if G ~= nil and not G:IsBot() and GetUnitToLocationDistance(G, E) < 2000 then
						return give(BOT_MODE_DESIRE_NONE, "human-near")
					end
				end
			end
			if D.location == RUNE_BOUNTY_1 or D.location == RUNE_BOUNTY_2 then
				if
					D.status == RUNE_STATUS_AVAILABLE
					and (
						a.IsTeamMustSaveRune(D.location)
						or not b.IsInLaningPhase()
						or GetUnitToLocationDistance(d, E) <= 500
					)
				then
					if a.IsEnemyPickRune(D.location) then
						return give(BOT_MODE_DESIRE_NONE, "enemy-closer")
					end
					local desire
					if g or k >= 4 and not a.IsThereAllyWithBottle(E, 1600) then
						desire = a.GetScaledDesire(BOT_MODE_DESIRE_VERYHIGH, D.distance, 3500)
					else
						desire = a.GetScaledDesire(BOT_MODE_DESIRE_HIGH, D.distance, 3500)
					end
					return give(a.ApplyEarlyLaneRuneGate(desire, D.distance, D.status, "bounty"))
				elseif
					D.status == RUNE_STATUS_UNKNOWN
					and D.distance <= C * 1.5
					and DotaTime() > 3 * 60 + 50
					and (e % 4 == 0 or e % 4 == 3 and f > 45)
				then
					return give(a.GetScaledDesire(BOT_MODE_DESIRE_HIGH, D.distance, C), "bounty-unknown")
				elseif
					D.status == RUNE_STATUS_MISSING
					and D.distance <= C * 1.5
					and DotaTime() > 3 * 60 + 50
					and (e % 4 == 3 or f > 52)
				then
					return give(a.GetScaledDesire(BOT_MODE_DESIRE_HIGH, D.distance, C * 2.5), "bounty-missing")
				end
			else
				if D.status == RUNE_STATUS_AVAILABLE then
					if a.IsEnemyPickRune(D.location) then
						return give(BOT_MODE_DESIRE_NONE, "enemy-closer")
					end
					local H = D.type
					local desire
					if H == RUNE_WATER and (g or i < 0.6 or j < 0.5) then
						desire = a.GetScaledDesire(BOT_MODE_DESIRE_HIGH, D.distance, 3200)
					elseif H == RUNE_WATER and not g then
						desire = a.GetScaledDesire(BOT_MODE_DESIRE_HIGH, D.distance, C)
					else
						local I = n == LANE_MID and b.IsInLaningPhase()
						if g or not b.IsEarlyGame() and k <= 3 then
							local J = I and BOT_MODE_DESIRE_VERYHIGH or BOT_MODE_DESIRE_HIGH
							desire = a.GetScaledDesire(J, D.distance, C * 2.5)
						else
							desire = a.GetScaledDesire(BOT_MODE_DESIRE_HIGH, D.distance, C * 2.5)
						end
					end
					-- Starting river gold/bounty sits on power-rune spots — gate early lane oscillation.
					return give(a.ApplyEarlyLaneRuneGate(desire, D.distance, D.status, "power"))
				elseif D.status == RUNE_STATUS_UNKNOWN and DotaTime() > 113 then
					if g or not b.IsEarlyGame() and k <= 3 then
						return give(a.GetScaledDesire(BOT_MODE_DESIRE_HIGH, D.distance, C * 2.5), "power-unknown")
					else
						return give(a.GetScaledDesire(BOT_MODE_DESIRE_HIGH, D.distance, C), "power-unknown")
					end
				elseif D.status == RUNE_STATUS_MISSING and DotaTime() > 60 and (e % 2 == 1 and f > 53) then
					return give(a.GetScaledDesire(BOT_MODE_DESIRE_HIGH, D.distance, C), "power-missing")
				elseif
					D.status == RUNE_STATUS_UNKNOWN
					and a.IsTeamMustSaveRune(D.location)
					and DotaTime() > 113
					and D.distance <= C * 2
				then
					return give(a.GetScaledDesire(BOT_MODE_DESIRE_HIGH, D.distance, C * 2), "power-save")
				end
			end
			return give(BOT_MODE_DESIRE_NONE, "status-" .. StatusTag(D.status))
		end
		return give(BOT_MODE_DESIRE_NONE, "no-best")
	end
	return give(BOT_MODE_DESIRE_NONE, "no-rune")
end
local K = nil
function OnStart()
	local L = d:FindItemSlot("item_bottle")
	if d:GetItemSlotType(L) == ITEM_SLOT_TYPE_MAIN then
		K = d:GetItemInSlot(L)
	end
end
function OnEnd()
	K = nil
end
local M = -math.huge
function Think()
	d._runeDo = "fall"
	if d:IsInvulnerable() and d:DistanceFromFountain() < 500 then
		d:Action_MoveToLocation(d:GetLocation() + RandomVector(500))
		doing("fountain")
		return
	end
	if b.CanNotUseAction(d) then
		doing("cant-act")
		return
	end
	-- Opening buys go to the stash once the hero has left the shop. Stay until they
	-- are in the bag, and walk back if something was stashed anyway.
	if DotaTime() < 20 and d:GetStashValue() > 0 and d:DistanceFromFountain() > 500 then
		d:Action_MoveToLocation(b.GetTeamFountain())
		doing("stash-back")
		return
	end
	if DotaTime() < -70 and d._openingShopDone ~= true and d:DistanceFromFountain() < 2200 then
		if d:DistanceFromFountain() > 350 then
			d:Action_MoveToLocation(b.GetTeamFountain())
		end
		doing("pre-shop")
		return
	end
	if a.ThinkBountySweep() then
		return
	end
	-- A pickup order that never lands (knockback, stun, river edge) must be reissued.
	if d:GetCurrentActionType() == BOT_ACTION_TYPE_PICK_UP_RUNE then
		if d._runePickupAt ~= nil and DotaTime() - d._runePickupAt < 0.6 then
			doing("pickup-wait")
			return
		end
	end
	-- Lotus / wisdom shrine fallback (same gather logic as dedicated modes).
	if d._mapObjKind ~= nil and d._mapObjLoc ~= nil then
		local MapObj = require(GetScriptDirectory() .. "/FuncLib/systems/map_objectives")
		MapObj.ThinkObjective(d, d._mapObjLoc, d._mapObjKind)
		doing("mapobj-" .. tostring(d._mapObjKind))
		return
	end
	if DotaTime() < 0 then
		if b.IsModeTurbo() and DotaTime() < -50 then
			doing("pre-wait")
			return
		end
		local N = d:GetNearbyHeroes(1200, true, BOT_MODE_NONE)
		local O = d:GetNearbyHeroes(1200, false, BOT_MODE_NONE)
		if #N > #O and #N >= 2 then
			local P = GetLaneFrontLocation(GetTeam(), n or d:GetAssignedLane(), -1500)
			d:Action_MoveToLocation(P)
			doing("pre-flee")
			return
		end
		if DotaTime() < -10 then
			local Q = a.GetGoOutLocation()
			if GetUnitToLocationDistance(d, Q) > 300 then
				d:Action_MoveToLocation(Q)
				doing("pre-out")
				return
			else
				if DotaTime() >= M then
					d:Action_MoveToLocation(Q + RandomVector(150))
					M = DotaTime() + RandomFloat(1, 3)
					doing("pre-hold")
					return
				end
			end
			doing("pre-hold")
			return
		end
		if GetTeam() == TEAM_RADIANT then
			if n == LANE_BOT then
				d:Action_MoveToLocation(GetRuneSpawnLocation(RUNE_BOUNTY_2) + RandomVector(50))
				doing("pre-bounty2")
				return
			else
				d:Action_MoveToLocation(GetRuneSpawnLocation(RUNE_POWERUP_1) + RandomVector(50))
				doing("pre-power1")
				return
			end
		else
			if n == LANE_TOP then
				d:Action_MoveToLocation(GetRuneSpawnLocation(RUNE_BOUNTY_1) + RandomVector(50))
				doing("pre-bounty1")
				return
			else
				d:Action_MoveToLocation(GetRuneSpawnLocation(RUNE_POWERUP_2) + RandomVector(50))
				doing("pre-power2")
				return
			end
		end
	end
	if d.rune and d.rune.normal then
		local R = math.min(d:GetAttackRange() + 150, 1200)
		local S = b.GetEnemiesNearLoc(d:GetLocation(), R)
		local T = d:GetNearbyCreeps(R, true)
		local D = d.rune.normal
		local E = GetRuneSpawnLocation(D.location)
		local liveDist = GetUnitToLocationDistance(d, E)
		local U = D.location == RUNE_POWERUP_1 or D.location == RUNE_POWERUP_2
		if
			U
			and DotaTime() >= 60
			and DotaTime() < 7 * 60
			and D.status ~= RUNE_STATUS_AVAILABLE
			and not IsLocationVisible(E)
		then
			if GetUnitToLocationDistance(d, E) > 50 then
				d:Action_MoveToLocation(E)
				doing("move-unseen")
				return
			end
		end
		-- Don't chase heroes into enemy tower after gold/power rune bait.
		local function CanHarassNearRune(enemy)
			if not b.IsValidHero(enemy) or i <= 0.35 then
				return false
			end
			local towers = d:GetNearbyTowers(1000, true)
			if b.IsValidBuilding(towers[1]) then
				local tr = (towers[1]:GetAttackRange() or 700) + 200
				if GetUnitToUnitDistance(d, towers[1]) < tr then
					return false
				end
				if GetUnitToUnitDistance(enemy, towers[1]) < tr + 100 then
					-- Only finish if we can kill them before tower melts us.
					if not b.CanKillTarget(enemy, d:GetAttackDamage() * 2.0, DAMAGE_TYPE_PHYSICAL) then
						return false
					end
				end
			end
			local myDmg = d:GetEstimatedDamageToTarget(false, enemy, 5.0, DAMAGE_TYPE_ALL)
			local theirDmg = enemy:GetEstimatedDamageToTarget(true, d, 5.0, DAMAGE_TYPE_ALL)
			return 1.5 * myDmg > theirDmg
		end
		if D.status == RUNE_STATUS_AVAILABLE then
			-- Pickup from the bank does not collect a river rune. Walk onto the point.
			-- If that walk makes no progress, leave so the lane is not abandoned.
			if liveDist > 130 then
				if liveDist <= 900 and a.RuneReachFailed(D.location, liveDist) then
					a.SkipRune(D.location, 25)
					local lane = n or d:GetAssignedLane()
					d:Action_MoveToLocation(GetLaneFrontLocation(GetTeam(), lane, -600))
					doing("give-up")
					return
				end
				if K and b.CanCastAbility(K) and liveDist < 1200 then
					local V = K:GetCurrentCharges()
					if V > 0 and (i ~= 1 or j ~= 1) then
						d:Action_UseAbility(K)
						doing("bottle")
						return
					end
				end
				if liveDist > 900 then
					for F, W in pairs(S) do
						if CanHarassNearRune(W) then
							d:Action_AttackUnit(W, true)
							doing("harass")
							return
						end
					end
					if
						b.IsValid(T[1])
						and b.CanBeAttacked(T[1])
						and b.CanKillTarget(T[1], d:GetAttackDamage(), DAMAGE_TYPE_PHYSICAL)
					then
						d:Action_AttackUnit(T[1], true)
						doing("lasthit")
						return
					end
				end
				d:Action_MoveToLocation(E)
				doing("move-on")
				return
			end
			d._runeReach = nil
			d._runePickupAt = DotaTime()
			a.NoteBountyGrab(D.location)
			a.NoteLaneRuneTake(D.location)
			d:Action_PickUpRune(D.location)
			doing("pickup")
			return
		else
			if liveDist > 500 then
				for F, W in pairs(S) do
					if CanHarassNearRune(W) then
						d:Action_AttackUnit(W, true)
						doing("harass")
						return
					end
				end
				if
					b.IsValid(T[1])
					and b.CanBeAttacked(T[1])
					and b.CanKillTarget(T[1], d:GetAttackDamage(), DAMAGE_TYPE_PHYSICAL)
				then
					d:Action_AttackUnit(T[1], true)
					doing("lasthit")
					return
				end
			end
			local step = math.max(0, liveDist - 280)
			local stand = b.Site.GetXUnitsTowardsLocation(d, E, step) or E
			d.rune.location = stand
			d:Action_MoveToLocation(stand)
			doing("move-down")
			return
		end
	end
	doing("no-target")
end
function a.InitRune()
	if d.rune == nil then
		d.rune =
			{ normal = { time = 0, type = nil, location = nil, distance = 0, status = RUNE_STATUS_MISSING }, location = nil }
	end
end
-- Bounty runes never despawn. A new one spawns beside the old one, but the bot API
-- still has a single id for that jungle spot. PickUpRune takes the one on the point
-- and then reports the spot missing, so the older rune is left unless we walk onto it.
local BOUNTY_SWEEP = {
	Vector(160, 0, 0),
	Vector(113, 113, 0),
	Vector(0, 160, 0),
	Vector(-113, 113, 0),
	Vector(-160, 0, 0),
	Vector(-113, -113, 0),
	Vector(0, -160, 0),
	Vector(113, -113, 0),
}
function a.NoteBountyGrab(runeId)
	if runeId ~= RUNE_BOUNTY_1 and runeId ~= RUNE_BOUNTY_2 then
		return
	end
	local now = DotaTime()
	local s = d._bountySweep
	if s == nil or s.id ~= runeId or (s.sweepUntil ~= nil and now > s.sweepUntil) then
		d._bountySweep = { id = runeId, seen = now }
		return
	end
	if s.sweepUntil == nil then
		s.seen = now
	end
end
function a.BountySweepState()
	local s = d._bountySweep
	if s == nil then
		return nil
	end
	local now = DotaTime()
	if s.sweepUntil ~= nil and now > s.sweepUntil then
		d._bountySweep = nil
		return nil
	end
	local loc = GetRuneSpawnLocation(s.id)
	local dist = GetUnitToLocationDistance(d, loc)
	local status = GetRuneStatus(s.id)
	if s.sweepUntil == nil then
		-- Still walking up to the registered rune. The ring starts once that one is gone.
		if status == RUNE_STATUS_AVAILABLE then
			if now - s.seen > 1.5 then
				d._bountySweep = nil
			end
			return nil
		end
		if dist > 900 then
			if now - s.seen > 1.5 then
				d._bountySweep = nil
			end
			return nil
		end
		s.sweepUntil = now + 2.4
		s.ringStart = now
	end
	if dist > 900 then
		return nil
	end
	return s, loc, dist, status
end
function a.BountySweepDesire()
	local s, loc, dist, status = a.BountySweepState()
	if s == nil then
		return nil
	end
	local D = d.rune.normal
	D.location = s.id
	D.distance = dist
	D.status = status
	D.type = RUNE_BOUNTY
	return BOT_MODE_DESIRE_ABSOLUTE
end
function a.ThinkBountySweep()
	local s, loc = a.BountySweepState()
	if s == nil then
		return false
	end
	local idx = math.floor((DotaTime() - s.ringStart) / 0.3) % #BOUNTY_SWEEP + 1
	local dest = loc + BOUNTY_SWEEP[idx]
	if GetUnitToLocationDistance(d, dest) <= 50 then
		d._runePickupAt = DotaTime()
		a.NoteLaneRuneTake(s.id)
		d:Action_PickUpRune(s.id)
		doing("sweep-pick")
		return true
	end
	d:Action_MoveToLocation(dest)
	doing("sweep")
	return true
end
function a.SkipRune(id, seconds)
	d._runeSkip = d._runeSkip or {}
	d._runeSkip[id] = DotaTime() + (seconds or 25)
	d._earlyRuneCommit = nil
	d._runeReach = nil
end
function a.RuneSkipped(id)
	local untilAt = d._runeSkip and d._runeSkip[id]
	return untilAt ~= nil and DotaTime() < untilAt
end
function a.RuneReachFailed(id, dist)
	local now = DotaTime()
	local s = d._runeReach
	if s == nil or s.id ~= id then
		d._runeReach = { id = id, since = now, best = dist }
		return false
	end
	if dist + 30 < s.best then
		s.best = dist
		s.since = now
		return false
	end
	local limit = 4
	local loc = GetRuneSpawnLocation(id)
	local mine = GetUnitToLocationDistance(d, loc)
	for u = 1, 5 do
		local v = GetTeamMember(u)
		if b.IsValidHero(v) and v ~= d and v:IsAlive() and GetUnitToLocationDistance(v, loc) + 80 < mine then
			limit = 2
			break
		end
	end
	return now - s.since >= limit
end
function a.ClosestAvailableRune(maxDist)
	local best, bestDist = nil, maxDist or 700
	local t = DotaTime()
	for _, rune in pairs(h) do
		-- Bounty runes spawn every 3 minutes and report missing until the bot has vision.
		local bountyDue = (rune == RUNE_BOUNTY_1 or rune == RUNE_BOUNTY_2) and t >= 170 and t % 180 <= 50
		if GetRuneStatus(rune) == RUNE_STATUS_AVAILABLE or (bountyDue and GetRuneStatus(rune) ~= RUNE_STATUS_MISSING) then
			if a.RuneSkipped(rune) then
				goto continue_rune
			end
			local dist = GetUnitToLocationDistance(d, GetRuneSpawnLocation(rune))
			if dist < bestDist then
				best = rune
				bestDist = dist
			end
		end
		::continue_rune::
	end
	return best, bestDist
end
function a.IsSuitableToPickRune()
	if a.IsNearRune(d, 550) then
		return true
	end
	local E = GetRuneSpawnLocation(d.rune.normal.location)
	if
		b.IsRetreating(d) and m > BOT_MODE_DESIRE_HIGH
		or #p >= 1 and #b.GetHeroesTargetingUnit(p, d) > 0
		or d:WasRecentlyDamagedByAnyHero(5.0) and b.IsRetreating(d)
		or GetUnitToUnitDistance(d, GetAncient(GetTeam())) < 2500 and DotaTime() > 0
		or GetUnitToUnitDistance(d, GetAncient(GetOpposingTeam())) < 4000
		or d:HasModifier("modifier_item_shadow_amulet_fade")
	then
		return false
	end
	return true
end
function a.IsNearRune(X, Y)
	Y = Y or 600
	for F, D in pairs(h) do
		local E = GetRuneSpawnLocation(D)
		if GetUnitToLocationDistance(X, E) <= Y then
			return true
		end
	end
	return false
end
function a.NoteLaneRuneTake(id)
	if DotaTime() >= 6 * 60 then
		return
	end
	d._laneRuneTaken = { id = id, untilAt = DotaTime() + 25 }
end
function a.SkipSecondLaningRune(id)
	local taken = d._laneRuneTaken
	if taken == nil or DotaTime() >= 6 * 60 or DotaTime() > taken.untilAt then
		return false
	end
	return id ~= taken.id
end
-- After the horn, the river spot is the mid's. 0:00 gold and 2:00 water share it,
-- and a sidelaner who stays there picks up both.
function a.SidelaneSkipsRiver(id, dist)
	if id ~= RUNE_POWERUP_1 and id ~= RUNE_POWERUP_2 then
		return false
	end
	local t = DotaTime()
	if t < 50 or t >= 6 * 60 then
		return false
	end
	if k == 2 then
		return false
	end
	return (dist or 99999) > 160
end
function a.GetBestRune()
	e = math.floor(DotaTime() / 60)
	f = DotaTime() % 60
	local Z = -1
	local _ = math.huge
	for F, D in pairs(h) do
		local E = GetRuneSpawnLocation(D)
		if
			a.IsTheClosestAlly(d, E)
			and not a.IsPingedByHumanPlayer(E, math.huge)
			and not r(D)
			and not a.RuneSkipped(D)
			and not a.IsMissing(D)
		then
			-- The horn gold on power-rune spots is for whoever stands closest. Leaving it to a
			-- nearby core stalled both, since the core is not the closest ally.
			local hornGold = DotaTime() < 70
			local dist = GetUnitToLocationDistance(d, E)
			if a.SidelaneSkipsRiver(D, dist) or a.SkipSecondLaningRune(D) then
				-- River gold at 0:00 and water at 2:00 share this spot. One mid trip.
			elseif D == RUNE_BOUNTY_1 or D == RUNE_BOUNTY_2 or hornGold or (b.IsCore(d) or not b.IsThereCoreNearby(1200)) then
				local a0 = dist
				if a0 < _ then
					Z = D
					_ = a0
				end
			end
		end
	end
	return Z, _
end
function a.IsTheClosestAlly(X, Q)
	local a1 = X
	local a2 = GetUnitToLocationDistance(X, Q)
	for u = 1, 5 do
		local v = GetTeamMember(u)
		if b.IsValidHero(v) then
			local a3 = GetUnitToLocationDistance(v, Q)
			if a3 < a2 then
				a1 = v
				a2 = a3
			end
		end
	end
	-- Keep claim while committed so a slightly closer ally doesn't flip us back to lane.
	if a1 ~= X and X._earlyRuneCommit and GetUnitToLocationDistance(X, Q) <= 1900 then
		return true
	end
	return a1 == X
end
function a.IsThereAllyWithBottle(Q, Y)
	for u = 1, 5 do
		local v = GetTeamMember(u)
		if
			b.IsValidHero(v)
			and v ~= d
			and GetUnitToLocationDistance(v, Q) <= Y
			and v:FindItemSlot("item_bottle") >= 0
		then
			return true
		end
	end
	return false
end
function a.IsTherePosition(a4, a5, Y)
	local E = GetRuneSpawnLocation(a5)
	for u = 1, 5 do
		local v = GetTeamMember(u)
		if b.IsValidHero(v) and b.GetPosition(v) == a4 and d ~= v then
			local a6 = GetUnitToLocationDistance(d, E)
			local a7 = GetUnitToLocationDistance(v, E)
			if a6 <= Y and a7 <= Y then
				return true
			end
		end
	end
	return false
end
local a8 = 30
function a.IsPingedByHumanPlayer(Q, Y)
	for u = 1, 5 do
		local v = GetTeamMember(u)
		if b.IsValidHero(v) and not v:IsBot() and GetUnitToLocationDistance(v, Q) <= Y then
			local w = v:GetMostRecentPing()
			if w then
				if not w.normal_ping and b.GetDistance(w.location, Q) <= 800 and GameTime() - w.time < a8 then
					return true
				end
			end
		end
	end
	return false
end
function a.IsPowerRune(a5)
	local H = GetRuneType(a5)
	if
		H == RUNE_DOUBLEDAMAGE
		or H == RUNE_HASTE
		or H == RUNE_ILLUSION
		or H == RUNE_INVISIBILITY
		or H == RUNE_REGENERATION
		or H == RUNE_ARCANE
		or H == RUNE_SHIELD
	then
		return true
	end
	return false
end
function a.IsMissing(s)
	if f < 52 and GetRuneStatus(s) == RUNE_STATUS_MISSING then
		return true
	end
	return false
end
function a.IsEnemyPickRune(s)
	local E = GetRuneSpawnLocation(s)
	if GetUnitToLocationDistance(d, E) < 600 then
		return false
	end
	for F, a9 in pairs(p) do
		if
			b.IsValidHero(a9)
			and not b.IsSuspiciousIllusion(a9)
			and (a9:IsFacingLocation(E, 30) or GetUnitToLocationDistance(a9, E) < 600)
			and GetUnitToLocationDistance(a9, E) < GetUnitToLocationDistance(d, E) + 300
		then
			return true
		end
	end
	return false
end
function a.IsUnitAroundLocation(aa, Y)
	for F, ab in pairs(GetTeamPlayers(GetOpposingTeam())) do
		if IsHeroAlive(ab) then
			local ac = GetHeroLastSeenInfo(ab)
			if ac ~= nil then
				local ad = ac[1]
				if ad ~= nil and b.GetDistance(aa, ad.location) <= Y and ad.time_since_seen < 1.0 then
					return true
				end
			end
		end
	end
	return false
end
function a.GetScaledDesire(ae, af, ag)
	local ah = 0.92
	if af > 2000 and (b.IsLateGame() or b.GetDistanceFromEnemyFountain(d) < 5500) then
		ah = 0.55
	elseif af > 1200 then
		ah = 0.85
	end
	local ai = b.GetHP(d)
	local aj = Clamp(ae * RemapValClamped(af, 0, ag, 1, 0.5), 0, ah)
	if ai < 0.6 then
		aj = RemapValClamped(ai, 0, 0.8, 0, aj)
	end
	return aj
end
-- A rune underfoot must beat laning (cores sit at ~0.57, last-hit at 0.6).
function a.DesireForNearbyRune(desire, dist, status)
	if status == RUNE_STATUS_AVAILABLE and type(dist) == "number" and dist <= 800 then
		return math.max(desire or 0, BOT_MODE_DESIRE_ABSOLUTE)
	end
	return desire
end
-- After creeps spawn, laning desire (~0.45) fights scaled rune desire and bots oscillate
-- lane ↔ river gold/bounty. Only start a pickup when already close; once committed, stick.
function a.ApplyEarlyLaneRuneGate(desire, dist, status, tag)
	tag = tag or "gate"
	if desire == nil or desire <= 0 then
		runeWhy = tag .. "-zero"
		return desire or 0
	end
	local t = DotaTime()
	if t <= 0 or t >= 70 then
		d._earlyRuneCommit = nil
		runeWhy = tag .. "-open"
		return desire
	end
	if status ~= RUNE_STATUS_AVAILABLE then
		d._earlyRuneCommit = nil
		runeWhy = tag .. "-not-up"
		return BOT_MODE_DESIRE_NONE
	end
	dist = dist or 99999
	local startDist = 1050
	local stickDist = 1900
	if dist > stickDist then
		d._earlyRuneCommit = nil
		runeWhy = tag .. "-far"
		return BOT_MODE_DESIRE_NONE
	end
	if (l == BOT_MODE_RUNE or d._earlyRuneCommit) and dist <= stickDist then
		d._earlyRuneCommit = true
		runeWhy = tag .. "-stick"
		return math.max(desire, BOT_MODE_DESIRE_HIGH)
	end
	if dist > startDist then
		runeWhy = tag .. "-wait"
		return BOT_MODE_DESIRE_NONE
	end
	d._earlyRuneCommit = true
	runeWhy = tag .. "-go"
	return math.max(desire, BOT_MODE_DESIRE_HIGH)
end
local ak = nil
function a.GetGoOutLocation()
	if ak then
		return ak
	end
	if GetTeam() == TEAM_RADIANT then
		if k == 1 or k == 5 then
			local al = { Vector(526.370239, -3893.405762, 256.000000), Vector(1999.415894, -4838.790039, 256.000000) }
			ak = al[RandomInt(1, #al)]
		elseif k == 2 or k == 3 or k == 4 then
			local al = { Vector(-3456.702637, 649.725403, 256.000000), Vector(-1945.830322, 60.404663, 128.000000) }
			ak = al[RandomInt(1, #al)]
		end
	elseif GetTeam() == TEAM_DIRE then
		if k == 1 or k == 5 then
			local al = { Vector(-1051.021973, 3384.059082, 256.000000), Vector(-2415.422119, 4641.448242, 256.000000) }
			ak = al[RandomInt(1, #al)]
		elseif k == 2 or k == 3 or k == 4 then
			local al = { Vector(2734.819580, -1155.105225, 256.000000), Vector(1142.979614, -337.891663, 128.000000) }
			ak = al[RandomInt(1, #al)]
		end
	end
	return ak
end
function a.CouldBlink(Q)
	local am = d:FindItemSlot("item_blink")
	if
		d:GetItemSlotType(am) == ITEM_SLOT_TYPE_MAIN
		or (d:GetUnitName() == "npc_dota_hero_antimage" or d:GetUnitName() == "npc_dota_hero_queenofpain")
	then
		local an = d:GetItemInSlot(am)
		if d:GetUnitName() == "npc_dota_hero_antimage" then
			an = d:GetAbilityByName("antimage_blink")
		end
		if d:GetUnitName() == "npc_dota_hero_queenofpain" then
			an = d:GetAbilityByName("queenofpain_blink")
		end
		if b.CanCastAbility(an) then
			local ao = GetUnitToLocationDistance(d, Q)
			local ap = b.Site.GetXUnitsTowardsLocation(d, Q, 1199)
			if ao <= 500 then
				return false
			elseif ao < 1200 then
				d:Action_UseAbilityOnLocation(an, Q)
				return true
			elseif IsLocationPassable(ap) then
				d:Action_UseAbilityOnLocation(an, ap)
				return true
			end
		end
	end
	return false
end
function a.IsTeamMustSaveRune(s)
	if GetTeam() == TEAM_DIRE then
		return s == RUNE_BOUNTY_1
			or s == RUNE_POWERUP_2
			or DotaTime() > 1 * 60 + 45 and s == RUNE_POWERUP_1
			or DotaTime() > 10 * 60 + 45 and s == RUNE_BOUNTY_2
	else
		return s == RUNE_BOUNTY_2
			or s == RUNE_POWERUP_1
			or DotaTime() > 1 * 60 + 45 and s == RUNE_POWERUP_2
			or DotaTime() > 10 * 60 + 45 and s == RUNE_BOUNTY_1
	end
end
function a.IsHumanDangerPingedRune(s)
	local t = GetRuneSpawnLocation(s)
	for u = 1, #GetTeamPlayers(GetTeam()) do
		local v = GetTeamMember(u)
		if v ~= nil and v:IsAlive() and not v:IsBot() then
			local w = v:GetMostRecentPing()
			if w ~= nil and not w.normal_ping and b.GetDistance(w.location, t) <= 400 and GameTime() - w.time < 30 then
				return true
			end
		end
	end
	return false
end
function a.IsAllyWithBottleCloser(s)
	local t = GetRuneSpawnLocation(s)
	local aq = GetUnitToLocationDistance(d, t)
	for u = 1, #GetTeamPlayers(GetTeam()) do
		local v = GetTeamMember(u)
		if
			v ~= nil
			and v ~= d
			and b.IsValidHero(v)
			and v:FindItemSlot("item_bottle") >= 0
			and GetUnitToLocationDistance(v, t) < aq
		then
			return true
		end
	end
	return false
end
function a.ShouldCheckRuneStatus(s)
	local ar = GetRuneStatus(s)
	return ar == RUNE_STATUS_AVAILABLE or ar == RUNE_STATUS_UNKNOWN
end
function a.GetLaningRuneDesire(z)
	local as = math.floor(DotaTime() / 60)
	local at = DotaTime() % 60
	local au = DotaTime() < 6 * 60 and (as % 2 == 1 and at >= 55 or as % 2 == 0 and at <= 5)
	if au then
		local av = { RUNE_POWERUP_1, RUNE_POWERUP_2 }
		local aw = nil
		local awStatus = nil
		local ax = z
		for F, D in pairs(av) do
			if k ~= 2 or a.SkipSecondLaningRune(D) then
				goto continue_power
			end
			local ay = GetRuneStatus(D)
			if
				(ay == RUNE_STATUS_AVAILABLE or ay == RUNE_STATUS_UNKNOWN)
				and not a.IsHumanDangerPingedRune(D)
				and not a.IsAllyWithBottleCloser(D)
			then
				local a0 = GetUnitToLocationDistance(d, GetRuneSpawnLocation(D))
				if a0 < ax then
					aw = D
					ax = a0
					awStatus = ay
				end
			end
			::continue_power::
		end
		if aw ~= nil then
			if d.rune and d.rune.normal then
				d.rune.normal.location = aw
				d.rune.normal.distance = ax
				d.rune.normal.status = GetRuneStatus(aw)
				d.rune.normal.type = GetRuneType(aw)
			end
			return a.DesireForNearbyRune(a.GetScaledDesire(BOT_MODE_DESIRE_HIGH, ax, 3200), ax, awStatus)
		end
	end
	if k >= 4 then
		local az = GetTeam()
		local aA = nil
		if az == TEAM_RADIANT and k == 4 or az == TEAM_DIRE and k == 5 then
			aA = RUNE_BOUNTY_1
		elseif az == TEAM_RADIANT and k == 5 or az == TEAM_DIRE and k == 4 then
			aA = RUNE_BOUNTY_2
		end
		if aA ~= nil and a.ShouldCheckRuneStatus(aA) and not a.IsHumanDangerPingedRune(aA) and not a.SkipSecondLaningRune(aA) then
			local a0 = GetUnitToLocationDistance(d, GetRuneSpawnLocation(aA))
			if a0 < z then
				if d.rune and d.rune.normal then
					d.rune.normal.location = aA
					d.rune.normal.distance = a0
					d.rune.normal.status = GetRuneStatus(aA)
					d.rune.normal.type = GetRuneType(aA)
				end
				return a.DesireForNearbyRune(
					a.GetScaledDesire(BOT_MODE_DESIRE_VERYHIGH, a0, 3500),
					a0,
					GetRuneStatus(aA)
				)
			end
		end
	end
	local aB = nil
	local aC = z
	local aD = { RUNE_BOUNTY_1, RUNE_BOUNTY_2, RUNE_POWERUP_1, RUNE_POWERUP_2 }
	for F, D in pairs(aD) do
		if a.ShouldCheckRuneStatus(D) and not a.IsHumanDangerPingedRune(D) and not a.IsAllyWithBottleCloser(D) then
			local a0 = GetUnitToLocationDistance(d, GetRuneSpawnLocation(D))
			if not a.SidelaneSkipsRiver(D, a0) and not a.SkipSecondLaningRune(D) and a0 < aC then
				aB = D
				aC = a0
			end
		end
	end
	if aB ~= nil then
		if d.rune and d.rune.normal then
			d.rune.normal.location = aB
			d.rune.normal.distance = aC
			d.rune.normal.status = GetRuneStatus(aB)
			d.rune.normal.type = GetRuneType(aB)
		end
		return a.DesireForNearbyRune(a.GetScaledDesire(BOT_MODE_DESIRE_HIGH, aC, z), aC, GetRuneStatus(aB))
	end
	return 0
end
if SafeCall then
	local aE = GetDesire
	local aF = Think
	if aE then
		GetDesire = SafeCall(aE, 0, "RUNE_GetDesire")
	end
	if aF then
		Think = SafeCall(aF, nil, "RUNE_Think")
	end
end
