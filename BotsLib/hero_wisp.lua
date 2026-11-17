-- Wisp: skill build, item build, and ability use for this hero.
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local Dota = require(GetScriptDirectory() .. "/FuncLib/dota/index")
local BotActionDesire = Dota.BotActionDesire
local BotMode = Dota.BotMode
local UnitType = Dota.UnitType
local Buff = require(GetScriptDirectory() .. "/FuncLib/data/buff")
local healingModifiers = Buff.hero_is_healing
local Utils = require(GetScriptDirectory() .. "/FuncLib/systems/utils")
local GetTeamFountainTpPoint = Utils.GetTeamFountainTpPoint
local HasAnyEffect = Utils.HasAnyEffect
local IsValidHero = Utils.IsValidHero
local HeroBuilder = require(GetScriptDirectory() .. "/FuncLib/hero/hero_builder")
local buildHeroConfig = HeroBuilder.buildHeroConfig
local buildHeroExport = HeroBuilder.buildHeroExport
local relocateHpThreshold = 0.2
local tetherAllyHpThreshold = 0.75
local tetherManaThreshold = 0.8
local retreatHpThreshold = 0.25
local relocateMinDistance = 3000
local spiritsMinCreeps = 2
local spiritsManaThreshold = 0.4
local bot = GetBot()
local Minion = dofile(GetScriptDirectory() .. "/FuncLib/hero/minion")
local heroConfig = buildHeroConfig(bot, {
	skills = { default = { 2, 1, 2, 3, 2, 6, 2, 3, 3, 3, 6, 1, 1, 1, 6 } },
	talents = { default = { t25 = { 10, 0 }, t20 = { 10, 0 }, t15 = { 0, 10 }, t10 = { 0, 10 } } },
	items = {
		pos_1 = {
			"item_tango",
			"item_faerie_fire",
			"item_gauntlets",
			"item_gauntlets",
			"item_gauntlets",
			"item_boots",
			"item_armlet",
			"item_black_king_bar",
			"item_sange",
			"item_ultimate_scepter",
			"item_heavens_halberd",
			"item_travel_boots",
			"item_satanic",
			"item_aghanims_shard",
			"item_assault",
			"item_travel_boots_2",
			"item_ultimate_scepter_2",
			"item_moon_shard",
		},
		pos_4 = {
			"item_priest_outfit",
			"item_mekansm",
			"item_holy_locket",
			"item_glimmer_cape",
			"item_guardian_greaves",
			"item_spirit_vessel",
			"item_shivas_guard",
			"item_moon_shard",
			"item_ultimate_scepter_2",
		},
		pos_5 = {
			"item_blood_grenade",
			"item_mage_outfit",
			"item_holy_locket",
			"item_glimmer_cape",
			"item_mekansm",
			"item_ultimate_scepter",
			"item_shivas_guard",
			"item_cyclone",
			"item_sheepstick",
			"item_wind_waker",
			"item_moon_shard",
			"item_ultimate_scepter_2",
		},
	},
	sell = { "item_black_king_bar", "item_quelling_blade" },
})
local tetherAbility = bot:GetAbilityByName("wisp_tether")
local spiritsAbility = bot:GetAbilityByName("wisp_spirits")
local overchargeAbility = bot:GetAbilityByName("wisp_overcharge")
local relocateAbility = bot:GetAbilityByName("wisp_relocate")
local tetherBreakAbility = bot:GetAbilityByName("wisp_tether_break")
local nearbyEnemies = {}
bot.stateTetheredHero = bot.stateTetheredHero
local function isHealing(unit)
	return HasAnyEffect(unit, "modifier_tango_heal", unpack(healingModifiers))
end
local function isFighting(hero)
	local attackedRecently = GameTime() - hero:GetLastAttackTime() < 0.33
	local attackTarget = hero:GetAttackTarget()
	return Fu.IsGoingOnSomeone(hero)
		or attackTarget ~= nil and attackTarget:GetTeam() == GetOpposingTeam() and attackedRecently
		or #hero:GetNearbyCreeps(200, true) > 2
end
local function isTethered()
	return bot:HasModifier("modifier_wisp_tether")
