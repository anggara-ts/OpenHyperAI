-- Alchemist: skill build, item build, and ability use for this hero.
local X = {}
local bot = GetBot()
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local AbilityContext = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local Minion = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local sTalentList = Fu.Skill.GetTalentList(bot)
local sAbilityList = Fu.Skill.GetAbilityList(bot)
local sRole = Fu.Item.GetRoleItemsBuyList(bot)
local tTalentTreeList = { ["t25"] = { 0, 10 }, ["t20"] = { 0, 10 }, ["t15"] = { 10, 0 }, ["t10"] = { 10, 0 } }
local tAllAbilityBuildList = { { 2, 1, 1, 2, 1, 6, 1, 2, 2, 3, 6, 3, 3, 3, 6 } }
local nAbilityBuildList = Fu.Skill.GetRandomBuild(tAllAbilityBuildList)
local nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList)
local sRoleItemsBuyList = {}
sRoleItemsBuyList["pos_1"] = {
	"item_bristleback_outfit",
	"item_soul_ring",
	"item_radiance",
	"item_travel_boots",
	"item_assault",
	"item_blink",
	"item_black_king_bar",
	"item_aghanims_shard",
	"item_abyssal_blade",
	"item_overwhelming_blink",
	"item_moon_shard",
	"item_ultimate_scepter_2",
	"item_travel_boots_2",
}
sRoleItemsBuyList["pos_2"] = sRoleItemsBuyList["pos_1"]
sRoleItemsBuyList["pos_4"] = sRoleItemsBuyList["pos_1"]
sRoleItemsBuyList["pos_5"] = sRoleItemsBuyList["pos_1"]
sRoleItemsBuyList["pos_3"] = sRoleItemsBuyList["pos_1"]
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
local gapSampleUnit, gapSampleDist, gapSampleAt = nil, 0, 0 -- distance sample of the nearest throw target
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
	elseif bot:IsChanneling() then
		return "channeling"
	elseif bot:IsUsingAbility() or bot:IsCastingAbility() then
		return "casting"
	elseif Fu.HasQueuedAction(bot) then
		return "queued"
	end
	return "other"
end
-- Runs every think, above the ability gate: the explosion on himself stuns him, so code below the gate never
-- sees a brew end. Returns whether he is brewing and the seconds brewed. When a brew ends it prints one line:
--   [OHA-ALCHEMIST] concoction brew-end outcome=thrown|self-explode|died|unknown ...
-- self-explode: still brewing at the deadline, or it ended around the deadline with no throw order in this
-- brew (only this file orders the throw), or he is stunned when the end is seen. thrown: a throw was ordered
-- and the brew ended before the deadline. unknown: anything else (this function did not run around the end
-- because the usage file returned before the hero script, and an order was pending).
function X.TrackConcoctionBrew()
	local brewed = DotaTime() - concoctionStartTime
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
		brewSeen = true
		brewSeenAt = brewed
		return true, brewed
	end
	if brewSeen then
		brewSeen = false
		local outcome = "unknown"
		local throwOrdered = lastThrowWhy ~= "none"
		if not bot:IsAlive() then
			outcome = "died"
		elseif brewSeenAt >= explodeAt - 0.07 then
			outcome = "self-explode"
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
			print(
				string.format(
					"[OHA-ALCHEMIST] t=%.0f concoction brew-end outcome=%s brewed=%.1fs seen=%.1fs rule=%s target=%s"
						.. " lastThrow=%s@%.1f gate=%s@%.1f nearest=%s nearestDist=%.0f mode=%s stunned=%s",
					DotaTime(),
					outcome,
					brewed,
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
					tostring(bot:IsStunned())
				)
			)
		end)
	end
	return false, brewed
end
-- One line per throw order (the order repeats while it is not carried out, so 1s per reason).
function X.LogConcoctionThrow(why, target, brewed)
	if bot._alchThrowLogWhy == why and DotaTime() < (bot._alchThrowLogAt or -999) then
		return
	end
	bot._alchThrowLogWhy = why
	bot._alchThrowLogAt = DotaTime() + 1
	pcall(function()
		print(
			string.format(
				"[OHA-ALCHEMIST] t=%.0f concoction throw why=%s target=%s dist=%.0f brewed=%.1fs illusion=%s",
				DotaTime(),
				why,
				UnitNameOrNone(target),
				GetUnitToUnitDistance(bot, target),
				brewed,
				tostring(Fu.IsSuspiciousIllusion(target))
			)
		)
	end)
