-- Shared helper: targeting.
local function installTargeting(Fu)
	function Fu.GetVulnerableWeakestUnit(bot, isHero, isEnemy, radius)
		local units = {}
		if isHero then
			units = Fu.GetNearbyHeroes(bot, radius, isEnemy, BOT_MODE_NONE)
		else
			units = bot:GetNearbyLaneCreeps(radius, isEnemy)
		end
		return Fu.GetAttackableWeakestUnitFromList(bot, units)
	end
	function Fu.GetVulnerableUnitNearLoc(bot, isHero, isEnemy, searchRadius, radius, location)
		local units = {}
		local weakestUnit = nil
		local lowestHealth = 10000
		if isHero then
			units = Fu.GetNearbyHeroes(bot, searchRadius, isEnemy, BOT_MODE_NONE)
		else
			units = bot:GetNearbyLaneCreeps(searchRadius, isEnemy)
		end
		for _, unit in pairs(units) do
			if GetUnitToLocationDistance(unit, location) < radius and unit:GetHealth() < lowestHealth and Fu.CanCastOnNonMagicImmune(unit) then
				weakestUnit = unit
				lowestHealth = unit:GetHealth()
			end
		end
		return weakestUnit
	end
	function Fu.GetAoeEnemyHeroLocation(bot, castRange, radius, minCount)
		local aoe = bot:FindAoELocation(true, true, bot:GetLocation(), castRange, radius, 0, 0)
		if aoe.count >= minCount then
			local enemyList = Fu.GetEnemyList(bot, 1600)
			local count = 0
			for _, enemy in pairs(enemyList) do
				if GetUnitToLocationDistance(enemy, aoe.targetloc) <= radius and not enemy:IsMagicImmune() then
					count = count + 1
				end
			end
			if count >= minCount then
				return aoe.targetloc
			end
		end
		return nil
	end
	function Fu.GetProperTarget(unit)
		local target = nil
		if unit:GetTeam() == GetBot():GetTeam() then
			target = unit:GetTarget()
		end
		if target == nil and unit:CanBeSeen() then
			target = unit:GetAttackTarget()
		end
		if target ~= nil and target:GetTeam() == unit:GetTeam() and (target:IsHero() or target:IsBuilding()) then
			target = nil
		end
		return target
	end
	function Fu.GetMostHpUnit(units)
		local mostHpUnit = nil
		local mostHp = 0
		for _, unit in pairs(units) do
			local health = unit:GetHealth()
			if unit ~= nil and not Fu.IsRoshan(unit) and not Fu.IsTormentor(unit) and health > mostHp then
				mostHpUnit = unit
				mostHp = health
			end
		end
		return mostHpUnit
	end
	-- Best creep to eat (Hand of Midas, Doom's Devour, Night Stalker's Midnight Feast): highest level, then
	-- highest max HP. maxLevel caps the level (Devour creep_level), nil = no cap. Never Roshan / Tormentor,
	-- ancients only when allowAncient, never dominated or allied-controlled units.
	function Fu.GetBestCreepToEat(units, maxLevel, allowAncient)
		local best, bestLvl, bestHp = nil, -1, -1
		for _, unit in pairs(units or {}) do
			if
				Fu.IsValid(unit)
				and Fu.CanBeAttacked(unit)
				and not Fu.IsRoshan(unit)
				and not Fu.IsTormentor(unit)
				and not unit:IsDominated()
				and (allowAncient or not unit:IsAncientCreep())
				and (maxLevel == nil or unit:GetLevel() <= maxLevel)
			then
				local lvl, hp = unit:GetLevel(), unit:GetMaxHealth()
				if lvl > bestLvl or lvl == bestLvl and hp > bestHp then
					best, bestLvl, bestHp = unit, lvl, hp
				end
			end
		end
		return best
	end
	function Fu.GetLeastHpUnit(units)
		local leastHpUnit = nil
		local leastHp = 999999
		for _, unit in pairs(units) do
			local health = unit:GetHealth()
			if health < leastHp then
				leastHpUnit = unit
				leastHp = health
			end
		end
		return leastHpUnit
	end
	function Fu.GetAttackableWeakestUnit(bot, radius, isHero, isEnemy)
		local units = {}
		if radius > 1600 then
			radius = 1600
		end
		if isHero then
			units = Fu.GetNearbyHeroes(bot, radius, isEnemy, BOT_MODE_NONE)
		else
			units = bot:GetNearbyLaneCreeps(radius, isEnemy)
		end
		return Fu.GetAttackableWeakestUnitFromList(bot, units)
	end
	function Fu.GetAttackableWeakestUnitFromList(bot, units)
		if bot == nil then
			bot = GetBot()
		end
		local weakestUnit = nil
		local lowestScore = math.huge
		local attackRange = bot:GetAttackRange()
		for _, unit in pairs(units) do
			if Fu.IsValidTarget(unit) then
				local health = unit:GetHealth()
				local offensivePower = 0
				local distance = GetUnitToUnitDistance(bot, unit)
				if Fu.IsValidHero(unit) then
					offensivePower = unit:GetRawOffensivePower()
				end
				if
					Fu.IsValid(unit)
					and not unit:IsAttackImmune()
					and not unit:IsInvulnerable()
					and not Fu.HasForbiddenModifier(unit)
					and not Fu.IsSuspiciousIllusion(unit)
					and not Fu.CannotBeKilled(bot, unit)
				then
					local healthWeight = 0.7
					local powerWeight = 0.3
					local score = health * healthWeight - offensivePower * powerWeight
					if score < lowestScore then
						lowestScore = score
						weakestUnit = unit
					end
				end
			end
		end
		return weakestUnit
	end
	function Fu.ConsiderTarget()
		local bot = GetBot()
		if not Fu.IsRunning(bot) or bot:HasModifier("modifier_item_hurricane_pike_range") then
			return
		end
		local target = Fu.GetProperTarget(bot)
		if not Fu.IsValidHero(target) then
			return
		end
		local attackRange = bot:GetAttackRange() + 69
		if attackRange > 1600 then
			attackRange = 1600
		end
		if attackRange < 300 then
			attackRange = 350
		end
		local weakestHero = Fu.GetAttackableWeakestUnit(bot, attackRange, true, true)
		if Fu.IsValidHero(weakestHero) and (GetUnitToUnitDistance(target, bot) > attackRange or Fu.HasForbiddenModifier(target)) then
			bot:SetTarget(weakestHero)
			return
		end
	end
	function Fu.GetMostHPPercent(units, allowMagicImmune)
		local mostHpPercent = 0
		local bestUnit = nil
		for _, unit in pairs(units) do
			local hpPercent = unit:GetHealth() / unit:GetMaxHealth()
			if (allowMagicImmune and Fu.CanCastOnMagicImmune(unit) or not allowMagicImmune and Fu.CanCastOnNonMagicImmune(unit)) and hpPercent > mostHpPercent then
				bestUnit = unit
				mostHpPercent = hpPercent
			end
		end
		return bestUnit
	end
	function Fu.GetCanBeKilledUnit(units, damage, damageType, allowMagicImmune)
		local killableUnit = nil
		for _, unit in pairs(units) do
			if
				(allowMagicImmune and Fu.CanCastOnMagicImmune(unit) or not allowMagicImmune and Fu.CanCastOnNonMagicImmune(unit)) and Fu.CanKillTarget(unit, damage, damageType)
			then
				killableUnit = unit
			end
		end
		return killableUnit
	end
	function Fu.GetClosestUnit(units)
		local closestUnit = nil
		if units ~= nil and #units >= 1 then
			return units[1]
		end
		return closestUnit
	end
	function Fu.GetStrongestUnit(radius, bot, isEnemy, allowMagicImmune, duration)
		local nearbyHeroes = Fu.GetNearbyHeroes(bot, radius, isEnemy, BOT_MODE_NONE)
		local strongestUnit = nil
		local highestDamage = 0
		for i = 1, #nearbyHeroes do
			if
				Fu.IsValidTarget(nearbyHeroes[i])
				and Fu.IsValidTarget(bot)
				and (
					allowMagicImmune == true and Fu.CanCastOnMagicImmune(nearbyHeroes[i]) == true
					or allowMagicImmune == false and Fu.CanCastOnNonMagicImmune(nearbyHeroes[i]) == true
				)
			then
				local estimatedDamage = nearbyHeroes[i]:GetEstimatedDamageToTarget(true, bot, duration, DAMAGE_TYPE_ALL)
				if estimatedDamage > highestDamage then
					highestDamage = estimatedDamage
					strongestUnit = nearbyHeroes[i]
				end
			end
		end
		return strongestUnit
	end
	function Fu.GetStrongestEnemyHero(heroList)
		local strongestHero = nil
		local highestHealth = 0
		for _, enemy in pairs(heroList) do
			if Fu.IsValidTarget(enemy) and Fu.IsNotImmune(enemy) and not Fu.IsSuspiciousIllusion(enemy) then
				if enemy:GetHealth() > highestHealth then
					strongestHero = enemy
					highestHealth = enemy:GetHealth()
				end
			end
		end
		return strongestHero
	end
	function Fu.GetWeakestUnit(units)
		return Fu.GetAttackableWeakestUnitFromList(nil, units)
	end
	function Fu.GetHeroCountAttackingTarget(heroes, target)
		local count = 0
		for _, hero in pairs(heroes) do
			if
				Fu.IsValidHero(hero)
				and Fu.IsInRange(hero, target, 1600)
				and Fu.IsGoingOnSomeone(hero)
				and hero:CanBeSeen()
				and (hero:GetAttackTarget() == target or hero:GetTarget() == target)
				and not Fu.IsSuspiciousIllusion(hero)
			then
				count = count + 1
			end
		end
		return count
	end
end
return installTargeting
