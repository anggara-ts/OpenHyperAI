-- Tusk: skill build, item build, and ability use for this hero.
local X = {}
local bot = GetBot()
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local AbilityContext = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local Minion = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local sTalentList = Fu.Skill.GetTalentList(bot)
local sAbilityList = Fu.Skill.GetAbilityList(bot)
local sRole = Fu.Item.GetRoleItemsBuyList(bot)
local tTalentTreeList = { ["t25"] = { 10, 0 }, ["t20"] = { 0, 10 }, ["t15"] = { 10, 0 }, ["t10"] = { 10, 0 } }
local tAllAbilityBuildList = { { 3, 1, 2, 3, 3, 6, 3, 2, 2, 2, 6, 1, 1, 1, 6 } }
local nAbilityBuildList = Fu.Skill.GetRandomBuild(tAllAbilityBuildList)
local nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList)
local sRoleItemsBuyList = {}
sRoleItemsBuyList["pos_4"] = {
	"item_double_tango",
	"item_faerie_fire",
	"item_wind_lace",
	"item_magic_wand",
	"item_arcane_boots",
	"item_blink",
	"item_guardian_greaves",
	"item_cyclone",
	"item_ultimate_scepter",
	"item_aghanims_shard",
	"item_black_king_bar",
	"item_lotus_orb",
	"item_gungir",
	"item_wind_waker",
	"item_overwhelming_blink",
	"item_ultimate_scepter_2",
	"item_moon_shard",
}
sRoleItemsBuyList["pos_5"] = {
	"item_double_tango",
	"item_faerie_fire",
	"item_wind_lace",
	"item_magic_wand",
	"item_tranquil_boots",
	"item_blink",
	"item_boots_of_bearing",
	"item_pipe",
	"item_ultimate_scepter",
	"item_aghanims_shard",
	"item_pavise",
	"item_solar_crest",
	"item_heavens_halberd",
	"item_lotus_orb",
	"item_gungir",
	"item_overwhelming_blink",
	"item_ultimate_scepter_2",
	"item_moon_shard",
}
sRoleItemsBuyList["pos_1"] = {
	"item_tank_outfit",
	"item_echo_sabre",
	"item_ring_of_health",
	"item_vanguard",
	"item_crimson_guard",
	-- No Aghanim's Scepter on the core: its Walrus Kick often knocked a ganked enemy away
	-- to safety. Blink to land the snowball/punch, BKB to stay in the fight.
	"item_blink",
	"item_black_king_bar",
	"item_heavens_halberd",
	"item_assault",
	"item_travel_boots",
	"item_aghanims_shard",
	"item_satanic",
	"item_moon_shard",
	"item_heart",
	"item_travel_boots_2",
}
sRoleItemsBuyList["pos_2"] = sRoleItemsBuyList["pos_1"]
sRoleItemsBuyList["pos_3"] = sRoleItemsBuyList["pos_1"]
X["sBuyList"] = sRoleItemsBuyList[sRole]
X["sSellList"] = { "item_black_king_bar", "item_quelling_blade" }
if Fu.Role.IsPvNMode() or Fu.Role.IsAllShadow() then
	X["sBuyList"], X["sSellList"] = { "PvN_antimage" }, {}
