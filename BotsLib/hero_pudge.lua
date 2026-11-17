-- Pudge: skill build, item build, and ability use for this hero.
local a = {}
local b = GetBot()
local c = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local d = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local e = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local f = c.Skill.GetTalentList(b)
local g = c.Skill.GetAbilityList(b)
local h = c.Item.GetRoleItemsBuyList(b)
local i = {
	{ ["t25"] = { 10, 0 }, ["t20"] = { 0, 10 }, ["t15"] = { 10, 0 }, ["t10"] = { 0, 10 } },
	{ ["t25"] = { 0, 10 }, ["t20"] = { 0, 10 }, ["t15"] = { 0, 10 }, ["t10"] = { 10, 0 } },
	{ ["t25"] = { 10, 0 }, ["t20"] = { 10, 0 }, ["t15"] = { 10, 0 }, ["t10"] = { 0, 10 } },
}
-- 1 Meat Hook, 2 Rot, 3 Meat Shield (pudge_flesh_heap), 6 Dismember. Entries skip talent levels;
-- Dismember stays at 6, 12 and 17. One point each in Hook, Rot, Meat Shield at levels 1-3, then
-- Meat Shield maxed (7), Rot (11), Meat Hook last (16). Same for every position (user call).
local PUDGE_SKILLS = { 1, 2, 3, 3, 3, 6, 3, 2, 2, 2, 6, 1, 1, 1, 6 }
local j = { PUDGE_SKILLS, PUDGE_SKILLS, PUDGE_SKILLS }
local k = j[2]
if h == "pos_2" then
	k = j[1]
end
if h == "pos_3" then
	k = j[2]
end
if h == "pos_4" then
	k = j[3]
end
if h == "pos_5" then
	k = j[3]
end
local l = c.Skill.GetTalentBuild(i[2])
if h == "pos_2" then
	l = c.Skill.GetTalentBuild(i[1])
end
if h == "pos_3" then
	l = c.Skill.GetTalentBuild(i[2])
end
if h == "pos_4" then
	l = c.Skill.GetTalentBuild(i[3])
end
if h == "pos_5" then
	l = c.Skill.GetTalentBuild(i[3])
end
local n = "item_team_aura"
local o = {}
o["pos_2"] = {
	"item_tango",
	"item_double_branches",
	"item_bracer",
	"item_bottle",
	"item_magic_wand",
	"item_boots",
	"item_blink",
	"item_ultimate_scepter",
	"item_pipe",
	"item_travel_boots",
	"item_bloodstone",
	"item_black_king_bar",
	"item_shivas_guard",
	"item_ultimate_scepter_2",
	"item_moon_shard",
	"item_travel_boots_2",
	"item_aghanims_shard",
}
o["pos_3"] = {
	"item_tango",
	"item_double_branches",
	"item_magic_stick",
	"item_magic_wand",
	"item_boots",
	"item_bracer",
	"item_phase_boots",
	"item_blink",
	"item_pipe",
	"item_ultimate_scepter",
	"item_shivas_guard",
	n,
	"item_black_king_bar",
	"item_travel_boots",
	"item_overwhelming_blink",
	"item_ultimate_scepter_2",
	"item_moon_shard",
	"item_travel_boots_2",
	"item_aghanims_shard",
}
o["pos_4"] = {
	"item_tango",
	"item_double_branches",
	"item_tranquil_boots",
	"item_magic_wand",
	"item_rod_of_atos",
	"item_blink",
	"item_aghanims_shard",
	"item_boots_of_bearing",
	"item_ultimate_scepter",
	"item_shivas_guard",
	"item_lotus_orb",
	"item_ultimate_scepter_2",
	"item_moon_shard",
}
o["pos_5"] = {
	"item_tango",
	"item_flask",
	"item_enchanted_mango",
	"item_wind_lace",
	"item_blood_grenade",
	"item_magic_wand",
	"item_tranquil_boots",
	"item_pipe",
	"item_blink",
	"item_aether_lens",
	"item_force_staff",
	"item_lotus_orb",
	"item_gungir",
	"item_overwhelming_blink",
	"item_wind_waker",
	"item_aghanims_shard",
	"item_ultimate_scepter_2",
	"item_moon_shard",
}
o["pos_1"] = {
	"item_tango",
	"item_double_branches",
	"item_bracer",
	"item_magic_wand",
	"item_bracer",
	"item_boots",
	"item_blink",
	"item_ultimate_scepter",
	"item_pipe",
	"item_travel_boots",
	"item_bloodstone",
	"item_black_king_bar",
	"item_shivas_guard",
	"item_ultimate_scepter_2",
	"item_moon_shard",
	"item_travel_boots_2",
	"item_aghanims_shard",
}
a["sBuyList"] = o[h]
a["sSellList"] = { "item_black_king_bar", "item_quelling_blade" }
if c.Role.IsPvNMode() or c.Role.IsAllShadow() then
	a["sBuyList"], a["sSellList"] = { "PvN_mid" }, {}
