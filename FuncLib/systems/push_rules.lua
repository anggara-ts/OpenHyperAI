-- Shared bot system: pure push / Roshan team rules (no bot API calls), so they can be tested with real numbers.
-- Used by FuncLib/systems/push.lua, FuncLib/systems/kill_window.lua and mode_roshan_generic.lua (#12).
local PushRules = {}

-- Respawn seconds of a dead enemy at `level`, from what our own heroes' deaths showed (learned[level] = seconds,
-- the same rules hold for both teams). Enemy heroes can't be asked: GetRespawnTime() on an enemy handle never
-- answered (games 066/067: all 50+ enemy deaths logged `respawn=30s known=false`), so the window used a flat 30s
-- while late-game respawns ran 70-125s (own deaths, `[OHA-DEATH] ... respawned=`), and Roshan calls were dropped
-- as window-short. Nearest learned level wins (ties: the higher one); nothing learned or no level: `default`. A value
-- learned at a lower level never goes under `default` (early samples of 12-20s must not shorten a level-20 window).
-- Returns seconds, source ("learned" or "default"), level used.
function PushRules.RespawnEstimate(learned, level, default)
	if type(learned) ~= "table" or type(level) ~= "number" or level < 1 then
		return default, "default", nil
	end
	local bestLevel, bestGap = nil, nil
	for knownLevel, seconds in pairs(learned) do
		if type(knownLevel) == "number" and type(seconds) == "number" and seconds > 0 then
			local gap = math.abs(knownLevel - level)
			if bestGap == nil or gap < bestGap or gap == bestGap and knownLevel > bestLevel then
				bestLevel, bestGap = knownLevel, gap
			end
		end
	end
	if bestLevel == nil then
		return default, "default", nil
	end
	if bestLevel < level then
		return math.max(learned[bestLevel], default or 0), "learned", bestLevel
	end
	return learned[bestLevel], "learned", bestLevel
end

-- Advantage window (#12, maintainer 2026-11-21: "when a team picks aegis, raise the push desire as long as our base
-- is not being pushed" and "5 enemies death also should affect push desire"). One rule:
--   s.aegis        our team holds the Aegis
--   s.alliesAlive  our heroes alive
--   s.enemiesAlive enemy heroes alive
--   s.dead         enemy heroes dead with more than 5s of respawn left
--   s.deadLong     enemy heroes dead with 20s+ of respawn left
--   s.baseThreat   enemy heroes on our high ground / at our Ancient, or 2+ enemy creeps at our Ancient
-- Returns desire (nil when no window) and why.
--   every enemy dead: 0.9 (wipe); 3+ dead for 20s+: 0.9; 2+ dead with 4-5 of ours alive: 0.8;
--   Aegis with 4+ alive: 0.8 (0.85 on top of a dead window).
function PushRules.Advantage(s)
	if s == nil then
		return nil, "none"
	end
	if s.baseThreat then
		return nil, "base-threat"
	end
	local alliesAlive = s.alliesAlive or 0
	local enemiesAlive = s.enemiesAlive or 5
	local desire, why = nil, "none"
	if alliesAlive >= 1 and enemiesAlive == 0 then
		desire, why = 0.9, "wipe"
	elseif (s.deadLong or 0) >= 3 and alliesAlive > enemiesAlive then
		desire, why = 0.9, "dead3"
	elseif (s.dead or 0) >= 2 and alliesAlive >= 4 and alliesAlive > enemiesAlive then
		desire, why = 0.8, "dead2"
	end
	if s.aegis and alliesAlive >= 4 then
		if desire == nil then
			desire, why = 0.8, "aegis"
		else
			desire, why = math.max(desire, 0.85), why .. "+aegis"
		end
	end
	return desire, why
end

-- The push cap while every enemy hero is alive and we don't have more alive (#12, game 067 33:00 and game 066
-- 67:54-81:58: `lock-capped why=cap desire=0.41 allies=2 alive=5/5` kept 3 of 5 farming at 0.6-0.77 farm).
--   s.enemiesAlive, s.alliesAlive, s.nwLead (our inventory net worth minus theirs), s.levelLead (our average level
--   minus theirs), s.tier (next target on the lane: 1 = T1, 2 = T2, 3 = high ground, 4 = Ancient)
-- Returns cap, joiners (how many bots, closest to the lane front first, may push above it), why; nil when the cap
-- does not apply. Ahead = 2000+ net worth or 1+ average level, the mirror of the behind-stop rule in push.lua.
function PushRules.FiveAliveCap(s)
	if s == nil or (s.enemiesAlive or 0) < 5 or (s.alliesAlive or 0) > (s.enemiesAlive or 0) then
		return nil, 5, "off"
	end
	local ahead = (s.nwLead or 0) >= 2000 or (s.levelLead or 0) >= 1
	local outer = (s.tier or 3) <= 2
	if ahead and outer then
		return 0.75, 4, "ahead+outer"
	elseif ahead then
		return 0.7, 3, "ahead"
	elseif outer then
		return 0.7, 3, "outer"
	end
	return 0.41, 2, "even"
end

-- A Roshan call the team answers outranks a push (#12, game 067 32:11: a 4-bot kill-window call at 0.60 lost to a
-- 0.99 kill push; 20s later every call dropped window-short). Returns the push desire to use and whether it yielded.
--   roshDesire / roshAge: this bot's Roshan desire and how many seconds ago it was computed. Only a gather call
--   (0.9+: a team call, or a kill-window take that fits) wins; a plain 0.60 call (timer, or a kill window held back
--   while the team is on the T2 / high ground or in a fight) does not cut the push.
--   finishingTower: the push is finishing a tower the group can kill in ~5s (that one goes first)
function PushRules.PushUnderRosh(pushDesire, roshDesire, roshAge, finishingTower)
	if type(pushDesire) ~= "number" or type(roshDesire) ~= "number" then
		return pushDesire, false
	end
	if finishingTower or (roshAge or 99) > 1.5 or roshDesire < 0.9 or pushDesire < roshDesire then
		return pushDesire, false
	end
	return math.max(0, roshDesire - 0.05), true
end

return PushRules
