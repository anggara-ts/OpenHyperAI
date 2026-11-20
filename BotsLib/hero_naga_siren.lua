-- Naga Siren: skill build, item build, and ability use for this hero.
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
local tTalentTreeList = { ["t25"] = { 0, 10 }, ["t20"] = { 10, 0 }, ["t15"] = { 0, 10 }, ["t10"] = { 10, 0 } }
local tAllAbilityBuildList = { { 1, 3, 2, 1, 1, 3, 1, 3, 3, 6, 6, 2, 2, 2, 6 } }
local nAbilityBuildList = Fu.Skill.GetRandomBuild(tAllAbilityBuildList)
local nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList)
local sRoleItemsBuyList = {}
-- Stratz 7.41f, week of 9 Nov 2026: pos 1, 17,827 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_1"] = {
	"item_tango",
	"item_double_branches",
	"item_quelling_blade",
	"item_circlet",
	"item_slippers",
	"item_wraith_band",
	"item_magic_wand",
	"item_power_treads",
	"item_manta",
	"item_orchid",
	"item_heart",
	"item_bloodthorn",
	"item_skadi",
	"item_blink",
	"item_travel_boots",
	"item_swift_blink",
	"item_aghanims_shard",
	"item_ultimate_scepter_2",
	"item_moon_shard",
	"item_travel_boots_2",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 2 has 869 matches, built from pos 1 (17,827) (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_2"] = sRoleItemsBuyList["pos_1"]
sRoleItemsBuyList["pos_4"] = sRoleItemsBuyList["pos_1"]
sRoleItemsBuyList["pos_5"] = sRoleItemsBuyList["pos_1"]
-- Stratz 7.41f, week of 9 Nov 2026: pos 3, 1,144 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_3"] = {
	"item_tango",
	"item_quelling_blade",
	"item_circlet",
	"item_double_branches",
	"item_slippers",
	"item_wraith_band",
	"item_magic_wand",
	"item_power_treads",
	"item_oblivion_staff",
	"item_manta",
	"item_orchid",
	"item_heart",
	"item_skadi",
	"item_ultimate_scepter",
	"item_moon_shard",
	"item_ultimate_scepter_2",
	"item_diffusal_blade",
	"item_disperser",
	"item_aghanims_shard",
}
X["sBuyList"] = sRoleItemsBuyList[sRole]
X["sSellList"] = { "item_black_king_bar", "item_quelling_blade" }
if Fu.Role.IsPvNMode() or Fu.Role.IsAllShadow() then
	X["sBuyList"], X["sSellList"] = { "PvN_PL" }, { "item_manta", "item_quelling_blade" }
