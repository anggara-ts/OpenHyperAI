-- Centaur: skill build, item build, and ability use for this hero.
local X = {}
local bot = GetBot()
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local AbilityContext = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local Minion = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local sTalentList = Fu.Skill.GetTalentList(bot)
local sAbilityList = Fu.Skill.GetAbilityList(bot)
local sRole = Fu.Item.GetRoleItemsBuyList(bot)
local tTalentTreeList = { ["t25"] = { 10, 0 }, ["t20"] = { 10, 0 }, ["t15"] = { 10, 0 }, ["t10"] = { 0, 10 } }
local tAllAbilityBuildList = { { 1, 2, 3, 3, 3, 6, 3, 1, 1, 1, 6, 2, 2, 2, 6 } }
local nAbilityBuildList = Fu.Skill.GetRandomBuild(tAllAbilityBuildList)
local nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList)
local sUtility = "item_team_aura"
local sRoleItemsBuyList = {}
-- Stratz 7.41f, week of 9 Nov 2026: pos 3, 93,524 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_3"] = {
	"item_tango",
	"item_double_gauntlets",
	"item_branches",
	"item_ring_of_protection",
	"item_bracer",
	"item_magic_wand",
	"item_vanguard",
	"item_phase_boots",
	"item_blink",
	"item_heart",
	sUtility,
	"item_aghanims_shard",
	"item_ultimate_scepter",
	"item_overwhelming_blink",
	"item_ultimate_scepter_2",
	"item_helm_of_the_dominator",
	"item_moon_shard",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 1 has 942 matches, built from pos 3 (93,524) (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_1"] = sRoleItemsBuyList["pos_3"]
-- Stratz 7.41f, week of 9 Nov 2026: pos 2, 1,869 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_2"] = {
	"item_tango",
	"item_double_gauntlets",
	"item_branches",
	"item_quelling_blade",
	"item_bracer",
	"item_magic_wand",
	"item_phase_boots",
	"item_blink",
	"item_heart",
	sUtility,
	"item_aghanims_shard",
	"item_shivas_guard",
	"item_overwhelming_blink",
	"item_ultimate_scepter_2",
	"item_consecrated_wraps",
	"item_moon_shard",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 4, 2,460 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_4"] = {
	"item_tango",
	"item_double_gauntlets",
	"item_branches",
	"item_ring_of_protection",
	"item_bracer",
	"item_magic_wand",
	"item_phase_boots",
	"item_blink",
	sUtility,
	"item_heart",
	"item_aghanims_shard",
	"item_black_king_bar",
	"item_ultimate_scepter",
	"item_moon_shard",
	"item_ultimate_scepter_2",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 5, 1,268 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_5"] = {
	"item_tango",
	"item_blood_grenade",
	"item_gauntlets",
	"item_branches",
	"item_magic_stick",
	"item_bracer",
	"item_magic_wand",
	"item_tranquil_boots",
	"item_blink",
	sUtility,
	"item_heart",
	"item_shivas_guard",
	"item_overwhelming_blink",
	"item_ultimate_scepter",
	"item_aghanims_shard",
	"item_moon_shard",
	"item_ultimate_scepter_2",
}
X["sBuyList"] = sRoleItemsBuyList[sRole]
X["sSellList"] = { "item_power_treads", "item_quelling_blade" }
if Fu.Role.IsPvNMode() or Fu.Role.IsAllShadow() then
	X["sBuyList"], X["sSellList"] = { "PvN_antimage" }, {}
