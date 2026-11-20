-- Phantom Lancer: skill build, item build, and ability use for this hero.
-- Accidental globals made file-local (#13): every bot shares one Lua state, so these were shared.
local botTarget
local X = {}
local bot = GetBot()
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local AbilityContext = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local Minion = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local sTalentList = Fu.Skill.GetTalentList(bot)
local sAbilityList = Fu.Skill.GetAbilityList(bot)
local sRole = Fu.Item.GetRoleItemsBuyList(bot)
local tTalentTreeList = { ["t25"] = { 10, 0 }, ["t20"] = { 10, 0 }, ["t15"] = { 10, 0 }, ["t10"] = { 0, 10 } }
local tAllAbilityBuildList = { { 1, 2, 1, 3, 1, 6, 1, 3, 3, 3, 6, 2, 2, 2, 6 } }
local nAbilityBuildList = Fu.Skill.GetRandomBuild(tAllAbilityBuildList)
local nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList)
local sMkbOrAbyssal = RandomInt(1, 9) > 5 and "item_monkey_king_bar" or "item_abyssal_blade"
local sButterfly = "item_butterfly"
local sRoleItemsBuyList = {}
-- Stratz 7.41f, week of 9 Nov 2026: pos 1, 217,062 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_1"] = {
	"item_tango",
	"item_double_branches",
	"item_quelling_blade",
	"item_magic_stick",
	"item_faerie_fire",
	"item_magic_wand",
	"item_wraith_band",
	"item_power_treads",
	"item_manta",
	"item_skadi",
	"item_aghanims_shard",
	"item_heart",
	sButterfly,
	sMkbOrAbyssal,
	"item_ultimate_scepter_2",
	"item_travel_boots",
	"item_moon_shard",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 2, 2,755 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_2"] = {
	"item_tango",
	"item_quelling_blade",
	"item_double_branches",
	"item_magic_stick",
	"item_faerie_fire",
	"item_magic_wand",
	"item_wraith_band",
	"item_power_treads",
	"item_manta",
	"item_aghanims_shard",
	"item_skadi",
	"item_heart",
	sButterfly,
	sMkbOrAbyssal,
	"item_moon_shard",
	"item_ultimate_scepter_2",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 4 has 583 matches, built from pos 5 (1,178) (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_4"] = {
	"item_tango",
	"item_double_branches",
	"item_quelling_blade",
	"item_magic_stick",
	"item_faerie_fire",
	"item_magic_wand",
	"item_wraith_band",
	"item_power_treads",
	"item_ultimate_scepter",
	"item_aghanims_shard",
	"item_skadi",
	sButterfly,
	"item_heart",
	sMkbOrAbyssal,
	"item_ultimate_scepter_2",
	"item_sange",
	"item_moon_shard",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 5, 1,178 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_5"] = {
	"item_tango",
	"item_double_branches",
	"item_quelling_blade",
	"item_magic_stick",
	"item_faerie_fire",
	"item_magic_wand",
	"item_wraith_band",
	"item_power_treads",
	"item_ultimate_scepter",
	"item_aghanims_shard",
	"item_skadi",
	sButterfly,
	"item_heart",
	sMkbOrAbyssal,
	"item_ultimate_scepter_2",
	"item_sange",
	"item_moon_shard",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 3, 3,631 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_3"] = {
	"item_tango",
	"item_quelling_blade",
	"item_double_branches",
	"item_magic_stick",
	"item_faerie_fire",
	"item_magic_wand",
	"item_wraith_band",
	"item_power_treads",
	"item_manta",
	"item_aghanims_shard",
	"item_skadi",
	"item_heart",
	sButterfly,
	sMkbOrAbyssal,
	"item_moon_shard",
	"item_ultimate_scepter_2",
}
X["sBuyList"] = sRoleItemsBuyList[sRole]
X["sSellList"] = { "item_black_king_bar", "item_quelling_blade" }
if Fu.Role.IsPvNMode() or Fu.Role.IsAllShadow() then
	X["sBuyList"], X["sSellList"] = { "PvN_PL" }, { "item_power_treads", "item_quelling_blade" }
