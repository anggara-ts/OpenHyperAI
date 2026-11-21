-- Rune mode. Walks to bounty and power runes. Wisdom shrine is not handled here.
local RuneMode = {}
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local CustomLoader = require(GetScriptDirectory() .. "/FuncLib/systems/custom_loader")
local RuneRules = require(GetScriptDirectory() .. "/FuncLib/systems/rune_rules")
CustomLoader.ThinkLess = CustomLoader.Enable and CustomLoader.ThinkLess or 1
local bot = GetBot()
local currentMinute = 0
local currentSecond = 0
local hasBottle = false
local runeIds = { RUNE_BOUNTY_1, RUNE_BOUNTY_2, RUNE_POWERUP_1, RUNE_POWERUP_2 }
-- After 1:00, a rune the status calls available but the game says is not there (GetRuneType -1)
-- while its spot is in our vision counts as missing, for every check in this file. Game 016: the
-- 2:00 water rune on the bottom power spot was taken, the status stayed "up", and Invoker looped
-- pick-up / move-on there from 2:30 to 2:45 (a skip only covered one of the pick-up paths).
-- Before 1:00 the horn spots are left to the no-rune check in the pick-up branch.
-- Every rune is registered for the sweep: bounty gold lies off the spawn point, and an unpicked
-- river rune leaves the next one spawning next to it (user report, game 016).
local function IsRiverRune(id)
	return id == RUNE_POWERUP_1 or id == RUNE_POWERUP_2
end
-- Sweep length: one 160 lap (2.4s) for every rune; a river rune next to an unpicked one lies as
-- close as bounty gold does.
-- Bounty circle walk off (user call); see RuneMode.NoteBountyGrab.
local BOUNTY_SWEEP_ON = false
local function SweepTime(id)
	return 2.4
end
-- Spawn cycle: jungle bounties every 240s (8 logged games: first seen up at 4:00, 8:00, 12:00,
-- 16:00, 20:00 ..., never at 3-minute marks; the bountyDue check below uses the same), river
-- runes every 120s (water at 2:00 and 4:00, power runes from 6:00).
local BOUNTY_CYCLE = 240
local function RuneCycle(id)
	return IsRiverRune(id) and 120 or BOUNTY_CYCLE
