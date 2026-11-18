-- Hero-specific helper: special units.
local X = {}
local bot
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
function X.GetDesire(thinkingBot)
	-- bot was set after these four reads, so they described the previous caller (nil at first).
	bot = thinkingBot
	local hpRatio = Fu.GetHP(bot)
	local isRetreating = Fu.IsRetreating(bot)
	local isRealInvisible = Fu.IsRealInvisible(bot)
	local isGoingOnSomeone = Fu.IsGoingOnSomeone(bot)
	if Fu.CanNotUseAction(bot) or bot:IsDisarmed() then
		return 0
	end
	bot.special_unit_target = nil
	local health = bot:GetHealth()
	local botHpRatio = hpRatio
	local botLocation = bot:GetLocation()
	local attackRange = bot:GetAttackRange()
	local alliesNearLoc = Fu.GetAlliesNearLoc(bot:GetLocation(), 1600)
	local enemiesNearLoc = Fu.GetEnemiesNearLoc(bot:GetLocation(), 1600)
	local nearbyAllies = bot:GetNearbyHeroes(1600, false, BOT_MODE_NONE)
	local nearbyEnemies = bot:GetNearbyHeroes(1600, true, BOT_MODE_NONE)
	local botTarget = Fu.GetProperTarget(bot)
	local botName = bot:GetUnitName()
	-- Escape Shadow Shaman serpent ward traps (self or ally) before other specials.
	-- Below teamfight priority; above creeps when no enemy hero is nearby.
	do
		local snakeDesire, snakeTarget = X.GetSerpentWardEscapeDesire(bot, attackRange, nearbyEnemies)
		if snakeDesire > 0 and Fu.IsValid(snakeTarget) then
			bot.special_unit_target = snakeTarget
			return snakeDesire
		end
	end
	-- Deward: revealed enemy obs/sentry under ally true sight.
	do
		local wardDesire, wardTarget = X.GetDewardDesire(bot, attackRange, enemiesNearLoc)
		if wardDesire > 0 and Fu.IsValid(wardTarget) then
			bot.special_unit_target = wardTarget
			return wardDesire
		end
	end
	for _, unit in pairs(GetUnitList(UNIT_LIST_ENEMIES)) do
		if Fu.IsValid(unit) and Fu.CanBeAttacked(unit) and Fu.IsInRange(bot, unit, 1600) then
			bot.special_unit_target = unit
			local unitName = unit:GetUnitName()
			local botDamage = X.GetUnitAttackDamageWithinTime(bot, 8.0)
			local unitHpRatio = Fu.GetHP(unit)
			local unitLocation = unit:GetLocation()
			local isInAttackRange = GetUnitToUnitDistance(bot, unit) <= attackRange
			if string.find(unitName, "rattletrap_cog") then
				if string.find(botName, "rattletrap") and isInAttackRange then
					if isGoingOnSomeone then
						if
							Fu.IsValidHero(botTarget)
							and Fu.CanCastOnNonMagicImmune(botTarget)
							and Fu.IsInRange(bot, botTarget, 800)
							and not Fu.IsInRange(bot, botTarget, 400)
							and not (Fu.IsInRange(bot, botTarget, 800) and Fu.IsChasingTarget(bot, botTarget))
						then
							local lineDistance = PointToLineDistance(botLocation, botTarget:GetLocation(), unitLocation)
							if lineDistance ~= nil and lineDistance.within and lineDistance.distance <= 185 then
								return 2
							end
						end
					end
					if isRetreating and isRealInvisible then
						for _, enemyHero in pairs(enemiesNearLoc) do
							if
								Fu.IsValidHero(enemyHero)
								and Fu.IsInRange(bot, enemyHero, 800)
								and not Fu.IsInRange(bot, botTarget, 400)
								and Fu.IsChasingTarget(enemyHero, bot)
							then
								local lineDistance =
									PointToLineDistance(botLocation, botTarget:GetLocation(), unitLocation)
								if lineDistance ~= nil and lineDistance.within and lineDistance.distance <= 185 then
									return 2
								end
							end
						end
					end
				else
					local cogsNearby = Fu.GetPowerCogsCountInLoc(botLocation, 1000)
					local cogsInRing = Fu.GetPowerCogsCountInLoc(botLocation, 216)
					if #nearbyEnemies >= 1 then
						local closeEnemies = Fu.GetEnemiesNearLoc(botLocation, 800)
						if cogsNearby == 8 and cogsInRing >= 4 and isInAttackRange then
							if
								#closeEnemies == 0
								or isGoingOnSomeone
								or isRetreating and not isRealInvisible and #closeEnemies >= 1
								or #alliesNearLoc < #enemiesNearLoc
							then
								return 0.95
							else
								return 0.55
							end
						end
					end
					if #enemiesNearLoc == 0 then
						if cogsNearby == 8 and cogsInRing >= 4 and isInAttackRange then
							return 0.90
						else
							if
								bot:GetTeam() ~= unit:GetTeam()
								and Fu.IsInRange(bot, unit, attackRange + 350)
								and not Fu.IsInLaningPhase()
							then
								return 0.75
							else
								return 0.50
							end
						end
					end
				end
			end
			if bot:GetTeam() ~= unit:GetTeam() then
				if
					string.find(unitName, "juggernaut_healing_ward")
					or string.find(unitName, "roshans_banner")
					or string.find(unitName, "land_mine")
					or string.find(unitName, "ignis_fatuus")
				then
					if Fu.IsInRange(bot, unit, attackRange) then
						return 1
					end
					if Fu.IsInRange(bot, unit, attackRange + 200) then
						return RemapValClamped(hpRatio, 0.1, 0.9, 0, 0.96)
					end
					if #nearbyEnemies == 0 then
						return RemapValClamped(hpRatio, 0.2, 0.9, 0, 0.9)
					end
					if #alliesNearLoc >= #enemiesNearLoc then
						return RemapValClamped(hpRatio, 0.2, 0.9, 0, 0.7)
					end
				end
				if string.find(unitName, "siege") then
					if #nearbyEnemies == 0 and Fu.GetDistanceFromAncient(bot, false) < 3000 then
						return 0.5
					end
				end
				if
					string.find(unitName, "shadow_shaman_ward")
					or string.find(unitName, "invoker_forged_spirit")
					or string.find(unitName, "venomancer_plague_ward")
					or string.find(unitName, "clinkz_skeleton_archer")
				then
					if hpRatio > 0.7 and Fu.IsInRange(bot, unit, attackRange) then
						if #enemiesNearLoc == 0 then
							return RemapValClamped(hpRatio, 0.3, 0.9, 0, 0.75)
						end
						if #alliesNearLoc >= #enemiesNearLoc then
							return 0.4
						end
					end
					if hpRatio < 0.7 and Fu.IsStuck(bot) then
						return RemapValClamped(hpRatio, 0.2, 0.8, 0.7, 0.3)
					end
					local attackingUnits = X.GetUnitTypeAttackingBot(botLocation, 1600, unitName)
					local unitsDamage = X.GetTotalAttackDamage(attackingUnits, 8.0)
					botDamage = X.GetUnitAttackDamageWithinTime(bot, 5.0)
					if not Fu.IsInTeamFight(bot, 900) and not (isRetreating and isRealInvisible) then
						if
							unitsDamage < health
							or Fu.IsInRange(bot, unit, attackRange)
								and not Fu.IsInRange(bot, unit, unit:GetAttackRange())
						then
							return 0.31
						end
					end
				end
				if string.find(unitName, "pugna_nether_ward") then
					if Fu.IsInRange(bot, unit, attackRange + 150) then
						if
							isGoingOnSomeone
								and Fu.IsValidHero(botTarget)
								and Fu.IsInRange(bot, botTarget, attackRange - 130)
								and Fu.GetHP(botTarget) < 0.5
							or X.IsBeingAttackedByHero(bot) and botHpRatio < 0.5
						then
							return 0.35
						else
							if not X.IsBeingAttackedByHero(bot) then
								return 0.60
							end
						end
					else
						return 0.35
					end
				end
				if
					string.find(unitName, "grimstroke_ink_creature")
					or string.find(unitName, "weaver_swarm")
					or string.find(unitName, "tidehunter_anchor")
				then
					if #enemiesNearLoc == 0 then
						return 0.9
					end
					if
						isGoingOnSomeone
							and Fu.IsValidHero(botTarget)
							and Fu.IsInRange(bot, botTarget, attackRange - 130)
							and Fu.GetHP(botTarget) < 0.5
						or X.IsBeingAttackedByHero(bot) and botHpRatio < 0.5
					then
						return 0.35
					end
					if not X.IsHeroWithinRadius(enemiesNearLoc, attackRange - 130) then
						return 0.96
					end
					if not X.IsBeingAttackedByHero(bot) then
						return 0.8
					else
					end
				end
				if string.find(unitName, "gyrocopter_homing_missile") then
					if
						not Fu.IsInTeamFight(bot, 900)
						and isInAttackRange
						and not (isRetreating and isRealInvisible)
					then
						if not Fu.IsRunning(unit) or not Fu.IsInRange(bot, unit, 250) then
							return 0.9
						end
					end
				end
				if string.find(unitName, "zeus_cloud") then
					if #alliesNearLoc >= #enemiesNearLoc or #nearbyEnemies == 0 then
						if isInAttackRange then
							return 0.7
						end
						return RemapValClamped(hpRatio, 0.3, 0.9, 0, 0.65)
					end
				end
				if string.find(unitName, "lone_druid_bear") or string.find(unitName, "npc_dota_brewmaster") then
					if #alliesNearLoc >= 2 and #nearbyAllies > #nearbyEnemies then
						return 0.45
					end
					if not X.IsUnitAfterUnit(unit, bot) then
						return BOT_ACTION_DESIRE_HIGH
					end
					if unitHpRatio < 0.25 then
						if X.IsUnitAfterUnit(unit, bot) then
							return RemapValClamped(botHpRatio, 0.25, 0.9, 0.2, 0.9)
						else
							return 0.45
						end
					end
				end
				if
					unit:HasModifier("modifier_dominated")
					or unit:HasModifier("modifier_chen_holy_persuasion")
					or string.find(unitName, "visage_familiar")
				then
					local unitDamage = X.GetUnitAttackDamageWithinTime(unit, 5.5)
					botDamage = X.GetUnitAttackDamageWithinTime(bot, 5.0)
					if
						not Fu.IsInTeamFight(bot, 1200)
						and not (isRetreating and not isRealInvisible)
						and isInAttackRange
						and botDamage > unitHpRatio
						and unitDamage < health
					then
						return 0.5
					end
				end
				if
					string.find(unitName, "lycan_wolf")
					or string.find(unitName, "eidolon")
					or string.find(unitName, "beastmaster_boar")
					or string.find(unitName, "beastmaster_greater_boar")
					or string.find(unitName, "furion_treant")
					or string.find(unitName, "broodmother_spiderling")
					or string.find(unitName, "skeleton_warrior")
				then
					local attackingUnits = X.GetUnitTypeAttackingBot(botLocation, 1600, unitName)
					local unitsDamage = X.GetTotalAttackDamage(attackingUnits, 4.0)
					local unitsHealth = X.GetTotalUnitHealth(attackingUnits)
					botDamage = X.GetUnitAttackDamageWithinTime(bot, 4.0)
					if
						not Fu.IsInTeamFight(bot, 1200)
						and isInAttackRange
						and botDamage > unitsHealth
						and unitsDamage < health
					then
						return RemapValClamped(botHpRatio, 0.25, 0.9, 0.2, 0.5)
					end
				end
				if string.find(unitName, "observer_wards") or string.find(unitName, "sentry_wards") then
					-- Handled earlier via GetDewardDesire; keep a fallback.
					if X.HasTrueSightNear(unit:GetLocation()) then
						if not X.IsBeingAttackedByHero(bot) or #enemiesNearLoc <= 1 then
							if Fu.IsInRange(bot, unit, attackRange + 200) then
								return 1.15
							end
							return 0.95
						end
					end
				end
				if string.find(unitName, "phoenix_sun") then
					if
						(#alliesNearLoc >= #enemiesNearLoc or Fu.WeAreStronger(bot, 1600))
						and not bot:HasModifier("modifier_phoenix_fire_spirit_burn")
						and not isRetreating
					then
						local alliesNearUnit = Fu.GetAlliesNearLoc(unit:GetLocation(), 900)
						if Fu.IsInRange(bot, unit, attackRange + 200) and #alliesNearUnit >= 2 then
							return 1.2
						end
						if Fu.IsInRange(bot, unit, attackRange + 300) and #alliesNearUnit >= 2 then
							return 1.1
						end
						if Fu.IsInRange(bot, unit, attackRange + 400) then
							return RemapValClamped(hpRatio, 0.2, 0.9, 0.4, 0.97)
						end
						return RemapValClamped(hpRatio, 0.2, 0.9, 0, 0.9)
					end
				end
				if string.find(unitName, "tombstone") then
					if #nearbyAllies >= #nearbyEnemies and not isRetreating then
						if Fu.IsInRange(bot, unit, attackRange + 200) then
							return RemapValClamped(hpRatio, 0.25, 0.9, 0.4, 0.96)
						end
						return 0.56
					end
				end
				if string.find(unitName, "undying_zombie") then
					if #nearbyAllies >= #nearbyEnemies and not isRetreating then
						if isInAttackRange then
							return 0.6
						end
						return 0.25
					end
				end
				if string.find(unitName, "warlock_golem") then
					botDamage = X.GetUnitAttackDamageWithinTime(bot, 5)
					local unitDamage = X.GetUnitAttackDamageWithinTime(unit, 5)
					if not Fu.IsInTeamFight(bot, 1600) and #nearbyAllies >= #nearbyEnemies then
						local canWinTrade = botDamage > unitHpRatio and unitDamage * 1.2 < botHpRatio
						if Fu.IsInRange(bot, unit, attackRange + 300) then
							if not X.IsUnitAfterUnit(unit, bot) or X.IsUnitAfterUnit(unit, bot) and canWinTrade then
								return 0.35
							else
								return 0.25
							end
						else
							if not X.IsUnitAfterUnit(unit, bot) or X.IsUnitAfterUnit(unit, bot) and canWinTrade then
								return 0.25
							end
						end
					end
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.Think(unit)
	local thinkingUnit = unit or bot
	if thinkingUnit == nil or Fu.CanNotUseAction(thinkingUnit) then
		return
	end
	local target = thinkingUnit.special_unit_target
	if Fu.IsValid(target) and not thinkingUnit:IsDisarmed() then
		thinkingUnit:Action_AttackUnit(target, true)
		return
	end
end
function X.IsUnitAfterUnit(unit, target)
	return unit:GetAttackTarget() == target or Fu.IsChasingTarget(unit, target)
end
function X.GetTotalAttackDamage(units, duration)
	local totalDamage = 0
	for _, unit in pairs(units) do
		if Fu.IsValid(unit) then
			totalDamage = totalDamage + unit:GetAttackDamage() * unit:GetAttackSpeed() * duration
		end
	end
	return totalDamage
end
function X.GetUnitTypeAttackingBot(location, radius, unitName)
	local matchingUnits = {}
	for _, unit in pairs(GetUnitList(UNIT_LIST_ENEMIES)) do
		if
			Fu.IsValid(unit)
			and unit:GetUnitName() == unitName
			and GetUnitToLocationDistance(unit, location) <= radius
			and (unit:GetAttackTarget() == bot or Fu.IsChasingTarget(unit, bot))
		then
			table.insert(matchingUnits, unit)
		end
	end
	return matchingUnits
end
function X.GetUnitAttackDamageWithinTime(unit, duration)
	return unit:GetAttackDamage() * unit:GetAttackSpeed() * duration
end
function X.GetTotalUnitHealth(units)
	local totalHealth = 0
	for i = 1, #units do
		totalHealth = totalHealth + units[i]:GetHealth()
	end
	return totalHealth
end
function X.IsBeingAttackedByHero(unit)
	for _, enemyHero in pairs(GetUnitList(UNIT_LIST_ENEMIES)) do
		if Fu.IsValidHero(enemyHero) and enemyHero:GetAttackTarget() == unit then
			return true
		end
	end
	return false
end
function X.IsHeroWithinRadius(heroes, radius)
	if Fu.IsValidHero(heroes[1]) and Fu.IsInRange(bot, heroes[1], radius) then
		return true
	end
	return false
end
-- Ally sentry / tower true sight radius (~925); use 1000 to match site.lua.
local TRUE_SIGHT_RADIUS = 1000

function X.IsThereSentry(loc)
	return X.HasTrueSightNear(loc)
end

function X.HasTrueSightNear(loc)
	local alliedWards = GetUnitList(UNIT_LIST_ALLIED_WARDS)
	for _, ward in pairs(alliedWards) do
		if
			ward ~= nil
			and ward:GetUnitName() == "npc_dota_sentry_wards"
			and GetUnitToLocationDistance(ward, loc) <= TRUE_SIGHT_RADIUS
		then
			return true
		end
	end
	local bot = GetBot()
	if bot ~= nil then
		local towers = bot:GetNearbyTowers(1600, false)
		for _, tower in ipairs(towers) do
			if GetUnitToLocationDistance(tower, loc) <= TRUE_SIGHT_RADIUS then
				return true
			end
		end
		-- Gem carriers grant true sight.
		local allies = GetUnitList(UNIT_LIST_ALLIED_HEROES)
		for _, ally in pairs(allies) do
			if Fu.IsValidHero(ally) and GetUnitToLocationDistance(ally, loc) <= TRUE_SIGHT_RADIUS then
				local gem = ally:FindItemSlot("item_gem")
				if gem >= 0 and gem <= 5 then
					return true
				end
			end
		end
	end
	return false
end

function X.IsEnemyWard(unit)
	if not Fu.IsValid(unit) then
		return false
	end
	local name = unit:GetUnitName()
	return string.find(name, "observer_wards") ~= nil or string.find(name, "sentry_wards") ~= nil
end

function X.IsSerpentWard(unit)
	if not Fu.IsValid(unit) then
		return false
	end
	return string.find(unit:GetUnitName(), "shadow_shaman_ward") ~= nil
end

function X.GetEnemySerpentWardsNear(loc, radius)
	local wards = {}
	for _, unit in pairs(GetUnitList(UNIT_LIST_ENEMIES)) do
		if X.IsSerpentWard(unit) and Fu.CanBeAttacked(unit) and GetUnitToLocationDistance(unit, loc) <= radius then
			wards[#wards + 1] = unit
		end
	end
	return wards
end

function X.IsHeroTrappedBySerpentWards(hero)
	if not Fu.IsValidHero(hero) or not hero:IsAlive() then
		return false, nil
	end
	local wards = X.GetEnemySerpentWardsNear(hero:GetLocation(), 420)
	local wardCount = #wards
	if wardCount <= 0 then
		return false, nil
	end
	local beingHit = false
	for _, ward in pairs(wards) do
		if ward:GetAttackTarget() == hero then
			beingHit = true
			break
		end
	end
	-- Mass Serpent Ward rings trap a hero; open a gap by killing one.
	if wardCount >= 3 or (wardCount >= 2 and (Fu.IsStuck(hero) or beingHit)) then
		return true, wards
	end
	return false, wards
end

-- The ward standing between the trapped hero and safety. Killing any other one
-- keeps the ring closed and the hero dies inside it.
function X.GetExitSerpentWard(wards, trapped)
	if wards == nil or trapped == nil then
		return nil
	end
	local from = trapped:GetLocation()
	local dest = Fu.GetTeamFountain()
	local best, bestLine = nil, 99999
	for _, ward in pairs(wards) do
		if Fu.IsValid(ward) and Fu.CanBeAttacked(ward) then
			local line = PointToLineDistance(from, dest, ward:GetLocation())
			local off = (line ~= nil and line.within) and line.distance or 99999
			if off < bestLine then
				bestLine = off
				best = ward
			end
		end
	end
	return best
end

function X.GetBestSerpentWardToKill(wards, bot, attackRange, trapped)
	local exitWard = X.GetExitSerpentWard(wards, trapped or bot)
	if exitWard ~= nil then
		return exitWard
	end
	if wards == nil or bot == nil then
		return nil
	end
	local best = nil
	local bestScore = -1
	local reach = (attackRange or bot:GetAttackRange()) + 450
	for _, ward in pairs(wards) do
		if Fu.IsValid(ward) and Fu.CanBeAttacked(ward) then
			local dist = GetUnitToUnitDistance(bot, ward)
			if dist <= math.max(reach, 900) then
				-- Prefer low HP and already in attack range so we open a gap fast.
				local inRangeBonus = dist <= (attackRange or bot:GetAttackRange()) + 50 and 200 or 0
				local score = inRangeBonus + (1200 - math.min(dist, 1200)) + (500 - math.min(ward:GetHealth(), 500))
				if score > bestScore then
					bestScore = score
					best = ward
				end
			end
		end
	end
	return best
end

function X.GetSerpentWardEscapeDesire(bot, attackRange, nearbyEnemyHeroes)
	if bot == nil or Fu.CanNotUseAction(bot) or bot:IsDisarmed() then
		return 0, nil
	end
	-- Team fights come first for an ally's trap. A bot trapped itself escapes even in a fight (game 034,
	-- 11:30: Axe in a Mass Serpent Ward ring during a fight killed some snakes, never left, died;
	-- datafeed: 10 wards, spawn radius 150, 2 hits each, 45s).
	local inFight = Fu.IsInTeamFight(bot, 1200)
	if inFight and not X.IsHeroTrappedBySerpentWards(bot) then
		return 0, nil
	end

	local enemyHeroCount = 0
	for _, hero in pairs(nearbyEnemyHeroes or {}) do
		if Fu.IsValidHero(hero) and not Fu.IsSuspiciousIllusion(hero) then
			enemyHeroCount = enemyHeroCount + 1
		end
	end

	local trapWards = nil
	local trapped = nil
	local selfTrapped, selfWards = X.IsHeroTrappedBySerpentWards(bot)
	if selfTrapped then
		trapWards = selfWards
		trapped = bot
	else
		for i = 1, #GetTeamPlayers(GetTeam()) do
			local ally = GetTeamMember(i)
			if
				ally ~= nil
				and ally ~= bot
				and ally:IsAlive()
				and not ally:IsIllusion()
				and GetUnitToUnitDistance(bot, ally) <= 1800
			then
				local allyTrapped, allyWards = X.IsHeroTrappedBySerpentWards(ally)
				if allyTrapped then
					trapWards = allyWards
					trapped = ally
					break
				end
			end
		end
	end

	if trapWards == nil then
		return 0, nil
	end

	local target = X.GetBestSerpentWardToKill(trapWards, bot, attackRange, trapped)
	if target == nil then
		return 0, nil
	end
	-- Remember the snake opening our own way out: when it dies, the item think walks the bot out
	-- through the gap (Usage.WalkOutOfSnakes in ability_item_usage_generic.lua).
	if trapped == bot then
		bot._snakeExitWard = target
		bot._snakeExitWardLoc = target:GetLocation()
		bot._snakeExitWardAt = DotaTime()
		if inFight then
			return 1.05, target
		end
	end

	-- No enemy heroes: kill a snake over creeps / farm.
	if enemyHeroCount == 0 then
		return 1.15, target
	end
	-- Enemy heroes around but not a teamfight: still open an escape if we can hit soon.
	if GetUnitToUnitDistance(bot, target) <= (attackRange or bot:GetAttackRange()) + 200 then
		return 0.98, target
	end
	if selfTrapped then
		return 0.96, target
	end
	-- Ally trap, need a short walk — still above creep clearing, below hard commits.
	return 0.95, target
end

function X.GetDewardDesire(bot, attackRange, nearbyEnemies)
	if bot == nil or Fu.CanNotUseAction(bot) or bot:IsDisarmed() then
		return 0, nil
	end
	local best = nil
	local bestDist = 99999
	local searchRange = math.max(1600, attackRange + 400)

	local function consider(unit)
		if not Fu.IsValid(unit) or not Fu.CanBeAttacked(unit) then
			return
		end
		if not X.IsEnemyWard(unit) then
			return
		end
		if bot:GetTeam() == unit:GetTeam() then
			return
		end
		local dist = GetUnitToUnitDistance(bot, unit)
		if dist > searchRange then
			return
		end
		-- Already visible/attackable wards are fair game; also accept true-sight coverage.
		if not unit:CanBeSeen() and not X.HasTrueSightNear(unit:GetLocation()) then
			return
		end
		if dist < bestDist then
			bestDist = dist
			best = unit
		end
	end

	for _, unit in pairs(GetUnitList(UNIT_LIST_ENEMY_WARDS)) do
		consider(unit)
	end
	-- Some builds only surface revealed wards on UNIT_LIST_ENEMIES.
	if best == nil then
		for _, unit in pairs(GetUnitList(UNIT_LIST_ENEMIES)) do
			consider(unit)
		end
	end

	if best == nil then
		return 0, nil
	end

	local underFire = X.IsBeingAttackedByHero(bot) and #(nearbyEnemies or {}) > 1
	if underFire and bestDist > attackRange + 150 then
		return 0, nil
	end

	-- Game 036, 35:11-35:22: three of four Radiant deaths were hitting a ward at 1.10 with 5-33% HP
	-- and 5 enemies around (1.10-1.25 beats retreat and attack). Below 50% HP with 2+ enemy heroes
	-- near, or hit by a hero in the last 2s: leave the ward. Any enemy hero within 1200: at most
	-- 0.9, under attack (0.95) and the hard retreat (0.98).
	local hp = Fu.GetHP(bot)
	local foes = Fu.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE) or {}
	local function DewardLog(what, desire)
		if DotaTime() >= (bot._dewardLogAt or -999) then
			bot._dewardLogAt = DotaTime() + 5
			pcall(
				print,
				string.format(
					"[OHA-DEWARD] t=%.0f %s %s desire=%.2f hp=%.2f foes=%d dist=%d",
					DotaTime(),
					(string.gsub(bot:GetUnitName(), "npc_dota_hero_", "")),
					what,
					desire,
					hp,
					#foes,
					bestDist
				)
			)
		end
	end
	if hp < 0.5 and (#foes >= 2 or bot:WasRecentlyDamagedByAnyHero(2.0)) then
		DewardLog("skip-low-hp", 0)
		return 0, nil
	end
	-- Game 037, t=1834: Lion hit a ward at the 0.90 cap with 92% HP and 4 enemy heroes near and
	-- died; 0.90 beat retreat (0.70 at that HP). 3+ enemy heroes within 1200, or more of them
	-- than us (this bot counted): leave the ward. A cap just under retreat would not do it,
	-- since the hard retreat only applies while attack/roam is the active mode.
	if #foes >= 1 then
		local alliesNear = #(Fu.GetAlliesNearLoc(bot:GetLocation(), 1200) or {})
		if #foes >= 3 or #foes > alliesNear then
			DewardLog("skip-outnumbered allies=" .. alliesNear, 0)
			return 0, nil
		end
	end
	local desire = 0.95
	if bestDist <= attackRange + 50 then
		desire = 1.25
	elseif bestDist <= attackRange + 350 then
		desire = 1.1
	end
	-- Any other enemy hero near: 0.6, under retreat's 0.70 even with the engine's ~10% bonus for
	-- the active mode (an active 0.65 reads 0.71 in the log).
	if #foes >= 1 and desire > 0.6 then
		desire = 0.6
		DewardLog("capped-enemies-near", desire)
	end
	return desire, best
end
-- Kiting (test, user request 2026-11-17; revert if it costs damage): a ranged bot fighting a melee
-- hero steps away between attacks instead of standing still. Only inside a window that cannot
-- cancel an attack: it is not known whether GetLastAttackTime is the start of the attack or the
-- moment it is released, so the window assumes the worst of both:
--   from  last + point + BUF        (wind-up surely over even if "last" is the start)
--   until last + spa - point - BUF  (next wind-up can start even if "last" is the release)
-- point = GetAttackPoint / GetAttackSpeed as in combat.lua GetAttackProDelayTime, at least 0.25s.
-- Shared: the override attack mode calls it, and X.TryKiteInAttack is the hook for heroes on
-- Valve's attack mode (game 037: it lived only in the override, so only Hoodwink ever kited).
local KITE_BUF = 0.1
-- Result of the kiting (#72): it fires, but does it help? After each step, once the melee hero's next attack could
-- have landed (his seconds per attack, or ours if longer, + 0.1s), check whether he hit us and whether our own
-- attack came after the step. One line per bot per 60s when it kited.
local function KiteStats(unit)
	unit._kiteStats = unit._kiteStats or { steps = 0, hitAfter = 0, late = 0, since = DotaTime() }
	return unit._kiteStats
end
function X.KiteResultTick(unit)
	local pending = unit._kitePending
	if pending ~= nil and GameTime() >= pending.checkAt then
		unit._kitePending = nil
		local stats = KiteStats(unit)
		if Fu.IsValidHero(pending.enemy) and unit:WasRecentlyDamagedByHero(pending.enemy, pending.window) then
			stats.hitAfter = stats.hitAfter + 1
		end
		if unit:GetLastAttackTime() < pending.at then
			stats.late = stats.late + 1
		end
	end
	local stats = unit._kiteStats
	if stats ~= nil and stats.steps > 0 and DotaTime() - stats.since >= 60 then
		pcall(
			print,
			string.format(
				"[OHA-KITE] t=%.0f %s result steps=%d hit-after=%d late-attack=%d window=%.0fs",
				DotaTime(),
				(string.gsub(unit:GetUnitName(), "npc_dota_hero_", "")),
				stats.steps,
				stats.hitAfter,
				stats.late,
				DotaTime() - stats.since
			)
		)
		unit._kiteStats = nil
	end
end
function X.TryKite(unit, meleeEnemy)
	local range = unit:GetAttackRange()
	if range <= 320 or not Fu.IsValidHero(meleeEnemy) or meleeEnemy:GetAttackRange() > 320 then
		return false
	end
	if Fu.IsDisabled(meleeEnemy) or meleeEnemy:IsRooted() or unit:IsRooted() or Fu.IsSuspiciousIllusion(meleeEnemy) then
		return false
	end
	local dist = GetUnitToUnitDistance(unit, meleeEnemy)
	-- The melee hero has to be a threat: on us, chasing us, or close.
	if
		meleeEnemy:GetAttackTarget() ~= unit
		and not Fu.IsChasingTarget(meleeEnemy, unit)
		and dist >= meleeEnemy:GetAttackRange() + 150
	then
		return false
	end
	-- Step back but stay in our attack range, so the next attack needs no walk back.
	local step = math.min(250, range - dist - 30)
	if step < 60 then
		return false
	end
	-- Never cut a wind-up that is playing now (attack activity 1503, as in combat.lua).
	if unit:GetAnimActivity() == 1503 and unit:GetAnimCycle() < unit:GetAttackPoint() + 0.05 then
		return false
	end
	local spa = unit:GetSecondsPerAttack()
	local point = math.max(unit:GetAttackPoint() / math.max(unit:GetAttackSpeed(), 0.1), 0.25)
	local since = GameTime() - unit:GetLastAttackTime()
	local from, to = point + KITE_BUF, spa - point - KITE_BUF
	if to - from < 0.15 or since < from or since > to then
		return false
	end
	local away = Fu.VectorAway(unit:GetLocation(), meleeEnemy:GetLocation(), step)
	if not IsLocationPassable(away) then
		return false
	end
	unit:Action_MoveToLocation(away)
	if unit._kitePending == nil then
		local enemySpa = meleeEnemy:GetSecondsPerAttack() or spa
		local window = math.max(enemySpa, spa) + 0.1
		KiteStats(unit).steps = KiteStats(unit).steps + 1
		unit._kitePending = { enemy = meleeEnemy, at = GameTime(), checkAt = GameTime() + window, window = window }
	end
	if DotaTime() >= (unit._kiteLogAt or -99) + 2 then
		unit._kiteLogAt = DotaTime()
		pcall(
			print,
			string.format(
				"[OHA-KITE] t=%.0f %s from %s dist=%d step=%d since=%.2f window=%.2f-%.2f spa=%.2f",
				DotaTime(),
				(string.gsub(unit:GetUnitName(), "npc_dota_hero_", "")),
				(string.gsub(meleeEnemy:GetUnitName(), "npc_dota_hero_", "")),
				dist,
				step,
				since,
				from,
				to,
				spa
			)
		)
	end
	return true
end
-- Per-think hook for heroes on Valve's own attack mode: attack mode active, ranged, hitting a
-- hero. Heroes on the override attack mode (unit._ohaAttackOverride, set by
-- mode_attack_generic.lua) already kite from its Think. Returns true when it issued the step.
function X.TryKiteInAttack(unit)
	if unit ~= nil and unit:IsAlive() then
		pcall(X.KiteResultTick, unit)
	end
	if
		unit == nil
		or unit._ohaAttackOverride
		or not unit:IsAlive()
		or unit:GetActiveMode() ~= BOT_MODE_ATTACK
		or unit:GetAttackRange() <= 320
		or Fu.CanNotUseAction(unit)
	then
		return false
	end
	local target = unit:GetAttackTarget()
	if not Fu.IsValidHero(target) then
		target = unit:GetTarget()
	end
	if not Fu.IsValidHero(target) then
		return false
	end
	return X.TryKite(unit, target)
end
return X
