-- Kunkka: skill build, item build, and ability use for this hero.
local X = {}
local bot = GetBot()
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local AbilityContext = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local Minion = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local sTalentList = Fu.Skill.GetTalentList(bot)
local sAbilityList = Fu.Skill.GetAbilityList(bot)
local sRole = Fu.Item.GetRoleItemsBuyList(bot)
local tTalentTreeList = {
	{ ["t25"] = { 0, 10 }, ["t20"] = { 0, 10 }, ["t15"] = { 0, 10 }, ["t10"] = { 0, 10 } },
	{ ["t25"] = { 0, 10 }, ["t20"] = { 0, 10 }, ["t15"] = { 0, 10 }, ["t10"] = { 0, 10 } },
}
local tAllAbilityBuildList = { { 2, 1, 2, 3, 2, 6, 2, 3, 3, 3, 6, 1, 1, 1, 6 }, { 2, 1, 2, 3, 2, 6, 2, 3, 3, 3, 6, 1, 1, 1, 6 } }
local nAbilityBuildList
local nTalentBuildList
if sRole == "pos_2" then
	nAbilityBuildList = tAllAbilityBuildList[1]
	nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList[1])
else
	nAbilityBuildList = tAllAbilityBuildList[2]
	nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList[2])
end
local sRoleItemsBuyList = {}
sRoleItemsBuyList["pos_2"] = {
	"item_tango",
	"item_double_branches",
	"item_quelling_blade",
	"item_gauntlets",
	"item_circlet",
	"item_bottle",
	"item_magic_wand",
	"item_bracer",
	"item_phase_boots",
	"item_blade_mail",
	"item_ultimate_scepter",
	"item_aghanims_shard",
	"item_black_king_bar",
	"item_greater_crit",
	"item_shivas_guard",
	"item_travel_boots",
	"item_heart",
	"item_refresher",
	"item_ultimate_scepter_2",
	"item_travel_boots_2",
	"item_moon_shard",
}
sRoleItemsBuyList["pos_3"] = {
	"item_tango",
	"item_double_branches",
	"item_quelling_blade",
	"item_double_gauntlets",
	"item_magic_wand",
	"item_double_bracer",
	"item_phase_boots",
	"item_blade_mail",
	"item_ultimate_scepter",
	"item_aghanims_shard",
	"item_black_king_bar",
	"item_greater_crit",
	"item_shivas_guard",
	"item_sheepstick",
	"item_travel_boots",
	"item_heart",
	"item_travel_boots_2",
	"item_ultimate_scepter_2",
	"item_moon_shard",
}
sRoleItemsBuyList["pos_1"] = sRoleItemsBuyList["pos_3"]
-- Support builds: Hand of Midas, Basher, MKB, Assault Cuirass and Abyssal Blade were carry items on a pos 4/5
-- support; swapped for save/utility items (Force Staff, Lotus Orb, Scythe of Vyse).
sRoleItemsBuyList["pos_4"] = {
	"item_priest_outfit",
	"item_mekansm",
	"item_glimmer_cape",
	"item_guardian_greaves",
	"item_force_staff",
	"item_aghanims_shard",
	"item_ultimate_scepter",
	"item_heavens_halberd",
	"item_lotus_orb",
	"item_sheepstick",
	"item_moon_shard",
	"item_ultimate_scepter_2",
}
sRoleItemsBuyList["pos_5"] = {
	"item_priest_outfit",
	"item_mekansm",
	"item_glimmer_cape",
	"item_pipe",
	"item_force_staff",
	"item_aghanims_shard",
	"item_ultimate_scepter",
	"item_heavens_halberd",
	"item_lotus_orb",
	"item_sheepstick",
	"item_moon_shard",
	"item_ultimate_scepter_2",
}
X["sBuyList"] = sRoleItemsBuyList[sRole]
X["sSellList"] = { "item_black_king_bar", "item_quelling_blade" }
if Fu.Role.IsPvNMode() or Fu.Role.IsAllShadow() then
	X["sBuyList"], X["sSellList"] = { "PvN_tank" }, { "item_power_treads", "item_quelling_blade" }
end
nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"] = Fu.SetUserHeroInit(nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"])
X["sSkillList"] = Fu.Skill.GetSkillList(sAbilityList, nAbilityBuildList, sTalentList, nTalentBuildList)
X["bDeafaultAbility"] = false
X["bDeafaultItem"] = false
function X.MinionThink(hMinionUnit)
	Minion.MinionThink(hMinionUnit)
