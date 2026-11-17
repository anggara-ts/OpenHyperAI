-- Oracle: skill build, item build, and ability use for this hero.
local X = {}
local bot = GetBot()
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local AbilityContext = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local Minion = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local sTalentList = Fu.Skill.GetTalentList(bot)
local sAbilityList = Fu.Skill.GetAbilityList(bot)
local sRole = Fu.Item.GetRoleItemsBuyList(bot)
local tTalentTreeList = { ["t25"] = { 10, 0 }, ["t20"] = { 0, 10 }, ["t15"] = { 10, 0 }, ["t10"] = { 10, 0 } }
local tAllAbilityBuildList = { { 1, 3, 3, 2, 3, 6, 3, 1, 1, 1, 6, 2, 2, 2, 6 } }
local nAbilityBuildList = Fu.Skill.GetRandomBuild(tAllAbilityBuildList)
local nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList)
local sRoleItemsBuyList = {}
sRoleItemsBuyList["pos_1"] = {
	"item_crystal_maiden_outfit",
	"item_kaya",
	"item_dagon_2",
	"item_rod_of_atos",
	"item_glimmer_cape",
	"item_kaya_and_sange",
	"item_force_staff",
	"item_dagon_5",
	"item_hurricane_pike",
	"item_aghanims_shard",
	"item_shivas_guard",
	"item_gungir",
	"item_moon_shard",
	"item_ultimate_scepter",
	"item_ultimate_scepter_2",
	"item_travel_boots_2",
}
sRoleItemsBuyList["pos_2"] = sRoleItemsBuyList["pos_1"]
sRoleItemsBuyList["pos_4"] = {
	"item_priest_outfit",
	"item_mekansm",
	"item_glimmer_cape",
	"item_aghanims_shard",
	"item_guardian_greaves",
	"item_blink",
	"item_ultimate_scepter",
	"item_shivas_guard",
	"item_moon_shard",
	"item_ultimate_scepter_2",
	"item_sheepstick",
}
sRoleItemsBuyList["pos_5"] = {
	-- Arcane Boots (crystal_maiden_outfit) into Guardian Greaves, Aether Lens, Blink Dagger and
	-- Aghanim's Shard instead of Tranquil -> Boots of Bearing (Drum), Pipe and an early Scepter: Arcane
	-- 99% (#1), Blink 70%, Shard 65%, Aether 58%, Greaves 30% of his matches (Dotabuff, last patch);
	-- Scepter, Pipe, Bearing and Drum are not in his top 25.
	"item_blood_grenade",
	"item_crystal_maiden_outfit",
	"item_aether_lens",
	"item_glimmer_cape",
	"item_blink",
	"item_guardian_greaves",
	"item_aghanims_shard",
	"item_cyclone",
	"item_shivas_guard",
	"item_sheepstick",
	"item_moon_shard",
	"item_ultimate_scepter_2",
}
sRoleItemsBuyList["pos_3"] = sRoleItemsBuyList["pos_1"]
X["sBuyList"] = sRoleItemsBuyList[sRole]
X["sSellList"] = { "item_black_king_bar", "item_quelling_blade", "item_shivas_guard", "item_glimmer_cape" }
if Fu.Role.IsPvNMode() or Fu.Role.IsAllShadow() then
	X["sBuyList"], X["sSellList"] = { "PvN_mage" }, {}
end
nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"] = Fu.SetUserHeroInit(nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"])
X["sSkillList"] = Fu.Skill.GetSkillList(sAbilityList, nAbilityBuildList, sTalentList, nTalentBuildList)
X["bDeafaultAbility"] = true
X["bDeafaultItem"] = true
function X.MinionThink(minionUnit)
	Minion.MinionThink(minionUnit)
