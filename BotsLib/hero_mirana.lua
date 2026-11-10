-- Mirana: skill build, item build, and ability use for this hero.
local a = {}
local b = GetBot()
local c = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local d = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local e = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local f = c.Skill.GetTalentList(b)
local g = c.Skill.GetAbilityList(b)
local h = c.Item.GetRoleItemsBuyList(b)
local i = { ["t25"] = { 10, 0 }, ["t20"] = { 10, 0 }, ["t15"] = { 10, 0 }, ["t10"] = { 10, 0 } }
local j = { { 1, 3, 1, 2, 1, 6, 1, 3, 3, 3, 6, 2, 2, 2, 6 } }
local k = c.Skill.GetRandomBuild(j)
local l = c.Skill.GetTalentBuild(i)
local m = {}
m["pos_1"] = {
	"item_ranged_carry_outfit",
	"item_dragon_lance",
	"item_rod_of_atos",
	"item_maelstrom",
	"item_black_king_bar",
	"item_mjollnir",
	"item_travel_boots",
	"item_orchid",
	"item_bloodthorn",
	"item_force_staff",
	"item_hurricane_pike",
	"item_ultimate_scepter",
	"item_moon_shard",
	"item_travel_boots_2",
	"item_ultimate_scepter_2",
	"item_butterfly",
}
m["pos_2"] = m["pos_1"]
m["pos_4"] = {
	"item_priest_outfit",
	"item_rod_of_atos",
	"item_mekansm",
	"item_glimmer_cape",
	"item_aghanims_shard",
	"item_guardian_greaves",
	"item_spirit_vessel",
	"item_ultimate_scepter",
	"item_shivas_guard",
	"item_moon_shard",
	"item_ultimate_scepter_2",
	"item_sheepstick",
}
m["pos_5"] = {
	"item_blood_grenade",
	"item_crystal_maiden_outfit",
	"item_rod_of_atos",
	"item_ancient_janggo",
	"item_glimmer_cape",
	"item_boots_of_bearing",
	"item_pipe",
	"item_ultimate_scepter",
	"item_cyclone",
	"item_shivas_guard",
	"item_sheepstick",
	"item_moon_shard",
	"item_ultimate_scepter_2",
}
m["pos_3"] = m["pos_1"]
a["sBuyList"] = m[h]
a["sSellList"] = { "item_black_king_bar", "item_quelling_blade" }
if c.Role.IsPvNMode() or c.Role.IsAllShadow() then
	a["sBuyList"], a["sSellList"] = { "PvN_ranged_carry" }, {}
end
k, l, a["sBuyList"], a["sSellList"] = c.SetUserHeroInit(k, l, a["sBuyList"], a["sSellList"])
a["sSkillList"] = c.Skill.GetSkillList(g, k, f, l)
a["bDeafaultAbility"] = false
a["bDeafaultItem"] = false
function a.MinionThink(n)
	if e.IsValidUnit(n) then
		e.IllusionThink(n)
	end
end
local o = SafeAbility(b:GetAbilityByName(g[1]), "sAbilityList[1]", "mirana")
local p = SafeAbility(b:GetAbilityByName(g[2]), "sAbilityList[2]", "mirana")
local q = SafeAbility(b:GetAbilityByName(g[3]), "sAbilityList[3]", "mirana")
local r = SafeAbility(b:GetAbilityByName(g[6]), "sAbilityList[6]", "mirana")
local s = SafeAbility(b:GetAbilityByName("mirana_celestial_quiver"), "mirana_celestial_quiver", "mirana")
local t, u
local v, w
local x, y
local z, A
local B, C
local D = 0
local E, F, G, H, I, J
function a.SkillsComplement()
	if c.CanNotUseAbility(b) then
		return
	end
	local K = d.Build(b)
	F = 400
	D = K.aetherRange
	E = K.level
	G = K.mp
	H = K.hp
	botTarget = K.target
	I = K.enemies
	J = K.allies
	t, u = a.ConsiderQ()
	if t > 0 then
		c.SetQueuePtToINT(b, true)
		b:ActionQueue_UseAbility(o)
		return
	end
	v, w = a.ConsiderW()
	if v > 0 then
		c.SetQueuePtToINT(b, true)
		b:ActionQueue_UseAbilityOnLocation(p, w)
		return
	end
	x, y = a.ConsiderE()
	if x > 0 then
		c.SetQueuePtToINT(b, false)
		b:ActionQueue_UseAbility(q)
		return
	end
	z, A = a.ConsiderR()
	if z > 0 then
		c.SetQueuePtToINT(b, true)
		b:ActionQueue_UseAbility(r)
		return
	end
	B, C = a.ConsiderCelestialQuiver()
	if B > 0 then
		b:Action_UseAbilityOnEntity(s, C)
		return
	end