end
local torrentAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[1]), "sAbilityList[1]", "kunkka")
local tidebringerAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[2]), "sAbilityList[2]", "kunkka")
local xMarksAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[3]), "sAbilityList[3]", "kunkka")
local returnAbility = SafeAbility(bot:GetAbilityByName("kunkka_return"), "kunkka_return", "kunkka")
local tidalWaveAbility = SafeAbility(bot:GetAbilityByName("kunkka_tidal_wave"), "kunkka_tidal_wave", "kunkka")
local ghostshipAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[6]), "sAbilityList[6]", "kunkka")
local torrentDesire, torrentLocation
local tidebringerDesire, tidebringerTarget
local xMarksDesire, xMarksTarget
local tidalWaveDesire, tidalWaveLocation
local unusedDesire
local unusedTarget
local ghostshipDesire, ghostshipLocation
local combo1Desire, combo1Target, combo1Location
local combo2Desire, combo2Target, combo2Location
local combo3Desire, combo3Target, combo3Location
local combo1StartTime = 0
local combo2StartTime = 0
local combo3StartTime = 0
local combo1ReturnDelay = 2.25
local combo2ReturnDelay = 3.35
local combo3ReturnDelay = 1.95
function X.SkillsComplement()
	if not bot:IsAlive() then
		combo1StartTime = 0
		combo2StartTime = 0
		combo3StartTime = 0
	end
	if Fu.CanNotUseAbility(bot) or bot:IsInvisible() then
		return
	end
	-- none of its fields are read here; kept for its side effect (the [OHA-CORNERED] log)
	AbilityContext.Build(bot)
	if
		returnAbility:IsHidden() == false
		and returnAbility:IsFullyCastable()
		and (combo3StartTime ~= 0 and DotaTime() >= combo3StartTime + combo3ReturnDelay or combo1StartTime ~= 0 and DotaTime() >= combo1StartTime + combo1ReturnDelay or combo2StartTime ~= 0 and DotaTime() >= combo2StartTime + combo2ReturnDelay)
	then
		combo1StartTime = 0
		combo2StartTime = 0
		combo3StartTime = 0
		bot:Action_UseAbility(returnAbility)
		return
	end
	if returnAbility:IsHidden() == true or xMarksAbility:IsFullyCastable() then
		combo1StartTime = 0
		combo2StartTime = 0
		combo3StartTime = 0
	end
	if combo1StartTime ~= 0 or combo2StartTime ~= 0 or combo3StartTime ~= 0 then -- was "combo2StartTime ~= 0" twice; combo3StartTime is the X + Torrent combo timer
		return
	end
	combo1Desire, combo1Target, combo1Location = X.ConsiderCombo1()
	if combo1Desire > 0 then
		combo1StartTime = DotaTime()
		Fu.SetQueuePtToINT(bot, true)
		bot:ActionQueue_UseAbilityOnEntity(xMarksAbility, combo1Target)
		bot:ActionQueue_UseAbilityOnLocation(ghostshipAbility, combo1Location)
		bot:ActionQueue_UseAbilityOnLocation(torrentAbility, combo1Location)
		return
	end
	combo2Desire, combo2Target, combo2Location = X.ConsiderCombo2()
	if combo2Desire > 0 then
		combo2StartTime = DotaTime()
		Fu.SetQueuePtToINT(bot, true)
		bot:ActionQueue_UseAbilityOnEntity(xMarksAbility, combo2Target)
		bot:ActionQueue_UseAbilityOnLocation(ghostshipAbility, combo2Location)
		return
	end
	combo3Desire, combo3Target, combo3Location = X.ConsiderCombo3()
	if combo3Desire > 0 then
		combo3StartTime = DotaTime()
		Fu.SetQueuePtToINT(bot, true)
		bot:ActionQueue_UseAbilityOnEntity(xMarksAbility, combo3Target)
		bot:ActionQueue_UseAbilityOnLocation(torrentAbility, combo3Location)
		return
	end
	torrentDesire, torrentLocation = X.ConsiderQ()
	if torrentDesire > 0 then
		Fu.SetQueuePtToINT(bot, true)
		bot:ActionQueue_UseAbilityOnLocation(torrentAbility, torrentLocation)
		return
	end
	xMarksDesire, xMarksTarget = X.ConsiderE()
	if xMarksDesire > 0 then
		Fu.SetQueuePtToINT(bot, false)
		bot:ActionQueue_UseAbilityOnEntity(xMarksAbility, xMarksTarget)
		return
	end
	ghostshipDesire, ghostshipLocation = X.ConsiderR()
	if ghostshipDesire > 0 then
		Fu.SetQueuePtToINT(bot, true)
		bot:ActionQueue_UseAbilityOnLocation(ghostshipAbility, ghostshipLocation)
		return
	end
	tidalWaveDesire, tidalWaveLocation = X.ConsiderAS()
	if tidalWaveDesire > 0 then
		Fu.SetQueuePtToINT(bot, true)
		bot:ActionQueue_UseAbilityOnLocation(tidalWaveAbility, tidalWaveLocation)
		return
	end
	tidebringerDesire, tidebringerTarget = X.ConsiderW()
	if tidebringerDesire > 0 then
		bot:Action_ClearActions(false)
		bot:ActionQueue_UseAbilityOnEntity(tidebringerAbility, tidebringerTarget)
		return
	end
