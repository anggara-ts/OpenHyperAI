-- Shared bot system: items in a bot's inventory that another player owns (#141).
--
-- The bot API has no owner or purchaser read for an item in an inventory (Docs/BOT_API_RUNTIME.md: none of the
-- 50 ability/item methods). The only owner it shows is on the ground: GetDroppedItemList() entries carry the
-- item, its owner unit and the location (item_purchase_generic.lua re-picks its own drops with drop.owner == bot).
-- Two ways an item is known to be foreign here:
--   drop-list      the item handle was seen on the ground with another player's hero as its owner (the handle is
--                  remembered, then found in the bot's inventory; whether the engine hands out the same handle
--                  both times is unverified, the [OHA-ITEM] drop-foreign line says how= when it works)
--   not-consumed   a Forager mushroom whose eat orders consumed nothing (another player's mushrooms can't be
--                  eaten: game 062, Medusa and Nyx Assassin held Nature's Prophet's mushrooms for 15+ minutes)
-- A foreign item is never used, eaten or swapped into the main slots, and is dropped once (DropForeignItems in
-- ability_item_usage_generic.lua).
local ForeignItems = {}

-- Items anyone can use whoever bought them: "ItemShareability" ITEM_FULLY_SHAREABLE or ITEM_PARTIALLY_SHAREABLE in
-- the 7.42 items.txt (scripts/npc/items.txt). Divine Rapier and Aegis go to whoever picks them up. None of these is
-- ever foreign.
ForeignItems.SHAREABLE = {
	item_aegis = true,
	item_aghanims_shard_roshan = true,
	item_bottle = true,
	item_cheese = true,
	item_courier = true,
	item_dust = true,
	item_famango = true,
	item_gem = true,
	item_great_famango = true,
	item_greater_famango = true,
	item_madstone_bundle = true,
	item_rapier = true,
	item_refresher_shard = true,
	item_roshans_banner = true,
	item_royale_with_cheese = true,
	item_smoke_of_deceit = true,
	item_tango_single = true,
	item_tier1_token = true,
	item_tier2_token = true,
	item_tier3_token = true,
	item_tier4_token = true,
	item_tier5_token = true,
	item_tome_of_knowledge = true,
	item_tpscroll = true,
	item_ultimate_scepter_roshan = true,
	item_ward_dispenser = true,
	item_ward_observer = true,
	item_ward_sentry = true,
}

ForeignItems.FORAGE = { item_foragers_health = true, item_foragers_stats = true, item_foragers_mana = true }

-- Pure: is an item with this owner foreign to the bot? Unknown owners (nil: a mushroom grown by the kit lies on
-- the ground without one; game 062, Kez ate one without ever holding a Forager's Kit) are not.
function ForeignItems.IsForeignOwner(itemName, ownerPid, botPid)
	if itemName == nil or ForeignItems.SHAREABLE[itemName] then
		return false
	end
	if type(ownerPid) ~= "number" or type(botPid) ~= "number" or ownerPid < 0 then
		return false
	end
	return ownerPid ~= botPid
end

-- Pure: may the bot spend an order on dropping a foreign item now? Not with an enemy hero near, not while a hero
-- hits it, not while retreating or fighting (an order would cancel the step or the attack).
function ForeignItems.SafeToDrop(enemiesNear, hitByHero, retreating, fighting, busy)
	return enemiesNear == 0 and not hitByHero and not retreating and not fighting and not busy
end

-- The dropped-item list, read at most once per 0.2s of game time for every bot that asks. Each entry also
-- records the owner of the item handle for the inventory check.
local ownerByItem = setmetatable({}, { __mode = "k" })
local dropCache, dropCacheAt = {}, nil
local function OwnerPid(drop)
	if type(drop.playerid) == "number" then
		return drop.playerid
	end
	local owner = drop.owner
	if owner == nil or (owner.IsNull ~= nil and owner:IsNull()) then
		return nil
	end
	local ok, pid = pcall(function()
		return owner:GetPlayerID()
	end)
	return ok and pid or nil
end
local function OwnerName(drop)
	local owner = drop.owner
	if owner == nil or (owner.IsNull ~= nil and owner:IsNull()) then
		return "unknown"
	end
	local ok, name = pcall(function()
		return owner:GetUnitName()
	end)
	return ok and type(name) == "string" and (string.gsub(name, "^npc_dota_hero_", "")) or "unknown"
end
-- Entries: { item, name, owner (unit or nil), ownerPid, ownerName, location }.
function ForeignItems.DropList()
	local now = DotaTime()
	if dropCacheAt ~= nil and now >= dropCacheAt and now < dropCacheAt + 0.2 then
		return dropCache
	end
	dropCacheAt = now
	local list = {}
	for _, drop in pairs(GetDroppedItemList() or {}) do
		local item = drop ~= nil and drop.item or nil
		if item ~= nil and not item:IsNull() and drop.location ~= nil then
			local entry = {
				item = item,
				name = item:GetName(),
				owner = drop.owner,
				ownerPid = OwnerPid(drop),
				ownerName = OwnerName(drop),
				location = drop.location,
			}
			list[#list + 1] = entry
			if entry.ownerPid ~= nil then
				ownerByItem[item] = { pid = entry.ownerPid, name = entry.ownerName }
			end
		end
	end
	dropCache = list
	return list
end

-- Is this inventory item foreign to the bot? Returns foreign, owner name, how.
function ForeignItems.Check(bot, item)
	if item == nil or item:IsNull() then
		return false
	end
	local name = item:GetName()
	local marked = bot._foreignNames ~= nil and bot._foreignNames[name] or nil
	if marked ~= nil then
		return true, marked.owner, marked.how
	end
	local rec = ownerByItem[item]
	if rec ~= nil and ForeignItems.IsForeignOwner(name, rec.pid, bot:GetPlayerID()) then
		return true, rec.name, "drop-list"
	end
	return false
end

-- Mark an item name as foreign for this bot for the rest of the game (used for Forager mushrooms, which stack, so
-- the name is the item).
function ForeignItems.MarkName(bot, name, owner, how)
	bot._foreignNames = bot._foreignNames or {}
	if bot._foreignNames[name] == nil then
		bot._foreignNames[name] = { owner = owner or "unknown", how = how or "unknown" }
	end
end

-- Was this name dropped as foreign by this bot? Its own-drop pick-ups leave it on the ground.
function ForeignItems.WasDropped(bot, name)
	return bot._foreignDropped ~= nil and bot._foreignDropped[name] ~= nil
end

return ForeignItems
