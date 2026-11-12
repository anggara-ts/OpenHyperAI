-- Team-wide kill advantage for push and Roshan.
-- A dead enemy raises both. An early return to the fountain (buyback) drops push.
local KillWindow = {}

local enemies = {}
local pushLockUntil = -999
local pushLogged = {}
local roshLogged = {}
local LOCK_SECONDS = 20

local function Now()
	return DotaTime()
end

local function TeamLabel()
	if GetTeam() == TEAM_DIRE then
		return "dire"
	end
	return "radiant"
end

local function ShouldLog()
	local me = GetBot()
	if me == nil or me.IsBot == nil or not me:IsBot() then
		return false
	end
	for i = 1, 5 do
		local member = GetTeamMember(i)
		if member ~= nil and member.IsBot ~= nil and member:IsBot() then
			return member == me
		end
	end
	return false
end

local function ShortName(name)
	if type(name) ~= "string" or name == "" then
		return "?"
	end
	return string.gsub(name, "npc_dota_hero_", "")
end

local function HeroName(pid)
	local ok, name = pcall(GetSelectedHeroName, pid)
	if ok then
		return ShortName(name)
	end
	return tostring(pid)
end

local function Fountain(team)
	if team == TEAM_RADIANT then
		return Vector(-7172, -6652, 384)
	end
	return Vector(6982, 6422, 392)
end

local function Dist(a, b)
	if a == nil or b == nil or a.x == nil or b.x == nil then
		return 99999
	end
	local dx = a.x - b.x
	local dy = a.y - b.y
	return math.sqrt(dx * dx + dy * dy)
end

local function LastSeen(pid)
	local info = GetHeroLastSeenInfo(pid)
	if info == nil then
		return nil
	end
	return info[1]
end

local function FindEnemy(pid)
	local list = GetUnitList(UNIT_LIST_ENEMY_HEROES)
	if list == nil then
		return nil
	end
	for _, hero in pairs(list) do
		if
			hero ~= nil
			and hero.IsHero ~= nil
			and hero:IsHero()
			and hero.GetPlayerID ~= nil
			and hero:GetPlayerID() == pid
		then
			local illusion = false
			if hero.IsIllusion ~= nil then
				local ok, value = pcall(function()
					return hero:IsIllusion()
				end)
				illusion = ok and value == true
			end
			if not illusion then
				return hero
			end
		end
	end
	return nil
end

local function RespawnOf(pid)
	local hero = FindEnemy(pid)
	if hero ~= nil and hero.GetRespawnTime ~= nil then
		local ok, rt = pcall(function()
			return hero:GetRespawnTime()
		end)
		if ok and type(rt) == "number" and rt > 5 and rt < 140 then
			return rt, true
		end
	end
	return 30, false
end

local function Print(line)
	pcall(print, line)
end

local function Empty()
	return { fresh = 0, buyback = false, lockLeft = 0, names = "" }
end

