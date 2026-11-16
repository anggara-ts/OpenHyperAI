-- Treant: skill build, item build, and ability use for this hero.
local a = {}
local b = GetBot()
local c = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local d = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local e = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local f = c.Skill.GetTalentList(b)
local g = c.Skill.GetAbilityList(b)
local h = c.Item.GetRoleItemsBuyList(b)
local i = { ["t25"] = { 0, 10 }, ["t20"] = { 0, 10 }, ["t15"] = { 10, 0 }, ["t10"] = { 10, 0 } }
local j = { { 2, 1, 3, 1, 3, 6, 3, 1, 1, 3, 6, 2, 2, 2, 6 } }
local k = c.Skill.GetRandomBuild(j)
local l = c.Skill.GetTalentBuild(i)
local m = {}
m["pos_4"] = {
	"item_double_tango",
	"item_faerie_fire",
	"item_wind_lace",
	"item_arcane_boots",
	"item_magic_wand",
	"item_guardian_greaves",
	"item_blink",
	"item_aghanims_shard",
	"item_meteor_hammer",
	"item_lotus_orb",
	"item_gungir",
	"item_wind_waker",
	"item_ultimate_scepter",
	"item_overwhelming_blink",
	"item_ultimate_scepter_2",
	"item_moon_shard",
}
m["pos_5"] = {
	"item_tango",
	"item_double_branches",
	"item_enchanted_mango",
	"item_blood_grenade",
	"item_wind_lace",
	"item_boots",
	"item_ring_of_basilius",
	"item_magic_wand",
	"item_arcane_boots",
	"item_pipe",
	"item_aghanims_shard",
	"item_blink",
	"item_glimmer_cape",
	"item_meteor_hammer",
	"item_ultimate_scepter",
	"item_sheepstick",
	"item_overwhelming_blink",
	"item_ultimate_scepter_2",
	"item_moon_shard",
}
m["pos_3"] = {
	"item_tango",
	"item_double_branches",
	"item_enchanted_mango",
	"item_wind_lace",
	"item_boots",
	"item_ring_of_basilius",
	"item_magic_wand",
	"item_arcane_boots",
	"item_aghanims_shard",
	"item_blink",
	"item_glimmer_cape",
	"item_pipe",
	"item_meteor_hammer",
	"item_ultimate_scepter",
	"item_sheepstick",
	"item_overwhelming_blink",
	"item_ultimate_scepter_2",
	"item_moon_shard",
}
m["pos_1"] = {
	"item_bristleback_outfit",
	"item_aghanims_shard",
	"item_blade_mail",
	"item_heavens_halberd",
	"item_lotus_orb",
	"item_black_king_bar",
	"item_travel_boots",
	"item_heart",
	"item_moon_shard",
	"item_travel_boots_2",
}
m["pos_2"] = m["pos_1"]
a["sBuyList"] = m[h]
a["sSellList"] = { "item_black_king_bar", "item_quelling_blade" }
if c.Role.IsPvNMode() or c.Role.IsAllShadow() then
	a["sBuyList"], a["sSellList"] = { "PvN_antimage" }, {}
end
k, l, a["sBuyList"], a["sSellList"] = c.SetUserHeroInit(k, l, a["sBuyList"], a["sSellList"])
a["sSkillList"] = c.Skill.GetSkillList(g, k, f, l)
a["bDeafaultAbility"] = false
-- Cast when cornered (retreating into 3+ enemies with no way out), before running further.
a["LastStandSpells"] = { { name = "treant_overgrowth", kind = "none" } }
a["bDeafaultItem"] = false
function a.MinionThink(n)
	e.MinionThink(n)
