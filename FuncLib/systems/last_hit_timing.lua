-- Last-hit timing every frame (#71, game 063: 105 got / 103 missed; 71 misses had no attack launched before the creep
-- died, 58 of them on a walk-in). The laning mode's Think runs only about 3 times a second (game 063 [OHA-PERF]: mode
-- GetDesire ~32 calls per 10s, ItemUsageThink 300), so its hit orders can be up to ~0.3s late. The laning Think still
-- picks the creep and walks in (Arm); this module, called every frame from ability_item_usage_generic.lua's
-- ItemUsageThink, then:
--   walk / hold  attacks on the frame the hit becomes sure (or early, see below) instead of at the next mode think;
--   wind-up      re-predicts the creep's HP at the moment our hit lands (attacks in flight, creeps and towers mid-swing,
--                our tower's next shot), lets the hit go when it kills, and cancels a hit that started early (the
--                creep was within 1.5 of our hits) and would not kill, just before the attack point; then holds and
--                attacks again at the right moment. Never cancels a hit that was sure when its wind-up started, a
--                deny or a harass hit (those never arm this).
-- The pure decisions are in last_hit_rules.lua. Logs: [OHA-LH] release / cancel / cancel-result and the per-minute
-- [OHA-LH] minute summary. Other per-frame code (kiting #72, team roam's overlay #165) can ask X.IsTiming(bot) to keep
-- its hands off while a last hit is being timed.
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local Rules = require(GetScriptDirectory() .. "/FuncLib/systems/last_hit_rules")

local X = {}

local ATTACK_ACTIVITY = 1503
-- A state not re-armed by the laning Think for this long is stale (the Think runs ~3 times a second).
local ARM_MAX_AGE = 1.0
local LOG_EVERY = 3

local function heroName(bot)
	return (string.gsub(bot:GetUnitName(), "npc_dota_hero_", ""))
end

-- Seconds between frames of this bot's ItemUsageThink (smoothed), 0.02..0.4.
local function noteFrame(bot, now)
	local last = bot._lhtFrameAt
	bot._lhtFrameAt = now
	if last ~= nil and now > last and now - last < 1 then
		bot._lhtGap = (bot._lhtGap or 0.05) * 0.8 + (now - last) * 0.2
	end
end
function X.FrameGap(bot)
	return math.min(0.4, math.max(0.02, bot._lhtGap or 0.1))
end

local function isRangedAttacker(bot)
	return bot:GetAttackRange() > 320 or bot:GetUnitName() == "npc_dota_hero_templar_assassin"
end

-- Projectile flight from bot to creep (0 for melee), as Fu.GetAttackProDelayTime counts it.
function X.TravelTime(bot, creep)
	if not isRangedAttacker(bot) then
		return 0
	end
	local offset = bot:GetPrimaryAttribute() == ATTRIBUTE_INTELLECT and 59 or 39
	local distance = math.min(GetUnitToUnitDistance(bot, creep) - offset, bot:GetAttackRange())
	return math.max(0, distance) / math.max(1, bot:GetAttackProjectileSpeed())
end

-- Our tower's next shot on a creep (#71, game 045): when an allied tower is attacking this creep and its next shot
-- lands before our hit (hitDelay seconds from now), the damage it deals, else 0.
function X.TowerShotBefore(bot, creep, hitDelay)
	-- An unreachable hit (delay inf, game 046: a melee bot far from the creep) has no timing to plan.
	if hitDelay == nil or hitDelay ~= hitDelay or hitDelay > 3 then
		return 0
	end
	for _, tower in pairs(bot:GetNearbyTowers(1000, false) or {}) do
		if Fu.IsValidBuilding(tower) and tower:GetAttackTarget() == creep then
			local nextShot = tower:GetLastAttackTime() + tower:GetSecondsPerAttack()
			local travel = GetUnitToUnitDistance(tower, creep) / math.max(1, tower:GetAttackProjectileSpeed())
			if nextShot + travel < GameTime() + hitDelay then
				return creep:GetActualIncomingDamage(tower:GetAttackDamage(), DAMAGE_TYPE_PHYSICAL)
			end
		end
	end
	return 0
end

-- The creep's HP when our hit lands in delay seconds: predictedHp, ourHit (our damage on it after armour),
-- incomingKills (the other hits alone kill it first). Same sums as Fu.WillKillTarget, with the tower shot as a hit
-- that lands first.
function X.Predict(creep, damage, delay, towerShot)
	towerShot = towerShot or 0
	local effectiveHealth = creep:GetHealth() + creep:GetHealthRegen() * delay + 0.8
	local incoming = Fu.GetTotalAttackWillRealDamage(creep, delay)
	local ourHit = creep:GetActualIncomingDamage(damage, DAMAGE_TYPE_PHYSICAL)
	local incomingKills = incoming >= effectiveHealth - 1 or (towerShot > 0 and towerShot >= creep:GetHealth())
	return effectiveHealth - incoming - towerShot, ourHit, incomingKills
end

-- Seconds until an enemy lane creep dies to our lane creeps and towers hitting it, our own hit not counted
-- (LastHitRules.DeathEta), and that damage per second. Heroes are left out: their hits on lane creeps come and go (a
-- support's backup hit, a core's last hit), the creeps and towers keep swinging.
function X.DeathEta(bot, creep)
	local dps = 0
	local function add(unit)
		if Fu.IsValid(unit) and unit:GetAttackTarget() == creep then
			local hit = creep:GetActualIncomingDamage(unit:GetAttackDamage(), DAMAGE_TYPE_PHYSICAL)
			dps = dps + hit / math.max(0.1, unit:GetSecondsPerAttack())
		end
	end
	for _, unit in pairs(bot:GetNearbyLaneCreeps(1600, false) or {}) do
		add(unit)
	end
	for _, tower in pairs(bot:GetNearbyTowers(1600, false) or {}) do
		add(tower)
	end
	local hp = creep:GetHealth() - Fu.GetCreepAttackProjectileWillRealDamage(creep, 1.0)
	return Rules.DeathEta(hp, dps), dps
end

-- The core's hit on creep: pending (attacking it and not in the previous attack's backswing / cooldown, so a hit is
-- still to come) and cooling (in the backswing / cooldown: its last hit already went out).
local function coreHitState(core, creep)
	local point = core:GetAttackPoint() / math.max(0.1, core:GetAttackSpeed())
	local cooling = GameTime() - core:GetLastAttackTime() < core:GetSecondsPerAttack() - point - 0.05
	return core:GetAttackTarget() == creep and not cooling, cooling
