-- Test runner for the bot scripts outside the game. Run from the repo root: luajit Tests/run.lua [filter]
-- Runs every Tests/test_*.lua (or only those whose file name contains the filter), prints one line per
-- case and exits non-zero when a case fails.
--
-- A test file gets the runner API as its chunk argument (local T = ...):
--   T.test(name, fn)            a case; it fails when fn raises an error
--   T.xfail(name, reason, fn)   a known bug: reported as XFAIL while fn fails; when fn passes it is an
--                               XPASS and counts as a failure, so the entry gets removed with the fix
--   T.eq(actual, expected, what) / T.near(actual, expected, tolerance, what) / T.ok(value, what)
--   T.stub                      Tests/stub_api.lua, already installed (call T.stub.reset() per case)
--   T.files(pattern)            repo files (git ls-files, tracked and untracked) matching a Lua pattern
--   T.read(path)                a file's contents
local ROOT = "."
local realLoadfile = loadfile

local function read(path)
	local f, err = io.open(path, "rb")
	if f == nil then
		error("cannot read " .. path .. ": " .. tostring(err), 2)
	end
	local content = f:read("*a")
	f:close()
	return content
end

if not io.open(ROOT .. "/Tests/run.lua", "r") then
	io.write("Run from the repo root: luajit Tests/run.lua\n")
	os.exit(2)
end

local fileList = nil
local function files(pattern)
	if fileList == nil then
		fileList = {}
		local p = io.popen('git ls-files --cached --others --exclude-standard -- "*.lua"')
		for line in p:lines() do
			line = string.gsub(line, "\r$", "")
			if line ~= "" then
				fileList[#fileList + 1] = line
			end
		end
		p:close()
		table.sort(fileList)
		if #fileList == 0 then
			error("git ls-files found no Lua files (is git installed, and is this the repo root?)")
		end
	end
	local result = {}
	for _, path in ipairs(fileList) do
		if pattern == nil or string.find(path, pattern) then
			result[#result + 1] = path
		end
	end
	return result
end

local function describe(value)
	if type(value) == "string" then
		return string.format("%q", value)
	end
	return tostring(value)
end

local T = {}
T.root = ROOT
T.read = read
T.files = files
function T.ok(value, what)
	if not value then
		error((what or "expected a true value") .. ", got " .. describe(value), 2)
	end
	return value
end
function T.eq(actual, expected, what)
	if actual ~= expected then
		error(string.format("%s: expected %s, got %s", what or "value", describe(expected), describe(actual)), 2)
	end
end
function T.near(actual, expected, tolerance, what)
	if type(actual) ~= "number" or math.abs(actual - expected) > (tolerance or 1e-6) then
		error(
			string.format(
				"%s: expected %s (+-%s), got %s",
				what or "value",
				describe(expected),
				tostring(tolerance),
				describe(actual)
			),
			2
		)
	end
end

local cases = {}
function T.test(name, fn)
	cases[#cases + 1] = { name = name, fn = fn }
end
function T.xfail(name, reason, fn)
	cases[#cases + 1] = { name = name, fn = fn, xfail = reason }
end

local Stub = realLoadfile(ROOT .. "/Tests/stub_api.lua")()
Stub.install(ROOT)
T.stub = Stub

local filter = arg and arg[1]
local testFiles = {}
for _, path in ipairs(files("^Tests/test_[%w_]+%.lua$")) do
	if filter == nil or string.find(path, filter, 1, true) then
		testFiles[#testFiles + 1] = path
	end
end

local function traceback(err)
	if debug and debug.traceback then
		return debug.traceback(tostring(err), 2)
	end
	return tostring(err)
end
-- Only the first lines of a traceback: the message and where it came from.
local function short(text, lines)
	local out, n = {}, 0
	for line in string.gmatch(tostring(text), "[^\n]+") do
		n = n + 1
		if n > lines then
			out[#out + 1] = "      ..."
			break
		end
		out[#out + 1] = "      " .. line
	end
	return table.concat(out, "\n")
end

local counts = { pass = 0, fail = 0, xfail = 0, xpass = 0 }
local failures = {}
for _, path in ipairs(testFiles) do
	io.write("== ", path, "\n")
	cases = {}
	local chunk, loadErr = realLoadfile(path)
	local ok, err = false, loadErr
	if chunk then
		ok, err = xpcall(function()
			chunk(T)
		end, traceback)
	end
	if not ok then
		counts.fail = counts.fail + 1
		failures[#failures + 1] = path .. " (loading the test file)"
		io.write("FAIL  ", path, " did not load\n", short(err, 12), "\n")
	end
	for _, case in ipairs(cases) do
		local passed, caseErr = xpcall(case.fn, traceback)
		if passed and not case.xfail then
			counts.pass = counts.pass + 1
			io.write("ok    ", case.name, "\n")
		elseif passed then
			counts.xpass = counts.xpass + 1
			failures[#failures + 1] = case.name .. " (XPASS: passes now, remove its xfail)"
			io.write("XPASS ", case.name, " -- passes now; remove the xfail (", case.xfail, ")\n")
		elseif case.xfail then
			counts.xfail = counts.xfail + 1
			io.write("xfail ", case.name, " -- ", case.xfail, "\n", short(caseErr, 1), "\n")
		else
			counts.fail = counts.fail + 1
			failures[#failures + 1] = case.name
			io.write("FAIL  ", case.name, "\n", short(caseErr, 12), "\n")
		end
	end
end

io.write(
	string.format(
		"\n%d passed, %d failed, %d expected failures, %d unexpected passes (%d files)\n",
		counts.pass,
		counts.fail,
		counts.xfail,
		counts.xpass,
		#testFiles
	)
)
for _, name in ipairs(failures) do
	io.write("  failed: ", name, "\n")
end
if #testFiles == 0 then
	io.write("no test files matched\n")
	os.exit(1)
end
os.exit((counts.fail + counts.xpass) > 0 and 1 or 0)
