-- Illusion rules (#48). Pure, no bot API calls, so Tests/test_illusion_rules.lua can load them.
local IllusionRules = {}

-- Seconds a cast order gets to start (cast phase, channel or cooldown running) before the illusion stops trying spells.
IllusionRules.CAST_START_TIMEOUT = 0.5

-- Which Vengeful Spirit illusion this is. Datafeed (hero 20, Vengeance Aura, Scepter): "Upon death, creates a strong
-- illusion of Vengeful Spirit that deals full damage, and can cast all of her spells". Manta / rune illusions can't
-- cast. hasDeathModifier: the illusion carries one of the Scepter illusion's modifiers (names from the installed
-- server.dll, see FuncLib/hero/minion_lib/vengeful_spirit.lua); ownerAlive: the hero is alive. A dead hero's
-- illusion counts as the death illusion too (Manta illusions outlive the hero; for those the cast timeout below
-- turns spells off). Returns "death" or "manta" and how it was told: "modifier", "owner-dead" or "-".
function IllusionRules.Kind(hasDeathModifier, ownerAlive)
	if hasDeathModifier then
		return "death", "modifier"
	end
	if not ownerAlive then
		return "death", "owner-dead"
	end
	return "manta", "-"
end

-- What happened to a cast order sinceOrder seconds ago: "started" (started is true), "pending" (still inside the
-- timeout) or "failed" (the order never started: the unit can't cast, so it stops trying).
function IllusionRules.CastOutcome(sinceOrder, started, timeout)
	if started then
		return "started"
	end
	if (sinceOrder or 0) < (timeout or IllusionRules.CAST_START_TIMEOUT) then
		return "pending"
	end
	return "failed"
end

return IllusionRules