end

-- A support's backup hit behind its core (#71, game 064). Returns the facts for LastHitRules.BackupDecision, with
-- coreEta / myDelay for the log. The core's pending hit counts as landing first when it lands before ours; its
-- projectile in flight is already in Fu.GetTotalAttackWillRealDamage.
function X.BackupFacts(bot, core, creep, damage)
	local myDelay = Fu.GetAttackProDelayTime(bot, creep)
	local coreEta = Fu.GetAttackProDelayTime(core, creep)
	local pending, cooling = coreHitState(core, creep)
	local predictedHp, ourHit, incomingKills = X.Predict(creep, damage, myDelay, X.TowerShotBefore(bot, creep, myDelay))
	if pending and coreEta < myDelay then
		predictedHp = predictedHp - creep:GetActualIncomingDamage(core:GetAttackDamage(), DAMAGE_TYPE_PHYSICAL)
		incomingKills = incomingKills or predictedHp <= 0
	end
	-- Free: a bot core in laning mode, any core not hitting a hero, not cooling down after a hit.
	local coreTarget = core:GetAttackTarget()
	local busy = core:IsBot() and core:GetActiveMode() ~= BOT_MODE_LANING
		or coreTarget ~= nil and not coreTarget:IsNull() and coreTarget:IsHero()
	local coreCanKill = false
	if not busy and not cooling then
		local corePredicted, coreHit, coreOthersKill =
			X.Predict(creep, core:GetAttackDamage(), coreEta, X.TowerShotBefore(bot, creep, coreEta))
		coreCanKill = not coreOthersKill and coreHit > corePredicted
	end
	return {
		coreKillsFirst = incomingKills,
		coreAttacking = pending,
		coreCanKill = coreCanKill,
		myDelay = myDelay,
		coreEta = coreEta,
		ourKills = not incomingKills and ourHit > predictedHp,
	}
