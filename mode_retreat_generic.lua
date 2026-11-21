-- Retreat mode. Also pulls a bot off a wisdom-shrine walk that has become dangerous.
local Retreat = {}
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local RetreatRules = require(GetScriptDirectory() .. "/FuncLib/systems/retreat_rules")
local bot = GetBot()
local hpRatio, mpRatio, botName, botHealth, healthRegen, manaRegen, botLocation, botTarget
local botLevel, activeMode
local allyHeroes, enemyHeroes
local loneDruidAegisAt = 0
local runStartTime = 0
local runDuration = 0
local allyAncient, enemyAncient
local nearby = {
	allyHeroes = {},
	enemyHeroes = {},
	enemyNearbyExtra = 0,
	allyNearbyExtra = 0,
	allyTowers1200 = nil,
	enemyTowers1200 = nil,
	enemyLaneCreeps1200 = nil,
	aegisNearby1200 = false,
}
local function isAegisNearby(radius)
	for _, droppedItem in pairs(GetDroppedItemList()) do
		if
			droppedItem
			and droppedItem.item:GetName() == "item_aegis"
			and GetUnitToLocationDistance(bot, droppedItem.location) < radius
		then
			return true
		end
	end
	return false
end
local function RefreshNearby()
	nearby.allyHeroes, nearby.enemyHeroes = {}, {}
	nearby.enemyNearbyExtra, nearby.allyNearbyExtra = 0, 0
	nearby.allyTowers1200 = bot:GetNearbyTowers(1200, false)
	nearby.enemyTowers1200 = bot:GetNearbyTowers(1200, true)
	nearby.enemyLaneCreeps1200 = bot:GetNearbyLaneCreeps(1200, true)
	local allUnits = GetUnitList(UNIT_LIST_ALL)
	for _, unit in pairs(allUnits) do
		if
			Fu.IsValid(unit)
			-- Nothing beyond 1600 counts below (heroes within 1600, the rest within 1200), so the distance is read
			-- first: the name and five modifier reads ran for every unit on the map on every retreat desire (#52:
			-- retreat.GetDesire was the biggest cost after the item think in games 059 and 062, 38s and 37s).
			and GetUnitToUnitDistance(bot, unit) <= 1600
			and unit:GetTeam() ~= TEAM_NEUTRAL
			and unit:GetTeam() ~= TEAM_NONE
			and not string.find(unit:GetUnitName(), "lone_druid_bear")
			and not unit:HasModifier("modifier_necrolyte_reapers_scythe")
			and not unit:HasModifier("modifier_dazzle_nothl_projection_physical_body_debuff")
			and not unit:HasModifier("modifier_skeleton_king_reincarnation_scepter_active")
			and not unit:HasModifier("modifier_item_helm_of_the_undying_active")
			and not unit:HasModifier("modifier_teleporting")
		then
			if
				Fu.IsValidHero(unit)
				and GetUnitToUnitDistance(bot, unit) <= 1600
				and (Fu.IsSuspiciousIllusion(unit) and unit:HasModifier("modifier_arc_warden_tempest_double") or not Fu.IsSuspiciousIllusion(
					unit
				))
				and not Fu.IsMeepoClone(unit)
			then
				if GetTeam() == unit:GetTeam() then
					table.insert(nearby.allyHeroes, unit)
				else
					table.insert(nearby.enemyHeroes, unit)
				end
			end
			if Fu.IsInRange(bot, unit, 1200) then
				local unitName = unit:GetUnitName()
				if bot:GetTeam() ~= unit:GetTeam() then
					if
						string.find(unitName, "warlock_golem")
						or string.find(unitName, "tombstone")
						or string.find(unitName, "npc_dota_phoenix_sun")
					then
						nearby.enemyNearbyExtra = nearby.enemyNearbyExtra + 1
					end
					if string.find(unitName, "tower") then
						local towerDamage = bot:GetActualIncomingDamage(
							unit:GetAttackDamage() * unit:GetAttackSpeed() * 5.0,
							DAMAGE_TYPE_PHYSICAL
						) - healthRegen * 5.0
						if towerDamage / botHealth >= 0.5 then
							nearby.enemyNearbyExtra = nearby.enemyNearbyExtra + 1
						end
					end
				else
					if string.find(unitName, "npc_dota_phoenix_sun") then
						nearby.allyNearbyExtra = nearby.allyNearbyExtra + 1
					end
				end
			end
		end
	end
	nearby.aegisNearby1200 = isAegisNearby(1200)
	return nearby
end
-- Which return in GetDesireHelper decided the retreat desire (its line number in this file),
-- for [OHA-RETREAT] below.
local retreatLine = 0
local function RetreatTag(line, desire)
	retreatLine = line
	return desire
end
-- Our Ancient is being fought over: enemy heroes seen within 1600 of it while it is hurt
-- (under 95%) or both T4s are gone. Game 036, 55:00-55:28: Slark and Ogre left at full HP on
-- low mana (tag 350) and the Ancient went from 0.77 to 0.13 with all five Radiant alive.
local function AncientLastStand()
	local ancient = GetAncient(GetTeam())
	if ancient == nil or not ancient:IsAlive() then
		return false
	end
	if ancient:GetHealth() >= 0.95 * ancient:GetMaxHealth() then
		for _, towerId in ipairs({ TOWER_BASE_1, TOWER_BASE_2 }) do
			local tower = GetTower(GetTeam(), towerId)
			if tower ~= nil and tower:IsAlive() then
				return false
			end
		end
	end
	return #(Fu.GetEnemiesNearLoc(ancient:GetLocation(), 1600) or {}) >= 1
end
local function LastStandLog(skipped)
	if DotaTime() >= (bot._lastStandLogAt or -999) then
		bot._lastStandLogAt = DotaTime() + 5
		pcall(
			print,
			string.format(
				"[OHA-DEFEND] t=%.0f %s ancient-last-stand retreat-skip=%s hp=%.2f mp=%.2f",
				DotaTime(),
				(string.gsub(bot:GetUnitName(), "npc_dota_hero_", "")),
				skipped,
				Fu.GetHP(bot),
				Fu.GetMP(bot)
			)
		)
	end
