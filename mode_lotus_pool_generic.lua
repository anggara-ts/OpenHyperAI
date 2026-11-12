-- Lotus pool mode. Contests pools near the 3:00 marks (1:30 turbo) when a lotus grows.
if
	GetBot():IsInvulnerable()
	or not GetBot():IsHero()
	or not string.find(GetBot():GetUnitName(), "hero")
	or GetBot():IsIllusion()
then
	return
end

local bot = GetBot()
local Utils = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local MapObj = require(GetScriptDirectory() .. "/FuncLib/systems/map_objectives")
local MatchTrace = require(GetScriptDirectory() .. "/FuncLib/systems/match_trace")

local targetLoc = nil
local dbgAt = -100
local dbgWhy = ""
local dbgLoc = nil

local function ModeTag(mode)
	if mode == BOT_MODE_NONE then return "none" end
	if mode == BOT_MODE_LANING then return "laning" end
	if mode == BOT_MODE_ATTACK then return "attack" end
	if mode == BOT_MODE_ROAM then return "roam" end
	if mode == BOT_MODE_RETREAT then return "retreat" end
	if mode == BOT_MODE_FARM then return "farm" end
	if mode == BOT_MODE_WARD then return "ward" end
	if mode == BOT_MODE_RUNE then return "rune" end
	if mode == BOT_MODE_TEAM_ROAM then return "team_roam" end
	if BOT_MODE_LOTUS_POOL ~= nil and mode == BOT_MODE_LOTUS_POOL then return "lotus" end
	if BOT_MODE_WISDOM_SHRINE ~= nil and mode == BOT_MODE_WISDOM_SHRINE then return "wisdom" end
	if BOT_MODE_OUTPOST ~= nil and mode == BOT_MODE_OUTPOST then return "outpost" end
	return "m" .. tostring(mode)
end

local function Num(v, fmt)
	if type(v) ~= "number" then
		return "?"
	end
	return string.format(fmt, v)
end

local function FamangoCount()
	local n = 0
	for slot = 0, 8 do
		local it = bot:GetItemInSlot(slot)
		if it ~= nil and it.GetName ~= nil then
			local name = it:GetName()
			if name == "item_famango" or name == "item_great_famango" or name == "item_greater_famango" then
				local c = it.GetCurrentCharges and it:GetCurrentCharges() or 1
				if type(c) ~= "number" or c < 1 then
					c = 1
				end
				n = n + c
			end
		end
	end
	return n
end

-- Grep [OHA-LOTUS]. One line a second during the spawn window, plus a line when the reason changes.
local function LotusDbg(desire, kind)
	local ok, err = pcall(function()
		local t = DotaTime()
		local interval = MapObj.LotusInterval()
		local toNext = MapObj.SecondsToNextMark(interval)
		local since = interval - toNext
		local window = toNext <= 40 or (t >= interval - 1 and since <= 50)
		local dist = bot._lotusDist
		if not window and (dist == nil or dist > 1600) then
			return
		end
		local why = bot._lotusWhy or "?"
		local pos = bot:GetLocation()
		local moved = -1
		if dbgLoc ~= nil then
			local dx = pos.x - dbgLoc.x
			local dy = pos.y - dbgLoc.y
			moved = math.sqrt(dx * dx + dy * dy)
		end
		local dt = t - dbgAt
		if dt < 0.25 or (why == dbgWhy and dt < 1) then
			return
		end
		local stuck = (dt >= 0.8 and type(dist) == "number" and dist <= 900 and moved >= 0 and moved < 40) and 1 or 0
		dbgAt = t
		dbgWhy = why
		dbgLoc = pos
		local g = bot._lotusDbg or {}
		local hero = string.gsub(bot:GetUnitName() or "?", "npc_dota_hero_", "")
		local team = GetTeam() == TEAM_RADIANT and "r" or "d"
		local role = Utils.GetPosition and Utils.GetPosition(bot) or "?"
		local mode = bot:GetActiveMode()
		local modeDes = bot:GetActiveModeDesire() or 0
		local shown = (kind == "lotus" and desire) or 0
		print(string.format(
			"[OHA-LOTUS] %s/%s t=%.1f xy=%.0f,%.0f pos=%s mode=%s/%.2f des=%.2f obj=%s why=%s dist=%s eta=%s beside=%s lost=%s in=%s room=%s hp=%s walk=%s pools=%s count=%s skip=%s toNext=%.0f since=%.0f foes=%s/%s danger=%s mango=%d do=%s moved=%.0f stuck=%d",
			hero, team, t, pos.x, pos.y, tostring(role),
			ModeTag(mode), modeDes, shown, tostring(kind or "none"), why,
			Num(g.dist or dist, "%.0f"), Num(g.eta, "%.0f"),
			tostring(g.beside or 0), tostring(g.lost or 0), tostring(g.inwin or 0), tostring(g.room or 0),
			Num(g.hp, "%.2f"), Num(g.walk, "%.0f"),
			tostring(g.pools ~= nil and g.pools or "?"), g.count == nil and "?" or tostring(g.count),
			Num(g.skip, "%.0f"),
			toNext, since,
			tostring(g.foes ~= nil and g.foes or "?"), tostring(g.friends ~= nil and g.friends or "?"),
			tostring(g.danger or 0),
			FamangoCount(),
			tostring(bot._lotusDo or "-"),
			moved, stuck
		))
	end)
	if not ok then
		print("[OHA-LOTUS] err " .. tostring(err))
	end
end

function GetDesire()
	if ShouldSkipBotThink(GetBot()) then
		return 0
	end
	local desire, loc, kind, eta = MapObj.ConsiderObjectiveDesire(bot)
	LotusDbg(desire, kind)
	if kind ~= "lotus" or desire <= 0 or loc == nil then
		targetLoc = nil
		return BOT_MODE_DESIRE_NONE
	end
	targetLoc = loc
	MatchTrace.Decide(
		bot,
		"lotus",
		string.format("%d,%d", math.floor(loc.x), math.floor(loc.y)),
		string.format("eta=%.0f desire=%.2f", eta or 0, desire),
		8
	)
	return desire
end

function OnStart() end

function OnEnd()
	targetLoc = nil
end

function Think()
	if not bot:IsAlive() or Utils.CanNotUseAction and Utils.CanNotUseAction(bot) then
		return
	end
	local loc = targetLoc
	if loc == nil then
		local _, found = MapObj.ConsiderObjectiveDesire(bot)
		loc = found
	end
	MapObj.ThinkObjective(bot, loc, "lotus")
end
