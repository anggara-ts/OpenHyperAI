-- [OHA-HUNT] (#165): what happens between a hunting spell and the hit, for heroes whose spell carries them to one
-- enemy hero: Clinkz's Skeleton Walk, Nyx Assassin's Vendetta, Spirit Breaker's Charge of Darkness. Diagnostics
-- only: it reads state and prints, it never orders anything.
-- Ticked from team roam's GetDesire (every think, any active mode). State lives on the bot handle (bot._huntTrace).
--   start spell= target= mode= dist=          the spell's modifier is up and its target is an enemy hero
--   mode-change from= to= dist=               the active mode changed during the hunt (first 8 per hunt)
--   interrupt by=snipe|other unit= dist=      an attack on another unit during the hunt (first of each per hunt)
--   end why=hit|cancel|lost|died|timeout dist= lasted= changes= snipe= other=
local HuntTrace = {}

-- target(bot): the hunt's target as the hero script knows it, or nil (an escape cast: no trace).
local SPECS = {
	-- Skeleton Walk (clinkz_wind_walk). Main's hero_clinkz.lua keeps no target of its own: its engage cast is for
	-- the bot's target 1600+ away; open PR #97 adds bot._huntTarget. Read both, nil-safe.
	npc_dota_hero_clinkz = {
		modifier = "modifier_clinkz_wind_walk",
		spell = "skeleton_walk",
		noRetreat = true,
		target = function(bot)
			return bot._huntTarget or bot:GetTarget() or bot:GetAttackTarget()
		end,
	},
	-- Vendetta: hero_nyx_assassin.lua sets bot.canVendettaKill / bot.vendettaTarget for its kill and engage casts.
	npc_dota_hero_nyx_assassin = {
		modifier = "modifier_nyx_assassin_vendetta",
		spell = "vendetta",
		target = function(bot)
			if bot.canVendettaKill then
				return bot.vendettaTarget
			end
			return nil
		end,
	},
	-- Charge of Darkness: hero_spirit_breaker.lua notes its cast target in bot._chargeTarget; bot.chargeRetreat
	-- marks an escape charge (on a creep).
	npc_dota_hero_spirit_breaker = {
		modifier = "modifier_spirit_breaker_charge_of_darkness",
		spell = "charge",
		target = function(bot)
			if bot.chargeRetreat then
				return nil
			end
			return bot._chargeTarget
		end,
	},
}

function HuntTrace.IsTraced(unitName)
	return SPECS[unitName] ~= nil
end

local function shortName(unit)
	local name = unit ~= nil and not unit:IsNull() and unit:GetUnitName() or "none"
	return (string.gsub(name, "npc_dota_hero_", ""))
end

local function enemyHero(bot, unit)
	if unit == nil or unit:IsNull() or not unit:IsAlive() or not unit:IsHero() then
		return nil
	end
	if unit:GetTeam() == bot:GetTeam() then
		return nil
	end
	return unit
end

-- How a hunt ended, once the spell's modifier is gone (and up to 1s more for the hit to land: Clinkz's arrow).
--   alive/seen  the target; damaged: it was damaged by the bot in the last second; waited: seconds since the end
-- Returns the reason, or nil to wait another think.
function HuntTrace.EndWhy(alive, seen, damaged, waited)
	if alive and seen and damaged then
		return "hit"
	end
	if waited < 1 then
		return nil
	end
	if not alive or not seen then
		return "lost"
	end
	return "cancel"
end

function HuntTrace.FormatEnd(now, hero, why, dist, lasted, h)
	return string.format(
		"[OHA-HUNT] t=%.0f %s end why=%s dist=%d lasted=%.1f spell=%s target=%s changes=%d snipe=%d other=%d",
		now,
		hero,
		why,
		dist,
		lasted,
		h.spell,
		h.targetName,
		h.changes,
		h.snipe,
		h.other
	)
end

local function finish(bot, hero, h, why, now)
	bot._huntTrace = nil
	pcall(print, HuntTrace.FormatEnd(now, hero, why, h.dist or -1, now - h.t, h))
end