end
k, l, a["sBuyList"], a["sSellList"] = c.SetUserHeroInit(k, l, a["sBuyList"], a["sSellList"])
a["sSkillList"] = c.Skill.GetSkillList(g, k, f, l)
a["bDeafaultAbility"] = false
a["bDeafaultItem"] = false
function a.MinionThink(p)
	e.MinionThink(p)
end
local q = {
	["npc_dota_hero_sniper"] = true,
	["npc_dota_hero_drow_ranger"] = true,
	["npc_dota_hero_templar_assassin"] = true,
	["npc_dota_hero_nevermore"] = true,
	["npc_dota_hero_zuus"] = true,
	["npc_dota_hero_lina"] = true,
	["npc_dota_hero_silencer"] = true,
	["npc_dota_hero_arc_warden"] = true,
}
local r, s
local t
local u
local v, w
local x
local y
local z
local A
-- Rot read as off right after it was turned on (game 020: "rot-on" 10 times a second while
-- farming, "rot-off" 11 times all game), so every think toggled it again and it flickered. It
-- counts as on when the toggle state or Rot's buff on Pudge says so, and it is toggled at most
-- once every 1.5s.
local function RotOn(ab)
	if ab == nil then
		return false
	end
	local okT, on = pcall(function()
		return ab:GetToggleState()
	end)
	return (okT and on == true) or GetBot():HasModifier("modifier_pudge_rot")
end
function a.ToggleRot(ab)
	local now = DotaTime()
	if now - (b._rotToggleAt or -99) < 1.5 then
		return false
	end
	b._rotToggleAt = now
	b:Action_UseAbility(ab)
	return true
end
function a.SkillsComplement()
	if c.CanNotUseAbility(b) then
		return
	end
	y = c.IsGoingOnSomeone(b)
	z = c.IsRetreating(b)
	A = c.IsAttacking(b)
	local B = SafeAbility(b:GetAbilityByName("pudge_meat_hook"), "pudge_meat_hook", "pudge")
	local C = SafeAbility(b:GetAbilityByName("pudge_rot"), "pudge_rot", "pudge")
	local D = SafeAbility(b:GetAbilityByName("pudge_flesh_heap"), "pudge_flesh_heap", "pudge")
	local E = SafeAbility(b:GetAbilityByName("pudge_dismember"), "pudge_dismember", "pudge")
	x = c.GetProperTarget(b)
	local F = c.GetHP(b)
	local G = C:GetSpecialValueInt("rot_radius")
	local H = c.GetNearbyHeroes(b, G + 50, true, BOT_MODE_NONE)
	if a.BlinkComboStep(C, D, E) then
		return
	end
	if a.BlinkHookStep(B) then
		return
	end
	if a.TryBlink(C, D, E) then
		return
	end
	if a.TryBlinkHook(B) then
		return
	end
	u = a.ConsiderMeatShield(D, C, x, F, G, H)
	if u > 0 then
		b:Action_UseAbility(D)
		return
	end
	if RotOn(C) and #H <= 0 then
		if a.ToggleRot(C) then
			return
		end
	end
	r, s = a.ConsiderMeatHook(B, C, E, x, F, H)
	if r > 0 then
		a.LogPudge("hook", F)
		b:Action_UseAbilityOnLocation(B, s)
		return
	end
	t = a.ConsiderRot(C, x, F, G, H)
	if t > 0 then
		if a.ToggleRot(C) then
			a.LogPudge(RotOn(C) and "rot-off" or "rot-on", F)
			return
		end
	end
	v, w = a.ConsiderDismember(E, x, F, H)
	if v > 0 then
		a.LogPudge("dismember " .. (c.IsValid(w) and (string.gsub(w:GetUnitName(), "npc_dota_hero_", "")) or "?"), F)
		b:Action_ClearActions(false)
		if c.CanCastAbility(D) and not b:HasModifier("modifier_pudge_flesh_heap_block") then
			b:ActionQueue_UseAbility(D)
		end
		if F > 0.3 and c.CanCastAbility(C) and not RotOn(C) then
			b:ActionQueue_UseAbility(C)
		end
		b:ActionQueue_UseAbilityOnEntity(E, w)
		return
	end
