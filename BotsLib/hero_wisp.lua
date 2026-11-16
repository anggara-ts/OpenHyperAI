-- Wisp: skill build, item build, and ability use for this hero.
local a = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local b = require(GetScriptDirectory() .. "/ts_libs/dota/index")
local c = b.BotActionDesire
local d = b.BotMode
local e = b.UnitType
local f = require(GetScriptDirectory() .. "/FuncLib/data/buff")
local g = f.hero_is_healing
local h = require(GetScriptDirectory() .. "/FuncLib/systems/utils")
local i = h.GetTeamFountainTpPoint
local j = h.HasAnyEffect
local k = h.IsValidHero
local l = require(GetScriptDirectory() .. "/FuncLib/hero/hero_builder")
local m = l.buildHeroConfig
local n = l.buildHeroExport
local o = 0.2
local p = 0.75
local q = 0.8
local r = 0.25
local s = 3000
local t = 2
local u = 0.4
local v = GetBot()
local w = dofile(GetScriptDirectory() .. "/FuncLib/hero/minion")
local x = m(
	v,
	{
		skills = { default = { 2, 1, 2, 3, 2, 6, 2, 3, 3, 3, 6, 1, 1, 1, 6 } },
		talents = { default = { t25 = { 10, 0 }, t20 = { 10, 0 }, t15 = { 0, 10 }, t10 = { 0, 10 } } },
		items = {
			pos_1 = {
				"item_tango",
				"item_faerie_fire",
				"item_gauntlets",
				"item_gauntlets",
				"item_gauntlets",
				"item_boots",
				"item_armlet",
				"item_black_king_bar",
				"item_sange",
				"item_ultimate_scepter",
				"item_heavens_halberd",
				"item_travel_boots",
				"item_satanic",
				"item_aghanims_shard",
				"item_assault",
				"item_travel_boots_2",
				"item_ultimate_scepter_2",
				"item_moon_shard",
			},
			pos_4 = {
				"item_priest_outfit",
				"item_mekansm",
				"item_holy_locket",
				"item_glimmer_cape",
				"item_guardian_greaves",
				"item_spirit_vessel",
				"item_shivas_guard",
				"item_moon_shard",
				"item_ultimate_scepter_2",
			},
			pos_5 = {
				"item_blood_grenade",
				"item_mage_outfit",
				"item_holy_locket",
				"item_glimmer_cape",
				"item_mekansm",
				"item_ultimate_scepter",
				"item_shivas_guard",
				"item_cyclone",
				"item_sheepstick",
				"item_wind_waker",
				"item_moon_shard",
				"item_ultimate_scepter_2",
			},
		},
		sell = { "item_black_king_bar", "item_quelling_blade" },
	}
)
local y = v:GetAbilityByName("wisp_tether")
local z = v:GetAbilityByName("wisp_spirits")
local A = v:GetAbilityByName("wisp_overcharge")
local B = v:GetAbilityByName("wisp_relocate")
local C = v:GetAbilityByName("wisp_tether_break")
local D = {}
v.stateTetheredHero = v.stateTetheredHero
local function E(F)
	return j(F, "modifier_tango_heal", unpack(g))
end
local function G(H)
	local I = GameTime() - H:GetLastAttackTime() < 0.33
	local J = H:GetAttackTarget()
	return a.IsGoingOnSomeone(H)
		or J ~= nil and J:GetTeam() == GetOpposingTeam() and I
		or #H:GetNearbyCreeps(200, true) > 2
end
local function K()
	return v:HasModifier("modifier_wisp_tether")
