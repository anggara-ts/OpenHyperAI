-- Venomancer: skill build, item build, and ability use for this hero.
local X = {}
local bot = GetBot()
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local AbilityContext = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local Minion = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local sTalentList = Fu.Skill.GetTalentList(bot)
local sAbilityList = Fu.Skill.GetAbilityList(bot)
local sRole = Fu.Item.GetRoleItemsBuyList(bot)
local tTalentTreeList = { ["t25"] = { 0, 10 }, ["t20"] = { 0, 10 }, ["t15"] = { 10, 0 }, ["t10"] = { 10, 0 } }
local tAllAbilityBuildList = { { 1, 2, 3, 3, 3, 6, 3, 2, 2, 2, 6, 1, 1, 1, 6 } }
local nAbilityBuildList = Fu.Skill.GetRandomBuild(tAllAbilityBuildList)
local nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList)
local sUtility = "item_team_aura"
local sRoleItemsBuyList = {}
sRoleItemsBuyList["pos_4"] = {
	"item_double_tango",
	"item_double_branches",
	"item_blood_grenade",
	"item_boots",
	"item_magic_wand",
	"item_urn_of_shadows",
	"item_arcane_boots",
	"item_pavise",
	"item_guardian_greaves",
	"item_glimmer_cape",
	"item_spirit_vessel",
	"item_force_staff",
	"item_aghanims_shard",
	sUtility,
	"item_ultimate_scepter",
	"item_wind_waker",
	"item_ultimate_scepter_2",
	"item_moon_shard",
}
sRoleItemsBuyList["pos_5"] = {
	"item_double_tango",
	"item_double_branches",
	"item_blood_grenade",
	"item_boots",
	"item_magic_wand",
	"item_urn_of_shadows",
	"item_tranquil_boots",
	"item_pavise",
	"item_pipe",
	"item_glimmer_cape",
	"item_spirit_vessel",
	"item_force_staff",
	"item_boots_of_bearing",
	"item_aghanims_shard",
	"item_ultimate_scepter",
	"item_wind_waker",
	"item_ultimate_scepter_2",
	"item_moon_shard",
}
sRoleItemsBuyList["pos_3"] = {
	"item_tango",
	"item_double_branches",
	"item_faerie_fire",
	"item_circlet",
	"item_magic_wand",
	"item_boots",
	"item_ring_of_basilius",
	"item_arcane_boots",
	"item_shivas_guard",
	"item_cyclone",
	"item_kaya_and_sange",
	"item_bloodstone",
	"item_black_king_bar",
	"item_aghanims_shard",
	"item_octarine_core",
	"item_refresher",
	"item_moon_shard",
	"item_ultimate_scepter_2",
}
sRoleItemsBuyList["pos_1"] = {
	"item_crystal_maiden_outfit",
	"item_dragon_lance",
	"item_witch_blade",
	"item_hurricane_pike",
	"item_black_king_bar",
	"item_aghanims_shard",
	"item_ultimate_scepter",
	"item_sange_and_yasha",
	"item_devastator",
	"item_sheepstick",
	"item_moon_shard",
	"item_travel_boots",
	"item_ultimate_scepter_2",
	"item_travel_boots_2",
}
sRoleItemsBuyList["pos_2"] = {
	"item_mid_outfit",
	"item_dragon_lance",
	"item_witch_blade",
	"item_hurricane_pike",
	"item_black_king_bar",
	"item_aghanims_shard",
	"item_ultimate_scepter",
	"item_kaya_and_sange",
	"item_devastator",
	"item_sheepstick",
	"item_moon_shard",
	"item_travel_boots",
	"item_ultimate_scepter_2",
	"item_travel_boots_2",
}
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
local venomousGaleAbility =
	SafeAbility(bot:GetAbilityByName("venomancer_venomous_gale"), "venomancer_venomous_gale", "venomancer")
local snakebiteAbility = SafeAbility(bot:GetAbilityByName("venomancer_snakebite"), "venomancer_snakebite", "venomancer")
local plagueWardAbility =
	SafeAbility(bot:GetAbilityByName("venomancer_plague_ward"), "venomancer_plague_ward", "venomancer")
