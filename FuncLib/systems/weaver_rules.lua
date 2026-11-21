-- Weaver's escape Shukuchi (#48, game 050 17:15-17:39): she stayed in attack mode at 40% HP with three heroes on her,
-- turned to retreat only at 4% HP and died; the escape Shukuchi ran only in retreat mode. 7.42 game files: Shukuchi
-- 65 mana, cooldown 15/12/9/6s, 4s of invisibility and haste, 0.25s fade; an attack ends the invisibility.
local WeaverRules = {}

WeaverRules.ESCAPE_HP = 0.35 -- the maintainer's game 050 note: escape when hit below ~35% HP
WeaverRules.ESCAPE_ENEMY_RANGE = 800 -- enemy heroes this close count as "on her"

-- Escape out of attack (or any other non-retreat) mode: below ESCAPE_HP, hit by an enemy hero in the last 1.5s,
-- with at least one able enemy hero within ESCAPE_ENEMY_RANGE, and her own target not about to die to her attacks.
function WeaverRules.EscapeOutOfRetreat(hpRatio, hitByHero, enemiesNear, targetDiesSoon)
	return hpRatio < WeaverRules.ESCAPE_HP and hitByHero == true and enemiesNear >= 1 and not targetDiesSoon
end

-- Why an escape Shukuchi that was wanted could not be cast: "cooldown", "mana" or "other" (silenced, rooted, ...).
function WeaverRules.EscapeBlocked(cooldownLeft, mana, manaCost)
	if cooldownLeft > 0 then
		return "cooldown"
	end
	if mana < manaCost then
		return "mana"
	end
	return "other"
end

-- The disable that keeps every cast off while an escape is wanted (SkillsComplement's early return), or nil when
-- nothing disables her (queued or casting: her own orders, not a block). Game 063: 9 of her 15 deaths had no escape or
-- skip line in the 10s before.
function WeaverRules.DisabledReason(stunned, hexed, silenced, nightmared, doomed)
	if stunned then
		return "stunned"
	end
	if hexed then
		return "hexed"
	end
	if silenced then
		return "silenced"
	end
	if nightmared then
		return "nightmared"
	end
	if doomed then
		return "doomed"
	end
	return nil
end

return WeaverRules
