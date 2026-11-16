-- Obsidian Destroyer: skill build, item build, and ability use for this hero.
local a = {}
local b = GetBot()
local c = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local d = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local e = c.Skill.GetTalentList(b)
local f = c.Skill.GetAbilityList(b)
local g = c.Item.GetRoleItemsBuyList(b)
local h = { { ["t25"] = { 0, 10 }, ["t20"] = { 10, 0 }, ["t15"] = { 10, 0 }, ["t10"] = { 10, 0 } } }
local i = { { 2, 1, 3, 2, 2, 6, 2, 1, 1, 1, 6, 3, 3, 3, 6 }, { 2, 1, 3, 2, 2, 6, 2, 1, 1, 1, 6, 3, 3, 3, 6 } }
local j
local k = c.Skill.GetTalentBuild(h[1])
if g == "pos_1" then
	j = i[1]
else
	j = i[2]
end
local l = {}
l["pos_1"] = {
	"item_tango",
	"item_double_branches",
	"item_faerie_fire",
	"item_double_circlet",
	"item_magic_wand",
	"item_double_null_talisman",
	"item_power_treads",
	-- Kaya, then Meteor Hammer (user call): timed to land as Astral Imprisonment ends.
	"item_kaya",
	"item_meteor_hammer",
	"item_witch_blade",
	"item_force_staff",
	"item_hurricane_pike",
	"item_black_king_bar",
	"item_aghanims_shard",
	"item_devastator",
	"item_sheepstick",
	"item_shivas_guard",
	"item_moon_shard",
	"item_ultimate_scepter_2",
	"item_travel_boots_2",
}
l["pos_2"] = {
	"item_tango",
	"item_double_branches",
	"item_faerie_fire",
	"item_double_mantle",
	"item_magic_wand",
	"item_double_null_talisman",
	"item_power_treads",
	-- Kaya, then Meteor Hammer (user call): timed to land as Astral Imprisonment ends.
	"item_kaya",
	"item_meteor_hammer",
	"item_witch_blade",
	"item_force_staff",
	"item_hurricane_pike",
	"item_black_king_bar",
	"item_aghanims_shard",
	"item_devastator",
	"item_sheepstick",
	"item_shivas_guard",
	"item_moon_shard",
	"item_ultimate_scepter_2",
	"item_travel_boots_2",
}
l["pos_3"] = l["pos_2"]
l["pos_4"] = l["pos_2"]
l["pos_5"] = l["pos_2"]
a["sBuyList"] = l[g]
a["sSellList"] = {
	"item_magic_wand",
	"item_black_king_bar",
	"item_null_talisman",
	"item_sheepstick",
	"item_null_talisman",
	"item_shivas_guard",
}
if c.Role.IsPvNMode() or c.Role.IsAllShadow() then
	a["sBuyList"], a["sSellList"] = { "PvN_mid" }, {}
end
j, k, a["sBuyList"], a["sSellList"] = c.SetUserHeroInit(j, k, a["sBuyList"], a["sSellList"])
a["sSkillList"] = c.Skill.GetSkillList(f, j, e, k)
a["bDeafaultAbility"] = false
a["bDeafaultItem"] = false
function a.MinionThink(m)
	if d.IsValidUnit(m) then
		d.IllusionThink(m)
	end
