-- Override for the built-in mode_attack_generic mode.
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
-- Kiting lives there now, shared with the per-think hook for heroes on Valve's attack mode.
local SpecialUnits = require(GetScriptDirectory() .. "/FuncLib/hero/special_units")
local AttackHelpers = {}
local bot = GetBot()
local attackTarget = { unit = nil, id = -1, location = nil, locationFuture = nil, hidden1 = false, hidden2 = false }
local attackRange, hpRatio, botHealth, attackDamage, unused, botLocation, botName
local skipNextDesire = false
local diveCooldown = { time = 0, interval = 0 }
local function isAliveUnit(unit)
	return unit ~= nil and not unit:IsNull() and unit:IsAlive()
end
BotsInit = require("game/botsinit")
local AttackMode = BotsInit.CreateGeneric()
function AttackMode.OnStart() end
function AttackMode.OnEnd()
	attackTarget.location = nil
	attackTarget.locationFuture = nil
	attackTarget.hidden1 = false
	attackTarget.hidden2 = false
end
-- The ally-follow desires (0.65) are skipped:
--   withdraw: farm is walking this bot out of the enemy half (bot._farmWithdrawUntil, set each think by
--     mode_farm_generic.lua), unless a hero is hitting the bot itself;
--   siege: a base siege is on (defend.lua Defend.GetBaseSiege, kept 10s) and the place to follow to is
--     over 3000 from the sieged building and over 4000 from our Ancient.
-- Returns the reason, or nil.
local FOLLOW_SIEGE_DIST, FOLLOW_ANCIENT_DIST = 3000, 4000
local function FollowSkipWhy(loc)
	if (bot._farmWithdrawUntil or -1) > DotaTime() and not bot:WasRecentlyDamagedByAnyHero(1.5) then
		return "withdraw"
	end
	local states = Fu.Utils.GameStates
	local siege = states ~= nil and states.baseSiege or nil
	if loc ~= nil and siege ~= nil and DotaTime() - siege.at <= 10 then
		local ancient = GetAncient(GetTeam())
		if
			Fu.GetDistance(loc, siege.loc) > FOLLOW_SIEGE_DIST
			and (ancient == nil or GetUnitToLocationDistance(ancient, loc) > FOLLOW_ANCIENT_DIST)
		then
			return "siege"
		end
	end
	return nil
end
local function LogFollowSkip(why, allyHero, loc)
	if DotaTime() < (bot._followSkipWhyLogAt or -999) then
		return
	end
	bot._followSkipWhyLogAt = DotaTime() + 5
	pcall(
		print,
		string.format(
			"[OHA-ATTACK] t=%.0f %s follow-skip why=%s ally=%s dist=%d",
			DotaTime(),
			(string.gsub(bot:GetUnitName(), "npc_dota_hero_", "")),
			why,
			(string.gsub(allyHero:GetUnitName(), "npc_dota_hero_", "")),
			GetUnitToLocationDistance(bot, loc)
		)
	)