end
function X.GetTowardsFountainLocation(location, distance)
	local towardsLocation = {}
	if GetTeam() == TEAM_RADIANT then
		towardsLocation[1] = location[1] - distance / math.sqrt(2)
		towardsLocation[2] = location[2] - distance / math.sqrt(2)
	end
	if GetTeam() == TEAM_DIRE then
		towardsLocation[1] = location[1] + distance / math.sqrt(2)
		towardsLocation[2] = location[2] + distance / math.sqrt(2)
	end
	return Vector(towardsLocation[1], towardsLocation[2])
end
function X.ConsiderCombo1()
	if not torrentAbility:IsFullyCastable() or not xMarksAbility:IsFullyCastable() or not ghostshipAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local mana = bot:GetMana()
	local comboManaCost = torrentAbility:GetManaCost() + xMarksAbility:GetManaCost() + ghostshipAbility:GetManaCost()
	if comboManaCost > mana then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castRange = xMarksAbility:GetCastRange() + 38
	if Fu.IsGoingOnSomeone(bot) then
		local target = bot:GetTarget()
		if
			Fu.IsValidHero(target)
			and Fu.CanCastOnNonMagicImmune(target)
			and GetUnitToUnitDistance(target, bot) > castRange / 2
			and GetUnitToUnitDistance(target, bot) < castRange
		then
			return BOT_ACTION_DESIRE_HIGH, target, Fu.GetFaceTowardDistanceLocation(target, 30)
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function X.ConsiderCombo2()
	if not ghostshipAbility:IsFullyCastable() or not xMarksAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil, {}
	end
	local mana = bot:GetMana()
	local comboManaCost = ghostshipAbility:GetManaCost() + xMarksAbility:GetManaCost()
	if comboManaCost > mana then
		return BOT_ACTION_DESIRE_NONE, nil, {}
	end
	local castRange = xMarksAbility:GetCastRange() + 38
	if Fu.IsGoingOnSomeone(bot) then
		local target = bot:GetTarget()
		if Fu.IsValidHero(target) and Fu.CanCastOnNonMagicImmune(target) and GetUnitToUnitDistance(target, bot) < castRange then
			return BOT_ACTION_DESIRE_HIGH, target, target:GetLocation()
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil, {}
end
function X.ConsiderCombo3()
	if not torrentAbility:IsFullyCastable() or not xMarksAbility:IsFullyCastable() or ghostshipAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil, {}
	end
	local mana = bot:GetMana()
	local comboManaCost = torrentAbility:GetManaCost() + xMarksAbility:GetManaCost()
	if comboManaCost > mana then
		return BOT_ACTION_DESIRE_NONE, nil, {}
	end
	local castRange = xMarksAbility:GetCastRange() + 38
	local nearbyEnemies = Fu.GetNearbyHeroes(bot, castRange + 200, true, BOT_MODE_NONE)
	for _, enemy in pairs(nearbyEnemies) do
		if enemy:IsChanneling() then
			return BOT_ACTION_DESIRE_MODERATE, enemy, enemy:GetLocation()
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		local target = bot:GetTarget()
		if Fu.IsValidHero(target) and Fu.CanCastOnNonMagicImmune(target) and GetUnitToUnitDistance(target, bot) < castRange then
			return BOT_ACTION_DESIRE_HIGH, target, Fu.GetFaceTowardDistanceLocation(target, 40)
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil, {}
end
function X.ConsiderQ()
	if not torrentAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castPoint = torrentAbility:GetCastPoint()
	local torrentDelay = torrentAbility:GetSpecialValueFloat("delay")
	if bot:GetActiveMode() == BOT_MODE_ROSHAN then
		local target = bot:GetAttackTarget()
		if Fu.IsRoshan(target) and Fu.CanCastOnMagicImmune(target) and Fu.IsInRange(target, bot, 600) then
			return BOT_ACTION_DESIRE_LOW, target:GetLocation()
		end
	end
	if Fu.IsRetreating(bot) then
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, 1000, true, BOT_MODE_NONE)
		for _, enemy in pairs(nearbyEnemies) do
			if bot:WasRecentlyDamagedByHero(enemy, 1.0) then
				return BOT_ACTION_DESIRE_MODERATE, enemy:GetExtrapolatedLocation((torrentDelay + castPoint) * 0.68)
			end
		end
	end
	local nearbyEnemies = Fu.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE)
	for _, enemy in pairs(nearbyEnemies) do
		if enemy:IsChanneling() then
			if DotaTime() >= (bot._kunkkaLogAt or -999) then
				bot._kunkkaLogAt = DotaTime() + 3
				pcall(print, string.format("[OHA-KUNKKA] t=%.0f torrent-channel target=%s", DotaTime(), enemy:GetUnitName()))
			end
			return BOT_ACTION_DESIRE_MODERATE, enemy:GetLocation()
		end
	end
	-- Hold Torrent for the X combos only after the retreat and channel-cut checks above: the hold used
	-- to come first, so with X ready (level 3+) Kunkka never Torrented to escape or to cut a channel,
	-- and Combo3 (X + Torrent on a channeller) is also off while Ghostship is ready.
	if xMarksAbility:GetLevel() >= 3 and xMarksAbility:IsFullyCastable() and bot:GetMana() > 160 then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	if Fu.IsGoingOnSomeone(bot) then
		local target = bot:GetTarget()
		if
			Fu.IsValidHero(target)
			and not Fu.IsRunning(target)
			and not Fu.IsMoving(target)
			and Fu.CanCastOnNonMagicImmune(target)
			and GetUnitToUnitDistance(target, bot) < 700
		then
			return BOT_ACTION_DESIRE_HIGH, target:GetExtrapolatedLocation((torrentDelay + castPoint) * 0.68)
		end
	end
	return BOT_ACTION_DESIRE_NONE, {}