end
nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"] =
	Fu.SetUserHeroInit(nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"])
X["sSkillList"] = Fu.Skill.GetSkillList(sAbilityList, nAbilityBuildList, sTalentList, nTalentBuildList)
X["bDeafaultAbility"] = false
X["bDeafaultItem"] = false
function X.MinionThink(minionUnit)
	if Minion.IsValidUnit(minionUnit) then
		if minionUnit:IsIllusion() then
			minionUnit.isIllusion = true
		end
		if minionUnit:HasModifier("modifier_phantom_lancer_phantom_edge_boost") then
			return
		end
		Minion.IllusionThink(minionUnit)
	end
end
local spiritLanceAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[1]), "sAbilityList[1]", "phantom_lancer")
local doppelwalkAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[2]), "sAbilityList[2]", "phantom_lancer")
local phantomRushAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[3]), "sAbilityList[3]", "phantom_lancer")
local juxtaposeAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[6]), "sAbilityList[6]", "phantom_lancer")
local talent4 = SafeAbility(bot:GetAbilityByName(sTalentList[4]), "sTalentList[4]", "phantom_lancer")
local talent5 = SafeAbility(bot:GetAbilityByName(sTalentList[5]), "sTalentList[5]", "phantom_lancer")
local spiritLanceDesire, spiritLanceTarget
local doppelwalkDesire, doppelwalkLocation
local juxtaposeDesire
local aetherRange = 0
local phantomRushDistance = 0
local botLevel, mpRatio, hpRatio, nearbyEnemies, nearbyAllies
function X.SkillsComplement()
	if
		Fu.CanNotUseAbility(bot)
		or bot:IsInvisible()
		or bot:HasModifier("modifier_phantom_lancer_phantom_edge_boost")
	then
		return
	end
	local context = AbilityContext.Build(bot)
	aetherRange = context.aetherRange
	botLevel = context.level
	mpRatio = context.mp
	hpRatio = context.hp
	botTarget = context.target
	nearbyEnemies = context.enemies
	nearbyAllies = context.allies
	if phantomRushAbility:IsTrained() then
		phantomRushDistance = phantomRushAbility:GetSpecialValueInt("max_distance")
	end
	-- sTalentList[5] is now special_bonus_unique_phantom_lancer_lance_damage (+100 lance damage, game files),
	-- not a Phantom Rush range talent, so it no longer stretches the rush distance D.
	spiritLanceDesire, spiritLanceTarget = X.ConsiderQ()
	if spiritLanceDesire > 0 then
		Fu.SetQueuePtToINT(bot, true)
		bot:ActionQueue_UseAbilityOnEntity(spiritLanceAbility, spiritLanceTarget)
		return
	end
	doppelwalkDesire, doppelwalkLocation = X.ConsiderW()
	if doppelwalkDesire > 0 then
		Fu.SetQueuePtToINT(bot, false)
		bot:ActionQueue_UseAbilityOnLocation(doppelwalkAbility, doppelwalkLocation)
		return
	end
	juxtaposeDesire = X.ConsiderR()
	if juxtaposeDesire > 0 then
		Fu.SetQueuePtToINT(bot, false)
		bot:ActionQueue_UseAbility(juxtaposeAbility)
		return
	end
