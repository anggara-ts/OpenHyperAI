-- Puck: skill build, item build, and ability use for this hero.
local X = {}
local bot = GetBot()
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local AbilityContext = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local Minion = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local sTalentList = Fu.Skill.GetTalentList(bot)
local sAbilityList = Fu.Skill.GetAbilityList(bot)
local sRole = Fu.Item.GetRoleItemsBuyList(bot)
local tTalentTreeList = { ["t25"] = { 0, 10 }, ["t20"] = { 0, 10 }, ["t15"] = { 10, 0 }, ["t10"] = { 0, 10 } }
local tAllAbilityBuildList = { { 1, 3, 1, 2, 1, 6, 1, 2, 2, 2, 6, 3, 3, 3, 6 } }
local nAbilityBuildList = Fu.Skill.GetRandomBuild(tAllAbilityBuildList)
local nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList)
local sMagicImmuneItem = RandomInt(1, 2) == 1 and "item_black_king_bar" or "item_sphere"
local sRoleItemsBuyList = {}
-- Stratz 7.41f, week of 9 Nov 2026: pos 2, 50,775 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_2"] = {
	"item_tango",
	"item_double_branches",
	"item_faerie_fire",
	"item_magic_wand",
	"item_null_talisman",
	"item_power_treads",
	"item_witch_blade",
	"item_blink",
	"item_aghanims_shard",
	"item_devastator",
	sMagicImmuneItem,
	"item_ultimate_scepter",
	"item_greater_crit",
	"item_ultimate_scepter_2",
	"item_overwhelming_blink",
	"item_wind_waker",
	"item_moon_shard",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 1 has 251 matches, built from pos 2 (50,775) (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_1"] = sRoleItemsBuyList["pos_2"]
-- Stratz 7.41f, week of 9 Nov 2026: pos 3 has 532 matches, built from pos 2 (50,775) (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_3"] = sRoleItemsBuyList["pos_2"]
-- Pos 4/5: a support start (Stratz 7.41f pos 4, n=902: Tango 100%, Blood Grenade 47%, Magic Stick 47%,
-- Branches 70%) and the same core items (Blink 105%, Witch Blade 59%, Eul's 59%).
-- Stratz 7.41f, week of 9 Nov 2026: pos 4, 1,196 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_4"] = {
	"item_tango",
	"item_blood_grenade",
	"item_double_branches",
	"item_magic_stick",
	"item_faerie_fire",
	"item_null_talisman",
	"item_magic_wand",
	"item_power_treads",
	"item_blink",
	"item_cyclone",
	"item_aghanims_shard",
	"item_ultimate_scepter",
	"item_travel_boots",
	"item_octarine_core",
	"item_maelstrom",
	"item_mjollnir",
	"item_moon_shard",
	"item_ultimate_scepter_2",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 5 has 728 matches, built from pos 4 (1,196) (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_5"] = sRoleItemsBuyList["pos_4"]
X["sBuyList"] = sRoleItemsBuyList[sRole]
X["sSellList"] = { "item_black_king_bar", "item_quelling_blade" }
if Fu.Role.IsPvNMode() or Fu.Role.IsAllShadow() then
	X["sBuyList"], X["sSellList"] = { "PvN_mid" }, {}
end
nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"] =
	Fu.SetUserHeroInit(nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"])
X["sSkillList"] = Fu.Skill.GetSkillList(sAbilityList, nAbilityBuildList, sTalentList, nTalentBuildList)
X["bDeafaultAbility"] = false
-- Cast when cornered (retreating into 3+ enemies with no way out), before running further.
X["LastStandSpells"] = { { name = "puck_dream_coil", kind = "point" } }
X["bDeafaultItem"] = false
function X.MinionThink(minionUnit)
	Minion.MinionThink(minionUnit)
end
local illusoryOrbAbility = SafeAbility(bot:GetAbilityByName("puck_illusory_orb"), "puck_illusory_orb", "puck")
local waningRiftAbility = SafeAbility(bot:GetAbilityByName("puck_waning_rift"), "puck_waning_rift", "puck")
local phaseShiftAbility = SafeAbility(bot:GetAbilityByName("puck_phase_shift"), "puck_phase_shift", "puck")
local etherealJauntAbility = SafeAbility(bot:GetAbilityByName("puck_ethereal_jaunt"), "puck_ethereal_jaunt", "puck")
local dreamCoilAbility = SafeAbility(bot:GetAbilityByName("puck_dream_coil"), "puck_dream_coil", "puck")
local illusoryOrbDesire, illusoryOrbLocation
local waningRiftDesire, waningRiftLocation
local phaseShiftDesire
local etherealJauntDesire
local dreamCoilDesire, dreamCoilLocation
local phaseOrbDesire, phaseOrbLocation
local isOrbEscaping = false
local botTarget
local isGoingOnSomeone
local isRetreating
local isAttacking
local mpRatio
function X.SkillsComplement()
	if Fu.CanNotUseAbility(bot) then
		return
	end
	isGoingOnSomeone = Fu.IsGoingOnSomeone(bot)
	isRetreating = Fu.IsRetreating(bot)
	isAttacking = Fu.IsAttacking(bot)
	mpRatio = Fu.GetMP(bot)
	local phaseDuration
	phaseOrbDesire, phaseOrbLocation, phaseDuration = X.ConsiderPhaseOrb()
	if phaseOrbDesire > 0 then
		bot:Action_ClearActions(false)
		bot:ActionQueue_UseAbilityOnLocation(illusoryOrbAbility, phaseOrbLocation)
		bot:ActionQueue_Delay(0.1)
		bot:ActionQueue_UseAbility(phaseShiftAbility)
		bot:ActionQueue_Delay(phaseDuration - 0.3)
		bot:ActionQueue_UseAbility(etherealJauntAbility)
		return
	end
	illusoryOrbDesire, illusoryOrbLocation = X.ConsiderIllusoryOrb()
	if illusoryOrbDesire > 0 then
		bot:Action_UseAbilityOnLocation(illusoryOrbAbility, illusoryOrbLocation)
		return
	end
	phaseShiftDesire = X.ConsiderPhaseShift()
	if phaseShiftDesire > 0 then
		bot:Action_UseAbility(phaseShiftAbility)
		return
	end
	etherealJauntDesire = X.ConsiderEtherealJaunt()
	if etherealJauntDesire > 0 then
		bot:Action_UseAbility(etherealJauntAbility)
		return
	end
	dreamCoilDesire, dreamCoilLocation = X.ConsiderDreamCoil()
	if dreamCoilDesire > 0 then
		bot:Action_UseAbilityOnLocation(dreamCoilAbility, dreamCoilLocation)
		return
	end
	waningRiftDesire, waningRiftLocation = X.ConsiderWaningRift()
	if waningRiftDesire > 0 then
		bot:Action_UseAbilityOnLocation(waningRiftAbility, waningRiftLocation)
		return
	end
end
function X.ConsiderIllusoryOrb()
	if not illusoryOrbAbility:IsFullyCastable() or bot:HasModifier("modifier_puck_phase_shift") then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local castRange = Fu.GetProperCastRange(false, bot, illusoryOrbAbility:GetCastRange())
	local castPoint = illusoryOrbAbility:GetCastPoint()
	local radius = illusoryOrbAbility:GetSpecialValueInt("radius")
	local damage = illusoryOrbAbility:GetSpecialValueInt("damage")
	botTarget = Fu.GetProperTarget(bot)
	local nearbyEnemies = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and Fu.CanKillTarget(enemyHero, damage, DAMAGE_TYPE_MAGICAL)
			and not Fu.IsSuspiciousIllusion(enemyHero)
			and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
			and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
			and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
			and not enemyHero:HasModifier("modifier_templar_assassin_refraction_absorb")
		then
			return BOT_ACTION_DESIRE_HIGH, enemyHero:GetLocation()
		end
	end
	if Fu.IsStuck(bot) then
		local escapeLocation = Fu.GetEscapeLoc()
		return BOT_ACTION_DESIRE_HIGH, Fu.Site.GetXUnitsTowardsLocation(bot, escapeLocation, castRange)
	end
	if isGoingOnSomeone then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, 1000, false, BOT_MODE_NONE)
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
			and not botTarget:HasModifier("modifier_templar_assassin_refraction_absorb")
		then
			local targetAllies = Fu.GetNearbyHeroes(botTarget, 1000, false, BOT_MODE_NONE)
			if nearbyAllies ~= nil and targetAllies ~= nil and #nearbyAllies >= #targetAllies then
				return BOT_ACTION_DESIRE_HIGH, botTarget:GetExtrapolatedLocation(castPoint)
			end
		end
	end
	if isRetreating then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, 800, false, BOT_MODE_NONE)
		local nearbyEnemyHeroes = Fu.GetNearbyHeroes(bot, 1000, true, BOT_MODE_NONE)
		if
			nearbyAllies ~= nil
			and nearbyEnemyHeroes ~= nil
			and Fu.IsValidHero(nearbyEnemyHeroes[1])
			and not Fu.IsSuspiciousIllusion(nearbyEnemyHeroes[1])
		then
			local enemyAllies = Fu.GetNearbyHeroes(nearbyEnemyHeroes[1], 1000, false, BOT_MODE_NONE)
			if enemyAllies ~= nil and #enemyAllies > #nearbyAllies then
				isOrbEscaping = true
				local escapeLocation = Fu.GetEscapeLoc()
				return BOT_ACTION_DESIRE_HIGH, Fu.Site.GetXUnitsTowardsLocation(bot, escapeLocation, castRange)
			else
				isOrbEscaping = false
			end
		end
	end
	if Fu.IsPushing(bot) or Fu.IsDefending(bot) then
		local aoeLocation = bot:FindAoELocation(true, false, bot:GetLocation(), castRange, radius, castPoint, 0)
		local laneCreeps = bot:GetNearbyLaneCreeps(castRange, true)
		if laneCreeps ~= nil and #laneCreeps >= 4 and aoeLocation.count >= 4 then
			return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
		end
		aoeLocation = bot:FindAoELocation(true, true, bot:GetLocation(), castRange, radius, castPoint, 0)
		if aoeLocation.count >= 1 then
			return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
		end
	end
	if Fu.IsFarming(bot) then
		local aoeLocation = bot:FindAoELocation(true, false, bot:GetLocation(), castRange, radius, castPoint, 0)
		if isAttacking then
			local neutralCreeps = bot:GetNearbyNeutralCreeps(castRange)
			if
				neutralCreeps ~= nil
				and (
					#neutralCreeps >= 3 and aoeLocation.count >= 3
					or #neutralCreeps >= 2 and neutralCreeps[1]:IsAncientCreep() and aoeLocation.count >= 2
				)
			then
				return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
			end
			local laneCreeps = bot:GetNearbyLaneCreeps(castRange, true)
			if laneCreeps ~= nil and #laneCreeps >= 3 and aoeLocation.count >= 3 then
				return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
			end
		end
	end
	if Fu.IsLaning(bot) then
		local killableCreepCount = 0
		local killableCreeps = {}
		local laneCreeps = bot:GetNearbyLaneCreeps(castRange, true)
		local nearbyEnemyHeroes = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
		for _, creep in pairs(laneCreeps) do
			if Fu.IsValid(creep) and creep:GetHealth() <= damage then
				killableCreepCount = killableCreepCount + 1
				table.insert(killableCreeps, creep)
			end
		end
		if killableCreepCount >= 2 and mpRatio > 0.25 and nearbyEnemyHeroes ~= nil and #nearbyEnemyHeroes >= 1 then
			return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(killableCreeps)
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if
			Fu.IsRoshan(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, 500)
			and isAttacking
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, 400) and isAttacking then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.ConsiderWaningRift()
	if not waningRiftAbility:IsFullyCastable() or bot:HasModifier("modifier_puck_phase_shift") then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local castPoint = waningRiftAbility:GetCastPoint()
	local radius = waningRiftAbility:GetSpecialValueInt("radius")
	local damage = waningRiftAbility:GetSpecialValueInt("damage")
	botTarget = Fu.GetProperTarget(bot)
	local nearbyEnemies = Fu.GetNearbyHeroes(bot, radius + 200, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and Fu.CanKillTarget(enemyHero, damage, DAMAGE_TYPE_MAGICAL)
			and not Fu.IsSuspiciousIllusion(enemyHero)
			and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
			and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
			and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
			and not enemyHero:HasModifier("modifier_templar_assassin_refraction_absorb")
		then
			return BOT_ACTION_DESIRE_HIGH, enemyHero:GetLocation()
		end
	end
	if Fu.IsStuck(bot) then
		local escapeLocation = Fu.GetEscapeLoc()
		return BOT_ACTION_DESIRE_HIGH, Fu.Site.GetXUnitsTowardsLocation(bot, escapeLocation, radius)
	end
	if Fu.IsInTeamFight(bot, 1200) then
		local enemiesInRadius = Fu.GetEnemiesNearLoc(bot:GetLocation(), radius)
		if enemiesInRadius ~= nil and #enemiesInRadius >= 2 then
			return BOT_ACTION_DESIRE_HIGH, bot:GetLocation()
		end
	end
	if isGoingOnSomeone then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, 1200, false, BOT_MODE_NONE)
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, radius)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
			and not botTarget:HasModifier("modifier_templar_assassin_refraction_absorb")
		then
			local targetAllies = Fu.GetNearbyHeroes(botTarget, 1200, false, BOT_MODE_NONE)
			if nearbyAllies ~= nil and targetAllies ~= nil and #nearbyAllies >= #targetAllies then
				return BOT_ACTION_DESIRE_HIGH, botTarget:GetExtrapolatedLocation(castPoint)
			end
		end
	end
	if isRetreating then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, 1000, false, BOT_MODE_NONE)
		local nearbyEnemyHeroes = Fu.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE)
		if
			nearbyAllies ~= nil
			and nearbyEnemyHeroes ~= nil
			and Fu.IsValidHero(nearbyEnemyHeroes[1])
			and not Fu.IsSuspiciousIllusion(nearbyEnemyHeroes[1])
			and not Fu.IsDisabled(nearbyEnemyHeroes[1])
		then
			local enemyAllies = Fu.GetNearbyHeroes(nearbyEnemyHeroes[1], 1200, false, BOT_MODE_NONE)
			if
				enemyAllies ~= nil
				and (#enemyAllies > #nearbyAllies or Fu.GetHP(bot) < 0.65 and bot:WasRecentlyDamagedByAnyHero(2))
			then
				local escapeLocation = Fu.GetEscapeLoc()
				return BOT_ACTION_DESIRE_HIGH, Fu.Site.GetXUnitsTowardsLocation(bot, escapeLocation, radius)
			end
		end
	end
	if Fu.IsPushing(bot) or Fu.IsDefending(bot) then
		local aoeLocation =
			bot:FindAoELocation(true, false, bot:GetLocation(), bot:GetAttackRange() + 150, radius, 0, 0)
		local laneCreeps = bot:GetNearbyLaneCreeps(radius, true)
		if laneCreeps ~= nil and #laneCreeps >= 4 and aoeLocation.count >= 4 then
			return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
		end
	end
	if Fu.IsFarming(bot) then
		local aoeLocation =
			bot:FindAoELocation(true, false, bot:GetLocation(), bot:GetAttackRange() + 150, radius, 0, 0)
		if isAttacking then
			local neutralCreeps = bot:GetNearbyNeutralCreeps(radius)
			if
				neutralCreeps ~= nil
				and (
					#neutralCreeps >= 3 and aoeLocation.count >= 3
					or #neutralCreeps >= 2 and neutralCreeps[1]:IsAncientCreep() and aoeLocation.count >= 2
				)
			then
				return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
			end
			local laneCreeps = bot:GetNearbyLaneCreeps(radius, true)
			if laneCreeps ~= nil and #laneCreeps >= 3 and aoeLocation.count >= 3 then
				return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
			end
		end
	end
	if Fu.IsLaning(bot) then
		local killableCreepCount = 0
		local killableCreeps = {}
		local laneCreeps = bot:GetNearbyLaneCreeps(radius, true)
		local nearbyEnemyHeroes = Fu.GetNearbyHeroes(bot, 1000, true, BOT_MODE_NONE)
		for _, creep in pairs(laneCreeps) do
			if Fu.IsValid(creep) and creep:GetHealth() <= damage then
				killableCreepCount = killableCreepCount + 1
				table.insert(killableCreeps, creep)
			end
		end
		if killableCreepCount >= 2 and mpRatio > 0.25 and nearbyEnemyHeroes ~= nil and #nearbyEnemyHeroes >= 1 then
			return BOT_ACTION_DESIRE_HIGH, bot:GetLocation()
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if Fu.IsRoshan(botTarget) and Fu.IsInRange(bot, botTarget, 500) and isAttacking then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, 400) and isAttacking then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.ConsiderPhaseShift()
	if not phaseShiftAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
	end
	-- datafeed: Phase Shift duration is fractional (1/1.75/2.5/3.25s).
	local duration = phaseShiftAbility:GetSpecialValueFloat("duration")
	if Fu.IsStunProjectileIncoming(bot, 600) then
		return BOT_ACTION_DESIRE_HIGH
	end
	if Fu.IsUnitTargetProjectileIncoming(bot, 400) then
		return BOT_ACTION_DESIRE_HIGH
	end
	if not bot:HasModifier("modifier_sniper_assassinate") and not bot:IsMagicImmune() then
		if Fu.IsWillBeCastUnitTargetSpell(bot, 400) then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if isRetreating then
		-- Phase only to wait out a short blink lockout (damage puts Blink on a 3s cooldown) with an enemy
		-- near: a READY blink (cooldown 0) also passed "< duration", so Puck stood in Phase Shift
		-- instead of blinking away. The build buys Overwhelming Blink, so look for it too.
		local blinkSlot = bot:FindItemSlot("item_blink")
		if blinkSlot < 0 then
			blinkSlot = bot:FindItemSlot("item_overwhelming_blink")
		end
		local blinkItem = blinkSlot >= 0 and blinkSlot <= 5 and bot:GetItemInSlot(blinkSlot) or nil
		if
			blinkItem ~= nil
			and blinkItem:GetCooldownTimeRemaining() > 0
			and blinkItem:GetCooldownTimeRemaining() < duration
			and bot:WasRecentlyDamagedByAnyHero(1.0)
		then
			return BOT_ACTION_DESIRE_HIGH
		end
		local linearProjectiles = GetLinearProjectiles()
		for _, projectile in pairs(linearProjectiles) do
			-- ability can be nil on a linear projectile (hero_ancient_apparition guards it too)
			if
				projectile ~= nil
				and projectile.ability ~= nil
				and projectile.ability:GetName() == "puck_illusory_orb"
			then
				if GetUnitToLocationDistance(bot, projectile.location) < 300 then
					return BOT_ACTION_DESIRE_HIGH
				end
			end
		end
	end
	local nearbyEnemies = Fu.GetEnemiesNearLoc(bot:GetLocation(), 800)
	local nearbyAllies = Fu.GetNearbyHeroes(bot, 800, false, BOT_MODE_NONE)
	if
		nearbyEnemies ~= nil
		and #nearbyEnemies >= 2
		and nearbyAllies ~= nil
		and #nearbyEnemies > #nearbyAllies
		and bot:WasRecentlyDamagedByAnyHero(1.5)
	then
		return BOT_ACTION_DESIRE_HIGH
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderEtherealJaunt()
	if not etherealJauntAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
	end
	local attackRange = bot:GetAttackRange()
	botTarget = Fu.GetProperTarget(bot)
	if isGoingOnSomeone then
		if Fu.IsValidTarget(botTarget) and not Fu.IsInRange(bot, botTarget, attackRange) then
			local linearProjectiles = GetLinearProjectiles()
			local targetAllies = Fu.GetNearbyHeroes(botTarget, 1200, false, BOT_MODE_NONE)
			local targetEnemies = Fu.GetNearbyHeroes(botTarget, 1200, true, BOT_MODE_NONE)
			if targetEnemies ~= nil and targetAllies ~= nil and #targetEnemies >= #targetAllies then
				local targetTowers = botTarget:GetNearbyTowers(700, false)
				for _, projectile in pairs(linearProjectiles) do
					if
						projectile ~= nil
						and projectile.ability ~= nil
						and projectile.ability:GetName() == "puck_illusory_orb"
						and not Fu.IsLocationInChrono(projectile.location)
					then
						if Fu.IsInLaningPhase() then
							if targetTowers ~= nil and #targetTowers == 0 then
								if GetUnitToLocationDistance(botTarget, projectile.location) < attackRange * 1.15 then
									return BOT_ACTION_DESIRE_HIGH
								end
							end
						else
							if GetUnitToLocationDistance(botTarget, projectile.location) < attackRange * 1.15 then
								local alliesNearOrb = Fu.GetAlliesNearLoc(projectile.location, 700)
								local enemiesNearOrb = Fu.GetEnemiesNearLoc(projectile.location, 700)
								if #alliesNearOrb >= #enemiesNearOrb then
									if
										#alliesNearOrb <= 1
										and #enemiesNearOrb == 1
										and targetTowers ~= nil
										and #targetTowers == 0
									then
										-- was "#targetAllies == 0", never true (the target counts itself);
										-- the laning branch above checks the towers the same way.
										X.LogJaunt("solo-no-tower", botTarget)
										return BOT_ACTION_DESIRE_HIGH
									end
									if #alliesNearOrb >= 2 then
										return BOT_ACTION_DESIRE_HIGH
									end
								end
							end
						end
					end
				end
			end
		end
	end
	if isRetreating and isOrbEscaping then
		local linearProjectiles = GetLinearProjectiles()
		for _, projectile in pairs(linearProjectiles) do
			if
				projectile ~= nil
				and projectile.ability ~= nil
				and projectile.ability:GetName() == "puck_illusory_orb"
				and not Fu.IsLocationInChrono(projectile.location)
			then
				if GetUnitToLocationDistance(bot, projectile.location) > 600 then
					return BOT_ACTION_DESIRE_HIGH
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
-- [OHA-PUCK] Jaunt to the orb onto a lone target with no tower near it, at most once per 10s.
function X.LogJaunt(reason, target)
	if DotaTime() < (bot._jauntLogAt or -999) then
		return
	end
	bot._jauntLogAt = DotaTime() + 10
	pcall(
		print,
		string.format(
			"[OHA-PUCK] t=%.0f jaunt why=%s target=%s hp=%.2f",
			DotaTime(),
			reason,
			(string.gsub(target:GetUnitName(), "npc_dota_hero_", "")),
			Fu.GetHP(target)
		)
	)
