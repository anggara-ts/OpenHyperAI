-- Undying: skill build, item build, and ability use for this hero.
local a = {}
local b = GetBot()
local c = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local d = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local e = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local f = c.Skill.GetTalentList(b)
local g = c.Skill.GetAbilityList(b)
local h = c.Item.GetRoleItemsBuyList(b)
local i = { ["t25"] = { 10, 0 }, ["t20"] = { 0, 10 }, ["t15"] = { 10, 0 }, ["t10"] = { 0, 10 } }
local j = { { 1, 3, 1, 3, 1, 6, 1, 3, 3, 2, 6, 2, 2, 2, 6 } }
local k = c.Skill.GetRandomBuild(j)
local l = c.Skill.GetTalentBuild(i)
local n = "item_team_aura"
local o = {}
-- One pair of boots in this build (user rule; Util/boots-check.js).
-- No Boots of Travel: this build's Guardian Greaves / Boots of Bearing are its one pair of boots.
o["pos_4"] = {
	"item_blood_grenade",
	"item_tango",
	"item_double_branches",
	"item_magic_wand",
	"item_arcane_boots",
	"item_essence_distiller",
	"item_crimson_guard",
	"item_guardian_greaves",
	"item_aghanims_shard",
	"item_blade_mail",
	"item_lotus_orb",
	"item_assault",
	"item_ultimate_scepter_2",
	"item_moon_shard",
}
o["pos_5"] = {
	"item_blood_grenade",
	"item_mage_outfit",
	"item_ancient_janggo",
	"item_glimmer_cape",
	"item_boots_of_bearing",
	"item_pipe",
	"item_aghanims_shard",
	"item_ultimate_scepter",
	"item_cyclone",
	"item_lotus_orb",
	"item_shivas_guard",
	"item_sheepstick",
	"item_moon_shard",
	"item_ultimate_scepter_2",
}
o["pos_1"] = {
	"item_bristleback_outfit",
	"item_aghanims_shard",
	"item_blade_mail",
	"item_heavens_halberd",
	"item_lotus_orb",
	"item_black_king_bar",
	"item_ultimate_scepter",
	"item_travel_boots",
	"item_ultimate_scepter_2",
	"item_heart",
	"item_moon_shard",
	"item_travel_boots_2",
}
o["pos_2"] = o["pos_1"]
o["pos_3"] = {
	"item_tank_outfit",
	"item_blade_mail",
	"item_crimson_guard",
	"item_aghanims_shard",
	"item_ultimate_scepter",
	"item_lotus_orb",
	"item_heavens_halberd",
	"item_sheepstick",
	"item_octarine_core",
	"item_travel_boots",
	"item_moon_shard",
	"item_travel_boots_2",
	"item_ultimate_scepter_2",
}
a["sBuyList"] = o[h]
a["sSellList"] = { "item_power_treads", "item_quelling_blade" }
if c.Role.IsPvNMode() or c.Role.IsAllShadow() then
	a["sBuyList"], a["sSellList"] = { "PvN_antimage" }, {}
end
k, l, a["sBuyList"], a["sSellList"] = c.SetUserHeroInit(k, l, a["sBuyList"], a["sSellList"])
a["sSkillList"] = c.Skill.GetSkillList(g, k, f, l)
a["bDeafaultAbility"] = false
a["bDeafaultItem"] = false
function a.MinionThink(p)
	e.MinionThink(p)
end
local q = SafeAbility(b:GetAbilityByName("undying_decay"), "undying_decay", "undying")
local r = SafeAbility(b:GetAbilityByName("undying_soul_rip"), "undying_soul_rip", "undying")
local s = SafeAbility(b:GetAbilityByName("undying_tombstone"), "undying_tombstone", "undying")
local t = SafeAbility(b:GetAbilityByName("undying_flesh_golem"), "undying_flesh_golem", "undying")
local u, v
local w, x
local y, z
local A
local B
local C
local D
local E
local F
function a.SkillsComplement()
	if c.CanNotUseAbility(b) then
		return
	end
	local G = d.Build(b)
	C = c.IsAttacking(b)
	D = G.hp
	E = G.mp
	F = G.isTeamFight
	B = G.target
	A = a.ConsiderFleshGolem()
	if A > 0 then
		b:Action_UseAbility(t)
		return
	end
	y, z = a.ConsiderTombstone()
	if y > 0 then
		b:Action_UseAbilityOnLocation(s, z)
		return
	end
	u, v = a.ConsiderDecay()
	if u > 0 then
		b:Action_UseAbilityOnLocation(q, v)
		return
	end
	w, x = a.ConsiderSoulRip()
	if w > 0 then
		b:Action_UseAbilityOnEntity(r, x)
		return
	end
