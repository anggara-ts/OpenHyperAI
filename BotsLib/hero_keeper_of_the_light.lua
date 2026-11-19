-- Keeper Of The Light: skill build, item build, and ability use for this hero.
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
	{ ["t25"] = { 0, 10 }, ["t20"] = { 0, 10 }, ["t15"] = { 0, 10 }, ["t10"] = { 10, 0 } },
}
local tAllAbilityBuildList =
	{ { 1, 3, 1, 3, 1, 6, 1, 3, 3, 2, 6, 2, 2, 2, 6 }, { 1, 3, 1, 3, 1, 6, 1, 3, 3, 2, 6, 2, 2, 2, 6 } }
local nAbilityBuildList = tAllAbilityBuildList[1]
if sRole == "pos_2" then
	nAbilityBuildList = tAllAbilityBuildList[1]
end
if sRole == "pos_4" then
	nAbilityBuildList = tAllAbilityBuildList[2]
end
if sRole == "pos_5" then
	nAbilityBuildList = tAllAbilityBuildList[2]
end
local nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList[1])
if sRole == "pos_2" then
	nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList[1])
end
if sRole == "pos_4" then
	nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList[2])
end
if sRole == "pos_5" then
	nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList[2])
end
local sRoleItemsBuyList = {}
sRoleItemsBuyList["pos_2"] = {
	"item_faerie_fire",
	"item_mantle",
	"item_circlet",
	"item_double_branches",
	"item_tango",
	"item_null_talisman",
	"item_boots",
	"item_magic_wand",
	"item_spirit_vessel",
	"item_dagon_2",
	"item_travel_boots",
	"item_ethereal_blade",
	"item_octarine_core",
	"item_dagon_5",
	"item_kaya_and_sange",
	"item_sheepstick",
	"item_ultimate_scepter",
	"item_ultimate_scepter_2",
	"item_moon_shard",
	"item_travel_boots_2",
	"item_aghanims_shard",
}
sRoleItemsBuyList["pos_3"] = sRoleItemsBuyList["pos_2"]
sRoleItemsBuyList["pos_1"] = sRoleItemsBuyList["pos_2"]
sRoleItemsBuyList["pos_4"] = {
	"item_double_tango",
	"item_faerie_fire",
	"item_clarity",
	"item_blood_grenade",
	"item_boots",
	"item_urn_of_shadows",
	"item_tranquil_boots",
	"item_glimmer_cape",
	"item_spirit_vessel",
	"item_kaya_and_sange",
	"item_boots_of_bearing",
	"item_octarine_core",
	"item_sheepstick",
	"item_aghanims_shard",
	"item_ultimate_scepter_2",
	"item_moon_shard",
}
sRoleItemsBuyList["pos_5"] = {
	"item_double_tango",
	"item_faerie_fire",
	"item_blood_grenade",
	"item_tranquil_boots",
	"item_solar_crest",
	"item_glimmer_cape",
	"item_mekansm",
	"item_cyclone",
	"item_boots_of_bearing",
	"item_lotus_orb",
	"item_sheepstick",
	"item_wind_waker",
	"item_ultimate_scepter_2",
	"item_aghanims_shard",
	"item_moon_shard",
}
X["sBuyList"] = sRoleItemsBuyList[sRole]
X["sSellList"] = { "item_ethereal_blade", "item_magic_wand" }
if Fu.Role.IsPvNMode() or Fu.Role.IsAllShadow() then
	X["sBuyList"], X["sSellList"] = { "PvN_mid" }, {}