end
function AttackMode.GetDesire()
	if not bot:IsAlive() or bot:IsIllusion() or bot:HasModifier("modifier_fountain_fury_swipes_damage_increase") then
		return BOT_MODE_DESIRE_NONE
	end
	if skipNextDesire then
		skipNextDesire = false
		return 0
	end
	if Fu.IsInLaningPhase() then
		local nearbyCreeps = bot:GetNearbyCreeps(600, true)
		if Fu.IsGoingOnSomeone(bot) and #nearbyCreeps >= 4 and bot:WasRecentlyDamagedByCreep(3.0) then
			return BOT_MODE_DESIRE_NONE
		end
	end
	attackTarget.hidden1 = false
	attackTarget.hidden2 = false
	attackRange = bot:GetAttackRange()
	hpRatio = Fu.GetHP(bot)
	botHealth = bot:GetHealth()
	attackDamage = bot:GetAttackDamage()
	botName = bot:GetUnitName()
	botLocation = bot:GetLocation()
	local isCore = Fu.IsCore(bot)
	local nearbyAllyHeroes = bot:GetNearbyHeroes(1600, false, BOT_MODE_NONE)
	local alliesNearby = Fu.GetAlliesNearLoc(botLocation, 1600)
	local nearbyEnemyHeroes = bot:GetNearbyHeroes(1600, true, BOT_MODE_NONE)
	local enemiesNearby = Fu.GetEnemiesNearLoc(botLocation, 1600)
	local enemyLaneCreeps = bot:GetNearbyLaneCreeps(1600, true)
	local enemyTowers = bot:GetNearbyTowers(1600, true)
	local bestTarget = nil
	local bestScore = 0
	for _, enemyHero in pairs(nearbyEnemyHeroes) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.IsInRange(bot, enemyHero, Max(1200, attackRange + 650))
			and not Fu.IsSuspiciousIllusion(enemyHero)
			and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
			and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
			and not enemyHero:HasModifier("modifier_skeleton_king_reincarnation_scepter_active")
			and not enemyHero:HasModifier("modifier_troll_warlord_battle_trance")
			and not enemyHero:HasModifier("modifier_winter_wyvern_cold_embrace")
		then
			local enemyName = enemyHero:GetUnitName()
			local weight = 1
			if enemyName == "npc_dota_hero_sniper" then
				weight = 4
			elseif enemyName == "npc_dota_hero_drow_ranger" then
				weight = 2
			elseif enemyName == "npc_dota_hero_crystal_maiden" then
				weight = 2
			elseif enemyName == "npc_dota_hero_jakiro" then
				weight = 2.5
			elseif enemyName == "npc_dota_hero_lina" then
				weight = 3
			elseif enemyName == "npc_dota_hero_nevermore" then
				weight = 3
			elseif enemyName == "npc_dota_hero_bristleback" and not enemyHero:IsFacingLocation(botLocation, 90) then
				weight = 0.5
			elseif enemyName == "npc_dota_hero_enchantress" and enemyHero:GetLevel() >= 6 then
				weight = 0.5
			end
			if enemyHero:HasModifier("modifier_troll_warlord_battle_trance") then
				weight = weight * 0.5
			end
			if enemyHero:HasModifier("modifier_item_blade_mail_reflect") then
				weight = weight * 0.3
			end
			if enemyHero:HasModifier("modifier_item_aeon_disk_buff") then
				weight = weight * 0.5
			end
			if enemyName ~= "npc_dota_hero_bristleback" then
				if Fu.IsCore(enemyHero) then
					weight = weight * 1.5
				else
					weight = weight * 0.5
				end
			end
			if Fu.IsDisabled(enemyHero) then
				weight = weight * 3
			end
			-- Jingu Mastery (game data): required_hits 4 (3 with the talent) on the same hero within
			-- counter_duration 5.5-10s gives 4 empowered attacks (+30-180 damage, 20-80% lifesteal). The
			-- counter sits on the enemy: keep hitting the marked hero instead of switching targets.
			if botName == "npc_dota_hero_monkey_king" then
				local jinguStacks = Fu.GetModifierCount(enemyHero, "modifier_monkey_king_quadruple_tap_counter")
				if jinguStacks > 0 then
					weight = weight * (1.5 + jinguStacks)
				end
			end
			if Fu.IsEarlyGame() or Fu.IsInLaningPhase() then
				if Fu.IsValidBuilding(enemyTowers[1]) and Fu.IsInRange(enemyHero, enemyTowers[1], 900) then
					-- Hard reject tower-hugging bait (starting gold rune → dive).
					if not Fu.CanKillTarget(enemyHero, bot:GetAttackDamage() * 2.0, DAMAGE_TYPE_PHYSICAL) then
						weight = weight * 0.05
					else
						weight = weight * 0.35
					end
				end
				if
					Fu.IsValidBuilding(enemyTowers[1])
					and Fu.IsInRange(bot, enemyTowers[1], (enemyTowers[1]:GetAttackRange() or 700) + 180)
				then
					weight = weight * 0.05
				end
			end
			local alliesNearEnemy = Fu.GetAlliesNearLoc(enemyHero:GetLocation(), 1200)
			local alliesDamage = Fu.GetTotalEstimatedDamageToTarget(alliesNearEnemy, enemyHero)
			local damageRatio = Max(alliesDamage / Max(enemyHero:GetHealth(), 1), 1)
			local missingHpRatio = 1 - Fu.GetHP(enemyHero)
			local killScore = (0.35 + missingHpRatio * 0.65) * Max(damageRatio, 0.15)
			local rangeFactor = Min(1, attackRange / GetUnitToUnitDistance(bot, enemyHero))
			local score = killScore * rangeFactor * weight
			if not Fu.CanBeAttacked(enemyHero) then
				score = score * 0.2
			end
			if score > bestScore then
				bestTarget = enemyHero
				bestScore = score
			end
		end
	end
	attackTarget.unit = bestTarget or AttackHelpers.GetWeakestNearbyHero(true, attackRange + 700)
	if Fu.IsValidHero(attackTarget.unit) then
		attackTarget.id = attackTarget.unit:GetPlayerID()
		attackTarget.location = attackTarget.unit:GetLocation()
		attackTarget.locationFuture = attackTarget.unit:GetExtrapolatedLocation(5.0)
	end
	if
		bot:HasModifier("modifier_marci_unleash") and Fu.GetModifierTime(bot, "modifier_marci_unleash") > 3
		or bot:HasModifier("modifier_muerta_pierce_the_veil_buff")
			and Fu.GetModifierTime(bot, "modifier_muerta_pierce_the_veil_buff") > 3
	then
		if
			#enemiesNearby > 0
			and #enemiesNearby < #alliesNearby + 2
			and (botName == "npc_dota_hero_muerta" and (hpRatio > 0.3 or bot:HasModifier("modifier_item_satanic_unholy") or bot:IsAttackImmune()) or botName == "npc_dota_hero_marci" and (hpRatio > 0.45 or bot:HasModifier(
				"modifier_item_satanic_unholy"
			) or bot:IsAttackImmune()))
			and Fu.IsValidHero(attackTarget.unit)
		then
			bot:SetTarget(attackTarget.unit)
			return BOT_MODE_DESIRE_HIGH
		end
	end
	if
		Fu.IsValidHero(attackTarget.unit)
		and not Fu.IsSuspiciousIllusion(attackTarget.unit)
		and not attackTarget.unit:HasModifier("modifier_necrolyte_reapers_scythe")
	then
		if DotaTime() < diveCooldown.time + diveCooldown.interval then
			return BOT_MODE_DESIRE_NONE
		end
		local diveInterval = AttackHelpers.IsRecklesslyDivingTower()
		if diveInterval ~= 0 then
			diveCooldown.time = DotaTime()
			diveCooldown.interval = diveInterval
			return BOT_MODE_DESIRE_NONE
		end
		local allyDamage = 0
		local allyHealth = 0
		local fightDuration = bot:GetLevel() < 6 and 2.5 or 5
		local allyHeroes = GetUnitList(UNIT_LIST_ALLIED_HEROES)
		for _, allyHero in ipairs(allyHeroes) do
			if
				Fu.IsValidHero(allyHero)
				and not Fu.IsSuspiciousIllusion(allyHero)
				and not allyHero:HasModifier("modifier_necrolyte_reapers_scythe")
				and not allyHero:HasModifier("modifier_teleporting")
				and (
					Fu.IsInLaningPhase() and Fu.IsInRange(allyHero, attackTarget.unit, 1600)
					or not Fu.IsInLaningPhase()
						and (GetUnitToUnitDistance(allyHero, attackTarget.unit) - allyHero:GetAttackRange()) / allyHero:GetCurrentMovementSpeed() <= 6.0
				)
			then
				local travelTime = Max(
					0,
					math.floor(
						(GetUnitToUnitDistance(allyHero, attackTarget.unit) - allyHero:GetAttackRange())
							/ allyHero:GetCurrentMovementSpeed()
					)
				)
				allyDamage = allyDamage
					+ allyHero:GetEstimatedDamageToTarget(
						true,
						attackTarget.unit,
						fightDuration - travelTime,
						DAMAGE_TYPE_ALL
					)
				allyHealth = allyHealth + allyHero:GetHealth()
			end
		end
		local towersNearTarget = attackTarget.unit:GetNearbyTowers(350, true)
		if
			Fu.IsValidBuilding(towersNearTarget[1]) and (Fu.IsEarlyGame() or not Fu.CanBeAttacked(towersNearTarget[1]))
		then
			allyDamage = allyDamage
				+ #towersNearTarget
					* attackTarget.unit:GetActualIncomingDamage(
						towersNearTarget[1]:GetAttackDamage() * 3,
						DAMAGE_TYPE_PHYSICAL
					)
		end
		local enemyDamage = 0
		local enemyHealth = 0
		local enemyHeroes = GetUnitList(UNIT_LIST_ENEMY_HEROES)
		for _, enemyHero in ipairs(enemyHeroes) do
			if
				Fu.IsValidHero(enemyHero)
				and GetUnitToUnitDistance(enemyHero, attackTarget.unit) / enemyHero:GetCurrentMovementSpeed() <= 6.0
				and not Fu.IsSuspiciousIllusion(enemyHero)
			then
				if
					not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
					and not enemyHero:HasModifier("modifier_teleporting")
				then
					if
						enemyHero:GetAttackTarget() == bot
						or Fu.IsChasingTarget(enemyHero, bot)
						or bot:WasRecentlyDamagedByHero(enemyHero, 2.0)
					then
						enemyDamage = enemyDamage
							+ enemyHero:GetEstimatedDamageToTarget(false, bot, fightDuration, DAMAGE_TYPE_ALL)
					end
				end
				enemyHealth = enemyHealth + enemyHero:GetHealth()
			end
		end
		enemyTowers = bot:GetNearbyTowers(1200, true)
		if Fu.IsValidBuilding(enemyTowers[1]) and (Fu.IsEarlyGame() or not Fu.CanBeAttacked(enemyTowers[1])) then
			enemyDamage = enemyDamage
				+ #enemyTowers
					* bot:GetActualIncomingDamage(enemyTowers[1]:GetAttackDamage() * 3, DAMAGE_TYPE_PHYSICAL)
		end
		if enemyHealth > 0 and Fu.IsValidHero(attackTarget.unit) then
			local killRatio = allyDamage / Max(attackTarget.unit:GetHealth(), 1)
			local deathRatio = enemyDamage / botHealth
			local attackDesire = RemapValClamped(killRatio, 1 / 3, 2 / 3, 0, 1.5)
			local safetyFactor = RemapValClamped(deathRatio, 0.5, 1.5, 1.5, 0.5)
			if Fu.IsInLaningPhase() then
				if #alliesNearby >= #enemiesNearby then
					if bot:HasModifier("modifier_tower_aura_bonus") then
						attackDesire = attackDesire + BOT_MODE_DESIRE_LOW
					end
				end
			end
			if #alliesNearby >= #enemiesNearby then
				if
					Fu.IsValidHero(enemiesNearby[1])
					and Fu.CanBeAttacked(enemiesNearby[1])
					and Fu.IsInRange(bot, enemiesNearby[1], attackRange + 150)
					and (
						not bot:WasRecentlyDamagedByAnyHero(3.0) and not bot:WasRecentlyDamagedByTower(2.0)
						or Fu.IsInTeamFight(bot, 1200)
					)
				then
					if not (Fu.IsInLaningPhase() and AttackHelpers.IsThereDyingCreepNearby()) then
						attackTarget.unit = enemiesNearby[1]
						attackDesire = attackDesire + BOT_MODE_DESIRE_HIGH
					end
				end
			end
			if bot:HasModifier("modifier_oracle_false_promise_timer") then
				if #alliesNearby >= #enemiesNearby and killRatio >= 1 / 3 or killRatio >= 0.8 then
					attackDesire = attackDesire + BOT_MODE_DESIRE_HIGH
				end
			end
			-- Lifesteal windows: Satanic Unholy Rage (175% lifesteal, 6s) and Monkey King's Jingu charges
			-- (20-80% lifesteal + bonus damage). Every hit heals and hurts, so fight while it lasts. Was
			-- only below 60% HP and within attack range - 75, so it stopped as soon as the heal worked.
			if
				(
					bot:HasModifier("modifier_item_satanic_unholy")
					or bot:HasModifier("modifier_monkey_king_quadruple_tap_bonuses")
				) and Fu.IsInRange(bot, attackTarget.unit, attackRange + 150)
			then
				if #alliesNearby >= #enemiesNearby and killRatio >= 1 / 3 or killRatio >= 0.8 then
					attackDesire = attackDesire + BOT_MODE_DESIRE_HIGH
				end
			end
			if bot:HasModifier("modifier_slark_shadow_dance") then
				if #alliesNearby >= #enemiesNearby and killRatio >= 1 / 3 or killRatio >= 2 / 3 then
					attackDesire = attackDesire + BOT_MODE_DESIRE_HIGH
				end
			end
			local desire = RemapValClamped(
				attackDesire * safetyFactor,
				0,
				1,
				BOT_MODE_DESIRE_NONE,
				BOT_MODE_DESIRE_VERYHIGH + 0.05
			)
			if desire > BOT_MODE_DESIRE_VERYHIGH then
				bot:SetTarget(attackTarget.unit)
				return desire
			end
		end
	end
	for _, allyHero in pairs(GetUnitList(UNIT_LIST_ALLIED_HEROES)) do
		if
			Fu.IsValidHero(allyHero)
			and bot ~= allyHero
			and not allyHero:IsIllusion()
			and not allyHero:HasModifier("modifier_necrolyte_reapers_scythe")
			and not allyHero:HasModifier("modifier_teleporting")
			and (
				Fu.IsInLaningPhase() and Fu.IsInRange(bot, allyHero, 900)
				or not Fu.IsInLaningPhase()
					and GetUnitToUnitDistance(bot, allyHero) / bot:GetCurrentMovementSpeed() <= 11.0
			)
		then
			local allyTarget = Fu.GetProperTarget(allyHero)
			if Fu.IsGoingOnSomeone(allyHero) then
				-- Don't pile into a lost fight / solo chase when outnumbered.
				-- Still commit when the target dies to one attack.
				local finishKill = Fu.IsValidHero(allyTarget) and Fu.ShouldFinishCommittedKill(bot, allyTarget)
				if not finishKill then
					local allyN = Fu.GetAllyCount(bot, 1400)
					local enemyN = Fu.GetEnemyCount(bot, 1400)
					if enemyN >= allyN + 1 and not Fu.WeAreStronger(bot, 1400) then
						goto continue_ally_follow
					end
					if allyN <= 1 and enemyN >= 2 then
						goto continue_ally_follow
					end
				end
				if Fu.IsValidHero(allyTarget) and not Fu.IsSuspiciousIllusion(allyTarget) then
					local far = GetUnitToUnitDistance(bot, allyTarget)
					-- The outnumbered gate above counts around this bot, so from 2000-4000 away it always
					-- passed (game 037: 50 follows beyond 1600, e.g. Kez and Hoodwink walking 2100-2400
					-- onto Dawnbreaker at t=2197 with 5 Dire there; all died). Count at the fight.
					if far > 1200 and not finishKill then
						local fightLoc = allyTarget:GetLocation()
						local enemiesAtFight = math.max(
							#Fu.GetEnemiesNearLoc(fightLoc, 1400),
							#(Fu.GetLastSeenEnemiesNearLoc(fightLoc, 1400) or {})
						)
						local alliesAtFight = #Fu.GetAlliesNearLoc(fightLoc, 1400)
						if enemiesAtFight >= alliesAtFight + 2 or alliesAtFight <= 1 and enemiesAtFight >= 3 then
							if DotaTime() >= (bot._followSkipLogAt or -999) then
								bot._followSkipLogAt = DotaTime() + 5
								pcall(
									print,
									string.format(
										"[OHA-ATTACK] t=%.0f %s follow-skip lost-fight ally=%s target=%s dist=%d enemiesThere=%d alliesThere=%d",
										DotaTime(),
										(string.gsub(botName, "npc_dota_hero_", "")),
										(string.gsub(allyHero:GetUnitName(), "npc_dota_hero_", "")),
										(string.gsub(allyTarget:GetUnitName(), "npc_dota_hero_", "")),
										far,
										enemiesAtFight,
										alliesAtFight
									)
								)
							end
							goto continue_ally_follow
						end
					end
					local skipWhy = FollowSkipWhy(allyTarget:GetLocation())
					if skipWhy ~= nil then
						LogFollowSkip(skipWhy, allyHero, allyTarget:GetLocation())
						goto continue_ally_follow
					end
					attackTarget.unit = allyTarget
					bot:SetTarget(attackTarget.unit)
					-- This is the 0.65 (VERYHIGH 0.6 + 0.05) attack with no enemy near: following an ally
					-- up to 11s of walking away. Think used to drop a target beyond 1200 (skipNextDesire = true), so
					-- the next desire read 0 and the bot flipped attack/assemble (game 036, Primal Beast,
					-- 20 changes at 41:41). Think now walks to it; logged here.
					if far > 1200 and DotaTime() >= (bot._flipSrcLogAt or -999) then
						bot._flipSrcLogAt = DotaTime() + 5
						pcall(
							print,
							string.format(
								"[OHA-FLIPSRC] t=%.0f %s attack=0.65 follow ally=%s target=%s dist=%d",
								DotaTime(),
								(string.gsub(botName, "npc_dota_hero_", "")),
								(string.gsub(allyHero:GetUnitName(), "npc_dota_hero_", "")),
								(string.gsub(allyTarget:GetUnitName(), "npc_dota_hero_", "")),
								far
							)
						)
					end
					return BOT_MODE_DESIRE_VERYHIGH + 0.05
				end
				if Fu.IsInRange(bot, allyHero, 1000) and #enemiesNearby == 0 then
					-- "Ally in attack mode with no target" is not a fight. Game 037: Kez and Hoodwink (the
					-- two override users) stood 46 apart in attack 0.65 with no enemy for 30s (t=1978-2009,
					-- also t=616 and 918): each walked to the other because the other was in attack mode.
					-- Follow only when the ally is really fighting.
					local allyLoc = allyHero:GetLocation()
					local allyFighting = allyHero:WasRecentlyDamagedByAnyHero(3.0)
						or #Fu.GetEnemiesNearLoc(allyLoc, 1200) > 0
						or #(Fu.GetLastSeenEnemiesNearLoc(allyLoc, 1200) or {}) > 0
					local skipWhy = allyFighting and FollowSkipWhy(allyLoc) or nil
					if skipWhy ~= nil then
						LogFollowSkip(skipWhy, allyHero, allyLoc)
						goto continue_ally_follow
					end
					if allyFighting then
						attackTarget.location = allyLoc
						attackTarget.hidden1 = true
						return BOT_MODE_DESIRE_VERYHIGH + 0.05
					end
					if DotaTime() >= (bot._followIdleLogAt or -999) then
						bot._followIdleLogAt = DotaTime() + 10
						pcall(
							print,
							string.format(
								"[OHA-ATTACK] t=%.0f %s follow-skip no-fight ally=%s allyMode=%d dist=%d",
								DotaTime(),
								(string.gsub(botName, "npc_dota_hero_", "")),
								(string.gsub(allyHero:GetUnitName(), "npc_dota_hero_", "")),
								allyHero:GetActiveMode(),
								GetUnitToUnitDistance(bot, allyHero)
							)
						)
					end
				end
				for i = 1, 5 do
					local teammate = GetTeamMember(i)
					if teammate and teammate == allyHero then
						local ping = teammate:GetMostRecentPing()
						if ping ~= nil and ping.normal_ping and GameTime() < ping.time + 5.5 then
							local enemiesNearPing = Fu.GetEnemiesNearLoc(ping.location, 300)
							local skipWhy = FollowSkipWhy(ping.location)
							if Fu.IsValidHero(enemiesNearPing[1]) and skipWhy ~= nil then
								LogFollowSkip(skipWhy, allyHero, ping.location)
							elseif Fu.IsValidHero(enemiesNearPing[1]) then
								attackTarget.location = ping.location
								-- Think only walks to attackTarget.location with hidden1 set; without it this
								-- desire did nothing and dropped to 0 next think.
								attackTarget.hidden1 = true
								return BOT_MODE_DESIRE_VERYHIGH + 0.05
							end
						end
					end
				end
			end
			::continue_ally_follow::
		end
	end
	if #enemiesNearby == 0 then
		if attackTarget.locationFuture then
			for _, playerId in ipairs(GetTeamPlayers(GetOpposingTeam())) do
				if IsHeroAlive(playerId) and playerId == attackTarget.id then
					local lastSeenInfo = GetHeroLastSeenInfo(playerId)
					if lastSeenInfo then
						local lastSeen = lastSeenInfo[1]
						if
							lastSeen
							and lastSeen.time_since_seen > 0.5
							and lastSeen.time_since_seen < 5.0
							and Fu.GetDistance(lastSeen.location, attackTarget.locationFuture) <= 1200
							and Fu.GetDistance(botLocation, attackTarget.locationFuture) <= 1200
						then
							attackTarget.hidden2 = true
							return BOT_MODE_DESIRE_VERYHIGH + 0.05
						end
					end
				end
			end
		end
	end
	return BOT_MODE_DESIRE_NONE
