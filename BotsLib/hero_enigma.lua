-- Enigma: skill build, item build, and ability use for this hero.
local a = {}
local b = GetBot()
local c = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local d = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local e = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local f = c.Skill.GetTalentList(b)
local g = c.Skill.GetAbilityList(b)
local h = c.Item.GetRoleItemsBuyList(b)
local i = {
	{ ["t25"] = { 10, 0 }, ["t20"] = { 10, 0 }, ["t15"] = { 0, 10 }, ["t10"] = { 0, 10 } },
	{ ["t25"] = { 10, 0 }, ["t20"] = { 10, 0 }, ["t15"] = { 0, 10 }, ["t10"] = { 0, 10 } },
}
local j = { { 2, 1, 2, 1, 2, 6, 2, 1, 1, 3, 6, 3, 3, 3, 6 }, { 2, 1, 2, 1, 2, 6, 2, 1, 1, 3, 6, 3, 3, 3, 6 } }
local k = j[1]
if h == "pos_3" then
	k = j[1]
end
if h == "pos_4" then
	k = j[2]
end
if h == "pos_5" then
	k = j[2]
end
local l = c.Skill.GetTalentBuild(i[1])
if h == "pos_3" then
	l = c.Skill.GetTalentBuild(i[1])
end
if h == "pos_4" then
	l = c.Skill.GetTalentBuild(i[2])
end
if h == "pos_5" then
	l = c.Skill.GetTalentBuild(i[2])
end
local n = "item_team_aura"
local o = {}
o["pos_3"] = {
	"item_tango",
	"item_double_branches",
	"item_magic_wand",
	-- Tranquil Boots before Vladmir (Buckler is its first part).
	"item_boots",
	"item_tranquil_boots",
	"item_vladmir",
	"item_blink",
	"item_black_king_bar",
	"item_aghanims_shard",
	"item_ultimate_scepter",
	-- Octarine (+450 mana, 25% cooldown) before Refresher: the double Black Hole needs ~1,125-1,465
	-- mana, more than the pool before Octarine.
	"item_octarine_core",
	"item_refresher",
	n,
	"item_travel_boots",
	"item_arcane_blink",
	"item_travel_boots_2",
	"item_ultimate_scepter_2",
	"item_moon_shard",
}
o["pos_4"] = {
	"item_enchanted_mango",
	"item_double_tango",
	"item_double_branches",
	"item_blood_grenade",
	"item_magic_wand",
	"item_boots",
	"item_vladmir",
	"item_arcane_boots",
	"item_blink",
	"item_guardian_greaves",
	"item_black_king_bar",
	"item_lotus_orb",
	"item_gungir",
	"item_refresher",
	"item_arcane_blink",
	"item_aghanims_shard",
	"item_ultimate_scepter_2",
	"item_moon_shard",
}
o["pos_5"] = {
	"item_enchanted_mango",
	"item_double_tango",
	"item_double_branches",
	"item_blood_grenade",
	"item_magic_wand",
	"item_boots",
	-- Tranquil Boots before Vladmir (Buckler is its first part).
	"item_tranquil_boots",
	"item_vladmir",
	"item_pipe",
	"item_blink",
	"item_boots_of_bearing",
	"item_black_king_bar",
	"item_refresher",
	"item_arcane_blink",
	"item_aghanims_shard",
	"item_ultimate_scepter_2",
	"item_moon_shard",
}
o["pos_1"] = o["pos_3"]
o["pos_2"] = o["pos_3"]
a["sBuyList"] = o[h]
a["sSellList"] = { "item_ultimate_scepter", "item_magic_wand", "item_cyclone", "item_magic_wand" }
if c.Role.IsPvNMode() or c.Role.IsAllShadow() then
	a["sBuyList"], a["sSellList"] = { "PvN_antimage" }, {}
end
k, l, a["sBuyList"], a["sSellList"] = c.SetUserHeroInit(k, l, a["sBuyList"], a["sSellList"])
a["sSkillList"] = c.Skill.GetSkillList(g, k, f, l)
a["bDeafaultAbility"] = false
-- Cast when cornered (retreating into 3+ enemies with no way out), before running further.
a["LastStandSpells"] = { { name = "enigma_black_hole", kind = "point" } }
a["bDeafaultItem"] = false
function a.MinionThink(p)
	e.MinionThink(p)
