-- Enigma: skill build, item build, and ability use for this hero.
local X = {}
local bot = GetBot()
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local AbilityContext = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local Minion = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local sTalentList = Fu.Skill.GetTalentList(bot)
local sAbilityList = Fu.Skill.GetAbilityList(bot)
local sRole = Fu.Item.GetRoleItemsBuyList(bot)
local tTalentTreeList = {
	{ ["t25"] = { 10, 0 }, ["t20"] = { 10, 0 }, ["t15"] = { 0, 10 }, ["t10"] = { 0, 10 } },
	{ ["t25"] = { 10, 0 }, ["t20"] = { 10, 0 }, ["t15"] = { 0, 10 }, ["t10"] = { 0, 10 } },
}
local tAllAbilityBuildList =
	{ { 2, 1, 2, 1, 2, 6, 2, 1, 1, 3, 6, 3, 3, 3, 6 }, { 2, 1, 2, 1, 2, 6, 2, 1, 1, 3, 6, 3, 3, 3, 6 } }
local nAbilityBuildList = tAllAbilityBuildList[1]
if sRole == "pos_3" then
	nAbilityBuildList = tAllAbilityBuildList[1]
end
if sRole == "pos_4" then
	nAbilityBuildList = tAllAbilityBuildList[2]
end
if sRole == "pos_5" then
	nAbilityBuildList = tAllAbilityBuildList[2]
end
local nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList[1])
if sRole == "pos_3" then
	nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList[1])
end
if sRole == "pos_4" then
	nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList[2])
end
if sRole == "pos_5" then
	nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList[2])
end
local sTeamAuraItem = "item_team_aura"
local sRoleItemsBuyList = {}
sRoleItemsBuyList["pos_3"] = {
	"item_tango",
	"item_double_branches",
	"item_magic_wand",
	-- Tranquil Boots before Vladmir (Buckler is its first part).
	"item_boots",
	"item_tranquil_boots",
	"item_vladmir",
	"item_blink",
	"item_black_king_bar",
	"item_aghanims_shard",
	"item_ultimate_scepter",
	-- Octarine (+450 mana, 25% cooldown) before Refresher: the double Black Hole needs ~1,125-1,465
	-- mana, more than the pool before Octarine.
	"item_octarine_core",
	"item_refresher",
	sTeamAuraItem,
	"item_travel_boots",
	"item_arcane_blink",
	"item_travel_boots_2",
	"item_ultimate_scepter_2",
	"item_moon_shard",
}
sRoleItemsBuyList["pos_4"] = {
	"item_enchanted_mango",
	"item_double_tango",
	"item_double_branches",
	"item_blood_grenade",
	"item_magic_wand",
	"item_boots",
	"item_vladmir",
	"item_arcane_boots",
	"item_blink",
	"item_guardian_greaves",
	"item_black_king_bar",
	"item_lotus_orb",
	"item_gungir",
	"item_refresher",
	"item_arcane_blink",
	"item_aghanims_shard",
	"item_ultimate_scepter_2",
	"item_moon_shard",
}
sRoleItemsBuyList["pos_5"] = {
	"item_enchanted_mango",
	"item_double_tango",
	"item_double_branches",
	"item_blood_grenade",
	"item_magic_wand",
	"item_boots",
	-- Tranquil Boots before Vladmir (Buckler is its first part).
	"item_tranquil_boots",
	"item_vladmir",
	"item_pipe",
	"item_blink",
	"item_boots_of_bearing",
	"item_black_king_bar",
	"item_refresher",
	"item_arcane_blink",
	"item_aghanims_shard",
	"item_ultimate_scepter_2",
	"item_moon_shard",
}
sRoleItemsBuyList["pos_1"] = sRoleItemsBuyList["pos_3"]
sRoleItemsBuyList["pos_2"] = sRoleItemsBuyList["pos_3"]
X["sBuyList"] = sRoleItemsBuyList[sRole]
X["sSellList"] = { "item_ultimate_scepter", "item_magic_wand", "item_cyclone", "item_magic_wand" }
if Fu.Role.IsPvNMode() or Fu.Role.IsAllShadow() then
	X["sBuyList"], X["sSellList"] = { "PvN_antimage" }, {}
