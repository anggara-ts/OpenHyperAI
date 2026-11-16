-- Weaver: skill build, item build, and ability use for this hero.
local a = {}
local b = GetBot()
local c = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local d = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local e = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local f = c.Skill.GetTalentList(b)
local g = c.Skill.GetAbilityList(b)
local h = c.Item.GetRoleItemsBuyList(b)
local i = { ["t25"] = { 10, 0 }, ["t20"] = { 0, 10 }, ["t15"] = { 0, 10 }, ["t10"] = { 10, 0 } }
local j = { { 2, 3, 1, 2, 2, 6, 2, 3, 3, 3, 6, 1, 1, 1, 6 } }
local k = c.Skill.GetRandomBuild(j)
local l = c.Skill.GetTalentBuild(i)
local m = RandomInt(1, 2) == 1 and "item_butterfly" or "item_monkey_king_bar"
local n = {}
n["pos_1"] = {
	"item_tango",
	"item_double_branches",
	"item_faerie_fire",
	"item_wraith_band",
	"item_falcon_blade",
	"item_power_treads",
	"item_magic_wand",
	"item_desolator",
	"item_dragon_lance",
	"item_sphere",
	"item_black_king_bar",
	"item_aghanims_shard",
	"item_greater_crit",
	"item_force_staff",
	"item_hurricane_pike",
	"item_satanic",
	m,
	"item_moon_shard",
	"item_ultimate_scepter_2",
}
n["pos_2"] = n["pos_1"]
n["pos_4"] = n["pos_1"]
n["pos_5"] = n["pos_1"]
n["pos_3"] = n["pos_1"]
a["sBuyList"] = n[h]
a["sSellList"] = { "item_black_king_bar", "item_quelling_blade" }
if c.Role.IsPvNMode() or c.Role.IsAllShadow() then
	a["sBuyList"], a["sSellList"] = { "PvN_antimage" }, {}
end
k, l, a["sBuyList"], a["sSellList"] = c.SetUserHeroInit(k, l, a["sBuyList"], a["sSellList"])
a["sSkillList"] = c.Skill.GetSkillList(g, k, f, l)
a["bDeafaultAbility"] = false
a["bDeafaultItem"] = false
function a.MinionThink(o)
	e.MinionThink(o)
end
local p = SafeAbility(b:GetAbilityByName("weaver_the_swarm"), "weaver_the_swarm", "weaver")
local q = SafeAbility(b:GetAbilityByName("weaver_shukuchi"), "weaver_shukuchi", "weaver")
local r = SafeAbility(b:GetAbilityByName("weaver_time_lapse"), "weaver_time_lapse", "weaver")
-- Geminate Attack is an autocast attack ability in the current game files (AUTOCAST | ATTACK);
-- nothing in this script turned it on, so the second attack depended on the default state.
local geminate = b:GetAbilityByName("weaver_geminate_attack")
-- [OHA-WEAVER] lines: throttled per reason, at most once per 5s.
function a.LogWeaver(why, fmt, ...)
	b._weaverLogAt = b._weaverLogAt or {}
	if DotaTime() < (b._weaverLogAt[why] or -999) then
		return
	end
	b._weaverLogAt[why] = DotaTime() + 5
	pcall(print, string.format("[OHA-WEAVER] t=%.0f " .. why .. " " .. fmt, DotaTime(), ...))
end
-- HP fraction about 5s ago (what Time Lapse gives back), sampled every 0.5s.
function a.HpFiveSecondsAgo()
	local now = DotaTime()
	b._weaverHp = b._weaverHp or {}
	local hist = b._weaverHp
	if #hist == 0 or now - hist[#hist][1] >= 0.5 then
		table.insert(hist, { now, c.GetHP(b) })
		while #hist > 0 and now - hist[1][1] > 6 do
			table.remove(hist, 1)
		end
	end
	for _, s5 in ipairs(hist) do
		if now - s5[1] <= 5.2 then
			return s5[2]
		end
	end
	return c.GetHP(b)
end
local s, t
local u
local v
local w
if b.tryShukuchiKill == nil then
	b.tryShukuchiKill = false
end
if b.ShukuchiKillTarget == nil then
	b.ShukuchiKillTarget = nil
