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

-- One think: mode, rule, cap, score (last hits + denies), engage target valid, and the last-hit overlay: (7th) the
-- rule of an overlay hit ordered this think on (8th) a unit key, and (9th) a unit key that died this think.
local function run(R, s, steps)
	local lines = {}
	for _, step in ipairs(steps) do
		local dead = step[9]
		R.OverlayResolve(s, step[1], step[5] or 0, function(key)
			return key == dead
		end)
		if step[7] ~= nil then
			R.OverlayTry(s, step[1], step[8] or "unit", step[7], step[2], step[5] or 0)
		end
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
		-- 8. a hunt on a lane creep by the last-hit overlay (no mode change), last hit 0.4s later
		{ 110.0, "farm", "overlay-hunt-carry/lane", "none", 8, false, "hunt-carry/lane", "c8" },
		{ 110.4, "farm", "none", "none", 9, false, nil, nil, "c8" },
		{ 120.0, "farm", "none", "none", 9 },
	})
	T.eq(#lines, 2, "one line per finished minute")
	inSample(lines[1] or "?", "minute 0")
	inSample(lines[2] or "?", "minute 1")
end)

T.test("roam stats: overlay tries resolve on their unit's death, a deny counts, no forced miss", function()
	local R = load()
	local s = R.New()
	local lines = run(R, s, {
		-- a snipe from farm with a last hit
		{ 1.0, "farm", "none", "none", 0, false, "snipe", "a" },
		{ 1.3, "farm", "none", "none", 1, false, nil, nil, "a" },
		-- a snipe from laning whose creep walks off: a drop after 3s without an order
		{ 5.0, "laning", "none", "none", 1, false, "snipe", "b" },
		{ 8.1, "laning", "none", "none", 1 },
		-- two snipes open at once (the offer moved to the next creep): both die, one point: one got, one miss, and
		-- the first is not counted as a miss when the second starts (game 064)
		{ 10.0, "farm", "none", "none", 1, false, "snipe", "c" },
		{ 10.1, "farm", "none", "none", 1, false, "snipe", "d" },
		{ 10.4, "farm", "none", "none", 2, false, nil, nil, "c" },
		{ 10.6, "farm", "none", "none", 2, false, nil, nil, "d" },
		-- creep hunts: a deny (score = last hits + denies) and one killed by someone else
		{ 20.0, "push_tower_mid", "none", "none", 2, false, "hunt-support/deny", "e" },
		{ 20.2, "push_tower_mid", "none", "none", 3, false, nil, nil, "e" },
		{ 30.0, "farm", "none", "none", 3, false, "hunt-carry/lane", "f" },
		{ 30.5, "farm", "none", "none", 3, false, nil, nil, "f" },
		{ 60.0, "farm", "none", "none", 3 },
	})
	local line = lines[1] or "?"
	T.ok(string.find(line, "acts=0 ", 1, true) ~= nil, "no team roam activation: " .. line)
	T.ok(string.find(line, "snipeLH=2/4 snipeLHbyPrev=farm:2/3,laning:0/1 creepLH=1/2", 1, true) ~= nil, line)
end)

