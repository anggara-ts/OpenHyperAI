-- Last-hit overlay (#165, mode flip-flops). Team roam's last-hit snipe and its hunt on a creep (a lane creep, a deny,
-- a neutral, a tower) used to win team roam as a mode for one hit: farm -> team_roam -> farm every few seconds
-- (game 063: 2102 team roam activations in 576 bot-minutes, 75% under 1s; the snipe 62% of them, the creep hunts
-- most of the rest). Now team roam only offers the hit (Offer, from its GetDesire, every think) and this hook issues
-- it from ability_item_usage_generic.lua's ItemUsageThink, after the active mode's Think, so the bot stays in its
-- mode. The hit fires only where team roam would have won the mode (its desire above the active mode's), with the
-- same conditions as before, and never while retreating, dodging, invisible, charging, channeling or casting.
-- Round 2 (game 064: snipe last hits fell to 62% from 84%): the active mode's Think kept ordering its own move /
-- push step / attack and replaced the swing. Now the overlay OWNS the hit from its first order on the unit until the
-- hit is released, the unit dies or 1s passes (RoamRules.OverlayHoldWhy): OhaCastGuard (global_overrides.lua) skips
-- every Lua mode Think meanwhile (HoldModeThink). Valve-run modes cannot be held, so team roam does not offer there
-- (RoamRules.SnipePath / ModeHoldable).
-- [OHA-ROAM] overlay-hit / overlay-skip / overlay-try; the [OHA-ROAMSTAT] snipeLH / creepLH shares measure the hits.
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local Rules = require(GetScriptDirectory() .. "/FuncLib/systems/team_roam_rules")
local RoamStats = require(GetScriptDirectory() .. "/FuncLib/systems/roam_stats")
local HuntTrace = require(GetScriptDirectory() .. "/FuncLib/systems/hunt_trace")

local X = {}

-- Heroes that attack out of invisibility on purpose (as TeamRoam.WillBreakInvisible): a last hit is fine for them.
local INVISIBLE_ATTACKERS = {
	npc_dota_hero_riki = true,
	npc_dota_hero_phantom_assassin = true,
	npc_dota_hero_templar_assassin = true,
	npc_dota_hero_bounty_hunter = true,
}
-- An offer older than this is from an earlier think (team roam's GetDesire did not run since).
local OFFER_MAX_AGE = 0.5
-- "An enemy hero in range" for FightingHero: the bot's attack range plus this.
local FIGHT_RANGE_SLACK = 150

local function shortName(unit)
	return (string.gsub(unit:GetUnitName(), "npc_dota_hero_", ""))
end

-- Team roam's GetDesire, every think: the unit to hit this think (nil: none), its desire (after team roam's
-- AdjustDesire) and the rule ("snipe", "hunt-carry/lane", ...).
function X.Offer(bot, unit, desire, why)
	if unit == nil then
		bot._lhOffer = nil
		return
	end
	bot._lhOffer = { unit = unit, desire = desire, why = why, t = DotaTime() }
end

local function unitUsable(unit)
	return unit ~= nil
		and not unit:IsNull()
		and unit:IsAlive()
		and unit:CanBeSeen()
		and not unit:IsInvulnerable()
		and not unit:IsAttackImmune()
end

-- Attack (or team roam's hero hunt) is on an enemy hero within attack range: a snipe must not take the bot off it
-- (game 064, 36:30: Clinkz sniped a creep in attack mode next to the Hoodwink his Skeleton Walk had just revealed).
function X.FightingHero(bot)
	local mode = bot:GetActiveMode()
	if mode ~= BOT_MODE_ATTACK and mode ~= BOT_MODE_TEAM_ROAM then
		return false
	end
	local target = bot:GetAttackTarget()
	if target == nil or target:IsNull() or not target:IsHero() then
		target = bot:GetTarget()
	end
	if target == nil or target:IsNull() or not target:IsAlive() or not target:IsHero() then
		return false
	end
	if target:GetTeam() == bot:GetTeam() then
		return false
	end
	return GetUnitToUnitDistance(bot, target) <= bot:GetAttackRange() + FIGHT_RANGE_SLACK
end

-- The active mode's name for RoamRules.ModeHoldable, from the BOT_MODE_* constants (a constant the API lacks is
-- skipped), nil for a mode not listed there.
local HOLD_MODE_NAMES = nil
local function holdModeName(mode)
	if HOLD_MODE_NAMES == nil then
		HOLD_MODE_NAMES = {}
		for _, pair in ipairs({
			{ BOT_MODE_LANING, "laning" },
			{ BOT_MODE_FARM, "farm" },
			{ BOT_MODE_PUSH_TOWER_TOP, "push_tower_top" },
			{ BOT_MODE_PUSH_TOWER_MID, "push_tower_mid" },
			{ BOT_MODE_PUSH_TOWER_BOT, "push_tower_bot" },
			{ BOT_MODE_ASSEMBLE, "assemble" },
			{ BOT_MODE_RUNE, "rune" },
			{ BOT_MODE_SECRET_SHOP, "secret_shop" },
			{ BOT_MODE_WARD, "ward" },
			{ BOT_MODE_ROSHAN, "roshan" },
			{ BOT_MODE_OUTPOST, "outpost" },
			{ BOT_MODE_TEAM_ROAM, "team_roam" },
			{ BOT_MODE_ATTACK, "attack" },
		}) do
			if pair[1] ~= nil then
				HOLD_MODE_NAMES[pair[1]] = pair[2]
			end
		end
	end
	return HOLD_MODE_NAMES[mode]
end

-- The active mode's Think is ours, so OhaCastGuard can hold it while the overlay owns a hit (RoamRules.ModeHoldable).
function X.ModeHoldable(bot)
	return Rules.ModeHoldable(holdModeName(bot:GetActiveMode()) or "?", bot._ohaAttackOverride)
end

-- Why the bot cannot take an attack order now (the "busy" skip), or nil. The detail goes into the skip line: game
-- 064 had 118 busy skips, most on Tiny and Primal Beast, the heroes with the most missed snipes.
local function busyWhy(bot)
	if bot:NumQueuedActions() > 0 then
		return "queued"
	end
	if bot:IsCastingAbility() or bot:IsUsingAbility() then
		return "casting"
	end
	if bot:IsDisarmed() then
		return "disarmed"
	end
	if bot:IsHexed() then
		return "hexed"
	end
	-- The current order is a cast (the mode's Think may have just ordered a TP or a ward: don't replace it).
	if bot:GetCurrentActionType() == BOT_ACTION_TYPE_USE_ABILITY then
		return "ability-order"
	end
	if Fu.CanNotUseAction(bot) then
		return "action"
	end
	return nil
end

-- The state OverlaySkipWhy reads.
function X.State(bot, desire)
	local mode = bot:GetActiveMode()
	local busy = busyWhy(bot)
	return {
		desire = desire,
		modeDesire = bot:GetActiveModeDesire(),
		retreat = mode == BOT_MODE_RETREAT,
		evasive = mode == BOT_MODE_EVASIVE_MANEUVERS,
		invisible = bot:IsInvisible() and not INVISIBLE_ATTACKERS[bot:GetUnitName()],
		-- Charge of Darkness, or a traced hunting spell (Skeleton Walk, Vendetta, Charge) for as long as its trace is
		-- open: up to HuntTrace.KILL_WINDOW (3s) after the reveal, when the hit belongs to the hero (game 064, 36:30:
		-- the old 1s block let a snipe through 1.5s after Clinkz's reveal).
		charging = bot:HasModifier("modifier_spirit_breaker_charge_of_darkness") or bot._huntTrace ~= nil,
		heroFight = X.FightingHero(bot),
		channeling = bot:IsChanneling(),
		busy = busy ~= nil,
		busyWhy = busy,
		valveMode = not X.ModeHoldable(bot),
	}
end

local function logSkip(bot, why, rule, unit, detail)
	-- "mode" is the normal case (the active mode is worth more): not logged. Throttled per reason, so a frequent one
	-- (busy) does not hide a rare one (invisible, charging).
	bot._lhSkipLogAt = bot._lhSkipLogAt or {}
	if why == "mode" or DotaTime() < (bot._lhSkipLogAt[why] or -99) then
		return
	end
	bot._lhSkipLogAt[why] = DotaTime() + 10
	pcall(
		print,
		string.format(
			"[OHA-ROAM] t=%.0f %s overlay-skip why=%s rule=%s unit=%s mode=%s%s",
			DotaTime(),
			shortName(bot),
			why,
			rule,
			unit:GetUnitName(),
			RoamStats.ModeName(bot:GetActiveMode()),
			detail ~= nil and (" detail=" .. detail) or ""
		)
	)
end

-- The hold (bot._lhOwn): from the overlay's first attack order on a unit until RoamRules.OverlayHoldWhy lets go.
local function release(bot, why)
	local own = bot._lhOwn
	bot._lhOwn = nil
	if own ~= nil and own.try ~= nil then
		own.try.release = why
		if why == "cap" then
			-- A hit that did not come in HOLD_CAP: no second hold on this unit (the mode gets the bot back).
			own.try.capped = true
		end
	end
end

local function holdWhy(bot, own)
	local unit = own.unit
	local mode = bot:GetActiveMode()
	return Rules.OverlayHoldWhy({
		now = GameTime(),
		since = own.t,
		alive = unit ~= nil and not unit:IsNull() and unit:IsAlive(),
		lastAttack = bot:GetLastAttackTime(),
		ownAttack = own.attackT,
		windup = own.windup,
		free = mode == BOT_MODE_RETREAT or mode == BOT_MODE_EVASIVE_MANEUVERS,
	})
end

-- True while the overlay owns a hit; releases it when its time is up. Other per-think orders should leave the bot
-- alone meanwhile: the #157 last-hit timing and #173 kiting hooks run before LastHitOverlay.Think in ItemUsageThink
-- and can check it.
function X.Owns(bot)
	local own = bot._lhOwn
	if own == nil then
		return false
	end
	local why = holdWhy(bot, own)
	if why ~= nil then
		release(bot, why)
		return false
	end
	return true
end

-- OhaCastGuard (global_overrides.lua), before every Lua mode Think: true = skip the Think, the overlay owns the hit.
function X.HoldModeThink(bot)
	if not X.Owns(bot) then
		return false
	end
	local own = bot._lhOwn
	own.held = own.held + 1
	if own.try ~= nil then
		own.try.held = own.try.held + 1
	end
	return true
end

local function score(bot)
	return bot:GetLastHits() + bot:GetDenies()
end

local function stats(bot)
	local s = bot._roamStats
	if s == nil then
		s = RoamStats.New()
		bot._roamStats = s
	end
	return s
end

local function isGone(unit)
	return unit == nil or unit:IsNull() or not unit:IsAlive()
end

-- [OHA-ROAM] overlay-try: one line per finished try (got throttled to one per 10s per bot, miss / drop to one per
-- 3s); the counts are in [OHA-ROAMSTAT] snipeLH / creepLH. Game 065: push-mode tries got 37/92 (farm 81%); why is
-- open (an ally hero taking the creep, the walk to a creep farther off, or a spell order replacing the swing), so the
-- line also says (diagnostics only):
--   gap=       distance to the unit minus the bot's attack range at the first order (the walk before the swing)
--   allies=    other allied heroes within ALLY_RADIUS of the unit at the first order (who may take it first)
--   replaced=  thinks of the hold that began with another order than the attack (a later order replaced it), and
--   cast=      how many of those were an ability order
local ALLY_RADIUS = 700
local function resolveTries(bot, now)
	local s = bot._roamStats
	if s == nil or s.tries == nil or #s.tries == 0 then
		return
	end
	local done = RoamStats.OverlayResolve(s, now, score(bot), isGone)
	if done == nil then
		return
	end
	bot._lhTryLogAt = bot._lhTryLogAt or {}
	for _, try in ipairs(done) do
		local key = try.result == "got" and "got" or "miss"
		if now >= (bot._lhTryLogAt[key] or -99) then
			bot._lhTryLogAt[key] = now + (key == "got" and 10 or 3)
			pcall(
				print,
				string.format(
					"[OHA-ROAM] t=%.0f %s overlay-try result=%s rule=%s mode=%s lasted=%.1f held=%d release=%s gap=%d allies=%d replaced=%d cast=%d",
					now,
					shortName(bot),
					try.result,
					try.why,
					try.mode,
					now - try.t,
					try.held,
					try.release or "none",
					try.gap or -1,
					try.allies or -1,
					try.replaced or 0,
					try.cast or 0
				)
			)
		end
	end
end

-- ItemUsageThink, every think (after the active mode's Think). Returns true when it ordered the hit. The order is
-- repeated every think while the overlay owns the hit (a later order in the same think, an item or a spell, still
-- replaces it, as it did while team roam ran).
-- Other allied heroes within ALLY_RADIUS of the unit (overlay-try allies=).
local function alliesNear(bot, unit)
	local n = 0
	for _, ally in ipairs(Fu.GetAlliesNearLoc(unit:GetLocation(), ALLY_RADIUS)) do
		if ally ~= bot then
			n = n + 1
		end
	end
	return n
end

-- While the overlay owns a hit, the bot's current order at the start of a think is still the attack, unless an order
-- after the overlay's (an item, a spell) replaced it last think (overlay-try replaced= / cast=).
local function noteReplaced(bot)
	local own = bot._lhOwn
	if own == nil or own.try == nil then
		return
	end
	local action = bot:GetCurrentActionType()
	if action == BOT_ACTION_TYPE_ATTACK then
		return
	end
	own.try.replaced = (own.try.replaced or 0) + 1
	if action == BOT_ACTION_TYPE_USE_ABILITY then
		own.try.cast = (own.try.cast or 0) + 1
	end
end

function X.Think(bot)
	local now = DotaTime()
	resolveTries(bot, now)
	noteReplaced(bot)
	local own = bot._lhOwn
	if own ~= nil and not X.Owns(bot) then
		own = nil
	end
	local offer = bot._lhOffer
	if offer ~= nil and (now - offer.t > OFFER_MAX_AGE or not unitUsable(offer.unit)) then
		bot._lhOffer = nil
		offer = nil
	end
	-- While it owns a hit the overlay stays on that unit: a newer offer (the next creep) would cancel the wind-up.
	local unit, why, desire
	if own ~= nil and unitUsable(own.unit) then
		unit, why, desire = own.unit, own.why, own.desire
		if offer ~= nil and offer.unit == unit then
			desire = offer.desire
		end
	elseif offer ~= nil then
		if own ~= nil then
			release(bot, "gone")
			own = nil
		end
		unit, why, desire = offer.unit, offer.why, offer.desire
	else
		if own ~= nil then
			release(bot, "gone")
		end
		return false
	end
	local state = X.State(bot, desire)
	local skip = Rules.OverlaySkipWhy(state)
	local s = stats(bot)
	if skip == nil and (own == nil or own.unit ~= unit) then
		-- A unit whose hold ran out (cap) gets no second one: the mode keeps the bot.
		for _, try in ipairs(s.tries or {}) do
			if try.key == unit and try.capped then
				skip = "capped"
			end
		end
	end
	if skip ~= nil then
		if bot._lhOwn ~= nil then
			release(bot, "skip-" .. skip)
		end
		logSkip(bot, skip, why, unit, skip == "busy" and state.busyWhy or nil)
		return false
	end
	local mode = bot:GetActiveMode()
	local modeName = mode == BOT_MODE_TEAM_ROAM and "team_roam" or RoamStats.ModeName(mode)
	local try, isNew = RoamStats.OverlayTry(s, now, unit, why, modeName, score(bot))
	if isNew then
		try.gap = math.floor(GetUnitToUnitDistance(bot, unit) - bot:GetAttackRange())
		try.allies = alliesNear(bot, unit)
		if bot._huntTrace ~= nil then
			pcall(HuntTrace.NoteSnipe, bot, unit)
		end
		if now >= (bot._lhLogAt or -99) then
			bot._lhLogAt = now + 10
			pcall(
				print,
				string.format(
					"[OHA-ROAM] t=%.0f %s overlay-hit rule=%s unit=%s mode=%s des=%.2f modeDes=%.2f dist=%.0f",
					now,
					shortName(bot),
					why,
					unit:GetUnitName(),
					modeName,
					desire,
					bot:GetActiveModeDesire(),
					GetUnitToUnitDistance(bot, unit)
				)
			)
		end
	end
	if bot._lhOwn == nil then
		bot._lhOwn = {
			unit = unit,
			why = why,
			desire = desire,
			t = GameTime(),
			attackT = bot:GetLastAttackTime(),
			-- The wind-up in seconds, as Fu.GetAttackProDelayTime (combat.lua): attack point / attack speed.
			windup = bot:GetAttackPoint() / math.max(bot:GetAttackSpeed(), 0.1) + 0.05,
			held = 0,
			try = try,
		}
	end
	bot:Action_AttackUnit(unit, true)
	return true
end

return X
