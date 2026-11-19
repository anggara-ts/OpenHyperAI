-- [OHA-DISRUPTOR] logs off: the behaviour they traced works (game 029).
-- Accidental globals made file-local (#13): every bot shares one Lua state, so these were shared.
local CanCastKineticStorm
local print = function() end
-- Disruptor: skill build, item build, and ability use for this hero.
local X = {}
local bot = GetBot()
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local AbilityContext = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local Minion = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local sTalentList = Fu.Skill.GetTalentList(bot)
local sAbilityList = Fu.Skill.GetAbilityList(bot)
local sRole = Fu.Item.GetRoleItemsBuyList(bot)
local tTalentTreeList = { ["t25"] = { 10, 0 }, ["t20"] = { 0, 10 }, ["t15"] = { 10, 0 }, ["t10"] = { 0, 10 } }
-- 1 Thunder Strike, 2 Glimpse, 3 Kinetic Field, 6 Static Storm (ultimate at 6, 12, 18).
-- Support: Glimpse first, then Thunder Strike, Kinetic Field last (Dotabuff most picked order).
-- Core: Thunder Strike first, then Glimpse, Kinetic Field last.
local tAllAbilityBuildList = { { 1, 2, 2, 3, 2, 6, 2, 1, 1, 1, 6, 3, 3, 3, 6 } }
if sRole ~= "pos_4" and sRole ~= "pos_5" then
	tAllAbilityBuildList = { { 1, 2, 1, 3, 1, 6, 1, 2, 2, 2, 6, 3, 3, 3, 6 } }
end
local nAbilityBuildList = Fu.Skill.GetRandomBuild(tAllAbilityBuildList)
local nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList)
local sRoleItemsBuyList = {}
sRoleItemsBuyList["pos_4"] = {
	"item_double_tango",
	"item_double_branches",
	"item_faerie_fire",
	"item_blood_grenade",
	"item_magic_wand",
	"item_arcane_boots",
	"item_glimmer_cape",
	"item_force_staff",
	"item_blink",
	"item_guardian_greaves",
	"item_ultimate_scepter",
	"item_sheepstick",
	"item_wind_waker",
	"item_aghanims_shard",
	"item_moon_shard",
	"item_ultimate_scepter_2",
}
sRoleItemsBuyList["pos_5"] = {
	"item_double_tango",
	"item_double_branches",
	"item_faerie_fire",
	"item_blood_grenade",
	"item_magic_wand",
	"item_arcane_boots",
	"item_glimmer_cape",
	"item_force_staff",
	"item_pipe",
	"item_aether_lens",
	"item_blink",
	"item_ultimate_scepter",
	"item_sheepstick",
	"item_aghanims_shard",
	"item_moon_shard",
	"item_ultimate_scepter_2",
}
sRoleItemsBuyList["pos_3"] = {
	"item_double_tango",
	"item_double_branches",
	"item_faerie_fire",
	"item_magic_wand",
	"item_arcane_boots",
	"item_glimmer_cape",
	"item_force_staff",
	"item_maelstrom",
	"item_gungir",
	"item_shivas_guard",
	"item_ultimate_scepter",
	"item_sheepstick",
	"item_wind_waker",
	"item_aghanims_shard",
	"item_moon_shard",
	"item_ultimate_scepter_2",
}
sRoleItemsBuyList["pos_1"] = sRoleItemsBuyList["pos_3"]
sRoleItemsBuyList["pos_2"] = sRoleItemsBuyList["pos_3"]
X["sBuyList"] = sRoleItemsBuyList[sRole]
X["sSellList"] = { "item_ultimate_scepter", "item_magic_wand", "item_cyclone", "item_magic_wand" }
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
local thunderStrikeAbility =
	SafeAbility(bot:GetAbilityByName("disruptor_thunder_strike"), "disruptor_thunder_strike", "disruptor")
local glimpseAbility = SafeAbility(bot:GetAbilityByName("disruptor_glimpse"), "disruptor_glimpse", "disruptor")
local kineticFieldAbility =
	SafeAbility(bot:GetAbilityByName("disruptor_kinetic_field"), "disruptor_kinetic_field", "disruptor")
local kineticFenceAbility =
	SafeAbility(bot:GetAbilityByName("disruptor_kinetic_fence"), "disruptor_kinetic_fence", "disruptor")
local staticStormAbility =
	SafeAbility(bot:GetAbilityByName("disruptor_static_storm"), "disruptor_static_storm", "disruptor")
