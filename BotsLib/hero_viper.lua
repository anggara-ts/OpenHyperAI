-- Viper: skill build, item build, and ability use for this hero.
local a = {}
local b = GetBot()
local c = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local d = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local e = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local f = c.Skill.GetTalentList(b)
local g = c.Skill.GetAbilityList(b)
local h = c.Item.GetRoleItemsBuyList(b)
local i = {
	{ ["t25"] = { 0, 10 }, ["t20"] = { 10, 0 }, ["t15"] = { 10, 0 }, ["t10"] = { 0, 10 } },
	{ ["t25"] = { 0, 10 }, ["t20"] = { 10, 0 }, ["t15"] = { 10, 0 }, ["t10"] = { 10, 0 } },
}
local j = { { 1, 3, 1, 2, 1, 6, 1, 2, 2, 3, 6, 3, 2, 3, 6 }, { 1, 3, 1, 3, 1, 6, 1, 2, 3, 3, 6, 2, 2, 2, 6 } }
local k
local l
if h == "pos_2" then
	k = j[1]
	l = c.Skill.GetTalentBuild(i[1])
else
	k = j[2]
	l = c.Skill.GetTalentBuild(i[2])
end
local m = RandomInt(1, 9) > 5 and "item_sphere" or "item_lotus_orb"
local n = RandomInt(1, 9) > 6 and "item_monkey_king_bar" or "item_butterfly"
local o = {}
o["pos_1"] = {
	"item_ranged_carry_outfit",
	"item_dragon_lance",
	"item_yasha",
	"item_bloodthorn",
	"item_aghanims_shard",
	"item_manta",
	"item_travel_boots",
	m,
	"item_hurricane_pike",
	n,
	"item_hydras_breath",
	"item_moon_shard",
	"item_travel_boots_2",
}
o["pos_2"] = {
	"item_mid_outfit",
	"item_dragon_lance",
	"item_yasha",
	"item_bloodthorn",
	"item_aghanims_shard",
	"item_manta",
	"item_travel_boots",
	m,
	"item_hurricane_pike",
	n,
	"item_hydras_breath",
	"item_moon_shard",
	"item_travel_boots_2",
}
o["pos_3"] = {
	"item_tango",
	"item_double_branches",
	"item_enchanted_mango",
	"item_double_circlet",
	"item_magic_wand",
	"item_double_wraith_band",
	"item_boots",
	"item_power_treads",
	"item_mage_slayer",
	"item_dragon_lance",
	m,
	"item_black_king_bar",
	"item_aghanims_shard",
	"item_hurricane_pike",
	"item_butterfly",
	"item_sheepstick",
	"item_travel_boots_2",
	"item_ultimate_scepter_2",
	"item_moon_shard",
}
o["pos_4"] = o["pos_3"]
o["pos_5"] = o["pos_3"]
a["sBuyList"] = o[h]
a["sSellList"] = { "item_black_king_bar", "item_quelling_blade", "item_mage_slayer", "item_butterfly" }
if c.Role.IsPvNMode() or c.Role.IsAllShadow() then
	a["sBuyList"], a["sSellList"] = { "PvN_mid" }, {}
end
k, l, a["sBuyList"], a["sSellList"] = c.SetUserHeroInit(k, l, a["sBuyList"], a["sSellList"])
a["sSkillList"] = c.Skill.GetSkillList(g, k, f, l)
a["bDeafaultAbility"] = true
a["bDeafaultItem"] = false
function a.MinionThink(p)
	e.MinionThink(p)
