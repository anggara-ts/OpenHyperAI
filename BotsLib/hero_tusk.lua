-- Tusk: skill build, item build, and ability use for this hero.
local a = {}
local b = GetBot()
local c = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local d = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local e = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local f = c.Skill.GetTalentList(b)
local g = c.Skill.GetAbilityList(b)
local h = c.Item.GetRoleItemsBuyList(b)
local i = { ["t25"] = { 10, 0 }, ["t20"] = { 0, 10 }, ["t15"] = { 10, 0 }, ["t10"] = { 10, 0 } }
local j = { { 3, 1, 2, 3, 3, 6, 3, 2, 2, 2, 6, 1, 1, 1, 6 } }
local k = c.Skill.GetRandomBuild(j)
local l = c.Skill.GetTalentBuild(i)
local m = {}
m["pos_4"] = {
	"item_double_tango",
	"item_faerie_fire",
	"item_wind_lace",
	"item_magic_wand",
	"item_arcane_boots",
	"item_blink",
	"item_guardian_greaves",
	"item_cyclone",
	"item_ultimate_scepter",
	"item_aghanims_shard",
	"item_black_king_bar",
	"item_lotus_orb",
	"item_gungir",
	"item_wind_waker",
	"item_overwhelming_blink",
	"item_ultimate_scepter_2",
	"item_moon_shard",
}
m["pos_5"] = {
	"item_double_tango",
	"item_faerie_fire",
	"item_wind_lace",
	"item_magic_wand",
	"item_tranquil_boots",
	"item_boots_of_bearing",
	"item_pipe",
	"item_ultimate_scepter",
	"item_aghanims_shard",
	"item_pavise",
	"item_blink",
	"item_solar_crest",
	"item_heavens_halberd",
	"item_lotus_orb",
	"item_gungir",
	"item_overwhelming_blink",
	"item_ultimate_scepter_2",
	"item_moon_shard",
}
m["pos_1"] = {
	"item_tank_outfit",
	"item_echo_sabre",
	"item_ring_of_health",
	"item_vanguard",
	"item_crimson_guard",
	-- No Aghanim's Scepter on the core: its Walrus Kick often knocked a ganked enemy away
	-- to safety. Blink to land the snowball/punch, BKB to stay in the fight.
	"item_blink",
	"item_black_king_bar",
	"item_heavens_halberd",
	"item_assault",
	"item_travel_boots",
	"item_aghanims_shard",
	"item_satanic",
	"item_moon_shard",
	"item_heart",
	"item_travel_boots_2",
}
m["pos_2"] = m["pos_1"]
m["pos_3"] = m["pos_1"]
a["sBuyList"] = m[h]
a["sSellList"] = { "item_black_king_bar", "item_quelling_blade" }
if c.Role.IsPvNMode() or c.Role.IsAllShadow() then
	a["sBuyList"], a["sSellList"] = { "PvN_antimage" }, {}
end
k, l, a["sBuyList"], a["sSellList"] = c.SetUserHeroInit(k, l, a["sBuyList"], a["sSellList"])
a["sSkillList"] = c.Skill.GetSkillList(g, k, f, l)
a["bDeafaultAbility"] = false
-- Tusk is invulnerable inside his snowball; spell logic must still run to launch it.
a["bThinkWhileInvulnerable"] = true
a["bDeafaultItem"] = false
function a.MinionThink(n)
	e.MinionThink(n)
end
local o = SafeAbility(b:GetAbilityByName("tusk_ice_shards"), "tusk_ice_shards", "tusk")
local p = SafeAbility(b:GetAbilityByName("tusk_snowball"), "tusk_snowball", "tusk")
local q = SafeAbility(b:GetAbilityByName("tusk_launch_snowball"), "tusk_launch_snowball", "tusk")
local r = SafeAbility(b:GetAbilityByName("tusk_tag_team"), "tusk_tag_team", "tusk")
local s = SafeAbility(b:GetAbilityByName("tusk_walrus_kick"), "tusk_walrus_kick", "tusk")
local t = SafeAbility(b:GetAbilityByName("tusk_walrus_punch"), "tusk_walrus_punch", "tusk")
local u = SafeAbility(b:GetAbilityByName("tusk_drinking_buddies"), "tusk_drinking_buddies", "tusk")
local v, w
local x, y
local z
local A
local B, C
local D, E
local F, G
local H
if b.snowballHeroRetreat then
	b.snowballHeroRetreat = false
