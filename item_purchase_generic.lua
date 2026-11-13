-- Buys and sells items from the hero build.
local a = GetBot()
local b = a:GetUnitName()
if
	a == nil
	or a:IsInvulnerable()
	or not a:IsHero()
	or not a:IsAlive()
	or not string.find(b, "hero")
	or a:IsIllusion()
then
	return
end
if GAMEMODE_ARDM == nil then
	GAMEMODE_ARDM = 20
end
local c = require(GetScriptDirectory() .. "/FuncLib/systems/item")
local d = require(GetScriptDirectory() .. "/FuncLib/systems/role")
local e = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local f = require(GetScriptDirectory() .. "/FuncLib/systems/utils")
local MatchTrace = require(GetScriptDirectory() .. "/FuncLib/systems/match_trace")
local TeamItems = require(GetScriptDirectory() .. "/FuncLib/systems/item_strategy")
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
local g = {}
if a:IsInvulnerable() or not a:IsHero() or a:IsIllusion() then
	return
end
local h = require(GetScriptDirectory() .. "/BotsLib/" .. string.gsub(b, "npc_dota_", ""))
if h == nil then
	return
end
a.purchaseListInReverseOrder = {}
a.currBuyingItemInPurchaseList = nil
a.currBuyingBasicItem = nil
a.currBuyingBasicItemList = {}
a.currBuyingBasicItemRefList = {}
a.currBuyingRequiredCounts = nil
a._lastPurchaseAttempt = { name = nil, t = -999 }
a.rebuildCount = 0
a.SecretShop = false
local i = h["sBuyList"]
local j = h["sSellList"]
if i == nil then
	log("[ERROR] Can't load purchase list for: %s", b)
	log("Stack Trace:", debug.traceback())
	return
