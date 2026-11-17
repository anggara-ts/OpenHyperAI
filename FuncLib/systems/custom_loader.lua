-- Loads Customize/general.lua so settings override the script defaults.
local a = nil
function LoadCustomize()
	if a then
		return a
	end
	local b, c = "game/Customize/general", nil
	-- Handler only keeps the message (see init_debug: logging inside it errored).
	local loadErr = nil
	local d, e = xpcall(function()
		c = require(b)
	end, function(f)
		loadErr = f
		return f
	end)
	if not (d and c) and loadErr ~= nil and log then
		pcall(log, "[WARN] When loading customized file: %s", tostring(loadErr))
	end
	if d and c then
		a = c
	else
		if GetScriptDirectory() == "bots" then
			a = require("bots.Customize.general")
		else
			a = require(GetScriptDirectory() .. "/Customize/general")
		end
	end
	return a
end
return LoadCustomize()
