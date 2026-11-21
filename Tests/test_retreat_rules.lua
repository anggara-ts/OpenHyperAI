-- FuncLib/systems/retreat_rules.lua: when an attacking bot is outnumbered enough to hard-retreat.
-- Arguments: allies, visible enemies, recently seen enemies, hp ratio, hit by a hero, we are stronger.
local T = ...

local function rules()
	T.stub.reset({ hero = "npc_dota_hero_lich" })
	return require(GetScriptDirectory() .. "/FuncLib/systems/retreat_rules")
end

-- Arguments: hp, creep hit, tower hit, can finish a hero, channeling, holding, creeps/tower still in reach.
T.test("creep-low: game 062 Weaver leaves the creep wave", function()
	local R = rules()
	-- t=1050: 13% HP, creeps hitting her, no enemy hero near.
	T.eq(R.CreepLowRetreat(0.13, true, false, false, false, false, true), true, "Weaver 13%, creep hit")
	-- A tower alone counts too.
	T.eq(R.CreepLowRetreat(0.20, false, true, false, false, false, true), true, "20%, tower hit")
end)

T.test("creep-low: stays when it should", function()
	local R = rules()
	-- Not hit by creeps or a tower: other rules decide.
	T.eq(R.CreepLowRetreat(0.10, false, false, false, false, false, true), false, "10%, not hit")
	-- Healthy enough: 30% (the rule starts under 25%).
	T.eq(R.CreepLowRetreat(0.30, true, false, false, false, false, true), false, "30%, creep hit")
	-- A hero in reach dies to the next hit: finish it.
	T.eq(R.CreepLowRetreat(0.15, true, false, true, false, false, true), false, "15%, kill to finish")
	-- Channeling (a TP home): don't cancel it.
	T.eq(R.CreepLowRetreat(0.15, true, false, false, true, false, true), false, "15%, channeling")
end)

T.test("creep-low: hold after it fired", function()
	local R = rules()
	-- Stepped away: the creep hit flag lapsed, creeps still in reach, 28%: keep retreating.
	T.eq(R.CreepLowRetreat(0.28, false, false, false, false, true, true), true, "held at 28%, creeps near")
	-- Out of creep reach: keep the rest of the window (game 064, push walked Death Prophet back in), don't renew it.
	local fire, renew = R.CreepLowRetreat(0.28, false, false, false, false, true, false)
	T.eq(fire, true, "held, nothing in reach: rest of the window")
	T.eq(renew, false, "held, nothing in reach: window not renewed")
	local _, renewNear = R.CreepLowRetreat(0.28, false, false, false, false, true, true)
	T.eq(renewNear, true, "held, creeps near: window renewed")
	-- Window over (holding false) and nothing hitting: let go.
	T.eq(R.CreepLowRetreat(0.28, false, false, false, false, false, false), false, "window over")
	-- Healed past the release line (35%): let go.
	T.eq(R.CreepLowRetreat(0.40, true, false, false, false, true, true), false, "held, healed to 40%")
end)

T.test("creep-low: a TP home keeps retreat up (game 064, Death Prophet 42:05)", function()
	local R = rules()
	-- t=2525: 24% HP, the rule fired at t=2524 (holding), TP channel started, tower still near: keep, renew.
	local fire, renew = R.CreepLowRetreat(0.24, false, true, false, true, true, true, true)
	T.eq(fire, true, "TP channel while held: keep retreat")
	T.eq(renew, true, "TP channel while held: renew the window")
	-- The same channel with no hold (the rule never fired): other rules decide.
	T.eq(R.CreepLowRetreat(0.24, false, true, false, true, false, true, true), false, "TP, rule not fired")
	-- A channel that is not a TP (a channelled spell): drop the rule, as before.
	T.eq(R.CreepLowRetreat(0.24, true, false, false, true, true, true, false), false, "other channel")
end)

T.test("finish exemption: no finish when the bot dies first (game 064, Alchemist 22:23)", function()
	local R = rules()
	-- t=1343: 18% HP, 5 enemy heroes hitting him: no exemption, whatever the damage estimate says.
	T.eq(R.DiesBeforeFinish(0.18, 400, 5, 0), true, "18%, 5 heroes on him")
	T.eq(select(2, R.DiesBeforeFinish(0.18, 400, 5, 0)), "low-hp", "why=low-hp")
	-- One hero on him at 18% with a small estimate: the finish can go ahead.
	T.eq(R.DiesBeforeFinish(0.18, 400, 1, 150), false, "18%, one hero, 150 incoming")
	-- Healthier, but the heroes on him deal more than his HP before his hit lands: no exemption.
	T.eq(R.DiesBeforeFinish(0.40, 900, 2, 950), true, "40%, 950 incoming vs 900 HP")
	T.eq(select(2, R.DiesBeforeFinish(0.40, 900, 2, 950)), "burst", "why=burst")
	-- Nobody hitting him: finish it.
	T.eq(R.DiesBeforeFinish(0.10, 200, 0, 0), false, "10%, nobody hitting")
	-- The retreat file uses the target-only check, not Fu.ShouldFinishCommittedKill, for both exemptions.
	local src = T.read("mode_retreat_generic.lua")
	T.ok(string.find(src, 'local freeKill = FinishKillExempt("hard-retreat")', 1, true) ~= nil, "hard retreat")
	T.ok(string.find(src, 'FinishKillExempt("creep-low")', 1, true) ~= nil, "creep-low")
end)

