-- [OHA-GRIM] logs off: the behaviour they traced works (game 029).
local print = function() end
-- Grimstroke: skill build, item build, and ability use for this hero.
local X = {}
local bot = GetBot()
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local AbilityContext = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local Minion = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local sTalentList = Fu.Skill.GetTalentList(bot)
local sAbilityList = Fu.Skill.GetAbilityList(bot)
local sRole = Fu.Item.GetRoleItemsBuyList(bot)
local tTalentTreeList = { ["t25"] = { 0, 10 }, ["t20"] = { 10, 0 }, ["t15"] = { 10, 0 }, ["t10"] = { 10, 0 } }
-- 1 Stroke of Fate, 2 Phantom's Embrace, 3 Ink Swell, 6 Soulbind.
-- Support (pos 4/5): Stroke of Fate first, then Phantom's Embrace, Ink Swell last (Dotabuff most
-- picked order; it was Ink Swell first).
-- Core: Stroke of Fate first, then Ink Swell, Phantom's Embrace last.
local tAllAbilityBuildList = { { 1, 3, 1, 2, 1, 6, 1, 2, 2, 2, 6, 3, 3, 3, 6 } }
if sRole ~= "pos_4" and sRole ~= "pos_5" then
	tAllAbilityBuildList = { { 1, 3, 1, 2, 1, 6, 1, 3, 3, 3, 6, 2, 2, 2, 6 } }
end
local nAbilityBuildList = Fu.Skill.GetRandomBuild(tAllAbilityBuildList)
local nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList)
local sRoleItemsBuyList = {}
sRoleItemsBuyList["pos_1"] = {
	"item_mage_outfit",
	"item_shadow_amulet",
	"item_shivas_guard",
	"item_cyclone",
	"item_glimmer_cape",
	"item_ultimate_scepter",
	"item_sheepstick",
	"item_aghanims_shard",
	"item_bloodthorn",
	"item_wind_waker",
	"item_moon_shard",
	"item_ultimate_scepter_2",
}
sRoleItemsBuyList["pos_2"] = sRoleItemsBuyList["pos_1"]
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
	"item_rod_of_atos",
	"item_gungir",
	"item_cyclone",
	"item_bloodstone",
	"item_black_king_bar",
	"item_aghanims_shard",
	"item_heavens_halberd",
	"item_wind_waker",
	"item_refresher",
	"item_travel_boots",
	"item_travel_boots_2",
	"item_moon_shard",
	"item_ultimate_scepter_2",
}
sRoleItemsBuyList["pos_4"] = {
	"item_blood_grenade",
	"item_priest_outfit",
	"item_blink",
	"item_glimmer_cape",
	"item_aghanims_shard",
	"item_ultimate_scepter",
	"item_aether_lens",
	"item_shivas_guard",
	"item_sheepstick",
	"item_moon_shard",
	"item_ultimate_scepter_2",
}
sRoleItemsBuyList["pos_5"] = {
	"item_blood_grenade",
	"item_mage_outfit",
	"item_ancient_janggo",
	"item_glimmer_cape",
	"item_blink",
	"item_boots_of_bearing",
	"item_aghanims_shard",
	"item_ultimate_scepter",
	"item_shivas_guard",
	"item_sheepstick",
	"item_moon_shard",
	"item_ultimate_scepter_2",
}
X["sBuyList"] = sRoleItemsBuyList[sRole]
X["sSellList"] = { "item_black_king_bar", "item_quelling_blade", "item_aether_lens", "item_urn_of_shadows" }
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
local strokeOfFateAbility =
	SafeAbility(bot:GetAbilityByName("grimstroke_dark_artistry"), "grimstroke_dark_artistry", "grimstroke")
local phantomsEmbraceAbility =
	SafeAbility(bot:GetAbilityByName("grimstroke_ink_creature"), "grimstroke_ink_creature", "grimstroke")
local inkSwellAbility =
	SafeAbility(bot:GetAbilityByName("grimstroke_spirit_walk"), "grimstroke_spirit_walk", "grimstroke")
local darkPortraitAbility =
	SafeAbility(bot:GetAbilityByName("grimstroke_dark_portrait"), "grimstroke_dark_portrait", "grimstroke")
