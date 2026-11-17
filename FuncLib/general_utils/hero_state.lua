-- Shared helper: hero state.
local function installHeroState(Fu)
	function Fu.HasQueuedAction(bot)
		if bot ~= GetBot() then
			return false
		end
		return bot:NumQueuedActions() > 0
	end
	function Fu.IsTryingtoUseAbility(unit)
		if not Fu.IsUnitValid(unit) then
			return false
		end
		return unit:IsCastingAbility() or unit:IsUsingAbility() or unit:IsChanneling()
	end
	function Fu.CanNotUseAction(unit)
		if not Fu.IsUnitValid(unit) then
			return false
		end
		return not unit:IsAlive()
			or Fu.HasQueuedAction(unit)
			or unit:IsInvulnerable() and not unit:HasModifier("modifier_fountain_invulnerability") and not unit:HasModifier(
				"modifier_dazzle_nothl_projection_soul_debuff"
			)
			or unit:IsCastingAbility()
			or unit:IsUsingAbility()
			or unit:IsChanneling()
			or unit:IsStunned() and not unit:HasModifier("modifier_dazzle_nothl_projection_soul_debuff")
			or unit:IsNightmared()
			or unit:HasModifier("modifier_ringmaster_the_box_buff")
			or unit:HasModifier("modifier_item_forcestaff_active")
			or unit:HasModifier("modifier_phantom_lancer_phantom_edge_boost")
			or unit:HasModifier("modifier_tinker_rearm")
	end
	function Fu.CanNotUseAbility(unit)
		if not Fu.IsUnitValid(unit) then
			return false
		end
		return not unit:IsAlive()
			or Fu.HasQueuedAction(unit)
			or unit:IsInvulnerable() and not unit:HasModifier("modifier_fountain_invulnerability") and not unit:HasModifier(
				"modifier_dazzle_nothl_projection_soul_debuff"
			)
			or unit:IsCastingAbility()
			or unit:IsUsingAbility()
			or unit:IsChanneling()
			or unit:IsSilenced()
			or unit:IsStunned() and not unit:HasModifier("modifier_dazzle_nothl_projection_soul_debuff")
			or unit:IsHexed()
			or unit:IsNightmared()
			or unit:HasModifier("modifier_ringmaster_the_box_buff")
			or unit:HasModifier("modifier_doom_bringer_doom")
			or unit:HasModifier("modifier_item_forcestaff_active")
	end
	local damageOverTimeModifiers = {
		"modifier_viper_corrosive_skin_slow",
		"modifier_viper_poison_attack_slow",
		"modifier_venomancer_poison_sting_debuff",
		"modifier_venomancer_venomous_gale",
		"modifier_huskar_burning_spear_debuff",
		"modifier_doom_bringer_scorched_earth_effect_enemy",
		"modifier_jakiro_liquid_fire_burn",
		"modifier_pudge_rot",
		"modifier_queenofpain_shadow_strike",
		"modifier_ancient_apparition_ice_blast",
		"modifier_item_radiance_debuff",
		"modifier_item_urn_damage",
		"modifier_item_spirit_vessel_damage",
		"modifier_ogre_magi_ignite",
		"modifier_batrider_napalm",
	}
	function Fu.HasDamageOverTimeDebuff(unit)
		if not Fu.IsUnitValid(unit) then
			return false
		end
		for _, modifierName in pairs(damageOverTimeModifiers) do
			if unit:HasModifier(modifierName) then
				return true
			end
		end
		return false
	end
	local towerAggroCooldowns = {}
	local denyCooldowns = {}
	local function IsOnCooldown(cooldowns, bot, duration)
		local playerId = bot:GetPlayerID()
		if cooldowns[playerId] and DotaTime() < cooldowns[playerId] then
			return true
		end
		return false
	end
	local function StartCooldown(cooldowns, bot, duration)
		cooldowns[bot:GetPlayerID()] = DotaTime() + duration
	end
	function Fu.TryDropTowerAggro(bot)
		if IsOnCooldown(towerAggroCooldowns, bot, 0) then
			return false
		end
		local nearbyTowers = bot:GetNearbyTowers(900, true)
		if nearbyTowers == nil or #nearbyTowers == 0 then
			return false
		end
		for _, tower in pairs(nearbyTowers) do
			if Fu.IsValidBuilding(tower) and tower:GetAttackTarget() == bot then
				-- Only a creep already in attack range: walking up to one kept the hero under the
				-- tower longer. (It also right-clicked allied heroes; gone.)
				local nearbyAllyCreeps = bot:GetNearbyLaneCreeps(bot:GetAttackRange() + 250, false)
				for _, creep in pairs(nearbyAllyCreeps) do
					if
						Fu.IsValid(creep)
						and GetUnitToUnitDistance(creep, tower) <= (tower:GetAttackRange() or 700)
						and GetUnitToUnitDistance(bot, creep) <= bot:GetAttackRange() + 50
					then
						bot:Action_AttackUnit(creep, true)
						StartCooldown(towerAggroCooldowns, bot, 1.5)
						return true
					end
				end
				local retreatLocation = Fu.AdjustLocationWithOffsetTowardsFountain(bot:GetLocation(), 500)
				bot:Action_MoveToLocation(retreatLocation)
				StartCooldown(towerAggroCooldowns, bot, 1.5)
				return true
			end
		end
		return false
	end
	function Fu.TryDenyTower(bot)
		if IsOnCooldown(denyCooldowns, bot, 0) then
			return false
		end
		local nearbyTowers = bot:GetNearbyTowers(700, false)
		if nearbyTowers == nil then
			return false
		end
		local team = GetTeam()
		for _, tower in pairs(nearbyTowers) do
			if
				Fu.IsValidBuilding(tower)
				and Fu.CanBeAttacked(tower)
				and tower ~= GetTower(team, TOWER_TOP_3)
				and tower ~= GetTower(team, TOWER_MID_3)
				and tower ~= GetTower(team, TOWER_BOT_3)
				and tower ~= GetTower(team, TOWER_BASE_1)
				and tower ~= GetTower(team, TOWER_BASE_2)
				and not tower:HasModifier("modifier_backdoor_protection")
				and not tower:HasModifier("modifier_backdoor_protection_in_base")
				and tower:GetHealth() < tower:GetMaxHealth() * 0.07
			then
				bot:Action_AttackUnit(tower, false)
				return true
			end
		end
		return false
	end
	function Fu.TryDenyAllyHero(bot)
		if IsOnCooldown(denyCooldowns, bot, 0) then
			return false
		end
		local nearbyAllies = bot:GetNearbyHeroes(700, false, BOT_MODE_NONE)
		if nearbyAllies == nil then
			return false
		end
		for _, ally in pairs(nearbyAllies) do
			if
				Fu.IsValidHero(ally)
				and ally ~= bot
				and Fu.CanBeAttacked(ally)
				and Fu.GetHP(ally) < 0.05
				and (
					ally:HasModifier("modifier_doom_bringer_doom")
					or ally:HasModifier("modifier_queenofpain_shadow_strike")
					or ally:HasModifier("modifier_venomancer_venomous_gale")
					or ally:HasModifier("modifier_venomancer_poison_sting_debuff")
				)
			then
				bot:Action_AttackUnit(ally, false)
				StartCooldown(denyCooldowns, bot, 2.0)
				return true
			end
		end
		return false
	end
	local undyingModifiers = {
		"modifier_abaddon_borrowed_time",
		"modifier_dazzle_shallow_grave",
		"modifier_wind_waker",
		"modifier_item_wind_waker",
		"modifier_oracle_false_promise_timer",
		"modifier_item_aeon_disk_buff",
	}
	local modifierTime = 0
	function Fu.HasMovableUndyingModifier(unit, minDuration)
		if not Fu.IsUnitValid(unit) then
			return false
		end
		for _, modifierName in pairs(undyingModifiers) do
			if unit:HasModifier(modifierName) then
				modifierTime = Fu.GetModifierTime(unit, modifierName)
				if modifierTime > 0 then
					if modifierTime > minDuration then
						return true
					end
					return false
				end
			end
		end
		return false
	end
	function Fu.IsWithoutTarget(unit)
		if not Fu.IsUnitValid(unit) then
			return false
		end
		return unit:CanBeSeen()
			and unit:GetAttackTarget() == nil
			and (unit:GetTeam() == GetBot():GetTeam() and unit:GetTarget() == nil)
	end
	function Fu.IsUnderLongDurationStun(unit)
		if not Fu.IsUnitValid(unit) then
			return false
		end
		return unit:HasModifier("modifier_bane_fiends_grip")
			or unit:HasModifier("modifier_legion_commander_duel")
			or unit:HasModifier("modifier_enigma_black_hole_pull")
			or unit:HasModifier("modifier_faceless_void_chronosphere_freeze")
			or unit:HasModifier("modifier_magnataur_reverse_polarity")
			or unit:HasModifier("modifier_tidehunter_ravage")
			or unit:HasModifier("modifier_winter_wyvern_winters_curse_aura")
	end
	function Fu.IsInEtherealForm(unit)
		if not Fu.IsUnitValid(unit) then
			return false
		end
		return unit:HasModifier("modifier_ghost_state")
			or unit:HasModifier("modifier_item_ethereal_blade_ethereal")
			or unit:HasModifier("modifier_necrolyte_death_seeker")
			or unit:HasModifier("modifier_necrolyte_sadist_active")
			or unit:HasModifier("modifier_pugna_decrepify")
	end
	function Fu.HasForbiddenModifier(unit)
		if not Fu.IsUnitValid(unit) then
			return false
		end
		for _, modifierName in pairs(Fu.Buff["enemy_is_immune"]) do
			if unit:HasModifier(modifierName) then
				return true
			end
		end
		if unit:IsHero() then
			local nearbyAllies = Fu.GetNearbyHeroes(unit, 800, false, BOT_MODE_NONE)
			if nearbyAllies ~= nil and #nearbyAllies >= 2 then
				for _, modifierName in pairs(Fu.Buff["enemy_is_undead"]) do
					if unit:HasModifier(modifierName) then
						return true
					end
				end
			end
			if not unit:IsBot() then
				local playerId = unit:GetPlayerID()
				local kills = GetHeroKills(playerId)
				local deaths = GetHeroDeaths(playerId)
				if deaths >= 6 and kills <= 6 and kills / deaths <= 0.3 then
					return true
				end
			end
		else
			if unit:HasModifier("modifier_crystal_maiden_frostbite") or unit:HasModifier("modifier_fountain_glyph") then
				return true
			end
		end
		return false
	end
	function Fu.ShouldEscape(bot)
		if not Fu.IsUnitValid(bot) then
			return false
		end
		local attackingAllies = Fu.GetNearbyHeroes(bot, 800, false, BOT_MODE_ATTACK)
		if #attackingAllies > 0 and Fu.GetHP(bot) > 0.16 then
			return false
		end
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, 1000, true, BOT_MODE_NONE)
		if bot:WasRecentlyDamagedByAnyHero(2.0) or bot:WasRecentlyDamagedByTower(2.0) or #nearbyEnemies >= 2 then
			return true
		end
		return false
	end
	function Fu.IsDisabled(unit)
		if not Fu.IsUnitValid(unit) then
			return false
		end
		if unit:GetTeam() ~= GetTeam() and unit:CanBeSeen() then
			return unit:IsRooted() or unit:IsStunned() or unit:IsHexed() or unit:IsNightmared() or Fu.IsTaunted(unit)
		else
			if unit:IsStunned() and Fu.GetRemainStunTime(unit) > 0.8 then
				return true
			end
			if
				unit:IsSilenced()
				and not unit:HasModifier("modifier_item_mask_of_madness_berserk")
				and Fu.IsWithoutTarget(unit)
			then
				return true
			end
			return unit:IsRooted() or unit:IsHexed() or unit:IsNightmared() or Fu.IsTaunted(unit)
		end
	end
	function Fu.IsTaunted(unit)
		if not Fu.IsUnitValid(unit) then
			return false
		end
		if not unit:CanBeSeen() then
			return false
		end
		return unit:HasModifier("modifier_axe_berserkers_call")
			or unit:HasModifier("modifier_legion_commander_duel")
			or unit:HasModifier("modifier_winter_wyvern_winters_curse")
			or unit:HasModifier("modifier_winter_wyvern_winters_curse_aura")
	end
	function Fu.IsMoving(unit)
		if not Fu.IsUnitValid(unit) then
			return false
		end
		if not unit:IsAlive() then
			return false
		end
		local futureLocation = unit:GetExtrapolatedLocation(0.6)
		if GetUnitToLocationDistance(unit, futureLocation) > unit:GetCurrentMovementSpeed() * 0.45 then
			return true
		end
		return false
	end
	function Fu.IsRunning(unit)
		if not Fu.IsUnitValid(unit) then
			return false
		end
		if not unit:IsAlive() then
			return false
		end
		return unit:GetAnimActivity() == ACTIVITY_RUN
	end
	function Fu.IsAttacking(unit)
		if not Fu.IsUnitValid(unit) then
			return false
		end
		local activity = unit:GetAnimActivity()
		if activity ~= ACTIVITY_ATTACK and activity ~= ACTIVITY_ATTACK2 then
			return false
		end
		if unit:GetAttackPoint() > unit:GetAnimCycle() * 0.99 then
			return true
		end
		return false
	end
	function Fu.IsChasingTarget(unit, target)
		if not Fu.IsUnitValid(unit) then
			return false
		end
		if
			Fu.IsRunning(unit)
			and Fu.IsRunning(target)
			and unit:IsFacingLocation(target:GetLocation(), 20)
			and not target:IsFacingLocation(unit:GetLocation(), 150)
		then
			return true
		end
		return false
	end
	function Fu.IsRealInvisible(unit)
		if not Fu.IsUnitValid(unit) then
			return false
		end
		local nearbyEnemyTowers = unit:GetNearbyTowers(880, true)
		if
			unit:IsInvisible()
			and not unit:HasModifier("modifier_item_dustofappearance")
			and not unit:HasModifier("modifier_bloodseeker_thirst_vision")
			and not unit:HasModifier("modifier_slardar_amplify_damage")
			and not unit:HasModifier("modifier_sniper_assassinate")
			and not unit:HasModifier("modifier_bounty_hunter_track")
			and not unit:HasModifier("modifier_faceless_void_chronosphere_freeze")
			and #nearbyEnemyTowers == 0
		then
			return true
		end
		return false
	end
	function Fu.GetModifierTime(unit, modifierName)
		if not Fu.IsUnitValid(unit) then
			return 0
		end
		if not unit:HasModifier(modifierName) then
			return 0
		end
		local modifierCount = unit:NumModifiers()
		for i = 0, modifierCount do
			if unit:GetModifierName(i) == modifierName then
				return unit:GetModifierRemainingDuration(i)
			end
		end
		return 0
	end
	function Fu.GetModifierCount(unit, modifierName)
		if not Fu.IsUnitValid(unit) then
			return 0
		end
		if not unit:HasModifier(modifierName) then
			return 0
		end
		local modifierCount = unit:NumModifiers()
		for i = 0, modifierCount do
			if unit:GetModifierName(i) == modifierName then
				return unit:GetModifierStackCount(i)
			end
		end
		return 0
	end
	function Fu.GetUniqueModifierCount(unit, modifierName)
		if not Fu.IsUnitValid(unit) then
			return 0
		end
		if not unit:HasModifier(modifierName) then
			return 0
		end
		local count = 0
		local modifierCount = unit:NumModifiers()
		for i = 0, modifierCount do
			if unit:GetModifierName(i) == modifierName then
				count = count + 1
			end
		end
		return count
	end
	function Fu.GetRemainStunTime(unit)
		if not Fu.IsUnitValid(unit) then
			return 0
		end
		if not unit:HasModifier("modifier_stunned") then
			return 0
		end
		local modifierCount = unit:NumModifiers()
		for i = 0, modifierCount do
			if unit:GetModifierName(i) == "modifier_stunned" then
				return unit:GetModifierRemainingDuration(i)
			end
		end
		return 0
	end
	function Fu.CannotBeKilled(attacker, target)
		if not Fu.IsUnitValid(attacker) then
			return false
		end
		return Fu.IsValidHero(target)
			and (
				Fu.GetModifierTime(target, "modifier_dazzle_shallow_grave") > 0.6
					and Fu.GetHP(target) < 0.15
					and (attacker == nil or attacker:GetUnitName() ~= "npc_dota_hero_axe")
				or Fu.GetModifierTime(target, "modifier_oracle_false_promise_timer") > 0.6
				or target:HasModifier("modifier_skeleton_king_reincarnation_scepter_active")
				or target:HasModifier("modifier_item_helm_of_the_undying_active")
				or target:HasModifier("modifier_item_aeon_disk_buff")
				or target:HasModifier("modifier_abaddon_borrowed_time")
			)
	end
	function Fu.CanIgnoreLowHp(unit)
		if not Fu.IsUnitValid(unit) then
			return false
		end
		return Fu.GetModifierTime(unit, "modifier_dazzle_shallow_grave") > 0.6
			or Fu.GetModifierTime(unit, "modifier_oracle_false_promise_timer") > 0.6
	end
	function Fu.DoesSomeoneHaveModifier(units, modifierName)
		-- Was `not Fu.IsUnitValid(units)`: a list is not a unit, so this always returned false.
		if units == nil then
			return false
		end
		for _, unit in pairs(units) do
			if Fu.IsValid(unit) and unit:HasModifier(modifierName) then
				return true
			end
		end
		return false
	end
	function Fu.DoesUnitHaveTemporaryBuff(unit)
		if not Fu.IsUnitValid(unit) then
			return false
		end
		local unitName = unit:GetUnitName()
		if unitName == "npc_dota_hero_huskar" and Fu.GetHP(unit) < 0.6 then
			return true
		end
		for i = 0, unit:NumModifiers() do
			local remainingDuration = unit:GetModifierRemainingDuration(i)
			if remainingDuration > 0.5 or remainingDuration > -1 and remainingDuration < 0.5 then
				return true
			end
		end
		return false
	end
	function Fu.IsUnitWillGoInvisible(unit)
		if not Fu.IsUnitValid(unit) then
			return false
		end
		return unit:HasModifier("modifier_sandking_sand_storm")
			or unit:HasModifier("modifier_bounty_hunter_wind_walk")
			or unit:HasModifier("modifier_clinkz_wind_walk")
			or unit:HasModifier("modifier_weaver_shukuchi")
			or unit:HasModifier("modifier_oracle_false_promise") and unit:HasModifier(
				"modifier_oracle_false_promise_invis"
			)
			or unit:HasModifier("modifier_windrunner_windrun") and unit:HasModifier("modifier_windrunner_windrun_invis")
			or unit:HasModifier("modifier_item_invisibility_edge")
			or unit:HasModifier("modifier_item_invisibility_edge_windwalk")
			or unit:HasModifier("modifier_item_silver_edge")
			or unit:HasModifier("modifier_item_silver_edge_windwalk")
			-- Moonlight Shadow (game files: modifier_mirana_moonlight_shadow; datafeed: 2.5/2/1.5s fade,
			-- on Mirana and every allied hero). Game 032, 11:00: not listed, so no Dust came.
			or unit:HasModifier("modifier_mirana_moonlight_shadow")
			or unit:HasModifier("modifier_item_glimmer_cape_fade")
			or unit:HasModifier("modifier_item_glimmer_cape")
			or unit:HasModifier("modifier_item_shadow_amulet")
			or unit:HasModifier("modifier_item_shadow_amulet_fade")
			or unit:HasModifier("modifier_item_trickster_cloak_invis")
	end
	function Fu.HasInvisCounterBuff(unit)
		if not Fu.IsUnitValid(unit) then
			return false
		end
		if
			unit:HasModifier("modifier_item_dustofappearance")
			or unit:HasModifier("modifier_bounty_hunter_track")
			or unit:HasModifier("modifier_bloodseeker_thirst_vision")
			or unit:HasModifier("modifier_slardar_amplify_damage")
			or unit:HasModifier("modifier_sniper_assassinate")
			or unit:HasModifier("modifier_faceless_void_chronosphere_freeze")
		then
			return true
		end
		return false
	end
end
return installHeroState
