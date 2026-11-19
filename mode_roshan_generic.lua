-- Roshan mode.
local bot = GetBot()
local botName = bot:GetUnitName()
if
	bot == nil
	or bot:IsInvulnerable()
	or not bot:IsHero()
	or not bot:IsAlive()
	or not string.find(botName, "hero")
	or bot:IsIllusion()
then
	return
end
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local KillWindow = require(GetScriptDirectory() .. "/FuncLib/systems/kill_window")
local ObjectiveTravel = require(GetScriptDirectory() .. "/FuncLib/systems/objective_travel")
local CustomLoader = require(GetScriptDirectory() .. "/FuncLib/systems/custom_loader")
local isRoshanAlive = false
Fu.Utils.GameStates = Fu.Utils.GameStates or {}
Fu.Utils.GameStates.roshHandle = Fu.Utils.GameStates.roshHandle or nil
local roshanAliveSince = 0
local wasRoshanAlive = false
local hasEnoughDps = false
local roshan
local hasHumanInTeam = nil
local humanInviteStartTime = 0
local humanInviteCooldownUntil = 0
local humanInviteDuration = 15
local humanInviteCooldown = 3 * 60
local humanInviteCooldownTurbo = 2 * 60
local dipUntil = 0
local nextDipAllowedAt = 0
local dipDuration = 1.5
local dipCooldown = 8
local function AdjustDesireForHealth(desire)
	if botName ~= "npc_dota_hero_huskar" and Fu.ShouldLeaveRoshanFight(bot) then
		bot._roshDipActive = false
		return 0
	end
	-- Tank steps out (#12, game 048 29:07: Sniper stayed at 18% HP with Roshan on him and died to Roshan; under
	-- 50% Roshan HP nobody leaves). Roshan's next 3s would kill him, and Roshan isn't about to die: 3s out, so
	-- Roshan turns to someone else.
	if DotaTime() < (bot._roshStepOutUntil or -999) then
		return 0
	end
	if desire > 0 and Fu.Utils.IsValidUnit(roshan) and roshan:GetAttackTarget() == bot then
		-- Untested on Roshan: fall back to his attack damage over 3s if the estimate fails or reads 0.
		local okD, estimate = pcall(function()
			return roshan:GetEstimatedDamageToTarget(true, bot, 3.0, DAMAGE_TYPE_PHYSICAL)
		end)
		local roshDmg = okD and type(estimate) == "number" and estimate or 0
		if roshDmg <= 0 then
			local secondsPerAttack = roshan:GetSecondsPerAttack() or 1
			roshDmg = (roshan:GetAttackDamage() or 0) * 3 / math.max(0.5, secondsPerAttack)
		end
		if bot:GetHealth() <= roshDmg and Fu.GetHP(roshan) > 0.08 then
			bot._roshStepOutUntil = DotaTime() + 3
			pcall(
				print,
				string.format(
					"[OHA-ROSH] t=%.0f %s step-out hp=%d roshDmg3s=%d roshHp=%.2f",
					DotaTime(),
					(string.gsub(botName, "npc_dota_hero_", "")),
					bot:GetHealth(),
					math.floor(roshDmg),
					Fu.GetHP(roshan)
				)
			)
			return 0
		end
	end
	if desire <= 0 then
		return desire
	end
	if botName == "npc_dota_hero_huskar" then
		return desire
	end
	local hpRatio = Fu.GetHP(bot)
	local isRoshanHurt = Fu.Utils.IsValidUnit(roshan) and Fu.GetHP(roshan) < 0.9
	if bot:WasRecentlyDamagedByAnyHero(2.0) and hpRatio < 0.4 and not isRoshanHurt then
		return desire * RemapValClamped(hpRatio, 0.1, 0.4, 0.0, 0.5)
	end
	local isRoshanTargetingBot = Fu.Utils.IsValidUnit(roshan) and roshan:GetAttackTarget() == bot
	local isNearRoshan = Fu.Utils.IsValidUnit(roshan) and GetUnitToUnitDistance(bot, roshan) < 600
	if hpRatio < 0.5 and isRoshanTargetingBot and DotaTime() > nextDipAllowedAt then
		dipUntil = DotaTime() + dipDuration
		nextDipAllowedAt = DotaTime() + dipCooldown
	end
	bot._roshDipActive = DotaTime() < dipUntil
	if isRoshanHurt and (bot._roshDipActive or isNearRoshan) then
		return math.max(desire, BOT_MODE_DESIRE_HIGH)
	end
	return desire
end
local lastLogTime = 0
local function RoshLog(fmt, ...)
	pcall(
		print,
		string.format(
			"[OHA-ROSH] t=%.0f %s %s " .. fmt,
			DotaTime(),
			GetTeam() == TEAM_DIRE and "dire" or "radiant",
			(string.gsub(bot:GetUnitName(), "npc_dota_hero_", "")),
			...
		)
	)
end
-- One line when this bot's Roshan desire turns on or off, with the reason.
local function LogDesireChange(final)
	local on = final >= 0.3
	if on == (bot._roshOn == true) then
		return
	end
	bot._roshOn = on
	local roshanLocation = Fu.GetCurrentRoshanLocation()
	-- Game 036, 19:56-21:06: four bots stood ~65s at the pit and dropped as even(5v5); the log had
	-- no Roshan HP. roshHp=-1 means no valid handle; hitting = allies whose attack target is Roshan.
	local roshHp, hitting = -1, 0
	if Fu.Utils.IsValidUnit(roshan) then
		roshHp = roshan:GetHealth() / math.max(roshan:GetMaxHealth(), 1)
		for _, allyHero in pairs(GetUnitList(UNIT_LIST_ALLIED_HEROES) or {}) do
			if allyHero ~= nil and allyHero:IsAlive() and allyHero:GetAttackTarget() == roshan then
				hitting = hitting + 1
			end
		end
	end
	RoshLog(
		"%s desire=%.2f why=%s mode=%s dist=%d allies=%d enemies=%d held=%d fit=%s roshHp=%.2f hitting=%d",
		on and "call" or "drop",
		final,
		tostring(bot._roshWhy),
		tostring(bot:GetActiveMode()),
		roshanLocation ~= nil and math.floor(GetUnitToLocationDistance(bot, roshanLocation)) or -1,
		Fu.GetNumOfAliveHeroes(false),
		Fu.GetNumOfAliveHeroes(true),
		bot._roshHeld or 0,
		tostring(bot._roshFitWhy),
		roshHp,
		hitting
	)
