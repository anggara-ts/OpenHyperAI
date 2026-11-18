-- Push the top lane towers.
local Push = require(GetScriptDirectory() .. "/FuncLib/systems/push")
local bot = GetBot()
if bot.PushLaneDesire == nil then
	bot.PushLaneDesire = { 0, 0, 0 }
end
function GetDesire()
	if ShouldSkipBotThink(bot) then
		return 0
	end
	return Push.GetPushDesire(bot, LANE_TOP)
end
function Think()
	if ShouldSkipBotThink(bot) then
		return
	end
	Push.PushThink(bot, LANE_TOP)
end
if SafeCall then
	local getDesire = GetDesire
	local think = Think
	if getDesire then
		GetDesire = SafeCall(getDesire, 0, "PUSH_TOWER_TOP_GetDesire")
	end
	if think then
		Think = SafeCall(think, nil, "PUSH_TOWER_TOP_Think")
	end
end
-- [OHA-PERF] timing (#52): FuncLib/systems/perf.lua
do
	local Perf = require(GetScriptDirectory() .. "/FuncLib/systems/perf")
	GetDesire = Perf.Wrap("push_tower_top.GetDesire", GetDesire)
	Think = Perf.Wrap("push_tower_top.Think", Think)
end