end
-- [OHA-PUCK] pick-off Dream Coil on a lone target, at most once per 10s.
function X.LogCoil(reason, target)
	if DotaTime() < (bot._coilLogAt or -999) then
		return
	end
	bot._coilLogAt = DotaTime() + 10
	pcall(
		print,
		string.format(
			"[OHA-PUCK] t=%.0f coil why=%s target=%s hp=%.2f",
			DotaTime(),
			reason,
			(string.gsub(target:GetUnitName(), "npc_dota_hero_", "")),
			Fu.GetHP(target)
		)
	)
end
function X.ConsiderDreamCoil()
	if not dreamCoilAbility:IsFullyCastable() or bot:HasModifier("modifier_puck_phase_shift") then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local castRange = Fu.GetProperCastRange(false, bot, dreamCoilAbility:GetCastRange())
	local radius = dreamCoilAbility:GetSpecialValueInt("coil_radius")
	local duration = dreamCoilAbility:GetSpecialValueInt("coil_duration")
	if Fu.IsInTeamFight(bot, 1200) then
		local aoeLocation = bot:FindAoELocation(true, true, bot:GetLocation(), castRange, radius, 0, 0)
		local enemiesInRadius = Fu.GetEnemiesNearLoc(aoeLocation.targetloc, radius)
		if
			enemiesInRadius ~= nil
			and #enemiesInRadius >= 2
			and not Fu.IsLocationInChrono(aoeLocation.targetloc)
			and not Fu.IsLocationInBlackHole(aoeLocation.targetloc)
		then
			return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
		end
	end
	if isGoingOnSomeone then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, 1000, false, BOT_MODE_NONE)
		local strongestTarget = Fu.GetStrongestUnit(castRange, bot, true, false, duration)
		if
			Fu.IsValidTarget(strongestTarget)
			and Fu.CanCastOnNonMagicImmune(strongestTarget)
			and not Fu.IsSuspiciousIllusion(strongestTarget)
			and not Fu.IsDisabled(strongestTarget)
			and not Fu.IsLocationInChrono(strongestTarget:GetLocation())
			and not Fu.IsLocationInBlackHole(strongestTarget:GetLocation())
			and not strongestTarget:HasModifier("modifier_abaddon_borrowed_time")
			and not strongestTarget:HasModifier("modifier_dazzle_shallow_grave")
			and not strongestTarget:HasModifier("modifier_necrolyte_reapers_scythe")
			and not strongestTarget:HasModifier("modifier_oracle_false_promise_timer")
		then
			-- enemiesNearTarget was Puck's own allies again (same list as nearbyAllies), so "#enemiesNearTarget == 0" could never hold and this
			-- pick-off coil never fired. Now it is the enemy heroes near the target (the target included):
			-- coil a lone target.
			local enemiesNearTarget = Fu.GetEnemiesNearLoc(strongestTarget:GetLocation(), 1000)
			if nearbyAllies ~= nil and enemiesNearTarget and #nearbyAllies >= #enemiesNearTarget then
				if
					#nearbyAllies == 1
					and #enemiesNearTarget <= 1
					and Fu.GetHP(strongestTarget) > 0.55
					and isAttacking
				then
					X.LogCoil("solo", strongestTarget)
					return BOT_ACTION_DESIRE_HIGH, strongestTarget:GetLocation()
				end
				if
					#nearbyAllies >= 2
					and #enemiesNearTarget <= 1
					and Fu.GetHP(strongestTarget) > 0.2
					and Fu.IsRunning(strongestTarget)
					and not strongestTarget:IsFacingLocation(bot:GetLocation(), 90)
				then
					X.LogCoil("runner", strongestTarget)
					return BOT_ACTION_DESIRE_HIGH, strongestTarget:GetLocation()
				end
			end
		end
	end
	if isRetreating then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, 1000, false, BOT_MODE_NONE)
		local aoeLocation = bot:FindAoELocation(true, true, bot:GetLocation(), castRange, radius, 0, 0)
		local enemiesInRadius = Fu.GetEnemiesNearLoc(aoeLocation.targetloc, radius)
		local allyTowers = bot:GetNearbyTowers(700, false)
		if nearbyAllies ~= nil and enemiesInRadius ~= nil then
			if
				allyTowers ~= nil
				and #allyTowers == 0
				and #enemiesInRadius > #nearbyAllies
				and #enemiesInRadius >= 3
				and #nearbyAllies <= 1
				and GetUnitToLocationDistance(bot, aoeLocation.targetloc) < 700
				and GetUnitToLocationDistance(bot, GetAncient(GetTeam()):GetLocation()) > 3200
			then
				return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
