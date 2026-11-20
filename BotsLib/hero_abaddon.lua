-- Abaddon: skill build, item build, and ability use for this hero.
local X = {}
local bot = GetBot()
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local AbilityContext = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local Minion = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local sTalentList = Fu.Skill.GetTalentList(bot)
local sAbilityList = Fu.Skill.GetAbilityList(bot)
local sRole = Fu.Item.GetRoleItemsBuyList(bot)
local tTalentTreeList = {
	{ ["t25"] = { 10, 0 }, ["t20"] = { 0, 10 }, ["t15"] = { 10, 0 }, ["t10"] = { 10, 0 } },
	{ ["t25"] = { 0, 10 }, ["t20"] = { 10, 0 }, ["t15"] = { 10, 0 }, ["t10"] = { 10, 0 } },
	{ ["t25"] = { 10, 0 }, ["t20"] = { 0, 10 }, ["t15"] = { 10, 0 }, ["t10"] = { 10, 0 } },
}
local tAllAbilityBuildList =
	{ { 2, 3, 2, 3, 2, 6, 2, 3, 3, 1, 6, 1, 1, 1, 6 }, { 2, 3, 2, 1, 2, 6, 2, 1, 1, 1, 6, 3, 3, 3, 6 } }
local nAbilityBuildList
local nTalentBuildList
if sRole == "pos_1" or sRole == "pos_2" then
	nAbilityBuildList = tAllAbilityBuildList[1]
	nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList[1])
elseif sRole == "pos_3" then
	nAbilityBuildList = tAllAbilityBuildList[1]
	nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList[2])
else
	nAbilityBuildList = tAllAbilityBuildList[2]
	nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList[3])
end
local sRoleItemsBuyList = {}
sRoleItemsBuyList["pos_1"] = {
	"item_tango",
	"item_double_branches",
	"item_quelling_blade",
	"item_circlet",
	"item_mantle",
	"item_magic_wand",
	"item_null_talisman",
	"item_phase_boots",
	"item_echo_sabre",
	"item_manta",
	"item_harpoon",
	"item_black_king_bar",
	"item_aghanims_shard",
	"item_bloodthorn",
	"item_abyssal_blade",
	"item_ultimate_scepter_2",
	"item_moon_shard",
	"item_travel_boots_2",
}
sRoleItemsBuyList["pos_2"] = sRoleItemsBuyList["pos_1"]
sRoleItemsBuyList["pos_3"] = {
	"item_tango",
	"item_double_branches",
	"item_quelling_blade",
	"item_magic_stick",
	"item_faerie_fire",
	"item_phase_boots",
	"item_magic_wand",
	"item_blade_mail",
	"item_radiance",
	"item_ultimate_scepter",
	"item_aghanims_shard",
	"item_assault",
	"item_lotus_orb",
	"item_ultimate_scepter_2",
	"item_abyssal_blade",
	"item_travel_boots_2",
	"item_moon_shard",
}
sRoleItemsBuyList["pos_4"] = {
	"item_tango",
	"item_double_branches",
	"item_blood_grenade",
	"item_magic_stick",
	"item_faerie_fire",
	"item_tranquil_boots",
	"item_magic_wand",
	"item_blade_mail",
	"item_solar_crest",
	"item_holy_locket",
	"item_boots_of_bearing",
	"item_ultimate_scepter",
	"item_aghanims_shard",
	"item_lotus_orb",
	"item_sheepstick",
	"item_ultimate_scepter_2",
	"item_wind_waker",
	"item_moon_shard",
}
sRoleItemsBuyList["pos_5"] = {
	"item_tango",
	"item_double_branches",
	"item_blood_grenade",
	"item_magic_stick",
	"item_faerie_fire",
	"item_arcane_boots",
	"item_magic_wand",
	"item_blade_mail",
	"item_solar_crest",
	"item_holy_locket",
	"item_guardian_greaves",
	"item_ultimate_scepter",
	"item_aghanims_shard",
	"item_lotus_orb",
	"item_sheepstick",
	"item_ultimate_scepter_2",
	"item_wind_waker",
	"item_moon_shard",
}
X["sBuyList"] = sRoleItemsBuyList[sRole]
X["sSellList"] = {
	"item_black_king_bar",
	"item_quelling_blade",
	"item_lotus_orb",
	"item_magic_wand",
	"item_wind_waker",
	"item_blade_mail",
}
if Fu.Role.IsPvNMode() or Fu.Role.IsAllShadow() then
	X["sBuyList"], X["sSellList"] = { "PvN_antimage" }, {}
