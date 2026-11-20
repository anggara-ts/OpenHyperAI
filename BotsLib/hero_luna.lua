-- Luna: skill build, item build, and ability use for this hero.
local X = {}
local bot = GetBot()
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local AbilityContext = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local TalentWatch = require(GetScriptDirectory() .. "/FuncLib/systems/talent_watch")
local Minion = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local sTalentList = Fu.Skill.GetTalentList(bot)
local sAbilityList = Fu.Skill.GetAbilityList(bot)
local sRole = Fu.Item.GetRoleItemsBuyList(bot)
local tTalentTreeList = { ["t25"] = { 0, 10 }, ["t20"] = { 0, 10 }, ["t15"] = { 0, 10 }, ["t10"] = { 0, 10 } }
local tAllAbilityBuildList = { { 1, 3, 1, 3, 1, 6, 1, 3, 3, 2, 6, 2, 2, 2, 6 } }
local nAbilityBuildList = Fu.Skill.GetRandomBuild(tAllAbilityBuildList)
local nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList)
local sRoleItemsBuyList = {}
-- Stratz 7.41f, week of 9 Nov 2026: pos 1, 224,077 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_1"] = {
	"item_tango",
	"item_double_branches",
	"item_faerie_fire",
	"item_magic_stick",
	"item_magic_wand",
	"item_power_treads",
	"item_mask_of_madness",
	"item_manta",
	"item_blink",
	"item_butterfly",
	"item_black_king_bar",
	"item_aghanims_shard",
	"item_swift_blink",
	"item_satanic",
	"item_ultimate_scepter_2",
	"item_moon_shard",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 2, 11,682 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_2"] = {
	"item_tango",
	"item_double_branches",
	"item_circlet",
	"item_slippers",
	"item_wraith_band",
	"item_magic_wand",
	"item_power_treads",
	"item_yasha",
	"item_ultimate_scepter",
	"item_manta",
	"item_black_king_bar",
	"item_butterfly",
	"item_aghanims_shard",
	"item_satanic",
	"item_ultimate_scepter_2",
	"item_hurricane_pike",
	"item_moon_shard",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 3, 2,994 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_3"] = {
	"item_tango",
	"item_double_branches",
	"item_circlet",
	"item_magic_stick",
	"item_wraith_band",
	"item_magic_wand",
	"item_power_treads",
	"item_mask_of_madness",
	"item_manta",
	"item_blink",
	"item_black_king_bar",
	"item_butterfly",
	"item_aghanims_shard",
	"item_satanic",
	"item_moon_shard",
	"item_ultimate_scepter_2",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 4, 2,080 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_4"] = {
	"item_tango",
	"item_branches",
	"item_circlet",
	"item_magic_stick",
	"item_magic_wand",
	"item_power_treads",
	"item_manta",
	"item_ultimate_scepter",
	"item_butterfly",
	"item_satanic",
	"item_ultimate_scepter_2",
	"item_soul_booster",
	"item_shivas_guard",
	"item_aghanims_shard",
	"item_moon_shard",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 5, 1,838 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_5"] = {
	"item_tango",
	"item_double_branches",
	"item_magic_stick",
	"item_faerie_fire",
	"item_magic_wand",
	"item_power_treads",
	"item_mask_of_madness",
	"item_manta",
	"item_ultimate_scepter",
	"item_butterfly",
	"item_black_king_bar",
	"item_travel_boots",
	"item_satanic",
	"item_ultimate_scepter_2",
	"item_refresher",
	"item_aghanims_shard",
	"item_moon_shard",
}
X["sBuyList"] = sRoleItemsBuyList[sRole]
X["sSellList"] = { "item_black_king_bar", "item_quelling_blade" }
if Fu.Role.IsPvNMode() or Fu.Role.IsAllShadow() then
	X["sBuyList"], X["sSellList"] = { "PvN_ranged_carry" }, {}
