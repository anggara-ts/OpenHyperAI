-- FuncLib/systems/team_memory.lua: notes shared by the bots of one team, kept apart per team.
local T = ...

T.test("team memory: one team's note is shared, the other team's is separate", function()
	T.stub.reset({ hero = "npc_dota_hero_lich" })
	local TeamMemory = require(GetScriptDirectory() .. "/FuncLib/systems/team_memory")
	TeamMemory.Set(2, "smokeAt", 829)
	T.eq(TeamMemory.Get(2, "smokeAt"), 829, "radiant note")
	T.eq(TeamMemory.Get(3, "smokeAt"), nil, "dire has none")
	local again = require(GetScriptDirectory() .. "/FuncLib/systems/team_memory")
	T.eq(again.Get(2, "smokeAt"), 829, "a second require sees the same table")
end)
