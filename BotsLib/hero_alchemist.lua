-- Alchemist: skill build, item build, and ability use for this hero.
local X = {}
local bot = GetBot()
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local AbilityContext = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local Minion = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local sTalentList = Fu.Skill.GetTalentList(bot)
local sAbilityList = Fu.Skill.GetAbilityList(bot)
local sRole = Fu.Item.GetRoleItemsBuyList(bot)
local tTalentTreeList = { ["t25"] = { 0, 10 }, ["t20"] = { 0, 10 }, ["t15"] = { 10, 0 }, ["t10"] = { 10, 0 } }
local tAllAbilityBuildList = { { 2, 1, 1, 2, 1, 6, 1, 2, 2, 3, 6, 3, 3, 3, 6 } }
local nAbilityBuildList = Fu.Skill.GetRandomBuild(tAllAbilityBuildList)
local nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList)
local sRoleItemsBuyList = {}
sRoleItemsBuyList["pos_1"] = {
	"item_bristleback_outfit",
	"item_soul_ring",
	"item_radiance",
	"item_travel_boots",
	"item_assault",
	"item_blink",
	"item_black_king_bar",
	"item_aghanims_shard",
	"item_abyssal_blade",
	"item_overwhelming_blink",
	"item_moon_shard",
	"item_ultimate_scepter_2",
	"item_travel_boots_2",
}
sRoleItemsBuyList["pos_2"] = sRoleItemsBuyList["pos_1"]
sRoleItemsBuyList["pos_4"] = sRoleItemsBuyList["pos_1"]
sRoleItemsBuyList["pos_5"] = sRoleItemsBuyList["pos_1"]
sRoleItemsBuyList["pos_3"] = sRoleItemsBuyList["pos_1"]
X["sBuyList"] = sRoleItemsBuyList[sRole]
X["sSellList"] = {
	"item_assault",
	"item_magic_wand",
	"item_abyssal_blade",
	"item_quelling_blade",
	"item_assault",
	"item_ancient_janggo",
	"item_assault",
	"item_soul_ring",
}
if Fu.Role.IsPvNMode() or Fu.Role.IsAllShadow() then
	X["sBuyList"], X["sSellList"] = { "PvN_antimage" }, {}
end
nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"] = Fu.SetUserHeroInit(nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"])
X["sSkillList"] = Fu.Skill.GetSkillList(sAbilityList, nAbilityBuildList, sTalentList, nTalentBuildList)
X["bDeafaultAbility"] = false
X["bDeafaultItem"] = false
function X.MinionThink(minionUnit)
	if Minion.IsValidUnit(minionUnit) then
		if Fu.IsValidHero(minionUnit) and minionUnit:IsIllusion() then
			Minion.IllusionThink(minionUnit)
		end
	end
