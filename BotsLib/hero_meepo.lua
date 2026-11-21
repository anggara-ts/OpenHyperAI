-- Meepo: skill build, item build, and ability use for this hero.
local X = {}
local bot = GetBot()
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local AbilityContext = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local Minion = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local MeepoTrace = require(GetScriptDirectory() .. "/FuncLib/systems/meepo_trace")
-- [OHA-MTRACE] (#139): true only with Customize.Debug_Meepo_Trace; then a mark goes out before every order below.
local traceOn = MeepoTrace.IsOn()
local sTalentList = Fu.Skill.GetTalentList(bot)
local sAbilityList = Fu.Skill.GetAbilityList(bot)
local sRole = Fu.Item.GetRoleItemsBuyList(bot)
-- 7.41b moved +Poof Damage onto the level 15 pair.
local tTalentTreeList = { ["t25"] = { 10, 0 }, ["t20"] = { 0, 10 }, ["t15"] = { 10, 0 }, ["t10"] = { 10, 0 } }
local tAllAbilityBuildList = { { 2, 3, 6, 1, 2, 2, 2, 3, 3, 6, 3, 1, 1, 1, 6, 6 } }
local nAbilityBuildList = Fu.Skill.GetRandomBuild(tAllAbilityBuildList)
local nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList)
-- Blink Dagger (#9) is in every list. Stratz 7.41f (week of 5-11 Nov 2026, all ranks): Blink in 86% of pos 1
-- matches (3,626), over 95% of pos 2 (17,191) and 90% of pos 3 (1,061). It is bought right after Sange and Yasha
-- and before the Shard: by minute 24, 61% of pos 2 Meepos have Blink and 16% the Shard (Shard 38% in all).
-- Pos 3 gets Sange and Yasha too (94% of its matches; it was missing from that list).
local sRoleItemsBuyList = {}
-- Stratz 7.41f, week of 9 Nov 2026: pos 1, 5,550 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_1"] = {
	"item_tango",
	"item_circlet",
	"item_double_branches",
	"item_quelling_blade",
	"item_slippers",
	"item_wraith_band",
	"item_power_treads",
	"item_sange_and_yasha",
	"item_blink",
	"item_skadi",
	"item_aghanims_shard",
	"item_ultimate_scepter",
	"item_butterfly",
	"item_swift_blink",
	"item_ultimate_scepter_2",
	"item_sheepstick",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 2, 28,121 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_2"] = {
	"item_tango",
	"item_circlet",
	"item_double_branches",
	"item_quelling_blade",
	"item_slippers",
	"item_wraith_band",
	"item_power_treads",
	"item_sange_and_yasha",
	"item_blink",
	"item_aghanims_shard",
	"item_skadi",
	"item_ultimate_scepter",
	"item_swift_blink",
	"item_ultimate_scepter_2",
	"item_sheepstick",
	"item_moon_shard",
	"item_heart",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 3, 1,566 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_3"] = {
	"item_tango",
	"item_circlet",
	"item_double_branches",
	"item_quelling_blade",
	"item_slippers",
	"item_wraith_band",
	"item_power_treads",
	"item_sange_and_yasha",
	"item_blink",
	"item_aghanims_shard",
	"item_skadi",
	"item_ultimate_scepter",
	"item_butterfly",
	"item_ultimate_scepter_2",
	"item_diffusal_blade",
	"item_disperser",
	"item_swift_blink",
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
-- MegaMeepo and its Fling were removed in 7.42 (Valve patch notes); the Shard now gives a pick-up and
-- Fling Release on Divided We Stand, which the bot does not use yet.
local earthbindDesire, earthbindLocation
local poofDesire, poofTarget
local digDesire
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
	meepos = Fu.GetMeepos()
	botTarget = context.target
	hpRatio = context.hp
	isAttacking = Fu.IsAttacking(bot)
	poofDesire, poofTarget = X.ConsiderPoof()
	if poofDesire > 0 then
		if traceOn then
			MeepoTrace.Mark("meepo.order-poof")
		end
		Fu.SetQueuePtToINT(bot, false)
		bot:ActionQueue_UseAbilityOnEntity(poofAbility, poofTarget)
		return
	end
	digDesire = X.ConsiderDig()
	if digDesire > 0 then
		if traceOn then
			MeepoTrace.Mark("meepo.order-dig")
		end
		bot:ActionQueue_UseAbility(digAbility)
		return
	end
	earthbindDesire, earthbindLocation = X.ConsiderEarthBind()
	if earthbindDesire > 0 then
		if traceOn then
			MeepoTrace.Mark("meepo.order-earthbind")
		end
		Fu.SetQueuePtToINT(bot, false)
		bot:ActionQueue_UseAbilityOnLocation(earthbindAbility, earthbindLocation)
		rememberEarthbindCast(earthbindLocation)
		return
	end
	local regroupBody = X.ConsiderRegroup()
	if regroupBody ~= nil then
		if traceOn then
			MeepoTrace.Mark("meepo.order-regroup-move")
		end
		bot:Action_MoveToLocation(regroupBody:GetLocation())
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
-- Game 037: 14 Meepo deaths. Bodies Poofed into fights already lost (25:28, 27:25, 38:17) and were
-- split across the map (24:09: one body in rune mode while another died). The old checks counted every
-- Meepo body as an ally (#meepos, GetNearbyHeroes), so three bodies looked like three heroes.
local FIGHT_RADIUS = 1200
local function MeepoTag()
	return Fu.IsMeepoClone(bot) and "clone" or "main"
end
-- Allied heroes near a location with all Meepo bodies counted as one (they die together), and the real
-- enemy heroes there.
local function FightCountAt(location)
	local allies, meepoSeen = 0, false
	for _, ally in pairs(GetUnitList(UNIT_LIST_ALLIED_HEROES) or {}) do
		if Fu.IsValidHero(ally) and GetUnitToLocationDistance(ally, location) <= FIGHT_RADIUS then
			if ally:GetUnitName() == "npc_dota_hero_meepo" then
				if not meepoSeen and not Fu.IsSuspiciousIllusion(ally) then
					meepoSeen = true
					allies = allies + 1
				end
			elseif not ally:IsIllusion() then
				allies = allies + 1
			end
		end
	end
	-- The arriving body is a Meepo too.
	if not meepoSeen then
		allies = allies + 1
	end
	return allies, #Fu.GetEnemiesNearLoc(location, FIGHT_RADIUS)
end
-- Clearly lost: two or more enemy heroes and more of them than us (Meepo bodies count once). Game 037
-- t=2297: a lone body vs Dawnbreaker and MK took the Poofs, Mirana joined and all three bodies died.
local function IsFightLost(allies, enemies)
	return enemies >= 2 and enemies > allies
end
-- A Poof onto another body, unless it is an escape (that body near the fountain), only into a fight
-- that is not clearly lost.
function X.ConsiderPoof()
	local desire, target = X.ConsiderPoofRaw()
	if desire > 0 and target ~= nil and target ~= bot and target:DistanceFromFountain() >= 800 then
		local allies, enemies = FightCountAt(target:GetLocation())
		if IsFightLost(allies, enemies) then
			if DotaTime() >= (bot._poofLostLogAt or -999) then
				bot._poofLostLogAt = DotaTime() + 5
				pcall(
					print,
					string.format(
						"[OHA-MEEPO] t=%.0f %s poof-skip lost-fight allies=%d enemies=%d dist=%d targetHp=%.2f",
						DotaTime(),
						MeepoTag(),
						allies,
						enemies,
						GetUnitToUnitDistance(bot, target),
						Fu.GetHP(target)
					)
				)
			end
			return BOT_ACTION_DESIRE_NONE, nil
		end
	end
	return desire, target
end
-- Pull a body toward another body that is fighting (enemy hero within 1200, hero damage in the last 2s)
-- when the fight is not clearly lost, this body is 1600-3000 away, out of a fight, not retreating and not
-- at Roshan / a Tormentor. Poof (above) runs first; this is the walk when Poof is down or none of its
-- branches fire. SkillsComplement does not run while channeling or with queued actions (CanNotUseAbility).
function X.ConsiderRegroup()
	if Fu.IsLaning(bot) or isRetreating or hpRatio < 0.5 or Fu.IsDoingRoshan(bot) or Fu.IsDoingTormentor(bot) then
		return nil
	end
	if #(Fu.GetNearbyHeroes(bot, FIGHT_RADIUS, true, BOT_MODE_NONE) or {}) > 0 then
		return nil
	end
	for _, meepo in pairs(meepos) do
		if meepo ~= bot and Fu.IsValidHero(meepo) and meepo:WasRecentlyDamagedByAnyHero(2.0) then
			local distance = GetUnitToUnitDistance(bot, meepo)
			if distance > 1600 and distance <= 3000 then
				local allies, enemies = FightCountAt(meepo:GetLocation())
				if enemies >= 1 and not IsFightLost(allies, enemies) then
					if DotaTime() >= (bot._meepoRegroupLogAt or -999) then
						bot._meepoRegroupLogAt = DotaTime() + 5
						pcall(
							print,
							string.format(
								"[OHA-MEEPO] t=%.0f %s regroup dist=%d allies=%d enemies=%d poofCd=%.0f",
								DotaTime(),
								MeepoTag(),
								distance,
								allies,
								enemies,
								poofAbility:GetCooldownTimeRemaining()
							)
						)
					end
					return meepo
				end
			end
		end
	end
	return nil
end
function X.ConsiderPoofRaw()
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
				if traceOn then
					MeepoTrace.Mark("meepo.poof-out")
				end
				return BOT_ACTION_DESIRE_ABSOLUTE, meepo
			end
		end
	end
	-- Fight Poofs (#8). Poof damages at the departure AND the arrival spot (datafeed: "damaging the enemy in
	-- both the departure and arrival locations"), so an enemy near both, or a self-Poof in place, takes it twice.
	-- Game 038, 18:30: Earthbind rooted the Dire team and no Meepo Poofed. Two cases:
	--   * onto a Meepo next to a disabled (rooted / stunned) enemy hero: the team Poof nuke;
	--   * a kill: this Poof (counted at both ends) plus the other Meepos' Poofs that are ready.
	if not isRetreating and hpRatio > 0.25 then
		local readyOthers = 0
		for _, meepo in pairs(meepos) do
			if meepo ~= bot and Fu.IsValidHero(meepo) then
				local otherPoof = meepo:GetAbilityByName("meepo_poof")
				if otherPoof ~= nil and otherPoof:IsFullyCastable() then
					readyOthers = readyOthers + 1
				end
			end
		end
		local bestMeepo, bestScore, bestWhy = nil, 0, nil
		for _, meepo in pairs(meepos) do
			if Fu.IsValidHero(meepo) then
				for _, enemyHero in pairs(Fu.GetNearbyHeroes(meepo, radius, true, BOT_MODE_NONE) or {}) do
					if
						Fu.IsValidHero(enemyHero)
						and Fu.CanCastOnNonMagicImmune(enemyHero)
						and not Fu.IsSuspiciousIllusion(enemyHero)
					then
						local hits = 1 + (GetUnitToUnitDistance(bot, enemyHero) <= radius and 1 or 0)
						local damage = poofDamage * hits + poofDamage * readyOthers
						local disabled = Fu.IsDisabled(enemyHero) or enemyHero:IsRooted()
						local kill = Fu.CanKillTarget(enemyHero, damage, DAMAGE_TYPE_MAGICAL)
						local score = (kill and 3 or 0) + (disabled and 2 or 0) + hits - 1
						if (kill or disabled) and score > bestScore then
							bestMeepo, bestScore = meepo, score
							bestWhy = (kill and "kill" or "disabled")
								.. " target="
								.. (string.gsub(enemyHero:GetUnitName(), "npc_dota_hero_", ""))
								.. " hits="
								.. hits
								.. " readyOthers="
								.. readyOthers
						end
					end
				end
			end
		end
		if bestMeepo ~= nil and mpRatio > 0.15 then
			if DotaTime() >= (bot._poofFightLogAt or -999) then
				bot._poofFightLogAt = DotaTime() + 3
				pcall(print, string.format("[OHA-MEEPO] t=%.0f poof-fight why=%s", DotaTime(), bestWhy))
			end
			return BOT_ACTION_DESIRE_HIGH, bestMeepo
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
	-- Dig (Aghanim's Scepter since 7.42; datafeed): invulnerable and untargetable, basic dispel, 50% max HP back (was
	-- 25%), 4s (was 3s). It was
	-- cast whenever HP < 49% in any fight (#8, game 038). Now only when this body is being focused (hit by a hero
	-- in the last 1.5s under 40% with an enemy near), or to dispel a root / silence while being hit.
	local enemiesNear = #(Fu.GetNearbyHeroes(bot, 900, true, BOT_MODE_NONE) or {})
	local beingHit = bot:WasRecentlyDamagedByAnyHero(1.5)
	local focused = hpRatio < 0.4 and beingHit and enemiesNear >= 1
	local dispel = (bot:IsRooted() or bot:IsSilenced()) and beingHit and hpRatio < 0.7
	if focused or dispel then
		if DotaTime() >= (bot._digLogAt or -999) then
			bot._digLogAt = DotaTime() + 5
			pcall(
				print,
				string.format(
					"[OHA-MEEPO] t=%.0f dig why=%s hp=%.2f enemies=%d",
					DotaTime(),
					focused and "focused" or "dispel",
					hpRatio,
					enemiesNear
				)
			)
		end
		return BOT_ACTION_DESIRE_HIGH
	end
	return BOT_ACTION_DESIRE_NONE
end
-- [OHA-MTRACE] (#139): start/end lines around the hero code and each spell decision; the functions themselves when
-- the trace is off. Last, so the engine-facing callers (ability_item_usage_generic, bot_generic) get the wrapped ones.
X.SkillsComplement = MeepoTrace.Wrap("meepo.SkillsComplement", X.SkillsComplement)
X.MinionThink = MeepoTrace.Wrap("meepo.MinionThink", X.MinionThink)
X.ConsiderPoof = MeepoTrace.Wrap("meepo.ConsiderPoof", X.ConsiderPoof)
X.ConsiderPoofRaw = MeepoTrace.Wrap("meepo.ConsiderPoofRaw", X.ConsiderPoofRaw)
X.ConsiderDig = MeepoTrace.Wrap("meepo.ConsiderDig", X.ConsiderDig)
X.ConsiderEarthBind = MeepoTrace.Wrap("meepo.ConsiderEarthBind", X.ConsiderEarthBind)
X.ConsiderRegroup = MeepoTrace.Wrap("meepo.ConsiderRegroup", X.ConsiderRegroup)
return X