end
local n = SafeAbility(
	b:GetAbilityByName("obsidian_destroyer_arcane_orb"),
	"obsidian_destroyer_arcane_orb",
	"obsidian_destroyer"
)
local o = SafeAbility(
	b:GetAbilityByName("obsidian_destroyer_astral_imprisonment"),
	"obsidian_destroyer_astral_imprisonment",
	"obsidian_destroyer"
)
local p = SafeAbility(
	b:GetAbilityByName("obsidian_destroyer_equilibrium"),
	"obsidian_destroyer_equilibrium",
	"obsidian_destroyer"
)
local q = SafeAbility(
	b:GetAbilityByName("obsidian_destroyer_objurgation"),
	"obsidian_destroyer_objurgation",
	"obsidian_destroyer"
)
local r = SafeAbility(
	b:GetAbilityByName("obsidian_destroyer_sanity_eclipse"),
	"obsidian_destroyer_sanity_eclipse",
	"obsidian_destroyer"
)
local s, t
local u, v
local w, x
local y
local z = false
local A, B
local C, D
-- Astral Imprisonment then Meteor Hammer. Valve data: the prison lasts 1.75/2.5/3.25/4s (the
-- prisoner is invulnerable), Meteor Hammer channels 2s and lands 0.5s later (600 range, 400
-- radius, 0.75s stun). So the channel starts when the prison has 2.5s left, on the prison spot,
-- and the meteor lands as the target comes out.
local PRISON_DURATION = { 1.75, 2.5, 3.25, 4 }
local HAMMER_LEAD = 2.5
function a.NotePrison(target)
	if not c.IsValidHero(target) or target:GetTeam() == GetTeam() then
		return
	end
	local lvl = math.max(1, math.min(4, o:GetLevel()))
	local dur = PRISON_DURATION[lvl]
	local okD, v = pcall(function()
		return o:GetSpecialValueFloat("prison_duration")
	end)
	if okD and type(v) == "number" and v > 0 then
		dur = v
	end
	local cast = math.max(0, o:GetCastPoint())
	b._prison = { target = target, loc = target:GetLocation(), castAt = DotaTime(), endAt = DotaTime() + cast + dur }
end
function a.ConsiderPrisonHammer()
	local st = b._prison
	if st == nil then
		return false
	end
	local now = DotaTime()
	-- The prison did not land: the target is still there and can be hurt.
	if now - st.castAt > 0.7 and c.IsValidHero(st.target) and st.target:CanBeSeen() and not st.target:IsInvulnerable() and now < st.endAt - 0.3 then
		b._prison = nil
		return false
	end
	if now > st.endAt + 0.3 then
		b._prison = nil
		return false
	end
	local slot = b:FindItemSlot("item_meteor_hammer")
	if slot < 0 or slot > 5 then
		return false
	end
	local hammer = b:GetItemInSlot(slot)
	if hammer == nil or not hammer:IsFullyCastable() then
		return false
	end
	local left = st.endAt - now
	local dist = GetUnitToLocationDistance(b, st.loc)
	-- Meteor Hammer is a 400-radius area (user note): aimed at a point inside its 600 range toward
	-- the prison spot, it still covers the prisoner up to ~980 away, so no step at all (Astral
	-- Imprisonment is cast from up to 650).
	local aim = st.loc
	if dist > 580 then
		aim = b:GetLocation() + (st.loc - b:GetLocation()):Normalized() * 580
	end
	if left <= HAMMER_LEAD + 0.05 then
		if dist <= 580 + 380 then
			b._prison = nil
			pcall(print, string.format(
				"[OHA-OD] t=%.1f prison-hammer target=%s left=%.2f dist=%d",
				now,
				c.IsValidHero(st.target) and (string.gsub(st.target:GetUnitName(), "npc_dota_hero_", "")) or "?",
				left,
				math.floor(dist)
			))
			b:Action_UseAbilityOnLocation(hammer, aim)
			return true
		end
		return false
	end
	return false
end
-- Items still work while silenced (game 021, 24:30: OD imprisoned Mirana, was silenced by
-- Static Storm, and the hammer check, behind the "cannot use abilities" gate, never ran).
local function CanUseItemsNow()
	if not b:IsAlive() or b:IsStunned() or b:IsHexed() or b:IsChanneling() or b:IsNightmared() then
		return false
	end
	local okM, muted = pcall(function()
		return b:IsMuted()
	end)
	return not (okM and muted)
