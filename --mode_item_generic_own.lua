-- Item pick-up mode. Replaces Valve's default item mode, which picked up anything on the ground
-- (game 015, 26:45: Chaos Knight carried a Forager's Kit he picked up from enemy Medusa; another
-- hero's item is no use to him). Picked up here, nothing else:
-- - the bot's own drops, except the ones dropped on purpose (wards and lotuses handed to an ally,
--   the Blood Grenade dropped for a slot),
-- - Gem of True Sight and Divine Rapier, whoever dropped them,
-- - neutral item tokens.
-- Roshan's drops (Aegis, Cheese, Refresher Shard, Roshan's Banner) and ally hand-offs (wards,
-- lotuses) are picked up by their own rules elsewhere, with their claim checks.
local bot = GetBot()
if bot == nil or not bot:IsHero() or bot:IsIllusion() then
	return
end
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")

local ANYONE = { item_gem = true, item_rapier = true }
local NOT_OWN = {
	item_ward_observer = true,
	item_ward_sentry = true,
	item_ward_dispenser = true,
	item_famango = true,
	item_great_famango = true,
	item_greater_famango = true,
	item_blood_grenade = true,
}
local RANGE = 1500

local target = nil

local function Allowed(drop)
	if drop == nil or drop.item == nil or drop.item:IsNull() then
		return false
	end
	local name = drop.item:GetName()
	if ANYONE[name] then
		return true
	end
	if string.find(name, "_token", 1, true) then
		return true
	end
	return drop.owner == bot and not NOT_OWN[name]
end

local function HasRoom(name)
	if string.find(name, "_token", 1, true) then
		return true
	end
	return Fu.Item.GetEmptyInventoryAmount(bot) > 0
end

function GetDesire()
	if ShouldSkipBotThink ~= nil and ShouldSkipBotThink(bot) then
		return 0
	end
	target = nil
	if not bot:IsAlive() or Fu.IsRetreating(bot) then
		return BOT_MODE_DESIRE_NONE
	end
	local best, bestDist = nil, RANGE
	for _, drop in pairs(GetDroppedItemList() or {}) do
		if Allowed(drop) and HasRoom(drop.item:GetName()) then
			local distance = GetUnitToLocationDistance(bot, drop.location)
			if distance < bestDist then
				best, bestDist = drop, distance
			end
		end
	end
	if best == nil then
		return BOT_MODE_DESIRE_NONE
	end
	-- Not into a fight we are losing for it.
	local foes = #(Fu.GetEnemiesNearLoc(best.location, 900) or {})
	local friends = #(Fu.GetAlliesNearLoc(best.location, 900) or {})
	if foes > friends then
		return BOT_MODE_DESIRE_NONE
	end
	target = best
	local top = ANYONE[best.item:GetName()] and BOT_MODE_DESIRE_VERYHIGH or BOT_MODE_DESIRE_MODERATE
	return RemapValClamped(bestDist, RANGE, 0, BOT_MODE_DESIRE_LOW, top)
end

function Think()
	if target == nil or target.item == nil or target.item:IsNull() then
		return
	end
	if GetUnitToLocationDistance(bot, target.location) > 100 then
		bot:Action_MoveToLocation(target.location)
	else
		bot:Action_PickUpItem(target.item)
	end
end

if SafeCall then
	local rawGetDesire = GetDesire
	local rawThink = Think
	GetDesire = SafeCall(rawGetDesire, 0, "ITEM_GetDesire")
	Think = SafeCall(rawThink, nil, "ITEM_Think")
end
