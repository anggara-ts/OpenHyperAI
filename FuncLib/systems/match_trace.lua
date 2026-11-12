-- Match trace. [OHA-DEV] console print (+ optional file append).
-- Files: C:/Users/ANGGARA/Documents/OpenHyperAI/match-trace-p<id>.log
-- Toggle: Customize.MatchTrace = true/false
-- Extra detail: Customize.MatchTraceVerbose = true
-- File writes are disabled: Dota bot sandbox usually blocks io.open.
local MatchTrace = {}

local enabled = true
local verbose = true
local perfEnabled = false
-- Keep WriteFile code, but do not attempt disk I/O (it does not work in-game).
local WRITE_TO_FILE = false
local settingsOk, settings = pcall(require, GetScriptDirectory() .. "/FuncLib/systems/custom_loader")
if settingsOk and type(settings) == "table" then
	if settings.MatchTrace == false then
		enabled = false
	end
	if settings.MatchTraceVerbose == false then
		verbose = false
	end
	if settings.MatchTraceWriteFile == true then
		WRITE_TO_FILE = true
	end
	-- Perf can run without full MatchTrace decision spam.
	if settings.MatchTracePerf == true then
		perfEnabled = true
	end
end

local version = "unknown"
local versionOk, versionMod = pcall(require, GetScriptDirectory() .. "/Customize/version")
if versionOk and type(versionMod) == "table" and versionMod.number then
	version = versionMod.number
end

local fileReady = {}
local lastKindAt = {}
local LOG_DIR = "C:/Users/ANGGARA/Documents/OpenHyperAI/"

local function ModeName(mode)
	local names = {}
	local function put(key, name)
		if key ~= nil then
			names[key] = name
		end
	end
	put(BOT_MODE_NONE, "none")
	put(BOT_MODE_LANING, "laning")
	put(BOT_MODE_ATTACK, "attack")
	put(BOT_MODE_ROAM, "roam")
	put(BOT_MODE_RETREAT, "retreat")
	put(BOT_MODE_SECRET_SHOP, "secret_shop")
	put(BOT_MODE_SIDE_SHOP, "side_shop")
	put(BOT_MODE_PUSH_TOWER_TOP, "push_top")
	put(BOT_MODE_PUSH_TOWER_MID, "push_mid")
	put(BOT_MODE_PUSH_TOWER_BOT, "push_bot")
	put(BOT_MODE_DEFEND_TOWER_TOP, "defend_top")
	put(BOT_MODE_DEFEND_TOWER_MID, "defend_mid")
	put(BOT_MODE_DEFEND_TOWER_BOT, "defend_bot")
	put(BOT_MODE_ASSEMBLE, "assemble")
	put(BOT_MODE_TEAM_ROAM, "team_roam")
	put(BOT_MODE_FARM, "farm")
	put(BOT_MODE_DEFEND_ALLY, "defend_ally")
	put(BOT_MODE_EVASIVE_MANEUVERS, "evasive")
	put(BOT_MODE_ROSHAN, "roshan")
	put(BOT_MODE_ITEM, "item")
	put(BOT_MODE_WARD, "ward")
	put(BOT_MODE_RUNE, "rune")
	if BOT_MODE_WATCHER ~= nil and mode == BOT_MODE_WATCHER then
		return "watcher"
	end
	if BOT_MODE_WISDOM_SHRINE ~= nil and mode == BOT_MODE_WISDOM_SHRINE then
		return "wisdom"
	end
	if BOT_MODE_LOTUS_POOL ~= nil and mode == BOT_MODE_LOTUS_POOL then
		return "lotus"
	end
	return names[mode] or ("mode" .. tostring(mode))
end

local function ActionName(action)
	if action == BOT_ACTION_TYPE_IDLE then
		return "idle"
	end
	if action == BOT_ACTION_TYPE_MOVE_TO then
		return "move"
	end
	if action == BOT_ACTION_TYPE_ATTACK then
		return "attack"
	end
	if action == BOT_ACTION_TYPE_USE_ABILITY then
		return "ability"
	end
	return tostring(action)
end

local function HeroTag(bot)
	local name = bot:GetUnitName() or "unknown"
	name = string.gsub(name, "npc_dota_hero_", "")
	local team = GetTeam() == TEAM_RADIANT and "radiant" or "dire"
	local pos = bot.theRole or bot.assignedRole or "?"
	if bot.GetAssignedLane and type(GetPosition) ~= "function" then
		-- keep role from bot fields
	end
	return string.format("%s %s pos=%s", name, team, tostring(pos))