local function TickRaw()
	local now = Now()
	local enemyTeam = GetOpposingTeam()
	local fountain = Fountain(enemyTeam)
	local fresh = 0
	local names = {}
	for _, pid in pairs(GetTeamPlayers(enemyTeam)) do
		local alive = IsHeroAlive(pid)
		local slot = enemies[pid]
		if slot == nil then
			enemies[pid] = { alive = alive, name = HeroName(pid) }
		else
			if slot.name == nil then
				slot.name = HeroName(pid)
			end
			if slot.alive and not alive then
				local seen = LastSeen(pid)
				local respawnFor, known = RespawnOf(pid)
				slot.alive = false
				slot.deathAt = now
				slot.respawnFor = respawnFor
				slot.respawnKnown = known
				slot.deathLoc = seen and seen.location or nil
				slot.pending = false
				pushLockUntil = -999
				if ShouldLog() then
					Print(string.format(
						"[OHA-FIGHT] t=%.0f %s death %s respawn=%.0fs known=%s push+rosh up",
						now,
						TeamLabel(),
						slot.name,
						respawnFor,
						tostring(known)
					))
				end
			elseif not slot.alive and alive then
				slot.alive = true
				slot.backAt = now
				slot.pending = true
			end
			if slot.alive and slot.pending and slot.backAt ~= nil and now <= slot.backAt + 8 then
				local elapsed = slot.deathAt and (slot.backAt - slot.deathAt) or 999
				local seen = LastSeen(pid)
				local seenFresh = seen ~= nil and seen.time_since_seen ~= nil and seen.time_since_seen < 2
				local atFountain = seenFresh and Dist(seen.location, fountain) < 2500
				local atDeath = seenFresh and slot.deathLoc ~= nil and Dist(seen.location, slot.deathLoc) < 1500
				local earlyByTimer = slot.respawnKnown and elapsed + 6 < (slot.respawnFor or 30)
				local earlyByFountain = atFountain and elapsed < 10
				if earlyByTimer or earlyByFountain or (atDeath and elapsed < 8) then
					local kind = "buyback"
					if atDeath and not atFountain and not earlyByFountain then
						kind = "aegis"
					elseif not atFountain and not earlyByTimer then
						kind = "early-respawn"
					end
					-- Aegis means the kill did not stick, so the push raise is over.
					-- Only a fountain return (or a timer-proven early respawn) is a buyback.
					if kind ~= "aegis" then
						pushLockUntil = now + LOCK_SECONDS
						if ShouldLog() then
							Print(string.format(
								"[OHA-FIGHT] t=%.0f %s %s %s deadFor=%.0fs push down %ds",
								now,
								TeamLabel(),
								kind,
								slot.name,
								elapsed,
								LOCK_SECONDS
							))
						end
					elseif ShouldLog() then
						Print(string.format(
							"[OHA-FIGHT] t=%.0f %s aegis %s deadFor=%.0fs push stays",
							now,
							TeamLabel(),
							slot.name,
							elapsed
						))
					end
					slot.pending = false
				elseif seenFresh then
					slot.pending = false
				end
			elseif slot.pending and slot.backAt ~= nil and now > slot.backAt + 8 then
				slot.pending = false
			end
			if not slot.alive and slot.deathAt ~= nil and now < slot.deathAt + (slot.respawnFor or 30) then
				fresh = fresh + 1
				names[#names + 1] = slot.name
			end
		end
	end
	local buyback = now < pushLockUntil
	return {
		fresh = fresh,
		buyback = buyback,
		lockLeft = buyback and (pushLockUntil - now) or 0,
		names = table.concat(names, ","),
	}
end

function KillWindow.Tick()
	local ok, snap = pcall(TickRaw)
	if not ok or type(snap) ~= "table" then
		return Empty()
	end
	return snap
end

function KillWindow.LogPush(bot, lane, was, floor, snap, hp, allies, enemiesAlive)
	if bot == nil or bot.GetPlayerID == nil then
		return
	end
	local now = Now()
	local id = bot:GetPlayerID()
	if pushLogged[id] ~= nil and now < pushLogged[id] then
		return
	end
	pushLogged[id] = now + 4
	Print(string.format(
		"[OHA-FIGHT] t=%.0f %s push %s lane=%s was=%.2f floor=%.2f dead=%d (%s) allies=%d enemies=%d hp=%.2f",
		now,
		TeamLabel(),
		ShortName(bot:GetUnitName()),
		tostring(lane),
		was,
		floor,
		snap.fresh or 0,
		snap.names or "",
		allies or 0,
		enemiesAlive or 0,
		hp or 0
	))
end

function KillWindow.LogRosh(bot, was, floor, snap)
	if bot == nil or bot.GetPlayerID == nil then
		return
	end
	local now = Now()
	local id = bot:GetPlayerID()
	if roshLogged[id] ~= nil and now < roshLogged[id] then
		return
	end
	roshLogged[id] = now + 4
	Print(string.format(
		"[OHA-FIGHT] t=%.0f %s rosh %s was=%.2f floor=%.2f dead=%d (%s)",
		now,
		TeamLabel(),
		ShortName(bot:GetUnitName()),
		was,
		floor,
		snap.fresh or 0,
		snap.names or ""
	))
end

return KillWindow
