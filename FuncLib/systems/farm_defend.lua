-- Decides whether a farming bot should answer a tower/rax/ancient defense call.
local Utils = require(GetScriptDirectory() .. "/FuncLib/func_utils")

local FarmDefend = {}

local INNER_TOWERS = {
	TOWER_TOP_2,
	TOWER_MID_2,
	TOWER_BOT_2,
	TOWER_TOP_3,
	TOWER_MID_3,
	TOWER_BOT_3,
}

local TOWERS_BY_LANE = {
	[LANE_TOP] = { TOWER_TOP_1, TOWER_TOP_2, TOWER_TOP_3 },
	[LANE_MID] = { TOWER_MID_1, TOWER_MID_2, TOWER_MID_3 },
	[LANE_BOT] = { TOWER_BOT_1, TOWER_BOT_2, TOWER_BOT_3 },
}

local BARRACKS_BY_LANE = {
	[LANE_TOP] = { BARRACKS_TOP_MELEE, BARRACKS_TOP_RANGED },
	[LANE_MID] = { BARRACKS_MID_MELEE, BARRACKS_MID_RANGED },
	[LANE_BOT] = { BARRACKS_BOT_MELEE, BARRACKS_BOT_RANGED },
}

local DECISION_CHAT_COOLDOWN = 18

local function DefendPing()
	local states = Utils.Utils and Utils.Utils.GameStates
	return states and states.defendPings or nil
end

local function GameStates()
	Utils.Utils = Utils.Utils or {}
	Utils.Utils.GameStates = Utils.Utils.GameStates or {}
	return Utils.Utils.GameStates
end

local function EnemyCreepsNear(location, radius)
	local count = 0
	local creeps = GetUnitList(UNIT_LIST_ENEMY_CREEPS)
	if creeps == nil then
		return 0
	end
	for _, creep in pairs(creeps) do
		if
			creep ~= nil
			and creep:IsAlive()
			and not creep:IsIllusion()
			and GetUnitToLocationDistance(creep, location) <= radius
		then
			count = count + 1
		end
	end
	return count
end

local function FrontTower(team, lane)
	local ids = TOWERS_BY_LANE[lane]
	if ids == nil then
		return nil, nil
	end
	for tier, id in ipairs(ids) do
		local tower = GetTower(team, id)
		if tower ~= nil and tower:IsAlive() then
			return tower, tier
		end
	end
	return nil, nil
end

-- Furthest living objective on a lane: tower, then rax, then base towers, then ancient.
local function FrontObjective(team, lane)
	local tower, tier = FrontTower(team, lane)
	if tower ~= nil then
		return tower, tier, "tower"
	end

	local raxIds = BARRACKS_BY_LANE[lane]
	if raxIds ~= nil then
		for _, id in ipairs(raxIds) do
			local rax = GetBarracks(team, id)
			if rax ~= nil and rax:IsAlive() then
				return rax, 3, "rax"
			end
		end
	end

	local base1 = GetTower(team, TOWER_BASE_1)
	if base1 ~= nil and base1:IsAlive() then
		return base1, 4, "base"
	end
	local base2 = GetTower(team, TOWER_BASE_2)
	if base2 ~= nil and base2:IsAlive() then
		return base2, 4, "base"
	end

	local ancient = GetAncient(team)
	if ancient ~= nil and ancient:IsAlive() then
		return ancient, 5, "ancient"
	end

	return nil, nil, nil
end

local function ObjectiveThreatened(objective, tier)
	local hp = objective:GetHealth() / math.max(1, objective:GetMaxHealth())
	local heroes = #Utils.GetEnemiesNearLoc(objective:GetLocation(), 1600)
	local creeps = EnemyCreepsNear(objective:GetLocation(), 800)
	return hp < 0.55
		or (heroes >= 1 and (tier >= 2 or hp < 0.75 or creeps >= 2))
		or (creeps >= 3 and hp < 0.8)
		or (tier >= 4 and heroes >= 1)
		or (tier >= 5 and heroes >= 1)
end

-- True when this bot should drop farming for the current defend call.
function FarmDefend.ShouldLeaveFarm(bot)
	local ping = DefendPing()
	if ping == nil or GameTime() - (ping.pingedTime or 0) > 5 then
		return false
	end

	local team = GetTeam()
	for _, id in pairs(INNER_TOWERS) do
		local tower = GetTower(team, id)
		if tower ~= nil and tower:IsAlive() and #Utils.GetEnemiesNearLoc(tower:GetLocation(), 1200) >= 2 then
			return true
		end
	end

	local ancient = GetAncient(team)
	if ancient ~= nil and ancient:IsAlive() then
		local nearAncient = #Utils.GetEnemiesNearLoc(ancient:GetLocation(), 1600)
		if nearAncient >= 1 then
			return true
		end
	end

	local objective, tier = FrontObjective(team, ping.lane)
	if objective == nil then
		return false
	end

	if not ObjectiveThreatened(objective, tier) then
		return false
	end

	local position = Utils.GetPosition(bot)
	local hasTp = Utils.Item.GetItemCharges(bot, "item_tpscroll") >= 1
	local distance = GetUnitToLocationDistance(bot, objective:GetLocation())
	local hp = objective:GetHealth() / math.max(1, objective:GetMaxHealth())
	local heroes = #Utils.GetEnemiesNearLoc(objective:GetLocation(), 1600)

	if position == 1 then
		return tier >= 2 or hp < 0.4 or heroes >= 2
	end
	if position >= 3 then
		return hasTp or distance <= 3500 or hp < 0.45 or tier >= 2
	end
	return tier >= 2 or hp < 0.45 or hasTp or distance <= 3000
end

-- One bot may announce a real refusal. The caller checks the final farm desire first.
function FarmDefend.ClaimAnnounce()
	local ping = DefendPing()
	if ping == nil or GameTime() - (ping.pingedTime or 0) > 5 then
		return false
	end
	local states = GameStates()
	if DotaTime() - (states.defendIgnoreChatTime or -100) < 15 then
		return false
	end
	states.defendIgnoreChatTime = DotaTime()
	return true
end

-- One bot may announce leaving farm for defend/push (rate-limited team-wide).
function FarmDefend.ClaimDecisionChat(kind)
	local states = GameStates()
	local key = "decisionChatTime_" .. tostring(kind or "generic")
	if DotaTime() - (states[key] or -100) < DECISION_CHAT_COOLDOWN then
		return false
	end
	if DotaTime() - (states.decisionChatTime or -100) < 8 then
		return false
	end
	states[key] = DotaTime()
	states.decisionChatTime = DotaTime()
	return true
end

return FarmDefend