end

local function backupCoreOf(st)
	local core = st.backupCore
	if core == nil or core:IsNull() or not core:IsAlive() then
		return nil
	end
	return core
end

-- Classify the hit if the bot attacked now (fresh attack: turn, walk, wind-up, flight).
local function classifyNow(bot, st)
	local delay = Fu.GetAttackProDelayTime(bot, st.creep)
	local predictedHp, ourHit, incomingKills =
		X.Predict(st.creep, st.damage, delay, X.TowerShotBefore(bot, st.creep, delay))
	return Rules.Classify(predictedHp, ourHit, incomingKills, st.allowEarly), predictedHp, ourHit
end

-- Per-minute counts for the [OHA-LH] minute summary.
function X.Stats(bot)
	local stats = bot._lhtStats
	if stats == nil then
		stats = {
			since = DotaTime(),
			got = 0,
			missed = 0,
			late = 0,
			early = 0,
			cancelled = 0,
			cancelLost = 0,
			released = 0,
			sureShort = 0,
			stopOk = 0,
			stopFail = 0,
			backup = 0,
			backupGot = 0,
			backupCore = 0,
			walkSkip = 0,
			walkSkipped = {},
		}
		bot._lhtStats = stats
	end
	return stats
end

-- From the laning mode's attempt tracker when an attempt ends. backupResult: nil (not a backup), "took" (the support
-- got it), "core-took" (the core got it: not a miss for the support) or "lost".
function X.NoteResult(bot, got, launch, early, cancels, backupResult)
	local stats = X.Stats(bot)
	if backupResult ~= nil then
		stats.backup = stats.backup + 1
		if backupResult == "took" then
			stats.backupGot = stats.backupGot + 1
		elseif backupResult == "core-took" then
			stats.backupCore = stats.backupCore + 1
			return
		end
	end
	if got then
		stats.got = stats.got + 1
	else
		stats.missed = stats.missed + 1
		if launch < 0 then
			stats.late = stats.late + 1
		end
		if (cancels or 0) > 0 then
			stats.cancelLost = stats.cancelLost + 1
		end
	end
	if early then
		stats.early = stats.early + 1
	end
end

-- One line per bot per minute with any attempt.
function X.LogMinute(bot)
	local stats = bot._lhtStats
	if stats == nil or DotaTime() - stats.since < 60 then
		return
	end
	bot._lhtStats = nil
	if stats.got + stats.missed + stats.cancelled + stats.backup + stats.walkSkip == 0 then
		return
	end
	pcall(
		print,
		string.format(
			"[OHA-LH] t=%.0f %s minute got=%d missed=%d late=%d early=%d cancelled=%d cancel-lost=%d released=%d sure-short=%d stop-ok=%d stop-fail=%d backup=%d backupGot=%d backupCore=%d walk-skip=%d",
			DotaTime(),
			heroName(bot),
			stats.got,
			stats.missed,
			stats.late,
			stats.early,
			stats.cancelled,
			stats.cancelLost,
			stats.released,
			stats.sureShort,
			stats.stopOk,
			stats.stopFail,
			stats.backup,
			stats.backupGot,
			stats.backupCore,
			stats.walkSkip
		)
	)
end

