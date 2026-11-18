-- Laning mode for the opening of the game.
local Utils = require(GetScriptDirectory() .. "/FuncLib/systems/utils")
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local Localization = require(GetScriptDirectory() .. "/FuncLib/systems/localization")
local bot = GetBot()
local botName = bot:GetUnitName()
if
	bot == nil
	or bot:IsInvulnerable()
	or not bot:IsHero()
	or not bot:IsAlive()
	or not string.find(botName, "hero")
	or bot:IsIllusion()
then
	return
end
if bot.isInLanePhase == nil then
	bot.isInLanePhase = false
end
local overrideMode = nil
local allyLaneCreeps = nil
local enemyLaneCreeps = nil
local furthestEnemyAttackRange = 0
local nearbyEnemies = nil
local botLane = nil
local attackRange = bot:GetAttackRange()
local attackDamage = bot:GetAttackDamage()
local humanCount, botCount = Fu.Utils.NumHumanBotPlayersInTeam(GetTeam())
local hasPickedAnnouncer = false
local hasAnnouncedPositions = false
if Utils.BuggyHeroesDueToValveTooLazy[botName] then
	overrideMode = dofile(GetScriptDirectory() .. "/FuncLib/systems/override_generic/mode_laning_generic")
end
-- Positions 1-3 are cores. Positions 4 and 5 are supports.
local function IsCoreRole()
	return Fu.GetPosition(bot) <= 3
end
local function IsSupportRole()
	return Fu.GetPosition(bot) >= 4
end
-- When a human is supporting, AI cores in the lane should farm more actively.
local function IsHumanSupportOnTeam()
	return Fu.IsPosxHuman(4) or Fu.IsPosxHuman(5)
end
function GetDesire()
	if ShouldSkipBotThink(GetBot()) then
		return 0
	end
	return GetDesireRaw()
end
function GetDesireRaw()
	PickOneAnnouncer()
	AnnounceMessages()
	bot.isInLanePhase = false
	local botLevel = bot:GetLevel()
	local gameTime = DotaTime()
	attackRange = bot:GetAttackRange()
	allyLaneCreeps = bot:GetNearbyLaneCreeps(1200, false)
	enemyLaneCreeps = bot:GetNearbyLaneCreeps(800, true)
	nearbyEnemies = bot:GetNearbyHeroes(1600, true, BOT_MODE_NONE)
	furthestEnemyAttackRange = GetFurthestEnemyAttackRange(nearbyEnemies)
	if overrideMode then
		botLane = overrideMode.GetBotTargetLane()
	else
		if IsLanMode and IsLanMode() then
			botLane = bot:GetAssignedLane()
		else
			local position = Fu.GetPosition(bot)
			if GetTeam() == TEAM_RADIANT then
				if position == 2 then
					botLane = LANE_MID
				elseif position == 1 or position == 5 then
					botLane = LANE_BOT
				elseif position == 3 or position == 4 then
					botLane = LANE_TOP
				end
			else
				if position == 2 then
					botLane = LANE_MID
				elseif position == 1 or position == 5 then
					botLane = LANE_TOP
				elseif position == 3 or position == 4 then
					botLane = LANE_BOT
				end
			end
			if botLane == nil then
				botLane = bot:GetAssignedLane() or LANE_MID
			end
		end
	end
	attackDamage = bot:GetAttackDamage()
	if bot:GetItemSlotType(bot:FindItemSlot("item_quelling_blade")) == ITEM_SLOT_TYPE_MAIN then
		if bot:GetAttackRange() > 310 or bot:GetUnitName() == "npc_dota_hero_templar_assassin" then
			attackDamage = attackDamage + 4
		else
			attackDamage = attackDamage + 8
		end
	end
	if gameTime < 0 then
		return BOT_ACTION_DESIRE_NONE
	end
	if Fu.GetEnemiesAroundAncient(bot, 3200) > 0 then
		return BOT_MODE_DESIRE_NONE
	end
	if bot:WasRecentlyDamagedByAnyHero(3) and #Fu.Utils.GetLastSeenEnemyIdsNearLocation(bot:GetLocation(), 800) > 0 then
		if Fu.GetHP(bot) < 0.4 and not Fu.WeAreStronger(bot, 1200) then
			return BOT_MODE_DESIRE_VERYLOW
		end
	end
	if
		nearbyEnemies ~= nil
		and #nearbyEnemies >= 1
		and (bot:WasRecentlyDamagedByAnyHero(2.0) or Fu.IsGoingOnSomeone(bot))
	then
		local firstEnemy = nearbyEnemies[1]
		local distance = Fu.IsValidHero(firstEnemy) and GetUnitToUnitDistance(bot, firstEnemy) or -1
		if distance >= 0 and distance < 1000 and Fu.GetHP(firstEnemy) < 0.6 then
			return 0.1
		end
	end
	if Fu.Utils.IsTeamPushingSecondTierOrHighGround(bot) then
		return BOT_MODE_DESIRE_NONE
	end
	-- AI cores contest last hits and denies when a human is supporting them.
	local bHumanSupport = IsHumanSupportOnTeam()
	if overrideMode or (IsCoreRole() and bHumanSupport) then
		if gameTime <= 9 * 60 then
			local lastHitCreep, _ = GetBestLastHitCreep(enemyLaneCreeps)
			local denyCreep = nil
			if IsCoreRole() and bHumanSupport then
				denyCreep = GetBestDenyCreep(allyLaneCreeps)
			end
			if Fu.IsValid(lastHitCreep) or Fu.IsValid(denyCreep) then
				-- Supports only get this boost when no core is around.
				local nCoreRadius = IsSupportRole() and 1000 or 700
				if Fu.GetPosition(bot) <= 2 or not Fu.IsThereNonSelfCoreNearby(nCoreRadius) then
					return 0.6
				end
			end
		end
	end
	if overrideMode and overrideMode.GetDesire ~= nil then
		return overrideMode.GetDesire()
	end
	if GetGameMode() == GAMEMODE_1V1MID or GetGameMode() == GAMEMODE_MO then
		return 1
	end
	local secondTowerByLane = { [LANE_TOP] = TOWER_TOP_2, [LANE_MID] = TOWER_MID_2, [LANE_BOT] = TOWER_BOT_2 }
	local enemySecondTower = secondTowerByLane[botLane] and GetTower(GetOpposingTeam(), secondTowerByLane[botLane])
	if enemySecondTower == nil or not enemySecondTower:IsAlive() then
		return 0
	end
	local hpRatio = Fu.GetHP(bot)
	local isSafe = #nearbyEnemies == 0 or bot:HasModifier("modifier_tower_aura_bonus")
	local desireScale = isSafe and 1 or RemapValClamped(hpRatio, 0, 0.7, 0, 1)
	if gameTime <= 10 then
		bot.isInLanePhase = true
		return 0.268 * desireScale
	end
	if gameTime <= 10 * 60 then
		bot.isInLanePhase = true
		if Fu.IsCore(bot) and isSafe and not bot:WasRecentlyDamagedByAnyHero(5.0) and not Fu.IsRetreating(bot) then
			return BOT_MODE_DESIRE_HIGH + 0.04
		end
		return (BOT_MODE_DESIRE_MODERATE - 0.05) * desireScale
	end
	if gameTime <= 12 * 60 and botLevel <= 11 then
		return 0.2 * desireScale
	end
	bot.isInLanePhase = false
	return BOT_MODE_DESIRE_NONE
