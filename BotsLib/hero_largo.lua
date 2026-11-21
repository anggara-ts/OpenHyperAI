-- Largo: skill build, item build, and ability use for this hero.
local X = {}
local bot = GetBot()
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local AbilityContext = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local Minion = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local sTalentList = Fu.Skill.GetTalentList(bot)
local sAbilityList = Fu.Skill.GetAbilityList(bot)
local sRole = Fu.Item.GetRoleItemsBuyList(bot)
local tTalentTreeList = {
	{ ["t25"] = { 0, 10 }, ["t20"] = { 10, 0 }, ["t15"] = { 10, 0 }, ["t10"] = { 10, 0 } },
	{ ["t25"] = { 0, 10 }, ["t20"] = { 10, 0 }, ["t15"] = { 10, 0 }, ["t10"] = { 10, 0 } },
}
-- Catchy Lick maxed first, Frogstomp second, Croak of Genius last (Dotabuff most picked order).
local tAllAbilityBuildList =
	{ { 1, 2, 1, 2, 1, 6, 1, 2, 2, 3, 6, 3, 3, 3, 6 }, { 1, 2, 1, 2, 1, 6, 1, 2, 2, 3, 6, 3, 3, 3, 6 } }
local nAbilityBuildList
local nTalentBuildList
if sRole == "pos_5" then
	nAbilityBuildList = tAllAbilityBuildList[1]
	nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList[1])
else
	nAbilityBuildList = tAllAbilityBuildList[2]
	nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList[2])
end
local sRoleItemsBuyList = {}
-- Stratz 7.41f, week of 9 Nov 2026: pos 4, 7,677 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_4"] = {
	"item_tango",
	"item_blood_grenade",
	"item_double_branches",
	"item_magic_stick",
	"item_enchanted_mango",
	"item_magic_wand",
	"item_ring_of_basilius",
	"item_arcane_boots",
	"item_holy_locket",
	"item_glimmer_cape",
	"item_mekansm",
	"item_lotus_orb",
	"item_guardian_greaves",
	"item_solar_crest",
	"item_kaya_and_sange",
	"item_aghanims_shard",
	"item_moon_shard",
	"item_ultimate_scepter_2",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 5, 7,674 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_5"] = {
	"item_tango",
	"item_blood_grenade",
	"item_magic_stick",
	"item_double_branches",
	"item_enchanted_mango",
	"item_magic_wand",
	"item_ring_of_basilius",
	"item_arcane_boots",
	"item_holy_locket",
	"item_glimmer_cape",
	"item_mekansm",
	"item_lotus_orb",
	"item_guardian_greaves",
	"item_solar_crest",
	"item_kaya_and_sange",
	"item_aghanims_shard",
	"item_moon_shard",
	"item_ultimate_scepter_2",
}
-- No Boots of Travel: this build's Guardian Greaves / Boots of Bearing are its one pair of boots.
-- Stratz 7.41f, week of 9 Nov 2026: pos 3, 11,750 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_3"] = {
	"item_tango",
	"item_double_gauntlets",
	"item_double_branches",
	"item_bracer",
	"item_magic_wand",
	"item_soul_ring",
	"item_phase_boots",
	"item_kaya_and_sange",
	"item_ultimate_scepter",
	"item_black_king_bar",
	"item_shivas_guard",
	"item_travel_boots",
	"item_ultimate_scepter_2",
	"item_crellas_crozier",
	"item_sphere",
	"item_aghanims_shard",
	"item_moon_shard",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 2, 1,608 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_2"] = {
	"item_tango",
	"item_double_branches",
	"item_faerie_fire",
	"item_gauntlets",
	"item_quelling_blade",
	"item_magic_wand",
	"item_soul_ring",
	"item_phase_boots",
	"item_kaya_and_sange",
	"item_ultimate_scepter",
	"item_black_king_bar",
	"item_aghanims_shard",
	"item_shivas_guard",
	"item_ultimate_scepter_2",
	"item_phylactery",
	"item_bloodstone",
	"item_moon_shard",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 1 has 178 matches, built from pos 3 (11,750) (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_1"] = {
	"item_tango",
	"item_double_gauntlets",
	"item_double_branches",
	"item_bracer",
	"item_magic_wand",
	"item_soul_ring",
	"item_phase_boots",
	"item_kaya_and_sange",
	"item_ultimate_scepter",
	"item_black_king_bar",
	"item_shivas_guard",
	"item_travel_boots",
	"item_ultimate_scepter_2",
	"item_crellas_crozier",
	"item_sphere",
	"item_aghanims_shard",
	"item_moon_shard",
	"item_travel_boots_2",
}
X["sBuyList"] = sRoleItemsBuyList[sRole]
X["sSellList"] = { "item_black_king_bar", "item_quelling_blade" }
if Fu.Role.IsPvNMode() or Fu.Role.IsAllShadow() then
	X["sBuyList"], X["sSellList"] = { "PvN_tank" }, { "item_power_treads", "item_quelling_blade" }
