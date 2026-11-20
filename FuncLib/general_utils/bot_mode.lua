-- Shared helper: bot mode.
local function installBotMode(Fu)
	function Fu.IsInTeamFight(unit, radius)
		if not Fu.IsUnitValid(unit) then
			return false
		end
		if radius == nil or radius > 1600 then
			radius = 1600
		end
		if unit._tfCache and DotaTime() - unit._tfCache[1] <= 0.2 then
			return unit._tfCache[2]
		end
		local attackingAllies = Fu.GetNearbyHeroes(unit, radius, false, BOT_MODE_ATTACK)
		local isInFight = #attackingAllies >= 2
		unit._tfCache = { DotaTime(), isInFight }
		return isInFight
	end
	function Fu.IsRetreating(unit)
		if not Fu.IsUnitValid(unit) then
			return false
		end
		local mode = unit:GetActiveMode()
		local modeDesire = unit:GetActiveModeDesire()
		local recentlyDamaged = unit:WasRecentlyDamagedByAnyHero(2.0)
		return mode == BOT_MODE_RETREAT and modeDesire > BOT_MODE_DESIRE_MODERATE and unit:DistanceFromFountain() > 0
			or mode == BOT_MODE_EVASIVE_MANEUVERS and recentlyDamaged
			or unit:HasModifier("modifier_bloodseeker_rupture") and recentlyDamaged
			or mode == BOT_MODE_FARM and modeDesire > BOT_MODE_DESIRE_ABSOLUTE
	end
	function Fu.IsGoingOnSomeone(unit)
		if not Fu.IsUnitValid(unit) then
			return false
		end
		local mode = unit:GetActiveMode()
		return mode == BOT_MODE_ROAM
			or mode == BOT_MODE_TEAM_ROAM
			or mode == BOT_MODE_ATTACK
			or mode == BOT_MODE_DEFEND_ALLY
	end
	function Fu.IsDefending(unit)
		if not Fu.IsUnitValid(unit) then
			return false
		end
		local mode = unit:GetActiveMode()
		return mode == BOT_MODE_DEFEND_TOWER_TOP
			or mode == BOT_MODE_DEFEND_TOWER_MID
			or mode == BOT_MODE_DEFEND_TOWER_BOT
	end
	function Fu.IsPushing(unit)
		if not Fu.IsUnitValid(unit) then
			return false
		end
		local mode = unit:GetActiveMode()
		return mode == BOT_MODE_PUSH_TOWER_TOP or mode == BOT_MODE_PUSH_TOWER_MID or mode == BOT_MODE_PUSH_TOWER_BOT
	end
	function Fu.IsLaning(unit)
		if not Fu.IsUnitValid(unit) then
			return false
		end
		local mode = unit:GetActiveMode()
		return mode == BOT_MODE_LANING
	end
	function Fu.IsDoingRoshan(unit)
		if not Fu.IsUnitValid(unit) then
			return false
		end
		return unit:GetActiveMode() == BOT_MODE_ROSHAN
	end
	-- Leave the pit when this hero is low and Roshan is still healthy. Stay out until
	-- 60% HP so they do not step back in on the next heal tick. Huskar wants to be low.
	function Fu.ShouldLeaveRoshanFight(unit)
		if not Fu.IsUnitValid(unit) or not unit:IsAlive() then
			return false
		end
		if unit:GetUnitName() == "npc_dota_hero_huskar" then
			return false
		end
		local hpRatio = Fu.GetHP(unit)
		local roshanHandle = Fu.Utils.GameStates and Fu.Utils.GameStates.roshHandle
		local roshanHpRatio = 1
		if Fu.IsUnitValid(roshanHandle) and roshanHandle:IsAlive() and roshanHandle:CanBeSeen() then
			roshanHpRatio = Fu.GetHP(roshanHandle)
		end
		if roshanHpRatio <= 0.5 then
			unit._roshHoldOut = false
			return false
		end
		if hpRatio < 0.45 then
			if not unit._roshHoldOut and log then
				log(
					string.format(
						"[ROSH] %s leave hp=%.2f rosh=%.2f",
						string.gsub(unit:GetUnitName(), "npc_dota_hero_", ""),
						hpRatio,
						roshanHpRatio
					)
				)
			end
			unit._roshHoldOut = true
		end
		if unit._roshHoldOut and hpRatio < 0.6 then
			return true
		end
		unit._roshHoldOut = false
		return false
	end
	function Fu.IsFarming(unit)
		if not Fu.IsUnitValid(unit) then
			return false
		end
		local mode = unit:GetActiveMode()
		local target = Fu.GetProperTarget(unit)
		return mode == BOT_MODE_FARM
			or target ~= nil and target:IsAlive() and target:GetTeam() == TEAM_NEUTRAL and not Fu.IsRoshan(target)
	end
	function Fu.IsTeamActivityCount(unit, count)
		local teamPlayers = GetTeamPlayers(GetTeam())
		for i = 1, #teamPlayers do
			local member = GetTeamMember(i)
			if member ~= nil and member:IsAlive() then
				if Fu.GetAllyCount(member, 1600) >= count then
					return true
				end
			end
		end
		return false
	end
	function Fu.GetSpecialModeAllies(unit, range, targetMode)
		if not Fu.IsUnitValid(unit) then
			return {}
		end
		local allies = {}
		local teamPlayers = GetTeamPlayers(GetTeam())
		for i = 1, #teamPlayers do
			local member = GetTeamMember(i)
			if member ~= nil and member:IsAlive() then
				if member:GetActiveMode() == targetMode and GetUnitToUnitDistance(member, unit) <= range then
					table.insert(allies, member)
				end
			end
		end
		return allies
	end
	function Fu.GetSpecialModeAlliesCount(targetMode)
		local allies = Fu.GetSpecialModeAllies(GetBot(), 99999, targetMode)
		return #allies
	end
	function Fu.GetTeamFightLocation(unit)
		if not Fu.IsUnitValid(unit) then
			return nil
		end
		local fightLocation = nil
		local teamPlayers = GetTeamPlayers(GetTeam())
		for i = 1, #teamPlayers do
			local member = GetTeamMember(i)
			if
				member ~= nil
				and member:IsAlive()
				and Fu.IsInTeamFight(member, 1500)
				and Fu.GetEnemyCount(member, 1400) >= 2
			then
				local allies = Fu.GetSpecialModeAllies(member, 1400, BOT_MODE_ATTACK)
				fightLocation = Fu.GetCenterOfUnits(allies)
				break
			end
		end
		return fightLocation
	end
	function Fu.GetTeamFightAlliesCount(unit)
		if not Fu.IsUnitValid(unit) then
			return 0
		end
		local teamPlayers = GetTeamPlayers(GetTeam())
		local alliesCount = 0
		for i = 1, #teamPlayers do
			local member = GetTeamMember(i)
			if
				member ~= nil
				and member:IsAlive()
				and Fu.IsInTeamFight(member, 1200)
				and Fu.GetEnemyCount(member, 1400) >= 2
			then
				alliesCount = Fu.GetSpecialModeAlliesCount(BOT_MODE_ATTACK)
				break
			end
		end
		return alliesCount
	end
	function Fu.IsDoingTormentor(unit)
		if not Fu.IsUnitValid(unit) then
			return false
		end
		local mode = unit:GetActiveMode()
		return mode == BOT_MODE_SIDE_SHOP or mode == BOT_MODE_WATCHER
	end
	function Fu.IsAnyAllyDefending(unit, lane)
		for _, allyHero in pairs(GetUnitList(UNIT_LIST_ALLIED_HEROES)) do
			if Fu.IsValidHero(allyHero) and Fu.IsNotSelf(unit, allyHero) then
				local mode = allyHero:GetActiveMode()
				if
					mode == BOT_MODE_DEFEND_TOWER_TOP and lane == LANE_TOP
					or mode == BOT_MODE_DEFEND_TOWER_MID and lane == LANE_MID
					or mode == BOT_MODE_DEFEND_TOWER_BOT and lane == LANE_BOT
				then
					return true
				end
			end
		end
		return false
	end
end
return installBotMode
