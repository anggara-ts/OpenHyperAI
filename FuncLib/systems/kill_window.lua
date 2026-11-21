-- Team-wide kill advantage for push and Roshan.
-- A dead enemy raises both. An early return to the fountain (buyback) drops push.
local KillWindow = {}
local PushRules = require(GetScriptDirectory() .. "/FuncLib/systems/push_rules")

local enemies = {}
-- Our own heroes' deaths teach the respawn time per level (PushRules.RespawnEstimate): learned[level] = seconds.
local own = {}
local learned = {}
local DEFAULT_RESPAWN = 30
local pushLockUntil = -999
local pushLogged = {}
local roshLogged = {}
local heldLogged = {}
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

local function Dist(posA, posB)
	if posA == nil or posB == nil or posA.x == nil or posB.x == nil then
		return 99999
	end
	local dx = posA.x - posB.x
	local dy = posA.y - posB.y
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

local function OwnAverageLevel()
	local sum, count = 0, 0
	for i = 1, 5 do
		local member = GetTeamMember(i)
		if member ~= nil and member.GetLevel ~= nil then
			sum = sum + member:GetLevel()
			count = count + 1
		end
	end
	return count > 0 and sum / count or nil
end

-- Enemy level: GetHeroLevel(pid) (a global; unverified for enemy player IDs), else the level last seen on its
-- handle, else our average level.
local function EnemyLevel(pid, slot)
	local ok, level = pcall(GetHeroLevel, pid)
	if ok and type(level) == "number" and level >= 1 then
		return math.floor(level), "api"
	end
	if slot ~= nil and slot.level ~= nil then
		return slot.level, "seen"
	end
	local average = OwnAverageLevel()
	if average ~= nil then
		return math.floor(average + 0.5), "ours"
	end
	return nil, "none"
end

-- Returns seconds, known (the API answered), source text for the log.
local function RespawnOf(pid, slot)
	local hero = FindEnemy(pid)
	if hero ~= nil and hero.GetRespawnTime ~= nil then
		local ok, respawnTime = pcall(function()
			return hero:GetRespawnTime()
		end)
		if ok and type(respawnTime) == "number" and respawnTime > 5 and respawnTime < 200 then
			return respawnTime, true, "api"
		end
	end
	local level, levelFrom = EnemyLevel(pid, slot)
	local seconds, source, usedLevel = PushRules.RespawnEstimate(learned, level, DEFAULT_RESPAWN)
	if source == "learned" then
		return seconds,
			false,
			string.format("learned(lvl=%s/%s from=%s)", tostring(level), levelFrom, tostring(usedLevel))
	end
	return seconds, false, string.format("default(lvl=%s/%s)", tostring(level), levelFrom)
end

local function OwnHero(pid)
	for i = 1, 5 do
		local member = GetTeamMember(i)
		if member ~= nil and member.GetPlayerID ~= nil and member:GetPlayerID() == pid then
			return member
		end
	end
	return nil
end

local function Print(line)
	pcall(print, line)
end

local function Empty()
	return { fresh = 0, buyback = false, lockLeft = 0, names = "" }
end

-- Own deaths: the respawn time GetRespawnTime() gives at the death, and the time it really took (logged at the
-- respawn, so a game shows whether the API value is the full timer).
local function TickOwn(now)
	for _, pid in pairs(GetTeamPlayers(GetTeam())) do
		local alive = IsHeroAlive(pid)
		local slot = own[pid]
		if slot == nil then
			own[pid] = { alive = alive }
		elseif slot.alive and not alive then
			local hero = OwnHero(pid)
			slot.alive = false
			slot.deathAt = now
			slot.level = hero ~= nil and hero:GetLevel() or nil
			slot.api = nil
			if hero ~= nil and hero.GetRespawnTime ~= nil then
				local ok, value = pcall(function()
					return hero:GetRespawnTime()
				end)
				if ok and type(value) == "number" and value > 3 and value < 200 then
					slot.api = value
					if slot.level ~= nil then
						learned[slot.level] = value
					end
				end
			end
		elseif not slot.alive and alive then
			slot.alive = true
			local observed = slot.deathAt ~= nil and now - slot.deathAt or nil
			-- No API value: the observed time teaches, unless it was a buyback or Aegis (well under the timer).
			if slot.api == nil and slot.level ~= nil and observed ~= nil and observed >= 8 then
				local before = learned[slot.level]
				if before == nil or observed >= before * 0.8 then
					learned[slot.level] = observed
				end
			end
			if ShouldLog() and observed ~= nil then
				Print(
					string.format(
						"[OHA-FIGHT] t=%.0f %s own-respawn %s lvl=%s api=%s observed=%.0f",
						now,
						TeamLabel(),
						HeroName(pid),
						tostring(slot.level),
						slot.api ~= nil and string.format("%.0f", slot.api) or "-",
						observed
					)
				)
			end
		end
	end
end

