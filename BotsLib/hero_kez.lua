-- Kez: skill build, item build, and ability use for this hero.
-- Accidental globals made file-local (#13): every bot shares one Lua state, so these were shared.
local botTarget, KazuraiKatanaDesire, KazuraiKatanaTarget
local X = {}
local bot = GetBot()
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local AbilityContext = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local Minion = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local sTalentList = Fu.Skill.GetTalentList(bot)
local sAbilityList = Fu.Skill.GetAbilityList(bot)
local sRole = Fu.Item.GetRoleItemsBuyList(bot)
local tTalentTreeList = { ["t25"] = { 10, 0 }, ["t20"] = { 0, 10 }, ["t15"] = { 0, 10 }, ["t10"] = { 10, 0 } }
local tAllAbilityBuildList = { { 1, 3, 1, 2, 3, 6, 3, 3, 1, 1, 6, 2, 2, 2, 6 } }
local nAbilityBuildList = Fu.Skill.GetRandomBuild(tAllAbilityBuildList)
local nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList)
local sRoleItemsBuyList = {}
sRoleItemsBuyList["pos_1"] = {
	"item_double_branches",
	"item_quelling_blade",
	"item_tango",
	"item_wraith_band",
	"item_magic_wand",
	"item_power_treads",
	"item_desolator",
	"item_mage_slayer",
	"item_black_king_bar",
	"item_lesser_crit",
	"item_greater_crit",
	"item_ultimate_scepter",
	"item_aghanims_shard",
	"item_moon_shard",
	"item_ultimate_scepter_2",
	"item_travel_boots_2",
}
sRoleItemsBuyList["pos_2"] = {
	"item_tango",
	"item_double_branches",
	"item_quelling_blade",
	"item_magic_wand",
	"item_wraith_band",
	"item_power_treads",
	"item_desolator",
	"item_mage_slayer",
	"item_black_king_bar",
	"item_greater_crit",
	"item_ultimate_scepter",
	"item_aghanims_shard",
	"item_monkey_king_bar",
	"item_moon_shard",
	"item_travel_boots_2",
	"item_ultimate_scepter_2",
}
sRoleItemsBuyList["pos_3"] = sRoleItemsBuyList["pos_1"]
-- One pair of boots in this build (user rule; Util/boots-check.js).
sRoleItemsBuyList["pos_4"] = {
	"item_tango",
	"item_double_branches",
	"item_blood_grenade",
	"item_orb_of_frost",
	"item_magic_wand",
	"item_boots",
	"item_tranquil_boots",
	"item_ancient_janggo",
	"item_boots_of_bearing",
	"item_solar_crest",
	"item_heavens_halberd",
	"item_sheepstick",
	"item_lotus_orb",
	"item_assault",
	"item_moon_shard",
	"item_aghanims_shard",
	"item_ultimate_scepter_2",
}
-- One pair of boots in this build (user rule; Util/boots-check.js).
sRoleItemsBuyList["pos_5"] = {
	"item_tango",
	"item_double_branches",
	"item_blood_grenade",
	"item_orb_of_frost",
	"item_magic_wand",
	"item_boots",
	"item_arcane_boots",
	"item_ancient_janggo",
	"item_pipe",
	"item_solar_crest",
	"item_guardian_greaves",
	"item_heavens_halberd",
	"item_sheepstick",
	"item_lotus_orb",
	"item_moon_shard",
	"item_aghanims_shard",
	"item_ultimate_scepter_2",
}
X["sBuyList"] = sRoleItemsBuyList[sRole]
X["sSellList"] = { "item_black_king_bar", "item_quelling_blade" }
if Fu.Role.IsPvNMode() or Fu.Role.IsAllShadow() then
	X["sBuyList"], X["sSellList"] = { "PvN_tank" }, { "item_heavens_halberd", "item_quelling_blade" }
