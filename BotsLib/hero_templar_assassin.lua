-- Templar Assassin: skill build, item build, and ability use for this hero.
local X = {}
local bot = GetBot()
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local AbilityContext = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local Minion = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local sTalentList = Fu.Skill.GetTalentList(bot)
local sAbilityList = Fu.Skill.GetAbilityList(bot)
local sRole = Fu.Item.GetRoleItemsBuyList(bot)
local tTalentTreeList = { ["t25"] = { 10, 0 }, ["t20"] = { 0, 10 }, ["t15"] = { 10, 0 }, ["t10"] = { 10, 0 } }
-- 1 Refraction, 2 Meld, 3 Psi Blades, 6 Psionic Trap. Dotabuff (2026-11-17): Meld at 1/3/5/7, Psi Blades
-- at 2/4/8/9, and one early Refraction point (17-38% of players take it at each of levels 1-7),
-- then Refraction maxed at 12-15. One Refraction at 3, so the bot is not without it until 11.
local tAllAbilityBuildList = { { 2, 3, 1, 3, 2, 6, 2, 3, 3, 2, 6, 1, 1, 1, 6 } }
local nAbilityBuildList = Fu.Skill.GetRandomBuild(tAllAbilityBuildList)
local nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList)
local sphereOrBkb = RandomInt(1, 9) > 6 and "item_sphere" or "item_black_king_bar"
local sRoleItemsBuyList = {}
sRoleItemsBuyList["pos_1"] = {
	"item_tango",
	"item_double_branches",
	"item_circlet",
	"item_circlet",
	"item_quelling_blade",
	"item_magic_wand",
	"item_power_treads",
	"item_dragon_lance",
	"item_desolator",
	"item_blink",
	"item_aghanims_shard",
	"item_black_king_bar",
	"item_greater_crit",
	"item_force_staff",
	"item_hurricane_pike",
	"item_swift_blink",
	"item_monkey_king_bar",
	"item_moon_shard",
	"item_ultimate_scepter_2",
}
sRoleItemsBuyList["pos_2"] = sRoleItemsBuyList["pos_1"]
sRoleItemsBuyList["pos_4"] = sRoleItemsBuyList["pos_1"]
sRoleItemsBuyList["pos_5"] = sRoleItemsBuyList["pos_1"]
sRoleItemsBuyList["pos_3"] = sRoleItemsBuyList["pos_1"]
X["sBuyList"] = sRoleItemsBuyList[sRole]
X["sSellList"] = { "item_black_king_bar", "item_quelling_blade" }
if Fu.Role.IsPvNMode() or Fu.Role.IsAllShadow() then
	X["sBuyList"], X["sSellList"] = { "PvN_TA" }, {}
end
nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"] = Fu.SetUserHeroInit(nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"])
X["sSkillList"] = Fu.Skill.GetSkillList(sAbilityList, nAbilityBuildList, sTalentList, nTalentBuildList)
X["bDeafaultAbility"] = false
X["bDeafaultItem"] = false
function X.MinionThink(minion)
	if Minion.IsValidUnit(minion) then
		if minion:GetUnitName() ~= "npc_dota_templar_assassin_psionic_trap" then
			Minion.IllusionThink(minion)
			return
		else
			-- Safe proxy: the datafeed does not list templar_assassin_self_trap (a trap-unit ability), so if
			-- it is gone a nil here would error on p:IsFullyCastable() every MinionThink.
			local selfTrapAbility = SafeAbility(minion:GetAbilityByName("templar_assassin_self_trap"), "templar_assassin_self_trap", "templar_assassin")
			local trapAbility =
				SafeAbility(bot:GetAbilityByName("templar_assassin_trap"), "templar_assassin_trap", "templar_assassin")
			local trapRadius = 400
			local attackRange = bot:GetAttackRange()
			local nearbyEnemies = minion:GetNearbyHeroes(trapRadius - 12, true, BOT_MODE_NONE)
			local enemyCreeps = minion:GetNearbyLaneCreeps(trapRadius - 28, true)
			local nearbyAllies = minion:GetNearbyHeroes(800, false, BOT_MODE_NONE)
			local farEnemies = minion:GetNearbyHeroes(1200, true, BOT_MODE_NONE)
			local distanceToBot = GetUnitToUnitDistance(bot, minion)
			if not bot:IsAlive() then
				distanceToBot = 9999
			end
			if selfTrapAbility:IsFullyCastable() then
				if #nearbyEnemies >= 1 and (distanceToBot < 1200 or #nearbyAllies >= 1 or X.IsEnemyRegenning(nearbyEnemies)) then
					minion:Action_UseAbility(selfTrapAbility)
					return
				end
				if
					minion:GetHealth() / minion:GetMaxHealth() < 0.6
					or farEnemies[1] ~= nil and farEnemies[1]:IsAlive() and farEnemies[1]:GetAttackTarget() == minion
				then
					minion:Action_UseAbility(selfTrapAbility)
					return
				end
				if #enemyCreeps >= 4 and #nearbyAllies == 0 then
					for _, creep in pairs(enemyCreeps) do
						if creep:IsAlive() and string.find(creep:GetUnitName(), "ranged") ~= nil then
							minion:Action_UseAbility(selfTrapAbility)
							return
						end
					end
				end
				local projectiles = minion:GetIncomingTrackingProjectiles()
				for _, projectile in pairs(projectiles) do
					if projectile.is_attack and GetUnitToLocationDistance(minion, projectile.location) < trapRadius then
						minion:Action_UseAbility(selfTrapAbility)
						return
					end
				end
			end
		end
	end
