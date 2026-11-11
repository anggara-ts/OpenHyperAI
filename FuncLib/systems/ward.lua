-- Shared bot system: ward.
local a = {}
local b = require(GetScriptDirectory() .. "/FuncLib/func_utils")
-- Eye cliffs pinged in the current map. Ground point under the cliff, used after that lane's T1 falls.
local UBER_WALK = 7000
local OBS_GAP = 1500
local UberWardSpots = {
	{ location = Vector(1015, 3593, 0), plant_time_obs = 0, plant_time_sentry = 0, role = "uber", side = "dire" },
	{ location = Vector(4612, 767, 0), plant_time_obs = 0, plant_time_sentry = 0, role = "uber", side = "dire" },
	{ location = Vector(-1287, -4329, 0), plant_time_obs = 0, plant_time_sentry = 0, role = "uber", side = "radiant" },
	{ location = Vector(-4348, -1008, 0), plant_time_obs = 0, plant_time_sentry = 0, role = "uber", side = "radiant" },
}
local RoshSpots = {
	{ location = Vector(-3379, 743, 0), plant_time_obs = 0, plant_time_sentry = 0, role = "contest", side = "radiant" },
	{ location = Vector(1230, -3082, 0), plant_time_obs = 0, plant_time_sentry = 0, role = "contest", side = "radiant" },
	{ location = Vector(-1700, 2728, 0), plant_time_obs = 0, plant_time_sentry = 0, role = "contest", side = "dire" },
	{ location = Vector(2588, -1248, 0), plant_time_obs = 0, plant_time_sentry = 0, role = "contest", side = "dire" },
}
local HuntSpots = {
	{ location = Vector(-1921, 4464, 0), plant_time_obs = 0, plant_time_sentry = 0, role = "hunt", side = "dire" },
	{ location = Vector(3796, -622, 0), plant_time_obs = 0, plant_time_sentry = 0, role = "hunt", side = "dire" },
	{ location = Vector(36, -3778, 0), plant_time_obs = 0, plant_time_sentry = 0, role = "hunt", side = "radiant" },
	{ location = Vector(-4876, 624, 0), plant_time_obs = 0, plant_time_sentry = 0, role = "hunt", side = "radiant" },
}
-- Lotus pools and twin gates. Same contest rules as Roshan: after 6:00, still blocked behind a living tier-1.
local GateSpots = {
	{ location = Vector(-7421, 4238, 0), plant_time_obs = 0, plant_time_sentry = 0, role = "contest", side = "radiant" },
	{ location = Vector(7309, -4419, 0), plant_time_obs = 0, plant_time_sentry = 0, role = "contest", side = "dire" },
	{ location = Vector(-6244, 7147, 0), plant_time_obs = 0, plant_time_sentry = 0, role = "contest", side = "radiant" },
	{ location = Vector(6206, -6958, 0), plant_time_obs = 0, plant_time_sentry = 0, role = "contest", side = "dire" },
}
local E = {
	[1] = { location = Vector(-1650, -83, 0), plant_time_obs = 0, plant_time_sentry = 0, role = "early", side = "radiant" },
	[2] = { location = Vector(-245, -996, 0), plant_time_obs = 0, plant_time_sentry = 0, role = "early", side = "radiant" },
	[3] = { location = Vector(6113, -3427, 0), plant_time_obs = 0, plant_time_sentry = 0, role = "early", side = "dire" },
	[4] = { location = Vector(5308, -4362, 0), plant_time_obs = 0, plant_time_sentry = 0, role = "early", side = "radiant" },
}
local F = {
	-- Radiant bank of the bottom rune. The dire bank looks back into Dire's own jungle.
	[1] = { location = Vector(-245, -996, 0), plant_time_obs = 0, plant_time_sentry = 0, role = "early", side = "radiant" },
	[2] = { location = Vector(-627, 850, 0), plant_time_obs = 0, plant_time_sentry = 0, role = "early", side = "dire" },
	[3] = { location = Vector(-5305, 4281, 0), plant_time_obs = 0, plant_time_sentry = 0, role = "early", side = "dire" },
	[4] = { location = Vector(-5862, 3476, 0), plant_time_obs = 0, plant_time_sentry = 0, role = "early", side = "radiant" },
}
function a.GetEarlyGameWardSpots()
	return GetTeam() == TEAM_RADIANT and E or F
end
function a.GetGameStartWardSpots()
	return a.GetEarlyGameWardSpots()
