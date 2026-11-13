-- Laning mode for the opening of the game.
local a = require(GetScriptDirectory() .. "/FuncLib/systems/utils")
local b = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local d = require(GetScriptDirectory() .. "/FuncLib/systems/localization")
local e = GetBot()
local f = e:GetUnitName()
if
	e == nil
	or e:IsInvulnerable()
	or not e:IsHero()
	or not e:IsAlive()
	or not string.find(f, "hero")
	or e:IsIllusion()
then
	return
end
if e.isInLanePhase == nil then
	e.isInLanePhase = false
end
local g = nil
local h = nil
local i = nil
local j = 0
local k = nil
local l = nil
local m = e:GetAttackRange()
local n = e:GetAttackDamage()
local q, r = b.Utils.NumHumanBotPlayersInTeam(GetTeam())
local s = false
local w = false
if a.BuggyHeroesDueToValveTooLazy[f] then
	g = dofile(GetScriptDirectory() .. "/FuncLib/systems/override_generic/mode_laning_generic")
end
-- Positions 1-3 are cores. Positions 4 and 5 are supports.
local function IsCoreRole()
	return b.GetPosition(e) <= 3
end
local function IsSupportRole()
	return b.GetPosition(e) >= 4
end
-- When a human is supporting, AI cores in the lane should farm more actively.
local function IsHumanSupportOnTeam()
	return b.IsPosxHuman(4) or b.IsPosxHuman(5)
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
	e.isInLanePhase = false
	local x = e:GetLevel()
	local y = DotaTime()
	m = e:GetAttackRange()
	h = e:GetNearbyLaneCreeps(1200, false)
	i = e:GetNearbyLaneCreeps(800, true)
	k = e:GetNearbyHeroes(1600, true, BOT_MODE_NONE)
	j = GetFurthestEnemyAttackRange(k)
	if g then
		l = g.GetBotTargetLane()
	else
		if IsLanMode and IsLanMode() then
			l = e:GetAssignedLane()
		else
			local z = b.GetPosition(e)
			if GetTeam() == TEAM_RADIANT then
				if z == 2 then
					l = LANE_MID
				elseif z == 1 or z == 5 then
					l = LANE_BOT
				elseif z == 3 or z == 4 then
					l = LANE_TOP
				end
			else
				if z == 2 then
					l = LANE_MID
				elseif z == 1 or z == 5 then
					l = LANE_TOP
				elseif z == 3 or z == 4 then
					l = LANE_BOT
				end
			end
			if l == nil then
				l = e:GetAssignedLane() or LANE_MID
			end
		end
	end
	n = e:GetAttackDamage()
	if e:GetItemSlotType(e:FindItemSlot("item_quelling_blade")) == ITEM_SLOT_TYPE_MAIN then
		if e:GetAttackRange() > 310 or e:GetUnitName() == "npc_dota_hero_templar_assassin" then
			n = n + 4
		else
			n = n + 8
		end
	end
	if y < 0 then
		return BOT_ACTION_DESIRE_NONE
	end
	if b.GetEnemiesAroundAncient(e, 3200) > 0 then
		return BOT_MODE_DESIRE_NONE
	end
	if e:WasRecentlyDamagedByAnyHero(3) and #b.Utils.GetLastSeenEnemyIdsNearLocation(e:GetLocation(), 800) > 0 then
		if b.GetHP(e) < 0.4 and not b.WeAreStronger(e, 1200) then
			return BOT_MODE_DESIRE_VERYLOW
		end
	end
	if k ~= nil and #k >= 1 and (e:WasRecentlyDamagedByAnyHero(2.0) or b.IsGoingOnSomeone(e)) then
		local A = k[1]
		local B = b.IsValidHero(A) and GetUnitToUnitDistance(e, A) or -1
		if B >= 0 and B < 1000 and b.GetHP(A) < 0.6 then
			return 0.1
		end
	end
	if b.Utils.IsTeamPushingSecondTierOrHighGround(e) then
		return BOT_MODE_DESIRE_NONE
	end
	-- AI cores contest last hits and denies when a human is supporting them.
	local bHumanSupport = IsHumanSupportOnTeam()
	if g or (IsCoreRole() and bHumanSupport) then
		if y <= 9 * 60 then
			local C, D = GetBestLastHitCreep(i)
			local denyCreep = nil
			if IsCoreRole() and bHumanSupport then
				denyCreep = GetBestDenyCreep(h)
			end
			if b.IsValid(C) or b.IsValid(denyCreep) then
				-- Supports only get this boost when no core is around.
				local nCoreRadius = IsSupportRole() and 1000 or 700
				if b.GetPosition(e) <= 2 or not b.IsThereNonSelfCoreNearby(nCoreRadius) then
					return 0.6
				end
			end
		end
	end
	if g and g.GetDesire ~= nil then
		return g.GetDesire()
	end
	if GetGameMode() == GAMEMODE_1V1MID or GetGameMode() == GAMEMODE_MO then
		return 1
	end
	local E = { [LANE_TOP] = TOWER_TOP_2, [LANE_MID] = TOWER_MID_2, [LANE_BOT] = TOWER_BOT_2 }
	local F = E[l] and GetTower(GetOpposingTeam(), E[l])
	if F == nil or not F:IsAlive() then
		return 0
	end
	local G = b.GetHP(e)
	local H = #k == 0 or e:HasModifier("modifier_tower_aura_bonus")
	local I = H and 1 or RemapValClamped(G, 0, 0.7, 0, 1)
	if y <= 10 then
		e.isInLanePhase = true
		return 0.268 * I
	end
	if y <= 10 * 60 then
		e.isInLanePhase = true
		if b.IsCore(e) and H and not e:WasRecentlyDamagedByAnyHero(5.0) and not b.IsRetreating(e) then
			return BOT_MODE_DESIRE_HIGH + 0.04
		end
		return (BOT_MODE_DESIRE_MODERATE - 0.05) * I
	end
	if y <= 12 * 60 and x <= 11 then
		return 0.2 * I
	end
	e.isInLanePhase = false
	return BOT_MODE_DESIRE_NONE
