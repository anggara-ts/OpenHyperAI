-- FuncLib/systems/weaver_rules.lua: Weaver's escape Shukuchi out of retreat mode (#48, game 050).
local T = ...

local function rules()
	T.stub.reset({ hero = "npc_dota_hero_weaver" })
	return require(GetScriptDirectory() .. "/FuncLib/systems/weaver_rules")
end

T.test("weaver escape: game 050 17:35, 40% then 4% HP in attack mode with three heroes on her", function()
	local R = rules()
	T.eq(R.EscapeOutOfRetreat(0.40, true, 3, false), false, "40% HP: still fighting")
	T.eq(R.EscapeOutOfRetreat(0.30, true, 3, false), true, "30% HP, hit, three enemies: escape")
	T.eq(R.EscapeOutOfRetreat(0.04, true, 1, false), true, "4% HP: escape")
end)

T.test("weaver escape: not without a hit, an enemy close, or when her target dies first", function()
	local R = rules()
	T.eq(R.EscapeOutOfRetreat(0.20, false, 2, false), false, "not hit by a hero")
	T.eq(R.EscapeOutOfRetreat(0.20, true, 0, false), false, "no enemy hero within 800")
	T.eq(R.EscapeOutOfRetreat(0.20, true, 2, true), false, "her target dies to her attacks first")
end)

T.test("weaver escape: why it could not be cast", function()
	local R = rules()
	T.eq(R.EscapeBlocked(3.2, 300, 65), "cooldown", "on cooldown")
	T.eq(R.EscapeBlocked(0, 40, 65), "mana", "not enough mana")
	T.eq(R.EscapeBlocked(0, 300, 65), "other", "silenced or similar")
end)

T.test("weaver escape: the hero file uses the rules and logs the escape", function()
	local src = T.read("BotsLib/hero_weaver.lua")
	T.ok(string.find(src, "WeaverRules.EscapeOutOfRetreat(", 1, true), "rule used")
	T.ok(string.find(src, '"shukuchi-escape"', 1, true), "escape log")
	T.ok(string.find(src, '"shukuchi-escape-skip"', 1, true), "skip log")
	T.ok(string.find(src, '"shukuchi-escape-end"', 1, true), "result log")
end)