end
-- Valve's built-in evasive mode switches this retreat logic off (tag 142). Game 036: 30 of 50
-- Radiant deaths ended in it, 0 of 47 Dire. Log what is around the bot when it starts, to find
-- the trigger. No behaviour change.
-- Is a linear projectile / avoidance zone ours? Game 037: the log listed allied Earthbind and
-- Impale. true = allied, false = enemy, nil = unknown (kept, marked "?").
local function IsAlliedSource(source)
	local caster = source.caster
	if caster ~= nil and caster.GetTeam ~= nil then
		local ok, team = pcall(caster.GetTeam, caster)
		if ok and team ~= nil then
			return team == GetTeam()
		end
	end
	local playerId = source.playerid or source.player
	if type(playerId) == "number" and playerId >= 0 then
		return GetTeamForPlayer(playerId) == GetTeam()
	end
	-- Field names above are not verified for linear projectiles. Ability names start with the
	-- hero name (meepo_earthbind, lion_impale): match them against our heroes.
	local abilityName = source.ability ~= nil and source.ability:GetName() or nil
	if abilityName ~= nil then
		for _, ally in pairs(GetUnitList(UNIT_LIST_ALLIED_HEROES) or {}) do
			if Fu.IsValid(ally) then
				local short = string.gsub(ally:GetUnitName(), "npc_dota_hero_", "")
				if string.sub(abilityName, 1, #short + 1) == short .. "_" then
					return true
				end
			end
		end
	end
	return nil
end
local function LogEvasiveEntry()
	local now = DotaTime()
	local evasiveSince = bot._evasiveSince
	bot._evasiveSince = now
	if evasiveSince ~= nil and now - evasiveSince < 1.0 then
		return
	end
	if now < (bot._evasiveLogAt or -999) then
		return
	end
	-- Game 037: 57 of 261 entries were printed at respawn (foes empty, hp=1.00): the active mode
	-- still reads evasive from before the death. Nothing within 2s of a death or a respawn.
	if now - math.max(bot._retreatDeadAt or -999, bot._retreatResumeAt or -999) < 2 then
		return
	end
	bot._evasiveLogAt = now + 3
	local enemyNames, castingNames = {}, {}
	for _, enemyHero in pairs(bot:GetNearbyHeroes(1600, true, BOT_MODE_NONE) or {}) do
		if Fu.IsValidHero(enemyHero) then
			local heroName = (string.gsub(enemyHero:GetUnitName(), "npc_dota_hero_", ""))
			enemyNames[#enemyNames + 1] = heroName
			local okAbility, activeAbility = pcall(function()
				return enemyHero:GetCurrentActiveAbility()
			end)
			if okAbility and activeAbility ~= nil then
				castingNames[#castingNames + 1] = heroName .. ":" .. tostring(activeAbility:GetName())
			end
		end
	end
	local trackingNames = {}
	local okTracking, trackingProjectiles = pcall(function()
		return bot:GetIncomingTrackingProjectiles()
	end)
	for _, projectile in pairs(okTracking and trackingProjectiles or {}) do
		if projectile ~= nil and not projectile.is_attack and IsAlliedSource(projectile) ~= true then
			local casterName = projectile.caster ~= nil
					and (string.gsub(projectile.caster:GetUnitName(), "npc_dota_hero_", ""))
				or "?"
			trackingNames[#trackingNames + 1] = casterName
				.. ":"
				.. (projectile.ability ~= nil and projectile.ability:GetName() or "?")
		end
	end
	local linearNames = {}
	local okLinear, linearProjectiles = pcall(GetLinearProjectiles)
	for _, projectile in pairs(okLinear and linearProjectiles or {}) do
		if
			projectile ~= nil
			and projectile.location ~= nil
			and GetUnitToLocationDistance(bot, projectile.location) <= 1500
		then
			local allied = IsAlliedSource(projectile)
			if allied ~= true then
				linearNames[#linearNames + 1] = (projectile.ability ~= nil and projectile.ability:GetName() or "?")
					.. (allied == nil and "?" or "")
			end
		end
	end
	local zoneNames = {}
	local okZones, avoidanceZones = pcall(GetAvoidanceZones)
	for _, zone in pairs(okZones and avoidanceZones or {}) do
		if
			zone ~= nil
			and zone.location ~= nil
			and GetUnitToLocationDistance(bot, zone.location) <= (zone.radius or 0) + 300
		then
			local allied = IsAlliedSource(zone)
			if allied ~= true then
				zoneNames[#zoneNames + 1] = (zone.ability ~= nil and zone.ability:GetName() or "?")
					.. "/"
					.. tostring(zone.radius)
					.. (allied == nil and "?" or "")
			end
		end
	end
	if #enemyNames == 0 and #trackingNames == 0 and #linearNames == 0 and #zoneNames == 0 then
		return
	end
	pcall(
		print,
		string.format(
			"[OHA-EVASIVE] t=%.0f %s enter hp=%.2f foes=%s casting=%s tracking=%s linear=%s zones=%s",
			now,
			(string.gsub(bot:GetUnitName(), "npc_dota_hero_", "")),
			Fu.GetHP(bot),
			table.concat(enemyNames, ","),
			table.concat(castingNames, ","),
			table.concat(trackingNames, ","),
			table.concat(linearNames, ","),
			table.concat(zoneNames, ",")
		)
	)
end
local function HeroName()
	return (string.gsub(bot:GetUnitName(), "npc_dota_hero_", ""))
end
local function CountRealHeroes(radius, enemy)
	local count = 0
	for _, hero in pairs(bot:GetNearbyHeroes(radius, enemy, BOT_MODE_NONE) or {}) do
		if Fu.IsValidHero(hero) and not Fu.IsSuspiciousIllusion(hero) and not Fu.IsMeepoClone(hero) then
			count = count + 1
		end
	end
	return count
end
-- Valve's evasive mode turns this file off (tag 142). Game 037: 33 of 52 Radiant deaths ended in it,
-- and those bots lost ground to the fountain in their last 3.5s (retreat deaths gained ~200). Low
-- (under 40%) with enemy heroes near and outnumbered or being hit: retreat above evasive (it reads
-- up to 1.00 as the active mode, and the active mode reads ~10% above its desire: 1.25 clears
-- even a raw 1.00 with that bonus). Held 3s once retreat is the active mode, renewed while under
-- 50% HP with an enemy hero near or a hero hit, so evasive cannot take the next think back.
local function OverEvasiveDesire()
	local now = DotaTime()
	local hp = Fu.GetHP(bot)
	local enemyN = CountRealHeroes(1200, true)
	local allyN = CountRealHeroes(1200, false)
	local hit = bot:WasRecentlyDamagedByAnyHero(1.5)
	local holding = bot._overEvasiveUntil ~= nil and now < bot._overEvasiveUntil and activeMode == BOT_MODE_RETREAT
	local start = activeMode == BOT_MODE_EVASIVE_MANEUVERS and hp < 0.4 and enemyN >= 1 and (enemyN > allyN or hit)
	if start or holding and hp < 0.5 and (enemyN >= 1 or hit) then
		bot._overEvasiveUntil = now + 3
		if now >= (bot._overEvasiveLogAt or -999) then
			bot._overEvasiveLogAt = now + 3
			pcall(
				print,
				string.format(
					"[OHA-RETREAT] t=%.0f %s over-evasive %s hp=%.2f enemies=%d allies=%d hit=%s mode=%d desire=%.2f",
					now,
					HeroName(),
					start and "start" or "hold",
					hp,
					enemyN,
					allyN,
					tostring(hit),
					activeMode or -1,
					BOT_DESIRE_OVERRIDE * 1.25
				)
			)
		end
		return BOT_DESIRE_OVERRIDE * 1.25
	end
	bot._overEvasiveUntil = nil
	return 0
end
-- Monkey King's Jingu charges heal 20-80% of each hit (game data, lifesteal): like Satanic's Unholy
-- Rage (tag 142), don't back off while they last and he is hitting a hero in an even fight. The
-- override attack mode had this as an attack bonus, but Monkey King does not load that file.
local function JinguFightOn()
	if
		bot:GetUnitName() ~= "npc_dota_hero_monkey_king"
		or not bot:HasModifier("modifier_monkey_king_quadruple_tap_bonuses")
		or Fu.GetHP(bot) <= 0.3
	then
		return false
	end
	local target = bot:GetAttackTarget()
	if
		not Fu.IsValidHero(target)
		or GetUnitToUnitDistance(bot, target) > bot:GetAttackRange() + 150
		or CountRealHeroes(1200, true) > CountRealHeroes(1200, false)
	then
		return false
	end
	if DotaTime() >= (bot._jinguFightLogAt or -999) then
		bot._jinguFightLogAt = DotaTime() + 3
		pcall(
			print,
			string.format(
				"[OHA-MONKEY_KING] t=%.0f jingu-fight retreat-skip hp=%.2f target=%s charges=%d",
				DotaTime(),
				Fu.GetHP(bot),
				(string.gsub(target:GetUnitName(), "npc_dota_hero_", "")),
				Fu.GetModifierCount(bot, "modifier_monkey_king_quadruple_tap_bonuses")
			)
		)
	end
	return true
end
-- The kill the creep-low rule and the hard retreat let a bot stay for: its own target (not any enemy near) dies to
-- the next hit (Fu.IsOneAutoAttackKill: its hit, or an ally's already in range), and the bot lives until that hit
-- lands (RetreatRules.DiesBeforeFinish). Game 064, 22:23: Alchemist at 18% HP with 5 enemy heroes on him stayed
-- (creep-low-skip why=finish) because Fu.ShouldFinishCommittedKill is true for any enemy within ~1200 one hit
-- kills, with no look at the bot's own HP, and he died the same second. src names the caller in the log.
local function FinishKillExempt(src)
	if not Fu.IsValidHero(botTarget) then
		return false
	end
	local attackRange = bot:GetAttackRange() or 150
	local dist = GetUnitToUnitDistance(bot, botTarget)
	-- The reach Fu.ShouldFinishCommittedKill uses.
	local targetKill = dist <= math.max(attackRange + 750, 1100) and Fu.IsOneAutoAttackKill(bot, botTarget)
	local now = DotaTime()
	if not targetKill then
		-- Say when the old rule (any enemy near) would have let the bot stay. At most every 5s.
		if hpRatio < 0.6 and now >= (bot._finishDenyLogAt or -999) and Fu.ShouldFinishCommittedKill(bot, botTarget) then
			bot._finishDenyLogAt = now + 5
			pcall(
				print,
				string.format(
					"[OHA-RETREAT] t=%.0f %s finish-denied why=not-target src=%s hp=%.2f target=%s",
					now,
					HeroName(),
					src,
					hpRatio,
					(string.gsub(botTarget:GetUnitName(), "npc_dota_hero_", ""))
				)
			)
		end
		return false
	end
	-- Until the hit lands: one attack interval, the projectile's flight, and the walk into range.
	local hitTime = bot:GetSecondsPerAttack() or 1.7
	local projectileSpeed = bot:GetAttackProjectileSpeed() or 0
	if attackRange > 300 and projectileSpeed > 0 then
		hitTime = hitTime + math.min(dist, attackRange) / projectileSpeed
	end
	if dist > attackRange then
		hitTime = hitTime + (dist - attackRange) / math.max(100, bot:GetCurrentMovementSpeed() or 300)
	end
	hitTime = math.min(hitTime, 3.0)
	local hitting, incoming = 0, 0
	for _, enemyHero in pairs(bot:GetNearbyHeroes(1200, true, BOT_MODE_NONE) or {}) do
		if
			Fu.IsValidHero(enemyHero)
			and not Fu.IsSuspiciousIllusion(enemyHero)
			and bot:WasRecentlyDamagedByHero(enemyHero, 1.0)
		then
			hitting = hitting + 1
			incoming = incoming + (enemyHero:GetEstimatedDamageToTarget(true, bot, hitTime, DAMAGE_TYPE_ALL) or 0)
		end
	end
	local diesFirst, why = RetreatRules.DiesBeforeFinish(hpRatio, botHealth, hitting, incoming)
	if diesFirst then
		if now >= (bot._finishDenyLogAt or -999) then
			bot._finishDenyLogAt = now + 5
			pcall(
				print,
				string.format(
					"[OHA-RETREAT] t=%.0f %s finish-denied why=%s src=%s hp=%.2f health=%d hitting=%d incoming=%d hitTime=%.1f target=%s",
					now,
					HeroName(),
					why,
					src,
					hpRatio,
					math.floor(botHealth or 0),
					hitting,
					math.floor(incoming),
					hitTime,
					(string.gsub(botTarget:GetUnitName(), "npc_dota_hero_", ""))
				)
			)
		end
		return false
	end
	return true
end
-- Alone / outnumbered after enemy backup: hard retreat so sticky engage cannot win.
-- It returned 0.7 (BOT_MODE_DESIRE_ABSOLUTE) while attack sits at 0.95, so it never won a
-- fight (game 036: 28 deaths straight out of attack mode). Below 60% HP it returns 0.98,
-- like the disarmed rule; above that it stays 0.7. Not while defending our Ancient.
-- It applied only while attack/roam was the active mode, so once it won, retreat dropped and
-- attack won back (game 037, Kez t=2319-2332: attack 0.65 / retreat 0.98, 29 changes in 13s).
-- Now held for 3s while retreat is active, renewed while still outnumbered under 70% HP.
-- Returns desire, tag (201 start, 202 held).
local function HardRetreatDesire(lastStand)
	if lastStand then
		bot._hardRetreatUntil = nil
		return 0, 201
	end
	local now = DotaTime()
	-- Allies: every allied hero near us except illusions, Meepo clones included (Fu.GetAllyCount drops the
	-- clones, so a Meepo with 3 bodies counted as alone).
	local alliesNearby = 0
	for _, ally in pairs(bot:GetNearbyHeroes(1400, false, BOT_MODE_NONE) or {}) do
		if Fu.IsValidHero(ally) and not ally:IsIllusion() then
			alliesNearby = alliesNearby + 1
		end
	end
	alliesNearby = math.max(1, alliesNearby)
	local enemiesNearby = Fu.GetEnemyCount(bot, 1400)
	local lastSeen = Fu.GetLastSeenEnemiesNearLoc and Fu.GetLastSeenEnemiesNearLoc(bot:GetLocation(), 2000) or {}
	local pressure = math.max(enemiesNearby, #lastSeen)
	local freeKill = FinishKillExempt("hard-retreat")
	local stronger = Fu.WeAreStronger(bot, 1400)
	local hit = bot:WasRecentlyDamagedByAnyHero(2.0)
	local outnumbered =
		RetreatRules.HardRetreatOutnumbered(alliesNearby, enemiesNearby, #lastSeen, hpRatio, hit, stronger)
	local attacking = activeMode == BOT_MODE_ATTACK
		or activeMode == BOT_MODE_TEAM_ROAM
		or activeMode == BOT_MODE_ROAM
		or Fu.IsGoingOnSomeone(bot)
	local holding = bot._hardRetreatUntil ~= nil and now < bot._hardRetreatUntil and activeMode == BOT_MODE_RETREAT
	if freeKill or not outnumbered or not attacking and not holding then
		-- Game 038: the old rule (Meepo clones not counted, stale sightings at any HP) fired 156 times on healthy
		-- bots. Say when it would have, to show the new rule holding the fight. At most every 5s.
		local oldAllies = Fu.GetAllyCount(bot, 1400)
		local oldOutnumbered = oldAllies <= 1 and pressure >= 2 or pressure >= oldAllies + 1 and not stronger
		if
			not outnumbered
			and oldOutnumbered
			and attacking
			and not freeKill
			and hpRatio >= 0.6
			and now >= (bot._hardRetreatSkipLogAt or -999)
		then
			bot._hardRetreatSkipLogAt = now + 5
			pcall(
				print,
				string.format(
					"[OHA-RETREAT] t=%.0f %s healthy-fight-kept hp=%.2f allies=%d visible=%d recent=%d hit=%s",
					now,
					HeroName(),
					hpRatio,
					alliesNearby,
					enemiesNearby,
					#lastSeen,
					tostring(hit)
				)
			)
		end
		bot._hardRetreatUntil = nil
		return 0, 201
	end
	if hpRatio < 0.6 or holding and hpRatio < 0.7 then
		bot._hardRetreatUntil = now + 3
		if now >= (bot._hardRetreatLogAt or -999) then
			bot._hardRetreatLogAt = now + 3
			pcall(
				print,
				string.format(
					"[OHA-RETREAT] t=%.0f %s hard-retreat %s hp=%.2f allies=%d pressure=%d mode=%d",
					now,
					HeroName(),
					holding and "hold" or "over-attack",
					hpRatio,
					alliesNearby,
					pressure,
					activeMode or -1
				)
			)
		end
		return 0.98, holding and 202 or 201
	end
	-- Healthy but clearly outnumbered (seen, two more than us, being hit): back off at 0.7. Held for 2s like the
	-- hurt case; without the hold it returned 0 on the next think (retreat active, no longer attacking) and
	-- attack won back, a one-think pulse every time.
	bot._hardRetreatUntil = now + 2
	if now >= (bot._hardRetreatLogAt or -999) then
		bot._hardRetreatLogAt = now + 3
		pcall(
			print,
			string.format(
				"[OHA-RETREAT] t=%.0f %s hard-retreat healthy-outnumbered hp=%.2f allies=%d visible=%d hit=%s",
				now,
				HeroName(),
				hpRatio,
				alliesNearby,
				enemiesNearby,
				tostring(hit)
			)
		)
	end
	return BOT_MODE_DESIRE_ABSOLUTE, 201
end
-- Low HP in a creep wave or under a tower, at any game time (RetreatRules.CreepLowRetreat). Game 062, 17:34: Weaver
-- died to creeps in attack mode (0.71-0.74), 13% -> 3% in 3.5s, no enemy hero near. 0.98 like the hard retreat:
-- attack reads up to 0.95, and BOT_MODE_DESIRE_VERYHIGH is only 0.6. Held 3s whichever mode is active (mode_hold does
-- not hold desires above 0.9), renewed while creeps or a tower are in reach and through a TP home (game 064, 42:04:
-- Death Prophet's TP was lost to push mode, see RetreatRules.CreepLowRetreat).
-- byRoshan: called from the Roshan / Tormentor exemption below, where Roshan's hits count as creep hits. Game 063,
-- 21:15 Earth Spirit and 46:03 Alchemist died to Roshan in Roshan mode: the exemption returned NONE above 20% HP, so
-- this rule fired only at 15% / 11%, and Roshan mode called Alchemist back in between (t=2755 out at 18%, t=2758
-- called, died t=2764). A Roshan exit holds while HP is under 35% and the bot is within 2500 of the pit (the radius
-- of the pit-leave rule, tag 217), not only while a creep is within 700.
local CREEP_LOW_PIT_HOLD = 2500
local function CreepLowDesire(byRoshan)
	local now = DotaTime()
	if
		bot:HasModifier("modifier_fountain_aura_buff")
		-- Medusa's Mana Shield takes the hits while she has mana (the generic formula below reads her by mana too).
		or botName == "npc_dota_hero_medusa" and mpRatio >= 0.3
	then
		bot._creepLowUntil = nil
		bot._creepLowByRoshan = nil
		return 0
	end
	local creepHit = bot:WasRecentlyDamagedByCreep(2.0)
	local towerHit = bot:WasRecentlyDamagedByTower(2.0)
	local holding = bot._creepLowUntil ~= nil and now < bot._creepLowUntil
	if not creepHit and not towerHit and not holding then
		bot._creepLowUntil = nil
		bot._creepLowByRoshan = nil
		return 0
	end
	local channeling = bot:IsChanneling()
	local teleporting = channeling and bot:HasModifier("modifier_teleporting")
	local creepCount = #(bot:GetNearbyCreeps(700, true) or {})
	local towerNear = #(bot:GetNearbyTowers(900, true) or {}) > 0
	local roshanPit = (byRoshan or bot._creepLowByRoshan) and Fu.GetCurrentRoshanLocation() or nil
	local nearPit = roshanPit ~= nil and GetUnitToLocationDistance(bot, roshanPit) < CREEP_LOW_PIT_HOLD
	local canFinish = not channeling and FinishKillExempt("creep-low")
	local fire, renew = RetreatRules.CreepLowRetreat(
		hpRatio,
		creepHit,
		towerHit,
		canFinish,
		channeling,
		holding,
		creepCount > 0 or towerNear or nearPit,
		teleporting
	)
	if not fire then
		if canFinish and hpRatio < RetreatRules.CREEP_LOW_HP and now >= (bot._creepLowSkipLogAt or -999) then
			bot._creepLowSkipLogAt = now + 5
			pcall(
				print,
				string.format(
					"[OHA-RETREAT] t=%.0f %s creep-low-skip why=finish hp=%.2f creeps=%d mode=%d",
					now,
					HeroName(),
					hpRatio,
					creepCount,
					activeMode or -1
				)
			)
		end
		-- A channel that is not a TP (or a TP that modifier_teleporting did not show) ended a live hold: say so,
		-- so a game without tp-keep lines tells "no TP" from "TP not detected".
		if channeling and holding then
			pcall(
				print,
				string.format(
					"[OHA-RETREAT] t=%.0f %s creep-low drop why=channel tp=%s hp=%.2f mode=%d",
					now,
					HeroName(),
					tostring(teleporting),
					hpRatio,
					activeMode or -1
				)
			)
		end
		bot._creepLowUntil = nil
		bot._creepLowByRoshan = nil
		bot._creepLowTpLogged = nil
		return 0
	end
	if renew then
		bot._creepLowUntil = now + 3
	end
	if byRoshan then
		bot._creepLowByRoshan = true
	end
	-- Once per TP channel: the line that shows retreat kept the TP (did the bot arrive? the next creep-low line, or
	-- none because the fountain ended the rule).
	if teleporting then
		if not bot._creepLowTpLogged then
			bot._creepLowTpLogged = true
			pcall(
				print,
				string.format(
					"[OHA-RETREAT] t=%.0f %s creep-low tp-keep hp=%.2f creeps=%d tower=%s mode=%d",
					now,
					HeroName(),
					hpRatio,
					creepCount,
					tostring(towerHit or towerNear),
					activeMode or -1
				)
			)
		end
		return 0.98
	end
	bot._creepLowTpLogged = nil
	if now >= (bot._creepLowLogAt or -999) then
		bot._creepLowLogAt = now + 3
		pcall(
			print,
			string.format(
				"[OHA-RETREAT] t=%.0f %s creep-low %s hp=%.2f creeps=%d tower=%s mode=%d src=%s renew=%s",
				now,
				HeroName(),
				holding and "hold" or "start",
				hpRatio,
				creepCount,
				tostring(towerHit or towerNear),
				activeMode or -1,
				bot._creepLowByRoshan and "roshan" or "wave",
				tostring(renew)
			)
		)
	end
	return 0.98
end
function GetDesire()
	-- Death and respawn times, for the evasive logger; the retreat holds end with the death.
	local now = DotaTime()
	if not bot:IsAlive() then
		bot._retreatDeadAt = now
		bot._hardRetreatUntil = nil
		bot._overEvasiveUntil = nil
		bot._creepLowUntil = nil
	end
	if now - (bot._retreatDesireAt or -999) > 1.5 then
		bot._retreatResumeAt = now
	end
	if ShouldSkipBotThink(GetBot()) then
		return 0
	end
	bot._retreatDesireAt = now
	retreatLine = 0
	local desire = GetDesireHelper()
	-- Rooted: retreat can only order a move, and a rooted hero can't move. Game 040, 5:40: Outworld Destroyer,
	-- rooted by Earthbind at 26% HP, stood still in retreat mode while Meepo hit him. With an enemy hero in reach,
	-- step aside (low desire) so attack mode fights back; spells and items run in their own think anyway. Retreat
	-- comes back as soon as the root ends.
	if
		type(desire) == "number"
		and desire > BOT_MODE_DESIRE_LOW
		and bot:IsAlive()
		and bot:IsRooted()
		and not bot:IsStunned()
		and not bot:IsHexed()
		and not bot:IsDisarmed()
	then
		local reach = bot:GetAttackRange() + 200
		local fightBackTarget = nil
		for _, enemyHero in pairs(bot:GetNearbyHeroes(math.min(1600, reach), true, BOT_MODE_NONE) or {}) do
			if Fu.IsValidHero(enemyHero) and Fu.CanBeAttacked(enemyHero) then
				if fightBackTarget == nil or enemyHero:GetHealth() < fightBackTarget:GetHealth() then
					fightBackTarget = enemyHero
				end
			end
		end
		if fightBackTarget ~= nil then
			if now >= (bot._rootedLogAt or -999) then
				bot._rootedLogAt = now + 3
				pcall(
					print,
					string.format(
						"[OHA-RETREAT] t=%.0f %s rooted act=fight-back target=%s hp=%.2f desire=%.2f",
						now,
						(string.gsub(bot:GetUnitName(), "npc_dota_hero_", "")),
						(string.gsub(fightBackTarget:GetUnitName(), "npc_dota_hero_", "")),
						bot:GetHealth() / bot:GetMaxHealth(),
						desire
					)
				)
			end
			return BOT_MODE_DESIRE_LOW
		end
	end
	-- A healthy bot wanting to retreat: say which rule (game 014, 35:30: Medusa at full HP and
	-- mana backed off from a 1v1 with OD, and nothing in the log said why). At most every 5s.
	if type(desire) == "number" and desire >= 0.5 and bot:IsAlive() and bot:GetHealth() >= 0.8 * bot:GetMaxHealth() then
		if DotaTime() >= (bot._retreatLogAt or -999) then
			bot._retreatLogAt = DotaTime() + 5
			pcall(
				print,
				string.format(
					"[OHA-RETREAT] t=%.0f %s desire=%.2f line=%d hp=%.2f mp=%.2f enemies1200=%d allies1200=%d",
					DotaTime(),
					(string.gsub(bot:GetUnitName(), "npc_dota_hero_", "")),
					desire,
					retreatLine,
					bot:GetHealth() / bot:GetMaxHealth(),
					bot:GetMana() / math.max(1, bot:GetMaxMana()),
					#(bot:GetNearbyHeroes(1200, true, BOT_MODE_NONE) or {}),
					#(bot:GetNearbyHeroes(1200, false, BOT_MODE_NONE) or {})
				)
			)
		end
	end
	-- The creep-low window is live but another rule returned first with less than its 0.98 (game 064, 42:08: push
	-- 0.90 won right after a creep-low hold line and the log could not say which rule let it). At most every 3s.
	if
		type(desire) == "number"
		and desire < 0.98
		and bot._creepLowUntil ~= nil
		and now < bot._creepLowUntil
		and now >= (bot._creepLowUnderLogAt or -999)
	then
		bot._creepLowUnderLogAt = now + 3
		pcall(
			print,
			string.format(
				"[OHA-RETREAT] t=%.0f %s creep-low-undercut desire=%.2f line=%d hp=%.2f mode=%d channel=%s",
				now,
				HeroName(),
				desire,
				retreatLine,
				hpRatio or -1,
				activeMode or -1,
				tostring(bot:IsChanneling())
			)
		)
	end
	return desire
end
function GetDesireHelper()
	activeMode = bot:GetActiveMode()
	if activeMode == BOT_MODE_EVASIVE_MANEUVERS and bot:IsAlive() then
		pcall(LogEvasiveEntry)
	end
	if
		not bot:IsAlive()
		or bot:HasModifier("modifier_dazzle_nothl_projection_soul_clone")
		or bot:HasModifier("modifier_skeleton_king_reincarnation_scepter_active")
		or bot:HasModifier("modifier_item_helm_of_the_undying_active")
		or bot:GetUnitName() == "npc_dota_hero_lone_druid" and bot:HasModifier("modifier_fountain_aura_buff") and DotaTime() < 0
		or bot:HasModifier("modifier_item_satanic_unholy")
		or Fu.GetModifierTime(bot, "modifier_abaddon_borrowed_time") > 2
		or Fu.GetModifierTime(bot, "modifier_muerta_pierce_the_veil_buff") > 2
		or Fu.GetModifierTime(bot, "modifier_dazzle_shallow_grave") > 3
		or Fu.GetModifierTime(bot, "modifier_oracle_false_promise_timer") > 3
		or JinguFightOn()
	then
		bot._hardRetreatUntil = nil
		bot._overEvasiveUntil = nil
		bot._creepLowUntil = nil
		return RetreatTag(142, BOT_MODE_DESIRE_NONE)
	end
	if activeMode == BOT_MODE_EVASIVE_MANEUVERS or bot._overEvasiveUntil ~= nil then
		local overEvasive = OverEvasiveDesire()
		if overEvasive > 0 then
			return RetreatTag(144, overEvasive)
		end
		if activeMode == BOT_MODE_EVASIVE_MANEUVERS then
			return RetreatTag(142, BOT_MODE_DESIRE_NONE)
		end
	end
	-- Disarmed in a fight: game 029, 29:25, Mirana, disarmed by Techies' Reactive Tazer, 46% HP,
	-- 4 enemies near, stood idle in attack mode (0.95). 2+ enemy heroes within 1200 under 60% HP,
	-- or 1 under 35%: retreat, above the attack mode.
	if bot:IsDisarmed() then
		local enemyCount = #(bot:GetNearbyHeroes(1200, true, BOT_MODE_NONE) or {})
		local hpNow = Fu.GetHP(bot)
		if enemyCount >= 2 and hpNow < 0.6 or enemyCount >= 1 and hpNow < 0.35 then
			return RetreatTag(143, 0.98)
		end
	end
	hpRatio = Fu.GetHP(bot)
	mpRatio = Fu.GetMP(bot)
	botName = bot:GetUnitName()
	botHealth = bot:GetHealth()
	healthRegen = bot:GetHealthRegen()
	manaRegen = bot:GetManaRegen()
	botLocation = bot:GetLocation()
	botTarget = Fu.GetProperTarget(bot)
	botLevel = bot:GetLevel()
	allyAncient = GetAncient(GetTeam())
	enemyAncient = GetAncient(GetOpposingTeam())
	RefreshNearby()
	allyHeroes = nearby.allyHeroes
	enemyHeroes = nearby.enemyHeroes
	local allyTowers = nearby.allyTowers1200
	local enemyTowers = nearby.enemyTowers1200
	local enemyLaneCreeps = nearby.enemyLaneCreeps1200
	local weAreStronger = Fu.WeAreStronger(bot, 1600)
	local isInTeamFight = Fu.IsInTeamFight(bot, 1200)
	-- A hard retreat in progress (below) keeps priority over the rules in between.
	if bot._hardRetreatUntil ~= nil then
		local held, heldTag = HardRetreatDesire(hpRatio >= 0.4 and AncientLastStand())
		if held > 0.9 then
			return RetreatTag(heldTag, held)
		end
	end
	-- Abort early tower-dive chase (e.g. gold-rune bait under T1).
	local towerDiveRetreat = Retreat.RetreatWhenTowerTargetedDesire()
	if towerDiveRetreat > 0 then
		return RetreatTag(166, towerDiveRetreat)
	end
	-- Summons and illusions chewing on us: spiderlings, golems, eidolons, illusions whose next
	-- 5s of damage is a big share of our HP. This check existed but nothing called it, so a
	-- hero stood in a spiderling swarm until its HP alone was low enough to retreat.
	local unitRun = Retreat.GetUnitDesire(1000)
	if unitRun > 0 then
		if DotaTime() >= (bot._unitRunLogAt or -999) then
			bot._unitRunLogAt = DotaTime() + 5
			pcall(
				print,
				string.format(
					"[OHA-RETREAT] t=%.0f %s summons desire=%.2f by=%s hp=%.2f",
					DotaTime(),
					(string.gsub(bot:GetUnitName(), "npc_dota_hero_", "")),
					unitRun,
					tostring(bot._unitRunBy),
					hpRatio
				)
			)
		end
		return RetreatTag(184, unitRun)
	end
	local lastStand = hpRatio >= 0.4 and AncientLastStand()
	local hardRetreat, hardRetreatTag = HardRetreatDesire(lastStand)
	if hardRetreat > 0 then
		return RetreatTag(hardRetreatTag, hardRetreat)
	end
	if
		activeMode == BOT_MODE_ROSHAN
		and not Fu.IsRoshanAlive()
		-- Was a bare distance (always true): any bot in Roshan mode anywhere retreated once Roshan was dead.
		and GetUnitToLocationDistance(bot, Fu.GetCurrentRoshanLocation()) < 1600
		and IsLocationVisible(Fu.GetCurrentRoshanLocation())
	then
		if not nearby.aegisNearby1200 then
			return RetreatTag(211, BOT_MODE_DESIRE_MODERATE)
		end
	end
	-- Pit leave (tag 217) only for a bot in a Roshan fight: in Roshan mode, hitting Roshan or hit by him in the last
	-- 5s, or already sent out of this fight (RetreatRules.RoshanLeaveApplies; game 065: it fired for lane bots near
	-- the pit and for Primal Beast after Roshan died, cutting their creep-low holds). In the fight the creep-low rule
	-- runs first, so its 0.98 (and the src=roshan hold near the pit) is not cut to 0.70.
	local roshanPit = Fu.GetCurrentRoshanLocation()
	local nearPit = roshanPit ~= nil and GetUnitToLocationDistance(bot, roshanPit) < 2500
	local roshanHandle = Fu.Utils.GameStates and Fu.Utils.GameStates.roshHandle
	local roshanSeenAlive = Fu.IsUnitValid(roshanHandle) and roshanHandle:IsAlive()
	if nearPit then
		local attackTarget = bot:GetAttackTarget()
		if
			activeMode == BOT_MODE_ROSHAN
			or attackTarget ~= nil and Fu.IsRoshan(attackTarget)
			or roshanSeenAlive and roshanHandle:GetAttackTarget() == bot
		then
			bot._roshanFightAt = DotaTime()
		end
	end
	if Fu.ShouldLeaveRoshanFight(bot) then
		-- Fu.IsRoshanAlive goes by the kill time and a fixed respawn time; a Roshan seen alive counts too (he can be
		-- back before that time runs out).
		local roshanAlive = roshanSeenAlive or Fu.IsRoshanAlive()
		local applies, leaveWhy = RetreatRules.RoshanLeaveApplies(
			nearPit,
			roshanAlive,
			DotaTime() - (bot._roshanFightAt or -999),
			bot._roshLeaveLatched == true
		)
		if not roshanAlive then
			bot._roshLeaveLatched = nil
		end
		if applies then
			local roshanLow = CreepLowDesire(true)
			local leaveDesire = math.max(BOT_MODE_DESIRE_ABSOLUTE, roshanLow)
			if not bot._roshLeaveLatched or DotaTime() >= (bot._roshLeaveLogAt or -999) then
				bot._roshLeaveLogAt = DotaTime() + 5
				pcall(
					print,
					string.format(
						"[OHA-RETREAT] t=%.0f %s rosh-leave why=%s hp=%.2f desire=%.2f creepLow=%.2f mode=%d",
						DotaTime(),
						HeroName(),
						leaveWhy,
						hpRatio,
						leaveDesire,
						roshanLow,
						activeMode or -1
					)
				)
			end
			bot._roshLeaveLatched = true
			return RetreatTag(217, leaveDesire)
		end
		-- On a change of reason, else every 15s (a hurt laner near the pit would repeat it).
		if
			leaveWhy ~= "far"
			and (leaveWhy ~= bot._roshLeaveSkipWhy or DotaTime() >= (bot._roshLeaveSkipLogAt or -999))
		then
			bot._roshLeaveSkipWhy = leaveWhy
			bot._roshLeaveSkipLogAt = DotaTime() + 15
			pcall(
				print,
				string.format(
					"[OHA-RETREAT] t=%.0f %s rosh-leave-skip why=%s hp=%.2f dist=%d mode=%d",
					DotaTime(),
					HeroName(),
					leaveWhy,
					hpRatio,
					math.floor(GetUnitToLocationDistance(bot, roshanPit)),
					activeMode or -1
				)
			)
		end
	else
		bot._roshLeaveLatched = nil
	end
	if
		Fu.IsDoingRoshan(bot)
		and bot:WasRecentlyDamagedByAnyHero(2.0)
		and not Fu.WeAreStronger(bot, 1200)
		and (Fu.GetEnemyCount(bot, 1400) >= 1 or #(Fu.GetLastSeenEnemiesNearLoc(bot:GetLocation(), 1400) or {}) >= 1)
	then
		return RetreatTag(229, BOT_MODE_DESIRE_ABSOLUTE)
	end
	if Fu.IsDoingRoshan(bot) or Fu.IsDoingTormentor(bot) then
		-- Roshan's hits count as creep hits: the low-HP creep rule runs before the exemption (game 063, #145). Not for
		-- Huskar (he wants to be low; the HP rewrite for him comes later, and Fu.ShouldLeaveRoshanFight skips him too).
		if botName ~= "npc_dota_hero_huskar" then
			local roshanLow = CreepLowDesire(true)
			if roshanLow > 0 then
				return RetreatTag(231, roshanLow)
			end
		end
		if hpRatio > 0.2 then
			return RetreatTag(232, BOT_MODE_DESIRE_NONE)
		end
	end
	local enemiesAroundAncient = Fu.GetEnemiesAroundAncient(bot, 3200)
	if enemiesAroundAncient > 0 then
		local ancientLocation = GetAncient(bot:GetTeam()):GetLocation()
		local ancientDistance = GetUnitToLocationDistance(bot, ancientLocation)
		if ancientDistance < 4000 then
			local aliveAllies = Fu.GetNumOfAliveHeroes(false)
			local aliveEnemies = Fu.GetNumOfAliveHeroes(true)
			if aliveEnemies <= aliveAllies + 1 then
				if aliveAllies >= 2 and hpRatio > 0.15 then
					return RetreatTag(243, BOT_MODE_DESIRE_NONE)
				end
				if aliveAllies >= 1 and hpRatio > 0.25 then
					return RetreatTag(246, BOT_MODE_DESIRE_LOW)
				end
			end
		end
	end
	if Fu.Utils.IsTeamPushingSecondTierOrHighGround(bot) and hpRatio > 0.5 then
		local nearbyAllies = bot:GetNearbyHeroes(1600, false, BOT_MODE_NONE) or {}
		if #nearbyAllies >= 2 then
			return RetreatTag(254, BOT_MODE_DESIRE_NONE)
		end
	end
	if (bot.isBear or botName == "npc_dota_hero_lone_druid_bear") and not Fu.IsEarlyGame() then
		if hpRatio >= 0.3 then
			local nearbyAllies = bot:GetNearbyHeroes(1200, false, BOT_MODE_NONE) or {}
			if #nearbyAllies >= 2 then
				return RetreatTag(261, BOT_MODE_DESIRE_NONE)
			end
		end
	end
	if
		hpRatio > 0.3
		and #allyHeroes >= 3
		and #enemyHeroes == 0
		and not bot:WasRecentlyDamagedByAnyHero(1.0)
		and not bot:WasRecentlyDamagedByTower(1.0)
	then
		return RetreatTag(272, BOT_MODE_DESIRE_NONE)
	end
	if isInTeamFight and botName == "npc_dota_hero_skeleton_king" and botLevel >= 6 then
		local reincarnationAbility = bot:GetAbilityByName("skeleton_king_reincarnation")
		if reincarnationAbility:GetCooldownTimeRemaining() <= 1.0 and bot:GetMana() >= 160 then
			return RetreatTag(277, BOT_MODE_DESIRE_NONE)
		end
	end
	if DotaTime() < 0 and hpRatio < 1 then
		for _, enemyHero in pairs(enemyHeroes) do
			if Fu.IsValidHero(enemyHero) and not enemyHero:IsBot() then
				return RetreatTag(283, RemapValClamped(hpRatio, 1, 0.1, BOT_MODE_DESIRE_HIGH, BOT_MODE_DESIRE_ABSOLUTE))
			end
		end
	end
	if botName == "npc_dota_hero_lone_druid" and DotaTime() > 25 and DotaTime() < loneDruidAegisAt + 6.5 then
		return RetreatTag(288, 3.33)
	end
	local roshanLocation = Fu.GetCurrentRoshanLocation()
	if
		botName == "npc_dota_hero_lone_druid"
		and activeMode == BOT_MODE_ITEM
		-- Was a bare distance (always true); the Aegis check below looks within 1200 of the bot.
		and GetUnitToLocationDistance(bot, roshanLocation) < 1200
		and IsLocationVisible(roshanLocation)
	then
		if nearby.aegisNearby1200 then
			loneDruidAegisAt = DotaTime()
			return RetreatTag(299, 3.33)
		end
	end
	if
		bot:HasModifier("modifier_fountain_fury_swipes_damage_increase")
		or not isInTeamFight and Fu.IsTargetedByEnemyWithModifier(
			enemyHeroes,
			"modifier_skeleton_king_reincarnation_scepter_active"
		)
		or not isInTeamFight
			and Fu.IsTargetedByEnemyWithModifier(enemyHeroes, "modifier_item_helm_of_the_undying_active")
	then
		return RetreatTag(307, BOT_MODE_DESIRE_ABSOLUTE)
	end
	-- A trancing Troll cannot die to damage. Trading hits only feeds his lifesteal.
	for _, enemyHero in pairs(enemyHeroes) do
		if
			Fu.IsValidHero(enemyHero)
			and enemyHero:HasModifier("modifier_troll_warlord_battle_trance")
			and enemyHero:GetAttackTarget() == bot
			and not Fu.IsDisabled(enemyHero)
			and not enemyHero:IsDisarmed()
			and not bot:HasModifier("modifier_ghost_state")
			and hpRatio < 0.85
		then
			return RetreatTag(320, RemapValClamped(hpRatio, 0.85, 0.3, BOT_MODE_DESIRE_HIGH, BOT_MODE_DESIRE_ABSOLUTE))
		end
	end
	if
		bot:HasModifier("modifier_doom_bringer_doom_aura_enemy")
			and (#enemyHeroes > 0 or #enemyHeroes > #allyHeroes + 1)
		or bot:HasModifier("modifier_razor_static_link_debuff") and Fu.IsUnitNearby(
			bot,
			enemyHeroes,
			700,
			"npc_dota_hero_razor",
			true
		) and #enemyHeroes >= #allyHeroes
		or bot:HasModifier("modifier_ursa_fury_swipes_damage_increase") and not isInTeamFight and Fu.IsUnitNearby(
			bot,
			enemyHeroes,
			700,
			"npc_dota_hero_ursa",
			true
		)
		or bot:HasModifier("modifier_ice_blast") and not isInTeamFight and #enemyHeroes > #allyHeroes
	then
		return RetreatTag(335, BOT_MODE_DESIRE_ABSOLUTE)
	end
	if botName == "npc_dota_hero_huskar" and not bot:HasModifier("modifier_item_spirit_vessel_damage") then
		local berserkersBloodAbility = bot:GetAbilityByName("huskar_berserkers_blood")
		if berserkersBloodAbility and berserkersBloodAbility:IsTrained() and berserkersBloodAbility:GetLevel() >= 3 then
			if hpRatio > 0.2 and healthRegen > 30 then
				hpRatio = 1
			end
			if hpRatio < 0.3 and (#enemyHeroes == 0 and Fu.HasItem(bot, "item_armlet")) then
				hpRatio = 1
			end
		end
	end
	-- Before tag 350 (0.6 within 4000 of the fountain, below attack), after the Huskar HP rewrite above.
	local creepLow = CreepLowDesire()
	if creepLow > 0 then
		return RetreatTag(340, creepLow)
	end
	if bot:DistanceFromFountain() <= 4000 and not isInTeamFight then
		if hpRatio <= 0.6 or mpRatio < 0.4 then
			if lastStand then
				LastStandLog("350")
			else
				return RetreatTag(350, BOT_MODE_DESIRE_VERYHIGH)
			end
		end
	end
	if bot:HasModifier("modifier_fountain_aura_buff") then
		local isAncientUnderAttack = enemiesAroundAncient and enemiesAroundAncient > 0
		if isAncientUnderAttack then
			if hpRatio <= 0.5 then
				return RetreatTag(357, BOT_MODE_DESIRE_ABSOLUTE)
			end
		elseif hpRatio <= 0.9 or mpRatio <= 0.8 and botName ~= "npc_dota_hero_huskar" then
			-- Topping up in the fountain while the Ancient is being killed: leave above 60% HP.
			if lastStand and hpRatio > 0.6 then
				LastStandLog("360")
			else
				return RetreatTag(360, BOT_MODE_DESIRE_ABSOLUTE)
			end
		end
		if #enemyHeroes > #allyHeroes and not weAreStronger and not Fu.CanBeAttacked(allyAncient) then
			return RetreatTag(363, BOT_MODE_DESIRE_HIGH)
		end
	end
	if Fu.IsInLaningPhase() or Fu.IsEarlyGame() and hpRatio < 0.35 then
		local nearbyCreeps = bot:GetNearbyCreeps(600, true)
		if Fu.IsGoingOnSomeone(bot) and #nearbyCreeps >= 4 and bot:WasRecentlyDamagedByCreep(3.0) then
			return RetreatTag(369, BOT_MODE_DESIRE_VERYHIGH)
		end
	end
	if bot:IsAlive() and not bot:HasModifier("modifier_fountain_aura_buff") then
		if runStartTime ~= 0 and DotaTime() < runStartTime + runDuration then
			return RetreatTag(374, BOT_DESIRE_OVERRIDE * 1.1)
		else
			runStartTime = 0
		end
		runDuration = Retreat.ShouldRun()
		if runDuration ~= 0 then
			if runStartTime == 0 then
				runStartTime = DotaTime()
			end
			return RetreatTag(383, BOT_DESIRE_OVERRIDE * 1.1)
		end
	end
	local completeItemDesire = Retreat.ConsiderCompleteItem()
	if completeItemDesire > 0 then
		return RetreatTag(388, completeItemDesire)
	end
	local enemyCount = #enemyHeroes
	local allyCount = #allyHeroes
	local recentlySeenEnemies = 0
	for _, playerId in pairs(GetTeamPlayers(GetOpposingTeam())) do
		if IsHeroAlive(playerId) then
			local lastSeenInfo = GetHeroLastSeenInfo(playerId)
			if lastSeenInfo ~= nil then
				local lastSeen = lastSeenInfo[1]
				if
					lastSeen ~= nil
					and GetUnitToLocationDistance(bot, lastSeen.location) <= 3200
					and lastSeen.time_since_seen <= 5.0
				then
					recentlySeenEnemies = recentlySeenEnemies + 1
				end
			end
		end
	end
	enemyCount = Max(enemyCount, recentlySeenEnemies)
	enemyCount = enemyCount + nearby.enemyNearbyExtra
	allyCount = allyCount + nearby.allyNearbyExtra
	if
		Fu.IsInLaningPhase()
		and Fu.IsValidBuilding(allyTowers[1])
		and bot:HasModifier("modifier_tower_aura_bonus")
		and #enemyLaneCreeps <= 1
	then
		allyCount = allyCount + 1
	end
	for _, allyHero in pairs(allyHeroes) do
		if
			Fu.IsValidHero(allyHero)
			and not allyHero:IsIllusion()
			and GetUnitToUnitDistance(bot, allyHero) / allyHero:GetCurrentMovementSpeed() <= 6.0
		then
			if Fu.IsHaveAegis(allyHero) then
				allyCount = allyCount + 1
			end
			if allyHero:GetUnitName() == "npc_dota_hero_skeleton_king" then
				local reincarnationAbility = allyHero:GetAbilityByName("skeleton_king_reincarnation")
				if
					reincarnationAbility
					and reincarnationAbility:IsTrained()
					and reincarnationAbility:GetCooldownTimeRemaining() == 0
					and allyHero:GetMana() > reincarnationAbility:GetManaCost() * 1.5
				then
					allyCount = allyCount + 1
				end
			end
		end
	end
	hpRatio = Clamp(hpRatio + healthRegen * 5.0 / bot:GetMaxHealth(), 0, 1)
	mpRatio = Clamp(mpRatio + manaRegen * 5.0 / bot:GetMaxMana(), 0, 1)
	local healthScore = 0
	if botName == "npc_dota_hero_medusa" then
		local effectiveHealth = botHealth - bot:GetMana() * 0.98 * (2 + 0.1 * botLevel)
		local maxEffectiveHealth = bot:GetMaxHealth() - bot:GetMaxMana() * 0.98 * (2 + 0.1 * botLevel)
		healthScore = effectiveHealth / maxEffectiveHealth * 0.2 + mpRatio * 0.8
	elseif botName == "npc_dota_hero_huskar" then
		healthScore = hpRatio
	else
		healthScore = hpRatio * 0.8 + mpRatio * 0.2
	end
	local maxDesire = GetAdjustedDesireValue(1)
	healthScore = RemapValClamped(healthScore, 0, 1, 0, maxDesire)
	local desire = maxDesire - (healthScore + maxDesire - maxDesire * (1 - healthScore ^ 2 / maxDesire) ^ 4) / 2
	if enemyCount > 0 then
		if enemyCount - allyCount > 0 then
			desire = desire + (enemyCount - allyCount) * GetAdjustedDesireValue(BOT_MODE_DESIRE_HIGH) / 4
		end
		if not weAreStronger and enemyCount >= allyCount then
			desire = desire + GetAdjustedDesireValue(0.25)
		end
		if allyCount >= enemyCount or weAreStronger then
			if
				bot:HasModifier("modifier_oracle_false_promise_timer")
				and Fu.GetModifierTime(bot, "modifier_oracle_false_promise_timer") > 2.0
				and Fu.IsUnitNearby(bot, allyHeroes, 1200, "npc_dota_hero_oracle", true)
			then
				desire = desire - GetAdjustedDesireValue(0.25)
			end
			if
				bot:HasModifier("modifier_dazzle_shallow_grave")
				and Fu.GetModifierTime(bot, "modifier_dazzle_shallow_grave") >= 2.0
				and Fu.IsUnitNearby(bot, allyHeroes, 1200, "npc_dota_hero_dazzle", true)
			then
				desire = desire - GetAdjustedDesireValue(0.2)
			end
			if bot:HasModifier("modifier_item_satanic_unholy") then
				desire = desire - GetAdjustedDesireValue(0.3)
			end
			-- Monkey King's Jingu charges: 20-80% lifesteal on hits, so stay in while above 20% HP.
			if bot:HasModifier("modifier_monkey_king_quadruple_tap_bonuses") and Fu.GetHP(bot) > 0.2 then
				desire = desire - GetAdjustedDesireValue(0.2)
			end
			local shadowDanceAbility = bot:GetAbilityByName("slark_shadow_dance")
			if
				Fu.CanCastAbility(shadowDanceAbility)
				or shadowDanceAbility ~= nil and shadowDanceAbility:IsTrained() and shadowDanceAbility:GetCooldownTimeRemaining() <= 3 and bot:GetMana() >= 150
				or bot:HasModifier("modifier_slark_shadow_dance")
					and Fu.GetModifierTime(bot, "modifier_slark_shadow_dance") > 1.5
			then
				desire = desire - GetAdjustedDesireValue(0.3)
			end
		end
	end
	local enemiesOnHighGround = Fu.Utils.CountEnemyHeroesOnHighGround(GetTeam())
	if enemiesOnHighGround > 0 and allyCount < 5 then
		local ancientDistance = GetUnitToUnitDistance(bot, allyAncient)
		if ancientDistance < 5000 then
			local aliveAllies = Fu.GetNumOfAliveHeroes(false)
			local aliveEnemies = Fu.GetNumOfAliveHeroes(true)
			if aliveEnemies > aliveAllies or not weAreStronger then
				local extraDesire = 0.15 + Max(0, enemiesOnHighGround - aliveAllies) * 0.05
				desire = desire + GetAdjustedDesireValue(extraDesire)
			end
		end
	end
	if bot:DistanceFromFountain() > 4000 then
		if enemyCount == 0 and recentlySeenEnemies == 0 and #enemyTowers == 0 then
			desire = desire - GetAdjustedDesireValue(0.25)
		end
	end
	if Fu.IsInLaningPhase() then
		if
			not bot:WasRecentlyDamagedByAnyHero(3.0)
			and (not bot:WasRecentlyDamagedByCreep(2.0) and hpRatio > 0.2)
			and (not bot:WasRecentlyDamagedByTower(2.0) and hpRatio > 0.2)
			and bot:DistanceFromFountain() > 4000
			and #Fu.GetHeroesTargetingUnit(enemyHeroes, bot) == 0
		then
			if
				hpRatio > 0.25
				or healthRegen > 20
				or bot:HasModifier("modifier_tango_heal")
				or bot:HasModifier("modifier_flask_healing")
				or bot:HasModifier("modifier_juggernaut_healing_ward_heal")
				or bot:HasModifier("modifier_item_urn_heal")
				or bot:HasModifier("modifier_item_spirit_vessel_heal")
			then
				desire = desire - GetAdjustedDesireValue(0.25)
			end
		end
	end
	if
		not Fu.IsInLaningPhase()
		and not bot:WasRecentlyDamagedByAnyHero(3.0)
		and not bot:WasRecentlyDamagedByTower(2.0)
		and hpRatio > 0.4
		and enemyCount == 0
	then
		desire = desire - GetAdjustedDesireValue(0.2)
	end
	if bot:HasModifier("modifier_slark_shadow_dance_passive_regen") then
		desire = desire - GetAdjustedDesireValue(0.25)
	end
	return RetreatTag(533, Clamp(desire, 0.0, BOT_MODE_DESIRE_ABSOLUTE))
end
-- A kill he is committed to: his target is in reach (attack range + 200) and disabled or below
-- 40% HP, and he either has Satanic's Unholy Rage on or 35%+ HP. The enemy-base run rules
-- below (barracks nearby, close to their Ancient) used to fire anyway, with no HP check: game
-- 020, 58:46-58:56, Nature's Prophet had Lina trapped under their T3, popped Satanic and ran
-- (retreat line 383 at 98% HP), then died.
local function IsCommittedKill()
	if not Fu.IsValidHero(botTarget) or not Fu.CanBeAttacked(botTarget) or Fu.IsSuspiciousIllusion(botTarget) then
		return false
	end
	if GetUnitToUnitDistance(bot, botTarget) > bot:GetAttackRange() + 200 then
		return false
	end
	if not (Fu.IsDisabled(botTarget) or Fu.GetHP(botTarget) < 0.4) then
		return false
	end
	return bot:HasModifier("modifier_item_satanic_unholy")
		or bot:HasModifier("modifier_monkey_king_quadruple_tap_bonuses") and Fu.GetHP(bot) >= 0.2
		or Fu.GetHP(bot) >= 0.35
end
function Retreat.ShouldRun()
	if bot:IsChanneling() or not bot:IsAlive() then
		return 0
	end
	if bot:HasModifier("modifier_medusa_stone_gaze_facing") then
		local attackTarget = bot:GetAttackTarget()
		if
			attackTarget ~= nil
			and attackTarget:GetUnitName() == "npc_dota_hero_medusa"
			and Fu.IsOtherAllyCanKillTarget(bot, attackTarget)
		then
		else
			return 3.33
		end
	end
	if
		(
			bot:GetCurrentMovementSpeed() > 330 and bot:DistanceFromFountain() < 10000
			or bot:DistanceFromFountain() < 5000
		) and not bot:WasRecentlyDamagedByAnyHero(5.0)
	then
		if botName == "npc_dota_hero_medusa" then
			local travelTime = bot:DistanceFromFountain() / bot:GetCurrentMovementSpeed()
			if mpRatio < 0.2 and mpRatio + manaRegen * travelTime / bot:GetMaxMana() < 0.4 then
				return travelTime
			end
		else
			local travelTime = bot:DistanceFromFountain() / bot:GetCurrentMovementSpeed()
			if hpRatio < 0.2 and hpRatio + healthRegen * travelTime / bot:GetMaxHealth() < 0.4 then
				return travelTime
			end
		end
	end
	for _, enemyHero in pairs(enemyHeroes) do
		if
			Fu.IsValidHero(enemyHero)
			and not Fu.IsSuspiciousIllusion(enemyHero)
			and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			local attackRange = enemyHero:GetAttackRange()
			if
				enemyHero:HasModifier("modifier_muerta_pierce_the_veil_buff")
				and Fu.IsInRange(bot, enemyHero, attackRange)
				and hpRatio < 0.5
			then
				local remainingTime = Fu.GetModifierTime(enemyHero, "modifier_muerta_pierce_the_veil_buff")
				if
					enemyHero:GetEstimatedDamageToTarget(false, bot, remainingTime, DAMAGE_TYPE_MAGICAL)
					>= botHealth + healthRegen * remainingTime
				then
					return remainingTime
				end
			elseif
				enemyHero:HasModifier("modifier_bristleback_active_conical_quill_spray")
				and Fu.IsInRange(bot, enemyHero, 400)
				and not enemyHero:IsFacingLocation(botLocation, 70)
			then
				return 3
			end
		end
	end
	if
		BOT_MODE_WISDOM_SHRINE
		and bot:GetActiveMode() == BOT_MODE_WISDOM_SHRINE
		and bot:GetActiveModeDesire() >= BOT_MODE_DESIRE_HIGH
	then
		local enemyTower = nil
		if GetTeam() == TEAM_RADIANT then
			enemyTower = GetTower(TEAM_DIRE, TOWER_BOT_1)
		else
			enemyTower = GetTower(TEAM_RADIANT, TOWER_TOP_1)
		end
		if enemyTower ~= nil and enemyTower:IsAlive() and GetUnitToUnitDistance(bot, enemyTower) < 1600 then
			local allyCount = Fu.GetAllyCount(bot, 1600)
			if Fu.IsInLaningPhase() or allyCount < 3 then
				return 2
			end
		end
	end
	local enemyFountainDistance = Fu.GetDistanceFromEnemyFountain(bot)
	if enemyFountainDistance < 1560 then
		return 2
	end
	if DotaTime() > 0 and Fu.IsEarlyGame() then
		local assignedLane = bot:GetAssignedLane()
		local team = GetTeam()
		local isDeepInEnemyLane = assignedLane == LANE_TOP
				and enemyFountainDistance < (team == TEAM_RADIANT and 12000 or 9000)
			or assignedLane == LANE_MID and enemyFountainDistance < (team == TEAM_RADIANT and 9000 or 8000)
			or assignedLane == LANE_BOT and enemyFountainDistance < (team == TEAM_RADIANT and 8700 or 11500)
		local nearbyEnemyTowers = bot:GetNearbyTowers(950, true)
		local isDivingTower = Fu.IsValidBuilding(nearbyEnemyTowers[1])
			and GetUnitToUnitDistance(bot, nearbyEnemyTowers[1])
				< (nearbyEnemyTowers[1]:GetAttackRange() or 700) + 200
		-- Game 044, 6:00: this ran Kez (87% HP, 2 allies to 1) off a Puck at 16% HP next to Dire's T1: "deep in the
		-- lane" alone triggered it, and "two right-clicks" ignored his spells and his allies. Now only inside the
		-- enemy tower's reach, and not when the target dies to what we and the allies near can do in ~3s, or is
		-- under 25% HP while the tower is busy with someone else.
		if
			isDivingTower
			and Fu.IsValidHero(botTarget)
			and Fu.CanBeAttacked(botTarget)
			and not Fu.IsSuspiciousIllusion(botTarget)
		then
			local teamDamage = bot:GetEstimatedDamageToTarget(true, botTarget, 3.0, DAMAGE_TYPE_ALL) or 0
			for _, ally in pairs(bot:GetNearbyHeroes(1200, false, BOT_MODE_NONE) or {}) do
				if Fu.IsValidHero(ally) and ally ~= bot and not ally:IsIllusion() then
					teamDamage = teamDamage
						+ (ally:GetEstimatedDamageToTarget(true, botTarget, 3.0, DAMAGE_TYPE_ALL) or 0)
				end
			end
			local tower = nearbyEnemyTowers[1]
			local towerOnUs = tower:GetAttackTarget() == bot
			local killable = teamDamage >= botTarget:GetHealth()
			local lowTarget = Fu.GetHP(botTarget) < 0.25 and not towerOnUs
			if not killable and not lowTarget then
				if DotaTime() >= (bot._antiDiveLogAt or -999) then
					bot._antiDiveLogAt = DotaTime() + 5
					pcall(
						print,
						string.format(
							"[OHA-RETREAT] t=%.0f %s anti-dive why=tower target=%s hp=%.2f dmg3s=%d targetHp=%d towerOnUs=%s",
							DotaTime(),
							(string.gsub(botName, "npc_dota_hero_", "")),
							(string.gsub(botTarget:GetUnitName(), "npc_dota_hero_", "")),
							Fu.GetHP(botTarget),
							math.floor(teamDamage),
							botTarget:GetHealth(),
							tostring(towerOnUs)
						)
					)
				end
				return 2.88
			end
		elseif isDeepInEnemyLane and Fu.IsValidHero(botTarget) and DotaTime() >= (bot._deepLaneLogAt or -999) then
			bot._deepLaneLogAt = DotaTime() + 10
			pcall(
				print,
				string.format(
					"[OHA-RETREAT] t=%.0f %s anti-dive skipped why=deep-lane-only target=%s",
					DotaTime(),
					(string.gsub(botName, "npc_dota_hero_", "")),
					(string.gsub(botTarget:GetUnitName(), "npc_dota_hero_", ""))
				)
			)
		end
	end
	local nearbyEnemyTowers = bot:GetNearbyTowers(900, true)
	local nearbyEnemyBarracks = bot:GetNearbyBarracks(900, true)
	local aliveEnemies = Fu.GetNumOfAliveHeroes(true)
	local enemyAncientDistance = GetUnitToUnitDistance(bot, enemyAncient)
	local isCommitted = IsCommittedKill()
	if #nearbyEnemyBarracks >= 1 and aliveEnemies >= 2 and not isCommitted then
		if #nearbyEnemyTowers >= 2 or enemyAncientDistance <= 1314 or enemyFountainDistance <= 2828 then
			return 2
		end
	end
	if (enemyAncientDistance <= 2000 or enemyFountainDistance <= 3000) and not isCommitted then
		local nearbyAllyCreeps = bot:GetNearbyLaneCreeps(900, false)
		local towerHitWithoutCreeps = bot:WasRecentlyDamagedByTower(3.0) and #nearbyAllyCreeps < 2
		if towerHitWithoutCreeps or hpRatio < 0.9 then
			local canLastHitTarget = false
			if
				Fu.IsValidHero(botTarget)
				and Fu.CanBeAttacked(botTarget)
				and Fu.IsInRange(bot, botTarget, bot:GetAttackRange() + 150)
				and Fu.CanKillTarget(botTarget, bot:GetAttackDamage(), DAMAGE_TYPE_PHYSICAL)
			then
				canLastHitTarget = true
			end
			if not canLastHitTarget then
				return 4
			end
		end
	end
	return 0
end
function Retreat.GetUnitDesire(radius)
	local enemyUnits = GetUnitList(UNIT_LIST_ENEMIES)
	for _, unit in pairs(enemyUnits) do
		if Fu.IsValid(unit) and not unit:IsBuilding() and Fu.IsInRange(bot, unit, radius) then
			local unitName = unit:GetUnitName()
			local totalDamage = 0
			local isChasingBot = Fu.IsChasingTarget(unit, bot) or unit:GetAttackTarget() == bot
			-- Only a real illusion. The suspicion check alone matched real heroes (Razor, Chaos Knight).
			if
				not unit:HasModifier("modifier_arc_warden_tempest_double")
				and Fu.IsSuspiciousIllusion(unit)
				and unit:IsIllusion()
			then
				-- Only illusions attacking or chasing this hero. Counting every illusion within 1600
				-- sent full-HP heroes into retreat near a Phantom Lancer army (game 016: 55 of these
				-- at 100% HP, Disruptor at 61:30-62:15).
				local illusions = Fu.GetSameUnitType(bot, 1600, unitName, true)
				totalDamage = Fu.GetUnitListTotalAttackDamage(bot, illusions, 5.0)
				local netDamage = bot:GetActualIncomingDamage(totalDamage, DAMAGE_TYPE_PHYSICAL) - healthRegen * 5.0
				if netDamage / botHealth > 0.5 then
					if netDamage / botHealth > 0.65 then
						bot._unitRunBy = unitName
						return 0.9
					else
						bot._unitRunBy = unitName
						return 0.75
					end
				end
			elseif string.find(unitName, "warlock_golem") and isChasingBot then
				local golems = Fu.GetSameUnitType(bot, 1600, unitName, false)
				totalDamage = Fu.GetUnitListTotalAttackDamage(bot, golems, 5.0)
				local netDamage = bot:GetActualIncomingDamage(totalDamage, DAMAGE_TYPE_PHYSICAL) - healthRegen * 5.0
				if netDamage / botHealth > 0.45 then
					bot._unitRunBy = unitName
					return 0.9
				end
			elseif string.find(unitName, "broodmother_spider") and isChasingBot and not Fu.IsInTeamFight(bot, 1600) then
				-- npc_dota_broodmother_spiderling / _spiderite. "spiderlings" (plural) never matched.
				local spiders = Fu.GetSameUnitType(bot, 1600, unitName, true)
				totalDamage = Fu.GetUnitListTotalAttackDamage(bot, spiders, 5.0)
				local netDamage = bot:GetActualIncomingDamage(totalDamage, DAMAGE_TYPE_PHYSICAL) - healthRegen * 5.0
				if netDamage / botHealth > 0.25 then
					bot._unitRunBy = unitName
					return 0.75
				end
			elseif string.find(unitName, "eidolon") and isChasingBot and not Fu.IsInTeamFight(bot, 1600) then
				local eidolons = Fu.GetSameUnitType(bot, 1600, unitName, true)
				totalDamage = Fu.GetUnitListTotalAttackDamage(bot, eidolons, 5.0)
				local netDamage = bot:GetActualIncomingDamage(totalDamage, DAMAGE_TYPE_PHYSICAL) - healthRegen * 5.0
				if netDamage / botHealth > 0.25 then
					bot._unitRunBy = unitName
					return 0.9
				end
			end
		end
	end
	return 0
end
function Retreat.RetreatWhenTowerTargetedDesire()
	if DotaTime() > 10 * 60 or Fu.IsInTeamFight(bot, 1600) then
		return 0
	end
	local nearbyEnemyTowers = bot:GetNearbyTowers(900, true)
	if Fu.IsValidBuilding(nearbyEnemyTowers[1]) and not Fu.IsPushing(bot) then
		local towerReach = (nearbyEnemyTowers[1]:GetAttackRange() or 700) + 160
		local underTower = GetUnitToUnitDistance(bot, nearbyEnemyTowers[1]) < towerReach
		if nearbyEnemyTowers[1]:GetAttackTarget() == bot or bot:WasRecentlyDamagedByTower(1.5) then
			return BOT_MODE_DESIRE_ABSOLUTE
		end
		if
			underTower and (Fu.IsGoingOnSomeone(bot) or activeMode == BOT_MODE_ATTACK or activeMode == BOT_MODE_RUNE)
		then
			if
				Fu.IsValidHero(botTarget)
				and not Fu.IsSuspiciousIllusion(botTarget)
				and not botTarget:HasModifier("modifier_dazzle_shallow_grave")
				and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
			then
				-- Early game: never trade under T1 unless the kill is free.
				if Fu.IsEarlyGame() or Fu.IsInLaningPhase() then
					if not Fu.CanKillTarget(botTarget, bot:GetAttackDamage() * 1.8, DAMAGE_TYPE_PHYSICAL) then
						return BOT_MODE_DESIRE_VERYHIGH
					end
				end
				local estimatedDamage = bot:GetEstimatedDamageToTarget(true, botTarget, 5.0, DAMAGE_TYPE_ALL) * 1.2
				estimatedDamage = botTarget:GetActualIncomingDamage(estimatedDamage, DAMAGE_TYPE_ALL)
				if estimatedDamage / math.max(botTarget:GetHealth(), 1) < 0.88 then
					return 0.9
				end
			else
				return BOT_MODE_DESIRE_HIGH
			end
		end
	end
	return 0
end
function Retreat.ConsiderCompleteItem()
	local teamFightLocation = Fu.GetTeamFightLocation(bot)
	if
		teamFightLocation == nil
		and #enemyHeroes == 0
		and bot:DistanceFromFountain() < 4400
		and not bot:HasModifier("modifier_fountain_aura_buff")
	then
		if Fu.Item.GetEmptyInventoryAmount(bot) == 0 then
			local hasRecipe = false
			local recipeName = ""
			for slot = 9, 14 do
				local item = bot:GetItemInSlot(slot)
				if item then
					if string.find(item:GetName(), "item_recipe") then
						recipeName = item:GetName()
						hasRecipe = true
						break
					end
				end
			end
			if hasRecipe then
				local itemName = string.gsub(recipeName, "_recipe", "")
				local components = GetItemComponents(itemName)[1]
				local componentCount = 0
				for slot = 0, 14 do
					local item = bot:GetItemInSlot(slot)
					if item and not item:IsCombineLocked() then
						local slotItemName = item:GetName()
						if slot <= 8 and string.find(slotItemName, "recipe") then
							return 0
						end
						for i = 1, #components do
							if slotItemName == components[i] then
								componentCount = componentCount + 1
							end
						end
					end
				end
				if componentCount > 0 and componentCount == #components then
					return BOT_DESIRE_OVERRIDE * 1.5
				end
			end
		end
	end
	return 0
end
-- Retreat is held only below 60% HP. Game 030: held at any HP it kept healthy bots running 2s after
-- the danger was gone. Game 031, 1:20-1:37: without it Earthshaker (30-57% HP, no enemy near)
-- flipped retreat 0.70 / laning 0.30 27 times and stood in place.
GetDesire = require(GetScriptDirectory() .. "/FuncLib/systems/mode_hold").Wrap(
	GetDesire,
	"retreat",
	BOT_MODE_RETREAT,
	function(bot)
		-- Not while rooted: the rooted fight-back in GetDesire drops retreat on purpose.
		return bot:GetHealth() < 0.6 * bot:GetMaxHealth() and not bot:IsRooted()
	end
)
if SafeCall then
	local originalGetDesire = GetDesire
	if originalGetDesire then
		GetDesire = SafeCall(originalGetDesire, 0, "RETREAT_GetDesire")
	end
end
-- [OHA-PERF] timing (#52): FuncLib/systems/perf.lua
do
	local Perf = require(GetScriptDirectory() .. "/FuncLib/systems/perf")
	GetDesire = Perf.Wrap("retreat.GetDesire", GetDesire)
	Think = Perf.Wrap("retreat.Think", Think)
end
return Retreat
