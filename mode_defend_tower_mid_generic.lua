-- Defend the mid lane. The decision itself is in FuncLib/systems/defend.lua.
local Defend = require(GetScriptDirectory() .. "/FuncLib/systems/defend")
local bot = GetBot()
function GetDesire()
	if ShouldSkipBotThink(bot) then
		return 0
	end
	return Defend.GetDefendDesire(bot, LANE_MID)
end
if SafeCall then
	local getDesire = GetDesire
	local think = Think
	if getDesire then
		GetDesire = SafeCall(getDesire, 0, "DEFEND_TOWER_MID_GetDesire")
	end
	if think then
		Think = SafeCall(think, nil, "DEFEND_TOWER_MID_Think")
	end
end
-- [OHA-PERF] timing (#52): FuncLib/systems/perf.lua
do
	local Perf = require(GetScriptDirectory() .. "/FuncLib/systems/perf")
	GetDesire = Perf.Wrap("defend_tower_mid.GetDesire", GetDesire)
	Think = Perf.Wrap("defend_tower_mid.Think", Think)
end
