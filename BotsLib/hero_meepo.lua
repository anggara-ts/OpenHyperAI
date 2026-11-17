-- Meepo: skill build, item build, and ability use for this hero.
local X = {}
local bot = GetBot()
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local AbilityContext = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local Minion = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local sTalentList = Fu.Skill.GetTalentList(bot)
local sAbilityList = Fu.Skill.GetAbilityList(bot)
local sRole = Fu.Item.GetRoleItemsBuyList(bot)
-- 7.41b moved +Poof Damage onto the level 15 pair.
local tTalentTreeList = { ["t25"] = { 10, 0 }, ["t20"] = { 0, 10 }, ["t15"] = { 10, 0 }, ["t10"] = { 10, 0 } }
local tAllAbilityBuildList = { { 2, 3, 6, 1, 2, 2, 2, 3, 3, 6, 3, 1, 1, 1, 6, 6 } }
local nAbilityBuildList = Fu.Skill.GetRandomBuild(tAllAbilityBuildList)
local nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList)
local sRoleItemsBuyList = {}
sRoleItemsBuyList["pos_1"] = {
	"item_tango",
	"item_double_branches",
	"item_quelling_blade",
	"item_wraith_band",
	"item_boots",
	"item_magic_wand",
	"item_power_treads",
	"item_diffusal_blade",
	"item_sange_and_yasha",
	"item_aghanims_shard",
	"item_blink",
	"item_skadi",
	"item_nullifier",
	"item_ultimate_scepter",
	"item_disperser",
	"item_ultimate_scepter_2",
	"item_swift_blink",
	"item_travel_boots_2",
}
sRoleItemsBuyList["pos_2"] = {
	"item_tango",
	"item_double_branches",
	"item_quelling_blade",
	"item_wraith_band",
	"item_boots",
	"item_magic_wand",
	"item_power_treads",
	"item_diffusal_blade",
	"item_sange_and_yasha",
	"item_aghanims_shard",
	"item_blink",
	"item_skadi",
	"item_ultimate_scepter",
	"item_disperser",
	"item_ultimate_scepter_2",
	"item_swift_blink",
	"item_travel_boots_2",
}
sRoleItemsBuyList["pos_3"] = {
	"item_tango",
	"item_double_branches",
	"item_quelling_blade",
	"item_wraith_band",
	"item_boots",
	"item_magic_wand",
	"item_power_treads",
	"item_diffusal_blade",
	"item_aghanims_shard",
	"item_blink",
	"item_skadi",
	"item_ultimate_scepter",
	"item_sheepstick",
	"item_disperser",
	"item_ultimate_scepter_2",
	"item_swift_blink",
	"item_travel_boots_2",
}
sRoleItemsBuyList["pos_4"] = sRoleItemsBuyList["pos_3"]
sRoleItemsBuyList["pos_5"] = sRoleItemsBuyList["pos_3"]
X["sBuyList"] = sRoleItemsBuyList[sRole]
X["sSellList"] = { "item_wraith_band", "item_quelling_blade", "item_magic_wand" }
if Fu.Role.IsPvNMode() or Fu.Role.IsAllShadow() then
	X["sBuyList"], X["sSellList"] = { "PvN_mid" }, {}
