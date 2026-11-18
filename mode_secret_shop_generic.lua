-- Walks to the secret shop.
local bot = GetBot()
if
	bot == nil
	or bot:IsInvulnerable()
	or not bot:IsHero()
	or not bot:IsAlive()
	or not string.find(bot:GetUnitName(), "hero")
	or bot:IsIllusion()
then
	return
end
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local CustomLoader = require(GetScriptDirectory() .. "/FuncLib/systems/custom_loader")
CustomLoader.ThinkLess = CustomLoader.Enable and CustomLoader.ThinkLess or 1
local team = bot:GetTeam()
local enemyTeam = team == TEAM_RADIANT and TEAM_DIRE or TEAM_RADIANT
local SecretShop = {}
local preferredSecretShop = nil
local secretShop1Location = GetShopLocation(GetTeam(), SHOP_SECRET)
local secretShop2Location = GetShopLocation(GetTeam(), SHOP_SECRET2)
local hasItemToSell = false
function GetDesire()
	if ShouldSkipBotThink(GetBot()) then
		return 0
	end
	local desire = GetDesireHelper()
	return desire
end
function GetDesireHelper()
	if Fu.Utils.IsTeamPushingSecondTierOrHighGround(bot) then
		return BOT_MODE_DESIRE_NONE
	end
	local ancient = GetAncient(GetTeam())
	if
		Fu.Utils.CountEnemyHeroesOnHighGround(GetTeam()) >= 2
		or ancient and Fu.Utils.CountEnemyHeroesNear(ancient:GetLocation(), 2500) >= 1
	then
		return BOT_MODE_DESIRE_NONE
	end
	if Fu.IsFarming(bot) and Fu.IsPushing(bot) and Fu.IsDefending(bot) then
		return BOT_MODE_DESIRE_NONE
	end
	if not SecretShop.IsSuitableToBuy() then
		return BOT_MODE_DESIRE_NONE
	end
	local isInventoryFull = true
	for slot = 0, 8 do
		if bot:GetItemInSlot(slot) == nil then
			isInventoryFull = false
		end
	end
	if isInventoryFull then
		if bot:GetLevel() > 11 and bot:FindItemSlot("item_aegis") < 0 then
			hasItemToSell = SecretShop.HaveItemToSell()
			if hasItemToSell then
				preferredSecretShop = SecretShop.GetPreferedSecretShop()
				if preferredSecretShop ~= nil then
					return RemapValClamped(GetUnitToLocationDistance(bot, preferredSecretShop), 6000, 0, 0.75, 0.95)
				end
			end
		end
		return BOT_MODE_DESIRE_NONE
	end
	local courier = bot.theCourier
	local courierState = GetCourierState(courier)
	if bot.SecretShop and courierState ~= COURIER_STATE_MOVING then
		preferredSecretShop = SecretShop.GetPreferedSecretShop()
		if preferredSecretShop ~= nil and courierState == COURIER_STATE_DEAD then
			return RemapValClamped(GetUnitToLocationDistance(bot, preferredSecretShop), 6000, 0, 0.7, 0.85)
		else
			if preferredSecretShop ~= nil and GetUnitToLocationDistance(bot, preferredSecretShop) <= 3200 then
				return RemapValClamped(GetUnitToLocationDistance(bot, preferredSecretShop), 3200, 0, 0.7, 0.85)
			end
		end
	end
	return BOT_MODE_DESIRE_NONE
end
function OnStart() end
function OnEnd() end
function Think()
	if Fu.CanNotUseAction(bot) then
		return
	end
	if bot:IsChanneling() or bot:NumQueuedActions() > 0 or bot:IsCastingAbility() or bot:IsUsingAbility() then
		return
	end
	if preferredSecretShop == nil then
		preferredSecretShop = SecretShop.GetPreferedSecretShop()
	end
	if bot:DistanceFromSecretShop() == 0 then
		bot:Action_MoveToLocation(preferredSecretShop + RandomVector(200))
		return
	end
	if bot:DistanceFromSecretShop() > 0 then
		bot:Action_MoveToLocation(preferredSecretShop + RandomVector(20))
		return
	end
end
function SecretShop.HaveItemToSell()
	local sellableItems = {
		"item_clarity",
		"item_faerie_fire",
		"item_tango",
		"item_flask",
		"item_bracer",
		"item_wraith_band",
		"item_null_talisman",
		"item_infused_raindrop",
		"item_bottle",
	}
	for _, itemName in pairs(sellableItems) do
		local slot = bot:FindItemSlot(itemName)
		if slot >= 0 and slot <= 8 then
			return true, slot
		end
	end
	return false, nil
end
function SecretShop.GetPreferedSecretShop()
	if GetTeam() == TEAM_RADIANT then
		if GetUnitToLocationDistance(bot, secretShop2Location) <= 3800 then
			return secretShop2Location
		else
			return secretShop1Location
		end
	end
	if GetUnitToLocationDistance(bot, secretShop1Location) <= 3800 then
		return secretShop1Location
	else
		return secretShop2Location
	end
end
function SecretShop.IsSuitableToBuy()
	local activeMode = bot:GetActiveMode()
	local nearbyEnemies = Fu.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE)
	if
		not bot:IsAlive()
		or bot:HasModifier("modifier_item_shadow_amulet_fade")
		or activeMode == BOT_MODE_RETREAT and bot:GetActiveModeDesire() >= BOT_MODE_DESIRE_HIGH
		or activeMode == BOT_MODE_ATTACK
		or activeMode == BOT_MODE_DEFEND_ALLY
		or nearbyEnemies ~= nil and #nearbyEnemies >= 2
		or nearbyEnemies[1] ~= nil and SecretShop.IsStronger(bot, nearbyEnemies[1])
		or GetUnitToUnitDistance(bot, GetAncient(GetTeam())) < 2300
		or GetUnitToUnitDistance(bot, GetAncient(GetOpposingTeam())) < 3500
	then
		return false
	end
	return true
end
function SecretShop.IsStronger(bot, enemy)
	local botDamage = bot:GetEstimatedDamageToTarget(true, enemy, 4.0, DAMAGE_TYPE_ALL)
	local enemyDamage = enemy:GetEstimatedDamageToTarget(true, bot, 4.0, DAMAGE_TYPE_ALL)
	return enemyDamage > botDamage
end
if SafeCall then
	local originalGetDesire = GetDesire
	local originalThink = Think
	if originalGetDesire then
		GetDesire = SafeCall(originalGetDesire, 0, "SECRET_SHOP_GetDesire")
	end
	if originalThink then
		Think = SafeCall(originalThink, nil, "SECRET_SHOP_Think")
	end
end
-- [OHA-PERF] timing (#52): FuncLib/systems/perf.lua
do
	local Perf = require(GetScriptDirectory() .. "/FuncLib/systems/perf")
	GetDesire = Perf.Wrap("secret_shop.GetDesire", GetDesire)
	Think = Perf.Wrap("secret_shop.Think", Think)
end
