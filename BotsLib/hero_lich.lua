-- Lich: skill build, item build, and ability use for this hero.
local X = {}
local bot = GetBot()
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local ChargeTracker = require(GetScriptDirectory() .. "/FuncLib/systems/charge_tracker")
local AbilityContext = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local Minion = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local sTalentList = Fu.Skill.GetTalentList(bot)
local sAbilityList = Fu.Skill.GetAbilityList(bot)
local sRole = Fu.Item.GetRoleItemsBuyList(bot)
local tTalentTreeList = { ["t25"] = { 10, 0 }, ["t20"] = { 0, 10 }, ["t15"] = { 10, 0 }, ["t10"] = { 10, 0 } }
local tAllAbilityBuildList = { { 1, 2, 1, 3, 1, 6, 1, 2, 2, 2, 6, 3, 3, 3, 6 } }
local nAbilityBuildList = Fu.Skill.GetRandomBuild(tAllAbilityBuildList)
local nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList)
local sRoleItemsBuyList = {}
sRoleItemsBuyList["pos_4"] = {
	"item_enchanted_mango",
	"item_blood_grenade",
	"item_priest_outfit",
	"item_force_staff",
	"item_mekansm",
	"item_glimmer_cape",
	"item_blink",
	"item_aghanims_shard",
	"item_guardian_greaves",
	"item_shivas_guard",
	"item_ultimate_scepter",
	"item_ultimate_scepter_2",
	"item_sheepstick",
	"item_refresher",
	"item_moon_shard",
}
sRoleItemsBuyList["pos_5"] = {
	"item_double_tango",
	"item_faerie_fire",
	"item_enchanted_mango",
	"item_blood_grenade",
	"item_boots",
	"item_urn_of_shadows",
	"item_tranquil_boots",
	"item_glimmer_cape",
	"item_blink",
	"item_aghanims_shard",
	"item_pipe",
	"item_spirit_vessel",
	"item_solar_crest",
	"item_boots_of_bearing",
	"item_octarine_core",
	"item_sheepstick",
	"item_ultimate_scepter_2",
	"item_moon_shard",
}
-- No Boots of Travel: this build's Guardian Greaves / Boots of Bearing are its one pair of boots.
sRoleItemsBuyList["pos_3"] = {
	"item_mage_outfit",
	"item_glimmer_cape",
	"item_boots_of_bearing",
	"item_aghanims_shard",
	"item_ultimate_scepter",
	"item_veil_of_discord",
	"item_cyclone",
	"item_shivas_guard",
	"item_refresher",
	"item_ultimate_scepter_2",
	"item_sheepstick",
	"item_wind_waker",
	"item_moon_shard",
}
sRoleItemsBuyList["pos_2"] = {
	"item_crystal_maiden_outfit",
	"item_force_staff",
	"item_aghanims_shard",
	"item_ultimate_scepter",
	"item_kaya",
	"item_meteor_hammer",
	"item_rod_of_atos",
	"item_hurricane_pike",
	"item_shivas_guard",
	"item_octarine_core",
	"item_gungir",
	"item_moon_shard",
	"item_ultimate_scepter_2",
	"item_travel_boots_2",
}
sRoleItemsBuyList["pos_1"] = {
	"item_crystal_maiden_outfit",
	"item_force_staff",
	"item_aghanims_shard",
	"item_ultimate_scepter",
	"item_kaya",
	"item_meteor_hammer",
	"item_rod_of_atos",
	"item_gungir",
	"item_hurricane_pike",
	"item_shivas_guard",
	"item_moon_shard",
	"item_ultimate_scepter_2",
	"item_travel_boots_2",
}
X["sBuyList"] = sRoleItemsBuyList[sRole]
X["sSellList"] = { "item_black_king_bar", "item_quelling_blade" }
if Fu.Role.IsPvNMode() or Fu.Role.IsAllShadow() then
	X["sBuyList"], X["sSellList"] = { "PvN_priest" }, {}
end
nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"] = Fu.SetUserHeroInit(nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"])
X["sSkillList"] = Fu.Skill.GetSkillList(sAbilityList, nAbilityBuildList, sTalentList, nTalentBuildList)
X["bDeafaultAbility"] = true
-- Cast when cornered (retreating into 3+ enemies with no way out), before running further.
X["LastStandSpells"] = { { name = "lich_chain_frost", kind = "unit" } }
X["bDeafaultItem"] = true
function X.MinionThink(minionUnit)
	if Minion.IsValidUnit(minionUnit) and minionUnit:GetUnitName() ~= "npc_dota_lich_ice_spire" then
		Minion.IllusionThink(minionUnit)
	end
end
local frostBlastAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[1]), "sAbilityList[1]", "lich")
local frostShieldAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[2]), "sAbilityList[2]", "lich")
local sinisterGazeAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[3]), "sAbilityList[3]", "lich")
-- Ice Spire by name: datafeed lists it as Shard-granted (hidden until then), and the innate Sacrifice
-- (lich_death_charge) can take slot index 4, so sAbilityList[4] isn't reliable.
local iceSpireAbility = SafeAbility(bot:GetAbilityByName("lich_ice_spire"), "lich_ice_spire", "lich")
local chainFrostAbility = SafeAbility(bot:GetAbilityByName(sAbilityList[6]), "sAbilityList[6]", "lich")
local sacrificeAbility = SafeAbility(bot:GetAbilityByName("lich_death_charge"), "lich_death_charge", "lich")
local talent1 = SafeAbility(bot:GetAbilityByName(sTalentList[1]), "sTalentList[1]", "lich")
local talent2 = SafeAbility(bot:GetAbilityByName(sTalentList[2]), "sTalentList[2]", "lich")
local talent5 = SafeAbility(bot:GetAbilityByName(sTalentList[5]), "sTalentList[5]", "lich")
local talent7 = SafeAbility(bot:GetAbilityByName(sTalentList[7]), "sTalentList[7]", "lich")
local frostBlastDesire, frostBlastTarget
local frostShieldDesire, frostShieldTarget
local sinisterGazeDesire, sinisterGazeTarget
local chainFrostDesire, chainFrostTarget
local iceSpireDesire, iceSpireLocation
local sacrificeDesire, sacrificeTarget
local aetherRange = 0
local manaReserve, mpRatio, hpRatio, nearbyEnemies, nearbyAllies
-- Sacrifice charges from the shared tracker (2 charges, 120s each, none when learned).
function X.SacrificeCharges()
	return ChargeTracker.Count(bot, sacrificeAbility) or 0