end
nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"] =
	Fu.SetUserHeroInit(nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"])
X["sSkillList"] = Fu.Skill.GetSkillList(sAbilityList, nAbilityBuildList, sTalentList, nTalentBuildList)
X["bDeafaultAbility"] = false
-- Cast when cornered (retreating into 3+ enemies with no way out), before running further.
X["LastStandSpells"] = { { name = "enigma_black_hole", kind = "point" } }
X["bDeafaultItem"] = false
function X.MinionThink(hMinionUnit)
	Minion.MinionThink(hMinionUnit)
end
local maleficeAbility = SafeAbility(bot:GetAbilityByName("enigma_malefice"), "enigma_malefice", "enigma")
local demonicConversionAbility =
	SafeAbility(bot:GetAbilityByName("enigma_demonic_conversion"), "enigma_demonic_conversion", "enigma")
local midnightPulseAbility =
	SafeAbility(bot:GetAbilityByName("enigma_midnight_pulse"), "enigma_midnight_pulse", "enigma")
local blackHoleAbility = SafeAbility(bot:GetAbilityByName("enigma_black_hole"), "enigma_black_hole", "enigma")
local maleficeTalent =
	SafeAbility(bot:GetAbilityByName("special_bonus_unique_enigma_2"), "special_bonus_unique_enigma_2", "enigma")
local midnightPulseTalent =
	SafeAbility(bot:GetAbilityByName("special_bonus_unique_enigma_6"), "special_bonus_unique_enigma_6", "enigma")
local maleficeDesire, maleficeTarget
local demonicConversionDesire, demonicConversionLocation
local midnightPulseDesire, midnightPulseLocation
local blackHoleDesire, blackHoleLocation
local blinkHoleDesire, blinkHoleLocation
local blinkPulseHoleDesire, blinkPulseHoleLocation
local blinkItem
local blackKingBar
local botTarget
local isGoingOnSomeone
local isAttacking
local isInTeamFight
function X.SkillsComplement()
	if Fu.CanNotUseAbility(bot) then
		return
	end
	local context = AbilityContext.Build(bot)
	isGoingOnSomeone = context.isEngaging
	isAttacking = Fu.IsAttacking(bot)
	isInTeamFight = context.isTeamFight
	botTarget = context.target
	local nearbyEnemies = Fu.GetNearbyHeroes(bot, 1000, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidHero(enemyHero)
			and (
				enemyHero:HasModifier("modifier_enigma_black_hole_pull")
				or enemyHero:HasModifier("modifier_enigma_black_hole_pull_scepter")
			)
		then
			return
		end
	end
	blinkPulseHoleDesire, blinkPulseHoleLocation = X.ConsiderBlinkPulseHole()
	if blinkPulseHoleDesire > 0 then
		X.LogBlackHole(
			"blink-pulse",
			#Fu.GetEnemiesNearLoc(blinkPulseHoleLocation, blackHoleAbility:GetSpecialValueInt("radius")),
			nil
		)
		bot:Action_ClearActions(false)
		if X.CanBKB() and not bot:IsMagicImmune() then
			bot:ActionQueue_UseAbility(blackKingBar)
			bot:ActionQueue_Delay(0.1)
		end
		bot:ActionQueue_UseAbilityOnLocation(blinkItem, blinkPulseHoleLocation)
		bot:ActionQueue_Delay(0.1)
		bot:ActionQueue_UseAbilityOnLocation(midnightPulseAbility, blinkPulseHoleLocation)
		bot:ActionQueue_Delay(0.1)
		bot:ActionQueue_UseAbilityOnLocation(blackHoleAbility, blinkPulseHoleLocation)
		return
	end
	blinkHoleDesire, blinkHoleLocation = X.ConsiderBlinkHole()
	if blinkHoleDesire > 0 then
		X.LogBlackHole(
			"blink",
			#Fu.GetEnemiesNearLoc(blinkHoleLocation, blackHoleAbility:GetSpecialValueInt("radius")),
			nil
		)
		bot:Action_ClearActions(false)
		if X.CanBKB() and not bot:IsMagicImmune() then
			bot:ActionQueue_UseAbility(blackKingBar)
			bot:ActionQueue_Delay(0.1)
		end
		bot:ActionQueue_UseAbilityOnLocation(blinkItem, blinkHoleLocation)
		bot:ActionQueue_Delay(0.1)
		X.QueuePulseBefore(blinkHoleLocation)
		bot:ActionQueue_UseAbilityOnLocation(blackHoleAbility, blinkHoleLocation)
		return
	end
	midnightPulseDesire, midnightPulseLocation = X.ConsiderMidnightPulse()
	if midnightPulseDesire > 0 then
		bot:Action_UseAbilityOnLocation(midnightPulseAbility, midnightPulseLocation)
		return
	end
	blackHoleDesire, blackHoleLocation = X.ConsiderBlackHole()
	if blackHoleDesire > 0 then
		bot:Action_ClearActions(false)
		if X.CanBKB() and not bot:IsMagicImmune() then
			bot:ActionQueue_UseAbility(blackKingBar)
			bot:ActionQueue_Delay(0.1)
		end
		X.QueuePulseBefore(blackHoleLocation)
		bot:ActionQueue_UseAbilityOnLocation(blackHoleAbility, blackHoleLocation)
		return
	end
	maleficeDesire, maleficeTarget = X.ConsiderMalefice()
	if maleficeDesire > 0 then
		bot:Action_UseAbilityOnEntity(maleficeAbility, maleficeTarget)
		return
	end
	demonicConversionDesire, demonicConversionLocation = X.ConsiderDemonicSummoning()
	if demonicConversionDesire > 0 then
		bot:Action_UseAbilityOnLocation(demonicConversionAbility, demonicConversionLocation)
		return
	end
end
function X.ConsiderMalefice()
	if not maleficeAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castRange = Fu.GetProperCastRange(false, bot, maleficeAbility:GetCastRange())
	-- datafeed: Malefice's instance count is "stun_instances" (3); it has no "value", so stunInstances (and the kill damage) was 0.
	local stunInstances = maleficeAbility:GetSpecialValueInt("stun_instances")
	if maleficeTalent:IsTrained() then
		stunInstances = stunInstances + maleficeAbility:GetSpecialValueInt("value")
	end
	local damage = maleficeAbility:GetSpecialValueInt("damage") * stunInstances
	local nearbyEnemies = Fu.GetNearbyHeroes(bot, castRange + 150, true, BOT_MODE_NONE)
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
				and not enemyHero:HasModifier("modifier_abaddon_aphotic_shield")
				and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
				and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
				and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
				and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
				and not enemyHero:HasModifier("modifier_skeleton_king_reincarnation_scepter_active")
				and not enemyHero:HasModifier("modifier_templar_assassin_refraction_absorb")
			then
				return BOT_ACTION_DESIRE_HIGH, enemyHero
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
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
			and not botTarget:HasModifier("modifier_skeleton_king_reincarnation_scepter_active")
		then
			local alliesNearTarget = Fu.GetNearbyHeroes(botTarget, 1400, true, BOT_MODE_NONE)
			local enemiesNearTarget = Fu.GetNearbyHeroes(botTarget, 1400, false, BOT_MODE_NONE)
			if alliesNearTarget ~= nil and enemiesNearTarget ~= nil and #alliesNearTarget >= #enemiesNearTarget then
				return BOT_ACTION_DESIRE_HIGH, botTarget
			end
		end
	end
	if Fu.IsRetreating(bot) then
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE)
		if
			Fu.IsValidHero(nearbyEnemies[1])
			and Fu.CanCastOnNonMagicImmune(nearbyEnemies[1])
			and Fu.CanCastOnTargetAdvanced(nearbyEnemies[1])
			and Fu.IsInRange(bot, nearbyEnemies[1], castRange)
			and not Fu.IsSuspiciousIllusion(nearbyEnemies[1])
			and not Fu.IsDisabled(nearbyEnemies[1])
			and not Fu.IsRealInvisible(bot)
		then
			local alliesNearChaser = Fu.GetNearbyHeroes(nearbyEnemies[1], 1200, true, BOT_MODE_NONE)
			local enemiesNearChaser = Fu.GetNearbyHeroes(nearbyEnemies[1], 1200, false, BOT_MODE_NONE)
			if
				alliesNearChaser ~= nil
				and enemiesNearChaser ~= nil
				and (#enemiesNearChaser > #alliesNearChaser or bot:WasRecentlyDamagedByAnyHero(2))
			then
				return BOT_ACTION_DESIRE_HIGH, nearbyEnemies[1]
			end
		end
	end
	local alliesInRange = Fu.GetNearbyHeroes(bot, castRange, false, BOT_MODE_NONE)
	for _, allyHero in pairs(alliesInRange) do
		local enemiesNearAlly = Fu.GetNearbyHeroes(allyHero, 1600, true, BOT_MODE_NONE)
		if
			Fu.IsValidHero(allyHero)
			and (not Fu.IsCore(bot) or Fu.IsCore(bot) and Fu.GetManaAfter(maleficeAbility:GetManaCost()) > 0.66)
			and Fu.IsRetreating(allyHero)
			and allyHero:WasRecentlyDamagedByAnyHero(2)
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
				and not Fu.IsDisabled(enemiesNearAlly[1])
				and not Fu.IsTaunted(enemiesNearAlly[1])
				and not Fu.IsSuspiciousIllusion(enemiesNearAlly[1])
				and not enemiesNearAlly[1]:HasModifier("modifier_legion_commander_duel")
				and not enemiesNearAlly[1]:HasModifier("modifier_enigma_black_hole_pull")
				and not enemiesNearAlly[1]:HasModifier("modifier_faceless_void_chronosphere_freeze")
			then
				return BOT_ACTION_DESIRE_HIGH, enemiesNearAlly[1]
			end
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if
			Fu.IsRoshan(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and isAttacking
			and not botTarget:HasModifier("modifier_roshan_spell_block")
		then
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
function X.ConsiderDemonicSummoning()
	if not demonicConversionAbility:IsFullyCastable() or Fu.GetHP(bot) < 0.25 then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local castRange = Fu.GetProperCastRange(false, bot, demonicConversionAbility:GetCastRange())
	local hpCost = 75 + 25 * (demonicConversionAbility:GetLevel() - 1)
	if isGoingOnSomeone and Fu.GetHP(bot) > 0.5 then
		if
			Fu.IsValidTarget(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not botTarget:HasModifier("modifier_dazzle_shallow_grave")
			and not botTarget:HasModifier("modifier_faceless_void_chronosphere_freeze")
		then
			local alliesNearTarget = Fu.GetNearbyHeroes(botTarget, 1400, true, BOT_MODE_NONE)
			local enemiesNearTarget = Fu.GetNearbyHeroes(botTarget, 1400, false, BOT_MODE_NONE)
			if alliesNearTarget ~= nil and enemiesNearTarget ~= nil and #alliesNearTarget >= #enemiesNearTarget then
				if DotaTime() < 10 * 60 then
					local towersNearTarget = botTarget:GetNearbyTowers(800, false)
					if towersNearTarget ~= nil then
						if Fu.IsChasingTarget(bot, botTarget) then
							if Fu.IsInRange(bot, botTarget, castRange) and #towersNearTarget == 0 then
								return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
							else
								if #towersNearTarget == 0 then
									return BOT_ACTION_DESIRE_HIGH,
										Fu.Site.GetXUnitsTowardsLocation(bot, botTarget:GetLocation(), castRange)
								end
							end
						else
							if Fu.IsInRange(bot, botTarget, castRange) then
								return BOT_ACTION_DESIRE_HIGH, (bot:GetLocation() + botTarget:GetLocation()) / 2
							end
						end
					end
				else
					if Fu.IsChasingTarget(bot, botTarget) then
						if Fu.IsInRange(bot, botTarget, castRange) then
							return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
						else
							return BOT_ACTION_DESIRE_HIGH,
								Fu.Site.GetXUnitsTowardsLocation(bot, botTarget:GetLocation(), castRange)
						end
					else
						if Fu.IsInRange(bot, botTarget, bot:GetAttackRange()) then
							return BOT_ACTION_DESIRE_HIGH, (bot:GetLocation() + botTarget:GetLocation()) / 2
						end
					end
				end
			end
		end
	end
	if Fu.IsDefending(bot) or Fu.IsPushing(bot) then
		if isAttacking then
			local nearbyLaneCreeps = bot:GetNearbyLaneCreeps(1000, true)
			if nearbyLaneCreeps ~= nil and #nearbyLaneCreeps >= 3 then
				return BOT_ACTION_DESIRE_HIGH, bot:GetLocation()
			end
			local nearbyTowers = bot:GetNearbyTowers(800, true)
			local nearbyBarracks = bot:GetNearbyBarracks(800, true)
			local nearbyFillers = bot:GetNearbyFillers(800, true)
			if
				Fu.IsValidBuilding(bot:GetAttackTarget())
				and (
					nearbyTowers ~= nil and #nearbyTowers >= 1
					or nearbyBarracks ~= nil and #nearbyBarracks >= 1
					or nearbyFillers ~= nil and #nearbyFillers >= 1
				)
			then
				return BOT_ACTION_DESIRE_HIGH, bot:GetLocation()
			end
		end
	end
	if
		Fu.IsFarming(bot)
		and Fu.GetHealthAfter(hpCost) > 0.5
		and Fu.GetManaAfter(demonicConversionAbility:GetManaCost()) > 0.33
		and isAttacking
	then
		local nearbyLaneCreeps = bot:GetNearbyLaneCreeps(1000, true)
		if nearbyLaneCreeps ~= nil and #nearbyLaneCreeps >= 4 then
			return BOT_ACTION_DESIRE_HIGH, bot:GetLocation()
		end
		local nearbyNeutrals = bot:GetNearbyNeutralCreeps(castRange)
		if nearbyNeutrals ~= nil and #nearbyNeutrals >= 2 then
			return BOT_ACTION_DESIRE_HIGH, bot:GetLocation()
		end
	end
	if Fu.IsLaning(bot) then
		-- Eidolons take the wave and harass in lane. The mana bar was 50% after the cast, about
		-- three quarters of a level 1-3 pool, and Enigma was never seen summoning in lane.
		-- Every skip is logged with the reason so the next game shows what blocks it.
		local hpAfter = Fu.GetHealthAfter(hpCost)
		local mpAfter = Fu.GetManaAfter(demonicConversionAbility:GetManaCost())
		local nearbyLaneCreeps = bot:GetNearbyLaneCreeps(800, true) or {}
		local why = nil
		if hpAfter <= 0.61 then
			why = "hp"
		elseif mpAfter <= 0.35 then
			why = "mana"
		elseif #nearbyLaneCreeps < 3 then
			why = "creeps"
		end
		if why == nil then
			pcall(
				print,
				string.format(
					"[OHA-ENIGMA] t=%.0f summon why=lane creeps=%d hpAfter=%.2f mpAfter=%.2f",
					DotaTime(),
					#nearbyLaneCreeps,
					hpAfter,
					mpAfter
				)
			)
			return BOT_ACTION_DESIRE_HIGH, bot:GetLocation()
		end
		if DotaTime() >= (bot._summonSkipLogAt or -999) then
			bot._summonSkipLogAt = DotaTime() + 20
			pcall(
				print,
				string.format(
					"[OHA-ENIGMA] t=%.0f summon-skip why=%s creeps=%d hpAfter=%.2f mpAfter=%.2f",
					DotaTime(),
					why,
					#nearbyLaneCreeps,
					hpAfter,
					mpAfter
				)
			)
		end
	end
	if Fu.IsDoingRoshan(bot) and Fu.GetHealthAfter(hpCost) > 0.5 then
		if Fu.IsRoshan(botTarget) and Fu.IsInRange(bot, botTarget, bot:GetAttackRange()) and isAttacking then
			return BOT_ACTION_DESIRE_HIGH, bot:GetLocation()
		end
	end
	if Fu.IsDoingTormentor(bot) and Fu.GetHealthAfter(hpCost) > 0.63 then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, bot:GetAttackRange()) and isAttacking then
			return BOT_ACTION_DESIRE_HIGH, bot:GetLocation()
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.ConsiderMidnightPulse()
	if not midnightPulseAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	-- Pulse only adds to Black Hole. With Black Hole off cooldown, a Pulse on its own must leave
	-- mana for it (Black Hole queues its own Pulse when both fit). Otherwise Pulse is free.
	if
		blackHoleAbility:IsTrained()
		and blackHoleAbility:GetCooldownTimeRemaining() <= 0
		and bot:GetMana() - midnightPulseAbility:GetManaCost() < blackHoleAbility:GetManaCost()
	then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local castRange = Fu.GetProperCastRange(false, bot, midnightPulseAbility:GetCastRange())
	local radius = midnightPulseAbility:GetSpecialValueInt("radius")
	if midnightPulseTalent:IsTrained() then
		radius = radius + midnightPulseAbility:GetSpecialValueInt("value")
	end
	if isInTeamFight then
		local aoeLocation = bot:FindAoELocation(true, true, bot:GetLocation(), castRange, radius / 2, 0, 0)
		local enemiesInRadius = Fu.GetEnemiesNearLoc(aoeLocation.targetloc, radius * 0.8)
		if enemiesInRadius ~= nil and #enemiesInRadius >= 2 then
			return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
		end
	end
	if isGoingOnSomeone then
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and not Fu.IsSuspiciousIllusion(botTarget)
		then
			local alliesNearTarget = Fu.GetNearbyHeroes(botTarget, 1400, true, BOT_MODE_NONE)
			local enemiesNearTarget = Fu.GetNearbyHeroes(botTarget, 1400, false, BOT_MODE_NONE)
			if alliesNearTarget ~= nil and enemiesNearTarget ~= nil and #alliesNearTarget >= #enemiesNearTarget then
				enemiesNearTarget = Fu.GetEnemiesNearLoc(botTarget:GetLocation(), radius * 0.66)
				if Fu.IsInRange(bot, botTarget, castRange) then
					if not Fu.IsChasingTarget(bot, botTarget) then
						if enemiesNearTarget ~= nil and #enemiesNearTarget >= 1 then
							return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(enemiesNearTarget)
						else
							return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
						end
					else
						return BOT_ACTION_DESIRE_HIGH, botTarget:GetExtrapolatedLocation(1)
					end
				else
					if
						Fu.IsInRange(bot, botTarget, castRange + radius)
						and not Fu.IsInRange(bot, botTarget, castRange)
						and not Fu.IsChasingTarget(bot, botTarget)
					then
						return BOT_ACTION_DESIRE_HIGH,
							Fu.Site.GetXUnitsTowardsLocation(bot, botTarget:GetLocation(), castRange)
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
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, castRange) and isAttacking then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
-- Black Hole is for two or more enemy heroes. One enemy only when it kills a core and no other
-- enemy hero is in sight: the old fallback cast it on a lone target whenever our numbers were
-- even or better. Damage is read from "damage" (per second) x "duration"; the old "value" key
-- does not exist on this ability, so every kill check came out 0.
function X.ConsiderBlackHole()
	if not blackHoleAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local castRange = Fu.GetProperCastRange(false, bot, blackHoleAbility:GetCastRange())
	local radius = blackHoleAbility:GetSpecialValueInt("radius")
	local dps = blackHoleAbility:GetSpecialValueInt("damage")
	local duration = blackHoleAbility:GetSpecialValueFloat("duration")
	if duration == nil or duration <= 0 then
		duration = 4
	end
	if isInTeamFight or isGoingOnSomeone then
		local aoeLocation = bot:FindAoELocation(true, true, bot:GetLocation(), castRange, radius * 0.8, 0, 0)
		local enemiesInRadius = Fu.GetEnemiesNearLoc(aoeLocation.targetloc, radius)
		if enemiesInRadius ~= nil and #enemiesInRadius >= 2 then
			X.LogBlackHole("group", #enemiesInRadius, enemiesInRadius[1])
			return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
		end
	end
	if
		isGoingOnSomeone
		and Fu.IsValidTarget(botTarget)
		and Fu.IsCore(botTarget)
		and Fu.CanCastOnMagicImmune(botTarget)
		and Fu.IsInRange(bot, botTarget, castRange + 200)
		and not Fu.IsSuspiciousIllusion(botTarget)
		and not botTarget:HasModifier("modifier_dazzle_shallow_grave")
		and not botTarget:HasModifier("modifier_faceless_void_chronosphere_freeze")
		and not botTarget:HasModifier("modifier_templar_assassin_refraction_absorb")
		and not botTarget:HasModifier("modifier_item_aeon_disk_buff")
		and botTarget:GetHealth() > 200
		and Fu.CanKillTarget(botTarget, dps * duration, DAMAGE_TYPE_PURE)
	then
		local others = Fu.GetEnemiesNearLoc(botTarget:GetLocation(), 1600)
		if others ~= nil and #others <= 1 then
			X.LogBlackHole("kill", 1, botTarget)
			if Fu.IsInRange(bot, botTarget, castRange) then
				return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
			end
			return BOT_ACTION_DESIRE_HIGH, Fu.Site.GetXUnitsTowardsLocation(bot, botTarget:GetLocation(), castRange)
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
-- [OHA-ENIGMA] black-hole why=group|kill heroes=N target=..., every cast decision (5s apart).
function X.LogBlackHole(why, heroes, target)
	if DotaTime() < (bot._blackHoleLogAt or -999) then
		return
	end
	bot._blackHoleLogAt = DotaTime() + 5
	pcall(
		print,
		string.format(
			"[OHA-ENIGMA] t=%.0f black-hole why=%s heroes=%d target=%s pulseReady=%s",
			DotaTime(),
			why,
			heroes,
			target and (string.gsub(target:GetUnitName(), "npc_dota_hero_", "")) or "-",
			tostring(midnightPulseAbility:IsFullyCastable())
		)
	)
end
-- Refresher for a second Black Hole: the first one went out within the last 15s, Refresher
-- and a Black Hole both fit in current mana, and 2+ enemy heroes are still grouped in reach.
-- The shared rule wanted mana for two more Black Holes, so it almost never fired. Items are
-- not used during the channel, so this runs once the first Black Hole has ended.
function X.CanUseRefresherShard()
	if not blackHoleAbility:IsTrained() or blackHoleAbility:IsFullyCastable() then
		return false
	end
	local cooldown = blackHoleAbility:GetCooldown()
	local remain = blackHoleAbility:GetCooldownTimeRemaining()
	if cooldown == nil or remain == nil or cooldown - remain > 15 then
		return false
	end
	local refresher = nil
	for _, name in ipairs({ "item_refresher", "item_refresher_shard" }) do
		local slot = bot:FindItemSlot(name)
		if slot >= 0 and slot <= 5 then
			refresher = bot:GetItemInSlot(slot)
			break
		end
	end
	if refresher == nil or not refresher:IsFullyCastable() then
		return false
	end
	if bot:GetMana() < refresher:GetManaCost() + blackHoleAbility:GetManaCost() then
		return false
	end
	local reach = Fu.GetProperCastRange(false, bot, blackHoleAbility:GetCastRange()) + 300
	local spot = bot:FindAoELocation(
		true,
		true,
		bot:GetLocation(),
		reach,
		blackHoleAbility:GetSpecialValueInt("radius") * 0.8,
		0,
		0
	)
	local enemiesInRadius = Fu.GetEnemiesNearLoc(spot.targetloc, blackHoleAbility:GetSpecialValueInt("radius"))
	if enemiesInRadius == nil or #enemiesInRadius < 2 then
		return false
	end
	pcall(
		print,
		string.format(
			"[OHA-ENIGMA] t=%.0f refresher heroes=%d mana=%.0f need=%.0f",
			DotaTime(),
			#enemiesInRadius,
			bot:GetMana(),
			refresher:GetManaCost() + blackHoleAbility:GetManaCost()
		)
	)
	return true
end
-- Midnight Pulse in front of Black Hole when it is ready and there is mana for both.
function X.QueuePulseBefore(loc)
	if
		midnightPulseAbility:IsFullyCastable()
		and bot:GetMana() >= midnightPulseAbility:GetManaCost() + blackHoleAbility:GetManaCost()
	then
		bot:ActionQueue_UseAbilityOnLocation(midnightPulseAbility, loc)
		bot:ActionQueue_Delay(0.1)
	end
end
function X.ConsiderBlinkHole()
	if X.CanDoBlinkHole() then
		local radius = blackHoleAbility:GetSpecialValueInt("radius")
		if isInTeamFight then
			local aoeLocation = bot:FindAoELocation(true, true, bot:GetLocation(), 1199, radius, 0, 0)
			local enemiesInRadius = Fu.GetEnemiesNearLoc(aoeLocation.targetloc, radius)
			if enemiesInRadius ~= nil and #enemiesInRadius >= 2 then
				return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.CanDoBlinkHole()
	-- X.HasBlink() is what sets blinkItem; nothing called it, so blinkItem stayed nil and the
	-- Blink + Black Hole initiation never fired.
	if blackHoleAbility:IsFullyCastable() and X.HasBlink() then
		local manaCost = blackHoleAbility:GetManaCost()
		if bot:GetMana() >= manaCost then
			return true
		end
	end
	return false
end
function X.ConsiderBlinkPulseHole()
	if X.CanDoBlinkPulseHole() then
		local radius = blackHoleAbility:GetSpecialValueInt("radius")
		if isInTeamFight then
			local aoeLocation = bot:FindAoELocation(true, true, bot:GetLocation(), 1199, radius, 0, 0)
			local enemiesInRadius = Fu.GetEnemiesNearLoc(aoeLocation.targetloc, radius)
			if enemiesInRadius ~= nil and #enemiesInRadius >= 2 then
				return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.CanDoBlinkPulseHole()
	-- X.HasBlink() sets blinkItem; it was never called (see CanDoBlinkHole).
	if blackHoleAbility:IsFullyCastable() and midnightPulseAbility:IsFullyCastable() and X.HasBlink() then
		local manaCost = blackHoleAbility:GetManaCost() + midnightPulseAbility:GetManaCost()
		if bot:GetMana() >= manaCost then
			return true
		end
	end
	return false
end
function X.HasBlink()
	local foundBlink = nil
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
			foundBlink = item
			break
		end
	end
	if foundBlink ~= nil and foundBlink:IsFullyCastable() then
		blinkItem = foundBlink
		return true
	end
	return false
end
function X.CanBKB()
	local foundBlackKingBar = nil
	for slot = 0, 5 do
		local item = bot:GetItemInSlot(slot)
		if item ~= nil and item:GetName() == "item_black_king_bar" then
			foundBlackKingBar = item
			break
		end
	end
	if foundBlackKingBar ~= nil and foundBlackKingBar:IsFullyCastable() then
		blackKingBar = foundBlackKingBar
		return true
	end
	return false
end
return X
