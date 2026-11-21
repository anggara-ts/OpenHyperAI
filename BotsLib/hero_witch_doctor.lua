-- Witch Doctor: skill build, item build, and ability use for this hero.
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
local tTalentTreeList = { ["t25"] = { 10, 0 }, ["t20"] = { 0, 10 }, ["t15"] = { 0, 10 }, ["t10"] = { 10, 0 } }
local tAllAbilityBuildList = { { 1, 3, 3, 1, 3, 6, 3, 1, 1, 2, 6, 2, 2, 2, 6 } }
local nAbilityBuildList = Fu.Skill.GetRandomBuild(tAllAbilityBuildList)
local nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList)
local sRoleItemsBuyList = {}
-- Stratz 7.41f, week of 9 Nov 2026: pos 4, 112,713 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_4"] = {
	"item_tango",
	"item_blood_grenade",
	"item_magic_stick",
	"item_double_branches",
	"item_enchanted_mango",
	"item_magic_wand",
	"item_urn_of_shadows",
	"item_arcane_boots",
	"item_glimmer_cape",
	"item_aghanims_shard",
	"item_ultimate_scepter",
	"item_aeon_disk",
	"item_ultimate_scepter_2",
	"item_spirit_vessel",
	"item_cyclone",
	"item_wind_waker",
	"item_sheepstick",
	"item_moon_shard",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 5, 250,259 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_5"] = {
	"item_tango",
	"item_blood_grenade",
	"item_magic_stick",
	"item_double_branches",
	"item_enchanted_mango",
	"item_magic_wand",
	"item_urn_of_shadows",
	"item_arcane_boots",
	"item_glimmer_cape",
	"item_aghanims_shard",
	"item_ultimate_scepter",
	"item_aeon_disk",
	"item_ultimate_scepter_2",
	"item_spirit_vessel",
	"item_pipe",
	"item_solar_crest",
	"item_moon_shard",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 3, 1,216 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_3"] = {
	"item_tango",
	"item_blood_grenade",
	"item_branches",
	"item_magic_stick",
	"item_circlet",
	"item_magic_wand",
	"item_arcane_boots",
	"item_blink",
	"item_glimmer_cape",
	"item_aghanims_shard",
	"item_ultimate_scepter",
	"item_black_king_bar",
	"item_travel_boots",
	"item_ultimate_scepter_2",
	"item_spirit_vessel",
	"item_sphere",
	"item_moon_shard",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 1 has 701 matches, built from pos 2 (2,733) (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_1"] = {
	"item_tango",
	"item_blood_grenade",
	"item_branches",
	"item_faerie_fire",
	"item_magic_stick",
	"item_magic_wand",
	"item_arcane_boots",
	"item_blink",
	"item_aghanims_shard",
	"item_glimmer_cape",
	"item_ultimate_scepter",
	"item_black_king_bar",
	"item_ultimate_scepter_2",
	"item_spirit_vessel",
	"item_invis_sword",
	"item_moon_shard",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 2, 2,733 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_2"] = {
	"item_tango",
	"item_blood_grenade",
	"item_branches",
	"item_faerie_fire",
	"item_magic_stick",
	"item_magic_wand",
	"item_arcane_boots",
	"item_blink",
	"item_aghanims_shard",
	"item_glimmer_cape",
	"item_ultimate_scepter",
	"item_black_king_bar",
	"item_ultimate_scepter_2",
	"item_spirit_vessel",
	"item_invis_sword",
	"item_moon_shard",
}
X["sBuyList"] = sRoleItemsBuyList[sRole]
X["sSellList"] = { "item_black_king_bar", "item_quelling_blade" }
if Fu.Role.IsPvNMode() or Fu.Role.IsAllShadow() then
	X["sBuyList"], X["sSellList"] = { "PvN_priest" }, {}