end
local acidSprayAbility = SafeAbility(bot:GetAbilityByName("alchemist_acid_spray"), "alchemist_acid_spray", "alchemist")
local unstableConcoctionAbility = SafeAbility(bot:GetAbilityByName("alchemist_unstable_concoction"), "alchemist_unstable_concoction", "alchemist")
local unstableConcoctionThrowAbility = SafeAbility(
	bot:GetAbilityByName("alchemist_unstable_concoction_throw"),
	"alchemist_unstable_concoction_throw",
	"alchemist"
)
local chemicalRageAbility = SafeAbility(bot:GetAbilityByName("alchemist_chemical_rage"), "alchemist_chemical_rage", "alchemist")
local berserkPotionAbility = SafeAbility(bot:GetAbilityByName("alchemist_berserk_potion"), "alchemist_berserk_potion", "alchemist")
local acidSprayDesire, acidSprayLocation
local unstableConcoctionDesire
local unstableConcoctionThrowDesire, unstableConcoctionThrowTarget
local berserkPotionDesire, berserkPotionTarget
local chemicalRageDesire
local retreatThrowDelay = 2
local fullBrewThrowDelay = 4.25
local concoctionStartTime = 0
local botTarget
local isEngaging
local isRetreating
local isAttacking
local hpRatio
function X.SkillsComplement()
	if Fu.CanNotUseAbility(bot) then
		return
	end
	local context = AbilityContext.Build(bot)
	isEngaging = context.isEngaging
	isRetreating = context.isRetreating
	isAttacking = Fu.IsAttacking(bot)
	hpRatio = context.hp
	chemicalRageDesire = X.ConsiderChemicalRage()
	if chemicalRageDesire > 0 then
		bot:Action_UseAbility(chemicalRageAbility)
		return
	end
	unstableConcoctionThrowDesire, unstableConcoctionThrowTarget = X.ConsiderUnstableConcoctionThrow()
	if unstableConcoctionThrowDesire > 0 then
		bot:Action_UseAbilityOnEntity(unstableConcoctionThrowAbility, unstableConcoctionThrowTarget)
		return
	end
	unstableConcoctionDesire = X.ConsiderUnstableConcoction()
	if unstableConcoctionDesire > 0 then
		-- [OHA-ALCHEMIST]: the brew start (never happened before the cast-range fix), throttled to 10s.
		if DotaTime() >= (bot._alchBrewLogAt or -999) then
			bot._alchBrewLogAt = DotaTime() + 10
			pcall(print, string.format("[OHA-ALCHEMIST] t=%.0f concoction start range=%d brewRange=%d", DotaTime(), unstableConcoctionThrowAbility:GetCastRange(), unstableConcoctionAbility:GetCastRange()))
		end
		bot:Action_UseAbility(unstableConcoctionAbility)
		concoctionStartTime = DotaTime()
		return
	end
	acidSprayDesire, acidSprayLocation = X.ConsiderAcidSpray()
	if acidSprayDesire > 0 then
		Fu.SetQueuePtToINT(bot, false)
		bot:Action_UseAbilityOnLocation(acidSprayAbility, acidSprayLocation)
		return
	end
	berserkPotionDesire, berserkPotionTarget = X.ConsiderBerserkPotion()
	if berserkPotionDesire > 0 then
		bot:Action_UseAbilityOnEntity(berserkPotionAbility, berserkPotionTarget)
		return
	end
