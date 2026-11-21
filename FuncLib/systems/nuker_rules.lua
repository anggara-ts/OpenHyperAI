-- Pure rules for nuker spell use (#47): Death Prophet's Crypt Swarm and Lina's solo combo. No bot API calls: the
-- hero files pass plain numbers, so Tests/test_nuker_rules.lua can check them.
local NukerRules = {}

-- An ultimate (Exorcism, Laguna Blade) counts as "coming" when it is learned, not running, and off cooldown within this many seconds: the
-- mana for it is kept. 15s is about one Crypt Swarm / Dragon Slave cooldown and a half (datafeed hero_id 43:
-- Crypt Swarm 10/9/8/7s; hero_id 25: Dragon Slave 11/10/9/8s).
NukerRules.ULT_SOON = 15

-- Mana at or above this share of the maximum counts as full: the regeneration from here on is wasted, so a spell
-- costs little (the same line as FULL_MANA_RATIO in PR #148's lane_nuke_rules.lua for Leshrac).
NukerRules.FULL_MANA_RATIO = 0.9

-- Lina's combo goes when the spells she can afford, in order, deal at least this share of the target's current HP
-- ("kills or nearly kills"); auto attacks and Fiery Soul finish the rest.
NukerRules.NEARLY_KILL = 0.85

-- Dragon Slave harass in lane is worth it when it leaves the target at or under this HP share: mode_retreat_generic.lua
-- sends a bot home at 60% HP or less within 4000 of its fountain (RetreatTag 350) and hard-retreats under 60% when
-- outnumbered, so a hero pushed under 60% leaves the lane.
NukerRules.HARASS_PUSH_OUT_HP = 0.6

-- Mana to keep for the ultimate: its cost while it is learned, not already running, and ready within ULT_SOON
-- seconds; otherwise nothing.
function NukerRules.UltReserve(learned, cost, cooldownLeft, active)
	if not learned or active or cooldownLeft > NukerRules.ULT_SOON then
		return 0
	end
	return cost
end

-- The reserve a fight cast keeps: the ultimate's mana only while she has it. A hero who can't cast the ultimate
-- anyway keeps fighting with her basic spells instead of holding mana she doesn't have.
function NukerRules.FightReserve(mana, ultReserve)
	if mana < ultReserve then
		return 0
	end
	return ultReserve
end

-- Can a spell of this cost be cast and still leave the reserve?
function NukerRules.CanSpend(mana, cost, reserve)
	return mana - cost >= reserve
end

-- Spare mana to spam a basic spell (Death Prophet's Crypt Swarm on a hero or a creep wave, #47)? The maintainer
-- (2026-11-21): "death prophet can spam crypt swarm to enemy hero and lane creep to push when the mana regen is
-- enough". Spare when, after the cast, the reserve is still there and either
--   her regeneration pays the cost back before the spell is ready again (regen * cooldown >= cost), or
--   her mana is full (FULL_MANA_RATIO), so the regeneration would be wasted anyway.
--   mana, maxMana  current and maximum mana; cost, cooldown: the spell's; regen: mana per second; reserve: mana to keep
function NukerRules.SpareMana(mana, maxMana, cost, cooldown, regen, reserve)
	if maxMana == nil or maxMana <= 0 or cost == nil or cost <= 0 or mana == nil then
		return false
	end
	if mana - cost < (reserve or 0) then
		return false
	end
	return (regen or 0) * (cooldown or 0) >= cost or mana >= maxMana * NukerRules.FULL_MANA_RATIO
end

-- Does Dragon Slave push a laning enemy out? hp / maxHp: the target's; damage: Dragon Slave's damage after resist.
function NukerRules.HarassPushesOut(hp, maxHp, damage)
	if maxHp <= 0 then
		return false
	end
	return (hp - damage) / maxHp <= NukerRules.HARASS_PUSH_OUT_HP
end

-- Lina's solo combo, Light Strike Array -> Dragon Slave -> Laguna Blade, on one enemy hero. s is a table of plain values:
--   disabled                   the target is stunned / rooted / hexed now, or her Light Strike Array is on its way to it
--   hp                         the target's current HP
--   mana                       Lina's mana
--   lsaReady, lsaInRange, lsaCost, lsaDamage           (damage after magic resist and spell amp)
--   slaveReady, slaveInRange, slaveCost, slaveDamage
--   lagunaReady, lagunaInRange, lagunaCost, lagunaDamage
--   committed                  the combo already started on this target (a step went in the last few seconds)
-- Plans the spells she can cast and afford in that order and returns the first one ("lsa", "slave", "laguna") and why
-- ("disabled" when the target is already held, "kill" when her stun opens the combo), or nil when the plan does not
-- deal NEARLY_KILL of the target's HP or nothing holds the target (no disable and no Light Strike Array to open).
-- Once committed and the target is held, the rest of the combo goes without the damage check: the check passed for
-- the whole combo when it opened, and the spells left (Dragon Slave + Laguna) never pass it again on their own.
function NukerRules.LinaComboStep(s)
	local plan = {}
	local mana = s.mana
	local damage = 0
	local spells = {
		{ "lsa", s.lsaReady and s.lsaInRange, s.lsaCost, s.lsaDamage },
		{ "slave", s.slaveReady and s.slaveInRange, s.slaveCost, s.slaveDamage },
		{ "laguna", s.lagunaReady and s.lagunaInRange, s.lagunaCost, s.lagunaDamage },
	}
	for _, spell in ipairs(spells) do
		if spell[2] and mana >= spell[3] then
			mana = mana - spell[3]
			damage = damage + spell[4]
			plan[#plan + 1] = spell[1]
		end
	end
	if #plan == 0 or s.hp <= 0 then
		return nil
	end
	if s.committed and s.disabled then
		return plan[1], "disabled"
	end
	if damage < s.hp * NukerRules.NEARLY_KILL then
		return nil
	end
	if s.disabled then
		return plan[1], "disabled"
	end
	if plan[1] == "lsa" then
		return "lsa", "kill"
	end
	return nil
end

return NukerRules