end

function MatchTrace.LogPath(bot)
	local id = bot and bot.GetPlayerID and bot:GetPlayerID() or "x"
	return LOG_DIR .. "match-trace-p" .. tostring(id) .. ".log"
end

local function WriteFile(bot, line)
	-- Disabled: file logging does not work under the bot sandbox.
	if not WRITE_TO_FILE then
		return "console-only"
	end
	if io == nil or io.open == nil then
		return "console-only"
	end
	local id = bot:GetPlayerID()
	local path = MatchTrace.LogPath(bot)
	local mode = "a"
	if not fileReady[id] then
		fileReady[id] = true
		if DotaTime() < 90 then
			mode = "w"
		end
	end
	local ok, file = pcall(io.open, path, mode)
	if ok and file ~= nil then
		file:write(line, "\n")
		file:close()
		return path
	end
	-- Fallback: script directory (works if not under Program Files).
	local fallback = GetScriptDirectory() .. "/match-trace-p" .. tostring(id) .. ".log"
	ok, file = pcall(io.open, fallback, mode)
	if ok and file ~= nil then
		file:write(line, "\n")
		file:close()
		return fallback
	end
	return "console-only"
end

function MatchTrace.Enabled()
	return enabled
end

function MatchTrace.Verbose()
	return verbose
end

function MatchTrace.PerfEnabled()
	return perfEnabled
end

-- Lightweight RealTime() profiler. Enable: Customize.MatchTracePerf = true
-- Logs spikes + periodic top-N averages to console ([OHA-PERF]).
local perfStats = {}
local perfNextReport = 0
local PERF_SPIKE_MS = 2.5
local PERF_REPORT_EVERY = 10.0