end
function X.SkillsComplement()
	-- Scepter: other spells can be cast while channeling Sinister Gaze (Valve data). The busy check
	-- below stops everything during a channel, so the weave runs first.
	if X.ConsiderGazeWeave() then
		return
	end
	if Fu.CanNotUseAbility(bot) or bot:IsInvisible() then
		return
	end
	local context = AbilityContext.Build(bot)
	manaReserve = 330
	aetherRange = context.aetherRange
	mpRatio = context.mp
	hpRatio = context.hp
	botTarget = context.target
	nearbyEnemies = context.enemies
	nearbyAllies = context.allies
	-- Sacrifice first: with both charges up it goes at once, so the Frost Blast pokes below do not
	-- keep pushing it back.
	sacrificeDesire, sacrificeTarget = X.ConsiderSacrifice()
	if sacrificeDesire > 0 then
		pcall(ChargeTracker.Issued, bot, sacrificeAbility, sacrificeTarget)
		Fu.SetQueuePtToINT(bot, true)
		bot:ActionQueue_UseAbilityOnEntity(sacrificeAbility, sacrificeTarget)
		return
	end
	-- Ice Spire beside a lone target before Chain Frost, so the orb bounces between them.
	local spireCombo = X.ConsiderSpireCombo()
	if spireCombo ~= nil then
		Fu.SetQueuePtToINT(bot, true)
		bot:ActionQueue_UseAbilityOnLocation(iceSpireAbility, spireCombo)
		return
	end
	-- Frost Shield on our Ice Spire right after Chain Frost (before Frost Blast pokes).
	local shieldSpire = X.ConsiderSpireShield()
	if shieldSpire ~= nil then
		bot:Action_UseAbilityOnEntity(frostShieldAbility, shieldSpire)
		return
	end
	chainFrostDesire, chainFrostTarget = X.ConsiderR()
	if chainFrostDesire > 0 then
		Fu.SetQueuePtToINT(bot, true)
		bot:ActionQueue_UseAbilityOnEntity(chainFrostAbility, chainFrostTarget)
		return
	end
	frostBlastDesire, frostBlastTarget = X.ConsiderQ()
	if frostBlastDesire > 0 then
		Fu.SetQueuePtToINT(bot, true)
		bot:ActionQueue_UseAbilityOnEntity(frostBlastAbility, frostBlastTarget)
		return
	end
	frostShieldDesire, frostShieldTarget = X.ConsiderW()
	if frostShieldDesire > 0 then
		Fu.SetQueuePtToINT(bot, true)
		bot:ActionQueue_UseAbilityOnEntity(frostShieldAbility, frostShieldTarget)
		return
	end
	sinisterGazeDesire, sinisterGazeTarget = X.ConsiderE()
	if sinisterGazeDesire > 0 then
		Fu.SetQueuePtToINT(bot, true)
		bot._gazeAt = DotaTime()
		bot._gazeTarget = sinisterGazeTarget
		if bot:HasScepter() then
			bot:ActionQueue_UseAbilityOnLocation(sinisterGazeAbility, sinisterGazeTarget:GetLocation())
		else
			bot:ActionQueue_UseAbilityOnEntity(sinisterGazeAbility, sinisterGazeTarget)
		end
		return
	end
	iceSpireDesire, iceSpireLocation = X.ConsiderAS()
	if iceSpireDesire > 0 then
		Fu.SetQueuePtToINT(bot, true)
		bot:ActionQueue_UseAbilityOnLocation(iceSpireAbility, iceSpireLocation)
		return
	end
end
-- Frost Blast on creeps only while he keeps the mana for one more Frost Blast and a Frost Shield
-- after the cast, so he can still answer a gank or an engage (user: he blasted waves until
-- he was out of mana).
local function CreepManaOk()
	local blast = frostBlastAbility:GetManaCost() or 0
	local shield = (frostShieldAbility:IsTrained() and frostShieldAbility:GetManaCost()) or 0
	return bot:GetMana() - blast >= blast + shield