-- A walk-in left out because it lands after the creep's death (counted once per creep per minute), with a throttled
-- [OHA-LH] walk-skip line.
function X.NoteWalkSkip(bot, creep, expect, death, dps, backup)
	local stats = X.Stats(bot)
	if not stats.walkSkipped[creep] then
		stats.walkSkipped[creep] = true
		stats.walkSkip = stats.walkSkip + 1
	end
	bot._lhtLogAt = bot._lhtLogAt or {}
	if DotaTime() < (bot._lhtLogAt.walkSkip or -99) then
		return
	end
	bot._lhtLogAt.walkSkip = DotaTime() + LOG_EVERY
	pcall(
		print,
		string.format(
			"[OHA-LH] t=%.0f %s walk-skip why=too-late creep-hp=%d expect=%.2f death=%.2f dps=%.0f dist=%d backup=%d",
			DotaTime(),
			heroName(bot),
			creep:GetHealth(),
			expect,
			death,
			dps,
			GetUnitToUnitDistance(bot, creep),
			backup and 1 or 0
		)
	)
end

local function throttledLog(bot, key, fmt, ...)
	bot._lhtLogAt = bot._lhtLogAt or {}
	if DotaTime() < (bot._lhtLogAt[key] or -99) then
		return
	end
	bot._lhtLogAt[key] = DotaTime() + LOG_EVERY
	pcall(print, string.format(fmt, ...))
end

-- The laning Think starts: a state it does not re-arm in this think is dropped by the next Tick.
function X.BeginThink(bot)
	local st = bot._lhTiming
	if st ~= nil then
		st.thinkAt = GameTime()
	end
end

-- Team roam's last-hit overlay (#171, FuncLib/systems/last_hit_overlay.lua, not on main yet) owns a hit while
-- bot._lhOwn is set: from its attack order until the attack is released, the unit dies or 1s passes. It runs after
-- this module in ItemUsageThink, so an order from here would replace its swing. While it owns one: no arm, no order;
-- on the same creep the overlay times it. A plain field read, so this works with or without #171.
-- [OHA-LH] skip why=overlay-owns once per hold (and at most every 3s).
local function overlayOwns(bot)
	local own = bot._lhOwn
	if own == nil then
		bot._lhtOverlaySeen = nil
		return false
	end
	if bot._lhtOverlaySeen ~= own then
		bot._lhtOverlaySeen = own
		local st = bot._lhTiming
		local unit = own.unit
		throttledLog(
			bot,
			"overlay",
			"[OHA-LH] t=%.0f %s skip why=overlay-owns ours=%s same=%s phase=%s",
			DotaTime(),
			heroName(bot),
			st ~= nil and "yes" or "no",
			(st ~= nil and st.creep == unit) and "yes" or "no",
			st ~= nil and st.phase or "-"
		)
	end
	bot._lhTiming = nil
	return true
end
X.OverlayOwns = overlayOwns

-- The laning Think orders (or keeps) a last hit on creep. info = { damage, allowEarly, walk }. Returns the state.
function X.Arm(bot, creep, info)
	if overlayOwns(bot) then
		return nil
	end
	local now = GameTime()
	local st = bot._lhTiming
	if st == nil or st.creep ~= creep then
		st = { creep = creep, cancels = 0, lastAttackSeen = bot:GetLastAttackTime() }
		bot._lhTiming = st
	end
	st.armedAt = now
	st.damage = info.damage
	st.allowEarly = info.allowEarly and X.EarlyAllowed(bot)
	st.backupCore = info.backupCore
	-- "decided": the release is decided and the swing still plays; it stays until the release is seen.
	if
		st.phase == "hold"
		or st.phase == "windup"
		or st.phase == "decided"
		or st.phase == "attack" and not info.walk
	then
		return st
	end
	st.phase = info.walk and "walk" or "attack"
	return st
end

-- True while the frame code owns this creep's hit (wind-up being watched, holding after a cancel, or an attack it
-- ordered): the laning Think then re-arms and issues no order of its own.
function X.Holding(bot, creep)
	local st = bot._lhTiming
	if st == nil or st.creep ~= creep then
		return false
	end
	-- An attack order counts only while the engine still has it (another order may have replaced it).
	return st.phase == "hold"
		or st.phase == "windup"
		or st.phase == "decided"
		or st.phase == "attack" and bot:GetAttackTarget() == creep
