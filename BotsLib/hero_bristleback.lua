-- Bristleback: skill build, item build, and ability use for this hero.
local a = {}
local b = GetBot()
local c = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local d = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local e = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local f = c.Skill.GetTalentList(b)
local g = c.Skill.GetAbilityList(b)
local h = c.Item.GetRoleItemsBuyList(b)
local i = { ["t25"] = { 0, 10 }, ["t20"] = { 10, 0 }, ["t15"] = { 10, 0 }, ["t10"] = { 10, 0 } }
local j = { { 2, 3, 2, 1, 2, 6, 2, 3, 3, 3, 6, 1, 1, 1, 6 } }
local k = c.Skill.GetRandomBuild(j)
local l = c.Skill.GetTalentBuild(i)
-- Heaven's Halberd only against heavy right-click damage that does not come through
-- illusions; otherwise the slot is skipped. It used to be a random pick, a second BKB 1 in 3.
local heavyPhysical, physicalHeroes = require(GetScriptDirectory() .. "/FuncLib/systems/item_strategy").EnemyHeavyPhysical()
local m = heavyPhysical and "item_heavens_halberd" or false
if h == "pos_3" then
	pcall(print, string.format(
		"[OHA-BUY] t=%.0f bristleback halberd=%s physical=%s",
		DotaTime(),
		tostring(heavyPhysical),
		table.concat(physicalHeroes, ",")
	))
end
local n = {}
n["pos_1"] = {
	"item_tango",
	"item_double_branches",
	"item_quelling_blade",
	"item_magic_wand",
	"item_bracer",
	"item_power_treads",
	"item_ultimate_scepter",
	"item_black_king_bar",
	"item_aghanims_shard",
	"item_sange_and_yasha",
	"item_basher",
	"item_satanic",
	"item_abyssal_blade",
	"item_assault",
	"item_ultimate_scepter_2",
	"item_moon_shard",
	"item_travel_boots_2",
}
n["pos_3"] = {
	"item_tango",
	"item_double_branches",
	"item_quelling_blade",
	"item_magic_wand",
	"item_bracer",
	-- Boots, then Ring of Health for lane sustain, then the rest of Power Treads. Vanguard
	-- uses the Ring, then Blade Mail, then the Vanguard upgrades to Crimson Guard.
	"item_boots",
	"item_ring_of_health",
	"item_power_treads_str",
	"item_vanguard",
	"item_blade_mail",
	"item_crimson_guard",
	"item_black_king_bar",
	"item_lotus_orb",
	m,
	"item_aghanims_shard",
	"item_assault",
	"item_ultimate_scepter_2",
	"item_wind_waker",
	"item_moon_shard",
	"item_travel_boots_2",
}
n["pos_2"] = {
	"item_tango",
	"item_double_branches",
	"item_quelling_blade",
	"item_bottle",
	"item_magic_wand",
	"item_bracer",
	"item_power_treads",
	"item_ultimate_scepter",
	"item_black_king_bar",
	"item_aghanims_shard",
	"item_sange_and_yasha",
	"item_assault",
	"item_satanic",
	"item_basher",
	"item_ultimate_scepter_2",
	"item_abyssal_blade",
	"item_moon_shard",
	"item_travel_boots_2",
}
n["pos_4"] = {
	"item_priest_outfit",
	"item_hand_of_midas",
	"item_mekansm",
	"item_glimmer_cape",
	"item_aghanims_shard",
	"item_guardian_greaves",
	"item_spirit_vessel",
	"item_lotus_orb",
	"item_mjollnir",
	"item_ultimate_scepter",
	"item_sheepstick",
	"item_mystic_staff",
	"item_ultimate_scepter_2",
	"item_shivas_guard",
	"item_moon_shard",
}
n["pos_5"] = {
	"item_mage_outfit",
	"item_hand_of_midas",
	"item_glimmer_cape",
	"item_pavise",
	"item_pipe",
	"item_solar_crest",
	"item_lotus_orb",
	"item_aghanims_shard",
	"item_spirit_vessel",
	"item_ultimate_scepter",
	"item_shivas_guard",
	"item_mystic_staff",
	"item_ultimate_scepter_2",
	"item_moon_shard",
	"item_sheepstick",
}
-- Drop the skipped Halberd slot (false) so the list has no holes.
for _, list in pairs(n) do
	for idx = #list, 1, -1 do
		if list[idx] == false then
			table.remove(list, idx)
		end
	end
