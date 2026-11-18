-- Trash_Talk_Level 2 (the default since 2026-11-18) picks kill lines from these lists with RandomInt(1, #list)
-- (ability_item_usage_generic.lua): an empty or missing list would break the kill chat.
local T = ...
local Stub = T.stub

local KEYS = { "got_first_blood", "got_a_kill", "got_big_kill", "got_big_kill_2", "got_big_kill_3", "random_responses" }

T.test("chat: every kill-chat list has lines", function()
	Stub.reset({ hero = "npc_dota_hero_lich" })
	local Localization = require(GetScriptDirectory() .. "/FuncLib/systems/localization")
	for _, key in ipairs(KEYS) do
		local lines = Localization.Get(key)
		T.ok(type(lines) == "table" and #lines > 0, key .. ": no lines")
		for i, line in ipairs(lines) do
			T.ok(type(line) == "string" and line ~= "", key .. "[" .. i .. "]: not a line")
		end
	end
end)

T.test("chat: the default level lets ally bots talk", function()
	local src = T.read("Customize/general.lua")
	T.ok(src:find("\nCustomize.Trash_Talk_Level = 2\n", 1, true) ~= nil, "Trash_Talk_Level default is not 2")
end)