end

-- Early swings for this bot: off after the stop orders failed again and again (every early swing would then land
-- on a creep that survives).
local EARLY_OFF_AFTER = 4
function X.EarlyAllowed(bot)
	return not bot._lhtNoEarly
end

-- For other per-frame code: a last hit is being timed now (do not move or re-target the bot).
function X.IsTiming(bot)
	local st = bot._lhTiming
	return st ~= nil and (st.phase == "hold" or st.phase == "windup" or st.phase == "decided")
end

-- The creep (and backup core) of the hit being timed now (X.IsTiming), else nil.
function X.TimedHit(bot)
	if not X.IsTiming(bot) then
		return nil, nil
	end
	local st = bot._lhTiming
	return st.creep, st.backupCore
end

-- The laning Think keeps the hit being timed this think without changing it (a deny passed over for it).
function X.KeepTimed(bot)
	local st = bot._lhTiming
	if st ~= nil then
		st.armedAt = GameTime()
	end
end

function X.Clear(bot)
	bot._lhTiming = nil
end

local function cancelSwing(bot, st, now, pointAt, predictedHp, ourHit, remaining, why)
	-- Which order stops a wind-up is not documented for the bot API: Action_ClearActions(true) first; after two stops
	-- that did not hold (the attack released anyway) and none that did, a move order to where the bot stands.
	local method = "clear"
	if (bot._lhtStopFail or 0) >= 2 and (bot._lhtStopOk or 0) == 0 then
		method = "move"
		bot:Action_MoveToLocation(bot:GetLocation())
	else
		bot:Action_ClearActions(true)
	end
	st.cancels = st.cancels + 1
	st.phase = "hold"
	st.cancelAt = now
	st.cancelPointAt = pointAt
	st.stopPending = method
	st.windupAt = nil
	local stats = X.Stats(bot)
	stats.cancelled = stats.cancelled + 1
	local attempt = bot._lhAttempt
	if attempt ~= nil and attempt.creep == st.creep then
		attempt.cancels = (attempt.cancels or 0) + 1
	end
	throttledLog(
		bot,
		"cancel",
		"[OHA-LH] t=%.0f %s cancel creep-hp=%d predicted=%.0f hit=%.0f remaining=%.2f cycle=%.3f since=%.2f n=%d method=%s why=%s",
		DotaTime(),
		heroName(bot),
		st.creep:GetHealth(),
		predictedHp,
		ourHit,
		remaining,
		bot:GetAnimCycle(),
		now - bot:GetLastAttackTime(),
		st.cancels,
		method,
		why
	)
end