end
local q = SafeAbility(b:GetAbilityByName("viper_poison_attack"), "viper_poison_attack", "viper")
local r = SafeAbility(b:GetAbilityByName("viper_nethertoxin"), "viper_nethertoxin", "viper")
local s = SafeAbility(b:GetAbilityByName("viper_nose_dive"), "viper_nose_dive", "viper")
local t = SafeAbility(b:GetAbilityByName("viper_viper_strike"), "viper_viper_strike", "viper")
local u, v
local w, x
local y, z
local A, B
local C
local D
local E
local F
local G
function a.SkillsComplement()
	if c.CanNotUseAbility(b) or b:IsInvisible() then
		return
	end
	D = c.IsGoingOnSomeone(b)
	E = c.IsRetreating(b)
	F = c.IsAttacking(b)
	G = c.GetMP(b)
	C = c.GetProperTarget(b)
	if c.IsValidHero(C) then
		if not q:GetAutoCastState() then
			q:ToggleAutoCast()
		end
	else
		if q:GetAutoCastState() then
			q:ToggleAutoCast()
		end
	end
	A, B = a.ConsiderViperStrike()
	if A > 0 then
		if c.HasPowerTreads(b) then
			c.SetQueuePtToINT(b, true)
			b:ActionQueue_UseAbilityOnEntity(t, B)
		else
			b:Action_UseAbilityOnEntity(t, B)
		end
		return
	end
	y, z = a.ConsiderNosedive()
	if y > 0 then
		if c.HasPowerTreads(b) then
			c.SetQueuePtToINT(b, true)
			b:ActionQueue_UseAbilityOnLocation(s, z)
		else
			b:Action_UseAbilityOnLocation(s, z)
		end
		return
	end
	w, x = a.ConsiderNetherToxin()
	if w > 0 then
		if c.HasPowerTreads(b) then
			c.SetQueuePtToINT(b, true)
			b:ActionQueue_UseAbilityOnLocation(r, x)
		else
			b:Action_UseAbilityOnLocation(r, x)
		end
		return
	end
	u, v = a.ConsiderPoisonAttack()
	if u > 0 then
		-- The autocast branches toggle autocast and return no target: nothing to cast then (game
		-- 034, 25:27 and 63:20: two casts refused for a nil target).
		if v ~= nil then
			b:Action_UseAbilityOnEntity(q, v)
		end
		return
	end
