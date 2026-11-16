-- [OHA-DOOM] logs off: the behaviour they traced works (game 029).
local print = function() end
-- Doom Bringer: skill build, item build, and ability use for this hero.
local a = {}
local b = GetBot()
local c = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local d = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local e = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local f = c.Skill.GetTalentList(b)
local g = c.Skill.GetAbilityList(b)
local h = c.Item.GetRoleItemsBuyList(b)
local i = {
	{ ["t25"] = { 0, 10 }, ["t20"] = { 0, 10 }, ["t15"] = { 0, 10 }, ["t10"] = { 10, 0 } },
	{ ["t25"] = { 0, 10 }, ["t20"] = { 0, 10 }, ["t15"] = { 0, 10 }, ["t10"] = { 10, 0 } },
}
local j = { { 1, 2, 1, 2, 1, 6, 2, 2, 1, 3, 6, 3, 3, 3, 6 }, { 2, 1, 2, 3, 2, 6, 2, 1, 1, 1, 6, 3, 3, 3, 6 } }
local k
local l
if h == "pos_2" then
	k = j[1]
	l = c.Skill.GetTalentBuild(i[1])
else
	k = j[2]
	l = c.Skill.GetTalentBuild(i[2])
end
local n = "item_team_aura"
local o = {}
o["pos_2"] = {
	"item_tango",
	"item_double_branches",
	"item_quelling_blade",
	"item_magic_stick",
	"item_bottle",
	"item_magic_wand",
	"item_helm_of_iron_will",
	"item_boots",
	"item_phase_boots",
	"item_shivas_guard",
	"item_blink",
	"item_black_king_bar",
	"item_octarine_core",
	"item_travel_boots",
	"item_aghanims_shard",
	"item_overwhelming_blink",
	"item_refresher",
	"item_travel_boots_2",
	"item_ultimate_scepter_2",
	"item_moon_shard",
}
o["pos_3"] = {
	"item_tango",
	"item_double_branches",
	"item_quelling_blade",
	"item_magic_stick",
	"item_enchanted_mango",
	"item_magic_wand",
	"item_helm_of_iron_will",
	"item_boots",
	"item_phase_boots",
	"item_shivas_guard",
	"item_blink",
	"item_black_king_bar",
	"item_octarine_core",
	n,
	"item_aghanims_shard",
	"item_overwhelming_blink",
	"item_ultimate_scepter",
	"item_ultimate_scepter_2",
	"item_moon_shard",
}
o["pos_1"] = o["pos_3"]
o["pos_4"] = o["pos_3"]
o["pos_5"] = o["pos_3"]
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
local q = SafeAbility(b:GetAbilityByName("doom_bringer_devour"), "doom_bringer_devour", "doom_bringer")
local r = SafeAbility(b:GetAbilityByName("doom_bringer_scorched_earth"), "doom_bringer_scorched_earth", "doom_bringer")
local s = SafeAbility(b:GetAbilityByName("doom_bringer_infernal_blade"), "doom_bringer_infernal_blade", "doom_bringer")
local t = SafeAbility(b:GetAbilityByName("doom_bringer_doom"), "doom_bringer_doom", "doom_bringer")
local u = SafeAbility(b:GetAbilityByName("doom_bringer_empty1"), "doom_bringer_empty1", "doom_bringer")
local v = SafeAbility(b:GetAbilityByName("doom_bringer_empty2"), "doom_bringer_empty2", "doom_bringer")
-- datafeed: special_bonus_unique_doom_2 is no longer a Doom talent (Ancient Devour moved to the Shard)
local x, y
local z
local A, B
local C, D
local E, F
local G, H
local I
local J
local K
local L
function a.SkillsComplement()
	if c.CanNotUseAbility(b) then
		return
	end
	local M = d.Build(b)
	J = M.isEngaging
	K = M.isRetreating
	L = c.IsAttacking(b)
	I = M.target
	C, D = a.ConsiderDoom()
	if C > 0 then
		b:Action_UseAbilityOnEntity(t, D)
		return
	end
	A, B = a.ConsiderInfernalBlade()
	if A > 0 then
		b:Action_UseAbilityOnEntity(s, B)
		return
	end
	-- Abilities taken with Devour. ConsiderDevourAbility existed but was never called, so stolen
	-- creep skills went unused. The slots change after each Devour, so look them up by name.
	for slot = 0, 10 do
		local stolen = b:GetAbilityInSlot(slot)
		if stolen ~= nil and not stolen:IsNull() and a.IsStolenAbility(stolen) then
			local want, target, kind
			if DEVOUR_ABILITIES[stolen:GetName()] then
				want, target, kind = a.ConsiderDevourAbility(stolen)
			else
				want, target, kind = a.ConsiderGenericDevourAbility(stolen)
			end
			if want ~= nil and want > 0 then
				if kind == "unit" and target ~= nil then
					b:Action_UseAbilityOnEntity(stolen, target)
				elseif kind == "point" and target ~= nil then
					b:Action_UseAbilityOnLocation(stolen, target:GetLocation())
				else
					b:Action_UseAbility(stolen)
				end
				return
			end
		end
	end
	local scorchWhy
	z, scorchWhy = a.ConsiderScorchedEarth()
	if z > 0 then
		pcall(print, string.format(
			"[OHA-DOOM] t=%.0f scorched why=%s hp=%.2f",
			DotaTime(),
			tostring(scorchWhy or "?"),
			c.GetHP(b)
		))
		b:Action_UseAbility(r)
		return
	end
	x, y = a.ConsiderDevour()
	if x > 0 then
		b:Action_UseAbilityOnEntity(q, y)
		return
	end
