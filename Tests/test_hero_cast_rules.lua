-- FuncLib/systems/hero_cast_rules.lua: casts that were never made (#47): Chen Hand of God, Huskar's Shard
-- Berserker's Blood, Pugna Life Drain on an ally, Tiny Toss onto an ally, Keeper's Spirit Form heal.
local T = ...

local function rules()
	T.stub.reset({ hero = "npc_dota_hero_chen" })
	return require(GetScriptDirectory() .. "/FuncLib/systems/hero_cast_rules")
end

T.test("hand of god: supports count, lower than cores", function()
	local R = rules()
	T.eq(R.HandOfGodWorth(0.45, true, true), true, "core at 45% in danger")
	T.eq(R.HandOfGodWorth(0.45, false, true), false, "support at 45%: not yet")
	T.eq(R.HandOfGodWorth(0.30, false, true), true, "support at 30% in danger")
	T.eq(R.HandOfGodWorth(0.10, false, false), false, "nobody on them: keep the ultimate")
end)

T.test("huskar cauterize: only to drop a root or a DoT in a fight, never too low", function()
	local R = rules()
	T.eq(R.HuskarCauterize(0.6, true, false, true, 1), true, "rooted, hit, enemy near")
	T.eq(R.HuskarCauterize(0.6, false, true, true, 2), true, "burning, hit, enemies near")
	T.eq(R.HuskarCauterize(0.6, false, false, true, 2), false, "nothing to dispel")
	T.eq(R.HuskarCauterize(0.2, true, true, true, 2), false, "HP too low to pay 30%")
	T.eq(R.HuskarCauterize(0.6, true, false, false, 1), false, "not being hit by a hero")
	T.eq(R.HuskarCauterize(0.6, true, false, true, 0), false, "no enemy hero near")
end)

T.test("pugna life drain on an ally: start and stop", function()
	local R = rules()
	T.eq(R.LifeDrainAllyWorth(0.3, 0.8, true, 1), true, "low ally under attack, Pugna healthy")
	T.eq(R.LifeDrainAllyWorth(0.3, 0.4, true, 1), false, "Pugna too low to pay")
	T.eq(R.LifeDrainAllyWorth(0.6, 0.9, true, 2), false, "ally not low")
	T.eq(R.LifeDrainAllyWorth(0.3, 0.9, false, 0), false, "ally not under attack")
	T.eq(R.LifeDrainAllyStop(0.95, 0.8), true, "ally healed")
	T.eq(R.LifeDrainAllyStop(0.5, 0.2), true, "Pugna low")
	T.eq(R.LifeDrainAllyStop(0.5, 0.7), false, "keep draining")
end)

T.test("tiny toss: nearest ally 400+ from the tossed unit, in cast range", function()
	local R = rules()
	local candidates = {
		{ ok = true, spotDist = 250, tinyDist = 300 }, -- too close to the tossed unit
		{ ok = true, spotDist = 700, tinyDist = 650 },
		{ ok = true, spotDist = 500, tinyDist = 1300 }, -- out of cast range
		{ ok = true, spotDist = 600, tinyDist = 800 },
	}
	T.eq(R.PickTossAlly(candidates, 1000, R.TOSS_ALLY_MIN_DIST), 4, "nearest valid ally")
	T.eq(R.PickTossAlly({ { ok = true, spotDist = 300, tinyDist = 200 } }, 1000, 400), nil, "nobody far enough")
	T.eq(R.PickTossAlly({}, 1000, 400), nil, "no allies")
end)

T.test("keeper spirit-form heal: only in Spirit Form, for a hurt ally under attack", function()
	local R = rules()
	T.eq(R.SpiritIlluminateHealWorth(0.4, true, true), true, "hurt ally hit, in Spirit Form")
	T.eq(R.SpiritIlluminateHealWorth(0.4, true, false), false, "not in Spirit Form")
	T.eq(R.SpiritIlluminateHealWorth(0.8, true, true), false, "ally healthy")
	T.eq(R.SpiritIlluminateHealWorth(0.4, false, true), false, "ally not under attack")
end)