end
nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"] =
	Fu.SetUserHeroInit(nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"])
X["sSkillList"] = Fu.Skill.GetSkillList(sAbilityList, nAbilityBuildList, sTalentList, nTalentBuildList)
X["bDeafaultAbility"] = true
X["bDeafaultItem"] = true
function X.MinionThink(minionUnit)
	if Minion.IsValidUnit(minionUnit) and minionUnit:GetUnitName() ~= "npc_dota_witch_doctor_death_ward" then
		Minion.IllusionThink(minionUnit)
	end
end
local paralyzingCaskAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[1]), "sAbilityList[1]", "witch_doctor")
local voodooRestorationAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[2]), "sAbilityList[2]", "witch_doctor")
local maledictAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[3]), "sAbilityList[3]", "witch_doctor")
-- Shard ability — must not use sAbilityList[4] (can be generic_hidden / wrong slot).
local voodooSwitcherooAbility = SafeAbility(
	bot:GetAbilityByName("witch_doctor_voodoo_switcheroo"),
	"witch_doctor_voodoo_switcheroo",
	"witch_doctor"
)
local deathWardAbility = SafeAbility(
	bot:GetAbilityByName(sAbilityList[6]) or bot:GetAbilityByName("witch_doctor_death_ward"),
	"sAbilityList[6]",
	"witch_doctor"
)
local talent2 = SafeAbility(bot:GetAbilityByName(sTalentList[2]), "sTalentList[2]", "witch_doctor")
local talent6 = SafeAbility(bot:GetAbilityByName(sTalentList[6]), "sTalentList[6]", "witch_doctor")
local caskDesire, caskTarget
local voodooRestorationDesire
local maledictDesire, maledictLocation
local deathWardDesire, deathWardLocation
local switcherooDesire
local aetherRange = 0
local mpRatio, hpRatio, nearbyEnemies, nearbyAllies
-- [OHA-WD] lines: throttled per reason, at most once per 5s.
function X.LogWD(why, fmt, ...)
	bot._wdLogAt = bot._wdLogAt or {}
	if DotaTime() < (bot._wdLogAt[why] or -999) then
		return
	end
	bot._wdLogAt[why] = DotaTime() + 5
	pcall(print, string.format("[OHA-WD] t=%.0f " .. why .. " " .. fmt, DotaTime(), ...))
end
function X.SkillsComplement()
	X.ConsiderCombo()
	if Fu.CanNotUseAbility(bot) or bot:IsInvisible() then
		return
	end
	local context = AbilityContext.Build(bot)
	aetherRange = context.aetherRange
	mpRatio = context.mp
	hpRatio = context.hp
	botTarget = context.target
	nearbyEnemies = context.enemies
	nearbyAllies = context.allies
	switcherooDesire = X.ConsiderAS()
	if
		switcherooDesire > 0
		and voodooSwitcherooAbility ~= nil
		and not voodooSwitcherooAbility:IsHidden()
		and voodooSwitcherooAbility:IsFullyCastable()
	then
		Fu.SetQueuePtToINT(bot, true)
		bot:ActionQueue_UseAbility(voodooSwitcherooAbility)
		return
	end
	maledictDesire, maledictLocation = X.ConsiderE()
	if maledictDesire > 0 then
		Fu.SetQueuePtToINT(bot, true)
		bot:ActionQueue_UseAbilityOnLocation(maledictAbility, maledictLocation)
		return
	end
	caskDesire, caskTarget = X.ConsiderQ()
	if caskDesire > 0 then
		Fu.SetQueuePtToINT(bot, true)
		bot:ActionQueue_UseAbilityOnEntity(paralyzingCaskAbility, caskTarget)
		return
	end
	voodooRestorationDesire = X.ConsiderW()
	if voodooRestorationDesire > 0 then
		bot:ActionQueue_UseAbility(voodooRestorationAbility)
		return
	end
	deathWardDesire, deathWardLocation = X.ConsiderR()
	if deathWardDesire > 0 then
		Fu.SetQueuePtToINT(bot, true)
		bot:ActionQueue_UseAbilityOnLocation(deathWardAbility, deathWardLocation)
		return
	end
