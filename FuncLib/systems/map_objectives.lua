-- Shared timing/discovery for lotus pools and wisdom shrines.
local MapObjectives = {}

local U = require(GetScriptDirectory() .. "/FuncLib/systems/utils")

local cachedLotus = { at = -999, units = {} }
local cachedWisdom = { at = -999, units = {} }

local function IsTurbo()
	if GetGameMode() == GAMEMODE_TURBO or GetGameMode() == 23 then
		return true
	end
	return U.IsModeTurbo and U.IsModeTurbo() or false
end

-- Seconds until the next clock mark for a fixed interval (first spawn == interval).
function MapObjectives.SecondsToNextMark(intervalSeconds)
	local t = DotaTime()
	if t < 0 then
		return intervalSeconds - t
	end
	local nextMark = math.ceil(t / intervalSeconds) * intervalSeconds
	if nextMark < intervalSeconds then
		nextMark = intervalSeconds
	end
	if math.abs(t - nextMark) < 0.05 then
		return 0
	end
	if nextMark <= t then
		nextMark = nextMark + intervalSeconds
	end
	return nextMark - t
end

function MapObjectives.LotusInterval()
	return IsTurbo() and 90 or 180
end

function MapObjectives.WisdomInterval()
	return IsTurbo() and 210 or 420
end

-- True in the contest window around a spawn/activation mark.
-- arriveEarly: start walking this many seconds before the mark
-- stayAfter: keep desire this many seconds after the mark
function MapObjectives.InMarkWindow(intervalSeconds, arriveEarly, stayAfter)
	local t = DotaTime()
	if t < -5 then
		return false, 9999
	end
	arriveEarly = arriveEarly or 35
	stayAfter = stayAfter or 18
	local toNext = MapObjectives.SecondsToNextMark(intervalSeconds)
	local sinceLast = intervalSeconds - toNext
	if toNext <= arriveEarly then
		return true, toNext
	end
	if sinceLast <= stayAfter and t >= intervalSeconds - 1 then
		return true, -sinceLast
	end
	return false, toNext
end

-- How early to leave for an objective, scaled by walk distance.
-- Nearby → ~8s early; far (~6k) → ~25s; hard cap so they never camp minutes early.
function MapObjectives.ArriveEarlyForDistance(dist, bot)
	dist = dist or 0
	local ms = 320
	if bot ~= nil and bot.GetCurrentMovementSpeed then
		local speed = bot:GetCurrentMovementSpeed()
		if type(speed) == "number" and speed > 200 then
			ms = speed
		end
	end
	-- travel time + small pathing buffer
	local early = dist / ms + 5
	if early < 8 then
		return 8
	end
	if early > 28 then
		return 28
	end
	return early
end