end
nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"] =
	Fu.SetUserHeroInit(nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"])
X["sSkillList"] = Fu.Skill.GetSkillList(sAbilityList, nAbilityBuildList, sTalentList, nTalentBuildList)
X["bDeafaultAbility"] = false
X["bDeafaultItem"] = false
function X.MinionThink(hMinionUnit)
	Minion.MinionThink(hMinionUnit)
end
local mistCoilAbility = SafeAbility(bot:GetAbilityByName("abaddon_death_coil"), "abaddon_death_coil", "abaddon")
local aphoticShieldAbility =
	SafeAbility(bot:GetAbilityByName("abaddon_aphotic_shield"), "abaddon_aphotic_shield", "abaddon")
local mistCoilDesire, mistCoilTarget
local aphoticShieldDesire, aphoticShieldTarget
local isAttacking = false
local botTarget, hpRatio
local nearbyAllies, nearbyEnemies
-- [OHA-ABADDON]: new casts (Borrowed Time by hand, Mist Coil harass), at most once per 10s per reason.
local function LogAbaddon(why)
	bot._abaddonLogAt = bot._abaddonLogAt or {}
	if DotaTime() < (bot._abaddonLogAt[why] or -999) then
		return
	end
	bot._abaddonLogAt[why] = DotaTime() + 10
	pcall(print, string.format("[OHA-ABADDON] t=%.0f %s hp=%.2f", DotaTime(), why, Fu.GetHP(bot)))
end
function X.SkillsComplement()
	if Fu.CanNotUseAbility(bot) then
		return
	end
	mistCoilAbility = SafeAbility(bot:GetAbilityByName("abaddon_death_coil"), "abaddon_death_coil", "abaddon")
	aphoticShieldAbility =
		SafeAbility(bot:GetAbilityByName("abaddon_aphotic_shield"), "abaddon_aphotic_shield", "abaddon")
	isAttacking = Fu.IsAttacking(bot)
	hpRatio = Fu.GetHP(bot)
	botTarget = Fu.GetProperTarget(bot)
	nearbyAllies = bot:GetNearbyHeroes(1600, false, BOT_MODE_NONE)
	nearbyEnemies = bot:GetNearbyHeroes(1600, true, BOT_MODE_NONE)
	-- fix: Borrowed Time (active, strong dispel, datafeed) was never cast; it only auto-fired below
	-- hp_threshold 400 HP, which late game is ~10% HP and too late against burst.
	local borrowedTime = bot:GetAbilityByName("abaddon_borrowed_time")
	if X.ConsiderBorrowedTime(borrowedTime) > 0 then
		bot:Action_UseAbility(borrowedTime)
		return
	end
	aphoticShieldDesire, aphoticShieldTarget = X.ConsiderAphoticShield()
	if aphoticShieldDesire > 0 then
		Fu.SetQueuePtToINT(bot, false)
		bot:ActionQueue_UseAbilityOnEntity(aphoticShieldAbility, aphoticShieldTarget)
		return
	end
	mistCoilDesire, mistCoilTarget = X.ConsiderMistCoil()
	if mistCoilDesire > 0 then
		Fu.SetQueuePtToINT(bot, false)
		bot:ActionQueue_UseAbilityOnEntity(mistCoilAbility, mistCoilTarget)
		return
	end
end
function X.ConsiderMistCoil()
	if not Fu.CanCastAbility(mistCoilAbility) then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castRange = Fu.GetProperCastRange(false, bot, mistCoilAbility:GetCastRange())
	local castPoint = mistCoilAbility:GetCastPoint()
	-- datafeed: Mist Coil's damage value is "damage_heal"; "target_damage" no longer exists (read 0)
	local damage = mistCoilAbility:GetSpecialValueInt("damage_heal")
	local projectileSpeed = mistCoilAbility:GetSpecialValueInt("missile_speed")
	local manaCost = mistCoilAbility:GetManaCost()
	local manaAfter = Fu.GetManaAfter(manaCost)
	local manaThreshold = Fu.GetManaThreshold(bot, manaCost, { aphoticShieldAbility })
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanBeAttacked(enemyHero)
			and Fu.IsInRange(bot, enemyHero, castRange)
			-- fix: Mist Coil is SPELL_IMMUNITY_ENEMIES_NO (game data); CanCastOnMagicImmune let it target BKB heroes
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and Fu.CanCastOnTargetAdvanced(enemyHero)
			and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
			and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
			and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
			and not enemyHero:HasModifier("modifier_templar_assassin_refraction_absorb")
		then
			local delay = GetUnitToUnitDistance(bot, enemyHero) / projectileSpeed + castPoint
			if Fu.WillKillTarget(enemyHero, damage, DAMAGE_TYPE_MAGICAL, delay) then
				return BOT_ACTION_DESIRE_HIGH, enemyHero
			end
		end
	end
	local weakestAlly = nil
	local weakestAllyHp = math.huge
	for _, allyHero in pairs(nearbyAllies) do
		if
			Fu.IsValidHero(allyHero)
			and Fu.CanBeAttacked(allyHero)
			and Fu.IsInRange(bot, allyHero, castRange + 200)
			and allyHero ~= bot
			and not allyHero:IsIllusion()
			and not allyHero:HasModifier("modifier_doom_bringer_doom_aura_enemy")
			and not allyHero:HasModifier("modifier_ice_blast")
			and not allyHero:HasModifier("modifier_necrolyte_reapers_scythe")
			and not allyHero:HasModifier("modifier_fountain_aura_buff")
			and not allyHero:HasModifier("modifier_rune_regen")
		then
			local allyHp = Fu.GetHP(allyHero)
			if allyHp < weakestAllyHp and allyHp <= 0.8 then
				weakestAlly = allyHero
				weakestAllyHp = allyHp
			end
			if allyHero:WasRecentlyDamagedByAnyHero(2.0) and Fu.IsDisabled(allyHero) and allyHp < 0.8 then
				return BOT_ACTION_DESIRE_HIGH, allyHero
			end
		end
	end
	if weakestAlly then
		return BOT_ACTION_DESIRE_HIGH, weakestAlly
	end
	-- fix: Mist Coil only hit enemy heroes to finish them. While engaging, coil the target
	-- (damage_heal, magical) when mana allows and Abaddon can afford the 40 self-damage.
	if
		Fu.IsGoingOnSomeone(bot)
		and Fu.IsValidHero(botTarget)
		and Fu.IsInRange(bot, botTarget, castRange)
		and Fu.CanCastOnNonMagicImmune(botTarget)
		and Fu.CanCastOnTargetAdvanced(botTarget)
		and not Fu.IsSuspiciousIllusion(botTarget)
		and manaAfter > manaThreshold
		and hpRatio > 0.4
	then
		LogAbaddon("coil-engage")
		return BOT_ACTION_DESIRE_HIGH, botTarget
	end
	if Fu.IsLaning(bot) and Fu.IsEarlyGame() and manaAfter > manaThreshold + 0.1 then
		local nearbyLaneCreeps = bot:GetNearbyLaneCreeps(math.min(castRange + 300, 1600), true)
		for _, creep in pairs(nearbyLaneCreeps) do
			if Fu.IsValid(creep) and Fu.CanBeAttacked(creep) and not Fu.IsOtherAllysTarget(creep) then
				local delay = GetUnitToUnitDistance(bot, creep) / projectileSpeed + castPoint
				if Fu.WillKillTarget(creep, damage, DAMAGE_TYPE_MAGICAL, delay) then
					local creepName = creep:GetUnitName()
					local enemyHeroesNearCreep = bot:FindAoELocation(true, true, creep:GetLocation(), 0, 800, 0, 0)
					if string.find(creepName, "ranged") then
						if enemyHeroesNearCreep.count > 0 or Fu.IsUnitTargetedByTower(creep, false) then
							return BOT_ACTION_DESIRE_HIGH, creep
						end
					end
					if Fu.IsEnemyTargetUnit(creep, 1200) and manaAfter > manaThreshold + 0.2 then
						return BOT_ACTION_DESIRE_HIGH, creep
					end
				end
			end
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if
			Fu.IsRoshan(botTarget)
			and Fu.CanBeAttacked(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and isAttacking
			and manaAfter > 0.5
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if
			Fu.IsTormentor(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and isAttacking
			and manaAfter > 0.5
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function X.ConsiderAphoticShield()
	if not Fu.CanCastAbility(aphoticShieldAbility) then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castRange = Fu.GetProperCastRange(false, bot, aphoticShieldAbility:GetCastRange())
	local manaCost = aphoticShieldAbility:GetManaCost()
	local manaAfter = Fu.GetManaAfter(manaCost)
	local manaThreshold = Fu.GetManaThreshold(bot, manaCost, { mistCoilAbility })
	for _, allyHero in pairs(nearbyAllies) do
		if
			Fu.IsValidHero(allyHero)
			and Fu.CanBeAttacked(allyHero)
			and Fu.IsInRange(bot, allyHero, castRange + 300)
			and not allyHero:IsIllusion()
			-- fix: Aphotic Shield has DOTA_UNIT_TARGET_FLAG_NOT_MAGIC_IMMUNE_ALLIES (game data); a BKB ally is an invalid target
			and not allyHero:IsMagicImmune()
			and not allyHero:HasModifier("modifier_abaddon_aphotic_shield")
			and not allyHero:HasModifier("modifier_abaddon_borrowed_time")
			and not allyHero:HasModifier("modifier_doom_bringer_doom_aura_enemy")
			and not allyHero:HasModifier("modifier_ice_blast")
			and not allyHero:HasModifier("modifier_necrolyte_reapers_scythe")
			and not allyHero:HasModifier("modifier_fountain_aura_buff")
			and not allyHero:HasModifier("modifier_rune_regen")
		then
			local allyHp = Fu.GetHP(allyHero)
			if allyHero:HasModifier("modifier_legion_commander_duel") then
				return BOT_ACTION_DESIRE_HIGH, allyHero
			end
			if Fu.IsDisabled(allyHero) then
				return BOT_ACTION_DESIRE_HIGH, allyHero
			end
			if Fu.IsGoingOnSomeone(allyHero) then
				local allyTarget = Fu.GetProperTarget(allyHero)
				if
					Fu.IsValidHero(allyTarget)
					and Fu.IsInRange(allyHero, allyTarget, allyHero:GetAttackRange() + 300)
					and not Fu.IsSuspiciousIllusion(allyTarget)
				then
					if allyHp < 0.4 or manaAfter > manaThreshold + 0.1 then
						return BOT_ACTION_DESIRE_HIGH, allyHero
					end
				end
			end
			if Fu.IsRetreating(allyHero) and not Fu.IsRealInvisible(allyHero) then
				if allyHero:WasRecentlyDamagedByAnyHero(2.0) and allyHp < 0.75 then
					return BOT_ACTION_DESIRE_HIGH, allyHero
				end
			end
			if Fu.IsDoingRoshan(bot) then
				if Fu.IsRoshan(botTarget) and Fu.IsInRange(bot, botTarget, 800) and isAttacking and allyHp < 0.5 then
					return BOT_ACTION_DESIRE_HIGH, allyHero
				end
			end
			if Fu.IsDoingTormentor(bot) then
				if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, 800) and isAttacking and allyHp < 0.5 then
					return BOT_ACTION_DESIRE_HIGH, allyHero
				end
			end
			if allyHero:WasRecentlyDamagedByAnyHero(2.0) and allyHp < 0.4 and manaAfter > manaThreshold + 0.1 then
				return BOT_ACTION_DESIRE_HIGH, allyHero
			end
		end
	end
	if Fu.IsRetreating(bot) and not Fu.IsRealInvisible(bot) then
		if bot:WasRecentlyDamagedByAnyHero(2.0) and hpRatio < 0.75 then
			return BOT_ACTION_DESIRE_HIGH, bot
		end
	end
	if Fu.IsFarming(bot) and isAttacking and manaAfter > manaThreshold + 0.1 then
		local nearbyCreeps = bot:GetNearbyCreeps(1600, true)
		if
			#nearbyCreeps > 0
			and hpRatio < 0.5
			and not bot:HasModifier("modifier_abaddon_aphotic_shield")
			and not bot:HasModifier("modifier_abaddon_borrowed_time")
		then
			return BOT_ACTION_DESIRE_HIGH, bot
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
-- Borrowed Time by hand: under hero damage in a fight, before burst drops him through the
-- 400 HP auto-trigger. The cast also strong-dispels him (datafeed).
function X.ConsiderBorrowedTime(borrowedTime)
	if not Fu.CanCastAbility(borrowedTime) or bot:HasModifier("modifier_abaddon_borrowed_time") then
		return BOT_ACTION_DESIRE_NONE
	end
	if not bot:WasRecentlyDamagedByAnyHero(1.5) then
		return BOT_ACTION_DESIRE_NONE
	end
	local enemiesNear = Fu.GetEnemiesNearLoc(bot:GetLocation(), 1200)
	if enemiesNear == nil or #enemiesNear == 0 then
		return BOT_ACTION_DESIRE_NONE
	end
	if hpRatio < 0.35 or hpRatio < 0.5 and #enemiesNear >= 2 then
		LogAbaddon("borrowed-time enemies=" .. #enemiesNear)
		return BOT_ACTION_DESIRE_HIGH
	end
	return BOT_ACTION_DESIRE_NONE
end
return X