end
nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"] =
	Fu.SetUserHeroInit(nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"])
X["sSkillList"] = Fu.Skill.GetSkillList(sAbilityList, nAbilityBuildList, sTalentList, nTalentBuildList)
X["bDeafaultAbility"] = false
-- Cast when cornered (retreating into 3+ enemies with no way out), before running further.
X["LastStandSpells"] = { { name = "centaur_stampede", kind = "none" }, { name = "centaur_hoof_stomp", kind = "none" } }
X["bDeafaultItem"] = false
function X.MinionThink(minionUnit)
	Minion.MinionThink(minionUnit)
end
local hoofStompAbility = SafeAbility(bot:GetAbilityByName("centaur_hoof_stomp"), "centaur_hoof_stomp", "centaur")
local doubleEdgeAbility = SafeAbility(bot:GetAbilityByName("centaur_double_edge"), "centaur_double_edge", "centaur")
local workHorseAbility = SafeAbility(bot:GetAbilityByName("centaur_work_horse"), "centaur_work_horse", "centaur")
local hitchARideAbility = SafeAbility(bot:GetAbilityByName("centaur_mount"), "centaur_mount", "centaur")
local stampedeAbility = SafeAbility(bot:GetAbilityByName("centaur_stampede"), "centaur_stampede", "centaur")
local hoofStompDesire
local doubleEdgeDesire, doubleEdgeTarget
local workHorseDesire
local hitchARideDesire, hitchARideTarget
local stampedeDesire
local botTarget
local isEngaging
local isRetreating
local isAttacking
local hpRatio
local isInTeamFight
function X.SkillsComplement()
	if Fu.CanNotUseAbility(bot) then
		return
	end
	local context = AbilityContext.Build(bot)
	isEngaging = context.isEngaging
	isRetreating = context.isRetreating
	isAttacking = Fu.IsAttacking(bot)
	hpRatio = context.hp
	isInTeamFight = context.isTeamFight
	hitchARideDesire, hitchARideTarget = X.ConsiderHitchARide()
	if hitchARideDesire > 0 then
		bot:Action_UseAbilityOnEntity(hitchARideAbility, hitchARideTarget)
		return
	end
	workHorseDesire, hitchARideTarget = X.ConsiderWorkHorse()
	if workHorseDesire > 0 then
		bot:Action_UseAbility(workHorseAbility)
		return
	end
	stampedeDesire = X.ConsiderStampede()
	if stampedeDesire > 0 then
		bot:Action_UseAbility(stampedeAbility)
		return
	end
	hoofStompDesire = X.ConsiderHoofStomp()
	if hoofStompDesire > 0 then
		bot:Action_UseAbility(hoofStompAbility)
		return
	end
	doubleEdgeDesire, doubleEdgeTarget = X.ConsiderDoubleEdge()
	-- Guard: never send the unit-target cast without a live target.
	if doubleEdgeDesire > 0 and Fu.IsValid(doubleEdgeTarget) then
		bot:Action_UseAbilityOnEntity(doubleEdgeAbility, doubleEdgeTarget)
		return
	end
end
-- [OHA-CENTAUR] stomp why=kill|group|fight heroes=N, at most once per 3s.
function X.LogStomp(why, heroes)
	if DotaTime() < (bot._stompLogAt or -999) then
		return
	end
	bot._stompLogAt = DotaTime() + 3
	pcall(
		print,
		string.format("[OHA-CENTAUR] t=%.0f stomp why=%s heroes=%d hp=%.2f", DotaTime(), why, heroes, Fu.GetHP(bot))
	)
end
function X.ConsiderHoofStomp()
	if not hoofStompAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
	end
	local radius = hoofStompAbility:GetSpecialValueInt("radius")
	local damage = hoofStompAbility:GetSpecialValueInt("stomp_damage")
	botTarget = Fu.GetProperTarget(bot)
	local nearbyEnemies = Fu.GetNearbyHeroes(bot, radius, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and not Fu.IsSuspiciousIllusion(enemyHero)
		then
			if enemyHero:IsChanneling() or Fu.IsCastingUltimateAbility(enemyHero) then
				return BOT_ACTION_DESIRE_HIGH
			end
			-- Kill range: stomp even through Shallow Grave and similar saves. The stun still holds
			-- him for the team; only an already disabled target is skipped.
			if Fu.CanKillTarget(enemyHero, damage, DAMAGE_TYPE_MAGICAL) and not Fu.IsDisabled(enemyHero) then
				X.LogStomp("kill", 1)
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	-- Team fight: the stun is an area. Two or more enemy heroes not already disabled within
	-- 275 (radius 325 less room for the 0.5s windup), or one in a team fight. The rule below
	-- only looked at the single target, so Centaur held the stomp with heroes all around him.
	do
		local stompable = 0
		for _, enemyHero in pairs(Fu.GetNearbyHeroes(bot, radius - 50, true, BOT_MODE_NONE) or {}) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and not Fu.IsDisabled(enemyHero)
				and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
			then
				stompable = stompable + 1
			end
		end
		if stompable >= 2 or isInTeamFight and stompable >= 1 then
			X.LogStomp(stompable >= 2 and "group" or "fight", stompable)
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if isEngaging then
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, radius - 100)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not Fu.IsDisabled(botTarget)
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			local nearbyAllies = Fu.GetNearbyHeroes(botTarget, 1200, true, BOT_MODE_NONE)
			local nearbyEnemies = Fu.GetNearbyHeroes(botTarget, 1200, false, BOT_MODE_NONE)
			if nearbyAllies ~= nil and nearbyEnemies ~= nil and #nearbyAllies >= #nearbyEnemies then
				if stampedeAbility:IsTrained() and stampedeAbility:IsFullyCastable() then
					if bot:GetMana() - hoofStompAbility:GetManaCost() > stampedeAbility:GetManaCost() then
						return BOT_ACTION_DESIRE_HIGH
					end
				else
					return BOT_ACTION_DESIRE_HIGH
				end
			end
		end
	end
	if isRetreating then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, 1200, false, BOT_MODE_NONE)
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE)
		if
			nearbyAllies ~= nil
			and nearbyEnemies ~= nil
			and Fu.IsValidHero(nearbyEnemies[1])
			and Fu.CanCastOnNonMagicImmune(nearbyEnemies[1])
			and Fu.IsInRange(bot, nearbyEnemies[1], radius)
			and Fu.IsChasingTarget(nearbyEnemies[1], bot)
			and not Fu.IsSuspiciousIllusion(nearbyEnemies[1])
			and not Fu.IsDisabled(nearbyEnemies[1])
			and not nearbyEnemies[1]:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			local chaserAllies = Fu.GetNearbyHeroes(nearbyEnemies[1], 1200, false, BOT_MODE_NONE)
			if chaserAllies ~= nil and (#chaserAllies > #nearbyAllies or bot:WasRecentlyDamagedByAnyHero(1.5)) then
				return BOT_ACTION_DESIRE_HIGH
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
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, radius) and isAttacking then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderDoubleEdge()
	if not doubleEdgeAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local strength = bot:GetAttributeValue(ATTRIBUTE_STRENGTH)
	local castRange = doubleEdgeAbility:GetCastRange()
	local attackRange = bot:GetAttackRange()
	local strengthDamageRatio = doubleEdgeAbility:GetSpecialValueInt("strength_damage") / 100
	local damage = doubleEdgeAbility:GetSpecialValueInt("edge_damage") + strength * strengthDamageRatio
	botTarget = Fu.GetProperTarget(bot)
	local nearbyEnemies = Fu.GetNearbyHeroes(bot, castRange + attackRange, true, BOT_MODE_NONE)
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
			and bot:GetHealth() > damage * 1.2
		then
			return BOT_ACTION_DESIRE_HIGH, enemyHero
		end
	end
	if isEngaging then
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange * 2)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
			and not botTarget:HasModifier("modifier_templar_assassin_refraction_absorb")
			and bot:GetHealth() > damage * 1.5
		then
			local nearbyAllies = Fu.GetNearbyHeroes(botTarget, 1200, true, BOT_MODE_NONE)
			local nearbyEnemies = Fu.GetNearbyHeroes(botTarget, 1200, false, BOT_MODE_NONE)
			if nearbyAllies ~= nil and nearbyEnemies ~= nil and #nearbyAllies >= #nearbyEnemies then
				return BOT_ACTION_DESIRE_HIGH, botTarget
			end
		end
	end
	if Fu.IsPushing(bot) or Fu.IsDefending(bot) then
		local laneCreeps = bot:GetNearbyLaneCreeps(castRange * 2, true)
		if
			laneCreeps ~= nil
			and #laneCreeps >= 3
			and Fu.CanBeAttacked(laneCreeps[1])
			and isAttacking
			and bot:GetHealth() > damage * 1.5
			and (bot:GetHealth() - damage) / bot:GetMaxHealth() > 0.5
			and Fu.GetHP(laneCreeps[1]) > 0.33
		then
			return BOT_ACTION_DESIRE_HIGH, laneCreeps[1]
		end
	end
	if Fu.IsFarming(bot) then
		if
			isAttacking
			and hpRatio > 0.3
			and bot:GetHealth() > damage * 1.5
			and (bot:GetHealth() - damage) / bot:GetMaxHealth() > 0.3
		then
			local neutralCreeps = bot:GetNearbyNeutralCreeps(castRange * 2)
			if neutralCreeps ~= nil and #neutralCreeps >= 1 and Fu.GetHP(neutralCreeps[1]) > 0.33 then
				return BOT_ACTION_DESIRE_HIGH, neutralCreeps[1]
			end
			local laneCreeps = bot:GetNearbyLaneCreeps(castRange * 2, true)
			if
				laneCreeps ~= nil
				and #laneCreeps >= 3
				and Fu.CanBeAttacked(laneCreeps[1])
				and Fu.GetHP(laneCreeps[1]) > 0.33
			then
				return BOT_ACTION_DESIRE_HIGH, laneCreeps[1]
			end
		end
	end
	if Fu.IsLaning(bot) then
		local killableCreepCount = 0
		local killableCreeps = {}
		local laneCreeps = bot:GetNearbyLaneCreeps(castRange * 2, true)
		for _, creep in pairs(laneCreeps) do
			if Fu.IsValid(creep) and creep:GetHealth() <= damage then
				killableCreepCount = killableCreepCount + 1
				table.insert(killableCreeps, creep)
			end
		end
		if
			killableCreepCount >= 2
			and Fu.CanBeAttacked(killableCreeps[1])
			and hpRatio > 0.3
			and bot:GetHealth() > damage * 1.5
			and (bot:GetHealth() - damage) / bot:GetMaxHealth() > 0.3
		then
			return BOT_ACTION_DESIRE_HIGH, killableCreeps[1]
		end
		local nearbyEnemies = Fu.GetEnemiesNearLoc(bot:GetLocation(), castRange + 75)
		if
			nearbyEnemies ~= nil
			and #nearbyEnemies >= 1
			and Fu.IsValidTarget(nearbyEnemies[1])
			and (bot:GetHealth() - damage) / bot:GetMaxHealth() > 0.65
		then
			return BOT_ACTION_DESIRE_HIGH, nearbyEnemies[1]
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if
			Fu.IsRoshan(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange * 2)
			and isAttacking
			and bot:GetHealth() > damage * 1.5
		then
			-- Return the target: this returned only the desire, so the caller cast Double Edge on
			-- nil ("nil-target" refusals). Double Edge is unit-target (datafeed behavior 40).
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if
			Fu.IsTormentor(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange * 2)
			and isAttacking
			and bot:GetHealth() > damage * 1.5
			and (bot:GetHealth() - damage) / bot:GetMaxHealth() > 0.45
		then
			-- Same nil-target fix as the Roshan branch above.
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.ConsiderStampede()
	if
		not stampedeAbility:IsFullyCastable()
		or bot:HasModifier("modifier_centaur_cart")
		or bot:HasModifier("modifier_centaur_stampede")
	then
		return BOT_ACTION_DESIRE_NONE
	end
	if isInTeamFight then
		local teamFightLocation = Fu.GetTeamFightLocation(bot)
		local nearbyEnemies = Fu.GetEnemiesNearLoc(bot:GetLocation(), 1200)
		if nearbyEnemies ~= nil and #nearbyEnemies >= 2 and teamFightLocation ~= nil then
			if Fu.GetLocationToLocationDistance(bot:GetLocation(), teamFightLocation) < 600 then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	if isRetreating then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, 1200, false, BOT_MODE_NONE)
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE)
		if
			nearbyAllies ~= nil
			and nearbyEnemies ~= nil
			and Fu.IsValidHero(nearbyEnemies[1])
			and Fu.IsInRange(bot, nearbyEnemies[1], 600)
			and Fu.IsChasingTarget(nearbyEnemies[1], bot)
			and not Fu.IsSuspiciousIllusion(nearbyEnemies[1])
			and not Fu.IsDisabled(nearbyEnemies[1])
		then
			local chaserAllies = Fu.GetNearbyHeroes(nearbyEnemies[1], 1200, false, BOT_MODE_NONE)
			if
				chaserAllies ~= nil
				and #chaserAllies > #nearbyAllies
				and #chaserAllies >= 2
				and #nearbyAllies <= 1
				and hpRatio < 0.5
			then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	-- Ally save: Stampede moves every allied hero (datafeed: "leads all allies"), but it was only
	-- cast for Centaur's own fight or escape. Cast it when an ally anywhere is low, retreating,
	-- being hit by heroes and has an enemy hero next to him.
	for _, allyHero in pairs(GetUnitList(UNIT_LIST_ALLIED_HEROES) or {}) do
		if
			allyHero ~= bot
			and Fu.IsValidHero(allyHero)
			and not allyHero:IsIllusion()
			and not allyHero:HasModifier("modifier_arc_warden_tempest_double")
			and Fu.GetHP(allyHero) < 0.35
			and allyHero:WasRecentlyDamagedByAnyHero(1.5)
			and Fu.IsRetreating(allyHero)
			and #Fu.GetEnemiesNearLoc(allyHero:GetLocation(), 600) >= 1
		then
			if DotaTime() >= (bot._stampedeSaveLogAt or -999) then
				bot._stampedeSaveLogAt = DotaTime() + 5
				pcall(
					print,
					string.format(
						"[OHA-CENTAUR] t=%.0f stampede save ally=%s hp=%.2f",
						DotaTime(),
						allyHero:GetUnitName(),
						Fu.GetHP(allyHero)
					)
				)
			end
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderWorkHorse()
	if
		not workHorseAbility:IsTrained()
		or not workHorseAbility:IsFullyCastable()
		or bot:HasModifier("modifier_centaur_stampede")
	then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	-- Team fight: Work Horse gives the Stampede run to Centaur only (datafeed), while Stampede
	-- carries every ally. The cart was cast first and then blocked Stampede (cart check there), so
	-- the team never got the charge. Use the cart in a fight only while Stampede is not ready.
	if isInTeamFight and not (stampedeAbility:IsTrained() and stampedeAbility:IsFullyCastable()) then
		local teamFightLocation = Fu.GetTeamFightLocation(bot)
		local nearbyEnemies = Fu.GetEnemiesNearLoc(bot:GetLocation(), 1200)
		if nearbyEnemies ~= nil and #nearbyEnemies >= 2 and teamFightLocation ~= nil then
			if Fu.GetLocationToLocationDistance(bot:GetLocation(), teamFightLocation) < 600 then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	if isRetreating then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, 1200, false, BOT_MODE_NONE)
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE)
		if
			nearbyAllies ~= nil
			and nearbyEnemies ~= nil
			and Fu.IsValidHero(nearbyEnemies[1])
			and Fu.IsInRange(bot, nearbyEnemies[1], 600)
			and Fu.IsChasingTarget(nearbyEnemies[1], bot)
			and not Fu.IsSuspiciousIllusion(nearbyEnemies[1])
			and not Fu.IsDisabled(nearbyEnemies[1])
		then
			local chaserAllies = Fu.GetNearbyHeroes(nearbyEnemies[1], 1200, false, BOT_MODE_NONE)
			if
				chaserAllies ~= nil
				and #chaserAllies > #nearbyAllies
				and #chaserAllies >= 2
				and #nearbyAllies <= 1
				and hpRatio < 0.5
			then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function X.ConsiderHitchARide()
	if hitchARideAbility:IsHidden() or not hitchARideAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castRange = hitchARideAbility:GetCastRange()
	if isEngaging or isInTeamFight then
		local nearbyAllies = Fu.GetAlliesNearLoc(bot:GetLocation(), castRange)
		for _, allyHero in pairs(nearbyAllies) do
			-- allyHero ~= bot: GetAlliesNearLoc includes Centaur himself; he cannot ride his own cart.
			if
				allyHero ~= bot
				and Fu.IsValidHero(allyHero)
				and allyHero:WasRecentlyDamagedByAnyHero(1.1)
				and Fu.GetHP(allyHero) < 0.5
				and not allyHero:IsIllusion()
				and not allyHero:HasModifier("modifier_arc_warden_tempest_double")
			then
				return BOT_ACTION_DESIRE_HIGH, allyHero
			end
		end
	end
	if isRetreating then
		local nearbyAllies = Fu.GetAlliesNearLoc(bot:GetLocation(), castRange)
		for _, allyHero in pairs(nearbyAllies) do
			-- allyHero ~= bot: same self-target guard (a retreating Centaur matched himself).
			if
				allyHero ~= bot
				and Fu.IsValidHero(allyHero)
				and Fu.IsRetreating(allyHero)
				and allyHero:WasRecentlyDamagedByAnyHero(1.1)
				and not allyHero:IsIllusion()
				and not allyHero:HasModifier("modifier_arc_warden_tempest_double")
			then
				return BOT_ACTION_DESIRE_HIGH, allyHero
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
return X