end
local I
local J
local K
function a.SkillsComplement()
	-- The hold flag only belongs to the escape snowball that set it. Clear it once Tusk is
	-- out of the snowball, or every later snowball would also wait out the full duration.
	if b.snowballHeroRetreat and q:IsHidden() and DotaTime() > (b._snowballRetreatAt or -99) + 1.5 then
		b.snowballHeroRetreat = false
	end
	-- Walrus Punch is an autocast attack spell. With autocast on, any right-click on a hero
	-- punches without Tag Team first (7:04 on Mirana, no Tag Team, no punch decision of ours).
	-- Keep it off so every Punch goes through ConsiderWalrusPunch and Tag Team leads.
	if t ~= nil and not t:IsNull() and t:IsTrained() and t:GetAutoCastState() then
		pcall(print, string.format("[OHA-TUSK] t=%.0f punch-autocast was=on turned=off", DotaTime()))
		t:ToggleAutoCast()
	end
	-- Launch as soon as the snowball is up, before the busy-casting check and every other
	-- spell. Checked after them, it could wait out the whole 3s windup while engaging. Only an
	-- escape snowball (snowballHeroRetreat) keeps rolling, to stay out of reach.
	if a.ConsiderLaunchSnowball() > 0 and not b:IsStunned() and not b:IsHexed() and not b:IsSilenced() then
		pcall(print, string.format(
			"[OHA-TUSK] t=%.0f snowball-launch after=%.1fs",
			DotaTime(),
			DotaTime() - (b._snowballCastAt or DotaTime())
		))
		b:Action_UseAbility(q)
		return
	end
	if c.CanNotUseAbility(b) then
		return
	end
	local L = d.Build(b)
	I = L.isEngaging
	J = L.isRetreating
	K = c.IsAttacking(b)
	H = L.target
	A = a.ConsiderTagTeam()
	if A > 0 then
		b:Action_UseAbility(r)
		return
	end
	F, G = a.ConsiderDrinkingBuddies()
	if F > 0 then
		b:Action_UseAbilityOnEntity(u, G)
		return
	end
	v, w = a.ConsiderIceShards()
	if v > 0 then
		b:Action_UseAbilityOnLocation(o, w)
		return
	end
	x, y = a.ConsiderSnowball()
	if x > 0 then
		b:Action_UseAbilityOnEntity(p, y)
		b._snowballCastAt = DotaTime()
		return
	end
	B, C = a.ConsiderWalrusKick()
	if B > 0 then
		b:Action_UseAbilityOnEntity(s, C)
		return
	end
	D, E = a.ConsiderWalrusPunch()
	if D > 0 then
		-- Tag Team first when it can go: its bonus damage applies to the Punch. Tag Team keys
		-- off Tusk's target and Punch off any hero in reach, so in lane (target a creep) the
		-- Punch went out alone (7:04).
		local tagWhy = a.TagTeamBeforePunch(E)
		if tagWhy == "cast" then
			b:Action_UseAbility(r)
			return
		end
		pcall(print, string.format(
			"[OHA-TUSK] t=%.0f punch target=%s hp=%.2f tagTeam=%s mp=%.2f",
			DotaTime(),
			E and (string.gsub(E:GetUnitName(), "npc_dota_hero_", "")) or "-",
			E and c.GetHP(E) or 0,
			tagWhy,
			c.GetMP(b)
		))
		b:Action_UseAbilityOnEntity(t, E)
		return
	end
