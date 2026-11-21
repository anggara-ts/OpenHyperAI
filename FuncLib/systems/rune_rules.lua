-- Pure rules for mode_rune_generic.lua (#32): plain numbers in, so Tests/test_rune_rules.lua can check them without
-- the bot API.
local RuneRules = {}

-- Passing-by grab (#32): does this bot leave a rune to an ally closer to it? The old rule left it to any closer ally,
-- whether or not that ally went for it. Game 066, 78:01: an invisibility rune (type 3) lay 357 from Elder Titan and
-- 382 from Earthshaker while they chased Omniknight, both said `powerrune-near-skip`, and nobody took it.
-- A closer human always has it. A closer bot has it while its active mode is the rune mode, and for the first
-- PASS_WAIT seconds this bot sees it closer (its rune mode needs a think to win). After that, a closer bot that still
-- isn't in the rune mode has given it up, and this bot takes it. waited: seconds this bot has seen that ally closer.
RuneRules.PASS_WAIT = 1.0
-- Seconds a bot that took a rune over stays its picker (renewed every think the passing grab still wants it).
RuneRules.PASS_TAKE_FOR = 3
function RuneRules.PassingYield(allyCloser, allyIsHuman, allyInRuneMode, waited)
	if not allyCloser then
		return false
	end
	if allyIsHuman or allyInRuneMode then
		return true
	end
	return waited < RuneRules.PASS_WAIT
end
-- The passing grab's desire with no enemy hero within 1200 (above a walking push or defend at 0.95, #99), and for a
-- power rune within PASS_POWER_STEP even with enemy heroes near, unless one hit the bot in the last 1.5s.
RuneRules.PASS_DESIRE = 0.97
RuneRules.PASS_POWER_STEP = 400

-- Leftover rune: a spot (river or jungle) whose status reads available while GetRuneType says -1 (no type), with
-- the spot in our vision, after the first 10s of its spawn cycle (the type reads -1 just after a spawn too: game
-- 017, the horn). Game 063: the bottom river bounty from 0:00 was never taken and read `type=-1` all game; bots
-- ordered the pick-up 14-20 times per visit at distance 0 (`blind-pickup` ... `pickup-failed tries=19`, Clinkz
-- 30:29-30:49 under creep fire), and Shadow Fiend at 15:00 left a jungle bounty reading the same (`no-rune rune=3`).
-- Game 062 (Valve's item mode in place): every one of the 9 `blind-pickup` orders on such a spot took the rune within
-- 1.6s from 70-130 away (`pickup-result taken=yes`, no `stale-status`), so a type -1 spot can hold a real rune the
-- order takes. So: one pick-up order, then stand on the spot without orders for HOLD_FOR seconds so Valve's item mode
-- can take it, then give up for this spawn cycle.
RuneRules.FRESH_SPAWN = 10
RuneRules.TRY_WAIT = 1.5
RuneRules.HOLD_FOR = 3
RuneRules.ON_SPOT = 60
RuneRules.GIVE_UP = 10

function RuneRules.IsLeftover(available, runeType, invalidType, visible, sinceSpawn)
	local untyped = runeType == -1 or (invalidType ~= nil and runeType == invalidType)
	return available == true and untyped and visible == true and sinceSpawn >= RuneRules.FRESH_SPAWN
end

-- One step of a leftover hold. hold = { t0 = start }; the step keeps hold.onSpotAt. dist: bot to the spot; up: the
-- raw status still reads available; typed: GetRuneType now names a rune; contested: enemy heroes hold the spot or
-- one hits the bot. Returns the phase ("try" / "walk" / "hold") or "end" plus why ("taken" / "typed" / "fight" /
-- "held" / "timeout").
function RuneRules.LeftoverStep(hold, now, dist, up, typed, contested)
	if not up then
		return "end", "taken"
	end
	if typed then
		return "end", "typed"
	end
	if contested then
		return "end", "fight"
	end
	if now - hold.t0 > RuneRules.GIVE_UP then
		return "end", "timeout"
	end
	if now < hold.t0 + RuneRules.TRY_WAIT then
		return "try"
	end
	if dist > RuneRules.ON_SPOT then
		hold.onSpotAt = nil
		return "walk"
	end
	hold.onSpotAt = hold.onSpotAt or now
	if now - hold.onSpotAt >= RuneRules.HOLD_FOR then
		return "end", "held"
	end
	return "hold"
end

-- Seconds stood on the spot so far.
function RuneRules.HeldFor(hold, now)
	return hold.onSpotAt ~= nil and now - hold.onSpotAt or 0
end

-- The pick-up retry loop for a rune with a known type: at most PICKUP_TRIES orders, PICKUP_GAP seconds apart (the
-- old loop counted thinks: 19 orders in 3s). try = { n = orders so far, last = time of the last order }.
-- "order": give one now; "wait": no new order; "fail": tries used up and the last one had its time.
RuneRules.PICKUP_TRIES = 3
RuneRules.PICKUP_GAP = 1.0
function RuneRules.PickupStep(try, now)
	local due = try.last == nil or now - try.last >= RuneRules.PICKUP_GAP
	if try.n >= RuneRules.PICKUP_TRIES then
		return due and "fail" or "wait"
	end
	return due and "order" or "wait"
end

-- Spawn hold at a river spot (#32, game 064, 2:00): Puck was 475 from the top spot when the water rune spawned, the
-- after-spawn walk desire (0.35) lost to laning (0.54-0.56) and she walked back to mid; the bounty walk-back brought
-- her there 8s later (2:14). A bot of the water walk (spawns at 0:00, 2:00, 4:00) within SPAWN_HOLD_RADIUS of the
-- spot from SPAWN_HOLD_BEFORE seconds before the spawn to SPAWN_HOLD_FOR after it keeps SPAWN_HOLD_DESIRE (above
-- laning, as the 0.6 on-spot stay; below fights and retreat). sinceSpawn: seconds since the spawn (negative before).
RuneRules.SPAWN_HOLD_RADIUS = 600
RuneRules.SPAWN_HOLD_BEFORE = 2
RuneRules.SPAWN_HOLD_FOR = 3
RuneRules.SPAWN_HOLD_DESIRE = 0.6
function RuneRules.SpawnHold(sinceSpawn, dist)
	return sinceSpawn >= -RuneRules.SPAWN_HOLD_BEFORE
		and sinceSpawn <= RuneRules.SPAWN_HOLD_FOR
		and dist <= RuneRules.SPAWN_HOLD_RADIUS
end

-- Walk to a river spot for a water rune (#32, game 065): Puck (mid) walked to the top spot before the 2:00 and 4:00
-- spawns at 0.53 (BOT_MODE_DESIRE_HIGH, `why=water-walk` t=112.7 and t=232.3, 1846-2188 from the spot) and laning
-- (0.56) won, so she stayed in lane; after the spawn the walk was 0.35 (`river-item-walk`, 2211 away at t=120.3).
-- Death Prophet took both top water runes. Maintainer (2026-11-21): raise it only for heroes near the spot (the mid
-- laner or a support roaming to mid), by distance. So a bot whose distance to the spot is the smallest on its team
-- (rank 1), or within RIVER_WALK_NEAR of it, walks at RIVER_WALK_DESIRE (above laning, as the spawn hold; below
-- fights, retreat and Valve's item mode, which does the pickup); others keep oldDesire.
-- rank: 1 + the number of living team heroes closer to the spot than the bot.
RuneRules.RIVER_WALK_NEAR = 2000
RuneRules.RIVER_WALK_DESIRE = 0.6
function RuneRules.RiverWalkNear(dist, rank)
	return rank == 1 or dist <= RuneRules.RIVER_WALK_NEAR
end
function RuneRules.RiverWalkDesire(dist, rank, oldDesire)
	if RuneRules.RiverWalkNear(dist, rank) then
		return math.max(RuneRules.RIVER_WALK_DESIRE, oldDesire)
	end
	return oldDesire
end

return RuneRules