end
function a.ConsiderDecay()
	if not q:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local H = c.GetProperCastRange(false, b, q:GetCastRange())
	local I = q:GetSpecialValueInt("radius")
	local J = q:GetSpecialValueInt("decay_damage")
	local K = q:GetLevel()
	local L = c.GetNearbyHeroes(b, H + I, true, BOT_MODE_NONE)
	for M, N in pairs(L) do
		if
			c.IsValidHero(N)
			and c.CanCastOnNonMagicImmune(N)
			and c.CanKillTarget(N, J, DAMAGE_TYPE_MAGICAL)
			and not c.IsSuspiciousIllusion(N)
			and not N:HasModifier("modifier_abaddon_borrowed_time")
			and not N:HasModifier("modifier_dazzle_shallow_grave")
			and not N:HasModifier("modifier_necrolyte_reapers_scythe")
			and not N:HasModifier("modifier_oracle_false_promise_timer")
		then
			local O = c.GetEnemiesNearLoc(N:GetLocation(), I)
			if O ~= nil and #O >= 1 then
				if not c.IsInRange(b, N, H) then
					return BOT_ACTION_DESIRE_HIGH, c.Site.GetXUnitsTowardsLocation(b, c.GetCenterOfUnits(O), H)
				else
					return BOT_ACTION_DESIRE_HIGH, c.GetCenterOfUnits(O)
				end
			end
			if not c.IsInRange(b, N, H) then
				return BOT_ACTION_DESIRE_HIGH, c.Site.GetXUnitsTowardsLocation(b, N:GetLocation(), H)
			else
				return BOT_ACTION_DESIRE_HIGH, N:GetLocation()
			end
		end
	end
	if F then
		local P = b:FindAoELocation(true, true, b:GetLocation(), H + I, I, 0, 0)
		local O = c.GetEnemiesNearLoc(P.targetloc, I)
		if O ~= nil and #O >= 2 then
			return BOT_ACTION_DESIRE_HIGH, c.Site.GetXUnitsTowardsLocation(b, P.targetloc, H)
		end
	end
	if c.IsGoingOnSomeone(b) then
		local O = c.GetNearbyHeroes(b, H + I, true, BOT_MODE_NONE)
		for M, N in pairs(O) do
			if c.IsValidHero(N) and c.CanCastOnNonMagicImmune(N) and not c.IsSuspiciousIllusion(N) then
				local Q = c.GetNearbyHeroes(N, 1200, true, BOT_MODE_NONE)
				local R = c.GetNearbyHeroes(N, 1200, false, BOT_MODE_NONE)
				if Q ~= nil and R ~= nil and #Q >= #R then
					O = c.GetEnemiesNearLoc(N:GetLocation(), I)
					if O ~= nil and #O >= 1 then
						if not c.IsInRange(b, N, H) then
							return BOT_ACTION_DESIRE_HIGH, c.Site.GetXUnitsTowardsLocation(b, c.GetCenterOfUnits(O), H)
						else
							return BOT_ACTION_DESIRE_HIGH, c.GetCenterOfUnits(O)
						end
					end
					if not c.IsInRange(b, N, H) then
						return BOT_ACTION_DESIRE_HIGH, c.Site.GetXUnitsTowardsLocation(b, N:GetLocation(), H)
					else
						return BOT_ACTION_DESIRE_HIGH, N:GetLocation()
					end
				end
			end
		end
	end
	if c.IsPushing(b) or c.IsDefending(b) then
		local S = b:GetNearbyLaneCreeps(H + I, true)
		if S ~= nil and #S >= 4 and K >= 3 and E > 0.6 then
			return BOT_ACTION_DESIRE_HIGH, c.GetCenterOfUnits(S)
		end
	end
	if c.IsLaning(b) then
		local O = c.GetNearbyHeroes(b, 1600, true, BOT_MODE_NONE)
		local S = b:GetNearbyLaneCreeps(H + I, true)
		if
			O ~= nil
			and #O == 0
			and S ~= nil
			and #S >= 4
			and C
			and E > 0.5
			and K >= 3
			and not c.IsThereNonSelfCoreNearby(1200)
		then
			return BOT_ACTION_DESIRE_HIGH, c.GetCenterOfUnits(S)
		end
		local P = b:FindAoELocation(true, true, b:GetLocation(), H + I, I, 0, 0)
		O = c.GetEnemiesNearLoc(P.targetloc, I)
		if O ~= nil and #O >= 2 and c.IsInLaningPhase() and K >= 2 then
			if GetUnitToLocationDistance(b, c.GetCenterOfUnits(O)) > H then
				return BOT_ACTION_DESIRE_HIGH, c.Site.GetXUnitsTowardsLocation(b, c.GetCenterOfUnits(O), H)
			else
				return BOT_ACTION_DESIRE_HIGH, c.GetCenterOfUnits(O)
			end
		end
	end
	if c.IsDoingRoshan(b) then
		if c.IsRoshan(B) and c.CanCastOnNonMagicImmune(B) and c.IsInRange(b, B, 500) and C and K >= 3 then
			return BOT_ACTION_DESIRE_HIGH, B:GetLocation()
		end
	end
	if c.IsDoingTormentor(b) then
		if c.IsTormentor(B) and c.IsInRange(b, B, 500) and C and K >= 3 then
			return BOT_ACTION_DESIRE_HIGH, B:GetLocation()
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function a.ConsiderSoulRip()
	if not r:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local H = c.GetProperCastRange(false, b, r:GetCastRange())
	local I = r:GetSpecialValueInt("radius")
	local J = r:GetSpecialValueInt("damage_per_unit")
	local L = c.GetNearbyHeroes(b, I, true, BOT_MODE_NONE)
	for M, N in pairs(L) do
		if
			c.IsValidHero(N)
			and c.CanCastOnNonMagicImmune(N)
			and not c.IsSuspiciousIllusion(N)
			and not N:HasModifier("modifier_abaddon_borrowed_time")
			and not N:HasModifier("modifier_dazzle_shallow_grave")
			and not N:HasModifier("modifier_necrolyte_reapers_scythe")
			and not N:HasModifier("modifier_oracle_false_promise_timer")
		then
			local O = c.GetEnemiesNearLoc(b:GetLocation(), I)
			local T = b:GetNearbyCreeps(I, true)
			-- datafeed: damage_per_unit for each unit, up to max_units. It multiplied heroes by
			-- creeps (and kept growing J across the loop), and then returned Undying himself, so
			-- the "kill" cast healed him. Aim it at the enemy, within cast range.
			local units = (O ~= nil and #O or 0) + (T ~= nil and #T or 0)
			local maxUnits = r:GetSpecialValueInt("max_units")
			if maxUnits ~= nil and maxUnits > 0 then
				units = math.min(units, maxUnits)
			end
			if c.IsInRange(b, N, H) and c.CanKillTarget(N, J * units, DAMAGE_TYPE_MAGICAL) then
				return BOT_ACTION_DESIRE_HIGH, N
			end
		end
	end
	-- Save heal (new): an ally other than Undying under hero attack below 40% HP. Before this the
	-- heal went to allies only while Undying was engaging, or with 4+ enemy creeps around, so a
	-- dove lane partner got nothing. datafeed: damage_per_unit per unit within radius (1300), up to
	-- max_units; note "Does rip from spell immune allies", so allied creeps are counted (that they
	-- add to the heal is not verified in a game). Logged: [OHA-UNDYING] save-rip.
	do
		local units = #(c.GetNearbyHeroes(b, I, true, BOT_MODE_NONE) or {})
			+ #(b:GetNearbyCreeps(I, true) or {})
			+ #(b:GetNearbyCreeps(I, false) or {})
		local maxUnits = r:GetSpecialValueInt("max_units")
		if maxUnits ~= nil and maxUnits > 0 then
			units = math.min(units, maxUnits)
		end
		local save, saveHP = nil, 0.4
		if units >= 2 then
			for M, W in pairs(c.GetNearbyHeroes(b, H, false, BOT_MODE_NONE) or {}) do
				if
					W ~= b
					and c.IsValidHero(W)
					and not W:IsIllusion()
					and not c.IsMeepoClone(W)
					and c.GetHP(W) < saveHP
					and W:WasRecentlyDamagedByAnyHero(2)
				then
					save, saveHP = W, c.GetHP(W)
				end
			end
		end
		if save ~= nil then
			if DotaTime() >= (b._undyingSaveLogAt or -999) then
				b._undyingSaveLogAt = DotaTime() + 5
				pcall(print, string.format(
					"[OHA-UNDYING] t=%.0f save-rip ally=%s hp=%.2f units=%d heal=%d",
					DotaTime(),
					(string.gsub(save:GetUnitName(), "npc_dota_hero_", "")),
					saveHP,
					units,
					J * units
				))
			end
			return BOT_ACTION_DESIRE_HIGH, save
		end
	end
	if c.IsGoingOnSomeone(b, 1200) then
		local U = nil
		local V = math.huge -- was 1000 (absolute HP): no ally above 1000 HP was ever healed
		local Q = c.GetNearbyHeroes(b, H, false, BOT_MODE_NONE)
		for M, W in pairs(Q) do
			if c.IsValidHero(W) and not c.IsSuspiciousIllusion(W) then
				local X = c.GetNearbyHeroes(b, I, true, BOT_MODE_NONE)
				local Y = b:GetNearbyCreeps(I, true)
				local Z = W:GetHealth()
				if Z < V and c.GetHP(W) < 0.75 and (X ~= nil and #X >= 1 or Y ~= nil and #Y >= 2) then
					V = Z
					U = W
				end
			end
		end
		if U ~= nil then
			return BOT_ACTION_DESIRE_MODERATE, U
		end
	end
	if c.IsRetreating(b) then
		local O = c.GetNearbyHeroes(b, I, true, BOT_MODE_NONE)
		for M, N in pairs(O) do
			if
				c.IsValidHero(N)
				and c.CanCastOnNonMagicImmune(N)
				and c.IsChasingTarget(N, b)
				and not c.IsSuspiciousIllusion(N)
			then
				local Q = c.GetNearbyHeroes(N, 1200, true, BOT_MODE_NONE)
				local R = c.GetNearbyHeroes(N, 1200, false, BOT_MODE_NONE)
				if Q ~= nil and R ~= nil and (#R > #Q or b:WasRecentlyDamagedByAnyHero(1.5) or D < 0.5) then
					return BOT_ACTION_DESIRE_HIGH, b
				end
			end
		end
		local T = b:GetNearbyCreeps(I, true)
		if T ~= nil and #T >= 4 and D < 0.6 then
			return BOT_ACTION_DESIRE_HIGH, b
		end
	end
	if c.IsPushing(b) then
		local S = b:GetNearbyLaneCreeps(I, true)
		if S ~= nil and #S >= 4 and E > 0.7 and D < 0.6 then
			return BOT_ACTION_DESIRE_HIGH, b
		end
	end
	if c.IsLaning(b) then
		local S = b:GetNearbyLaneCreeps(I, true)
		if S ~= nil and #S >= 3 and C and E > 0.5 and D < 0.6 then
			return BOT_ACTION_DESIRE_HIGH, b
		end
	end
	if c.IsDoingRoshan(b) or c.IsDoingTormentor(b) then
		if (c.IsRoshan(B) or c.IsTormentor(B)) and c.IsInRange(b, B, I) and C then
			local U = nil
			local V = math.huge -- was 1000 (absolute HP): no ally above 1000 HP was ever healed
			local Q = c.GetNearbyHeroes(b, H, false, BOT_MODE_NONE)
			for M, W in pairs(Q) do
				if c.IsValidHero(W) and not c.IsSuspiciousIllusion(W) then
					local Z = W:GetHealth()
					if Z < V and c.GetHP(W) < 0.75 then
						V = Z
						U = W
					end
				end
			end
			if U ~= nil then
				return BOT_ACTION_DESIRE_MODERATE, U
			end
		end
	end
	local U = nil
	local V = math.huge -- was 1000 (absolute HP): no ally above 1000 HP was ever healed
	local Q = c.GetNearbyHeroes(b, H, false, BOT_MODE_NONE)
	for M, W in pairs(Q) do
		if c.IsValidHero(W) and not c.IsSuspiciousIllusion(W) then
			local Y = b:GetNearbyCreeps(I, true)
			local Z = W:GetHealth()
			if Z < V and c.GetHP(W) < 0.75 and E > 0.35 and Y ~= nil and #Y >= 4 then
				V = Z
				U = W
			end
		end
	end
	if U ~= nil then
		return BOT_ACTION_DESIRE_MODERATE, U
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function a.ConsiderTombstone()
	if not s:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local H = c.GetProperCastRange(false, b, s:GetCastRange())
	local I = s:GetSpecialValueInt("radius")
	if F then
		local P = b:FindAoELocation(true, true, b:GetLocation(), H, I, 0, 0)
		local O = c.GetEnemiesNearLoc(P.targetloc, I / 2)
		if O ~= nil and #O >= 2 then
			local _ = c.GetCenterOfUnits(O)
			if c.IsLocationInChrono(_) or c.IsLocationInBlackHole(_) or c.IsLocationInArena(_, I / 2) then
				return BOT_ACTION_DESIRE_HIGH, b:GetLocation()
			end
			-- datafeed: zombies spawn by every enemy within radius (1200) of the Tombstone, cast range
			-- 500. Aiming at the enemies' centre made Undying walk into them to plant it; plant it
			-- toward them, no farther than the cast range, so it stays out of their reach.
			local castRange = s:GetCastRange()
			local dist = GetUnitToLocationDistance(b, _)
			if dist > castRange then
				return BOT_ACTION_DESIRE_HIGH, c.Site.GetXUnitsTowardsLocation(b, _, castRange)
			end
			return BOT_ACTION_DESIRE_HIGH, _
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function a.ConsiderFleshGolem()
	if not t:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
	end
	if F then
		local O = c.GetEnemiesNearLoc(b:GetLocation(), 1200)
		if O ~= nil and #O >= 2 then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
return a