end
function AttackMode.Think()
	if Fu.CanNotUseAction(bot) then
		return
	end
	local nearbyEnemyHeroes = bot:GetNearbyHeroes(1600, true, BOT_MODE_NONE)
	local enemyTowers = bot:GetNearbyTowers(1600, true)
	if bot:HasModifier("modifier_pugna_life_drain") then
		for _, enemyHero in ipairs(nearbyEnemyHeroes) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.IsInRange(bot, enemyHero, 750)
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and (
					enemyHero:GetUnitName() == "npc_dota_hero_pugna"
					or enemyHero:GetUnitName() == "npc_dota_hero_rubick"
				)
			then
				bot:Action_MoveToLocation(Fu.VectorAway(botLocation, enemyHero:GetLocation(), 800))
				return
			end
		end
	elseif bot:HasModifier("modifier_razor_static_link_debuff") then
		for _, enemyHero in ipairs(nearbyEnemyHeroes) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.IsInRange(bot, enemyHero, 750)
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and enemyHero:GetUnitName() == "npc_dota_hero_razor"
			then
				bot:Action_MoveToLocation(Fu.VectorAway(botLocation, enemyHero:GetLocation(), 800))
				return
			end
		end
	else
		for _, enemyHero in pairs(nearbyEnemyHeroes) do
			if
				Fu.IsValidHero(enemyHero)
				and enemyHero:GetAttackTarget() == bot
				and (
					enemyHero:HasModifier("modifier_item_helm_of_the_undying_active")
					or enemyHero:HasModifier("modifier_skeleton_king_reincarnation_scepter_active")
				)
			then
				if Fu.IsInRange(bot, enemyHero, enemyHero:GetAttackRange() + 150) then
					bot:Action_MoveToLocation(
						Fu.VectorAway(botLocation, enemyHero:GetLocation(), enemyHero:GetAttackRange() * 2)
					)
					return
				end
			end
		end
	end
	if attackTarget.unit == nil then
		attackTarget.unit = AttackHelpers.GetWeakestNearbyHero(true, attackRange + 800)
	end
	if Fu.IsValidHero(attackTarget.unit) and Fu.IsInRange(bot, attackTarget.unit, 1200) then
		local distance = GetUnitToUnitDistance(bot, attackTarget.unit)
		local isMuerta = botName == "npc_dota_hero_muerta"
		local isEthereal = Fu.IsInEtherealForm(attackTarget.unit)
		local isUnattackable = attackTarget.unit:IsAttackImmune() and (not isEthereal or not isMuerta)
		if isUnattackable then
			bot:Action_MoveToLocation(Fu.VectorTowards(attackTarget.unit:GetLocation(), botLocation, attackRange / 2))
			return
		end
		if SpecialUnits.TryKite(bot, attackTarget.unit) then
			return
		end
		bot:Action_AttackUnit(attackTarget.unit, false)
		return
	end
	if attackTarget.hidden1 and attackTarget.location then
		bot:Action_MoveToLocation(attackTarget.location)
		return
	end
	if attackTarget.hidden2 and attackTarget.locationFuture then
		if GetUnitToLocationDistance(bot, attackTarget.locationFuture) > attackRange then
			bot:Action_MoveToLocation(attackTarget.locationFuture)
			return
		end
	end
	-- An ally's fight target beyond 1200 (the ally-follow desire): walk there instead of
	-- dropping the mode, which made the next desire 0 and the bot flip attack/assemble.
	if Fu.IsValidHero(attackTarget.unit) and not Fu.IsSuspiciousIllusion(attackTarget.unit) then
		bot:Action_MoveToLocation(attackTarget.unit:GetLocation())
		return
	end
	skipNextDesire = true
