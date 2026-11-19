-- No hero file (or the minion code it pulls in) leaves a helper function in the global table (#13).
-- Every bot shares one Lua state, so a global `function HasBlink()` in two hero files means one hero runs
-- the other's copy. Helpers go on the module table (X.Helper) or are forward-declared as locals.
-- This sees only functions defined while the file loads; a global assigned inside a think function
-- (`Type = ...`) needs the scope scan described in the PR for #13.
local T = ...
local Stub = T.stub

-- Folders whose functions must never be global.
local function isHeroCode(source)
	source = string.gsub(source, "\\", "/")
	return string.find(source, "BotsLib/hero_", 1, true) ~= nil
		or string.find(source, "FuncLib/hero/minion_lib/", 1, true) ~= nil
end

local function leakedFunctions()
	local leaked = {}
	for name, value in pairs(_G) do
		if type(value) == "function" then
			local info = debug.getinfo(value, "S")
			if info ~= nil and info.what == "Lua" and isHeroCode(info.source or "") then
				leaked[#leaked + 1] = tostring(name)
			end
		end
	end
	table.sort(leaked)
	return leaked
end

for _, path in ipairs(T.files("^BotsLib/hero_[%w_]+%.lua$")) do
	local file = string.match(path, "^BotsLib/(hero_[%w_]+)%.lua$")
	T.test("no global helper functions: " .. file, function()
		Stub.reset({ hero = "npc_dota_" .. file, slot = 1 })
		local ok, result = Stub.load("BotsLib/" .. file)
		if not ok then
			error(tostring(result), 0)
		end
		T.eq(table.concat(leakedFunctions(), ", "), "", file .. " global functions")
	end)
end