end
log("[Purchase] %s loaded %d items: %s -> %s", b, #i, i[1] or "nil", i[#i] or "nil")
for k = 1, #i do
	a.purchaseListInReverseOrder[k] = i[#i - k + 1]
end
a.sell_time = -90
local l = -90
a.countInvCheck = 0
a.lastItemToBuy = nil
a.bPurchaseFromSecret = false
a.hasBuyShard = true
local m = 0
local n = nil
local o = false
local p = -90
a.lastInvCheck = -90
a.fullInvCheck = -90
a.switchTime = 0
a.hasBuyClarity = false
local q = -90
local r = false
local s = false
local t = -999
local u = 0
local v = false
local w, x, y, z, A, B, C, D, E
local function F(G, H)
	local I = 0
	for J = 0, 14 do
		local K = G:GetItemInSlot(J)
		if K ~= nil and K:GetName() == H then
			I = I + 1
		end
	end
	return I
end
local function L(M)
	local N = {}
	for O, P in ipairs(M) do
		N[P] = (N[P] or 0) + 1
	end
	return N
end
local Q = {
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
local function R(H)
	if H == "item_boots" then
		local S = a.currBuyingItemInPurchaseList
		local T = {
			item_power_treads = true,
			item_phase_boots = true,
			item_arcane_boots = true,
			item_tranquil_boots = true,
			item_travel_boots = true,
			item_travel_boots_2 = true,
			item_guardian_greaves = true,
			item_boots_of_bearing = true,
		}
		if c.HasBootsInMainSolt(a) and not T[S] then
			return false
		end
	end
	if GetGameMode() == GAMEMODE_ARDM and DotaTime() > 2 * 60 and Q[H] then
		return false
	end
	if not a.currBuyingRequiredCounts then
		return true
	end
	local U = a.currBuyingRequiredCounts[H]
	if not U then
		return true
	end
	local V = F(a, H)
	return V < U
end
local function W()
	while #a.currBuyingBasicItemList > 0 do
		local X = a.currBuyingBasicItemList[#a.currBuyingBasicItemList]
		if R(X) then
			return X
		else
			a.currBuyingBasicItemList[#a.currBuyingBasicItemList] = nil
		end
	end
	return nil
end
local function Y(X)
	local Z = DotaTime()
	if a._lastPurchaseAttempt.name == X and Z - a._lastPurchaseAttempt.t < 0.4 then
		return true
	end
	a._lastPurchaseAttempt.name, a._lastPurchaseAttempt.t = X, Z
	return false
end
local function _()
	local a0 = c.GetItemCharges(a, "item_tpscroll")
	return a0 >= 2 or a0 >= 1 and c.HasItem(a, "item_travel_boots") or a0 >= 1 and c.HasItem(a, "item_travel_boots_2")
end
local function a1()
	a.countInvCheck = 0
	a.currBuyingBasicItem = nil
	a.currBuyingBasicItemList[#a.currBuyingBasicItemList] = nil
end
local function a2()
	a.countInvCheck = 0
	a.currBuyingItemInPurchaseList = nil
	a.currBuyingBasicItem = nil
	a.currBuyingBasicItemList = {}
	a.currBuyingBasicItemRefList = {}
	a.currBuyingRequiredCounts = nil
	a._recipeTarget = nil
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
	if OwnedAnywhere(a, itemName) then
		return true
	end
	if a.currBuyingItemInPurchaseList == itemName then
		return true
	end
	return false
end
local function QueueReactiveItem(itemName)
	if tReactiveQueued[itemName] or ReactiveOwnedOrBuilding(itemName) then
		return false
	end
	tReactiveQueued[itemName] = true
	if not QueueFront(a.purchaseListInReverseOrder, itemName) then
		return false
	end
	a2()
	a.rebuildCount = 0
	log("[Item] %s queued counter %s (pos %s)", b, itemName, tostring(e.GetPosition(a)))
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
			if sHero ~= nil and e.tRightclickMenace[sHero] then
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
				local nAllyPos = e.GetPosition(ally)
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
	local nPos = e.GetPosition(a)
	local bStr = a:GetPrimaryAttribute() == ATTRIBUTE_STRENGTH
	if nPos <= 3 then
		local bAssigned = IsLockdownBuyer(nPos, tLockdownBotPositions, 2)
		local bFallback = nTeamLock == 0 and DotaTime() > nStart + 10 * 60
		local sLockItem = LockdownItemFor(bStr)
		local bOwnLock = false
		for _, sLock in ipairs(tLock) do
			if OwnedAnywhere(a, sLock) then
				bOwnLock = true
			end
		end
		if (bAssigned or bFallback) and not bOwnLock and nTeamLock < 2 then
			if QueueReactiveItem(sLockItem) then
				return
			end
		end
		if
			bAssigned
			and bOwnLock
			and not bTeamHex
			and not bStr
			and DotaTime() > 25 * 60
		then
			local nHexPos = nil
			for _, p in ipairs({ 2, 3, 1 }) do
				if IsLockdownBuyer(p, tLockdownBotPositions, 2) and tLockdownStrByPos[p] == false then
					nHexPos = p
					break
				end
			end
			if nHexPos == nPos then
				if QueueReactiveItem("item_sheepstick") then
					return
				end
			end
		end
	elseif not OwnedAnywhere(a, "item_ethereal_blade") then
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
	a._swapDespiteEnemies = true
	a:ActionImmediate_SwapItems(fromSlot, toSlot)
	a._swapDespiteEnemies = nil
end
local function MainSlotForBackpackItem()
	for slot = 0, 5 do
		if a:GetItemInSlot(slot) == nil then
			return slot
		end
	end
	for slot = 0, 5 do
		local it = a:GetItemInSlot(slot)
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
		VerifyLastSwap(a)
	end
	local grenadeSlot = a:FindItemSlot("item_blood_grenade")
	-- Log every slot change of the grenade with the main inventory and the mode. A move into
	-- the backpack that no logged swap made was something outside the swap wrapper.
	if grenadeSlot ~= (a._grenadeLastSlot or -1) then
		if grenadeSlot >= 0 or (a._grenadeLastSlot or -1) >= 0 then
			local main = {}
			for s = 0, 5 do
				local it = a:GetItemInSlot(s)
				main[#main + 1] = it ~= nil and (string.gsub(it:GetName(), "^item_", "")) or "-"
			end
			local pack = {}
			for s = 6, 8 do
				local it = a:GetItemInSlot(s)
				pack[#pack + 1] = it ~= nil and (string.gsub(it:GetName(), "^item_", "")) or "-"
			end
			pcall(print, string.format(
				"[OHA-ITEM] t=%.0f %s grenade-moved from=%d to=%d mode=%s main=%s pack=%s",
				DotaTime(),
				(string.gsub(b, "npc_dota_hero_", "")),
				a._grenadeLastSlot or -1,
				grenadeSlot,
				tostring(a:GetActiveMode()),
				table.concat(main, ","),
				table.concat(pack, ",")
			))
		end
		a._grenadeLastSlot = grenadeSlot
	end
	-- Bot item swaps do not take effect in this game build (every checked swap was a no-op), so
	-- there is nothing to do while the grenade is merely in the backpack. The game moves it
	-- back up as soon as a main slot frees. From 12:00 a grenade still carried is dead weight:
	-- sell it at base or drop it elsewhere, away from enemy heroes.
	if grenadeSlot < 0 or grenadeSlot > 8 or DotaTime() < 12 * 60 then
		return
	end
	if #(a:GetNearbyHeroes(1200, true, BOT_MODE_NONE) or {}) > 0 then
		return
	end
	local grenade = a:GetItemInSlot(grenadeSlot)
	if grenade == nil then
		return
	end
	-- A dropped item can be picked straight back up by the engine (seen with a Clarity).
	-- Drop it once; if it comes back, only sell it at base from then on.
	if a._grenadeDroppedAt ~= nil and DotaTime() - a._grenadeDroppedAt < 3 then
		return
	end
	if a._grenadeDroppedAt ~= nil and not a._grenadeRepickLogged then
		a._grenadeRepickLogged = true
		pcall(print, string.format(
			"[OHA-ITEM] t=%.0f %s grenade-repicked after=%.0fs",
			DotaTime(),
			(string.gsub(b, "npc_dota_hero_", "")),
			DotaTime() - a._grenadeDroppedAt
		))
	end
	local how
	if a:DistanceFromFountain() <= 1600 then
		a:ActionImmediate_SellItem(grenade)
		how = "sold"
	elseif a._grenadeDroppedAt == nil then
		a:Action_DropItem(grenade, a:GetLocation())
		a._grenadeDroppedAt = DotaTime()
		how = "dropped"
	else
		return
	end
	if DotaTime() >= (a._grenadeDisposeLogAt or -999) then
		a._grenadeDisposeLogAt = DotaTime() + 10
		pcall(print, string.format(
			"[OHA-ITEM] t=%.0f %s grenade-%s slot=%d",
			DotaTime(),
			(string.gsub(b, "npc_dota_hero_", "")),
			how,
			grenadeSlot
		))
	end
end
local function PromoteBackpackCounters()
	if DotaTime() < promoteNextCheck then
		return
	end
	promoteNextCheck = DotaTime() + 2
	for nBpSlot = 6, 8 do
		local hBpItem = a:GetItemInSlot(nBpSlot)
		if hBpItem ~= nil and tPromoteFromBackpack[hBpItem:GetName()] then
			local nBpCost = GetItemCost(hBpItem:GetName())
			local nBestSlot, nBestCost = -1, nBpCost
			for nSlot = 0, 5 do
				local hItem = a:GetItemInSlot(nSlot)
				if hItem == nil then
					nBestSlot, nBestCost = nSlot, -1
					break
				end
				local sName = hItem:GetName()
				local nCost = GetItemCost(sName)
				if
					nCost < nBestCost
					and not tPromoteFromBackpack[sName]
					and not c.IsCanNotSwitchItem(sName)
					and not string.find(sName, "boots")
					and sName ~= "item_power_treads"
					and sName ~= "item_guardian_greaves"
				then
					nBestSlot, nBestCost = nSlot, nCost
				end
			end
			if nBestSlot ~= -1 then
				log("[Item] %s backpack -> main: %s", b, hBpItem:GetName())
				a:ActionImmediate_SwapItems(nBpSlot, nBestSlot)
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
	pcall(print, string.format(
		"[OHA-BUY] t=%.0f %s " .. fmt,
		DotaTime(),
		(string.gsub(b, "npc_dota_hero_", "")),
		...
	))
end
local function IsBasicItem(name)
	if type(c[name]) == "table" then
		return false
	end
	local ok, parts = pcall(GetItemComponents, name)
	return not ok or type(parts) ~= "table" or #parts == 0
end
-- An ingredient of this recipe's item that the hero does not own yet, or nil.
local function MissingIngredient(recipe)
	local parent = string.gsub(recipe, "^item_recipe_", "item_")
	local parts = c[parent]
	if type(parts) ~= "table" then
		local ok, list = pcall(c.GetComponentList, parent)
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
		if F(a, part) < count then
			return part
		end
	end
	return nil
end
-- true/false when the courier's slots can be read, nil when there is no courier handle.
local function CourierHasItem(name)
	local courier = a.theCourier
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
	local function walk(n, depth)
		local list = c[n]
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
	local item = a.currBuyingBasicItem
	if type(item) ~= "string" or not string.find(item, "item_recipe_", 1, true) then
		return false
	end
	-- A recipe whose item the hero already has as many of as this build wants is a
	-- leftover from a rebuild. Buying its ingredients would make an extra item.
	local parent = string.gsub(item, "^item_recipe_", "item_")
	local wanted = a._recipeTarget and a._recipeTarget[parent]
	if wanted ~= nil and F(a, parent) >= wanted then
		BuyLog(
			"recipe-stray %s owned=%d wanted=%d for=%s",
			ShortItem(item),
			F(a, parent),
			wanted,
			ShortItem(a.currBuyingItemInPurchaseList)
		)
		a1()
		return true
	end
	a._recipeHold = a._recipeHold or {}
	local missing = MissingIngredient(item)
	if missing == nil then
		a._recipeHold[item] = nil
		return false
	end
	local parts = IngredientParts(missing)
	local isPart = {}
	for _, p in ipairs(parts) do
		isPart[p] = true
	end
	local list = a.currBuyingBasicItemList
	-- Nearest upcoming entry for this ingredient or one of its parts. Buy order runs from
	-- the end of the list, so the highest index below the recipe is the next one bought.
	local queuedAt = nil
	for k = #list - 1, 1, -1 do
		if isPart[list[k]] then
			queuedAt = k
			break
		end
	end
	-- Only act on an ingredient this build planned to buy. An upgrade recipe can name an
	-- item whose parts the hero no longer holds (boots inside Travel Boots); leave those alone.
	local planned = false
	for _, entry in ipairs(a.currBuyingBasicItemRefList or {}) do
		if isPart[entry] then
			planned = true
			break
		end
	end
	if queuedAt == nil and not planned then
		a._recipeHold[item] = nil
		return false
	end
	local now = DotaTime()
	local hold = a._recipeHold[item]
	if hold == nil then
		hold = { since = now, requeues = 0 }
		a._recipeHold[item] = hold
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
				ShortItem(a.currBuyingItemInPurchaseList)
			)
		end
		return false
	end
	-- Courier first. An ingredient already bought and on its way must not be matched to a
	-- later copy in the queue (a Sobi Mask meant for Urn pushed the Ring of Basilius recipe
	-- to the end of the build, and Arcane Boots never combined).
	local onCourier = nil
	for _, p in ipairs(parts) do
		local found = CourierHasItem(p)
		if found == true then
			onCourier = true
			break
		elseif found == false then
			onCourier = false
		end
	end
	if onCourier == nil then
		onCourier = (a:GetCourierValue() or 0) > 0
	end
	local action
	if onCourier then
		action = "wait-courier"
	elseif queuedAt ~= nil then
		-- Sit right behind that part instead of at the very end of the build.
		list[#list] = nil
		table.insert(list, queuedAt, item)
		action = "defer"
		hold.since = now
	else
		-- Planned but fell out of the queue: put back the basic parts the hero lacks.
		local need = {}
		if IsBasicItem(missing) then
			need[missing] = 1
		else
			for _, p in ipairs(parts) do
				if p ~= missing and IsBasicItem(p) then
					need[p] = (need[p] or 0) + 1
				end
			end
		end
		local added = 0
		for p, count in pairs(need) do
			for _ = 1, count - F(a, p) do
				list[#list + 1] = p
				added = added + 1
			end
		end
		if added == 0 then
			a._recipeHold[item] = nil
			return false
		end
		hold.requeues = hold.requeues + 1
		action = "queue"
		if hold.requeues <= MAX_REQUEUES then
			hold.since = now
		end
	end
	a.currBuyingBasicItem = nil
	if a._recipeHoldLogAt == nil or now >= a._recipeHoldLogAt then
		a._recipeHoldLogAt = now + 3
		BuyLog(
			"recipe-hold %s missing=%s action=%s requeues=%d for=%s gold=%d",
			ShortItem(item),
			ShortItem(missing),
			action,
			hold.requeues,
			ShortItem(a.currBuyingItemInPurchaseList),
			a:GetGold()
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
local function a3()
	if a.lastItemToBuy ~= a.currBuyingBasicItem then
		a.lastItemToBuy = a.currBuyingBasicItem
		a:SetNextItemPurchaseValue(GetItemCost(a.currBuyingBasicItem))
		a.bPurchaseFromSecret = IsItemPurchasedFromSecretShop(a.currBuyingBasicItem)
		m = GetItemCost(a.currBuyingBasicItem)
	end
	if
		a.currBuyingBasicItem == "item_infused_raindrop"
		or a.currBuyingBasicItem == "item_tome_of_knowledge"
		or a.currBuyingBasicItem == "item_flask"
	then
		if GetItemStockCount(a.currBuyingBasicItem) <= 0 then
			a1()
			return
		end
	end
	local a4 = W()
	if not a4 then
		return
	end
	a.currBuyingBasicItem = a4
	if HoldRecipe() then
		return
	end
	if Y(a.currBuyingBasicItem) then
		return
	end
	-- The price set at the top of a3 belongs to the item picked last think. In the opening
	-- loop that was a 50-gold Branch, so a hero with 110 gold tried the wand recipe and failed.
	if a.lastItemToBuy ~= a.currBuyingBasicItem then
		a.lastItemToBuy = a.currBuyingBasicItem
		a:SetNextItemPurchaseValue(GetItemCost(a.currBuyingBasicItem))
		a.bPurchaseFromSecret = IsItemPurchasedFromSecretShop(a.currBuyingBasicItem)
		m = GetItemCost(a.currBuyingBasicItem)
	end
	local a5 = m
	if
		a.lastItemToBuy == "item_boots"
		and a.currBuyingItemInPurchaseList == "item_travel_boots"
		and c.HasBootsInMainSolt(a)
	then
		a5 = GetItemCost("item_travel_boots")
	end
	if a:GetLevel() >= 18 and o == false and DotaTime() > p + 1.0 then
		for k = 2, 8, 3 do
			local a6 = GetTower(GetTeam(), k)
			if a6 == nil or a6:GetHealth() / a6:GetMaxHealth() < 0.3 then
				o = true
				break
			end
		end
		for k = 1, 7, 3 do
			local a6 = GetTower(GetTeam(), k)
			if a6 ~= nil and a6:IsAlive() then
				o = false
				break
			end
		end
		for k = 9, 10, 1 do
			local a6 = GetTower(GetTeam(), k)
			if a6 == nil or a6:GetHealth() / a6:GetMaxHealth() < 0.9 then
				o = true
				break
			end
		end
		if DotaTime() >= 54 * 60 then
			o = true
		end
		p = DotaTime()
	elseif o == true and a:GetBuybackCooldown() <= 10 then
		a5 = m + a:GetBuybackCost() + a:GetNetWorth() / 40 - 300
	end
	if #a.currBuyingBasicItemList == 1 or d.IsPvNMode() then
		a5 = m
	end
	if not a.hasBuyShard and DotaTime() > 12 * 60 then
		local a7 = 15 * 60 - DotaTime()
		if a7 < 0 then
			a5 = a5 + 1400
		else
			a5 = a5 + 1400 * (1 - a7 / 300)
		end
	end
	if a.currBuyingBasicItem == "item_aghanims_shard" then
		a.hasBuyShard = false
		a1()
		return
	end
	if a:GetGold() >= a5 and a:GetItemInSlot(14) == nil then
		if DotaTime() < 20 and (a:DistanceFromFountain() > 1000 or c.GetEmptyInventoryAmount(a) < 1) and a:DistanceFromSecretShop() > 300 then
			return
		end
		if n == nil then
			n = a.theCourier
		end
		if a.SecretShop and n ~= nil and n:DistanceFromSecretShop() == 0 then
			local a8 = n:ActionImmediate_PurchaseItem(a.currBuyingBasicItem)
			if a8 == PURCHASE_ITEM_SUCCESS then
				BuyLog(
					"bought %s for=%s gold=%d left=%d courier=secret",
					ShortItem(a.currBuyingBasicItem),
					ShortItem(a.currBuyingItemInPurchaseList),
					a:GetGold(),
					math.max(0, #a.currBuyingBasicItemList - 1)
				)
				a1()
				a.SecretShop = false
				return
			elseif FailureDropsItem(a8, GetItemStockCount(a.currBuyingBasicItem)) then
				a1()
				a.SecretShop = false
				return
			end
		end
		if a.bPurchaseFromSecret and a:DistanceFromSecretShop() > 0 then
			a.SecretShop = true
		else
			if f.CountBackpackEmptySpace(a) > 0 or a:DistanceFromSecretShop() > 700 then
				local result = a:ActionImmediate_PurchaseItem(a.currBuyingBasicItem)
				if result == PURCHASE_ITEM_SUCCESS then
					BuyLog(
						"bought %s for=%s gold=%d left=%d",
						ShortItem(a.currBuyingBasicItem),
						ShortItem(a.currBuyingItemInPurchaseList),
						a:GetGold(),
						math.max(0, #a.currBuyingBasicItemList - 1)
					)
					a1()
					a.SecretShop = false
					return
				else
					local stock = GetItemStockCount(a.currBuyingBasicItem)
					if FailureDropsItem(result, stock) then
						-- The item leaves the queue here. If it was an ingredient, the recipe guard puts it back.
						BuyLog(
							"dropped %s for=%s result=%s stock=%s gold=%d",
							ShortItem(a.currBuyingBasicItem),
							ShortItem(a.currBuyingItemInPurchaseList),
							tostring(result),
							tostring(stock),
							a:GetGold()
						)
						a1()
						a.SecretShop = false
					else
						local a9 = a:ActionImmediate_PurchaseItem(a.currBuyingBasicItem)
						log("%s 未能购买物品 %s : %s", b, a.currBuyingBasicItem, a9)
					end
				end
			end
		end
	else
		a.SecretShop = false
	end
end
local function aa()
	local a4 = W()
	if not a4 then
		return
	end
	a.currBuyingBasicItem = a4
	if HoldRecipe() then
		return
	end
	if Y(a.currBuyingBasicItem) then
		return
	end
	if a.lastItemToBuy ~= a.currBuyingBasicItem then
		a.lastItemToBuy = a.currBuyingBasicItem
		a:SetNextItemPurchaseValue(GetItemCost(a.currBuyingBasicItem))
		m = GetItemCost(a.currBuyingBasicItem)
		a.lastItemToBuy = a.currBuyingBasicItem
	end
	if a.currBuyingBasicItem == "item_infused_raindrop" or a.currBuyingBasicItem == "item_tome_of_knowledge" then
		if GetItemStockCount(a.currBuyingBasicItem) <= 0 then
			a1()
			return
		end
	end
	local a5 = m
	if
		a.lastItemToBuy == "item_boots"
		and a.currBuyingItemInPurchaseList == "item_travel_boots"
		and c.HasBootsInMainSolt(a)
	then
		a5 = GetItemCost("item_travel_boots")
	end
	if not a.hasBuyShard and DotaTime() > 8 * 60 then
		local a7 = 10 * 60 - DotaTime()
		if a7 < 0 then
			a5 = a5 + 1400
		else
			a5 = a5 + 1400 * (1 - a7 / 180)
		end
	end
	if a.currBuyingBasicItem == "item_aghanims_shard" then
		a.hasBuyShard = false
		a1()
		return
	end
	if a:GetGold() >= a5 and a:GetItemInSlot(14) == nil then
		if DotaTime() < 20 and (a:DistanceFromFountain() > 1000 or c.GetEmptyInventoryAmount(a) < 1) and a:DistanceFromSecretShop() > 300 then
			return
		end
		local result = a:ActionImmediate_PurchaseItem(a.currBuyingBasicItem)
		if result == PURCHASE_ITEM_SUCCESS then
			BuyLog(
				"bought %s for=%s gold=%d left=%d",
				ShortItem(a.currBuyingBasicItem),
				ShortItem(a.currBuyingItemInPurchaseList),
				a:GetGold(),
				math.max(0, #a.currBuyingBasicItemList - 1)
			)
			a1()
			return
		else
			local stock = GetItemStockCount(a.currBuyingBasicItem)
			if FailureDropsItem(result, stock) then
				BuyLog(
					"dropped %s for=%s result=%s stock=%s gold=%d",
					ShortItem(a.currBuyingBasicItem),
					ShortItem(a.currBuyingItemInPurchaseList),
					tostring(result),
					tostring(stock),
					a:GetGold()
				)
				a1()
			else
				local a9 = a:ActionImmediate_PurchaseItem(a.currBuyingBasicItem)
				log("%s 未能购买物品 %s : %s", b, a.currBuyingBasicItem, a9)
			end
		end
	end
end
function ItemPurchaseThink()
	w = DotaTime()
	local ab, ac, ad = e.IsStaleARDMHero(a, b)
	if ab then
		return
	end
	if ad ~= b then
		if not ac:IsAlive() then
			return
		end
		log("[ARDM] Item purchase: hero changed from %s to %s", b, ad)
		a = ac
		b = ad
		local ae = string.gsub(b, "npc_dota_", "")
		local af, ag = pcall(dofile, GetScriptDirectory() .. "/BotsLib/" .. ae)
		if af and ag ~= nil and ag["sBuyList"] ~= nil then
			h = ag
			i = ag["sBuyList"]
			j = ag["sSellList"]
		else
			i = {}
			j = {}
		end
		local ah = c.HasBuyBoots(a)
			or c.HasItem(a, "item_guardian_greaves")
			or c.HasItem(a, "item_travel_boots")
			or c.HasItem(a, "item_travel_boots_2")
			or c.HasItem(a, "item_boots_of_bearing")
		local ai = {
			item_boots = true,
			item_phase_boots = true,
			item_power_treads = true,
			item_tranquil_boots = true,
			item_arcane_boots = true,
		}
		a.purchaseListInReverseOrder = {}
		local aj = 0
		for k = #i, 1, -1 do
			local H = i[k]
			local ak = false
			if c.IsItemInHero(H) then
				ak = true
			elseif GetGameMode() == GAMEMODE_ARDM and DotaTime() > 2 * 60 and Q[H] then
				ak = true
			elseif ah and ai[H] then
				ak = true
			end
			if not ak then
				aj = aj + 1
				a.purchaseListInReverseOrder[aj] = H
			end
		end
		local al = {}
		for O, H in ipairs(i) do
			al[H] = true
			if c[H] ~= nil then
				for O, am in pairs(c[H]) do
					al[am] = true
				end
			end
		end
		local an = {
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
		local ao = {}
		for J = 0, 14 do
			local ap = a:GetItemInSlot(J)
			if ap ~= nil then
				local X = ap:GetName()
				if not an[X] and not al[X] and not string.find(X, "token") then
					table.insert(ao, { slot = J, name = X, cost = GetItemCost(X) })
				end
			end
		end
		table.sort(ao, function(aq, ar)
			return aq.cost < ar.cost
		end)
		local as = 3
		for O, at in ipairs(ao) do
			local ap = a:GetItemInSlot(at.slot)
			if ap ~= nil then
				if string.find(at.name, "recipe") or at.cost < 1000 then
					a:ActionImmediate_SellItem(ap)
					log("[ARDM] Sold: %s (cost: %s)", at.name, at.cost)
				end
			end
		end
		local au = 0
		for J = 0, 8 do
			if a:GetItemInSlot(J) ~= nil then
				au = au + 1
			end
		end
		local av = 9 - au
		if av < as then
			for O, at in ipairs(ao) do
				if av >= as then
					break
				end
				local ap = a:GetItemInSlot(at.slot)
				if ap ~= nil then
					a:ActionImmediate_SellItem(ap)
					log("[ARDM] Sold (full inv): %s (cost: %s)", at.name, at.cost)
					av = av + 1
				end
			end
		end
		a.currBuyingItemInPurchaseList = nil
		a.currBuyingBasicItem = nil
		a.currBuyingBasicItemList = {}
		a.currBuyingBasicItemRefList = {}
		a.currBuyingRequiredCounts = nil
		a.rebuildCount = 0
		a.countInvCheck = 0
	end
	if a.needPurchaseRebuild then
		a.needPurchaseRebuild = nil
		local aw = e.GetPosition(a)
		log("[PosSwap] Item purchase rebuild for %s -> pos%s", b, aw)
		local ae = string.gsub(b, "npc_dota_", "")
		local af, ag = pcall(dofile, GetScriptDirectory() .. "/BotsLib/" .. ae)
		if af and ag ~= nil and ag["sBuyList"] ~= nil then
			h = ag
			i = ag["sBuyList"]
			j = ag["sSellList"]
		end
		if i then
			local ah = c.HasBuyBoots(a)
				or c.HasItem(a, "item_guardian_greaves")
				or c.HasItem(a, "item_travel_boots")
				or c.HasItem(a, "item_travel_boots_2")
				or c.HasItem(a, "item_boots_of_bearing")
			local ai = {
				item_boots = true,
				item_phase_boots = true,
				item_power_treads = true,
				item_tranquil_boots = true,
				item_arcane_boots = true,
			}
			-- The new position's boots replace the old pair. Dropping them from the buy list
			-- left the old pair in the inventory, so a swap stacked two pairs of boots.
			if ah then
				local kept = {}
				for k = 1, #i do
					kept[i[k]] = true
					for _, part in pairs(c[i[k]] or {}) do
						kept[part] = true
					end
				end
				for _, boot in pairs(c["tEarlyBoots"]) do
					if not kept[boot] then
						local slot = a:FindItemSlot(boot)
						if slot >= 0 and slot <= 8 then
							log("[PosSwap] Selling %s — %s no longer builds it", boot, b)
							a:ActionImmediate_SellItem(a:GetItemInSlot(slot))
						end
					end
				end
			end
			a.purchaseListInReverseOrder = {}
			local aj = 0
			for k = #i, 1, -1 do
				local H = i[k]
				local ak = false
				if c.IsItemInHero(H) then
					ak = true
				elseif ah and ai[H] then
					ak = true
				elseif DotaTime() > 10 * 60 and Q[H] then
					ak = true
				end
				if not ak then
					aj = aj + 1
					a.purchaseListInReverseOrder[aj] = H
				end
			end
		end
		a.currBuyingItemInPurchaseList = nil
		a.currBuyingBasicItem = nil
		a.currBuyingBasicItemList = {}
		a.currBuyingBasicItemRefList = {}
		a.currBuyingRequiredCounts = nil
		a.rebuildCount = 0
		a.countInvCheck = 0
		log("[PosSwap] Purchase list rebuilt with %s items", #a.purchaseListInReverseOrder)
	end
	if a.lastItemPurchaseFrameProcessTime == nil then
		a.lastItemPurchaseFrameProcessTime = w
	end
	if w > 30 and w - a.lastItemPurchaseFrameProcessTime < 1 then
		return
	end
	a.lastItemPurchaseFrameProcessTime = w
	if GetGameState() ~= GAME_STATE_PRE_GAME and GetGameState() ~= GAME_STATE_GAME_IN_PROGRESS then
		return
	end
	if
		a:IsIllusion()
		or a:HasModifier("modifier_arc_warden_tempest_double")
		or w > 0 and e.IsMeepoClone(a)
		or a:HasModifier("modifier_dazzle_nothl_projection_soul_debuff")
	then
		a.purchaseListInReverseOrder = {}
		return
	end
	x = a:GetLevel()
	y = a:GetGold()
	z = a:GetNetWorth()
	A = a:GetActiveMode()
	B = e.GetHP(a)
	C = a:GetCourierValue()
	D = a:GetStashValue()
	E = a:DistanceFromFountain()
	QueueRightclickCounters()
	PromoteBackpackCounters()
	PreferBloodGrenadeOverBranch()
	if c.TryPickupRoshanDrop(a) then
		return
	end
	local ax = GetDroppedItemList()
	for O, ay in pairs(ax) do
		if
			ay ~= nil
			and ay.owner == a
			and ay.item ~= nil
			and not string.find(ay.item:GetName(), "token")
			and not f.HasValue(c.tEarlyConsumableItem, ay.item:GetName())
			and ay.item:GetName() ~= "item_famango"
			and ay.item:GetName() ~= "item_great_famango"
			and ay.item:GetName() ~= "item_greater_famango"
			-- Never re-pick wards we just handed to supports (breaks drop↔pickup loops).
			and ay.item:GetName() ~= "item_ward_observer"
			and ay.item:GetName() ~= "item_ward_sentry"
			and ay.item:GetName() ~= "item_ward_dispenser"
			and c.RoshanClaimKind(ay.item:GetName()) == nil
		then
			local az = GetUnitToLocationDistance(a, ay.location)
			if az > 200 and az < 1000 then
				a:Action_MoveToLocation(ay.location)
			elseif az <= 100 then
				a:Action_PickUpItem(ay.item)
				return
			end
		end
	end
	if f.IsBear(a) and a:IsAlive() then
		local aA = f.GetLoneDruid(a).bearItemsMap or {}
		local aB = GetDroppedItemList()
		for O, aC in pairs(aB) do
			if
				aC.owner == f.GetLoneDruid(a).hero
				and aC.item ~= nil
				and not string.find(aC.item:GetName(), "token")
			then
				local H = aC.item:GetName()
				if aA[H] and not c.HasItem(a, H) then
					local aD = GetUnitToLocationDistance(a, aC.location)
					if aD > 100 and aD < 1000 then
						a:Action_MoveToLocation(aC.location)
						return
					elseif aD <= 100 then
						a:Action_PickUpItem(aC.item)
						return
					end
				end
			end
		end
	end
	if d["supportExist"] == nil then
		d.UpdateSupportStatus(a)
	end
	if d["invisEnemyExist"] == false then
		d.UpdateInvisEnemyStatus(a)
	end
	if r == false and w > q + 2.0 then
		r = c.HasBuyBoots(a)
		q = w
	end
	if
		e.GetMP(a) < 0.3
		and E > 2000
		and C == 0
		and GetItemStockCount("item_clarity") > 1
		and c.GetItemCharges(a, "item_clarity") <= 0
		and y >= GetItemCost("item_clarity")
	then
		a.hasBuyClarity = true
		a:ActionImmediate_PurchaseItem("item_clarity")
	end
	if e.GetPosition(a) >= 4 then
		if
			w > 30
			and not a.hasBuyClarity
			and y >= GetItemCost("item_clarity")
			and not d.IsPvNMode()
			and f.CountBackpackEmptySpace(a) >= 2
		then
			a.hasBuyClarity = true
			a:ActionImmediate_PurchaseItem("item_clarity")
		elseif
			x >= 5
			and d["invisEnemyExist"] == true
			and r == true
			and y >= GetItemCost("item_dust")
			and c.GetEmptyInventoryAmount(a) >= 2
			and c.GetItemCharges(a, "item_dust") <= 0
			and C == 0
			and not e.HasItem(a, "item_ward_sentry")
		then
			a:ActionImmediate_PurchaseItem("item_dust")
		end
	end
	if e.IsInLaningPhase() and not string.find(b, "lone_druid") then
		if
			x < 6
			and a:IsAlive()
			and C == 0
			and a:FindItemSlot("item_flask") < 0
			and a:FindItemSlot("item_tango") < 0
			and E > 2000
			and D == 0
			and not a:HasModifier("modifier_elixer_healing")
			and not a:HasModifier("modifier_filler_heal")
			and not a:HasModifier("modifier_flask_healing")
			and not a:HasModifier("modifier_fountain_aura_buff")
			and not a:HasModifier("modifier_juggernaut_healing_ward_heal")
			and not a:HasModifier("modifier_warlock_shadow_word")
			and not IsThereHealingInStash(a)
			and c.GetEmptyInventoryAmount(a) >= 1
			and e.GetHP(a) < 0.5
		then
			local aE = e.GetLanePartner(a)
			if a:GetHealthRegen() <= 10 then
				if e.IsCore(a) then
					if aE ~= nil then
						if
							aE:FindItemSlot("item_flask") < 0
							and aE:FindItemSlot("item_tango") < 0
							and c.GetItemCharges(a, "item_flask") <= 0
							and y >= GetItemCost("item_flask")
							and GetItemStockCount("item_flask") > 1
						then
							a:ActionImmediate_PurchaseItem("item_flask")
						end
					else
						if
							c.GetItemCharges(a, "item_flask") <= 0
							and y >= GetItemCost("item_flask")
							and GetItemStockCount("item_flask") > 1
							and (
								not e.HasItem(a, "item_bottle")
								or e.HasItem(a, "item_bottle") and c.GetItemCharges(a, "item_bottle") <= 0
							)
						then
							a:ActionImmediate_PurchaseItem("item_flask")
						end
					end
				else
					if
						c.GetItemCharges(a, "item_flask") <= 0
						and y >= GetItemCost("item_flask")
						and GetItemStockCount("item_flask") > 1
					then
						a:ActionImmediate_PurchaseItem("item_flask")
					end
				end
			else
				if e.IsCore(a) then
					if aE ~= nil then
						if
							aE:FindItemSlot("item_flask") < 0
							and aE:FindItemSlot("item_tango") < 0
							and aE ~= nil
							and c.GetItemCharges(a, "item_tango") <= 0
							and y >= GetItemCost("item_tango")
							and GetItemStockCount("item_flask") > 1
						then
							a:ActionImmediate_PurchaseItem("item_tango")
						end
					else
						if
							c.GetItemCharges(a, "item_flask") <= 0
							and GetItemStockCount("item_flask") > 1
							and y >= GetItemCost("item_flask")
							and (
								not e.HasItem(a, "item_bottle")
								or e.HasItem(a, "item_bottle") and c.GetItemCharges(a, "item_bottle") <= 0
							)
						then
							a:ActionImmediate_PurchaseItem("item_flask")
						end
					end
				else
					if c.GetItemCharges(a, "item_tango") <= 0 and y >= GetItemCost("item_tango") then
						a:ActionImmediate_PurchaseItem("item_tango")
					end
				end
			end
		end
	end
	-- Supports buy wards. Old gates were too strict: stock > 1, 2 empty slots,
	-- pos4 sentry only after 5m, and obs/sentry split by exact role — so bags full
	-- of starting consumables meant nobody bought.
	local wardNames = { "item_ward_observer", "item_ward_sentry", "item_ward_dispenser" }
	local obsForHumans = e.GetPosition(a) >= 4 and ObserverStockForHumans()
	if e.GetPosition(a) >= 4 and C == 0 then
		local emptySlots = c.GetEmptyInventoryAmount(a)
		-- A buy outside the fountain shop goes straight to the stash. During the
		-- opening that sentry then sits there, so require a free slot and the shop.
		local canReceive = emptySlots >= 1 and (w >= 20 or E <= 1000)
		if canReceive then
			local function tryBuyWard(itemName, maxCharges, reason)
				if itemName == "item_ward_observer" and not obsForHumans then
					return false
				end
				if GetItemStockCount(itemName) < 1 then
					return false
				end
				if y < GetItemCost(itemName) then
					return false
				end
				if c.GetWardCharges(a, itemName) >= maxCharges then
					return false
				end
				MatchTrace.Buy(a, itemName, reason)
				a:ActionImmediate_PurchaseItem(itemName)
				y = a:GetGold()
				emptySlots = c.GetEmptyInventoryAmount(a)
				return true
			end
			-- Observers first. One sentry for the whole team before 8:00.
			-- A second waits until 8:00 or a known invis hero.
			local earlyLane = w < 8 * 60 and d["invisEnemyExist"] ~= true
			local sentryCap = 2
			if earlyLane then
				sentryCap = 1
				for _, ally in pairs(GetUnitList(UNIT_LIST_ALLIED_HEROES) or {}) do
					if
						ally ~= nil
						and ally ~= a
						and ally:IsHero()
						and not ally:IsIllusion()
						and c.GetWardCharges(ally, "item_ward_sentry") >= 1
					then
						sentryCap = 0
						break
					end
				end
			end
			tryBuyWard("item_ward_observer", 2, "support obs")
			if sentryCap > 0 and w > (a._sentryBuyAt or -100) + 15 then
				if tryBuyWard("item_ward_sentry", sentryCap, "support sentry") then
					a._sentryBuyAt = w
				end
			end
		end
		-- Supports: pick up wards a core dropped for us.
		if emptySlots >= 1 or c.GetEmptyInventoryAmount(a) >= 1 then
			for _, drop in pairs(GetDroppedItemList() or {}) do
				if drop ~= nil and drop.item ~= nil then
					local dropName = drop.item:GetName()
					if
						dropName == "item_ward_observer"
						or dropName == "item_ward_sentry"
						or dropName == "item_ward_dispenser"
					then
						local dropDist = GetUnitToLocationDistance(a, drop.location)
						if dropDist <= 1200 then
							if dropDist > 120 then
								a:Action_MoveToLocation(drop.location)
							else
								a:Action_PickUpItem(drop.item)
							end
							return
						end
					end
				end
			end
		end
	elseif e.GetPosition(a) <= 3 then
		-- Cores should not hold wards. Only drop when a support is close enough to take it;
		-- otherwise stow in backpack (never drop at own feet — that caused pick↔drop loops).
		if w > (a._lastCoreWardDrop or -100) + 3.0 then
			local nearbySupport = nil
			for _, ally in pairs(a:GetNearbyHeroes(450, false, BOT_MODE_NONE) or {}) do
				if ally ~= nil and ally ~= a and ally:IsAlive() and e.GetPosition(ally) >= 4 then
					nearbySupport = ally
					break
				end
			end
			for _, wardName in ipairs(wardNames) do
				local wardSlot = a:FindItemSlot(wardName)
				if wardSlot >= 0 then
					local wardItem = a:GetItemInSlot(wardSlot)
					if wardItem ~= nil then
						a._lastCoreWardDrop = w
						if nearbySupport ~= nil then
							MatchTrace.Buy(a, wardName, "core handoff to support")
							a:Action_DropItem(wardItem, nearbySupport:GetLocation())
							return
						elseif wardSlot <= 5 then
							for pack = 6, 8 do
								if a:GetItemInSlot(pack) == nil then
									a:ActionImmediate_SwapItems(wardSlot, pack)
									MatchTrace.Buy(a, wardName, "core stow backpack")
									break
								end
							end
						end
					end
				end
			end
		end
	end
	if
		e.GetPosition(a) == 5
		and z < 10000
		and f.CountBackpackEmptySpace(a) >= 2
		and GetItemStockCount("item_smoke_of_deceit") > 1
		and y >= GetItemCost("item_smoke_of_deceit")
		and c.GetEmptyInventoryAmount(a) >= 3
		and c.GetItemCharges(a, "item_smoke_of_deceit") == 0
		and C == 0
	then
		-- No Smoke before the horn or in the laning phase: it is wasted gold and a slot that
		-- early. Pos 5 buys one once laning is over.
		-- By the clock: the laning-phase flag drops out mid-lane (GetDesireRaw clears it and
		-- several early returns never set it back), so Techies bought one at 7:00 in lane.
		if DotaTime() >= 12 * 60 and not e.IsInLaningPhase() then
			MatchTrace.Buy(a, "item_smoke_of_deceit", "post_laning pos5")
			a:ActionImmediate_PurchaseItem("item_smoke_of_deceit")
		end
	end
	if
		e.IsInLaningPhase()
		and (e.GetPosition(a) == 4 or e.GetPosition(a) == 5)
		and GetItemStockCount("item_blood_grenade") > 0
		and x < 5
		and y >= GetItemCost("item_blood_grenade")
		and c.GetEmptyInventoryAmount(a) >= 3
		-- The 3 above counts the backpack. A grenade that arrives into a full main inventory
		-- goes to the backpack and cannot be thrown (Lina at 2:58). Need a free main slot, two
		-- away from the fountain since the courier brings build parts along with it.
		and c.GetEmptyNonBackpackInventoryAmount(a) >= (a:DistanceFromFountain() <= 1600 and 1 or 2)
		and c.GetItemCharges(a, "item_blood_grenade") == 0
		and D > 0
	then
		pcall(print, string.format(
			"[OHA-BUY] t=%.0f %s bought blood_grenade for=rebuy mainFree=%d",
			DotaTime(),
			(string.gsub(b, "npc_dota_hero_", "")),
			c.GetEmptyNonBackpackInventoryAmount(a)
		))
		a:ActionImmediate_PurchaseItem("item_blood_grenade")
	end
	if not a.hasBuyShard and GetItemStockCount("item_aghanims_shard") > 0 and y >= 1400 then
		a.hasBuyShard = true
		a:ActionImmediate_PurchaseItem("item_aghanims_shard")
	end
	if s == false and w < 0 then
		s = true
	end
	local aI = GetItemCost("item_tpscroll")
	if
		w > 4 * 60
		and C <= 100
		and y >= aI
		and not _()
		and b ~= "npc_dota_hero_meepo"
		and b ~= "npc_dota_hero_lone_druid_bear"
	then
		local a0 = c.GetItemCharges(a, "item_tpscroll")
		if a:HasModifier("modifier_teleporting") then
			a0 = a0 - 1
		end
		if a0 <= 0 or x >= 18 and a0 <= 1 then
			if y >= aI * 2 and w > 25 * 60 then
				a:ActionImmediate_PurchaseItem("item_tpscroll")
			end
			a:ActionImmediate_PurchaseItem("item_tpscroll")
		end
	end
	if w > 180 and w < 1800 and a.switchTime < w - 5.6 then
		local aJ = a:FindItemSlot("item_infused_raindrop")
		local aK = c.GetItemCharges(a, "item_infused_raindrop")
		local aL = e.GetNearbyHeroes(a, 1600, true, BOT_MODE_NONE)
		if
			aJ >= 0
			and aJ <= 5
			and (aL[1] ~= nil or A == BOT_MODE_ROSHAN or a:WasRecentlyDamagedByAnyHero(3.1))
			and (aK == 1 or aK >= 7)
		then
			a.switchTime = w
			a:ActionImmediate_SwapItems(aJ, 6)
		end
	end
	if e.GetPosition(a) >= 4 and w > (a._lastWardSwapTime or 0) + 3 then
		local aM = A == BOT_MODE_WARD
		local aN = { "item_ward_observer", "item_ward_sentry", "item_ward_dispenser" }
		for O, aO in ipairs(aN) do
			local aP = a:FindItemSlot(aO)
			if aP >= 0 then
				if aM then
					if aP >= 6 and aP <= 8 then
						for aQ = 0, 5 do
							local aR = a:GetItemInSlot(aQ)
							if aR == nil then
								a:ActionImmediate_SwapItems(aP, aQ)
								a._lastWardSwapTime = w
								break
							end
						end
					end
				else
					-- Stash observers only. A sentry or a sentry-only dispenser
					-- goes on cooldown when it is swapped back into the bag.
					if aO == "item_ward_observer" and aP >= 0 and aP <= 5 then
						for aS = 6, 8 do
							local aT = a:GetItemInSlot(aS)
							if aT == nil then
								a:ActionImmediate_SwapItems(aP, aS)
								a._lastWardSwapTime = w
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
	if b == "npc_dota_hero_witch_doctor" and w >= grisMinTime and w > (a._grisPurchaseCheck or -100) + 2.0 then
		a._grisPurchaseCheck = w
		local mainEmpty = c.GetEmptyNonBackpackInventoryAmount(a)
		local packEmpty = f.CountBackpackEmptySpace(a)
		if mainEmpty <= 0 and (packEmpty <= 0 or a.currBuyingBasicItem ~= nil) then
			local grisSlot = a:FindItemSlot("item_grisgris")
			if grisSlot >= 0 then
				local gris = a:GetItemInSlot(grisSlot)
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
					a:ActionImmediate_Chat(msg, true)
					if grisSlot == 16 or grisSlot >= 6 then
						for J = 0, 8 do
							local junk = a:GetItemInSlot(J)
							if
								junk ~= nil
								and junk:GetName() ~= "item_grisgris"
								and junk:GetName() ~= "item_tpscroll"
								and (GetItemCost(junk:GetName()) or 0) < 600
							then
								a:ActionImmediate_SellItem(junk)
								break
							end
						end
						for J = 0, 5 do
							if a:GetItemInSlot(J) == nil then
								a:ActionImmediate_SwapItems(grisSlot, J)
								grisSlot = J
								gris = a:GetItemInSlot(J)
								break
							end
						end
					end
					if gris ~= nil then
						a:Action_ClearActions(false)
						a:Action_UseAbility(gris)
						MatchTrace.Buy(a, "item_grisgris", "consume (purchase path)")
					end
				end
			end
		end
	end
	if
		GetGameMode() ~= 23 and x > 6 and w > a.fullInvCheck + 1.0 and (E <= 200 or a:DistanceFromSecretShop() <= 200)
		or GetGameMode() == 23 and x > 9 and w > a.fullInvCheck + 1.0
	then
		local aU = c.GetEmptyInventoryAmount(a)
		local aV = nil
		local aW = 2
		if x <= 17 then
			aW = 1
		end
		if not e.IsCore(a) and x > 10 then
			aW = 2
		end
		if aU <= aW - 1 then
			for k = 1, #c["tEarlyItem"] do
				local H = c["tEarlyItem"][k]
				local aX = a:FindItemSlot(H)
				if aX >= 0 and aX <= 8 then
					aV = aX
					break
				end
			end
			if aV == nil and not e.IsCore(a) then
				for k = 1, #c["tSupportSellWhenFull"] do
					local H = c["tSupportSellWhenFull"][k]
					local aX = a:FindItemSlot(H)
					if aX >= 0 and aX <= 8 then
						aV = aX
						break
					end
				end
			end
		end
		if aV == nil and z > 10000 and a:GetItemInSlot(6) ~= nil and a:GetItemInSlot(7) ~= nil then
			local aY = a:FindItemSlot("item_magic_wand")
			local aZ = a:FindItemSlot("item_infused_raindrop")
			if aZ < 0 then
				aZ = a:FindItemSlot("item_bracer")
			end
			if aZ < 0 then
				aZ = a:FindItemSlot("item_null_talisman")
			end
			if aZ < 0 then
				aZ = a:FindItemSlot("item_wraith_band")
			end
			if aZ >= 0 and aY >= 6 and aY <= 8 then
				aV = aZ
			end
		end
		if aV ~= nil then
			a:ActionImmediate_SellItem(a:GetItemInSlot(aV))
		end
		a.fullInvCheck = w
	end
	local a_ = f.CountBackpackEmptySpace(a)
	if w > a.sell_time + 0.5 and a_ <= 1 and (E <= 100 or a:DistanceFromSecretShop() <= 100) then
		a.sell_time = w
		SetPairedItems(c.sSellList)
		SetPairedItems(j)
		if z > 23000 then
			if c.HasItem(a, "item_hand_of_midas") then
				a:ActionImmediate_SellItem(a:GetItemInSlot(a:FindItemSlot("item_hand_of_midas")))
			end
		end
		if
			(w > 18 * 60 or z > 20000) and (c.HasItem(a, "item_travel_boots") or c.HasItem(a, "item_travel_boots_2"))
		then
			for k = 1, #c["tEarlyBoots"] do
				local b0 = a:FindItemSlot(c["tEarlyBoots"][k])
				if b0 >= 0 then
					a:ActionImmediate_SellItem(a:GetItemInSlot(b0))
				end
			end
		end
	end
	if c.HasItem(a, "item_mask_of_madness") and c.HasItem(a, "item_satanic") then
		a:ActionImmediate_SellItem(a:GetItemInSlot(a:FindItemSlot("item_mask_of_madness")))
	end
	-- Healing Lotus (item_famango*) cannot be sold — stack / use / drop to free a slot.
	-- Prefer supports holding them: healthy cores hand off to a nearby support with space.
	local lateLotus = (GetGameMode() == GAMEMODE_TURBO or GetGameMode() == 23) and (15 * 60) or (25 * 60)
	-- Step 0: finish greater-famango stack pickup after a merge drop, or start a merge anytime.
	if c.TryPickupStackedGreaterFamango(a) then
		return
	end
	if c.CanStackGreaterFamango(a) and w > (a._lastLotusStack or -100) + 2.0 then
		if c.TryStackGreaterFamango(a) then
			a._lastLotusStack = w
			MatchTrace.Buy(a, "item_greater_famango", "stack merge")
			return
		end
	end
	local function NearbySupportForLotus(preferGreaterStack)
		for _, ally in pairs(a:GetNearbyHeroes(450, false, BOT_MODE_NONE) or {}) do
			if ally ~= nil and ally ~= a and ally:IsAlive() and e.GetPosition(ally) >= 4 then
				local greater = ally:FindItemSlot("item_greater_famango")
				local canStackOnAlly = false
				if preferGreaterStack and greater >= 0 then
					local gItem = ally:GetItemInSlot(greater)
					if gItem ~= nil and c.GetLotusCharges(gItem) < c.GREATER_FAMANGO_MAX_STACK then
						canStackOnAlly = true
					end
				end
				local emptyOk = c.GetEmptyNonBackpackInventoryAmount(ally) >= 1 or canStackOnAlly
				if emptyOk then
					return ally
				end
			end
		end
		return nil
	end
	local function BackpackLotus()
		for slot = 6, 8 do
			local it = a:GetItemInSlot(slot)
			if it ~= nil and not it:IsNull() then
				local name = it:GetName()
				if
					name == "item_famango"
					or name == "item_great_famango"
					or name == "item_greater_famango"
				then
					return name, slot, it
				end
			end
		end
		return nil, -1, nil
	end
	local function BackpackForage()
		for slot = 6, 8 do
			local it = a:GetItemInSlot(slot)
			if it ~= nil and not it:IsNull() then
				local name = it:GetName()
				if
					name == "item_foragers_health"
					or name == "item_foragers_stats"
					or name == "item_foragers_mana"
				then
					return name, slot, it
				end
			end
		end
		return nil, -1, nil
	end
	-- Vital Toadstool, Ironwood Nut, Tomo'kan Ringcap. They land in the backpack, which cannot cast them.
	-- Swap one into a main slot and eat it. A drop leaves it on the ground.
	local forageCalm = #(a:GetNearbyHeroes(1200, true, BOT_MODE_NONE) or {}) == 0
		and not a:WasRecentlyDamagedByAnyHero(3.0)
	if forageCalm and w > (a._lastBackpackForage or -100) + 3.0 then
		local forageName, forageSlot, forageItem = BackpackForage()
		if forageItem ~= nil then
			a._lastBackpackForage = w
			local dest = MainSlotForBackpackItem()
			if dest == nil then
				local cheap = c.GetMainInvLessValItemSlot(a)
				if cheap ~= nil and cheap >= 0 then
					dest = cheap
				end
			end
			if dest ~= nil then
				ForceSwap(forageSlot, dest)
				local moved = a:GetItemInSlot(dest)
				if moved ~= nil and not moved:IsNull() and moved:GetName() == forageName then
					MatchTrace.Buy(a, forageName, "backpack forage swap and use")
					if forageName == "item_foragers_stats" then
						a:Action_UseAbility(moved)
					else
						a:Action_UseAbilityOnEntity(moved, a)
					end
				end
				return
			end
		end
	end
	-- A lotus in the backpack is never cast. Hand it to a support, swap it out and use it, or drop it.
	if w > (a._lastBackpackLotus or -100) + 3.0 then
		local lotusName, lotusSlot, lotusItem = BackpackLotus()
		if lotusItem ~= nil then
			a._lastBackpackLotus = w
			local hp = e.GetHP(a)
			local mp = e.GetMP(a)
			local ally = nil
			if hp >= 0.6 and mp >= 0.4 then
				ally = NearbySupportForLotus(lotusName == "item_greater_famango")
			end
			if ally ~= nil then
				MatchTrace.Buy(a, lotusName, "backpack lotus to support")
				a:Action_DropItem(lotusItem, ally:GetLocation())
				return
			end
			local dest = c.GetMainInvLessValItemSlot(a)
			if dest ~= nil and dest >= 0 then
				a:ActionImmediate_SwapItems(lotusSlot, dest)
				local moved = a:GetItemInSlot(dest)
				if moved ~= nil and not moved:IsNull() and moved:GetName() == lotusName then
					MatchTrace.Buy(a, lotusName, "backpack lotus swap and use")
					a:Action_UseAbilityOnEntity(moved, a)
				end
				return
			end
			MatchTrace.Buy(a, lotusName, "backpack lotus drop")
			a:Action_DropItem(lotusItem, a:GetLocation())
			return
		end
	end
	if e.GetPosition(a) <= 3 and w > (a._lastLotusHandoff or -100) + 4.0 then
		local hp = e.GetHP(a)
		local mp = e.GetMP(a)
		if hp >= 0.78 and mp >= 0.6 then
			local lotusName, _, lotusItem = c.FindLotusToFreeSlot(a)
			if lotusItem ~= nil then
				local ally = NearbySupportForLotus(lotusName == "item_greater_famango")
				if ally ~= nil then
					a._lastLotusHandoff = w
					MatchTrace.Buy(a, lotusName, "core handoff lotus to support")
					a:Action_DropItem(lotusItem, ally:GetLocation())
					return
				end
			end
		end
	elseif e.GetPosition(a) >= 4 then
		-- Supports pick up healing lotuses cores dropped for them (or own stack merge).
		if c.GetEmptyNonBackpackInventoryAmount(a) >= 1 or c.CanStackGreaterFamango(a) then
			for _, drop in pairs(GetDroppedItemList() or {}) do
				if drop ~= nil and drop.item ~= nil then
					local dropName = drop.item:GetName()
					if
						dropName == "item_famango"
						or dropName == "item_great_famango"
						or dropName == "item_greater_famango"
					then
						local dropDist = GetUnitToLocationDistance(a, drop.location)
						if dropDist <= 1000 then
							if dropDist > 120 then
								a:Action_MoveToLocation(drop.location)
							else
								a:Action_PickUpItem(drop.item)
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
	if w >= lateLotus and w > (a._lastLotusFreeSlot or -100) + 3.0 then
		if c.GetEmptyNonBackpackInventoryAmount(a) <= 0 then
			if c.TryStackGreaterFamango(a) then
				a._lastLotusFreeSlot = w
				MatchTrace.Buy(a, "item_greater_famango", "late full-bag stack merge")
				return
			end
			local lotusName, lotusSlot, lotusItem = c.FindLotusToFreeSlot(a)
			if lotusItem ~= nil then
				local hp = e.GetHP(a)
				local mp = e.GetMP(a)
				local ally = NearbySupportForLotus(lotusName == "item_greater_famango")
				if hp >= 0.9 and mp >= 0.85 and ally ~= nil then
					a._lastLotusFreeSlot = w
					MatchTrace.Buy(a, lotusName, "late full-bag drop to support")
					a:Action_DropItem(lotusItem, ally:GetLocation())
					return
				end
				-- Consume (even near full) — cannot sell; opens a slot for the next buy.
				if lotusSlot > 5 then
					for J = 0, 5 do
						if a:GetItemInSlot(J) == nil then
							a:ActionImmediate_SwapItems(lotusSlot, J)
							lotusSlot = J
							lotusItem = a:GetItemInSlot(J)
							break
						end
					end
				end
				if lotusItem ~= nil and lotusSlot >= 0 and lotusSlot <= 5 then
					a._lastLotusFreeSlot = w
					MatchTrace.Buy(a, lotusName, "late full-bag consume")
					a:Action_UseAbilityOnEntity(lotusItem, a)
					return
				end
			end
		end
	end
	if #a.purchaseListInReverseOrder == 0 then
		a2()
		a:SetNextItemPurchaseValue(0)
		if w < 20 and E <= 1000 and (D or 0) == 0 then
			a._openingShopDone = true
		end
		return
	end
	local b3 = {
		item_boots = true,
		item_phase_boots = true,
		item_power_treads = true,
		item_tranquil_boots = true,
		item_arcane_boots = true,
	}
	local function OwnsOtherBoots(item)
		for _, boot in pairs(c["tEarlyBoots"]) do
			if boot ~= item and a:FindItemSlot(boot) >= 0 then
				return boot
			end
		end
		return nil
	end
	if a.currBuyingItemInPurchaseList == nil and #a.currBuyingBasicItemList == 0 then
		while #a.purchaseListInReverseOrder > 0 do
			local b4 = a.purchaseListInReverseOrder[#a.purchaseListInReverseOrder]
			local otherBoots = b3[b4] and OwnsOtherBoots(b4) or nil
			if otherBoots ~= nil then
				-- A second pair never combines with the first. Sell the old one and buy this.
				local slot = a:FindItemSlot(otherBoots)
				if slot >= 0 and slot <= 8 then
					log("[Purchase] Selling %s to buy %s", otherBoots, b4)
					a:ActionImmediate_SellItem(a:GetItemInSlot(slot))
				end
				break
			elseif TeamItems.AllyOwns(a, b4) then
				-- Pipe / Crimson / Lotus / Urn / Vessel do not stack. A human or a fixed build may already have one.
				log("[Purchase] Skipping %s — an ally already has it", b4)
				a.purchaseListInReverseOrder[#a.purchaseListInReverseOrder] = nil
			else
				break
			end
		end
		if #a.purchaseListInReverseOrder == 0 then
			a2()
			a:SetNextItemPurchaseValue(0)
			return
		end
		a.currBuyingItemInPurchaseList = a.purchaseListInReverseOrder[#a.purchaseListInReverseOrder]
		local b5 = c.GetBasicItems({ a.currBuyingItemInPurchaseList })
		for k = 1, math.ceil(#b5 / 2) do
			a.currBuyingBasicItemList[k] = b5[#b5 - k + 1]
			a.currBuyingBasicItemList[#b5 - k + 1] = b5[k]
		end
		a.currBuyingBasicItemRefList = f.Deepcopy(a.currBuyingBasicItemList)
		a.currBuyingRequiredCounts = L(a.currBuyingBasicItemRefList)
		-- How many of each recipe item this build should end with: owned now plus the recipes in it.
		a._recipeTarget = {}
		for _, part in ipairs(a.currBuyingBasicItemRefList) do
			if string.find(part, "item_recipe_", 1, true) then
				local parent = string.gsub(part, "^item_recipe_", "item_")
				a._recipeTarget[parent] = (a._recipeTarget[parent] or F(a, parent)) + 1
			end
		end
		W()
	end
	if #a.currBuyingBasicItemList == 0 then
		if
			c.IsItemInHero(a.currBuyingItemInPurchaseList)
			or a.currBuyingItemInPurchaseList == "item_aghanims_shard"
			or a == f.GetLoneDruid(a).hero and f.GetLoneDruid(a).bear ~= nil and c.GetItemTotalWorthInSlots(
				f.GetLoneDruid(a).bear
			) < 28000 and c.IsItemInTargetHero(a.currBuyingItemInPurchaseList, f.GetLoneDruid(a).bear)
			or a.countInvCheck > (GetGameMode() == GAMEMODE_ARDM and 30 or 30)
			or a.rebuildCount >= 5 and C == 0 and D == 0
		then
			if a.countInvCheck > 0 or a.rebuildCount >= 5 then
				log(
					"[Purchase] %s skipping stuck item %s (rebuilds=%d invCheck=%d)",
					b,
					tostring(a.currBuyingItemInPurchaseList),
					a.rebuildCount,
					a.countInvCheck
				)
			end
			a.countInvCheck = 0
			a2()
			a.purchaseListInReverseOrder[#a.purchaseListInReverseOrder] = nil
		elseif w > a.lastInvCheck + 1.0 then
			a.lastInvCheck = w
			if C > 0 or D > 0 then
				a.countInvCheck = 0
			elseif a.rebuildCount < 5 and b ~= "npc_dota_hero_lone_druid" then
				a.rebuildCount = a.rebuildCount + 1
				for J = 0, 14 do
					local b6 = a:GetItemInSlot(J)
					if b6 then
						local b7 = b6:GetName()
						if string.find(b7, "recipe") then
							local b8 = string.gsub(b7, "item_recipe_", "item_")
							local b9 = c[b8] or c.GetComponentList(b8)
							if b9 and #b9 > 0 then
								for O, am in pairs(b9) do
									if not string.find(am, "recipe") and not c.IsItemInHero(am) then
										table.insert(a.currBuyingBasicItemList, 1, am)
									end
								end
								if #a.currBuyingBasicItemList > 0 then
									a.currBuyingRequiredCounts = L(a.currBuyingBasicItemList)
									break
								end
							end
						end
					end
				end
				local ba = c.GetReducedPurchaseList(a, a.currBuyingBasicItemRefList)
				for O, bb in pairs(ba) do
					if not c.IsItemInHero(bb) then
						a.currBuyingBasicItemList[#a.currBuyingBasicItemList + 1] = bb
					end
				end
				a.currBuyingRequiredCounts = L(a.currBuyingBasicItemList)
				W()
			else
				a.countInvCheck = a.countInvCheck + 1
			end
		end
	elseif #a.currBuyingBasicItemList > 0 then
		if a.currBuyingBasicItem == nil then
			a.currBuyingBasicItem = W()
		else
			local function buyOpening()
				if GetGameMode() == 23 then
					aa()
				else
					a3()
				end
			end
			-- One think at the fountain buys the whole starting kit, before rune mode walks out.
			if E <= 1000 and w < 20 then
				for _ = 1, 8 do
					if #a.currBuyingBasicItemList == 0 then
						break
					end
					local gold = a:GetGold()
					buyOpening()
					if a:GetGold() >= gold then
						break
					end
				end
			else
				buyOpening()
			end
		end
		if w < 20 and E <= 1000 and (D or 0) == 0 then
			local waiting = #a.currBuyingBasicItemList > 0
			local cost = 0
			if waiting and a.currBuyingBasicItem ~= nil then
				cost = GetItemCost(a.currBuyingBasicItem) or 0
			end
			if not waiting or a:GetGold() < cost or c.GetEmptyInventoryAmount(a) < 1 then
				a._openingShopDone = true
			end
		end
	end
end
function SetPairedItems(bc)
	for k = 2, #bc, 2 do
		local bd = a:FindItemSlot(bc[k - 1])
		local be = a:FindItemSlot(bc[k])
		if bd >= 0 and be >= 0 then
			a:ActionImmediate_SellItem(a:GetItemInSlot(be))
		end
	end
end
function IsThereHealingInStash(G)
	local bf = 0
	for k = 9, 14 do
		local ap = G:GetItemInSlot(k)
		if ap ~= nil then
			if
				string.find(ap:GetName(), "item_flask")
				or string.find(ap:GetName(), "item_tango")
				or string.find(ap:GetName(), "item_bottle")
			then
				bf = bf + 1
			end
		end
	end
	return bf > 0
end
g.ItemPurchaseThink = ItemPurchaseThink
return g