end
function a.ConsiderDevour()
	if not q:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local N = q:GetSpecialValueInt("creep_level")
	local O = b:GetNearbyCreeps(1200, true)
	if not K then
		local P = b:GetNearbyTowers(1600, true)
		local Q = a.GetRangedOrSiegeCreep(O, N)
		if Q ~= nil then
			if
				c.IsLaning(b)
				and P ~= nil
				and (#P == 0 or #P >= 1 and c.IsValidBuilding(P[1]) and GetUnitToUnitDistance(Q, P[1]) > 700)
			then
				return BOT_ACTION_DESIRE_HIGH, Q
			end
		end
		for R, S in pairs(O) do
			if
				c.IsValid(S)
				and c.CanBeAttacked(S)
				and S:GetLevel() <= N
				and not c.IsRoshan(S)
				and not c.IsTormentor(S)
			then
				if
					c.IsInLaningPhase()
					and S:GetTeam() ~= b:GetTeam()
					and S:GetTeam() ~= TEAM_NEUTRAL
					and P ~= nil
					and (#P == 0 or #P >= 1 and c.IsValidBuilding(P[1]) and GetUnitToUnitDistance(S, P[1]) > 700)
				then
					return BOT_ACTION_DESIRE_HIGH, S
				end
				Q = nil
				if S and S:GetTeam() == TEAM_NEUTRAL then
					Q = c.GetMostHpUnit(O)
				end
				if Q ~= nil then
					-- datafeed: Devouring Ancients now comes from Aghanim's Shard (can_target_ancient), not
					-- special_bonus_unique_doom_2, which is no longer one of Doom's talents
					if
						Q:IsAncientCreep()
						and (q:GetSpecialValueInt("can_target_ancient") > 0 or c.HasAghanimsShard(b))
					then
						return BOT_ACTION_DESIRE_HIGH, Q
					end
					if not Q:IsAncientCreep() then
						return BOT_ACTION_DESIRE_HIGH, Q
					end
				end
				if not S:IsAncientCreep() then
					return BOT_ACTION_DESIRE_HIGH, S
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function a.ConsiderScorchedEarth()
	if not r:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
	end
	-- Valve data: 666 radius damage to enemies; Doom alone gets +7-10% move speed and +6.66 HP
	-- regen, for 10-16s. So it is both a chase and an escape spell.
	local T = r:GetSpecialValueInt("radius")
	if J then
		if
			c.IsValidTarget(I)
			and c.CanCastOnNonMagicImmune(I)
			and not c.IsSuspiciousIllusion(I)
			and not I:HasModifier("modifier_necrolyte_reapers_scythe")
			and not I:HasModifier("modifier_skeleton_king_reincarnation_scepter_active")
		then
			local U = c.GetNearbyHeroes(I, 1200, true, BOT_MODE_NONE)
			local V = c.GetNearbyHeroes(I, 1200, false, BOT_MODE_NONE)
			if U ~= nil and V ~= nil and #U >= #V then
				-- In the burn: damage. Up to 1200 and running from him: the speed closes the gap
				-- (it used to need the target inside 816).
				if c.IsInRange(b, I, T + 150) then
					return BOT_ACTION_DESIRE_HIGH, "chase-burn"
				end
				if c.IsInRange(b, I, 1200) and c.IsChasingTarget(b, I) then
					return BOT_ACTION_DESIRE_HIGH, "chase-speed"
				end
			end
		end
	end
	-- Escape: speed and regen. Any enemy hero chasing within 1200, or hit by a hero in the last
	-- 3s. It used to need retreat desire 0.75+, the chaser inside 866, and either being
	-- outnumbered by 2 or hit in the last 2s.
	if K then
		if b:WasRecentlyDamagedByAnyHero(3) then
			return BOT_ACTION_DESIRE_HIGH, "escape-hit"
		end
		for R, W in pairs(c.GetNearbyHeroes(b, 1200, true, BOT_MODE_NONE) or {}) do
			if
				c.IsValidHero(W)
				and c.IsChasingTarget(W, b)
				and not c.IsSuspiciousIllusion(W)
				and not c.IsDisabled(W)
			then
				return BOT_ACTION_DESIRE_HIGH, "escape-chased"
			end
		end
		if c.GetHP(b) < 0.4 and #(c.GetNearbyHeroes(b, 1600, true, BOT_MODE_NONE) or {}) > 0 then
			return BOT_ACTION_DESIRE_HIGH, "escape-low-hp"
		end
	end
	if c.IsFarming(b) then
		local O = b:GetNearbyCreeps(T, true)
		if
			-- fix: tested an undefined global (nEnemyLaneCreeps), so farming never used Scorched Earth
			O ~= nil
			and (#O >= 3 or #O >= 2 and O[1]:IsAncientCreep())
			and c.CanBeAttacked(O[1])
			and L
			and c.GetManaAfter(r:GetManaCost()) * b:GetMana() > t:GetManaCost() * 1.75
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if c.IsDoingRoshan(b) then
		if
			c.IsRoshan(I)
			and c.CanCastOnNonMagicImmune(I)
			and c.IsInRange(b, I, T)
			and L
			and c.GetManaAfter(r:GetManaCost()) * b:GetMana() > t:GetManaCost() * 2
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if c.IsDoingTormentor(b) then
		if
			c.IsTormentor(I)
			and c.IsInRange(b, I, T)
			and L
			and c.GetManaAfter(r:GetManaCost()) * b:GetMana() > t:GetManaCost() * 2
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function a.ConsiderInfernalBlade()
	if not s:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local Y = s:GetCastRange()
	local Z = s:GetSpecialValueInt("burn_damage")
	-- datafeed: burn_damage_pct is fractional (0.5/1.75/3/4.25), GetSpecialValueInt truncated it
	local _ = s:GetSpecialValueFloat("burn_damage_pct") / 100
	local a0 = s:GetSpecialValueInt("burn_duration")
	local a1 = c.GetNearbyHeroes(b, 700, true, BOT_MODE_NONE)
	for R, W in pairs(a1) do
		if
			c.IsValidHero(W)
			and c.CanCastOnNonMagicImmune(W)
			and c.CanCastOnTargetAdvanced(W)
			and not c.IsSuspiciousIllusion(W)
		then
			local P = W:GetNearbyTowers(700, false)
			-- A TP is checked by its modifier too, as everywhere else in the project: IsChanneling()
			-- alone missed an enemy TP in range at 32:30.
			if W:IsChanneling() or W:HasModifier("modifier_teleporting") then
				if not c.IsInLaningPhase() or P ~= nil and #P == 0 then
					return BOT_ACTION_DESIRE_HIGH, W
				end
			end
			if
				c.WillKillTarget(W, Z + W:GetMaxHealth() * _, DAMAGE_TYPE_MAGICAL, a0)
				and not W:HasModifier("modifier_abaddon_borrowed_time")
				and not W:HasModifier("modifier_dazzle_shallow_grave")
				and not W:HasModifier("modifier_necrolyte_reapers_scythe")
				and not W:HasModifier("modifier_oracle_false_promise_timer")
				and not W:HasModifier("modifier_skeleton_king_reincarnation_scepter_active")
				and not W:HasModifier("modifier_templar_assassin_refraction_absorb")
			then
				if c.IsInLaningPhase() then
					if P ~= nil and #P == 0 then
						return BOT_ACTION_DESIRE_HIGH, W
					end
				else
					return BOT_ACTION_DESIRE_HIGH, W
				end
			end
		end
	end
	if J then
		if
			c.IsValidTarget(I)
			and c.CanCastOnNonMagicImmune(I)
			and c.CanCastOnTargetAdvanced(I)
			and c.IsInRange(b, I, Y + 150)
			and not c.IsSuspiciousIllusion(I)
			and not c.IsDisabled(I)
			and not I:HasModifier("modifier_enigma_black_hole_pull")
			and not I:HasModifier("modifier_faceless_void_chronosphere_freeze")
			and not I:HasModifier("modifier_necrolyte_reapers_scythe")
			and not I:HasModifier("modifier_skeleton_king_reincarnation_scepter_active")
		then
			local U = c.GetNearbyHeroes(I, 1200, true, BOT_MODE_NONE)
			local V = c.GetNearbyHeroes(I, 1200, false, BOT_MODE_NONE)
			if U ~= nil and V ~= nil and #U >= #V then
				return BOT_ACTION_DESIRE_HIGH, I
			end
		end
	end
	if K then
		local V = c.GetNearbyHeroes(b, Y, true, BOT_MODE_NONE)
		for R, W in pairs(V) do
			if
				c.IsValidHero(W)
				and c.CanCastOnNonMagicImmune(W)
				and c.CanCastOnTargetAdvanced(W)
				and c.IsChasingTarget(W, b)
				and not c.IsSuspiciousIllusion(W)
				and not c.IsDisabled(W)
				and not W:HasModifier("modifier_necrolyte_reapers_scythe")
			then
				local U = c.GetNearbyHeroes(W, 1200, true, BOT_MODE_NONE)
				local X = c.GetNearbyHeroes(W, 1200, false, BOT_MODE_NONE)
				if U ~= nil and X ~= nil and (#X > #U or b:WasRecentlyDamagedByAnyHero(2)) then
					return BOT_ACTION_DESIRE_HIGH, W
				end
			end
		end
	end
	if c.IsFarming(b) then
		local a2 = b:GetNearbyNeutralCreeps(Y + 150)
		if a2 ~= nil and #a2 >= 1 then
			local a3 = c.GetMostHpUnit(a2)
			if
				c.IsValid(a3)
				and c.GetManaAfter(r:GetManaCost()) * b:GetMana() > t:GetManaCost()
				and not c.IsOtherAllysTarget(a3)
			then
				return BOT_ACTION_DESIRE_HIGH, a3
			end
		end
	end
	if c.IsLaning(b) then
		local nEnemyLaneCreeps = b:GetNearbyLaneCreeps(Y + 75, true)
		for R, S in pairs(nEnemyLaneCreeps) do
			if
				c.IsValid(S)
				and c.CanBeAttacked(S)
				and (c.IsKeyWordUnit("ranged", S) or c.IsKeyWordUnit("siege", S) or c.IsKeyWordUnit("flagbearer", S))
				and S:GetHealth() <= Z
			then
				local a4 = c.GetNearbyHeroes(b, 1600, true, BOT_MODE_NONE)
				if a4 ~= nil and #a4 >= 1 and GetUnitToUnitDistance(S, a4[1]) < 500 then
					return BOT_ACTION_DESIRE_HIGH, S
				end
			end
		end
	end
	if c.IsDoingRoshan(b) then
		if c.IsRoshan(I) and c.IsInRange(b, I, Y) and L then
			return BOT_ACTION_DESIRE_HIGH, I
		end
	end
	if c.IsDoingTormentor(b) then
		if c.IsTormentor(I) and c.IsInRange(b, I, Y) and L then
			return BOT_ACTION_DESIRE_HIGH, I
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function a.ConsiderDoom()
	if not t:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local a0 = t:GetSpecialValueInt("duration")
	if J then
		local a5 = nil
		local a6 = 0
		local a1 = c.GetNearbyHeroes(b, 1000, true, BOT_MODE_NONE)
		for R, W in pairs(a1) do
			if
				c.IsValid(W)
				and c.CanCastOnMagicImmune(W)
				and c.CanCastOnTargetAdvanced(W)
				and not c.IsSuspiciousIllusion(W)
				and not c.IsDisabled(W)
				and not c.IsHaveAegis(W)
				and not W:HasModifier("modifier_doom_bringer_doom")
				and not W:HasModifier("modifier_enigma_black_hole_pull")
				and not W:HasModifier("modifier_faceless_void_chronosphere_freeze")
				and not W:HasModifier("modifier_necrolyte_reapers_scythe")
				and not W:HasModifier("modifier_oracle_false_promise_timer")
				and not W:HasModifier("modifier_skeleton_king_reincarnation_scepter_active")
			then
				local U = c.GetNearbyHeroes(W, 1600, true, BOT_MODE_NONE)
				local V = c.GetNearbyHeroes(W, 1600, false, BOT_MODE_NONE)
				if U ~= nil and V ~= nil and #U >= #V then
					local a7 = W:GetEstimatedDamageToTarget(false, b, 3.0, DAMAGE_TYPE_ALL)
					if a6 < a7 then
						a6 = a7
						a5 = W
					end
				end
			end
		end
		if a5 ~= nil then
			local U = c.GetNearbyHeroes(a5, 1600, true, BOT_MODE_NONE)
			local V = c.GetNearbyHeroes(a5, 1600, false, BOT_MODE_NONE)
			if U ~= nil and V ~= nil then
				if c.IsInLaningPhase() then
					if not (#U >= #V + 2) and c.IsAttacking(a5) then
						if a5:GetHealth() <= b:GetEstimatedDamageToTarget(true, a5, a0, DAMAGE_TYPE_ALL) then
							return BOT_ACTION_DESIRE_HIGH, a5
						end
					end
				else
					if not (#U >= #V + 2) then
						return BOT_ACTION_DESIRE_HIGH, a5
					end
				end
			end
		end
	end
	-- Retreat: Doom was cast only while engaging. Doom silences its target (datafeed: "prevents them
	-- from casting spells"), so when Doom is low and being hit, put it on the chaser hurting him
	-- most, so the chaser cannot stun or blink after him.
	if K and c.GetHP(b) < 0.5 and b:WasRecentlyDamagedByAnyHero(2) then
		local best, bestDmg = nil, 0
		for R, W in pairs(c.GetNearbyHeroes(b, 550, true, BOT_MODE_NONE) or {}) do
			if
				c.IsValidHero(W)
				and c.CanCastOnTargetAdvanced(W)
				and c.IsChasingTarget(W, b)
				and c.CanCastOnMagicImmune(W)
				and not c.IsHaveAegis(W) -- same guards as the engage branch
				and not c.IsSuspiciousIllusion(W)
				and not W:HasModifier("modifier_doom_bringer_doom")
				and not W:HasModifier("modifier_necrolyte_reapers_scythe")
			then
				local dmg = W:GetEstimatedDamageToTarget(false, b, 3.0, DAMAGE_TYPE_ALL)
				if dmg > bestDmg then
					best, bestDmg = W, dmg
				end
			end
		end
		if best ~= nil then
			if DotaTime() >= (b._doomRetreatLogAt or -999) then
				b._doomRetreatLogAt = DotaTime() + 5
				pcall(print, string.format("[OHA-DOOM] t=%.0f doom retreat target=%s hp=%.2f", DotaTime(), best:GetUnitName(), c.GetHP(b)))
			end
			return BOT_ACTION_DESIRE_HIGH, best
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
DEVOUR_ABILITIES = {
	centaur_khan_war_stomp = true,
	fel_beast_haunt = true,
	giant_wolf_intimidate = true,
	harpy_scout_take_off = true,
	harpy_storm_chain_lightning = true,
	satyr_trickster_purge = true,
}
-- A Devoured creep ability: not one of Doom's own, not a map/system ability, not hidden.
function a.IsStolenAbility(ab)
	local name = ab:GetName()
	if type(name) ~= "string" or ab:IsHidden() or ab:IsPassive() then
		return false
	end
	if string.sub(name, 1, 13) == "doom_bringer_" or string.sub(name, 1, 14) == "special_bonus_" then
		return false
	end
	for _, prefix in ipairs({ "ability_", "plus_", "seasonal_", "twin_gate" }) do
		if string.sub(name, 1, #prefix) == prefix then
			return false
		end
	end
	return true
end
-- Any other Devoured creep ability, judged by its own target type and team (read from the game,
-- so no creep ability names are hard-coded). Toggles and autocasts are left alone.
function a.ConsiderGenericDevourAbility(ab)
	if not ab:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil, ""
	end
	local behavior = ab:GetBehavior()
	local has = function(flag)
		return flag ~= nil and c.CheckBitfieldFlag(behavior, flag)
	end
	-- Behavior flags: no target 4, unit 8, point 16, toggle 512, autocast 4096 (checked on known
	-- abilities: Echo Slam, Fissure, Split Shot, Walrus Punch). Friendly target team is 1.
	if has(512) or has(4096) then
		return BOT_ACTION_DESIRE_NONE, nil, ""
	end
	local okTeam, team = pcall(function()
		return ab:GetTargetTeam()
	end)
	local friendly = okTeam and team == 1
	local range = ab:GetCastRange()
	if range == nil or range < 150 then
		range = 350
	end
	range = c.GetProperCastRange(false, b, range)
	local foesNear = c.GetNearbyHeroes(b, 1200, true, BOT_MODE_NONE) or {}
	if has(8) and friendly then
		if #foesNear == 0 then
			return BOT_ACTION_DESIRE_NONE, nil, ""
		end
		local best, bestHp = nil, 0.5
		for _, ally in pairs(c.GetNearbyHeroes(b, range, false, BOT_MODE_NONE) or {}) do
			if c.IsValidHero(ally) and not ally:IsIllusion() and c.GetHP(ally) < bestHp then
				best, bestHp = ally, c.GetHP(ally)
			end
		end
		if best ~= nil then
			return BOT_ACTION_DESIRE_HIGH, best, "unit"
		end
		return BOT_ACTION_DESIRE_NONE, nil, ""
	end
	local target = nil
	if (J or c.IsInTeamFight(b, 1200)) and c.IsValidHero(I) and not c.IsSuspiciousIllusion(I) then
		target = I
	elseif K then
		for _, foe in pairs(foesNear) do
			if c.IsValidHero(foe) and not c.IsSuspiciousIllusion(foe) and c.IsChasingTarget(foe, b) then
				target = foe
				break
			end
		end
	end
	if target == nil or not c.CanCastOnNonMagicImmune(target) then
		return BOT_ACTION_DESIRE_NONE, nil, ""
	end
	if has(8) and c.IsInRange(b, target, range + 100) then
		return BOT_ACTION_DESIRE_HIGH, target, "unit"
	end
	if has(16) and c.IsInRange(b, target, range + 100) then
		return BOT_ACTION_DESIRE_HIGH, target, "point"
	end
	if has(4) and c.IsInRange(b, target, 350) then
		return BOT_ACTION_DESIRE_HIGH, nil, ""
	end
	return BOT_ACTION_DESIRE_NONE, nil, ""
end
function a.ConsiderDevourAbility(a8)
	if a8:IsPassive() or not a8:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil, ""
	end
	local Y = 0
	local T = 0
	local a9 = 0
	if a8:GetName() == "fel_beast_haunt" then
		Y = 600
		if J then
			if
				c.IsValidTarget(I)
				and c.CanCastOnNonMagicImmune(I)
				and c.CanCastOnTargetAdvanced(I)
				and c.IsInRange(b, I, Y)
				and not c.IsSuspiciousIllusion(I)
				and not c.IsDisabled(I)
				and not I:HasModifier("modifier_necrolyte_reapers_scythe")
				and not I:HasModifier("modifier_skeleton_king_reincarnation_scepter_active")
			then
				local U = c.GetNearbyHeroes(I, 1200, true, BOT_MODE_NONE)
				local V = c.GetNearbyHeroes(I, 1200, false, BOT_MODE_NONE)
				if U ~= nil and V ~= nil and #U >= #V then
					return BOT_ACTION_DESIRE_HIGH, I, "unit"
				end
			end
		end
		if K and b:GetActiveModeDesire() > 0.5 then
			local V = c.GetNearbyHeroes(b, Y, true, BOT_MODE_NONE)
			for R, W in pairs(V) do
				if
					c.IsValidHero(W)
					and c.CanCastOnNonMagicImmune(W)
					and c.CanCastOnTargetAdvanced(W)
					and c.IsChasingTarget(W, b)
					and not c.IsSuspiciousIllusion(W)
					and not c.IsDisabled(W)
					and not W:HasModifier("modifier_necrolyte_reapers_scythe")
					and not W:HasModifier("modifier_skeleton_king_reincarnation_scepter_active")
				then
					local U = c.GetNearbyHeroes(W, 1200, true, BOT_MODE_NONE)
					local X = c.GetNearbyHeroes(W, 1200, false, BOT_MODE_NONE)
					if U ~= nil and X ~= nil and (#X > #U or b:WasRecentlyDamagedByAnyHero(2)) then
						return BOT_ACTION_DESIRE_HIGH, W, "unit"
					end
				end
			end
		end
	end
	if a8:GetName() == "harpy_scout_take_off" then
		if c.IsStuck(b) then
			if a8:GetToggleState() == false then
				return BOT_ACTION_DESIRE_HIGH
			else
				return BOT_ACTION_DESIRE_NONE
			end
		end
		if a8:GetToggleState() == true then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if a8:GetName() == "harpy_storm_chain_lightning" then
		Y = c.GetProperCastRange(false, b, a8:GetCastRange())
		a9 = a8:GetSpecialValueInt("initial_damage")
		local aa = a8:GetSpecialValueInt("jump_range")
		local a1 = c.GetNearbyHeroes(b, Y, true, BOT_MODE_NONE)
		for R, W in pairs(a1) do
			if
				c.IsValidHero(W)
				and c.CanCastOnNonMagicImmune(W)
				and c.CanCastOnTargetAdvanced(W)
				and c.CanKillTarget(W, a9, DAMAGE_TYPE_MAGICAL)
				and not c.IsSuspiciousIllusion(W)
				and not W:HasModifier("modifier_abaddon_borrowed_time")
				and not W:HasModifier("modifier_dazzle_shallow_grave")
				and not W:HasModifier("modifier_necrolyte_reapers_scythe")
				and not W:HasModifier("modifier_oracle_false_promise_timer")
				and not W:HasModifier("modifier_templar_assassin_refraction_absorb")
			then
				return BOT_ACTION_DESIRE_HIGH, W, "unit"
			end
		end
		if J then
			if
				c.IsValidTarget(I)
				and c.CanCastOnNonMagicImmune(I)
				and c.CanCastOnTargetAdvanced(I)
				and c.IsInRange(b, I, Y)
				and not c.IsSuspiciousIllusion(I)
				and not c.IsDisabled(I)
				and not I:HasModifier("modifier_necrolyte_reapers_scythe")
				and not I:HasModifier("modifier_templar_assassin_refraction_absorb")
			then
				local U = c.GetNearbyHeroes(b, 1200, false, BOT_MODE_NONE)
				local V = c.GetNearbyHeroes(b, 1200, true, BOT_MODE_NONE)
				if U ~= nil and V ~= nil and #U >= #V then
					return BOT_ACTION_DESIRE_HIGH, I, "unit"
				end
			end
		end
		if K then
			local V = c.GetNearbyHeroes(b, Y, true, BOT_MODE_NONE)
			for R, W in pairs(V) do
				if
					c.IsValidHero(W)
					and c.CanCastOnNonMagicImmune(W)
					and c.IsChasingTarget(W, b)
					and not c.IsSuspiciousIllusion(W)
					and not c.IsDisabled(W)
				then
					local U = c.GetNearbyHeroes(W, 1200, true, BOT_MODE_NONE)
					local X = c.GetNearbyHeroes(W, 1200, false, BOT_MODE_NONE)
					if U ~= nil and X ~= nil and (#X > #U or b:WasRecentlyDamagedByAnyHero(2)) then
						return BOT_ACTION_DESIRE_HIGH, W, "unit"
					end
				end
			end
		end
		if c.IsFarming(b) and c.GetManaAfter(a8:GetManaCost()) * b:GetMana() > t:GetManaCost() * 2 then
			local O = b:GetNearbyCreeps(1600, true)
			if O ~= nil and (#O >= 3 or #O >= 2 and O[1]:IsAncientCreep()) and L then
				for R, S in pairs(O) do
					if c.IsValid(S) and c.CanBeAttacked(S) then
						local ab = c.GetNearbyAroundLocationUnitCount(true, false, aa, S:GetLocation())
						if ab >= 2 then
							return BOT_ACTION_DESIRE_HIGH, S, "unit"
						end
					end
				end
			end
		end
		if c.IsDoingRoshan(b) then
			if c.IsRoshan(I) and c.CanCastOnNonMagicImmune(I) and c.IsInRange(b, I, Y) and L then
				return BOT_ACTION_DESIRE_HIGH, I, "unit"
			end
		end
		if c.IsDoingTormentor(b) then
			if c.IsTormentor(I) and c.IsInRange(b, I, Y) and L then
				return BOT_ACTION_DESIRE_HIGH, I, "unit"
			end
		end
	end
	if a8:GetName() == "centaur_khan_war_stomp" then
		a9 = a8:GetAbilityDamage()
		T = a8:GetSpecialValueInt("radius")
		local a1 = c.GetNearbyHeroes(b, T, true, BOT_MODE_NONE)
		for R, W in pairs(a1) do
			if c.IsValidHero(W) and c.CanCastOnNonMagicImmune(W) and not c.IsSuspiciousIllusion(W) then
				if W:IsChanneling() then
					return BOT_ACTION_DESIRE_HIGH, nil, ""
				end
				if
					c.CanKillTarget(W, a9, DAMAGE_TYPE_MAGICAL)
					and not W:HasModifier("modifier_abaddon_borrowed_time")
					and not W:HasModifier("modifier_dazzle_shallow_grave")
					and not W:HasModifier("modifier_necrolyte_reapers_scythe")
					and not W:HasModifier("modifier_oracle_false_promise_timer")
					and not W:HasModifier("modifier_skeleton_king_reincarnation_scepter_active")
					and not W:HasModifier("modifier_templar_assassin_refraction_absorb")
				then
					return BOT_ACTION_DESIRE_HIGH, nil, ""
				end
			end
		end
		if J then
			if
				c.IsValidTarget(I)
				and c.CanCastOnNonMagicImmune(I)
				and c.IsInRange(b, I, T)
				and not c.IsSuspiciousIllusion(I)
				and not c.IsDisabled(I)
				and not I:HasModifier("modifier_enigma_black_hole_pull")
				and not I:HasModifier("modifier_faceless_void_chronosphere_freeze")
				and not I:HasModifier("modifier_necrolyte_reapers_scythe")
				and not I:HasModifier("modifier_skeleton_king_reincarnation_scepter_active")
			then
				local U = c.GetNearbyHeroes(I, 1200, true, BOT_MODE_NONE)
				local V = c.GetNearbyHeroes(I, 1200, false, BOT_MODE_NONE)
				if U ~= nil and V ~= nil and #U >= #V then
					return BOT_ACTION_DESIRE_HIGH, nil, ""
				end
			end
		end
		if K then
			local U = c.GetNearbyHeroes(b, 1200, false, BOT_MODE_NONE)
			local V = c.GetNearbyHeroes(b, 1200, true, BOT_MODE_NONE)
			if
				U ~= nil
				and V ~= nil
				and c.IsValidHero(V[1])
				and c.CanCastOnNonMagicImmune(V[1])
				and c.IsInRange(b, V[1], T)
				and c.IsChasingTarget(V[1], b)
				and not c.IsSuspiciousIllusion(V[1])
				and not c.IsDisabled(V[1])
				and not V[1]:HasModifier("modifier_necrolyte_reapers_scythe")
			then
				local X = c.GetNearbyHeroes(V[1], 1200, false, BOT_MODE_NONE)
				if X ~= nil and (#X > #U or b:WasRecentlyDamagedByAnyHero(2)) then
					return BOT_ACTION_DESIRE_HIGH, nil, ""
				end
			end
		end
		if c.IsDoingRoshan(b) then
			if
				c.IsRoshan(I)
				and c.CanCastOnNonMagicImmune(I)
				and c.IsInRange(b, I, T)
				and L
				and not c.IsDisabled(I)
			then
				return BOT_ACTION_DESIRE_HIGH, nil, ""
			end
		end
		if c.IsDoingTormentor(b) then
			if c.IsTormentor(I) and c.IsInRange(b, I, T) and L then
				return BOT_ACTION_DESIRE_HIGH, nil, ""
			end
		end
	end
	if a8:GetName() == "giant_wolf_intimidate" then
		T = a8:GetSpecialValueInt("radius")
		if J then
			if
				c.IsValidTarget(I)
				and c.IsInRange(b, I, T)
				and not c.IsSuspiciousIllusion(I)
				and not c.IsDisabled(I)
				and not I:HasModifier("modifier_necrolyte_reapers_scythe")
			then
				local U = c.GetNearbyHeroes(b, 1200, false, BOT_MODE_NONE)
				local V = c.GetNearbyHeroes(b, 1200, true, BOT_MODE_NONE)
				if U ~= nil and V ~= nil and #U >= #V then
					return BOT_ACTION_DESIRE_HIGH, nil, ""
				end
			end
		end
		if K then
			local U = c.GetNearbyHeroes(b, 1200, false, BOT_MODE_NONE)
			local V = c.GetNearbyHeroes(b, 1200, true, BOT_MODE_NONE)
			if
				U ~= nil
				and V ~= nil
				and c.IsValidHero(V[1])
				and c.IsInRange(b, V[1], T)
				and c.IsChasingTarget(V[1], b)
				and c.IsAttacking(V[1])
				and not c.IsSuspiciousIllusion(V[1])
				and not c.IsDisabled(V[1])
				and not V[1]:HasModifier("modifier_necrolyte_reapers_scythe")
			then
				local X = c.GetNearbyHeroes(V[1], 1200, false, BOT_MODE_NONE)
				if X ~= nil and (#X > #U or b:WasRecentlyDamagedByAnyHero(1.5)) then
					return BOT_ACTION_DESIRE_HIGH, nil, ""
				end
			end
		end
		if c.IsDoingRoshan(b) then
			if c.IsRoshan(I) and c.IsInRange(b, I, T) and L and not c.IsDisabled(I) then
				return BOT_ACTION_DESIRE_HIGH, nil, ""
			end
		end
		if c.IsDoingTormentor(b) then
			if c.IsTormentor(I) and c.IsInRange(b, I, T) and L then
				return BOT_ACTION_DESIRE_HIGH, nil, ""
			end
		end
	end
	if a8:GetName() == "satyr_trickster_purge" then
		Y = c.GetProperCastRange(false, b, a8:GetCastRange())
		if not b:IsMagicImmune() and not b:IsInvulnerable() then
			if c.IsDisabled(b) or b:HasModifier("modifier_bounty_hunter_track") then
				return BOT_ACTION_DESIRE_HIGH, b, "unit"
			end
		end
		local ac = c.GetNearbyHeroes(b, Y, false, BOT_MODE_NONE)
		for R, ad in pairs(ac) do
			if
				c.IsValidHero(ad)
				and not ad:IsMagicImmune()
				and not ad:IsInvulnerable()
				and not c.IsSuspiciousIllusion(ad)
			then
				if c.IsDisabled(ad) or ad:HasModifier("modifier_bounty_hunter_track") then
					return BOT_ACTION_DESIRE_HIGH, ad, "unit"
				end
			end
		end
		local a1 = c.GetNearbyHeroes(b, Y, true, BOT_MODE_NONE)
		for R, W in pairs(a1) do
			if
				c.IsValidHero(W)
				and not c.IsDisabled(W)
				and not W:IsMagicImmune()
				and not W:IsInvulnerable()
				and not c.IsSuspiciousIllusion(W)
			then
				if W:HasModifier("modifier_item_satanic_unholy") or W:HasModifier("modifier_rune_doubledamage") then
					return BOT_ACTION_DESIRE_HIGH, W, "unit"
				end
			end
		end
		if J then
			if
				c.IsValidTarget(I)
				and c.CanCastOnNonMagicImmune(I)
				and c.CanCastOnTargetAdvanced(I)
				and c.IsInRange(b, I, Y)
				and c.IsChasingTarget(b, I)
				and I:GetCurrentMovementSpeed() > b:GetCurrentMovementSpeed()
				and not c.IsSuspiciousIllusion(I)
				and not c.IsDisabled(I)
				and not I:HasModifier("modifier_necrolyte_reapers_scythe")
			then
				local U = c.GetNearbyHeroes(b, 1200, false, BOT_MODE_NONE)
				local V = c.GetNearbyHeroes(b, 1200, true, BOT_MODE_NONE)
				if U ~= nil and V ~= nil and #U >= #V then
					return BOT_ACTION_DESIRE_HIGH, I, "unit"
				end
			end
		end
		if K then
			local V = c.GetNearbyHeroes(b, Y, true, BOT_MODE_NONE)
			for R, W in pairs(V) do
				if
					c.IsValidHero(W)
					and c.CanCastOnNonMagicImmune(W)
					and c.CanCastOnTargetAdvanced(W)
					and c.IsChasingTarget(W, b)
					and not c.IsSuspiciousIllusion(W)
					and not c.IsDisabled(W)
				then
					local U = c.GetNearbyHeroes(W, 1200, true, BOT_MODE_NONE)
					local X = c.GetNearbyHeroes(W, 1200, false, BOT_MODE_NONE)
					if
						U ~= nil
						and X ~= nil
						and (#X > #U or b:WasRecentlyDamagedByAnyHero(2))
						and W:GetCurrentMovementSpeed() > b:GetCurrentMovementSpeed()
					then
						return BOT_ACTION_DESIRE_HIGH, W, "unit"
					end
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil, ""
end
function a.GetRangedOrSiegeCreep(O, ae)
	for R, S in pairs(O) do
		if
			c.IsValid(S)
			and c.CanBeAttacked(S)
			and S:GetLevel() <= ae
			and (c.IsKeyWordUnit("siege", S) or c.IsKeyWordUnit("ranged", S))
			and not c.IsRoshan(S)
			and not c.IsTormentor(S)
		then
			return S
		end
	end
	return nil
end
return a
