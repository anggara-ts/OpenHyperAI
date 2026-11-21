-- Buys and sells items from the hero build.
local bot = GetBot()
local botName = bot:GetUnitName()
if
	bot == nil
	or bot:IsInvulnerable()
	or not bot:IsHero()
	or not bot:IsAlive()
	or not string.find(botName, "hero")
	or bot:IsIllusion()
then
	return
end
if GAMEMODE_ARDM == nil then
	GAMEMODE_ARDM = 20
end
local Item = require(GetScriptDirectory() .. "/FuncLib/systems/item")
local Role = require(GetScriptDirectory() .. "/FuncLib/systems/role")
local BuyRules = require(GetScriptDirectory() .. "/FuncLib/systems/buy_rules")
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local Utils = require(GetScriptDirectory() .. "/FuncLib/systems/utils")
local MatchTrace = require(GetScriptDirectory() .. "/FuncLib/systems/match_trace")
local TeamItems = require(GetScriptDirectory() .. "/FuncLib/systems/item_strategy")
local ForeignItems = require(GetScriptDirectory() .. "/FuncLib/systems/foreign_items")
-- Observer stock is shared with the human. When a ward lands in the shop, leave it
-- for 30s. Buy only what is still there after that.
local OBS_HUMAN_WINDOW = 30
local obsStockSeen = -1
local obsStockAt = nil
local function ObserverStockForHumans()
	local stock = GetItemStockCount("item_ward_observer")
	local now = DotaTime()
	if stock <= 0 then
		obsStockSeen = 0
		obsStockAt = nil
		return false
	end
	if obsStockAt == nil or stock > obsStockSeen then
		obsStockAt = now
	end
	obsStockSeen = stock
	return now >= obsStockAt + OBS_HUMAN_WINDOW
end
local ItemPurchase = {}
if bot:IsInvulnerable() or not bot:IsHero() or bot:IsIllusion() then
	return
end
local heroModule = require(GetScriptDirectory() .. "/BotsLib/" .. string.gsub(botName, "npc_dota_", ""))
if heroModule == nil then
	return