end
a["sBuyList"] = n[h]
a["sSellList"] = {
	"item_power_treads",
	"item_quelling_blade",
	"item_basher",
	"item_quelling_blade",
	"item_satanic",
	"item_magic_wand",
	"item_assault",
	"item_bracer",
	"item_assault",
	"item_bottle",
	"item_satanic",
	"item_bracer",
}
if c.Role.IsPvNMode() or c.Role.IsAllShadow() then
	a["sBuyList"], a["sSellList"] = { "PvN_tank" }, { "item_power_treads", "item_quelling_blade" }
end
k, l, a["sBuyList"], a["sSellList"] = c.SetUserHeroInit(k, l, a["sBuyList"], a["sSellList"])
a["sSkillList"] = c.Skill.GetSkillList(g, k, f, l)
a["bDeafaultAbility"] = false
a["bDeafaultItem"] = false
function a.MinionThink(o)
	e.MinionThink(o)
end
local p =
	SafeAbility(b:GetAbilityByName("bristleback_viscous_nasal_goo"), "bristleback_viscous_nasal_goo", "bristleback")
local q = SafeAbility(b:GetAbilityByName("bristleback_quill_spray"), "bristleback_quill_spray", "bristleback")
local r = SafeAbility(b:GetAbilityByName("bristleback_bristleback"), "bristleback_bristleback", "bristleback")
local s = SafeAbility(b:GetAbilityByName("bristleback_hairball"), "bristleback_hairball", "bristleback")
local t = SafeAbility(b:GetAbilityByName("bristleback_warpath"), "bristleback_warpath", "bristleback")
local u, v
local w
local x, y
local z, A
local B
local C = false
local D, E
local F, G
local H
local I
local J
local K
function a.SkillsComplement()
	b = GetBot()
	if c.CanNotUseAbility(b) then
		return
	end
	local L = d.Build(b)
	H = L.isEngaging
	I = L.isRetreating
	J = L.hp
	K = L.isTeamFight
	C = c.IsAttacking(b)
	E = J
	D = L.target
	F = L.allies
	G = L.enemies
	x, y = a.ConsiderHairball()
	if x > 0 then
		c.SetQueuePtToINT(b, true)
		b:ActionQueue_UseAbilityOnLocation(s, y)
		return
	end
	z, A = a.ConsiderBristleback()
	if z > 0 then
		c.SetQueuePtToINT(b, false)
		b:ActionQueue_UseAbilityOnLocation(r, A)
		return
	end
	u, v = a.ConsiderViscousNasalGoo()
	if u > 0 then
		c.SetQueuePtToINT(b, false)
		b:ActionQueue_UseAbilityOnEntity(p, v)
		return
	end
	B = a.ConsiderWarpath()
	if B > 0 then
		b:Action_UseAbility(t)
		return
	end
	w = a.ConsiderQuillSpray()
	if w > 0 then
		c.SetQueuePtToINT(b, true)
		b:ActionQueue_UseAbility(q)
		return
	end