end
nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"] =
	Fu.SetUserHeroInit(nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"])
X["sSkillList"] = Fu.Skill.GetSkillList(sAbilityList, nAbilityBuildList, sTalentList, nTalentBuildList)
X["bDeafaultAbility"] = false
X["bDeafaultItem"] = false
function X.MinionThink(hMinionUnit)
	Minion.MinionThink(hMinionUnit)
end
local catchyLickAbility = SafeAbility(bot:GetAbilityByName("largo_catchy_lick"), "largo_catchy_lick", "largo")
local frogstompAbility = SafeAbility(bot:GetAbilityByName("largo_frogstomp"), "largo_frogstomp", "largo")
local croakOfGeniusAbility =
	SafeAbility(bot:GetAbilityByName("largo_croak_of_genius"), "largo_croak_of_genius", "largo")
local amphibianRhapsodyAbility =
	SafeAbility(bot:GetAbilityByName("largo_amphibian_rhapsody"), "largo_amphibian_rhapsody", "largo")
local fightSongAbility = SafeAbility(bot:GetAbilityByName("largo_song_fight_song"), "largo_song_fight_song", "largo")
local doubleTimeAbility = SafeAbility(bot:GetAbilityByName("largo_song_double_time"), "largo_song_double_time", "largo")
local goodVibrationsAbility =
	SafeAbility(bot:GetAbilityByName("largo_song_good_vibrations"), "largo_song_good_vibrations", "largo")
local catchyLickDesire, catchyLickTarget
local frogstompDesire, frogstompLocation
local croakOfGeniusDesire, croakOfGeniusTarget
local amphibianRhapsodyDesire
local songState = { strumTime = 0, song1 = fightSongAbility, song2 = fightSongAbility, wasInWindow = false }
local isAttacking = false
local botTarget, hpRatio
local nearbyAllies, nearbyEnemies
local isGoingOnSomeone
function X.SkillsComplement()
	if not bot:HasModifier("modifier_largo_amphibian_rhapsody_self") then
		songState.strumTime = 0
		songState.wasInWindow = false
	else
		if amphibianRhapsodyAbility and amphibianRhapsodyAbility:IsTrained() and songState.strumTime > 0 then
			local rhythmInterval = amphibianRhapsodyAbility:GetSpecialValueInt("rhythm_interval")
			if DotaTime() >= songState.strumTime + rhythmInterval then
				songState.strumTime = songState.strumTime + rhythmInterval
			end
		end
	end
	if Fu.CanNotUseAbility(bot) then
		return
	end
	isGoingOnSomeone = Fu.IsGoingOnSomeone(bot)
	isAttacking = Fu.IsAttacking(bot)
	hpRatio = Fu.GetHP(bot)
	botTarget = Fu.GetProperTarget(bot)
	nearbyAllies = bot:GetNearbyHeroes(1600, false, BOT_MODE_NONE)
	nearbyEnemies = bot:GetNearbyHeroes(1600, true, BOT_MODE_NONE)
	croakOfGeniusDesire, croakOfGeniusTarget = X.ConsiderCroakOfGenius()
	if croakOfGeniusDesire > 0 then
		Fu.SetQueuePtToINT(bot, false)
		bot:ActionQueue_UseAbilityOnEntity(croakOfGeniusAbility, croakOfGeniusTarget)
		return
	end
	catchyLickDesire, catchyLickTarget = X.ConsiderCatchLick()
	if catchyLickDesire > 0 then
		Fu.SetQueuePtToINT(bot, false)
		bot:ActionQueue_UseAbilityOnEntity(catchyLickAbility, catchyLickTarget)
		return
	end
	frogstompDesire, frogstompLocation = X.ConsiderFrogstomp()
	if frogstompDesire > 0 then
		Fu.SetQueuePtToINT(bot, false)
		bot:ActionQueue_UseAbilityOnLocation(frogstompAbility, frogstompLocation)
		return
	end
	amphibianRhapsodyDesire = X.ConsiderAmphibianRhapsody()
	if amphibianRhapsodyDesire > 0 then
		bot:Action_UseAbility(amphibianRhapsodyAbility)
		return
	end
end
function X.ConsiderCatchLick()
	if not Fu.CanCastAbility(catchyLickAbility) then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castRange = catchyLickAbility:GetCastRange()
	local pullDistance = catchyLickAbility:GetSpecialValueInt("pull_distance")
	local pullDistanceAlly = catchyLickAbility:GetSpecialValueInt("pull_distance_ally")
	local damage = catchyLickAbility:GetSpecialValueInt("damage")
	local manaCost = catchyLickAbility:GetManaCost()
	local manaAfter = Fu.GetManaAfter(manaCost)
	local manaThreshold = Fu.GetManaThreshold(bot, manaCost, { frogstompAbility, croakOfGeniusAbility })
	for _, allyHero in pairs(nearbyAllies) do
		if
			Fu.IsValidHero(allyHero)
			and bot ~= allyHero
			and Fu.IsInRange(bot, allyHero, pullDistanceAlly + 300)
			and not Fu.IsInRange(bot, allyHero, pullDistanceAlly * 0.8)
			and not Fu.IsDisabled(allyHero)
			and not Fu.IsSuspiciousIllusion(allyHero)
			and not Fu.IsRealInvisible(allyHero)
			and not allyHero:IsChanneling()
		then
			if Fu.IsGoingOnSomeone(allyHero) then
				local allyTarget = Fu.GetProperTarget(allyHero)
				if
					Fu.IsValidHero(allyTarget)
					and allyHero:IsFacingLocation(allyTarget:GetLocation(), 15)
					and GetUnitToUnitDistance(allyHero, allyTarget) > allyHero:GetAttackRange() + 50
					and GetUnitToUnitDistance(allyHero, allyTarget) < allyHero:GetAttackRange() + 700
					and not Fu.IsSuspiciousIllusion(allyTarget)
					and not allyTarget:IsFacingLocation(allyHero:GetLocation(), 40)
					and #nearbyAllies >= 3
				then
					local lineInfo =
						PointToLineDistance(allyTarget:GetLocation(), allyHero:GetLocation(), bot:GetLocation())
					if lineInfo and lineInfo.within and lineInfo.distance <= 600 then
						return BOT_ACTION_DESIRE_HIGH, allyHero
					end
					lineInfo = PointToLineDistance(bot:GetLocation(), allyHero:GetLocation(), allyTarget:GetLocation())
					if lineInfo and lineInfo.within and lineInfo.distance <= 600 then
						return BOT_ACTION_DESIRE_HIGH, allyHero
					end
				end
			end
			local enemiesNearAlly = Fu.GetEnemiesNearLoc(allyHero:GetLocation(), 900)
			if
				Fu.IsRetreating(allyHero)
				and #enemiesNearAlly > 0
				and allyHero:IsFacingLocation(Fu.GetTeamFountain(), 30)
				and allyHero:DistanceFromFountain() > 1200
				and allyHero:WasRecentlyDamagedByAnyHero(5.0)
			then
				local lineInfo = PointToLineDistance(Fu.GetTeamFountain(), allyHero:GetLocation(), bot:GetLocation())
				if lineInfo and lineInfo.within and lineInfo.distance <= 600 then
					return BOT_ACTION_DESIRE_HIGH, allyHero
				end
			end
			if Fu.IsStuck(allyHero) then
				return BOT_ACTION_DESIRE_HIGH, allyHero
			end
		end
		if
			Fu.IsValidHero(allyHero)
			and Fu.IsInRange(bot, allyHero, castRange)
			and not allyHero:IsMagicImmune()
			and not allyHero:IsIllusion()
			and not allyHero:IsChanneling()
			and not allyHero:HasModifier("modifier_necrolyte_reapers_scythe")
			and allyHero:WasRecentlyDamagedByAnyHero(2.0)
		then
			local allyIsGoingOnSomeone = Fu.IsGoingOnSomeone(allyHero)
			local allyIsRetreating = Fu.IsRetreating(allyHero)
			if
				Fu.GetModifierTime(allyHero, "modifier_bane_nightmare") > 2
				or Fu.GetModifierTime(allyHero, "modifier_axe_battle_hunger") > 2 and allyIsRetreating
				or Fu.GetModifierTime(allyHero, "modifier_bristleback_viscous_nasal_goo") > 2 and Fu.IsRunning(allyHero)
				or Fu.GetModifierTime(allyHero, "modifier_earth_spirit_magnetize") > 2 and not allyIsGoingOnSomeone
				or Fu.GetModifierTime(allyHero, "modifier_phoenix_fire_spirit_burn") > 2 and allyIsGoingOnSomeone
				or Fu.GetModifierTime(allyHero, "modifier_life_stealer_open_wounds") > 2 and allyIsRetreating
				or Fu.GetModifierTime(allyHero, "modifier_faceless_void_time_dilation_slow") > 2 and allyIsGoingOnSomeone
				or Fu.GetModifierTime(allyHero, "modifier_warlock_fatal_bonds") > 2
				or Fu.GetModifierTime(allyHero, "modifier_arc_warden_flux") > 2 and allyIsRetreating
				or Fu.GetModifierTime(allyHero, "modifier_venomancer_venomous_gale") > 2 and allyIsRetreating
				-- Stun only when the lick is a strong dispel: it is a basic dispel (strong_dispel 0 in the
				-- game KV, no talent changes it) and a stun needs a strong dispel, so licking a stunned
				-- ally only moved it and wasted the cast.
				or catchyLickAbility:GetSpecialValueInt("strong_dispel") > 0
					and Fu.GetModifierTime(allyHero, "modifier_stunned") > 2
			then
				return BOT_ACTION_DESIRE_HIGH, allyHero
			end
		end
	end
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanBeAttacked(enemyHero)
			and Fu.IsInRange(bot, enemyHero, castRange)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and Fu.CanCastOnTargetAdvanced(enemyHero)
			and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			if
				Fu.CanKillTarget(enemyHero, damage, DAMAGE_TYPE_MAGICAL)
				and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
				and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
				and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
				and not enemyHero:HasModifier("modifier_templar_assassin_refraction_absorb")
			then
				return BOT_ACTION_DESIRE_HIGH, enemyHero
			end
			if hpRatio < 0.9 then
				if
					Fu.GetModifierTime(enemyHero, "modifier_earthshaker_enchant_totem") > 2
					or Fu.GetModifierTime(enemyHero, "modifier_legion_commander_overwhelming_odds") > 2
					or Fu.GetModifierTime(enemyHero, "modifier_legion_commander_press_the_attack") > 2
					or Fu.GetModifierTime(enemyHero, "modifier_ogre_magi_bloodlust") > 2
					or Fu.GetModifierTime(enemyHero, "modifier_shredder_reactive_armor_bomb") > 2
					or Fu.GetModifierTime(enemyHero, "modifier_ursa_overpower") > 2
					or Fu.GetModifierTime(enemyHero, "modifier_necrolyte_sadist_active") > 2
					or Fu.GetModifierTime(enemyHero, "modifier_pugna_decrepify") > 2
					or Fu.GetModifierTime(enemyHero, "modifier_warlock_shadow_word") > 2
					or Fu.GetModifierTime(enemyHero, "modifier_abaddon_aphotic_shield") > 2
				then
					return BOT_ACTION_DESIRE_HIGH, enemyHero
				end
			end
		end
	end
	if isGoingOnSomeone then
		if
			Fu.IsValidHero(botTarget)
			and Fu.CanBeAttacked(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.CanCastOnTargetAdvanced(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and not Fu.IsInRange(bot, botTarget, pullDistance)
			and Fu.IsChasingTarget(bot, botTarget)
			and not Fu.IsDisabled(botTarget)
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end
	local nearbyCreeps = bot:GetNearbyCreeps(Min(castRange + 300, 1600), true)
	if Fu.IsPushing(bot) or Fu.IsDefending(bot) or Fu.IsFarming(bot) then
		if #nearbyAllies <= 2 and #nearbyEnemies == 0 and isAttacking and manaAfter > manaThreshold + 0.1 then
			local bestCreep = nil
			local bestDamageRatio = 0
			for _, creep in pairs(nearbyCreeps) do
				if
					Fu.IsValid(creep)
					and Fu.CanBeAttacked(creep)
					and not Fu.IsRoshan(creep)
					and not Fu.IsTormentor(creep)
					and not Fu.IsOtherAllysTarget(creep)
					and creep:GetHealth() > 0
				then
					local damageRatio = creep:GetActualIncomingDamage(damage, DAMAGE_TYPE_MAGICAL) / creep:GetHealth()
					if damageRatio > bestDamageRatio then
						bestCreep = creep
						bestDamageRatio = damageRatio
					end
				end
			end
			if bestCreep then
				return BOT_ACTION_DESIRE_HIGH, bestCreep
			end
		end
	end
	if Fu.IsLaning(bot) and Fu.IsInLaningPhase() and manaAfter > manaThreshold then
		for _, creep in pairs(nearbyCreeps) do
			if
				Fu.IsValid(creep)
				and Fu.CanBeAttacked(creep)
				and Fu.CanKillTarget(creep, damage, DAMAGE_TYPE_MAGICAL)
				and (Fu.IsCore(bot) or not Fu.IsThereCoreInLocation(creep:GetLocation(), 650))
				and not Fu.IsOtherAllysTarget(creep)
			then
				local creepName = creep:GetUnitName()
				if string.find(creepName, "ranged") then
					local aoeLocation = bot:FindAoELocation(true, true, creep:GetLocation(), 0, 600, 0, 0)
					if aoeLocation.count > 0 or Fu.IsUnitTargetedByTower(creep, false) then
						return BOT_ACTION_DESIRE_HIGH, creep
					end
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function X.ConsiderFrogstomp()
	if not Fu.CanCastAbility(frogstompAbility) then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local castRange = frogstompAbility:GetCastRange()
	local radius = frogstompAbility:GetSpecialValueInt("radius")
	local manaCost = frogstompAbility:GetManaCost()
	local manaAfter = Fu.GetManaAfter(manaCost)
	local manaThreshold = Fu.GetManaThreshold(bot, manaCost, { catchyLickAbility, croakOfGeniusAbility })
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanBeAttacked(enemyHero)
			and Fu.IsInRange(bot, enemyHero, castRange)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
			and enemyHero:IsChanneling()
		then
			return BOT_ACTION_DESIRE_HIGH, enemyHero:GetLocation()
		end
	end
	if isGoingOnSomeone then
		if
			Fu.IsValidHero(botTarget)
			and Fu.CanBeAttacked(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			if Fu.IsDisabled(botTarget) or botTarget:GetCurrentMovementSpeed() <= 250 then
				return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
			end
		end
	end
	if Fu.IsRetreating(bot) and not Fu.IsRealInvisible(bot) and Fu.IsRunning(bot) then
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.CanBeAttacked(enemyHero)
				and Fu.IsInRange(bot, enemyHero, radius * 2)
				and not Fu.IsInRange(bot, enemyHero, radius * 0.8)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and not Fu.IsDisabled(enemyHero)
				and bot:WasRecentlyDamagedByHero(enemyHero, 3.0)
			then
				return BOT_ACTION_DESIRE_HIGH, (bot:GetLocation() + enemyHero:GetLocation()) / 2
			end
		end
	end
	local nearbyCreeps = bot:GetNearbyCreeps(Min(castRange + 300, 1600), true)
	if
		Fu.IsPushing(bot)
		and #nearbyAllies <= 2
		and isAttacking
		and manaAfter > manaThreshold
		and #nearbyEnemies == 0
	then
		for _, creep in pairs(nearbyCreeps) do
			if Fu.IsValid(creep) and Fu.CanBeAttacked(creep) and not Fu.IsRunning(creep) then
				local aoeLocation = bot:FindAoELocation(true, false, creep:GetLocation(), 0, radius, 0, 0)
				if aoeLocation.count >= 4 then
					return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
				end
			end
		end
	end
	if Fu.IsDefending(bot) and isAttacking and manaAfter > manaThreshold then
		for _, creep in pairs(nearbyCreeps) do
			if Fu.IsValid(creep) and Fu.CanBeAttacked(creep) and not Fu.IsRunning(creep) then
				local aoeLocation = bot:FindAoELocation(true, false, creep:GetLocation(), 0, radius, 0, 0)
				if
					aoeLocation.count >= 4
					or aoeLocation.count >= 3 and string.find(creep:GetUnitName(), "upgraded")
				then
					return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
				end
			end
		end
	end
	if Fu.IsFarming(bot) and isAttacking and manaAfter > manaThreshold then
		for _, creep in pairs(nearbyCreeps) do
			if Fu.IsValid(creep) and Fu.CanBeAttacked(creep) and not Fu.IsRunning(creep) then
				local aoeLocation = bot:FindAoELocation(true, false, creep:GetLocation(), 0, radius, 0, 0)
				if
					aoeLocation.count >= 3
					or aoeLocation.count >= 2 and creep:IsAncientCreep()
					or aoeLocation.count >= 1 and creep:GetHealth() >= 550
				then
					return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
				end
			end
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if
			Fu.IsRoshan(botTarget)
			and Fu.CanBeAttacked(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and isAttacking
			and manaAfter > manaThreshold
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if
			Fu.IsTormentor(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and isAttacking
			and manaAfter > manaThreshold
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.ConsiderCroakOfGenius()
	if not Fu.CanCastAbility(croakOfGeniusAbility) then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castRange = croakOfGeniusAbility:GetCastRange()
	local bestAlly = nil
	local bestDamage = 0
	for _, allyHero in pairs(nearbyAllies) do
		if
			Fu.IsValidHero(allyHero)
			and Fu.IsInRange(bot, allyHero, castRange + 300)
			and Fu.IsGoingOnSomeone(allyHero)
			and not allyHero:IsIllusion()
			and not allyHero:IsSilenced()
			and not allyHero:HasModifier("modifier_doom_bringer_doom_aura_enemy")
			and not allyHero:HasModifier("modifier_necrolyte_reapers_scythe")
			and not allyHero:HasModifier("modifier_largo_croak_of_genius_buff")
			and not allyHero:HasModifier("modifier_silencer_curse_of_the_silent")
			and not allyHero:HasModifier("modifier_teleporting")
		then
			local allyTarget = Fu.GetProperTarget(allyHero)
			if
				Fu.IsValidHero(allyTarget)
				and Fu.CanBeAttacked(allyTarget)
				and not Fu.IsSuspiciousIllusion(allyTarget)
			then
				local estimatedDamage = allyHero:GetEstimatedDamageToTarget(true, allyTarget, 5.0, DAMAGE_TYPE_MAGICAL)
				if estimatedDamage > bestDamage then
					bestAlly = allyHero
					bestDamage = estimatedDamage
				end
			end
		end
	end
	if bestAlly then
		return BOT_ACTION_DESIRE_HIGH, bestAlly
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
local songList = { fightSongAbility, doubleTimeAbility, goodVibrationsAbility }
function X.ConsiderAmphibianRhapsody()
	if not Fu.CanCastAbility(amphibianRhapsodyAbility) then
		return BOT_ACTION_DESIRE_NONE
	end
	local radius = amphibianRhapsodyAbility:GetSpecialValueInt("radius")
	local hasDoubleSong = amphibianRhapsodyAbility:GetSpecialValueInt("double_song") > 0
	local manaThreshold = Fu.GetManaThreshold(bot, 150, { catchyLickAbility, frogstompAbility, croakOfGeniusAbility })
	local mpRatio = Fu.GetMP(bot)
	local isToggledOn = amphibianRhapsodyAbility:GetToggleState()
	repeat
		songState.song1 = songList[RandomInt(1, 3)]
		songState.song2 = songList[RandomInt(1, 3)]
	until songState.song1 ~= songState.song2
	if hasDoubleSong and mpRatio > manaThreshold then
		if isGoingOnSomeone or Fu.IsInTeamFight(bot, 1200) then
			for _, enemyHero in pairs(nearbyEnemies) do
				if
					Fu.IsValidHero(enemyHero)
					and Fu.CanBeAttacked(enemyHero)
					and Fu.IsInRange(bot, enemyHero, radius)
					and Fu.CanCastOnNonMagicImmune(enemyHero)
					and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
					and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
					and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
				then
					if not isToggledOn then
						return BOT_ACTION_DESIRE_HIGH
					else
						X.Strum(songState.song1, songState.song2)
						return BOT_ACTION_DESIRE_NONE
					end
				end
			end
		end
	end
	for _, allyHero in pairs(nearbyAllies) do
		if
			Fu.IsValidHero(allyHero)
			and Fu.IsInRange(bot, allyHero, radius)
			and not allyHero:IsIllusion()
			and not allyHero:HasModifier("modifier_necrolyte_reapers_scythe")
			and not allyHero:HasModifier("modifier_teleporting")
		then
			local allyHpRatio = Fu.GetHP(allyHero)
			local allyTarget = Fu.GetProperTarget(allyHero)
			if Fu.IsGoingOnSomeone(allyHero) and bot ~= allyHero then
				if
					Fu.IsValidHero(allyTarget)
					and Fu.CanBeAttacked(allyTarget)
					and Fu.IsInRange(allyHero, allyTarget, Max(allyHero:GetAttackRange(), 800))
					and not Fu.IsSuspiciousIllusion(allyTarget)
				then
					if not Fu.CanCastAbility(frogstompAbility) then
						if mpRatio > manaThreshold + 0.1 then
							if not isToggledOn then
								return BOT_ACTION_DESIRE_HIGH
							else
								if
									Fu.IsChasingTarget(allyHero, allyTarget)
									or Fu.IsInTeamFight(bot, 1200) and allyHero:WasRecentlyDamagedByAnyHero(2.0)
									or allyHero:GetCurrentMovementSpeed() <= 250
								then
									X.Strum(doubleTimeAbility, nil)
								elseif allyHpRatio < 0.55 and X.IsGoodToHeal(allyHero) then
									X.Strum(goodVibrationsAbility, nil)
								else
									X.Strum(fightSongAbility, nil)
								end
								return BOT_ACTION_DESIRE_NONE
							end
						end
					end
				end
			end
			if not Fu.IsRealInvisible(bot) then
				if Fu.IsRetreating(allyHero) and allyHpRatio < 0.65 and not Fu.CanCastAbility(frogstompAbility) then
					if mpRatio > manaThreshold + 0.1 then
						if not isToggledOn then
							return BOT_ACTION_DESIRE_HIGH
						else
							if allyHero:GetCurrentMovementSpeed() <= 250 and not allyHero:IsRooted() then
								X.Strum(doubleTimeAbility, nil)
							else
								if X.IsGoodToHeal(allyHero) then
									X.Strum(goodVibrationsAbility, nil)
								end
							end
							return BOT_ACTION_DESIRE_NONE
						end
					end
				end
				if allyHpRatio < 0.5 and X.IsGoodToHeal(allyHero) then
					if mpRatio > manaThreshold + 0.1 then
						if not isToggledOn then
							return BOT_ACTION_DESIRE_HIGH
						else
							X.Strum(goodVibrationsAbility, nil)
						end
						return BOT_ACTION_DESIRE_NONE
					end
				end
			end
			if bot ~= allyHero and Fu.IsCore(allyHero) and mpRatio > manaThreshold + 0.1 then
				if Fu.IsDoingRoshan(allyHero) and Fu.IsDoingRoshan(bot) then
					if
						Fu.IsRoshan(allyTarget)
						and Fu.CanBeAttacked(allyTarget)
						and Fu.IsInRange(allyHero, allyTarget, 1200)
					then
						if not isToggledOn and Fu.IsAttacking(allyHero) then
							return BOT_ACTION_DESIRE_HIGH
						else
							X.Strum(fightSongAbility, nil)
						end
						return BOT_ACTION_DESIRE_NONE
					end
				end
				if Fu.IsDoingTormentor(allyHero) and Fu.IsDoingTormentor(bot) then
					if Fu.IsTormentor(allyTarget) and Fu.IsInRange(allyHero, allyTarget, 1200) then
						if not isToggledOn and Fu.IsAttacking(allyHero) then
							return BOT_ACTION_DESIRE_HIGH
						else
							if hasDoubleSong then
								X.Strum(fightSongAbility, goodVibrationsAbility)
							else
								X.Strum(fightSongAbility, nil)
							end
						end
						return BOT_ACTION_DESIRE_NONE
					end
				end
			end
		end
	end
	if isToggledOn and math.floor(DotaTime()) % 2 == 0 then
		return BOT_ACTION_DESIRE_HIGH
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.IsGoodToHeal(hero)
	return not hero:HasModifier("modifier_abaddon_borrowed_time")
		and not hero:HasModifier("modifier_doom_bringer_doom_aura_enemy")
		and not hero:HasModifier("modifier_ice_blast")
		and not hero:HasModifier("modifier_necrolyte_reapers_scythe")
		and hero:GetUnitName() ~= "npc_dota_hero_medusa"
		and hero:GetUnitName() ~= "npc_dota_hero_huskar"
end
function X.Strum(firstSong, secondSong)
	local gracePeriod = amphibianRhapsodyAbility:GetSpecialValueFloat("rhythm_grace_period")
	local now = DotaTime()
	local isInWindow = songState.strumTime == 0
		or now >= songState.strumTime - gracePeriod and now <= songState.strumTime + gracePeriod
	if isInWindow and not songState.wasInWindow then
		if firstSong and secondSong == nil then
			bot:Action_UseAbility(firstSong)
			if songState.strumTime == 0 then
				songState.strumTime = DotaTime()
			end
		elseif firstSong and secondSong and firstSong ~= secondSong then
			bot:ActionPush_UseAbility(firstSong)
			bot:ActionPush_UseAbility(secondSong)
			if songState.strumTime == 0 then
				songState.strumTime = DotaTime()
			end
		end
	end
	songState.wasInWindow = isInWindow
end
return X
