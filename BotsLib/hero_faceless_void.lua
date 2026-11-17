-- Faceless Void: skill build, item build, and ability use for this hero.
local a = {}
local b = GetBot()
local c = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local d = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local e = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local f = c.Skill.GetTalentList(b)
local g = c.Skill.GetAbilityList(b)
local h = c.Item.GetRoleItemsBuyList(b)
local i = { ["t25"] = { 0, 10 }, ["t20"] = { 0, 10 }, ["t15"] = { 0, 10 }, ["t10"] = { 10, 0 } }
-- Time Walk first, then Time Lock, Time Dilation last; Chronosphere at 6/12/18.
local j = { { 1, 3, 1, 2, 1, 6, 1, 3, 3, 3, 6, 2, 2, 2, 6 } }
local k = c.Skill.GetRandomBuild(j)
local l = c.Skill.GetTalentBuild(i)
local m = {}
m["pos_1"] = {
	"item_tango",
	"item_double_branches",
	"item_quelling_blade",
	"item_wraith_band",
	"item_power_treads",
	"item_magic_wand",
	"item_mask_of_madness",
	"item_mjollnir",
	"item_black_king_bar",
	"item_skadi",
	"item_aghanims_shard",
	"item_butterfly",
	"item_moon_shard",
	"item_refresher",
	"item_travel_boots",
	"item_travel_boots_2",
	"item_ultimate_scepter_2",
}
m["pos_2"] = m["pos_1"]
m["pos_3"] = m["pos_1"]
m["pos_4"] = m["pos_1"]
m["pos_5"] = m["pos_1"]
a["sBuyList"] = m[h]
a["sSellList"] = { "item_black_king_bar", "item_quelling_blade" }
if c.Role.IsPvNMode() or c.Role.IsAllShadow() then
	a["sBuyList"], a["sSellList"] = { "PvN_antimage" }, {}
end
k, l, a["sBuyList"], a["sSellList"] = c.SetUserHeroInit(k, l, a["sBuyList"], a["sSellList"])
a["sSkillList"] = c.Skill.GetSkillList(g, k, f, l)
a["bDeafaultAbility"] = false
-- Cast when cornered (retreating into 3+ enemies with no way out), before running further.
a["LastStandSpells"] = { { name = "faceless_void_chronosphere", kind = "point" } }
a["bDeafaultItem"] = false
function a.MinionThink(n)
	e.MinionThink(n)
end
local o = SafeAbility(b:GetAbilityByName("faceless_void_time_walk"), "faceless_void_time_walk", "faceless_void")
local p = SafeAbility(b:GetAbilityByName("faceless_void_time_dilation"), "faceless_void_time_dilation", "faceless_void")
local q = SafeAbility(b:GetAbilityByName("faceless_void_chronosphere"), "faceless_void_chronosphere", "faceless_void")
local r = SafeAbility(
	b:GetAbilityByName("faceless_void_time_walk_reverse"),
	"faceless_void_time_walk_reverse",
	"faceless_void"
)
local t, u
local v
local w, x
local y
local B
local E
local F
local G
function a.SkillsComplement()
	if c.CanNotUseAbility(b) then
		return
	end
	F = c.IsGoingOnSomeone(b)
	G = c.IsRetreating(b)
	E = c.GetProperTarget(b)
	y = a.ConsiderTimeWalkReverse()
	if y > 0 then
		b:Action_UseAbility(r)
		return
	end
	t, u = a.ConsiderTimeWalk()
	if t > 0 and IsAllowedToCast(o:GetManaCost()) then
		c.SetQueuePtToINT(b, false)
		b:Action_UseAbilityOnLocation(o, u)
		B = u
		return
	end
	v = a.ConsiderTimeDilation()
	if v > 0 and IsAllowedToCast(p:GetManaCost()) then
		c.SetQueuePtToINT(b, false)
		b:Action_UseAbility(p)
		return
	end
	w, x = a.ConsiderChronosphere()
	if w > 0 then
		b:Action_UseAbilityOnLocation(q, x)
		return
	end
end
function a.CanUseRefresherShard()
	local H = 1000
	local I = "none"
	local J = nil
	local K = "刷新技能"
	local L = c.GetNearbyHeroes(b, H, true, BOT_MODE_NONE)
	if
		#L > 0
		and (F or c.IsInTeamFight(b))
		and c.CanUseRefresherShard(b)
		and not b:HasModifier("modifier_faceless_void_chronosphere_speed")
	then
		return BOT_ACTION_DESIRE_HIGH, J, I, K
	end
	return false
