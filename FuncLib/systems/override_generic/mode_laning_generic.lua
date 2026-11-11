-- Override for the built-in mode_laning_generic mode.
local a = require(GetScriptDirectory() .. "/FuncLib/func_utils")
BotsInit = require("game/botsinit")
local b = BotsInit.CreateGeneric()
local c = GetBot()
function b.OnStart() end
function b.OnEnd() end
local d
local e, f, g
local h = 0
function b.GetDesire()
	local i = c.isBear or string.find(c:GetUnitName(), "lone_druid_bear")
	if i then
		local j = require(GetScriptDirectory() .. "/FuncLib/systems/utils")
		local k = j.GetLoneDruid(c)
		if k and k.hero and a.IsValidHero(k.hero) and k.hero:IsAlive() then
			local l = k.hero:GetActiveMode()
			if
				l == BOT_MODE_ATTACK
				or l == BOT_MODE_DEFEND_ALLY
				or l == BOT_MODE_TEAM_ROAM
				or l == BOT_MODE_ROSHAN
				or l == BOT_MODE_FARM
			then
				return BOT_MODE_DESIRE_NONE
			end
			local m = a.GetProperTarget(k.hero)
			if a.IsValidHero(m) and GetUnitToUnitDistance(c, m) < 1200 then
				return BOT_MODE_DESIRE_NONE
			end
		end
	end
	e, f = ConsiderTango()
	if e > 0 then
		return BOT_MODE_DESIRE_ABSOLUTE
	end
	if not d then
		d = GetBotTargetLane()
	end
	if GetGameMode() == GAMEMODE_1V1MID or GetGameMode() == GAMEMODE_MO then
		return 1
	end
	local n = DotaTime()
	local o = c:GetLevel()
	if GetGameMode() == 23 then
		n = n * 1.65
	end
	if n <= 10 then
		c.isInLanePhase = true
		return 0.268
	end
	if n <= 9 * 60 and o <= 7 then
		c.isInLanePhase = true
		return 0.446
	end
	if n <= 12 * 60 and o <= 11 then
		c.isInLanePhase = true
		return 0.369
	end
	if o <= 15 and a.GetCoresAverageNetworth() < 12000 then
		c.isInLanePhase = true
		return 0.228
	end
	c.isInLanePhase = false
	return BOT_MODE_DESIRE_VERYLOW
end
function GetBotTargetLane()
	if IsLanMode and IsLanMode() then
		local p = c:GetAssignedLane()
		if p == LANE_TOP or p == LANE_MID or p == LANE_BOT then
			d = p
			return d
		end
	end
	local q = a.GetPosition(c)
	if GetTeam() == TEAM_RADIANT then
		if q == 2 then
			d = LANE_MID
		elseif q == 1 or q == 5 then
			d = LANE_BOT
		elseif q == 3 or q == 4 then
			d = LANE_TOP
		end
	else
		if q == 2 then
			d = LANE_MID
		elseif q == 1 or q == 5 then
			d = LANE_TOP
		elseif q == 3 or q == 4 then
			d = LANE_BOT
		end
	end
	return d
