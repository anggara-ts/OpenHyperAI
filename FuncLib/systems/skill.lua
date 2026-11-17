-- Shared bot system: skill.
local Utils = require(GetScriptDirectory() .. "/FuncLib/systems/utils")
local Skill = {}
local HIDDEN_ABILITY_NAME = "generic_hidden"
if DOTA_ABILITY_BEHAVIOR_NOT_LEARNABLE == nil then
	DOTA_ABILITY_BEHAVIOR_NOT_LEARNABLE = 64
end
Skill["sAllyUnitAbilityIndex"] = {
	["bloodseeker_bloodrage"] = true,
	["omniknight_purification"] = true,
	["omniknight_repel"] = true,
	["medusa_mana_shield"] = true,
	["grimstroke_spirit_walk"] = true,
	["dazzle_shallow_grave"] = true,
	["dazzle_shadow_wave"] = true,
	["ogre_magi_bloodlust"] = true,
	["lich_frost_shield"] = true,
}
Skill["sProjectileAbilityIndex"] = {
	["chaos_knight_chaos_bolt"] = true,
	["grimstroke_ink_creature"] = true,
	["lich_chain_frost"] = true,
	["medusa_mystic_snake"] = true,
	["phantom_assassin_stifling_dagger"] = true,
	["phantom_lancer_spirit_lance"] = true,
	["skeleton_king_hellfire_blast"] = true,
	["skywrath_mage_arcane_bolt"] = true,
	["sven_storm_bolt"] = true,
	["vengefulspirit_magic_missile"] = true,
	["viper_viper_strike"] = true,
	["witch_doctor_paralyzing_cask"] = true,
}
Skill["sOnlyProjectileAbilityIndex"] = {
	["necrolyte_death_pulse"] = true,
	["arc_warden_spark_wraith"] = true,
	["tinker_heat_seeking_missile"] = true,
	["skywrath_mage_concussive_shot"] = true,
	["rattletrap_battery_assault"] = true,
	["queenofpain_scream_of_pain"] = true,
}
Skill["sStunProjectileAbilityIndex"] = {
	["chaos_knight_chaos_bolt"] = true,
	["skeleton_king_hellfire_blast"] = true,
	["sven_storm_bolt"] = true,
	["vengefulspirit_magic_missile"] = true,
	["witch_doctor_paralyzing_cask"] = true,
	["dragon_knight_dragon_tail"] = true,
}
function Skill.GetTalentList(hero)
	local talentList = {}
	for slot = 0, 25 do
		local ability = hero:GetAbilityInSlot(slot)
		if ability ~= nil and ability:IsTalent() then
			table.insert(talentList, ability:GetName())
		end
	end
	return talentList
end
function Skill.GetAbilityList(hero)
	local abilityList = {}
	local lastSlot = 10
	local heroName = hero:GetUnitName()
	for slot = 0, lastSlot do
		local ability = hero:GetAbilityInSlot(slot)
		if ability then
			local abilityName = ability:GetName()
			if abilityName == HIDDEN_ABILITY_NAME then
				if slot ~= 0 then
					table.insert(abilityList, HIDDEN_ABILITY_NAME)
				else
					log(
						"[WARN] The ability %s on slot %s does not make sense. Check if there is anything wrong with this hero: %s",
						abilityName,
						slot,
						heroName
					)
				end
			elseif
				Utils.AbilityBehaviorHasFlag(ability:GetBehavior(), DOTA_ABILITY_BEHAVIOR_NOT_LEARNABLE)
				and ability:IsHidden()
			then
			elseif ability:IsUltimate() and slot >= 4 then
				if
					Utils.AbilityBehaviorHasFlag(ability:GetBehavior(), DOTA_ABILITY_BEHAVIOR_NOT_LEARNABLE)
					or ability:IsHidden()
				then
					log(
						"[WARN] The ability %s on slot %s seems to be an ultimate for hero: %s. But it is not learnable OR hidden. Check if there is anything wrong with this hero.",
						abilityName,
						slot,
						heroName
					)
				else
					abilityList[6] = abilityName
				end
			elseif not ability:IsTalent() then
				table.insert(abilityList, abilityName)
			else
				log("%s failed to load ability with name= %s, at idx= %s", heroName, abilityName, slot)
			end
		else
			log("[WARN] It seems there is no ability on slot %s for %s", slot, heroName)
		end
	end
	return abilityList
