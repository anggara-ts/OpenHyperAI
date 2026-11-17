-- Shared helper: item ability.
local function installItemAbility(Fu)
	local isDebugLogEnabled = 1 == 10
	local spamManaThreshold = 0.39
	function Fu.GetUltimateAbility(unit)
		return unit:GetAbilityInSlot(5)
	end
	function Fu.CanUseRefresherShard(bot)
		local ultimate = Fu.GetUltimateAbility(bot)
		if ultimate ~= nil and ultimate:IsPassive() == false then
			local cooldown = ultimate:GetCooldown()
			local manaCost = ultimate:GetManaCost()
			local minElapsed = 2
			if
				bot:GetMana() >= manaCost * 2
				and ultimate:GetCooldownTimeRemaining() >= cooldown / 2
				and cooldown - ultimate:GetCooldownTimeRemaining() >= minElapsed
			then
				return true
			end
		end
		return false
	end
	function Fu.GetMostUltimateCDUnit()
		local bestUnit = nil
		local bestCooldown = 0
		for index, playerId in pairs(GetTeamPlayers(GetTeam())) do
			if IsHeroAlive(playerId) then
				local member = GetTeamMember(index)
				if
					member ~= nil
					and member:IsAlive()
					and member:GetUnitName() ~= "npc_dota_hero_nevermore"
					and member:GetUnitName() ~= "npc_dota_hero_arc_warden"
				then
					if member:GetUnitName() == "npc_dota_hero_silencer" or member:GetUnitName() == "npc_dota_hero_warlock" then
						return member
					end
					local ultimate = Fu.GetUltimateAbility(member)
					if ultimate ~= nil and ultimate:IsPassive() == false and ultimate:GetCooldown() >= bestCooldown then
						bestUnit = member
						bestCooldown = ultimate:GetCooldown()
					end
				end
			end
		end
		return bestUnit
	end
	function Fu.CanCastAbilityOnTarget(target, canPierceMagicImmune)
		return target:CanBeSeen()
			and (canPierceMagicImmune or not target:IsMagicImmune())
			and not target:IsInvulnerable()
			and not Fu.IsSuspiciousIllusion(target)
			and not Fu.HasForbiddenModifier(target)
	end
	function Fu.CanCastAbility(ability)
		if
			ability == nil
			or ability:IsNull()
			or ability:IsPassive()
			or ability:IsHidden()
			or not ability:IsTrained()
			or not ability:IsFullyCastable()
			or not ability:IsActivated()
		then
			return false
		end
		return true
	end
	function Fu.CanBlinkDagger(bot)
		local blink = nil
		for slot = 0, 5 do
			local item = bot:GetItemInSlot(slot)
			if
				item ~= nil
				and (
					item:GetName() == "item_blink"
					or item:GetName() == "item_overwhelming_blink"
					or item:GetName() == "item_arcane_blink"
					or item:GetName() == "item_swift_blink"
				)
			then
				blink = item
				break
			end
		end
		if blink ~= nil and blink:IsFullyCastable() then
			bot.Blink = blink
			return true
		end
		return false
	end
	function Fu.CanBlackKingBar(bot)
		local bkb = nil
		for slot = 0, 5 do
			local item = bot:GetItemInSlot(slot)
			if item ~= nil and item:GetName() == "item_black_king_bar" then
				bkb = item
				break
			end
		end
		if bkb ~= nil and bkb:IsFullyCastable() then
			bot.BlackKingBar = bkb
			return true
		end
		return false
	end
	function Fu.HasItemInInventory(itemName)
		return GetBot():FindItemSlot(itemName) >= 0
	end
	function Fu.GetItem(itemName)
		for slot = 0, 5 do
			local item = GetBot():GetItemInSlot(slot)
			if item ~= nil and item:GetName() == itemName then
				return item
			end
		end
		return nil
	end
	function Fu.GetItem2(unit, itemName)
		for slot = 0, 16 do
			local item = unit:GetItemInSlot(slot)
			if item ~= nil then
				if string.find(item:GetName(), itemName) then
					return item
				end
			end
		end
		return nil
	end
	function Fu.GetAbility(unit, abilityName)
		for slot = 0, 23 do
			local ability = unit:GetAbilityInSlot(slot)
			if ability ~= nil and ability:GetName() == abilityName then
				return ability
			end
		end
		return nil
	end
	function Fu.GetComboItem(bot, itemName)
		local slot = bot:FindItemSlot(itemName)
		if slot >= 0 and slot <= 5 then
			return bot:GetItemInSlot(slot)
		end
	end
	function Fu.HasItem(bot, itemName)
		local slot = bot:FindItemSlot(itemName)
		if slot >= 0 and slot <= 5 then
			return true
		end
		return false
	end
	function Fu.FindItemSlotNotInNonbackpack(bot, itemName)
		local slot = bot:FindItemSlot(itemName)
		if slot >= 0 and slot <= 5 then
			return slot
		end
		return -1
	end
	function Fu.IsItemAvailable(itemName)
		local bot = GetBot()
		local slot = bot:FindItemSlot(itemName)
		if slot >= 0 and slot <= 5 then
			return bot:GetItemInSlot(slot)
		end
	end
	function Fu.IsAllowedToSpam(bot, manaCost)
		if bot:HasModifier("modifier_silencer_curse_of_the_silent") then
			return false
		end
		if bot:HasModifier("modifier_rune_regen") then
			return true
		end
		return (bot:GetMana() - manaCost) / bot:GetMaxMana() >= spamManaThreshold
	end
	function Fu.SetQueueToInvisible(bot)
		if bot:IsAlive() and not bot:IsInvisible() and not bot:HasModifier("modifier_item_dustofappearance") then
			local nearbyTowers = bot:GetNearbyTowers(888, true)
			if nearbyTowers[1] ~= nil then
				return
			end
			local shadowAmulet = Fu.IsItemAvailable("item_shadow_amulet")
			if shadowAmulet ~= nil and shadowAmulet:IsFullyCastable() then
				bot:ActionQueue_UseAbilityOnEntity(shadowAmulet, bot)
				return
			end
			local glimmerCape = Fu.IsItemAvailable("item_glimmer_cape")
			if glimmerCape ~= nil and glimmerCape:IsFullyCastable() then
				bot:ActionQueue_UseAbilityOnEntity(glimmerCape, bot)
				return
			end
			local shadowBlade = Fu.IsItemAvailable("item_invis_sword")
			if shadowBlade ~= nil and shadowBlade:IsFullyCastable() then
				bot:ActionQueue_UseAbility(shadowBlade)
				return
			end
			local silverEdge = Fu.IsItemAvailable("item_silver_edge")
			if silverEdge ~= nil and silverEdge:IsFullyCastable() then
				bot:ActionQueue_UseAbility(silverEdge)
				return
			end
		end
	end
	function Fu.SetQueueSwitchPtToINT(bot)
		local powerTreads = Fu.IsItemAvailable("item_power_treads")
		if powerTreads ~= nil and powerTreads:IsFullyCastable() then
			if powerTreads:GetPowerTreadsStat() == ATTRIBUTE_INTELLECT then
				bot:ActionQueue_UseAbility(powerTreads)
				bot:ActionQueue_UseAbility(powerTreads)
				return
			elseif powerTreads:GetPowerTreadsStat() == ATTRIBUTE_STRENGTH then
				bot:ActionQueue_UseAbility(powerTreads)
				return
			end
		end
	end
	function Fu.SetQueueUseSoulRing(bot)
		local soulRing = Fu.IsItemAvailable("item_soul_ring")
		if soulRing ~= nil and soulRing:IsFullyCastable() then
			local enemyCount = Fu.GetEnemyCount(bot, 1600)
			local hpRatio = Fu.GetHP(bot)
			local mpRatio = Fu.GetMP(bot)
			if hpRatio > 0.35 + 0.1 * enemyCount and mpRatio < 0.99 - 0.1 * enemyCount and (enemyCount <= 2 or hpRatio > mpRatio * 2.5) then
				bot:ActionQueue_UseAbility(soulRing)
				return
			end
		end
	end
	function Fu.SetQueuePtToINT(bot, useSoulRing)
		bot:Action_ClearActions(false)
		if useSoulRing then
			Fu.SetQueueUseSoulRing(bot)
		end
		-- Game 031, 66:30: OD kept switching his Power Treads. Every spell switched them to
		-- Intelligence and the Treads rule switched them back (to Strength while retreating, or to
		-- his main attribute 0.2s later). No switch for a spell while the Treads rule wants Strength.
		local ok, wantsStrength = pcall(function()
			return Fu.IsRetreating(bot) and bot:GetActiveModeDesire() > BOT_MODE_DESIRE_MODERATE
				or bot:GetHealth() < 0.3 * bot:GetMaxHealth()
		end)
		if ok and wantsStrength then
			return
		end
		if not Fu.IsPTReady(bot, ATTRIBUTE_INTELLECT) then
			bot._ptSpellSwitchAt = DotaTime()
			Fu.SetQueueSwitchPtToINT(bot)
		end
	end
	function Fu.IsPTReady(bot, attribute)
		if
			not bot:IsAlive()
			or bot:IsMuted()
			or bot:IsChanneling()
			or bot:IsInvisible()
			or bot:GetHealth() / bot:GetMaxHealth() < 0.2
		then
			return true
		end
		if attribute == ATTRIBUTE_INTELLECT then
			attribute = ATTRIBUTE_AGILITY
		elseif attribute == ATTRIBUTE_AGILITY then
			attribute = ATTRIBUTE_INTELLECT
		end
		local powerTreads = Fu.IsItemAvailable("item_power_treads")
		if powerTreads ~= nil and powerTreads:IsFullyCastable() then
			if powerTreads:GetPowerTreadsStat() ~= attribute then
				return false
			end
		end
		return true
	end
	function Fu.ShouldSwitchPTStat(bot, powerTreads)
		local currentStat = powerTreads:GetPowerTreadsStat()
		local primaryAttribute = bot:GetPrimaryAttribute()
		if currentStat == ATTRIBUTE_INTELLECT then
			currentStat = ATTRIBUTE_AGILITY
		elseif currentStat == ATTRIBUTE_AGILITY then
			currentStat = ATTRIBUTE_INTELLECT
		end
		if primaryAttribute ~= ATTRIBUTE_INTELLECT and primaryAttribute ~= ATTRIBUTE_STRENGTH and primaryAttribute ~= ATTRIBUTE_AGILITY then
			return currentStat ~= ATTRIBUTE_STRENGTH
		end
		return primaryAttribute ~= currentStat
	end
	function Fu.IsCastingUltimateAbility(unit)
		if unit:CanBeSeen() and (unit:IsCastingAbility() or unit:IsUsingAbility()) then
			local activeAbility = unit:GetCurrentActiveAbility()
			if activeAbility ~= nil and activeAbility:IsUltimate() then
				return true
			end
		end
		return false
	end
	function Fu.ConsiderForMkbDisassembleMask(bot)
		if bot.maskDismantleDone == nil then
			bot.maskDismantleDone = false
		end
		if bot.staffUnlockDone == nil then
			bot.staffUnlockDone = false
		end
		if bot.lifestealUnlockDone == nil then
			bot.lifestealUnlockDone = false
		end
		if bot.dismantleCheckTime == nil then
			bot.dismantleCheckTime = 600
		end
		if bot.staffUnlockDone then
			return
		end
		if bot.dismantleCheckTime < DotaTime() + 1.0 then
			bot.dismantleCheckTime = DotaTime()
			local maskSlot = bot:FindItemSlot("item_mask_of_madness")
			local claymoreSlot = bot:FindItemSlot("item_claymore")
			local reaverSlot = bot:FindItemSlot("item_reaver")
			if
				not bot.maskDismantleDone
				and (bot:GetItemInSlot(6) == nil or bot:GetItemInSlot(7) == nil or bot:GetItemInSlot(8) == nil)
			then
				if
					maskSlot >= 0
					and maskSlot <= 8
					and (reaverSlot >= 0 and reaverSlot <= 8 or claymoreSlot >= 0 and claymoreSlot <= 8)
					and (bot:GetGold() >= 1400 or bot:GetStashValue() >= 1400 or bot:GetCourierValue() >= 1400)
				then
					if isDebugLogEnabled then
						log("%s mask Dismantle1", bot:GetUnitName())
					end
					bot.maskDismantleDone = true
					bot:ActionImmediate_DisassembleItem(bot:GetItemInSlot(maskSlot))
					return
				end
				if maskSlot >= 0 and maskSlot <= 8 and claymoreSlot >= 0 and reaverSlot >= 0 then
					if isDebugLogEnabled then
						log("%s mask Dismantle2", bot:GetUnitName())
					end
					bot.maskDismantleDone = true
					bot:ActionImmediate_DisassembleItem(bot:GetItemInSlot(maskSlot))
					return
				end
			end
			if not bot.maskDismantleDone then
				return
			end
			local lifestealSlot = bot:FindItemSlot("item_lifesteal")
			local quarterstaffSlot = bot:FindItemSlot("item_quarterstaff")
			if lifestealSlot >= 0 and not bot.lifestealUnlockDone then
				if isDebugLogEnabled then
					log("%s lifestealUnlockDone", bot:GetUnitName())
				end
				bot.lifestealUnlockDone = true
				bot:ActionImmediate_SetItemCombineLock(bot:GetItemInSlot(lifestealSlot), false)
				return
			end
			local satanicSlot = bot:FindItemSlot("item_satanic")
			if satanicSlot >= 0 and quarterstaffSlot >= 0 and not bot.staffUnlockDone then
				if isDebugLogEnabled then
					log("%s staffUnlockDone", bot:GetUnitName())
				end
				bot.staffUnlockDone = true
				bot:ActionImmediate_SetItemCombineLock(bot:GetItemInSlot(quarterstaffSlot), false)
				return
			end
		end
	end
	function Fu.CanBeCast(ability)
		return ability:IsTrained() and ability:IsFullyCastable() and ability:IsHidden() == false
	end
	function Fu.CanSpamSpell(bot, manaCost)
		local threshold = 1.0
		if manaCost < 100 then
			threshold = 0.6
		end
		return (bot:GetMana() - manaCost) / bot:GetMaxMana() >= threshold - bot:GetLevel() / (3 * 30)
	end
	local castRangeBonus = 200
	local maxCastRange = 1600
	function Fu.GetProperCastRange(isExactRange, unit, castRange)
		local attackRange = unit:GetAttackRange()
		if isExactRange then
			return castRange
		elseif castRange <= attackRange then
			return attackRange + castRangeBonus
		elseif castRange + castRangeBonus <= maxCastRange then
			return castRange + castRangeBonus
		elseif castRange > maxCastRange then
			return maxCastRange
		else
			return castRange
		end
	end
	local maxLevel = 30
	function Fu.AllowedToSpam(bot, manaCost)
		return (bot:GetMana() - manaCost) / bot:GetMaxMana() >= 1.0 - bot:GetLevel() / (2 * maxLevel)
	end
	function Fu.HasAghanimsShard(unit)
		return unit:HasModifier("modifier_item_aghanims_shard")
	end
	function Fu.CanCastAbilitySoon(ability, seconds)
		if
			ability == nil
			or ability:IsNull()
			or ability:GetName() == ""
			or ability:IsPassive()
			or ability:IsHidden()
			or not ability:IsTrained()
			or not ability:IsActivated()
		then
			return false
		end
		if ability:GetCooldownTimeRemaining() > seconds then
			return false
		end
		return true
	end
	function Fu.GetManaThreshold(bot, manaCost, abilities)
		local threshold = 0
		local manaRegen = bot:GetManaRegen()
		local maxMana = bot:GetMaxMana()
		local slots = { 0, 1, 2, 3, 4, 5, 15 }
		for i = 1, #slots do
			local item = bot:GetItemInSlot(slots[i])
			if item then
				local itemName = item:GetName()
				if itemName == "item_tpscroll" or itemName == "item_black_king_bar" then
					local itemManaCost = item:GetManaCost()
					if Fu.CanCastAbilitySoon(item, manaCost / manaRegen) then
						threshold = threshold + itemManaCost / maxMana
					end
				end
			end
		end
		for _, ability in pairs(abilities) do
			if type(ability) == "number" then
				threshold = threshold + ability / maxMana
			else
				if Fu.CanCastAbilitySoon(ability, manaCost / manaRegen) then
					threshold = threshold + ability:GetManaCost() / maxMana
				end
			end
		end
		return threshold
	end
	function Fu.HasInvisibilityOrItem(unit)
		if
			unit:HasInvisibility(false)
			or Fu.HasItem(unit, "item_shadow_amulet")
			or Fu.HasItem(unit, "item_glimmer_cape")
			or Fu.HasItem(unit, "item_invis_sword")
			or Fu.HasItem(unit, "item_silver_edge")
		then
			return true
		end
		return false
	end
	function Fu.HasAbility(unit, abilityName)
		for slot = 0, 23 do
			local ability = unit:GetAbilityInSlot(slot)
			if ability ~= nil and ability:GetName() == abilityName then
				return true, ability
			end
		end
		return false, nil
	end
	function Fu.HasPowerTreads(bot)
		if
			Fu.HasItem(bot, "item_power_treads")
			or Fu.HasItem(bot, "item_power_treads_agi")
			or Fu.HasItem(bot, "item_power_treads_int")
			or Fu.HasItem(bot, "item_power_treads_str")
		then
			return true
		end
		return false
	end
end
return installItemAbility