end
function a.ConsiderTimeWalk()
	if not o:IsFullyCastable() or b:HasModifier("modifier_faceless_void_chronosphere_speed") then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local H = o:GetSpecialValueInt("range")
	local M = o:GetCastPoint()
	local N = o:GetSpecialValueInt("speed")
	local O = o:GetSpecialValueInt("backtrack_duration")
	local P = c.GetNearbyHeroes(b, 1600, true, BOT_MODE_NONE)
	if c.IsStuck(b) then
		return BOT_ACTION_DESIRE_HIGH, c.Site.GetXUnitsTowardsLocation(b, c.GetEscapeLoc(), H)
	end
	if c.IsStunProjectileIncoming(b, 600) or c.IsUnitTargetProjectileIncoming(b, 400) then
		return BOT_ACTION_DESIRE_HIGH, c.Site.GetXUnitsTowardsLocation(b, c.GetEscapeLoc(), H)
	end
	if not b:HasModifier("modifier_sniper_assassinate") and not b:IsMagicImmune() then
		if c.IsWillBeCastUnitTargetSpell(b, 400) then
			return BOT_ACTION_DESIRE_HIGH, c.Site.GetXUnitsTowardsLocation(b, c.GetEscapeLoc(), H)
		end
	end
	if F then
		if
			c.IsValidTarget(E)
			and c.CanCastOnNonMagicImmune(E)
			and not c.IsSuspiciousIllusion(E)
			and not c.IsDisabled(E)
			and not E:IsAttackImmune()
			and not E:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			local Q = c.GetNearbyHeroes(E, 1200, true, BOT_MODE_NONE)
			local R = c.GetNearbyHeroes(E, 1200, false, BOT_MODE_NONE)
			local S = GetUnitToUnitDistance(b, E) / N + M
			local T = c.Site.GetXUnitsTowardsLocation(b, E:GetExtrapolatedLocation(S), H)
			if Q ~= nil and R ~= nil and #Q >= #R and IsLocationPassable(T) and not c.IsLocationInArena(T, 600) then
				if GetUnitToLocationDistance(b, T) > b:GetAttackRange() * 2 then
					if c.IsInLaningPhase() then
						local U = c.GetHP(b)
						local V = E:GetHealth()
						local W = b:GetAttackDamage()
						-- Target low, not Void low: "U < 0.3" (Void's own HP) made him Time Walk in when he
					-- was nearly dead and skip it when the target was.
					local X = c.GetHP(E) < 0.3
						local Y = V <= W * 3
						local Z = E:GetNearbyTowers(700, false)
						if (X or Y) and Z ~= nil and #Z == 0 then
							return BOT_ACTION_DESIRE_HIGH, T
						end
					else
						return BOT_ACTION_DESIRE_HIGH, T
					end
				end
			end
		end
	end
	if G then
		local R = c.GetNearbyHeroes(b, 1200, true, BOT_MODE_NONE)
		for _, a0 in pairs(R) do
			if
				c.IsValidHero(a0)
				and c.IsInRange(b, a0, H)
				and not c.IsSuspiciousIllusion(a0)
				and not c.IsDisabled(a0)
				and not c.IsRealInvisible(b)
			then
				local Q = c.GetNearbyHeroes(a0, 1200, true, BOT_MODE_NONE)
				local a1 = c.GetNearbyHeroes(a0, 1200, false, BOT_MODE_NONE)
				if Q ~= nil and a1 ~= nil and (#a1 > #Q or b:WasRecentlyDamagedByHero(a0, O)) then
					return BOT_ACTION_DESIRE_HIGH, c.Site.GetXUnitsTowardsLocation(b, c.GetEscapeLoc(), H)
				end
			end
		end
	end
	if c.IsPushing(b) then
		local a2 = b:GetNearbyLaneCreeps(H, true)
		if a2 ~= nil and #a2 >= 3 and GetUnitToLocationDistance(b, c.GetCenterOfUnits(a2)) > 500 then
			return BOT_ACTION_DESIRE_HIGH, c.GetCenterOfUnits(a2)
		end
	end
	if c.IsFarming(b) then
		if c.IsValid(E) and GetUnitToUnitDistance(b, E) > 500 then
			return BOT_ACTION_DESIRE_HIGH, E:GetLocation()
		end
	end
	if c.IsLaning(b) then
		local a2 = b:GetNearbyLaneCreeps(H, true)
		if
			(b:GetMana() - o:GetManaCost()) / b:GetMaxMana() > 0.85
			and b:DistanceFromFountain() > 100
			and b:DistanceFromFountain() < 6000
			and c.IsInLaningPhase()
			and #P == 0
		then
			local a3 = b:GetAssignedLane()
			local a4 = GetLaneFrontLocation(GetTeam(), a3, 0)
			local a5 = GetUnitToLocationDistance(b, a4)
			if a5 > H then
				local a6 = c.Site.GetXUnitsTowardsLocation(b, a4, H)
				if IsLocationPassable(a6) then
					return BOT_ACTION_DESIRE_HIGH, a6
				end
			end
		end
	end
	if c.IsDoingRoshan(b) then
		local a7 = c.GetCurrentRoshanLocation()
		if GetUnitToLocationDistance(b, a7) > H then
			local a8 = c.Site.GetXUnitsTowardsLocation(b, a7, H)
			local R = c.GetEnemiesNearLoc(a7, 1600)
			if R ~= nil and #R == 0 and IsLocationPassable(a8) then
				return BOT_ACTION_DESIRE_HIGH, a8
			end
		end
	end
	if c.IsDoingTormentor(b) then
		local a9 = c.GetTormentorLocation(GetTeam())
		if GetUnitToLocationDistance(b, a9) > H then
			local a8 = c.Site.GetXUnitsTowardsLocation(b, a9, H)
			local R = c.GetEnemiesNearLoc(a8, 1600)
			if R ~= nil and #R == 0 and IsLocationPassable(a8) then
				return BOT_ACTION_DESIRE_HIGH, a8
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function a.ConsiderTimeDilation()
	if not p:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
	end
	local aa = p:GetSpecialValueInt("radius")
	if c.IsInTeamFight(b, 1200) then
		local R = c.GetEnemiesNearLoc(b:GetLocation(), aa)
		if R ~= nil and #R >= 2 then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if F then
		if
			c.IsValidTarget(E)
			and c.CanCastOnNonMagicImmune(E)
			and c.IsInRange(b, E, aa)
			and not c.IsSuspiciousIllusion(E)
			and not c.IsDisabled(E)
			and not E:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if G then
		local R = c.GetNearbyHeroes(b, aa, true, BOT_MODE_NONE)
		for _, a0 in pairs(R) do
			if
				c.IsValidHero(a0)
				and c.CanCastOnNonMagicImmune(a0)
				and not c.IsSuspiciousIllusion(a0)
				and not c.IsDisabled(a0)
			then
				local Q = c.GetNearbyHeroes(a0, 1200, true, BOT_MODE_NONE)
				local a1 = c.GetNearbyHeroes(a0, 1200, false, BOT_MODE_NONE)
				if Q ~= nil and a1 ~= nil and (#Q >= #a1 or b:WasRecentlyDamagedByHero(a0, 2.5)) then
					return BOT_ACTION_DESIRE_HIGH
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function a.ConsiderChronosphere()
	if not q:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local H = q:GetCastRange()
	local M = q:GetCastPoint()
	local aa = q:GetSpecialValueInt("radius")
	local ab = q:GetSpecialValueInt("duration")
	local ac = b:GetAttackDamage()
	local ad = b:GetAttackSpeed()
	local ae = GetHeroKills(b:GetPlayerID())
	local af = GetHeroDeaths(b:GetPlayerID())
	if c.IsInTeamFight(b, 1200) then
		local ag = b:FindAoELocation(true, true, b:GetLocation(), H, aa / 1.2, M, 0)
		local R = c.GetEnemiesNearLoc(ag.targetloc, aa / 1.2)
		-- Chronosphere pauses allies too (datafeed: "friendly or enemy, except those owned by
		-- Faceless Void"). Skip a sphere that freezes as many of our heroes as enemies.
		local frozen = a.AlliesInChrono(ag.targetloc, aa)
		if R ~= nil and #R >= 2 and frozen >= #R then
			a.LogChrono("skip-allies", #R, frozen)
		end
		if R ~= nil and #R >= 2 and frozen < #R then
			local ah = nil
			local ai = 10000
			for _, a0 in pairs(R) do
				if
					c.IsValidHero(a0)
					and not c.IsSuspiciousIllusion(a0)
					and not a0:IsAttackImmune()
					and not a0:HasModifier("modifier_abaddon_borrowed_time")
					and not a0:HasModifier("modifier_dazzle_shallow_grave")
					and not a0:HasModifier("modifier_necrolyte_reapers_scythe")
					and not a0:HasModifier("modifier_oracle_false_promise_timer")
					and not a0:HasModifier("modifier_templar_assassin_refraction_absorb")
					and a0:GetHealth() < ai
				then
					ai = a0:GetHealth()
					ah = a0
				end
			end
			if ah ~= nil then
				b:SetTarget(ah)
				return BOT_ACTION_DESIRE_HIGH, ag.targetloc
			end
		end
	end
	if F then
		if
			c.IsValidTarget(E)
			and c.CanCastOnMagicImmune(E)
			and c.IsInRange(b, E, H + aa)
			and not c.IsSuspiciousIllusion(E)
			and not E:IsAttackImmune()
			and not E:HasModifier("modifier_necrolyte_reapers_scythe")
			and not E:HasModifier("modifier_templar_assassin_refraction_absorb")
		then
			local Q = c.GetNearbyHeroes(b, 1200, false, BOT_MODE_NONE)
			local R = c.GetNearbyHeroes(b, 1200, true, BOT_MODE_NONE)
			if Q ~= nil and R ~= nil and #Q >= #R and #Q <= 1 and #R <= 1 then
				local T = c.Site.GetXUnitsTowardsLocation(b, E:GetLocation(), H)
				if
					c.CanKillTarget(E, ac * ad * ab, DAMAGE_TYPE_PHYSICAL)
					and not c.IsLocationInChrono(T)
					and not c.IsLocationInBlackHole(T)
					and not c.IsLocationInArena(T, aa)
				then
					b:SetTarget(E)
					return BOT_ACTION_DESIRE_HIGH, T
				end
			end
		end
	end
	if G then
		local Q = c.GetNearbyHeroes(b, 1200, false, BOT_MODE_NONE)
		local R = c.GetNearbyHeroes(b, 1200, true, BOT_MODE_NONE)
		for _, a0 in pairs(R) do
			if
				Q ~= nil
				and R ~= nil
				and c.IsValidHero(a0)
				and c.IsChasingTarget(a0, b)
				and not c.IsSuspiciousIllusion(a0)
				and not c.IsDisabled(a0)
				and not R[1]:HasModifier("modifier_legion_commander_duel")
				and not R[1]:HasModifier("modifier_necrolyte_reapers_scythe")
			then
				local a1 = c.GetNearbyHeroes(R[1], 1200, false, BOT_MODE_NONE)
				if a1 ~= nil and #a1 > #Q + 2 and #Q <= 1 then
					local ag = b:FindAoELocation(true, true, b:GetLocation(), H, aa, M, 0)
					local aj = c.GetEnemiesNearLoc(ag.targetloc, aa)
					if
						aj ~= nil
						and #aj >= 1
						and not c.IsLocationInChrono(ag.targetloc)
						and not c.IsLocationInBlackHole(ag.targetloc)
						and not c.IsLocationInArena(ag.targetloc, aa)
						and a.AlliesInChrono(ag.targetloc, aa) < #aj
					then
						return BOT_ACTION_DESIRE_HIGH, ag.targetloc
					end
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
-- Our heroes (not Void) that a sphere at loc would pause.
function a.AlliesInChrono(loc, radius)
	local n = 0
	for _, ally in pairs(c.GetAlliesNearLoc(loc, radius) or {}) do
		if ally ~= b and c.IsValidHero(ally) and not ally:IsIllusion() then
			n = n + 1
		end
	end
	return n
end
function a.LogChrono(why, enemies, allies)
	if DotaTime() < (b._chronoLogAt or -999) then
		return
	end
	b._chronoLogAt = DotaTime() + 5
	pcall(print, string.format("[OHA-VOID] t=%.0f chrono %s enemies=%d allies=%d", DotaTime(), why, enemies, allies))
end
function a.ConsiderTimeWalkReverse()
	if not r:IsTrained() or not r:IsFullyCastable() or not r:IsActivated() then
		return BOT_ACTION_DESIRE_NONE
	end
	if c.IsStunProjectileIncoming(b, 600) or c.IsUnitTargetProjectileIncoming(b, 400) then
		return BOT_ACTION_DESIRE_HIGH
	end
	if not b:HasModifier("modifier_sniper_assassinate") and not b:IsMagicImmune() then
		if c.IsWillBeCastUnitTargetSpell(b, 400) then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if
		not b:HasModifier("modifier_faceless_void_chronosphere_speed")
		and c.IsValidTarget(E)
		and c.IsInRange(b, E, b:GetCurrentVisionRange())
		and not c.IsSuspiciousIllusion(E)
	then
		local Q = c.GetNearbyHeroes(E, 1200, true, BOT_MODE_NONE)
		local R = c.GetNearbyHeroes(E, 1200, false, BOT_MODE_NONE)
		if Q ~= nil and R ~= nil then
			if
				#R > #Q
				and GetUnitToLocationDistance(b, B) > GetUnitToLocationDistance(E, B)
				and GetUnitToLocationDistance(b, B) > GetUnitToUnitDistance(b, E)
			then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function IsAllowedToCast(al)
	if q ~= nil and not q:IsNull() and q:IsTrained() and q:IsFullyCastable() then
		local am = q:GetManaCost()
		if b:GetMana() - al * 2 > am then
			return true
		else
			return false
		end
	end
	return true
end
return a
