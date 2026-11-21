-- Alchemist: skill build, item build, and ability use for this hero.
local X = {}
local bot = GetBot()
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local AbilityContext = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local Minion = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local ConcoctionRules = require(GetScriptDirectory() .. "/FuncLib/systems/concoction_rules")
local sTalentList = Fu.Skill.GetTalentList(bot)
local sAbilityList = Fu.Skill.GetAbilityList(bot)
local sRole = Fu.Item.GetRoleItemsBuyList(bot)
local tTalentTreeList = { ["t25"] = { 0, 10 }, ["t20"] = { 0, 10 }, ["t15"] = { 10, 0 }, ["t10"] = { 10, 0 } }
local tAllAbilityBuildList = { { 2, 1, 1, 2, 1, 6, 1, 2, 2, 3, 6, 3, 3, 3, 6 } }
local nAbilityBuildList = Fu.Skill.GetRandomBuild(tAllAbilityBuildList)
local nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList)
local sRoleItemsBuyList = {}
-- Stratz 7.41f, week of 9 Nov 2026: pos 1, 14,658 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_1"] = {
	"item_tango",
	"item_quelling_blade",
	"item_double_gauntlets",
	"item_double_branches",
	"item_magic_wand",
	"item_soul_ring",
	"item_phase_boots",
	"item_radiance",
	"item_blink",
	"item_black_king_bar",
	"item_assault",
	"item_abyssal_blade",
	"item_aghanims_shard",
	"item_moon_shard",
	"item_ultimate_scepter_2",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 2, 10,389 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_2"] = {
	"item_tango",
	"item_quelling_blade",
	"item_double_gauntlets",
	"item_double_branches",
	"item_soul_ring",
	"item_boots",
	"item_radiance",
	"item_blink",
	"item_travel_boots",
	"item_ultimate_scepter",
	"item_black_king_bar",
	"item_abyssal_blade",
	"item_overwhelming_blink",
	"item_aghanims_shard",
	"item_moon_shard",
	"item_ultimate_scepter_2",
	"item_travel_boots_2",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 4, 7,192 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_4"] = {
	"item_tango",
	"item_quelling_blade",
	"item_double_gauntlets",
	"item_branches",
	"item_soul_ring",
	"item_boots",
	"item_blink",
	"item_travel_boots",
	"item_buckler",
	"item_black_king_bar",
	"item_assault",
	"item_orchid",
	"item_sange_and_yasha",
	"item_aghanims_shard",
	"item_moon_shard",
	"item_ultimate_scepter_2",
	"item_travel_boots_2",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 5, 4,897 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_5"] = {
	"item_tango",
	"item_blood_grenade",
	"item_double_gauntlets",
	"item_quelling_blade",
	"item_branches",
	"item_soul_ring",
	"item_boots",
	"item_blink",
	"item_travel_boots",
	"item_black_king_bar",
	"item_assault",
	"item_basher",
	"item_abyssal_blade",
	"item_aghanims_shard",
	"item_moon_shard",
	"item_ultimate_scepter_2",
	"item_travel_boots_2",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 3, 11,797 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_3"] = {
	"item_tango",
	"item_quelling_blade",
	"item_double_gauntlets",
	"item_double_branches",
	"item_magic_wand",
	"item_soul_ring",
	"item_phase_boots",
	"item_radiance",
	"item_blink",
	"item_black_king_bar",
	"item_assault",
	"item_swift_blink",
	"item_moon_shard",
	"item_sange_and_yasha",
	"item_aghanims_shard",
	"item_ultimate_scepter_2",
}
X["sBuyList"] = sRoleItemsBuyList[sRole]
X["sSellList"] = {
	"item_assault",
	"item_magic_wand",
	"item_abyssal_blade",
	"item_quelling_blade",
	"item_assault",
	"item_ancient_janggo",
	"item_assault",
	"item_soul_ring",
}
if Fu.Role.IsPvNMode() or Fu.Role.IsAllShadow() then
	X["sBuyList"], X["sSellList"] = { "PvN_antimage" }, {}
