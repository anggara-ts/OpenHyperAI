-- How Rubick plays after stealing a spell from Axe.
local bot = GetBot()
local X = {}
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local berserkersCallAbility
local battleHungerAbility
local cullingBladeAbility
local botTarget
local mpRatio, nearbyEnemies, nearbyAllies
function X.ConsiderStolenSpell(ability)
	bot = GetBot()
	if Fu.CanNotUseAbility(bot) then
		return
	end
	mpRatio = bot:GetMana() / bot:GetMaxMana()
	nearbyEnemies = Fu.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE)
	nearbyAllies = Fu.GetAlliesNearLoc(bot:GetLocation(), 1600)
	botTarget = Fu.GetProperTarget(bot)
	local abilityName = ability:GetName()
	if abilityName == "axe_culling_blade" then
		cullingBladeAbility = ability
		CullingBladeDesire, CullingBladeTarget = X.ConsiderCullingBlade()
		if CullingBladeDesire > 0 then
			bot:Action_UseAbilityOnEntity(cullingBladeAbility, CullingBladeTarget)
			return
		end
	end
	if abilityName == "axe_berserkers_call" then
		berserkersCallAbility = ability
		BerserkersCallDesire = X.ConsiderBerserkersCall()
		if BerserkersCallDesire > 0 then
			bot:Action_UseAbility(berserkersCallAbility)
			return
		end
	end
	if abilityName == "axe_battle_hunger" then
		battleHungerAbility = ability
		BattleHungerDesire, BattleHungerTarget = X.ConsiderBattleHunger()
		if BattleHungerDesire > 0 then
			bot:Action_UseAbilityOnEntity(battleHungerAbility, BattleHungerTarget)
			return
		end
	end
