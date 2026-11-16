-- Ward mode. Places observer and sentry wards.
if
	GetBot():IsInvulnerable()
	or not GetBot():IsHero()
	or not string.find(GetBot():GetUnitName(), "hero")
	or GetBot():IsIllusion()
then
	return
end
local a = {}
local b = GetBot()
local c = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local d = require(GetScriptDirectory() .. "/FuncLib/systems/ward")
local e = require(GetScriptDirectory() .. "/FuncLib/systems/custom_loader")
local MatchTrace = require(GetScriptDirectory() .. "/FuncLib/systems/match_trace")
local locOk, loc = pcall(require, GetScriptDirectory() .. "/FuncLib/systems/localization")
if not locOk then
	loc = {
		Get = function()
			return nil
		end,
	}
end
e.ThinkLess = e.Enable and e.ThinkLess or 1
local f = 500
local g = 500
local h = nil
local i = nil
local j = nil
local k = -math.huge
local function DispenserSentryCharges(item)
	if item == nil or item.GetSecondaryCharges == nil then
		return 0
	end
	local ok, n = pcall(function()
		return item:GetSecondaryCharges()
	end)
	if ok and type(n) == "number" then
		return n
	end
	return 0
end
local function DispenserHasObservers(item)
	return item ~= nil and (item:GetCurrentCharges() or 0) > 0
end
-- Plant from a Ward Dispenser. Which toggle state means observer is not documented, and the old
-- code toggled whenever the state read false and returned, so the next think could toggle it
-- back: game 014 Lina and game 016 Techies stood on the bottom-rune spot holding a dispenser and
-- never planted. Now: cast, then watch the charges (observers are the current charges, sentries
-- the secondary). The wanted count went down: done. The other one went down: wrong mode, toggle
-- once for next time. Nothing changed for 1s: toggle once and cast again. Returns true when it
-- issued an order or is waiting on one.
local function DispenserPlant(item, loc, wantObs)
	local now = DotaTime()
	local obs = item:GetCurrentCharges() or 0
	local sen = DispenserSentryCharges(item)
	local t = b._dispTry
	if t ~= nil and (t.loc ~= loc or t.wantObs ~= wantObs or now - t.at > 4) then
		t = nil
	end
	if t == nil then
		b._dispTry = { at = now, loc = loc, wantObs = wantObs, obs = obs, sen = sen, toggled = false, castAt = now }
		b:Action_UseAbilityOnLocation(item, loc)
		return true
	end
	local gotWanted = wantObs and obs < t.obs or not wantObs and sen < t.sen
	local gotOther = wantObs and sen < t.sen or not wantObs and obs < t.obs
	if gotWanted then
		b._dispTry = nil
		return false
	end
	if gotOther then
		-- Planted the other kind: switch the dispenser for the next one.
		b._dispTry = nil
		b:Action_UseAbilityOnEntity(item, b)
		pcall(print, string.format("[OHA-WARD] t=%.0f dispenser wrong-mode want=%s toggled", now, wantObs and "obs" or "sentry"))
		return true
	end
	if now - t.castAt >= 1 and not t.toggled then
		t.toggled = true
		t.recast = true
		t.castAt = now + 0.5
		b:Action_UseAbilityOnEntity(item, b)
		return true
	end
	if t.recast and now >= t.castAt then
		t.recast = false
		t.castAt = now
		b:Action_UseAbilityOnLocation(item, loc)
	end
	return true