end
local lastShadowAmuletTime = -90
function X.ConsiderCombo()
	if bot:IsAlive() and bot:IsChanneling() and not bot:IsInvisible() then
		local enemyTowers = bot:GetNearbyTowers(880, true)
		if enemyTowers[1] ~= nil then
			return
		end
		local shadowAmulet = Fu.IsItemAvailable("item_shadow_amulet")
		if shadowAmulet ~= nil and shadowAmulet:IsFullyCastable() and lastShadowAmuletTime < DotaTime() - 10 then
			lastShadowAmuletTime = DotaTime()
			bot:Action_UseAbilityOnEntity(shadowAmulet, bot)
			return
		end
		if not bot:HasModifier("modifier_teleporting") then
			local glimmerCape = Fu.IsItemAvailable("item_glimmer_cape")
			if glimmerCape ~= nil and glimmerCape:IsFullyCastable() then
				bot:Action_UseAbilityOnEntity(glimmerCape, bot)
				return
			end
			local shadowBlade = Fu.IsItemAvailable("item_invis_sword")
			if shadowBlade ~= nil and shadowBlade:IsFullyCastable() then
				bot:Action_UseAbility(shadowBlade)
				return
			end
			local silverEdge = Fu.IsItemAvailable("item_silver_edge")
			if silverEdge ~= nil and silverEdge:IsFullyCastable() then
				bot:Action_UseAbility(silverEdge)
				return
			end
		end
	end
