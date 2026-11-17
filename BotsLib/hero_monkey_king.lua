-- Monkey King: skill build, item build, and ability use for this hero.
local a = {}
local b = GetBot()
local c = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local d = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local e = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local f = c.Skill.GetTalentList(b)
-- Fixed list by name. GetAbilityList skips only abilities that are both unlearnable and hidden at
-- spawn, so Primal Spring (slot 3) and Mischief (slot 5) could shift Jingu Mastery's index; the
-- old arrays had 16 entries, the ultimate first at level 9 and 5 points in one basic ability.
local g = {
	"monkey_king_boundless_strike",
	"monkey_king_tree_dance",
	"monkey_king_jingu_mastery",
	[6] = "monkey_king_wukongs_command",
}
local h = c.Item.GetRoleItemsBuyList(b)
local i = {
	{ ["t25"] = { 10, 0 }, ["t20"] = { 10, 0 }, ["t15"] = { 0, 10 }, ["t10"] = { 10, 0 } },
	{ ["t25"] = { 10, 0 }, ["t20"] = { 10, 0 }, ["t15"] = { 0, 10 }, ["t10"] = { 10, 0 } },
}
-- User call: one point in each basic ability at levels 1-3, Jingu Mastery maxed, ultimate at
-- 6/12/18, then Boundless Strike, Tree Dance last.
local j = { { 1, 2, 3, 3, 3, 6, 3, 1, 1, 1, 6, 2, 2, 2, 6 }, { 1, 2, 3, 3, 3, 6, 3, 1, 1, 1, 6, 2, 2, 2, 6 } }
local k
local l
if h == "pos_1" then
	k = j[1]
	l = c.Skill.GetTalentBuild(i[1])
else
	k = j[2]
	l = c.Skill.GetTalentBuild(i[2])
end
local m = {}
m["pos_1"] = {
	"item_tango",
	"item_double_branches",
	"item_quelling_blade",
	"item_orb_of_frost",
	"item_boots",
	"item_orb_of_corrosion",
	"item_power_treads",
	"item_magic_wand",
	"item_echo_sabre",
	"item_desolator",
	"item_black_king_bar",
	"item_harpoon",
	"item_basher",
	"item_skadi",
	"item_travel_boots",
	"item_abyssal_blade",
	"item_satanic",
	"item_travel_boots_2",
	"item_ultimate_scepter_2",
	"item_moon_shard",
	"item_aghanims_shard",
}
m["pos_2"] = {
	"item_tango",
	"item_double_branches",
	"item_quelling_blade",
	"item_orb_of_frost",
	"item_power_treads",
	"item_orb_of_corrosion",
	"item_magic_wand",
	"item_echo_sabre",
	"item_desolator",
	"item_black_king_bar",
	"item_harpoon",
	"item_basher",
	"item_skadi",
	"item_travel_boots",
	"item_abyssal_blade",
	"item_satanic",
	"item_travel_boots_2",
	"item_ultimate_scepter_2",
	"item_moon_shard",
	"item_aghanims_shard",
}
m["pos_3"] = m["pos_1"]
m["pos_4"] = m["pos_1"]
m["pos_5"] = m["pos_1"]
a["sBuyList"] = m[h]
a["sSellList"] = { "item_black_king_bar", "item_quelling_blade", "item_satanic", "item_desolator" }
if c.Role.IsPvNMode() or c.Role.IsAllShadow() then
	a["sBuyList"], a["sSellList"] = { "PvN_mid" }, {}
end
k, l, a["sBuyList"], a["sSellList"] = c.SetUserHeroInit(k, l, a["sBuyList"], a["sSellList"])
a["sSkillList"] = c.Skill.GetSkillList(g, k, f, l)
a["bDeafaultAbility"] = false
a["bDeafaultItem"] = false
function a.MinionThink(n)
	e.MinionThink(n)