end
local q = SafeAbility(b:GetAbilityByName("enigma_malefice"), "enigma_malefice", "enigma")
local r = SafeAbility(b:GetAbilityByName("enigma_demonic_conversion"), "enigma_demonic_conversion", "enigma")
local s = SafeAbility(b:GetAbilityByName("enigma_midnight_pulse"), "enigma_midnight_pulse", "enigma")
local t = SafeAbility(b:GetAbilityByName("enigma_black_hole"), "enigma_black_hole", "enigma")
local u = SafeAbility(b:GetAbilityByName("special_bonus_unique_enigma_2"), "special_bonus_unique_enigma_2", "enigma")
local v = SafeAbility(b:GetAbilityByName("special_bonus_unique_enigma_6"), "special_bonus_unique_enigma_6", "enigma")
local w, x
local y, z
local A, B
local C, D
local E, F
local G, H
local I
local J
local K
local L
local M
local N
function a.SkillsComplement()
	if c.CanNotUseAbility(b) then
		return
	end
	local O = d.Build(b)
	L = O.isEngaging
	M = c.IsAttacking(b)
	N = O.isTeamFight
	K = O.target
	local P = c.GetNearbyHeroes(b, 1000, true, BOT_MODE_NONE)
	for Q, R in pairs(P) do
		if
			c.IsValidHero(R)
			and (
				R:HasModifier("modifier_enigma_black_hole_pull")
				or R:HasModifier("modifier_enigma_black_hole_pull_scepter")
			)
		then
			return
		end
	end
	G, H = a.ConsiderBlinkPulseHole()
	if G > 0 then
		b:Action_ClearActions(false)
		if a.CanBKB() and not b:IsMagicImmune() then
			b:ActionQueue_UseAbility(J)
			b:ActionQueue_Delay(0.1)
		end
		b:ActionQueue_UseAbilityOnLocation(I, H)
		b:ActionQueue_Delay(0.1)
		b:ActionQueue_UseAbilityOnLocation(s, H)
		b:ActionQueue_Delay(0.1)
		b:ActionQueue_UseAbilityOnLocation(t, H)
		return
	end
	E, F = a.ConsiderBlinkHole()
	if E > 0 then
		b:Action_ClearActions(false)
		if a.CanBKB() and not b:IsMagicImmune() then
			b:ActionQueue_UseAbility(J)
			b:ActionQueue_Delay(0.1)
		end
		b:ActionQueue_UseAbilityOnLocation(I, F)
		b:ActionQueue_Delay(0.1)
		a.QueuePulseBefore(F)
		b:ActionQueue_UseAbilityOnLocation(t, F)
		return
	end
	A, B = a.ConsiderMidnightPulse()
	if A > 0 then
		b:Action_UseAbilityOnLocation(s, B)
		return
	end
	C, D = a.ConsiderBlackHole()
	if C > 0 then
		b:Action_ClearActions(false)
		if a.CanBKB() and not b:IsMagicImmune() then
			b:ActionQueue_UseAbility(J)
			b:ActionQueue_Delay(0.1)
		end
		a.QueuePulseBefore(D)
		b:ActionQueue_UseAbilityOnLocation(t, D)
		return
	end
	w, x = a.ConsiderMalefice()
	if w > 0 then
		b:Action_UseAbilityOnEntity(q, x)
		return
	end
	y, z = a.ConsiderDemonicSummoning()
	if y > 0 then
		b:Action_UseAbilityOnLocation(r, z)
		return
	end