end
-- A spot next to an enemy T2/T3, or deeper than a living T1, gets the ward killed and the support ganked.
local function EnemyWardTooDeep(loc)
	local enemy = GetOpposingTeam()
	local gates = {
		{ TOWER_TOP_2, TOWER_TOP_1 },
		{ TOWER_MID_2, TOWER_MID_1 },
		{ TOWER_BOT_2, TOWER_BOT_1 },
		{ TOWER_TOP_3, TOWER_TOP_2 },
		{ TOWER_MID_3, TOWER_MID_2 },
		{ TOWER_BOT_3, TOWER_BOT_2 },
		{ TOWER_TOP_3, TOWER_TOP_1 },
		{ TOWER_MID_3, TOWER_MID_1 },
		{ TOWER_BOT_3, TOWER_BOT_1 },
	}
	for i = 1, #gates do
		local inner = GetTower(enemy, gates[i][1])
		local outer = GetTower(enemy, gates[i][2])
		if inner ~= nil and outer ~= nil and GetUnitToLocationDistance(inner, loc) <= 1600 then
			return true
		end
	end
	local ancient = GetAncient(enemy)
	if ancient == nil then
		return false
	end
	local fronts = { TOWER_TOP_1, TOWER_MID_1, TOWER_BOT_1 }
	local nearest = nil
	local nearestDist = 3200
	for i = 1, #fronts do
		local t1 = GetTower(enemy, fronts[i])
		if t1 ~= nil then
			local dist = GetUnitToLocationDistance(t1, loc)
			if dist < nearestDist then
				nearestDist = dist
				nearest = t1
			end
		end
	end
	if nearest == nil then
		return false
	end
	local spotDepth = GetUnitToLocationDistance(ancient, loc)
	local towerDepth = GetUnitToUnitDistance(ancient, nearest)
	return spotDepth + 500 < towerDepth