end
function X.ConsiderQ()
	if not paralyzingCaskAbility:IsFullyCastable() then
		return 0
	end
	local abilityLevel = paralyzingCaskAbility:GetLevel()
	local castRange = paralyzingCaskAbility:GetCastRange() + aetherRange
	local castPoint = paralyzingCaskAbility:GetCastPoint()
	local manaCost = paralyzingCaskAbility:GetManaCost()
	-- datafeed: Cask base_damage is 55/70/85/100 (+20 per bounce); the old 50 + abilityLevel * 25 overrated it.
	local damage = paralyzingCaskAbility:GetSpecialValueInt("base_damage")
	local damageType = DAMAGE_TYPE_MAGICAL
	local enemiesInRange = Fu.GetNearbyHeroes(bot, castRange + 50, true, BOT_MODE_NONE)
	-- datafeed: bounce_range (575) is a Cask value; it was read from Death Ward (deathWardAbility), which has none, so this was 0
	-- and the Q-Aoe / Q-Attack / Q-Retreat group checks never saw anyone.
	local bounceRadius = paralyzingCaskAbility:GetSpecialValueInt("bounce_range") / 2
	for _, enemyHero in pairs(enemiesInRange) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and Fu.CanCastOnTargetAdvanced(enemyHero)
		then
			local hitTime = castPoint + GetUnitToUnitDistance(bot, enemyHero) / 1000
			if Fu.WillMagicKillTarget(bot, enemyHero, damage * 1.6, hitTime) then
				return BOT_ACTION_DESIRE_HIGH, enemyHero, "Q-Kill:" .. Fu.Chat.GetNormName(enemyHero)
			end
			if enemyHero:IsChanneling() then
				return BOT_ACTION_DESIRE_HIGH, enemyHero, "Q-Check:" .. Fu.Chat.GetNormName(enemyHero)
			end
		end
	end
	-- Ally save: game report (1:00, Anti-Mage harassing Pudge next to WD with Cask ready, WD did nothing).
	-- Cask on an enemy hero that is attacking or chasing an ally who is hurt (< 75% HP) or was just hit by it.
	-- datafeed: Cask cast range 600, mana 80/100/120/140, 0.8s hero stun per bounce, bounce_range 575.
	if bot:GetMana() >= manaCost then
		local alliesNearby = Fu.GetNearbyHeroes(bot, 1600, false, BOT_MODE_NONE)
		for _, enemyHero in pairs(enemiesInRange) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.IsInRange(bot, enemyHero, castRange)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
				and not Fu.IsSuspiciousIllusion(enemyHero)
			then
				local enemyAttackTarget = enemyHero:GetAttackTarget()
				for _, allyHero in pairs(alliesNearby) do
					if
						Fu.IsValidHero(allyHero)
						and allyHero ~= bot
						and not allyHero:IsIllusion()
						and allyHero:GetTeam() == bot:GetTeam()
						and ((Fu.IsValid(enemyAttackTarget) and enemyAttackTarget:IsHero() and enemyAttackTarget == allyHero) or (GetUnitToUnitDistance(
							enemyHero,
							allyHero
						) <= 900 and Fu.IsChasingTarget(enemyHero, allyHero)))
						and (Fu.GetHP(allyHero) < 0.75 or allyHero:WasRecentlyDamagedByHero(enemyHero, 2.0))
					then
						pcall(
							print,
							string.format(
								"[OHA-WD] t=%.0f cask-save enemy=%s ally=%s",
								DotaTime(),
								enemyHero:GetUnitName(),
								allyHero:GetUnitName()
							)
						)
						return BOT_ACTION_DESIRE_HIGH, enemyHero, "Q-Save:" .. Fu.Chat.GetNormName(enemyHero)
					end
				end
			end
		end
	end
	if #enemiesInRange >= 1 then
		local aoeLocation = Fu.GetAoeEnemyHeroLocation(bot, castRange, bounceRadius, 2)
		if aoeLocation ~= nil then
			for _, enemyHero in pairs(enemiesInRange) do
				if
					Fu.IsValidHero(enemyHero)
					and Fu.CanCastOnNonMagicImmune(enemyHero)
					and Fu.CanCastOnTargetAdvanced(enemyHero)
					and Fu.IsInLocRange(enemyHero, aoeLocation, bounceRadius + 50)
				then
					return BOT_ACTION_DESIRE_HIGH, enemyHero, "Q-Aoe:" .. Fu.Chat.GetNormName(enemyHero)
				end
			end
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidHero(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.CanCastOnTargetAdvanced(botTarget)
		then
			local creepsNearTarget = botTarget:GetNearbyCreeps(bounceRadius * 1.9, false)
			local heroesNearTarget = Fu.GetNearbyHeroes(botTarget, bounceRadius * 1.9, false, BOT_MODE_NONE)
			-- Gank on a lone hero (no creeps, no second enemy): Cask was never cast, and Death Ward
			-- waits while Cask is ready (ConsiderR), so neither came out. Now also when another
			-- allied hero is near the target (allies list counts WD, who is within cast range).
			local alliesNearTarget = Fu.GetAlliesNearLoc(botTarget:GetLocation(), 900)
			if #creepsNearTarget >= 2 or #heroesNearTarget >= 2 or hpRatio < 0.28 or #alliesNearTarget >= 2 then
				if #creepsNearTarget < 2 and #heroesNearTarget < 2 and hpRatio >= 0.28 then
					X.LogWD("cask-gank", "target=%s allies=%d", botTarget:GetUnitName(), #alliesNearTarget)
				end
				return BOT_ACTION_DESIRE_HIGH, botTarget, "Q-Attack:" .. Fu.Chat.GetNormName(botTarget)
			end
		end
	end
	if Fu.IsRetreating(bot) then
		for _, enemyHero in pairs(enemiesInRange) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
				and bot:WasRecentlyDamagedByHero(enemyHero, 3.0)
			then
				local creepsNearTarget = enemyHero:GetNearbyCreeps(bounceRadius * 1.9, false)
				local heroesNearTarget = Fu.GetNearbyHeroes(enemyHero, bounceRadius * 1.9, false, BOT_MODE_NONE)
				if #creepsNearTarget + #heroesNearTarget >= 2 or hpRatio < 0.23 then
					return BOT_ACTION_DESIRE_HIGH, enemyHero, "Q-Retreat:" .. Fu.Chat.GetNormName(enemyHero)
				end
			end
		end
	end
	if
		(Fu.IsPushing(bot) or Fu.IsDefending(bot) or Fu.IsFarming(bot))
		and Fu.IsAllowedToSpam(bot, 30)
		and abilityLevel >= 2
		and #nearbyEnemies == 0
		and #nearbyAllies <= 2
	then
		local enemyLaneCreeps = bot:GetNearbyLaneCreeps(999, true)
		local allyLaneCreeps = bot:GetNearbyLaneCreeps(888, false)
		for _, creep in pairs(enemyLaneCreeps) do
			if
				Fu.IsValid(creep)
				and not creep:HasModifier("modifier_fountain_glyph")
				and Fu.IsInRange(creep, bot, castRange + 300)
			then
				if #allyLaneCreeps == 0 and Fu.GetAroundTargetEnemyUnitCount(creep, bounceRadius * 2) >= 3 then
					return BOT_ACTION_DESIRE_HIGH, creep, "Q-PushAoe"
				end
				if
					Fu.IsKeyWordUnit("ranged", creep)
					and (
						Fu.WillKillTarget(creep, damage, damageType, castPoint)
						or #enemyLaneCreeps >= 7 and Fu.GetAroundTargetEnemyUnitCount(creep, bounceRadius * 2) >= 3
					)
				then
					return BOT_ACTION_DESIRE_HIGH, creep, "Q-PushRanged"
				end
				if
					Fu.IsKeyWordUnit("melee", creep)
					and Fu.WillKillTarget(creep, damage, damageType, castPoint)
					and (Fu.GetAroundTargetEnemyUnitCount(creep, bounceRadius * 2) >= 2 or mpRatio > 0.8)
				then
					return BOT_ACTION_DESIRE_HIGH, creep, "Q-PushMelee"
				end
			end
		end
	end
	if Fu.IsFarming(bot) and Fu.GetManaAfter(manaCost) > 0.3 and #nearbyEnemies == 0 then
		local neutralCreeps = bot:GetNearbyNeutralCreeps(castRange)
		if #neutralCreeps >= 3 then
			for _, creep in pairs(neutralCreeps) do
				if Fu.IsValid(creep) and Fu.IsInRange(bot, creep, castRange) then
					return BOT_ACTION_DESIRE_HIGH, creep, "Q-Farm:" .. #neutralCreeps
				end
			end
		end
	end
	if Fu.IsFarming(bot) and Fu.GetManaAfter(manaCost) > 0.3 and #nearbyEnemies == 0 then
		local laneCreeps = bot:GetNearbyLaneCreeps(castRange, true)
		if laneCreeps ~= nil and #laneCreeps >= 3 then
			for _, creep in pairs(laneCreeps) do
				if Fu.IsValid(creep) and Fu.CanBeAttacked(creep) and Fu.IsInRange(bot, creep, castRange) then
					return BOT_ACTION_DESIRE_HIGH, creep, "Q-FarmCreeps:" .. #laneCreeps
				end
			end
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if
			Fu.IsRoshan(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and Fu.IsAttacking(bot)
			and Fu.GetManaAfter(manaCost) > 0.3
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget, "Q-Roshan"
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if
			Fu.IsTormentor(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and Fu.IsAttacking(bot)
			and Fu.GetManaAfter(manaCost) > 0.3
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget, "Q-Tormentor"
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderW()
	if not voodooRestorationAbility:IsFullyCastable() then
		return 0
	end
	local radius = voodooRestorationAbility:GetSpecialValueInt("radius")
	local enemiesNearby = Fu.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE)
	if Fu.GetMP(bot) < 0.33 then
		if voodooRestorationAbility:GetToggleState() == true then
			return BOT_ACTION_DESIRE_HIGH
		else
			return BOT_ACTION_DESIRE_NONE
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidTarget(botTarget)
			and Fu.IsInRange(bot, botTarget, 1600)
			and not Fu.IsSuspiciousIllusion(botTarget)
		then
			local alliesNearTarget = Fu.GetNearbyHeroes(botTarget, 1200, true, BOT_MODE_NONE)
			local enemiesNearTarget = Fu.GetNearbyHeroes(botTarget, 1200, false, BOT_MODE_NONE)
			if alliesNearTarget ~= nil and enemiesNearTarget ~= nil and #alliesNearTarget >= #enemiesNearTarget then
				alliesNearTarget = Fu.GetAlliesNearLoc(bot:GetLocation(), radius)
				for _, allyHero in pairs(alliesNearTarget) do
					if
						Fu.IsValidHero(allyHero)
						and Fu.GetHP(allyHero) < 0.5
						and not Fu.IsSuspiciousIllusion(allyHero)
						and not allyHero:HasModifier("modifier_skeleton_king_reincarnation_scepter_active")
						and not allyHero:HasModifier("modifier_oracle_false_promise_timer")
						and not allyHero:HasModifier("modifier_item_aeon_disk_buff")
					then
						if voodooRestorationAbility:GetToggleState() == false then
							return BOT_ACTION_DESIRE_HIGH
						else
							return BOT_ACTION_DESIRE_NONE
						end
					end
				end
			end
		end
	end
	if Fu.IsRetreating(bot) then
		if
			Fu.IsValidHero(enemiesNearby[1])
			and Fu.GetHP(bot) < 0.5
			and not Fu.IsSuspiciousIllusion(enemiesNearby[1])
		then
			local alliesNearTarget = Fu.GetNearbyHeroes(enemiesNearby[1], 1200, true, BOT_MODE_NONE)
			local enemiesNearTarget = Fu.GetNearbyHeroes(enemiesNearby[1], 1200, false, BOT_MODE_NONE)
			if
				alliesNearTarget ~= nil
				and enemiesNearTarget ~= nil
				and (#alliesNearTarget > #enemiesNearTarget or bot:WasRecentlyDamagedByAnyHero(1.5))
			then
				if voodooRestorationAbility:GetToggleState() == false then
					return BOT_ACTION_DESIRE_HIGH
				else
					return BOT_ACTION_DESIRE_NONE
				end
			end
		end
	end
	-- Heal only ran with no enemy within 1600 or in attack modes, so in a team fight while WD was
	-- defending/pushing the heal stayed off (or was toggled off). Now team fights count too.
	local inFight = Fu.IsInTeamFight(bot, 1200)
	local alliesInRadius = Fu.GetAlliesNearLoc(bot:GetLocation(), radius)
	for _, allyHero in pairs(alliesInRadius) do
		if
			Fu.IsValidHero(allyHero)
			and Fu.GetHP(allyHero) < 0.5
			and enemiesNearby ~= nil
			and (#enemiesNearby == 0 or inFight)
			and not Fu.IsSuspiciousIllusion(allyHero)
			and not allyHero:HasModifier("modifier_skeleton_king_reincarnation_scepter_active")
			and not allyHero:HasModifier("modifier_oracle_false_promise_timer")
			and not allyHero:HasModifier("modifier_item_aeon_disk_buff")
		then
			if voodooRestorationAbility:GetToggleState() == false then
				return BOT_ACTION_DESIRE_HIGH
			else
				return BOT_ACTION_DESIRE_NONE
			end
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if Fu.IsRoshan(botTarget) and Fu.IsInRange(bot, botTarget, bot:GetAttackRange()) and Fu.IsAttacking(bot) then
			if voodooRestorationAbility:GetToggleState() == false then
				return BOT_ACTION_DESIRE_HIGH
			else
				return BOT_ACTION_DESIRE_NONE
			end
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, bot:GetAttackRange()) and Fu.IsAttacking(bot) then
			if voodooRestorationAbility:GetToggleState() == false then
				return BOT_ACTION_DESIRE_HIGH
			else
				return BOT_ACTION_DESIRE_NONE
			end
		end
	end
	if voodooRestorationAbility:GetToggleState() == true then
		return BOT_ACTION_DESIRE_HIGH
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderE()
	if not maledictAbility:IsFullyCastable() then
		return 0
	end
	local abilityLevel = maledictAbility:GetLevel()
	local castRange = maledictAbility:GetCastRange() + aetherRange
	local castPoint = maledictAbility:GetCastPoint()
	local manaCost = maledictAbility:GetManaCost()
	local damage = maledictAbility:GetAbilityDamage()
	local damageType = DAMAGE_TYPE_MAGICAL
	local enemiesInRange = Fu.GetNearbyHeroes(bot, castRange + 32, true, BOT_MODE_NONE)
	local radius = maledictAbility:GetSpecialValueInt("radius")
	if Fu.IsInTeamFight(bot, 1200) then
		local aoeLocation = Fu.GetAoeEnemyHeroLocation(bot, castRange, radius, 2)
		if aoeLocation ~= nil then
			return BOT_ACTION_DESIRE_HIGH, aoeLocation, "E-Fight"
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidHero(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange + 99)
			and Fu.CanCastOnNonMagicImmune(botTarget)
		then
			local castLocation = Fu.GetCastLocation(bot, botTarget, castRange, radius)
			if castLocation ~= nil then
				return BOT_ACTION_DESIRE_HIGH, castLocation, "E-Attack:" .. Fu.Chat.GetNormName(botTarget)
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderR()
	if not deathWardAbility:IsFullyCastable() then
		return 0
	end
	if
		paralyzingCaskAbility:IsFullyCastable()
		and bot:GetMana() > deathWardAbility:GetManaCost() + paralyzingCaskAbility:GetManaCost()
	then
		return 0
	end
	if
		maledictAbility:IsFullyCastable()
		and bot:GetMana() > deathWardAbility:GetManaCost() + maledictAbility:GetManaCost()
	then
		return 0
	end
	local abilityLevel = deathWardAbility:GetLevel()
	local castRange = deathWardAbility:GetCastRange() + aetherRange
	local castPoint = deathWardAbility:GetCastPoint()
	local manaCost = deathWardAbility:GetManaCost()
	local damage = deathWardAbility:GetAbilityDamage()
	local damageType = DAMAGE_TYPE_PURE -- datafeed: Death Ward damage type is pure (4), not physical
	local wardRadius = 700 - 120
	local enemiesInRange = Fu.GetNearbyHeroes(bot, castRange + wardRadius, true, BOT_MODE_NONE)
	if Fu.IsInTeamFight(bot, 900) then
		if #enemiesInRange >= 2 then
			for _, enemyHero in pairs(enemiesInRange) do
				if
					Fu.IsValidHero(enemyHero)
					and Fu.CanCastOnMagicImmune(enemyHero)
					and not enemyHero:IsAttackImmune()
				then
					local castLocation = Fu.GetCastLocation(bot, enemyHero, castRange, wardRadius)
					if castLocation ~= nil then
						return BOT_ACTION_DESIRE_HIGH, castLocation, "R-团战:" .. Fu.Chat.GetNormName(enemyHero)
					end
				end
			end
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidHero(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange + wardRadius - 260)
			and not botTarget:IsAttackImmune()
			and Fu.CanCastOnMagicImmune(botTarget)
			and (Fu.IsDisabled(botTarget) or botTarget:GetHealth() <= botTarget:GetActualIncomingDamage(
				bot:GetOffensivePower() * 2,
				DAMAGE_TYPE_ALL
			))
			and botTarget:GetHealth() > 500
			and #nearbyAllies <= 2
		then
			local castLocation = Fu.GetCastLocation(bot, botTarget, castRange, wardRadius)
			if castLocation ~= nil then
				return BOT_ACTION_DESIRE_HIGH, castLocation, "R-Attack:" .. Fu.Chat.GetNormName(botTarget)
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderAS()
	-- Voodoo Switcheroo is shard-locked and hidden until then (invalid order 60 if cast early).
	if
		voodooSwitcherooAbility == nil
		or voodooSwitcherooAbility:IsHidden()
		or not voodooSwitcherooAbility:IsTrained()
		or not voodooSwitcherooAbility:IsFullyCastable()
	then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local radius = 700
	local castRange = voodooSwitcherooAbility:GetCastRange()
	local castPoint = voodooSwitcherooAbility:GetCastPoint()
	local manaCost = voodooSwitcherooAbility:GetManaCost()
	local enemiesNearby = Fu.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE)
	if #enemiesNearby >= 1 and Fu.IsStunProjectileIncoming(bot, 600) then
		return BOT_ACTION_DESIRE_HIGH, "AS-躲眩晕弹道"
	end
	if Fu.IsRetreating(bot) and #enemiesNearby == 1 then
		local enemyHero = enemiesNearby[1]
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanCastOnMagicImmune(enemyHero)
			and enemyHero:GetAttackTarget() == bot
			and Fu.IsInRange(bot, enemyHero, enemyHero:GetAttackRange() + 100)
		then
			return BOT_ACTION_DESIRE_HIGH, "AS-撤退隐藏"
		end
	end
	if deathWardAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
	end
	if Fu.IsInTeamFight(bot, 900) then
		local enemiesInRadius = Fu.GetNearbyHeroes(bot, radius, true, BOT_MODE_NONE)
		if #enemiesInRadius >= 2 then
			return BOT_ACTION_DESIRE_HIGH, "AS-团战"
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidHero(botTarget)
			and Fu.IsInRange(bot, botTarget, radius * 0.5)
			and Fu.CanCastOnMagicImmune(botTarget)
			and botTarget:GetAttackTarget() == bot
			and hpRatio < 0.5
		then
			return BOT_ACTION_DESIRE_HIGH, "AS-攻击"
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
return X