end
local function considerTether()
	if not isTethered() then
		bot.stateTetheredHero = nil
	end
	if not tetherAbility:IsFullyCastable() or not tetherBreakAbility:IsHidden() then
		return BotActionDesire.None, nil
	end
	local castRange = tetherAbility:GetCastRange()
	local nearbyAllies = bot:GetNearbyHeroes(castRange, false, BotMode.None) or {}
	for _, allyHero in ipairs(nearbyAllies) do
		do
			local shouldContinue
			repeat
				-- Tether is SPELL_IMMUNITY_ALLIES_YES: a BKB carry can be tethered (the magic-immune
				-- skip dropped Io's main fight target). Illusions of allies are skipped instead.
				if allyHero == bot or not allyHero:IsAlive() or allyHero:IsIllusion() then
					shouldContinue = true
					break
				end
				if Fu.IsRetreating(bot) or Fu.GetHP(bot) < retreatHpThreshold then
					if Fu.IsRetreating(allyHero) then
						return BotActionDesire.High, allyHero
					end
					shouldContinue = true
					break
				end
				if
					Fu.GetHP(allyHero) < tetherAllyHpThreshold
					or Fu.GetMP(bot) > tetherManaThreshold
					or isHealing(bot)
					or isFighting(allyHero)
				then
					return BotActionDesire.High, allyHero
				end
				shouldContinue = true
			until true
			if not shouldContinue then
				break
			end
		end
	end
	return BotActionDesire.None, nil
end
local function considerOvercharge()
	if not overchargeAbility:IsFullyCastable() then
		return BotActionDesire.None
	end
	if isTethered() and bot.stateTetheredHero ~= nil and isFighting(bot.stateTetheredHero) then
		return BotActionDesire.High
	end
	return BotActionDesire.None
end
local function considerSpirits()
	if not spiritsAbility:IsFullyCastable() then
		return BotActionDesire.None
	end
	-- Was "#nearbyEnemies >= 1" (any enemy hero within 1600): spirits circle Io at 200-650 range, so they
	-- were cast (90-120 mana) at heroes they could not reach. Now: an enemy hero within 800.
	for _, enemyHero in ipairs(nearbyEnemies) do
		if IsValidHero(enemyHero) and GetUnitToUnitDistance(bot, enemyHero) <= 800 then
			return BotActionDesire.High
		end
	end
	if #bot:GetNearbyNeutralCreeps(500, true) >= spiritsMinCreeps and Fu.GetMP(bot) > spiritsManaThreshold then
		return BotActionDesire.Moderate
	end
	return BotActionDesire.None
end
local function considerRelocate()
	if not relocateAbility:IsFullyCastable() then
		return BotActionDesire.None, nil
	end
	if isTethered() and bot.stateTetheredHero ~= nil then
		local tetheredHpRatio = Fu.GetHP(bot.stateTetheredHero)
		local hpRatio = Fu.GetHP(bot)
		if tetheredHpRatio <= relocateHpThreshold or hpRatio <= relocateHpThreshold then
			local enemiesNearTethered = bot.stateTetheredHero:GetNearbyHeroes(1200, true, BotMode.None) or {}
			local tetheredIsLosing = #enemiesNearTethered >= 1 and tetheredHpRatio < Fu.GetHP(enemiesNearTethered[1])
			local botIsLosing = #nearbyEnemies >= 1 and hpRatio < Fu.GetHP(nearbyEnemies[1])
			if tetheredIsLosing or botIsLosing then
				return BotActionDesire.High, GetTeamFountainTpPoint()
			end
		end
	end
	if not isTethered() and #nearbyEnemies >= 1 and Fu.GetHP(bot) < relocateHpThreshold then
		return BotActionDesire.High, GetTeamFountainTpPoint()
	end
	for _, allyHero in ipairs(GetUnitList(UnitType.AlliedHeroes)) do
		if
			IsValidHero(allyHero)
			and Fu.IsInTeamFight(allyHero, 1200)
			and GetUnitToUnitDistance(bot, allyHero) > relocateMinDistance
			and allyHero:WasRecentlyDamagedByAnyHero(2)
		then
			return BotActionDesire.High, allyHero:GetLocation()
		end
	end
	return BotActionDesire.None, nil
end
local function skillsComplement()
	if Fu.CanNotUseAbility(bot) or bot:IsInvisible() then
		return
	end
	nearbyEnemies = bot:GetNearbyHeroes(1600, true, BotMode.None) or {}
	local tetherDesire, tetherTarget = considerTether()
	if tetherDesire > 0 and tetherTarget then
		bot:Action_UseAbilityOnEntity(tetherAbility, tetherTarget)
		bot.stateTetheredHero = tetherTarget
		return
	end
	local overchargeDesire = considerOvercharge()
	if overchargeDesire > 0 then
		bot:Action_UseAbility(overchargeAbility)
		return
	end
	local spiritsDesire = considerSpirits()
	if spiritsDesire > 0 then
		bot:Action_UseAbility(spiritsAbility)
		return
	end
	local relocateDesire, relocateLocation = considerRelocate()
	if relocateDesire > 0 and relocateLocation ~= nil then
		bot:Action_UseAbilityOnLocation(relocateAbility, relocateLocation)
		return
	end
	-- Follow the tethered ally: the tether breaks past 1000 range (MAX TETHER DISTANCE in the
	-- datafeed) and nothing kept Io near the ally, so modes walked Io away and broke it.
	local tetheredHero = bot.stateTetheredHero
	if
		isTethered()
		and IsValidHero(tetheredHero)
		and not Fu.IsRetreating(bot)
		and GetUnitToUnitDistance(bot, tetheredHero) > 650
	then
		if DotaTime() >= (bot._wispFollowLogAt or -999) then
			bot._wispFollowLogAt = DotaTime() + 5
			pcall(
				print,
				string.format(
					"[OHA-WISP] t=%.0f follow-tether ally=%s dist=%d",
					DotaTime(),
					tetheredHero:GetUnitName(),
					GetUnitToUnitDistance(bot, tetheredHero)
				)
			)
		end
		bot:Action_MoveToLocation(tetheredHero:GetLocation())
	end
end
local function minionThink(minion)
	if Minion.IsValidUnit(minion) then
		Minion.IllusionThink(minion)
	end
end
local X = buildHeroExport(heroConfig, skillsComplement, minionThink)
return X
