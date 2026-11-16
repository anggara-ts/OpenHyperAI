-- Rubick: skill build, item build, and ability use for this hero.
local a = {}
local b = GetBot()
local c = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local d = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local e = dofile(GetScriptDirectory() .. "/FuncLib/hero/rubick")
local f = require(GetScriptDirectory() .. "/FuncLib/data/spell_prob_list")
local g = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local h = c.Skill.GetTalentList(b)
local i = c.Skill.GetAbilityList(b)
local j = c.Item.GetRoleItemsBuyList(b)
local k = { ["t25"] = { 10, 0 }, ["t20"] = { 0, 10 }, ["t15"] = { 0, 10 }, ["t10"] = { 10, 0 } }
local l = { { 2, 1, 2, 3, 2, 6, 2, 3, 3, 3, 6, 1, 1, 1, 6 } }
local m = c.Skill.GetRandomBuild(l)
local n = c.Skill.GetTalentBuild(k)
local o = {}
o["pos_2"] = {
	"item_tango",
	"item_double_branches",
	"item_faerie_fire",
	"item_bottle",
	"item_boots",
	"item_magic_wand",
	"item_dagon_2",
	"item_travel_boots",
	"item_cyclone",
	"item_ultimate_scepter",
	"item_octarine_core",
	"item_dagon_5",
	"item_aghanims_shard",
	"item_ultimate_scepter_2",
	"item_shivas_guard",
	"item_travel_boots_2",
	"item_wind_waker",
	"item_moon_shard",
}
o["pos_5"] = {
	"item_double_tango",
	"item_double_branches",
	"item_blood_grenade",
	"item_magic_stick",
	"item_boots",
	"item_magic_wand",
	"item_arcane_boots",
	"item_glimmer_cape",
	"item_pipe",
	"item_aether_lens",
	"item_blink",
	"item_ancient_janggo",
	"item_aghanims_shard",
	"item_force_staff",
	"item_ultimate_scepter",
	"item_octarine_core",
	"item_arcane_blink",
	"item_ultimate_scepter_2",
	"item_moon_shard",
	"item_travel_boots_2",
}
o["pos_4"] = {
	"item_double_tango",
	"item_double_branches",
	"item_blood_grenade",
	"item_magic_stick",
	"item_boots",
	"item_magic_wand",
	"item_arcane_boots",
	"item_glimmer_cape",
	"item_aether_lens",
	"item_blink",
	"item_mekansm",
	"item_guardian_greaves",
	"item_force_staff",
	"item_aghanims_shard",
	"item_ultimate_scepter",
	"item_octarine_core",
	"item_cyclone",
	"item_arcane_blink",
	"item_ultimate_scepter_2",
	"item_moon_shard",
}
o["pos_1"] = {
	"item_tango",
	"item_double_branches",
	"item_faerie_fire",
	"item_boots",
	"item_magic_wand",
	"item_dagon_2",
	"item_travel_boots",
	"item_cyclone",
	"item_ultimate_scepter",
	"item_octarine_core",
	"item_dagon_5",
	"item_aghanims_shard",
	"item_ultimate_scepter_2",
	"item_shivas_guard",
	"item_travel_boots_2",
	"item_wind_waker",
	"item_moon_shard",
}
o["pos_3"] = {
	"item_tango",
	"item_double_branches",
	"item_magic_stick",
	"item_ring_of_protection",
	"item_helm_of_iron_will",
	"item_boots",
	"item_magic_wand",
	"item_phase_boots",
	"item_veil_of_discord",
	"item_glimmer_cape",
	"item_ultimate_scepter",
	"item_blink",
	"item_shivas_guard",
	"item_black_king_bar",
	"item_travel_boots",
	"item_overwhelming_blink",
	"item_ultimate_scepter_2",
	"item_travel_boots_2",
	"item_aghanims_shard",
	"item_moon_shard",
}
a["sBuyList"] = o[j]
a["sSellList"] = { "item_black_king_bar", "item_quelling_blade" }
if c.Role.IsPvNMode() or c.Role.IsAllShadow() then
	a["sBuyList"], a["sSellList"] = { "PvN_antimage" }, {}
end
m, n, a["sBuyList"], a["sSellList"] = c.SetUserHeroInit(m, n, a["sBuyList"], a["sSellList"])
a["sSkillList"] = c.Skill.GetSkillList(i, m, h, n)
a["bDeafaultAbility"] = false
a["bDeafaultItem"] = false
function a.MinionThink(p)
	g.MinionThink(p)