end
function a.ConsiderViscousNasalGoo()
	if not c.CanCastAbility(p) then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	for M, N in pairs(G) do
		if
			c.IsValidHero(N)
			and J < 0.6
			and J < c.GetHP(N)
			and c.IsInRange(b, N, 900)
			and N:IsFacingLocation(b:GetLocation(), 40)
		then
			return BOT_ACTION_DESIRE_NONE, nil
		end
	end
	local O = c.GetProperCastRange(false, b, p:GetCastRange())
	local P = p:GetManaCost()
	local Q = c.GetManaAfter(P)
	local R = c.GetManaThreshold(b, P, { r, s })
	if K then
		if
			c.IsValidHero(G[1])
			and c.CanBeAttacked(G[1])
			and c.CanCastOnNonMagicImmune(G[1])
			and not G[1]:HasModifier("modifier_necrolyte_reapers_scythe")
			and Q > R
		then
			return BOT_ACTION_DESIRE_HIGH, G[1]
		end
	end
	if H then
		if
			c.IsValidHero(D)
			and c.IsInRange(b, D, O)
			and c.CanBeAttacked(D)
			and c.CanCastOnNonMagicImmune(D)
			and not D:HasModifier("modifier_necrolyte_reapers_scythe")
			and Q > R
		then
			return BOT_ACTION_DESIRE_HIGH, D
		end
	end
	if I and not c.IsRealInvisible(b) then
		if c.IsValidHero(G[1]) and c.IsInRange(b, G[1], O) then
			if K or not c.IsInLaningPhase() then
				return BOT_ACTION_DESIRE_HIGH, G[1]
			end
			if
				c.CanCastOnNonMagicImmune(G[1])
				and c.CanCastOnTargetAdvanced(G[1])
				and b:WasRecentlyDamagedByHero(G[1], 3.0)
			then
				if c.IsChasingTarget(G[1], b) or #G > #F and G[1]:GetAttackTarget() == b then
					return BOT_ACTION_DESIRE_HIGH, G[1]
				end
			end
		end
		for M, S in pairs(F) do
			if
				b ~= S
				and c.IsValidHero(S)
				and c.IsRetreating(S)
				and S:WasRecentlyDamagedByAnyHero(3.0)
				and not c.IsSuspiciousIllusion(S)
				and not c.IsRealInvisible(S)
				and not c.IsRealInvisible(b)
			then
				for M, N in ipairs(G) do
					if
						c.IsValidHero(N)
						and c.IsInRange(b, N, O)
						and c.CanCastOnNonMagicImmune(N)
						and c.CanCastOnTargetAdvanced(N)
						and c.IsChasingTarget(N, S)
						and not c.IsDisabled(N)
					then
						return BOT_ACTION_DESIRE_HIGH, N
					end
				end
			end
		end
	end
	if c.IsDoingRoshan(b) then
		if
			c.IsRoshan(D)
			and c.CanBeAttacked(D)
			and c.CanCastOnMagicImmune(D)
			and c.IsInRange(b, D, O)
			and Q > 0.4
			and Q > R
			and C
		then
			return BOT_ACTION_DESIRE_HIGH, D
		end
	end
	if c.IsDoingTormentor(b) then
		if c.IsTormentor(D) and c.CanCastOnMagicImmune(D) and c.IsInRange(b, D, O) and Q > 0.4 and Q > R and C then
			return BOT_ACTION_DESIRE_HIGH, D
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
-- Enemy lane creeps in range that one spray kills. Damage is base plus 30 per quill stack
-- already on the creep (capped at max_damage), physical, so armor applies.
function a.QuillLaneKills(radius)
	local base = q:GetSpecialValueInt("quill_base_damage")
	if base == nil or base <= 0 then
		return 0
	end
	local perStack = q:GetSpecialValueInt("quill_stack_damage") or 0
	local maxDamage = q:GetSpecialValueInt("max_damage") or 0
	local kills = 0
	for M, N in pairs(b:GetNearbyLaneCreeps(radius, true) or {}) do
		if c.IsValid(N) and c.CanBeAttacked(N) then
			local stacks = c.GetModifierCount(N, "modifier_bristleback_quill_spray") or 0
			local raw = base + perStack * stacks
			if maxDamage > 0 then
				raw = math.min(raw, maxDamage)
			end
			if N:GetHealth() <= N:GetActualIncomingDamage(raw, DAMAGE_TYPE_PHYSICAL) then
				kills = kills + 1
			end
		end
	end
	return kills
end
-- [OHA-QUILL]: each Quill Spray cast with why, at most once per 10s per reason.
function a.LogQuill(why, kills, heroes, mana)
	b._quillLogAt = b._quillLogAt or {}
	if DotaTime() < (b._quillLogAt[why] or -999) then
		return
	end
	b._quillLogAt[why] = DotaTime() + 10
	pcall(print, string.format(
		"[OHA-QUILL] t=%.0f %s %s kills=%d heroes=%d mana=%.2f",
		DotaTime(),
		(string.gsub(b:GetUnitName(), "npc_dota_hero_", "")),
		why,
		kills,
		heroes,
		mana
	))