end
local o = false
local p = SafeAbility(b:GetAbilityByName("treant_natures_grasp"), "treant_natures_grasp", "treant")
local q = SafeAbility(b:GetAbilityByName("treant_leech_seed"), "treant_leech_seed", "treant")
local r = SafeAbility(b:GetAbilityByName("treant_living_armor"), "treant_living_armor", "treant")
local s = SafeAbility(b:GetAbilityByName("treant_eyes_in_the_forest"), "treant_eyes_in_the_forest", "treant")
local t = SafeAbility(b:GetAbilityByName("treant_overgrowth"), "treant_overgrowth", "treant")
local u, v
local w, x
local y, z
local A, B
local C
local D
local E, F
local G
local H
local I
local J
local K
function a.SkillsComplement()
	if c.CanNotUseAbility(b) then
		return
	end
	local L = d.Build(b)
	H = L.isEngaging
	I = c.IsAttacking(b)
	J = L.hp
	K = L.isTeamFight
	E, F = a.ConsiderBlinkOvergrowth()
	if E > 0 then
		b:Action_ClearActions(false)
		b:ActionQueue_UseAbilityOnLocation(D, F)
		b:ActionQueue_Delay(0.1)
		b:ActionQueue_UseAbility(t)
		return
	end
	C = a.ConsiderOvergrowth()
	if C > 0 then
		b:Action_UseAbility(t)
		return
	end
	u, v = a.ConsiderNaturesGrasp()
	if u > 0 then
		b:Action_UseAbilityOnLocation(p, v)
		return
	end
	w, x = a.ConsiderLeechSeed()
	-- datafeed: Leech Seed is now unit-target only (behavior 135176 = unit target + autocast +
	-- attack, range 150); the old point-cast path (o) could never be used, so it always casts on a unit.
	if w > 0 and c.IsValid(x) then
		o = false
		b:Action_UseAbilityOnEntity(q, x)
		return
	end
	A, B = a.ConsiderEyesInTheForest()
	if A > 0 then
		b:Action_UseAbilityOnTree(s, B)
		return
	end
	y, z = a.ConsiderLivingArmor()
	if y > 0 then
		b:Action_UseAbilityOnEntity(r, z)
		return
	end