end
function GetFurthestEnemyAttackRange(enemies)
	local furthestRange = 0
	for _, enemyHero in pairs(enemies) do
		if Fu.IsValidHero(enemyHero) and not Fu.IsSuspiciousIllusion(enemyHero) then
			local range = enemyHero:GetAttackRange()
			if range > furthestRange then
				furthestRange = range
			end
		end
	end
	return furthestRange
end
local function GetCreepValue(creep)
	local unitName = creep:GetUnitName()
	if string.find(unitName, "ranged") then
		return 3
	end
	if string.find(unitName, "flagbearer") then
		return 2
	end
	return 1
end
function GetBestLastHitCreep(creeps)
	local damage = attackDamage - 3
	local bestCreep = nil
	local bestValue = 0
	for _, creep in pairs(creeps) do
		if Fu.IsValid(creep) and Fu.CanBeAttacked(creep) then
			local attackDelay = Fu.GetAttackProDelayTime(bot, creep)
			local value = GetCreepValue(creep)
			if Fu.WillKillTarget(creep, damage, DAMAGE_TYPE_PHYSICAL, attackDelay) then
				if value > bestValue then
					bestValue = value
					bestCreep = creep
				end
			end
		end
	end
	return bestCreep
end
function GetBestDenyCreep(creeps)
	local bestCreep = nil
	local bestValue = 0
	local fallbackCreep = nil
	local fallbackScore = 0
	for _, creep in pairs(creeps) do
		if
			Fu.IsValid(creep)
			and Fu.GetHP(creep) < 0.49
			and Fu.CanBeAttacked(creep)
			and creep:GetHealth() <= attackDamage
			and Fu.IsDeniableLaneCreep(creep)
		then
			local value = GetCreepValue(creep)
			-- Prefer a deny that can be executed immediately. Otherwise keep the
			-- best creep as a fallback so the bot can walk up to it.
			if GetUnitToUnitDistance(bot, creep) <= attackRange + 100 then
				if value > bestValue then
					bestValue = value
					bestCreep = creep
				end
			elseif value > fallbackScore then
				fallbackScore = value
				fallbackCreep = creep
			end
		end
	end
	if bestCreep ~= nil then
		return bestCreep
	end
	return fallbackCreep