local soulBindAbility =
	SafeAbility(bot:GetAbilityByName("grimstroke_soul_chain"), "grimstroke_soul_chain", "grimstroke")
local strokeOfFateDesire, strokeOfFateLocation
local phantomsEmbraceDesire, phantomsEmbraceTarget
local inkSwellDesire, inkSwellTarget
local darkPortraitDesire, darkPortraitTarget
local soulBindDesire, soulBindTarget
local botTarget
local isEngaging
local isRetreating
local isAttacking
-- Stroke of Fate on alt-cast goes straight (7.41), easier to aim than the curve. The bot API
-- has no alt-cast call; the autocast switch is the closest, so it is turned on once Stroke is
-- learned and the state is logged before and after, to confirm in game that the path is straight.
-- Checked every 5s: if the switch is found off again (e.g. reset by a death), it is logged with
-- the gap since the last check (a long gap means he was dead) and turned back on.
local function StrokeStraight()
	if not strokeOfFateAbility:IsTrained() then
		return
	end
	local now = DotaTime()
	if bot._strokeAltCheckAt ~= nil and now - bot._strokeAltCheckAt < 5 then
		return
	end
	local gap = bot._strokeAltCheckAt ~= nil and now - bot._strokeAltCheckAt or 0
	local first = bot._strokeAltCheckAt == nil
	bot._strokeAltCheckAt = now
	local okB, before = pcall(function()
		return strokeOfFateAbility:GetAutoCastState()
	end)
	if not okB or before ~= false then
		if first then
			pcall(print, string.format("[OHA-GRIM] t=%.0f stroke-altcast already=%s", now, tostring(okB and before)))
		end
		return
	end
	pcall(function()
		strokeOfFateAbility:ToggleAutoCast()
	end)
	local okA, after = pcall(function()
		return strokeOfFateAbility:GetAutoCastState()
	end)
	pcall(
		print,
		string.format(
			"[OHA-GRIM] t=%.0f stroke-altcast %s gap=%.0f after=%s",
			now,
			first and "set" or "reset-found",
			gap,
			tostring(okA and after)
		)
	)
end
-- Stroke of Fate on creeps keeps mana for Ink Swell + Phantom's Embrace (+ Soulbind when it is
-- up within 20s), and at least 25% of the pool. It was spammed on waves down to low mana.
function X.StrokeOnCreepsOk()
	local reserve = 0
	if inkSwellAbility:IsTrained() then
		reserve = reserve + inkSwellAbility:GetManaCost()
	end
	if phantomsEmbraceAbility:IsTrained() then
		reserve = reserve + phantomsEmbraceAbility:GetManaCost()
	end
	if soulBindAbility:IsTrained() and soulBindAbility:GetCooldownTimeRemaining() < 20 then
		reserve = reserve + soulBindAbility:GetManaCost()
	end
	local left = bot:GetMana() - strokeOfFateAbility:GetManaCost()
	return left >= reserve and Fu.GetManaAfter(strokeOfFateAbility:GetManaCost()) >= 0.25
