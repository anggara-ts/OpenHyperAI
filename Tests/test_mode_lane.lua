-- FuncLib/general_utils/bot_mode.lua Fu.GetModeLane: the lane of a push / defend mode. Global movement while
-- pushing or defending goes there, not to the assigned lane (game 062, 41:09: Nature's Prophet in push mid,
-- mode 9, teleported to his assigned top lane).
local T = ...

local function setup()
	T.stub.reset({ hero = "npc_dota_hero_furion" })
	return require(GetScriptDirectory() .. "/FuncLib/func_utils")
end

T.test("GetModeLane: push modes", function()
	local Fu = setup()
	T.eq(Fu.GetModeLane(BOT_MODE_PUSH_TOWER_TOP), LANE_TOP, "push top")
	T.eq(Fu.GetModeLane(BOT_MODE_PUSH_TOWER_MID), LANE_MID, "push mid")
	T.eq(Fu.GetModeLane(BOT_MODE_PUSH_TOWER_BOT), LANE_BOT, "push bot")
	-- The game 062 case by number: mode 9 is push mid, lane 2 is mid.
	T.eq(Fu.GetModeLane(9), 2, "mode 9 -> lane 2")
end)

T.test("GetModeLane: defend modes", function()
	local Fu = setup()
	T.eq(Fu.GetModeLane(BOT_MODE_DEFEND_TOWER_TOP), LANE_TOP, "defend top")
	T.eq(Fu.GetModeLane(BOT_MODE_DEFEND_TOWER_MID), LANE_MID, "defend mid")
	T.eq(Fu.GetModeLane(BOT_MODE_DEFEND_TOWER_BOT), LANE_BOT, "defend bot")
end)

T.test("GetModeLane: other modes have no lane", function()
	local Fu = setup()
	T.eq(Fu.GetModeLane(BOT_MODE_LANING), nil, "laning")
	T.eq(Fu.GetModeLane(BOT_MODE_TEAM_ROAM), nil, "team roam")
	T.eq(Fu.GetModeLane(BOT_MODE_RETREAT), nil, "retreat")
	T.eq(Fu.GetModeLane(nil), nil, "nil")
end)