function MatchTrace.PerfSample(label, elapsedSec)
	if not perfEnabled or label == nil or elapsedSec == nil then
		return
	end
	local ms = elapsedSec * 1000.0
	local s = perfStats[label]
	if s == nil then
		s = { n = 0, sum = 0, max = 0 }
		perfStats[label] = s
	end
	s.n = s.n + 1
	s.sum = s.sum + ms
	if ms > s.max then
		s.max = ms
	end
	if ms >= PERF_SPIKE_MS then
		print(string.format("[OHA-PERF spike] %s %.2fms t=%.1f", tostring(label), ms, DotaTime()))
	end
	local now = RealTime and RealTime() or DotaTime()
	if now >= perfNextReport then
		perfNextReport = now + PERF_REPORT_EVERY
		local rows = {}
		for name, st in pairs(perfStats) do
			if st.n > 0 then
				rows[#rows + 1] = {
					name = name,
					avg = st.sum / st.n,
					max = st.max,
					n = st.n,
					sum = st.sum,
				}
			end
		end
		table.sort(rows, function(a, b)
			return a.sum > b.sum
		end)
		local parts = {}
		for i = 1, math.min(8, #rows) do
			local r = rows[i]
			parts[#parts + 1] =
				string.format("%s avg=%.2f max=%.2f n=%d", r.name, r.avg, r.max, r.n)
		end
		if #parts > 0 then
			print(string.format("[OHA-PERF top] t=%.1f %s", DotaTime(), table.concat(parts, " | ")))
		end
		-- Soft reset max so spikes stay meaningful; keep avg over window via sum/n reset.
		for _, st in pairs(perfStats) do
			st.n = 0
			st.sum = 0
			st.max = 0
		end
	end
end

function MatchTrace.PerfWrap(label, fn, fallback)
	if not perfEnabled then
		return fn
	end
	return function(...)
		local t0 = RealTime and RealTime() or nil
		local ok, a, b, c = pcall(fn, ...)
		if t0 ~= nil then
			MatchTrace.PerfSample(label, (RealTime() - t0))
		end
		if ok then
			return a, b, c
		end
		print(string.format("[OHA-PERF err] %s %s", tostring(label), tostring(a)))
		return fallback
	end
end

function MatchTrace.Event(bot, kind, detail)
	if not enabled or bot == nil then
		return
	end
	local line = string.format(
		"[OHA-DEV %s] t=%.1f %s %s",
		kind,
		DotaTime(),
		HeroTag(bot),
		detail or ""
	)
	print(line)
	WriteFile(bot, line)
end

-- Rate-limited decision log. Same kind+key within cooldownSeconds is skipped.
function MatchTrace.Decide(bot, kind, key, detail, cooldownSeconds)
	if not enabled or bot == nil then
		return
	end
	cooldownSeconds = cooldownSeconds or 2.0
	local id = bot:GetPlayerID()
	lastKindAt[id] = lastKindAt[id] or {}
	local stamp = tostring(kind) .. "|" .. tostring(key or "")
	local now = DotaTime()
	if lastKindAt[id][stamp] and now - lastKindAt[id][stamp] < cooldownSeconds then
		return
	end
	lastKindAt[id][stamp] = now
	MatchTrace.Event(bot, kind, detail)
end

function MatchTrace.Item(bot, itemName, reason, detail)
	MatchTrace.Decide(
		bot,
		"item",
		itemName .. ":" .. tostring(reason),
		string.format("%s reason=%s %s", tostring(itemName), tostring(reason), detail or ""),
		1.5
	)
end

function MatchTrace.Buy(bot, itemName, detail)
	MatchTrace.Decide(
		bot,
		"buy",
		itemName,
		string.format("%s %s", tostring(itemName), detail or ""),
		0.5
	)
end

local function StandingStillOk(bot, mode)
	if bot:IsChanneling() then
		return true
	end
	if bot:DistanceFromFountain() < 1500 then
		return true
	end
	return mode == BOT_MODE_SECRET_SHOP or mode == BOT_MODE_WARD or mode == BOT_MODE_RUNE or mode == BOT_MODE_ITEM
end

-- Game boundary lines for split-console.js. Printed even when tracing is off.
-- Module state is per script VM, so a team can print the same marker more than once.
local markerSent = {}
local nextEndCheck = 0

local function TeamTag(team)
	return team == TEAM_RADIANT and "radiant" or "dire"
end

local function Lineup(team)
	local names = {}
	for _, pid in ipairs(GetTeamPlayers(team) or {}) do
		local name = string.gsub(GetSelectedHeroName(pid) or "", "npc_dota_hero_", "")
		names[#names + 1] = name ~= "" and name or "?"
	end
	return table.concat(names, ",")
end

function MatchTrace.MatchMarker(phase, detail)
	if markerSent[phase] then
		return
	end
	markerSent[phase] = true
	print(string.format(
		"[OHA-MATCH] %s team=%s t=%.1f version=%s %s",
		phase,
		TeamTag(GetTeam()),
		DotaTime(),
		version,
		detail or ""
	))
end

local function AncientDead(team)
	local ancient = GetAncient(team)
	return ancient == nil or ancient:GetHealth() <= 0
end

function MatchTrace.Markers()
	MatchTrace.MatchMarker(
		"game",
		string.format("radiant=%s dire=%s", Lineup(TEAM_RADIANT), Lineup(TEAM_DIRE))
	)
	if markerSent["end"] or DotaTime() < nextEndCheck then
		return
	end
	nextEndCheck = DotaTime() + 1
	local gs = GetGameState()
	if gs ~= GAME_STATE_GAME_IN_PROGRESS and gs ~= GAME_STATE_POST_GAME then
		return
	end
	local radiantDead = AncientDead(TEAM_RADIANT)
	local direDead = AncientDead(TEAM_DIRE)
	if gs ~= GAME_STATE_POST_GAME and not radiantDead and not direDead then
		return
	end
	local winner = "unknown"
	if radiantDead and not direDead then
		winner = "dire"
	elseif direDead and not radiantDead then
		winner = "radiant"
	end
	MatchTrace.MatchMarker("end", "winner=" .. winner)
end

function MatchTrace.Tick(bot)
	if bot ~= nil and bot:IsHero() then
		MatchTrace.Markers()
	end
	if not enabled or bot == nil or not bot:IsHero() then
		return
	end
	local now = DotaTime()
	local state = bot._trace
	if state == nil then
		state = {
			loc = bot:GetLocation(),
			locAt = now,
			mode = bot:GetActiveMode(),
			modeAt = now,
			flips = {},
			nextTick = now,
			nextBeat = now + 5,
			dead = not bot:IsAlive(),
			started = false,
		}
		bot._trace = state
	end
	if now < state.nextTick then
		return
	end
	state.nextTick = now + 0.5
	if not state.started then
		state.started = true
		local path = MatchTrace.LogPath(bot)
		MatchTrace.Event(
			bot,
			"start",
			string.format(
				"version=%s verbose=%s file=%s",
				version,
				tostring(verbose),
				path
			)
		)
	end
	-- Post-game end marker (once).
	local gs = GetGameState()
	if gs == GAME_STATE_POST_GAME and not state.ended then
		state.ended = true
		MatchTrace.Event(bot, "end", "game_over")
		return
	end
	if not bot:IsAlive() then
		if not state.dead then
			state.dead = true
			local loc = bot:GetLocation()
			MatchTrace.Event(
				bot,
				"life",
				string.format("died mode=%s xy=%d,%d", ModeName(state.mode), math.floor(loc.x), math.floor(loc.y))
			)
		end
		return
	end
	if state.dead then
		state.dead = false
		state.loc = bot:GetLocation()
		state.locAt = now
		MatchTrace.Event(bot, "life", "respawned")
	end
	local loc = bot:GetLocation()
	local mode = bot:GetActiveMode()
	local desire = bot:GetActiveModeDesire() or 0
	local moved = GetUnitToLocationDistance(bot, state.loc)
	if mode ~= state.mode then
		state.flips[#state.flips + 1] = { t = now, mode = mode }
		MatchTrace.Event(
			bot,
			"mode",
			string.format(
				"%s -> %s desire=%.2f held=%.1fs",
				ModeName(state.mode),
				ModeName(mode),
				desire,
				now - state.modeAt
			)
		)
		state.mode = mode
		state.modeAt = now
	end
	local kept = {}
	local flipNames = {}
	for i = 1, #state.flips do
		if now - state.flips[i].t <= 10 then
			kept[#kept + 1] = state.flips[i]
			flipNames[#flipNames + 1] = ModeName(state.flips[i].mode)
		end
	end
	state.flips = kept
	if #kept >= 6 and now >= (state.nextFlipLog or 0) then
		state.nextFlipLog = now + 15
		MatchTrace.Event(bot, "weird", string.format("mode-flip %dx/10s %s", #kept, table.concat(flipNames, ",")))
	end
	if moved > 200 then
		state.loc = loc
		state.locAt = now
	end
	local stillFor = now - state.locAt
	local action = bot:GetCurrentActionType()
	local passable = IsLocationPassable(loc)
	if stillFor > 4 and action == BOT_ACTION_TYPE_MOVE_TO and not passable and now >= (state.nextStuckLog or 0) then
		state.nextStuckLog = now + 15
		MatchTrace.Event(
			bot,
			"stuck",
			string.format(
				"impassable mode=%s for=%.0fs xy=%d,%d",
				ModeName(mode),
				stillFor,
				math.floor(loc.x),
				math.floor(loc.y)
			)
		)
	elseif stillFor > 15 and not StandingStillOk(bot, mode) and now >= (state.nextStuckLog or 0) then
		state.nextStuckLog = now + 15
		local target = bot:GetAttackTarget()
		local targetName = "none"
		if target ~= nil and target.GetUnitName ~= nil then
			targetName = target:GetUnitName()
		end
		MatchTrace.Event(
			bot,
			"stuck",
			string.format(
				"still mode=%s for=%.0fs moved=%d act=%s tgt=%s xy=%d,%d",
				ModeName(mode),
				stillFor,
				math.floor(moved),
				ActionName(action),
				targetName,
				math.floor(loc.x),
				math.floor(loc.y)
			)
		)
	end
	local beatEvery = verbose and 15 or 30
	if now >= state.nextBeat then
		state.nextBeat = now + beatEvery
		local target = bot:GetAttackTarget()
		local targetName = "none"
		if target ~= nil and target.GetUnitName ~= nil then
			targetName = target:GetUnitName()
		end
		local allies = bot:GetNearbyHeroes(1600, false, BOT_MODE_NONE) or {}
		local enemies = bot:GetNearbyHeroes(1600, true, BOT_MODE_NONE) or {}
		MatchTrace.Event(
			bot,
			"beat",
			string.format(
				"mode=%s desire=%.2f held=%.0fs hp=%.2f mp=%.2f act=%s tgt=%s allies=%d enemies=%d gold=%d xy=%d,%d fountain=%d",
				ModeName(mode),
				desire,
				now - state.modeAt,
				bot:GetHealth() / math.max(1, bot:GetMaxHealth()),
				bot:GetMana() / math.max(1, bot:GetMaxMana()),
				ActionName(action),
				targetName,
				#allies,
				#enemies,
				bot:GetGold(),
				math.floor(loc.x),
				math.floor(loc.y),
				math.floor(bot:DistanceFromFountain())
			)
		)
	end
end

return MatchTrace