end
function GetFurthestEnemyAttackRange(J)
	local K = 0
	for D, L in pairs(J) do
		if b.IsValidHero(L) and not b.IsSuspiciousIllusion(L) then
			local M = L:GetAttackRange()
			if M > K then
				K = M
			end
		end
	end
	return K
end
local function N(O)
	local P = O:GetUnitName()
	if string.find(P, "ranged") then
		return 3
	end
	if string.find(P, "flagbearer") then
		return 2
	end
	return 1
end
function GetBestLastHitCreep(Q)
	local R = n - 3
	local S = nil
	local T = 0
	for D, O in pairs(Q) do
		if b.IsValid(O) and b.CanBeAttacked(O) then
			local U = b.GetAttackProDelayTime(e, O)
			local V = N(O)
			if b.WillKillTarget(O, R, DAMAGE_TYPE_PHYSICAL, U) then
				if V > T then
					T = V
					S = O
				end
			end
		end
	end
	return S
end
function GetBestDenyCreep(Q)
	local W = nil
	local T = 0
	local fallbackCreep = nil
	local fallbackScore = 0
	for D, O in pairs(Q) do
		if
			b.IsValid(O)
			and b.GetHP(O) < 0.49
			and b.CanBeAttacked(O)
			and O:GetHealth() <= n
			and b.IsDeniableLaneCreep(O)
		then
			local V = N(O)
			-- Prefer a deny that can be executed immediately. Otherwise keep the
			-- best creep as a fallback so the bot can walk up to it.
			if GetUnitToUnitDistance(e, O) <= m + 100 then
				if V > T then
					T = V
					W = O
				end
			elseif V > fallbackScore then
				fallbackScore = V
				fallbackCreep = O
			end
		end
	end
	if W ~= nil then
		return W
	end
	return fallbackCreep
end
local X = 0
local function Y(Z)
	local _ = e:GetNearbyTowers(900, true)
	if b.IsValidBuilding(_[1]) and _[1]:GetAttackTarget() == e then
		for D, O in pairs(Z) do
			if b.IsValid(O) and b.IsInRange(e, O, m + 100) then
				e:Action_AttackUnit(O, true)
				return true
			end
		end
	end
	return false
end
local function a0()
	for a1 = 1, #GetTeamPlayers(GetTeam()) do
		local a2 = GetTeamMember(a1)
		if a2 ~= nil and a2 ~= e and b.IsValidHero(a2) and a2:GetAssignedLane() == l then
			return a2
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
	name = string.gsub(name, "_(%l)", function(c)
		return " " .. string.upper(c)
	end)
	return string.upper(string.sub(name, 1, 1)) .. string.sub(name, 2)