local function watchWindup(bot, st, now)
	local pointTime = bot:GetAttackPoint() / math.max(0.1, bot:GetAttackSpeed())
	if st.windupAt == nil then
		-- Seen this frame, so it started at most one frame ago.
		st.windupAt = now - X.FrameGap(bot) * 0.5
		st.early = nil
	end
	local remaining = st.windupAt + pointTime - now
	local delay = math.max(0, remaining) + X.TravelTime(bot, st.creep)
	local predictedHp, ourHit, incomingKills =
		X.Predict(st.creep, st.damage, delay, X.TowerShotBefore(bot, st.creep, delay))
	local core = backupCoreOf(st)
	local coreEta = -1
	if core ~= nil then
		-- A backup swing: the core's hit still to come and landing before ours counts too.
		coreEta = Fu.GetAttackProDelayTime(core, st.creep)
		if coreHitState(core, st.creep) and coreEta < delay then
			predictedHp = predictedHp - st.creep:GetActualIncomingDamage(core:GetAttackDamage(), DAMAGE_TYPE_PHYSICAL)
			incomingKills = incomingKills or predictedHp <= 0
		end
	end
	if st.early == nil then
		-- Sure when the swing started: never cancelled.
		st.early = Rules.Classify(predictedHp, ourHit, incomingKills, false) ~= "sure"
	end
	local decision, why = Rules.WindupDecision({
		predictedHp = predictedHp,
		ourHit = ourHit,
		incomingKills = incomingKills,
		remaining = remaining,
		frameGap = X.FrameGap(bot),
		early = st.early,
		backup = core ~= nil,
	})
	if core ~= nil and (decision == "cancel" or decision == "release") then
		throttledLog(
			bot,
			"backup",
			"[OHA-LH] t=%.0f %s backup creep-hp=%d coreEta=%.2f myEta=%.2f result=%s why=%s",
			DotaTime(),
			heroName(bot),
			st.creep:GetHealth(),
			coreEta,
			delay,
			decision,
			why
		)
	end
	if decision == "cancel" then
		cancelSwing(bot, st, now, st.windupAt + pointTime, predictedHp, ourHit, remaining, why)
		return
	end
	if decision == "release" then
		st.phase = "decided"
		local stats = X.Stats(bot)
		stats.released = stats.released + 1
		if why == "sure" then
			stats.sureShort = stats.sureShort + 1
		end
		throttledLog(
			bot,
			"release",
			"[OHA-LH] t=%.0f %s release creep-hp=%d predicted=%.0f hit=%.0f remaining=%.2f elapsed=%.2f cycle=%.3f early=%s why=%s",
			DotaTime(),
			heroName(bot),
			st.creep:GetHealth(),
			predictedHp,
			ourHit,
			remaining,
			now - st.windupAt,
			bot:GetAnimCycle(),
			st.early and "yes" or "no",
			why
		)
	end
end

-- After a cancel: did the stop hold, then attack again at the right moment.
local function watchHold(bot, st, now)
	if st.stopPending ~= nil then
		if now <= st.cancelPointAt + 0.1 then
			return
		end
		-- The attack point passed without a release (a release moves the state to "released" in Tick).
		bot._lhtStopOk = (bot._lhtStopOk or 0) + 1
		local stats = X.Stats(bot)
		stats.stopOk = stats.stopOk + 1
		throttledLog(
			bot,
			"stop",
			"[OHA-LH] t=%.0f %s cancel-result stopped=yes method=%s",
			DotaTime(),
			heroName(bot),
			st.stopPending
		)
		st.stopPending = nil
	end
	local core = backupCoreOf(st)
	local restart
	if core ~= nil then
		restart = Rules.BackupDecision(X.BackupFacts(bot, core, st.creep, st.damage)) == "go" and "sure" or "hold"
	else
		restart = Rules.RestartDecision(classifyNow(bot, st), st.cancels)
	end
	if restart ~= "hold" then
		bot:Action_AttackUnit(st.creep, true)
		st.phase = "attack"
		return
	end
	-- Standing idle, the engine may auto-attack another unit: stop it.
	local target = bot:GetAttackTarget()
	if target ~= nil and target ~= st.creep and bot:GetAnimActivity() == ATTACK_ACTIVITY then
		bot:Action_ClearActions(true)
	end
end

-- Walking in: attack on the frame the hit becomes sure, or early once in range.
local function watchWalk(bot, st)
	local core = backupCoreOf(st)
	if core ~= nil then
		-- A backup hit: only once the core's hit is due to land first (or the core cannot take it).
		local facts = X.BackupFacts(bot, core, st.creep, st.damage)
		if Rules.BackupDecision(facts) == "go" then
			bot:Action_AttackUnit(st.creep, true)
			st.phase = "attack"
			return true
		end
		return false
	end
	local kind = classifyNow(bot, st)
	if kind == "sure" then
		bot:Action_AttackUnit(st.creep, true)
		st.phase = "attack"
		return true
	end
	if
		kind == "early"
		and GetUnitToUnitDistance(bot, st.creep) <= bot:GetAttackRange() + st.creep:GetBoundingRadius()
		and Rules.CanTimeWindup(bot:GetAttackPoint() / math.max(0.1, bot:GetAttackSpeed()), X.FrameGap(bot))
	then
		bot:Action_AttackUnit(st.creep, true)
		st.phase = "attack"
		return true
	end
	return false
