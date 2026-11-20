-- Life Stealer: skill build, item build, and ability use for this hero.
local X = {}
local bot = GetBot()
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local AbilityContext = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local Minion = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local sTalentList = Fu.Skill.GetTalentList(bot)
local sAbilityList = Fu.Skill.GetAbilityList(bot)
local sRole = Fu.Item.GetRoleItemsBuyList(bot)
local tTalentTreeList = { ["t25"] = { 0, 10 }, ["t20"] = { 10, 0 }, ["t15"] = { 10, 0 }, ["t10"] = { 10, 0 } }
-- Feast maxed first, Rage second, Open Wounds last (Dotabuff most picked order). Infest at 6/12/18.
local tAllAbilityBuildList = { { 3, 2, 3, 1, 3, 6, 3, 1, 1, 1, 6, 2, 2, 2, 6 } }
local nAbilityBuildList = Fu.Skill.GetRandomBuild(tAllAbilityBuildList)
local nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList)
local sRoleItemsBuyList = {}
-- Stratz 7.41f, week of 9 Nov 2026: pos 1, 235,249 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_1"] = {
	"item_tango",
	"item_double_gauntlets",
	"item_quelling_blade",
	"item_double_branches",
	"item_magic_wand",
	"item_phase_boots",
	"item_radiance",
	"item_sange_and_yasha",
	"item_ultimate_scepter",
	"item_basher",
	"item_monkey_king_bar",
	"item_abyssal_blade",
	"item_ultimate_scepter_2",
	"item_travel_boots",
	"item_moon_shard",
	"item_blink",
	"item_swift_blink",
	"item_aghanims_shard",
	"item_travel_boots_2",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 2, 1,844 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_2"] = {
	"item_tango",
	"item_quelling_blade",
	"item_double_gauntlets",
	"item_branches",
	"item_bracer",
	"item_magic_wand",
	"item_phase_boots",
	"item_radiance",
	"item_sange",
	"item_ultimate_scepter",
	"item_basher",
	"item_monkey_king_bar",
	"item_abyssal_blade",
	"item_ultimate_scepter_2",
	"item_manta",
	"item_aghanims_shard",
	"item_moon_shard",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 3, 17,521 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_3"] = {
	"item_tango",
	"item_quelling_blade",
	"item_double_gauntlets",
	"item_double_branches",
	"item_bracer",
	"item_magic_wand",
	"item_phase_boots",
	"item_radiance",
	"item_sange_and_yasha",
	"item_basher",
	"item_ultimate_scepter",
	"item_abyssal_blade",
	"item_ultimate_scepter_2",
	"item_armlet",
	"item_maelstrom",
	"item_mjollnir",
	"item_aghanims_shard",
	"item_moon_shard",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 4, 1,235 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_4"] = {
	"item_tango",
	"item_quelling_blade",
	"item_double_gauntlets",
	"item_branches",
	"item_bracer",
	"item_magic_wand",
	"item_phase_boots",
	"item_radiance",
	"item_sange",
	"item_basher",
	"item_ultimate_scepter",
	"item_abyssal_blade",
	"item_ultimate_scepter_2",
	"item_armlet",
	"item_vladmir",
	"item_aghanims_shard",
	"item_moon_shard",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 5, 1,387 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_5"] = {
	"item_tango",
	"item_quelling_blade",
	"item_double_gauntlets",
	"item_branches",
	"item_faerie_fire",
	"item_bracer",
	"item_magic_wand",
	"item_phase_boots",
	"item_radiance",
	"item_buckler",
	"item_ultimate_scepter",
	"item_basher",
	"item_assault",
	"item_abyssal_blade",
	"item_ultimate_scepter_2",
	"item_armlet",
	"item_manta",
	"item_aghanims_shard",
	"item_moon_shard",
}
X["sBuyList"] = sRoleItemsBuyList[sRole]
X["sSellList"] = { "item_black_king_bar", "item_quelling_blade" }
if Fu.Role.IsPvNMode() or Fu.Role.IsAllShadow() then
	X["sBuyList"], X["sSellList"] = { "PvN_mid" }, {}