end
function a.SkillsComplement()
	b = GetBot()
	if b._prison ~= nil and CanUseItemsNow() and a.ConsiderPrisonHammer() then
		return
	end
	if c.CanNotUseAbility(b) then
		return
	end
	n = SafeAbility(
		b:GetAbilityByName("obsidian_destroyer_arcane_orb"),
		"obsidian_destroyer_arcane_orb",
		"obsidian_destroyer"
	)
	o = SafeAbility(
		b:GetAbilityByName("obsidian_destroyer_astral_imprisonment"),
		"obsidian_destroyer_astral_imprisonment",
		"obsidian_destroyer"
	)
	p = SafeAbility(
		b:GetAbilityByName("obsidian_destroyer_equilibrium"),
		"obsidian_destroyer_equilibrium",
		"obsidian_destroyer"
	)
	q = SafeAbility(
		b:GetAbilityByName("obsidian_destroyer_objurgation"),
		"obsidian_destroyer_objurgation",
		"obsidian_destroyer"
	)
	r = SafeAbility(
		b:GetAbilityByName("obsidian_destroyer_sanity_eclipse"),
		"obsidian_destroyer_sanity_eclipse",
		"obsidian_destroyer"
	)
	z = c.IsAttacking(b)
	B = c.GetHP(b)
	A = c.GetProperTarget(b)
	C = b:GetNearbyHeroes(1600, false, BOT_MODE_NONE)
	D = b:GetNearbyHeroes(1600, true, BOT_MODE_NONE)
	y = a.ConsiderObjurgation()
	if y > 0 then
		c.SetQueuePtToINT(b, false)
		b:ActionQueue_UseAbility(q)
		return
	end
	w, x = a.ConsiderSanitysEclipse()
	if w > 0 then
		c.SetQueuePtToINT(b, false)
		b:ActionQueue_UseAbilityOnLocation(r, x)
		return
	end
	if a.ConsiderPrisonHammer() then
		return
	end
	u, v = a.ConsiderAstralImprisonment()
	if u > 0 then
		c.SetQueuePtToINT(b, false)
		b:ActionQueue_UseAbilityOnEntity(o, v)
		pcall(a.NotePrison, v)
		return
	end
	s, t = a.ConsiderArcaneOrb()
	if s > 0 then
		b:Action_UseAbilityOnEntity(n, t)
		return
	end
