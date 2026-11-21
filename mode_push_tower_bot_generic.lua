-- Push the bottom lane towers.
local Push = require(GetScriptDirectory() .. "/FuncLib/systems/push")
local bot = GetBot()
if bot.PushLaneDesire == nil then
	bot.PushLaneDesire = { 0, 0, 0 }
end
function GetDesire()
	if ShouldSkipBotThink(bot) then
		return 0
	end
	return Push.GetPushDesire(bot, LANE_BOT)
end
function Think()
	if ShouldSkipBotThink(bot) then
		return
	end
	Push.PushThink(bot, LANE_BOT)
end
if SafeCall then
	local originalGetDesire = GetDesire
	local originalThink = Think
	if originalGetDesire then
		GetDesire = SafeCall(originalGetDesire, 0, "PUSH_TOWER_BOT_GetDesire")
	end
	if originalThink then
		Think = SafeCall(originalThink, nil, "PUSH_TOWER_BOT_Think")
	end
end
-- [OHA-PERF] timing (#52): FuncLib/systems/perf.lua
do
	local Perf = require(GetScriptDirectory() .. "/FuncLib/systems/perf")
	GetDesire = Perf.Wrap("push_tower_bot.GetDesire", GetDesire)
	Think = Perf.Wrap("push_tower_bot.Think", Think)
end
-- [OHA-MTRACE] Meepo call trace (#139): FuncLib/systems/meepo_trace.lua. Off unless Customize.Debug_Meepo_Trace;
-- last, so it is the outermost wrapper and its lines bracket everything the engine calls.
do
	local MeepoTrace = require(GetScriptDirectory() .. "/FuncLib/systems/meepo_trace")
	GetDesire = MeepoTrace.Wrap("push_tower_bot.GetDesire", GetDesire)
	Think = MeepoTrace.Wrap("push_tower_bot.Think", Think)
	OnStart = MeepoTrace.Wrap("push_tower_bot.OnStart", OnStart)
	OnEnd = MeepoTrace.Wrap("push_tower_bot.OnEnd", OnEnd)
end
