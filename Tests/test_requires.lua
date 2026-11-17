-- Every require / dofile of a bot script with a literal path names a file that exists (exact case, as
-- git has it: the game also runs on case-sensitive file systems).
--   require(GetScriptDirectory() .. "/X")      pcall(require, GetScriptDirectory() .. "/X")
--   dofile(GetScriptDirectory() .. "/X")       pcall(dofile, GetScriptDirectory() .. "/X")
--   require("bots.X.Y") / require("bots/X")
-- Paths built at run time (require(modulePath), "/BotsLib/" .. heroFile) are not checked here;
-- test_load_heroes.lua covers the hero files.
local T = ...

-- Modules outside this repo: the game's own files and the player's optional settings file.
local EXTERNAL = {
	["game/botsinit"] = "Valve's bot framework",
	["game/Customize/general"] = "optional user settings in game/, falls back to bots/Customize/general",
}

-- Repo paths that may legitimately be absent.
local OPTIONAL = {
	["Customize/build_info"] = "git-ignored, written by Util/build-info.js; Customize/version.lua loads it with pcall",
}

-- Known bugs: "<file> -> <module>" = reason. Reported as expected failures until fixed (then XPASS).
local KNOWN_MISSING = {
	["BotsLib/hero_muerta.lua -> FuncLib/mode_team_roam_generic_shared"] = "Muerta's X.Think requires a module "
		.. "that is not in the repo; nothing calls X.Think today, so it never fails in game",
}

local known = {}
for _, path in ipairs(T.files()) do
	known[path] = true
end

local function exists(modulePath)
	local relative = string.gsub(modulePath, "%.lua$", "")
	return known[relative .. ".lua"] == true
end

local CALL = "[%(,]%s*"
local SCRIPT_DIR = "GetScriptDirectory%(%)%s*%.%.%s*"
local function findTargets(source)
	local targets = {}
	local lineNo = 0
	for line in string.gmatch(source .. "\n", "([^\n]*)\n") do
		lineNo = lineNo + 1
		if not string.find(line, "^%s*%-%-") then
			for _, fname in ipairs({ "require", "dofile" }) do
				-- fname(GetScriptDirectory() .. "/X") or pcall(fname, GetScriptDirectory() .. "/X"); the literal
				-- must end the argument (a following ".." means the path is built at run time).
				for quote, target, after in string.gmatch(line, fname .. CALL .. SCRIPT_DIR .. "([\"'])/(.-)%1%s*(.?)") do
					if quote and after ~= "." then
						targets[#targets + 1] = { line = lineNo, kind = fname, target = target }
					end
				end
				for quote, target, after in string.gmatch(line, fname .. CALL .. "([\"'])(.-)%1%s*(.?)") do
					if quote and after ~= "." then
						targets[#targets + 1] = { line = lineNo, kind = fname, target = target, literal = true }
					end
				end
			end
		end
	end
	return targets
end

local checked = 0
local missing = {}
local knownMissing = {}
local sources = T.files("%.lua$")
for _, path in ipairs(sources) do
	if not string.find(path, "^Tests/") then
		for _, ref in ipairs(findTargets(T.read(path))) do
			local target = ref.target
			local resolved = nil
			if not ref.literal then
				resolved = target
			elseif string.find(target, "^bots[./]") then
				resolved = string.gsub(string.sub(target, 6), "%.", "/")
			end
			if resolved ~= nil then
				checked = checked + 1
				local key = path .. " -> " .. resolved
				if KNOWN_MISSING[key] then
					knownMissing[key] = not exists(resolved)
				elseif not exists(resolved) and not OPTIONAL[resolved] then
					missing[#missing + 1] =
						string.format("%s:%d: %s %q -> %s.lua not found", path, ref.line, ref.kind, target, resolved)
				end
			elseif not EXTERNAL[target] and string.find(target, "/") then
				missing[#missing + 1] = string.format(
					"%s:%d: %s %q is neither bots/ nor a known external module",
					path,
					ref.line,
					ref.kind,
					target
				)
			end
		end
	end
end

-- About 680 when written (2026-11-17). If the code changes its require style, update the patterns
-- above rather than let this pass on nothing.
T.test("the require patterns still match the code base (" .. checked .. " literal paths)", function()
	T.ok(checked > 600, "checked " .. checked .. " literal require/dofile paths, expected more than 600")
end)

T.test("every literal require/dofile path exists", function()
	if #missing > 0 then
		error(#missing .. " unresolved:\n" .. table.concat(missing, "\n"), 0)
	end
end)

for key, reason in pairs(KNOWN_MISSING) do
	-- Passes (XPASS) once the module exists or the require is gone: then remove the entry.
	T.xfail("require " .. key, reason, function()
		if knownMissing[key] then
			error("module not found", 0)
		end
	end)
end