end
nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"] =
	Fu.SetUserHeroInit(nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"])
X["sSkillList"] = Fu.Skill.GetSkillList(sAbilityList, nAbilityBuildList, sTalentList, nTalentBuildList)
X["bDeafaultAbility"] = false
X["bDeafaultItem"] = false
function X.MinionThink(minionUnit)
	if Minion.IsValidUnit(minionUnit) then
		if Fu.IsValidHero(minionUnit) and minionUnit:IsIllusion() then
			Minion.IllusionThink(minionUnit)
		end
	end
end
local acidSprayAbility = SafeAbility(bot:GetAbilityByName("alchemist_acid_spray"), "alchemist_acid_spray", "alchemist")
local unstableConcoctionAbility =
	SafeAbility(bot:GetAbilityByName("alchemist_unstable_concoction"), "alchemist_unstable_concoction", "alchemist")
local unstableConcoctionThrowAbility = SafeAbility(
	bot:GetAbilityByName("alchemist_unstable_concoction_throw"),
	"alchemist_unstable_concoction_throw",
	"alchemist"
)
local chemicalRageAbility =
	SafeAbility(bot:GetAbilityByName("alchemist_chemical_rage"), "alchemist_chemical_rage", "alchemist")
local berserkPotionAbility =
	SafeAbility(bot:GetAbilityByName("alchemist_berserk_potion"), "alchemist_berserk_potion", "alchemist")
local acidSprayDesire, acidSprayLocation
local unstableConcoctionDesire, unstableConcoctionTarget, unstableConcoctionWhy
local unstableConcoctionThrowDesire, unstableConcoctionThrowTarget, unstableConcoctionThrowWhy
local berserkPotionDesire, berserkPotionTarget
local chemicalRageDesire
local retreatThrowDelay = 2
local fullBrewThrowDelay = 4.25
local concoctionStartTime = 0
-- Brew state (#34), reset at every brew start.
local brewTarget = nil -- the hero the brew was started for
local brewWhy = "none" -- the start rule that fired
local brewSeen = false -- the throw ability was seen in the slot since the start: he really is brewing
local brewSeenAt = 0 -- seconds brewed when it was last seen there
local lastThrowWhy, lastThrowBrewed = "none", 0 -- the last throw order of this brew
local lastGateWhy, lastGateBrewed = "none", 0 -- the last time the ability gate was closed during this brew
local brewDisabled = false -- the gate was closed by a stun, silence or hex during this brew (game 057)
local brewLateGate = 0 -- seconds the gate was closed from the full-brew throw time (4.25s) on
local brewGateCast = "-" -- the other cast or queued order that closed the gate last
local brewLastThinkAt, brewThinkDt, brewMaxGap = 0, 0, 0 -- seconds between brew tracker runs
local brewThreatKind = "-" -- what the stun-threat throw reacted to
local hpMarkHp, hpMarkAt = 0, -999 -- his HP at most 1s ago, for the HP-drop threat
local gapSampleUnit, gapSampleDist, gapSampleAt = nil, 0, 0 -- distance sample of the nearest throw target
local throwOrderUnit, throwOrderAt = nil, 0 -- the hero of the current throw order and when it was first ordered
local brewHelp = nil -- { kind=, target= }: this brew helps the allies finish a hero (FinishingCase), else nil
local pendingHelp = nil -- set by FinishingCase for the start that returns why=help
local helpStun = nil -- the stun of the last help-early throw, for its log line
local brewLostAt = -1 -- seconds brewed when the brew target was first seen dead or out of sight, -1: not lost
local botTarget
local isEngaging
local isRetreating
local brewRetreating
local isAttacking
local hpRatio
-- Damage of a concoction thrown after `brewed` seconds. Game data (7.42 npc_abilities.txt,
-- alchemist_unstable_concoction): min_damage 0, max_damage 150/220/290/360 at brew_time 5.0; the datafeed
-- text says "the longer the concoction brews, the more damage it deals and the longer the stun". The data
-- gives only the two ends: a straight line between them is assumed, so callers keep a margin.
function X.ConcoctionDamageAt(maxDamage, brewed, brewTime)
	if brewTime == nil or brewTime <= 0 then
		return maxDamage
	end
	return maxDamage * math.max(0, math.min(1, brewed / brewTime))
end
-- Distance between a runner and its chaser after `seconds`: it only grows when the runner is the faster one.
function X.ConcoctionGapAfter(distance, runnerSpeed, chaserSpeed, seconds)
	return distance + math.max(0, runnerSpeed - chaserSpeed) * seconds
end
-- Seconds until a target at `distance` leaves the throw range, at `rate` units per second (positive: the gap
-- grows). 0 when it is already out, math.huge when the gap is not growing.
function X.ConcoctionSecondsInRange(distance, rate, castRange)
	if distance >= castRange then
		return 0
	end
	if rate <= 0 then
		return math.huge
	end
	return (castRange - distance) / rate
end
-- #34, game 057: a disable while he holds the brew keeps him from throwing it, and it then blows up on him.
-- Game 057, 52:47: Puck blinked onto him 1s into a brew and cast Waning Rift on him (7.42 npc_heroes:
-- puck_waning_rift silence_duration 2.0/2.5/3.0/3.5, +1.25 talent); he was disabled from then to the explosion.
-- Returns what makes a disable likely now, or nil. `threat`: projectile (a stun projectile is on its way),
-- afterDisable (he was stunned, silenced or hexed earlier in this brew: a chained disable is likely), enemyCast
-- (an enemy within 600 is casting at him), hpLost (share of his max HP lost within the last second).
-- The brew time floors keep a throw worth its cooldown: game data (7.42 npc_heroes, alchemist_unstable_concoction)
-- min_stun 0.25, max_stun 1.7/2.2/2.7/3.2 at brew_time 5.0 (the throw's own block lists 1.75/2.25/2.75/3.25);
-- assuming a straight line, 1.5s brewed is 30% of max_damage and a 0.7-1.1s stun.
function X.ConcoctionThreat(brewed, threat)
	if threat == nil then
		return nil
	end
	if threat.projectile and brewed >= 0.3 then
		return "projectile"
	end
	if threat.afterDisable and brewed >= 1.0 then
		return "after-disable"
	end
	if threat.enemyCast and brewed >= 1.5 then
		return "enemy-cast"
	end
	if (threat.hpLost or 0) >= 0.25 and brewed >= 1.5 then
		return "hp-drop"
	end
	return nil
end
-- Gate reasons a throw order may override while brewing: another cast in its cast point or a queued order.
-- Not a channel (it may be an escape Town Portal), stun, silence, hex or invulnerability.
local softGateReasons = { casting = true, queued = true }
function X.ConcoctionGateSoft(reason)
	return softGateReasons[reason] == true
end
-- #34, game 057: his other casts are held while a brew is in hand, so none of them is in its cast point when
-- the throw is due. Acid Spray and Berserk Potion (7.42 npc_heroes: AbilityCastPoint 0.1 and 0.2) wait for the
-- whole brew; Chemical Rage (cast point 0.0, 0.35s transformation, datafeed transformation_time) only from 3.0s
-- brewed, ahead of the 4.25s throws.
function X.ConcoctionHoldsCast(castName, brewing, brewed)
	if not brewing then
		return false
	end
	if castName == "chemical_rage" then
		return brewed >= 3.0
	end
	return true
end
-- #34, game 063: a kill brew is not started when its damage is lethal within KILL_BREW_MIN_SECONDS of brewing,
-- or when his own attacks kill the target within KILL_BREW_ATTACK_SECONDS (attackKillSeconds: nil when it is
-- out of his attack range). A target that dies in the throw's cast point leaves the brew on him (3721: Lina at
-- 8%, thrown at 0.3s, she died before it went out and it blew up 5s later).
X.KILL_BREW_MIN_SECONDS = 0.5
X.KILL_BREW_ATTACK_SECONDS = 1.0
-- (f) target-lost throws: the share of the throw range a target must be within before X.TARGET_LOST_ANY_AFTER
-- seconds brewed, and the seconds after which a throw order whose cast has not gone out may take another hero.
X.TARGET_LOST_INNER = 0.9
X.TARGET_LOST_ANY_AFTER = 3.0
X.THROW_REPICK_AFTER = 0.4
function X.ConcoctionKillTooEasy(lethalAfter, attackKillSeconds)
	return lethalAfter <= X.KILL_BREW_MIN_SECONDS
		or attackKillSeconds ~= nil and attackKillSeconds <= X.KILL_BREW_ATTACK_SECONDS
end
-- #34, game 063: no kill or engage brew while the retreat mode wants him out (desire 0.5 or more, or its run
-- lines 374 / 383: Retreat.ShouldRun), read from mode_retreat_generic.lua's bot._retreatDesireNow /
-- bot._retreatLineNow, published at most 0.5s ago. t=2060: an engage brew started in another mode while
-- retreat said 1.10 (line 383); he then blinked away and it blew up on him.
function X.ConcoctionRetreatWanted(desire, line, age)
	if desire == nil or age == nil or age > 0.5 then
		return false
	end
	return desire >= 0.5 or line == 374 or line == 383
end
-- Game data: brew_explosion 5.5 on the brew ability (the hidden throw ability's own block still lists 7.0);
-- 5.5 is the deadline used, since it is safe under either value.
local function ConcoctionExplodeAt()
	local explodeAt = unstableConcoctionAbility:GetSpecialValueFloat("brew_explosion")
	if explodeAt == nil or explodeAt <= 0 or explodeAt > 5.5 then
		explodeAt = 5.5
	end
	return explodeAt
end
-- Game data: brew_time 5.0, the brew time that gives max_damage and max_stun.
local function ConcoctionBrewTime()
	local brewTime = unstableConcoctionAbility:GetSpecialValueFloat("brew_time")
	if brewTime == nil or brewTime <= 0 then
		brewTime = 5.0
	end
	return brewTime
end
-- A unit the throw can be ordered on: visible, not magic immune (game data: SpellImmunityType ENEMIES_NO),
-- not invulnerable. Illusions count: the throw's target type is HERO and the explosion is AoE.
local function CanHitWithThrow(unit)
	return Fu.IsValidHero(unit) and unit:CanBeSeen() and not unit:IsMagicImmune() and not unit:IsInvulnerable()
end
-- The nearest real hero and the nearest suspected illusion within `range` that the throw can hit.
local function NearestThrowTargets(range)
	local nearest, nearestDist = nil, range
	local nearestIllusion, illusionDist = nil, range
	for _, enemyHero in pairs(Fu.GetNearbyHeroes(bot, math.min(range, 1600), true, BOT_MODE_NONE) or {}) do
		if CanHitWithThrow(enemyHero) then
			local distance = GetUnitToUnitDistance(bot, enemyHero)
			if Fu.IsSuspiciousIllusion(enemyHero) then
				if distance <= illusionDist then
					nearestIllusion, illusionDist = enemyHero, distance
				end
			elseif distance <= nearestDist then
				nearest, nearestDist = enemyHero, distance
			end
		end
	end
	return nearest, nearestDist, nearestIllusion, illusionDist
end
-- The nearest hero of a list that a normal (not forced) throw takes: a real hero without a spell-reflecting or
-- similar modifier (Fu.CanCastOnNonMagicImmune).
local function NearestCastable(enemyHeroes)
	local nearest, nearestDist = nil, 99999
	for _, enemyHero in pairs(enemyHeroes or {}) do
		if Fu.IsValidHero(enemyHero) and Fu.CanCastOnNonMagicImmune(enemyHero) then
			local distance = GetUnitToUnitDistance(bot, enemyHero)
			if distance < nearestDist then
				nearest, nearestDist = enemyHero, distance
			end
		end
	end
	return nearest, nearestDist
end
-- Will this enemy still be inside the throw range (with a 75 margin) after `seconds` of brewing?
-- botIsRunner: he runs and it chases (the retreat case); otherwise it runs and he follows. His speed counts
-- the brew's bonus (game data: move_speed +4/8/12/16% while brewing).
local function WillStayInThrowRange(enemyHero, seconds, castRange, botIsRunner)
	local distance = GetUnitToUnitDistance(bot, enemyHero)
	local brewSpeedBonus = unstableConcoctionAbility:GetSpecialValueInt("move_speed") or 0
	local ownSpeed = bot:GetCurrentMovementSpeed() * (1 + brewSpeedBonus / 100)
	local enemySpeed = enemyHero:GetCurrentMovementSpeed()
	local gap = distance
	if botIsRunner then
		gap = X.ConcoctionGapAfter(distance, ownSpeed, enemySpeed, seconds)
	elseif Fu.IsRunning(enemyHero) and not enemyHero:IsFacingLocation(bot:GetLocation(), 90) then
		gap = X.ConcoctionGapAfter(distance, enemySpeed, ownSpeed, seconds)
	end
	return gap <= castRange - 75, gap
end
local function UnitNameOrNone(unit)
	if unit == nil or unit:IsNull() then
		return "none"
	end
	return unit:GetUnitName()
end
-- Why Fu.CanNotUseAbility closed the gate, for the brew's end line.
local function AbilityGateReason()
	if bot:IsStunned() then
		return "stunned"
	elseif bot:IsSilenced() then
		return "silenced"
	elseif bot:IsHexed() then
		return "hexed"
	elseif bot:IsNightmared() or bot:IsInvulnerable() then
		return "other"
	elseif bot:IsChanneling() then
		return "channeling"
	elseif bot:IsUsingAbility() or bot:IsCastingAbility() then
		return "casting"
	elseif Fu.HasQueuedAction(bot) then
		return "queued"
	end
	return "other"
end
-- The throw he ordered is in its cast point (game data: AbilityCastPoint 0.2): a new order would restart it.
-- When the active ability can't be read, any cast after a throw order in this brew counts as the throw (he
-- may have turned or walked first), which is how the gate behaved before.
local function IsThrowInProgress()
	local activeAbility = bot:GetCurrentActiveAbility()
	if activeAbility ~= nil and not activeAbility:IsNull() then
		return activeAbility:GetName() == "alchemist_unstable_concoction_throw"
	end
	return lastThrowWhy ~= "none"
end
-- Notes a closed gate during a brew for the brew's end line (#34, game 057: the line only named the last
-- reason, which on most brews was the throw's own cast point).
local function NoteBrewGate(reason, brewed)
	lastGateWhy, lastGateBrewed = reason, brewed
	if reason == "stunned" or reason == "silenced" or reason == "hexed" then
		brewDisabled = true
	end
	if brewed >= fullBrewThrowDelay then
		brewLateGate = brewLateGate + brewThinkDt
	end
	if reason == "casting" then
		local activeAbility = bot:GetCurrentActiveAbility()
		if activeAbility ~= nil and not activeAbility:IsNull() then
			brewGateCast = activeAbility:GetName()
		end
	elseif reason == "queued" then
		brewGateCast = "queued:" .. tostring(bot:GetQueuedActionType(0))
	end
end
-- What makes a disable likely now (see X.ConcoctionThreat).
local function ReadBrewThreat()
	local now = DotaTime()
	local hp = bot:GetHealth()
	local hpLost = 0
	if now - hpMarkAt > 1.0 then
		hpMarkHp, hpMarkAt = hp, now
	else
		hpLost = (hpMarkHp - hp) / math.max(1, bot:GetMaxHealth())
	end
	return {
		projectile = Fu.IsStunProjectileIncoming(bot, 1000),
		afterDisable = brewDisabled,
		enemyCast = Fu.IsWillBeCastUnitTargetSpell(bot, 600) or Fu.IsWillBeCastPointSpell(bot, 600),
		hpLost = hpLost,
	}
end
-- The hero the brew was started for is dead or out of sight.
local function BrewTargetLost()
	return brewTarget == nil or brewTarget:IsNull() or not brewTarget:IsAlive() or not brewTarget:CanBeSeen()
end
-- Does the retreat mode want him out (X.ConcoctionRetreatWanted)? Returns the flag, the desire and the line.
local function RetreatWanted()
	local desire, line = bot._retreatDesireNow, bot._retreatLineNow
	local at = bot._retreatDesireAt
	local wanted = X.ConcoctionRetreatWanted(desire, line, at ~= nil and DotaTime() - at or nil)
	return wanted, desire or 0, line or 0
end
-- Runs every think, above the ability gate: the explosion on himself stuns him, so code below the gate never
-- sees a brew end. Returns whether he is brewing and the seconds brewed. When a brew ends it prints one line:
--   [OHA-ALCHEMIST] concoction brew-end outcome=thrown|self-explode|died|unknown ...
-- self-explode: still brewing at the deadline, or it ended around the deadline with no throw order in this
-- brew (only this file orders the throw), or he is stunned when the end is seen. thrown: a throw was ordered
-- and the brew ended before the deadline. died: he is dead, or this function did not run for over 5s (it does
-- not run while he is dead; game 057, 34:06: a brew seen at 1.0s ended "unknown" 66s later, after his death).
-- unknown: anything else (this function did not run around the end because the usage file returned before the
-- hero script, and an order was pending). stunned= is read after the end, so on a self-explode it is mostly the
-- explosion's own stun; gate= is the last closed gate, lateGate= the seconds it was closed from 4.25s brewed on,
-- cast= the other cast or queued order seen at the gate, maxGap= the longest pause between runs of this function.
function X.TrackConcoctionBrew()
	local now = DotaTime()
	local brewed = now - concoctionStartTime
	local explodeAt = ConcoctionExplodeAt()
	-- While brewing the throw ability takes the brew's slot (datafeed note: "While brewing, this ability is
	-- replaced by Unstable Concoction Throw") and is hidden otherwise. The time bound keeps a wrong hidden
	-- state from reading as an endless brew; a cast range of 0 is the nil-ability proxy.
	local brewing = brewed >= 0
		and brewed <= explodeAt + 0.3
		and bot:IsAlive()
		and unstableConcoctionThrowAbility:GetCastRange() > 0
		and not unstableConcoctionThrowAbility:IsHidden()
	if brewing then
		if brewSeen then
			brewThinkDt = math.min(0.5, now - brewLastThinkAt)
			brewMaxGap = math.max(brewMaxGap, now - brewLastThinkAt)
		else
			brewThinkDt = 0
		end
		brewLastThinkAt = now
		brewSeen = true
		brewSeenAt = brewed
		-- Read by ability_item_usage_generic.lua: no retreat blink while a brew is in hand and a hero is in throw
		-- range (game 063, 34:20: the blink at 0.7s brewed carried it away from every target). With nobody in range
		-- the brew blows up on him anyway, so the blink is free. Refreshed every run, so it lapses by itself.
		local inRange, _, inRangeIllusion = NearestThrowTargets(unstableConcoctionThrowAbility:GetCastRange())
		bot._alchBrewingUntil = (inRange ~= nil or inRangeIllusion ~= nil) and now + 0.3 or nil
		-- #34, game 064: once per brew, the moment the brew target is gone and who is left for it:
		--   [OHA-ALCHEMIST] concoction target-lost brewed= target= nearest= nearestDist= plan=throw|chase|none
		-- throw: a hero within the throw range (the target-lost throw takes it); chase: within 1600 (keep-range walks
		-- to it); none: nobody in sight, the brew will blow up on him unless a hero shows up.
		if brewLostAt < 0 and BrewTargetLost() then
			brewLostAt = brewed
			pcall(function()
				local castRange = unstableConcoctionThrowAbility:GetCastRange()
				local nearest, nearestDist = NearestThrowTargets(1600)
				local plan = nearest == nil and "none" or nearestDist <= castRange and "throw" or "chase"
				print(
					string.format(
						"[OHA-ALCHEMIST] t=%.0f concoction target-lost brewed=%.1fs target=%s nearest=%s nearestDist=%.0f"
							.. " plan=%s mode=%s",
						DotaTime(),
						brewed,
						UnitNameOrNone(brewTarget),
						UnitNameOrNone(nearest),
						nearest ~= nil and nearestDist or -1,
						plan,
						tostring(bot:GetActiveMode())
					)
				)
			end)
		end
		return true, brewed
	end
	bot._alchBrewingUntil = nil
	bot._alchChaseUntil = nil
	if brewSeen then
		brewSeen = false
		local outcome = "unknown"
		local throwOrdered = lastThrowWhy ~= "none"
		if not bot:IsAlive() then
			outcome = "died"
		elseif brewSeenAt >= explodeAt - 0.07 then
			outcome = "self-explode"
		elseif brewed - brewSeenAt > 5 then
			outcome = "died"
		elseif brewed < explodeAt - 0.07 then
			if throwOrdered then
				outcome = "thrown"
			end
		elseif not throwOrdered and brewed <= explodeAt + 5 then
			outcome = "self-explode"
		elseif bot:IsStunned() then
			outcome = "self-explode"
		end
		pcall(function()
			local nearest, nearestDist = NearestThrowTargets(1600)
			print(string.format(
				"[OHA-ALCHEMIST] t=%.0f concoction brew-end outcome=%s brewed=%.1fs seen=%.1fs rule=%s target=%s"
					.. " lastThrow=%s@%.1f gate=%s@%.1f nearest=%s nearestDist=%.0f mode=%s stunned=%s"
					.. " lateGate=%.1fs cast=%s maxGap=%.1fs targetLost=%s lostAt=%.1fs lineDelay=%.1fs",
				DotaTime(),
				outcome,
				-- A died brew prints at his respawn: brewed= is the time last seen brewing, lineDelay= the rest.
				outcome == "died" and brewSeenAt or brewed,
				brewSeenAt,
				brewWhy,
				UnitNameOrNone(brewTarget),
				lastThrowWhy,
				lastThrowBrewed,
				lastGateWhy,
				lastGateBrewed,
				UnitNameOrNone(nearest),
				nearest ~= nil and nearestDist or -1,
				tostring(bot:GetActiveMode()),
				tostring(bot:IsStunned()),
				brewLateGate,
				brewGateCast,
				brewMaxGap,
				tostring(BrewTargetLost()),
				brewLostAt,
				brewed - brewSeenAt
			))
		end)
	end
	return false, brewed
end
-- One line per throw order (the order repeats while it is not carried out, so 1s per reason). threat= names
-- what the stun-threat throw reacted to; gate= is "open", or the cast, queued order or channel the throw replaces.
function X.LogConcoctionThrow(why, target, brewed, gate)
	if bot._alchThrowLogWhy == why and DotaTime() < (bot._alchThrowLogAt or -999) then
		return
	end
	bot._alchThrowLogWhy = why
	bot._alchThrowLogAt = DotaTime() + 1
	pcall(function()
		print(
			string.format(
				"[OHA-ALCHEMIST] t=%.0f concoction throw why=%s target=%s dist=%.0f brewed=%.1fs illusion=%s"
					.. " threat=%s gate=%s stun=%s",
				DotaTime(),
				why,
				UnitNameOrNone(target),
				GetUnitToUnitDistance(bot, target),
				brewed,
				tostring(Fu.IsSuspiciousIllusion(target)),
				why == "stun-threat" and brewThreatKind or "-",
				gate or "open",
				why == "help-early" and helpStun ~= nil and string.format("%.2f", helpStun) or "-"
			)
		)
	end)
end
local function OrderConcoctionThrow(brewed, gate)
	local why = unstableConcoctionThrowWhy or "none"
	X.LogConcoctionThrow(why, unstableConcoctionThrowTarget, brewed, gate)
	lastThrowWhy, lastThrowBrewed = why, brewed
	if unstableConcoctionThrowTarget ~= throwOrderUnit then
		throwOrderUnit, throwOrderAt = unstableConcoctionThrowTarget, DotaTime()
	end
	bot._alchChaseUntil = nil
	bot:Action_UseAbilityOnEntity(unstableConcoctionThrowAbility, unstableConcoctionThrowTarget)
end
-- Another cast from this file is held while a brew is in hand (X.ConcoctionHoldsCast); one line per 3s.
local function HoldsCastWhileBrewing(castName, brewing, brewed)
	if not X.ConcoctionHoldsCast(castName, brewing, brewed) then
		return false
	end
	if DotaTime() >= (bot._alchHoldLogAt or -999) then
		bot._alchHoldLogAt = DotaTime() + 3
		pcall(
			print,
			string.format("[OHA-ALCHEMIST] t=%.0f concoction hold cast=%s brewed=%.1fs", DotaTime(), castName, brewed)
		)
	end
	return true
end
-- While brewing and not retreating, walk back into range of a throw target (#34). Game 039, 15:09 and 39:01:
-- the brew started in attack mode, the mode changed (push after a farm withdraw, Roshan) and walked him off,
-- and at 5.0s nobody was within the throw range. Only when no real hero is within the start distance (throw
-- range - 175), so it never pulls him out of a fight he is already in, and only toward a hero he can bring
-- into range before the brew explodes. The brew target first, else the nearest hero. Runs last in
-- SkillsComplement: a move order above would cancel his own casts.
-- The enemy tower within radius of a location, or nil.
local function EnemyTowerAt(location, radius)
	for towerId = 0, 10 do
		local tower = GetTower(GetOpposingTeam(), towerId)
		if
			tower ~= nil
			and not tower:IsNull()
			and tower:IsAlive()
			and GetUnitToLocationDistance(tower, location) <= radius
		then
			return tower
		end
	end
	return nil
end
-- #34, game 063 (2255, 3707-3708): keep-range said move=no-tower in push mode with our wave on the tower, and the
-- brew blew up. A tower our team is pushing (2+ of our lane creeps or 2+ other allied heroes within 700 of it, and
-- not shooting at him) does not stop the chase. Read from the units at the tower, not from his mode: once the
-- chase hold below is on, his mode is the hold's.
local function TowerPushedByTeam(tower)
	if tower:GetAttackTarget() == bot then
		return false, 0, 0
	end
	local towerLoc = tower:GetLocation()
	local creeps = 0
	for _, creep in pairs(GetUnitList(UNIT_LIST_ALLIED_CREEPS) or {}) do
		if Fu.IsValid(creep) and creep:IsCreep() and GetUnitToLocationDistance(creep, towerLoc) <= 700 then
			creeps = creeps + 1
		end
	end
	local allies = 0
	for _, allyHero in pairs(Fu.GetAlliesNearLoc(towerLoc, 700) or {}) do
		if allyHero ~= bot then
			allies = allies + 1
		end
	end
	return creeps >= 2 or allies >= 2, creeps, allies
end
function X.ConcoctionKeepRange(brewed)
	local castRange = unstableConcoctionThrowAbility:GetCastRange()
	local nearest, nearestDist = NearestThrowTargets(1600)
	if nearest == nil or nearestDist <= castRange - 175 then
		bot._alchChaseUntil = nil
		return false
	end
	local chaseTarget, chaseDist = nearest, nearestDist
	if CanHitWithThrow(brewTarget) and not Fu.IsSuspiciousIllusion(brewTarget) then
		local brewTargetDist = GetUnitToUnitDistance(bot, brewTarget)
		if brewTargetDist <= 1600 then
			chaseTarget, chaseDist = brewTarget, brewTargetDist
		end
	end
	-- Not under an enemy tower (7.42 npc_units.txt: tower AttackRange 700; 850 leaves a margin) unless our team
	-- is pushing that tower. No exemption by his mode any more: under the chase hold his mode is the hold's, so a
	-- mode test would flip between chase and no chase from one think to the next.
	local tower = EnemyTowerAt(chaseTarget:GetLocation(), 850)
	local towerPushed, towerCreeps, towerAllies = false, 0, 0
	if tower ~= nil then
		towerPushed, towerCreeps, towerAllies = TowerPushedByTeam(tower)
	end
	local secondsLeft = ConcoctionExplodeAt() - brewed
	local reachable = chaseDist - castRange <= bot:GetCurrentMovementSpeed() * secondsLeft
	local move = "yes"
	if RetreatWanted() then
		move = "no-retreat"
	elseif tower ~= nil and not towerPushed then
		move = "no-tower"
	elseif not reachable then
		move = "no-reach"
	end
	if DotaTime() >= (bot._alchKeepLogAt or -999) then
		bot._alchKeepLogAt = DotaTime() + 1
		pcall(function()
			print(
				string.format(
					"[OHA-ALCHEMIST] t=%.0f concoction keep-range target=%s dist=%.0f brewed=%.1fs mode=%s move=%s"
						.. " hold=%s tower=%s towerCreeps=%d towerAllies=%d",
					DotaTime(),
					UnitNameOrNone(chaseTarget),
					chaseDist,
					brewed,
					tostring(bot:GetActiveMode()),
					move,
					tostring((bot._alchChaseUntil or -1) > DotaTime()),
					tower ~= nil and (towerPushed and "pushed" or "enemy") or "none",
					towerCreeps,
					towerAllies
				)
			)
		end)
	end
	if move ~= "yes" then
		bot._alchChaseUntil = nil
		return false
	end
	-- Game 063, 7:32: keep-range ordered the move with dist 606 -> 1023 in laning mode: the mode's own move order
	-- replaced it. mode_outpost_generic.lua (heroSpecificDesire alchemist) takes the bot while this is set and
	-- gives no order (bot._outpostHoldUntil), so this move stands. Refreshed every run; it ends with the throw,
	-- the brew, a retreat or a target back in range.
	bot._alchChaseUntil = DotaTime() + 0.3
	bot:Action_MoveToLocation(chaseTarget:GetLocation())
	return true
end
local function ReadContext()
	local context = AbilityContext.Build(bot)
	isEngaging = context.isEngaging
	isRetreating = context.isRetreating
	-- Fu.IsRetreating needs a retreat desire above 0.5; the mode alone already walks him away from his target.
	brewRetreating = isRetreating or bot:GetActiveMode() == BOT_MODE_RETREAT
	isAttacking = Fu.IsAttacking(bot)
	hpRatio = context.hp
end
function X.SkillsComplement()
	local brewing, brewed = X.TrackConcoctionBrew()
	X.TrackEnemyTeleports()
	if Fu.CanNotUseAbility(bot) then
		if not brewing then
			return
		end
		local gateWhy = AbilityGateReason()
		NoteBrewGate(gateWhy, brewed)
		-- #34, game 057: another cast or a queued order no longer holds a due throw back; the throw
		-- order replaces it. Not while the throw itself is in its cast point, unless (f) the order is older than
		-- X.THROW_REPICK_AFTER (game data: AbilityCastPoint 0.2; turning included it should be out by then)
		-- and the throw now goes to another hero: a new order would restart the cast point, so not every think.
		if not X.ConcoctionGateSoft(gateWhy) then
			return
		end
		local repick = false
		if gateWhy == "casting" and IsThrowInProgress() then
			if throwOrderUnit == nil or DotaTime() - throwOrderAt < X.THROW_REPICK_AFTER then
				return
			end
			repick = true
		end
		ReadContext()
		unstableConcoctionThrowDesire, unstableConcoctionThrowTarget, unstableConcoctionThrowWhy =
			X.ConsiderUnstableConcoctionThrow()
		if unstableConcoctionThrowDesire > 0 then
			if repick then
				if unstableConcoctionThrowTarget == throwOrderUnit then
					return
				end
				OrderConcoctionThrow(brewed, "repick:" .. UnitNameOrNone(throwOrderUnit))
				return
			end
			OrderConcoctionThrow(brewed, gateWhy .. ":" .. brewGateCast)
		elseif
			gateWhy == "queued"
			and BrewTargetLost()
			and not brewRetreating
			and unstableConcoctionThrowAbility:IsFullyCastable()
		then
			-- #34, game 064 (t=2062, gate=queued cast=queued:4): a queued order from his mode kept the walk to
			-- another hero (X.ConcoctionKeepRange) from running once the brew target was gone. The move replaces
			-- the queued order; not a cast in its cast point (a move would cancel that).
			X.ConcoctionKeepRange(brewed)
		end
		return
	end
	ReadContext()
	-- The throw comes before Chemical Rage: the Rage has a 0.35s transformation (datafeed: transformation_time)
	-- in which nothing can be thrown, and the brew blows up on him 0.5s after it is full.
	unstableConcoctionThrowDesire, unstableConcoctionThrowTarget, unstableConcoctionThrowWhy =
		X.ConsiderUnstableConcoctionThrow()
	if unstableConcoctionThrowDesire > 0 then
		OrderConcoctionThrow(brewed)
		return
	end
	chemicalRageDesire = X.ConsiderChemicalRage()
	if chemicalRageDesire > 0 and not HoldsCastWhileBrewing("chemical_rage", brewing, brewed) then
		bot:Action_UseAbility(chemicalRageAbility)
		return
	end
	unstableConcoctionDesire, unstableConcoctionTarget, unstableConcoctionWhy = X.ConsiderUnstableConcoction()
	if unstableConcoctionDesire > 0 then
		brewTarget, brewWhy = unstableConcoctionTarget, unstableConcoctionWhy or "none"
		brewHelp = brewWhy == "help" and pendingHelp or nil
		pendingHelp, helpStun = nil, nil
		brewSeen, brewSeenAt = false, 0
		lastThrowWhy, lastThrowBrewed = "none", 0
		lastGateWhy, lastGateBrewed = "none", 0
		brewDisabled, brewLateGate, brewGateCast, brewMaxGap, brewThreatKind = false, 0, "-", 0, "-"
		hpMarkAt = -999
		gapSampleUnit = nil
		throwOrderUnit, throwOrderAt = nil, 0
		brewLostAt = -1
		-- [OHA-ALCHEMIST]: the brew start with its rule and target, throttled to 10s (the order repeats until
		-- it is carried out; game data: AbilityCooldown 17).
		if DotaTime() >= (bot._alchBrewLogAt or -999) then
			bot._alchBrewLogAt = DotaTime() + 10
			pcall(function()
				local hasTarget = Fu.IsValidHero(brewTarget)
				print(
					string.format(
						"[OHA-ALCHEMIST] t=%.0f concoction start why=%s target=%s dist=%.0f targetHp=%.2f mode=%s range=%.0f",
						DotaTime(),
						brewWhy,
						UnitNameOrNone(brewTarget),
						hasTarget and GetUnitToUnitDistance(bot, brewTarget) or -1,
						hasTarget and Fu.GetHP(brewTarget) or -1,
						tostring(bot:GetActiveMode()),
						unstableConcoctionThrowAbility:GetCastRange()
					)
				)
			end)
		end
		bot:Action_UseAbility(unstableConcoctionAbility)
		concoctionStartTime = DotaTime()
		return
	end
	acidSprayDesire, acidSprayLocation = X.ConsiderAcidSpray()
	if acidSprayDesire > 0 and not HoldsCastWhileBrewing("acid_spray", brewing, brewed) then
		Fu.SetQueuePtToINT(bot, false)
		bot:Action_UseAbilityOnLocation(acidSprayAbility, acidSprayLocation)
		return
	end
	berserkPotionDesire, berserkPotionTarget = X.ConsiderBerserkPotion()
	if berserkPotionDesire > 0 and not HoldsCastWhileBrewing("berserk_potion", brewing, brewed) then
		bot:Action_UseAbilityOnEntity(berserkPotionAbility, berserkPotionTarget)
		return
	end
	-- Not hidden and castable is the pair the throw itself has always been gated on.
	if brewing and not brewRetreating and unstableConcoctionThrowAbility:IsFullyCastable() then
		X.ConcoctionKeepRange(brewed)
	end
end
function X.ConsiderAcidSpray()
	if not acidSprayAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local castRange = acidSprayAbility:GetCastRange()
	local castPoint = acidSprayAbility:GetCastPoint()
	local radius = acidSprayAbility:GetSpecialValueInt("radius")
	botTarget = Fu.GetProperTarget(bot)
	if Fu.IsInTeamFight(bot, 1200) then
		local aoeLocation = bot:FindAoELocation(true, true, bot:GetLocation(), castRange, radius, castPoint, 0)
		if aoeLocation.count >= 2 then
			local enemiesInRadius = Fu.GetEnemiesNearLoc(aoeLocation.targetloc, radius)
			if enemiesInRadius ~= nil and #enemiesInRadius >= 2 then
				return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
			end
		end
	end
	if isEngaging then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, 900, false, BOT_MODE_NONE)
		-- fix: nInRangeEnemy was an undefined global here, so engaging never used Acid Spray
		local nInRangeEnemy = Fu.GetNearbyHeroes(bot, 900, true, BOT_MODE_NONE)
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			-- fix: dropped "target attacking and facing Alchemist": Acid Spray (armor reduction) was then
			-- never thrown on a target that runs, the usual case when Alchemist engages.
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not botTarget:HasModifier("modifier_dazzle_shallow_grave")
			and nearbyAllies ~= nil
			and nInRangeEnemy ~= nil
			and #nearbyAllies >= #nInRangeEnemy
		then
			local targetAllies = Fu.GetNearbyHeroes(botTarget, 900, false, BOT_MODE_NONE)
			if nearbyAllies ~= nil and targetAllies ~= nil and #nearbyAllies >= #targetAllies then
				return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
			end
		end
	end
	if isRetreating then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, 1000, false, BOT_MODE_NONE)
		local nInRangeEnemy = Fu.GetNearbyHeroes(bot, 1000, true, BOT_MODE_NONE)
		if
			nearbyAllies ~= nil
			and nInRangeEnemy
			and Fu.IsValidHero(nInRangeEnemy[1])
			and Fu.CanCastOnNonMagicImmune(nInRangeEnemy[1])
			and Fu.IsInRange(bot, nInRangeEnemy[1], 600)
			and Fu.IsRunning(nInRangeEnemy[1])
			and nInRangeEnemy[1]:IsFacingLocation(bot:GetLocation(), 30)
			and not Fu.IsSuspiciousIllusion(nInRangeEnemy[1])
			and not Fu.IsDisabled(nInRangeEnemy[1])
		then
			local targetAllies = Fu.GetNearbyHeroes(nInRangeEnemy[1], 800, false, BOT_MODE_NONE)
			if
				targetAllies ~= nil
				and (#targetAllies > #nearbyAllies or hpRatio < 0.45 and bot:WasRecentlyDamagedByAnyHero(2.5))
			then
				return BOT_ACTION_DESIRE_HIGH, bot:GetLocation()
			end
		end
	end
	if Fu.IsDefending(bot) or Fu.IsPushing(bot) then
		local laneCreeps = bot:GetNearbyLaneCreeps(castRange, true)
		local aoeLocation = bot:FindAoELocation(true, false, bot:GetLocation(), castRange, radius, 0, 0)
		local allyLaneFront = GetLaneFrontLocation(GetTeam(), bot:GetAssignedLane(), 0)
		local enemyLaneFront = GetLaneFrontLocation(GetOpposingTeam(), bot:GetAssignedLane(), 0)
		if
			laneCreeps ~= nil
			and #laneCreeps >= 5
			and aoeLocation.count >= 5
			and Fu.GetLocationToLocationDistance(allyLaneFront, enemyLaneFront) < 150
		then
			return BOT_ACTION_DESIRE_MODERATE, aoeLocation.targetloc
		end
	end
	if Fu.IsFarming(bot) then
		local aoeLocation = bot:FindAoELocation(true, false, bot:GetLocation(), castRange, radius, 0, 0)
		local neutralCreeps = bot:GetNearbyNeutralCreeps(600)
		local laneCreeps = bot:GetNearbyLaneCreeps(600, true)
		if isAttacking and Fu.GetMP(bot) > 0.33 then
			if
				neutralCreeps ~= nil
				and (
					#neutralCreeps >= 3 and aoeLocation.count >= 3
					or #neutralCreeps >= 2 and aoeLocation.count >= 2 and neutralCreeps[1]:IsAncientCreep()
				)
			then
				return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
			end
			if laneCreeps ~= nil and #laneCreeps >= 4 and aoeLocation.count >= 4 then
				return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
			end
		end
	end
	if Fu.IsLaning(bot) then
		local laneCreeps = bot:GetNearbyLaneCreeps(600, true)
		local aoeLocation = bot:FindAoELocation(true, false, bot:GetLocation(), castRange, radius, 0, 0)
		if isAttacking and Fu.GetMP(bot) > 0.65 then
			if laneCreeps ~= nil and #laneCreeps >= 4 and aoeLocation.count >= 4 then
				return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
			end
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if
			Fu.IsRoshan(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, 500)
			and isAttacking
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, 400) and isAttacking then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
-- How a hero the allies are finishing can still get away (maintainer, 2026-11-21): "tp" (teleporting or
-- channeling), "blink" (a Blink Dagger ready and moving), "runner" (moving and not facing him), or nil.
local function EscapeKind(enemyHero)
	if enemyHero:HasModifier("modifier_teleporting") or enemyHero:IsChanneling() then
		return "tp"
	end
	local moving = Fu.IsRunning(enemyHero)
	if not moving then
		return nil
	end
	local okBlink, blinkReady = pcall(function()
		for slot = 0, 5 do
			local item = enemyHero:GetItemInSlot(slot)
			if
				item ~= nil
				and string.find(item:GetName(), "blink", 1, true) ~= nil
				and item:GetCooldownTimeRemaining() <= 0
			then
				return true
			end
		end
		return false
	end)
	if okBlink and blinkReady then
		return "blink"
	end
	if not enemyHero:IsFacingLocation(bot:GetLocation(), 90) then
		return "runner"
	end
	return nil
