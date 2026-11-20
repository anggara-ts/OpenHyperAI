-- Elder Titan: skill build, item build, and ability use for this hero.
-- Accidental globals made file-local (#13): every bot shares one Lua state, so these were shared.
local ConsiderAstralSpirit, ConsiderMoveAstralSpirit, ConsiderReturnSpirit, ConsiderEarthSplitter, ConsiderEchoStomp
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
	{ ["t25"] = { 0, 10 }, ["t20"] = { 0, 10 }, ["t15"] = { 10, 0 }, ["t10"] = { 10, 0 } },
}
-- Build 1 took Earth Splitter only at level 9 and rank 2 at 16; ultimate now at levels 6/12 (entries 6/11).
local tAllAbilityBuildList =
	{ { 2, 3, 2, 3, 2, 6, 2, 3, 3, 1, 6, 1, 1, 1, 6 }, { 2, 1, 2, 3, 2, 6, 2, 3, 3, 3, 6, 1, 1, 1, 6 } }
local nAbilityBuildList
local nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList[1])
if sRole == "pos_1" then
	nAbilityBuildList = tAllAbilityBuildList[1]
else
	nAbilityBuildList = tAllAbilityBuildList[2]
end
local sRoleItemsBuyList = {}
-- Stratz 7.41f, week of 9 Nov 2026: pos 1 has 354 matches, built from pos 3 (6,547) (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_1"] = {
	"item_tango",
	"item_quelling_blade",
	"item_double_branches",
	"item_gauntlets",
	"item_circlet",
	"item_bracer",
	"item_magic_wand",
	"item_phase_boots",
	"item_mask_of_madness",
	"item_echo_sabre",
	"item_ultimate_scepter",
	"item_lesser_crit",
	"item_harpoon",
	"item_greater_crit",
	"item_basher",
	"item_travel_boots",
	"item_ultimate_scepter_2",
	"item_satanic",
	"item_assault",
	"item_aghanims_shard",
	"item_moon_shard",
	"item_travel_boots_2",
}
-- Phase Boots (sven outfit), Shard and Scepter early: the three most played Elder Titan items.
-- Stratz 7.41f, week of 9 Nov 2026: pos 3, 6,547 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_3"] = {
	"item_tango",
	"item_quelling_blade",
	"item_double_branches",
	"item_gauntlets",
	"item_circlet",
	"item_bracer",
	"item_magic_wand",
	"item_phase_boots",
	"item_mask_of_madness",
	"item_echo_sabre",
	"item_ultimate_scepter",
	"item_lesser_crit",
	"item_harpoon",
	"item_greater_crit",
	"item_basher",
	"item_travel_boots",
	"item_ultimate_scepter_2",
	"item_satanic",
	"item_assault",
	"item_aghanims_shard",
	"item_moon_shard",
	"item_travel_boots_2",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 2 has 558 matches, built from pos 3 (6,547) (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_2"] = sRoleItemsBuyList["pos_3"]
-- Stratz 7.41f, week of 9 Nov 2026: pos 4, 4,321 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_4"] = {
	"item_tango",
	"item_blood_grenade",
	"item_double_branches",
	"item_wind_lace",
	"item_magic_wand",
	"item_tranquil_boots",
	"item_ancient_janggo",
	"item_cyclone",
	"item_ultimate_scepter",
	"item_boots_of_bearing",
	"item_greater_crit",
	"item_gungir",
	"item_lotus_orb",
	"item_aghanims_shard",
	"item_moon_shard",
	"item_ultimate_scepter_2",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 5, 3,908 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_5"] = {
	"item_tango",
	"item_blood_grenade",
	"item_double_branches",
	"item_wind_lace",
	"item_magic_wand",
	"item_tranquil_boots",
	"item_ancient_janggo",
	"item_cyclone",
	"item_aghanims_shard",
	"item_ultimate_scepter",
	"item_boots_of_bearing",
	"item_gungir",
	"item_echo_sabre",
	"item_force_staff",
	"item_moon_shard",
	"item_ultimate_scepter_2",
}
X["sBuyList"] = sRoleItemsBuyList[sRole]
X["sSellList"] = { "item_travel_boots", "item_quelling_blade", "item_abyssal_blade", "item_magic_wand" }
if Fu.Role.IsPvNMode() or Fu.Role.IsAllShadow() then
	X["sBuyList"], X["sSellList"] = { "PvN_antimage" }, {}
