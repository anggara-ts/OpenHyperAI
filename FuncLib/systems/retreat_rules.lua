-- Shared bot system: pure retreat rules (no bot API calls), so they can be tested with real numbers.
local RetreatRules = {}

-- Low HP and being chewed by creeps or a tower, with no hero kill to finish (mode_retreat_generic.lua, creep-low).
-- Game 062, 17:34: Weaver stood in attack mode (0.71-0.74) in a creep wave and went from 13% to 3% HP in 3.5s
-- with no enemy hero near; the only creep rule (tag 369) needs the laning phase, 4+ creeps and a chase.
-- 25%: that wave took ~3% of her HP per second (10% in 3.5s), so 25% leaves ~8s, enough to walk out of
-- creep reach (and a hero turning up) with room to spare; the file uses 25% as its low line elsewhere too
-- (the Ancient-defence and laning-regen rules).
-- Once it fires, it holds for the caller's 3s window while HP stays under 35%, whichever mode is active (the creep
-- hit flag lapses 2s after the bot steps away, and attack or push would walk it straight back in); the window is
-- renewed while creeps or a tower are still in reach. Game 064, 42:04-42:13: the hold needed retreat to be the
-- active mode and let go as soon as nothing was in reach, and push mode (0.90) walked Death Prophet back under the
-- Radiant mid T3 at 16% HP, where she died.
-- A TP home while the rule holds is the escape: retreat stays up (0.98) for the whole channel and the window is
-- renewed through it, so no other mode takes over and cancels the TP with an order (retreat's Think is Valve's; in
-- game 064 the retreat TPs it was left alone for went through, e.g. Clinkz 20:32, 32% -> 88% HP 10s later).
-- Game 064, 42:05: the rule returned false while channeling, push took over during Death Prophet's TP and the TP was
-- lost. Other channels (not a TP) drop the rule, as before.
--   hp          HP ratio
--   creepHit    damaged by a creep in the last ~2s; towerHit: by a tower
--   canFinish   the bot's target dies to its next hit and the bot lives that long (mode_retreat_generic.lua)
--   channeling  the bot is channeling; teleporting: the channel is a TP (modifier_teleporting)
--   holding     the rule fired and its window has not run out
--   creepsNear  enemy creeps or an enemy tower still in reach
-- Returns: retreat now, renew the window.
RetreatRules.CREEP_LOW_HP = 0.25
RetreatRules.CREEP_LOW_RELEASE_HP = 0.35
function RetreatRules.CreepLowRetreat(hp, creepHit, towerHit, canFinish, channeling, holding, creepsNear, teleporting)
	if channeling then
		local keepTp = holding and teleporting == true
		return keepTp, keepTp
	end
	if canFinish then
		return false, false
	end
	if hp < RetreatRules.CREEP_LOW_HP and (creepHit or towerHit) then
		return true, true
	end
	if holding and hp < RetreatRules.CREEP_LOW_RELEASE_HP then
		return true, creepHit or towerHit or creepsNear
	end
	return false, false
end

-- Would the bot die before its finishing hit lands? Then the retreat rules give no "finish the kill" exemption.
-- Game 064, 22:23: Alchemist at 18% HP with 5 enemy heroes on him stayed in the creep wave because an enemy near him
-- was one hit from death (creep-low-skip why=finish), and died the same second.
--   hp        the bot's HP ratio; health: its HP
--   hitting   enemy heroes that damaged it in the last second (spells too)
--   incoming  what those heroes can deal to it before its hit lands (the engine's estimate, ready spells included)
-- Under 20% HP with 2+ heroes on it the estimate is not trusted (game 064: a damage estimate 2s before read one
-- attacker and 4.5s to live; 5 heroes killed him 2s later).
-- Returns: dies first, why.
RetreatRules.FINISH_DENY_HP = 0.2
function RetreatRules.DiesBeforeFinish(hp, health, hitting, incoming)
	if hp < RetreatRules.FINISH_DENY_HP and hitting >= 2 then
		return true, "low-hp"
	end
	if hitting >= 1 and incoming >= health then
		return true, "burst"
	end
	return false, nil
end

-- Is a bot that is attacking outnumbered enough to break off (mode_retreat_generic.lua, hard retreat)?
--   allies   heroes of ours near it, itself and Meepo clones included (they fight), illusions not
--   visible  enemy heroes seen near it right now
--   recent   enemy heroes last seen near it in the past few seconds (vision flickers)
--   hp       its HP ratio; hit: damaged by a hero in the last ~2s; stronger: Fu.WeAreStronger
-- Below 60% HP the recent sightings count too: being caught matters more than being sure.
-- At 60%+ only enemies it can see, two more than us, while it is being hit. Game 038: the old rule sent
-- Mirana back at full HP with no enemy within 1200 (two lane opponents last seen within 2000), and Meepo
-- with 3 bodies against 2 (his clones were not counted), 156 times in one game.
function RetreatRules.HardRetreatOutnumbered(allies, visible, recent, hp, hit, stronger)
	local pressure = math.max(visible, recent)
	if hp < 0.6 then
		return allies <= 1 and pressure >= 2 or pressure >= allies + 1 and not stronger
	end
	return hit and visible >= allies + 2 and not stronger
end

return RetreatRules
