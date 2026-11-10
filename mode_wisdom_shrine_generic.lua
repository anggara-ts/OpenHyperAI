-- Wisdom shrine mode. Takes the XP shrine near the 7:00 marks (3:30 turbo) when active.
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

function GetDesire()
	if ShouldSkipBotThink(GetBot()) then
		return 0
	end
	local desire, loc, kind, eta = MapObj.ConsiderObjectiveDesire(bot)
	if kind ~= "wisdom" or desire <= 0 or loc == nil then
		targetLoc = nil
		return BOT_MODE_DESIRE_NONE
	end
	targetLoc = loc
	MatchTrace.Decide(
		bot,
		"wisdom",
		string.format("%d,%d", math.floor(loc.x), math.floor(loc.y)),
		string.format("eta=%.0f desire=%.2f lvl=%d", eta or 0, desire, bot:GetLevel()),
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
	MapObj.ThinkObjective(bot, loc, "wisdom")
end
