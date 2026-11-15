-- Disruptor: skill build, item build, and ability use for this hero.
local a = {}
local b = GetBot()
local c = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local d = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local e = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local f = c.Skill.GetTalentList(b)
local g = c.Skill.GetAbilityList(b)
local h = c.Item.GetRoleItemsBuyList(b)
local i = { ["t25"] = { 10, 0 }, ["t20"] = { 0, 10 }, ["t15"] = { 10, 0 }, ["t10"] = { 0, 10 } }
-- 1 Thunder Strike, 2 Glimpse, 3 Kinetic Field, 6 Static Storm (ultimate at 6, 12, 18).
-- Support: one point in each, then Glimpse, then Kinetic Field, Thunder Strike last.
-- Core: Thunder Strike first, then Glimpse, Kinetic Field last.
local j = { { 1, 2, 3, 2, 2, 6, 2, 3, 3, 3, 6, 1, 1, 1, 6 } }
if h ~= "pos_4" and h ~= "pos_5" then
	j = { { 1, 2, 1, 3, 1, 6, 1, 2, 2, 2, 6, 3, 3, 3, 6 } }
end
local k = c.Skill.GetRandomBuild(j)
local l = c.Skill.GetTalentBuild(i)
local m = {}
m["pos_4"] = {
	"item_double_tango",
	"item_double_branches",
	"item_faerie_fire",
	"item_blood_grenade",
	"item_magic_wand",
	"item_arcane_boots",
	"item_glimmer_cape",
	"item_force_staff",
	"item_guardian_greaves",
	"item_hurricane_pike",
	"item_sheepstick",
	"item_shivas_guard",
	"item_wind_waker",
	"item_aghanims_shard",
	"item_moon_shard",
	"item_ultimate_scepter_2",
}
m["pos_5"] = {
	"item_double_tango",
	"item_double_branches",
	"item_faerie_fire",
	"item_blood_grenade",
	"item_magic_wand",
	"item_tranquil_boots",
	"item_glimmer_cape",
	"item_force_staff",
	"item_pipe",
	"item_aether_lens",
	"item_boots_of_bearing",
	"item_hurricane_pike",
	"item_sheepstick",
	"item_aghanims_shard",
	"item_moon_shard",
	"item_ultimate_scepter_2",
}
m["pos_3"] = {
	"item_double_tango",
	"item_double_branches",
	"item_faerie_fire",
	"item_magic_wand",
	"item_arcane_boots",
	"item_glimmer_cape",
	"item_force_staff",
	"item_maelstrom",
	"item_gungir",
	"item_shivas_guard",
	"item_hurricane_pike",
	"item_sheepstick",
	"item_wind_waker",
	"item_aghanims_shard",
	"item_moon_shard",
	"item_ultimate_scepter_2",
}
m["pos_1"] = m["pos_3"]
m["pos_2"] = m["pos_3"]
a["sBuyList"] = m[h]
a["sSellList"] = { "item_ultimate_scepter", "item_magic_wand", "item_cyclone", "item_magic_wand" }
if c.Role.IsPvNMode() or c.Role.IsAllShadow() then
	a["sBuyList"], a["sSellList"] = { "PvN_antimage" }, {}
end
k, l, a["sBuyList"], a["sSellList"] = c.SetUserHeroInit(k, l, a["sBuyList"], a["sSellList"])
a["sSkillList"] = c.Skill.GetSkillList(g, k, f, l)
a["bDeafaultAbility"] = false
a["bDeafaultItem"] = false
function a.MinionThink(n)
	e.MinionThink(n)
