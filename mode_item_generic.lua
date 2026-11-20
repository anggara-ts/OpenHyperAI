-- Item mode, trial (#141): our GetDesire, Valve's Think. This file defines GetDesire only, no Think, OnStart or OnEnd,
-- so Valve's item Think still does the pick-ups (as mode_retreat_generic.lua keeps Valve's retreat Think). Valve's
-- item mode picks up the river bounty and water runes, which our scripts can't (AGENTS.md, "Valve default modes
-- we keep on purpose"), but its own desire also walked bots to other heroes' items (game 062: Medusa and Nyx
-- Assassin carried Nature's Prophet's Forager mushrooms for 15+ minutes). Desire here only for:
--   a bounty or water rune at a river rune spot within 400 (or the 8s after a river spawn, when the API may read
--   the rune as missing),
--   this bot's own dropped item, and Gem / Divine Rapier (any owner), Aegis / Cheese / Refresher Shard (the bot the
--   Roshan claim picks), within 900,
-- and 0 while another player's item is the nearest dropped item within 900. The values and reasons are in
-- FuncLib/systems/item_mode_rules.lua.
-- UNVERIFIED: that Valve's Think still picks things up when this GetDesire drives the mode. [OHA-ITEMMODE] logs each
-- target and, 5s later, picked=yes/no and ran=yes/no (whether the item mode was active meanwhile). A target not
-- picked up is skipped for 45s, so a Think that does nothing can't hold a bot still.
local ItemModeRules = require(GetScriptDirectory() .. "/FuncLib/systems/item_mode_rules")
local ForeignItems = require(GetScriptDirectory() .. "/FuncLib/systems/foreign_items")
local Item = require(GetScriptDirectory() .. "/FuncLib/systems/item")
local bot = GetBot()

local RESULT_AFTER = 5
local SKIP_FOR = 45

local function HeroName()
	return (string.gsub(bot:GetUnitName(), "npc_dota_hero_", ""))
end

-- Own drops the item mode leaves alone, as the own-drop pick-up in item_purchase_generic.lua does: wards handed to
-- supports and lotus fruit handed to allies (their drop/pick-up loops), tokens, early consumables.
local function OwnDropWanted(name)
	if
		string.find(name, "token", 1, true)
		or name == "item_ward_observer"
		or name == "item_ward_sentry"
		or name == "item_ward_dispenser"
		or name == "item_famango"
		or name == "item_great_famango"
		or name == "item_greater_famango"
	then
		return false
	end
	for _, early in ipairs(Item.tEarlyConsumableItem or {}) do
		if early == name then
			return false
		end
	end
	return not ForeignItems.WasDropped(bot, name)
end

local function Skipped(key, now)
	return bot._itemModeSkip ~= nil and now < (bot._itemModeSkip[key] or -999)
end

local function RiverCandidates(now, candidates)
	local spawnTime = ItemModeRules.RiverSpawnWindow(now)
	for _, id in ipairs({ RUNE_POWERUP_1, RUNE_POWERUP_2 }) do
		local loc = GetRuneSpawnLocation(id)
		local dist = loc ~= nil and GetUnitToLocationDistance(bot, loc) or math.huge
		local key = "rune" .. tostring(id)
		if dist <= ItemModeRules.RIVER_REACH and not Skipped(key, now) then
			local status = GetRuneStatus(id)
			local okT, runeType = pcall(GetRuneType, id)
			runeType = okT and runeType or nil
			local kind = nil
			if status == RUNE_STATUS_AVAILABLE and runeType == RUNE_BOUNTY then
				kind = "river-bounty"
			elseif status == RUNE_STATUS_AVAILABLE and RUNE_WATER ~= nil and runeType == RUNE_WATER then
				kind = "river-water"
			elseif spawnTime ~= nil and not (now - spawnTime >= 1 and status == RUNE_STATUS_MISSING) then
				-- As the rune mode's water stay: after 1s on it, a spot that reads missing is empty.
				kind = "river-spawn"
			end
			if kind ~= nil then
				candidates[#candidates + 1] = {
					kind = kind,
					dist = dist,
					key = key,
					runeId = id,
					loc = loc,
					label = string.format("rune%d(status=%s,type=%s)", id, tostring(status), tostring(runeType)),
				}
			end
		end
	end
end

local function DropCandidates(now, candidates)
	local botPid = bot:GetPlayerID()
	for _, drop in ipairs(ForeignItems.DropList()) do
		local dist = GetUnitToLocationDistance(bot, drop.location)
		if dist <= ItemModeRules.ITEM_REACH then
			local name = drop.name
			local key = string.format("%s@%.0f,%.0f", name, drop.location.x, drop.location.y)
			local kind = ItemModeRules.VALUABLE[name]
			if kind == "aegis" or kind == "cheese" or kind == "refresher-shard" then
				if not Item.ShouldClaimRoshanDrop(bot, drop.location, name) then
					kind = nil
				end
			end
			if kind == nil then
				local own = drop.owner == bot or (drop.ownerPid ~= nil and drop.ownerPid == botPid)
				if own then
					kind = OwnDropWanted(name) and "own-drop" or nil
				elseif ForeignItems.IsForeignOwner(name, drop.ownerPid, botPid) then
					kind = "foreign"
				end
			end
			if kind ~= nil and (kind == "foreign" or not Skipped(key, now)) then
				candidates[#candidates + 1] = {
					kind = kind,
					dist = dist,
					item = true,
					key = key,
					name = name,
					loc = drop.location,
					label = string.format("%s(owner=%s)", (string.gsub(name, "^item_", "")), drop.ownerName),
				}
			end
		end
	end