end
local nextMoveTime = 0
local function ShiftTowerAggro(allyCreeps)
	local enemyTowers = bot:GetNearbyTowers(900, true)
	if Fu.IsValidBuilding(enemyTowers[1]) and enemyTowers[1]:GetAttackTarget() == bot then
		for _, creep in pairs(allyCreeps) do
			if Fu.IsValid(creep) and Fu.IsInRange(bot, creep, attackRange + 100) then
				bot:Action_AttackUnit(creep, true)
				return true
			end
		end
	end
	return false
end
local function GetLanePartner()
	for i = 1, #GetTeamPlayers(GetTeam()) do
		local member = GetTeamMember(i)
		if member ~= nil and member ~= bot and Fu.IsValidHero(member) and member:GetAssignedLane() == botLane then
			return member
		end
	end
	return nil
end
-- Ally T1 ↔ enemy T1 is ~7k mid / ~11k side lanes; midpoint ≈ 3.5k / 5.5k from our T1.
-- Harass up to ~lane midpoint on our half; never inside enemy T1 range.
local OFFSIDE_ENEMY_FROM_T1 = 3800
local OFFSIDE_SELF_FROM_T1 = 4000
local function GetLaneT1(team, lane)
	if lane == LANE_TOP then
		return GetTower(team, TOWER_TOP_1)
	elseif lane == LANE_MID then
		return GetTower(team, TOWER_MID_1)
	elseif lane == LANE_BOT then
		return GetTower(team, TOWER_BOT_1)
	end
	return nil
end
local function PrettyHeroName(unit)
	local name = string.gsub(unit:GetUnitName(), "npc_dota_hero_", "")
	name = string.gsub(name, "_(%l)", function(letter)
		return " " .. string.upper(letter)
	end)
	return string.upper(string.sub(name, 1, 1)) .. string.sub(name, 2)
end
local function AnnounceOffsideHarass(target)
	local now = DotaTime()
	if bot.sOffsideHarassChatTime ~= nil and now - bot.sOffsideHarassChatTime < 10 then
		return
	end
	bot.sOffsideHarassChatTime = now
	bot:ActionImmediate_Chat("Harassing " .. PrettyHeroName(target), false)
end
-- Right-clicking a hero pulls every enemy lane creep within 500 that is not already on us.
local function CreepAggroCounts(hero)
	local creeps = hero:GetNearbyLaneCreeps(500, true) or {}
	local fresh, hitting = 0, 0
	for _, creep in pairs(creeps) do
		if Fu.IsValid(creep) then
			if creep:GetAttackTarget() == hero then
				hitting = hitting + 1
			else
				fresh = fresh + 1
			end
		end
	end
	return fresh, hitting
end
local function CreepAggroUnsafe(hero)
	local fresh, hitting = CreepAggroCounts(hero)
	return fresh > 0 or hitting >= 2