end
nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"] =
	Fu.SetUserHeroInit(nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"])
X["sSkillList"] = Fu.Skill.GetSkillList(sAbilityList, nAbilityBuildList, sTalentList, nTalentBuildList)
X["bDeafaultAbility"] = false
X["bDeafaultItem"] = false
function X.MinionThink(minion)
	if Minion.IsValidUnit(minion) then
		Minion.IllusionThink(minion)
	end
end
local illuminateAbility = SafeAbility(
	bot:GetAbilityByName("keeper_of_the_light_illuminate"),
	"keeper_of_the_light_illuminate",
	"keeper_of_the_light"
)
local illuminateEndAbility = SafeAbility(
	bot:GetAbilityByName("keeper_of_the_light_illuminate_end"),
	"keeper_of_the_light_illuminate_end",
	"keeper_of_the_light"
)
local blindingLightAbility = SafeAbility(
	bot:GetAbilityByName("keeper_of_the_light_blinding_light"),
	"keeper_of_the_light_blinding_light",
	"keeper_of_the_light"
)
local chakraMagicAbility = SafeAbility(
	bot:GetAbilityByName("keeper_of_the_light_chakra_magic"),
	"keeper_of_the_light_chakra_magic",
	"keeper_of_the_light"
)
local solarBindAbility = SafeAbility(
	bot:GetAbilityByName("keeper_of_the_light_radiant_bind"),
	"keeper_of_the_light_radiant_bind",
	"keeper_of_the_light"
)
local willOWispAbility = SafeAbility(
	bot:GetAbilityByName("keeper_of_the_light_will_o_wisp"),
	"keeper_of_the_light_will_o_wisp",
	"keeper_of_the_light"
)
local spiritFormAbility = SafeAbility(
	bot:GetAbilityByName("keeper_of_the_light_spirit_form"),
	"keeper_of_the_light_spirit_form",
	"keeper_of_the_light"
)
local illuminateDesire, illuminateLocation
local illuminateEndDesire
local blindingLightDesire, blindingLightLocation
local chakraMagicDesire, chakraMagicTarget
local solarBindDesire, solarBindTarget
local willOWispDesire, willOWispLocation
local spiritFormDesire
local illuminateCastTime = -100
local nearbyAllies, nearbyEnemies
local botTarget
local isGoingOnSomeone
local isAttacking
-- [OHA-KOTL] one line per new behaviour, at most once per 3s per kind.
function X.LogKotl(what)
	bot._kotlLogAt = bot._kotlLogAt or {}
	if DotaTime() < (bot._kotlLogAt[what] or -999) then
		return
	end
	bot._kotlLogAt[what] = DotaTime() + 3
	pcall(print, string.format("[OHA-KOTL] t=%.0f %s", DotaTime(), what))
end
function X.SkillsComplement()
	-- Illuminate is channelled, and CanNotUseAbility() is true for the whole channel (IsChanneling), so
	-- the early release (Illuminate End) further down was never reached outside Spirit Form. Check it
	-- here, before that early return, while Keeper is channelling.
	if bot:IsChanneling() and bot.illuminate_status ~= nil and Fu.CanCastAbility(illuminateEndAbility) then
		if X.ConsiderIlluminateEnd() > 0 then
			X.LogKotl("illuminate-end why=" .. tostring(bot.illuminate_status[1]))
			bot:Action_UseAbility(illuminateEndAbility)
			return
		end
	end
	if Fu.CanNotUseAbility(bot) then
		return
	end
	isGoingOnSomeone = Fu.IsGoingOnSomeone(bot)
	isAttacking = Fu.IsAttacking(bot)
	illuminateAbility = SafeAbility(
		bot:GetAbilityByName("keeper_of_the_light_illuminate"),
		"keeper_of_the_light_illuminate",
		"keeper_of_the_light"
	)
	illuminateEndAbility = SafeAbility(
		bot:GetAbilityByName("keeper_of_the_light_illuminate_end"),
		"keeper_of_the_light_illuminate_end",
		"keeper_of_the_light"
	)
	blindingLightAbility = SafeAbility(
		bot:GetAbilityByName("keeper_of_the_light_blinding_light"),
		"keeper_of_the_light_blinding_light",
		"keeper_of_the_light"
	)
	chakraMagicAbility = SafeAbility(
		bot:GetAbilityByName("keeper_of_the_light_chakra_magic"),
		"keeper_of_the_light_chakra_magic",
		"keeper_of_the_light"
	)
	solarBindAbility = SafeAbility(
		bot:GetAbilityByName("keeper_of_the_light_radiant_bind"),
		"keeper_of_the_light_radiant_bind",
		"keeper_of_the_light"
	)
	willOWispAbility = SafeAbility(
		bot:GetAbilityByName("keeper_of_the_light_will_o_wisp"),
		"keeper_of_the_light_will_o_wisp",
		"keeper_of_the_light"
	)
	spiritFormAbility = SafeAbility(
		bot:GetAbilityByName("keeper_of_the_light_spirit_form"),
		"keeper_of_the_light_spirit_form",
		"keeper_of_the_light"
	)
	nearbyAllies = bot:GetNearbyHeroes(1600, false, BOT_MODE_NONE)
	nearbyEnemies = bot:GetNearbyHeroes(1600, true, BOT_MODE_NONE)
	botTarget = Fu.GetProperTarget(bot)
	spiritFormDesire = X.ConsiderSpiritForm()
	if spiritFormDesire > 0 then
		bot:Action_UseAbility(spiritFormAbility)
		return
	end
	solarBindDesire, solarBindTarget = X.ConsiderSolarBind()
	if solarBindDesire > 0 then
		bot:Action_UseAbilityOnEntity(solarBindAbility, solarBindTarget)
		return
	end
	willOWispDesire, willOWispLocation = X.ConsiderWillOWisp()
	if willOWispDesire > 0 then
		bot:Action_UseAbilityOnLocation(willOWispAbility, willOWispLocation)
		return
	end
	blindingLightDesire, blindingLightLocation = X.ConsiderBlindingLight()
	if blindingLightDesire > 0 then
		bot:Action_UseAbilityOnLocation(blindingLightAbility, blindingLightLocation)
		return
	end
	illuminateEndDesire = X.ConsiderIlluminateEnd()
	if illuminateEndDesire > 0 then
		bot:Action_UseAbility(illuminateEndAbility)
		return
	end
	illuminateDesire, illuminateLocation = X.ConsiderIlluminate()
	if illuminateDesire > 0 then
		bot:Action_UseAbilityOnLocation(illuminateAbility, illuminateLocation)
		illuminateCastTime = DotaTime()
		return
	end
	chakraMagicDesire, chakraMagicTarget = X.ConsiderChakraMagic()
	if chakraMagicDesire > 0 then
		bot:Action_UseAbilityOnEntity(chakraMagicAbility, chakraMagicTarget)
		return
	end
end
function X.ConsiderIlluminate()
	if not Fu.CanCastAbility(illuminateAbility) then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local castRange = Fu.GetProperCastRange(false, bot, illuminateAbility:GetCastRange())
	local illuminateRange = illuminateAbility:GetSpecialValueInt("range")
	local radius = illuminateAbility:GetSpecialValueInt("radius")
	local damage = illuminateAbility:GetSpecialValueInt("total_damage")
	local manaAfterCast = Fu.GetManaAfter(illuminateAbility:GetManaCost())
	-- Illuminate is ready, so any earlier wave is over: drop its status, or a stale "kill"/"laning"
	-- target could release this new cast early (only the kill and laning branches set a new status).
	bot.illuminate_status = nil
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.IsInRange(bot, enemyHero, illuminateRange)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
		then
			if
				Fu.CanKillTarget(enemyHero, damage, DAMAGE_TYPE_MAGICAL)
				and not Fu.IsRunning(enemyHero)
				and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
				and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
				and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
				and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
				and not enemyHero:HasModifier("modifier_templar_assassin_refraction_absorb")
				and not enemyHero:HasModifier("modifier_troll_warlord_battle_trance")
			then
				bot.illuminate_status = { "kill", enemyHero }
				return BOT_ACTION_DESIRE_HIGH, enemyHero:GetLocation()
			end
			if Fu.IsInEtherealForm(enemyHero) or enemyHero:HasModifier("modifier_keeper_of_the_light_radiant_bind") then
				return BOT_ACTION_DESIRE_HIGH, enemyHero:GetLocation()
			end
		end
	end
	if isGoingOnSomeone then
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, illuminateRange)
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
			and not botTarget:HasModifier("modifier_templar_assassin_refraction_absorb")
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	if Fu.IsFarming(bot) and manaAfterCast > 0.25 then
		local nearbyCreeps = bot:GetNearbyCreeps(800, true)
		if
			#nearbyCreeps >= 3
			and Fu.IsValid(nearbyCreeps[1])
			and Fu.CanBeAttacked(nearbyCreeps[1])
			and not Fu.IsRunning(nearbyCreeps[1])
		then
			local aoeLocation = bot:FindAoELocation(true, false, nearbyCreeps[1]:GetLocation(), 0, radius, 0, 0)
			if aoeLocation.count >= 3 or aoeLocation.count >= 2 and nearbyCreeps[1]:IsAncientCreep() then
				return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
			end
		end
	end
	local laneCreeps = bot:GetNearbyLaneCreeps(800, true)
	if Fu.IsPushing(bot) or Fu.IsDefending(bot) then
		if
			#laneCreeps >= 3
			and Fu.IsValid(laneCreeps[1])
			and Fu.CanBeAttacked(laneCreeps[1])
			and not Fu.IsRunning(laneCreeps[1])
		then
			local aoeLocation = bot:FindAoELocation(true, false, laneCreeps[1]:GetLocation(), 0, radius, 0, 0)
			if aoeLocation.count >= 3 then
				return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
			end
		end
	end
	if
		Fu.IsLaning(bot)
		and (Fu.IsCore(bot) or not Fu.IsCore(bot) and not Fu.IsThereCoreNearby(1200))
		and manaAfterCast > 0.28
	then
		local killableCreeps = {}
		local enemyTowers = bot:GetNearbyTowers(1600, true)
		for _, creep in pairs(laneCreeps) do
			if
				Fu.IsValid(creep)
				and Fu.IsKeyWordUnit("ranged", creep)
				and Fu.CanBeAttacked(creep)
				and not Fu.IsRunning(creep)
				and Fu.CanKillTarget(creep, damage, DAMAGE_TYPE_MAGICAL)
			then
				if
					Fu.IsValidHero(nearbyEnemies[1])
					and not Fu.IsSuspiciousIllusion(nearbyEnemies[1])
					and GetUnitToUnitDistance(creep, nearbyEnemies[1]) <= 600
					and (
						#enemyTowers == 0
						or Fu.IsValidBuilding(enemyTowers[1]) and GetUnitToUnitDistance(enemyTowers[1], creep) > 700
					)
				then
					bot.illuminate_status = { "laning", creep }
					return BOT_ACTION_DESIRE_HIGH, creep:GetLocation()
				end
			end
			if Fu.IsValid(creep) and Fu.CanKillTarget(creep, damage, DAMAGE_TYPE_MAGICAL) then
				table.insert(killableCreeps, creep)
			end
		end
		if #killableCreeps >= 2 then
			return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(killableCreeps)
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if
			Fu.IsRoshan(botTarget)
			and Fu.IsInRange(botTarget, bot, castRange)
			and Fu.CanBeAttacked(botTarget)
			and isAttacking
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(botTarget, bot, castRange) and isAttacking then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.ConsiderIlluminateEnd()
	if not Fu.CanCastAbility(illuminateEndAbility) then
		return BOT_ACTION_DESIRE_NONE
	end
	local maxChannelTime = illuminateAbility:GetSpecialValueInt("max_channel_time")
	local totalDamage = illuminateAbility:GetSpecialValueInt("total_damage")
	local currentDamage =
		RemapValClamped(DotaTime(), illuminateCastTime, illuminateCastTime + maxChannelTime, 0, totalDamage)
	if bot.illuminate_status ~= nil then
		if bot.illuminate_status[1] == "kill" then
			if
				Fu.IsValidHero(bot.illuminate_status[2])
				and Fu.CanKillTarget(bot.illuminate_status[2], currentDamage, DAMAGE_TYPE_MAGICAL)
			then
				return BOT_ACTION_DESIRE_HIGH
			end
		elseif bot.illuminate_status[1] == "laning" then
			if
				Fu.IsValid(bot.illuminate_status[2])
				and Fu.CanKillTarget(bot.illuminate_status[2], currentDamage, DAMAGE_TYPE_MAGICAL)
			then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderBlindingLight()
	if not Fu.CanCastAbility(blindingLightAbility) then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local castRange = Fu.GetProperCastRange(false, bot, blindingLightAbility:GetCastRange())
	local castPoint = blindingLightAbility:GetCastPoint()
	local damage = blindingLightAbility:GetSpecialValueInt("damage")
	local radius = blindingLightAbility:GetSpecialValueInt("radius")
	local abilityLevel = blindingLightAbility:GetLevel()
	for _, enemyHero in pairs(nearbyEnemies) do
		-- Range check added: nearbyEnemies reaches 1600, so a killable enemy 1600 away made Keeper walk up to it.
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and Fu.IsInRange(bot, enemyHero, castRange)
		then
			if
				Fu.CanKillTarget(enemyHero, damage, DAMAGE_TYPE_MAGICAL)
				and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
				and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
				and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
				and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
				and not enemyHero:HasModifier("modifier_templar_assassin_refraction_absorb")
				and not enemyHero:HasModifier("modifier_troll_warlord_battle_trance")
			then
				return BOT_ACTION_DESIRE_HIGH, enemyHero:GetLocation()
			end
			if
				enemyHero:HasModifier("modifier_troll_warlord_battle_trance") and Fu.IsAttacking(enemyHero)
				or enemyHero:HasModifier("modifier_legion_commander_duel") and Fu.GetHP(enemyHero) > 0.25
			then
				return BOT_ACTION_DESIRE_HIGH, enemyHero:GetLocation()
			end
		end
	end
	if isGoingOnSomeone then
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and not botTarget:HasModifier("modifier_enigma_black_hole_pull")
			and not botTarget:HasModifier("modifier_faceless_void_chronosphere_freeze")
			and not botTarget:HasModifier("modifier_legion_commander_duel")
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			if Fu.IsChasingTarget(bot, botTarget) then
				local castLocation = Fu.VectorAway(botTarget:GetLocation(), bot:GetLocation(), castRange * 0.5)
				return BOT_ACTION_DESIRE_HIGH, castLocation
			end
		end
	end
	if
		Fu.IsRetreating(bot)
		and not Fu.IsRealInvisible(bot)
		and not Fu.CanCastAbility(solarBindAbility)
		and bot:WasRecentlyDamagedByAnyHero(3.0)
	then
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.IsInRange(bot, enemyHero, radius)
				and Fu.IsChasingTarget(enemyHero, bot)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and not Fu.IsDisabled(enemyHero)
			then
				return BOT_ACTION_DESIRE_HIGH, (bot:GetLocation() + enemyHero:GetLocation()) / 2
			end
		end
	end
	for _, allyHero in pairs(nearbyAllies) do
		if
			Fu.IsValidHero(allyHero)
			and Fu.IsInRange(bot, allyHero, castRange)
			and Fu.IsRetreating(allyHero)
			and not allyHero:IsIllusion()
		then
			local allyNearbyEnemies = allyHero:GetNearbyHeroes(radius, true, BOT_MODE_NONE)
			if
				Fu.IsValidHero(allyNearbyEnemies[1])
				and Fu.CanCastOnNonMagicImmune(allyNearbyEnemies[1])
				and not Fu.IsSuspiciousIllusion(allyNearbyEnemies[1])
				and not allyNearbyEnemies[1]:HasModifier("modifier_enigma_black_hole_pull")
				and not allyNearbyEnemies[1]:HasModifier("modifier_faceless_void_chronosphere_freeze")
				and not allyNearbyEnemies[1]:HasModifier("modifier_legion_commander_duel")
				and not allyNearbyEnemies[1]:HasModifier("modifier_necrolyte_reapers_scythe")
			then
				-- Blinding Light knocks units to the edge of the area (datafeed), i.e. away from its centre.
				-- The centre used to be past the enemy (VectorAway), which knocked the chaser onto the
				-- retreating ally. Put the centre between them so the chaser is knocked away from the ally.
				local castLocation =
					Fu.VectorTowards(allyNearbyEnemies[1]:GetLocation(), allyHero:GetLocation(), radius * 0.4)
				X.LogKotl(
					"blind-save ally=" .. allyHero:GetUnitName() .. " enemy=" .. allyNearbyEnemies[1]:GetUnitName()
				)
				return BOT_ACTION_DESIRE_HIGH, castLocation
			end
		end
	end
	if abilityLevel >= 3 and (Fu.IsPushing(bot) or Fu.IsDefending(bot)) then
		local laneCreeps = bot:GetNearbyLaneCreeps(castRange, true)
		if #laneCreeps >= 4 then
			local aoeLocation = bot:FindAoELocation(true, false, bot:GetLocation(), castRange, radius, 0, 0)
			if aoeLocation.count >= 4 then
				return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.ConsiderChakraMagic()
	if not Fu.CanCastAbility(chakraMagicAbility) then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castRange = Fu.GetProperCastRange(false, bot, chakraMagicAbility:GetCastRange())
	local manaRestore = chakraMagicAbility:GetSpecialValueInt("mana_restore")
	if bot:GetMaxMana() - bot:GetMana() > manaRestore * 1.2 then
		return BOT_ACTION_DESIRE_HIGH, bot
	else
		local alliesInRange = Fu.GetAlliesNearLoc(bot:GetLocation(), castRange)
		for _, allyHero in pairs(alliesInRange) do
			if Fu.IsValidHero(allyHero) and allyHero:GetMaxMana() - allyHero:GetMana() > manaRestore * 1.3 then
				return BOT_ACTION_DESIRE_HIGH, allyHero
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function X.ConsiderSolarBind()
	if not Fu.CanCastAbility(solarBindAbility) then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castRange = Fu.GetProperCastRange(false, bot, solarBindAbility:GetCastRange())
	if isGoingOnSomeone then
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanBeAttacked(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.CanCastOnTargetAdvanced(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and not Fu.IsDisabled(botTarget)
			and not botTarget:HasModifier("modifier_dazzle_shallow_grave")
			and not botTarget:HasModifier("modifier_faceless_void_chronosphere_freeze")
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
			and not botTarget:HasModifier("modifier_keeper_of_the_light_radiant_bind")
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end
	if
		Fu.IsRetreating(bot)
		and not Fu.IsRealInvisible(bot)
		and not Fu.CanCastAbility(blindingLightAbility)
		and bot:WasRecentlyDamagedByAnyHero(3.0)
	then
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.IsInRange(bot, enemyHero, 400)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
				and Fu.IsChasingTarget(enemyHero, bot)
				and not Fu.IsDisabled(enemyHero)
				and not enemyHero:HasModifier("modifier_keeper_of_the_light_radiant_bind")
			then
				return BOT_ACTION_DESIRE_HIGH, enemyHero
			end
		end
	end
	if not Fu.CanCastAbility(blindingLightAbility) then
		for _, allyHero in pairs(nearbyAllies) do
			if
				Fu.IsValidHero(allyHero)
				and Fu.IsInRange(bot, allyHero, castRange)
				and Fu.IsRetreating(allyHero)
				and not allyHero:IsIllusion()
			then
				local allyNearbyEnemies = allyHero:GetNearbyHeroes(400, true, BOT_MODE_NONE)
				if
					Fu.IsValidHero(allyNearbyEnemies[1])
					and Fu.CanCastOnNonMagicImmune(allyNearbyEnemies[1])
					and Fu.CanCastOnTargetAdvanced(allyNearbyEnemies[1])
					and not Fu.IsSuspiciousIllusion(allyNearbyEnemies[1])
					and not Fu.IsDisabled(allyNearbyEnemies[1])
					and not allyNearbyEnemies[1]:HasModifier("modifier_necrolyte_reapers_scythe")
					and not allyNearbyEnemies[1]:HasModifier("modifier_keeper_of_the_light_radiant_bind")
				then
					return BOT_ACTION_DESIRE_HIGH, allyNearbyEnemies[1]
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
function X.ConsiderWillOWisp()
	if not Fu.CanCastAbility(willOWispAbility) then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local castRange = Fu.GetProperCastRange(false, bot, willOWispAbility:GetCastRange())
	local radius = willOWispAbility:GetSpecialValueInt("radius")
	local castPoint = willOWispAbility:GetCastPoint()
	-- Will-O-Wisp has no "duration" key (game KV), so the old "duration > 0.5" test read 0 and the
	-- TP-cancel branch never fired. Its first pull comes after off_duration_initial (1.0s).
	local firstPullDelay = willOWispAbility:GetSpecialValueFloat("off_duration_initial")
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.IsInRange(bot, enemyHero, castRange)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and enemyHero:HasModifier("modifier_teleporting")
		then
			local teleportTimeLeft = Fu.GetModifierTime(enemyHero, "modifier_teleporting")
			if teleportTimeLeft > castPoint + firstPullDelay then
				X.LogKotl("wisp-tp target=" .. enemyHero:GetUnitName())
				return BOT_ACTION_DESIRE_HIGH, enemyHero:GetLocation()
			end
		end
	end
	if Fu.IsInTeamFight(bot, 1200) then
		local aoeLocation = bot:FindAoELocation(true, true, bot:GetLocation(), castRange, radius, 0, 0)
		local enemiesInRadius = Fu.GetEnemiesNearLoc(aoeLocation.targetloc, radius)
		if #enemiesInRadius >= 2 and (Fu.IsCore(enemiesInRadius[1]) or Fu.IsCore(enemiesInRadius[2])) then
			return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.ConsiderSpiritForm()
	if not Fu.CanCastAbility(spiritFormAbility) then
		return BOT_ACTION_DESIRE_NONE
	end
	if isGoingOnSomeone then
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanBeAttacked(botTarget)
			and Fu.IsInRange(bot, botTarget, 1200)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
			and not botTarget:HasModifier("modifier_troll_warlord_battle_trance")
			and not botTarget:HasModifier("modifier_ursa_enrage")
		then
			if
				Fu.WeAreStronger(bot, 1600)
				or bot:GetEstimatedDamageToTarget(true, botTarget, 10.0, DAMAGE_TYPE_ALL) > botTarget:GetHealth()
			then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
return X
