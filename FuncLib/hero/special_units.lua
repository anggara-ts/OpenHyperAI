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
-- Kiting (#72; user request 2026-11-17, global helper since game 063): a ranged bot that is attacking steps away
-- from a melee unit hitting it between its own attacks, instead of standing still. Kinds:
--   hero    a melee hero (attack mode: our target, on us, chasing us or close; other modes: hitting us)
--   lane    a melee lane creep hitting us (laning, farming a lane, pushing)
--   jungle  a melee neutral hitting us (jungling)
-- Only inside the safe window between attacks (FuncLib/systems/kite_rules.lua: never cuts a wind-up, skipped when
-- attacks are too fast), and the step keeps the bot's attack target in range. No step while a last hit is due
-- before the step and the next attack are over. The override attack mode calls X.TryKite from its Think; every
-- other mode goes through X.TryKiteInAttack, the per-think hook in ability_item_usage_generic.lua.
local KiteRules = require(GetScriptDirectory() .. "/FuncLib/systems/kite_rules")
local KITE_KINDS = { "hero", "lane", "jungle", "chase" }
-- Result of the kiting: does it help? One sample per attack cycle and kind: after a step ("steps"), or when the
-- same situation came up and the bot did not step ("base", the baseline, with why it did not: fast attacks, no
-- room for a step, a last hit due, a blocked spot). Once the attacker's next attack could have landed (its seconds
-- per attack, or ours if longer, + 0.1s): was the bot hit (a hero: by that hero; a creep: by any creep, the API
-- has no per-creep read), did its own attack come after the step, and did it move 40+. One line per kind per 60s.
-- Chase samples are checked when our next attack is released: was the target still in attack range (inRangeNext).
local function KiteStats(unit)
	if unit._kiteStats == nil then
		local kinds = {}
		for _, kind in ipairs(KITE_KINDS) do
			kinds[kind] = {
				steps = 0,
				hitAfter = 0,
				late = 0,
				moved = 0,
				base = 0,
				baseHit = 0,
				inRange = 0,
				baseInRange = 0,
				fromHit = 0,
				baseFromHit = 0,
				why = {},
			}
		end
		unit._kiteStats = { since = DotaTime(), kinds = kinds }
	end
	return unit._kiteStats
end
local function ShortName(unit)
	local unitName = unit:GetUnitName() or "?"
	return (string.gsub(string.gsub(unitName, "^npc_dota_hero_", ""), "^npc_dota_", ""))
end
-- Start a sample unless one is still open (one per attack cycle). checkIn: seconds to the check (chase: our next
-- attack), else the attacker's next attack.
local function KiteSample(unit, attacker, kind, stepped, why, stepEnd, checkIn)
	if unit._kitePending ~= nil then
		return
	end
	local spa = unit:GetSecondsPerAttack()
	local kindStats = KiteStats(unit).kinds[kind]
	-- Not a like-for-like baseline (KiteRules.NOT_BASELINE): counted in no-step= once per attack cycle, no sample.
	if not stepped and KiteRules.NOT_BASELINE[why] then
		unit._kiteSkipNext = unit._kiteSkipNext or {}
		if GameTime() >= (unit._kiteSkipNext[kind] or -99) then
			unit._kiteSkipNext[kind] = GameTime() + spa
			kindStats.why[why] = (kindStats.why[why] or 0) + 1
		end
		return
	end
	local attackerSpa = attacker:GetSecondsPerAttack() or spa
	local window = checkIn or math.max(attackerSpa, spa) + 0.1
	if stepped then
		kindStats.steps = kindStats.steps + 1
	else
		kindStats.base = kindStats.base + 1
		kindStats.why[why] = (kindStats.why[why] or 0) + 1
	end
	unit._kitePending = {
		enemy = attacker,
		kind = kind,
		stepped = stepped,
		at = GameTime(),
		checkAt = GameTime() + window,
		window = window,
		stepEnd = stepEnd,
		stepLeft = stepEnd ~= nil and Fu.GetLocationToLocationDistance(unit:GetLocation(), stepEnd) or nil,
		closest = math.huge,
		-- fromHit: the unit we stepped from (not any creep) released an attack on us before the check.
		attackerLast = attacker:GetLastAttackTime(),
		fromHit = false,
	}