end
function a.ConsiderQuillSpray()
	if not c.CanCastAbility(q) then
		return BOT_ACTION_DESIRE_NONE
	end
	if q:GetAutoCastState() == true then
		q:ToggleAutoCast()
	end
	local T = q:GetSpecialValueInt("radius")
	local Q = c.GetManaAfter(q:GetManaCost())
	if K then
		if c.IsValidHero(G[1]) then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if H then
		if
			c.IsValidHero(D)
			and c.IsInRange(b, D, T - 100)
			and c.CanBeAttacked(D)
			and c.CanCastOnMagicImmune(D)
			and not D:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if I and not c.IsRealInvisible(b) then
		for M, N in pairs(G) do
			if
				c.IsValidHero(N)
				and c.CanBeAttacked(N)
				and c.IsInRange(b, N, T)
				and (b:WasRecentlyDamagedByHero(N, 4.0) or N:HasModifier("modifier_bristleback_quill_spray"))
			then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	local foesInRange = 0
	for M, N in pairs(b:GetNearbyHeroes(T - 50, true, BOT_MODE_NONE) or {}) do
		if c.IsValidHero(N) and c.CanBeAttacked(N) and not c.IsSuspiciousIllusion(N) then
			foesInRange = foesInRange + 1
		end
	end
	-- Engaging: any enemy hero inside the spray, not only the chosen target.
	if H and foesInRange >= 1 then
		a.LogQuill("engage", 0, foesInRange, Q)
		return BOT_ACTION_DESIRE_HIGH
	end
	-- Lane: 35 mana on a 3s cooldown. Finish creeps the quills will kill, and poke a laner
	-- in range; a spell on a hero does not pull creep aggro the way a right-click does.
	if c.IsInLaningPhase() and Q > 0.3 then
		local kills = a.QuillLaneKills(T - 50)
		if kills >= 2 or kills >= 1 and foesInRange >= 1 then
			a.LogQuill("lane-lasthit", kills, foesInRange, Q)
			return BOT_ACTION_DESIRE_HIGH
		end
		if foesInRange >= 1 and Q > 0.5 then
			a.LogQuill("lane-poke", kills, foesInRange, Q)
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	local U = b:GetNearbyCreeps(T, true)
	if c.IsPushing(b) or c.IsDefending(b) or H or c.IsFarming(b) then
		if c.CanBeAttacked(U[1]) and Q > 0.25 then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if c.IsFarming(b) and Q > 0.25 then
		if c.IsValid(D) and c.CanBeAttacked(D) and D:IsCreep() then
			if D:GetHealth() > b:GetAttackDamage() * 3 then
				return BOT_ACTION_DESIRE_HIGH
			end
			if c.IsValid(U[1]) and c.CanBeAttacked(U[1]) and #U >= 2 then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	if c.IsDoingRoshan(b) and C then
		if c.IsRoshan(D) and c.CanBeAttacked(D) and c.CanCastOnMagicImmune(D) and c.IsInRange(b, D, T) then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if c.IsDoingTormentor(b) and C then
		if c.IsTormentor(D) and c.IsInRange(b, D, T) then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Q > 0.9 and not c.IsInLaningPhase() and b:DistanceFromFountain() > 2400 then
		return BOT_ACTION_DESIRE_HIGH
	end
	return BOT_ACTION_DESIRE_NONE