end
function a.ConsiderNaturesGrasp()
	if not p:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local M = c.GetProperCastRange(false, b, p:GetCastRange())
	local N = p:GetSpecialValueInt("latch_range")
	G = c.GetProperTarget(b)
	if K then
		local O = b:FindAoELocation(true, true, b:GetLocation(), M, N, 0, 0)
		local P = c.GetEnemiesNearLoc(O.targetloc, N)
		if P ~= nil and #P >= 2 then
			return BOT_ACTION_DESIRE_HIGH, O.targetloc
		end
	end
	if H then
		if
			c.IsValidTarget(G)
			and c.CanCastOnNonMagicImmune(G)
			and c.IsInRange(b, G, M)
			and not c.IsSuspiciousIllusion(G)
			and not c.IsDisabled(G)
			and not G:HasModifier("modifier_necrolyte_reapers_scythe")
			and not c.IsLocationInChrono(G:GetLocation())
		then
			local Q = c.GetNearbyHeroes(G, 1200, true, BOT_MODE_NONE)
			local R = c.GetNearbyHeroes(G, 1200, false, BOT_MODE_NONE)
			if Q ~= nil and R ~= nil and #Q >= #R then
				return BOT_ACTION_DESIRE_HIGH, G:GetLocation()
			end
		end
	end
	if c.IsRetreating(b) then
		local Q = c.GetNearbyHeroes(b, 1200, false, BOT_MODE_NONE)
		local P = c.GetNearbyHeroes(b, 1200, true, BOT_MODE_NONE)
		if
			Q ~= nil
			and P
			and c.IsValidHero(P[1])
			and c.CanCastOnNonMagicImmune(P[1])
			and c.IsChasingTarget(P[1], b)
			and not c.IsSuspiciousIllusion(P[1])
			and not c.IsDisabled(P[1])
			and not P[1]:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			local R = c.GetNearbyHeroes(P[1], 1000, false, BOT_MODE_NONE)
			if R ~= nil and (#R > #Q or J < 0.75 and b:WasRecentlyDamagedByAnyHero(1)) then
				return BOT_ACTION_DESIRE_HIGH, P[1]:GetLocation()
			end
		end
	end
	if c.IsDefending(b) then
		local O = b:FindAoELocation(true, false, b:GetLocation(), M, N, 0, 0)
		local S = b:GetNearbyLaneCreeps(M, true)
		if S ~= nil and #S >= 3 and O.count >= 3 and c.CanBeAttacked(S[1]) then
			return BOT_ACTION_DESIRE_HIGH, c.GetCenterOfUnits(S)
		end
		O = b:FindAoELocation(true, true, b:GetLocation(), M, N, 0, 0)
		if O.count >= 1 then
			return BOT_ACTION_DESIRE_HIGH, O.targetloc
		end
	end
	if c.IsLaning(b) then
		local T = c.GetStrongestUnit(M, b, true, false, 5)
		if
			c.IsValidTarget(T)
			and c.CanCastOnNonMagicImmune(T)
			and not c.IsSuspiciousIllusion(T)
			and not T:HasModifier("modifier_abaddon_borrowed_time")
			and not T:HasModifier("modifier_dazzle_shallow_grave")
			and not T:HasModifier("modifier_necrolyte_reapers_scythe")
			and c.GetMP(b) > 0.75
		then
			return BOT_ACTION_DESIRE_HIGH, T:GetLocation()
		end
		if not c.IsInLaningPhase() then
			local O = b:FindAoELocation(true, false, b:GetLocation(), M, N, 0, 0)
			local S = b:GetNearbyLaneCreeps(M, true)
			if S ~= nil and #S >= 3 and O.count >= 3 and c.CanBeAttacked(S[1]) then
				return BOT_ACTION_DESIRE_HIGH, c.GetCenterOfUnits(S)
			end
		end
	end
	if c.IsDoingRoshan(b) then
		if c.IsRoshan(G) and c.CanCastOnNonMagicImmune(G) and c.IsInRange(b, G, 500) and I then
			return BOT_ACTION_DESIRE_HIGH, G:GetLocation()
		end
	end
	if c.IsDoingTormentor(b) then
		if c.IsTormentor(G) and c.IsInRange(b, G, 500) and I then
			return BOT_ACTION_DESIRE_HIGH, G:GetLocation()
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function a.ConsiderLeechSeed()
	if not q:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local M = c.GetProperCastRange(false, b, q:GetCastRange())
	G = c.GetProperTarget(b)
	local N = q:GetSpecialValueInt("radius")
	if H then
		o = false
		if c.IsValidHero(G) and c.CanCastOnNonMagicImmune(G) and not c.IsChasingTarget(b, G) then
			local O = b:FindAoELocation(true, true, G:GetLocation(), 0, N, 0, 0)
			-- datafeed: unit-target now, so seed the hero itself (it was a point cast on the group).
			if O.count >= 2 and c.IsInRange(b, G, M) then
				return BOT_ACTION_DESIRE_HIGH, G
			end
		end
		local P = c.GetNearbyHeroes(b, 1200, true, BOT_MODE_NONE)
		local U = nil
		local V = 0
		for W, X in pairs(P) do
			if
				c.IsValidHero(X)
				and c.CanCastOnNonMagicImmune(X)
				and c.IsInRange(b, X, M)
				and not c.IsSuspiciousIllusion(X)
				and not c.IsDisabled(X)
				and not X:HasModifier("modifier_abaddon_borrowed_time")
				and not X:HasModifier("modifier_dazzle_shallow_grave")
				and not X:HasModifier("modifier_necrolyte_reapers_scythe")
				and not X:HasModifier("modifier_treant_natures_grasp_damage")
			then
				local Q = c.GetNearbyHeroes(X, 1200, true, BOT_MODE_NONE)
				local R = c.GetNearbyHeroes(X, 1200, false, BOT_MODE_NONE)
				local Y = X:GetEstimatedDamageToTarget(false, b, 5, DAMAGE_TYPE_ALL)
				if Q ~= nil and R ~= nil and #Q >= #R and Y > V then
					V = Y
					U = X
				end
			end
		end
		if U ~= nil then
			return BOT_ACTION_DESIRE_MODERATE, U
		end
	end
	if c.IsRetreating(b) then
		local Q = c.GetNearbyHeroes(b, 1200, false, BOT_MODE_NONE)
		local P = c.GetNearbyHeroes(b, 1200, true, BOT_MODE_NONE)
		if
			Q ~= nil
			and P
			and c.IsValidHero(P[1])
			and c.CanCastOnNonMagicImmune(P[1])
			and c.IsInRange(b, P[1], M)
			and c.IsChasingTarget(P[1], b)
			and not c.IsSuspiciousIllusion(P[1])
			and not c.IsDisabled(P[1])
			and not P[1]:HasModifier("modifier_treant_natures_grasp_damage")
		then
			if #P > #Q or J < 0.75 and b:WasRecentlyDamagedByAnyHero(1.5) then
				return BOT_ACTION_DESIRE_HIGH, P[1]
			end
		end
	end
	if c.IsDoingRoshan(b) then
		if c.IsRoshan(G) and c.CanCastOnNonMagicImmune(G) and c.IsInRange(b, G, 500) and I then
			-- datafeed: unit-target now; seed Roshan instead of a point at Treant's feet.
			return BOT_ACTION_DESIRE_HIGH, G
		end
	end
	if c.IsDoingTormentor(b) then
		if c.IsTormentor(G) and c.IsInRange(b, G, 500) and I then
			return BOT_ACTION_DESIRE_HIGH, G
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function a.ConsiderLivingArmor()
	if not r:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local Z = nil
	local _ = 0
	-- In a fight an ally being focused comes first: the pick below takes the ally with the most
	-- offensive power, at any HP, so a dying support never got the block. Under 50% HP and hit by a
	-- hero in the last 2s, lowest HP first. Logged: [OHA-TREANT] armor-save.
	if H or c.IsInTeamFight(b, 1600) then
		local save, saveHP = nil, 0.5
		for W, a0 in pairs(c.GetNearbyHeroes(b, 1600, false, BOT_MODE_NONE) or {}) do
			if
				c.IsValidHero(a0)
				and not c.IsMeepoClone(a0)
				and not a0:IsIllusion()
				and not a0:HasModifier("modifier_arc_warden_tempest_double")
				and not a0:HasModifier("modifier_treant_living_armor")
				and c.GetHP(a0) < saveHP
				and a0:WasRecentlyDamagedByAnyHero(2)
			then
				save, saveHP = a0, c.GetHP(a0)
			end
		end
		if save ~= nil then
			if DotaTime() >= (b._treantArmorLogAt or -999) then
				b._treantArmorLogAt = DotaTime() + 5
				pcall(print, string.format(
					"[OHA-TREANT] t=%.0f armor-save ally=%s hp=%.2f",
					DotaTime(),
					(string.gsub(save:GetUnitName(), "npc_dota_hero_", "")),
					saveHP
				))
			end
			return BOT_ACTION_DESIRE_HIGH, save
		end
	end
	if H or c.IsInTeamFight(b, 1600) then
		local Q = c.GetNearbyHeroes(b, 1600, false, BOT_MODE_NONE)
		for W, a0 in pairs(Q) do
			if
				c.IsValidHero(a0)
				and not c.IsMeepoClone(a0)
				and not a0:IsIllusion()
				and not a0:HasModifier("modifier_arc_warden_tempest_double")
				and not a0:HasModifier("modifier_treant_living_armor")
				and not a0:HasModifier("modifier_fountain_aura")
			then
				if _ < a0:GetOffensivePower() then
					_ = a0:GetOffensivePower()
					Z = a0
				end
			end
		end
	end
	if Z ~= nil then
		return BOT_ACTION_DESIRE_HIGH, Z
	end
	local a1 = nil
	local a2 = 0.7
	for W, a0 in pairs(GetUnitList(UNIT_LIST_ALLIED_HEROES)) do
		if
			c.IsValidHero(a0)
			and not c.IsMeepoClone(a0)
			and not a0:IsIllusion()
			and not a0:HasModifier("modifier_arc_warden_tempest_double")
			and not a0:HasModifier("modifier_treant_living_armor")
			and not a0:HasModifier("modifier_fountain_aura")
		then
			if c.GetHP(a0) < a2 and c.GetHP(a0) < 0.7 then
				a2 = c.GetHP(a0)
				a1 = a0
			end
		end
	end
	if a1 ~= nil then
		return BOT_ACTION_DESIRE_HIGH, a1
	end
	local a3 = nil
	local a4 = 0.8
	for W, a5 in pairs(GetUnitList(UNIT_LIST_ALLIED_BUILDINGS)) do
		if c.IsValidBuilding(a5) and not a5:HasModifier("modifier_treant_living_armor") then
			if a5:GetHealth() / a5:GetMaxHealth() < a4 and a5:GetHealth() / a5:GetMaxHealth() < 0.8 then
				a4 = a5:GetHealth() / a5:GetMaxHealth()
				a3 = a5
			end
		end
	end
	if a3 ~= nil then
		return BOT_ACTION_DESIRE_HIGH, a3
	end
	if
		J < 0.75
		and not b:HasModifier("modifier_treant_living_armor")
		and not b:HasModifier("modifier_fountain_aura")
	then
		return BOT_ACTION_DESIRE_HIGH, b
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function a.ConsiderOvergrowth()
	if not t:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
	end
	local N = t:GetSpecialValueInt("radius")
	-- K (2+ allies in attack mode) used to be required, so Overgrowth stayed unused when Treant
	-- was going in on someone with fewer allies in attack mode, or caught by 3 enemies while
	-- defending. Now: 2+ enemies in radius (datafeed 800) in a fight or while engaging, or 3+ anytime.
	-- Logged: [OHA-TREANT] overgrowth.
	local P = c.GetEnemiesNearLoc(b:GetLocation(), N)
	if
		P ~= nil
		and (#P >= 3 or #P >= 2 and (K or H))
		and not c.IsLocationInChrono(b:GetLocation())
		and not c.IsLocationInBlackHole(b:GetLocation())
	then
		if not K and DotaTime() >= (b._treantOvergrowthLogAt or -999) then
			b._treantOvergrowthLogAt = DotaTime() + 10
			pcall(print, string.format(
				"[OHA-TREANT] t=%.0f overgrowth enemies=%d engaging=%s (not a team fight)",
				DotaTime(),
				#P,
				tostring(H)
			))
		end
		return BOT_ACTION_DESIRE_HIGH
	end
	return BOT_ACTION_DESIRE_NONE
end
function a.ConsiderEyesInTheForest()
	if not s:IsTrained() or not s:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local M = c.GetProperCastRange(false, b, s:GetCastRange())
	local N = s:GetSpecialValueInt("vision_aoe")
	G = c.GetProperTarget(b)
	if H then
		if
			c.IsValidTarget(G)
			and c.IsInRange(b, G, N)
			and not c.IsSuspiciousIllusion(G)
			and not G:HasModifier("modifier_treant_eyes_in_the_forest")
		then
			local Q = c.GetNearbyHeroes(G, 1200, true, BOT_MODE_NONE)
			local R = c.GetNearbyHeroes(G, 1200, false, BOT_MODE_NONE)
			local a6 = b:GetNearbyTrees(M)
			if Q ~= nil and R ~= nil and #Q >= #R and #Q >= 1 and a6 ~= nil and #a6 >= 1 then
				return BOT_ACTION_DESIRE_HIGH, a6[1]
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function a.ConsiderBlinkOvergrowth()
	if CanDoBlinkOvergrowth() then
		local N = t:GetSpecialValueInt("radius")
		if K then
			local O = b:FindAoELocation(true, true, b:GetLocation(), 1199, N, 0, 0)
			local P = c.GetEnemiesNearLoc(O.targetloc, N)
			if
				P ~= nil
				and #P >= 2
				and not c.IsLocationInChrono(O.targetloc)
				and not c.IsLocationInBlackHole(O.targetloc)
				and GetUnitToLocationDistance(b, O.targetloc) > 600
			then
				return BOT_ACTION_DESIRE_HIGH, O.targetloc
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function CanDoBlinkOvergrowth()
	-- datafeed item_blink: blink_damage_cooldown 3, so Blink cannot be used within 3s of hero damage;
	-- the queued Overgrowth would then go off where Treant stood (not verified in a game).
	if t:IsFullyCastable() and HasBlink() and not b:WasRecentlyDamagedByAnyHero(3.0) then
		local a7 = t:GetManaCost()
		if b:GetMana() >= a7 then
			b.shouldBlink = true
			return true
		end
	end
	b.shouldBlink = false
	return false
end
function HasBlink()
	local a8 = nil
	for a9 = 0, 5 do
		local aa = b:GetItemInSlot(a9)
		if
			aa ~= nil
			and (
				aa:GetName() == "item_blink"
				or aa:GetName() == "item_overwhelming_blink"
				or aa:GetName() == "item_arcane_blink"
				or aa:GetName() == "item_swift_blink"
			)
		then
			a8 = aa
			break
		end
	end
	if a8 ~= nil and a8:IsFullyCastable() then
		D = a8
		return true
	end
	return false
end
return a