end
function GetDesire()
	if ShouldSkipBotThink(GetBot()) then
		return 0
	end
	local rawDesire, gatherCall = GetDesireHelper()
	local final = AdjustDesireForHealth(rawDesire)
	-- A live gather has to beat farm and a one-kill push. VERYHIGH in this engine is ~0.6,
	-- so clamping the call there is why the rest of the team never leaves the lane.
	if gatherCall and final >= 0.9 then
		final = 0.96
	else
		final = Clamp(final, 0, BOT_MODE_DESIRE_VERYHIGH)
	end
	if DotaTime() > 3 * 60 and DotaTime() > lastLogTime + 15 then
		lastLogTime = DotaTime()
		log(
			string.format(
				"[ROSH] t=%.0f %s raw=%.2f final=%.2f alive=%s dps=%s kill=%s hg=%s eA=%d aA=%d",
				DotaTime(),
				string.gsub(bot:GetUnitName(), "npc_dota_hero_", ""),
				rawDesire,
				final,
				tostring(Fu.IsRoshanAlive()),
				tostring(hasEnoughDps),
				tostring(isRoshanAlive),
				tostring(Fu.Utils.IsTeamPushingSecondTierOrHighGround(bot)),
				Fu.GetNumOfAliveHeroes(true),
				Fu.GetNumOfAliveHeroes(false)
			)
		)
	end
	LogDesireChange(final)
	-- Do not shout here — desire alone is not a commit (caused "Let's Rosh" then nothing).
	return final
end
local function AllyActiveMode(hero)
	local ok, mode = pcall(function()
		return hero:GetActiveMode()
	end)
	if ok then
		return mode
	end
	return nil
end
-- A low hero (except Huskar) and anyone already defending the ancient are not part of the call.
local function AllyShouldJoin(ally)
	if ally == nil or not ally:IsAlive() or not ally:IsHero() or ally:IsIllusion() then
		return false
	end
	if ally:GetUnitName() ~= "npc_dota_hero_huskar" and Fu.GetHP(ally) < 0.45 then
		return false
	end
	local ancient = GetAncient(GetTeam())
	if ancient ~= nil and GetUnitToUnitDistance(ally, ancient) < 2500 then
		if Fu.Utils.CountEnemyHeroesNear(ancient:GetLocation(), 2500) >= 1 then
			return false
		end
	end
	return true
