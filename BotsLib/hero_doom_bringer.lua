-- [OHA-DOOM] logs off: the behaviour they traced works (game 029).
-- Accidental globals made file-local (#13): every bot shares one Lua state, so these were shared.
local DEVOUR_ABILITIES
local print = function() end
-- Doom Bringer: skill build, item build, and ability use for this hero.
local X = {}
local bot = GetBot()
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local AbilityContext = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local Minion = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local sTalentList = Fu.Skill.GetTalentList(bot)
local sAbilityList = Fu.Skill.GetAbilityList(bot)
local sRole = Fu.Item.GetRoleItemsBuyList(bot)
local tTalentTreeList = {
	{ ["t25"] = { 0, 10 }, ["t20"] = { 0, 10 }, ["t15"] = { 0, 10 }, ["t10"] = { 10, 0 } },
	{ ["t25"] = { 0, 10 }, ["t20"] = { 0, 10 }, ["t15"] = { 0, 10 }, ["t10"] = { 10, 0 } },
}
local tAllAbilityBuildList =
	{ { 1, 2, 1, 2, 1, 6, 2, 2, 1, 3, 6, 3, 3, 3, 6 }, { 2, 1, 2, 3, 2, 6, 2, 1, 1, 1, 6, 3, 3, 3, 6 } }
local nAbilityBuildList
local nTalentBuildList
if sRole == "pos_2" then
	nAbilityBuildList = tAllAbilityBuildList[1]
	nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList[1])
else
	nAbilityBuildList = tAllAbilityBuildList[2]
	nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList[2])
end
local sUtility = "item_team_aura"
local sRoleItemsBuyList = {}
sRoleItemsBuyList["pos_2"] = {
	"item_tango",
	"item_double_branches",
	"item_quelling_blade",
	"item_magic_stick",
	"item_bottle",
	"item_magic_wand",
	"item_helm_of_iron_will",
	"item_boots",
	"item_phase_boots",
	"item_shivas_guard",
	"item_blink",
	"item_black_king_bar",
	"item_octarine_core",
	"item_travel_boots",
	"item_aghanims_shard",
	"item_overwhelming_blink",
	"item_refresher",
	"item_travel_boots_2",
	"item_ultimate_scepter_2",
	"item_moon_shard",
}
sRoleItemsBuyList["pos_3"] = {
	"item_tango",
	"item_gauntlets",
	"item_double_branches",
	"item_quelling_blade",
	"item_circlet",
	"item_bracer",
	"item_magic_wand",
	"item_helm_of_iron_will",
	"item_boots",
	"item_phase_boots",
	"item_shivas_guard",
	"item_blink",
	"item_black_king_bar",
	"item_octarine_core",
	sUtility,
	"item_aghanims_shard",
	"item_overwhelming_blink",
	"item_ultimate_scepter",
	"item_ultimate_scepter_2",
	"item_moon_shard",
}
sRoleItemsBuyList["pos_1"] = sRoleItemsBuyList["pos_3"]
sRoleItemsBuyList["pos_4"] = sRoleItemsBuyList["pos_3"]
sRoleItemsBuyList["pos_5"] = sRoleItemsBuyList["pos_3"]
X["sBuyList"] = sRoleItemsBuyList[sRole]
X["sSellList"] = { "item_power_treads", "item_quelling_blade" }
if Fu.Role.IsPvNMode() or Fu.Role.IsAllShadow() then
	X["sBuyList"], X["sSellList"] = { "PvN_antimage" }, {}