end
function AttackHelpers.IsRecklesslyDivingTower()
	if Fu.IsValidHero(attackTarget.unit) then
		local enemyTowers = bot:GetNearbyTowers(800, true)
		if Fu.IsValidBuilding(enemyTowers[1]) then
			local targetEnemies = attackTarget.unit:GetNearbyHeroes(900, true, BOT_MODE_NONE)
			local incomingDamage = 0
			for _, allyHero in pairs(targetEnemies) do
				if
					Fu.IsValidHero(allyHero)
					and Fu.IsGoingOnSomeone(allyHero)
					and not Fu.IsSuspiciousIllusion(allyHero)
				then
					local allyTarget = Fu.GetProperTarget(allyHero)
					if allyTarget == attackTarget.unit then
						incomingDamage = incomingDamage
							+ allyHero:GetAttackDamage()
								* allyHero:GetAttackSpeed()
								* Max(
									1,
									3
										- GetUnitToUnitDistance(allyHero, attackTarget.unit)
											/ allyHero:GetCurrentMovementSpeed()
								)
					end
				end
			end
			if
				attackTarget.unit:GetActualIncomingDamage(incomingDamage, DAMAGE_TYPE_PHYSICAL)
				< attackTarget.unit:GetHealth() + attackTarget.unit:GetHealthRegen() * 3
			then
				return 2.5
			end
		end
	end
	return 0
