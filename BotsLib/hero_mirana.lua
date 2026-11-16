-- [OHA-MIRANA] logs off: the behaviour they traced works (game 029).
local print = function() end
-- Mirana: skill build, item build, and ability use for this hero.
local a = {}
local b = GetBot()
local c = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local ChargeTracker = require(GetScriptDirectory() .. "/FuncLib/systems/charge_tracker")
local d = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local e = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local f = c.Skill.GetTalentList(b)
local g = c.Skill.GetAbilityList(b)
local h = c.Item.GetRoleItemsBuyList(b)
local i = { ["t25"] = { 10, 0 }, ["t20"] = { 10, 0 }, ["t15"] = { 10, 0 }, ["t10"] = { 10, 0 } }
local j = { { 1, 3, 1, 2, 1, 6, 1, 3, 3, 3, 6, 2, 2, 2, 6 } }
local k = c.Skill.GetRandomBuild(j)
local l = c.Skill.GetTalentBuild(i)
local m = {}
m["pos_1"] = {
	"item_ranged_carry_outfit",
	"item_dragon_lance",
	"item_maelstrom",
	"item_aghanims_shard",
	"item_mjollnir",
	"item_travel_boots",
	"item_orchid",
	"item_bloodthorn",
	"item_force_staff",
	"item_hurricane_pike",
	"item_ultimate_scepter",
	"item_moon_shard",
	"item_travel_boots_2",
	"item_ultimate_scepter_2",
	"item_butterfly",
}
m["pos_2"] = m["pos_1"]
m["pos_4"] = {
	"item_priest_outfit",
	"item_rod_of_atos",
	"item_aghanims_shard",
	"item_ultimate_scepter",
	"item_mekansm",
	"item_guardian_greaves",
	"item_glimmer_cape",
	"item_spirit_vessel",
	"item_shivas_guard",
	"item_moon_shard",
	"item_ultimate_scepter_2",
	"item_sheepstick",
}
m["pos_5"] = {
	"item_blood_grenade",
	"item_crystal_maiden_outfit",
	"item_rod_of_atos",
	"item_aghanims_shard",
	"item_ultimate_scepter",
	"item_ancient_janggo",
	"item_boots_of_bearing",
	"item_pipe",
	"item_glimmer_cape",
	"item_cyclone",
	"item_shivas_guard",
	"item_sheepstick",
	"item_moon_shard",
	"item_ultimate_scepter_2",
}
m["pos_3"] = m["pos_1"]
a["sBuyList"] = m[h]
a["sSellList"] = { "item_maelstrom", "item_quelling_blade" }
if c.Role.IsPvNMode() or c.Role.IsAllShadow() then
	a["sBuyList"], a["sSellList"] = { "PvN_ranged_carry" }, {}
end
k, l, a["sBuyList"], a["sSellList"] = c.SetUserHeroInit(k, l, a["sBuyList"], a["sSellList"])
a["sSkillList"] = c.Skill.GetSkillList(g, k, f, l)
a["bDeafaultAbility"] = false
a["bDeafaultItem"] = false
function a.MinionThink(n)
	if e.IsValidUnit(n) then
		e.IllusionThink(n)
	end
end
local o = SafeAbility(b:GetAbilityByName(g[1]), "sAbilityList[1]", "mirana")
local p = SafeAbility(b:GetAbilityByName(g[2]), "sAbilityList[2]", "mirana")
local q = SafeAbility(b:GetAbilityByName(g[3]), "sAbilityList[3]", "mirana")
local r = SafeAbility(b:GetAbilityByName(g[6]), "sAbilityList[6]", "mirana")
local s = SafeAbility(b:GetAbilityByName("mirana_celestial_quiver"), "mirana_celestial_quiver", "mirana")
local t, u
local v, w
local x, y
local z, A
local B, C
local D = 0
local E, F, G, H, I, J
function a.SkillsComplement()
	if c.CanNotUseAbility(b) then
		return
	end
	local K = d.Build(b)
	F = 400
	D = K.aetherRange
	E = K.level
	G = K.mp
	H = K.hp
	botTarget = K.target
	I = K.enemies
	J = K.allies
	t, u = a.ConsiderQ()
	if t > 0 then
		c.SetQueuePtToINT(b, true)
		b:ActionQueue_UseAbility(o)
		return
	end
	a._heldArrow = false
	v, w = a.ConsiderW()
	if v > 0 then
		c.SetQueuePtToINT(b, true)
		b:ActionQueue_UseAbilityOnLocation(p, w)
		return
	end
	if a._heldArrow then
		return
	end
	local leapWhy
	x, y, leapWhy = a.ConsiderE()
	if x > 0 and leapWhy == "turn" then
		b:Action_MoveToLocation(y)
		return
	end
	if x > 0 then
		pcall(ChargeTracker.Issued, b, q)
		pcall(print, string.format(
			"[OHA-MIRANA] t=%.0f leap-cast charges=%s",
			DotaTime(),
			tostring(ChargeTracker.Count(b, q))
		))
		c.SetQueuePtToINT(b, false)
		b:ActionQueue_UseAbility(q)
		return
	end
	z, A = a.ConsiderR()
	if z > 0 then
		c.SetQueuePtToINT(b, true)
		b:ActionQueue_UseAbility(r)
		return
	end
	B, C = a.ConsiderCelestialQuiver()
	if B > 0 then
		b:Action_UseAbilityOnEntity(s, C)
		return
	end