end
local function AnnounceOffsideHarass(target)
	local now = DotaTime()
	if e.sOffsideHarassChatTime ~= nil and now - e.sOffsideHarassChatTime < 10 then
		return
	end
	e.sOffsideHarassChatTime = now
	e:ActionImmediate_Chat("Harassing " .. PrettyHeroName(target), false)
end
-- Right-clicking a hero pulls every enemy lane creep within 500 that is not already on us.
local function CreepAggroUnsafe(hero)
	local creeps = hero:GetNearbyLaneCreeps(500, true) or {}
	local fresh, hitting = 0, 0
	for _, creep in pairs(creeps) do
		if b.IsValid(creep) then
			if creep:GetAttackTarget() == hero then
				hitting = hitting + 1
			else
				fresh = fresh + 1
			end
		end
	end
	return fresh > 0 or hitting >= 2
end
-- Aggressive lane poke on our half. LH/deny still come first in Think.
local function ConsiderOffsideHarass(enemyHeroes)
	if not b.IsInLaningPhase or not b.IsInLaningPhase() then
		return nil
	end
	if b.GetHP(e) < 0.55 or CreepAggroUnsafe(e) then
		return nil
	end
	if e:WasRecentlyDamagedByAnyHero(1.0) and b.GetHP(e) < 0.75 then
		return nil
	end
	local allyT1 = GetLaneT1(GetTeam(), l)
	local enemyT1 = GetLaneT1(GetOpposingTeam(), l)
	if allyT1 == nil or not allyT1:IsAlive() then
		return nil
	end
	local atk = e:GetAttackRange()
	local best = nil
	local bestDist = 99999
	for _, enemy in pairs(enemyHeroes or {}) do
		if
			b.IsValidHero(enemy)
			and b.CanBeAttacked(enemy)
			and not b.IsSuspiciousIllusion(enemy)
			and b.IsInRange(e, enemy, atk + 250)
		then
			-- Never stand inside enemy tower attack range.
			if
				enemyT1 ~= nil
				and enemyT1:IsAlive()
				and GetUnitToUnitDistance(e, enemyT1) < (enemyT1:GetAttackRange() or 700) + 180
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
			local selfToAllyT1 = GetUnitToUnitDistance(e, allyT1)
			if enemyToAllyT1 <= OFFSIDE_ENEMY_FROM_T1 and selfToAllyT1 <= OFFSIDE_SELF_FROM_T1 then
				local dist = GetUnitToUnitDistance(e, enemy)
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
	local standOff = math.max(m, 250, j)
	if IsCoreRole() and m < 326 and b.GetHP(e) >= 0.45 then
		standOff = math.min(standOff, MELEE_CORE_STANDOFF)
	end
	return standOff
end
-- Name of an allied core that will get this last hit itself, or nil when none can.
-- A human core is always left the creep. A bot core counts when its own attack,
-- including the walk, lands before the creeps kill it.
local function CoreCanTakeLastHit(creep)
	for _, ally in pairs(b.GetNearbyHeroes(e, 1000, false, BOT_MODE_NONE) or {}) do
		if b.IsValidHero(ally) and ally ~= e and b.IsCore(ally) and not ally:IsIllusion() then
			local name = (string.gsub(ally:GetUnitName(), "npc_dota_hero_", ""))
			if not ally:IsBot() then
				return name
			end
			local delay = b.GetAttackProDelayTime(ally, creep)
			if b.WillKillTarget(creep, ally:GetAttackDamage() - 3, DAMAGE_TYPE_PHYSICAL, delay) then
				return name
			end
		end
	end
	return nil
end
-- [OHA-LANE]: every 20s per bot in the laning phase. Last hits, denies, where it
-- stands relative to the wave, and how often a support took or left a last hit.
local function LogLaning()
	local now = DotaTime()
	if now < 0 or now > 10 * 60 or now < (e._laneLogAt or -999) then
		return
	end
	e._laneLogAt = now + 20
	local nearest = 99999
	for _, creep in pairs(e:GetNearbyLaneCreeps(1600, true) or {}) do
		if b.IsValid(creep) then
			nearest = math.min(nearest, GetUnitToUnitDistance(e, creep))
		end
	end
	local partner = a0()
	pcall(print, string.format(
		"[OHA-LANE] t=%.0f %s pos=%d lane=%s range=%d standoff=%d enemyRange=%d creep=%d lh=%d dn=%d partner=%s supTook=%d supLeft=%d hp=%.2f",
		now,
		(string.gsub(e:GetUnitName(), "npc_dota_hero_", "")),
		b.GetPosition(e),
		tostring(l),
		math.floor(m),
		math.floor(LaneStandOff()),
		math.floor(j or 0),
		math.floor(nearest),
		e:GetLastHits(),
		e:GetDenies(),
		partner ~= nil and (string.gsub(partner:GetUnitName(), "npc_dota_hero_", "")) or "-",
		e._laneSupportTook or 0,
		e._laneSupportLeft or 0,
		b.GetHP(e)
	))
	e._laneSupportTook = 0
	e._laneSupportLeft = 0
