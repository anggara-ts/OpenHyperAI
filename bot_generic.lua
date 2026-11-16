-- Runs once per bot. Loads that hero file from BotsLib and thinks for the bot summons.
local a = GetBot()
local b = a:GetUnitName()
if a == nil or a:IsInvulnerable() or not a:IsHero() or not string.find(b, "hero") or a:IsIllusion() then
	return
end
local c = require(GetScriptDirectory() .. "/FuncLib/systems/utils")
local d = dofile(GetScriptDirectory() .. "/BotsLib/" .. string.gsub(b, "npc_dota_", ""))
if d == nil then
	log("[ERROR] No build config file found for bot: %s", b)
	return
end
function MinionThink(e)
	if not c.IsValidUnit(e) then
		return
	end
	if e.lastMinionFrameProcessTime == nil then
		e.lastMinionFrameProcessTime = DotaTime()
	end
	if DotaTime() - e.lastMinionFrameProcessTime < 0.3 then
		return
	end
	e.lastMinionFrameProcessTime = DotaTime()
	d.MinionThink(e)
end

-- [OHA-ERROR] trap (minions). From ~11:20 every game an unwrapped entry point fails and the engine only
-- prints "Script Runtime Error: error in error handling" (its handler cannot run, typically a stack
-- overflow), then squelches it after 10 copies. Caught here and printed with its name, up to 3 times
-- per entry point per bot; the failing call still just stops, as before.
local OHA_TRAP_COUNT = {}
local function OHA_Trap(name, fn, fallback)
	if type(fn) ~= "function" then
		return fn
	end
	return function(...)
		local res = { pcall(fn, ...) }
		if res[1] then
			return unpack(res, 2)
		end
		local n = (OHA_TRAP_COUNT[name] or 0) + 1
		OHA_TRAP_COUNT[name] = n
		if n <= 3 then
			local hero = "?"
			pcall(function()
				hero = GetBot():GetUnitName()
			end)
			pcall(print, string.format("[OHA-ERROR] t=%.1f %s %s: %s", DotaTime(), hero, name, tostring(res[2])))
		end
		return fallback
	end
end
MinionThink = OHA_Trap("MinionThink", MinionThink, nil)