end
function a.ConsiderArcaneOrb()
	if not n:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local E = b:GetAttackRange()
	local F = n:GetSpecialValueInt("mana_pool_damage_pct") / 100
	local G = b:GetAttackDamage() + b:GetMana() * F
	local H = n:GetLevel()
	local I = n:GetAutoCastState()
	local J = n:GetManaCost()
	local K = c.GetManaAfter(J)
	local L = c.GetManaThreshold(b, J, { o, q, r })
	if H == 4 and not I then
		n:ToggleAutoCast()
	end
	if I then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	for M, N in pairs(D) do
		if c.IsValidHero(N) and c.CanBeAttacked(N) and c.IsInRange(b, N, E + 300) and c.CanCastOnNonMagicImmune(N) then
			local O = GetUnitToUnitDistance(b, N) / b:GetAttackProjectileSpeed()
			if
				c.WillKillTarget(N, G, DAMAGE_TYPE_MAGICAL, O)
				and not N:HasModifier("modifier_abaddon_borrowed_time")
				and not N:HasModifier("modifier_dazzle_shallow_grave")
				and not N:HasModifier("modifier_necrolyte_reapers_scythe")
				and not N:HasModifier("modifier_oracle_false_promise_timer")
				and not N:HasModifier("modifier_templar_assassin_refraction_absorb")
			then
				return BOT_ACTION_DESIRE_HIGH, N
			end
		end
	end
	if c.IsGoingOnSomeone(b) then
		if
			c.IsValidHero(A)
			and c.CanBeAttacked(A)
			and c.IsInRange(b, A, E + 150)
			and not c.IsSuspiciousIllusion(A)
			and not A:HasModifier("modifier_abaddon_borrowed_time")
			and not A:HasModifier("modifier_dazzle_shallow_grave")
			and not A:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			return BOT_ACTION_DESIRE_HIGH, A
		end
	end
	local P = b:GetNearbyCreeps(Min(E + 300, 1600), true)
	if (c.IsPushing(b) or c.IsDefending(b) or c.IsFarming(b)) and z and K > L + 0.1 then
		if c.IsValid(A) and c.CanBeAttacked(A) and A:IsCreep() then
			return BOT_ACTION_DESIRE_HIGH, A
		end
	end
	if not c.IsRetreating(b) and not c.IsRealInvisible(b) then
		if c.IsEarlyGame() then
			for M, N in pairs(D) do
				if
					c.IsValidHero(N)
					and c.CanBeAttacked(N)
					and c.IsInRange(b, N, E + 150)
					and c.CanCastOnNonMagicImmune(N)
				then
					return BOT_ACTION_DESIRE_HIGH, N
				end
			end
		end
		for M, Q in pairs(P) do
			if c.IsValid(Q) and c.CanBeAttacked(Q) and (c.IsCore(b) or not c.IsOtherAllysTarget(Q)) then
				local O = GetUnitToUnitDistance(b, Q) / b:GetAttackProjectileSpeed()
				if c.WillKillTarget(Q, G, DAMAGE_TYPE_MAGICAL, O) then
					return BOT_ACTION_DESIRE_HIGH, Q
				end
			end
		end
	end
	if c.IsDoingRoshan(b) then
		if c.IsRoshan(A) and c.CanBeAttacked(A) and c.IsInRange(b, A, E) and z then
			return BOT_ACTION_DESIRE_HIGH, A
		end
	end
	if c.IsDoingTormentor(b) then
		if c.IsTormentor(A) and c.IsInRange(b, A, E) and z then
			return BOT_ACTION_DESIRE_HIGH, A
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function a.ConsiderAstralImprisonment()
	if not o:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local R = o:GetCastRange()
	local G = o:GetSpecialValueInt("damage")
	local S = o:GetSpecialValueInt("prison_duration")
	local J = o:GetManaCost()
	local K = c.GetManaAfter(J)
	local L = c.GetManaThreshold(b, J, { r })
	if #C >= #D then
		if c.GetAttackProjectileDamageByRange(b, 800) > b:GetHealth() then
			return BOT_ACTION_DESIRE_HIGH, b
		end
		if not b:IsMagicImmune() then
			if c.IsStunProjectileIncoming(b, 600) and B < 0.2 then
				return BOT_ACTION_DESIRE_HIGH, b
			end
		end
	end
	for M, N in pairs(D) do
		if
			c.IsValidHero(N)
			and c.CanBeAttacked(N)
			and c.IsInRange(b, N, R)
			and c.CanCastOnNonMagicImmune(N)
			and c.CanCastOnTargetAdvanced(N)
			and K > L
		then
			if N:IsChanneling() then
				return BOT_ACTION_DESIRE_HIGH, N
			end
			local T = c.GetHeroesTargetingUnit(C, N)
			if
				c.CanKillTarget(N, G, DAMAGE_TYPE_MAGICAL)
				and not N:HasModifier("modifier_abaddon_borrowed_time")
				and not N:HasModifier("modifier_dazzle_shallow_grave")
				and not N:HasModifier("modifier_oracle_false_promise_timer")
				and not N:HasModifier("modifier_templar_assassin_refraction_absorb")
				and #T <= 1
			then
				return BOT_ACTION_DESIRE_HIGH, N
			end
		end
	end
	if c.IsInTeamFight(b, 1200) and K > L then
		for M, U in pairs(C) do
			if c.IsValidHero(U) and c.CanBeAttacked(U) and c.IsInRange(b, U, R + 300) and not U:IsIllusion() then
				if
					U:HasModifier("modifier_enigma_black_hole_pull")
					or U:HasModifier("modifier_faceless_void_chronosphere_freeze")
					or U:HasModifier("modifier_necrolyte_reapers_scythe")
					or U:HasModifier("modifier_legion_commander_duel") and c.GetHP(U) < 0.1
					or c.GetHP(U) < 0.33 and c.IsRetreating(U)
				then
					return BOT_ACTION_DESIRE_HIGH, U
				end
			end
		end
		local V = nil
		local W = 0
		for M, N in pairs(D) do
			if
				c.IsValidHero(N)
				and c.CanBeAttacked(N)
				and c.IsInRange(b, N, R + 300)
				and c.CanCastOnNonMagicImmune(N)
				and c.CanCastOnTargetAdvanced(N)
				and not c.IsDisabled(N)
			then
				if
					N:HasModifier("modifier_abaddon_borrowed_time") or N:HasModifier("modifier_dazzle_shallow_grave")
				then
					return BOT_ACTION_DESIRE_HIGH, N
				end
				local X = N:GetEstimatedDamageToTarget(false, b, 5.0, DAMAGE_TYPE_ALL)
				local Y = c.GetTotalEstimatedDamageToTarget(C, N, 5.0)
				if X > W and Y < N:GetHealth() then
					V = N
					W = X
				end
			end
		end
		if V then
			return BOT_ACTION_DESIRE_HIGH, V
		end
	end
	if c.IsGoingOnSomeone(b) then
		if
			c.IsValidHero(A)
			and c.CanBeAttacked(A)
			and c.IsInRange(b, A, R)
			and c.CanCastOnNonMagicImmune(A)
			and c.CanCastOnTargetAdvanced(A)
			and not c.IsDisabled(A)
			and not A:HasModifier("modifier_necrolyte_reapers_scythe")
			and not A:HasModifier("modifier_templar_assassin_refraction_absorb")
			and K > L
		then
			local Z = c.GetAlliesNearLoc(b:GetLocation(), 800)
			local _ = c.GetEnemiesNearLoc(b:GetLocation(), 800)
			if not (#Z >= #_ + 2) then
				if #Z <= 1 then
					return BOT_ACTION_DESIRE_HIGH, A
				end
				local a0 = 0
				for M, U in pairs(C) do
					if
						c.IsValidHero(U)
						and b ~= U
						and not U:IsIllusion()
						and not U:HasModifier("modifier_necrolyte_reapers_scythe")
						and not U:HasModifier("modifier_teleporting")
						and (U:GetAttackTarget() == A or c.IsChasingTarget(U, A))
					then
						a0 = a0 + U:GetEstimatedDamageToTarget(true, A, S, DAMAGE_TYPE_ALL)
					end
				end
				if a0 * 1.25 < A:GetHealth() then
					return BOT_ACTION_DESIRE_HIGH, A
				end
			end
		end
	end
	if c.IsRetreating(b) and not c.IsRealInvisible(b) then
		for M, N in pairs(D) do
			if
				c.IsValidHero(N)
				and c.CanBeAttacked(N)
				and c.IsInRange(b, N, R)
				and c.CanCastOnNonMagicImmune(N)
				and c.CanCastOnTargetAdvanced(N)
				and not c.IsDisabled(N)
				and b:WasRecentlyDamagedByHero(N, 5.0)
			then
				return BOT_ACTION_DESIRE_HIGH, N
			end
		end
	end
	if not c.IsRetreating(b) and not c.IsRealInvisible(b) and not c.IsInTeamFight(b, 1200) and K > L then
		for M, U in pairs(C) do
			if c.IsValidHero(U) and b ~= U and c.IsRetreating(U) and not U:IsIllusion() then
				for M, N in pairs(D) do
					if
						c.IsValidHero(N)
						and c.CanBeAttacked(N)
						and c.IsInRange(b, N, R)
						and c.CanCastOnNonMagicImmune(N)
						and c.CanCastOnTargetAdvanced(N)
						and not c.IsDisabled(N)
						and U:WasRecentlyDamagedByHero(N, 5.0)
						and c.IsChasingTarget(N, U)
					then
						return BOT_ACTION_DESIRE_HIGH, N
					end
				end
			end
		end
	end
	if c.IsLaning(b) and c.IsEarlyGame() and K > L then
		for M, N in pairs(D) do
			if
				c.IsValidHero(N)
				and c.CanBeAttacked(N)
				and c.IsInRange(b, N, R + 200)
				and c.CanCastOnNonMagicImmune(N)
				and c.CanCastOnTargetAdvanced(N)
				and c.IsAttacking(N)
				and not c.IsDisabled(N)
			then
				local Z = c.GetAlliesNearLoc(b:GetLocation(), 800)
				local _ = c.GetEnemiesNearLoc(b:GetLocation(), 800)
				if not (#Z >= #_ + 2) then
					return BOT_ACTION_DESIRE_HIGH, N
				end
			end
		end
	end
	if c.IsDoingTormentor(b) then
		if c.IsTormentor(A) and c.IsInRange(b, A, R) then
			for M, U in pairs(C) do
				if
					c.IsValidHero(U)
					and c.GetHP(U) < 0.3
					and not U:IsIllusion()
					and not U:HasModifier("modifier_abaddon_borrowed_time")
					and not U:HasModifier("modifier_dazzle_shallow_grave")
					and not U:HasModifier("modifier_templar_assassin_refraction_absorb")
				then
					return BOT_ACTION_DESIRE_HIGH, U
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function a.ConsiderSanitysEclipse()
	if not r:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local R = r:GetCastRange()
	local a1 = r:GetCastPoint()
	local a2 = r:GetSpecialValueFloat("damage_multiplier")
	local a3 = r:GetSpecialValueFloat("base_damage")
	for M, N in pairs(D) do
		if
			c.IsValidHero(N)
			and c.CanBeAttacked(N)
			and c.IsInRange(b, N, R + 300)
			and c.CanCastOnNonMagicImmune(N)
			and not N:HasModifier("modifier_abaddon_borrowed_time")
			and not N:HasModifier("modifier_dazzle_shallow_grave")
			and not N:HasModifier("modifier_enigma_black_hole_pull")
			and not N:HasModifier("modifier_faceless_void_chronosphere_freeze")
			and not N:HasModifier("modifier_legion_commander_duel")
			and not N:HasModifier("modifier_necrolyte_reapers_scythe")
			and not N:HasModifier("modifier_oracle_false_promise_timer")
		then
			local O = GetUnitToUnitDistance(b, N) / b:GetCurrentMovementSpeed() + a1
			local a4 = math.abs(b:GetMana() - N:GetMana())
			local G = a4 * a2
			if c.WillKillTarget(N, a3 + G, DAMAGE_TYPE_MAGICAL, O) then
				return BOT_ACTION_DESIRE_HIGH, N:GetLocation()
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function a.ConsiderObjurgation()
	if not q:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
	end
	if c.IsRetreating(b) and not c.IsRealInvisible(b) and b:WasRecentlyDamagedByAnyHero(2.0) and B < 0.6 then
		if #D > #C or b:IsRooted() or c.GetTotalEstimatedDamageToTarget(D, b, 6.0) > b:GetHealth() then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if not c.IsRealInvisible(b) and b:WasRecentlyDamagedByAnyHero(2.0) then
		if c.GetTotalEstimatedDamageToTarget(D, b, 5.0) > b:GetHealth() then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if c.IsDoingRoshan(b) then
		if c.IsRoshan(A) and c.CanBeAttacked(A) and c.IsInRange(b, A, 800) and z and B < 0.3 then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if c.IsDoingTormentor(b) then
		if c.IsTormentor(A) and c.IsInRange(b, A, 800) and z and B < 0.35 then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
return a