end
function b.Think()
	if not c:IsAlive() or a.CanNotUseAction(c) or c:IsChanneling() or c:IsDisarmed() then
		return
	end
	local r = c:GetAttackRange()
	local s = d or c:GetAssignedLane()
	local t = c:GetNearbyLaneCreeps(1200, false)
	local u = c:GetNearbyLaneCreeps(1200, true)
	local v = c:GetNearbyHeroes(1600, true, BOT_MODE_NONE)
	local w = c:GetNearbyTowers(1200, true)
	if e and e > 0 and f then
		local x = c:GetItemInSlot(g)
		c:Action_UseAbilityOnTree(x, f)
		return
	end
	if
		c:WasRecentlyDamagedByAnyHero(2.0) and #a.GetHeroesTargetingUnit(v, c) >= 1
		or a.IsValidBuilding(w[1]) and w[1]:GetAttackTarget() == c
		or c:WasRecentlyDamagedByCreep(2.0)
			and not (c:HasModifier("modifier_tower_aura") or c:HasModifier("modifier_tower_aura_bonus"))
			and #t > 0
	then
		local y = a.AdjustLocationWithOffsetTowardsFountain(c:GetLocation(), 500)
		c:Action_MoveToLocation(y + RandomVector(50))
		return
	end
	if c:WasRecentlyDamagedByTower(1.0) and #u > 0 then
		local z = c:GetNearbyTowers(750, true)
		if #z > 0 then
			for A, B in pairs(u) do
				if a.IsValid(B) and GetUnitToUnitDistance(B, z[1]) < 700 then
					c:Action_AttackUnit(B, true)
					return
				end
			end
		end
	end
	if a.IsValidBuilding(w[1]) then
		local C = GetUnitToUnitDistance(c, w[1])
		if C < 800 and #u < 3 then
			c:Action_MoveToLocation(a.VectorAway(c:GetLocation(), w[1]:GetLocation(), 950) + RandomVector(75))
			return
		end
		if C < 900 and c:WasRecentlyDamagedByTower(2.0) then
			c:Action_MoveToLocation(a.VectorAway(c:GetLocation(), w[1]:GetLocation(), 950))
			return
		end
	end
	local bSupport = a.GetPosition(c) >= 4
	-- Supports deny first and leave the last hits to their core.
	if bSupport then
		local denyCreep = GetBestDenyCreep(t)
		if a.IsValid(denyCreep) then
			c:Action_AttackUnit(denyCreep, true)
			return
		end
	end
	local D = GetBestLastHitCreep(u)
	if a.IsValid(D) then
		local i = c.isBear or string.find(c:GetUnitName(), "lone_druid_bear")
		local bCanLastHit
		if bSupport then
			-- Do not compete with a core for last hits.
			bCanLastHit = not a.IsThereNonSelfCoreNearby(1000)
		else
			local E = a.GetLanePartner(c)
			bCanLastHit = i
				or E == nil
				or a.IsCore(c)
				or not a.IsCore(c) and a.IsCore(E) and (not E:IsAlive() or not a.IsInRange(c, E, 800))
		end
		if bCanLastHit then
			if GetUnitToUnitDistance(c, D) > r then
				c:Action_MoveToUnit(D)
			else
				c:Action_AttackUnit(D, true)
			end
			return
		end
	end
	-- Cores deny after looking for a last hit. Supports already denied above.
	if not bSupport then
		local F = GetBestDenyCreep(t)
		if a.IsValid(F) then
			c:Action_AttackUnit(F, true)
			return
		end
	end
	-- Aggressive poke on our half; never chase into enemy T1 (rune/tower bait).
	if a.IsInLaningPhase and a.IsInLaningPhase() and a.GetHP(c) >= 0.55 then
		if not (c:WasRecentlyDamagedByAnyHero(1.0) and a.GetHP(c) < 0.75) then
			local function laneT1(team, lane)
				if lane == LANE_TOP then
					return GetTower(team, TOWER_TOP_1)
				elseif lane == LANE_MID then
					return GetTower(team, TOWER_MID_1)
				elseif lane == LANE_BOT then
					return GetTower(team, TOWER_BOT_1)
				end
				return nil
			end
			local allyT1 = laneT1(GetTeam(), s)
			local enemyT1 = laneT1(GetOpposingTeam(), s)
			local atk = c:GetAttackRange()
			if allyT1 ~= nil and allyT1:IsAlive() then
				for _, enemy in pairs(v or {}) do
					if
						a.IsValidHero(enemy)
						and a.CanBeAttacked(enemy)
						and not a.IsSuspiciousIllusion(enemy)
						and a.IsInRange(c, enemy, atk + 250)
					then
						local selfUnderTower = enemyT1 ~= nil
							and enemyT1:IsAlive()
							and GetUnitToUnitDistance(c, enemyT1) < (enemyT1:GetAttackRange() or 700) + 180
						local enemyUnderTower = enemyT1 ~= nil
							and enemyT1:IsAlive()
							and GetUnitToUnitDistance(enemy, enemyT1) < (enemyT1:GetAttackRange() or 700) + 250
						if
							not selfUnderTower
							and not enemyUnderTower
							and GetUnitToUnitDistance(enemy, allyT1) <= 3800
							and GetUnitToUnitDistance(c, allyT1) <= 4000
						then
							local now = DotaTime()
							if c.sOffsideHarassChatTime == nil or now - c.sOffsideHarassChatTime >= 10 then
								c.sOffsideHarassChatTime = now
								local name = string.gsub(enemy:GetUnitName(), "npc_dota_hero_", "")
								name = string.gsub(name, "_(%l)", function(ch)
									return " " .. string.upper(ch)
								end)
								name = string.upper(string.sub(name, 1, 1)) .. string.sub(name, 2)
								c:ActionImmediate_Chat("Harassing " .. name, false)
							end
							if GetUnitToUnitDistance(c, enemy) > atk then
								c:Action_MoveToLocation(enemy:GetLocation())
							else
								c:Action_AttackUnit(enemy, true)
							end
							return
						end
					end
				end
			end
		end
	end
	local i = c.isBear or string.find(c:GetUnitName(), "lone_druid_bear")
	local G = c:GetNearbyLaneCreeps(600, true)
	if #G <= 2 and not a.IsCore(c) and not i and a.GetHP(c) > 0.4 then
		local H = GetHarassTarget(v)
		if a.IsValidHero(H) then
			c:Action_AttackUnit(H, true)
			return
		end
	end
	local I = GetFurthestEnemyAttackRange(v)
	if I == 0 then
		I = math.max(r, 330)
	end
	local J = GetLaneFrontAmount(GetTeam(), s, false)
	local K = GetLaneFrontAmount(GetOpposingTeam(), s, false)
	local L = GetLaneFrontLocation(GetTeam(), s, -I)
	if K < J then
		L = GetLaneFrontLocation(GetOpposingTeam(), s, -I)
	end
	if DotaTime() >= h then
		c:Action_MoveToLocation(L + RandomVector(300))
		h = DotaTime() + RandomFloat(0.05, 0.2)
	end