end
function Skill.GetRandomBuild(buildList)
	return buildList[RandomInt(1, #buildList)]
end
function Skill.GetTalentBuild(talentTree)
	local talentBuild = {
		[1] = talentTree["t10"][1] == 0 and 1 or 2,
		[2] = talentTree["t15"][1] == 0 and 3 or 4,
		[3] = talentTree["t20"][1] == 0 and 5 or 6,
		[4] = talentTree["t25"][1] == 0 and 7 or 8,
		[5] = talentTree["t10"][1] == 0 and 2 or 1,
		[6] = talentTree["t15"][1] == 0 and 4 or 3,
		[7] = talentTree["t20"][1] == 0 and 6 or 5,
		[8] = talentTree["t25"][1] == 0 and 8 or 7,
	}
	return talentBuild
end
function Skill.GetSkillList(abilityList, abilityBuild, talentList, talentBuild)
	local heroName = GetBot():GetUnitName()
	local skillList = {}
	local talentIndex = 1
	local abilityIndex = 1
	local totalPoints = #abilityBuild + #talentBuild
	for point = 1, totalPoints do
		if point >= 10 and (point % 5 == 0 or abilityIndex > #abilityBuild) then
			skillList[point] = talentList[talentBuild[talentIndex]]
			talentIndex = talentIndex + 1
		else
			if abilityIndex <= #abilityBuild then
				skillList[point] = abilityList[abilityBuild[abilityIndex]]
				abilityIndex = abilityIndex + 1
			end
		end
	end
	if heroName == "npc_dota_hero_meepo" then
		skillList = {
			[1] = abilityList[abilityBuild[1]],
			[2] = abilityList[abilityBuild[2]],
			[3] = abilityList[abilityBuild[3]],
			[4] = abilityList[abilityBuild[4]],
			[5] = abilityList[abilityBuild[5]],
			[6] = abilityList[abilityBuild[6]],
			[7] = abilityList[abilityBuild[7]],
			[8] = abilityList[abilityBuild[8]],
			[9] = abilityList[abilityBuild[9]],
			[10] = abilityList[abilityBuild[10]],
			[11] = talentList[talentBuild[1]],
			[12] = abilityList[abilityBuild[11]],
			[13] = abilityList[abilityBuild[12]],
			[14] = abilityList[abilityBuild[13]],
			[15] = talentList[talentBuild[2]],
			[16] = abilityList[abilityBuild[14]],
			[17] = abilityList[abilityBuild[15]],
			[18] = talentList[talentBuild[3]],
			[19] = talentList[talentBuild[4]],
			[20] = talentList[talentBuild[5]],
			[21] = talentList[talentBuild[6]],
			[22] = talentList[talentBuild[7]],
			[23] = talentList[talentBuild[8]],
			[24] = abilityList[abilityBuild[16]],
			[25] = talentList[talentBuild[3]],
			[26] = talentList[talentBuild[4]],
			[27] = talentList[talentBuild[5]],
			[28] = talentList[talentBuild[6]],
			[29] = talentList[talentBuild[7]],
			[30] = talentList[talentBuild[8]],
		}
	end
	if heroName == "npc_dota_hero_invoker" then
		-- Indexed by ability point, not hero level. Since 7.41b Invoker gets an
		-- extra point at levels 6, 12 and 18, so the level 10/15/20/25 talents
		-- are his 11th, 17th, 23rd and 28th points.
		local tTalentAtPoint = { [11] = 1, [17] = 2, [23] = 3, [28] = 4, [29] = 5, [30] = 6, [31] = 7, [32] = 8 }
		skillList = {}
		local nAbility = 1
		for nPoint = 1, #abilityBuild + 8 do
			if tTalentAtPoint[nPoint] then
				skillList[nPoint] = talentList[talentBuild[tTalentAtPoint[nPoint]]]
			else
				skillList[nPoint] = abilityList[abilityBuild[nAbility]]
				nAbility = nAbility + 1
			end
		end
	end
	return skillList
end
function Skill.IsHeroInEnemyTeam(heroName)
	for _, playerId in pairs(GetTeamPlayers(GetOpposingTeam())) do
		if GetSelectedHeroName(playerId) == heroName then
			return true
		end
	end
	return false
end
function Skill.GetOutfitName(hero)
	return "item_" .. string.gsub(hero:GetUnitName(), "npc_dota_hero_", "") .. "_outfit"
end
return Skill