end

-- Is the target gone (picked up by anyone)?
local function TargetGone(try)
	if try.runeId ~= nil then
		return GetRuneStatus(try.runeId) ~= RUNE_STATUS_AVAILABLE
	end
	for _, drop in ipairs(ForeignItems.DropList()) do
		if drop.name == try.name then
			local dx, dy = drop.location.x - try.loc.x, drop.location.y - try.loc.y
			if dx * dx + dy * dy <= 150 * 150 then
				return false
			end
		end
	end
	return true
end

-- The result line, 5s after a target was first wanted: picked (the target is gone), mine (the item is in this bot's
-- inventory, or its gold went up for a rune), ran (the item mode was the active mode meanwhile, so Valve's Think had
-- its turn). Not picked: skip that target for 45s.
local function CheckResult(now)
	local try = bot._itemModeTry
	if try == nil then
		return
	end
	if bot:GetActiveMode() == BOT_MODE_ITEM then
		try.ran = true
	end
	if now < try.at + RESULT_AFTER then
		return
	end
	bot._itemModeTry = nil
	local picked = TargetGone(try)
	local mine
	if try.runeId ~= nil then
		mine = string.format("gold=%+d", math.floor(bot:GetGold() - try.gold))
	else
		mine = "inBag=" .. (bot:FindItemSlot(try.name) >= 0 and "yes" or "no")
	end
	if not picked then
		bot._itemModeSkip = bot._itemModeSkip or {}
		bot._itemModeSkip[try.key] = now + SKIP_FOR
	end
	pcall(
		print,
		string.format(
			"[OHA-ITEMMODE] t=%.0f %s result why=%s target=%s picked=%s ran=%s %s dist=%d%s",
			now,
			HeroName(),
			try.why,
			try.label,
			picked and "yes" or "no",
			try.ran and "yes" or "no",
			mine,
			math.floor(GetUnitToLocationDistance(bot, try.loc)),
			picked and "" or " skip=45s"
		)
	)
end

local function Compute(now)
	local candidates = {}
	if now >= 0 then
		RiverCandidates(now, candidates)
	end
	DropCandidates(now, candidates)
	if #candidates == 0 then
		return 0, "none", nil
	end
	local enemies = #(bot:GetNearbyHeroes(1200, true, BOT_MODE_NONE) or {})
	local allies = #(bot:GetNearbyHeroes(1200, false, BOT_MODE_NONE) or {})
	local mode = bot:GetActiveMode()
	local ctx = {
		hp = bot:GetHealth() / math.max(1, bot:GetMaxHealth()),
		retreating = mode == BOT_MODE_RETREAT and bot:GetActiveModeDesire() >= 0.5,
		outnumbered = enemies > allies,
	}
	local desire, why, index = ItemModeRules.Decide(candidates, ctx)
	return desire, why, index and candidates[index] or nil
end

function GetDesire()
	if ShouldSkipBotThink(bot) then
		bot._itemModeTry = nil
		return 0
	end
	local now = DotaTime()
	CheckResult(now)
	if now < (bot._itemModeAt or -999) then
		return bot._itemModeDesire or 0
	end
	bot._itemModeAt = now + 0.25
	local desire, why, target = Compute(now)
	bot._itemModeDesire = desire
	if desire > 0 and target ~= nil and bot._itemModeTry == nil then
		bot._itemModeTry = {
			at = now,
			key = target.key,
			why = why,
			label = target.label,
			runeId = target.runeId,
			name = target.name,
			loc = target.loc,
			gold = bot:GetGold(),
			ran = false,
		}
	end
	-- One line when the decision changes (desire, why or target), at most every 2s per bot. A 0 is logged only when
	-- it follows a desire or a foreign item blocked it.
	local label = target ~= nil and target.label or "-"
	local sig = string.format("%.2f|%s|%s", desire, why, label)
	local worth = desire > 0 or why == "foreign-nearest" or (bot._itemModeLogDesire or 0) > 0
	if sig ~= bot._itemModeLogSig and worth and now >= (bot._itemModeLogAt or -999) then
		bot._itemModeLogSig = sig
		bot._itemModeLogAt = now + 2
		bot._itemModeLogDesire = desire
		pcall(
			print,
			string.format(
				"[OHA-ITEMMODE] t=%.0f %s desire=%.2f why=%s target=%s dist=%d mode=%d",
				now,
				HeroName(),
				desire,
				why,
				label,
				target ~= nil and math.floor(target.dist) or -1,
				bot:GetActiveMode()
			)
		)
	end
	return desire
end

if SafeCall then
	GetDesire = SafeCall(GetDesire, 0, "ITEM_GetDesire")
end
-- [OHA-PERF] timing (#52): FuncLib/systems/perf.lua. Think stays Valve's: only GetDesire is wrapped.
do
	local Perf = require(GetScriptDirectory() .. "/FuncLib/systems/perf")
	GetDesire = Perf.Wrap("item.GetDesire", GetDesire)
end