end
nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"] =
	Fu.SetUserHeroInit(nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"])
X["sSkillList"] = Fu.Skill.GetSkillList(sAbilityList, nAbilityBuildList, sTalentList, nTalentBuildList)
X["bDeafaultAbility"] = false
X["bDeafaultItem"] = false
function X.MinionThink(minion)
	if Minion.IsValidUnit(minion) then
		if minion:IsIllusion() then
			minion.isIllusion = true
		end
		Minion.IllusionThink(minion)
	end
end
local mirrorImageAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[1]), "sAbilityList[1]", "naga_siren")
local ensnareAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[2]), "sAbilityList[2]", "naga_siren")
local riptideAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[3]), "sAbilityList[3]", "naga_siren")
local songOfTheSirenAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[6]), "sAbilityList[6]", "naga_siren")
local songCancelAbility = SafeAbility(
	bot:GetAbilityByName("naga_siren_song_of_the_siren_cancel"),
	"naga_siren_song_of_the_siren_cancel",
	"naga_siren"
)
local reelInAbility = SafeAbility(bot:GetAbilityByName("naga_siren_reel_in"), "naga_siren_reel_in", "naga_siren")
local mirrorImageDesire, mirrorImageTarget
local ensnareDesire, ensnareTarget
local riptideDesire, riptideTarget
local songDesire, songTarget
local songCancelDesire, songCancelTarget
local reelInDesire
local aetherRange = 0
local mpRatio, nearbyEnemies
function X.SkillsComplement()
	if Fu.CanNotUseAbility(bot) or bot:IsInvisible() then
		return
	end
	local context = AbilityContext.Build(bot)
	aetherRange = context.aetherRange
	mpRatio = context.mp
	botTarget = context.target
	nearbyEnemies = context.enemies
	mirrorImageDesire = X.ConsiderQ()
	ensnareDesire, ensnareTarget = X.ConsiderW()
	songDesire = X.ConsiderR()
	songCancelDesire = X.ConsiderSR()
	if mirrorImageDesire > 0 then
		bot:Action_ClearActions(false)
		bot:Action_UseAbility(mirrorImageAbility)
		return
	end
	if ensnareDesire > 0 then
		Fu.SetQueuePtToINT(bot, true)
		bot:ActionQueue_UseAbilityOnEntity(ensnareAbility, ensnareTarget)
		return
	end
	reelInDesire = X.ConsiderReelIn()
	if reelInDesire > 0 then
		Fu.SetQueuePtToINT(bot, true)
		bot:Action_UseAbility(reelInAbility)
		return
	end
	if songDesire > 0 then
		Fu.SetQueuePtToINT(bot, true)
		bot:ActionQueue_UseAbility(songOfTheSirenAbility)
		return
	end
	if songCancelDesire > 0 then
		bot:Action_UseAbility(songCancelAbility)
		return
	end