local function TickRaw()
	local now = Now()
	pcall(TickOwn, now)
	local enemyTeam = GetOpposingTeam()
	local fountain = Fountain(enemyTeam)
	local fresh = 0
	local names = {}
	for _, pid in pairs(GetTeamPlayers(enemyTeam)) do
		local alive = IsHeroAlive(pid)
		local slot = enemies[pid]
		if slot == nil then
			enemies[pid] = { alive = alive, name = HeroName(pid), team = enemyTeam }
		else
			if slot.name == nil then
				slot.name = HeroName(pid)
			end
			if slot.alive and alive and now >= (slot.levelAt or -999) then
				-- Level last seen on its handle (EnemyLevel fallback), every 5s.
				slot.levelAt = now + 5
				local hero = FindEnemy(pid)
				if hero ~= nil and hero.GetLevel ~= nil then
					slot.level = hero:GetLevel()
				end
			end
			if slot.alive and not alive then
				local seen = LastSeen(pid)
				local respawnFor, known, source = RespawnOf(pid, slot)
				slot.alive = false
				slot.deathAt = now
				slot.respawnFor = respawnFor
				-- API value only: an estimate that runs long would read the real respawn as a buyback (push down 20s).
				slot.respawnKnown = known
				slot.deathLoc = seen and seen.location or nil
				slot.pending = false
				pushLockUntil = -999
				if ShouldLog() then
					Print(
						string.format(
							"[OHA-FIGHT] t=%.0f %s death %s respawn=%.0fs known=%s src=%s push+rosh up",
							now,
							TeamLabel(),
							slot.name,
							respawnFor,
							tostring(known),
							source
						)
					)
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
							Print(
								string.format(
									"[OHA-FIGHT] t=%.0f %s %s %s deadFor=%.0fs push down %ds",
									now,
									TeamLabel(),
									kind,
									slot.name,
									elapsed,
									LOCK_SECONDS
								)
							)
						end
					elseif ShouldLog() then
						Print(
							string.format(
								"[OHA-FIGHT] t=%.0f %s aegis %s deadFor=%.0fs push stays",
								now,
								TeamLabel(),
								slot.name,
								elapsed
							)
						)
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

-- Dead enemies for the advantage window (PushRules.Advantage): dead with more than 5s of respawn left, dead with
-- 20s+ left, the shortest respawn left (nil when none is dead) and their names.
function KillWindow.DeadCounts()
	local now = Now()
	local enemyTeam = GetOpposingTeam()
	local dead, deadLong, minLeft = 0, 0, nil
	local names = {}
	-- Only this team's enemies (both teams' bots may share this module).
	for _, slot in pairs(enemies) do
		if slot.team == enemyTeam and not slot.alive and slot.deathAt ~= nil then
			local rest = slot.deathAt + (slot.respawnFor or DEFAULT_RESPAWN) - now
			if rest > 5 then
				dead = dead + 1
				names[#names + 1] = slot.name or "?"
				if rest >= 20 then
					deadLong = deadLong + 1
				end
				if minLeft == nil or rest < minLeft then
					minLeft = rest
				end
			end
		end
	end
	return dead, deadLong, minLeft, table.concat(names, ",")
end

-- Seconds until the first dead enemy respawns, or nil when none is dead.
-- Dead enemies that will be back within `seconds` (respawn timer only).
function KillWindow.RespawningWithin(seconds)
	local now = Now()
	local count = 0
	for _, slot in pairs(enemies) do
		if not slot.alive and slot.deathAt ~= nil then
			local rest = slot.deathAt + (slot.respawnFor or 30) - now
			if rest <= seconds then
				count = count + 1
			end
		end
	end
	return count
end
function KillWindow.WindowLeft()
	local now = Now()
	local left = nil
	for _, slot in pairs(enemies) do
		if not slot.alive and slot.deathAt ~= nil then
			local rest = slot.deathAt + (slot.respawnFor or 30) - now
			if rest > 0 and (left == nil or rest < left) then
				left = rest
			end
		end
	end
	return left
end

-- Seconds a respawned enemy needs to reach `loc` from its fountain, counting a TP to a
-- tower on the way. Kept between 8 and 20.
function KillWindow.TransitGrace(loc)
	local distance = Dist(Fountain(GetOpposingTeam()), loc)
	if distance >= 99999 then
		return 10
	end
	return math.max(8, math.min(20, distance / 450))
end

-- Enemies that respawned less than `grace` seconds ago and have not been seen away from
-- their fountain. They are alive but cannot contest a far objective yet.
function KillWindow.EnemiesInTransit(grace)
	local now = Now()
	local fountain = Fountain(GetOpposingTeam())
	local count = 0
	for pid, slot in pairs(enemies) do
		if slot.alive and slot.backAt ~= nil and now - slot.backAt < (grace or 15) then
			local seen = LastSeen(pid)
			local away = seen ~= nil
				and seen.time_since_seen ~= nil
				and seen.time_since_seen < 3
				and Dist(seen.location, fountain) > 3500
			if not away then
				count = count + 1
			end
		end
	end
	return count
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
	Print(
		string.format(
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
		)
	)
end

-- A kill window is open but the push floor is held because our base is being hit.
function KillWindow.LogPushHeld(bot, lane, snap, why)
	if bot == nil or bot.GetPlayerID == nil then
		return
	end
	local now = Now()
	local id = bot:GetPlayerID()
	if heldLogged[id] ~= nil and now < heldLogged[id] then
		return
	end
	heldLogged[id] = now + 4
	Print(
		string.format(
			"[OHA-FIGHT] t=%.0f %s push-held %s lane=%s dead=%d (%s) why=%s",
			now,
			TeamLabel(),
			ShortName(bot:GetUnitName()),
			tostring(lane),
			snap.fresh or 0,
			snap.names or "",
			(why ~= nil and why ~= "") and why or "?"
		)
	)
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
	Print(
		string.format(
			"[OHA-FIGHT] t=%.0f %s rosh %s was=%.2f floor=%.2f dead=%d (%s)",
			now,
			TeamLabel(),
			ShortName(bot:GetUnitName()),
			was,
			floor,
			snap.fresh or 0,
			snap.names or ""
		)
	)
end

return KillWindow
