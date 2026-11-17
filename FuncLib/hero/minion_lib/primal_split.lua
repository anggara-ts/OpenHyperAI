-- Thinking for summoned units: primal split.
-- Accidental globals made file-local (#13): every bot shares one Lua state, so these were shared.
local DispelMagic, WindWalk, DispelMagicTarget, CycloneTarget, HurlBoulder, HurlBoulderTarget, AstralPull
local AstralPullDesire, AttackUnits, UseDispelMagic, UseCyclone, UseWindWalk, UseHurlBoulder, UseAstralPull
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local MinionUtils = require(GetScriptDirectory() .. "/FuncLib/hero/minion_lib/utils")
local X = {}
local bot = nil
local dispelMagicDesire, cycloneDesire, windWalkDesire, hurlBoulderDesire = 0, 0, 0, 0
local botTarget
function X.MinionThink(ownerBot, minion)
	bot = ownerBot
	botTarget = Fu.GetProperTarget(bot)
	if Fu.IsValid(minion) then
		if string.find(minion:GetUnitName(), "npc_dota_brewmaster_storm") then
			if minion:IsUsingAbility() then
				return
			end
			DispelMagic = minion:GetAbilityByName("brewmaster_storm_dispel_magic")
			Cyclone = minion:GetAbilityByName("brewmaster_storm_cyclone")
			WindWalk = minion:GetAbilityByName("brewmaster_storm_wind_walk")
			dispelMagicDesire, DispelMagicTarget = UseDispelMagic(minion)
			if dispelMagicDesire > 0 then
				minion:Action_UseAbilityOnLocation(DispelMagic, DispelMagicTarget)
				return
			end
			cycloneDesire, CycloneTarget = UseCyclone(minion)
			if cycloneDesire > 0 then
				minion:Action_UseAbilityOnEntity(Cyclone, CycloneTarget)
				return
			end
			windWalkDesire = UseWindWalk(minion)
			if windWalkDesire > 0 then
				minion:Action_UseAbility(WindWalk)
				return
			end
		end
		if string.find(minion:GetUnitName(), "npc_dota_brewmaster_earth") then
			if minion:IsUsingAbility() then
				return
			end
			HurlBoulder = minion:GetAbilityByName("brewmaster_earth_hurl_boulder")
			hurlBoulderDesire, HurlBoulderTarget = UseHurlBoulder(minion)
			if hurlBoulderDesire > 0 then
				minion:Action_UseAbilityOnEntity(HurlBoulder, HurlBoulderTarget)
				return
			end
			if minion:GetHealth() <= minion:GetMaxHealth() * 0.25 then
				minion:Action_MoveToLocation(Fu.GetTeamFountain())
				return
			end
			local strongestAlly = nil
			local maxAttackDamage = 0
			for i = 1, 5 do
				local teamMember = GetTeamMember(i)
				if Fu.IsValidHero(teamMember) and teamMember:IsAlive() then
					local attackDamage = teamMember:GetAttackDamage()
					if attackDamage > maxAttackDamage then
						maxAttackDamage = attackDamage
						strongestAlly = teamMember
					end
				end
			end
			if strongestAlly ~= nil then
				local allyEnemies = strongestAlly:GetNearbyHeroes(1600, true, BOT_MODE_NONE)
				if allyEnemies and #allyEnemies >= 1 then
					minion:Action_AttackUnit(Fu.GetWeakestUnit(allyEnemies), false)
					return
				end
				if GetUnitToUnitDistance(minion, strongestAlly) > 400 then
					minion:Action_MoveToLocation(strongestAlly:GetLocation())
					return
				end
			end
		end
		if string.find(minion:GetUnitName(), "npc_dota_brewmaster_fire") then
		end
		if string.find(minion:GetUnitName(), "npc_dota_brewmaster_void") then
			if minion:IsUsingAbility() then
				return
			end
			AstralPull = minion:GetAbilityByName("brewmaster_void_astral_pull")
			AstralPullDesire = UseAstralPull(minion)
			if AstralPullDesire > 0 then
				minion:Action_UseAbility(AstralPull)
				return
			end
		end
		local attackTarget = AttackUnits(minion)
		if attackTarget ~= nil then
			minion:Action_AttackUnit(attackTarget, false)
			return
		end
		local moveDesire, moveLocation = ConsiderMove(minion)
		if moveDesire > 0 then
			minion:Action_MoveToLocation(moveLocation)
			return
		end
	end
end
function AttackUnits(minion)
	local botMode = bot:GetActiveMode()
	if Fu.IsGoingOnSomeone(bot) and Fu.IsValidHero(botTarget) then
		if GetUnitToUnitDistance(minion, botTarget) <= 1600 then
			return botTarget
		end
	end
	if
		botMode == BOT_MODE_RETREAT
		or botMode == BOT_MODE_SECRET_SHOP
		or botMode == BOT_MODE_WARD
		or botMode == BOT_MODE_RUNE
	then
		local nearbyEnemies = minion:GetNearbyHeroes(1200, true, BOT_MODE_NONE)
		if nearbyEnemies and #nearbyEnemies >= 1 then
			return Fu.GetWeakestUnit(nearbyEnemies)
		end
		local nearbyCreeps = minion:GetNearbyLaneCreeps(1600, true)
		if nearbyCreeps and #nearbyCreeps >= 1 then
			return Fu.GetWeakestUnit(nearbyCreeps)
		end
		return nil
	end
	if botMode == BOT_MODE_LANING then
		local enemyTowers = minion:GetNearbyTowers(800, true)
		for _, tower in pairs(enemyTowers) do
			if Fu.IsValidBuilding(tower) then
				local towerTarget = tower:GetAttackTarget()
				if towerTarget == minion or GetUnitToUnitDistance(minion, tower) <= 700 then
					return nil
				end
			end
		end
		local botAttackTarget = bot:GetAttackTarget()
		if botAttackTarget ~= nil then
			return botAttackTarget
		end
		local nearbyEnemies = minion:GetNearbyHeroes(800, true, BOT_MODE_NONE)
		if nearbyEnemies and #nearbyEnemies >= 1 then
			for _, enemyHero in pairs(nearbyEnemies) do
				if Fu.IsValidHero(enemyHero) and enemyHero:GetAttackTarget() == minion then
					return nil
				end
			end
			return Fu.GetWeakestUnit(nearbyEnemies)
		end
		return nil
	end
	if botMode == BOT_MODE_FARM then
		local nearbyCreeps = minion:GetNearbyLaneCreeps(1600, true)
		if nearbyCreeps and #nearbyCreeps >= 1 then
			return Fu.GetWeakestUnit(nearbyCreeps)
		end
		nearbyCreeps = minion:GetNearbyCreeps(1600, true)
		if nearbyCreeps and #nearbyCreeps >= 1 then
			return Fu.GetWeakestUnit(nearbyCreeps)
		end
		return nil
	end
	if Fu.IsPushing(bot) then
		local nearbyCreeps = minion:GetNearbyLaneCreeps(1600, true)
		if nearbyCreeps and #nearbyCreeps >= 1 then
			return Fu.GetWeakestUnit(nearbyCreeps)
		end
		local enemyBarracks = minion:GetNearbyBarracks(1600, true)
		if enemyBarracks then
			for _, barracks in pairs(enemyBarracks) do
				if
					Fu.IsValidBuilding(barracks)
					and not barracks:IsInvulnerable()
					and string.find(barracks:GetUnitName(), "melee")
				then
					return barracks
				end
			end
			for _, barracks in pairs(enemyBarracks) do
				if Fu.IsValidBuilding(barracks) and not barracks:IsInvulnerable() then
					return barracks
				end
			end
		end
		local enemyTowers = minion:GetNearbyTowers(1600, true)
		if
			enemyTowers
			and #enemyTowers >= 1
			and Fu.IsValidBuilding(enemyTowers[1])
			and not enemyTowers[1]:IsInvulnerable()
		then
			return enemyTowers[1]
		end
		local enemyAncient = GetAncient(GetOpposingTeam())
		if
			enemyAncient
			and Fu.IsValidBuilding(enemyAncient)
			and not enemyAncient:IsInvulnerable()
			and GetUnitToUnitDistance(minion, enemyAncient) <= 1600
		then
			return enemyAncient
		end
		return nil
	end
	if Fu.IsDefending(bot) then
		local nearbyCreeps = minion:GetNearbyLaneCreeps(1600, true)
		if nearbyCreeps and #nearbyCreeps >= 1 then
			return Fu.GetWeakestUnit(nearbyCreeps)
		end
		return nil
	end
	if botMode == BOT_MODE_ROSHAN then
		local nearbyCreeps = minion:GetNearbyCreeps(1600, true)
		if nearbyCreeps then
			for _, creep in pairs(nearbyCreeps) do
				if Fu.IsRoshan(creep) then
					return creep
				end
			end
		end
		return nil
	end
	local nearbyEnemies = minion:GetNearbyHeroes(1600, true, BOT_MODE_NONE)
	if nearbyEnemies and #nearbyEnemies >= 1 then
		return Fu.GetWeakestUnit(nearbyEnemies)
	end
	local nearbyCreeps = minion:GetNearbyLaneCreeps(1600, true)
	if nearbyCreeps and #nearbyCreeps >= 1 then
		return nearbyCreeps[1]
	end
	local enemyTowers = minion:GetNearbyTowers(1600, true)
	if enemyTowers and #enemyTowers >= 1 and Fu.IsValidBuilding(enemyTowers[1]) then
		return enemyTowers[1]
	end
	return nil
end
function UseDispelMagic(minion)
	if not DispelMagic:IsFullyCastable() then
		return 0, nil
	end
	if Fu.CanNotUseAbility(minion) then
		return 0, nil
	end
	local castRange = DispelMagic:GetCastRange()
	local radius = DispelMagic:GetSpecialValueInt("radius")
	local aoeLocation = bot:FindAoELocation(true, true, minion:GetLocation(), castRange, radius / 2, 0, 0)
	if aoeLocation.count >= 2 then
		return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
	end
	return 0, nil
end
function UseCyclone(minion)
	if not Cyclone:IsFullyCastable() then
		return 0, nil
	end
	if Fu.CanNotUseAbility(minion) then
		return 0, nil
	end
	local castRange = Cyclone:GetCastRange()
	local nearbyEnemies = minion:GetNearbyHeroes(castRange + 500, true, BOT_MODE_NONE)
	local stunnableEnemies = Fu.FilterEnemiesForStun(nearbyEnemies)
	local cycloneTarget = nil
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidTarget(enemyHero)
			and enemyHero:IsChanneling()
			and Fu.IsNotImmune(enemyHero)
			and not Fu.IsReflectingSpells(enemyHero)
		then
			cycloneTarget = enemyHero
			break
		end
	end
	if cycloneTarget == nil and Fu.IsGoingOnSomeone(bot) then
		local ownerTarget = botTarget
		for _, enemyHero in pairs(stunnableEnemies) do
			if
				Fu.IsValidHero(enemyHero)
				and enemyHero ~= ownerTarget
				and not enemyHero:IsMagicImmune()
				and not Fu.IsReflectingSpells(enemyHero)
			then
				cycloneTarget = enemyHero
				break
			end
		end
	end
	if cycloneTarget == nil and #stunnableEnemies >= 2 then
		local strongestEnemy = Fu.GetStrongestEnemyHero(stunnableEnemies)
		if
			strongestEnemy ~= nil
			and not strongestEnemy:IsMagicImmune()
			and not Fu.IsReflectingSpells(strongestEnemy)
		then
			cycloneTarget = strongestEnemy
		end
	end
	if cycloneTarget ~= nil then
		return BOT_ACTION_DESIRE_HIGH, cycloneTarget
	end
	return 0, nil
end
function UseWindWalk(minion)
	if not WindWalk:IsFullyCastable() then
		return 0, nil
	end
	if DispelMagic:IsFullyCastable() then
		return 0, nil
	end
	if Cyclone:IsFullyCastable() then
		return 0, nil
	end
	if Fu.CanNotUseAbility(minion) then
		return 0, nil
	end
	return BOT_ACTION_DESIRE_HIGH
end
function UseHurlBoulder(minion)
	if not HurlBoulder:IsFullyCastable() then
		return 0, nil
	end
	if Fu.CanNotUseAbility(minion) then
		return 0, nil
	end
	local castRange = HurlBoulder:GetCastRange()
	local damage = HurlBoulder:GetSpecialValueInt("damage")
	local nearbyEnemies = minion:GetNearbyHeroes(castRange, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidHero(enemyHero)
			and not enemyHero:IsMagicImmune()
			and not Fu.IsReflectingSpells(enemyHero)
			and (enemyHero:IsChanneling() or damage > enemyHero:GetHealth())
		then
			return BOT_ACTION_DESIRE_HIGH, enemyHero
		end
	end
	if
		Fu.IsGoingOnSomeone(bot)
		and Fu.IsValidHero(botTarget)
		and Fu.IsInRange(minion, botTarget, castRange)
		and not botTarget:IsMagicImmune()
		and not Fu.IsReflectingSpells(botTarget)
		and not Fu.IsDisabled(botTarget)
	then
		return BOT_ACTION_DESIRE_HIGH, botTarget
	end
	if Fu.IsRetreating(bot) then
		local strongestEnemy = Fu.GetStrongestEnemyHero(nearbyEnemies)
		if
			strongestEnemy ~= nil
			and not strongestEnemy:IsMagicImmune()
			and not Fu.IsReflectingSpells(strongestEnemy)
		then
			return BOT_ACTION_DESIRE_HIGH, strongestEnemy
		end
	end
	local allyTowers = minion:GetNearbyTowers(1600, false)
	for _, tower in pairs(allyTowers) do
		local towerTarget = tower:GetAttackTarget()
		if
			Fu.IsValidHero(towerTarget)
			and not towerTarget:IsMagicImmune()
			and not Fu.IsDisabled(towerTarget)
			and not Fu.IsReflectingSpells(towerTarget)
		then
			return BOT_ACTION_DESIRE_HIGH, towerTarget
		end
	end
	return 0, nil
end
function UseAstralPull(minion)
	if not AstralPull:IsFullyCastable() then
		return 0, nil
	end
	if Fu.CanNotUseAbility(minion) then
		return 0, nil
	end
	local searchRange = 800
	local damage = AstralPull:GetAbilityDamage()
	local nearbyEnemies = minion:GetNearbyHeroes(searchRange, true, BOT_MODE_NONE)
	if nearbyEnemies ~= nil and #nearbyEnemies >= 1 then
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValidHero(enemyHero)
				and not Fu.IsReflectingSpells(enemyHero)
				and (enemyHero:IsChanneling() or damage > enemyHero:GetHealth())
			then
				return BOT_ACTION_DESIRE_HIGH, enemyHero
			end
		end
	end
	return 0, nil
end
function ConsiderMove(minion)
	if MinionUtils.CantMove(minion) then
		return BOT_MODE_DESIRE_NONE, 0
	end
	local botMode = bot:GetActiveMode()
	if botMode == BOT_MODE_LANING then
		local enemyTowers = minion:GetNearbyTowers(800, true)
		for _, tower in pairs(enemyTowers) do
			if Fu.IsValidBuilding(tower) then
				local towerTarget = tower:GetAttackTarget()
				if towerTarget == minion or GetUnitToUnitDistance(minion, tower) <= 700 then
					return BOT_ACTION_DESIRE_HIGH, Fu.GetTeamFountain()
				end
			end
		end
		local nearbyEnemies = minion:GetNearbyHeroes(800, true, BOT_MODE_NONE)
		for _, enemyHero in pairs(nearbyEnemies or {}) do
			if Fu.IsValidHero(enemyHero) and enemyHero:GetAttackTarget() == minion then
				return BOT_ACTION_DESIRE_HIGH, bot:GetLocation()
			end
		end
	end
	local distanceToBot = GetUnitToUnitDistance(minion, bot)
	if distanceToBot > 200 then
		return BOT_ACTION_DESIRE_HIGH, bot:GetLocation()
	end
	return BOT_ACTION_DESIRE_HIGH, bot:GetLocation() + RandomVector(200)
end
return X
