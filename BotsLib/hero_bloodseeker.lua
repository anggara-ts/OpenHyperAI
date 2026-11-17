-- Bloodseeker: skill build, item build, and ability use for this hero.
local a = {}
local b = GetBot()
local c = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local d = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local e = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local f = c.Skill.GetTalentList(b)
local g = c.Skill.GetAbilityList(b)
local h = c.Item.GetRoleItemsBuyList(b)
local i = {
	{ ["t25"] = { 0, 10 }, ["t20"] = { 0, 10 }, ["t15"] = { 0, 10 }, ["t10"] = { 0, 10 } },
	{ ["t25"] = { 0, 10 }, ["t20"] = { 0, 10 }, ["t15"] = { 0, 10 }, ["t10"] = { 0, 10 } },
}
local j = { { 2, 3, 2, 1, 2, 6, 2, 1, 1, 1, 6, 3, 3, 3, 6 }, { 2, 3, 2, 1, 2, 6, 2, 1, 1, 1, 6, 3, 3, 3, 6 } }
local k = j[2]
if h == "pos_1" then
	k = j[1]
end
if h == "pos_2" then
	k = j[1]
end
if h == "pos_3" then
	k = j[2]
end
local l = c.Skill.GetTalentBuild(i[2])
if h == "pos_1" then
	l = c.Skill.GetTalentBuild(i[1])
end
if h == "pos_2" then
	l = c.Skill.GetTalentBuild(i[1])
end
if h == "pos_3" then
	l = c.Skill.GetTalentBuild(i[2])
end
local n = "item_team_aura"
local o = {}
o["pos_1"] = {
	"item_tango",
	"item_double_branches",
	"item_quelling_blade",
	"item_slippers",
	"item_circlet",
	"item_magic_wand",
	"item_wraith_band",
	"item_phase_boots",
	"item_maelstrom",
	"item_yasha",
	"item_black_king_bar",
	"item_sange_and_yasha",
	"item_mjollnir",
	"item_basher",
	"item_aghanims_shard",
	"item_abyssal_blade",
	"item_butterfly",
	"item_monkey_king_bar",
	"item_moon_shard",
	"item_ultimate_scepter_2",
}
o["pos_2"] = {
	"item_tango",
	"item_double_branches",
	"item_quelling_blade",
	"item_slippers",
	"item_circlet",
	"item_magic_wand",
	"item_wraith_band",
	"item_bottle",
	"item_phase_boots",
	"item_maelstrom",
	"item_yasha",
	"item_black_king_bar",
	"item_sange_and_yasha",
	"item_mjollnir",
	"item_basher",
	"item_aghanims_shard",
	"item_butterfly",
	"item_travel_boots",
	"item_abyssal_blade",
	"item_travel_boots_2",
	"item_moon_shard",
	"item_ultimate_scepter_2",
}
o["pos_3"] = {
	"item_tango",
	"item_double_branches",
	"item_quelling_blade",
	"item_magic_wand",
	"item_double_wraith_band",
	"item_boots",
	"item_phase_boots",
	"item_maelstrom",
	"item_black_king_bar",
	"item_mjollnir",
	"item_blade_mail",
	n,
	"item_basher",
	"item_travel_boots",
	"item_abyssal_blade",
	"item_travel_boots_2",
	"item_aghanims_shard",
	"item_moon_shard",
	"item_ultimate_scepter_2",
}
o["pos_4"] = o["pos_3"]
o["pos_5"] = o["pos_3"]
a["sBuyList"] = o[h]
a["sSellList"] = { "item_power_treads", "item_quelling_blade", "item_abyssal_blade", "item_magic_wand" }
if c.Role.IsPvNMode() or c.Role.IsAllShadow() then
	a["sBuyList"], a["sSellList"] = { "PvN_melee_carry" }, { "item_power_treads", "item_quelling_blade" }
end
k, l, a["sBuyList"], a["sSellList"] = c.SetUserHeroInit(k, l, a["sBuyList"], a["sSellList"])
a["sSkillList"] = c.Skill.GetSkillList(g, k, f, l)
a["bDeafaultAbility"] = false
a["bDeafaultItem"] = false
function a.MinionThink(p)
	e.MinionThink(p)
