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
	local regroupBody = X.ConsiderRegroup()
	if regroupBody ~= nil then
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
	X.HoldFountainTp()
	local desire, target = X.ConsiderPoofRaw()
	if desire <= 0 then
		X.LogPoofIdle()
	end
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
-- Back to the others by Poof (#8). A body that went home to heal (TP, walk or an escape Poof) only had a Poof
-- back in laning, push / defend, Roshan and Tormentor mode or onto a body chasing a hero; otherwise it spent the
-- TP scroll ("fountain TP out", from 75% HP) or walked. Game 045, 16:38: the main body, healed to 85%, used the
-- scroll to reach the bottom lane where another body was farming. Poof reaches a body anywhere (game data:
-- meepo_poof has no AbilityCastRange; the branches below already cross the map with it), costs 80 mana and
-- keeps the scroll for the next escape.
-- The body to go to: 3500+ from our fountain, above half HP, not retreating, not in a fight that is clearly lost.
-- Not while the base needs this body: it is in a defend mode, an enemy hero is within 1600, or enemy heroes were
-- seen within 3500 of our Ancient (the same check that keeps the fountain TP at home).
function X.PoofOutBody()
	if bot:DistanceFromFountain() > 1500 or not poofAbility:IsTrained() or Fu.IsDefending(bot) then
		return nil
	end
	if #(Fu.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE) or {}) > 0 then
		return nil
	end
	local ancient = GetAncient(GetTeam())
	if ancient ~= nil and #(Fu.GetLastSeenEnemiesNearLoc(ancient:GetLocation(), 3500) or {}) > 0 then
		return nil
	end
	local bestBody, bestHp = nil, 0.5
	for _, meepo in pairs(meepos) do
		if
			meepo ~= bot
			and Fu.IsValidHero(meepo)
			and meepo:DistanceFromFountain() > 3500
			and Fu.GetHP(meepo) > bestHp
			and not Fu.IsRetreating(meepo)
		then
			local allies, enemies = FightCountAt(meepo:GetLocation())
			if not IsFightLost(allies, enemies) then
				bestBody, bestHp = meepo, Fu.GetHP(meepo)
			end
		end
	end
	return bestBody
end
-- Items think before spells, so the scroll would go first. While this body is at the fountain and such a body
-- exists, hold its TP: the tpscroll rule in ability_item_usage_generic.lua reads bot._meepoPoofOutHold. The hold
-- lapses 2s after the last think that set it, and after 30s in a row it pauses for 20s, so a Poof that never
-- comes (silenced, mana burned) cannot keep him in the base.
function X.HoldFountainTp()
	local now = DotaTime()
	if now < (bot._meepoPoofOutPause or -999) or X.PoofOutBody() == nil then
		return
	end
	if bot._meepoPoofOutSince == nil or now > (bot._meepoPoofOutHold or -999) then
		bot._meepoPoofOutSince = now
	end
	if now - bot._meepoPoofOutSince > 30 then
		bot._meepoPoofOutPause = now + 20
		return
	end
	bot._meepoPoofOutHold = now + 2
end
-- Poof into a trade (#8, game 038, 4:00), log only. The card asks for a Poof while an enemy hero is "in reach",
-- but Poof only hits within its radius (400) of a body after a 1.5s cast, and at that moment Alchemist stood
-- 755-802 away. This says how often an enemy hero really is inside the radius with Poof ready and no rule casting it
-- (the fight rules need a kill or a disabled enemy), and whether he stands still: the facts a trade rule needs.
function X.LogPoofIdle()
	if DotaTime() < (bot._poofIdleLogAt or -999) or not poofAbility:IsFullyCastable() then
		return
	end
	local radius = poofAbility:GetSpecialValueInt("radius")
	for _, enemyHero in pairs(Fu.GetNearbyHeroes(bot, radius, true, BOT_MODE_NONE) or {}) do
		if Fu.IsValidHero(enemyHero) and not Fu.IsSuspiciousIllusion(enemyHero) then
			bot._poofIdleLogAt = DotaTime() + 8
			pcall(
				print,
				string.format(
					"[OHA-MEEPO] t=%.0f %s poof-idle enemy=%s dist=%d enemyHp=%.2f running=%s onMe=%s hp=%.2f mp=%.2f mode=%d bodies=%d",
					DotaTime(),
					MeepoTag(),
					(string.gsub(enemyHero:GetUnitName(), "npc_dota_hero_", "")),
					GetUnitToUnitDistance(bot, enemyHero),
					Fu.GetHP(enemyHero),
					tostring(Fu.IsRunning(enemyHero)),
					tostring(enemyHero:GetAttackTarget() == bot),
					hpRatio,
					mpRatio,
					bot:GetActiveMode(),
					#meepos
				)
			)
			return
		end
	end
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
				return BOT_ACTION_DESIRE_ABSOLUTE, meepo
			end
		end
	end
	-- Healed at the fountain (the HP and mana at which retreat lets go of it: mode_retreat_generic.lua, tag 360)
	-- with another body out on the map: Poof to it (X.PoofOutBody above).
	if hpRatio > 0.9 and mpRatio > 0.8 and not bot._sellPending then
		local outBody = X.PoofOutBody()
		if outBody ~= nil then
			if DotaTime() >= (bot._poofOutLogAt or -999) then
				bot._poofOutLogAt = DotaTime() + 5
				pcall(
					print,
					string.format(
						"[OHA-MEEPO] t=%.0f %s poof-out dist=%d targetHp=%.2f hp=%.2f mp=%.2f held=%.0f",
						DotaTime(),
						MeepoTag(),
						GetUnitToUnitDistance(bot, outBody),
						Fu.GetHP(outBody),
						hpRatio,
						mpRatio,
						DotaTime() - (bot._meepoPoofOutSince or DotaTime())
					)
				)
			end
			return BOT_ACTION_DESIRE_HIGH, outBody
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
	-- Dig (Shard, datafeed): 3s invulnerable and untargetable, basic dispel, 25% max HP back, 40s cooldown. It was
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