local noxiousPlagueAbility =
	SafeAbility(bot:GetAbilityByName("venomancer_noxious_plague"), "venomancer_noxious_plague", "venomancer")
local venomousGaleDesire, venomousGaleLocation
local snakebiteDesire, snakebiteTarget
local plagueWardDesire, plagueWardTarget, plagueWardOnEntity
local noxiousPlagueDesire, noxiousPlagueTarget
local botTarget
local isEngaging
local isAttacking
local mpRatio
function X.SkillsComplement()
	if Fu.CanNotUseAbility(bot) then
		return
	end
	local context = AbilityContext.Build(bot)
	isEngaging = context.isEngaging
	isAttacking = Fu.IsAttacking(bot)
	mpRatio = context.mp
	botTarget = context.target
	noxiousPlagueDesire, noxiousPlagueTarget = X.ConsiderNoxiousPlague()
	if noxiousPlagueDesire > 0 then
		bot:Action_UseAbilityOnEntity(noxiousPlagueAbility, noxiousPlagueTarget)
		return
	end
	snakebiteDesire, snakebiteTarget = X.ConsiderSnakebite()
	if snakebiteDesire > 0 then
		bot:Action_UseAbilityOnEntity(snakebiteAbility, snakebiteTarget)
		return
	end
	venomousGaleDesire, venomousGaleLocation = X.ConsiderVenomousGale()
	if venomousGaleDesire > 0 then
		bot:Action_UseAbilityOnLocation(venomousGaleAbility, venomousGaleLocation)
		return
	end
	plagueWardDesire, plagueWardTarget, plagueWardOnEntity = X.ConsiderPlagueWard()
	if plagueWardDesire > 0 then
		if plagueWardOnEntity then
			bot:Action_UseAbilityOnEntity(plagueWardAbility, plagueWardTarget)
		else
			bot:Action_UseAbilityOnLocation(plagueWardAbility, plagueWardTarget)
		end
		return
	end