end
function X.ConsiderQ()
	if not frostBlastAbility:IsFullyCastable() then
		return 0
	end
	local abilityLevel = frostBlastAbility:GetLevel()
	local castRange = frostBlastAbility:GetCastRange() + aetherRange
	local baseCastRange = castRange
	if #nearbyEnemies <= 2 and castRange < 700 then
		castRange = castRange + 100
	end
	local castPoint = frostBlastAbility:GetCastPoint()
	local manaCost = frostBlastAbility:GetManaCost()
	local damage = frostBlastAbility:GetSpecialValueInt("damage") -- datafeed: primary-target damage 40/80/120/160 (was abilityLevel * 50)
	local aoeDamage = frostBlastAbility:GetSpecialValueInt("aoe_damage")
	if talent2:IsTrained() then
		aoeDamage = aoeDamage + talent2:GetSpecialValueInt("value")
	end
	local totalDamage = damage + aoeDamage
	local damageType = DAMAGE_TYPE_MAGICAL
	local radius = frostBlastAbility:GetSpecialValueInt("radius")
	local enemiesInRange = Fu.GetNearbyHeroes(bot, castRange + 32, true, BOT_MODE_NONE)
	local enemiesInBonusRange = Fu.GetNearbyHeroes(bot, castRange + 150, true, BOT_MODE_NONE)
	local nearbyCreeps = bot:GetNearbyCreeps(castRange + 43, true)
	for _, enemyHero in pairs(enemiesInBonusRange) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and Fu.CanCastOnTargetAdvanced(enemyHero)
			and Fu.WillMagicKillTarget(bot, enemyHero, totalDamage, castPoint)
		then
			if Fu.WillMagicKillTarget(bot, enemyHero, aoeDamage, castPoint) then
				local bounceTarget = nil
				local unitsInRange = Fu.CombineTwoTable(enemiesInRange, nearbyCreeps)
				for _, unit in pairs(unitsInRange) do
					if
						Fu.IsValidHero(unit)
						and Fu.IsInRange(enemyHero, unit, radius)
						and Fu.CanCastOnNonMagicImmune(unit)
						and Fu.CanCastOnTargetAdvanced(unit)
					then
						bounceTarget = unit
						break
					end
				end
				if bounceTarget ~= nil then
					return BOT_ACTION_DESIRE_HIGH, bounceTarget, "Q-优化击杀:" .. Fu.Chat.GetNormName(bounceTarget)
				end
			end
			return BOT_ACTION_DESIRE_HIGH, enemyHero, "Q-击杀:" .. Fu.Chat.GetNormName(enemyHero)
		end
	end
	if Fu.IsInTeamFight(bot, 1200) then
		local bestAoeTarget = nil
		local maxHeroCount = 1
		local unitsInRange = Fu.CombineTwoTable(enemiesInRange, nearbyCreeps)
		local weakestHero = nil
		local minHealth = 9999
		for _, unit in pairs(unitsInRange) do
			if Fu.IsValid(unit) and Fu.CanCastOnNonMagicImmune(unit) and Fu.CanCastOnTargetAdvanced(unit) then
				local heroCount = Fu.GetAroundTargetEnemyHeroCount(unit, radius)
				if heroCount > maxHeroCount then
					maxHeroCount = heroCount
					bestAoeTarget = unit
				end
				if unit:IsHero() then
					local health = unit:GetHealth()
					if health < minHealth then
						minHealth = health
						weakestHero = unit
					end
				end
			end
		end
		if bestAoeTarget ~= nil then
			return BOT_ACTION_DESIRE_HIGH, bestAoeTarget, "Q-团战最优目标:" .. maxHeroCount
		end
		if weakestHero ~= nil then
			return BOT_ACTION_DESIRE_HIGH, weakestHero, "Q-团战最弱目标:" .. Fu.Chat.GetNormName(weakestHero)
		end
	end
	if Fu.IsLaning(bot) then
		if mpRatio > 0.5 then
			for _, enemyHero in pairs(enemiesInRange) do
				if
					Fu.IsValidHero(enemyHero)
					and Fu.CanCastOnNonMagicImmune(enemyHero)
					and Fu.CanCastOnTargetAdvanced(enemyHero)
					and Fu.GetAttackEnemysAllyCreepCount(enemyHero, 1400) >= 3
				then
					return BOT_ACTION_DESIRE_HIGH, enemyHero, "Q-对线消耗:" .. Fu.Chat.GetNormName(enemyHero)
				end
			end
		end
		if #nearbyAllies <= 1 or Fu.IsCore(bot) then
			local laneCreeps = bot:GetNearbyLaneCreeps(800, true)
			for _, creep in pairs(laneCreeps) do
				if Fu.IsValid(creep) and not creep:HasModifier("modifier_fountain_glyph") then
					if
						Fu.IsKeyWordUnit("ranged", creep)
						and bot:GetMana() > 330
						and CreepManaOk()
						and Fu.WillKillTarget(creep, totalDamage, damageType, castPoint)
						and not Fu.IsAllysTarget(creep)
					then
						return BOT_ACTION_DESIRE_HIGH, creep, "Q-对线补刀远程"
					end
					if
						bot:GetMana() > 400
						and CreepManaOk()
						and Fu.IsKeyWordUnit("melee", creep)
						and Fu.WillKillTarget(creep, totalDamage, damageType, castPoint)
						and not Fu.WillKillTarget(creep, totalDamage * 0.5, damageType, castPoint)
						and not Fu.IsAllysTarget(creep)
					then
						return BOT_ACTION_DESIRE_HIGH, creep, "Q-对线补刀近战"
					end
				end
			end
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidHero(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange + 30)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.CanCastOnTargetAdvanced(botTarget)
		then
			if abilityLevel >= 2 or mpRatio > 0.68 or Fu.GetHP(botTarget) < 0.48 or hpRatio < 0.28 then
				return BOT_ACTION_DESIRE_HIGH, botTarget, "Q-攻击:" .. Fu.Chat.GetNormName(botTarget)
			end
		end
	end
	if Fu.IsRetreating(bot) then
		for _, enemyHero in pairs(enemiesInRange) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.IsInRange(bot, enemyHero, baseCastRange)
				and (bot:WasRecentlyDamagedByHero(enemyHero, 4.0) or mpRatio > 0.68 or GetUnitToUnitDistance(bot, enemyHero) <= 400)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
			then
				return BOT_ACTION_DESIRE_HIGH, enemyHero, "Q-撤退时减速:" .. Fu.Chat.GetNormName(enemyHero)
			end
		end
	end
	-- Jungle: Frost Blast hits the target plus everything within 200 (Valve data: 40-160 on the
	-- target, 80-200 area). It needed level 3, 3+ neutrals, a 600+ HP target with 3 units around
	-- it, and Lich already facing it, so it almost never went. Now: level 2+, the neutral with
	-- the most others around it (2+ units hit), the hit worth it (their HP at least twice the
	-- area damage), and mana kept (30%, or 20% with a Sacrifice charge to refill).
	if
		Fu.IsFarming(bot)
		and abilityLevel >= 2
		and #nearbyEnemies == 0
		and (#nearbyAllies <= 1 or Fu.IsCore(bot))
		and not (Fu.IsPushing(bot) or Fu.IsDefending(bot))
	then
		local keep = (X.SacrificeCharges and X.SacrificeCharges() or 0) >= 1 and 0.2 or 0.3
		if Fu.GetManaAfter(manaCost) >= keep and CreepManaOk() then
			local aoe = frostBlastAbility:GetSpecialValueInt("aoe_damage")
			local best, bestHit, bestHp = nil, 1, 0
			for _, creep in pairs(bot:GetNearbyNeutralCreeps(castRange + 100) or {}) do
				if Fu.IsValid(creep) and creep:GetMagicResist() < 0.5 and Fu.CanBeAttacked(creep) then
					local hit, hp = 0, 0
					for _, other in pairs(bot:GetNearbyNeutralCreeps(castRange + 400) or {}) do
						if Fu.IsValid(other) and GetUnitToUnitDistance(creep, other) <= radius then
							hit = hit + 1
							hp = hp + math.min(other:GetHealth(), aoe)
						end
					end
					if hit >= 2 and hp >= aoe * 2 and (hit > bestHit or hit == bestHit and hp > bestHp) then
						best, bestHit, bestHp = creep, hit, hp
					end
				end
			end
			if best ~= nil then
				return BOT_ACTION_DESIRE_HIGH, best, "Q-jungle:" .. bestHit
			end
		end
	end
	-- Was "(pushing ... and #nearbyAllies <= 1) or IsCore": a core Lich (pos 1) passed in any mode with no
	-- mana check and blasted every wave. Now pushing, defending or farming for everyone, a core
	-- may do it with more allies around, and the mana reserve applies.
	if
		(Fu.IsPushing(bot) or Fu.IsDefending(bot) or Fu.IsFarming(bot))
		and Fu.IsAllowedToSpam(bot, 30)
		and abilityLevel >= 3
		and #nearbyEnemies == 0
		and (#nearbyAllies <= 1 or Fu.IsCore(bot))
		and CreepManaOk()
	then
		local laneCreeps = bot:GetNearbyLaneCreeps(999, true)
		local allyLaneCreeps = bot:GetNearbyLaneCreeps(888, false)
		for _, creep in pairs(laneCreeps) do
			if Fu.IsValid(creep) and not creep:HasModifier("modifier_fountain_glyph") and Fu.IsInRange(creep, bot, castRange + 300) then
				if #allyLaneCreeps == 0 and Fu.GetAroundTargetEnemyUnitCount(creep, radius) >= 4 then
					return BOT_ACTION_DESIRE_HIGH, creep, "Q-推线AoE"
				end
				if Fu.IsKeyWordUnit("ranged", creep) and Fu.WillKillTarget(creep, totalDamage, damageType, castPoint) then
					return BOT_ACTION_DESIRE_HIGH, creep, "Q-推线补刀远程"
				end
				if
					Fu.IsKeyWordUnit("melee", creep)
					and Fu.WillKillTarget(creep, totalDamage, damageType, castPoint)
					and (Fu.GetAroundTargetEnemyUnitCount(creep, radius) >= 2 or mpRatio > 0.8)
				then
					return BOT_ACTION_DESIRE_HIGH, creep, "Q-推线补刀近战"
				end
			end
		end
	end
	if bot:GetActiveMode() == BOT_MODE_ROSHAN and bot:GetMana() >= 600 then
		if Fu.IsRoshan(botTarget) and Fu.GetHP(botTarget) > 0.2 and Fu.IsInRange(bot, botTarget, baseCastRange) then
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, baseCastRange) and Fu.IsAttacking(bot) then
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end
	if bot:WasRecentlyDamagedByAnyHero(3.0) and bot:GetActiveMode() ~= BOT_MODE_RETREAT and #enemiesInRange >= 1 and abilityLevel >= 4 then
		for _, enemyHero in pairs(enemiesInRange) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.IsInRange(bot, enemyHero, baseCastRange)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
				and bot:IsFacingLocation(enemyHero:GetLocation(), 45)
			then
				return BOT_ACTION_DESIRE_HIGH, enemyHero, "Q-保护自己:" .. Fu.Chat.GetNormName(enemyHero)
			end
		end
	end
	if
		(#nearbyEnemies > 0 or bot:WasRecentlyDamagedByAnyHero(3.0))
		and (bot:GetActiveMode() ~= BOT_MODE_RETREAT or #nearbyAllies >= 2)
		and #enemiesInRange >= 1
		and abilityLevel >= 4
		and bot:GetMana() > manaReserve
	then
		for _, enemyHero in pairs(enemiesInRange) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.IsInRange(bot, enemyHero, baseCastRange)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
			then
				return BOT_ACTION_DESIRE_HIGH, enemyHero, "Q-消耗敌人:" .. Fu.Chat.GetNormName(enemyHero)
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderW()
	if not frostShieldAbility:IsFullyCastable() then
		return 0
	end
	local abilityLevel = frostShieldAbility:GetLevel()
	local castRange = frostShieldAbility:GetCastRange() + aetherRange
	local castPoint = frostShieldAbility:GetCastPoint()
	local manaCost = frostShieldAbility:GetManaCost()
	local damage = frostShieldAbility:GetAbilityDamage()
	local damageType = DAMAGE_TYPE_MAGICAL
	local alliesInRange = Fu.GetAlliesNearLoc(bot:GetLocation(), castRange + 50)
	local radius = frostShieldAbility:GetSpecialValueInt("radius")
	if Fu.IsInTeamFight(bot, 900) then
		local bestAlly = nil
		local maxThreat = 39
		for _, allyHero in pairs(alliesInRange) do
			local allyEnemies = Fu.GetNearbyHeroes(allyHero, 1600, true, BOT_MODE_NONE)
			local allyEnemyCreeps = allyHero:GetNearbyCreeps(1000, true)
			local threat = 0
			for _, enemyHero in pairs(allyEnemies) do
				if enemyHero:GetAttackTarget() == allyHero or enemyHero:IsFacingLocation(allyHero:GetLocation(), 12) then
					threat = threat + 30
				end
			end
			for _, creep in pairs(allyEnemyCreeps) do
				if creep:GetAttackTarget() == allyHero then
					threat = threat + 10
				end
			end
			if threat > maxThreat then
				bestAlly = allyHero
				maxThreat = threat
			end
		end
		if bestAlly ~= nil then
			return BOT_ACTION_DESIRE_HIGH, bestAlly, "W-团战保护:" .. maxThreat
		end
	end
	if talent7:IsTrained() then
		local allyTowers = bot:GetNearbyTowers(castRange + 50, false)
		for _, building in pairs(allyTowers) do
			if
				Fu.IsValidBuilding(building)
				and building:GetMaxHealth() - building:GetHealth() > 600
				and (#nearbyEnemies == 0 or nearbyEnemies[1]:GetAttackTarget() == building)
			then
				return BOT_ACTION_DESIRE_HIGH, building, "W-修塔"
			end
		end
		local allyBarracks = bot:GetNearbyBarracks(castRange + 50, false)
		for _, building in pairs(allyBarracks) do
			if
				Fu.IsValidBuilding(building)
				and building:GetMaxHealth() - building:GetHealth() > 800
				and (#nearbyEnemies == 0 or nearbyEnemies[1]:GetAttackTarget() == building)
			then
				return BOT_ACTION_DESIRE_HIGH, building, "W-修兵营"
			end
		end
		local ancient = GetAncient(GetTeam())
		if Fu.IsInRange(bot, ancient, castRange) and ancient:GetMaxHealth() - ancient:GetHealth() > 1000 then
			return BOT_ACTION_DESIRE_HIGH, ancient, "W-修基地"
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if Fu.IsRoshan(botTarget) and botTarget:GetAttackTarget() ~= nil then
			local roshanTarget = botTarget:GetAttackTarget()
			for _, allyHero in pairs(alliesInRange) do
				if roshanTarget == allyHero then
					return BOT_ACTION_DESIRE_HIGH, allyHero, "W-肉山"
				end
			end
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, 800) and Fu.IsAttacking(bot) then
			local weakestUnit = Fu.GetAttackableWeakestUnit(bot, castRange, true, false)
			if weakestUnit ~= nil then
				return BOT_ACTION_DESIRE_HIGH, weakestUnit, ""
			end
		end
	end
	for _, allyHero in pairs(alliesInRange) do
		local allyEnemies = Fu.GetNearbyHeroes(allyHero, radius - 20, true, BOT_MODE_NONE)
		if #allyEnemies >= 3 then
			return BOT_ACTION_DESIRE_HIGH, allyHero, "W-Aoe:" .. #allyEnemies
		end
		if Fu.IsRetreating(allyHero) then
			for _, enemyHero in pairs(allyEnemies) do
				if
					Fu.IsValidHero(enemyHero)
					and Fu.CanCastOnMagicImmune(enemyHero)
					and (
						allyHero == enemyHero:GetAttackTarget()
						or allyHero:GetActiveModeDesire() > 0.85
						or allyHero:WasRecentlyDamagedByHero(enemyHero, 4.0)
					)
				then
					return BOT_ACTION_DESIRE_HIGH, allyHero, "W-保护队友:" .. Fu.Chat.GetNormName(enemyHero)
				end
			end
		end
		-- Ally (or Lich) being hit by a hero outside a team fight and not retreating, e.g. harassed in
		-- lane: no case covered it. Frost Shield cuts 45-60% of attack damage (Valve data).
		if
			Fu.IsValidHero(allyHero)
			and allyHero:WasRecentlyDamagedByAnyHero(1.5)
			and Fu.GetHP(allyHero) < 0.6
			and #(Fu.GetNearbyHeroes(allyHero, 700, true, BOT_MODE_NONE) or {}) >= 1
			and not allyHero:HasModifier("modifier_lich_frost_shield")
		then
			X.LogLich("shield-harassed", allyHero)
			return BOT_ACTION_DESIRE_HIGH, allyHero, "W-harassed"
		end
		if Fu.IsGoingOnSomeone(allyHero) then
			local allyTarget = Fu.GetProperTarget(allyHero)
			if Fu.IsValidHero(allyTarget) and Fu.CanCastOnNonMagicImmune(allyTarget) and Fu.IsInRange(allyHero, allyTarget, radius) then
				if allyTarget:GetAttackTarget() == allyHero then
					return BOT_ACTION_DESIRE_HIGH, allyHero, "W-保护被攻击队友" .. Fu.Chat.GetNormName(allyTarget)
				end
				if
					allyHero:IsFacingLocation(allyTarget:GetLocation(), 20)
					and not allyTarget:IsFacingLocation(allyHero:GetLocation(), 120)
					and Fu.IsRunning(allyTarget)
				then
					return BOT_ACTION_DESIRE_HIGH, allyHero, "W-辅助队友进攻" .. Fu.Chat.GetNormName(allyTarget)
				end
			end
		end
		-- Waves and camps: the shield's tick damages everything around the ally. It needed
		-- level 4, at most two allies, and 4+ creeps, and defending was not covered at all
		-- (game 016: never cast while defending top). Now level 2+, pushing or defending, 3+
		-- creeps around the ally, any number of allies, mana kept as before.
		if (Fu.IsPushing(allyHero) or Fu.IsDefending(allyHero)) and abilityLevel >= 2 and Fu.IsAllowedToSpam(bot, manaCost) and #nearbyEnemies == 0 and CreepManaOk() then
			local laneCreeps = allyHero:GetNearbyLaneCreeps(radius, true)
			if #laneCreeps >= 3 and not laneCreeps[1]:HasModifier("modifier_fountain_glyph") then
				return BOT_ACTION_DESIRE_HIGH, allyHero, "W-wave" .. #laneCreeps
			end
		end
		if Fu.IsFarming(allyHero) and abilityLevel >= 2 and Fu.IsAllowedToSpam(bot, manaCost) and #nearbyEnemies == 0 and CreepManaOk() then
			local neutralCreeps = allyHero:GetNearbyNeutralCreeps(radius)
			if #neutralCreeps >= 3 and neutralCreeps[1]:GetMagicResist() < 0.3 then
				return BOT_ACTION_DESIRE_HIGH, allyHero, "W-camp" .. #neutralCreeps
			end
		end
		if talent7:IsTrained() and Fu.IsAllowedToSpam(bot, manaCost) and #nearbyEnemies == 0 then
			if Fu.GetHP(allyHero) < 0.38 then
				return BOT_ACTION_DESIRE_HIGH, allyHero, "W-治疗队友:" .. Fu.Chat.GetNormName(allyHero)
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderE()
	if not sinisterGazeAbility:IsFullyCastable() then
		return 0
	end
	local abilityLevel = sinisterGazeAbility:GetLevel()
	local castRange = sinisterGazeAbility:GetCastRange() + aetherRange
	if #nearbyEnemies <= 2 and castRange < 630 then
		castRange = castRange + 150
	end
	local castPoint = sinisterGazeAbility:GetCastPoint()
	local manaCost = sinisterGazeAbility:GetManaCost()
	local damage = sinisterGazeAbility:GetAbilityDamage()
	local damageType = DAMAGE_TYPE_MAGICAL
	local enemiesInRange = Fu.GetNearbyHeroes(bot, castRange + 50, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(enemiesInRange) do
		if Fu.IsValidHero(enemyHero) then
			if enemyHero:IsChanneling() and Fu.CanCastOnNonMagicImmune(enemyHero) then
				return BOT_ACTION_DESIRE_HIGH, enemyHero, "E-打断施法:" .. Fu.Chat.GetNormName(enemyHero)
			end
			if Fu.IsCastingUltimateAbility(enemyHero) and Fu.CanCastOnNonMagicImmune(enemyHero) then
				return BOT_ACTION_DESIRE_HIGH, enemyHero, "E-打断大招:" .. Fu.Chat.GetNormName(enemyHero)
			end
		end
	end
	if Fu.IsInTeamFight(bot, 900) then
		local enemies = Fu.GetEnemyList(bot, castRange + 420)
		if #enemies >= 2 or #nearbyAllies >= 3 then
			local mostDangerousEnemy = nil
			local maxDamageToBot = 0
			-- In-range filter added: the best one was picked from castRange+420 and then dropped when out of
			-- range, so Gaze was skipped while a reachable enemy stood next to Lich.
			for _, enemyHero in pairs(enemies) do
				if
					Fu.IsValid(enemyHero)
					and Fu.IsInRange(bot, enemyHero, castRange + 50)
					and Fu.CanCastOnNonMagicImmune(enemyHero)
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
			if mostDangerousEnemy ~= nil and Fu.IsInRange(bot, mostDangerousEnemy, castRange + 50) then
				return BOT_ACTION_DESIRE_HIGH, mostDangerousEnemy, "E-团战控制:" .. Fu.Chat.GetNormName(mostDangerousEnemy)
			end
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidHero(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange + 32)
			and not Fu.IsInRange(bot, botTarget, castRange - 200)
			and bot:IsFacingLocation(botTarget:GetLocation(), 30)
			and not botTarget:IsFacingLocation(bot:GetLocation(), 100)
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget, "E-攻击:" .. Fu.Chat.GetNormName(botTarget)
		end
	end
	if Fu.IsDoingRoshan(bot) and mpRatio > 0.6 then
		if
			Fu.IsRoshan(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and not Fu.IsDisabled(botTarget)
			and not botTarget:IsDisarmed()
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget, "E-肉山"
		end
	end
	-- Mana: Gaze drains 25% of the target's current mana (Valve data). When Frost Blast and Frost
	-- Shield have used the pool up, take it from an enemy hero, or a ranged creep with no hero near.
	-- Not under an enemy tower or when outnumbered: he stands still for the channel.
	local blastCost = frostBlastAbility:GetManaCost() + frostShieldAbility:GetManaCost()
	if bot:GetMana() < blastCost and #(bot:GetNearbyTowers(900, true) or {}) == 0 then
		local foes = Fu.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE) or {}
		local friends = Fu.GetNearbyHeroes(bot, 1200, false, BOT_MODE_NONE) or {}
		local best, bestMana = nil, 150
		for _, enemyHero in pairs(foes) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and Fu.IsInRange(bot, enemyHero, castRange)
				and enemyHero:GetMana() > bestMana
			then
				best, bestMana = enemyHero, enemyHero:GetMana()
			end
		end
		if best ~= nil and #friends >= #foes then
			X.LogLich("gaze-mana", best)
			return BOT_ACTION_DESIRE_HIGH, best, "E-mana"
		end
		if #foes == 0 then
			for _, creep in pairs(bot:GetNearbyLaneCreeps(castRange, true) or {}) do
				if Fu.IsValid(creep) and Fu.IsKeyWordUnit("ranged", creep) and creep:GetMana() >= 60 then
					X.LogLich("gaze-mana-creep", creep)
					return BOT_ACTION_DESIRE_HIGH, creep, "E-mana-creep"
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderR()
	if not chainFrostAbility:IsFullyCastable() then
		return 0
	end
	local abilityLevel = chainFrostAbility:GetLevel()
	local castRange = chainFrostAbility:GetCastRange() + aetherRange
	local castPoint = chainFrostAbility:GetCastPoint()
	local manaCost = chainFrostAbility:GetManaCost()
	local damage = chainFrostAbility:GetSpecialValueInt("damage")
	if talent5:IsTrained() then
		damage = damage + talent5:GetSpecialValueInt("value")
	end
	local damageType = DAMAGE_TYPE_MAGICAL
	local enemiesInRange = Fu.GetNearbyHeroes(bot, castRange + 50, true, BOT_MODE_NONE)
	local bounceRadius = chainFrostAbility:GetSpecialValueInt("jump_range") / 2
	for _, enemyHero in pairs(enemiesInRange) do
		if Fu.IsValidHero(enemyHero) and Fu.CanCastOnNonMagicImmune(enemyHero) and Fu.CanCastOnTargetAdvanced(enemyHero) then
			local delay = castPoint + GetUnitToUnitDistance(bot, enemyHero) / 850
			if Fu.WillMagicKillTarget(bot, enemyHero, damage, delay) then
				return BOT_ACTION_DESIRE_HIGH, enemyHero, "R-直接击杀:" .. Fu.Chat.GetNormName(enemyHero)
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
					and Fu.IsInLocRange(enemyHero, aoeLocation, bounceRadius)
				then
					return BOT_ACTION_DESIRE_HIGH, enemyHero, "R-Aoe:" .. Fu.Chat.GetNormName(enemyHero)
				end
			end
		end
	end
	-- Our Ice Spire beside a lone target: the orb bounces between them (Valve data: Chain Frost can
	-- bounce to the Spire when no other enemy is in range).
	if Fu.IsValidHero(botTarget) and Fu.CanCastOnNonMagicImmune(botTarget) and Fu.IsInRange(bot, botTarget, castRange) then
		local spire = X.GetOwnSpire()
		if spire ~= nil and GetUnitToUnitDistance(spire, botTarget) <= chainFrostAbility:GetSpecialValueInt("jump_range") then
			bot._chainAt = DotaTime()
			X.LogLich("chain-spire", botTarget)
			return BOT_ACTION_DESIRE_HIGH, botTarget, "R-spire"
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		if
			Fu.IsValidHero(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.CanCastOnTargetAdvanced(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
		then
			local targetAllyCreeps = botTarget:GetNearbyCreeps(bounceRadius * 1.9, false)
			local targetAllies = Fu.GetNearbyHeroes(botTarget, bounceRadius * 1.9, false, BOT_MODE_NONE)
			if #targetAllyCreeps >= 2 or #targetAllies >= 2 or hpRatio < 0.28 then
				return BOT_ACTION_DESIRE_HIGH, botTarget, "R-攻击:" .. Fu.Chat.GetNormName(botTarget)
			end
		end
	end
	if Fu.IsRetreating(bot) then
		for _, enemyHero in pairs(enemiesInRange) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.CanCastOnTargetAdvanced(enemyHero)
				and bot:WasRecentlyDamagedByHero(enemyHero, 4.0)
			then
				local targetAllyCreeps = enemyHero:GetNearbyCreeps(bounceRadius * 1.9, false)
				local targetAllies = Fu.GetNearbyHeroes(enemyHero, bounceRadius * 1.9, false, BOT_MODE_NONE)
				if #targetAllyCreeps + #targetAllies >= 2 or hpRatio < 0.38 then
					return BOT_ACTION_DESIRE_HIGH, enemyHero, "R-撤退时减速:" .. Fu.Chat.GetNormName(enemyHero)
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderAS()
	if not iceSpireAbility:IsTrained() or not iceSpireAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local radius = 500
	local castRange = iceSpireAbility:GetCastRange()
	local castPoint = iceSpireAbility:GetCastPoint()
	local manaCost = iceSpireAbility:GetManaCost()
	if Fu.IsRetreating(bot) then
		local enemiesInRadius = Fu.GetNearbyHeroes(bot, radius, true, BOT_MODE_NONE)
		local nearestEnemy = enemiesInRadius[1]
		if Fu.IsValidHero(nearestEnemy) and Fu.CanCastOnNonMagicImmune(nearestEnemy) then
			return BOT_ACTION_DESIRE_HIGH, bot:GetLocation()
		end
	end
	if Fu.IsInTeamFight(bot, 1400) then
		local aoeLocation = Fu.GetAoeEnemyHeroLocation(bot, castRange, radius, 2)
		if aoeLocation ~= nil then
			return BOT_ACTION_DESIRE_HIGH, aoeLocation
		end
	end
	if Fu.IsGoingOnSomeone(bot) then
		local target = Fu.GetProperTarget(bot)
		if Fu.IsValidHero(target) and Fu.IsInRange(bot, target, castRange) and Fu.CanCastOnNonMagicImmune(target) then
			return BOT_ACTION_DESIRE_HIGH, target:GetLocation()
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
-- [OHA-LICH] lines, at most once per 3s per kind.
function X.LogLich(kind, target)
	bot._lichLogAt = bot._lichLogAt or {}
	if DotaTime() < (bot._lichLogAt[kind] or -999) then
		return
	end
	bot._lichLogAt[kind] = DotaTime() + 3
	pcall(print, string.format(
		"[OHA-LICH] t=%.0f %s target=%s mp=%.2f",
		DotaTime(),
		kind,
		target ~= nil and (string.gsub(target:GetUnitName(), "npc_dota_hero_", "")) or "-",
		Fu.GetMP(bot)
	))
end
-- Frost Shield on our Ice Spire: each shield tick heals it by one hero hit (Valve data). Cast
-- when the spire has lost HP (a Chain Frost bounce costs it a hit, so that is covered too) or
-- enemy heroes or creeps are within 700 of it, and no shield of ours is on it. It used to
-- need an enemy hero within 700 and ran after Frost Blast, so a spire chipped by creeps or by the
-- Chain Frost bounce was never shielded. He walks up to 400 extra to reach it, not when retreating.
function X.ConsiderSpireShield()
	if not frostShieldAbility:IsFullyCastable() then
		return nil
	end
	local spire = X.GetOwnSpire()
	if spire == nil then
		return nil
	end
	local reach = frostShieldAbility:GetCastRange() + aetherRange + (Fu.IsRetreating(bot) and 0 or 400)
	if GetUnitToUnitDistance(bot, spire) > reach then
		return nil
	end
	local duration = frostShieldAbility:GetSpecialValueFloat("duration")
	if duration == nil or duration <= 0 then
		duration = 4
	end
	if DotaTime() < (bot._spireShieldAt or -999) + duration then
		return nil
	end
	local damaged = spire:GetHealth() < spire:GetMaxHealth()
	local loc = spire:GetLocation()
	local busy = #(Fu.GetEnemiesNearLoc(loc, 700) or {}) >= 1 or #(spire:GetNearbyCreeps(700, true) or {}) >= 1
	if not (damaged or busy) then
		return nil
	end
	bot._spireShieldAt = DotaTime()
	X.LogLich(damaged and "shield-spire damaged" or "shield-spire", nil)
	return spire
end
-- Our own Ice Spire, if one stands.
function X.GetOwnSpire()
	for _, unit in pairs(GetUnitList(UNIT_LIST_ALLIES) or {}) do
		if Fu.IsValid(unit) and unit:GetUnitName() == "npc_dota_lich_ice_spire" then
			return unit
		end
	end
	return nil
end
-- Ice Spire within Chain Frost's bounce range of a lone target (no other enemy hero within 1200),
-- when Chain Frost is up with mana for both. Returns the spot or nil.
function X.ConsiderSpireCombo()
	if not iceSpireAbility:IsTrained() or iceSpireAbility:IsHidden() or not iceSpireAbility:IsFullyCastable() or not chainFrostAbility:IsFullyCastable() then
		return nil
	end
	if bot:GetMana() < iceSpireAbility:GetManaCost() + chainFrostAbility:GetManaCost() or X.GetOwnSpire() ~= nil then
		return nil
	end
	if not Fu.IsGoingOnSomeone(bot) or not Fu.IsValidHero(botTarget) or Fu.IsSuspiciousIllusion(botTarget) then
		return nil
	end
	if not Fu.IsInRange(bot, botTarget, iceSpireAbility:GetCastRange()) then
		return nil
	end
	local others = Fu.GetNearbyHeroes(botTarget, 1200, false, BOT_MODE_NONE) or {}
	if #others > 1 then
		return nil
	end
	-- 250 from the target toward Lich: inside the 550 bounce range and in the spire's slow.
	local spot = Fu.Utils.GetOffsetLocationTowardsTargetLocation(botTarget:GetLocation(), bot:GetLocation(), 250)
	X.LogLich("spire-combo", botTarget)
	return spot
end
-- Scepter only: while channeling Sinister Gaze, cast Ice Spire, Chain Frost or Frost Shield on the
-- spire. Orders are sent directly; whether the engine keeps the channel is what the log will show.
function X.ConsiderGazeWeave()
	if not bot:HasScepter() or not bot:IsChanneling() or DotaTime() - (bot._gazeAt or -99) > 2.5 then
		return false
	end
	if bot:IsStunned() or bot:IsSilenced() or bot:IsHexed() then
		return false
	end
	local target = bot._gazeTarget
	if not Fu.IsValidHero(target) then
		return false
	end
	if iceSpireAbility:IsTrained() and not iceSpireAbility:IsHidden() and iceSpireAbility:IsFullyCastable() and X.GetOwnSpire() == nil and Fu.IsInRange(bot, target, iceSpireAbility:GetCastRange()) then
		X.LogLich("gaze-weave-spire", target)
		bot:Action_UseAbilityOnLocation(iceSpireAbility, target:GetLocation())
		return true
	end
	-- Chain Frost during the Gaze only when it is worth its cooldown: another enemy within the
	-- bounce range of the target, our Ice Spire beside it, or the target below 50% HP. It went on
	-- a lone, healthy Techies at 54:40 (game 017).
	local jump = chainFrostAbility:GetSpecialValueInt("jump_range")
	if jump == nil or jump <= 0 then
		jump = 550
	end
	local others = 0
	for _, otherEnemy in pairs(Fu.GetNearbyHeroes(target, jump, false, BOT_MODE_NONE) or {}) do
		if otherEnemy ~= target and Fu.IsValidHero(otherEnemy) then
			others = others + 1
		end
	end
	local spireNear = X.GetOwnSpire() ~= nil and GetUnitToUnitDistance(X.GetOwnSpire(), target) <= jump
	local chainWorth = others >= 1 or spireNear or Fu.GetHP(target) < 0.5
	if chainWorth and chainFrostAbility:IsFullyCastable() and Fu.IsInRange(bot, target, chainFrostAbility:GetCastRange()) then
		X.LogLich("gaze-weave-chain", target)
		bot._chainAt = DotaTime()
		bot:Action_UseAbilityOnEntity(chainFrostAbility, target)
		return true
	end
	local spire = X.GetOwnSpire()
	if spire ~= nil and frostShieldAbility:IsFullyCastable() and GetUnitToUnitDistance(bot, spire) <= frostShieldAbility:GetCastRange() then
		X.LogLich("gaze-weave-shield", nil)
		bot:Action_UseAbilityOnEntity(frostShieldAbility, spire)
		return true
	end
	return false
end
function X.ConsiderSacrifice()
	if not Fu.CanCastAbility(sacrificeAbility) then
		return BOT_ACTION_DESIRE_NONE
	end
	if bot:HasModifier("modifier_rune_regen") or bot:HasModifier("modifier_fountain_aura_buff") then
		return BOT_ACTION_DESIRE_NONE
	end
	local castRange = sacrificeAbility:GetCastRange()
	-- Both charges up (2 max, 120s each, Valve data): use one now even at full mana. It denies an
	-- allied creep and gives 69% of its experience. Prefer a creep the enemy is about to kill.
	-- Charges from our own tracker (the API has no ability-charge read). Not with an enemy hero
	-- near: a fight wants Chain Frost, not a 0.4s cast on his own creep.
	local charges = X.SacrificeCharges()
	-- In lane an enemy hero is almost always within 1200, which blocked this rule; 600 is a hero
	-- right on him.
	local enemyNear = #(Fu.GetNearbyHeroes(bot, 600, true, BOT_MODE_NONE) or {}) > 0
	if charges ~= nil and charges >= 2 and not enemyNear and not Fu.IsInTeamFight(bot, 1200) then
		local deny, denyHp, any, anyHp = nil, 0.4, nil, 0
		for _, creep in pairs(bot:GetNearbyLaneCreeps(Min(castRange + 300, 1600), false) or {}) do
			if Fu.IsValid(creep) and Fu.CanBeAttacked(creep) then
				local hp = creep:GetHealth() / math.max(1, creep:GetMaxHealth())
				if hp < denyHp then
					deny, denyHp = creep, hp
				end
				if creep:GetHealth() > anyHp then
					any, anyHp = creep, creep:GetHealth()
				end
			end
		end
		local pick = deny or any
		if pick ~= nil then
			X.LogLich((deny ~= nil and "sacrifice-deny" or "sacrifice-full") .. " charges=" .. tostring(charges), nil)
			return BOT_ACTION_DESIRE_HIGH, pick
		end
	end
	-- Both charges up but none spent: say why, at most every 15s (game 014: 2 charges sat for
	-- 118s and 174s after laning).
	if charges ~= nil and charges >= 2 and DotaTime() >= (bot._sac2SkipLogAt or -999) then
		bot._sac2SkipLogAt = DotaTime() + 15
		local why = enemyNear and "enemy-within-600"
			or Fu.IsInTeamFight(bot, 1200) and "team-fight"
			or "no-allied-lane-creep-in-" .. tostring(Min(castRange + 300, 1600))
		pcall(print, string.format("[OHA-LICH] t=%.0f sacrifice2-skip why=%s mp=%.2f", DotaTime(), why, Fu.GetMP(bot)))
	end
	-- Mana (below 50%): 42% of the creep's current HP (Valve data), so the creep with the most HP,
	-- siege creeps included (they come back as lane creeps). The old per-level bonus is not in the
	-- data and is gone.
	local manaRestorePct = sacrificeAbility:GetSpecialValueInt("active_mana_restore_pct_of_health") / 100
	local allyLaneCreeps = bot:GetNearbyLaneCreeps(Min(castRange + 300, 1600), false)
	-- Game 014: with a charge and 11-14% mana he waited 85s, because 150 mana needs a creep with
	-- 357+ HP and laning creeps rarely have that. Now 100+ below 50% mana, any 40+ below 25%.
	local mp = Fu.GetMP(bot)
	if mp < 0.5 then
		local need = mp < 0.25 and 40 or 100
		local bestCreep = nil
		local bestGain = 0
		for _, creep in pairs(allyLaneCreeps) do
			if Fu.IsValid(creep) and Fu.CanBeAttacked(creep) then
				local gain = creep:GetHealth() * manaRestorePct
				if gain > bestGain then
					bestCreep = creep
					bestGain = gain
				end
			end
		end
		if bestCreep ~= nil and bestGain < need then
			if DotaTime() >= (bot._sacSkipLogAt or -999) then
				bot._sacSkipLogAt = DotaTime() + 10
				pcall(print, string.format(
					"[OHA-LICH] t=%.0f sacrifice-skip best=%.0f need=%d creeps=%d mp=%.2f",
					DotaTime(), bestGain, need, #allyLaneCreeps, mp
				))
			end
			bestCreep = nil
		end
		if bestCreep then
			X.LogLich("sacrifice-mana charges=" .. tostring(charges) .. " gain=" .. string.format("%.0f", bestGain), nil)
			return BOT_ACTION_DESIRE_HIGH, bestCreep
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
return X
