-- Shared helper: positioning.
local function installPositioning(Fu)
	function Fu.IsAllyHeroBetweenAllyAndEnemy(allyHero, enemyHero, location, radius)
		local startLocation = allyHero:GetLocation()
		local endLocation = location
		local heroes = Fu.GetNearbyHeroes(allyHero, 1600, false, BOT_MODE_NONE)
		for _, hero in pairs(heroes) do
			if hero ~= allyHero then
				local lineInfo = PointToLineDistance(startLocation, endLocation, hero:GetLocation())
				if lineInfo ~= nil and lineInfo.within and lineInfo.distance <= radius + 50 then
					return true
				end
			end
		end
		heroes = Fu.GetNearbyHeroes(enemyHero, 1600, true, BOT_MODE_NONE)
		for _, hero in pairs(heroes) do
			if hero ~= allyHero then
				local lineInfo = PointToLineDistance(startLocation, endLocation, hero:GetLocation())
				if lineInfo ~= nil and lineInfo.within and lineInfo.distance <= radius + 50 then
					return true
				end
			end
		end
		return false
	end
	function Fu.IsInRange(unit, target, range)
		if target == nil or not target:CanBeSeen() then
			return false
		end
		return GetUnitToUnitDistance(unit, target) <= range
	end
	function Fu.IsInLocRange(unit, location, range)
		if not unit:CanBeSeen() then
			return false
		end
		return GetUnitToLocationDistance(unit, location) <= range
	end
	function Fu.GetCorrectLoc(unit, delay)
		local stability = unit:GetMovementDirectionStability()
		local currentLocation = unit:GetLocation()
		local predictedLocation = unit:GetExtrapolatedLocation(delay)
		local midLocation = (currentLocation + predictedLocation) * 0.5
		local nearMidLocation = (currentLocation + midLocation) * 0.5
		local farMidLocation = (predictedLocation + midLocation) * 0.5
		if stability < 0.5 then
			return nearMidLocation
		elseif stability < 0.7 then
			return midLocation
		elseif stability < 0.9 then
			return farMidLocation
		end
		return predictedLocation
	end
	function Fu.GetLocationToLocationDistance(firstLocation, secondLocation)
		local x1 = firstLocation.x
		local x2 = secondLocation.x
		local y1 = firstLocation.y
		local y2 = secondLocation.y
		return math.sqrt(math.pow(y2 - y1, 2) + math.pow(x2 - x1, 2))
	end
	function Fu.GetUnitTowardDistanceLocation(unit, target, distance)
		local unitLocation = unit:GetLocation()
		local direction = (target:GetLocation() - unitLocation) / GetUnitToUnitDistance(unit, target)
		return unitLocation + distance * direction
	end
	function Fu.GetLocationTowardDistanceLocation(unit, location, distance)
		local unitLocation = unit:GetLocation()
		local direction = (location - unitLocation) / GetUnitToLocationDistance(unit, location)
		return unitLocation + distance * direction
	end
	function Fu.GetFaceTowardDistanceLocation(unit, distance)
		local unitLocation = unit:GetLocation()
		local facingRadians = unit:GetFacing() * math.pi / 180
		local direction = Vector(math.cos(facingRadians), math.sin(facingRadians))
		return unitLocation + distance * direction
	end
	function Fu.GetCastLocation(bot, target, castRange, radius)
		local distance = GetUnitToUnitDistance(bot, target)
		if distance <= castRange then
			return target:GetLocation()
		end
		if distance <= castRange + radius - 120 then
			return Fu.GetUnitTowardDistanceLocation(bot, target, castRange)
		end
		if
			distance < castRange + radius - 18
			and (
				Fu.IsDisabled(target)
				or target:GetCurrentMovementSpeed() <= 160
				or target:IsFacingLocation(bot:GetLocation(), 45)
				or bot:IsFacingLocation(target:GetLocation(), 45) and target:GetCurrentMovementSpeed() <= 220
			)
		then
			return Fu.GetUnitTowardDistanceLocation(bot, target, castRange + 18)
		end
		if
			distance < castRange + radius + 28
			and target:IsFacingLocation(bot:GetLocation(), 30)
			and bot:IsFacingLocation(target:GetLocation(), 30)
			and target:GetMovementDirectionStability() > 0.95
			and target:GetCurrentMovementSpeed() >= 300
		then
			return Fu.GetUnitTowardDistanceLocation(bot, target, castRange + 18)
		end
		return nil
	end
	function Fu.GetDelayCastLocation(bot, target, castRange, radius, delay)
		local predictedLocation = Fu.GetCorrectLoc(target, delay)
		local distance = GetUnitToLocationDistance(bot, predictedLocation)
		if distance > castRange + radius - 16 then
			return nil
		end
		if distance > castRange - radius * 0.38 then
			return Fu.GetLocationTowardDistanceLocation(bot, predictedLocation, castRange + 8)
		end
		return predictedLocation
	end
	function Fu.GetCenterOfUnits(units)
		if #units == 0 then
			return Vector(0.0, 0.0)
		end
		local locationSum = Vector(0.0, 0.0)
		local count = 0
		for _, unit in pairs(units) do
			if Fu.IsValid(unit) then
				locationSum = locationSum + unit:GetLocation()
				count = count + 1
			end
		end
		if count == 0 then
			return Vector(0.0, 0.0)
		end
		return locationSum / count
	end
	function Fu.GetNearestLaneFrontLocation(location, isEnemy, delta)
		local team = GetTeam()
		if isEnemy then
			team = GetOpposingTeam()
		end
		local topFront = GetLaneFrontLocation(team, LANE_TOP, delta)
		local midFront = GetLaneFrontLocation(team, LANE_MID, delta)
		local botFront = GetLaneFrontLocation(team, LANE_BOT, delta)
		local topDistance = Fu.GetLocationToLocationDistance(location, topFront)
		local midDistance = Fu.GetLocationToLocationDistance(location, midFront)
		local botDistance = Fu.GetLocationToLocationDistance(location, botFront)
		if topDistance < midDistance and topDistance < botDistance then
			return topFront
		end
		if botDistance < midDistance and botDistance < topDistance then
			return botFront
		end
		return midFront
	end
	function Fu.RandomForwardVector(length)
		local vector = RandomVector(length)
		if GetTeam() == TEAM_RADIANT then
			vector.x = vector.x > 0 and vector.x or -vector.x
			vector.y = vector.y > 0 and vector.y or -vector.y
		end
		if GetTeam() == TEAM_DIRE then
			vector.x = vector.x < 0 and vector.x or -vector.x
			vector.y = vector.y < 0 and vector.y or -vector.y
		end
		return vector
	end
	function Fu.GetDistance(first, second)
		return math.sqrt((first[1] - second[1]) * (first[1] - second[1]) + (first[2] - second[2]) * (first[2] - second[2]))
	end
	function Fu.IsHeroBetweenMeAndLocation(unit, location, radius)
		local startLocation = unit:GetLocation()
		local endLocation = location
		local bot = GetBot()
		local allies = Fu.GetNearbyHeroes(bot, 1600, false, BOT_MODE_NONE)
		for _, ally in pairs(allies) do
			if ally ~= unit then
				local lineInfo = PointToLineDistance(startLocation, endLocation, ally:GetLocation())
				if lineInfo ~= nil and lineInfo.within and lineInfo.distance < radius then
					return true
				end
			end
		end
		local enemies = Fu.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE)
		for _, enemy in pairs(enemies) do
			if enemy ~= unit and not Fu.IsSuspiciousIllusion(enemy) then
				local lineInfo = PointToLineDistance(startLocation, endLocation, enemy:GetLocation())
				if lineInfo ~= nil and lineInfo.within and lineInfo.distance < radius then
					return true
				end
			end
		end
		return false
	end
	function Fu.IsEnemyBetweenMeAndLocation(unit, location, radius)
		local startLocation = unit:GetLocation()
		local endLocation = location
		local bot = GetBot()
		local enemies = Fu.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE)
		for _, enemy in pairs(enemies) do
			if enemy ~= unit and not Fu.IsSuspiciousIllusion(enemy) then
				local lineInfo = PointToLineDistance(startLocation, endLocation, enemy:GetLocation())
				if lineInfo ~= nil and lineInfo.within and lineInfo.distance < radius then
					return true
				end
			end
		end
		return false
	end
	function Fu.IsHeroBetweenMeAndTarget(unit, target, location, radius)
		local startLocation = unit:GetLocation()
		local endLocation = location
		local allies = Fu.GetNearbyHeroes(unit, 1600, false, BOT_MODE_NONE)
		for _, ally in pairs(allies) do
			if ally ~= target and ally ~= unit then
				local lineInfo = PointToLineDistance(startLocation, endLocation, ally:GetLocation())
				if lineInfo ~= nil and lineInfo.within == true and lineInfo.distance < radius then
					return true
				end
			end
		end
		local enemies = Fu.GetNearbyHeroes(unit, 1600, true, BOT_MODE_NONE)
		for _, enemy in pairs(enemies) do
			if enemy ~= target and enemy ~= unit then
				local lineInfo = PointToLineDistance(startLocation, endLocation, enemy:GetLocation())
				if lineInfo ~= nil and lineInfo.within and lineInfo.distance < radius then
					return true
				end
			end
		end
		return false
	end
	function Fu.IsCreepBetweenMeAndLocation(unit, location, radius)
		local startLocation = unit:GetLocation()
		local endLocation = location
		local bot = GetBot()
		local enemyCreeps = bot:GetNearbyLaneCreeps(1600, true)
		for _, creep in pairs(enemyCreeps) do
			local lineInfo = PointToLineDistance(startLocation, endLocation, creep:GetLocation())
			if lineInfo ~= nil and lineInfo.within and lineInfo.distance < radius then
				return true
			end
		end
		local allyCreeps = bot:GetNearbyLaneCreeps(1600, false)
		for _, creep in pairs(allyCreeps) do
			local lineInfo = PointToLineDistance(startLocation, endLocation, creep:GetLocation())
			if lineInfo ~= nil and lineInfo.within and lineInfo.distance < radius then
				return true
			end
		end
		return false
	end
	function Fu.IsUnitBetweenMeAndLocation(unit, target, location, radius)
		local startLocation = unit:GetLocation()
		local endLocation = location
		for _, otherUnit in pairs(GetUnitList(UNIT_LIST_ALL)) do
			if
				Fu.IsValid(otherUnit)
				and GetUnitToUnitDistance(GetBot(), otherUnit) <= 1600
				and not otherUnit:IsBuilding()
				and not string.find(otherUnit:GetUnitName(), "ward")
				and unit ~= otherUnit
				and target ~= otherUnit
			then
				local hitRadius = radius + otherUnit:GetBoundingRadius()
				local lineInfo = PointToLineDistance(startLocation, endLocation, otherUnit:GetLocation())
				if lineInfo ~= nil and lineInfo.within and lineInfo.distance <= hitRadius then
					return true
				end
			end
		end
		return false
	end
	function Fu.IsCreepBetweenMeAndTarget(unit, target, location, radius)
		local startLocation = unit:GetLocation()
		local endLocation = location
		local creeps = unit:GetNearbyCreeps(1600, false)
		for _, creep in pairs(creeps) do
			local lineInfo = PointToLineDistance(startLocation, endLocation, creep:GetLocation())
			if lineInfo ~= nil and lineInfo.within and lineInfo.distance <= radius then
				return true
			end
		end
		if target:IsHero() then
			creeps = target:GetNearbyCreeps(1600, true)
			for _, creep in pairs(creeps) do
				local lineInfo = PointToLineDistance(startLocation, endLocation, creep:GetLocation())
				if lineInfo ~= nil and lineInfo.within and lineInfo.distance <= radius then
					return true
				end
			end
		end
		creeps = unit:GetNearbyCreeps(1600, true)
		for _, creep in pairs(creeps) do
			local lineInfo = PointToLineDistance(startLocation, endLocation, creep:GetLocation())
			if lineInfo ~= nil and lineInfo.within and lineInfo.distance <= radius then
				return true
			end
		end
		if target:IsHero() then
			creeps = target:GetNearbyCreeps(1600, false)
			for _, creep in pairs(creeps) do
				local lineInfo = PointToLineDistance(startLocation, endLocation, creep:GetLocation())
				if lineInfo ~= nil and lineInfo.within and lineInfo.distance <= radius then
					return true
				end
			end
		end
		return false
	end
	function Fu.IsAllyHeroBetweenMeAndTarget(unit, target, location, radius)
		local startLocation = unit:GetLocation()
		local endLocation = location
		local allies = Fu.GetNearbyHeroes(unit, 1600, false, BOT_MODE_NONE)
		for _, ally in pairs(allies) do
			if ally ~= unit then
				local lineInfo = PointToLineDistance(startLocation, endLocation, ally:GetLocation())
				if lineInfo ~= nil and lineInfo.within and lineInfo.distance <= radius + 50 then
					return true
				end
			end
		end
		local enemies = Fu.GetNearbyHeroes(target, 1600, true, BOT_MODE_NONE)
		for _, enemy in pairs(enemies) do
			if enemy ~= unit and not Fu.IsSuspiciousIllusion(enemy) then
				local lineInfo = PointToLineDistance(startLocation, endLocation, enemy:GetLocation())
				if lineInfo ~= nil and lineInfo.within and lineInfo.distance <= radius + 50 then
					return true
				end
			end
		end
		return false
	end
	function Fu.AdjustLocationWithOffset(location, offset, unit)
		local result = location
		local facing = unit:GetFacing()
		local offsetX = offset * math.cos(facing)
		local offsetY = offset * math.sin(facing)
		result = result + Vector(offsetX, offsetY)
		return result
	end
	function Fu.AdjustLocationWithOffsetTowardsFountain(loc, distance)
		return Fu.Utils.GetOffsetLocationTowardsTargetLocation(loc, Fu.GetTeamFountain(), distance)
	end
	function Fu.GetXUnitsTowardsLocation2(startLocation, targetLocation, distance)
		local direction = (targetLocation - startLocation):Normalized()
		return startLocation + direction * distance
	end
	function Fu.GetRandomLocationWithinDist(center, minDistance, maxDistance)
		local angle = math.random() * 2 * math.pi
		local distance = math.random(minDistance, maxDistance)
		local newX = center.x + distance * math.cos(angle)
		local newY = center.y + distance * math.sin(angle)
		return Vector(newX, newY, center.z)
	end
	function Fu.AreTreesBetween(bot, loc, radius)
		local trees = bot:GetNearbyTrees(GetUnitToLocationDistance(bot, loc))
		for _, tree in pairs(trees) do
			local treeLocation = GetTreeLocation(tree)
			local botLocation = bot:GetLocation()
			local targetLocation = loc
			if treeLocation ~= botLocation then
				local lineA = 1
				local lineB = 1
				local lineC = 0
				if treeLocation.x - botLocation.x == 0 then
					lineB = 0
					lineC = -treeLocation.x
				else
					lineA = -(treeLocation.y - botLocation.y) / (treeLocation.x - botLocation.x)
					lineC = -(treeLocation.y + treeLocation.x * lineA)
				end
				local distanceToLine = math.abs((lineA * targetLocation.x + lineB * targetLocation.y + lineC) / math.sqrt(lineA * lineA + lineB * lineB))
				if distanceToLine <= radius and GetUnitToLocationDistance(bot, loc) > Fu.GetDistance(treeLocation, loc) + 50 then
					return true
				end
			end
		end
		return false
	end
	function Fu.VectorTowards(startLocation, targetLocation, distance)
		local direction = (targetLocation - startLocation):Normalized()
		return startLocation + direction * distance
	end
	function Fu.VectorAway(startLocation, awayFromLocation, distance)
		local direction = (startLocation - awayFromLocation):Normalized()
		return startLocation + direction * distance
	end
	function Fu.GetBestRetreatTree(bot, range)
		local trees = bot:GetNearbyTrees(range)
		local retreatLocation = Fu.VectorTowards(bot:GetLocation(), Fu.GetTeamFountain(), 1000)
		local bestTreeLocation = nil
		local maxDistance = 0
		for _, tree in pairs(trees) do
			local treeLocation = GetTreeLocation(tree)
			if
				not Fu.AreTreesBetween(bot, treeLocation, 100)
				and GetUnitToLocationDistance(bot, treeLocation) > maxDistance
				and GetUnitToLocationDistance(bot, treeLocation) < range
				and Fu.GetDistance(treeLocation, retreatLocation) < 880
			then
				maxDistance = GetUnitToLocationDistance(bot, treeLocation)
				-- Was `bestTreeLocation = loc` (an undefined global), so this never returned a tree and Timber Chain's
				-- retreat branch never fired (hero review, Timbersaw).
				bestTreeLocation = treeLocation
			end
		end
		if bestTreeLocation ~= nil and maxDistance > bot:GetAttackRange() then
			return bestTreeLocation
		end
		return bestTreeLocation
	end
	function Fu.GetBestTree(bot, location, target, range, radius)
		local bestTree = nil
		local trees = bot:GetNearbyTrees(range)
		local minDistance = 10000
		for _, tree in pairs(trees) do
			local treeLocation = GetTreeLocation(tree)
			local botLocation = bot:GetLocation()
			local targetLocation = location
			if treeLocation ~= botLocation then
				local lineA = 1
				local lineB = 1
				local lineC = 0
				if treeLocation.x - botLocation.x == 0 then
					lineB = 0
					lineC = -treeLocation.x
				else
					lineA = -(treeLocation.y - botLocation.y) / (treeLocation.x - botLocation.x)
					lineC = -(treeLocation.y + treeLocation.x * lineA)
				end
				local distanceToLine = math.abs((lineA * targetLocation.x + lineB * targetLocation.y + lineC) / math.sqrt(lineA * lineA + lineB * lineB))
				if
					distanceToLine <= radius
					and minDistance > GetUnitToLocationDistance(target, treeLocation)
					and GetUnitToLocationDistance(target, treeLocation) <= GetUnitToLocationDistance(bot, treeLocation)
				then
					bestTree = tree
					minDistance = GetUnitToLocationDistance(target, treeLocation)
				end
			end
		end
		return bestTree
	end
	function Fu.GetUltLoc(bot, target, manaCost, range, projectileSpeed)
		local velocity = target:GetVelocity()
		local speed = Fu.GetDistance(Vector(0, 0), velocity)
		if speed > 800 then
			velocity = velocity / speed * target:GetCurrentMovementSpeed()
		end
		local botLocation = bot:GetLocation()
		local targetLocation = target:GetLocation()
		local quadA = velocity.x * velocity.x + velocity.y * velocity.y - projectileSpeed * projectileSpeed
		local quadB = -2 * (velocity.x * (botLocation.x - targetLocation.x) + velocity.y * (botLocation.y - targetLocation.y))
		local quadC = (botLocation.x - targetLocation.x) * (botLocation.x - targetLocation.x) + (botLocation.y - targetLocation.y) * (botLocation.y - targetLocation.y)
		local hitTime = math.max(
			(-quadB + math.sqrt(quadB * quadB - 4 * quadA * quadC)) / (2 * quadA),
			(-quadB - math.sqrt(quadB * quadB - 4 * quadA * quadC)) / (2 * quadA)
		)
		local ultLocation = (hitTime + 0.35) * velocity + targetLocation
		if GetUnitToLocationDistance(bot, ultLocation) > range or bot:GetMana() < 100 + manaCost then
			return nil
		end
		if target:GetMovementDirectionStability() < 0.4 or not bot:IsFacingLocation(target:GetLocation(), 60) then
			ultLocation = Fu.VectorTowards(targetLocation, Fu.GetEnemyFountain(), 180)
		end
		if Fu.IsDisabled(target) then
			ultLocation = target:GetLocation()
		end
		return ultLocation
	end
	return J
end
return installPositioning
