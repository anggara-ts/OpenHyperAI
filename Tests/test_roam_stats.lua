-- FuncLib/systems/roam_stats.lua and hunt_trace.lua (#165, mode flip-flops): the team roam activation counts and
-- the line formats. Tests/data/flip_report_sample.txt holds the lines Util/flip-report.js --self-test parses, so a
-- format change here that the tool does not follow fails one of the two.
local T = ...

local function load()
	T.stub.reset({ hero = "npc_dota_hero_medusa" })
	return require(GetScriptDirectory() .. "/FuncLib/systems/roam_stats"),
		require(GetScriptDirectory() .. "/FuncLib/systems/hunt_trace")
end

local SAMPLE = T.read("Tests/data/flip_report_sample.txt")

local function inSample(text, what)
	T.ok(string.find(SAMPLE, text, 1, true) ~= nil, what .. ": " .. text)
end

T.test("roam stats: cap label from adjustDesire's outcome", function()
	local R = load()
	T.eq(R.CapLabel(1.5, 0.5), "push", "pushing: above 0.6 -> 0.5")
	T.eq(R.CapLabel(1.5, 0.72), "lane", "laning phase: above 0.9 -> 0.72")
	T.eq(R.CapLabel(0.64, 0.64), "none", "not cut")
	T.eq(R.DwellBucket(0.5), 1, "under 1s")
	T.eq(R.DwellBucket(1.4), 2, "1s")
	T.eq(R.DwellBucket(3.9), 3, "2-3s")
	T.eq(R.DwellBucket(5.1), 4, "4s+")
end)

T.test("roam stats: FLIP annotation", function()
	local R = load()
	T.eq(R.FlipNote("snipe", 1.5, 0.5, "push", 0.5), "(snipe,raw=1.50,cap=push)", "capped")
	T.eq(R.FlipNote("hunt-carry/lane", 0.64, 0.64, "none", 0.64), "(hunt-carry/lane)", "uncapped")
	T.eq(R.FlipNote("snipe", 1.5, 1.5, "none", 0.64), "(?)", "latch is not the winning desire")
	T.eq(R.FlipNote(nil, nil, nil, nil, 0.5), "(?)", "nothing latched")
	inSample("team_roam:0.50@30" .. R.FlipNote("snipe", 1.5, 0.5, "push", 0.5), "sample FLIP")
	inSample("team_roam:0.64@20" .. R.FlipNote("hunt-carry/lane", 0.64, 0.64, "none", 0.64), "sample FLIP")
end)

-- One think: mode, rule, cap, last hits, engage target valid.
local function run(R, s, steps)
	local lines = {}
	for _, step in ipairs(steps) do
		local line = R.Step(s, step[1], step[2], step[3] or "none", step[4] or "none", step[5] or 0, step[6] or false)
		if line ~= nil then
			lines[#lines + 1] = string.format("[OHA-ROAMSTAT] t=%.0f %s %s", step[1], "medusa", line)
		end
	end
	return lines
end

T.test("roam stats: activations, the hunt switching itself off, cap lift, snipe last hits", function()
	local R = load()
	local s = R.New()
	local lines = run(R, s, {
		-- 1. snipe from farm, last hit 0.4s later; back to farm after 0.5s
		{ 10.0, "farm", "snipe", "none", 5 },
		{ 10.1, "team_roam", "snipe", "none", 5 },
		{ 10.5, "team_roam", "snipe", "none", 6 },
		{ 10.6, "farm", "none", "none", 6 },
		-- 2. hunt on a lane creep from farm; on its first think as the active mode the gate returns NONE
		{ 20.0, "farm", "hunt-carry/lane", "none", 6 },
		{ 20.1, "team_roam", "gate-off", "none", 6, true },
		{ 20.2, "farm", "hunt-carry/lane", "none", 6 },
		-- 3. snipe capped at 0.50 while pushing, uncapped once team roam runs; no last hit in 1.5s
		{ 30.0, "push_tower_mid", "snipe", "push", 6 },
		{ 30.1, "team_roam", "snipe", "none", 6 },
		{ 31.7, "team_roam", "snipe", "none", 6 },
		{ 32.2, "push_tower_mid", "none", "none", 6 },
		-- minute 1: 4. snipe from farm with a last hit, then the attack mode
		{ 70.0, "farm", "snipe", "none", 6 },
		{ 70.1, "team_roam", "snipe", "none", 6 },
		{ 70.3, "team_roam", "snipe", "none", 7 },
		{ 71.5, "attack", "none", "none", 7 },
		-- 5. hunt on a hero for 5s, handed to the attack mode
		{ 80.0, "farm", "hunt-support/hero", "none", 7 },
		{ 80.1, "team_roam", "hunt-support/hero", "none", 7, true },
		{ 85.2, "attack", "none", "none", 7 },
		-- 6. the hunt switching itself off again
		{ 90.0, "farm", "hunt-carry/lane", "none", 7 },
		{ 90.1, "team_roam", "gate-off", "none", 7, true },
		{ 90.2, "farm", "none", "none", 7 },
		-- 7. snipe capped at 0.72 in the laning phase (stays capped: the laning phase is game time)
		{ 100.0, "laning", "snipe", "lane", 7 },
		{ 100.1, "team_roam", "snipe", "lane", 7 },
		{ 100.4, "team_roam", "snipe", "lane", 8 },
		{ 100.9, "laning", "none", "none", 8 },
		{ 120.0, "farm", "none", "none", 8 },
	})
	T.eq(#lines, 2, "one line per finished minute")
	inSample(lines[1] or "?", "minute 0")
	inSample(lines[2] or "?", "minute 1")
end)

T.test("roam stats: a hunt whose target died is not a self-off", function()
	local R = load()
	local s = R.New()
	local lines = run(R, s, {
		{ 1.0, "farm", "hunt-carry/lane", "none", 0 },
		{ 1.1, "team_roam", "gate-off", "none", 0, false },
		{ 1.2, "farm", "none", "none", 1 },
		{ 60.0, "farm", "none", "none", 1 },
	})
	T.ok(lines[1] ~= nil and string.find(lines[1], "huntSelfOff=0 huntGateOff=0 huntGone=1", 1, true), lines[1])
end)

T.test("hunt trace: end reasons and line format", function()
	local _, H = load()
	T.eq(H.EndWhy(true, true, true, 0), "hit", "damaged by the bot")
	T.eq(H.EndWhy(true, true, false, 0.5), nil, "wait for the hit to land")
	T.eq(H.EndWhy(true, true, false, 1.0), "cancel", "no hit in 1s")
	T.eq(H.EndWhy(false, false, false, 1.0), "lost", "target dead or out of sight")
	T.ok(H.IsTraced("npc_dota_hero_nyx_assassin") and not H.IsTraced("npc_dota_hero_medusa"), "traced heroes")
	local h = { spell = "vendetta", targetName = "lich", changes = 1, snipe = 1, other = 0 }
	inSample(H.FormatEnd(306, "nyx_assassin", "hit", 120, 6.0, h), "sample HUNT end")
end)