end
function AttackHelpers.IsThereDyingCreepNearby()
	local enemyLaneCreeps = bot:GetNearbyLaneCreeps(Min(attackRange + 300, 1600), true)
	for _, creep in pairs(enemyLaneCreeps) do
		if Fu.IsValid(creep) and Fu.CanBeAttacked(creep) then
			if creep:GetHealth() < attackDamage + attackDamage / 2 then
				return true
			end
		end
	end
	return false
end
function AttackHelpers.GetWeakestNearbyHero(enemies, range)
	local weakestHero = nil
	local bestRatio = 0
	local heroes = bot:GetNearbyHeroes(Min(range, 1600), enemies, BOT_MODE_NONE)
	for _, hero in ipairs(heroes) do
		if
			Fu.IsValidHero(hero)
			and not Fu.IsSuspiciousIllusion(hero)
			and not hero:HasModifier("modifier_abaddon_borrowed_time")
			and not hero:HasModifier("modifier_necrolyte_reapers_scythe")
			and not hero:HasModifier("modifier_skeleton_king_reincarnation_scepter_active")
			and not hero:HasModifier("modifier_item_helm_of_the_undying_active")
		then
			local damageRatio = hero:GetActualIncomingDamage(
				bot:GetAttackDamage() * bot:GetAttackSpeed() * 3.0,
				DAMAGE_TYPE_PHYSICAL
			) / (hero:GetHealth() + hero:GetHealthRegen() * 3.0)
			if damageRatio > bestRatio then
				weakestHero = hero
				bestRatio = damageRatio
			end
		end
	end
	return weakestHero
end
return AttackMode
