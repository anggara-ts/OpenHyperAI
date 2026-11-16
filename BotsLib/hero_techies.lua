-- Techies: skill build, item build, and ability use for this hero.
local a = {}
local b = GetBot()
local c = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local ChargeTracker = require(GetScriptDirectory() .. "/FuncLib/systems/charge_tracker")
local d = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local e = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local f = require(GetScriptDirectory() .. "/FuncLib/hero/techies")
local g = c.Skill.GetTalentList(b)
local h = c.Skill.GetAbilityList(b)
local i = c.Item.GetRoleItemsBuyList(b)
local j = { ["t25"] = { 10, 0 }, ["t20"] = { 10, 0 }, ["t15"] = { 0, 10 }, ["t10"] = { 10, 0 } }
-- 1 Sticky Bomb, 2 Reactive Tazer, 3 Blast Off, 6 Proximity Mines (ultimate). Entries skip
-- talent levels (talent picks are unchanged); ultimate points stay at levels 6, 12 and 17.
-- One point in each at levels 1-3, then Sticky Bomb maxed first (level 7), Blast Off next
-- (level 11), Reactive Tazer last (level 16). Was Blast Off first, then Sticky Bomb.
local k = { { 1, 2, 3, 1, 1, 6, 1, 3, 3, 3, 6, 2, 2, 2, 6 } }
local l = c.Skill.GetRandomBuild(k)
local m = c.Skill.GetTalentBuild(j)
local n = {}
n["pos_4"] = {
	-- Arcane Boots already cover mana, so this build keeps Magic Wand instead of Soul Ring.
	"item_double_tango",
	"item_double_branches",
	"item_blood_grenade",
	"item_boots",
	"item_magic_wand",
	"item_arcane_boots",
	"item_kaya",
	-- Shard, then Aghanim's Scepter, then Guardian Greaves (user call).
	"item_aghanims_shard",
	"item_ultimate_scepter",
	"item_guardian_greaves",
	"item_force_staff",
	"item_lotus_orb",
	"item_veil_of_discord",
	"item_bloodstone",
	"item_yasha_and_kaya",
	"item_sheepstick",
	"item_moon_shard",
	"item_ultimate_scepter_2",
}
n["pos_5"] = {
	-- 600 starting gold: Soul Ring parts (455) + Tango (90) + Blood Grenade (50) = 595.
	-- The recipe (350) finishes Soul Ring after Boots, in place of Magic Wand.
	"item_tango",
	"item_blood_grenade",
	"item_ring_of_protection",
	"item_double_gauntlets",
	"item_boots",
	"item_soul_ring",
	"item_tranquil_boots",
	"item_kaya",
	"item_pipe",
	"item_force_staff",
	"item_boots_of_bearing",
	"item_veil_of_discord",
	"item_bloodstone",
	"item_yasha_and_kaya",
	"item_sheepstick",
	"item_aghanims_shard",
	"item_moon_shard",
	"item_ultimate_scepter_2",
}
n["pos_3"] = {
	-- 600 starting gold: Soul Ring parts (455) + Tango (90) + Branches (55) = 600.
	"item_tango",
	"item_branches",
	"item_ring_of_protection",
	"item_double_gauntlets",
	"item_boots",
	"item_soul_ring",
	"item_tranquil_boots",
	"item_kaya",
	"item_force_staff",
	"item_kaya_and_sange",
	"item_boots_of_bearing",
	"item_veil_of_discord",
	"item_bloodstone",
	"item_yasha_and_kaya",
	"item_sheepstick",
	"item_aghanims_shard",
	"item_moon_shard",
	"item_ultimate_scepter_2",
}
n["pos_1"] = {
	"item_crystal_maiden_outfit",
	"item_kaya",
	"item_kaya_and_sange",
	"item_aether_lens",
	"item_black_king_bar",
	"item_shivas_guard",
	"item_aghanims_shard",
	"item_veil_of_discord",
	"item_bloodstone",
	"item_yasha_and_kaya",
	"item_moon_shard",
	"item_ultimate_scepter_2",
	"item_travel_boots_2",
}
n["pos_2"] = n["pos_1"]
a["sBuyList"] = n[i]
a["sSellList"] = { "item_black_king_bar", "item_quelling_blade" }
if c.Role.IsPvNMode() or c.Role.IsAllShadow() then
	a["sBuyList"], a["sSellList"] = { "PvN_antimage" }, {}
end
l, m, a["sBuyList"], a["sSellList"] = c.SetUserHeroInit(l, m, a["sBuyList"], a["sSellList"])
a["sSkillList"] = c.Skill.GetSkillList(h, l, g, m)
a["bDeafaultAbility"] = false
a["bDeafaultItem"] = false
function a.MinionThink(o)
	e.MinionThink(o)
