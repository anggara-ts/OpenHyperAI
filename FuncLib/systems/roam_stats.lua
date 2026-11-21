-- Team roam diagnostics (#165): which rule of mode_team_roam_generic.lua set its desire, and what each time team
-- roam became the active mode led to. Diagnostics only: nothing here feeds a decision.
-- Pure apart from ModeName (reads the BOT_MODE_* globals), so Tests/test_roam_stats.lua drives it with plain values.
-- Line formats are parsed by Util/flip-report.js; Tests/data/flip_report_sample.txt pins them for both sides.
local RoamStats = {}

local MODE_NAMES = nil
-- "farm", "team_roam", "push_tower_mid", ... (BOT_MODE_FARM -> "farm"), the names [OHA-FLIP] prints.
function RoamStats.ModeName(mode)
	if MODE_NAMES == nil then
		MODE_NAMES = {}
		for name, id in pairs(_G) do
			if type(name) == "string" and type(id) == "number" and string.sub(name, 1, 9) == "BOT_MODE_" then
				if string.sub(name, 1, 16) ~= "BOT_MODE_DESIRE_" then
					MODE_NAMES[id] = string.lower(string.sub(name, 10))
				end
			end
		end
	end
	return MODE_NAMES[mode] or tostring(mode)
end

-- Which cut team roam's adjustDesire made, read from its outcome: above 0.6 -> 0.5 while pushing, above 0.9 ->
-- 0.72 in the laning phase.
function RoamStats.CapLabel(raw, final)
	if raw == final then
		return "none"
	end
	if final == 0.5 then
		return "push"
	end
	if final == 0.72 then
		return "lane"
	end
	return "other"
end

-- The annotation [OHA-FLIP] adds to a team_roam entry: "(snipe,raw=1.50,cap=push)" when adjustDesire cut it,
-- "(hunt-carry/lane)" when not (raw = the desire printed before it). No spaces: the FLIP parsers split the modes
-- list on whitespace; short, as a FLIP line lists up to ~30 entries. "(?)" when the latched desire is not the one
-- the mode won with.
function RoamStats.FlipNote(why, raw, final, cap, activeDesire)
	if why == nil or raw == nil or final == nil then
		return "(?)"
	end
	if activeDesire ~= nil and math.abs(activeDesire - final) > 0.005 then
		return "(?)"
	end
	if cap == nil or cap == "none" then
		return "(" .. why .. ")"
	end
	return string.format("(%s,raw=%.2f,cap=%s)", why, raw, cap)
end

-- Rules that come from CarryFindTarget / SupportFindTarget (the "hunt": mostly creeps, see the kind after "/").
function RoamStats.IsHunt(why)
	return why ~= nil and string.sub(why, 1, 5) == "hunt-"
end

local function newCounters()
	return {
		acts = 0,
		byRule = {},
		prevMode = {},
		nextMode = {},
		dwell = { 0, 0, 0, 0 },
		huntToAttack = 0,
		huntSelfOff = 0,
		huntGateOff = 0,
		huntGone = 0,
		capLift = 0,
		snipeGot = 0,
		snipeTries = 0,
		snipeByPrev = {},
		creepGot = 0,
		creepTries = 0,
	}
end

function RoamStats.New()
	return { prevMode = nil, act = nil, snipe = nil, minute = nil, c = newCounters() }
end

local function inc(map, key)
	map[key] = (map[key] or 0) + 1
end

-- "farm:3,push_tower_mid:2" (most first, then by name), "-" when empty.
local function mapText(map, value)
	local keys = {}
	for key in pairs(map) do
		keys[#keys + 1] = key
	end
	if #keys == 0 then
		return "-"
	end
	local function count(key)
		local v = map[key]
		return type(v) == "table" and v.tries or v
	end
	table.sort(keys, function(a, b)
		if count(a) ~= count(b) then
			return count(a) > count(b)
		end
		return a < b
	end)
	local parts = {}
	for i = 1, #keys do
		parts[i] = keys[i] .. ":" .. (value and value(map[keys[i]]) or tostring(map[keys[i]]))
	end
	return table.concat(parts, ",")
end

-- Seconds a team roam activation lasted -> dwell bucket: 0 (under 1s), 1, 2-3, 4+.
function RoamStats.DwellBucket(seconds)
	local s = math.floor(seconds)
	if s <= 0 then
		return 1
	elseif s == 1 then
		return 2
	elseif s <= 3 then
		return 3
	end
	return 4
end

-- The [OHA-ROAMSTAT] fields after "t=<t> <hero> ".
function RoamStats.Format(minute, c)
	return string.format(
		"min=%d acts=%d byRule=%s prevMode=%s nextMode=%s dwell0=%d dwell1=%d dwell2_3=%d dwell4p=%d huntToAttack=%d huntSelfOff=%d huntGateOff=%d huntGone=%d capLift=%d snipeLH=%d/%d snipeLHbyPrev=%s creepLH=%d/%d",
		minute,
		c.acts,
		mapText(c.byRule),
		mapText(c.prevMode),
		mapText(c.nextMode),
		c.dwell[1],
		c.dwell[2],
		c.dwell[3],
		c.dwell[4],
		c.huntToAttack,
		c.huntSelfOff,
		c.huntGateOff,
		c.huntGone,
		c.capLift,
		c.snipeGot,
		c.snipeTries,
		mapText(c.snipeByPrev, function(v)
			return v.got .. "/" .. v.tries
		end),
		c.creepGot,
		c.creepTries
	)
end

-- A snipe that won team roam as a mode (a Valve-run mode, see RoamRules.SnipePath) resolves once a last hit follows
-- (true) or after 1.5s (false), or when a new one starts before it resolved (force: no last hit). nil: pending.
local function resolvePending(pending, now, lastHits, force)
	if pending == nil then
		return nil
	end
	local got = lastHits ~= nil and pending.lh ~= nil and lastHits > pending.lh
	if got or now - pending.t > 1.5 or force then
		return got
	end
	return nil
end

local function resolveSnipe(s, now, lastHits, force)
	local snipe = s.snipe
	local got = resolvePending(snipe, now, lastHits, force)
	if got == nil then
		return
	end
	local c = s.c
	local byPrev = c.snipeByPrev[snipe.prev] or { got = 0, tries = 0 }
	c.snipeByPrev[snipe.prev] = byPrev
	byPrev.tries = byPrev.tries + 1
	c.snipeTries = c.snipeTries + 1
	if got then
		byPrev.got = byPrev.got + 1
		c.snipeGot = c.snipeGot + 1
	end
	s.snipe = nil
end

-- The last-hit overlay's tries (FuncLib/systems/last_hit_overlay.lua): a try is the overlay ordering hits on one
-- unit, without a mode change. Game 064 counted an open try as a miss as soon as the overlay moved to another unit,
-- and a deny never counted (only GetLastHits was read). Now a try stays open until its unit dies or the overlay has
-- not ordered it for TRY_DROP seconds:
--   got   the unit died and our score (last hits + denies) went up since the try started; each point is claimed
--         by one try only (two open tries, one hit: one got, one miss)
--   miss  the unit died, no new point
--   drop  the unit lived and the overlay stopped ordering it (another mode or a newer offer took the bot)
-- A snipe counts in snipeLH (as the snipe activations did before), a hunt on a creep in creepLH; a drop is a try
-- without a hit, as an activation without a last hit in 1.5s was.
local TRY_DROP = 3
RoamStats.TRY_DROP = TRY_DROP

-- The overlay ordered a hit on key (the unit handle) this think. Returns the try (the overlay keeps notes on it:
-- held, release, capped) and whether it is new.
--   why    "snipe" (team roam's snipe) or the hunt's rule ("hunt-carry/lane", ...)
--   mode   the active mode's name (the snipe's previous mode in snipeLHbyPrev)
--   score  bot:GetLastHits() + bot:GetDenies() now
function RoamStats.OverlayTry(s, now, key, why, mode, score)
	s.tries = s.tries or {}
	for _, try in ipairs(s.tries) do
		if try.key == key then
			try.last = now
			return try, false
		end
	end
	local try = { key = key, why = why, mode = mode or "?", t = now, last = now, score = score, held = 0 }
	s.tries[#s.tries + 1] = try
	return try, true
end

local function countTry(s, try, got)
	local c = s.c
	if try.why == "snipe" then
		local byPrev = c.snipeByPrev[try.mode] or { got = 0, tries = 0 }
		c.snipeByPrev[try.mode] = byPrev
		byPrev.tries = byPrev.tries + 1
		c.snipeTries = c.snipeTries + 1
		if got then
			byPrev.got = byPrev.got + 1
			c.snipeGot = c.snipeGot + 1
		end
	else
		c.creepTries = c.creepTries + 1
		if got then
			c.creepGot = c.creepGot + 1
		end
	end
end

-- Every overlay think. isDead(key): the try's unit is dead (or gone). Returns the tries that resolved this think,
-- each with .result ("got" / "miss" / "drop"), or nil.
function RoamStats.OverlayResolve(s, now, score, isDead)
	local tries = s.tries
	if tries == nil or #tries == 0 then
		return nil
	end
	local done = nil
	local i = 1
	while i <= #tries do
		local try = tries[i]
		local result = nil
		if isDead(try.key) then
			local base = math.max(try.score or 0, s.claimed or -1)
			if score ~= nil and score > base then
				result = "got"
				s.claimed = base + 1
			else
				result = "miss"
			end
		elseif now - try.last > TRY_DROP then
			result = "drop"
		end
		if result ~= nil then
			try.result = result
			countTry(s, try, result == "got")
			table.remove(tries, i)
			done = done or {}
			done[#done + 1] = try
		else
			i = i + 1
		end
	end
	return done
end

-- Once per team roam GetDesire (every think, whatever mode is active).
--   mode         the active mode's name this think ("team_roam" while team roam runs)
--   why, cap     the rule team roam's desire came from this think, and adjustDesire's cut (CapLabel)
--   lastHits     bot:GetLastHits() + bot:GetDenies() (a deny snipe counts too)
--   targetValid  team roam's engage target still alive, visible and attackable (only read while team roam runs)
-- Activation = the active mode turns into team_roam; the rule that won it is the one from the think before.
-- Returns the fields of a finished minute's [OHA-ROAMSTAT] line once per game minute, else nil.
function RoamStats.Step(s, now, mode, why, cap, lastHits, targetValid)
	local line = nil
	local minute = math.floor(now / 60)
	if s.minute == nil then
		s.minute = minute
	elseif minute ~= s.minute then
		line = RoamStats.Format(s.minute, s.c)
		s.minute = minute
		s.c = newCounters()
	end
	local c = s.c
	-- A snipe is worth it when a last hit follows within 1.5s. Before #165's fix a snipe was a team roam activation
	-- (kept for the Valve-run modes); otherwise it is an overlay try (OverlayTry / OverlayResolve).
	local newSnipe = mode == "team_roam" and s.prevMode ~= "team_roam" and s.winWhy == "snipe"
	resolveSnipe(s, now, lastHits, newSnipe)
	local roam = "team_roam"
	if mode == roam and s.prevMode ~= roam then
		local winWhy = s.winWhy or "?"
		local prev = s.prevMode or "?"
		s.act = { t = now, why = winWhy, prev = prev, cap = s.winCap or "none", thinks = 0 }
		c.acts = c.acts + 1
		inc(c.byRule, winWhy)
		inc(c.prevMode, prev)
		if winWhy == "snipe" then
			s.snipe = { t = now, lh = s.winLastHits or lastHits, prev = prev }
		end
	end
	local act = s.act
	if mode == roam and act ~= nil then
		act.thinks = act.thinks + 1
		if act.thinks == 1 then
			if RoamStats.IsHunt(act.why) then
				-- Hypothesis (a) of #165: the hunt only runs while farm/push/... is the active mode, so on its
				-- first think as the active mode it returns NONE through that gate.
				if why == "gate-off" and targetValid then
					act.gateOff = true
				elseif not targetValid then
					act.gone = true
				end
			end
			-- Hypothesis (b): it won capped (pushing / laning phase) and the same rule, now uncapped, carries on.
			if act.cap ~= "none" and why == act.why and cap == "none" then
				act.capLift = true
			end
		end
	end
	if mode ~= roam and s.prevMode == roam and act ~= nil then
		local bucket = RoamStats.DwellBucket(now - act.t)
		c.dwell[bucket] = c.dwell[bucket] + 1
		inc(c.nextMode, mode)
		if RoamStats.IsHunt(act.why) then
			if mode == "attack" then
				c.huntToAttack = c.huntToAttack + 1
			end
			if act.gateOff then
				c.huntGateOff = c.huntGateOff + 1
				if act.thinks <= 1 then
					c.huntSelfOff = c.huntSelfOff + 1
				end
			end
			if act.gone then
				c.huntGone = c.huntGone + 1
			end
		end
		if act.capLift then
			c.capLift = c.capLift + 1
		end
		s.act = nil
	end
	if mode ~= roam then
		s.winWhy, s.winCap, s.winLastHits = why, cap, lastHits
	end
	s.prevMode = mode
	return line
end

return RoamStats
