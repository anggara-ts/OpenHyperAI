-- Morphling: skill build, item build, and ability use for this hero.
local X = {}
local bot = GetBot()
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local AbilityContext = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local Minion = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local SpellList = require(GetScriptDirectory() .. "/FuncLib/data/spell_list")
local sTalentList = Fu.Skill.GetTalentList(bot)
local sAbilityList = Fu.Skill.GetAbilityList(bot)
local sRole = Fu.Item.GetRoleItemsBuyList(bot)
local tTalentTreeList = {
	{ ["t25"] = { 0, 10 }, ["t20"] = { 10, 0 }, ["t15"] = { 0, 10 }, ["t10"] = { 0, 10 } },
	{ ["t25"] = { 0, 10 }, ["t20"] = { 10, 0 }, ["t15"] = { 0, 10 }, ["t10"] = { 0, 10 } },
}
local tAllAbilityBuildList =
	{ { 4, 2, 1, 1, 1, 6, 1, 4, 4, 2, 2, 6, 4, 2, 6 }, { 4, 2, 1, 1, 1, 6, 1, 4, 4, 2, 2, 6, 4, 2, 6 } }
local nAbilityBuildList
local nTalentBuildList
if sRole == "pos_2" then
	nAbilityBuildList = tAllAbilityBuildList[2]
	nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList[2])
else
	nAbilityBuildList = tAllAbilityBuildList[1]
	nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList[1])
end
local sRoleItemsBuyList = {}
-- Hydra's Breath (user call; Dotabuff 30% of matches): +30 agility, 30% of attacks also hit 3 more enemies in a cone.
sRoleItemsBuyList["pos_1"] = {
	"item_tango",
	"item_double_branches",
	"item_magic_stick",
	"item_circlet",
	"item_magic_wand",
	"item_power_treads",
	"item_vladmir",
	"item_manta",
	"item_butterfly",
	"item_black_king_bar",
	"item_aghanims_shard",
	"item_greater_crit",
	"item_skadi",
	"item_moon_shard",
	"item_hydras_breath",
	"item_ultimate_scepter_2",
}
-- Hydra's Breath (user call; Dotabuff 30% of matches): +30 agility, 30% of attacks also hit 3 more enemies in a cone.
sRoleItemsBuyList["pos_2"] = {
	"item_tango",
	"item_double_branches",
	"item_magic_stick",
	"item_circlet",
	"item_bottle",
	"item_magic_wand",
	"item_power_treads",
	"item_vladmir",
	"item_manta",
	"item_butterfly",
	"item_black_king_bar",
	"item_aghanims_shard",
	"item_greater_crit",
	"item_hydras_breath",
	"item_moon_shard",
	"item_satanic",
	"item_ultimate_scepter_2",
}
sRoleItemsBuyList["pos_3"] = sRoleItemsBuyList["pos_1"]
sRoleItemsBuyList["pos_4"] = sRoleItemsBuyList["pos_1"]
sRoleItemsBuyList["pos_5"] = sRoleItemsBuyList["pos_1"]
X["sBuyList"] = sRoleItemsBuyList[sRole]
X["sSellList"] = { "item_magic_wand", "item_circlet", "item_hydras_breath", "item_vladmir" }
if Fu.Role.IsPvNMode() or Fu.Role.IsAllShadow() then
	X["sBuyList"], X["sSellList"] = { "PvN_mid" }, {}