T.test("creep-low: Roshan counts as a creep (game 063, Earth Spirit and Alchemist died in Roshan mode)", function()
	local R = rules()
	-- Alchemist t=2755: 18% HP, Roshan hitting him (a creep hit), out of the exemption now.
	T.eq(R.CreepLowRetreat(0.18, true, false, false, false, false, true), true, "Roshan hit at 18%")
	-- Held near the pit (the caller passes "within 2500 of the pit" as in reach): Roshan mode can't call him back.
	T.eq(R.CreepLowRetreat(0.20, false, false, false, false, true, true), true, "held near the pit at 20%")
	-- The retreat file runs the rule inside the Roshan / Tormentor exemption, before its NONE (tag 232).
	local src = T.read("mode_retreat_generic.lua")
	local ruleAt = string.find(src, "CreepLowDesire(true)", 1, true)
	local exemptAt = string.find(src, "RetreatTag(232, BOT_MODE_DESIRE_NONE)", 1, true)
	T.ok(ruleAt ~= nil and exemptAt ~= nil and ruleAt < exemptAt, "creep-low before the Roshan exemption")
end)

T.test("pit leave: only for a bot in a Roshan fight (game 065, tag 217)", function()
	local R = rules()
	-- Clinkz t=126 / Dark Willow t=398: low in a lane near the pit, never in the Roshan fight: other rules decide.
	local applies, why = R.RoshanLeaveApplies(true, true, 999, false)
	T.eq(applies, false, "lane bot near the pit")
	T.eq(why, "not-in-fight", "lane bot near the pit: why")
	-- Primal Beast t=2609: hit Roshan a second before, but Roshan just died: no pit leave, creep-low keeps its 0.98.
	applies, why = R.RoshanLeaveApplies(true, false, 1, false)
	T.eq(applies, false, "Roshan dead")
	T.eq(why, "rosh-dead", "Roshan dead: why")
	-- In the fight (hit by Roshan 1s ago), or already sent out and not healed yet: leave.
	T.eq(R.RoshanLeaveApplies(true, true, 1, false), true, "in the fight")
	T.eq(R.RoshanLeaveApplies(true, true, 30, true), true, "sent out, still under 60%")
	-- Far from the pit: never.
	T.eq(R.RoshanLeaveApplies(false, true, 0, true), false, "far from the pit")
	-- The retreat file asks the creep-low rule first inside the pit leave (0.98 is not cut to 0.70).
	local src = T.read("mode_retreat_generic.lua")
	local creepAt = string.find(src, "local roshanLow = CreepLowDesire(true)", 1, true)
	local tagAt = string.find(src, "RetreatTag(217, leaveDesire)", 1, true)
	T.ok(creepAt ~= nil and tagAt ~= nil and creepAt < tagAt, "creep-low before the pit-leave return")
end)

T.test("hard retreat: healthy cases from game 038 keep fighting", function()
	local R = rules()
	-- Mirana t=29: alone, nobody within 1200, two lane opponents last seen within 2000, full HP.
	T.eq(R.HardRetreatOutnumbered(1, 0, 2, 1.00, false, false), false, "Mirana t=29")
	-- Meepo t=1115: three bodies (clones counted now) against two, full HP.
	T.eq(R.HardRetreatOutnumbered(3, 2, 2, 1.00, true, false), false, "Meepo t=1115")
	-- Healthy, one more enemy than us and being hit: still fight (not two more).
	T.eq(R.HardRetreatOutnumbered(2, 3, 3, 0.85, true, false), false, "2 vs 3 at 85%")
end)

T.test("hard retreat: still breaks off when it should", function()
	local R = rules()
	-- Healthy but alone against three that it can see, and being hit.
	T.eq(R.HardRetreatOutnumbered(1, 3, 3, 0.90, true, false), true, "1 vs 3 at 90%, hit")
	-- Same but not being hit yet: hold (the fight may not be on us).
	T.eq(R.HardRetreatOutnumbered(1, 3, 3, 0.90, false, false), false, "1 vs 3 at 90%, not hit")
	-- Hurt: stale sightings count, as before.
	T.eq(R.HardRetreatOutnumbered(1, 0, 2, 0.45, false, false), true, "alone at 45%, two last seen")
	T.eq(R.HardRetreatOutnumbered(2, 3, 3, 0.50, false, false), true, "2 vs 3 at 50%")
	-- Hurt but our side is stronger (Fu.WeAreStronger): keep fighting unless alone.
	T.eq(R.HardRetreatOutnumbered(2, 3, 3, 0.50, false, true), false, "2 vs 3 at 50%, stronger")
end)