end
local o = SafeAbility(b:GetAbilityByName("monkey_king_boundless_strike"), "monkey_king_boundless_strike", "monkey_king")
local p = SafeAbility(b:GetAbilityByName("monkey_king_tree_dance"), "monkey_king_tree_dance", "monkey_king")
local q = SafeAbility(b:GetAbilityByName("monkey_king_primal_spring"), "monkey_king_primal_spring", "monkey_king")
local r =
	SafeAbility(b:GetAbilityByName("monkey_king_primal_spring_early"), "monkey_king_primal_spring_early", "monkey_king")
local s = SafeAbility(b:GetAbilityByName("monkey_king_mischief"), "monkey_king_mischief", "monkey_king")
local t = SafeAbility(b:GetAbilityByName("monkey_king_untransform"), "monkey_king_untransform", "monkey_king")
local u = SafeAbility(b:GetAbilityByName("monkey_king_wukongs_command"), "monkey_king_wukongs_command", "monkey_king")
local v = SafeAbility(b:GetAbilityByName("monkey_king_transfiguration"), "monkey_king_transfiguration", "monkey_king")
local w, x
local y, z
local A, B
local C
local D
local E, F
local G, H
local I
local J
local K
local L
local M
local N
local O
-- In-game check: is the Jingu buff seen, and do the counter stacks build on the hero he hits?
local jinguOn, jinguLogTarget, jinguLogStacks = false, nil, 0
local function LogJingu()
	local on = b:HasModifier("modifier_monkey_king_quadruple_tap_bonuses")
	if on ~= jinguOn then
		jinguOn = on
		print(string.format("[OHA-MONKEY_KING] jingu %s charges=%d hp=%.2f", on and "active" or "ended",
			c.GetModifierCount(b, "modifier_monkey_king_quadruple_tap_bonuses"), c.GetHP(b)))
	end
	local tgt = b:GetAttackTarget()
	if c.IsValidHero(tgt) then
		local st = c.GetModifierCount(tgt, "modifier_monkey_king_quadruple_tap_counter")
		if st > 0 and (tgt ~= jinguLogTarget or st ~= jinguLogStacks) then
			jinguLogTarget, jinguLogStacks = tgt, st
			print(string.format("[OHA-MONKEY_KING] jingu counter target=%s stacks=%d", tgt:GetUnitName(), st))
		end
	end
end
function a.SkillsComplement()
	LogJingu()
	if c.CanNotUseAbility(b) then
		return
	end
	J = c.IsGoingOnSomeone(b)
	K = c.IsRetreating(b)
	L = c.IsAttacking(b)
	M = c.GetHP(b)
	N = c.GetMP(b)
	O = c.IsInTeamFight(b, 1200)
	E, F = a.ConsiderWukongsCommand()
	if E > 0 then
		-- Game 036: FPS hitch at 35:29 with no script cause found; log the cast to line it up next time.
		print(string.format("[OHA-MONKEY_KING] wukong cast t=%.0f", DotaTime()))
		b:Action_UseAbilityOnLocation(u, F)
		return
	end
	w, x = a.ConsiderBoundlessStrike()
	if w > 0 then
		b:Action_UseAbilityOnLocation(o, x)
		return
	end
	D = a.ConsiderMischief()
	if D > 0 then
		b:Action_ClearActions(false)
		b:ActionQueue_UseAbility(s)
		if not t:IsHidden() or t:IsFullyCastable() then
			b:ActionQueue_Delay(0.2)
			b:ActionQueue_UseAbility(t)
		end
		return
	end
	y, z = a.ConsiderTreeDance()
	if y > 0 then
		b:Action_UseAbilityOnTree(p, z)
		return
	end
	A, B = a.ConsiderPrimalSpring()
	if A > 0 then
		b:Action_UseAbilityOnLocation(q, B)
		return
	end
	G, H = a.ConsiderChangingOfTheGuard()
	if G > 0 then
		b:Action_UseAbilityOnLocation(v, H)
		return
	end