end
function X.IsEnemyRegenning(enemies)
	for _, enemy in pairs(enemies) do
		if
			enemy ~= nil
			and enemy:CanBeSeen()
			and enemy:IsAlive()
			and (
				enemy:GetHealth() < 240
				or enemy:HasModifier("modifier_clarity_potion")
				or enemy:HasModifier("modifier_bottle_regeneration")
				or enemy:HasModifier("modifier_rune_regen")
				or enemy:HasModifier("modifier_item_urn_heal")
				or enemy:HasModifier("modifier_item_spirit_vessel_heal")
			)
		then
			return true
		end
	end
	return false
end
local refractionAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[1]), "sAbilityList[1]", "templar_assassin")
local meldAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[2]), "sAbilityList[2]", "templar_assassin")
local psionicTrapAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[6]), "sAbilityList[6]", "templar_assassin")
local refractionDesire
local meldDesire
local psionicTrapDesire, psionicTrapLocation
local roshanLocation = nil
local midTrapLocation = nil
local topTowerLocation = nil
local bottomTowerLocation = nil
local runeList = { RUNE_BOUNTY_1, RUNE_BOUNTY_2, RUNE_BOUNTY_3, RUNE_BOUNTY_4, RUNE_POWERUP_1, RUNE_POWERUP_2 }
local lastTrapScanTime = 0
local runeLocations = {}
local neutralCamps = {}
local mpRatio, hpRatio, botLevel
local botTarget
function X.SkillsComplement()
	X.TAConsiderTarget()
	if Fu.CanNotUseAbility(bot) or bot:HasModifier("modifier_templar_assassin_meld") then
		return
	end
	local context = AbilityContext.Build(bot)
	botTarget = context.target
	botLevel = context.level
	mpRatio = context.mp
	hpRatio = context.hp
	if midTrapLocation == nil then
		local enemyMidTower = GetTower(GetOpposingTeam(), TOWER_MID_1)
		local allyMidTower = GetTower(GetTeam(), TOWER_MID_1)
		midTrapLocation = Fu.GetUnitTowardDistanceLocation(bot, allyMidTower, 928)
		topTowerLocation = GetTower(GetTeam(), TOWER_TOP_1):GetLocation()
		bottomTowerLocation = GetTower(GetTeam(), TOWER_BOT_1):GetLocation()
	end
	psionicTrapDesire, psionicTrapLocation = X.ConsiderR()
	if psionicTrapDesire > 0 then
		Fu.SetQueuePtToINT(bot, false)
		bot:ActionQueue_UseAbilityOnLocation(psionicTrapAbility, psionicTrapLocation)
		return
	end
	refractionDesire = X.ConsiderQ()
	if refractionDesire > 0 then
		Fu.SetQueuePtToINT(bot, false)
		bot:ActionQueue_UseAbility(refractionAbility)
		return
	end
	meldDesire = X.ConsiderW()
	if meldDesire > 0 then
		Fu.SetQueuePtToINT(bot, false)
		bot:ActionQueue_UseAbility(meldAbility)
		return
	end
