-- FuncLib/systems/chat_guard.lua (issue #56): a team says the same chat text at most once per 30s.
local T = ...

local function guard()
	T.stub.reset({ hero = "npc_dota_hero_lich" })
	return require(GetScriptDirectory() .. "/FuncLib/systems/chat_guard")
end

T.test("chat guard: game 062 'Please come defending' every 3-4s is said once per 30s", function()
	local G = guard()
	local state = {}
	local key = "2t:Please come defending"
	-- 23:24:38, :41, :45, :48 and 23:26:08 in game 062 (seconds from 23:24:38).
	T.eq(G.Allow(state, key, 0), true, "first")
	T.eq(G.Allow(state, key, 3), false, "+3s")
	T.eq(G.Allow(state, key, 7), false, "+7s")
	T.eq(G.Allow(state, key, 10), false, "+10s")
	T.eq(G.Allow(state, key, 90), true, "+90s")
	-- A drop does not restart the window.
	T.eq(G.Allow(state, key, 119), false, "+29s after the last one said")
	T.eq(G.Allow(state, key, 120), true, "+30s after the last one said")
end)

T.test("chat guard: other text, the other team and all chat are separate", function()
	local G = guard()
	local state = {}
	T.eq(G.Allow(state, "2t:Defend bot!", 0), true, "first line")
	T.eq(G.Allow(state, "2t:Defend mid!", 1), true, "other text")
	T.eq(G.Allow(state, "3t:Defend bot!", 1), true, "other team")
	T.eq(G.Allow(state, "2a:Defend bot!", 1), true, "all chat")
	T.eq(G.Allow(state, "2t:Defend bot!", 2), false, "same team, same text")
end)

T.test("chat guard: a clock that went back (new game) does not block", function()
	local G = guard()
	local state = { ["2t:?"] = 1500 }
	T.eq(G.Allow(state, "2t:?", -90), true, "pregame after a long game")
end)

T.test("chat guard: the wrapper is installed over ActionImmediate_Chat", function()
	local src = T.read("FuncLib/systems/global_overrides.lua")
	T.ok(src:find("function CDOTA_Bot_Script:ActionImmediate_Chat(", 1, true) ~= nil, "no chat wrapper")
	T.ok(src:find("ChatGuard.Allow(", 1, true) ~= nil, "wrapper does not use ChatGuard.Allow")
end)