end
local function DropDeepEnemySpots(list)
	local kept = {}
	for i = 1, #list do
		local spot = list[i]
		if spot.role == "early" then
			kept[#kept + 1] = spot
		elseif spot.location ~= nil and not EnemyWardTooDeep(spot.location) then
			kept[#kept + 1] = spot
		end
	end
	return kept
end
-- Home/defend ground spots sit on our T3. Skip them until that lane's T1 is gone,
-- unless enemies are already on the high ground (handled by the caller).
local function HomeWardTooEarly(loc)
	local team = GetTeam()
	local lanes = {
		{ TOWER_TOP_1, TOWER_TOP_3 },
		{ TOWER_MID_1, TOWER_MID_3 },
		{ TOWER_BOT_1, TOWER_BOT_3 },
	}
	local sawTower = false
	local laneOpen = false
	for i = 1, #lanes do
		local t1 = GetTower(team, lanes[i][1])
		local t3 = GetTower(team, lanes[i][2])
		if t1 ~= nil or t3 ~= nil then
			sawTower = true
		end
		if t1 == nil and t3 ~= nil then
			laneOpen = true
		end
		if t1 ~= nil and t3 ~= nil and GetUnitToLocationDistance(t3, loc) <= 1800 then
			return true
		end
	end
	return not sawTower or not laneOpen
end
function a.WalkLimit(spot)
	if spot and spot.role == "uber" then
		return UBER_WALK
	end
	return 4000
end
local function ObsFree(spot)
	return spot ~= nil
		and spot.location ~= nil
		and not a.IsOtherWardClose(spot.location, "npc_dota_observer_wards", OBS_GAP, true, false)
		and not a.IsThereEnemySentry(spot.location, 1100)
		and (spot.plant_time_obs == 0 or DotaTime() > spot.plant_time_obs + 360)
end
local function SentryFree(spot)
	return spot ~= nil
		and spot.location ~= nil
		and not a.IsOtherWardClose(spot.location, "npc_dota_sentry_wards", 1200, true, false)
		and not b.Site.IsLocationHaveTrueSight(spot.location)
end
-- Towers have loaded and at least one enemy tier-1 is gone. All-nil is not "all down".
local function EnemyOuterDown()
	local enemy = GetOpposingTeam()
	local lanes = { TOWER_TOP_1, TOWER_MID_1, TOWER_BOT_1 }
	local alive = 0
	local loaded = GetTower(enemy, TOWER_TOP_2) ~= nil
		or GetTower(enemy, TOWER_MID_2) ~= nil
		or GetTower(enemy, TOWER_BOT_2) ~= nil
		or GetTower(enemy, TOWER_TOP_3) ~= nil
		or GetTower(enemy, TOWER_MID_3) ~= nil
		or GetTower(enemy, TOWER_BOT_3) ~= nil
	for i = 1, #lanes do
		if GetTower(enemy, lanes[i]) ~= nil then
			alive = alive + 1
			loaded = true
		end
	end
	return loaded and alive < #lanes
end
local function TeamSide()
	return GetTeam() == TEAM_RADIANT and "radiant" or "dire"
end
local function DefendingHighGround()
	local ancient = GetAncient(GetTeam())
	local near = ancient ~= nil and b.Utils.CountEnemyHeroesNear(ancient:GetLocation(), 2500) or 0
	return near >= 1 or b.Utils.CountEnemyHeroesOnHighGround(GetTeam()) >= 1
end
function a.GetAvailabeObserverWardSpots(K)
	local L = {}
	if DotaTime() < 0 or b.IsEarlyGame() then
		for M, N in pairs(a.GetEarlyGameWardSpots()) do
			if ObsFree(N) then
				table.insert(L, N)
			end
		end
		if DotaTime() < 6 * 60 then
			return DropDeepEnemySpots(L)
		end
	end
	local ourSide = TeamSide()
	local defending = DefendingHighGround()
	local pushing = not defending and EnemyOuterDown()
	local function consider(spot)
		if not ObsFree(spot) then
			return
		end
		local onOurs = spot.side == ourSide
		if spot.role == "uber" then
			-- Own eye cliff looks back into our jungle. While pushing, ward the enemy cliff.
			if defending and not onOurs then
				return
			end
			if pushing and onOurs then
				return
			end
		elseif spot.role == "contest" then
			if defending and not onOurs then
				return
			end
		elseif spot.role == "hunt" then
			if onOurs then
				if not defending and HomeWardTooEarly(spot.location) then
					return
				end
			elseif defending or (b.IsEarlyGame() and not pushing) then
				return
			end
		else
			return
		end
		table.insert(L, spot)
	end
	for i = 1, #UberWardSpots do
		consider(UberWardSpots[i])
	end
	for i = 1, #RoshSpots do
		local spot = RoshSpots[i]
		local x, y = spot.location.x, spot.location.y
		local bottomRune = (x == 1230 and y == -3082) or (x == 2588 and y == -1248)
		-- Own bank of the bottom rune faces our jungle. Ward the enemy bank.
		if not (bottomRune and spot.side == ourSide) then
			consider(spot)
		end
	end
	for i = 1, #GateSpots do
		consider(GateSpots[i])
	end
	for i = 1, #HuntSpots do
		consider(HuntSpots[i])
	end
	return DropDeepEnemySpots(L)
end
function a.GetClosestObserverWardSpot(K, S)
	local T = 100000
	local U = nil
	local uberBest = nil
	local uberDist = 100000
	local uberMax = UBER_WALK
	for M, N in pairs(S) do
		local V = GetUnitToLocationDistance(K, N.location)
		if N.role == "uber" and V < uberDist and V <= uberMax then
			uberDist = V
			uberBest = N
		end
		if V < T then
			T = V
			U = N
		end
	end
	return uberBest or U
end
function a.GetPossibleSentryWardSpots(K)
	local W = {}
	local ourSide = TeamSide()
	local defending = DefendingHighGround()
	local pushing = not defending and EnemyOuterDown()
	if DotaTime() < 0 or b.IsEarlyGame() then
		for M, N in pairs(a.GetEarlyGameWardSpots()) do
			if N.side ~= ourSide and SentryFree(N) then
				table.insert(W, N)
			end
		end
		if DotaTime() < 6 * 60 then
			return DropDeepEnemySpots(W)
		end
	end
	local function consider(spot)
		if not SentryFree(spot) then
			return
		end
		local onOurs = spot.side == ourSide
		local want = false
		if defending then
			want = onOurs
		elseif pushing then
			want = not onOurs
		else
			want = spot.role == "contest" or spot.role == "uber"
		end
		if want then
			table.insert(W, spot)
		end
	end
	for i = 1, #UberWardSpots do
		consider(UberWardSpots[i])
	end
	for i = 1, #RoshSpots do
		consider(RoshSpots[i])
	end
	for i = 1, #GateSpots do
		consider(GateSpots[i])
	end
	for i = 1, #HuntSpots do
		consider(HuntSpots[i])
	end
	return DropDeepEnemySpots(W)
end
function a.GetClosestSentryWardSpot(K, S)
	local T = 100000
	local U = nil
	for M, N in pairs(S) do
		local V = GetUnitToLocationDistance(K, N.location)
		if V < T then
			T = V
			U = N
		end
	end
	return U
end
function a.IsOtherWardClose(X, Y, Z, _, a0)
	local a1 = GetUnitList(UNIT_LIST_ALLIED_WARDS)
	if not _ then
		a1 = GetUnitList(UNIT_LIST_ENEMY_WARDS)
	end
	for M, a2 in pairs(a1) do
		if b.IsValid(a2) and string.find(a2:GetUnitName(), Y) and GetUnitToLocationDistance(a2, X) <= Z then
			if a0 then
				if Y == "item_ward_observer" and b.GetModifierTime(a2, "modifier_item_buff_ward") >= 360 / 2 then
					return true
				end
			else
				return true
			end
		end
	end
	return false
end
function a.IsThereEnemySentry(X, Z)
	local a3 = GetUnitList(UNIT_LIST_ENEMY_WARDS)
	for M, a2 in pairs(a3) do
		if b.IsValid(a2) and a2:GetUnitName() == "npc_dota_sentry_wards" and GetUnitToLocationDistance(a2, X) <= Z then
			return true
		end
	end
	return false
end
return a