end
function a.ConsiderBoundlessStrike()
	if not o:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local P = c.GetProperCastRange(false, b, o:GetCastRange())
	local Q = o:GetCastPoint()
	local R = o:GetSpecialValueInt("strike_radius")
	local S = b:GetAttackDamage() * o:GetSpecialValueInt("strike_crit_mult") / 100
	I = c.GetProperTarget(b)
	local T = c.GetNearbyHeroes(b, P, true, BOT_MODE_NONE)
	for U, V in pairs(T) do
		if c.IsValidHero(V) and c.CanCastOnNonMagicImmune(V) and not c.IsSuspiciousIllusion(V) then
			if b:HasModifier("modifier_monkey_king_quadruple_tap_bonuses") and c.GetHP(V) < 0.5 then
				return BOT_ACTION_DESIRE_HIGH, V:GetExtrapolatedLocation(Q)
			end
			if V:IsChanneling() or c.IsCastingUltimateAbility(V) then
				return BOT_ACTION_DESIRE_HIGH, V:GetLocation()
			end
			-- datafeed: Boundless Strike deals physical damage (a crit on his attack), not magical.
			if
				c.CanKillTarget(V, S, DAMAGE_TYPE_PHYSICAL)
				and not V:HasModifier("modifier_abaddon_borrowed_time")
				and not V:HasModifier("modifier_dazzle_shallow_grave")
				and not V:HasModifier("modifier_oracle_false_promise_timer")
				and not V:HasModifier("modifier_templar_assassin_refraction_absorb")
			then
				return BOT_ACTION_DESIRE_HIGH, V:GetExtrapolatedLocation(Q)
			end
		end
	end
	-- Was: two heroes inside a 150 circle AND two enemies within 150 of Monkey King himself, which
	-- almost never holds. The staff stuns along a line (datafeed): strike_radius is the line's
	-- half-width and the cast range its length. Aim at the enemy whose line catches the most heroes.
	if O then
		local me = b:GetLocation()
		local len = o:GetSpecialValueInt("strike_cast_range")
		if len == nil or len <= 0 then
			len = P
		end
		local bestLoc, bestN = nil, 0
		for U, V in pairs(T) do
			if c.IsValidHero(V) and c.CanCastOnNonMagicImmune(V) and not c.IsSuspiciousIllusion(V) then
				local aim = V:GetExtrapolatedLocation(Q)
				local tip = me + (aim - me):Normalized() * len
				local n = 0
				for _, X in pairs(T) do
					if c.IsValidHero(X) and c.CanCastOnNonMagicImmune(X) then
						local hit = PointToLineDistance(me, tip, X:GetExtrapolatedLocation(Q))
						if hit ~= nil and hit.within and hit.distance <= R + 25 then
							n = n + 1
						end
					end
				end
				if n > bestN then
					bestLoc, bestN = aim, n
				end
			end
		end
		if bestLoc ~= nil and bestN >= 2 then
			if DotaTime() >= (b._strikeLineLogAt or -999) then
				b._strikeLineLogAt = DotaTime() + 5
				pcall(print, string.format("[OHA-MONKEY_KING] t=%.0f boundless-strike line heroes=%d", DotaTime(), bestN))
			end
			return BOT_ACTION_DESIRE_HIGH, bestLoc
		end
	end
	if J then
		local Y = c.GetNearbyHeroes(b, 1000, false, BOT_MODE_NONE)
		if
			c.IsValidTarget(I)
			and c.CanCastOnNonMagicImmune(I)
			and c.IsInRange(b, I, P)
			and not c.IsSuspiciousIllusion(I)
			and not c.IsDisabled(I)
			and not I:HasModifier("modifier_dazzle_shallow_grave")
			and not I:HasModifier("modifier_templar_assassin_refraction_absorb")
		then
			local Z = c.GetNearbyHeroes(I, 1000, false, BOT_MODE_NONE)
			if Y ~= nil and Z ~= nil and #Y >= #Z then
				return BOT_ACTION_DESIRE_HIGH, I:GetExtrapolatedLocation(Q)
			end
		end
	end
	if K then
		local Y = c.GetNearbyHeroes(b, 800, false, BOT_MODE_NONE)
		local _ = c.GetNearbyHeroes(b, 800, true, BOT_MODE_NONE)
		if
			Y ~= nil
			and _
			and c.IsValidHero(_[1])
			and c.CanCastOnNonMagicImmune(_[1])
			and c.IsInRange(b, _[1], P)
			and c.IsRunning(_[1])
			and _[1]:IsFacingLocation(b:GetLocation(), 30)
			and not c.IsSuspiciousIllusion(_[1])
		then
			local Z = c.GetNearbyHeroes(_[1], 800, false, BOT_MODE_NONE)
			if Z ~= nil and (#Z > #Y or M < 0.65 and b:WasRecentlyDamagedByAnyHero(2.2)) then
				return BOT_ACTION_DESIRE_HIGH, _[1]:GetExtrapolatedLocation(Q)
			end
		end
	end
	if c.IsPushing(b) or c.IsDefending(b) then
		local W = b:FindAoELocation(true, false, b:GetLocation(), P, R, Q, 0)
		local a0 = b:GetNearbyLaneCreeps(P, true)
		if a0 ~= nil and #a0 >= 4 and W.count >= 4 then
			return BOT_ACTION_DESIRE_HIGH, W.targetloc
		end
		W = b:FindAoELocation(true, true, b:GetLocation(), P, R, Q, 0)
		if W.count >= 1 then
			return BOT_ACTION_DESIRE_HIGH, W.targetloc
		end
	end
	if c.IsFarming(b) then
		local W = b:FindAoELocation(true, false, b:GetLocation(), P, R, Q, 0)
		if L then
			local a1 = b:GetNearbyNeutralCreeps(P)
			if a1 ~= nil and (#a1 >= 3 and W.count >= 3 or #a1 >= 2 and a1[1]:IsAncientCreep() and W.count >= 2) then
				return BOT_ACTION_DESIRE_HIGH, W.targetloc
			end
			local a0 = b:GetNearbyLaneCreeps(P, true)
			if a0 ~= nil and #a0 >= 3 and W.count >= 3 then
				return BOT_ACTION_DESIRE_HIGH, W.targetloc
			end
		end
	end
	if c.IsLaning(b) then
		local a2 = 0
		local a3 = {}
		local a0 = b:GetNearbyLaneCreeps(P, true)
		local _ = c.GetNearbyHeroes(b, P, true, BOT_MODE_NONE)
		for U, a4 in pairs(a0) do
			if c.IsValid(a4) and a4:GetHealth() <= S then
				a2 = a2 + 1
				table.insert(a3, a4)
			end
		end
		if a2 >= 2 and N > 0.25 and _ ~= nil and #_ >= 1 then
			return BOT_ACTION_DESIRE_HIGH, c.GetCenterOfUnits(a3)
		end
	end
	if c.IsDoingRoshan(b) then
		if c.IsRoshan(I) and c.CanCastOnNonMagicImmune(I) and c.IsInRange(b, I, 500) and L then
			return BOT_ACTION_DESIRE_HIGH, I:GetLocation()
		end
	end
	if c.IsDoingTormentor(b) then
		if c.IsTormentor(I) and c.IsInRange(b, I, 400) and L then
			return BOT_ACTION_DESIRE_HIGH, I:GetLocation()
		end
	end
	local a5 = c.GetNearbyHeroes(b, P, false, BOT_MODE_NONE)
	for U, a6 in pairs(a5) do
		local a7 = c.GetNearbyHeroes(a6, P, true, BOT_MODE_NONE)
		if c.IsRetreating(a6) and a6:WasRecentlyDamagedByAnyHero(2.1) and not a6:IsIllusion() and N > 0.59 then
			if
				a7 ~= nil
				and #a7 >= 1
				and c.IsValidHero(a7[1])
				and c.CanCastOnNonMagicImmune(a7[1])
				and c.IsInRange(a6, a7[1], 400)
				and c.IsInRange(b, a7[1], P)
				and c.IsRunning(a6)
				and a7[1]:IsFacingLocation(a6:GetLocation(), 30)
				and not c.IsDisabled(a7[1])
				and not c.IsTaunted(a7[1])
				and not c.IsSuspiciousIllusion(a7[1])
				and not a7[1]:HasModifier("modifier_enigma_black_hole_pull")
				and not a7[1]:HasModifier("modifier_faceless_void_chronosphere_freeze")
			then
				return BOT_ACTION_DESIRE_HIGH, a7[1]:GetExtrapolatedLocation(Q)
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function a.ConsiderTreeDance()
	if not p:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local P = p:GetCastRange()
	I = c.GetProperTarget(b)
	local T = c.GetNearbyHeroes(b, 1200, true, BOT_MODE_NONE)
	if T == nil then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	-- Was "J and q:IsFullyCastable()": Primal Spring is only gained while perched (datafeed), so
	-- from the ground this either never held, or (perched) it held again and Tree Dance (cooldown
	-- 0.9 to 0, checked before Spring) hopped to the next tree instead of springing. Now: Spring
	-- trained, off cooldown and affordable; no new hop for 3s after one, so Spring gets its turn;
	-- and the tree must be within Spring's range of the target (it was just the first tree found).
	local springReady = q:IsTrained() and q:GetCooldownTimeRemaining() <= 0 and b:GetMana() >= q:GetManaCost()
	if J and springReady and DotaTime() - (b._mkTreeDanceAt or -999) > 3 then
		local Y = c.GetNearbyHeroes(b, 1000, false, BOT_MODE_NONE)
		if
			c.IsValidTarget(I)
			and c.CanCastOnNonMagicImmune(I)
			and c.IsInRange(b, I, P)
			and not c.IsSuspiciousIllusion(I)
			and not I:HasModifier("modifier_dazzle_shallow_grave")
			and not I:HasModifier("modifier_templar_assassin_refraction_absorb")
		then
			local a8 = b:GetNearbyTrees(P)
			local Z = c.GetNearbyHeroes(I, 1000, false, BOT_MODE_NONE)
			local springRange = q:GetCastRange()
			if springRange == nil or springRange <= 0 then
				springRange = 800
			end
			local tree, treeDist = nil, math.huge
			for U, an in pairs(a8 or {}) do
				local tl = GetTreeLocation(an)
				local d0 = GetUnitToLocationDistance(I, tl)
				if d0 <= springRange - 100 and d0 < treeDist and (IsLocationVisible(tl) or IsLocationPassable(tl)) then
					tree, treeDist = an, d0
				end
			end
			if Y ~= nil and Z ~= nil and #Y >= #Z and tree ~= nil then
				b._mkTreeDanceAt = DotaTime()
				pcall(print, string.format(
					"[OHA-MONKEY_KING] t=%.0f tree-dance engage target=%s tree-to-target=%d",
					DotaTime(),
					(string.gsub(I:GetUnitName(), "npc_dota_hero_", "")),
					math.floor(treeDist)
				))
				return BOT_ACTION_DESIRE_HIGH, tree
			end
		end
	end
	if K then
		local Y = c.GetNearbyHeroes(b, 800, false, BOT_MODE_NONE)
		local _ = c.GetNearbyHeroes(b, 800, true, BOT_MODE_NONE)
		if
			Y ~= nil
			and _
			and c.IsValidHero(_[1])
			and c.CanCastOnNonMagicImmune(_[1])
			and c.IsInRange(b, _[1], P)
			and c.IsRunning(_[1])
			and _[1]:IsFacingLocation(b:GetLocation(), 30)
			and not c.IsSuspiciousIllusion(_[1])
		then
			local Z = c.GetNearbyHeroes(_[1], 800, false, BOT_MODE_NONE)
			if
				Z ~= nil
				and (#Z > #Y or M < 0.65 and b:WasRecentlyDamagedByAnyHero(2.2))
				and b:DistanceFromFountain() > 1000
			then
				local a8 = b:GetNearbyTrees(P)
				local a9 = GetFurthestTree(a8)
				if
					a9 ~= nil and (IsLocationVisible(GetTreeLocation(a9)) or IsLocationPassable(GetTreeLocation(a9)))
				then
					return BOT_ACTION_DESIRE_HIGH, a9
				end
			end
		end
	end
	if c.IsFarming(b) and N > 0.35 then
		local a1 = b:GetNearbyNeutralCreeps(P)
		if a1 ~= nil and (#a1 >= 3 or #a1 >= 2 and a1[1]:IsAncientCreep()) then
			local a8 = a1[1]:GetNearbyTrees(P)
			if
				a8 ~= nil
				and #a8 >= 1
				and (IsLocationVisible(GetTreeLocation(a8[1])) or IsLocationPassable(GetTreeLocation(a8[1])))
			then
				return BOT_ACTION_DESIRE_HIGH, a8[1]
			end
		end
		local a0 = b:GetNearbyLaneCreeps(P, true)
		if a0 ~= nil and #a0 >= 3 then
			local a8 = a0[1]:GetNearbyTrees(P)
			if
				a8 ~= nil
				and #a8 >= 1
				and (IsLocationVisible(GetTreeLocation(a8[1])) or IsLocationPassable(GetTreeLocation(a8[1])))
			then
				return BOT_ACTION_DESIRE_HIGH, a8[1]
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function a.ConsiderPrimalSpring()
	if q:IsHidden() or not q:IsFullyCastable() or not q:IsActivated() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	-- Primal Spring has no "max_distance" value (game KV: only impact_damage/slow/radius; the leap
	-- range is its AbilityCastRange, 800), so the old lookup read 0 and the spring never aimed anywhere.
	local aa = q:GetCastRange()
	local ab = q:GetChannelTime()
	local R = q:GetSpecialValueInt("impact_radius")
	if O then
		local W = b:FindAoELocation(true, true, b:GetLocation(), aa, R, ab, 0)
		if W.count >= 2 then
			-- Was enemies within impact_radius of Monkey King himself, not of the landing spot (up to
			-- 800 away), so a group out there never counted.
			local X = c.GetEnemiesNearLoc(W.targetloc, R)
			if X ~= nil and #X >= 2 then
				return BOT_ACTION_DESIRE_HIGH, W.targetloc
			end
		end
	end
	if J then
		local Y = c.GetNearbyHeroes(b, 1000, false, BOT_MODE_NONE)
		local ac = c.GetAttackableWeakestUnit(b, aa, true, true)
		if
			c.IsValidTarget(ac)
			and not c.IsSuspiciousIllusion(ac)
			and not ac:HasModifier("modifier_abaddon_borrowed_time")
			and not ac:HasModifier("modifier_dazzle_shallow_grave")
			and not ac:HasModifier("modifier_templar_assassin_refraction_absorb")
			and not c.IsLocationInChrono(ac:GetLocation())
			and not c.IsLocationInBlackHole(ac:GetLocation())
		then
			local Z = c.GetNearbyHeroes(ac, 1000, false, BOT_MODE_NONE)
			if Y ~= nil and Z ~= nil and #Y >= #Z then
				return BOT_ACTION_DESIRE_HIGH, ac:GetExtrapolatedLocation(ab)
			end
		end
	end
	if K then
		local Y = c.GetNearbyHeroes(b, 800, false, BOT_MODE_NONE)
		local _ = c.GetNearbyHeroes(b, 800, true, BOT_MODE_NONE)
		if
			Y ~= nil
			and _
			and c.IsValidHero(_[1])
			and c.CanCastOnNonMagicImmune(_[1])
			and c.IsInRange(b, _[1], aa)
			and c.IsRunning(_[1])
			and _[1]:IsFacingLocation(b:GetLocation(), 30)
			and not c.IsSuspiciousIllusion(_[1])
		then
			local Z = c.GetNearbyHeroes(_[1], 800, false, BOT_MODE_NONE)
			if Z ~= nil and (#Z > #Y or M < 0.71 and b:WasRecentlyDamagedByAnyHero(2.2)) then
				local ad = c.GetEscapeLoc()
				return BOT_ACTION_DESIRE_MODERATE, c.Site.GetXUnitsTowardsLocation(b, ad, aa)
			end
		end
	end
	if c.IsPushing(b) or c.IsDefending(b) then
		local _ = c.GetNearbyHeroes(b, 1000, true, BOT_MODE_NONE)
		local W = b:FindAoELocation(true, false, b:GetLocation(), aa, R, ab, 0)
		local a0 = b:GetNearbyLaneCreeps(aa, true)
		if a0 ~= nil and #a0 >= 4 and W.count >= 4 and _ ~= nil and #_ == 0 then
			return BOT_ACTION_DESIRE_HIGH, W.targetloc
		end
	end
	if c.IsFarming(b) and N > 0.35 then
		local W = b:FindAoELocation(true, false, b:GetLocation(), aa, R, ab, 0)
		local a1 = b:GetNearbyNeutralCreeps(aa)
		if a1 ~= nil and (#a1 >= 3 and W.count >= 3 or #a1 >= 2 and a1[1]:IsAncientCreep() and W.count >= 2) then
			return BOT_ACTION_DESIRE_HIGH, W.targetloc
		end
		local a0 = b:GetNearbyLaneCreeps(aa, true)
		if a0 ~= nil and #a0 >= 3 and W.count >= 3 then
			return BOT_ACTION_DESIRE_HIGH, W.targetloc
		end
	end
	if c.IsLaning(b) then
		local W = b:FindAoELocation(true, false, b:GetLocation(), aa, R, ab, 0)
		local a0 = b:GetNearbyLaneCreeps(aa, true)
		if a0 ~= nil and #a0 >= 2 and W.count >= 2 then
			return BOT_ACTION_DESIRE_HIGH, W.targetloc
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function a.ConsiderMischief()
	if not s:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
	end
	if c.IsStunProjectileIncoming(b, 600) then
		return BOT_ACTION_DESIRE_HIGH
	end
	return BOT_ACTION_DESIRE_NONE
end
function a.ConsiderWukongsCommand()
	if not u:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local P = u:GetSpecialValueInt("cast_range")
	local R = u:GetSpecialValueInt("second_radius")
	I = c.GetProperTarget(b)
	if O then
		local W = b:FindAoELocation(true, true, b:GetLocation(), P, R / 2, 1, 0)
		if W.count >= 2 then
			local X = c.GetEnemiesNearLoc(b:GetLocation(), R)
			if
				X ~= nil
				and #X >= 2
				and not c.IsLocationInChrono(W.targetloc)
				and not c.IsLocationInBlackHole(W.targetloc)
			then
				return BOT_ACTION_DESIRE_HIGH, W.targetloc
			end
		end
	end
	if J then
		local Y = c.GetNearbyHeroes(b, 1000, false, BOT_MODE_NONE)
		if
			c.IsValidTarget(I)
			and c.CanCastOnNonMagicImmune(I)
			and c.IsInRange(b, I, P)
			and not c.IsSuspiciousIllusion(I)
			and not I:HasModifier("modifier_dazzle_shallow_grave")
			and not I:HasModifier("modifier_templar_assassin_refraction_absorb")
			and not c.IsLocationInChrono(I:GetLocation())
			and not c.IsLocationInBlackHole(I:GetLocation())
		then
			local Z = c.GetNearbyHeroes(I, 1000, false, BOT_MODE_NONE)
			if Y ~= nil and Z ~= nil and #Y >= #Z then
				return BOT_ACTION_DESIRE_HIGH, I:GetExtrapolatedLocation(1)
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function GetFurthestTree(a8)
	if GetAncient(GetTeam()) == nil then
		return nil
	end
	local a9 = nil
	local ae = 10000
	for U, af in pairs(a8) do
		local ag = GetUnitToLocationDistance(GetAncient(GetTeam()), GetTreeLocation(af))
		if ag < ae then
			a9 = af
			ae = ag
		end
	end
	return a9
end
function a.ConsiderChangingOfTheGuard()
	if not c.CanCastAbility(v) or b:IsRooted() then
		return BOT_ACTION_DESIRE_NONE
	end
	if b:HasModifier("modifier_monkey_king_fur_army_bonus_damage") then
		local T = c.GetNearbyHeroes(b, 1600, true, BOT_MODE_NONE)
		local a5 = c.GetNearbyHeroes(b, 1600, false, BOT_MODE_NONE)
		if
			c.IsStunProjectileIncoming(b, 550) and #T > #a5
			or c.GetAttackProjectileDamageByRange(b, 900) > b:GetHealth()
		then
			return BOT_ACTION_DESIRE_HIGH, b:GetLocation()
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
return a