end

-- Every frame (ItemUsageThink). Returns true while it owns the bot's order this frame (the caller then issues none).
function X.Tick(bot)
	local now = GameTime()
	noteFrame(bot, now)
	if overlayOwns(bot) then
		return false
	end
	local st = bot._lhTiming
	if st == nil then
		return false
	end
	local creep = st.creep
	if
		bot:GetActiveMode() ~= BOT_MODE_LANING
		-- An enemy tower on us: the tower-aggro step after this hook comes first.
		or bot:WasRecentlyDamagedByTower(1.0)
		-- The last laning Think did not re-arm it (it gave another order: a deny, a harass hit). Before: only when that
		-- Think ran in this same frame, so a Think that ran after the frame's Tick left the walk / attack armed for up to
		-- ARM_MAX_AGE, and the next Tick could replace the Think's deny with the old last-hit attack.
		or (st.thinkAt ~= nil and st.thinkAt > (st.armedAt or -99))
		or now - (st.armedAt or -99) > ARM_MAX_AGE
		or creep == nil
		or creep:IsNull()
		or not creep:IsAlive()
	then
		bot._lhTiming = nil
		return false
	end
	-- Our attack released (GetLastAttackTime moves at the release: game 063's probe read 5-200s since the last attack
	-- while the swing was winding up).
	local lastAttack = bot:GetLastAttackTime()
	if lastAttack > (st.lastAttackSeen or -99) then
		st.lastAttackSeen = lastAttack
		if st.stopPending ~= nil then
			bot._lhtStopFail = (bot._lhtStopFail or 0) + 1
			local stats = X.Stats(bot)
			stats.stopFail = stats.stopFail + 1
			throttledLog(
				bot,
				"stop",
				"[OHA-LH] t=%.0f %s cancel-result stopped=no method=%s",
				DotaTime(),
				heroName(bot),
				st.stopPending
			)
			st.stopPending = nil
			if bot._lhtStopFail >= EARLY_OFF_AFTER and (bot._lhtStopOk or 0) == 0 and not bot._lhtNoEarly then
				bot._lhtNoEarly = true
				pcall(
					print,
					string.format(
						"[OHA-LH] t=%.0f %s early-off stop-fail=%d stop-ok=0",
						DotaTime(),
						heroName(bot),
						bot._lhtStopFail
					)
				)
			end
		end
		st.phase = "released"
		st.windupAt = nil
		return false
	end
	local phase = st.phase
	local swinging = bot:GetAnimActivity() == ATTACK_ACTIVITY and bot:GetAttackTarget() == creep
	if phase == "decided" then
		if swinging then
			return true
		end
		-- The swing stopped before the release (another order, a disable): wait for the next one.
		st.phase = "attack"
		return false
	end
	if phase == "attack" or phase == "windup" then
		-- A new wind-up only once the previous attack's backswing is over: activity 1503 also covers the backswing
		-- (GetLastAttackTime is the release; the next swing can start at release + seconds per attack - wind-up).
		local pointTime = bot:GetAttackPoint() / math.max(0.1, bot:GetAttackSpeed())
		local cooledDown = now - lastAttack >= bot:GetSecondsPerAttack() - pointTime - 0.05
		if swinging and (phase == "windup" or cooledDown) then
			st.phase = "windup"
			watchWindup(bot, st, now)
			return st.phase == "windup" or st.phase == "hold" or st.phase == "decided"
		end
		if phase == "windup" then
			-- The swing stopped without a release (another order, a disable): wait for the next one.
			st.phase = "attack"
			st.windupAt = nil
		end
		return false
	end
	if phase == "hold" then
		watchHold(bot, st, now)
		return true
	end
	if phase == "walk" then
		return watchWalk(bot, st)
	end
	return false
end

return X