end
-- A brew start on a low hero his allies are finishing (ConcoctionRules.AlliesFinishing), for the kill and engage
-- starts. His allies are counted from his own list (within 1600 of him) when their attack target is that hero,
-- himself not. Returns nil when it is not that case (the normal rules decide), "save" (no brew) or "help" (start a
-- help brew; pendingHelp holds the escape kind, "held" when it is not escaping), with ConcoctionRules.FinishingPlan:
-- escaping: help, thrown early (X.ConsiderHelpThrow); not escaping with another enemy hero within 1200: save the
-- brew for that one; nobody else near: help anyway, thrown at once (the cooldown is free then).
-- [OHA-ALCHEMIST] concoction no-brew why=save-for-next other= and help-start kind=, each at most every 5s.
local function FinishingCase(enemyHero, rule)
	local targetHp = Fu.GetHP(enemyHero)
	if targetHp >= ConcoctionRules.FINISH_HP then
		return nil
	end
	local alliesOnTarget = 0
	for _, allyHero in pairs(Fu.GetNearbyHeroes(bot, 1600, false, BOT_MODE_NONE) or {}) do
		if
			Fu.IsValidHero(allyHero)
			and allyHero:GetUnitName() ~= bot:GetUnitName()
			and not allyHero:IsIllusion()
			and allyHero:GetAttackTarget() == enemyHero
		then
			alliesOnTarget = alliesOnTarget + 1
		end
	end
	if not ConcoctionRules.AlliesFinishing(targetHp, alliesOnTarget) then
		return nil
	end
	local other = nil
	for _, otherHero in pairs(Fu.GetNearbyHeroes(bot, ConcoctionRules.SAVE_RADIUS, true, BOT_MODE_NONE) or {}) do
		if
			otherHero ~= enemyHero
			and Fu.IsValidHero(otherHero)
			and otherHero:IsAlive()
			and not Fu.IsSuspiciousIllusion(otherHero)
		then
			other = otherHero
			break
		end
	end
	local escape = EscapeKind(enemyHero)
	local plan = ConcoctionRules.FinishingPlan(escape, other ~= nil)
	if plan == "save" then
		if DotaTime() >= (bot._alchFinishLogAt or -999) then
			bot._alchFinishLogAt = DotaTime() + 5
			pcall(
				print,
				string.format(
					"[OHA-ALCHEMIST] t=%.0f concoction no-brew why=save-for-next rule=%s target=%s hp=%.2f allies=%d other=%s",
					DotaTime(),
					rule,
					enemyHero:GetUnitName(),
					targetHp,
					alliesOnTarget,
					other:GetUnitName()
				)
			)
		end
		return "save"
	end
	pendingHelp = { kind = plan == "help" and escape or "held", target = enemyHero }
	if DotaTime() >= (bot._alchHelpLogAt or -999) then
		bot._alchHelpLogAt = DotaTime() + 5
		pcall(
			print,
			string.format(
				"[OHA-ALCHEMIST] t=%.0f concoction help-start rule=%s target=%s hp=%.2f allies=%d kind=%s other=%s",
				DotaTime(),
				rule,
				enemyHero:GetUnitName(),
				targetHp,
				alliesOnTarget,
				pendingHelp.kind,
				UnitNameOrNone(other)
			)
		)
	end
	return "help"
