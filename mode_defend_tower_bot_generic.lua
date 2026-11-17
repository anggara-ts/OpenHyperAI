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