end
local q = SafeAbility(b:GetAbilityByName("rubick_telekinesis"), "rubick_telekinesis", "rubick")
local r = SafeAbility(b:GetAbilityByName("rubick_telekinesis_land"), "rubick_telekinesis_land", "rubick")
local s = SafeAbility(b:GetAbilityByName("rubick_fade_bolt"), "rubick_fade_bolt", "rubick")
local t = SafeAbility(b:GetAbilityByName("rubick_empty1"), "rubick_empty1", "rubick")
local u = SafeAbility(b:GetAbilityByName("rubick_empty2"), "rubick_empty2", "rubick")
local v = SafeAbility(b:GetAbilityByName("rubick_spell_steal"), "rubick_spell_steal", "rubick")
local w, x
local y, z
local A, B
local C, D
local E
local F = 0
if b.shouldBlink == nil then
	b.shouldBlink = false
end
local G
function a.SkillsComplement()
	if c.CanNotUseAbility(b) then
		return
	end
	local H = d.Build(b)
	G = H.isRetreating
	if c.GetHP(b) > 0.3 and not G and (b:IsChanneling() or b:IsUsingAbility() or b:IsCastingAbility()) then
		-- nRadius is a local of ConsiderFadeBolt and nil here, so this line raised an error every
		-- time he was casting; use the 1200 radius the rest of the file checks.
		local I = c.GetNearbyHeroes(b, 1200, true, BOT_MODE_NONE)
		if I ~= nil and #I > 0 then
			return
		end
	end
	E = H.target
	t = b:GetAbilityInSlot(3)
	u = b:GetAbilityInSlot(4)
	a.ConsiderStolenSpell1()
	a.ConsiderStolenSpell2()
	C, D = a.ConsiderSpellSteal()
	if C > 0 then
		b:Action_UseAbilityOnEntity(v, D)
		F = DotaTime()
		return
	end
	w, x = a.ConsiderTelekinesis()
	if w > 0 then
		b.teleTarget = x
		b:Action_UseAbilityOnEntity(q, x)
		return
	end
	y, z = a.ConsiderTelekinesisLand()
	if y > 0 then
		b:Action_UseAbilityOnLocation(r, z)
		b.isChannelLand = false
		b.isSaveUltLand = false
		b.isEngagingLand = false
		b.isRetreatLand = false
		b.isSaveAllyLand = false
		return
	end
	A, B = a.ConsiderFadeBolt()
	if A > 0 then
		b:Action_UseAbilityOnEntity(s, B)
		return
	end
