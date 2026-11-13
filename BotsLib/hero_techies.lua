-- Techies: skill build, item build, and ability use for this hero.
local a = {}
local b = GetBot()
local c = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local d = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local e = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local f = require(GetScriptDirectory() .. "/FuncLib/hero/techies")
local g = c.Skill.GetTalentList(b)
local h = c.Skill.GetAbilityList(b)
local i = c.Item.GetRoleItemsBuyList(b)
local j = { ["t25"] = { 10, 0 }, ["t20"] = { 10, 0 }, ["t15"] = { 0, 10 }, ["t10"] = { 10, 0 } }
local k = { { 1, 3, 1, 2, 1, 6, 1, 3, 3, 3, 6, 2, 2, 2, 6 } }
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
	"item_guardian_greaves",
	"item_force_staff",
	"item_lotus_orb",
	"item_octarine_core",
	"item_sheepstick",
	"item_aghanims_shard",
	"item_moon_shard",
	"item_ultimate_scepter_2",
}
n["pos_5"] = {
	-- 600 starting gold: Soul Ring parts (455) + Tango (90) + Blood Grenade (50) = 595.
	-- The recipe (350) finishes Soul Ring after Boots, in place of Magic Wand.
	"item_tango",
	"item_blood_grenade",
	"item_ring_of_protection",
	"item_gauntlets",
	"item_gauntlets",
	"item_boots",
	"item_soul_ring",
	"item_tranquil_boots",
	"item_kaya",
	"item_pipe",
	"item_force_staff",
	"item_boots_of_bearing",
	"item_octarine_core",
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
	"item_gauntlets",
	"item_gauntlets",
	"item_boots",
	"item_soul_ring",
	"item_tranquil_boots",
	"item_kaya",
	"item_force_staff",
	"item_kaya_and_sange",
	"item_boots_of_bearing",
	"item_octarine_core",
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
	"item_octarine_core",
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
function a.SkillsComplement()
	-- Detonate M.A.D. still works while Techies is dead or already acting.
	if a.ConsiderDetonateMad() > 0 then
		b:Action_UseAbility(madStop)
		b._madLoc = nil
		return
	end
	if c.CanNotUseAbility(b) then
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
	y, z, yWhy = a.ConsiderBlastOff()
	if y > 0 then
		b:Action_ClearActions(false)
		b:ActionQueue_UseAbilityOnLocation(s, z)
		-- The cast point is spent before the next queued order; the 0.75s flight is not.
		b:ActionQueue_Delay(math.max(0.3, s:GetSpecialValueFloat("duration")) + 0.1)
		local manaLeft = b:GetMana() - s:GetManaCost()
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
		end
		a.LogTechies(string.format("blast why=%s tazer=%s", yWhy or "?", tostring(tazer)), planted, z)
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
		b._madLoc = D
		b._madUntil = DotaTime() + 45
		b:Action_UseAbilityOnLocation(mad, D)
		return
	end
	C, D = a.ConsiderProximityMines()
	if C > 0 then
		b:Action_UseAbilityOnLocation(u, D)
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
	local foes = c.GetNearbyHeroes(ally, 1000, true, BOT_MODE_NONE)
	for Z, foe in pairs(foes or {}) do
		if c.IsValidHero(foe) and not c.IsSuspiciousIllusion(foe) and c.IsChasingTarget(foe, ally) and c.GetHP(ally) < 0.8 then
			return "flee-chased"
		end
	end
	return nil
end
-- Why an ally is going in (worth the Tazer), or nil. Attack mode alone is not enough: an
-- enemy hero has to be close to her.
local function AllyIsInitiating(ally)
	local foes = c.GetNearbyHeroes(ally, 1000, true, BOT_MODE_NONE)
	for Z, foe in pairs(foes or {}) do
		if c.IsValidHero(foe) and not c.IsSuspiciousIllusion(foe) then
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
		if HeroIsBeingHit(b) then
			a.LogTazer(b, "self-hit")
			return BOT_ACTION_DESIRE_HIGH, b
		end
		if N then
			local foes = c.GetNearbyHeroes(b, 1400, true, BOT_MODE_NONE)
			for Z, foe in pairs(foes or {}) do
				if c.IsValidHero(foe) and not c.IsSuspiciousIllusion(foe) and c.IsChasingTarget(foe, b) then
					a.LogTazer(b, "self-chased")
					return BOT_ACTION_DESIRE_HIGH, b
				end
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
	if not c.HasAghanimsShard(b) or b:WasRecentlyDamagedByAnyHero(1.5) then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	if mad == nil or mad:IsNull() or mad:IsHidden() or mad:IsPassive() or not mad:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	if b._madLoc ~= nil and DotaTime() < (b._madUntil or 0) then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local castRange = mad:GetCastRange()
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
	if M and c.IsValidTarget(H) and not c.IsSuspiciousIllusion(H) and GetUnitToUnitDistance(b, H) > 400 then
		local loc = Toward(H)
		if loc ~= nil then
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
function a.ConsiderDetonateMad()
	if madStop == nil or madStop:IsNull() or madStop:IsHidden() or not madStop:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
	end
	if b:IsStunned() or b:IsHexed() or b:IsSilenced() or b:IsNightmared() then
		return BOT_ACTION_DESIRE_NONE
	end
	local loc = b._madLoc
	if loc == nil or DotaTime() > (b._madUntil or 0) then
		return BOT_ACTION_DESIRE_NONE
	end
	-- The barrel needs 1.5s after the order. Pop it when a hero is already on it.
	local foes = c.GetEnemiesNearLoc(loc, 280)
	if foes ~= nil and #foes >= 1 then
		return BOT_ACTION_DESIRE_HIGH
	end
	return BOT_ACTION_DESIRE_NONE
end
-- Returns desire, location, and why: channel, fight, chase, initiate, last-stand, escape.
function a.ConsiderBlastOff()
	if not s:IsFullyCastable() or s:IsHidden() then
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
-- Proximity Mines is charge based (3 charges, one every 15s). Charges left, or 3 if the
-- API does not report them.
function a.MineCharges()
	local ok, n = pcall(function()
		return u:GetCurrentAbilityCharges()
	end)
	if ok and type(n) == "number" then
		return n
	end
	return 3
end
-- Three spots 120 degrees apart around center. At radius 210 they sit ~364 apart, past the
-- 350 minimum mine spacing, and the target in the middle is near full damage from each.
-- Skips spots that are not passable or too close to an existing mine.
function a.MineTriangle(center, radius)
	local spots = {}
	if center == nil then
		return spots
	end
	for k = 0, 2 do
		local angle = math.rad(90 + 120 * k)
		local spot = center + Vector(math.cos(angle) * radius, math.sin(angle) * radius, 0)
		if IsLocationPassable(spot) and not f.IsOtherMinesClose(spot) then
			spots[#spots + 1] = spot
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
	local ao = q:GetManaCost() + s:GetManaCost()
	if DotaTime() > E + 1.5 and c.GetManaAfter(ao) * b:GetMana() > u:GetManaCost() * 2 and a.IsSuitableToPlaceMine() then
		local ah = f.GetAvailableSpot()
		MineLocation, MineLocationDistance = f.GetClosestSpot(b, ah)
		if
			MineLocation ~= nil
			and GetUnitToLocationDistance(b, MineLocation) <= 2000
			and not a.IsEnemyCloserToWardLocation(MineLocation, MineLocationDistance)
		then
			for ai = 0, 10 do
				local aj = c.GetRandomLocationWithinDist(MineLocation, 0, f.nMinMineDistance * 3 + 100)
				if IsLocationPassable(aj) and not f.IsOtherMinesClose(aj) then
					local ak = c.GetTechiesMinesInLoc(aj, f.nMinMineDistance * 3 + 100)
					if #ak < 3 then
						return BOT_ACTION_DESIRE_HIGH, aj
					end
				end
				ai = ai + 1
			end
		end
	end
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