end
local q = SafeAbility(b:GetAbilityByName(g[1]), "sAbilityList[1]", "bloodseeker")
local r = SafeAbility(b:GetAbilityByName(g[2]), "sAbilityList[2]", "bloodseeker")
local s = SafeAbility(b:GetAbilityByName(g[6]), "sAbilityList[6]", "bloodseeker")
local u = SafeAbility(b:GetAbilityByName("bloodseeker_thirst"), "bloodseeker_thirst", "bloodseeker")
local v = 0
local w, x = 0
local y, z = 0
local B
local C
local D, E, F, G, H
local I
function a.SkillsComplement()
	if c.CanNotUseAbility(b) or b:IsInvisible() then
		return
	end
	I = c.IsAttacking(b)
	local J = d.Build(b)
	D = 300
	E = J.mp
	F = J.hp
	G = J.level
	H = J.enemies
	C = J.target
	B = a.ConsiderThirst()
	if B > 0 then
		c.SetQueuePtToINT(b, false)
		b:ActionQueue_UseAbility(u)
		return
	end
	y, z = a.ConsiderR()
	if y > 0 then
		c.SetQueuePtToINT(b, false)
		b:ActionQueue_UseAbilityOnEntity(s, z)
		return
	end
	v = a.ConsiderQ()
	if v > 0 then
		b:Action_ClearActions(false)
		b:ActionQueue_UseAbility(q)
		return
	end
	w, x = a.ConsiderW()
	if w > 0 then
		c.SetQueuePtToINT(b, false)
		b:ActionQueue_UseAbilityOnLocation(r, x)
		return
	end
