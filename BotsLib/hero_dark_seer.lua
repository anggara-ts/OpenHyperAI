-- Dark Seer: skill build, item build, and ability use for this hero.
-- Accidental globals made file-local (#13): every bot shares one Lua state, so these were shared.
local CanDoVacuumWall, HasBlink
local X = {}
local bot = GetBot()
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local AbilityContext = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local Minion = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local sTalentList = Fu.Skill.GetTalentList(bot)
local sAbilityList = Fu.Skill.GetAbilityList(bot)
local sRole = Fu.Item.GetRoleItemsBuyList(bot)
local tTalentTreeList = { ["t25"] = { 10, 0 }, ["t20"] = { 0, 10 }, ["t15"] = { 0, 10 }, ["t10"] = { 10, 0 } }
-- Wall of Replica moved to entry 11 (level 12); it sat at entry 12 (level 13), a level late.
local tAllAbilityBuildList = { { 2, 3, 2, 1, 2, 6, 2, 3, 3, 3, 6, 1, 1, 1, 6 } }
local nAbilityBuildList = Fu.Skill.GetRandomBuild(tAllAbilityBuildList)
local nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList)
local sRoleItemsBuyList = {}
local sUtilityList = { "item_crimson_guard", "item_lotus_orb", "item_heavens_halberd" }
local sUtility = sUtilityList[RandomInt(1, #sUtilityList)]
sRoleItemsBuyList["pos_3"] = {
	"item_tango",
	"item_double_branches",
	"item_magic_stick",
	"item_quelling_blade",
	"item_enchanted_mango",
	"item_magic_wand",
	"item_arcane_boots",
	"item_helm_of_the_dominator",
	"item_crimson_guard",
	"item_blink",
	"item_ultimate_scepter",
	"item_aghanims_shard",
	"item_black_king_bar",
	"item_shivas_guard",
	"item_sheepstick",
	"item_arcane_blink",
	"item_travel_boots",
	"item_moon_shard",
	"item_travel_boots_2",
	"item_ultimate_scepter_2",
}
sRoleItemsBuyList["pos_1"] = sRoleItemsBuyList["pos_3"]
sRoleItemsBuyList["pos_2"] = sRoleItemsBuyList["pos_3"]
sRoleItemsBuyList["pos_4"] = {
	"item_tango",
	"item_double_branches",
	"item_magic_stick",
	"item_quelling_blade",
	"item_enchanted_mango",
	"item_magic_wand",
	"item_arcane_boots",
	"item_veil_of_discord",
	"item_guardian_greaves",
	"item_blink",
	sUtility,
	"item_ultimate_scepter",
	"item_black_king_bar",
	"item_shivas_guard",
	"item_sheepstick",
	"item_arcane_blink",
	"item_ultimate_scepter_2",
	"item_aghanims_shard",
	"item_moon_shard",
}
sRoleItemsBuyList["pos_5"] = {
	"item_tango",
	"item_double_branches",
	"item_magic_stick",
	"item_quelling_blade",
	"item_enchanted_mango",
	"item_magic_wand",
	"item_arcane_boots",
	"item_veil_of_discord",
	"item_pipe",
	"item_blink",
	sUtility,
	"item_ultimate_scepter",
	"item_black_king_bar",
	"item_shivas_guard",
	"item_sheepstick",
	"item_arcane_blink",
	"item_ultimate_scepter_2",
	"item_aghanims_shard",
	"item_moon_shard",
}
X["sBuyList"] = sRoleItemsBuyList[sRole]
X["sSellList"] = { "item_ultimate_scepter", "item_magic_wand" }
if Fu.Role.IsPvNMode() or Fu.Role.IsAllShadow() then
	X["sBuyList"], X["sSellList"] = { "PvN_antimage" }, {}
end
nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"] =
	Fu.SetUserHeroInit(nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"])
X["sSkillList"] = Fu.Skill.GetSkillList(sAbilityList, nAbilityBuildList, sTalentList, nTalentBuildList)
X["bDeafaultAbility"] = false
-- Cast when cornered (retreating into 3+ enemies with no way out), before running further.
X["LastStandSpells"] = { { name = "dark_seer_wall_of_replica", kind = "point" } }
X["bDeafaultItem"] = false
function X.MinionThink(hMinionUnit)
	Minion.MinionThink(hMinionUnit)
end
local vacuumAbility = SafeAbility(bot:GetAbilityByName("dark_seer_vacuum"), "dark_seer_vacuum", "dark_seer")
local ionShellAbility = SafeAbility(bot:GetAbilityByName("dark_seer_ion_shell"), "dark_seer_ion_shell", "dark_seer")
local surgeAbility = SafeAbility(bot:GetAbilityByName("dark_seer_surge"), "dark_seer_surge", "dark_seer")
local wallOfReplicaAbility =
	SafeAbility(bot:GetAbilityByName("dark_seer_wall_of_replica"), "dark_seer_wall_of_replica", "dark_seer")
local vacuumDesire, vacuumLocation
local ionShellDesire, ionShellTarget
local surgeDesire, surgeTarget
local wallOfReplicaDesire, wallOfReplicaLocation
local vacuumWallDesire, vacuumWallLocation
local blinkItem
local botTarget
if bot.shouldBlink == nil then
	bot.shouldBlink = false
end
local isEngaging
local isInTeamFight
function X.SkillsComplement()
	if Fu.CanNotUseAbility(bot) then
		return
	end
	local context = AbilityContext.Build(bot)
	isEngaging = context.isEngaging
	isInTeamFight = context.isTeamFight
	botTarget = context.target
	vacuumWallDesire, vacuumWallLocation = X.ConsiderVacuumWall()
	if vacuumWallDesire > 0 then
		if DotaTime() >= (bot._vacWallLogAt or -999) then
			bot._vacWallLogAt = DotaTime() + 5
			pcall(
				print,
				string.format(
					"[OHA-DARK_SEER] t=%.0f blink-vacuum-wall dist=%d",
					DotaTime(),
					GetUnitToLocationDistance(bot, vacuumWallLocation)
				)
			)
		end
		bot:Action_ClearActions(false)
		bot:ActionQueue_UseAbilityOnLocation(blinkItem, vacuumWallLocation)
		bot:ActionQueue_Delay(0.1)
		bot:ActionQueue_UseAbilityOnLocation(vacuumAbility, vacuumWallLocation)
		bot:ActionQueue_Delay(0.8)
		bot:ActionQueue_UseAbilityOnLocation(wallOfReplicaAbility, vacuumWallLocation)
		bot:ActionQueue_Delay(0.93)
		return
	end
	vacuumDesire, vacuumLocation = X.ConsiderVacuum()
	if vacuumDesire > 0 then
		bot:Action_UseAbilityOnLocation(vacuumAbility, vacuumLocation)
		return
	end
	wallOfReplicaDesire, wallOfReplicaLocation = X.ConsiderWallOfReplica()
	if wallOfReplicaDesire > 0 then
		bot:Action_UseAbilityOnLocation(wallOfReplicaAbility, wallOfReplicaLocation)
		return
	end
	surgeDesire, surgeTarget = X.ConsiderSurge()
	if surgeDesire > 0 then
		bot:Action_UseAbilityOnEntity(surgeAbility, surgeTarget)
		return
	end
	ionShellDesire, ionShellTarget = X.ConsiderIonShell()
	if ionShellDesire > 0 then
		bot:Action_UseAbilityOnEntity(ionShellAbility, ionShellTarget)
		return
	end
end
function X.ConsiderVacuum()
	if not vacuumAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local castRange = Fu.GetProperCastRange(false, bot, vacuumAbility:GetCastRange())
	local castPoint = vacuumAbility:GetCastPoint()
	local radius = vacuumAbility:GetSpecialValueInt("radius")
	local damage = vacuumAbility:GetSpecialValueInt("damage")
	local enemiesInRange = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(enemiesInRange) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and Fu.CanKillTarget(enemyHero, damage, DAMAGE_TYPE_MAGICAL)
			and not isInTeamFight
			and not Fu.IsSuspiciousIllusion(enemyHero)
			and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
			and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
			and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
			and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
			and not enemyHero:HasModifier("modifier_templar_assassin_refraction_absorb")
		then
			return BOT_ACTION_DESIRE_HIGH, enemyHero:GetLocation()
		end
	end
	if isInTeamFight and not CanDoVacuumWall() then
		local aoeLocation = bot:FindAoELocation(true, true, bot:GetLocation(), castRange, radius, castPoint, 0)
		local enemiesInAoe = Fu.GetEnemiesNearLoc(aoeLocation.targetloc, radius)
		if enemiesInAoe ~= nil and #enemiesInAoe >= 2 then
			return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(enemiesInAoe)
		end
	end
	if isEngaging then
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange + radius)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not botTarget:HasModifier("modifier_enigma_black_hole_pull")
			and not botTarget:HasModifier("modifier_faceless_void_chronosphere_freeze")
			and not botTarget:HasModifier("modifier_legion_commander_duel")
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			local alliesNearTarget = Fu.GetNearbyHeroes(botTarget, 1200, true, BOT_MODE_NONE)
			local enemiesNearTarget = Fu.GetNearbyHeroes(botTarget, 1200, false, BOT_MODE_NONE)
			if alliesNearTarget ~= nil and enemiesNearTarget ~= nil and #alliesNearTarget >= #enemiesNearTarget then
				if not Fu.IsInRange(bot, botTarget, castRange) then
					return BOT_ACTION_DESIRE_HIGH,
						Fu.Site.GetXUnitsTowardsLocation(bot, botTarget:GetLocation(), castRange)
				else
					return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.ConsiderIonShell()
	if not ionShellAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castRange = Fu.GetProperCastRange(false, bot, ionShellAbility:GetCastRange())
	local radius = ionShellAbility:GetSpecialValueInt("radius")
	local abilityLevel = ionShellAbility:GetLevel()
	if isEngaging then
		local shellTarget = nil
		local mostAttackers = 1
		local nearbyAllies = Fu.GetNearbyHeroes(bot, castRange, false, BOT_MODE_NONE)
		if nearbyAllies ~= nil and #nearbyAllies >= 1 then
			for _, allyHero in pairs(nearbyAllies) do
				if
					Fu.IsValid(allyHero)
					and not allyHero:IsIllusion()
					and not allyHero:HasModifier("modifier_dark_seer_ion_shell")
					and not allyHero:HasModifier("modifier_necrolyte_reapers_scythe")
				then
					local attackerCount = 0
					local enemiesNearAlly = Fu.GetNearbyHeroes(allyHero, 1200, true, BOT_MODE_NONE)
					local enemyCreepsNearAlly = allyHero:GetNearbyCreeps(1200, true)
					for _, enemyHero in pairs(enemiesNearAlly) do
						if
							enemyHero ~= nil
							and enemyHero:IsAlive()
							and enemyHero:GetAttackTarget() == allyHero
							and not Fu.IsSuspiciousIllusion(enemyHero)
							and allyHero:GetAttackRange() <= 326
						then
							attackerCount = attackerCount + 1
						end
					end
					for _, creep in pairs(enemyCreepsNearAlly) do
						if
							creep ~= nil
							and creep:IsAlive()
							and creep:GetAttackTarget() == allyHero
							and creep:GetAttackRange() <= 326
						then
							attackerCount = attackerCount + 1
						end
					end
					if attackerCount > mostAttackers then
						mostAttackers = attackerCount
						shellTarget = allyHero
					end
				end
			end
		else
			if
				Fu.IsValidTarget(botTarget)
				and Fu.IsInRange(bot, botTarget, radius)
				and not Fu.IsSuspiciousIllusion(botTarget)
				and not bot:HasModifier("modifier_dark_seer_ion_shell")
			then
				shellTarget = bot
			end
		end
		-- nearbyAllies always holds Dark Seer himself, so the "no allies: shell myself" branch above never ran
		-- and in a fight the shell went out only on a melee ally hit by 2+ units. Fall back to the
		-- unshelled ally hero (self included) closest to the target, once within shell radius +150.
		if shellTarget == nil and Fu.IsValidTarget(botTarget) and not Fu.IsSuspiciousIllusion(botTarget) then
			local best = nil
			for _, allyHero in pairs(nearbyAllies or {}) do
				if
					Fu.IsValidHero(allyHero)
					and not allyHero:IsIllusion()
					and not allyHero:HasModifier("modifier_dark_seer_ion_shell")
					and not allyHero:HasModifier("modifier_necrolyte_reapers_scythe")
					and GetUnitToUnitDistance(allyHero, botTarget) <= radius + 150
					and (
						best == nil
						or GetUnitToUnitDistance(allyHero, botTarget) < GetUnitToUnitDistance(best, botTarget)
					)
				then
					best = allyHero
				end
			end
			shellTarget = best
			if shellTarget ~= nil and DotaTime() >= (bot._shellFallbackLogAt or -999) then
				bot._shellFallbackLogAt = DotaTime() + 5
				pcall(
					print,
					string.format(
						"[OHA-DARK_SEER] t=%.0f ion shell fight fallback on=%s",
						DotaTime(),
						shellTarget:GetUnitName()
					)
				)
			end
		end
		if shellTarget ~= nil then
			return BOT_ACTION_DESIRE_HIGH, shellTarget
		end
	end
	if Fu.IsRetreating(bot) and bot:GetActiveModeDesire() > 0.75 and not vacuumAbility:IsFullyCastable() then
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, radius, true, BOT_MODE_NONE)
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.IsChasingTarget(enemyHero, bot)
				and not bot:HasModifier("modifier_dark_seer_ion_shell")
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and not Fu.IsDisabled(enemyHero)
				and not Fu.IsRealInvisible(bot)
			then
				local chaserEnemies = Fu.GetNearbyHeroes(enemyHero, 1200, true, BOT_MODE_NONE)
				local chaserAllies = Fu.GetNearbyHeroes(enemyHero, 1200, false, BOT_MODE_NONE)
				if
					chaserEnemies ~= nil
					and chaserAllies ~= nil
					and (#chaserAllies > #chaserEnemies or bot:WasRecentlyDamagedByAnyHero(2))
				then
					return BOT_ACTION_DESIRE_HIGH, bot
				end
			end
		end
	end
	if Fu.IsPushing(bot) or Fu.IsDefending(bot) then
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE)
		if nearbyEnemies ~= nil and #nearbyEnemies == 0 then
			local allyLaneCreeps = bot:GetNearbyLaneCreeps(castRange, false)
			if allyLaneCreeps ~= nil and #allyLaneCreeps >= 1 then
				local frontCreep = nil
				local farthestFromFountain = 0
				for _, creep in pairs(allyLaneCreeps) do
					if
						Fu.IsValid(creep)
						and Fu.GetHP(creep) > 0.75
						and creep:DistanceFromFountain() > farthestFromFountain
						and creep:GetAttackRange() <= 326
						and not creep:HasModifier("modifier_dark_seer_ion_shell")
					then
						frontCreep = creep
						farthestFromFountain = creep:DistanceFromFountain()
					end
				end
				if frontCreep ~= nil then
					return BOT_ACTION_DESIRE_HIGH, frontCreep
				end
			end
		end
	end
	if Fu.IsFarming(bot) then
		local attackTarget = bot:GetAttackTarget()
		local neutralCreeps = bot:GetNearbyNeutralCreeps(radius + bot:GetAttackRange())
		if Fu.IsValid(attackTarget) and attackTarget:IsCreep() and neutralCreeps ~= nil and #neutralCreeps >= 2 then
			if not bot:HasModifier("modifier_dark_seer_ion_shell") then
				return BOT_ACTION_DESIRE_HIGH, bot
			end
		end
	end
	if Fu.IsLaning(bot) then
		local laneCreeps = bot:GetNearbyLaneCreeps(radius, true)
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE)
		local enemyTowers = bot:GetNearbyTowers(700, true)
		-- #enemyTowers == 0: the tower list was fetched but #nearbyEnemies was tested twice, so he shelled under towers.
		if
			laneCreeps ~= nil
			and #laneCreeps >= 3
			and nearbyEnemies ~= nil
			and #nearbyEnemies == 0
			and enemyTowers ~= nil
			and #enemyTowers == 0
			and abilityLevel >= 2
		then
			if
				Fu.IsAttacking(bot)
				and Fu.CanBeAttacked(laneCreeps[1])
				and not bot:HasModifier("modifier_dark_seer_ion_shell")
			then
				return BOT_ACTION_DESIRE_HIGH, bot
			end
		end
	end
	if Fu.IsDoingRoshan(bot) or Fu.IsDoingTormentor(bot) then
		if
			(Fu.IsRoshan(botTarget) or Fu.IsTormentor(botTarget))
			and Fu.IsInRange(bot, botTarget, radius)
			and Fu.IsAttacking(bot)
			and not bot:HasModifier("modifier_dark_seer_ion_shell")
		then
			return BOT_ACTION_DESIRE_HIGH, bot
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function X.ConsiderSurge()
	if not surgeAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castRange = Fu.GetProperCastRange(false, bot, surgeAbility:GetCastRange())
	local abilityLevel = surgeAbility:GetLevel()
	local roshanLocation = Fu.GetCurrentRoshanLocation()
	local tormentorLocation = Fu.GetTormentorLocation(GetTeam())
	if isEngaging then
		if
			Fu.IsValidTarget(botTarget)
			and Fu.IsInRange(bot, botTarget, 1200)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not botTarget:HasModifier("modifier_faceless_void_chronosphere_freeze")
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			local nearbyAllies = Fu.GetNearbyHeroes(bot, 1200, false, BOT_MODE_NONE)
			local closestDistance = GetUnitToUnitDistance(bot, botTarget)
			local bestAlly = bot
			for _, allyHero in pairs(nearbyAllies) do
				local allyTarget = Fu.GetProperTarget(allyHero)
				local allyDistance = GetUnitToUnitDistance(allyHero, botTarget)
				if
					allyDistance < closestDistance
					and allyDistance < castRange
					and Fu.IsValidTarget(allyTarget)
					and not Fu.IsSuspiciousIllusion(allyTarget)
					and not allyTarget:HasModifier("modifier_faceless_void_chronosphere_freeze")
					and not allyTarget:HasModifier("modifier_necrolyte_reapers_scythe")
					and allyHero:IsFacingLocation(allyTarget:GetLocation(), 30)
				then
					closestDistance = allyDistance
					bestAlly = allyHero
				end
			end
			return BOT_ACTION_DESIRE_HIGH, bestAlly
		end
	end
	if Fu.IsRetreating(bot) and bot:GetActiveModeDesire() > 0.75 then
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE)
		for _, enemyHero in pairs(nearbyEnemies) do
			-- Surge is self-cast here: the chaser being magic immune and Dark Seer wearing his own Ion
			-- Shell (both copied from the shell branch) have nothing to do with it, and the shell check
			-- stopped the escape whenever he had shelled himself.
			if
				Fu.IsValidHero(enemyHero)
				and Fu.IsChasingTarget(enemyHero, bot)
				and Fu.IsInRange(bot, enemyHero, 600)
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and not Fu.IsDisabled(enemyHero)
				and not Fu.IsRealInvisible(bot)
			then
				local chaserEnemies = Fu.GetNearbyHeroes(enemyHero, 1200, true, BOT_MODE_NONE)
				local chaserAllies = Fu.GetNearbyHeroes(enemyHero, 1200, false, BOT_MODE_NONE)
				if
					chaserEnemies ~= nil
					and chaserAllies ~= nil
					and (#chaserAllies > #chaserEnemies or bot:WasRecentlyDamagedByAnyHero(1.5))
				then
					return BOT_ACTION_DESIRE_HIGH, bot
				end
			end
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if
			GetUnitToLocationDistance(bot, roshanLocation) > 1600
			and Fu.GetManaAfter(surgeAbility:GetManaCost()) * bot:GetMana() > vacuumAbility:GetManaCost()
			and Fu.GetManaAfter(surgeAbility:GetManaCost()) * bot:GetMana() > wallOfReplicaAbility:GetManaCost()
			and abilityLevel >= 3
		then
			return BOT_ACTION_DESIRE_HIGH, bot
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if
			GetUnitToLocationDistance(bot, tormentorLocation) > 1600
			and Fu.GetManaAfter(surgeAbility:GetManaCost()) * bot:GetMana() > vacuumAbility:GetManaCost()
			and Fu.GetManaAfter(surgeAbility:GetManaCost()) * bot:GetMana() > wallOfReplicaAbility:GetManaCost()
			and abilityLevel >= 2
		then
			return BOT_ACTION_DESIRE_HIGH, bot
		end
	end
	local alliesInRange = Fu.GetNearbyHeroes(bot, castRange, false, BOT_MODE_NONE)
	for _, allyHero in pairs(alliesInRange) do
		local enemiesNearAlly = Fu.GetNearbyHeroes(allyHero, 1200, true, BOT_MODE_NONE)
		if
			Fu.IsValidHero(allyHero)
			and Fu.IsRetreating(allyHero)
			and allyHero:WasRecentlyDamagedByAnyHero(1.5)
			and not allyHero:IsIllusion()
		then
			if
				enemiesNearAlly ~= nil
				and #enemiesNearAlly >= 1
				and Fu.IsValidHero(enemiesNearAlly[1])
				and Fu.IsInRange(bot, enemiesNearAlly[1], castRange)
				and Fu.IsChasingTarget(enemiesNearAlly[1], allyHero)
				and allyHero:GetCurrentMovementSpeed() < enemiesNearAlly[1]:GetCurrentMovementSpeed()
				and allyHero:IsFacingLocation(Fu.GetTeamFountain(), 30)
				and not Fu.IsDisabled(enemiesNearAlly[1])
				and not Fu.IsTaunted(enemiesNearAlly[1])
				and not Fu.IsSuspiciousIllusion(enemiesNearAlly[1])
				and not enemiesNearAlly[1]:HasModifier("modifier_necrolyte_reapers_scythe")
			then
				return BOT_ACTION_DESIRE_HIGH, allyHero
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function X.ConsiderWallOfReplica()
	if not wallOfReplicaAbility:IsFullyCastable() or CanDoVacuumWall() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local castRange = Fu.GetProperCastRange(false, bot, wallOfReplicaAbility:GetCastRange())
	local castPoint = wallOfReplicaAbility:GetCastPoint() + 0.73
	local radius = vacuumAbility:GetSpecialValueInt("radius")
	if isInTeamFight then
		local aoeLocation = bot:FindAoELocation(true, true, bot:GetLocation(), castRange, radius, castPoint, 0)
		local enemiesInAoe = Fu.GetEnemiesNearLoc(aoeLocation.targetloc, radius)
		if enemiesInAoe ~= nil and #enemiesInAoe >= 2 then
			return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(enemiesInAoe)
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.ConsiderVacuumWall()
	if CanDoVacuumWall() then
		local castPoint = wallOfReplicaAbility:GetCastPoint() + 0.73
		-- The combo blinks onto the spot first, so search within Blink range (1200), not Vacuum's
		-- 450-600: with Vacuum range the Blink only fired on fights already next to Dark Seer.
		local searchRange = math.max(Fu.GetProperCastRange(false, bot, vacuumAbility:GetCastRange()), 1150)
		local radius = vacuumAbility:GetSpecialValueInt("radius")
		if Fu.IsInTeamFight(bot, 1600) then
			local aoeLocation = bot:FindAoELocation(true, true, bot:GetLocation(), searchRange, radius, castPoint, 0)
			local enemiesInAoe = Fu.GetEnemiesNearLoc(aoeLocation.targetloc, radius)
			if enemiesInAoe ~= nil and #enemiesInAoe >= 2 then
				return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(enemiesInAoe)
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function CanDoVacuumWall()
	if vacuumAbility:IsFullyCastable() and wallOfReplicaAbility:IsFullyCastable() and HasBlink() then
		local comboManaCost = vacuumAbility:GetManaCost() + wallOfReplicaAbility:GetManaCost()
		if bot:GetMana() >= comboManaCost then
			bot.shouldBlink = true
			return true
		end
	end
	-- was true here too, which left shouldBlink stuck on and blocked the generic engage blink for Dark Seer
	bot.shouldBlink = false
	return false
end
function HasBlink()
	local blink = nil
	for slot = 0, 5 do
		local item = bot:GetItemInSlot(slot)
		if
			item ~= nil
			and (
				item:GetName() == "item_blink"
				or item:GetName() == "item_overwhelming_blink"
				or item:GetName() == "item_arcane_blink"
				or item:GetName() == "item_swift_blink"
			)
		then
			blink = item
			break
		end
	end
	if blink ~= nil and blink:IsFullyCastable() then
		blinkItem = blink
		return true
	end
	return false
end
return X
