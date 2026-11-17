-- Shared helper: combat.
local function installCombat(Fu)
	function Fu.IsOtherAllyCanKillTarget(bot, target)
		if not Fu.IsValid(target) then
			return false
		end
		local CacheKeys = Fu.CK
		if CacheKeys then
			local cached = Fu.Utils.GetCachedVars(CacheKeys.IS_OTHER_ALLY_CAN_KILL + target:GetPlayerID(), 0.5)
			if cached ~= nil then
				return cached
			end
		end
		if target:GetHealth() / target:GetMaxHealth() > 0.38 then
			if CacheKeys then
				Fu.Utils.SetCachedVars(CacheKeys.IS_OTHER_ALLY_CAN_KILL + target:GetPlayerID(), false)
			end
			return false
		end
		local totalDamage = 0
		local damageType = DAMAGE_TYPE_PHYSICAL
		local teamPlayers = GetTeamPlayers(GetTeam())
		for i = 1, #teamPlayers do
			local member = GetTeamMember(i)
			if
				Fu.IsValidTarget(member)
				and member ~= bot
				and not Fu.IsDisabled(member)
				and member:GetHealth() / member:GetMaxHealth() > 0.15
				and member:IsFacingLocation(target:GetLocation(), 20)
				and GetUnitToUnitDistance(member, target) <= member:GetAttackRange() + 50
			then
				local memberTarget = Fu.GetProperTarget(member)
				if memberTarget == nil or memberTarget == target or Fu.IsHumanPlayer(member) then
					local duration = Fu.IsHumanPlayer(member) and 6.0 or 2.0
					totalDamage = totalDamage
						+ member:GetEstimatedDamageToTarget(true, target, duration, DAMAGE_TYPE_PHYSICAL)
				end
			end
		end
		local result = totalDamage > target:GetHealth()
		if CacheKeys then
			Fu.Utils.SetCachedVars(CacheKeys.IS_OTHER_ALLY_CAN_KILL + target:GetPlayerID(), result)
		end
		return result
	end
	function Fu.CanCastOnMagicImmune(unit)
		return unit:CanBeSeen()
			and not unit:IsInvulnerable()
			and not Fu.IsSuspiciousIllusion(unit)
			and not Fu.HasForbiddenModifier(unit)
	end
	function Fu.IsNotImmune(unit)
		return Fu.IsValidTarget(unit) and unit:CanBeSeen() and not unit:IsInvulnerable() and not unit:IsMagicImmune()
	end
	function Fu.IsRecklesslyDivingTower(bot, target)
		if not Fu.IsValidHero(target) then
			return false
		end
		local nearbyTowers = bot:GetNearbyTowers(800, true)
		if not Fu.IsValidBuilding(nearbyTowers[1]) then
			return false
		end
		local targetEnemies = target:GetNearbyHeroes(900, true, BOT_MODE_NONE)
		local incomingDamage = 0
		for _, attacker in pairs(targetEnemies) do
			if Fu.IsValidHero(attacker) and Fu.IsGoingOnSomeone(attacker) and not Fu.IsSuspiciousIllusion(attacker) then
				local attackerTarget = Fu.GetProperTarget(attacker)
				if attackerTarget == target then
					local approachTime = math.max(
						0,
						(GetUnitToUnitDistance(attacker, target) - attacker:GetAttackRange())
							/ math.max(1, attacker:GetCurrentMovementSpeed())
					)
					incomingDamage = incomingDamage
						+ attacker:GetAttackDamage() * attacker:GetAttackSpeed() * math.max(1, 3 - approachTime)
				end
			end
		end
		local effectiveHealth = target:GetHealth() + target:GetHealthRegen() * 3
		if target:GetActualIncomingDamage(incomingDamage, DAMAGE_TYPE_PHYSICAL) < effectiveHealth then
			return true
		end
		return false
	end
	function Fu.IsReflectingSpells(unit)
		if unit == nil then
			return false
		end
		return unit:HasModifier("modifier_item_lotus_orb_active")
			or unit:HasModifier("modifier_antimage_counterspell")
			or unit:HasModifier("modifier_mirror_shield")
	end
	function Fu.FilterEnemiesForStun(enemies)
		local filtered = {}
		for _, enemyHero in pairs(enemies) do
			if
				not Fu.IsSuspiciousIllusion(enemyHero)
				and not enemyHero:IsRooted()
				and not enemyHero:IsStunned()
				and not enemyHero:IsHexed()
				and not enemyHero:IsNightmared()
				and not Fu.IsTaunted(enemyHero)
			then
				table.insert(filtered, enemyHero)
			end
		end
		return filtered
	end
	function Fu.CanCastOnNonMagicImmune(unit)
		return unit:CanBeSeen()
			and not unit:IsMagicImmune()
			and not unit:IsInvulnerable()
			and not Fu.IsSuspiciousIllusion(unit)
			and not Fu.HasForbiddenModifier(unit)
	end
	function Fu.CanCastOnTargetAdvanced(unit)
		if Fu.IsSuspiciousIllusion(unit) then
			return false
		end
		if unit:GetUnitName() == "npc_dota_hero_antimage" then
			if
				unit:HasModifier("modifier_antimage_spell_shield")
				and Fu.GetModifierTime(unit, "modifier_antimage_spell_shield") > 0.27
			then
				return false
			end
			if
				unit:IsSilenced()
				or unit:IsStunned()
				or unit:IsHexed()
				or unit:IsNightmared()
				or unit:IsChanneling()
				or Fu.IsTaunted(unit)
				or unit:GetMana() < 45
				or unit:HasModifier("modifier_antimage_spell_shield")
					and Fu.GetModifierTime(unit, "modifier_antimage_spell_shield") < 0.27
			then
				if
					not unit:HasModifier("modifier_item_sphere_target")
					and not unit:HasModifier("modifier_item_lotus_orb_active")
					and not unit:HasModifier("modifier_item_aeon_disk_buff")
					and (not unit:HasModifier("modifier_dazzle_shallow_grave") or unit:GetHealth() > 300)
				then
					return true
				end
			end
			return false
		end
		return not unit:HasModifier("modifier_item_sphere_target")
			and not unit:HasModifier("modifier_antimage_spell_shield")
			and not unit:HasModifier("modifier_brewmaster_earth_spell_immunity")
			and not unit:HasModifier("modifier_item_lotus_orb_active")
			and not unit:HasModifier("modifier_item_aeon_disk_buff")
			and not unit:HasModifier("modifier_roshan_spell_block")
			and (not unit:HasModifier("modifier_dazzle_shallow_grave") or unit:GetHealth() > 300)
	end
	function Fu.CanKillTarget(unit, damage, damageType)
		if damageType == DAMAGE_TYPE_PURE then
			return damage >= unit:GetHealth()
		end
		return unit:GetActualIncomingDamage(damage, damageType) >= unit:GetHealth()
	end
	-- True when one real auto-attack from attacker, or an ally already in hit range, kills target.
	function Fu.IsOneAutoAttackKill(attacker, target)
		if not Fu.IsValidHero(attacker) or not Fu.IsValidHero(target) or Fu.IsSuspiciousIllusion(target) then
			return false
		end
		if target:IsInvulnerable() or target:IsAttackImmune() then
			return false
		end
		if
			target:HasModifier("modifier_abaddon_borrowed_time")
			or target:HasModifier("modifier_dazzle_shallow_grave")
			or target:HasModifier("modifier_oracle_false_promise_timer")
			or target:HasModifier("modifier_item_aeon_disk_buff")
		then
			return false
		end
		local hp = target:GetHealth()
		if hp <= 0 then
			return false
		end
		local function hitKills(unit)
			if not Fu.IsValidHero(unit) or Fu.IsSuspiciousIllusion(unit) then
				return false
			end
			local damage = unit:GetAttackDamage()
			if type(damage) ~= "number" or damage <= 0 then
				return false
			end
			return target:GetActualIncomingDamage(damage, DAMAGE_TYPE_PHYSICAL) >= hp
		end
		if hitKills(attacker) then
			return true
		end
		local allies = attacker:GetNearbyHeroes(1000, false, BOT_MODE_NONE) or {}
		for _, ally in pairs(allies) do
			if
				ally ~= attacker
				and hitKills(ally)
				and GetUnitToUnitDistance(ally, target) <= ally:GetAttackRange() + 250
			then
				return true
			end
		end
		return false
	end
	-- Stay in a committed fight to land the last hit instead of leaving on a numbers disadvantage.
	function Fu.ShouldFinishCommittedKill(bot, target)
		if not Fu.IsValidHero(bot) then
			return false
		end
		local reach = math.max((bot:GetAttackRange() or 150) + 750, 1100)
		if
			Fu.IsValidHero(target)
			and GetUnitToUnitDistance(bot, target) <= reach
			and Fu.IsOneAutoAttackKill(bot, target)
		then
			return true
		end
		local enemies = bot:GetNearbyHeroes(math.min(reach, 1200), true, BOT_MODE_NONE) or {}
		for _, enemy in pairs(enemies) do
			if Fu.IsOneAutoAttackKill(bot, enemy) then
				return true
			end
		end
		return false
	end
	function Fu.WillKillTarget(unit, damage, damageType, delay)
		local effectiveHealth = unit:GetHealth() + unit:GetHealthRegen() * delay + 0.8
		local attackDamage = Fu.GetTotalAttackWillRealDamage(unit, delay)
		local totalDamage = unit:GetActualIncomingDamage(damage, damageType) + attackDamage
		return totalDamage > effectiveHealth and attackDamage < effectiveHealth - 1
	end
	function Fu.WillMixedDamageKillTarget(unit, physicalDamage, magicalDamage, pureDamage, delay)
		local effectiveHealth = unit:GetHealth() + unit:GetHealthRegen() * delay + 0.8
		local attackDamage = Fu.GetTotalAttackWillRealDamage(unit, delay)
		local physicalTaken = unit:GetActualIncomingDamage(physicalDamage, DAMAGE_TYPE_PHYSICAL)
		local magicalTaken = unit:GetActualIncomingDamage(magicalDamage, DAMAGE_TYPE_MAGICAL)
		local pureTaken = unit:GetActualIncomingDamage(pureDamage, DAMAGE_TYPE_PURE)
		local totalDamage = physicalTaken + magicalTaken + pureTaken + attackDamage
		return totalDamage > effectiveHealth and attackDamage < effectiveHealth - 1
	end
	function Fu.WillMagicKillTarget(bot, unit, damage, delay)
		local damageType = DAMAGE_TYPE_MAGICAL
		local magicMultiplier = 1 - unit:GetMagicResist()
		if magicMultiplier < 0.05 then
			magicMultiplier = 0.05
		end
		local regenDuringDelay = unit:GetHealthRegen() * delay
		local spellDamage = damage * (1 + bot:GetSpellAmp()) - regenDuringDelay / magicMultiplier
		if unit:HasModifier("modifier_medusa_mana_shield") then
			local manaShieldDamage = spellDamage * 0.98
			if unit:GetMana() * 2.8 >= manaShieldDamage then
				spellDamage = spellDamage * 0.04
			else
				spellDamage = spellDamage * 0.02 + manaShieldDamage - unit:GetMana() * 2.8
			end
		end
		if unit:GetUnitName() == "npc_dota_hero_bristleback" and not unit:IsFacingLocation(bot:GetLocation(), 120) then
			spellDamage = spellDamage * 0.7
		end
		if unit:HasModifier("modifier_kunkka_ghost_ship_damage_delay") then
			local remainingTime = Fu.GetModifierTime(unit, "modifier_kunkka_ghost_ship_damage_delay")
			if remainingTime >= delay then
				spellDamage = spellDamage * 0.55
			end
		end
		if unit:HasModifier("modifier_templar_assassin_refraction_absorb") then
			local remainingTime = Fu.GetModifierTime(unit, "modifier_templar_assassin_refraction_absorb")
			if remainingTime >= delay then
				spellDamage = 0
			end
		end
		local actualDamage = unit:GetActualIncomingDamage(spellDamage, damageType)
		return actualDamage >= unit:GetHealth()
	end
	function Fu.GetUnitListTotalAttackDamage(bot, units, duration)
		local totalDamage = 0
		for _, unit in pairs(units) do
			if Fu.IsValid(unit) then
				local attackDamage = unit:GetAttackDamage()
				local unitName = unit:GetUnitName()
				if Fu.IsSuspiciousIllusion(unit) then
					if string.find(unitName, "phantom_lancer") then
						attackDamage = attackDamage * 0.19
					elseif string.find(unitName, "naga_siren") then
						attackDamage = attackDamage * 0.4
					elseif string.find(unitName, "chaos_knight") then
					elseif string.find(unitName, "terrorblade") then
						if Fu.IsUnitNearby(bot, units, 1200, unitName, true) then
							attackDamage = attackDamage * (0.6 + 0.25)
						else
							attackDamage = attackDamage * (0.6 - 0.50)
						end
					elseif unit:HasModifier("modifier_darkseer_wallofreplica_illusion") then
						attackDamage = attackDamage * 0.9
					elseif unit:HasModifier("modifier_grimstroke_scepter_buff") then
						attackDamage = attackDamage * 1.5
					else
						if unit:GetAttackRange() > 300 then
							attackDamage = attackDamage * 0.28
						else
							attackDamage = attackDamage * 0.33
						end
					end
				end
				totalDamage = totalDamage + attackDamage * unit:GetAttackSpeed() * duration
			end
		end
		return totalDamage
	end
	local function isRealTerrorbladeNearby(unit, radius)
		for _, enemyHero in pairs(GetUnitList(UNIT_LIST_ENEMY_HEROES)) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.IsInRange(unit, enemyHero, radius)
				and enemyHero:GetUnitName() == "npc_dota_hero_terrorblade"
				and not Fu.IsSuspiciousIllusion(enemyHero)
			then
				return true
			end
		end
		return false
	end
	local function getIllusionAttackDamage(unit, duration, illusionsOnly)
		if Fu.IsValid(unit) then
			local attackDamage = unit:GetAttackDamage()
			local unitName = unit:GetUnitName()
			if illusionsOnly and Fu.IsSuspiciousIllusion(unit) then
				if string.find(unitName, "phantom_lancer") then
					attackDamage = attackDamage * 0.19
				elseif string.find(unitName, "naga_siren") then
					attackDamage = attackDamage * 0.4
				elseif string.find(unitName, "chaos_knight") then
				elseif string.find(unitName, "terrorblade") then
					if isRealTerrorbladeNearby(unit, 1200) then
						attackDamage = attackDamage * 0.6 * 1.25
					else
						attackDamage = attackDamage * 0.6 * 0.60
					end
				elseif unit:HasModifier("modifier_darkseer_wallofreplica_illusion") then
					attackDamage = attackDamage * 0.9
				elseif unit:HasModifier("modifier_grimstroke_scepter_buff") then
					attackDamage = attackDamage * 1.5
				else
					attackDamage = attackDamage * 0.33
				end
				return attackDamage * unit:GetAttackSpeed() * duration
			else
				if not illusionsOnly then
					return attackDamage * unit:GetAttackSpeed() * duration
				end
			end
		end
		return nil
	end
	function Fu.GetAttackProDelayTime(bot, creep)
		if creep == nil then
			log("[ERROR] nil creep target")
			log("Stack Trace:", debug.traceback())
			return 0
		end
		local botName = bot:GetUnitName()
		local attackRange = bot:GetAttackRange()
		local attackPoint = bot:GetAttackPoint()
		local attackSpeed = bot:GetAttackSpeed()
		local projectileSpeed = bot:GetAttackProjectileSpeed()
		local moveSpeed = bot:GetCurrentMovementSpeed()
		local attackPointTime = attackPoint / attackSpeed
		local backswingTime = bot:GetSecondsPerAttack() - attackPointTime
		local cooldownLeft = 0
		if GameTime() - bot:GetLastAttackTime() < backswingTime then
			cooldownLeft = backswingTime - (GameTime() - bot:GetLastAttackTime())
		end
		local delay = attackPointTime + cooldownLeft * 0.98
		local distance = GetUnitToUnitDistance(bot, creep)
		if
			bot:CanBeSeen()
			and bot:GetAttackTarget() == creep
			and bot:GetAnimActivity() == 1503
			and bot:GetAnimCycle() < attackPoint
		then
			delay = 0.9 * (attackPoint - bot:GetAnimCycle()) / attackSpeed
		end
		if attackRange > 320 or botName == "npc_dota_hero_templar_assassin" then
			local projectileOffset = 39
			if bot:GetPrimaryAttribute() == ATTRIBUTE_INTELLECT then
				projectileOffset = 59
			end
			local travelDistance = distance - projectileOffset
			if travelDistance < 0 then
				travelDistance = 0
			end
			if travelDistance > attackRange then
				travelDistance = attackRange - 32
			end
			delay = delay + travelDistance / projectileSpeed
			if distance > attackRange + projectileOffset / 1.2 and botName ~= "npc_dota_hero_sniper" then
				delay = delay + (distance - attackRange - projectileOffset / 1.2) / moveSpeed
			end
		end
		if attackRange < 326 and distance > attackRange + 50 and botName ~= "npc_dota_hero_templar_assassin" then
			delay = delay + (distance - attackRange - 50) / moveSpeed
		end
		return delay
	end
	function Fu.GetCreepAttackActivityWillRealDamage(unit, timeWindow)
		local bot = GetBot()
		local botLevel = bot:GetLevel()
		local now = GameTime()
		local totalDamage = 0
		local isEnemyCreeps = true
		if unit:GetTeam() ~= bot:GetTeam() then
			isEnemyCreeps = false
		end
		local nearbyLaneCreeps = bot:GetNearbyLaneCreeps(1600, isEnemyCreeps)
		for _, creep in pairs(nearbyLaneCreeps) do
			if
				creep:CanBeSeen()
				and creep:GetAttackTarget() == unit
				and creep:GetAnimActivity() == 1503
				and creep:GetLastAttackTime() < now - 0.2
			then
				local attackPoint = creep:GetAttackPoint()
				local animCycle = creep:GetAnimCycle()
				local secondsPerAttack = creep:GetSecondsPerAttack()
				if
					Fu.IsKeyWordUnit("melee", creep)
					and animCycle < attackPoint
					and (attackPoint - animCycle) * secondsPerAttack < timeWindow * (0.99 - botLevel / 300)
				then
					totalDamage = totalDamage + creep:GetAttackDamage() * 1
				end
				if Fu.IsKeyWordUnit("ranged", creep) and animCycle < attackPoint then
					local distance = GetUnitToUnitDistance(creep, unit) - 22
					local projectileSpeed = creep:GetAttackProjectileSpeed()
					local travelTime = distance / (projectileSpeed + 1)
					if
						(attackPoint - animCycle) * secondsPerAttack + travelTime
						< timeWindow * (0.98 - botLevel / 200)
					then
						totalDamage = totalDamage + creep:GetAttackDamage() * 1
					end
				end
				if Fu.IsKeyWordUnit("siege", creep) and animCycle < 0.292 then
					local distance = GetUnitToUnitDistance(creep, unit) - 28
					local projectileSpeed = creep:GetAttackProjectileSpeed()
					local travelTime = distance / (projectileSpeed + 1)
					if (0.292 - animCycle) * 0.699 / 0.292 + travelTime < timeWindow * (0.9 - botLevel / 150) then
						totalDamage = totalDamage + creep:GetAttackDamage() * 1
					end
				end
			end
		end
		return unit:GetActualIncomingDamage(totalDamage, DAMAGE_TYPE_PHYSICAL)
	end
	function Fu.GetCreepAttackProjectileWillRealDamage(unit, timeWindow)
		local totalDamage = 0
		local projectiles = unit:GetIncomingTrackingProjectiles()
		for _, projectile in pairs(projectiles) do
			if projectile.is_attack and projectile.caster ~= nil then
				local projectileSpeed = projectile.caster:GetAttackProjectileSpeed()
				if projectile.caster:IsTower() then
					projectileSpeed = projectileSpeed * 0.93
				end
				local travelReach = projectileSpeed * timeWindow * 0.95
				local distance = GetUnitToLocationDistance(unit, projectile.location)
				if travelReach > distance * 1.02 then
					totalDamage = totalDamage + projectile.caster:GetAttackDamage() * 1
				end
			end
		end
		return unit:GetActualIncomingDamage(totalDamage, DAMAGE_TYPE_PHYSICAL)
	end
	function Fu.GetTotalAttackWillRealDamage(unit, timeWindow)
		return Fu.GetCreepAttackProjectileWillRealDamage(unit, timeWindow)
			+ Fu.GetCreepAttackActivityWillRealDamage(unit, timeWindow)
	end
	function Fu.GetAttackProjectileDamageByRange(unit, radius)
		local totalDamage = 0
		local projectiles = unit:GetIncomingTrackingProjectiles()
		for _, projectile in pairs(projectiles) do
			if
				projectile.is_attack
				and projectile.caster ~= nil
				and GetUnitToLocationDistance(unit, projectile.location) < radius
			then
				totalDamage = totalDamage + projectile.caster:GetAttackDamage() * 1
			end
		end
		return totalDamage
	end
	function Fu.DotProduct(vectorA, vectorB)
		return vectorA.x * vectorB.x + vectorA.y * vectorB.y + vectorA.z * vectorB.z
	end
	local function getEffectiveHealth(health, armor)
		local damageMultiplier = 1 - 0.06 * armor / (1 + 0.06 * math.abs(armor))
		return health / damageMultiplier
	end
	local function getFightReadiness(hero)
		local readiness = 1
		local unitName = hero:GetUnitName()
		local hpScore = Fu.GetHP(hero) + hero:GetHealthRegen() * 5.0 / hero:GetMaxHealth()
		local mpScore = Fu.GetMP(hero) + hero:GetManaRegen() * 5.0 / hero:GetMaxMana()
		if unitName == "npc_dota_hero_huskar" then
			hpScore = getEffectiveHealth(hero:GetHealth(), hero:GetArmor()) / hero:GetMaxHealth()
				+ hero:GetHealthRegen() * 5.0 / hero:GetMaxHealth()
			readiness = RemapValClamped(hpScore, 0, 0.5, 0.5, 1)
		elseif unitName == "npc_dota_hero_medusa" then
			local effectiveHealth = getEffectiveHealth(hero:GetHealth() - hero:GetMana(), hero:GetArmor())
			local maxHealthPool = hero:GetMaxHealth() - hero:GetMaxMana()
			local score = RemapValClamped(effectiveHealth / maxHealthPool, 0, 1, 0, 1) * 0.2
				+ RemapValClamped(mpScore, 0, 0.75, 0, 1) * 0.8
			readiness = RemapValClamped(score, 0.5, 1, 0.5, 1)
		else
			hpScore = getEffectiveHealth(hero:GetHealth(), hero:GetArmor()) / hero:GetMaxHealth()
				+ hero:GetHealthRegen() * 5.0 / hero:GetMaxHealth()
			local score = RemapValClamped(hpScore, 0, 0.75, 0, 1) * 0.8 + RemapValClamped(mpScore, 0, 1, 0, 1) * 0.2
			readiness = RemapValClamped(score, 0.5, 1, 0.5, 1)
		end
		return readiness
	end
	-- Fast right-click carries. Lockdown has to be aimed at them even when
	-- damage cannot kill them, which is the case during Troll's Battle Trance.
	Fu.tRightclickMenace = {
		npc_dota_hero_troll_warlord = true,
		npc_dota_hero_ursa = true,
		npc_dota_hero_slark = true,
		npc_dota_hero_phantom_assassin = true,
	}
	-- Allied-creep queries also return summons such as Tidehunter's fish.
	-- Siege creeps are npc_dota_*_siege, so they stay deniable.
	function Fu.IsDeniableLaneCreep(creep)
		if not Fu.IsValid(creep) then
			return false
		end
		local sName = creep:GetUnitName()
		return string.find(sName, "npc_dota_creep_") ~= nil or string.find(sName, "_siege") ~= nil
	end
	-- Right-click carry to lock down right now, independent of the focus target.
	-- sKind: 'silence' before Battle Trance, 'hex' or 'disarm' while he swings,
	-- 'pierce' through debuff immunity (Abyssal).
	function Fu.GetRightclickMenaceLock(bot, nCastRange, sKind)
		local best, bestScore = nil, -1
		local nRange = math.min(nCastRange, 1600)
		for _, enemy in pairs(Fu.GetNearbyHeroes(bot, nRange, true, BOT_MODE_NONE)) do
			if
				Fu.IsValidHero(enemy)
				and Fu.tRightclickMenace[enemy:GetUnitName()]
				and not Fu.IsSuspiciousIllusion(enemy)
				and not enemy:IsHexed()
				and not enemy:IsStunned()
				and not enemy:IsInvulnerable()
			then
				local bTrance = enemy:HasModifier("modifier_troll_warlord_battle_trance")
				local hVictim = enemy:GetAttackTarget()
				local bHittingHero = hVictim ~= nil and hVictim:IsHero() and hVictim:GetTeam() == bot:GetTeam()
				local bEngaged = bTrance
					or bHittingHero
					or bot:WasRecentlyDamagedByHero(enemy, 2.0)
					or Fu.IsInTeamFight(bot, 1200)
				local bUsable = false
				if sKind == "silence" then
					bUsable = not bTrance and not enemy:IsSilenced() and not enemy:IsMagicImmune()
				elseif sKind == "hex" then
					bUsable = not enemy:IsMagicImmune()
				elseif sKind == "disarm" then
					bUsable = hVictim ~= nil and not enemy:IsDisarmed() and not enemy:IsMagicImmune()
				elseif sKind == "pierce" then
					bUsable = true
				end
				if bEngaged and bUsable then
					local score = (bTrance and 3 or 0)
						+ (bHittingHero and 2 or 0)
						+ (1 - GetUnitToUnitDistance(bot, enemy) / nCastRange)
					if score > bestScore then
						best, bestScore = enemy, score
					end
				end
			end
		end
		return best
	end
	function Fu.WeAreStronger(bot, radius)
		local CacheKeys = Fu.CK
		if CacheKeys then
			local cached = Fu.Utils.GetCachedVars(CacheKeys.WE_ARE_STRONGER + bot:GetPlayerID(), 0.5)
			if cached ~= nil then
				return cached
			end
		end
		local allyHeroes = {}
		local enemyHeroes = {}
		local allyPower = 0
		local allyRawPower = 0
		local enemyRawPower = 0
		local regenBuffer = bot:GetHealthRegen() * 2.0
		for _, unit in pairs(GetUnitList(UNIT_LIST_ALL)) do
			if
				Fu.IsValidHero(unit)
				and GetUnitToUnitDistance(bot, unit) <= radius
				and Fu.GetHP(unit) > 0.1
				and not unit:HasModifier("modifier_necrolyte_reapers_scythe")
				and not unit:HasModifier("modifier_dazzle_nothl_projection_physical_body_debuff")
				and not unit:HasModifier("modifier_skeleton_king_reincarnation_scepter_active")
				and not unit:HasModifier("modifier_item_helm_of_the_undying_active")
				and not unit:HasModifier("modifier_teleporting")
				and unit:GetTeam() ~= TEAM_NEUTRAL
				and unit:GetTeam() ~= TEAM_NONE
			then
				local unitName = unit:GetUnitName()
				local readiness = getFightReadiness(unit)
				local hpWeight = RemapValClamped(Fu.GetHP(unit), 0.25, 1, 0, 1)
				if GetTeam() == unit:GetTeam() then
					if not unit:HasModifier("modifier_arc_warden_tempest_double") and Fu.IsSuspiciousIllusion(unit) then
						local illusionDamage = getIllusionAttackDamage(unit, 5.0, true)
						if illusionDamage then
							allyPower = allyPower
								+ math.log(1 + unit:GetOffensivePower())
									* math.sqrt(Max(0, illusionDamage))
									* hpWeight
							allyRawPower = allyRawPower
								+ math.log(1 + unit:GetRawOffensivePower())
									* math.sqrt(Max(0, illusionDamage))
									* hpWeight
						end
					else
						if
							not Fu.IsMeepoClone(unit)
							and not string.find(unitName, "lone_druid_bear")
							and not unit:HasModifier("modifier_item_helm_of_the_undying_active")
						then
							table.insert(allyHeroes, unit)
						end
						allyPower = allyPower
							+ math.log(1 + unit:GetOffensivePower())
								* math.sqrt(unit:GetAttackDamage() * unit:GetAttackSpeed() * 5)
								* readiness
						allyRawPower = allyRawPower
							+ math.log(1 + unit:GetRawOffensivePower())
								* math.sqrt(Max(0, unit:GetAttackDamage() * unit:GetAttackSpeed() * 5))
								* readiness
					end
				else
					if not unit:HasModifier("modifier_arc_warden_tempest_double") and Fu.IsSuspiciousIllusion(unit) then
						local illusionDamage = getIllusionAttackDamage(unit, 5.0, true)
						if illusionDamage then
							enemyRawPower = enemyRawPower
								+ math.log(1 + unit:GetRawOffensivePower())
									* math.sqrt(Max(0, illusionDamage))
									* hpWeight
						end
					else
						if
							not Fu.IsMeepoClone(unit)
							and not string.find(unitName, "lone_druid_bear")
							and not unit:HasModifier("modifier_item_helm_of_the_undying_active")
						then
							table.insert(enemyHeroes, unit)
						end
						enemyRawPower = enemyRawPower
							+ math.log(1 + unit:GetRawOffensivePower())
								* math.sqrt(Max(0, unit:GetAttackDamage() * unit:GetAttackSpeed() * 5))
								* readiness
					end
				end
			end
		end
		local allyTowers = bot:GetNearbyTowers(600, false)
		if Fu.IsValidBuilding(allyTowers[1]) then
			if allyTowers[1]:HasModifier("modifier_fountain_glyph") then
				local towerPower = #allyTowers
					* math.sqrt(Max(0, allyTowers[1]:GetAttackDamage() * allyTowers[1]:GetAttackSpeed() * 5.0 * 2))
				allyPower = allyPower + towerPower
				allyRawPower = allyRawPower + towerPower
			else
				local towerPower = #allyTowers
					* math.sqrt(Max(0, allyTowers[1]:GetAttackDamage() * allyTowers[1]:GetAttackSpeed() * 5.0))
				allyPower = allyPower + towerPower
				allyRawPower = allyRawPower + towerPower
			end
		end
		-- Enemy towers count against us the same way ours count for us.
		local enemyTowers = bot:GetNearbyTowers(600, true)
		if Fu.IsValidBuilding(enemyTowers[1]) then
			local glyphMultiplier = enemyTowers[1]:HasModifier("modifier_fountain_glyph") and 2 or 1
			enemyRawPower = enemyRawPower
				+ #enemyTowers
					* math.sqrt(
						Max(
							0,
							enemyTowers[1]:GetAttackDamage() * enemyTowers[1]:GetAttackSpeed() * 5.0 * glyphMultiplier
						)
					)
		end
		if not Fu.IsEarlyGame() and Fu.IsInTeamFight(bot, 1600) and #allyHeroes >= #enemyHeroes then
			local teamFightLocation = Fu.GetTeamFightLocation(bot)
			if
				teamFightLocation ~= nil and (Fu.IsHumanInLoc(teamFightLocation, 1200) or #allyHeroes > #enemyHeroes)
			then
				allyPower = allyPower * 1.20
				allyRawPower = allyRawPower * 1.20
			end
		end
		local result = allyRawPower > enemyRawPower
		if CacheKeys then
			Fu.Utils.SetCachedVars(CacheKeys.WE_ARE_STRONGER + bot:GetPlayerID(), result)
		end
		return result
	end
	function Fu.GetArmorReducers(hero)
		local armorReduction = 0
		if
			Fu.HasItem(hero, "item_desolator")
			and (
				hero:GetItemInSlot(6) ~= "item_desolator"
				or hero:GetItemInSlot(7) ~= "item_desolator"
				or hero:GetItemInSlot(8) ~= "item_desolator"
			)
		then
			armorReduction = armorReduction + 6
		end
		if
			Fu.HasItem(hero, "item_assault")
			and (
				hero:GetItemInSlot(6) ~= "item_assault"
				or hero:GetItemInSlot(7) ~= "item_assault"
				or hero:GetItemInSlot(8) ~= "item_assault"
			)
		then
			armorReduction = armorReduction + 5
		end
		if
			Fu.HasItem(hero, "item_blight_stone")
			and (
				hero:GetItemInSlot(6) ~= "item_blight_stone"
				or hero:GetItemInSlot(7) ~= "item_blight_stone"
				or hero:GetItemInSlot(8) ~= "item_blight_stone"
			)
		then
			armorReduction = armorReduction + 2
		end
		local darkLordAbility = hero:GetAbilityByName("nevermore_dark_lord")
		if
			hero:GetUnitName() == "npc_dota_hero_nevermore"
			and darkLordAbility ~= nil
			and darkLordAbility:GetLevel() > 0
		then
			armorReduction = armorReduction + darkLordAbility:GetSpecialValueInt("presence_armor_reduction")
		end
		local ripTideAbility = hero:GetAbilityByName("naga_siren_rip_tide")
		if
			hero:GetUnitName() == "npc_dota_hero_naga_siren"
			and ripTideAbility ~= nil
			and ripTideAbility:GetLevel() > 0
		then
			armorReduction = armorReduction + ripTideAbility:GetSpecialValueInt("armor_reduction")
		end
		return armorReduction
	end
	function Fu.HasEnoughDPSForRoshan(heroes)
		local totalDps = 0
		local requiredDps = 0
		local killTime = 60
		local roshanBaseHealth = 6000
		local roshanBaseArmor = 30
		local roshanArmorPerMinute = 0.375
		local roshanHealthPerMinute = 130 * 2
		local roshanHealth = roshanBaseHealth + roshanHealthPerMinute * math.floor(DotaTime() / 60)
		for _, hero in pairs(heroes) do
			local roshanArmor = roshanBaseArmor
				+ roshanArmorPerMinute * math.floor(DotaTime() / 60)
				- Fu.GetArmorReducers(hero)
			local attackDamage = hero:GetAttackDamage()
			local attackSpeed = hero:GetAttackSpeed()
			local dps = attackDamage * attackSpeed * (1 - roshanArmor / (roshanArmor + 20))
			totalDps = totalDps + dps
		end
		requiredDps = roshanHealth / killTime
		return totalDps >= requiredDps
	end
	function Fu.GetTotalEstimatedDamageToTarget(units, target)
		local totalDamage = 0
		for _, unit in pairs(units) do
			if Fu.IsValid(unit) and Fu.IsValid(target) and not Fu.IsSuspiciousIllusion(unit) then
				totalDamage = totalDamage + unit:GetEstimatedDamageToTarget(true, target, 5, DAMAGE_TYPE_ALL)
			end
		end
		return totalDamage
	end
	function Fu.IsAllyCanKill(target)
		if target:GetHealth() / target:GetMaxHealth() > 0.38 then
			return false
		end
		local totalDamage = 0
		local damageType = DAMAGE_TYPE_PHYSICAL
		local teamPlayers = GetTeamPlayers(GetTeam())
		for i = 1, #teamPlayers do
			local member = GetTeamMember(i)
			if
				member ~= nil
				and member:IsAlive()
				and member:CanBeSeen()
				and member:GetAttackTarget() == target
				and GetUnitToUnitDistance(member, target) <= member:GetAttackRange() + 50
			then
				totalDamage = totalDamage + member:GetAttackDamage()
			end
		end
		totalDamage = totalDamage * 2.44 + Fu.GetAttackProjectileDamageByRange(target, 1200)
		if Fu.CanKillTarget(target, totalDamage, damageType) then
			return true
		end
		return false
	end
	function Fu.IsEnemyTeleporting(enemyHero)
		if not Fu.IsValidHero(enemyHero) then
			return false
		end
		return enemyHero:HasModifier("modifier_teleporting")
	end
	function Fu.GetTPTarget(bot, radius)
		local nearbyEnemies = bot:GetNearbyHeroes(radius, true, BOT_MODE_NONE) or {}
		for _, enemyHero in pairs(nearbyEnemies) do
			if Fu.IsValidHero(enemyHero) and Fu.IsEnemyTeleporting(enemyHero) and Fu.CanBeAttacked(enemyHero) then
				return enemyHero
			end
		end
		return nil
	end
	function Fu.IsEnemyHealing(enemyHero)
		if not Fu.IsValidHero(enemyHero) then
			return false
		end
		return enemyHero:HasModifier("modifier_flask_healing")
			or enemyHero:HasModifier("modifier_clarity_potion")
			or enemyHero:HasModifier("modifier_bottle_regeneration")
			or enemyHero:HasModifier("modifier_tango_heal")
	end
	function Fu.GetHealingTarget(bot, radius)
		local nearbyEnemies = bot:GetNearbyHeroes(radius, true, BOT_MODE_NONE) or {}
		for _, enemyHero in pairs(nearbyEnemies) do
			if Fu.IsValidHero(enemyHero) and Fu.IsEnemyHealing(enemyHero) and Fu.CanBeAttacked(enemyHero) then
				return enemyHero
			end
		end
		return nil
	end
	function Fu.IsSafeToUseUltimate(bot, location, radius)
		radius = radius or 1200
		local alliesNearLocation = Fu.GetAlliesNearLoc(location, radius)
		local enemiesNearLocation = Fu.GetEnemiesNearLoc(location, radius)
		return #alliesNearLocation >= #enemiesNearLocation
	end
	function Fu.IsLocationDangerous(location)
		local dangerModifiers = {
			"modifier_faceless_void_chronosphere_freeze",
			"modifier_enigma_black_hole_pull",
			"modifier_dark_willow_bramble_maze",
		}
		for _, enemyUnit in pairs(GetUnitList(UNIT_LIST_ENEMIES)) do
			if enemyUnit and not enemyUnit:IsNull() and enemyUnit:IsAlive() then
				for _, modifierName in pairs(dangerModifiers) do
					if enemyUnit:HasModifier(modifierName) and GetUnitToLocationDistance(enemyUnit, location) < 600 then
						return true
					end
				end
			end
		end
		return false
	end
end
return installCombat
