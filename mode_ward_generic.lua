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
local function AnnounceWard(kind)
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
			if not I and (q == "item_ward_observer" or q == "item_ward_dispenser") then
				h = p
				I = o <= 5
			end
			if not J and (q == "item_ward_sentry" or q == "item_ward_dispenser") then
				i = p
				J = o <= 5
			end
		end
	end
	-- Enter ward mode even if wards are still in backpack so purchase can promote them.
	if h ~= nil and (I and c.CanCastAbility(h) or not I) then
		local r = d.GetAvailabeObserverWardSpots(b)
		j = d.GetClosestObserverWardSpot(b, r)
		if j and (not a.IsEnemyCloserToWardLocation(j.location) or c.IsRealInvisible(b)) then
			local s = n and not a.IsWardSpotDefensiveOrNearby(j.location)
			if s then
			elseif DotaTime() > 0 and GetUnitToLocationDistance(b, j.location) > 4000 then
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
			elseif DotaTime() > 0 and GetUnitToLocationDistance(b, j.location) > 4000 then
			elseif DotaTime() > k + 1.0 then
				return BOT_MODE_DESIRE_VERYHIGH
			end
		end
	end
	return BOT_MODE_DESIRE_NONE
end
function Think()
	if c.CanNotUseAction(b) then
		return
	end
	if j then
		if h and c.CanCastAbility(h) then
			if GetUnitToLocationDistance(b, j.location) <= f then
				if h:GetName() == "item_ward_observer" then
					AnnounceWard("observer")
					b:Action_UseAbilityOnLocation(h, j.location)
				else
					if h:GetToggleState() == false then
						b:Action_UseAbilityOnEntity(h, b)
						return
					else
						AnnounceWard("observer")
						b:Action_UseAbilityOnLocation(h, j.location)
					end
				end
				j.plant_time_obs = DotaTime()
				return
			else
				b:Action_MoveToLocation(j.location)
				return
			end
		end
		if i and c.CanCastAbility(i) then
			if GetUnitToLocationDistance(b, j.location) <= g then
				local u = 0
				if d.IsOtherWardClose(j.location, "npc_dota_observer_wards", 300, true, false) then
					u = 30
				end
				if i:GetName() == "item_ward_sentry" then
					AnnounceWard("sentry")
					b:Action_UseAbilityOnLocation(i, j.location + RandomVector(u))
				else
					if i:GetToggleState() == true then
						b:Action_UseAbilityOnEntity(i, b)
						return
					else
						AnnounceWard("sentry")
						b:Action_UseAbilityOnLocation(i, j.location + RandomVector(u))
					end
				end
				j.plant_time_sentry = DotaTime()
				return
			else
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