end
function a.ConsiderQ()
	if not o:IsFullyCastable() then
		return 0
	end
	local L = o:GetLevel()
	local M = o:GetSpecialValueInt("starfall_radius")
	local N = o:GetSpecialValueInt("starfall_secondary_radius")
	local O = o:GetCastPoint()
	local P = o:GetManaCost()
	local Q = o:GetAbilityDamage()
	local R = DAMAGE_TYPE_MAGICAL
	local S = c.GetAroundEnemyHeroList(N)
	local T = c.GetAroundEnemyHeroList(M)
	local U = nil
	local V = nil
	for W, X in pairs(T) do
		if c.IsValid(X) and c.CanCastOnNonMagicImmune(X) and c.WillMagicKillTarget(b, X, Q, O) then
			U = X
			V = "Q-击杀:" .. c.Chat.GetNormName(U)
			return BOT_ACTION_DESIRE_HIGH, U, V
		end
	end
	if c.IsGoingOnSomeone(b) then
		if
			c.IsValidHero(botTarget)
			and c.IsInRange(b, botTarget, M)
			and c.CanCastOnNonMagicImmune(botTarget)
			and (#S >= 1 or #T >= 2 or H < 0.4)
		then
			U = botTarget
			V = "Q-攻击:" .. c.Chat.GetNormName(U)
			return BOT_ACTION_DESIRE_HIGH, U, V
		end
	end
	if c.IsRetreating(b) and b:WasRecentlyDamagedByAnyHero(3.0) and (#S >= 1 or H < 0.6) then
		for W, X in pairs(T) do
			if c.IsValid(X) and c.CanCastOnNonMagicImmune(X) then
				U = X
				V = "Q-撤退" .. c.Chat.GetNormName(U)
				return BOT_ACTION_DESIRE_HIGH, U, V
			end
		end
	end
	if b:GetActiveMode() == BOT_MODE_LANING or E <= 7 and #J <= 2 then
		local Y = 0
		local Z = 0
		local _ = b:GetNearbyLaneCreeps(M, true)
		for W, creep in pairs(_) do
			if
				c.IsValid(creep)
				and not creep:HasModifier("modifier_fountain_glyph")
				and not c.IsOtherAllysTarget(creep)
			then
				local a0 = Q
				if c.WillKillTarget(creep, a0, R, O + 0.57) then
					if c.IsKeyWordUnit("ranged", creep) then
						Z = Z + 1
					end
					if c.IsKeyWordUnit("melee", creep) then
						Y = Y + 1
					end
				end
			end
		end
		if Y + Z >= 3 then
			U = b
			V = "Q对线1"
			return BOT_ACTION_DESIRE_HIGH, U, V
		end
		if Z >= 1 and Y >= 1 then
			U = b
			V = "Q对线2"
			return BOT_ACTION_DESIRE_HIGH, U, V
		end
		if #_ == 0 and #S >= 1 and G > 0.5 then
			U = S[1]
			V = "Q对线消耗:" .. c.Chat.GetNormName(U)
			return BOT_ACTION_DESIRE_HIGH, U, V
		end
	end
	if
		(c.IsPushing(b) or c.IsDefending(b) or c.IsFarming(b))
		and c.IsAllowedToSpam(b, P * 0.32)
		and #J <= 3
		and #I == 0
	then
		local a1 = b:GetNearbyLaneCreeps(M - 50, true)
		if
			c.IsValid(a1[1])
			and not a1[1]:HasModifier("modifier_fountain_glyph")
			and (#a1 >= 5 or G > 0.88 and #a1 >= 4)
		then
			U = creep
			V = "Q-带线"
			return BOT_ACTION_DESIRE_HIGH, U, V
		end
	end
	if c.IsFarming(b) and DotaTime() > 8 * 60 and c.IsAllowedToSpam(b, P) then
		local a2 = b:GetNearbyNeutralCreeps(N)
		if #a2 >= 3 and c.IsValid(botTarget) and botTarget:GetMagicResist() < 0.51 then
			U = botTarget
			V = "Q-打野AOE" .. #a2
			return BOT_ACTION_DESIRE_HIGH, V
		end
	end
	if c.IsDoingTormentor(b) then
		if c.IsTormentor(botTarget) and c.IsInRange(botTarget, b, M) and c.IsAttacking(b) then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
-- [OHA-MIRANA] arrow-skip: an enemy hero is teleporting within arrow range and no arrow goes,
-- with the reason (cooldown, mana, untrained, blocked). At most every 5s.
function a.LogTeleportArrowSkip(why, target)
	if DotaTime() < (b._arrowSkipLogAt or -999) then
		return
	end
	b._arrowSkipLogAt = DotaTime() + 5
	pcall(print, string.format(
		"[OHA-MIRANA] t=%.0f arrow-skip why=%s target=%s dist=%d mp=%.2f",
		DotaTime(),
		why,
		(string.gsub(target:GetUnitName(), "npc_dota_hero_", "")),
		math.floor(GetUnitToUnitDistance(b, target)),
		b:GetMana() / math.max(1, b:GetMaxMana())
	))
end
function a.ConsiderW()
	if not p:IsFullyCastable() then
		for _, X in pairs(c.GetNearbyHeroes(b, 1600, true, BOT_MODE_NONE) or {}) do
			if c.IsValidHero(X) and X:HasModifier("modifier_teleporting") then
				local why = not p:IsTrained() and "untrained"
					or p:GetCooldownTimeRemaining() > 0 and "cooldown"
					or b:GetMana() < p:GetManaCost() and "mana"
					or "not-castable"
				a.LogTeleportArrowSkip(why, X)
				break
			end
		end
		return 0
	end
	local M = p:GetSpecialValueInt("arrow_range")
	if M == nil or M <= 0 then
		M = p:GetCastRange()
	end
	if M == nil or M <= 0 then
		M = 3000
	end
	M = M + D
	local N = p:GetSpecialValueInt("arrow_width")
	if N == nil or N <= 0 then
		N = 115
	end
	local a3 = p:GetSpecialValueInt("arrow_speed")
	if a3 == nil or a3 <= 0 then
		a3 = 900
	end
	local O = p:GetCastPoint()
	local P = p:GetManaCost()
	local minUseful = 350
	local a4 = c.GetNearbyHeroes(b, math.min(M, 3500), true, BOT_MODE_NONE)
	local U = nil

	local function arrowLoc(target)
		local dist = GetUnitToUnitDistance(b, target)
		local travel = O + dist / a3
		return c.GetCorrectLoc(target, travel)
	end

	local function clearShot(target, loc)
		if a.IsEnemyUnitBetweenArrow(b, target, loc, N) then
			return false
		end
		return true
	end

	-- Root first so the arrow cannot be dodged. Hold the shot until the root lands.
	local function releaseArrow(target, loc)
		if a.HoldArrowForAtos(target) then
			return 0
		end
		pcall(print, string.format(
			"[OHA-MIRANA] t=%.0f arrow target=%s dist=%d mode=%d",
			DotaTime(),
			(string.gsub(target:GetUnitName(), "npc_dota_hero_", "")),
			math.floor(GetUnitToUnitDistance(b, target)),
			b:GetActiveMode()
		))
		return BOT_ACTION_DESIRE_HIGH, loc
	end

	-- TP interrupt / already disabled: highest priority.
	for W, X in pairs(a4) do
		if
			c.IsValidHero(X)
			and c.IsInRange(b, X, M)
			and not c.IsInRange(b, X, 80)
			and c.CanCastOnNonMagicImmune(X)
			and not c.IsSuspiciousIllusion(X)
		then
			local loc = arrowLoc(X)
			if X:HasModifier("modifier_teleporting") and not clearShot(X, loc) then
				a.LogTeleportArrowSkip("blocked", X)
			end
			if clearShot(X, loc) then
				if X:HasModifier("modifier_teleporting") then
					return releaseArrow(X, loc)
				end
				if c.IsDisabled(X) and not c.IsInRange(b, X, minUseful) then
					return releaseArrow(X, loc)
				end
			end
		end
	end

	-- Engage: lead the target when the lane/path is clear. A fight while pushing or defending
	-- counts too: at 47:40 the post-kill push floor kept her in push mode and no arrow went.
	local nearHeroes = c.GetNearbyHeroes(b, 1600, true, BOT_MODE_NONE) or {}
	local fighting = c.IsGoingOnSomeone(b)
		or c.IsInTeamFight(b, 1200)
		or (c.IsPushing(b) or c.IsDefending(b)) and #nearHeroes >= 1
	if fighting then
		if
			c.IsValidHero(botTarget)
			and c.IsInRange(b, botTarget, M)
			and not c.IsInRange(b, botTarget, minUseful)
			and c.CanCastOnNonMagicImmune(botTarget)
			and not c.IsSuspiciousIllusion(botTarget)
			and not botTarget:HasModifier("modifier_abaddon_borrowed_time")
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
			and not botTarget:HasModifier("modifier_oracle_false_promise_timer")
		then
			local loc = arrowLoc(botTarget)
			if clearShot(botTarget, loc) then
				return releaseArrow(botTarget, loc)
			end
		end
		-- Secondary: any visible enemy with a clean long shot.
		for W, X in pairs(a4) do
			if
				c.IsValidHero(X)
				and c.IsInRange(b, X, M)
				and not c.IsInRange(b, X, minUseful)
				and c.CanCastOnNonMagicImmune(X)
				and not c.IsSuspiciousIllusion(X)
				and not X:HasModifier("modifier_abaddon_borrowed_time")
			then
				local loc = arrowLoc(X)
				if clearShot(X, loc) then
					return releaseArrow(X, loc)
				end
			end
		end
	end

	-- Free shot, in any mode: an enemy hero with a clear line (our own creeps never block; enemy
	-- and neutral units do). Game 014, 27:20-27:35: defending and retreating at full HP with
	-- enemies on our high ground, no arrow, because the rules above need a fight, a retreat
	-- under fire, or an enemy within 1600. Close enough to lead (1800), or standing / attacking /
	-- slow from further. Keeps 15% mana (30% in lane) unless defending or retreating.
	do
		-- In lane keep 30% mana for last-hit Starstorms and escape Leaps.
		local keepMana = (c.IsDefending(b) or c.IsRetreating(b)) and 0 or (c.IsLaning(b) and 0.3 or 0.15)
		if c.GetManaAfter(P) >= keepMana then
			local blocked = nil
			for W, X in pairs(a4) do
				if
					c.IsValidHero(X)
					and c.IsInRange(b, X, M)
					and not c.IsInRange(b, X, 600)
					and c.CanCastOnNonMagicImmune(X)
					and not c.IsSuspiciousIllusion(X)
					and not X:HasModifier("modifier_abaddon_borrowed_time")
					and not X:HasModifier("modifier_oracle_false_promise_timer")
				then
					local dist = GetUnitToUnitDistance(b, X)
					local easy = dist <= 1800
						or X:GetCurrentMovementSpeed() < 200
						or X:IsChanneling()
						or c.IsAttacking(X)
						or c.IsDisabled(X)
					if easy then
						local loc = arrowLoc(X)
						if clearShot(X, loc) then
							pcall(print, string.format(
								"[OHA-MIRANA] t=%.0f arrow-free target=%s dist=%d",
								DotaTime(),
								(string.gsub(X:GetUnitName(), "npc_dota_hero_", "")),
								dist
							))
							return releaseArrow(X, loc)
						end
						blocked = blocked or X
					end
				end
			end
			if blocked ~= nil and DotaTime() >= (b._arrowBlockedLogAt or -999) then
				b._arrowBlockedLogAt = DotaTime() + 5
				pcall(print, string.format(
					"[OHA-MIRANA] t=%.0f arrow-skip why=blocked target=%s dist=%d",
					DotaTime(),
					(string.gsub(blocked:GetUnitName(), "npc_dota_hero_", "")),
					GetUnitToUnitDistance(b, blocked)
				))
			end
		end
	end
	-- Retreat: stun chasing heroes.
	if c.IsRetreating(b) and b:WasRecentlyDamagedByAnyHero(3.0) then
		for W, X in pairs(a4) do
			if
				c.IsValidHero(X)
				and c.IsInRange(b, X, M)
				and not c.IsInRange(b, X, 200)
				and c.CanCastOnNonMagicImmune(X)
				and not c.IsSuspiciousIllusion(X)
				and (c.IsChasingTarget(X, b) or b:WasRecentlyDamagedByHero(X, 2.5))
			then
				local loc = arrowLoc(X)
				if clearShot(X, loc) then
					return releaseArrow(X, loc)
				end
			end
		end
	end

	-- Laning / mid-game poke when mana is fine and shot is clean.
	if (c.IsLaning(b) or E <= 12) and G > 0.45 and #J <= 3 then
		for W, X in pairs(a4) do
			if
				c.IsValidHero(X)
				and c.IsInRange(b, X, math.min(M, 2200))
				and not c.IsInRange(b, X, 500)
				and c.CanCastOnNonMagicImmune(X)
				and not c.IsSuspiciousIllusion(X)
				and not c.IsOtherAllyCanKillTarget(b, X)
			then
				local loc = arrowLoc(X)
				if clearShot(X, loc) then
					return releaseArrow(X, loc)
				end
			end
		end
	end

	-- The first non-ancient creep hit dies outright, lane or jungle, at any travel distance.
	-- Hero shots above already had priority. Ancient creeps are not instant-killed.
	local nearEnemy = c.GetNearbyHeroes(b, 1400, true, BOT_MODE_NONE)
	if
		not c.IsGoingOnSomeone(b)
		and not c.IsRetreating(b)
		and c.IsAllowedToSpam(b, P)
		and (nearEnemy == nil or #nearEnemy == 0)
	then
		local search = math.min(M, 1600)
		local function aimCreep(creep)
			if creep == nil or not c.IsValid(creep) or creep:IsHero() then
				return nil
			end
			if creep.IsAncientCreep ~= nil and creep:IsAncientCreep() then
				return nil
			end
			if not c.IsInRange(b, creep, M) or c.IsInRange(b, creep, 80) then
				return nil
			end
			if c.IsOtherAllysTarget(creep) then
				return nil
			end
			local loc = creep:GetLocation()
			if a.IsEnemyUnitBetweenArrow(b, creep, loc, N) then
				return nil
			end
			return loc
		end
		if c.IsLaning(b) or c.IsFarming(b) or c.IsPushing(b) or c.IsDefending(b) then
			local lane = b:GetNearbyLaneCreeps(search, true)
			local siege, ranged, fat
			for _, creep in pairs(lane or {}) do
				if c.IsValid(creep) and not creep:IsHero() then
					local far = not c.IsInRange(b, creep, b:GetAttackRange() + 80)
					if c.IsKeyWordUnit("siege", creep) then
						if siege == nil or creep:GetHealth() > siege:GetHealth() then
							siege = creep
						end
					elseif c.IsKeyWordUnit("ranged", creep) and far then
						if ranged == nil or creep:GetHealth() > ranged:GetHealth() then
							ranged = creep
						end
					elseif far and creep:GetHealth() >= 400 and (fat == nil or creep:GetHealth() > fat:GetHealth()) then
						fat = creep
					end
				end
			end
			local loc = aimCreep(siege)
			if loc == nil then
				loc = aimCreep(ranged)
			end
			if loc == nil then
				loc = aimCreep(fat)
			end
			if loc ~= nil then
				return BOT_ACTION_DESIRE_HIGH, loc
			end
		end
		if c.IsFarming(b) or c.IsPushing(b) or (not c.IsLaning(b) and DotaTime() > 3 * 60) then
			-- Arrow kills a non-ancient creep outright (Valve data), so spend it on a large camp,
			-- the biggest creep there. It went on small-camp creeps before.
			local neutrals = b:GetNearbyNeutralCreeps(search)
			local spawners = GetNeutralSpawners() or {}
			local function CampType(creep)
				local best, bestD = nil, 900
				for _, sp in pairs(spawners) do
					if sp.location ~= nil then
						local d = GetUnitToLocationDistance(creep, sp.location)
						if d < bestD then
							best, bestD = sp.type, d
						end
					end
				end
				return best
			end
			local best, bestHp = nil, 0
			for _, creep in pairs(neutrals or {}) do
				if
					c.IsValid(creep)
					and not creep:IsHero()
					and (creep.IsAncientCreep == nil or not creep:IsAncientCreep())
					and creep:GetMaxHealth() > bestHp
					and CampType(creep) == "large"
				then
					best = creep
					bestHp = creep:GetMaxHealth()
				end
			end
			-- Not on one an attack or two would finish anyway.
			if best ~= nil and bestHp >= 450 and best:GetHealth() >= 300 then
				local loc = aimCreep(best)
				if loc ~= nil then
					return BOT_ACTION_DESIRE_HIGH, loc
				end
			end
		end
	end
	if c.IsDoingRoshan(b) then
		if c.IsRoshan(botTarget) and c.IsInRange(b, botTarget, M) and not c.IsInRange(b, botTarget, 300) then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	if c.IsDoingTormentor(b) then
		if c.IsTormentor(botTarget) and c.IsInRange(botTarget, b, M) and c.IsAttacking(b) then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function a.HoldArrowForAtos(target)
	if not c.IsValidHero(target) or c.IsDisabled(target) or target:IsRooted() then
		return false
	end
	local slot = b:FindItemSlot("item_rod_of_atos")
	if slot < 0 or slot > 5 then
		return false
	end
	local item = b:GetItemInSlot(slot)
	if item == nil or item:IsNull() then
		return false
	end
	if not c.CanCastOnNonMagicImmune(target) or not c.CanCastOnTargetAdvanced(target) then
		return false
	end
	local range = 1100 + (D or 0)
	local castRange = item:GetCastRange()
	if type(castRange) == "number" and castRange > 200 then
		range = castRange + (D or 0)
	end
	if GetUnitToUnitDistance(b, target) > range then
		return false
	end
	if item:IsFullyCastable() then
		b:Action_UseAbilityOnEntity(item, target)
		a._heldArrow = true
		return true
	end
	local cd = item:GetCooldown()
	local remain = item:GetCooldownTimeRemaining()
	-- Atos was just thrown. Wait for the root instead of firing the arrow over it.
	if type(cd) == "number" and type(remain) == "number" and cd > 0 and remain > cd - 2.5 then
		a._heldArrow = true
		return true
	end
	return false
end
function a.LeapReady()
	if q == nil or q:IsNull() or q:IsHidden() or not q:IsTrained() or not q:IsActivated() then
		return false
	end
	if b:GetMana() < q:GetManaCost() then
		return false
	end
	-- Leap has 2 charges (Valve data, no Shard needed). Castable means a charge is left; the
	-- old Shard-only branch read GetCurrentCharges, which is documented for items only.
	return q:IsFullyCastable()
end
function a.ConsiderE()
	if not a.LeapReady() or b:IsRooted() then
		return 0
	end
	local L = q:GetLevel()
	local M = q:GetSpecialValueInt("leap_distance")
	local N = b:GetAttackRange()
	local O = q:GetCastPoint()
	local P = q:GetManaCost()
	local Q = 0
	local R = DAMAGE_TYPE_MAGICAL
	local S = c.GetAroundEnemyHeroList(800)
	local T = c.GetAroundEnemyHeroList(1200)
	local U = nil
	local V = nil
	-- Chase: Leap goes 650 the way she faces and gives attack/move speed for 5s (Valve data). It
	-- used to need the target 620-1380 away and facing within 6 degrees, so a target running
	-- just ahead never got leapt on (5:00, game 014). Now: where she lands is checked against
	-- where the target will be, and a fleeing target inside 620 counts too.
	local chaseWhy = nil
	if c.IsGoingOnSomeone(b) and c.IsValidHero(botTarget) and c.IsInRange(b, botTarget, M + N + 300) then
		local fleeing = not botTarget:IsFacingLocation(b:GetLocation(), 90)
		local dist = GetUnitToUnitDistance(b, botTarget)
		local face = b:GetFacing() * math.pi / 180
		local me = b:GetLocation()
		local land = Vector(me.x + math.cos(face) * M, me.y + math.sin(face) * M, me.z)
		local there = botTarget:GetExtrapolatedLocation(0.6)
		local landDist = math.sqrt((land.x - there.x) ^ 2 + (land.y - there.y) ^ 2)
		-- Game 031: one leap brought her next to the target, the next one carried her past him (650
		-- forward, wherever he is) and a third brought her back: two charges wasted. No chase leap
		-- with the target already in attack range, unless the landing is at least 150 closer than
		-- she is now, or within 3s of the last chase leap (its speed bonus lasts 5s).
		if botTarget:IsAttackImmune() or not c.CanCastOnMagicImmune(botTarget) then
			chaseWhy = "target-immune"
		elseif dist <= N + 50 then
			chaseWhy = "in-attack-range"
		elseif DotaTime() - (b._chaseLeapAt or -999) < 3 then
			chaseWhy = "recent-leap"
		elseif landDist > dist - 150 then
			chaseWhy = string.format("no-gain(%d->%d)", dist, landDist)
		elseif landDist > N - 80 then
			chaseWhy = string.format("lands-far(%d)", landDist)
		elseif dist < M - 30 and not fleeing then
			chaseWhy = "close-not-fleeing"
		end
		-- Logged again (the other Mirana lines stay off) while this rule is new.
		if chaseWhy ~= nil and DotaTime() >= (b._leapChaseLogAt or -999) then
			b._leapChaseLogAt = DotaTime() + 5
			pcall(_G.print, string.format(
				"[OHA-MIRANA] t=%.0f leap-skip why=chase-%s target=%s dist=%d",
				DotaTime(),
				chaseWhy,
				(string.gsub(botTarget:GetUnitName(), "npc_dota_hero_", "")),
				dist
			))
		end
	end
	if c.IsGoingOnSomeone(b) and chaseWhy == nil then
		if c.IsValidHero(botTarget) and c.IsInRange(b, botTarget, M + N + 300) then
			local a6 = c.GetNearbyHeroes(botTarget, 900, false, BOT_MODE_NONE)
			local a7 = c.GetNearbyHeroes(botTarget, 1300, true, BOT_MODE_NONE)
			local a8 = c.GetNumOfAliveHeroes(true)
			if
				a8 <= 2
				or #a6 <= 1
				or #a6 <= #a7
				or c.WillKillTarget(botTarget, b:GetAttackDamage() * 3, DAMAGE_TYPE_PHYSICAL, 2.0)
			then
				U = botTarget
				V = "E-进攻:" .. c.Chat.GetNormName(U)
				b._chaseLeapAt = DotaTime()
				pcall(_G.print, string.format(
					"[OHA-MIRANA] t=%.0f leap why=chase target=%s dist=%d",
					DotaTime(),
					(string.gsub(botTarget:GetUnitName(), "npc_dota_hero_", "")),
					GetUnitToUnitDistance(b, botTarget)
				))
				return BOT_ACTION_DESIRE_HIGH, U, V
			end
		end
	end
	if c.IsStuck(b) then
		U = b
		V = "E-被卡住"
		return BOT_ACTION_DESIRE_HIGH, U, V
	end
	-- Escape. Also out of retreat mode when low and outnumbered: at 31:14 (game 014) she had both
	-- charges, 27% HP and three enemies on her, but was not in retreat mode, so no Leap.
	local lowAndOutnumbered = c.GetHP(b) < 0.4 and #T >= 2
	if (c.IsRetreating(b) or lowAndOutnumbered) and b:WasRecentlyDamagedByAnyHero(3.0) then
		local why = #S == 0 and "no-enemy-in-800" or "facing-enemy"
		-- Judge the landing spot (650 along her facing) against every enemy unit near her, illusions
		-- included: farther from the closest one, farther from their centre, and no more of them
		-- around it. It used to be enough to face away from one enemy: at 7:30 (game 016) she
		-- leapt out from Phantom Lancer, then 2s later "away from" one Lancer straight into the
		-- others.
		if #S > 0 then
			local foes = {}
			for W, X in pairs(GetUnitList(UNIT_LIST_ENEMY_HEROES) or {}) do
				if c.IsValid(X) and X:IsAlive() and GetUnitToUnitDistance(b, X) <= 1400 then
					foes[#foes + 1] = X
				end
			end
			local me = b:GetLocation()
			local face = b:GetFacing() * math.pi / 180
			local land = Vector(me.x + math.cos(face) * M, me.y + math.sin(face) * M, me.z)
			local function Closest(p0)
				local best = math.huge
				for _, X in ipairs(foes) do
					local q = X:GetLocation()
					best = math.min(best, math.sqrt((q.x - p0.x) ^ 2 + (q.y - p0.y) ^ 2))
				end
				return best
			end
			local function Around(p0)
				local n0 = 0
				for _, X in ipairs(foes) do
					local q = X:GetLocation()
					if (q.x - p0.x) ^ 2 + (q.y - p0.y) ^ 2 <= 600 * 600 then
						n0 = n0 + 1
					end
				end
				return n0
			end
			local center = c.GetCenterOfUnits(foes)
			local fromCenterNow = math.sqrt((me.x - center.x) ^ 2 + (me.y - center.y) ^ 2)
			local fromCenterLand = math.sqrt((land.x - center.x) ^ 2 + (land.y - center.y) ^ 2)
			if
				IsLocationPassable(land)
				and Closest(land) > Closest(me) + 200
				and fromCenterLand > fromCenterNow + 300
				and Around(land) <= Around(me)
			then
				U = S[1]
				V = "E-逃跑"
				pcall(print, string.format(
					"[OHA-MIRANA] t=%.0f leap why=escape foes=%d closest=%d->%d hp=%.2f",
					DotaTime(),
					#foes,
					math.floor(Closest(me)),
					math.floor(Closest(land)),
					c.GetHP(b)
				))
				return BOT_ACTION_DESIRE_HIGH, U, V
			end
		end
		-- Facing them while low: turn away first (Leap goes the way she faces); the next think
		-- leaps once she faces away.
		if why == "facing-enemy" and c.GetHP(b) < 0.4 then
			local center = c.GetCenterOfUnits(S)
			local me = b:GetLocation()
			local dx, dy = me.x - center.x, me.y - center.y
			local len = math.sqrt(dx * dx + dy * dy)
			if len < 1 then
				local fountain = GetTeam() == TEAM_RADIANT and Vector(-7172, -6652, 0) or Vector(6982, 6422, 0)
				dx, dy = fountain.x - me.x, fountain.y - me.y
				len = math.max(1, math.sqrt(dx * dx + dy * dy))
			end
			if DotaTime() >= (b._leapTurnLogAt or -999) then
				b._leapTurnLogAt = DotaTime() + 3
				pcall(print, string.format(
					"[OHA-MIRANA] t=%.0f leap-turn enemies800=%d hp=%.2f",
					DotaTime(),
					#S,
					c.GetHP(b)
				))
			end
			return BOT_ACTION_DESIRE_HIGH, Vector(me.x + dx / len * 300, me.y + dy / len * 300, me.z), "turn"
		end
		-- Retreating under fire without a Leap: say why (no enemy hero within 800, or not yet
		-- turned away; Leap goes the way she faces). At most every 5s.
		if DotaTime() >= (b._leapSkipLogAt or -999) then
			b._leapSkipLogAt = DotaTime() + 5
			pcall(print, string.format(
				"[OHA-MIRANA] t=%.0f leap-skip why=%s enemies1200=%d hp=%.2f",
				DotaTime(),
				why,
				#T,
				c.GetHP(b)
			))
		end
	end
	if c.IsFarming(b) and E >= 12 then
		if
			botTarget ~= nil
			and botTarget:IsAlive()
			and c.IsInRange(b, botTarget, M + N + 400)
			and not c.IsInRange(b, botTarget, 1080)
			and b:IsFacingLocation(botTarget:GetLocation(), 6)
		then
			U = botTarget:GetLocation()
			V = "E-打钱赶路"
			return BOT_ACTION_DESIRE_HIGH, U, V
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function a.ConsiderR()
	if not r:IsFullyCastable() then
		return 0
	end
	local L = r:GetLevel()
	local M = r:GetCastRange()
	local N = 600
	local O = r:GetCastPoint()
	local P = r:GetManaCost()
	local Q = r:GetSpecialValueInt("dam")
	local R = DAMAGE_TYPE_MAGICAL
	local S = c.GetAroundEnemyHeroList(M)
	local T = c.GetAroundEnemyHeroList(M + 200)
	local U = nil
	local V = nil
	for a9 = 1, #GetTeamPlayers(GetTeam()) do
		local aa = GetTeamMember(a9)
		if aa ~= nil and aa:IsAlive() and not aa:IsInvisible() then
			if c.IsGoingOnSomeone(aa) then
				local ab = c.GetProperTarget(aa)
				if c.IsValidHero(ab) and not c.IsInRange(aa, ab, 1600) and c.IsInRange(aa, ab, 2800) then
					local ac = c.GetAlliesNearLoc(aa:GetLocation(), 1000)
					if #ac >= 2 then
						U = aa
						V = "R-潜行准备进攻的队友:" .. c.Chat.GetNormName(U)
						return BOT_ACTION_DESIRE_HIGH, U, V
					end
				end
			end
			if c.IsRetreating(aa) then
				local a6 = c.GetNearbyHeroes(aa, 900, true, BOT_MODE_NONE)
				for W, X in pairs(a6) do
					if aa:WasRecentlyDamagedByHero(X, 3.0) then
						U = aa
						V = "R-隐身撤退的队友:" .. c.Chat.GetNormName(U)
						return BOT_ACTION_DESIRE_HIGH, U, V
					end
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function a.IsEnemyCreepBetweenEnemyHero(ad, ae, N)
	return a.IsEnemyUnitBetweenArrow(ad, ae, ae:GetLocation(), N)
end

-- Sacred Arrow only collides with enemy units (not allies).
function a.IsEnemyUnitBetweenArrow(caster, target, aimLoc, width)
	local origin = caster:GetLocation()
	local dest = aimLoc or target:GetLocation()
	local radius = (width or 115) + 25

	local function blocks(unit)
		if not c.IsValid(unit) or unit == target or unit == caster then
			return false
		end
		if unit:GetTeam() == caster:GetTeam() then
			return false
		end
		-- No IsBarracks / IsFort in the bot API ("attempt to call method IsBarracks", game 018);
		-- IsBuilding covers towers, barracks and the Ancient.
		if unit:IsBuilding() or unit:IsTower() then
			return false
		end
		local name = unit:GetUnitName()
		if string.find(name, "ward") or string.find(name, "tome") then
			return false
		end
		local hit = PointToLineDistance(origin, dest, unit:GetLocation())
		if hit ~= nil and hit.within and hit.distance <= radius + unit:GetBoundingRadius() then
			-- Only block if the blocker is closer than the intended target.
			if GetUnitToLocationDistance(caster, unit:GetLocation()) < GetUnitToLocationDistance(caster, dest) - 30 then
				return true
			end
		end
		return false
	end

	local creeps = caster:GetNearbyCreeps(1600, true)
	for _, creep in pairs(creeps) do
		if blocks(creep) then
			return true
		end
	end
	if target ~= nil and target.GetNearbyCreeps ~= nil then
		local nearTarget = target:GetNearbyCreeps(1200, false)
		if nearTarget then
			for _, creep in pairs(nearTarget) do
				if blocks(creep) then
					return true
				end
			end
		end
	end
	local enemies = c.GetNearbyHeroes(caster, 1600, true, BOT_MODE_NONE)
	for _, hero in pairs(enemies) do
		if blocks(hero) then
			return true
		end
	end
	return false
end
function a.ConsiderCelestialQuiver()
	if not c.CanCastAbility(s) or b:IsDisarmed() then
		return BOT_ACTION_DESIRE_NONE
	end
	local Q = s:GetSpecialValueInt("bonus_damage")
	local aj = s:GetAutoCastState()
	local ak = b:GetNearbyHeroes(b:GetAttackRange() + 300, true, BOT_MODE_NONE)
	for W, al in pairs(ak) do
		if
			c.IsValidHero(al)
			and c.CanBeAttacked(al)
			and c.IsInRange(b, al, b:GetAttackRange() + 150)
			and not c.IsSuspiciousIllusion(al)
			and not al:HasModifier("modifier_abaddon_borrowed_time")
			and not al:HasModifier("modifier_dazzle_shallow_grave")
			and not al:HasModifier("modifier_necrolyte_reapers_scythe")
			and not al:HasModifier("modifier_oracle_false_promise_timer")
			and not al:HasModifier("modifier_templar_assassin_refraction_absorb")
		then
			if
				c.WillKillTarget(al, b:GetAttackDamage() + Q, DAMAGE_TYPE_MAGICAL, b:GetAttackSpeed())
				and not c.WillKillTarget(al, b:GetAttackDamage(), DAMAGE_TYPE_PHYSICAL, b:GetAttackSpeed())
			then
				return BOT_ACTION_DESIRE_HIGH, al
			end
		end
	end
	local harass = false
	for W, al in pairs(ak) do
		if
			c.IsValidHero(al)
			and c.CanBeAttacked(al)
			and c.IsInRange(b, al, b:GetAttackRange() + 150)
			and not c.IsSuspiciousIllusion(al)
			and not al:HasModifier("modifier_abaddon_borrowed_time")
			and not al:HasModifier("modifier_dazzle_shallow_grave")
			and not al:HasModifier("modifier_necrolyte_reapers_scythe")
			and not al:HasModifier("modifier_oracle_false_promise_timer")
			and not al:HasModifier("modifier_templar_assassin_refraction_absorb")
		then
			harass = true
			break
		end
	end
	-- Mid game onward the orb stays on. Early, it stays on only while a hero is in attack range.
	if not c.IsEarlyGame() or (harass and G ~= nil and G > 0.35) then
		if not aj then
			s:ToggleAutoCast()
		end
		return BOT_ACTION_DESIRE_NONE
	end
	local am = b:GetNearbyCreeps(Min(b:GetAttackRange() + 300, 1600), true)
	if c.IsLaning(b) then
		for W, creep in pairs(am) do
			if
				c.IsValid(creep)
				and c.CanBeAttacked(creep)
				and c.IsKeyWordUnit("ranged", creep)
				and not c.CanKillTarget(creep, b:GetAttackDamage(), DAMAGE_TYPE_PHYSICAL)
			then
				local an = b:FindAoELocation(true, true, creep:GetLocation(), 0, 650, 0, 0)
				if c.WillKillTarget(creep, b:GetAttackDamage() + Q, DAMAGE_TYPE_MAGICAL, b:GetAttackSpeed()) then
					if an.count > 0 or c.IsUnitTargetedByTower(creep, false) or c.IsEnemyTargetUnit(creep, 1200) then
						return BOT_ACTION_DESIRE_HIGH, creep
					end
				end
			end
		end
	end
	if aj then
		s:ToggleAutoCast()
	end
	return BOT_ACTION_DESIRE_NONE
end
return a