end
function a.ConsiderIceShards()
	if not o:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local M = c.GetProperCastRange(false, b, o:GetCastRange())
	local N = o:GetCastPoint()
	local O = o:GetSpecialValueInt("shard_width")
	local P = o:GetSpecialValueInt("shard_damage")
	local Q = o:GetSpecialValueInt("shard_speed")
	-- The shards ring the target point (7 shards 200 out), so aim where he will be when the
	-- ball arrives. The old aim added 2s on top and landed the ring ~700 ahead of a runner.
	local function Spot(T)
		-- Close up (right after a snowball), a ring centred on the enemy puts shards between
		-- him and Tusk: at 10:00 it walled Tusk off and the enemy walked away. Centre it 300
		-- past the enemy, on the side away from Tusk, so the wall is behind the enemy instead.
		local dist = GetUnitToUnitDistance(b, T)
		if dist < 500 then
			local from, to = b:GetLocation(), T:GetLocation()
			local dx, dy = to.x - from.x, to.y - from.y
			local len = math.max(1, math.sqrt(dx * dx + dy * dy))
			return Vector(to.x + dx / len * 300, to.y + dy / len * 300, to.z)
		end
		if c.IsDisabled(T) or T:GetCurrentMovementSpeed() <= 0 then
			return T:GetLocation()
		end
		return T:GetExtrapolatedLocation(dist / math.max(1, Q) + N + 0.2)
	end
	local function Trappable(T)
		return c.IsValidHero(T)
			and c.IsInRange(b, T, M)
			and not c.IsSuspiciousIllusion(T)
			and not T:HasModifier("modifier_enigma_black_hole_pull")
			and not T:HasModifier("modifier_faceless_void_chronosphere_freeze")
			and not T:HasModifier("modifier_legion_commander_duel")
			and not T:HasModifier("modifier_necrolyte_reapers_scythe")
	end
	local R = c.GetNearbyHeroes(b, M, true, BOT_MODE_NONE)
	for S, T in pairs(R) do
		if
			c.IsValidHero(T)
			and c.CanCastOnNonMagicImmune(T)
			and c.IsInRange(b, T, M)
			and c.CanKillTarget(T, P, DAMAGE_TYPE_MAGICAL)
			and not c.IsSuspiciousIllusion(T)
			and not T:HasModifier("modifier_abaddon_borrowed_time")
			and not T:HasModifier("modifier_dazzle_shallow_grave")
			and not T:HasModifier("modifier_necrolyte_reapers_scythe")
			and not T:HasModifier("modifier_oracle_false_promise_timer")
			and not T:HasModifier("modifier_templar_assassin_refraction_absorb")
		then
			a.LogShards("kill", T)
			return BOT_ACTION_DESIRE_HIGH, Spot(T)
		end
	end
	if c.IsInTeamFight(b, 1200) then
		local V = b:FindAoELocation(true, true, b:GetLocation(), M, O, 0, 0)
		local W = c.GetEnemiesNearLoc(V.targetloc, O)
		if
			W ~= nil
			and #W >= 2
			and not c.IsLocationInChrono(V.targetloc)
			and not c.IsLocationInBlackHole(V.targetloc)
		then
			a.LogShards("fight", W[1])
			return BOT_ACTION_DESIRE_HIGH, V.targetloc
		end
	end
	-- Going in on his target: trap it whether he is chasing, walking up, or it is disabled.
	if I and c.IsValidTarget(H) and c.CanCastOnMagicImmune(H) and Trappable(H) then
		local X = c.GetNearbyHeroes(H, 1200, true, BOT_MODE_NONE)
		local W = c.GetNearbyHeroes(H, 1200, false, BOT_MODE_NONE)
		if X ~= nil and W ~= nil and #X >= #W then
			a.LogShards("engage", H)
			return BOT_ACTION_DESIRE_HIGH, Spot(H)
		end
	end
	-- An ally is already hitting a hurt enemy hero: trap it so it cannot walk out.
	for S, T in pairs(R) do
		if Trappable(T) and c.GetHP(T) < 0.6 then
			local ours = c.GetNearbyHeroes(T, 1200, true, BOT_MODE_NONE)
			local theirs = c.GetNearbyHeroes(T, 1200, false, BOT_MODE_NONE)
			if ours ~= nil and theirs ~= nil and #ours >= #theirs then
				for Z, ally in pairs(c.GetNearbyHeroes(T, 700, true, BOT_MODE_NONE)) do
					if ally ~= b and c.IsValidHero(ally) and not ally:IsIllusion() and ally:GetAttackTarget() == T then
						a.LogShards("gank", T)
						return BOT_ACTION_DESIRE_HIGH, Spot(T)
					end
				end
			end
		end
	end
	local wave = a.WaveToClear(o, 900, 3, 0.45)
	if wave ~= nil then
		a.LogWaveClear("shards", wave)
		return BOT_ACTION_DESIRE_HIGH, c.GetCenterOfUnits(wave)
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
-- [OHA-TUSK] shards why=kill|fight|engage|gank, at most once per 3s.
function a.LogShards(why, target)
	if DotaTime() < (b._tuskShardsLogAt or -999) then
		return
	end
	b._tuskShardsLogAt = DotaTime() + 3
	pcall(print, string.format(
		"[OHA-TUSK] t=%.0f shards why=%s target=%s hp=%.2f dist=%d",
		DotaTime(),
		why,
		target and (string.gsub(target:GetUnitName(), "npc_dota_hero_", "")) or "-",
		target and c.GetHP(target) or 0,
		target and math.floor(GetUnitToUnitDistance(b, target)) or 0
	))
