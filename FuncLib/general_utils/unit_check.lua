-- Shared helper: unit check.
local function installUnitCheck(Fu)
	function Fu.IsNoItemIllution(unit)
		if
			(unit:IsIllusion() or Fu.IsMeepoClone(unit))
			and not unit:HasModifier("modifier_arc_warden_tempest_double")
			and unit:GetUnitName() ~= "npc_dota_hero_vengefulspirit"
		then
			return true
		end
		return false
	end
	function Fu.IsNoAbilityIllution(unit)
		if
			unit:IsIllusion()
			and not unit:HasModifier("modifier_arc_warden_tempest_double")
			and unit:GetUnitName() ~= "npc_dota_hero_vengefulspirit"
			and not Fu.IsMeepoClone(unit)
		then
			return true
		end
		return false
	end
	function Fu.IsSuspiciousIllusion(unit)
		if unit == nil or unit:IsNull() then
			return false
		end
		-- The answer used to be cached on the handle for the whole game. One bad moment (a level-up
		-- tick, a dead read) flagged a real hero as an illusion until the game ended, and every
		-- check that skips illusions ignored that hero. Reuse it for half a second only.
		if unit.is_suspicious_illusion ~= nil and DotaTime() - (unit.is_suspicious_illusion_at or -999) < 0.5 then
			return unit.is_suspicious_illusion
		end
		unit.is_suspicious_illusion_at = DotaTime()
		if not unit:CanBeSeen() then
			unit.is_suspicious_illusion = false
			return false
		end
		if
			unit:CanBeSeen()
			and (not unit:IsHero() or unit:IsCastingAbility() or unit:IsUsingAbility() or unit:IsChanneling())
		then
			unit.is_suspicious_illusion = false
			return false
		end
		local bot = GetBot()
		if unit:GetTeam() == bot:GetTeam() then
			unit.is_suspicious_illusion = unit:IsIllusion() or unit:HasModifier("modifier_arc_warden_tempest_double")
			return unit.is_suspicious_illusion
		elseif unit:GetTeam() == GetOpposingTeam() then
			if
				unit:HasModifier("modifier_illusion")
				or unit:HasModifier("modifier_darkseer_wallofreplica_illusion")
				or unit:HasModifier("modifier_phantom_lancer_doppelwalk_illusion")
				or unit:HasModifier("modifier_phantom_lancer_juxtapose_illusion")
				or unit:HasModifier("modifier_skeleton_king_reincarnation_scepter_active")
				or unit:HasModifier("modifier_item_helm_of_the_undying_active")
				or unit:HasModifier("modifier_terrorblade_conjureimage")
			then
				unit.is_suspicious_illusion = true
				return true
			end
			local playerId = unit:GetPlayerID()
			if not IsHeroAlive(playerId) then
				unit.is_suspicious_illusion = true
				return true
			end
			if GetHeroLevel(playerId) > unit:GetLevel() then
				unit.is_suspicious_illusion = true
				return true
			end
		end
		unit.is_suspicious_illusion = false
		return false
	end
	function Fu.IsKeyWordUnit(keyword, unit)
		if string.find(unit:GetUnitName(), keyword) ~= nil then
			return true
		end
		return false
	end
	function Fu.IsHumanPlayer(unit)
		return not unit:IsBot()
	end
	function Fu.IsValid(unit)
		return unit ~= nil and not unit:IsNull() and unit:CanBeSeen() and unit:IsAlive() and not unit:IsBuilding()
	end
	function Fu.IsValidTarget(unit)
		return Fu.Utils.IsValidHero(unit)
	end
	function Fu.IsValidHero(unit)
		return Fu.Utils.IsValidHero(unit)
	end
	function Fu.IsValidBuilding(unit)
		return Fu.Utils.IsValidBuilding(unit)
	end
	function Fu.IsRoshan(unit)
		return unit ~= nil
			and not unit:IsNull()
			and unit:CanBeSeen()
			and unit:IsAlive()
			and string.find(unit:GetUnitName(), "roshan") ~= nil
	end
	function Fu.CanBeAttacked(unit)
		return unit ~= nil
			and not Fu.HasForbiddenModifier(unit)
			and unit:IsAlive()
			and unit:CanBeSeen()
			and not unit:IsNull()
			and not unit:IsAttackImmune()
			and not unit:IsInvulnerable()
			and not unit:HasModifier("modifier_fountain_glyph")
			and not unit:HasModifier("modifier_omninight_guardian_angel")
			and not unit:HasModifier("modifier_winter_wyvern_cold_embrace")
			and not unit:HasModifier("modifier_dark_willow_shadow_realm_buff")
			and not unit:HasModifier("modifier_ringmaster_the_box_buff")
			and not unit:HasModifier("modifier_dazzle_nothl_projection_soul_debuff")
			and (unit:GetTeam() == GetTeam() or not unit:HasModifier("modifier_crystal_maiden_frostbite"))
			and (
				unit:GetTeam() ~= GetTeam()
				or unit:GetUnitName() ~= "npc_dota_wraith_king_skeleton_warrior"
					and unit:GetHealth() / unit:GetMaxHealth() < 0.5
			)
	end
	function Fu.IsTormentor(unit)
		return unit ~= nil
			and not unit:IsNull()
			and unit:CanBeSeen()
			and unit:IsAlive()
			and string.find(unit:GetUnitName(), "miniboss") ~= nil
	end
	function Fu.IsRealBot(unit)
		for i = 1, 5 do
			local teamMember = GetTeamMember(i)
			if teamMember and unit == teamMember then
				return true
			end
		end
		return false
	end
	-- A clone of our own Meepo (a Meepo on our team that is not one of our team members). Only our team: for the
	-- enemy team GetTeamMember cannot tell the real Meepo from a clone, and every enemy Meepo body is a threat and a
	-- target (#132, game 052: the check was true for the enemy's real Meepo too, so Fu.GetNearbyHeroes left all
	-- enemy Meepo bodies out and Shadow Fiend, rooted and hit by two of them, counted enemies=0).
	function Fu.IsMeepoClone(unit)
		if
			Fu.IsValidHero(unit)
			and unit:GetUnitName() == "npc_dota_hero_meepo"
			and unit:GetTeam() == GetTeam()
			and not Fu.IsRealBot(unit)
		then
			return true
		end
		return false
	end
	function Fu.IsEnemyHero(unit)
		if unit ~= nil and unit:GetTeam() ~= GetBot():GetTeam() then
			return true
		else
			return false
		end
	end
end
return installUnitCheck