end
nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"] =
	Fu.SetUserHeroInit(nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"])
X["sSkillList"] = Fu.Skill.GetSkillList(sAbilityList, nAbilityBuildList, sTalentList, nTalentBuildList)
X["bDeafaultAbility"] = false
-- Tusk is invulnerable inside his snowball; spell logic must still run to launch it.
X["bThinkWhileInvulnerable"] = true
X["bDeafaultItem"] = false
function X.MinionThink(minionUnit)
	Minion.MinionThink(minionUnit)
end
local iceShardsAbility = SafeAbility(bot:GetAbilityByName("tusk_ice_shards"), "tusk_ice_shards", "tusk")
local snowballAbility = SafeAbility(bot:GetAbilityByName("tusk_snowball"), "tusk_snowball", "tusk")
local launchSnowballAbility = SafeAbility(bot:GetAbilityByName("tusk_launch_snowball"), "tusk_launch_snowball", "tusk")
local tagTeamAbility = SafeAbility(bot:GetAbilityByName("tusk_tag_team"), "tusk_tag_team", "tusk")
local walrusKickAbility = SafeAbility(bot:GetAbilityByName("tusk_walrus_kick"), "tusk_walrus_kick", "tusk")
local walrusPunchAbility = SafeAbility(bot:GetAbilityByName("tusk_walrus_punch"), "tusk_walrus_punch", "tusk")
local drinkingBuddiesAbility =
	SafeAbility(bot:GetAbilityByName("tusk_drinking_buddies"), "tusk_drinking_buddies", "tusk")
local iceShardsDesire, iceShardsLocation
local snowballDesire, snowballTarget
local launchSnowballDesire
local tagTeamDesire
local walrusKickDesire, walrusKickTarget
local walrusPunchDesire, walrusPunchTarget
local drinkingBuddiesDesire, drinkingBuddiesTarget
local botTarget
if bot.snowballHeroRetreat then
	bot.snowballHeroRetreat = false
end
local isEngaging
local isRetreating
local isAttacking
function X.SkillsComplement()
	-- The hold flag only belongs to the escape snowball that set it. Clear it once Tusk is
	-- out of the snowball, or every later snowball would also wait out the full duration.
	if
		bot.snowballHeroRetreat
		and launchSnowballAbility:IsHidden()
		and DotaTime() > (bot._snowballRetreatAt or -99) + 1.5
	then
		bot.snowballHeroRetreat = false
	end
	-- Walrus Punch is an autocast attack spell. With autocast on, any right-click on a hero
	-- punches without Tag Team first (7:04 on Mirana, no Tag Team, no punch decision of ours).
	-- Keep it off so every Punch goes through ConsiderWalrusPunch and Tag Team leads.
	if
		walrusPunchAbility ~= nil
		and not walrusPunchAbility:IsNull()
		and walrusPunchAbility:IsTrained()
		and walrusPunchAbility:GetAutoCastState()
	then
		pcall(print, string.format("[OHA-TUSK] t=%.0f punch-autocast was=on turned=off", DotaTime()))
		walrusPunchAbility:ToggleAutoCast()
	end
	-- Launch as soon as the snowball is up, before the busy-casting check and every other
	-- spell. Checked after them, it could wait out the whole 3s windup while engaging. Only an
	-- escape snowball (snowballHeroRetreat) keeps rolling, to stay out of reach.
	if X.ConsiderLaunchSnowball() > 0 and not bot:IsStunned() and not bot:IsHexed() and not bot:IsSilenced() then
		-- The order repeats each think until the snowball leaves; log the first one only.
		if (bot._snowballLaunchLoggedFor or -1) ~= (bot._snowballCastAt or 0) then
			bot._snowballLaunchLoggedFor = bot._snowballCastAt or 0
			pcall(
				print,
				string.format(
					"[OHA-TUSK] t=%.0f snowball-launch after=%.1fs",
					DotaTime(),
					DotaTime() - (bot._snowballCastAt or DotaTime())
				)
			)
		end
		bot:Action_UseAbility(launchSnowballAbility)
		return
	end
	if Fu.CanNotUseAbility(bot) then
		return
	end
	local context = AbilityContext.Build(bot)
	isEngaging = context.isEngaging
	isRetreating = context.isRetreating
	isAttacking = Fu.IsAttacking(bot)
	botTarget = context.target
	tagTeamDesire = X.ConsiderTagTeam()
	if tagTeamDesire > 0 then
		bot:Action_UseAbility(tagTeamAbility)
		return
	end
	drinkingBuddiesDesire, drinkingBuddiesTarget = X.ConsiderDrinkingBuddies()
	if drinkingBuddiesDesire > 0 then
		bot:Action_UseAbilityOnEntity(drinkingBuddiesAbility, drinkingBuddiesTarget)
		return
	end
	iceShardsDesire, iceShardsLocation = X.ConsiderIceShards()
	if iceShardsDesire > 0 then
		bot:Action_UseAbilityOnLocation(iceShardsAbility, iceShardsLocation)
		return
	end
	snowballDesire, snowballTarget = X.ConsiderSnowball()
	if snowballDesire > 0 then
		bot:Action_UseAbilityOnEntity(snowballAbility, snowballTarget)
		bot._snowballCastAt = DotaTime()
		return
	end
	walrusKickDesire, walrusKickTarget = X.ConsiderWalrusKick()
	if walrusKickDesire > 0 then
		bot:Action_UseAbilityOnEntity(walrusKickAbility, walrusKickTarget)
		return
	end
	walrusPunchDesire, walrusPunchTarget = X.ConsiderWalrusPunch()
	if walrusPunchDesire > 0 then
		-- Tag Team first when it can go: its bonus damage applies to the Punch. Tag Team keys
		-- off Tusk's target and Punch off any hero in reach, so in lane (target a creep) the
		-- Punch went out alone (7:04).
		local tagWhy = X.TagTeamBeforePunch(walrusPunchTarget)
		if tagWhy == "cast" then
			bot:Action_UseAbility(tagTeamAbility)
			return
		end
		pcall(
			print,
			string.format(
				"[OHA-TUSK] t=%.0f punch target=%s hp=%.2f tagTeam=%s mp=%.2f",
				DotaTime(),
				walrusPunchTarget and (string.gsub(walrusPunchTarget:GetUnitName(), "npc_dota_hero_", "")) or "-",
				walrusPunchTarget and Fu.GetHP(walrusPunchTarget) or 0,
				tagWhy,
				Fu.GetMP(bot)
			)
		)
		bot:Action_UseAbilityOnEntity(walrusPunchAbility, walrusPunchTarget)
		return
	end
end
function X.ConsiderIceShards()
	if not iceShardsAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local castRange = Fu.GetProperCastRange(false, bot, iceShardsAbility:GetCastRange())
	local castPoint = iceShardsAbility:GetCastPoint()
	local shardWidth = iceShardsAbility:GetSpecialValueInt("shard_width")
	local damage = iceShardsAbility:GetSpecialValueInt("shard_damage")
	local shardSpeed = iceShardsAbility:GetSpecialValueInt("shard_speed")
	-- The shards ring the target point (7 shards 200 out), so aim where he will be when the
	-- ball arrives. The old aim added 2s on top and landed the ring ~700 ahead of a runner.
	local function Spot(enemyHero)
		-- Close up (right after a snowball), a ring centred on the enemy puts shards between
		-- him and Tusk: at 10:00 it walled Tusk off and the enemy walked away. Centre it 300
		-- past the enemy, on the side away from Tusk, so the wall is behind the enemy instead.
		local dist = GetUnitToUnitDistance(bot, enemyHero)
		if dist < 500 then
			local from, to = bot:GetLocation(), enemyHero:GetLocation()
			local dx, dy = to.x - from.x, to.y - from.y
			local len = math.max(1, math.sqrt(dx * dx + dy * dy))
			return Vector(to.x + dx / len * 300, to.y + dy / len * 300, to.z)
		end
		if Fu.IsDisabled(enemyHero) or enemyHero:GetCurrentMovementSpeed() <= 0 then
			return enemyHero:GetLocation()
		end
		return enemyHero:GetExtrapolatedLocation(dist / math.max(1, shardSpeed) + castPoint + 0.2)
	end
	local function Trappable(enemyHero)
		return Fu.IsValidHero(enemyHero)
			and Fu.IsInRange(bot, enemyHero, castRange)
			and not Fu.IsSuspiciousIllusion(enemyHero)
			and not enemyHero:HasModifier("modifier_enigma_black_hole_pull")
			and not enemyHero:HasModifier("modifier_faceless_void_chronosphere_freeze")
			and not enemyHero:HasModifier("modifier_legion_commander_duel")
			and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
	end
	local nearbyEnemies = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and Fu.IsInRange(bot, enemyHero, castRange)
			and Fu.CanKillTarget(enemyHero, damage, DAMAGE_TYPE_MAGICAL)
			and not Fu.IsSuspiciousIllusion(enemyHero)
			and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
			and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
			and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
			and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
			and not enemyHero:HasModifier("modifier_templar_assassin_refraction_absorb")
		then
			X.LogShards("kill", enemyHero)
			return BOT_ACTION_DESIRE_HIGH, Spot(enemyHero)
		end
	end
	if Fu.IsInTeamFight(bot, 1200) then
		local aoeLocation = bot:FindAoELocation(true, true, bot:GetLocation(), castRange, shardWidth, 0, 0)
		local nearbyEnemies = Fu.GetEnemiesNearLoc(aoeLocation.targetloc, shardWidth)
		if
			nearbyEnemies ~= nil
			and #nearbyEnemies >= 2
			and not Fu.IsLocationInChrono(aoeLocation.targetloc)
			and not Fu.IsLocationInBlackHole(aoeLocation.targetloc)
		then
			X.LogShards("fight", nearbyEnemies[1])
			return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
		end
	end
	-- Going in on his target: trap it whether he is chasing, walking up, or it is disabled.
	if isEngaging and Fu.IsValidTarget(botTarget) and Fu.CanCastOnMagicImmune(botTarget) and Trappable(botTarget) then
		local nearbyAllies = Fu.GetNearbyHeroes(botTarget, 1200, true, BOT_MODE_NONE)
		local nearbyEnemies = Fu.GetNearbyHeroes(botTarget, 1200, false, BOT_MODE_NONE)
		if nearbyAllies ~= nil and nearbyEnemies ~= nil and #nearbyAllies >= #nearbyEnemies then
			X.LogShards("engage", botTarget)
			return BOT_ACTION_DESIRE_HIGH, Spot(botTarget)
		end
	end
	-- An ally is already hitting a hurt enemy hero: trap it so it cannot walk out.
	for _, enemyHero in pairs(nearbyEnemies) do
		if Trappable(enemyHero) and Fu.GetHP(enemyHero) < 0.6 then
			local ours = Fu.GetNearbyHeroes(enemyHero, 1200, true, BOT_MODE_NONE)
			local theirs = Fu.GetNearbyHeroes(enemyHero, 1200, false, BOT_MODE_NONE)
			if ours ~= nil and theirs ~= nil and #ours >= #theirs then
				for _, ally in pairs(Fu.GetNearbyHeroes(enemyHero, 700, true, BOT_MODE_NONE)) do
					if
						ally ~= bot
						and Fu.IsValidHero(ally)
						and not ally:IsIllusion()
						and ally:GetAttackTarget() == enemyHero
					then
						X.LogShards("gank", enemyHero)
						return BOT_ACTION_DESIRE_HIGH, Spot(enemyHero)
					end
				end
			end
		end
	end
	local wave = X.WaveToClear(iceShardsAbility, 900, 3, 0.45)
	if wave ~= nil then
		X.LogWaveClear("shards", wave)
		return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(wave)
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
-- [OHA-TUSK] shards why=kill|fight|engage|gank, at most once per 3s.
function X.LogShards(why, target)
	if DotaTime() < (bot._tuskShardsLogAt or -999) then
		return
	end
	bot._tuskShardsLogAt = DotaTime() + 3
	pcall(
		print,
		string.format(
			"[OHA-TUSK] t=%.0f shards why=%s target=%s hp=%.2f dist=%d",
			DotaTime(),
			why,
			target and (string.gsub(target:GetUnitName(), "npc_dota_hero_", "")) or "-",
			target and Fu.GetHP(target) or 0,
			target and math.floor(GetUnitToUnitDistance(bot, target)) or 0
		)
	)
end
-- Enemy lane creeps worth a spell, or nil. No enemy hero in sight, mana left after the cast,
-- and not taking a core's farm. Laning phase only to save a tower, so the lane is not pushed.
function X.WaveToClear(ability, range, minCreeps, manaAfter)
	if isRetreating or isEngaging or Fu.GetManaAfter(ability:GetManaCost()) < manaAfter then
		return nil
	end
	local defending = Fu.IsDefending(bot)
	if Fu.IsInLaningPhase() and not defending then
		return nil
	end
	if not defending and Fu.IsThereNonSelfCoreNearby(1200) then
		return nil
	end
	local foes = Fu.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE)
	if foes ~= nil and #foes >= 1 then
		return nil
	end
	local creeps = bot:GetNearbyLaneCreeps(range, true)
	if creeps == nil or #creeps < minCreeps then
		return nil
	end
	return creeps
