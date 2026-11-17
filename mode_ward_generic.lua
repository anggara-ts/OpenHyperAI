-- Ward mode. Places observer and sentry wards.
if
	GetBot():IsInvulnerable()
	or not GetBot():IsHero()
	or not string.find(GetBot():GetUnitName(), "hero")
	or GetBot():IsIllusion()
then
	return
end
local WardMode = {}
local bot = GetBot()
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local Ward = require(GetScriptDirectory() .. "/FuncLib/systems/ward")
local CustomLoader = require(GetScriptDirectory() .. "/FuncLib/systems/custom_loader")
local MatchTrace = require(GetScriptDirectory() .. "/FuncLib/systems/match_trace")
local localizationOk, Localization = pcall(require, GetScriptDirectory() .. "/FuncLib/systems/localization")
if not localizationOk then
	Localization = {
		Get = function()
			return nil
		end,
	}
end
CustomLoader.ThinkLess = CustomLoader.Enable and CustomLoader.ThinkLess or 1
local observerCastRange = 500
local sentryCastRange = 500
local observerWard = nil
local sentryWard = nil
local wardSpot = nil
local wardModeOffUntil = -math.huge
-- Switched off on purpose: ping/chat when a ward is planted (user request) and per-try plant logging.
local ANNOUNCE_WARD_PLANT = false
local LOG_PLANT_TRIES = false
local function DispenserSentryCharges(item)
	if item == nil or item.GetSecondaryCharges == nil then
		return 0
	end
	local ok, charges = pcall(function()
		return item:GetSecondaryCharges()
	end)
	if ok and type(charges) == "number" then
		return charges
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
-- Game 031, 0:31: Earthshaker at a top ward spot with a dispenser holding 1 observer kept
-- switching it and never planted; nothing in the log. Each dispenser order is logged.
local function DispLog(step, item, loc, wantObs, obs, sen)
	local okT, tog = pcall(function()
		return item:GetToggleState()
	end)
	pcall(print, string.format(
		"[OHA-WARD] t=%.1f %s dispenser %s want=%s obs=%d sen=%d toggle=%s dist=%.0f",
		DotaTime(),
		(string.gsub(bot:GetUnitName(), "npc_dota_hero_", "")),
		step,
		wantObs and "obs" or "sentry",
		obs,
		sen,
		okT and tostring(tog) or "?",
		GetUnitToLocationDistance(bot, loc)
	))
end
local function DispenserPlant(item, loc, wantObs)
	local now = DotaTime()
	local obs = item:GetCurrentCharges() or 0
	local sen = DispenserSentryCharges(item)
	local pendingTry = bot._dispTry
	if pendingTry ~= nil and (pendingTry.loc ~= loc or pendingTry.wantObs ~= wantObs or now - pendingTry.at > 4) then
		pendingTry = nil
	end
	if pendingTry == nil then
		-- Game 032: all 3 observer plants went in with GetToggleState() true and the first charge count
		-- (observers) dropping, so true = observer active. Switch first when the state is the other one,
		-- then cast 0.4s later; the old cast / watch / switch flow stays as the fallback.
		local okT, tog = pcall(function()
			return item:GetToggleState()
		end)
		if okT and type(tog) == "boolean" and tog ~= wantObs then
			bot._dispTry = { at = now, loc = loc, wantObs = wantObs, obs = obs, sen = sen, toggled = true, recast = true, castAt = now + 0.4 }
			DispLog("pre-toggle", item, loc, wantObs, obs, sen)
			bot:Action_UseAbilityOnEntity(item, bot)
			return true
		end
		bot._dispTry = { at = now, loc = loc, wantObs = wantObs, obs = obs, sen = sen, toggled = false, castAt = now }
		DispLog("cast", item, loc, wantObs, obs, sen)
		bot:Action_UseAbilityOnLocation(item, loc)
		return true
	end
	local gotWanted = wantObs and obs < pendingTry.obs or not wantObs and sen < pendingTry.sen
	local gotOther = wantObs and sen < pendingTry.sen or not wantObs and obs < pendingTry.obs
	if gotWanted then
		DispLog("planted", item, loc, wantObs, obs, sen)
		bot._dispTry = nil
		return false
	end
	if gotOther then
		-- Planted the other kind: switch the dispenser for the next one.
		bot._dispTry = nil
		bot:Action_UseAbilityOnEntity(item, bot)
		pcall(print, string.format("[OHA-WARD] t=%.0f dispenser wrong-mode want=%s toggled", now, wantObs and "obs" or "sentry"))
		return true
	end
	if now - pendingTry.castAt >= 1 and not pendingTry.toggled then
		pendingTry.toggled = true
		pendingTry.recast = true
		pendingTry.castAt = now + 0.5
		DispLog("toggle", item, loc, wantObs, obs, sen)
		bot:Action_UseAbilityOnEntity(item, bot)
		return true
	end
	if pendingTry.recast and now >= pendingTry.castAt then
		pendingTry.recast = false
		pendingTry.castAt = now
		DispLog("recast", item, loc, wantObs, obs, sen)
		bot:Action_UseAbilityOnLocation(item, loc)
	end
	return true