end
local fortunesEndAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[1]), "sAbilityList[1]", "oracle")
local fatesEdictAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[2]), "sAbilityList[2]", "oracle")
local purifyingFlamesAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[3]), "sAbilityList[3]", "oracle")
local falsePromiseAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[6]), "sAbilityList[6]", "oracle")
local talent3 = SafeAbility(bot:GetAbilityByName(sTalentList[3]), "sTalentList[3]", "oracle")
-- datafeed: Rain of Destiny is the Shard ability "oracle_rain_of_destiny" (hidden + not learnable,
-- so GetAbilityList skips it and sAbilityList[4] can be the innate Prognosticate). Fetch it by name.
local rainOfDestinyAbility = SafeAbility(bot:GetAbilityByName("oracle_rain_of_destiny"), "oracle_rain_of_destiny", "oracle")
local fortunesEndDesire, fortunesEndTarget
local fatesEdictDesire, fatesEdictTarget
local purifyingFlamesDesire, purifyingFlamesTarget
local falsePromiseDesire, falsePromiseTarget
local rainOfDestinyDesire, rainOfDestinyLocation
local aetherRange = 0
local hpRatio, nearbyEnemies, nearbyAllies
function X.SkillsComplement()
	if Fu.CanNotUseAbility(bot) or bot:IsInvisible() then
		return
	end
	local context = AbilityContext.Build(bot)
	aetherRange = context.aetherRange
	hpRatio = context.hp
	botTarget = context.target
	nearbyEnemies = context.enemies
	nearbyAllies = context.allies
	falsePromiseDesire, falsePromiseTarget = X.ConsiderR()
	if falsePromiseDesire > 0 then
		Fu.SetQueuePtToINT(bot, true)
		bot:ActionQueue_UseAbilityOnEntity(falsePromiseAbility, falsePromiseTarget)
		return
	end
	purifyingFlamesDesire, purifyingFlamesTarget = X.ConsiderE()
	if purifyingFlamesDesire > 0 then
		Fu.SetQueuePtToINT(bot, true)
		bot:ActionQueue_UseAbilityOnEntity(purifyingFlamesAbility, purifyingFlamesTarget)
		return
	end
	fatesEdictDesire, fatesEdictTarget = X.ConsiderW()
	if fatesEdictDesire > 0 then
		Fu.SetQueuePtToINT(bot, false)
		bot:ActionQueue_UseAbilityOnEntity(fatesEdictAbility, fatesEdictTarget)
		return
	end
	fortunesEndDesire, fortunesEndTarget = X.ConsiderQ()
	if fortunesEndDesire > 0 then
		Fu.SetQueuePtToINT(bot, true)
		bot:ActionQueue_UseAbilityOnEntity(fortunesEndAbility, fortunesEndTarget)
		-- Purifying Flames after it on an enemy only: on an ally just dispelled it would be damage.
		if purifyingFlamesAbility:IsFullyCastable() and fortunesEndTarget ~= nil and fortunesEndTarget.GetTeam ~= nil and fortunesEndTarget:GetTeam() ~= GetTeam() then
			bot:ActionQueue_UseAbilityOnEntity(purifyingFlamesAbility, fortunesEndTarget)
		end
		return
	end
	rainOfDestinyDesire, rainOfDestinyLocation = X.ConsiderD()
	if rainOfDestinyDesire > 0 then
		Fu.SetQueuePtToINT(bot, true)
		bot:ActionQueue_UseAbilityOnLocation(rainOfDestinyAbility, rainOfDestinyLocation)
		return
	end