end
function X.ConsiderR()
	-- datafeed: the Juxtapose active (invisibility) comes from the Shard, not the Scepter. The branch was also
	-- switched off with "or true"; CanCastAbility keeps it off while Juxtapose is still passive.
	if not Fu.CanCastAbility(juxtaposeAbility) then
		return BOT_ACTION_DESIRE_NONE
	end
	if Fu.IsRetreating(bot) and Fu.GetHP(bot) < 0.4 then
		return BOT_ACTION_DESIRE_HIGH
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidHero(botTarget)
			and Fu.IsInRange(bot, botTarget, 1200)
			and not Fu.IsInRange(bot, botTarget, 650)
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderQ()
	if not spiritLanceAbility:IsFullyCastable() then
		return 0
	end
	local abilityLevel = spiritLanceAbility:GetLevel()
	local castRange = spiritLanceAbility:GetCastRange() + aetherRange
	if #nearbyEnemies <= 1 then
		castRange = castRange + 200
	end
	local castPoint = spiritLanceAbility:GetCastPoint()
	local manaCost = spiritLanceAbility:GetManaCost()
	local damage = spiritLanceAbility:GetSpecialValueInt("lance_damage")
	local damageType = DAMAGE_TYPE_MAGICAL
	local enemyHeroes = Fu.GetNearbyHeroes(bot, castRange + 50, true, BOT_MODE_NONE)
	local attackDamage = bot:GetAttackDamage()
	if not Fu.IsValidHero(botTarget) or Fu.GetHP(botTarget) > 0.2 then
		for _, enemyHero in pairs(enemyHeroes) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
				and Fu.WillMagicKillTarget(bot, enemyHero, damage, castPoint)
			then
				return BOT_ACTION_DESIRE_HIGH, enemyHero, "Q击杀" .. Fu.Chat.GetNormName(enemyHero)
			end
		end
	end
	if bot:GetActiveMode() == BOT_MODE_LANING and #nearbyAllies <= 2 then
		local laneCreeps = bot:GetNearbyLaneCreeps(castRange + 90, true)
		for _, creep in pairs(laneCreeps) do
			if
				Fu.IsValid(creep)
				and not creep:HasModifier("modifier_fountain_glyph")
				and Fu.IsKeyWordUnit("ranged", creep)
				and not Fu.IsAllysTarget(creep)
				and not Fu.IsInRange(bot, creep, 300)
			then
				local delay = castPoint + GetUnitToUnitDistance(bot, creep) / 1000
				if Fu.WillKillTarget(creep, damage, damageType, delay * 0.95) then
					return BOT_ACTION_DESIRE_HIGH, creep, "Q对线"
				end
			end
		end
	end
	if
		Fu.IsRetreating(bot)
		and (bot:WasRecentlyDamagedByAnyHero(2.0) or bot:GetActiveModeDesire() > BOT_MODE_DESIRE_VERYHIGH)
	then
		for _, enemyHero in pairs(enemyHeroes) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
			then
				return BOT_ACTION_DESIRE_HIGH, enemyHero, "Q撤退" .. enemyHero:GetUnitName()
			end
		end
	end
	if Fu.IsFarming(bot) and botLevel > 5 and Fu.IsAllowedToSpam(bot, 30) then
		if
			Fu.IsValid(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and botTarget:GetTeam() == TEAM_NEUTRAL
			and (botTarget:GetMagicResist() < 0.3 or mpRatio > 0.9)
			and not Fu.CanKillTarget(botTarget, attackDamage * 1.38, DAMAGE_TYPE_PHYSICAL)
			and not Fu.CanKillTarget(botTarget, damage - 10, damageType)
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget, "Q打野"
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidHero(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.CanCastOnTargetAdvanced(botTarget)
			and Fu.IsInRange(botTarget, bot, castRange + 50)
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget, "Q进攻" .. Fu.Chat.GetNormName(botTarget)
		end
		if Fu.IsInTeamFight(bot, 900) and botLevel > 5 then
			for _, enemyHero in pairs(enemyHeroes) do
				if
					Fu.IsValidHero(enemyHero)
					and Fu.CanCastOnNonMagicImmune(enemyHero)
					and Fu.CanCastOnTargetAdvanced(enemyHero)
				then
					return BOT_ACTION_DESIRE_HIGH, enemyHero, "Q团战" .. Fu.Chat.GetNormName(enemyHero)
				end
			end
		end
	end
	if
		(Fu.IsPushing(bot) or Fu.IsDefending(bot) or Fu.IsFarming(bot))
		and #nearbyAllies <= 2
		and botLevel >= 8
		and Fu.IsAllowedToSpam(bot, 30)
	then
		local laneCreeps = bot:GetNearbyLaneCreeps(castRange + 220, true)
		for _, creep in pairs(laneCreeps) do
			if
				Fu.IsValid(creep)
				and not creep:HasModifier("modifier_fountain_glyph")
				and (Fu.IsKeyWordUnit("ranged", creep) or mpRatio > 0.6 and Fu.IsKeyWordUnit("melee", creep))
				and not Fu.IsAllysTarget(creep)
				and creep:GetHealth() > damage * 0.88
			then
				local delay = castPoint + GetUnitToUnitDistance(bot, creep) / 1000
				if
					Fu.WillKillTarget(creep, damage, damageType, delay * 0.98)
					and not Fu.WillKillTarget(creep, attackDamage, DAMAGE_TYPE_PHYSICAL, delay)
				then
					return BOT_ACTION_DESIRE_HIGH, creep, "Q推线1"
				end
				local allyLaneCreeps = bot:GetNearbyLaneCreeps(1200, false)
				if #allyLaneCreeps == 0 then
					return BOT_ACTION_DESIRE_HIGH, creep, "Q推线2"
				end
			end
		end
	end
	if bot:GetActiveMode() == BOT_MODE_ROSHAN and botLevel > 15 and mpRatio > 0.4 then
		if Fu.IsRoshan(botTarget) and Fu.GetHP(botTarget) > 0.2 and Fu.IsInRange(botTarget, bot, castRange) then
			return BOT_ACTION_DESIRE_HIGH, botTarget, "Q肉山"
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderW()
	if not doppelwalkAbility:IsFullyCastable() or bot:DistanceFromFountain() < 600 then
		return 0
	end
	local abilityLevel = doppelwalkAbility:GetLevel()
	local castRange = doppelwalkAbility:GetCastRange() + aetherRange
	local castPoint = doppelwalkAbility:GetCastPoint()
	local manaCost = doppelwalkAbility:GetManaCost()
	local enemyHeroes = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	local retreatLocation = Fu.GetLocationTowardDistanceLocation(bot, Fu.GetTeamFountain(), castRange)
	if
		Fu.IsNotAttackProjectileIncoming(bot, 500)
		or Fu.IsWithoutTarget(bot) and Fu.GetAttackProjectileDamageByRange(bot, 1600) >= bot:GetHealth()
	then
		return BOT_ACTION_DESIRE_HIGH, retreatLocation, "W躲避"
	end
	if
		Fu.IsRetreating(bot)
		and (bot:WasRecentlyDamagedByAnyHero(2.0) or bot:GetActiveModeDesire() > BOT_MODE_DESIRE_VERYHIGH)
		and #nearbyEnemies >= 1
	then
		return BOT_ACTION_DESIRE_HIGH, retreatLocation, "W撤退"
	end
	if Fu.IsGoingOnSomeone(bot) and not bot:HasModifier("modifier_phantom_lancer_phantom_edge_agility") then
		if
			Fu.IsValidHero(botTarget)
			and Fu.CanCastOnMagicImmune(botTarget)
			and not Fu.IsDisabled(botTarget)
			and (X.IsEnemyCastAbility() or hpRatio < 0.2)
			and (
				abilityLevel >= 3
				or mpRatio > 0.6
				or hpRatio < 0.4
				or Fu.GetHP(botTarget) < 0.4
				or DotaTime() > 9 * 60
			)
		then
			local bestLocation = nil
			local bestDistance = 9999
			local targetLocation = Fu.GetCorrectLoc(botTarget, 1.0)
			for distance = 30, castRange, 30 do
				local candidateLocation = Fu.GetFaceTowardDistanceLocation(bot, distance)
				local distanceToTarget = Fu.GetLocationToLocationDistance(targetLocation, candidateLocation)
				if
					distanceToTarget > 300
					and (distanceToTarget < phantomRushDistance - 300 or distanceToTarget < 500)
					and distanceToTarget < bestDistance
				then
					bestDistance = distanceToTarget
					bestLocation = candidateLocation
				end
			end
			if bestLocation ~= nil then
				return BOT_ACTION_DESIRE_HIGH, bestLocation, "W迷惑" .. Fu.Chat.GetNormName(botTarget)
			end
			local chaseLocation = Fu.GetUnitTowardDistanceLocation(bot, botTarget, castRange)
			if
				abilityLevel >= 4
				and not Fu.IsInRange(bot, botTarget, phantomRushDistance + 400)
				and Fu.IsInRange(bot, botTarget, phantomRushDistance + 1000)
				and bot:IsFacingLocation(botTarget:GetLocation(), 30)
				and botTarget:IsFacingLocation(Fu.GetEnemyFountain(), 30)
			then
				return BOT_ACTION_DESIRE_HIGH, chaseLocation, "W追击" .. Fu.Chat.GetNormName(botTarget)
			end
		end
	end
	if
		(Fu.IsPushing(bot) or Fu.IsDefending(bot) or Fu.IsFarming(bot))
		and #nearbyAllies <= 2
		and botLevel >= 9
		and Fu.IsAllowedToSpam(bot, 100)
	then
		if
			Fu.IsValid(botTarget)
			and not Fu.IsInRange(bot, botTarget, phantomRushDistance + 300)
			and Fu.IsInRange(bot, botTarget, phantomRushDistance + 1200)
		then
			return BOT_ACTION_DESIRE_HIGH, Fu.GetUnitTowardDistanceLocation(bot, botTarget, castRange), "W打钱"
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
local ignoredEnemyAbilities = {
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
function X.IsEnemyCastAbility()
	local enemyHeroes = Fu.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(enemyHeroes) do
		if
			enemyHero ~= nil
			and enemyHero:IsAlive()
			and (enemyHero:IsCastingAbility() or enemyHero:IsUsingAbility())
			and enemyHero:IsFacingLocation(bot:GetLocation(), 25)
		then
			local activeAbility = enemyHero:GetCurrentActiveAbility()
			if activeAbility ~= nil then
				local behavior = activeAbility:GetBehavior()
				local abilityName = activeAbility:GetName()
				if
					behavior ~= ABILITY_BEHAVIOR_UNIT_TARGET
					and (enemyHero:IsBot() or enemyHero:GetLevel() >= 5)
					and ignoredEnemyAbilities[abilityName] ~= true
				then
					return true
				end
				if
					behavior == ABILITY_BEHAVIOR_UNIT_TARGET
					and not enemyHero:IsBot()
					and enemyHero:GetLevel() >= 6
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
return X
