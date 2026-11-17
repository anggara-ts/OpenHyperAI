-- Tiny: skill build, item build, and ability use for this hero.
local X = {}
local bot = GetBot()
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local AbilityContext = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local Minion = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local sTalentList = Fu.Skill.GetTalentList(bot)
local sAbilityList = Fu.Skill.GetAbilityList(bot)
local sRole = Fu.Item.GetRoleItemsBuyList(bot)
local tTalentTreeList = {
	{ ["t25"] = { 10, 0 }, ["t20"] = { 0, 10 }, ["t15"] = { 0, 10 }, ["t10"] = { 10, 0 } },
	{ ["t25"] = { 10, 0 }, ["t20"] = { 0, 10 }, ["t15"] = { 10, 0 }, ["t10"] = { 10, 0 } },
}
local tAllAbilityBuildList =
	{ { 3, 1, 3, 2, 3, 6, 3, 1, 1, 1, 6, 2, 2, 2, 6 }, { 3, 1, 1, 2, 1, 6, 1, 2, 2, 2, 6, 3, 3, 3, 6 } }
local nAbilityBuildList
local nTalentBuildList
if sRole == "pos_1" then
	nAbilityBuildList = tAllAbilityBuildList[1]
	nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList[1])
else
	nAbilityBuildList = tAllAbilityBuildList[2]
	nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList[2])
end
local sRoleItemsBuyList = {}
sRoleItemsBuyList["pos_1"] = {
	"item_tango",
	"item_quelling_blade",
	"item_slippers",
	"item_circlet",
	"item_double_branches",
	"item_wraith_band",
	"item_magic_wand",
	"item_hand_of_midas",
	"item_power_treads",
	"item_echo_sabre",
	"item_blink",
	"item_black_king_bar",
	"item_aghanims_shard",
	"item_greater_crit",
	"item_harpoon",
	"item_satanic",
	"item_moon_shard",
	"item_swift_blink",
	"item_travel_boots_2",
	"item_ultimate_scepter_2",
}
sRoleItemsBuyList["pos_2"] = {
	"item_tango",
	"item_double_branches",
	"item_faerie_fire",
	"item_quelling_blade",
	"item_bottle",
	"item_power_treads",
	"item_magic_wand",
	"item_blink",
	"item_echo_sabre",
	"item_aghanims_shard",
	"item_black_king_bar",
	"item_greater_crit",
	"item_harpoon",
	"item_assault",
	"item_moon_shard",
	"item_swift_blink",
	"item_travel_boots_2",
	"item_ultimate_scepter_2",
}
sRoleItemsBuyList["pos_4"] = {
	"item_tango",
	"item_quelling_blade",
	"item_slippers",
	"item_circlet",
	"item_double_branches",
	"item_wraith_band",
	"item_magic_wand",
	"item_hand_of_midas",
	"item_power_treads",
	"item_echo_sabre",
	"item_blink",
	"item_black_king_bar",
	"item_aghanims_shard",
	"item_greater_crit",
	"item_harpoon",
	"item_satanic",
	"item_moon_shard",
	"item_swift_blink",
	"item_travel_boots_2",
	"item_ultimate_scepter_2",
}
sRoleItemsBuyList["pos_5"] = sRoleItemsBuyList["pos_4"]
sRoleItemsBuyList["pos_3"] = sRoleItemsBuyList["pos_4"]
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
function X.MinionThink(hMinionUnit)
	Minion.MinionThink(hMinionUnit)