end
function GetBestLastHitCreep(M)
	local N = c:GetAttackDamage()
	if c:GetItemSlotType(c:FindItemSlot("item_quelling_blade")) == ITEM_SLOT_TYPE_MAIN then
		if c:GetAttackRange() > 310 or c:GetUnitName() == "npc_dota_hero_templar_assassin" then
			N = N + 4
		else
			N = N + 8
		end
	end
	for A, B in pairs(M) do
		if a.IsValid(B) and a.CanBeAttacked(B) then
			local O = a.GetAttackProDelayTime(c, B)
			if a.WillKillTarget(B, N, DAMAGE_TYPE_PHYSICAL, O) then
				return B
			end
		end
	end
	return nil
end
function GetBestDenyCreep(M)
	local fallback = nil
	local attackRange = c:GetAttackRange()
	for A, B in pairs(M) do
		if
			a.IsValid(B)
			and a.GetHP(B) < 0.49
			and a.CanBeAttacked(B)
			and B:GetHealth() <= c:GetAttackDamage()
			and a.IsDeniableLaneCreep(B)
		then
			-- Prefer a deny that can be executed immediately. Otherwise keep the
			-- first valid creep so the bot can walk up to it.
			if GetUnitToUnitDistance(c, B) <= attackRange + 100 then
				return B
			elseif fallback == nil then
				fallback = B
			end
		end
	end
	return fallback
end
function GetHarassTarget(P)
	local enemyTowers = c:GetNearbyTowers(1000, true)
	for A, Q in pairs(P) do
		if
			a.IsValidHero(Q)
			and a.IsInRange(c, Q, c:GetAttackRange() + 220)
			and a.CanBeAttacked(Q)
			and not a.IsSuspiciousIllusion(Q)
		then
			-- Skip tower-hugging bait.
			if a.IsValidBuilding(enemyTowers[1]) then
				local tr = (enemyTowers[1]:GetAttackRange() or 700) + 200
				if GetUnitToUnitDistance(c, enemyTowers[1]) < tr or GetUnitToUnitDistance(Q, enemyTowers[1]) < tr + 80 then
					goto continue_harass
				end
			end
			return Q
		end
		::continue_harass::
	end
	return nil
end
function GetFurthestEnemyAttackRange(R)
	local S = 0
	for A, T in pairs(R) do
		if a.IsValidHero(T) and not a.IsSuspiciousIllusion(T) then
			local U = T:GetAttackRange()
			if U > S then
				S = U
			end
		end
	end
	return S
end
function ConsiderTango()
	if c:HasModifier("modifier_tango_heal") then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	e = 0
	g = a.FindItemSlotNotInNonbackpack(c, "item_tango")
	if g < 0 then
		g = a.FindItemSlotNotInNonbackpack(c, "item_tango_single")
	end
	if
		g >= 0
		and c:OriginalGetMaxHealth() - c:OriginalGetHealth() > 250
		and a.GetHP(c) > 0.15
		and not a.IsAttacking(c)
		and not c:WasRecentlyDamagedByAnyHero(2)
	then
		local V = c:GetNearbyTrees(800)
		local W = V[1]
		local X = a.GetNearbyHeroes(c, 1000, true, BOT_MODE_NONE)
		local Y = X[1]
		local Z = c:GetNearbyTowers(1400, true)
		local _ = Z[1]
		if W ~= nil then
			local a0 = GetTreeLocation(W)
			if
				IsLocationVisible(a0)
				and IsLocationPassable(a0)
				and (#X == 0 or GetUnitToLocationDistance(c, a0) * 1.6 < GetUnitToUnitDistance(c, Y))
				and (#Z == 0 or GetUnitToLocationDistance(_, a0) > 920)
			then
				return BOT_ACTION_DESIRE_HIGH, W
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
return b