end
-- After an engage blink, for 3s: Meat Shield, then Rot on, then Dismember on the blink target,
-- one order per think. Ends when Dismember goes out, the target is gone, or the 3s run out.
function a.BlinkComboStep(rot, shield, dismember)
	local st = b._pudgeCombo
	if st == nil then
		return false
	end
	local x0 = st.target
	if DotaTime() - st.at > 3 or not c.IsValidHero(x0) or not x0:IsAlive() then
		b._pudgeCombo = nil
		return false
	end
	if not st.shield then
		st.shield = true
		if shield ~= nil and c.CanCastAbility(shield) and not b:HasModifier("modifier_pudge_flesh_heap_block") then
			a.LogPudge("blink-combo shield", c.GetHP(b))
			b:Action_UseAbility(shield)
			return true
		end
	end
	if not st.rot then
		st.rot = true
		if rot ~= nil and rot:IsTrained() and rot:IsFullyCastable() and not RotOn(rot) then
			if a.ToggleRot(rot) then
				a.LogPudge("blink-combo rot", c.GetHP(b))
				return true
			end
		end
	end
	b._pudgeCombo = nil
	if dismember ~= nil and c.CanCastAbility(dismember) and c.CanCastOnMagicImmune(x0) then
		a.LogPudge("blink-combo dismember " .. (string.gsub(x0:GetUnitName(), "npc_dota_hero_", "")), c.GetHP(b))
		b:Action_UseAbilityOnEntity(dismember, x0)
		return true
	end
	return false
end
function a.TryBlink(rot, shield, dismember)
	if not c.CanBlinkDagger(b) or b.Blink == nil or b:IsRooted() then
		return false
	end
	local blink = b.Blink
	local range = 1200
	if blink:GetName() == "item_arcane_blink" then
		range = 1400
	end
	if z and b:DistanceFromFountain() > 900 then
		local enemies = c.GetNearbyHeroes(b, 1200, true, BOT_MODE_NONE)
		local ancient = GetAncient(GetTeam())
		if enemies ~= nil and #enemies >= 1 and ancient ~= nil then
			local dest = c.GetLocationTowardDistanceLocation(b, ancient:GetLocation(), range)
			if IsLocationPassable(dest) then
				b:Action_UseAbilityOnLocation(blink, dest)
				return true
			end
		end
	end
	-- Engage blink (chase or initiate), user call: no "target below 60% / disabled / alone" gate
	-- any more, which kept him from initiating. Needs 40%+ HP, and our heroes near the target
	-- (Pudge always counted) at least as many as theirs. The whole combo is queued at once:
	-- blink to point blank -> Meat Shield -> Rot on -> Dismember. It used to be the blink alone,
	-- and the next think could hook or Rot first.
	if y and c.GetHP(b) >= 0.4 and c.IsValidHero(x) and not c.IsSuspiciousIllusion(x) then
		local dist = GetUnitToUnitDistance(b, x)
		if
			dist > 350
			and dist <= range + 150
			and not c.IsLocationInChrono(x:GetLocation())
			and not c.IsLocationInBlackHole(x:GetLocation())
		then
			local friends = 1
			for _, ally in pairs(c.GetAlliesNearLoc(x:GetLocation(), 1100) or {}) do
				if ally ~= b then
					friends = friends + 1
				end
			end
			local foes = c.GetEnemiesNearLoc(x:GetLocation(), 1100) or {}
			if friends >= #foes then
				local dest = x:GetLocation()
				if dist > range then
					dest = c.GetLocationTowardDistanceLocation(b, x:GetLocation(), range - 50)
				end
				if IsLocationPassable(dest) then
					-- One step per think after this (see BlinkComboStep): a queue behind the blink is
					-- wiped by the next order from the spell think or the mode.
					b._pudgeCombo = { target = x, at = DotaTime(), shield = false, rot = false }
					a.LogPudge(
						"blink-combo start target=" .. (string.gsub(x:GetUnitName(), "npc_dota_hero_", "")) .. " dist=" .. math.floor(dist),
						c.GetHP(b)
					)
					b:Action_UseAbilityOnLocation(blink, dest)
					return true
				end
			end
		end
	end
	return false
end
-- Blink then hook (user call): an enemy hero Pudge cannot hook from where he stands (out of range,
-- or a unit in the way) but could from a blink away. Blink to a spot on a ring around the target
-- (hook range - 250) that has a clear hook line, no enemy hero within 500, and is closest to an
-- allied hero or one of our towers (one of those within 1200), so the target is pulled into our
-- side; hook on the next think. Not while retreating, 50%+ HP, mana for the hook.
-- Logged: [OHA-PUDGE] blink-hook.
local function HookLineClear(from, to, width, target)
	for _, u in pairs(GetUnitList(UNIT_LIST_ALL) or {}) do
		if
			c.IsValid(u)
			and u ~= b
			and u ~= target
			and not u:IsBuilding()
			and not string.find(u:GetUnitName(), "ward")
			and GetUnitToLocationDistance(u, from) <= 1600
		then
			local l = PointToLineDistance(from, to, u:GetLocation())
			if l ~= nil and l.within and l.distance <= width + u:GetBoundingRadius() then
				return false
			end
		end
	end
	return true
