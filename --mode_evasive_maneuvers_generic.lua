-- Disabled stub for mode_evasive_maneuvers_generic. The -- prefix in the filename keeps Dota from loading it, so Valve default behavior is used.
local bot = GetBot()
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
function GetDesire()
	if ShouldSkipBotThink(GetBot()) then
		return 0
	end
	local isNearSerpentWard = false
	for _, enemyUnit in pairs(GetUnitList(UNIT_LIST_ENEMIES)) do
		if
			Fu.IsValid(enemyUnit)
			and GetUnitToUnitDistance(bot, enemyUnit) < 1200
			and string.find(enemyUnit:GetUnitName(), "shadow_shaman_ward")
		then
			isNearSerpentWard = true
			break
		end
	end
	if isNearSerpentWard then
		return BOT_MODE_DESIRE_NONE
	end
end
