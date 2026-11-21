-- Defend the bottom lane. The decision itself is in FuncLib/systems/defend.lua.
local Defend = require(GetScriptDirectory() .. "/FuncLib/systems/defend")
local bot = GetBot()
local botName = bot:GetUnitName()
function GetDesire()
	if ShouldSkipBotThink(bot) then
		return 0
	end
	return Defend.GetDefendDesire(bot, LANE_BOT)
end
if SafeCall then
	local originalGetDesire = GetDesire
	local originalThink = Think
	if originalGetDesire then
		GetDesire = SafeCall(originalGetDesire, 0, "DEFEND_TOWER_BOT_GetDesire")
	end
	if originalThink then
		Think = SafeCall(originalThink, nil, "DEFEND_TOWER_BOT_Think")
	end
end
-- [OHA-PERF] timing (#52): FuncLib/systems/perf.lua
do
	local Perf = require(GetScriptDirectory() .. "/FuncLib/systems/perf")
	GetDesire = Perf.Wrap("defend_tower_bot.GetDesire", GetDesire)
	Think = Perf.Wrap("defend_tower_bot.Think", Think)
end
-- [OHA-MTRACE] Meepo call trace (#139): FuncLib/systems/meepo_trace.lua. Off unless Customize.Debug_Meepo_Trace;
-- last, so it is the outermost wrapper and its lines bracket everything the engine calls.
do
	local MeepoTrace = require(GetScriptDirectory() .. "/FuncLib/systems/meepo_trace")
	GetDesire = MeepoTrace.Wrap("defend_tower_bot.GetDesire", GetDesire)
	Think = MeepoTrace.Wrap("defend_tower_bot.Think", Think)
	OnStart = MeepoTrace.Wrap("defend_tower_bot.OnStart", OnStart)
	OnEnd = MeepoTrace.Wrap("defend_tower_bot.OnEnd", OnEnd)
end