end
nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"] =
	Fu.SetUserHeroInit(nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"])
X["sSkillList"] = Fu.Skill.GetSkillList(sAbilityList, nAbilityBuildList, sTalentList, nTalentBuildList)
X["bDeafaultAbility"] = false
X["bDeafaultItem"] = false
function X.MinionThink(minionUnit)
	Minion.MinionThink(minionUnit)
end
local devourAbility = SafeAbility(bot:GetAbilityByName("doom_bringer_devour"), "doom_bringer_devour", "doom_bringer")
local scorchedEarthAbility =
	SafeAbility(bot:GetAbilityByName("doom_bringer_scorched_earth"), "doom_bringer_scorched_earth", "doom_bringer")
local infernalBladeAbility =
	SafeAbility(bot:GetAbilityByName("doom_bringer_infernal_blade"), "doom_bringer_infernal_blade", "doom_bringer")
local doomAbility = SafeAbility(bot:GetAbilityByName("doom_bringer_doom"), "doom_bringer_doom", "doom_bringer")
local empty1Ability = SafeAbility(bot:GetAbilityByName("doom_bringer_empty1"), "doom_bringer_empty1", "doom_bringer")
local empty2Ability = SafeAbility(bot:GetAbilityByName("doom_bringer_empty2"), "doom_bringer_empty2", "doom_bringer")
-- datafeed: special_bonus_unique_doom_2 is no longer a Doom talent (Ancient Devour moved to the Shard)
local devourDesire, devourTarget
local scorchedEarthDesire
local infernalBladeDesire, infernalBladeTarget
local doomDesire, doomTarget
local empty1Desire, empty1Target
local empty2Desire, empty2Target
local botTarget
local isGoingOnSomeone
local isRetreating
local isAttacking
function X.SkillsComplement()
	if Fu.CanNotUseAbility(bot) then
		return
	end
	local context = AbilityContext.Build(bot)
	isGoingOnSomeone = context.isEngaging
	isRetreating = context.isRetreating
	isAttacking = Fu.IsAttacking(bot)
	botTarget = context.target
	doomDesire, doomTarget = X.ConsiderDoom()
	if doomDesire > 0 then
		bot:Action_UseAbilityOnEntity(doomAbility, doomTarget)
		return
	end
	infernalBladeDesire, infernalBladeTarget = X.ConsiderInfernalBlade()
	if infernalBladeDesire > 0 then
		bot:Action_UseAbilityOnEntity(infernalBladeAbility, infernalBladeTarget)
		return
	end
	-- Abilities taken with Devour. ConsiderDevourAbility existed but was never called, so stolen
	-- creep skills went unused. The slots change after each Devour, so look them up by name.
	for slot = 0, 10 do
		local stolen = bot:GetAbilityInSlot(slot)
		if stolen ~= nil and not stolen:IsNull() and X.IsStolenAbility(stolen) then
			local want, target, kind
			if DEVOUR_ABILITIES[stolen:GetName()] then
				want, target, kind = X.ConsiderDevourAbility(stolen)
			else
				want, target, kind = X.ConsiderGenericDevourAbility(stolen)
			end
			if want ~= nil and want > 0 then
				if kind == "unit" and target ~= nil then
					bot:Action_UseAbilityOnEntity(stolen, target)
				elseif kind == "point" and target ~= nil then
					bot:Action_UseAbilityOnLocation(stolen, target:GetLocation())
				else
					bot:Action_UseAbility(stolen)
				end
				return
			end
		end
	end
	local scorchWhy
	scorchedEarthDesire, scorchWhy = X.ConsiderScorchedEarth()
	if scorchedEarthDesire > 0 then
		pcall(
			print,
			string.format(
				"[OHA-DOOM] t=%.0f scorched why=%s hp=%.2f",
				DotaTime(),
				tostring(scorchWhy or "?"),
				Fu.GetHP(bot)
			)
		)
		bot:Action_UseAbility(scorchedEarthAbility)
		return
	end
	devourDesire, devourTarget = X.ConsiderDevour()
	if devourDesire > 0 then
		bot:Action_UseAbilityOnEntity(devourAbility, devourTarget)
		return
	end
end
function X.ConsiderDevour()
	if not devourAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	-- Game data: creep_level 4/5/6/6 is the highest creep level Devour can eat at each skill level;
	-- ancients only with the Shard (can_target_ancient). Old code took the most-HP neutral with no level
	-- check (refused order every think when it was above the cap) or simply the first creep listed.
	local maxCreepLevel = devourAbility:GetSpecialValueInt("creep_level")
	if maxCreepLevel <= 0 then
		maxCreepLevel = ({ 4, 5, 6, 6 })[math.max(1, math.min(4, devourAbility:GetLevel()))]
	end
	local canAncient = devourAbility:GetSpecialValueInt("can_target_ancient") > 0 or Fu.HasAghanimsShard(bot)
	if not isRetreating then
		local enemyTowers = bot:GetNearbyTowers(1600, true)
		-- Lane creeps next to an enemy tower are skipped, as before.
		local candidateCreeps = {}
		for _, creep in pairs(bot:GetNearbyCreeps(1200, true) or {}) do
			if
				Fu.IsValid(creep)
				and (
					creep:GetTeam() == TEAM_NEUTRAL
					or enemyTowers == nil
					or #enemyTowers == 0
					or not Fu.IsValidBuilding(enemyTowers[1])
					or GetUnitToUnitDistance(creep, enemyTowers[1]) > 700
				)
			then
				candidateCreeps[#candidateCreeps + 1] = creep
			end
		end
		-- Highest level, then highest max HP, within the level cap.
		local bestCreep = Fu.GetBestCreepToEat(candidateCreeps, maxCreepLevel, canAncient)
		if bestCreep ~= nil then
			return BOT_ACTION_DESIRE_HIGH, bestCreep
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function X.ConsiderScorchedEarth()
	if not scorchedEarthAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
	end
	-- Valve data: 666 radius damage to enemies; Doom alone gets +7-10% move speed and +6.66 HP
	-- regen, for 10-16s. So it is both a chase and an escape spell.
	local radius = scorchedEarthAbility:GetSpecialValueInt("radius")
	if isGoingOnSomeone then
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
			and not botTarget:HasModifier("modifier_skeleton_king_reincarnation_scepter_active")
		then
			local allyHeroes = Fu.GetNearbyHeroes(botTarget, 1200, true, BOT_MODE_NONE)
			local enemyHeroes = Fu.GetNearbyHeroes(botTarget, 1200, false, BOT_MODE_NONE)
			if allyHeroes ~= nil and enemyHeroes ~= nil and #allyHeroes >= #enemyHeroes then
				-- In the burn: damage. Up to 1200 and running from him: the speed closes the gap
				-- (it used to need the target inside 816).
				if Fu.IsInRange(bot, botTarget, radius + 150) then
					return BOT_ACTION_DESIRE_HIGH, "chase-burn"
				end
				if Fu.IsInRange(bot, botTarget, 1200) and Fu.IsChasingTarget(bot, botTarget) then
					return BOT_ACTION_DESIRE_HIGH, "chase-speed"
				end
			end
		end
	end
	-- Escape: speed and regen. Any enemy hero chasing within 1200, or hit by a hero in the last
	-- 3s. It used to need retreat desire 0.75+, the chaser inside 866, and either being
	-- outnumbered by 2 or hit in the last 2s.
	if isRetreating then
		if bot:WasRecentlyDamagedByAnyHero(3) then
			return BOT_ACTION_DESIRE_HIGH, "escape-hit"
		end
		for _, enemyHero in pairs(Fu.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE) or {}) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.IsChasingTarget(enemyHero, bot)
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and not Fu.IsDisabled(enemyHero)
			then
				return BOT_ACTION_DESIRE_HIGH, "escape-chased"
			end
		end
		if Fu.GetHP(bot) < 0.4 and #(Fu.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE) or {}) > 0 then
			return BOT_ACTION_DESIRE_HIGH, "escape-low-hp"
		end
	end
	if Fu.IsFarming(bot) then
		local enemyCreeps = bot:GetNearbyCreeps(radius, true)
		if
			-- fix: tested an undefined global (nEnemyLaneCreeps), so farming never used Scorched Earth
			enemyCreeps ~= nil
			and (#enemyCreeps >= 3 or #enemyCreeps >= 2 and enemyCreeps[1]:IsAncientCreep())
			and Fu.CanBeAttacked(enemyCreeps[1])
			and isAttacking
			and Fu.GetManaAfter(scorchedEarthAbility:GetManaCost()) * bot:GetMana()
				> doomAbility:GetManaCost() * 1.75
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if
			Fu.IsRoshan(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, radius)
			and isAttacking
			and Fu.GetManaAfter(scorchedEarthAbility:GetManaCost()) * bot:GetMana() > doomAbility:GetManaCost() * 2
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if
			Fu.IsTormentor(botTarget)
			and Fu.IsInRange(bot, botTarget, radius)
			and isAttacking
			and Fu.GetManaAfter(scorchedEarthAbility:GetManaCost()) * bot:GetMana() > doomAbility:GetManaCost() * 2
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderInfernalBlade()
	if not infernalBladeAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castRange = infernalBladeAbility:GetCastRange()
	local burnDamage = infernalBladeAbility:GetSpecialValueInt("burn_damage")
	-- datafeed: burn_damage_pct is fractional (0.5/1.75/3/4.25), GetSpecialValueInt truncated it
	local burnDamagePct = infernalBladeAbility:GetSpecialValueFloat("burn_damage_pct") / 100
	local burnDuration = infernalBladeAbility:GetSpecialValueInt("burn_duration")
	local enemiesInRange = Fu.GetNearbyHeroes(bot, 700, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(enemiesInRange) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and Fu.CanCastOnTargetAdvanced(enemyHero)
			and not Fu.IsSuspiciousIllusion(enemyHero)
		then
			local towersNearEnemy = enemyHero:GetNearbyTowers(700, false)
			-- A TP is checked by its modifier too, as everywhere else in the project: IsChanneling()
			-- alone missed an enemy TP in range at 32:30.
			if enemyHero:IsChanneling() or enemyHero:HasModifier("modifier_teleporting") then
				if not Fu.IsInLaningPhase() or towersNearEnemy ~= nil and #towersNearEnemy == 0 then
					return BOT_ACTION_DESIRE_HIGH, enemyHero
				end
			end
			if
				Fu.WillKillTarget(
					enemyHero,
					burnDamage + enemyHero:GetMaxHealth() * burnDamagePct,
					DAMAGE_TYPE_MAGICAL,
					burnDuration
				)
				and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
				and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
				and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
				and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
				and not enemyHero:HasModifier("modifier_skeleton_king_reincarnation_scepter_active")
				and not enemyHero:HasModifier("modifier_templar_assassin_refraction_absorb")
			then
				if Fu.IsInLaningPhase() then
					if towersNearEnemy ~= nil and #towersNearEnemy == 0 then
						return BOT_ACTION_DESIRE_HIGH, enemyHero
					end
				else
					return BOT_ACTION_DESIRE_HIGH, enemyHero
				end
			end
		end
	end
	if isGoingOnSomeone then
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.CanCastOnTargetAdvanced(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange + 150)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not Fu.IsDisabled(botTarget)
			and not botTarget:HasModifier("modifier_enigma_black_hole_pull")
			and not botTarget:HasModifier("modifier_faceless_void_chronosphere_freeze")
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
			and not botTarget:HasModifier("modifier_skeleton_king_reincarnation_scepter_active")
		then
			local allyHeroes = Fu.GetNearbyHeroes(botTarget, 1200, true, BOT_MODE_NONE)
			local enemyHeroes = Fu.GetNearbyHeroes(botTarget, 1200, false, BOT_MODE_NONE)
			if allyHeroes ~= nil and enemyHeroes ~= nil and #allyHeroes >= #enemyHeroes then
				return BOT_ACTION_DESIRE_HIGH, botTarget
			end
		end
	end
	if isRetreating then
		local enemyHeroes = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
		for _, enemyHero in pairs(enemyHeroes) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
				and Fu.IsChasingTarget(enemyHero, bot)
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and not Fu.IsDisabled(enemyHero)
				and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
			then
				local allyHeroes = Fu.GetNearbyHeroes(enemyHero, 1200, true, BOT_MODE_NONE)
				local enemiesNearChaser = Fu.GetNearbyHeroes(enemyHero, 1200, false, BOT_MODE_NONE)
				if
					allyHeroes ~= nil
					and enemiesNearChaser ~= nil
					and (#enemiesNearChaser > #allyHeroes or bot:WasRecentlyDamagedByAnyHero(2))
				then
					return BOT_ACTION_DESIRE_HIGH, enemyHero
				end
			end
		end
	end
	if Fu.IsFarming(bot) then
		local neutralCreeps = bot:GetNearbyNeutralCreeps(castRange + 150)
		if neutralCreeps ~= nil and #neutralCreeps >= 1 then
			local mostHpCreep = Fu.GetMostHpUnit(neutralCreeps)
			if
				Fu.IsValid(mostHpCreep)
				and Fu.GetManaAfter(scorchedEarthAbility:GetManaCost()) * bot:GetMana() > doomAbility:GetManaCost()
				and not Fu.IsOtherAllysTarget(mostHpCreep)
			then
				return BOT_ACTION_DESIRE_HIGH, mostHpCreep
			end
		end
	end
	if Fu.IsLaning(bot) then
		local nEnemyLaneCreeps = bot:GetNearbyLaneCreeps(castRange + 75, true)
		for _, creep in pairs(nEnemyLaneCreeps) do
			if
				Fu.IsValid(creep)
				and Fu.CanBeAttacked(creep)
				and (Fu.IsKeyWordUnit("ranged", creep) or Fu.IsKeyWordUnit("siege", creep) or Fu.IsKeyWordUnit(
					"flagbearer",
					creep
				))
				and creep:GetHealth() <= burnDamage
			then
				local enemiesNearby = Fu.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE)
				if
					enemiesNearby ~= nil
					and #enemiesNearby >= 1
					and GetUnitToUnitDistance(creep, enemiesNearby[1]) < 500
				then
					return BOT_ACTION_DESIRE_HIGH, creep
				end
			end
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if Fu.IsRoshan(botTarget) and Fu.IsInRange(bot, botTarget, castRange) and isAttacking then
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, castRange) and isAttacking then
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function X.ConsiderDoom()
	if not doomAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local doomDuration = doomAbility:GetSpecialValueInt("duration")
	if isGoingOnSomeone then
		local bestTarget = nil
		local highestDamage = 0
		local enemiesInRange = Fu.GetNearbyHeroes(bot, 1000, true, BOT_MODE_NONE)
		for _, enemyHero in pairs(enemiesInRange) do
			if
				Fu.IsValid(enemyHero)
				and Fu.CanCastOnMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and not Fu.IsDisabled(enemyHero)
				and not Fu.IsHaveAegis(enemyHero)
				and not enemyHero:HasModifier("modifier_doom_bringer_doom")
				and not enemyHero:HasModifier("modifier_enigma_black_hole_pull")
				and not enemyHero:HasModifier("modifier_faceless_void_chronosphere_freeze")
				and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
				and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
				and not enemyHero:HasModifier("modifier_skeleton_king_reincarnation_scepter_active")
			then
				local allyHeroes = Fu.GetNearbyHeroes(enemyHero, 1600, true, BOT_MODE_NONE)
				local enemyHeroes = Fu.GetNearbyHeroes(enemyHero, 1600, false, BOT_MODE_NONE)
				if allyHeroes ~= nil and enemyHeroes ~= nil and #allyHeroes >= #enemyHeroes then
					local estimatedDamage = enemyHero:GetEstimatedDamageToTarget(false, bot, 3.0, DAMAGE_TYPE_ALL)
					if highestDamage < estimatedDamage then
						highestDamage = estimatedDamage
						bestTarget = enemyHero
					end
				end
			end
		end
		if bestTarget ~= nil then
			local allyHeroes = Fu.GetNearbyHeroes(bestTarget, 1600, true, BOT_MODE_NONE)
			local enemyHeroes = Fu.GetNearbyHeroes(bestTarget, 1600, false, BOT_MODE_NONE)
			if allyHeroes ~= nil and enemyHeroes ~= nil then
				if Fu.IsInLaningPhase() then
					if #allyHeroes < #enemyHeroes + 2 and Fu.IsAttacking(bestTarget) then
						if
							bestTarget:GetHealth()
							<= bot:GetEstimatedDamageToTarget(true, bestTarget, doomDuration, DAMAGE_TYPE_ALL)
						then
							return BOT_ACTION_DESIRE_HIGH, bestTarget
						end
					end
				else
					if #allyHeroes < #enemyHeroes + 2 then
						return BOT_ACTION_DESIRE_HIGH, bestTarget
					end
				end
			end
		end
	end
	-- Retreat: Doom was cast only while engaging. Doom silences its target (datafeed: "prevents them
	-- from casting spells"), so when Doom is low and being hit, put it on the chaser hurting him
	-- most, so the chaser cannot stun or blink after him.
	if isRetreating and Fu.GetHP(bot) < 0.5 and bot:WasRecentlyDamagedByAnyHero(2) then
		local best, bestDmg = nil, 0
		for _, enemyHero in pairs(Fu.GetNearbyHeroes(bot, 550, true, BOT_MODE_NONE) or {}) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
				and Fu.IsChasingTarget(enemyHero, bot)
				and Fu.CanCastOnMagicImmune(enemyHero)
				and not Fu.IsHaveAegis(enemyHero) -- same guards as the engage branch
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and not enemyHero:HasModifier("modifier_doom_bringer_doom")
				and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
			then
				local dmg = enemyHero:GetEstimatedDamageToTarget(false, bot, 3.0, DAMAGE_TYPE_ALL)
				if dmg > bestDmg then
					best, bestDmg = enemyHero, dmg
				end
			end
		end
		if best ~= nil then
			if DotaTime() >= (bot._doomRetreatLogAt or -999) then
				bot._doomRetreatLogAt = DotaTime() + 5
				pcall(
					print,
					string.format(
						"[OHA-DOOM] t=%.0f doom retreat target=%s hp=%.2f",
						DotaTime(),
						best:GetUnitName(),
						Fu.GetHP(bot)
					)
				)
			end
			return BOT_ACTION_DESIRE_HIGH, best
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
DEVOUR_ABILITIES = {
	centaur_khan_war_stomp = true,
	fel_beast_haunt = true,
	giant_wolf_intimidate = true,
	harpy_scout_take_off = true,
	harpy_storm_chain_lightning = true,
	satyr_trickster_purge = true,
}
-- A Devoured creep ability: not one of Doom's own, not a map/system ability, not hidden.
function X.IsStolenAbility(ability)
	local name = ability:GetName()
	if type(name) ~= "string" or ability:IsHidden() or ability:IsPassive() then
		return false
	end
	if string.sub(name, 1, 13) == "doom_bringer_" or string.sub(name, 1, 14) == "special_bonus_" then
		return false
	end
	for _, prefix in ipairs({ "ability_", "plus_", "seasonal_", "twin_gate" }) do
		if string.sub(name, 1, #prefix) == prefix then
			return false
		end
	end
	return true
end
-- Any other Devoured creep ability, judged by its own target type and team (read from the game,
-- so no creep ability names are hard-coded). Toggles and autocasts are left alone.
function X.ConsiderGenericDevourAbility(ability)
	if not ability:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil, ""
	end
	local behavior = ability:GetBehavior()
	local has = function(flag)
		return flag ~= nil and Fu.CheckBitfieldFlag(behavior, flag)
	end
	-- Behavior flags: no target 4, unit 8, point 16, toggle 512, autocast 4096 (checked on known
	-- abilities: Echo Slam, Fissure, Split Shot, Walrus Punch). Friendly target team is 1.
	if has(512) or has(4096) then
		return BOT_ACTION_DESIRE_NONE, nil, ""
	end
	local okTeam, team = pcall(function()
		return ability:GetTargetTeam()
	end)
	local friendly = okTeam and team == 1
	local range = ability:GetCastRange()
	if range == nil or range < 150 then
		range = 350
	end
	range = Fu.GetProperCastRange(false, bot, range)
	local foesNear = Fu.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE) or {}
	if has(8) and friendly then
		if #foesNear == 0 then
			return BOT_ACTION_DESIRE_NONE, nil, ""
		end
		local best, bestHp = nil, 0.5
		for _, ally in pairs(Fu.GetNearbyHeroes(bot, range, false, BOT_MODE_NONE) or {}) do
			if Fu.IsValidHero(ally) and not ally:IsIllusion() and Fu.GetHP(ally) < bestHp then
				best, bestHp = ally, Fu.GetHP(ally)
			end
		end
		if best ~= nil then
			return BOT_ACTION_DESIRE_HIGH, best, "unit"
		end
		return BOT_ACTION_DESIRE_NONE, nil, ""
	end
	local target = nil
	if
		(isGoingOnSomeone or Fu.IsInTeamFight(bot, 1200))
		and Fu.IsValidHero(botTarget)
		and not Fu.IsSuspiciousIllusion(botTarget)
	then
		target = botTarget
	elseif isRetreating then
		for _, foe in pairs(foesNear) do
			if Fu.IsValidHero(foe) and not Fu.IsSuspiciousIllusion(foe) and Fu.IsChasingTarget(foe, bot) then
				target = foe
				break
			end
		end
	end
	if target == nil or not Fu.CanCastOnNonMagicImmune(target) then
		return BOT_ACTION_DESIRE_NONE, nil, ""
	end
	if has(8) and Fu.IsInRange(bot, target, range + 100) then
		return BOT_ACTION_DESIRE_HIGH, target, "unit"
	end
	if has(16) and Fu.IsInRange(bot, target, range + 100) then
		return BOT_ACTION_DESIRE_HIGH, target, "point"
	end
	if has(4) and Fu.IsInRange(bot, target, 350) then
		return BOT_ACTION_DESIRE_HIGH, nil, ""
	end
	return BOT_ACTION_DESIRE_NONE, nil, ""
end
function X.ConsiderDevourAbility(stolenAbility)
	if stolenAbility:IsPassive() or not stolenAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil, ""
	end
	local castRange = 0
	local radius = 0
	local damage = 0
	if stolenAbility:GetName() == "fel_beast_haunt" then
		castRange = 600
		if isGoingOnSomeone then
			if
				Fu.IsValidTarget(botTarget)
				and Fu.CanCastOnNonMagicImmune(botTarget)
				and Fu.CanCastOnTargetAdvanced(botTarget)
				and Fu.IsInRange(bot, botTarget, castRange)
				and not Fu.IsSuspiciousIllusion(botTarget)
				and not Fu.IsDisabled(botTarget)
				and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
				and not botTarget:HasModifier("modifier_skeleton_king_reincarnation_scepter_active")
			then
				local allyHeroes = Fu.GetNearbyHeroes(botTarget, 1200, true, BOT_MODE_NONE)
				local enemyHeroes = Fu.GetNearbyHeroes(botTarget, 1200, false, BOT_MODE_NONE)
				if allyHeroes ~= nil and enemyHeroes ~= nil and #allyHeroes >= #enemyHeroes then
					return BOT_ACTION_DESIRE_HIGH, botTarget, "unit"
				end
			end
		end
		if isRetreating and bot:GetActiveModeDesire() > 0.5 then
			local enemyHeroes = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
			for _, enemyHero in pairs(enemyHeroes) do
				if
					Fu.IsValidHero(enemyHero)
					and Fu.CanCastOnNonMagicImmune(enemyHero)
					and Fu.CanCastOnTargetAdvanced(enemyHero)
					and Fu.IsChasingTarget(enemyHero, bot)
					and not Fu.IsSuspiciousIllusion(enemyHero)
					and not Fu.IsDisabled(enemyHero)
					and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
					and not enemyHero:HasModifier("modifier_skeleton_king_reincarnation_scepter_active")
				then
					local allyHeroes = Fu.GetNearbyHeroes(enemyHero, 1200, true, BOT_MODE_NONE)
					local enemiesNearChaser = Fu.GetNearbyHeroes(enemyHero, 1200, false, BOT_MODE_NONE)
					if
						allyHeroes ~= nil
						and enemiesNearChaser ~= nil
						and (#enemiesNearChaser > #allyHeroes or bot:WasRecentlyDamagedByAnyHero(2))
					then
						return BOT_ACTION_DESIRE_HIGH, enemyHero, "unit"
					end
				end
			end
		end
	end
	if stolenAbility:GetName() == "harpy_scout_take_off" then
		if Fu.IsStuck(bot) then
			if stolenAbility:GetToggleState() == false then
				return BOT_ACTION_DESIRE_HIGH
			else
				return BOT_ACTION_DESIRE_NONE
			end
		end
		if stolenAbility:GetToggleState() == true then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if stolenAbility:GetName() == "harpy_storm_chain_lightning" then
		castRange = Fu.GetProperCastRange(false, bot, stolenAbility:GetCastRange())
		damage = stolenAbility:GetSpecialValueInt("initial_damage")
		local jumpRange = stolenAbility:GetSpecialValueInt("jump_range")
		local enemiesInRange = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
		for _, enemyHero in pairs(enemiesInRange) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
				and Fu.CanKillTarget(enemyHero, damage, DAMAGE_TYPE_MAGICAL)
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
				and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
				and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
				and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
				and not enemyHero:HasModifier("modifier_templar_assassin_refraction_absorb")
			then
				return BOT_ACTION_DESIRE_HIGH, enemyHero, "unit"
			end
		end
		if isGoingOnSomeone then
			if
				Fu.IsValidTarget(botTarget)
				and Fu.CanCastOnNonMagicImmune(botTarget)
				and Fu.CanCastOnTargetAdvanced(botTarget)
				and Fu.IsInRange(bot, botTarget, castRange)
				and not Fu.IsSuspiciousIllusion(botTarget)
				and not Fu.IsDisabled(botTarget)
				and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
				and not botTarget:HasModifier("modifier_templar_assassin_refraction_absorb")
			then
				local allyHeroes = Fu.GetNearbyHeroes(bot, 1200, false, BOT_MODE_NONE)
				local enemyHeroes = Fu.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE)
				if allyHeroes ~= nil and enemyHeroes ~= nil and #allyHeroes >= #enemyHeroes then
					return BOT_ACTION_DESIRE_HIGH, botTarget, "unit"
				end
			end
		end
		if isRetreating then
			local enemyHeroes = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
			for _, enemyHero in pairs(enemyHeroes) do
				if
					Fu.IsValidHero(enemyHero)
					and Fu.CanCastOnNonMagicImmune(enemyHero)
					and Fu.IsChasingTarget(enemyHero, bot)
					and not Fu.IsSuspiciousIllusion(enemyHero)
					and not Fu.IsDisabled(enemyHero)
				then
					local allyHeroes = Fu.GetNearbyHeroes(enemyHero, 1200, true, BOT_MODE_NONE)
					local enemiesNearChaser = Fu.GetNearbyHeroes(enemyHero, 1200, false, BOT_MODE_NONE)
					if
						allyHeroes ~= nil
						and enemiesNearChaser ~= nil
						and (#enemiesNearChaser > #allyHeroes or bot:WasRecentlyDamagedByAnyHero(2))
					then
						return BOT_ACTION_DESIRE_HIGH, enemyHero, "unit"
					end
				end
			end
		end
		if
			Fu.IsFarming(bot)
			and Fu.GetManaAfter(stolenAbility:GetManaCost()) * bot:GetMana() > doomAbility:GetManaCost() * 2
		then
			local enemyCreeps = bot:GetNearbyCreeps(1600, true)
			if
				enemyCreeps ~= nil
				and (#enemyCreeps >= 3 or #enemyCreeps >= 2 and enemyCreeps[1]:IsAncientCreep())
				and isAttacking
			then
				for _, creep in pairs(enemyCreeps) do
					if Fu.IsValid(creep) and Fu.CanBeAttacked(creep) then
						local nearbyUnitCount =
							Fu.GetNearbyAroundLocationUnitCount(true, false, jumpRange, creep:GetLocation())
						if nearbyUnitCount >= 2 then
							return BOT_ACTION_DESIRE_HIGH, creep, "unit"
						end
					end
				end
			end
		end
		if Fu.IsDoingRoshan(bot) then
			if
				Fu.IsRoshan(botTarget)
				and Fu.CanCastOnNonMagicImmune(botTarget)
				and Fu.IsInRange(bot, botTarget, castRange)
				and isAttacking
			then
				return BOT_ACTION_DESIRE_HIGH, botTarget, "unit"
			end
		end
		if Fu.IsDoingTormentor(bot) then
			if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, castRange) and isAttacking then
				return BOT_ACTION_DESIRE_HIGH, botTarget, "unit"
			end
		end
	end
	if stolenAbility:GetName() == "centaur_khan_war_stomp" then
		damage = stolenAbility:GetAbilityDamage()
		radius = stolenAbility:GetSpecialValueInt("radius")
		local enemiesInRange = Fu.GetNearbyHeroes(bot, radius, true, BOT_MODE_NONE)
		for _, enemyHero in pairs(enemiesInRange) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and not Fu.IsSuspiciousIllusion(enemyHero)
			then
				if enemyHero:IsChanneling() then
					return BOT_ACTION_DESIRE_HIGH, nil, ""
				end
				if
					Fu.CanKillTarget(enemyHero, damage, DAMAGE_TYPE_MAGICAL)
					and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
					and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
					and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
					and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
					and not enemyHero:HasModifier("modifier_skeleton_king_reincarnation_scepter_active")
					and not enemyHero:HasModifier("modifier_templar_assassin_refraction_absorb")
				then
					return BOT_ACTION_DESIRE_HIGH, nil, ""
				end
			end
		end
		if isGoingOnSomeone then
			if
				Fu.IsValidTarget(botTarget)
				and Fu.CanCastOnNonMagicImmune(botTarget)
				and Fu.IsInRange(bot, botTarget, radius)
				and not Fu.IsSuspiciousIllusion(botTarget)
				and not Fu.IsDisabled(botTarget)
				and not botTarget:HasModifier("modifier_enigma_black_hole_pull")
				and not botTarget:HasModifier("modifier_faceless_void_chronosphere_freeze")
				and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
				and not botTarget:HasModifier("modifier_skeleton_king_reincarnation_scepter_active")
			then
				local allyHeroes = Fu.GetNearbyHeroes(botTarget, 1200, true, BOT_MODE_NONE)
				local enemyHeroes = Fu.GetNearbyHeroes(botTarget, 1200, false, BOT_MODE_NONE)
				if allyHeroes ~= nil and enemyHeroes ~= nil and #allyHeroes >= #enemyHeroes then
					return BOT_ACTION_DESIRE_HIGH, nil, ""
				end
			end
		end
		if isRetreating then
			local allyHeroes = Fu.GetNearbyHeroes(bot, 1200, false, BOT_MODE_NONE)
			local enemyHeroes = Fu.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE)
			if
				allyHeroes ~= nil
				and enemyHeroes ~= nil
				and Fu.IsValidHero(enemyHeroes[1])
				and Fu.CanCastOnNonMagicImmune(enemyHeroes[1])
				and Fu.IsInRange(bot, enemyHeroes[1], radius)
				and Fu.IsChasingTarget(enemyHeroes[1], bot)
				and not Fu.IsSuspiciousIllusion(enemyHeroes[1])
				and not Fu.IsDisabled(enemyHeroes[1])
				and not enemyHeroes[1]:HasModifier("modifier_necrolyte_reapers_scythe")
			then
				local enemiesNearChaser = Fu.GetNearbyHeroes(enemyHeroes[1], 1200, false, BOT_MODE_NONE)
				if
					enemiesNearChaser ~= nil
					and (#enemiesNearChaser > #allyHeroes or bot:WasRecentlyDamagedByAnyHero(2))
				then
					return BOT_ACTION_DESIRE_HIGH, nil, ""
				end
			end
		end
		if Fu.IsDoingRoshan(bot) then
			if
				Fu.IsRoshan(botTarget)
				and Fu.CanCastOnNonMagicImmune(botTarget)
				and Fu.IsInRange(bot, botTarget, radius)
				and isAttacking
				and not Fu.IsDisabled(botTarget)
			then
				return BOT_ACTION_DESIRE_HIGH, nil, ""
			end
		end
		if Fu.IsDoingTormentor(bot) then
			if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, radius) and isAttacking then
				return BOT_ACTION_DESIRE_HIGH, nil, ""
			end
		end
	end
	if stolenAbility:GetName() == "giant_wolf_intimidate" then
		radius = stolenAbility:GetSpecialValueInt("radius")
		if isGoingOnSomeone then
			if
				Fu.IsValidTarget(botTarget)
				and Fu.IsInRange(bot, botTarget, radius)
				and not Fu.IsSuspiciousIllusion(botTarget)
				and not Fu.IsDisabled(botTarget)
				and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
			then
				local allyHeroes = Fu.GetNearbyHeroes(bot, 1200, false, BOT_MODE_NONE)
				local enemyHeroes = Fu.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE)
				if allyHeroes ~= nil and enemyHeroes ~= nil and #allyHeroes >= #enemyHeroes then
					return BOT_ACTION_DESIRE_HIGH, nil, ""
				end
			end
		end
		if isRetreating then
			local allyHeroes = Fu.GetNearbyHeroes(bot, 1200, false, BOT_MODE_NONE)
			local enemyHeroes = Fu.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE)
			if
				allyHeroes ~= nil
				and enemyHeroes ~= nil
				and Fu.IsValidHero(enemyHeroes[1])
				and Fu.IsInRange(bot, enemyHeroes[1], radius)
				and Fu.IsChasingTarget(enemyHeroes[1], bot)
				and Fu.IsAttacking(enemyHeroes[1])
				and not Fu.IsSuspiciousIllusion(enemyHeroes[1])
				and not Fu.IsDisabled(enemyHeroes[1])
				and not enemyHeroes[1]:HasModifier("modifier_necrolyte_reapers_scythe")
			then
				local enemiesNearChaser = Fu.GetNearbyHeroes(enemyHeroes[1], 1200, false, BOT_MODE_NONE)
				if
					enemiesNearChaser ~= nil
					and (#enemiesNearChaser > #allyHeroes or bot:WasRecentlyDamagedByAnyHero(1.5))
				then
					return BOT_ACTION_DESIRE_HIGH, nil, ""
				end
			end
		end
		if Fu.IsDoingRoshan(bot) then
			if
				Fu.IsRoshan(botTarget)
				and Fu.IsInRange(bot, botTarget, radius)
				and isAttacking
				and not Fu.IsDisabled(botTarget)
			then
				return BOT_ACTION_DESIRE_HIGH, nil, ""
			end
		end
		if Fu.IsDoingTormentor(bot) then
			if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, radius) and isAttacking then
				return BOT_ACTION_DESIRE_HIGH, nil, ""
			end
		end
	end
	if stolenAbility:GetName() == "satyr_trickster_purge" then
		castRange = Fu.GetProperCastRange(false, bot, stolenAbility:GetCastRange())
		if not bot:IsMagicImmune() and not bot:IsInvulnerable() then
			if Fu.IsDisabled(bot) or bot:HasModifier("modifier_bounty_hunter_track") then
				return BOT_ACTION_DESIRE_HIGH, bot, "unit"
			end
		end
		local alliesInRange = Fu.GetNearbyHeroes(bot, castRange, false, BOT_MODE_NONE)
		for _, allyHero in pairs(alliesInRange) do
			if
				Fu.IsValidHero(allyHero)
				and not allyHero:IsMagicImmune()
				and not allyHero:IsInvulnerable()
				and not Fu.IsSuspiciousIllusion(allyHero)
			then
				if Fu.IsDisabled(allyHero) or allyHero:HasModifier("modifier_bounty_hunter_track") then
					return BOT_ACTION_DESIRE_HIGH, allyHero, "unit"
				end
			end
		end
		local enemiesInRange = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
		for _, enemyHero in pairs(enemiesInRange) do
			if
				Fu.IsValidHero(enemyHero)
				and not Fu.IsDisabled(enemyHero)
				and not enemyHero:IsMagicImmune()
				and not enemyHero:IsInvulnerable()
				and not Fu.IsSuspiciousIllusion(enemyHero)
			then
				if
					enemyHero:HasModifier("modifier_item_satanic_unholy")
					or enemyHero:HasModifier("modifier_rune_doubledamage")
				then
					return BOT_ACTION_DESIRE_HIGH, enemyHero, "unit"
				end
			end
		end
		if isGoingOnSomeone then
			if
				Fu.IsValidTarget(botTarget)
				and Fu.CanCastOnNonMagicImmune(botTarget)
				and Fu.CanCastOnTargetAdvanced(botTarget)
				and Fu.IsInRange(bot, botTarget, castRange)
				and Fu.IsChasingTarget(bot, botTarget)
				and botTarget:GetCurrentMovementSpeed() > bot:GetCurrentMovementSpeed()
				and not Fu.IsSuspiciousIllusion(botTarget)
				and not Fu.IsDisabled(botTarget)
				and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
			then
				local allyHeroes = Fu.GetNearbyHeroes(bot, 1200, false, BOT_MODE_NONE)
				local enemyHeroes = Fu.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE)
				if allyHeroes ~= nil and enemyHeroes ~= nil and #allyHeroes >= #enemyHeroes then
					return BOT_ACTION_DESIRE_HIGH, botTarget, "unit"
				end
			end
		end
		if isRetreating then
			local enemyHeroes = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
			for _, enemyHero in pairs(enemyHeroes) do
				if
					Fu.IsValidHero(enemyHero)
					and Fu.CanCastOnNonMagicImmune(enemyHero)
					and Fu.CanCastOnTargetAdvanced(enemyHero)
					and Fu.IsChasingTarget(enemyHero, bot)
					and not Fu.IsSuspiciousIllusion(enemyHero)
					and not Fu.IsDisabled(enemyHero)
				then
					local allyHeroes = Fu.GetNearbyHeroes(enemyHero, 1200, true, BOT_MODE_NONE)
					local enemiesNearChaser = Fu.GetNearbyHeroes(enemyHero, 1200, false, BOT_MODE_NONE)
					if
						allyHeroes ~= nil
						and enemiesNearChaser ~= nil
						and (#enemiesNearChaser > #allyHeroes or bot:WasRecentlyDamagedByAnyHero(2))
						and enemyHero:GetCurrentMovementSpeed() > bot:GetCurrentMovementSpeed()
					then
						return BOT_ACTION_DESIRE_HIGH, enemyHero, "unit"
					end
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil, ""
end
return X
