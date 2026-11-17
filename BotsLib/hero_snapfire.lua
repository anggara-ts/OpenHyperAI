-- Snapfire: skill build, item build, and ability use for this hero.
local X = {}
local bot = GetBot()
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local AbilityContext = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local Minion = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local sTalentList = Fu.Skill.GetTalentList(bot)
local sAbilityList = Fu.Skill.GetAbilityList(bot)
local sRole = Fu.Item.GetRoleItemsBuyList(bot)
local tTalentTreeList = { ["t25"] = { 0, 10 }, ["t20"] = { 0, 10 }, ["t15"] = { 0, 10 }, ["t10"] = { 0, 10 } }
local tAllAbilityBuildList = { { 1, 2, 1, 2, 1, 6, 1, 2, 2, 3, 6, 3, 3, 3, 6 } }
local nAbilityBuildList = Fu.Skill.GetRandomBuild(tAllAbilityBuildList)
local nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList)
local sRoleItemsBuyList = {}
sRoleItemsBuyList["pos_2"] = {
	"item_double_branches",
	"item_circlet",
	"item_faerie_fire",
	"item_tango",
	"item_bottle",
	"item_bracer",
	"item_boots",
	"item_magic_wand",
	"item_blink",
	"item_kaya",
	"item_yasha_and_kaya",
	"item_travel_boots",
	"item_aghanims_shard",
	"item_black_king_bar",
	"item_shivas_guard",
	"item_greater_crit",
	"item_ultimate_scepter",
	"item_sheepstick",
	"item_moon_shard",
	"item_travel_boots_2",
	"item_ultimate_scepter_2",
}
sRoleItemsBuyList["pos_1"] = {
	"item_double_branches",
	"item_circlet",
	"item_faerie_fire",
	"item_tango",
	"item_bracer",
	"item_boots",
	"item_magic_wand",
	"item_maelstrom",
	"item_dragon_lance",
	"item_mjollnir",
	"item_travel_boots",
	"item_greater_crit",
	"item_aghanims_shard",
	"item_black_king_bar",
	"item_force_staff",
	"item_hurricane_pike",
	"item_moon_shard",
	"item_sheepstick",
	"item_travel_boots_2",
	"item_ultimate_scepter_2",
}
sRoleItemsBuyList["pos_3"] = sRoleItemsBuyList["pos_1"]
-- Supports had the carry list (Maelstrom, Daedalus, BKB). Snapfire's most common role is pos 4
-- (hero_pos_weights 60), so give pos 4/5 a support build like Hoodwink's. Aghanim's Scepter grants
-- Gobble Up / Spit Out, and the Shard makes Firesnap Cookie heal and launch a Mortimer Kiss (datafeed).
sRoleItemsBuyList["pos_4"] = {
	"item_priest_outfit",
	"item_blink",
	"item_glimmer_cape",
	"item_guardian_greaves",
	"item_force_staff",
	"item_aghanims_shard",
	"item_ultimate_scepter",
	"item_sheepstick",
	"item_octarine_core",
	"item_moon_shard",
	"item_ultimate_scepter_2",
}
sRoleItemsBuyList["pos_5"] = {
	"item_mage_outfit",
	"item_ancient_janggo",
	"item_glimmer_cape",
	"item_boots_of_bearing",
	"item_blink",
	"item_force_staff",
	"item_aghanims_shard",
	"item_ultimate_scepter",
	"item_sheepstick",
	"item_moon_shard",
	"item_ultimate_scepter_2",
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
function X.MinionThink(minionUnit)
	Minion.MinionThink(minionUnit)
end
local scatterblastAbility =
	SafeAbility(bot:GetAbilityByName("snapfire_scatterblast"), "snapfire_scatterblast", "snapfire")
local firesnapCookieAbility =
	SafeAbility(bot:GetAbilityByName("snapfire_firesnap_cookie"), "snapfire_firesnap_cookie", "snapfire")
local lilShredderAbility =
	SafeAbility(bot:GetAbilityByName("snapfire_lil_shredder"), "snapfire_lil_shredder", "snapfire")
local gobbleUpAbility = SafeAbility(bot:GetAbilityByName("snapfire_gobble_up"), "snapfire_gobble_up", "snapfire")
local spitCreepAbility = SafeAbility(bot:GetAbilityByName("snapfire_spit_creep"), "snapfire_spit_creep", "snapfire")
local mortimerKissesAbility =
	SafeAbility(bot:GetAbilityByName("snapfire_mortimer_kisses"), "snapfire_mortimer_kisses", "snapfire")
local scatterblastDesire, scatterblastLocation
local firesnapCookieDesire, firesnapCookieTarget
local lilShredderDesire
local gobbleUpDesire, gobbleUpTarget
local spitOutDesire, spitOutLocation
local mortimerKissesDesire, mortimerKissesLocation
local botTarget
local isGoingOnSomeone
local isAttacking
local mpRatio
-- Review fix: what Mortimer has in his belly ("creep" or "hero"). Gobble Up used to store this in
-- the ability handle gobbleUpAbility itself (gobbleUpAbility = "hero"), which broke every later Gobble Up call, and the creep
-- case wrote a global that Spit Out never read, so a gobbled creep was never spat.
local gobbled = nil
function X.SkillsComplement()
	if Fu.CanNotUseAbility(bot) then
		return
	end
	local context = AbilityContext.Build(bot)
	isGoingOnSomeone = context.isEngaging
	isAttacking = Fu.IsAttacking(bot)
	mpRatio = context.mp
	mortimerKissesDesire, mortimerKissesLocation = X.ConsiderMortimerKisses()
	if mortimerKissesDesire > 0 then
		bot:Action_UseAbilityOnLocation(mortimerKissesAbility, mortimerKissesLocation)
		return
	end
	lilShredderDesire = X.ConsiderLilShredder()
	if lilShredderDesire > 0 then
		bot:Action_UseAbility(lilShredderAbility)
		return
	end
	scatterblastDesire, scatterblastLocation = X.ConsiderScatterBlast()
	if scatterblastDesire > 0 then
		bot:Action_UseAbilityOnLocation(scatterblastAbility, scatterblastLocation)
		return
	end
	firesnapCookieDesire, firesnapCookieTarget = X.ConsiderFiresnapCookie()
	if firesnapCookieDesire > 0 then
		bot:Action_UseAbilityOnEntity(firesnapCookieAbility, firesnapCookieTarget)
		return
	end
	spitOutDesire, spitOutLocation = X.ConsiderSpitOut()
	if spitOutDesire > 0 then
		bot:Action_UseAbilityOnLocation(spitCreepAbility, spitOutLocation)
		return
	end
	gobbleUpDesire, gobbleUpTarget = X.ConsiderGobbleUp()
	if gobbleUpDesire > 0 then
		bot:Action_UseAbilityOnEntity(gobbleUpAbility, gobbleUpTarget)
		return
	end
end
function X.ConsiderScatterBlast()
	if not scatterblastAbility:IsFullyCastable() or bot:HasModifier("modifier_snapfire_mortimer_kisses") then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local castRange = Fu.GetProperCastRange(false, bot, scatterblastAbility:GetCastRange())
	local castPoint = scatterblastAbility:GetCastPoint()
	local radius = scatterblastAbility:GetSpecialValueInt("blast_width_end")
	local damage = scatterblastAbility:GetSpecialValueInt("damage")
	botTarget = Fu.GetProperTarget(bot)
	local nearbyEnemies = Fu.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and Fu.IsInRange(bot, enemyHero, castRange)
			and Fu.CanKillTarget(enemyHero, damage, DAMAGE_TYPE_MAGICAL)
			and not Fu.IsSuspiciousIllusion(enemyHero)
			and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
			and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
			and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
			and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
			and not enemyHero:HasModifier("modifier_templar_assassin_refraction_absorb")
		then
			return BOT_ACTION_DESIRE_HIGH, enemyHero:GetExtrapolatedLocation(castPoint)
		end
	end
	if Fu.IsInTeamFight(bot, 1200) then
		local aoe = bot:FindAoELocation(true, true, bot:GetLocation(), castRange, radius, 0, 0)
		local enemiesNearAoe = Fu.GetEnemiesNearLoc(aoe.targetloc, radius)
		if enemiesNearAoe ~= nil and #enemiesNearAoe >= 2 then
			return BOT_ACTION_DESIRE_HIGH, aoe.targetloc
		end
	end
	if isGoingOnSomeone then
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			local alliesNearTarget = Fu.GetNearbyHeroes(botTarget, 1200, true, BOT_MODE_NONE)
			local enemiesNearTarget = Fu.GetNearbyHeroes(botTarget, 1200, false, BOT_MODE_NONE)
			if alliesNearTarget ~= nil and enemiesNearTarget ~= nil and #alliesNearTarget >= #enemiesNearTarget then
				return BOT_ACTION_DESIRE_HIGH, botTarget:GetExtrapolatedLocation(castPoint)
			end
		end
	end
	if Fu.IsRetreating(bot) then
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.IsInRange(bot, enemyHero, castRange)
				and Fu.IsChasingTarget(enemyHero, bot)
				-- Review fix: the slow is the escape value, so also blast a chaser that is hurting us,
				-- not only one it kills.
				and (Fu.CanKillTarget(enemyHero, damage, DAMAGE_TYPE_MAGICAL) or bot:WasRecentlyDamagedByHero(
					enemyHero,
					2.0
				))
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
				and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
				and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
				and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
				and not enemyHero:HasModifier("modifier_templar_assassin_refraction_absorb")
			then
				-- Review fix: the cone was aimed at Snapfire's own position, so its direction was
				-- undefined/forward (away from the chaser while running). Aim at the chaser.
				if DotaTime() - (X.lastBlastLog or -99) > 10 then
					X.lastBlastLog = DotaTime()
					pcall(
						print,
						string.format(
							"[OHA-SNAPFIRE] t=%.0f scatter-retreat chaser=%s",
							DotaTime(),
							enemyHero:GetUnitName()
						)
					)
				end
				return BOT_ACTION_DESIRE_HIGH, enemyHero:GetExtrapolatedLocation(castPoint)
			end
		end
	end
	if (Fu.IsPushing(bot) or Fu.IsDefending(bot)) and not bot:HasModifier("modifier_snapfire_lil_shredder_buff") then
		local aoe = bot:FindAoELocation(true, false, bot:GetLocation(), castRange, radius, castPoint, 0)
		local laneCreeps = bot:GetNearbyLaneCreeps(castRange, true)
		if laneCreeps ~= nil and #laneCreeps >= 4 and aoe.count >= 4 then
			return BOT_ACTION_DESIRE_HIGH, aoe.targetloc
		end
		aoe = bot:FindAoELocation(true, true, bot:GetLocation(), castRange, radius, castPoint, 0)
		if aoe.count >= 1 then
			return BOT_ACTION_DESIRE_HIGH, aoe.targetloc
		end
	end
	if Fu.IsFarming(bot) and not bot:HasModifier("modifier_snapfire_lil_shredder_buff") then
		local aoe = bot:FindAoELocation(true, false, bot:GetLocation(), castRange, radius, castPoint, 0)
		if isAttacking then
			local neutralCreeps = bot:GetNearbyNeutralCreeps(castRange)
			if
				neutralCreeps ~= nil
				and (#neutralCreeps >= 3 and aoe.count >= 3 or #neutralCreeps >= 2 and neutralCreeps[1]:IsAncientCreep() and aoe.count >= 2)
				and mpRatio > 0.33
			then
				return BOT_ACTION_DESIRE_HIGH, aoe.targetloc
			end
			local laneCreeps = bot:GetNearbyLaneCreeps(castRange, true)
			if laneCreeps ~= nil and #laneCreeps >= 3 and aoe.count >= 3 and mpRatio > 0.37 then
				return BOT_ACTION_DESIRE_HIGH, aoe.targetloc
			end
		end
	end
	if Fu.IsLaning(bot) then
		local killableCount = 0
		local killableCreeps = {}
		local laneCreeps = bot:GetNearbyLaneCreeps(castRange, true)
		local enemiesInRange = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
		for _, creep in pairs(laneCreeps) do
			if Fu.IsValid(creep) and creep:GetHealth() <= damage then
				killableCount = killableCount + 1
				table.insert(killableCreeps, creep)
			end
		end
		if killableCount >= 2 and mpRatio > 0.25 and enemiesInRange ~= nil and #enemiesInRange >= 1 then
			return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(killableCreeps)
		end
		if
			enemiesInRange ~= nil
			and #enemiesInRange >= 1
			and Fu.IsValidHero(enemiesInRange[1])
			and Fu.IsAttacking(enemiesInRange[1])
			and mpRatio > 0.55
			and Fu.GetHP(bot) < Fu.GetHP(enemiesInRange[1])
			and enemiesInRange[1]:GetAttackTarget() == bot
		then
			return BOT_ACTION_DESIRE_HIGH, enemiesInRange[1]:GetLocation()
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
function X.ConsiderFiresnapCookie()
	-- Review fix: casting another ability cancels Mortimer Kisses (datafeed note), and Cookie is
	-- considered right after it; skip Cookie while Kisses is running, as the other spells do.
	if not firesnapCookieAbility:IsFullyCastable() or bot:HasModifier("modifier_snapfire_mortimer_kisses") then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castRange = Fu.GetProperCastRange(false, bot, firesnapCookieAbility:GetCastRange())
	local castPoint = firesnapCookieAbility:GetCastPoint()
	local radius = firesnapCookieAbility:GetSpecialValueInt("impact_radius")
	local jumpDistance = firesnapCookieAbility:GetSpecialValueInt("jump_horizontal_distance")
	local jumpDuration = firesnapCookieAbility:GetSpecialValueFloat("jump_duration") -- Review fix: 0.484 read as Int gave 0
	botTarget = Fu.GetProperTarget(bot)
	local nearbyEnemies = Fu.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and enemyHero:IsChanneling()
			and bot:IsFacingLocation(enemyHero:GetLocation(), 15)
			and not Fu.IsSuspiciousIllusion(enemyHero)
		then
			local alliesNearTarget = Fu.GetNearbyHeroes(enemyHero, 1200, true, BOT_MODE_NONE)
			local enemiesNearTarget = Fu.GetNearbyHeroes(enemyHero, 1200, false, BOT_MODE_NONE)
			if
				Fu.IsInRange(bot, enemyHero, jumpDistance + radius)
				and not Fu.IsInRange(bot, enemyHero, jumpDistance * 0.51)
				and alliesNearTarget ~= nil
				and enemiesNearTarget ~= nil
				and #alliesNearTarget >= #enemiesNearTarget
			then
				return BOT_ACTION_DESIRE_HIGH, bot
			end
		end
	end
	if Fu.IsStuck(bot) then
		return BOT_ACTION_DESIRE_HIGH, bot
	end
	if Fu.IsInTeamFight(bot, 1200) then
		local aoe =
			bot:FindAoELocation(true, true, bot:GetLocation(), jumpDistance, radius, jumpDuration + castPoint, 0)
		local enemiesNearAoe = Fu.GetEnemiesNearLoc(aoe.targetloc, jumpDistance)
		local notStunnedCount = Fu.CountNotStunnedUnits(enemiesNearAoe, aoe, radius, 2)
		if
			enemiesNearAoe ~= nil
			and #enemiesNearAoe >= 2
			and notStunnedCount >= 2
			and bot:IsFacingLocation(aoe.targetloc, 15)
		then
			return BOT_ACTION_DESIRE_LOW, bot
		end
	end
	if isGoingOnSomeone then
		local enemiesInRange = Fu.GetNearbyHeroes(bot, 600, true, BOT_MODE_NONE)
		for _, enemyHero in pairs(enemiesInRange) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.IsChasingTarget(bot, enemyHero)
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and not Fu.IsDisabled(enemyHero)
				and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
				and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
				and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
				and not Fu.IsLocationInChrono(enemyHero:GetLocation())
				and not Fu.IsLocationInBlackHole(enemyHero:GetLocation())
			then
				local alliesNearTarget = Fu.GetNearbyHeroes(enemyHero, 1200, true, BOT_MODE_NONE)
				local enemiesNearTarget = Fu.GetNearbyHeroes(enemyHero, 1200, false, BOT_MODE_NONE)
				if alliesNearTarget ~= nil and enemiesNearTarget ~= nil and #alliesNearTarget >= #enemiesNearTarget then
					return BOT_ACTION_DESIRE_HIGH, bot
				end
			end
		end
		local nearbyAllies = Fu.GetNearbyHeroes(bot, castRange, false, BOT_MODE_ATTACK)
		for _, allyHero in pairs(nearbyAllies) do
			local allyTarget = allyHero:GetAttackTarget()
			if
				Fu.IsValidHero(allyHero)
				and Fu.IsValidTarget(allyTarget)
				and Fu.CanCastOnNonMagicImmune(allyTarget)
				and Fu.IsChasingTarget(allyHero, allyTarget)
				and Fu.IsInRange(allyHero, allyTarget, jumpDistance)
				and not Fu.IsInRange(allyHero, allyTarget, jumpDistance / 2)
				and not allyHero:IsIllusion()
				and not Fu.IsSuspiciousIllusion(allyTarget)
				and not Fu.IsDisabled(allyTarget)
				and not allyTarget:HasModifier("modifier_abaddon_borrowed_time")
				and not allyTarget:HasModifier("modifier_dazzle_shallow_grave")
				and not allyTarget:HasModifier("modifier_necrolyte_reapers_scythe")
				and not Fu.IsLocationInChrono(allyTarget:GetLocation())
				and not Fu.IsLocationInBlackHole(allyTarget:GetLocation())
			then
				local alliesNearAllyTarget = Fu.GetNearbyHeroes(allyTarget, 1200, true, BOT_MODE_NONE)
				local enemiesNearAllyTarget = Fu.GetNearbyHeroes(allyTarget, 1200, false, BOT_MODE_NONE)
				if
					alliesNearAllyTarget ~= nil
					and enemiesNearAllyTarget ~= nil
					and #alliesNearAllyTarget >= #enemiesNearAllyTarget
				then
					return BOT_ACTION_DESIRE_HIGH, allyHero
				end
			end
		end
	end
	if Fu.IsRetreating(bot) then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, 1000, false, BOT_MODE_NONE)
		local enemiesInRange = Fu.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE)
		if
			nearbyAllies ~= nil
			and enemiesInRange ~= nil
			and Fu.IsValidHero(enemiesInRange[1])
			and not Fu.IsSuspiciousIllusion(enemiesInRange[1])
			and not Fu.IsDisabled(enemiesInRange[1])
		then
			local enemiesNearEnemy = Fu.GetNearbyHeroes(enemiesInRange[1], 1200, false, BOT_MODE_NONE)
			if
				enemiesNearEnemy ~= nil
				and (#enemiesNearEnemy > #nearbyAllies or Fu.GetHP(bot) < 0.65 and bot:WasRecentlyDamagedByAnyHero(1.5))
				and bot:IsFacingLocation(Fu.GetEscapeLoc(), 30)
			then
				return BOT_ACTION_DESIRE_HIGH, bot
			end
		end
	end
	local nearbyAllies = Fu.GetNearbyHeroes(bot, 1000, false, BOT_MODE_NONE)
	for _, allyHero in pairs(nearbyAllies) do
		if Fu.IsValidHero(allyHero) and Fu.IsStuck(allyHero) and not allyHero:IsIllusion() then
			return BOT_ACTION_DESIRE_HIGH, allyHero
		end
		local enemiesNearAlly = Fu.GetNearbyHeroes(allyHero, 800, true, BOT_MODE_NONE)
		if Fu.IsRetreating(allyHero) and not allyHero:IsIllusion() then
			if
				enemiesNearAlly ~= nil
				and #enemiesNearAlly >= 1
				and Fu.IsValidHero(enemiesNearAlly[1])
				and Fu.IsInRange(bot, allyHero, castRange)
				and Fu.IsChasingTarget(enemiesNearAlly[1], allyHero)
				and allyHero:IsFacingLocation(Fu.GetEscapeLoc(), 30)
				and not Fu.IsSuspiciousIllusion(enemiesNearAlly[1])
				and not Fu.IsDisabled(enemiesNearAlly[1])
				and not Fu.IsTaunted(enemiesNearAlly[1])
				and not enemiesNearAlly[1]:HasModifier("modifier_enigma_black_hole_pull")
				and not enemiesNearAlly[1]:HasModifier("modifier_faceless_void_chronosphere_freeze")
				and not enemiesNearAlly[1]:HasModifier("modifier_necrolyte_reapers_scythe")
			then
				return BOT_ACTION_DESIRE_HIGH, allyHero
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function X.ConsiderLilShredder()
	if not lilShredderAbility:IsFullyCastable() or bot:HasModifier("modifier_snapfire_mortimer_kisses") then
		return BOT_ACTION_DESIRE_NONE
	end
	local attackRange = bot:GetAttackRange() + lilShredderAbility:GetSpecialValueInt("attack_range_bonus")
	botTarget = Fu.GetProperTarget(bot)
	if botTarget ~= nil and botTarget:IsBuilding() and isAttacking then
		return BOT_ACTION_DESIRE_HIGH
	end
	if isGoingOnSomeone then
		if
			Fu.IsValidTarget(botTarget)
			and Fu.IsInRange(bot, botTarget, attackRange - 100)
			and isAttacking
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			local alliesNearTarget = Fu.GetNearbyHeroes(botTarget, 1200, true, BOT_MODE_NONE)
			local enemiesNearTarget = Fu.GetNearbyHeroes(botTarget, 1200, false, BOT_MODE_NONE)
			if alliesNearTarget ~= nil and enemiesNearTarget ~= nil and #alliesNearTarget >= #enemiesNearTarget then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	if Fu.IsPushing(bot) or Fu.IsDefending(bot) then
		local enemiesInRange = Fu.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE)
		local laneCreeps = bot:GetNearbyLaneCreeps(attackRange, true)
		local nearbyTowers = bot:GetNearbyTowers(bot:GetAttackRange(), true)
		if
			isAttacking
			and enemiesInRange ~= nil
			and #enemiesInRange <= 1
			and (laneCreeps ~= nil and #laneCreeps >= 4 or nearbyTowers ~= nil and #nearbyTowers >= 1)
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsFarming(bot) then
		if isAttacking and mpRatio > 0.33 then
			local neutralCreeps = bot:GetNearbyNeutralCreeps(attackRange)
			if
				neutralCreeps ~= nil
				and (#neutralCreeps >= 3 or #neutralCreeps >= 2 and neutralCreeps[1]:IsAncientCreep())
			then
				return BOT_ACTION_DESIRE_HIGH
			end
			local laneCreeps = bot:GetNearbyLaneCreeps(attackRange, true)
			if laneCreeps ~= nil and #laneCreeps >= 3 then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if Fu.IsRoshan(botTarget) and Fu.IsInRange(bot, botTarget, 500) and isAttacking then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, 400) and isAttacking then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderMortimerKisses()
	if not mortimerKissesAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local minRange = mortimerKissesAbility:GetSpecialValueInt("min_range")
	if isGoingOnSomeone then
		local enemiesInRange = Fu.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE)
		for _, enemyHero in pairs(enemiesInRange) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and not Fu.IsInRange(bot, enemyHero, minRange)
				and not Fu.IsSuspiciousIllusion(enemyHero)
			then
				if
					Fu.IsLocationInChrono(enemyHero:GetLocation()) or Fu.IsLocationInBlackHole(enemyHero:GetLocation())
				then
					return BOT_ACTION_DESIRE_HIGH, enemyHero:GetLocation()
				end
			end
			if
				Fu.IsValidHero(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and not Fu.IsInRange(bot, enemyHero, minRange)
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
				and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
				and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
				and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
			then
				local alliesNearTarget = Fu.GetNearbyHeroes(enemyHero, 1600, true, BOT_MODE_NONE)
				local enemiesNearTarget = Fu.GetNearbyHeroes(enemyHero, 1600, false, BOT_MODE_NONE)
				if alliesNearTarget ~= nil and enemiesNearTarget ~= nil and #alliesNearTarget >= #enemiesNearTarget then
					return BOT_ACTION_DESIRE_HIGH, enemyHero:GetLocation()
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.ConsiderGobbleUp()
	if
		not bot:HasScepter()
		or not gobbleUpAbility:IsFullyCastable()
		or bot:HasModifier("modifier_snapfire_mortimer_kisses")
	then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castRange = Fu.GetProperCastRange(false, bot, gobbleUpAbility:GetCastRange())
	local kissesCastRange = Fu.GetProperCastRange(false, bot, mortimerKissesAbility:GetCastRange())
	botTarget = Fu.GetProperTarget(bot)
	if isGoingOnSomeone then
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, kissesCastRange)
			and not Fu.IsInRange(bot, botTarget, 600)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
			and not Fu.IsLocationInChrono(botTarget:GetLocation())
			and not Fu.IsLocationInBlackHole(botTarget:GetLocation())
		then
			local nearbyCreeps = bot:GetNearbyCreeps(castRange + 100, true)
			if nearbyCreeps ~= nil and #nearbyCreeps >= 1 then
				gobbled = "creep" -- Review fix: was a global Spit Out never read
				return BOT_ACTION_DESIRE_HIGH, nearbyCreeps[1]
			end
		end
	end
	local nearbyAllies = Fu.GetNearbyHeroes(bot, 1000, false, BOT_MODE_NONE)
	for _, allyHero in pairs(nearbyAllies) do
		local enemiesNearAlly = Fu.GetNearbyHeroes(allyHero, 800, true, BOT_MODE_NONE)
		if Fu.IsRetreating(allyHero) and allyHero:WasRecentlyDamagedByAnyHero(1.5) and not allyHero:IsIllusion() then
			if
				enemiesNearAlly ~= nil
				and #enemiesNearAlly >= 1
				and Fu.IsValidHero(enemiesNearAlly[1])
				and Fu.IsInRange(bot, allyHero, castRange)
				and Fu.IsInRange(allyHero, enemiesNearAlly[1], 600)
				and Fu.IsChasingTarget(enemiesNearAlly[1], allyHero)
				and not Fu.IsSuspiciousIllusion(enemiesNearAlly[1])
				and not Fu.IsDisabled(enemiesNearAlly[1])
				and not Fu.IsTaunted(enemiesNearAlly[1])
				and not enemiesNearAlly[1]:HasModifier("modifier_enigma_black_hole_pull")
				and not enemiesNearAlly[1]:HasModifier("modifier_faceless_void_chronosphere_freeze")
				and not enemiesNearAlly[1]:HasModifier("modifier_necrolyte_reapers_scythe")
			then
				gobbled = "hero" -- Review fix: was gobbleUpAbility = "hero", overwriting the Gobble Up ability handle
				if DotaTime() - (X.lastGobbleLog or -99) > 10 then
					X.lastGobbleLog = DotaTime()
					pcall(
						print,
						string.format("[OHA-SNAPFIRE] t=%.0f gobble-save ally=%s", DotaTime(), allyHero:GetUnitName())
					)
				end
				return BOT_ACTION_DESIRE_HIGH, allyHero
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function X.ConsiderSpitOut()
	if not spitCreepAbility:IsFullyCastable() or not bot:HasModifier("modifier_snapfire_gobble_up_belly_has_unit") then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local kissesCastRange = Fu.GetProperCastRange(false, bot, mortimerKissesAbility:GetCastRange())
	botTarget = Fu.GetProperTarget(bot)
	-- Review fix: read the belly kind from gobbled, not from the ability handle gobbleUpAbility.
	if isGoingOnSomeone and gobbled == "creep" then
		if Fu.IsValidTarget(botTarget) then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	if gobbled == "hero" then
		return BOT_ACTION_DESIRE_HIGH, Fu.Site.GetXUnitsTowardsLocation(bot, Fu.GetEscapeLoc(), kissesCastRange)
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
return X