end
function X.SkillsComplement()
	pcall(StrokeStraight)
	if Fu.CanNotUseAbility(bot) then
		return
	end
	local context = AbilityContext.Build(bot)
	isEngaging = context.isEngaging
	isRetreating = context.isRetreating
	isAttacking = Fu.IsAttacking(bot)
	botTarget = context.target
	inkSwellDesire, inkSwellTarget = X.ConsiderInkSwell()
	if inkSwellDesire > 0 then
		bot:Action_UseAbilityOnEntity(inkSwellAbility, inkSwellTarget)
		return
	end
	soulBindDesire, soulBindTarget = X.ConsiderSoulBind()
	if soulBindDesire > 0 then
		-- Soulbind -> Phantom's Embrace on the bound hero: a unit-target spell on one bound hero
		-- is also cast on the other (Valve data), so both get the latch and the silence.
		bot:Action_ClearActions(false)
		bot:ActionQueue_UseAbilityOnEntity(soulBindAbility, soulBindTarget)
		if
			phantomsEmbraceAbility:IsFullyCastable()
			and bot:GetMana() >= soulBindAbility:GetManaCost() + phantomsEmbraceAbility:GetManaCost()
		then
			bot:ActionQueue_UseAbilityOnEntity(phantomsEmbraceAbility, soulBindTarget)
			pcall(
				print,
				string.format(
					"[OHA-GRIM] t=%.0f soulbind-embrace target=%s",
					DotaTime(),
					(string.gsub(soulBindTarget:GetUnitName(), "npc_dota_hero_", ""))
				)
			)
		end
		return
	end
	phantomsEmbraceDesire, phantomsEmbraceTarget = X.ConsiderPhantomsEmbrace()
	if phantomsEmbraceDesire > 0 then
		bot:Action_UseAbilityOnEntity(phantomsEmbraceAbility, phantomsEmbraceTarget)
		return
	end
	strokeOfFateDesire, strokeOfFateLocation = X.ConsiderStrokeOfFate()
	if strokeOfFateDesire > 0 then
		-- EXPERIMENT: Stroke of Fate is ALT_CASTABLE (game files): the plain cast curves from where
		-- Grimstroke faces, the alt-cast goes straight. The bot API has no alt-cast order; try
		-- whether the alt state is the autocast toggle. Toggled once; every cast logs the state.
		if not bot._grimAltTried then
			bot._grimAltTried = true
			local okB, before = pcall(function()
				return strokeOfFateAbility:GetAutoCastState()
			end)
			local okT = pcall(function()
				strokeOfFateAbility:ToggleAutoCast()
			end)
			local okA, after = pcall(function()
				return strokeOfFateAbility:GetAutoCastState()
			end)
			pcall(
				print,
				string.format(
					"[OHA-GRIM] t=%.0f stroke-altcast-toggle ok=%s before=%s after=%s",
					DotaTime(),
					tostring(okT),
					okB and tostring(before) or "error",
					okA and tostring(after) or "error"
				)
			)
		end
		local okS, state = pcall(function()
			return strokeOfFateAbility:GetAutoCastState()
		end)
		pcall(
			print,
			string.format(
				"[OHA-GRIM] t=%.0f stroke cast alt=%s dist=%d",
				DotaTime(),
				okS and tostring(state) or "error",
				math.floor(GetUnitToLocationDistance(bot, strokeOfFateLocation))
			)
		)
		bot:Action_UseAbilityOnLocation(strokeOfFateAbility, strokeOfFateLocation)
		return
	end
	darkPortraitDesire, darkPortraitTarget = X.ConsiderDarkPortrait()
	if darkPortraitDesire > 0 then
		bot:Action_UseAbilityOnEntity(darkPortraitAbility, darkPortraitTarget)
		return
	end