end
-- Enemy lane creeps worth a spell, or nil. No enemy hero in sight, mana left after the cast,
-- and not taking a core's farm. Laning phase only to save a tower, so the lane is not pushed.
function a.WaveToClear(ability, range, minCreeps, manaAfter)
	if J or I or c.GetManaAfter(ability:GetManaCost()) < manaAfter then
		return nil
	end
	local defending = c.IsDefending(b)
	if c.IsInLaningPhase() and not defending then
		return nil
	end
	if not defending and c.IsThereNonSelfCoreNearby(1200) then
		return nil
	end
	local foes = c.GetNearbyHeroes(b, 1600, true, BOT_MODE_NONE)
	if foes ~= nil and #foes >= 1 then
		return nil
	end
	local creeps = b:GetNearbyLaneCreeps(range, true)
	if creeps == nil or #creeps < minCreeps then
		return nil
	end
	return creeps
end
-- [OHA-TUSK] wave-shards / wave-snowball, at most once per 10s per kind.
function a.LogWaveClear(kind, creeps)
	b._tuskWaveLogAt = b._tuskWaveLogAt or {}
	if DotaTime() < (b._tuskWaveLogAt[kind] or -999) then
		return
	end
	b._tuskWaveLogAt[kind] = DotaTime() + 10
	pcall(print, string.format(
		"[OHA-TUSK] t=%.0f wave-%s creeps=%d mp=%.2f mode=%d",
		DotaTime(),
		kind,
		#creeps,
		c.GetMP(b),
		b:GetActiveMode()
	))
