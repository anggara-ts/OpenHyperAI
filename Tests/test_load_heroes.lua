-- Every BotsLib/hero_*.lua loads (as bot_generic.lua does: dofile with GetBot() being that hero) as
-- each of the five positions, and returns its build table with SkillsComplement.
local T = ...
local Stub = T.stub

-- Heroes that cannot load in the stub yet, with the reason. Each one is reported as an expected failure;
-- when it starts loading the runner says XPASS and the entry should go.
local KNOWN_BROKEN = {}

for _, path in ipairs(T.files("^BotsLib/hero_[%w_]+%.lua$")) do
	local file = string.match(path, "^BotsLib/(hero_[%w_]+)%.lua$")
	local unitName = "npc_dota_" .. file
	-- Once per team slot: the stub's slot is the hero's position, and hero files pick their skill and
	-- item builds by position at load time.
	local function case()
		for slot = 1, 5 do
			Stub.reset({ hero = unitName, slot = slot })
			local ok, result = Stub.load("BotsLib/" .. file)
			if not ok then
				error("as pos " .. slot .. ": " .. tostring(result), 0)
			end
			T.eq(type(result), "table", file .. " (pos " .. slot .. ") returns")
			T.eq(type(result.SkillsComplement), "function", file .. ".SkillsComplement (pos " .. slot .. ")")
		end
	end
	if KNOWN_BROKEN[file] then
		T.xfail("load " .. file, KNOWN_BROKEN[file], case)
	else
		T.test("load " .. file, case)
	end
end
