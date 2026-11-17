-- Vengefulspirit: skill build, item build, and ability use for this hero.
local X = {}
local bot = GetBot()
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local AbilityContext = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local Minion = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local sTalentList = Fu.Skill.GetTalentList(bot)
local sAbilityList = Fu.Skill.GetAbilityList(bot)
local sRole = Fu.Item.GetRoleItemsBuyList(bot)
local tTalentTreeList = { ["t25"] = { 10, 0 }, ["t20"] = { 0, 10 }, ["t15"] = { 0, 10 }, ["t10"] = { 0, 10 } }
local tAllAbilityBuildList = { { 2, 1, 1, 2, 1, 6, 1, 2, 2, 3, 6, 3, 3, 3, 6 } }
local nAbilityBuildList = Fu.Skill.GetRandomBuild(tAllAbilityBuildList)
local nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList)
local sRoleItemsBuyList = {}
sRoleItemsBuyList["pos_4"] = {
	"item_double_tango",
	"item_double_branches",
	"item_blood_grenade",
	"item_circlet",
	"item_boots",
	"item_magic_wand",
	"item_arcane_boots",
	"item_pavise",
	"item_solar_crest",
	"item_glimmer_cape",
	"item_guardian_greaves",
	"item_ultimate_scepter",
	"item_aghanims_shard",
	"item_force_staff",
	"item_lotus_orb",
	-- removed a second "item_aghanims_shard": the Shard is already bought a few lines up and only applies once
	"item_hurricane_pike",
	"item_moon_shard",
	"item_ultimate_scepter_2",
	"item_sheepstick",
}
sRoleItemsBuyList["pos_5"] = {
	"item_tango",
	"item_tango",
	"item_double_branches",
	"item_enchanted_mango",
	"item_enchanted_mango",
	"item_blood_grenade",
	"item_magic_wand",
	"item_tranquil_boots",
	"item_force_staff",
	"item_glimmer_cape",
	"item_pipe",
	"item_boots_of_bearing",
	"item_pavise",
	"item_solar_crest",
	"item_aghanims_shard",
	"item_ultimate_scepter",
	"item_hurricane_pike",
	"item_sheepstick",
	"item_aether_lens",
	"item_moon_shard",
	"item_ultimate_scepter_2",
}
-- Hydra's Breath (user call; Dotabuff 44%, #4 of matches): +30 agility, 30% of attacks also hit 3 more enemies in a cone.
sRoleItemsBuyList["pos_3"] = {
	"item_tango",
	"item_double_branches",
	"item_faerie_fire",
	"item_enchanted_mango",
	"item_magic_wand",
	"item_power_treads",
	"item_witch_blade",
	"item_ultimate_scepter",
	"item_force_staff",
	"item_hurricane_pike",
	"item_aghanims_shard",
	"item_black_king_bar",
	"item_manta",
	"item_hydras_breath",
	"item_sheepstick",
	"item_travel_boots",
	"item_moon_shard",
	"item_travel_boots_2",
	"item_ultimate_scepter_2",
}
sRoleItemsBuyList["pos_1"] = sRoleItemsBuyList["pos_3"]
sRoleItemsBuyList["pos_2"] = sRoleItemsBuyList["pos_3"]
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
function X.MinionThink(minionUnit)
	Minion.MinionThink(minionUnit)
end
local magicMissileAbility =
	SafeAbility(bot:GetAbilityByName("vengefulspirit_magic_missile"), "vengefulspirit_magic_missile", "vengefulspirit")
local waveOfTerrorAbility = SafeAbility(
	bot:GetAbilityByName("vengefulspirit_wave_of_terror"),
	"vengefulspirit_wave_of_terror",
	"vengefulspirit"
)
local netherSwapAbility =
	SafeAbility(bot:GetAbilityByName("vengefulspirit_nether_swap"), "vengefulspirit_nether_swap", "vengefulspirit")
local magicMissileDesire, magicMissileTarget
local waveOfTerrorDesire, waveOfTerrorLocation
local netherSwapDesire, netherSwapTarget
local botTarget
local isGoingOnSomeone
local isAttacking
function X.SkillsComplement()
	if Fu.CanNotUseAbility(bot) then
		return
	end
	local context = AbilityContext.Build(bot)
	isGoingOnSomeone = context.isEngaging
	isAttacking = Fu.IsAttacking(bot)
	botTarget = context.target
	netherSwapDesire, netherSwapTarget = X.ConsiderNetherSwap()
	if netherSwapDesire > 0 then
		bot:Action_UseAbilityOnEntity(netherSwapAbility, netherSwapTarget)
		return
	end
	magicMissileDesire, magicMissileTarget = X.ConsiderMagicMissile()
	if magicMissileDesire > 0 then
		bot:Action_UseAbilityOnEntity(magicMissileAbility, magicMissileTarget)
		return
	end
	waveOfTerrorDesire, waveOfTerrorLocation = X.ConsiderWaveOfTerror()
	if waveOfTerrorDesire > 0 then
		bot:Action_UseAbilityOnLocation(waveOfTerrorAbility, waveOfTerrorLocation)
		return
	end