end
nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"] =
	Fu.SetUserHeroInit(nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"])
X["sSkillList"] = Fu.Skill.GetSkillList(sAbilityList, nAbilityBuildList, sTalentList, nTalentBuildList)
X["bDeafaultAbility"] = false
X["bDeafaultItem"] = false
function X.MinionThink(minionUnit)
	Minion.MinionThink(minionUnit)
end
local function isNearRecentEarthbind(location, radius)
	local now = GameTime()
	local minDistance = radius * 1.5
	for _, meepo in pairs(GetUnitList(UNIT_LIST_ALLIED_HEROES)) do
		if
			meepo ~= bot
			and Fu.IsValidHero(meepo)
			and meepo:GetUnitName() == "npc_dota_hero_meepo"
			and meepo.earth_bind_cast ~= nil
			and now - meepo.earth_bind_cast.time < 2.0
		then
			local distanceToCast = GetUnitToLocationDistance(bot, meepo.earth_bind_cast.location)
			local dx = location.x - meepo.earth_bind_cast.location.x
			local dy = location.y - meepo.earth_bind_cast.location.y
			local distance = math.sqrt(dx * dx + dy * dy)
			if distance < minDistance then
				return true
			end
		end
	end
	return false
end
local function rememberEarthbindCast(location)
	bot.earth_bind_cast = { time = GameTime(), location = location }
end
local earthbindAbility = SafeAbility(bot:GetAbilityByName("meepo_earthbind"), "meepo_earthbind", "meepo")
local poofAbility = SafeAbility(bot:GetAbilityByName("meepo_poof"), "meepo_poof", "meepo")
local digAbility = SafeAbility(bot:GetAbilityByName("meepo_petrify"), "meepo_petrify", "meepo")
local megaMeepoAbility = SafeAbility(bot:GetAbilityByName("meepo_megameepo"), "meepo_megameepo", "meepo")
local megaMeepoFlingAbility =
	SafeAbility(bot:GetAbilityByName("meepo_megameepo_fling"), "meepo_megameepo_fling", "meepo")
local earthbindDesire, earthbindLocation
local poofDesire, poofTarget
local digDesire
local megaMeepoDesire
local flingDesire, flingTarget
local meepos = {}
local botTarget
local hpRatio
local isAttacking
local isGoingOnSomeone
local isRetreating
local mpRatio
function X.SkillsComplement()
	if Fu.CanNotUseAbility(bot) then
		return
	end
	local context = AbilityContext.Build(bot)
	isGoingOnSomeone = context.isEngaging
	isRetreating = context.isRetreating
	mpRatio = context.mp
	earthbindAbility = SafeAbility(bot:GetAbilityByName("meepo_earthbind"), "meepo_earthbind", "meepo")
	poofAbility = SafeAbility(bot:GetAbilityByName("meepo_poof"), "meepo_poof", "meepo")
	digAbility = SafeAbility(bot:GetAbilityByName("meepo_petrify"), "meepo_petrify", "meepo")
	megaMeepoAbility = SafeAbility(bot:GetAbilityByName("meepo_megameepo"), "meepo_megameepo", "meepo")
	megaMeepoFlingAbility = SafeAbility(bot:GetAbilityByName("meepo_megameepo_fling"), "meepo_megameepo_fling", "meepo")
	meepos = Fu.GetMeepos()
	botTarget = context.target
	hpRatio = context.hp
	isAttacking = Fu.IsAttacking(bot)
	poofDesire, poofTarget = X.ConsiderPoof()
	if poofDesire > 0 then
		Fu.SetQueuePtToINT(bot, false)
		bot:ActionQueue_UseAbilityOnEntity(poofAbility, poofTarget)
		return
	end
	digDesire = X.ConsiderDig()
	if digDesire > 0 then
		bot:ActionQueue_UseAbility(digAbility)
		return
	end
	megaMeepoDesire = X.ConsiderMegaMeepo()
	if megaMeepoDesire > 0 then
		bot:ActionQueue_UseAbility(megaMeepoAbility)
		return
	end
	earthbindDesire, earthbindLocation = X.ConsiderEarthBind()
	if earthbindDesire > 0 then
		Fu.SetQueuePtToINT(bot, false)
		bot:ActionQueue_UseAbilityOnLocation(earthbindAbility, earthbindLocation)
		rememberEarthbindCast(earthbindLocation)
		return
	end
	flingDesire, flingTarget = X.ConsiderMegaMeepoFling()
	if flingDesire > 0 then
		bot:ActionQueue_UseAbilityOnEntity(megaMeepoFlingAbility, flingTarget)
		return
	end
end
function X.ConsiderEarthBind()
	if not earthbindAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local castRange = Fu.GetProperCastRange(false, bot, earthbindAbility:GetCastRange())
	local castPoint = earthbindAbility:GetCastPoint()
	local radius = earthbindAbility:GetSpecialValueInt("radius")
	local speed = earthbindAbility:GetSpecialValueInt("speed")
	local modeDesire = bot:GetActiveModeDesire()
	local enemyHeroes = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(enemyHeroes) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and Fu.IsInRange(bot, enemyHero, castRange)
			and (enemyHero:IsChanneling() or Fu.IsCastingUltimateAbility(enemyHero))
			and not Fu.IsSuspiciousIllusion(enemyHero)
		then
			local castLocation = enemyHero:GetLocation()
			if not isNearRecentEarthbind(castLocation, radius) then
				return BOT_ACTION_DESIRE_HIGH, castLocation
			end
		end
	end
	if Fu.IsInTeamFight(bot, 1200) then
		local aoe = bot:FindAoELocation(true, true, bot:GetLocation(), castRange, radius, castPoint, 0)
		if aoe.count >= 2 then
			if not isNearRecentEarthbind(aoe.targetloc, radius) then
				return BOT_ACTION_DESIRE_HIGH, aoe.targetloc
			end
		end
	end
	if isGoingOnSomeone then
		local allyHeroes = Fu.GetNearbyHeroes(bot, 1000, false, BOT_MODE_NONE)
		local nearbyEnemyHeroes = Fu.GetNearbyHeroes(bot, 800, true, BOT_MODE_NONE)
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not Fu.IsDisabled(botTarget)
			and not Fu.IsTaunted(botTarget)
			and not botTarget:HasModifier("modifier_enigma_black_hole_pull")
			and not botTarget:HasModifier("modifier_faceless_void_chronosphere_freeze")
			and not botTarget:HasModifier("modifier_meepo_earthbind")
			and allyHeroes ~= nil
			and nearbyEnemyHeroes
			and #allyHeroes >= #nearbyEnemyHeroes
		then
			local delay = GetUnitToUnitDistance(bot, botTarget) / speed + castPoint
			local castLocation = botTarget:GetExtrapolatedLocation(delay)
			if not isNearRecentEarthbind(castLocation, radius) then
				return BOT_ACTION_DESIRE_HIGH, castLocation
			end
		end
	end
	if isRetreating and modeDesire > BOT_ACTION_DESIRE_HIGH then
		local allyHeroes = Fu.GetNearbyHeroes(bot, 800, false, BOT_MODE_NONE)
		local nearbyEnemyHeroes = Fu.GetNearbyHeroes(bot, 800, true, BOT_MODE_NONE)
		if
			allyHeroes ~= nil
			and nearbyEnemyHeroes
			and (#nearbyEnemyHeroes > #allyHeroes or hpRatio < 0.62 and bot:WasRecentlyDamagedByAnyHero(2))
			and Fu.IsValidHero(nearbyEnemyHeroes[1])
			and Fu.CanCastOnNonMagicImmune(nearbyEnemyHeroes[1])
			and Fu.IsInRange(bot, nearbyEnemyHeroes[1], castRange)
			and not Fu.IsSuspiciousIllusion(nearbyEnemyHeroes[1])
			and not Fu.IsDisabled(nearbyEnemyHeroes[1])
			and not nearbyEnemyHeroes[1]:HasModifier("modifier_meepo_earthbind")
		then
			local delay = GetUnitToUnitDistance(bot, nearbyEnemyHeroes[1]) / speed + castPoint
			local castLocation = nearbyEnemyHeroes[1]:GetExtrapolatedLocation(delay)
			if not isNearRecentEarthbind(castLocation, radius) then
				return BOT_ACTION_DESIRE_HIGH, castLocation
			end
		end
	end
	local allyHeroesInRange = Fu.GetNearbyHeroes(bot, castRange, false, BOT_MODE_NONE)
	for _, allyHero in pairs(allyHeroesInRange) do
		local allyEnemies = Fu.GetNearbyHeroes(allyHero, castRange, true, BOT_MODE_NONE)
		if
			Fu.IsRetreating(allyHero)
			and allyHero:WasRecentlyDamagedByAnyHero(2.1)
			and not allyHero:IsIllusion()
			and mpRatio > 0.48
		then
			if
				allyEnemies ~= nil
				and #allyEnemies >= 1
				and Fu.IsValidHero(allyEnemies[1])
				and Fu.CanCastOnNonMagicImmune(allyEnemies[1])
				and Fu.IsInRange(allyHero, allyEnemies[1], 400)
				and Fu.IsInRange(bot, allyEnemies[1], castRange)
				and Fu.IsRunning(allyHero)
				and allyEnemies[1]:IsFacingLocation(allyHero:GetLocation(), 30)
				and not Fu.IsDisabled(allyEnemies[1])
				and not Fu.IsTaunted(allyEnemies[1])
				and not Fu.IsSuspiciousIllusion(allyEnemies[1])
				and not allyEnemies[1]:HasModifier("modifier_enigma_black_hole_pull")
				and not allyEnemies[1]:HasModifier("modifier_faceless_void_chronosphere_freeze")
				and not allyEnemies[1]:HasModifier("modifier_meepo_earthbind")
			then
				local delay = GetUnitToUnitDistance(bot, allyEnemies[1]) / speed + castPoint
				local castLocation = allyEnemies[1]:GetExtrapolatedLocation(delay + castPoint)
				if not isNearRecentEarthbind(castLocation, radius) then
					return BOT_ACTION_DESIRE_HIGH, castLocation
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.ConsiderPoof()
	if not poofAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local radius = poofAbility:GetSpecialValueInt("radius")
	-- Poof has no AbilityDamage in the game data; its damage is the special value "poof_damage"
	-- (50/80/110/140). GetAbilityDamage() gave 0, so the lane last-hit Poofs never fired.
	local poofDamage = poofAbility:GetSpecialValueInt("poof_damage")
	if hpRatio < 0.5 and isRetreating then
		for _, meepo in pairs(meepos) do
			if meepo ~= bot and meepo:DistanceFromFountain() < 800 and not Fu.IsStunProjectileIncoming(bot, 400) then
				return BOT_ACTION_DESIRE_ABSOLUTE, meepo
			end
		end
	end
	if (Fu.IsPushing(bot) or Fu.IsDefending(bot)) and not isRetreating then
		local laneFront = GetLaneFrontLocation(GetTeam(), bot:GetAssignedLane(), 0)
		for _, meepo in pairs(meepos) do
			if
				meepo ~= bot
				and GetUnitToLocationDistance(meepo, laneFront) < 1200
				and GetUnitToLocationDistance(bot, laneFront) > 3200
				and hpRatio > 0.6
			then
				return BOT_ACTION_DESIRE_HIGH, meepo
			end
		end
	end
	if hpRatio > 0.5 and not isRetreating then
		for _, meepo in pairs(meepos) do
			if
				meepo ~= bot
				and Fu.IsRetreating(meepo)
				and meepo:WasRecentlyDamagedByAnyHero(2.0)
				and Fu.GetHP(meepo) < 0.5
				and GetUnitToUnitDistance(bot, meepo) > 1200
			then
				local meepoAllies = Fu.GetNearbyHeroes(meepo, 1200, false, BOT_MODE_NONE)
				local meepoEnemies = Fu.GetNearbyHeroes(meepo, 1200, true, BOT_MODE_NONE)
				if
					meepoAllies ~= nil
					and meepoEnemies ~= nil
					and #meepoAllies >= #meepoEnemies
					and #meepoEnemies >= 1
				then
					return BOT_ACTION_DESIRE_HIGH, meepo
				end
			end
		end
	end
	for _, meepo in pairs(meepos) do
		local meepoTarget = meepo:GetAttackTarget()
		if Fu.IsGoingOnSomeone(meepo) then
			local meepoAllies = Fu.GetNearbyHeroes(meepo, 1000, false, BOT_MODE_NONE)
			local meepoEnemies = Fu.GetNearbyHeroes(meepo, 800, true, BOT_MODE_NONE)
			if
				Fu.IsValidTarget(meepoTarget)
				and Fu.IsInRange(meepo, meepoTarget, 800)
				and not isRetreating
				and not Fu.IsSuspiciousIllusion(meepoTarget)
				and meepoAllies ~= nil
				and meepoEnemies
				and #meepoAllies >= #meepoEnemies
				and GetUnitToUnitDistance(bot, meepo) > 1600
			then
				return BOT_ACTION_DESIRE_HIGH, meepo
			end
		end
		if Fu.IsLaning(bot) and Fu.IsLaning(meepo) and meepo ~= bot then
			local laneFront = GetLaneFrontLocation(GetTeam(), bot:GetAssignedLane(), 0)
			if
				GetUnitToLocationDistance(bot, laneFront) > 1600
				and GetUnitToLocationDistance(meepo, laneFront) < 600
			then
				return BOT_ACTION_DESIRE_HIGH, meepo
			end
		end
		if Fu.IsDoingRoshan(meepo) then
			local meepoEnemies = Fu.GetNearbyHeroes(meepo, 800, true, BOT_MODE_NONE)
			if
				Fu.IsRoshan(meepoTarget)
				and Fu.IsInRange(meepo, meepoTarget, 400)
				and Fu.GetHP(meepoTarget) > 0.33
				and meepoEnemies ~= nil
				and #meepoEnemies == 0
			then
				return BOT_ACTION_DESIRE_HIGH, meepo
			end
		end
		if Fu.IsDoingTormentor(meepo) then
			local meepoEnemies = Fu.GetNearbyHeroes(meepo, 800, true, BOT_MODE_NONE)
			if
				Fu.IsTormentor(meepoTarget)
				and Fu.IsInRange(meepo, meepoTarget, 400)
				and meepoEnemies ~= nil
				and #meepoEnemies == 0
			then
				return BOT_ACTION_DESIRE_HIGH, meepo
			end
		end
		if hpRatio < 0.3 and isRetreating and meepo ~= bot and meepo:DistanceFromFountain() < 500 then
			return BOT_ACTION_DESIRE_HIGH, meepo
		end
	end
	if isRetreating then
		local allyHeroes = Fu.GetNearbyHeroes(bot, 800, false, BOT_MODE_NONE)
		local nearbyEnemyHeroes = Fu.GetNearbyHeroes(bot, 800, true, BOT_MODE_NONE)
		if
			allyHeroes ~= nil
			and nearbyEnemyHeroes
			and (#nearbyEnemyHeroes > #allyHeroes or hpRatio < 0.8 and bot:WasRecentlyDamagedByAnyHero(1.3))
			and Fu.IsValidHero(nearbyEnemyHeroes[1])
			and Fu.CanCastOnNonMagicImmune(nearbyEnemyHeroes[1])
			and Fu.IsInRange(bot, nearbyEnemyHeroes[1], 1000)
			and Fu.IsRunning(nearbyEnemyHeroes[1])
			and nearbyEnemyHeroes[1]:IsFacingLocation(bot:GetLocation(), 30)
			and not Fu.IsSuspiciousIllusion(nearbyEnemyHeroes[1])
		then
			local farthestMeepo = nil
			local farthestDistance = 0
			for _, meepo in pairs(meepos) do
				-- Was the farthest Meepo whatever its state: a Meepo fighting elsewhere is no escape.
				-- Only a Meepo with no enemy hero within 1200 counts.
				local meepoEnemies = Fu.GetNearbyHeroes(meepo, 1200, true, BOT_MODE_NONE)
				if
					(meepoEnemies == nil or #meepoEnemies == 0)
					and GetUnitToUnitDistance(bot, meepo) > farthestDistance
				then
					farthestMeepo = meepo
					farthestDistance = GetUnitToUnitDistance(bot, meepo)
				end
			end
			if farthestMeepo ~= nil and farthestMeepo ~= bot then
				return BOT_ACTION_DESIRE_HIGH, farthestMeepo
			end
		end
	end
	if Fu.IsFarming(bot) then
		if isAttacking then
			local laneCreeps = bot:GetNearbyLaneCreeps(radius, true)
			if laneCreeps ~= nil and #laneCreeps >= 3 and mpRatio > 0.33 then
				return BOT_ACTION_DESIRE_HIGH, bot
			end
			local neutralCreeps = bot:GetNearbyNeutralCreeps(radius)
			if neutralCreeps ~= nil and #neutralCreeps >= 2 and mpRatio > 0.26 then
				return BOT_ACTION_DESIRE_HIGH, bot
			end
		end
	end
	if Fu.IsLaning(bot) and mpRatio > 0.29 then
		local laneCreeps = bot:GetNearbyLaneCreeps(radius, true)
		local killableCount = 0
		for _, creep in pairs(laneCreeps) do
			if Fu.IsValid(creep) and Fu.CanKillTarget(creep, poofDamage, DAMAGE_TYPE_MAGICAL) then
				killableCount = killableCount + 1
			end
		end
		if killableCount >= 2 then
			-- [OHA-MEEPO]: lane last-hit Poof (dead before the poof_damage fix), every 10s at most.
			if DotaTime() >= (bot._poofLaneLogAt or -999) then
				bot._poofLaneLogAt = DotaTime() + 10
				pcall(
					print,
					string.format(
						"[OHA-MEEPO] t=%.0f poof-lane-lasthit creeps=%d dmg=%d",
						DotaTime(),
						killableCount,
						poofDamage
					)
				)
			end
			return BOT_ACTION_DESIRE_HIGH, bot
		end
		local nearbyEnemyHeroes = Fu.GetNearbyHeroes(bot, radius / 2.1, true, BOT_MODE_NONE)
		for _, enemyHero in pairs(nearbyEnemyHeroes) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
				and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
				and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
				and not enemyHero:HasModifier("modifier_templar_assassin_refraction_absorb")
				and mpRatio > 0.76
			then
				return BOT_ACTION_DESIRE_HIGH, bot
			end
		end
		for _, creep in pairs(laneCreeps) do
			if
				Fu.IsValid(creep)
				and (Fu.IsKeyWordUnit("ranged", creep) or Fu.IsKeyWordUnit("siege", creep) or Fu.IsKeyWordUnit(
					"flagbearer",
					creep
				))
				and Fu.CanKillTarget(creep, poofDamage, DAMAGE_TYPE_MAGICAL)
			then
				nearbyEnemyHeroes = Fu.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE)
				if
					nearbyEnemyHeroes ~= nil
					and #nearbyEnemyHeroes >= 1
					and GetUnitToUnitDistance(creep, nearbyEnemyHeroes[1]) <= 500
					and hpRatio > 0.5
					and not bot:WasRecentlyDamagedByAnyHero(2.7)
				then
					return BOT_ACTION_DESIRE_HIGH, bot
				end
			end
		end
	end
	if Fu.IsDefending(bot) or Fu.IsPushing(bot) then
		local laneCreeps = bot:GetNearbyLaneCreeps(radius, true)
		if laneCreeps ~= nil and #laneCreeps >= 4 then
			return BOT_ACTION_DESIRE_HIGH, bot
		end
	end
	if hpRatio and not isRetreating then
		for _, meepo in pairs(meepos) do
			local meepoAllies = Fu.GetNearbyHeroes(meepo, 800, false, BOT_MODE_NONE)
			local meepoEnemies = Fu.GetNearbyHeroes(meepo, 1200, true, BOT_MODE_NONE)
			if
				meepoAllies ~= nil
				and meepoEnemies ~= nil
				and (#meepos >= #meepoEnemies or #meepoAllies >= #meepoEnemies)
				and GetUnitToUnitDistance(bot, meepo) > 1600
				and meepo:WasRecentlyDamagedByAnyHero(1.1)
			then
				return BOT_ACTION_DESIRE_HIGH, meepo
			end
		end
	end
	if hpRatio and not isRetreating then
		for _, meepo in pairs(meepos) do
			local meepoAllies = Fu.GetNearbyHeroes(meepo, 800, false, BOT_MODE_NONE)
			local meepoEnemies = Fu.GetNearbyHeroes(meepo, 324, true, BOT_MODE_NONE)
			if meepoEnemies ~= nil and hpRatio - Fu.GetHP(meepo) > 0.2 then
				if
					Fu.IsValidHero(meepoEnemies[1])
					and (#meepos >= #meepoEnemies or #meepoAllies >= #meepoEnemies)
					and not Fu.IsSuspiciousIllusion(meepoEnemies[1])
					and not Fu.IsLaning(meepo)
				then
					return BOT_ACTION_DESIRE_HIGH, meepo
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function X.ConsiderDig()
	if not digAbility:IsTrained() or not digAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
	end
	if bot:HasModifier("modifier_doom_bringer_doom") then
		return BOT_ACTION_DESIRE_NONE
	end
	if bot:HasModifier("modifier_oracle_false_promise_timer") then
		return BOT_ACTION_DESIRE_NONE
	end
	if bot:HasModifier("modifier_ice_blast") then
		if not bot:WasRecentlyDamagedByAnyHero(1.5) then
			return BOT_ACTION_DESIRE_NONE
		end
	end
	if hpRatio < 0.49 then
		return BOT_ACTION_DESIRE_HIGH
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderMegaMeepo()
	if
		not megaMeepoAbility:IsTrained()
		or not megaMeepoAbility:IsFullyCastable()
		or bot:HasModifier("modifier_meepo_petrify")
	then
		return BOT_ACTION_DESIRE_NONE
	end
	local radius = 600
	if isGoingOnSomeone then
		local damagedCloneCount = 0
		for _, meepo in pairs(meepos) do
			if
				meepo:WasRecentlyDamagedByAnyHero(1.2)
				and Fu.IsMeepoClone(meepo)
				and Fu.IsInRange(bot, meepo, radius)
				and not meepo:HasModifier("modifier_meepo_petrify")
			then
				damagedCloneCount = damagedCloneCount + 1
			end
		end
		if damagedCloneCount >= 2 then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderMegaMeepoFling()
	if megaMeepoFlingAbility:IsHidden() or not megaMeepoFlingAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
	end
	local castRange = megaMeepoFlingAbility:GetCastRange()
	local allyHeroes = Fu.GetNearbyHeroes(bot, 1000, false, BOT_MODE_NONE)
	local nearbyEnemyHeroes = Fu.GetNearbyHeroes(bot, 800, true, BOT_MODE_NONE)
	if isGoingOnSomeone then
		local weakestTarget = Fu.GetAttackableWeakestUnit(bot, castRange, true, true)
		if
			weakestTarget ~= nil
			and bot:WasRecentlyDamagedByAnyHero(3.1)
			and not Fu.IsMeepoClone(bot)
			and not weakestTarget:HasModifier("modifier_faceless_void_chronosphere_freeze")
			and allyHeroes ~= nil
			and nearbyEnemyHeroes
			and #allyHeroes >= #nearbyEnemyHeroes
		then
			return BOT_ACTION_DESIRE_HIGH, weakestTarget
		end
	end
	local enemyCreeps = bot:GetNearbyCreeps(castRange, true)
	if enemyCreeps ~= nil and #enemyCreeps >= 1 and nearbyEnemyHeroes ~= nil and #nearbyEnemyHeroes == 0 then
		if Fu.IsValid(enemyCreeps[1]) and not Fu.IsMeepoClone(bot) then
			return BOT_ACTION_DESIRE_HIGH, enemyCreeps[1]
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
return X