end
function X.ConsiderAcidSpray()
	if not acidSprayAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local castRange = acidSprayAbility:GetCastRange()
	local castPoint = acidSprayAbility:GetCastPoint()
	local radius = acidSprayAbility:GetSpecialValueInt("radius")
	botTarget = Fu.GetProperTarget(bot)
	if Fu.IsInTeamFight(bot, 1200) then
		local aoeLocation = bot:FindAoELocation(true, true, bot:GetLocation(), castRange, radius, castPoint, 0)
		if aoeLocation.count >= 2 then
			local enemiesInRadius = Fu.GetEnemiesNearLoc(aoeLocation.targetloc, radius)
			if enemiesInRadius ~= nil and #enemiesInRadius >= 2 then
				return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
			end
		end
	end
	if isEngaging then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, 900, false, BOT_MODE_NONE)
		-- fix: nInRangeEnemy was an undefined global here, so engaging never used Acid Spray
		local nInRangeEnemy = Fu.GetNearbyHeroes(bot, 900, true, BOT_MODE_NONE)
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			-- fix: dropped "target attacking and facing Alchemist": Acid Spray (armor reduction) was then
			-- never thrown on a target that runs, the usual case when Alchemist engages.
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not botTarget:HasModifier("modifier_dazzle_shallow_grave")
			and nearbyAllies ~= nil
			and nInRangeEnemy ~= nil
			and #nearbyAllies >= #nInRangeEnemy
		then
			local targetAllies = Fu.GetNearbyHeroes(botTarget, 900, false, BOT_MODE_NONE)
			if nearbyAllies ~= nil and targetAllies ~= nil and #nearbyAllies >= #targetAllies then
				return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
			end
		end
	end
	if isRetreating then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, 1000, false, BOT_MODE_NONE)
		local nInRangeEnemy = Fu.GetNearbyHeroes(bot, 1000, true, BOT_MODE_NONE)
		if
			nearbyAllies ~= nil
			and nInRangeEnemy
			and Fu.IsValidHero(nInRangeEnemy[1])
			and Fu.CanCastOnNonMagicImmune(nInRangeEnemy[1])
			and Fu.IsInRange(bot, nInRangeEnemy[1], 600)
			and Fu.IsRunning(nInRangeEnemy[1])
			and nInRangeEnemy[1]:IsFacingLocation(bot:GetLocation(), 30)
			and not Fu.IsSuspiciousIllusion(nInRangeEnemy[1])
			and not Fu.IsDisabled(nInRangeEnemy[1])
		then
			local targetAllies = Fu.GetNearbyHeroes(nInRangeEnemy[1], 800, false, BOT_MODE_NONE)
			if targetAllies ~= nil and (#targetAllies > #nearbyAllies or hpRatio < 0.45 and bot:WasRecentlyDamagedByAnyHero(2.5)) then
				return BOT_ACTION_DESIRE_HIGH, bot:GetLocation()
			end
		end
	end
	if Fu.IsDefending(bot) or Fu.IsPushing(bot) then
		local laneCreeps = bot:GetNearbyLaneCreeps(castRange, true)
		local aoeLocation = bot:FindAoELocation(true, false, bot:GetLocation(), castRange, radius, 0, 0)
		local allyLaneFront = GetLaneFrontLocation(GetTeam(), bot:GetAssignedLane(), 0)
		local enemyLaneFront = GetLaneFrontLocation(GetOpposingTeam(), bot:GetAssignedLane(), 0)
		if laneCreeps ~= nil and #laneCreeps >= 5 and aoeLocation.count >= 5 and Fu.GetLocationToLocationDistance(allyLaneFront, enemyLaneFront) < 150 then
			return BOT_ACTION_DESIRE_MODERATE, aoeLocation.targetloc
		end
	end
	if Fu.IsFarming(bot) then
		local aoeLocation = bot:FindAoELocation(true, false, bot:GetLocation(), castRange, radius, 0, 0)
		local neutralCreeps = bot:GetNearbyNeutralCreeps(600)
		local laneCreeps = bot:GetNearbyLaneCreeps(600, true)
		if isAttacking and Fu.GetMP(bot) > 0.33 then
			if neutralCreeps ~= nil and (#neutralCreeps >= 3 and aoeLocation.count >= 3 or #neutralCreeps >= 2 and aoeLocation.count >= 2 and neutralCreeps[1]:IsAncientCreep()) then
				return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
			end
			if laneCreeps ~= nil and #laneCreeps >= 4 and aoeLocation.count >= 4 then
				return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
			end
		end
	end
	if Fu.IsLaning(bot) then
		local laneCreeps = bot:GetNearbyLaneCreeps(600, true)
		local aoeLocation = bot:FindAoELocation(true, false, bot:GetLocation(), castRange, radius, 0, 0)
		if isAttacking and Fu.GetMP(bot) > 0.65 then
			if laneCreeps ~= nil and #laneCreeps >= 4 and aoeLocation.count >= 4 then
				return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
			end
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if Fu.IsRoshan(botTarget) and Fu.CanCastOnNonMagicImmune(botTarget) and Fu.IsInRange(bot, botTarget, 500) and isAttacking then
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
function X.ConsiderUnstableConcoction()
	if not unstableConcoctionAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
	end
	-- fix: Unstable Concoction is NO_TARGET with no AbilityCastRange (game data), so unstableConcoctionAbility:GetCastRange()
	-- was 0 and every check below (castRange, castRange - 200, castRange - 175) found nobody: the brew was never started.
	-- Use the throw's range (775), which is where the brew has to land.
	local castRange = unstableConcoctionThrowAbility:GetCastRange()
	local maxDamage = unstableConcoctionAbility:GetSpecialValueInt("max_damage")
	local nearbyEnemies = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and Fu.IsInRange(bot, enemyHero, castRange - 200)
			and not Fu.IsSuspiciousIllusion(enemyHero)
		then
			if enemyHero:IsChanneling() then
				return BOT_ACTION_DESIRE_HIGH
			end
			if
				Fu.CanKillTarget(enemyHero, maxDamage, DAMAGE_TYPE_PHYSICAL)
				and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
				and not enemyHero:HasModifier("modifier_abaddon_aphotic_shield")
				and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
				and not enemyHero:HasModifier("modifier_enigma_black_hole_pull")
				and not enemyHero:HasModifier("modifier_faceless_void_chronosphere_freeze")
				and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
				and not enemyHero:HasModifier("modifier_item_solar_crest_armor_addition")
			then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	if isEngaging then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, 1000, false, BOT_MODE_NONE)
		local nInRangeEnemy = Fu.GetNearbyHeroes(bot, castRange - 175, true, BOT_MODE_NONE)
		for _, enemyHero in pairs(nInRangeEnemy) do
			if
				Fu.IsValidTarget(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and not Fu.IsDisabled(enemyHero)
				and not enemyHero:HasModifier("modifier_enigma_black_hole_pull")
				and not enemyHero:HasModifier("modifier_faceless_void_chronosphere_freeze")
				and not enemyHero:HasModifier("modifier_legion_commander_duel")
				and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
			then
				local targetAllies = Fu.GetNearbyHeroes(enemyHero, 1000, false, BOT_MODE_NONE)
				if nearbyAllies ~= nil and targetAllies ~= nil and #nearbyAllies >= #targetAllies then
					return BOT_ACTION_DESIRE_HIGH, enemyHero
				end
			end
		end
	end
	if isRetreating then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, castRange + 175, false, BOT_MODE_NONE)
		local nInRangeEnemy = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
		if
			nearbyAllies ~= nil
			and nInRangeEnemy ~= nil
			and Fu.IsValidHero(nInRangeEnemy[1])
			and Fu.CanCastOnNonMagicImmune(nInRangeEnemy[1])
			and Fu.IsInRange(bot, nInRangeEnemy[1], castRange - 175)
			and Fu.IsRunning(nInRangeEnemy[1])
			and nInRangeEnemy[1]:IsFacingLocation(bot:GetLocation(), 30)
			and not Fu.IsSuspiciousIllusion(nInRangeEnemy[1])
			and not Fu.IsDisabled(nInRangeEnemy[1])
			and not nInRangeEnemy[1]:HasModifier("modifier_enigma_black_hole_pull")
			and not nInRangeEnemy[1]:HasModifier("modifier_faceless_void_chronosphere_freeze")
			and not nInRangeEnemy[1]:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			local targetAllies = Fu.GetNearbyHeroes(nInRangeEnemy[1], 800, false, BOT_MODE_NONE)
			if targetAllies ~= nil and (#targetAllies > #nearbyAllies or hpRatio < 0.6 and bot:WasRecentlyDamagedByAnyHero(2.2)) then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderUnstableConcoctionThrow()
	if unstableConcoctionThrowAbility:IsHidden() or not unstableConcoctionThrowAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castRange = unstableConcoctionThrowAbility:GetCastRange()
	local maxDamage = unstableConcoctionAbility:GetSpecialValueInt("max_damage")
	local nearbyEnemies = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and not Fu.IsSuspiciousIllusion(enemyHero)
			and DotaTime() >= concoctionStartTime + fullBrewThrowDelay
		then
			if enemyHero:IsChanneling() then
				return BOT_ACTION_DESIRE_HIGH, enemyHero
			end
			if
				Fu.CanKillTarget(enemyHero, maxDamage, DAMAGE_TYPE_PHYSICAL)
				and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
				and not enemyHero:HasModifier("modifier_abaddon_aphotic_shield")
				and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
				and not enemyHero:HasModifier("modifier_enigma_black_hole_pull")
				and not enemyHero:HasModifier("modifier_faceless_void_chronosphere_freeze")
				and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
				and not enemyHero:HasModifier("modifier_item_solar_crest_armor_addition")
			then
				return BOT_ACTION_DESIRE_HIGH, enemyHero
			end
		end
	end
	if isEngaging then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, 1000, false, BOT_MODE_NONE)
		local nInRangeEnemy = Fu.GetNearbyHeroes(bot, castRange - 175, true, BOT_MODE_NONE)
		for _, enemyHero in pairs(nInRangeEnemy) do
			if
				Fu.IsValidTarget(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and not Fu.IsDisabled(enemyHero)
				and not enemyHero:HasModifier("modifier_enigma_black_hole_pull")
				and not enemyHero:HasModifier("modifier_faceless_void_chronosphere_freeze")
				and not enemyHero:HasModifier("modifier_legion_commander_duel")
				and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
				and DotaTime() >= concoctionStartTime + fullBrewThrowDelay
			then
				local targetAllies = Fu.GetNearbyHeroes(enemyHero, 1000, false, BOT_MODE_NONE)
				if nearbyAllies ~= nil and targetAllies ~= nil and #nearbyAllies >= #targetAllies then
					return BOT_ACTION_DESIRE_HIGH, enemyHero
				end
			end
		end
	end
	if isRetreating then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, 800, false, BOT_MODE_NONE)
		local nInRangeEnemy = Fu.GetNearbyHeroes(bot, 1000, true, BOT_MODE_NONE)
		if
			nearbyAllies ~= nil
			and nInRangeEnemy ~= nil
			and Fu.IsValidHero(nInRangeEnemy[1])
			and Fu.CanCastOnNonMagicImmune(nInRangeEnemy[1])
			and Fu.IsInRange(bot, nInRangeEnemy[1], castRange)
			and not Fu.IsSuspiciousIllusion(nInRangeEnemy[1])
			and not nInRangeEnemy[1]:HasModifier("modifier_enigma_black_hole_pull")
			and not nInRangeEnemy[1]:HasModifier("modifier_faceless_void_chronosphere_freeze")
			and not nInRangeEnemy[1]:HasModifier("modifier_necrolyte_reapers_scythe")
			and DotaTime() >= concoctionStartTime + retreatThrowDelay
		then
			local targetAllies = Fu.GetNearbyHeroes(nInRangeEnemy[1], 800, false, BOT_MODE_NONE)
			if targetAllies ~= nil and (#targetAllies > #nearbyAllies or hpRatio < 0.6 and bot:WasRecentlyDamagedByAnyHero(2.2)) then
				return BOT_ACTION_DESIRE_HIGH, nInRangeEnemy[1]
			end
		end
	end
	-- Fallback: any hero in range. Game data (throw): brew_time 5.0 for the full stun/damage
	-- (max_stun 1.75-3.25 vs min 0.25), brew_explosion 7.0. It used the 2s gate (retreatThrowDelay), so whenever an
	-- enemy was in range it threw at ~2s, ahead of the 4.25s (fullBrewThrowDelay) kill/engage branches above. The 2s
	-- throw stays only for the retreat case (isRetreating) above.
	if nearbyEnemies ~= nil and #nearbyEnemies >= 1 and DotaTime() >= concoctionStartTime + fullBrewThrowDelay then
		for _, enemyHero in pairs(nearbyEnemies) do
			if Fu.IsValidHero(enemyHero) and Fu.CanCastOnNonMagicImmune(enemyHero) and not Fu.IsSuspiciousIllusion(enemyHero) then
				print(string.format("[OHA-ALCHEMIST] concoction throw why=fallback target=%s brewed=%.1fs",
					enemyHero:GetUnitName(), DotaTime() - concoctionStartTime))
				return BOT_ACTION_DESIRE_HIGH, enemyHero
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function X.ConsiderChemicalRage()
	if not chemicalRageAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
	end
	botTarget = Fu.GetProperTarget(bot)
	if Fu.IsInTeamFight(bot, 1200) then
		local enemiesNearby = Fu.GetEnemiesNearLoc(bot:GetLocation(), 700)
		if enemiesNearby ~= nil and #enemiesNearby >= 2 then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if isEngaging then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, 1000, false, BOT_MODE_NONE)
		if
			Fu.IsValidTarget(botTarget)
			and Fu.IsInRange(bot, botTarget, 800)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not botTarget:HasModifier("modifier_enigma_black_hole_pull")
			and not botTarget:HasModifier("modifier_faceless_void_chronosphere_freeze")
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			local targetAllies = Fu.GetNearbyHeroes(botTarget, 1000, false, BOT_MODE_NONE)
			if nearbyAllies ~= nil and targetAllies ~= nil and #nearbyAllies >= #targetAllies then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	if isRetreating then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, 800, false, BOT_MODE_NONE)
		local nInRangeEnemy = Fu.GetNearbyHeroes(bot, 800, true, BOT_MODE_NONE)
		if
			nearbyAllies ~= nil
			and nInRangeEnemy ~= nil
			and Fu.IsValidHero(nInRangeEnemy[1])
			and Fu.IsRunning(nInRangeEnemy[1])
			and nInRangeEnemy[1]:IsFacingLocation(bot:GetLocation(), 30)
			and not Fu.IsSuspiciousIllusion(nInRangeEnemy[1])
			and not Fu.IsDisabled(nInRangeEnemy[1])
			and not nInRangeEnemy[1]:HasModifier("modifier_enigma_black_hole_pull")
			and not nInRangeEnemy[1]:HasModifier("modifier_faceless_void_chronosphere_freeze")
			and not nInRangeEnemy[1]:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			local targetAllies = Fu.GetNearbyHeroes(nInRangeEnemy[1], 800, false, BOT_MODE_NONE)
			if targetAllies ~= nil and (#targetAllies > #nearbyAllies or hpRatio < 0.35 and bot:WasRecentlyDamagedByAnyHero(1.5)) then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	if Fu.IsFarming(bot) then
		if isAttacking and Fu.IsValid(botTarget) and botTarget:IsCreep() and hpRatio < 0.3 then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if
			Fu.IsRoshan(botTarget)
			and Fu.IsInRange(bot, botTarget, 500)
			and isAttacking
			and (Fu.IsModeTurbo() and DotaTime() < 15 * 60 or DotaTime() < 30 * 60)
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if
			Fu.IsTormentor(botTarget)
			and Fu.IsInRange(bot, botTarget, 400)
			and isAttacking
			and (Fu.IsModeTurbo() and DotaTime() < 16 * 60 or DotaTime() < 32 * 60)
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderBerserkPotion()
	if not berserkPotionAbility:IsTrained() or not berserkPotionAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castRange = berserkPotionAbility:GetCastRange()
	local nearbyAllies = Fu.GetNearbyHeroes(bot, castRange, false, BOT_MODE_NONE)
	for _, allyHero in pairs(nearbyAllies) do
		if
			Fu.IsValidHero(allyHero)
			and Fu.IsInRange(bot, allyHero, castRange)
			and not allyHero:HasModifier("modifier_legion_commander_press_the_attack")
			and not allyHero:HasModifier("modifier_item_satanic_unholy")
			and not allyHero:IsMagicImmune()
			and not allyHero:IsInvulnerable()
			and not allyHero:IsIllusion()
			and allyHero:CanBeSeen()
		then
			if Fu.IsDisabled(allyHero) then
				return BOT_ACTION_DESIRE_HIGH, allyHero
			end
			if
				Fu.IsRetreating(allyHero)
				and Fu.IsRunning(allyHero)
				and Fu.GetHP(allyHero) < 0.6
				and allyHero:WasRecentlyDamagedByAnyHero(2.5)
				and allyHero:IsFacingLocation(GetAncient(GetTeam()):GetLocation(), 45)
			then
				return BOT_ACTION_DESIRE_HIGH, allyHero
			end
			if Fu.IsGoingOnSomeone(allyHero) then
				local allyTarget = Fu.GetProperTarget(allyHero)
				if
					Fu.IsValidHero(allyTarget)
					and allyHero:IsFacingLocation(allyTarget:GetLocation(), 20)
					and Fu.IsInRange(allyHero, allyTarget, allyHero:GetAttackRange() + 100)
				then
					return BOT_ACTION_DESIRE_HIGH, allyHero
				end
				if Fu.GetHP(allyHero) < 0.33 then
					return BOT_ACTION_DESIRE_HIGH, allyHero
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
return X
