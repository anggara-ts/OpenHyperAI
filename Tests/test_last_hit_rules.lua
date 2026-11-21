-- FuncLib/systems/last_hit_rules.lua: last-hit timing rules (#71): turn time, creep value, early start, wind-up
-- release / cancel.
local T = ...

local function rules()
	T.stub.reset({ hero = "npc_dota_hero_nevermore" })
	return require(GetScriptDirectory() .. "/FuncLib/systems/last_hit_rules")
end

T.test("turn time: 0.03 * radians / turn rate, after the 11.5 degree tolerance", function()
	local R = rules()
	-- Liquipedia "Turn Rate": 180 degrees at 0.6 is 0.03 * pi / 0.6 = 0.157s; less the 11.5 degree tolerance.
	T.near(R.TurnTime(180, 0.6), 0.03 * math.rad(168.5) / 0.6, 1e-9, "180 at 0.6")
	T.near(R.TurnTime(180, 0.6), 0.147, 0.001, "about 0.147s")
	T.eq(R.TurnTime(11.5, 0.6), 0, "inside the tolerance")
	T.eq(R.TurnTime(5, 0.9), 0, "facing it already")
	T.ok(R.TurnTime(90, 0.9) < R.TurnTime(90, 0.6), "a faster turner turns sooner")
	T.eq(R.TurnTime(90, 0), 0, "a bad turn rate gives no time, not inf")
end)

T.test("turn angle: facing degrees against the direction to the target", function()
	local R = rules()
	T.near(R.TurnAngle(0, 100, 0), 0, 1e-9, "facing east, target east")
	T.near(R.TurnAngle(0, -100, 0), 180, 1e-9, "target behind")
	T.near(R.TurnAngle(90, 100, 0), 90, 1e-9, "facing north, target east")
	T.near(R.TurnAngle(350, 100, 0), 10, 1e-9, "wraps around 360")
	T.near(R.TurnAngle(270, 0, 100), 180, 1e-9, "facing south, target north")
	T.eq(R.TurnAngle(45, 0, 0), 0, "on top of it")
end)

T.test("turn rates from the Valve datafeed, base 0.6", function()
	local R = rules()
	T.eq(R.TurnRate("npc_dota_hero_nevermore"), 0.9, "Shadow Fiend")
	T.eq(R.TurnRate("npc_dota_hero_kez"), 1.0, "Kez")
	T.eq(R.TurnRate("npc_dota_hero_weaver"), 0.6, "not listed: base")
	T.eq(R.TurnRate("npc_dota_hero_zuus"), 0.6, "Zeus base")
end)

T.test("creep kind and value: flagbearer > siege > ranged > melee", function()
	local R = rules()
	T.eq(R.CreepKind("npc_dota_creep_goodguys_flagbearer"), "flag")
	T.eq(R.CreepKind("npc_dota_goodguys_siege"), "siege", "game 063's siege name has no 'creep'")
	T.eq(R.CreepKind("npc_dota_creep_badguys_ranged"), "ranged")
	T.eq(R.CreepKind("npc_dota_creep_badguys_melee"), "melee")
	T.ok(R.KIND_VALUE.flag > R.KIND_VALUE.siege, "flag over siege")
	T.ok(R.KIND_VALUE.siege > R.KIND_VALUE.ranged, "siege over ranged")
	T.ok(R.KIND_VALUE.ranged > R.KIND_VALUE.melee, "ranged over melee")
end)

T.test("pick: sure beats early, value beats list order, a walk-in counts less", function()
	local R = rules()
	local nearMelee = R.PickScore("melee", true, false)
	local nearRanged = R.PickScore("ranged", true, false)
	local farFlag = R.PickScore("flag", true, true)
	local nearSiege = R.PickScore("siege", true, false)
	local earlyFlag = R.PickScore("flag", false, false)
	T.ok(nearRanged > nearMelee, "ranged over melee")
	T.ok(farFlag > nearRanged, "a far flagbearer over a near ranged creep")
	T.ok(nearSiege > farFlag, "a near siege creep over a far flagbearer")
	T.ok(nearMelee > earlyFlag, "a sure melee over an early flagbearer")
	T.ok(R.BetterPick(nearMelee, 0.5, nil, nil), "first candidate")
	T.ok(R.BetterPick(nearMelee, 0.3, nearMelee, 0.5), "tie: the hit that lands first")
	T.ok(not R.BetterPick(nearMelee, 0.6, nearMelee, 0.5), "tie: later hit loses")
end)

T.test("classify: sure / early (1.5 hits) / nil", function()
	local R = rules()
	T.eq(R.Classify(40, 45, false, true), "sure", "our hit kills")
	T.eq(R.Classify(45, 45, false, true), "early", "exactly our hit: Fu.WillKillTarget needs more than the HP")
	T.eq(R.Classify(60, 45, false, true), "early", "within 1.5 hits")
	T.eq(R.Classify(70, 45, false, true), nil, "beyond 1.5 hits")
	T.eq(R.Classify(60, 45, false, false), nil, "early not allowed (a support with a core near)")
	T.eq(R.Classify(10, 45, true, true), nil, "the others kill it first")
end)

T.test("wind-up: release a kill, wait while there is time, cancel an early miss at the last look", function()
	local R = rules()
	local function decide(over)
		local s = { predictedHp = 60, ourHit = 45, incomingKills = false, remaining = 0.05, frameGap = 0.033 }
		for k, v in pairs(over) do
			s[k] = v
		end
		return R.WindupDecision(s)
	end
	T.eq(decide({ predictedHp = 30, early = true }), "release", "our hit kills: release")
	T.eq(select(2, decide({ predictedHp = 30, early = true })), "kills")
	T.eq(decide({ incomingKills = true, early = true }), "release", "others kill it first: nothing to stop")
	T.eq(decide({ early = true, remaining = 0.2 }), "wait", "time for another look")
	local decision, why = decide({ early = true })
	T.eq(decision, "cancel", "early start, survives, last look")
	T.eq(why, "survives")
	decision, why = decide({ early = false })
	T.eq(decision, "release", "a sure start is never cancelled")
	T.eq(why, "sure")
	T.eq(decide({ early = true, remaining = -0.05 }), "cancel", "late look still tries to stop it")
end)

T.test("restart after a cancel: sure at once, early a few times, then hold", function()
	local R = rules()
	T.eq(R.RestartDecision("sure", 5), "sure")
	T.eq(R.RestartDecision("early", 0), "early")
	T.eq(R.RestartDecision("early", R.MAX_EARLY_RESTARTS), "hold", "early restarts capped")
	T.eq(R.RestartDecision(nil, 0), "hold")
end)

T.test("an early swing needs two looks inside the wind-up", function()
	local R = rules()
	T.ok(R.CanTimeWindup(0.21, 0.033), "Dark Willow's 0.21s wind-up at 30 looks a second")
	T.ok(not R.CanTimeWindup(0.21, 0.125), "at 8 looks a second it is too short")
end)

T.test("backup hit: lands after the core's, leaves the creep the core kills", function()
	local R = rules()
	local function decide(over)
		local b = {
			coreKillsFirst = false,
			coreState = "attacking",
			coreTooLate = false,
			coreCanKill = false,
			myDelay = 0.6,
			coreEta = 0.4,
			ourKills = true,
		}
		for k, v in pairs(over) do
			b[k] = v
		end
		return R.BackupDecision(b)
	end
	T.eq(decide({ coreKillsFirst = true }), "core", "the core's hit kills it first")
	T.eq(decide({ myDelay = 0.5 }), "wait", "ours would land under 0.15s after the core's")
	local decision, why = decide({})
	T.eq(decision, "go", "ours lands 0.2s after the core's and kills what is left")
	T.eq(why, "behind")
	T.eq(decide({ ourKills = false }), "wait", "still too healthy after the core's hit")
	T.eq(decide({ coreState = "free", coreCanKill = true }), "wait", "the core is free and its hit kills: it takes it")
	T.eq(decide({ coreState = "attacking", coreCanKill = true }), "wait", "the core holds it and its hit kills")
	-- Game 065 t=310 Dark Willow behind Clinkz: coreEta 0.93 against myEta 0.78, the creep taken first.
	T.eq(decide({ coreState = "free", myDelay = 0.78, coreEta = 0.93 }), "wait", "a free core walking in lands first")
	-- Game 065 t=634 Hoodwink behind Primal Beast (overlay hold): coreEta 0.59 against myEta 0.54.
	T.eq(decide({ myDelay = 0.54, coreEta = 0.59 }), "wait", "the core's hold counts as attacking")
	decision, why = decide({ coreState = "free", coreCanKill = true, coreTooLate = true, myDelay = 0.5, coreEta = 1.8 })
	T.eq(decision, "go", "the core's hit comes after the creep dies")
	T.eq(why, "late")
	for _, state in ipairs({ "busy", "far", "elsewhere" }) do
		decision, why = decide({ coreState = state, coreCanKill = true, myDelay = 0.3, coreEta = 0.9 })
		T.eq(decision, "go", "the core cannot take it: " .. state)
		T.eq(why, state)
	end
end)

T.test("backup: the core's hit is too late only clearly before it lands", function()
	local R = rules()
	T.ok(R.CoreTooLate(true, math.huge, 0.4), "hits already on their way kill it first")
	T.ok(R.CoreTooLate(false, 1.0, 1.8), "dies 0.8s before a walk-in lands")
	T.ok(not R.CoreTooLate(false, 0.35, 0.45), "within the margin: the core still gets the chance")
	T.ok(not R.CoreTooLate(false, math.huge, 3), "nothing hits it")
end)

T.test("backup swing: the core can still take it first", function()
	local R = rules()
	local b = { coreState = "attacking", coreTooLate = false, coreCanKill = true, myDelay = 0.54, coreEta = 0.59 }
	T.ok(R.BackupCoreNext(b), "game 065 t=634: Primal Beast's hit kills it, ours would land first")
	b.coreCanKill = false
	T.ok(not R.BackupCoreNext(b), "the core's hit does not kill it: ours goes")
	b.coreCanKill, b.coreState = true, "busy"
	T.ok(not R.BackupCoreNext(b), "a busy core does not take it")
	b.coreState, b.coreTooLate = "free", true
	T.ok(not R.BackupCoreNext(b), "too late for the core")
	local s = { predictedHp = 30, ourHit = 45, incomingKills = false, frameGap = 0.033, early = false, backup = true }
	s.coreNext, s.remaining = true, 0.3
	T.eq(R.WindupDecision(s), "wait", "another look first")
	s.remaining = 0.05
	local decision, why = R.WindupDecision(s)
	T.eq(decision, "cancel", "stopped for the core")
	T.eq(why, "core-next")
	s.coreNext = false
	T.eq(R.WindupDecision(s), "release", "the core cannot: ours kills it")
end)

T.test("backup swing: stopped when the core's hit kills first, at the last look", function()
	local R = rules()
	local s = { predictedHp = -5, ourHit = 45, incomingKills = true, frameGap = 0.033, early = false, backup = true }
	s.remaining = 0.3
	T.eq(R.WindupDecision(s), "wait", "time for another look")
	s.remaining = 0.05
	local decision, why = R.WindupDecision(s)
	T.eq(decision, "cancel", "the core's hit kills it")
	T.eq(why, "core")
	s.backup = false
	T.eq(R.WindupDecision(s), "release", "not a backup: nothing to stop")
end)

T.test("walk-in too late: the hit lands after the creep's estimated death", function()
	local R = rules()
	-- Game 064 t=61 Abaddon: creep 53 HP, expect=2.47, took=0.93. Two melee creeps at ~19 a hit per second: 1.39s.
	T.near(R.DeathEta(53, 38), 53 / 38, 1e-9, "HP over damage per second")
	T.eq(R.DeathEta(0, 38), 0, "already dead")
	T.eq(R.DeathEta(53, 0), math.huge, "nothing hits it")
	T.ok(R.WalkTooLate(2.47, R.DeathEta(53, 38)), "Abaddon's walk-in is not opened")
	T.ok(not R.WalkTooLate(0.8, R.DeathEta(53, 38)), "a hit that lands first still goes")
	T.ok(not R.WalkTooLate(5, R.DeathEta(300, 0)), "a creep nothing hits waits for us")
end)

T.test("deny over a timed last hit: only a more valuable creep", function()
	local R = rules()
	T.ok(not R.DenyBeatsTimedHit("melee", "melee"), "same kind: keep the last hit (our gold)")
	T.ok(not R.DenyBeatsTimedHit("melee", "ranged"), "a melee deny does not stop a ranged last hit")
	T.ok(R.DenyBeatsTimedHit("flag", "melee"), "a flagbearer deny beats a melee last hit")
	T.ok(R.DenyBeatsTimedHit("siege", "ranged"), "a siege deny beats a ranged last hit")
end)
