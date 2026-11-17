-- Obsidian Destroyer: skill build, item build, and ability use for this hero.
local X = {}
local bot = GetBot()
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local Minion = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local sTalentList = Fu.Skill.GetTalentList(bot)
local sAbilityList = Fu.Skill.GetAbilityList(bot)
local sRole = Fu.Item.GetRoleItemsBuyList(bot)
local tTalentTreeList = { { ["t25"] = { 0, 10 }, ["t20"] = { 10, 0 }, ["t15"] = { 10, 0 }, ["t10"] = { 10, 0 } } }
local tAllAbilityBuildList =
	{ { 2, 1, 3, 2, 2, 6, 2, 1, 1, 1, 6, 3, 3, 3, 6 }, { 2, 1, 3, 2, 2, 6, 2, 1, 1, 1, 6, 3, 3, 3, 6 } }
local nAbilityBuildList
local nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList[1])
if sRole == "pos_1" then
	nAbilityBuildList = tAllAbilityBuildList[1]
else
	nAbilityBuildList = tAllAbilityBuildList[2]
end
local sRoleItemsBuyList = {}
sRoleItemsBuyList["pos_1"] = {
	"item_tango",
	"item_double_branches",
	"item_faerie_fire",
	"item_double_circlet",
	"item_magic_wand",
	"item_double_null_talisman",
	"item_power_treads",
	-- Kaya, then Meteor Hammer (user call): timed to land as Astral Imprisonment ends.
	"item_kaya",
	"item_meteor_hammer",
	"item_witch_blade",
	-- Blink Dagger: #2 by matches played (Dotabuff, last patch). Force Staff still comes as part of Pike.
	"item_blink",
	"item_hurricane_pike",
	"item_black_king_bar",
	"item_aghanims_shard",
	"item_devastator",
	"item_sheepstick",
	"item_shivas_guard",
	"item_moon_shard",
	"item_ultimate_scepter_2",
	"item_travel_boots_2",
}
sRoleItemsBuyList["pos_2"] = {
	"item_tango",
	"item_double_branches",
	"item_faerie_fire",
	"item_double_mantle",
	"item_magic_wand",
	"item_double_null_talisman",
	"item_power_treads",
	-- Kaya, then Meteor Hammer (user call): timed to land as Astral Imprisonment ends.
	"item_kaya",
	"item_meteor_hammer",
	"item_witch_blade",
	-- Blink Dagger: #2 by matches played (Dotabuff, last patch). Force Staff still comes as part of Pike.
	"item_blink",
	"item_hurricane_pike",
	"item_black_king_bar",
	"item_aghanims_shard",
	"item_devastator",
	"item_sheepstick",
	"item_shivas_guard",
	"item_moon_shard",
	"item_ultimate_scepter_2",
	"item_travel_boots_2",
}
sRoleItemsBuyList["pos_3"] = sRoleItemsBuyList["pos_2"]
sRoleItemsBuyList["pos_4"] = sRoleItemsBuyList["pos_2"]
sRoleItemsBuyList["pos_5"] = sRoleItemsBuyList["pos_2"]
X["sBuyList"] = sRoleItemsBuyList[sRole]
-- fix: pairs are { owned, sold }; they were reversed (owning a Magic Wand sold the Black King Bar,
-- owning a Null Talisman sold Scythe of Vyse / Shiva's Guard)
X["sSellList"] = {
	"item_black_king_bar",
	"item_magic_wand",
	"item_sheepstick",
	"item_null_talisman",
	"item_shivas_guard",
	"item_null_talisman",
}
if Fu.Role.IsPvNMode() or Fu.Role.IsAllShadow() then
	X["sBuyList"], X["sSellList"] = { "PvN_mid" }, {}
end
nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"] =
	Fu.SetUserHeroInit(nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"])
X["sSkillList"] = Fu.Skill.GetSkillList(sAbilityList, nAbilityBuildList, sTalentList, nTalentBuildList)
X["bDeafaultAbility"] = false
X["bDeafaultItem"] = false
function X.MinionThink(hMinionUnit)
	if Minion.IsValidUnit(hMinionUnit) then
		Minion.IllusionThink(hMinionUnit)
	end
end
local arcaneOrbAbility = SafeAbility(
	bot:GetAbilityByName("obsidian_destroyer_arcane_orb"),
	"obsidian_destroyer_arcane_orb",
	"obsidian_destroyer"
)
local astralImprisonmentAbility = SafeAbility(
	bot:GetAbilityByName("obsidian_destroyer_astral_imprisonment"),
	"obsidian_destroyer_astral_imprisonment",
	"obsidian_destroyer"
)
local objurgationAbility = SafeAbility(
	bot:GetAbilityByName("obsidian_destroyer_objurgation"),
	"obsidian_destroyer_objurgation",
	"obsidian_destroyer"
)
local sanityEclipseAbility = SafeAbility(
	bot:GetAbilityByName("obsidian_destroyer_sanity_eclipse"),
	"obsidian_destroyer_sanity_eclipse",
	"obsidian_destroyer"
)
local arcaneOrbDesire, arcaneOrbTarget
local astralImprisonmentDesire, astralImprisonmentTarget
local sanityEclipseDesire, sanityEclipseLocation
local objurgationDesire
local isAttacking = false
local botTarget, hpRatio
local nearbyAllies, nearbyEnemies
-- Astral Imprisonment then Meteor Hammer. Valve data: the prison lasts 1.75/2.5/3.25/4s (the
-- prisoner is invulnerable), Meteor Hammer channels 2s and lands 0.5s later (600 range, 400
-- radius, 0.75s stun). So the channel starts when the prison has 2.5s left, on the prison spot,
-- and the meteor lands as the target comes out.
local PRISON_DURATION = { 1.75, 2.5, 3.25, 4 }
-- Lands 0.15s after the prisoner comes out (game 032, 21:50: landed while he was still inside).
local HAMMER_LEAD = 2.35
function X.NotePrison(target)
	if not Fu.IsValidHero(target) or target:GetTeam() == GetTeam() then
		return
	end
	local lvl = math.max(1, math.min(4, astralImprisonmentAbility:GetLevel()))
	local dur = PRISON_DURATION[lvl]
	local okD, specialDuration = pcall(function()
		return astralImprisonmentAbility:GetSpecialValueFloat("prison_duration")
	end)
	if okD and type(specialDuration) == "number" and specialDuration > 0 then
		dur = specialDuration
	end
	local cast = math.max(0, astralImprisonmentAbility:GetCastPoint())
	-- endAt is provisional: the order can wait for a turn or a walk into range. It is set again
	-- when Astral Imprisonment goes on cooldown (the cast itself).
	bot._prison = {
		target = target,
		loc = target:GetLocation(),
		castAt = DotaTime(),
		dur = dur,
		confirmed = false,
		endAt = DotaTime() + cast + dur,
	}
end
function X.ConsiderPrisonHammer()
	local st = bot._prison
	if st == nil then
		return false
	end
	local now = DotaTime()
	if not st.confirmed then
		if astralImprisonmentAbility:GetCooldownTimeRemaining() > 0 then
			st.confirmed = true
			st.confirmedAt = now
			st.endAt = now + st.dur
		elseif now - st.castAt > 2 then
			-- Ordered but never cast.
			bot._prison = nil
		end
		return false
	end
	-- The prison did not land: the target is still there and can be hurt.
	if
		now - st.confirmedAt > 0.4
		and Fu.IsValidHero(st.target)
		and st.target:CanBeSeen()
		and not st.target:IsInvulnerable()
		and now < st.endAt - 0.3
	then
		bot._prison = nil
		return false
	end
	if now > st.endAt + 0.3 then
		bot._prison = nil
		return false
	end
	local slot = bot:FindItemSlot("item_meteor_hammer")
	if slot < 0 or slot > 5 then
		return false
	end
	local hammer = bot:GetItemInSlot(slot)
	if hammer == nil or not hammer:IsFullyCastable() then
		return false
	end
	local left = st.endAt - now
	local dist = GetUnitToLocationDistance(bot, st.loc)
	-- Meteor Hammer is a 400-radius area (user note): aimed at a point inside its 600 range toward
	-- the prison spot, it still covers the prisoner up to ~980 away, so no step at all (Astral
	-- Imprisonment is cast from up to 650).
	local aim = st.loc
	if dist > 580 then
		aim = bot:GetLocation() + (st.loc - bot:GetLocation()):Normalized() * 580
	end
	if left <= HAMMER_LEAD + 0.05 then
		if dist <= 580 + 380 then
			bot._prison = nil
			pcall(
				print,
				string.format(
					"[OHA-OD] t=%.1f prison-hammer target=%s left=%.2f dist=%d",
					now,
					Fu.IsValidHero(st.target) and (string.gsub(st.target:GetUnitName(), "npc_dota_hero_", "")) or "?",
					left,
					math.floor(dist)
				)
			)
			bot:Action_UseAbilityOnLocation(hammer, aim)
			return true
		end
		return false
	end
	return false
end
-- Items still work while silenced (game 021, 24:30: OD imprisoned Mirana, was silenced by
-- Static Storm, and the hammer check, behind the "cannot use abilities" gate, never ran).
local function CanUseItemsNow()
	if not bot:IsAlive() or bot:IsStunned() or bot:IsHexed() or bot:IsChanneling() or bot:IsNightmared() then
		return false
	end
	local okM, muted = pcall(function()
		return bot:IsMuted()
	end)
	return not (okM and muted)
end
function X.SkillsComplement()
	bot = GetBot()
	if bot._prison ~= nil and CanUseItemsNow() and X.ConsiderPrisonHammer() then
		return
	end
	if Fu.CanNotUseAbility(bot) then
		return
	end
	arcaneOrbAbility = SafeAbility(
		bot:GetAbilityByName("obsidian_destroyer_arcane_orb"),
		"obsidian_destroyer_arcane_orb",
		"obsidian_destroyer"
	)
	astralImprisonmentAbility = SafeAbility(
		bot:GetAbilityByName("obsidian_destroyer_astral_imprisonment"),
		"obsidian_destroyer_astral_imprisonment",
		"obsidian_destroyer"
	)
	objurgationAbility = SafeAbility(
		bot:GetAbilityByName("obsidian_destroyer_objurgation"),
		"obsidian_destroyer_objurgation",
		"obsidian_destroyer"
	)
	sanityEclipseAbility = SafeAbility(
		bot:GetAbilityByName("obsidian_destroyer_sanity_eclipse"),
		"obsidian_destroyer_sanity_eclipse",
		"obsidian_destroyer"
	)
	isAttacking = Fu.IsAttacking(bot)
	hpRatio = Fu.GetHP(bot)
	botTarget = Fu.GetProperTarget(bot)
	nearbyAllies = bot:GetNearbyHeroes(1600, false, BOT_MODE_NONE)
	nearbyEnemies = bot:GetNearbyHeroes(1600, true, BOT_MODE_NONE)
	objurgationDesire = X.ConsiderObjurgation()
	if objurgationDesire > 0 then
		Fu.SetQueuePtToINT(bot, false)
		bot:ActionQueue_UseAbility(objurgationAbility)
		return
	end
	sanityEclipseDesire, sanityEclipseLocation = X.ConsiderSanitysEclipse()
	if sanityEclipseDesire > 0 then
		Fu.SetQueuePtToINT(bot, false)
		bot:ActionQueue_UseAbilityOnLocation(sanityEclipseAbility, sanityEclipseLocation)
		return
	end
	if X.ConsiderPrisonHammer() then
		return
	end
	astralImprisonmentDesire, astralImprisonmentTarget = X.ConsiderAstralImprisonment()
	if astralImprisonmentDesire > 0 then
		Fu.SetQueuePtToINT(bot, false)
		bot:ActionQueue_UseAbilityOnEntity(astralImprisonmentAbility, astralImprisonmentTarget)
		pcall(X.NotePrison, astralImprisonmentTarget)
		return
	end
	arcaneOrbDesire, arcaneOrbTarget = X.ConsiderArcaneOrb()
	if arcaneOrbDesire > 0 then
		bot:Action_UseAbilityOnEntity(arcaneOrbAbility, arcaneOrbTarget)
		return
	end
end
function X.ConsiderArcaneOrb()
	if not arcaneOrbAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local attackRange = bot:GetAttackRange()
	local manaPoolDamagePct = arcaneOrbAbility:GetSpecialValueInt("mana_pool_damage_pct") / 100
	local totalDamage = bot:GetAttackDamage() + bot:GetMana() * manaPoolDamagePct
	-- datafeed: Arcane Orb's bonus is pure (damage 4); the attack itself is physical
	local orbPhys, orbPure = bot:GetAttackDamage(), bot:GetMana() * manaPoolDamagePct
	local abilityLevel = arcaneOrbAbility:GetLevel()
	local isAutoCast = arcaneOrbAbility:GetAutoCastState()
	local manaCost = arcaneOrbAbility:GetManaCost()
	local manaAfter = Fu.GetManaAfter(manaCost)
	local manaThreshold =
		Fu.GetManaThreshold(bot, manaCost, { astralImprisonmentAbility, objurgationAbility, sanityEclipseAbility })
	if abilityLevel == 4 and not isAutoCast then
		arcaneOrbAbility:ToggleAutoCast()
	end
	if isAutoCast then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanBeAttacked(enemyHero)
			and Fu.IsInRange(bot, enemyHero, attackRange + 300)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
		then
			local travelTime = GetUnitToUnitDistance(bot, enemyHero) / bot:GetAttackProjectileSpeed()
			if
				Fu.WillMixedDamageKillTarget(enemyHero, orbPhys, 0, orbPure, travelTime)
				and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
				and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
				and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
				and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
				and not enemyHero:HasModifier("modifier_templar_assassin_refraction_absorb")
			then
				return BOT_ACTION_DESIRE_HIGH, enemyHero
			end
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidHero(botTarget)
			and Fu.CanBeAttacked(botTarget)
			and Fu.IsInRange(bot, botTarget, attackRange + 150)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not botTarget:HasModifier("modifier_abaddon_borrowed_time")
			and not botTarget:HasModifier("modifier_dazzle_shallow_grave")
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end
	local nearbyCreeps = bot:GetNearbyCreeps(Min(attackRange + 300, 1600), true)
	if
		(Fu.IsPushing(bot) or Fu.IsDefending(bot) or Fu.IsFarming(bot))
		and isAttacking
		and manaAfter > manaThreshold + 0.1
	then
		if Fu.IsValid(botTarget) and Fu.CanBeAttacked(botTarget) and botTarget:IsCreep() then
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end
	if not Fu.IsRetreating(bot) and not Fu.IsRealInvisible(bot) then
		if Fu.IsEarlyGame() then
			for _, enemyHero in pairs(nearbyEnemies) do
				if
					Fu.IsValidHero(enemyHero)
					and Fu.CanBeAttacked(enemyHero)
					and Fu.IsInRange(bot, enemyHero, attackRange + 150)
					and Fu.CanCastOnNonMagicImmune(enemyHero)
				then
					return BOT_ACTION_DESIRE_HIGH, enemyHero
				end
			end
		end
		for _, creep in pairs(nearbyCreeps) do
			if
				Fu.IsValid(creep)
				and Fu.CanBeAttacked(creep)
				and (Fu.IsCore(bot) or not Fu.IsOtherAllysTarget(creep))
			then
				local travelTime = GetUnitToUnitDistance(bot, creep) / bot:GetAttackProjectileSpeed()
				if Fu.WillMixedDamageKillTarget(creep, orbPhys, 0, orbPure, travelTime) then
					return BOT_ACTION_DESIRE_HIGH, creep
				end
			end
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if
			Fu.IsRoshan(botTarget)
			and Fu.CanBeAttacked(botTarget)
			and Fu.IsInRange(bot, botTarget, attackRange)
			and isAttacking
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, attackRange) and isAttacking then
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function X.ConsiderAstralImprisonment()
	if not astralImprisonmentAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castRange = astralImprisonmentAbility:GetCastRange()
	local damage = astralImprisonmentAbility:GetSpecialValueInt("damage")
	-- datafeed: prison_duration is 1.75/2.5/3.25/4; GetSpecialValueInt truncated it
	local prisonDuration = astralImprisonmentAbility:GetSpecialValueFloat("prison_duration")
	local manaCost = astralImprisonmentAbility:GetManaCost()
	local manaAfter = Fu.GetManaAfter(manaCost)
	local manaThreshold = Fu.GetManaThreshold(bot, manaCost, { sanityEclipseAbility })
	-- Lethal attack projectiles on the way: prison himself whatever the hero count (the prisoner is
	-- invulnerable, datafeed). This sat behind "allies >= enemies", so he died to them when outnumbered,
	-- the case where he needs it most.
	if Fu.GetAttackProjectileDamageByRange(bot, 800) > bot:GetHealth() then
		if #nearbyAllies < #nearbyEnemies and DotaTime() >= (bot._odSelfLogAt or -999) then
			bot._odSelfLogAt = DotaTime() + 3
			pcall(
				print,
				string.format(
					"[OHA-OD] t=%.0f self-prison outnumbered allies=%d enemies=%d",
					DotaTime(),
					#nearbyAllies,
					#nearbyEnemies
				)
			)
		end
		return BOT_ACTION_DESIRE_HIGH, bot
	end
	if #nearbyAllies >= #nearbyEnemies then
		if not bot:IsMagicImmune() then
			if Fu.IsStunProjectileIncoming(bot, 600) and hpRatio < 0.2 then
				return BOT_ACTION_DESIRE_HIGH, bot
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
			and manaAfter > manaThreshold
		then
			if enemyHero:IsChanneling() then
				return BOT_ACTION_DESIRE_HIGH, enemyHero
			end
			local heroesTargetingEnemy = Fu.GetHeroesTargetingUnit(nearbyAllies, enemyHero)
			if
				Fu.CanKillTarget(enemyHero, damage, DAMAGE_TYPE_MAGICAL)
				and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
				and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
				and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
				and not enemyHero:HasModifier("modifier_templar_assassin_refraction_absorb")
				and #heroesTargetingEnemy <= 1
			then
				return BOT_ACTION_DESIRE_HIGH, enemyHero
			end
		end
	end
	if Fu.IsInTeamFight(bot, 1200) and manaAfter > manaThreshold then
		for _, allyHero in pairs(nearbyAllies) do
			if
				Fu.IsValidHero(allyHero)
				and Fu.CanBeAttacked(allyHero)
				and Fu.IsInRange(bot, allyHero, castRange + 300)
				and not allyHero:IsIllusion()
			then
				if
					allyHero:HasModifier("modifier_enigma_black_hole_pull")
					or allyHero:HasModifier("modifier_faceless_void_chronosphere_freeze")
					or allyHero:HasModifier("modifier_necrolyte_reapers_scythe")
					or allyHero:HasModifier("modifier_legion_commander_duel") and Fu.GetHP(allyHero) < 0.1
					or Fu.GetHP(allyHero) < 0.33 and Fu.IsRetreating(allyHero)
				then
					return BOT_ACTION_DESIRE_HIGH, allyHero
				end
			end
		end
		local bestTarget = nil
		local maxEstimatedDamage = 0
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.CanBeAttacked(enemyHero)
				and Fu.IsInRange(bot, enemyHero, castRange + 300)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
				and not Fu.IsDisabled(enemyHero)
			then
				if
					enemyHero:HasModifier("modifier_abaddon_borrowed_time")
					or enemyHero:HasModifier("modifier_dazzle_shallow_grave")
				then
					return BOT_ACTION_DESIRE_HIGH, enemyHero
				end
				local estimatedDamage = enemyHero:GetEstimatedDamageToTarget(false, bot, 5.0, DAMAGE_TYPE_ALL)
				local alliesDamage = Fu.GetTotalEstimatedDamageToTarget(nearbyAllies, enemyHero, 5.0)
				if estimatedDamage > maxEstimatedDamage and alliesDamage < enemyHero:GetHealth() then
					bestTarget = enemyHero
					maxEstimatedDamage = estimatedDamage
				end
			end
		end
		if bestTarget then
			return BOT_ACTION_DESIRE_HIGH, bestTarget
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidHero(botTarget)
			and Fu.CanBeAttacked(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.CanCastOnTargetAdvanced(botTarget)
			and not Fu.IsDisabled(botTarget)
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
			and not botTarget:HasModifier("modifier_templar_assassin_refraction_absorb")
			and manaAfter > manaThreshold
		then
			local alliesNearBot = Fu.GetAlliesNearLoc(bot:GetLocation(), 800)
			local enemiesNearBot = Fu.GetEnemiesNearLoc(bot:GetLocation(), 800)
			if #alliesNearBot < #enemiesNearBot + 2 then
				if #alliesNearBot <= 1 then
					return BOT_ACTION_DESIRE_HIGH, botTarget
				end
				local alliesDamageToTarget = 0
				for _, allyHero in pairs(nearbyAllies) do
					if
						Fu.IsValidHero(allyHero)
						and bot ~= allyHero
						and not allyHero:IsIllusion()
						and not allyHero:HasModifier("modifier_necrolyte_reapers_scythe")
						and not allyHero:HasModifier("modifier_teleporting")
						and (allyHero:GetAttackTarget() == botTarget or Fu.IsChasingTarget(allyHero, botTarget))
					then
						alliesDamageToTarget = alliesDamageToTarget
							+ allyHero:GetEstimatedDamageToTarget(true, botTarget, prisonDuration, DAMAGE_TYPE_ALL)
					end
				end
				if alliesDamageToTarget * 1.25 < botTarget:GetHealth() then
					return BOT_ACTION_DESIRE_HIGH, botTarget
				end
			end
		end
	end
	if Fu.IsRetreating(bot) and not Fu.IsRealInvisible(bot) then
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.CanBeAttacked(enemyHero)
				and Fu.IsInRange(bot, enemyHero, castRange)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
				and not Fu.IsDisabled(enemyHero)
				and bot:WasRecentlyDamagedByHero(enemyHero, 5.0)
			then
				return BOT_ACTION_DESIRE_HIGH, enemyHero
			end
		end
	end
	if
		not Fu.IsRetreating(bot)
		and not Fu.IsRealInvisible(bot)
		and not Fu.IsInTeamFight(bot, 1200)
		and manaAfter > manaThreshold
	then
		for _, allyHero in pairs(nearbyAllies) do
			if
				Fu.IsValidHero(allyHero)
				and bot ~= allyHero
				and Fu.IsRetreating(allyHero)
				and not allyHero:IsIllusion()
			then
				for _, enemyHero in pairs(nearbyEnemies) do
					if
						Fu.IsValidHero(enemyHero)
						and Fu.CanBeAttacked(enemyHero)
						and Fu.IsInRange(bot, enemyHero, castRange)
						and Fu.CanCastOnNonMagicImmune(enemyHero)
						and Fu.CanCastOnTargetAdvanced(enemyHero)
						and not Fu.IsDisabled(enemyHero)
						and allyHero:WasRecentlyDamagedByHero(enemyHero, 5.0)
						and Fu.IsChasingTarget(enemyHero, allyHero)
					then
						return BOT_ACTION_DESIRE_HIGH, enemyHero
					end
				end
			end
		end
	end
	if Fu.IsLaning(bot) and Fu.IsEarlyGame() and manaAfter > manaThreshold then
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.CanBeAttacked(enemyHero)
				and Fu.IsInRange(bot, enemyHero, castRange + 200)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
				and Fu.IsAttacking(enemyHero)
				and not Fu.IsDisabled(enemyHero)
			then
				local alliesNearBot = Fu.GetAlliesNearLoc(bot:GetLocation(), 800)
				local enemiesNearBot = Fu.GetEnemiesNearLoc(bot:GetLocation(), 800)
				if #alliesNearBot < #enemiesNearBot + 2 then
					return BOT_ACTION_DESIRE_HIGH, enemyHero
				end
			end
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, castRange) then
			for _, allyHero in pairs(nearbyAllies) do
				if
					Fu.IsValidHero(allyHero)
					and Fu.GetHP(allyHero) < 0.3
					and not allyHero:IsIllusion()
					and not allyHero:HasModifier("modifier_abaddon_borrowed_time")
					and not allyHero:HasModifier("modifier_dazzle_shallow_grave")
					and not allyHero:HasModifier("modifier_templar_assassin_refraction_absorb")
				then
					return BOT_ACTION_DESIRE_HIGH, allyHero
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function X.ConsiderSanitysEclipse()
	if not sanityEclipseAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local castRange = sanityEclipseAbility:GetCastRange()
	local castPoint = sanityEclipseAbility:GetCastPoint()
	local damageMultiplier = sanityEclipseAbility:GetSpecialValueFloat("damage_multiplier")
	local baseDamage = sanityEclipseAbility:GetSpecialValueFloat("base_damage")
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanBeAttacked(enemyHero)
			and Fu.IsInRange(bot, enemyHero, castRange + 300)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
			and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
			and not enemyHero:HasModifier("modifier_enigma_black_hole_pull")
			and not enemyHero:HasModifier("modifier_faceless_void_chronosphere_freeze")
			and not enemyHero:HasModifier("modifier_legion_commander_duel")
			and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
			and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
		then
			local delay = GetUnitToUnitDistance(bot, enemyHero) / bot:GetCurrentMovementSpeed() + castPoint
			-- datafeed: damage uses the difference in MAX mana (OD's minus the target's), not current mana
			local maxManaDifference = math.max(0, bot:GetMaxMana() - enemyHero:GetMaxMana())
			local bonusDamage = maxManaDifference * damageMultiplier
			if Fu.WillKillTarget(enemyHero, baseDamage + bonusDamage, DAMAGE_TYPE_MAGICAL, delay) then
				return BOT_ACTION_DESIRE_HIGH, enemyHero:GetLocation()
			end
		end
	end
	-- Team fight: it was cast only for a kill, so a 3-hero Eclipse never went out. A spot in cast range
	-- (700) where 3+ enemy heroes in the radius (500/525/550, game data) each take at least 40% of their
	-- current HP: base_damage + 0.4 x (OD max mana - their max mana), magical (datafeed).
	if Fu.IsInTeamFight(bot, 1200) then
		local rad = sanityEclipseAbility:GetSpecialValueInt("radius")
		if rad <= 0 then
			rad = 500
		end
		local aoe = bot:FindAoELocation(true, true, bot:GetLocation(), castRange, rad - 50, castPoint, 0)
		if aoe ~= nil and aoe.count ~= nil and aoe.count >= 3 and aoe.targetloc ~= nil then
			local hit = 0
			for _, enemyHero in pairs(Fu.GetEnemiesNearLoc(aoe.targetloc, rad - 50) or {}) do
				if
					Fu.IsValidHero(enemyHero)
					and Fu.CanCastOnNonMagicImmune(enemyHero)
					and not Fu.IsSuspiciousIllusion(enemyHero)
				then
					local dmg = baseDamage + math.max(0, bot:GetMaxMana() - enemyHero:GetMaxMana()) * damageMultiplier
					if enemyHero:GetActualIncomingDamage(dmg, DAMAGE_TYPE_MAGICAL) >= enemyHero:GetHealth() * 0.4 then
						hit = hit + 1
					end
				end
			end
			if hit >= 3 then
				if DotaTime() >= (bot._odEclipseLogAt or -999) then
					bot._odEclipseLogAt = DotaTime() + 3
					pcall(print, string.format("[OHA-OD] t=%.0f eclipse-teamfight heroes=%d", DotaTime(), hit))
				end
				return BOT_ACTION_DESIRE_HIGH, aoe.targetloc
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.ConsiderObjurgation()
	if not objurgationAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
	end
	if
		Fu.IsRetreating(bot)
		and not Fu.IsRealInvisible(bot)
		and bot:WasRecentlyDamagedByAnyHero(2.0)
		and hpRatio < 0.6
	then
		if
			#nearbyEnemies > #nearbyAllies
			or bot:IsRooted()
			or Fu.GetTotalEstimatedDamageToTarget(nearbyEnemies, bot, 6.0) > bot:GetHealth()
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if not Fu.IsRealInvisible(bot) and bot:WasRecentlyDamagedByAnyHero(2.0) then
		if Fu.GetTotalEstimatedDamageToTarget(nearbyEnemies, bot, 5.0) > bot:GetHealth() then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if
			Fu.IsRoshan(botTarget)
			and Fu.CanBeAttacked(botTarget)
			and Fu.IsInRange(bot, botTarget, 800)
			and isAttacking
			and hpRatio < 0.3
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, 800) and isAttacking and hpRatio < 0.35 then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
return X