end
function X.ConsiderE()
	if not xMarksAbility:IsFullyCastable() or torrentAbility:IsFullyCastable() or ghostshipAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castRange = xMarksAbility:GetCastRange()
	if Fu.IsRetreating(bot) then
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, 1000, true, BOT_MODE_NONE)
		for _, enemy in pairs(nearbyEnemies) do
			if bot:WasRecentlyDamagedByHero(enemy, 1.0) and Fu.CanCastOnNonMagicImmune(enemy) then
				return BOT_ACTION_DESIRE_MODERATE, enemy
			end
		end
	end
	local nearbyEnemies = Fu.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE)
	for _, enemy in pairs(nearbyEnemies) do
		-- X alone on a channelling enemy was a wasted cast: nothing in this branch triggers Return, so the
		-- enemy was sent back to the spot it was already channelling on. Removed; Torrent covers channels.
		-- Range and magic-immunity checks added (X range is 550-1000, this list reaches 1200).
		if
			bot:GetActiveMode() == BOT_MODE_ATTACK
			and #nearbyEnemies == 1
			and bot:GetLevel() >= 6
			and Fu.IsInRange(bot, enemy, castRange)
			and Fu.CanCastOnNonMagicImmune(enemy)
			and bot:IsFacingLocation(enemy:GetLocation(), 30)
			and enemy:IsFacingLocation(Fu.GetEnemyFountain(), 30)
		then
			return BOT_ACTION_DESIRE_MODERATE, enemy
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function X.ConsiderR()
	-- Ghostship alone was blocked whenever X was ready. The X combos only run while going on someone,
	-- so in a fight in any other mode (defending, retreating) Ghostship was never cast. Only defer to
	-- the combos when they can actually run.
	if not ghostshipAbility:IsFullyCastable() or xMarksAbility:IsFullyCastable() and Fu.IsGoingOnSomeone(bot) then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castRange = ghostshipAbility:GetCastRange()
	local ghostshipWidth = ghostshipAbility:GetSpecialValueInt("ghostship_width")
	-- The retreat Ghostship keeps the old X gate (only while X is on cooldown), so the looser gate
	-- above does not spend the ultimate on every retreat.
	if Fu.IsRetreating(bot) and not xMarksAbility:IsFullyCastable() then
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, 1000, true, BOT_MODE_NONE)
		for _, enemy in pairs(nearbyEnemies) do
			if bot:WasRecentlyDamagedByHero(enemy, 1.0) then
				return BOT_ACTION_DESIRE_MODERATE, X.GetTowardsFountainLocation(bot:GetLocation(), castRange - 200)
			end
		end
	end
	local nearbyEnemies = Fu.GetNearbyHeroes(bot, 1000, true, BOT_MODE_NONE)
	for _, enemy in pairs(nearbyEnemies) do
		if enemy:IsChanneling() then
			return BOT_ACTION_DESIRE_MODERATE, enemy:GetLocation()
		end
	end
	if Fu.IsInTeamFight(bot, 1200) then
		local aoe = bot:FindAoELocation(true, true, bot:GetLocation(), castRange * 0.8, ghostshipWidth, 0.8, 0)
		local enemyList = Fu.GetEnemyList(bot, 1200)
		if aoe.count >= 3 and #enemyList >= 2 then
			return BOT_ACTION_DESIRE_MODERATE, aoe.targetloc
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function X.ConsiderW()
	if not Fu.IsRunning(bot) or tidebringerAbility == nil or not tidebringerAbility:IsFullyCastable() then
		return 0
	end
	local target = Fu.GetProperTarget(bot)
	if not Fu.IsValid(target) then
		return 0
	end
	local attackRange = bot:GetAttackRange() + 40
	if attackRange < 200 then
		attackRange = 200
	end
	local frontUnit = X.GetNearbyUnit(bot, target)
	-- Only stop to cleave a unit in front when the cleave (cleave_distance 650-1025, game KV) reaches the
	-- real target; it used to fire whenever the target was out of attack range, which stalled chases.
	local cleave = tidebringerAbility:GetSpecialValueInt("cleave_distance")
	if Fu.IsValid(frontUnit) and GetUnitToUnitDistance(target, bot) > attackRange and GetUnitToUnitDistance(frontUnit, target) <= cleave * 0.8 then
		return BOT_ACTION_DESIRE_HIGH, frontUnit
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.GetNearbyUnit(bot, target)
	if bot:IsFacingLocation(target:GetLocation(), 39) then
		local nearbyCreeps = bot:GetNearbyCreeps(240, true)
		for _, creep in pairs(nearbyCreeps) do
			if Fu.IsValid(creep) and bot:IsFacingLocation(creep:GetLocation(), 38) then
				return creep
			end
		end
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, 240, true, BOT_MODE_NONE)
		for _, enemy in pairs(nearbyEnemies) do
			if Fu.IsValid(enemy) and bot:IsFacingLocation(enemy:GetLocation(), 38) then
				return enemy
			end
		end
	end
	return nil
