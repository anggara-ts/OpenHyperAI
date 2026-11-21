-- #52: the per-think costs games 059 and 062 named in [OHA-PERFSUM] (item_tpscroll, MatchTrace.Tick) are only paid
-- where they change something, and they still give the same answers.
local T = ...

-- Counts GetUnitList calls by list type, passing them on to the stub.
local function countUnitLists(extraCreeps)
	local stubList = GetUnitList
	local calls = {}
	GetUnitList = function(listType)
		calls[listType] = (calls[listType] or 0) + 1
		if listType == UNIT_LIST_ENEMY_CREEPS then
			return extraCreeps or {}
		end
		return stubList(listType)
	end
	return calls
end

local function creepAt(x, y)
	return T.stub.newUnit({ name = "npc_dota_creep_badguys_melee", team = TEAM_DIRE, loc = Vector(x, y, 0) })
end

T.test("Utils.BaseUnderCreeps: 2 enemy creeps within 1600 of our Ancient", function()
	T.stub.reset({ hero = "npc_dota_hero_lich" })
	local Utils = require(GetScriptDirectory() .. "/FuncLib/systems/utils")
	local bot = GetBot()
	local ancient = GetAncient(GetTeam())
	local at = ancient:GetLocation()
	countUnitLists({ creepAt(at.x + 300, at.y), creepAt(at.x, at.y + 500) })
	T.eq(Utils.BaseUnderCreeps(bot), true, "two creeps at the Ancient")
	countUnitLists({ creepAt(at.x + 300, at.y), creepAt(at.x + 4000, at.y) })
	T.eq(Utils.BaseUnderCreeps(bot), false, "one at the Ancient, one far")
	countUnitLists({})
	T.eq(Utils.BaseUnderCreeps(bot), false, "no creeps")
end)

T.test("item_tpscroll reads the enemy creeps only near the fountain", function()
	T.stub.reset({ hero = "npc_dota_hero_lich", time = 600 })
	local Usage = dofile("ability_item_usage_generic.lua")
	local bot = GetBot()
	local rule = Usage.ConsiderItemDesire.item_tpscroll
	-- Away from the fountain: the base-creep check is not needed and must not run.
	bot.DistanceFromFountain = function()
		return 5000
	end
	local calls = countUnitLists({})
	rule(nil)
	T.eq(calls[UNIT_LIST_ENEMY_CREEPS], nil, "no enemy creep read 5000 from the fountain")
	-- At the fountain, healthy, no enemy near: the check runs (and two creeps at the Ancient hold the TP).
	bot.DistanceFromFountain = function()
		return 300
	end
	-- Past the rule's 0.3s recheck (a "no TP" answer is kept that long).
	T.stub.time = T.stub.time + 1
	local at = GetAncient(GetTeam()):GetLocation()
	calls = countUnitLists({ creepAt(at.x + 300, at.y), creepAt(at.x, at.y + 500) })
	local desire = rule(nil)
	T.ok((calls[UNIT_LIST_ENEMY_CREEPS] or 0) >= 1, "enemy creeps read at the fountain")
	T.ok(desire == nil or desire <= 0, "no fountain TP while creeps are at the Ancient")
end)

-- Game 063: item_tpscroll was still the biggest item rule (23.8s). A "no TP" answer is kept 0.3s per bot,
-- except in danger (hit by an enemy hero within 2s, HP under 40%).
T.test("item_tpscroll: a no-TP answer is kept 0.3s, the rule runs every think in danger", function()
	T.stub.reset({ hero = "npc_dota_hero_lich", time = 600 })
	local Usage = dofile("ability_item_usage_generic.lua")
	local bot = GetBot()
	local rule = Usage.ConsiderItemDesire.item_tpscroll
	bot.DistanceFromFountain = function()
		return 300
	end
	local hitByHero = false
	bot.WasRecentlyDamagedByAnyHero = function()
		return hitByHero
	end
	-- Two creeps at our Ancient hold the fountain TP: the answer is "no TP".
	local at = GetAncient(GetTeam()):GetLocation()
	local calls = countUnitLists({ creepAt(at.x + 300, at.y), creepAt(at.x, at.y + 500) })
	local desire = rule(nil)
	T.ok(desire == nil or desire <= 0, "no TP")
	T.eq(calls[UNIT_LIST_ENEMY_CREEPS], 1, "first call runs the rule")
	T.stub.time = T.stub.time + 0.1
	rule(nil)
	T.eq(calls[UNIT_LIST_ENEMY_CREEPS], 1, "0.1s later: kept")
	T.stub.time = T.stub.time + 0.3
	rule(nil)
	T.eq(calls[UNIT_LIST_ENEMY_CREEPS], 2, "0.4s later: runs again")
	hitByHero = true
	T.stub.time = T.stub.time + 0.05
	rule(nil)
	T.eq(calls[UNIT_LIST_ENEMY_CREEPS], 3, "hit by a hero 0.05s later: runs again")
end)

T.test("MatchTrace.Markers builds the lineup only until the game marker is sent", function()
	T.stub.reset({ hero = "npc_dota_hero_lich" })
	local MatchTrace = require(GetScriptDirectory() .. "/FuncLib/systems/match_trace")
	local stubName = GetSelectedHeroName
	local reads = 0
	GetSelectedHeroName = function(playerId)
		reads = reads + 1
		return stubName(playerId)
	end
	MatchTrace.Markers()
	T.eq(reads, 10, "the first call names all ten heroes")
	local printed = 0
	for _, line in ipairs(T.stub.printed) do
		if string.find(line, "[OHA-MATCH] game", 1, true) then
			printed = printed + 1
		end
	end
	T.eq(printed, 1, "the game marker printed once")
	MatchTrace.Markers()
	MatchTrace.Markers()
	T.eq(reads, 10, "later calls read no hero name")
end)