end
-- What is at a river rune spot the API cannot pick up (game 017: river gold seen in game, type -1
-- or type 5 with pick-ups failing at distance 0). Prints units and dropped items within 350 of
-- the spawn point, once per spot per 60s.
local function LogRuneSpot(id, why)
	bot._runeSpotLogAt = bot._runeSpotLogAt or {}
	if DotaTime() < (bot._runeSpotLogAt[id] or -999) then
		return
	end
	bot._runeSpotLogAt[id] = DotaTime() + 60
	local loc = GetRuneSpawnLocation(id)
	local units, items = {}, {}
	for _, unit in pairs(GetUnitList(UNIT_LIST_ALL) or {}) do
		if unit ~= nil and not unit:IsNull() and GetUnitToLocationDistance(unit, loc) <= 350 and not unit:IsHero() then
			units[#units + 1] = unit:GetUnitName()
		end
	end
	for _, droppedItem in pairs(GetDroppedItemList() or {}) do
		if droppedItem ~= nil and droppedItem.item ~= nil and droppedItem.location ~= nil then
			local dx, dy = droppedItem.location.x - loc.x, droppedItem.location.y - loc.y
			if dx * dx + dy * dy <= 350 * 350 then
				items[#items + 1] = droppedItem.item:GetName()
			end
		end
	end
	local okT, rType = pcall(GetRuneType, id)
	pcall(
		print,
		string.format(
			"[OHA-RUNE] t=%.1f spot rune=%s why=%s type=%s status=%s units=%s items=%s",
			DotaTime(),
			tostring(id),
			why,
			tostring(okT and rType),
			tostring(GetRuneStatus(id)),
			#units > 0 and table.concat(units, ",") or "-",
			#items > 0 and table.concat(items, ",") or "-"
		)
	)
end
local RawGetRuneStatus = GetRuneStatus
local function GetRuneStatus(id)
	local status = RawGetRuneStatus(id)
	-- A river rune a bot found empty on arrival (type -1, the pick-up failed) reads missing until the next spawn.
	-- Game 043, 25:10: the old rule here (available + type -1 + spot in vision = missing) hid a real power rune
	-- (`spot rune=1 type=-1 status=1`, Pudge 425 away) and the team walked past it. Type -1 alone is no proof.
	if
		status == RUNE_STATUS_AVAILABLE
		and bot._staleCycle ~= nil
		and bot._staleCycle[id] == math.floor(DotaTime() / RuneCycle(id))
	then
		return RUNE_STATUS_MISSING
	end
	return status
end
local hpRatio, mpRatio, botPosition, activeMode, activeModeDesire, assignedLane
local nearbyAllies, nearbyEnemies
local humanClaimTime = {}
-- Early-game console trace. Grep [OHA-RUNE]. While a bot is within 1600 of a rune before 6:10
-- (covers the 2:00 and 4:00 water runes and the 6:00 power rune): a line whenever the reason
-- changes, and a stuck line at most every 10s (was one a second per bot until game 037).
local RUNE_DBG_UNTIL = 370
local runeWhy = "none"
local dbgAt = -100
local dbgWhy = ""
local dbgLoc = nil
local dbgStuckLogAt = -100
-- Diagnostic (#32, maintainer: bots walk right past a power rune without taking it). When a power rune is up
-- within 600 and this decision is something else, say which rule won. At most every 20s per bot.
local function IsPickupWhy(why)
	return why == "underfoot" or string.sub(why, 1, 6) == "power-" or string.sub(why, 1, 7) == "status-"
end
local function LogPowerRuneSkip(why)
	if IsPickupWhy(tostring(why)) or DotaTime() < 0 or DotaTime() < (bot._powerSkipLogAt or -999) then
		return
	end
	for _, id in ipairs({ RUNE_POWERUP_1, RUNE_POWERUP_2 }) do
		if GetRuneStatus(id) == RUNE_STATUS_AVAILABLE then
			local runeType = GetRuneType(id)
			local dist = GetUnitToLocationDistance(bot, GetRuneSpawnLocation(id))
			if dist <= 600 and runeType ~= RUNE_BOUNTY and not (RUNE_WATER ~= nil and runeType == RUNE_WATER) then
				bot._powerSkipLogAt = DotaTime() + 20
				pcall(
					print,
					string.format(
						"[OHA-RUNE] t=%.0f %s powerrune-near-skip spot=%d type=%s dist=%d why=%s",
						DotaTime(),
						(string.gsub(bot:GetUnitName(), "npc_dota_hero_", "")),
						id,
						tostring(runeType),
						dist,
						tostring(why)
					)
				)
				return
			end
		end
	end
end
local function give(desire, why)
	if why ~= nil then
		runeWhy = why
		pcall(LogPowerRuneSkip, why)
	end
	return desire
end
local function ModeTag(mode)
	if mode == BOT_MODE_NONE then
		return "none"
	end
	if mode == BOT_MODE_LANING then
		return "laning"
	end
	if mode == BOT_MODE_ATTACK then
		return "attack"
	end
	if mode == BOT_MODE_ROAM then
		return "roam"
	end
	if mode == BOT_MODE_RETREAT then
		return "retreat"
	end
	if mode == BOT_MODE_FARM then
		return "farm"
	end
	if mode == BOT_MODE_WARD then
		return "ward"
	end
	if mode == BOT_MODE_RUNE then
		return "rune"
	end
	if mode == BOT_MODE_TEAM_ROAM then
		return "team_roam"
	end
	if BOT_MODE_LOTUS_POOL ~= nil and mode == BOT_MODE_LOTUS_POOL then
		return "lotus"
	end
	if BOT_MODE_WISDOM_SHRINE ~= nil and mode == BOT_MODE_WISDOM_SHRINE then
		return "wisdom"
	end
	if BOT_MODE_OUTPOST ~= nil and mode == BOT_MODE_OUTPOST then
		return "outpost"
	end
	return "m" .. tostring(mode)
end
local function RuneTag(id)
	if id == RUNE_BOUNTY_1 then
		return "b1"
	end
	if id == RUNE_BOUNTY_2 then
		return "b2"
	end
	if id == RUNE_POWERUP_1 then
		return "p1"
	end
	if id == RUNE_POWERUP_2 then
		return "p2"
	end
	return tostring(id)
end
local function StatusTag(status)
	if status == RUNE_STATUS_AVAILABLE then
		return "up"
	end
	if status == RUNE_STATUS_MISSING then
		return "miss"
	end
	if status == RUNE_STATUS_UNKNOWN then
		return "unk"
	end
	return tostring(status)
end
local function ActTag(action)
	if action == BOT_ACTION_TYPE_IDLE then
		return "idle"
	end
	if action == BOT_ACTION_TYPE_MOVE_TO then
		return "move"
	end
	if action == BOT_ACTION_TYPE_ATTACK then
		return "attack"
	end
	if action == BOT_ACTION_TYPE_PICK_UP_RUNE then
		return "pickup"
	end
	if action == BOT_ACTION_TYPE_USE_ABILITY then
		return "ability"
	end
	return "a" .. tostring(action)
end
local function HeroTag()
	local name = string.gsub(bot:GetUnitName() or "?", "npc_dota_hero_", "")
	local team = GetTeam() == TEAM_RADIANT and "r" or "d"
	-- Meepo clones get their own tag: can a clone pick up a rune? (discussion #50, "not confirmed yet")
	return name .. "/" .. team .. (Fu.IsMeepoClone(bot) and "/clone" or "")
end
-- Did the pick-up order take the rune? 1.5s after the order the spot's status says (#50: Meepo clones and runes).
-- One line per order: [OHA-RUNE] <hero>/<team>[/clone] pickup-result rune= taken=yes|no.
local function CheckPickupResult()
	local check = bot._pickupResult
	if check == nil or DotaTime() < check.at + 1.5 then
		return
	end
	bot._pickupResult = nil
	local status = GetRuneStatus(check.id)
	pcall(
		print,
		string.format(
			"[OHA-RUNE] %s t=%.1f pickup-result rune=%s taken=%s status=%s",
			HeroTag(),
			DotaTime(),
			tostring(check.id),
			status == RUNE_STATUS_AVAILABLE and "no" or "yes",
			tostring(status)
		)
	)
end
local function NearRune()
	local bestId, bestDist = nil, math.huge
	local parts = {}
	for idx = 1, #runeIds do
		local rune = runeIds[idx]
		local dist = GetUnitToLocationDistance(bot, GetRuneSpawnLocation(rune))
		parts[#parts + 1] = string.format("%s:%s:%.0f", RuneTag(rune), StatusTag(GetRuneStatus(rune)), dist)
		if dist < bestDist then
			bestId, bestDist = rune, dist
		end
	end
	return bestId, bestDist, table.concat(parts, " ")
end
function RuneMode.RuneDbg(desire)
	local ok, err = pcall(function()
		local now = DotaTime()
		if now > RUNE_DBG_UNTIL then
			return
		end
		local nearId, nearDist, runeList = NearRune()
		local why = runeWhy or "?"
		local inRune = activeMode == BOT_MODE_RUNE
		if nearDist > 1600 and not inRune and (desire or 0) <= 0 then
			return
		end
		local loc = bot:GetLocation()
		local moved = dbgLoc and Fu.GetDistance(dbgLoc, loc) or -1
		local elapsed = now - dbgAt
		local changed = why ~= dbgWhy
		if elapsed < 0.25 or (not changed and elapsed < 1) then
			return
		end
		local stuck = (elapsed >= 0.8 and nearDist <= 900 and moved >= 0 and moved < 40) and 1 or 0
		dbgAt = now
		dbgWhy = why
		dbgLoc = loc
		-- Game 037: 1,318 trace lines in 0:00-2:00 (one a second per bot). Print one line per
		-- decision (why changes), plus a stuck line at most every 10s. Meepo clones stay quiet.
		if Fu.IsMeepoClone(bot) then
			return
		end
		if not changed then
			if stuck == 0 or now < dbgStuckLogAt then
				return
			end
			dbgStuckLogAt = now + 10
		end
		local runeInfo = bot.rune and bot.rune.normal
		local best = "none"
		if runeInfo ~= nil and runeInfo.location ~= nil then
			best = string.format(
				"%s:%s:%.0f",
				RuneTag(runeInfo.location),
				StatusTag(runeInfo.status),
				runeInfo.distance or -1
			)
		end
		print(
			string.format(
				"[OHA-RUNE] %s t=%.1f xy=%.0f,%.0f pos=%s mode=%s/%.2f des=%.2f why=%s best=%s near=%s:%.0f commit=%s n=%d/%d act=%s runeDo=%s moved=%.0f stuck=%d hp=%.2f cant=%s q=%d runes=%s",
				HeroTag(),
				now,
				loc.x,
				loc.y,
				tostring(botPosition),
				ModeTag(activeMode),
				activeModeDesire or 0,
				desire or 0,
				why,
				best,
				RuneTag(nearId),
				nearDist,
				bot._earlyRuneCommit and "1" or "0",
				#(nearbyEnemies or {}),
				#(nearbyAllies or {}),
				ActTag(bot:GetCurrentActionType()),
				tostring(bot._runeDo or "-"),
				moved,
				stuck,
				hpRatio or 0,
				Fu.CanNotUseAction(bot) and "1" or "0",
				bot.NumQueuedActions and bot:NumQueuedActions() or 0,
				runeList
			)
		)
	end)
	if not ok then
		print("[OHA-RUNE] err " .. tostring(err))
	end
end
local function doing(name)
	bot._runeDo = name
	if DotaTime() > RUNE_DBG_UNTIL or name == bot._runeDoPrev or Fu.IsMeepoClone(bot) then
		return
	end
	local nearDist = select(2, NearRune())
	if nearDist > 1600 and DotaTime() > 0 then
		return
	end
	bot._runeDoPrev = name
	local loc = bot:GetLocation()
	print(
		string.format(
			"[OHA-RUNE] %s t=%.1f do=%s xy=%.0f,%.0f mode=%s",
			HeroTag(),
			DotaTime(),
			name,
			loc.x,
			loc.y,
			ModeTag(bot:GetActiveMode())
		)
	)
end
local function IsHumanClaimingRune(runeId)
	local runeLocation = GetRuneSpawnLocation(runeId)
	if humanClaimTime[runeId] and GameTime() - humanClaimTime[runeId] < 5 then
		return true
	end
	for playerIndex = 1, #GetTeamPlayers(GetTeam()) do
		local member = GetTeamMember(playerIndex)
		if member ~= nil and member:IsAlive() and not member:IsBot() then
			if GetUnitToLocationDistance(member, runeLocation) < 2000 then
				humanClaimTime[runeId] = GameTime()
				return true
			end
			local ping = member:GetMostRecentPing()
			if
				ping ~= nil
				and ping.normal_ping
				and Fu.GetDistance(ping.location, runeLocation) < 800
				and GameTime() - ping.time < 5
			then
				humanClaimTime[runeId] = GameTime()
				return true
			end
		end
	end
	return false
end
-- [OHA-RUNE] watch: every 20s, all game, one bot per team prints all four rune slots: status,
-- type, time since seen, whether the spot is in vision, and the closest ally bot with its mode.
-- For river spots with an ally within 1200 it also prints the spot log (units and items there).
-- To see why a rune that is lying there is not taken (game 017, 16:50: top river spot with an
-- arcane rune and gold, nobody took them; the trace stops at 6:10).
local function IsTeamLogger()
	for i = 1, 5 do
		local member = GetTeamMember(i)
		if member ~= nil and member:IsBot() then
			return member == bot
		end
	end
	return false
end
-- Other rune ids at a river spot. The bot API has RUNE_BOUNTY_1..4 from the old map, but these
-- bots only track 4 ids. Game 019, 0:00: the river gold lay right under Medusa (top) and Queen of
-- Pain, Pudge and Techies (bottom) for 13s, read as a bounty on the river power-rune id, and
-- PickUpRune on that id did nothing. If the horn gold sits under another id at the same spot, a
-- pickup on that id may work. Ids 0-7 whose spawn point is within 400 of the river spot.
local altIds = {}
local function AltRuneIds(id)
	if altIds[id] ~= nil then
		return altIds[id]
	end
	local list = {}
	local okB, base = pcall(GetRuneSpawnLocation, id)
	if okB and base ~= nil then
		for candidateId = 0, 7 do
			local tracked = false
			for _, trackedId in ipairs(runeIds) do
				if trackedId == candidateId then
					tracked = true
				end
			end
			if not tracked then
				local okL, loc = pcall(GetRuneSpawnLocation, candidateId)
				if okL and loc ~= nil and (loc - base):Length2D() <= 400 then
					list[#list + 1] = candidateId
				end
			end
		end
	end
	altIds[id] = list
	return list
end
-- One-time probe per team at the horn (0.0-1.5s) and once before it (-60s): rune ids 0-7 with
-- their constant name, spawn point, status and type.
local RUNE_NAMES = {}
for _, pair in ipairs({
	{ RUNE_POWERUP_1, "RUNE_POWERUP_1" },
	{ RUNE_POWERUP_2, "RUNE_POWERUP_2" },
	{ RUNE_BOUNTY_1, "RUNE_BOUNTY_1" },
	{ RUNE_BOUNTY_2, "RUNE_BOUNTY_2" },
	{ RUNE_BOUNTY_3, "RUNE_BOUNTY_3" },
	{ RUNE_BOUNTY_4, "RUNE_BOUNTY_4" },
}) do
	if pair[1] ~= nil then
		RUNE_NAMES[pair[1]] = pair[2]
	end
end
function RuneMode.RuneProbe()
	local now = DotaTime()
	local stage = (now >= -60 and now < -50) and "pre" or (now >= 0 and now <= 1.5) and "horn" or nil
	if stage == nil or RuneMode["_runeProbe_" .. stage] or not IsTeamLogger() then
		return
	end
	RuneMode["_runeProbe_" .. stage] = true
	local parts = {}
	for probeId = 0, 7 do
		local okL, loc = pcall(GetRuneSpawnLocation, probeId)
		local okS, status = pcall(GetRuneStatus, probeId)
		local okT, runeType = pcall(GetRuneType, probeId)
		parts[#parts + 1] = string.format(
			"%d(%s):loc=%s st=%s ty=%s",
			probeId,
			RUNE_NAMES[probeId] or "-",
			(okL and loc ~= nil) and string.format("%.0f,%.0f", loc.x, loc.y) or "err",
			okS and tostring(status) or "err",
			okT and tostring(runeType) or "err"
		)
	end
	pcall(
		print,
		string.format(
			"[OHA-RUNE] t=%.1f probe-%s %s %s",
			now,
			stage,
			GetTeam() == TEAM_RADIANT and "radiant" or "dire",
			table.concat(parts, " ")
		)
	)
end
-- Water runes (2:00, 4:00): the bot API never reports them at the river spot (game 031, 4:02: the
-- top spot read "missing" though seen 2s before, the rune lying there), and only Valve's default
-- item mode picks them up, for a bot close by. So the ally closest to a river spot (within 2200,
-- not outnumbered there) walks to it from 8s before the spawn and holds it until 8s after.
-- The river gold at the horn too (game 031: OD stood on the bottom spot, laning pulled him to mid
-- 0.3s after the horn, the gold stayed; Valve's item mode took the top one only at 0:06, at 0.90).
-- After the spawn the hold desire is 0.35: above laning (0.27-0.30), below the item mode's 0.90,
-- so the item mode takes over as soon as it wants the rune.
local WATER_AT = { 0, 120, 240 }
local RIVER_HOLD_DESIRE = 0.35
function RuneMode.WaterWalk()
	local now = DotaTime()
	local waterWalk = bot._waterWalk
	if waterWalk ~= nil then
		if not bot:IsAlive() or now > waterWalk.t0 + 8 then
			bot._waterWalk = nil
			return nil
		end
		if GetUnitToLocationDistance(bot, waterWalk.loc) <= 200 then
			return now < waterWalk.t0 and "hold" or "near"
		end
		return "walk"
	end
	bot._waterDone = bot._waterDone or {}
	for _, spawnTime in ipairs(WATER_AT) do
		if now >= spawnTime - 8 and now <= spawnTime + 4 then
			for _, id in ipairs({ RUNE_POWERUP_1, RUNE_POWERUP_2 }) do
				local key = spawnTime .. ":" .. id
				local loc = GetRuneSpawnLocation(id)
				if
					not bot._waterDone[key]
					-- Not the hero who just planted the early mid ward: he goes behind his T1 and to lane.
					and not (spawnTime == 0 and bot._earlyWardPlantedAt ~= nil)
					and GetUnitToLocationDistance(bot, loc) <= 2200
					and RuneMode.IsTheClosestAlly(bot, loc)
					and #(Fu.GetEnemiesNearLoc(loc, 1000) or {}) <= #(Fu.GetAlliesNearLoc(loc, 1000) or {}) + 1
				then
					bot._waterDone[key] = true
					bot._waterWalk = { id = id, loc = loc, t0 = spawnTime }
					return "walk"
				end
			end
		end
	end
	return nil
end
-- River gold / water rune left at a river spot after the hold ended (#32, game 062, 0:00): a fight started at the
-- top spot at the horn, Nature's Prophet stood 15 from the rune in attack mode (0.95), the water-walk hold ran out
-- 8s after the spawn, everyone left (no-best) and the rune lay there until 0:35-0:55. Bots can't pick it up
-- (UnpickableRiverRune below), Valve's item mode can, for a bot close by. So while a river spot shows a bounty or
-- water rune that our team sees right now (an unseen spot's status is stale: game 062 kept taken runes "up"), the
-- nearest bot in lane or farm mode within 1600, not hit by a hero, walks back and stands on the spot so the item
-- mode takes it. Gives up when the rune is gone, 60s after the spawn, after 6s on the spot with the rune still
-- reading up, or below 30% HP. Up to 3 tries per spawn (a fight in between ends a try, another can start after).
-- Desire while walking 0.70: the active mode reads ~1.1x its desire (game 062: `mode=rune/0.58 des=0.53`), and an
-- active farm mode read 0.66 (earth_spirit t=1289), so this must clear ~0.66; laning reads 0.27-0.30. Below attack
-- (0.95) and retreat. On the spot 0.60, as river-item-stay: Valve's item mode (0.90) beat that at the horn.
-- [OHA-RUNE] river-bounty-return (start) / river-return-end why= (result).
local RIVER_RETURN_WALK_DESIRE = 0.70
local RIVER_RETURN_HOLD_DESIRE = 0.60
local RIVER_RETURN_RANGE = 1600
local RIVER_RETURN_GIVE_UP = 60
local RIVER_RETURN_ON_SPOT = 6
local RIVER_RETURN_TRIES = 3
local RIVER_SPOT_RADIUS = 200
local function RiverRuneSeenUp(id)
	if GetRuneStatus(id) ~= RUNE_STATUS_AVAILABLE then
		return false
	end
	local okV, visible = pcall(IsLocationVisible, GetRuneSpawnLocation(id))
	if not okV or not visible then
		return false
	end
	local okT, runeType = pcall(GetRuneType, id)
	return okT and (runeType == RUNE_BOUNTY or RUNE_WATER ~= nil and runeType == RUNE_WATER)
end
local function FreeForRiverReturn(unit)
	local mode = unit:GetActiveMode()
	return (mode == BOT_MODE_LANING or mode == BOT_MODE_FARM)
		and not unit:WasRecentlyDamagedByAnyHero(2.0)
		and Fu.GetHP(unit) >= 0.4
end
local function RiverSpotContested(loc)
	local enemiesAtSpot = #(Fu.GetEnemiesNearLoc(loc, 900) or {})
	local alliesAtSpot = #(Fu.GetAlliesNearLoc(loc, 900) or {})
	if GetUnitToLocationDistance(bot, loc) > 900 then
		alliesAtSpot = alliesAtSpot + 1
	end
	return enemiesAtSpot > alliesAtSpot or bot:WasRecentlyDamagedByAnyHero(1.5) and enemiesAtSpot >= 1
end
-- Another ally is on it already: its own return for this spot and spawn, or standing on the spot in rune / item mode.
local function RiverReturnClaimed(id, spawn, loc)
	for i = 1, 5 do
		local member = GetTeamMember(i)
		if Fu.IsValidHero(member) and member ~= bot then
			local claim = member._riverReturn
			if claim ~= nil and claim.id == id and claim.spawn == spawn then
				return true
			end
			local mode = member:GetActiveMode()
			if
				(mode == BOT_MODE_RUNE or mode == BOT_MODE_ITEM)
				and GetUnitToLocationDistance(member, loc) <= RIVER_SPOT_RADIUS + 100
			then
				return true
			end
		end
	end
	return false
end
local function EndRiverReturn(why)
	local riverReturn = bot._riverReturn
	bot._riverReturn = nil
	if riverReturn == nil then
		return
	end
	if why ~= "fight" and why ~= "hp" and why ~= "far" then
		bot._riverReturnDone = bot._riverReturnDone or {}
		bot._riverReturnDone[riverReturn.spawn .. ":" .. riverReturn.id] = RIVER_RETURN_TRIES
	end
	pcall(
		print,
		string.format(
			"[OHA-RUNE] t=%.0f %s river-return-end why=%s spot=%d dist=%d took=%.0fs status=%s",
			DotaTime(),
			(string.gsub(bot:GetUnitName(), "npc_dota_hero_", "")),
			why,
			riverReturn.id,
			GetUnitToLocationDistance(bot, riverReturn.loc),
			DotaTime() - riverReturn.t0,
			StatusTag(GetRuneStatus(riverReturn.id))
		)
	)
end
-- Returns "walk" / "near" while a return is on, nil otherwise.
function RuneMode.RiverBountyReturn()
	local now = DotaTime()
	local riverReturn = bot._riverReturn
	if riverReturn ~= nil then
		local dist = GetUnitToLocationDistance(bot, riverReturn.loc)
		if not bot:IsAlive() then
			EndRiverReturn("dead")
		elseif GetRuneStatus(riverReturn.id) ~= RUNE_STATUS_AVAILABLE then
			EndRiverReturn("gone")
		elseif now > riverReturn.spawn + RIVER_RETURN_GIVE_UP then
			EndRiverReturn("timeout")
		elseif Fu.GetHP(bot) < 0.3 then
			EndRiverReturn("hp")
		elseif dist > RIVER_RETURN_RANGE + 800 then
			-- Another mode (a chase, a defend) took it far away.
			EndRiverReturn("far")
		elseif RiverSpotContested(riverReturn.loc) then
			EndRiverReturn("fight")
		elseif dist <= RIVER_SPOT_RADIUS then
			riverReturn.onSpotAt = riverReturn.onSpotAt or now
			if now - riverReturn.onSpotAt > RIVER_RETURN_ON_SPOT then
				EndRiverReturn("stale")
			else
				return "near"
			end
		else
			return "walk"
		end
		return nil
	end
	if now < 0 then
		return nil
	end
	local spawn = math.floor(now / RuneCycle(RUNE_POWERUP_1)) * RuneCycle(RUNE_POWERUP_1)
	if now > spawn + RIVER_RETURN_GIVE_UP or not FreeForRiverReturn(bot) then
		return nil
	end
	bot._riverReturnDone = bot._riverReturnDone or {}
	for _, id in ipairs({ RUNE_POWERUP_1, RUNE_POWERUP_2 }) do
		local key = spawn .. ":" .. id
		local loc = GetRuneSpawnLocation(id)
		local dist = GetUnitToLocationDistance(bot, loc)
		if
			(bot._riverReturnDone[key] or 0) < RIVER_RETURN_TRIES
			and dist <= RIVER_RETURN_RANGE
			and RiverRuneSeenUp(id)
			and not RiverSpotContested(loc)
			and not RiverReturnClaimed(id, spawn, loc)
		then
			-- The nearest of the free allies (a fighting one closer to it doesn't count).
			local nearest = true
			for i = 1, 5 do
				local member = GetTeamMember(i)
				if
					Fu.IsValidHero(member)
					and member ~= bot
					and FreeForRiverReturn(member)
					and GetUnitToLocationDistance(member, loc) < dist
				then
					nearest = false
					break
				end
			end
			if nearest then
				bot._riverReturnDone[key] = (bot._riverReturnDone[key] or 0) + 1
				bot._riverReturn = { id = id, loc = loc, spawn = spawn, t0 = now }
				local okT, runeType = pcall(GetRuneType, id)
				pcall(
					print,
					string.format(
						"[OHA-RUNE] t=%.0f %s river-bounty-return spot=%d dist=%d type=%s since=%.0fs mode=%s try=%d",
						now,
						(string.gsub(bot:GetUnitName(), "npc_dota_hero_", "")),
						id,
						dist,
						tostring(okT and runeType),
						now - spawn,
						ModeTag(bot:GetActiveMode()),
						bot._riverReturnDone[key]
					)
				)
				return dist <= RIVER_SPOT_RADIUS and "near" or "walk"
			end
		end
	end
	return nil
end
-- Does Action_PickUpRune take a river bounty / water rune in 7.42? Games 015-025 said no (every id, at distance 0).
-- Once per spawn per bot, standing on a river spot (the horn water-hold or a river-bounty-return) with the rune
-- reading up: order the pick-up on the spot's id, and 1.5s later log whether the rune is gone. For those 1.5s rune
-- mode holds at RIVER_PICKUP_TRY_DESIRE (GetDesire) so Valve's item mode doesn't take the rune first and blur the
-- answer. The bot's gold doesn't show who took it (unverified who gets bounty gold), so worked=yes only when the rune
-- is gone, the item mode was never active in between and no other hero stood within 300 of it; worked=unsure when
-- one of those happened.
-- 0.92: above the item mode's 0.90 (game 031 log); ended early by a hero hit or an enemy hero at the spot.
-- Stops for the rest of the game after its first worked=no (game 063: worked=no in all 4 tries, 0:01-4:19), so the
-- probe doesn't keep the item mode off the spot for 1.5s every spawn.
local RIVER_PICKUP_TRY_DESIRE = 0.92
function RuneMode.RiverPickupTry(id, spawn)
	bot._riverPickupTried = bot._riverPickupTried or {}
	local key = spawn .. ":" .. id
	if
		bot._riverPickupNo
		or bot._riverPickupTried[key]
		or bot._riverPickup ~= nil
		or GetRuneStatus(id) ~= RUNE_STATUS_AVAILABLE
	then
		return false
	end
	bot._riverPickupTried[key] = true
	local okT, runeType = pcall(GetRuneType, id)
	bot._riverPickup = {
		id = id,
		at = DotaTime(),
		gold = bot:GetGold(),
		type = okT and runeType or nil,
		mode = bot:GetActiveMode(),
		itemMode = false,
		others = false,
	}
	bot:Action_PickUpRune(id)
	return true
end
local function OtherHeroAtSpot(loc)
	for _, list in ipairs({ UNIT_LIST_ALLIED_HEROES, UNIT_LIST_ENEMY_HEROES }) do
		for _, hero in pairs(GetUnitList(list) or {}) do
			if
				Fu.IsValidHero(hero)
				and hero ~= bot
				and not hero:IsIllusion()
				and GetUnitToLocationDistance(hero, loc) <= 300
			then
				return true
			end
		end
	end
	return false
end
function RuneMode.RiverPickupCheck()
	local pickup = bot._riverPickup
	if pickup == nil then
		return
	end
	if bot:GetActiveMode() == BOT_MODE_ITEM then
		pickup.itemMode = true
	end
	if not pickup.others and OtherHeroAtSpot(GetRuneSpawnLocation(pickup.id)) then
		pickup.others = true
	end
	if DotaTime() < pickup.at + 1.5 then
		return
	end
	bot._riverPickup = nil
	local gone = RawGetRuneStatus(pickup.id) ~= RUNE_STATUS_AVAILABLE
	local worked = not gone and "no" or (pickup.itemMode or pickup.others) and "unsure" or "yes"
	if worked == "no" then
		bot._riverPickupNo = true
	end
	pcall(
		print,
		string.format(
			"[OHA-RUNE] t=%.1f %s river-pickup-try id=%d worked=%s type=%s gold+=%d mode=%s itemMode=%s others=%s now=%s stop=%s",
			DotaTime(),
			(string.gsub(bot:GetUnitName(), "npc_dota_hero_", "")),
			pickup.id,
			worked,
			tostring(pickup.type),
			bot:GetGold() - pickup.gold,
			ModeTag(pickup.mode),
			tostring(pickup.itemMode),
			tostring(pickup.others),
			ModeTag(bot:GetActiveMode()),
			worked == "no" and "yes" or "no"
		)
	)
end
-- Leftover rune (RuneRules.IsLeftover: available, type -1, spot in vision, 10s+ into its cycle; river or jungle).
-- One pick-up order (game 062: it took the rune every time), then stand on the spot with no orders for up to 3s so
-- Valve's item mode can take it (maintainer, game 063: "type -1 probably horn bounty rune (it's still there) so let
-- valve's item mode take it"), then give up on the spot for this spawn cycle. Driven from GetDesire, not Think:
-- once the item mode takes over, this mode's Think stops running, and the timer and result line must still run.
-- Desire 0.70 for the order and the walk onto the spot (clears an active farm mode, as river-bounty-return does),
-- 0.60 on the spot (below Valve's item mode's 0.90, as the horn hold). [OHA-RUNE] leftover-hold / leftover-result.
local LEFTOVER_TRY_DESIRE = 0.70
local LEFTOVER_HOLD_DESIRE = 0.60
local function EndLeftover(why)
	local hold = bot._leftover
	bot._leftover = nil
	if hold == nil then
		return
	end
	local now = DotaTime()
	-- The raw status, before the give-up mark: the wrapper reads missing once it is set (game 063, 30:49: a
	-- `pickup-result taken=yes status=2` 0.2s after `stale-status` was the wrapper, not a pick-up).
	local taken = RawGetRuneStatus(hold.id) ~= RUNE_STATUS_AVAILABLE
	bot._leftoverDone = bot._leftoverDone or {}
	if why ~= "typed" then
		bot._leftoverDone[hold.id] = hold.cycle
	end
	if not taken and (why == "held" or why == "timeout") then
		-- Reads missing for every rule in this file until the next spawn (GetRuneStatus above).
		bot._staleCycle = bot._staleCycle or {}
		bot._staleCycle[hold.id] = hold.cycle
	elseif not taken and why == "fight" then
		RuneMode.SkipRune(hold.id, 20)
	end
	pcall(
		print,
		string.format(
			"[OHA-RUNE] t=%.0f %s leftover-result spot=%d taken=%s why=%s held=%.1f itemMode=%s gold=%d dist=%d",
			now,
			(string.gsub(bot:GetUnitName(), "npc_dota_hero_", "")),
			hold.id,
			taken and "yes" or "no",
			why,
			RuneRules.HeldFor(hold, now),
			hold.itemMode and "yes" or "no",
			bot:GetGold() - hold.gold,
			GetUnitToLocationDistance(bot, hold.loc)
		)
	)
end
-- From the pick-up branch of Think, on the spot (within 130) of a rune RuneRules.IsLeftover says is a leftover.
function RuneMode.LeftoverStart(id, loc, runeType, dist)
	local now = DotaTime()
	local cycle = RuneCycle(id)
	bot._leftover = {
		id = id,
		loc = loc,
		t0 = now,
		cycle = math.floor(now / cycle),
		gold = bot:GetGold(),
		phase = "try",
		itemMode = false,
	}
	bot._runePickTry = nil
	bot._runePickupAt = now
	bot:Action_PickUpRune(id)
	local okS, seen = pcall(GetRuneTimeSinceSeen, id)
	pcall(
		print,
		string.format(
			"[OHA-RUNE] t=%.0f %s leftover-hold spot=%d type=%s since=%.0f dist=%d seen=%s",
			now,
			(string.gsub(bot:GetUnitName(), "npc_dota_hero_", "")),
			id,
			tostring(runeType),
			now % cycle,
			dist,
			okS and type(seen) == "number" and string.format("%.0f", seen) or "?"
		)
	)
end
-- The hold's desire while it is on, nil once it ended (the end writes the result line).
function RuneMode.LeftoverDesire()
	local hold = bot._leftover
	if hold == nil then
		return nil
	end
	if not bot:IsAlive() then
		EndLeftover("dead")
		return nil
	end
	if bot:GetActiveMode() == BOT_MODE_ITEM then
		hold.itemMode = true
	end
	local okT, runeType = pcall(GetRuneType, hold.id)
	local typed = okT and runeType ~= nil and runeType ~= -1 and not (RUNE_INVALID ~= nil and runeType == RUNE_INVALID)
	local phase, why = RuneRules.LeftoverStep(
		hold,
		DotaTime(),
		GetUnitToLocationDistance(bot, hold.loc),
		RawGetRuneStatus(hold.id) == RUNE_STATUS_AVAILABLE,
		typed,
		RiverSpotContested(hold.loc) or Fu.GetHP(bot) < 0.3
	)
	if phase == "end" then
		EndLeftover(why)
		return nil
	end
	hold.phase = phase
	return phase == "hold" and LEFTOVER_HOLD_DESIRE or LEFTOVER_TRY_DESIRE
end
function RuneMode.RuneWatch()
	local now = DotaTime()
	if now < 0 or now < (RuneMode._runeWatchAt or -999) or not IsTeamLogger() then
		return
	end
	RuneMode._runeWatchAt = now + 20
	local parts = {}
	for _, id in ipairs(runeIds) do
		local loc = GetRuneSpawnLocation(id)
		local okT, rType = pcall(GetRuneType, id)
		local okS, seen = pcall(GetRuneTimeSinceSeen, id)
		local okV, vis = pcall(IsLocationVisible, loc)
		local best, bestD = nil, math.huge
		for i = 1, 5 do
			local member = GetTeamMember(i)
			if member ~= nil and member:IsAlive() then
				local distance = GetUnitToLocationDistance(member, loc)
				if distance < bestD then
					best, bestD = member, distance
				end
			end
		end
		parts[#parts + 1] = string.format(
			"%s:%s/t%s/seen%s/vis%s/near=%s:%d:%s",
			RuneTag(id),
			StatusTag(GetRuneStatus(id)),
			tostring(okT and rType),
			okS and type(seen) == "number" and string.format("%.0f", seen) or "?",
			okV and vis and "1" or "0",
			best ~= nil and (string.gsub(best:GetUnitName(), "npc_dota_hero_", "")) or "-",
			math.floor(bestD),
			best ~= nil and ModeTag(best:GetActiveMode()) or "-"
		)
		if IsRiverRune(id) and bestD <= 1200 then
			pcall(LogRuneSpot, id, "watch")
		end
	end
	pcall(
		print,
		string.format(
			"[OHA-RUNE] t=%.0f watch %s %s",
			now,
			GetTeam() == TEAM_RADIANT and "radiant" or "dire",
			table.concat(parts, " ")
		)
	)
end
-- River gold id test (user call): on the gold, try rune ids 0-7 with Action_PickUpRune, then with
-- ActionPush_PickUpRune, 0.4s each, and log the one after which his gold jumps by 30+. Sticky:
-- once started it holds rune mode and the bot at the gold until all 16 tries are done or 0:15
-- (game 024: other rune rules pulled the testers off after 3-4 tries, no result).
function RuneMode.GoldCycleStep()
	local goldCycle = bot._goldCycle
	if goldCycle == nil then
		return false
	end
	local now = DotaTime()
	local function finish(msg)
		pcall(print, msg)
		bot._goldCycle = nil
		bot._goldCycleDone = true
	end
	local gained = bot:GetGold() - goldCycle.g0
	if gained >= 30 and goldCycle.last ~= nil then
		finish(
			string.format(
				"[OHA-RUNE] %s t=%.1f river-gold PICKED spot=%s id=%d order=%s gold+%d",
				HeroTag(),
				now,
				tostring(goldCycle.spot),
				goldCycle.last.id,
				goldCycle.last.push and "ActionPush_PickUpRune" or "Action_PickUpRune",
				gained
			)
		)
		return false
	end
	if now >= 15 or not bot:IsAlive() then
		finish(
			string.format(
				"[OHA-RUNE] %s t=%.1f river-gold test cut at try %d (time or death)",
				HeroTag(),
				now,
				goldCycle.k
			)
		)
		return false
	end
	if GetUnitToLocationDistance(bot, goldCycle.gold) > 40 then
		bot:Action_MoveToLocation(goldCycle.gold)
		doing("river-gold-ids")
		return true
	end
	if now - goldCycle.at < 0.4 then
		doing("river-gold-ids")
		return true
	end
	if goldCycle.k >= 16 then
		finish(
			string.format(
				"[OHA-RUNE] %s t=%.1f river-gold tried ids 0-7 x2 at spot=%s, no gold",
				HeroTag(),
				now,
				tostring(goldCycle.spot)
			)
		)
		return false
	end
	local id = goldCycle.k % 8
	local push = goldCycle.k >= 8
	goldCycle.k = goldCycle.k + 1
	goldCycle.at = now
	goldCycle.g0 = bot:GetGold()
	goldCycle.last = { id = id, push = push }
	bot._runePickupAt = now
	pcall(function()
		if push then
			bot:ActionPush_PickUpRune(id)
		else
			bot:Action_PickUpRune(id)
		end
	end)
	doing("river-gold-ids")
	return true
end
function GetDesire()
	pcall(RuneMode.RuneWatch)
	pcall(RuneMode.RiverPickupCheck)
	if bot._goldCycle ~= nil and DotaTime() < 15 then
		runeWhy = "river-gold-test"
		return BOT_MODE_DESIRE_ABSOLUTE + 0.05
	end
	if ShouldSkipBotThink(GetBot()) then
		runeWhy = "skip"
		RuneMode.RuneDbg(0)
		return 0
	end
	-- The pick-up try (RuneMode.RiverPickupTry): hold rune mode above the item mode for its 1.5s, unless a hero hits
	-- the bot or an enemy hero is at the spot.
	local pickup = bot._riverPickup
	if pickup ~= nil and DotaTime() < pickup.at + 1.5 and GetRuneStatus(pickup.id) == RUNE_STATUS_AVAILABLE then
		local spot = GetRuneSpawnLocation(pickup.id)
		if
			GetUnitToLocationDistance(bot, spot) <= 300
			and not bot:WasRecentlyDamagedByAnyHero(1.5)
			and #(Fu.GetEnemiesNearLoc(spot, 900) or {}) == 0
		then
			runeWhy = "river-pickup-try"
			RuneMode.RuneDbg(RIVER_PICKUP_TRY_DESIRE)
			return RIVER_PICKUP_TRY_DESIRE
		end
	end
	-- A leftover-rune hold (RuneMode.LeftoverDesire): before GetDesireRaw, so no other rune rule (the bounty
	-- passing's 0.97 from #99 included) lifts the bot above the item mode while it stands on the spot.
	if bot._leftover ~= nil then
		local okL, leftoverDesire = pcall(RuneMode.LeftoverDesire)
		if not okL then
			bot._leftover = nil
		elseif leftoverDesire ~= nil then
			runeWhy = "leftover-" .. tostring(bot._leftover and bot._leftover.phase)
			RuneMode.RuneDbg(leftoverDesire)
			return leftoverDesire
		end
	end
	local desire = GetDesireRaw()
	RuneMode.RuneDbg(desire)
	return desire
end
-- Another Meepo body with an enemy hero within 1200 that took hero damage in the last 3s.
function RuneMode.MeepoBodyInFight()
	for _, meepo in pairs(GetUnitList(UNIT_LIST_ALLIED_HEROES) or {}) do
		if
			meepo ~= bot
			and Fu.IsValidHero(meepo)
			and meepo:GetUnitName() == "npc_dota_hero_meepo"
			and meepo:WasRecentlyDamagedByAnyHero(3.0)
			and #(meepo:GetNearbyHeroes(1200, true, BOT_MODE_NONE) or {}) >= 1
		then
			return meepo
		end
	end
	return nil
end
function GetDesireRaw()
	pcall(CheckPickupResult)
	RuneMode.InitRune()
	bot._mapObjKind = nil
	bot._mapObjLoc = nil
	hasBottle = bot:FindItemSlot("item_bottle") >= 0
	hpRatio = Fu.GetHP(bot)
	mpRatio = Fu.GetMP(bot)
	botPosition = Fu.GetPosition(bot)
	activeMode = bot:GetActiveMode()
	activeModeDesire = bot:GetActiveModeDesire()
	assignedLane = bot:GetAssignedLane()
	nearbyAllies = bot:GetNearbyHeroes(1600, false, BOT_MODE_NONE) or {}
	nearbyEnemies = bot:GetNearbyHeroes(1600, true, BOT_MODE_NONE) or {}
	if bot:IsInvulnerable() and hpRatio > 0.9 and bot:DistanceFromFountain() < 500 then
		return give(BOT_MODE_DESIRE_ABSOLUTE, "fountain")
	end
	-- Meepo: no rune / lotus / wisdom trip while another body is fighting (losing one body kills
	-- them all). Game 037, 24:09: one body was in rune mode at (-7802,642) while another died.
	if bot:GetUnitName() == "npc_dota_hero_meepo" and RuneMode.ClosestAvailableRune(300) == nil then
		local fightBody = RuneMode.MeepoBodyInFight()
		if fightBody ~= nil then
			if DotaTime() >= (bot._meepoRuneSkipLogAt or -999) then
				bot._meepoRuneSkipLogAt = DotaTime() + 10
				pcall(
					print,
					string.format(
						"[OHA-MEEPO] t=%.0f %s rune-skip body-in-fight dist=%d",
						DotaTime(),
						Fu.IsMeepoClone(bot) and "clone" or "main",
						GetUnitToUnitDistance(bot, fightBody)
					)
				)
			end
			return give(BOT_MODE_DESIRE_NONE, "meepo-fight")
		end
	end
	do
		local okW, waterState = pcall(RuneMode.WaterWalk)
		if okW and waterState ~= nil and bot._waterWalk ~= nil then
			-- Game 043, 0:00: Ringmaster walked onto the top spot where Pudge, Meepo and Rubick stood (n=3/1), lost
			-- HP before the horn, and the 5s stay held him there (0.69 -> 0.40). Not into more enemy heroes than
			-- ours at the spot, and not while heroes hit us.
			local spot = bot._waterWalk.loc
			local enemiesAtSpot = #(Fu.GetEnemiesNearLoc(spot, 900) or {})
			local alliesAtSpot = #(Fu.GetAlliesNearLoc(spot, 900) or {})
			if GetUnitToLocationDistance(bot, spot) > 900 then
				alliesAtSpot = alliesAtSpot + 1
			end
			local hitByHero = bot:WasRecentlyDamagedByAnyHero(1.5)
			if enemiesAtSpot > alliesAtSpot or hitByHero and enemiesAtSpot >= 1 then
				if DotaTime() >= (bot._waterContestLogAt or -999) then
					bot._waterContestLogAt = DotaTime() + 5
					pcall(
						print,
						string.format(
							"[OHA-RUNE] t=%.0f %s water-skip why=contested enemies=%d allies=%d hit=%s hp=%.2f",
							DotaTime(),
							(string.gsub(bot:GetUnitName(), "npc_dota_hero_", "")),
							enemiesAtSpot,
							alliesAtSpot,
							tostring(hitByHero),
							Fu.GetHP(bot)
						)
					)
				end
				return give(BOT_MODE_DESIRE_NONE, "water-contested")
			end
			if DotaTime() < bot._waterWalk.t0 then
				return give(BOT_MODE_DESIRE_HIGH, "water-" .. waterState)
			end
			-- Bots can't pick a water rune up themselves (see UnpickableRiverRune: every pickup order failed);
			-- Valve's item mode does it while the bot stands there. Game 040, 4:00: the item mode took over for 1s,
			-- then laning (0.56) beat the 0.35 hold and Meepo walked off with the rune still there. For the first
			-- 5s after the spawn, standing on it holds at 0.6 (above laning, below fights and retreat).
			local sinceSpawn = DotaTime() - bot._waterWalk.t0
			-- Not on an empty spot (game 045, 0:08: Viper stood idle on the bottom spot reading missing until the stay
			-- ran out). After 1s on it, a spot that reads missing ends the stay.
			local spotEmpty = sinceSpawn >= 1 and RawGetRuneStatus(bot._waterWalk.id) == RUNE_STATUS_MISSING
			if spotEmpty and bot._waterEmptyLogged ~= bot._waterWalk.t0 then
				bot._waterEmptyLogged = bot._waterWalk.t0
				pcall(
					print,
					string.format(
						"[OHA-RUNE] t=%.0f %s water-stay-end why=empty spot=%d",
						DotaTime(),
						(string.gsub(bot:GetUnitName(), "npc_dota_hero_", "")),
						bot._waterWalk.id
					)
				)
			end
			if spotEmpty then
				return give(BOT_MODE_DESIRE_NONE, "water-empty")
			end
			if sinceSpawn <= 5 and GetUnitToLocationDistance(bot, bot._waterWalk.loc) <= 300 then
				if bot._waterStayLogged ~= bot._waterWalk.t0 then
					bot._waterStayLogged = bot._waterWalk.t0
					pcall(
						print,
						string.format(
							"[OHA-RUNE] t=%.0f %s water-stay spot=%d for=5s",
							DotaTime(),
							(string.gsub(bot:GetUnitName(), "npc_dota_hero_", "")),
							bot._waterWalk.id
						)
					)
				end
				return give(0.6, "river-item-stay")
			end
			return give(RIVER_HOLD_DESIRE, "river-item-" .. waterState)
		end
	end
	-- Back to a river rune left after the hold (RuneMode.RiverBountyReturn); before the lane-busy defer below.
	do
		local okR, returnState = pcall(RuneMode.RiverBountyReturn)
		if okR and returnState ~= nil and bot._riverReturn ~= nil then
			return give(
				returnState == "near" and RIVER_RETURN_HOLD_DESIRE or RIVER_RETURN_WALK_DESIRE,
				"river-bounty-return-" .. returnState
			)
		end
	end
	-- Laning first (user call): while the bot's lane needs it, runes, lotus pools and wisdom
	-- shrines wait unless one is within 500. Re-checked every think, so a deferred spot is taken
	-- once the lane is pushed or empty and the spot is near.
	local laneBusy = RuneMode.LaneBusy()
	-- The lane support contests his side's lotus pool while laning (map_objectives
	-- IsLotusContester): the lane-busy hold does not stop his lotus trip.
	local lotusContest = false
	if laneBusy then
		local okC, isContester = pcall(function()
			return require(GetScriptDirectory() .. "/FuncLib/systems/map_objectives").IsLotusContester(bot)
		end)
		lotusContest = okC and isContester == true
	end
	if laneBusy and DotaTime() >= 15 and not lotusContest then
		local closeRune = RuneMode.ClosestAvailableRune(500)
		if closeRune == nil then
			RuneMode.NoteLaneDefer()
			return give(BOT_MODE_DESIRE_NONE, "lane-busy")
		end
	end
	-- Before the fight bailouts. An enemy near the pool was returning NONE and lotus never started.
	do
		local MapObj = require(GetScriptDirectory() .. "/FuncLib/systems/map_objectives")
		local desire, loc, kind = MapObj.ConsiderObjectiveDesire(bot)
		if
			laneBusy
			and loc ~= nil
			and GetUnitToLocationDistance(bot, loc) > 500
			and not (lotusContest and kind == "lotus")
		then
			desire = 0
		end
		-- A rune within 1000 that reads available (its spot in vision) beats a lotus or wisdom
		-- walk; standing beside the pool as it spawns (absolute desire) still wins. Game 021,
		-- 8:24-8:43: Disruptor was heading for the bottom jungle bounty and turned off to walk
		-- to the bottom lotus pool 17-28s before its spawn.
		local nearRune = RuneMode.ClosestAvailableRune(1000)
		if
			nearRune ~= nil
			and GetRuneStatus(nearRune) == RUNE_STATUS_AVAILABLE
			and desire < BOT_MODE_DESIRE_ABSOLUTE
		then
			desire = 0
		end
		if desire > 0 and loc ~= nil and kind ~= nil then
			bot._mapObjKind = kind
			bot._mapObjLoc = loc
			return give(desire, "mapobj-" .. tostring(kind))
		end
		-- The contester with no lotus trip now: the lane hold applies as usual.
		if lotusContest and DotaTime() >= 15 and RuneMode.ClosestAvailableRune(500) == nil then
			RuneMode.NoteLaneDefer()
			return give(BOT_MODE_DESIRE_NONE, "lane-busy")
		end
	end
	if DotaTime() > 0 and #nearbyEnemies > 0 then
		if #nearbyEnemies > #nearbyAllies then
			return give(BOT_MODE_DESIRE_NONE, "outnumbered")
		end
		if bot:WasRecentlyDamagedByAnyHero(2.0) and hpRatio < 0.4 then
			return give(BOT_MODE_DESIRE_NONE, "hurt")
		end
	end
	-- A rune underfoot still beats a leftover fight. Farther than the bank, lotus and wisdom win.
	local runeId, runeDist = RuneMode.ClosestAvailableRune(400)
	if runeId ~= nil and not RuneMode.IsTheClosestAlly(bot, GetRuneSpawnLocation(runeId)) then
		runeId = nil
	end
	local dying = hpRatio < 0.25 and #nearbyEnemies > 0 and bot:WasRecentlyDamagedByAnyHero(1.2)
	if
		runeId ~= nil
		and not dying
		and not RuneMode.SidelaneSkipsRiver(runeId, runeDist)
		and not RuneMode.SkipSecondLaningRune(runeId)
	then
		local runeInfo = bot.rune.normal
		runeInfo.location = runeId
		runeInfo.distance = runeDist
		runeInfo.status = RUNE_STATUS_AVAILABLE
		runeInfo.type = GetRuneType(runeId)
		return give(BOT_MODE_DESIRE_ABSOLUTE + 0.02, "underfoot")
	end
	-- A leftover bounty sits beside the spawn, not on a second rune id. Stay and walk the ring.
	local sweepDesire = RuneMode.BountySweepDesire()
	if sweepDesire ~= nil then
		return give(sweepDesire, "bounty-sweep")
	end
	-- Passing by (user call): a bounty rune that reads available (the spot is in vision) within
	-- 1000, in any phase and before the pushing / defending gates, when no ally is closer to it
	-- and no enemy is closer or about to take it. Laning used to need it within 500, and after
	-- laning it had to be the "best" rune and the bot not pushing or defending.
	-- Not while enemy heroes are at our Ancient (that exit now comes after this grab).
	if
		not dying
		and hpRatio >= 0.35
		and Fu.Utils.CountEnemyHeroesNear(GetAncient(GetTeam()):GetLocation(), 3200) == 0
	then
		-- Power runes too (user call), with the laning rules for who takes the river runes.
		for _, id in ipairs({ RUNE_BOUNTY_1, RUNE_BOUNTY_2, RUNE_POWERUP_1, RUNE_POWERUP_2 }) do
			if GetRuneStatus(id) == RUNE_STATUS_AVAILABLE then
				local loc = GetRuneSpawnLocation(id)
				local mine = GetUnitToLocationDistance(bot, loc)
				local riverOk = not IsRiverRune(id)
					or not (RuneMode.SidelaneSkipsRiver(id, mine) or RuneMode.SkipSecondLaningRune(id))
				if mine <= 1000 and riverOk and not RuneMode.RuneSkipped(id) and not RuneMode.IsEnemyPickRune(id) then
					local allyCloser = false
					for _, ally in pairs(GetUnitList(UNIT_LIST_ALLIED_HEROES) or {}) do
						if
							ally ~= bot
							and ally:IsAlive()
							and not ally:IsIllusion()
							and GetUnitToLocationDistance(ally, loc) < mine
						then
							allyCloser = true
							break
						end
					end
					if not allyCloser then
						local runeInfo = bot.rune.normal
						runeInfo.location = id
						runeInfo.distance = mine
						runeInfo.status = RUNE_STATUS_AVAILABLE
						runeInfo.type = GetRuneType(id)
						-- No enemy hero near: above a walking push or defend (0.95). Game 048 18:10: Night
						-- Stalker walked past the top jungle bounty 885 away on a push (passing gave 0.75).
						local passDesire = mine <= 600 and BOT_MODE_DESIRE_VERYHIGH or BOT_MODE_DESIRE_HIGH
						if #(Fu.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE) or {}) == 0 then
							passDesire = math.max(passDesire, 0.97)
						end
						return give(passDesire, IsRiverRune(id) and "power-passing" or "bounty-passing")
					end
				end
			end
		end
	end
	-- These three come after the underfoot grab, the sweep and the passing-by grab (game 020, 79:14: Shadow Demon took
	-- the Radiant jungle bounty while his team pushed, and "team-push" stopped the sweep for the
	-- older rune beside it). The sweep only runs within 900 of a spot just taken, for ~2.4s.
	if Fu.Utils.IsTeamPushingSecondTierOrHighGround(bot) then
		return give(BOT_MODE_DESIRE_NONE, "team-push")
	end
	local enemiesAtAncient = Fu.Utils.CountEnemyHeroesNear(GetAncient(GetTeam()):GetLocation(), 3200)
	if enemiesAtAncient >= 1 then
		return give(BOT_MODE_DESIRE_NONE, "ancient")
	end
	if Fu.Utils.CountEnemyHeroesOnHighGround(GetTeam()) >= 2 then
		return give(BOT_MODE_DESIRE_NONE, "highground")
	end
	if not Fu.IsInLaningPhase() then
		if Fu.IsPushing(bot) or Fu.IsDefending(bot) then
			return give(BOT_MODE_DESIRE_NONE, "pushing")
		end
		local currentMode = bot:GetActiveMode()
		if
			currentMode == BOT_MODE_PUSH_TOWER_TOP
			or currentMode == BOT_MODE_PUSH_TOWER_MID
			or currentMode == BOT_MODE_PUSH_TOWER_BOT
		then
			return give(BOT_MODE_DESIRE_NONE, "push-mode")
		end
	end
	if DotaTime() >= 60 and DotaTime() < 7 * 60 then
		local laningRuneRange = 2500
		if
			activeMode == BOT_MODE_RUNE
			and bot.rune
			and bot.rune.normal
			and bot.rune.normal.location ~= nil
			and bot.rune.normal.location ~= -1
			and GetUnitToLocationDistance(bot, GetRuneSpawnLocation(bot.rune.normal.location)) < laningRuneRange
		then
			local runeStatus = GetRuneStatus(bot.rune.normal.location)
			local here = GetUnitToLocationDistance(bot, GetRuneSpawnLocation(bot.rune.normal.location))
			-- 2:00 and 4:00 river runes are the mid's. A sidelaner who camped the
			-- 0:00 gold stays through the water spawn and picks up both.
			if runeStatus == RUNE_STATUS_AVAILABLE or runeStatus == RUNE_STATUS_UNKNOWN then
				-- A skipped rune too: game 021, 1:28-2:26, Medusa stayed by the top river spot on
				-- "laning-close" with the horn gold there given up as unpickable (skipped).
				if
					RuneMode.SidelaneSkipsRiver(bot.rune.normal.location, here)
					or RuneMode.SkipSecondLaningRune(bot.rune.normal.location)
					or RuneMode.RuneSkipped(bot.rune.normal.location)
				then
					-- fall through and let lane desire win
				elseif runeStatus == RUNE_STATUS_AVAILABLE and here <= 800 then
					return give(BOT_MODE_DESIRE_ABSOLUTE, "laning-close")
				else
					return give(BOT_MODE_DESIRE_VERYHIGH, "laning-hold")
				end
			end
		end
		local laningDesire = RuneMode.GetLaningRuneDesire(laningRuneRange)
		if laningDesire > 0 then
			return give(laningDesire, "laning")
		end
	end
	if bot.rune and bot.rune.normal then
		local searchRange = Fu.IsInLaningPhase() and 1600 or 1200
		local runeInfo = bot.rune.normal
		runeInfo.location, runeInfo.distance = RuneMode.GetBestRune()
		if runeInfo.distance > 4000 and DotaTime() >= 60 * 2 then
			return give(BOT_MODE_DESIRE_NONE, "too-far")
		end
		if DotaTime() < 0 and not bot:WasRecentlyDamagedByAnyHero(10.0) then
			return give(BOT_MODE_DESIRE_MODERATE, "pre-horn")
		end
		if not Fu.IsInLaningPhase() and runeInfo.distance > 2000 then
			return give(BOT_MODE_DESIRE_NONE, "post-lane-far")
		end
		if runeInfo.location ~= -1 then
			runeInfo.type = GetRuneType(runeInfo.location)
			runeInfo.status = GetRuneStatus(runeInfo.location)
			local runeLocation = GetRuneSpawnLocation(runeInfo.location)
			if runeInfo.distance < 1200 then
				for _, allyHero in pairs(nearbyAllies) do
					if
						allyHero ~= nil
						and not allyHero:IsBot()
						and GetUnitToLocationDistance(allyHero, runeLocation) < 2000
					then
						return give(BOT_MODE_DESIRE_NONE, "human-near")
					end
				end
			end
			if runeInfo.location == RUNE_BOUNTY_1 or runeInfo.location == RUNE_BOUNTY_2 then
				if
					runeInfo.status == RUNE_STATUS_AVAILABLE
					and (
						RuneMode.IsTeamMustSaveRune(runeInfo.location)
						or not Fu.IsInLaningPhase()
						or GetUnitToLocationDistance(bot, runeLocation) <= 500
					)
				then
					if RuneMode.IsEnemyPickRune(runeInfo.location) then
						return give(BOT_MODE_DESIRE_NONE, "enemy-closer")
					end
					local desire
					if hasBottle or botPosition >= 4 and not RuneMode.IsThereAllyWithBottle(runeLocation, 1600) then
						desire = RuneMode.GetScaledDesire(BOT_MODE_DESIRE_VERYHIGH, runeInfo.distance, 3500)
					else
						desire = RuneMode.GetScaledDesire(BOT_MODE_DESIRE_HIGH, runeInfo.distance, 3500)
					end
					return give(RuneMode.ApplyEarlyLaneRuneGate(desire, runeInfo.distance, runeInfo.status, "bounty"))
				elseif
					runeInfo.status == RUNE_STATUS_UNKNOWN
					and runeInfo.distance <= searchRange * 1.5
					and DotaTime() > 3 * 60 + 50
					and (currentMinute % 4 == 0 or currentMinute % 4 == 3 and currentSecond > 45)
				then
					return give(
						RuneMode.GetScaledDesire(BOT_MODE_DESIRE_HIGH, runeInfo.distance, searchRange),
						"bounty-unknown"
					)
				elseif
					runeInfo.status == RUNE_STATUS_MISSING
					and runeInfo.distance <= searchRange * 1.5
					and DotaTime() > 3 * 60 + 50
					and (currentMinute % 4 == 3 or currentSecond > 52)
				then
					return give(
						RuneMode.GetScaledDesire(BOT_MODE_DESIRE_HIGH, runeInfo.distance, searchRange * 2.5),
						"bounty-missing"
					)
				end
			else
				if runeInfo.status == RUNE_STATUS_AVAILABLE then
					if RuneMode.IsEnemyPickRune(runeInfo.location) then
						return give(BOT_MODE_DESIRE_NONE, "enemy-closer")
					end
					local runeType = runeInfo.type
					local desire
					if runeType == RUNE_WATER and (hasBottle or hpRatio < 0.6 or mpRatio < 0.5) then
						desire = RuneMode.GetScaledDesire(BOT_MODE_DESIRE_HIGH, runeInfo.distance, 3200)
					elseif runeType == RUNE_WATER and not hasBottle then
						desire = RuneMode.GetScaledDesire(BOT_MODE_DESIRE_HIGH, runeInfo.distance, searchRange)
					else
						local isMidLaning = assignedLane == LANE_MID and Fu.IsInLaningPhase()
						if hasBottle or not Fu.IsEarlyGame() and botPosition <= 3 then
							local baseDesire = isMidLaning and BOT_MODE_DESIRE_VERYHIGH or BOT_MODE_DESIRE_HIGH
							desire = RuneMode.GetScaledDesire(baseDesire, runeInfo.distance, searchRange * 2.5)
						else
							desire =
								RuneMode.GetScaledDesire(BOT_MODE_DESIRE_HIGH, runeInfo.distance, searchRange * 2.5)
						end
					end
					-- Starting river gold/bounty sits on power-rune spots — gate early lane oscillation.
					return give(RuneMode.ApplyEarlyLaneRuneGate(desire, runeInfo.distance, runeInfo.status, "power"))
				elseif runeInfo.status == RUNE_STATUS_UNKNOWN and DotaTime() > 113 then
					if hasBottle or not Fu.IsEarlyGame() and botPosition <= 3 then
						return give(
							RuneMode.GetScaledDesire(BOT_MODE_DESIRE_HIGH, runeInfo.distance, searchRange * 2.5),
							"power-unknown"
						)
					else
						return give(
							RuneMode.GetScaledDesire(BOT_MODE_DESIRE_HIGH, runeInfo.distance, searchRange),
							"power-unknown"
						)
					end
				elseif
					runeInfo.status == RUNE_STATUS_MISSING
					and DotaTime() > 60
					and (currentMinute % 2 == 1 and currentSecond > 53)
				then
					return give(
						RuneMode.GetScaledDesire(BOT_MODE_DESIRE_HIGH, runeInfo.distance, searchRange),
						"power-missing"
					)
				elseif
					runeInfo.status == RUNE_STATUS_UNKNOWN
					and RuneMode.IsTeamMustSaveRune(runeInfo.location)
					and DotaTime() > 113
					and runeInfo.distance <= searchRange * 2
				then
					return give(
						RuneMode.GetScaledDesire(BOT_MODE_DESIRE_HIGH, runeInfo.distance, searchRange * 2),
						"power-save"
					)
				end
			end
			return give(BOT_MODE_DESIRE_NONE, "status-" .. StatusTag(runeInfo.status))
		end
		return give(BOT_MODE_DESIRE_NONE, "no-best")
	end
	return give(BOT_MODE_DESIRE_NONE, "no-rune")
end
local bottle = nil
function OnStart()
	local bottleSlot = bot:FindItemSlot("item_bottle")
	if bot:GetItemSlotType(bottleSlot) == ITEM_SLOT_TYPE_MAIN then
		bottle = bot:GetItemInSlot(bottleSlot)
	end
end
function OnEnd()
	bottle = nil
end
local nextPreHoldMoveTime = -math.huge
function Think()
	bot._runeDo = "fall"
	if bot._waterWalk ~= nil then
		if GetUnitToLocationDistance(bot, bot._waterWalk.loc) > 200 then
			bot:Action_MoveToLocation(bot._waterWalk.loc)
			doing("water-walk")
			return
		end
		-- On the spot: stand still, for Valve's item mode to take over and pick the rune up. Once per spawn, try
		-- the pick-up order too (RuneMode.RiverPickupTry: does 7.42 allow it?).
		if DotaTime() >= bot._waterWalk.t0 then
			pcall(RuneMode.RiverPickupTry, bot._waterWalk.id, bot._waterWalk.t0)
		end
		doing("water-hold")
		return
	end
	if bot._riverReturn ~= nil then
		if GetUnitToLocationDistance(bot, bot._riverReturn.loc) > RIVER_SPOT_RADIUS then
			bot:Action_MoveToLocation(bot._riverReturn.loc)
			doing("river-return-walk")
			return
		end
		pcall(RuneMode.RiverPickupTry, bot._riverReturn.id, bot._riverReturn.spawn)
		doing("river-return-hold")
		return
	end
	-- A leftover-rune hold (RuneMode.LeftoverStart gave the one pick-up order): wait for it, walk onto the spot,
	-- then stand there with no orders for Valve's item mode.
	local leftover = bot._leftover
	if leftover ~= nil then
		if leftover.phase == "try" then
			doing("leftover-try")
			return
		end
		if GetUnitToLocationDistance(bot, leftover.loc) > RuneRules.ON_SPOT then
			leftover.stopped = nil
			bot:Action_MoveToLocation(leftover.loc)
			doing("leftover-walk")
			return
		end
		if not leftover.stopped then
			leftover.stopped = true
			bot:Action_ClearActions(true)
		end
		doing("leftover-hold")
		return
	end
	if bot._goldCycle ~= nil then
		local okG, held = pcall(RuneMode.GoldCycleStep)
		if okG and held then
			return
		end
	end
	if bot:IsInvulnerable() and bot:DistanceFromFountain() < 500 then
		bot:Action_MoveToLocation(bot:GetLocation() + RandomVector(500))
		doing("fountain")
		return
	end
	if Fu.CanNotUseAction(bot) then
		doing("cant-act")
		return
	end
	-- Opening buys go to the stash once the hero has left the shop. Stay until they
	-- are in the bag, and walk back if something was stashed anyway.
	if DotaTime() < 20 and bot:GetStashValue() > 0 and bot:DistanceFromFountain() > 500 then
		bot:Action_MoveToLocation(Fu.GetTeamFountain())
		doing("stash-back")
		return
	end
	if DotaTime() < -70 and bot._openingShopDone ~= true and bot:DistanceFromFountain() < 2200 then
		if bot:DistanceFromFountain() > 350 then
			bot:Action_MoveToLocation(Fu.GetTeamFountain())
		end
		doing("pre-shop")
		return
	end
	if RuneMode.ThinkBountySweep() then
		return
	end
	-- A pick-up order in progress is left to finish for up to 3s while the bot is within 600 of
	-- the spawn spot. The rune is not always on the spawn point (game 016: water rune and gold on
	-- the bottom power spot); the engine walks to it, the bot passed 130 from the spawn point, the
	-- move-on below cancelled the pick-up, and Medusa, Doom and Invoker went back and forth. It
	-- was protected for 0.6s only. A pick-up that never lands is still reissued after that.
	if bot:GetCurrentActionType() == BOT_ACTION_TYPE_PICK_UP_RUNE then
		local target = bot.rune and bot.rune.normal and bot.rune.normal.location
		local near = target ~= nil and GetUnitToLocationDistance(bot, GetRuneSpawnLocation(target)) < 600
		if bot._runePickupAt ~= nil and DotaTime() - bot._runePickupAt < (near and 3 or 0.6) then
			doing("pickup-wait")
			return
		end
	end
	-- Lotus / wisdom shrine fallback (same gather logic as dedicated modes).
	if bot._mapObjKind ~= nil and bot._mapObjLoc ~= nil then
		local MapObj = require(GetScriptDirectory() .. "/FuncLib/systems/map_objectives")
		MapObj.ThinkObjective(bot, bot._mapObjLoc, bot._mapObjKind)
		doing("mapobj-" .. tostring(bot._mapObjKind))
		return
	end
	if DotaTime() < 0 then
		if Fu.IsModeTurbo() and DotaTime() < -50 then
			doing("pre-wait")
			return
		end
		local enemiesNearby = bot:GetNearbyHeroes(1200, true, BOT_MODE_NONE)
		local alliesNearby = bot:GetNearbyHeroes(1200, false, BOT_MODE_NONE)
		if #enemiesNearby > #alliesNearby and #enemiesNearby >= 2 then
			local laneFrontLocation = GetLaneFrontLocation(GetTeam(), assignedLane or bot:GetAssignedLane(), -1500)
			bot:Action_MoveToLocation(laneFrontLocation)
			doing("pre-flee")
			return
		end
		if DotaTime() < -10 then
			local goOutLocation = RuneMode.GetGoOutLocation()
			if GetUnitToLocationDistance(bot, goOutLocation) > 300 then
				bot:Action_MoveToLocation(goOutLocation)
				doing("pre-out")
				return
			else
				if DotaTime() >= nextPreHoldMoveTime then
					bot:Action_MoveToLocation(goOutLocation + RandomVector(150))
					nextPreHoldMoveTime = DotaTime() + RandomFloat(1, 3)
					doing("pre-hold")
					return
				end
			end
			doing("pre-hold")
			return
		end
		if GetTeam() == TEAM_RADIANT then
			if assignedLane == LANE_BOT then
				bot:Action_MoveToLocation(RuneMode.PickerSpot(RUNE_BOUNTY_2))
				doing("pre-bounty2")
				return
			else
				bot:Action_MoveToLocation(RuneMode.PickerSpot(RUNE_POWERUP_1))
				doing("pre-power1")
				return
			end
		else
			if assignedLane == LANE_TOP then
				bot:Action_MoveToLocation(RuneMode.PickerSpot(RUNE_BOUNTY_1))
				doing("pre-bounty1")
				return
			else
				bot:Action_MoveToLocation(RuneMode.PickerSpot(RUNE_POWERUP_2))
				doing("pre-power2")
				return
			end
		end
	end
	if bot.rune and bot.rune.normal then
		local searchRadius = math.min(bot:GetAttackRange() + 150, 1200)
		local enemiesInRange = Fu.GetEnemiesNearLoc(bot:GetLocation(), searchRadius)
		local enemyCreeps = bot:GetNearbyCreeps(searchRadius, true)
		local runeInfo = bot.rune.normal
		local runeLocation = GetRuneSpawnLocation(runeInfo.location)
		local liveDist = GetUnitToLocationDistance(bot, runeLocation)
		local isPowerRuneSpot = runeInfo.location == RUNE_POWERUP_1 or runeInfo.location == RUNE_POWERUP_2
		if
			isPowerRuneSpot
			and DotaTime() >= 60
			and DotaTime() < 7 * 60
			and runeInfo.status ~= RUNE_STATUS_AVAILABLE
			and not IsLocationVisible(runeLocation)
		then
			if GetUnitToLocationDistance(bot, runeLocation) > 50 then
				bot:Action_MoveToLocation(runeLocation)
				doing("move-unseen")
				return
			end
		end
		-- Don't chase heroes into enemy tower after gold/power rune bait.
		local function CanHarassNearRune(enemy)
			if not Fu.IsValidHero(enemy) or hpRatio <= 0.35 then
				return false
			end
			local towers = bot:GetNearbyTowers(1000, true)
			if Fu.IsValidBuilding(towers[1]) then
				local towerRange = (towers[1]:GetAttackRange() or 700) + 200
				if GetUnitToUnitDistance(bot, towers[1]) < towerRange then
					return false
				end
				if GetUnitToUnitDistance(enemy, towers[1]) < towerRange + 100 then
					-- Only finish if we can kill them before tower melts us.
					if not Fu.CanKillTarget(enemy, bot:GetAttackDamage() * 2.0, DAMAGE_TYPE_PHYSICAL) then
						return false
					end
				end
			end
			local myDmg = bot:GetEstimatedDamageToTarget(false, enemy, 5.0, DAMAGE_TYPE_ALL)
			local theirDmg = enemy:GetEstimatedDamageToTarget(true, bot, 5.0, DAMAGE_TYPE_ALL)
			return 1.5 * myDmg > theirDmg
		end
		if runeInfo.status == RUNE_STATUS_AVAILABLE then
			if RuneMode.BackUpPicker(runeInfo.location) then
				return
			end
			-- Pickup from the bank does not collect a river rune. Walk onto the point.
			-- If that walk makes no progress, leave so the lane is not abandoned.
			if liveDist > 130 then
				if liveDist <= 900 and RuneMode.RuneReachFailed(runeInfo.location, liveDist) then
					RuneMode.SkipRune(runeInfo.location, 25)
					local lane = assignedLane or bot:GetAssignedLane()
					bot:Action_MoveToLocation(GetLaneFrontLocation(GetTeam(), lane, -600))
					doing("give-up")
					return
				end
				if bottle and Fu.CanCastAbility(bottle) and liveDist < 1200 then
					local bottleCharges = bottle:GetCurrentCharges()
					if bottleCharges > 0 and (hpRatio ~= 1 or mpRatio ~= 1) then
						bot:Action_UseAbility(bottle)
						doing("bottle")
						return
					end
				end
				if liveDist > 900 then
					for _, enemyHero in pairs(enemiesInRange) do
						if CanHarassNearRune(enemyHero) then
							bot:Action_AttackUnit(enemyHero, true)
							doing("harass")
							return
						end
					end
					if
						Fu.IsValid(enemyCreeps[1])
						and Fu.CanBeAttacked(enemyCreeps[1])
						and Fu.CanKillTarget(enemyCreeps[1], bot:GetAttackDamage(), DAMAGE_TYPE_PHYSICAL)
					then
						bot:Action_AttackUnit(enemyCreeps[1], true)
						doing("lasthit")
						return
					end
				end
				bot:Action_MoveToLocation(runeLocation)
				doing("move-on")
				return
			end
			bot._runeReach = nil
			local now0 = DotaTime()
			local laneBack = GetLaneFrontLocation(GetTeam(), assignedLane or bot:GetAssignedLane(), -600)
			-- Skipped: leave it now (game 016: Medusa went back to a skipped spot every 3s, the
			-- target rune was kept after the skip).
			if RuneMode.RuneSkipped(runeInfo.location) then
				bot:Action_MoveToLocation(laneBack)
				doing("skipped")
				return
			end
			-- The status says up but nothing is there (GetRuneType -1, game 016 at the horn on both
			-- power spots): skip it at once.
			local rType = GetRuneType and GetRuneType(runeInfo.location) or nil
			-- Just spawned (first 10s of its cycle, the horn included): keep ordering the pick-up as
			-- before. Game 017 at 0:00: the rune read as not there yet, the empty-spot check
			-- started the sweep at 0.3s, the rune then counted as missing and the bot left; only
			-- one horn gold was taken.
			local freshSpawn = now0 < 10 or now0 % RuneCycle(runeInfo.location) < 10
			if freshSpawn then
				if IsRiverRune(runeInfo.location) and liveDist < 100 and now0 % RuneCycle(runeInfo.location) >= 3 then
					pcall(LogRuneSpot, runeInfo.location, "fresh-still-there")
				end
				bot._runePickTry = nil
				bot._runePickupAt = now0
				-- Standing right on the spawn point, the pick-up does nothing (games 015-021: Medusa
				-- and Pudge at distance 0 on the river spots, 13s of orders, no gold; game 014: the
				-- one taken was walked onto from ~390 away). After 1.5s of orders within 80 of the
				-- spot, step back 160 toward our side and order the pick-up from there, so the
				-- order walks onto the rune. One step-back per second at most.
				-- Two phases: walk 160 back (held until there, at most 1s; build 016 re-ordered the
				-- pick-up on the very next think, so the walk lasted one frame: game 022, OD and
				-- Techies moved 15 in 2s on the bottom river spot), then order the pick-up from
				-- there so the walk-in collects it. Again after 1.5s more within 80.
				local freshTry = bot._freshTry
				if freshTry == nil or freshTry.id ~= runeInfo.location or now0 - freshTry.last > 3 then
					freshTry = { id = runeInfo.location, first = now0, last = now0 }
					bot._freshTry = freshTry
				end
				freshTry.last = now0
				-- River gold lies off the reported spawn point (user pings, game 022): top (-1677, 1188)
				-- vs the API's (-1640, 1112), bottom (1137, -1124) vs (1180, -1216), the same offset
				-- of about (-40, +85) both times. The bots stood on the reported point, ~90 from it.
				-- Walk onto the gold, then order the pick-up there.
				if IsRiverRune(runeInfo.location) and rType == RUNE_BOUNTY then
					local gold = runeLocation + Vector(-40, 85, 0)
					if not freshTry.goldLogged then
						freshTry.goldLogged = true
						pcall(
							print,
							string.format(
								"[OHA-RUNE] %s t=%.1f river-gold spot=%s gold=%.0f,%.0f dist=%.0f",
								HeroTag(),
								now0,
								tostring(runeInfo.location),
								gold.x,
								gold.y,
								GetUnitToLocationDistance(bot, gold)
							)
						)
					end
					-- A teammate is running the id test here: stay where you are and leave the gold to
					-- the tester (bots group up on the rune spots at the start; game 024, three Dire bots
					-- body-blocked each other on the bottom spot).
					if bot._goldCycle == nil then
						for i = 1, 5 do
							local member = GetTeamMember(i)
							if
								member ~= nil
								and member ~= bot
								and member._goldCycle ~= nil
								and member._goldCycle.spot == runeInfo.location
							then
								if GetUnitToLocationDistance(bot, gold) < 160 then
									bot:Action_MoveToLocation(Fu.AdjustLocationWithOffsetTowardsFountain(gold, 200))
								end
								doing("river-gold-hold")
								return
							end
						end
					end
					if GetUnitToLocationDistance(bot, gold) > 40 and now0 - freshTry.first < 4 then
						bot:Action_MoveToLocation(gold)
						doing("river-gold-walk")
						return
					end
					-- On the gold: start the id test (sticky, see RuneMode.GoldCycleStep).
					if
						GetUnitToLocationDistance(bot, gold) <= 60
						and bot._goldCycle == nil
						and not bot._goldCycleDone
					then
						-- One tester per spot: three bots on one spot block each other (game 024).
						local busy = false
						for i = 1, 5 do
							local member = GetTeamMember(i)
							if
								member ~= nil
								and member ~= bot
								and member._goldCycle ~= nil
								and member._goldCycle.spot == runeInfo.location
							then
								busy = true
							end
						end
						if not busy then
							bot._goldCycle =
								{ spot = runeInfo.location, gold = gold, k = 0, at = now0 - 1, g0 = bot:GetGold() }
						end
					end
					if bot._goldCycle ~= nil and RuneMode.GoldCycleStep() then
						return
					end
				end
				if freshTry.backTo ~= nil then
					if now0 < freshTry.backUntil and GetUnitToLocationDistance(bot, freshTry.backTo) > 40 then
						bot:Action_MoveToLocation(freshTry.backTo)
						doing("pickup-stepback")
						return
					end
					freshTry.backTo = nil
					freshTry.first = now0
				end
				if liveDist < 80 and now0 - freshTry.first >= 1.5 then
					freshTry.backTo = Fu.AdjustLocationWithOffsetTowardsFountain(runeLocation, 160)
					freshTry.backUntil = now0 + 1
					if not freshTry.logged then
						freshTry.logged = true
						pcall(
							print,
							string.format(
								"[OHA-RUNE] %s t=%.1f pickup-stepback rune=%s dist=%.0f type=%s",
								HeroTag(),
								now0,
								tostring(runeInfo.location),
								liveDist,
								tostring(rType)
							)
						)
					end
					bot:Action_MoveToLocation(freshTry.backTo)
					doing("pickup-stepback")
					return
				end
				bot:Action_PickUpRune(runeInfo.location)
				doing("pickup-fresh")
				return
			end
			-- Every rune gets the sweep (name kept): bounty gold and river runes both lie off the
			-- spawn point.
			local isBounty = true
			-- Bounty gold can lie off the spawn point: circle the spot (the bounty sweep) before
			-- giving up on it. Skipping straight away cut the sweep out (game 016, 29:20:
			-- Disruptor left the jungle gold).
			bot._bountySwept = bot._bountySwept or {}
			-- One sweep per rune per spawn cycle: a new sweep is only worth it once a new rune can
			-- have spawned (it was a flat 20s, only there to stop back-to-back sweeps).
			local cycle = RuneCycle(runeInfo.location)
			local lastSweep = bot._bountySwept[runeInfo.location]
			local canSweep = BOUNTY_SWEEP_ON
				and isBounty
				and bot._bountySweep == nil
				and (lastSweep == nil or math.floor(lastSweep / cycle) < math.floor(now0 / cycle))
			local function StartSweep(why)
				bot._bountySwept[runeInfo.location] = now0
				bot._bountySweep = {
					id = runeInfo.location,
					seen = now0,
					sweepUntil = now0 + SweepTime(runeInfo.location),
					ringStart = now0,
				}
				bot._runePickTry = nil
				pcall(
					print,
					string.format(
						"[OHA-RUNE] %s t=%.1f bounty-sweep why=%s rune=%s",
						HeroTag(),
						now0,
						why,
						tostring(runeInfo.location)
					)
				)
				doing("sweep-start")
			end
			if IsRiverRune(runeInfo.location) then
				pcall(LogRuneSpot, runeInfo.location, "pickup-branch")
			end
			if canSweep and (rType == -1 or (RUNE_INVALID ~= nil and rType == RUNE_INVALID)) then
				StartSweep("no-rune")
				return
			end
			local typeUnknown = rType == -1 or (RUNE_INVALID ~= nil and rType == RUNE_INVALID)
			if typeUnknown then
				-- Status available, no type, spot in vision: a leftover rune (RuneRules.IsLeftover). One pick-up order,
				-- then hold the spot for Valve's item mode (RuneMode.LeftoverStart); once per spot and spawn cycle. It
				-- replaces the blind pick-up loop (game 063: 14-20 orders per visit at distance 0, every one failed).
				local cycle = RuneCycle(runeInfo.location)
				local okV, visible = pcall(IsLocationVisible, runeLocation)
				bot._leftoverDone = bot._leftoverDone or {}
				if
					bot._leftoverDone[runeInfo.location] ~= math.floor(now0 / cycle)
					and RuneRules.IsLeftover(
						RawGetRuneStatus(runeInfo.location) == RUNE_STATUS_AVAILABLE,
						rType,
						RUNE_INVALID,
						okV and visible,
						now0 % cycle
					)
				then
					RuneMode.LeftoverStart(runeInfo.location, runeLocation, rType, liveDist)
					doing("leftover-try")
					return
				end
				pcall(
					print,
					string.format(
						"[OHA-RUNE] %s t=%.1f no-rune rune=%s dist=%.0f",
						HeroTag(),
						now0,
						tostring(runeInfo.location),
						liveDist
					)
				)
				bot._runePickTry = nil
				RuneMode.SkipRune(runeInfo.location, 30)
				bot:Action_MoveToLocation(laneBack)
				doing("no-rune")
				return
			end
			-- On the rune and the pick-up keeps not happening (game 015, 2:28: Medusa went back and forth on the
			-- bottom water rune, pick-up action, 64 moved in 10s): at most 3 orders, 1s apart (RuneRules.PickupStep; it
			-- counted thinks before, 19 orders in 3s), then skip it for 30s and say so.
			local now = DotaTime()
			if
				bot._runePickTry == nil
				or bot._runePickTry.id ~= runeInfo.location
				-- 8s since the last order (not the first): a pick-up in progress waits up to 3s per order (pickup-wait
				-- above), so 3 orders can take 9s and a reset from the first order would never let it fail.
				or now - (bot._runePickTry.last or bot._runePickTry.first) > 8
			then
				bot._runePickTry = { id = runeInfo.location, first = now, n = 0 }
			end
			local pickStep = RuneRules.PickupStep(bot._runePickTry, now)
			if pickStep == "wait" then
				doing("pickup-wait")
				return
			end
			if pickStep == "fail" and canSweep then
				StartSweep("pickup-failed")
				return
			end
			if pickStep == "fail" then
				pcall(
					print,
					string.format(
						"[OHA-RUNE] %s t=%.1f pickup-failed rune=%s tries=%d dist=%.0f type=%s",
						HeroTag(),
						now,
						tostring(runeInfo.location),
						bot._runePickTry.n,
						liveDist,
						tostring(GetRuneType and GetRuneType(runeInfo.location) or "?")
					)
				)
				bot._runePickTry = nil
				-- River gold (a bounty on a power spot) that will not pick up stays that way: skip
				-- it until the next power rune spawn (every 2 min), not just 30s, so the water or
				-- power rune that spawns there is still taken.
				local skipFor = 30
				if IsRiverRune(runeInfo.location) and GetRuneType and GetRuneType(runeInfo.location) == RUNE_BOUNTY then
					skipFor = math.max(30, 120 - (now % 120) + 1)
				end
				RuneMode.SkipRune(runeInfo.location, skipFor)
				local failedType = GetRuneType and GetRuneType(runeInfo.location)
				if
					IsRiverRune(runeInfo.location)
					and (failedType == -1 or (RUNE_INVALID ~= nil and failedType == RUNE_INVALID))
				then
					bot._staleCycle = bot._staleCycle or {}
					bot._staleCycle[runeInfo.location] = math.floor(now / RuneCycle(runeInfo.location))
					pcall(
						print,
						string.format(
							"[OHA-RUNE] %s t=%.1f stale-status rune=%s (available, type -1, nothing to pick up)",
							HeroTag(),
							now,
							tostring(runeInfo.location)
						)
					)
				end
				bot:Action_MoveToLocation(GetLaneFrontLocation(GetTeam(), assignedLane or bot:GetAssignedLane(), -600))
				doing("pickup-failed")
				return
			end
			bot._runePickTry.n = bot._runePickTry.n + 1
			bot._runePickTry.last = now
			bot._runePickupAt = now
			RuneMode.NoteBountyGrab(runeInfo.location)
			RuneMode.NoteLaneRuneTake(runeInfo.location)
			-- A real rune (game 016: water rune) and the pick-up from ~110 away kept failing: from the second order on,
			-- step onto the spawn spot first, then pick up.
			if liveDist > 60 and bot._runePickTry.n >= 2 then
				bot:Action_MoveToLocation(runeLocation)
				bot:ActionQueue_PickUpRune(runeInfo.location)
				doing("step-pickup")
				return
			end
			bot:Action_PickUpRune(runeInfo.location)
			if bot._pickupResult == nil then
				bot._pickupResult = { id = runeInfo.location, at = DotaTime() }
			end
			doing("pickup")
			return
		else
			if liveDist > 500 then
				for _, enemyHero in pairs(enemiesInRange) do
					if CanHarassNearRune(enemyHero) then
						bot:Action_AttackUnit(enemyHero, true)
						doing("harass")
						return
					end
				end
				if
					Fu.IsValid(enemyCreeps[1])
					and Fu.CanBeAttacked(enemyCreeps[1])
					and Fu.CanKillTarget(enemyCreeps[1], bot:GetAttackDamage(), DAMAGE_TYPE_PHYSICAL)
				then
					bot:Action_AttackUnit(enemyCreeps[1], true)
					doing("lasthit")
					return
				end
			end
			local step = math.max(0, liveDist - 280)
			local stand = Fu.Site.GetXUnitsTowardsLocation(bot, runeLocation, step) or runeLocation
			bot.rune.location = stand
			bot:Action_MoveToLocation(stand)
			doing("move-down")
			return
		end
	end
	doing("no-target")
end
function RuneMode.InitRune()
	if bot.rune == nil then
		bot.rune = {
			normal = { time = 0, type = nil, location = nil, distance = 0, status = RUNE_STATUS_MISSING },
			location = nil,
		}
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
-- The circle walk around a jungle bounty spot after a pickup is off (user call): in the logged
-- games it ran 66 times and found 1 extra rune, held the bot 2.4s after every bounty, and since build
-- 045 bounties no longer stack; a leftover rune is picked up by Valve's item mode (BOUNTY_SWEEP_ON, top of file).
function RuneMode.NoteBountyGrab(runeId)
	if not BOUNTY_SWEEP_ON then
		return
	end
	local now = DotaTime()
	local sweep = bot._bountySweep
	if sweep == nil or sweep.id ~= runeId or (sweep.sweepUntil ~= nil and now > sweep.sweepUntil) then
		bot._bountySweep = { id = runeId, seen = now }
		return
	end
	if sweep.sweepUntil == nil then
		sweep.seen = now
	end
end
function RuneMode.BountySweepState()
	if not BOUNTY_SWEEP_ON then
		bot._bountySweep = nil
		return nil
	end
	local sweep = bot._bountySweep
	if sweep == nil then
		return nil
	end
	local now = DotaTime()
	if sweep.sweepUntil ~= nil and now > sweep.sweepUntil then
		bot._bountySweep = nil
		return nil
	end
	local loc = GetRuneSpawnLocation(sweep.id)
	local dist = GetUnitToLocationDistance(bot, loc)
	local status = GetRuneStatus(sweep.id)
	if sweep.sweepUntil == nil then
		-- Still walking up to the registered rune. The ring starts once that one is gone.
		if status == RUNE_STATUS_AVAILABLE then
			if now - sweep.seen > 1.5 then
				bot._bountySweep = nil
			end
			return nil
		end
		if dist > 900 then
			if now - sweep.seen > 1.5 then
				bot._bountySweep = nil
			end
			return nil
		end
		sweep.sweepUntil = now + SweepTime(sweep.id)
		sweep.ringStart = now
	end
	if dist > 900 then
		return nil
	end
	return sweep, loc, dist, status
end
function RuneMode.BountySweepDesire()
	local sweep, loc, dist, status = RuneMode.BountySweepState()
	if sweep == nil then
		return nil
	end
	local runeInfo = bot.rune.normal
	runeInfo.location = sweep.id
	runeInfo.distance = dist
	runeInfo.status = status
	runeInfo.type = RUNE_BOUNTY
	return BOT_MODE_DESIRE_ABSOLUTE
end
function RuneMode.ThinkBountySweep()
	local sweep, loc = RuneMode.BountySweepState()
	if sweep == nil then
		return false
	end
	local step = math.floor((DotaTime() - sweep.ringStart) / 0.3)
	local idx = step % #BOUNTY_SWEEP + 1
	local dest = loc + BOUNTY_SWEEP[idx]
	if GetUnitToLocationDistance(bot, dest) <= 50 then
		bot._runePickupAt = DotaTime()
		RuneMode.NoteLaneRuneTake(sweep.id)
		bot:Action_PickUpRune(sweep.id)
		doing("sweep-pick")
		return true
	end
	bot:Action_MoveToLocation(dest)
	doing("sweep")
	return true
end
function RuneMode.SkipRune(id, seconds)
	bot._runeSkip = bot._runeSkip or {}
	bot._runeSkip[id] = DotaTime() + (seconds or 25)
	bot._earlyRuneCommit = nil
	bot._runeReach = nil
end
-- Team memory (user call): the rune status the bot API gives is per team and stays at its last
-- reading when the spot is fogged, with the time since it was seen. A spot whose last reading is
-- "missing" and was seen after its latest spawn (bounty every 240s, river every 120s) has been
-- checked or picked this cycle by someone on the team: nobody goes there until it spawns again.
-- A spot last seen before its latest spawn is treated as holding a rune; "available" is trusted.
function RuneMode.CheckedEmpty(id)
	local now = DotaTime()
	if now < 0 or GetRuneStatus(id) ~= RUNE_STATUS_MISSING then
		return false
	end
	local okS, seen = pcall(GetRuneTimeSinceSeen, id)
	if not okS or type(seen) ~= "number" or seen < 0 then
		return false
	end
	local cycle = RuneCycle(id)
	local lastSpawn = math.floor(now / cycle) * cycle
	return now - seen >= lastSpawn + 1
end
-- River gold (a bounty on a power spot, the horn) and water runes cannot be picked up by bots: game
-- 025, Medusa stood on the gold (user pings) and tried rune ids 0-7 with Action_PickUpRune and 0-6
-- with ActionPush_PickUpRune, no gold; every game since game 015 failed the same way, water runes
-- included. They are skipped once the game starts; the pre-horn grouping at the rune spots stays.
-- Jungle bounties and river power runes are picked up normally.
local function UnpickableRiverRune(id)
	if not IsRiverRune(id) or DotaTime() < 0 then
		return false
	end
	-- The single-picker attempt (build 037) failed too (game 027): no exception any more.
	local runeType = GetRuneType and GetRuneType(id) or nil
	return runeType == RUNE_BOUNTY or (RUNE_WATER ~= nil and runeType == RUNE_WATER)
end
function RuneMode.RuneSkipped(id)
	if UnpickableRiverRune(id) then
		return true
	end
	local untilAt = bot._runeSkip and bot._runeSkip[id]
	if untilAt ~= nil and DotaTime() < untilAt then
		return true
	end
	return RuneMode.CheckedEmpty(id)
end
function RuneMode.RuneReachFailed(id, dist)
	local now = DotaTime()
	local reach = bot._runeReach
	if reach == nil or reach.id ~= id then
		bot._runeReach = { id = id, since = now, best = dist }
		return false
	end
	if dist + 30 < reach.best then
		reach.best = dist
		reach.since = now
		return false
	end
	local limit = 4
	local loc = GetRuneSpawnLocation(id)
	local mine = GetUnitToLocationDistance(bot, loc)
	for playerIndex = 1, 5 do
		local member = GetTeamMember(playerIndex)
		if
			Fu.IsValidHero(member)
			and member ~= bot
			and member:IsAlive()
			and GetUnitToLocationDistance(member, loc) + 80 < mine
		then
			limit = 2
			break
		end
	end
	return now - reach.since >= limit
end
-- The bot's lane needs it: laning phase, the bot within 1500 of its lane's creep front, an enemy
-- lane creep within 1000 of it, and the lane not pushed (its front farther than 1000 from the
-- enemy T1 of that lane).
local LANE_T1 = { [LANE_TOP] = TOWER_TOP_1, [LANE_MID] = TOWER_MID_1, [LANE_BOT] = TOWER_BOT_1 }
function RuneMode.LaneBusy()
	if not Fu.IsInLaningPhase() or not bot:IsAlive() then
		return false
	end
	local lane = assignedLane or bot:GetAssignedLane()
	local front = GetLaneFrontLocation(GetTeam(), lane, 0)
	if front == nil or GetUnitToLocationDistance(bot, front) > 1500 then
		return false
	end
	local theirs = #(bot:GetNearbyLaneCreeps(1000, true) or {})
	if theirs == 0 then
		return false
	end
	-- Pushed: the front within 1600 of their T1 (was 1000), or our creeps near him clearly
	-- outnumber theirs (game 023, 3:00: Disruptor's lane pushed, he was by the bottom lotus pool
	-- and the deferral still held).
	local t1 = LANE_T1[lane] and GetTower(GetOpposingTeam(), LANE_T1[lane]) or nil
	if t1 ~= nil and GetUnitToLocationDistance(t1, front) <= 1600 then
		return false
	end
	if #(bot:GetNearbyLaneCreeps(1000, false) or {}) >= theirs + 2 then
		return false
	end
	return true
end
-- Once per 10s per bot: a rune or objective was set aside for the lane.
function RuneMode.NoteLaneDefer()
	local now = DotaTime()
	if now < (bot._laneDeferLogAt or -999) then
		return
	end
	bot._laneDeferLogAt = now + 10
	pcall(print, string.format("[OHA-RUNE] %s t=%.0f lane-busy defer", HeroTag(), now))
end
function RuneMode.ClosestAvailableRune(maxDist)
	local best, bestDist = nil, maxDist or 700
	local now = DotaTime()
	for _, rune in pairs(runeIds) do
		-- Jungle bounties spawn every 4 minutes and report missing until the bot has vision.
		local bountyDue = (rune == RUNE_BOUNTY_1 or rune == RUNE_BOUNTY_2)
			and now >= BOUNTY_CYCLE - 10
			and now % BOUNTY_CYCLE <= 50
		if
			GetRuneStatus(rune) == RUNE_STATUS_AVAILABLE or (bountyDue and GetRuneStatus(rune) ~= RUNE_STATUS_MISSING)
		then
			if RuneMode.RuneSkipped(rune) then
				goto continue_rune
			end
			local dist = GetUnitToLocationDistance(bot, GetRuneSpawnLocation(rune))
			if dist < bestDist then
				best = rune
				bestDist = dist
			end
		end
		::continue_rune::
	end
	return best, bestDist
end
function RuneMode.IsSuitableToPickRune()
	if RuneMode.IsNearRune(bot, 550) then
		return true
	end
	local runeLocation = GetRuneSpawnLocation(bot.rune.normal.location)
	if
		Fu.IsRetreating(bot) and activeModeDesire > BOT_MODE_DESIRE_HIGH
		or #nearbyEnemies >= 1 and #Fu.GetHeroesTargetingUnit(nearbyEnemies, bot) > 0
		or bot:WasRecentlyDamagedByAnyHero(5.0) and Fu.IsRetreating(bot)
		or GetUnitToUnitDistance(bot, GetAncient(GetTeam())) < 2500 and DotaTime() > 0
		or GetUnitToUnitDistance(bot, GetAncient(GetOpposingTeam())) < 4000
		or bot:HasModifier("modifier_item_shadow_amulet_fade")
	then
		return false
	end
	return true
end
function RuneMode.IsNearRune(unit, radius)
	radius = radius or 600
	for _, runeId in pairs(runeIds) do
		local runeLocation = GetRuneSpawnLocation(runeId)
		if GetUnitToLocationDistance(unit, runeLocation) <= radius then
			return true
		end
	end
	return false
end
function RuneMode.NoteLaneRuneTake(id)
	if DotaTime() >= 6 * 60 then
		return
	end
	bot._laneRuneTaken = { id = id, untilAt = DotaTime() + 25 }
end
function RuneMode.SkipSecondLaningRune(id)
	local taken = bot._laneRuneTaken
	if taken == nil or DotaTime() >= 6 * 60 or DotaTime() > taken.untilAt then
		return false
	end
	return id ~= taken.id
end
-- After the horn, the river spot is the mid's. 0:00 gold and 2:00 water share it,
-- and a sidelaner who stays there picks up both.
function RuneMode.SidelaneSkipsRiver(id, dist)
	if id ~= RUNE_POWERUP_1 and id ~= RUNE_POWERUP_2 then
		return false
	end
	local now = DotaTime()
	if now < 50 or now >= 6 * 60 then
		return false
	end
	if botPosition == 2 then
		return false
	end
	return (dist or 99999) > 160
end
function RuneMode.GetBestRune()
	currentMinute = math.floor(DotaTime() / 60)
	currentSecond = DotaTime() % 60
	local bestRune = -1
	local bestDistance = math.huge
	for _, runeId in pairs(runeIds) do
		local runeLocation = GetRuneSpawnLocation(runeId)
		if
			RuneMode.IsTheClosestAlly(bot, runeLocation)
			and not RuneMode.IsPingedByHumanPlayer(runeLocation, math.huge)
			and not IsHumanClaimingRune(runeId)
			and not RuneMode.RuneSkipped(runeId)
			and not RuneMode.IsMissing(runeId)
		then
			-- The horn gold on power-rune spots is for whoever stands closest. Leaving it to a
			-- nearby core stalled both, since the core is not the closest ally.
			local hornGold = DotaTime() < 70
			local dist = GetUnitToLocationDistance(bot, runeLocation)
			if RuneMode.SidelaneSkipsRiver(runeId, dist) or RuneMode.SkipSecondLaningRune(runeId) then
				-- River gold at 0:00 and water at 2:00 share this spot. One mid trip.
			elseif
				runeId == RUNE_BOUNTY_1
				or runeId == RUNE_BOUNTY_2
				or hornGold
				or (Fu.IsCore(bot) or not Fu.IsThereCoreNearby(1200))
			then
				local distance = dist
				if distance < bestDistance then
					bestRune = runeId
					bestDistance = distance
				end
			end
		end
	end
	return bestRune, bestDistance
end
-- One picker per rune (user call): only the ally closest to a rune spot walks onto it; the others
-- back it up from 450 toward our side. Bots grouped on the rune spots at the start and blocked
-- each other's way onto the rune (games 023-025).
local BACKUP_DIST = 450
function RuneMode.PickerSpot(id)
	local loc = GetRuneSpawnLocation(id)
	if RuneMode.IsTheClosestAlly(bot, loc) then
		return loc + RandomVector(50)
	end
	return Fu.AdjustLocationWithOffsetTowardsFountain(loc, BACKUP_DIST)
end
-- Not the picker for this rune while the picker is near it: hold the backup spot. True if it acted.
function RuneMode.BackUpPicker(id)
	local loc = GetRuneSpawnLocation(id)
	if RuneMode.IsTheClosestAlly(bot, loc) then
		return false
	end
	local pickerNear = false
	for i = 1, 5 do
		local member = GetTeamMember(i)
		if member ~= nil and member ~= bot and member:IsAlive() and GetUnitToLocationDistance(member, loc) <= 1500 then
			pickerNear = true
		end
	end
	if not pickerNear then
		return false
	end
	local spot = Fu.AdjustLocationWithOffsetTowardsFountain(loc, BACKUP_DIST)
	if GetUnitToLocationDistance(bot, spot) > 120 then
		bot:Action_MoveToLocation(spot)
	end
	doing("rune-backup")
	return true
end
function RuneMode.IsTheClosestAlly(unit, location)
	local closestAlly = unit
	local closestDistance = GetUnitToLocationDistance(unit, location)
	for playerIndex = 1, 5 do
		local member = GetTeamMember(playerIndex)
		if Fu.IsValidHero(member) then
			local allyDistance = GetUnitToLocationDistance(member, location)
			if allyDistance < closestDistance then
				closestAlly = member
				closestDistance = allyDistance
			end
		end
	end
	-- Keep claim while committed so a slightly closer ally doesn't flip us back to lane.
	if closestAlly ~= unit and unit._earlyRuneCommit and GetUnitToLocationDistance(unit, location) <= 1900 then
		return true
	end
	return closestAlly == unit
end
function RuneMode.IsThereAllyWithBottle(location, radius)
	for playerIndex = 1, 5 do
		local member = GetTeamMember(playerIndex)
		if
			Fu.IsValidHero(member)
			and member ~= bot
			and GetUnitToLocationDistance(member, location) <= radius
			and member:FindItemSlot("item_bottle") >= 0
		then
			return true
		end
	end
	return false
end
function RuneMode.IsTherePosition(position, runeId, radius)
	local runeLocation = GetRuneSpawnLocation(runeId)
	for playerIndex = 1, 5 do
		local member = GetTeamMember(playerIndex)
		if Fu.IsValidHero(member) and Fu.GetPosition(member) == position and bot ~= member then
			local botDistance = GetUnitToLocationDistance(bot, runeLocation)
			local allyDistance = GetUnitToLocationDistance(member, runeLocation)
			if botDistance <= radius and allyDistance <= radius then
				return true
			end
		end
	end
	return false
end
local pingMemorySeconds = 30
function RuneMode.IsPingedByHumanPlayer(location, radius)
	for playerIndex = 1, 5 do
		local member = GetTeamMember(playerIndex)
		if Fu.IsValidHero(member) and not member:IsBot() and GetUnitToLocationDistance(member, location) <= radius then
			local ping = member:GetMostRecentPing()
			if ping then
				if
					not ping.normal_ping
					and Fu.GetDistance(ping.location, location) <= 800
					and GameTime() - ping.time < pingMemorySeconds
				then
					return true
				end
			end
		end
	end
	return false
end
function RuneMode.IsPowerRune(runeId)
	local runeType = GetRuneType(runeId)
	if
		runeType == RUNE_DOUBLEDAMAGE
		or runeType == RUNE_HASTE
		or runeType == RUNE_ILLUSION
		or runeType == RUNE_INVISIBILITY
		or runeType == RUNE_REGENERATION
		or runeType == RUNE_ARCANE
		or runeType == RUNE_SHIELD
	then
		return true
	end
	return false
end
function RuneMode.IsMissing(runeId)
	if currentSecond < 52 and GetRuneStatus(runeId) == RUNE_STATUS_MISSING then
		return true
	end
	return false
end
function RuneMode.IsEnemyPickRune(runeId)
	local runeLocation = GetRuneSpawnLocation(runeId)
	if GetUnitToLocationDistance(bot, runeLocation) < 600 then
		return false
	end
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidHero(enemyHero)
			and not Fu.IsSuspiciousIllusion(enemyHero)
			and (enemyHero:IsFacingLocation(runeLocation, 30) or GetUnitToLocationDistance(enemyHero, runeLocation) < 600)
			and GetUnitToLocationDistance(enemyHero, runeLocation)
				< GetUnitToLocationDistance(bot, runeLocation) + 300
		then
			return true
		end
	end
	return false
end
function RuneMode.IsUnitAroundLocation(location, radius)
	for _, playerId in pairs(GetTeamPlayers(GetOpposingTeam())) do
		if IsHeroAlive(playerId) then
			local lastSeenInfo = GetHeroLastSeenInfo(playerId)
			if lastSeenInfo ~= nil then
				local lastSeen = lastSeenInfo[1]
				if
					lastSeen ~= nil
					and Fu.GetDistance(location, lastSeen.location) <= radius
					and lastSeen.time_since_seen < 1.0
				then
					return true
				end
			end
		end
	end
	return false
end
function RuneMode.GetScaledDesire(baseDesire, distance, maxDistance)
	local maxDesire = 0.92
	if distance > 2000 and (Fu.IsLateGame() or Fu.GetDistanceFromEnemyFountain(bot) < 5500) then
		maxDesire = 0.55
	elseif distance > 1200 then
		maxDesire = 0.85
	end
	local currentHp = Fu.GetHP(bot)
	local desire = Clamp(baseDesire * RemapValClamped(distance, 0, maxDistance, 1, 0.5), 0, maxDesire)
	if currentHp < 0.6 then
		desire = RemapValClamped(currentHp, 0, 0.8, 0, desire)
	end
	return desire
end
-- A rune underfoot must beat laning (cores sit at ~0.57, last-hit at 0.6).
function RuneMode.DesireForNearbyRune(desire, dist, status)
	if status == RUNE_STATUS_AVAILABLE and type(dist) == "number" and dist <= 800 then
		return math.max(desire or 0, BOT_MODE_DESIRE_ABSOLUTE)
	end
	return desire
end
-- After creeps spawn, laning desire (~0.45) fights scaled rune desire and bots oscillate
-- lane ↔ river gold/bounty. Only start a pickup when already close; once committed, stick.
function RuneMode.ApplyEarlyLaneRuneGate(desire, dist, status, tag)
	tag = tag or "gate"
	if desire == nil or desire <= 0 then
		runeWhy = tag .. "-zero"
		return desire or 0
	end
	local now = DotaTime()
	if now <= 0 or now >= 70 then
		bot._earlyRuneCommit = nil
		runeWhy = tag .. "-open"
		return desire
	end
	if status ~= RUNE_STATUS_AVAILABLE then
		bot._earlyRuneCommit = nil
		runeWhy = tag .. "-not-up"
		return BOT_MODE_DESIRE_NONE
	end
	dist = dist or 99999
	local startDist = 1050
	local stickDist = 1900
	-- The horn jungle bounty, while the lanes are still empty (first 30s): start from up to 2200.
	-- Game 023: the Dire bot for the top jungle bounty was pulled into a pre-horn fight, stood
	-- 1450-1600 away at the horn, read "bounty-wait" (start needed 1050) and the gold was left.
	if tag == "bounty" and now < 30 then
		startDist = 2200
		stickDist = 2400
	end
	if dist > stickDist then
		bot._earlyRuneCommit = nil
		runeWhy = tag .. "-far"
		return BOT_MODE_DESIRE_NONE
	end
	if (activeMode == BOT_MODE_RUNE or bot._earlyRuneCommit) and dist <= stickDist then
		bot._earlyRuneCommit = true
		runeWhy = tag .. "-stick"
		return math.max(desire, BOT_MODE_DESIRE_HIGH)
	end
	if dist > startDist then
		runeWhy = tag .. "-wait"
		return BOT_MODE_DESIRE_NONE
	end
	bot._earlyRuneCommit = true
	runeWhy = tag .. "-go"
	return math.max(desire, BOT_MODE_DESIRE_HIGH)
end
local cachedGoOutLocation = nil
function RuneMode.GetGoOutLocation()
	if cachedGoOutLocation then
		return cachedGoOutLocation
	end
	if GetTeam() == TEAM_RADIANT then
		if botPosition == 1 or botPosition == 5 then
			local candidates =
				{ Vector(526.370239, -3893.405762, 256.000000), Vector(1999.415894, -4838.790039, 256.000000) }
			cachedGoOutLocation = candidates[RandomInt(1, #candidates)]
		elseif botPosition == 2 or botPosition == 3 or botPosition == 4 then
			local candidates =
				{ Vector(-3456.702637, 649.725403, 256.000000), Vector(-1945.830322, 60.404663, 128.000000) }
			cachedGoOutLocation = candidates[RandomInt(1, #candidates)]
		end
	elseif GetTeam() == TEAM_DIRE then
		if botPosition == 1 or botPosition == 5 then
			local candidates =
				{ Vector(-1051.021973, 3384.059082, 256.000000), Vector(-2415.422119, 4641.448242, 256.000000) }
			cachedGoOutLocation = candidates[RandomInt(1, #candidates)]
		elseif botPosition == 2 or botPosition == 3 or botPosition == 4 then
			local candidates =
				{ Vector(2734.819580, -1155.105225, 256.000000), Vector(1142.979614, -337.891663, 128.000000) }
			cachedGoOutLocation = candidates[RandomInt(1, #candidates)]
		end
	end
	return cachedGoOutLocation
end
function RuneMode.CouldBlink(location)
	local blinkSlot = bot:FindItemSlot("item_blink")
	if
		bot:GetItemSlotType(blinkSlot) == ITEM_SLOT_TYPE_MAIN
		or (bot:GetUnitName() == "npc_dota_hero_antimage" or bot:GetUnitName() == "npc_dota_hero_queenofpain")
	then
		local blinkAbility = bot:GetItemInSlot(blinkSlot)
		if bot:GetUnitName() == "npc_dota_hero_antimage" then
			blinkAbility = bot:GetAbilityByName("antimage_blink")
		end
		if bot:GetUnitName() == "npc_dota_hero_queenofpain" then
			blinkAbility = bot:GetAbilityByName("queenofpain_blink")
		end
		if Fu.CanCastAbility(blinkAbility) then
			local distance = GetUnitToLocationDistance(bot, location)
			local blinkLocation = Fu.Site.GetXUnitsTowardsLocation(bot, location, 1199)
			if distance <= 500 then
				return false
			elseif distance < 1200 then
				bot:Action_UseAbilityOnLocation(blinkAbility, location)
				return true
			elseif IsLocationPassable(blinkLocation) then
				bot:Action_UseAbilityOnLocation(blinkAbility, blinkLocation)
				return true
			end
		end
	end
	return false
end
function RuneMode.IsTeamMustSaveRune(runeId)
	if GetTeam() == TEAM_DIRE then
		return runeId == RUNE_BOUNTY_1
			or runeId == RUNE_POWERUP_2
			or DotaTime() > 1 * 60 + 45 and runeId == RUNE_POWERUP_1
			or DotaTime() > 10 * 60 + 45 and runeId == RUNE_BOUNTY_2
	else
		return runeId == RUNE_BOUNTY_2
			or runeId == RUNE_POWERUP_1
			or DotaTime() > 1 * 60 + 45 and runeId == RUNE_POWERUP_2
			or DotaTime() > 10 * 60 + 45 and runeId == RUNE_BOUNTY_1
	end
end
function RuneMode.IsHumanDangerPingedRune(runeId)
	local runeLocation = GetRuneSpawnLocation(runeId)
	for playerIndex = 1, #GetTeamPlayers(GetTeam()) do
		local member = GetTeamMember(playerIndex)
		if member ~= nil and member:IsAlive() and not member:IsBot() then
			local ping = member:GetMostRecentPing()
			if
				ping ~= nil
				and not ping.normal_ping
				and Fu.GetDistance(ping.location, runeLocation) <= 400
				and GameTime() - ping.time < 30
			then
				return true
			end
		end
	end
	return false
end
function RuneMode.IsAllyWithBottleCloser(runeId)
	local runeLocation = GetRuneSpawnLocation(runeId)
	local myDistance = GetUnitToLocationDistance(bot, runeLocation)
	for playerIndex = 1, #GetTeamPlayers(GetTeam()) do
		local member = GetTeamMember(playerIndex)
		if
			member ~= nil
			and member ~= bot
			and Fu.IsValidHero(member)
			and member:FindItemSlot("item_bottle") >= 0
			and GetUnitToLocationDistance(member, runeLocation) < myDistance
		then
			return true
		end
	end
	return false
end
function RuneMode.ShouldCheckRuneStatus(runeId)
	local status = GetRuneStatus(runeId)
	return status == RUNE_STATUS_AVAILABLE or status == RUNE_STATUS_UNKNOWN
end
function RuneMode.GetLaningRuneDesire(laningRuneRange)
	local minute = math.floor(DotaTime() / 60)
	local second = DotaTime() % 60
	local isPowerRuneWindow = DotaTime() < 6 * 60
		and (minute % 2 == 1 and second >= 55 or minute % 2 == 0 and second <= 5)
	if isPowerRuneWindow then
		local powerRunes = { RUNE_POWERUP_1, RUNE_POWERUP_2 }
		local bestPowerRune = nil
		local bestPowerStatus = nil
		local bestPowerDistance = laningRuneRange
		for _, runeId in pairs(powerRunes) do
			if botPosition ~= 2 or RuneMode.SkipSecondLaningRune(runeId) or RuneMode.RuneSkipped(runeId) then
				goto continue_power
			end
			local status = GetRuneStatus(runeId)
			if
				(status == RUNE_STATUS_AVAILABLE or status == RUNE_STATUS_UNKNOWN)
				and not RuneMode.IsHumanDangerPingedRune(runeId)
				and not RuneMode.IsAllyWithBottleCloser(runeId)
			then
				local distance = GetUnitToLocationDistance(bot, GetRuneSpawnLocation(runeId))
				if distance < bestPowerDistance then
					bestPowerRune = runeId
					bestPowerDistance = distance
					bestPowerStatus = status
				end
			end
			::continue_power::
		end
		if bestPowerRune ~= nil then
			if bot.rune and bot.rune.normal then
				bot.rune.normal.location = bestPowerRune
				bot.rune.normal.distance = bestPowerDistance
				bot.rune.normal.status = GetRuneStatus(bestPowerRune)
				bot.rune.normal.type = GetRuneType(bestPowerRune)
			end
			return RuneMode.DesireForNearbyRune(
				RuneMode.GetScaledDesire(BOT_MODE_DESIRE_HIGH, bestPowerDistance, 3200),
				bestPowerDistance,
				bestPowerStatus
			)
		end
	end
	if botPosition >= 4 then
		local team = GetTeam()
		local bountyRune = nil
		if team == TEAM_RADIANT and botPosition == 4 or team == TEAM_DIRE and botPosition == 5 then
			bountyRune = RUNE_BOUNTY_1
		elseif team == TEAM_RADIANT and botPosition == 5 or team == TEAM_DIRE and botPosition == 4 then
			bountyRune = RUNE_BOUNTY_2
		end
		if
			bountyRune ~= nil
			and RuneMode.ShouldCheckRuneStatus(bountyRune)
			and not RuneMode.IsHumanDangerPingedRune(bountyRune)
			and not RuneMode.SkipSecondLaningRune(bountyRune)
		then
			local distance = GetUnitToLocationDistance(bot, GetRuneSpawnLocation(bountyRune))
			if distance < laningRuneRange then
				if bot.rune and bot.rune.normal then
					bot.rune.normal.location = bountyRune
					bot.rune.normal.distance = distance
					bot.rune.normal.status = GetRuneStatus(bountyRune)
					bot.rune.normal.type = GetRuneType(bountyRune)
				end
				return RuneMode.DesireForNearbyRune(
					RuneMode.GetScaledDesire(BOT_MODE_DESIRE_VERYHIGH, distance, 3500),
					distance,
					GetRuneStatus(bountyRune)
				)
			end
		end
	end
	local bestRune = nil
	local bestDistance = laningRuneRange
	local allRunes = { RUNE_BOUNTY_1, RUNE_BOUNTY_2, RUNE_POWERUP_1, RUNE_POWERUP_2 }
	for _, runeId in pairs(allRunes) do
		if
			RuneMode.ShouldCheckRuneStatus(runeId)
			and not RuneMode.IsHumanDangerPingedRune(runeId)
			and not RuneMode.IsAllyWithBottleCloser(runeId)
		then
			local distance = GetUnitToLocationDistance(bot, GetRuneSpawnLocation(runeId))
			if
				not RuneMode.SidelaneSkipsRiver(runeId, distance)
				and not RuneMode.SkipSecondLaningRune(runeId)
				and distance < bestDistance
			then
				bestRune = runeId
				bestDistance = distance
			end
		end
	end
	if bestRune ~= nil then
		if bot.rune and bot.rune.normal then
			bot.rune.normal.location = bestRune
			bot.rune.normal.distance = bestDistance
			bot.rune.normal.status = GetRuneStatus(bestRune)
			bot.rune.normal.type = GetRuneType(bestRune)
		end
		return RuneMode.DesireForNearbyRune(
			RuneMode.GetScaledDesire(BOT_MODE_DESIRE_HIGH, bestDistance, laningRuneRange),
			bestDistance,
			GetRuneStatus(bestRune)
		)
	end
	return 0
end
if SafeCall then
	local rawGetDesire = GetDesire
	local rawThink = Think
	if rawGetDesire then
		GetDesire = SafeCall(rawGetDesire, 0, "RUNE_GetDesire")
	end
	if rawThink then
		Think = SafeCall(rawThink, nil, "RUNE_Think")
	end
end
-- [OHA-PERF] timing (#52): FuncLib/systems/perf.lua
do
	local Perf = require(GetScriptDirectory() .. "/FuncLib/systems/perf")
	GetDesire = Perf.Wrap("rune.GetDesire", GetDesire)
	Think = Perf.Wrap("rune.Think", Think)
end