end
-- [OHA-TUSK] wave-shards / wave-snowball, at most once per 10s per kind.
function X.LogWaveClear(kind, creeps)
	bot._tuskWaveLogAt = bot._tuskWaveLogAt or {}
	if DotaTime() < (bot._tuskWaveLogAt[kind] or -999) then
		return
	end
	bot._tuskWaveLogAt[kind] = DotaTime() + 10
	pcall(
		print,
		string.format(
			"[OHA-TUSK] t=%.0f wave-%s creeps=%d mp=%.2f mode=%d",
			DotaTime(),
			kind,
			#creeps,
			Fu.GetMP(bot),
			bot:GetActiveMode()
		)
	)
end
function X.ConsiderDrinkingBuddies()
	-- Not castable while rooted since 7.41c.
	if not Fu.CanCastAbility(drinkingBuddiesAbility) or bot:IsRooted() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castRange = Fu.GetProperCastRange(false, bot, drinkingBuddiesAbility:GetCastRange())
	local alliesInRange = Fu.GetAlliesNearLoc(bot:GetLocation(), castRange)
	local strongestAlly = nil
	local highestAttackDamage = 0
	for _, allyHero in pairs(alliesInRange) do
		if allyHero ~= bot and Fu.IsValidHero(allyHero) and not allyHero:IsIllusion() then
			if Fu.IsStuck(bot) or Fu.IsStuck(allyHero) then
				return BOT_ACTION_DESIRE_HIGH, allyHero
			end
			if Fu.IsDoingRoshan(bot) then
				if
					Fu.IsRoshan(botTarget)
					and Fu.CanBeAttacked(botTarget)
					and Fu.IsInRange(bot, botTarget, 500)
					and isAttacking
				then
					return BOT_ACTION_DESIRE_HIGH, allyHero
				end
			end
			if Fu.IsDoingTormentor(bot) then
				if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, 500) and isAttacking then
					return BOT_ACTION_DESIRE_HIGH, allyHero
				end
			end
			if
				not Fu.IsDisabled(allyHero)
				and not Fu.IsWithoutTarget(allyHero)
				and not allyHero:HasModifier("modifier_necrolyte_reapers_scythe")
				and not allyHero:HasModifier("modifier_skeleton_king_reincarnation_scepter_active")
			then
				local damage = allyHero:GetAttackDamage() * allyHero:GetAttackSpeed()
				if damage > highestAttackDamage then
					strongestAlly = allyHero
					highestAttackDamage = damage
				end
			end
		end
	end
	if isEngaging and strongestAlly ~= nil then
		if
			Fu.IsValidTarget(botTarget)
			and Fu.IsInRange(bot, botTarget, 1000)
			and Fu.CanBeAttacked(botTarget)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
			and not botTarget:HasModifier("modifier_templar_assassin_refraction_absorb")
		then
			local isBotChasing = Fu.IsChasingTarget(bot, botTarget)
			local isAllyChasing = Fu.IsChasingTarget(strongestAlly, botTarget)
			local botDistance = GetUnitToUnitDistance(bot, botTarget)
			local allyDistance = GetUnitToUnitDistance(strongestAlly, botTarget)
			if
				not isBotChasing
				or isBotChasing and isAllyChasing and allyDistance < botDistance and allyDistance < 500
			then
				return BOT_ACTION_DESIRE_HIGH, strongestAlly
			end
		end
	end
	local nearbyAllies = bot:GetNearbyHeroes(1600, false, BOT_MODE_NONE)
	if
		isRetreating
		and not Fu.IsRealInvisible(bot)
		and not bot:HasModifier("modifier_fountain_aura_buff")
		and #alliesInRange > 1
	then
		for _, hero in pairs(nearbyAllies) do
			if Fu.IsValidHero(hero) and Fu.IsInRange(bot, hero, 800) and Fu.IsChasingTarget(hero, bot) then
				if
					bot:WasRecentlyDamagedByAnyHero(3.0) and not Fu.IsSuspiciousIllusion(hero)
					or #alliesInRange + 2 <= #nearbyAllies
				then
					for _, allyHero in pairs(alliesInRange) do
						if
							allyHero ~= bot
							and Fu.IsValidHero(allyHero)
							and not allyHero:IsIllusion()
							and Fu.IsRetreating(allyHero)
							and GetUnitToUnitDistance(allyHero, hero) > GetUnitToUnitDistance(bot, hero)
							and GetUnitToLocationDistance(hero, (bot:GetLocation() + allyHero:GetLocation()) / 2)
								> 500
						then
							return BOT_ACTION_DESIRE_HIGH, allyHero
						end
					end
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function X.ConsiderSnowball()
	if not snowballAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castRange = Fu.GetProperCastRange(false, bot, snowballAbility:GetCastRange())
	local snowballDuration = snowballAbility:GetSpecialValueFloat("snowball_duration")
	if isEngaging then
		local bestTarget = nil
		local highestDamage = 0
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and not enemyHero:HasModifier("modifier_enigma_black_hole_pull")
				and not enemyHero:HasModifier("modifier_faceless_void_chronosphere_freeze")
				and not enemyHero:HasModifier("modifier_legion_commander_duel")
				and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
			then
				local estimatedDamage =
					enemyHero:GetEstimatedDamageToTarget(false, bot, snowballDuration, DAMAGE_TYPE_ALL)
				if estimatedDamage > highestDamage then
					highestDamage = estimatedDamage
					bestTarget = enemyHero
				end
			end
		end
		if bestTarget ~= nil then
			local nearbyAllies = Fu.GetNearbyHeroes(bestTarget, 1200, true, BOT_MODE_NONE)
			nearbyEnemies = Fu.GetNearbyHeroes(bestTarget, 1200, false, BOT_MODE_NONE)
			if nearbyAllies ~= nil and nearbyEnemies ~= nil and #nearbyAllies >= #nearbyEnemies then
				return BOT_ACTION_DESIRE_HIGH, bestTarget
			end
		end
	end
	if isRetreating then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, 1200, false, BOT_MODE_NONE)
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE)
		local escapeCreep = nil
		local farthestCreepDistance = 0
		-- Escape: outnumbered, low, or a ready blink locked by recent hero damage. The
		-- snowball holds him out of reach while the 3s blink lock runs out.
		local outnumbered = nearbyAllies ~= nil and nearbyEnemies ~= nil and #nearbyEnemies > #nearbyAllies
		local low = Fu.GetHP(bot) < 0.5
		local blinkLocked = X.BlinkLockedByDamage()
		if nearbyEnemies ~= nil and #nearbyEnemies >= 1 and (outnumbered or low or blinkLocked) then
			for _, enemyHero in pairs(nearbyEnemies) do
				if
					Fu.IsValidHero(enemyHero)
					and Fu.CanCastOnNonMagicImmune(enemyHero)
					and Fu.IsInRange(bot, enemyHero, 600)
					and Fu.IsChasingTarget(enemyHero, bot)
					and bot:WasRecentlyDamagedByHero(enemyHero, 1.5)
					and not Fu.IsSuspiciousIllusion(enemyHero)
					and not Fu.IsDisabled(enemyHero)
				then
					local nearbyCreeps = bot:GetNearbyCreeps(castRange, true)
					for _, creep in pairs(nearbyCreeps) do
						if
							Fu.IsValid(creep)
							and GetUnitToLocationDistance(creep, GetAncient(GetTeam()):GetLocation()) < GetUnitToLocationDistance(
								bot,
								GetAncient(GetTeam()):GetLocation()
							)
							and GetUnitToUnitDistance(bot, creep) > castRange / 2
							and GetUnitToUnitDistance(bot, creep) > farthestCreepDistance
						then
							-- Farthest enemy creep on the way home. The old test (farthestCreepDistance > distance)
							-- started from 0 and never picked one.
							farthestCreepDistance = GetUnitToUnitDistance(bot, creep)
							escapeCreep = creep
						end
					end
				end
			end
			if escapeCreep ~= nil then
				bot.snowballHeroRetreat = true
				bot._snowballRetreatAt = DotaTime()
				X.LogEscapeSnowball(escapeCreep, outnumbered, low, blinkLocked, nearbyAllies, nearbyEnemies)
				return BOT_ACTION_DESIRE_HIGH, escapeCreep
			end
			nearbyEnemies = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
			for _, enemyHero in pairs(nearbyEnemies) do
				if
					Fu.IsValidHero(enemyHero)
					and Fu.CanCastOnNonMagicImmune(enemyHero)
					and Fu.IsInRange(bot, enemyHero, 600)
					and Fu.IsChasingTarget(enemyHero, bot)
					and bot:WasRecentlyDamagedByHero(enemyHero, 1.5)
					and not Fu.IsSuspiciousIllusion(enemyHero)
					and not Fu.IsDisabled(enemyHero)
					and not enemyHero:HasModifier("modifier_enigma_black_hole_pull")
					and not enemyHero:HasModifier("modifier_faceless_void_chronosphere_freeze")
					and not enemyHero:HasModifier("modifier_legion_commander_duel")
					and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
				then
					bot.snowballHeroRetreat = true
					bot._snowballRetreatAt = DotaTime()
					X.LogEscapeSnowball(enemyHero, outnumbered, low, blinkLocked, nearbyAllies, nearbyEnemies)
					return BOT_ACTION_DESIRE_HIGH, enemyHero
				end
			end
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if
			Fu.IsRoshan(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, 500)
			and isAttacking
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, 500) and isAttacking then
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end
	-- Wave clear on high mana only: the snowball is his gank and save, so keep mana for Shards
	-- and the next fight. Aim at the farthest creep so the roll crosses the whole wave, and
	-- never roll under an enemy tower.
	local wave = X.WaveToClear(snowballAbility, 900, 4, 0.6)
	if wave ~= nil then
		local far, farDist = nil, 0
		for _, creep in pairs(wave) do
			if Fu.IsValid(creep) then
				local dist = GetUnitToUnitDistance(bot, creep)
				if dist > farDist and #(creep:GetNearbyTowers(800, false) or {}) == 0 then
					far, farDist = creep, dist
				end
			end
		end
		if far ~= nil then
			X.LogWaveClear("snowball", wave)
			return BOT_ACTION_DESIRE_HIGH, far
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
local BLINKS = { "item_blink", "item_overwhelming_blink", "item_swift_blink", "item_arcane_blink" }
-- Blink is off cooldown but cannot be used: a hero hit him within the last 3 seconds.
function X.BlinkLockedByDamage()
	if not bot:WasRecentlyDamagedByAnyHero(3.0) then
		return false
	end
	for _, name in ipairs(BLINKS) do
		local slot = bot:FindItemSlot(name)
		if slot >= 0 and slot <= 5 then
			local item = bot:GetItemInSlot(slot)
			if item ~= nil and item:GetCooldownTimeRemaining() <= 0 then
				return true
			end
		end
	end
	return false
