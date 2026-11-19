-- Clinkz: skill build, item build, and ability use for this hero.
local X = {}
local bot = GetBot()
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local AbilityContext = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local Minion = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local sTalentList = Fu.Skill.GetTalentList(bot)
local sAbilityList = Fu.Skill.GetAbilityList(bot)
local sRole = Fu.Item.GetRoleItemsBuyList(bot)
local tTalentTreeList = {
	{ ["t25"] = { 0, 10 }, ["t20"] = { 10, 0 }, ["t15"] = { 0, 10 }, ["t10"] = { 0, 10 } },
	{ ["t25"] = { 0, 10 }, ["t20"] = { 10, 0 }, ["t15"] = { 0, 10 }, ["t10"] = { 0, 10 } },
}
-- tAllAbilityBuildList[2]: Skeleton Walk (ultimate) moved to entry 11 (level 12); it sat at entry 12 (level 13), a level late.
local tAllAbilityBuildList =
	{ { 2, 3, 2, 3, 3, 6, 2, 2, 1, 1, 6, 1, 1, 3, 6 }, { 2, 3, 2, 3, 3, 6, 2, 2, 1, 1, 6, 1, 1, 3, 6 } }
local nAbilityBuildList
local nTalentBuildList
if sRole == "pos_1" then
	nAbilityBuildList = tAllAbilityBuildList[1]
	nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList[1])
else
	nAbilityBuildList = tAllAbilityBuildList[2]
	nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList[2])