end
function X.ConsiderQ()
	if not refractionAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
	end
	local attackRange = bot:GetAttackRange()
	local attackDamage = bot:GetAttackDamage()
	local bonusDamage = refractionAbility:GetSpecialValueInt("bonus_damage")
	local totalDamage = attackDamage + bonusDamage
	local damageType = DAMAGE_TYPE_PHYSICAL
	local abilityLevel = refractionAbility:GetLevel()
	local manaCost = refractionAbility:GetManaCost()
	local enemyHeroes = Fu.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE)
	if hpRatio < 0.8 then
		for _, enemyHero in pairs(enemyHeroes) do
			if bot:WasRecentlyDamagedByHero(enemyHero, 1.0) and enemyHero:GetAttackTarget() == bot then
				return BOT_ACTION_DESIRE_MODERATE
			end
		end
	end
	if
		hpRatio < 0.11
		and not bot:IsInvisible()
		and (bot:WasRecentlyDamagedByAnyHero(4.0) or bot:WasRecentlyDamagedByCreep(2.0) or bot:WasRecentlyDamagedByTower(2.0))
	then
		return BOT_ACTION_DESIRE_MODERATE
	end
	if bot:GetActiveMode() == BOT_MODE_LANING or botLevel <= 7 then
		local laneCreeps = bot:GetNearbyLaneCreeps(800, true)
		if mpRatio > 0.28 and #laneCreeps >= 4 then
			for _, creep in pairs(laneCreeps) do
				if
					Fu.IsValid(creep)
					and not creep:HasModifier("modifier_fountain_glyph")
					and Fu.IsInRange(bot, creep, attackRange + 300)
					and Fu.CanKillTarget(creep, totalDamage, damageType)
				then
					return BOT_ACTION_DESIRE_MODERATE
				end
			end
		end
	end
	if Fu.IsRetreating(bot) then
		for _, enemyHero in pairs(enemyHeroes) do
			if bot:WasRecentlyDamagedByHero(enemyHero, 2.0) or hpRatio < 0.25 then
				return BOT_ACTION_DESIRE_MODERATE
			end
		end
	end
	if Fu.IsNotAttackProjectileIncoming(bot, 1600) or Fu.GetAttackProjectileDamageByRange(bot, 1600) >= 110 then
		return BOT_ACTION_DESIRE_MODERATE
	end
	if (Fu.IsPushing(bot) or Fu.IsDefending(bot) or Fu.IsFarming(bot)) and Fu.IsAllowedToSpam(bot, manaCost) and abilityLevel >= 3 then
		local laneCreeps = bot:GetNearbyLaneCreeps(1600, true)
		if #laneCreeps >= 2 then
			local healthiestCreep = Fu.GetMostHpUnit(laneCreeps)
			if
				Fu.IsValid(healthiestCreep)
				and (healthiestCreep:GetHealth() >= 400 or #laneCreeps >= 5)
				and not healthiestCreep:HasModifier("modifier_fountain_glyph")
			then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	if Fu.IsFarming(bot) and abilityLevel >= 2 and (bot:GetAttackDamage() < 200 or mpRatio > 0.49) and mpRatio > 0.3 then
		local neutralCreeps = bot:GetNearbyNeutralCreeps(800)
		if #neutralCreeps >= 2 then
			local healthiestCreep = Fu.GetMostHpUnit(neutralCreeps)
			if Fu.IsValid(healthiestCreep) and (healthiestCreep:GetHealth() >= 400 or #neutralCreeps >= 3) and Fu.IsInRange(healthiestCreep, bot, attackRange + 50) then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	if Fu.IsGoingOnSomeone(bot) and abilityLevel >= 2 then
		if Fu.IsValidHero(botTarget) and Fu.CanBeAttacked(botTarget) and Fu.IsInRange(botTarget, bot, 2000) then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if bot:GetActiveMode() == BOT_MODE_ROSHAN then
		local attackTarget = bot:GetAttackTarget()
		if Fu.IsRoshan(attackTarget) and Fu.GetHP(attackTarget) > 0.3 and Fu.IsInRange(attackTarget, bot, attackRange) then
			return BOT_ACTION_DESIRE_LOW
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(botTarget, bot, 800) and Fu.IsAttacking(bot) then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if
		bot:HasModifier("modifier_rune_regen") or abilityLevel >= 3 and mpRatio > 0.96 and bot:HasModifier("modifier_fountain_aura_buff")
	then
		return BOT_ACTION_DESIRE_LOW
	end
	if botLevel >= 12 and bot:GetMana() > 325 then
		local enemyHeroes = Fu.GetNearbyHeroes(bot, 800, true, BOT_MODE_NONE)
		local laneCreeps = bot:GetNearbyLaneCreeps(1600, true)
		local enemyTowers = bot:GetNearbyTowers(1600, true)
		if #enemyHeroes > 0 or #enemyTowers > 0 or #laneCreeps > 1 or Fu.IsInEnemyArea(bot) and mpRatio > 0.95 then
			return BOT_ACTION_DESIRE_LOW
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderW()
	local enemyTowers = bot:GetNearbyTowers(888, true)
	if not meldAbility:IsFullyCastable() or #enemyTowers > 0 or bot:HasModifier("modifier_item_dustofappearance") then
		return BOT_ACTION_DESIRE_NONE
	end
	local incomingDamage = Fu.GetAttackProjectileDamageByRange(bot, 1600)
	if
		incomingDamage > bot:GetAttackDamage() * (botLevel % 10 + 1)
		or incomingDamage > bot:GetHealth() * 0.38
		or bot:IsDisarmed() and bot:GetActiveMode() ~= BOT_MODE_RETREAT
		or bot:IsRooted()
	then
		if not bot:IsInvisible() then
			return BOT_ACTION_DESIRE_MODERATE
		end
	end
	if Fu.IsRunning(bot) then
		return BOT_ACTION_DESIRE_NONE
	end
	local abilityLevel = meldAbility:GetLevel()
	local manaCost = meldAbility:GetManaCost()
	local attackRange = bot:GetAttackRange()
	local attackDamage = bot:GetAttackDamage()
	local bonusDamage = meldAbility:GetSpecialValueInt("bonus_damage")
	local damageType = DAMAGE_TYPE_PHYSICAL
	local totalDamage = attackDamage + bonusDamage
	local enemyHeroes = Fu.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE)
	if bot:GetActiveMode() == BOT_MODE_ROSHAN then
		local attackTarget = bot:GetAttackTarget()
		if Fu.IsRoshan(attackTarget) and Fu.IsInRange(attackTarget, bot, attackRange + 40) then
			return BOT_ACTION_DESIRE_LOW
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(botTarget, bot, attackRange) and Fu.IsAttacking(bot) then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		local attackTarget = bot:GetAttackTarget()
		if Fu.IsValidHero(attackTarget) and Fu.CanBeAttacked(attackTarget) and Fu.IsInRange(attackTarget, bot, attackRange + 64) then
			return BOT_ACTION_DESIRE_HIGH
		end
		attackTarget = bot:GetTarget()
		if Fu.IsValidHero(attackTarget) and Fu.CanBeAttacked(attackTarget) and Fu.IsInRange(attackTarget, bot, attackRange + 24) then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsFarming(bot) and #enemyHeroes == 0 and mpRatio > 0.28 + (4 - abilityLevel) / 20 then
		local neutralCreeps = bot:GetNearbyNeutralCreeps(800)
		local attackTarget = bot:GetAttackTarget()
		if
			Fu.IsValid(attackTarget)
			and Fu.IsInRange(attackTarget, bot, attackRange + 50)
			and attackTarget:GetHealth() >= attackDamage * 1.18 + bonusDamage
			and (#neutralCreeps > 1 or attackTarget:GetHealth() > attackDamage * 2.28)
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if (Fu.IsPushing(bot) or Fu.IsDefending(bot) or Fu.IsFarming(bot)) and Fu.IsAllowedToSpam(bot, manaCost) and abilityLevel >= 3 and #enemyHeroes == 0 then
		local laneCreeps = bot:GetNearbyLaneCreeps(1200, true)
		local allyCreeps = bot:GetNearbyLaneCreeps(800, false)
		if #laneCreeps >= 3 then
			local attackTarget = bot:GetAttackTarget()
			if
				Fu.IsValid(attackTarget)
				and Fu.IsInRange(attackTarget, bot, attackRange + 50)
				and not attackTarget:HasModifier("modifier_fountain_glyph")
				and not Fu.CanKillTarget(attackTarget, attackDamage * 1.2, damageType)
				and (Fu.CanKillTarget(attackTarget, totalDamage * 1.2, damageType) or #allyCreeps <= 1)
			then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	local attackTarget = bot:GetAttackTarget()
	if
		Fu.IsValid(attackTarget)
		and Fu.IsKeyWordUnit("ranged", attackTarget)
		and not attackTarget:HasModifier("modifier_fountain_glyph")
		and Fu.GetHP(attackTarget) > 0.48
		and Fu.IsInRange(attackTarget, bot, attackRange + 40)
		and not Fu.CanKillTarget(attackTarget, attackDamage * 1.2, damageType)
		and Fu.CanKillTarget(attackTarget, totalDamage * 1.2, damageType)
	then
		return BOT_ACTION_DESIRE_HIGH
	end
	if botLevel > 11 and bot:GetMana() > 280 then
		local attackTarget = bot:GetAttackTarget()
		if Fu.IsValid(attackTarget) and Fu.IsInRange(attackTarget, bot, attackRange + 50) and not Fu.CanKillTarget(attackTarget, attackDamage * 3.28, damageType) then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderR()
	if not psionicTrapAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	if #runeLocations == 0 then
		for index, runeType in pairs(runeList) do
			local runeLocation = GetRuneSpawnLocation(runeType)
			runeLocations[index] = runeLocation
		end
	end
	if #neutralCamps == 0 then
		local spawners = GetNeutralSpawners()
		for index, spawner in pairs(spawners) do
			if spawner.team == GetTeam() and spawner.type ~= "small" and spawner.type ~= "medium" then
				neutralCamps[index] = spawner
			end
		end
	end
	local castRange = psionicTrapAbility:GetCastRange()
	local castPoint = psionicTrapAbility:GetCastPoint()
	local abilityLevel = psionicTrapAbility:GetLevel()
	local enemyCreeps = bot:GetNearbyCreeps(1000, true)
	local closeEnemies = Fu.GetNearbyHeroes(bot, 600, true, BOT_MODE_NONE)
	if Fu.IsRetreating(bot) then
		local enemyHeroes = Fu.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE)
		for _, enemyHero in pairs(enemyHeroes) do
			if Fu.IsMoving(enemyHero) and bot:WasRecentlyDamagedByHero(enemyHero, 2.0) and Fu.CanCastOnNonMagicImmune(enemyHero) then
				return BOT_ACTION_DESIRE_MODERATE, enemyHero:GetExtrapolatedLocation(1.0)
			end
		end
	end
	local teamPlayers = GetTeamPlayers(GetTeam())
	for i = 1, #teamPlayers do
		local teammate = GetTeamMember(i)
		if Fu.IsValid(teammate) and Fu.IsGoingOnSomeone(teammate) then
			local allyTarget = Fu.GetProperTarget(teammate)
			if
				Fu.IsValidHero(allyTarget)
				and Fu.IsRunning(allyTarget)
				and Fu.IsInRange(allyTarget, bot, castRange + 800)
				and not Fu.IsInRange(allyTarget, bot, bot:GetAttackRange())
				and Fu.CanCastOnNonMagicImmune(allyTarget)
			then
				local predictedLocation = allyTarget:GetExtrapolatedLocation(1.8)
				if
					GetUnitToLocationDistance(bot, predictedLocation) <= castRange + 50
					and allyTarget:GetMovementDirectionStability() > 0.95
					and IsLocationPassable(predictedLocation)
				then
					return BOT_ACTION_DESIRE_HIGH, predictedLocation
				end
				predictedLocation = allyTarget:GetExtrapolatedLocation(0.8)
				if
					GetUnitToLocationDistance(bot, predictedLocation) <= castRange + 50
					and allyTarget:GetMovementDirectionStability() > 0.9
					and IsLocationPassable(predictedLocation)
				then
					return BOT_ACTION_DESIRE_HIGH, predictedLocation
				end
				local targetLocation = allyTarget:GetLocation()
				if GetUnitToLocationDistance(bot, targetLocation) <= castRange + 50 then
					return BOT_ACTION_DESIRE_HIGH, targetLocation
				end
			end
		end
	end
	local enemyHeroes = Fu.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE)
	if
		lastTrapScanTime < DotaTime() - 1.0
		and #enemyHeroes == 0
		and not bot:WasRecentlyDamagedByAnyHero(3.0)
		and bot:GetActiveMode() ~= BOT_MODE_RETREAT
	then
		for _, runeLocation in pairs(runeLocations) do
			if GetUnitToLocationDistance(bot, runeLocation) < castRange then
				if not IsLocationVisible(runeLocation) then
					return BOT_ACTION_DESIRE_HIGH, runeLocation
				end
			end
		end
		for _, camp in pairs(neutralCamps) do
			if GetUnitToLocationDistance(bot, camp.location) < castRange and abilityLevel >= 2 and (camp.type ~= "ancient" or botLevel >= 15) then
				if not IsLocationVisible(camp.location) then
					return BOT_ACTION_DESIRE_HIGH, camp.location
				end
			end
		end
		if midTrapLocation ~= nil and abilityLevel >= 2 then
			if GetUnitToLocationDistance(bot, midTrapLocation) < castRange and not IsLocationVisible(midTrapLocation) then
				return BOT_ACTION_DESIRE_HIGH, midTrapLocation
			end
		end
		if abilityLevel >= 3 then
			if topTowerLocation ~= nil then
				if GetUnitToLocationDistance(bot, topTowerLocation) < castRange and not IsLocationVisible(topTowerLocation) then
					return BOT_ACTION_DESIRE_HIGH, topTowerLocation
				end
			end
			if bottomTowerLocation ~= nil then
				if GetUnitToLocationDistance(bot, bottomTowerLocation) < castRange and not IsLocationVisible(bottomTowerLocation) then
					return BOT_ACTION_DESIRE_HIGH, bottomTowerLocation
				end
			end
		end
		lastTrapScanTime = DotaTime()
	end
	if bot:GetActiveMode() == BOT_MODE_ROSHAN and roshanLocation == nil then
		if Fu.IsRoshan(botTarget) then
			roshanLocation = botTarget:GetLocation()
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.TAConsiderTarget()
	local bot = GetBot()
	if not Fu.IsRunning(bot) or bot:HasModifier("modifier_item_hurricane_pike_range") then
		return
	end
	local attackTarget = bot:GetAttackTarget()
	if not Fu.IsValidHero(attackTarget) then
		return
	end
	local attackRange = bot:GetAttackRange() + 40
	if attackRange > 1600 then
		attackRange = 1600
	end
	local enemiesInRange = Fu.GetNearbyHeroes(bot, attackRange, true, BOT_MODE_NONE)
	local newTarget = enemiesInRange[1]
	-- Review fix: this read nInAttackRangeWeakestEnemyHero, a global that is never set (always nil),
	-- so TA kept running after an out-of-range or untouchable target. Use the weakest attackable
	-- hero in range (same helper as Sniper's ConsiderTarget), else the nearest one.
	newTarget = Fu.GetAttackableWeakestUnit(bot, attackRange, true, true) or newTarget
	if
		Fu.IsValidHero(newTarget)
		and newTarget ~= attackTarget
		and Fu.CanBeAttacked(newTarget)
		and (GetUnitToUnitDistance(attackTarget, bot) > attackRange or Fu.HasForbiddenModifier(attackTarget))
	then
		if DotaTime() - (X.lastRetargetLog or -99) > 10 then
			X.lastRetargetLog = DotaTime()
			pcall(print, string.format("[OHA-TA] t=%.0f retarget from=%s to=%s", DotaTime(), attackTarget:GetUnitName(), newTarget:GetUnitName()))
		end
		bot:SetTarget(newTarget)
		return
	end
end
return X
