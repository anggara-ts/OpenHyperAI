-- Shared bot system: log.
local rawPrint = print
function _G.log(format, ...)
	if not IsDebug then
		return
	end
	if select("#", ...) == 0 then
		rawPrint(format)
	else
		rawPrint(string.format(format, ...))
	end
end
return { log = _G.log }