end
function X.ConsiderMagicMissile()
	if not magicMissileAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castRange = Fu.GetProperCastRange(false, bot, magicMissileAbility:GetCastRange())
	local damage = magicMissileAbility:GetSpecialValueInt("magic_missile_damage")
	local enemiesInRange = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(enemiesInRange) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and not Fu.IsSuspiciousIllusion(enemyHero)
		then
			if enemyHero:IsChanneling() then
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
			if Fu.IsInLaningPhase() then
				local alliedTowers = enemyHero:GetNearbyTowers(700, true)
				if
					alliedTowers ~= nil
					and #alliedTowers >= 1
					and Fu.IsValidBuilding(alliedTowers[1])
					and alliedTowers[1]:GetAttackTarget() == enemyHero
				then
					return BOT_ACTION_DESIRE_HIGH, enemyHero
				end
			end
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
				and Fu.CanCastOnNonMagicImmune(enemiesNearAlly[1])
				and Fu.CanCastOnTargetAdvanced(enemiesNearAlly[1])
				and Fu.IsInRange(bot, enemiesNearAlly[1], castRange)
				and Fu.IsChasingTarget(enemiesNearAlly[1], allyHero)
				and enemiesNearAlly[1]:IsFacingLocation(allyHero:GetLocation(), 30)
				and not Fu.IsDisabled(enemiesNearAlly[1])
				and not Fu.IsTaunted(enemiesNearAlly[1])
				and not Fu.IsSuspiciousIllusion(enemiesNearAlly[1])
				and not enemiesNearAlly[1]:HasModifier("modifier_legion_commander_duel")
				and not enemiesNearAlly[1]:HasModifier("modifier_enigma_black_hole_pull")
				and not enemiesNearAlly[1]:HasModifier("modifier_faceless_void_chronosphere_freeze")
				and not enemiesNearAlly[1]:HasModifier("modifier_necrolyte_reapers_scythe")
			then
				return BOT_ACTION_DESIRE_HIGH, enemiesNearAlly[1]
			end
		end
	end
	if isGoingOnSomeone then
		local bestTarget = nil
		local highestDamage = 0
		local enemyHeroes = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
		for _, enemyHero in pairs(enemyHeroes) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and not Fu.IsDisabled(enemyHero)
				and not enemyHero:HasModifier("modifier_enigma_black_hole_pull")
				and not enemyHero:HasModifier("modifier_faceless_void_chronosphere_freeze")
				and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
			then
				local alliesNearTarget = Fu.GetNearbyHeroes(enemyHero, 1200, true, BOT_MODE_NONE)
				local enemiesNearTarget = Fu.GetNearbyHeroes(enemyHero, 1200, false, BOT_MODE_NONE)
				local estimatedDamage = enemyHero:GetEstimatedDamageToTarget(true, bot, 5, DAMAGE_TYPE_ALL)
				if
					alliesNearTarget ~= nil
					and enemiesNearTarget ~= nil
					and #alliesNearTarget >= #enemiesNearTarget
					and highestDamage < estimatedDamage
				then
					highestDamage = estimatedDamage
					bestTarget = enemyHero
				end
			end
		end
		if bestTarget ~= nil then
			return BOT_ACTION_DESIRE_HIGH, bestTarget
		end
	end
	if Fu.IsRetreating(bot) then
		local enemyHeroes = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
		for _, enemyHero in pairs(enemyHeroes) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.IsChasingTarget(enemyHero, bot)
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and not Fu.IsDisabled(enemyHero)
			then
				local alliesNearTarget = Fu.GetNearbyHeroes(enemyHero, 1200, true, BOT_MODE_NONE)
				local enemiesNearTarget = Fu.GetNearbyHeroes(enemyHero, 1200, false, BOT_MODE_NONE)
				if
					alliesNearTarget ~= nil
					and enemiesNearTarget ~= nil
					and (#enemiesNearTarget > #alliesNearTarget or bot:WasRecentlyDamagedByAnyHero(2))
				then
					return BOT_ACTION_DESIRE_HIGH, enemyHero
				end
			end
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if
			Fu.IsRoshan(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, 500)
			and isAttacking
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, 500) and isAttacking then
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function X.ConsiderWaveOfTerror()
	if not waveOfTerrorAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local castRange = Fu.GetProperCastRange(false, bot, waveOfTerrorAbility:GetCastRange())
	local waveWidth = waveOfTerrorAbility:GetSpecialValueInt("wave_width")
	-- datafeed: Wave of Terror's damage is the "damage" value (60/80/100/120); it has no AbilityDamage, so this was 0.
	local damage = waveOfTerrorAbility:GetSpecialValueInt("damage")
	local enemiesInRange = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(enemiesInRange) do
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
			local enemiesInWave = Fu.GetEnemiesNearLoc(enemyHero:GetLocation(), waveWidth)
			if enemiesInWave ~= nil and #enemiesInWave >= 1 then
				return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(enemiesInWave)
			end
			return BOT_ACTION_DESIRE_HIGH, enemyHero:GetLocation()
		end
	end
	if isGoingOnSomeone then
		local bestTarget = nil
		local highestDamage = 0
		local enemyHeroes = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
		for _, enemyHero in pairs(enemyHeroes) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and not Fu.IsDisabled(enemyHero)
				and not enemyHero:HasModifier("modifier_enigma_black_hole_pull")
				and not enemyHero:HasModifier("modifier_faceless_void_chronosphere_freeze")
				and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
			then
				local alliesNearTarget = Fu.GetNearbyHeroes(enemyHero, 1200, true, BOT_MODE_NONE)
				local enemiesNearTarget = Fu.GetNearbyHeroes(enemyHero, 1200, false, BOT_MODE_NONE)
				local estimatedDamage = enemyHero:GetEstimatedDamageToTarget(true, bot, 5, DAMAGE_TYPE_ALL)
				if
					alliesNearTarget ~= nil
					and enemiesNearTarget ~= nil
					and #alliesNearTarget >= #enemiesNearTarget
					and highestDamage < estimatedDamage
				then
					highestDamage = estimatedDamage
					bestTarget = enemyHero
				end
			end
		end
		if bestTarget ~= nil then
			enemyHeroes = Fu.GetEnemiesNearLoc(bestTarget:GetLocation(), waveWidth)
			if enemyHeroes ~= nil and #enemyHeroes >= 1 then
				return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(enemyHeroes)
			end
			return BOT_ACTION_DESIRE_HIGH, bestTarget:GetLocation()
		end
	end
	if Fu.IsRetreating(bot) then
		local enemyHeroes = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
		for _, enemyHero in pairs(enemyHeroes) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.IsChasingTarget(enemyHero, bot)
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and not Fu.IsDisabled(enemyHero)
			then
				local alliesNearTarget = Fu.GetNearbyHeroes(enemyHero, 1200, true, BOT_MODE_NONE)
				local enemiesNearTarget = Fu.GetNearbyHeroes(enemyHero, 1200, false, BOT_MODE_NONE)
				if
					alliesNearTarget ~= nil
					and enemiesNearTarget ~= nil
					and (#enemiesNearTarget > #alliesNearTarget or bot:WasRecentlyDamagedByAnyHero(2.5))
				then
					return BOT_ACTION_DESIRE_HIGH, enemyHero:GetLocation()
				end
			end
		end
	end
	if Fu.IsFarming(bot) then
		if Fu.IsValid(botTarget) and botTarget:GetTeam() == TEAM_NEUTRAL and Fu.IsInRange(bot, botTarget, 1000) then
			local aoeLocation = bot:FindAoELocation(true, false, bot:GetLocation(), castRange, waveWidth, 0, 0)
			if aoeLocation.count >= 2 then
				return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
			end
		end
	end
	if (Fu.IsPushing(bot) or Fu.IsDefending(bot)) and not Fu.IsThereNonSelfCoreNearby(1000) then
		local aoeLocation = bot:FindAoELocation(true, false, bot:GetLocation(), castRange, waveWidth, 0, 0)
		local laneCreeps = bot:GetNearbyLaneCreeps(castRange, true)
		if laneCreeps ~= nil and #laneCreeps >= 3 and aoeLocation.count >= 3 then
			return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(laneCreeps)
		end
		aoeLocation = bot:FindAoELocation(true, true, bot:GetLocation(), castRange, waveWidth, 0, 0)
		if aoeLocation.count >= 1 then
			return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
		end
	end
	if Fu.IsLaning(bot) then
		local killableCount = 0
		local killableCreeps = {}
		local laneCreeps = bot:GetNearbyLaneCreeps(castRange, true)
		local enemyHeroes = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
		for _, creep in pairs(laneCreeps) do
			if Fu.IsValid(creep) and creep:GetHealth() <= damage then
				killableCount = killableCount + 1
				table.insert(killableCreeps, creep)
			end
		end
		if
			killableCount >= 2
			and Fu.GetMP(bot) > 0.3
			and enemyHeroes ~= nil
			and #enemyHeroes >= 1
			and Fu.CanBeAttacked(killableCreeps[1])
			and not Fu.IsThereNonSelfCoreNearby(1200)
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
function X.ConsiderNetherSwap()
	if not netherSwapAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castRange = Fu.GetProperCastRange(false, bot, netherSwapAbility:GetCastRange())
	local alliesInRange = Fu.GetNearbyHeroes(bot, castRange, false, BOT_MODE_NONE)
	for _, allyHero in pairs(alliesInRange) do
		if Fu.IsValidHero(allyHero) and not Fu.IsSuspiciousIllusion(allyHero) then
			-- Duel: our own Legion Commander carries the duel modifier too when he is the one dueling; what
			-- Swap does to a running Duel is not verified, so do not swap him out of his own duel.
			if
				allyHero:HasModifier("modifier_faceless_void_chronosphere_freeze")
				or allyHero:HasModifier("modifier_enigma_black_hole_pull")
				or allyHero:HasModifier("modifier_legion_commander_duel") and allyHero:GetUnitName() ~= "npc_dota_hero_legion_commander"
				or allyHero:HasModifier("modifier_mars_arena_of_blood_leash")
					and not bot:HasModifier("modifier_mars_arena_of_blood_leash")
			then
				return BOT_ACTION_DESIRE_HIGH, allyHero
			end
		end
	end
	-- Low-HP ally save (Swap's main support use was missing): an ally under 30% HP, hit by a hero in
	-- the last 1.5s, with an enemy hero within 700 of him, while Venge is above 50% HP, 500+ away
	-- from him (a shorter swap barely moves him) and has fewer enemy heroes around her than he does.
	-- Swap on allies: the npc data only says TEAM_CUSTOM; this relies on the ally swaps above, which
	-- already target allies.
	if Fu.GetHP(bot) > 0.5 then
		local nearMe = #(Fu.GetNearbyHeroes(bot, 700, true, BOT_MODE_NONE) or {})
		for _, allyHero in pairs(alliesInRange) do
			if
				Fu.IsValidHero(allyHero)
				and allyHero ~= bot
				and not allyHero:IsIllusion()
				and not Fu.IsSuspiciousIllusion(allyHero)
				and Fu.GetHP(allyHero) < 0.3
				and not Fu.IsInRange(bot, allyHero, 500)
				and allyHero:WasRecentlyDamagedByAnyHero(1.5)
				and not allyHero:HasModifier("modifier_necrolyte_reapers_scythe")
			then
				local nearAlly = #(Fu.GetNearbyHeroes(allyHero, 700, true, BOT_MODE_NONE) or {})
				if nearAlly >= 1 and nearMe < nearAlly then
					if DotaTime() >= (bot._swapSaveLogAt or -999) then
						bot._swapSaveLogAt = DotaTime() + 10
						pcall(
							print,
							string.format(
								"[OHA-VENGEFULSPIRIT] t=%.0f swap-save ally=%s hp=%.2f enemiesNearAlly=%d nearMe=%d",
								DotaTime(),
								(string.gsub(allyHero:GetUnitName(), "npc_dota_hero_", "")),
								Fu.GetHP(allyHero),
								nearAlly,
								nearMe
							)
						)
					end
					return BOT_ACTION_DESIRE_HIGH, allyHero
				end
			end
		end
	end
	-- Engage swap: Swap pierces spell immunity (npc data: SPELL_IMMUNITY_ENEMIES_YES), so a BKB'd core
	-- can still be pulled in; Linken's is avoided as for other targeted spells (not verified for Swap).
	-- Venge lands where the enemy stood, so not below 40% HP.
	if isGoingOnSomeone and Fu.GetHP(bot) > 0.4 then
		local bestTarget = nil
		local highestDamage = 0
		local enemyHeroes = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
		for _, enemyHero in pairs(enemyHeroes) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.CanCastOnMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
				and not Fu.IsInRange(bot, enemyHero, castRange / 2)
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and not Fu.IsDisabled(enemyHero)
				and not enemyHero:HasModifier("modifier_enigma_black_hole_pull")
				and not enemyHero:HasModifier("modifier_faceless_void_chronosphere_freeze")
				and not enemyHero:HasModifier("modifier_legion_commander_duel")
				and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
				and not enemyHero:WasRecentlyDamagedByAnyHero(2)
			then
				local alliesNearTarget = Fu.GetNearbyHeroes(enemyHero, 1200, true, BOT_MODE_NONE)
				local enemiesNearTarget = Fu.GetNearbyHeroes(enemyHero, 1200, false, BOT_MODE_NONE)
				local estimatedDamage = enemyHero:GetEstimatedDamageToTarget(true, bot, 5, DAMAGE_TYPE_ALL)
				if
					alliesNearTarget ~= nil
					and enemiesNearTarget ~= nil
					and #alliesNearTarget >= #enemiesNearTarget
					and #alliesNearTarget >= 1
					and #alliesNearTarget <= #enemiesNearTarget + 2
					and highestDamage < estimatedDamage
				then
					highestDamage = estimatedDamage
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
return X