end
function X.ConsiderAS()
	if not tidalWaveAbility:IsTrained() or not tidalWaveAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local radius = 350
	local castRange = 750
	local castPoint = tidalWaveAbility:GetCastPoint()
	local manaCost = tidalWaveAbility:GetManaCost()
	if Fu.IsRetreating(bot) then
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
		local target = nearbyEnemies[1]
		if Fu.IsValidHero(target) and Fu.CanCastOnNonMagicImmune(target) then
			return BOT_ACTION_DESIRE_HIGH, target:GetLocation()
		end
	end
	if Fu.IsInTeamFight(bot, 1400) then
		local aoeLocation = Fu.GetAoeEnemyHeroLocation(bot, castRange, radius, 2)
		if aoeLocation ~= nil then
			local mirroredLocation = bot:GetLocation() + bot:GetLocation() - aoeLocation
			return BOT_ACTION_DESIRE_HIGH, aoeLocation
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		local target = Fu.GetProperTarget(bot)
		if Fu.IsValidHero(target) and Fu.IsInRange(bot, target, 400) and Fu.CanCastOnNonMagicImmune(target) then
			local mirroredLocation = bot:GetLocation() + bot:GetLocation() - target:GetLocation()
			return BOT_ACTION_DESIRE_HIGH, mirroredLocation
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
return X
