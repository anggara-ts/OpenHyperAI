-- Thinking for summoned units: utils.
local X = {}
local enemyAncient = GetAncient(GetOpposingTeam())
function X.IsValidUnit(unit)
	return unit ~= nil and not unit:IsNull() and unit:IsAlive() and unit:CanBeSeen()
end
function X.IsValidTarget(unit)
	return X.IsValidUnit(unit) and not unit:IsInvulnerable() and not unit:IsAttackImmune()
end
function X.IsBusy(unit)
	return X.IsValidUnit(unit) and (unit:IsUsingAbility() or unit:IsCastingAbility() or unit:IsChanneling())
end
function X.CantMove(unit)
	return X.IsValidUnit(unit)
		and (
			unit:IsStunned()
			or unit:IsRooted()
			or unit:IsNightmared()
			or unit:IsInvulnerable() and not unit:HasModifier("modifier_fountain_invulnerability")
			or not unit:GetCurrentMovementSpeed()
			or unit:GetCurrentMovementSpeed() < 100
		)
end
function X.CanNotUseAbility(unit)
	return not X.IsValidUnit(unit)
		or unit:IsInvulnerable()
		or unit:IsCastingAbility()
		or unit:IsUsingAbility()
		or unit:IsChanneling()
		or unit:IsSilenced()
		or unit:IsStunned()
		or unit:IsHexed()
		or unit:IsNightmared()
		or unit:HasModifier("modifier_ringmaster_the_box_buff")
		or unit:HasModifier("modifier_doom_bringer_doom")
		or unit:HasModifier("modifier_item_forcestaff_active")
end
function X.CantAttack(unit)
	return X.IsValidUnit(unit)
		and (
			unit:IsStunned()
			or unit:IsRooted()
			or unit:IsNightmared()
			or unit:IsDisarmed()
			or unit:IsInvulnerable()
			or unit:GetAttackDamage() <= 0
		)
end
function X.GetWeakestHero(radius, sourceUnit)
	if X.IsValidUnit(sourceUnit) then
		local nearbyHeroes = sourceUnit:GetNearbyHeroes(radius * 0.5, true, BOT_MODE_NONE) or {}
		if #nearbyHeroes == 0 then
			nearbyHeroes = sourceUnit:GetNearbyHeroes(radius, true, BOT_MODE_NONE) or {}
		end
		return X.GetWeakest(nearbyHeroes)
	end
	return nil
end
function X.GetWeakestCreep(radius, sourceUnit)
	if X.IsValidUnit(sourceUnit) then
		local nearbyCreeps = sourceUnit:GetNearbyCreeps(radius * 0.5, true) or {}
		if #nearbyCreeps == 0 then
			nearbyCreeps = sourceUnit:GetNearbyCreeps(radius, true) or {}
		end
		return X.GetWeakest(nearbyCreeps)
	end
	return nil