end
function X.ConsiderBerserkersCall()
	if not berserkersCallAbility:IsFullyCastable() then
		return 0
	end
	local radius = berserkersCallAbility:GetSpecialValueInt("radius")
	local manaCost = berserkersCallAbility:GetManaCost()
	local nearbyEnemyList = Fu.GetAroundEnemyHeroList(radius - 50)
	for _, enemyHero in pairs(nearbyEnemyList) do
		if enemyHero:IsChanneling() and not enemyHero:IsMagicImmune() then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidHero(botTarget)
			and Fu.IsInRange(botTarget, bot, radius - 90)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and not Fu.IsDisabled(botTarget)
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if
		(Fu.IsPushing(bot) or Fu.IsDefending(bot) or Fu.IsFarming(bot))
		and Fu.IsAllowedToSpam(bot, manaCost)
		and bot:GetAttackTarget() ~= nil
		and DotaTime() > 6 * 60
		and #nearbyAllies <= 2
		and #nearbyEnemies == 0
	then
		local nearbyLaneCreeps = bot:GetNearbyLaneCreeps(radius - 50, true)
		if #nearbyLaneCreeps >= 4 and not nearbyLaneCreeps[1]:HasModifier("modifier_fountain_glyph") then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if bot:GetActiveMode() == BOT_MODE_ROSHAN then
		if
			Fu.IsRoshan(botTarget)
			and not Fu.IsDisabled(botTarget)
			and not botTarget:IsDisarmed()
			and Fu.IsInRange(botTarget, bot, radius)
			and Fu.IsAttacking(bot)
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderBattleHunger()
	if not battleHungerAbility:IsFullyCastable() then
		return 0
	end
	local abilityLevel = battleHungerAbility:GetLevel()
	local castRange = Fu.GetProperCastRange(false, bot, battleHungerAbility:GetCastRange())
	local manaCost = battleHungerAbility:GetManaCost()
	local duration = battleHungerAbility:GetSpecialValueInt("duration")
	local damage = battleHungerAbility:GetSpecialValueInt("damage_per_second") * duration
	local enemiesInRange = Fu.GetAroundEnemyHeroList(castRange)
	local enemiesInExtendedRange = Fu.GetAroundEnemyHeroList(castRange + 200)
	for _, enemyHero in pairs(enemiesInRange) do
		if
			Fu.IsValid(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and Fu.CanCastOnTargetAdvanced(enemyHero)
			and Fu.WillMagicKillTarget(bot, enemyHero, damage, duration)
			and not enemyHero:HasModifier("modifier_axe_battle_hunger_self")
		then
			return BOT_ACTION_DESIRE_HIGH, enemyHero
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidHero(botTarget)
			and Fu.IsInRange(botTarget, bot, castRange)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.CanCastOnTargetAdvanced(botTarget)
			and not botTarget:HasModifier("modifier_axe_battle_hunger_self")
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end
	if Fu.IsInTeamFight(bot, 1200) then
		local weakestTarget = nil
		local weakestHealth = 100000
		for _, enemyHero in pairs(enemiesInExtendedRange) do
			if
				Fu.IsValid(enemyHero)
				and not enemyHero:HasModifier("modifier_axe_battle_hunger_self")
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
			then
				local health = enemyHero:GetHealth()
				if health < weakestHealth then
					weakestHealth = health
					weakestTarget = enemyHero
				end
			end
		end
		if weakestTarget ~= nil then
			return BOT_ACTION_DESIRE_HIGH, weakestTarget
		end
	end
	if Fu.IsLaning(bot) and mpRatio > 0.5 then
		for _, enemyHero in pairs(enemiesInRange) do
			if
				Fu.IsValid(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
				and enemyHero:GetAttackTarget() == nil
				and not enemyHero:HasModifier("modifier_axe_battle_hunger_self")
			then
				return BOT_ACTION_DESIRE_HIGH, enemyHero
			end
		end
	end
	if Fu.IsRetreating(bot) then
		for _, enemyHero in pairs(enemiesInRange) do
			if
				Fu.IsValid(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
				and not enemyHero:HasModifier("modifier_axe_battle_hunger_self")
			then
				return BOT_ACTION_DESIRE_HIGH, enemyHero
			end
		end
	end
	if Fu.IsFarming(bot) and abilityLevel >= 2 and Fu.IsAllowedToSpam(bot, manaCost * 0.25) then
		local nearbyNeutrals = bot:GetNearbyNeutralCreeps(castRange + 100)
		local strongestCreep = Fu.GetMostHpUnit(nearbyNeutrals)
		if
			Fu.IsValid(strongestCreep)
			and not Fu.IsRoshan(strongestCreep)
			and not strongestCreep:HasModifier("modifier_axe_battle_hunger_self")
			and strongestCreep:GetMagicResist() < 0.3
			and not Fu.CanKillTarget(strongestCreep, bot:GetAttackDamage() * 2.88, DAMAGE_TYPE_PHYSICAL)
		then
			return BOT_ACTION_DESIRE_HIGH, strongestCreep
		end
	end
	if bot:GetActiveMode() == BOT_MODE_ROSHAN then
		if
			Fu.IsRoshan(botTarget)
			and not Fu.IsDisabled(botTarget)
			and Fu.IsInRange(botTarget, bot, castRange)
			and not botTarget:HasModifier("modifier_axe_battle_hunger_self")
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderCullingBlade()
	if not cullingBladeAbility:IsFullyCastable() then
		return 0
	end
	local abilityLevel = cullingBladeAbility:GetLevel()
	local castRange = Fu.GetProperCastRange(false, bot, cullingBladeAbility:GetCastRange())
	local damage = 150 + 100 * abilityLevel
	local enemiesInExtendedRange = Fu.GetAroundEnemyHeroList(castRange + 200)
	for _, enemyHero in pairs(enemiesInExtendedRange) do
		if
			Fu.IsValidHero(enemyHero)
			and enemyHero:CanBeSeen()
			and enemyHero:GetHealth() + enemyHero:GetHealthRegen() * 0.8 < damage
			and not Fu.IsHaveAegis(enemyHero)
			and not enemyHero:IsInvulnerable()
			and not enemyHero:IsMagicImmune()
			and not X.HasSpecialModifier(enemyHero)
			and not X.IsKillBotAntiMage(enemyHero)
		then
			return BOT_ACTION_DESIRE_HIGH, enemyHero
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.HasSpecialModifier(hero)
	if
		hero:HasModifier("modifier_winter_wyvern_winters_curse")
		or hero:HasModifier("modifier_winter_wyvern_winters_curse_aura")
		or hero:HasModifier("modifier_antimage_spell_shield")
		or hero:HasModifier("modifier_item_lotus_orb_active")
		or hero:HasModifier("modifier_item_aeon_disk_buff")
		or hero:HasModifier("modifier_item_sphere_target")
		or hero:HasModifier("modifier_illusion")
	then
		return true
	else
		return false
	end
end
function X.IsKillBotAntiMage(hero)
	if
		not hero:IsBot()
		or hero:GetUnitName() ~= "npc_dota_hero_antimage"
		or hero:IsStunned()
		or hero:IsHexed()
		or hero:IsNightmared()
		or hero:IsChanneling()
		or Fu.IsTaunted(hero)
	then
		return false
	end
	return true
end
return X
