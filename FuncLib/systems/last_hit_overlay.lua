-- Last-hit overlay (#165, mode flip-flops). Team roam's last-hit snipe and its hunt on a creep (a lane creep, a deny,
-- a neutral, a tower) used to win team roam as a mode for one hit: farm -> team_roam -> farm every few seconds
-- (game 063: 2102 team roam activations in 576 bot-minutes, 75% under 1s; the snipe 62% of them, the creep hunts
-- most of the rest). Now team roam only offers the hit (Offer, from its GetDesire, every think) and this hook issues
-- it from ability_item_usage_generic.lua's ItemUsageThink, after the active mode's Think, so the bot stays in its
-- mode. The hit fires only where team roam would have won the mode (its desire above the active mode's), with the
-- same conditions as before, and never while retreating, dodging, invisible, charging, channeling or casting.
-- [OHA-ROAM] overlay-hit / overlay-skip; the [OHA-ROAMSTAT] snipeLH / creepLH shares measure the last hits.
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

-- The state OverlaySkipWhy reads.
function X.State(bot, desire)
	local mode = bot:GetActiveMode()
	return {
		desire = desire,
		modeDesire = bot:GetActiveModeDesire(),
		retreat = mode == BOT_MODE_RETREAT,
		evasive = mode == BOT_MODE_EVASIVE_MANEUVERS,
		invisible = bot:IsInvisible() and not INVISIBLE_ATTACKERS[bot:GetUnitName()],
		-- Charge of Darkness, or a traced hunting spell (Skeleton Walk, Vendetta, Charge) and 1s after its reveal, when
		-- the hit belongs to the hero (hunt_trace.lua: offAt = the reveal).
		charging = bot:HasModifier("modifier_spirit_breaker_charge_of_darkness")
			or bot._huntTrace ~= nil and (bot._huntTrace.offAt == nil or DotaTime() - bot._huntTrace.offAt < 1),
		channeling = bot:IsChanneling(),
		-- Casting, a queued order, stunned, hexed or disarmed (Fu.CanNotUseAction covers the first ones), or the
		-- current order is a cast (the mode's Think may have just ordered a TP or a ward: don't replace it).
		busy = Fu.CanNotUseAction(bot)
			or bot:IsDisarmed()
			or bot:IsHexed()
			or bot:GetCurrentActionType() == BOT_ACTION_TYPE_USE_ABILITY,
	}
end

local function logSkip(bot, why, offer)
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
			"[OHA-ROAM] t=%.0f %s overlay-skip why=%s rule=%s unit=%s mode=%s",
			DotaTime(),
			shortName(bot),
			why,
			offer.why,
			offer.unit:GetUnitName(),
			RoamStats.ModeName(bot:GetActiveMode())
		)
	)
end

-- ItemUsageThink, every think (after the active mode's Think). Returns true when it ordered the hit; the order is
-- repeated every think until the unit dies, as team roam's Think did, so a later order in the same think (an item,
-- a spell) still replaces it, as it did while team roam ran.
function X.Think(bot)
	local offer = bot._lhOffer
	if offer == nil then
		return false
	end
	local now = DotaTime()
	if now - offer.t > OFFER_MAX_AGE or not unitUsable(offer.unit) then
		bot._lhOffer = nil
		return false
	end
	local why = Rules.OverlaySkipWhy(X.State(bot, offer.desire))
	if why ~= nil then
		logSkip(bot, why, offer)
		return false
	end
	local unit = offer.unit
	local mode = bot:GetActiveMode()
	-- A new unit (or the same one after a pause): one try for the last-hit share, one log line (10s throttle).
	if unit ~= bot._lhUnit or now - (bot._lhAt or -99) > 1.5 then
		local modeName = mode == BOT_MODE_TEAM_ROAM and "team_roam" or RoamStats.ModeName(mode)
		local stats = bot._roamStats
		if stats == nil then
			stats = RoamStats.New()
			bot._roamStats = stats
		end
		pcall(RoamStats.NoteOverlay, stats, now, offer.why, modeName, bot:GetLastHits())
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
					offer.why,
					unit:GetUnitName(),
					modeName,
					offer.desire,
					bot:GetActiveModeDesire(),
					GetUnitToUnitDistance(bot, unit)
				)
			)
		end
	end
	bot._lhUnit, bot._lhAt = unit, now
	bot:Action_AttackUnit(unit, true)
	return true
end

return X