end
-- [OHA-TUSK]: every escape snowball, with what triggered it.
function X.LogEscapeSnowball(target, outnumbered, low, blinkLocked, allies, enemies)
	local name = target:IsHero() and (string.gsub(target:GetUnitName(), "npc_dota_hero_", "")) or "creep"
	pcall(
		print,
		string.format(
			"[OHA-TUSK] t=%.0f escape-snowball target=%s hp=%.2f allies=%d enemies=%d outnumbered=%s low=%s blinkLocked=%s",
			DotaTime(),
			name,
			Fu.GetHP(bot),
			allies and #allies or 0,
			enemies and #enemies or 0,
			tostring(outnumbered),
			tostring(low),
			tostring(blinkLocked)
		)
	)
end
function X.ConsiderLaunchSnowball()
	if launchSnowballAbility:IsHidden() or not launchSnowballAbility:IsFullyCastable() or bot.snowballHeroRetreat then
		return BOT_ACTION_DESIRE_NONE
	end
	return BOT_ACTION_DESIRE_HIGH
end
function X.ConsiderTagTeam()
	if not Fu.CanCastAbility(tagTeamAbility) then
		return BOT_ACTION_DESIRE_NONE
	end
	local radius = tagTeamAbility:GetSpecialValueInt("radius")
	if Fu.IsInTeamFight(bot, 1200) then
		local nearbyEnemies = Fu.GetEnemiesNearLoc(bot:GetLocation(), radius)
		if nearbyEnemies ~= nil and #nearbyEnemies >= 2 then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if isEngaging then
		-- A stunned target is the best time for it: Tag Team adds bonus damage to every
		-- attack on enemies in the aura, Walrus Punch included. The old "not disabled" test
		-- skipped it right after Snowball landed, so Tusk went straight to the ult.
		if
			Fu.IsValidTarget(botTarget)
			and Fu.IsInRange(bot, botTarget, radius)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not botTarget:HasModifier("modifier_dazzle_shallow_grave")
			and not botTarget:HasModifier("modifier_legion_commander_duel")
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
			and not botTarget:HasModifier("modifier_templar_assassin_refraction_absorb")
		then
			local nearbyAllies = Fu.GetNearbyHeroes(botTarget, 1200, true, BOT_MODE_NONE)
			local nearbyEnemies = Fu.GetNearbyHeroes(botTarget, 1200, false, BOT_MODE_NONE)
			local numbers = nearbyAllies ~= nil and nearbyEnemies ~= nil and #nearbyAllies >= #nearbyEnemies
			-- Going in with Walrus Punch anyway: open with Tag Team regardless of numbers.
			local punchReady = walrusPunchAbility ~= nil
				and walrusPunchAbility:IsTrained()
				and walrusPunchAbility:IsFullyCastable()
			if numbers or punchReady or Fu.IsDisabled(botTarget) then
				pcall(
					print,
					string.format(
						"[OHA-TUSK] t=%.0f tag-team target=%s disabled=%s punchReady=%s numbers=%s",
						DotaTime(),
						(string.gsub(botTarget:GetUnitName(), "npc_dota_hero_", "")),
						tostring(Fu.IsDisabled(botTarget)),
						tostring(punchReady),
						tostring(numbers)
					)
				)
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	if Fu.IsDoingRoshan(bot) then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, 600, false, BOT_MODE_NONE)
		if
			Fu.IsRoshan(botTarget)
			and Fu.IsInRange(bot, botTarget, 500)
			and isAttacking
			and nearbyAllies ~= nil
			and #nearbyAllies >= 2
			and Fu.IsAttacking(nearbyAllies[1])
			and Fu.IsAttacking(nearbyAllies[2])
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, 500) and isAttacking then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
-- "cast" when Tag Team should go out ahead of a Walrus Punch on `target`, or why not.
function X.TagTeamBeforePunch(target)
	if tagTeamAbility == nil or tagTeamAbility:IsNull() or not tagTeamAbility:IsTrained() then
		return "untrained"
	end
	if tagTeamAbility:GetCooldownTimeRemaining() > 0 then
		return "cooldown"
	end
	if bot:GetMana() < tagTeamAbility:GetManaCost() + walrusPunchAbility:GetManaCost() then
		return "mana"
	end
	local radius = tagTeamAbility:GetSpecialValueInt("radius")
	if radius == nil or radius < 100 then
		radius = 350
	end
	if target == nil or GetUnitToUnitDistance(bot, target) > radius then
		return "range"
	end
	if not Fu.CanCastAbility(tagTeamAbility) then
		return "blocked"
	end
	return "cast"