end
nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"] =
	Fu.SetUserHeroInit(nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"])
X["sSkillList"] = Fu.Skill.GetSkillList(sAbilityList, nAbilityBuildList, sTalentList, nTalentBuildList)
X["bDeafaultAbility"] = false
X["bDeafaultItem"] = false
local echoStompAbility =
	SafeAbility(bot:GetAbilityByName("elder_titan_echo_stomp"), "elder_titan_echo_stomp", "elder_titan")
local ancestralSpiritAbility =
	SafeAbility(bot:GetAbilityByName("elder_titan_ancestral_spirit"), "elder_titan_ancestral_spirit", "elder_titan")
local moveSpiritAbility =
	SafeAbility(bot:GetAbilityByName("elder_titan_move_spirit"), "elder_titan_move_spirit", "elder_titan")
local returnSpiritAbility =
	SafeAbility(bot:GetAbilityByName("elder_titan_return_spirit"), "elder_titan_return_spirit", "elder_titan")
local naturalOrderAbility =
	SafeAbility(bot:GetAbilityByName("elder_titan_natural_order"), "elder_titan_natural_order", "elder_titan")
local earthSplitterAbility =
	SafeAbility(bot:GetAbilityByName("elder_titan_earth_splitter"), "elder_titan_earth_splitter", "elder_titan")
local botTarget
local nearbyEnemies, nearbyAllies
local astralSpiritLocation = nil
local astralSpiritCastTime = 0
local astralSpiritDuration = 10
local function IsHeldInPlace(unit)
	return unit:HasModifier("modifier_faceless_void_chronosphere_freeze")
		or unit:HasModifier("modifier_enigma_black_hole_pull")
end
local function IsHeldForAtLeast(unit, minDuration)
	local holdModifiers = { "modifier_faceless_void_chronosphere_freeze", "modifier_enigma_black_hole_pull" }
	for _, modifierName in pairs(holdModifiers) do
		local modifierIndex = unit:GetModifierByName(modifierName)
		if modifierIndex ~= -1 then
			local remainingDuration = unit:GetModifierRemainingDuration(modifierIndex)
			if remainingDuration >= minDuration then
				return true
			end
		end
	end
	return false
end
local function IsAstralSpiritOut()
	return ancestralSpiritAbility
		and not ancestralSpiritAbility:IsFullyCastable()
		and astralSpiritLocation ~= nil
		and DotaTime() - astralSpiritCastTime < astralSpiritDuration
end
function X.MinionThink(minionUnit)
	Minion.MinionThink(minionUnit)
end
local isGoingOnSomeone
local isInTeamFight
local lastSpiritMoveTime = 0
local spiritMoveInterval = 1.0
-- fix: these were globals. Forward-declared locals: the "function X()" definitions below assign these.
local ConsiderAstralSpirit, ConsiderMoveAstralSpirit, ConsiderReturnSpirit, ConsiderEarthSplitter, ConsiderEchoStomp
function X.SkillsComplement()
	if Fu.CanNotUseAbility(bot) or bot:IsCastingAbility() or bot:IsChanneling() then
		return
	end
	local context = AbilityContext.Build(bot)
	isGoingOnSomeone = context.isEngaging
	isInTeamFight = context.isTeamFight
	nearbyEnemies = context.enemies
	nearbyAllies = context.allies
	botTarget = context.target
	moveSpiritAbility =
		SafeAbility(bot:GetAbilityByName("elder_titan_move_spirit"), "elder_titan_move_spirit", "elder_titan")
	returnSpiritAbility =
		SafeAbility(bot:GetAbilityByName("elder_titan_return_spirit"), "elder_titan_return_spirit", "elder_titan")
	if ConsiderEchoStomp(bot) > 0 then
		bot:Action_UseAbility(echoStompAbility)
		return
	end
	local earthSplitterDesire, earthSplitterLocation = ConsiderEarthSplitter()
	if earthSplitterDesire > 0 then
		Fu.SetQueuePtToINT(bot, false)
		bot:ActionQueue_UseAbilityOnLocation(earthSplitterAbility, earthSplitterLocation)
		return
	end
	if IsAstralSpiritOut() then
		if ConsiderReturnSpirit() > 0 and returnSpiritAbility ~= nil and Fu.CanCastAbility(returnSpiritAbility) then
			bot:Action_UseAbility(returnSpiritAbility)
			return
		end
		local nearestEnemy = nearbyEnemies and nearbyEnemies[1] or nil
		local isInEnemyAttackRange = Fu.IsValidHero(nearestEnemy)
			and Fu.IsInRange(bot, nearestEnemy, nearestEnemy:GetAttackRange() + 150)
		if
			DotaTime() > lastSpiritMoveTime + spiritMoveInterval
			and not bot:WasRecentlyDamagedByAnyHero(2.0)
			and not bot:WasRecentlyDamagedByTower(2.0)
			and not isInEnemyAttackRange
			and moveSpiritAbility ~= nil
			and Fu.CanCastAbility(moveSpiritAbility)
		then
			local moveSpiritDesire, moveSpiritLocation = ConsiderMoveAstralSpirit()
			if moveSpiritDesire > 0 and moveSpiritLocation ~= nil then
				bot:Action_UseAbilityOnLocation(moveSpiritAbility, moveSpiritLocation)
				lastSpiritMoveTime = DotaTime()
			end
		end
		return
	end
	local astralSpiritDesire, castLocation = ConsiderAstralSpirit()
	if astralSpiritDesire > 0 then
		Fu.SetQueuePtToINT(bot, false)
		astralSpiritLocation = castLocation
		astralSpiritCastTime = DotaTime()
		lastSpiritMoveTime = DotaTime()
		bot:ActionQueue_UseAbilityOnLocation(ancestralSpiritAbility, castLocation)
	end
end
function ConsiderAstralSpirit()
	if not ancestralSpiritAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
	end
	if bot:IsUsingAbility() or bot:IsCastingAbility() then
		return BOT_ACTION_DESIRE_NONE
	end
	if bot:HasModifier("modifier_elder_titan_ancestral_spirit_buff") then
		return BOT_ACTION_DESIRE_NONE
	end
	local castRange = ancestralSpiritAbility:GetSpecialValueInt("AbilityCastRange")
	if Fu.IsValidTarget(botTarget) and (Fu.IsInTeamFight(bot, 1600) or isGoingOnSomeone or Fu.IsPushing(bot)) then
		if Fu.IsInRange(bot, botTarget, castRange) then
			local aoe = bot:FindAoELocation(true, true, bot:GetLocation(), castRange, 500, 0, 0)
			if aoe.count >= #nearbyEnemies - 1 then
				return BOT_ACTION_DESIRE_HIGH, aoe.targetloc
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function ConsiderMoveAstralSpirit()
	if moveSpiritAbility == nil then
		return BOT_ACTION_DESIRE_NONE
	end
	if not IsAstralSpiritOut() then
		return BOT_ACTION_DESIRE_NONE
	end
	local enemies = nearbyEnemies or bot:GetNearbyHeroes(1600, true, BOT_MODE_NONE) or {}
	local closestEnemy = nil
	local closestDistance = 99999
	for _, enemyHero in pairs(enemies) do
		if Fu.IsValidHero(enemyHero) then
			local distance = Fu.Utils.GetLocationToLocationDistance(astralSpiritLocation, enemyHero:GetLocation())
			if distance < closestDistance then
				closestDistance = distance
				closestEnemy = enemyHero
			end
		end
	end
	if closestEnemy ~= nil then
		return BOT_ACTION_DESIRE_VERYHIGH, closestEnemy:GetLocation()
	end
	return BOT_ACTION_DESIRE_NONE
end
function ConsiderReturnSpirit()
	if not IsAstralSpiritOut() then
		return BOT_ACTION_DESIRE_NONE
	end
	local timeSinceCast = DotaTime() - astralSpiritCastTime
	if timeSinceCast >= 4 then
		return BOT_ACTION_DESIRE_HIGH
	end
	return BOT_ACTION_DESIRE_NONE
end
function ConsiderEarthSplitter()
	if not earthSplitterAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
	end
	if bot:IsCastingAbility() then
		return BOT_ACTION_DESIRE_NONE
	end
	-- Earth Splitter's cast range (2400) is a top-level AbilityCastRange, not an AbilityValues key,
	-- so GetSpecialValueInt("AbilityCastRange") read 0: no enemy was ever "in range" and the AoE
	-- search ran around Elder Titan's own feet. Read the real cast range.
	local castRange = earthSplitterAbility:GetCastRange()
	if castRange == nil or castRange <= 0 then
		castRange = 2400
	end
	local radius = 300
	local delay = 3.14
	if Fu.IsInTeamFight(bot, 1600) or isGoingOnSomeone or Fu.IsPushing(bot) then
		for _, enemyHero in pairs(nearbyEnemies) do
			-- The crack lands crack_time (2.72s) after the cast, so the hold must outlast that (was 1.8).
			if
				Fu.IsValidHero(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.IsInRange(bot, enemyHero, castRange)
				and IsHeldForAtLeast(enemyHero, 2.8)
			then
				pcall(
					print,
					string.format("[OHA-ELDERTITAN] t=%.0f splitter on held %s", DotaTime(), enemyHero:GetUnitName())
				)
				return BOT_ACTION_DESIRE_VERYHIGH, enemyHero:GetLocation()
			end
		end
		local aoe = bot:FindAoELocation(true, true, bot:GetLocation(), castRange, radius, delay, 1500)
		local enemiesNearAoe = Fu.GetHeroesNearLocation(true, aoe.targetloc, 800)
		if #enemiesNearAoe >= 3 then
			return BOT_ACTION_DESIRE_HIGH, aoe.targetloc
		end
		if #enemiesNearAoe >= 2 then
			local hasCore = false
			for _, enemyHero in pairs(enemiesNearAoe) do
				if Fu.IsValidHero(enemyHero) and Fu.IsCore(enemyHero) then
					hasCore = true
					break
				end
			end
			if hasCore then
				return BOT_ACTION_DESIRE_HIGH, aoe.targetloc
			end
		end
		if
			Fu.IsValidHero(botTarget)
			and #nearbyEnemies >= #nearbyAllies
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.CanKillTarget(botTarget, botTarget:GetMaxHealth() * 0.4, DAMAGE_TYPE_MAGICAL)
		then
			local predictedLocation = Fu.GetCorrectLoc(botTarget, delay)
			return BOT_ACTION_DESIRE_HIGH, predictedLocation
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function ConsiderEchoStomp(caster)
	if not echoStompAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
	end
	local radius = echoStompAbility:GetSpecialValueInt("radius")
	local damage = echoStompAbility:GetSpecialValueInt("stomp_damage")
	if caster == nil then
		caster = bot
	end
	local enemiesInRadius = caster:GetNearbyHeroes(radius, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(enemiesInRadius) do
		if enemyHero:IsChanneling() then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	local disabledCount = 0
	for _, enemyHero in pairs(enemiesInRadius) do
		if
			Fu.IsValidHero(enemyHero)
			and (Fu.IsDisabled(enemyHero) or enemyHero:GetCurrentMovementSpeed() <= 250 or IsHeldInPlace(enemyHero))
		then
			disabledCount = disabledCount + 1
		end
	end
	if disabledCount >= 3 then
		return BOT_ACTION_DESIRE_HIGH
	end
	if Fu.IsRetreating(bot) then
		for _, enemyHero in pairs(enemiesInRadius) do
			if Fu.IsValidHero(enemyHero) and bot:WasRecentlyDamagedByHero(enemyHero, 2) then
				if
					Fu.CanCastOnNonMagicImmune(enemyHero)
					and (
						Fu.IsDisabled(enemyHero)
						or enemyHero:GetCurrentMovementSpeed() <= 250
						or IsHeldInPlace(enemyHero)
					)
				then
					return BOT_ACTION_DESIRE_HIGH
				end
			end
		end
	end
	if isInTeamFight or isGoingOnSomeone or Fu.IsPushing(bot) or Fu.IsDefending(bot) then
		-- No IsChasingTarget here: it needs the target to be running, so a stunned target (the
		-- best moment to stomp) never passed.
		if
			Fu.IsValidHero(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(caster, botTarget, radius)
			and (Fu.IsDisabled(botTarget) or botTarget:GetCurrentMovementSpeed() <= 250 or IsHeldInPlace(botTarget))
		then
			return BOT_ACTION_DESIRE_HIGH
		end
		-- Two or more heroes well inside the radius in a fight: the stomp (0.4s + 1.3s channel)
		-- sleeps them even if they are not disabled first. It used to need 3 already-disabled heroes.
		if isInTeamFight or isGoingOnSomeone then
			local deep = 0
			for _, enemyHero in pairs(enemiesInRadius) do
				if
					Fu.IsValidHero(enemyHero)
					and Fu.CanCastOnNonMagicImmune(enemyHero)
					and not Fu.IsSuspiciousIllusion(enemyHero)
					and Fu.IsInRange(caster, enemyHero, radius - 150)
				then
					deep = deep + 1
				end
			end
			if deep >= 2 then
				pcall(print, string.format("[OHA-ELDERTITAN] t=%.0f stomp heroes=%d", DotaTime(), deep))
				return BOT_ACTION_DESIRE_HIGH
			end
		end
		local disabledCountInFight = 0
		for _, enemyHero in pairs(enemiesInRadius) do
			if
				Fu.IsValidHero(enemyHero)
				and (Fu.IsDisabled(enemyHero) or enemyHero:GetCurrentMovementSpeed() <= 250 or IsHeldInPlace(enemyHero))
			then
				disabledCountInFight = disabledCountInFight + 1
			end
		end
		if disabledCountInFight >= 3 then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
return X