end
function X.KiteResultTick(unit)
	local pending = unit._kitePending
	-- moved: the bot came 40+ closer to the step's end point at some think before the check (the mode may walk it
	-- back by the check, so the position at the check says nothing).
	if pending ~= nil and pending.stepEnd ~= nil then
		pending.closest =
			math.min(pending.closest, Fu.GetLocationToLocationDistance(unit:GetLocation(), pending.stepEnd))
	end
	-- fromHit (#72, game 064: the creep metric counted any creep's hit): the attacker's last attack time moved after
	-- the sample started while its target was this bot. Read every frame, so the target at the release is seen.
	if pending ~= nil and pending.kind ~= "chase" and not pending.fromHit then
		local attacker = pending.enemy
		if
			Fu.IsValid(attacker)
			and attacker:GetLastAttackTime() > (pending.attackerLast or math.huge)
			and attacker:GetAttackTarget() == unit
		then
			pending.fromHit = true
		end
	end
	-- A chase step: attack at once when the target is back in range before the step ends (X.ChaseReattack).
	if pending ~= nil and pending.kind == "chase" and pending.stepped and GameTime() < pending.checkAt then
		X.ChaseReattack(unit, pending)
	end
	if pending ~= nil and GameTime() >= pending.checkAt then
		unit._kitePending = nil
		local kindStats = KiteStats(unit).kinds[pending.kind]
		local hit, inRange = false, false
		if pending.kind == "chase" then
			local target = pending.enemy
			inRange = Fu.IsValidHero(target)
				and target:IsAlive()
				and KiteRules.InAttackRange(
					GetUnitToUnitDistance(unit, target),
					unit:GetAttackRange(),
					unit:GetBoundingRadius(),
					target:GetBoundingRadius()
				)
		elseif pending.kind == "hero" then
			hit = Fu.IsValidHero(pending.enemy) and unit:WasRecentlyDamagedByHero(pending.enemy, pending.window)
		else
			hit = unit:WasRecentlyDamagedByCreep(pending.window)
		end
		if pending.stepped then
			if hit then
				kindStats.hitAfter = kindStats.hitAfter + 1
			end
			if pending.fromHit then
				kindStats.fromHit = kindStats.fromHit + 1
			end
			if inRange then
				kindStats.inRange = kindStats.inRange + 1
			end
			local attacked = unit:GetLastAttackTime() >= pending.at
			if not attacked then
				kindStats.late = kindStats.late + 1
			end
			if pending.kind == "chase" then
				-- One line per chase step (about 20-40 a game): did our attack follow it (the same test as late-attack),
				-- was the target in range at the check, and which order attacked (queue: the attack queued behind the
				-- step; frame: X.ChaseReattack once the target was back in range).
				pcall(
					print,
					string.format(
						"[OHA-KITE] t=%.0f %s chase-result result=%s inRange=%d reattack=%s target=%s step=%d",
						DotaTime(),
						ShortName(unit),
						attacked and "attacked" or "no-attack",
						inRange and 1 or 0,
						pending.reattack or "queue",
						Fu.IsValid(pending.enemy) and ShortName(pending.enemy) or "-",
						pending.step or 0
					)
				)
			end
			if pending.stepLeft ~= nil and pending.stepLeft - pending.closest >= 40 then
				kindStats.moved = kindStats.moved + 1
			end
		else
			if hit then
				kindStats.baseHit = kindStats.baseHit + 1
			end
			if pending.fromHit then
				kindStats.baseFromHit = kindStats.baseFromHit + 1
			end
			if inRange then
				kindStats.baseInRange = kindStats.baseInRange + 1
			end
		end
	end
	local stats = unit._kiteStats
	if stats ~= nil and DotaTime() - stats.since >= 60 then
		for _, kind in ipairs(KITE_KINDS) do
			local kindStats = stats.kinds[kind]
			if kindStats.steps > 0 or kindStats.base > 0 or next(kindStats.why) ~= nil then
				local why = {}
				for reason, count in pairs(kindStats.why) do
					why[#why + 1] = reason .. ":" .. count
				end
				table.sort(why)
				if kind == "chase" then
					pcall(
						print,
						string.format(
							"[OHA-KITE] t=%.0f %s result kind=chase steps=%d inRangeNext=%d late-attack=%d moved=%d base=%d base-inRangeNext=%d no-step=%s window=%.0fs",
							DotaTime(),
							ShortName(unit),
							kindStats.steps,
							kindStats.inRange,
							kindStats.late,
							kindStats.moved,
							kindStats.base,
							kindStats.baseInRange,
							#why > 0 and table.concat(why, ",") or "-",
							DotaTime() - stats.since
						)
					)
				else
					pcall(
						print,
						string.format(
							"[OHA-KITE] t=%.0f %s result kind=%s steps=%d hit-after=%d fromHit=%d late-attack=%d moved=%d base=%d base-hit=%d baseFromHit=%d no-step=%s window=%.0fs",
							DotaTime(),
							ShortName(unit),
							kind,
							kindStats.steps,
							kindStats.hitAfter,
							kindStats.fromHit,
							kindStats.late,
							kindStats.moved,
							kindStats.base,
							kindStats.baseHit,
							kindStats.baseFromHit,
							#why > 0 and table.concat(why, ",") or "-",
							DotaTime() - stats.since
						)
					)
				end
			end
		end
		unit._kiteStats = nil
	end
end
-- Laning: a last hit (or deny) that would be due before the step and our next attack are over. The laning mode
-- times its last hits the same way (mode_laning_generic.lua GetBestLastHitCreep: attack damage - 3,
-- Fu.GetAttackProDelayTime, the creep attacks already on their way).
function X.KiteLastHitDue(unit, step)
	local stepSeconds = KiteRules.StepSeconds(step, unit:GetCurrentMovementSpeed())
	local hit = unit:GetAttackDamage() - 3
	local radius = math.min(1600, unit:GetAttackRange() + 200)
	for _, enemyCreeps in ipairs({ true, false }) do
		for _, creep in pairs(unit:GetNearbyLaneCreeps(radius, enemyCreeps) or {}) do
			if Fu.IsValid(creep) and Fu.CanBeAttacked(creep) then
				local horizon = stepSeconds + Fu.GetAttackProDelayTime(unit, creep)
				local ourHit = creep:GetActualIncomingDamage(hit, DAMAGE_TYPE_PHYSICAL)
				local others = Fu.GetTotalAttackWillRealDamage(creep, horizon)
				if KiteRules.LastHitDue(creep:GetHealth(), ourHit, others) then
					return true
				end
			end
		end
	end
	return false
end
-- Team roam's last-hit overlay (#171, FuncLib/systems/last_hit_overlay.lua, not on main yet) owns a hit while
-- unit._lhOwn is set: from its attack order until the attack is released, the unit dies or 1s passes. It runs after
-- this hook in ItemUsageThink, so a kite or chase step would replace its swing: none meanwhile. A plain field read,
-- so this works with or without #171. [OHA-KITE] kite-skip why=overlay-owns once per hold (and at most every 3s).
local function OverlayOwns(unit, kind)
	local own = unit._lhOwn
	if own == nil then
		return false
	end
	if unit._kiteOverlaySeen ~= own and DotaTime() >= (unit._kiteOverlayLogAt or -99) + 3 then
		unit._kiteOverlaySeen = own
		unit._kiteOverlayLogAt = DotaTime()
		pcall(
			print,
			string.format(
				"[OHA-KITE] t=%.0f %s kite-skip why=overlay-owns kind=%s mode=%d",
				DotaTime(),
				ShortName(unit),
				kind,
				unit:GetActiveMode()
			)
		)
	end
	return true
end
-- One kite step from attacker while target stays in range. Returns true when it issued the step.
function X.KiteStep(unit, attacker, target, kind)
	if OverlayOwns(unit, kind) then
		return false
	end
	if Fu.IsDisabled(attacker) or attacker:IsRooted() or unit:IsRooted() then
		return false
	end
	local spa = unit:GetSecondsPerAttack()
	local from, to = KiteRules.Window(spa, unit:GetAttackPoint(), unit:GetAttackSpeed())
	local tooFast, gap = KiteRules.TooFast(from, to, unit:GetCurrentMovementSpeed())
	if tooFast then
		KiteSample(unit, attacker, kind, false, "fast")
		if DotaTime() >= (unit._kiteSkipLogAt or -99) + 20 then
			unit._kiteSkipLogAt = DotaTime()
			pcall(
				print,
				string.format(
					"[OHA-KITE] t=%.0f %s kite-skip why=fast-attack kind=%s gap=%.2f spa=%.2f",
					DotaTime(),
					ShortName(unit),
					kind,
					gap,
					spa
				)
			)
		end
		return false
	end
	local since = GameTime() - unit:GetLastAttackTime()
	if not KiteRules.InWindow(since, from, to) then
		return false
	end
	-- Never cut a wind-up that is playing now (attack activity 1503, as in combat.lua).
	if unit:GetAnimActivity() == 1503 and unit:GetAnimCycle() < unit:GetAttackPoint() + 0.05 then
		return false
	end
	local here, attackerAt, targetAt = unit:GetLocation(), attacker:GetLocation(), target:GetLocation()
	local step, endX, endY =
		KiteRules.Step(here.x, here.y, attackerAt.x, attackerAt.y, targetAt.x, targetAt.y, unit:GetAttackRange())
	if step == nil then
		KiteSample(unit, attacker, kind, false, "no-room")
		return false
	end
	if X.KiteLastHitDue(unit, step) then
		KiteSample(unit, attacker, kind, false, "last-hit")
		return false
	end
	local away = Vector(endX, endY, here.z)
	if not IsLocationPassable(away) then
		KiteSample(unit, attacker, kind, false, "blocked")
		return false
	end
	unit:Action_MoveToLocation(away)
	KiteSample(unit, attacker, kind, true, nil, away)
	-- From lines: every 2s for heroes (about 30 a game), every 10s for creeps (many more steps; the result line
	-- has the counts).
	unit._kiteLogAt = unit._kiteLogAt or {}
	if DotaTime() >= (unit._kiteLogAt[kind] or -99) + (kind == "hero" and 2 or 10) then
		unit._kiteLogAt[kind] = DotaTime()
		pcall(
			print,
			string.format(
				"[OHA-KITE] t=%.0f %s from %s kind=%s mode=%d target=%s dist=%d step=%d since=%.2f window=%.2f-%.2f spa=%.2f",
				DotaTime(),
				ShortName(unit),
				ShortName(attacker),
				kind,
				unit:GetActiveMode(),
				ShortName(target),
				GetUnitToUnitDistance(unit, attacker),
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
-- Attack mode against a melee hero (the override attack mode calls this from its Think, the hook below for Valve's
-- attack mode): the hero has to be a threat, on us, chasing us or close.
function X.TryKite(unit, meleeEnemy)
	if
		unit:GetAttackRange() <= KiteRules.MELEE_RANGE
		or not Fu.IsValidHero(meleeEnemy)
		or meleeEnemy:GetAttackRange() > KiteRules.MELEE_RANGE
		or Fu.IsSuspiciousIllusion(meleeEnemy)
	then
		return false
	end
	if not X.MeleeThreat(unit, meleeEnemy) then
		return false
	end
	return X.KiteStep(unit, meleeEnemy, meleeEnemy, "hero")
end
-- A melee hero on us, chasing us, or close.
function X.MeleeThreat(unit, meleeEnemy)
	return meleeEnemy:GetAttackRange() <= KiteRules.MELEE_RANGE
		and not Fu.IsSuspiciousIllusion(meleeEnemy)
		and (
			meleeEnemy:GetAttackTarget() == unit
			or Fu.IsChasingTarget(meleeEnemy, unit)
			or GetUnitToUnitDistance(unit, meleeEnemy) < meleeEnemy:GetAttackRange() + 150
		)
end
-- The nearest melee unit hitting unit: an enemy hero first, then a lane creep, then a neutral. The scans only run
-- when unit was damaged by that kind in the last 1.5s.
function X.FindMeleeAttacker(unit)
	local best, bestKind, bestDist = nil, nil, math.huge
	local function consider(candidate, kind)
		if
			Fu.IsValid(candidate)
			and candidate:GetAttackTarget() == unit
			and candidate:GetAttackRange() <= KiteRules.MELEE_RANGE
		then
			local dist = GetUnitToUnitDistance(unit, candidate)
			if dist < bestDist then
				best, bestKind, bestDist = candidate, kind, dist
			end
		end
	end
	if unit:WasRecentlyDamagedByAnyHero(1.5) then
		for _, enemy in pairs(unit:GetNearbyHeroes(600, true, BOT_MODE_NONE) or {}) do
			if Fu.IsValidHero(enemy) and not Fu.IsSuspiciousIllusion(enemy) then
				consider(enemy, "hero")
			end
		end
		if best ~= nil then
			return best, bestKind
		end
	end
	if unit:WasRecentlyDamagedByCreep(1.5) then
		for _, creep in pairs(unit:GetNearbyLaneCreeps(500, true) or {}) do
			consider(creep, "lane")
		end
		if best == nil then
			for _, creep in pairs(unit:GetNearbyNeutralCreeps(500) or {}) do
				consider(creep, "jungle")
			end
		end
	end
	return best, bestKind
end
-- Modes that move the bot on purpose (retreat, Valve's dodging) or that a step would spoil (Roshan pit).
local NO_KITE_MODES = {
	[BOT_MODE_RETREAT] = true,
	[BOT_MODE_EVASIVE_MANEUVERS] = true,
	[BOT_MODE_ROSHAN] = true,
}
-- A mode or hero script holding the bot (outpost hold, a cast hold, Clinkz's invisible hunt, Techies' plant).
local function KiteHeld(unit)
	local now = DotaTime()
	return now < (unit._outpostHoldUntil or -1)
		or now < (unit._castHoldUntil or -1)
		or now < (unit._clinkzHuntUntil or -1)
		or now < (unit._madHoldUntil or -1)
end
-- After a chase step (#72, game 065: in 9 of 23 steps no attack of ours came before the check, and the target was in
-- range at the next check in only 5): the target is back in attack range while the step still runs, so attack now
-- instead of walking on to the step's end. Once per step, and only while nothing else holds the bot: the same
-- target, alive and attackable, no team roam overlay hit (_lhOwn), no hold, no mode without kiting, not invisible,
-- not already attacking it.
function X.ChaseReattack(unit, pending)
	local target = pending.enemy
	if pending.reattack ~= nil or not Fu.IsValidHero(target) or not target:IsAlive() then
		return false
	end
	if unit:GetAttackTarget() == target or unit._lhOwn ~= nil or KiteHeld(unit) then
		return false
	end
	if NO_KITE_MODES[unit:GetActiveMode()] or unit:IsInvisible() or Fu.CanNotUseAction(unit) then
		return false
	end
	-- The mode moved on to another target: not ours to attack.
	local modeTarget = unit:GetTarget()
	if not Fu.CanBeAttacked(target) or Fu.IsValid(modeTarget) and modeTarget ~= target then
		return false
	end
	if
		not KiteRules.InAttackRange(
			GetUnitToUnitDistance(unit, target),
			unit:GetAttackRange(),
			unit:GetBoundingRadius(),
			target:GetBoundingRadius()
		)
	then
		return false
	end
	pending.reattack = "frame"
	unit:Action_AttackUnit(target, false)
	return true
end
-- Enemy heroes near the chase target or near us (the most of the two) and our heroes near us, kept for 0.3s per bot
-- (the chase gate asks on every frame with a step to give; #52 perf).
local function ChaseGroupCounts(unit, here, targetAt)
	local cache = unit._kiteGroup
	local now = GameTime()
	if cache ~= nil and now < cache.untilTime then
		return cache.enemies, cache.allies
	end
	local enemies = math.max(
		#Fu.GetEnemiesNearLoc(targetAt, KiteRules.CHASE_GROUP_RADIUS),
		#Fu.GetEnemiesNearLoc(here, KiteRules.CHASE_GROUP_RADIUS)
	)
	local allies = #Fu.GetAlliesNearLoc(here, KiteRules.CHASE_ALLY_RADIUS)
	unit._kiteGroup = { untilTime = now + 0.3, enemies = enemies, allies = allies }
	return enemies, allies
end
-- Chase step toward an enemy hero target that runs out of range (kind=chase). The caller made sure no melee unit
-- is hitting the bot (stepping away wins). Returns true when it issued the step.
function X.ChaseStep(unit, target)
	if OverlayOwns(unit, "chase") then
		return false
	end
	if target:GetTeam() == unit:GetTeam() or Fu.IsSuspiciousIllusion(target) or unit:IsRooted() then
		return false
	end
	local spa = unit:GetSecondsPerAttack()
	local range = unit:GetAttackRange()
	local from, to = KiteRules.Window(spa, unit:GetAttackPoint(), unit:GetAttackSpeed())
	local since = GameTime() - unit:GetLastAttackTime()
	local nextIn = KiteRules.NextAttackIn(spa, since, from)
	local here, targetAt = unit:GetLocation(), target:GetLocation()
	-- Extrapolated to our next attack, at most KiteRules.CHASE_HORIZON ahead.
	local horizon = KiteRules.ChaseHorizon(nextIn)
	local ahead = target:GetExtrapolatedLocation(horizon)
	local step, endX, endY = KiteRules.ChaseStep(here.x, here.y, targetAt.x, targetAt.y, ahead.x, ahead.y, range)
	if step == nil then
		return false
	end
	local checkIn = nextIn + 0.1
	-- Not toward a group: 2+ enemy heroes near the target or near us, and fewer of us (KiteRules.ChaseOutnumbered).
	-- First of the gates (game 065: after the fast / window checks it never came up, 0 lines in 168 fast skips). It
	-- runs on every frame with a chase step to give, so the counts are kept for 0.3s.
	local enemies, allies = ChaseGroupCounts(unit, here, targetAt)
	if KiteRules.ChaseOutnumbered(enemies, allies) then
		KiteSample(unit, target, "chase", false, "outnumbered", nil, checkIn)
		unit._kiteLogAt = unit._kiteLogAt or {}
		if DotaTime() >= (unit._kiteLogAt.outnumbered or -99) + 10 then
			unit._kiteLogAt.outnumbered = DotaTime()
			pcall(
				print,
				string.format(
					"[OHA-KITE] t=%.0f %s chase-skip why=outnumbered target=%s enemies=%d allies=%d dist=%d",
					DotaTime(),
					ShortName(unit),
					ShortName(target),
					enemies,
					allies,
					GetUnitToUnitDistance(unit, target)
				)
			)
		end
		return false
	end
	if KiteRules.TooFast(from, to, unit:GetCurrentMovementSpeed()) then
		KiteSample(unit, target, "chase", false, "fast", nil, checkIn)
		return false
	end
	if not KiteRules.InWindow(since, from, to) then
		return false
	end
	if unit:GetAnimActivity() == 1503 and unit:GetAnimCycle() < unit:GetAttackPoint() + 0.05 then
		return false
	end
	-- The step ends before our next wind-up can start (game 065: 9 of 23 steps had no attack before the check).
	local fitted = KiteRules.FitChaseStep(step, unit:GetCurrentMovementSpeed(), to - since)
	if fitted == nil then
		KiteSample(unit, target, "chase", false, "no-time", nil, checkIn)
		return false
	end
	if fitted < step then
		endX = here.x + (endX - here.x) * fitted / step
		endY = here.y + (endY - here.y) * fitted / step
		step = fitted
	end
	local stepEnd = Vector(endX, endY, here.z)
	-- Not into an enemy tower's range (+100): #159's chase-stop rule is not on this branch.
	for _, tower in pairs(unit:GetNearbyTowers(1600, true) or {}) do
		if Fu.IsValidBuilding(tower) and GetUnitToLocationDistance(tower, stepEnd) <= tower:GetAttackRange() + 100 then
			KiteSample(unit, target, "chase", false, "tower", nil, checkIn)
			return false
		end
	end
	if X.KiteLastHitDue(unit, step) then
		KiteSample(unit, target, "chase", false, "last-hit", nil, checkIn)
		return false
	end
	if not IsLocationPassable(stepEnd) then
		KiteSample(unit, target, "chase", false, "blocked", nil, checkIn)
		return false
	end
	-- The attack follows the step (game 065: a bare move left the next attack to the mode's next order); the
	-- per-frame check in X.KiteResultTick attacks at once when the target is back in range before the step ends.
	unit:Action_MoveToLocation(stepEnd)
	unit:ActionQueue_AttackUnit(target, false)
	KiteSample(unit, target, "chase", true, nil, stepEnd, checkIn)
	if unit._kitePending ~= nil and unit._kitePending.kind == "chase" and unit._kitePending.step == nil then
		unit._kitePending.step = step
	end
	unit._kiteLogAt = unit._kiteLogAt or {}
	if DotaTime() >= (unit._kiteLogAt.chase or -99) + 2 then
		unit._kiteLogAt.chase = DotaTime()
		pcall(
			print,
			string.format(
				"[OHA-KITE] t=%.0f %s chase %s kind=chase mode=%d dist=%d ahead=%d horizon=%.2f enemies=%d allies=%d step=%d since=%.2f window=%.2f-%.2f spa=%.2f",
				DotaTime(),
				ShortName(unit),
				ShortName(target),
				unit:GetActiveMode(),
				GetUnitToUnitDistance(unit, target),
				GetUnitToLocationDistance(unit, ahead),
				horizon,
				enemies,
				allies,
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
-- For the override attack mode's Think (after X.TryKite): chase the hero it attacks, unless a melee unit is on the
-- bot (stepping away wins) or a hold, invisibility or the mode rules it out.
function X.TryChase(unit, target)
	if
		not Fu.IsValidHero(target)
		or unit:GetAttackRange() <= KiteRules.MELEE_RANGE
		or NO_KITE_MODES[unit:GetActiveMode()]
		or KiteHeld(unit)
		or unit:IsInvisible()
		or X.MeleeThreat(unit, target)
		or X.FindMeleeAttacker(unit) ~= nil
	then
		return false
	end
	return X.ChaseStep(unit, target)
end
local function KiteHook(unit)
	local mode = unit:GetActiveMode()
	if NO_KITE_MODES[mode] or unit:GetAttackRange() <= KiteRules.MELEE_RANGE then
		return false
	end
	local target = unit:GetAttackTarget()
	if mode == BOT_MODE_ATTACK and unit._ohaAttackOverride then
		return false
	end
	if not Fu.IsValid(target) and mode ~= BOT_MODE_ATTACK then
		return false
	end
	if KiteHeld(unit) or Fu.CanNotUseAction(unit) or unit:IsInvisible() then
		return false
	end
	local heroTarget = Fu.IsValidHero(target) and target or nil
	if mode == BOT_MODE_ATTACK then
		heroTarget = heroTarget or unit:GetTarget()
		if Fu.IsValidHero(heroTarget) and X.MeleeThreat(unit, heroTarget) then
			return X.TryKite(unit, heroTarget)
		end
	end
	local attacker, kind = X.FindMeleeAttacker(unit)
	if attacker ~= nil then
		if not Fu.IsValid(target) then
			return false
		end
		return X.KiteStep(unit, attacker, target, kind)
	end
	-- No melee unit on us: chase a hero target that runs out of range.
	if Fu.IsValidHero(heroTarget) then
		return X.ChaseStep(unit, heroTarget)
	end
	return false
end
-- Per-think hook (ability_item_usage_generic.lua) for every mode. Heroes on the override attack mode
-- (unit._ohaAttackOverride, set by mode_attack_generic.lua) kite from its Think while attack mode runs. Returns
-- true when it issued the step. The call site's pcall would hide an error (and with it all kiting): the first 3
-- distinct ones per bot print as [OHA-ERROR].
function X.TryKiteInAttack(unit)
	if unit == nil or not unit:IsAlive() then
		return false
	end
	pcall(X.KiteResultTick, unit)
	local ok, kited = pcall(KiteHook, unit)
	if ok then
		return kited == true
	end
	unit._kiteErrs = unit._kiteErrs or {}
	local key = tostring(kited)
	if not unit._kiteErrs[key] and (unit._kiteErrCount or 0) < 3 then
		unit._kiteErrs[key] = true
		unit._kiteErrCount = (unit._kiteErrCount or 0) + 1
		pcall(print, string.format("[OHA-ERROR] t=%.0f %s kite: %s", DotaTime(), ShortName(unit), key))
	end
	return false
end
return X