end
nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"] =
	Fu.SetUserHeroInit(nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"])
X["sSkillList"] = Fu.Skill.GetSkillList(sAbilityList, nAbilityBuildList, sTalentList, nTalentBuildList)
X["bDeafaultAbility"] = false
X["bDeafaultItem"] = false
function X.MinionThink(minionUnit)
	Minion.MinionThink(minionUnit)
end
local switchDisciplineAbility = SafeAbility(bot:GetAbilityByName("kez_switch_weapons"), "kez_switch_weapons", "kez")
local echoSlashAbility = SafeAbility(bot:GetAbilityByName("kez_echo_slash"), "kez_echo_slash", "kez")
local grapplingClawAbility = SafeAbility(bot:GetAbilityByName("kez_grappling_claw"), "kez_grappling_claw", "kez")
local kazuraiKatanaAbility = SafeAbility(bot:GetAbilityByName("kez_kazurai_katana"), "kez_kazurai_katana", "kez")
local raptorDanceAbility = SafeAbility(bot:GetAbilityByName("kez_raptor_dance"), "kez_raptor_dance", "kez")
local falconRushAbility = SafeAbility(bot:GetAbilityByName("kez_falcon_rush"), "kez_falcon_rush", "kez")
local talonTossAbility = SafeAbility(bot:GetAbilityByName("kez_talon_toss"), "kez_talon_toss", "kez")
local shodoSaiAbility = SafeAbility(bot:GetAbilityByName("kez_shodo_sai"), "kez_shodo_sai", "kez")
local shodoSaiCancelAbility =
	SafeAbility(bot:GetAbilityByName("kez_shodo_sai_parry_cancel"), "kez_shodo_sai_parry_cancel", "kez")
local ravensVeilAbility = SafeAbility(bot:GetAbilityByName("kez_ravens_veil"), "kez_ravens_veil", "kez")
local spareRange = 220
local echoSlashDesire, grapplingClawDesire, grapplingClawTarget, grapplingClawTargetType, raptorDanceDesire
local falconRushDesire
local talonTossDesire, talonTossTarget
local shodoSaiDesire, shodoSaiLocation
local shodoSaiCancelDesire
local ravensVeilDesire
local enemyTowers
local switchDisciplineDesire
local isGoingOnSomeone
local isRetreating
local isAttacking
local hpRatio
local mpRatio, nearbyEnemies, nearbyAllies
-- [OHA-KEZ] one line per new behaviour, at most once per 3s per kind.
function X.LogKez(what)
	bot._kezLogAt = bot._kezLogAt or {}
	local kind = string.match(what, "^%S+") or what
	if DotaTime() < (bot._kezLogAt[kind] or -999) then
		return
	end
	bot._kezLogAt[kind] = DotaTime() + 3
	pcall(print, string.format("[OHA-KEZ] t=%.0f %s", DotaTime(), what))
end
function X.SkillsComplement()
	isGoingOnSomeone = Fu.IsGoingOnSomeone(bot)
	isRetreating = Fu.IsRetreating(bot)
	isAttacking = Fu.IsAttacking(bot)
	hpRatio = Fu.GetHP(bot)
	local context = AbilityContext.Build(bot)
	mpRatio = context.mp
	botTarget = context.target
	nearbyEnemies = context.enemies
	nearbyAllies = context.allies
	enemyTowers = bot:GetNearbyTowers(800, true)
	local firstSlotAbility = bot:GetAbilityInSlot(0)
	if firstSlotAbility ~= nil then
		if firstSlotAbility:GetName() == "kez_echo_slash" then
			bot.kez_mode = "katana"
		elseif firstSlotAbility:GetName() == "kez_falcon_rush" then
			bot.kez_mode = "sai"
		end
	end
	if
		Fu.IsInLaningPhase()
		and not isRetreating
		and Fu.IsValidHero(botTarget)
		and Fu.GetHP(botTarget) > 0.5
		and Fu.GetMP(bot) < 0.6
	then
		return
	end
	if Fu.CanNotUseAbility(bot) or bot:HasModifier("modifier_kez_raptor_dance_immune") then
		return
	end
	-- DoCombo queues Veil > Switch > Claw > Echo Slash; without this return the casts below (Switch,
	-- Ravens Veil, Talon Toss) ran in the same tick and an Action_ call cleared the queued combo.
	if X.DoCombo() then
		return
	end
	switchDisciplineDesire = X.ConsiderSwitchDiscipline()
	if switchDisciplineDesire > 0 then
		bot:Action_UseAbility(switchDisciplineAbility)
		return
	end
	if bot.kez_mode == "sai" then
		falconRushDesire = X.ConsiderFalconRush()
		if falconRushDesire > 0 then
			Fu.SetQueuePtToINT(bot, false)
			bot:ActionQueue_UseAbility(falconRushAbility)
			return
		end
		talonTossDesire, talonTossTarget = X.ConsiderTalonToss()
		if talonTossDesire > 0 then
			Fu.SetQueuePtToINT(bot, false)
			bot:ActionQueue_UseAbilityOnEntity(talonTossAbility, talonTossTarget)
			return
		end
		ravensVeilDesire = X.ConsiderRavensVeil()
		if ravensVeilDesire > 0 then
			bot:Action_UseAbility(ravensVeilAbility)
			return
		end
		shodoSaiCancelDesire = X.ConsiderShodoSaiCancel()
		if shodoSaiCancelDesire > 0 then
			bot:Action_UseAbility(shodoSaiCancelAbility)
			return
		end
		shodoSaiDesire, shodoSaiLocation = X.ConsiderShodoSai()
		if shodoSaiDesire > 0 then
			bot:Action_UseAbilityOnLocation(shodoSaiAbility, shodoSaiLocation)
			return
		end
	else
		grapplingClawDesire, grapplingClawTarget, grapplingClawTargetType = X.ConsiderGrapplingClaw()
		if grapplingClawDesire > 0 then
			Fu.SetQueuePtToINT(bot, false)
			if
				grapplingClawTarget ~= nil
				and (type(grapplingClawTarget) == "number" or grapplingClawTargetType == "tree")
			then
				bot:Action_UseAbilityOnTree(grapplingClawAbility, grapplingClawTarget)
			elseif grapplingClawTarget ~= nil then
				bot:Action_UseAbilityOnEntity(grapplingClawAbility, grapplingClawTarget)
			end
			return
		end
		echoSlashDesire = X.ConsiderEchoSlash()
		if echoSlashDesire > 0 then
			Fu.SetQueuePtToINT(bot, false)
			bot:ActionQueue_UseAbility(echoSlashAbility)
			return
		end
		KazuraiKatanaDesire, KazuraiKatanaTarget = X.ConsiderKazuraiKatana()
		if KazuraiKatanaDesire > 0 then
			bot:Action_UseAbilityOnEntity(kazuraiKatanaAbility, KazuraiKatanaTarget)
			return
		end
		raptorDanceDesire = X.ConsiderRaptorDance()
		if raptorDanceDesire > 0 then
			Fu.SetQueuePtToINT(bot, false)
			bot:ActionQueue_UseAbility(raptorDanceAbility)
			return
		end
	end
end
function X.ConsiderEchoSlash()
	if not Fu.CanCastAbility(echoSlashAbility) then
		return BOT_ACTION_DESIRE_NONE
	end
	local katanaDistance = echoSlashAbility:GetSpecialValueInt("katana_distance")
	local travelDistance = echoSlashAbility:GetSpecialValueInt("travel_distance")
	local katanaRadius = echoSlashAbility:GetSpecialValueInt("katana_radius")
	local echoDamagePct = echoSlashAbility:GetSpecialValueInt("katana_echo_damage") / 100
	local echoHeroDamage = echoSlashAbility:GetSpecialValueInt("echo_hero_damage")
	local echoDamage = bot:GetAttackDamage() * echoDamagePct
	local strikes = echoSlashAbility:GetSpecialValueInt("katana_strikes")
	local manaAfter = Fu.GetManaAfter(echoSlashAbility:GetManaCost())
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.IsInRange(bot, enemyHero, katanaDistance * 0.8)
			and bot:IsFacingLocation(enemyHero:GetLocation(), 15)
			and Fu.CanBeAttacked(enemyHero)
			and not Fu.IsSuspiciousIllusion(enemyHero)
			and Fu.CanKillTarget(enemyHero, (echoDamage + echoHeroDamage) * strikes, DAMAGE_TYPE_PHYSICAL)
			and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
			and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
			and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
			and not enemyHero:HasModifier("modifier_troll_warlord_battle_trance")
			and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if isGoingOnSomeone then
		if
			Fu.IsValidHero(botTarget)
			and Fu.IsInRange(bot, botTarget, katanaDistance)
			and bot:IsFacingLocation(botTarget:GetLocation(), 15)
			and Fu.CanBeAttacked(botTarget)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not botTarget:HasModifier("modifier_abaddon_borrowed_time")
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
			and not botTarget:HasModifier("modifier_troll_warlord_battle_trance")
			and not botTarget:HasModifier("modifier_oracle_false_promise_timer")
		then
			if
				not Fu.IsChasingTarget(bot, botTarget)
				or Fu.IsDisabled(botTarget)
				or botTarget:GetCurrentMovementSpeed() <= 200
			then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	if
		isRetreating
		and not Fu.IsRealInvisible(bot)
		and bot:WasRecentlyDamagedByAnyHero(3.0)
		and Fu.CanBeAttacked(bot)
	then
		for _, enemyHero in pairs(nearbyEnemies) do
			if Fu.IsValidHero(enemyHero) and Fu.IsInRange(bot, enemyHero, 1200) then
				if Fu.IsChasingTarget(enemyHero, bot) or nearbyAllies ~= nil and #nearbyEnemies > #nearbyAllies then
					local awayLocation = Fu.VectorAway
							and Fu.VectorAway(bot:GetLocation(), enemyHero:GetLocation(), 800)
						or Fu.GetTeamFountain()
					if bot:IsFacingLocation(Fu.GetTeamFountain(), 45) or bot:IsFacingLocation(awayLocation, 45) then
						return BOT_ACTION_DESIRE_HIGH
					end
				end
			end
		end
	end
	if (Fu.IsPushing(bot) or Fu.IsDefending(bot)) and not Fu.IsThereNonSelfCoreNearby(1200) and manaAfter > 0.4 then
		local laneCreeps = bot:GetNearbyLaneCreeps(katanaDistance, true)
		if Fu.IsValid(laneCreeps[1]) and Fu.CanBeAttacked(laneCreeps[1]) and not Fu.IsRunning(laneCreeps[1]) then
			local aoe = bot:FindAoELocation(true, false, laneCreeps[1]:GetLocation(), 0, katanaRadius, 0, 0)
			if aoe.count >= 4 and bot:IsFacingLocation(aoe.targetloc, 20) then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	if Fu.IsFarming(bot) and not Fu.IsThereNonSelfCoreNearby(1200) and manaAfter > 0.3 then
		local creeps = bot:GetNearbyCreeps(katanaDistance, true)
		if Fu.IsValid(creeps[1]) and Fu.CanBeAttacked(creeps[1]) and not Fu.IsRunning(creeps[1]) then
			local aoe = bot:FindAoELocation(true, false, creeps[1]:GetLocation(), 0, katanaRadius, 0, 0)
			if
				(aoe.count >= 2 or aoe.count >= 2 and creeps[1]:IsAncientCreep())
				and bot:IsFacingLocation(aoe.targetloc, 20)
			then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	if Fu.IsLaning(bot) and not Fu.IsThereNonSelfCoreNearby(1200) then
		if
			nearbyEnemies[1] ~= nil
			and Fu.IsInRange(bot, nearbyEnemies[1], katanaDistance - 100)
			and bot:IsFacingLocation(nearbyEnemies[1]:GetLocation(), 8)
			and manaAfter > 0.5
		then
			return BOT_ACTION_DESIRE_HIGH
		end
		local creeps = bot:GetNearbyCreeps(katanaDistance, true)
		if Fu.IsValid(creeps[1]) and Fu.CanBeAttacked(creeps[1]) and not Fu.IsRunning(creeps[1]) then
			local aoe = bot:FindAoELocation(true, false, creeps[1]:GetLocation(), 0, katanaRadius, 0, 0)
			if aoe.count >= 5 and bot:IsFacingLocation(aoe.targetloc, 15) then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if
			Fu.IsRoshan(botTarget)
			and Fu.CanBeAttacked(botTarget)
			and bot:IsFacingLocation(botTarget:GetLocation(), 20)
			and Fu.IsInRange(bot, botTarget, katanaDistance)
			and isAttacking
			and manaAfter > 0.25
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if
			Fu.IsTormentor(botTarget)
			and Fu.CanBeAttacked(botTarget)
			and bot:IsFacingLocation(botTarget:GetLocation(), 20)
			and Fu.IsInRange(bot, botTarget, katanaDistance)
			and isAttacking
			and manaAfter > 0.25
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderGrapplingClaw()
	if not Fu.CanCastAbility(grapplingClawAbility) or bot:IsRooted() then
		return BOT_ACTION_DESIRE_NONE
	end
	local castRange = grapplingClawAbility:GetCastRange()
	local manaAfter = Fu.GetManaAfter(grapplingClawAbility:GetManaCost())
	if
		isRetreating
		and not Fu.IsRealInvisible(bot)
		and bot:DistanceFromFountain() > 600
		and not bot:HasModifier("modifier_fountain_aura_buff")
	then
		local clawTarget, clawTargetType = X.GetBestRetreatGrapplingTarget(castRange)
		if clawTarget ~= nil then
			if nearbyAllies ~= nil and nearbyEnemies ~= nil then
				for _, enemyHero in pairs(nearbyEnemies) do
					if Fu.IsValidHero(enemyHero) and Fu.IsInRange(bot, enemyHero, 1600) then
						if Fu.IsChasingTarget(enemyHero, bot) or #nearbyEnemies > #nearbyAllies then
							return BOT_ACTION_DESIRE_HIGH, clawTarget, clawTargetType
						end
					end
				end
			end
			if not Fu.IsInLaningPhase() and (manaAfter > 0.4 or hpRatio < 0.2) then
				local alliesNear = Fu.GetAlliesNearLoc(bot:GetLocation(), 1200)
				if nearbyEnemies ~= nil and #nearbyEnemies >= #alliesNear + 2 then
					return BOT_ACTION_DESIRE_HIGH, clawTarget, clawTargetType
				end
			end
		end
	end
	if Fu.IsInLaningPhase() and mpRatio < 0.3 then
		return BOT_ACTION_DESIRE_NONE
	end
	if isGoingOnSomeone then
		if
			Fu.IsValidHero(botTarget)
			and Fu.CanBeAttacked(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and not Fu.IsInRange(bot, botTarget, bot:GetAttackRange() + 200)
			and Fu.IsChasingTarget(bot, botTarget)
			and Fu.CanCastOnTargetAdvanced(botTarget)
			and not botTarget:HasModifier("modifier_enigma_black_hole_pull")
			and not botTarget:HasModifier("modifier_faceless_void_chronosphere_freeze")
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget, "unit"
		end
	end
	if bot.stuckTime ~= nil and DotaTime() - bot.stuckTime > 2 then
		local clawTarget, clawTargetType = X.GetBestRetreatGrapplingTarget(castRange)
		if clawTarget ~= nil then
			return BOT_ACTION_DESIRE_HIGH, clawTarget, clawTargetType
		end
	end
	if Fu.IsLaning(bot) and Fu.IsInLaningPhase() and manaAfter > 0.8 and DotaTime() > 0 then
		local laneFront = GetLaneFrontLocation(GetTeam(), bot:GetAssignedLane(), 0)
		if GetUnitToLocationDistance(bot, laneFront) > 2000 and nearbyEnemies ~= nil and #nearbyEnemies <= 1 then
			local clawTarget, clawTargetType = X.GetBestGrapplingTargetTowardsLocation(castRange, laneFront)
			if clawTarget ~= nil then
				return BOT_ACTION_DESIRE_HIGH, clawTarget, clawTargetType
			end
		end
	end
	if Fu.IsPushing(bot) and manaAfter > 0.5 then
		local lane = LANE_MID
		if bot:GetActiveMode() == BOT_MODE_PUSH_TOWER_TOP then
			lane = LANE_TOP
		end
		if bot:GetActiveMode() == BOT_MODE_PUSH_TOWER_BOT then
			lane = LANE_BOT
		end
		local laneFront = GetLaneFrontLocation(GetTeam(), lane, 0)
		if GetUnitToLocationDistance(bot, laneFront) / bot:GetCurrentMovementSpeed() > 3.5 then
			local clawTarget, clawTargetType = X.GetBestGrapplingTargetTowardsLocation(castRange, laneFront)
			if clawTarget ~= nil then
				return BOT_ACTION_DESIRE_HIGH, clawTarget, clawTargetType
			end
		end
	end
	if Fu.IsDefending(bot) and manaAfter > 0.5 and nearbyEnemies ~= nil and #nearbyEnemies <= 1 then
		local lane = LANE_MID
		if bot:GetActiveMode() == BOT_MODE_DEFEND_TOWER_TOP then
			lane = LANE_TOP
		end
		if bot:GetActiveMode() == BOT_MODE_DEFEND_TOWER_BOT then
			lane = LANE_BOT
		end
		local laneFront = GetLaneFrontLocation(GetTeam(), lane, 0)
		if GetUnitToLocationDistance(bot, laneFront) / bot:GetCurrentMovementSpeed() > 3.5 then
			local clawTarget, clawTargetType = X.GetBestGrapplingTargetTowardsLocation(castRange, laneFront)
			if clawTarget ~= nil then
				return BOT_ACTION_DESIRE_HIGH, clawTarget, clawTargetType
			end
		end
	end
	if Fu.IsFarming(bot) and manaAfter > 0.5 and nearbyEnemies ~= nil and #nearbyEnemies == 0 then
		if bot.farm and bot.farm.location then
			local clawTarget, clawTargetType = X.GetBestGrapplingTargetTowardsLocation(castRange, bot.farm.location)
			if clawTarget ~= nil and Fu.IsRunning(bot) then
				return BOT_ACTION_DESIRE_HIGH, clawTarget, clawTargetType
			end
		end
	end
	if Fu.IsDoingRoshan(bot) then
		local roshanLocation = Fu.GetCurrentRoshanLocation and Fu.GetCurrentRoshanLocation() or nil
		if
			roshanLocation ~= nil
			and GetUnitToLocationDistance(bot, roshanLocation) > 2000
			and nearbyEnemies ~= nil
			and #nearbyEnemies <= 1
			and manaAfter > 0.4
		then
			local clawTarget, clawTargetType = X.GetBestGrapplingTargetTowardsLocation(castRange, roshanLocation)
			if clawTarget ~= nil then
				return BOT_ACTION_DESIRE_HIGH, clawTarget, clawTargetType
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderRaptorDance()
	if not Fu.CanCastAbility(raptorDanceAbility) then
		return BOT_ACTION_DESIRE_NONE
	end
	local radius = raptorDanceAbility:GetSpecialValueInt("radius") - 150
	local baseDamage = raptorDanceAbility:GetSpecialValueInt("base_damage")
	local strikes = raptorDanceAbility:GetSpecialValueInt("strikes")
	local strikeInterval = raptorDanceAbility:GetSpecialValueFloat("strike_interval") or 0.2
	-- max_health_damage_pct is 2.5 (game KV): the Int read truncated it to 2.
	local maxHealthDamagePct = raptorDanceAbility:GetSpecialValueFloat("max_health_damage_pct")
	local castPoint = raptorDanceAbility:GetCastPoint()
	if not bot:IsMagicImmune() then
		if Fu.IsStunProjectileIncoming and Fu.IsStunProjectileIncoming(bot, 800) then
			return BOT_ACTION_DESIRE_NONE
		end
	end
	for _, enemyHero in pairs(nearbyEnemies) do
		if Fu.IsValidHero(enemyHero) and Fu.IsInRange(bot, enemyHero, radius) and Fu.CanBeAttacked(enemyHero) then
			-- Each strike is base_damage + max_health_damage_pct of max HP, both pure (game KV); no attack
			-- damage. Adding Kez's attack damage per strike over-counted and cast Raptor Dance on survivors.
			local totalDamage = (baseDamage + maxHealthDamagePct / 100 * enemyHero:GetMaxHealth()) * strikes
			if
				Fu.CanKillTarget(enemyHero, totalDamage, DAMAGE_TYPE_PURE)
				and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
				and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
				and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
			then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	if Fu.IsInTeamFight(bot, 1200) and hpRatio < 0.75 then
		if
			bot:IsMagicImmune()
			or bot:IsInvulnerable()
			or bot:HasModifier("modifier_dazzle_shallow_grave")
			or bot:HasModifier("modifier_oracle_false_promise_timer")
		then
			local enemiesNear = Fu.GetEnemiesNearLoc(bot:GetLocation(), radius * 0.8)
			if enemiesNear ~= nil and #enemiesNear >= 1 then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	if isGoingOnSomeone and hpRatio < 0.75 then
		if
			Fu.IsValidTarget(botTarget)
			and Fu.IsInRange(bot, botTarget, radius * 0.75)
			and Fu.CanBeAttacked(botTarget)
			and not Fu.IsChasingTarget(bot, botTarget)
			and not botTarget:HasModifier("modifier_abaddon_borrowed_time")
			and not botTarget:HasModifier("modifier_dazzle_shallow_grave")
			and not botTarget:HasModifier("modifier_oracle_false_promise_timer")
			and not botTarget:HasModifier("modifier_ursa_enrage")
		then
			local enemiesNear = Fu.GetEnemiesNearLoc(bot:GetLocation(), radius * 0.8)
			local estimatedDamage =
				bot:GetEstimatedDamageToTarget(true, botTarget, castPoint + strikes * strikeInterval, DAMAGE_TYPE_ALL)
			if enemiesNear ~= nil then
				if
					estimatedDamage / botTarget:GetHealth() > 0.5
					or hpRatio < 0.65 and #enemiesNear >= 2
					or #enemiesNear >= 3
				then
					return BOT_ACTION_DESIRE_HIGH
				end
			end
		end
	end
	if isRetreating then
		if
			nearbyAllies ~= nil
			and nearbyEnemies ~= nil
			and #nearbyEnemies >= #nearbyAllies
			and hpRatio < 0.5
			and hpRatio > 0.15
			and bot:WasRecentlyDamagedByAnyHero(3)
			and Fu.IsValidHero(nearbyEnemies[1])
			and Fu.IsInRange(bot, nearbyEnemies[1], radius)
			and not Fu.IsSuspiciousIllusion(nearbyEnemies[1])
			and not nearbyEnemies[1]:HasModifier("modifier_abaddon_borrowed_time")
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsInLaningPhase() and mpRatio < 0.3 then
		return BOT_ACTION_DESIRE_NONE
	end
	if Fu.IsInTeamFight(bot, 1200) and hpRatio < 0.6 then
		local aoeLocation = Fu.GetAoeEnemyHeroLocation(bot, 0, radius, 2)
		if aoeLocation ~= nil then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if
			Fu.IsRoshan(botTarget)
			and Fu.CanBeAttacked(botTarget)
			and Fu.IsInRange(bot, botTarget, radius)
			and hpRatio < 0.55
			and isAttacking
			and nearbyEnemies ~= nil
			and #nearbyEnemies == 0
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderKazuraiKatana()
	if not Fu.CanCastAbility(kazuraiKatanaAbility) then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	-- katana_attack_range lives on Switch Discipline (o), not on Kazurai Katana (game KV), so the old
	-- lookup read 0 and the impale was never cast.
	local katanaAttackRange = switchDisciplineAbility:GetSpecialValueInt("katana_attack_range")
	local katanaBonusDamage = kazuraiKatanaAbility:GetSpecialValueInt("katana_bonus_damage") / 100
	-- The impale bursts bleed_as_rupture_pct (50%) of the target's Katana stacks at once (datafeed:
	-- "STACKS AS BURST DAMAGE"; shard +50). Modifier name and "1 stack = 1 damage" are inherited from the
	-- old code and not verified.
	local burstPct = kazuraiKatanaAbility:GetSpecialValueInt("bleed_as_rupture_pct") / 100
	if burstPct <= 0 then
		burstPct = 0.5
	end
	-- Game 037: no impale-kill / impale-burst at all. "modifier_kez_katana_bleed" is not in the game
	-- data (modifier names are not in the KV files), so it cannot be confirmed: every 10s, list the
	-- modifiers on the hero Kez is hitting in Katana stance, to find the real bleed name and count.
	if
		bot.kez_mode == "katana"
		and Fu.IsValidHero(botTarget)
		and Fu.IsInRange(bot, botTarget, katanaAttackRange + 100)
		and DotaTime() >= (bot._kezBleedModLogAt or -999)
	then
		bot._kezBleedModLogAt = DotaTime() + 10
		local mods = {}
		for i = 0, botTarget:NumModifiers() - 1 do
			mods[#mods + 1] = tostring(botTarget:GetModifierName(i))
				.. "x"
				.. tostring(botTarget:GetModifierStackCount(i))
		end
		pcall(
			print,
			string.format(
				"[OHA-KEZ] t=%.0f impale-check target=%s stacks(katana_bleed)=%d mods=%s",
				DotaTime(),
				(string.gsub(botTarget:GetUnitName(), "npc_dota_hero_", "")),
				Fu.GetModifierCount(botTarget, "modifier_kez_katana_bleed"),
				table.concat(mods, ",")
			)
		)
	end
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.IsInRange(bot, enemyHero, katanaAttackRange)
			and Fu.CanCastOnTargetAdvanced(enemyHero)
		then
			if enemyHero:IsChanneling() then
				return BOT_ACTION_DESIRE_HIGH, enemyHero
			end
			-- The Katana bleed is a debuff on the enemy (datafeed: "applies stacking damage over time to
			-- enemies"); the stacks were read from Kez himself, so this kill check never passed.
			local burstDamage = Fu.GetModifierCount(enemyHero, "modifier_kez_katana_bleed") * burstPct
			if
				Fu.CanKillTarget(enemyHero, burstDamage, DAMAGE_TYPE_PHYSICAL)
				and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
				and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
				and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
				and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
				and not enemyHero:HasModifier("modifier_troll_warlord_battle_trance")
				and not enemyHero:HasModifier("modifier_ursa_enrage")
			then
				X.LogKez("impale-kill target=" .. enemyHero:GetUnitName() .. " burst=" .. math.floor(burstDamage))
				return BOT_ACTION_DESIRE_HIGH, enemyHero
			end
		end
	end
	if isGoingOnSomeone then
		if
			Fu.IsValidHero(botTarget)
			and Fu.IsInRange(bot, botTarget, katanaAttackRange)
			and Fu.CanCastOnTargetAdvanced(botTarget)
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
			and not botTarget:HasModifier("modifier_troll_warlord_battle_trance")
			and not botTarget:HasModifier("modifier_ursa_enrage")
		then
			-- Stacks are on the target and the burst is measured against the target's HP (it used Kez's
			-- own stacks and Kez's own HP).
			local burstDamage = Fu.GetModifierCount(botTarget, "modifier_kez_katana_bleed") * burstPct
			if
				burstDamage / botTarget:GetHealth() > RemapValClamped(kazuraiKatanaAbility:GetLevel(), 2, 4, 0.1, 0.25)
			then
				X.LogKez("impale-burst target=" .. botTarget:GetUnitName() .. " burst=" .. math.floor(burstDamage))
				return BOT_ACTION_DESIRE_HIGH, botTarget
			end
			if burstDamage > RemapValClamped(kazuraiKatanaAbility:GetLevel(), 2, 4, 75, 300) then
				return BOT_ACTION_DESIRE_HIGH, botTarget
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function X.ConsiderFalconRush()
	if not Fu.CanCastAbility(falconRushAbility) then
		return BOT_ACTION_DESIRE_NONE
	end
	local rushRange = falconRushAbility:GetSpecialValueInt("rush_range") - 50
	local manaAfter = Fu.GetManaAfter(falconRushAbility:GetManaCost())
	local attackRange = bot:GetAttackRange()
	if isGoingOnSomeone then
		if
			Fu.IsValidHero(botTarget)
			and Fu.CanBeAttacked(botTarget)
			and Fu.IsInRange(bot, botTarget, rushRange)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not Fu.IsEnemyBlackHoleInLocation(botTarget:GetLocation())
			and not Fu.IsEnemyChronosphereInLocation(botTarget:GetLocation())
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
			and not botTarget:HasModifier("modifier_troll_warlord_battle_trance")
		then
			if Fu.IsInLaningPhase() then
				if Fu.GetHP(botTarget) < 0.4 and #enemyTowers <= 0 then
					return BOT_ACTION_DESIRE_HIGH
				end
				return BOT_ACTION_DESIRE_NONE
			end
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsFarming(bot) and not Fu.IsThereNonSelfCoreNearby(1200) and manaAfter > 0.4 then
		local creeps = bot:GetNearbyCreeps(attackRange, true)
		if #creeps >= 2 then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsPushing(bot) and manaAfter > 0.3 then
		if
			Fu.IsValidBuilding(botTarget)
			and Fu.CanBeAttacked(botTarget)
			and Fu.IsInRange(bot, botTarget, bot:GetAttackRange() + 300)
			and isAttacking
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if
			Fu.IsRoshan(botTarget)
			and Fu.CanBeAttacked(botTarget)
			and Fu.IsInRange(bot, botTarget, 500)
			and isAttacking
			and manaAfter > 0.25
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, 500) and isAttacking and manaAfter > 0.25 then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderTalonToss()
	if not Fu.CanCastAbility(talonTossAbility) then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castRange = Fu.GetProperCastRange(false, bot, talonTossAbility:GetCastRange())
	local radius = talonTossAbility:GetSpecialValueInt("radius")
	local damage = talonTossAbility:GetSpecialValueInt("damage")
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and Fu.CanCastOnTargetAdvanced(enemyHero)
			and Fu.IsInRange(bot, enemyHero, castRange)
			-- datafeed: Talon Toss is a fixed-damage attack, physical damage.
			and Fu.CanKillTarget(enemyHero, damage, DAMAGE_TYPE_PHYSICAL)
			and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
			and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
			and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
			and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
			and not enemyHero:HasModifier("modifier_troll_warlord_battle_trance")
		then
			return BOT_ACTION_DESIRE_HIGH, enemyHero
		end
	end
	-- Talon Toss "radius" is 0 now (game KV), so the old team-fight branch (2+ enemies within radius of
	-- the target) never fired, and it overwrote the shared enemy list U. Use the silence to cut a
	-- channel instead, which nothing else in Sai stance did.
	local enemiesNear = Fu.GetEnemiesNearLoc(bot:GetLocation(), castRange)
	for _, enemyHero in pairs(enemiesNear) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and Fu.CanCastOnTargetAdvanced(enemyHero)
			and Fu.IsInRange(bot, enemyHero, castRange)
			and enemyHero:IsChanneling()
		then
			X.LogKez("toss-channel target=" .. enemyHero:GetUnitName())
			return BOT_ACTION_DESIRE_HIGH, enemyHero
		end
	end
	if isGoingOnSomeone then
		if
			Fu.IsValidHero(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.CanCastOnTargetAdvanced(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and not Fu.IsDisabled(botTarget)
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
			and not botTarget:HasModifier("modifier_troll_warlord_battle_trance")
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end
	if Fu.IsLaning(bot) and Fu.GetManaAfter(talonTossAbility:GetManaCost()) > 0.3 then
		local laneCreeps = bot:GetNearbyLaneCreeps(castRange, true)
		for _, creep in pairs(laneCreeps) do
			if
				Fu.IsValid(creep)
				and Fu.CanBeAttacked(creep)
				and not Fu.IsInRange(bot, creep, bot:GetAttackRange() * 2.5)
				and Fu.IsKeyWordUnit("ranged", creep)
				-- datafeed: Talon Toss deals physical damage.
				and Fu.CanKillTarget(creep, damage, DAMAGE_TYPE_PHYSICAL)
			then
				if
					Fu.IsValidHero(nearbyEnemies[1])
					and not Fu.IsSuspiciousIllusion(nearbyEnemies[1])
					and Fu.IsInRange(creep, nearbyEnemies[1], 550)
				then
					return BOT_ACTION_DESIRE_HIGH, creep
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function X.ConsiderShodoSai()
	if not Fu.CanCastAbility(shodoSaiAbility) then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	if isRetreating and not Fu.IsRealInvisible(bot) then
		local alliesNear = Fu.GetAlliesNearLoc(bot:GetLocation(), 900)
		if #alliesNear >= 1 then
			local chaserCount = 0
			local parryLocation = nil
			local enemyHeroes = bot:GetNearbyHeroes(1200, true, BOT_MODE_NONE)
			for _, enemyHero in pairs(enemyHeroes) do
				-- No facing test: the parry is point-targeted and locks Kez's facing toward the point
				-- (datafeed), and a retreating Kez faces away from his chasers, so it almost never passed.
				if
					Fu.IsValidHero(enemyHero)
					and Fu.CanCastOnMagicImmune(enemyHero)
					and (enemyHero:GetAttackTarget() == bot or Fu.IsChasingTarget(enemyHero, bot))
					and not Fu.IsDisabled(enemyHero)
				then
					chaserCount = chaserCount + 1
					parryLocation = parryLocation or enemyHero:GetLocation()
				end
			end
			-- Parry toward the attacker that was counted (it used ax[1], which may be someone else).
			if chaserCount >= 1 and #enemyHeroes > #alliesNear and parryLocation ~= nil then
				X.LogKez("parry-retreat")
				return BOT_ACTION_DESIRE_HIGH, parryLocation
			end
		end
	end
	-- Fight use (was missing): a hero right-clicking Kez in melee range gets parried, stunned and Marked.
	if isGoingOnSomeone and not Fu.IsRealInvisible(bot) then
		local enemyHeroes = bot:GetNearbyHeroes(400, true, BOT_MODE_NONE)
		for _, enemyHero in pairs(enemyHeroes) do
			if
				Fu.IsValidHero(enemyHero)
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and enemyHero:GetAttackTarget() == bot
				and Fu.IsAttacking(enemyHero)
				and not Fu.IsDisabled(enemyHero)
			then
				X.LogKez("parry-fight attacker=" .. enemyHero:GetUnitName())
				return BOT_ACTION_DESIRE_HIGH, enemyHero:GetLocation()
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.ConsiderShodoSaiCancel()
	if not Fu.CanCastAbility(shodoSaiCancelAbility) then
		return BOT_ACTION_DESIRE_NONE
	end
	if isRetreating and not Fu.IsRealInvisible(bot) then
		local alliesNear = Fu.GetAlliesNearLoc(bot:GetLocation(), 900)
		if #alliesNear >= 1 then
			local threatCount = 0
			local enemyHeroes = bot:GetNearbyHeroes(1200, true, BOT_MODE_NONE)
			for _, enemyHero in pairs(enemyHeroes) do
				if
					Fu.IsValidHero(enemyHero)
					and Fu.CanCastOnMagicImmune(enemyHero)
					and bot:IsFacingLocation(enemyHero:GetLocation(), 15)
					and not Fu.IsDisabled(enemyHero)
				then
					threatCount = threatCount + 1
				end
			end
			if threatCount < 1 and #enemyHeroes < #alliesNear then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderRavensVeil()
	if not Fu.CanCastAbility(ravensVeilAbility) then
		return BOT_ACTION_DESIRE_NONE
	end
	local blastRadius = ravensVeilAbility:GetSpecialValueInt("blast_radius")
	-- Escape use (was missing): Raven's Veil gives a basic dispel, bonus move speed and invisibility
	-- (datafeed), so cast it when chased and hurt while retreating.
	if isRetreating and not Fu.IsRealInvisible(bot) and bot:WasRecentlyDamagedByAnyHero(2.0) and hpRatio < 0.5 then
		local enemiesNear = Fu.GetEnemiesNearLoc(bot:GetLocation(), 900)
		if #enemiesNear >= 1 then
			X.LogKez("veil-escape enemies=" .. #enemiesNear .. " hp=" .. string.format("%.2f", hpRatio))
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsInTeamFight(bot, 1200) then
		local enemiesNear = Fu.GetEnemiesNearLoc(bot:GetLocation(), blastRadius * 0.6)
		if Fu.IsLateGame() and #enemiesNear >= 3 or not Fu.IsLateGame() and #enemiesNear >= 2 then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderSwitchDiscipline()
	if not Fu.CanCastAbility(switchDisciplineAbility) then
		return BOT_ACTION_DESIRE_NONE
	end
	if bot:GetAbilityPoints() > 0 then
		return BOT_ACTION_DESIRE_NONE
	end
	if isGoingOnSomeone then
		if
			Fu.IsValidHero(botTarget)
			and Fu.IsInRange(bot, botTarget, 1200)
			and Fu.GetMP(bot) > 0.25
			and bot.kez_mode == "katana"
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if isRetreating and not Fu.IsRealInvisible(bot) then
		if bot.kez_mode == "sai" then
			if Fu.CanCastAbility(talonTossAbility) or not bot:WasRecentlyDamagedByAnyHero(2) then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	if Fu.IsLaning(bot) or Fu.IsPushing(bot) then
		if bot.kez_mode == "sai" then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsFarming(bot) or Fu.IsDoingRoshan(bot) or Fu.IsDoingTormentor(bot) then
		if bot.kez_mode == "katana" then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.DoCombo()
	if bot.kez_mode == "sai" then
		if bot:HasScepter() and not Fu.CanCastAbility(falconRushAbility) then
			if Fu.CanCastAbility(ravensVeilAbility) and not bot:IsRooted() then
				local switchManaCost = 0
				local veilManaCost = ravensVeilAbility:GetManaCost()
				local clawManaCost = 50
				local echoSlashManaCost = 85
				if Fu.GetManaAfter(switchManaCost + veilManaCost + clawManaCost + echoSlashManaCost) > 0.1 then
					local clawRange = 700 + 100 * (talonTossAbility:GetLevel() - 1)
					local comboTarget = nil
					local highestThreat = 0
					local enemiesNear = Fu.GetEnemiesNearLoc(bot:GetLocation(), clawRange)
					for _, enemyHero in pairs(enemiesNear) do
						if isGoingOnSomeone then
							if
								Fu.IsValidHero(enemyHero)
								and Fu.IsInRange(bot, enemyHero, clawRange)
								and Fu.CanBeAttacked(enemyHero)
								and Fu.CanCastOnTargetAdvanced(enemyHero)
								and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
								and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
								and not enemyHero:HasModifier("modifier_enigma_black_hole_pull")
								and not enemyHero:HasModifier("modifier_faceless_void_chronosphere_freeze")
								and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
								and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
								and not enemyHero:HasModifier("modifier_troll_warlord_battle_trance")
								and not enemyHero:HasModifier("modifier_ursa_enrage")
							then
								local targetEnemies = enemyHero:GetNearbyHeroes(1200, true, BOT_MODE_NONE)
								local targetAllies = enemyHero:GetNearbyHeroes(1200, false, BOT_MODE_NONE)
								local threat = enemyHero:GetAttackDamage() * enemyHero:GetAttackSpeed()
									+ enemyHero:GetEstimatedDamageToTarget(false, bot, 4.0, DAMAGE_TYPE_ALL)
								if
									threat > highestThreat
									and #targetEnemies >= #targetAllies
									and #targetEnemies < #targetAllies + 2
								then
									comboTarget = enemyHero
									highestThreat = threat
								end
							end
						end
					end
					if Fu.IsValidHero(comboTarget) then
						local distance = GetUnitToUnitDistance(bot, comboTarget)
						local travelDelay = distance / 1800 + distance / 3000
						bot:Action_ClearActions(false)
						bot:ActionQueue_UseAbility(ravensVeilAbility)
						bot:ActionQueue_Delay(0.3)
						bot:ActionQueue_UseAbility(switchDisciplineAbility)
						bot:ActionQueue_UseAbilityOnEntity(grapplingClawAbility, comboTarget)
						bot:ActionQueue_Delay(travelDelay)
						bot:ActionQueue_UseAbility(echoSlashAbility)
						X.LogKez("scepter-combo target=" .. comboTarget:GetUnitName())
						return true
					end
				end
			end
		end
	end
end
function X.GetBestGrapplingTargetTowardsLocation(castRange, targetLocation)
	local trees = bot:GetNearbyTrees(math.min(castRange, 1600))
	local botLocation = bot:GetLocation()
	local direction = (targetLocation - botLocation):Normalized()
	local minDistance = castRange * 0.5
	local maxAngle = 45
	local bestTarget = nil
	local bestDistance = 0
	for i = #trees, 1, -1 do
		if trees[i] then
			local treeLocation = GetTreeLocation(trees[i])
			local treeDirection = (treeLocation - botLocation):Normalized()
			local dot = Fu.DotProduct(direction, treeDirection)
			if dot >= math.cos(math.rad(maxAngle)) then
				local distance = GetUnitToLocationDistance(bot, treeLocation)
				if distance > minDistance then
					local botToTargetDistance = GetUnitToLocationDistance(bot, targetLocation)
					local treeToTargetDistance = Fu.GetDistance(treeLocation, targetLocation)
					if treeToTargetDistance < botToTargetDistance and distance > bestDistance then
						bestTarget = trees[i]
						bestDistance = distance
					end
				end
			end
		end
	end
	if bestTarget ~= nil then
		return bestTarget, "tree"
	end
	local creeps = bot:GetNearbyCreeps(math.min(castRange, 1600), true)
	bestTarget = nil
	bestDistance = 0
	for i = #creeps, 1, -1 do
		if Fu.IsValid(creeps[i]) and Fu.CanCastOnTargetAdvanced(creeps[i]) then
			local creepLocation = creeps[i]:GetLocation()
			local creepDirection = (creepLocation - botLocation):Normalized()
			local dot = Fu.DotProduct(direction, creepDirection)
			if dot >= math.cos(math.rad(maxAngle)) then
				local distance = GetUnitToUnitDistance(bot, creeps[i])
				if distance > minDistance then
					local botToTargetDistance = GetUnitToLocationDistance(bot, targetLocation)
					local creepToTargetDistance = GetUnitToLocationDistance(creeps[i], targetLocation)
					if creepToTargetDistance < botToTargetDistance and distance > bestDistance then
						bestTarget = creeps[i]
						bestDistance = distance
					end
				end
			end
		end
	end
	if bestTarget ~= nil then
		return bestTarget, "unit"
	end
	return nil, ""
end
function X.GetBestRetreatGrapplingTarget(castRange)
	local trees = bot:GetNearbyTrees(math.min(castRange, 1600))
	local bestTree = nil
	local bestTreeDistance = 0
	local bestTreeFountainDistance = 100000
	local fountainLocation = Fu.GetTeamFountain()
	local botLocation = bot:GetLocation()
	local fountainDirection = (fountainLocation - botLocation):Normalized()
	for i = #trees, 1, -1 do
		if trees[i] then
			local treeLocation = GetTreeLocation(trees[i])
			local distance = GetUnitToLocationDistance(bot, treeLocation)
			local fountainDistance = Fu.GetDistance(fountainLocation, treeLocation)
			local direction = (treeLocation - botLocation):Normalized()
			local dot = Fu.DotProduct(direction, fountainDirection)
			-- math.cos takes radians: cos(45) is a 58-degree cone, not the intended 45.
			if
				dot >= math.cos(math.rad(45))
				and distance > bestTreeDistance
				and fountainDistance < bestTreeFountainDistance
			then
				bestTreeDistance = distance
				bestTreeFountainDistance = fountainDistance
				bestTree = trees[i]
			end
		end
	end
	if bestTree ~= nil and bestTreeDistance > castRange * 0.4 then
		return bestTree, "tree"
	end
	local bestCreep = nil
	local bestCreepDistance = 0
	local bestCreepFountainDistance = 100000
	local creeps = bot:GetNearbyCreeps(castRange, true)
	for i = #creeps, 1, -1 do
		-- Was aX[1] (the first creep) for every creep: each candidate must itself be far enough away.
		if Fu.IsValid(creeps[i]) and not Fu.IsInRange(bot, creeps[i], castRange * 0.4) then
			local creepLocation = creeps[i]:GetLocation()
			local distance = GetUnitToLocationDistance(bot, creepLocation)
			local fountainDistance = Fu.GetDistance(fountainLocation, creepLocation)
			local direction = (creepLocation - botLocation):Normalized()
			local dot = Fu.DotProduct(direction, fountainDirection)
			if
				dot >= math.cos(math.rad(45))
				and distance > bestCreepDistance
				and fountainDistance < bestCreepFountainDistance
			then
				bestCreepDistance = distance
				bestCreepFountainDistance = fountainDistance
				bestCreep = creeps[i]
			end
		end
	end
	if bestCreep ~= nil then
		return bestCreep, "unit"
	end
	return nil, ""
end
return X