end
local avalancheAbility = SafeAbility(bot:GetAbilityByName("tiny_avalanche"), "tiny_avalanche", "tiny")
local tossAbility = SafeAbility(bot:GetAbilityByName("tiny_toss"), "tiny_toss", "tiny")
local treeGrabAbility = SafeAbility(bot:GetAbilityByName("tiny_tree_grab"), "tiny_tree_grab", "tiny")
local tossTreeAbility = SafeAbility(bot:GetAbilityByName("tiny_toss_tree"), "tiny_toss_tree", "tiny")
local treeVolleyAbility = SafeAbility(bot:GetAbilityByName("tiny_tree_channel"), "tiny_tree_channel", "tiny")
local avalancheDesire, avalancheLocation
local tossDesire, tossTarget
local treeGrabDesire, treeGrabTarget
local tossTreeDesire, tossTreeTarget
local treeVolleyDesire, treeVolleyLocation
local blinkTossDesire, blinkTossTarget
local blinkItem
local blinkLocation
local botTarget
local isGoingOnSomeone
local isRetreating
local hpRatio
function X.SkillsComplement()
	if Fu.CanNotUseAbility(bot) then
		return
	end
	isGoingOnSomeone = Fu.IsGoingOnSomeone(bot)
	isRetreating = Fu.IsRetreating(bot)
	hpRatio = Fu.GetHP(bot)
	blinkTossDesire, blinkTossTarget = X.ConsiderBlinkToss()
	if blinkTossDesire > 0 then
		bot:Action_ClearActions(false)
		bot:ActionQueue_UseAbilityOnLocation(blinkItem, blinkLocation)
		bot:ActionQueue_Delay(0.1)
		bot:ActionQueue_UseAbilityOnEntity(tossAbility, blinkTossTarget)
		return
	end
	avalancheDesire, avalancheLocation = X.ConsiderAvalanche()
	if avalancheDesire > 0 then
		bot:Action_UseAbilityOnLocation(avalancheAbility, avalancheLocation)
		return
	end
	tossDesire, tossTarget = X.ConsiderToss()
	if tossDesire > 0 then
		bot:Action_UseAbilityOnEntity(tossAbility, tossTarget)
		return
	end
	treeGrabDesire, treeGrabTarget = X.ConsiderTreeGrab()
	if treeGrabDesire > 0 then
		bot:Action_UseAbilityOnTree(treeGrabAbility, treeGrabTarget)
		return
	end
	tossTreeDesire, tossTreeTarget = X.ConsiderTreeThrow()
	if tossTreeDesire > 0 then
		bot:Action_UseAbilityOnEntity(tossTreeAbility, tossTreeTarget)
		return
	end
	treeVolleyDesire, treeVolleyLocation = X.ConsiderTreeVolley()
	if treeVolleyDesire > 0 then
		bot:Action_UseAbilityOnLocation(treeVolleyAbility, treeVolleyLocation)
		return
	end