end
function a.ConsiderPoisonAttack()
	if not q:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local H = c.GetProperCastRange(false, b, q:GetCastRange())
	local I = b:GetAttackRange()
	local J = q:GetSpecialValueInt("damage")
	local K = q:GetSpecialValueInt("duration")
	if not E then
		local L = c.GetNearbyHeroes(b, H, true, BOT_MODE_NONE)
		for M, N in pairs(L) do
			if
				c.IsValidHero(N)
				and c.CanCastOnNonMagicImmune(N)
				and c.CanKillTarget(N, J * K, DAMAGE_TYPE_MAGICAL)
				and not c.IsSuspiciousIllusion(N)
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
	-- Lane poke with Poison Attack (user call; Viper Strike is no longer used for that). Laning, not
	-- retreating, over 40% mana and HP: an enemy hero within cast range, not standing under his
	-- tower, gets one (20 mana, 600 range, slows and stacks).
	if not E and c.IsInLaningPhase() and G > 0.4 and c.GetHP(b) > 0.4 then
		for _, N in pairs(c.GetNearbyHeroes(b, H, true, BOT_MODE_NONE) or {}) do
			if
				c.IsValidHero(N)
				and c.CanCastOnNonMagicImmune(N)
				and not c.IsSuspiciousIllusion(N)
				and not N:IsAttackImmune()
				and #(N:GetNearbyTowers(750, false) or {}) == 0
			then
				return BOT_ACTION_DESIRE_HIGH, N
			end
		end
	end
	if D then
		if
			c.IsValidTarget(C)
			and C:CanBeSeen()
			and not c.IsSuspiciousIllusion(C)
			and not C:IsMagicImmune()
			and not C:IsInvulnerable()
			and not C:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			local O = c.GetNearbyHeroes(C, 1200, true, BOT_MODE_NONE)
			local P = c.GetNearbyHeroes(C, 1200, false, BOT_MODE_NONE)
			if
				O ~= nil
				and P ~= nil
				and #O >= #P
				and c.GetManaAfter(q:GetManaCost()) * b:GetMana() > t:GetManaCost()
			then
				if c.IsInRange(b, C, I) and not C:IsAttackImmune() then
					if not q:GetAutoCastState() then
						q:ToggleAutoCast()
						return BOT_ACTION_DESIRE_HIGH, nil
					else
						return BOT_ACTION_DESIRE_NONE, nil
					end
				end
				if c.IsInRange(b, C, H) and not c.IsInRange(b, C, I) then
					return BOT_ACTION_DESIRE_HIGH, C
				end
			end
		end
	end
	if E then
		local P = c.GetNearbyHeroes(b, H, true, BOT_MODE_NONE)
		if
			c.IsValidHero(P[1])
			and c.IsChasingTarget(P[1], b)
			and not P[1]:HasModifier("modifier_viper_poison_attack_slow")
			and not P[1]:IsMagicImmune()
			and not P[1]:IsInvulnerable()
		then
			return BOT_ACTION_DESIRE_HIGH, P[1]
		end
	end
	if c.IsDoingRoshan(b) then
		if c.IsRoshan(C) and c.IsInRange(b, C, 500) and F then
			if not q:GetAutoCastState() and G > 0.25 then
				q:ToggleAutoCast()
				return BOT_ACTION_DESIRE_HIGH, nil
			else
				if q:GetAutoCastState() and G < 0.25 then
					q:ToggleAutoCast()
					return BOT_ACTION_DESIRE_HIGH, nil
				end
				return BOT_ACTION_DESIRE_NONE, nil
			end
		end
	end
	if c.IsDoingTormentor(b) then
		if c.IsTormentor(C) and c.IsInRange(b, C, 500) and F then
			if not q:GetAutoCastState() and G > 0.25 then
				q:ToggleAutoCast()
				return BOT_ACTION_DESIRE_HIGH, nil
			else
				if q:GetAutoCastState() and G < 0.25 then
					q:ToggleAutoCast()
					return BOT_ACTION_DESIRE_HIGH, nil
				end
				return BOT_ACTION_DESIRE_NONE, nil
			end
		end
	end
	local Q = c.GetNearbyHeroes(b, H, false, BOT_MODE_NONE)
	for M, R in pairs(Q) do
		local S = c.GetNearbyHeroes(R, 1200, true, BOT_MODE_NONE)
		for M, N in pairs(S) do
			if c.IsValidHero(R) and c.IsRetreating(R) and R:WasRecentlyDamagedByAnyHero(2) and not R:IsIllusion() then
				if
					c.IsValidHero(N)
					and c.CanCastOnNonMagicImmune(N)
					and c.IsInRange(b, N, H)
					and c.IsChasingTarget(N, R)
					and not c.IsDisabled(N)
					and not c.IsTaunted(N)
					and not c.IsSuspiciousIllusion(N)
					and not N:HasModifier("modifier_necrolyte_reapers_scythe")
					and not N:HasModifier("modifier_viper_poison_attack_slow")
				then
					return BOT_ACTION_DESIRE_HIGH, N
				end
			end
		end
	end
	if q:GetAutoCastState() then
		q:ToggleAutoCast()
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function a.ConsiderNetherToxin()
	if not r:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local H = c.GetProperCastRange(false, b, r:GetCastRange())
	local T = r:GetSpecialValueInt("radius")
	local U = r:GetLevel()
	if D then
		if
			c.IsValidHero(C)
			and c.CanCastOnNonMagicImmune(C)
			and c.IsInRange(b, C, H)
			and not C:HasModifier("modifier_necrolyte_reapers_scythe")
			and not C:HasModifier("modifier_viper_nethertoxin")
		then
			local O = c.GetNearbyHeroes(C, 1200, true, BOT_MODE_NONE)
			local P = c.GetNearbyHeroes(C, 1200, false, BOT_MODE_NONE)
			if O ~= nil and P ~= nil and #O >= #P then
				if c.IsInRange(b, C, H) then
					return BOT_ACTION_DESIRE_HIGH, C:GetLocation()
				end
				if c.IsInRange(b, C, H + T) and not c.IsInRange(b, C, H) then
					return BOT_ACTION_DESIRE_HIGH, c.Site.GetXUnitsTowardsLocation(b, C:GetLocation(), H)
				end
			end
		end
	end
	if E and b:GetActiveModeDesire() > 0.5 then
		local P = c.GetNearbyHeroes(b, H, true, BOT_MODE_NONE)
		for M, N in pairs(P) do
			if
				c.IsValidHero(N)
				and c.CanCastOnNonMagicImmune(N)
				and not c.IsSuspiciousIllusion(N)
				and not c.IsDisabled(N)
			then
				local O = c.GetNearbyHeroes(N, 1200, true, BOT_MODE_NONE)
				local V = c.GetNearbyHeroes(N, 1200, false, BOT_MODE_NONE)
				if O ~= nil and V ~= nil and (#V > #O or b:WasRecentlyDamagedByAnyHero(2)) then
					return BOT_ACTION_DESIRE_HIGH, N:GetExtrapolatedLocation(0.5)
				end
			end
		end
	end
	if c.IsPushing(b) or c.IsDefending(b) then
		local W = b:GetNearbyLaneCreeps(1000, true)
		if W ~= nil and #W >= 4 and not c.IsRunning(W[1]) then
			return BOT_ACTION_DESIRE_HIGH, c.GetCenterOfUnits(W)
		end
	end
	if c.IsFarming(b) and c.GetManaAfter(r:GetManaCost()) * b:GetMana() > t:GetManaCost() and U >= 2 then
		if F then
			local X = b:GetNearbyNeutralCreeps(b:GetAttackRange() + 200)
			local Y = c.GetNearbyAroundLocationUnitCount(true, false, T, c.GetCenterOfUnits(X))
			if X ~= nil and #X >= 1 and c.GetManaAfter(r:GetManaCost()) * b:GetMana() > t:GetManaCost() then
				if c.IsBigCamp(X) or X[1]:IsAncientCreep() then
					if #X >= 2 and Y >= 2 then
						return BOT_ACTION_DESIRE_HIGH, c.GetCenterOfUnits(X)
					end
				else
					if #X >= 3 and Y >= 2 then
						return BOT_ACTION_DESIRE_HIGH, c.GetCenterOfUnits(X)
					end
				end
			end
			local W = b:GetNearbyLaneCreeps(b:GetAttackRange() + 200, true)
			Y = c.GetNearbyAroundLocationUnitCount(true, false, T, c.GetCenterOfUnits(W))
			if W ~= nil and #W >= 3 and Y >= 2 then
				return BOT_ACTION_DESIRE_HIGH, c.GetCenterOfUnits(W)
			end
		end
	end
	if c.IsDoingRoshan(b) then
		if
			c.IsRoshan(C)
			and c.IsInRange(b, C, 500)
			and F
			and not C:IsMagicImmune()
			and not C:HasModifier("modifier_viper_nethertoxin")
		then
			return BOT_ACTION_DESIRE_HIGH, C:GetLocation()
		end
	end
	if c.IsDoingTormentor(b) then
		if c.IsTormentor(C) and c.IsInRange(b, C, 500) and F and not C:HasModifier("modifier_viper_nethertoxin") then
			return BOT_ACTION_DESIRE_HIGH, C:GetLocation()
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
-- Viper Strike (datafeed: 750 range, 70/110/150 per second for 6s, breaks passives, 50/40/30s).
-- Rework (user call, game 031: he ulted a hero to poke in lane and then did nothing; lane pokes are
-- for Poison Attack). It used to go on any enemy hero within ~830. Now only:
-- 1. a kill: the full poison kills an enemy hero in range;
-- 2. a team fight: the best target in range, a core first (estimated position 1-2), then a hero
--    whose passive matters (the list below), then his attack target;
-- 3. going on someone: his target in range; while laning only when it is an all-in (target under
--    60% HP, or our heroes there outnumber his);
-- 4. Roshan.
local PASSIVE_HEROES = {
	npc_dota_hero_bristleback = true,
	npc_dota_hero_spectre = true,
	npc_dota_hero_huskar = true,
	npc_dota_hero_dragon_knight = true,
	npc_dota_hero_tidehunter = true,
	npc_dota_hero_phantom_assassin = true,
	npc_dota_hero_antimage = true,
	npc_dota_hero_mars = true,
	npc_dota_hero_centaur = true,
	npc_dota_hero_necrolyte = true,
}
local function StrikeOk(N)
	return c.IsValidHero(N)
		and c.CanCastOnNonMagicImmune(N)
		and c.CanCastOnTargetAdvanced(N)
		and not c.IsSuspiciousIllusion(N)
		and not N:HasModifier("modifier_abaddon_borrowed_time")
		and not N:HasModifier("modifier_dazzle_shallow_grave")
		and not N:HasModifier("modifier_necrolyte_reapers_scythe")
		and not N:HasModifier("modifier_oracle_false_promise_timer")
		and not N:HasModifier("modifier_item_aeon_disk_buff")
		and not N:HasModifier("modifier_item_sphere_target")
end
local function LogStrike(why, N)
	pcall(print, string.format(
		"[OHA-VIPER] t=%.0f strike why=%s target=%s hp=%.2f",
		DotaTime(),
		why,
		(string.gsub(N:GetUnitName(), "npc_dota_hero_", "")),
		c.GetHP(N)
	))
end
function a.ConsiderViperStrike()
	if not t:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local H = t:GetCastRange() + 50
	local total = t:GetSpecialValueInt("damage") * t:GetSpecialValueInt("duration")
	local inRange = {}
	for _, N in pairs(c.GetNearbyHeroes(b, H, true, BOT_MODE_NONE) or {}) do
		if StrikeOk(N) then
			inRange[#inRange + 1] = N
		end
	end
	if #inRange == 0 then
		if c.IsDoingRoshan(b) and c.IsRoshan(C) and c.IsInRange(b, C, 500) and F and not C:HasModifier("modifier_roshan_spell_block") then
			return BOT_ACTION_DESIRE_HIGH, C
		end
		return BOT_ACTION_DESIRE_NONE, nil
	end
	-- 1. A kill.
	for _, N in ipairs(inRange) do
		if N:GetHealth() < N:GetActualIncomingDamage(total, DAMAGE_TYPE_MAGICAL) then
			LogStrike("kill", N)
			return BOT_ACTION_DESIRE_HIGH, N
		end
	end
	-- 2. A team fight: a core, then a passive hero, then his target.
	if c.IsInTeamFight(b, 1200) then
		local core, passive = nil, nil
		for _, N in ipairs(inRange) do
			local okP, pos = pcall(c.GetPosition, N)
			if core == nil and okP and type(pos) == "number" and pos <= 2 then
				core = N
			end
			if passive == nil and PASSIVE_HEROES[N:GetUnitName()] then
				passive = N
			end
		end
		local pick = core or passive
		if pick == nil and c.IsValidHero(C) then
			for _, N in ipairs(inRange) do
				if N == C then
					pick = N
				end
			end
		end
		if pick ~= nil then
			LogStrike(pick == core and "fight-core" or (pick == passive and "fight-passive" or "fight-target"), pick)
			return BOT_ACTION_DESIRE_HIGH, pick
		end
	end
	-- 3. Going on someone: his target; while laning only on an all-in.
	if D and c.IsValidHero(C) then
		for _, N in ipairs(inRange) do
			if N == C then
				local allIn = true
				if c.IsInLaningPhase() then
					local ours = #(c.GetNearbyHeroes(C, 1200, true, BOT_MODE_NONE) or {})
					local theirs = #(c.GetNearbyHeroes(C, 1200, false, BOT_MODE_NONE) or {})
					allIn = c.GetHP(C) < 0.6 or ours > theirs
				end
				if allIn then
					LogStrike("engage", N)
					return BOT_ACTION_DESIRE_HIGH, N
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function a.ConsiderNosedive()
	if not s:IsTrained() or not s:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local H = c.GetProperCastRange(false, b, s:GetCastRange())
	local T = 500
	if D then
		if c.IsValidTarget(C) and not c.IsSuspiciousIllusion(C) and not C:IsMagicImmune() then
			local O = c.GetNearbyHeroes(C, 1200, true, BOT_MODE_NONE)
			local P = c.GetNearbyHeroes(C, 1200, false, BOT_MODE_NONE)
			if O ~= nil and P ~= nil and #O >= #P then
				P = c.GetEnemiesNearLoc(C:GetLocation(), T)
				if P ~= nil and #P >= 1 then
					if c.IsInRange(b, C, H) then
						return BOT_ACTION_DESIRE_HIGH, c.GetCenterOfUnits(P)
					end
					if c.IsInRange(b, C, H + T) and not c.IsInRange(b, C, H) then
						return BOT_ACTION_DESIRE_HIGH, c.Site.GetXUnitsTowardsLocation(b, c.GetCenterOfUnits(P), H)
					end
				end
				if c.IsInRange(b, C, H) then
					return BOT_ACTION_DESIRE_HIGH, C:GetLocation()
				end
				if c.IsInRange(b, C, H + T) and not c.IsInRange(b, C, H) then
					return BOT_ACTION_DESIRE_HIGH, c.Site.GetXUnitsTowardsLocation(b, C:GetLocation(), H)
				end
			end
		end
	end
	if E and b:GetActiveModeDesire() > 0.75 then
		local P = c.GetNearbyHeroes(b, H, true, BOT_MODE_NONE)
		for M, N in pairs(P) do
			if
				c.IsValidHero(N)
				and c.CanCastOnNonMagicImmune(N)
				and c.IsChasingTarget(N, b)
				and b:IsFacingLocation(c.GetTeamFountain(), 30)
				and b:DistanceFromFountain() > 600
				and not c.IsSuspiciousIllusion(N)
				and not c.IsDisabled(N)
				and not c.IsRealInvisible(b)
			then
				local O = c.GetNearbyHeroes(N, 1200, true, BOT_MODE_NONE)
				local V = c.GetNearbyHeroes(N, 1200, false, BOT_MODE_NONE)
				if O ~= nil and V ~= nil and (#V > #O or b:WasRecentlyDamagedByAnyHero(2)) then
					return BOT_ACTION_DESIRE_HIGH, c.Site.GetXUnitsTowardsLocation(b, c.GetTeamFountain(), H)
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
return a