end
function X.ConsiderQ()
	if not mirrorImageAbility:IsFullyCastable() then
		return 0
	end
	local abilityLevel = mirrorImageAbility:GetLevel()
	local castRange = mirrorImageAbility:GetCastRange()
	local castPoint = mirrorImageAbility:GetCastPoint()
	local manaCost = mirrorImageAbility:GetManaCost()
	local damage = mirrorImageAbility:GetAbilityDamage()
	local damageType = DAMAGE_TYPE_MAGICAL
	local closeEnemies = Fu.GetAroundEnemyHeroList(800)
	local enemiesInFightRange = Fu.GetAroundEnemyHeroList(1200)
	local castTarget = nil
	local castReason = nil
	if Fu.IsInTeamFight(bot, 1000) then
		if #enemiesInFightRange >= 2 then
			castTarget = enemiesInFightRange[1]
			castReason = "Q-团战" .. Fu.Chat.GetNormName(castTarget)
			return BOT_ACTION_DESIRE_HIGH, castTarget, castReason
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if Fu.IsValidHero(botTarget) and Fu.IsInRange(bot, botTarget, 700) then
			castTarget = botTarget
			castReason = "Q-攻击:" .. Fu.Chat.GetNormName(castTarget)
			return BOT_ACTION_DESIRE_HIGH, castTarget, castReason
		end
	end
	if Fu.IsLaning(bot) then
		local attackTarget = bot:GetAttackTarget()
		if Fu.IsValidHero(attackTarget) and Fu.IsInRange(bot, attackTarget, 600) then
			castTarget = attackTarget
			castReason = "Q-对线"
			return BOT_ACTION_DESIRE_HIGH, castTarget, castReason
		end
		if bot:WasRecentlyDamagedByAnyHero(1.0) and #closeEnemies >= 1 and mpRatio > 0.4 then
			castTarget = bot
			castReason = "Q-对线防御伤害"
			return BOT_ACTION_DESIRE_HIGH, castTarget, castReason
		end
	end
	if Fu.IsFarming(bot) then
		local attackTarget = bot:GetAttackTarget()
		if
			Fu.IsValid(attackTarget)
			and not attackTarget:HasModifier("modifier_fountain_glyph")
			and Fu.IsInRange(bot, attackTarget, 500)
		then
			return BOT_ACTION_DESIRE_HIGH, attackTarget, "Q-打钱"
		end
	end
	if Fu.IsPushing(bot) or Fu.IsDefending(bot) or Fu.IsFarming(bot) then
		local laneCreeps = bot:GetNearbyLaneCreeps(800, true)
		local nearbyTowers = bot:GetNearbyTowers(800, true)
		local nearbyBarracks = bot:GetNearbyBarracks(800, true)
		if #laneCreeps >= 1 or #nearbyTowers >= 1 or #nearbyBarracks >= 1 then
			if botTarget ~= nil then
				castTarget = botTarget
				castReason = "Q-推线推塔"
				return BOT_ACTION_DESIRE_HIGH, castTarget, castReason
			end
		end
		local attackTarget = bot:GetAttackTarget()
		if Fu.IsValidBuilding(attackTarget) and attackTarget:GetTeam() ~= bot:GetTeam() then
			castTarget = attackTarget
			castReason = "Q-拆建筑"
			return BOT_ACTION_DESIRE_HIGH, castTarget, castReason
		end
	end
	if Fu.IsRetreating(bot) and #closeEnemies >= 1 then
		for _, enemyHero in pairs(closeEnemies) do
			if Fu.IsValid(enemyHero) and Fu.CanCastOnMagicImmune(enemyHero) then
				castTarget = enemyHero
				castReason = "Q-撤退时掩护" .. Fu.Chat.GetNormName(castTarget)
				return BOT_ACTION_DESIRE_HIGH, castTarget, castReason
			end
		end
	end
	if abilityLevel >= 4 and Fu.IsAllowedToSpam(bot, 80) then
		local nearbyCreeps = bot:GetNearbyCreeps(1600, true)
		local nearbyTowers = bot:GetNearbyTowers(1600, true)
		if #nearbyCreeps >= 1 or #nearbyTowers >= 1 or #nearbyEnemies >= 1 then
			castTarget = bot
			castReason = "Q-通用的情况"
			return BOT_ACTION_DESIRE_HIGH, castTarget, castReason
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if
			Fu.IsRoshan(botTarget)
			and Fu.IsInRange(botTarget, bot, 800)
			and Fu.CanBeAttacked(botTarget)
			and Fu.IsAttacking(bot)
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(botTarget, bot, 800) and Fu.IsAttacking(bot) then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderW()
	if not ensnareAbility:IsFullyCastable() then
		return 0
	end
	local abilityLevel = ensnareAbility:GetLevel()
	local castRange = ensnareAbility:GetCastRange() + aetherRange
	local castPoint = ensnareAbility:GetCastPoint()
	local manaCost = ensnareAbility:GetManaCost()
	local damage = ensnareAbility:GetAbilityDamage()
	local damageType = DAMAGE_TYPE_MAGICAL
	local nearbyEnemies = Fu.GetAroundEnemyHeroList(castRange)
	local enemiesInExtendedRange = Fu.GetAroundEnemyHeroList(castRange + 200)
	local castTarget = nil
	local castReason = nil
	for _, enemyHero in pairs(enemiesInExtendedRange) do
		if
			Fu.IsValid(enemyHero)
			and (Fu.CanCastOnNonMagicImmune(enemyHero) or Fu.CanCastOnMagicImmune(enemyHero) and bot:HasScepter())
			-- Any channel, not only a TP: Ensnare "interrupts the target" (datafeed), so a channeled
			-- ultimate is stopped too.
			and enemyHero:IsChanneling()
		then
			if DotaTime() >= (bot._nagaNetLogAt or -999) then
				bot._nagaNetLogAt = DotaTime() + 3
				pcall(
					print,
					string.format(
						"[OHA-NAGA] t=%.0f ensnare-interrupt target=%s tp=%s",
						DotaTime(),
						(string.gsub(enemyHero:GetUnitName(), "npc_dota_hero_", "")),
						tostring(enemyHero:HasModifier("modifier_teleporting"))
					)
				)
			end
			castTarget = enemyHero
			castReason = "W-打断TP:" .. Fu.Chat.GetNormName(enemyHero)
			return BOT_ACTION_DESIRE_HIGH, castTarget, castReason
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidHero(botTarget)
			and Fu.IsInRange(botTarget, bot, castRange)
			and (Fu.CanCastOnNonMagicImmune(botTarget) or Fu.CanCastOnMagicImmune(botTarget) and bot:HasScepter())
			and Fu.CanCastOnTargetAdvanced(botTarget)
			and not Fu.IsDisabled(botTarget)
			and Fu.IsRunning(botTarget)
			and bot:IsFacingLocation(botTarget:GetLocation(), 20)
			and not botTarget:IsFacingLocation(bot:GetLocation(), 140)
		then
			castTarget = botTarget
			castReason = "W-攻击" .. Fu.Chat.GetNormName(castTarget)
			return BOT_ACTION_DESIRE_HIGH, castTarget, castReason
		end
		for _, enemyHero in pairs(nearbyEnemies) do
			if Fu.IsValid(enemyHero) then
				if
					enemyHero:HasModifier("modifier_item_glimmer_cape")
					or enemyHero:HasModifier("modifier_invisible")
					or enemyHero:HasModifier("modifier_item_shadow_amulet_fade")
				then
					if
						(
							Fu.CanCastOnNonMagicImmune(enemyHero)
							or Fu.CanCastOnMagicImmune(enemyHero) and bot:HasScepter()
						)
						and Fu.CanCastOnTargetAdvanced(enemyHero)
						and not enemyHero:HasModifier("modifier_item_dustofappearance")
						and not enemyHero:HasModifier("modifier_slardar_amplify_damage")
						and not enemyHero:HasModifier("modifier_bloodseeker_thirst_vision")
						and not enemyHero:HasModifier("modifier_sniper_assassinate")
						and not enemyHero:HasModifier("modifier_bounty_hunter_track")
					then
						castTarget = enemyHero
						castReason = "W-显隐" .. Fu.Chat.GetNormName(castTarget)
						return BOT_ACTION_DESIRE_HIGH, castTarget, castReason
					end
				end
			end
		end
	end
	if Fu.IsRetreating(bot) and bot:WasRecentlyDamagedByAnyHero(5.0) then
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValid(enemyHero)
				and (Fu.CanCastOnNonMagicImmune(enemyHero) or Fu.CanCastOnMagicImmune(enemyHero) and bot:HasScepter())
				and Fu.CanCastOnTargetAdvanced(enemyHero)
				and not Fu.IsDisabled(enemyHero)
				and not enemyHero:IsDisarmed()
				and enemyHero:IsFacingLocation(bot:GetLocation(), 30)
			then
				castTarget = enemyHero
				castReason = "W-撤退" .. Fu.Chat.GetNormName(castTarget)
				return BOT_ACTION_DESIRE_HIGH, castTarget, castReason
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderR()
	if not songOfTheSirenAbility:IsFullyCastable() then
		return 0
	end
	local abilityLevel = songOfTheSirenAbility:GetLevel()
	local radius = songOfTheSirenAbility:GetSpecialValueInt("radius")
	local castRange = radius
	local castPoint = songOfTheSirenAbility:GetCastPoint()
	local manaCost = songOfTheSirenAbility:GetManaCost()
	local damage = 0
	local damageType = DAMAGE_TYPE_MAGICAL
	local nearbyEnemies = Fu.GetAroundEnemyHeroList(radius - 200)
	local enemiesInRadius = Fu.GetAroundEnemyHeroList(radius)
	local castTarget = nil
	local castReason = nil
	-- Team save: in a fight, 2+ enemy heroes inside the Song radius and an allied hero (Naga too) under
	-- 30% HP who was just hit. Song puts every enemy in range in a stasis where they cannot act or be
	-- attacked (datafeed); it was only cast to ambush or to escape alone.
	if Fu.IsInTeamFight(bot, 1200) then
		local foes = 0
		for _, enemyHero in pairs(Fu.GetNearbyHeroes(bot, radius - 50, true, BOT_MODE_NONE) or {}) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and not Fu.IsSuspiciousIllusion(enemyHero)
			then
				foes = foes + 1
			end
		end
		if foes >= 2 then
			for _, ally in pairs(Fu.GetNearbyHeroes(bot, radius - 50, false, BOT_MODE_NONE) or {}) do
				if
					Fu.IsValidHero(ally)
					and not ally:IsIllusion()
					and Fu.GetHP(ally) < 0.3
					and ally:WasRecentlyDamagedByAnyHero(2.0)
				then
					if DotaTime() >= (bot._nagaSongLogAt or -999) then
						bot._nagaSongLogAt = DotaTime() + 3
						pcall(
							print,
							string.format(
								"[OHA-NAGA] t=%.0f song-save ally=%s hp=%.2f foes=%d",
								DotaTime(),
								(string.gsub(ally:GetUnitName(), "npc_dota_hero_", "")),
								Fu.GetHP(ally),
								foes
							)
						)
					end
					return BOT_ACTION_DESIRE_HIGH, ally, "R-save"
				end
			end
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		-- The target must be inside the Song radius (900/1150/1400, game data): it took 800-1400 at
		-- every level, so at level 1-2 the target could stand outside the Song it was cast for.
		if
			Fu.IsValidHero(botTarget)
			and Fu.IsInRange(bot, botTarget, math.min(1400, radius - 50))
			and not Fu.IsInRange(bot, botTarget, 800)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and not botTarget:WasRecentlyDamagedByAnyHero(3.0)
			and bot:IsFacingLocation(botTarget:GetLocation(), 20)
		then
			local alliesNearTarget = Fu.GetNearbyHeroes(botTarget, 700, true, BOT_MODE_NONE)
			if #alliesNearTarget == 0 then
				castTarget = botTarget
				castReason = "R-伏击:" .. Fu.Chat.GetNormName(castTarget)
				return BOT_ACTION_DESIRE_HIGH, castTarget, castReason
			end
		end
	end
	if Fu.IsRetreating(bot) and bot:WasRecentlyDamagedByAnyHero(3.0) then
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValid(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and not Fu.IsDisabled(enemyHero)
				and not enemyHero:IsDisarmed()
			then
				castTarget = enemyHero
				castReason = "R-撤退" .. Fu.Chat.GetNormName(castTarget)
				return BOT_ACTION_DESIRE_HIGH, castTarget, castReason
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderSR()
	if songCancelAbility:IsHidden() or not songCancelAbility:IsTrained() or not songCancelAbility:IsFullyCastable() then
		return 0
	end
	if Fu.IsGoingOnSomeone(bot) then
		if Fu.IsValidHero(botTarget) and Fu.IsInRange(bot, botTarget, 300) then
			local alliesNearTarget = Fu.GetNearbyHeroes(botTarget, 300, true, BOT_MODE_NONE)
			if alliesNearTarget ~= nil and #alliesNearTarget >= 3 then
				return BOT_ACTION_DESIRE_HIGH, botTarget, "SR-停止大招"
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderReelIn()
	if not bot:HasScepter() or not reelInAbility:IsFullyCastable() or Fu.IsInTeamFight(bot, 1400) then
		return BOT_ACTION_DESIRE_NONE
	end
	local searchRange = 1400
	local nearbyAllies = Fu.GetNearbyHeroes(bot, searchRange, false, BOT_MODE_NONE)
	local nearbyEnemies = Fu.GetNearbyHeroes(bot, searchRange, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.IsInRange(bot, enemyHero, searchRange)
			and not Fu.IsInRange(bot, enemyHero, bot:GetAttackRange() * 2)
			and enemyHero:HasModifier("modifier_naga_siren_ensnare")
			and #nearbyAllies >= #nearbyEnemies
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidHero(botTarget)
			and Fu.IsInRange(bot, botTarget, searchRange)
			and not Fu.IsInRange(bot, botTarget, bot:GetAttackRange() * 2)
			and bot:IsFacingLocation(botTarget:GetLocation(), 30)
			and botTarget:HasModifier("modifier_naga_siren_ensnare")
			and #nearbyAllies >= #nearbyEnemies
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
return X