end
function X.ConsiderAvalanche()
	if not avalancheAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castRange = Fu.GetProperCastRange(false, bot, avalancheAbility:GetCastRange())
	local radius = avalancheAbility:GetSpecialValueInt("radius")
	-- datafeed: Avalanche's damage value is "avalanche_damage" (90/180/270/360); "value" read 0, so the kill checks never fired.
	local damage = avalancheAbility:GetSpecialValueInt("avalanche_damage") * (1 + bot:GetSpellAmp())
	local manaCost = avalancheAbility:GetManaCost()
	botTarget = Fu.GetProperTarget(bot)
	local enemiesInRange = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(enemiesInRange) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and not Fu.IsSuspiciousIllusion(enemyHero)
		then
			if enemyHero:IsChanneling() or Fu.IsCastingUltimateAbility(enemyHero) then
				return BOT_ACTION_DESIRE_HIGH, enemyHero:GetLocation()
			end
			if
				Fu.CanKillTarget(enemyHero, damage, DAMAGE_TYPE_MAGICAL)
				and not enemyHero:HasModifier("modifier_abaddon_aphotic_shield")
				and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
				and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
				and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
				and not enemyHero:HasModifier("modifier_templar_assassin_refraction_absorb")
			then
				return BOT_ACTION_DESIRE_HIGH, enemyHero:GetLocation()
			end
		end
	end
	if isGoingOnSomeone then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, castRange + 200, false, BOT_MODE_NONE)
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange - 50)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not Fu.IsDisabled(botTarget)
			and not botTarget:HasModifier("modifier_abaddon_aphotic_shield")
			and not botTarget:HasModifier("modifier_dazzle_shallow_grave")
			and not botTarget:HasModifier("modifier_templar_assassin_refraction_absorb")
			and nearbyAllies ~= nil
			and nearbyEnemies ~= nil
			and #nearbyAllies >= #nearbyEnemies
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	if isRetreating then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, castRange + 200, false, BOT_MODE_NONE)
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
		if
			nearbyAllies ~= nil
			and nearbyEnemies ~= nil
			and (#nearbyEnemies > #nearbyAllies or hpRatio < 0.58 and bot:WasRecentlyDamagedByAnyHero(2))
			and Fu.IsValidHero(nearbyEnemies[1])
			and Fu.CanCastOnNonMagicImmune(nearbyEnemies[1])
			and Fu.IsInRange(bot, nearbyEnemies[1], castRange)
			and not Fu.IsSuspiciousIllusion(nearbyEnemies[1])
			and not Fu.IsDisabled(nearbyEnemies[1])
		then
			return BOT_ACTION_DESIRE_HIGH, nearbyEnemies[1]:GetLocation()
		end
	end
	if (Fu.IsPushing(bot) or Fu.IsDefending(bot)) and Fu.CanSpamSpell(bot, manaCost) then
		local laneCreeps = bot:GetNearbyLaneCreeps(castRange, true)
		local aoeLocation = bot:FindAoELocation(true, false, bot:GetLocation(), castRange, radius, 0, 0)
		if laneCreeps ~= nil and #laneCreeps >= 4 and aoeLocation.count >= 4 then
			return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
		end
	end
	if Fu.IsFarming(bot) then
		local neutralCreeps = bot:GetNearbyNeutralCreeps(castRange)
		local aoeLocation = bot:FindAoELocation(true, false, bot:GetLocation(), castRange, radius, 0, 0)
		if neutralCreeps ~= nil and #neutralCreeps >= 3 and aoeLocation.count >= 3 then
			return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
		end
	end
	if Fu.IsLaning(bot) and Fu.IsAllowedToSpam(bot, manaCost) then
		local laneCreeps = bot:GetNearbyLaneCreeps(radius, true)
		for _, creep in pairs(laneCreeps) do
			if
				Fu.IsValid(creep)
				and (Fu.IsKeyWordUnit("ranged", creep) or Fu.IsKeyWordUnit("siege", creep))
				and creep:GetHealth() <= damage
			then
				local nearbyEnemies = Fu.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE)
				if
					nearbyEnemies ~= nil
					and #nearbyEnemies >= 1
					and GetUnitToUnitDistance(creep, nearbyEnemies[1]) <= 600
				then
					return BOT_ACTION_DESIRE_HIGH, creep:GetLocation()
				end
			end
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if
			Fu.IsRoshan(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if
			Fu.IsTormentor(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and Fu.IsAttacking(bot)
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function X.ConsiderToss()
	if not tossAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castRange = Fu.GetProperCastRange(false, bot, tossAbility:GetCastRange())
	local damage = tossAbility:GetSpecialValueInt("toss_damage") * (1 + bot:GetSpellAmp())
	local grabRadius = tossAbility:GetSpecialValueInt("grab_radius")
	botTarget = Fu.GetProperTarget(bot)
	-- datafeed: Toss throws the nearest unit within grab_radius (300) of Tiny. With none there it
	-- has nothing to throw, yet the kill and interrupt branches below cast it anyway.
	local grab = X.TossGrabUnit(grabRadius)
	if grab == nil then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local enemiesInRange = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(enemiesInRange) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and not Fu.IsSuspiciousIllusion(enemyHero)
		then
			if
				(enemyHero:IsChanneling() or Fu.IsCastingUltimateAbility(enemyHero))
				and avalancheAbility:IsTrained()
				and not avalancheAbility:IsCooldownReady()
			then
				return BOT_ACTION_DESIRE_HIGH, enemyHero
			end
			if
				Fu.CanKillTarget(enemyHero, damage, DAMAGE_TYPE_MAGICAL)
				and not enemyHero:HasModifier("modifier_abaddon_aphotic_shield")
				and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
				and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
				and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
				and not enemyHero:HasModifier("modifier_templar_assassin_refraction_absorb")
			then
				return BOT_ACTION_DESIRE_HIGH, enemyHero
			end
		end
	end
	-- "and not CanDoBlinkToss()" removed: Blink + Toss is considered first in SkillsComplement, so
	-- once that combo works the guard would only stop this Toss whenever a Blink was ready and the
	-- combo declined. (Today CanDoBlinkToss is always false: blinkItem is never set.)
	if isGoingOnSomeone then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, castRange + 200, false, BOT_MODE_NONE)
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not Fu.IsDisabled(botTarget)
			and not botTarget:HasModifier("modifier_faceless_void_chronosphere_freeze")
			and not botTarget:HasModifier("modifier_legion_commander_duel")
			and nearbyAllies ~= nil
			and nearbyEnemies ~= nil
			and #nearbyAllies >= #nearbyEnemies
		then
			if Fu.IsInRange(bot, botTarget, grabRadius) then
				local chronoTarget = nil
				local enemiesInRange = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
				for _, enemyHero in pairs(enemiesInRange) do
					if
						Fu.IsValidHero(enemyHero)
						and Fu.CanCastOnNonMagicImmune(enemyHero)
						and Fu.IsInRange(bot, enemyHero, castRange)
						and not Fu.IsSuspiciousIllusion(enemyHero)
						and enemyHero:HasModifier("modifier_faceless_void_chronosphere_freeze")
					then
						chronoTarget = enemyHero
						break
					end
				end
				if chronoTarget ~= nil then
					for _, enemyHero in pairs(enemiesInRange) do
						if
							Fu.IsValidHero(enemyHero)
							and Fu.CanCastOnNonMagicImmune(enemyHero)
							and Fu.IsInRange(bot, enemyHero, grabRadius)
							and not Fu.IsSuspiciousIllusion(enemyHero)
						then
							return BOT_ACTION_DESIRE_HIGH, chronoTarget
						end
					end
				end
				return BOT_ACTION_DESIRE_HIGH, botTarget
			else
				if Fu.IsInRange(bot, botTarget, castRange) then
					local allyLaneCreeps = bot:GetNearbyLaneCreeps(grabRadius, false)
					local enemyCreeps = bot:GetNearbyCreeps(grabRadius, true)
					if allyLaneCreeps ~= nil and #allyLaneCreeps >= 1 or enemyCreeps ~= nil and #enemyCreeps >= 1 then
						return BOT_ACTION_DESIRE_HIGH, botTarget
					end
					local enemiesNearTarget = Fu.GetEnemiesNearLoc(botTarget:GetLocation(), grabRadius)
					if enemiesNearTarget ~= nil and #enemiesNearTarget <= 1 then
						local alliesInGrabRadius = Fu.GetNearbyHeroes(bot, grabRadius, false, BOT_MODE_NONE)
						if
							alliesInGrabRadius ~= nil
							and #alliesInGrabRadius >= 1
							and GetUnitToUnitDistance(bot, botTarget) > grabRadius + 75
						then
							return BOT_ACTION_DESIRE_HIGH, botTarget
						end
					end
				end
			end
		end
	end
	if isRetreating then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, castRange + 200, false, BOT_MODE_NONE)
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
		if
			nearbyAllies ~= nil
			and nearbyEnemies ~= nil
			-- "hpRatio and" was always true (hpRatio is the HP fraction); 0.58 as in Avalanche's escape branch.
			and (#nearbyEnemies > #nearbyAllies or hpRatio < 0.58 and bot:WasRecentlyDamagedByAnyHero(2))
			and Fu.IsValidHero(nearbyEnemies[1])
			and Fu.CanCastOnNonMagicImmune(nearbyEnemies[1])
			and not Fu.IsSuspiciousIllusion(nearbyEnemies[1])
			and not Fu.IsDisabled(nearbyEnemies[1])
		then
			local escapeLocation = Fu.GetEscapeLoc()
			local furthestUnit = Fu.GetFurthestUnitToLocationFrommAll(bot, castRange, escapeLocation)
			if furthestUnit ~= nil and GetUnitToUnitDistance(bot, furthestUnit) > grabRadius then
				local closestUnit = Fu.GetClosestUnitToLocationFrommAll2(bot, grabRadius, bot:GetLocation())
				if Fu.IsValidTarget(closestUnit) and closestUnit:GetTeam() ~= bot:GetTeam() then
					return BOT_ACTION_DESIRE_MODERATE, furthestUnit
				end
			elseif furthestUnit ~= nil and GetUnitToUnitDistance(furthestUnit, bot) <= grabRadius then
				local closestUnit = Fu.GetClosestUnitToLocationFrommAll2(bot, grabRadius, bot:GetLocation())
				if Fu.IsValidTarget(closestUnit) and closestUnit:GetTeam() ~= bot:GetTeam() then
					return BOT_ACTION_DESIRE_MODERATE, closestUnit
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function X.ConsiderTreeGrab()
	if not treeGrabAbility:IsFullyCastable() or bot:HasModifier("modifier_tiny_tree_grab") then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local nearbyEnemies = Fu.GetNearbyHeroes(bot, 700, true, BOT_MODE_NONE)
	if
		not isRetreating
		and bot:GetHealth() > 0.15
		and bot:DistanceFromFountain() > 800
		and nearbyEnemies ~= nil
		and #nearbyEnemies == 0
	then
		local nearbyTrees = bot:GetNearbyTrees(1200)
		if
			nearbyTrees ~= nil
			and #nearbyTrees > 0
			and (
				IsLocationVisible(GetTreeLocation(nearbyTrees[1]))
				or IsLocationPassable(GetTreeLocation(nearbyTrees[1]))
			)
		then
			return BOT_ACTION_DESIRE_HIGH, nearbyTrees[1]
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function X.ConsiderTreeThrow()
	if not tossTreeAbility:IsFullyCastable() or not bot:HasModifier("modifier_tiny_tree_grab") then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castRange = tossTreeAbility:GetSpecialValueInt("range")
	local damage = bot:GetAttackDamage()
	local treeCharges = bot:GetModifierStackCount(bot:GetModifierByName("modifier_tiny_tree_grab"))
	botTarget = Fu.GetProperTarget(bot)
	local enemiesInRange = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(enemiesInRange) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.IsInRange(bot, enemyHero, castRange)
			and not Fu.IsSuspiciousIllusion(enemyHero)
		then
			if
				(
					Fu.CanKillTarget(enemyHero, damage, DAMAGE_TYPE_PHYSICAL)
					or isRetreating and Fu.CanKillTarget(enemyHero, damage, DAMAGE_TYPE_PHYSICAL)
				)
				and not enemyHero:HasModifier("modifier_abaddon_aphotic_shield")
				and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
				and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
				and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
				and not enemyHero:HasModifier("modifier_templar_assassin_refraction_absorb")
			then
				return BOT_ACTION_DESIRE_HIGH, enemyHero
			end
		end
	end
	if isGoingOnSomeone then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, castRange + 100, false, BOT_MODE_NONE)
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
		if
			Fu.IsValidTarget(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and not Fu.IsInRange(bot, botTarget, bot:GetAttackRange() + 50)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not botTarget:HasModifier("modifier_abaddon_aphotic_shield")
			and not botTarget:HasModifier("modifier_dazzle_shallow_grave")
			and not botTarget:HasModifier("modifier_templar_assassin_refraction_absorb")
			and nearbyAllies ~= nil
			and nearbyEnemies ~= nil
			and #nearbyAllies >= #nearbyEnemies
			and treeCharges <= 2
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end
	if isRetreating then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, castRange + 100, false, BOT_MODE_NONE)
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
		local weakestUnit = Fu.GetVulnerableWeakestUnit(bot, true, true, castRange)
		if
			nearbyAllies ~= nil
			and nearbyEnemies ~= nil
			and (#nearbyEnemies > #nearbyAllies or hpRatio < 0.65 and bot:WasRecentlyDamagedByAnyHero(2))
			and Fu.IsValidTarget(weakestUnit)
			and not Fu.IsSuspiciousIllusion(weakestUnit)
			and not weakestUnit:HasModifier("modifier_abaddon_aphotic_shield")
			and not weakestUnit:HasModifier("modifier_abaddon_borrowed_time")
			and not weakestUnit:HasModifier("modifier_dazzle_shallow_grave")
			and not weakestUnit:HasModifier("modifier_oracle_false_promise_timer")
			and not weakestUnit:HasModifier("modifier_templar_assassin_refraction_absorb")
		then
			return BOT_ACTION_DESIRE_HIGH, weakestUnit
		end
	end
	if Fu.IsLaning(bot) then
		local laneCreeps = bot:GetNearbyLaneCreeps(castRange, true)
		for _, creep in pairs(laneCreeps) do
			if
				Fu.IsValid(creep)
				and (Fu.IsKeyWordUnit("ranged", creep) or Fu.IsKeyWordUnit("siege", creep))
				and creep:GetHealth() <= damage
			then
				local nearbyEnemies = Fu.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE)
				if
					nearbyEnemies ~= nil
					and #nearbyEnemies >= 1
					and GetUnitToUnitDistance(creep, nearbyEnemies[1]) <= 600
				then
					return BOT_ACTION_DESIRE_HIGH, creep
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function X.ConsiderTreeVolley()
	-- datafeed: Tree Volley (tiny_tree_channel) is granted by Aghanim's Scepter, so it needs the Scepter (was inverted).
	if not bot:HasScepter() or not treeVolleyAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castRange = Fu.GetProperCastRange(false, bot, treeVolleyAbility:GetCastRange())
	local castPoint = treeVolleyAbility:GetCastPoint()
	local treeGrabRadius = treeVolleyAbility:GetSpecialValueInt("tree_grab_radius")
	local splashRadius = treeVolleyAbility:GetSpecialValueInt("splash_radius")
	botTarget = Fu.GetProperTarget(bot)
	if Fu.IsInTeamFight(bot, 1200) then
		local nearbyTrees = bot:GetNearbyTrees(treeGrabRadius)
		if #nearbyTrees >= 3 then
			local aoeLocation =
				bot:FindAoELocation(true, true, bot:GetLocation(), castRange, splashRadius, castPoint, 0)
			if aoeLocation.count >= 2 then
				return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
			end
		end
	end
	if isGoingOnSomeone then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, castRange + 100, false, BOT_MODE_NONE)
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
		if
			Fu.IsValidTarget(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange) -- was a duplicated IsValidTarget(botTarget), with no range check
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not botTarget:HasModifier("modifier_abaddon_aphotic_shield")
			and not botTarget:HasModifier("modifier_dazzle_shallow_grave")
			and not botTarget:HasModifier("modifier_templar_assassin_refraction_absorb")
			and nearbyAllies ~= nil
			and nearbyEnemies ~= nil
			and #nearbyAllies >= #nearbyEnemies
			and GetUnitToUnitDistance(bot, botTarget) >= 500
		then
			local nearbyTrees = bot:GetNearbyTrees(treeGrabRadius)
			if #nearbyTrees >= 3 then
				return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.ConsiderBlinkToss()
	if CanDoBlinkToss() then
		local castRange = Fu.GetProperCastRange(false, bot, tossAbility:GetCastRange())
		local grabRadius = tossAbility:GetSpecialValueInt("grab_radius")
		botTarget = Fu.GetProperTarget(bot)
		if isGoingOnSomeone then
			local nearbyAllies = Fu.GetNearbyHeroes(bot, castRange, false, BOT_MODE_NONE)
			local nearbyEnemies = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
			if
				Fu.IsValidTarget(botTarget)
				and Fu.CanCastOnNonMagicImmune(botTarget)
				and not Fu.IsSuspiciousIllusion(botTarget)
				and not Fu.IsDisabled(botTarget)
				and not botTarget:HasModifier("modifier_faceless_void_chronosphere_freeze")
				and not botTarget:HasModifier("modifier_legion_commander_duel")
				and nearbyAllies ~= nil
				and nearbyEnemies ~= nil
				and #nearbyAllies >= #nearbyEnemies
				and #nearbyAllies >= 1
			then
				if Fu.IsInRange(bot, botTarget, castRange) and GetUnitToUnitDistance(bot, botTarget) > grabRadius then
					blinkLocation = botTarget:GetLocation()
					return BOT_ACTION_DESIRE_HIGH, nearbyAllies[#nearbyAllies]
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
-- The unit Toss would grab: the nearest hero or creep (either team) within `radius` of Tiny,
-- not Tiny, not debuff/magic immune (datafeed: "Debuff Immune units ... cannot be tossed").
function X.TossGrabUnit(radius)
	local best, bestDist = nil, radius + 1
	local lists = {
		Fu.GetNearbyHeroes(bot, radius, false, BOT_MODE_NONE) or {},
		Fu.GetNearbyHeroes(bot, radius, true, BOT_MODE_NONE) or {},
		bot:GetNearbyCreeps(radius, true) or {},
		bot:GetNearbyCreeps(radius, false) or {},
	}
	for _, list in ipairs(lists) do
		for _, unit in pairs(list) do
			if unit ~= bot and Fu.IsValid(unit) and unit:IsAlive() and not unit:IsMagicImmune() then
				local distance = GetUnitToUnitDistance(bot, unit)
				if distance < bestDist then
					best, bestDist = unit, distance
				end
			end
		end
	end
	return best
end
function CanDoBlinkToss()
	if tossAbility:IsFullyCastable() and blinkItem ~= nil and blinkItem:IsFullyCastable() then
		local manaCost = tossAbility:GetManaCost()
		if bot:GetMana() >= manaCost then
			return true
		end
	end
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
