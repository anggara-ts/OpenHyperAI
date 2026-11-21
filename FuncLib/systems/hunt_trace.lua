-- [OHA-HUNT] (#165): what happens between a hunting spell and the hit, for heroes whose spell carries them to one
-- enemy hero: Clinkz's Skeleton Walk, Nyx Assassin's Vendetta, Spirit Breaker's Charge of Darkness. Diagnostics
-- only: it reads state and prints, it never orders anything.
-- Ticked from team roam's GetDesire (every think, any active mode). State lives on the bot handle (bot._huntTrace).
--   start spell= target= mode= dist=          the spell's modifier is up and its target is an enemy hero
--   mode-change from= to= dist=               the active mode changed during the hunt (first 8 per hunt)
--   interrupt by=snipe|other unit= dist=      an attack on another unit during the hunt (first of each per hunt)
--   end why=kill|hit|cancel|lost|died|timeout dist= lasted= changes= snipe= other=
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

-- How a hunt ended, once the spell's modifier is gone (the reveal: Clinkz's attack, Nyx's Vendetta strike, the
-- charge's bash). Game 063 counted Clinkz's reveals that killed Nevermore (15:32), Furion (20:36) and Shadow Fiend
-- (49:05) as "lost": the target was dead, so not "damaged and seen". Now:
--   kill    the target died within KILL_WINDOW after the reveal, or within KILL_WINDOW of the hunter's last hit
--   hit     the hunter damaged it after the reveal (and it lived through the window)
--   lost    dead without the hunt's part in it, or out of sight at the end of the window
--   cancel  alive and visible, never hit
--   alive/seen     the target now
--   waited         seconds since the reveal
--   deadAfter      seconds from the reveal to the target's death (negative: died before it), nil while alive
--   hitToDeath     seconds from the hunter's last damage on it to its death, nil if never damaged or alive
--   hit            the hunter damaged it since the reveal (1s before it counts: the arrow is in the air)
-- Returns the reason, or nil to wait another think.
local KILL_WINDOW = 3
HuntTrace.KILL_WINDOW = KILL_WINDOW
function HuntTrace.EndWhy(alive, seen, waited, deadAfter, hitToDeath, hit)
	if not alive then
		if deadAfter ~= nil and deadAfter >= -0.5 and deadAfter <= KILL_WINDOW then
			return "kill"
		end
		if hitToDeath ~= nil and hitToDeath <= KILL_WINDOW then
			return "kill"
		end
		return "lost"
	end
	if waited < KILL_WINDOW then
		return nil
	end
	if hit then
		return "hit"
	end
	if not seen then
		return "lost"
	end
	return "cancel"
end

-- Is the hunt's target dead? Game 064: 5 of 16 "kill" ends had a living target (Clinkz: Puck had teleported home,
-- Hoodwink was 2710 away or under Shadow Amulet): the handle's IsAlive() reads false for an enemy that teleported,
-- turned invisible or left vision. Only the scoreboard confirms a death: the target player's GetHeroDeaths went up
-- since the hunt started. Returns dead, and how it was read ("deaths", or "unread" when the count is unreadable:
-- then never dead, so a not-alive handle is a target out of sight and the hunt ends hit / lost).
function HuntTrace.TargetDead(deathsAtStart, deathsNow)
	if deathsAtStart ~= nil and deathsNow ~= nil then
		return deathsNow > deathsAtStart, "deaths"
	end
	return false, "unread"
end

function HuntTrace.FormatEnd(now, hero, why, dist, lasted, h)
	return string.format(
		"[OHA-HUNT] t=%.0f %s end why=%s dist=%d lasted=%.1f spell=%s target=%s changes=%d snipe=%d other=%d death=%s",
		now,
		hero,
		why,
		dist,
		lasted,
		h.spell,
		h.targetName,
		h.changes,
		h.snipe,
		h.other,
		h.deathCheck or "unread"
	)
end

-- The target player's death count (the scoreboard), or nil when it cannot be read.
local function heroDeaths(unit)
	if unit == nil or unit:IsNull() then
		return nil
	end
	local okP, pid = pcall(function()
		return unit:GetPlayerID()
	end)
	if not okP or type(pid) ~= "number" or pid < 0 then
		return nil
	end
	local okD, deaths = pcall(GetHeroDeaths, pid)
	if okD and type(deaths) == "number" then
		return deaths
	end
	return nil
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
			deaths = heroDeaths(target),
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
	-- The handle can read not-alive for a living enemy out of sight: alive unless the scoreboard has the death.
	local handleAlive = target ~= nil and not target:IsNull() and target:IsAlive()
	local dead, deathCheck = HuntTrace.TargetDead(h.deaths, heroDeaths(target))
	h.deathCheck = deathCheck
	local alive = not dead
	local seen = handleAlive and not dead and target:CanBeSeen()
	if seen then
		h.dist = math.floor(GetUnitToUnitDistance(bot, target))
		if target:WasRecentlyDamagedByHero(bot, 1.0) then
			h.hitAt = now
		end
	end
	if not alive and h.deadAt == nil then
		h.deadAt = now
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
	local deadAfter = h.deadAt ~= nil and h.deadAt - h.offAt or nil
	local hitToDeath = h.deadAt ~= nil and h.hitAt ~= nil and h.deadAt - h.hitAt or nil
	local hit = h.hitAt ~= nil and h.hitAt >= h.offAt - 1
	local why = HuntTrace.EndWhy(alive, seen, now - h.offAt, deadAfter, hitToDeath, hit)
	if why ~= nil then
		finish(bot, hero, h, why, now)
	end
end

return HuntTrace