end
bot.purchaseListInReverseOrder = {}
bot.currBuyingItemInPurchaseList = nil
bot.currBuyingBasicItem = nil
bot.currBuyingBasicItemList = {}
bot.currBuyingBasicItemRefList = {}
bot.currBuyingRequiredCounts = nil
bot._lastPurchaseAttempt = { name = nil, t = -999 }
bot.rebuildCount = 0
bot.SecretShop = false
-- Boots of Travel 2 needs Boots of Travel first in the list. About 60 builds list only Boots of
-- Travel 2: the planner then bought Boots and the recipe, again and again (game 020: OD ended
-- with two level-1 Boots of Travel and kept re-buying the recipe; Lich bought Boots 21 times
-- for it in earlier games). Insert Boots of Travel before the first Boots of Travel 2 when no
-- Boots of Travel comes before it.
local function FixTravelBoots(list)
	if type(list) ~= "table" then
		return list
	end
	local out, seenT1 = {}, false
	for _, it in ipairs(list) do
		if it == "item_travel_boots" then
			seenT1 = true
		elseif it == "item_travel_boots_2" and not seenT1 then
			out[#out + 1] = "item_travel_boots"
			seenT1 = true
		end
		out[#out + 1] = it
	end
	return out
end
local buyList = FixTravelBoots(heroModule["sBuyList"])
local sellList = heroModule["sSellList"]
if buyList == nil then
	log("[ERROR] Can't load purchase list for: %s", botName)
	log("Stack Trace:", debug.traceback())
	return
end
log("[Purchase] %s loaded %d items: %s -> %s", botName, #buyList, buyList[1] or "nil", buyList[#buyList] or "nil")
for i = 1, #buyList do
	bot.purchaseListInReverseOrder[i] = buyList[#buyList - i + 1]
end
bot.sell_time = -90
local unusedSellTime = -90
bot.countInvCheck = 0
bot.lastItemToBuy = nil
bot.bPurchaseFromSecret = false
bot.hasBuyShard = true
local nextItemCost = 0
local courier = nil
local keepBuybackGold = false
local lastBuybackCheckTime = -90
bot.lastInvCheck = -90
bot.fullInvCheck = -90
bot.switchTime = 0
bot.hasBuyClarity = false
local lastBootsCheckTime = -90
local hasBoots = false
local wasPreGame = false
local unusedTime = -999
local unusedCount = 0
local unusedFlag = false
local now, botLevel, gold, netWorth, activeMode, courierValue, stashValue, fountainDistance
local function CountItem(unit, itemName)
	local count = 0
	for slot = 0, 14 do
		local item = unit:GetItemInSlot(slot)
		if item ~= nil and item:GetName() == itemName then
			count = count + 1
		end
	end
	return count
end
local function CountList(list)
	local counts = {}
	for _, name in ipairs(list) do
		counts[name] = (counts[name] or 0) + 1
	end
	return counts
end
-- How many of each part the bot must hold once the parts still to buy (list) are bought: what it holds now plus
-- the list (#38). Game 055: Weaver held a Magic Stick and one Iron Branch; the plan for Magic Wand (Stick + 2
-- Branches + recipe) was one Branch and the recipe. The count was the list alone (1 Branch), she held 1, so
-- ShouldBuyBasicItem skipped the Branch, the recipe was bought and the Wand never formed. 90 rebuilt lists start
-- with one Branch and build a Wand later.
local function RequiredCounts(list)
	local counts = CountList(list)
	for name, count in pairs(counts) do
		counts[name] = count + CountItem(bot, name)
	end
	return counts
end
local tEarlyGameItems = {
	item_tango = true,
	item_double_tango = true,
	item_clarity = true,
	item_faerie_fire = true,
	item_enchanted_mango = true,
	item_flask = true,
	item_blood_grenade = true,
	item_branches = true,
	item_double_branches = true,
	item_magic_stick = true,
	item_magic_wand = true,
	item_recipe_magic_wand = true,
	item_infused_raindrop = true,
	item_orb_of_venom = true,
	item_blight_stone = true,
	item_orb_of_frost = true,
	item_gauntlets = true,
	item_slippers = true,
	item_mantle = true,
	item_circlet = true,
	item_ring_of_protection = true,
	item_bracer = true,
	item_wraith_band = true,
	item_null_talisman = true,
	item_soul_ring = true,
}
local function ShouldBuyBasicItem(itemName)
	if itemName == "item_boots" then
		local buildingItem = bot.currBuyingItemInPurchaseList
		local bootUpgrades = {
			item_power_treads = true,
			item_phase_boots = true,
			item_arcane_boots = true,
			item_tranquil_boots = true,
			item_travel_boots = true,
			item_travel_boots_2 = true,
			item_guardian_greaves = true,
			item_boots_of_bearing = true,
		}
		if Item.HasBootsInMainSolt(bot) and not bootUpgrades[buildingItem] then
			return false
		end
	end
	if GetGameMode() == GAMEMODE_ARDM and DotaTime() > 2 * 60 and tEarlyGameItems[itemName] then
		return false
	end
	if not bot.currBuyingRequiredCounts then
		return true
	end
	local requiredCount = bot.currBuyingRequiredCounts[itemName]
	if not requiredCount then
		return true
	end
	local ownedCount = CountItem(bot, itemName)
	return ownedCount < requiredCount
end
local function NextBasicItem()
	while #bot.currBuyingBasicItemList > 0 do
		local itemName = bot.currBuyingBasicItemList[#bot.currBuyingBasicItemList]
		if ShouldBuyBasicItem(itemName) then
			return itemName
		else
			bot.currBuyingBasicItemList[#bot.currBuyingBasicItemList] = nil
		end
	end
	return nil
end
local function IsRepeatedPurchase(itemName)
	local time = DotaTime()
	if bot._lastPurchaseAttempt.name == itemName and time - bot._lastPurchaseAttempt.t < 0.4 then
		return true
	end
	bot._lastPurchaseAttempt.name, bot._lastPurchaseAttempt.t = itemName, time
	return false
end
local function HasEnoughTpScrolls()
	local tpCharges = Item.GetItemCharges(bot, "item_tpscroll")
	return tpCharges >= 2
		or tpCharges >= 1 and Item.HasItem(bot, "item_travel_boots")
		or tpCharges >= 1 and Item.HasItem(bot, "item_travel_boots_2")
end
local function FinishBasicItem()
	bot.countInvCheck = 0
	bot.currBuyingBasicItem = nil
	bot.currBuyingBasicItemList[#bot.currBuyingBasicItemList] = nil
end
local function ResetBuyState()
	bot.countInvCheck = 0
	bot.currBuyingItemInPurchaseList = nil
	bot.currBuyingBasicItem = nil
	bot.currBuyingBasicItemList = {}
	bot.currBuyingBasicItemRefList = {}
	bot.currBuyingRequiredCounts = nil
	bot._recipeTarget = nil
end
-- Which bot cores owe the team a lockdown answer. Mid first, then offlane,
-- then the carry if a human holds one of those roles. Every bot computes the
-- same answer from positions, so they agree without shared Lua state.
local tLockdownOrder = { 2, 3, 1 }
local function IsLockdownBuyer(nMyPos, tBotPositions, nWanted)
	local nAssigned = 0
	for _, nPos in ipairs(tLockdownOrder) do
		if nAssigned >= nWanted then
			return false
		end
		if tBotPositions[nPos] then
			nAssigned = nAssigned + 1
			if nPos == nMyPos then
				return true
			end
		end
	end
	return false
end
local function LockdownItemFor(bStrength)
	return bStrength and "item_heavens_halberd" or "item_orchid"
end
-- The last entry of the reverse purchase list is bought next.
local function QueueFront(tReverseList, itemName)
	if tReverseList[#tReverseList] == itemName then
		return false
	end
	for i = #tReverseList, 1, -1 do
		if tReverseList[i] == itemName then
			table.remove(tReverseList, i)
		end
	end
	tReverseList[#tReverseList + 1] = itemName
	return true
end
local tLockdownBotPositions = nil
local tLockdownStrByPos = {}
local tReactiveQueued = {}
local reactiveRightclickMenace = nil
local function OwnedAnywhere(unit, itemName)
	local nSlot = unit:FindItemSlot(itemName)
	return nSlot >= 0 and nSlot <= 14
end
local function ReactiveOwnedOrBuilding(itemName)
	if OwnedAnywhere(bot, itemName) then
		return true
	end
	if bot.currBuyingItemInPurchaseList == itemName then
		return true
	end
	return false
end
local function QueueReactiveItem(itemName)
	if tReactiveQueued[itemName] or ReactiveOwnedOrBuilding(itemName) then
		return false
	end
	tReactiveQueued[itemName] = true
	if not QueueFront(bot.purchaseListInReverseOrder, itemName) then
		return false
	end
	-- Keep what is left of the item being built, so it resumes there after the reactive item.
	-- Game 014: Ghost Scepter cut into Mirana's priest_outfit at 20:19, the outfit restarted from
	-- scratch, and she bought tangos, branches, Magic Stick and the wand recipe again while she
	-- already had a Magic Wand.
	if bot.currBuyingItemInPurchaseList ~= nil and #bot.currBuyingBasicItemList > 0 then
		bot._resumeBuy = bot._resumeBuy or {}
		bot._resumeBuy[bot.currBuyingItemInPurchaseList] = {
			list = Utils.Deepcopy(bot.currBuyingBasicItemList),
			ref = Utils.Deepcopy(bot.currBuyingBasicItemRefList),
			target = bot._recipeTarget and Utils.Deepcopy(bot._recipeTarget) or nil,
		}
	end
	ResetBuyState()
	bot.rebuildCount = 0
	log("[Item] %s queued counter %s (pos %s)", botName, itemName, tostring(Fu.GetPosition(bot)))
	return true
end
local function QueueRightclickCounters()
	local nStart = 12 * 60
	if DotaTime() < nStart then
		return
	end
	if reactiveRightclickMenace == nil then
		reactiveRightclickMenace = false
		for _, id in pairs(GetTeamPlayers(GetOpposingTeam())) do
			local sHero = GetSelectedHeroName(id)
			if sHero ~= nil and Fu.tRightclickMenace[sHero] then
				reactiveRightclickMenace = true
			end
		end
	end
	if reactiveRightclickMenace ~= true then
		return
	end
	local tLock = {
		"item_heavens_halberd",
		"item_orchid",
		"item_bloodthorn",
		"item_sheepstick",
		"item_abyssal_blade",
	}
	local nTeamLock, bTeamHex = 0, false
	local tPositions, nResolved = {}, 0
	local tTeamIds = GetTeamPlayers(GetTeam())
	for i = 1, #tTeamIds do
		local ally = GetTeamMember(i)
		if ally ~= nil and not ally:IsNull() then
			nResolved = nResolved + 1
			if ally:IsBot() then
				local nAllyPos = Fu.GetPosition(ally)
				tPositions[nAllyPos] = true
				tLockdownStrByPos[nAllyPos] = ally:GetPrimaryAttribute() == ATTRIBUTE_STRENGTH
			end
			for _, sLock in ipairs(tLock) do
				if OwnedAnywhere(ally, sLock) then
					nTeamLock = nTeamLock + 1
					if sLock == "item_sheepstick" then
						bTeamHex = true
					end
				end
			end
		end
	end
	if tLockdownBotPositions == nil and nResolved == #tTeamIds then
		tLockdownBotPositions = tPositions
	end
	if tLockdownBotPositions == nil then
		return
	end
	local nPos = Fu.GetPosition(bot)
	local bStr = bot:GetPrimaryAttribute() == ATTRIBUTE_STRENGTH
	if nPos <= 3 then
		local bAssigned = IsLockdownBuyer(nPos, tLockdownBotPositions, 2)
		local bFallback = nTeamLock == 0 and DotaTime() > nStart + 10 * 60
		local sLockItem = LockdownItemFor(bStr)
		local bOwnLock = false
		for _, sLock in ipairs(tLock) do
			if OwnedAnywhere(bot, sLock) then
				bOwnLock = true
			end
		end
		if (bAssigned or bFallback) and not bOwnLock and nTeamLock < 2 then
			if QueueReactiveItem(sLockItem) then
				return
			end
		end
		if bAssigned and bOwnLock and not bTeamHex and not bStr and DotaTime() > 25 * 60 then
			local nHexPos = nil
			for _, pos in ipairs({ 2, 3, 1 }) do
				if IsLockdownBuyer(pos, tLockdownBotPositions, 2) and tLockdownStrByPos[pos] == false then
					nHexPos = pos
					break
				end
			end
			if nHexPos == nPos then
				if QueueReactiveItem("item_sheepstick") then
					return
				end
			end
		end
	elseif not OwnedAnywhere(bot, "item_ethereal_blade") then
		if QueueReactiveItem("item_ghost") then
			return
		end
	end
end
local tPromoteFromBackpack = {
	item_orchid = true,
	item_bloodthorn = true,
	item_sheepstick = true,
	item_heavens_halberd = true,
	item_abyssal_blade = true,
	item_ghost = true,
	item_black_king_bar = true,
	item_force_staff = true,
	item_hurricane_pike = true,
	item_blade_mail = true,
	item_glimmer_cape = true,
	item_nullifier = true,
	-- Cast from a main slot only (game 032, 11:51: Grimstroke's Dust ended up in the backpack).
	item_dust = true,
	-- Used once, at a moment the bot cannot see 6s ahead (the backpack cooldown), so they are
	-- brought into the main inventory as soon as they sit in the backpack, and never moved out
	-- again (sCanNotSwitchItems). A Gem gives no true sight from the backpack.
	item_cheese = true,
	item_famango = true,
	item_great_famango = true,
	item_greater_famango = true,
	item_refresher_shard = true,
	item_gem = true,
}
-- Promoted whatever they cost: these items cost little or nothing (Roshan and lotus drops), so the
-- "only replace something cheaper" rule would never find them a slot.
local tPromoteAnyCost = {
	item_dust = true,
	item_cheese = true,
	item_famango = true,
	item_great_famango = true,
	item_greater_famango = true,
	item_refresher_shard = true,
	item_gem = true,
}
local promoteNextCheck = 0
-- Consumables that can sit in the backpack. A branch cannot: it is a wand component,
-- and parking it makes the game pull it straight back on cooldown.
local PARK_IN_BACKPACK = {
	item_tango = true,
	item_tango_single = true,
	item_clarity = true,
	item_faerie_fire = true,
	item_enchanted_mango = true,
	item_flask = true,
}
local function ForceSwap(fromSlot, toSlot)
	bot._swapDespiteEnemies = true
	bot:ActionImmediate_SwapItems(fromSlot, toSlot)
	bot._swapDespiteEnemies = nil
end
local function MainSlotForBackpackItem()
	for slot = 0, 5 do
		if bot:GetItemInSlot(slot) == nil then
			return slot
		end
	end
	for slot = 0, 5 do
		local it = bot:GetItemInSlot(slot)
		if it ~= nil and PARK_IN_BACKPACK[it:GetName()] then
			return slot
		end
	end
	return nil
end
-- A full bag puts the grenade in the backpack, where it cannot be thrown.
-- The grenade takes a main slot ahead of a branch. Do not pull that branch back out.
local function PreferBloodGrenadeOverBranch()
	if VerifyLastSwap then
		VerifyLastSwap(bot)
	end
	local grenadeSlot = bot:FindItemSlot("item_blood_grenade")
	-- Log every slot change of the grenade with the main inventory and the mode. A move into
	-- the backpack that no logged swap made was something outside the swap wrapper.
	if grenadeSlot ~= (bot._grenadeLastSlot or -1) then
		if grenadeSlot >= 0 or (bot._grenadeLastSlot or -1) >= 0 then
			local main = {}
			for slot = 0, 5 do
				local it = bot:GetItemInSlot(slot)
				main[#main + 1] = it ~= nil and (string.gsub(it:GetName(), "^item_", "")) or "-"
			end
			local pack = {}
			for slot = 6, 8 do
				local it = bot:GetItemInSlot(slot)
				pack[#pack + 1] = it ~= nil and (string.gsub(it:GetName(), "^item_", "")) or "-"
			end
			pcall(
				print,
				string.format(
					"[OHA-ITEM] t=%.0f %s grenade-moved from=%d to=%d mode=%s main=%s pack=%s",
					DotaTime(),
					(string.gsub(botName, "npc_dota_hero_", "")),
					bot._grenadeLastSlot or -1,
					grenadeSlot,
					tostring(bot:GetActiveMode()),
					table.concat(main, ","),
					table.concat(pack, ",")
				)
			)
		end
		bot._grenadeLastSlot = grenadeSlot
	end
	-- Bot item swaps do not take effect in this game build (every checked swap was a no-op), so
	-- there is nothing to do while the grenade is merely in the backpack. The game moves it
	-- back up as soon as a main slot frees. From 12:00 a grenade still carried is dead weight:
	-- sell it at base or drop it elsewhere, away from enemy heroes.
	if grenadeSlot < 0 or grenadeSlot > 8 or DotaTime() < 12 * 60 then
		return
	end
	if #(bot:GetNearbyHeroes(1200, true, BOT_MODE_NONE) or {}) > 0 then
		return
	end
	local grenade = bot:GetItemInSlot(grenadeSlot)
	if grenade == nil then
		return
	end
	-- A dropped item can be picked straight back up by the engine (seen with a Clarity).
	-- Drop it once; if it comes back, only sell it at base from then on.
	if bot._grenadeDroppedAt ~= nil and DotaTime() - bot._grenadeDroppedAt < 3 then
		return
	end
	if bot._grenadeDroppedAt ~= nil and not bot._grenadeRepickLogged then
		bot._grenadeRepickLogged = true
		pcall(
			print,
			string.format(
				"[OHA-ITEM] t=%.0f %s grenade-repicked after=%.0fs",
				DotaTime(),
				(string.gsub(botName, "npc_dota_hero_", "")),
				DotaTime() - bot._grenadeDroppedAt
			)
		)
	end
	local how
	if bot:DistanceFromFountain() <= 1600 then
		bot:ActionImmediate_SellItem(grenade)
		how = "sold"
	elseif bot._grenadeDroppedAt == nil then
		bot:Action_DropItem(grenade, bot:GetLocation())
		bot._grenadeDroppedAt = DotaTime()
		how = "dropped"
	else
		return
	end
	if DotaTime() >= (bot._grenadeDisposeLogAt or -999) then
		bot._grenadeDisposeLogAt = DotaTime() + 10
		pcall(
			print,
			string.format(
				"[OHA-ITEM] t=%.0f %s grenade-%s slot=%d",
				DotaTime(),
				(string.gsub(botName, "npc_dota_hero_", "")),
				how,
				grenadeSlot
			)
		)
	end
end
-- Game 037: a backpack item pulled into the main inventory was back in the backpack a few seconds
-- later, and the routine pulled it again at every swap-pair gap (Night Stalker's Clarity every 12s,
-- t=1162-1203; Lion's healing lotus every 12s; Hoodwink's Dust every 2 minutes). No Lua routine in
-- our code moves a Clarity, a lotus or Dust out of the main inventory (every ActionImmediate_SwapItems
-- call site checked), and the swap wrapper refuses the reverse swap of the same pair for 11s, so the
-- swap itself does not stick (games 008-012: 216 of 217 swaps checked 0.5s later had not happened).
-- Each pull is now checked 1.5s later: [OHA-ITEM] pull-check result=stuck/reverted/gone. A reverted
-- item is not pulled again for 30s, so the routines stop re-ordering it.
local PULL_CHECK_AFTER = 1.5
local PULL_BACKOFF = 30
local function WatchPull(tag, item, dest)
	if item == nil or item:IsNull() then
		return
	end
	bot._pullWatch = bot._pullWatch or {}
	bot._pullWatch[#bot._pullWatch + 1] = {
		tag = tag,
		item = item,
		name = item:GetName(),
		dest = dest,
		at = DotaTime(),
		charges = item:GetCurrentCharges() or 0,
	}
end
-- True when the swap wrapper (global_overrides.lua) passed the swap a<->b on to the engine just now
-- (it records _swapCheck only then; a swap it refused for the pair gap or a fight leaves none).
local function SwapIssued(slotA, slotB)
	local check = bot._swapCheck
	return check ~= nil and check.at == DotaTime() and check.a == slotA and check.b == slotB
end
local function PullBackedOff(name)
	return bot._pullBackoff ~= nil and (bot._pullBackoff[name] or -1) > DotaTime()
end
local function CheckPulls()
	local list = bot._pullWatch
	if list == nil or #list == 0 then
		return
	end
	local now = DotaTime()
	local keep = {}
	for _, watch in ipairs(list) do
		if now - watch.at < PULL_CHECK_AFTER then
			keep[#keep + 1] = watch
		else
			local slot = -1
			for s = 0, 8 do
				if bot:GetItemInSlot(s) == watch.item then
					slot = s
					break
				end
			end
			local result = slot < 0 and "gone" or (slot <= 5 and "stuck" or "reverted")
			local inDest = bot:GetItemInSlot(watch.dest)
			if slot < 0 then
				-- Item handles may not compare equal across calls: fall back to names.
				if inDest ~= nil and not inDest:IsNull() and inDest:GetName() == watch.name then
					result, slot = "stuck", watch.dest
				else
					for s = 6, 8 do
						local it = bot:GetItemInSlot(s)
						if it ~= nil and not it:IsNull() and it:GetName() == watch.name then
							result, slot = "reverted", s
							break
						end
					end
				end
			end
			if result == "reverted" then
				bot._pullBackoff = bot._pullBackoff or {}
				bot._pullBackoff[watch.name] = now + PULL_BACKOFF
			end
			local found = slot >= 0 and bot:GetItemInSlot(slot) or nil
			pcall(
				print,
				string.format(
					"[OHA-ITEM] t=%.0f %s pull-check %s %s result=%s slot=%d dest=%d(%s) after=%.1f charges=%d->%d%s",
					now,
					(string.gsub(botName, "npc_dota_hero_", "")),
					watch.tag,
					(string.gsub(watch.name, "^item_", "")),
					result,
					slot,
					watch.dest,
					inDest ~= nil and (string.gsub(inDest:GetName(), "^item_", "")) or "-",
					now - watch.at,
					watch.charges,
					found ~= nil and not found:IsNull() and (found:GetCurrentCharges() or 0) or -1,
					result == "reverted" and string.format(" backoff=%ds", PULL_BACKOFF) or ""
				)
			)
		end
	end
	bot._pullWatch = keep
end
-- [OHA-NEUTRAL] madstone (#116): the first neutral item came at 11-19 min in games 050-062 although tier 1 opens at
-- 0:00. 7.42 rules (resource/localization/dota_english.txt, DOTA_Madstone_Explaination_1/2): "Fully clear a neutral
-- creep camp to earn 2 Madstone for yourself and 1 for a random ally (Ancient camps earn 3 and 2)"; tier 1 takes 6
-- (scripts/npc/neutral_items.txt craft_cost), later tiers 10; a team limit rises over time (its numbers are not in
-- the game files). The reward drops as item_madstone_bundle (scripts/npc/items.txt: AutoPickup 1, ItemCastOnPickup
-- 1, die_time 20). Whether bots collect it is not known, so every bundle that comes within 1200 of the bot is
-- logged when seen and when gone (fate=expired when it lay the full 20 s, else taken; minDist = how close the bot
-- came), and a bot without a neutral item says so every 2 min. No bundle line at all means the bundles are not in
-- GetDroppedItemList. Until 30:00 only (tier 3).
local MADSTONE_LOG_UNTIL = 1800
local madstoneNextScan = 0
local function LogMadstone(neutralName)
	local now = DotaTime()
	if now < 0 or now > MADSTONE_LOG_UNTIL or now < madstoneNextScan then
		return
	end
	madstoneNextScan = now + 1
	local heroName = (string.gsub(botName, "npc_dota_hero_", ""))
	local bundles = bot._madstoneBundles or {}
	bot._madstoneBundles = bundles
	local stats = bot._madstoneStats or { seen = 0, taken = 0, expired = 0, nextSummary = 0 }
	bot._madstoneStats = stats
	local present = {}
	for _, drop in pairs(GetDroppedItemList() or {}) do
		if
			drop ~= nil
			and drop.item ~= nil
			and drop.location ~= nil
			and not drop.item:IsNull()
			and drop.item:GetName() == "item_madstone_bundle"
		then
			local key = string.format("%.0f,%.0f", drop.location.x, drop.location.y)
			local dist = GetUnitToLocationDistance(bot, drop.location)
			local entry = bundles[key]
			if entry == nil then
				entry = { firstAt = now, minDist = dist, logged = false }
				bundles[key] = entry
			end
			present[key] = true
			entry.minDist = math.min(entry.minDist, dist)
			if not entry.logged and dist <= 1200 then
				entry.logged = true
				stats.seen = stats.seen + 1
				print(
					string.format(
						"[OHA-NEUTRAL] t=%.0f %s madstone-bundle seen at=%s dist=%.0f age=%.0f slot16=%s",
						now,
						heroName,
						key,
						dist,
						now - entry.firstAt,
						neutralName
					)
				)
			end
		end
	end
	for key, entry in pairs(bundles) do
		if not present[key] then
			bundles[key] = nil
			if entry.logged then
				local age = now - entry.firstAt
				local fate = age >= 19 and "expired" or "taken"
				stats[fate] = stats[fate] + 1
				print(
					string.format(
						"[OHA-NEUTRAL] t=%.0f %s madstone-bundle gone at=%s age=%.0f fate=%s minDist=%.0f",
						now,
						heroName,
						key,
						age,
						fate,
						entry.minDist
					)
				)
			end
		end
	end
	if neutralName == "none" and now >= stats.nextSummary then
		stats.nextSummary = now + 120
		print(
			string.format(
				"[OHA-NEUTRAL] t=%.0f %s no-neutral-yet bundlesSeen=%d taken=%d expired=%d lastHits=%d",
				now,
				heroName,
				stats.seen,
				stats.taken,
				stats.expired,
				bot:GetLastHits()
			)
		)
	end
end
local function PromoteBackpackCounters()
	CheckPulls()
	-- [OHA-NEUTRAL]: which neutral item the bot carries (slot 16), printed when it changes. Game 039: the
	-- maintainer saw no neutral item on Keeper of the Light and nothing in the log could say (#15).
	local neutralItem = bot:GetItemInSlot(16)
	local neutralName = neutralItem ~= nil and not neutralItem:IsNull() and neutralItem:GetName() or "none"
	if neutralName ~= bot._neutralLogged and DotaTime() > 0 then
		bot._neutralLogged = neutralName
		pcall(
			print,
			string.format(
				"[OHA-NEUTRAL] t=%.0f %s slot16=%s",
				DotaTime(),
				(string.gsub(bot:GetUnitName(), "npc_dota_hero_", "")),
				neutralName
			)
		)
	end
	pcall(LogMadstone, neutralName)
	if DotaTime() < promoteNextCheck then
		return
	end
	promoteNextCheck = DotaTime() + 2
	for nBpSlot = 6, 8 do
		local hBpItem = bot:GetItemInSlot(nBpSlot)
		-- Game 032: Dust (promoted since build 055) picked the Ward Dispenser as the cheapest main item;
		-- the engine ignored every swap and it was tried every 12s all game (Oracle 325 tries, 708 for
		-- four supports), keeping the 11s swap gap running for every other swap. Wards are never moved
		-- out for it, and an item that two swaps did not move is left for 120s.
		bot._promoteTries = bot._promoteTries or {}
		local tries = hBpItem ~= nil and bot._promoteTries[hBpItem:GetName()] or nil
		if tries ~= nil and DotaTime() > tries.untilAt then
			bot._promoteTries[hBpItem:GetName()] = nil
			tries = nil
		end
		if
			hBpItem ~= nil
			and tPromoteFromBackpack[hBpItem:GetName()]
			and not (tries ~= nil and tries.n >= 2)
			and not PullBackedOff(hBpItem:GetName())
		then
			local nBpCost = tPromoteAnyCost[hBpItem:GetName()] and math.huge or GetItemCost(hBpItem:GetName())
			local nBestSlot, nBestCost = -1, nBpCost
			for nSlot = 0, 5 do
				local hItem = bot:GetItemInSlot(nSlot)
				if hItem == nil then
					nBestSlot, nBestCost = nSlot, -1
					break
				end
				local sName = hItem:GetName()
				local nCost = GetItemCost(sName)
				if
					nCost < nBestCost
					and not tPromoteFromBackpack[sName]
					and not Item.IsCanNotSwitchItem(sName)
					and not string.find(sName, "boots")
					and not string.find(sName, "item_ward", 1, true)
					and sName ~= "item_power_treads"
					and sName ~= "item_guardian_greaves"
					-- Never give up an item with an active on a cooldown (Mekansm, Magic Wand, Urn, Glimmer...):
					-- moving it through the backpack puts it on cooldown, and the engine often reverts the swap,
					-- so it went back and forth. Game 039, ~40:00: Rubick's Mekansm, swapped out for Dust twice.
					and not (not hItem:IsPassive() and (hItem:GetCooldown() or 0) > 0)
				then
					nBestSlot, nBestCost = nSlot, nCost
				end
			end
			if nBestSlot ~= -1 then
				log("[Item] %s backpack -> main: %s", botName, hBpItem:GetName())
				local tryRecord = bot._promoteTries[hBpItem:GetName()] or { n = 0, untilAt = 0 }
				tryRecord.n = tryRecord.n + 1
				tryRecord.untilAt = DotaTime() + 120
				bot._promoteTries[hBpItem:GetName()] = tryRecord
				bot:ActionImmediate_SwapItems(nBpSlot, nBestSlot)
				if SwapIssued(nBpSlot, nBestSlot) then
					WatchPull("promote", hBpItem, nBestSlot)
				end
				return
			end
		end
	end
end
local function ShortItem(name)
	return (string.gsub(tostring(name), "^item_", ""))
end
-- [OHA-BUY] lines: every purchase, and every recipe held back for a missing ingredient.
local function BuyLog(fmt, ...)
	pcall(
		print,
		string.format("[OHA-BUY] t=%.0f %s " .. fmt, DotaTime(), (string.gsub(botName, "npc_dota_hero_", "")), ...)
	)
end
-- Every purchase order goes through Purchase (#15). Game 063, 10:38: Shadow Fiend's courier took
-- `stash=tango,boots` with no [OHA-BUY] line, and half the purchase paths (restocks, wards, Smoke, Shard, TP)
-- printed nothing, so a log could not say which path bought an item. A success prints
-- `bought <item> via=<path> for=<target>`; a failed order prints `buy-failed` at most once per item every 30s.
local function Purchase(unit, itemName, via, forItem, extra)
	local result = unit:ActionImmediate_PurchaseItem(itemName)
	if result == PURCHASE_ITEM_SUCCESS then
		BuyLog(
			"bought %s via=%s for=%s gold=%d%s",
			ShortItem(itemName),
			via,
			ShortItem(forItem or itemName),
			bot:GetGold(),
			extra or ""
		)
	else
		bot._buyFailLogAt = bot._buyFailLogAt or {}
		if DotaTime() >= (bot._buyFailLogAt[itemName] or -999) then
			bot._buyFailLogAt[itemName] = DotaTime() + 30
			BuyLog("buy-failed %s via=%s result=%s gold=%d", ShortItem(itemName), via, tostring(result), bot:GetGold())
		end
	end
	return result
end
local function IsBasicItem(name)
	if type(Item[name]) == "table" then
		return false
	end
	local ok, parts = pcall(GetItemComponents, name)
	return not ok or type(parts) ~= "table" or #parts == 0
end
-- An ingredient of this recipe's item that the hero does not own yet, or nil.
local function MissingIngredient(recipe)
	local parent = string.gsub(recipe, "^item_recipe_", "item_")
	local parts = Item[parent]
	if type(parts) ~= "table" then
		local ok, list = pcall(Item.GetComponentList, parent)
		parts = ok and list or nil
	end
	if type(parts) ~= "table" then
		return nil
	end
	local need = {}
	for _, part in ipairs(parts) do
		if type(part) == "string" and part ~= recipe and not string.find(part, "item_recipe_", 1, true) then
			need[part] = (need[part] or 0) + 1
		end
	end
	for part, count in pairs(need) do
		if CountItem(bot, part) < count then
			return part
		end
	end
	return nil
end
local CourierHasItem
-- true when one of names is seen on the courier.
local function CourierHasItemAny(names)
	for _, name in ipairs(names) do
		if CourierHasItem(name) == true then
			return true
		end
	end
	return false
end
-- true/false when the courier's slots can be read, nil when there is no courier handle.
function CourierHasItem(name)
	local courier = bot.theCourier
	if courier == nil then
		return nil
	end
	local ok, found = pcall(function()
		for slot = 0, 8 do
			local it = courier:GetItemInSlot(slot)
			if it ~= nil and it:GetName() == name then
				return true
			end
		end
		return false
	end)
	if not ok then
		return nil
	end
	return found
end
-- How many times one recipe may put its ingredient back in the queue before the
-- re-queues stop counting as progress.
local MAX_REQUEUES = 3
-- The missing ingredient plus every part it is built from (Ring of Basilius -> Sobi Mask,
-- its recipe, ...). A composite ingredient never sits in the basic buy list itself.
local function IngredientParts(name)
	local parts = { name }
	local function walk(itemName, depth)
		local list = Item[itemName]
		if depth > 3 or type(list) ~= "table" then
			return
		end
		for _, part in ipairs(list) do
			if type(part) == "string" then
				parts[#parts + 1] = part
				walk(part, depth + 1)
			end
		end
	end
	walk(name, 0)
	return parts
end
-- A recipe is bought only after its own ingredients. Returns true when the recipe was
-- held back this think.
local function HoldRecipe()
	local item = bot.currBuyingBasicItem
	if type(item) ~= "string" or not string.find(item, "item_recipe_", 1, true) then
		return false
	end
	-- A recipe whose item the hero already has as many of as this build wants is a
	-- leftover from a rebuild. Buying its ingredients would make an extra item.
	local parent = string.gsub(item, "^item_recipe_", "item_")
	local wanted = bot._recipeTarget and bot._recipeTarget[parent]
	if wanted ~= nil and CountItem(bot, parent) >= wanted then
		BuyLog(
			"recipe-stray %s owned=%d wanted=%d for=%s",
			ShortItem(item),
			CountItem(bot, parent),
			wanted,
			ShortItem(bot.currBuyingItemInPurchaseList)
		)
		FinishBasicItem()
		return true
	end
	bot._recipeHold = bot._recipeHold or {}
	local missing = MissingIngredient(item)
	if missing == nil then
		bot._recipeHold[item] = nil
		return false
	end
	local parts = IngredientParts(missing)
	local isPart = {}
	for _, part in ipairs(parts) do
		isPart[part] = true
	end
	local list = bot.currBuyingBasicItemList
	-- Nearest upcoming entry for this ingredient or one of its parts. Buy order runs from
	-- the end of the list, so the highest index below the recipe is the next one bought.
	local queuedAt = nil
	for i = #list - 1, 1, -1 do
		if isPart[list[i]] then
			queuedAt = i
			break
		end
	end
	-- Only act on an ingredient this build planned to buy. An upgrade recipe can name an
	-- item whose parts the hero no longer holds (boots inside Travel Boots); leave those alone.
	local planned = false
	for _, entry in ipairs(bot.currBuyingBasicItemRefList or {}) do
		if isPart[entry] then
			planned = true
			break
		end
	end
	if queuedAt == nil and not planned then
		bot._recipeHold[item] = nil
		return false
	end
	local now = DotaTime()
	local hold = bot._recipeHold[item]
	if hold == nil then
		hold = { since = now, requeues = 0 }
		bot._recipeHold[item] = hold
	end
	-- The 60s only counts time spent truly stuck. Queuing or deferring for the ingredient
	-- restarts it; waiting on the courier and repeated failed re-queues do not.
	if now - hold.since > 60 then
		if not hold.forcedLogged then
			hold.forcedLogged = true
			BuyLog(
				"recipe-forced %s missing=%s requeues=%d for=%s",
				ShortItem(item),
				ShortItem(missing),
				hold.requeues,
				ShortItem(bot.currBuyingItemInPurchaseList)
			)
		end
		return false
	end
	-- Courier first. An ingredient already bought and on its way must not be matched to a
	-- later copy in the queue (a Sobi Mask meant for Urn pushed the Ring of Basilius recipe
	-- to the end of the build, and Arcane Boots never combined).
	local onCourier = nil
	for _, part in ipairs(parts) do
		local found = CourierHasItem(part)
		if found == true then
			onCourier = true
			break
		elseif found == false then
			onCourier = false
		end
	end
	if onCourier == nil then
		onCourier = (bot:GetCourierValue() or 0) > 0
	end
	local action
	if onCourier then
		action = "wait-courier"
		-- The part is seen on the courier: keep waiting instead of forcing the recipe after 60s
		-- (game 015: Veil recipe forced while the Robe was on its way, then a second Veil started).
		if CourierHasItemAny ~= nil and CourierHasItemAny(parts) then
			hold.since = now
		end
	elseif queuedAt ~= nil then
		-- Sit right behind that part instead of at the very end of the build.
		list[#list] = nil
		table.insert(list, queuedAt, item)
		action = "defer"
		hold.since = now
	else
		-- Planned but fell out of the queue: put back the basic parts the hero lacks. A part
		-- he already holds as a built item counts as owned with everything inside it: game 015,
		-- Mekansm had not combined yet when the Greaves recipe came up, and the Ring of Regen
		-- inside his Headdress was queued again because only basic items were counted.
		local need = {}
		local function NeedParts(itemName, depth)
			if CountItem(bot, itemName) >= 1 or depth > 4 then
				return
			end
			local list = Item[itemName]
			if type(list) ~= "table" or IsBasicItem(itemName) then
				need[itemName] = (need[itemName] or 0) + 1
				return
			end
			for _, part in ipairs(list) do
				if type(part) == "string" then
					NeedParts(part, depth + 1)
				end
			end
		end
		NeedParts(missing, 0)
		local added = 0
		for part, count in pairs(need) do
			for _ = 1, count - CountItem(bot, part) do
				list[#list + 1] = part
				added = added + 1
			end
		end
		if added == 0 then
			bot._recipeHold[item] = nil
			return false
		end
		hold.requeues = hold.requeues + 1
		action = "queue"
		if hold.requeues <= MAX_REQUEUES then
			hold.since = now
		end
	end
	bot.currBuyingBasicItem = nil
	if bot._recipeHoldLogAt == nil or now >= bot._recipeHoldLogAt then
		bot._recipeHoldLogAt = now + 3
		BuyLog(
			"recipe-hold %s missing=%s action=%s requeues=%d for=%s gold=%d",
			ShortItem(item),
			ShortItem(missing),
			action,
			hold.requeues,
			ShortItem(bot.currBuyingItemInPurchaseList),
			bot:GetGold()
		)
	end
	return true
end
-- A failed purchase removes the item from the queue only when the shop will never sell it
-- (out of stock, disallowed, unknown name). Unlimited items report stock 0, so the old
-- "stock < 1" rule also dropped items that only failed for gold or shop distance.
local function FailureDropsItem(result, stock)
	if PURCHASE_ITEM_OUT_OF_STOCK ~= nil then
		return result == PURCHASE_ITEM_OUT_OF_STOCK
			or result == PURCHASE_ITEM_DISALLOWED_ITEM
			or result == PURCHASE_ITEM_INVALID_ITEM_NAME
	end
	return stock < 1 and result ~= 63
end
local function BuyBasicItem()
	if bot.lastItemToBuy ~= bot.currBuyingBasicItem then
		bot.lastItemToBuy = bot.currBuyingBasicItem
		bot:SetNextItemPurchaseValue(GetItemCost(bot.currBuyingBasicItem))
		bot.bPurchaseFromSecret = IsItemPurchasedFromSecretShop(bot.currBuyingBasicItem)
		nextItemCost = GetItemCost(bot.currBuyingBasicItem)
	end
	if bot.currBuyingBasicItem == "item_infused_raindrop" or bot.currBuyingBasicItem == "item_flask" then
		if GetItemStockCount(bot.currBuyingBasicItem) <= 0 then
			FinishBasicItem()
			return
		end
	end
	local nextItem = NextBasicItem()
	if not nextItem then
		return
	end
	bot.currBuyingBasicItem = nextItem
	if HoldRecipe() then
		return
	end
	if IsRepeatedPurchase(bot.currBuyingBasicItem) then
		return
	end
	-- The price set at the top of BuyBasicItem belongs to the item picked last think. In the opening
	-- loop that was a 50-gold Branch, so a hero with 110 gold tried the wand recipe and failed.
	if bot.lastItemToBuy ~= bot.currBuyingBasicItem then
		bot.lastItemToBuy = bot.currBuyingBasicItem
		bot:SetNextItemPurchaseValue(GetItemCost(bot.currBuyingBasicItem))
		bot.bPurchaseFromSecret = IsItemPurchasedFromSecretShop(bot.currBuyingBasicItem)
		nextItemCost = GetItemCost(bot.currBuyingBasicItem)
	end
	local requiredGold = nextItemCost
	if
		bot.lastItemToBuy == "item_boots"
		and bot.currBuyingItemInPurchaseList == "item_travel_boots"
		and Item.HasBootsInMainSolt(bot)
	then
		requiredGold = GetItemCost("item_travel_boots")
	end
	if bot:GetLevel() >= 18 and keepBuybackGold == false and DotaTime() > lastBuybackCheckTime + 1.0 then
		for i = 2, 8, 3 do
			local tower = GetTower(GetTeam(), i)
			if tower == nil or tower:GetHealth() / tower:GetMaxHealth() < 0.3 then
				keepBuybackGold = true
				break
			end
		end
		for i = 1, 7, 3 do
			local tower = GetTower(GetTeam(), i)
			if tower ~= nil and tower:IsAlive() then
				keepBuybackGold = false
				break
			end
		end
		for i = 9, 10, 1 do
			local tower = GetTower(GetTeam(), i)
			if tower == nil or tower:GetHealth() / tower:GetMaxHealth() < 0.9 then
				keepBuybackGold = true
				break
			end
		end
		if DotaTime() >= 54 * 60 then
			keepBuybackGold = true
		end
		lastBuybackCheckTime = DotaTime()
	elseif keepBuybackGold == true and bot:GetBuybackCooldown() <= 10 then
		-- Buyback reserve. Game 036: Primal Beast bought nothing 38:26-52:43 and Lion nothing after
		-- 40:00. Supports (pos 4-5) keep no reserve, and a core holds one item at most 3 min; then
		-- it buys and the next item can be held again. [OHA-BUY] hold-for-buyback logs the wait.
		local reserveTo = nextItemCost + bot:GetBuybackCost() + bot:GetNetWorth() / 40 - 300
		if Fu.GetPosition(bot) <= 3 and bot:GetGold() < reserveTo then
			if bot:GetGold() >= nextItemCost then
				if bot._bbHoldItem ~= bot.currBuyingBasicItem then
					bot._bbHoldItem = bot.currBuyingBasicItem
					bot._bbHoldSince = DotaTime()
				end
				local held = DotaTime() - (bot._bbHoldSince or DotaTime())
				if held < 180 then
					requiredGold = reserveTo
					if DotaTime() >= (bot._bbHoldLogAt or -999) then
						bot._bbHoldLogAt = DotaTime() + 30
						BuyLog(
							"hold-for-buyback item=%s gold=%d need=%d buyback=%d held=%.0fs",
							ShortItem(bot.currBuyingBasicItem),
							bot:GetGold(),
							math.floor(reserveTo),
							bot:GetBuybackCost(),
							held
						)
					end
				elseif not bot._bbHoldReleased then
					bot._bbHoldReleased = true
					BuyLog(
						"hold-for-buyback released item=%s gold=%d after=%.0fs",
						ShortItem(bot.currBuyingBasicItem),
						bot:GetGold(),
						held
					)
				end
			else
				requiredGold = reserveTo
			end
		end
	end
	if bot._bbHoldItem ~= nil and bot._bbHoldItem ~= bot.currBuyingBasicItem then
		bot._bbHoldItem, bot._bbHoldSince, bot._bbHoldReleased = nil, nil, nil
	end
	if #bot.currBuyingBasicItemList == 1 or Role.IsPvNMode() then
		requiredGold = nextItemCost
	end
	if not bot.hasBuyShard and DotaTime() > 12 * 60 then
		local shardTimeLeft = 15 * 60 - DotaTime()
		if shardTimeLeft < 0 then
			requiredGold = requiredGold + 1400
		else
			requiredGold = requiredGold + 1400 * (1 - shardTimeLeft / 300)
		end
	end
	if bot.currBuyingBasicItem == "item_aghanims_shard" then
		bot.hasBuyShard = false
		FinishBasicItem()
		return
	end
	if bot:GetGold() >= requiredGold and bot:GetItemInSlot(14) == nil then
		if
			DotaTime() < 20
			and (bot:DistanceFromFountain() > 1000 or Item.GetEmptyInventoryAmount(bot) < 1)
			and bot:DistanceFromSecretShop() > 300
		then
			return
		end
		if courier == nil then
			courier = bot.theCourier
		end
		if bot.SecretShop and courier ~= nil and courier:DistanceFromSecretShop() == 0 then
			local courierResult = Purchase(
				courier,
				bot.currBuyingBasicItem,
				"plan-courier",
				bot.currBuyingItemInPurchaseList,
				string.format(" left=%d courier=secret", math.max(0, #bot.currBuyingBasicItemList - 1))
			)
			if courierResult == PURCHASE_ITEM_SUCCESS then
				FinishBasicItem()
				bot.SecretShop = false
				return
			elseif FailureDropsItem(courierResult, GetItemStockCount(bot.currBuyingBasicItem)) then
				FinishBasicItem()
				bot.SecretShop = false
				return
			end
		end
		if bot.bPurchaseFromSecret and bot:DistanceFromSecretShop() > 0 then
			bot.SecretShop = true
		else
			if Utils.CountBackpackEmptySpace(bot) > 0 or bot:DistanceFromSecretShop() > 700 then
				local result = Purchase(
					bot,
					bot.currBuyingBasicItem,
					"plan",
					bot.currBuyingItemInPurchaseList,
					string.format(" left=%d", math.max(0, #bot.currBuyingBasicItemList - 1))
				)
				if result == PURCHASE_ITEM_SUCCESS then
					FinishBasicItem()
					bot.SecretShop = false
					return
				else
					local stock = GetItemStockCount(bot.currBuyingBasicItem)
					if FailureDropsItem(result, stock) then
						-- The item leaves the queue here. If it was an ingredient, the recipe guard puts it back.
						BuyLog(
							"dropped %s for=%s result=%s stock=%s gold=%d",
							ShortItem(bot.currBuyingBasicItem),
							ShortItem(bot.currBuyingItemInPurchaseList),
							tostring(result),
							tostring(stock),
							bot:GetGold()
						)
						FinishBasicItem()
						bot.SecretShop = false
					else
						-- A retry that goes through used to leave the item queued, so it was bought again.
						if
							Purchase(bot, bot.currBuyingBasicItem, "plan-retry", bot.currBuyingItemInPurchaseList)
							== PURCHASE_ITEM_SUCCESS
						then
							FinishBasicItem()
							bot.SecretShop = false
						end
					end
				end
			end
		end
	else
		bot.SecretShop = false
	end
end
-- true when the build still uses this item (the item itself or a part of one still to buy); defined with the sell
-- marks below.
local NeededLater
-- A sell rule skips an item the build still uses (#15, game 065: Dark Willow's Circlets for her Urn were sold at the
-- fountain right after each buy, 5 times from 33:59 and twice at 42:36). One line per item every 60s.
local function KeepForBuild(itemName, rule)
	if not NeededLater(itemName) then
		return false
	end
	bot._sellKeepLogAt = bot._sellKeepLogAt or {}
	if DotaTime() >= (bot._sellKeepLogAt[itemName] or -999) then
		bot._sellKeepLogAt[itemName] = DotaTime() + 60
		BuyLog(
			"sell-keep %s why=%s for=%s",
			ShortItem(itemName),
			rule,
			ShortItem(bot.currBuyingItemInPurchaseList or "-")
		)
	end
	return true
end
local function BuyBasicItemTurbo()
	local nextItem = NextBasicItem()
	if not nextItem then
		return
	end
	bot.currBuyingBasicItem = nextItem
	if HoldRecipe() then
		return
	end
	if IsRepeatedPurchase(bot.currBuyingBasicItem) then
		return
	end
	if bot.lastItemToBuy ~= bot.currBuyingBasicItem then
		bot.lastItemToBuy = bot.currBuyingBasicItem
		bot:SetNextItemPurchaseValue(GetItemCost(bot.currBuyingBasicItem))
		nextItemCost = GetItemCost(bot.currBuyingBasicItem)
		bot.lastItemToBuy = bot.currBuyingBasicItem
	end
	if bot.currBuyingBasicItem == "item_infused_raindrop" then
		if GetItemStockCount(bot.currBuyingBasicItem) <= 0 then
			FinishBasicItem()
			return
		end
	end
	local requiredGold = nextItemCost
	if
		bot.lastItemToBuy == "item_boots"
		and bot.currBuyingItemInPurchaseList == "item_travel_boots"
		and Item.HasBootsInMainSolt(bot)
	then
		requiredGold = GetItemCost("item_travel_boots")
	end
	if not bot.hasBuyShard and DotaTime() > 8 * 60 then
		local shardTimeLeft = 10 * 60 - DotaTime()
		if shardTimeLeft < 0 then
			requiredGold = requiredGold + 1400
		else
			requiredGold = requiredGold + 1400 * (1 - shardTimeLeft / 180)
		end
	end
	if bot.currBuyingBasicItem == "item_aghanims_shard" then
		bot.hasBuyShard = false
		FinishBasicItem()
		return
	end
	if bot:GetGold() >= requiredGold and bot:GetItemInSlot(14) == nil then
		if
			DotaTime() < 20
			and (bot:DistanceFromFountain() > 1000 or Item.GetEmptyInventoryAmount(bot) < 1)
			and bot:DistanceFromSecretShop() > 300
		then
			return
		end
		local result = Purchase(
			bot,
			bot.currBuyingBasicItem,
			"plan-turbo",
			bot.currBuyingItemInPurchaseList,
			string.format(" left=%d", math.max(0, #bot.currBuyingBasicItemList - 1))
		)
		if result == PURCHASE_ITEM_SUCCESS then
			FinishBasicItem()
			return
		else
			local stock = GetItemStockCount(bot.currBuyingBasicItem)
			if FailureDropsItem(result, stock) then
				BuyLog(
					"dropped %s for=%s result=%s stock=%s gold=%d",
					ShortItem(bot.currBuyingBasicItem),
					ShortItem(bot.currBuyingItemInPurchaseList),
					tostring(result),
					tostring(stock),
					bot:GetGold()
				)
				FinishBasicItem()
			else
				if
					Purchase(bot, bot.currBuyingBasicItem, "plan-retry", bot.currBuyingItemInPurchaseList)
					== PURCHASE_ITEM_SUCCESS
				then
					FinishBasicItem()
				end
			end
		end
	end
end
function ItemPurchaseThink()
	now = DotaTime()
	local isStale, currentHero, currentName = Fu.IsStaleARDMHero(bot, botName)
	if isStale then
		return
	end
	if currentName ~= botName then
		if not currentHero:IsAlive() then
			return
		end
		log("[ARDM] Item purchase: hero changed from %s to %s", botName, currentName)
		bot = currentHero
		botName = currentName
		local heroFile = string.gsub(botName, "npc_dota_", "")
		local loaded, newHeroModule = pcall(dofile, GetScriptDirectory() .. "/BotsLib/" .. heroFile)
		if loaded and newHeroModule ~= nil and newHeroModule["sBuyList"] ~= nil then
			heroModule = newHeroModule
			buyList = FixTravelBoots(newHeroModule["sBuyList"])
			sellList = newHeroModule["sSellList"]
		else
			buyList = {}
			sellList = {}
		end
		local ownsBoots = Item.HasBuyBoots(bot)
			or Item.HasItem(bot, "item_guardian_greaves")
			or Item.HasItem(bot, "item_travel_boots")
			or Item.HasItem(bot, "item_travel_boots_2")
			or Item.HasItem(bot, "item_boots_of_bearing")
		local earlyBootsSet = {
			item_boots = true,
			item_phase_boots = true,
			item_power_treads = true,
			item_tranquil_boots = true,
			item_arcane_boots = true,
		}
		bot.purchaseListInReverseOrder = {}
		local count = 0
		for i = #buyList, 1, -1 do
			local itemName = buyList[i]
			local skip = false
			if Item.IsItemInHero(itemName) then
				skip = true
			elseif GetGameMode() == GAMEMODE_ARDM and DotaTime() > 2 * 60 and tEarlyGameItems[itemName] then
				skip = true
			elseif ownsBoots and earlyBootsSet[itemName] then
				skip = true
			end
			if not skip then
				count = count + 1
				bot.purchaseListInReverseOrder[count] = itemName
			end
		end
		local neededItems = {}
		for _, itemName in ipairs(buyList) do
			neededItems[itemName] = true
			if Item[itemName] ~= nil then
				for _, component in pairs(Item[itemName]) do
					neededItems[component] = true
				end
			end
		end
		local keepItems = {
			item_aegis = true,
			item_rapier = true,
			item_gem = true,
			item_cheese = true,
			item_refresher_shard = true,
			item_moon_shard = true,
			item_tpscroll = true,
			item_famango = true,
			item_great_famango = true,
			item_greater_famango = true,
		}
		local sellCandidates = {}
		for slot = 0, 14 do
			local item = bot:GetItemInSlot(slot)
			if item ~= nil then
				local itemName = item:GetName()
				if not keepItems[itemName] and not neededItems[itemName] and not string.find(itemName, "token") then
					table.insert(sellCandidates, { slot = slot, name = itemName, cost = GetItemCost(itemName) })
				end
			end
		end
		table.sort(sellCandidates, function(left, right)
			return left.cost < right.cost
		end)
		local minFreeSlots = 3
		for _, candidate in ipairs(sellCandidates) do
			local item = bot:GetItemInSlot(candidate.slot)
			if item ~= nil then
				if string.find(candidate.name, "recipe") or candidate.cost < 1000 then
					bot:ActionImmediate_SellItem(item)
					log("[ARDM] Sold: %s (cost: %s)", candidate.name, candidate.cost)
				end
			end
		end
		local usedSlots = 0
		for slot = 0, 8 do
			if bot:GetItemInSlot(slot) ~= nil then
				usedSlots = usedSlots + 1
			end
		end
		local freeSlots = 9 - usedSlots
		if freeSlots < minFreeSlots then
			for _, candidate in ipairs(sellCandidates) do
				if freeSlots >= minFreeSlots then
					break
				end
				local item = bot:GetItemInSlot(candidate.slot)
				if item ~= nil then
					bot:ActionImmediate_SellItem(item)
					log("[ARDM] Sold (full inv): %s (cost: %s)", candidate.name, candidate.cost)
					freeSlots = freeSlots + 1
				end
			end
		end
		bot.currBuyingItemInPurchaseList = nil
		bot.currBuyingBasicItem = nil
		bot.currBuyingBasicItemList = {}
		bot.currBuyingBasicItemRefList = {}
		bot.currBuyingRequiredCounts = nil
		bot.rebuildCount = 0
		bot.countInvCheck = 0
	end
	if bot.needPurchaseRebuild then
		bot.needPurchaseRebuild = nil
		local position = Fu.GetPosition(bot)
		log("[PosSwap] Item purchase rebuild for %s -> pos%s", botName, position)
		local heroFile = string.gsub(botName, "npc_dota_", "")
		local loaded, newHeroModule = pcall(dofile, GetScriptDirectory() .. "/BotsLib/" .. heroFile)
		if loaded and newHeroModule ~= nil and newHeroModule["sBuyList"] ~= nil then
			heroModule = newHeroModule
			buyList = FixTravelBoots(newHeroModule["sBuyList"])
			sellList = newHeroModule["sSellList"]
		end
		if buyList then
			local ownsBoots = Item.HasBuyBoots(bot)
				or Item.HasItem(bot, "item_guardian_greaves")
				or Item.HasItem(bot, "item_travel_boots")
				or Item.HasItem(bot, "item_travel_boots_2")
				or Item.HasItem(bot, "item_boots_of_bearing")
			local earlyBootsSet = {
				item_boots = true,
				item_phase_boots = true,
				item_power_treads = true,
				item_tranquil_boots = true,
				item_arcane_boots = true,
			}
			-- The new position's boots replace the old pair. Dropping them from the buy list
			-- left the old pair in the inventory, so a swap stacked two pairs of boots.
			if ownsBoots then
				local kept = {}
				for i = 1, #buyList do
					kept[buyList[i]] = true
					for _, part in pairs(Item[buyList[i]] or {}) do
						kept[part] = true
					end
				end
				for _, boot in pairs(Item["tEarlyBoots"]) do
					if not kept[boot] then
						local slot = bot:FindItemSlot(boot)
						if slot >= 0 and slot <= 8 then
							log("[PosSwap] Selling %s — %s no longer builds it", boot, botName)
							bot:ActionImmediate_SellItem(bot:GetItemInSlot(slot))
						end
					end
				end
			end
			bot.purchaseListInReverseOrder = {}
			local count = 0
			for i = #buyList, 1, -1 do
				local itemName = buyList[i]
				local skip = false
				if Item.IsItemInHero(itemName) then
					skip = true
				elseif ownsBoots and earlyBootsSet[itemName] then
					skip = true
				elseif DotaTime() > 10 * 60 and tEarlyGameItems[itemName] then
					skip = true
				end
				if not skip then
					count = count + 1
					bot.purchaseListInReverseOrder[count] = itemName
				end
			end
		end
		bot.currBuyingItemInPurchaseList = nil
		bot.currBuyingBasicItem = nil
		bot.currBuyingBasicItemList = {}
		bot.currBuyingBasicItemRefList = {}
		bot.currBuyingRequiredCounts = nil
		bot.rebuildCount = 0
		bot.countInvCheck = 0
		log("[PosSwap] Purchase list rebuilt with %s items", #bot.purchaseListInReverseOrder)
	end
	if bot.lastItemPurchaseFrameProcessTime == nil then
		bot.lastItemPurchaseFrameProcessTime = now
	end
	if now > 30 and now - bot.lastItemPurchaseFrameProcessTime < 1 then
		return
	end
	bot.lastItemPurchaseFrameProcessTime = now
	if GetGameState() ~= GAME_STATE_PRE_GAME and GetGameState() ~= GAME_STATE_GAME_IN_PROGRESS then
		return
	end
	if
		bot:IsIllusion()
		or bot:HasModifier("modifier_arc_warden_tempest_double")
		or now > 0 and Fu.IsMeepoClone(bot)
		or bot:HasModifier("modifier_dazzle_nothl_projection_soul_debuff")
	then
		bot.purchaseListInReverseOrder = {}
		return
	end
	botLevel = bot:GetLevel()
	gold = bot:GetGold()
	netWorth = bot:GetNetWorth()
	activeMode = bot:GetActiveMode()
	courierValue = bot:GetCourierValue()
	stashValue = bot:GetStashValue()
	fountainDistance = bot:DistanceFromFountain()
	QueueRightclickCounters()
	PromoteBackpackCounters()
	PreferBloodGrenadeOverBranch()
	if Item.TryPickupRoshanDrop(bot) then
		return
	end
	local droppedItems = GetDroppedItemList()
	for _, drop in pairs(droppedItems) do
		if
			drop ~= nil
			and drop.owner == bot
			and drop.item ~= nil
			and not string.find(drop.item:GetName(), "token")
			and not Utils.HasValue(Item.tEarlyConsumableItem, drop.item:GetName())
			and drop.item:GetName() ~= "item_famango"
			and drop.item:GetName() ~= "item_great_famango"
			and drop.item:GetName() ~= "item_greater_famango"
			-- Never re-pick wards we just handed to supports (breaks drop↔pickup loops).
			and drop.item:GetName() ~= "item_ward_observer"
			and drop.item:GetName() ~= "item_ward_sentry"
			and drop.item:GetName() ~= "item_ward_dispenser"
			and Item.RoshanClaimKind(drop.item:GetName()) == nil
			-- Not another player's item this bot dropped (#141): whether drop.owner names the buyer or whoever
			-- dropped it is unverified, and the second would walk the bot straight back to it.
			and not ForeignItems.WasDropped(bot, drop.item:GetName())
		then
			local distance = GetUnitToLocationDistance(bot, drop.location)
			if distance > 200 and distance < 1000 then
				bot:Action_MoveToLocation(drop.location)
			elseif distance <= 100 then
				bot:Action_PickUpItem(drop.item)
				return
			end
		end
	end
	if Utils.IsBear(bot) and bot:IsAlive() then
		local bearItemsMap = Utils.GetLoneDruid(bot).bearItemsMap or {}
		local droppedItems = GetDroppedItemList()
		for _, drop in pairs(droppedItems) do
			if
				drop.owner == Utils.GetLoneDruid(bot).hero
				and drop.item ~= nil
				and not string.find(drop.item:GetName(), "token")
			then
				local itemName = drop.item:GetName()
				if bearItemsMap[itemName] and not Item.HasItem(bot, itemName) then
					local distance = GetUnitToLocationDistance(bot, drop.location)
					if distance > 100 and distance < 1000 then
						bot:Action_MoveToLocation(drop.location)
						return
					elseif distance <= 100 then
						bot:Action_PickUpItem(drop.item)
						return
					end
				end
			end
		end
	end
	if Role["supportExist"] == nil then
		Role.UpdateSupportStatus(bot)
	end
	if Role["invisEnemyExist"] == false then
		Role.UpdateInvisEnemyStatus(bot)
	end
	if hasBoots == false and now > lastBootsCheckTime + 2.0 then
		hasBoots = Item.HasBuyBoots(bot)
		lastBootsCheckTime = now
	end
	if
		Fu.GetMP(bot) < 0.3
		and fountainDistance > 2000
		and courierValue == 0
		and GetItemStockCount("item_clarity") > 1
		and Item.GetItemCharges(bot, "item_clarity") <= 0
		and gold >= GetItemCost("item_clarity")
		-- Not right after a full-inventory sale of a Clarity (game 067: Undying sold one at 42:29 and bought one at
		-- 42:30, a 25-gold loop also seen on Zeus and Death Prophet).
		and now >= (bot._claritySoldAt or -999) + 60
	then
		bot.hasBuyClarity = true
		Purchase(bot, "item_clarity", "low-mana", "item_clarity")
	end
	if Fu.GetPosition(bot) >= 4 then
		if
			now > 30
			and not bot.hasBuyClarity
			and gold >= GetItemCost("item_clarity")
			and not Role.IsPvNMode()
			and Utils.CountBackpackEmptySpace(bot) >= 2
		then
			bot.hasBuyClarity = true
			Purchase(bot, "item_clarity", "support-clarity", "item_clarity")
		elseif
			botLevel >= 5
			and Role["invisEnemyExist"] == true
			and hasBoots == true
			and gold >= GetItemCost("item_dust")
			and Item.GetEmptyInventoryAmount(bot) >= 2
			and Item.GetItemCharges(bot, "item_dust") <= 0
			and courierValue == 0
			and not Fu.HasItem(bot, "item_ward_sentry")
		then
			Purchase(bot, "item_dust", "support-dust", "item_dust")
		end
	end
	if Fu.IsInLaningPhase() and not string.find(botName, "lone_druid") then
		if
			botLevel < 6
			and bot:IsAlive()
			and courierValue == 0
			and bot:FindItemSlot("item_flask") < 0
			and bot:FindItemSlot("item_tango") < 0
			and fountainDistance > 2000
			and stashValue == 0
			and not bot:HasModifier("modifier_elixer_healing")
			and not bot:HasModifier("modifier_filler_heal")
			and not bot:HasModifier("modifier_flask_healing")
			and not bot:HasModifier("modifier_fountain_aura_buff")
			and not bot:HasModifier("modifier_juggernaut_healing_ward_heal")
			and not bot:HasModifier("modifier_warlock_shadow_word")
			and not IsThereHealingInStash(bot)
			and Item.GetEmptyInventoryAmount(bot) >= 1
			and Fu.GetHP(bot) < 0.5
		then
			local lanePartner = Fu.GetLanePartner(bot)
			if bot:GetHealthRegen() <= 10 then
				if Fu.IsCore(bot) then
					if lanePartner ~= nil then
						if
							lanePartner:FindItemSlot("item_flask") < 0
							and lanePartner:FindItemSlot("item_tango") < 0
							and Item.GetItemCharges(bot, "item_flask") <= 0
							and gold >= GetItemCost("item_flask")
							and GetItemStockCount("item_flask") > 1
						then
							bot:ActionImmediate_PurchaseItem("item_flask")
						end
					else
						if
							Item.GetItemCharges(bot, "item_flask") <= 0
							and gold >= GetItemCost("item_flask")
							and GetItemStockCount("item_flask") > 1
							and (
								not Fu.HasItem(bot, "item_bottle")
								or Fu.HasItem(bot, "item_bottle") and Item.GetItemCharges(bot, "item_bottle") <= 0
							)
						then
							bot:ActionImmediate_PurchaseItem("item_flask")
						end
					end
				else
					if
						Item.GetItemCharges(bot, "item_flask") <= 0
						and gold >= GetItemCost("item_flask")
						and GetItemStockCount("item_flask") > 1
					then
						bot:ActionImmediate_PurchaseItem("item_flask")
					end
				end
			else
				if Fu.IsCore(bot) then
					if lanePartner ~= nil then
						if
							lanePartner:FindItemSlot("item_flask") < 0
							and lanePartner:FindItemSlot("item_tango") < 0
							and lanePartner ~= nil
							and Item.GetItemCharges(bot, "item_tango") <= 0
							and gold >= GetItemCost("item_tango")
							and GetItemStockCount("item_flask") > 1
						then
							bot:ActionImmediate_PurchaseItem("item_tango")
						end
					else
						if
							Item.GetItemCharges(bot, "item_flask") <= 0
							and GetItemStockCount("item_flask") > 1
							and gold >= GetItemCost("item_flask")
							and (
								not Fu.HasItem(bot, "item_bottle")
								or Fu.HasItem(bot, "item_bottle") and Item.GetItemCharges(bot, "item_bottle") <= 0
							)
						then
							bot:ActionImmediate_PurchaseItem("item_flask")
						end
					end
				else
					if Item.GetItemCharges(bot, "item_tango") <= 0 and gold >= GetItemCost("item_tango") then
						bot:ActionImmediate_PurchaseItem("item_tango")
					end
				end
			end
		end
	end
	-- Supports buy wards. Old gates were too strict: stock > 1, 2 empty slots,
	-- pos4 sentry only after 5m, and obs/sentry split by exact role — so bags full
	-- of starting consumables meant nobody bought.
	local wardNames = { "item_ward_observer", "item_ward_sentry", "item_ward_dispenser" }
	local obsForHumans = Fu.GetPosition(bot) >= 4 and ObserverStockForHumans()
	if Fu.GetPosition(bot) >= 4 and courierValue == 0 then
		local emptySlots = Item.GetEmptyInventoryAmount(bot)
		-- A buy outside the fountain shop goes straight to the stash. During the
		-- opening that sentry then sits there, so require a free slot and the shop.
		-- Before the horn a ward bought away from the shop goes to the stash; the courier now
		-- brings wards out from -56s (other stash items still wait for 0:20).
		local canReceive = emptySlots >= 1 and (now >= 20 or fountainDistance <= 1000 or now >= -60)
		if canReceive then
			local function tryBuyWard(itemName, maxCharges, reason)
				if itemName == "item_ward_observer" and not obsForHumans then
					return false
				end
				if GetItemStockCount(itemName) < 1 then
					return false
				end
				if gold < GetItemCost(itemName) then
					return false
				end
				if Item.GetWardCharges(bot, itemName) >= maxCharges then
					return false
				end
				MatchTrace.Buy(bot, itemName, reason)
				Purchase(bot, itemName, "support-ward", itemName)
				gold = bot:GetGold()
				emptySlots = Item.GetEmptyInventoryAmount(bot)
				return true
			end
			-- Observers first. One sentry for the whole team before 8:00.
			-- A second waits until 8:00 or a known invis hero.
			local earlyLane = now < 8 * 60 and Role["invisEnemyExist"] ~= true
			local sentryCap = 2
			if earlyLane then
				sentryCap = 1
				for _, ally in pairs(GetUnitList(UNIT_LIST_ALLIED_HEROES) or {}) do
					if
						ally ~= nil
						and ally ~= bot
						and ally:IsHero()
						and not ally:IsIllusion()
						and Item.GetWardCharges(ally, "item_ward_sentry") >= 1
					then
						sentryCap = 0
						break
					end
				end
			end
			-- Before the horn only pos 5 buys observers (user call: pos 5 always plants the early
			-- one); the stock is shared, so pos 4 buying first left pos 5 without one.
			if now >= 0 or Fu.GetPosition(bot) == 5 then
				tryBuyWard("item_ward_observer", 2, "support obs")
			end
			if sentryCap > 0 and now > (bot._sentryBuyAt or -100) + 15 then
				if tryBuyWard("item_ward_sentry", sentryCap, "support sentry") then
					bot._sentryBuyAt = now
				end
			end
		end
		-- Supports: pick up wards a core dropped for us.
		if emptySlots >= 1 or Item.GetEmptyInventoryAmount(bot) >= 1 then
			for _, drop in pairs(GetDroppedItemList() or {}) do
				if drop ~= nil and drop.item ~= nil then
					local dropName = drop.item:GetName()
					if
						dropName == "item_ward_observer"
						or dropName == "item_ward_sentry"
						or dropName == "item_ward_dispenser"
					then
						local dropDist = GetUnitToLocationDistance(bot, drop.location)
						if dropDist <= 1200 then
							if dropDist > 120 then
								bot:Action_MoveToLocation(drop.location)
							else
								bot:Action_PickUpItem(drop.item)
							end
							return
						end
					end
				end
			end
		end
	elseif Fu.GetPosition(bot) <= 3 then
		-- Cores should not hold wards. Only drop when a support is close enough to take it;
		-- otherwise stow in backpack (never drop at own feet — that caused pick↔drop loops).
		if now > (bot._lastCoreWardDrop or -100) + 3.0 then
			local nearbySupport = nil
			for _, ally in pairs(bot:GetNearbyHeroes(450, false, BOT_MODE_NONE) or {}) do
				if ally ~= nil and ally ~= bot and ally:IsAlive() and Fu.GetPosition(ally) >= 4 then
					nearbySupport = ally
					break
				end
			end
			for _, wardName in ipairs(wardNames) do
				local wardSlot = bot:FindItemSlot(wardName)
				if wardSlot >= 0 then
					local wardItem = bot:GetItemInSlot(wardSlot)
					if wardItem ~= nil then
						bot._lastCoreWardDrop = now
						if nearbySupport ~= nil then
							MatchTrace.Buy(bot, wardName, "core handoff to support")
							bot:Action_DropItem(wardItem, nearbySupport:GetLocation())
							return
						elseif wardSlot <= 5 then
							for pack = 6, 8 do
								if bot:GetItemInSlot(pack) == nil then
									bot:ActionImmediate_SwapItems(wardSlot, pack)
									MatchTrace.Buy(bot, wardName, "core stow backpack")
									break
								end
							end
						end
					end
				end
			end
		end
	end
	-- Pos 4 and 5 both carry one now (was pos 5 under 10000 net worth with 3 free slots, which
	-- rarely held, so Smoke was seldom bought). One free main-inventory slot is required: bot
	-- swaps do not take effect, so a Smoke bought into the backpack may never get used.
	if
		Fu.GetPosition(bot) >= 4
		and GetItemStockCount("item_smoke_of_deceit") > 1
		and gold >= GetItemCost("item_smoke_of_deceit")
		and Item.GetEmptyNonBackpackInventoryAmount(bot) >= 1
		and Item.GetItemCharges(bot, "item_smoke_of_deceit") == 0
		and courierValue == 0
	then
		-- No Smoke before the horn or in the laning phase: it is wasted gold and a slot that
		-- early. Supports buy one once laning is over.
		-- By the clock: the laning-phase flag drops out mid-lane (GetDesireRaw clears it and
		-- several early returns never set it back), so Techies bought one at 7:00 in lane.
		if DotaTime() >= 12 * 60 and not Fu.IsInLaningPhase() then
			MatchTrace.Buy(bot, "item_smoke_of_deceit", "post_laning support")
			Purchase(bot, "item_smoke_of_deceit", "support-smoke", "item_smoke_of_deceit")
		end
	end
	-- No Blood Grenade rebuys: the one in the starting build (bought before the horn) is all a
	-- hero needs. Rebuys landed in full bags (Lina, Earthshaker in the backpack).
	if not bot.hasBuyShard and GetItemStockCount("item_aghanims_shard") > 0 and gold >= 1400 then
		bot.hasBuyShard = true
		Purchase(bot, "item_aghanims_shard", "shard", "item_aghanims_shard")
	end
	if wasPreGame == false and now < 0 then
		wasPreGame = true
	end
	local tpCost = GetItemCost("item_tpscroll")
	if
		now > 4 * 60
		and courierValue <= 100
		and gold >= tpCost
		and not HasEnoughTpScrolls()
		-- Meepo was skipped by name (inherited, no reason given), so he never rebought a TP (game 043, ~8:00, #8).
		-- Only the clones are skipped now: the main Meepo buys it like every hero.
		and not Fu.IsMeepoClone(bot)
		and botName ~= "npc_dota_hero_lone_druid_bear"
		-- A bought TP is not counted while the courier carries it (charges read the hero and the stash; a 100-gold
		-- TP on the courier still passes courierValue <= 100). Game 044: Meepo bought 2-3 in a row (t=371/372,
		-- 1568/1575/1576). Wait 30s after a buy.
		and now >= (bot._tpBuyHoldUntil or -999)
	then
		local tpCharges = Item.GetItemCharges(bot, "item_tpscroll")
		if bot:HasModifier("modifier_teleporting") then
			tpCharges = tpCharges - 1
		end
		if tpCharges <= 0 or botLevel >= 18 and tpCharges <= 1 then
			if gold >= tpCost * 2 and now > 25 * 60 then
				Purchase(bot, "item_tpscroll", "tp-restock", "item_tpscroll")
			end
			Purchase(bot, "item_tpscroll", "tp-restock", "item_tpscroll")
			bot._tpBuyHoldUntil = now + 30
			if botName == "npc_dota_hero_meepo" then
				pcall(print, string.format("[OHA-MEEPO] t=%.0f tp-buy charges=%d gold=%d", now, tpCharges, gold))
			end
		end
	end
	if now > 180 and now < 1800 and bot.switchTime < now - 5.6 then
		local raindropSlot = bot:FindItemSlot("item_infused_raindrop")
		local raindropCharges = Item.GetItemCharges(bot, "item_infused_raindrop")
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE)
		if
			raindropSlot >= 0
			and raindropSlot <= 5
			and (nearbyEnemies[1] ~= nil or activeMode == BOT_MODE_ROSHAN or bot:WasRecentlyDamagedByAnyHero(3.1))
			and (raindropCharges == 1 or raindropCharges >= 7)
		then
			bot.switchTime = now
			bot:ActionImmediate_SwapItems(raindropSlot, 6)
		end
	end
	if Fu.GetPosition(bot) >= 4 and now > (bot._lastWardSwapTime or 0) + 3 then
		local isWarding = activeMode == BOT_MODE_WARD
		local wardItemNames = { "item_ward_observer", "item_ward_sentry", "item_ward_dispenser" }
		for _, wardItemName in ipairs(wardItemNames) do
			local wardSlot = bot:FindItemSlot(wardItemName)
			if wardSlot >= 0 then
				if isWarding then
					if wardSlot >= 6 and wardSlot <= 8 then
						for mainSlot = 0, 5 do
							local mainItem = bot:GetItemInSlot(mainSlot)
							if mainItem == nil then
								bot:ActionImmediate_SwapItems(wardSlot, mainSlot)
								bot._lastWardSwapTime = now
								break
							end
						end
					end
				else
					-- Stash observers only. A sentry or a sentry-only dispenser
					-- goes on cooldown when it is swapped back into the bag.
					if wardItemName == "item_ward_observer" and wardSlot >= 0 and wardSlot <= 5 then
						for backpackSlot = 6, 8 do
							local backpackItem = bot:GetItemInSlot(backpackSlot)
							if backpackItem == nil then
								bot:ActionImmediate_SwapItems(wardSlot, backpackSlot)
								bot._lastWardSwapTime = now
								break
							end
						end
					end
				end
			end
		end
	end
	-- Witch Doctor: when packed, consume Gris-Gris (right-click Consume == Action_UseAbility; not SellItem).
	-- Skip early game — starting consumables fill the bag; keep Gris-Gris until ~15m (turbo ~9m).
	local grisMinTime = (GetGameMode() == GAMEMODE_TURBO or GetGameMode() == 23) and (9 * 60) or (15 * 60)
	if
		botName == "npc_dota_hero_witch_doctor"
		and now >= grisMinTime
		and now > (bot._grisPurchaseCheck or -100) + 2.0
	then
		bot._grisPurchaseCheck = now
		local mainEmpty = Item.GetEmptyNonBackpackInventoryAmount(bot)
		local packEmpty = Utils.CountBackpackEmptySpace(bot)
		if mainEmpty <= 0 and (packEmpty <= 0 or bot.currBuyingBasicItem ~= nil) then
			local grisSlot = bot:FindItemSlot("item_grisgris")
			if grisSlot >= 0 then
				local gris = bot:GetItemInSlot(grisSlot)
				if gris ~= nil then
					local locOk, loc = pcall(require, GetScriptDirectory() .. "/FuncLib/systems/localization")
					local msg = "Consuming Gris-Gris — inventory full!"
					if locOk and loc and loc.Get then
						local lines = loc.Get("say_consume_grisgris")
						if type(lines) == "table" and #lines > 0 then
							msg = lines[RandomInt(1, #lines)]
						elseif type(lines) == "string" then
							msg = lines
						end
					end
					bot:ActionImmediate_Chat(msg, true)
					if grisSlot == 16 or grisSlot >= 6 then
						for slot = 0, 8 do
							local junk = bot:GetItemInSlot(slot)
							if
								junk ~= nil
								and junk:GetName() ~= "item_grisgris"
								and junk:GetName() ~= "item_tpscroll"
								and (GetItemCost(junk:GetName()) or 0) < 600
							then
								bot:ActionImmediate_SellItem(junk)
								break
							end
						end
						for slot = 0, 5 do
							if bot:GetItemInSlot(slot) == nil then
								bot:ActionImmediate_SwapItems(grisSlot, slot)
								grisSlot = slot
								gris = bot:GetItemInSlot(slot)
								break
							end
						end
					end
					if gris ~= nil then
						bot:Action_ClearActions(false)
						bot:Action_UseAbility(gris)
						MatchTrace.Buy(bot, "item_grisgris", "consume (purchase path)")
					end
				end
			end
		end
	end
	if
		GetGameMode() ~= 23
			and botLevel > 6
			and now > bot.fullInvCheck + 1.0
			and (fountainDistance <= 200 or bot:DistanceFromSecretShop() <= 200)
		or GetGameMode() == 23 and botLevel > 9 and now > bot.fullInvCheck + 1.0
	then
		local emptyInventory = Item.GetEmptyInventoryAmount(bot)
		local sellSlot = nil
		local minEmptySlots = 2
		if botLevel <= 17 then
			minEmptySlots = 1
		end
		if not Fu.IsCore(bot) and botLevel > 10 then
			minEmptySlots = 2
		end
		if emptyInventory <= minEmptySlots - 1 then
			for i = 1, #Item["tEarlyItem"] do
				local itemName = Item["tEarlyItem"][i]
				local itemSlot = bot:FindItemSlot(itemName)
				if itemSlot >= 0 and itemSlot <= 8 and not KeepForBuild(itemName, "full") then
					sellSlot = itemSlot
					break
				end
			end
			if sellSlot == nil and not Fu.IsCore(bot) then
				for i = 1, #Item["tSupportSellWhenFull"] do
					local itemName = Item["tSupportSellWhenFull"][i]
					local itemSlot = bot:FindItemSlot(itemName)
					if itemSlot >= 0 and itemSlot <= 8 and not KeepForBuild(itemName, "full") then
						sellSlot = itemSlot
						break
					end
				end
			end
		end
		if sellSlot == nil and netWorth > 10000 and bot:GetItemInSlot(6) ~= nil and bot:GetItemInSlot(7) ~= nil then
			local wandSlot = bot:FindItemSlot("item_magic_wand")
			local cheapSlot = bot:FindItemSlot("item_infused_raindrop")
			if cheapSlot < 0 then
				cheapSlot = bot:FindItemSlot("item_bracer")
			end
			if cheapSlot < 0 then
				cheapSlot = bot:FindItemSlot("item_null_talisman")
			end
			if cheapSlot < 0 then
				cheapSlot = bot:FindItemSlot("item_wraith_band")
			end
			if
				cheapSlot >= 0
				and wandSlot >= 6
				and wandSlot <= 8
				and not KeepForBuild(bot:GetItemInSlot(cheapSlot):GetName(), "full-wand")
			then
				sellSlot = cheapSlot
			end
		end
		if sellSlot ~= nil then
			-- This sale printed nothing, so a part that went missing could not be traced (#15, game 065).
			if bot:GetItemInSlot(sellSlot):GetName() == "item_clarity" then
				bot._claritySoldAt = now
			end
			BuyLog(
				"sell-full %s slot=%d empty=%d",
				ShortItem(bot:GetItemInSlot(sellSlot):GetName()),
				sellSlot,
				emptyInventory
			)
			bot:ActionImmediate_SellItem(bot:GetItemInSlot(sellSlot))
		end
		bot.fullInvCheck = now
	end
	local backpackEmpty = Utils.CountBackpackEmptySpace(bot)
	if
		now > bot.sell_time + 0.5
		and backpackEmpty <= 1
		and (fountainDistance <= 100 or bot:DistanceFromSecretShop() <= 100)
	then
		bot.sell_time = now
		SetPairedItems(Item.sSellList)
		SetPairedItems(sellList)
		if netWorth > 23000 then
			if Item.HasItem(bot, "item_hand_of_midas") then
				bot:ActionImmediate_SellItem(bot:GetItemInSlot(bot:FindItemSlot("item_hand_of_midas")))
			end
		end
		if
			(now > 18 * 60 or netWorth > 20000)
			and (Item.HasItem(bot, "item_travel_boots") or Item.HasItem(bot, "item_travel_boots_2"))
		then
			for i = 1, #Item["tEarlyBoots"] do
				local bootsSlot = bot:FindItemSlot(Item["tEarlyBoots"][i])
				if bootsSlot >= 0 then
					bot:ActionImmediate_SellItem(bot:GetItemInSlot(bootsSlot))
				end
			end
		end
	end
	pcall(SellMarkedItems)
	if Item.HasItem(bot, "item_mask_of_madness") and Item.HasItem(bot, "item_satanic") then
		bot:ActionImmediate_SellItem(bot:GetItemInSlot(bot:FindItemSlot("item_mask_of_madness")))
	end
	-- Healing Lotus (item_famango*) cannot be sold — stack / use / drop to free a slot.
	-- Prefer supports holding them: healthy cores hand off to a nearby support with space.
	local lateLotus = (GetGameMode() == GAMEMODE_TURBO or GetGameMode() == 23) and (15 * 60) or (25 * 60)
	-- Step 0: finish greater-famango stack pickup after a merge drop, or start a merge anytime.
	if Item.TryPickupStackedGreaterFamango(bot) then
		return
	end
	if Item.CanStackGreaterFamango(bot) and now > (bot._lastLotusStack or -100) + 2.0 then
		if Item.TryStackGreaterFamango(bot) then
			bot._lastLotusStack = now
			MatchTrace.Buy(bot, "item_greater_famango", "stack merge")
			return
		end
	end
	local function NearbySupportForLotus(preferGreaterStack)
		for _, ally in pairs(bot:GetNearbyHeroes(450, false, BOT_MODE_NONE) or {}) do
			if ally ~= nil and ally ~= bot and ally:IsAlive() and Fu.GetPosition(ally) >= 4 then
				local greater = ally:FindItemSlot("item_greater_famango")
				local canStackOnAlly = false
				if preferGreaterStack and greater >= 0 then
					local gItem = ally:GetItemInSlot(greater)
					if gItem ~= nil and Item.GetLotusCharges(gItem) < Item.GREATER_FAMANGO_MAX_STACK then
						canStackOnAlly = true
					end
				end
				local emptyOk = Item.GetEmptyNonBackpackInventoryAmount(ally) >= 1 or canStackOnAlly
				if emptyOk then
					return ally
				end
			end
		end
		return nil
	end
	local function BackpackLotus()
		for slot = 6, 8 do
			local it = bot:GetItemInSlot(slot)
			if it ~= nil and not it:IsNull() then
				local name = it:GetName()
				if name == "item_famango" or name == "item_great_famango" or name == "item_greater_famango" then
					return name, slot, it
				end
			end
		end
		return nil, -1, nil
	end
	local function BackpackForage()
		for slot = 6, 8 do
			local it = bot:GetItemInSlot(slot)
			if it ~= nil and not it:IsNull() then
				local name = it:GetName()
				local backedOff = bot._forageSwapBackoff ~= nil and now < (bot._forageSwapBackoff[name] or -999)
				-- Not another player's mushroom (#141; game 062, 44:39: Medusa swapped Nature's Prophet's into a main
				-- slot): it can't be eaten, and the item think drops it.
				if
					(name == "item_foragers_health" or name == "item_foragers_stats" or name == "item_foragers_mana")
					and not backedOff
					and not ForeignItems.Check(bot, it)
				then
					return name, slot, it
				end
			end
		end
		return nil, -1, nil
	end
	-- Vital Toadstool, Ironwood Nut, Tomo'kan Ringcap. They land in the backpack, which cannot cast them.
	-- Swap one into a main slot and eat it. A drop leaves it on the ground.
	local forageCalm = #(bot:GetNearbyHeroes(1200, true, BOT_MODE_NONE) or {}) == 0
		and not bot:WasRecentlyDamagedByAnyHero(3.0)
	if forageCalm and now > (bot._lastBackpackForage or -100) + 3.0 then
		local forageName, forageSlot, forageItem = BackpackForage()
		if forageItem ~= nil then
			bot._lastBackpackForage = now
			local dest = MainSlotForBackpackItem()
			if dest == nil then
				local cheap = Item.GetMainInvLessValItemSlot(bot)
				if cheap ~= nil and cheap >= 0 then
					dest = cheap
				end
			end
			-- A mushroom that can't be used here (another hero's Forager's Kit) went back and forth every 4s for the
			-- rest of the game (game 045: Weaver, 34 swap lines). After 2 swaps of the same forage within 60s, leave it
			-- for 120s.
			bot._forageSwaps = bot._forageSwaps or {}
			local swaps = bot._forageSwaps[forageName]
			if swaps == nil or now - swaps.since > 60 then
				swaps = { n = 0, since = now }
			end
			swaps.n = swaps.n + 1
			bot._forageSwaps[forageName] = swaps
			if swaps.n > 2 then
				bot._forageSwapBackoff = bot._forageSwapBackoff or {}
				bot._forageSwapBackoff[forageName] = now + 120
				bot._forageSwaps[forageName] = nil
				pcall(
					print,
					string.format(
						"[OHA-FORAGE] t=%.0f %s swap-giveup %s why=not-used backoff=120s",
						now,
						(string.gsub(bot:GetUnitName(), "npc_dota_hero_", "")),
						forageName
					)
				)
				dest = nil
			end
			if dest ~= nil then
				ForceSwap(forageSlot, dest)
				local moved = bot:GetItemInSlot(dest)
				-- Game 031: Dazzle kept a Forager mushroom in the backpack for the rest of the game,
				-- and this step never logged a use. Log each try (once per 15s).
				if now >= (bot._forageLogAt or -999) then
					bot._forageLogAt = now + 15
					pcall(
						print,
						string.format(
							"[OHA-FORAGE] t=%.0f %s swap %s slot%d->%d moved=%s",
							now,
							(string.gsub(botName, "npc_dota_hero_", "")),
							forageName,
							forageSlot,
							dest,
							moved ~= nil and not moved:IsNull() and moved:GetName() or "-"
						)
					)
				end
				if moved ~= nil and not moved:IsNull() and moved:GetName() == forageName then
					MatchTrace.Buy(bot, forageName, "backpack forage swap and use")
					if forageName == "item_foragers_stats" or forageName == "item_foragers_mana" then
						bot:Action_UseAbility(moved)
					else
						bot:Action_UseAbilityOnEntity(moved, bot)
					end
				end
				return
			end
		end
	end
	-- Mana consumables parked in the backpack (Clarity, Enchanted Mango) were never brought back, so a bot
	-- with an empty mana pool kept them unused (game 036, 30:00+: Slark's Clarity arrived in slot 6).
	-- Game data: Clarity 6 mana/s for 25s (the usage rule skips it within 4s of hero damage), Mango 100
	-- mana at once. Below 35% mana, swap one into a main slot: a free slot, a parked consumable, else the
	-- cheapest swappable item that is not one the backpack-promote routine would pull straight back.
	-- The usage rules (item_clarity / item_enchanted_mango) cast it once the 6s backpack cooldown ends.
	if now > (bot._lastBackpackMana or -100) + 3.0 and Fu.GetMP(bot) < 0.35 and bot:DistanceFromFountain() > 2000 then
		local manaSlot, manaName = -1, nil
		for slot = 6, 8 do
			local it = bot:GetItemInSlot(slot)
			if it ~= nil and not it:IsNull() then
				local name = it:GetName()
				if
					(
						name == "item_enchanted_mango"
						or name == "item_clarity" and not bot:WasRecentlyDamagedByAnyHero(4.0)
					) and not PullBackedOff(name)
				then
					manaSlot, manaName = slot, name
					if name == "item_enchanted_mango" then
						break
					end
				end
			end
		end
		if manaName ~= nil then
			bot._lastBackpackMana = now
			local dest = nil
			for slot = 0, 5 do
				local it = bot:GetItemInSlot(slot)
				if it == nil then
					dest = slot
					break
				end
			end
			if dest == nil then
				local bestCost = math.huge
				for slot = 0, 5 do
					local it = bot:GetItemInSlot(slot)
					local name = it ~= nil and not it:IsNull() and it:GetName() or nil
					if
						name ~= nil
						and name ~= "item_clarity"
						and name ~= "item_enchanted_mango"
						and not tPromoteFromBackpack[name]
						and not Item.IsCanNotSwitchItem(name)
						and not string.find(name, "item_ward", 1, true)
					then
						local cost = PARK_IN_BACKPACK[name] and 0 or (GetItemCost(name) or 0)
						if cost < bestCost then
							bestCost, dest = cost, slot
						end
					end
				end
			end
			local out = dest ~= nil and bot:GetItemInSlot(dest) or nil
			local manaItem = bot:GetItemInSlot(manaSlot)
			local issued = false
			if dest ~= nil then
				bot:ActionImmediate_SwapItems(manaSlot, dest)
				issued = SwapIssued(manaSlot, dest)
				if issued then
					-- Checked 1.5s later (CheckPulls); a reverted pull backs off 30s.
					WatchPull("mana", manaItem, dest)
				end
			end
			-- moved= shows what sits in the main slot right after the order; issued=false means the
			-- swap wrapper held it (pair gap or fight), which game 037 printed as a repeat every 4s.
			local moved = dest ~= nil and bot:GetItemInSlot(dest) or nil
			pcall(
				print,
				string.format(
					"[OHA-MANA] t=%.0f %s backpack %s slot%d->%s out=%s moved=%s issued=%s mp=%.2f",
					now,
					(string.gsub(botName, "npc_dota_hero_", "")),
					(string.gsub(manaName, "item_", "")),
					manaSlot,
					dest ~= nil and tostring(dest) or "none",
					out ~= nil and not out:IsNull() and (string.gsub(out:GetName(), "item_", "")) or "-",
					moved ~= nil and not moved:IsNull() and (string.gsub(moved:GetName(), "item_", "")) or "-",
					tostring(issued),
					Fu.GetMP(bot)
				)
			)
		end
	end
	-- A lotus in the backpack is never cast. Hand it to a support, swap it out and use it, or drop it.
	if now > (bot._lastBackpackLotus or -100) + 3.0 then
		local lotusName, lotusSlot, lotusItem = BackpackLotus()
		-- A pull that reverted (CheckPulls) waits 30s; Lion re-pulled a lotus every 12s in game 037.
		if lotusItem ~= nil and not PullBackedOff(lotusName) then
			bot._lastBackpackLotus = now
			local hp = Fu.GetHP(bot)
			local mp = Fu.GetMP(bot)
			local ally = nil
			if hp >= 0.6 and mp >= 0.4 then
				ally = NearbySupportForLotus(lotusName == "item_greater_famango")
			end
			if ally ~= nil then
				MatchTrace.Buy(bot, lotusName, "backpack lotus to support")
				bot:Action_DropItem(lotusItem, ally:GetLocation())
				return
			end
			local dest = Item.GetMainInvLessValItemSlot(bot)
			if dest ~= nil and dest >= 0 then
				bot:ActionImmediate_SwapItems(lotusSlot, dest)
				if SwapIssued(lotusSlot, dest) then
					WatchPull("lotus", lotusItem, dest)
				end
				local moved = bot:GetItemInSlot(dest)
				if moved ~= nil and not moved:IsNull() and moved:GetName() == lotusName then
					MatchTrace.Buy(bot, lotusName, "backpack lotus swap and use")
					bot:Action_UseAbilityOnEntity(moved, bot)
				end
				return
			end
			MatchTrace.Buy(bot, lotusName, "backpack lotus drop")
			bot:Action_DropItem(lotusItem, bot:GetLocation())
			return
		end
	end
	if Fu.GetPosition(bot) <= 3 and now > (bot._lastLotusHandoff or -100) + 4.0 then
		local hp = Fu.GetHP(bot)
		local mp = Fu.GetMP(bot)
		if hp >= 0.78 and mp >= 0.6 then
			local lotusName, _, lotusItem = Item.FindLotusToFreeSlot(bot)
			if lotusItem ~= nil then
				local ally = NearbySupportForLotus(lotusName == "item_greater_famango")
				if ally ~= nil then
					bot._lastLotusHandoff = now
					MatchTrace.Buy(bot, lotusName, "core handoff lotus to support")
					bot:Action_DropItem(lotusItem, ally:GetLocation())
					return
				end
			end
		end
	elseif Fu.GetPosition(bot) >= 4 then
		-- Supports pick up healing lotuses cores dropped for them (or own stack merge).
		if Item.GetEmptyNonBackpackInventoryAmount(bot) >= 1 or Item.CanStackGreaterFamango(bot) then
			for _, drop in pairs(GetDroppedItemList() or {}) do
				if drop ~= nil and drop.item ~= nil then
					local dropName = drop.item:GetName()
					if
						dropName == "item_famango"
						or dropName == "item_great_famango"
						or dropName == "item_greater_famango"
					then
						local dropDist = GetUnitToLocationDistance(bot, drop.location)
						if dropDist <= 1000 then
							if dropDist > 120 then
								bot:Action_MoveToLocation(drop.location)
							else
								bot:Action_PickUpItem(drop.item)
							end
							return
						end
					end
				end
			end
		end
	end
	-- Late game: main bag full.
	-- 0) Stack greater famango (max 3) when two piles exist — frees a slot.
	-- 1) Else drop to support if HP/MP full, or consume.
	if now >= lateLotus and now > (bot._lastLotusFreeSlot or -100) + 3.0 then
		if Item.GetEmptyNonBackpackInventoryAmount(bot) <= 0 then
			if Item.TryStackGreaterFamango(bot) then
				bot._lastLotusFreeSlot = now
				MatchTrace.Buy(bot, "item_greater_famango", "late full-bag stack merge")
				return
			end
			local lotusName, lotusSlot, lotusItem = Item.FindLotusToFreeSlot(bot)
			if lotusItem ~= nil then
				local hp = Fu.GetHP(bot)
				local mp = Fu.GetMP(bot)
				local ally = NearbySupportForLotus(lotusName == "item_greater_famango")
				if hp >= 0.9 and mp >= 0.85 and ally ~= nil then
					bot._lastLotusFreeSlot = now
					MatchTrace.Buy(bot, lotusName, "late full-bag drop to support")
					bot:Action_DropItem(lotusItem, ally:GetLocation())
					return
				end
				-- Consume (even near full) — cannot sell; opens a slot for the next buy.
				if lotusSlot > 5 then
					for slot = 0, 5 do
						if bot:GetItemInSlot(slot) == nil then
							bot:ActionImmediate_SwapItems(lotusSlot, slot)
							lotusSlot = slot
							lotusItem = bot:GetItemInSlot(slot)
							break
						end
					end
				end
				if lotusItem ~= nil and lotusSlot >= 0 and lotusSlot <= 5 then
					bot._lastLotusFreeSlot = now
					MatchTrace.Buy(bot, lotusName, "late full-bag consume")
					bot:Action_UseAbilityOnEntity(lotusItem, bot)
					return
				end
			end
		end
	end
	if #bot.purchaseListInReverseOrder == 0 then
		ResetBuyState()
		bot:SetNextItemPurchaseValue(0)
		if now < 20 and fountainDistance <= 1000 and (stashValue or 0) == 0 then
			bot._openingShopDone = true
		end
		return
	end
	local earlyBootsSet = {
		item_boots = true,
		item_phase_boots = true,
		item_power_treads = true,
		item_tranquil_boots = true,
		item_arcane_boots = true,
	}
	local function OwnsOtherBoots(item)
		for _, boot in pairs(Item["tEarlyBoots"]) do
			if boot ~= item and bot:FindItemSlot(boot) >= 0 then
				return boot
			end
		end
		return nil
	end
	if bot.currBuyingItemInPurchaseList == nil and #bot.currBuyingBasicItemList == 0 then
		while #bot.purchaseListInReverseOrder > 0 do
			local nextItem = bot.purchaseListInReverseOrder[#bot.purchaseListInReverseOrder]
			local otherBoots = earlyBootsSet[nextItem] and OwnsOtherBoots(nextItem) or nil
			-- Aura boots stay: a bot with Guardian Greaves or Boots of Bearing does not also buy Boots of
			-- Travel (one pair of boots, user rule). Neither the sell-the-old-pair rule above nor the
			-- travel-boots sell marks cover the aura boots, so 5 builds carried both.
			local auraBoots = (nextItem == "item_travel_boots" or nextItem == "item_travel_boots_2")
				and (bot:FindItemSlot("item_guardian_greaves") >= 0 or bot:FindItemSlot("item_boots_of_bearing") >= 0)
			if auraBoots then
				log("[Purchase] Skipping %s — aura boots already owned", nextItem)
				bot.purchaseListInReverseOrder[#bot.purchaseListInReverseOrder] = nil
			elseif otherBoots ~= nil then
				-- A second pair never combines with the first. Sell the old one and buy this.
				local slot = bot:FindItemSlot(otherBoots)
				if slot >= 0 and slot <= 8 then
					log("[Purchase] Selling %s to buy %s", otherBoots, nextItem)
					bot:ActionImmediate_SellItem(bot:GetItemInSlot(slot))
				end
				break
			elseif TeamItems.AllyOwns(bot, nextItem) then
				-- Pipe / Crimson / Lotus / Urn / Vessel do not stack. A human or a fixed build may already have one.
				log("[Purchase] Skipping %s — an ally already has it", nextItem)
				bot.purchaseListInReverseOrder[#bot.purchaseListInReverseOrder] = nil
			else
				break
			end
		end
		if #bot.purchaseListInReverseOrder == 0 then
			ResetBuyState()
			bot:SetNextItemPurchaseValue(0)
			return
		end
		bot.currBuyingItemInPurchaseList = bot.purchaseListInReverseOrder[#bot.purchaseListInReverseOrder]
		local resume = bot._resumeBuy and bot._resumeBuy[bot.currBuyingItemInPurchaseList]
		if resume ~= nil then
			bot._resumeBuy[bot.currBuyingItemInPurchaseList] = nil
			bot.currBuyingBasicItemList = resume.list
			bot.currBuyingBasicItemRefList = resume.ref
			bot.currBuyingRequiredCounts = RequiredCounts(bot.currBuyingBasicItemList)
			bot._recipeTarget = resume.target or {}
			BuyLog("resume %s left=%d", ShortItem(bot.currBuyingItemInPurchaseList), #bot.currBuyingBasicItemList)
			NextBasicItem()
			return
		end
		local basicItems = Item.GetBasicItems({ bot.currBuyingItemInPurchaseList })
		for i = 1, math.ceil(#basicItems / 2) do
			bot.currBuyingBasicItemList[i] = basicItems[#basicItems - i + 1]
			bot.currBuyingBasicItemList[#basicItems - i + 1] = basicItems[i]
		end
		bot.currBuyingBasicItemRefList = Utils.Deepcopy(bot.currBuyingBasicItemList)
		bot.currBuyingRequiredCounts = RequiredCounts(bot.currBuyingBasicItemList)
		-- How many of each recipe item this build should end with: owned now plus the recipes in it.
		bot._recipeTarget = {}
		for _, part in ipairs(bot.currBuyingBasicItemRefList) do
			if string.find(part, "item_recipe_", 1, true) then
				local parent = string.gsub(part, "^item_recipe_", "item_")
				bot._recipeTarget[parent] = (bot._recipeTarget[parent] or CountItem(bot, parent)) + 1
			end
		end
		NextBasicItem()
	end
	if #bot.currBuyingBasicItemList == 0 then
		if
			Item.IsItemInHero(bot.currBuyingItemInPurchaseList)
			or bot.currBuyingItemInPurchaseList == "item_aghanims_shard"
			or bot == Utils.GetLoneDruid(bot).hero and Utils.GetLoneDruid(bot).bear ~= nil and Item.GetItemTotalWorthInSlots(
				Utils.GetLoneDruid(bot).bear
			) < 28000 and Item.IsItemInTargetHero(bot.currBuyingItemInPurchaseList, Utils.GetLoneDruid(bot).bear)
			or bot.countInvCheck > (GetGameMode() == GAMEMODE_ARDM and 30 or 30)
			or bot.rebuildCount >= 5 and courierValue == 0 and stashValue == 0
		then
			if bot.countInvCheck > 0 or bot.rebuildCount >= 5 then
				log(
					"[Purchase] %s skipping stuck item %s (rebuilds=%d invCheck=%d)",
					botName,
					tostring(bot.currBuyingItemInPurchaseList),
					bot.rebuildCount,
					bot.countInvCheck
				)
			end
			bot.countInvCheck = 0
			ResetBuyState()
			bot.purchaseListInReverseOrder[#bot.purchaseListInReverseOrder] = nil
		elseif now > bot.lastInvCheck + 1.0 then
			bot.lastInvCheck = now
			if courierValue > 0 or stashValue > 0 then
				bot.countInvCheck = 0
			elseif bot.rebuildCount < 5 and botName ~= "npc_dota_hero_lone_druid" then
				bot.rebuildCount = bot.rebuildCount + 1
				for slot = 0, 14 do
					local item = bot:GetItemInSlot(slot)
					if item then
						local itemName = item:GetName()
						if string.find(itemName, "recipe") then
							local parentName = string.gsub(itemName, "item_recipe_", "item_")
							local components = Item[parentName] or Item.GetComponentList(parentName)
							if components and #components > 0 then
								-- Each part as many times as the item needs it, less what is held (a held recipe for a
								-- Magic Wand with one Branch is still one Branch short).
								for component, needed in pairs(CountList(components)) do
									if not string.find(component, "recipe") then
										for _ = CountItem(bot, component) + 1, needed do
											-- A built part (Urn for Spirit Vessel) is bought as its basic parts (#15).
											local parts = Item.PartsToBuy(component)
											if #parts ~= 1 or parts[1] ~= component then
												local short = {}
												for i, part in ipairs(parts) do
													short[i] = ShortItem(part)
												end
												BuyLog(
													"rebuild-parts %s parts=%s for=%s",
													ShortItem(component),
													table.concat(short, ","),
													ShortItem(bot.currBuyingItemInPurchaseList)
												)
											end
											for _, part in ipairs(parts) do
												table.insert(bot.currBuyingBasicItemList, 1, part)
											end
										end
									end
								end
								if #bot.currBuyingBasicItemList > 0 then
									bot.currBuyingRequiredCounts = RequiredCounts(bot.currBuyingBasicItemList)
									break
								end
							end
						end
					end
				end
				-- Then what the whole item still needs, less what the step above queued (#15, game 065, 40:45: the old
				-- step appended the ref list less held items, so Dark Willow's four Urn parts were queued twice,
				-- left=7). GetBasicItems counts held copies (a held Urn is not broken into parts again, a held
				-- Branch covers one of two).
				local okW, wanted = pcall(Item.GetBasicItems, { bot.currBuyingItemInPurchaseList })
				local added = BuyRules.BeyondQueued(bot.currBuyingBasicItemList, okW and wanted or {})
				for _, part in ipairs(added) do
					table.insert(bot.currBuyingBasicItemList, 1, part)
				end
				local queuedShort, inv = {}, {}
				for i, part in ipairs(bot.currBuyingBasicItemList) do
					queuedShort[i] = ShortItem(part)
				end
				for slot = 0, 14 do
					local held = bot:GetItemInSlot(slot)
					if held ~= nil then
						inv[#inv + 1] = ShortItem(held:GetName())
					end
				end
				-- At most 5 rebuilds per item, so no throttle. inv= shows what the hero held (slots 0-14).
				BuyLog(
					"rebuild for=%s n=%d added=%d queued=%s inv=%s",
					ShortItem(bot.currBuyingItemInPurchaseList),
					bot.rebuildCount,
					#added,
					#queuedShort > 0 and table.concat(queuedShort, ",") or "-",
					#inv > 0 and table.concat(inv, ",") or "-"
				)
				bot.currBuyingRequiredCounts = RequiredCounts(bot.currBuyingBasicItemList)
				NextBasicItem()
			else
				bot.countInvCheck = bot.countInvCheck + 1
			end
		end
	elseif #bot.currBuyingBasicItemList > 0 then
		if bot.currBuyingBasicItem == nil then
			bot.currBuyingBasicItem = NextBasicItem()
		else
			local function buyOpening()
				if GetGameMode() == 23 then
					BuyBasicItemTurbo()
				else
					BuyBasicItem()
				end
			end
			-- One think at the fountain buys the whole starting kit, before rune mode walks out.
			if fountainDistance <= 1000 and now < 20 then
				for _ = 1, 8 do
					if #bot.currBuyingBasicItemList == 0 then
						break
					end
					local gold = bot:GetGold()
					buyOpening()
					if bot:GetGold() >= gold then
						break
					end
				end
			else
				buyOpening()
			end
		end
		if now < 20 and fountainDistance <= 1000 and (stashValue or 0) == 0 then
			local waiting = #bot.currBuyingBasicItemList > 0
			local cost = 0
			if waiting and bot.currBuyingBasicItem ~= nil then
				cost = GetItemCost(bot.currBuyingBasicItem) or 0
			end
			if not waiting or bot:GetGold() < cost or Item.GetEmptyInventoryAmount(bot) < 1 then
				bot._openingShopDone = true
			end
		end
	end
end
-- Sell marks: the game's "mark for sale" has no bot API (only ActionImmediate_SellItem, at a
-- shop), so the bot keeps its own list. An item is marked once it is no use any more, and sold at
-- the first shop visit (fountain, secret shop or side shop), with free slots or not. The old rule
-- only sold with the backpack nearly full and within 100 of the fountain or at the secret shop,
-- so Invoker carried Power Treads and Magic Wand next to Boots of Travel for a long time.
-- Marked:
-- - the second item of each sell pair (hero and shared sell lists) once the first is owned,
-- - early boots once Boots of Travel is owned,
-- - a standalone early item that nothing left in the build is made from (Helm of Iron Will:
--   game 016, Doom still carried it at 53:00 because his team item was not Crimson Guard).
-- Item -> earliest game time it may be sold once nothing left in the build uses it. Circlet: a
-- starting stat item in many builds that is never turned into a Wraith Band / Null Talisman / Bracer
-- (game 033, 20:00: Death Prophet still carried hers; 20 build lists across 17 heroes do this).
local UNUSED_SELL = { item_helm_of_iron_will = 0, item_circlet = 15 * 60 }
-- partsOf for BuyRules.IsPartOf: an item's direct parts from the Item tables, nil for a basic item.
local function DirectParts(name)
	local parts = Item[name]
	return type(parts) == "table" and parts or nil
end
function NeededLater(name)
	local list = {}
	for _, it in ipairs(bot.purchaseListInReverseOrder or {}) do
		list[#list + 1] = it
	end
	if bot.currBuyingItemInPurchaseList ~= nil then
		list[#list + 1] = bot.currBuyingItemInPurchaseList
	end
	for _, it in ipairs(list) do
		-- Owned items must still count as parts: GetBasicItems leaves out what the hero holds, so a
		-- held Helm of Iron Will was not seen as a Crimson Guard part, marked unused and sold, then
		-- bought again (game 017: Magnus bought it 21 times from 26:12 to 40:24). The walk goes through
		-- the item tables with nothing taken off, built parts included: the Urn of Shadows inside an
		-- Essence Distiller counts, not only its Circlet (#15, game 065).
		if BuyRules.IsPartOf(it, name, DirectParts) then
			return true
		end
	end
	-- Parts still to buy for the item being built right now.
	for _, part in ipairs(bot.currBuyingBasicItemList or {}) do
		if part == name then
			return true
		end
	end
	for _, part in ipairs(bot.currBuyingBasicItemRefList or {}) do
		if part == name then
			return true
		end
	end
	return false
end
local function MarkedForSale()
	local marks = {}
	local function pairs2(list)
		if type(list) ~= "table" then
			return
		end
		for i = 2, #list, 2 do
			-- Not while the build still uses it: the Wizard Hat / Circlet pair sold the Circlets Dark Willow bought
			-- for the Urn of her Essence Distiller (#15, game 065, 42:36).
			if
				bot:FindItemSlot(list[i - 1]) >= 0
				and bot:FindItemSlot(list[i]) >= 0
				and not KeepForBuild(list[i], "pair:" .. ShortItem(list[i - 1]))
			then
				marks[list[i]] = "pair:" .. list[i - 1]
			end
		end
	end
	pairs2(Item.sSellList)
	pairs2(sellList)
	if Item.HasItem(bot, "item_travel_boots") or Item.HasItem(bot, "item_travel_boots_2") then
		for _, boots in ipairs(Item["tEarlyBoots"] or {}) do
			marks[boots] = "travel-boots"
		end
	end
	for name, after in pairs(UNUSED_SELL) do
		if DotaTime() >= (tonumber(after) or 0) and bot:FindItemSlot(name) >= 0 and not NeededLater(name) then
			marks[name] = "unused"
		end
	end
	-- A second pair of plain Boots that nothing left in the build uses (#15, game 063: Shadow Fiend held two).
	if marks.item_boots == nil then
		local held = CountItem(bot, "item_boots")
		if held >= 2 then
			local plan = {}
			for _, it in ipairs(bot.purchaseListInReverseOrder or {}) do
				plan[#plan + 1] = it
			end
			if bot.currBuyingItemInPurchaseList ~= nil then
				plan[#plan + 1] = bot.currBuyingItemInPurchaseList
			end
			local none = setmetatable({}, {
				__index = function()
					return 0
				end,
			})
			local extra, needed = BuyRules.ExtraBoots(held, plan, function(name)
				local ok, parts = pcall(Item.GetBasicItems, { name }, none)
				return ok and parts or nil
			end)
			if extra > 0 then
				marks.item_boots = "extra"
				if DotaTime() >= (bot._extraBootsLogAt or -999) then
					bot._extraBootsLogAt = DotaTime() + 30
					BuyLog("sell-extra boots held=%d needed=%d", held, needed)
				end
			end
		end
	end
	return marks
end
function SellMarkedItems()
	local now = DotaTime()
	if now < (bot._sellMarkAt or -999) + 1 then
		return
	end
	bot._sellMarkAt = now
	local fountainDist, secretShopDist, sideShopDist =
		bot:DistanceFromFountain(), bot:DistanceFromSecretShop(), bot:DistanceFromSideShop()
	-- DistanceFromSideShop() is -2147483648 on this map (no side shops; game 018 sell-failed
	-- lines), so "<= 200" passed everywhere and sells were tried far from any shop. Only a real,
	-- non-negative distance counts.
	local atShop = (fountainDist >= 0 and fountainDist <= 500)
		or (secretShopDist >= 0 and secretShopDist <= 200)
		or (sideShopDist >= 0 and sideShopDist <= 200)
	-- Something waits to be sold: the fountain TP-out rule holds while this is set (game 031,
	-- 66:48: Medusa walked home to 1942 from the fountain and teleported out at once, and kept her
	-- Power Treads next to Boots of Travel; the sale needs the fountain within 500).
	local okM, marks = pcall(MarkedForSale)
	bot._sellPending = false
	if okM and marks ~= nil then
		for name in pairs(marks) do
			if bot:FindItemSlot(name) >= 0 and now >= (bot._sellBlock ~= nil and bot._sellBlock[name] or -999) then
				bot._sellPending = true
				break
			end
		end
	end
	if not atShop then
		return
	end
	-- A sell that did not go through: game 017, the same item was ordered sold every second for up
	-- to 13 minutes (Magnus Helm of Iron Will 173 times, Medusa Power Treads 172) with no error
	-- line, far from the fountain. The item still in the bag 1s after the order counts as failed:
	-- logged once with the shop distances and where it is (sell-failed), then left alone for 30s.
	bot._sellBlock = bot._sellBlock or {}
	local last = bot._sellTry
	if last ~= nil and now - last.at >= 1 then
		bot._sellTry = nil
		local slot0 = bot:FindItemSlot(last.name)
		if slot0 >= 0 then
			bot._sellBlock[last.name] = now + 30
			local myLocation = bot:GetLocation()
			local function shopAt(kind)
				local okL, loc = pcall(GetShopLocation, GetTeam(), kind)
				if okL and loc ~= nil then
					return string.format("%.0f,%.0f", loc.x, loc.y)
				end
				return "?"
			end
			pcall(
				print,
				string.format(
					"[OHA-ITEM] t=%.0f %s sell-failed %s slot=%d at=%.0f,%.0f fountain=%d secret=%d side=%d shops secret=%s secret2=%s side=%s side2=%s",
					now,
					(string.gsub(botName, "npc_dota_hero_", "")),
					(string.gsub(last.name, "^item_", "")),
					slot0,
					myLocation.x,
					myLocation.y,
					math.floor(fountainDist),
					math.floor(secretShopDist),
					math.floor(sideShopDist),
					shopAt(SHOP_SECRET),
					shopAt(SHOP_SECRET2),
					shopAt(SHOP_SIDE),
					shopAt(SHOP_SIDE2)
				)
			)
		end
	end
	for name, why in pairs(MarkedForSale()) do
		local slot = bot:FindItemSlot(name)
		if slot >= 0 and slot <= 14 and now >= (bot._sellBlock[name] or -999) then
			local it = bot:GetItemInSlot(slot)
			if it ~= nil then
				bot._sellTry = { name = name, at = now }
				bot:ActionImmediate_SellItem(it)
				return
			end
		end
	end
end
function SetPairedItems(sellPairs)
	for i = 2, #sellPairs, 2 do
		local firstSlot = bot:FindItemSlot(sellPairs[i - 1])
		local secondSlot = bot:FindItemSlot(sellPairs[i])
		if
			firstSlot >= 0
			and secondSlot >= 0
			and not KeepForBuild(sellPairs[i], "pair:" .. ShortItem(sellPairs[i - 1]))
		then
			bot:ActionImmediate_SellItem(bot:GetItemInSlot(secondSlot))
		end
	end
end
function IsThereHealingInStash(unit)
	local healingCount = 0
	for slot = 9, 14 do
		local item = unit:GetItemInSlot(slot)
		if item ~= nil then
			if
				string.find(item:GetName(), "item_flask")
				or string.find(item:GetName(), "item_tango")
				or string.find(item:GetName(), "item_bottle")
			then
				healingCount = healingCount + 1
			end
		end
	end
	return healingCount > 0
end
-- Engine entry points report their own errors. Unwrapped, an error here showed only as
-- "Script Runtime Error: error in error handling" (every bot at -89s), with no message.
-- Up to 3 per function per bot, as [OHA-ERROR].
local OHA_ERR_COUNT = {}
local function OHA_Guard(name, fn)
	if type(fn) ~= "function" then
		return fn
	end
	return function(...)
		local ok, err = pcall(fn, ...)
		if not ok then
			local errorCount = (OHA_ERR_COUNT[name] or 0) + 1
			OHA_ERR_COUNT[name] = errorCount
			if errorCount <= 3 then
				local hero = "?"
				pcall(function()
					hero = GetBot():GetUnitName()
				end)
				pcall(print, string.format("[OHA-ERROR] t=%.1f %s %s: %s", DotaTime(), hero, name, tostring(err)))
			end
		end
	end
end
ItemPurchaseThink = OHA_Guard("ItemPurchaseThink", ItemPurchaseThink)
ItemPurchase.ItemPurchaseThink = ItemPurchaseThink
-- [OHA-PERF] timing (#52): FuncLib/systems/perf.lua
do
	local Perf = require(GetScriptDirectory() .. "/FuncLib/systems/perf")
	ItemPurchaseThink = Perf.Wrap("ItemPurchaseThink", ItemPurchaseThink)
end
return ItemPurchase