end
function X.ConsiderD()
	if not rainOfDestinyAbility:IsTrained() or not rainOfDestinyAbility:IsFullyCastable() then
		return 0
	end
	local abilityLevel = rainOfDestinyAbility:GetLevel()
	local castRange = 650 + aetherRange
	local castPoint = rainOfDestinyAbility:GetCastPoint()
	local manaCost = rainOfDestinyAbility:GetManaCost()
	local damage = rainOfDestinyAbility:GetAbilityDamage()
	local damageType = DAMAGE_TYPE_MAGICAL
	local radius = 650
	-- Heal (datafeed: allies in the rain heal and take more healing): in a fight, 2+ allied heroes under
	-- 70% HP within 300 of a spot in range.
	if Fu.IsInTeamFight(bot, 1200) then
		for _, ally in pairs(nearbyAllies or {}) do
			if Fu.IsValidHero(ally) and Fu.GetHP(ally) < 0.7 and Fu.IsInRange(bot, ally, castRange) then
				local hurt = 0
				for _, other in pairs(Fu.GetAlliesNearLoc(ally:GetLocation(), 300) or {}) do
					if Fu.IsValidHero(other) and Fu.GetHP(other) < 0.7 then
						hurt = hurt + 1
					end
				end
				if hurt >= 2 then
					pcall(print, string.format("[OHA-ORACLE] t=%.0f rain-heal allies=%d", DotaTime(), hurt))
					return BOT_ACTION_DESIRE_HIGH, ally:GetLocation(), "D-Heal"
				end
			end
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidHero(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and (botTarget:GetAttackTarget() ~= nil or bot:GetAttackTarget() ~= nil)
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation(), "D-Attack" .. Fu.Chat.GetNormName(botTarget)
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderQ()
	if not fortunesEndAbility:IsFullyCastable() then
		return 0
	end
	local abilityLevel = fortunesEndAbility:GetLevel()
	local castRange = fortunesEndAbility:GetCastRange() + aetherRange
	local castPoint = fortunesEndAbility:GetCastPoint()
	local manaCost = fortunesEndAbility:GetManaCost()
	local damage = fortunesEndAbility:GetAbilityDamage()
	local damageType = DAMAGE_TYPE_MAGICAL
	local radius = 300
	local enemiesInRange = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	-- Save (datafeed: on an ally it only dispels debuffs): an ally in range who is rooted or silenced
	-- with an enemy hero within 900 of him.
	for _, ally in pairs(nearbyAllies or {}) do
		if
			Fu.IsValidHero(ally)
			and not ally:IsIllusion()
			and Fu.IsInRange(bot, ally, castRange)
			and (ally:IsRooted() or ally:IsSilenced())
			and not ally:IsMagicImmune()
			and #(Fu.GetEnemiesNearLoc(ally:GetLocation(), 900) or {}) >= 1
		then
			pcall(print, string.format("[OHA-ORACLE] t=%.0f fortunes_end-dispel ally=%s", DotaTime(), (string.gsub(ally:GetUnitName(), "npc_dota_hero_", ""))))
			return BOT_ACTION_DESIRE_HIGH, ally, "Q-Dispel" .. Fu.Chat.GetNormName(ally)
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if Fu.IsValidHero(botTarget) and Fu.IsInRange(bot, botTarget, castRange) and Fu.CanCastOnNonMagicImmune(botTarget) then
			return BOT_ACTION_DESIRE_HIGH, botTarget, "Q-Attack" .. Fu.Chat.GetNormName(botTarget)
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderW()
	if not fatesEdictAbility:IsFullyCastable() then
		return 0
	end
	local abilityLevel = fatesEdictAbility:GetLevel()
	local castRange = fatesEdictAbility:GetCastRange() + aetherRange
	local castPoint = fatesEdictAbility:GetCastPoint()
	local manaCost = fatesEdictAbility:GetManaCost()
	local damage = fatesEdictAbility:GetAbilityDamage()
	local damageType = DAMAGE_TYPE_MAGICAL
	local enemiesInRange = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	-- Save: a hurt ally (under 60% HP, hit by a hero in the last 2s) with an enemy spell projectile
	-- on its way gets Fate's Edict (100% magic resistance, datafeed); Purifying Flames then heals him
	-- (ConsiderE's Edict rule).
	for _, ally in pairs(nearbyAllies or {}) do
		if
			Fu.IsValidHero(ally)
			and not ally:IsIllusion()
			and Fu.IsInRange(bot, ally, castRange)
			and Fu.GetHP(ally) < 0.6
			and ally:WasRecentlyDamagedByAnyHero(2.0)
			and Fu.IsNotAttackProjectileIncoming(ally, 900)
			and not ally:IsMagicImmune()
			and not ally:HasModifier("modifier_oracle_fates_edict")
		then
			pcall(print, string.format("[OHA-ORACLE] t=%.0f edict-save ally=%s hp=%.2f", DotaTime(), (string.gsub(ally:GetUnitName(), "npc_dota_hero_", "")), Fu.GetHP(ally)))
			return BOT_ACTION_DESIRE_HIGH, ally, "W-Save" .. Fu.Chat.GetNormName(ally)
		end
	end
	if Fu.IsInTeamFight(bot, 900) and #nearbyEnemies >= 3 then
		local mostDangerousEnemy = nil
		local maxDamageToBot = 0
		for _, enemyHero in pairs(enemiesInRange) do
			if
				Fu.IsValid(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
				and not Fu.IsDisabled(enemyHero)
				and not enemyHero:IsDisarmed()
			then
				local damageToBot = enemyHero:GetEstimatedDamageToTarget(false, bot, 3.0, DAMAGE_TYPE_PHYSICAL)
				if damageToBot > maxDamageToBot then
					maxDamageToBot = damageToBot
					mostDangerousEnemy = enemyHero
				end
			end
		end
		if mostDangerousEnemy ~= nil then
			return BOT_ACTION_DESIRE_HIGH, mostDangerousEnemy, "W-Battle" .. Fu.Chat.GetNormName(mostDangerousEnemy)
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		-- Fate's Edict gives its target 100% magic resistance (datafeed), which blocks Oracle's own
		-- Fortune's End and Purifying Flames and the team's magic burst on the hero being killed. Only on
		-- that target while it is hitting one of our heroes and still above 50% HP; "attacking anything"
		-- used to be enough.
		local hitting = Fu.IsValidHero(botTarget) and botTarget:GetAttackTarget() or nil
		if
			Fu.IsValidHero(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsValidHero(hitting)
			and hitting:GetTeam() == GetTeam()
			and Fu.GetHP(botTarget) > 0.5
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget, "W-Attack" .. Fu.Chat.GetNormName(botTarget)
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderE()
	if not purifyingFlamesAbility:IsFullyCastable() then
		return 0
	end
	local abilityLevel = purifyingFlamesAbility:GetLevel()
	local castRange = purifyingFlamesAbility:GetCastRange() + aetherRange
	if castRange >= 1500 then
		castRange = 1500
	end
	local castPoint = purifyingFlamesAbility:GetCastPoint()
	local manaCost = purifyingFlamesAbility:GetManaCost()
	local damage = purifyingFlamesAbility:GetSpecialValueInt("damage")
	local damageType = DAMAGE_TYPE_MAGICAL
	local enemiesInRange = Fu.GetNearbyHeroes(bot, castRange + 50, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(enemiesInRange) do
		if Fu.IsValidHero(enemyHero) and Fu.CanCastOnNonMagicImmune(enemyHero) and Fu.WillMagicKillTarget(bot, enemyHero, damage, castPoint) then
			return BOT_ACTION_DESIRE_HIGH, enemyHero, "E-击杀" .. Fu.Chat.GetNormName(enemyHero)
		end
	end
	for _, allyHero in pairs(nearbyAllies) do
		if Fu.IsValidHero(allyHero) and Fu.IsInRange(bot, allyHero, castRange) and Fu.CanCastOnNonMagicImmune(allyHero) then
			if
				allyHero:GetMagicResist() > 0.42
				and Fu.GetHP(allyHero) < 0.8
				and (#nearbyEnemies == 0 or allyHero:GetHealth() > 999)
				and Fu.GetUniqueModifierCount(bot, "modifier_oracle_purifying_flames") < 3
			then
				return BOT_ACTION_DESIRE_HIGH, allyHero, "E-治疗" .. Fu.Chat.GetNormName(allyHero)
			end
		end
		if
			allyHero:HasModifier("modifier_oracle_false_promise_timer")
			and Fu.GetModifierTime(allyHero, "modifier_oracle_false_promise_timer") > 3.8
			and Fu.IsInRange(bot, allyHero, castRange)
		then
			return BOT_ACTION_DESIRE_HIGH, allyHero, "E-支援抢救" .. Fu.Chat.GetNormName(allyHero)
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidHero(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange + 50)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and botTarget:GetMagicResist() < 0.6
		then
			local projectiles = botTarget:GetIncomingTrackingProjectiles()
			for _, projectile in pairs(projectiles) do
				if
					not projectile.is_attack
					and projectile.ability ~= nil
					and projectile.ability:GetName() == "oracle_fortunes_end"
					and GetUnitToLocationDistance(botTarget, projectile.location) > 330
				then
					return BOT_ACTION_DESIRE_HIGH, botTarget, "E-弹道前进攻" .. Fu.Chat.GetNormName(botTarget)
				end
			end
			if Fu.WillMagicKillTarget(bot, botTarget, damage * 1.6, castPoint) then
				local alliesNearTarget = Fu.GetAlliesNearLoc(botTarget:GetLocation(), 550)
				if #alliesNearTarget >= 3 then
					return BOT_ACTION_DESIRE_HIGH, botTarget, "E-击杀前进攻" .. Fu.Chat.GetNormName(botTarget)
				end
			end
		end
	end
	if (Fu.IsPushing(bot) or Fu.IsDefending(bot) or Fu.IsFarming(bot)) and #nearbyAllies <= 2 and abilityLevel >= 3 and Fu.IsAllowedToSpam(bot, 30) then
		local laneCreeps = bot:GetNearbyLaneCreeps(castRange + 350, true)
		for _, creep in pairs(laneCreeps) do
			if
				Fu.IsValid(creep)
				and not creep:HasModifier("modifier_fountain_glyph")
				and creep:GetHealth() > damage * 0.6
				and not Fu.IsOtherAllysTarget(creep)
			then
				if Fu.IsKeyWordUnit("ranged", creep) and Fu.WillKillTarget(creep, damage, damageType, castPoint) then
					return BOT_ACTION_DESIRE_HIGH, creep, "E-补刀远程兵"
				end
				if
					bot:GetMana() > falsePromiseAbility:GetManaCost() * 2
					and abilityLevel >= 4
					and Fu.IsKeyWordUnit("melee", creep)
					and creep:GetHealth() > damage * 0.7
					and Fu.WillKillTarget(creep, damage, damageType, castPoint)
				then
					return BOT_ACTION_DESIRE_HIGH, creep, "E-补刀近战兵"
				end
			end
		end
		if #nearbyAllies <= 1 then
			local neutralCreeps = bot:GetNearbyNeutralCreeps(castRange + 150)
			for _, creep in pairs(neutralCreeps) do
				if Fu.IsValid(creep) and creep:GetHealth() > damage * 0.45 and Fu.WillKillTarget(creep, damage, damageType, castRange) then
					return BOT_ACTION_DESIRE_HIGH, creep, "E-补刀野怪"
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderR()
	if not falsePromiseAbility:IsFullyCastable() then
		return 0
	end
	local abilityLevel = falsePromiseAbility:GetLevel()
	local castRange = falsePromiseAbility:GetCastRange() + aetherRange
	local castPoint = falsePromiseAbility:GetCastPoint()
	local manaCost = falsePromiseAbility:GetManaCost()
	local damage = falsePromiseAbility:GetAbilityDamage()
	local damageType = DAMAGE_TYPE_MAGICAL
	local enemiesInRange = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	for _, allyHero in pairs(nearbyAllies) do
		if Fu.IsInRange(bot, allyHero, castRange + 50) and allyHero:WasRecentlyDamagedByAnyHero(2.0) and Fu.GetHP(allyHero) < 0.55 then
			if Fu.IsRetreating(allyHero) and (allyHero ~= bot or hpRatio < 0.25) then
				return BOT_ACTION_DESIRE_HIGH, allyHero, "R-protect" .. Fu.Chat.GetNormName(allyHero)
			end
			if Fu.IsGoingOnSomeone(allyHero) and Fu.GetHP(allyHero) < 0.3 then
				local allyTarget = Fu.GetProperTarget(allyHero)
				if Fu.IsValidHero(allyTarget) and Fu.IsInRange(allyHero, allyTarget, 600) then
					return BOT_ACTION_DESIRE_HIGH, allyHero, "R-support" .. Fu.Chat.GetNormName(allyHero)
				end
			end
			if
				not allyHero:IsBot()
				and Fu.GetHP(allyHero) <= 0.6
				and allyHero:GetAttackTarget() ~= nil
				and allyHero:GetAttackTarget():IsHero()
				and allyHero:WasRecentlyDamagedByAnyHero(2.0)
				and #nearbyEnemies >= 2
				and (Fu.IsGoingOnSomeone(bot) or Fu.IsGoingOnSomeone(allyHero))
			then
				return BOT_ACTION_DESIRE_HIGH, allyHero, "R-ally" .. Fu.Chat.GetNormName(allyHero)
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
return X