end
function a.ConsiderBristleback()
	if not c.CanCastAbility(r) then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local T = 350
	local P = r:GetManaCost()
	local Q = c.GetManaAfter(P)
	local R = c.GetManaThreshold(b, P, { r, s })
	if H then
		if
			c.IsValidHero(D)
			and c.CanBeAttacked(D)
			and c.IsInRange(b, D, T)
			and not D:HasModifier("modifier_necrolyte_reapers_scythe")
			and (c.IsDisabled(D) or D:GetCurrentMovementSpeed() <= 250 or not c.IsMoving(D))
		then
			return BOT_ACTION_DESIRE_HIGH, D:GetLocation()
		end
	end
	if I and not c.IsRealInvisible(b) and b:WasRecentlyDamagedByAnyHero(3.0) then
		for M, N in ipairs(G) do
			if
				c.IsValidHero(N)
				and c.CanBeAttacked(N)
				and c.IsInRange(b, N, T)
				and not N:HasModifier("modifier_abaddon_borrowed_time")
				and not N:HasModifier("modifier_dazzle_shallow_grave")
				and not N:HasModifier("modifier_necrolyte_reapers_scythe")
				and N:GetAttackTarget() == b
			then
				local V = c.GetAlliesNearLoc(b:GetLocation(), 1200)
				local W = c.GetEnemiesNearLoc(b:GetLocation(), 1200)
				if not (#W >= #V + 2) then
					return BOT_ACTION_DESIRE_HIGH, N:GetLocation()
				end
			end
		end
	end
	local U = b:GetNearbyCreeps(800, true)
	if (c.IsPushing(b) or c.IsDefending(b)) and Q > R + 0.1 and C and #G == 0 then
		for M, X in pairs(U) do
			if c.IsValid(X) and c.CanBeAttacked(X) and not c.IsRunning(X) then
				local Y = b:FindAoELocation(true, false, X:GetLocation(), 0, T, 0, 0)
				if Y.count >= 4 or Y.count >= 1 and X:GetHealth() >= 1000 then
					return BOT_ACTION_DESIRE_HIGH, Y.targetloc
				end
			end
		end
	end
	if c.IsFarming(b) and Q > R and C then
		for M, X in pairs(U) do
			if c.IsValid(X) and c.CanBeAttacked(X) and not c.IsRunning(X) then
				local Y = b:FindAoELocation(true, false, X:GetLocation(), 0, T, 0, 0)
				if Y.count >= 5 or Y.count >= 2 and X:IsAncientCreep() then
					return BOT_ACTION_DESIRE_HIGH, Y.targetloc
				end
			end
		end
	end
	if c.IsDoingRoshan(b) then
		if c.IsRoshan(D) and c.CanBeAttacked(D) and c.IsInRange(b, D, T * 2) and Q > R and C then
			return BOT_ACTION_DESIRE_HIGH, D:GetLocation()
		end
	end
	if c.IsDoingTormentor(b) then
		if c.IsTormentor(D) and c.IsInRange(b, D, T * 2) and Q > R and C then
			return BOT_ACTION_DESIRE_HIGH, D:GetLocation()
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function a.ConsiderHairball()
	if not c.CanCastAbility(s) then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local O = c.GetProperCastRange(false, b, s:GetCastRange())
	local T = s:GetSpecialValueInt("radius")
	local P = s:GetManaCost()
	local Q = c.GetManaAfter(P)
	local R = c.GetManaThreshold(b, P, { r })
	if c.IsInTeamFight(b, 1400) then
		local Z = c.GetAoeEnemyHeroLocation(b, O, T, 2)
		if Z ~= nil and Q > R then
			return BOT_ACTION_DESIRE_HIGH, Z
		end
	end
	if H then
		if
			c.IsValidHero(D)
			and c.CanBeAttacked(D)
			and c.IsInRange(b, D, O)
			and c.CanCastOnNonMagicImmune(D)
			and not D:HasModifier("modifier_necrolyte_reapers_scythe")
			and Q > R
		then
			return BOT_ACTION_DESIRE_HIGH, D:GetLocation()
		end
	end
	if I and not c.IsRealInvisible(b) and b:WasRecentlyDamagedByAnyHero(3.0) then
		for M, N in ipairs(G) do
			if
				c.IsValidHero(N)
				and c.CanBeAttacked(N)
				and c.CanCastOnNonMagicImmune(N)
				and c.IsInRange(b, N, O)
				and not N:HasModifier("modifier_necrolyte_reapers_scythe")
			then
				if c.IsChasingTarget(N, b) or #G > #F and N:GetAttackTarget() == b then
					return BOT_ACTION_DESIRE_HIGH, (b:GetLocation() + N:GetLocation()) / 2
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function a.ConsiderWarpath()
	if not c.CanCastAbility(t) then
		return BOT_ACTION_DESIRE_NONE
	end
	local V = c.GetEnemiesNearLoc(b:GetLocation(), 1200)
	local W = c.GetEnemiesNearLoc(b:GetLocation(), 800)
	if K then
		if #W > #V or E < 0.5 and b:WasRecentlyDamagedByAnyHero(4.0) then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if I and not c.IsRealInvisible(b) then
		for M, N in pairs(G) do
			if c.IsValidHero(N) and c.IsInRange(b, N, 500) and c.IsChasingTarget(N, b) then
				if c.GetTotalEstimatedDamageToTarget(G, b, 8.0) > b:GetHealth() * 1.15 or #G > #F and E < 0.4 then
					return BOT_ACTION_DESIRE_HIGH
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
return a