end
function a.ConsiderThirst()
	if not c.CanCastAbility(u) then
		return BOT_MODE_NONE
	end
	if c.IsGoingOnSomeone(b) then
		if c.IsValidHero(C) and c.CanCastOnMagicImmune(C) and c.IsInRange(C, b, 600) then
			if not b:HasModifier("modifier_bloodseeker_thirst") then
				return BOT_ACTION_DESIRE_HIGH, b
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function a.ConsiderQ()
	if not q:IsFullyCastable() then
		return 0
	end
	if b:HasModifier("modifier_bloodseeker_bloodrage") then
		return 0
	end
	local M = b:GetAttackDamage()
	if c.IsInTeamFight(b, 1200) or c.IsPushing(b) or c.IsDefending(b) then
		local N = c.GetNearbyHeroes(b, 1200, true, BOT_MODE_NONE)
		if #N >= 1 then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if c.IsGoingOnSomeone(b) then
		if c.IsValidHero(C) and c.CanCastOnMagicImmune(C) and c.IsInRange(C, b, 600) then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if c.IsValid(C) and C:GetTeam() == TEAM_NEUTRAL then
		local O = b:GetNearbyCreeps(1000, true)
		for P, Q in pairs(O) do
			if c.IsValid(Q) and not c.CanKillTarget(Q, M, DAMAGE_TYPE_PHYSICAL) then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	if c.IsDoingRoshan(b) then
		if c.IsRoshan(C) and c.IsInRange(b, C, b:GetAttackRange()) and I then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if c.IsDoingTormentor(b) then
		if c.IsTormentor(C) and c.IsInRange(b, C, b:GetAttackRange()) and I then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function a.ConsiderW()
	if not r:IsFullyCastable() then
		return 0
	end
	local K = 600
	local R = r:GetCastRange()
	local S = r:GetCastPoint()
	local T = r:GetSpecialValueFloat("delay")
	local U = r:GetManaCost()
	local M = r:GetSpecialValueInt("damage")
	local N = c.GetNearbyHeroes(b, R, true, BOT_MODE_NONE)
	local V = c.GetNearbyHeroes(b, 800, false, BOT_MODE_NONE)
	for P, W in pairs(N) do
		if c.IsValid(W) and c.CanCastOnNonMagicImmune(W) and c.CanKillTarget(W, M, DAMAGE_TYPE_PURE) then
			if W:GetMovementDirectionStability() >= 0.75 then
				return BOT_ACTION_DESIRE_HIGH, W:GetExtrapolatedLocation(T)
			else
				return BOT_ACTION_DESIRE_HIGH, W:GetLocation()
			end
		end
	end
	if b:GetActiveMode() == BOT_MODE_LANING and c.IsAllowedToSpam(b, U) then
		local X = b:FindAoELocation(true, false, b:GetLocation(), 1000, K / 2, S, M)
		if X.count >= 4 then
			return BOT_ACTION_DESIRE_MODERATE, X.targetloc
		end
	end
	-- Parenthesised: without them "or" let this fire with no push/defend at all whenever no enemy hero was near.
	if (c.IsPushing(b) or c.IsDefending(b)) and c.IsAllowedToSpam(b, U) and (N == nil or #N == 0) and #V <= 2 then
		local Y = b:GetNearbyLaneCreeps(1000, true)
		local X = b:FindAoELocation(true, false, b:GetLocation(), 1000, K / 2, S, M)
		if X.count >= 4 and #Y >= 4 then
			return BOT_ACTION_DESIRE_MODERATE, X.targetloc
		end
	end
	if c.IsRetreating(b) then
		for P, W in pairs(N) do
			if c.IsValid(W) and b:WasRecentlyDamagedByHero(W, 1.0) and c.CanCastOnNonMagicImmune(W) then
				return BOT_ACTION_DESIRE_HIGH, b:GetLocation()
			end
		end
	end
	if c.IsInTeamFight(b, 1200) then
		local X = b:FindAoELocation(true, true, b:GetLocation(), R - 200, K / 2, S, 0)
		if X.count >= 2 then
			local Z = c.GetInvUnitInLocCount(b, R, K / 2, X.targetloc, false)
			if Z >= X.count then
				return BOT_ACTION_DESIRE_MODERATE, X.targetloc
			end
		end
	end
	if c.IsGoingOnSomeone(b) then
		if c.IsValidHero(C) and c.CanCastOnNonMagicImmune(C) and c.IsInRange(C, b, R + K) then
			local _ = c.GetDelayCastLocation(b, C, R, K, 2.0)
			if _ ~= nil then
				return BOT_ACTION_DESIRE_HIGH, _
			end
		end
	end
	if c.IsDoingRoshan(b) then
		if c.IsRoshan(C) and c.IsInRange(b, C, R) and I then
			return BOT_ACTION_DESIRE_HIGH, C:GetLocation()
		end
	end
	if c.IsDoingTormentor(b) then
		if c.IsTormentor(C) and c.IsInRange(b, C, R) and I then
			return BOT_ACTION_DESIRE_HIGH, C:GetLocation()
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function a.ConsiderR()
	if not s:IsFullyCastable() then
		return 0
	end
	local R = s:GetCastRange()
	local S = s:GetCastPoint()
	local U = s:GetManaCost()
	local N = c.GetNearbyHeroes(b, R + 200, true, BOT_MODE_NONE)
	-- fix: Rupture has DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES / SPELL_IMMUNITY_ENEMIES_YES (game data),
	-- so the three target checks below now accept BKB heroes (was CanCastOnNonMagicImmune).
	if c.IsRetreating(b) then
		for P, W in pairs(N) do
			if
				b:WasRecentlyDamagedByHero(W, 1.0)
				and c.CanCastOnMagicImmune(W)
				and c.CanCastOnTargetAdvanced(W)
				and not W:HasModifier("modifier_bloodseeker_bloodrage")
				and not W:HasModifier("modifier_bloodseeker_rupture")
			then
				return BOT_ACTION_DESIRE_MODERATE, W
			end
		end
	end
	if c.IsInTeamFight(b, 1200) then
		for P, W in pairs(N) do
			if
				c.CanCastOnMagicImmune(W)
				and c.CanCastOnTargetAdvanced(W)
				and c.Role.IsCarry(W:GetUnitName())
				and not W:HasModifier("modifier_bloodseeker_bloodrage")
				and not W:HasModifier("modifier_bloodseeker_rupture")
				and not c.IsDisabled(W)
			then
				return BOT_ACTION_DESIRE_HIGH, W
			end
		end
	end
	if c.IsGoingOnSomeone(b) then
		if
			c.IsValidHero(C)
			and c.CanCastOnMagicImmune(C)
			and c.CanCastOnTargetAdvanced(C)
			and c.IsInRange(C, b, R + 100)
			and not C:HasModifier("modifier_bloodseeker_bloodrage")
			and not C:HasModifier("modifier_bloodseeker_rupture")
			and not c.IsDisabled(C)
		then
			local a0 = c.GetNearbyHeroes(C, 1200, true, BOT_MODE_NONE)
			if a0 ~= nil and #a0 >= 2 then
				return BOT_ACTION_DESIRE_HIGH, C
			end
			-- fix: a0 counts Bloodseeker himself, so ">= 2" meant a solo gank never ruptured. Alone,
			-- rupture a target already below half HP (it cannot run without bleeding).
			if c.GetHP(C) < 0.5 and not c.IsSuspiciousIllusion(C) then
				if DotaTime() >= (b._bsRuptureLogAt or -999) then
					b._bsRuptureLogAt = DotaTime() + 10
					pcall(print, string.format(
						"[OHA-BLOODSEEKER] t=%.0f rupture solo %s hp=%.2f",
						DotaTime(),
						(string.gsub(C:GetUnitName(), "npc_dota_hero_", "")),
						c.GetHP(C)
					))
				end
				return BOT_ACTION_DESIRE_HIGH, C
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
return a