local function ScanUnits(cache, unitName)
	if DotaTime() - cache.at < 2.0 and #cache.units > 0 then
		return cache.units
	end
	local found = {}
	for _, u in pairs(GetUnitList(UNIT_LIST_ALL) or {}) do
		if u ~= nil and u.GetUnitName and u:GetUnitName() == unitName then
			found[#found + 1] = u
		end
	end
	cache.at = DotaTime()
	cache.units = found
	return found
end

function MapObjectives.GetLotusPoolLocations()
	local units = ScanUnits(cachedLotus, "npc_dota_lotus_pool")
	if #units >= 1 then
		local locs = {}
		for i = 1, #units do
			locs[i] = units[i]:GetLocation()
		end
		return locs, units
	end
	local pools = U.LotusPools or {}
	return {
		pools.top or Vector(-7264, 4493, 256),
		pools.bottom or Vector(7788, -4121, 256),
	}, nil
end

function MapObjectives.GetWisdomShrineLocations()
	local units = ScanUnits(cachedWisdom, "npc_dota_xp_fountain")
	if #units >= 1 then
		local locs = {}
		for i = 1, #units do
			locs[i] = units[i]:GetLocation()
		end
		return locs, units
	end
	local runes = U.WisdomRunes or {}
	return {
		runes[TEAM_RADIANT] or Vector(-8126, -320, 256),
		runes[TEAM_DIRE] or Vector(8319, 266, 256),
	}, nil
end

function MapObjectives.PickClosestLocation(bot, locations)
	local best = nil
	local bestDist = 99999
	for i = 1, #locations do
		local loc = locations[i]
		if loc ~= nil then
			local d = GetUnitToLocationDistance(bot, loc)
			if d < bestDist then
				bestDist = d
				best = loc
			end
		end
	end
	return best, bestDist
end

-- Prefer the pool on the bot's lane side; fall back to nearest if that is too far.
function MapObjectives.PickLotusForBot(bot, locations)
	if locations == nil or #locations == 0 then
		return nil, 99999
	end
	if #locations == 1 then
		return locations[1], GetUnitToLocationDistance(bot, locations[1])
	end
	local top, bottom = locations[1], locations[2]
	-- Normalize by y so "top" is the northern pool.
	if top.y < bottom.y then
		top, bottom = bottom, top
	end
	local lane = bot:GetAssignedLane()
	local prefer = nil
	if lane == LANE_TOP then
		prefer = top
	elseif lane == LANE_BOT then
		prefer = bottom
	end
	local closest, closestDist = MapObjectives.PickClosestLocation(bot, locations)
	if prefer ~= nil then
		local preferDist = GetUnitToLocationDistance(bot, prefer)
		local maxWalk = MapObjectives.MaxWalk(bot)
		-- Lane-side pool only if reachable; otherwise take whichever is closer.
		if preferDist <= maxWalk + 600 then
			return prefer, preferDist
		end
	end
	return closest, closestDist
end

-- Team shrine first (Radiant west / Dire east), else nearest.
function MapObjectives.PickWisdomForBot(bot, locations)
	if locations == nil or #locations == 0 then
		return nil, 99999
	end
	local team = GetTeam()
	local preferred = nil
	if team == TEAM_RADIANT then
		-- Radiant shrine is the western one (negative x).
		for i = 1, #locations do
			if preferred == nil or locations[i].x < preferred.x then
				preferred = locations[i]
			end
		end
	else
		for i = 1, #locations do
			if preferred == nil or locations[i].x > preferred.x then
				preferred = locations[i]
			end
		end
	end
	if preferred ~= nil then
		return preferred, GetUnitToLocationDistance(bot, preferred)
	end
	return MapObjectives.PickClosestLocation(bot, locations)
end

-- True if this bot is the best living ally to take the objective (one bot per spot).
function MapObjectives.IsBestAllyForLocation(bot, loc, scoreFn)
	if loc == nil then
		return false
	end
	local bestBot = bot
	local bestScore = scoreFn(bot, loc)
	for _, ally in pairs(GetUnitList(UNIT_LIST_ALLIED_HEROES) or {}) do
		if ally ~= nil and ally ~= bot and ally:IsAlive() and ally:IsHero() and not ally:IsIllusion() then
			local score = scoreFn(ally, loc)
			if score > bestScore then
				bestScore = score
				bestBot = ally
			end
		end
	end
	return bestBot == bot
end

function MapObjectives.DangerousObjective(bot, loc, enemyRange)
	enemyRange = enemyRange or 1400
	local enemies = bot:GetNearbyHeroes(enemyRange, true, BOT_MODE_NONE) or {}
	local allies = bot:GetNearbyHeroes(enemyRange, false, BOT_MODE_NONE) or {}
	if #enemies >= #allies + 1 and GetUnitToLocationDistance(bot, loc) > 600 then
		return true
	end
	local hp = bot:GetHealth() / math.max(1, bot:GetMaxHealth())
	if bot:WasRecentlyDamagedByAnyHero(2.0) and hp < 0.4 then
		return true
	end
	return false
end

function MapObjectives.TeamInCrisis(bot)
	local ancient = GetAncient(GetTeam())
	if ancient ~= nil and U.CountEnemyHeroesNear and U.CountEnemyHeroesNear(ancient:GetLocation(), 2800) >= 1 then
		return true
	end
	if U.CountEnemyHeroesOnHighGround and U.CountEnemyHeroesOnHighGround(GetTeam()) >= 2 then
		return true
	end
	return false
end

-- Map width is ~16k units; pools/shrines often sit ~3–5k from a lane.
MapObjectives.WALK_NEAR = 3200
MapObjectives.WALK_IDLE = 5200 -- enough to leave lane for a lotus/shrine mark
MapObjectives.WALK_WINDOW = 6000 -- designated picker during the spawn window

function MapObjectives.IsIdleForObjective(bot)
	if bot == nil or not bot:IsAlive() then
		return false
	end
	local mode = bot:GetActiveMode()
	local desire = bot:GetActiveModeDesire() or 0
	if mode == BOT_MODE_ATTACK or mode == BOT_MODE_RETREAT or mode == BOT_MODE_DEFEND_ALLY then
		return false
	end
	if
		mode == BOT_MODE_PUSH_TOWER_TOP
		or mode == BOT_MODE_PUSH_TOWER_MID
		or mode == BOT_MODE_PUSH_TOWER_BOT
		or mode == BOT_MODE_DEFEND_TOWER_TOP
		or mode == BOT_MODE_DEFEND_TOWER_MID
		or mode == BOT_MODE_DEFEND_TOWER_BOT
		or mode == BOT_MODE_ROSHAN
		or mode == BOT_MODE_TEAM_ROAM
	then
		return false
	end
	local enemies = bot:GetNearbyHeroes(1200, true, BOT_MODE_NONE) or {}
	if #enemies > 0 then
		return false
	end
	-- Busy farming/laning with strong desire: stay local only.
	if (mode == BOT_MODE_FARM or mode == BOT_MODE_LANING) and desire >= BOT_MODE_DESIRE_HIGH then
		return false
	end
	return true
end

function MapObjectives.MaxWalk(bot, inWindow)
	if inWindow then
		return MapObjectives.WALK_WINDOW
	end
	if MapObjectives.IsIdleForObjective(bot) then
		return MapObjectives.WALK_IDLE
	end
	return MapObjectives.WALK_NEAR
end

-- Free one slot so a lotus can land (early bags are often full of consumables).
function MapObjectives.EnsureInventorySlot(bot)
	if bot == nil then
		return false
	end
	local Item = require(GetScriptDirectory() .. "/FuncLib/systems/item")
	if Item.GetEmptyInventoryAmount(bot) > 0 then
		return true
	end
	local keep = {
		item_aegis = true,
		item_rapier = true,
		item_gem = true,
		item_cheese = true,
		item_refresher_shard = true,
		item_tpscroll = true,
		item_ward_observer = true,
		item_ward_sentry = true,
		item_ward_dispenser = true,
		item_smoke_of_deceit = true,
		item_grisgris = true,
	}
	local best = nil
	local bestCost = 999999
	for slot = 0, 8 do
		local it = bot:GetItemInSlot(slot)
		if it ~= nil and not it:IsNull() then
			local name = it:GetName()
			if not keep[name] and not string.find(name, "token") then
				local cost = GetItemCost(name) or 0
				if cost < bestCost and cost <= 90 then
					bestCost = cost
					best = it
				end
			end
		end
	end
	if best == nil then
		return false
	end
	bot:ActionImmediate_SellItem(best)
	return true
end

local function UtilsPos(bot)
	local ok, Utils = pcall(require, GetScriptDirectory() .. "/FuncLib/func_utils")
	if ok and Utils and Utils.GetPosition then
		return Utils.GetPosition(bot)
	end
	return 3
end

function MapObjectives.LotusScore(hero, loc)
	if hero == nil or not hero:IsAlive() then
		return -99999
	end
	local dist = GetUnitToLocationDistance(hero, loc)
	if dist > MapObjectives.MaxWalk(hero, true) + 400 then
		return -99999
	end
	local pos = UtilsPos(hero)
	local score = 10000 - dist
	-- Supports hold healing lotuses; strongly prefer them at the pool.
	if pos >= 4 then
		score = score + 1200
	elseif pos == 3 then
		score = score + 350
	elseif pos == 2 then
		score = score + 80
	else
		score = score - 400
	end
	local hp = hero:GetHealth() / math.max(1, hero:GetMaxHealth())
	local mp = hero:GetMana() / math.max(1, hero:GetMaxMana())
	if hp < 0.7 or mp < 0.45 then
		score = score + 250
	end
	-- Already carrying a lotus: slightly less need to contest again.
	if
		hero:FindItemSlot("item_famango") >= 0
		or hero:FindItemSlot("item_great_famango") >= 0
		or hero:FindItemSlot("item_greater_famango") >= 0
	then
		score = score - 350
	end
	if not hero:IsBot() and dist < 2200 then
		score = score + 2000
	end
	return score
end

function MapObjectives.WisdomScore(hero, loc)
	if hero == nil or not hero:IsAlive() then
		return -99999
	end
	local dist = GetUnitToLocationDistance(hero, loc)
	if dist > MapObjectives.MaxWalk(hero, true) + 400 then
		return -99999
	end
	local pos = UtilsPos(hero)
	local score = 10000 - dist
	score = score + (30 - hero:GetLevel()) * 80
	if pos >= 4 then
		score = score + 400
	elseif pos == 3 then
		score = score + 300
	elseif pos == 1 then
		score = score - 150
	end
	local hp = hero:GetHealth() / math.max(1, hero:GetMaxHealth())
	if hp < 0.45 then
		score = score - 600
	end
	if not hero:IsBot() and dist < 2200 then
		score = score + 2500
	end
	return score
end

-- Pool buff stack is the stored lotus count once we have seen it above zero.
-- Until then a zero stack is "unknown", so an empty read cannot skip every pool.
local lotusStackSeen = false

local function LotusCharges(bot)
	local n = 0
	for slot = 0, 16 do
		local it = bot:GetItemInSlot(slot)
		if it ~= nil and it.GetName ~= nil then
			local name = it:GetName()
			if name == "item_famango" or name == "item_great_famango" or name == "item_greater_famango" then
				local charges = 1
				if it.GetCurrentCharges ~= nil then
					local c = it:GetCurrentCharges()
					if type(c) == "number" and c > charges then
						charges = c
					end
				end
				n = n + charges
			end
		end
	end
	return n
end

function MapObjectives.LotusCountOnUnit(pool)
	if pool == nil or pool.NumModifiers == nil then
		return nil
	end
	if pool.IsNull ~= nil and pool:IsNull() then
		return nil
	end
	-- NumModifiers on a fogged lotus pool spams the console and tanks FPS.
	if pool.CanBeSeen ~= nil and not pool:CanBeSeen() then
		return nil
	end
	local found = false
	local stacks = 0
	local n = pool:NumModifiers() or 0
	for i = 0, n - 1 do
		local name = pool:GetModifierName(i)
		if type(name) == "string" and string.find(name, "lotus_pool", 1, true) then
			found = true
			local s = pool:GetModifierStackCount(i)
			if type(s) == "number" and s > stacks then
				stacks = s
			end
		end
	end
	if not found then
		return nil
	end
	if stacks > 0 then
		lotusStackSeen = true
		return stacks
	end
	if lotusStackSeen then
		return 0
	end
	return nil
end

function MapObjectives.LotusCountNear(loc, units)
	if loc == nil or units == nil then
		return nil
	end
	local best = nil
	local bestDist = 800
	for i = 1, #units do
		local pool = units[i]
		if pool ~= nil and pool.GetLocation ~= nil then
			local dist = GetUnitToLocationDistance(pool, loc)
			if dist < bestDist then
				bestDist = dist
				best = pool
			end
		end
	end
	if best == nil then
		return nil
	end
	return MapObjectives.LotusCountOnUnit(best)
end

-- True once this spawn's lotus should already be in the pool.
function MapObjectives.LotusSpawnOpen()
	local interval = MapObjectives.LotusInterval()
	local t = DotaTime()
	if t < interval - 1 then
		return false
	end
	local mark = math.floor(t / interval) * interval
	return mark >= interval and t >= mark
end

-- Inside the ring: a lotus that never arrives was taken or the pool is empty.
function MapObjectives.LotusPluckStalled(bot, enemyInRing)
	local have = LotusCharges(bot)
	local now = DotaTime()
	if bot._lotusHave ~= have or bot._lotusHaveAt == nil then
		bot._lotusHave = have
		bot._lotusHaveAt = now
	end
	local limit = enemyInRing and 6 or 2.5
	return now - bot._lotusHaveAt >= limit
end

local function EnemyInLotusRing(bot, loc)
	local enemies = bot:GetNearbyHeroes(900, true, BOT_MODE_NONE) or {}
	for i = 1, #enemies do
		local enemy = enemies[i]
		if
			enemy ~= nil
			and enemy:IsAlive()
			and not enemy:IsIllusion()
			and GetUnitToLocationDistance(enemy, loc) <= 380
		then
			return true
		end
	end
	return false
end

-- Attack or cast without leaving the pluck ring. Standing still is only for the pickup itself.
local function ActInsideLotus(bot, loc)
	if bot:IsCastingAbility() or bot:IsChanneling() then
		return
	end
	local action = bot:GetCurrentActionType()
	if action == BOT_ACTION_TYPE_USE_ABILITY then
		return
	end
	local range = bot:GetAttackRange() + 80
	local heroes = bot:GetNearbyHeroes(range, true, BOT_MODE_NONE) or {}
	for i = 1, #heroes do
		local hero = heroes[i]
		if hero ~= nil and hero:IsAlive() and not hero:IsIllusion() and GetUnitToUnitDistance(bot, hero) <= range then
			if bot:GetAttackTarget() ~= hero then
				bot:Action_AttackUnit(hero, true)
			end
			return
		end
	end
	local creeps = bot:GetNearbyCreeps(range, true) or {}
	for i = 1, #creeps do
		local creep = creeps[i]
		if creep ~= nil and creep:IsAlive() and GetUnitToUnitDistance(bot, creep) <= range then
			if bot:GetAttackTarget() ~= creep then
				bot:Action_AttackUnit(creep, true)
			end
			return
		end
	end
	-- Stop the walk-in order once, so it does not carry the hero out of the ring.
	if action == BOT_ACTION_TYPE_MOVE_TO then
		bot:Action_ClearActions(true)
	end
end

-- Returns desire, location, kind ("lotus"|"wisdom"), eta. Desire 0 if none.
function MapObjectives.ConsiderObjectiveDesire(bot)
	if bot == nil or not bot:IsAlive() or bot:IsIllusion() then
		return 0, nil, nil, nil
	end
	if MapObjectives.TeamInCrisis(bot) then
		return 0, nil, nil, nil
	end
	local ok, Utils = pcall(require, GetScriptDirectory() .. "/FuncLib/func_utils")
	if ok and Utils and Utils.IsDefending and Utils.IsDefending(bot) then
		return 0, nil, nil, nil
	end

	-- Wisdom: leave time scales with distance; linger ~8s after mark (3s channel).
	local wInterval = MapObjectives.WisdomInterval()
	local wisdomMark = math.floor(math.max(0, DotaTime()) / wInterval) * wInterval
	local wisdomClaimed = bot._wisdomClaimedMark ~= nil
		and bot._wisdomClaimedMark == wisdomMark
		and DotaTime() >= wisdomMark
	if not wisdomClaimed then
		local locs = MapObjectives.GetWisdomShrineLocations()
		local loc, dist = MapObjectives.PickWisdomForBot(bot, locs)
		local maxWalk = MapObjectives.MaxWalk(bot, true)
		local arrive = MapObjectives.ArriveEarlyForDistance(dist, bot)
		local inWisdom, etaW = MapObjectives.InMarkWindow(wInterval, arrive, 8)
		local hp = bot:GetHealth() / math.max(1, bot:GetMaxHealth())
		if
			inWisdom
			and loc ~= nil
			and dist <= maxWalk
			and hp >= 0.45
			and not (bot:WasRecentlyDamagedByAnyHero(3.0) and hp < 0.65)
			and not (MapObjectives.DangerousObjective(bot, loc, 1500) and dist > 700)
			and MapObjectives.IsBestAllyForLocation(bot, loc, MapObjectives.WisdomScore)
		then
			local desire = RemapValClamped(dist, maxWalk, 0, BOT_MODE_DESIRE_MODERATE, BOT_MODE_DESIRE_ABSOLUTE)
			-- Don't go hard until travel time is actually needed.
			if type(etaW) == "number" and etaW > arrive * 0.55 then
				desire = math.min(desire, BOT_MODE_DESIRE_LOW + 0.05)
			elseif type(etaW) == "number" and etaW <= 12 then
				desire = math.max(desire, BOT_MODE_DESIRE_HIGH + 0.05)
			end
			if type(etaW) == "number" and math.abs(etaW) <= 8 then
				desire = math.max(desire, BOT_MODE_DESIRE_VERYHIGH + 0.05)
			end
			return desire, loc, "wisdom", etaW
		end
	end

	-- Lotus: walk in before the mark. Leave once the pool is empty or a pluck never lands.
	do
		local lInterval = MapObjectives.LotusInterval()
		local locs, units = MapObjectives.GetLotusPoolLocations()
		local loc, dist = MapObjectives.PickLotusForBot(bot, locs)
		local maxWalk = MapObjectives.MaxWalk(bot, true)
		local arrive = MapObjectives.ArriveEarlyForDistance(dist, bot)
		local inLotus, etaL = MapObjectives.InMarkWindow(lInterval, arrive, 6)
		local count = MapObjectives.LotusCountNear(loc, units)
		local mark = math.floor(math.max(0, DotaTime()) / lInterval) * lInterval
		-- Enemy already took this spawn, or the pool has not stored one.
		if count == 0 and type(etaL) == "number" and etaL < -1.5 then
			inLotus = false
		end
		if bot._lotusSkipMark == mark and mark >= lInterval and (count == nil or count == 0) then
			inLotus = false
		end
		local hp = bot:GetHealth() / math.max(1, bot:GetMaxHealth())
		local Item = require(GetScriptDirectory() .. "/FuncLib/systems/item")
		local mainRoom = Item.GetEmptyNonBackpackInventoryAmount(bot) > 0
		if
			inLotus
			and mainRoom
			and loc ~= nil
			and dist <= maxWalk
			and hp >= 0.28
			and not (MapObjectives.DangerousObjective(bot, loc, 1500) and dist > 700)
			and MapObjectives.IsBestAllyForLocation(bot, loc, MapObjectives.LotusScore)
		then
			local desire = RemapValClamped(dist, maxWalk, 0, BOT_MODE_DESIRE_MODERATE, BOT_MODE_DESIRE_ABSOLUTE)
			if type(etaL) == "number" and etaL > arrive * 0.55 then
				desire = math.min(desire, BOT_MODE_DESIRE_LOW + 0.05)
			elseif type(etaL) == "number" and etaL <= 12 then
				desire = math.max(desire, BOT_MODE_DESIRE_HIGH + 0.05)
			end
			if type(etaL) == "number" and math.abs(etaL) <= 8 then
				desire = math.max(desire, BOT_MODE_DESIRE_VERYHIGH + 0.05)
			end
			return desire, loc, "lotus", etaL
		end
	end

	return 0, nil, nil, nil
end

local function AnnounceObjective(bot, kind)
	if bot == nil or kind == nil then
		return
	end
	local now = DotaTime()
	if bot._mapObjChatKind == kind and bot._mapObjChatAt ~= nil and now - bot._mapObjChatAt < 20 then
		return
	end
	bot._mapObjChatKind = kind
	bot._mapObjChatAt = now
	local key = kind == "wisdom" and "say_take_wisdom" or "say_take_lotus"
	local fallback = kind == "wisdom" and "Taking wisdom shrine." or "Taking lotus."
	local msg = fallback
	local ok, loc = pcall(require, GetScriptDirectory() .. "/FuncLib/systems/localization")
	if ok and loc and loc.Get then
		local lines = loc.Get(key)
		if type(lines) == "table" and #lines > 0 then
			msg = lines[RandomInt(1, #lines)]
		elseif type(lines) == "string" then
			msg = lines
		end
	end
	-- false = team chat
	bot:ActionImmediate_Chat(msg, false)
end

-- Stand in the gather/pluck ring. kind: "lotus" | "wisdom"
function MapObjectives.ThinkObjective(bot, loc, kind)
	if bot == nil or loc == nil then
		return false
	end
	AnnounceObjective(bot, kind)
	local gather = kind == "wisdom" and 280 or 340
	local dist = GetUnitToLocationDistance(bot, loc)
	local enemies = bot:GetNearbyHeroes(1000, true, BOT_MODE_NONE) or {}
	local allies = bot:GetNearbyHeroes(1000, false, BOT_MODE_NONE) or {}

	if #enemies > 0 and #enemies > #allies and dist > gather then
		return true
	end
	if #enemies > 0 and #enemies <= #allies and not (kind == "lotus" and dist <= gather) then
		local target = enemies[1]
		if target ~= nil and target:IsAlive() then
			bot:Action_AttackUnit(target, true)
			return true
		end
	end
	if dist > gather then
		if kind == "wisdom" then
			bot._wisdomStandSince = nil
			bot._wisdomXpAtStand = nil
		elseif kind == "lotus" then
			bot._lotusHaveAt = nil
		end
		bot:Action_MoveToLocation(loc)
		return true
	end
	if kind == "lotus" then
		local Item = require(GetScriptDirectory() .. "/FuncLib/systems/item")
		-- A full main inventory puts the lotus in the backpack, where it sits unused.
		if Item.GetEmptyNonBackpackInventoryAmount(bot) <= 0 then
			local interval = MapObjectives.LotusInterval()
			bot._lotusSkipMark = math.floor(math.max(0, DotaTime()) / interval) * interval
			return false
		end
		local _, units = MapObjectives.GetLotusPoolLocations()
		local count = MapObjectives.LotusCountNear(loc, units)
		if count == 0 and MapObjectives.LotusSpawnOpen() then
			local interval = MapObjectives.LotusInterval()
			bot._lotusSkipMark = math.floor(math.max(0, DotaTime()) / interval) * interval
			return false
		end
		if (MapObjectives.LotusSpawnOpen() or (count ~= nil and count > 0)) then
			if MapObjectives.LotusPluckStalled(bot, EnemyInLotusRing(bot, loc)) then
				local interval = MapObjectives.LotusInterval()
				bot._lotusSkipMark = math.floor(math.max(0, DotaTime()) / interval) * interval
				return false
			end
		end
		ActInsideLotus(bot, loc)
		return true
	elseif kind == "wisdom" then
		-- Shrine channel is ~3s. Mark claimed once XP lands or after a short stand so we leave.
		local now = DotaTime()
		local xp = bot.GetCurrentXP and bot:GetCurrentXP() or nil
		if bot._wisdomStandSince == nil then
			bot._wisdomStandSince = now
			bot._wisdomXpAtStand = xp
		else
			local gotXp = xp ~= nil and bot._wisdomXpAtStand ~= nil and xp > bot._wisdomXpAtStand
			local stoodLongEnough = now - bot._wisdomStandSince >= 3.5
			-- Only claim after the mark has opened (eta already passed / clock on the interval).
			local interval = MapObjectives.WisdomInterval()
			local mark = math.floor(math.max(0, now) / interval) * interval
			if mark >= interval and now >= mark and (gotXp or stoodLongEnough) then
				bot._wisdomClaimedMark = mark
				bot._wisdomStandSince = nil
				bot._wisdomXpAtStand = nil
			end
		end
	end
	-- Hold still so pluck/channel is not cancelled by micro-moves.
	bot:Action_ClearActions(true)
	return true
end

return MapObjectives
