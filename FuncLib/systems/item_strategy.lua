-- Team defensive items. Picks Pipe / Crimson Guard / Lotus Orb from the enemy's damage
-- and gives each one to a single bot on the team.
--
-- Every bot builds its item list on its own, so the plan only reads things that are the
-- same for every bot: ally heroes, their roster positions, and the enemy lineup.
-- Every bot then arrives at the same split without sharing state.
local Strategy = {}

local Roles = require(GetScriptDirectory() .. "/FuncLib/data/hero_roles_map").HeroRolesMap

-- Placeholder a hero build puts where its flexible defensive item goes.
Strategy.SLOT = "item_team_aura"

-- Items a team should not double. Their effects do not stack.
local TEAM_ITEMS = {
	item_pipe = true,
	item_crimson_guard = true,
	item_lotus_orb = true,
}
Strategy.TEAM_ITEMS = TEAM_ITEMS

-- Heroes with a flexible defensive slot, and the items that slot may hold.
-- Non-team items here (Halberd, Shiva's) are the fallback once the team items are taken.
local FLEX = {
	npc_dota_hero_bloodseeker = { "item_crimson_guard", "item_pipe" },
	npc_dota_hero_centaur = { "item_crimson_guard", "item_pipe", "item_lotus_orb" },
	npc_dota_hero_doom_bringer = { "item_crimson_guard", "item_pipe", "item_lotus_orb", "item_heavens_halberd" },
	npc_dota_hero_enigma = { "item_pipe", "item_lotus_orb" },
	npc_dota_hero_legion_commander = { "item_crimson_guard", "item_pipe", "item_heavens_halberd" },
	npc_dota_hero_leshrac = { "item_pipe", "item_lotus_orb", "item_crimson_guard" },
	npc_dota_hero_lycan = { "item_pipe", "item_lotus_orb", "item_heavens_halberd", "item_crimson_guard" },
	npc_dota_hero_magnataur = { "item_lotus_orb", "item_heavens_halberd" },
	npc_dota_hero_mars = { "item_pipe", "item_lotus_orb", "item_heavens_halberd", "item_crimson_guard" },
	npc_dota_hero_night_stalker = { "item_pipe", "item_lotus_orb", "item_heavens_halberd", "item_crimson_guard" },
	npc_dota_hero_omniknight = { "item_crimson_guard", "item_pipe", "item_heavens_halberd" },
	npc_dota_hero_pangolier = { "item_pipe", "item_lotus_orb", "item_heavens_halberd", "item_crimson_guard" },
	npc_dota_hero_pudge = { "item_pipe", "item_lotus_orb", "item_crimson_guard" },
	npc_dota_hero_shredder = { "item_crimson_guard", "item_pipe", "item_lotus_orb" },
	npc_dota_hero_undying = { "item_pipe", "item_lotus_orb" },
	npc_dota_hero_venomancer = { "item_pipe", "item_lotus_orb", "item_heavens_halberd" },
	npc_dota_hero_winter_wyvern = { "item_lotus_orb", "item_shivas_guard" },
}

-- Heroes the role table scores wrong for damage type.
local DAMAGE_OVERRIDE = {
	npc_dota_hero_huskar = { magic = 2, physical = 1 },
	npc_dota_hero_storm_spirit = { magic = 2, physical = 1 },
	npc_dota_hero_bristleback = { magic = 0, physical = 2 },
}

-- Offlaner leads team items, then supports, then mid, then carry.
local POS_ORDER = { [3] = 1, [4] = 2, [5] = 3, [2] = 4, [1] = 5 }

-- Urn of Shadows and Spirit Vessel share one heal/damage effect, so one per team.
local URN_FAMILY = { item_urn_of_shadows = true, item_spirit_vessel = true }
-- Roamer first, then hard support.
local URN_POS_ORDER = { [4] = 1, [5] = 2, [3] = 3, [2] = 4, [1] = 5 }
-- Positions whose BotsLib build has Urn or Spirit Vessel. A bot cannot read an ally's
-- build at runtime, so this is kept by hand. Update it when a hero build adds or drops one.
local URN_BUILDS = {
	npc_dota_hero_ancient_apparition = { 4 },
	npc_dota_hero_arc_warden = { 1, 2, 3, 4, 5 },
	npc_dota_hero_bane = { 4 },
	npc_dota_hero_bristleback = { 4, 5 },
	npc_dota_hero_chen = { 4 },
	npc_dota_hero_crystal_maiden = { 4 },
	npc_dota_hero_dazzle = { 4, 5 },
	npc_dota_hero_earthshaker = { 4 },
	npc_dota_hero_earth_spirit = { 1, 2, 4 },
	npc_dota_hero_elder_titan = { 4, 5 },
	npc_dota_hero_furion = { 4, 5 },
	npc_dota_hero_grimstroke = { 4, 5 },
	npc_dota_hero_invoker = { 1, 2, 3, 4, 5 },
	npc_dota_hero_jakiro = { 4 },
	npc_dota_hero_keeper_of_the_light = { 1, 2, 3, 4 },
	npc_dota_hero_largo = { 5 },
	npc_dota_hero_lich = { 5 },
	npc_dota_hero_lina = { 4 },
	npc_dota_hero_lion = { 4 },
	npc_dota_hero_mirana = { 4 },
	npc_dota_hero_muerta = { 4, 5 },
	npc_dota_hero_necrolyte = { 5 },
	npc_dota_hero_night_stalker = { 4, 5 },
	npc_dota_hero_ogre_magi = { 4, 5 },
	npc_dota_hero_oracle = { 4 },
	npc_dota_hero_primal_beast = { 4, 5 },
	npc_dota_hero_sand_king = { 4 },
	npc_dota_hero_tinker = { 5 },
	npc_dota_hero_venomancer = { 4, 5 },
	npc_dota_hero_wisp = { 4 },
	npc_dota_hero_zuus = { 4 },
}

local function TeamKey(team)
	return team == TEAM_RADIANT and "TEAM_RADIANT" or "TEAM_DIRE"
end

-- Returns magic, physical summed over the enemy lineup.
function Strategy.EnemyDamage()
	local magic, physical = 0, 0
	for _, pid in pairs(GetTeamPlayers(GetOpposingTeam()) or {}) do
		local name = GetSelectedHeroName(pid)
		if name ~= nil and name ~= "" then
			local o = DAMAGE_OVERRIDE[name]
			if o ~= nil then
				magic = magic + o.magic
				physical = physical + o.physical
			else
				local r = Roles[name]
				if r ~= nil then
					magic = magic + (r.nuker or 0) + 0.25 * (r.disabler or 0)
					physical = physical + (r.carry or 0) + 0.25 * (r.pusher or 0)
				end
			end
		end
	end
	return magic, physical
end

-- Team items, best first, for this enemy lineup.
function Strategy.RankTeamItems()
	local magic, physical = Strategy.EnemyDamage()
	local total = magic + physical
	if total <= 0 then
		return { "item_lotus_orb", "item_crimson_guard", "item_pipe" }, "unknown"
	end
	local share = magic / total
	if share >= 0.58 then
		return { "item_pipe", "item_lotus_orb", "item_crimson_guard" }, "magic"
	elseif share <= 0.42 then
		return { "item_crimson_guard", "item_lotus_orb", "item_pipe" }, "physical"
	end
	return { "item_lotus_orb", "item_crimson_guard", "item_pipe" }, "mixed"
end

local function Has(list, item)
	for i = 1, #list do
		if list[i] == item then
			return true
		end
	end
	return false
end

-- The one bot ally whose build keeps Urn / Spirit Vessel. Same result in every bot.
function Strategy.UrnOwner()
	local team = GetTeam()
	local roles = require(GetScriptDirectory() .. "/FuncLib/systems/role").RoleAssignment[TeamKey(team)] or {}
	local best, bestOrder, bestIdx = nil, 99, 99
	for idx, pid in pairs(GetTeamPlayers(team) or {}) do
		local name = GetSelectedHeroName(pid)
		local positions = name ~= nil and URN_BUILDS[name] or nil
		if positions ~= nil and IsPlayerBot(pid) then
			local pos = roles[idx] or idx
			if Has(positions, pos) then
				local order = URN_POS_ORDER[pos] or 9
				if order < bestOrder or (order == bestOrder and idx < bestIdx) then
					best, bestOrder, bestIdx = name, order, idx
				end
			end
		end
	end
	return best
end

-- heroName -> item for every bot ally with a flexible slot. Same result in every bot.
function Strategy.TeamPlan()
	local team = GetTeam()
	local key = TeamKey(team)
	local roles = require(GetScriptDirectory() .. "/FuncLib/systems/role").RoleAssignment[key] or {}
	local members = {}
	for idx, pid in pairs(GetTeamPlayers(team) or {}) do
		local name = GetSelectedHeroName(pid)
		if name ~= nil and FLEX[name] ~= nil and IsPlayerBot(pid) then
			local pos = roles[idx] or idx
			members[#members + 1] = { name = name, order = POS_ORDER[pos] or 9, idx = idx }
		end
	end
	table.sort(members, function(x, y)
		if x.order ~= y.order then
			return x.order < y.order
		end
		return x.idx < y.idx
	end)
	local rank, kind = Strategy.RankTeamItems()
	local plan, owner = {}, {}
	for _, m in ipairs(members) do
		local options = FLEX[m.name]
		local pick = nil
		for _, item in ipairs(rank) do
			if owner[item] == nil and Has(options, item) then
				pick = item
				break
			end
		end
		if pick == nil then
			for _, item in ipairs(options) do
				if not TEAM_ITEMS[item] then
					pick = item
					break
				end
			end
		end
		if pick ~= nil then
			plan[m.name] = pick
			if TEAM_ITEMS[pick] then
				owner[pick] = m.name
			end
		end
	end
	return plan, owner, kind
end

-- Fill this bot's placeholder, and drop a fixed team item the plan gave to an ally.
function Strategy.ApplyTeamItems(bot, list)
	if bot == nil or type(list) ~= "table" then
		return list
	end
	local me = bot:GetUnitName()
	local plan, owner, kind = Strategy.TeamPlan()
	local mine = plan[me]
	local urnOwner = Strategy.UrnOwner()
	local dropUrn = urnOwner ~= nil and urnOwner ~= me
	local out, seen = {}, {}
	for i = 1, #list do
		local item = list[i]
		if URN_FAMILY[item] then
			if not dropUrn then
				out[#out + 1] = item
			end
		elseif item == Strategy.SLOT then
			if mine ~= nil and not seen[mine] then
				out[#out + 1] = mine
				seen[mine] = true
			end
		elseif TEAM_ITEMS[item] then
			if (owner[item] == nil or owner[item] == me) and not seen[item] then
				out[#out + 1] = item
				seen[item] = true
			end
		else
			out[#out + 1] = item
		end
	end
	log("[TeamItems] %s enemy=%s pick=%s urn=%s", me, kind, tostring(mine), tostring(urnOwner))
	return out
end

-- True when an ally hero already carries this team item (or one from the Urn family).
function Strategy.AllyOwns(bot, item)
	local family = nil
	if URN_FAMILY[item] then
		-- Upgrading our own Urn into a Vessel is fine.
		if item == "item_spirit_vessel" and bot:FindItemSlot("item_urn_of_shadows") >= 0 then
			return false
		end
		family = URN_FAMILY
	elseif TEAM_ITEMS[item] then
		family = { [item] = true }
	else
		return false
	end
	for _, ally in pairs(GetUnitList(UNIT_LIST_ALLIED_HEROES) or {}) do
		if ally ~= nil and ally ~= bot and not ally:IsIllusion() then
			for name in pairs(family) do
				if ally:FindItemSlot(name) >= 0 then
					return true
				end
			end
		end
	end
	return false
end

return Strategy