end
nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"] =
	Fu.SetUserHeroInit(nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"])
X["sSkillList"] = Fu.Skill.GetSkillList(sAbilityList, nAbilityBuildList, sTalentList, nTalentBuildList)
X["bDeafaultAbility"] = false
X["bDeafaultItem"] = false
function X.MinionThink(minionUnit)
	Minion.MinionThink(minionUnit)
end
local lucentBeamAbility = SafeAbility(bot:GetAbilityByName("luna_lucent_beam"), "luna_lucent_beam", "luna")
local moonGlaiveAbility = SafeAbility(bot:GetAbilityByName("luna_moon_glaive"), "luna_moon_glaive", "luna")
local lunarOrbitAbility = SafeAbility(bot:GetAbilityByName("luna_lunar_orbit"), "luna_lunar_orbit", "luna")
local eclipseAbility = SafeAbility(bot:GetAbilityByName("luna_eclipse"), "luna_eclipse", "luna")
local lucentBeamDesire, lucentBeamTarget
local moonGlaivesDesire
local lunarOrbitDesire
local eclipseDesire
local botTarget
local isGoingOnSomeone
local isRetreating
local isAttacking
function X.SkillsComplement()
	TalentWatch.Tick(bot)
	if Fu.CanNotUseAbility(bot) then
		return
	end
	isGoingOnSomeone = Fu.IsGoingOnSomeone(bot)
	isRetreating = Fu.IsRetreating(bot)
	isAttacking = Fu.IsAttacking(bot)
	botTarget = Fu.GetProperTarget(bot)
	Fu.ConsiderTarget()
	moonGlaivesDesire = X.ConsiderMoonGlaives()
	if moonGlaivesDesire > 0 then
		bot:Action_UseAbility(moonGlaiveAbility)
		return
	end
	lunarOrbitDesire = X.ConsiderLunarOrbit()
	if lunarOrbitDesire > 0 then
		bot:Action_UseAbility(lunarOrbitAbility)
		return
	end
	eclipseDesire = X.ConsiderEclipse()
	if eclipseDesire > 0 then
		if Fu.HasPowerTreads(bot) then
			Fu.SetQueuePtToINT(bot, false)
			if bot:HasScepter() then
				bot:ActionQueue_UseAbilityOnEntity(eclipseAbility, bot)
			else
				bot:ActionQueue_UseAbility(eclipseAbility)
			end
		else
			if bot:HasScepter() then
				bot:Action_UseAbilityOnEntity(eclipseAbility, bot)
			else
				bot:Action_UseAbility(eclipseAbility)
			end
		end
		return
	end
	lucentBeamDesire, lucentBeamTarget = X.ConsiderLucentBeam()
	if lucentBeamDesire > 0 then
		if Fu.HasPowerTreads(bot) then
			Fu.SetQueuePtToINT(bot, false)
			bot:ActionQueue_UseAbilityOnEntity(lucentBeamAbility, lucentBeamTarget)
		else
			bot:Action_UseAbilityOnEntity(lucentBeamAbility, lucentBeamTarget)
		end
		return
	end
end
function X.ConsiderLucentBeam()
	if not lucentBeamAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castRange = Fu.GetProperCastRange(false, bot, lucentBeamAbility:GetCastRange())
	local abilityLevel = lucentBeamAbility:GetLevel()
	-- The old bonus came from talent 6 (Lunar Orbit speed/damage), not the beam talent.
	-- 7.42 game files: special_bonus_unique_luna_1 (+80) is linked into luna_lucent_beam "beam_damage", and the
	-- read includes it once learned (FuncLib/systems/talent_watch.lua). The old talent "value" read added 0 (#46).
	local damage = lucentBeamAbility:GetSpecialValueInt("beam_damage")
	local nearbyEnemies = Fu.GetNearbyHeroes(bot, castRange + 300, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and Fu.CanCastOnTargetAdvanced(enemyHero)
			and not Fu.IsSuspiciousIllusion(enemyHero)
		then
			if enemyHero:IsChanneling() or Fu.IsCastingUltimateAbility(enemyHero) then
				return BOT_ACTION_DESIRE_HIGH, enemyHero
			end
			if
				Fu.CanKillTarget(enemyHero, damage, DAMAGE_TYPE_MAGICAL)
				and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
				and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
				and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
				and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
				and not enemyHero:HasModifier("modifier_templar_assassin_refraction_absorb")
			then
				return BOT_ACTION_DESIRE_HIGH, enemyHero
			end
		end
	end
	if Fu.IsInTeamFight(bot, 1200) then
		local weakestTarget = nil
		local lowestHealth = 10000
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
				and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
				and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
			then
				local health = enemyHero:GetHealth()
				if health < lowestHealth then
					lowestHealth = health
					weakestTarget = enemyHero
				end
			end
		end
		if weakestTarget ~= nil then
			return BOT_ACTION_DESIRE_HIGH, weakestTarget
		end
	end
	if isGoingOnSomeone then
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.CanCastOnTargetAdvanced(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange + 75)
		then
			local alliesNearTarget = Fu.GetNearbyHeroes(botTarget, 1200, true, BOT_MODE_NONE)
			-- The target's own allies (false). Both calls used true, so the check was always true.
			local enemiesNearTarget = Fu.GetNearbyHeroes(botTarget, 1200, false, BOT_MODE_NONE)
			if alliesNearTarget ~= nil and enemiesNearTarget ~= nil and #alliesNearTarget >= #enemiesNearTarget then
				return BOT_ACTION_DESIRE_HIGH, botTarget
			end
		end
	end
	if isRetreating and bot:GetActiveModeDesire() > 0.5 then
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
				and Fu.IsChasingTarget(enemyHero, bot)
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and not Fu.IsDisabled(enemyHero)
				and not Fu.IsRealInvisible(bot)
			then
				local alliesNearChaser = Fu.GetNearbyHeroes(enemyHero, 1200, true, BOT_MODE_NONE)
				local enemiesNearChaser = Fu.GetNearbyHeroes(enemyHero, 1200, false, BOT_MODE_NONE)
				if
					alliesNearChaser ~= nil
					and enemiesNearChaser ~= nil
					and (#enemiesNearChaser > #alliesNearChaser or bot:WasRecentlyDamagedByAnyHero(2))
				then
					return BOT_ACTION_DESIRE_HIGH, enemyHero
				end
			end
		end
	end
	if Fu.IsLaning(bot) then
		local laneCreeps = bot:GetNearbyLaneCreeps(castRange + 200, true)
		for _, creep in pairs(laneCreeps) do
			if
				Fu.IsValid(creep)
				and Fu.CanBeAttacked(creep)
				and (Fu.IsKeyWordUnit("ranged", creep) or Fu.IsKeyWordUnit("siege", creep) or Fu.IsKeyWordUnit(
					"flagbearer",
					creep
				))
				and Fu.CanKillTarget(creep, damage, DAMAGE_TYPE_MAGICAL)
				and not Fu.IsInRange(bot, creep, bot:GetAttackRange() + 80)
			then
				return BOT_ACTION_DESIRE_HIGH, creep
			end
		end
		if abilityLevel >= 2 or Fu.GetMP(bot) > 0.9 then
			for _, creep in pairs(laneCreeps) do
				if
					Fu.IsValid(creep)
					and Fu.CanBeAttacked(creep)
					and Fu.IsKeyWordUnit("melee", creep)
					and Fu.CanKillTarget(creep, damage, DAMAGE_TYPE_MAGICAL)
					and not Fu.IsInRange(bot, creep, bot:GetAttackRange() + 80)
				then
					return BOT_ACTION_DESIRE_HIGH, creep
				end
			end
		end
	end
	if Fu.IsFarming(bot) then
		local neutralCreeps = bot:GetNearbyNeutralCreeps(castRange + 100)
		local strongestCreep = Fu.GetMostHpUnit(neutralCreeps)
		if
			Fu.IsValid(strongestCreep)
			and (#neutralCreeps >= 2 or GetUnitToUnitDistance(strongestCreep, bot) <= 400)
			and not Fu.IsRoshan(strongestCreep)
			and not Fu.CanKillTarget(strongestCreep, bot:GetAttackDamage() * 1.68, DAMAGE_TYPE_PHYSICAL)
			and not Fu.CanKillTarget(strongestCreep, damage - 10, DAMAGE_TYPE_MAGICAL)
			and Fu.GetManaAfter(lucentBeamAbility:GetManaCost()) * bot:GetMana() > eclipseAbility:GetManaCost() * 2
		then
			return BOT_ACTION_DESIRE_HIGH, strongestCreep
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if
			Fu.IsRoshan(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and isAttacking
			and not Fu.IsDisabled(botTarget)
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, castRange) and isAttacking then
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end
	local nearbyAllies = Fu.GetNearbyHeroes(bot, castRange, false, BOT_MODE_NONE)
	for _, allyHero in pairs(nearbyAllies) do
		local enemiesNearAlly = Fu.GetNearbyHeroes(allyHero, 1200, true, BOT_MODE_NONE)
		if
			Fu.IsValidHero(allyHero)
			and Fu.IsRetreating(allyHero)
			and Fu.IsCore(allyHero)
			and allyHero:WasRecentlyDamagedByAnyHero(2)
			and allyHero:GetActiveModeDesire() >= 0.5
			and not allyHero:IsIllusion()
		then
			if
				enemiesNearAlly ~= nil
				and #enemiesNearAlly >= 1
				and Fu.IsValidHero(enemiesNearAlly[1])
				and Fu.CanCastOnNonMagicImmune(enemiesNearAlly[1])
				and Fu.CanCastOnTargetAdvanced(enemiesNearAlly[1])
				and Fu.IsInRange(bot, enemiesNearAlly[1], castRange)
				and Fu.IsChasingTarget(enemiesNearAlly[1], allyHero)
				and not Fu.IsChasingTarget(enemiesNearAlly[1], bot)
				and not Fu.IsDisabled(enemiesNearAlly[1])
				and not Fu.IsTaunted(enemiesNearAlly[1])
				and not Fu.IsSuspiciousIllusion(enemiesNearAlly[1])
				and not enemiesNearAlly[1]:HasModifier("modifier_necrolyte_reapers_scythe")
			then
				return BOT_ACTION_DESIRE_HIGH, enemiesNearAlly[1]
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function X.ConsiderLunarOrbit()
	if not lunarOrbitAbility:IsTrained() or not lunarOrbitAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
	end
	-- Glaives orbit at rotating_glaives_movement_radius (225) and hit within rotating_glaives_hit_radius
	-- (200) of each glaive, so they reach ~425. Using 225 alone needed the target almost in melee range
	-- (Luna is ranged), and 3 neutrals inside 225, so the orbit was rarely cast to fight or farm.
	local radius = lunarOrbitAbility:GetSpecialValueInt("rotating_glaives_movement_radius")
		+ lunarOrbitAbility:GetSpecialValueInt("rotating_glaives_hit_radius")
	local nearbyEnemies = Fu.GetNearbyHeroes(bot, 700, true, BOT_MODE_NONE)
	if Fu.GetHP(bot) < 0.5 and bot:WasRecentlyDamagedByAnyHero(1) and nearbyEnemies ~= nil and #nearbyEnemies >= 1 then
		return BOT_ACTION_DESIRE_HIGH
	end
	if isGoingOnSomeone then
		if
			Fu.IsValidTarget(botTarget)
			and Fu.IsInRange(bot, botTarget, radius)
			and bot:WasRecentlyDamagedByAnyHero(1)
			and not Fu.IsDisabled(botTarget)
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end
	if isRetreating then
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE)
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.IsChasingTarget(enemyHero, bot)
				and Fu.IsInRange(bot, enemyHero, 700)
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and not Fu.IsDisabled(enemyHero)
			then
				local alliesNearChaser = Fu.GetNearbyHeroes(enemyHero, 1200, true, BOT_MODE_NONE)
				local enemiesNearChaser = Fu.GetNearbyHeroes(enemyHero, 1200, false, BOT_MODE_NONE)
				if
					alliesNearChaser ~= nil
					and enemiesNearChaser ~= nil
					and (#enemiesNearChaser > #alliesNearChaser or bot:WasRecentlyDamagedByAnyHero(1.5))
				then
					return BOT_ACTION_DESIRE_HIGH
				end
			end
		end
	end
	if Fu.IsFarming(bot) then
		local nearbyCreeps = bot:GetNearbyCreeps(radius, true)
		if
			nearbyCreeps ~= nil
			and (#nearbyCreeps >= 3 or #nearbyCreeps >= 2 and nearbyCreeps[1]:IsAncientCreep())
			and Fu.CanBeAttacked(nearbyCreeps[1])
			and isAttacking
			and Fu.GetManaAfter(lunarOrbitAbility:GetManaCost()) * bot:GetMana() > eclipseAbility:GetManaCost() * 2
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderMoonGlaives()
	-- datafeed: Moon Glaives is passive (behavior 2); never try to cast it (if a passive reads as
	-- castable, the early return in SkillsComplement would skip Lucent Beam / Eclipse). The active is
	-- Lunar Orbit (ConsiderLunarOrbit).
	if
		not moonGlaiveAbility:IsTrained()
		or not moonGlaiveAbility:IsFullyCastable()
		or moonGlaiveAbility:IsPassive()
	then
		return BOT_ACTION_DESIRE_NONE
	end
	local radius = 175
	local nearbyEnemies = Fu.GetNearbyHeroes(bot, 700, true, BOT_MODE_NONE)
	if Fu.GetHP(bot) < 0.5 and bot:WasRecentlyDamagedByAnyHero(1) and nearbyEnemies ~= nil and #nearbyEnemies >= 1 then
		return BOT_ACTION_DESIRE_HIGH
	end
	if isGoingOnSomeone then
		if
			Fu.IsValidTarget(botTarget)
			and Fu.IsInRange(bot, botTarget, radius)
			and bot:WasRecentlyDamagedByAnyHero(1)
			and not Fu.IsDisabled(botTarget)
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end
	if isRetreating then
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE)
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.IsChasingTarget(enemyHero, bot)
				and Fu.IsInRange(bot, enemyHero, 700)
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and not Fu.IsDisabled(enemyHero)
			then
				local alliesNearChaser = Fu.GetNearbyHeroes(enemyHero, 1200, true, BOT_MODE_NONE)
				local enemiesNearChaser = Fu.GetNearbyHeroes(enemyHero, 1200, false, BOT_MODE_NONE)
				if
					alliesNearChaser ~= nil
					and enemiesNearChaser ~= nil
					and (#enemiesNearChaser > #alliesNearChaser or bot:WasRecentlyDamagedByAnyHero(1.5))
				then
					return BOT_ACTION_DESIRE_HIGH
				end
			end
		end
	end
	if Fu.IsFarming(bot) then
		local nearbyCreeps = bot:GetNearbyCreeps(radius, true)
		if
			nearbyCreeps ~= nil
			and (#nearbyCreeps >= 3 or #nearbyCreeps >= 2 and nearbyCreeps[1]:IsAncientCreep())
			and Fu.CanBeAttacked(nearbyCreeps[1])
			and isAttacking
			and Fu.GetManaAfter(moonGlaiveAbility:GetManaCost()) * bot:GetMana() > eclipseAbility:GetManaCost() * 2
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderEclipse()
	if not eclipseAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
	end
	local radius = eclipseAbility:GetSpecialValueInt("radius")
	local damage = lucentBeamAbility:GetSpecialValueInt("beam_damage")
	if Fu.IsInTeamFight(bot, 1200) then
		local nearbyEnemies = Fu.GetEnemiesNearLoc(bot:GetLocation(), radius + 75)
		if nearbyEnemies ~= nil and #nearbyEnemies >= 2 then
			-- Was: needed a hero killable by ONE beam, so in most fights Eclipse waited for someone
			-- nearly dead. Eclipse fires `beams` beams at random nearby enemies, at most `hit_count` on
			-- one unit. Estimate one hero's share as beams / heroes in range (creeps, if beams can hit
			-- them, are not counted, so this is an upper estimate).
			local beams = math.max(1, eclipseAbility:GetSpecialValueInt("beams"))
			local perUnitCap = math.max(1, eclipseAbility:GetSpecialValueInt("hit_count"))
			local share = math.max(1, math.min(perUnitCap, math.floor(beams / #nearbyEnemies)))
			damage = damage * share
			local canKillHero = false
			for _, enemyHero in pairs(nearbyEnemies) do
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
					canKillHero = true
					break
				end
			end
			if canKillHero then
				if share > 1 and DotaTime() >= (bot._ohaLunaEclipseLogAt or -999) then
					bot._ohaLunaEclipseLogAt = DotaTime() + 5
					pcall(
						print,
						string.format(
							"[OHA-LUNA] t=%.0f eclipse team fight heroes=%d beams/hero=%d",
							DotaTime(),
							#nearbyEnemies,
							share
						)
					)
				end
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	if isGoingOnSomeone then
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, radius)
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
			and botTarget:GetHealth() > bot:GetAttackDamage() * 4
		then
			local nearbyEnemies = Fu.GetNearbyHeroes(bot, radius + 75, true, BOT_MODE_NONE)
			local nearbyAllies = Fu.GetNearbyHeroes(bot, 1200, false, BOT_MODE_NONE)
			if
				nearbyEnemies ~= nil
				and #nearbyEnemies >= 1
				and nearbyAllies ~= nil
				and #nearbyAllies >= #nearbyEnemies
			then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
return X