end
local sRoleItemsBuyList = {}
sRoleItemsBuyList["pos_1"] = {
	"item_tango",
	"item_double_branches",
	"item_quelling_blade",
	"item_magic_wand",
	"item_falcon_blade",
	"item_power_treads",
	"item_desolator",
	"item_orchid",
	"item_dragon_lance",
	"item_aghanims_shard",
	"item_black_king_bar",
	"item_bloodthorn",
	"item_force_staff",
	"item_hurricane_pike",
	"item_greater_crit",
	"item_moon_shard",
	"item_butterfly",
	"item_ultimate_scepter",
	"item_ultimate_scepter_2",
}
sRoleItemsBuyList["pos_2"] = {
	"item_mid_outfit",
	"item_dragon_lance",
	"item_desolator",
	"item_orchid",
	-- removed a second item_dragon_lance here: one lance already listed above, and Hurricane Pike takes only one
	"item_aghanims_shard",
	"item_black_king_bar",
	"item_bloodthorn",
	"item_force_staff",
	"item_hurricane_pike",
	"item_sheepstick",
	"item_moon_shard",
	"item_butterfly",
	"item_ultimate_scepter",
	"item_ultimate_scepter_2",
}
sRoleItemsBuyList["pos_3"] = sRoleItemsBuyList["pos_1"]
sRoleItemsBuyList["pos_4"] = sRoleItemsBuyList["pos_1"]
sRoleItemsBuyList["pos_5"] = sRoleItemsBuyList["pos_1"]
X["sBuyList"] = sRoleItemsBuyList[sRole]
X["sSellList"] = {
	"item_hurricane_pike",
	"item_urn_of_shadows",
	"item_mjollnir",
	"item_magic_wand",
	"item_hand_of_midas",
	"item_urn_of_shadows",
	"item_greater_crit",
	"item_hand_of_midas",
	"item_greater_crit",
	"item_falcon_blade",
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
local strafeAbility = SafeAbility(bot:GetAbilityByName("clinkz_strafe"), "clinkz_strafe", "clinkz")
local deathPactAbility = SafeAbility(bot:GetAbilityByName("clinkz_death_pact"), "clinkz_death_pact", "clinkz")
local burningBarrageAbility =
	SafeAbility(bot:GetAbilityByName("clinkz_burning_barrage"), "clinkz_burning_barrage", "clinkz")
local burningArmyAbility = SafeAbility(bot:GetAbilityByName("clinkz_burning_army"), "clinkz_burning_army", "clinkz")
local skeletonWalkAbility = SafeAbility(bot:GetAbilityByName("clinkz_wind_walk"), "clinkz_wind_walk", "clinkz")
local searingArrowsAbility =
	SafeAbility(bot:GetAbilityByName("clinkz_searing_arrows"), "clinkz_searing_arrows", "clinkz")
local strafeDesire
local deathPactDesire, deathPactTarget
local burningBarrageDesire, burningBarrageLocation
local burningArmyDesire, burningArmyLocation
local skeletonWalkDesire
local searingArrowsDesire, searingArrowsTarget
local botTarget
local isGoingOnSomeone
local isAttacking
local mpRatio
function X.SkillsComplement()
	if Fu.CanNotUseAbility(bot) then
		return
	end
	local context = AbilityContext.Build(bot)
	isGoingOnSomeone = context.isEngaging
	isAttacking = Fu.IsAttacking(bot)
	mpRatio = context.mp
	botTarget = context.target
	local okH, hunted = pcall(X.HuntStep)
	if okH and hunted then
		return
	end
	if not okH then
		bot._clinkzHuntUntil = nil
		if DotaTime() >= (bot._huntErrAt or -999) then
			bot._huntErrAt = DotaTime() + 10
			pcall(print, string.format("[OHA-CLINKZ] t=%.0f hunt error %s", DotaTime(), tostring(hunted)))
		end
	end
	skeletonWalkDesire = X.ConsiderSkeletonWalk()
	if skeletonWalkDesire > 0 then
		-- Soul Ring first when he has it (maintainer's hunt), so the walk and the reveal have mana.
		local ring = X.ReadyItem("item_soul_ring")
		if ring ~= nil and Fu.GetHP(bot) > 0.4 then
			X.LogHunt("soul-ring", nil)
			bot:Action_UseAbility(ring)
			bot:ActionQueue_UseAbility(skeletonWalkAbility)
			return
		end
		bot:Action_UseAbility(skeletonWalkAbility)
		return
	end
	searingArrowsDesire, searingArrowsTarget = X.ConsiderSearingArrows()
	if searingArrowsDesire > 0 then
		bot:Action_UseAbilityOnEntity(searingArrowsAbility, searingArrowsTarget)
		return
	end
	burningBarrageDesire, burningBarrageLocation = X.ConsiderBurningBarrage()
	if burningBarrageDesire > 0 then
		bot:Action_UseAbilityOnLocation(burningBarrageAbility, burningBarrageLocation)
		return
	end
	strafeDesire = X.ConsiderStrafe()
	if strafeDesire > 0 then
		bot._strafeAt = DotaTime()
		bot:Action_UseAbility(strafeAbility)
		return
	end
	deathPactDesire, deathPactTarget = X.ConsiderDeathPact()
	if deathPactDesire > 0 then
		bot:Action_UseAbilityOnEntity(deathPactAbility, deathPactTarget)
		return
	end
	burningArmyDesire, burningArmyLocation = X.ConsiderBurningArmy()
	if burningArmyDesire > 0 then
		bot:Action_UseAbilityOnLocation(burningArmyAbility, burningArmyLocation)
		return
	end
end
-- The maintainer's Clinkz hunt (#94): Soul Ring, Skeleton Walk, eat the biggest creep in range while invisible
-- (Death Pact doesn't break Skeleton Walk, datafeed), walk point blank to the target, then reveal with Orchid /
-- Bloodthorn and Strafe and shoot. Burning Barrage is for groups.
function X.ReadyItem(name)
	local slot = bot:FindItemSlot(name)
	if slot < 0 or slot > 5 then
		return nil
	end
	local item = bot:GetItemInSlot(slot)
	if item ~= nil and not item:IsNull() and item:IsFullyCastable() then
		return item
	end
	return nil
end
function X.LogHunt(step, target)
	if DotaTime() < (bot._huntLogAt or -999) and step == bot._huntLogStep then
		return
	end
	bot._huntLogAt = DotaTime() + 3
	bot._huntLogStep = step
	pcall(
		print,
		string.format(
			"[OHA-CLINKZ] t=%.0f hunt step=%s target=%s hp=%.2f",
			DotaTime(),
			step,
			target ~= nil and (string.gsub(target:GetUnitName(), "npc_dota_hero_", "")) or "-",
			Fu.GetHP(bot)
		)
	)
end
-- A lone enemy hero worth a hunt (#94, maintainer): visible, within 2500, no other enemy hero within 1200 of it
-- and none of its towers within 900. Clinkz above 60% HP, not retreating, with mana for the walk, a pact and the
-- silence (game files: Skeleton Walk 80/105/130 mana, 35/40/45s, +25/35/45% speed; Death Pact 50), and Strafe or
-- a silence item ready. The weakest such hero. Not for 15s after a cancelled hunt.
function X.FindPrey()
	if
		Fu.GetHP(bot) < 0.6
		or Fu.IsRetreating(bot)
		or DotaTime() < (bot._huntOffUntil or -999)
		or bot:GetMana() < skeletonWalkAbility:GetManaCost() + 150
		or not (strafeAbility:IsFullyCastable() or X.ReadyItem("item_bloodthorn") or X.ReadyItem("item_orchid"))
	then
		return nil
	end
	local best, bestHp = nil, 2
	for _, enemyHero in pairs(GetUnitList(UNIT_LIST_ENEMY_HEROES) or {}) do
		if
			Fu.IsValidHero(enemyHero)
			and enemyHero:CanBeSeen()
			and not Fu.IsSuspiciousIllusion(enemyHero)
			and Fu.CanBeAttacked(enemyHero)
			and GetUnitToUnitDistance(bot, enemyHero) <= 2500
			and Fu.GetHP(enemyHero) < bestHp
			and #Fu.GetEnemiesNearLoc(enemyHero:GetLocation(), 1200) <= 1
			and #(enemyHero:GetNearbyTowers(900, false) or {}) == 0
		then
			best, bestHp = enemyHero, Fu.GetHP(enemyHero)
		end
	end
	return best
end
-- The hero to hunt while invisible: the engage target, else the weakest hero within 1400 that isn't covered
-- by more enemies than we have near. Kept for 6s (game 048: the target changed while he walked).
function X.HuntTarget()
	local locked = bot._huntTarget
	if
		Fu.IsValidHero(locked)
		and locked:CanBeSeen()
		and DotaTime() - (bot._huntLockAt or -999) < (bot._huntLockFor or 6)
		and GetUnitToUnitDistance(bot, locked) < (bot._huntRange or 1600)
		and Fu.GetHP(bot) >= 0.35
	then
		return locked
	end
	bot._huntTarget, bot._huntPrey, bot._huntLockFor, bot._huntRange = nil, nil, nil, nil
	-- No new target for 15s after a cancelled hunt (else the same hero is picked again next think).
	if Fu.GetHP(bot) < 0.5 or Fu.IsRetreating(bot) or DotaTime() < (bot._huntOffUntil or -999) then
		return nil
	end
	local best, bestHp = nil, 2
	if isGoingOnSomeone and Fu.IsValidHero(botTarget) and not Fu.IsSuspiciousIllusion(botTarget) then
		best = botTarget
	else
		local alliesNear = #Fu.GetAlliesNearLoc(bot:GetLocation(), 1200)
		for _, enemyHero in pairs(Fu.GetNearbyHeroes(bot, 1400, true, BOT_MODE_NONE) or {}) do
			if
				Fu.IsValidHero(enemyHero)
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and Fu.CanBeAttacked(enemyHero)
				and Fu.GetHP(enemyHero) < bestHp
				and #Fu.GetEnemiesNearLoc(enemyHero:GetLocation(), 900) <= alliesNear
			then
				best, bestHp = enemyHero, Fu.GetHP(enemyHero)
			end
		end
	end
	if best ~= nil then
		bot._huntTarget = best
		bot._huntLockAt = DotaTime()
	end
	return best
end
-- Returns true when it gave an order. In any mode while invisible (#94, game 048: 61 approaches, 2 reveals;
-- at 44:30 he showed himself at the edge of his range and the target walked out of the skeletons' attacks).
-- He walks to a point 150 past the target on its way home (its escape path), then hex, Strafe and shoot from
-- point blank. bot._clinkzHuntUntil keeps the outpost mode holding the other modes' orders meanwhile.
function X.HuntStep()
	if not bot:HasModifier("modifier_clinkz_wind_walk") then
		bot._huntTarget = nil
		return false
	end
	-- Invisible: a pact on the biggest creep in range first (heal + max HP, keeps him invisible).
	if Fu.CanCastAbility(deathPactAbility) and not bot:HasModifier("modifier_clinkz_death_pact") then
		local creep = GetMostHPCreepLevel(
			bot:GetNearbyCreeps(deathPactAbility:GetCastRange(), true),
			deathPactAbility:GetSpecialValueInt("creep_level")
		)
		if creep ~= nil and not creep:IsAncientCreep() then
			X.LogHunt("pact", nil)
			bot:Action_UseAbilityOnEntity(deathPactAbility, creep)
			return true
		end
	end
	local target = X.HuntTarget()
	if target == nil then
		bot._clinkzHuntUntil = nil
		return false
	end
	-- A hunt on a lone hero ends when it gets backup (maintainer): another enemy hero within 1200 of the target
	-- before the reveal. He stays invisible and the modes take over; no new hunt for 15s.
	if bot._huntPrey == target and #Fu.GetEnemiesNearLoc(target:GetLocation(), 1200) >= 2 then
		pcall(
			print,
			string.format(
				"[OHA-CLINKZ] t=%.0f hunt cancel why=backup target=%s dist=%d",
				DotaTime(),
				(string.gsub(target:GetUnitName(), "npc_dota_hero_", "")),
				GetUnitToUnitDistance(bot, target)
			)
		)
		bot._huntTarget, bot._huntPrey, bot._huntLockFor, bot._huntRange = nil, nil, nil, nil
		bot._huntOffUntil = DotaTime() + 15
		bot._clinkzHuntUntil = nil
		return false
	end
	-- Outnumbered around Clinkz (the ally list includes him): no hunt.
	if #Fu.GetEnemiesNearLoc(bot:GetLocation(), 1200) > #Fu.GetAlliesNearLoc(bot:GetLocation(), 1200) then
		bot._huntTarget = nil
		bot._clinkzHuntUntil = nil
		return false
	end
	local distance = GetUnitToUnitDistance(bot, target)
	if distance > 200 then
		local toFountain = Fu.GetEnemyFountain() - target:GetLocation()
		local ambush = target:GetLocation() + toFountain:Normalized() * 150
		-- Not into an enemy tower's range (700, plus a margin).
		for _, tower in pairs(bot:GetNearbyTowers(1600, true) or {}) do
			if Fu.IsValidBuilding(tower) and GetUnitToLocationDistance(tower, ambush) < 850 then
				X.LogHunt("skip-tower", target)
				bot._huntTarget = nil
				bot._clinkzHuntUntil = nil
				return false
			end
		end
		bot._clinkzHuntUntil = DotaTime() + 0.3
		X.LogHunt("approach", target)
		bot:Action_MoveToLocation(ambush)
		return true
	end
	-- Searing Arrows on for the hunt's hits (maintainer): the first attack comes before the arrow rules run.
	if searingArrowsAbility:IsTrained() and not searingArrowsAbility:GetAutoCastState() then
		searingArrowsAbility:ToggleAutoCast()
	end
	local hex = X.ReadyItem("item_bloodthorn") or X.ReadyItem("item_orchid")
	local step = nil
	if hex ~= nil and Fu.CanCastOnNonMagicImmune(target) then
		step = "reveal-" .. hex:GetName()
		-- The item ends the invisibility, so HuntStep stops next think: queue the first hit now.
		bot:Action_UseAbilityOnEntity(hex, target)
		bot:ActionQueue_AttackUnit(target, true)
	elseif strafeAbility:IsFullyCastable() then
		step = "reveal-strafe"
		bot._strafeAt = DotaTime()
		bot:Action_UseAbility(strafeAbility)
	else
		step = "reveal-attack"
		bot:Action_AttackUnit(target, true)
	end
	X.LogHunt(step, target)
	if DotaTime() >= (bot._huntRevealLogAt or -999) then
		bot._huntRevealLogAt = DotaTime() + 3
		pcall(
			print,
			string.format(
				"[OHA-CLINKZ] t=%.0f hunt reveal dist=%d target=%s by=%s",
				DotaTime(),
				distance,
				(string.gsub(target:GetUnitName(), "npc_dota_hero_", "")),
				step
			)
		)
	end
	-- Keep the other modes out until the first hit lands.
	bot._clinkzHuntUntil = DotaTime() + 0.5
	return true
end
function X.ConsiderStrafe()
	if not strafeAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
	end
	local attackRange = bot:GetAttackRange()
	if isGoingOnSomeone then
		if
			Fu.IsValidTarget(botTarget)
			and Fu.IsInRange(bot, botTarget, attackRange)
			and not Fu.IsChasingTarget(bot, botTarget)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			local alliesNearTarget = Fu.GetNearbyHeroes(botTarget, 1200, true, BOT_MODE_NONE)
			local enemiesNearTarget = Fu.GetNearbyHeroes(botTarget, 1200, false, BOT_MODE_NONE)
			if alliesNearTarget ~= nil and enemiesNearTarget ~= nil and #alliesNearTarget >= #enemiesNearTarget then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	if Fu.IsFarming(bot) then
		if isAttacking then
			local nearbyNeutralCreeps = bot:GetNearbyNeutralCreeps(1000)
			if
				nearbyNeutralCreeps ~= nil
				and (#nearbyNeutralCreeps >= 3 or #nearbyNeutralCreeps >= 2 and nearbyNeutralCreeps[1]:IsAncientCreep())
			then
				if skeletonWalkAbility:IsTrained() then
					if
						Fu.GetManaAfter(strafeAbility:GetManaCost()) * bot:GetMana() > skeletonWalkAbility:GetManaCost()
					then
						return BOT_ACTION_DESIRE_HIGH
					end
				else
					if mpRatio > 0.25 then
						return BOT_ACTION_DESIRE_HIGH
					end
				end
			end
			local nearbyLaneCreeps = bot:GetNearbyLaneCreeps(1000, true)
			if nearbyLaneCreeps ~= nil and #nearbyLaneCreeps >= 4 then
				if skeletonWalkAbility:IsTrained() then
					if
						Fu.GetManaAfter(strafeAbility:GetManaCost()) * bot:GetMana() > skeletonWalkAbility:GetManaCost()
					then
						return BOT_ACTION_DESIRE_HIGH
					end
				else
					if mpRatio > 0.25 then
						return BOT_ACTION_DESIRE_HIGH
					end
				end
			end
		end
	end
	if Fu.IsPushing(bot) or Fu.IsDefending(bot) then
		local nearbyLaneCreeps = bot:GetNearbyLaneCreeps(1000, true)
		if nearbyLaneCreeps ~= nil and #nearbyLaneCreeps >= 4 then
			if skeletonWalkAbility:IsTrained() then
				if Fu.GetManaAfter(strafeAbility:GetManaCost()) * bot:GetMana() > skeletonWalkAbility:GetManaCost() then
					return BOT_ACTION_DESIRE_HIGH
				end
			else
				if mpRatio > 0.25 then
					return BOT_ACTION_DESIRE_HIGH
				end
			end
		end
	end
	if Fu.IsDoingRoshan(bot) or Fu.IsDoingTormentor(bot) then
		if
			(Fu.IsRoshan(botTarget) or Fu.IsTormentor(botTarget))
			and Fu.IsInRange(bot, botTarget, attackRange)
			and isAttacking
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderDeathPact()
	if not deathPactAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castRange = deathPactAbility:GetCastRange()
	local maxCreepLevel = deathPactAbility:GetSpecialValueInt("creep_level")
	local nearbyCreeps = bot:GetNearbyCreeps(castRange, true)
	-- Heal (#48, game 047 10:08: Clinkz walked home at half HP). Datafeed: Death Pact heals and adds max HP
	-- (175/250/325/400 for 45s; the current HP stays when it ends), charges 1/1/2/2. Missing 80% of the gain or under
	-- 60% HP, no enemy hero within 900: eat the biggest creep in range, in any mode, even with a pact up.
	do
		local gain = deathPactAbility:GetSpecialValueInt("health_gain")
		local missing = bot:GetMaxHealth() - bot:GetHealth()
		local enemiesNear = #(bot:GetNearbyHeroes(900, true, BOT_MODE_NONE) or {})
		if (missing >= gain * 0.8 or Fu.GetHP(bot) < 0.6) and enemiesNear == 0 then
			local creep = GetMostHPCreepLevel(nearbyCreeps, maxCreepLevel)
			if creep ~= nil and not creep:IsAncientCreep() then
				pcall(
					print,
					string.format(
						"[OHA-CLINKZ] t=%.0f death-pact why=heal hp=%.2f gain=%d creep=%s",
						DotaTime(),
						Fu.GetHP(bot),
						gain,
						creep:GetUnitName()
					)
				)
				return BOT_ACTION_DESIRE_HIGH, creep
			end
		end
	end
	-- Escape (#94, game 050 10:47-10:53: he ran with Skeleton Walk from Lich and Tinker and died with no pact). Game
	-- files (7.42): charges 1/1/2/2, no cooldown, 700 range, +175-400 HP; it doesn't end Skeleton Walk. Hurt under
	-- 60% with an enemy hero within 900 while retreating or just hit: eat the biggest creep in range, pact up or not.
	if
		Fu.GetHP(bot) < 0.6
		and (Fu.IsRetreating(bot) or bot:WasRecentlyDamagedByAnyHero(2.0))
		and #(bot:GetNearbyHeroes(900, true, BOT_MODE_NONE) or {}) >= 1
	then
		local creep = GetMostHPCreepLevel(nearbyCreeps, maxCreepLevel)
		if creep ~= nil and not creep:IsAncientCreep() then
			pcall(
				print,
				string.format(
					"[OHA-CLINKZ] t=%.0f death-pact why=escape hp=%.2f creep=%s",
					DotaTime(),
					Fu.GetHP(bot),
					creep:GetUnitName()
				)
			)
			return BOT_ACTION_DESIRE_HIGH, creep
		end
	end
	if Fu.IsInLaningPhase() then
		if Fu.IsLaning(bot) then
			local nearbyLaneCreeps = bot:GetNearbyLaneCreeps(castRange, true)
			for _, creep in pairs(nearbyLaneCreeps) do
				if
					Fu.IsValid(creep)
					and Fu.CanBeAttacked(creep)
					and (Fu.IsKeyWordUnit("ranged", creep) or Fu.IsKeyWordUnit("siege", creep))
					and creep:GetLevel() <= maxCreepLevel
				then
					local nearbyAllies = Fu.GetNearbyHeroes(bot, 1600, false, BOT_MODE_NONE)
					if
						nearbyAllies ~= nil
						and #nearbyAllies >= 1
						and GetUnitToUnitDistance(creep, nearbyAllies[1]) < 600
						and botTarget ~= creep
						and not bot:HasModifier("modifier_clinkz_death_pact")
					then
						return BOT_ACTION_DESIRE_HIGH, creep
					end
				end
			end
		end
	else
		local creep = GetMostHPCreepLevel(nearbyCreeps, maxCreepLevel)
		if creep ~= nil and not bot:HasModifier("modifier_clinkz_death_pact") and not creep:IsAncientCreep() then
			return BOT_ACTION_DESIRE_HIGH, creep
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function X.ConsiderSkeletonWalk()
	if
		not skeletonWalkAbility:IsFullyCastable()
		or bot:HasModifier("modifier_clinkz_wind_walk")
		or Fu.IsRealInvisible(bot)
	then
		return BOT_ACTION_DESIRE_NONE
	end
	local roshanLocation = Fu.GetCurrentRoshanLocation()
	local tormentorLocation = Fu.GetTormentorLocation(GetTeam())
	local nearbyEnemies = Fu.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE)
	-- Hunt (#94, maintainer's play; game 050 30:40: he saw Lich alone and hit him from the edge of his range).
	local okPrey, prey = pcall(X.FindPrey)
	if okPrey and prey ~= nil then
		bot._huntTarget = prey
		bot._huntPrey = prey
		bot._huntLockAt = DotaTime()
		bot._huntLockFor = 30
		bot._huntRange = 3200
		pcall(
			print,
			string.format(
				"[OHA-CLINKZ] t=%.0f hunt start target=%s dist=%d hp=%.2f target-hp=%.2f",
				DotaTime(),
				(string.gsub(prey:GetUnitName(), "npc_dota_hero_", "")),
				GetUnitToUnitDistance(bot, prey),
				Fu.GetHP(bot),
				Fu.GetHP(prey)
			)
		)
		return BOT_ACTION_DESIRE_HIGH
	end
	if isGoingOnSomeone and bot:GetActiveModeDesire() > 0.65 then
		if
			Fu.IsValidTarget(botTarget)
			and GetUnitToUnitDistance(bot, botTarget) > 1600
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			local alliesNearTarget = Fu.GetAlliesNearLoc(botTarget:GetLocation(), 1200)
			local enemiesNearTarget = Fu.GetEnemiesNearLoc(botTarget:GetLocation(), 1200)
			if alliesNearTarget ~= nil and enemiesNearTarget ~= nil and #alliesNearTarget >= #enemiesNearTarget then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	if Fu.IsRetreating(bot) and bot:GetActiveModeDesire() > 0.5 then
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE)
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.IsChasingTarget(enemyHero, bot)
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and not Fu.IsDisabled(enemyHero)
			then
				local alliesNearEnemy = Fu.GetNearbyHeroes(enemyHero, 1200, true, BOT_MODE_NONE)
				local enemiesNearEnemy = Fu.GetNearbyHeroes(enemyHero, 1200, false, BOT_MODE_NONE)
				if
					alliesNearEnemy ~= nil
					and enemiesNearEnemy ~= nil
					and (#enemiesNearEnemy > #alliesNearEnemy or bot:WasRecentlyDamagedByAnyHero(1.5))
				then
					return BOT_ACTION_DESIRE_HIGH
				end
			end
		end
	end
	if Fu.IsFarming(bot) then
		if bot.farmLocation ~= nil then
			if GetUnitToLocationDistance(bot, bot.farmLocation) > 3200 then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	if Fu.IsLaning(bot) then
		if
			Fu.GetManaAfter(skeletonWalkAbility:GetManaCost()) > 0.8
			and bot:DistanceFromFountain() > 100
			and bot:DistanceFromFountain() < 6000
			and Fu.IsInLaningPhase()
			and nearbyEnemies ~= nil
			and #nearbyEnemies == 0
		then
			local assignedLane = bot:GetAssignedLane()
			local laneFrontLocation = GetLaneFrontLocation(GetTeam(), assignedLane, 0)
			local laneFrontDistance = GetUnitToLocationDistance(bot, laneFrontLocation)
			if laneFrontDistance > 1600 then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if GetUnitToLocationDistance(bot, roshanLocation) > 4000 then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if GetUnitToLocationDistance(bot, tormentorLocation) > 4000 then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderSearingArrows()
	if not Fu.CanCastAbility(searingArrowsAbility) or bot:IsDisarmed() then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local attackRange = bot:GetAttackRange()
	local manaCost = searingArrowsAbility:GetManaCost()
	local manaAfter = Fu.GetManaAfter(manaCost)
	local manaThreshold = Fu.GetManaThreshold(
		bot,
		manaCost,
		{ strafeAbility, deathPactAbility, burningBarrageAbility, burningArmyAbility, skeletonWalkAbility }
	)
	local isAutoCastOn = searingArrowsAbility:GetAutoCastState()
	if isGoingOnSomeone then
		if
			Fu.IsValidHero(botTarget)
			and Fu.CanBeAttacked(botTarget)
			and Fu.IsInRange(bot, botTarget, attackRange + 300)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not botTarget:IsMagicImmune()
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			if manaAfter > manaThreshold + 0.1 then
				if not isAutoCastOn then
					searingArrowsAbility:ToggleAutoCast()
				end
				return BOT_ACTION_DESIRE_NONE
			end
		end
	end
	if Fu.IsPushing(bot) or Fu.IsDefending(bot) or Fu.IsFarming(bot) then
		if
			Fu.IsValid(botTarget)
			and Fu.CanBeAttacked(botTarget)
			and Fu.IsInRange(bot, botTarget, attackRange)
			and not Fu.CanKillTarget(botTarget, bot:GetAttackDamage() * 3, DAMAGE_TYPE_PHYSICAL)
			and not Fu.IsRoshan(botTarget)
			and not Fu.IsTormentor(botTarget)
		then
			if manaAfter > manaThreshold + 0.15 then
				if not isAutoCastOn then
					searingArrowsAbility:ToggleAutoCast()
				end
				return BOT_ACTION_DESIRE_NONE
			end
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if Fu.IsRoshan(botTarget) and Fu.CanBeAttacked(botTarget) and Fu.IsInRange(bot, botTarget, attackRange) then
			if manaAfter > manaThreshold + 0.15 then
				if not isAutoCastOn and isAttacking then
					searingArrowsAbility:ToggleAutoCast()
				end
				return BOT_ACTION_DESIRE_NONE
			end
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, attackRange) then
			if manaAfter > manaThreshold + 0.15 then
				if not isAutoCastOn and isAttacking then
					searingArrowsAbility:ToggleAutoCast()
				end
				return BOT_ACTION_DESIRE_NONE
			end
		end
	end
	if
		Fu.IsValidHero(botTarget)
		and Fu.CanBeAttacked(botTarget)
		and Fu.IsInRange(bot, botTarget, attackRange + 100)
		and not botTarget:IsMagicImmune()
		and manaAfter > manaThreshold
	then
		if not isAutoCastOn then
			searingArrowsAbility:ToggleAutoCast()
		end
		return BOT_ACTION_DESIRE_NONE
	end
	if isAutoCastOn then
		searingArrowsAbility:ToggleAutoCast()
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function X.ConsiderBurningBarrage()
	if not burningBarrageAbility:IsTrained() or not burningBarrageAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	-- Not during Strafe (maintainer, game 048 44:30): the 2s channel wastes the Strafe attack speed. The cast time
	-- covers the case where the API doesn't show the modifier (game files: Strafe lasts "duration").
	local strafeFor = strafeAbility:GetSpecialValueFloat("duration")
	if
		bot:HasModifier("modifier_clinkz_strafe")
		or DotaTime() - (bot._strafeAt or -999) < (strafeFor > 0 and strafeFor or 3.5)
	then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	-- datafeed: Burning Barrage has no cast range and no "radius"; its arrows fly "range" (850), "projectile_width" (200) wide
	local castRange = Fu.GetProperCastRange(
		false,
		bot,
		math.max(burningBarrageAbility:GetCastRange(), burningBarrageAbility:GetSpecialValueInt("range"))
	)
	local projectileWidth = burningBarrageAbility:GetSpecialValueInt("projectile_width")
	if isGoingOnSomeone then
		if
			Fu.IsValidTarget(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange - 125)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			local alliesNearTarget = Fu.GetAlliesNearLoc(botTarget:GetLocation(), 1200)
			local enemiesNearTarget = Fu.GetEnemiesNearLoc(botTarget:GetLocation(), 1200)
			if alliesNearTarget ~= nil and enemiesNearTarget ~= nil and #alliesNearTarget >= #enemiesNearTarget then
				enemiesNearTarget = Fu.GetEnemiesNearLoc(botTarget:GetLocation(), projectileWidth - 75)
				-- Groups only (maintainer): a single target gets Strafe.
				if enemiesNearTarget ~= nil and #enemiesNearTarget >= 2 then
					return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(enemiesNearTarget)
				else
					return BOT_ACTION_DESIRE_HIGH, botTarget:GetExtrapolatedLocation(0.5)
				end
			end
		end
	end
	if Fu.IsFarming(bot) then
		local nearbyNeutralCreeps = bot:GetNearbyNeutralCreeps(1000)
		if
			nearbyNeutralCreeps ~= nil
			and #nearbyNeutralCreeps >= 1
			and isAttacking
			and Fu.GetManaAfter(burningBarrageAbility:GetManaCost()) * bot:GetMana()
				> skeletonWalkAbility:GetManaCost()
		then
			if Fu.IsBigCamp(nearbyNeutralCreeps) or nearbyNeutralCreeps[1]:IsAncientCreep() then
				if #nearbyNeutralCreeps >= 2 then
					return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(nearbyNeutralCreeps)
				end
			else
				if #nearbyNeutralCreeps >= 3 then
					return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(nearbyNeutralCreeps)
				end
			end
		end
		local nearbyLaneCreeps = bot:GetNearbyLaneCreeps(1000, true)
		if nearbyLaneCreeps ~= nil and #nearbyLaneCreeps >= 4 then
			return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(nearbyLaneCreeps)
		end
	end
	if Fu.IsPushing(bot) or Fu.IsDefending(bot) then
		local nearbyLaneCreeps = bot:GetNearbyLaneCreeps(1000, true)
		if nearbyLaneCreeps ~= nil and #nearbyLaneCreeps >= 4 then
			return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(nearbyLaneCreeps)
		end
	end
	if Fu.IsDoingRoshan(bot) or Fu.IsDoingTormentor(bot) then
		if
			(Fu.IsRoshan(botTarget) or Fu.IsTormentor(botTarget))
			and Fu.IsInRange(bot, botTarget, bot:GetAttackRange())
			and isAttacking
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.ConsiderBurningArmy()
	-- checked burningBarrageAbility by mistake; Burning Army is burningArmyAbility
	if not burningArmyAbility:IsTrained() or not burningArmyAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local attackRange = bot:GetAttackRange()
	local castRange = burningArmyAbility:GetCastRange()
	local radius = 900
	if Fu.IsInTeamFight(bot, 1200) then
		local aoeLocation = bot:FindAoELocation(true, true, bot:GetLocation(), castRange + radius / 2, radius, 0, 0)
		local enemiesNearLocation = Fu.GetEnemiesNearLoc(aoeLocation.targetloc, radius)
		if enemiesNearLocation ~= nil and #enemiesNearLocation >= 2 then
			if GetUnitToLocationDistance(bot, Fu.GetCenterOfUnits(enemiesNearLocation)) > castRange then
				return BOT_ACTION_DESIRE_HIGH,
					Fu.Site.GetXUnitsTowardsLocation(bot, Fu.GetCenterOfUnits(enemiesNearLocation), castRange)
			else
				return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(enemiesNearLocation)
			end
		end
	end
	if isGoingOnSomeone then
		if
			Fu.IsValidTarget(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			local alliesNearTarget = Fu.GetAlliesNearLoc(botTarget:GetLocation(), 1200)
			local enemiesNearTarget = Fu.GetEnemiesNearLoc(botTarget:GetLocation(), 1200)
			if alliesNearTarget ~= nil and enemiesNearTarget ~= nil and #alliesNearTarget >= #enemiesNearTarget then
				enemiesNearTarget = Fu.GetEnemiesNearLoc(botTarget:GetLocation(), radius)
				if enemiesNearTarget ~= nil and #enemiesNearTarget >= 1 then
					if GetUnitToLocationDistance(bot, Fu.GetCenterOfUnits(enemiesNearTarget)) > castRange then
						return BOT_ACTION_DESIRE_HIGH,
							Fu.Site.GetXUnitsTowardsLocation(bot, Fu.GetCenterOfUnits(enemiesNearTarget), castRange)
					else
						return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(enemiesNearTarget)
					end
				else
					if GetUnitToUnitDistance(bot, botTarget) > castRange then
						return BOT_ACTION_DESIRE_HIGH,
							Fu.Site.GetXUnitsTowardsLocation(bot, botTarget:GetLocation(), castRange)
					else
						return BOT_ACTION_DESIRE_HIGH, botTarget:GetExtrapolatedLocation(0.5)
					end
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function GetMostHPCreepLevel(creeps, maxLevel)
	local bestCreep = nil
	local bestHealth = 0
	for _, creep in pairs(creeps) do
		local health = creep:GetHealth()
		local level = creep:GetLevel()
		if health > bestHealth and level <= maxLevel and not Fu.IsKeyWordUnit("flagbearer", creep) then
			bestCreep = creep
			bestHealth = health
		end
	end
	return bestCreep
end
return X