end
local function NearestAnchor(p)
	local best = math.huge
	for _, ally in pairs(GetUnitList(UNIT_LIST_ALLIED_HEROES) or {}) do
		if ally ~= b and ally:IsAlive() and not ally:IsIllusion() then
			best = math.min(best, GetUnitToLocationDistance(ally, p))
		end
	end
	for _, t in pairs(GetUnitList(UNIT_LIST_ALLIED_BUILDINGS) or {}) do
		if t ~= nil and t:IsAlive() and t:IsTower() then
			best = math.min(best, GetUnitToLocationDistance(t, p))
		end
	end
	return best
end
function a.TryBlinkHook(hook)
	if not c.CanBlinkDagger(b) or b.Blink == nil or b:IsRooted() or not c.CanCastAbility(hook) then
		return false
	end
	if z or c.GetHP(b) < 0.5 or b:GetMana() < hook:GetManaCost() then
		return false
	end
	local blinkRange = b.Blink:GetName() == "item_arcane_blink" and 1400 or 1200
	local hookRange = c.GetProperCastRange(false, b, hook:GetCastRange())
	local width = hook:GetSpecialValueInt("hook_width")
	local target = nil
	for _, e in pairs(GetUnitList(UNIT_LIST_ENEMY_HEROES) or {}) do
		if c.IsValidHero(e) and not c.IsSuspiciousIllusion(e) and c.CanCastOnNonMagicImmune(e) and not e:IsInvulnerable() then
			local d = GetUnitToUnitDistance(b, e)
			local hookableNow = d <= hookRange - 100 and HookLineClear(b:GetLocation(), e:GetLocation(), width, e)
			if not hookableNow and d > hookRange - 100 - blinkRange and d <= blinkRange + hookRange - 250 then
				if target == nil or c.GetHP(e) < c.GetHP(target) then
					target = e
				end
			end
		end
	end
	if target == nil then
		return false
	end
	local tl = target:GetLocation()
	local ring = hookRange - 250
	local best, bestScore = nil, 1200
	for deg = 0, 330, 30 do
		local rad = math.rad(deg)
		local p = Vector(tl.x + math.cos(rad) * ring, tl.y + math.sin(rad) * ring, tl.z)
		if
			GetUnitToLocationDistance(b, p) <= blinkRange
			and IsLocationPassable(p)
			and #(c.GetEnemiesNearLoc(p, 500) or {}) == 0
			and HookLineClear(p, tl, width, target)
		then
			local score = NearestAnchor(p)
			if score < bestScore then
				best, bestScore = p, score
			end
		end
	end
	if best == nil then
		return false
	end
	b._pudgeBlinkHook = { target = target, at = DotaTime() }
	pcall(print, string.format(
		"[OHA-PUDGE] t=%.0f blink-hook start target=%s dist=%d anchor=%d",
		DotaTime(),
		(string.gsub(target:GetUnitName(), "npc_dota_hero_", "")),
		math.floor(GetUnitToUnitDistance(b, target)),
		math.floor(bestScore)
	))
	b:Action_UseAbilityOnLocation(b.Blink, best)
	return true
end
-- The hook after a blink-hook blink (Blink is instant; this runs on the next think).
function a.BlinkHookStep(hook)
	local st = b._pudgeBlinkHook
	if st == nil then
		return false
	end
	b._pudgeBlinkHook = nil
	local t = st.target
	if DotaTime() - st.at > 1.5 or not c.IsValidHero(t) or not t:IsAlive() or not c.CanCastAbility(hook) then
		return false
	end
	local speed = math.max(1, hook:GetSpecialValueInt("hook_speed"))
	local d = GetUnitToUnitDistance(b, t)
	b:Action_UseAbilityOnLocation(hook, t:GetExtrapolatedLocation(hook:GetCastPoint() + d / speed))
	pcall(print, string.format(
		"[OHA-PUDGE] t=%.0f blink-hook hook target=%s dist=%d",
		DotaTime(),
		(string.gsub(t:GetUnitName(), "npc_dota_hero_", "")),
		math.floor(d)
	))
	return true
end
-- [OHA-PUDGE] one line per cast decision, with HP, mode and the heroes around him.
-- The combo, hooks, Rot and Dismember work as intended: no longer printed (call sites kept).
function a.LogPudge(what, hp)
	if true then
		return
	end
	pcall(function()
		local foes = #(c.GetNearbyHeroes(b, 1200, true, BOT_MODE_NONE) or {})
		local friends = #(c.GetNearbyHeroes(b, 1200, false, BOT_MODE_NONE) or {})
		print(string.format(
			"[OHA-PUDGE] t=%.0f %s hp=%.2f mode=%d engaging=%s retreating=%s foes=%d allies=%d",
			DotaTime(),
			what,
			hp or c.GetHP(b),
			b:GetActiveMode(),
			tostring(y and true or false),
			tostring(z and true or false),
			foes,
			friends - 1
		))
	end)