end
-- Diagnostic (#71): with an enemy hero in attack range and no last hit to take, did the bot harass, and if not,
-- which gate stopped it (hp / creep-aggro / tower)? The maintainer sees bots stand idle between last hits.
-- At most every 5s per bot.
local function LogHarass(enemyHero, target, why, fresh, hitting)
	if DotaTime() < (bot._harassLogAt or -999) then
		return
	end
	bot._harassLogAt = DotaTime() + 5
	pcall(
		print,
		string.format(
			"[OHA-HARASS] t=%.0f %s %s target=%s why=%s hp=%.2f fresh=%d hitting=%d range=%d dist=%d",
			DotaTime(),
			(string.gsub(bot:GetUnitName(), "npc_dota_hero_", "")),
			target ~= nil and "hit" or "skip",
			(string.gsub(enemyHero:GetUnitName(), "npc_dota_hero_", "")),
			why or "-",
			Fu.GetHP(bot),
			fresh,
			hitting,
			attackRange,
			GetUnitToUnitDistance(bot, enemyHero)
		)
	)
end
-- Aggressive lane poke on our half. LH/deny still come first in Think.
local function ConsiderOffsideHarass(enemyHeroes)
	if not Fu.IsInLaningPhase or not Fu.IsInLaningPhase() then
		return nil
	end
	if Fu.GetHP(bot) < 0.55 or CreepAggroUnsafe(bot) then
		return nil
	end
	if bot:WasRecentlyDamagedByAnyHero(1.0) and Fu.GetHP(bot) < 0.75 then
		return nil
	end
	local allyT1 = GetLaneT1(GetTeam(), botLane)
	local enemyT1 = GetLaneT1(GetOpposingTeam(), botLane)
	if allyT1 == nil or not allyT1:IsAlive() then
		return nil
	end
	local currentAttackRange = bot:GetAttackRange()
	local best = nil
	local bestDist = 99999
	for _, enemy in pairs(enemyHeroes or {}) do
		if
			Fu.IsValidHero(enemy)
			and Fu.CanBeAttacked(enemy)
			and not Fu.IsSuspiciousIllusion(enemy)
			and Fu.IsInRange(bot, enemy, currentAttackRange + 250)
		then
			-- Never stand inside enemy tower attack range.
			if
				enemyT1 ~= nil
				and enemyT1:IsAlive()
				and GetUnitToUnitDistance(bot, enemyT1) < (enemyT1:GetAttackRange() or 700) + 180
			then
				goto continue_enemy
			end
			-- Don't chase a hero who is hugging their own T1 (rune/tower bait).
			if
				enemyT1 ~= nil
				and enemyT1:IsAlive()
				and GetUnitToUnitDistance(enemy, enemyT1) < (enemyT1:GetAttackRange() or 700) + 250
			then
				goto continue_enemy
			end
			local enemyToAllyT1 = GetUnitToUnitDistance(enemy, allyT1)
			local selfToAllyT1 = GetUnitToUnitDistance(bot, allyT1)
			if enemyToAllyT1 <= OFFSIDE_ENEMY_FROM_T1 and selfToAllyT1 <= OFFSIDE_SELF_FROM_T1 then
				local dist = GetUnitToUnitDistance(bot, enemy)
				if dist < bestDist then
					bestDist = dist
					best = enemy
				end
			end
			::continue_enemy::
		end
	end
	return best
end
-- A melee core held back at the enemy's attack range (600 vs a ranged laner) is too
-- far to walk in for a last hit before the creeps finish it. It stands by the wave.
local MELEE_CORE_STANDOFF = 300
local function LaneStandOff()
	local standOff = math.max(attackRange, 250, furthestEnemyAttackRange)
	if IsCoreRole() and attackRange < 326 and Fu.GetHP(bot) >= 0.45 then
		standOff = math.min(standOff, MELEE_CORE_STANDOFF)
	end
	return standOff
end
-- Name of an allied core that will get this last hit itself, or nil when none can, plus
-- when its hit would land (nil for a human core, who is always left the creep). A bot core
-- counts when its own attack, including the walk, lands before the creeps kill it.
local function CoreCanTakeLastHit(creep)
	for _, ally in pairs(Fu.GetNearbyHeroes(bot, 1000, false, BOT_MODE_NONE) or {}) do
		if Fu.IsValidHero(ally) and ally ~= bot and Fu.IsCore(ally) and not ally:IsIllusion() then
			local name = (string.gsub(ally:GetUnitName(), "npc_dota_hero_", ""))
			if not ally:IsBot() then
				return name, nil
			end
			local delay = Fu.GetAttackProDelayTime(ally, creep)
			if Fu.WillKillTarget(creep, ally:GetAttackDamage() - 3, DAMAGE_TYPE_PHYSICAL, delay) then
				return name, delay
			end
		end
	end
	return nil, nil
end
-- Enemy heroes harassing us: aiming at us now, or hit us in the last 1.5s.
local function Harassers()
	local list = {}
	for _, enemyHero in pairs(nearbyEnemies or {}) do
		if
			Fu.IsValidHero(enemyHero)
			and not Fu.IsSuspiciousIllusion(enemyHero)
			and (enemyHero:GetAttackTarget() == bot or bot:WasRecentlyDamagedByHero(enemyHero, 1.5))
		then
			list[#list + 1] = enemyHero
		end
	end
	return list
end
local function LaneLog(fmt, ...)
	if DotaTime() >= (bot._laneRiskLogAt or -999) then
		bot._laneRiskLogAt = DotaTime() + 2
		pcall(print, string.format(fmt, ...))
	end
end
-- Walking in for a last hit with a harasser on us (user rule 2026-11-17). The spot we attack from
-- is inside a harasser's attack range + 100: skip below 40% HP, skip a melee creep below 60% HP
-- (ranged / siege / flagbearer still worth it), and a ranged bot below 60% only last-hits from
-- where it stands. Returns why it skips, or nil.
local function LastHitRisk(creep, spot, needsWalk)
	local hp = Fu.GetHP(bot)
	if hp >= 0.6 then
		return nil
	end
	local danger = nil
	for _, harasser in pairs(Harassers()) do
		if GetUnitToLocationDistance(harasser, spot) <= harasser:GetAttackRange() + 100 then
			danger = harasser
			break
		end
	end
	if danger == nil then
		return nil
	end
	local name = creep:GetUnitName() or ""
	local valuable = GetCreepValue(creep) >= 2 or string.find(name, "siege", 1, true) ~= nil
	if hp < 0.4 then
		return "low-hp", danger
	end
	if not valuable then
		return "melee-creep", danger
	end
	if attackRange > 326 and needsWalk then
		return "ranged-walk", danger
	end
	return nil
end
-- [OHA-LANE]: every 20s per bot in the laning phase. Last hits, denies, where it
-- stands relative to the wave, and how often a support took or left a last hit.
local function LogLaning()
	local now = DotaTime()
	if now < 0 or now > 10 * 60 or now < (bot._laneLogAt or -999) then
		return
	end
	bot._laneLogAt = now + 20
	local nearest = 99999
	for _, creep in pairs(bot:GetNearbyLaneCreeps(1600, true) or {}) do
		if Fu.IsValid(creep) then
			nearest = math.min(nearest, GetUnitToUnitDistance(bot, creep))
		end
	end
	local partner = GetLanePartner()
	pcall(
		print,
		string.format(
			"[OHA-LANE] t=%.0f %s pos=%d lane=%s range=%d standoff=%d enemyRange=%d creep=%d lh=%d dn=%d partner=%s supTook=%d supLeft=%d hp=%.2f",
			now,
			(string.gsub(bot:GetUnitName(), "npc_dota_hero_", "")),
			Fu.GetPosition(bot),
			tostring(botLane),
			math.floor(attackRange),
			math.floor(LaneStandOff()),
			math.floor(furthestEnemyAttackRange or 0),
			math.floor(nearest),
			bot:GetLastHits(),
			bot:GetDenies(),
			partner ~= nil and (string.gsub(partner:GetUnitName(), "npc_dota_hero_", "")) or "-",
			bot._laneSupportTook or 0,
			bot._laneSupportLeft or 0,
			Fu.GetHP(bot)
		)
	)
	bot._laneSupportTook = 0
	bot._laneSupportLeft = 0
end
-- Enemy summons attacking this hero: spiderlings, wolves, golems, treants. Lane creeps,
-- heroes and buildings are handled elsewhere.
local function SummonsOnMe()
	local count = 0
	for _, unit in pairs(GetUnitList(UNIT_LIST_ENEMIES) or {}) do
		if
			Fu.IsValid(unit)
			and not unit:IsHero()
			and not unit:IsBuilding()
			and not string.find(unit:GetUnitName() or "", "npc_dota_creep_", 1, true)
			and unit:GetAttackTarget() == bot
			and GetUnitToUnitDistance(unit, bot) <= 800
		then
			count = count + 1
		end
	end
	return count
end
-- Custom laning Think for all roles so cores also harass (not only buggy/human-support).
do
	function Think()
		LogLaning()
		-- Standing at the lane spot while two or more summons bite is how a hero melted to
		-- spiderlings. Step back toward the tower and let the creeps or tower take them.
		local summons = SummonsOnMe()
		if summons >= 2 then
			if DotaTime() >= (bot._summonStepLogAt or -999) then
				bot._summonStepLogAt = DotaTime() + 5
				pcall(
					print,
					string.format(
						"[OHA-LANE] t=%.0f %s summons-step-back count=%d hp=%.2f",
						DotaTime(),
						(string.gsub(bot:GetUnitName(), "npc_dota_hero_", "")),
						summons,
						Fu.GetHP(bot)
					)
				)
			end
			bot:Action_MoveToLocation(Fu.AdjustLocationWithOffsetTowardsFountain(bot:GetLocation(), 500))
			return
		end
		local enemyTowers = bot:GetNearbyTowers(1200, true)
		if ShiftTowerAggro(allyLaneCreeps) then
			return
		end
		if Fu.IsValidBuilding(enemyTowers[1]) then
			local towerDistance = GetUnitToUnitDistance(bot, enemyTowers[1])
			if towerDistance < 800 and #enemyLaneCreeps < 3 then
				if DotaTime() >= nextMoveTime then
					bot:Action_MoveToLocation(
						Fu.VectorAway(bot:GetLocation(), enemyTowers[1]:GetLocation(), 950) + RandomVector(75)
					)
					nextMoveTime = DotaTime() + RandomFloat(1, 3)
					return
				end
			end
		end
		local bSupport = IsSupportRole()
		-- Supports deny first and leave the last hits to their core.
		if bSupport then
			local denyCreep = GetBestDenyCreep(allyLaneCreeps)
			if Fu.IsValid(denyCreep) then
				bot:SetTarget(denyCreep)
				bot:Action_AttackUnit(denyCreep, true)
				return
			end
		end
		local lastHitCreep = GetBestLastHitCreep(enemyLaneCreeps)
		if Fu.IsValid(lastHitCreep) then
			if
				Fu.IsValidBuilding(enemyTowers[1])
				and Fu.IsValid(enemyLaneCreeps[1])
				and GetUnitToUnitDistance(enemyLaneCreeps[1], enemyTowers[1]) < 700
				and GetUnitToUnitDistance(enemyLaneCreeps[1], bot) > attackRange
			then
				local creepsNearTower = bot:FindAoELocation(false, false, enemyTowers[1]:GetLocation(), 0, 650, 0, 0)
				if creepsNearTower.count <= 3 then
					goto a5
				end
			end
			local bCanLastHit
			if bSupport then
				-- Do not compete with a core for last hits, but take one the core cannot reach in time.
				-- With a bot core on the creep, go too but land after the core's hit: the core
				-- gets it first, and the support only secures it if the core misses it.
				local coreName, coreDelay = CoreCanTakeLastHit(lastHitCreep)
				bCanLastHit = coreName == nil
				if not bCanLastHit and coreDelay ~= nil then
					local myDelay = Fu.GetAttackProDelayTime(bot, lastHitCreep)
					bCanLastHit = myDelay > coreDelay + 0.15
						and Fu.WillKillTarget(lastHitCreep, bot:GetAttackDamage() - 3, DAMAGE_TYPE_PHYSICAL, myDelay)
				end
				if bot._laneSupportCreep ~= lastHitCreep then
					bot._laneSupportCreep = lastHitCreep
					if bCanLastHit then
						bot._laneSupportTook = (bot._laneSupportTook or 0) + 1
					else
						bot._laneSupportLeft = (bot._laneSupportLeft or 0) + 1
					end
				end
			else
				local lanePartner = GetLanePartner()
				bCanLastHit = lanePartner == nil
					or Fu.IsCore(bot)
					or not Fu.IsCore(bot)
						and Fu.IsCore(lanePartner)
						and (not lanePartner:IsAlive() or GetUnitToUnitDistance(lanePartner, lastHitCreep) > lanePartner:GetAttackRange() + 400)
			end
			if bCanLastHit then
				local creepDistance = GetUnitToUnitDistance(bot, lastHitCreep)
				do
					local spot = bot:GetLocation()
					if creepDistance > attackRange then
						spot = Fu.GetXUnitsTowardsLocation2(
							lastHitCreep:GetLocation(),
							bot:GetLocation(),
							attackRange - lastHitCreep:GetBoundingRadius()
						)
					end
					local why, harasser = LastHitRisk(lastHitCreep, spot, creepDistance > attackRange)
					if why ~= nil then
						LaneLog(
							"[OHA-LANE] t=%.0f %s lasthit-skip why=%s creep=%s by=%s hp=%.2f walk=%d",
							DotaTime(),
							(string.gsub(bot:GetUnitName(), "npc_dota_hero_", "")),
							why,
							(string.gsub(lastHitCreep:GetUnitName(), "npc_dota_", "")),
							(string.gsub(harasser:GetUnitName(), "npc_dota_hero_", "")),
							Fu.GetHP(bot),
							math.max(0, math.floor(creepDistance - attackRange))
						)
						goto a5
					end
				end
				if creepDistance > attackRange then
					local attackDistance = attackRange - lastHitCreep:GetBoundingRadius()
					local moveLocation =
						Fu.GetXUnitsTowardsLocation2(lastHitCreep:GetLocation(), bot:GetLocation(), attackDistance)
					bot:Action_MoveDirectly(moveLocation)
					return
				else
					bot:SetTarget(lastHitCreep)
					bot:Action_AttackUnit(lastHitCreep, false)
					return
				end
			end
			::a5::
		end
		-- Cores deny after looking for a last hit. Supports already denied above.
		if not bSupport then
			local coreDenyCreep = GetBestDenyCreep(allyLaneCreeps)
			if Fu.IsValid(coreDenyCreep) then
				bot:SetTarget(coreDenyCreep)
				bot:Action_AttackUnit(coreDenyCreep, true)
				return
			end
		end
		-- Offside poke (after LH/deny, before general harass). Stay in attack range.
		-- Walking closer is what pulls the wave onto her.
		do
			local offside = ConsiderOffsideHarass(nearbyEnemies)
			if offside ~= nil and GetUnitToUnitDistance(bot, offside) <= attackRange then
				AnnounceOffsideHarass(offside)
				bot:Action_AttackUnit(offside, true)
				return
			end
		end
		if overrideMode then
			overrideMode.Think()
			return
		end
		if
			Fu.IsValidBuilding(enemyTowers[1])
			and Fu.CanBeAttacked(enemyTowers[1])
			and Fu.IsValid(enemyTowers[1]:GetAttackTarget())
			and enemyTowers[1]:GetAttackTarget():IsCreep()
		then
			if #allyLaneCreeps >= 3 then
				bot:Action_AttackUnit(enemyTowers[1], true)
				return
			end
		end
		local enemyT1Harass = GetLaneT1(GetOpposingTeam(), botLane)
		local function SafeToHarassHero(hero)
			if not Fu.IsValidHero(hero) or not Fu.CanBeAttacked(hero) or Fu.IsSuspiciousIllusion(hero) then
				return false
			end
			if
				enemyT1Harass ~= nil
				and enemyT1Harass:IsAlive()
				and (
					GetUnitToUnitDistance(bot, enemyT1Harass) < (enemyT1Harass:GetAttackRange() or 700) + 180
					or GetUnitToUnitDistance(hero, enemyT1Harass) < (enemyT1Harass:GetAttackRange() or 700) + 250
				)
			then
				return false
			end
			return true
		end
		-- Harass a hero in attack range: supports above 50% HP, cores above 45%, no fresh creep aggro, not by
		-- the enemy T1 (unchanged rules; now one pass with a log of the gate that stops it).
		do
			local inRange = nil
			for _, enemyHero in pairs(nearbyEnemies) do
				if
					Fu.IsValidHero(enemyHero)
					and not Fu.IsSuspiciousIllusion(enemyHero)
					and Fu.IsInRange(bot, enemyHero, attackRange)
				then
					inRange = enemyHero
					break
				end
			end
			if inRange ~= nil then
				local fresh, hitting = CreepAggroCounts(bot)
				local hpNeed = Fu.IsCore(bot) and 0.45 or 0.5
				local target, why = nil, nil
				if Fu.GetHP(bot) <= hpNeed then
					why = "hp"
				elseif fresh > 0 or hitting >= 2 then
					why = "creep-aggro"
				else
					for _, enemyHero in pairs(nearbyEnemies) do
						if SafeToHarassHero(enemyHero) and Fu.IsInRange(bot, enemyHero, attackRange) then
							target = enemyHero
							break
						end
					end
					if target == nil then
						why = "tower"
					end
				end
				LogHarass(inRange, target, why, fresh, hitting)
				if target ~= nil then
					bot:Action_AttackUnit(target, true)
					return
				end
			end
		end
		-- Harassed with no last hit to take and no trade above: step out of the harasser's attack
		-- range + 100 toward our fountain for 1s, then the wait spot below brings us back.
		if bot._harassStepUntil ~= nil and DotaTime() < bot._harassStepUntil then
			bot:Action_MoveToLocation(bot._harassStepTo)
			return
		end
		do
			for _, harasser in pairs(Harassers()) do
				local dist = GetUnitToUnitDistance(bot, harasser)
				if bot:WasRecentlyDamagedByHero(harasser, 1.5) and dist <= harasser:GetAttackRange() + 100 then
					local need = math.max(150, harasser:GetAttackRange() + 150 - dist)
					bot._harassStepUntil = DotaTime() + 1.0
					bot._harassStepTo = Fu.AdjustLocationWithOffsetTowardsFountain(bot:GetLocation(), need)
					LaneLog(
						"[OHA-LANE] t=%.0f %s harass-step by=%s dist=%d step=%d hp=%.2f",
						DotaTime(),
						(string.gsub(bot:GetUnitName(), "npc_dota_hero_", "")),
						(string.gsub(harasser:GetUnitName(), "npc_dota_hero_", "")),
						dist,
						need,
						Fu.GetHP(bot)
					)
					bot:Action_MoveToLocation(bot._harassStepTo)
					return
				end
			end
		end
		-- Melee core aggro pull. Ordering an attack on any visible enemy hero, at any distance,
		-- makes the enemy creeps near him turn on him (the order is what counts, not walking in).
		-- He gives the order once, then steps back toward our tower for 1.5s so they follow:
		-- the wave fight moves off the enemy tower and away from their heroes, easier to farm.
		-- Only with HP 60%+, 2+ enemy creeps within 500, the wave within 1500 of the enemy T1,
		-- at most one enemy hero within 800, and once every 8s.
		if bot._aggroBackUntil ~= nil and DotaTime() < bot._aggroBackUntil then
			bot:Action_MoveToLocation(bot._aggroBackTo)
			return
		end
		if IsCoreRole() and attackRange < 326 and Fu.GetHP(bot) >= 0.6 and DotaTime() >= (bot._aggroNextAt or -999) then
			local close = 0
			for _, creep in pairs(enemyLaneCreeps or {}) do
				if Fu.IsValid(creep) and GetUnitToUnitDistance(bot, creep) <= 500 then
					close = close + 1
				end
			end
			local enemyT1 = GetLaneT1(GetOpposingTeam(), botLane)
			local nearTower = enemyT1 ~= nil
				and enemyT1:IsAlive()
				and Fu.IsValid(enemyLaneCreeps[1])
				and GetUnitToUnitDistance(enemyLaneCreeps[1], enemyT1) <= 1500
			local heroesClose = 0
			for _, enemyHero in pairs(nearbyEnemies or {}) do
				if Fu.IsValidHero(enemyHero) and GetUnitToUnitDistance(bot, enemyHero) <= 800 then
					heroesClose = heroesClose + 1
				end
			end
			if close >= 2 and nearTower and heroesClose <= 1 then
				local bait = nil
				for _, enemyHero in pairs(GetUnitList(UNIT_LIST_ENEMY_HEROES) or {}) do
					if
						Fu.IsValidHero(enemyHero)
						and enemyHero:CanBeSeen()
						and not Fu.IsSuspiciousIllusion(enemyHero)
					then
						bait = enemyHero
						break
					end
				end
				if bait ~= nil then
					bot._aggroNextAt = DotaTime() + 8
					bot._aggroBackUntil = DotaTime() + 1.5
					bot._aggroBackTo = Fu.AdjustLocationWithOffsetTowardsFountain(bot:GetLocation(), 350)
					pcall(
						print,
						string.format(
							"[OHA-AGGRO] t=%.0f %s pull creeps=%d bait=%s dist=%d",
							DotaTime(),
							(string.gsub(bot:GetUnitName(), "npc_dota_hero_", "")),
							close,
							(string.gsub(bait:GetUnitName(), "npc_dota_hero_", "")),
							GetUnitToUnitDistance(bot, bait)
						)
					)
					bot:Action_AttackUnit(bait, true)
					return
				end
			end
		end
		-- Melee core: wait at the edge of attack range of the enemy creep that is about to die
		-- (2.5 hits or less), not 300 behind the wave. From there the last hit only needs the
		-- attack, not a walk, so it lands in time. Not next to the enemy tower.
		if IsCoreRole() and attackRange < 326 and Fu.GetHP(bot) >= 0.45 and not CreepAggroUnsafe(bot) then
			local rawAttackDamage = bot:GetAttackDamage()
			local soon, soonHp = nil, math.huge
			for _, creep in pairs(enemyLaneCreeps or {}) do
				if
					Fu.IsValid(creep)
					and Fu.CanBeAttacked(creep)
					and creep:GetHealth() <= rawAttackDamage * 2.5
					and creep:GetHealth() < soonHp
					and not (Fu.IsValidBuilding(enemyTowers[1]) and GetUnitToUnitDistance(creep, enemyTowers[1]) < 750)
				then
					soon, soonHp = creep, creep:GetHealth()
				end
			end
			if soon ~= nil then
				local spot = Fu.GetXUnitsTowardsLocation2(
					soon:GetLocation(),
					bot:GetLocation(),
					attackRange + soon:GetBoundingRadius() + 40
				)
				if GetUnitToLocationDistance(bot, spot) > 60 then
					bot:Action_MoveDirectly(spot)
				end
				return
			end
		end
		local allyFrontAmount = GetLaneFrontAmount(GetTeam(), botLane, false)
		local enemyFrontAmount = GetLaneFrontAmount(GetOpposingTeam(), botLane, false)
		local standOff = LaneStandOff()
		local waitLocation = GetLaneFrontLocation(GetTeam(), botLane, -standOff)
		if enemyFrontAmount < allyFrontAmount then
			waitLocation = GetLaneFrontLocation(GetOpposingTeam(), botLane, -standOff)
		end
		if DotaTime() >= nextMoveTime then
			bot:Action_MoveToLocation(waitLocation + RandomVector(100))
			nextMoveTime = DotaTime() + RandomFloat(0.3, 0.9)
		end
	end
end
function PickOneAnnouncer()
	if hasPickedAnnouncer then
		return
	end
	local playerId = bot:GetPlayerID()
	local team = bot:GetTeam()
	local lowestBotId = playerId
	for otherId = 0, 63 do
		if otherId ~= playerId then
			local isBotOk, isBot = pcall(IsPlayerBot, otherId)
			local teamOk, otherTeam = pcall(GetTeamForPlayer, otherId)
			if isBotOk and teamOk and isBot and otherTeam == team and otherId < lowestBotId then
				lowestBotId = otherId
			end
		end
	end
	bot.isAnnouncer = playerId == lowestBotId
	hasPickedAnnouncer = true
end
function AnnounceMessages()
	-- Welcome + map version is sent during hero pick (hero_selection.lua), not here.
	if DotaTime() > 60 then
		return
	end
	if GetGameMode() ~= GAMEMODE_1V1MID and not hasAnnouncedPositions then
		if DotaTime() >= 0 and humanCount > 0 and botCount > 0 then
			bot:ActionImmediate_Chat(
				Localization.Get("pos_select_closed") .. " (" .. tostring(Fu.GetPosition(bot)) .. ")",
				true
			)
			hasAnnouncedPositions = true
		end
	end
end
-- Hold the desire through short dips while laning (FuncLib/systems/mode_hold.lua). Game 030: the
-- flips left were mostly laning against rune or attack (OD, 4:00: laning 0.56 / rune 0.35, 9 times).
GetDesire = require(GetScriptDirectory() .. "/FuncLib/systems/mode_hold").Wrap(GetDesire, "laning", BOT_MODE_LANING)
if SafeCall then
	local originalGetDesire = GetDesire
	local originalThink = Think
	if originalGetDesire then
		GetDesire = SafeCall(originalGetDesire, 0, "LANING_GetDesire")
	end
	if originalThink then
		Think = SafeCall(originalThink, nil, "LANING_Think")
	end
end
-- [OHA-PERF] timing (#52): FuncLib/systems/perf.lua
do
	local Perf = require(GetScriptDirectory() .. "/FuncLib/systems/perf")
	GetDesire = Perf.Wrap("laning.GetDesire", GetDesire)
	Think = Perf.Wrap("laning.Think", Think)
end