end
-- Console copy at game end only keeps the tail, and the signout fills most of it.
-- Remember plants during the match and print them once POST_GAME starts.
local planted = {}
local dumped = false
local function PickChat(key, fallback)
	local msg = Localization.Get(key)
	if type(msg) == "table" and #msg > 0 then
		return msg[RandomInt(1, #msg)]
	end
	if type(msg) == "string" then
		return msg
	end
	return fallback
end
local function RememberWard(kind)
	if wardSpot == nil or wardSpot.location == nil then
		return
	end
	local x = math.floor(wardSpot.location.x)
	local y = math.floor(wardSpot.location.y)
	local now = DotaTime()
	local last = planted[#planted]
	if last and last.kind == kind and last.x == x and last.y == y and now - last.t < 20 then
		return
	end
	planted[#planted + 1] = { t = now, kind = kind, role = wardSpot.role or "spot", x = x, y = y }
	if #planted > 40 then
		table.remove(planted, 1)
	end
end
local function DumpWards()
	if dumped or GetGameState() ~= DOTA_GAMERULES_STATE_POST_GAME then
		return
	end
	dumped = true
	local name = string.gsub(bot:GetUnitName() or "bot", "npc_dota_hero_", "")
	print(string.format("[OHA-WARD] %s n=%d", name, #planted))
	for idx = 1, #planted do
		local entry = planted[idx]
		print(string.format("[OHA-WARD] %s %s t=%.0f role=%s %d,%d", name, entry.kind, entry.t, entry.role, entry.x, entry.y))
	end
end
local function AnnounceWard(kind)
	RememberWard(kind)
	local role = wardSpot and wardSpot.role or nil
	local wardLoc = wardSpot and wardSpot.location or nil
	MatchTrace.Item(
		bot,
		kind == "sentry" and "item_ward_sentry" or "item_ward_observer",
		"plant",
		string.format(
			"role=%s xy=%s",
			tostring(role or "?"),
			wardLoc and string.format("%d,%d", math.floor(wardLoc.x), math.floor(wardLoc.y)) or "?"
		)
	)
	-- No ping and no team chat on a plant any more: warding is proven to work (user request).
	if not ANNOUNCE_WARD_PLANT then
		return
	end
	Fu.Utils.GameStates = Fu.Utils.GameStates or {}
	-- Bot API has no "Enemy Ward Here" wheel ping — danger ping (X) is the closest mark.
	if kind == "sentry" and wardLoc ~= nil then
		if DotaTime() - (Fu.Utils.GameStates.wardPingTime or -100) >= 8 then
			Fu.Utils.GameStates.wardPingTime = DotaTime()
			bot:ActionImmediate_Ping(wardLoc.x, wardLoc.y, false)
		end
	end
	if DotaTime() - (Fu.Utils.GameStates.wardChatTime or -100) < 12 then
		return
	end
	Fu.Utils.GameStates.wardChatTime = DotaTime()
	local key = kind == "sentry" and "say_ward_sentry" or "say_ward_observer"
	if role == "defend" then
		key = kind == "sentry" and "say_ward_sentry_defend" or "say_ward_observer_defend"
	elseif role == "offense" then
		key = kind == "sentry" and "say_ward_sentry_offense" or "say_ward_observer_offense"
	end
	local text = PickChat(key, kind == "sentry" and "Planting sentry." or "Planting observer.")
	bot:ActionImmediate_Chat(text, false)
	if Fu.Utils.DebugMode or Fu.Utils.GameStates.verboseChat then
		local extra = string.format(
			"[debug] ward %s role=%s at (%.0f, %.0f)",
			kind,
			tostring(role or "n/a"),
			wardSpot and wardSpot.location.x or 0,
			wardSpot and wardSpot.location.y or 0
		)
		bot:ActionImmediate_Chat(extra, false)
	end
end
function GetDesire()
	DumpWards()
	if ShouldSkipBotThink(GetBot()) then
		return 0
	end
	if Fu.GetPosition(bot) <= 3 then
		return false
	end
	local desire = GetDesireHelper()
	return RemapValClamped(Fu.GetHP(bot) * desire, 0, 1, BOT_MODE_DESIRE_NONE, desire)
end
function GetDesireHelper()
	if not WardMode.IsSuitableToWard() then
		return BOT_MODE_DESIRE_NONE
	end
	-- One early ward (user call). Game 030, -0:17: right after Techies planted the Dire mid ward,
	-- ward mode started a second early trip across the top river and he ended up fighting at the
	-- top rune. No more ward trips until 0:20.
	if bot._earlyWardPlantedAt ~= nil and DotaTime() < 20 then
		return BOT_MODE_DESIRE_NONE
	end
	if Fu.Utils.IsTeamPushingSecondTierOrHighGround(bot) then
		return BOT_MODE_DESIRE_NONE
	end
	local enemiesNearAncient = Fu.Utils.CountEnemyHeroesNear(GetAncient(GetTeam()):GetLocation(), 3200)
	if enemiesNearAncient >= 1 then
		return BOT_MODE_DESIRE_NONE
	end
	local isHighGroundThreatened = Fu.Utils.CountEnemyHeroesOnHighGround(GetTeam()) >= 2
	observerWard = nil
	sentryWard = nil
	local observerInInventory = false
	local sentryInInventory = false
	-- Main inventory first, then backpack (human-gifted wards often land in bag).
	for slot = 0, 8 do
		local item = bot:GetItemInSlot(slot)
		if item then
			local itemName = item:GetName()
			-- A dispenser with only sentries is not an observer. Toggling it
			-- toward observer mode puts the sentry on cooldown.
			local dispenserObs = itemName == "item_ward_dispenser" and DispenserHasObservers(item)
			local dispenserSen = itemName == "item_ward_dispenser" and DispenserSentryCharges(item) > 0
			if not observerInInventory and (itemName == "item_ward_observer" or dispenserObs) then
				observerWard = item
				observerInInventory = slot <= 5
			end
			if not sentryInInventory and (itemName == "item_ward_sentry" or dispenserSen) then
				sentryWard = item
				sentryInInventory = slot <= 5
			end
		end
	end
	-- Enter ward mode even if wards are still in backpack so purchase can promote them.
	-- Before the horn the observer is pos 5's (user call).
	if observerWard ~= nil and DotaTime() < 0 and Fu.GetPosition(bot) ~= 5 then
		observerWard = nil
	end
	-- Objective ward first (FuncLib/systems/ward.lua GetObjectiveWardSpot): a teammate heading for
	-- Roshan or the enemy outpost gets the enemy-side spot next to it warded before he arrives.
	if observerWard ~= nil and (observerInInventory and Fu.CanCastAbility(observerWard) or not observerInInventory) and DotaTime() > 0 and DotaTime() > wardModeOffUntil + 1.0 then
		local obj, kind = Ward.GetObjectiveWardSpot(bot)
		if obj and (not WardMode.IsEnemyCloserToWardLocation(obj.location) or Fu.IsRealInvisible(bot)) then
			wardSpot = obj
			if DotaTime() >= (bot._objWardLogAt or -999) + 20 then
				bot._objWardLogAt = DotaTime()
				pcall(print, string.format(
					"[OHA-WARD] t=%.0f %s objective-ward for=%s spot=%d,%d dist=%d",
					DotaTime(),
					(string.gsub(bot:GetUnitName(), "npc_dota_hero_", "")),
					tostring(kind),
					math.floor(obj.location.x),
					math.floor(obj.location.y),
					math.floor(GetUnitToLocationDistance(bot, obj.location))
				))
			end
			return BOT_MODE_DESIRE_VERYHIGH
		end
	end
	if observerWard ~= nil and (observerInInventory and Fu.CanCastAbility(observerWard) or not observerInInventory) then
		local observerSpots = Ward.GetAvailabeObserverWardSpots(bot)
		wardSpot = Ward.GetClosestObserverWardSpot(bot, observerSpots)
		if wardSpot and (not WardMode.IsEnemyCloserToWardLocation(wardSpot.location) or Fu.IsRealInvisible(bot)) then
			local skipSpot = isHighGroundThreatened and not WardMode.IsWardSpotDefensiveOrNearby(wardSpot.location)
			if skipSpot then
			elseif DotaTime() > 0 and GetUnitToLocationDistance(bot, wardSpot.location) > Ward.WalkLimit(wardSpot) then
			elseif DotaTime() < 0 and DotaTime() > (Fu.IsModeTurbo() and -45 or -60) then
				return BOT_MODE_DESIRE_ABSOLUTE
			elseif DotaTime() > wardModeOffUntil + 1.0 then
				return BOT_MODE_DESIRE_VERYHIGH
			end
		end
	end
	if sentryWard ~= nil and (sentryInInventory and Fu.CanCastAbility(sentryWard) or not sentryInInventory) then
		local sentrySpots = Ward.GetPossibleSentryWardSpots(bot)
		wardSpot = Ward.GetClosestSentryWardSpot(bot, sentrySpots)
		if wardSpot and (not WardMode.IsEnemyCloserToWardLocation(wardSpot.location) or Fu.IsRealInvisible(bot)) then
			local skipSpot = isHighGroundThreatened and not WardMode.IsWardSpotDefensiveOrNearby(wardSpot.location)
			if skipSpot then
			elseif DotaTime() > 0 and GetUnitToLocationDistance(bot, wardSpot.location) > Ward.WalkLimit(wardSpot) then
			elseif DotaTime() > wardModeOffUntil + 1.0 then
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
		local item = bot:GetItemInSlot(slot)
		if item ~= nil then
			local itemName = item:GetName()
			if itemName == "item_ward_observer" then
				obs = obs + (item:GetCurrentCharges() or 0)
			elseif itemName == "item_ward_sentry" then
				sen = sen + (item:GetCurrentCharges() or 0)
			elseif itemName == "item_ward_dispenser" then
				obs = obs + (item:GetCurrentCharges() or 0)
				sen = sen + DispenserSentryCharges(item)
			end
		end
	end
	return obs, sen
end
-- Plant tries are no longer printed (ward planting works); kept as a no-op for the call sites.
local function LogPlantTry(kind, item, loc)
	if not LOG_PLANT_TRIES then
		return
	end
	local now = DotaTime()
	local obs, sen = WardCharges()
	bot._wardTry = { at = now, kind = kind, loc = loc, obs = obs, sen = sen }
	if now < (bot._wardTryLogAt or -999) then
		return
	end
	bot._wardTryLogAt = now + 1
	local myLocation = bot:GetLocation()
	pcall(print, string.format(
		"[OHA-WARD] t=%.0f %s plant-try %s item=%s spot=%.0f,%.0f dist=%d spotPassable=%s me=%.0f,%.0f obs=%d sen=%d",
		now,
		(string.gsub(bot:GetUnitName(), "npc_dota_hero_", "")),
		kind,
		item ~= nil and item:GetName() or "?",
		loc.x,
		loc.y,
		GetUnitToLocationDistance(bot, loc),
		tostring(IsLocationPassable(loc)),
		myLocation.x,
		myLocation.y,
		obs,
		sen
	))
end
local function WatchPlant()
	local pendingTry = bot._wardTry
	if pendingTry == nil then
		return
	end
	if DotaTime() - pendingTry.at > 3 then
		bot._wardTry = nil
		return
	end
	local obs, sen = WardCharges()
	if obs < pendingTry.obs or sen < pendingTry.sen then
		pcall(print, string.format(
			"[OHA-WARD] t=%.0f %s planted %s at=%.0f,%.0f",
			DotaTime(),
			(string.gsub(bot:GetUnitName(), "npc_dota_hero_", "")),
			obs < pendingTry.obs and "observer" or "sentry",
			pendingTry.loc.x,
			pendingTry.loc.y
		))
		bot._wardTry = nil
	end
end
local function GiveUpWardSpot(why)
	local now = DotaTime()
	if wardSpot ~= nil then
		wardSpot.plant_time_obs = now
		wardSpot.plant_time_sentry = now
	end
	wardModeOffUntil = now + 15
	bot._wardAtSpotSince = nil
	bot._wardIdleSince = nil
	pcall(print, string.format(
		"[OHA-WARD] t=%.0f %s give-up why=%s spot=%s obs=%s sentry=%s",
		now,
		(string.gsub(bot:GetUnitName(), "npc_dota_hero_", "")),
		why,
		wardSpot ~= nil and string.format("%.0f,%.0f", wardSpot.location.x, wardSpot.location.y) or "-",
		observerWard ~= nil and string.format("%s/slot%d/%s", observerWard:GetName(), bot:FindItemSlot(observerWard:GetName()), tostring(Fu.CanCastAbility(observerWard))) or "-",
		sentryWard ~= nil and string.format("%s/slot%d/%s", sentryWard:GetName(), bot:FindItemSlot(sentryWard:GetName()), tostring(Fu.CanCastAbility(sentryWard))) or "-"
	))
end
function Think()
	if OhaCastGuard ~= nil and OhaCastGuard(GetBot()) then
		return
	end
	DumpWards()
	if Fu.CanNotUseAction(bot) then
		return
	end
	if wardSpot and GetUnitToLocationDistance(bot, wardSpot.location) <= math.max(observerCastRange, sentryCastRange) then
		bot._wardAtSpotSince = bot._wardAtSpotSince or DotaTime()
		if DotaTime() - bot._wardAtSpotSince >= 5 then
			GiveUpWardSpot("in-range-no-plant")
			return
		end
	else
		bot._wardAtSpotSince = nil
	end
	-- No progress toward the spot for 4s (the path keeps turning back): game 031, -0:16 to -0:03,
	-- Techies paced 650-700 from the Dire mid spot in sight of the enemy and drew an attack. Within
	-- 700: plant from here toward it. Farther: give the spot up.
	if wardSpot and wardSpot.location then
		local now = DotaTime()
		local dist = GetUnitToLocationDistance(bot, wardSpot.location)
		local progress = bot._wardProgress
		if progress == nil or progress.spot ~= wardSpot or dist < progress.best - 40 then
			bot._wardProgress = { spot = wardSpot, best = dist, at = now }
		elseif now - progress.at >= 4 and dist > math.max(observerCastRange, sentryCastRange) then
			bot._wardProgress = nil
			if dist <= 700 and WardMode.PlantShort() then
				return
			end
			GiveUpWardSpot("no-progress")
			return
		end
	end
	WardMode.WardThinkActed = false
	WardMode.WardThink()
	if WardMode.WardThinkActed then
		bot._wardIdleSince = nil
	else
		bot._wardIdleSince = bot._wardIdleSince or DotaTime()
		if DotaTime() - bot._wardIdleSince >= 3 then
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
	for radius = 50, 250, 50 do
		for step = 0, 11 do
			local angle = step * math.pi / 6
			local candidate = Vector(loc.x + math.cos(angle) * radius, loc.y + math.sin(angle) * radius, loc.z)
			if IsLocationPassable(candidate) then
				pcall(print, string.format(
					"[OHA-WARD] t=%.0f spot-moved from=%.0f,%.0f to=%.0f,%.0f (not walkable)",
					DotaTime(),
					loc.x,
					loc.y,
					candidate.x,
					candidate.y
				))
				spot.location = candidate
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
	local midTower = GetTower(GetTeam(), TOWER_MID_1)
	if midTower == nil or GetUnitToLocationDistance(midTower, spot.location) > 3000 then
		return
	end
	local pending = bot._earlyWardPending
	if pending ~= nil and DotaTime() - pending.at < 4 then
		return
	end
	-- Pos 5 only (user call): after the mid observer he walks to our own jungle's bounty spot
	-- (Radiant's jungle holds the bottom bounty, Dire's the top one), up to 40s. No walk back
	-- behind the mid T1 any more, for anyone.
	if Fu.GetPosition(bot) ~= 5 then
		return
	end
	local obs = WardCharges()
	bot._earlyWardPending = {
		at = DotaTime(),
		obs = obs,
		to = GetRuneSpawnLocation(GetTeam() == TEAM_RADIANT and RUNE_BOUNTY_2 or RUNE_BOUNTY_1),
		window = 40,
	}
end
-- Plant the observer from where he stands, as far toward the spot as the cast range allows.
function WardMode.PlantShort()
	if wardSpot == nil or observerWard == nil or not Fu.CanCastAbility(observerWard) then
		return false
	end
	if observerWard:GetName() == "item_ward_dispenser" and not DispenserHasObservers(observerWard) then
		return false
	end
	local loc = Fu.Utils.GetOffsetLocationTowardsTargetLocation(bot:GetLocation(), wardSpot.location, observerCastRange - 30)
	pcall(print, string.format(
		"[OHA-WARD] t=%.0f %s plant-short spot=%.0f,%.0f at=%.0f,%.0f dist=%d",
		DotaTime(),
		(string.gsub(bot:GetUnitName(), "npc_dota_hero_", "")),
		wardSpot.location.x,
		wardSpot.location.y,
		loc.x,
		loc.y,
		GetUnitToLocationDistance(bot, wardSpot.location)
	))
	pcall(MarkEarlyWard, wardSpot)
	if observerWard:GetName() == "item_ward_observer" then
		bot:Action_UseAbilityOnLocation(observerWard, loc)
	else
		DispenserPlant(observerWard, loc, true)
	end
	wardSpot.plant_time_obs = DotaTime()
	return true
end
function WardMode.WardThink()
	pcall(ValidateSpot, wardSpot)
	if wardSpot then
		if observerWard and Fu.CanCastAbility(observerWard) and (observerWard:GetName() ~= "item_ward_dispenser" or DispenserHasObservers(observerWard)) then
			if GetUnitToLocationDistance(bot, wardSpot.location) <= observerCastRange then
				if observerWard:GetName() == "item_ward_observer" then
					AnnounceWard("observer")
					WardMode.WardThinkActed = true
					LogPlantTry("observer", observerWard, wardSpot.location)
					pcall(MarkEarlyWard, wardSpot)
					bot:Action_UseAbilityOnLocation(observerWard, wardSpot.location)
				else
					WardMode.WardThinkActed = true
					LogPlantTry("observer", observerWard, wardSpot.location)
					pcall(MarkEarlyWard, wardSpot)
					if DispenserPlant(observerWard, wardSpot.location, true) then
						return
					end
					AnnounceWard("observer")
				end
				wardSpot.plant_time_obs = DotaTime()
				return
			else
				WardMode.WardThinkActed = true
				bot:Action_MoveToLocation(wardSpot.location)
				return
			end
		end
		if sentryWard and Fu.CanCastAbility(sentryWard) and (sentryWard:GetName() ~= "item_ward_dispenser" or DispenserSentryCharges(sentryWard) > 0) then
			if GetUnitToLocationDistance(bot, wardSpot.location) <= sentryCastRange then
				local scatterRadius = 0
				if Ward.IsOtherWardClose(wardSpot.location, "npc_dota_observer_wards", 300, true, false) then
					scatterRadius = 30
				end
				-- A dispenser: plant through DispenserPlant (cast, watch the charges, toggle only
				-- when the cast did nothing or planted the wrong kind). The old rule took toggle
				-- state true as observer mode, toggled, waited 0.8s and gave the spot up: game 019,
				-- 14:48-15:26, Techies kept switching a dispenser that held 0 observers and 2
				-- sentries. Which state means which mode is not documented.
				if sentryWard:GetName() == "item_ward_dispenser" then
					WardMode.WardThinkActed = true
					LogPlantTry("sentry", sentryWard, wardSpot.location)
					if DispenserPlant(sentryWard, wardSpot.location, false) then
						return
					end
					AnnounceWard("sentry")
					wardSpot.plant_time_sentry = DotaTime()
					return
				end
				bot._wardToggleAt = nil
				AnnounceWard("sentry")
				WardMode.WardThinkActed = true
				LogPlantTry("sentry", sentryWard, wardSpot.location)
				bot:Action_UseAbilityOnLocation(sentryWard, wardSpot.location + RandomVector(scatterRadius))
				wardSpot.plant_time_sentry = DotaTime()
				return
			else
				WardMode.WardThinkActed = true
				bot:Action_MoveToLocation(wardSpot.location)
				return
			end
		end
	end
end
function WardMode.IsSuitableToWard()
	local enemyHeroes = bot:GetNearbyHeroes(1200, true, BOT_MODE_NONE)
	local botMode = bot:GetActiveMode()
	local modeDesire = bot:GetActiveModeDesire()
	if
		Fu.IsRetreating(bot) and modeDesire > 0.75
		or botMode == BOT_MODE_RUNE and DotaTime() > 0
		or botMode == BOT_MODE_DEFEND_ALLY
		or enemyHeroes ~= nil and #enemyHeroes >= 1 and WardMode.IsIBecameTheTarget(enemyHeroes)
		or Fu.IsDefending(bot)
		or Fu.IsGoingOnSomeone(bot)
		or bot:WasRecentlyDamagedByAnyHero(5.0)
	then
		return false
	end
	-- Not into visible enemies: game 020, -0:29 to -0:12, Mirana walked alone to the Dire-bank
	-- ward spot by the top rune and three Dire heroes killed her there (first blood). It only
	-- stopped once someone attacked her. Now: no ward trip while outnumbered by visible enemy
	-- heroes within 1200, or toward a spot on the enemy's side of the river with an enemy hero
	-- within 1000 of it.
	local foes = 0
	for _, enemyHero in pairs(enemyHeroes or {}) do
		if Fu.IsValidHero(enemyHero) and not Fu.IsSuspiciousIllusion(enemyHero) then
			foes = foes + 1
		end
	end
	local friends = #(bot:GetNearbyHeroes(1200, false, BOT_MODE_NONE) or {})
	if foes >= 1 and foes > friends then
		return false
	end
	local spot = wardSpot
	if spot ~= nil and spot.location ~= nil then
		local ourSide = GetTeam() == TEAM_RADIANT and "radiant" or "dire"
		if spot.side ~= nil and spot.side ~= ourSide then
			for _, enemyHero in pairs(GetUnitList(UNIT_LIST_ENEMY_HEROES) or {}) do
				if Fu.IsValidHero(enemyHero) and enemyHero:CanBeSeen() and GetUnitToLocationDistance(enemyHero, spot.location) <= 1000 then
					return false
				end
			end
		end
	end
	return true
end
function WardMode.IsIBecameTheTarget(enemyHeroes)
	for _, enemyHero in pairs(enemyHeroes) do
		if Fu.IsValid(enemyHero) and not Fu.IsSuspiciousIllusion(enemyHero) and enemyHero:GetAttackTarget() == bot then
			return true
		end
	end
	return false
end
function WardMode.IsWardSpotDefensiveOrNearby(location)
	if GetUnitToLocationDistance(bot, location) <= 1500 then
		return true
	end
	local ancient = GetAncient(GetTeam())
	if ancient and ancient:IsAlive() then
		local distance = Fu.GetDistance(ancient:GetLocation(), location)
		if distance <= 3500 then
			return true
		end
	end
	return false
end
function WardMode.IsEnemyCloserToWardLocation(location)
	for _, playerId in pairs(GetTeamPlayers(GetOpposingTeam())) do
		if IsHeroAlive(playerId) then
			local lastSeenInfo = GetHeroLastSeenInfo(playerId)
			if lastSeenInfo ~= nil then
				local lastSeen = lastSeenInfo[1]
				if
					lastSeen ~= nil
					and lastSeen.time_since_seen < 3.0
					and Fu.GetDistance(lastSeen.location, location) < GetUnitToLocationDistance(bot, location)
				then
					local alliesNear = Fu.GetAlliesNearLoc(location, 1200)
					local enemiesNear = Fu.GetEnemiesNearLoc(location, 1200)
					if #enemiesNear > #alliesNear then
						return true
					end
				end
			end
		end
	end
	return false
end
if SafeCall then
	local originalGetDesire = GetDesire
	local originalThink = Think
	if originalGetDesire then
		GetDesire = SafeCall(originalGetDesire, 0, "WARD_GetDesire")
	end
	if originalThink then
		Think = SafeCall(originalThink, nil, "WARD_Think")
	end
end
