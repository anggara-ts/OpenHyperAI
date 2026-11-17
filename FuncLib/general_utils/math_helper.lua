-- Shared helper: math helper.
local function installMathHelpers(Fu)
	function Fu.IsUnitValid(unit)
		if unit == nil then
			return false
		end
		local ok, notNull = pcall(function()
			return not unit:IsNull()
		end)
		if not ok or not notNull then
			return false
		end
		return true
	end
	function Fu.GetHP(unit)
		if not Fu.IsUnitValid(unit) or not unit:CanBeSeen() or not unit:IsAlive() then
			return 0
		end
		local health = unit:GetHealth()
		local maxHealth = unit:GetMaxHealth()
		if GetTeam() == unit:GetTeam() then
			health = unit:OriginalGetHealth()
			maxHealth = unit:OriginalGetMaxHealth()
		end
		if health <= 0 then
			return 0
		end
		return health / maxHealth
	end
	function Fu.GetMP(unit)
		if not Fu.IsUnitValid(unit) then
			return 0
		end
		if unit:GetUnitName() == "npc_dota_hero_huskar" then
			return unit:GetHealth() / unit:GetMaxHealth()
		end
		return unit:GetMana() / unit:GetMaxMana()
	end
	function Fu.GetManaAfter(manaCost)
		local bot = GetBot()
		return (bot:GetMana() - manaCost) / bot:GetMaxMana()
	end
	function Fu.GetHealthAfter(damage)
		local bot = GetBot()
		return (bot:GetHealth() - damage) / bot:GetMaxHealth()
	end
	function Fu.GetOne(value)
		return math.floor(value * 10) / 10
	end
	function Fu.ToNearest500(value)
		return math.floor(value / 500 + 0.5) * 500
	end
	function Fu.CombineTwoTable(first, second)
		local combined = first
		local firstLength = #first
		for index, item in pairs(second) do
			combined[firstLength + index] = item
		end
		return combined
	end
	function Fu.CheckBitfieldFlag(bitfield, flag)
		return bitfield / flag % 2 >= 1
	end
	function Fu.GetETAWithAcceleration(distance, speed, acceleration)
		return (math.sqrt(2 * acceleration * distance + speed * speed) - speed) / acceleration
	end
	local lastActionTime = {}
	function Fu.HasNotActionLast(interval, actionKey)
		if lastActionTime[actionKey] == nil then
			lastActionTime[actionKey] = -90
		end
		if DotaTime() > lastActionTime[actionKey] + interval then
			lastActionTime[actionKey] = DotaTime()
			return true
		end
		return false
	end
	function Fu.CountNotStunnedUnits(units, aoe, radius, minCount)
		local count = 0
		if aoe.count >= minCount then
			for _, unit in pairs(units) do
				if
					GetUnitToLocationDistance(unit, aoe.targetloc) <= radius
					and not unit:IsInvulnerable()
					and not Fu.IsDisabled(unit)
				then
					count = count + 1
				end
			end
		end
		return count
	end
	function Fu.HasHealingItem(unit)
		return Fu.HasItem(unit, "item_tango")
			or Fu.HasItem(unit, "item_tango_single")
			or Fu.HasItem(unit, "item_flask")
			or Fu.HasItem(unit, "item_bottle")
			or Fu.HasItem(unit, "item_faerie_fire")
			or Fu.HasItem(unit, "item_enchanted_mango")
			or Fu.HasItem(unit, "item_famango")
			or Fu.HasItem(unit, "item_great_famango")
			or Fu.HasItem(unit, "item_greater_famango")
			or unit:HasModifier("modifier_tango_heal")
			or unit:HasModifier("modifier_flask_healing")
			or unit:HasModifier("modifier_bottle_regeneration")
	end
end
return installMathHelpers