end
function a.ConsiderDrinkingBuddies()
	-- Not castable while rooted since 7.41c.
	if not c.CanCastAbility(u) or b:IsRooted() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local M = c.GetProperCastRange(false, b, u:GetCastRange())
	local Z = c.GetAlliesNearLoc(b:GetLocation(), M)
	local _ = nil
	local a0 = 0
	for S, a1 in pairs(Z) do
		if a1 ~= b and c.IsValidHero(a1) and not a1:IsIllusion() then
			if c.IsStuck(b) or c.IsStuck(a1) then
				return BOT_ACTION_DESIRE_HIGH, a1
			end
			if c.IsDoingRoshan(b) then
				if c.IsRoshan(H) and c.CanBeAttacked(H) and c.IsInRange(b, H, 500) and K then
					return BOT_ACTION_DESIRE_HIGH, a1
				end
			end
			if c.IsDoingTormentor(b) then
				if c.IsTormentor(H) and c.IsInRange(b, H, 500) and K then
					return BOT_ACTION_DESIRE_HIGH, a1
				end
			end
			if
				not c.IsDisabled(a1)
				and not c.IsWithoutTarget(a1)
				and not a1:HasModifier("modifier_necrolyte_reapers_scythe")
				and not a1:HasModifier("modifier_skeleton_king_reincarnation_scepter_active")
			then
				local P = a1:GetAttackDamage() * a1:GetAttackSpeed()
				if P > a0 then
					_ = a1
					a0 = P
				end
			end
		end
	end
	if I and _ ~= nil then
		if
			c.IsValidTarget(H)
			and c.IsInRange(b, H, 1000)
			and c.CanBeAttacked(H)
			and not c.IsSuspiciousIllusion(H)
			and not H:HasModifier("modifier_necrolyte_reapers_scythe")
			and not H:HasModifier("modifier_templar_assassin_refraction_absorb")
		then
			local a2 = c.IsChasingTarget(b, H)
			local a3 = c.IsChasingTarget(_, H)
			local a4 = GetUnitToUnitDistance(b, H)
			local a5 = GetUnitToUnitDistance(_, H)
			if not a2 or a2 and a3 and a5 < a4 and a5 < 500 then
				return BOT_ACTION_DESIRE_HIGH, _
			end
		end
	end
	local R = b:GetNearbyHeroes(1600, false, BOT_MODE_NONE)
	if J and not c.IsRealInvisible(b) and not b:HasModifier("modifier_fountain_aura_buff") and #Z > 1 then
		for S, T in pairs(R) do
			if c.IsValidHero(T) and c.IsInRange(b, T, 800) and c.IsChasingTarget(T, b) then
				if b:WasRecentlyDamagedByAnyHero(3.0) and not c.IsSuspiciousIllusion(T) or #Z + 2 <= #R then
					for S, a1 in pairs(Z) do
						if
							a1 ~= b
							and c.IsValidHero(a1)
							and not a1:IsIllusion()
							and c.IsRetreating(a1)
							and GetUnitToUnitDistance(a1, T) > GetUnitToUnitDistance(b, T)
							and GetUnitToLocationDistance(T, (b:GetLocation() + a1:GetLocation()) / 2) > 500
						then
							return BOT_ACTION_DESIRE_HIGH, a1
						end
					end
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function a.ConsiderSnowball()
	if not p:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local M = c.GetProperCastRange(false, b, p:GetCastRange())
	local a6 = p:GetSpecialValueFloat("snowball_duration")
	if I then
		local a7 = nil
		local a8 = 0
		local W = c.GetNearbyHeroes(b, M, true, BOT_MODE_NONE)
		for S, T in pairs(W) do
			if
				c.IsValidHero(T)
				and c.CanCastOnNonMagicImmune(T)
				and not c.IsSuspiciousIllusion(T)
				and not T:HasModifier("modifier_enigma_black_hole_pull")
				and not T:HasModifier("modifier_faceless_void_chronosphere_freeze")
				and not T:HasModifier("modifier_legion_commander_duel")
				and not T:HasModifier("modifier_necrolyte_reapers_scythe")
			then
				local a9 = T:GetEstimatedDamageToTarget(false, b, a6, DAMAGE_TYPE_ALL)
				if a9 > a8 then
					a8 = a9
					a7 = T
				end
			end
		end
		if a7 ~= nil then
			local X = c.GetNearbyHeroes(a7, 1200, true, BOT_MODE_NONE)
			W = c.GetNearbyHeroes(a7, 1200, false, BOT_MODE_NONE)
			if X ~= nil and W ~= nil and #X >= #W then
				return BOT_ACTION_DESIRE_HIGH, a7
			end
		end
	end
	if J then
		local X = c.GetNearbyHeroes(b, 1200, false, BOT_MODE_NONE)
		local W = c.GetNearbyHeroes(b, 1200, true, BOT_MODE_NONE)
		local aa = nil
		local ab = 0
		-- Escape: outnumbered, low, or a ready blink locked by recent hero damage. The
		-- snowball holds him out of reach while the 3s blink lock runs out.
		local outnumbered = X ~= nil and W ~= nil and #W > #X
		local low = c.GetHP(b) < 0.5
		local blinkLocked = a.BlinkLockedByDamage()
		if W ~= nil and #W >= 1 and (outnumbered or low or blinkLocked) then
			for S, T in pairs(W) do
				if
					c.IsValidHero(T)
					and c.CanCastOnNonMagicImmune(T)
					and c.IsInRange(b, T, 600)
					and c.IsChasingTarget(T, b)
					and b:WasRecentlyDamagedByHero(T, 1.5)
					and not c.IsSuspiciousIllusion(T)
					and not c.IsDisabled(T)
				then
					local ac = b:GetNearbyCreeps(M, true)
					for S, ad in pairs(ac) do
						if
							c.IsValid(ad)
							and GetUnitToLocationDistance(ad, GetAncient(GetTeam()):GetLocation()) < GetUnitToLocationDistance(
								b,
								GetAncient(GetTeam()):GetLocation()
							)
							and GetUnitToUnitDistance(b, ad) > M / 2
							and GetUnitToUnitDistance(b, ad) > ab
						then
							-- Farthest enemy creep on the way home. The old test (ab > distance)
							-- started from 0 and never picked one.
							ab = GetUnitToUnitDistance(b, ad)
							aa = ad
						end
					end
				end
			end
			if aa ~= nil then
				b.snowballHeroRetreat = true
				b._snowballRetreatAt = DotaTime()
				a.LogEscapeSnowball(aa, outnumbered, low, blinkLocked, X, W)
				return BOT_ACTION_DESIRE_HIGH, aa
			end
			W = c.GetNearbyHeroes(b, M, true, BOT_MODE_NONE)
			for S, T in pairs(W) do
				if
					c.IsValidHero(T)
					and c.CanCastOnNonMagicImmune(T)
					and c.IsInRange(b, T, 600)
					and c.IsChasingTarget(T, b)
					and b:WasRecentlyDamagedByHero(T, 1.5)
					and not c.IsSuspiciousIllusion(T)
					and not c.IsDisabled(T)
					and not T:HasModifier("modifier_enigma_black_hole_pull")
					and not T:HasModifier("modifier_faceless_void_chronosphere_freeze")
					and not T:HasModifier("modifier_legion_commander_duel")
					and not T:HasModifier("modifier_necrolyte_reapers_scythe")
				then
					b.snowballHeroRetreat = true
					b._snowballRetreatAt = DotaTime()
					a.LogEscapeSnowball(T, outnumbered, low, blinkLocked, X, W)
					return BOT_ACTION_DESIRE_HIGH, T
				end
			end
		end
	end
	if c.IsDoingRoshan(b) then
		if c.IsRoshan(H) and c.CanCastOnNonMagicImmune(H) and c.IsInRange(b, H, 500) and K then
			return BOT_ACTION_DESIRE_HIGH, H
		end
	end
	if c.IsDoingTormentor(b) then
		if c.IsTormentor(H) and c.IsInRange(b, H, 500) and K then
			return BOT_ACTION_DESIRE_HIGH, H
		end
	end
	-- Wave clear on high mana only: the snowball is his gank and save, so keep mana for Shards
	-- and the next fight. Aim at the farthest creep so the roll crosses the whole wave, and
	-- never roll under an enemy tower.
	local wave = a.WaveToClear(p, 900, 4, 0.6)
	if wave ~= nil then
		local far, farDist = nil, 0
		for S, cr in pairs(wave) do
			if c.IsValid(cr) then
				local dist = GetUnitToUnitDistance(b, cr)
				if dist > farDist and #(cr:GetNearbyTowers(800, false) or {}) == 0 then
					far, farDist = cr, dist
				end
			end
		end
		if far ~= nil then
			a.LogWaveClear("snowball", wave)
			return BOT_ACTION_DESIRE_HIGH, far
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
local BLINKS = { "item_blink", "item_overwhelming_blink", "item_swift_blink", "item_arcane_blink" }
-- Blink is off cooldown but cannot be used: a hero hit him within the last 3 seconds.
function a.BlinkLockedByDamage()
	if not b:WasRecentlyDamagedByAnyHero(3.0) then
		return false
	end
	for _, name in ipairs(BLINKS) do
		local slot = b:FindItemSlot(name)
		if slot >= 0 and slot <= 5 then
			local item = b:GetItemInSlot(slot)
			if item ~= nil and item:GetCooldownTimeRemaining() <= 0 then
				return true
			end
		end
	end
	return false