end
nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"] =
	Fu.SetUserHeroInit(nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"])
X["sSkillList"] = Fu.Skill.GetSkillList(sAbilityList, nAbilityBuildList, sTalentList, nTalentBuildList)
X["bDeafaultAbility"] = false
X["bDeafaultItem"] = false
function X.MinionThink(hMinionUnit)
	Minion.MinionThink(hMinionUnit)
end
local waveformAbility = SafeAbility(bot:GetAbilityByName("morphling_waveform"), "morphling_waveform", "morphling")
local adaptiveStrikeAgiAbility =
	SafeAbility(bot:GetAbilityByName("morphling_adaptive_strike_agi"), "morphling_adaptive_strike_agi", "morphling")
local morphAgiAbility = SafeAbility(bot:GetAbilityByName("morphling_morph_agi"), "morphling_morph_agi", "morphling")
local morphStrAbility = SafeAbility(bot:GetAbilityByName("morphling_morph_str"), "morphling_morph_str", "morphling")
local replicateAbility = SafeAbility(bot:GetAbilityByName("morphling_replicate"), "morphling_replicate", "morphling")
local morphReplicateAbility =
	SafeAbility(bot:GetAbilityByName("morphling_morph_replicate"), "morphling_morph_replicate", "morphling")
local waveformDesire, waveformLocation
local adaptiveStrikeDesire, adaptiveStrikeTarget
local attributeShiftDesire, attributeShiftType -- the type was the global `Type`
local replicateDesire, replicateTarget
local replicatedHeroName = ""
local botTarget
local hpRatio
local nearbyAllies, nearbyEnemies
local isStrengthPrimary = false
if bot.IsMorphling == nil then
	bot.IsMorphling = true
end
local agiRatio = 1
local baseAgility = 24
local baseStrength = 23
local agilityGain = 4.2
local strengthGain = 2.6
local heroModuleCache = {}
local function ThinkAsReplicatedHero(ability)
	if ability == nil then
		return
	end
	local heroName = SpellList.GetSpellHeroName(ability:GetName())
	if heroName == nil then
		return
	end
	if not heroModuleCache[heroName] then
		heroModuleCache[heroName] =
			require(GetScriptDirectory() .. "/BotsLib/" .. string.gsub(heroName, "npc_dota_", ""))
	end
	local heroModule = heroModuleCache[heroName]
	if heroModule and heroModule.SkillsComplement then
		heroModule.SkillsComplement()
	end
end
local replicateTimes = { 0, math.huge }
local replicateDuration = math.pi
local isEngaging
local isRetreating
local isAttacking
function X.SkillsComplement()
	if Fu.CanNotUseAbility(bot) then
		return
	end
	local context = AbilityContext.Build(bot)
	isEngaging = context.isEngaging
	isRetreating = context.isRetreating
	isAttacking = Fu.IsAttacking(bot)
	nearbyAllies = bot:GetNearbyHeroes(1600, false, BOT_MODE_NONE)
	nearbyEnemies = context.enemies
	botTarget = context.target
	hpRatio = context.hp
	isStrengthPrimary = bot:GetPrimaryAttribute() == ATTRIBUTE_STRENGTH and true or false
	if bot:GetAbilityInSlot(0) == waveformAbility then
		bot.IsMorphling = true
	else
		bot.IsMorphling = false
	end
	if bot:HasModifier("modifier_morphling_replicate_manager") then
		if DotaTime() > replicateTimes[2] + replicateDuration + 0.25 + 0.1 then
			if bot.IsMorphling == true then
				if isEngaging and Fu.IsValidHero(botTarget) and Fu.IsInRange(bot, botTarget, 900) then
					if
						IsGoodToMorphBack(replicatedHeroName, true)
						or hpRatio > 0.8
						or hpRatio > 0.5 and #nearbyAllies > #nearbyEnemies
					then
						bot:Action_UseAbility(morphReplicateAbility)
						replicateTimes[1] = DotaTime()
						return
					end
				end
				if
					isRetreating
					and not Fu.IsRealInvisible(bot)
					and IsGoodToMorphBack(replicatedHeroName, false)
					and not Fu.CanCastAbility(waveformAbility, 3)
				then
					local enemiesNearBot = Fu.GetEnemiesNearLoc(bot:GetLocation(), 1200)
					if #enemiesNearBot > 0 and hpRatio > 0.4 then
						bot:Action_UseAbility(morphReplicateAbility)
						replicateTimes[1] = DotaTime()
						return
					end
				end
			end
		end
		if DotaTime() < replicateTimes[1] + 3 + 0.25 + 0.1 then
			if bot.IsMorphling == false and Fu.CanCastAbility(morphReplicateAbility) then
				if replicateDuration == math.pi then
					local hasSpellReady = false
					local cooldownCount = 0
					local weightedCooldownSum = 0
					local weightSum = 0
					for slot = 0, 7 do
						local slotAbility = bot:GetAbilityInSlot(slot)
						if
							slotAbility
							and slotAbility ~= morphReplicateAbility
							and slotAbility:IsTrained()
							and not slotAbility:IsPassive()
							and string.find(
								slotAbility:GetName(),
								string.gsub(replicatedHeroName, "npc_dota_hero_", "")
							)
							and not string.find(slotAbility:GetName(), "morphling")
						then
							if Fu.CanCastAbilitySoon(slotAbility, 1.5) then
								hasSpellReady = true
							end
							local cooldown = slotAbility:GetCooldown()
							if cooldown > 0 then
								local weight = 1 / math.sqrt(cooldown)
								weightedCooldownSum = weightedCooldownSum + cooldown * weight
								weightSum = weightSum + weight
								cooldownCount = cooldownCount + 1
							end
						end
					end
					if not hasSpellReady then
						bot:Action_UseAbility(morphReplicateAbility)
						replicateTimes[2] = DotaTime()
						return
					end
					if cooldownCount > 0 then
						replicateDuration = Max(weightedCooldownSum / weightSum, math.pi)
					end
				end
				for slot = 0, 6 do
					local slotAbility = bot:GetAbilityInSlot(slot)
					if slotAbility ~= nil and slotAbility ~= morphReplicateAbility then
						ThinkAsReplicatedHero(slotAbility)
					end
				end
			end
		else
			local shouldMorphBack = true
			if
				bot:HasModifier("modifier_terrorblade_metamorphosis")
				or bot:HasModifier("modifier_terrorblade_metamorphosis_transform")
			then
				if hpRatio > 0.4 and isEngaging then
					shouldMorphBack = false
				end
			end
			if replicatedHeroName == "npc_dota_hero_obsidian_destroyer" then
				local firstAbility = bot:GetAbilityInSlot(0)
				local thirdAbility = bot:GetAbilityInSlot(2)
				if
					firstAbility
					and firstAbility:IsTrained()
					and firstAbility:GetLevel() >= 3
					and (thirdAbility and thirdAbility:IsTrained() and firstAbility:GetLevel() >= 3)
				then
					if isEngaging then
						shouldMorphBack = false
					end
				end
			end
			if shouldMorphBack then
				if bot.IsMorphling == false and Fu.CanCastAbility(morphReplicateAbility) then
					bot:Action_UseAbility(morphReplicateAbility)
					replicateTimes[2] = DotaTime()
					return
				end
			end
		end
	else
		replicateDuration = math.pi
		replicateTimes = { 0, math.huge }
		replicatedHeroName = ""
	end
	if bot.IsMorphling then
		X.SetRatios()
		attributeShiftDesire, attributeShiftType = X.ConsiderAtttributeShift()
		if attributeShiftDesire > 0 then
			if attributeShiftType == "agi" then
				bot:Action_UseAbility(morphAgiAbility)
			else
				bot:Action_UseAbility(morphStrAbility)
			end
			return
		end
		waveformDesire, waveformLocation = X.ConsiderWaveform()
		if waveformDesire > 0 then
			Fu.SetQueuePtToINT(bot, false)
			bot:ActionQueue_UseAbilityOnLocation(waveformAbility, waveformLocation)
			return
		end
		adaptiveStrikeDesire, adaptiveStrikeTarget = X.ConsiderAdaptiveStrikeAGI()
		if adaptiveStrikeDesire > 0 then
			Fu.SetQueuePtToINT(bot, false)
			bot:ActionQueue_UseAbilityOnEntity(adaptiveStrikeAgiAbility, adaptiveStrikeTarget)
			return
		end
		replicateDesire, replicateTarget = X.ConsiderMorph()
		if replicateDesire > 0 then
			bot:Action_UseAbilityOnEntity(replicateAbility, replicateTarget)
			replicateTimes[1] = DotaTime()
			replicatedHeroName = replicateTarget:GetUnitName()
			return
		end
	end
end
function X.ConsiderWaveform()
	if not Fu.CanCastAbility(waveformAbility) or bot:IsRooted() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local castRange = Fu.GetProperCastRange(false, bot, waveformAbility:GetCastRange())
	local castPoint = waveformAbility:GetCastPoint()
	local speed = waveformAbility:GetSpecialValueInt("speed")
	-- datafeed: Waveform damage is AbilityDamage 75/150/225/300; "#AbilityDamage" is not a special value key.
	local damage = waveformAbility:GetAbilityDamage()
	local width = waveformAbility:GetSpecialValueInt("width")
	local manaCost = waveformAbility:GetManaCost()
	local manaAfter = Fu.GetManaAfter(manaCost)
	local manaThreshold = Fu.GetManaThreshold(bot, manaCost, { adaptiveStrikeAgiAbility, replicateAbility })
	local manaThresholdAll =
		Fu.GetManaThreshold(bot, manaCost, { waveformAbility, adaptiveStrikeAgiAbility, replicateAbility })
	local teamFountain = Fu.GetTeamFountain()
	local retreatLocation = Fu.VectorTowards(bot:GetLocation(), teamFountain, castRange)
	if Fu.IsStuck(bot) then
		return BOT_ACTION_DESIRE_HIGH, retreatLocation
	end
	if not Fu.IsRealInvisible(bot) and not bot:IsMagicImmune() then
		if
			Fu.IsStunProjectileIncoming(bot, 500)
			or not bot:HasModifier("modifier_sniper_assassinate") and Fu.IsWillBeCastUnitTargetSpell(bot, 400)
		then
			return BOT_ACTION_DESIRE_HIGH, retreatLocation
		end
	end
	if isEngaging then
		if
			Fu.IsValidHero(botTarget)
			and Fu.CanBeAttacked(botTarget)
			and GetUnitToLocationDistance(botTarget, Fu.GetEnemyFountain()) > 1200
			and not Fu.IsInRange(bot, botTarget, bot:GetAttackRange())
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not botTarget:HasModifier("modifier_faceless_void_chronosphere_freeze")
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			local weAreStronger = Fu.WeAreStronger(bot, 1200)
			if #nearbyAllies >= #nearbyEnemies and weAreStronger then
				local travelTime = GetUnitToUnitDistance(bot, botTarget) / speed + castPoint
				local targetLocation = Fu.VectorAway(botTarget:GetLocation(), bot:GetLocation(), 300)
				local isUnderTower = botTarget:HasModifier("modifier_tower_aura_bonus")
				if GetUnitToLocationDistance(bot, targetLocation) <= castRange then
					if IsLocationPassable(targetLocation) then
						if Fu.IsInLaningPhase() then
							if
								not isUnderTower
								or Fu.WillKillTarget(botTarget, damage, DAMAGE_TYPE_MAGICAL, travelTime)
							then
								return BOT_ACTION_DESIRE_HIGH, targetLocation
							end
						else
							return BOT_ACTION_DESIRE_HIGH, targetLocation
						end
					end
				end
				if
					GetUnitToLocationDistance(bot, targetLocation) > castRange
					and GetUnitToLocationDistance(bot, targetLocation) < castRange + 350
				then
					if IsLocationPassable(targetLocation) then
						if Fu.IsInLaningPhase() then
							if
								not isUnderTower
								or Fu.WillKillTarget(botTarget, damage, DAMAGE_TYPE_MAGICAL, travelTime)
							then
								return BOT_ACTION_DESIRE_HIGH, targetLocation
							end
						else
							return BOT_ACTION_DESIRE_HIGH, targetLocation
						end
					end
				end
			end
		end
	end
	if isRetreating and not Fu.IsRealInvisible(bot) then
		for _, enemyHero in pairs(nearbyEnemies) do
			if Fu.IsValidHero(enemyHero) and not Fu.IsSuspiciousIllusion(enemyHero) then
				if
					Fu.IsChasingTarget(enemyHero, bot)
						and not Fu.IsInTeamFight(bot, 1200)
						and bot:WasRecentlyDamagedByAnyHero(3.0)
					or #nearbyEnemies > #nearbyAllies
					or hpRatio < 0.65 and bot:WasRecentlyDamagedByAnyHero(3.0)
				then
					return BOT_ACTION_DESIRE_HIGH, retreatLocation
				end
			end
		end
	end
	local nearbyCreeps = bot:GetNearbyCreeps(Min(castRange + 300, 1600), true)
	if
		Fu.IsPushing(bot)
		and isAttacking
		and manaAfter > manaThresholdAll
		and manaAfter > 0.5
		and #nearbyAllies <= 3
		and #nearbyEnemies == 0
	then
		for _, creep in pairs(nearbyCreeps) do
			if Fu.IsValid(creep) and Fu.CanBeAttacked(creep) then
				local aoeLocation = bot:FindAoELocation(true, false, creep:GetLocation(), 0, width, 0, 0)
				if aoeLocation.count >= 4 and IsLocationPassable(aoeLocation.targetloc) then
					return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
				end
			end
		end
	end
	if Fu.IsDefending(bot) and isAttacking and manaAfter > manaThreshold and #nearbyEnemies == 0 then
		for _, creep in pairs(nearbyCreeps) do
			if Fu.IsValid(creep) and Fu.CanBeAttacked(creep) then
				local aoeLocation = bot:FindAoELocation(true, false, creep:GetLocation(), 0, width, 0, 0)
				if aoeLocation.count >= 4 and IsLocationPassable(aoeLocation.targetloc) then
					return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
				end
			end
		end
	end
	if Fu.IsFarming(bot) and manaAfter > manaThresholdAll and #nearbyEnemies == 0 and not Fu.IsLateGame() then
		for _, creep in pairs(nearbyCreeps) do
			if Fu.IsValid(creep) and Fu.CanBeAttacked(creep) then
				local aoeLocation = bot:FindAoELocation(true, false, creep:GetLocation(), 0, width, 0, 0)
				if aoeLocation.count >= 3 or aoeLocation.count >= 2 and creep:IsAncientCreep() then
					local targetLocation = Fu.VectorAway(aoeLocation.targetloc, bot:GetLocation(), 350)
					if IsLocationPassable(targetLocation) then
						return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
					end
				end
			end
		end
	end
	if Fu.IsDoingRoshan(bot) and manaAfter > manaThresholdAll + 0.15 and manaAfter > 0.5 then
		local roshanLocation = Fu.GetCurrentRoshanLocation()
		if
			GetUnitToLocationDistance(bot, roshanLocation) > 2000
			and #nearbyEnemies == 0
			and IsLocationPassable(roshanLocation)
		then
			return BOT_ACTION_DESIRE_HIGH, Fu.VectorTowards(bot:GetLocation(), roshanLocation, castRange)
		end
	end
	if Fu.IsDoingTormentor(bot) and manaAfter > manaThresholdAll + 0.15 and manaAfter > 0.5 then
		local tormentorLocation = Fu.GetTormentorLocation()
		if
			GetUnitToLocationDistance(bot, tormentorLocation) > 2000
			and #nearbyEnemies == 0
			and IsLocationPassable(tormentorLocation)
		then
			return BOT_ACTION_DESIRE_HIGH, Fu.VectorTowards(bot:GetLocation(), tormentorLocation, castRange)
		end
	end
	local aoeLocation = bot:FindAoELocation(true, false, bot:GetLocation(), castRange, width, 0, damage)
	if aoeLocation.count >= 5 and #nearbyEnemies <= 1 and manaAfter > manaThresholdAll then
		return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.ConsiderAdaptiveStrikeAGI()
	if not Fu.CanCastAbility(adaptiveStrikeAgiAbility) then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castRange = Fu.GetProperCastRange(false, bot, adaptiveStrikeAgiAbility:GetCastRange())
	local castPoint = adaptiveStrikeAgiAbility:GetCastPoint()
	local damageMin = adaptiveStrikeAgiAbility:GetSpecialValueFloat("damage_min")
	local damageMax = adaptiveStrikeAgiAbility:GetSpecialValueFloat("damage_max")
	local agility = bot:GetAttributeValue(ATTRIBUTE_AGILITY)
	local strength = bot:GetAttributeValue(ATTRIBUTE_STRENGTH)
	local damage = adaptiveStrikeAgiAbility:GetSpecialValueInt("damage_base")
	local projectileSpeed = adaptiveStrikeAgiAbility:GetSpecialValueInt("projectile_speed")
	local manaCost = adaptiveStrikeAgiAbility:GetManaCost()
	local manaAfter = Fu.GetManaAfter(manaCost)
	local manaThreshold = Fu.GetManaThreshold(bot, manaCost, { waveformAbility, replicateAbility })
	local manaThresholdAll =
		Fu.GetManaThreshold(bot, manaCost, { waveformAbility, adaptiveStrikeAgiAbility, replicateAbility })
	local isAgilityStrike = agility > strength * 1.5
	if isAgilityStrike then
		damage = damage + damageMax * agility
	else
		damage = damage + damageMin * agility
	end
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.IsInRange(bot, enemyHero, castRange)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and Fu.CanCastOnTargetAdvanced(enemyHero)
		then
			local travelTime = GetUnitToUnitDistance(bot, enemyHero) / projectileSpeed + castPoint
			-- Interrupt a TP or channel at any attribute split: the stun is 0.5s even at minimum (stun_min,
			-- game data). It needed Strength 50% above Agility, which a carry Morphling almost never has.
			local interrupt = false
			if enemyHero:HasModifier("modifier_teleporting") then
				interrupt = Fu.GetModifierTime(enemyHero, "modifier_teleporting") > travelTime
			elseif
				enemyHero:IsChanneling()
				and manaAfter > manaThresholdAll
				and not Fu.IsRealInvisible(bot)
				and not isRetreating
			then
				interrupt = true
			end
			if interrupt then
				if DotaTime() >= (bot._morphIntLogAt or -999) then
					bot._morphIntLogAt = DotaTime() + 3
					pcall(
						print,
						string.format(
							"[OHA-MORPH] t=%.0f strike-interrupt target=%s agi=%d str=%d",
							DotaTime(),
							(string.gsub(enemyHero:GetUnitName(), "npc_dota_hero_", "")),
							math.floor(agility),
							math.floor(strength)
						)
					)
				end
				return BOT_ACTION_DESIRE_HIGH, enemyHero
			end
			if
				Fu.WillKillTarget(enemyHero, damage, DAMAGE_TYPE_MAGICAL, travelTime)
				and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
				and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
				and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
				and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
				and not enemyHero:HasModifier("modifier_troll_warlord_battle_trance")
			then
				return BOT_ACTION_DESIRE_HIGH, enemyHero
			end
		end
	end
	if Fu.IsInTeamFight(bot, 1200) and isAgilityStrike then
		local bestTarget = nil
		local bestDamageRatio = 0
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.CanBeAttacked(enemyHero)
				and Fu.IsInRange(bot, enemyHero, castRange)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
				and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
				and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
				and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
				and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
				and not enemyHero:HasModifier("modifier_templar_assassin_refraction_absorb")
				and not enemyHero:HasModifier("modifier_troll_warlord_battle_trance")
			then
				if Fu.IsInEtherealForm(enemyHero) then
					return BOT_ACTION_DESIRE_HIGH, enemyHero
				end
				local damageRatio = enemyHero:GetActualIncomingDamage(damage, DAMAGE_TYPE_MAGICAL)
					/ enemyHero:GetHealth()
				if damageRatio > bestDamageRatio then
					bestTarget = enemyHero
					bestDamageRatio = damageRatio
				end
			end
		end
		if bestTarget then
			return BOT_ACTION_DESIRE_HIGH, bestTarget
		end
	end
	if isEngaging and isAgilityStrike then
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanBeAttacked(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.CanCastOnTargetAdvanced(botTarget)
			and Fu.GetHP(botTarget) < 0.6
			and not botTarget:HasModifier("modifier_abaddon_borrowed_time")
			and not botTarget:HasModifier("modifier_dazzle_shallow_grave")
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
			and not botTarget:HasModifier("modifier_oracle_false_promise_timer")
			and not botTarget:HasModifier("modifier_ursa_enrage")
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end
	if isRetreating and not Fu.IsRealInvisible(bot) and not isAgilityStrike then
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.CanBeAttacked(enemyHero)
				and Fu.IsInRange(bot, enemyHero, castRange)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
				and not Fu.IsDisabled(enemyHero)
				and bot:WasRecentlyDamagedByHero(enemyHero, 3.0)
			then
				return BOT_ACTION_DESIRE_HIGH, enemyHero
			end
		end
	end
	local nearbyCreeps = bot:GetNearbyCreeps(Min(castRange + 300, 1600), true)
	if Fu.IsFarming(bot) and manaAfter > manaThreshold and (isStrengthPrimary or isAgilityStrike) then
		local bestCreep = nil
		local bestCreepRatio = 0
		for _, creep in pairs(nearbyCreeps) do
			if
				Fu.IsValid(creep)
				and Fu.CanBeAttacked(creep)
				and Fu.CanCastOnTargetAdvanced(creep)
				and Fu.GetHP(creep) > 0.4
			then
				local creepDamageRatio = creep:GetActualIncomingDamage(damage, DAMAGE_TYPE_MAGICAL) / creep:GetHealth()
				if creepDamageRatio > bestCreepRatio then
					bestCreep = creep
					bestCreepRatio = creepDamageRatio
				end
			end
		end
		if bestCreep then
			return BOT_ACTION_DESIRE_HIGH, bestCreep
		end
	end
	if Fu.IsLaning(bot) and Fu.IsInLaningPhase() and manaAfter > manaThreshold then
		local nearbyLaneCreeps = bot:GetNearbyLaneCreeps(castRange, true)
		for _, creep in pairs(nearbyLaneCreeps) do
			if
				Fu.IsValid(creep)
				and Fu.CanBeAttacked(creep)
				and Fu.CanCastOnTargetAdvanced(creep)
				and (
					not isStrengthPrimary
						and (Fu.IsKeyWordUnit("ranged", creep) or Fu.IsKeyWordUnit("siege", creep) or Fu.IsKeyWordUnit(
							"flagbearer",
							creep
						))
					or manaAfter > 0.5
				)
			then
				local travelTime = GetUnitToUnitDistance(bot, creep) / projectileSpeed + castPoint
				if Fu.WillKillTarget(creep, damage, DAMAGE_TYPE_MAGICAL, travelTime) then
					local aoeLocation = bot:FindAoELocation(true, true, creep:GetLocation(), 0, 600, 0, 0)
					if aoeLocation.count > 0 or Fu.IsUnitTargetedByTower(creep, false) then
						return BOT_ACTION_DESIRE_HIGH, creep
					end
				end
			end
		end
	end
	if Fu.IsDoingRoshan(bot) and isAgilityStrike then
		if
			Fu.IsRoshan(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and Fu.CanBeAttacked(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and isAttacking
			and manaAfter > manaThreshold
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end
	if Fu.IsDoingTormentor(bot) and isAgilityStrike then
		if
			Fu.IsTormentor(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and isAttacking
			and manaAfter > manaThreshold
		then
			-- Return the Tormentor: the caller casts on the second value, which was nil here.
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function X.ConsiderAtttributeShift()
	if not Fu.CanCastAbility(morphAgiAbility) or not Fu.CanCastAbility(morphStrAbility) then
		return BOT_ACTION_DESIRE_NONE
	end
	local netWorth = bot:GetNetWorth()
	local attackRange = bot:GetAttackRange()
	local isAgiMorphOn = morphAgiAbility:GetToggleState()
	local isStrMorphOn = morphStrAbility:GetToggleState()
	local alliesNearBot = Fu.GetAlliesNearLoc(bot:GetLocation(), 1200)
	local enemiesNearBot = Fu.GetEnemiesNearLoc(bot:GetLocation(), 1200)
	local nearbyTowers = bot:GetNearbyTowers(1100, true)
	local weAreStronger = Fu.WeAreStronger(bot, 1600)
	local agility = bot:GetAttributeValue(ATTRIBUTE_AGILITY)
	local strength = bot:GetAttributeValue(ATTRIBUTE_STRENGTH)
	local agiStrRatio = agility / strength * 1.5
	if isRetreating and not Fu.IsRealInvisible(bot) and bot:WasRecentlyDamagedByAnyHero(5.0) then
		if bot:WasRecentlyDamagedByAnyHero(3.0) then
			if isStrMorphOn == false then
				return BOT_ACTION_DESIRE_HIGH, "str"
			end
			return BOT_ACTION_DESIRE_NONE, ""
		end
		if bot:HasModifier("modifier_fountain_aura_buff") and #enemiesNearBot == 0 then
			if agiRatio < 0.5 then
				if isAgiMorphOn == false then
					return BOT_ACTION_DESIRE_HIGH, "agi"
				end
				return BOT_ACTION_DESIRE_NONE, ""
			else
				if agiRatio > 0.5 + 0.02 then
					if isStrMorphOn == false then
						return BOT_ACTION_DESIRE_HIGH, "str"
					end
					return BOT_ACTION_DESIRE_NONE, ""
				end
			end
			return BOT_ACTION_DESIRE_NONE, ""
		end
		if isStrMorphOn == true then
			return BOT_ACTION_DESIRE_HIGH, "str"
		end
		return BOT_ACTION_DESIRE_NONE, ""
	end
	if isStrengthPrimary then
		if netWorth > 30000 then
			if agiStrRatio < 1.0 then
				if isAgiMorphOn == false then
					return BOT_ACTION_DESIRE_HIGH, "agi"
				end
				return BOT_ACTION_DESIRE_NONE, ""
			else
				if agiStrRatio > 1.0 + 0.02 then
					if isStrMorphOn == false then
						return BOT_ACTION_DESIRE_HIGH, "str"
					end
					return BOT_ACTION_DESIRE_NONE, ""
				end
			end
		else
			local targetAgiRatio = Fu.IsInLaningPhase() and 0.4 or 0.6
			if netWorth > 20000 then
				targetAgiRatio = 0.5
			end
			if agiRatio < targetAgiRatio then
				if isAgiMorphOn == false then
					return BOT_ACTION_DESIRE_HIGH, "agi"
				end
				return BOT_ACTION_DESIRE_NONE, ""
			end
			if agiRatio > targetAgiRatio + 0.02 then
				if isStrMorphOn == false then
					return BOT_ACTION_DESIRE_HIGH, "str"
				end
				return BOT_ACTION_DESIRE_NONE, ""
			end
		end
	else
		if isEngaging then
			if
				Fu.IsValidHero(botTarget)
				and (Fu.CanBeAttacked(botTarget) or #enemiesNearBot > 1)
				and Fu.IsInRange(bot, botTarget, attackRange + 300)
				and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
			then
				local targetAgiRatio = RemapValClamped(netWorth, 5000, 25000, 0.5, 0.90)
				if #enemiesNearBot > #alliesNearBot and not weAreStronger then
					targetAgiRatio = targetAgiRatio * 0.75
				end
				if agiRatio < targetAgiRatio and hpRatio > 0.3 then
					if isAgiMorphOn == false then
						return BOT_ACTION_DESIRE_HIGH, "agi"
					end
					return BOT_ACTION_DESIRE_NONE, ""
				else
					if agiRatio > targetAgiRatio + 0.02 then
						if isStrMorphOn == false then
							return BOT_ACTION_DESIRE_HIGH, "str"
						end
						return BOT_ACTION_DESIRE_NONE, ""
					end
				end
			end
		end
		if Fu.IsPushing(bot) or Fu.IsDefending(bot) then
			local targetAgiRatio = RemapValClamped(netWorth, 5000, 20000, 0.5, 0.75)
			if #enemiesNearBot > #alliesNearBot and not weAreStronger then
				targetAgiRatio = targetAgiRatio * 0.75
			end
			if agiRatio < targetAgiRatio and hpRatio > 0.3 then
				if isAgiMorphOn == false then
					return BOT_ACTION_DESIRE_HIGH, "agi"
				end
				return BOT_ACTION_DESIRE_NONE, ""
			else
				if agiRatio > targetAgiRatio + 0.02 then
					if isStrMorphOn == false then
						return BOT_ACTION_DESIRE_HIGH, "str"
					end
					return BOT_ACTION_DESIRE_NONE, ""
				end
			end
		end
		if Fu.IsLaning(bot) and Fu.IsInLaningPhase() then
			local targetAgiRatio = RemapValClamped(bot:GetLevel(), 1, 6, 0.55, 0.6)
			if agiRatio < targetAgiRatio then
				if isAgiMorphOn == false then
					return BOT_ACTION_DESIRE_HIGH, "agi"
				end
				return BOT_ACTION_DESIRE_NONE, ""
			else
				if agiRatio > targetAgiRatio + 0.02 then
					if isStrMorphOn == false then
						return BOT_ACTION_DESIRE_HIGH, "str"
					end
					return BOT_ACTION_DESIRE_NONE, ""
				end
			end
		end
		if Fu.IsFarming(bot) and hpRatio > 0.3 then
			local targetAgiRatio = RemapValClamped(netWorth, 5000, 20000, 0.55, 0.85)
			if agiRatio < targetAgiRatio then
				if isAgiMorphOn == false then
					return BOT_ACTION_DESIRE_HIGH, "agi"
				end
				return BOT_ACTION_DESIRE_NONE, ""
			else
				if agiRatio > targetAgiRatio + 0.02 then
					if isStrMorphOn == false then
						return BOT_ACTION_DESIRE_HIGH, "str"
					end
					return BOT_ACTION_DESIRE_NONE, ""
				end
			end
		end
		if Fu.IsDoingRoshan(bot) or Fu.IsDoingTormentor(bot) then
			if
				(Fu.IsRoshan(botTarget) or Fu.IsTormentor(botTarget))
				and Fu.CanBeAttacked(botTarget)
				and Fu.IsInRange(bot, botTarget, 1000)
			then
				local targetAgiRatio = RemapValClamped(netWorth, 5000, 20000, 0.5, 0.85)
				if agiRatio < targetAgiRatio and hpRatio > 0.35 then
					if isAgiMorphOn == false then
						return BOT_ACTION_DESIRE_HIGH, "agi"
					end
					return BOT_ACTION_DESIRE_NONE, ""
				else
					if agiRatio > targetAgiRatio + 0.02 then
						if isStrMorphOn == false then
							return BOT_ACTION_DESIRE_HIGH, "str"
						end
						return BOT_ACTION_DESIRE_NONE, ""
					end
				end
			end
		end
	end
	if isStrMorphOn == true then
		return BOT_ACTION_DESIRE_HIGH, "str"
	end
	if isAgiMorphOn == true then
		return BOT_ACTION_DESIRE_HIGH, "agi"
	end
	return BOT_ACTION_DESIRE_NONE, ""
end
function X.ConsiderMorph()
	if not Fu.CanCastAbility(replicateAbility) then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castRange = Fu.GetProperCastRange(false, bot, replicateAbility:GetCastRange())
	if Fu.IsInTeamFight(bot, 1200) then
		local bestTarget = nil
		local bestScore = 0
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.IsInRange(bot, enemyHero, castRange)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and not string.find(enemyHero:GetUnitName(), "huskar")
				and not string.find(enemyHero:GetUnitName(), "invoker")
			then
				local spellDamage = enemyHero:GetEstimatedDamageToTarget(false, bot, 5.0, DAMAGE_TYPE_MAGICAL)
					+ enemyHero:GetEstimatedDamageToTarget(false, bot, 5.0, DAMAGE_TYPE_PURE)
				if spellDamage > bestScore then
					bestTarget = enemyHero
					bestScore = spellDamage
				end
			end
		end
		if bestTarget then
			return BOT_ACTION_DESIRE_HIGH, bestTarget
		end
	end
	if isEngaging then
		if
			Fu.IsValidHero(botTarget)
			and Fu.CanBeAttacked(botTarget)
			and Fu.IsInRange(bot, botTarget, 1200)
			and Fu.GetHP(botTarget) < 0.5
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not botTarget:HasModifier("modifier_abaddon_borrowed_time")
			and not botTarget:HasModifier("modifier_dazzle_shallow_grave")
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
			and not botTarget:HasModifier("modifier_oracle_false_promise_timer")
		then
			local duration = 6.0
			local totalAllyDamage = Fu.GetTotalEstimatedDamageToTarget(nearbyAllies, botTarget, duration)
			if
				totalAllyDamage > botTarget:GetHealth() + botTarget:GetHealthRegen() * duration
				and #nearbyAllies >= #nearbyEnemies
				and hpRatio > 0.4
			then
				local enemiesNearBot = Fu.GetEnemiesNearLoc(bot:GetLocation(), 1200)
				if not Fu.IsLateGame() and #enemiesNearBot > 0 or #enemiesNearBot > 1 then
					local bestTarget = nil
					local bestScore = -math.huge
					for _, enemyHero in pairs(enemiesNearBot) do
						if
							Fu.IsValidHero(enemyHero)
							and Fu.CanCastOnTargetAdvanced(enemyHero)
							and not enemyHero:HasModifier("modifier_skeleton_king_reincarnation_scepter_active")
							and not enemyHero:HasModifier("modifier_item_helm_of_the_undying_active")
							and not string.find(enemyHero:GetUnitName(), "huskar")
							and not string.find(enemyHero:GetUnitName(), "invoker")
						then
							local spellDamage = enemyHero:GetEstimatedDamageToTarget(
								false,
								bot,
								5.0,
								DAMAGE_TYPE_MAGICAL
							) + enemyHero:GetEstimatedDamageToTarget(false, bot, 5.0, DAMAGE_TYPE_PURE)
							local engageScore = GetMorphEngageScore(enemyHero:GetUnitName()) * spellDamage
							if engageScore > bestScore then
								bestTarget = enemyHero
								bestScore = engageScore
							end
						end
					end
					if bestTarget ~= nil then
						return BOT_ACTION_DESIRE_HIGH, bestTarget
					end
				end
			end
		end
	end
	if
		isRetreating
		and not Fu.IsRealInvisible(bot)
		and bot:GetActiveModeDesire() > BOT_MODE_DESIRE_HIGH
		and bot:WasRecentlyDamagedByAnyHero(3.0)
		and not Fu.CanCastAbility(waveformAbility, 3.0)
		and hpRatio > 0.5
	then
		local bestTarget = nil
		local bestScore = 0
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.IsInRange(bot, enemyHero, castRange)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
			then
				local retreatScore = GetMorphRetreatScore(enemyHero:GetUnitName())
				if retreatScore > 0 and retreatScore > bestScore then
					bestTarget = enemyHero
					bestScore = retreatScore
				end
			end
		end
		if bestTarget ~= nil then
			return BOT_ACTION_DESIRE_HIGH, bestTarget
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function X.SetRatios()
	local talentStatLevels = 0
	local bonusAgility = 0
	local bonusStrength = 0
	local primaryAttribute = bot:GetPrimaryAttribute()
	local itemSlots = { 0, 1, 2, 3, 4, 5, 16, 17 }
	for i = 1, #itemSlots do
		local item = bot:GetItemInSlot(itemSlots[i])
		if item then
			local itemName = item:GetName()
			if string.find(itemName, "item_power_treads") then
				local bonusStat = item:GetSpecialValueInt("bonus_stat")
				local treadsStat = item:GetPowerTreadsStat()
				if treadsStat == ATTRIBUTE_AGILITY then
					bonusAgility = bonusAgility + bonusStat
				elseif treadsStat == ATTRIBUTE_STRENGTH then
					bonusStrength = bonusStrength + bonusStat
				end
			end
			if string.find(itemName, "evolved") then
				local primaryStatBonus = item:GetSpecialValueInt("primary_stat")
				if primaryAttribute == ATTRIBUTE_AGILITY then
					bonusAgility = bonusAgility + primaryStatBonus
				elseif primaryAttribute == ATTRIBUTE_STRENGTH then
					bonusStrength = bonusStrength + primaryStatBonus
				end
			end
			local bonusAllStats = item:GetSpecialValueInt("bonus_all_stats")
			bonusAgility = bonusAgility + item:GetSpecialValueInt("bonus_agility") + bonusAllStats
			bonusStrength = bonusStrength + item:GetSpecialValueInt("bonus_strength") + bonusAllStats
		end
	end
	talentStatLevels = 0
	if bot:GetLevel() >= 26 then
		talentStatLevels = 7
	elseif bot:GetLevel() >= 24 then
		talentStatLevels = 6
	elseif bot:GetLevel() >= 23 then
		talentStatLevels = 5
	elseif bot:GetLevel() >= 22 then
		talentStatLevels = 4
	elseif bot:GetLevel() >= 21 then
		talentStatLevels = 3
	elseif bot:GetLevel() >= 19 then
		talentStatLevels = 2
	elseif bot:GetLevel() >= 17 then
		talentStatLevels = 1
	end
	if primaryAttribute == ATTRIBUTE_AGILITY then
		bonusAgility = bonusAgility + talentStatLevels * 3 + talentStatLevels * 2
		bonusStrength = bonusStrength + talentStatLevels * 2
	elseif primaryAttribute == ATTRIBUTE_STRENGTH then
		bonusAgility = bonusAgility + talentStatLevels * 2
		bonusStrength = bonusStrength + talentStatLevels * 3 + talentStatLevels * 2
	end
	local agilityTalent = bot:GetAbilityInSlot(14)
	local strengthTalent = bot:GetAbilityInSlot(16)
	if agilityTalent ~= nil and agilityTalent:IsTrained() then
		bonusAgility = bonusAgility + agilityTalent:GetSpecialValueInt("value")
	end
	if strengthTalent ~= nil and strengthTalent:IsTrained() then
		bonusStrength = bonusStrength + strengthTalent:GetSpecialValueInt("value")
	end
	local expectedBaseAgility = baseAgility + agilityGain * (bot:GetLevel() - 1)
	local expectedBaseStrength = baseStrength + strengthGain * (bot:GetLevel() - 1)
	local currentAgility = bot:GetAttributeValue(ATTRIBUTE_AGILITY)
	local currentStrength = bot:GetAttributeValue(ATTRIBUTE_STRENGTH)
	local agilityGained = currentAgility - expectedBaseAgility
	local strengthGained = currentStrength - expectedBaseStrength
	local morphableAgility = expectedBaseAgility + agilityGained - bonusAgility
	local morphableStrength = expectedBaseStrength + strengthGained - bonusStrength
	agiRatio = morphableAgility / (morphableAgility + morphableStrength)
end
local function MakeMorphScore(scoreEngage, scoreRetreat, goodToEngageBack, goodToRetreatBack)
	return {
		scoreEngage = scoreEngage,
		scoreRetreat = scoreRetreat,
		goodToEngageBack = goodToEngageBack,
		goodToRetreatBack = goodToRetreatBack,
	}
end
local morphTargetScores = {
	["npc_dota_hero_abaddon"] = MakeMorphScore(0.3, 0.1, false, false),
	["npc_dota_hero_abyssal_underlord"] = MakeMorphScore(0.8, 0.5, true, true),
	["npc_dota_hero_alchemist"] = MakeMorphScore(0.4, 0.2, false, false),
	["npc_dota_hero_ancient_apparition"] = MakeMorphScore(0.7, 0.4, true, false),
	["npc_dota_hero_antimage"] = MakeMorphScore(0.5, 0.9, true, true),
	["npc_dota_hero_arc_warden"] = MakeMorphScore(0.4, 0.1, true, false),
	["npc_dota_hero_axe"] = MakeMorphScore(0.3, 0.5, false, false),
	["npc_dota_hero_bane"] = MakeMorphScore(0.8, 0.5, true, true),
	["npc_dota_hero_batrider"] = MakeMorphScore(0.3, 0.3, false, false),
	["npc_dota_hero_beastmaster"] = MakeMorphScore(0.2, 0.2, false, false),
	["npc_dota_hero_bloodseeker"] = MakeMorphScore(0.2, 0.1, false, false),
	["npc_dota_hero_bounty_hunter"] = MakeMorphScore(0.2, 0.6, false, true),
	["npc_dota_hero_brewmaster"] = MakeMorphScore(0.3, 0.3, false, false),
	["npc_dota_hero_bristleback"] = MakeMorphScore(0.4, 0.2, false, false),
	["npc_dota_hero_broodmother"] = MakeMorphScore(0.5, 0.1, false, false),
	["npc_dota_hero_centaur"] = MakeMorphScore(0.4, 0.3, true, false),
	["npc_dota_hero_chaos_knight"] = MakeMorphScore(0.6, 0.5, true, false),
	["npc_dota_hero_chen"] = MakeMorphScore(0.4, 0.1, false, false),
	["npc_dota_hero_clinkz"] = MakeMorphScore(0.3, 0.2, false, false),
	["npc_dota_hero_crystal_maiden"] = MakeMorphScore(0.8, 0.8, true, true),
	["npc_dota_hero_dark_seer"] = MakeMorphScore(0.2, 0.5, true, true),
	["npc_dota_hero_dark_willow"] = MakeMorphScore(0.6, 0.5, true, true),
	["npc_dota_hero_dawnbreaker"] = MakeMorphScore(0.6, 0.4, true, false),
	["npc_dota_hero_dazzle"] = MakeMorphScore(0.8, 0.2, true, false),
	["npc_dota_hero_death_prophet"] = MakeMorphScore(0.5, 0.2, true, false),
	["npc_dota_hero_disruptor"] = MakeMorphScore(0.8, 0.5, true, true),
	["npc_dota_hero_doom_bringer"] = MakeMorphScore(0.2, 0.1, false, false),
	["npc_dota_hero_dragon_knight"] = MakeMorphScore(0.6, 0.8, true, true),
	["npc_dota_hero_drow_ranger"] = MakeMorphScore(0.2, 0.2, false, false),
	["npc_dota_hero_earth_spirit"] = MakeMorphScore(0.8, 1, true, true),
	["npc_dota_hero_earthshaker"] = MakeMorphScore(1, 1, true, true),
	["npc_dota_hero_elder_titan"] = MakeMorphScore(0.1, 0.1, false, false),
	["npc_dota_hero_ember_spirit"] = MakeMorphScore(0.5, 0.4, true, true),
	["npc_dota_hero_enchantress"] = MakeMorphScore(0.2, 0.2, false, false),
	["npc_dota_hero_enigma"] = MakeMorphScore(0.2, 0.5, false, false),
	["npc_dota_hero_faceless_void"] = MakeMorphScore(0.5, 0.5, true, true),
	["npc_dota_hero_furion"] = MakeMorphScore(0.5, 0.5, true, true),
	["npc_dota_hero_grimstroke"] = MakeMorphScore(0.8, 0.4, true, true),
	["npc_dota_hero_gyrocopter"] = MakeMorphScore(0.6, 0.4, true, false),
	["npc_dota_hero_hoodwink"] = MakeMorphScore(0.5, 0.3, true, false),
	["npc_dota_hero_huskar"] = MakeMorphScore(0.2, 0.1, false, false),
	["npc_dota_hero_invoker"] = MakeMorphScore(0.5, 0.3, true, false),
	["npc_dota_hero_jakiro"] = MakeMorphScore(0.6, 0.6, true, false),
	["npc_dota_hero_juggernaut"] = MakeMorphScore(0.8, 0.3, true, true),
	["npc_dota_hero_keeper_of_the_light"] = MakeMorphScore(0.2, 0.2, false, false),
	["npc_dota_hero_kunkka"] = MakeMorphScore(0.4, 0.4, true, true),
	["npc_dota_hero_legion_commander"] = MakeMorphScore(0.6, 0.4, true, true),
	["npc_dota_hero_leshrac"] = MakeMorphScore(0.6, 0.4, true, true),
	["npc_dota_hero_lich"] = MakeMorphScore(0.7, 0.2, true, false),
	["npc_dota_hero_life_stealer"] = MakeMorphScore(0.8, 0.4, true, true),
	["npc_dota_hero_lina"] = MakeMorphScore(0.4, 0.2, true, true),
	["npc_dota_hero_lion"] = MakeMorphScore(1, 1, true, true),
	["npc_dota_hero_lone_druid"] = MakeMorphScore(0.1, 0.1, false, false),
	["npc_dota_hero_luna"] = MakeMorphScore(0.4, 0.2, false, false),
	["npc_dota_hero_lycan"] = MakeMorphScore(0.7, 0.2, true, false),
	["npc_dota_hero_magnataur"] = MakeMorphScore(0.4, 0.7, true, true),
	["npc_dota_hero_marci"] = MakeMorphScore(0.3, 0.3, false, false),
	["npc_dota_hero_mars"] = MakeMorphScore(0.7, 0.4, true, true),
	["npc_dota_hero_medusa"] = MakeMorphScore(0.1, 0.2, true, false),
	["npc_dota_hero_meepo"] = MakeMorphScore(0.2, 0.2, false, false),
	["npc_dota_hero_mirana"] = MakeMorphScore(0.3, 0.7, false, true),
	["npc_dota_hero_monkey_king"] = MakeMorphScore(0.4, 0.4, true, false),
	["npc_dota_hero_muerta"] = MakeMorphScore(0.5, 0.3, true, false),
	["npc_dota_hero_naga_siren"] = MakeMorphScore(0.2, 0.2, false, false),
	["npc_dota_hero_necrolyte"] = MakeMorphScore(0.2, 0.1, true, true),
	["npc_dota_hero_nevermore"] = MakeMorphScore(0.2, 0.1, true, false),
	["npc_dota_hero_night_stalker"] = MakeMorphScore(0.5, 0.2, true, false),
	["npc_dota_hero_nyx_assassin"] = MakeMorphScore(0.6, 0.6, true, true),
	["npc_dota_hero_obsidian_destroyer"] = MakeMorphScore(0.8, 0.8, true, true),
	["npc_dota_hero_ogre_magi"] = MakeMorphScore(0.8, 0.7, true, true),
	["npc_dota_hero_omniknight"] = MakeMorphScore(0.3, 0.3, true, false),
	["npc_dota_hero_oracle"] = MakeMorphScore(0.3, 0.3, true, false),
	["npc_dota_hero_pangolier"] = MakeMorphScore(0.5, 0.5, true, true),
	["npc_dota_hero_phantom_lancer"] = MakeMorphScore(0.1, 0.3, false, true),
	["npc_dota_hero_phantom_assassin"] = MakeMorphScore(0.3, 0.3, false, true),
	["npc_dota_hero_phoenix"] = MakeMorphScore(0.2, 0.2, false, false),
	["npc_dota_hero_primal_beast"] = MakeMorphScore(0.2, 0.2, false, false),
	["npc_dota_hero_puck"] = MakeMorphScore(0.6, 0.5, true, true),
	["npc_dota_hero_pudge"] = MakeMorphScore(0.5, 0.1, true, false),
	["npc_dota_hero_pugna"] = MakeMorphScore(0.4, 0.1, true, true),
	["npc_dota_hero_queenofpain"] = MakeMorphScore(0.9, 0.9, true, true),
	["npc_dota_hero_rattletrap"] = MakeMorphScore(0.2, 0.2, true, false),
	["npc_dota_hero_razor"] = MakeMorphScore(0.8, 0.2, true, false),
	["npc_dota_hero_riki"] = MakeMorphScore(0.2, 0.2, true, true),
	["npc_dota_hero_ringmaster"] = MakeMorphScore(0.4, 0.1, false, false),
	["npc_dota_hero_rubick"] = MakeMorphScore(0.3, 0.5, false, true),
	["npc_dota_hero_sand_king"] = MakeMorphScore(1, 1, true, true),
	["npc_dota_hero_shadow_demon"] = MakeMorphScore(0.8, 0.5, true, false),
	["npc_dota_hero_shadow_shaman"] = MakeMorphScore(0.9, 0.8, true, true),
	["npc_dota_hero_shredder"] = MakeMorphScore(0.4, 0.8, true, true),
	["npc_dota_hero_silencer"] = MakeMorphScore(0.2, 0.1, false, false),
	["npc_dota_hero_skeleton_king"] = MakeMorphScore(0.2, 0.3, false, false),
	["npc_dota_hero_skywrath_mage"] = MakeMorphScore(0.5, 0.1, true, false),
	["npc_dota_hero_slardar"] = MakeMorphScore(0.5, 0.5, true, true),
	["npc_dota_hero_slark"] = MakeMorphScore(0.7, 0.7, true, true),
	["npc_dota_hero_snapfire"] = MakeMorphScore(0.5, 0.5, true, false),
	["npc_dota_hero_sniper"] = MakeMorphScore(0.2, 0.1, false, false),
	["npc_dota_hero_spectre"] = MakeMorphScore(0.1, 0.1, false, false),
	["npc_dota_hero_spirit_breaker"] = MakeMorphScore(0.5, 0.5, true, true),
	["npc_dota_hero_storm_spirit"] = MakeMorphScore(0.2, 0.2, false, false),
	["npc_dota_hero_sven"] = MakeMorphScore(0.5, 0.5, true, true),
	["npc_dota_hero_techies"] = MakeMorphScore(0.3, 0.2, false, false),
	["npc_dota_hero_templar_assassin"] = MakeMorphScore(0.2, 0.1, false, false),
	["npc_dota_hero_terrorblade"] = MakeMorphScore(0.5, 0.1, false, false),
	["npc_dota_hero_tidehunter"] = MakeMorphScore(0.3, 0.3, false, false),
	["npc_dota_hero_tinker"] = MakeMorphScore(0.2, 0.1, false, false),
	["npc_dota_hero_tiny"] = MakeMorphScore(0.9, 0.7, true, true),
	["npc_dota_hero_treant"] = MakeMorphScore(0.3, 0.2, false, false),
	["npc_dota_hero_troll_warlord"] = MakeMorphScore(0.2, 0.2, false, false),
	["npc_dota_hero_tusk"] = MakeMorphScore(0.3, 0.6, false, true),
	["npc_dota_hero_undying"] = MakeMorphScore(0.1, 0.1, false, false),
	["npc_dota_hero_ursa"] = MakeMorphScore(0.5, 0.3, true, false),
	["npc_dota_hero_vengefulspirit"] = MakeMorphScore(0.7, 0.6, true, true),
	["npc_dota_hero_venomancer"] = MakeMorphScore(0.2, 0.1, false, false),
	["npc_dota_hero_viper"] = MakeMorphScore(0.2, 0.1, false, false),
	["npc_dota_hero_visage"] = MakeMorphScore(0.2, 0.1, false, false),
	["npc_dota_hero_void_spirit"] = MakeMorphScore(0.6, 0.6, true, true),
	["npc_dota_hero_warlock"] = MakeMorphScore(0.4, 0.2, false, false),
	["npc_dota_hero_weaver"] = MakeMorphScore(0.2, 0.8, false, true),
	["npc_dota_hero_windrunner"] = MakeMorphScore(0.4, 0.5, true, true),
	["npc_dota_hero_wisp"] = MakeMorphScore(0.1, 0.1, false, false),
	["npc_dota_hero_witch_doctor"] = MakeMorphScore(0.5, 0.5, true, false),
	["npc_dota_hero_zuus"] = MakeMorphScore(0.5, 0.2, true, false),
}
function GetMorphEngageScore(heroName)
	if morphTargetScores[heroName] and morphTargetScores[heroName].scoreEngage then
		return morphTargetScores[heroName].scoreEngage
	end
	return 0.1
end
function GetMorphRetreatScore(heroName)
	if morphTargetScores[heroName] and morphTargetScores[heroName].scoreRetreat then
		if morphTargetScores[heroName].scoreRetreat >= 0.5 then
			return morphTargetScores[heroName].scoreRetreat
		end
	end
	return -1
end
function IsGoodToMorphBack(heroName, forEngage)
	if morphTargetScores[heroName] then
		if forEngage then
			if morphTargetScores[heroName].goodToEngageBack then
				return morphTargetScores[heroName].goodToEngageBack
			end
		else
			if morphTargetScores[heroName].goodToRetreatBack then
				return morphTargetScores[heroName].goodToRetreatBack
			end
		end
	end
	return false
end
return X