end
function a.ConsiderQ()
	if not o:IsFullyCastable() then
		return 0
	end
	local L = o:GetLevel()
	local M = o:GetSpecialValueInt("starfall_radius")
	local N = o:GetSpecialValueInt("starfall_secondary_radius")
	local O = o:GetCastPoint()
	local P = o:GetManaCost()
	local Q = o:GetAbilityDamage()
	local R = DAMAGE_TYPE_MAGICAL
	local S = c.GetAroundEnemyHeroList(N)
	local T = c.GetAroundEnemyHeroList(M)
	local U = nil
	local V = nil
	for W, X in pairs(T) do
		if c.IsValid(X) and c.CanCastOnNonMagicImmune(X) and c.WillMagicKillTarget(b, X, Q, O) then
			U = X
			V = "Q-击杀:" .. c.Chat.GetNormName(U)
			return BOT_ACTION_DESIRE_HIGH, U, V
		end
	end
	if c.IsGoingOnSomeone(b) then
		if
			c.IsValidHero(botTarget)
			and c.IsInRange(b, botTarget, M)
			and c.CanCastOnNonMagicImmune(botTarget)
			and (#S >= 1 or #T >= 2 or H < 0.4)
		then
			U = botTarget
			V = "Q-攻击:" .. c.Chat.GetNormName(U)
			return BOT_ACTION_DESIRE_HIGH, U, V
		end
	end
	if c.IsRetreating(b) and b:WasRecentlyDamagedByAnyHero(3.0) and (#S >= 1 or H < 0.6) then
		for W, X in pairs(T) do
			if c.IsValid(X) and c.CanCastOnNonMagicImmune(X) then
				U = X
				V = "Q-撤退" .. c.Chat.GetNormName(U)
				return BOT_ACTION_DESIRE_HIGH, U, V
			end
		end
	end
	if b:GetActiveMode() == BOT_MODE_LANING or E <= 7 and #J <= 2 then
		local Y = 0
		local Z = 0
		local _ = b:GetNearbyLaneCreeps(M, true)
		for W, creep in pairs(_) do
			if
				c.IsValid(creep)
				and not creep:HasModifier("modifier_fountain_glyph")
				and not c.IsOtherAllysTarget(creep)
			then
				local a0 = Q
				if c.WillKillTarget(creep, a0, R, O + 0.57) then
					if c.IsKeyWordUnit("ranged", creep) then
						Z = Z + 1
					end
					if c.IsKeyWordUnit("melee", creep) then
						Y = Y + 1
					end
				end
			end
		end
		if Y + Z >= 3 then
			U = b
			V = "Q对线1"
			return BOT_ACTION_DESIRE_HIGH, U, V
		end
		if Z >= 1 and Y >= 1 then
			U = b
			V = "Q对线2"
			return BOT_ACTION_DESIRE_HIGH, U, V
		end
		if #_ == 0 and #S >= 1 and G > 0.5 then
			U = S[1]
			V = "Q对线消耗:" .. c.Chat.GetNormName(U)
			return BOT_ACTION_DESIRE_HIGH, U, V
		end
	end
	if
		(c.IsPushing(b) or c.IsDefending(b) or c.IsFarming(b))
		and c.IsAllowedToSpam(b, P * 0.32)
		and #J <= 3
		and #I == 0
	then
		local a1 = b:GetNearbyLaneCreeps(M - 50, true)
		if
			c.IsValid(a1[1])
			and not a1[1]:HasModifier("modifier_fountain_glyph")
			and (#a1 >= 5 or G > 0.88 and #a1 >= 4)
		then
			U = creep
			V = "Q-带线"
			return BOT_ACTION_DESIRE_HIGH, U, V
		end
	end
	if c.IsFarming(b) and DotaTime() > 8 * 60 and c.IsAllowedToSpam(b, P) then
		local a2 = b:GetNearbyNeutralCreeps(N)
		if #a2 >= 3 and c.IsValid(botTarget) and botTarget:GetMagicResist() < 0.51 then
			U = botTarget
			V = "Q-打野AOE" .. #a2
			return BOT_ACTION_DESIRE_HIGH, V
		end
	end
	if c.IsDoingTormentor(b) then
		if c.IsTormentor(botTarget) and c.IsInRange(botTarget, b, M) and c.IsAttacking(b) then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function a.ConsiderW()
	if not p:IsFullyCastable() then
		return 0
	end
	local M = p:GetSpecialValueInt("arrow_range")
	if M == nil or M <= 0 then
		M = p:GetCastRange()
	end
	if M == nil or M <= 0 then
		M = 3000
	end
	M = M + D
	local N = p:GetSpecialValueInt("arrow_width")
	if N == nil or N <= 0 then
		N = 115
	end
	local a3 = p:GetSpecialValueInt("arrow_speed")
	if a3 == nil or a3 <= 0 then
		a3 = 900
	end
	local O = p:GetCastPoint()
	local P = p:GetManaCost()
	local minUseful = 350
	local a4 = c.GetNearbyHeroes(b, math.min(M, 3500), true, BOT_MODE_NONE)
	local U = nil

	local function arrowLoc(target)
		local dist = GetUnitToUnitDistance(b, target)
		local travel = O + dist / a3
		return c.GetCorrectLoc(target, travel)
	end

	local function clearShot(target, loc)
		if a.IsEnemyUnitBetweenArrow(b, target, loc, N) then
			return false
		end
		return true
	end

	-- TP interrupt / already disabled: highest priority.
	for W, X in pairs(a4) do
		if
			c.IsValidHero(X)
			and c.IsInRange(b, X, M)
			and not c.IsInRange(b, X, 80)
			and c.CanCastOnNonMagicImmune(X)
			and not c.IsSuspiciousIllusion(X)
		then
			local loc = arrowLoc(X)
			if clearShot(X, loc) then
				if X:HasModifier("modifier_teleporting") then
					return BOT_ACTION_DESIRE_HIGH, loc
				end
				if c.IsDisabled(X) and not c.IsInRange(b, X, minUseful) then
					return BOT_ACTION_DESIRE_HIGH, loc
				end
			end
		end
	end

	-- Engage: lead the target when the lane/path is clear.
	if c.IsGoingOnSomeone(b) then
		if
			c.IsValidHero(botTarget)
			and c.IsInRange(b, botTarget, M)
			and not c.IsInRange(b, botTarget, minUseful)
			and c.CanCastOnNonMagicImmune(botTarget)
			and not c.IsSuspiciousIllusion(botTarget)
			and not botTarget:HasModifier("modifier_abaddon_borrowed_time")
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
			and not botTarget:HasModifier("modifier_oracle_false_promise_timer")
		then
			local loc = arrowLoc(botTarget)
			if clearShot(botTarget, loc) then
				return BOT_ACTION_DESIRE_HIGH, loc
			end
		end
		-- Secondary: any visible enemy with a clean long shot.
		for W, X in pairs(a4) do
			if
				c.IsValidHero(X)
				and c.IsInRange(b, X, M)
				and not c.IsInRange(b, X, minUseful)
				and c.CanCastOnNonMagicImmune(X)
				and not c.IsSuspiciousIllusion(X)
				and not X:HasModifier("modifier_abaddon_borrowed_time")
			then
				local loc = arrowLoc(X)
				if clearShot(X, loc) then
					return BOT_ACTION_DESIRE_HIGH, loc
				end
			end
		end
	end

	-- Retreat: stun chasing heroes.
	if c.IsRetreating(b) and b:WasRecentlyDamagedByAnyHero(3.0) then
		for W, X in pairs(a4) do
			if
				c.IsValidHero(X)
				and c.IsInRange(b, X, M)
				and not c.IsInRange(b, X, 200)
				and c.CanCastOnNonMagicImmune(X)
				and not c.IsSuspiciousIllusion(X)
				and (c.IsChasingTarget(X, b) or b:WasRecentlyDamagedByHero(X, 2.5))
			then
				local loc = arrowLoc(X)
				if clearShot(X, loc) then
					return BOT_ACTION_DESIRE_HIGH, loc
				end
			end
		end
	end

	-- Laning / mid-game poke when mana is fine and shot is clean.
	if (c.IsLaning(b) or E <= 12) and G > 0.45 and #J <= 3 then
		for W, X in pairs(a4) do
			if
				c.IsValidHero(X)
				and c.IsInRange(b, X, math.min(M, 2200))
				and not c.IsInRange(b, X, 500)
				and c.CanCastOnNonMagicImmune(X)
				and not c.IsSuspiciousIllusion(X)
				and not c.IsOtherAllyCanKillTarget(b, X)
			then
				local loc = arrowLoc(X)
				if clearShot(X, loc) then
					return BOT_ACTION_DESIRE_HIGH, loc
				end
			end
		end
	end

	if c.IsFarming(b) and DotaTime() > 4 * 60 and E <= 22 and c.IsAllowedToSpam(b, P) then
		local a2 = b:GetNearbyNeutralCreeps(1600)
		local a5 = c.GetMostHpUnit(a2)
		if c.IsValid(a5) and a5:GetHealth() > 920 and not a5:IsAncientCreep() and not c.IsOtherAllysTarget(a5) then
			U = a5
			return BOT_ACTION_DESIRE_HIGH, U:GetLocation()
		end
	end
	if c.IsDoingRoshan(b) then
		if c.IsRoshan(botTarget) and c.IsInRange(b, botTarget, M) and not c.IsInRange(b, botTarget, 300) then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	if c.IsDoingTormentor(b) then
		if c.IsTormentor(botTarget) and c.IsInRange(botTarget, b, M) and c.IsAttacking(b) then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function a.ConsiderE()
	if not q:IsFullyCastable() or b:IsRooted() then
		return 0
	end
	local L = q:GetLevel()
	local M = q:GetSpecialValueInt("leap_distance")
	local N = b:GetAttackRange()
	local O = q:GetCastPoint()
	local P = q:GetManaCost()
	local Q = 0
	local R = DAMAGE_TYPE_MAGICAL
	local S = c.GetAroundEnemyHeroList(800)
	local T = c.GetAroundEnemyHeroList(1200)
	local U = nil
	local V = nil
	if c.IsGoingOnSomeone(b) and not b:HasModifier("modifier_mirana_leap_buff") then
		if
			c.IsValidHero(botTarget)
			and c.IsInRange(b, botTarget, M + N + 100)
			and not c.IsInRange(b, botTarget, M - 30)
			and not botTarget:IsAttackImmune()
			and c.CanCastOnMagicImmune(botTarget)
			and b:IsFacingLocation(botTarget:GetLocation(), 6)
		then
			local a6 = c.GetNearbyHeroes(botTarget, 900, false, BOT_MODE_NONE)
			local a7 = c.GetNearbyHeroes(botTarget, 1300, true, BOT_MODE_NONE)
			local a8 = c.GetNumOfAliveHeroes(true)
			if
				a8 <= 2
				or #a6 <= 1
				or #a6 <= #a7
				or c.WillKillTarget(botTarget, b:GetAttackDamage() * 3, DAMAGE_TYPE_PHYSICAL, 2.0)
			then
				U = botTarget
				V = "E-进攻:" .. c.Chat.GetNormName(U)
				return BOT_ACTION_DESIRE_HIGH, U, V
			end
		end
	end
	if c.IsStuck(b) then
		U = b
		V = "E-被卡住"
		return BOT_ACTION_DESIRE_HIGH, U, V
	end
	if c.IsRetreating(b) and b:WasRecentlyDamagedByAnyHero(3.0) then
		for W, X in pairs(S) do
			if c.IsValid(X) and not c.IsDisabled(X) and not b:IsFacingLocation(X:GetLocation(), 155) then
				U = X
				V = "E-逃跑:" .. c.Chat.GetNormName(U)
				return BOT_ACTION_DESIRE_HIGH, U, V
			end
		end
	end
	if c.IsFarming(b) and E >= 12 and not b:HasModifier("modifier_mirana_leap_buff") then
		if
			botTarget ~= nil
			and botTarget:IsAlive()
			and c.IsInRange(b, botTarget, M + N + 400)
			and not c.IsInRange(b, botTarget, 1080)
			and b:IsFacingLocation(botTarget:GetLocation(), 6)
		then
			U = botTarget:GetLocation()
			V = "E-打钱赶路"
			return BOT_ACTION_DESIRE_HIGH, U, V
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function a.ConsiderR()
	if not r:IsFullyCastable() then
		return 0
	end
	local L = r:GetLevel()
	local M = r:GetCastRange()
	local N = 600
	local O = r:GetCastPoint()
	local P = r:GetManaCost()
	local Q = r:GetSpecialValueInt("dam")
	local R = DAMAGE_TYPE_MAGICAL
	local S = c.GetAroundEnemyHeroList(M)
	local T = c.GetAroundEnemyHeroList(M + 200)
	local U = nil
	local V = nil
	for a9 = 1, #GetTeamPlayers(GetTeam()) do
		local aa = GetTeamMember(a9)
		if aa ~= nil and aa:IsAlive() and not aa:IsInvisible() then
			if c.IsGoingOnSomeone(aa) then
				local ab = c.GetProperTarget(aa)
				if c.IsValidHero(ab) and not c.IsInRange(aa, ab, 1600) and c.IsInRange(aa, ab, 2800) then
					local ac = c.GetAlliesNearLoc(aa:GetLocation(), 1000)
					if #ac >= 2 then
						U = aa
						V = "R-潜行准备进攻的队友:" .. c.Chat.GetNormName(U)
						return BOT_ACTION_DESIRE_HIGH, U, V
					end
				end
			end
			if c.IsRetreating(aa) then
				local a6 = c.GetNearbyHeroes(aa, 900, true, BOT_MODE_NONE)
				for W, X in pairs(a6) do
					if aa:WasRecentlyDamagedByHero(X, 3.0) then
						U = aa
						V = "R-隐身撤退的队友:" .. c.Chat.GetNormName(U)
						return BOT_ACTION_DESIRE_HIGH, U, V
					end
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function a.IsEnemyCreepBetweenEnemyHero(ad, ae, N)
	return a.IsEnemyUnitBetweenArrow(ad, ae, ae:GetLocation(), N)
end

-- Sacred Arrow only collides with enemy units (not allies).
function a.IsEnemyUnitBetweenArrow(caster, target, aimLoc, width)
	local origin = caster:GetLocation()
	local dest = aimLoc or target:GetLocation()
	local radius = (width or 115) + 25

	local function blocks(unit)
		if not c.IsValid(unit) or unit == target or unit == caster then
			return false
		end
		if unit:GetTeam() == caster:GetTeam() then
			return false
		end
		if unit:IsBuilding() or unit:IsTower() or unit:IsBarracks() or unit:IsFort() then
			return false
		end
		local name = unit:GetUnitName()
		if string.find(name, "ward") or string.find(name, "tome") then
			return false
		end
		local hit = PointToLineDistance(origin, dest, unit:GetLocation())
		if hit ~= nil and hit.within and hit.distance <= radius + unit:GetBoundingRadius() then
			-- Only block if the blocker is closer than the intended target.
			if GetUnitToLocationDistance(caster, unit:GetLocation()) < GetUnitToLocationDistance(caster, dest) - 30 then
				return true
			end
		end
		return false
	end

	local creeps = caster:GetNearbyCreeps(1600, true)
	for _, creep in pairs(creeps) do
		if blocks(creep) then
			return true
		end
	end
	if target ~= nil and target.GetNearbyCreeps ~= nil then
		local nearTarget = target:GetNearbyCreeps(1200, false)
		if nearTarget then
			for _, creep in pairs(nearTarget) do
				if blocks(creep) then
					return true
				end
			end
		end
	end
	local enemies = c.GetNearbyHeroes(caster, 1600, true, BOT_MODE_NONE)
	for _, hero in pairs(enemies) do
		if blocks(hero) then
			return true
		end
	end
	return false
end
function a.ConsiderCelestialQuiver()
	if not c.CanCastAbility(s) or b:IsDisarmed() then
		return BOT_ACTION_DESIRE_NONE
	end
	local Q = s:GetSpecialValueInt("bonus_damage")
	local aj = s:GetAutoCastState()
	local ak = b:GetNearbyHeroes(b:GetAttackRange() + 300, true, BOT_MODE_NONE)
	for W, al in pairs(ak) do
		if
			c.IsValidHero(al)
			and c.CanBeAttacked(al)
			and c.IsInRange(b, al, b:GetAttackRange() + 150)
			and not c.IsSuspiciousIllusion(al)
			and not al:HasModifier("modifier_abaddon_borrowed_time")
			and not al:HasModifier("modifier_dazzle_shallow_grave")
			and not al:HasModifier("modifier_necrolyte_reapers_scythe")
			and not al:HasModifier("modifier_oracle_false_promise_timer")
			and not al:HasModifier("modifier_templar_assassin_refraction_absorb")
		then
			if
				c.WillKillTarget(al, b:GetAttackDamage() + Q, DAMAGE_TYPE_MAGICAL, b:GetAttackSpeed())
				and not c.WillKillTarget(al, b:GetAttackDamage(), DAMAGE_TYPE_PHYSICAL, b:GetAttackSpeed())
			then
				return BOT_ACTION_DESIRE_HIGH, al
			end
		end
	end
	if c.IsGoingOnSomeone(b) then
		if
			c.IsValidHero(botTarget)
			and c.CanBeAttacked(botTarget)
			and c.IsInRange(b, botTarget, b:GetAttackRange() + 300)
			and not c.IsSuspiciousIllusion(botTarget)
			and not botTarget:HasModifier("modifier_abaddon_borrowed_time")
			and not botTarget:HasModifier("modifier_dazzle_shallow_grave")
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
			and not botTarget:HasModifier("modifier_oracle_false_promise_timer")
			and not botTarget:HasModifier("modifier_templar_assassin_refraction_absorb")
		then
			if not aj then
				s:ToggleAutoCast()
			end
			return BOT_ACTION_DESIRE_NONE
		end
	end
	local am = b:GetNearbyCreeps(Min(b:GetAttackRange() + 300, 1600), true)
	if c.IsLaning(b) and c.IsEarlyGame() then
		for W, creep in pairs(am) do
			if
				c.IsValid(creep)
				and c.CanBeAttacked(creep)
				and c.IsKeyWordUnit("ranged", creep)
				and not c.CanKillTarget(creep, b:GetAttackDamage(), DAMAGE_TYPE_PHYSICAL)
			then
				local an = b:FindAoELocation(true, true, creep:GetLocation(), 0, 650, 0, 0)
				if c.WillKillTarget(creep, b:GetAttackDamage() + Q, DAMAGE_TYPE_MAGICAL, b:GetAttackSpeed()) then
					if an.count > 0 or c.IsUnitTargetedByTower(creep, false) or c.IsEnemyTargetUnit(creep, 1200) then
						return BOT_ACTION_DESIRE_HIGH, creep
					end
				end
			end
		end
	end
	if aj then
		s:ToggleAutoCast()
	end
	return BOT_ACTION_DESIRE_NONE
end
return a
