-- Shared helper: projectile.
local function installProjectile(Fu)
	function Fu.IsAllyUnitSpell(abilityName)
		return Fu.Skill["sAllyUnitAbilityIndex"][abilityName] == true
	end
	function Fu.IsProjectileUnitSpell(abilityName)
		return Fu.Skill["sProjectileAbilityIndex"][abilityName] == true
	end
	function Fu.IsOnlyProjectileSpell(abilityName)
		return Fu.Skill["sOnlyProjectileAbilityIndex"][abilityName] == true
	end
	function Fu.IsStunProjectileSpell(abilityName)
		return Fu.Skill["sStunProjectileAbilityIndex"][abilityName] == true
	end
	function Fu.IsWillBeCastUnitTargetSpell(unit, range)
		if range > 1600 then
			range = 1600
		end
		local nearbyEnemies = Fu.GetNearbyHeroes(unit, range, true, BOT_MODE_NONE)
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				enemyHero ~= nil
				and enemyHero:IsAlive()
				and (enemyHero:IsCastingAbility() or enemyHero:IsUsingAbility())
				and enemyHero:IsFacingLocation(unit:GetLocation(), 20)
			then
				local activeAbility = enemyHero:GetCurrentActiveAbility()
				if activeAbility ~= nil and activeAbility:GetBehavior() == ABILITY_BEHAVIOR_UNIT_TARGET then
					local abilityName = activeAbility:GetName()
					if not Fu.IsAllyUnitSpell(abilityName) then
						if Fu.IsInRange(enemyHero, unit, 330) or not Fu.IsProjectileUnitSpell(abilityName) then
							if not Fu.IsHumanPlayer(enemyHero) then
								return true
							else
								local animCycle = enemyHero:GetAnimCycle()
								local castPoint = activeAbility:GetCastPoint()
								if animCycle > 0.1 and castPoint * (1 - animCycle) < 0.27 then
									return true
								end
							end
						end
					end
				end
			end
		end
		return false
	end
	function Fu.IsWillBeCastPointSpell(unit, range)
		local nearbyEnemies = Fu.GetNearbyHeroes(unit, range, true, BOT_MODE_NONE)
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				enemyHero ~= nil
				and enemyHero:IsAlive()
				and (enemyHero:IsCastingAbility() or enemyHero:IsUsingAbility())
				and enemyHero:IsFacingLocation(unit:GetLocation(), 50)
			then
				local activeAbility = enemyHero:GetCurrentActiveAbility()
				if activeAbility ~= nil then
					if
						activeAbility:GetBehavior() == ABILITY_BEHAVIOR_POINT
						or activeAbility:GetBehavior() == ABILITY_BEHAVIOR_NO_TARGET
						or activeAbility:GetBehavior() == 48
					then
						return true
					end
				end
			end
		end
		return false
	end
	function Fu.IsProjectileIncoming(unit, range)
		local projectiles = unit:GetIncomingTrackingProjectiles()
		for _, projectile in pairs(projectiles) do
			if
				projectile.is_dodgeable
				and not projectile.is_attack
				and GetUnitToLocationDistance(unit, projectile.location) < range
				and (projectile.caster == nil or projectile.caster:GetTeam() ~= GetTeam())
				and (
					projectile.ability ~= nil
					and not Fu.IsOnlyProjectileSpell(projectile.ability:GetName())
					and (
						projectile.ability:GetName() ~= "medusa_mystic_snake"
						or projectile.caster == nil
						or projectile.caster:GetUnitName() == "npc_dota_hero_medusa"
					)
				)
			then
				return true
			end
		end
		return false
	end
	function Fu.IsUnitTargetProjectileIncoming(unit, range)
		local projectiles = unit:GetIncomingTrackingProjectiles()
		for _, projectile in pairs(projectiles) do
			if
				not projectile.is_attack
				and GetUnitToLocationDistance(unit, projectile.location) < range
				and (projectile.caster == nil or projectile.caster:GetTeam() ~= unit:GetTeam() and projectile.caster:IsHero() and projectile.caster:GetUnitName() ~= "npc_dota_hero_antimage" and projectile.caster:GetUnitName() ~= "npc_dota_hero_templar_assassin")
				and (projectile.ability ~= nil and (projectile.ability:GetName() ~= "medusa_mystic_snake" or projectile.caster == nil or projectile.caster:GetUnitName() == "npc_dota_hero_medusa"))
				and (
					projectile.ability:GetBehavior() == ABILITY_BEHAVIOR_UNIT_TARGET
					or not Fu.IsOnlyProjectileSpell(projectile.ability:GetName())
				)
			then
				return true
			end
		end
		return false
	end
	function Fu.IsStunProjectileIncoming(unit, range)
		local projectiles = unit:GetIncomingTrackingProjectiles()
		for _, projectile in pairs(projectiles) do
			if
				not projectile.is_attack
				and GetUnitToLocationDistance(unit, projectile.location) < range
				and projectile.ability ~= nil
				and Fu.IsStunProjectileSpell(projectile.ability:GetName())
			then
				return true
			end
		end
		return false
	end
	function Fu.IsAttackProjectileIncoming(unit, range)
		local projectiles = unit:GetIncomingTrackingProjectiles()
		for _, projectile in pairs(projectiles) do
			if projectile.is_attack and GetUnitToLocationDistance(unit, projectile.location) < range then
				return true
			end
		end
		return false
	end
	function Fu.IsNotAttackProjectileIncoming(unit, range)
		local projectiles = unit:GetIncomingTrackingProjectiles()
		for _, projectile in pairs(projectiles) do
			if
				not projectile.is_attack
				and GetUnitToLocationDistance(unit, projectile.location) < range
				and (projectile.caster == nil or projectile.caster:GetTeam() ~= unit:GetTeam())
				and (
					projectile.ability ~= nil
					and (
						projectile.ability:GetName() ~= "medusa_mystic_snake"
						or projectile.caster == nil
						or projectile.caster:GetUnitName() == "npc_dota_hero_medusa"
					)
				)
			then
				return true
			end
		end
		return false
	end
	local ignoredSelfCasts = {
		["antimage_blink"] = true,
		["arc_warden_magnetic_field"] = true,
		["arc_warden_spark_wraith"] = true,
		["arc_warden_tempest_double"] = true,
		["chaos_knight_phantasm"] = true,
		["clinkz_burning_army"] = true,
		["death_prophet_exorcism"] = true,
		["dragon_knight_elder_dragon_form"] = true,
		["juggernaut_healing_ward"] = true,
		["necrolyte_death_pulse"] = true,
		["necrolyte_sadist"] = true,
		["omniknight_guardian_angel"] = true,
		["phantom_assassin_blur"] = true,
		["pugna_nether_ward"] = true,
		["skeleton_king_mortal_strike"] = true,
		["sven_warcry"] = true,
		["sven_gods_strength"] = true,
		["templar_assassin_refraction"] = true,
		["templar_assassin_psionic_trap"] = true,
		["windrunner_windrun"] = true,
		["witch_doctor_voodoo_restoration"] = true,
	}
	function Fu.DidEnemyCastAbility()
		local bot = GetBot()
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE)
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				enemyHero ~= nil
				and enemyHero:IsAlive()
				and enemyHero:IsFacingLocation(bot:GetLocation(), 30)
				and (enemyHero:IsCastingAbility() or enemyHero:IsUsingAbility())
			then
				local activeAbility = enemyHero:GetCurrentActiveAbility()
				if activeAbility ~= nil then
					local behavior = activeAbility:GetBehavior()
					local abilityName = activeAbility:GetName()
					if
						behavior ~= ABILITY_BEHAVIOR_UNIT_TARGET
						and (enemyHero:IsBot() or enemyHero:GetLevel() >= 5)
						and not ignoredSelfCasts[abilityName]
					then
						return true
					end
					if
						behavior == ABILITY_BEHAVIOR_UNIT_TARGET
						and enemyHero:GetLevel() >= 6
						and not enemyHero:IsBot()
						and not Fu.IsAllyUnitSpell(abilityName)
						and (not Fu.IsProjectileUnitSpell(abilityName) or Fu.IsInRange(bot, enemyHero, 400))
					then
						return true
					end
				end
			end
		end
		return false
	end
end
return installProjectile