end
local p = SafeAbility(b:GetAbilityByName("techies_sticky_bomb"), "techies_sticky_bomb", "techies")
local q = SafeAbility(b:GetAbilityByName("techies_reactive_tazer"), "techies_reactive_tazer", "techies")
local r = SafeAbility(b:GetAbilityByName("techies_reactive_tazer_stop"), "techies_reactive_tazer_stop", "techies")
local s = SafeAbility(b:GetAbilityByName("techies_suicide"), "techies_suicide", "techies")
local t = SafeAbility(b:GetAbilityByName("techies_minefield_sign"), "techies_minefield_sign", "techies")
local u = SafeAbility(b:GetAbilityByName("techies_land_mines"), "techies_land_mines", "techies")
local mad = SafeAbility(
	b:GetAbilityByName("techies_mutually_assured_destruction"),
	"techies_mutually_assured_destruction",
	"techies"
)
local madStop = SafeAbility(b:GetAbilityByName("techies_focused_detonate"), "techies_focused_detonate", "techies")
local v, w
local x, xTarget
local y, z, yWhy
local A, B
local C, D
local E = 0
local F, G, Flag
local H, I, J, K, L
local M
local N
local O
local P
-- M.A.D. (7.41 patch notes): a passive innate. Aghanim's Shard adds an active part: plant an
-- invisible barrel (450 range, 30s cooldown, 1s cast point, 200 HP), then detonate it with a
-- sub-ability; detonated, it turns visible and immortal and explodes 1.5s later. Only one planted
-- barrel at a time. The in-game names of the plant and detonate abilities are not in Valve's data,
-- so they are found at runtime among his abilities: the plant is a non-passive, point or AoE
-- targeted M.A.D. ability; the detonate is a no-target one ("detonate" in its name preferred;
-- not Sticky Bomb's). With Shard, every candidate is logged once (name, behavior, passive, hidden),
-- so the next game shows the real names.
-- Behavior bits (Valve: no target 4, point 16, AoE 32); the named constants may be missing.
local BEH_NO_TARGET = ABILITY_BEHAVIOR_NO_TARGET or DOTA_ABILITY_BEHAVIOR_NO_TARGET or 4
local BEH_POINT = ABILITY_BEHAVIOR_POINT or DOTA_ABILITY_BEHAVIOR_POINT or 16
local BEH_AOE = ABILITY_BEHAVIOR_AOE or DOTA_ABILITY_BEHAVIOR_AOE or 32
local function MadCandidates()
	local list = {}
	for slot = 0, 30 do
		local ab = b:GetAbilityInSlot(slot)
		if ab ~= nil and not ab:IsNull() then
			local n = ab:GetName()
			if
				string.find(n, "techies", 1, true)
				and (
					string.find(n, "mutually", 1, true)
					or string.find(n, "detonate", 1, true)
					or string.find(n, "barrel", 1, true)
					or string.find(n, "_mad", 1, true)
				)
				and not string.find(n, "sticky", 1, true)
			then
				list[#list + 1] = ab
			end
		end
	end
	return list
end
local function Behavior(ab)
	local ok, v = pcall(function()
		return ab:GetBehavior()
	end)
	return ok and v or 0
end
-- Logged whenever the set of M.A.D. abilities (and their castable/hidden state) changes, with or
-- without the Shard buff: game 017, Techies had the barrel unlocked but HasAghanimsShard (the
-- modifier_item_aghanims_shard buff) never let this run, so nothing was logged or planted.
local function LogMadCandidates(list)
	local sig = {}
	for _, ab in ipairs(list) do
		sig[#sig + 1] = ab:GetName() .. (ab:IsHidden() and "h" or "") .. (ab:IsTrained() and "t" or "")
	end
	local key = table.concat(sig, ",")
	if key == b._madNamesLogged then
		return
	end
	b._madNamesLogged = key
	local parts = {}
	for _, ab in ipairs(list) do
		local okP, passive = pcall(function()
			return ab:IsPassive()
		end)
		parts[#parts + 1] = string.format(
			"%s(beh=%s passive=%s hidden=%s castable=%s)",
			ab:GetName(),
			tostring(Behavior(ab)),
			tostring(okP and passive),
			tostring(ab:IsHidden()),
			tostring(ab:IsFullyCastable())
		)
	end
	pcall(print, string.format("[OHA-TECHIES] t=%.0f mad-abilities %s", DotaTime(), table.concat(parts, " ")))
end
-- The planted barrel is the unit npc_dota_techies_remote_mine (Liquipedia, M.A.D. page). Logged
-- when one of ours appears and when it is gone, to confirm a plant and a detonation in game.
function a.WatchBarrel()
	-- npc_dota_techies_remote_mine also matches his Sticky Bombs (game 018: 61 seen/gone pairs
	-- from 0:33, before the Shard). Only watch for 6s after a plant order.
	if b._madPlantAt == nil or DotaTime() - b._madPlantAt > 6 then
		return
	end
	local found = nil
	for _, u in pairs(GetUnitList(UNIT_LIST_ALLIES) or {}) do
		if u ~= nil and not u:IsNull() and u:GetUnitName() == "npc_dota_techies_remote_mine" then
			found = u
			break
		end
	end
	if found ~= nil and not b._barrelSeen then
		b._barrelSeen = true
		local p0 = found:GetLocation()
		pcall(print, string.format("[OHA-TECHIES] t=%.0f mad-barrel seen at=%.0f,%.0f", DotaTime(), p0.x, p0.y))
	elseif found == nil and b._barrelSeen then
		b._barrelSeen = false
		pcall(print, string.format("[OHA-TECHIES] t=%.0f mad-barrel gone", DotaTime()))
	end
end
-- The barrel plant ability, or nil (no Shard, or not found / not castable). Game 018 at 25:12
-- (Shard bought): techies_mutually_assured_destruction itself turned active (behavior 48 = point
-- + AoE, not passive, not hidden, castable). No IsTrained check: an innate has no skill points.
function a.MadPlant()
	local list = MadCandidates()
	for _, ab in ipairs(list) do
		local okP, passive = pcall(function()
			return ab:IsPassive()
		end)
		local beh = Behavior(ab)
		local targeted = c.CheckBitfieldFlag(beh, BEH_POINT) or c.CheckBitfieldFlag(beh, BEH_AOE)
		if
			not (okP and passive)
			and not ab:IsHidden()
			and targeted
			and not string.find(ab:GetName(), "detonate", 1, true)
			and ab:IsFullyCastable()
		then
			return ab
		end
	end
	return nil
end
-- The detonate sub-ability (no target), or nil. A "detonate" name first, then any castable
-- no-target, non-passive M.A.D. ability (the plant is point targeted, so it never matches).
function a.MadDetonate()
	local fallback = nil
	for _, ab in ipairs(MadCandidates()) do
		-- Not hidden: techies_focused_detonate shows once a barrel is down (game 018: every
		-- mad-detonate came after a plant). Ordering it while hidden could cut the plant cast short.
		if not ab:IsHidden() and ab:IsFullyCastable() then
			local okP, passive = pcall(function()
				return ab:IsPassive()
			end)
			local beh = Behavior(ab)
			local noTarget = c.CheckBitfieldFlag(beh, BEH_NO_TARGET) and not c.CheckBitfieldFlag(beh, BEH_POINT)
			if not (okP and passive) and noTarget then
				if string.find(ab:GetName(), "detonate", 1, true) then
					return ab
				end
				fallback = fallback or ab
			end
		end
	end
	return fallback
end
-- Plant M.A.D. and detonate it right away. The barrel counts as out only until the planned
-- detonate time + 2s: a plant that never landed (interrupted) used to block the next one for
-- 45s (game 018: three Blast Off combos without M.A.D. for that reason).
-- The plant hold: no other spell (or item) order until M.A.D. is on cooldown or the hold ends.
function a.MadHoldActive()
	if DotaTime() >= (b._madHoldUntil or -999) then
		return false
	end
	local plantAb = b:GetAbilityByName("techies_mutually_assured_destruction")
	if plantAb ~= nil and plantAb:GetCooldownTimeRemaining() > 0 then
		b._madHoldUntil = nil
		return false
	end
	return true
end
function a.PlantMad(plant, loc, tag)
	local castPoint = math.max(0.3, plant:GetCastPoint())
	-- Always inside cast range, so the order is a cast and not a walk first (game 021: all 7
	-- failed plants had M.A.D. off cooldown, never cast; a walk-in leaves time for other orders).
	local range = plant:GetCastRange()
	if range == nil or range < 100 then
		range = 450
	end
	if GetUnitToLocationDistance(b, loc) > range - 20 then
		loc = c.Utils.GetOffsetLocationTowardsTargetLocation(b:GetLocation(), loc, range - 40)
	end
	b._madLoc = loc
	b._madDetonateAt = DotaTime() + castPoint + 0.15
	-- 4s after the planned detonate: game 019, plants into a spot beyond cast range (he walks in
	-- first) showed the barrel 2-3s after the order, past the old 2s window.
	b._madUntil = b._madDetonateAt + 4
	b._madPlantAt = DotaTime()
	-- No other spell order until the plant is cast: game 019, 8 of 15 plants failed because the
	-- next think sent Sticky Bomb, the Tazer, a mine or Blast Off and cut the cast short (43:01:
	-- post-blast plant and post-blast Sticky in the same second).
	-- Held until M.A.D. is on cooldown (the plant was cast) or 1.2s pass; see MadHoldActive.
	b._madHoldUntil = DotaTime() + math.max(castPoint + 0.25, 1.2)
	a.LogTechies("mad-plant " .. plant:GetName() .. (tag and (" " .. tag) or ""), 0, loc)
	b:Action_UseAbilityOnLocation(plant, loc)
end
-- Landing from Blast Off: M.A.D. right after the mines, before Sticky Bomb, once per Blast Off.
-- Aimed at the stunned enemy hero by the landing spot (or where the nearest one is heading). No
-- "recently hit" rule here: right after landing he is almost always being hit.
function a.ConsiderPostBlastMad()
	if b._blastAt == nil or b._madBlastAt == b._blastAt then
		return nil, nil
	end
	local since = DotaTime() - b._blastAt
	if since < 1.75 or since > 6 then
		return nil, nil
	end
	if b._madLoc ~= nil and DotaTime() < (b._madUntil or 0) then
		return nil, nil
	end
	local plant = a.MadPlant()
	if plant == nil then
		return nil, nil
	end
	local range = plant:GetCastRange()
	if range == nil or range < 100 then
		range = 450
	end
	range = c.GetProperCastRange(false, b, range)
	local best, bestScore = nil, math.huge
	for _, e0 in pairs(c.GetNearbyHeroes(b, range + 250, true, BOT_MODE_NONE) or {}) do
		if c.IsValidHero(e0) and not c.IsSuspiciousIllusion(e0) then
			local d0 = GetUnitToUnitDistance(b, e0)
			-- A disabled one first (the Blast Off stun), then the nearest.
			local score = d0 - (c.IsDisabled(e0) and 10000 or 0)
			if score < bestScore then
				best, bestScore = e0, score
			end
		end
	end
	if best == nil then
		return nil, nil
	end
	local loc = best:GetLocation()
	if not c.IsDisabled(best) then
		loc = best:GetExtrapolatedLocation(math.max(0.3, plant:GetCastPoint()) + 0.3)
	end
	if GetUnitToLocationDistance(b, loc) > range then
		loc = c.Utils.GetOffsetLocationTowardsTargetLocation(b:GetLocation(), loc, range - 40)
	end
	return plant, loc
end
function a.SkillsComplement()
	-- Detonate M.A.D. still works while Techies is dead or already acting.
	if a.ConsiderDetonateMad() > 0 then
		local det = a.MadDetonate()
		if det ~= nil then
			a.LogTechies("mad-detonate", 0, b._madLoc or b:GetLocation())
			b:Action_UseAbility(det)
		end
		b._madLoc = nil
		b._madDetonateAt = nil
		return
	end
	if c.CanNotUseAbility(b) then
		return
	end
	if a.MadHoldActive() then
		return
	end
	local Q = d.Build(b)
	M = Q.isEngaging
	N = Q.isRetreating
	O = c.IsAttacking(b)
	P = Q.hp
	H = Q.target
	I = s:GetSpecialValueInt("damage")
	J = u:GetSpecialValueInt("damage")
	K = J * 2
	L = I + K
	-- Blast Off first, never waiting on the Tazer. The Tazer and the mines are extras queued
	-- behind it when they are up: the Tazer on Techies after he lands (speed, and a disarm on
	-- whoever hits him in the middle of the fight), then mines around the stunned target.
	-- The old order put the Tazer first (0.1s cast and a 0.6s wait), which delayed the stun,
	-- and Blast Off was held back whenever the Tazer was not ready to go with it.
	-- Just landed from Blast Off: plant the mine triangle first, one mine per think. The mines
	-- queued behind Blast Off are wiped by any other order before he lands (17:30: blast, no
	-- mines), and the stunned-target rule below runs too late, after Tazer and Sticky Bomb.
	-- Landed: Veil of Discord first (enemies take more spell damage), then the mine triangle,
	-- then Sticky Bomb on the nearest enemy hero.
	local veil = a.ConsiderPostBlastVeil()
	if veil ~= nil then
		b._veilBlastAt = b._blastAt
		a.LogTechies("post-blast-veil", 0, b:GetLocation())
		b:Action_UseAbility(veil)
		return
	end
	-- Scepter: Minefield Sign first (one per Blast Off), on himself (10 range): the triangle goes
	-- around him, inside its radius, invulnerable and with +15% damage (Valve data).
	if a.ConsiderPostBlastSign() then
		b._signBlastAt = b._blastAt
		a.LogTechies("post-blast-sign", 0, b:GetLocation())
		b:Action_UseAbilityOnLocation(t, b:GetLocation())
		return
	end
	local postMine = a.ConsiderPostBlastMines()
	if postMine ~= nil then
		a.OrderMine(postMine, "post-blast")
		return
	end
	local madPlant, madLoc = a.ConsiderPostBlastMad()
	if madPlant ~= nil then
		b._madBlastAt = b._blastAt
		a.PlantMad(madPlant, madLoc, "post-blast")
		return
	end
	local stickyLoc = a.ConsiderPostBlastSticky()
	if stickyLoc ~= nil then
		b._stickyBlastAt = b._blastAt
		a.LogTechies("post-blast-sticky", 0, stickyLoc)
		b:Action_UseAbilityOnLocation(p, stickyLoc)
		return
	end
	-- Then out with Force Staff: turn toward home first (it pushes the way he faces).
	if a.ConsiderPostBlastEscape() then
		return
	end
	-- Short on mana for a Blast Off that is otherwise ready: Soul Ring now, Blast Off next think.
	if a.ConsiderSoulRingForBlast() then
		return
	end
	y, z, yWhy = a.ConsiderBlastOff()
	if y > 0 then
		b:Action_ClearActions(false)
		-- Sticky Bomb first (user call), then Blast Off: only when it is ready, an enemy hero is
		-- in its cast range and near the landing spot, and there is mana for both. Otherwise
		-- Blast Off goes alone, as before; Sticky never holds it back.
		local stickyFirst = false
		local manaLeft = b:GetMana() - s:GetManaCost()
		if yWhy ~= "escape" and p:IsTrained() and p:IsFullyCastable() and manaLeft >= p:GetManaCost() then
			local range = p:GetCastRange() + 100
			local best, bestD = nil, math.huge
			for _, e0 in pairs(c.GetNearbyHeroes(b, range, true, BOT_MODE_NONE) or {}) do
				if
					c.IsValidHero(e0)
					and c.CanCastOnNonMagicImmune(e0)
					and not c.IsSuspiciousIllusion(e0)
					and GetUnitToLocationDistance(e0, z) <= 450
				then
					local d0 = GetUnitToLocationDistance(e0, z)
					if d0 < bestD then
						best, bestD = e0, d0
					end
				end
			end
			if best ~= nil then
				local stickyLoc = c.IsDisabled(best) and best:GetLocation() or best:GetExtrapolatedLocation(0.5)
				b:ActionQueue_UseAbilityOnLocation(p, stickyLoc)
				manaLeft = manaLeft - p:GetManaCost()
				stickyFirst = true
				a.LogTechies("pre-blast-sticky", 0, stickyLoc)
			end
		end
		b:ActionQueue_UseAbilityOnLocation(s, z)
		-- The cast point is spent before the next queued order; the 0.75s flight is not.
		b:ActionQueue_Delay(math.max(0.3, s:GetSpecialValueFloat("duration")) + 0.1)
		local tazer = false
		if a.TazerUsable() and manaLeft >= q:GetManaCost() then
			if a.TazerIsUnitTarget() then
				b:ActionQueue_UseAbilityOnEntity(q, b)
			else
				b:ActionQueue_UseAbility(q)
			end
			b._tazerCastAt = DotaTime()
			manaLeft = manaLeft - q:GetManaCost()
			tazer = true
		end
		local planted = 0
		if yWhy ~= "escape" and u:IsTrained() and not u:IsHidden() then
			local mineCost = u:GetManaCost()
			local maxMines = math.min(a.MineCharges(), mineCost > 0 and math.floor(manaLeft / mineCost) or 3)
			for _, spot in ipairs(a.MineTriangle(z, 210)) do
				if planted >= maxMines then
					break
				end
				b:ActionQueue_UseAbilityOnLocation(u, spot)
				planted = planted + 1
			end
			if planted > 0 then
				pcall(ChargeTracker.Issued, b, u, nil, planted)
			end
		end
		a.LogTechies(string.format("blast why=%s tazer=%s", yWhy or "?", tostring(tazer)), planted, z)
		if yWhy ~= "escape" then
			-- With Sticky in front, Blast Off starts one Sticky cast later; the landing steps
			-- (mines, M.A.D., ...) are timed from here.
			b._blastAt = DotaTime() + (stickyFirst and math.max(0, p:GetCastPoint()) or 0)
			b._blastLoc = z
			if stickyFirst then
				-- Sticky already thrown: no second one after landing.
				b._stickyBlastAt = b._blastAt
			end
		end
		return
	end
	x, xTarget = a.ConsiderReactiveTazer()
	if x > 0 then
		-- Unit-target only in a version where it can go on an ally. Otherwise it is a self cast.
		if a.TazerIsUnitTarget() then
			b:Action_UseAbilityOnEntity(q, xTarget or b)
		else
			b:Action_UseAbility(q)
		end
		b._tazerCastAt = DotaTime()
		return
	end
	-- No manual Tazer detonation. Popping it early throws away the speed and the disarm on
	-- attackers, and the blast goes off by itself when the buff ends.
	v, w = a.ConsiderStickyBomb()
	if v > 0 then
		b:Action_UseAbilityOnLocation(p, w)
		return
	end
	C, D = a.ConsiderPlantMad()
	if C > 0 then
		a.PlantMad(a.MadPlant(), D)
		return
	end
	C, D = a.ConsiderProximityMines()
	if C > 0 then
		a.OrderMine(D, a._mineKind or "mine")
		E = DotaTime()
		return
	end
	A, B = a.ConsiderMineFieldSign()
	if A > 0 then
		b:Action_UseAbilityOnLocation(t, B)
		return
	end
end
function a.ConsiderStickyBomb()
	if not p:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
	end
	local T = c.GetProperCastRange(false, b, p:GetCastRange())
	local U = p:GetSpecialValueInt("damage")
	local V = p:GetSpecialValueInt("speed")
	local W = p:GetSpecialValueInt("acceleration")
	local X = p:GetLevel()
	local Y = c.GetNearbyHeroes(b, T, true, BOT_MODE_NONE)
	for Z, _ in pairs(Y) do
		if
			c.IsValidHero(_)
			and c.CanCastOnNonMagicImmune(_)
			and c.CanKillTarget(_, U, DAMAGE_TYPE_MAGICAL)
			and not c.IsSuspiciousIllusion(_)
			and not _:HasModifier("modifier_abaddon_borrowed_time")
			and not _:HasModifier("modifier_dazzle_shallow_grave")
			and not _:HasModifier("modifier_necrolyte_reapers_scythe")
			and not _:HasModifier("modifier_oracle_false_promise_timer")
			and not _:HasModifier("modifier_templar_assassin_refraction_absorb")
		then
			local a0 = c.GetETAWithAcceleration(GetUnitToUnitDistance(b, _), V, W)
			if c.IsChasingTarget(b, _) then
				return BOT_ACTION_DESIRE_HIGH, _:GetExtrapolatedLocation(a0)
			else
				return BOT_ACTION_DESIRE_HIGH, _:GetLocation()
			end
		end
	end
	local a1 = c.GetNearbyHeroes(b, T, false, BOT_MODE_NONE)
	for Z, a2 in pairs(a1) do
		local a3 = c.GetNearbyHeroes(a2, 1200, true, BOT_MODE_NONE)
		for Z, _ in pairs(a3) do
			if
				c.IsValidHero(a2)
				and c.IsRetreating(a2)
				and a2:WasRecentlyDamagedByAnyHero(1.5)
				and not a2:IsIllusion()
			then
				if
					c.IsValidHero(_)
					and c.CanCastOnNonMagicImmune(_)
					and c.IsInRange(b, _, T)
					and c.IsChasingTarget(_, a2)
					and not c.IsDisabled(_)
					and not c.IsTaunted(_)
					and not c.IsSuspiciousIllusion(_)
					and not _:HasModifier("modifier_necrolyte_reapers_scythe")
				then
					local a0 = c.GetETAWithAcceleration(GetUnitToUnitDistance(b, _), V, W)
					if c.IsChasingTarget(_, a2) then
						return BOT_ACTION_DESIRE_HIGH, _:GetExtrapolatedLocation(a0)
					else
						return BOT_ACTION_DESIRE_HIGH, _:GetLocation()
					end
				end
			end
		end
	end
	if M then
		if
			c.IsValidTarget(H)
			and c.CanCastOnNonMagicImmune(H)
			and c.IsInRange(b, H, T)
			and not c.IsSuspiciousIllusion(H)
			and not H:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			local a4 = c.GetNearbyHeroes(H, 1200, true, BOT_MODE_NONE)
			local a5 = c.GetNearbyHeroes(H, 1200, false, BOT_MODE_NONE)
			if a4 ~= nil and a5 ~= nil and #a4 >= #a5 then
				local a0 = c.GetETAWithAcceleration(GetUnitToUnitDistance(b, H), V, W)
				if c.IsChasingTarget(b, H) then
					return BOT_ACTION_DESIRE_HIGH, H:GetExtrapolatedLocation(a0)
				else
					return BOT_ACTION_DESIRE_HIGH, H:GetLocation()
				end
			end
		end
	end
	if N then
		local a5 = c.GetNearbyHeroes(b, T, true, BOT_MODE_NONE)
		for Z, _ in pairs(a5) do
			if
				c.IsValidHero(_)
				and c.CanCastOnNonMagicImmune(_)
				and c.IsChasingTarget(_, b)
				and not c.IsSuspiciousIllusion(_)
				and not c.IsDisabled(_)
			then
				local a4 = c.GetNearbyHeroes(_, 1200, true, BOT_MODE_NONE)
				local a6 = c.GetNearbyHeroes(_, 1200, false, BOT_MODE_NONE)
				if a4 ~= nil and a6 ~= nil and (#a6 > #a4 or b:WasRecentlyDamagedByAnyHero(2)) then
					return BOT_ACTION_DESIRE_HIGH, (b:GetLocation() + _:GetLocation()) / 2
				end
			end
		end
	end
	if (c.IsPushing(b) or c.IsDefending(b)) and X >= 3 and not c.IsThereNonSelfCoreNearby(1000) then
		local a7 = b:GetNearbyLaneCreeps(1600, true)
		if a7 ~= nil and #a7 >= 4 and c.GetMP(b) > 0.5 then
			return BOT_ACTION_DESIRE_HIGH, c.GetCenterOfUnits(a7)
		end
	end
	if c.IsFarming(b) and c.GetManaAfter(p:GetManaCost()) > 0.3 then
		local a8 = b:GetNearbyNeutralCreeps(T)
		if a8 ~= nil then
			if #a8 >= 2 or #a8 >= 1 and c.IsValid(a8[1]) and a8[1]:IsAncientCreep() then
				return BOT_ACTION_DESIRE_HIGH, a8[1]:GetLocation()
			end
		end
		local a7 = b:GetNearbyLaneCreeps(T, true)
		if a7 ~= nil then
			if #a7 >= 3 then
				return BOT_ACTION_DESIRE_HIGH, c.GetCenterOfUnits(a7)
			end
		end
	end
	if c.IsLaning(b) then
		local a9 = {}
		local a7 = b:GetNearbyLaneCreeps(T, true)
		local a5 = c.GetNearbyHeroes(b, T, true, BOT_MODE_NONE)
		for Z, _ in pairs(a5) do
			if c.IsValidHero(_) and c.CanCastOnNonMagicImmune(_) and not c.IsSuspiciousIllusion(_) then
				local aa = _:GetNearbyTowers(600, true)
				if aa ~= nil and #aa >= 1 and c.IsValidBuilding(aa[1]) and aa[1]:GetAttackTarget() == _ then
					return BOT_ACTION_DESIRE_HIGH, _:GetLocation()
				end
			end
		end
		-- The bomb latches the nearest enemy hero at the landing spot. A lane poke is worth the mana.
		if c.GetManaAfter(p:GetManaCost()) > 0.4 then
			for Z, _ in pairs(a5) do
				if
					c.IsValidHero(_)
					and c.CanCastOnNonMagicImmune(_)
					and c.IsInRange(b, _, T)
					and not c.IsSuspiciousIllusion(_)
					and not _:HasModifier("modifier_abaddon_borrowed_time")
					and not _:HasModifier("modifier_dazzle_shallow_grave")
					and not _:HasModifier("modifier_oracle_false_promise_timer")
				then
					return BOT_ACTION_DESIRE_HIGH, _:GetExtrapolatedLocation(1.2)
				end
			end
		end
		for Z, ab in pairs(a7) do
			if c.IsValid(ab) and ab:GetHealth() <= U then
				table.insert(a9, ab)
			end
		end
		if #a9 >= 2 and c.GetMP(b) > 0.35 and c.CanBeAttacked(a9[1]) and not c.IsThereNonSelfCoreNearby(1200) then
			return BOT_ACTION_DESIRE_HIGH, c.GetCenterOfUnits(a9)
		end
	end
	if c.IsDoingRoshan(b) then
		if c.IsRoshan(H) and c.CanCastOnNonMagicImmune(H) and c.IsInRange(b, H, T) and O then
			return BOT_ACTION_DESIRE_HIGH, H:GetLocation()
		end
	end
	if c.IsDoingTormentor(b) then
		if c.IsTormentor(H) and c.IsInRange(b, H, T) and O then
			return BOT_ACTION_DESIRE_HIGH, H:GetLocation()
		end
	end
	local a9 = {}
	local ac = b:GetNearbyLaneCreeps(T, true)
	for Z, ab in pairs(ac) do
		if c.IsValid(ab) and ab:GetHealth() <= U then
			table.insert(a9, ab)
		end
	end
	if #a9 >= 3 and c.CanBeAttacked(a9[1]) and not c.IsThereNonSelfCoreNearby(1200) then
		return BOT_ACTION_DESIRE_HIGH, c.GetCenterOfUnits(a9)
	end
	return BOT_ACTION_DESIRE_NONE
end
local function HeroIsBeingHit(hero)
	if hero == nil or not hero:IsAlive() then
		return false
	end
	if hero:WasRecentlyDamagedByAnyHero(2.0) then
		return true
	end
	local foes = c.GetNearbyHeroes(hero, 800, true, BOT_MODE_NONE)
	for Z, foe in pairs(foes or {}) do
		if c.IsValidHero(foe) and not foe:IsIllusion() and foe:GetAttackTarget() == hero then
			return true
		end
	end
	return false
end
local function TazerCastRange()
	local range = q:GetCastRange()
	if range == nil or range < 100 then
		range = 600
	end
	return c.GetProperCastRange(false, b, range)
end
local function AllyCanTakeTazer(ally, range)
	return ally ~= nil
		and ally ~= b
		and c.IsValidHero(ally)
		and not ally:IsIllusion()
		and c.IsInRange(b, ally, range)
		and not ally:HasModifier("modifier_techies_reactive_tazer")
		and c.CanCastOnNonMagicImmune(ally)
end
-- Why an ally needs the Tazer to get away, or nil. Being hit only counts when it is a real
-- threat (below 70% HP, or two enemy heroes on her): one lane harass hit used to make a
-- full-HP Medusa "fleeing" (5:50).
local function AllyIsFleeing(ally)
	if c.IsRetreating(ally) and ally:WasRecentlyDamagedByAnyHero(3.0) then
		return "flee-retreat"
	end
	local near = c.GetNearbyHeroes(ally, 800, true, BOT_MODE_NONE) or {}
	if HeroIsBeingHit(ally) and (c.GetHP(ally) < 0.7 or #near >= 2) then
		return "flee-hit"
	end
	-- Chased: below 50% HP, or by two enemy heroes. At 80% a lane trade counted (game 014:
	-- Lich at 62-78% HP, 3 of 13 casts).
	local foes = c.GetNearbyHeroes(ally, 1000, true, BOT_MODE_NONE)
	local chasers = 0
	for Z, foe in pairs(foes or {}) do
		if c.IsValidHero(foe) and not c.IsSuspiciousIllusion(foe) and c.IsChasingTarget(foe, ally) then
			chasers = chasers + 1
		end
	end
	if chasers >= 1 and (c.GetHP(ally) < 0.5 or chasers >= 2) then
		return "flee-chased"
	end
	return nil
end
-- Why an ally is going in (worth the Tazer), or nil. Attack mode alone is not enough: an
-- enemy hero has to be close to her.
local function AllyIsInitiating(ally)
	-- A real kill try (enemy below 50% HP) or a team fight. A lane trade on a healthy enemy
	-- counted (game 014: 5 of 13 casts on Lich at 89-100% HP, enemy healthy).
	local teamFight = c.IsInTeamFight(ally, 1200)
	local foes = c.GetNearbyHeroes(ally, 1000, true, BOT_MODE_NONE)
	for Z, foe in pairs(foes or {}) do
		if c.IsValidHero(foe) and not c.IsSuspiciousIllusion(foe) and (teamFight or c.GetHP(foe) < 0.5) then
			if c.IsChasingTarget(ally, foe) then
				return "initiate-chase"
			end
			if c.IsGoingOnSomeone(ally) and GetUnitToUnitDistance(ally, foe) <= 700 then
				return "initiate"
			end
		end
	end
	return nil
end
-- [OHA-TECHIES] tazer target=... why=..., every cast.
function a.LogTazer(target, why)
	pcall(print, string.format(
		"[OHA-TECHIES] t=%.0f tazer target=%s why=%s targetHp=%.2f mode=%d",
		DotaTime(),
		target == b and "self" or (string.gsub(target:GetUnitName(), "npc_dota_hero_", "")),
		why,
		c.GetHP(target),
		target:GetActiveMode()
	))
end
function a.ConsiderReactiveTazer()
	if not a.TazerUsable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local range = TazerCastRange()
	-- Self first when he is the one being hit or chased. The buff is speed plus a disarm on attackers.
	if not b:HasModifier("modifier_techies_reactive_tazer") then
		-- Same bar as for allies: one lane harass hit was enough (36 of 55 casts last game).
		if
			HeroIsBeingHit(b)
			and (c.GetHP(b) < 0.7 or #(c.GetNearbyHeroes(b, 800, true, BOT_MODE_NONE) or {}) >= 2)
		then
			a.LogTazer(b, "self-hit")
			return BOT_ACTION_DESIRE_HIGH, b
		end
		if N then
			-- Below 50% HP or two chasers (game 014: 4 casts at 78-79% HP).
			local foes = c.GetNearbyHeroes(b, 1400, true, BOT_MODE_NONE)
			local chasers = 0
			for Z, foe in pairs(foes or {}) do
				if c.IsValidHero(foe) and not c.IsSuspiciousIllusion(foe) and c.IsChasingTarget(foe, b) then
					chasers = chasers + 1
				end
			end
			if chasers >= 1 and (c.GetHP(b) < 0.5 or chasers >= 2) then
				a.LogTazer(b, "self-chased")
				return BOT_ACTION_DESIRE_HIGH, b
			end
		end
	end
	-- Same cast works on an ally with no shard. Help the one who is fleeing, then the one going in.
	local flee, initiate, fleeWhy, initiateWhy = nil, nil, nil, nil
	local allies = a.TazerIsUnitTarget() and c.GetNearbyHeroes(b, range, false, BOT_MODE_NONE) or {}
	for Z, ally in pairs(allies or {}) do
		if AllyCanTakeTazer(ally, range) then
			local why = AllyIsFleeing(ally)
			if why ~= nil then
				flee, fleeWhy = ally, why
			elseif initiate == nil then
				initiateWhy = AllyIsInitiating(ally)
				if initiateWhy ~= nil then
					initiate = ally
				end
			end
		end
	end
	if flee ~= nil then
		a.LogTazer(flee, fleeWhy)
		return BOT_ACTION_DESIRE_HIGH, flee
	end
	-- Going in: keep 25% mana for mines and Blast Off.
	if c.GetManaAfter(q:GetManaCost()) < 0.25 then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	-- With Blast Off up, keep the Tazer for the combo. Spent on an ally going in or on our own
	-- approach, it was on cooldown by the time a target came into Blast Off range.
	local selfEngage = not b:HasModifier("modifier_techies_reactive_tazer")
		and M
		and c.IsValidTarget(H)
		and c.IsInRange(b, H, 1200)
		and not c.IsSuspiciousIllusion(H)
		and c.GetManaAfter(q:GetManaCost()) > 0.2
	if (initiate ~= nil or selfEngage) and a.ComboReady() then
		if DotaTime() >= (b._tazerHeldLogAt or -999) then
			b._tazerHeldLogAt = DotaTime() + 10
			pcall(print, string.format(
				"[OHA-TECHIES] t=%.0f tazer-held for=%s pid=%d mp=%.2f",
				DotaTime(),
				initiate ~= nil and (string.gsub(initiate:GetUnitName(), "npc_dota_hero_", "")) or "self",
				b:GetPlayerID(),
				c.GetMP(b)
			))
		end
		return BOT_ACTION_DESIRE_NONE, nil
	end
	if initiate ~= nil then
		a.LogTazer(initiate, initiateWhy)
		return BOT_ACTION_DESIRE_HIGH, initiate
	end
	if selfEngage then
		a.LogTazer(b, "self-engage")
		return BOT_ACTION_DESIRE_HIGH, b
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
local function TazerHost()
	if b:HasModifier("modifier_techies_reactive_tazer") then
		return b
	end
	local allies = c.GetNearbyHeroes(b, 1200, false, BOT_MODE_NONE)
	for Z, ally in pairs(allies or {}) do
		if c.IsValidHero(ally) and ally:HasModifier("modifier_techies_reactive_tazer") then
			return ally
		end
	end
	return nil
end
function a.ConsiderDetonateTazer()
	if r == nil or r:IsNull() or r:IsHidden() or not r:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
	end
	local host = TazerHost()
	if host == nil then
		return BOT_ACTION_DESIRE_NONE
	end
	-- Secondary cast pops the charge early and ends the speed and the disarm on attackers.
	-- Pop it at once only for two heroes in the blast; one hero waits until the buff has worked.
	local radius = q:GetSpecialValueInt("stun_radius")
	if radius == nil or radius < 100 then
		radius = q:GetSpecialValueInt("radius")
	end
	if radius == nil or radius < 100 then
		radius = 450
	end
	local inBlast = 0
	local foes = c.GetNearbyHeroes(host, radius, true, BOT_MODE_NONE)
	for Z, foe in pairs(foes or {}) do
		if c.IsValidHero(foe) and not c.IsSuspiciousIllusion(foe) and not foe:IsMagicImmune() then
			inBlast = inBlast + 1
		end
	end
	local held = DotaTime() - (b._tazerCastAt or -99)
	if inBlast >= 2 or inBlast >= 1 and held >= 1.5 then
		return BOT_ACTION_DESIRE_HIGH
	end
	return BOT_ACTION_DESIRE_NONE
end
function a.TazerIsUnitTarget()
	local ok, behavior = pcall(function()
		return q:GetBehavior()
	end)
	return ok and behavior ~= nil and c.CheckBitfieldFlag(behavior, ABILITY_BEHAVIOR_UNIT_TARGET)
end
function a.ConsiderPlantMad()
	-- No Shard-buff check: the plant ability is found directly (see MadPlant).
	if b:WasRecentlyDamagedByAnyHero(1.5) then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	-- The barrel plant (Shard) found at runtime; never the passive innate (a refused order
	-- freezes him).
	local plant = a.MadPlant()
	if plant == nil then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	if b._madLoc ~= nil and DotaTime() < (b._madUntil or 0) then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local castRange = plant:GetCastRange()
	if castRange == nil or castRange < 100 then
		castRange = 450
	end
	castRange = c.GetProperCastRange(false, b, castRange)
	local function Toward(unit)
		local dist = GetUnitToUnitDistance(b, unit)
		if dist <= castRange then
			return unit:GetLocation()
		end
		if dist <= castRange + 250 then
			return c.Utils.GetOffsetLocationTowardsTargetLocation(b:GetLocation(), unit:GetLocation(), castRange - 40)
		end
		return nil
	end
	-- Burst: a disabled enemy hero in reach (Blast Off stun, a teammate's stun).
	for Z, foe in pairs(c.GetNearbyHeroes(b, castRange + 250, true, BOT_MODE_NONE) or {}) do
		if c.IsValidHero(foe) and not c.IsSuspiciousIllusion(foe) and c.IsDisabled(foe) then
			local loc = Toward(foe)
			if loc ~= nil then
				return BOT_ACTION_DESIRE_HIGH, loc
			end
		end
	end
	if M and c.IsValidTarget(H) and not c.IsSuspiciousIllusion(H) and GetUnitToUnitDistance(b, H) > 400 then
		-- Where the target will be when it blows: 1s plant + 1.5s fuse.
		local loc = Toward(H)
		if loc ~= nil then
			if not c.IsDisabled(H) then
				loc = H:GetExtrapolatedLocation(1.5)
			end
			return BOT_ACTION_DESIRE_HIGH, loc
		end
	end
	if N then
		local foes = c.GetNearbyHeroes(b, 1100, true, BOT_MODE_NONE)
		for Z, foe in pairs(foes or {}) do
			if
				c.IsValidHero(foe)
				and not c.IsSuspiciousIllusion(foe)
				and c.IsChasingTarget(foe, b)
				and GetUnitToUnitDistance(b, foe) > 500
			then
				local loc = Toward(foe)
				if loc ~= nil then
					return BOT_ACTION_DESIRE_HIGH, loc
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
local function PlantFailWhy()
	local why = ""
	pcall(function()
		local plantAb = b:GetAbilityByName("techies_mutually_assured_destruction")
		local det = b:GetAbilityByName("techies_focused_detonate")
		why = string.format(
			" alive=%s plantCd=%.1f det=%s/%s since=%.1f",
			tostring(b:IsAlive()),
			plantAb ~= nil and plantAb:GetCooldownTimeRemaining() or -1,
			det ~= nil and (det:IsHidden() and "hidden" or "shown") or "none",
			det ~= nil and tostring(det:IsFullyCastable()) or "-",
			DotaTime() - (b._madPlantAt or DotaTime())
		)
	end)
	return why
end
-- Detonate whenever it is shown (user call): techies_focused_detonate shows once a barrel is down,
-- so it is clicked as soon as it is castable, unless he is dead, stunned, hexed, silenced or
-- nightmared. No timer and no enemy check. A plant that never shows the detonate is logged:
-- 'not cast' when M.A.D. never went on cooldown, 'no detonate' when it did.
function a.ConsiderDetonateMad()
	local now = DotaTime()
	if a.MadDetonate() ~= nil then
		if not b:IsAlive() or b:IsStunned() or b:IsHexed() or b:IsSilenced() or b:IsNightmared() then
			return BOT_ACTION_DESIRE_NONE
		end
		return BOT_ACTION_DESIRE_HIGH
	end
	if b._madLoc ~= nil and now - (b._madPlantAt or now) > 3.5 then
		local plantAb = b:GetAbilityByName("techies_mutually_assured_destruction")
		local cast = plantAb ~= nil and plantAb:GetCooldownTimeRemaining() > 0
		a.LogTechies("mad-plant-failed (" .. (cast and "no detonate" or "not cast") .. ")" .. PlantFailWhy(), 0, b._madLoc)
		b._madLoc = nil
		b._madDetonateAt = nil
	end
	return BOT_ACTION_DESIRE_NONE
end
-- Returns desire, location, and why: channel, fight, chase, initiate, last-stand, escape.
-- Soul Ring (costs 170 HP, gives 170 mana for 10s) right before every engaging Blast Off
-- (never to escape), and only if HP stays safe after both the ring and Blast
-- Off's own cost (a share of current HP): early on that pair would drop him into a TP home.
function a.ConsiderSoulRingForBlast()
	local slot = b:FindItemSlot("item_soul_ring")
	if slot < 0 or slot > 5 then
		return false
	end
	local ring = b:GetItemInSlot(slot)
	if ring == nil or not ring:IsFullyCastable() then
		return false
	end
	-- Before every engaging Blast Off, not only when short on mana: the extra 170 pays for the
	-- Tazer and the mine triangle that follow. Still only if the ring makes Blast Off affordable.
	local cost = s:GetManaCost()
	local mana = b:GetMana()
	if mana + 170 < cost then
		return false
	end
	local desire, loc, why = a.ConsiderBlastOff(true)
	if desire <= 0 or why == "escape" then
		return false
	end
	local pct = s:GetSpecialValueInt("hp_cost")
	if pct == nil or pct <= 0 then
		pct = 20
	end
	local after = (b:GetHealth() - 170) * (1 - pct / 100)
	local ok = after >= 0.4 * b:GetMaxHealth() and after >= 300
	if DotaTime() >= (b._soulRingLogAt or -999) then
		b._soulRingLogAt = DotaTime() + 5
		pcall(print, string.format(
			"[OHA-TECHIES] t=%.0f soul-ring %s for=blast-%s hpAfter=%.0f max=%.0f mana=%.0f cost=%.0f",
			DotaTime(),
			ok and "used" or "skipped-hp",
			tostring(why),
			after,
			b:GetMaxHealth(),
			mana,
			cost
		))
	end
	if not ok then
		return false
	end
	b:Action_UseAbility(ring)
	return true
end
-- ignoreMana: judge the situation as if the mana were there (used to decide on Soul Ring).
function a.ConsiderBlastOff(ignoreMana)
	local ready = ignoreMana and s:IsTrained() and s:GetCooldownTimeRemaining() <= 0 or s:IsFullyCastable()
	if not ready or s:IsHidden() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local T = c.GetProperCastRange(false, b, s:GetCastRange())
	local R = s:GetCastPoint()
	local ad = s:GetSpecialValueInt("radius")
	local S = s:GetSpecialValueFloat("duration")
	local Y = c.GetNearbyHeroes(b, T, true, BOT_MODE_NONE)
	for Z, _ in pairs(Y) do
		if
			c.IsValidHero(_)
			and c.CanCastOnNonMagicImmune(_)
			and not c.IsSuspiciousIllusion(_)
			and not _:HasModifier("modifier_abaddon_borrowed_time")
			and not _:HasModifier("modifier_dazzle_shallow_grave")
			and not _:HasModifier("modifier_faceless_void_chronosphere_freeze")
			and not _:HasModifier("modifier_necrolyte_reapers_scythe")
			and not _:HasModifier("modifier_oracle_false_promise_timer")
			and not _:HasModifier("modifier_templar_assassin_refraction_absorb")
		then
			-- Stop a channel (TP, ult) even when outnumbered. Only a low Techies checks numbers,
			-- since the landing costs him a share of his current HP.
			if _:IsChanneling() then
				local a4 = c.GetNearbyHeroes(_, 1200, true, BOT_MODE_NONE)
				local a5 = c.GetNearbyHeroes(_, 1200, false, BOT_MODE_NONE)
				if (P or 1) >= 0.3 or a4 ~= nil and a5 ~= nil and #a4 >= #a5 then
					return BOT_ACTION_DESIRE_HIGH, _:GetLocation(), "channel"
				end
			end
		end
	end
	if c.IsInTeamFight(b, 1200) then
		local ae = b:FindAoELocation(true, true, b:GetLocation(), T, ad, 0, 0)
		local a5 = c.GetEnemiesNearLoc(ae.targetloc, ad * 0.8)
		if a5 ~= nil and #a5 >= 2 and not c.IsLocationInChrono(c.GetCenterOfUnits(a5)) then
			return BOT_ACTION_DESIRE_HIGH, c.GetCenterOfUnits(a5), "fight"
		end
	end
	if M then
		if
			c.IsValidTarget(H)
			and c.CanCastOnNonMagicImmune(H)
			and c.IsInRange(b, H, T)
			and not c.IsSuspiciousIllusion(H)
			and not H:HasModifier("modifier_faceless_void_chronosphere_freeze")
			and not H:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			local a4 = c.GetNearbyHeroes(H, 1200, true, BOT_MODE_NONE)
			local a5 = c.GetNearbyHeroes(H, 1200, false, BOT_MODE_NONE)
			if a4 ~= nil and a5 ~= nil and #a4 >= #a5 then
				local af = false
				local a0 = R + S
				local ag = H:GetNearbyTowers(700, false)
				if c.IsChasingTarget(b, H) then
					if c.IsInLaningPhase() then
						if Y ~= nil and #ag >= 1 then
							af = true
						end
					end
					if not af then
						return BOT_ACTION_DESIRE_HIGH, H:GetExtrapolatedLocation(a0), "chase"
					end
				else
					if c.IsInLaningPhase() then
						if Y ~= nil and #ag >= 1 then
							af = true
						end
					end
					if not af then
						a5 = c.GetEnemiesNearLoc(H:GetLocation(), ad)
						if a5 ~= nil and #a5 >= 1 then
							return BOT_ACTION_DESIRE_HIGH, c.GetCenterOfUnits(a5), "initiate"
						else
							return BOT_ACTION_DESIRE_HIGH, H:GetLocation(), "initiate"
						end
					end
				end
			end
		end
	end
	if N then
		local a5 = c.GetNearbyHeroes(b, T, true, BOT_MODE_NONE)
		for Z, _ in pairs(a5) do
			if c.IsValidHero(_) and c.IsChasingTarget(_, b) and not c.IsSuspiciousIllusion(_) then
				local a4 = c.GetNearbyHeroes(_, 1200, true, BOT_MODE_NONE)
				local a6 = c.GetNearbyHeroes(_, 1200, false, BOT_MODE_NONE)
				if a4 ~= nil and a6 ~= nil and (#a6 > #a4 or b:WasRecentlyDamagedByAnyHero(2)) then
					if
						P < 0.5
						and c.CanCastOnNonMagicImmune(_)
						and b:GetHealth() < c.GetTotalEstimatedDamageToTarget(a5, b)
					then
						return BOT_ACTION_DESIRE_HIGH, _:GetLocation(), "last-stand"
					else
						return BOT_ACTION_DESIRE_HIGH, c.Site.GetXUnitsTowardsLocation(b, c.GetTeamFountain(), T), "escape"
					end
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function a.ConsiderMineFieldSign()
	-- Minefield Sign stays hidden without Scepter but still reports castable. Ordering it
	-- then is refused by the server and freezes Techies in place every think.
	if not u:IsTrained() or t:IsHidden() or not t:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local ad = t:GetSpecialValueInt("aura_radius")
	local ah = f.GetAvailableSpot()
	MineLocation, MineLocationDistance = f.GetClosestSpot(b, ah)
	if
		MineLocation ~= nil
		and GetUnitToLocationDistance(b, MineLocation) <= b:GetCurrentVisionRange()
		and not a.IsEnemyCloserToWardLocation(MineLocation, MineLocationDistance)
	then
		for ai = 0, 50 do
			local aj = c.GetRandomLocationWithinDist(MineLocation, 0, ad * 3 + 100)
			if IsLocationPassable(aj) then
				local ak = c.GetTechiesMinesInLoc(aj, ad)
				if #ak >= 3 then
					return BOT_ACTION_DESIRE_HIGH, aj
				end
			end
			ai = ai + 1
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
-- Proximity Mines is charge based (3 charges, one every 15s). Charges left from the shared
-- tracker (the API has no ability-charge read), or 3 before it has a count.
function a.MineCharges()
	return ChargeTracker.Count(b, u) or 3
end
-- Three spots 120 degrees apart around center. At radius 210 they sit ~364 apart, past the
-- 350 minimum mine spacing, and the target in the middle is near full damage from each.
-- Skips spots that are not passable or too close to an existing mine.
-- A spot a mine can actually go: walkable (covers cliffs and map objects), no tree within 120,
-- no building within 250, no mine too close, and 350 from the other spots of this triangle.
function a.MineSpotOk(spot, chosen)
	if not IsLocationPassable(spot) or f.IsOtherMinesClose(spot) then
		return false
	end
	for _, other in ipairs(chosen) do
		if (other.x - spot.x) ^ 2 + (other.y - spot.y) ^ 2 < 350 * 350 then
			return false
		end
	end
	for _, tree in pairs(b:GetNearbyTrees(math.min(1600, GetUnitToLocationDistance(b, spot) + 200)) or {}) do
		local tl = GetTreeLocation(tree)
		if tl ~= nil and (tl.x - spot.x) ^ 2 + (tl.y - spot.y) ^ 2 < 120 * 120 then
			return false
		end
	end
	for _, list in ipairs({ UNIT_LIST_ALLIED_BUILDINGS, UNIT_LIST_ENEMY_BUILDINGS }) do
		for _, bld in pairs(GetUnitList(list) or {}) do
			if bld ~= nil and not bld:IsNull() and GetUnitToLocationDistance(bld, spot) < 250 then
				return false
			end
		end
	end
	return true
end
function a.MineTriangle(center, radius)
	local spots = {}
	if center == nil then
		return spots
	end
	-- Blocked spot (tree, building, cliff): try a slightly turned or shorter/longer spot first.
	local turns = { 0, 20, -20 }
	local radii = { radius, radius - 50, radius + 40 }
	for k = 0, 2 do
		local placed = false
		for _, rr in ipairs(radii) do
			for _, turn in ipairs(turns) do
				local angle = math.rad(90 + 120 * k + turn)
				local spot = center + Vector(math.cos(angle) * rr, math.sin(angle) * rr, 0)
				if a.MineSpotOk(spot, spots) then
					spots[#spots + 1] = spot
					placed = true
					break
				end
			end
			if placed then
				break
			end
		end
	end
	return spots
end
-- [OHA-TECHIES]: mine combos and triangles, at most once per 5s per kind.
function a.LogTechies(kind, mines, center)
	b._techiesLogAt = b._techiesLogAt or {}
	if DotaTime() < (b._techiesLogAt[kind] or -999) then
		return
	end
	b._techiesLogAt[kind] = DotaTime() + 5
	pcall(print, string.format(
		"[OHA-TECHIES] t=%.0f %s pid=%d mines=%d charges=%d at=%.0f,%.0f mp=%.2f",
		DotaTime(),
		kind,
		b:GetPlayerID(),
		mines,
		a.MineCharges(),
		center and center.x or 0,
		center and center.y or 0,
		c.GetMP(b)
	))
end
-- A mine spot of the triangle around the last Blast Off landing, 1.75s to 3.5s after the order
-- (1s cast point and 0.75s flight, Valve data, then the stun). Spots already mined are skipped.
-- Every mine order, with the exact spot and its distance from Techies. The engine rejects some
-- with "Cast failed, but not sure why! (techies_land_mines, target loc ..., result: 24)"; matching
-- those coordinates against these lines shows whether the distance is the problem.
function a.OrderMine(loc, kind)
	if loc == nil then
		return
	end
	pcall(print, string.format(
		"[OHA-TECHIES] t=%.0f mine-order kind=%s at=%.2f,%.2f dist=%d range=%d charges=%d",
		DotaTime(),
		kind,
		loc.x,
		loc.y,
		math.floor(GetUnitToLocationDistance(b, loc)),
		u:GetCastRange(),
		a.MineCharges()
	))
	pcall(ChargeTracker.Issued, b, u)
	b:Action_UseAbilityOnLocation(u, loc)
end
-- When Blast Off lands: its cast point plus the flight.
local function BlastLandAt()
	if b._blastAt == nil then
		return nil
	end
	local flight = s:GetSpecialValueFloat("duration")
	if flight == nil or flight <= 0 then
		flight = 0.75
	end
	return b._blastAt + s:GetCastPoint() + flight
end
-- Force Staff out after the landing combo (Veil, mines, Sticky Bomb come first in the order),
-- once per Blast Off, from 0.5s to 6s after landing, when an enemy hero is within 800 and he is
-- below 60% HP or two enemy heroes are on him. Force Staff pushes 600 the way he faces (Valve
-- data), so he turns toward the fountain first. The shared rule only pushes a hero already in
-- retreat mode and facing home, which he rarely is right after landing.
function a.ConsiderPostBlastEscape()
	local land = BlastLandAt()
	if land == nil or DotaTime() < land + 0.5 or DotaTime() > land + 6 or b._forceBlastAt == b._blastAt then
		return false
	end
	local slot = b:FindItemSlot("item_force_staff")
	if slot < 0 or slot > 5 then
		slot = b:FindItemSlot("item_hurricane_pike")
	end
	if slot < 0 or slot > 5 then
		return false
	end
	local force = b:GetItemInSlot(slot)
	if force == nil or not force:IsFullyCastable() or b:IsRooted() then
		return false
	end
	local foes = 0
	for _, e0 in pairs(c.GetNearbyHeroes(b, 800, true, BOT_MODE_NONE) or {}) do
		if c.IsValidHero(e0) and not c.IsSuspiciousIllusion(e0) then
			foes = foes + 1
		end
	end
	if foes == 0 or (c.GetHP(b) >= 0.6 and foes < 2) then
		return false
	end
	local home = GetTeam() == TEAM_RADIANT and Vector(-7172, -6652, 0) or Vector(6982, 6422, 0)
	local me = b:GetLocation()
	local dx, dy = home.x - me.x, home.y - me.y
	local len = math.max(1, math.sqrt(dx * dx + dy * dy))
	local landing = Vector(me.x + dx / len * 600, me.y + dy / len * 600, me.z)
	if not IsLocationPassable(landing) then
		return false
	end
	if not b:IsFacingLocation(home, 25) then
		b:Action_MoveToLocation(Vector(me.x + dx / len * 200, me.y + dy / len * 200, me.z))
		return true
	end
	b._forceBlastAt = b._blastAt
	a.LogTechies(string.format("post-blast-force foes=%d hp=%.2f", foes, c.GetHP(b)), 0, landing)
	b:Action_UseAbilityOnEntity(force, b)
	return true
end
-- Veil of Discord right after landing, once per Blast Off, with an enemy hero in its radius.
function a.ConsiderPostBlastVeil()
	local land = BlastLandAt()
	if land == nil or DotaTime() < land or DotaTime() > land + 2.5 or b._veilBlastAt == b._blastAt then
		return nil
	end
	local slot = b:FindItemSlot("item_veil_of_discord")
	if slot < 0 or slot > 5 then
		return nil
	end
	local veil = b:GetItemInSlot(slot)
	if veil == nil or not veil:IsFullyCastable() then
		return nil
	end
	local radius = veil:GetSpecialValueInt("debuff_radius")
	if radius == nil or radius <= 0 then
		radius = 600
	end
	for _, e0 in pairs(c.GetNearbyHeroes(b, radius, true, BOT_MODE_NONE) or {}) do
		if c.IsValidHero(e0) and not c.IsSuspiciousIllusion(e0) then
			return veil
		end
	end
	return nil
end
-- Sticky Bomb after the post-blast mine triangle (mines spent or not castable), once per Blast
-- Off, on the nearest enemy hero in range, up to 5s after the cast.
function a.ConsiderPostBlastSticky()
	if b._blastAt == nil or DotaTime() - b._blastAt < 1.75 or DotaTime() - b._blastAt > 5 then
		return nil
	end
	if b._stickyBlastAt == b._blastAt or not p:IsTrained() or not p:IsFullyCastable() then
		return nil
	end
	local range = p:GetCastRange() + 100
	local best, bestD = nil, math.huge
	for _, e0 in pairs(c.GetNearbyHeroes(b, range, true, BOT_MODE_NONE) or {}) do
		if c.IsValidHero(e0) and c.CanCastOnNonMagicImmune(e0) and not c.IsSuspiciousIllusion(e0) then
			local d0 = GetUnitToUnitDistance(b, e0)
			if d0 < bestD then
				best, bestD = e0, d0
			end
		end
	end
	if best == nil then
		return nil
	end
	return best:GetExtrapolatedLocation(0.5)
end
function a.ConsiderPostBlastSign()
	if b._blastAt == nil or b._signBlastAt == b._blastAt then
		return false
	end
	local land = BlastLandAt()
	if land == nil or DotaTime() < land or DotaTime() > land + 2 then
		return false
	end
	if not b:HasScepter() or t:IsHidden() or not t:IsFullyCastable() or not u:IsTrained() then
		return false
	end
	return true
end
function a.ConsiderPostBlastMines()
	if b._blastAt == nil or b._blastLoc == nil or DotaTime() - b._blastAt > 3.5 then
		return nil
	end
	if DotaTime() - b._blastAt < 1.75 or not u:IsTrained() or u:IsHidden() or not u:IsFullyCastable() then
		return nil
	end
	-- Around Techies himself: he has just landed among the stunned enemies, so no walking.
	for _, spot in ipairs(a.MineTriangle(b:GetLocation(), 210)) do
		return spot
	end
	return nil
end
function a.ConsiderProximityMines()
	if not u:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local T = c.GetProperCastRange(false, b, u:GetCastRange())
	local al = 400
	local am = u:GetManaCost()
	-- A disabled enemy in reach: build the triangle around it, one mine per think (cast point 0).
	if
		c.IsValidHero(H)
		and c.IsDisabled(H)
		and c.CanCastOnNonMagicImmune(H)
		and not c.IsSuspiciousIllusion(H)
		and GetUnitToUnitDistance(b, H) <= T + 210
		and not H:HasModifier("modifier_necrolyte_reapers_scythe")
	then
		local spots = a.MineTriangle(H:GetLocation(), 210)
		if spots[1] ~= nil and GetUnitToLocationDistance(b, spots[1]) <= T + 100 then
			a.LogTechies("triangle", #spots, H:GetLocation())
			return BOT_ACTION_DESIRE_HIGH, spots[1]
		end
	end
	if M then
		if
			c.IsValidTarget(H)
			and c.CanCastOnNonMagicImmune(H)
			and c.IsInRange(b, H, T + al)
			and not c.IsChasingTarget(b, H)
			and not c.IsSuspiciousIllusion(H)
			and not H:HasModifier("modifier_necrolyte_reapers_scythe")
			and not H:HasModifier("modifier_templar_assassin_refraction_absorb")
		then
			local a4 = c.GetNearbyHeroes(H, 1200, true, BOT_MODE_NONE)
			local a5 = c.GetNearbyHeroes(H, 1200, false, BOT_MODE_NONE)
			if c.CanKillTarget(H, K, DAMAGE_TYPE_MAGICAL) or a4 ~= nil and a5 ~= nil and #a4 >= #a5 then
				a5 = c.GetEnemiesNearLoc(H:GetLocation(), f.nMinMineDistance)
				if a5 ~= nil and #a5 >= 1 then
					local an, aj = f.GetGoodPlaceForMiningNear(c.GetCenterOfUnits(a5))
					if an > 0 then
						return BOT_ACTION_DESIRE_HIGH, aj
					end
				else
					local an, aj = f.GetGoodPlaceForMiningNear(H:GetLocation())
					if an > 0 then
						return BOT_ACTION_DESIRE_HIGH, aj
					end
				end
			end
		end
	end
	local Y = c.GetNearbyHeroes(b, T + al, true, BOT_MODE_NONE)
	for Z, _ in pairs(Y) do
		if
			c.IsValidHero(_)
			and c.CanCastOnNonMagicImmune(_)
			and c.GetManaAfter(am) > 0.5
			and not N
			and P > c.GetHP(_)
			and not c.IsSuspiciousIllusion(_)
			and not _:HasModifier("modifier_abaddon_borrowed_time")
			and not _:HasModifier("modifier_dazzle_shallow_grave")
			and not _:HasModifier("modifier_oracle_false_promise_timer")
			and not _:HasModifier("modifier_templar_assassin_refraction_absorb")
		then
			local a4 = c.GetNearbyHeroes(_, 1200, true, BOT_MODE_NONE)
			local a5 = c.GetNearbyHeroes(_, 1200, false, BOT_MODE_NONE)
			if a4 ~= nil and a5 ~= nil and #a4 >= #a5 then
				local aj = _:GetExtrapolatedLocation(0.5)
				if GetUnitToLocationDistance(b, aj) < T + 100 then
					return BOT_ACTION_DESIRE_HIGH, aj
				end
				aj = c.Utils.GetOffsetLocationTowardsTargetLocation(b:GetLocation(), _:GetLocation(), T)
				if GetUnitToLocationDistance(b, aj) < T + 100 then
					return BOT_ACTION_DESIRE_HIGH, aj
				end
			end
		end
	end
	if N then
		local a5 = c.GetNearbyHeroes(b, 1000, true, BOT_MODE_NONE)
		for Z, _ in pairs(a5) do
			if
				c.IsValidHero(_)
				and c.CanCastOnNonMagicImmune(_)
				and c.IsChasingTarget(_, b)
				and not c.IsSuspiciousIllusion(_)
				and not c.IsDisabled(_)
			then
				local a4 = c.GetNearbyHeroes(_, 1200, true, BOT_MODE_NONE)
				local a6 = c.GetNearbyHeroes(_, 1200, false, BOT_MODE_NONE)
				if
					a4 ~= nil
					and a6 ~= nil
					and (#a6 > #a4 or b:WasRecentlyDamagedByAnyHero(1))
					and c.CanKillTarget(_, J, DAMAGE_TYPE_MAGICAL)
				then
					local aj = (b:GetLocation() + _:GetLocation()) / 2
					if GetUnitToLocationDistance(b, aj) <= T then
						return BOT_ACTION_DESIRE_HIGH, aj
					else
						return BOT_ACTION_DESIRE_HIGH, b:GetLocation()
					end
				end
			end
		end
	end
	if c.IsPushing(b) then
		local ag = b:GetNearbyTowers(1200, true)
		if ag ~= nil and #ag >= 1 and c.IsValidBuilding(ag[1]) and c.CanBeAttacked(ag[1]) then
			local a4 = c.GetAlliesNearLoc(ag[1]:GetLocation(), b:GetAttackRange())
			local a5 = c.GetEnemiesNearLoc(ag[1]:GetLocation(), 1600)
			if a4 ~= nil and #a4 >= 1 and a5 ~= nil and #a5 == 0 then
				-- Mines deal 30% to buildings. Ring the tower with the 350-spaced triangle
				-- instead of one random spot that blocks the next mine.
				local spots = a.MineTriangle(ag[1]:GetLocation(), 250)
				if spots[1] ~= nil then
					a.LogTechies("tower", #spots, ag[1]:GetLocation())
					return BOT_ACTION_DESIRE_HIGH, spots[1]
				end
			end
		end
	end
	if c.IsDoingRoshan(b) then
		if
			c.IsRoshan(H)
			and c.CanCastOnNonMagicImmune(H)
			and c.IsInRange(b, H, al)
			and O
			and not f.IsOtherMinesClose(H:GetLocation())
		then
			return BOT_ACTION_DESIRE_HIGH, H:GetLocation()
		end
	end
	if c.IsDoingTormentor(b) then
		if c.IsTormentor(H) and c.IsInRange(b, H, T) and O and not f.IsOtherMinesClose(H:GetLocation()) then
			return BOT_ACTION_DESIRE_HIGH, H:GetLocation()
		end
	end
	if c.IsFarming(b) and c.GetManaAfter(am) > 0.3 then
		local a8 = b:GetNearbyNeutralCreeps(al)
		if a8 ~= nil then
			if #a8 > 1 then
				return BOT_ACTION_DESIRE_HIGH, a8[1]:GetLocation()
			end
		end
		local a7 = b:GetNearbyLaneCreeps(al, true)
		if a7 ~= nil then
			if #a7 > 1 then
				return BOT_ACTION_DESIRE_HIGH, a7[1]:GetLocation()
			end
		end
	end
	-- No idle mining at random map spots: it spent mana on mines nobody walked into.
	return BOT_ACTION_DESIRE_NONE, 0
end
function a.IsSuitableToPlaceMine()
	local Y = c.GetEnemiesNearLoc(b:GetLocation(), 2000)
	local ap = b:GetActiveMode()
	local aq = c.GetTeamFightLocation(b)
	if
		ap == BOT_MODE_RETREAT and b:GetActiveModeDesire() > BOT_MODE_DESIRE_HIGH
		or ap == BOT_MODE_RUNE and DotaTime() > 0
		or ap == BOT_MODE_DEFEND_ALLY
		or M and b:GetActiveModeDesire() > BOT_MODE_DESIRE_MODERATE
		or c.IsPushing(b) and b:GetActiveModeDesire() > BOT_MODE_DESIRE_MODERATE
		or c.IsDefending(b)
		or c.IsDoingRoshan(b)
		or c.IsDoingTormentor(b)
		or b:GetLevel() <= 6
		or aq ~= nil
		or Y ~= nil and #Y >= 1
	then
		return false
	end
	return true
end
function a.IsIBecameTheTarget(ar)
	for Z, as in pairs(ar) do
		if as ~= nil and as:CanBeSeen() and as:GetAttackTarget() == b then
			return true
		end
	end
	return false
end
function a.IsEnemyCloserToWardLocation(at, au)
	for Z, av in pairs(GetTeamPlayers(GetOpposingTeam())) do
		local aw = GetHeroLastSeenInfo(av)
		if aw ~= nil then
			local ax = aw[1]
			if ax ~= nil and ax.time_since_seen < 5 and c.GetDistance(ax.location, at) < au then
				return true
			end
		end
	end
	return false
end
-- Tazer can report castable while hidden (seen with two Techies on one team). Every order on it
-- is then refused, so nothing that needs it may count on it.
function a.TazerUsable()
	if not q:IsFullyCastable() then
		return false
	end
	if q:IsHidden() then
		if DotaTime() >= (b._tazerHiddenLogAt or -999) then
			b._tazerHiddenLogAt = DotaTime() + 30
			pcall(print, string.format(
				"[OHA-TECHIES] t=%.0f tazer-hidden pid=%d lvl=%d stopHidden=%s buff=%s",
				DotaTime(),
				b:GetPlayerID(),
				q:GetLevel(),
				tostring(r == nil or r:IsNull() or r:IsHidden()),
				tostring(b:HasModifier("modifier_techies_reactive_tazer"))
			))
		end
		return false
	end
	return true
end
-- Blast Off and the Tazer are both up with mana for both, and the target is about to be in
-- Blast Off range. Only then is the Tazer kept back to follow the Blast Off; it never holds
-- the Blast Off itself, and it is not kept when there is no target close.
function a.ComboReady()
	if
		not (
			s:IsFullyCastable()
			and not s:IsHidden()
			and q:IsFullyCastable()
			and not q:IsHidden()
			and b:GetMana() >= q:GetManaCost() + s:GetManaCost()
		)
	then
		return false
	end
	local range = c.GetProperCastRange(false, b, s:GetCastRange()) + 300
	return c.IsValidTarget(H) and GetUnitToUnitDistance(b, H) <= range
end
return a