end
function X.ConsiderStrokeOfFate()
	if not strokeOfFateAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local castRange = Fu.GetProperCastRange(false, bot, strokeOfFateAbility:GetCastRange())
	local castPoint = strokeOfFateAbility:GetCastPoint()
	local radius = strokeOfFateAbility:GetSpecialValueInt("end_radius")
	local projectileSpeed = strokeOfFateAbility:GetSpecialValueInt("projectile_speed")
	local damage = strokeOfFateAbility:GetSpecialValueInt("damage")
	local abilityLevel = strokeOfFateAbility:GetLevel()
	local nearbyEnemies = bot:GetNearbyHeroes(castRange, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and Fu.CanKillTarget(enemyHero, damage, DAMAGE_TYPE_MAGICAL)
			and not Fu.IsSuspiciousIllusion(enemyHero)
			and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
			and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
			and not enemyHero:HasModifier("modifier_templar_assassin_refraction_absorb")
		then
			local travelTime = GetUnitToUnitDistance(bot, enemyHero) / projectileSpeed + castPoint
			return BOT_ACTION_DESIRE_HIGH, enemyHero:GetExtrapolatedLocation(travelTime)
		end
	end
	if isEngaging then
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not Fu.IsDisabled(botTarget)
		then
			local nearbyAllies = botTarget:GetNearbyHeroes(1200, true, BOT_MODE_NONE)
			local nearbyEnemies = botTarget:GetNearbyHeroes(1200, false, BOT_MODE_NONE)
			if
				nearbyAllies ~= nil
				and nearbyEnemies ~= nil
				and (#nearbyAllies >= #nearbyEnemies or Fu.WeAreStronger(bot, 1600))
			then
				local travelTime = GetUnitToUnitDistance(bot, botTarget) / projectileSpeed + castPoint
				nearbyEnemies = Fu.GetEnemiesNearLoc(botTarget:GetLocation(), radius)
				if nearbyEnemies ~= nil and #nearbyEnemies >= 2 and not Fu.IsRunning(botTarget) then
					return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(nearbyEnemies)
				else
					return BOT_ACTION_DESIRE_HIGH, botTarget:GetExtrapolatedLocation(travelTime)
				end
			end
		end
	end
	if isRetreating then
		local nearbyAllies = bot:GetNearbyHeroes(1600, false, BOT_MODE_NONE)
		local nearbyEnemies = bot:GetNearbyHeroes(1600, true, BOT_MODE_NONE)
		if
			nearbyAllies ~= nil
			and nearbyEnemies ~= nil
			and (#nearbyEnemies > #nearbyAllies or not Fu.WeAreStronger(bot, 1600))
			and Fu.IsValidHero(nearbyEnemies[1])
			and Fu.CanCastOnNonMagicImmune(nearbyEnemies[1])
			and Fu.IsInRange(bot, nearbyEnemies[1], castRange)
			and not Fu.IsInRange(bot, nearbyEnemies[1], 300)
			and not Fu.IsSuspiciousIllusion(nearbyEnemies[1])
			and not Fu.IsDisabled(nearbyEnemies[1])
		then
			return BOT_ACTION_DESIRE_HIGH, nearbyEnemies[1]:GetLocation()
		end
	end
	if (Fu.IsPushing(bot) or Fu.IsDefending(bot)) and X.StrokeOnCreepsOk() and abilityLevel >= 3 then
		local aoeLocation = bot:FindAoELocation(true, true, bot:GetLocation(), castRange, radius, castPoint, 0)
		if aoeLocation.count >= 2 then
			local vulnerableUnit =
				Fu.GetVulnerableUnitNearLoc(bot, true, true, castRange, radius, aoeLocation.targetloc)
			if vulnerableUnit ~= nil then
				local travelTime = GetUnitToUnitDistance(bot, vulnerableUnit) / projectileSpeed + castPoint
				return BOT_ACTION_DESIRE_HIGH, vulnerableUnit:GetExtrapolatedLocation(travelTime)
			end
		end
		local laneCreeps = bot:GetNearbyLaneCreeps(castRange, true)
		if
			laneCreeps ~= nil
			and #laneCreeps >= 3
			and Fu.CanBeAttacked(laneCreeps[1])
			and nearbyEnemies ~= nil
			and #nearbyEnemies == 0
			and not Fu.IsRunning(laneCreeps[1])
			and not Fu.IsThereNonSelfCoreNearby(1000)
		then
			return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(laneCreeps)
		end
	end
	local nearbyAllies = bot:GetNearbyHeroes(castRange, false, BOT_MODE_NONE)
	for _, allyHero in pairs(nearbyAllies) do
		local enemiesNearAlly = allyHero:GetNearbyHeroes(1600, true, BOT_MODE_NONE)
		if
			Fu.IsValidHero(allyHero)
			and Fu.IsRetreating(allyHero)
			and allyHero:GetActiveModeDesire() >= 0.5
			and not allyHero:IsIllusion()
		then
			if
				Fu.IsValidHero(enemiesNearAlly[1])
				and Fu.CanCastOnNonMagicImmune(enemiesNearAlly[1])
				and Fu.IsInRange(bot, enemiesNearAlly[1], castRange)
				and Fu.IsChasingTarget(enemiesNearAlly[1], allyHero)
				and not Fu.IsChasingTarget(enemiesNearAlly[1], bot)
				and not Fu.IsDisabled(enemiesNearAlly[1])
				and not Fu.IsTaunted(enemiesNearAlly[1])
				and not Fu.IsSuspiciousIllusion(enemiesNearAlly[1])
				and not enemiesNearAlly[1]:HasModifier("modifier_enigma_black_hole_pull")
				and not enemiesNearAlly[1]:HasModifier("modifier_faceless_void_chronosphere_freeze")
				and not enemiesNearAlly[1]:HasModifier("modifier_necrolyte_reapers_scythe")
			then
				local travelTime = GetUnitToUnitDistance(bot, enemiesNearAlly[1]) / projectileSpeed + castPoint
				return BOT_ACTION_DESIRE_HIGH, enemiesNearAlly[1]:GetExtrapolatedLocation(travelTime)
			end
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if
			Fu.IsRoshan(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, bot:GetAttackRange())
			and isAttacking
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if
			Fu.IsTormentor(botTarget)
			and Fu.IsInRange(bot, botTarget, bot:GetAttackRange())
			and Fu.GetHP(botTarget) < 0.5
			and isAttacking
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.ConsiderPhantomsEmbrace()
	if not phantomsEmbraceAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castRange = Fu.GetProperCastRange(false, bot, phantomsEmbraceAbility:GetCastRange())
	local latchDuration = phantomsEmbraceAbility:GetSpecialValueInt("latch_duration")
	local damagePerSecond = phantomsEmbraceAbility:GetSpecialValueInt("damage_per_second")
	local popDamage = phantomsEmbraceAbility:GetSpecialValueInt("pop_damage")
	local nearbyEnemies = bot:GetNearbyHeroes(castRange, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and Fu.CanCastOnTargetAdvanced(enemyHero)
			-- datafeed: Phantom's Embrace deals magical damage.
			and Fu.CanKillTarget(enemyHero, damagePerSecond * latchDuration + popDamage, DAMAGE_TYPE_MAGICAL)
			and not Fu.IsSuspiciousIllusion(enemyHero)
			and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
			and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
			and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
			and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
			and not enemyHero:HasModifier("modifier_templar_assassin_refraction_absorb")
			and not strokeOfFateAbility:IsFullyCastable()
		then
			return BOT_ACTION_DESIRE_HIGH, enemyHero
		end
	end
	if isEngaging then
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.CanCastOnTargetAdvanced(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not Fu.IsDisabled(botTarget)
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			local nearbyAllies = botTarget:GetNearbyHeroes(1200, true, BOT_MODE_NONE)
			local nearbyEnemies = botTarget:GetNearbyHeroes(1200, false, BOT_MODE_NONE)
			if
				nearbyAllies ~= nil
				and nearbyEnemies ~= nil
				and (#nearbyAllies >= #nearbyEnemies or Fu.WeAreStronger(bot, 1600))
			then
				return BOT_ACTION_DESIRE_HIGH, botTarget
			end
		end
	end
	if isRetreating then
		local nearbyEnemies = bot:GetNearbyHeroes(1600, true, BOT_MODE_NONE)
		if
			Fu.IsValidHero(nearbyEnemies[1])
			and Fu.CanCastOnNonMagicImmune(nearbyEnemies[1])
			and Fu.CanCastOnTargetAdvanced(nearbyEnemies[1])
			and Fu.IsInRange(bot, nearbyEnemies[1], castRange)
			and Fu.IsChasingTarget(nearbyEnemies[1], bot)
			and not Fu.IsSuspiciousIllusion(nearbyEnemies[1])
			and not Fu.IsDisabled(nearbyEnemies[1])
		then
			local nearbyAllies = nearbyEnemies[1]:GetNearbyHeroes(1200, true, BOT_MODE_NONE)
			local chaserAllies = nearbyEnemies[1]:GetNearbyHeroes(1200, false, BOT_MODE_NONE)
			if
				nearbyAllies ~= nil
				and chaserAllies ~= nil
				and (
					#chaserAllies > #nearbyAllies
					or not Fu.WeAreStronger(bot, 1200)
					or bot:WasRecentlyDamagedByAnyHero(1)
				)
			then
				return BOT_ACTION_DESIRE_HIGH, nearbyEnemies[1]
			end
		end
	end
	local nearbyAllies = bot:GetNearbyHeroes(castRange, false, BOT_MODE_NONE)
	for _, allyHero in pairs(nearbyAllies) do
		local enemiesNearAlly = allyHero:GetNearbyHeroes(1600, true, BOT_MODE_NONE)
		if
			Fu.IsValidHero(allyHero)
			and Fu.IsRetreating(allyHero)
			and allyHero:WasRecentlyDamagedByAnyHero(1)
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
				and not Fu.IsChasingTarget(enemiesNearAlly[1], bot)
				and not Fu.IsDisabled(enemiesNearAlly[1])
				and not Fu.IsTaunted(enemiesNearAlly[1])
				and not Fu.IsSuspiciousIllusion(enemiesNearAlly[1])
				and not enemiesNearAlly[1]:HasModifier("modifier_necrolyte_reapers_scythe")
			then
				return BOT_ACTION_DESIRE_HIGH, enemiesNearAlly[1]
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function X.ConsiderInkSwell()
	if not inkSwellAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castRange = Fu.GetProperCastRange(false, bot, inkSwellAbility:GetCastRange())
	local radius = inkSwellAbility:GetSpecialValueInt("radius")
	local nearbyEnemies = bot:GetNearbyHeroes(radius, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and enemyHero:IsChanneling()
			and not Fu.IsSuspiciousIllusion(enemyHero)
			and not Fu.IsDisabled(enemyHero)
		then
			return BOT_ACTION_DESIRE_HIGH, bot
		end
	end
	local nearbyAllies = bot:GetNearbyHeroes(castRange, false, BOT_MODE_NONE)
	for _, allyHero in pairs(nearbyAllies) do
		local enemiesNearAlly = allyHero:GetNearbyHeroes(radius, true, BOT_MODE_NONE)
		if Fu.IsValidHero(allyHero) and not Fu.IsSuspiciousIllusion(allyHero) then
			for _, enemyHero in pairs(enemiesNearAlly) do
				if
					Fu.IsValidHero(enemyHero)
					and Fu.CanCastOnNonMagicImmune(enemyHero)
					and enemyHero:IsChanneling()
					and not Fu.IsSuspiciousIllusion(enemyHero)
					and not Fu.IsDisabled(enemyHero)
					and not enemyHero:HasModifier("modifier_enigma_black_hole_pull")
					and not enemyHero:HasModifier("modifier_faceless_void_chronosphere_freeze")
					and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
				then
					return BOT_ACTION_DESIRE_HIGH, allyHero
				end
			end
		end
	end
	local nearestAllyDistance = 1600
	local nearestAlly = nil
	for _, allyHero in pairs(nearbyAllies) do
		if
			Fu.IsValidHero(allyHero)
			and Fu.IsValidTarget(botTarget)
			and not Fu.IsSuspiciousIllusion(allyHero)
			and GetUnitToUnitDistance(allyHero, botTarget) < nearestAllyDistance
		then
			-- Keep the ally nearest the target: nearestAllyDistance was never lowered, so the last ally in the list
			-- won (often one far from the target, and then no enemy was in the swell radius).
			nearestAlly = allyHero
			nearestAllyDistance = GetUnitToUnitDistance(allyHero, botTarget)
		end
	end
	if isEngaging then
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not botTarget:HasModifier("modifier_enigma_black_hole_pull")
			and not botTarget:HasModifier("modifier_faceless_void_chronosphere_freeze")
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			local nearbyAllies = botTarget:GetNearbyHeroes(1600, true, BOT_MODE_NONE)
			local nearbyEnemies = botTarget:GetNearbyHeroes(1600, false, BOT_MODE_NONE)
			if
				nearbyAllies ~= nil
				and nearbyEnemies ~= nil
				and (#nearbyAllies >= #nearbyEnemies or Fu.WeAreStronger(bot, 1600))
				and nearestAlly ~= nil
			then
				nearbyEnemies = Fu.GetEnemiesNearLoc(nearestAlly:GetLocation(), radius)
				if nearbyEnemies ~= nil and #nearbyEnemies >= 1 then
					pcall(
						print,
						string.format(
							"[OHA-GRIM] t=%.0f ink-swell engage ally=%s dist=%d",
							DotaTime(),
							nearestAlly:GetUnitName(),
							math.floor(nearestAllyDistance)
						)
					)
					return BOT_ACTION_DESIRE_HIGH, nearestAlly
				end
			end
		end
	end
	if isRetreating and bot:GetActiveModeDesire() > 0.75 and not strokeOfFateAbility:IsFullyCastable() then
		local nearbyEnemies = bot:GetNearbyHeroes(1600, true, BOT_MODE_NONE)
		if
			Fu.IsValidHero(nearbyEnemies[1])
			and Fu.CanCastOnNonMagicImmune(nearbyEnemies[1])
			and Fu.IsInRange(bot, nearbyEnemies[1], castRange)
			and Fu.IsChasingTarget(nearbyEnemies[1], bot)
			and not Fu.IsSuspiciousIllusion(nearbyEnemies[1])
			and not Fu.IsDisabled(nearbyEnemies[1])
		then
			local nearbyAllies = nearbyEnemies[1]:GetNearbyHeroes(1600, true, BOT_MODE_NONE)
			local chaserAllies = nearbyEnemies[1]:GetNearbyHeroes(1600, false, BOT_MODE_NONE)
			if
				nearbyAllies ~= nil
				and chaserAllies ~= nil
				and (
					#chaserAllies > #nearbyAllies
					or not Fu.WeAreStronger(bot, 1600)
					or bot:WasRecentlyDamagedByAnyHero(1) and Fu.GetHP(bot) < 0.75
				)
			then
				return BOT_ACTION_DESIRE_HIGH, bot
			end
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if
			Fu.IsRoshan(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, radius)
			and isAttacking
		then
			return BOT_ACTION_DESIRE_HIGH, bot
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, radius) and isAttacking then
			return BOT_ACTION_DESIRE_HIGH, bot
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function X.ConsiderSoulBind()
	if not soulBindAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local latchRadius = soulBindAbility:GetSpecialValueInt("chain_latch_radius")
	local chainDuration = soulBindAbility:GetSpecialValueInt("chain_duration")
	if isEngaging then
		local strongestEnemy = Fu.GetStrongestUnit(1200, bot, true, true, chainDuration)
		if strongestEnemy == nil then
			strongestEnemy = Fu.GetStrongestUnit(1200, bot, true, false, chainDuration)
		end
		if
			Fu.IsValidHero(strongestEnemy)
			and not Fu.IsSuspiciousIllusion(strongestEnemy)
			and not strongestEnemy:HasModifier("modifier_enigma_black_hole_pull")
			and not strongestEnemy:HasModifier("modifier_faceless_void_chronosphere_freeze")
			and not strongestEnemy:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			local nearbyAllies = strongestEnemy:GetNearbyHeroes(1600, true, BOT_MODE_NONE)
			local nearbyEnemies = strongestEnemy:GetNearbyHeroes(1600, false, BOT_MODE_NONE)
			local enemiesInLatchRadius = Fu.GetEnemiesNearLoc(strongestEnemy:GetLocation(), latchRadius)
			if
				nearbyAllies ~= nil
				and nearbyEnemies ~= nil
				and (#nearbyAllies >= #nearbyEnemies or Fu.WeAreStronger(bot, 1600))
				and enemiesInLatchRadius ~= nil
				and #enemiesInLatchRadius >= 2
			then
				return BOT_ACTION_DESIRE_HIGH, strongestEnemy
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function X.ConsiderDarkPortrait()
	if not darkPortraitAbility:IsTrained() or not darkPortraitAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	if isEngaging then
		local strongestEnemy = Fu.GetStrongestUnit(1600, bot, true, true, 5)
		if strongestEnemy == nil then
			strongestEnemy = Fu.GetStrongestUnit(1600, bot, true, false, 5)
		end
		if
			Fu.IsValidHero(strongestEnemy)
			and not Fu.IsSuspiciousIllusion(strongestEnemy)
			and not Fu.IsDisabled(strongestEnemy)
			and not strongestEnemy:HasModifier("modifier_enigma_black_hole_pull")
			and not strongestEnemy:HasModifier("modifier_faceless_void_chronosphere_freeze")
			and not strongestEnemy:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			local nearbyEnemies = bot:GetNearbyHeroes(1600, true, BOT_MODE_NONE)
			local nearbyAllies = bot:GetNearbyHeroes(1600, false, BOT_MODE_NONE)
			if
				nearbyEnemies ~= nil
				and nearbyAllies ~= nil
				and (#nearbyAllies >= #nearbyEnemies or Fu.WeAreStronger(bot, 1600))
			then
				return BOT_ACTION_DESIRE_HIGH, strongestEnemy
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
return X