end
function X.ConsiderWalrusKick()
	-- Walrus Kick comes from Aghanim's Scepter. Before that it is hidden but can still read castable.
	if not Fu.CanCastAbility(walrusKickAbility) then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castRange = Fu.GetProperCastRange(false, bot, walrusKickAbility:GetCastRange())
	if isRetreating and not Fu.IsRealInvisible(bot) then
		for _, enemyHero in pairs(Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.IsInRange(bot, enemyHero, castRange)
				and Fu.IsChasingTarget(enemyHero, bot)
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and not Fu.IsDisabled(enemyHero)
				and not enemyHero:HasModifier("modifier_enigma_black_hole_pull")
				and not enemyHero:HasModifier("modifier_faceless_void_chronosphere_freeze")
				and not enemyHero:HasModifier("modifier_legion_commander_duel")
				and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
			then
				return BOT_ACTION_DESIRE_HIGH, enemyHero
			end
		end
	end
	if isEngaging then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, 1200, false, BOT_MODE_NONE)
		for _, enemyHero in pairs(Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.IsInRange(bot, enemyHero, castRange)
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
				and not enemyHero:HasModifier("modifier_enigma_black_hole_pull")
				and not enemyHero:HasModifier("modifier_faceless_void_chronosphere_freeze")
				and not enemyHero:HasModifier("modifier_legion_commander_duel")
				and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
			then
				if
					nearbyAllies ~= nil
					and #nearbyAllies >= 2
					and enemyHero ~= botTarget
					and Fu.IsInRange(enemyHero, nearbyAllies[1], 600)
				then
					return BOT_ACTION_DESIRE_HIGH, enemyHero
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function X.ConsiderWalrusPunch()
	if not walrusPunchAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castRange = Fu.GetProperCastRange(false, bot, walrusPunchAbility:GetCastRange())
	if isEngaging then
		local bestTarget = nil
		local highestDamage = 0
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.CanCastOnMagicImmune(enemyHero)
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
				and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
				and not enemyHero:HasModifier("modifier_enigma_black_hole_pull")
				and not enemyHero:HasModifier("modifier_faceless_void_chronosphere_freeze")
				and not enemyHero:HasModifier("modifier_legion_commander_duel")
				and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
				and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
				and not enemyHero:HasModifier("modifier_templar_assassin_refraction_absorb")
			then
				local estimatedDamage = enemyHero:GetEstimatedDamageToTarget(false, bot, 4, DAMAGE_TYPE_ALL)
				if estimatedDamage > highestDamage then
					highestDamage = estimatedDamage
					bestTarget = enemyHero
				end
			end
		end
		if bestTarget ~= nil then
			return BOT_ACTION_DESIRE_HIGH, bestTarget
		end
	end
	if Fu.IsDoingRoshan(bot) then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, 600, false, BOT_MODE_NONE)
		if
			Fu.IsRoshan(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, 500)
			and isAttacking
			and nearbyAllies ~= nil
			and #nearbyAllies >= 2
			and Fu.IsAttacking(nearbyAllies[1])
			and Fu.IsAttacking(nearbyAllies[2])
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, 500) and isAttacking then
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
return X