end
local o = SafeAbility(b:GetAbilityByName("disruptor_thunder_strike"), "disruptor_thunder_strike", "disruptor")
local p = SafeAbility(b:GetAbilityByName("disruptor_glimpse"), "disruptor_glimpse", "disruptor")
local q = SafeAbility(b:GetAbilityByName("disruptor_kinetic_field"), "disruptor_kinetic_field", "disruptor")
local r = SafeAbility(b:GetAbilityByName("disruptor_kinetic_fence"), "disruptor_kinetic_fence", "disruptor")
local s = SafeAbility(b:GetAbilityByName("disruptor_static_storm"), "disruptor_static_storm", "disruptor")
local t, u
local v, w
local x, y
local z, A
local B, C
local D = 0
local E, F
local G
local H
local I
local J
local K
-- Where each enemy hero was over the last few seconds, for the Glimpse return spot (Glimpse
-- sends the target back to where it was 4s ago, Valve data). Sampled every 0.2s.
local trail = {}
local trailAt = -99
local function RecordTrail()
	local now = DotaTime()
	if now - trailAt < 0.2 then
		return
	end
	trailAt = now
	for _, e0 in pairs(GetUnitList(UNIT_LIST_ENEMY_HEROES) or {}) do
		if c.IsValidHero(e0) and e0:CanBeSeen() and not e0:IsIllusion() then
			local id = e0:GetPlayerID()
			local list = trail[id] or {}
			list[#list + 1] = { t = now, loc = e0:GetLocation() }
			while #list > 0 and now - list[1].t > 6 do
				table.remove(list, 1)
			end
			trail[id] = list
		end
	end
end
-- Where target would land if Glimpsed now, or nil when it was not seen at that moment.
function a.GlimpseReturnSpot(target)
	local back = p:GetSpecialValueFloat("backtrack_time")
	if back == nil or back <= 0 then
		back = 4
	end
	local want = DotaTime() - back
	local best, bestGap = nil, 0.35
	for _, e0 in ipairs(trail[target:GetPlayerID()] or {}) do
		local gap = math.abs(e0.t - want)
		if gap < bestGap then
			best, bestGap = e0.loc, gap
		end
	end
	return best
end
-- Glimpse -> Kinetic Field on the return spot -> Static Storm there when 2+ enemy heroes will be
-- in it or it is a team fight. The field forms in 1s, so it is up when the target lands.
function a.ConsiderGlimpseCombo()
	if not (H or K) or not p:IsFullyCastable() or not q:IsFullyCastable() then
		return nil
	end
	local mana = b:GetMana() - p:GetManaCost() - q:GetManaCost()
	if mana < 0 then
		return nil
	end
	local range = c.GetProperCastRange(false, b, p:GetCastRange())
	local fieldRange = q:GetCastRange() + 100
	local candidates = {}
	if c.IsValidHero(G) then
		candidates[1] = G
	end
	for _, e0 in pairs(c.GetNearbyHeroes(b, range, true, BOT_MODE_NONE) or {}) do
		candidates[#candidates + 1] = e0
	end
	for _, T in ipairs(candidates) do
		if
			c.IsValidHero(T)
			and c.IsInRange(b, T, range)
			and c.CanCastOnNonMagicImmune(T)
			and c.CanCastOnTargetAdvanced(T)
			and not c.IsSuspiciousIllusion(T)
			and not c.IsDisabled(T)
			and not T:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			local spot = a.GlimpseReturnSpot(T)
			if
				spot ~= nil
				and GetUnitToLocationDistance(T, spot) >= 350
				and GetUnitToLocationDistance(b, spot) <= fieldRange
			then
				local allies = #(c.GetNearbyHeroes(b, 1600, false, BOT_MODE_NONE) or {})
				local foes = #(c.GetNearbyHeroes(T, 1200, false, BOT_MODE_NONE) or {})
				if allies >= foes - 1 then
					local storm = false
					if s:IsTrained() and s:IsFullyCastable() and mana >= s:GetManaCost() then
						local inStorm = #(c.GetEnemiesNearLoc(spot, s:GetSpecialValueInt("radius")) or {}) + 1
						storm = inStorm >= 2 or K
					end
					return T, spot, storm
				end
			end
		end
	end
	return nil
end
function a.SkillsComplement()
	RecordTrail()
	if c.CanNotUseAbility(b) then
		return
	end
	local L = d.Build(b)
	H = L.isEngaging
	I = L.isRetreating
	J = c.IsAttacking(b)
	K = L.isTeamFight
	G = L.target
	-- An enemy teleporting within Glimpse range: Glimpse it first. It sat last in the order,
	-- behind the storms, the fields and Thunder Strike (game 016, 62:00: no Glimpse on a TP).
	if p:IsFullyCastable() then
		local range = c.GetProperCastRange(false, b, p:GetCastRange())
		for _, T in pairs(c.GetNearbyHeroes(b, range, true, BOT_MODE_NONE) or {}) do
			if
				c.IsValidHero(T)
				and T:HasModifier("modifier_teleporting")
				and c.CanCastOnNonMagicImmune(T)
				and c.CanCastOnTargetAdvanced(T)
				and not c.IsSuspiciousIllusion(T)
			then
				pcall(print, string.format(
					"[OHA-DISRUPTOR] t=%.0f glimpse-tp target=%s dist=%d",
					DotaTime(),
					(string.gsub(T:GetUnitName(), "npc_dota_hero_", "")),
					GetUnitToUnitDistance(b, T)
				))
				b:Action_UseAbilityOnEntity(p, T)
				return
			end
		end
	end
	local comboTarget, comboSpot, comboStorm = a.ConsiderGlimpseCombo()
	if comboTarget ~= nil then
		pcall(print, string.format(
			"[OHA-DISRUPTOR] t=%.0f glimpse-combo target=%s back=%d storm=%s",
			DotaTime(),
			(string.gsub(comboTarget:GetUnitName(), "npc_dota_hero_", "")),
			GetUnitToLocationDistance(comboTarget, comboSpot),
			tostring(comboStorm)
		))
		b:Action_ClearActions(false)
		b:ActionQueue_UseAbilityOnEntity(p, comboTarget)
		b:ActionQueue_Delay(0.1)
		b:ActionQueue_UseAbilityOnLocation(q, comboSpot)
		if comboStorm then
			b:ActionQueue_Delay(0.1)
			b:ActionQueue_UseAbilityOnLocation(s, comboSpot)
		end
		return
	end
	E, F = a.ConsiderKineticStorm()
	if E > 0 then
		b:Action_ClearActions(false)
		b:ActionQueue_UseAbilityOnLocation(s, F)
		b:ActionQueue_Delay(0.05)
		b:ActionQueue_UseAbilityOnLocation(q, F)
		b:ActionQueue_Delay(0.05)
		return
	end
	B, C = a.ConsiderStaticStorm()
	if B > 0 then
		b:Action_UseAbilityOnLocation(s, C)
		return
	end
	x, y = a.ConsiderKineticField()
	if x > 0 then
		b:Action_UseAbilityOnLocation(q, y)
		return
	end
	z, A = a.ConsiderKineticFence()
	if z > 0 then
		b:Action_UseAbilityOnLocation(r, A)
		D = DotaTime()
		return
	end
	t, u = a.ConsiderThunderStrike()
	if t > 0 then
		b:Action_UseAbilityOnEntity(o, u)
		return
	end
	v, w = a.ConsiderGlimpse()
	if v > 0 then
		b:Action_UseAbilityOnEntity(p, w)
		return
	end
end
function a.ConsiderThunderStrike()
	if not o:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local M = c.GetProperCastRange(false, b, o:GetCastRange())
	local N = o:GetSpecialValueInt("radius")
	local O = o:GetSpecialValueInt("strike_damage")
	local P = o:GetSpecialValueInt("strikes")
	local Q = c.GetNearbyHeroes(b, M, true, BOT_MODE_NONE)
	for R, S in pairs(Q) do
		if
			c.IsValidTarget(S)
			and c.CanCastOnNonMagicImmune(S)
			and c.CanCastOnTargetAdvanced(S)
			and c.CanKillTarget(S, O * P, DAMAGE_TYPE_MAGICAL)
			and not c.IsSuspiciousIllusion(S)
			and not S:HasModifier("modifier_abaddon_borrowed_time")
			and not S:HasModifier("modifier_dazzle_shallow_grave")
			and not S:HasModifier("modifier_necrolyte_reapers_scythe")
			and not S:HasModifier("modifier_oracle_false_promise_timer")
			and not S:HasModifier("modifier_skeleton_king_reincarnation_scepter_active")
			and not S:HasModifier("modifier_templar_assassin_refraction_absorb")
		then
			return BOT_ACTION_DESIRE_HIGH, S
		end
	end
	local T = c.GetNearbyHeroes(b, M, false, BOT_MODE_NONE)
	for R, U in pairs(T) do
		local V = c.GetNearbyHeroes(U, 1200, true, BOT_MODE_NONE)
		if
			c.IsValidHero(U)
			and c.IsRetreating(U)
			and c.IsCore(U)
			and U:WasRecentlyDamagedByAnyHero(2)
			and U:GetActiveModeDesire() >= 0.5
			and not U:IsIllusion()
			and not p:IsFullyCastable()
		then
			if
				V ~= nil
				and #V >= 1
				and c.IsValidHero(V[1])
				and c.CanCastOnNonMagicImmune(V[1])
				and c.CanCastOnTargetAdvanced(V[1])
				and c.IsInRange(b, V[1], M)
				and c.IsChasingTarget(V[1], U)
				and not c.IsChasingTarget(V[1], b)
				and not c.IsDisabled(V[1])
				and not c.IsTaunted(V[1])
				and not c.IsSuspiciousIllusion(V[1])
				and not V[1]:HasModifier("modifier_necrolyte_reapers_scythe")
			then
				return BOT_ACTION_DESIRE_HIGH, V[1]
			end
		end
	end
	if H then
		if
			c.IsValidTarget(G)
			and c.CanCastOnNonMagicImmune(G)
			and c.CanCastOnTargetAdvanced(G)
			and c.IsInRange(b, G, M + 300)
			and not c.IsSuspiciousIllusion(G)
			and not G:HasModifier("modifier_skeleton_king_reincarnation_scepter_active")
		then
			local W = c.GetNearbyHeroes(G, 1200, true, BOT_MODE_NONE)
			local X = c.GetNearbyHeroes(G, 1200, false, BOT_MODE_NONE)
			if W ~= nil and X ~= nil and #W >= #X then
				return BOT_ACTION_DESIRE_HIGH, G
			end
		end
	end
	if I and b:GetActiveModeDesire() > 0.5 then
		local X = c.GetNearbyHeroes(b, M, true, BOT_MODE_NONE)
		for R, S in pairs(X) do
			if
				c.IsValidHero(S)
				and c.CanCastOnNonMagicImmune(S)
				and c.CanCastOnTargetAdvanced(S)
				and c.IsChasingTarget(S, b)
				and not c.IsSuspiciousIllusion(S)
				and not c.IsDisabled(S)
				and not S:HasModifier("modifier_necrolyte_reapers_scythe")
			then
				local W = c.GetNearbyHeroes(S, 1200, true, BOT_MODE_NONE)
				local Y = c.GetNearbyHeroes(S, 1200, false, BOT_MODE_NONE)
				if W ~= nil and Y ~= nil and (#Y > #W or b:WasRecentlyDamagedByAnyHero(2)) then
					return BOT_ACTION_DESIRE_HIGH, S
				end
			end
		end
	end
	if c.IsPushing(b) or c.IsDefending(b) then
		local X = c.GetEnemiesNearLoc(b:GetLocation(), 1600)
		local Z = b:GetNearbyLaneCreeps(M, true)
		if Z ~= nil and #Z >= 3 and X ~= nil and #X == 0 then
			for R, _ in pairs(Z) do
				if c.IsValid(_) and c.CanBeAttacked(_) then
					local a0 = c.GetNearbyAroundLocationUnitCount(true, false, N, _:GetLocation())
					if a0 >= 3 then
						return BOT_ACTION_DESIRE_HIGH, _
					end
				end
			end
		end
	end
	if c.IsDoingRoshan(b) then
		if c.IsRoshan(G) and c.IsInRange(b, G, M) and J then
			return BOT_ACTION_DESIRE_HIGH, G
		end
	end
	if c.IsDoingTormentor(b) then
		if c.IsTormentor(G) and c.IsInRange(b, G, M) and J then
			return BOT_ACTION_DESIRE_HIGH, G
		end
	end
	if c.IsDoingTormentor(b) then
		if c.IsTormentor(G) and c.IsInRange(b, G, M) and J then
			return BOT_ACTION_DESIRE_HIGH, G
		end
	end
	local a1 = b:GetNearbyNeutralCreeps(M)
	for R, _ in pairs(a1) do
		if c.IsValid(_) and c.CanBeAttacked(_) and _:GetHealth() > O * P / 2 and _:GetHealth() <= O * P then
			return BOT_ACTION_DESIRE_HIGH, _
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function a.ConsiderGlimpse()
	if not p:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	-- A fleeing enemy: pull it back to where it was 4s ago when that spot is well behind it and
	-- closer to us. The old chase rule also needed the target to be teleporting or in its fountain,
	-- so a running enemy was never glimpsed.
	if H or K then
		local range = c.GetProperCastRange(false, b, p:GetCastRange())
		for _, T in pairs(c.GetNearbyHeroes(b, range, true, BOT_MODE_NONE) or {}) do
			if
				c.IsValidHero(T)
				and c.CanCastOnNonMagicImmune(T)
				and c.CanCastOnTargetAdvanced(T)
				and not c.IsSuspiciousIllusion(T)
				and not c.IsDisabled(T)
				and not T:IsFacingLocation(b:GetLocation(), 90)
			then
				local spot = a.GlimpseReturnSpot(T)
				if
					spot ~= nil
					and GetUnitToLocationDistance(T, spot) >= 400
					and GetUnitToLocationDistance(b, spot) + 300 < GetUnitToUnitDistance(b, T)
				then
					pcall(print, string.format(
						"[OHA-DISRUPTOR] t=%.0f glimpse-flee target=%s back=%d",
						DotaTime(),
						(string.gsub(T:GetUnitName(), "npc_dota_hero_", "")),
						GetUnitToLocationDistance(T, spot)
					))
					return BOT_ACTION_DESIRE_HIGH, T
				end
			end
		end
	end
	local M = c.GetProperCastRange(false, b, p:GetCastRange())
	local T = c.GetNearbyHeroes(b, M, false, BOT_MODE_NONE)
	local Q = c.GetNearbyHeroes(b, M, true, BOT_MODE_NONE)
	for R, S in pairs(Q) do
		if
			c.IsValidHero(S)
			and c.CanCastOnNonMagicImmune(S)
			and c.CanCastOnTargetAdvanced(S)
			and (S:IsChanneling() or b:GetActiveMode() == BOT_MODE_ATTACK and (T ~= nil and #T <= 3 and #Q <= 2) and b:IsFacingLocation(
				S:GetLocation(),
				30
			) and S:IsFacingLocation(c.GetEnemyFountain(), 30))
			and c.CanCastOnNonMagicImmune(S)
			and not c.IsSuspiciousIllusion(S)
		then
			if S:HasModifier("modifier_teleporting") or S:HasModifier("modifier_fountain_aura_buff") then
				return BOT_ACTION_DESIRE_HIGH, S
			end
			if H then
				local W = c.GetNearbyHeroes(S, 1200, false, BOT_MODE_NONE)
				if
					c.IsChasingTarget(b, S)
					and S:GetCurrentMovementSpeed() > b:GetCurrentMovementSpeed()
					and W ~= nil
					and #W >= #Q
				then
					return BOT_ACTION_DESIRE_HIGH, S
				end
			end
		end
	end
	if I and b:GetActiveModeDesire() >= 0.75 then
		local X = c.GetNearbyHeroes(b, M, true, BOT_MODE_NONE)
		for R, S in pairs(X) do
			if
				c.IsValidHero(S)
				and c.CanCastOnNonMagicImmune(S)
				and c.CanCastOnTargetAdvanced(S)
				and c.IsChasingTarget(S, b)
				and not c.IsSuspiciousIllusion(S)
				and not c.IsDisabled(S)
				and not c.IsRealInvisible(b)
				and not S:HasModifier("modifier_necrolyte_reapers_scythe")
			then
				local W = c.GetNearbyHeroes(S, 1200, true, BOT_MODE_NONE)
				local Y = c.GetNearbyHeroes(S, 1200, false, BOT_MODE_NONE)
				if W ~= nil and Y ~= nil and (#Y > #W or b:WasRecentlyDamagedByAnyHero(2)) then
					return BOT_ACTION_DESIRE_HIGH, S
				end
			end
		end
	end
	for R, U in pairs(T) do
		local V = c.GetNearbyHeroes(U, 1200, true, BOT_MODE_NONE)
		if
			c.IsValidHero(U)
			and c.IsRetreating(U)
			and c.IsCore(U)
			and U:GetActiveModeDesire() >= 0.75
			and U:WasRecentlyDamagedByAnyHero(2)
			and not U:IsIllusion()
		then
			if
				V ~= nil
				and #V >= 1
				and c.IsValidHero(V[1])
				and c.CanCastOnNonMagicImmune(V[1])
				and c.CanCastOnTargetAdvanced(V[1])
				and c.IsInRange(b, V[1], M)
				and c.IsChasingTarget(V[1], U)
				and not c.IsChasingTarget(V[1], b)
				and not c.IsDisabled(V[1])
				and not c.IsTaunted(V[1])
				and not c.IsSuspiciousIllusion(V[1])
				and not V[1]:HasModifier("modifier_necrolyte_reapers_scythe")
			then
				return BOT_ACTION_DESIRE_HIGH, V[1]
			end
		end
	end
	local a2 = 0
	local a3 = 0
	local a4 = nil
	for R, S in pairs(Q) do
		if
			c.IsValidHero(S)
			and c.CanCastOnNonMagicImmune(S)
			and c.CanCastOnTargetAdvanced(S)
			and not c.IsSuspiciousIllusion(S)
			and p:GetLevel() >= 3
		then
			if c.IsSuspiciousIllusion(S) then
				a3 = a3 + 1
				a4 = S
			else
				a2 = a2 + 1
			end
		end
	end
	if a2 == 0 and a3 >= 1 then
		return BOT_ACTION_DESIRE_HIGH, a4
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function a.ConsiderKineticFence()
	if not c.CanCastAbility(r) then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local a5 = r:GetSpecialValueInt("duration")
	if not c.CanCastAbility(r) or DotaTime() < D + a5 then
		return BOT_ACTION_DESIRE_NONE
	end
	local M = c.GetProperCastRange(false, b, r:GetCastRange())
	local a6 = r:GetCastPoint()
	local N = r:GetSpecialValueInt("radius")
	local a7 = r:GetSpecialValueInt("formation_time")
	local Q = b:GetNearbyHeroes(1600, true, BOT_MODE_NONE)
	if K then
		local a8 = b:FindAoELocation(true, true, b:GetLocation(), M, N, a6 + a7, 0)
		local X = c.GetEnemiesNearLoc(a8.targetloc, N)
		if #X >= 2 then
			return BOT_ACTION_DESIRE_HIGH, a8.targetloc
		end
	end
	if H then
		if
			c.IsValidTarget(G)
			and c.CanCastOnNonMagicImmune(G)
			and c.IsInRange(b, G, M)
			and not G:HasModifier("modifier_enigma_black_hole_pull")
			and not G:HasModifier("modifier_faceless_void_chronosphere_freeze")
			and not G:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			local a8 = b:FindAoELocation(true, true, G:GetLocation(), 0, N, a6, 0)
			local a9 = a8.targetloc
			local aa = c.GetCorrectLoc(G, a7)
			if #Q <= 1 then
				if c.IsChasingTarget(b, G) then
					if a8.count >= 2 then
						return BOT_ACTION_DESIRE_HIGH, a9
					else
						return BOT_ACTION_DESIRE_HIGH, aa
					end
				end
			else
				if a8.count >= 2 then
					return BOT_ACTION_DESIRE_HIGH, a9
				else
					return BOT_ACTION_DESIRE_HIGH, aa
				end
			end
		end
	end
	if I and not c.IsRealInvisible(b) and b:GetActiveModeDesire() > 0.9 then
		for R, S in pairs(Q) do
			if
				c.IsValidHero(S)
				and c.CanCastOnNonMagicImmune(S)
				and c.IsInRange(b, S, M)
				and c.IsChasingTarget(S, b)
				and not c.IsDisabled(S)
				and not S:HasModifier("modifier_necrolyte_reapers_scythe")
			then
				return BOT_ACTION_DESIRE_HIGH, (b:GetLocation() + c.GetCorrectLoc(S, a7)) / 2
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function a.ConsiderKineticField()
	if not c.CanCastAbility(q) then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local M = c.GetProperCastRange(false, b, q:GetCastRange())
	local a6 = q:GetCastPoint()
	local N = q:GetSpecialValueInt("radius")
	if K and not CanCastKineticStorm() then
		local a8 = b:FindAoELocation(true, true, b:GetLocation(), M, N * 0.8, 0, 0)
		local X = c.GetEnemiesNearLoc(a8.targetloc, N * 0.8)
		if X ~= nil and #X >= 2 then
			return BOT_ACTION_DESIRE_HIGH, a8.targetloc
		end
	end
	if H then
		if
			c.IsValidTarget(G)
			and c.IsInRange(b, G, M)
			and not c.IsSuspiciousIllusion(G)
			and not G:IsMagicImmune()
			and not G:HasModifier("modifier_necrolyte_reapers_scythe")
			and not G:HasModifier("modifier_skeleton_king_reincarnation_scepter_active")
		then
			local W = c.GetNearbyHeroes(G, 1400, true, BOT_MODE_NONE)
			local X = c.GetNearbyHeroes(G, 1400, false, BOT_MODE_NONE)
			if W ~= nil and X ~= nil and #W >= #X then
				if #X == 0 then
					if c.IsChasingTarget(b, G) then
						if c.IsInRange(b, G, M) then
							return BOT_ACTION_DESIRE_HIGH, G:GetExtrapolatedLocation(a6)
						end
						if c.IsInRange(b, G, M + N) and not c.IsInRange(b, G, M) then
							return BOT_ACTION_DESIRE_HIGH, c.Site.GetXUnitsTowardsLocation(b, G:GetLocation(), M)
						end
					end
				else
					if c.IsInRange(b, G, M) then
						X = c.GetEnemiesNearLoc(G:GetLocation(), N * 0.8)
						if X ~= nil and #X >= 1 then
							return BOT_ACTION_DESIRE_HIGH, c.GetCenterOfUnits(X)
						else
							return BOT_ACTION_DESIRE_HIGH, G:GetExtrapolatedLocation(a6)
						end
					end
					if c.IsInRange(b, G, M + N) and not c.IsInRange(b, G, M) then
						X = c.GetEnemiesNearLoc(G:GetLocation(), N * 0.8)
						if X ~= nil and #X >= 1 then
							return BOT_ACTION_DESIRE_HIGH, c.Site.GetXUnitsTowardsLocation(b, c.GetCenterOfUnits(X), M)
						else
							return BOT_ACTION_DESIRE_HIGH, c.Site.GetXUnitsTowardsLocation(b, G:GetLocation(), M)
						end
					end
				end
			end
		end
	end
	local ab = RemapValClamped(q:GetLevel(), 1, 4, 0.75, 0.5)
	if I and b:GetActiveModeDesire() >= ab then
		local X = c.GetNearbyHeroes(b, M, true, BOT_MODE_NONE)
		if X ~= nil and #X >= 1 then
			if
				c.IsValidHero(X[1])
				and c.IsChasingTarget(X[1], b)
				and not c.IsSuspiciousIllusion(X[1])
				and not c.IsDisabled(X[1])
				and not X[1]:IsMagicImmune()
				and not X[1]:HasModifier("modifier_necrolyte_reapers_scythe")
			then
				local W = c.GetNearbyHeroes(X[1], 1200, true, BOT_MODE_NONE)
				local Y = c.GetNearbyHeroes(X[1], 1200, false, BOT_MODE_NONE)
				if W ~= nil and Y ~= nil and (#Y > #W or b:WasRecentlyDamagedByAnyHero(2)) then
					if GetUnitToLocationDistance(b, X[1]:GetExtrapolatedLocation(a6)) > N then
						return BOT_ACTION_DESIRE_HIGH, b:GetLocation()
					else
						return BOT_ACTION_DESIRE_HIGH, (b:GetLocation() + X[1]:GetLocation()) / 2
					end
				end
			end
		end
	end
	local T = c.GetNearbyHeroes(b, M, false, BOT_MODE_NONE)
	for R, U in pairs(T) do
		local V = c.GetNearbyHeroes(U, 1200, true, BOT_MODE_NONE)
		if
			c.IsValidHero(U)
			and c.IsRetreating(U)
			and c.IsCore(U)
			and U:GetActiveModeDesire() >= 0.75
			and U:WasRecentlyDamagedByAnyHero(2)
			and not U:IsIllusion()
			and not H
		then
			if
				V ~= nil
				and #V >= 1
				and c.IsValidHero(V[1])
				and c.IsInRange(b, V[1], M)
				and c.IsChasingTarget(V[1], U)
				and not c.IsChasingTarget(V[1], b)
				and not c.IsDisabled(V[1])
				and not c.IsTaunted(V[1])
				and not c.IsSuspiciousIllusion(V[1])
				and not V[1]:IsMagicImmune()
				and not V[1]:HasModifier("modifier_necrolyte_reapers_scythe")
				and GetUnitToUnitDistance(U, V[1]) < GetUnitToUnitDistance(b, V[1])
			then
				return BOT_ACTION_DESIRE_HIGH, (U:GetLocation() + V[1]:GetLocation()) / 2
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function a.ConsiderStaticStorm()
	if not s:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local N = s:GetSpecialValueInt("radius")
	local M = s:GetCastRange()
	-- Engaging counts too, not only a team fight: two enemies in a skirmish never got it.
	if (K or H) and not CanCastKineticStorm() then
		local a8 = b:FindAoELocation(true, true, b:GetLocation(), M, N * 0.8, 0, 0)
		local X = c.GetEnemiesNearLoc(a8.targetloc, N * 0.8)
		if
			X ~= nil
			and #X >= 2
			and GetUnitToLocationDistance(b, a8.targetloc) <= M
			and not c.IsLocationInChrono(a8.targetloc)
			and not c.IsLocationInBlackHole(a8.targetloc)
		then
			return BOT_ACTION_DESIRE_HIGH, c.GetCenterOfUnits(X)
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function a.ConsiderKineticStorm()
	if CanCastKineticStorm() then
		local M = c.GetProperCastRange(false, b, q:GetCastRange())
		local N = q:GetSpecialValueInt("radius")
		if K or H then
			local a8 = b:FindAoELocation(true, true, b:GetLocation(), M, N * 0.8, 0, 0)
			local X = c.GetEnemiesNearLoc(a8.targetloc, N * 0.8)
			if
				X ~= nil
				and #X >= 2
				and GetUnitToLocationDistance(b, a8.targetloc) <= M
				and not c.IsLocationInChrono(a8.targetloc)
				and not c.IsLocationInBlackHole(a8.targetloc)
			then
				return BOT_ACTION_DESIRE_HIGH, c.GetCenterOfUnits(X)
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function CanCastKineticStorm()
	if c.CanCastAbility(q) and s:IsFullyCastable() then
		local ac = q:GetManaCost() + s:GetManaCost()
		if b:GetMana() >= ac then
			return true
		end
	end
	return false
end
return a