end
-- [OHA-TUSK]: every escape snowball, with what triggered it.
function a.LogEscapeSnowball(target, outnumbered, low, blinkLocked, allies, enemies)
	local name = target:IsHero() and (string.gsub(target:GetUnitName(), "npc_dota_hero_", "")) or "creep"
	pcall(print, string.format(
		"[OHA-TUSK] t=%.0f escape-snowball target=%s hp=%.2f allies=%d enemies=%d outnumbered=%s low=%s blinkLocked=%s",
		DotaTime(),
		name,
		c.GetHP(b),
		allies and #allies or 0,
		enemies and #enemies or 0,
		tostring(outnumbered),
		tostring(low),
		tostring(blinkLocked)
	))
end
function a.ConsiderLaunchSnowball()
	if q:IsHidden() or not q:IsFullyCastable() or b.snowballHeroRetreat then
		return BOT_ACTION_DESIRE_NONE
	end
	return BOT_ACTION_DESIRE_HIGH
end
function a.ConsiderTagTeam()
	if not c.CanCastAbility(r) then
		return BOT_ACTION_DESIRE_NONE
	end
	local O = r:GetSpecialValueInt("radius")
	if c.IsInTeamFight(b, 1200) then
		local W = c.GetEnemiesNearLoc(b:GetLocation(), O)
		if W ~= nil and #W >= 2 then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if I then
		-- A stunned target is the best time for it: Tag Team adds bonus damage to every
		-- attack on enemies in the aura, Walrus Punch included. The old "not disabled" test
		-- skipped it right after Snowball landed, so Tusk went straight to the ult.
		if
			c.IsValidTarget(H)
			and c.IsInRange(b, H, O)
			and not c.IsSuspiciousIllusion(H)
			and not H:HasModifier("modifier_dazzle_shallow_grave")
			and not H:HasModifier("modifier_legion_commander_duel")
			and not H:HasModifier("modifier_necrolyte_reapers_scythe")
			and not H:HasModifier("modifier_templar_assassin_refraction_absorb")
		then
			local X = c.GetNearbyHeroes(H, 1200, true, BOT_MODE_NONE)
			local W = c.GetNearbyHeroes(H, 1200, false, BOT_MODE_NONE)
			local numbers = X ~= nil and W ~= nil and #X >= #W
			-- Going in with Walrus Punch anyway: open with Tag Team regardless of numbers.
			local punchReady = t ~= nil and t:IsTrained() and t:IsFullyCastable()
			if numbers or punchReady or c.IsDisabled(H) then
				pcall(print, string.format(
					"[OHA-TUSK] t=%.0f tag-team target=%s disabled=%s punchReady=%s numbers=%s",
					DotaTime(),
					(string.gsub(H:GetUnitName(), "npc_dota_hero_", "")),
					tostring(c.IsDisabled(H)),
					tostring(punchReady),
					tostring(numbers)
				))
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	if c.IsDoingRoshan(b) then
		local X = c.GetNearbyHeroes(b, 600, false, BOT_MODE_NONE)
		if
			c.IsRoshan(H)
			and c.IsInRange(b, H, 500)
			and K
			and X ~= nil
			and #X >= 2
			and c.IsAttacking(X[1])
			and c.IsAttacking(X[2])
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if c.IsDoingTormentor(b) then
		if c.IsTormentor(H) and c.IsInRange(b, H, 500) and K then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