end
-- Enemy summons attacking this hero: spiderlings, wolves, golems, treants. Lane creeps,
-- heroes and buildings are handled elsewhere.
local function SummonsOnMe()
	local n = 0
	for _, unit in pairs(GetUnitList(UNIT_LIST_ENEMIES) or {}) do
		if
			b.IsValid(unit)
			and not unit:IsHero()
			and not unit:IsBuilding()
			and not string.find(unit:GetUnitName() or "", "npc_dota_creep_", 1, true)
			and unit:GetAttackTarget() == e
			and GetUnitToUnitDistance(unit, e) <= 800
		then
			n = n + 1
		end
	end
	return n
end
-- Custom laning Think for all roles so cores also harass (not only buggy/human-support).
do
	function Think()
		LogLaning()
		-- Standing at the lane spot while two or more summons bite is how a hero melted to
		-- spiderlings. Step back toward the tower and let the creeps or tower take them.
		local summons = SummonsOnMe()
		if summons >= 2 then
			if DotaTime() >= (e._summonStepLogAt or -999) then
				e._summonStepLogAt = DotaTime() + 5
				pcall(print, string.format(
					"[OHA-LANE] t=%.0f %s summons-step-back count=%d hp=%.2f",
					DotaTime(),
					(string.gsub(e:GetUnitName(), "npc_dota_hero_", "")),
					summons,
					b.GetHP(e)
				))
			end
			e:Action_MoveToLocation(b.AdjustLocationWithOffsetTowardsFountain(e:GetLocation(), 500))
			return
		end
		local _ = e:GetNearbyTowers(1200, true)
		if Y(h) then
			return
		end
		if b.IsValidBuilding(_[1]) then
			local a3 = GetUnitToUnitDistance(e, _[1])
			if a3 < 800 and #i < 3 then
				if DotaTime() >= X then
					e:Action_MoveToLocation(b.VectorAway(e:GetLocation(), _[1]:GetLocation(), 950) + RandomVector(75))
					X = DotaTime() + RandomFloat(1, 3)
					return
				end
			end
		end
		local bSupport = IsSupportRole()
		-- Supports deny first and leave the last hits to their core.
		if bSupport then
			local denyCreep = GetBestDenyCreep(h)
			if b.IsValid(denyCreep) then
				e:SetTarget(denyCreep)
				e:Action_AttackUnit(denyCreep, true)
				return
			end
		end
		local C = GetBestLastHitCreep(i)
		if b.IsValid(C) then
			if
				b.IsValidBuilding(_[1])
				and b.IsValid(i[1])
				and GetUnitToUnitDistance(i[1], _[1]) < 700
				and GetUnitToUnitDistance(i[1], e) > m
			then
				local a4 = e:FindAoELocation(false, false, _[1]:GetLocation(), 0, 650, 0, 0)
				if a4.count <= 3 then
					goto a5
				end
			end
			local bCanLastHit
			if bSupport then
				-- Do not compete with a core for last hits, but take one the core cannot reach in time.
				local coreName = CoreCanTakeLastHit(C)
				bCanLastHit = coreName == nil
				if e._laneSupportCreep ~= C then
					e._laneSupportCreep = C
					if bCanLastHit then
						e._laneSupportTook = (e._laneSupportTook or 0) + 1
					else
						e._laneSupportLeft = (e._laneSupportLeft or 0) + 1
					end
				end
			else
				local a6 = a0()
				bCanLastHit = a6 == nil
					or b.IsCore(e)
					or not b.IsCore(e)
						and b.IsCore(a6)
						and (not a6:IsAlive() or GetUnitToUnitDistance(a6, C) > a6:GetAttackRange() + 400)
			end
			if bCanLastHit then
				local a7 = GetUnitToUnitDistance(e, C)
				if a7 > m then
					local a8 = m - C:GetBoundingRadius()
					local a9 = b.GetXUnitsTowardsLocation2(C:GetLocation(), e:GetLocation(), a8)
					e:Action_MoveDirectly(a9)
					return
				else
					e:SetTarget(C)
					e:Action_AttackUnit(C, false)
					return
				end
			end
			::a5::
		end
		-- Cores deny after looking for a last hit. Supports already denied above.
		if not bSupport then
			local aa = GetBestDenyCreep(h)
			if b.IsValid(aa) then
				e:SetTarget(aa)
				e:Action_AttackUnit(aa, true)
				return
			end
		end
		-- Offside poke (after LH/deny, before general harass). Stay in attack range.
		-- Walking closer is what pulls the wave onto her.
		do
			local offside = ConsiderOffsideHarass(k)
			if offside ~= nil and GetUnitToUnitDistance(e, offside) <= m then
				AnnounceOffsideHarass(offside)
				e:Action_AttackUnit(offside, true)
				return
			end
		end
		if g then
			g.Think()
			return
		end
		if
			b.IsValidBuilding(_[1])
			and b.CanBeAttacked(_[1])
			and b.IsValid(_[1]:GetAttackTarget())
			and _[1]:GetAttackTarget():IsCreep()
		then
			if #h >= 3 then
				e:Action_AttackUnit(_[1], true)
				return
			end
		end
		local enemyT1Harass = GetLaneT1(GetOpposingTeam(), l)
		local function SafeToHarassHero(L)
			if not b.IsValidHero(L) or not b.CanBeAttacked(L) or b.IsSuspiciousIllusion(L) then
				return false
			end
			if
				enemyT1Harass ~= nil
				and enemyT1Harass:IsAlive()
				and (
					GetUnitToUnitDistance(e, enemyT1Harass) < (enemyT1Harass:GetAttackRange() or 700) + 180
					or GetUnitToUnitDistance(L, enemyT1Harass) < (enemyT1Harass:GetAttackRange() or 700) + 250
				)
			then
				return false
			end
			return true
		end
		if not b.IsCore(e) and b.GetHP(e) > 0.5 and not CreepAggroUnsafe(e) then
			for D, L in pairs(k) do
				if SafeToHarassHero(L) and b.IsInRange(e, L, m) then
					e:Action_AttackUnit(L, true)
					return
				end
			end
		end
		if b.IsCore(e) and b.GetHP(e) > 0.45 and not CreepAggroUnsafe(e) then
			for D, L in pairs(k) do
				if SafeToHarassHero(L) and b.IsInRange(e, L, m) then
					e:Action_AttackUnit(L, true)
					return
				end
			end
		end
		local ae = GetLaneFrontAmount(GetTeam(), l, false)
		local af = GetLaneFrontAmount(GetOpposingTeam(), l, false)
		local ag = LaneStandOff()
		local ah = GetLaneFrontLocation(GetTeam(), l, -ag)
		if af < ae then
			ah = GetLaneFrontLocation(GetOpposingTeam(), l, -ag)
		end
		if DotaTime() >= X then
			e:Action_MoveToLocation(ah + RandomVector(100))
			X = DotaTime() + RandomFloat(0.3, 0.9)
		end
	end
end
function PickOneAnnouncer()
	if s then
		return
	end
	local ai = e:GetPlayerID()
	local aj = e:GetTeam()
	local ak = ai
	for al = 0, 63 do
		if al ~= ai then
			local am, an = pcall(IsPlayerBot, al)
			local ao, ap = pcall(GetTeamForPlayer, al)
			if am and ao and an and ap == aj and al < ak then
				ak = al
			end
		end
	end
	e.isAnnouncer = ai == ak
	s = true
end
function AnnounceMessages()
	-- Welcome + map version is sent during hero pick (hero_selection.lua), not here.
	if DotaTime() > 60 then
		return
	end
	if GetGameMode() ~= GAMEMODE_1V1MID and not w then
		if DotaTime() >= 0 and q > 0 and r > 0 then
			e:ActionImmediate_Chat(d.Get("pos_select_closed") .. " (" .. tostring(b.GetPosition(e)) .. ")", true)
			w = true
		end
	end
end
if SafeCall then
	local au = GetDesire
	local av = Think
	if au then
		GetDesire = SafeCall(au, 0, "LANING_GetDesire")
	end
	if av then
		Think = SafeCall(av, nil, "LANING_Think")
	end
end