end
nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"] =
	Fu.SetUserHeroInit(nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"])
X["sSkillList"] = Fu.Skill.GetSkillList(sAbilityList, nAbilityBuildList, sTalentList, nTalentBuildList)
X["bDeafaultAbility"] = false
X["bDeafaultItem"] = false
local botTarget, unused1, unused2
local nearbyAllies, nearbyEnemies
function X.MinionThink(hMinionUnit)
	local botHp = Fu.GetHP(bot)
	local minionConsumeAbility = hMinionUnit:GetAbilityByName("life_stealer_consume")
	if minionConsumeAbility and minionConsumeAbility:IsFullyCastable() then
		local minionEnemies = hMinionUnit:GetNearbyHeroes(1200, true, BOT_MODE_NONE)
		local isHeroHost = hMinionUnit:IsHero()
		if not bot._infestTime then
			bot._infestTime = DotaTime()
		end
		local infestDuration = DotaTime() - bot._infestTime
		if botHp > 0.9 and hMinionUnit:HasModifier("modifier_fountain_aura_buff") then
			hMinionUnit:Action_UseAbility(minionConsumeAbility)
			bot._infestTime = nil
			return
		end
		if minionEnemies and #minionEnemies >= 2 and botHp > 0.7 then
			hMinionUnit:Action_UseAbility(minionConsumeAbility)
			bot._infestTime = nil
			return
		end
		if botHp > 0.95 and infestDuration > 2 then
			hMinionUnit:Action_UseAbility(minionConsumeAbility)
			bot._infestTime = nil
			return
		end
		if not isHeroHost then
			if minionEnemies and #minionEnemies > 0 and botHp > 0.5 then
				hMinionUnit:Action_UseAbility(minionConsumeAbility)
				bot._infestTime = nil
				return
			end
			local teamFightLocation = Fu.GetTeamFightLocation(bot)
			if teamFightLocation and botHp > 0.5 then
				hMinionUnit:Action_MoveToLocation(teamFightLocation)
			else
				hMinionUnit:Action_MoveToLocation(Fu.GetTeamFountain())
			end
			return
		end
		if isHeroHost then
			if botHp > 0.75 and minionEnemies and #minionEnemies > 0 then
				hMinionUnit:Action_UseAbility(minionConsumeAbility)
				bot._infestTime = nil
				return
			end
			if botHp > 0.85 and infestDuration > 4 then
				hMinionUnit:Action_UseAbility(minionConsumeAbility)
				bot._infestTime = nil
				return
			end
		end
		if infestDuration > 15 then
			hMinionUnit:Action_UseAbility(minionConsumeAbility)
			bot._infestTime = nil
			return
		end
	end
	Minion.MinionThink(hMinionUnit)
end
local rageAbility = SafeAbility(bot:GetAbilityByName("life_stealer_rage"), "life_stealer_rage", "life_stealer")
local openWoundsAbility =
	SafeAbility(bot:GetAbilityByName("life_stealer_open_wounds"), "life_stealer_open_wounds", "life_stealer")
local infestAbility = SafeAbility(bot:GetAbilityByName("life_stealer_infest"), "life_stealer_infest", "life_stealer")
local consumeAbility = SafeAbility(bot:GetAbilityByName("life_stealer_consume"), "life_stealer_consume", "life_stealer")
local rageDesire
local openWoundsDesire, openWoundsTarget
local infestDesire, infestTarget
local consumeDesire
local isAttacking = false
local hpRatio
local isGoingOnSomeone
local isRetreating
function X.SkillsComplement()
	rageAbility = SafeAbility(bot:GetAbilityByName("life_stealer_rage"), "life_stealer_rage", "life_stealer")
	openWoundsAbility =
		SafeAbility(bot:GetAbilityByName("life_stealer_open_wounds"), "life_stealer_open_wounds", "life_stealer")
	infestAbility = SafeAbility(bot:GetAbilityByName("life_stealer_infest"), "life_stealer_infest", "life_stealer")
	consumeAbility = SafeAbility(bot:GetAbilityByName("life_stealer_consume"), "life_stealer_consume", "life_stealer")
	isAttacking = Fu.IsAttacking(bot)
	hpRatio = Fu.GetHP(bot)
	botTarget = Fu.GetProperTarget(bot)
	nearbyAllies = bot:GetNearbyHeroes(1600, false, BOT_MODE_NONE)
	nearbyEnemies = bot:GetNearbyHeroes(1600, true, BOT_MODE_NONE)
	-- Mode flags every frame, before Consume: they were only set outside Infest (after Consume ran),
	-- so ConsiderConsume read the values from the moment he went in.
	isGoingOnSomeone = Fu.IsGoingOnSomeone(bot)
	isRetreating = Fu.IsRetreating(bot)
	consumeDesire = X.ConsiderConsume()
	if consumeDesire > 0 then
		bot:Action_UseAbility(consumeAbility)
		return
	end
	if not bot:HasModifier("modifier_life_stealer_infest") then
		if Fu.CanNotUseAbility(bot) then
			return
		end
	end
	rageDesire = X.ConsiderRage()
	if rageDesire > 0 then
		Fu.SetQueuePtToINT(bot, false)
		bot:ActionQueue_UseAbility(rageAbility)
		return
	end
	-- ConsiderInfest was written but never called, so Infest (datafeed: unit target) was never cast.
	infestDesire, infestTarget = X.ConsiderInfest()
	if infestDesire > 0 and infestTarget ~= nil then
		bot:Action_UseAbilityOnEntity(infestAbility, infestTarget)
		return
	end
	openWoundsDesire, openWoundsTarget = X.ConsiderOpenWounds()
	if openWoundsDesire > 0 then
		Fu.SetQueuePtToINT(bot, false)
		bot:ActionQueue_UseAbilityOnEntity(openWoundsAbility, openWoundsTarget)
		return
	end
end
function X.ConsiderRage()
	if
		not Fu.CanCastAbility(rageAbility)
		or bot:HasModifier("modifier_life_stealer_infest")
		or bot:IsMagicImmune()
		or bot:IsInvulnerable()
	then
		return BOT_ACTION_DESIRE_NONE
	end
	local enemiesNearBot = Fu.GetEnemiesNearLoc(bot:GetLocation(), 1200)
	if #enemiesNearBot > 0 then
		if bot:WasRecentlyDamagedByAnyHero(3.0) and not Fu.IsRealInvisible(bot) then
			if
				Fu.IsNotAttackProjectileIncoming(bot, 350)
				or Fu.IsWillBeCastUnitTargetSpell(bot, 500)
				or Fu.IsWillBeCastPointSpell(bot, 500)
			then
				-- Rage gives debuff immunity and 80% magic resistance (Valve data), so it answers an
				-- incoming spell in any fight. It needed the target out of attack range or a retreat
				-- below 55% HP, so a hex or stun cast on him in melee was never blocked.
				if isGoingOnSomeone or isRetreating or hpRatio < 0.6 then
					if DotaTime() >= (bot._rageLogAt or -999) then
						bot._rageLogAt = DotaTime() + 5
						pcall(
							print,
							string.format(
								"[OHA-LIFESTEALER] t=%.0f rage vs incoming spell hp=%.2f",
								DotaTime(),
								hpRatio
							)
						)
					end
					return BOT_ACTION_DESIRE_HIGH
				end
			end
			if Fu.IsStunProjectileIncoming and Fu.IsStunProjectileIncoming(bot, 550) then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
		if isGoingOnSomeone or isRetreating and not Fu.IsRealInvisible(bot) then
			if bot:IsRooted() then
				if isRetreating then
					return BOT_ACTION_DESIRE_HIGH
				elseif
					isGoingOnSomeone
					and Fu.IsValidTarget(botTarget)
					and not Fu.IsInRange(bot, botTarget, bot:GetAttackRange())
				then
					return BOT_ACTION_DESIRE_HIGH
				end
			end
			enemiesNearBot = Fu.GetEnemiesNearLoc(bot:GetLocation(), 600)
			if
				bot:IsSilenced()
				and #enemiesNearBot >= 2
				and isGoingOnSomeone
				and not bot:HasModifier("modifier_item_mask_of_madness_berserk")
			then
				return BOT_ACTION_DESIRE_HIGH
			end
			local alliesNearBot = Fu.GetAlliesNearLoc(bot:GetLocation(), 1200)
			if
				#enemiesNearBot >= #alliesNearBot
				and hpRatio < 0.6
				and Fu.IsValidHero(enemiesNearBot[1])
				and (Fu.IsChasingTarget(enemiesNearBot[1], bot) or enemiesNearBot[1]:GetAttackTarget() == bot)
			then
				return BOT_ACTION_DESIRE_HIGH
			end
			if
				#enemiesNearBot >= 3
				and Fu.IsInTeamFight(bot, 1200)
				and #Fu.GetHeroesTargetingUnit(enemiesNearBot, bot) > 0
				and not Fu.IsRealInvisible(bot)
			then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	if
		bot:HasModifier("modifier_jakiro_macropyre_burn")
		or bot:HasModifier("modifier_lich_chainfrost_slow")
		or bot:HasModifier("modifier_crystal_maiden_freezing_field_slow")
		or bot:HasModifier("modifier_puck_coiled")
		or bot:HasModifier("modifier_skywrath_mystic_flare_aura_effect")
		or bot:HasModifier("modifier_snapfire_magma_burn_slow")
		or bot:HasModifier("modifier_sand_king_epicenter_slow")
	then
		return BOT_ACTION_DESIRE_HIGH
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderOpenWounds()
	if not Fu.CanCastAbility(openWoundsAbility) or bot:HasModifier("modifier_life_stealer_infest") then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castRange = Fu.GetProperCastRange(false, bot, openWoundsAbility:GetCastRange())
	local manaCost = openWoundsAbility:GetManaCost()
	local manaAfter = Fu.GetManaAfter(manaCost)
	local manaThreshold = Fu.GetManaThreshold(bot, manaCost, { rageAbility, infestAbility })
	if isGoingOnSomeone then
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanBeAttacked(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.CanCastOnTargetAdvanced(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and not Fu.IsDisabled(botTarget)
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
			and not botTarget:HasModifier("modifier_templar_assassin_refraction_absorb")
		then
			-- Added "he is hitting it": a 1v1 in melee range (no chase, one attacker) never got Open
			-- Wounds, his lifesteal and slow for the fight.
			if
				Fu.IsChasingTarget(bot, botTarget)
				or #Fu.GetHeroesTargetingUnit(nearbyAllies, botTarget) >= 2 and Fu.GetHP(botTarget) > 0.2
				or isAttacking and bot:GetAttackTarget() == botTarget and Fu.GetHP(botTarget) > 0.2
			then
				if manaAfter > manaThreshold then
					return BOT_ACTION_DESIRE_HIGH, botTarget
				end
			end
		end
	end
	if isRetreating and not Fu.IsRealInvisible(bot) then
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.IsInRange(bot, enemyHero, castRange)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
				and bot:WasRecentlyDamagedByHero(enemyHero, 3.0)
				and Fu.IsChasingTarget(enemyHero, bot)
				and not Fu.IsDisabled(enemyHero)
				and not enemyHero:IsDisarmed()
			then
				if Fu.IsChasingTarget(enemyHero, bot) or #nearbyEnemies > #nearbyAllies and hpRatio < 0.5 then
					return BOT_ACTION_DESIRE_HIGH, enemyHero
				end
			end
		end
	end
	if
		(Fu.IsPushing(bot) or Fu.IsDefending(bot) or Fu.IsFarming(bot))
		and hpRatio < 0.5
		and (manaAfter > manaThreshold or hpRatio < 0.2)
		and isAttacking
	then
		if
			Fu.IsValid(botTarget)
			and Fu.CanBeAttacked(botTarget)
			and botTarget:IsCreep()
			and Fu.GetHP(botTarget) >= 0.75
			and not Fu.CanKillTarget(botTarget, bot:GetAttackDamage() * 4, DAMAGE_TYPE_PHYSICAL)
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if
			Fu.IsRoshan(botTarget)
			and Fu.CanBeAttacked(botTarget)
			and Fu.CanCastOnTargetAdvanced(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and Fu.GetHP(botTarget) > 0.2
			and isAttacking
			and hpRatio < 0.5
			and (manaAfter > manaThreshold or hpRatio < 0.2)
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if
			Fu.IsTormentor(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and isAttacking
			and hpRatio < 0.5
			and (manaAfter > manaThreshold or hpRatio < 0.2)
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function X.ConsiderInfest()
	if not Fu.CanCastAbility(infestAbility) or bot:HasModifier("modifier_life_stealer_infest") then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castRange = Fu.GetProperCastRange(false, bot, infestAbility:GetCastRange())
	if isGoingOnSomeone then
		if
			Fu.IsValidHero(botTarget)
			and Fu.CanBeAttacked(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and not Fu.IsDisabled(botTarget)
			and not botTarget:HasModifier("modifier_enigma_black_hole_pull")
			and not botTarget:HasModifier("modifier_faceless_void_chronosphere_freeze")
		then
			if bot:HasScepter() then
				if
					hpRatio < 0.5
					and Fu.CanCastOnTargetAdvanced(botTarget)
					and Fu.IsInRange(bot, botTarget, castRange + 300)
					and (Fu.IsCore(botTarget) or Fu.GetHP(botTarget) > 0.5)
				then
					bot.infest_target = "hero"
					return BOT_ACTION_DESIRE_HIGH, botTarget
				end
			end
			local enemiesNearTarget = Fu.GetEnemiesNearLoc(botTarget:GetLocation(), 900)
			if #enemiesNearTarget >= 2 then
				local infestAlly = nil
				for _, allyHero in pairs(nearbyAllies) do
					if
						bot ~= allyHero
						and Fu.IsValidHero(allyHero)
						and Fu.IsInRange(bot, allyHero, 900)
						and Fu.IsGoingOnSomeone(allyHero)
						and (allyHero:GetAttackTarget() == botTarget or Fu.IsChasingTarget(allyHero, botTarget))
						and not allyHero:IsIllusion()
						and not Fu.IsMeepoClone(allyHero)
						and allyHero:GetAttackRange() <= 324
					then
						infestAlly = allyHero
					end
				end
				if infestAlly ~= nil then
					bot.infest_target = "hero"
					return BOT_ACTION_DESIRE_HIGH, infestAlly
				end
			end
		end
	end
	if isRetreating and not Fu.IsRealInvisible(bot) then
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.IsInRange(bot, enemyHero, 800)
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and not enemyHero:IsDisarmed()
			then
				if Fu.IsChasingTarget(enemyHero, bot) or #nearbyEnemies > #nearbyAllies and hpRatio < 0.5 then
					local totalEstimatedDamage = Fu.GetTotalEstimatedDamageToTarget(nearbyEnemies, bot, 5.0)
					if totalEstimatedDamage > bot:GetHealth() + bot:GetHealthRegen() * 5.0 then
						for _, allyHero in ipairs(nearbyAllies) do
							if
								bot ~= allyHero
								and Fu.IsValidHero(allyHero)
								and Fu.IsInRange(bot, allyHero, castRange + 500)
								and Fu.IsRetreating(allyHero)
								and not Fu.IsSuspiciousIllusion(allyHero)
								and not Fu.IsMeepoClone(allyHero)
							then
								bot.infest_target = "hero"
								return BOT_ACTION_DESIRE_HIGH, allyHero
							end
						end
						local allyLaneCreeps = bot:GetNearbyLaneCreeps(777, false)
						for _, creep in ipairs(allyLaneCreeps) do
							if Fu.IsValid(creep) then
								bot.infest_target = "creep"
								return BOT_ACTION_DESIRE_HIGH, creep
							end
						end
						local enemyCreeps = bot:GetNearbyCreeps(777, true)
						for _, creep in ipairs(enemyCreeps) do
							if
								Fu.IsValid(creep)
								and not creep:IsAncientCreep()
								and not creep:IsDominated()
								and not creep:HasModifier("modifier_chen_holy_persuasion")
								and not creep:HasModifier("modifier_dominated")
							then
								bot.infest_target = "creep"
								return BOT_ACTION_DESIRE_HIGH, creep
							end
						end
					end
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function X.ConsiderConsume()
	if not Fu.CanCastAbility(consumeAbility) then
		return BOT_ACTION_DESIRE_NONE
	end
	local consumeDamage = infestAbility:GetSpecialValueInt("damage")
	local consumeRadius = infestAbility:GetSpecialValueInt("radius")
	if not isRetreating then
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.CanBeAttacked(enemyHero)
				and Fu.IsInRange(bot, enemyHero, consumeRadius - 100)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
				and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
				and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
			then
				local alliesNearEnemy = Fu.GetAlliesNearLoc(enemyHero:GetLocation(), 1200)
				local enemiesNearEnemy = Fu.GetEnemiesNearLoc(enemyHero:GetLocation(), 1200)
				if #alliesNearEnemy >= #enemiesNearEnemy then
					if Fu.CanKillTarget(enemyHero, consumeDamage, DAMAGE_TYPE_MAGICAL) then
						return BOT_ACTION_DESIRE_HIGH
					end
				end
			end
		end
	end
	if isGoingOnSomeone then
		if
			Fu.IsValidHero(botTarget)
			and Fu.CanBeAttacked(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, consumeRadius)
			and not botTarget:HasModifier("modifier_dazzle_shallow_grave")
			and not botTarget:HasModifier("modifier_enigma_black_hole_pull")
			and not botTarget:HasModifier("modifier_faceless_void_chronosphere_freeze")
		then
			if hpRatio > 0.8 then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	if isRetreating then
		if #nearbyEnemies == 0 and hpRatio > 0.9 then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if hpRatio > 0.9 and #nearbyAllies >= #nearbyEnemies then
		return BOT_ACTION_DESIRE_HIGH
	end
	return BOT_ACTION_DESIRE_NONE
end
return X
