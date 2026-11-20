-- FuncLib/hero/minion_lib/utils.lua: a minion's castable abilities are a list with no gaps (game 049, 20:29: a Chen
-- creep with a hidden slot left a hole and minion_with_skill.lua indexed nil).
local T = ...

local function fakeAbility(name, hidden, passive)
	return {
		GetName = function()
			return name
		end,
		IsHidden = function()
			return hidden == true
		end,
		IsPassive = function()
			return passive == true
		end,
		IsNull = function()
			return false
		end,
	}
end

T.test("minion abilities: hidden and passive slots leave no gap", function()
	T.stub.reset({ hero = "npc_dota_hero_chen" })
	local MinionUtils = require(GetScriptDirectory() .. "/FuncLib/hero/minion_lib/utils")
	local slots = {
		[0] = fakeAbility("creep_hidden", true),
		[1] = fakeAbility("creep_passive", false, true),
		[2] = fakeAbility("creep_nuke"),
		[4] = fakeAbility("creep_stun"),
	}
	local unit = {
		IsNull = function()
			return false
		end,
		GetAbilityInSlot = function(_, i)
			return slots[i]
		end,
	}
	MinionUtils.InitiateAbility(unit)
	T.eq(#unit.abilities, 2, "two castable abilities")
	T.eq(unit.abilities[1]:GetName(), "creep_nuke", "first")
	T.eq(unit.abilities[2]:GetName(), "creep_stun", "second")
	for i = 1, #unit.abilities do
		T.ok(unit.abilities[i] ~= nil, "no hole at " .. i)
	end
end)