end
function X.GetWeakestTower(radius, sourceUnit)
	if not X.IsValidUnit(sourceUnit) then
		return nil
	end
	-- GetNearbyTowers is stubbed to nil for non-heroes (serpent wards, etc.).
	-- Scan enemy buildings directly so wards can hit towers when no hero/creep is better.
	local buildings = {}
	for _, unit in pairs(GetUnitList(UNIT_LIST_ENEMY_BUILDINGS) or {}) do
		if
			X.IsValidTarget(unit)
			and GetUnitToUnitDistance(sourceUnit, unit) <= radius
			and not X.IsNotAllowedToAttack(unit)
			and (unit:IsTower() or unit:IsBuilding())
		then
			local name = unit:GetUnitName() or ""
			-- Skip outposts / twin gates (not attack objectives for wards).
			if name ~= "npc_dota_watch_tower" and not string.find(name, "twin_gate") then
				buildings[#buildings + 1] = unit
			end
		end
	end
	local weakest = X.GetWeakest(buildings)
	if weakest ~= nil then
		return weakest
	end
	if X.IsValidTarget(enemyAncient) and GetUnitToUnitDistance(sourceUnit, enemyAncient) <= radius then
		return enemyAncient
	end
	return nil
end
function X.GetWeakest(units)
	local weakestUnit = nil
	local lowestHitsToKill = 10000
	if #units > 0 then
		for i = 1, #units do
			local unit = units[i]
			if X.IsValidTarget(unit) and not X.IsNotAllowedToAttack(unit) then
				local hitsToKill = unit:GetHealth() / unit:GetActualIncomingDamage(3000, DAMAGE_TYPE_PHYSICAL)
				if hitsToKill < lowestHitsToKill then
					weakestUnit = unit
					lowestHitsToKill = hitsToKill
				end
			end
		end
	end
	return weakestUnit
end
function X.IsNotAllowedToAttack(unit)
	local unitName = unit:GetUnitName() or ""
	return unitName == "#DOTA_OutpostName_North"
		or unitName == "#DOTA_OutpostName_South"
		or unitName == "npc_dota_watch_tower"
		or unitName == "npc_dota_unit_twin_gate"
		or string.find(unitName, "twin_gate") ~= nil
end
function X.IsTargetedByHero(unit)
	for _, enemy in pairs(GetUnitList(UNIT_LIST_ENEMY_HEROES)) do
		if
			X.IsValidUnit(enemy)
			and enemy:IsHero()
			and GetUnitToUnitDistance(unit, enemy) <= enemy:GetAttackRange() + 300
			and enemy:GetAttackTarget() == unit
		then
			return true
		end
	end
	return false
end
function X.IsTargetedByTower(unit)
	for _, enemy in pairs(GetUnitList(UNIT_LIST_ENEMY_BUILDINGS)) do
		if
			X.IsValidUnit(enemy)
			and enemy:IsTower()
			and GetUnitToUnitDistance(unit, enemy) <= enemy:GetAttackRange() + 300
			and enemy:GetAttackTarget() == unit
		then
			return true
		end
	end
	return false
end
function X.IsTargetedByCreep(unit)
	for _, enemy in pairs(GetUnitList(UNIT_LIST_ENEMY_CREEPS)) do
		if
			X.IsValidUnit(enemy)
			and enemy:IsCreep()
			and GetUnitToUnitDistance(unit, enemy) <= enemy:GetAttackRange() + 300
			and enemy:GetAttackTarget() == unit
		then
			return true
		end
	end
	for _, enemy in pairs(GetUnitList(UNIT_LIST_NEUTRAL_CREEPS)) do
		if
			X.IsValidUnit(enemy)
			and enemy:IsCreep()
			and GetUnitToUnitDistance(unit, enemy) <= enemy:GetAttackRange() + 300
			and enemy:GetAttackTarget() == unit
		then
			return true
		end
	end
	return false
end
function X.IsShamanFowlPlayChicken(unit)
	if unit:GetUnitName() == "npc_dota_hero_shadow_shaman" and unit:IsIllusion() and unit:IsHexed() then
		return true
	end
	return false
end
function X.InitiateAbility(unit)
	if unit ~= nil and not unit:IsNull() then
		unit.abilities = {}
		for i = 0, 23 do
			local ability = unit:GetAbilityInSlot(i)
			if ability and not ability:IsHidden() and not ability:IsPassive() then
				unit.abilities[i + 1] = ability
			end
		end
	end
end
function X.IsAttackingWard(unit)
	local unitName = unit:GetUnitName()
	return string.find(unitName, "npc_dota_shadow_shaman_ward")
		or string.find(unitName, "npc_dota_venomancer_plague_ward")
		or string.find(unitName, "npc_dota_witch_doctor_death_ward")
end
function X.CantBeControlled(unit)
	local unitName = unit:GetUnitName()
	return unitName == "npc_dota_zeus_cloud"
		or string.find(unitName, "npc_dota_unit_tombstone")
		or string.find(unitName, "npc_dota_pugna_nether_ward")
		or string.find(unitName, "npc_dota_techies")
		or unitName == "npc_dota_rattletrap_cog"
		or unitName == "npc_dota_rattletrap_rocket"
		or unitName == "npc_dota_broodmother_web"
		or unitName == "npc_dota_unit_undying_zombie"
		or unitName == "npc_dota_unit_undying_zombie_torso"
		or unitName == "npc_dota_weaver_swarm"
		or unitName == "npc_dota_death_prophet_torment"
		or unitName == "npc_dota_gyrocopter_homing_missile"
		or unitName == "npc_dota_plasma_field"
		or unitName == "npc_dota_wisp_spirit"
		or unitName == "npc_dota_beastmaster_axe"
		or unitName == "npc_dota_troll_warlord_axe"
		or unitName == "npc_dota_phoenix_sun"
		or unitName == "npc_dota_treant_eyes"
		or unitName == "npc_dota_clinkz_skeleton_archer"
		or unitName == "dota_death_prophet_exorcism_spirit"
		or unitName == "npc_dota_dark_willow_creature"
		or unitName == "npc_dota_hero_hoodwink" and unit:HasModifier("modifier_hoodwink_sharpshooter_windup")
end
function X.IsMinionWithNoSkill(unit)
	local unitName = unit:GetUnitName()
	return string.find(unitName, "eidolon")
		or unitName == "npc_dota_furion_treant"
		or unitName == "npc_dota_furion_treant_large"
		or unitName == "npc_dota_invoker_forged_spirit"
		or unitName == "npc_dota_broodmother_spiderling"
		or unitName == "npc_dota_broodmother_spiderite"
		or unitName == "npc_dota_wraith_king_skeleton_warrior"
		or unitName == "npc_dota_beastmaster_greater_boar"
		or unitName == "npc_dota_dark_troll_warlord_skeleton_warrior"
		or string.find(unitName, "npc_dota_warlock")
		or string.find(unitName, "npc_dota_beastmaster_boar")
		or string.find(unitName, "npc_dota_lycan_wolf")
		or string.find(unitName, "npc_dota_neutral_kobold")
		or string.find(unitName, "npc_dota_creep_goodguys")
		or string.find(unitName, "npc_dota_goodguys_siege")
		or string.find(unitName, "npc_dota_creep_badguys")
		or string.find(unitName, "npc_dota_badguys_siege")
		or string.find(unitName, "npc_dota_necronomicon_warrior")
		or unitName == "npc_dota_neutral_centaur_outrunner"
		or unitName == "npc_dota_neutral_fel_beast"
		or unitName == "npc_dota_neutral_polar_furbolg_champion"
		or unitName == "npc_dota_neutral_ogre_mauler"
		or unitName == "npc_dota_neutral_giant_wolf"
		or unitName == "npc_dota_neutral_alpha_wolf"
		or unitName == "npc_dota_neutral_wildkin"
		or unitName == "npc_dota_neutral_jungle_stalker"
		or unitName == "npc_dota_neutral_elder_jungle_stalker"
		or unitName == "npc_dota_neutral_prowler_acolyte"
		or unitName == "npc_dota_neutral_rock_golem"
		or unitName == "npc_dota_neutral_granite_golem"
		or unitName == "npc_dota_neutral_small_thunder_lizard"
		or unitName == "npc_dota_neutral_gnoll_assassin"
		or unitName == "npc_dota_neutral_ghost"
		or unitName == "npc_dota_wraith_ghost"
		or unitName == "npc_dota_neutral_dark_troll"
		or unitName == "npc_dota_neutral_forest_troll_berserker"
		or unitName == "npc_dota_neutral_harpy_scout"
		or unitName == "npc_dota_neutral_black_drake"
		or unitName == "npc_dota_neutral_tadpole"
end
function X.IsMinionWithSkill(unit)
	local unitName = unit:GetUnitName()
	return unitName == "npc_dota_neutral_centaur_khan"
		or unitName == "npc_dota_neutral_polar_furbolg_ursa_warrior"
		or unitName == "npc_dota_neutral_mud_golem"
		or unitName == "npc_dota_neutral_mud_golem_split"
		or unitName == "npc_dota_neutral_mud_golem_split_doom"
		or unitName == "npc_dota_neutral_ogre_magi"
		or unitName == "npc_dota_neutral_enraged_wildkin"
		or unitName == "npc_dota_neutral_satyr_soulstealer"
		or unitName == "npc_dota_neutral_satyr_hellcaller"
		or unitName == "npc_dota_neutral_prowler_shaman"
		or unitName == "npc_dota_neutral_big_thunder_lizard"
		or unitName == "npc_dota_neutral_dark_troll_warlord"
		or unitName == "npc_dota_neutral_satyr_trickster"
		or unitName == "npc_dota_neutral_forest_troll_high_priest"
		or unitName == "npc_dota_neutral_harpy_storm"
		or unitName == "npc_dota_neutral_black_dragon"
		or unitName == "npc_dota_neutral_warpine_raider"
		or unitName == "npc_dota_neutral_froglet_mage"
		or unitName == "npc_dota_neutral_froglet"
		or unitName == "npc_dota_neutral_grown_frog_mage"
		or unitName == "npc_dota_neutral_grown_frog"
		or unitName == "npc_dota_neutral_ancient_frog_mage"
		or unitName == "npc_dota_neutral_ancient_frog"
		or string.find(unitName, "npc_dota_necronomicon_archer")
end
function X.IsFrozeSigil(unit)
	local unitName = unit:GetUnitName()
	return string.find(unitName, "npc_dota_tusk_frozen_sigil")
end
function X.IsHawk(unit)
	local unitName = unit:GetUnitName()
	return unitName == "npc_dota_scout_hawk"
		or unitName == "npc_dota_greater_hawk"
		or string.find(unitName, "npc_dota_beastmaster_hawk")
		or string.find(unitName, "npc_dota_beastmaster_raptor")
end
function X.IsTornado(unit)
	local unitName = unit:GetUnitName()
	return unitName == "npc_dota_enraged_wildkin_tornado"
end
function X.IsHealingWard(unit)
	local unitName = unit:GetUnitName()
	return unitName == "npc_dota_juggernaut_healing_ward"
end
function X.IsBear(unit)
	local unitName = unit:GetUnitName()
	return string.find(unitName, "npc_dota_lone_druid_bear")
end
function X.IsFamiliar(unit)
	local unitName = unit:GetUnitName()
	return string.find(unitName, "npc_dota_visage_familiar")
end
function X.IsPrimalSplit(unit)
	local unitName = unit:GetUnitName()
	return string.find(unitName, "npc_dota_brewmaster_earth")
		or string.find(unitName, "npc_dota_brewmaster_storm")
		or string.find(unitName, "npc_dota_brewmaster_fire")
		or string.find(unitName, "npc_dota_brewmaster_void")
end
return X
