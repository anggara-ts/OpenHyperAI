-- Shared helper: team info.
local function installTeamInfo(Fu)
	local unitListCache = {}
	local unitListCacheTime = -1
	local function GetCachedUnitList(listType)
		local now = GameTime()
		if now ~= unitListCacheTime then
			unitListCache = {}
			unitListCacheTime = now
		end
		if unitListCache[listType] then
			return unitListCache[listType]
		end
		local units = GetUnitList(listType)
		unitListCache[listType] = units
		return units
	end
	Fu.GetCachedUnitList = GetCachedUnitList
	local realEnemyHeroesCache = nil
	local realEnemyHeroesTime = -1
	function Fu.GetRealEnemyHeroes()
		local now = GameTime()
		if now == realEnemyHeroesTime and realEnemyHeroesCache then
			return realEnemyHeroesCache
		end
		local enemyHeroes = GetCachedUnitList(UNIT_LIST_ENEMY_HEROES)
		local realHeroes = {}
		for _, hero in pairs(enemyHeroes) do
			if
				Fu.IsValidHero(hero)
				and not Fu.IsSuspiciousIllusion(hero)
				and not Fu.IsMeepoClone(hero)
				and not hero:HasModifier("modifier_arc_warden_tempest_double")
			then
				table.insert(realHeroes, hero)
			end
		end
		realEnemyHeroesCache = realHeroes
		realEnemyHeroesTime = now
		return realHeroes
	end
	function Fu.GetUnitAllyCountAroundEnemyTarget(target, radius)
		local location = target:GetLocation()
		local heroCount = Fu.GetNearbyAroundLocationUnitCount(false, true, radius, location)
		local creepCount = Fu.GetNearbyAroundLocationUnitCount(false, false, radius, location)
		return heroCount + creepCount
	end
	function Fu.GetAroundTargetEnemyUnitCount(target, radius)
		local location = target:GetLocation()
		return Fu.GetAroundTargetLocEnemyUnitCount(location, radius)
	end
	function Fu.GetAroundTargetLocEnemyUnitCount(location, radius)
		local heroCount = Fu.GetNearbyAroundLocationUnitCount(true, true, radius, location)
		local creepCount = Fu.GetNearbyAroundLocationUnitCount(true, false, radius, location)
		return heroCount + creepCount
	end
	function Fu.GetAroundTargetEnemyHeroCount(target, radius)
		return Fu.GetNearbyAroundLocationUnitCount(true, true, radius, target:GetLocation())
	end
	function Fu.GetNearbyAroundLocationUnitCount(isEnemy, heroesOnly, radius, location)
		local count = 0
		if heroesOnly then
			if isEnemy then
				count = #Fu.GetEnemiesNearLoc(location, radius)
			else
				count = #Fu.GetAlliesNearLoc(location, radius)
			end
		else
			if isEnemy then
				for _, unit in pairs(GetCachedUnitList(UNIT_LIST_ENEMIES)) do
					if Fu.IsValid(unit) and GetUnitToLocationDistance(unit, location) <= radius then
						count = count + 1
					end
				end
			else
				for _, unit in pairs(GetCachedUnitList(UNIT_LIST_ALLIES)) do
					if Fu.IsValid(unit) and GetUnitToLocationDistance(unit, location) <= radius then
						count = count + 1
					end
				end
			end
		end
		return count
	end
	function Fu.GetAttackEnemysAllyCreepCount(target, radius)
		local bot = GetBot()
		local allyCreeps = bot:GetNearbyCreeps(radius, false)
		local count = 0
		for _, creep in pairs(allyCreeps) do
			if creep:IsAlive() and creep:CanBeSeen() and creep:GetAttackTarget() == target then
				count = count + 1
			end
		end
		return count
	end
	function Fu.GetRetreatingAlliesNearLoc(location, radius)
		local allies = {}
		for i = 1, #GetTeamPlayers(GetTeam()) do
			local member = GetTeamMember(i)
			if
				member ~= nil
				and member:IsAlive()
				and GetUnitToLocationDistance(member, location) <= radius
				and Fu.IsRetreating(member)
			then
				table.insert(allies, member)
			end
		end
		return allies
	end
	function Fu.GetAlliesNearLoc(location, radius)
		local allies = {}
		if location == nil then
			return allies
		end
		for i = 1, #GetTeamPlayers(GetTeam()) do
			local member = GetTeamMember(i)
			if member ~= nil and member:IsAlive() and GetUnitToLocationDistance(member, location) <= radius then
				table.insert(allies, member)
			end
		end
		return allies
	end
	function Fu.GetEnemiesNearLoc(location, radius)
		local enemies = {}
		if location == nil then
			return enemies
		end
		for _, enemyHero in pairs(Fu.GetRealEnemyHeroes()) do
			if GetUnitToLocationDistance(enemyHero, location) <= radius then
				table.insert(enemies, enemyHero)
			end
		end
		return enemies
	end
	function Fu.GetIllusionsNearLoc(location, radius)
		local illusions = {}
		for _, enemyHero in pairs(GetCachedUnitList(UNIT_LIST_ENEMY_HEROES)) do
			if
				Fu.IsValidHero(enemyHero)
				and GetUnitToLocationDistance(enemyHero, location) <= radius
				and Fu.IsSuspiciousIllusion(enemyHero)
				and not Fu.IsMeepoClone(enemyHero)
			then
				table.insert(illusions, enemyHero)
			end
		end
		return illusions
	end
	function Fu.GetHeroesTargetingUnit(heroes, target)
		local result = {}
		for _, enemyHero in pairs(heroes) do
			if
				Fu.IsValidHero(enemyHero)
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and (enemyHero:GetAttackTarget() == target or Fu.IsChasingTarget(enemyHero, target))
			then
				table.insert(result, enemyHero)
			end
		end
		return result
	end
	function Fu.GetSameUnitType(target, radius, unitName, onlyTargeting)
		local result = {}
		local units = GetCachedUnitList(UNIT_LIST_ALL)
		for _, unit in pairs(units) do
			if
				Fu.IsValid(unit)
				and unit:GetUnitName() == unitName
				and GetUnitToUnitDistance(unit, target) <= radius
			then
				if onlyTargeting then
					if unit:GetAttackTarget() == target or Fu.IsChasingTarget(unit, target) then
						table.insert(result, unit)
					end
				else
					table.insert(result, unit)
				end
			end
		end
		return result
	end
	function Fu.IsTargetedByEnemyWithModifier(heroes, modifierName)
		-- Read the global `bot` (nil, or whichever bot some hero file last stored there), not the caller.
		local bot = GetBot()
		for _, enemyHero in pairs(heroes) do
			if
				Fu.IsValidHero(enemyHero)
				and enemyHero:HasModifier(modifierName)
				and (enemyHero:GetAttackTarget() == bot or Fu.IsChasingTarget(enemyHero, bot))
			then
				return true
			end
		end
		return false
	end
	function Fu.GetInvUnitInLocCount(bot, range, radius, location, includeMagicImmune)
		local count = 0
		if range > 1600 then
			range = 1600
		end
		local units = Fu.GetNearbyHeroes(bot, range, true, BOT_MODE_NONE)
		for _, enemy in pairs(units) do
			if
				(
					includeMagicImmune and Fu.CanCastOnMagicImmune(enemy)
					or not includeMagicImmune and Fu.CanCastOnNonMagicImmune(enemy)
				) and GetUnitToLocationDistance(enemy, location) <= radius
			then
				count = count + 1
			end
		end
		return count
	end
	function Fu.GetInLocLaneCreepCount(bot, range, radius, location)
		local count = 0
		if range > 1600 then
			range = 1600
		end
		local units = bot:GetNearbyLaneCreeps(range, true)
		for _, creep in pairs(units) do
			if GetUnitToLocationDistance(creep, location) <= radius then
				count = count + 1
			end
		end
		return count
	end
	function Fu.GetInvUnitCount(includeMagicImmune, units)
		local count = 0
		if units ~= nil then
			for _, unit in pairs(units) do
				if
					includeMagicImmune and Fu.CanCastOnMagicImmune(unit)
					or not includeMagicImmune and Fu.CanCastOnNonMagicImmune(unit)
				then
					count = count + 1
				end
			end
		end
		return count
	end
	function Fu.GetAroundTargetAllyHeroCount(target, radius)
		local allies = Fu.GetAlliesNearLoc(target:GetLocation(), radius)
		return #allies
	end
	function Fu.GetAroundTargetOtherAllyHeroCount(bot, target, radius)
		local allies = Fu.GetAlliesNearLoc(target:GetLocation(), radius)
		if GetUnitToUnitDistance(bot, target) <= radius then
			return #allies - 1
		end
		return #allies
	end
	function Fu.GetAllyCreepNearLoc(bot, location, radius)
		local creeps = bot:GetNearbyCreeps(1600, false)
		local nearCreeps = {}
		for _, creep in pairs(creeps) do
			if creep ~= nil and creep:IsAlive() and GetUnitToLocationDistance(creep, location) <= radius then
				table.insert(nearCreeps, creep)
			end
		end
		return nearCreeps
	end
	function Fu.GetAllyUnitCountAroundEnemyTarget(bot, target, radius)
		local allies = Fu.GetAlliesNearLoc(target:GetLocation(), radius)
		local creeps = Fu.GetAllyCreepNearLoc(bot, target:GetLocation(), radius)
		return #allies + #creeps
	end
	local CACHE_TTL = 0.15
	local function GetFrameCached(bot, key, maxAge)
		if bot._fc == nil then
			return nil
		end
		local entry = bot._fc[key]
		if entry and DotaTime() - entry[1] <= (maxAge or CACHE_TTL) then
			return entry[2]
		end
		return nil
	end
	local function SetFrameCached(bot, key, value)
		if bot._fc == nil then
			bot._fc = {}
		end
		bot._fc[key] = { DotaTime(), value }
	end
	function Fu.GetNearbyHeroes(bot, radius, isEnemy, mode)
		if not mode then
			mode = BOT_MODE_NONE
		end
		local heroes = bot:GetNearbyHeroes(radius, isEnemy, mode)
		if not heroes then
			return heroes
		end
		local result = {}
		for _, hero in pairs(heroes) do
			-- Used to test the CALLER's modifier (`bot:HasModifier("modifier_arc_warden_tempest_double")`), so an
			-- Arc Warden Tempest Double calling this got an empty list (blind in fights). Doubles in the list are
			-- kept on purpose: an enemy Double hits as hard as the real hero and must count as a threat and a
			-- target. Fu.GetRealEnemyHeroes is the variant that leaves Doubles out.
			if Fu.IsValidHero(hero) and not Fu.IsMeepoClone(hero) then
				table.insert(result, hero)
			end
		end
		return result
	end
	function Fu.GetAroundBotUnitList(bot, radius, isEnemy)
		if radius > 1600 then
			radius = 1600
		end
		local heroes = Fu.GetNearbyHeroes(bot, radius, isEnemy, BOT_MODE_NONE)
		local creeps = bot:GetNearbyCreeps(radius, isEnemy)
		local units = {}
		if #heroes > 0 and #creeps > 0 then
			units = heroes
			for i = 1, #creeps do
				table.insert(units, creeps[i])
			end
		elseif #heroes == 0 then
			units = creeps
		elseif #creeps == 0 then
			units = heroes
		end
		return units
	end
	function Fu.GetAllyList(bot, radius)
		if radius > 1600 then
			radius = 1600
		end
		local allies = {}
		local heroes = Fu.GetNearbyHeroes(bot, radius, false, BOT_MODE_NONE)
		if #heroes <= 1 then
			return heroes
		end
		for _, ally in pairs(heroes) do
			if ally ~= nil and ally:IsAlive() and not ally:IsIllusion() then
				table.insert(allies, ally)
			end
		end
		return allies
	end
	function Fu.GetAllyCount(bot, radius)
		local allies = Fu.GetAllyList(bot, radius)
		return #allies
	end
	function Fu.GetAroundEnemyHeroList(radius)
		if radius > 1600 then
			radius = 1600
		end
		return Fu.GetNearbyHeroes(GetBot(), radius, true, BOT_MODE_NONE)
	end
	function Fu.GetEnemyList(bot, radius)
		if radius > 1600 then
			radius = 1600
		end
		local enemies = {}
		local heroes = Fu.GetNearbyHeroes(bot, radius, true, BOT_MODE_NONE)
		if heroes[1] == nil then
			return heroes
		end
		for _, enemy in pairs(heroes) do
			if enemy ~= nil and type(enemy) == "table" and enemy:IsAlive() and not Fu.IsSuspiciousIllusion(enemy) then
				table.insert(enemies, enemy)
			end
		end
		return enemies
	end
	function Fu.GetEnemyCount(bot, radius)
		local enemies = Fu.GetEnemyList(bot, radius)
		return #enemies
	end
	function Fu.GetLastSeenEnemiesNearLoc(location, radius)
		local enemies = {}
		for _, playerId in pairs(GetTeamPlayers(GetOpposingTeam())) do
			if IsHeroAlive(playerId) then
				local lastSeenInfo = GetHeroLastSeenInfo(playerId)
				if lastSeenInfo ~= nil then
					local lastSeen = lastSeenInfo[1]
					if
						lastSeen ~= nil
						and Fu.GetLocationToLocationDistance(location, lastSeen.location) <= radius
						and lastSeen.time_since_seen < 5.0
					then
						table.insert(enemies, playerId)
					end
				end
			end
		end
		return enemies
	end
	function Fu.GetNumOfAliveHeroes(isEnemy)
		local bot = GetBot()
		local team = GetTeam()
		if isEnemy then
			team = GetOpposingTeam()
		end
		local cacheKey = 80000 + team
		local cached = GetFrameCached(bot, cacheKey, 1.0)
		if cached then
			return cached
		end
		local count = 0
		for _, playerId in pairs(GetTeamPlayers(team)) do
			if IsHeroAlive(playerId) then
				count = count + 1
			end
		end
		SetFrameCached(bot, cacheKey, count)
		return count
	end
	function Fu.GetHeroesNearLocation(isEnemy, location, radius)
		local result = {}
		local heroes = isEnemy and GetCachedUnitList(UNIT_LIST_ENEMY_HEROES)
			or GetCachedUnitList(UNIT_LIST_ALLIED_HEROES)
		for _, hero in pairs(heroes) do
			if
				hero ~= nil
				and hero:IsAlive()
				and hero:CanBeSeen()
				and GetUnitToLocationDistance(hero, location) <= radius
			then
				table.insert(result, hero)
			end
		end
		return result
	end
	function Fu.GetAverageLevel(isEnemy)
		local bot = GetBot()
		local team = GetTeam()
		if isEnemy then
			team = GetOpposingTeam()
		end
		local cacheKey = 81000 + team
		local cached = GetFrameCached(bot, cacheKey, 2.0)
		if cached then
			return cached
		end
		local count = 0
		local totalLevel = 0
		for _, playerId in pairs(GetTeamPlayers(team)) do
			totalLevel = totalLevel + GetHeroLevel(playerId)
			count = count + 1
		end
		local averageLevel = totalLevel / count
		SetFrameCached(bot, cacheKey, averageLevel)
		return averageLevel
	end
	function Fu.GetNumOfTeamTotalKills(isEnemy)
		local count = 0
		local team = GetOpposingTeam()
		if isEnemy then
			team = GetTeam()
		end
		local cacheKeys = Fu.CK
		if cacheKeys then
			local cached = Fu.Utils.GetCachedVars(cacheKeys.NUM_TEAM_TOTAL_KILLS + team, 1)
			if cached ~= nil then
				return cached
			end
		end
		for _, playerId in pairs(GetTeamPlayers(team)) do
			count = count + GetHeroDeaths(playerId)
		end
		if cacheKeys then
			Fu.Utils.SetCachedVars(cacheKeys.NUM_TEAM_TOTAL_KILLS + team, count)
		end
		return count
	end
	function Fu.GetUnitWithMinDistanceToLoc(sourceUnit, units, defaultUnit, defaultDistance, location)
		local closestUnit = defaultUnit
		local closestDistance = defaultDistance
		for i = 1, #units do
			if units[i] ~= nil and units[i] ~= sourceUnit and Fu.CanCastOnNonMagicImmune(units[i]) then
				local distance = GetUnitToLocationDistance(units[i], location)
				if distance < closestDistance then
					closestDistance = distance
					closestUnit = units[i]
				end
			end
		end
		return closestDistance, closestUnit
	end
	function Fu.GetUnitWithMaxDistanceToLoc(sourceUnit, units, defaultUnit, defaultDistance, location)
		local farthestUnit = defaultUnit
		local farthestDistance = defaultDistance
		for i = 1, #units do
			if units[i] ~= nil and units[i] ~= sourceUnit and Fu.CanCastOnNonMagicImmune(units[i]) then
				local distance = GetUnitToLocationDistance(units[i], location)
				if distance > farthestDistance then
					farthestDistance = distance
					farthestUnit = units[i]
				end
			end
		end
		return farthestDistance, farthestUnit
	end
	function Fu.GetFurthestUnitToLocationFrommAll(sourceUnit, radius, location)
		local allies = Fu.GetNearbyHeroes(sourceUnit, radius, false, BOT_MODE_NONE)
		local enemies = Fu.GetNearbyHeroes(sourceUnit, radius, true, BOT_MODE_NONE)
		local allyCreeps = sourceUnit:GetNearbyLaneCreeps(radius, false)
		local enemyCreeps = sourceUnit:GetNearbyLaneCreeps(radius, true)
		local distance = GetUnitToLocationDistance(sourceUnit, location)
		local farthestUnit = sourceUnit
		distance, farthestUnit = Fu.GetUnitWithMaxDistanceToLoc(sourceUnit, allies, farthestUnit, distance, location)
		distance, farthestUnit = Fu.GetUnitWithMaxDistanceToLoc(sourceUnit, enemies, farthestUnit, distance, location)
		distance, farthestUnit =
			Fu.GetUnitWithMaxDistanceToLoc(sourceUnit, allyCreeps, farthestUnit, distance, location)
		distance, farthestUnit =
			Fu.GetUnitWithMaxDistanceToLoc(sourceUnit, enemyCreeps, farthestUnit, distance, location)
		if farthestUnit ~= sourceUnit then
			return farthestUnit
		end
		return nil
	end
	function Fu.GetClosestUnitToLocationFrommAll(sourceUnit, radius, location)
		local allies = Fu.GetNearbyHeroes(sourceUnit, radius, false, BOT_MODE_NONE)
		local enemies = Fu.GetNearbyHeroes(sourceUnit, radius, true, BOT_MODE_NONE)
		local allyCreeps = sourceUnit:GetNearbyLaneCreeps(radius, false)
		local enemyCreeps = sourceUnit:GetNearbyLaneCreeps(radius, true)
		local distance = GetUnitToLocationDistance(sourceUnit, location)
		local closestUnit = sourceUnit
		distance, closestUnit = Fu.GetUnitWithMinDistanceToLoc(sourceUnit, allies, closestUnit, distance, location)
		distance, closestUnit = Fu.GetUnitWithMinDistanceToLoc(sourceUnit, enemies, closestUnit, distance, location)
		distance, closestUnit = Fu.GetUnitWithMinDistanceToLoc(sourceUnit, allyCreeps, closestUnit, distance, location)
		distance, closestUnit = Fu.GetUnitWithMinDistanceToLoc(sourceUnit, enemyCreeps, closestUnit, distance, location)
		if closestUnit ~= sourceUnit then
			return closestUnit
		end
		return nil
	end
	function Fu.GetClosestUnitToLocationFrommAll2(sourceUnit, radius, location)
		local allies = Fu.GetNearbyHeroes(sourceUnit, radius, false, BOT_MODE_NONE)
		local enemies = Fu.GetNearbyHeroes(sourceUnit, radius, true, BOT_MODE_NONE)
		local allyCreeps = sourceUnit:GetNearbyLaneCreeps(radius, false)
		local enemyCreeps = sourceUnit:GetNearbyLaneCreeps(radius, true)
		local distance = 10000
		local closestUnit = nil
		distance, closestUnit = Fu.GetUnitWithMinDistanceToLoc(sourceUnit, allies, closestUnit, distance, location)
		distance, closestUnit = Fu.GetUnitWithMinDistanceToLoc(sourceUnit, enemies, closestUnit, distance, location)
		distance, closestUnit = Fu.GetUnitWithMinDistanceToLoc(sourceUnit, allyCreeps, closestUnit, distance, location)
		distance, closestUnit = Fu.GetUnitWithMinDistanceToLoc(sourceUnit, enemyCreeps, closestUnit, distance, location)
		if closestUnit ~= nil then
			return closestUnit
		end
		return nil
	end
	function Fu.GetAliveAllyCoreCount()
		local count = 0
		for _, ally in pairs(GetCachedUnitList(UNIT_LIST_ALLIED_HEROES)) do
			if Fu.IsValidHero(ally) and Fu.IsCore(ally) and not ally:IsIllusion() then
				count = count + 1
			end
		end
		return count
	end
	function Fu.GetMeepos()
		local meepos = {}
		for _, ally in pairs(GetCachedUnitList(UNIT_LIST_ALLIED_HEROES)) do
			if
				Fu.IsValidHero(ally)
				and ally:GetUnitName() == "npc_dota_hero_meepo"
				and not Fu.IsSuspiciousIllusion(ally)
			then
				table.insert(meepos, ally)
			end
		end
		return meepos
	end
	function Fu.NumHumanBotPlayersInTeam()
		local humanCount, botCount = 0, 0
		for _, playerId in pairs(GetTeamPlayers(GetTeam())) do
			if not IsPlayerBot(playerId) then
				humanCount = humanCount + 1
			else
				botCount = botCount + 1
			end
		end
		return humanCount, botCount
	end
	function Fu.GetEnemiesAroundAncient(bot, radius)
		if bot == nil then
			bot = GetBot()
		end
		return Fu.GetEnemiesAroundLoc(GetAncient(bot:GetTeam()):GetLocation(), radius)
	end
	function Fu.GetEnemiesAroundLoc(location, radius)
		if not radius then
			radius = 2000
		end
		local threat = 0
		local ancientLocation = GetAncient(GetBot():GetTeam()):GetLocation()
		for _, playerId in pairs(GetTeamPlayers(GetOpposingTeam())) do
			if IsHeroAlive(playerId) then
				local lastSeenInfo = GetHeroLastSeenInfo(playerId)
				if lastSeenInfo ~= nil then
					local lastSeen = lastSeenInfo[1]
					if
						lastSeen ~= nil
						and Fu.GetLocationToLocationDistance(location, lastSeen.location) <= radius
						and lastSeen.time_since_seen < 5.0
					then
						threat = threat + GetHeroLevel(playerId) / 3
						if Fu.GetLocationToLocationDistance(ancientLocation, location) < 1600 then
							threat = threat + 2
						end
					end
				end
			end
		end
		for _, unit in pairs(GetCachedUnitList(UNIT_LIST_ENEMIES)) do
			if Fu.IsValid(unit) and GetUnitToLocationDistance(unit, location) <= radius then
				local unitName = unit:GetUnitName()
				if unit:IsCreep() then
					threat = threat + 1
					if
						unit:IsAncientCreep()
						or unit:HasModifier("modifier_chen_holy_persuasion")
						or unit:HasModifier("modifier_dominated")
					then
						threat = threat + 1
					end
				elseif string.find(unit:GetUnitName(), "spiderling") then
					threat = threat + 0.1
				elseif string.find(unit:GetUnitName(), "eidolon") then
					threat = threat + 0.3
				elseif string.find(unitName, "siege") and not string.find(unitName, "upgraded") then
					threat = threat + 0.6
				elseif string.find(unitName, "upgraded") then
					threat = threat + 1
				elseif string.find(unitName, "warlock_golem") then
					if DotaTime() < 10 * 60 then
						threat = threat + 3
					elseif DotaTime() < 20 * 60 then
						threat = threat + 2.5
					elseif DotaTime() < 30 * 60 then
						threat = threat + 2
					else
						threat = threat + 1.5
					end
				elseif string.find(unitName, "lone_druid_bear") then
					threat = threat + 3
				elseif string.find(unitName, "shadow_shaman_ward") then
					threat = threat + 2
				elseif string.find(unit:GetUnitName(), "tombstone") then
					threat = threat + 2
				elseif Fu.IsSuspiciousIllusion(unit) then
					if
						unit:HasModifier("modifier_arc_warden_tempest_double")
						or string.find(unit:GetUnitName(), "chaos_knight")
						or string.find(unit:GetUnitName(), "naga_siren")
					then
						threat = threat + 2
					end
				elseif not (string.find(unitName, "observer_wards") or string.find(unitName, "sentry_wards")) then
					threat = threat + 1
				end
				if Fu.GetLocationToLocationDistance(ancientLocation, location) < 1600 then
					threat = threat + 2
				end
			end
		end
		return threat
	end
	local allyNetworths = {}
	local enemyNetworths = {}
	function Fu.GetInventoryNetworth()
		local allyNetworth = 0
		local enemyNetworth = 0
		if math.floor(DotaTime()) % 2 == 0 then
			for i = 1, #GetTeamPlayers(GetTeam()) do
				local member = GetTeamMember(i)
				if member then
					local itemsCost = 0
					for slot = 0, 8 do
						local item = member:GetItemInSlot(slot)
						if item then
							itemsCost = itemsCost + GetItemCost(item:GetName())
						end
					end
					local playerId = member:GetPlayerID()
					if allyNetworths[playerId] == nil then
						allyNetworths[playerId] = 0
					end
					if allyNetworths[playerId] < itemsCost then
						allyNetworths[playerId] = itemsCost
					end
				end
			end
			for _, enemy in pairs(GetCachedUnitList(UNIT_LIST_ENEMY_HEROES)) do
				if
					Fu.IsValidHero(enemy)
					and not Fu.IsSuspiciousIllusion(enemy)
					and not enemy:HasModifier("modifier_arc_warden_tempest_double")
					and not string.find(enemy:GetUnitName(), "lone_druid_bear")
					and not Fu.IsMeepoClone(enemy)
				then
					local playerId = enemy:GetPlayerID()
					local itemsCost = 0
					for i = 0, 8 do
						local item = enemy:GetItemInSlot(i)
						if item then
							itemsCost = itemsCost + GetItemCost(item:GetName())
						end
					end
					if enemyNetworths[playerId] == nil then
						enemyNetworths[playerId] = 0
					end
					if enemyNetworths[playerId] < itemsCost then
						enemyNetworths[playerId] = itemsCost
					end
				end
			end
		end
		for _, networth in pairs(allyNetworths) do
			allyNetworth = allyNetworth + networth
		end
		for _, networth in pairs(enemyNetworths) do
			enemyNetworth = enemyNetworth + networth
		end
		return allyNetworth, enemyNetworth
	end
	function Fu.GetAliveCoreCount(isEnemy)
		local bot = GetBot()
		local cacheKey = 82000 + (isEnemy and 1 or 0)
		local cached = GetFrameCached(bot, cacheKey, 1.0)
		if cached then
			return cached
		end
		local count = 0
		if isEnemy then
			for _, enemyHero in pairs(GetCachedUnitList(UNIT_LIST_ENEMY_HEROES)) do
				if Fu.IsValidHero(enemyHero) and not Fu.IsSuspiciousIllusion(enemyHero) and Fu.IsCore(enemyHero) then
					count = count + 1
				end
			end
		else
			for _, ally in pairs(GetCachedUnitList(UNIT_LIST_ALLIED_HEROES)) do
				if Fu.IsValidHero(ally) and not ally:IsIllusion() and Fu.IsCore(ally) then
					count = count + 1
				end
			end
		end
		SetFrameCached(bot, cacheKey, count)
		return count
	end
	function Fu.GetEnemyCountInLane(lane)
		local count = 0
		local laneFront = GetLaneFrontLocation(GetTeam(), lane, 0)
		for _, playerId in pairs(GetTeamPlayers(GetOpposingTeam())) do
			if IsHeroAlive(playerId) then
				local lastSeenInfo = GetHeroLastSeenInfo(playerId)
				if lastSeenInfo ~= nil then
					local lastSeen = lastSeenInfo[1]
					if
						lastSeen ~= nil
						and Fu.GetDistance(laneFront, lastSeen.location) < 1600
						and lastSeen.time_since_seen < 6
					then
						count = count + 1
					end
				end
			end
		end
		return count
	end
	function Fu.GetCreepListAroundTargetCanKill(target, radius, maxHealth, isEnemy, neutralsOnly, creepsOnly)
		if radius > 1600 then
			radius = 1600
		end
		local creeps = {}
		if target ~= nil then
			if neutralsOnly then
				for _, creep in pairs(GetUnitList(UNIT_LIST_NEUTRAL_CREEPS)) do
					if
						Fu.IsValid(creep)
						and target ~= creep
						and GetUnitToUnitDistance(target, creep) <= radius
						and creep:GetHealth() <= maxHealth
					then
						table.insert(creeps, creep)
					end
				end
			elseif creepsOnly then
				local units = GetUnitList(UNIT_LIST_ALLIED_CREEPS)
				if isEnemy then
					units = GetUnitList(UNIT_LIST_ENEMY_CREEPS)
				end
				for _, creep in pairs(units) do
					if
						Fu.IsValid(creep)
						and target ~= creep
						and GetUnitToUnitDistance(target, creep) <= radius
						and creep:GetHealth() <= maxHealth
					then
						table.insert(creeps, creep)
					end
				end
			else
				local units = GetUnitList(UNIT_LIST_ALLIED_CREEPS)
				if isEnemy then
					units = GetUnitList(UNIT_LIST_ENEMY_CREEPS)
				end
				for _, creep in pairs(units) do
					if
						Fu.IsValid(creep)
						and target ~= creep
						and GetUnitToUnitDistance(target, creep) <= radius
						and creep:GetHealth() <= maxHealth
					then
						table.insert(creeps, creep)
					end
				end
				units = GetUnitList(UNIT_LIST_NEUTRAL_CREEPS)
				for _, creep in pairs(units) do
					if
						Fu.IsValid(creep)
						and target ~= creep
						and GetUnitToUnitDistance(target, creep) <= radius
						and creep:GetHealth() <= maxHealth
					then
						table.insert(creeps, creep)
					end
				end
			end
		end
		return creeps
	end
end
return installTeamInfo