end
-- While brewing and not retreating, walk back into range of a throw target (#34). Game 039, 15:09 and 39:01:
-- the brew started in attack mode, the mode changed (push after a farm withdraw, Roshan) and walked him off,
-- and at 5.0s nobody was within the throw range. Only when no real hero is within the start distance (throw
-- range - 175), so it never pulls him out of a fight he is already in, and only toward a hero he can bring
-- into range before the brew explodes. The brew target first, else the nearest hero. Runs last in
-- SkillsComplement: a move order above would cancel his own casts.
function X.ConcoctionKeepRange(brewed)
	local castRange = unstableConcoctionThrowAbility:GetCastRange()
	local nearest, nearestDist = NearestThrowTargets(1600)
	if nearest == nil or nearestDist <= castRange - 175 then
		return false
	end
	local chaseTarget, chaseDist = nearest, nearestDist
	if CanHitWithThrow(brewTarget) and not Fu.IsSuspiciousIllusion(brewTarget) then
		local brewTargetDist = GetUnitToUnitDistance(bot, brewTarget)
		if brewTargetDist <= 1600 then
			chaseTarget, chaseDist = brewTarget, brewTargetDist
		end
	end
	-- Not under an enemy tower (7.42 npc_units.txt: tower AttackRange 700; 850 leaves a margin) unless the
	-- attack mode already took him there.
	local underTower = not isEngaging and Fu.IsLocHaveTower(850, true, chaseTarget:GetLocation())
	local secondsLeft = ConcoctionExplodeAt() - brewed
	local reachable = chaseDist - castRange <= bot:GetCurrentMovementSpeed() * secondsLeft
	local move = "yes"
	if underTower then
		move = "no-tower"
	elseif not reachable then
		move = "no-reach"
	end
	if DotaTime() >= (bot._alchKeepLogAt or -999) then
		bot._alchKeepLogAt = DotaTime() + 1
		pcall(function()
			print(
				string.format(
					"[OHA-ALCHEMIST] t=%.0f concoction keep-range target=%s dist=%.0f brewed=%.1fs mode=%s move=%s",
					DotaTime(),
					UnitNameOrNone(chaseTarget),
					chaseDist,
					brewed,
					tostring(bot:GetActiveMode()),
					move
				)
			)
		end)
	end
	if move ~= "yes" then
		return false
	end
	bot:Action_MoveToLocation(chaseTarget:GetLocation())
	return true
end
function X.SkillsComplement()
	local brewing, brewed = X.TrackConcoctionBrew()
	if Fu.CanNotUseAbility(bot) then
		if brewing then
			lastGateWhy, lastGateBrewed = AbilityGateReason(), brewed
		end
		return
	end
	local context = AbilityContext.Build(bot)
	isEngaging = context.isEngaging
	isRetreating = context.isRetreating
	-- Fu.IsRetreating needs a retreat desire above 0.5; the mode alone already walks him away from his target.
	brewRetreating = isRetreating or bot:GetActiveMode() == BOT_MODE_RETREAT
	isAttacking = Fu.IsAttacking(bot)
	hpRatio = context.hp
	-- The throw comes before Chemical Rage: the Rage has a 0.35s transformation (datafeed: transformation_time)
	-- in which nothing can be thrown, and the brew blows up on him 0.5s after it is full.
	unstableConcoctionThrowDesire, unstableConcoctionThrowTarget, unstableConcoctionThrowWhy =
		X.ConsiderUnstableConcoctionThrow()
	if unstableConcoctionThrowDesire > 0 then
		X.LogConcoctionThrow(unstableConcoctionThrowWhy or "none", unstableConcoctionThrowTarget, brewed)
		lastThrowWhy, lastThrowBrewed = unstableConcoctionThrowWhy or "none", brewed
		bot:Action_UseAbilityOnEntity(unstableConcoctionThrowAbility, unstableConcoctionThrowTarget)
		return
	end
	chemicalRageDesire = X.ConsiderChemicalRage()
	if chemicalRageDesire > 0 then
		bot:Action_UseAbility(chemicalRageAbility)
		return
	end
	unstableConcoctionDesire, unstableConcoctionTarget, unstableConcoctionWhy = X.ConsiderUnstableConcoction()
	if unstableConcoctionDesire > 0 then
		brewTarget, brewWhy = unstableConcoctionTarget, unstableConcoctionWhy or "none"
		brewSeen, brewSeenAt = false, 0
		lastThrowWhy, lastThrowBrewed = "none", 0
		lastGateWhy, lastGateBrewed = "none", 0
		gapSampleUnit = nil
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
	if acidSprayDesire > 0 then
		Fu.SetQueuePtToINT(bot, false)
		bot:Action_UseAbilityOnLocation(acidSprayAbility, acidSprayLocation)
		return
	end
	berserkPotionDesire, berserkPotionTarget = X.ConsiderBerserkPotion()
	if berserkPotionDesire > 0 then
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
			then
				-- #34: the damage grows with the brew time, so the kill needs this many seconds of brewing.
				-- A target that runs off faster than he follows is out of range by then: no brew for it.
				local lethalAfter = brewTime
					* enemyHero:GetHealth()
					/ math.max(1, enemyHero:GetActualIncomingDamage(maxDamage, DAMAGE_TYPE_PHYSICAL))
				if WillStayInThrowRange(enemyHero, lethalAfter, castRange, false) then
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
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and not Fu.IsDisabled(enemyHero)
				and not enemyHero:HasModifier("modifier_enigma_black_hole_pull")
				and not enemyHero:HasModifier("modifier_faceless_void_chronosphere_freeze")
				and not enemyHero:HasModifier("modifier_legion_commander_duel")
				and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
				-- #34: only a target that is still in range at the earliest early throw (2s).
				and WillStayInThrowRange(enemyHero, retreatThrowDelay, castRange, false)
			then
				local targetAllies = Fu.GetNearbyHeroes(enemyHero, 1000, false, BOT_MODE_NONE)
				if nearbyAllies ~= nil and targetAllies ~= nil and #nearbyAllies >= #targetAllies then
					return BOT_ACTION_DESIRE_HIGH, enemyHero, "engage"
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
			if enemyHero:IsChanneling() then
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
	local nearestCastable, nearestCastableDist = NearestCastable(nearbyEnemies)
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