end
local x
local y
local z
local A
function a.SkillsComplement()
	-- Sample HP before the early return so the 5s history has no gaps while stunned.
	local hp5 = a.HpFiveSecondsAgo()
	if geminate ~= nil and not geminate:IsNull() and geminate:IsTrained() and not geminate:GetAutoCastState() then
		geminate:ToggleAutoCast()
		a.LogWeaver("geminate-autocast-on", "")
	end
	if c.CanNotUseAbility(b) then
		return
	end
	x = c.IsRetreating(b)
	y = c.IsAttacking(b)
	z = c.GetHP(b)
	A = c.GetMP(b)
	w = c.GetProperTarget(b)
	-- Grace of 0.5s after the cast so the flag is not cleared before the buff shows up.
	if not b:HasModifier("modifier_weaver_shukuchi") and DotaTime() - (b.ShukuchiKillAt or -99) > 0.5 then
		b.tryShukuchiKill = false
	end
	-- Time Lapse in a fight: it was only considered in retreat mode, so a Weaver burst down while
	-- attacking (mode not yet retreat) died with it ready. Cast when HP fell hard in the last 5s.
	if r:IsFullyCastable() and not x and z < 0.3 and hp5 - z >= 0.25 and b:WasRecentlyDamagedByAnyHero(1.5) then
		a.LogWeaver("lapse-fight", "hp=%.2f hp5=%.2f", z, hp5)
		b:Action_UseAbility(r)
		return
	end
	v, Target = a.ConsiderTimeLapse()
	if v > 0 then
		if Target == "self" then
			b:Action_UseAbility(r)
		else
			if b:HasScepter() then
				b:Action_UseAbilityOnEntity(r, Target)
			end
		end
		return
	end
	-- Shukuchi kill: the cast set tryShukuchiKill but nothing read it, so the bot cast Shukuchi
	-- and kept doing what its mode wanted; the damage only lands on enemies Weaver passes
	-- through (radius 175), so it now walks onto the target, not while retreating, and stops
	-- once inside that radius (the hit has landed).
	if b.tryShukuchiKill and not x then
		local kt = b.ShukuchiKillTarget
		if c.IsValidHero(kt) and GetUnitToUnitDistance(b, kt) > 150 and GetUnitToUnitDistance(b, kt) < 1800 then
			a.LogWeaver("shukuchi-kill-path", "target=%s dist=%d", kt:GetUnitName(), GetUnitToUnitDistance(b, kt))
			b:Action_MoveToLocation(kt:GetExtrapolatedLocation(0.3))
			return
		end
		b.tryShukuchiKill = false
	end
	u = a.ConsiderShukuchi()
	if u > 0 then
		c.SetQueuePtToINT(b, false)
		b:Action_UseAbility(q)
		return
	end
	s, t = a.ConsiderTheSwarm()
	if s > 0 then
		c.SetQueuePtToINT(b, false)
		b:Action_UseAbilityOnLocation(p, t)
		return
	end