end
-- Console copy at game end only keeps the tail, and the signout fills most of it.
-- Remember plants during the match and print them once POST_GAME starts.
local planted = {}
local dumped = false
local function PickChat(key, fallback)
	local msg = loc.Get(key)
	if type(msg) == "table" and #msg > 0 then
		return msg[RandomInt(1, #msg)]
	end
	if type(msg) == "string" then
		return msg
	end
	return fallback
end
local function RememberWard(kind)
	if j == nil or j.location == nil then
		return
	end
	local x = math.floor(j.location.x)
	local y = math.floor(j.location.y)
	local now = DotaTime()
	local last = planted[#planted]
	if last and last.kind == kind and last.x == x and last.y == y and now - last.t < 20 then
		return
	end
	planted[#planted + 1] = { t = now, kind = kind, role = j.role or "spot", x = x, y = y }
	if #planted > 40 then
		table.remove(planted, 1)
	end
end
local function DumpWards()
	if dumped or GetGameState() ~= DOTA_GAMERULES_STATE_POST_GAME then
		return
	end
	dumped = true
	local name = string.gsub(b:GetUnitName() or "bot", "npc_dota_hero_", "")
	print(string.format("[OHA-WARD] %s n=%d", name, #planted))
	for idx = 1, #planted do
		local p = planted[idx]
		print(string.format("[OHA-WARD] %s %s t=%.0f role=%s %d,%d", name, p.kind, p.t, p.role, p.x, p.y))
	end
end
local function AnnounceWard(kind)
	RememberWard(kind)
	local role = j and j.role or nil
	local wardLoc = j and j.location or nil
	MatchTrace.Item(
		b,
		kind == "sentry" and "item_ward_sentry" or "item_ward_observer",
		"plant",
		string.format(
			"role=%s xy=%s",
			tostring(role or "?"),
			wardLoc and string.format("%d,%d", math.floor(wardLoc.x), math.floor(wardLoc.y)) or "?"
		)
	)
	-- No ping and no team chat on a plant any more: warding is proven to work (user request).
	if true then
		return
	end
	c.Utils.GameStates = c.Utils.GameStates or {}
	-- Bot API has no "Enemy Ward Here" wheel ping — danger ping (X) is the closest mark.
	if kind == "sentry" and wardLoc ~= nil then
		if DotaTime() - (c.Utils.GameStates.wardPingTime or -100) >= 8 then
			c.Utils.GameStates.wardPingTime = DotaTime()
			b:ActionImmediate_Ping(wardLoc.x, wardLoc.y, false)
		end
	end
	if DotaTime() - (c.Utils.GameStates.wardChatTime or -100) < 12 then
		return
	end
	c.Utils.GameStates.wardChatTime = DotaTime()
	local key = kind == "sentry" and "say_ward_sentry" or "say_ward_observer"
	if role == "defend" then
		key = kind == "sentry" and "say_ward_sentry_defend" or "say_ward_observer_defend"
	elseif role == "offense" then
		key = kind == "sentry" and "say_ward_sentry_offense" or "say_ward_observer_offense"
	end
	local text = PickChat(key, kind == "sentry" and "Planting sentry." or "Planting observer.")
	b:ActionImmediate_Chat(text, false)
	if c.Utils.DebugMode or c.Utils.GameStates.verboseChat then
		local extra = string.format(
			"[debug] ward %s role=%s at (%.0f, %.0f)",
			kind,
			tostring(role or "n/a"),
			j and j.location.x or 0,
			j and j.location.y or 0
		)
		b:ActionImmediate_Chat(extra, false)
	end
end
function GetDesire()
	DumpWards()
	if ShouldSkipBotThink(GetBot()) then
		return 0
	end
	if c.GetPosition(b) <= 3 then
		return false
	end
	local l = GetDesireHelper()
	return RemapValClamped(c.GetHP(b) * l, 0, 1, BOT_MODE_DESIRE_NONE, l)
end
function GetDesireHelper()
	if not a.IsSuitableToWard() then
		return BOT_MODE_DESIRE_NONE
	end
	-- One early ward (user call). Game 030, -0:17: right after Techies planted the Dire mid ward,
	-- ward mode started a second early trip across the top river and he ended up fighting at the
	-- top rune. No more ward trips until 0:20.
	if b._earlyWardPlantedAt ~= nil and DotaTime() < 20 then
		return BOT_MODE_DESIRE_NONE
	end
	if c.Utils.IsTeamPushingSecondTierOrHighGround(b) then
		return BOT_MODE_DESIRE_NONE
	end
	local m = c.Utils.CountEnemyHeroesNear(GetAncient(GetTeam()):GetLocation(), 3200)
	if m >= 1 then
		return BOT_MODE_DESIRE_NONE
	end
	local n = c.Utils.CountEnemyHeroesOnHighGround(GetTeam()) >= 2
	h = nil
	i = nil
	local I = false
	local J = false
	-- Main inventory first, then backpack (human-gifted wards often land in bag).
	for o = 0, 8 do
		local p = b:GetItemInSlot(o)
		if p then
			local q = p:GetName()
			-- A dispenser with only sentries is not an observer. Toggling it
			-- toward observer mode puts the sentry on cooldown.
			local dispenserObs = q == "item_ward_dispenser" and DispenserHasObservers(p)
			local dispenserSen = q == "item_ward_dispenser" and DispenserSentryCharges(p) > 0
			if not I and (q == "item_ward_observer" or dispenserObs) then
				h = p
				I = o <= 5
			end
			if not J and (q == "item_ward_sentry" or dispenserSen) then
				i = p
				J = o <= 5
			end
		end
	end
	-- Enter ward mode even if wards are still in backpack so purchase can promote them.
	-- Before the horn the observer is pos 5's (user call).
	if h ~= nil and DotaTime() < 0 and c.GetPosition(b) ~= 5 then
		h = nil
	end
	if h ~= nil and (I and c.CanCastAbility(h) or not I) then
		local r = d.GetAvailabeObserverWardSpots(b)
		j = d.GetClosestObserverWardSpot(b, r)
		if j and (not a.IsEnemyCloserToWardLocation(j.location) or c.IsRealInvisible(b)) then
			local s = n and not a.IsWardSpotDefensiveOrNearby(j.location)
			if s then
			elseif DotaTime() > 0 and GetUnitToLocationDistance(b, j.location) > d.WalkLimit(j) then
			elseif DotaTime() < 0 and DotaTime() > (c.IsModeTurbo() and -45 or -60) then
				return BOT_MODE_DESIRE_ABSOLUTE
			elseif DotaTime() > k + 1.0 then
				return BOT_MODE_DESIRE_VERYHIGH
			end
		end
	end
	if i ~= nil and (J and c.CanCastAbility(i) or not J) then
		local t = d.GetPossibleSentryWardSpots(b)
		j = d.GetClosestSentryWardSpot(b, t)
		if j and (not a.IsEnemyCloserToWardLocation(j.location) or c.IsRealInvisible(b)) then
			local s = n and not a.IsWardSpotDefensiveOrNearby(j.location)
			if s then
			elseif DotaTime() > 0 and GetUnitToLocationDistance(b, j.location) > d.WalkLimit(j) then
			elseif DotaTime() > k + 1.0 then
				return BOT_MODE_DESIRE_VERYHIGH
			end
		end
	end
	return BOT_MODE_DESIRE_NONE
end
-- Give up a ward spot that is not working: standing in range of it for 5s without planting, or
-- nothing to do with it for 3s (ward not castable). Game 014: Dire Lina stood 73 from her spot
-- (123,-1118) from 0:02 to 0:48. The spot is marked planted (skipped for 6 min) and ward mode
-- stays off for 15s.
-- Plant debugging. WardCharges: observers and sentries the bot holds (dispenser: current =
-- observers, secondary = sentries). LogPlantTry: each cast order at a spot (every 1s at most)
-- with distance, whether the spot and the bot's spot are walkable, and the charges.
-- WatchPlant: when the charges go down after a try, [OHA-WARD] planted ... (the try worked).
local function WardCharges()
	local obs, sen = 0, 0
	for slot = 0, 8 do
		local it = b:GetItemInSlot(slot)
		if it ~= nil then
			local n0 = it:GetName()
			if n0 == "item_ward_observer" then
				obs = obs + (it:GetCurrentCharges() or 0)
			elseif n0 == "item_ward_sentry" then
				sen = sen + (it:GetCurrentCharges() or 0)
			elseif n0 == "item_ward_dispenser" then
				obs = obs + (it:GetCurrentCharges() or 0)
				sen = sen + DispenserSentryCharges(it)
			end
		end
	end
	return obs, sen
end
-- Plant tries are no longer printed (ward planting works); kept as a no-op for the call sites.
local function LogPlantTry(kind, item, loc)
	if true then
		return
	end
	local now = DotaTime()
	local obs, sen = WardCharges()
	b._wardTry = { at = now, kind = kind, loc = loc, obs = obs, sen = sen }
	if now < (b._wardTryLogAt or -999) then
		return
	end
	b._wardTryLogAt = now + 1
	local me = b:GetLocation()
	pcall(print, string.format(
		"[OHA-WARD] t=%.0f %s plant-try %s item=%s spot=%.0f,%.0f dist=%d spotPassable=%s me=%.0f,%.0f obs=%d sen=%d",
		now,
		(string.gsub(b:GetUnitName(), "npc_dota_hero_", "")),
		kind,
		item ~= nil and item:GetName() or "?",
		loc.x,
		loc.y,
		GetUnitToLocationDistance(b, loc),
		tostring(IsLocationPassable(loc)),
		me.x,
		me.y,
		obs,
		sen
	))
end
local function WatchPlant()
	local t0 = b._wardTry
	if t0 == nil then
		return
	end
	if DotaTime() - t0.at > 3 then
		b._wardTry = nil
		return
	end
	local obs, sen = WardCharges()
	if obs < t0.obs or sen < t0.sen then
		pcall(print, string.format(
			"[OHA-WARD] t=%.0f %s planted %s at=%.0f,%.0f",
			DotaTime(),
			(string.gsub(b:GetUnitName(), "npc_dota_hero_", "")),
			obs < t0.obs and "observer" or "sentry",
			t0.loc.x,
			t0.loc.y
		))
		b._wardTry = nil
	end
end
local function GiveUpWardSpot(why)
	local now = DotaTime()
	if j ~= nil then
		j.plant_time_obs = now
		j.plant_time_sentry = now
	end
	k = now + 15
	b._wardAtSpotSince = nil
	b._wardIdleSince = nil
	pcall(print, string.format(
		"[OHA-WARD] t=%.0f %s give-up why=%s spot=%s obs=%s sentry=%s",
		now,
		(string.gsub(b:GetUnitName(), "npc_dota_hero_", "")),
		why,
		j ~= nil and string.format("%.0f,%.0f", j.location.x, j.location.y) or "-",
		h ~= nil and string.format("%s/slot%d/%s", h:GetName(), b:FindItemSlot(h:GetName()), tostring(c.CanCastAbility(h))) or "-",
		i ~= nil and string.format("%s/slot%d/%s", i:GetName(), b:FindItemSlot(i:GetName()), tostring(c.CanCastAbility(i))) or "-"
	))
end
function Think()
	if OhaCastGuard ~= nil and OhaCastGuard(GetBot()) then
		return
	end
	DumpWards()
	if c.CanNotUseAction(b) then
		return
	end
	if j and GetUnitToLocationDistance(b, j.location) <= math.max(f, g) then
		b._wardAtSpotSince = b._wardAtSpotSince or DotaTime()
		if DotaTime() - b._wardAtSpotSince >= 5 then
			GiveUpWardSpot("in-range-no-plant")
			return
		end
	else
		b._wardAtSpotSince = nil
	end
	-- No progress toward the spot for 4s (the path keeps turning back): game 031, -0:16 to -0:03,
	-- Techies paced 650-700 from the Dire mid spot in sight of the enemy and drew an attack. Within
	-- 700: plant from here toward it. Farther: give the spot up.
	if j and j.location then
		local now = DotaTime()
		local dist = GetUnitToLocationDistance(b, j.location)
		local pr = b._wardProgress
		if pr == nil or pr.spot ~= j or dist < pr.best - 40 then
			b._wardProgress = { spot = j, best = dist, at = now }
		elseif now - pr.at >= 4 and dist > math.max(f, g) then
			b._wardProgress = nil
			if dist <= 700 and a.PlantShort() then
				return
			end
			GiveUpWardSpot("no-progress")
			return
		end
	end
	a.WardThinkActed = false
	a.WardThink()
	if a.WardThinkActed then
		b._wardIdleSince = nil
	else
		b._wardIdleSince = b._wardIdleSince or DotaTime()
		if DotaTime() - b._wardIdleSince >= 3 then
			GiveUpWardSpot("nothing-to-do")
		end
	end
end
-- A ward spot that is not walkable (cliff edge, tree line) cannot take a ward: the bot stood in
-- range casting and nothing was planted (bottom-rune spot: Lina in game 014, Techies in games
-- 016 and 017 at both the old and the moved coordinates). The first time a spot is used it is
-- checked; if not walkable, the nearest walkable point within 250 replaces it (logged).
local function ValidateSpot(spot)
	if spot == nil or spot._checked then
		return
	end
	spot._checked = true
	local loc = spot.location
	if IsLocationPassable(loc) then
		return
	end
	for r = 50, 250, 50 do
		for k = 0, 11 do
			local ang = k * math.pi / 6
			local p0 = Vector(loc.x + math.cos(ang) * r, loc.y + math.sin(ang) * r, loc.z)
			if IsLocationPassable(p0) then
				pcall(print, string.format(
					"[OHA-WARD] t=%.0f spot-moved from=%.0f,%.0f to=%.0f,%.0f (not walkable)",
					DotaTime(),
					loc.x,
					loc.y,
					p0.x,
					p0.y
				))
				spot.location = p0
				return
			end
		end
	end
	pcall(print, string.format("[OHA-WARD] t=%.0f spot-invalid at=%.0f,%.0f", DotaTime(), loc.x, loc.y))
end
-- An early ward near mid: remember the observer count when the plant is ordered; general roaming
-- walks the bot back behind our mid T1 once the ward is down (count dropped), before it goes to
-- lane (user call: after the mid ward they walked on the river and were exposed).
local function MarkEarlyWard(spot)
	if spot == nil or spot.role ~= "early" or spot.location == nil then
		return
	end
	local t1 = GetTower(GetTeam(), TOWER_MID_1)
	if t1 == nil or GetUnitToLocationDistance(t1, spot.location) > 3000 then
		return
	end
	local p = b._earlyWardPending
	if p ~= nil and DotaTime() - p.at < 4 then
		return
	end
	-- Pos 5 only (user call): after the mid observer he walks to our own jungle's bounty spot
	-- (Radiant's jungle holds the bottom bounty, Dire's the top one), up to 40s. No walk back
	-- behind the mid T1 any more, for anyone.
	if c.GetPosition(b) ~= 5 then
		return
	end
	local obs = WardCharges()
	b._earlyWardPending = {
		at = DotaTime(),
		obs = obs,
		to = GetRuneSpawnLocation(GetTeam() == TEAM_RADIANT and RUNE_BOUNTY_2 or RUNE_BOUNTY_1),
		window = 40,
	}
end
-- Plant the observer from where he stands, as far toward the spot as the cast range allows.
function a.PlantShort()
	if j == nil or h == nil or not c.CanCastAbility(h) then
		return false
	end
	if h:GetName() == "item_ward_dispenser" and not DispenserHasObservers(h) then
		return false
	end
	local loc = c.Utils.GetOffsetLocationTowardsTargetLocation(b:GetLocation(), j.location, f - 30)
	pcall(print, string.format(
		"[OHA-WARD] t=%.0f %s plant-short spot=%.0f,%.0f at=%.0f,%.0f dist=%d",
		DotaTime(),
		(string.gsub(b:GetUnitName(), "npc_dota_hero_", "")),
		j.location.x,
		j.location.y,
		loc.x,
		loc.y,
		GetUnitToLocationDistance(b, j.location)
	))
	pcall(MarkEarlyWard, j)
	if h:GetName() == "item_ward_observer" then
		b:Action_UseAbilityOnLocation(h, loc)
	else
		DispenserPlant(h, loc, true)
	end
	j.plant_time_obs = DotaTime()
	return true
end
function a.WardThink()
	pcall(ValidateSpot, j)
	if j then
		if h and c.CanCastAbility(h) and (h:GetName() ~= "item_ward_dispenser" or DispenserHasObservers(h)) then
			if GetUnitToLocationDistance(b, j.location) <= f then
				if h:GetName() == "item_ward_observer" then
					AnnounceWard("observer")
					a.WardThinkActed = true
					LogPlantTry("observer", h, j.location)
					pcall(MarkEarlyWard, j)
					b:Action_UseAbilityOnLocation(h, j.location)
				else
					a.WardThinkActed = true
					LogPlantTry("observer", h, j.location)
					pcall(MarkEarlyWard, j)
					if DispenserPlant(h, j.location, true) then
						return
					end
					AnnounceWard("observer")
				end
				j.plant_time_obs = DotaTime()
				return
			else
				a.WardThinkActed = true
				b:Action_MoveToLocation(j.location)
				return
			end
		end
		if i and c.CanCastAbility(i) and (i:GetName() ~= "item_ward_dispenser" or DispenserSentryCharges(i) > 0) then
			if GetUnitToLocationDistance(b, j.location) <= g then
				local u = 0
				if d.IsOtherWardClose(j.location, "npc_dota_observer_wards", 300, true, false) then
					u = 30
				end
				-- A dispenser: plant through DispenserPlant (cast, watch the charges, toggle only
				-- when the cast did nothing or planted the wrong kind). The old rule took toggle
				-- state true as observer mode, toggled, waited 0.8s and gave the spot up: game 019,
				-- 14:48-15:26, Techies kept switching a dispenser that held 0 observers and 2
				-- sentries. Which state means which mode is not documented.
				if i:GetName() == "item_ward_dispenser" then
					a.WardThinkActed = true
					LogPlantTry("sentry", i, j.location)
					if DispenserPlant(i, j.location, false) then
						return
					end
					AnnounceWard("sentry")
					j.plant_time_sentry = DotaTime()
					return
				end
				b._wardToggleAt = nil
				AnnounceWard("sentry")
				a.WardThinkActed = true
				LogPlantTry("sentry", i, j.location)
				b:Action_UseAbilityOnLocation(i, j.location + RandomVector(u))
				j.plant_time_sentry = DotaTime()
				return
			else
				a.WardThinkActed = true
				b:Action_MoveToLocation(j.location)
				return
			end
		end
	end
end
function a.IsSuitableToWard()
	local v = b:GetNearbyHeroes(1200, true, BOT_MODE_NONE)
	local w = b:GetActiveMode()
	local x = b:GetActiveModeDesire()
	if
		c.IsRetreating(b) and x > 0.75
		or w == BOT_MODE_RUNE and DotaTime() > 0
		or w == BOT_MODE_DEFEND_ALLY
		or v ~= nil and #v >= 1 and a.IsIBecameTheTarget(v)
		or c.IsDefending(b)
		or c.IsGoingOnSomeone(b)
		or b:WasRecentlyDamagedByAnyHero(5.0)
	then
		return false
	end
	-- Not into visible enemies: game 020, -0:29 to -0:12, Mirana walked alone to the Dire-bank
	-- ward spot by the top rune and three Dire heroes killed her there (first blood). It only
	-- stopped once someone attacked her. Now: no ward trip while outnumbered by visible enemy
	-- heroes within 1200, or toward a spot on the enemy's side of the river with an enemy hero
	-- within 1000 of it.
	local foes = 0
	for _, e0 in pairs(v or {}) do
		if c.IsValidHero(e0) and not c.IsSuspiciousIllusion(e0) then
			foes = foes + 1
		end
	end
	local friends = #(b:GetNearbyHeroes(1200, false, BOT_MODE_NONE) or {})
	if foes >= 1 and foes > friends then
		return false
	end
	local spot = j
	if spot ~= nil and spot.location ~= nil then
		local ours = GetTeam() == TEAM_RADIANT and "radiant" or "dire"
		if spot.side ~= nil and spot.side ~= ours then
			for _, e0 in pairs(GetUnitList(UNIT_LIST_ENEMY_HEROES) or {}) do
				if c.IsValidHero(e0) and e0:CanBeSeen() and GetUnitToLocationDistance(e0, spot.location) <= 1000 then
					return false
				end
			end
		end
	end
	return true
end
function a.IsIBecameTheTarget(y)
	for z, A in pairs(y) do
		if c.IsValid(A) and not c.IsSuspiciousIllusion(A) and A:GetAttackTarget() == b then
			return true
		end
	end
	return false
end
function a.IsWardSpotDefensiveOrNearby(B)
	if GetUnitToLocationDistance(b, B) <= 1500 then
		return true
	end
	local C = GetAncient(GetTeam())
	if C and C:IsAlive() then
		local D = c.GetDistance(C:GetLocation(), B)
		if D <= 3500 then
			return true
		end
	end
	return false
end
function a.IsEnemyCloserToWardLocation(B)
	for z, E in pairs(GetTeamPlayers(GetOpposingTeam())) do
		if IsHeroAlive(E) then
			local F = GetHeroLastSeenInfo(E)
			if F ~= nil then
				local G = F[1]
				if
					G ~= nil
					and G.time_since_seen < 3.0
					and c.GetDistance(G.location, B) < GetUnitToLocationDistance(b, B)
				then
					local H = c.GetAlliesNearLoc(B, 1200)
					local v = c.GetEnemiesNearLoc(B, 1200)
					if #v > #H then
						return true
					end
				end
			end
		end
	end
	return false
end
if SafeCall then
	local I = GetDesire
	local J = Think
	if I then
		GetDesire = SafeCall(I, 0, "WARD_GetDesire")
	end
	if J then
		Think = SafeCall(J, nil, "WARD_Think")
	end
end