local function CanDoPhaseOrb()
	if phaseShiftAbility:IsFullyCastable() and illusoryOrbAbility:IsFullyCastable() then
		local comboManaCost = phaseShiftAbility:GetManaCost() + illusoryOrbAbility:GetManaCost()
		if bot:GetMana() >= comboManaCost then
			return true
		end
	end
	return false
end
function X.ConsiderPhaseOrb()
	if CanDoPhaseOrb() then
		local castRange = Fu.GetProperCastRange(false, bot, illusoryOrbAbility:GetCastRange())
		-- datafeed: Phase Shift duration is 1/1.75/2.5/3.25s; read as a float so the Jaunt delay is not cut short.
		local phaseDuration = phaseShiftAbility:GetSpecialValueFloat("duration")
		local nearbyEnemies = Fu.GetEnemiesNearLoc(bot:GetLocation(), 800)
		local nearbyAllies = Fu.GetNearbyHeroes(bot, 800, false, BOT_MODE_NONE)
		-- Escape combo only when fleeing or hurt: without this Puck orbed away from every even 2v2+
		-- fight (it runs first, before Dream Coil) even while it was the one attacking.
		if
			nearbyEnemies ~= nil
			and #nearbyEnemies >= 2
			and nearbyAllies ~= nil
			and #nearbyEnemies >= #nearbyAllies
			and (isRetreating or Fu.GetHP(bot) < 0.4 and bot:WasRecentlyDamagedByAnyHero(2))
		then
			local escapeLocation = Fu.GetEscapeLoc()
			return BOT_ACTION_DESIRE_HIGH,
				Fu.Site.GetXUnitsTowardsLocation(bot, escapeLocation, castRange),
				phaseDuration
		end
		if isRetreating then
			local nearbyEnemyHeroes = Fu.GetNearbyHeroes(bot, 1000, true, BOT_MODE_NONE)
			if
				nearbyAllies ~= nil
				and nearbyEnemyHeroes ~= nil
				and Fu.IsValidHero(nearbyEnemyHeroes[1])
				and not Fu.IsSuspiciousIllusion(nearbyEnemyHeroes[1])
			then
				local enemyAllies = Fu.GetNearbyHeroes(nearbyEnemyHeroes[1], 1000, false, BOT_MODE_NONE)
				if enemyAllies ~= nil and #enemyAllies > #nearbyAllies then
					local escapeLocation = Fu.GetEscapeLoc()
					return BOT_ACTION_DESIRE_HIGH,
						Fu.Site.GetXUnitsTowardsLocation(bot, escapeLocation, castRange),
						phaseDuration
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
return X