-- "cast" when Tag Team should go out ahead of a Walrus Punch on `target`, or why not.
function a.TagTeamBeforePunch(target)
	if r == nil or r:IsNull() or not r:IsTrained() then
		return "untrained"
	end
	if r:GetCooldownTimeRemaining() > 0 then
		return "cooldown"
	end
	if b:GetMana() < r:GetManaCost() + t:GetManaCost() then
		return "mana"
	end
	local radius = r:GetSpecialValueInt("radius")
	if radius == nil or radius < 100 then
		radius = 350
	end
	if target == nil or GetUnitToUnitDistance(b, target) > radius then
		return "range"
	end
	if not c.CanCastAbility(r) then
		return "blocked"
	end
	return "cast"
end
function a.ConsiderWalrusKick()
	-- Walrus Kick comes from Aghanim's Scepter. Before that it is hidden but can still read castable.
	if not c.CanCastAbility(s) then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local M = c.GetProperCastRange(false, b, s:GetCastRange())
	if J and not c.IsRealInvisible(b) then
		for S, T in pairs(c.GetNearbyHeroes(b, M, true, BOT_MODE_NONE)) do
			if
				c.IsValidHero(T)
				and c.CanCastOnNonMagicImmune(T)
				and c.IsInRange(b, T, M)
				and c.IsChasingTarget(T, b)
				and not c.IsSuspiciousIllusion(T)
				and not c.IsDisabled(T)
				and not T:HasModifier("modifier_enigma_black_hole_pull")
				and not T:HasModifier("modifier_faceless_void_chronosphere_freeze")
				and not T:HasModifier("modifier_legion_commander_duel")
				and not T:HasModifier("modifier_necrolyte_reapers_scythe")
			then
				return BOT_ACTION_DESIRE_HIGH, T
			end
		end
	end
	if I then
		local X = c.GetNearbyHeroes(b, 1200, false, BOT_MODE_NONE)
		for S, T in pairs(c.GetNearbyHeroes(b, M, true, BOT_MODE_NONE)) do
			if
				c.IsValidHero(T)
				and c.CanCastOnNonMagicImmune(T)
				and c.IsInRange(b, T, M)
				and not c.IsSuspiciousIllusion(T)
				and not T:HasModifier("modifier_abaddon_borrowed_time")
				and not T:HasModifier("modifier_enigma_black_hole_pull")
				and not T:HasModifier("modifier_faceless_void_chronosphere_freeze")
				and not T:HasModifier("modifier_legion_commander_duel")
				and not T:HasModifier("modifier_necrolyte_reapers_scythe")
			then
				if X ~= nil and #X >= 2 and T ~= H and c.IsInRange(T, X[1], 600) then
					return BOT_ACTION_DESIRE_HIGH, T
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function a.ConsiderWalrusPunch()
	if not t:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local M = c.GetProperCastRange(false, b, t:GetCastRange())
	if I then
		local a7 = nil
		local a8 = 0
		local W = c.GetNearbyHeroes(b, M, true, BOT_MODE_NONE)
		for S, T in pairs(W) do
			if
				c.IsValidHero(T)
				and c.CanCastOnMagicImmune(T)
				and not c.IsSuspiciousIllusion(T)
				and not T:HasModifier("modifier_abaddon_borrowed_time")
				and not T:HasModifier("modifier_dazzle_shallow_grave")
				and not T:HasModifier("modifier_enigma_black_hole_pull")
				and not T:HasModifier("modifier_faceless_void_chronosphere_freeze")
				and not T:HasModifier("modifier_legion_commander_duel")
				and not T:HasModifier("modifier_necrolyte_reapers_scythe")
				and not T:HasModifier("modifier_oracle_false_promise_timer")
				and not T:HasModifier("modifier_templar_assassin_refraction_absorb")
			then
				local a9 = T:GetEstimatedDamageToTarget(false, b, 4, DAMAGE_TYPE_ALL)
				if a9 > a8 then
					a8 = a9
					a7 = T
				end
			end
		end
		if a7 ~= nil then
			return BOT_ACTION_DESIRE_HIGH, a7
		end
	end
	if c.IsDoingRoshan(b) then
		local X = c.GetNearbyHeroes(b, 600, false, BOT_MODE_NONE)
		if
			c.IsRoshan(H)
			and c.CanCastOnNonMagicImmune(H)
			and c.IsInRange(b, H, 500)
			and K
			and X ~= nil
			and #X >= 2
			and c.IsAttacking(X[1])
			and c.IsAttacking(X[2])
		then
			return BOT_ACTION_DESIRE_HIGH, H
		end
	end
	if c.IsDoingTormentor(b) then
		if c.IsTormentor(H) and c.IsInRange(b, H, 500) and K then
			return BOT_ACTION_DESIRE_HIGH, H
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
return a