end
function a.ConsiderTheSwarm()
	if not p:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local B = p:GetCastRange()
	local C = p:GetSpecialValueInt("spawn_radius")
	if c.IsGoingOnSomeone(b) then
		if
			c.IsValidTarget(w)
			-- The Swarm is SPELL_IMMUNITY_ENEMIES_NO: beetles do not latch a magic-immune hero.
			and c.CanCastOnNonMagicImmune(w)
			and c.IsInRange(b, w, B * 0.8)
			and not c.IsSuspiciousIllusion(w)
			and not w:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			local D = c.GetNearbyHeroes(w, 1200, true, BOT_MODE_NONE)
			local E = c.GetNearbyHeroes(w, 1200, false, BOT_MODE_NONE)
			if D ~= nil and E ~= nil and #D >= #E then
				E = c.GetEnemiesNearLoc(w:GetLocation(), C)
				if E ~= nil and #E >= 1 then
					return BOT_ACTION_DESIRE_HIGH, c.GetCenterOfUnits(E)
				end
				return BOT_ACTION_DESIRE_HIGH, w:GetExtrapolatedLocation(0.5)
			end
		end
	end
	if x then
		local E = c.GetNearbyHeroes(b, 1600, true, BOT_MODE_NONE)
		for F, G in pairs(E) do
			if
				c.IsValidHero(G)
				and c.CanCastOnNonMagicImmune(G)
				and c.IsChasingTarget(G, b)
				and not c.IsSuspiciousIllusion(G)
				and not c.IsDisabled(G)
			then
				local D = c.GetNearbyHeroes(G, 1200, true, BOT_MODE_NONE)
				local H = c.GetNearbyHeroes(G, 1200, false, BOT_MODE_NONE)
				if D ~= nil and H ~= nil and (#H > #D or b:WasRecentlyDamagedByAnyHero(2)) then
					E = c.GetEnemiesNearLoc(G:GetLocation(), C)
					if E ~= nil and #E >= 1 then
						return BOT_ACTION_DESIRE_HIGH, c.GetCenterOfUnits(E)
					end
					return BOT_ACTION_DESIRE_HIGH, G:GetLocation()
				end
			end
		end
	end
	if c.IsPushing(b) or c.IsDefending(b) then
		-- Heroes first: the creep case returned before it, so with 5 creeps in range the swarm
		-- went on the wave even with enemy heroes standing there.
		local J = b:FindAoELocation(true, true, b:GetLocation(), 1600, C, 0, 0)
		local E = c.GetEnemiesNearLoc(J.targetloc, C)
		if E ~= nil and #E >= 1 then
			return BOT_ACTION_DESIRE_HIGH, c.GetCenterOfUnits(E)
		end
		-- Creeps only with spare mana: the swarm is Weaver's fight spell (20-44s cooldown).
		local I = b:GetNearbyLaneCreeps(1600, true)
		if I ~= nil and #I >= 5 and A > 0.5 then
			return BOT_ACTION_DESIRE_HIGH, c.GetCenterOfUnits(I)
		end
	end
	if c.IsDoingRoshan(b) then
		if c.IsRoshan(w) and c.CanCastOnMagicImmune(w) and c.IsInRange(b, w, 500) and y then
			return BOT_ACTION_DESIRE_HIGH, w:GetLocation()
		end
	end
	if c.IsDoingTormentor(b) then
		if c.IsTormentor(w) and c.IsInRange(b, w, 500) and y then
			return BOT_ACTION_DESIRE_HIGH, w:GetLocation()
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function a.ConsiderShukuchi()
	if not q:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
	end
	local K = b:GetAttackRange()
	local L = q:GetSpecialValueInt("damage")
	local M = q:GetSpecialValueFloat("duration")
	local N = 550
	local O = c.GetCurrentRoshanLocation()
	local P = c.GetTormentorLocation(GetTeam())
	local Q = c.GetNearbyHeroes(b, 1600, true, BOT_MODE_NONE)
	for F, G in pairs(Q) do
		if
			c.IsValidHero(G)
			and c.CanCastOnNonMagicImmune(G)
			and c.CanKillTarget(G, L, DAMAGE_TYPE_MAGICAL)
			and G:DistanceFromFountain() > 600
			and not c.IsSuspiciousIllusion(G)
			and not G:HasModifier("modifier_abaddon_borrowed_time")
			and not G:HasModifier("modifier_dazzle_shallow_grave")
			and not G:HasModifier("modifier_necrolyte_reapers_scythe")
			and not G:HasModifier("modifier_oracle_false_promise_timer")
			and not G:HasModifier("modifier_templar_assassin_refraction_absorb")
		then
			local R = GetUnitToUnitDistance(b, G) / N
			if R + 1 < M then
				if c.IsInLaningPhase() then
					local S = G:GetNearbyTowers(700, false)
					if S ~= nil and #S == 0 then
						b.tryShukuchiKill = true
						b.ShukuchiKillTarget = G
						b.ShukuchiKillAt = DotaTime()
						return BOT_ACTION_DESIRE_HIGH
					end
				else
					b.tryShukuchiKill = true
					b.ShukuchiKillTarget = G
					b.ShukuchiKillAt = DotaTime()
					return BOT_ACTION_DESIRE_HIGH
				end
			end
		end
	end
	if c.IsGoingOnSomeone(b) then
		if
			c.IsValidTarget(w)
			and c.CanCastOnMagicImmune(w)
			and not c.IsInRange(b, w, K + 300)
			and not w:HasModifier("modifier_enigma_black_hole_pull")
			and not w:HasModifier("modifier_faceless_void_chronosphere_freeze")
			and not w:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if x then
		local E = c.GetNearbyHeroes(b, 1200, true, BOT_MODE_NONE)
		for F, G in pairs(E) do
			if c.IsValidHero(G) and c.IsChasingTarget(G, b) and not c.IsDisabled(G) then
				local D = c.GetNearbyHeroes(G, 1200, true, BOT_MODE_NONE)
				local H = c.GetNearbyHeroes(G, 1200, false, BOT_MODE_NONE)
				if D ~= nil and H ~= nil and (#H > #D or b:WasRecentlyDamagedByAnyHero(1.5)) then
					return BOT_ACTION_DESIRE_HIGH
				end
			end
		end
		if b:WasRecentlyDamagedByTower(2) then
			return BOT_ACTION_DESIRE_HIGH
		end
		if (c.IsTormentor(w) or c.IsRoshan(w)) and c.IsInRange(b, w, 500) then
			if z < 0.4 then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	if c.IsPushing(b) and A > 0.3 then
		local T = b:GetNearbyTowers(800, true)
		if T ~= nil and #T >= 1 and T[1] ~= nil and c.IsInRange(T[1], b, K) then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if c.IsFarming(b) and z > 0.25 and A > 0.25 then
		local U = b:GetAttackTarget()
		-- Only as a gap closer to a farther target: cast while standing and attacking, Shukuchi
		-- passed through nothing and its invisibility broke on the next attack (65 mana wasted).
		if U ~= nil and GetUnitToUnitDistance(b, U) > K + 200 then
			return BOT_ACTION_DESIRE_MODERATE
		end
	end
	if c.IsDoingRoshan(b) and A > 0.4 then
		local R = GetUnitToLocationDistance(b, O) / N
		if R > M then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if c.IsDoingTormentor(b) and A > 0.4 then
		local R = GetUnitToLocationDistance(b, P) / N
		if R > M then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function a.ConsiderTimeLapse()
	if not r:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	if x then
		local E = c.GetNearbyHeroes(b, 1600, true, BOT_MODE_NONE)
		for F, G in pairs(E) do
			if c.IsValidHero(G) and not c.IsSuspiciousIllusion(G) and not c.IsDisabled(G) then
				local D = c.GetNearbyHeroes(G, 1200, true, BOT_MODE_NONE)
				local H = c.GetNearbyHeroes(G, 1200, false, BOT_MODE_NONE)
				if D ~= nil and H ~= nil and #H > #D then
					if
						z < 0.42
						and q:IsTrained()
						and q:GetCooldownTimeRemaining() < 2.5
						and c.IsChasingTarget(G, b)
					then
						return BOT_ACTION_DESIRE_HIGH, "self"
					end
				end
				if z < 0.33 and b:WasRecentlyDamagedByHero(G, 1) then
					return BOT_ACTION_DESIRE_HIGH, "self"
				end
			end
		end
	end
	if b:HasScepter() then
		local B = r:GetCastRange()
		local D = c.GetNearbyHeroes(b, B, false, BOT_MODE_NONE)
		for F, V in pairs(D) do
			if
				c.IsValidHero(V)
				and c.IsRetreating(V)
				and c.GetHP(V) < 0.33
				and c.IsCore(V)
				and z > 0.75
				and V:WasRecentlyDamagedByAnyHero(2)
				and not c.IsSuspiciousIllusion(V)
				and not V:HasModifier("modifier_legion_commander_duel")
				and not V:HasModifier("modifier_necrolyte_reapers_scythe")
			then
				local E = c.GetNearbyHeroes(V, 1200, true, BOT_MODE_NONE)
				for F, G in pairs(E) do
					if
						c.IsValidHero(G)
						and c.IsChasingTarget(G, V)
						and not c.IsSuspiciousIllusion(G)
						and not c.IsDisabled(G)
					then
						return BOT_ACTION_DESIRE_HIGH, V
					end
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
return a
