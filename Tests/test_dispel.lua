-- FuncLib/systems/dispel.lua: the self-dispel check runs at the end of every item think of every bot (#52).
-- Without a ready dispel item it must answer -1 without reading the bot's modifiers; with one it must still
-- answer as before.
local T = ...

local function dispel()
	T.stub.reset({ hero = "npc_dota_hero_lich" })
	return require(GetScriptDirectory() .. "/FuncLib/systems/dispel")
end

-- A bot with only what the check reads. items: { [slot] = { name =, ready = } }, modifiers: { [name] = true }.
local function fakeBot(items, modifiers)
	local reads = { modifiers = 0 }
	local bot = { reads = reads }
	function bot:HasModifier(name)
		reads.modifiers = reads.modifiers + 1
		return modifiers[name] == true
	end
	function bot:FindItemSlot(name)
		for slot, item in pairs(items) do
			if item.name == name then
				return slot
			end
		end
		return -1
	end
	function bot:GetItemInSlot(slot)
		local item = items[slot]
		if item == nil then
			return nil
		end
		return {
			IsFullyCastable = function()
				return item.ready
			end,
		}
	end
	function bot:IsBot()
		return true
	end
	function bot:GetHealth()
		return 800
	end
	function bot:GetMaxHealth()
		return 1000
	end
	function bot:GetNearbyHeroes()
		return {}
	end
	function bot:GetModifierByName()
		return 0
	end
	function bot:GetModifierRemainingDuration()
		return 3
	end
	function bot:GetAbilityInSlot()
		return nil
	end
	function bot:GetPlayerID()
		return T.stub.PLAYER_IDS[TEAM_RADIANT][1]
	end
	return bot
end

T.test("self-dispel: no dispel item means -1 without reading a modifier", function()
	local Dispel = dispel()
	local bot = fakeBot({ [0] = { name = "item_blink", ready = true } }, { modifier_stunned = true })
	T.eq(Dispel.HasReadySelfDispelItem(bot), false, "no dispel item")
	T.eq(Dispel.ShouldUseSelfDispelItem(bot), -1, "answer")
	T.eq(bot.reads.modifiers, 0, "modifier reads")
end)

T.test("self-dispel: an item on cooldown means -1 without reading a modifier", function()
	local Dispel = dispel()
	local bot = fakeBot({ [2] = { name = "item_black_king_bar", ready = false } }, { modifier_stunned = true })
	T.eq(Dispel.ShouldUseSelfDispelItem(bot), -1, "answer")
	T.eq(bot.reads.modifiers, 0, "modifier reads")
end)

T.test("self-dispel: a ready item is still used on a real debuff, and kept without one", function()
	local Dispel = dispel()
	-- Stunned (severity 9, strong dispel only): Black King Bar's slot.
	local stunned = fakeBot({ [2] = { name = "item_black_king_bar", ready = true } }, { modifier_stunned = true })
	T.eq(Dispel.HasReadySelfDispelItem(stunned), true, "ready item")
	T.eq(Dispel.ShouldUseSelfDispelItem(stunned), 2, "BKB slot while stunned")
	local clean = fakeBot({ [2] = { name = "item_black_king_bar", ready = true } }, {})
	T.eq(Dispel.ShouldUseSelfDispelItem(clean), -1, "nothing to dispel")
	T.ok(clean.reads.modifiers > 0, "the debuffs were read")
end)

T.test("AnalyzeDebuffs gives the same answer on every call (the debuff list is built once)", function()
	local Dispel = dispel()
	local bot = fakeBot({}, { modifier_stunned = true, modifier_bashed = true })
	local first = Dispel.AnalyzeDebuffs(bot)
	local second = Dispel.AnalyzeDebuffs(bot)
	T.eq(first.score, 18, "two severity-9 debuffs")
	T.eq(second.score, first.score, "second call")
	T.eq(first.worstSeverity, 9, "worst")
	T.eq(first.hasDisable, true, "disable")
	T.eq(first.canStrongDispel, true, "strong dispel")
end)