T.test("roam stats: one overlay try per unit, its result", function()
	local R = load()
	local s = R.New()
	local try, isNew = R.OverlayTry(s, 1, "a", "snipe", "farm", 5)
	T.ok(isNew, "new")
	local again, isNew2 = R.OverlayTry(s, 1.2, "a", "snipe", "farm", 5)
	T.ok(again == try and not isNew2, "the same try")
	T.eq(
		R.OverlayResolve(s, 1.3, 5, function()
			return false
		end),
		nil,
		"open"
	)
	local done = R.OverlayResolve(s, 1.4, 6, function()
		return true
	end)
	T.ok(done ~= nil and done[1] == try and try.result == "got", "got")
	T.eq(#s.tries, 0, "closed")
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
	-- EndWhy(alive, seen, waited, deadAfter, hitToDeath, hit)
	T.eq(H.EndWhy(true, true, 0.5, nil, nil, true), nil, "hit: wait the kill window out")
	T.eq(H.EndWhy(true, true, 3.1, nil, nil, true), "hit", "damaged by the bot, still alive")
	T.eq(H.EndWhy(true, true, 1.0, nil, nil, false), nil, "wait for the hit to land")
	T.eq(H.EndWhy(true, true, 3.0, nil, nil, false), "cancel", "no hit in the window")
	T.eq(H.EndWhy(true, false, 3.0, nil, nil, false), "lost", "out of sight")
	-- Game 063: Clinkz's reveals that killed Nevermore, Furion and Shadow Fiend were counted as lost.
	T.eq(H.EndWhy(false, false, 0.8, 0.8, 0.1, true), "kill", "died 0.8s after the reveal")
	T.eq(H.EndWhy(false, false, 2.5, 2.5, nil, false), "kill", "died in the window, by an ally")
	T.eq(H.EndWhy(false, false, 0, -5, 0.5, false), "kill", "died to the hunter's hit before the modifier ended")
	T.eq(H.EndWhy(false, false, 0, -5, nil, false), "lost", "died before the reveal, not by the hunter")
	T.eq(H.EndWhy(false, false, 0, -5, 8, false), "lost", "the hunter's hit was long before")
	T.ok(H.IsTraced("npc_dota_hero_nyx_assassin") and not H.IsTraced("npc_dota_hero_medusa"), "traced heroes")
	local h = { spell = "vendetta", targetName = "lich", changes = 1, snipe = 1, other = 0, deathCheck = "deaths" }
	inSample(H.FormatEnd(306, "nyx_assassin", "hit", 120, 6.0, h), "sample HUNT end")
end)

-- A fake unit: only what HuntTrace.Tick reads.
local function fakeUnit(name, team, x)
	local u = { name = name, team = team, alive = true, visible = true, modifiers = {}, _loc = Vector(x, 0, 0) }
	function u:GetUnitName()
		return self.name
	end
	function u:GetPlayerID()
		return self.pid
	end
	-- null: a stale handle (game 065: the target's handle after it left vision).
	function u:IsNull()
		return self.null == true
	end
	function u:IsIllusion()
		return false
	end
	function u:IsAlive()
		return self.alive
	end
	function u:IsHero()
		return string.find(self.name, "npc_dota_hero_", 1, true) ~= nil
	end
	function u:GetTeam()
		return self.team
	end
	function u:CanBeSeen()
		return self.visible
	end
	function u:HasModifier(m)
		return self.modifiers[m] == true
	end
	function u:GetAttackTarget()
		return self.attackTarget
	end
	function u:GetTarget()
		return self.target
	end
	function u:WasRecentlyDamagedByHero(_, _)
		return self.damaged == true
	end
	return u
end

local function printed(what)
	local found = {}
	for _, line in ipairs(T.stub.printed) do
		if string.find(line, what, 1, true) then
			found[#found + 1] = line
		end
	end
	return found
end

T.test("hunt trace: Vendetta from the cast to the hit, with a mode change and a snipe", function()
	local _, H = load()
	local nyx = fakeUnit("npc_dota_hero_nyx_assassin", 2, 0)
	local lich = fakeUnit("npc_dota_hero_lich", 3, 1800)
	local creep = fakeUnit("npc_dota_creep_badguys_melee", 3, 500)
	local vendetta = "modifier_nyx_assassin_vendetta"
	T.stub.time = 300
	H.Tick(nyx, "outpost")
	T.eq(nyx._huntTrace, nil, "no modifier: no hunt")
	nyx.modifiers[vendetta] = true
	H.Tick(nyx, "outpost")
	T.eq(nyx._huntTrace, nil, "escape Vendetta (no canVendettaKill): not traced")
	nyx.modifiers[vendetta] = nil
	H.Tick(nyx, "outpost")
	nyx.canVendettaKill, nyx.vendettaTarget = true, lich
	nyx.modifiers[vendetta] = true
	H.Tick(nyx, "outpost")
	T.ok(nyx._huntTrace ~= nil, "kill Vendetta traced")
	T.eq(#printed("start spell=vendetta target=lich mode=outpost dist=1800"), 1, "start line")
	T.stub.time = 302
	nyx._loc = Vector(900, 0, 0)
	H.Tick(nyx, "team_roam")
	T.eq(#printed("mode-change from=outpost to=team_roam dist=900"), 1, "mode-change line")
	H.NoteSnipe(nyx, creep)
	H.NoteSnipe(nyx, creep)
	T.eq(#printed("interrupt by=snipe unit=npc_dota_creep_badguys_melee"), 1, "one snipe line per hunt")
	nyx.attackTarget = creep
	H.Tick(nyx, "team_roam")
	T.eq(#printed("interrupt by=other unit=npc_dota_creep_badguys_melee"), 1, "attack on another unit")
	-- Ticks come every think; one under 3s apart, so no "died" gap.
	T.stub.time = 304
	H.Tick(nyx, "team_roam")
	T.stub.time = 306
	nyx._loc = Vector(1680, 0, 0)
	nyx.attackTarget = lich
	nyx.modifiers[vendetta] = nil
	lich.damaged = true
	H.Tick(nyx, "team_roam")
	T.ok(nyx._huntTrace ~= nil, "hit: waits the kill window")
	lich.damaged = false
	T.stub.time = 308
	H.Tick(nyx, "team_roam")
	T.stub.time = 309.1
	H.Tick(nyx, "team_roam")
	T.eq(nyx._huntTrace, nil, "hunt over")
	local ends = printed("end why=hit dist=120 lasted=9.1 spell=vendetta target=lich changes=1 snipe=2 other=1")
	T.eq(#ends, 1, "end line: " .. table.concat(printed("end why"), " / "))
end)

T.test("hunt trace: a charge that misses, a gap, Clinkz only with a hero target", function()
	local _, H = load()
	local sb = fakeUnit("npc_dota_hero_spirit_breaker", 2, 0)
	local lich = fakeUnit("npc_dota_hero_lich", 3, 3500)
	local charge = "modifier_spirit_breaker_charge_of_darkness"
	T.stub.time = 400
	sb._chargeTarget = lich
	sb.modifiers[charge] = true
	H.Tick(sb, "outpost")
	T.stub.time = 403
	sb.modifiers[charge] = nil
	H.Tick(sb, "outpost")
	T.ok(sb._huntTrace ~= nil, "waits up to 1s for the hit")
	T.stub.time = 405
	H.Tick(sb, "farm")
	T.stub.time = 406.1
	H.Tick(sb, "farm")
	T.eq(#printed("end why=cancel"), 1, "no hit: cancel")
	-- A tick gap of 3s+ during a hunt: the bot died (desires are not asked while dead).
	sb.modifiers[charge] = true
	H.Tick(sb, "outpost")
	T.stub.time = 410
	H.Tick(sb, "outpost")
	T.eq(#printed("end why=died"), 1, "gap: died")
	local clinkz = fakeUnit("npc_dota_hero_clinkz", 2, 0)
	local creep = fakeUnit("npc_dota_creep_badguys_melee", 3, 500)
	clinkz.modifiers.modifier_clinkz_wind_walk = true
	clinkz.target = creep
	H.Tick(clinkz, "farm")
	T.eq(clinkz._huntTrace, nil, "walk with a creep target: no hunt")
	clinkz.target = lich
	H.Tick(clinkz, "retreat")
	T.eq(clinkz._huntTrace, nil, "retreating: no hunt")
	H.Tick(clinkz, "attack")
	T.ok(clinkz._huntTrace ~= nil and clinkz._huntTrace.spell == "skeleton_walk", "found the hero during the walk")
end)

-- The scoreboard's death counts (GetHeroDeaths) for the hunt tests; restore() puts the stub's back.
local function scoreboard()
	local deaths = {}
	local original = GetHeroDeaths
	GetHeroDeaths = function(pid)
		return deaths[pid] or 0
	end
	return deaths, function()
		GetHeroDeaths = original
	end
end

T.test("hunt trace: a death needs the scoreboard", function()
	local _, H = load()
	T.eq(H.TargetDead(2, 3), true, "deaths went up")
	T.eq(H.TargetDead(2, 2), false, "same deaths: alive, whatever the handle says")
	T.eq(H.TargetDead(nil, 2), false, "unread at the start: never dead")
	T.eq(select(2, H.TargetDead(2, 2)), "deaths", "how")
	T.eq(select(2, H.TargetDead(nil, nil)), "unread", "how, unread")
end)

T.test("hunt trace: a reveal that kills is a kill, not lost (game 063)", function()
	local _, H = load()
	local deaths, restore = scoreboard()
	local clinkz = fakeUnit("npc_dota_hero_clinkz", 2, 0)
	local sf = fakeUnit("npc_dota_hero_nevermore", 3, 900)
	sf.pid = 7
	deaths[7] = 1
	local walk = "modifier_clinkz_wind_walk"
	T.stub.time = 900
	clinkz.target = sf
	clinkz.modifiers[walk] = true
	H.Tick(clinkz, "attack")
	T.ok(clinkz._huntTrace ~= nil, "hunt on")
	-- The reveal: the walk ends with the attack; the arrow lands, Nevermore dies 0.7s later.
	T.stub.time = 902
	clinkz.modifiers[walk] = nil
	sf.damaged = true
	H.Tick(clinkz, "attack")
	T.stub.time = 902.7
	sf.alive, sf.visible = false, false
	deaths[7] = 2
	H.Tick(clinkz, "attack")
	restore()
	T.eq(clinkz._huntTrace, nil, "hunt over")
	T.eq(#printed("end why=kill"), 1, "kill: " .. table.concat(printed("end why"), " / "))
	T.ok(string.find(printed("end why=kill")[1] or "", "death=deaths", 1, true) ~= nil, "read from the scoreboard")
	T.eq(#printed("end why=lost"), 0, "not lost")
	local h = {
		spell = "skeleton_walk",
		targetName = "nevermore",
		changes = 0,
		snipe = 0,
		other = 0,
		deathCheck = "deaths",
	}
	inSample(H.FormatEnd(903, "clinkz", "kill", 180, 2.7, h), "sample HUNT kill")
end)

T.test("hunt trace: a target that teleports or turns invisible is not a kill (game 064)", function()
	local _, H = load()
	local deaths, restore = scoreboard()
	local clinkz = fakeUnit("npc_dota_hero_clinkz", 2, 0)
	local puck = fakeUnit("npc_dota_hero_puck", 3, 700)
	puck.pid = 8
	deaths[8] = 3
	local walk = "modifier_clinkz_wind_walk"
	T.stub.time = 745
	clinkz.target = puck
	clinkz.modifiers[walk] = true
	H.Tick(clinkz, "attack")
	-- The reveal hits Puck; she teleports home and the handle reads not alive, but the scoreboard has no death.
	T.stub.time = 748
	clinkz.modifiers[walk] = nil
	puck.damaged = true
	H.Tick(clinkz, "attack")
	T.stub.time = 749
	puck.alive, puck.visible, puck.damaged = false, false, false
	H.Tick(clinkz, "attack")
	T.ok(clinkz._huntTrace ~= nil, "not ended as a kill")
	T.stub.time = 751.1
	H.Tick(clinkz, "attack")
	restore()
	T.eq(#printed("end why=kill"), 0, "no kill")
	T.eq(#printed("end why=hit"), 1, "hit (damaged after the reveal): " .. table.concat(printed("end why"), " / "))
end)

T.test("hunt trace: the kill window stays open while the hunter keeps hitting (game 065)", function()
	local _, H = load()
	-- EndWhy(alive, seen, waited, deadAfter, hitToDeath, hit, sinceHit)
	T.eq(H.EndWhy(true, false, 3.1, nil, nil, true, 0.2), nil, "still hitting: wait")
	T.eq(H.EndWhy(true, false, 3.1, nil, nil, true, 1.5), "hit", "stopped hitting: hit")
	T.eq(H.EndWhy(true, true, 6.0, nil, nil, true, 0.2), "hit", "the longer window is capped")
	T.eq(H.EndWhy(true, false, 3.1, nil, nil, false, nil), "lost", "never hit, out of sight: lost")
	T.eq(H.KeepRead(6, nil), 6, "a failed read keeps the last good one")
	T.eq(H.KeepRead(6, 7), 7, "a new read")
	T.eq(H.KeepRead(nil, nil), nil, "never read")
end)

T.test("hunt trace: a stale target handle, the hit on its new handle, a kill read by player ID (game 065)", function()
	local _, H = load()
	local deaths, restore = scoreboard()
	local nyx = fakeUnit("npc_dota_hero_nyx_assassin", 3, 0)
	local hoodwink = fakeUnit("npc_dota_hero_hoodwink", 2, 600)
	hoodwink.pid = 9
	deaths[9] = 6
	local vendetta = "modifier_nyx_assassin_vendetta"
	T.stub.time = 3072
	nyx.canVendettaKill, nyx.vendettaTarget = true, hoodwink
	nyx.modifiers[vendetta] = true
	H.Tick(nyx, "attack")
	T.ok(nyx._huntTrace ~= nil and nyx._huntTrace.pid == 9, "player ID kept at the start")
	-- The strike at 3074; then the stored handle goes stale and Nyx attacks a second handle of the same hero.
	T.stub.time = 3074
	nyx.modifiers[vendetta] = nil
	hoodwink.damaged = true
	H.Tick(nyx, "attack")
	T.stub.time = 3075
	hoodwink.null = true
	local again = fakeUnit("npc_dota_hero_hoodwink", 2, 300)
	again.pid, again.damaged = 9, true
	nyx.attackTarget = again
	H.Tick(nyx, "attack")
	T.eq(#printed("interrupt by=other"), 0, "the same hero on a new handle is not another unit")
	T.stub.time = 3076
	H.Tick(nyx, "attack")
	T.stub.time = 3077.1
	H.Tick(nyx, "attack")
	T.ok(nyx._huntTrace ~= nil, "still hitting her: the window stays open")
	T.stub.time = 3077.3
	again.alive, again.visible = false, false
	deaths[9] = 7
	H.Tick(nyx, "attack")
	restore()
	T.eq(nyx._huntTrace, nil, "hunt over")
	local ends = printed("end why=kill")
	T.eq(#ends, 1, "kill: " .. table.concat(printed("end why"), " / "))
	T.ok(string.find(ends[1] or "", "death=deaths refound=1", 1, true) ~= nil, "scoreboard read, handle refound")
end)

T.test("hunt trace: no player ID on the handle: found by hero name, the death still read", function()
	local _, H = load()
	local deaths, restore = scoreboard()
	-- The stub's enemy team (Dire: GetOpposingTeam for the stub bot) has Zeus as player 16.
	local clinkz = fakeUnit("npc_dota_hero_clinkz", 2, 0)
	local zeus = fakeUnit("npc_dota_hero_zuus", 3, 2400)
	deaths[16] = 2
	local walk = "modifier_clinkz_wind_walk"
	T.stub.time = 2645
	clinkz.target = zeus
	clinkz.modifiers[walk] = true
	H.Tick(clinkz, "farm")
	T.ok(clinkz._huntTrace ~= nil and clinkz._huntTrace.pid == 16, "player ID by name")
	-- Zeus leaves vision; the walk ends; an ally kills him out of sight 1s later.
	T.stub.time = 2647
	zeus.alive, zeus.visible = false, false
	clinkz.modifiers[walk] = nil
	H.Tick(clinkz, "farm")
	T.stub.time = 2648
	deaths[16] = 3
	H.Tick(clinkz, "farm")
	restore()
	local ends = printed("end why=kill")
	T.eq(#ends, 1, "kill out of sight: " .. table.concat(printed("end why"), " / "))
	T.ok(string.find(ends[1] or "", "death=deaths", 1, true) ~= nil, "read from the scoreboard")
end)
