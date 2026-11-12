-- Hero-specific helper: special units.
local a = {}
local b
local c = require(GetScriptDirectory() .. "/FuncLib/func_utils")
function a.GetDesire(d)
	local e = c.GetHP(b)
	local f = c.IsRetreating(b)
	local g = c.IsRealInvisible(b)
	local h = c.IsGoingOnSomeone(b)
	b = d
	if c.CanNotUseAction(b) or b:IsDisarmed() then
		return 0
	end
	b.special_unit_target = nil
	local i = b:GetHealth()
	local j = e
	local k = b:GetLocation()
	local l = b:GetAttackRange()
	local m = c.GetAlliesNearLoc(b:GetLocation(), 1600)
	local n = c.GetEnemiesNearLoc(b:GetLocation(), 1600)
	local o = b:GetNearbyHeroes(1600, false, BOT_MODE_NONE)
	local p = b:GetNearbyHeroes(1600, true, BOT_MODE_NONE)
	local q = c.GetProperTarget(b)
	local r = b:GetUnitName()
	local s = false
	for t = 1, #GetTeamPlayers(GetTeam()) do
		local u = GetTeamMember(t)
		if u ~= nil and u:GetUnitName() == "npc_dota_hero_rattletrap" then
			s = true
			break
		end
	end
	-- Escape Shadow Shaman serpent ward traps (self or ally) before other specials.
	-- Below teamfight priority; above creeps when no enemy hero is nearby.
	do
		local snakeDesire, snakeTarget = a.GetSerpentWardEscapeDesire(b, l, p)
		if snakeDesire > 0 and c.IsValid(snakeTarget) then
			b.special_unit_target = snakeTarget
			return snakeDesire
		end
	end
	-- Deward: revealed enemy obs/sentry under ally true sight.
	do
		local wardDesire, wardTarget = a.GetDewardDesire(b, l, n)
		if wardDesire > 0 and c.IsValid(wardTarget) then
			b.special_unit_target = wardTarget
			return wardDesire
		end
	end
	for v, w in pairs(GetUnitList(UNIT_LIST_ENEMIES)) do
		if c.IsValid(w) and c.CanBeAttacked(w) and c.IsInRange(b, w, 1600) then
			b.special_unit_target = w
			local x = w:GetUnitName()
			local y = a.GetUnitAttackDamageWithinTime(b, 8.0)
			local z = c.GetHP(w)
			local A = w:GetLocation()
			local B = GetUnitToUnitDistance(b, w) <= l
			if string.find(x, "rattletrap_cog") then
				if string.find(r, "rattletrap") and B then
					if h then
						if
							c.IsValidHero(q)
							and c.CanCastOnNonMagicImmune(q)
							and c.IsInRange(b, q, 800)
							and not c.IsInRange(b, q, 400)
							and not (c.IsInRange(b, q, 800) and c.IsChasingTarget(b, q))
						then
							local C = PointToLineDistance(k, q:GetLocation(), A)
							if C ~= nil and C.within and C.distance <= 185 then
								return 2
							end
						end
					end
					if f and g then
						for v, D in pairs(n) do
							if
								c.IsValidHero(D)
								and c.IsInRange(b, D, 800)
								and not c.IsInRange(b, q, 400)
								and c.IsChasingTarget(D, b)
							then
								local C = PointToLineDistance(k, q:GetLocation(), A)
								if C ~= nil and C.within and C.distance <= 185 then
									return 2
								end
							end
						end
					end
				else
					local E = c.GetPowerCogsCountInLoc(k, 1000)
					local F = c.GetPowerCogsCountInLoc(k, 216)
					if #p >= 1 then
						local G = c.GetEnemiesNearLoc(k, 800)
						if E == 8 and F >= 4 and B then
							if #G == 0 or h or f and not g and #G >= 1 or #m < #n then
								return 0.95
							else
								return 0.55
							end
						end
					end
					if #n == 0 then
						if E == 8 and F >= 4 and B then
							return 0.90
						else
							if
								b:GetTeam() ~= w:GetTeam()
								and c.IsInRange(b, w, l + 350)
								and not c.IsInLaningPhase()
							then
								return 0.75
							else
								return 0.50
							end
						end
					end
				end
			end
			if b:GetTeam() ~= w:GetTeam() then
				if
					string.find(x, "juggernaut_healing_ward")
					or string.find(x, "roshans_banner")
					or string.find(x, "land_mine")
					or string.find(x, "ignis_fatuus")
				then
					if c.IsInRange(b, w, l) then
						return 1
					end
					if c.IsInRange(b, w, l + 200) then
						return RemapValClamped(e, 0.1, 0.9, 0, 0.96)
					end
					if #p == 0 then
						return RemapValClamped(e, 0.2, 0.9, 0, 0.9)
					end
					if #m >= #n then
						return RemapValClamped(e, 0.2, 0.9, 0, 0.7)
					end
				end
				if string.find(x, "siege") then
					if #p == 0 and c.GetDistanceFromAncient(b, false) < 3000 then
						return 0.5
					end
				end
				if
					string.find(x, "shadow_shaman_ward")
					or string.find(x, "invoker_forged_spirit")
					or string.find(x, "venomancer_plague_ward")
					or string.find(x, "clinkz_skeleton_archer")
				then
					if e > 0.7 and c.IsInRange(b, w, l) then
						if #n == 0 then
							return RemapValClamped(e, 0.3, 0.9, 0, 0.75)
						end
						if #m >= #n then
							return 0.4
						end
					end
					if e < 0.7 and c.IsStuck(b) then
						return RemapValClamped(e, 0.2, 0.8, 0.7, 0.3)
					end
					local H = a.GetUnitTypeAttackingBot(k, 1600, x)
					local I = a.GetTotalAttackDamage(H, 8.0)
					y = a.GetUnitAttackDamageWithinTime(b, 5.0)
					if not c.IsInTeamFight(b, 900) and not (f and g) then
						if I < i or c.IsInRange(b, w, l) and not c.IsInRange(b, w, w:GetAttackRange()) then
							return 0.31
						end
					end
				end
				if string.find(x, "pugna_nether_ward") then
					if c.IsInRange(b, w, l + 150) then
						if
							h and c.IsValidHero(q) and c.IsInRange(b, q, l - 130) and c.GetHP(q) < 0.5
							or a.IsBeingAttackedByHero(b) and j < 0.5
						then
							return 0.35
						else
							if not a.IsBeingAttackedByHero(b) then
								return 0.60
							end
						end
					else
						return 0.35
					end
				end
				if
					string.find(x, "grimstroke_ink_creature")
					or string.find(x, "weaver_swarm")
					or string.find(x, "tidehunter_anchor")
				then
					if #n == 0 then
						return 0.9
					end
					if
						h and c.IsValidHero(q) and c.IsInRange(b, q, l - 130) and c.GetHP(q) < 0.5
						or a.IsBeingAttackedByHero(b) and j < 0.5
					then
						return 0.35
					end
					if not a.IsHeroWithinRadius(n, l - 130) then
						return 0.96
					end
					if not a.IsBeingAttackedByHero(b) then
						return 0.8
					else
					end
				end
				if string.find(x, "gyrocopter_homing_missile") then
					if not c.IsInTeamFight(b, 900) and B and not (f and g) then
						if not c.IsRunning(w) or not c.IsInRange(b, w, 250) then
							return 0.9
						end
					end
				end
				if string.find(x, "zeus_cloud") then
					if #m >= #n or #p == 0 then
						if B then
							return 0.7
						end
						return RemapValClamped(e, 0.3, 0.9, 0, 0.65)
					end
				end
				if string.find(x, "lone_druid_bear") or string.find(x, "npc_dota_brewmaster") then
					if #m >= 2 and #o > #p then
						return 0.45
					end
					if not a.IsUnitAfterUnit(w, b) then
						return BOT_ACTION_DESIRE_HIGH
					end
					if z < 0.25 then
						if a.IsUnitAfterUnit(w, b) then
							return RemapValClamped(j, 0.25, 0.9, 0.2, 0.9)
						else
							return 0.45
						end
					end
				end
				if
					w:HasModifier("modifier_dominated")
					or w:HasModifier("modifier_chen_holy_persuasion")
					or string.find(x, "visage_familiar")
				then
					local J = a.GetUnitAttackDamageWithinTime(w, 5.5)
					y = a.GetUnitAttackDamageWithinTime(b, 5.0)
					if not c.IsInTeamFight(b, 1200) and not (f and not g) and B and y > z and J < i then
						return 0.5
					end
				end
				if
					string.find(x, "lycan_wolf")
					or string.find(x, "eidolon")
					or string.find(x, "beastmaster_boar")
					or string.find(x, "beastmaster_greater_boar")
					or string.find(x, "furion_treant")
					or string.find(x, "broodmother_spiderling")
					or string.find(x, "skeleton_warrior")
				then
					local K = a.GetUnitTypeAttackingBot(k, 1600, x)
					local J = a.GetTotalAttackDamage(K, 4.0)
					local L = a.GetTotalUnitHealth(K)
					y = a.GetUnitAttackDamageWithinTime(b, 4.0)
					if not c.IsInTeamFight(b, 1200) and B and y > L and J < i then
						return RemapValClamped(j, 0.25, 0.9, 0.2, 0.5)
					end
				end
				if string.find(x, "observer_wards") or string.find(x, "sentry_wards") then
					-- Handled earlier via GetDewardDesire; keep a fallback.
					if a.HasTrueSightNear(w:GetLocation()) then
						if not a.IsBeingAttackedByHero(b) or #n <= 1 then
							if c.IsInRange(b, w, l + 200) then
								return 1.15
							end
							return 0.95
						end
					end
				end
				if string.find(x, "phoenix_sun") then
					if
						(#m >= #n or c.WeAreStronger(b, 1600))
						and not b:HasModifier("modifier_phoenix_fire_spirit_burn")
						and not f
					then
						local M = c.GetAlliesNearLoc(w:GetLocation(), 900)
						if c.IsInRange(b, w, l + 200) and #M >= 2 then
							return 1.2
						end
						if c.IsInRange(b, w, l + 300) and #M >= 2 then
							return 1.1
						end
						if c.IsInRange(b, w, l + 400) then
							return RemapValClamped(e, 0.2, 0.9, 0.4, 0.97)
						end
						return RemapValClamped(e, 0.2, 0.9, 0, 0.9)
					end
				end
				if string.find(x, "tombstone") then
					if #o >= #p and not f then
						if c.IsInRange(b, w, l + 200) then
							return RemapValClamped(e, 0.25, 0.9, 0.4, 0.96)
						end
						return 0.56
					end
				end
				if string.find(x, "undying_zombie") then
					if #o >= #p and not f then
						if B then
							return 0.6
						end
						return 0.25
					end
				end
				if string.find(x, "warlock_golem") then
					y = a.GetUnitAttackDamageWithinTime(b, 5)
					local J = a.GetUnitAttackDamageWithinTime(w, 5)
					if not c.IsInTeamFight(b, 1600) and #o >= #p then
						local N = y > z and J * 1.2 < j
						if c.IsInRange(b, w, l + 300) then
							if not a.IsUnitAfterUnit(w, b) or a.IsUnitAfterUnit(w, b) and N then
								return 0.35
							else
								return 0.25
							end
						else
							if not a.IsUnitAfterUnit(w, b) or a.IsUnitAfterUnit(w, b) and N then
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
function a.Think(d)
	local O = d or b
	if O == nil or c.CanNotUseAction(O) then
		return
	end
	local P = O.special_unit_target
	if c.IsValid(P) and not O:IsDisarmed() then
		O:Action_AttackUnit(P, true)
		return
	end
end
function a.IsUnitAfterUnit(Q, R)
	return Q:GetAttackTarget() == R or c.IsChasingTarget(Q, R)
end
function a.GetTotalAttackDamage(K, S)
	local T = 0
	for v, w in pairs(K) do
		if c.IsValid(w) then
			T = T + w:GetAttackDamage() * w:GetAttackSpeed() * S
		end
	end
	return T
end
function a.GetUnitTypeAttackingBot(U, V, W)
	local X = {}
	for v, w in pairs(GetUnitList(UNIT_LIST_ENEMIES)) do
		if
			c.IsValid(w)
			and w:GetUnitName() == W
			and GetUnitToLocationDistance(w, U) <= V
			and (w:GetAttackTarget() == b or c.IsChasingTarget(w, b))
		then
			table.insert(X, w)
		end
	end
	return X
end
function a.GetUnitAttackDamageWithinTime(w, S)
	return w:GetAttackDamage() * w:GetAttackSpeed() * S
end
function a.GetTotalUnitHealth(K)
	local Y = 0
	for t = 1, #K do
		Y = Y + K[t]:GetHealth()
	end
	return Y
end
function a.IsBeingAttackedByHero(w)
	for v, Z in pairs(GetUnitList(UNIT_LIST_ENEMIES)) do
		if c.IsValidHero(Z) and Z:GetAttackTarget() == w then
			return true
		end
	end
	return false
end
function a.IsHeroWithinRadius(K, V)
	if c.IsValidHero(K[1]) and c.IsInRange(b, K[1], V) then
		return true
	end
	return false
end
-- Ally sentry / tower true sight radius (~925); use 1000 to match site.lua.
local TRUE_SIGHT_RADIUS = 1000

function a.IsThereSentry(_)
	return a.HasTrueSightNear(_)
end

function a.HasTrueSightNear(loc)
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
			if c.IsValidHero(ally) and GetUnitToLocationDistance(ally, loc) <= TRUE_SIGHT_RADIUS then
				local gem = ally:FindItemSlot("item_gem")
				if gem >= 0 and gem <= 5 then
					return true
				end
			end
		end
	end
	return false
end

function a.IsEnemyWard(unit)
	if not c.IsValid(unit) then
		return false
	end
	local name = unit:GetUnitName()
	return string.find(name, "observer_wards") ~= nil or string.find(name, "sentry_wards") ~= nil
end

function a.IsSerpentWard(unit)
	if not c.IsValid(unit) then
		return false
	end
	return string.find(unit:GetUnitName(), "shadow_shaman_ward") ~= nil
end

function a.GetEnemySerpentWardsNear(loc, radius)
	local wards = {}
	for _, unit in pairs(GetUnitList(UNIT_LIST_ENEMIES)) do
		if a.IsSerpentWard(unit) and c.CanBeAttacked(unit) and GetUnitToLocationDistance(unit, loc) <= radius then
			wards[#wards + 1] = unit
		end
	end
	return wards
end

function a.IsHeroTrappedBySerpentWards(hero)
	if not c.IsValidHero(hero) or not hero:IsAlive() then
		return false, nil
	end
	local wards = a.GetEnemySerpentWardsNear(hero:GetLocation(), 420)
	local n = #wards
	if n <= 0 then
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
	if n >= 3 or (n >= 2 and (c.IsStuck(hero) or beingHit)) then
		return true, wards
	end
	return false, wards
end

-- The ward standing between the trapped hero and safety. Killing any other one
-- keeps the ring closed and the hero dies inside it.
function a.GetExitSerpentWard(wards, trapped)
	if wards == nil or trapped == nil then
		return nil
	end
	local from = trapped:GetLocation()
	local dest = c.GetTeamFountain()
	local best, bestLine = nil, 99999
	for _, ward in pairs(wards) do
		if c.IsValid(ward) and c.CanBeAttacked(ward) then
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

function a.GetBestSerpentWardToKill(wards, bot, attackRange, trapped)
	local exitWard = a.GetExitSerpentWard(wards, trapped or bot)
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
		if c.IsValid(ward) and c.CanBeAttacked(ward) then
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

function a.GetSerpentWardEscapeDesire(bot, attackRange, nearbyEnemyHeroes)
	if bot == nil or c.CanNotUseAction(bot) or bot:IsDisarmed() then
		return 0, nil
	end
	-- Team fights come first — do not peel for snakes while a real fight is on.
	if c.IsInTeamFight(bot, 1200) then
		return 0, nil
	end

	local enemyHeroCount = 0
	for _, hero in pairs(nearbyEnemyHeroes or {}) do
		if c.IsValidHero(hero) and not c.IsSuspiciousIllusion(hero) then
			enemyHeroCount = enemyHeroCount + 1
		end
	end

	local trapWards = nil
	local trapped = nil
	local selfTrapped, selfWards = a.IsHeroTrappedBySerpentWards(bot)
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
				local allyTrapped, allyWards = a.IsHeroTrappedBySerpentWards(ally)
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

	local target = a.GetBestSerpentWardToKill(trapWards, bot, attackRange, trapped)
	if target == nil then
		return 0, nil
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

function a.GetDewardDesire(bot, attackRange, nearbyEnemies)
	if bot == nil or c.CanNotUseAction(bot) or bot:IsDisarmed() then
		return 0, nil
	end
	local best = nil
	local bestDist = 99999
	local searchRange = math.max(1600, attackRange + 400)

	local function consider(unit)
		if not c.IsValid(unit) or not c.CanBeAttacked(unit) then
			return
		end
		if not a.IsEnemyWard(unit) then
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
		if not unit:CanBeSeen() and not a.HasTrueSightNear(unit:GetLocation()) then
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

	local underFire = a.IsBeingAttackedByHero(bot) and #(nearbyEnemies or {}) > 1
	if underFire and bestDist > attackRange + 150 then
		return 0, nil
	end

	if bestDist <= attackRange + 50 then
		return 1.25, best
	end
	if bestDist <= attackRange + 350 then
		return 1.1, best
	end
	return 0.95, best
end
return a