end
function a.ConsiderTelekinesis()
	if q:IsHidden() or not q:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local J = c.GetProperCastRange(false, b, q:GetCastRange())
	-- Clear the landing reason: flags were only cleared when Land was cast, so a lift that ended without
	-- a Land left a stale flag that the next lift's landing used first.
	b.isChannelLand, b.isSaveUltLand, b.isEngagingLand, b.isRetreatLand, b.isSaveAllyLand = false, false, false, false, false
	local I = c.GetNearbyHeroes(b, J + 300, true, BOT_MODE_NONE)
	for K, L in pairs(I) do
		if
			c.IsValidHero(L)
			and c.CanCastOnNonMagicImmune(L)
			and c.CanCastOnTargetAdvanced(L)
			and not c.IsSuspiciousIllusion(L)
		then
			if L:IsChanneling() or c.IsCastingUltimateAbility(L) then
				b.isChannelLand = true
				return BOT_ACTION_DESIRE_HIGH, L
			end
		end
	end
	if c.IsGoingOnSomeone(b) then
		local M = c.GetAlliesNearLoc(b:GetLocation(), 1200)
		local N = c.GetEnemiesNearLoc(b:GetLocation(), 1200)
		-- Telekinesis targets ENEMY units (game files); only the Shard adds teammates
		-- (shard_teammate_throw_delay). Without it this order on an ally is refused every frame.
		for K, O in pairs(c.HasAghanimsShard(b) and M or {}) do
			if
				c.IsValidHero(O)
				and c.IsCore(O)
				and not c.IsSuspiciousIllusion(O)
				and not O:IsInvulnerable()
				and not O:IsAttackImmune()
				and not O:HasModifier("modifier_furion_sprout_damage")
				and not O:HasModifier("modifier_legion_commander_duel")
				and not O:HasModifier("modifier_necrolyte_reapers_scythe")
			then
				if
					O:HasModifier("modifier_enigma_black_hole_pull")
					or O:HasModifier("modifier_faceless_void_chronosphere_freeze")
				then
					b.isSaveUltLand = true
					return BOT_ACTION_DESIRE_HIGH, O
				end
			end
		end
		if
			c.IsValidTarget(E)
			and c.CanCastOnNonMagicImmune(E)
			and c.CanCastOnTargetAdvanced(E)
			and c.IsInRange(b, E, J + 150)
			and not c.IsSuspiciousIllusion(E)
			and not c.IsDisabled(E)
			and not E:HasModifier("modifier_furion_sprout_damage")
			and not E:HasModifier("modifier_legion_commander_duel")
			and not E:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			M = c.GetAlliesNearLoc(E:GetLocation(), 1200)
			N = c.GetEnemiesNearLoc(E:GetLocation(), 1200)
			if M ~= nil and N ~= nil and #M >= #N and not (#N == 0 and #M >= #N + 2) then
				b.isEngagingLand = true
				return BOT_ACTION_DESIRE_HIGH, E
			end
		end
	end
	if G then
		local N = c.GetNearbyHeroes(b, J, true, BOT_MODE_NONE)
		for K, L in pairs(N) do
			if
				c.IsValidHero(L)
				and c.CanCastOnNonMagicImmune(L)
				and c.CanCastOnTargetAdvanced(L)
				and not c.IsSuspiciousIllusion(L)
				and not c.IsDisabled(L)
				and not L:HasModifier("modifier_furion_sprout_damage")
			then
				local M = c.GetNearbyHeroes(L, 1200, true, BOT_MODE_NONE)
				local P = c.GetNearbyHeroes(L, 1200, false, BOT_MODE_NONE)
				if M ~= nil and P ~= nil and (#P > #M or b:WasRecentlyDamagedByAnyHero(2)) then
					b.isRetreatLand = true
					return BOT_ACTION_DESIRE_HIGH, L
				end
			end
		end
	end
	local Q = c.GetNearbyHeroes(b, J, false, BOT_MODE_NONE)
	for K, O in pairs(Q) do
		local R = c.GetNearbyHeroes(O, 1200, true, BOT_MODE_NONE)
		if c.IsValidHero(O) and c.IsRetreating(O) and O:WasRecentlyDamagedByAnyHero(2) and not O:IsIllusion() then
			if
				R ~= nil
				and #R >= 1
				and c.IsValidHero(R[1])
				and c.CanCastOnNonMagicImmune(R[1])
				and c.CanCastOnTargetAdvanced(R[1])
				and c.IsInRange(b, R[1], J)
				and c.IsChasingTarget(R[1], O)
				and R[1]:IsFacingLocation(O:GetLocation(), 30)
				and not c.IsDisabled(R[1])
				and not c.IsTaunted(R[1])
				and not c.IsSuspiciousIllusion(R[1])
				and not R[1]:HasModifier("modifier_legion_commander_duel")
				and not R[1]:HasModifier("modifier_enigma_black_hole_pull")
				and not R[1]:HasModifier("modifier_faceless_void_chronosphere_freeze")
				and not R[1]:HasModifier("modifier_furion_sprout_damage")
				and not R[1]:HasModifier("modifier_necrolyte_reapers_scythe")
			then
				b.isSaveAllyLand = true
				return BOT_ACTION_DESIRE_HIGH, R[1]
			end
		end
	end
	if c.IsDoingRoshan(b) then
		if
			c.IsRoshan(E)
			and c.CanCastOnMagicImmune(E)
			and c.IsInRange(b, E, J)
			and c.IsAttacking(b)
			and E:HasModifier("modifier_roshan_spell_block")
		then
			return BOT_ACTION_DESIRE_LOW, E
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function a.ConsiderTelekinesisLand()
	if r:IsHidden() or not r:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	-- Throw distance is Telekinesis' max_land_distance (375, Shard +225), not the impact "radius"; the
	-- rubick_8 talent is landing DAMAGE (game files), so it no longer adds 300 to the distance.
	local S = q:GetSpecialValueInt("max_land_distance")
	if S <= 0 then
		S = 375
	end
	local M = c.GetAlliesNearLoc(b:GetLocation(), 1200)
	local N = c.GetEnemiesNearLoc(b:GetLocation(), 1200)
	if c.IsValidHero(E) and not c.IsSuspiciousIllusion(E) then
		M = c.GetAlliesNearLoc(E:GetLocation(), 1200)
		N = c.GetEnemiesNearLoc(E:GetLocation(), 1200)
	end
	if M ~= nil and N ~= nil and c.IsValid(b.teleTarget) then
		if b.isChannelLand ~= nil and b.isChannelLand == true then
			if #M >= #N then
				if c.IsInRange(b, b.teleTarget, S) then
					return BOT_ACTION_DESIRE_HIGH, b:GetLocation()
				end
				if not c.IsInRange(b, b.teleTarget, S) then
					return BOT_ACTION_DESIRE_HIGH, c.Site.GetXUnitsTowardsLocation(b, b:GetLocation(), S)
				end
			end
			if #N > #M then
				return BOT_ACTION_DESIRE_HIGH, c.Site.GetXUnitsTowardsLocation(b, c.GetEnemyFountain(), S)
			end
		end
		if b.isSaveUltLand ~= nil and b.isSaveUltLand == true then
			return BOT_ACTION_DESIRE_HIGH, c.Site.GetXUnitsTowardsLocation(b, c.GetTeamFountain(), S)
		end
		if b.isEngagingLand ~= nil and b.isEngagingLand == true then
			return BOT_ACTION_DESIRE_HIGH, b:GetLocation()
		end
		-- datafeed: Land "throws the enemy in a targeted direction", so the point is read from the lifted
		-- unit. Both cases aimed S units from RUBICK (retreat) or toward OUR fountain (save-ally), which
		-- dropped the chaser next to Rubick or onto the fleeing ally. Throw it toward its own fountain.
		if b.isRetreatLand ~= nil and b.isRetreatLand == true then
			a.LogLand("retreat")
			return BOT_ACTION_DESIRE_HIGH, c.Site.GetXUnitsTowardsLocation(b.teleTarget, c.GetEnemyFountain(), S)
		end
		if b.isSaveAllyLand ~= nil and b.isSaveAllyLand == true then
			a.LogLand("save-ally")
			return BOT_ACTION_DESIRE_HIGH, c.Site.GetXUnitsTowardsLocation(b.teleTarget, c.GetEnemyFountain(), S)
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
-- [OHA-RUBICK] telekinesis land why, at most once per 5s.
function a.LogLand(why)
	if DotaTime() < (b._landLogAt or -999) then
		return
	end
	b._landLogAt = DotaTime() + 5
	pcall(print, string.format(
		"[OHA-RUBICK] t=%.0f tele-land %s target=%s",
		DotaTime(),
		why,
		c.IsValid(b.teleTarget) and b.teleTarget:GetUnitName() or "-"
	))
end
function a.ConsiderFadeBolt()
	if not s:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local J = c.GetProperCastRange(false, b, s:GetCastRange())
	local U = s:GetSpecialValueInt("damage")
	local nRadius = s:GetSpecialValueInt("radius")
	local I = c.GetNearbyHeroes(b, J, true, BOT_MODE_NONE)
	for K, L in pairs(I) do
		if
			c.IsValidHero(L)
			and c.CanCastOnNonMagicImmune(L)
			and c.CanCastOnTargetAdvanced(L)
			and not c.IsSuspiciousIllusion(L)
			and not L:HasModifier("modifier_rubick_telekinesis")
		then
			if c.IsInEtherealForm(L) then
				return BOT_ACTION_DESIRE_HIGH, L
			end
			if
				c.CanKillTarget(L, U, DAMAGE_TYPE_MAGICAL)
				and not L:HasModifier("modifier_abaddon_borrowed_time")
				and not L:HasModifier("modifier_dazzle_shallow_grave")
				and not L:HasModifier("modifier_necrolyte_reapers_scythe")
				and not L:HasModifier("modifier_oracle_false_promise_timer")
				and not L:HasModifier("modifier_templar_assassin_refraction_absorb")
			then
				return BOT_ACTION_DESIRE_HIGH, L
			end
		end
	end
	local Q = c.GetNearbyHeroes(b, J, false, BOT_MODE_NONE)
	for K, O in pairs(Q) do
		local R = c.GetNearbyHeroes(O, 1200, true, BOT_MODE_NONE)
		if c.IsValidHero(O) and c.IsRetreating(O) and O:WasRecentlyDamagedByAnyHero(1.5) and not O:IsIllusion() then
			if
				R ~= nil
				and #R >= 1
				and c.IsValidHero(R[1])
				and c.CanCastOnNonMagicImmune(R[1])
				and c.CanCastOnTargetAdvanced(R[1])
				and c.IsInRange(b, R[1], J)
				and c.IsChasingTarget(R[1], O)
				and c.IsAttacking(R[1])
				and R[1]:IsFacingLocation(O:GetLocation(), 30)
				and not c.IsChasingTarget(R[1], b)
				and not c.IsDisabled(R[1])
				and not c.IsTaunted(R[1])
				and not c.IsSuspiciousIllusion(R[1])
				and not R[1]:HasModifier("modifier_necrolyte_reapers_scythe")
				and not R[1]:HasModifier("modifier_rubick_telekinesis")
			then
				return BOT_ACTION_DESIRE_HIGH, R[1]
			end
		end
	end
	if c.IsInTeamFight(b, 1200) then
		local N = c.GetEnemiesNearLoc(b:GetLocation(), J)
		local V = nil
		local W = 100000
		for K, L in pairs(N) do
			if
				c.IsValidHero(L)
				and c.CanCastOnNonMagicImmune(L)
				and c.CanCastOnTargetAdvanced(L)
				and not c.IsSuspiciousIllusion(L)
				and not L:HasModifier("modifier_abaddon_borrowed_time")
				and not L:HasModifier("modifier_necrolyte_reapers_scythe")
				and not L:HasModifier("modifier_dazzle_shallow_grave")
				and not L:HasModifier("modifier_rubick_telekinesis")
				and not L:HasModifier("modifier_templar_assassin_refraction_absorb")
			then
				local P = c.GetEnemiesNearLoc(L:GetLocation(), nRadius)
				local X = L:GetHealth()
				if P ~= nil and #P >= 1 and X < W then
					W = X
					V = L
				end
			end
		end
		if V ~= nil then
			return BOT_ACTION_DESIRE_HIGH, V
		end
	end
	if c.IsGoingOnSomeone(b) then
		if
			c.IsValidTarget(E)
			and c.CanCastOnNonMagicImmune(E)
			and c.CanCastOnTargetAdvanced(E)
			and c.IsInRange(b, E, J)
			and not c.IsSuspiciousIllusion(E)
			and not c.IsDisabled(E)
			and not E:HasModifier("modifier_necrolyte_reapers_scythe")
			and not E:HasModifier("modifier_rubick_telekinesis")
			and not E:HasModifier("modifier_templar_assassin_refraction_absorb")
		then
			local M = c.GetNearbyHeroes(b, 1200, false, BOT_MODE_NONE)
			local N = c.GetNearbyHeroes(b, 1200, true, BOT_MODE_NONE)
			if M ~= nil and N ~= nil and #M >= #N then
				return BOT_ACTION_DESIRE_HIGH, E
			end
		end
	end
	if G then
		local N = c.GetNearbyHeroes(b, J, true, BOT_MODE_NONE)
		for K, L in pairs(N) do
			if
				c.IsValidHero(L)
				and c.CanCastOnNonMagicImmune(L)
				and c.CanCastOnTargetAdvanced(L)
				and c.IsChasingTarget(L, b)
				and c.IsAttacking(L)
				and not c.IsInRange(b, L, 300)
				and not c.IsSuspiciousIllusion(L)
				and not c.IsDisabled(L)
			then
				local M = c.GetNearbyHeroes(L, 1200, true, BOT_MODE_NONE)
				local P = c.GetNearbyHeroes(L, 1200, false, BOT_MODE_NONE)
				if M ~= nil and P ~= nil and (#P > #M or b:WasRecentlyDamagedByAnyHero(2)) then
					return BOT_ACTION_DESIRE_HIGH, L
				end
			end
		end
	end
	if c.IsPushing(b) or c.IsDefending(b) then
		local Y = b:GetNearbyLaneCreeps(1200, true)
		if Y ~= nil and #Y >= 3 and c.CanBeAttacked(Y[1]) then
			return BOT_ACTION_DESIRE_HIGH, Y[1]
		end
	end
	if c.IsLaning(b) and not c.IsThereNonSelfCoreNearby(800) then
		local Z = {}
		local N = c.GetEnemiesNearLoc(b:GetLocation(), 1200)
		local Y = b:GetNearbyLaneCreeps(J, true)
		for K, _ in pairs(Y) do
			if
				c.IsValid(_)
				and c.CanBeAttacked(_)
				and (c.IsKeyWordUnit("ranged", _) or c.IsKeyWordUnit("siege", _) or c.IsKeyWordUnit("flagbearer", _))
				and _:GetHealth() <= U
				and c.GetMP(b) > 0.3
			then
				if N ~= nil and #N >= 1 and GetUnitToUnitDistance(_, N[1]) < 500 then
					return BOT_ACTION_DESIRE_HIGH, _
				end
			end
			if c.IsValid(_) and _:GetHealth() <= U then
				table.insert(Z, _)
			end
		end
		if c.GetMP(b) > 0.3 and N ~= nil and #N >= 1 and #Z >= 2 and c.CanBeAttacked(Z[1]) then
			return BOT_ACTION_DESIRE_HIGH, Z[1]
		end
	end
	if c.IsDoingRoshan(b) then
		if
			c.IsRoshan(E)
			and c.CanCastOnNonMagicImmune(E)
			and c.IsInRange(b, E, J)
			and not E:HasModifier("modifier_roshan_spell_block")
		then
			return BOT_ACTION_DESIRE_HIGH, E
		end
	end
	if c.IsDoingTormentor(b) then
		if c.IsTormentor(E) and c.IsInRange(b, E, J) and c.IsAttacking(b) then
			return BOT_ACTION_DESIRE_HIGH, E
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function a.ConsiderStolenSpell1()
	if t:GetName() == "rubick_empty1" or not t:IsFullyCastable() then
		return BOT_ACTION_DESIRE_HIGH, 0, ""
	end
	e.ConsiderStolenSpell(t)
	return BOT_ACTION_DESIRE_HIGH, 0, ""
end
function a.ConsiderStolenSpell2()
	if u:GetName() == "rubick_empty2" or not u:IsFullyCastable() then
		return BOT_ACTION_DESIRE_HIGH, 0, ""
	end
	e.ConsiderStolenSpell(u)
	return BOT_ACTION_DESIRE_HIGH, 0, ""
end
function a.ConsiderSpellSteal()
	if not v:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	if DotaTime() - F < 60 then
		if t:IsFullyCastable() and t:IsUltimate() and not b:HasScepter() then
			return BOT_ACTION_DESIRE_NONE, nil
		end
		if u:IsFullyCastable() and u:IsUltimate() then
			return BOT_ACTION_DESIRE_NONE, nil
		end
	end
	if t:GetCooldownTimeRemaining() < 5 and t:GetAbilityDamage() >= 280 then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	if u:GetCooldownTimeRemaining() < 5 and u:GetAbilityDamage() >= 280 then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local J = c.GetProperCastRange(false, b, v:GetCastRange())
	local N = c.GetEnemiesNearLoc(b:GetLocation(), J + 300)
	for K, L in pairs(N) do
		if
			c.IsValidHero(L)
			and c.CanCastOnTargetAdvanced(L)
			and not c.IsSuspiciousIllusion(L)
			and not c.IsMeepoClone(L)
		then
			if L:IsUsingAbility() or L:IsCastingAbility() or c.IsCastingUltimateAbility(L) or L:GetLevel() > 10 then
				-- The weight table is keyed by spell NAME; passing the handle always gave the default 1,
				-- and "weight*100*100 >= rand(1,70)" was always true, so Rubick re-stole every cooldown and
				-- threw away good stolen spells. Now: weight of the held spell (0 keep .. 1 replace) against
				-- a roll that is redrawn only every 15s (a per-frame roll passes within a second anyway).
				if DotaTime() >= (b._stealRollAt or -999) then
					b._stealRollAt = DotaTime() + 15
					b._stealRoll = RandomInt(1, 100)
					b._stealRoll2 = RandomInt(1, 100)
				end
				local a0 = f.GetSpellReplaceWeight(t:GetName()) * 100
				local a1 = b._stealRoll
				local steal = false
				if b:HasScepter() then
					local a2 = f.GetSpellReplaceWeight(u:GetName()) * 100
					if a0 >= a1 and a2 >= b._stealRoll2 then
						steal = true
					end
					if a2 >= a1 then
						steal = true
					end
				else
					if a0 >= a1 then
						steal = true
					end
				end
				if steal then
					if DotaTime() >= (b._stealLogAt or -999) then
						b._stealLogAt = DotaTime() + 5
						pcall(print, string.format(
							"[OHA-RUBICK] t=%.0f spell-steal from=%s held=%s w=%.0f roll=%d",
							DotaTime(),
							(string.gsub(L:GetUnitName(), "npc_dota_hero_", "")),
							t:GetName(),
							a0,
							a1
						))
					end
					b._stealRollAt = -999
					return BOT_ACTION_DESIRE_HIGH, L
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
return a