end
function a.ConsiderMeatHook(B, C, E, x, F, H)
	if not B:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local K = c.GetProperCastRange(false, b, B:GetCastRange())
	local L = B:GetCastPoint()
	local M = B:GetSpecialValueInt("hook_width")
	local N = B:GetSpecialValueInt("hook_speed")
	local O = B:GetSpecialValueInt("damage")
	local P = B:GetManaCost()
	local Q = c.GetTPTarget(b, K)
	if Q and not c.IsUnitBetweenMeAndLocation(b, Q, Q:GetLocation(), M) then
		return BOT_ACTION_DESIRE_HIGH, Q:GetLocation()
	end
	local J = c.GetNearbyHeroes(b, K, true, BOT_MODE_NONE)
	for R, S in pairs(J) do
		if c.IsValidHero(S) and not c.IsSuspiciousIllusion(S) then
			if S:IsChanneling() or c.IsCastingUltimateAbility(S) then
				if not c.IsUnitBetweenMeAndLocation(b, S, S:GetLocation(), M) then
					return BOT_ACTION_DESIRE_HIGH, S:GetLocation()
				end
			end
			if S:HasModifier("modifier_teleporting") then
				local T = c.GetModifierTime(S, "modifier_teleporting")
				local U = GetUnitToUnitDistance(b, S) / N + L
				if T > U and not c.IsUnitBetweenMeAndLocation(b, S, S:GetLocation(), M) then
					return BOT_ACTION_DESIRE_HIGH, S:GetLocation()
				end
			end
			if
				c.CanKillTarget(S, O, DAMAGE_TYPE_PURE)
				and not S:HasModifier("modifier_abaddon_borrowed_time")
				and not S:HasModifier("modifier_dazzle_shallow_grave")
				and not S:HasModifier("modifier_necrolyte_reapers_scythe")
				and not S:HasModifier("modifier_oracle_false_promise_timer")
				and not S:HasModifier("modifier_templar_assassin_refraction_absorb")
			then
				local V = GetUnitToUnitDistance(b, S) / N + L
				local W = c.GetCorrectLoc(S, V)
				if
					not c.IsUnitBetweenMeAndLocation(b, S, W, M)
					and not c.IsLocationInChrono(W)
					and not c.IsLocationInBlackHole(W)
				then
					return BOT_ACTION_DESIRE_HIGH, W
				end
			end
		end
	end
	-- Engage hooks need 40%+ HP: the hook drags an enemy onto him, which is a fight he has to win.
	if y and F >= 0.4 then
		local X = c.GetNearbyHeroes(b, 1200, false, BOT_MODE_NONE)
		local Y = c.GetStrongestUnit(K, b, true, true, 5)
		local Z = c.GetNearbyHeroes(b, K, true, BOT_MODE_NONE)
		for R, S in pairs(Z) do
			if
				c.IsValidHero(S)
				and not c.IsSuspiciousIllusion(S)
				and not S:HasModifier("modifier_necrolyte_reapers_scythe")
			then
				local _ = c.GetNearbyHeroes(S, 1200, false, BOT_MODE_NONE)
				if X ~= nil and _ ~= nil and #X >= #_ and q[S:GetUnitName()] then
					local V = GetUnitToUnitDistance(b, S) / N + L
					local W = c.GetCorrectLoc(S, V)
					if
						not c.IsUnitBetweenMeAndLocation(b, S, W, M)
						and not c.IsLocationInChrono(W)
						and not c.IsLocationInBlackHole(W)
					then
						return BOT_ACTION_DESIRE_HIGH, W
					end
				end
			end
		end
		if
			c.IsValidTarget(Y)
			and not c.IsSuspiciousIllusion(Y)
			and not Y:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			local _ = c.GetNearbyHeroes(Y, 1200, false, BOT_MODE_NONE)
			if X ~= nil and _ ~= nil and #X >= #_ then
				local V = GetUnitToUnitDistance(b, Y) / N + L
				local W = c.GetCorrectLoc(Y, V)
				if
					not c.IsUnitBetweenMeAndLocation(b, Y, W, M)
					and not c.IsLocationInChrono(W)
					and not c.IsLocationInBlackHole(W)
				then
					return BOT_ACTION_DESIRE_HIGH, W
				end
			end
		end
	end
	if c.IsLaning(b) then
		local a0 = c.GetManaThreshold(b, P, { C, E })
		if c.GetMP(b) < a0 then
		else
			local a1 = b:GetNearbyLaneCreeps(K, true)
			for R, a2 in pairs(a1) do
				if
					c.IsValid(a2)
					and not c.IsRunning(a2)
					and c.CanBeAttacked(a2)
					and c.IsKeyWordUnit("siege", a2)
					and a2:GetHealth() <= O
				then
					local a3 = b:GetNearbyHeroes(1600, true, BOT_MODE_NONE)
					if
						(
							c.IsValid(a3[1]) and GetUnitToUnitDistance(a3[1], a2) < 500
							or not c.IsInRange(b, a2, b:GetAttackRange() + 25)
						)
						and not c.IsUnitBetweenMeAndLocation(b, a2, a2:GetLocation(), M)
						and (c.IsCore(b) or not c.IsCore(b) and not c.IsThereCoreNearby(1200))
					then
						return BOT_ACTION_DESIRE_HIGH, a2:GetLocation()
					end
				end
			end
			local a4 = b:GetNearbyTowers(700, false)
			local Z = c.GetNearbyHeroes(b, K, true, BOT_MODE_NONE)
			if c.IsValidBuilding(a4[1]) and c.IsValidHero(Z[1]) and c.IsInRange(b, a4[1], 500) then
				local a5 = a4[1]:GetAttackTarget()
				if a5 == nil then
					for R, S in pairs(Z) do
						if
							c.IsValidHero(S)
							and not c.IsSuspiciousIllusion(S)
							and not S:HasModifier("modifier_abaddon_borrowed_time")
							and not S:HasModifier("modifier_abaddon_aphotic_shield")
						then
							local V = GetUnitToUnitDistance(b, S) / N + L
							local W = c.GetCorrectLoc(S, V)
							if not c.IsUnitBetweenMeAndLocation(b, S, W, M) then
								return BOT_ACTION_DESIRE_HIGH, W
							end
						end
					end
				end
			end
		end
	end
	local I = b:GetNearbyHeroes(K, false, BOT_MODE_NONE)
	for R, a6 in pairs(I) do
		if
			c.IsValidHero(a6)
			and not a6:IsIllusion()
			and (a6:HasModifier("modifier_enigma_black_hole_pull") or a6:HasModifier(
				"modifier_faceless_void_chronosphere_freeze"
			))
			and not c.IsUnitBetweenMeAndLocation(b, a6, a6:GetLocation(), M)
		then
			return BOT_ACTION_DESIRE_HIGH, a6:GetLocation()
		end
		-- Save hook on an ally running from a chaser (user call, rework): the ally must be in hook
		-- range and 400+ away (a pull worth having), the chaser within 700 of the ALLY (it used to be
		-- "within half a hook range of Pudge", so it fired only with the enemy already on Pudge and
		-- never checked the ally's own distance), and Pudge 300+ closer to safety than the ally (it
		-- was half a hook range, keeping Pudge too far back). Logged: [OHA-PUDGE] ally-hook.
		local allyDist = GetUnitToUnitDistance(b, a6)
		if
			c.IsValidHero(a6)
			and a6 ~= b
			and not a6:IsIllusion()
			and c.IsRetreating(a6)
			and a6:WasRecentlyDamagedByAnyHero(2.1)
			and c.IsRunning(a6)
			and c.GetMP(b) > 0.31
			and allyDist >= 400
			and allyDist <= K
		then
			local chaser = nil
			for _, e in pairs(a6:GetNearbyHeroes(700, true, BOT_MODE_NONE) or {}) do
				if
					c.IsValidHero(e)
					and not c.IsSuspiciousIllusion(e)
					and not c.IsDisabled(e)
					and not c.IsTaunted(e)
					and e:IsFacingLocation(a6:GetLocation(), 30)
					and not e:HasModifier("modifier_enigma_black_hole_pull")
					and not e:HasModifier("modifier_faceless_void_chronosphere_freeze")
					and not e:HasModifier("modifier_necrolyte_reapers_scythe")
				then
					chaser = e
					break
				end
			end
			local esc = c.GetEscapeLoc()
			if
				chaser ~= nil
				and GetUnitToLocationDistance(a6, esc) - GetUnitToLocationDistance(b, esc) >= 300
				and not c.IsUnitBetweenMeAndLocation(b, a6, a6:GetLocation(), M)
			then
				pcall(print, string.format(
					"[OHA-PUDGE] t=%.0f ally-hook %s chaser=%s dist=%d",
					DotaTime(),
					(string.gsub(a6:GetUnitName(), "npc_dota_hero_", "")),
					(string.gsub(chaser:GetUnitName(), "npc_dota_hero_", "")),
					math.floor(allyDist)
				))
				return BOT_ACTION_DESIRE_HIGH, a6:GetLocation()
			end
		end
	end
	if c.IsDoingRoshan(b) then
		if
			c.IsRoshan(x)
			and c.IsInRange(b, x, 500)
			and A
			and not c.IsUnitBetweenMeAndLocation(b, x, x:GetLocation(), M)
		then
			return BOT_ACTION_DESIRE_HIGH, x:GetLocation()
		end
	end
	if c.IsDoingTormentor(b) then
		if
			c.IsTormentor(x)
			and c.IsInRange(b, x, 400)
			and A
			and not c.IsUnitBetweenMeAndLocation(b, x, x:GetLocation(), M)
		then
			return BOT_ACTION_DESIRE_HIGH, x:GetLocation()
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function a.ConsiderRot(C, x, F, G, H)
	if not C:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
	end
	if RotOn(C) and #H <= 0 then
		return BOT_ACTION_DESIRE_HIGH
	end
	-- Rot hurts Pudge too (Valve data: non-lethal self damage). In fights it stayed on at any HP;
	-- now off below 30% while engaging and below 40% while running away.
	local rotFloor = z and 0.4 or 0.3
	if (y or z) and F < rotFloor then
		if RotOn(C) then
			return BOT_ACTION_DESIRE_HIGH
		end
		return BOT_ACTION_DESIRE_NONE
	end
	if y then
		for R, S in pairs(H) do
			if
				c.IsValidHero(S)
				and (c.CanCastOnNonMagicImmune(S) or #H >= 2)
				and not c.IsSuspiciousIllusion(S)
				and not S:HasModifier("modifier_abaddon_borrowed_time")
				and not S:HasModifier("modifier_dazzle_shallow_grave")
				and not S:HasModifier("modifier_necrolyte_reapers_scythe")
			then
				if RotOn(C) == false then
					return BOT_ACTION_DESIRE_HIGH
				else
					return BOT_ACTION_DESIRE_NONE
				end
			end
		end
	end
	if z then
		for R, S in pairs(H) do
			if
				c.IsValidHero(S)
				and (c.CanCastOnNonMagicImmune(S) or #H >= 2)
				and not c.IsSuspiciousIllusion(S)
				and not S:HasModifier("modifier_abaddon_borrowed_time")
				and not S:HasModifier("modifier_necrolyte_reapers_scythe")
			then
				if RotOn(C) == false then
					return BOT_ACTION_DESIRE_HIGH
				else
					return BOT_ACTION_DESIRE_NONE
				end
			end
		end
	end
	if c.IsPushing(b) or c.IsDefending(b) then
		local a1 = b:GetNearbyLaneCreeps(G, true)
		if a1 ~= nil then
			if #a1 >= 1 and RotOn(C) == false and A and F > 0.2 then
				return BOT_ACTION_DESIRE_HIGH
			else
				if (#a1 == 0 or F < 0.2) and RotOn(C) == true then
					return BOT_ACTION_DESIRE_HIGH
				end
				return BOT_ACTION_DESIRE_NONE
			end
		end
	end
	if c.IsFarming(b) then
		local a8 = b:GetNearbyNeutralCreeps(G)
		if a8 ~= nil then
			if #a8 >= 1 and RotOn(C) == false and A and F > 0.35 then
				return BOT_ACTION_DESIRE_HIGH
			else
				if (#a8 == 0 or F < 0.35) and RotOn(C) == true then
					return BOT_ACTION_DESIRE_HIGH
				end
				return BOT_ACTION_DESIRE_NONE
			end
		end
		local a1 = b:GetNearbyLaneCreeps(G, true)
		if a1 ~= nil then
			if #a1 >= 1 and RotOn(C) == false and A and F > 0.2 then
				return BOT_ACTION_DESIRE_HIGH
			else
				if (#a1 == 0 or F < 0.2) and RotOn(C) == true then
					return BOT_ACTION_DESIRE_HIGH
				end
				return BOT_ACTION_DESIRE_NONE
			end
		end
	end
	if c.IsLaning(b) and (c.IsCore(b) or not c.IsCore(b) and not c.IsThereNonSelfCoreNearby(1200)) then
		local a1 = b:GetNearbyLaneCreeps(G, true)
		local Z = c.GetNearbyHeroes(b, 1200, true, BOT_MODE_NONE)
		if a1 ~= nil and Z ~= nil and #Z == 0 then
			if #a1 >= 1 and RotOn(C) == false and A and F > 0.5 then
				return BOT_ACTION_DESIRE_HIGH
			else
				if (#a1 == 0 or F < 0.5) and RotOn(C) == true then
					return BOT_ACTION_DESIRE_HIGH
				end
				return BOT_ACTION_DESIRE_NONE
			end
		end
	end
	if c.IsDoingRoshan(b) then
		if c.IsRoshan(x) and c.CanCastOnNonMagicImmune(x) and c.IsInRange(b, x, G) and A and F > 0.4 then
			if RotOn(C) == false and F > 0.4 then
				return BOT_ACTION_DESIRE_HIGH
			else
				if F < 0.4 and RotOn(C) == true then
					return BOT_ACTION_DESIRE_HIGH
				end
				return BOT_ACTION_DESIRE_NONE
			end
		end
	end
	if c.IsDoingTormentor(b) then
		if c.IsTormentor(x) and c.IsInRange(b, x, G) and A then
			if RotOn(C) == false then
				return BOT_ACTION_DESIRE_HIGH
			else
				if F < 0.65 and RotOn(C) == true then
					return BOT_ACTION_DESIRE_HIGH
				end
				return BOT_ACTION_DESIRE_NONE
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function a.ConsiderMeatShield(D, C, x, F, G, H)
	if not c.CanCastAbility(D) or b:HasModifier("modifier_pudge_flesh_heap_block") then
		return BOT_ACTION_DESIRE_NONE
	end
	local near = c.GetNearbyHeroes(b, 800, true, BOT_MODE_NONE)
	local engaged = near ~= nil
		and #near >= 1
		and (y or z or b:WasRecentlyDamagedByAnyHero(2.0) or b:WasRecentlyDamagedByTower(1.5))
	if engaged then
		return BOT_ACTION_DESIRE_HIGH
	end
	local rotOn = RotOn(C)
	local wantsRot = not rotOn and a.ConsiderRot(C, x, F, G, H) > 0
	if (rotOn or wantsRot) and ((H ~= nil and #H >= 1) or F < 0.7) then
		return BOT_ACTION_DESIRE_HIGH
	end
	return BOT_ACTION_DESIRE_NONE
end
function a.ConsiderDismember(E, x, F, H)
	if not E:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local K = c.GetProperCastRange(false, b, E:GetCastRange())
	local a9 = b:GetAttributeValue(ATTRIBUTE_STRENGTH)
	local aa = E:GetSpecialValueFloat("strength_damage")
	local ab = E:GetSpecialValueFloat("AbilityChannelTime")
	local O = E:GetSpecialValueInt("dismember_damage") + a9 * aa
	if y then
		local X = c.GetNearbyHeroes(b, 1200, false, BOT_MODE_NONE)
		local Y = c.GetStrongestUnit(K, b, true, true, 5)
		if
			c.IsValidTarget(Y)
			and not c.IsSuspiciousIllusion(Y)
			and not Y:HasModifier("modifier_abaddon_borrowed_time")
			and not Y:HasModifier("modifier_dazzle_shallow_grave")
			and not Y:HasModifier("modifier_necrolyte_reapers_scythe")
			and not Y:HasModifier("modifier_templar_assassin_refraction_absorb")
			and (c.CanCastOnNonMagicImmune(Y) or c.CanCastOnMagicImmune(Y))
		then
			local _ = c.GetNearbyHeroes(Y, 1200, false, BOT_MODE_NONE)
			if X ~= nil and _ ~= nil and #X >= #_ then
				return BOT_ACTION_DESIRE_HIGH, Y
			end
		end
	end
	if z then
		local X = c.GetNearbyHeroes(b, 1200, false, BOT_MODE_NONE)
		local ac = c.GetAttackableWeakestUnit(b, K, true, true)
		if
			c.IsValidTarget(ac)
			and not c.IsSuspiciousIllusion(ac)
			and not ac:HasModifier("modifier_abaddon_borrowed_time")
			and not ac:HasModifier("modifier_dazzle_shallow_grave")
			and not ac:HasModifier("modifier_necrolyte_reapers_scythe")
			and not ac:HasModifier("modifier_templar_assassin_refraction_absorb")
		then
			-- Running away: only a Dismember that kills. It went on the weakest enemy whenever the
			-- enemies outnumbered us, or below 20% HP, which kept him channelling 2.75s in place
			-- while outnumbered.
			if c.IsInRange(b, ac, K) and c.WillKillTarget(ac, O, DAMAGE_TYPE_MAGICAL, ab) then
				return BOT_ACTION_DESIRE_HIGH, ac
			end
		end
	end
	if c.IsInLaningPhase(b) then
		local Z = c.GetNearbyHeroes(b, K + 100, true, BOT_MODE_NONE)
		local a4 = b:GetNearbyTowers(700, true)
		if Z ~= nil and #Z == 1 and a4 ~= nil and #a4 == 0 then
			if
				c.IsValidHero(Z[1])
				and c.WillKillTarget(Z[1], O, DAMAGE_TYPE_MAGICAL, ab)
				and not c.IsSuspiciousIllusion(Z[1])
				and not Z[1]:HasModifier("modifier_abaddon_borrowed_time")
				and not Z[1]:HasModifier("modifier_dazzle_shallow_grave")
				and not Z[1]:HasModifier("modifier_oracle_false_promise_timer")
				and not Z[1]:HasModifier("modifier_templar_assassin_refraction_absorb")
			then
				return BOT_ACTION_DESIRE_HIGH, Z[1]
			end
		end
	end
	if c.IsDoingRoshan(b) then
		if c.IsRoshan(x) and c.CanCastOnNonMagicImmune(x) and c.IsInRange(b, x, 500) and A then
			return BOT_ACTION_DESIRE_HIGH, x
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
return a