end
-- grouped: joiners already at the pit or the fountain-side rally.
-- pending: furthest joiner who acked (switched to Roshan) and is still outside that ring.
-- required: allies this call waits for: the ones there, the ones who acked, and, for the first
-- 4s of the call, everyone who could join (they need a think or two to switch).
-- declined: names of allies who did not switch after that, so the call does not wait for them
-- (a core busy defending or farming used to hold the whole group).
local ACK_GRACE = 4
-- ackSet: allies who acked inside the grace. A late joiner (decliner whose own mode ended) is
-- welcome but not waited for: it is neither required nor counted as still walking, so the group
-- that already gathered does not hold for it (it used to, up to the 40s cap).
local function RoshanGather(pit, callAge, ackSet)
	ackSet = ackSet or {}
	local grouped, pending, required = 0, 0, 0
	local declined = {}
	local coming = {}
	local players = GetTeamPlayers(GetTeam())
	for wasRoshanAlive = 1, #players do
		local ally = GetTeamMember(wasRoshanAlive)
		if AllyShouldJoin(ally) then
			local dist = GetUnitToLocationDistance(ally, pit)
			local acked = ally == bot or (ally:IsBot() and AllyActiveMode(ally) == BOT_MODE_ROSHAN)
			local inGrace = (callAge or 0) < ACK_GRACE
			local pid = ally:GetPlayerID()
			if inGrace and (acked or dist <= 1800) then
				ackSet[pid] = true
			end
			if dist <= 1800 then
				grouped = grouped + 1
				required = required + 1
				coming[#coming + 1] = ally
			elseif acked and (inGrace or ackSet[pid]) then
				required = required + 1
				coming[#coming + 1] = ally
				if ally ~= bot and dist > pending then
					pending = dist
				end
			elseif acked then
				-- Late joiner: on its way, not waited for.
				coming[#coming + 1] = ally
			elseif inGrace then
				required = required + 1
				coming[#coming + 1] = ally
			else
				declined[#declined + 1] = (string.gsub(ally:GetUnitName(), "npc_dota_hero_", ""))
			end
		end
	end
	return grouped, pending, required, declined, coming
end
local function GatherMinimum()
	if Fu.IsLateGame() then
		return 2
	elseif Fu.IsMidGame() then
		return 3
	end
	return 4
end
-- A teammate is on the call. That is what pulls the rest of the team. Any distance: it used
-- to count only allies within 2800 of the rally, so heroes further out never joined and the
-- gather sat at grouped=0/5 (game 014).
local function TeamRoshanCall(pit)
	local players = GetTeamPlayers(GetTeam())
	for wasRoshanAlive = 1, #players do
		local ally = GetTeamMember(wasRoshanAlive)
		if ally ~= nil and ally ~= bot and ally:IsAlive() and ally:IsHero() and not ally:IsIllusion() then
			if AllyActiveMode(ally) == BOT_MODE_ROSHAN then
				return true
			end
		end
	end
	return false
end
local function FindRoshan()
	local cachedRoshan = Fu.Utils.GameStates.roshHandle
	if Fu.Utils.IsValidUnit(cachedRoshan) then
		roshan = cachedRoshan
		return
	end
	local neutralCreeps = bot:GetNearbyNeutralCreeps(1600)
	for _, creep in pairs(neutralCreeps) do
		if creep:GetUnitName() == "npc_dota_roshan" then
			roshan = creep
			Fu.Utils.GameStates.roshHandle = creep
			return
		end
	end
end
-- Safe to start/continue Roshan: numbers + pit not contested.
-- finishing=true allows a looser gate when Roshan is already low and allies are in the pit.
-- Enemies that can reach the pit now. One who just respawned is still walking back
-- from the fountain, so the numbers a kill bought last a little past the respawn.
-- Enemies held at their base (user call, game 031, 70:00: Radiant's mega creeps were deep in Dire's
-- base and Radiant farmed the jungle instead of taking Roshan; with 4-5 Dire heroes alive the
-- numbers rule never allowed it). 4+ of our lane creeps within 3000 of the enemy ancient: an enemy
-- hero seen there (within 3500 of it) in the last 5s does not contest Roshan. Cached for 1s.
local heldAt, heldN = -999, 0
local function EnemiesHeldAtBase()
	local now = DotaTime()
	if now - heldAt < 1 then
		return heldN
	end
	heldAt, heldN = now, 0
	bot._roshHeld = 0
	local enemyAncient = GetAncient(GetOpposingTeam())
	if enemyAncient == nil then
		return 0
	end
	local creeps = 0
	for _, unit in pairs(GetUnitList(UNIT_LIST_ALLIED_CREEPS) or {}) do
		if
			unit ~= nil
			and not unit:IsNull()
			and unit:IsAlive()
			and GetUnitToUnitDistance(unit, enemyAncient) <= 3000
		then
			creeps = creeps + 1
		end
	end
	if creeps < 4 then
		return 0
	end
	for _, pid in ipairs(GetTeamPlayers(GetOpposingTeam())) do
		if IsHeroAlive(pid) then
			local info = GetHeroLastSeenInfo(pid)
			local lastSeen = info ~= nil and info[1] or nil
			if
				lastSeen ~= nil
				and lastSeen.time_since_seen <= 5
				and GetUnitToLocationDistance(enemyAncient, lastSeen.location) <= 3500
			then
				heldN = heldN + 1
			end
		end
	end
	bot._roshHeld = heldN
	return heldN
end
local function ContestingEnemies(roshanLocation)
	local alive = Fu.GetNumOfAliveHeroes(true)
	local grace = KillWindow.TransitGrace(roshanLocation)
	local transit = KillWindow.EnemiesInTransit(grace)
	return math.max(0, alive - transit - EnemiesHeldAtBase()), transit
end
-- Numbers rule for a fresh take. Returns ok, why.
local function FreshTakeNumbers(alliesAlive, enemiesAlive, missing)
	if enemiesAlive >= alliesAlive then
		return false, string.format("even(%dv%d)", alliesAlive, enemiesAlive)
	end
	if enemiesAlive >= 4 and missing < 2 then
		return false, string.format("enemies4(missing=%d)", missing)
	end
	if enemiesAlive >= 3 and alliesAlive - enemiesAlive < 1 and missing < 2 then
		return false, string.format("enemies3(missing=%d)", missing)
	end
	return true, "ok"
end
-- Safe to start/continue Roshan: numbers + pit not contested. Returns ok, why.
local function IsRoshanEngageSafe(roshanLocation, finishing)
	if roshanLocation == nil then
		return false, "no-pit"
	end
	local alliesAlive = Fu.GetNumOfAliveHeroes(false)
	local enemiesAlive = ContestingEnemies(roshanLocation)
	local missing = Fu.Utils.CountMissingEnemyHeroes and Fu.Utils.CountMissingEnemyHeroes() or 0
	local alliesNear = Fu.GetAlliesNearLoc(roshanLocation, 1600) or {}
	local enemiesNear = Fu.GetLastSeenEnemiesNearLoc(roshanLocation, 1600) or {}
	local alliesInPit = #alliesNear
	local enemiesInPit = #enemiesNear
	-- Contested pit: enemies already there in force.
	if enemiesInPit >= 2 and enemiesInPit >= math.max(1, alliesInPit) then
		return false, string.format("contested(%d)", enemiesInPit)
	end
	if finishing then
		-- Finish only if we already own the pit / have numbers.
		if alliesInPit >= 2 and enemiesInPit <= 1 then
			return true, "ok"
		end
		if alliesAlive >= enemiesAlive + 1 and enemiesInPit == 0 then
			return true, "ok"
		end
		return false, string.format("finish-unsafe(pit=%d foes=%d)", alliesInPit, enemiesInPit)
	end
	-- Fresh take: need a real numbers edge or missing enemies — never full 5v5.
	return FreshTakeNumbers(alliesAlive, enemiesAlive, missing)
end
-- Time the group needs: the GatherMinimum-th closest joiner walks to the rally, then the
-- group kills Roshan. Everyone computes the same number, so the team goes or stays together.
local function TakeTimeNeeded(roshanLocation)
	local rally = Fu.AdjustLocationWithOffsetTowardsFountain(roshanLocation, 900)
	local etas = {}
	local dps = {}
	local players = GetTeamPlayers(GetTeam())
	for wasRoshanAlive = 1, #players do
		local ally = GetTeamMember(wasRoshanAlive)
		if AllyShouldJoin(ally) then
			-- Fastest way there: walk, TP to our tower nearest the pit, or a Twin Gate. Walking
			-- only made an ally across the map look too slow for every kill window.
			local eta = ObjectiveTravel.Eta(ally, rally)
			local secondsPerAttack = ally:GetSecondsPerAttack()
			local hit = (secondsPerAttack ~= nil and secondsPerAttack > 0) and ally:GetAttackDamage() / secondsPerAttack
				or 0
			etas[#etas + 1] = { eta = eta, dps = hit }
		end
	end
	if #etas == 0 then
		return 999, 999, 999
	end
	table.sort(etas, function(first, second)
		return first.eta < second.eta
	end)
	local gatherCount = math.min(#etas, GatherMinimum())
	-- Damage of everyone who is coming and arrives within 15s of the gather minimum, not only
	-- the first n. With only the first two, the estimate jumped as soon as the walk started and
	-- the closest heroes changed (game 014: called at need=31, dropped 5s later at need=55;
	-- 19 calls, 19 drops, no Roshan all game).
	local groupDps = 0
	for wasRoshanAlive = 1, #etas do
		if wasRoshanAlive <= gatherCount or etas[wasRoshanAlive].eta <= etas[gatherCount].eta + 15 then
			groupDps = groupDps + etas[wasRoshanAlive].dps
		end
	end
	local roshHp = 6000 + 130 * math.max(0, DotaTime() / 60)
	if Fu.Utils.IsValidUnit(roshan) and roshan:CanBeSeen() then
		roshHp = roshan:GetHealth()
	end
	-- Roshan's armor takes roughly half of right-click damage.
	local killTime = math.max(8, math.min(60, roshHp / math.max(1, groupDps * 0.5)))
	return etas[gatherCount].eta + killTime, etas[gatherCount].eta, killTime
end
-- A take that only works because of a kill must fit inside that kill's window.
-- Returns ok, why.
local function TakeFitsWindow(roshanLocation)
	local alliesAlive = Fu.GetNumOfAliveHeroes(false)
	local missing = Fu.Utils.CountMissingEnemyHeroes and Fu.Utils.CountMissingEnemyHeroes() or 0
	local killWindowState = KillWindow.Tick()
	-- Count enemies that respawn before the take could be done as alive already. Calling on the
	-- live count alone flipped to "window-short" a second later when two of them were back
	-- (15:12: called with 2 alive, 4 alive next think).
	local need0 = TakeTimeNeeded(roshanLocation)
	local back = KillWindow.RespawningWithin and KillWindow.RespawningWithin(need0) or 0
	local everyone = math.max(0, Fu.GetNumOfAliveHeroes(true) - EnemiesHeldAtBase())
		+ (killWindowState.fresh or 0)
		+ back
	if FreshTakeNumbers(alliesAlive, everyone, missing) then
		return true, "no-window-needed"
	end
	local left = KillWindow.WindowLeft()
	if left == nil then
		-- Only the transit grace is left. Not enough to start a walk.
		return false, "window-closed"
	end
	local window = left + KillWindow.TransitGrace(roshanLocation)
	local need, eta, kill = TakeTimeNeeded(roshanLocation)
	if need + 3 > window then
		return false, string.format("window-short(need=%.0f eta=%.0f kill=%.0f left=%.0f)", need, eta, kill, window)
	end
	return true, string.format("window(need=%.0f left=%.0f)", need, window)
end
-- Looser window check for a call that is already running (own call that passed the full check
-- in the last 20s, or a teammate's call): only drop when the window no longer covers the walk
-- plus 15s of hitting. Re-running the full check every think dropped every call within 1-8s.
local function RunningCallFits(roshanLocation)
	local alliesAlive = Fu.GetNumOfAliveHeroes(false)
	local missing = Fu.Utils.CountMissingEnemyHeroes and Fu.Utils.CountMissingEnemyHeroes() or 0
	local killWindowState = KillWindow.Tick()
	local need0, eta0 = TakeTimeNeeded(roshanLocation)
	local back = KillWindow.RespawningWithin and KillWindow.RespawningWithin(need0) or 0
	if
		FreshTakeNumbers(
			alliesAlive,
			math.max(0, Fu.GetNumOfAliveHeroes(true) - EnemiesHeldAtBase()) + (killWindowState.fresh or 0) + back,
			missing
		)
	then
		return true, "running-no-window-needed"
	end
	local left = KillWindow.WindowLeft()
	if left == nil then
		return false, "running-window-closed"
	end
	local window = left + KillWindow.TransitGrace(roshanLocation)
	if window < eta0 + 15 then
		return false, string.format("running-window-short(eta=%.0f left=%.0f)", eta0, window)
	end
	return true, string.format("running(eta=%.0f left=%.0f)", eta0, window)
end
-- Records why the desire came out as it did, for the [OHA-ROSH] call/abort lines.
local function Ret(desire, why, call)
	bot._roshWhy = why
	return desire, call
end
function GetDesireHelper()
	if
		bot:IsInvulnerable()
		or not bot:IsHero()
		or not bot:IsAlive()
		or not string.find(botName, "hero")
		or bot:IsIllusion()
	then
		return Ret(BOT_MODE_DESIRE_NONE, "invalid")
	end
	local ourAncient = GetAncient(GetTeam())
	if
		Fu.Utils.CountEnemyHeroesOnHighGround(GetTeam()) >= 2
		or ourAncient and Fu.Utils.CountEnemyHeroesNear(ourAncient:GetLocation(), 2500) >= 1
	then
		return Ret(BOT_MODE_DESIRE_NONE, "base-threat")
	end
	if not Fu.Utils.IsValidUnit(roshan) then
		FindRoshan()
	end
	local roshanLocation = Fu.GetCurrentRoshanLocation()
	local alliesAlive = Fu.GetNumOfAliveHeroes(false)
	local contestingEnemies = ContestingEnemies(roshanLocation)
	local aliveAllies = {}
	for _, allyHero in pairs(GetUnitList(UNIT_LIST_ALLIED_HEROES)) do
		if allyHero:IsAlive() then
			table.insert(aliveAllies, allyHero)
		end
	end
	isRoshanAlive = Fu.IsRoshanAlive()
	if isRoshanAlive and not wasRoshanAlive then
		roshanAliveSince = DotaTime()
		wasRoshanAlive = true
	elseif not isRoshanAlive then
		roshanAliveSince = 0
		wasRoshanAlive = false
	end
	-- Re-checked every think. A team that was strong enough once is not strong enough for the rest of the game.
	hasEnoughDps = Fu.HasEnoughDPSForRoshan(aliveAllies)
	if Fu.GetEnemiesAroundAncient(bot, 2000) > 2 or Fu.GetHP(GetAncient(bot:GetTeam())) < 0.6 then
		return Ret(BOT_MODE_DESIRE_NONE, "base-threat")
	end
	local alliesInPit = #(Fu.GetAlliesNearLoc(roshanLocation, 1600) or {})
	local roshLow = Fu.Utils.IsValidUnit(roshan) and (roshan:GetHealth() / roshan:GetMaxHealth()) < 0.8
	-- Early game: no fresh pit. Only stay if Roshan is already low and allies are in it.
	if Fu.IsEarlyGame() and not (roshLow and alliesInPit >= 2 and IsRoshanEngageSafe(roshanLocation, true)) then
		return Ret(BOT_MODE_DESIRE_NONE, "early-game")
	end
	-- Nobody acked this bot's last call: off for 30s, finishing included (game 015, 57:00:
	-- Medusa stayed in a "finishing" Roshan alone and hit him solo while the rest pushed).
	if DotaTime() < (bot._roshNoAckUntil or -999) then
		return Ret(BOT_MODE_DESIRE_NONE, "nobody-acked")
	end
	if roshLow then
		local safeFinish, finishWhy = IsRoshanEngageSafe(roshanLocation, true)
		-- Finishing needs company in the pit, unless he can finish Roshan alone in about 5s.
		local secondsPerAttack = bot:GetSecondsPerAttack()
		local myDps = (secondsPerAttack ~= nil and secondsPerAttack > 0)
				and bot:GetAttackDamage() / secondsPerAttack * 0.5
			or 0
		local soloFinish = Fu.Utils.IsValidUnit(roshan) and roshan:GetHealth() <= myDps * 5
		-- Two hitters at least (#12, game 048 29:10: two allies TP'd out and Sniper and Ringmaster were left to
		-- finish it): allies next to Roshan, not only somewhere in the pit.
		local alliesAtRoshan = Fu.Utils.IsValidUnit(roshan) and #(Fu.GetAlliesNearLoc(roshan:GetLocation(), 900) or {})
			or alliesInPit
		if safeFinish and alliesAtRoshan < 2 and alliesInPit >= 2 and not soloFinish then
			return Ret(BOT_MODE_DESIRE_NONE, "few-hitters")
		end
		if safeFinish and (alliesInPit >= 2 or soloFinish) then
			local roshanHpRatio = roshan:GetHealth() / roshan:GetMaxHealth()
			return Ret(RemapValClamped(roshanHpRatio, 0.8, 0.0, 0.9, 1.0), "finishing")
		end
		-- Contested / unsafe finish — do not suicide into the pit.
		return Ret(BOT_MODE_DESIRE_NONE, safeFinish and "finish-no-dps" or finishWhy)
	end
	-- A committed take with the group in the pit keeps going on pit control (the finishing check),
	-- not the fresh-take numbers: at 56:59 a committed 5-man take on full-HP Roshan was dropped
	-- by everyone at once as enemies4(missing=1).
	local committedNow = bot._roshCommitUntil ~= nil and DotaTime() < bot._roshCommitUntil
	-- The commit lasted 25s; after that a group already hitting Roshan in the pit fell back to the
	-- fresh-take numbers and left (game 036, 21:06, drop why=even(5v5) dist=69-299). Extend it
	-- while 3+ allies are in the pit, 2+ are hitting Roshan and no enemy hero is seen near it.
	if committedNow and alliesInPit >= 3 and Fu.Utils.IsValidUnit(roshan) then
		local hitting = 0
		for _, allyHero in pairs(GetUnitList(UNIT_LIST_ALLIED_HEROES) or {}) do
			if allyHero ~= nil and allyHero:IsAlive() and allyHero:GetAttackTarget() == roshan then
				hitting = hitting + 1
			end
		end
		if
			hitting >= 2
			and #(Fu.GetEnemiesNearLoc(roshanLocation, 1600) or {}) == 0
			and bot._roshCommitUntil - DotaTime() < 8
		then
			bot._roshCommitUntil = DotaTime() + 10
			if DotaTime() >= (bot._roshExtendLogAt or -999) then
				bot._roshExtendLogAt = DotaTime() + 10
				RoshLog(
					"commit-extend hitting=%d inPit=%d roshHp=%.2f",
					hitting,
					alliesInPit,
					roshan:GetHealth() / math.max(roshan:GetMaxHealth(), 1)
				)
			end
		end
	end
	local safeTake, takeWhy = IsRoshanEngageSafe(roshanLocation, committedNow and alliesInPit >= 3)
	if not safeTake then
		return Ret(BOT_MODE_DESIRE_NONE, takeWhy)
	end
	if alliesAlive < contestingEnemies then
		return Ret(BOT_ACTION_DESIRE_NONE, "outnumbered")
	end
	-- A take that only works because of a kill has to fit in that kill's window. Once the
	-- group has committed at the rally, finish the walk in.
	local committed = bot._roshCommitUntil ~= nil and DotaTime() < bot._roshCommitUntil
	local teamCall = isRoshanAlive and hasEnoughDps and TeamRoshanCall(roshanLocation)
	if not committed then
		local running = teamCall or (bot._roshFitOkAt ~= nil and DotaTime() - bot._roshFitOkAt < 20)
		if running then
			local fits, fitWhy = RunningCallFits(roshanLocation)
			bot._roshFitWhy = fitWhy
			if not fits then
				bot._roshFitOkAt = nil
				bot._roshFitFailUntil = DotaTime() + 15
				return Ret(BOT_MODE_DESIRE_NONE, fitWhy)
			end
		else
			-- A take that just failed the window check is not re-called for 15s; the
			-- call-drop-call churn walked the team toward the pit and back several times.
			if DotaTime() < (bot._roshFitFailUntil or -999) then
				return Ret(BOT_MODE_DESIRE_NONE, "recent-window-fail")
			end
			local fits, fitWhy = TakeFitsWindow(roshanLocation)
			bot._roshFitWhy = fitWhy
			if not fits then
				bot._roshFitFailUntil = DotaTime() + 15
				return Ret(BOT_MODE_DESIRE_NONE, fitWhy)
			end
			bot._roshFitOkAt = DotaTime()
		end
	end
	if teamCall and not bot:WasRecentlyDamagedByAnyHero(2.0) then
		local enemiesHere = bot:GetNearbyHeroes(1000, true, BOT_MODE_NONE) or {}
		if #enemiesHere == 0 then
			return Ret(0.96, "team-call", true)
		end
	end
	local killWindowState = KillWindow.Tick()
	-- The kill window stays open until a respawned enemy could be back at the pit.
	local inTransit = KillWindow.EnemiesInTransit(KillWindow.TransitGrace(roshanLocation))
	local killRosh = (killWindowState.fresh >= 1 or inTransit >= 1)
		and isRoshanAlive
		and hasEnoughDps
		and not Fu.IsEarlyGame()
		and DotaTime() > 8 * 60
	-- Hold a kill-window call for 8s: the fresh-kill / in-transit counts flicker, and a call
	-- dropped as "too-early-no-kill" two seconds later was re-called five seconds after that.
	if killRosh then
		bot._roshKillLatchUntil = DotaTime() + 8
	elseif isRoshanAlive and hasEnoughDps and DotaTime() < (bot._roshKillLatchUntil or -999) then
		killRosh = true
	end
	if hasHumanInTeam == nil then
		hasHumanInTeam = Fu.Utils.IsHumanPlayerInTeam(GetTeam())
	end
	if hasHumanInTeam and not killRosh then
		if Fu.IsEarlyGame() then
			return Ret(BOT_ACTION_DESIRE_NONE, "early-game")
		end
		if DotaTime() < humanInviteCooldownUntil then
			return Ret(BOT_ACTION_DESIRE_NONE, "human-cooldown")
		end
		local humanPlayer, ping = Fu.GetHumanPing()
		local isPingAtRoshan = humanPlayer ~= nil
			and ping ~= nil
			and ping.normal_ping
			and Fu.GetDistance(ping.location, Fu.GetCurrentRoshanLocation()) < 600
			and DotaTime() < ping.time + 5.0
		if not isPingAtRoshan then
			-- Soft invite without shouting: quiet staging desire only while safe.
			-- Old behavior announced then dropped after 15s — looked like false invites.
			if Fu.IsRoshanAlive() and hasEnoughDps then
				if humanInviteStartTime == 0 then
					humanInviteStartTime = DotaTime()
				end
				local inviteAge = DotaTime() - humanInviteStartTime
				if inviteAge < humanInviteDuration then
					return Ret(BOT_MODE_DESIRE_LOW, "human-invite")
				else
					humanInviteStartTime = 0
					humanInviteCooldownUntil = DotaTime()
						+ (Fu.IsModeTurbo() and humanInviteCooldownTurbo or humanInviteCooldown)
					return Ret(BOT_MODE_DESIRE_NONE, "human-invite-expired")
				end
			else
				humanInviteStartTime = 0
			end
		else
			humanInviteStartTime = 0
			humanInviteCooldownUntil = 0
		end
	end
	if isRoshanAlive and hasEnoughDps then
		local humanPlayer, ping = Fu.GetHumanPing()
		if humanPlayer ~= nil and DotaTime() > 5.0 then
			if
				ping ~= nil
				and ping.normal_ping
				and GetUnitToLocationDistance(humanPlayer, roshanLocation) < 4500
				and Fu.GetDistance(ping.location, roshanLocation) < 600
				and DotaTime() < ping.time + 5.0
			then
				if IsRoshanEngageSafe(roshanLocation, false) then
					return Ret(0.95, "ping")
				end
				return Ret(BOT_MODE_DESIRE_NONE, "ping-unsafe")
			end
		end
		if DotaTime() < (Fu.IsModeTurbo() and 15 * 60 or 20 * 60) and not killRosh then
			return Ret(BOT_MODE_DESIRE_NONE, "too-early-no-kill")
		end
		local timeFactor = RemapValClamped(DotaTime(), roshanAliveSince, roshanAliveSince + 2.5 * 60, 1, 2)
		local desire = RemapValClamped(GetRoshanDesire() * timeFactor, 0, 1, 0, BOT_MODE_DESIRE_ABSOLUTE)
		local alliesNearPit = Fu.GetAlliesNearLoc(roshanLocation, 1600)
		if #alliesNearPit >= 4 then
			desire = 0.9
		end
		local isPushingHighGround = Fu.Utils.IsTeamPushingSecondTierOrHighGround(bot)
		if isPushingHighGround and #alliesNearPit < 3 then
			desire = desire * 0.6
		end
		local why = "timer"
		if killRosh then
			local floor = BOT_MODE_DESIRE_VERYHIGH
			if desire < floor then
				KillWindow.LogRosh(bot, desire, floor, killWindowState)
				desire = floor
			end
			why = "kill-window"
		end
		return Ret(Clamp(desire, 0, BOT_MODE_DESIRE_VERYHIGH), why)
	end
	return Ret(BOT_ACTION_DESIRE_NONE, isRoshanAlive and "no-dps" or "rosh-dead")
end
local rallyOffset = 900
local pitAttackDistance = 300
function Think()
	if OhaCastGuard ~= nil and OhaCastGuard(GetBot()) then
		return
	end
	if not bot:IsAlive() or Fu.CanNotUseAction(bot) then
		return
	end
	if Fu.Item.TryPickupRoshanDrop(bot) then
		return
	end
	local roshanLocation = Fu.GetCurrentRoshanLocation()
	if roshanLocation == nil then
		return
	end
	if Fu.ShouldLeaveRoshanFight(bot) then
		local away = Fu.AdjustLocationWithOffsetTowardsFountain(roshanLocation, 1600)
		bot:Action_MoveToLocation(away)
		return
	end
	if bot._roshDipActive then
		local dipLocation = Fu.AdjustLocationWithOffsetTowardsFountain(roshanLocation, 300)
		bot:Action_MoveToLocation(dipLocation)
		return
	end
	if not Fu.Utils.IsValidUnit(roshan) then
		FindRoshan()
	end
	local distanceToPit = GetUnitToLocationDistance(bot, roshanLocation)
	local isInPit = distanceToPit <= pitAttackDistance
	local finishing = Fu.Utils.IsValidUnit(roshan) and Fu.GetHP(roshan) < 0.9
	local safe = IsRoshanEngageSafe(roshanLocation, finishing)
	local function MoveToPit()
		bot:Action_MoveToLocation(roshanLocation)
	end
	local function AttackRoshanOrMove()
		if isInPit and Fu.Utils.IsValidUnit(roshan) and Fu.CanBeAttacked(roshan) then
			bot:Action_AttackUnit(roshan, true)
		else
			MoveToPit()
		end
	end
	local rally = Fu.AdjustLocationWithOffsetTowardsFountain(roshanLocation, rallyOffset)
	local pitAllies = Fu.GetAlliesNearLoc(roshanLocation, 700) or {}
	local pitCount = 0
	for _, ally in pairs(pitAllies) do
		if Fu.IsValidHero(ally) and ally:IsAlive() and not ally:IsIllusion() then
			pitCount = pitCount + 1
		end
	end
	-- Fight is already going with a group in the pit. Join it.
	if finishing and pitCount >= 2 and safe then
		AttackRoshanOrMove()
		return
	end
	-- A gank on the rally must not leave them idle. Fight if the local fight is ours,
	-- otherwise step toward the fountain instead of holding the spot.
	local function RallyThreat()
		local enemy = nil
		local enemyDist = 1200
		local near = Fu.GetEnemyList(bot, 1200) or {}
		for _, hero in pairs(near) do
			if Fu.IsValidHero(hero) then
				local dist = GetUnitToUnitDistance(bot, hero)
				if dist < enemyDist then
					enemy = hero
					enemyDist = dist
				end
			end
		end
		local seenLoc = nil
		local seenDist = 1400
		for _, pid in pairs(GetTeamPlayers(GetOpposingTeam())) do
			if IsHeroAlive(pid) then
				local info = GetHeroLastSeenInfo(pid)
				local spot = info and info[1]
				if spot ~= nil and spot.time_since_seen < 2.5 then
					local dist = GetUnitToLocationDistance(bot, spot.location)
					if dist < seenDist then
						seenLoc = spot.location
						seenDist = dist
					end
				end
			end
		end
		local hit = bot:WasRecentlyDamagedByAnyHero(2.0)
		if enemy == nil and seenLoc == nil and not hit then
			return false
		end
		local allies = #(Fu.GetAlliesNearLoc(bot:GetLocation(), 1200) or {})
		if allies < 1 then
			allies = 1
		end
		local threats = #near
		if seenLoc ~= nil then
			threats = math.max(threats, 1)
		end
		local run = threats > allies or not Fu.WeAreStronger(bot, 1200)
		bot._roshThinkAt = DotaTime() - 4
		if run then
			local away = Fu.AdjustLocationWithOffsetTowardsFountain(bot:GetLocation(), 700)
			if enemy ~= nil then
				away = Fu.VectorAway(bot:GetLocation(), enemy:GetLocation(), 600)
				away = (away + Fu.AdjustLocationWithOffsetTowardsFountain(bot:GetLocation(), 400)) / 2
			elseif seenLoc ~= nil then
				away = Fu.VectorAway(bot:GetLocation(), seenLoc, 600)
			end
			bot:Action_MoveToLocation(away)
			return true
		end
		if enemy ~= nil then
			if enemyDist <= bot:GetAttackRange() + 150 then
				bot:Action_AttackUnit(enemy, true)
			else
				bot:Action_MoveToLocation(enemy:GetLocation())
			end
			return true
		end
		if seenLoc ~= nil or hit then
			bot:Action_MoveToLocation(Fu.AdjustLocationWithOffsetTowardsFountain(bot:GetLocation(), 400))
			return true
		end
		return false
	end
	if RallyThreat() then
		return
	end
	-- Hold the fountain side until the living team is in the ring, then go in together.
	-- Two at the rally used to count as ready, so the rest never had to arrive.
	local now = DotaTime()
	-- A gap of more than 3s out of Roshan mode restarts the gather, but not during a commit: game
	-- 017, 41:42, Doom, Lich, Mirana and Medusa committed 4/4, Doom left the mode for a few
	-- seconds in the pit, the restart wiped his commit and acks, and 4s later he dropped the take
	-- as a weak group with Lich counted as declined (then Lich did the same to Doom and Mirana).
	local stillCommitted = bot._roshCommitUntil ~= nil and now < bot._roshCommitUntil
	if bot._roshGatherAt == nil or (now - (bot._roshThinkAt or 0) > 3 and not stillCommitted) then
		bot._roshGatherAt = now
		bot._roshCommitUntil = nil
		bot._roshAckSet = {}
	end
	bot._roshThinkAt = now
	bot._roshAckSet = bot._roshAckSet or {}
	local grouped, pending, required, declined, coming =
		RoshanGather(roshanLocation, now - bot._roshGatherAt, bot._roshAckSet)
	local elapsed = now - bot._roshGatherAt
	-- Nobody else acked: drop the call (no solo Roshan) and do not re-call for 30s.
	if elapsed >= ACK_GRACE and required < 2 then
		if now >= (bot._roshNoAckUntil or -999) then
			RoshLog("drop why=nobody-acked declined=%s", #declined > 0 and table.concat(declined, ",") or "-")
		end
		bot._roshNoAckUntil = now + 30
		-- Stop hitting Roshan alone: the last order (attack) would keep running.
		bot:Action_MoveToLocation(Fu.AdjustLocationWithOffsetTowardsFountain(bot:GetLocation(), 400))
		return
	end
	-- The allies who acked are not enough to kill Roshan (the desire check counts every living
	-- ally, decliners included): drop and do not re-call for 30s. Not once committed.
	if
		elapsed >= ACK_GRACE
		and not (bot._roshCommitUntil ~= nil and now < bot._roshCommitUntil)
		and not Fu.HasEnoughDPSForRoshan(coming)
	then
		bot._roshNoAckUntil = now + 30
		RoshLog(
			"drop why=weak-group coming=%d declined=%s",
			#coming,
			#declined > 0 and table.concat(declined, ",") or "-"
		)
		return
	end
	local othersWalking = pending > 1800
	local minimum = math.min(GatherMinimum(), math.max(required, 1))
	local full = required > 0 and grouped >= required
	local committed = bot._roshCommitUntil ~= nil and now < bot._roshCommitUntil
	-- A short wait lets allies switch into the call. After that, the minimum group goes
	-- in as soon as nobody else is still walking. The old flat 22s wait was where kill
	-- windows ran out and the whole group walked away again.
	local arrived = not othersWalking and grouped >= minimum and elapsed >= 6
	-- Waiting for a straggler would outlast the kill window: go with who is here.
	local windowTight = false
	local left = KillWindow.WindowLeft()
	if othersWalking and grouped >= minimum and left ~= nil then
		local _, _, killTime = TakeTimeNeeded(roshanLocation)
		local window = left + KillWindow.TransitGrace(roshanLocation)
		windowTight = window < pending / 320 + killTime + 3
	end
	local capped = elapsed >= 40 and grouped >= math.min(2, math.max(required, 1))
	if safe and (full or arrived or windowTight or capped) then
		local fresh = not committed
		bot._roshCommitUntil = now + 25
		committed = true
		if fresh then
			RoshLog(
				"commit grouped=%d/%d min=%d pending=%d elapsed=%.0f by=%s",
				grouped,
				required,
				minimum,
				math.floor(pending),
				elapsed,
				full and "full" or (arrived and "arrived" or (windowTight and "window" or "cap"))
			)
		end
	end
	local ready = safe and (committed or full or arrived or windowTight or capped)
	if not ready and now >= (bot._roshGatherLogAt or -999) then
		bot._roshGatherLogAt = now + 5
		local _, safeWhy = IsRoshanEngageSafe(roshanLocation, finishing)
		RoshLog(
			"gather grouped=%d/%d min=%d pending=%d elapsed=%.0f safe=%s window=%s declined=%s",
			grouped,
			required,
			minimum,
			math.floor(pending),
			elapsed,
			safe and "ok" or tostring(safeWhy),
			left ~= nil and string.format("%.0f", left) or "-",
			#declined > 0 and table.concat(declined, ",") or "-"
		)
	end
	if not ready then
		bot._roshCommitUntil = nil
		if GetUnitToLocationDistance(bot, rally) > 50 then
			if not ObjectiveTravel.Go(bot, rally, "roshan") then
				bot:Action_MoveToLocation(rally + RandomVector(80))
			end
		end
		if elapsed < 2 then
			local myId = bot:GetPlayerID()
			local caller = true
			local players = GetTeamPlayers(GetTeam())
			for wasRoshanAlive = 1, #players do
				local ally = GetTeamMember(wasRoshanAlive)
				if
					ally ~= nil
					and ally ~= bot
					and ally:IsAlive()
					and not ally:IsIllusion()
					and AllyActiveMode(ally) == BOT_MODE_ROSHAN
					and ally:GetPlayerID() < myId
				then
					caller = false
					break
				end
			end
			if caller then
				Fu.ModeAnnounce(bot, "say_roshan", 20)
			end
		end
		return
	end
	if not isInPit then
		MoveToPit()
		return
	end
	if Fu.Utils.IsValidUnit(roshan) and Fu.CanBeAttacked(roshan) then
		bot:Action_AttackUnit(roshan, true)
	else
		bot:Action_MoveToLocation(roshanLocation + RandomVector(50))
	end
end

-- [OHA-ERROR] trap (roshan). From ~11:20 every game an unwrapped entry point fails and the engine only
-- prints "Script Runtime Error: error in error handling" (its handler cannot run, typically a stack
-- overflow), then squelches it after 10 copies. Caught here and printed with its name, up to 3 times
-- per entry point per bot; the failing call still just stops, as before.
local OHA_TRAP_COUNT = {}
local function OHA_Trap(name, fn, fallback)
	if type(fn) ~= "function" then
		return fn
	end
	return function(...)
		local res = { pcall(fn, ...) }
		if res[1] then
			return unpack(res, 2)
		end
		local errorCount = (OHA_TRAP_COUNT[name] or 0) + 1
		OHA_TRAP_COUNT[name] = errorCount
		if errorCount <= 3 then
			local hero = "?"
			pcall(function()
				hero = GetBot():GetUnitName()
			end)
			pcall(print, string.format("[OHA-ERROR] t=%.1f %s %s: %s", DotaTime(), hero, name, tostring(res[2])))
		end
		return fallback
	end
end
GetDesire = OHA_Trap("ROSHAN_GetDesire", GetDesire, 0)
Think = OHA_Trap("ROSHAN_Run", Think, nil)
-- [OHA-PERF] timing (#52): FuncLib/systems/perf.lua
do
	local Perf = require(GetScriptDirectory() .. "/FuncLib/systems/perf")
	GetDesire = Perf.Wrap("roshan.GetDesire", GetDesire)
	Think = Perf.Wrap("roshan.Think", Think)
end