end
local function L()
	if not K() then
		v.stateTetheredHero = nil
	end
	if not y:IsFullyCastable() or not C:IsHidden() then
		return c.None, nil
	end
	local M = y:GetCastRange()
	local N = v:GetNearbyHeroes(M, false, d.None) or {}
	for O, H in ipairs(N) do
		do
			local P
			repeat
				-- Tether is SPELL_IMMUNITY_ALLIES_YES: a BKB carry can be tethered (the magic-immune
				-- skip dropped Io's main fight target). Illusions of allies are skipped instead.
				if H == v or not H:IsAlive() or H:IsIllusion() then
					P = true
					break
				end
				if a.IsRetreating(v) or a.GetHP(v) < r then
					if a.IsRetreating(H) then
						return c.High, H
					end
					P = true
					break
				end
				if a.GetHP(H) < p or a.GetMP(v) > q or E(v) or G(H) then
					return c.High, H
				end
				P = true
			until true
			if not P then
				break
			end
		end
	end
	return c.None, nil
end
local function Q()
	if not A:IsFullyCastable() then
		return c.None
	end
	if K() and v.stateTetheredHero ~= nil and G(v.stateTetheredHero) then
		return c.High
	end
	return c.None
end
local function R()
	if not z:IsFullyCastable() then
		return c.None
	end
	-- Was "#D >= 1" (any enemy hero within 1600): spirits circle Io at 200-650 range, so they
	-- were cast (90-120 mana) at heroes they could not reach. Now: an enemy hero within 800.
	for O, H in ipairs(D) do
		if k(H) and GetUnitToUnitDistance(v, H) <= 800 then
			return c.High
		end
	end
	if #v:GetNearbyNeutralCreeps(500, true) >= t and a.GetMP(v) > u then
		return c.Moderate
	end
	return c.None
end
local function S()
	if not B:IsFullyCastable() then
		return c.None, nil
	end
	if K() and v.stateTetheredHero ~= nil then
		local T = a.GetHP(v.stateTetheredHero)
		local U = a.GetHP(v)
		if T <= o or U <= o then
			local V = v.stateTetheredHero:GetNearbyHeroes(1200, true, d.None) or {}
			local W = #V >= 1 and T < a.GetHP(V[1])
			local X = #D >= 1 and U < a.GetHP(D[1])
			if W or X then
				return c.High, i()
			end
		end
	end
	if not K() and #D >= 1 and a.GetHP(v) < o then
		return c.High, i()
	end
	for O, H in ipairs(GetUnitList(e.AlliedHeroes)) do
		if
			k(H)
			and a.IsInTeamFight(H, 1200)
			and GetUnitToUnitDistance(v, H) > s
			and H:WasRecentlyDamagedByAnyHero(2)
		then
			return c.High, H:GetLocation()
		end
	end
	return c.None, nil
end
local function Y()
	if a.CanNotUseAbility(v) or v:IsInvisible() then
		return
	end
	D = v:GetNearbyHeroes(1600, true, d.None) or {}
	local Z, _ = L()
	if Z > 0 and _ then
		v:Action_UseAbilityOnEntity(y, _)
		v.stateTetheredHero = _
		return
	end
	local a0 = Q()
	if a0 > 0 then
		v:Action_UseAbility(A)
		return
	end
	local a1 = R()
	if a1 > 0 then
		v:Action_UseAbility(z)
		return
	end
	local a2, a3 = S()
	if a2 > 0 and a3 ~= nil then
		v:Action_UseAbilityOnLocation(B, a3)
		return
	end
	-- Follow the tethered ally: the tether breaks past 1000 range (MAX TETHER DISTANCE in the
	-- datafeed) and nothing kept Io near the ally, so modes walked Io away and broke it.
	local th = v.stateTetheredHero
	if K() and k(th) and not a.IsRetreating(v) and GetUnitToUnitDistance(v, th) > 650 then
		if DotaTime() >= (v._wispFollowLogAt or -999) then
			v._wispFollowLogAt = DotaTime() + 5
			pcall(print, string.format(
				"[OHA-WISP] t=%.0f follow-tether ally=%s dist=%d",
				DotaTime(),
				th:GetUnitName(),
				GetUnitToUnitDistance(v, th)
			))
		end
		v:Action_MoveToLocation(th:GetLocation())
	end
end
local function a4(a5)
	if w.IsValidUnit(a5) then
		w.IllusionThink(a5)
	end
end
local a6 = n(x, Y, a4)
return a6
