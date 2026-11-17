-- Techies: skill build, item build, and ability use for this hero.
local X = {}
local bot = GetBot()
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local ChargeTracker = require(GetScriptDirectory() .. "/FuncLib/systems/charge_tracker")
local AbilityContext = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local Minion = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local Techies = require(GetScriptDirectory() .. "/FuncLib/hero/techies")
local sTalentList = Fu.Skill.GetTalentList(bot)
local sAbilityList = Fu.Skill.GetAbilityList(bot)
local sRole = Fu.Item.GetRoleItemsBuyList(bot)
local tTalentTreeList = { ["t25"] = { 10, 0 }, ["t20"] = { 10, 0 }, ["t15"] = { 0, 10 }, ["t10"] = { 10, 0 } }
-- 1 Sticky Bomb, 2 Reactive Tazer, 3 Blast Off, 6 Proximity Mines (ultimate). Entries skip
-- talent levels (talent picks are unchanged); ultimate points stay at levels 6, 12 and 17.
-- One point in each at levels 1-3, then Sticky Bomb maxed first (level 7), Blast Off next
-- (level 11), Reactive Tazer last (level 16). Was Blast Off first, then Sticky Bomb.
local tAllAbilityBuildList = { { 1, 2, 3, 1, 1, 6, 1, 3, 3, 3, 6, 2, 2, 2, 6 } }
local nAbilityBuildList = Fu.Skill.GetRandomBuild(tAllAbilityBuildList)
local nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList)
local sRoleItemsBuyList = {}
sRoleItemsBuyList["pos_4"] = {
	-- Arcane Boots already cover mana, so this build keeps Magic Wand instead of Soul Ring.
	"item_double_tango",
	"item_double_branches",
	"item_blood_grenade",
	"item_boots",
	"item_magic_wand",
	"item_arcane_boots",
	"item_kaya",
	"item_aether_lens",
	-- Shard, then Aghanim's Scepter, then Guardian Greaves (user call).
	"item_aghanims_shard",
	"item_ultimate_scepter",
	"item_guardian_greaves",
	"item_force_staff",
	"item_lotus_orb",
	"item_octarine_core",
	"item_yasha_and_kaya",
	"item_sheepstick",
	"item_moon_shard",
	"item_ultimate_scepter_2",
}
sRoleItemsBuyList["pos_5"] = {
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
	"item_aether_lens",
	"item_pipe",
	"item_force_staff",
	"item_boots_of_bearing",
	"item_octarine_core",
	"item_yasha_and_kaya",
	"item_sheepstick",
	"item_aghanims_shard",
	"item_moon_shard",
	"item_ultimate_scepter_2",
}
sRoleItemsBuyList["pos_3"] = {
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
sRoleItemsBuyList["pos_1"] = {
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
sRoleItemsBuyList["pos_2"] = sRoleItemsBuyList["pos_1"]
X["sBuyList"] = sRoleItemsBuyList[sRole]
X["sSellList"] = { "item_black_king_bar", "item_quelling_blade" }
if Fu.Role.IsPvNMode() or Fu.Role.IsAllShadow() then
	X["sBuyList"], X["sSellList"] = { "PvN_antimage" }, {}
end
nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"] =
	Fu.SetUserHeroInit(nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"])
X["sSkillList"] = Fu.Skill.GetSkillList(sAbilityList, nAbilityBuildList, sTalentList, nTalentBuildList)
X["bDeafaultAbility"] = false
X["bDeafaultItem"] = false
function X.MinionThink(minion)
	Minion.MinionThink(minion)
end
local stickyBombAbility = SafeAbility(bot:GetAbilityByName("techies_sticky_bomb"), "techies_sticky_bomb", "techies")
local reactiveTazerAbility =
	SafeAbility(bot:GetAbilityByName("techies_reactive_tazer"), "techies_reactive_tazer", "techies")
local tazerStopAbility =
	SafeAbility(bot:GetAbilityByName("techies_reactive_tazer_stop"), "techies_reactive_tazer_stop", "techies")
local blastOffAbility = SafeAbility(bot:GetAbilityByName("techies_suicide"), "techies_suicide", "techies")
local minefieldSignAbility =
	SafeAbility(bot:GetAbilityByName("techies_minefield_sign"), "techies_minefield_sign", "techies")
local proximityMinesAbility = SafeAbility(bot:GetAbilityByName("techies_land_mines"), "techies_land_mines", "techies")
local mad = SafeAbility(
	bot:GetAbilityByName("techies_mutually_assured_destruction"),
	"techies_mutually_assured_destruction",
	"techies"
)
local madStop = SafeAbility(bot:GetAbilityByName("techies_focused_detonate"), "techies_focused_detonate", "techies")
local stickyBombDesire, stickyBombLocation
local tazerDesire, tazerTarget
local blastOffDesire, blastOffLocation, blastOffWhy
local minefieldSignDesire, minefieldSignLocation
local plantDesire, plantLocation
local botTarget, mineDamage, twoMinesDamage
local isEngaging
local isRetreating
local isAttacking
local hpRatio
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
		local ability = bot:GetAbilityInSlot(slot)
		if ability ~= nil and not ability:IsNull() then
			local name = ability:GetName()
			if
				string.find(name, "techies", 1, true)
				and (string.find(name, "mutually", 1, true) or string.find(name, "detonate", 1, true) or string.find(
					name,
					"barrel",
					1,
					true
				) or string.find(name, "_mad", 1, true))
				and not string.find(name, "sticky", 1, true)
			then
				list[#list + 1] = ability
			end
		end
	end
	return list
end
local function Behavior(ability)
	local ok, value = pcall(function()
		return ability:GetBehavior()
	end)
	return ok and value or 0
end
-- Logged whenever the set of M.A.D. abilities (and their castable/hidden state) changes, with or
-- without the Shard buff: game 017, Techies had the barrel unlocked but HasAghanimsShard (the
-- modifier_item_aghanims_shard buff) never let this run, so nothing was logged or planted.
local function LogMadCandidates(list)
	local sig = {}
	for _, ability in ipairs(list) do
		sig[#sig + 1] = ability:GetName() .. (ability:IsHidden() and "h" or "") .. (ability:IsTrained() and "t" or "")
	end
	local key = table.concat(sig, ",")
	if key == bot._madNamesLogged then
		return
	end
	bot._madNamesLogged = key
	local parts = {}
	for _, ability in ipairs(list) do
		local ok, passive = pcall(function()
			return ability:IsPassive()
		end)
		parts[#parts + 1] = string.format(
			"%s(beh=%s passive=%s hidden=%s castable=%s)",
			ability:GetName(),
			tostring(Behavior(ability)),
			tostring(ok and passive),
			tostring(ability:IsHidden()),
			tostring(ability:IsFullyCastable())
		)
	end
	pcall(print, string.format("[OHA-TECHIES] t=%.0f mad-abilities %s", DotaTime(), table.concat(parts, " ")))
end
-- The planted barrel is the unit npc_dota_techies_remote_mine (Liquipedia, M.A.D. page). Logged
-- when one of ours appears and when it is gone, to confirm a plant and a detonation in game.
function X.WatchBarrel()
	-- npc_dota_techies_remote_mine also matches his Sticky Bombs (game 018: 61 seen/gone pairs
	-- from 0:33, before the Shard). Only watch for 6s after a plant order.
	if bot._madPlantAt == nil or DotaTime() - bot._madPlantAt > 6 then
		return
	end
	local found = nil
	for _, unit in pairs(GetUnitList(UNIT_LIST_ALLIES) or {}) do
		if unit ~= nil and not unit:IsNull() and unit:GetUnitName() == "npc_dota_techies_remote_mine" then
			found = unit
			break
		end
	end
	if found ~= nil and not bot._barrelSeen then
		bot._barrelSeen = true
		local location = found:GetLocation()
		pcall(
			print,
			string.format("[OHA-TECHIES] t=%.0f mad-barrel seen at=%.0f,%.0f", DotaTime(), location.x, location.y)
		)
	elseif found == nil and bot._barrelSeen then
		bot._barrelSeen = false
		pcall(print, string.format("[OHA-TECHIES] t=%.0f mad-barrel gone", DotaTime()))
	end
end
-- The barrel plant ability, or nil (no Shard, or not found / not castable). Game 018 at 25:12
-- (Shard bought): techies_mutually_assured_destruction itself turned active (behavior 48 = point
-- + AoE, not passive, not hidden, castable). No IsTrained check: an innate has no skill points.
function X.MadPlant()
	local list = MadCandidates()
	for _, ability in ipairs(list) do
		local ok, passive = pcall(function()
			return ability:IsPassive()
		end)
		local behavior = Behavior(ability)
		local targeted = Fu.CheckBitfieldFlag(behavior, BEH_POINT) or Fu.CheckBitfieldFlag(behavior, BEH_AOE)
		if
			not (ok and passive)
			and not ability:IsHidden()
			and targeted
			and not string.find(ability:GetName(), "detonate", 1, true)
			and ability:IsFullyCastable()
		then
			return ability
		end
	end
	return nil
end
-- The detonate sub-ability (no target), or nil. A "detonate" name first, then any castable
-- no-target, non-passive M.A.D. ability (the plant is point targeted, so it never matches).
function X.MadDetonate()
	local fallback = nil
	for _, ability in ipairs(MadCandidates()) do
		-- Not hidden: techies_focused_detonate shows once a barrel is down (game 018: every
		-- mad-detonate came after a plant). Ordering it while hidden could cut the plant cast short.
		if not ability:IsHidden() and ability:IsFullyCastable() then
			local ok, passive = pcall(function()
				return ability:IsPassive()
			end)
			local behavior = Behavior(ability)
			local noTarget = Fu.CheckBitfieldFlag(behavior, BEH_NO_TARGET)
				and not Fu.CheckBitfieldFlag(behavior, BEH_POINT)
			if not (ok and passive) and noTarget then
				if string.find(ability:GetName(), "detonate", 1, true) then
					return ability
				end
				fallback = fallback or ability
			end
		end
	end
	return fallback
end
-- Plant M.A.D. and detonate it right away. The barrel counts as out only until the planned
-- detonate time + 2s: a plant that never landed (interrupted) used to block the next one for
-- 45s (game 018: three Blast Off combos without M.A.D. for that reason).
-- The plant hold: no other spell (or item) order until M.A.D. is on cooldown or the hold ends.
function X.MadHoldActive()
	if DotaTime() >= (bot._madHoldUntil or -999) then
		return false
	end
	local plantAbility = bot:GetAbilityByName("techies_mutually_assured_destruction")
	if plantAbility ~= nil and plantAbility:GetCooldownTimeRemaining() > 0 then
		bot._madHoldUntil = nil
		return false
	end
	return true
end
function X.PlantMad(plant, loc, tag)
	local castPoint = math.max(0.3, plant:GetCastPoint())
	-- Always inside cast range, so the order is a cast and not a walk first (game 021: all 7
	-- failed plants had M.A.D. off cooldown, never cast; a walk-in leaves time for other orders).
	local range = plant:GetCastRange()
	if range == nil or range < 100 then
		range = 450
	end
	if GetUnitToLocationDistance(bot, loc) > range - 20 then
		loc = Fu.Utils.GetOffsetLocationTowardsTargetLocation(bot:GetLocation(), loc, range - 40)
	end
	bot._madLoc = loc
	bot._madDetonateAt = DotaTime() + castPoint + 0.15
	-- 4s after the planned detonate: game 019, plants into a spot beyond cast range (he walks in
	-- first) showed the barrel 2-3s after the order, past the old 2s window.
	bot._madUntil = bot._madDetonateAt + 4
	bot._madPlantAt = DotaTime()
	-- No other spell order until the plant is cast: game 019, 8 of 15 plants failed because the
	-- next think sent Sticky Bomb, the Tazer, a mine or Blast Off and cut the cast short (43:01:
	-- post-blast plant and post-blast Sticky in the same second).
	-- Held until M.A.D. is on cooldown (the plant was cast) or 1.2s pass; see MadHoldActive.
	bot._madHoldUntil = DotaTime() + math.max(castPoint + 0.25, 1.2)
	X.LogTechies("mad-plant " .. plant:GetName() .. (tag and (" " .. tag) or ""), 0, loc)
	bot:Action_UseAbilityOnLocation(plant, loc)
end
-- Landing from Blast Off: M.A.D. right after the mines, before Sticky Bomb, once per Blast Off.
-- Aimed at the stunned enemy hero by the landing spot (or where the nearest one is heading). No
-- "recently hit" rule here: right after landing he is almost always being hit.
function X.ConsiderPostBlastMad()
	if bot._blastAt == nil or bot._madBlastAt == bot._blastAt then
		return nil, nil
	end
	local since = DotaTime() - bot._blastAt
	if since < 1.75 or since > 6 then
		return nil, nil
	end
	if bot._madLoc ~= nil and DotaTime() < (bot._madUntil or 0) or X.MadDetonate() ~= nil then
		return nil, nil
	end
	local plant = X.MadPlant()
	if plant == nil then
		return nil, nil
	end
	local range = plant:GetCastRange()
	if range == nil or range < 100 then
		range = 450
	end
	range = Fu.GetProperCastRange(false, bot, range)
	local best, bestScore = nil, math.huge
	for _, enemy in pairs(Fu.GetNearbyHeroes(bot, range + 250, true, BOT_MODE_NONE) or {}) do
		if Fu.IsValidHero(enemy) and not Fu.IsSuspiciousIllusion(enemy) then
			local dist = GetUnitToUnitDistance(bot, enemy)
			-- A disabled one first (the Blast Off stun), then the nearest.
			local score = dist - (Fu.IsDisabled(enemy) and 10000 or 0)
			if score < bestScore then
				best, bestScore = enemy, score
			end
		end
	end
	if best == nil then
		return nil, nil
	end
	local loc = best:GetLocation()
	if not Fu.IsDisabled(best) then
		loc = best:GetExtrapolatedLocation(math.max(0.3, plant:GetCastPoint()) + 0.3)
	end
	if GetUnitToLocationDistance(bot, loc) > range then
		loc = Fu.Utils.GetOffsetLocationTowardsTargetLocation(bot:GetLocation(), loc, range - 40)
	end
	return plant, loc
end
function X.SkillsComplement()
	-- Detonate M.A.D. still works while Techies is dead or already acting.
	if X.ConsiderDetonateMad() > 0 then
		local detonateAbility = X.MadDetonate()
		if detonateAbility ~= nil then
			X.LogTechies("mad-detonate why=" .. tostring(bot._madDetonateWhy), 0, bot._madLoc or bot:GetLocation())
			bot:Action_UseAbility(detonateAbility)
		end
		bot._madLoc = nil
		bot._madDetonateAt = nil
		bot._madBarrelAt = nil
		return
	end
	-- An escape Blast Off that never went on cooldown (game 031, 6:56: ordered, then not cast;
	-- 1s cast point while being hit): log what stopped it.
	if bot._escapeBlastAt ~= nil and DotaTime() - bot._escapeBlastAt >= 1.6 then
		if blastOffAbility:IsTrained() and blastOffAbility:GetCooldownTimeRemaining() <= 0 then
			pcall(
				print,
				string.format(
					"[OHA-TECHIES] t=%.0f escape-not-cast stun=%s hex=%s silence=%s mode=%d act=%d hp=%.2f",
					DotaTime(),
					tostring(bot:IsStunned()),
					tostring(bot:IsHexed()),
					tostring(bot:IsSilenced()),
					bot:GetActiveMode(),
					bot:GetCurrentActionType(),
					Fu.GetHP(bot)
				)
			)
		end
		bot._escapeBlastAt = nil
	end
	if Fu.CanNotUseAbility(bot) then
		return
	end
	if X.MadHoldActive() then
		return
	end
	local context = AbilityContext.Build(bot)
	isEngaging = context.isEngaging
	isRetreating = context.isRetreating
	isAttacking = Fu.IsAttacking(bot)
	hpRatio = context.hp
	botTarget = context.target
	mineDamage = proximityMinesAbility:GetSpecialValueInt("damage")
	twoMinesDamage = mineDamage * 2
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
	local veil = X.ConsiderPostBlastVeil()
	if veil ~= nil then
		bot._veilBlastAt = bot._blastAt
		X.LogTechies("post-blast-veil", 0, bot:GetLocation())
		bot:Action_UseAbility(veil)
		return
	end
	-- Scepter: Minefield Sign first (one per Blast Off), on himself (10 range): the triangle goes
	-- around him, inside its radius, invulnerable and with +15% damage (Valve data).
	if X.ConsiderPostBlastSign() then
		bot._signBlastAt = bot._blastAt
		X.LogTechies("post-blast-sign", 0, bot:GetLocation())
		bot:Action_UseAbilityOnLocation(minefieldSignAbility, bot:GetLocation())
		return
	end
	local postMine = X.ConsiderPostBlastMines()
	if postMine ~= nil then
		X.OrderMine(postMine, "post-blast")
		return
	end
	local madPlant, madLoc = X.ConsiderPostBlastMad()
	if madPlant ~= nil then
		bot._madBlastAt = bot._blastAt
		X.PlantMad(madPlant, madLoc, "post-blast")
		return
	end
	local stickyLoc = X.ConsiderPostBlastSticky()
	if stickyLoc ~= nil then
		bot._stickyBlastAt = bot._blastAt
		X.LogTechies("post-blast-sticky", 0, stickyLoc)
		bot:Action_UseAbilityOnLocation(stickyBombAbility, stickyLoc)
		return
	end
	-- Then out with Force Staff: turn toward home first (it pushes the way he faces).
	if X.ConsiderPostBlastEscape() then
		return
	end
	-- Short on mana for a Blast Off that is otherwise ready: Soul Ring now, Blast Off next think.
	if X.ConsiderSoulRingForBlast() then
		return
	end
	blastOffDesire, blastOffLocation, blastOffWhy = X.ConsiderBlastOff()
	if blastOffDesire > 0 then
		bot:Action_ClearActions(false)
		-- Sticky Bomb first (user call), then Blast Off: only when it is ready, an enemy hero is
		-- in its cast range and near the landing spot, and there is mana for both. Otherwise
		-- Blast Off goes alone, as before; Sticky never holds it back.
		local stickyFirst = false
		local manaLeft = bot:GetMana() - blastOffAbility:GetManaCost()
		if
			blastOffWhy ~= "escape"
			and stickyBombAbility:IsTrained()
			and stickyBombAbility:IsFullyCastable()
			and manaLeft >= stickyBombAbility:GetManaCost()
		then
			local range = stickyBombAbility:GetCastRange() + 100
			local best, bestDist = nil, math.huge
			for _, enemy in pairs(Fu.GetNearbyHeroes(bot, range, true, BOT_MODE_NONE) or {}) do
				if
					Fu.IsValidHero(enemy)
					and Fu.CanCastOnNonMagicImmune(enemy)
					and not Fu.IsSuspiciousIllusion(enemy)
					and GetUnitToLocationDistance(enemy, blastOffLocation) <= 450
				then
					local dist = GetUnitToLocationDistance(enemy, blastOffLocation)
					if dist < bestDist then
						best, bestDist = enemy, dist
					end
				end
			end
			if best ~= nil then
				local stickyLoc = Fu.IsDisabled(best) and best:GetLocation() or best:GetExtrapolatedLocation(0.5)
				bot:ActionQueue_UseAbilityOnLocation(stickyBombAbility, stickyLoc)
				manaLeft = manaLeft - stickyBombAbility:GetManaCost()
				stickyFirst = true
				X.LogTechies("pre-blast-sticky", 0, stickyLoc)
			end
		end
		bot:ActionQueue_UseAbilityOnLocation(blastOffAbility, blastOffLocation)
		-- The cast point is spent before the next queued order; the 0.75s flight is not.
		bot:ActionQueue_Delay(math.max(0.3, blastOffAbility:GetSpecialValueFloat("duration")) + 0.1)
		local tazer = false
		if X.TazerUsable() and manaLeft >= reactiveTazerAbility:GetManaCost() then
			if X.TazerIsUnitTarget() then
				bot:ActionQueue_UseAbilityOnEntity(reactiveTazerAbility, bot)
			else
				bot:ActionQueue_UseAbility(reactiveTazerAbility)
			end
			bot._tazerCastAt = DotaTime()
			manaLeft = manaLeft - reactiveTazerAbility:GetManaCost()
			tazer = true
		end
		local planted = 0
		if blastOffWhy ~= "escape" and proximityMinesAbility:IsTrained() and not proximityMinesAbility:IsHidden() then
			local mineCost = proximityMinesAbility:GetManaCost()
			local maxMines = math.min(X.MineCharges(), mineCost > 0 and math.floor(manaLeft / mineCost) or 3)
			for _, spot in ipairs(X.MineTriangle(blastOffLocation, 210)) do
				if planted >= maxMines then
					break
				end
				bot:ActionQueue_UseAbilityOnLocation(proximityMinesAbility, spot)
				planted = planted + 1
			end
			if planted > 0 then
				pcall(ChargeTracker.Issued, bot, proximityMinesAbility, nil, planted)
			end
		end
		X.LogTechies(
			string.format("blast why=%s tazer=%s", blastOffWhy or "?", tostring(tazer)),
			planted,
			blastOffLocation
		)
		if blastOffWhy == "escape" then
			bot._escapeBlastAt = DotaTime()
		end
		if blastOffWhy ~= "escape" then
			-- With Sticky in front, Blast Off starts one Sticky cast later; the landing steps
			-- (mines, M.A.D., ...) are timed from here.
			bot._blastAt = DotaTime() + (stickyFirst and math.max(0, stickyBombAbility:GetCastPoint()) or 0)
			bot._blastLoc = blastOffLocation
			if stickyFirst then
				-- Sticky already thrown: no second one after landing.
				bot._stickyBlastAt = bot._blastAt
			end
		end
		return
	end
	tazerDesire, tazerTarget = X.ConsiderReactiveTazer()
	if tazerDesire > 0 then
		-- Unit-target only in a version where it can go on an ally. Otherwise it is a self cast.
		if X.TazerIsUnitTarget() then
			bot:Action_UseAbilityOnEntity(reactiveTazerAbility, tazerTarget or bot)
		else
			bot:Action_UseAbility(reactiveTazerAbility)
		end
		bot._tazerCastAt = DotaTime()
		return
	end
	-- No manual Tazer detonation. Popping it early throws away the speed and the disarm on
	-- attackers, and the blast goes off by itself when the buff ends.
	stickyBombDesire, stickyBombLocation = X.ConsiderStickyBomb()
	if stickyBombDesire > 0 then
		bot:Action_UseAbilityOnLocation(stickyBombAbility, stickyBombLocation)
		return
	end
	plantDesire, plantLocation = X.ConsiderPlantMad()
	if plantDesire > 0 then
		X.PlantMad(X.MadPlant(), plantLocation)
		return
	end
	plantDesire, plantLocation = X.ConsiderProximityMines()
	if plantDesire > 0 then
		X.OrderMine(plantLocation, X._mineKind or "mine")
		return
	end
	minefieldSignDesire, minefieldSignLocation = X.ConsiderMineFieldSign()
	if minefieldSignDesire > 0 then
		bot:Action_UseAbilityOnLocation(minefieldSignAbility, minefieldSignLocation)
		return
	end
end
-- Sticky Bomb (datafeed): 0.1s cast point, flies at 500 with 2000 acceleration, sticks to an enemy
-- hero within 300 of the landing, explodes 2s later in a 350 radius.
-- A hero: aimed where he will be when the bomb lands (cast point + flight), kept in cast range.
local function StickyHeroSpot(hero, range, speed, accel)
	local loc = hero:GetLocation()
	if not Fu.IsDisabled(hero) then
		local eta = stickyBombAbility:GetCastPoint()
			+ Fu.GetETAWithAcceleration(GetUnitToUnitDistance(bot, hero), speed, accel)
		loc = hero:GetExtrapolatedLocation(eta)
	end
	if GetUnitToLocationDistance(bot, loc) > range then
		loc = Fu.Site.GetXUnitsTowardsLocation(bot, loc, range)
	end
	return loc
end
-- Creeps: the spot in cast range that has the most of them within 300 (the 350 blast, less the
-- creeps' drift over the fuse). Candidates: each creep, each pair's midpoint and the center.
local STICKY_AOE = 300
local function StickyCreepSpot(units, range)
	local list = {}
	for _, unit in pairs(units or {}) do
		if Fu.IsValid(unit) then
			table.insert(list, unit)
		end
	end
	if #list == 0 then
		return nil, 0
	end
	local candidates = { Fu.GetCenterOfUnits(list) }
	for i = 1, #list do
		local firstLocation = list[i]:GetLocation()
		table.insert(candidates, firstLocation)
		for j = i + 1, #list do
			table.insert(candidates, (firstLocation + list[j]:GetLocation()) / 2)
		end
	end
	local best, bestCount, bestSum = nil, 0, math.huge
	for _, loc in ipairs(candidates) do
		if GetUnitToLocationDistance(bot, loc) <= range then
			local count, sum = 0, 0
			for _, unit in ipairs(list) do
				local dist = GetUnitToLocationDistance(unit, loc)
				if dist <= STICKY_AOE then
					count = count + 1
					sum = sum + dist
				end
			end
			if count > bestCount or count == bestCount and sum < bestSum then
				best, bestCount, bestSum = loc, count, sum
			end
		end
	end
	return best, bestCount
end
function X.ConsiderStickyBomb()
	if not stickyBombAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
	end
	local castRange = Fu.GetProperCastRange(false, bot, stickyBombAbility:GetCastRange())
	local damage = stickyBombAbility:GetSpecialValueInt("damage")
	local speed = stickyBombAbility:GetSpecialValueInt("speed")
	local acceleration = stickyBombAbility:GetSpecialValueInt("acceleration")
	local abilityLevel = stickyBombAbility:GetLevel()
	local enemiesInRange = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(enemiesInRange) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and Fu.CanKillTarget(enemyHero, damage, DAMAGE_TYPE_MAGICAL)
			and not Fu.IsSuspiciousIllusion(enemyHero)
			and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
			and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
			and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
			and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
			and not enemyHero:HasModifier("modifier_templar_assassin_refraction_absorb")
		then
			return BOT_ACTION_DESIRE_HIGH, StickyHeroSpot(enemyHero, castRange, speed, acceleration)
		end
	end
	local alliesInRange = Fu.GetNearbyHeroes(bot, castRange, false, BOT_MODE_NONE)
	for _, allyHero in pairs(alliesInRange) do
		local allyNearbyEnemies = Fu.GetNearbyHeroes(allyHero, 1200, true, BOT_MODE_NONE)
		for _, enemyHero in pairs(allyNearbyEnemies) do
			if
				Fu.IsValidHero(allyHero)
				and Fu.IsRetreating(allyHero)
				and allyHero:WasRecentlyDamagedByAnyHero(1.5)
				and not allyHero:IsIllusion()
			then
				if
					Fu.IsValidHero(enemyHero)
					and Fu.CanCastOnNonMagicImmune(enemyHero)
					and Fu.IsInRange(bot, enemyHero, castRange)
					and Fu.IsChasingTarget(enemyHero, allyHero)
					and not Fu.IsDisabled(enemyHero)
					and not Fu.IsTaunted(enemyHero)
					and not Fu.IsSuspiciousIllusion(enemyHero)
					and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
				then
					return BOT_ACTION_DESIRE_HIGH, StickyHeroSpot(enemyHero, castRange, speed, acceleration)
				end
			end
		end
	end
	if isEngaging then
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			local alliesNearTarget = Fu.GetNearbyHeroes(botTarget, 1200, true, BOT_MODE_NONE)
			local enemiesNearTarget = Fu.GetNearbyHeroes(botTarget, 1200, false, BOT_MODE_NONE)
			if alliesNearTarget ~= nil and enemiesNearTarget ~= nil and #alliesNearTarget >= #enemiesNearTarget then
				return BOT_ACTION_DESIRE_HIGH, StickyHeroSpot(botTarget, castRange, speed, acceleration)
			end
		end
	end
	if isRetreating then
		local enemiesInRange = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
		for _, enemyHero in pairs(enemiesInRange) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.IsChasingTarget(enemyHero, bot)
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and not Fu.IsDisabled(enemyHero)
			then
				local alliesNearEnemy = Fu.GetNearbyHeroes(enemyHero, 1200, true, BOT_MODE_NONE)
				local enemiesNearEnemy = Fu.GetNearbyHeroes(enemyHero, 1200, false, BOT_MODE_NONE)
				if
					alliesNearEnemy ~= nil
					and enemiesNearEnemy ~= nil
					and (#enemiesNearEnemy > #alliesNearEnemy or bot:WasRecentlyDamagedByAnyHero(2))
				then
					return BOT_ACTION_DESIRE_HIGH, StickyHeroSpot(enemyHero, castRange, speed, acceleration)
				end
			end
		end
	end
	if (Fu.IsPushing(bot) or Fu.IsDefending(bot)) and abilityLevel >= 3 and not Fu.IsThereNonSelfCoreNearby(1000) then
		local spot, count = StickyCreepSpot(bot:GetNearbyLaneCreeps(castRange + STICKY_AOE, true), castRange)
		if spot ~= nil and count >= 4 and Fu.GetMP(bot) > 0.5 then
			return BOT_ACTION_DESIRE_HIGH, spot
		end
	end
	if Fu.IsFarming(bot) and Fu.GetManaAfter(stickyBombAbility:GetManaCost()) > 0.3 then
		local neutralCreeps = bot:GetNearbyNeutralCreeps(castRange + STICKY_AOE)
		local spot, count = StickyCreepSpot(neutralCreeps, castRange)
		if
			spot ~= nil
			and (count >= 2 or count >= 1 and Fu.IsValid(neutralCreeps[1]) and neutralCreeps[1]:IsAncientCreep())
		then
			return BOT_ACTION_DESIRE_HIGH, spot
		end
		spot, count = StickyCreepSpot(bot:GetNearbyLaneCreeps(castRange + STICKY_AOE, true), castRange)
		if spot ~= nil and count >= 3 then
			return BOT_ACTION_DESIRE_HIGH, spot
		end
	end
	if Fu.IsLaning(bot) then
		local killableCreeps = {}
		local laneCreeps = bot:GetNearbyLaneCreeps(castRange, true)
		local enemiesInRange = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
		for _, enemyHero in pairs(enemiesInRange) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and not Fu.IsSuspiciousIllusion(enemyHero)
			then
				local enemyTowers = enemyHero:GetNearbyTowers(600, true)
				if
					enemyTowers ~= nil
					and #enemyTowers >= 1
					and Fu.IsValidBuilding(enemyTowers[1])
					and enemyTowers[1]:GetAttackTarget() == enemyHero
				then
					return BOT_ACTION_DESIRE_HIGH, StickyHeroSpot(enemyHero, castRange, speed, acceleration)
				end
			end
		end
		-- The bomb latches the nearest enemy hero at the landing spot. A lane poke is worth the mana.
		if Fu.GetManaAfter(stickyBombAbility:GetManaCost()) > 0.4 then
			for _, enemyHero in pairs(enemiesInRange) do
				if
					Fu.IsValidHero(enemyHero)
					and Fu.CanCastOnNonMagicImmune(enemyHero)
					and Fu.IsInRange(bot, enemyHero, castRange)
					and not Fu.IsSuspiciousIllusion(enemyHero)
					and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
					and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
					and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
				then
					return BOT_ACTION_DESIRE_HIGH, StickyHeroSpot(enemyHero, castRange, speed, acceleration)
				end
			end
		end
		for _, creep in pairs(bot:GetNearbyLaneCreeps(castRange + STICKY_AOE, true) or {}) do
			if Fu.IsValid(creep) and creep:GetHealth() <= damage then
				table.insert(killableCreeps, creep)
			end
		end
		local spot, count = StickyCreepSpot(killableCreeps, castRange)
		if
			spot ~= nil
			and count >= 2
			and Fu.GetMP(bot) > 0.35
			and Fu.CanBeAttacked(killableCreeps[1])
			and not Fu.IsThereNonSelfCoreNearby(1200)
		then
			return BOT_ACTION_DESIRE_HIGH, spot
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if
			Fu.IsRoshan(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and isAttacking
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, castRange) and isAttacking then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	local killableCreeps = {}
	local laneCreeps = bot:GetNearbyLaneCreeps(castRange + STICKY_AOE, true)
	for _, creep in pairs(laneCreeps or {}) do
		if Fu.IsValid(creep) and creep:GetHealth() <= damage then
			table.insert(killableCreeps, creep)
		end
	end
	local spot, count = StickyCreepSpot(killableCreeps, castRange)
	if spot ~= nil and count >= 3 and Fu.CanBeAttacked(killableCreeps[1]) and not Fu.IsThereNonSelfCoreNearby(1200) then
		return BOT_ACTION_DESIRE_HIGH, spot
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
	local foes = Fu.GetNearbyHeroes(hero, 800, true, BOT_MODE_NONE)
	for _, foe in pairs(foes or {}) do
		if Fu.IsValidHero(foe) and not foe:IsIllusion() and foe:GetAttackTarget() == hero then
			return true
		end
	end
	return false
end
local function TazerCastRange()
	local range = reactiveTazerAbility:GetCastRange()
	if range == nil or range < 100 then
		range = 600
	end
	return Fu.GetProperCastRange(false, bot, range)
end
local function AllyCanTakeTazer(ally, range)
	return ally ~= nil
		and ally ~= bot
		and Fu.IsValidHero(ally)
		and not ally:IsIllusion()
		and Fu.IsInRange(bot, ally, range)
		and not ally:HasModifier("modifier_techies_reactive_tazer")
		and Fu.CanCastOnNonMagicImmune(ally)
end
-- Why an ally needs the Tazer to get away, or nil. Being hit only counts when it is a real
-- threat (below 70% HP, or two enemy heroes on her): one lane harass hit used to make a
-- full-HP Medusa "fleeing" (5:50).
local function AllyIsFleeing(ally)
	if Fu.IsRetreating(ally) and ally:WasRecentlyDamagedByAnyHero(3.0) then
		return "flee-retreat"
	end
	local near = Fu.GetNearbyHeroes(ally, 800, true, BOT_MODE_NONE) or {}
	if HeroIsBeingHit(ally) and (Fu.GetHP(ally) < 0.7 or #near >= 2) then
		return "flee-hit"
	end
	-- Chased: below 50% HP, or by two enemy heroes. At 80% a lane trade counted (game 014:
	-- Lich at 62-78% HP, 3 of 13 casts).
	local foes = Fu.GetNearbyHeroes(ally, 1000, true, BOT_MODE_NONE)
	local chasers = 0
	for _, foe in pairs(foes or {}) do
		if Fu.IsValidHero(foe) and not Fu.IsSuspiciousIllusion(foe) and Fu.IsChasingTarget(foe, ally) then
			chasers = chasers + 1
		end
	end
	if chasers >= 1 and (Fu.GetHP(ally) < 0.5 or chasers >= 2) then
		return "flee-chased"
	end
	return nil
end
-- Why an ally is going in (worth the Tazer), or nil. Attack mode alone is not enough: an
-- enemy hero has to be close to her.
local function AllyIsInitiating(ally)
	-- A real kill try (enemy below 50% HP) or a team fight. A lane trade on a healthy enemy
	-- counted (game 014: 5 of 13 casts on Lich at 89-100% HP, enemy healthy).
	local teamFight = Fu.IsInTeamFight(ally, 1200)
	local foes = Fu.GetNearbyHeroes(ally, 1000, true, BOT_MODE_NONE)
	for _, foe in pairs(foes or {}) do
		if Fu.IsValidHero(foe) and not Fu.IsSuspiciousIllusion(foe) and (teamFight or Fu.GetHP(foe) < 0.5) then
			if Fu.IsChasingTarget(ally, foe) then
				return "initiate-chase"
			end
			if Fu.IsGoingOnSomeone(ally) and GetUnitToUnitDistance(ally, foe) <= 700 then
				return "initiate"
			end
		end
	end
	return nil
end
-- [OHA-TECHIES] tazer target=... why=..., every cast.
function X.LogTazer(target, why)
	pcall(
		print,
		string.format(
			"[OHA-TECHIES] t=%.0f tazer target=%s why=%s targetHp=%.2f mode=%d",
			DotaTime(),
			target == bot and "self" or (string.gsub(target:GetUnitName(), "npc_dota_hero_", "")),
			why,
			Fu.GetHP(target),
			target:GetActiveMode()
		)
	)
end
function X.ConsiderReactiveTazer()
	if not X.TazerUsable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local range = TazerCastRange()
	-- Self first when he is the one being hit or chased. The buff is speed plus a disarm on attackers.
	if not bot:HasModifier("modifier_techies_reactive_tazer") then
		-- Same bar as for allies: one lane harass hit was enough (36 of 55 casts last game).
		if
			HeroIsBeingHit(bot)
			and (Fu.GetHP(bot) < 0.7 or #(Fu.GetNearbyHeroes(bot, 800, true, BOT_MODE_NONE) or {}) >= 2)
		then
			X.LogTazer(bot, "self-hit")
			return BOT_ACTION_DESIRE_HIGH, bot
		end
		if isRetreating then
			-- Below 50% HP or two chasers (game 014: 4 casts at 78-79% HP).
			local foes = Fu.GetNearbyHeroes(bot, 1400, true, BOT_MODE_NONE)
			local chasers = 0
			for _, foe in pairs(foes or {}) do
				if Fu.IsValidHero(foe) and not Fu.IsSuspiciousIllusion(foe) and Fu.IsChasingTarget(foe, bot) then
					chasers = chasers + 1
				end
			end
			if chasers >= 1 and (Fu.GetHP(bot) < 0.5 or chasers >= 2) then
				X.LogTazer(bot, "self-chased")
				return BOT_ACTION_DESIRE_HIGH, bot
			end
		end
	end
	-- Same cast works on an ally with no shard. Help the one who is fleeing, then the one going in.
	local flee, initiate, fleeWhy, initiateWhy = nil, nil, nil, nil
	local allies = X.TazerIsUnitTarget() and Fu.GetNearbyHeroes(bot, range, false, BOT_MODE_NONE) or {}
	for _, ally in pairs(allies or {}) do
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
		X.LogTazer(flee, fleeWhy)
		return BOT_ACTION_DESIRE_HIGH, flee
	end
	-- Going in: keep 25% mana for mines and Blast Off.
	if Fu.GetManaAfter(reactiveTazerAbility:GetManaCost()) < 0.25 then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	-- With Blast Off up, keep the Tazer for the combo. Spent on an ally going in or on our own
	-- approach, it was on cooldown by the time a target came into Blast Off range.
	local selfEngage = not bot:HasModifier("modifier_techies_reactive_tazer")
		and isEngaging
		and Fu.IsValidTarget(botTarget)
		and Fu.IsInRange(bot, botTarget, 1200)
		and not Fu.IsSuspiciousIllusion(botTarget)
		and Fu.GetManaAfter(reactiveTazerAbility:GetManaCost()) > 0.2
	if (initiate ~= nil or selfEngage) and X.ComboReady() then
		if DotaTime() >= (bot._tazerHeldLogAt or -999) then
			bot._tazerHeldLogAt = DotaTime() + 10
			pcall(
				print,
				string.format(
					"[OHA-TECHIES] t=%.0f tazer-held for=%s pid=%d mp=%.2f",
					DotaTime(),
					initiate ~= nil and (string.gsub(initiate:GetUnitName(), "npc_dota_hero_", "")) or "self",
					bot:GetPlayerID(),
					Fu.GetMP(bot)
				)
			)
		end
		return BOT_ACTION_DESIRE_NONE, nil
	end
	if initiate ~= nil then
		X.LogTazer(initiate, initiateWhy)
		return BOT_ACTION_DESIRE_HIGH, initiate
	end
	if selfEngage then
		X.LogTazer(bot, "self-engage")
		return BOT_ACTION_DESIRE_HIGH, bot
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
local function TazerHost()
	if bot:HasModifier("modifier_techies_reactive_tazer") then
		return bot
	end
	local allies = Fu.GetNearbyHeroes(bot, 1200, false, BOT_MODE_NONE)
	for _, ally in pairs(allies or {}) do
		if Fu.IsValidHero(ally) and ally:HasModifier("modifier_techies_reactive_tazer") then
			return ally
		end
	end
	return nil
end
function X.ConsiderDetonateTazer()
	if
		tazerStopAbility == nil
		or tazerStopAbility:IsNull()
		or tazerStopAbility:IsHidden()
		or not tazerStopAbility:IsFullyCastable()
	then
		return BOT_ACTION_DESIRE_NONE
	end
	local host = TazerHost()
	if host == nil then
		return BOT_ACTION_DESIRE_NONE
	end
	-- Secondary cast pops the charge early and ends the speed and the disarm on attackers.
	-- Pop it at once only for two heroes in the blast; one hero waits until the buff has worked.
	local radius = reactiveTazerAbility:GetSpecialValueInt("stun_radius")
	if radius == nil or radius < 100 then
		radius = reactiveTazerAbility:GetSpecialValueInt("radius")
	end
	if radius == nil or radius < 100 then
		radius = 450
	end
	local inBlast = 0
	local foes = Fu.GetNearbyHeroes(host, radius, true, BOT_MODE_NONE)
	for _, foe in pairs(foes or {}) do
		if Fu.IsValidHero(foe) and not Fu.IsSuspiciousIllusion(foe) and not foe:IsMagicImmune() then
			inBlast = inBlast + 1
		end
	end
	local held = DotaTime() - (bot._tazerCastAt or -99)
	if inBlast >= 2 or inBlast >= 1 and held >= 1.5 then
		return BOT_ACTION_DESIRE_HIGH
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.TazerIsUnitTarget()
	local ok, behavior = pcall(function()
		return reactiveTazerAbility:GetBehavior()
	end)
	return ok and behavior ~= nil and Fu.CheckBitfieldFlag(behavior, ABILITY_BEHAVIOR_UNIT_TARGET)
end
function X.ConsiderPlantMad()
	-- No Shard-buff check: the plant ability is found directly (see MadPlant).
	if bot:WasRecentlyDamagedByAnyHero(1.5) then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	-- The barrel plant (Shard) found at runtime; never the passive innate (a refused order
	-- freezes him).
	local plant = X.MadPlant()
	if plant == nil then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	if bot._madLoc ~= nil and DotaTime() < (bot._madUntil or 0) or X.MadDetonate() ~= nil then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local castRange = plant:GetCastRange()
	if castRange == nil or castRange < 100 then
		castRange = 450
	end
	castRange = Fu.GetProperCastRange(false, bot, castRange)
	local function Toward(unit)
		local dist = GetUnitToUnitDistance(bot, unit)
		if dist <= castRange then
			return unit:GetLocation()
		end
		if dist <= castRange + 250 then
			return Fu.Utils.GetOffsetLocationTowardsTargetLocation(
				bot:GetLocation(),
				unit:GetLocation(),
				castRange - 40
			)
		end
		return nil
	end
	-- Burst: a disabled enemy hero in reach (Blast Off stun, a teammate's stun).
	for _, foe in pairs(Fu.GetNearbyHeroes(bot, castRange + 250, true, BOT_MODE_NONE) or {}) do
		if Fu.IsValidHero(foe) and not Fu.IsSuspiciousIllusion(foe) and Fu.IsDisabled(foe) then
			local loc = Toward(foe)
			if loc ~= nil then
				return BOT_ACTION_DESIRE_HIGH, loc
			end
		end
	end
	if
		isEngaging
		and Fu.IsValidTarget(botTarget)
		and not Fu.IsSuspiciousIllusion(botTarget)
		and GetUnitToUnitDistance(bot, botTarget) > 400
	then
		-- Where the target will be when it blows: 1s plant + 1.5s fuse.
		local loc = Toward(botTarget)
		if loc ~= nil then
			-- Where he will be when the plant lands (1s cast point); the barrel then waits until he
			-- is within 350 of it.
			if not Fu.IsDisabled(botTarget) then
				loc = botTarget:GetExtrapolatedLocation(1.1)
				if GetUnitToLocationDistance(bot, loc) > castRange then
					loc = Fu.Utils.GetOffsetLocationTowardsTargetLocation(bot:GetLocation(), loc, castRange - 40)
				end
			end
			return BOT_ACTION_DESIRE_HIGH, loc
		end
	end
	if isRetreating then
		local foes = Fu.GetNearbyHeroes(bot, 1100, true, BOT_MODE_NONE)
		for _, foe in pairs(foes or {}) do
			if
				Fu.IsValidHero(foe)
				and not Fu.IsSuspiciousIllusion(foe)
				and Fu.IsChasingTarget(foe, bot)
				and GetUnitToUnitDistance(bot, foe) > 500
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
		local plantAbility = bot:GetAbilityByName("techies_mutually_assured_destruction")
		local detonateAbility = bot:GetAbilityByName("techies_focused_detonate")
		why = string.format(
			" alive=%s plantCd=%.1f det=%s/%s since=%.1f",
			tostring(bot:IsAlive()),
			plantAbility ~= nil and plantAbility:GetCooldownTimeRemaining() or -1,
			detonateAbility ~= nil and (detonateAbility:IsHidden() and "hidden" or "shown") or "none",
			detonateAbility ~= nil and tostring(detonateAbility:IsFullyCastable()) or "-",
			DotaTime() - (bot._madPlantAt or DotaTime())
		)
	end)
	return why
end
-- Detonate whenever it is shown (user call): techies_focused_detonate shows once a barrel is down,
-- so it is clicked as soon as it is castable, unless he is dead, stunned, hexed, silenced or
-- nightmared. No timer and no enemy check. A plant that never shows the detonate is logged:
-- 'not cast' when M.A.D. never went on cooldown, 'no detonate' when it did.
-- A planted M.A.D. waits for its victim (user call; datafeed Shard text: detonated manually with a
-- sub-ability, one at a time, no time limit). It used to go off as soon as the detonate button showed,
-- wherever the enemies were. Now: an enemy hero within 350 of the barrel (blast radius 400). Two
-- exceptions free the one-barrel slot: the barrel is 30s old, or Techies is more than 1500 from it
-- after 5s. No known barrel spot: as before, at once.
local MAD_TRIGGER = 350
function X.ConsiderDetonateMad()
	local now = DotaTime()
	if X.MadDetonate() ~= nil then
		if not bot:IsAlive() or bot:IsStunned() or bot:IsHexed() or bot:IsSilenced() or bot:IsNightmared() then
			return BOT_ACTION_DESIRE_NONE
		end
		bot._madBarrelAt = bot._madBarrelAt or now
		local loc = bot._madLoc
		if loc == nil then
			bot._madDetonateWhy = "no-spot"
			return BOT_ACTION_DESIRE_HIGH
		end
		for _, enemy in pairs(Fu.GetEnemiesNearLoc(loc, MAD_TRIGGER) or {}) do
			if Fu.IsValidHero(enemy) and not Fu.IsSuspiciousIllusion(enemy) then
				bot._madDetonateWhy = "enemy-in"
				return BOT_ACTION_DESIRE_HIGH
			end
		end
		local age = now - bot._madBarrelAt
		if age > 30 then
			bot._madDetonateWhy = "stale"
			return BOT_ACTION_DESIRE_HIGH
		end
		if age > 5 and GetUnitToLocationDistance(bot, loc) > 1500 then
			bot._madDetonateWhy = "left-behind"
			return BOT_ACTION_DESIRE_HIGH
		end
		return BOT_ACTION_DESIRE_NONE
	end
	bot._madBarrelAt = nil
	if bot._madLoc ~= nil and now - (bot._madPlantAt or now) > 3.5 then
		local plantAbility = bot:GetAbilityByName("techies_mutually_assured_destruction")
		local cast = plantAbility ~= nil and plantAbility:GetCooldownTimeRemaining() > 0
		X.LogTechies(
			"mad-plant-failed (" .. (cast and "no detonate" or "not cast") .. ")" .. PlantFailWhy(),
			0,
			bot._madLoc
		)
		bot._madLoc = nil
		bot._madDetonateAt = nil
	end
	return BOT_ACTION_DESIRE_NONE
end
-- Returns desire, location, and why: channel, fight, chase, initiate, last-stand, escape.
-- Soul Ring (costs 170 HP, gives 170 mana for 10s) right before every engaging Blast Off
-- (never to escape), and only if HP stays safe after both the ring and Blast
-- Off's own cost (a share of current HP): early on that pair would drop him into a TP home.
function X.ConsiderSoulRingForBlast()
	local slot = bot:FindItemSlot("item_soul_ring")
	if slot < 0 or slot > 5 then
		return false
	end
	local ring = bot:GetItemInSlot(slot)
	if ring == nil or not ring:IsFullyCastable() then
		return false
	end
	-- Before every engaging Blast Off, not only when short on mana: the extra 170 pays for the
	-- Tazer and the mine triangle that follow. Still only if the ring makes Blast Off affordable.
	local cost = blastOffAbility:GetManaCost()
	local mana = bot:GetMana()
	if mana + 170 < cost then
		return false
	end
	local desire, loc, why = X.ConsiderBlastOff(true)
	if desire <= 0 or why == "escape" then
		return false
	end
	local pct = blastOffAbility:GetSpecialValueInt("hp_cost")
	if pct == nil or pct <= 0 then
		pct = 20
	end
	local after = (bot:GetHealth() - 170) * (1 - pct / 100)
	local ok = after >= 0.4 * bot:GetMaxHealth() and after >= 300
	if DotaTime() >= (bot._soulRingLogAt or -999) then
		bot._soulRingLogAt = DotaTime() + 5
		pcall(
			print,
			string.format(
				"[OHA-TECHIES] t=%.0f soul-ring %s for=blast-%s hpAfter=%.0f max=%.0f mana=%.0f cost=%.0f",
				DotaTime(),
				ok and "used" or "skipped-hp",
				tostring(why),
				after,
				bot:GetMaxHealth(),
				mana,
				cost
			)
		)
	end
	if not ok then
		return false
	end
	bot:Action_UseAbility(ring)
	return true
end
-- ignoreMana: judge the situation as if the mana were there (used to decide on Soul Ring).
-- What the Blast Off combo deals to one hero (all magical, game files): Blast Off, plus Sticky Bomb
-- when it is ready and there is mana for it after the blast, plus up to 2 Land Mines (the landing
-- triangle; charges and mana permitting). User call: Techies only blasts in to start a fight when
-- this kills someone; otherwise he keeps throwing Sticky Bombs (late game he blasted onto full-HP
-- tanks and died).
function X.ComboDamage()
	local dmg = blastOffAbility:GetSpecialValueInt("damage")
	local mana = bot:GetMana() - blastOffAbility:GetManaCost()
	if
		stickyBombAbility:IsTrained()
		and stickyBombAbility:IsFullyCastable()
		and mana >= stickyBombAbility:GetManaCost()
	then
		dmg = dmg + stickyBombAbility:GetSpecialValueInt("damage")
		mana = mana - stickyBombAbility:GetManaCost()
	end
	if proximityMinesAbility:IsTrained() and not proximityMinesAbility:IsHidden() then
		local cost = proximityMinesAbility:GetManaCost()
		local mines = math.min(X.MineCharges(), 2, cost > 0 and math.floor(mana / cost) or 2)
		dmg = dmg + math.max(0, mines) * proximityMinesAbility:GetSpecialValueInt("damage")
	end
	return dmg
end
-- Allied heroes who can follow up on the target: within 1200 of him, alive, not illusions, not
-- retreating, 30%+ HP. Each counts as 15% of his max HP on top of the combo (user call: alone the
-- combo must kill, with allies near Techies can start a fight that they finish).
local FOLLOW_UP_SHARE = 0.15
function X.FollowUpAllies(target)
	local count = 0
	for _, ally in pairs(Fu.GetNearbyHeroes(bot, 1600, false, BOT_MODE_NONE) or {}) do
		if
			ally ~= bot
			and Fu.IsValidHero(ally)
			and not ally:IsIllusion()
			and GetUnitToUnitDistance(ally, target) <= 1200
			and Fu.GetHP(ally) >= 0.3
			and not Fu.IsRetreating(ally)
		then
			count = count + 1
		end
	end
	return math.min(count, 4)
end
function X.ComboKills(target)
	if not Fu.IsValidHero(target) then
		return false
	end
	local dealt = target:GetActualIncomingDamage(X.ComboDamage(), DAMAGE_TYPE_MAGICAL)
	local followUp = X.FollowUpAllies(target) * FOLLOW_UP_SHARE * target:GetMaxHealth()
	return dealt + followUp >= target:GetHealth()
end
function X.LogBlastSkip(target, why)
	if DotaTime() < (bot._blastSkipLogAt or -99) + 10 or target == nil then
		return
	end
	bot._blastSkipLogAt = DotaTime()
	pcall(
		print,
		string.format(
			"[OHA-TECHIES] t=%.0f blast-skip why=%s target=%s combo=%d dealt=%d allies=%d hp=%d/%d",
			DotaTime(),
			why,
			(string.gsub(target:GetUnitName(), "npc_dota_hero_", "")),
			X.ComboDamage(),
			target:GetActualIncomingDamage(X.ComboDamage(), DAMAGE_TYPE_MAGICAL),
			X.FollowUpAllies(target),
			target:GetHealth(),
			target:GetMaxHealth()
		)
	)
end
function X.ConsiderBlastOff(ignoreMana)
	local ready = ignoreMana and blastOffAbility:IsTrained() and blastOffAbility:GetCooldownTimeRemaining() <= 0
		or blastOffAbility:IsFullyCastable()
	if not ready or blastOffAbility:IsHidden() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local castRange = Fu.GetProperCastRange(false, bot, blastOffAbility:GetCastRange())
	local castPoint = blastOffAbility:GetCastPoint()
	local radius = blastOffAbility:GetSpecialValueInt("radius")
	local flightDuration = blastOffAbility:GetSpecialValueFloat("duration")
	local enemiesInRange = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(enemiesInRange) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and not Fu.IsSuspiciousIllusion(enemyHero)
			and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
			and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
			and not enemyHero:HasModifier("modifier_faceless_void_chronosphere_freeze")
			and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
			and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
			and not enemyHero:HasModifier("modifier_templar_assassin_refraction_absorb")
		then
			-- Stop a channel (TP, ult) even when outnumbered. Only a low Techies checks numbers,
			-- since the landing costs him a share of his current HP.
			if enemyHero:IsChanneling() then
				local alliesNearEnemy = Fu.GetNearbyHeroes(enemyHero, 1200, true, BOT_MODE_NONE)
				local enemiesNearEnemy = Fu.GetNearbyHeroes(enemyHero, 1200, false, BOT_MODE_NONE)
				if
					(hpRatio or 1) >= 0.3
					or alliesNearEnemy ~= nil and enemiesNearEnemy ~= nil and #alliesNearEnemy >= #enemiesNearEnemy
				then
					return BOT_ACTION_DESIRE_HIGH, enemyHero:GetLocation(), "channel"
				end
			end
		end
	end
	if Fu.IsInTeamFight(bot, 1200) then
		local aoeLocation = bot:FindAoELocation(true, true, bot:GetLocation(), castRange, radius, 0, 0)
		local enemiesInRadius = Fu.GetEnemiesNearLoc(aoeLocation.targetloc, radius * 0.8)
		if
			enemiesInRadius ~= nil
			and #enemiesInRadius >= 2
			and not Fu.IsLocationInChrono(Fu.GetCenterOfUnits(enemiesInRadius))
		then
			local kills = false
			for _, enemy in pairs(enemiesInRadius) do
				if X.ComboKills(enemy) then
					kills = true
					break
				end
			end
			if kills then
				return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(enemiesInRadius), "fight"
			end
			X.LogBlastSkip(enemiesInRadius[1], "fight-no-kill")
		end
	end
	if
		isEngaging
		and Fu.IsValidHero(botTarget)
		and Fu.IsInRange(bot, botTarget, castRange)
		and not X.ComboKills(botTarget)
	then
		X.LogBlastSkip(botTarget, "no-kill")
	end
	if isEngaging then
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not botTarget:HasModifier("modifier_faceless_void_chronosphere_freeze")
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
			and X.ComboKills(botTarget)
		then
			local alliesNearTarget = Fu.GetNearbyHeroes(botTarget, 1200, true, BOT_MODE_NONE)
			local enemiesNearTarget = Fu.GetNearbyHeroes(botTarget, 1200, false, BOT_MODE_NONE)
			if alliesNearTarget ~= nil and enemiesNearTarget ~= nil and #alliesNearTarget >= #enemiesNearTarget then
				local targetUnderTower = false
				local delay = castPoint + flightDuration
				local targetTowers = botTarget:GetNearbyTowers(700, false)
				if Fu.IsChasingTarget(bot, botTarget) then
					if Fu.IsInLaningPhase() then
						if enemiesInRange ~= nil and #targetTowers >= 1 then
							targetUnderTower = true
						end
					end
					if not targetUnderTower then
						return BOT_ACTION_DESIRE_HIGH, botTarget:GetExtrapolatedLocation(delay), "chase"
					end
				else
					if Fu.IsInLaningPhase() then
						if enemiesInRange ~= nil and #targetTowers >= 1 then
							targetUnderTower = true
						end
					end
					if not targetUnderTower then
						enemiesNearTarget = Fu.GetEnemiesNearLoc(botTarget:GetLocation(), radius)
						if enemiesNearTarget ~= nil and #enemiesNearTarget >= 1 then
							return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(enemiesNearTarget), "initiate"
						else
							return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation(), "initiate"
						end
					end
				end
			end
		end
	end
	if isRetreating then
		local enemiesInRange = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
		for _, enemyHero in pairs(enemiesInRange) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.IsChasingTarget(enemyHero, bot)
				and not Fu.IsSuspiciousIllusion(enemyHero)
			then
				local alliesNearEnemy = Fu.GetNearbyHeroes(enemyHero, 1200, true, BOT_MODE_NONE)
				local enemiesNearEnemy = Fu.GetNearbyHeroes(enemyHero, 1200, false, BOT_MODE_NONE)
				if
					alliesNearEnemy ~= nil
					and enemiesNearEnemy ~= nil
					and (#enemiesNearEnemy > #alliesNearEnemy or bot:WasRecentlyDamagedByAnyHero(2))
				then
					-- Game 031, 6:59: low and chased, he blasted onto the chaser (last-stand) and stayed
					-- in the fight. Run away (user call); onto the chaser only when the blast kills him.
					if
						Fu.CanCastOnNonMagicImmune(enemyHero)
						and Fu.CanKillTarget(
							enemyHero,
							blastOffAbility:GetSpecialValueInt("damage"),
							DAMAGE_TYPE_MAGICAL
						)
					then
						return BOT_ACTION_DESIRE_HIGH, enemyHero:GetLocation(), "last-stand"
					else
						return BOT_ACTION_DESIRE_HIGH,
							Fu.Site.GetXUnitsTowardsLocation(bot, Fu.GetTeamFountain(), castRange),
							"escape"
					end
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.ConsiderMineFieldSign()
	-- Minefield Sign stays hidden without Scepter but still reports castable. Ordering it
	-- then is refused by the server and freezes Techies in place every think.
	if
		not proximityMinesAbility:IsTrained()
		or minefieldSignAbility:IsHidden()
		or not minefieldSignAbility:IsFullyCastable()
	then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local auraRadius = minefieldSignAbility:GetSpecialValueInt("aura_radius")
	local availableSpots = Techies.GetAvailableSpot()
	MineLocation, MineLocationDistance = Techies.GetClosestSpot(bot, availableSpots)
	if
		MineLocation ~= nil
		and GetUnitToLocationDistance(bot, MineLocation) <= bot:GetCurrentVisionRange()
		and not X.IsEnemyCloserToWardLocation(MineLocation, MineLocationDistance)
	then
		for attempt = 0, 50 do
			local candidateLocation = Fu.GetRandomLocationWithinDist(MineLocation, 0, auraRadius * 3 + 100)
			if IsLocationPassable(candidateLocation) then
				local minesNearby = Fu.GetTechiesMinesInLoc(candidateLocation, auraRadius)
				if #minesNearby >= 3 then
					return BOT_ACTION_DESIRE_HIGH, candidateLocation
				end
			end
			attempt = attempt + 1
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
-- Proximity Mines is charge based (3 charges, one every 15s). Charges left from the shared
-- tracker (the API has no ability-charge read), or 3 before it has a count.
function X.MineCharges()
	return ChargeTracker.Count(bot, proximityMinesAbility) or 3
end
-- Three spots 120 degrees apart around center. At radius 210 they sit ~364 apart, past the
-- 350 minimum mine spacing, and the target in the middle is near full damage from each.
-- Skips spots that are not passable or too close to an existing mine.
-- A spot a mine can actually go: walkable (covers cliffs and map objects), no tree within 120,
-- no building within 250, no mine too close, and 350 from the other spots of this triangle.
function X.MineSpotOk(spot, chosen)
	if not IsLocationPassable(spot) or Techies.IsOtherMinesClose(spot) then
		return false
	end
	for _, other in ipairs(chosen) do
		if (other.x - spot.x) ^ 2 + (other.y - spot.y) ^ 2 < 350 * 350 then
			return false
		end
	end
	for _, tree in pairs(bot:GetNearbyTrees(math.min(1600, GetUnitToLocationDistance(bot, spot) + 200)) or {}) do
		local treeLocation = GetTreeLocation(tree)
		if treeLocation ~= nil and (treeLocation.x - spot.x) ^ 2 + (treeLocation.y - spot.y) ^ 2 < 120 * 120 then
			return false
		end
	end
	for _, list in ipairs({ UNIT_LIST_ALLIED_BUILDINGS, UNIT_LIST_ENEMY_BUILDINGS }) do
		for _, building in pairs(GetUnitList(list) or {}) do
			if building ~= nil and not building:IsNull() and GetUnitToLocationDistance(building, spot) < 250 then
				return false
			end
		end
	end
	return true
end
function X.MineTriangle(center, radius)
	local spots = {}
	if center == nil then
		return spots
	end
	-- Blocked spot (tree, building, cliff): try a slightly turned or shorter/longer spot first.
	local turns = { 0, 20, -20 }
	local radii = { radius, radius - 50, radius + 40 }
	for i = 0, 2 do
		local placed = false
		for _, ringRadius in ipairs(radii) do
			for _, turn in ipairs(turns) do
				local angle = math.rad(90 + 120 * i + turn)
				local spot = center + Vector(math.cos(angle) * ringRadius, math.sin(angle) * ringRadius, 0)
				if X.MineSpotOk(spot, spots) then
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
function X.LogTechies(kind, mines, center)
	bot._techiesLogAt = bot._techiesLogAt or {}
	if DotaTime() < (bot._techiesLogAt[kind] or -999) then
		return
	end
	bot._techiesLogAt[kind] = DotaTime() + 5
	pcall(
		print,
		string.format(
			"[OHA-TECHIES] t=%.0f %s pid=%d mines=%d charges=%d at=%.0f,%.0f mp=%.2f",
			DotaTime(),
			kind,
			bot:GetPlayerID(),
			mines,
			X.MineCharges(),
			center and center.x or 0,
			center and center.y or 0,
			Fu.GetMP(bot)
		)
	)
end
-- A mine spot of the triangle around the last Blast Off landing, 1.75s to 3.5s after the order
-- (1s cast point and 0.75s flight, Valve data, then the stun). Spots already mined are skipped.
-- Every mine order, with the exact spot and its distance from Techies. The engine rejects some
-- with "Cast failed, but not sure why! (techies_land_mines, target loc ..., result: 24)"; matching
-- those coordinates against these lines shows whether the distance is the problem.
function X.OrderMine(loc, kind)
	if loc == nil then
		return
	end
	pcall(
		print,
		string.format(
			"[OHA-TECHIES] t=%.0f mine-order kind=%s at=%.2f,%.2f dist=%d range=%d charges=%d",
			DotaTime(),
			kind,
			loc.x,
			loc.y,
			math.floor(GetUnitToLocationDistance(bot, loc)),
			proximityMinesAbility:GetCastRange(),
			X.MineCharges()
		)
	)
	pcall(ChargeTracker.Issued, bot, proximityMinesAbility)
	bot:Action_UseAbilityOnLocation(proximityMinesAbility, loc)
end
-- When Blast Off lands: its cast point plus the flight.
local function BlastLandAt()
	if bot._blastAt == nil then
		return nil
	end
	local flight = blastOffAbility:GetSpecialValueFloat("duration")
	if flight == nil or flight <= 0 then
		flight = 0.75
	end
	return bot._blastAt + blastOffAbility:GetCastPoint() + flight
end
-- Force Staff out after the landing combo (Veil, mines, Sticky Bomb come first in the order),
-- once per Blast Off, from 0.5s to 6s after landing, when an enemy hero is within 800 and he is
-- below 60% HP or two enemy heroes are on him. Force Staff pushes 600 the way he faces (Valve
-- data), so he turns toward the fountain first. The shared rule only pushes a hero already in
-- retreat mode and facing home, which he rarely is right after landing.
function X.ConsiderPostBlastEscape()
	local land = BlastLandAt()
	if land == nil or DotaTime() < land + 0.5 or DotaTime() > land + 6 or bot._forceBlastAt == bot._blastAt then
		return false
	end
	local slot = bot:FindItemSlot("item_force_staff")
	if slot < 0 or slot > 5 then
		slot = bot:FindItemSlot("item_hurricane_pike")
	end
	if slot < 0 or slot > 5 then
		return false
	end
	local force = bot:GetItemInSlot(slot)
	if force == nil or not force:IsFullyCastable() or bot:IsRooted() then
		return false
	end
	local foes = 0
	for _, enemy in pairs(Fu.GetNearbyHeroes(bot, 800, true, BOT_MODE_NONE) or {}) do
		if Fu.IsValidHero(enemy) and not Fu.IsSuspiciousIllusion(enemy) then
			foes = foes + 1
		end
	end
	if foes == 0 or (Fu.GetHP(bot) >= 0.6 and foes < 2) then
		return false
	end
	local home = GetTeam() == TEAM_RADIANT and Vector(-7172, -6652, 0) or Vector(6982, 6422, 0)
	local me = bot:GetLocation()
	local dx, dy = home.x - me.x, home.y - me.y
	local len = math.max(1, math.sqrt(dx * dx + dy * dy))
	local landing = Vector(me.x + dx / len * 600, me.y + dy / len * 600, me.z)
	if not IsLocationPassable(landing) then
		return false
	end
	if not bot:IsFacingLocation(home, 25) then
		bot:Action_MoveToLocation(Vector(me.x + dx / len * 200, me.y + dy / len * 200, me.z))
		return true
	end
	bot._forceBlastAt = bot._blastAt
	X.LogTechies(string.format("post-blast-force foes=%d hp=%.2f", foes, Fu.GetHP(bot)), 0, landing)
	bot:Action_UseAbilityOnEntity(force, bot)
	return true
end
-- Veil of Discord right after landing, once per Blast Off, with an enemy hero in its radius.
function X.ConsiderPostBlastVeil()
	local land = BlastLandAt()
	if land == nil or DotaTime() < land or DotaTime() > land + 2.5 or bot._veilBlastAt == bot._blastAt then
		return nil
	end
	local slot = bot:FindItemSlot("item_veil_of_discord")
	if slot < 0 or slot > 5 then
		return nil
	end
	local veil = bot:GetItemInSlot(slot)
	if veil == nil or not veil:IsFullyCastable() then
		return nil
	end
	local radius = veil:GetSpecialValueInt("debuff_radius")
	if radius == nil or radius <= 0 then
		radius = 600
	end
	for _, enemy in pairs(Fu.GetNearbyHeroes(bot, radius, true, BOT_MODE_NONE) or {}) do
		if Fu.IsValidHero(enemy) and not Fu.IsSuspiciousIllusion(enemy) then
			return veil
		end
	end
	return nil
end
-- Sticky Bomb after the post-blast mine triangle (mines spent or not castable), once per Blast
-- Off, on the nearest enemy hero in range, up to 5s after the cast.
function X.ConsiderPostBlastSticky()
	if bot._blastAt == nil or DotaTime() - bot._blastAt < 1.75 or DotaTime() - bot._blastAt > 5 then
		return nil
	end
	if
		bot._stickyBlastAt == bot._blastAt
		or not stickyBombAbility:IsTrained()
		or not stickyBombAbility:IsFullyCastable()
	then
		return nil
	end
	local range = stickyBombAbility:GetCastRange() + 100
	local best, bestDist = nil, math.huge
	for _, enemy in pairs(Fu.GetNearbyHeroes(bot, range, true, BOT_MODE_NONE) or {}) do
		if Fu.IsValidHero(enemy) and Fu.CanCastOnNonMagicImmune(enemy) and not Fu.IsSuspiciousIllusion(enemy) then
			local dist = GetUnitToUnitDistance(bot, enemy)
			if dist < bestDist then
				best, bestDist = enemy, dist
			end
		end
	end
	if best == nil then
		return nil
	end
	return best:GetExtrapolatedLocation(0.5)
end
function X.ConsiderPostBlastSign()
	if bot._blastAt == nil or bot._signBlastAt == bot._blastAt then
		return false
	end
	local land = BlastLandAt()
	if land == nil or DotaTime() < land or DotaTime() > land + 2 then
		return false
	end
	if
		not bot:HasScepter()
		or minefieldSignAbility:IsHidden()
		or not minefieldSignAbility:IsFullyCastable()
		or not proximityMinesAbility:IsTrained()
	then
		return false
	end
	return true
end
function X.ConsiderPostBlastMines()
	if bot._blastAt == nil or bot._blastLoc == nil or DotaTime() - bot._blastAt > 3.5 then
		return nil
	end
	if
		DotaTime() - bot._blastAt < 1.75
		or not proximityMinesAbility:IsTrained()
		or proximityMinesAbility:IsHidden()
		or not proximityMinesAbility:IsFullyCastable()
	then
		return nil
	end
	-- Around Techies himself: he has just landed among the stunned enemies, so no walking.
	return X.MineTriangle(bot:GetLocation(), 210)[1]
end
function X.ConsiderProximityMines()
	if not proximityMinesAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local castRange = Fu.GetProperCastRange(false, bot, proximityMinesAbility:GetCastRange())
	local searchRadius = 400
	local manaCost = proximityMinesAbility:GetManaCost()
	-- A disabled enemy in reach: build the triangle around it, one mine per think (cast point 0).
	if
		Fu.IsValidHero(botTarget)
		and Fu.IsDisabled(botTarget)
		and Fu.CanCastOnNonMagicImmune(botTarget)
		and not Fu.IsSuspiciousIllusion(botTarget)
		and GetUnitToUnitDistance(bot, botTarget) <= castRange + 210
		and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
	then
		local spots = X.MineTriangle(botTarget:GetLocation(), 210)
		if spots[1] ~= nil and GetUnitToLocationDistance(bot, spots[1]) <= castRange + 100 then
			X.LogTechies("triangle", #spots, botTarget:GetLocation())
			return BOT_ACTION_DESIRE_HIGH, spots[1]
		end
	end
	if isEngaging then
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange + searchRadius)
			and not Fu.IsChasingTarget(bot, botTarget)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
			and not botTarget:HasModifier("modifier_templar_assassin_refraction_absorb")
		then
			local alliesNearTarget = Fu.GetNearbyHeroes(botTarget, 1200, true, BOT_MODE_NONE)
			local enemiesNearTarget = Fu.GetNearbyHeroes(botTarget, 1200, false, BOT_MODE_NONE)
			if
				Fu.CanKillTarget(botTarget, twoMinesDamage, DAMAGE_TYPE_MAGICAL)
				or alliesNearTarget ~= nil and enemiesNearTarget ~= nil and #alliesNearTarget >= #enemiesNearTarget
			then
				enemiesNearTarget = Fu.GetEnemiesNearLoc(botTarget:GetLocation(), Techies.nMinMineDistance)
				if enemiesNearTarget ~= nil and #enemiesNearTarget >= 1 then
					local placeScore, placeLocation =
						Techies.GetGoodPlaceForMiningNear(Fu.GetCenterOfUnits(enemiesNearTarget))
					if placeScore > 0 then
						return BOT_ACTION_DESIRE_HIGH, placeLocation
					end
				else
					local placeScore, placeLocation = Techies.GetGoodPlaceForMiningNear(botTarget:GetLocation())
					if placeScore > 0 then
						return BOT_ACTION_DESIRE_HIGH, placeLocation
					end
				end
			end
		end
	end
	local enemiesInRange = Fu.GetNearbyHeroes(bot, castRange + searchRadius, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(enemiesInRange) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and Fu.GetManaAfter(manaCost) > 0.5
			and not isRetreating
			and hpRatio > Fu.GetHP(enemyHero)
			and not Fu.IsSuspiciousIllusion(enemyHero)
			and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
			and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
			and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
			and not enemyHero:HasModifier("modifier_templar_assassin_refraction_absorb")
		then
			local alliesNearEnemy = Fu.GetNearbyHeroes(enemyHero, 1200, true, BOT_MODE_NONE)
			local enemiesNearEnemy = Fu.GetNearbyHeroes(enemyHero, 1200, false, BOT_MODE_NONE)
			if alliesNearEnemy ~= nil and enemiesNearEnemy ~= nil and #alliesNearEnemy >= #enemiesNearEnemy then
				local mineSpot = enemyHero:GetExtrapolatedLocation(0.5)
				if GetUnitToLocationDistance(bot, mineSpot) < castRange + 100 then
					return BOT_ACTION_DESIRE_HIGH, mineSpot
				end
				mineSpot = Fu.Utils.GetOffsetLocationTowardsTargetLocation(
					bot:GetLocation(),
					enemyHero:GetLocation(),
					castRange
				)
				if GetUnitToLocationDistance(bot, mineSpot) < castRange + 100 then
					return BOT_ACTION_DESIRE_HIGH, mineSpot
				end
			end
		end
	end
	if isRetreating then
		local enemiesInRange = Fu.GetNearbyHeroes(bot, 1000, true, BOT_MODE_NONE)
		for _, enemyHero in pairs(enemiesInRange) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.IsChasingTarget(enemyHero, bot)
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and not Fu.IsDisabled(enemyHero)
			then
				local alliesNearEnemy = Fu.GetNearbyHeroes(enemyHero, 1200, true, BOT_MODE_NONE)
				local enemiesNearEnemy = Fu.GetNearbyHeroes(enemyHero, 1200, false, BOT_MODE_NONE)
				if
					alliesNearEnemy ~= nil
					and enemiesNearEnemy ~= nil
					and (#enemiesNearEnemy > #alliesNearEnemy or bot:WasRecentlyDamagedByAnyHero(1))
					and Fu.CanKillTarget(enemyHero, mineDamage, DAMAGE_TYPE_MAGICAL)
				then
					local mineSpot = (bot:GetLocation() + enemyHero:GetLocation()) / 2
					if GetUnitToLocationDistance(bot, mineSpot) <= castRange then
						return BOT_ACTION_DESIRE_HIGH, mineSpot
					else
						return BOT_ACTION_DESIRE_HIGH, bot:GetLocation()
					end
				end
			end
		end
	end
	if Fu.IsPushing(bot) then
		local enemyTowers = bot:GetNearbyTowers(1200, true)
		if
			enemyTowers ~= nil
			and #enemyTowers >= 1
			and Fu.IsValidBuilding(enemyTowers[1])
			and Fu.CanBeAttacked(enemyTowers[1])
		then
			local alliesNearTower = Fu.GetAlliesNearLoc(enemyTowers[1]:GetLocation(), bot:GetAttackRange())
			local enemiesNearTower = Fu.GetEnemiesNearLoc(enemyTowers[1]:GetLocation(), 1600)
			if
				alliesNearTower ~= nil
				and #alliesNearTower >= 1
				and enemiesNearTower ~= nil
				and #enemiesNearTower == 0
			then
				-- Mines deal 30% to buildings. Ring the tower with the 350-spaced triangle
				-- instead of one random spot that blocks the next mine.
				local spots = X.MineTriangle(enemyTowers[1]:GetLocation(), 250)
				if spots[1] ~= nil then
					X.LogTechies("tower", #spots, enemyTowers[1]:GetLocation())
					return BOT_ACTION_DESIRE_HIGH, spots[1]
				end
			end
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if
			Fu.IsRoshan(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, searchRadius)
			and isAttacking
			and not Techies.IsOtherMinesClose(botTarget:GetLocation())
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if
			Fu.IsTormentor(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and isAttacking
			and not Techies.IsOtherMinesClose(botTarget:GetLocation())
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	if Fu.IsFarming(bot) and Fu.GetManaAfter(manaCost) > 0.3 then
		local neutralCreeps = bot:GetNearbyNeutralCreeps(searchRadius)
		if neutralCreeps ~= nil then
			if #neutralCreeps > 1 then
				return BOT_ACTION_DESIRE_HIGH, neutralCreeps[1]:GetLocation()
			end
		end
		local laneCreeps = bot:GetNearbyLaneCreeps(searchRadius, true)
		if laneCreeps ~= nil then
			if #laneCreeps > 1 then
				return BOT_ACTION_DESIRE_HIGH, laneCreeps[1]:GetLocation()
			end
		end
	end
	-- No idle mining at random map spots: it spent mana on mines nobody walked into.
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.IsSuitableToPlaceMine()
	local nearbyEnemies = Fu.GetEnemiesNearLoc(bot:GetLocation(), 2000)
	local activeMode = bot:GetActiveMode()
	local teamFightLocation = Fu.GetTeamFightLocation(bot)
	if
		activeMode == BOT_MODE_RETREAT and bot:GetActiveModeDesire() > BOT_MODE_DESIRE_HIGH
		or activeMode == BOT_MODE_RUNE and DotaTime() > 0
		or activeMode == BOT_MODE_DEFEND_ALLY
		or isEngaging and bot:GetActiveModeDesire() > BOT_MODE_DESIRE_MODERATE
		or Fu.IsPushing(bot) and bot:GetActiveModeDesire() > BOT_MODE_DESIRE_MODERATE
		or Fu.IsDefending(bot)
		or Fu.IsDoingRoshan(bot)
		or Fu.IsDoingTormentor(bot)
		or bot:GetLevel() <= 6
		or teamFightLocation ~= nil
		or nearbyEnemies ~= nil and #nearbyEnemies >= 1
	then
		return false
	end
	return true
end
function X.IsIBecameTheTarget(units)
	for _, unit in pairs(units) do
		if unit ~= nil and unit:CanBeSeen() and unit:GetAttackTarget() == bot then
			return true
		end
	end
	return false
end
function X.IsEnemyCloserToWardLocation(location, distance)
	for _, playerId in pairs(GetTeamPlayers(GetOpposingTeam())) do
		local lastSeenInfo = GetHeroLastSeenInfo(playerId)
		if lastSeenInfo ~= nil then
			local lastSeen = lastSeenInfo[1]
			if
				lastSeen ~= nil
				and lastSeen.time_since_seen < 5
				and Fu.GetDistance(lastSeen.location, location) < distance
			then
				return true
			end
		end
	end
	return false
end
-- Tazer can report castable while hidden (seen with two Techies on one team). Every order on it
-- is then refused, so nothing that needs it may count on it.
function X.TazerUsable()
	if not reactiveTazerAbility:IsFullyCastable() then
		return false
	end
	if reactiveTazerAbility:IsHidden() then
		if DotaTime() >= (bot._tazerHiddenLogAt or -999) then
			bot._tazerHiddenLogAt = DotaTime() + 30
			pcall(
				print,
				string.format(
					"[OHA-TECHIES] t=%.0f tazer-hidden pid=%d lvl=%d stopHidden=%s buff=%s",
					DotaTime(),
					bot:GetPlayerID(),
					reactiveTazerAbility:GetLevel(),
					tostring(tazerStopAbility == nil or tazerStopAbility:IsNull() or tazerStopAbility:IsHidden()),
					tostring(bot:HasModifier("modifier_techies_reactive_tazer"))
				)
			)
		end
		return false
	end
	return true
end
-- Blast Off and the Tazer are both up with mana for both, and the target is about to be in
-- Blast Off range. Only then is the Tazer kept back to follow the Blast Off; it never holds
-- the Blast Off itself, and it is not kept when there is no target close.
function X.ComboReady()
	if
		not (
			blastOffAbility:IsFullyCastable()
			and not blastOffAbility:IsHidden()
			and reactiveTazerAbility:IsFullyCastable()
			and not reactiveTazerAbility:IsHidden()
			and bot:GetMana() >= reactiveTazerAbility:GetManaCost() + blastOffAbility:GetManaCost()
		)
	then
		return false
	end
	local range = Fu.GetProperCastRange(false, bot, blastOffAbility:GetCastRange()) + 300
	-- No combo without a kill: the Tazer is not held back for one that will not happen.
	return Fu.IsValidTarget(botTarget) and GetUnitToUnitDistance(bot, botTarget) <= range and X.ComboKills(botTarget)
end
return X
