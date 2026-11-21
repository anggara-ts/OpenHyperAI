-- Laning mode for the opening of the game.
local Utils = require(GetScriptDirectory() .. "/FuncLib/systems/utils")
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local Localization = require(GetScriptDirectory() .. "/FuncLib/systems/localization")
local LaneHarassRules = require(GetScriptDirectory() .. "/FuncLib/systems/lane_harass_rules")
local LastHitRules = require(GetScriptDirectory() .. "/FuncLib/systems/last_hit_rules")
local LastHitTiming = require(GetScriptDirectory() .. "/FuncLib/systems/last_hit_timing")
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
-- Creep value (#71, maintainer 2026-11-21): flagbearer > siege > ranged > melee, LastHitRules.KIND_VALUE.
local function GetCreepKind(creep)
	return LastHitRules.CreepKind(creep:GetUnitName())
end
-- Diagnostic (#71, game 047: enemy heroes kept walking behind our tower in the laning phase): when this bot is inside
-- an enemy tower's range in the laning phase, say which mode took it there. At most every 10s.
local function LogInEnemyTower()
	if not Fu.IsInLaningPhase() or DotaTime() < (bot._inEnemyTowerLogAt or -999) or not bot:IsAlive() then
		return
	end
	for _, tower in pairs(bot:GetNearbyTowers(1000, true) or {}) do
		if Fu.IsValidBuilding(tower) and GetUnitToUnitDistance(bot, tower) <= (tower:GetAttackRange() or 700) + 100 then
			bot._inEnemyTowerLogAt = DotaTime() + 10
			local target = bot:GetAttackTarget()
			-- Games 059 and 062: 53 of 64 lines were laning mode, 7 of 64 with the tower shooting the bot. Whether
			-- that is a wave fight at the tower (our creeps there to hold it) or a walk past the tower is not in the
			-- line: holders= our lane creeps in the tower's range, past= the bot is deeper than the tower (closer to
			-- the enemy fountain), act= the bot's current action type.
			local reach = (tower:GetAttackRange() or 700) + 100
			local holders = 0
			for _, creep in pairs(bot:GetNearbyLaneCreeps(1600, false) or {}) do
				if Fu.IsValid(creep) and GetUnitToUnitDistance(creep, tower) <= reach then
					holders = holders + 1
				end
			end
			local enemyFountain = Fu.GetEnemyFountain()
			local past = enemyFountain ~= nil
				and GetUnitToLocationDistance(bot, enemyFountain) < GetUnitToLocationDistance(tower, enemyFountain)
			pcall(
				print,
				string.format(
					"[OHA-LANE] t=%.0f %s in-enemy-tower mode=%d desire=%.2f towerOnMe=%s target=%s hp=%.2f holders=%d past=%s act=%d",
					DotaTime(),
					(string.gsub(bot:GetUnitName(), "npc_dota_hero_", "")),
					bot:GetActiveMode(),
					bot:GetActiveModeDesire(),
					tostring(tower:GetAttackTarget() == bot),
					target ~= nil and not target:IsNull() and target:GetUnitName() or "-",
					Fu.GetHP(bot),
					holders,
					tostring(past),
					bot:GetCurrentActionType() or -1
				)
			)
			return
		end
	end
end
-- Creep score (#71, maintainer game 050: "check all heroes' creep stats"). Last hits and denies every minute
-- until 15:00, then every 5 minutes. (Finished games also have the engine's end-of-match numbers.)
local function LogCreepScore()
	local now = DotaTime()
	if now < 0 or now < (bot._csLogAt or -999) or bot:IsIllusion() then
		return
	end
	bot._csLogAt = now + (now < 900 and 60 or 300)
	pcall(
		print,
		string.format(
			"[OHA-CS] t=%.0f %s lh=%d dn=%d lvl=%d nw=%d",
			now,
			(string.gsub(bot:GetUnitName(), "npc_dota_hero_", "")),
			bot:GetLastHits(),
			bot:GetDenies(),
			bot:GetLevel(),
			bot:GetNetWorth()
		)
	)
end
-- Last-hit attempts in the laning phase (#71, maintainer game 050 6:30: Weaver's hits look late; she missed 42
-- last hits, Kez 11). The first attack (or walk-in) order on a creep starts an attempt with the creep's HP and when
-- the hit is expected to land; when that creep dies, say whether the bot's last-hit count went up and how long it
-- really took.
-- Games 051-062 read this line wrong: the attempt started when GetBestLastHitCreep picked a creep, before the
-- support / tower / harasser gates, so creeps a support left to its core counted as "missed" (game 062: Nyx 0 of 18,
-- Dazzle 0 of 13), and the death was only seen at the next laning GetDesire (about 3 a second), which added up to
-- 0.3s to took=. Now the attempt starts at the order, both the laning GetDesire and Think look, and the line adds:
--   launch=  seconds from the order to the bot's first attack after it (GetLastAttackTime, read while the creep
--            lived), -1 when none was seen;
--   gap=     seconds since the previous look before the death was seen (took= can be late by up to this much);
--   walk=    1 when the order was a walk-in, pos= the bot's position.
local function TrackLastHitAttempt()
	local now = DotaTime()
	local lastLook = bot._lhLookAt or now
	bot._lhLookAt = now
	local attempt = bot._lhAttempt
	if attempt == nil then
		return
	end
	local creep = attempt.creep
	local dead = creep == nil or creep:IsNull() or not creep:IsAlive()
	-- The bot's first attack after the order, read while the creep lives (later reads could be the next creep).
	if attempt.deadAt == nil and attempt.launchAt == nil then
		local lastAttack = bot:GetLastAttackTime()
		if lastAttack ~= nil and lastAttack >= attempt.orderAt then
			attempt.launchAt = lastAttack
		end
	end
	if not dead then
		if now - attempt.at > 4 then
			bot._lhAttempt = nil
		end
		return
	end
	-- The counter can update a moment after the death.
	if attempt.deadAt == nil then
		-- Not looked at for a while (dead bot, skipped think): when the creep died is unknown, no line.
		if now - attempt.at > 4 or now - lastLook > 1 then
			bot._lhAttempt = nil
			return
		end
		attempt.deadAt = now
		attempt.gap = now - lastLook
	end
	if now - attempt.deadAt < 0.3 then
		return
	end
	bot._lhAttempt = nil
	local launch = attempt.launchAt ~= nil and attempt.launchAt - attempt.orderAt or -1
	local got = bot:GetLastHits() > attempt.lastHits
	pcall(LastHitTiming.NoteResult, bot, got, launch, attempt.early, attempt.cancels)
	pcall(
		print,
		string.format(
			"[OHA-LH] t=%.0f %s %s creep-hp=%d dmg=%d expect=%.2f took=%.2f launch=%.2f gap=%.2f walk=%d pos=%d kind=%s turn=%.2f early=%s cancels=%d",
			now,
			(string.gsub(bot:GetUnitName(), "npc_dota_hero_", "")),
			got and "got" or "missed",
			attempt.hp,
			attempt.damage,
			attempt.delay,
			attempt.deadAt - attempt.at,
			launch,
			attempt.gap or 0,
			attempt.walk and 1 or 0,
			Fu.GetPosition(bot),
			attempt.kind or "-",
			attempt.turn or 0,
			attempt.early and "yes" or "no",
			attempt.cancels or 0
		)
	)
end
-- The attack timing numbers the hit prediction uses (Fu.GetAttackProDelayTime), once per bot while it is mid-attack
-- on a last-hit creep (#71, game 050: does GetAnimCycle() run 0-1 or in seconds next to GetAttackPoint()?). In games
-- 059 and 062 the shortest expect= of melee heroes matches the game files' AttackAnimationPoint / attack speed
-- (Earth Spirit 0.35 -> 0.28, Meepo 0.38 -> 0.27), so GetAttackPoint() reads in seconds; the cycle is the open part.
local function ProbeAttackTiming(creep)
	if bot._lhProbeDone or bot:GetAttackTarget() ~= creep or bot:GetAnimActivity() ~= 1503 then
		return
	end
	bot._lhProbeDone = true
	local attackPoint = bot:GetAttackPoint()
	local attackSpeed = bot:GetAttackSpeed()
	pcall(
		print,
		string.format(
			"[OHA-LH] t=%.0f %s probe attackPoint=%.3f attackSpeed=%.3f secPerAttack=%.3f pointTime=%.3f cycle=%.3f sinceAttack=%.3f",
			DotaTime(),
			(string.gsub(bot:GetUnitName(), "npc_dota_hero_", "")),
			attackPoint,
			attackSpeed,
			bot:GetSecondsPerAttack(),
			attackPoint / math.max(0.01, attackSpeed),
			bot:GetAnimCycle(),
			GameTime() - bot:GetLastAttackTime()
		)
	)
end
-- An attack or walk-in order on a last-hit creep: arms the per-frame timing (LastHitTiming) and starts the attempt the
-- first time for this creep.
local function OrderLastHit(creep, walk)
	local pick = bot._lhPick
	local picked = pick ~= nil and pick.creep == creep
	LastHitTiming.Arm(bot, creep, {
		damage = picked and pick.damage or attackDamage - 3,
		allowEarly = picked and pick.allowEarly or false,
		walk = walk,
	})
	local attempt = bot._lhAttempt
	if attempt ~= nil and attempt.creep == creep then
		pcall(ProbeAttackTiming, creep)
		return
	end
	if not Fu.IsInLaningPhase() then
		return
	end
	bot._lhAttempt = {
		creep = creep,
		at = DotaTime(),
		orderAt = GameTime(),
		hp = creep:GetHealth(),
		damage = picked and pick.damage or attackDamage - 3,
		delay = picked and pick.delay or Fu.GetAttackProDelayTime(bot, creep),
		lastHits = bot:GetLastHits(),
		walk = walk,
		kind = picked and pick.kind or GetCreepKind(creep),
		turn = picked and pick.turn or 0,
		early = picked and pick.early or false,
		cancels = 0,
	}
end
function GetDesire()
	if ShouldSkipBotThink(GetBot()) then
		return 0
	end
	pcall(LogInEnemyTower)
	pcall(LogCreepScore)
	pcall(TrackLastHitAttempt)
	pcall(LastHitTiming.LogMinute, bot)
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
-- Early starts (#71, game 063): a support leaves last hits to a core near it, so it only starts early alone. Off for
-- a bot whose stop orders keep failing (LastHitTiming.EarlyAllowed, [OHA-LH] early-off).
local function AllowEarlyStart()
	return LastHitTiming.EarlyAllowed(bot) and (not IsSupportRole() or not Fu.IsThereNonSelfCoreNearby(1000))
end
-- The last-hit pick (#71). Every creep is classified for the moment our hit would land (turn, walk, wind-up, flight;
-- attacks in flight, creeps and towers mid-swing, our tower's next shot): "sure" (our hit kills it) or "early" (within
-- 1.5 of our hits: start the swing, LastHitTiming cancels it if the creep is not low enough at the attack point).
-- Among them: a sure kill beats an early one, then creep value less a walk-in penalty, then the hit that lands first
-- (LastHitRules.PickScore). Before: the first creep in list order with the highest of ranged 3 / flagbearer 2 / melee 1,
-- sure kills only.
function GetBestLastHitCreep(creeps)
	local damage = attackDamage - 3
	local bonus = bot._lastHitBonus or 0
	local allowEarly = AllowEarlyStart()
	local best = nil
	for _, creep in pairs(creeps) do
		if Fu.IsValid(creep) and Fu.CanBeAttacked(creep) then
			local attackDelay = Fu.GetAttackProDelayTime(bot, creep)
			local okT, towerShot = pcall(LastHitTiming.TowerShotBefore, bot, creep, attackDelay)
			towerShot = okT and towerShot or 0
			-- The tower shot lands first; our hit then needs to finish what's left, and the tower alone must not
			-- kill it (that gold is lost either way).
			local towerKills = towerShot > 0 and towerShot >= creep:GetHealth()
			if towerShot > 0 and not towerKills and DotaTime() >= (bot._lhTowerLogAt or -999) then
				bot._lhTowerLogAt = DotaTime() + 10
				pcall(
					print,
					string.format(
						"[OHA-LANE] t=%.0f %s lh-tower creep-hp=%d tower=%d hit=%d delay=%.2f",
						DotaTime(),
						(string.gsub(bot:GetUnitName(), "npc_dota_hero_", "")),
						creep:GetHealth(),
						math.floor(towerShot),
						damage,
						attackDelay
					)
				)
			end
			local predictedHp, ourHit, incomingKills = LastHitTiming.Predict(creep, damage, attackDelay, towerShot)
			local class = LastHitRules.Classify(predictedHp, ourHit, incomingKills, allowEarly)
			local hitDamage = damage
			if class ~= "sure" and bonus > 0 then
				-- Clinkz's Searing Arrows (#48): a hit that only kills with the bonus.
				local _, bonusHit = LastHitTiming.Predict(creep, damage + bonus, attackDelay, towerShot)
				if LastHitRules.Classify(predictedHp, bonusHit, incomingKills, false) == "sure" then
					class, hitDamage = "sure", damage + bonus
				end
			end
			if class ~= nil then
				local kind = GetCreepKind(creep)
				local walk = GetUnitToUnitDistance(bot, creep) > attackRange
				local score = LastHitRules.PickScore(kind, class == "sure", walk)
				if best == nil or LastHitRules.BetterPick(score, attackDelay, best.score, best.delay) then
					best = {
						creep = creep,
						damage = hitDamage,
						bonus = hitDamage > damage,
						delay = attackDelay,
						score = score,
						kind = kind,
						early = class == "early",
						turn = Fu.GetTurnTime(bot, creep),
						allowEarly = allowEarly,
					}
				end
			end
		end
	end
	if best ~= nil and best.bonus then
		bot._lastHitNeedsBonus = { creep = best.creep, at = DotaTime() }
	end
	-- The pick only: the attempt for [OHA-LH] starts when Think orders the hit (OrderLastHit).
	bot._lhPick = best
	return best ~= nil and best.creep or nil
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
			-- Same order as last hits (#71): a denied flagbearer gives the enemy none of its area gold.
			local value = LastHitRules.KIND_VALUE[GetCreepKind(creep)]
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
-- noreset= (#71, games 059 / 062): on a creep-aggro skip, the gate that also stopped the harass-and-reset.
local function LogHarass(enemyHero, target, why, fresh, hitting, noReset)
	if DotaTime() < (bot._harassLogAt or -999) then
		return
	end
	bot._harassLogAt = DotaTime() + 5
	pcall(
		print,
		string.format(
			"[OHA-HARASS] t=%.0f %s %s target=%s why=%s hp=%.2f fresh=%d hitting=%d range=%d dist=%d noreset=%s",
			DotaTime(),
			(string.gsub(bot:GetUnitName(), "npc_dota_hero_", "")),
			target ~= nil and "hit" or "skip",
			(string.gsub(enemyHero:GetUnitName(), "npc_dota_hero_", "")),
			why or "-",
			Fu.GetHP(bot),
			fresh,
			hitting,
			attackRange,
			GetUnitToUnitDistance(bot, enemyHero),
			noReset or "-"
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
	local valuable = GetCreepKind(creep) ~= "melee"
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
		pcall(TrackLastHitAttempt)
		-- A last-hit timing this think does not re-arm is dropped (LastHitTiming.Tick, next frame at the latest).
		LastHitTiming.BeginThink(bot)
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
					-- Not from inside an enemy tower's range (#71, game 044 4:20: Puck walked under Radiant's bottom
					-- T1 for a last hit). Supports never; cores only above 50% HP with 2+ of our lane creeps in that
					-- range to hold the tower.
					local tower = enemyTowers[1]
					if why == nil and Fu.IsValidBuilding(tower) and tower:IsAlive() then
						local towerReach = (tower:GetAttackRange() or 700) + 150
						if GetUnitToLocationDistance(tower, spot) <= towerReach then
							local holders = 0
							for _, creep in pairs(allyLaneCreeps or {}) do
								if Fu.IsValid(creep) and GetUnitToUnitDistance(creep, tower) <= towerReach then
									holders = holders + 1
								end
							end
							if bSupport or Fu.GetHP(bot) <= 0.5 or holders < 2 then
								why, harasser = "tower", tower
							end
						end
					end
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
				-- The per-frame timing owns this hit (a wind-up being watched, holding after a cancel, or an attack it
				-- ordered): keep it armed and give no order that would replace it.
				if LastHitTiming.Holding(bot, lastHitCreep) then
					OrderLastHit(lastHitCreep, false)
					return
				end
				local pick = bot._lhPick
				local early = pick ~= nil and pick.creep == lastHitCreep and pick.early
				if creepDistance > attackRange then
					local attackDistance = attackRange - lastHitCreep:GetBoundingRadius()
					local moveLocation =
						Fu.GetXUnitsTowardsLocation2(lastHitCreep:GetLocation(), bot:GetLocation(), attackDistance)
					OrderLastHit(lastHitCreep, true)
					bot:Action_MoveDirectly(moveLocation)
					return
				elseif
					early
					and not LastHitRules.CanTimeWindup(
						bot:GetAttackPoint() / math.max(0.1, bot:GetAttackSpeed()),
						LastHitTiming.FrameGap(bot)
					)
				then
					-- Too few frames inside this hero's wind-up to check it: no early swing, the per-frame timing
					-- attacks when the hit is sure.
					OrderLastHit(lastHitCreep, true)
					return
				else
					OrderLastHit(lastHitCreep, false)
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
		do
			local reset = bot._harassReset
			if reset ~= nil then
				if DotaTime() > reset.untilTime or not Fu.IsValidHero(reset.target) then
					bot._harassReset = nil
				elseif bot:GetLastAttackTime() >= reset.at or GameTime() - reset.at > 1 then
					bot:Action_MoveToLocation(Fu.AdjustLocationWithOffsetTowardsFountain(bot:GetLocation(), 350))
					return
				else
					bot:Action_AttackUnit(reset.target, true)
					return
				end
			end
		end
		-- Tower punish (#71, maintainer game 047: enemy heroes walked behind our tower and nobody hit them). An enemy hero
		-- inside our tower's range is a free target above 40% HP: the tower hits him and takes the creep aggro.
		do
			local ourTower = GetLaneT1(GetTeam(), botLane)
			for _, tower in pairs(bot:GetNearbyTowers(1200, false) or {}) do
				if Fu.IsValidBuilding(tower) then
					ourTower = tower
					break
				end
			end
			if Fu.IsValidBuilding(ourTower) and ourTower:IsAlive() and Fu.GetHP(bot) > 0.4 then
				local reach = (ourTower:GetAttackRange() or 700) - 50
				for _, enemyHero in pairs(nearbyEnemies) do
					if
						Fu.IsValidHero(enemyHero)
						and not Fu.IsSuspiciousIllusion(enemyHero)
						and Fu.CanBeAttacked(enemyHero)
						and GetUnitToUnitDistance(enemyHero, ourTower) <= reach
						and GetUnitToUnitDistance(bot, enemyHero) <= attackRange + 400
					then
						if DotaTime() >= (bot._towerPunishLogAt or -999) then
							bot._towerPunishLogAt = DotaTime() + 5
							pcall(
								print,
								string.format(
									"[OHA-LANE] t=%.0f %s tower-punish target=%s towerOn=%s hp=%.2f",
									DotaTime(),
									(string.gsub(bot:GetUnitName(), "npc_dota_hero_", "")),
									(string.gsub(enemyHero:GetUnitName(), "npc_dota_hero_", "")),
									tostring(ourTower:GetAttackTarget() == enemyHero),
									Fu.GetHP(bot)
								)
							)
						end
						bot:Action_AttackUnit(enemyHero, true)
						return
					end
				end
			end
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
				-- Harass and reset (#71): game 044 skipped 19 of 26 harass chances for creep aggro. A ranged bot over
				-- 60% HP with at most 2 fresh creeps near still takes one hit, then steps back toward its fountain
				-- for 1.2s so the creeps that turned on it lose it (the usual "hit and step back"). Every ranged hero
				-- now (LaneHarassRules.ResetBlock), not only range 400+: game 059's Zeus skipped it twice.
				local noReset = nil
				if target == nil and why == "creep-aggro" then
					noReset = LaneHarassRules.ResetBlock(
						attackRange,
						Fu.GetHP(bot),
						fresh,
						hitting,
						SafeToHarassHero(inRange),
						DotaTime() >= (bot._harassResetNextAt or -999)
					)
					if noReset == nil then
						target = inRange
						why = "reset"
						bot._harassReset = { target = inRange, at = GameTime(), untilTime = DotaTime() + 2.5 }
						bot._harassResetNextAt = DotaTime() + 6
					end
				end
				LogHarass(inRange, target, why, fresh, hitting, noReset)
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
