-- Loads Customize/general.lua so settings override the script defaults.
local cachedSettings = nil
function LoadCustomize()
	if cachedSettings then
		return cachedSettings
	end
	local modulePath, settings = "game/Customize/general", nil
	-- Handler only keeps the message (see init_debug: logging inside it errored).
	local loadErr = nil
	local loadOk, loadResult = xpcall(function()
		settings = require(modulePath)
	end, function(err)
		loadErr = err
		return err
	end)
	if not (loadOk and settings) and loadErr ~= nil and log then
		pcall(log, "[WARN] When loading customized file: %s", tostring(loadErr))
	end
	if loadOk and settings then
		cachedSettings = settings
	else
		if GetScriptDirectory() == "bots" then
			cachedSettings = require("bots.Customize.general")
		else
			cachedSettings = require(GetScriptDirectory() .. "/Customize/general")
		end
	end
	return cachedSettings
end
return LoadCustomize()
