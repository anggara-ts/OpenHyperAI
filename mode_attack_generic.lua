-- Attack mode. Picks a fight target and how badly the bot wants that fight.
local bot = GetBot()
local botName = bot:GetUnitName()
local Utils = require(GetScriptDirectory() .. "/FuncLib/systems/utils")
local AttackOverride
if not ShouldSkipBotThink(bot) and Utils.BuggyHeroesDueToValveTooLazy[botName] then
	AttackOverride = dofile(GetScriptDirectory() .. "/FuncLib/systems/override_generic/mode_attack_generic")
end
if AttackOverride ~= nil then
	function GetDesire()
		if ShouldSkipBotThink(bot) then
			return 0
		end
		return math.min(AttackOverride.GetDesire(), BOT_MODE_DESIRE_ABSOLUTE)
	end
	function Think()
		if ShouldSkipBotThink(bot) then
			return
		end
		return AttackOverride.Think()
	end
	function OnStart()
		return AttackOverride.OnStart()
	end
	function OnEnd()
		return AttackOverride.OnEnd()
	end
end
if SafeCall then
	local originalGetDesire = GetDesire
	local originalThink = Think
	if originalGetDesire then
		GetDesire = SafeCall(originalGetDesire, 0, "ATTACK_GetDesire")
	end
	if originalThink then
		Think = SafeCall(originalThink, nil, "ATTACK_Think")
	end
end