local thunderStrikeDesire, thunderStrikeTarget
local glimpseDesire, glimpseTarget
local kineticFieldDesire, kineticFieldLocation
local kineticFenceDesire, kineticFenceLocation
local staticStormDesire, staticStormLocation
local kineticFenceCastTime = 0
local kineticStormDesire, kineticStormLocation
local botTarget
local isGoingOnSomeone
local isRetreating
local isAttacking
local isInTeamFight
-- Where each enemy hero was over the last few seconds, for the Glimpse return spot (Glimpse
-- sends the target back to where it was 4s ago, Valve data). Sampled every 0.2s.
local trail = {}
local trailAt = -99
local function RecordTrail()
	local now = DotaTime()
	if now - trailAt < 0.2 then
		return
	end
	trailAt = now
	for _, enemyHero in pairs(GetUnitList(UNIT_LIST_ENEMY_HEROES) or {}) do
		if Fu.IsValidHero(enemyHero) and enemyHero:CanBeSeen() and not enemyHero:IsIllusion() then
			local id = enemyHero:GetPlayerID()
			local list = trail[id] or {}
			list[#list + 1] = { t = now, loc = enemyHero:GetLocation() }
			while #list > 0 and now - list[1].t > 6 do
				table.remove(list, 1)
			end
			trail[id] = list
		end
	end
end
-- Where target would land if Glimpsed now, or nil when it was not seen at that moment.
function X.GlimpseReturnSpot(target)
	local back = glimpseAbility:GetSpecialValueFloat("backtrack_time")
	if back == nil or back <= 0 then
		back = 4
	end
	local want = DotaTime() - back
	local best, bestGap = nil, 0.35
	for _, sample in ipairs(trail[target:GetPlayerID()] or {}) do
		local gap = math.abs(sample.t - want)
		if gap < bestGap then
			best, bestGap = sample.loc, gap
		end
	end
	return best
end
-- Glimpse -> Kinetic Field on the return spot -> Static Storm there when 2+ enemy heroes will be
-- in it or it is a team fight. The field forms in 1s, so it is up when the target lands.
function X.ConsiderGlimpseCombo()
	if
		not (isGoingOnSomeone or isInTeamFight)
		or not glimpseAbility:IsFullyCastable()
		or not kineticFieldAbility:IsFullyCastable()
	then
		return nil
	end
	local mana = bot:GetMana() - glimpseAbility:GetManaCost() - kineticFieldAbility:GetManaCost()
	if mana < 0 then
		return nil
	end
	local range = Fu.GetProperCastRange(false, bot, glimpseAbility:GetCastRange())
	local fieldRange = kineticFieldAbility:GetCastRange() + 100
	local candidates = {}
	if Fu.IsValidHero(botTarget) then
		candidates[1] = botTarget
	end
	for _, enemyHero in pairs(Fu.GetNearbyHeroes(bot, range, true, BOT_MODE_NONE) or {}) do
		candidates[#candidates + 1] = enemyHero
	end
	for _, candidate in ipairs(candidates) do
		if
			Fu.IsValidHero(candidate)
			and Fu.IsInRange(bot, candidate, range)
			and Fu.CanCastOnNonMagicImmune(candidate)
			and Fu.CanCastOnTargetAdvanced(candidate)
			and not Fu.IsSuspiciousIllusion(candidate)
			and not Fu.IsDisabled(candidate)
			and not candidate:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			local spot = X.GlimpseReturnSpot(candidate)
			if
				spot ~= nil
				and GetUnitToLocationDistance(candidate, spot) >= 350
				and GetUnitToLocationDistance(bot, spot) <= fieldRange
			then
				local allies = #(Fu.GetNearbyHeroes(bot, 1600, false, BOT_MODE_NONE) or {})
				local foes = #(Fu.GetNearbyHeroes(candidate, 1200, false, BOT_MODE_NONE) or {})
				if allies >= foes - 1 then
					local storm = false
					if
						staticStormAbility:IsTrained()
						and staticStormAbility:IsFullyCastable()
						and mana >= staticStormAbility:GetManaCost()
					then
						local inStorm = #(
								Fu.GetEnemiesNearLoc(spot, staticStormAbility:GetSpecialValueInt("radius")) or {}
							) + 1
						storm = inStorm >= 2 or isInTeamFight
					end
					return candidate, spot, storm
				end
			end
		end
	end
	return nil
end
function X.SkillsComplement()
	RecordTrail()
	if Fu.CanNotUseAbility(bot) then
		return
	end
	local context = AbilityContext.Build(bot)
	isGoingOnSomeone = context.isEngaging
	isRetreating = context.isRetreating
	isAttacking = Fu.IsAttacking(bot)
	isInTeamFight = context.isTeamFight
	botTarget = context.target
	-- An enemy teleporting within Glimpse range: Glimpse it first. It sat last in the order,
	-- behind the storms, the fields and Thunder Strike (game 016, 62:00: no Glimpse on a TP).
	if glimpseAbility:IsFullyCastable() then
		local range = Fu.GetProperCastRange(false, bot, glimpseAbility:GetCastRange())
		for _, enemyHero in pairs(Fu.GetNearbyHeroes(bot, range, true, BOT_MODE_NONE) or {}) do
			if
				Fu.IsValidHero(enemyHero)
				and enemyHero:HasModifier("modifier_teleporting")
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
				and not Fu.IsSuspiciousIllusion(enemyHero)
			then
				pcall(
					print,
					string.format(
						"[OHA-DISRUPTOR] t=%.0f glimpse-tp target=%s dist=%d",
						DotaTime(),
						(string.gsub(enemyHero:GetUnitName(), "npc_dota_hero_", "")),
						GetUnitToUnitDistance(bot, enemyHero)
					)
				)
				bot:Action_UseAbilityOnEntity(glimpseAbility, enemyHero)
				return
			end
		end
	end
	local comboTarget, comboSpot, comboStorm = X.ConsiderGlimpseCombo()
	if comboTarget ~= nil then
		pcall(
			print,
			string.format(
				"[OHA-DISRUPTOR] t=%.0f glimpse-combo target=%s back=%d storm=%s",
				DotaTime(),
				(string.gsub(comboTarget:GetUnitName(), "npc_dota_hero_", "")),
				GetUnitToLocationDistance(comboTarget, comboSpot),
				tostring(comboStorm)
			)
		)
		bot:Action_ClearActions(false)
		bot:ActionQueue_UseAbilityOnEntity(glimpseAbility, comboTarget)
		bot:ActionQueue_Delay(0.1)
		bot:ActionQueue_UseAbilityOnLocation(kineticFieldAbility, comboSpot)
		if comboStorm then
			bot:ActionQueue_Delay(0.1)
			bot:ActionQueue_UseAbilityOnLocation(staticStormAbility, comboSpot)
		end
		return
	end
	kineticStormDesire, kineticStormLocation = X.ConsiderKineticStorm()
	if kineticStormDesire > 0 then
		-- Kinetic Field first, then Static Storm inside it (user call): the field holds them in the
		-- storm. It used to be storm first, field second.
		bot:Action_ClearActions(false)
		bot:ActionQueue_UseAbilityOnLocation(kineticFieldAbility, kineticStormLocation)
		bot:ActionQueue_Delay(0.05)
		bot:ActionQueue_UseAbilityOnLocation(staticStormAbility, kineticStormLocation)
		bot:ActionQueue_Delay(0.05)
		return
	end
	staticStormDesire, staticStormLocation = X.ConsiderStaticStorm()
	if staticStormDesire > 0 then
		bot:Action_UseAbilityOnLocation(staticStormAbility, staticStormLocation)
		return
	end
	kineticFieldDesire, kineticFieldLocation = X.ConsiderKineticField()
	if kineticFieldDesire > 0 then
		-- Static Storm on the same spot right behind the field when it is ready, an enemy hero
		-- is inside the field's radius, and he is engaging or in a team fight.
		local inField = Fu.GetEnemiesNearLoc(kineticFieldLocation, kineticFieldAbility:GetSpecialValueInt("radius"))
			or {}
		local coreIn = false
		for _, enemyHero in pairs(inField) do
			local okP, pos = pcall(Fu.GetPosition, enemyHero)
			if okP and type(pos) == "number" and pos <= 2 then
				coreIn = true
			end
		end
		-- A group (2+) in the field, or one high-value core (estimated position 1 or 2).
		local stormOk = (isGoingOnSomeone or isInTeamFight)
			and staticStormAbility:IsTrained()
			and staticStormAbility:IsFullyCastable()
			and bot:GetMana() >= kineticFieldAbility:GetManaCost() + staticStormAbility:GetManaCost()
			and (#inField >= 2 or coreIn)
		if stormOk then
			bot:Action_ClearActions(false)
			bot:ActionQueue_UseAbilityOnLocation(kineticFieldAbility, kineticFieldLocation)
			bot:ActionQueue_Delay(0.05)
			bot:ActionQueue_UseAbilityOnLocation(staticStormAbility, kineticFieldLocation)
			pcall(
				print,
				string.format(
					"[OHA-DISRUPTOR] t=%.0f field-storm at=%.0f,%.0f",
					DotaTime(),
					kineticFieldLocation.x,
					kineticFieldLocation.y
				)
			)
			return
		end
		bot:Action_UseAbilityOnLocation(kineticFieldAbility, kineticFieldLocation)
		return
	end
	kineticFenceDesire, kineticFenceLocation = X.ConsiderKineticFence()
	if kineticFenceDesire > 0 then
		bot:Action_UseAbilityOnLocation(kineticFenceAbility, kineticFenceLocation)
		kineticFenceCastTime = DotaTime()
		return
	end
	thunderStrikeDesire, thunderStrikeTarget = X.ConsiderThunderStrike()
	if thunderStrikeDesire > 0 then
		bot:Action_UseAbilityOnEntity(thunderStrikeAbility, thunderStrikeTarget)
		return
	end
	glimpseDesire, glimpseTarget = X.ConsiderGlimpse()
	if glimpseDesire > 0 then
		bot:Action_UseAbilityOnEntity(glimpseAbility, glimpseTarget)
		return
	end
end
function X.ConsiderThunderStrike()
	if not thunderStrikeAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castRange = Fu.GetProperCastRange(false, bot, thunderStrikeAbility:GetCastRange())
	local radius = thunderStrikeAbility:GetSpecialValueInt("radius")
	local strikeDamage = thunderStrikeAbility:GetSpecialValueInt("strike_damage")
	local strikeCount = thunderStrikeAbility:GetSpecialValueInt("strikes")
	local nearbyEnemies = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidTarget(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and Fu.CanCastOnTargetAdvanced(enemyHero)
			and Fu.CanKillTarget(enemyHero, strikeDamage * strikeCount, DAMAGE_TYPE_MAGICAL)
			and not Fu.IsSuspiciousIllusion(enemyHero)
			and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
			and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
			and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
			and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
			and not enemyHero:HasModifier("modifier_skeleton_king_reincarnation_scepter_active")
			and not enemyHero:HasModifier("modifier_templar_assassin_refraction_absorb")
		then
			return BOT_ACTION_DESIRE_HIGH, enemyHero
		end
	end
	local alliesInRange = Fu.GetNearbyHeroes(bot, castRange, false, BOT_MODE_NONE)
	for _, allyHero in pairs(alliesInRange) do
		local allyNearbyEnemies = Fu.GetNearbyHeroes(allyHero, 1200, true, BOT_MODE_NONE)
		if
			Fu.IsValidHero(allyHero)
			and Fu.IsRetreating(allyHero)
			and Fu.IsCore(allyHero)
			and allyHero:WasRecentlyDamagedByAnyHero(2)
			and allyHero:GetActiveModeDesire() >= 0.5
			and not allyHero:IsIllusion()
			and not glimpseAbility:IsFullyCastable()
		then
			if
				allyNearbyEnemies ~= nil
				and #allyNearbyEnemies >= 1
				and Fu.IsValidHero(allyNearbyEnemies[1])
				and Fu.CanCastOnNonMagicImmune(allyNearbyEnemies[1])
				and Fu.CanCastOnTargetAdvanced(allyNearbyEnemies[1])
				and Fu.IsInRange(bot, allyNearbyEnemies[1], castRange)
				and Fu.IsChasingTarget(allyNearbyEnemies[1], allyHero)
				and not Fu.IsChasingTarget(allyNearbyEnemies[1], bot)
				and not Fu.IsDisabled(allyNearbyEnemies[1])
				and not Fu.IsTaunted(allyNearbyEnemies[1])
				and not Fu.IsSuspiciousIllusion(allyNearbyEnemies[1])
				and not allyNearbyEnemies[1]:HasModifier("modifier_necrolyte_reapers_scythe")
			then
				return BOT_ACTION_DESIRE_HIGH, allyNearbyEnemies[1]
			end
		end
	end
	if isGoingOnSomeone then
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.CanCastOnTargetAdvanced(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange + 300)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not botTarget:HasModifier("modifier_skeleton_king_reincarnation_scepter_active")
		then
			local alliesNearTarget = Fu.GetNearbyHeroes(botTarget, 1200, true, BOT_MODE_NONE)
			local enemiesNearTarget = Fu.GetNearbyHeroes(botTarget, 1200, false, BOT_MODE_NONE)
			if alliesNearTarget ~= nil and enemiesNearTarget ~= nil and #alliesNearTarget >= #enemiesNearTarget then
				return BOT_ACTION_DESIRE_HIGH, botTarget
			end
		end
	end
	if isRetreating and bot:GetActiveModeDesire() > 0.5 then
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
				and Fu.IsChasingTarget(enemyHero, bot)
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and not Fu.IsDisabled(enemyHero)
				and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
			then
				local alliesNearTarget = Fu.GetNearbyHeroes(enemyHero, 1200, true, BOT_MODE_NONE)
				local enemiesNearTarget = Fu.GetNearbyHeroes(enemyHero, 1200, false, BOT_MODE_NONE)
				if
					alliesNearTarget ~= nil
					and enemiesNearTarget ~= nil
					and (#enemiesNearTarget > #alliesNearTarget or bot:WasRecentlyDamagedByAnyHero(2))
				then
					return BOT_ACTION_DESIRE_HIGH, enemyHero
				end
			end
		end
	end
	if Fu.IsPushing(bot) or Fu.IsDefending(bot) then
		local nearbyEnemies = Fu.GetEnemiesNearLoc(bot:GetLocation(), 1600)
		local nearbyLaneCreeps = bot:GetNearbyLaneCreeps(castRange, true)
		if nearbyLaneCreeps ~= nil and #nearbyLaneCreeps >= 3 and nearbyEnemies ~= nil and #nearbyEnemies == 0 then
			for _, creep in pairs(nearbyLaneCreeps) do
				if Fu.IsValid(creep) and Fu.CanBeAttacked(creep) then
					local creepCount = Fu.GetNearbyAroundLocationUnitCount(true, false, radius, creep:GetLocation())
					if creepCount >= 3 then
						return BOT_ACTION_DESIRE_HIGH, creep
					end
				end
			end
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if Fu.IsRoshan(botTarget) and Fu.IsInRange(bot, botTarget, castRange) and isAttacking then
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, castRange) and isAttacking then
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end
	local nearbyNeutrals = bot:GetNearbyNeutralCreeps(castRange)
	for _, creep in pairs(nearbyNeutrals) do
		if
			Fu.IsValid(creep)
			and Fu.CanBeAttacked(creep)
			and creep:GetHealth() > strikeDamage * strikeCount / 2
			and creep:GetHealth() <= strikeDamage * strikeCount
		then
			return BOT_ACTION_DESIRE_HIGH, creep
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function X.ConsiderGlimpse()
	if not glimpseAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	-- A fleeing enemy: pull it back to where it was 4s ago when that spot is well behind it and
	-- closer to us. The old chase rule also needed the target to be teleporting or in its fountain,
	-- so a running enemy was never glimpsed.
	if isGoingOnSomeone or isInTeamFight then
		local range = Fu.GetProperCastRange(false, bot, glimpseAbility:GetCastRange())
		for _, enemyHero in pairs(Fu.GetNearbyHeroes(bot, range, true, BOT_MODE_NONE) or {}) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and not Fu.IsDisabled(enemyHero)
				and not enemyHero:IsFacingLocation(bot:GetLocation(), 90)
			then
				local spot = X.GlimpseReturnSpot(enemyHero)
				if
					spot ~= nil
					and GetUnitToLocationDistance(enemyHero, spot) >= 400
					and GetUnitToLocationDistance(bot, spot) + 300 < GetUnitToUnitDistance(bot, enemyHero)
				then
					pcall(
						print,
						string.format(
							"[OHA-DISRUPTOR] t=%.0f glimpse-flee target=%s back=%d",
							DotaTime(),
							(string.gsub(enemyHero:GetUnitName(), "npc_dota_hero_", "")),
							GetUnitToLocationDistance(enemyHero, spot)
						)
					)
					return BOT_ACTION_DESIRE_HIGH, enemyHero
				end
			end
		end
	end
	local castRange = Fu.GetProperCastRange(false, bot, glimpseAbility:GetCastRange())
	local alliesInRange = Fu.GetNearbyHeroes(bot, castRange, false, BOT_MODE_NONE)
	local nearbyEnemies = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and Fu.CanCastOnTargetAdvanced(enemyHero)
			and (enemyHero:IsChanneling() or bot:GetActiveMode() == BOT_MODE_ATTACK and (alliesInRange ~= nil and #alliesInRange <= 3 and #nearbyEnemies <= 2) and bot:IsFacingLocation(
				enemyHero:GetLocation(),
				30
			) and enemyHero:IsFacingLocation(Fu.GetEnemyFountain(), 30))
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and not Fu.IsSuspiciousIllusion(enemyHero)
		then
			if
				enemyHero:HasModifier("modifier_teleporting") or enemyHero:HasModifier("modifier_fountain_aura_buff")
			then
				return BOT_ACTION_DESIRE_HIGH, enemyHero
			end
			if isGoingOnSomeone then
				local enemiesNearTarget = Fu.GetNearbyHeroes(enemyHero, 1200, false, BOT_MODE_NONE)
				if
					Fu.IsChasingTarget(bot, enemyHero)
					and enemyHero:GetCurrentMovementSpeed() > bot:GetCurrentMovementSpeed()
					and enemiesNearTarget ~= nil
					and #enemiesNearTarget >= #nearbyEnemies
				then
					return BOT_ACTION_DESIRE_HIGH, enemyHero
				end
			end
		end
	end
	if isRetreating and bot:GetActiveModeDesire() >= 0.75 then
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
				and Fu.IsChasingTarget(enemyHero, bot)
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and not Fu.IsDisabled(enemyHero)
				and not Fu.IsRealInvisible(bot)
				and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
			then
				local alliesNearTarget = Fu.GetNearbyHeroes(enemyHero, 1200, true, BOT_MODE_NONE)
				local enemiesNearTarget = Fu.GetNearbyHeroes(enemyHero, 1200, false, BOT_MODE_NONE)
				if
					alliesNearTarget ~= nil
					and enemiesNearTarget ~= nil
					and (#enemiesNearTarget > #alliesNearTarget or bot:WasRecentlyDamagedByAnyHero(2))
				then
					return BOT_ACTION_DESIRE_HIGH, enemyHero
				end
			end
		end
	end
	for _, allyHero in pairs(alliesInRange) do
		local allyNearbyEnemies = Fu.GetNearbyHeroes(allyHero, 1200, true, BOT_MODE_NONE)
		if
			Fu.IsValidHero(allyHero)
			and Fu.IsRetreating(allyHero)
			and Fu.IsCore(allyHero)
			and allyHero:GetActiveModeDesire() >= 0.75
			and allyHero:WasRecentlyDamagedByAnyHero(2)
			and not allyHero:IsIllusion()
		then
			if
				allyNearbyEnemies ~= nil
				and #allyNearbyEnemies >= 1
				and Fu.IsValidHero(allyNearbyEnemies[1])
				and Fu.CanCastOnNonMagicImmune(allyNearbyEnemies[1])
				and Fu.CanCastOnTargetAdvanced(allyNearbyEnemies[1])
				and Fu.IsInRange(bot, allyNearbyEnemies[1], castRange)
				and Fu.IsChasingTarget(allyNearbyEnemies[1], allyHero)
				and not Fu.IsChasingTarget(allyNearbyEnemies[1], bot)
				and not Fu.IsDisabled(allyNearbyEnemies[1])
				and not Fu.IsTaunted(allyNearbyEnemies[1])
				and not Fu.IsSuspiciousIllusion(allyNearbyEnemies[1])
				and not allyNearbyEnemies[1]:HasModifier("modifier_necrolyte_reapers_scythe")
			then
				return BOT_ACTION_DESIRE_HIGH, allyNearbyEnemies[1]
			end
		end
	end
	local realHeroCount = 0
	local illusionCount = 0
	local illusionTarget = nil
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and Fu.CanCastOnTargetAdvanced(enemyHero)
			-- no IsSuspiciousIllusion filter here: it dropped every illusion before the count below,
			-- so "Glimpse kills illusions" (datafeed) could never fire.
			and glimpseAbility:GetLevel() >= 3
		then
			if Fu.IsSuspiciousIllusion(enemyHero) then
				illusionCount = illusionCount + 1
				illusionTarget = enemyHero
			else
				realHeroCount = realHeroCount + 1
			end
		end
	end
	if realHeroCount == 0 and illusionCount >= 1 then
		if DotaTime() >= (bot._glimpseIllLogAt or -999) then
			bot._glimpseIllLogAt = DotaTime() + 5
			pcall(
				print,
				string.format("[OHA-DISRUPTOR] t=%.0f glimpse illusion=%s", DotaTime(), illusionTarget:GetUnitName())
			)
		end
		return BOT_ACTION_DESIRE_HIGH, illusionTarget
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function X.ConsiderKineticFence()
	if not Fu.CanCastAbility(kineticFenceAbility) then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	-- Float reads: Kinetic Fence duration is 4.4s and its formation time 0.5s since 7.42 (Valve datafeed);
	-- an Int read gave 4 and 0.
	local duration = kineticFenceAbility:GetSpecialValueFloat("duration")
	if not Fu.CanCastAbility(kineticFenceAbility) or DotaTime() < kineticFenceCastTime + duration then
		return BOT_ACTION_DESIRE_NONE
	end
	local castRange = Fu.GetProperCastRange(false, bot, kineticFenceAbility:GetCastRange())
	local castPoint = kineticFenceAbility:GetCastPoint()
	local radius = kineticFenceAbility:GetSpecialValueInt("radius")
	local formationTime = kineticFenceAbility:GetSpecialValueFloat("formation_time")
	local nearbyEnemies = bot:GetNearbyHeroes(1600, true, BOT_MODE_NONE)
	if isInTeamFight then
		local aoeLocation =
			bot:FindAoELocation(true, true, bot:GetLocation(), castRange, radius, castPoint + formationTime, 0)
		local nearbyEnemies = Fu.GetEnemiesNearLoc(aoeLocation.targetloc, radius)
		if #nearbyEnemies >= 2 then
			return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
		end
	end
	if isGoingOnSomeone then
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and not botTarget:HasModifier("modifier_enigma_black_hole_pull")
			and not botTarget:HasModifier("modifier_faceless_void_chronosphere_freeze")
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			local aoeLocation = bot:FindAoELocation(true, true, botTarget:GetLocation(), 0, radius, castPoint, 0)
			local aoeTargetLocation = aoeLocation.targetloc
			local predictedLocation = Fu.GetCorrectLoc(botTarget, formationTime)
			if #nearbyEnemies <= 1 then
				if Fu.IsChasingTarget(bot, botTarget) then
					if aoeLocation.count >= 2 then
						return BOT_ACTION_DESIRE_HIGH, aoeTargetLocation
					else
						return BOT_ACTION_DESIRE_HIGH, predictedLocation
					end
				end
			else
				if aoeLocation.count >= 2 then
					return BOT_ACTION_DESIRE_HIGH, aoeTargetLocation
				else
					return BOT_ACTION_DESIRE_HIGH, predictedLocation
				end
			end
		end
	end
	if isRetreating and not Fu.IsRealInvisible(bot) and bot:GetActiveModeDesire() > 0.9 then
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.IsInRange(bot, enemyHero, castRange)
				and Fu.IsChasingTarget(enemyHero, bot)
				and not Fu.IsDisabled(enemyHero)
				and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
			then
				return BOT_ACTION_DESIRE_HIGH, (bot:GetLocation() + Fu.GetCorrectLoc(enemyHero, formationTime)) / 2
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderKineticField()
	if not Fu.CanCastAbility(kineticFieldAbility) then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castRange = Fu.GetProperCastRange(false, bot, kineticFieldAbility:GetCastRange())
	local castPoint = kineticFieldAbility:GetCastPoint()
	local radius = kineticFieldAbility:GetSpecialValueInt("radius")
	if isInTeamFight and not CanCastKineticStorm() then
		local aoeLocation = bot:FindAoELocation(true, true, bot:GetLocation(), castRange, radius * 0.8, 0, 0)
		local nearbyEnemies = Fu.GetEnemiesNearLoc(aoeLocation.targetloc, radius * 0.8)
		if nearbyEnemies ~= nil and #nearbyEnemies >= 2 then
			return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
		end
	end
	if isGoingOnSomeone then
		if
			Fu.IsValidTarget(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not botTarget:IsMagicImmune()
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
			and not botTarget:HasModifier("modifier_skeleton_king_reincarnation_scepter_active")
		then
			local alliesNearTarget = Fu.GetNearbyHeroes(botTarget, 1400, true, BOT_MODE_NONE)
			local enemiesNearTarget = Fu.GetNearbyHeroes(botTarget, 1400, false, BOT_MODE_NONE)
			if alliesNearTarget ~= nil and enemiesNearTarget ~= nil and #alliesNearTarget >= #enemiesNearTarget then
				if #enemiesNearTarget == 0 then
					if Fu.IsChasingTarget(bot, botTarget) then
						if Fu.IsInRange(bot, botTarget, castRange) then
							return BOT_ACTION_DESIRE_HIGH, botTarget:GetExtrapolatedLocation(castPoint)
						end
						if
							Fu.IsInRange(bot, botTarget, castRange + radius)
							and not Fu.IsInRange(bot, botTarget, castRange)
						then
							return BOT_ACTION_DESIRE_HIGH,
								Fu.Site.GetXUnitsTowardsLocation(bot, botTarget:GetLocation(), castRange)
						end
					end
				else
					if Fu.IsInRange(bot, botTarget, castRange) then
						enemiesNearTarget = Fu.GetEnemiesNearLoc(botTarget:GetLocation(), radius * 0.8)
						if enemiesNearTarget ~= nil and #enemiesNearTarget >= 1 then
							return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(enemiesNearTarget)
						else
							return BOT_ACTION_DESIRE_HIGH, botTarget:GetExtrapolatedLocation(castPoint)
						end
					end
					if
						Fu.IsInRange(bot, botTarget, castRange + radius)
						and not Fu.IsInRange(bot, botTarget, castRange)
					then
						enemiesNearTarget = Fu.GetEnemiesNearLoc(botTarget:GetLocation(), radius * 0.8)
						if enemiesNearTarget ~= nil and #enemiesNearTarget >= 1 then
							return BOT_ACTION_DESIRE_HIGH,
								Fu.Site.GetXUnitsTowardsLocation(bot, Fu.GetCenterOfUnits(enemiesNearTarget), castRange)
						else
							return BOT_ACTION_DESIRE_HIGH,
								Fu.Site.GetXUnitsTowardsLocation(bot, botTarget:GetLocation(), castRange)
						end
					end
				end
			end
		end
	end
	local desireThreshold = RemapValClamped(kineticFieldAbility:GetLevel(), 1, 4, 0.75, 0.5)
	if isRetreating and bot:GetActiveModeDesire() >= desireThreshold then
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
		if nearbyEnemies ~= nil and #nearbyEnemies >= 1 then
			if
				Fu.IsValidHero(nearbyEnemies[1])
				and Fu.IsChasingTarget(nearbyEnemies[1], bot)
				and not Fu.IsSuspiciousIllusion(nearbyEnemies[1])
				and not Fu.IsDisabled(nearbyEnemies[1])
				and not nearbyEnemies[1]:IsMagicImmune()
				and not nearbyEnemies[1]:HasModifier("modifier_necrolyte_reapers_scythe")
			then
				local alliesNearTarget = Fu.GetNearbyHeroes(nearbyEnemies[1], 1200, true, BOT_MODE_NONE)
				local enemiesNearTarget = Fu.GetNearbyHeroes(nearbyEnemies[1], 1200, false, BOT_MODE_NONE)
				if
					alliesNearTarget ~= nil
					and enemiesNearTarget ~= nil
					and (#enemiesNearTarget > #alliesNearTarget or bot:WasRecentlyDamagedByAnyHero(2))
				then
					if GetUnitToLocationDistance(bot, nearbyEnemies[1]:GetExtrapolatedLocation(castPoint)) > radius then
						return BOT_ACTION_DESIRE_HIGH, bot:GetLocation()
					else
						return BOT_ACTION_DESIRE_HIGH, (bot:GetLocation() + nearbyEnemies[1]:GetLocation()) / 2
					end
				end
			end
		end
	end
	local alliesInRange = Fu.GetNearbyHeroes(bot, castRange, false, BOT_MODE_NONE)
	for _, allyHero in pairs(alliesInRange) do
		local allyNearbyEnemies = Fu.GetNearbyHeroes(allyHero, 1200, true, BOT_MODE_NONE)
		if
			Fu.IsValidHero(allyHero)
			and Fu.IsRetreating(allyHero)
			and Fu.IsCore(allyHero)
			and allyHero:GetActiveModeDesire() >= 0.75
			and allyHero:WasRecentlyDamagedByAnyHero(2)
			and not allyHero:IsIllusion()
			and not isGoingOnSomeone
		then
			if
				allyNearbyEnemies ~= nil
				and #allyNearbyEnemies >= 1
				and Fu.IsValidHero(allyNearbyEnemies[1])
				and Fu.IsInRange(bot, allyNearbyEnemies[1], castRange)
				and Fu.IsChasingTarget(allyNearbyEnemies[1], allyHero)
				and not Fu.IsChasingTarget(allyNearbyEnemies[1], bot)
				and not Fu.IsDisabled(allyNearbyEnemies[1])
				and not Fu.IsTaunted(allyNearbyEnemies[1])
				and not Fu.IsSuspiciousIllusion(allyNearbyEnemies[1])
				and not allyNearbyEnemies[1]:IsMagicImmune()
				and not allyNearbyEnemies[1]:HasModifier("modifier_necrolyte_reapers_scythe")
				and GetUnitToUnitDistance(allyHero, allyNearbyEnemies[1])
					< GetUnitToUnitDistance(bot, allyNearbyEnemies[1])
			then
				return BOT_ACTION_DESIRE_HIGH, (allyHero:GetLocation() + allyNearbyEnemies[1]:GetLocation()) / 2
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.ConsiderStaticStorm()
	if not staticStormAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local radius = staticStormAbility:GetSpecialValueInt("radius")
	local castRange = staticStormAbility:GetCastRange()
	-- Engaging counts too, not only a team fight: two enemies in a skirmish never got it.
	if (isInTeamFight or isGoingOnSomeone) and not CanCastKineticStorm() then
		local aoeLocation = bot:FindAoELocation(true, true, bot:GetLocation(), castRange, radius * 0.8, 0, 0)
		local nearbyEnemies = Fu.GetEnemiesNearLoc(aoeLocation.targetloc, radius * 0.8)
		if
			nearbyEnemies ~= nil
			and #nearbyEnemies >= 2
			and GetUnitToLocationDistance(bot, aoeLocation.targetloc) <= castRange
			and not Fu.IsLocationInChrono(aoeLocation.targetloc)
			and not Fu.IsLocationInBlackHole(aoeLocation.targetloc)
		then
			return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(nearbyEnemies)
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.ConsiderKineticStorm()
	if CanCastKineticStorm() then
		local castRange = Fu.GetProperCastRange(false, bot, kineticFieldAbility:GetCastRange())
		local radius = kineticFieldAbility:GetSpecialValueInt("radius")
		if isInTeamFight or isGoingOnSomeone then
			local aoeLocation = bot:FindAoELocation(true, true, bot:GetLocation(), castRange, radius * 0.8, 0, 0)
			local nearbyEnemies = Fu.GetEnemiesNearLoc(aoeLocation.targetloc, radius * 0.8)
			-- A group (2+) as before, or one hero when it is his target while engaging and a
			-- high-value core: estimated position 1 or 2 (user call). An unknown role reads as 3 and
			-- does not count.
			local oneOk = false
			if
				isGoingOnSomeone
				and nearbyEnemies ~= nil
				and #nearbyEnemies == 1
				and Fu.IsValidHero(botTarget)
				and nearbyEnemies[1] == botTarget
			then
				local okP, pos = pcall(Fu.GetPosition, botTarget)
				oneOk = okP and type(pos) == "number" and pos <= 2
			end
			if
				nearbyEnemies ~= nil
				and (#nearbyEnemies >= 2 or oneOk)
				and GetUnitToLocationDistance(bot, aoeLocation.targetloc) <= castRange
				and not Fu.IsLocationInChrono(aoeLocation.targetloc)
				and not Fu.IsLocationInBlackHole(aoeLocation.targetloc)
			then
				return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(nearbyEnemies)
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function CanCastKineticStorm()
	if Fu.CanCastAbility(kineticFieldAbility) and staticStormAbility:IsFullyCastable() then
		local totalManaCost = kineticFieldAbility:GetManaCost() + staticStormAbility:GetManaCost()
		if bot:GetMana() >= totalManaCost then
			return true
		end
	end
	return false
end
return X