-- Team roam's Think attacked its last-hit creep (the snipe) while a hunt is on.
function HuntTrace.NoteSnipe(bot, unit)
	local h = bot._huntTrace
	if h == nil then
		return
	end
	h.snipe = h.snipe + 1
	if h.snipe == 1 then
		pcall(
			print,
			string.format(
				"[OHA-HUNT] t=%.0f %s interrupt by=snipe unit=%s dist=%d spell=%s target=%s",
				DotaTime(),
				shortName(bot),
				shortName(unit),
				h.dist or -1,
				h.spell,
				h.targetName
			)
		)
	end
end

-- modeName: the active mode's name (RoamStats.ModeName).
function HuntTrace.Tick(bot, modeName)
	local spec = SPECS[bot:GetUnitName()]
	if spec == nil then
		return
	end
	local now = DotaTime()
	local hero = shortName(bot)
	local h = bot._huntTrace
	if h ~= nil and (not bot:IsAlive() or now - h.seen > 3) then
		-- A gap of 3s+ in the ticks: mode desires are not asked while the bot is dead (unverified).
		finish(bot, hero, h, "died", now)
		return
	end
	if not bot:IsAlive() then
		return
	end
	local on = bot:HasModifier(spec.modifier)
	if h == nil then
		if not on then
			bot._huntTraceSkip = nil
			return
		end
		if bot._huntTraceSkip then
			return
		end
		local target = enemyHero(bot, spec.target(bot))
		if target == nil or spec.noRetreat and modeName == "retreat" then
			-- Clinkz walks invisible for many reasons: keep looking for a hero target during the walk. The others
			-- know their target at the cast: no target means an escape, skip this cast.
			bot._huntTraceSkip = not spec.noRetreat
			return
		end
		h = {
			t = now,
			seen = now,
			spell = spec.spell,
			target = target,
			targetName = shortName(target),
			mode = modeName,
			dist = math.floor(GetUnitToUnitDistance(bot, target)),
			changes = 0,
			snipe = 0,
			other = 0,
		}
		bot._huntTrace = h
		pcall(
			print,
			string.format(
				"[OHA-HUNT] t=%.0f %s start spell=%s target=%s mode=%s dist=%d",
				now,
				hero,
				h.spell,
				h.targetName,
				modeName,
				h.dist
			)
		)
		return
	end
	h.seen = now
	local target = h.target
	local alive = target ~= nil and not target:IsNull() and target:IsAlive()
	local seen = alive and target:CanBeSeen()
	if seen then
		h.dist = math.floor(GetUnitToUnitDistance(bot, target))
	end
	if modeName ~= h.mode then
		h.changes = h.changes + 1
		if h.changes <= 8 then
			pcall(
				print,
				string.format(
					"[OHA-HUNT] t=%.0f %s mode-change from=%s to=%s dist=%d spell=%s target=%s",
					now,
					hero,
					h.mode,
					modeName,
					h.dist or -1,
					h.spell,
					h.targetName
				)
			)
		end
		h.mode = modeName
	end
	local attackTarget = bot:GetAttackTarget()
	if attackTarget ~= nil and attackTarget ~= target and attackTarget ~= h.lastOther then
		h.lastOther = attackTarget
		h.other = h.other + 1
		if h.other == 1 then
			pcall(
				print,
				string.format(
					"[OHA-HUNT] t=%.0f %s interrupt by=other unit=%s dist=%d spell=%s target=%s mode=%s",
					now,
					hero,
					shortName(attackTarget),
					h.dist or -1,
					h.spell,
					h.targetName,
					modeName
				)
			)
		end
	end
	if on then
		h.offAt = nil
		if now - h.t > 60 then
			finish(bot, hero, h, "timeout", now)
		end
		return
	end
	h.offAt = h.offAt or now
	local damaged = seen and target:WasRecentlyDamagedByHero(bot, 1.0)
	local why = HuntTrace.EndWhy(alive, seen, damaged, now - h.offAt)
	if why ~= nil then
		finish(bot, hero, h, why, now)
	end
end

return HuntTrace
