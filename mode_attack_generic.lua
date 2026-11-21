-- Attack mode. Picks a fight target and how badly the bot wants that fight.
local bot = GetBot()
local botName = bot:GetUnitName()
local Utils = require(GetScriptDirectory() .. "/FuncLib/systems/utils")
local AttackOverride
if not ShouldSkipBotThink(bot) and Utils.BuggyHeroesDueToValveTooLazy[botName] then
	AttackOverride = dofile(GetScriptDirectory() .. "/FuncLib/systems/override_generic/mode_attack_generic")
end
-- Heroes not on the list keep Valve's attack mode: this file defines no GetDesire/Think for them,
-- and defining one would replace Valve's with no way to call it. Their attack-mode extras (kiting:
-- FuncLib/hero/special_units.lua TryKiteInAttack) run from the per-think item/ability hook. The
-- flag tells that hook this hero kites from the override's Think instead.
if AttackOverride ~= nil then
	bot._ohaAttackOverride = true
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
-- [OHA-PERF] timing (#52): FuncLib/systems/perf.lua
do
	local Perf = require(GetScriptDirectory() .. "/FuncLib/systems/perf")
	GetDesire = Perf.Wrap("attack.GetDesire", GetDesire)
	Think = Perf.Wrap("attack.Think", Think)
end
-- [OHA-MTRACE] Meepo call trace (#139): FuncLib/systems/meepo_trace.lua. Off unless Customize.Debug_Meepo_Trace;
-- last, so it is the outermost wrapper and its lines bracket everything the engine calls.
do
	local MeepoTrace = require(GetScriptDirectory() .. "/FuncLib/systems/meepo_trace")
	GetDesire = MeepoTrace.Wrap("attack.GetDesire", GetDesire)
	Think = MeepoTrace.Wrap("attack.Think", Think)
	OnStart = MeepoTrace.Wrap("attack.OnStart", OnStart)
	OnEnd = MeepoTrace.Wrap("attack.OnEnd", OnEnd)
end