end
function a.ConsiderMalefice()
	if not q:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local S = c.GetProperCastRange(false, b, q:GetCastRange())
	-- datafeed: Malefice's instance count is "stun_instances" (3); it has no "value", so T (and the kill damage) was 0.
	local T = q:GetSpecialValueInt("stun_instances")
	if u:IsTrained() then
		T = T + q:GetSpecialValueInt("value")
	end
	local U = q:GetSpecialValueInt("damage") * T
	local P = c.GetNearbyHeroes(b, S + 150, true, BOT_MODE_NONE)
	for Q, R in pairs(P) do
		if
			c.IsValidHero(R)
			and c.CanCastOnNonMagicImmune(R)
			and c.CanCastOnTargetAdvanced(R)
			and not c.IsSuspiciousIllusion(R)
		then
			if R:IsChanneling() or c.IsCastingUltimateAbility(R) then
				return BOT_ACTION_DESIRE_HIGH, R
			end
			if
				c.CanKillTarget(R, U, DAMAGE_TYPE_MAGICAL)
				and not R:HasModifier("modifier_abaddon_aphotic_shield")
				and not R:HasModifier("modifier_abaddon_borrowed_time")
				and not R:HasModifier("modifier_dazzle_shallow_grave")
				and not R:HasModifier("modifier_necrolyte_reapers_scythe")
				and not R:HasModifier("modifier_oracle_false_promise_timer")
				and not R:HasModifier("modifier_skeleton_king_reincarnation_scepter_active")
				and not R:HasModifier("modifier_templar_assassin_refraction_absorb")
			then
				return BOT_ACTION_DESIRE_HIGH, R
			end
		end
	end
	if L then
		if
			c.IsValidTarget(K)
			and c.CanCastOnNonMagicImmune(K)
			and c.CanCastOnTargetAdvanced(K)
			and c.IsInRange(b, K, S + 150)
			and not c.IsSuspiciousIllusion(K)
			and not c.IsDisabled(K)
			and not K:HasModifier("modifier_necrolyte_reapers_scythe")
			and not K:HasModifier("modifier_skeleton_king_reincarnation_scepter_active")
		then
			local V = c.GetNearbyHeroes(K, 1400, true, BOT_MODE_NONE)
			local W = c.GetNearbyHeroes(K, 1400, false, BOT_MODE_NONE)
			if V ~= nil and W ~= nil and #V >= #W then
				return BOT_ACTION_DESIRE_HIGH, K
			end
		end
	end
	if c.IsRetreating(b) then
		local W = c.GetNearbyHeroes(b, 1600, true, BOT_MODE_NONE)
		if
			c.IsValidHero(W[1])
			and c.CanCastOnNonMagicImmune(W[1])
			and c.CanCastOnTargetAdvanced(W[1])
			and c.IsInRange(b, W[1], S)
			and not c.IsSuspiciousIllusion(W[1])
			and not c.IsDisabled(W[1])
			and not c.IsRealInvisible(b)
		then
			local V = c.GetNearbyHeroes(W[1], 1200, true, BOT_MODE_NONE)
			local X = c.GetNearbyHeroes(W[1], 1200, false, BOT_MODE_NONE)
			if V ~= nil and X ~= nil and (#X > #V or b:WasRecentlyDamagedByAnyHero(2)) then
				return BOT_ACTION_DESIRE_HIGH, W[1]
			end
		end
	end
	local Y = c.GetNearbyHeroes(b, S, false, BOT_MODE_NONE)
	for Q, Z in pairs(Y) do
		local _ = c.GetNearbyHeroes(Z, 1600, true, BOT_MODE_NONE)
		if
			c.IsValidHero(Z)
			and (not c.IsCore(b) or c.IsCore(b) and c.GetManaAfter(q:GetManaCost()) > 0.66)
			and c.IsRetreating(Z)
			and Z:WasRecentlyDamagedByAnyHero(2)
			and not Z:IsIllusion()
		then
			if
				_ ~= nil
				and #_ >= 1
				and c.IsValidHero(_[1])
				and c.CanCastOnNonMagicImmune(_[1])
				and c.CanCastOnTargetAdvanced(_[1])
				and c.IsInRange(b, _[1], S)
				and c.IsChasingTarget(_[1], Z)
				and not c.IsDisabled(_[1])
				and not c.IsTaunted(_[1])
				and not c.IsSuspiciousIllusion(_[1])
				and not _[1]:HasModifier("modifier_legion_commander_duel")
				and not _[1]:HasModifier("modifier_enigma_black_hole_pull")
				and not _[1]:HasModifier("modifier_faceless_void_chronosphere_freeze")
			then
				return BOT_ACTION_DESIRE_HIGH, _[1]
			end
		end
	end
	if c.IsDoingRoshan(b) then
		if
			c.IsRoshan(K)
			and c.CanCastOnNonMagicImmune(K)
			and c.IsInRange(b, K, S)
			and M
			and not K:HasModifier("modifier_roshan_spell_block")
		then
			return BOT_ACTION_DESIRE_HIGH, K
		end
	end
	if c.IsDoingTormentor(b) then
		if c.IsTormentor(K) and c.IsInRange(b, K, S) and M then
			return BOT_ACTION_DESIRE_HIGH, K
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function a.ConsiderDemonicSummoning()
	if not r:IsFullyCastable() or c.GetHP(b) < 0.25 then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local S = c.GetProperCastRange(false, b, r:GetCastRange())
	local a0 = 75 + 25 * (r:GetLevel() - 1)
	if L and c.GetHP(b) > 0.5 then
		if
			c.IsValidTarget(K)
			and c.IsInRange(b, K, S)
			and not c.IsSuspiciousIllusion(K)
			and not K:HasModifier("modifier_dazzle_shallow_grave")
			and not K:HasModifier("modifier_faceless_void_chronosphere_freeze")
		then
			local V = c.GetNearbyHeroes(K, 1400, true, BOT_MODE_NONE)
			local W = c.GetNearbyHeroes(K, 1400, false, BOT_MODE_NONE)
			if V ~= nil and W ~= nil and #V >= #W then
				if DotaTime() < 10 * 60 then
					local a1 = K:GetNearbyTowers(800, false)
					if a1 ~= nil then
						if c.IsChasingTarget(b, K) then
							if c.IsInRange(b, K, S) and #a1 == 0 then
								return BOT_ACTION_DESIRE_HIGH, K:GetLocation()
							else
								if #a1 == 0 then
									return BOT_ACTION_DESIRE_HIGH,
										c.Site.GetXUnitsTowardsLocation(b, K:GetLocation(), S)
								end
							end
						else
							if c.IsInRange(b, K, S) then
								return BOT_ACTION_DESIRE_HIGH, (b:GetLocation() + K:GetLocation()) / 2
							end
						end
					end
				else
					if c.IsChasingTarget(b, K) then
						if c.IsInRange(b, K, S) then
							return BOT_ACTION_DESIRE_HIGH, K:GetLocation()
						else
							return BOT_ACTION_DESIRE_HIGH, c.Site.GetXUnitsTowardsLocation(b, K:GetLocation(), S)
						end
					else
						if c.IsInRange(b, K, b:GetAttackRange()) then
							return BOT_ACTION_DESIRE_HIGH, (b:GetLocation() + K:GetLocation()) / 2
						end
					end
				end
			end
		end
	end
	if c.IsDefending(b) or c.IsPushing(b) then
		if M then
			local a2 = b:GetNearbyLaneCreeps(1000, true)
			if a2 ~= nil and #a2 >= 3 then
				return BOT_ACTION_DESIRE_HIGH, b:GetLocation()
			end
			local a1 = b:GetNearbyTowers(800, true)
			local a3 = b:GetNearbyBarracks(800, true)
			local a4 = b:GetNearbyFillers(800, true)
			if
				c.IsValidBuilding(b:GetAttackTarget()) and (
					a1 ~= nil and #a1 >= 1
					or a3 ~= nil and #a3 >= 1
					or a4 ~= nil and #a4 >= 1
				)
			then
				return BOT_ACTION_DESIRE_HIGH, b:GetLocation()
			end
		end
	end
	if c.IsFarming(b) and c.GetHealthAfter(a0) > 0.5 and c.GetManaAfter(r:GetManaCost()) > 0.33 and M then
		local a2 = b:GetNearbyLaneCreeps(1000, true)
		if a2 ~= nil and #a2 >= 4 then
			return BOT_ACTION_DESIRE_HIGH, b:GetLocation()
		end
		local a5 = b:GetNearbyNeutralCreeps(S)
		if a5 ~= nil and #a5 >= 2 then
			return BOT_ACTION_DESIRE_HIGH, b:GetLocation()
		end
	end
	if c.IsLaning(b) then
		-- Eidolons take the wave and harass in lane. The mana bar was 50% after the cast, about
		-- three quarters of a level 1-3 pool, and Enigma was never seen summoning in lane.
		-- Every skip is logged with the reason so the next game shows what blocks it.
		local hpAfter = c.GetHealthAfter(a0)
		local mpAfter = c.GetManaAfter(r:GetManaCost())
		local a2 = b:GetNearbyLaneCreeps(800, true) or {}
		local why = nil
		if hpAfter <= 0.61 then
			why = "hp"
		elseif mpAfter <= 0.35 then
			why = "mana"
		elseif #a2 < 3 then
			why = "creeps"
		end
		if why == nil then
			pcall(print, string.format(
				"[OHA-ENIGMA] t=%.0f summon why=lane creeps=%d hpAfter=%.2f mpAfter=%.2f",
				DotaTime(), #a2, hpAfter, mpAfter
			))
			return BOT_ACTION_DESIRE_HIGH, b:GetLocation()
		end
		if DotaTime() >= (b._summonSkipLogAt or -999) then
			b._summonSkipLogAt = DotaTime() + 20
			pcall(print, string.format(
				"[OHA-ENIGMA] t=%.0f summon-skip why=%s creeps=%d hpAfter=%.2f mpAfter=%.2f",
				DotaTime(), why, #a2, hpAfter, mpAfter
			))
		end
	end
	if c.IsDoingRoshan(b) and c.GetHealthAfter(a0) > 0.5 then
		if c.IsRoshan(K) and c.IsInRange(b, K, b:GetAttackRange()) and M then
			return BOT_ACTION_DESIRE_HIGH, b:GetLocation()
		end
	end
	if c.IsDoingTormentor(b) and c.GetHealthAfter(a0) > 0.63 then
		if c.IsTormentor(K) and c.IsInRange(b, K, b:GetAttackRange()) and M then
			return BOT_ACTION_DESIRE_HIGH, b:GetLocation()
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function a.ConsiderMidnightPulse()
	if not s:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	-- Pulse only adds to Black Hole. With Black Hole off cooldown, a Pulse on its own must leave
	-- mana for it (Black Hole queues its own Pulse when both fit). Otherwise Pulse is free.
	if t:IsTrained() and t:GetCooldownTimeRemaining() <= 0 and b:GetMana() - s:GetManaCost() < t:GetManaCost() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local S = c.GetProperCastRange(false, b, s:GetCastRange())
	local a6 = s:GetSpecialValueInt("radius")
	if v:IsTrained() then
		a6 = a6 + s:GetSpecialValueInt("value")
	end
	if N then
		local a7 = b:FindAoELocation(true, true, b:GetLocation(), S, a6 / 2, 0, 0)
		local W = c.GetEnemiesNearLoc(a7.targetloc, a6 * 0.8)
		if W ~= nil and #W >= 2 then
			return BOT_ACTION_DESIRE_HIGH, a7.targetloc
		end
	end
	if L then
		if c.IsValidTarget(K) and c.CanCastOnNonMagicImmune(K) and not c.IsSuspiciousIllusion(K) then
			local V = c.GetNearbyHeroes(K, 1400, true, BOT_MODE_NONE)
			local W = c.GetNearbyHeroes(K, 1400, false, BOT_MODE_NONE)
			if V ~= nil and W ~= nil and #V >= #W then
				W = c.GetEnemiesNearLoc(K:GetLocation(), a6 * 0.66)
				if c.IsInRange(b, K, S) then
					if not c.IsChasingTarget(b, K) then
						if W ~= nil and #W >= 1 then
							return BOT_ACTION_DESIRE_HIGH, c.GetCenterOfUnits(W)
						else
							return BOT_ACTION_DESIRE_HIGH, K:GetLocation()
						end
					else
						return BOT_ACTION_DESIRE_HIGH, K:GetExtrapolatedLocation(1)
					end
				else
					if c.IsInRange(b, K, S + a6) and not c.IsInRange(b, K, S) and not c.IsChasingTarget(b, K) then
						return BOT_ACTION_DESIRE_HIGH, c.Site.GetXUnitsTowardsLocation(b, K:GetLocation(), S)
					end
				end
			end
		end
	end
	if c.IsDoingRoshan(b) then
		if c.IsRoshan(K) and c.CanCastOnNonMagicImmune(K) and c.IsInRange(b, K, S) and M then
			return BOT_ACTION_DESIRE_HIGH, K:GetLocation()
		end
	end
	if c.IsDoingTormentor(b) then
		if c.IsTormentor(K) and c.IsInRange(b, K, S) and M then
			return BOT_ACTION_DESIRE_HIGH, K:GetLocation()
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
-- Black Hole is for two or more enemy heroes. One enemy only when it kills a core and no other
-- enemy hero is in sight: the old fallback cast it on a lone target whenever our numbers were
-- even or better. Damage is read from "damage" (per second) x "duration"; the old "value" key
-- does not exist on this ability, so every kill check came out 0.
function a.ConsiderBlackHole()
	if not t:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local S = c.GetProperCastRange(false, b, t:GetCastRange())
	local a6 = t:GetSpecialValueInt("radius")
	local dps = t:GetSpecialValueInt("damage")
	local a8 = t:GetSpecialValueFloat("duration")
	if a8 == nil or a8 <= 0 then
		a8 = 4
	end
	if N or L then
		local a7 = b:FindAoELocation(true, true, b:GetLocation(), S, a6 * 0.8, 0, 0)
		local W = c.GetEnemiesNearLoc(a7.targetloc, a6)
		if W ~= nil and #W >= 2 then
			a.LogBlackHole("group", #W, W[1])
			return BOT_ACTION_DESIRE_HIGH, a7.targetloc
		end
	end
	if
		L
		and c.IsValidTarget(K)
		and c.IsCore(K)
		and c.CanCastOnMagicImmune(K)
		and c.IsInRange(b, K, S + 200)
		and not c.IsSuspiciousIllusion(K)
		and not K:HasModifier("modifier_dazzle_shallow_grave")
		and not K:HasModifier("modifier_faceless_void_chronosphere_freeze")
		and not K:HasModifier("modifier_templar_assassin_refraction_absorb")
		and not K:HasModifier("modifier_item_aeon_disk_buff")
		and K:GetHealth() > 200
		and c.CanKillTarget(K, dps * a8, DAMAGE_TYPE_PURE)
	then
		local others = c.GetEnemiesNearLoc(K:GetLocation(), 1600)
		if others ~= nil and #others <= 1 then
			a.LogBlackHole("kill", 1, K)
			if c.IsInRange(b, K, S) then
				return BOT_ACTION_DESIRE_HIGH, K:GetLocation()
			end
			return BOT_ACTION_DESIRE_HIGH, c.Site.GetXUnitsTowardsLocation(b, K:GetLocation(), S)
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
-- [OHA-ENIGMA] black-hole why=group|kill heroes=N target=..., every cast decision (5s apart).
function a.LogBlackHole(why, heroes, target)
	if DotaTime() < (b._blackHoleLogAt or -999) then
		return
	end
	b._blackHoleLogAt = DotaTime() + 5
	pcall(print, string.format(
		"[OHA-ENIGMA] t=%.0f black-hole why=%s heroes=%d target=%s pulseReady=%s",
		DotaTime(),
		why,
		heroes,
		target and (string.gsub(target:GetUnitName(), "npc_dota_hero_", "")) or "-",
		tostring(s:IsFullyCastable())
	))
end
-- Refresher for a second Black Hole: the first one went out within the last 15s, Refresher
-- and a Black Hole both fit in current mana, and 2+ enemy heroes are still grouped in reach.
-- The shared rule wanted mana for two more Black Holes, so it almost never fired. Items are
-- not used during the channel, so this runs once the first Black Hole has ended.
function a.CanUseRefresherShard()
	if not t:IsTrained() or t:IsFullyCastable() then
		return false
	end
	local cd = t:GetCooldown()
	local remain = t:GetCooldownTimeRemaining()
	if cd == nil or remain == nil or cd - remain > 15 then
		return false
	end
	local refresher = nil
	for _, name in ipairs({ "item_refresher", "item_refresher_shard" }) do
		local slot = b:FindItemSlot(name)
		if slot >= 0 and slot <= 5 then
			refresher = b:GetItemInSlot(slot)
			break
		end
	end
	if refresher == nil or not refresher:IsFullyCastable() then
		return false
	end
	if b:GetMana() < refresher:GetManaCost() + t:GetManaCost() then
		return false
	end
	local reach = c.GetProperCastRange(false, b, t:GetCastRange()) + 300
	local spot = b:FindAoELocation(true, true, b:GetLocation(), reach, t:GetSpecialValueInt("radius") * 0.8, 0, 0)
	local group = c.GetEnemiesNearLoc(spot.targetloc, t:GetSpecialValueInt("radius"))
	if group == nil or #group < 2 then
		return false
	end
	pcall(print, string.format(
		"[OHA-ENIGMA] t=%.0f refresher heroes=%d mana=%.0f need=%.0f",
		DotaTime(),
		#group,
		b:GetMana(),
		refresher:GetManaCost() + t:GetManaCost()
	))
	return true
end
-- Midnight Pulse in front of Black Hole when it is ready and there is mana for both.
function a.QueuePulseBefore(loc)
	if s:IsFullyCastable() and b:GetMana() >= s:GetManaCost() + t:GetManaCost() then
		b:ActionQueue_UseAbilityOnLocation(s, loc)
		b:ActionQueue_Delay(0.1)
	end
end
function a.ConsiderBlinkHole()
	if a.CanDoBlinkHole() then
		local a6 = t:GetSpecialValueInt("radius")
		if N then
			local a7 = b:FindAoELocation(true, true, b:GetLocation(), 1199, a6, 0, 0)
			local W = c.GetEnemiesNearLoc(a7.targetloc, a6)
			if W ~= nil and #W >= 2 then
				return BOT_ACTION_DESIRE_HIGH, a7.targetloc
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function a.CanDoBlinkHole()
	if t:IsFullyCastable() and I ~= nil and I:IsFullyCastable() then
		local a9 = t:GetManaCost()
		if b:GetMana() >= a9 then
			return true
		end
	end
	return false
end
function a.ConsiderBlinkPulseHole()
	if a.CanDoBlinkPulseHole() then
		local a6 = t:GetSpecialValueInt("radius")
		if N then
			local a7 = b:FindAoELocation(true, true, b:GetLocation(), 1199, a6, 0, 0)
			local W = c.GetEnemiesNearLoc(a7.targetloc, a6)
			if W ~= nil and #W >= 2 then
				return BOT_ACTION_DESIRE_HIGH, a7.targetloc
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function a.CanDoBlinkPulseHole()
	if t:IsFullyCastable() and s:IsFullyCastable() and I ~= nil and I:IsFullyCastable() then
		local a9 = t:GetManaCost() + s:GetManaCost()
		if b:GetMana() >= a9 then
			return true
		end
	end
	return false
end
function a.HasBlink()
	local aa = nil
	for ab = 0, 5 do
		local ac = b:GetItemInSlot(ab)
		if
			ac ~= nil
			and (
				ac:GetName() == "item_blink"
				or ac:GetName() == "item_overwhelming_blink"
				or ac:GetName() == "item_arcane_blink"
				or ac:GetName() == "item_swift_blink"
			)
		then
			aa = ac
			break
		end
	end
	if aa ~= nil and aa:IsFullyCastable() then
		I = aa
		return true
	end
	return false
end
function a.CanBKB()
	local ad = nil
	for ab = 0, 5 do
		local ac = b:GetItemInSlot(ab)
		if ac ~= nil and ac:GetName() == "item_black_king_bar" then
			ad = ac
			break
		end
	end
	if ad ~= nil and ad:IsFullyCastable() then
		J = ad
		return true
	end
	return false
end
return a