end
-- #34 (c): logs a kill or engage start that the retreat mode stops (X.ConcoctionRetreatWanted), at most every 5s.
local function RetreatStopsBrew(enemyHero, rule)
	local wanted, desire, line = RetreatWanted()
	if not wanted then
		return false
	end
	if DotaTime() >= (bot._alchRetreatNoBrewLogAt or -999) then
		bot._alchRetreatNoBrewLogAt = DotaTime() + 5
		pcall(
			print,
			string.format(
				"[OHA-ALCHEMIST] t=%.0f concoction no-brew why=retreat-wanted rule=%s target=%s desire=%.2f line=%d mode=%s",
				DotaTime(),
				rule,
				enemyHero:GetUnitName(),
				desire,
				line,
				tostring(bot:GetActiveMode())
			)
		)
	end
	return true
end
-- Damage of our team already on its way to an enemy hero: our projectiles in flight at it (an attack: the
-- caster's attack damage; a spell: its AbilityDamage, else the caster's attack damage, as for attack-based shots
-- like Acorn Shot) and the next hit of every allied hero attacking it from within its attack range (+100).
-- Not his own. Whether GetIncomingTrackingProjectiles lists our projectiles on an enemy hero is unverified, so it
-- runs in pcall and the no-brew line prints both parts (proj= in flight, hits= allies' next hits).
local function AllyPendingDamage(enemyHero)
	local projectiles, hits = 0, 0
	pcall(function()
		for _, projectile in pairs(enemyHero:GetIncomingTrackingProjectiles() or {}) do
			local caster = projectile.caster
			if caster ~= nil and not caster:IsNull() and caster:GetTeam() == GetTeam() and caster ~= bot then
				local damage, damageType = caster:GetAttackDamage(), DAMAGE_TYPE_PHYSICAL
				if not projectile.is_attack and projectile.ability ~= nil and not projectile.ability:IsNull() then
					local abilityDamage = projectile.ability:GetAbilityDamage() or 0
					if abilityDamage > 0 then
						damage, damageType = abilityDamage, projectile.ability:GetDamageType()
					end
				end
				projectiles = projectiles + enemyHero:GetActualIncomingDamage(damage, damageType)
			end
		end
	end)
	for _, allyHero in pairs(Fu.GetNearbyHeroes(bot, 1600, false, BOT_MODE_NONE) or {}) do
		if
			Fu.IsValidHero(allyHero)
			and allyHero ~= bot
			and not allyHero:IsIllusion()
			and allyHero:GetAttackTarget() == enemyHero
			and GetUnitToUnitDistance(allyHero, enemyHero) <= allyHero:GetAttackRange() + 100
		then
			hits = hits + enemyHero:GetActualIncomingDamage(allyHero:GetAttackDamage(), DAMAGE_TYPE_PHYSICAL)
		end
	end
	return projectiles + hits, projectiles, hits
end
-- #34, game 064 (ConcoctionRules.FinishedWithoutBrew): no kill or engage brew on a hero his next hit or our
-- team's damage on its way kills, whether or not it is running. [OHA-ALCHEMIST] no-brew why=finish-hit, every 5s.
local function FinishHitStopsBrew(enemyHero, rule)
	local health = enemyHero:GetHealth()
	local ownHit = enemyHero:GetActualIncomingDamage(bot:GetAttackDamage(), DAMAGE_TYPE_PHYSICAL)
	local ownInReach = GetUnitToUnitDistance(bot, enemyHero) <= bot:GetAttackRange() + 150
	local allyPending, allyProjectiles, allyHits = AllyPendingDamage(enemyHero)
	local by = ConcoctionRules.FinishedWithoutBrew(health, ownHit, ownInReach, allyPending)
	if by == nil then
		return false
	end
	if DotaTime() >= (bot._alchFinishHitLogAt or -999) then
		bot._alchFinishHitLogAt = DotaTime() + 5
		pcall(
			print,
			string.format(
				"[OHA-ALCHEMIST] t=%.0f concoction no-brew why=finish-hit by=%s rule=%s target=%s hp=%d hit=%d"
					.. " inReach=%s allyPending=%d proj=%d hits=%d dist=%.0f escape=%s",
				DotaTime(),
				by,
				rule,
				enemyHero:GetUnitName(),
				health,
				ownHit,
				tostring(ownInReach),
				allyPending,
				allyProjectiles,
				allyHits,
				GetUnitToUnitDistance(bot, enemyHero),
				tostring(EscapeKind(enemyHero))
			)
		)
	end
	return true
end
-- Returns the desire, the hero the brew is for and the rule that fired (kill, channel, engage, retreat).
function X.ConsiderUnstableConcoction()
	if not unstableConcoctionAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
	end
	-- fix: Unstable Concoction is NO_TARGET with no AbilityCastRange (game data), so unstableConcoctionAbility:GetCastRange()
	-- was 0 and every check below (castRange, castRange - 200, castRange - 175) found nobody: the brew was never started.
	-- Use the throw's range (775), which is where the brew has to land.
	local castRange = unstableConcoctionThrowAbility:GetCastRange()
	local maxDamage = unstableConcoctionAbility:GetSpecialValueInt("max_damage")
	local brewTime = ConcoctionBrewTime()
	local nearbyEnemies = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and Fu.IsInRange(bot, enemyHero, castRange - 200)
			and not Fu.IsSuspiciousIllusion(enemyHero)
		then
			if enemyHero:IsChanneling() then
				-- A channeling hero the allies are finishing (often a Town Portal out): a help brew, timed so the
				-- stun lands before the channel ends (X.ConsiderHelpThrow).
				if FinishingCase(enemyHero, "channel") == "help" then
					return BOT_ACTION_DESIRE_HIGH, enemyHero, "help"
				end
				return BOT_ACTION_DESIRE_HIGH, enemyHero, "channel"
			end
			if
				Fu.CanKillTarget(enemyHero, maxDamage, DAMAGE_TYPE_PHYSICAL)
				and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
				and not enemyHero:HasModifier("modifier_abaddon_aphotic_shield")
				and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
				and not enemyHero:HasModifier("modifier_enigma_black_hole_pull")
				and not enemyHero:HasModifier("modifier_faceless_void_chronosphere_freeze")
				and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
				and not enemyHero:HasModifier("modifier_item_solar_crest_armor_addition")
				and not FinishHitStopsBrew(enemyHero, "kill")
			then
				-- #34: the damage grows with the brew time, so the kill needs this many seconds of brewing.
				-- A target that runs off faster than he follows is out of range by then: no brew for it.
				local lethalAfter = brewTime
					* enemyHero:GetHealth()
					/ math.max(1, enemyHero:GetActualIncomingDamage(maxDamage, DAMAGE_TYPE_PHYSICAL))
				-- His attacks: the first hit lands about at once, every next one a full attack later.
				local attackKillSeconds = nil
				if GetUnitToUnitDistance(bot, enemyHero) <= bot:GetAttackRange() + 150 then
					local perHit = enemyHero:GetActualIncomingDamage(bot:GetAttackDamage(), DAMAGE_TYPE_PHYSICAL)
					local hits = math.ceil(enemyHero:GetHealth() / math.max(1, perHit))
					attackKillSeconds = (hits - 1) * bot:GetSecondsPerAttack()
				end
				-- (b) only for a hero that is not getting away: a runner, a Blink or a Town Portal needs the stun.
				local finishing = nil
				local attackInstead = X.ConcoctionKillTooEasy(lethalAfter, attackKillSeconds)
					and EscapeKind(enemyHero) == nil
				if attackInstead then
					-- (b): his attacks kill it as fast; [OHA-ALCHEMIST] no-brew why=attack-kill, at most every 5s.
					if DotaTime() >= (bot._alchEasyKillLogAt or -999) then
						bot._alchEasyKillLogAt = DotaTime() + 5
						pcall(
							print,
							string.format(
								"[OHA-ALCHEMIST] t=%.0f concoction no-brew why=attack-kill target=%s hp=%.2f lethalAfter=%.2fs"
									.. " attackKill=%.2fs",
								DotaTime(),
								enemyHero:GetUnitName(),
								Fu.GetHP(enemyHero),
								lethalAfter,
								attackKillSeconds or -1
							)
						)
					end
				else
					finishing = FinishingCase(enemyHero, "kill")
					if finishing == "help" and not RetreatStopsBrew(enemyHero, "kill") then
						return BOT_ACTION_DESIRE_HIGH, enemyHero, "help"
					end
				end
				if
					finishing == nil
					and not attackInstead
					and WillStayInThrowRange(enemyHero, lethalAfter, castRange, false)
					and not RetreatStopsBrew(enemyHero, "kill")
				then
					return BOT_ACTION_DESIRE_HIGH, enemyHero, "kill"
				end
			end
		end
	end
	if isEngaging then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, 1000, false, BOT_MODE_NONE)
		local nInRangeEnemy = Fu.GetNearbyHeroes(bot, castRange - 175, true, BOT_MODE_NONE)
		for _, enemyHero in pairs(nInRangeEnemy) do
			if
				Fu.IsValidTarget(enemyHero)
				-- #34 (d), game 063 t=2060: an engage start at dist=614 from this list of "within 600": the list is
				-- not exact at its edge, so the distance is checked here.
				and GetUnitToUnitDistance(bot, enemyHero) <= castRange - 175
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and not Fu.IsDisabled(enemyHero)
				and not enemyHero:HasModifier("modifier_enigma_black_hole_pull")
				and not enemyHero:HasModifier("modifier_faceless_void_chronosphere_freeze")
				and not enemyHero:HasModifier("modifier_legion_commander_duel")
				and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
				-- #34: only a target that is still in range at the earliest early throw (2s).
				and WillStayInThrowRange(enemyHero, retreatThrowDelay, castRange, false)
				-- #34, game 064: a low hero the next hit kills is not a reason for an engage brew either.
				and not FinishHitStopsBrew(enemyHero, "engage")
			then
				local targetAllies = Fu.GetNearbyHeroes(enemyHero, 1000, false, BOT_MODE_NONE)
				if nearbyAllies ~= nil and targetAllies ~= nil and #nearbyAllies >= #targetAllies then
					local finishing = FinishingCase(enemyHero, "engage")
					if finishing ~= "save" and not RetreatStopsBrew(enemyHero, "engage") then
						return BOT_ACTION_DESIRE_HIGH, enemyHero, finishing == "help" and "help" or "engage"
					end
				end
			end
		end
	end
	if isRetreating then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, castRange + 175, false, BOT_MODE_NONE)
		local nInRangeEnemy = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
		local chaser = nInRangeEnemy ~= nil and nInRangeEnemy[1] or nil
		if
			nearbyAllies ~= nil
			and Fu.IsValidHero(chaser)
			and Fu.CanCastOnNonMagicImmune(chaser)
			and Fu.IsInRange(bot, chaser, castRange - 175)
			and Fu.IsRunning(chaser)
			and chaser:IsFacingLocation(bot:GetLocation(), 30)
			and not Fu.IsSuspiciousIllusion(chaser)
			and not Fu.IsDisabled(chaser)
			and not chaser:HasModifier("modifier_enigma_black_hole_pull")
			and not chaser:HasModifier("modifier_faceless_void_chronosphere_freeze")
			and not chaser:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			local targetAllies = Fu.GetNearbyHeroes(chaser, 800, false, BOT_MODE_NONE)
			if
				targetAllies ~= nil
				and (#targetAllies > #nearbyAllies or hpRatio < 0.6 and bot:WasRecentlyDamagedByAnyHero(2.2))
			then
				-- #34: a hero within 600 that runs at him was enough, and he then carried the brew away from it.
				-- Now the chaser has to be on him (attacking him, or within 350) and still inside the throw
				-- range at the retreat throw (2s), counting both speeds.
				local chaserDist = GetUnitToUnitDistance(bot, chaser)
				local onHim = chaser:GetAttackTarget() == bot or chaserDist <= 350
				local staysInRange, gapAtThrow = WillStayInThrowRange(chaser, retreatThrowDelay, castRange, true)
				if onHim and staysInRange then
					return BOT_ACTION_DESIRE_HIGH, chaser, "retreat"
				end
				if DotaTime() >= (bot._alchSkipLogAt or -999) then
					bot._alchSkipLogAt = DotaTime() + 5
					pcall(function()
						print(
							string.format(
								"[OHA-ALCHEMIST] t=%.0f concoction no-brew why=retreat chaser=%s dist=%.0f onHim=%s gapAt2s=%.0f",
								DotaTime(),
								UnitNameOrNone(chaser),
								chaserDist,
								tostring(onHim),
								gapAtThrow
							)
						)
					end)
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
-- Enemy Town Portals in sight (#34): is the modifier's time left real? Game 063 (t=1834) read 3.00 left on a Zeus
-- TP, the full channel. On the first think an enemy hero within 1600 has modifier_teleporting, its time left is
-- read; 0.2s or more later it is read again (ConcoctionRules.TpReadIsReal). One line per TP:
--   [OHA-ALCHEMIST] tp-left target= first= second= dt= real=yes|no|unknown channel=
-- (unknown: the TP ended or went out of sight before the second read). Keyed by player ID.
local tpSeen = {}
local function TpChannelOf(enemyHero)
	local okBoots, hasBoots2 = pcall(function()
		for slot = 0, 5 do
			local item = enemyHero:GetItemInSlot(slot)
			if item ~= nil and item:GetName() == "item_travel_boots_2" then
				return true
			end
		end
		return false
	end)
	if okBoots and hasBoots2 then
		return ConcoctionRules.TP_CHANNEL_BOOTS2
	end
	return ConcoctionRules.TP_CHANNEL
end
local function LogTpLeft(entry)
	entry.logged = true
	local real = entry.real == true and "yes" or entry.real == false and "no" or "unknown"
	pcall(
		print,
		string.format(
			"[OHA-ALCHEMIST] t=%.0f tp-left target=%s first=%.2f second=%.2f dt=%.2f real=%s channel=%.1f",
			DotaTime(),
			entry.name,
			entry.first,
			entry.second or -1,
			entry.dt or -1,
			real,
			entry.channel
		)
	)
end
function X.TrackEnemyTeleports()
	local now = DotaTime()
	local seenNow = {}
	for _, enemyHero in pairs(Fu.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE) or {}) do
		if Fu.IsValidHero(enemyHero) and enemyHero:HasModifier("modifier_teleporting") then
			local id = enemyHero:GetPlayerID()
			seenNow[id] = true
			local read = Fu.GetModifierTime(enemyHero, "modifier_teleporting")
			local entry = tpSeen[id]
			if entry == nil then
				tpSeen[id] = {
					seenAt = now,
					first = read,
					channel = TpChannelOf(enemyHero),
					name = enemyHero:GetUnitName(),
				}
			elseif entry.second == nil and now - entry.seenAt >= 0.2 then
				entry.second, entry.dt = read, now - entry.seenAt
				entry.real = ConcoctionRules.TpReadIsReal(entry.first, entry.second, entry.dt)
				LogTpLeft(entry)
			end
		end
	end
	for id, entry in pairs(tpSeen) do
		if not seenNow[id] then
			if not entry.logged then
				LogTpLeft(entry)
			end
			tpSeen[id] = nil
		end
	end
end
-- Seconds left of a target's teleport for the help throw (ConcoctionRules.TpTimeLeft): the read when it proved
-- real, else the time since it was first seen, with the read as an upper bound. 0 when nothing is known.
function X.TpTimeLeft(target)
	local read = Fu.GetModifierTime(target, "modifier_teleporting")
	local entry = tpSeen[target:GetPlayerID()]
	if entry == nil then
		return read
	end
	return ConcoctionRules.TpTimeLeft(entry.seenAt, DotaTime(), entry.channel, read, entry.real)
end
-- A help brew (FinishingCase) goes out early, as soon as ConcoctionRules.HelpThrowNow says: the stun of the brew
-- so far (linear from min_stun at 0s to max_stun at brew_time, read from the ability) covers about 1s for a runner
-- or a Blink, the stun lands before a Town Portal or channel ends (throw cast point and projectile_speed from the
-- throw ability), or at once for a held hero with nobody else near. Returns the target, or nil.
function X.ConsiderHelpThrow(brewed, castRange)
	if brewHelp == nil then
		return nil
	end
	local target = brewHelp.target
	if
		not Fu.IsValidHero(target)
		or not target:IsAlive()
		or not target:CanBeSeen()
		or not Fu.CanCastOnNonMagicImmune(target)
	then
		return nil
	end
	local distance = GetUnitToUnitDistance(bot, target)
	if distance > castRange then
		return nil
	end
	local minStun = unstableConcoctionAbility:GetSpecialValueFloat("min_stun")
	local maxStun = unstableConcoctionAbility:GetSpecialValueFloat("max_stun")
	if minStun == nil or minStun <= 0 then
		minStun = 0.25
	end
	if maxStun == nil or maxStun <= minStun then
		maxStun = 1.7
	end
	local stun = ConcoctionRules.StunAt(brewed, minStun, maxStun, ConcoctionBrewTime())
	local speed = unstableConcoctionThrowAbility:GetSpecialValueInt("projectile_speed")
	local okPoint, castPoint = pcall(function()
		return unstableConcoctionThrowAbility:GetCastPoint()
	end)
	local landTime = ConcoctionRules.LandTime(
		distance,
		okPoint and type(castPoint) == "number" and castPoint or nil,
		speed ~= nil and speed > 0 and speed or nil
	)
	local tpLeft = nil
	if brewHelp.kind == "tp" then
		tpLeft = X.TpTimeLeft(target)
	end
	if not ConcoctionRules.HelpThrowNow(brewHelp.kind, brewed, stun, tpLeft, landTime) then
		return nil
	end
	helpStun = stun
	return target
end
-- Returns the desire, the target and the rule that fired (the caller logs the throw).
function X.ConsiderUnstableConcoctionThrow()
	if unstableConcoctionThrowAbility:IsHidden() or not unstableConcoctionThrowAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castRange = unstableConcoctionThrowAbility:GetCastRange()
	local maxDamage = unstableConcoctionAbility:GetSpecialValueInt("max_damage")
	local brewed = DotaTime() - concoctionStartTime
	-- #34: what this brew does if thrown now, with a 10% margin (see X.ConcoctionDamageAt). The kill throw
	-- used max_damage and waited for 4.25s: a target that could die earlier got away or died to an ally first
	-- (game 043, 34:56: Kez at 6% HP, the brew ended with nobody in range).
	local damageNow = X.ConcoctionDamageAt(maxDamage, brewed, ConcoctionBrewTime()) * 0.9
	local nearbyEnemies = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and not Fu.IsSuspiciousIllusion(enemyHero)
		then
			-- #34: a channel is interrupted now. Any brew stuns (game data: min_stun 0.25), and waiting for
			-- 4.25s let a Town Portal finish (7.42 items.txt: item_tpscroll AbilityChannelTime 3.0; game 043,
			-- 41:23: Kez teleported out, the brew blew up on him).
			-- The help brew's own target: X.ConsiderHelpThrow times the throw to the channel's end.
			if enemyHero:IsChanneling() and not (brewHelp ~= nil and brewHelp.target == enemyHero) then
				return BOT_ACTION_DESIRE_HIGH, enemyHero, "channel"
			end
			if
				Fu.CanKillTarget(enemyHero, damageNow, DAMAGE_TYPE_PHYSICAL)
				and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
				and not enemyHero:HasModifier("modifier_abaddon_aphotic_shield")
				and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
				and not enemyHero:HasModifier("modifier_enigma_black_hole_pull")
				and not enemyHero:HasModifier("modifier_faceless_void_chronosphere_freeze")
				and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
				and not enemyHero:HasModifier("modifier_item_solar_crest_armor_addition")
			then
				return BOT_ACTION_DESIRE_HIGH, enemyHero, "kill"
			end
		end
	end
	local helpTarget = X.ConsiderHelpThrow(brewed, castRange)
	if helpTarget ~= nil then
		return BOT_ACTION_DESIRE_HIGH, helpTarget, "help-early"
	end
	local nearestCastable, nearestCastableDist = NearestCastable(nearbyEnemies)
	if nearestCastable ~= nil then
		-- #34, game 057: throw before a likely disable instead of holding the brew for the full stun (see
		-- X.ConcoctionThreat). At the brew target when it is in range, else the nearest hero.
		local threat = X.ConcoctionThreat(brewed, ReadBrewThreat())
		if threat ~= nil then
			brewThreatKind = threat
			local threatTarget = nearestCastable
			if
				not BrewTargetLost()
				and Fu.CanCastOnNonMagicImmune(brewTarget)
				and not Fu.IsSuspiciousIllusion(brewTarget)
				and GetUnitToUnitDistance(bot, brewTarget) <= castRange
			then
				threatTarget = brewTarget
			end
			return BOT_ACTION_DESIRE_HIGH, threatTarget, "stun-threat"
		end
		-- #34, game 057: the brew target died or went out of sight (16:27: Zeus died 1s into the brew; at 2.6s
		-- Puck stood at 614, inside the throw range, and no rule threw at him before he left). Any other hero in
		-- range takes the brew from 1.0s on.
		-- (f), game 063 t=2256: thrown at Weaver at 772 of 775 at 4.0s, the cast never went out and nobody was in
		-- range after it. Until 3.0s brewed only a hero within 0.9 of the range takes it (keep-range walks him
		-- closer to a farther one); from 3.0s the nearest one, wherever it is in the range.
		if brewed >= 1.0 and BrewTargetLost() then
			if nearestCastableDist <= castRange * X.TARGET_LOST_INNER or brewed >= X.TARGET_LOST_ANY_AFTER then
				return BOT_ACTION_DESIRE_HIGH, nearestCastable, "target-lost"
			end
		end
	end
	if isEngaging then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, 1000, false, BOT_MODE_NONE)
		local nInRangeEnemy = Fu.GetNearbyHeroes(bot, castRange - 175, true, BOT_MODE_NONE)
		for _, enemyHero in pairs(nInRangeEnemy) do
			if
				Fu.IsValidTarget(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and not Fu.IsDisabled(enemyHero)
				and not enemyHero:HasModifier("modifier_enigma_black_hole_pull")
				and not enemyHero:HasModifier("modifier_faceless_void_chronosphere_freeze")
				and not enemyHero:HasModifier("modifier_legion_commander_duel")
				and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
				and brewed >= fullBrewThrowDelay
			then
				local targetAllies = Fu.GetNearbyHeroes(enemyHero, 1000, false, BOT_MODE_NONE)
				if nearbyAllies ~= nil and targetAllies ~= nil and #nearbyAllies >= #targetAllies then
					return BOT_ACTION_DESIRE_HIGH, enemyHero, "engage"
				end
			end
		end
	end
	-- Retreating: from 2s brewed, the nearest hero in range. #34: it also asked for "outnumbered, or below 60%
	-- HP and just hit"; without that he carried the brew away and it blew up on him (game 040, 3:35-3:40:
	-- retreat at 0.60 with 83% HP, two enemies near, "no-target" at 5.0s).
	if
		isRetreating
		and brewed >= retreatThrowDelay
		and nearestCastable ~= nil
		and not nearestCastable:HasModifier("modifier_enigma_black_hole_pull")
		and not nearestCastable:HasModifier("modifier_faceless_void_chronosphere_freeze")
		and not nearestCastable:HasModifier("modifier_necrolyte_reapers_scythe")
	then
		return BOT_ACTION_DESIRE_HIGH, nearestCastable, "retreat"
	end
	-- #34, losing the last target: every hero he can throw at is in the outer fifth of the range and the
	-- nearest one leaves it within a second at the measured rate (his own walking included, whatever mode
	-- moves him). Thrown at any brew time: a weak throw (game data: min_stun 0.25, min_damage 0) beats the
	-- full stun and damage on himself. Games 039 (32:38) and 040 (7:55, 9:03): the 4.3s throw was ordered on
	-- a hero at the edge, never carried out, and 0.7s later nobody was in range.
	if nearestCastable ~= nil then
		local now = DotaTime()
		if gapSampleUnit ~= nearestCastable or now - gapSampleAt > 1.0 then
			gapSampleUnit, gapSampleDist, gapSampleAt = nearestCastable, nearestCastableDist, now
		elseif now - gapSampleAt >= 0.2 then
			local rate = (nearestCastableDist - gapSampleDist) / (now - gapSampleAt)
			gapSampleDist, gapSampleAt = nearestCastableDist, now
			if
				brewed >= 0.3
				and nearestCastableDist > castRange * 0.8
				and X.ConcoctionSecondsInRange(nearestCastableDist, rate, castRange) < 1.0
			then
				return BOT_ACTION_DESIRE_HIGH, nearestCastable, "last-target"
			end
		end
	else
		gapSampleUnit = nil
	end
	-- Fallback: the nearest hero in range once the brew is (nearly) full. Game data: brew_time 5.0 for the
	-- full stun/damage. It used the 2s gate (retreatThrowDelay), so whenever an enemy was in range it threw
	-- at ~2s, ahead of the 4.25s (fullBrewThrowDelay) engage branch above. #34: it took the first hero of the
	-- list, anywhere within the range; the nearest one is the one the order reaches.
	if nearestCastable ~= nil and brewed >= fullBrewThrowDelay then
		return BOT_ACTION_DESIRE_HIGH, nearestCastable, "fallback"
	end
	-- Forced throw before the brew explodes on him (5.5s; 0.2s cast point): from 5.0s brewed, the nearest
	-- enemy hero he can target, illusions included. The throw targets heroes only (game data: target type
	-- HERO, flag NOT_CREEP_HERO), so with no hero in range nothing can be thrown and it is logged.
	local explodeAt = ConcoctionExplodeAt()
	-- Early throw: from 2s brewed, a target near the edge of range that is not facing him is walking away;
	-- throw now instead of holding to 4.25s and losing it (game 038: 13 self-explosions, "no-target" at 5.0s).
	if brewed >= retreatThrowDelay and brewed < explodeAt - 0.5 then
		for _, enemyHero in pairs(nearbyEnemies or {}) do
			if
				CanHitWithThrow(enemyHero)
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and GetUnitToUnitDistance(bot, enemyHero) > castRange * 0.8
				and not enemyHero:IsFacingLocation(bot:GetLocation(), 90)
			then
				return BOT_ACTION_DESIRE_HIGH, enemyHero, "leaving"
			end
		end
	end
	if brewed >= explodeAt - 0.5 and brewed < explodeAt + 1 then
		-- Prefer a real hero; otherwise the nearest illusion (the explosion is AoE, so a real hero next to
		-- it is hit too). Game 039, 30:42: the old filter (Fu.CanCastOnNonMagicImmune) rejects suspicious
		-- illusions, so with only Phantom Lancer's illusions in range the brew blew up on him.
		local nearest, _, nearestIllusion = NearestThrowTargets(castRange + 100)
		if nearest == nil then
			nearest = nearestIllusion
		end
		if nearest ~= nil then
			return BOT_ACTION_DESIRE_ABSOLUTE, nearest, "forced"
		end
		if DotaTime() >= (bot._alchNoTargetLogAt or -999) then
			bot._alchNoTargetLogAt = DotaTime() + 3
			pcall(
				print,
				string.format(
					"[OHA-ALCHEMIST] t=%.0f concoction throw why=no-target brewed=%.1fs explode=%.1f",
					DotaTime(),
					brewed,
					explodeAt
				)
			)
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function X.ConsiderChemicalRage()
	if not chemicalRageAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
	end
	botTarget = Fu.GetProperTarget(bot)
	if Fu.IsInTeamFight(bot, 1200) then
		local enemiesNearby = Fu.GetEnemiesNearLoc(bot:GetLocation(), 700)
		if enemiesNearby ~= nil and #enemiesNearby >= 2 then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if isEngaging then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, 1000, false, BOT_MODE_NONE)
		if
			Fu.IsValidTarget(botTarget)
			and Fu.IsInRange(bot, botTarget, 800)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not botTarget:HasModifier("modifier_enigma_black_hole_pull")
			and not botTarget:HasModifier("modifier_faceless_void_chronosphere_freeze")
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			local targetAllies = Fu.GetNearbyHeroes(botTarget, 1000, false, BOT_MODE_NONE)
			if nearbyAllies ~= nil and targetAllies ~= nil and #nearbyAllies >= #targetAllies then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	if isRetreating then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, 800, false, BOT_MODE_NONE)
		local nInRangeEnemy = Fu.GetNearbyHeroes(bot, 800, true, BOT_MODE_NONE)
		if
			nearbyAllies ~= nil
			and nInRangeEnemy ~= nil
			and Fu.IsValidHero(nInRangeEnemy[1])
			and Fu.IsRunning(nInRangeEnemy[1])
			and nInRangeEnemy[1]:IsFacingLocation(bot:GetLocation(), 30)
			and not Fu.IsSuspiciousIllusion(nInRangeEnemy[1])
			and not Fu.IsDisabled(nInRangeEnemy[1])
			and not nInRangeEnemy[1]:HasModifier("modifier_enigma_black_hole_pull")
			and not nInRangeEnemy[1]:HasModifier("modifier_faceless_void_chronosphere_freeze")
			and not nInRangeEnemy[1]:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			local targetAllies = Fu.GetNearbyHeroes(nInRangeEnemy[1], 800, false, BOT_MODE_NONE)
			if
				targetAllies ~= nil
				and (#targetAllies > #nearbyAllies or hpRatio < 0.35 and bot:WasRecentlyDamagedByAnyHero(1.5))
			then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	if Fu.IsFarming(bot) then
		if isAttacking and Fu.IsValid(botTarget) and botTarget:IsCreep() and hpRatio < 0.3 then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if
			Fu.IsRoshan(botTarget)
			and Fu.IsInRange(bot, botTarget, 500)
			and isAttacking
			and (Fu.IsModeTurbo() and DotaTime() < 15 * 60 or DotaTime() < 30 * 60)
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if
			Fu.IsTormentor(botTarget)
			and Fu.IsInRange(bot, botTarget, 400)
			and isAttacking
			and (Fu.IsModeTurbo() and DotaTime() < 16 * 60 or DotaTime() < 32 * 60)
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderBerserkPotion()
	if not berserkPotionAbility:IsTrained() or not berserkPotionAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castRange = berserkPotionAbility:GetCastRange()
	local nearbyAllies = Fu.GetNearbyHeroes(bot, castRange, false, BOT_MODE_NONE)
	for _, allyHero in pairs(nearbyAllies) do
		if
			Fu.IsValidHero(allyHero)
			and Fu.IsInRange(bot, allyHero, castRange)
			and not allyHero:HasModifier("modifier_legion_commander_press_the_attack")
			and not allyHero:HasModifier("modifier_item_satanic_unholy")
			and not allyHero:IsMagicImmune()
			and not allyHero:IsInvulnerable()
			and not allyHero:IsIllusion()
			and allyHero:CanBeSeen()
		then
			if Fu.IsDisabled(allyHero) then
				return BOT_ACTION_DESIRE_HIGH, allyHero
			end
			if
				Fu.IsRetreating(allyHero)
				and Fu.IsRunning(allyHero)
				and Fu.GetHP(allyHero) < 0.6
				and allyHero:WasRecentlyDamagedByAnyHero(2.5)
				and allyHero:IsFacingLocation(GetAncient(GetTeam()):GetLocation(), 45)
			then
				return BOT_ACTION_DESIRE_HIGH, allyHero
			end
			if Fu.IsGoingOnSomeone(allyHero) then
				local allyTarget = Fu.GetProperTarget(allyHero)
				if
					Fu.IsValidHero(allyTarget)
					and allyHero:IsFacingLocation(allyTarget:GetLocation(), 20)
					and Fu.IsInRange(allyHero, allyTarget, allyHero:GetAttackRange() + 100)
				then
					return BOT_ACTION_DESIRE_HIGH, allyHero
				end
				if Fu.GetHP(allyHero) < 0.33 then
					return BOT_ACTION_DESIRE_HIGH, allyHero
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
return X