end
function X.ConsiderVenomousGale()
	if not Fu.CanCastAbility(venomousGaleAbility) then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local castRange = Fu.GetProperCastRange(false, bot, venomousGaleAbility:GetCastRange())
	local radius = venomousGaleAbility:GetSpecialValueInt("radius")
	local strikeDamage = venomousGaleAbility:GetSpecialValueInt("strike_damage")
	local tickDamage = venomousGaleAbility:GetSpecialValueInt("tick_damage")
	-- datafeed: Venomous Gale deals strike_damage once plus tick_damage every tick_interval (3s) over duration (15s).
	-- The old kill check used strike * tick (25 * 10 = 250 at level 1, real total 75).
	local nGaleTicks = math.floor(
		venomousGaleAbility:GetSpecialValueInt("duration")
			/ math.max(1, venomousGaleAbility:GetSpecialValueInt("tick_interval"))
	)
	local nearbyEnemies = bot:GetNearbyHeroes(castRange, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and (Fu.CanKillTarget(enemyHero, strikeDamage, DAMAGE_TYPE_MAGICAL) or Fu.CanKillTarget(
				enemyHero,
				strikeDamage + tickDamage * nGaleTicks,
				DAMAGE_TYPE_MAGICAL
			))
			and not Fu.IsSuspiciousIllusion(enemyHero)
			and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
			and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
			and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
			and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
			and not enemyHero:HasModifier("modifier_templar_assassin_refraction_absorb")
		then
			if Fu.IsInLaningPhase() then
				local allyTowers = enemyHero:GetNearbyTowers(700, true)
				if
					allyTowers ~= nil
					and #allyTowers >= 1
					and Fu.IsValidBuilding(allyTowers[1])
					and allyTowers[1]:GetAttackTarget() == enemyHero
				then
					local enemiesNearTarget = Fu.GetEnemiesNearLoc(enemyHero:GetLocation(), radius)
					if enemiesNearTarget ~= nil and #enemiesNearTarget >= 1 then
						return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(enemiesNearTarget)
					end
					return BOT_ACTION_DESIRE_HIGH, enemyHero:GetLocation()
				end
			end
			return BOT_ACTION_DESIRE_HIGH, enemyHero:GetLocation()
		end
	end
	local nearbyAllies = bot:GetNearbyHeroes(castRange, false, BOT_MODE_NONE)
	for _, allyHero in pairs(nearbyAllies) do
		local enemiesNearAlly = allyHero:GetNearbyHeroes(1200, true, BOT_MODE_NONE)
		for _, enemyHero in pairs(enemiesNearAlly) do
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
					local enemiesNearTarget = Fu.GetEnemiesNearLoc(enemyHero:GetLocation(), radius)
					if enemiesNearTarget ~= nil and #enemiesNearTarget >= 1 then
						return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(enemiesNearTarget)
					end
					return BOT_ACTION_DESIRE_HIGH, enemyHero:GetLocation()
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
		then
			local alliesNearTarget = botTarget:GetNearbyHeroes(1200, true, BOT_MODE_NONE)
			local enemiesNearTarget = botTarget:GetNearbyHeroes(1200, false, BOT_MODE_NONE)
			if alliesNearTarget ~= nil and enemiesNearTarget ~= nil and #alliesNearTarget >= #enemiesNearTarget then
				enemiesNearTarget = Fu.GetEnemiesNearLoc(botTarget:GetLocation(), radius)
				if enemiesNearTarget ~= nil and #enemiesNearTarget >= 1 then
					return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(enemiesNearTarget)
				end
				return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
			end
		end
	end
	if Fu.IsRetreating(bot) then
		local nearbyEnemies = bot:GetNearbyHeroes(castRange, true, BOT_MODE_NONE)
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.IsChasingTarget(enemyHero, bot)
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and not Fu.IsDisabled(enemyHero)
			then
				local alliesNearTarget = enemyHero:GetNearbyHeroes(1200, true, BOT_MODE_NONE)
				local enemiesNearTarget = enemyHero:GetNearbyHeroes(1200, false, BOT_MODE_NONE)
				if
					alliesNearTarget ~= nil
					and enemiesNearTarget ~= nil
					and (#enemiesNearTarget > #alliesNearTarget or bot:WasRecentlyDamagedByAnyHero(2))
				then
					enemiesNearTarget = Fu.GetEnemiesNearLoc(enemyHero:GetLocation(), radius)
					if enemiesNearTarget ~= nil and #enemiesNearTarget >= 1 then
						return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(enemiesNearTarget)
					end
					return BOT_ACTION_DESIRE_HIGH, enemyHero:GetLocation()
				end
			end
		end
	end
	if (Fu.IsPushing(bot) or Fu.IsDefending(bot)) and not Fu.IsThereCoreNearby(1000) then
		local aoeLocation = bot:FindAoELocation(true, false, bot:GetLocation(), castRange, radius, 0, 0)
		local nearbyLaneCreeps = bot:GetNearbyLaneCreeps(castRange, true)
		if nearbyLaneCreeps ~= nil and #nearbyLaneCreeps >= 3 and aoeLocation.count >= 3 and mpRatio > 0.5 then
			return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(nearbyLaneCreeps)
		end
		aoeLocation = bot:FindAoELocation(true, true, bot:GetLocation(), castRange, radius, 0, 0)
		if aoeLocation.count >= 1 then
			return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
		end
	end
	if Fu.IsLaning(bot) then
		local killableCreepCount = 0
		local killableCreeps = {}
		local nearbyLaneCreeps = bot:GetNearbyLaneCreeps(castRange, true)
		local nearbyEnemies = bot:GetNearbyHeroes(castRange, true, BOT_MODE_NONE)
		for _, creep in pairs(nearbyLaneCreeps) do
			if Fu.IsValid(creep) and creep:GetHealth() <= strikeDamage then
				killableCreepCount = killableCreepCount + 1
				table.insert(killableCreeps, creep)
			end
		end
		if
			killableCreepCount >= 2
			and mpRatio > 0.41
			and nearbyEnemies ~= nil
			and #nearbyEnemies >= 1
			and Fu.CanBeAttacked(killableCreeps[1])
			and not Fu.IsThereCoreNearby(1200)
		then
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
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, 500) and isAttacking then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.ConsiderPlagueWard()
	if not Fu.CanCastAbility(plagueWardAbility) then
		return BOT_ACTION_DESIRE_NONE, 0, false
	end
	local castRange = Fu.GetProperCastRange(false, bot, plagueWardAbility:GetCastRange())
	local nearbyAllies = bot:GetNearbyHeroes(1600, false, BOT_MODE_NONE)
	local nearbyEnemies = bot:GetNearbyHeroes(1600, true, BOT_MODE_NONE)
	local selfCastCheck = 20 -- always 20, so the "< 8" and "< 6" self-cast branches below never run
	if isEngaging then
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanBeAttacked(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			if selfCastCheck < 8 then
				return BOT_ACTION_DESIRE_HIGH, bot, true
			else
				local towersNearTarget = botTarget:GetNearbyTowers(700, false)
				if towersNearTarget ~= nil and #towersNearTarget == 0 then
					return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation(), false
				end
			end
		end
	end
	if Fu.IsRetreating(bot) and not Fu.IsRealInvisible(bot) then
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.CanBeAttacked(enemyHero)
				and Fu.IsChasingTarget(enemyHero, bot)
				and not Fu.IsSuspiciousIllusion(enemyHero)
			then
				if Fu.GetHP(bot) < 0.75 and bot:WasRecentlyDamagedByAnyHero(3.0) or #nearbyAllies < #nearbyEnemies then
					if Fu.IsInRange(bot, enemyHero, 550) and selfCastCheck < 6 then
						return BOT_ACTION_DESIRE_HIGH, bot, true
					else
						return BOT_ACTION_DESIRE_HIGH, (bot:GetLocation() + enemyHero:GetLocation()) / 2, false
					end
				end
			end
		end
	end
	-- Push / defend / farm: wards were only placed when engaging or retreating, so the 5s ward
	-- (24-30 mana) never helped clear a wave or a camp. Keeps mana for Gale, Snakebite and the ult
	-- (same reserve idiom as Snakebite), and only with no enemy hero within 1600.
	if
		(Fu.IsPushing(bot) or Fu.IsDefending(bot) or Fu.IsFarming(bot))
		and Fu.GetManaAfter(plagueWardAbility:GetManaCost()) > Fu.GetManaThreshold(
			bot,
			plagueWardAbility:GetManaCost(),
			{ venomousGaleAbility, snakebiteAbility, noxiousPlagueAbility }
		)
		and #nearbyEnemies == 0
	then
		local spot = nil
		local nearbyLaneCreeps = bot:GetNearbyLaneCreeps(castRange, true)
		if nearbyLaneCreeps ~= nil and #nearbyLaneCreeps >= 3 then
			spot = Fu.GetCenterOfUnits(nearbyLaneCreeps)
		elseif
			Fu.IsFarming(bot)
			and Fu.IsValid(botTarget)
			and botTarget:GetTeam() == TEAM_NEUTRAL
			and Fu.IsInRange(bot, botTarget, castRange)
		then
			spot = botTarget:GetLocation()
		end
		if spot ~= nil then
			if DotaTime() >= (bot._wardLogAt or -999) then
				bot._wardLogAt = DotaTime() + 15
				pcall(
					print,
					string.format(
						"[OHA-VENOMANCER] t=%.0f plague-ward clear creeps=%d farm=%s",
						DotaTime(),
						nearbyLaneCreeps ~= nil and #nearbyLaneCreeps or 0,
						tostring(Fu.IsFarming(bot))
					)
				)
			end
			return BOT_ACTION_DESIRE_HIGH, spot, false
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0, false
end
function X.ConsiderNoxiousPlague()
	if not Fu.CanCastAbility(noxiousPlagueAbility) then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castRange = Fu.GetProperCastRange(false, bot, noxiousPlagueAbility:GetCastRange())
	if isEngaging then
		local bestTarget = nil
		local maxEstimatedDamage = 0
		local nearbyEnemies = bot:GetNearbyHeroes(castRange, true, BOT_MODE_NONE)
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				-- Noxious Plague is damage and a slow, not a disable: a stunned target is a good target, so
				-- "not disabled" is dropped. Linken's check added: an 80-100s ult must not pop a sphere.
				Fu.IsValidHero(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and not enemyHero:HasModifier("modifier_enigma_black_hole_pull")
				and not enemyHero:HasModifier("modifier_faceless_void_chronosphere_freeze")
				and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
				and not enemyHero:HasModifier("modifier_venomancer_latent_poison")
			then
				local alliesNearTarget = enemyHero:GetNearbyHeroes(1200, true, BOT_MODE_NONE)
				local enemiesNearTarget = enemyHero:GetNearbyHeroes(1200, false, BOT_MODE_NONE)
				local estimatedDamage = enemyHero:GetEstimatedDamageToTarget(true, bot, 5, DAMAGE_TYPE_ALL)
				if
					alliesNearTarget ~= nil
					and enemiesNearTarget ~= nil
					and #alliesNearTarget >= #enemiesNearTarget
					and #alliesNearTarget < #enemiesNearTarget + 2
					and maxEstimatedDamage < estimatedDamage
				then
					maxEstimatedDamage = estimatedDamage
					bestTarget = enemyHero
				end
			end
		end
		if bestTarget ~= nil then
			return BOT_ACTION_DESIRE_HIGH, bestTarget
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function X.ConsiderSnakebite()
	if not Fu.CanCastAbility(snakebiteAbility) then
		return BOT_ACTION_DESIRE_NONE
	end
	-- A queued bite clears his move order, and lane, farm, and retreat then wait
	-- on that queue. Cast only when the target is already in range.
	-- Real cast range (600), not GetProperCastRange's +200: the comment above wants the target
	-- already in range, and the +200 made him walk forward to bite.
	local castRange = snakebiteAbility:GetCastRange()
	local manaCost = snakebiteAbility:GetManaCost()
	local manaAfter = Fu.GetManaAfter(manaCost)
	local manaThreshold =
		Fu.GetManaThreshold(bot, manaCost, { venomousGaleAbility, plagueWardAbility, noxiousPlagueAbility })
	local hitByHero = bot:WasRecentlyDamagedByAnyHero(1.5)
	local hitByCreep = bot:WasRecentlyDamagedByCreep(1.5)
	if Fu.IsGoingOnSomeone(bot) and not Fu.IsRetreating(bot) then
		if
			Fu.IsValidHero(botTarget)
			and Fu.CanBeAttacked(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.CanCastOnTargetAdvanced(botTarget)
			-- Snakebite is only damage over time (npc data: base_damage + tick_damage, no disable), so
			-- the old "not disabled / not disarmed" checks only skipped stunned targets.
			and not botTarget:HasModifier("modifier_abaddon_borrowed_time")
			and not botTarget:HasModifier("modifier_dazzle_shallow_grave")
			and not botTarget:HasModifier("modifier_oracle_false_promise_timer")
			and not botTarget:HasModifier("modifier_templar_assassin_refraction_absorb")
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end
	if
		(Fu.IsPushing(bot) or Fu.IsDefending(bot) or Fu.IsFarming(bot))
		and isAttacking
		and manaAfter > manaThreshold
		and not hitByHero
		and not hitByCreep
	then
		if
			Fu.IsValid(botTarget)
			and Fu.CanBeAttacked(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and not botTarget:IsBuilding()
			and not botTarget:IsHero()
			and not Fu.CanKillTarget(botTarget, bot:GetAttackDamage() * 3.5, DAMAGE_TYPE_PHYSICAL)
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if
			Fu.IsRoshan(botTarget)
			and Fu.CanBeAttacked(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and isAttacking
			and manaAfter > manaThreshold + 0.1
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if
			Fu.IsTormentor(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and isAttacking
			and manaAfter > manaThreshold + 0.1
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
return X
