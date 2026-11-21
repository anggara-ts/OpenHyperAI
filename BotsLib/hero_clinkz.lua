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
	{ ["t25"] = { 0, 10 }, ["t20"] = { 0, 10 }, ["t15"] = { 0, 10 }, ["t10"] = { 0, 10 } },
	{ ["t25"] = { 0, 10 }, ["t20"] = { 0, 10 }, ["t15"] = { 0, 10 }, ["t10"] = { 0, 10 } },
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
-- Stratz 7.41f, week of 9 Nov 2026: pos 1, 38,631 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_1"] = {
	"item_tango",
	"item_double_branches",
	"item_faerie_fire",
	"item_magic_stick",
	"item_magic_wand",
	"item_falcon_blade",
	"item_power_treads",
	"item_desolator",
	"item_dragon_lance",
	"item_greater_crit",
	"item_black_king_bar",
	"item_ultimate_scepter",
	"item_travel_boots",
	"item_ultimate_scepter_2",
	"item_hydras_breath",
	"item_moon_shard",
	"item_sphere",
	"item_aghanims_shard",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 2, 34,387 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_2"] = {
	"item_tango",
	"item_double_branches",
	"item_faerie_fire",
	"item_magic_stick",
	"item_magic_wand",
	"item_falcon_blade",
	"item_power_treads",
	"item_oblivion_staff",
	"item_desolator",
	"item_orchid",
	"item_lesser_crit",
	"item_bloodthorn",
	"item_greater_crit",
	"item_ultimate_scepter",
	"item_travel_boots",
	"item_ultimate_scepter_2",
	"item_hydras_breath",
	"item_nullifier",
	-- removed a second item_dragon_lance here: one lance already listed above, and Hurricane Pike takes only one
	"item_aghanims_shard",
	"item_moon_shard",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 3, 3,106 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_3"] = {
	"item_tango",
	"item_double_branches",
	"item_faerie_fire",
	"item_circlet",
	"item_sobi_mask",
	"item_magic_wand",
	"item_falcon_blade",
	"item_power_treads",
	"item_oblivion_staff",
	"item_desolator",
	"item_orchid",
	"item_aghanims_shard",
	"item_lesser_crit",
	"item_bloodthorn",
	"item_greater_crit",
	"item_ultimate_scepter",
	"item_travel_boots",
	"item_ultimate_scepter_2",
	"item_hydras_breath",
	"item_sphere",
	"item_moon_shard",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 4, 4,261 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_4"] = {
	"item_tango",
	"item_blood_grenade",
	"item_double_branches",
	"item_blight_stone",
	"item_magic_wand",
	"item_falcon_blade",
	"item_power_treads",
	"item_orchid",
	"item_desolator",
	"item_bloodthorn",
	"item_greater_crit",
	"item_travel_boots",
	"item_monkey_king_bar",
	"item_ultimate_scepter_2",
	"item_hydras_breath",
	"item_aghanims_shard",
	"item_moon_shard",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 5, 1,731 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_5"] = {
	"item_tango",
	"item_blood_grenade",
	"item_double_branches",
	"item_magic_stick",
	"item_faerie_fire",
	"item_magic_wand",
	"item_falcon_blade",
	"item_power_treads",
	"item_orchid",
	"item_dragon_lance",
	"item_lesser_crit",
	"item_bloodthorn",
	"item_greater_crit",
	"item_travel_boots",
	"item_ultimate_scepter",
	"item_sheepstick",
	"item_hydras_breath",
	"item_aghanims_shard",
	"item_moon_shard",
	"item_ultimate_scepter_2",
}
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
-- Death Pact charges (#94). Datafeed hero 56 (7.42): AbilityCharges 1/1/2/2, AbilityChargeRestoreTime 40. Game 063,
-- 7:56: three escape orders 18 s after a pact (HP up 0.52 -> 0.59 at 7:38), none cast: the API reports the spell
-- castable with no charge left, and ChargeTracker skips one-charge spells. A pact shows as the 45 s
-- modifier_clinkz_death_pact appearing or being refreshed.
local PACT_CHARGES = { 1, 1, 2, 2 }
local PACT_RESTORE = 40
local pactState = { n = nil, nextAt = nil, lastLeft = 0 }
-- Pure: one step of the charge count. n: charges before (nil = full), spent: a pact was seen this step.
-- Returns the new n and the time the next charge comes back (nil when full).
function X.PactChargeStep(n, nextAt, max, restore, now, spent)
	n = math.min(n or max, max)
	while nextAt ~= nil and now >= nextAt and n < max do
		n = n + 1
		nextAt = n < max and nextAt + restore or nil
	end
	if n >= max then
		nextAt = nil
	end
	if spent then
		n = math.max(0, n - 1)
		nextAt = nextAt or now + restore
	end
	return n, nextAt
end
-- Once per think, before any early return: charges left now.
function X.PactCharges()
	local level = deathPactAbility:GetLevel()
	if level < 1 then
		return 0
	end
	local left = Fu.GetModifierTime(bot, "modifier_clinkz_death_pact") or 0
	local spent = left > pactState.lastLeft + 1
	pactState.lastLeft = left
	local max = PACT_CHARGES[math.min(level, #PACT_CHARGES)]
	pactState.n, pactState.nextAt =
		X.PactChargeStep(pactState.n, pactState.nextAt, max, PACT_RESTORE, DotaTime(), spent)
	-- An order that never became a pact (game 063, 7:56: three escape orders, no HP gained): say so once.
	local order = pactState.order
	if spent then
		pactState.order = nil
	elseif order ~= nil and DotaTime() > order.at + 1 then
		pactState.order = nil
		pcall(
			print,
			string.format(
				"[OHA-CLINKZ] t=%.0f death-pact-unspent why=%s mode=%d rooted=%s charges=%d max=%d",
				DotaTime(),
				order.why,
				bot:GetActiveMode(),
				tostring(bot:IsRooted()),
				pactState.n,
				max
			)
		)
	end
	return pactState.n
end
-- Every Death Pact order goes through here (death-pact-unspent when no pact follows within 1 s).
function X.OrderPact(creep, why)
	if pactState.order == nil then
		pactState.order = { at = DotaTime(), why = why }
	end
	bot:Action_UseAbilityOnEntity(deathPactAbility, creep)
end
function X.HasPactCharge()
	return (pactState.n or 1) >= 1 and deathPactAbility:IsFullyCastable()
end
-- The reveal of an invisible hunt, measured 2.5 s later: did the target lose HP (hunt result=).
local huntReveal = nil
local function CheckHuntResult()
	if huntReveal == nil or DotaTime() < huntReveal.at + 2.5 then
		return
	end
	local reveal = huntReveal
	huntReveal = nil
	local target = reveal.target
	local result
	local dmg = 0
	if target == nil or target:IsNull() or not target:IsAlive() then
		result = "kill"
	elseif target:CanBeSeen() then
		dmg = reveal.hp - target:GetHealth()
		result = dmg > 0 and "hit" or "miss"
	else
		result = "lost"
	end
	pcall(
		print,
		string.format(
			"[OHA-CLINKZ] t=%.0f hunt result=%s target=%s dmg=%d by=%s",
			DotaTime(),
			result,
			reveal.name,
			math.max(0, math.floor(dmg)),
			reveal.by
		)
	)
end
function X.SkillsComplement()
	pcall(X.PactCharges)
	pcall(CheckHuntResult)
	if Fu.CanNotUseAbility(bot) then
		return
	end
	local context = AbilityContext.Build(bot)
	isGoingOnSomeone = context.isEngaging
	isAttacking = Fu.IsAttacking(bot)
	mpRatio = context.mp
	botTarget = context.target
	-- Escape pact first: it doesn't break Skeleton Walk, and the hunt or the attack spells must not hold it back.
	local escapePactDesire, escapePactTarget = X.ConsiderEscapePact()
	if escapePactDesire > 0 then
		X.OrderPact(escapePactTarget, "escape")
		return
	end
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
		-- Every Barrage is logged (#94): strafe= must be false and since-strafe= longer than Strafe lasts.
		pcall(
			print,
			string.format(
				"[OHA-CLINKZ] t=%.0f barrage strafe=%s since-strafe=%.1f enemies=%d",
				DotaTime(),
				tostring(bot:HasModifier("modifier_clinkz_strafe")),
				math.min(DotaTime() - (bot._strafeAt or -999), 99),
				#Fu.GetEnemiesNearLoc(burningBarrageLocation, 400)
			)
		)
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
		X.OrderPact(deathPactTarget, "other")
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
-- A hunt on a lone hero always ends with one line (#94, game 051: 12 or more of 20 hunts had none, so the log
-- could not say why they ended). why = revealed | invis-gone | target-gone | lost-sight | timeout | too-far |
-- low-hp | outnumbered | tower. keepTarget: the reveal keeps its target for the first hits.
function X.EndHunt(why, keepTarget)
	local prey = bot._huntPrey
	if prey ~= nil then
		local known = Fu.IsValidHero(prey)
		pcall(
			print,
			string.format(
				"[OHA-CLINKZ] t=%.0f hunt end why=%s target=%s dist=%d lasted=%.0f",
				DotaTime(),
				why,
				known and (string.gsub(prey:GetUnitName(), "npc_dota_hero_", "")) or "-",
				known and GetUnitToUnitDistance(bot, prey) or -1,
				DotaTime() - (bot._huntLockAt or DotaTime())
			)
		)
	end
	bot._huntPrey, bot._huntLockFor, bot._huntRange = nil, nil, nil
	if not keepTarget then
		bot._huntTarget = nil
	end
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
	if locked ~= nil then
		local why = "timeout"
		if not Fu.IsValidHero(locked) then
			why = "target-gone"
		elseif not locked:CanBeSeen() then
			why = "lost-sight"
		elseif Fu.GetHP(bot) < 0.35 then
			why = "low-hp"
		elseif GetUnitToUnitDistance(bot, locked) >= (bot._huntRange or 1600) then
			why = "too-far"
		end
		if bot._huntPrey ~= nil then
			X.EndHunt(why)
		else
			-- A hunt on the engage target (no hunt start line): say why the hold ends.
			X.LogHunt("drop-" .. why, Fu.IsValidHero(locked) and locked or nil)
		end
	end
	bot._huntTarget, bot._huntPrey, bot._huntLockFor, bot._huntRange = nil, nil, nil, nil
	-- No new target for 15s after a cancelled hunt (else the same hero is picked again next think).
	if Fu.GetHP(bot) < 0.5 or Fu.IsRetreating(bot) or DotaTime() < (bot._huntOffUntil or -999) then
		return nil
	end
	local best, bestHp = nil, 2
	-- Not farther than 2600, so the lock below (distance + 600, at most 3200) keeps it: game 063, 7 of the 24
	-- walks started 4000-14000 from the target and flipped up to 12 times.
	if
		isGoingOnSomeone
		and Fu.IsValidHero(botTarget)
		and not Fu.IsSuspiciousIllusion(botTarget)
		and GetUnitToUnitDistance(bot, botTarget) <= 2600
	then
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
		-- Keep the target for the walk (game 063, t=925: picked at 1837, the 1600 lock range dropped it at once; with
		-- the outpost hold on he is not "going on someone", so no re-pick until the attack mode took over again, four
		-- mode flips on the way in). 20 s and 600 more than the distance now, at most 3200.
		bot._huntLockFor = 20
		bot._huntRange = math.min(3200, math.max(1600, GetUnitToUnitDistance(bot, best) + 600))
	end
	return best
end
-- Returns true when it gave an order. In any mode while invisible (#94, game 048: 61 approaches, 2 reveals;
-- at 44:30 he showed himself at the edge of his range and the target walked out of the skeletons' attacks).
-- He walks to a point 150 past the target on its way home (its escape path), then hex, Strafe and shoot from
-- point blank. bot._clinkzHuntUntil keeps the outpost mode holding the other modes' orders meanwhile.
function X.HuntStep()
	if not bot:HasModifier("modifier_clinkz_wind_walk") then
		-- Just revealed: keep the other modes out until the first hit takes HP off the target (at most 1.2 s).
		-- Game 063: the 0.5 s hold ran out during the attack, the attack mode took over and the walk was gone
		-- with no hit (t=869, reveal at 194, no damage).
		local reveal = huntReveal
		if
			reveal ~= nil
			and DotaTime() < reveal.at + 1.2
			and reveal.target ~= nil
			and not reveal.target:IsNull()
			and reveal.target:IsAlive()
			and reveal.target:GetHealth() >= reveal.hp
		then
			bot._clinkzHuntUntil = DotaTime() + 0.2
			-- Only when the attack order was replaced: a repeat of the same order keeps the swing going.
			if bot:GetAttackTarget() ~= reveal.target then
				bot:Action_AttackUnit(reveal.target, true)
			end
			return true
		end
		X.EndHunt("invis-gone")
		bot._huntTarget = nil
		return false
	end
	-- Invisible: a pact on the biggest creep in range first (heal + max HP, keeps him invisible).
	if X.HasPactCharge() and not bot:HasModifier("modifier_clinkz_death_pact") then
		local creep = GetMostHPCreepLevel(
			bot:GetNearbyCreeps(deathPactAbility:GetCastRange(), true),
			deathPactAbility:GetSpecialValueInt("creep_level")
		)
		if creep ~= nil and not creep:IsAncientCreep() then
			X.LogHunt("pact", nil)
			-- The cast must not drop the hunt hold (the attack mode took over during it).
			if bot._huntTarget ~= nil then
				bot._clinkzHuntUntil = DotaTime() + 0.6
			end
			X.OrderPact(creep, "hunt")
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
	-- A real cancel: no new hunt for 5 s (game 063: this check ended the hunt with no pause, the attack mode
	-- picked the same target next think and the hunt started again, flipping outpost <-> attack).
	if #Fu.GetEnemiesNearLoc(bot:GetLocation(), 1200) > #Fu.GetAlliesNearLoc(bot:GetLocation(), 1200) then
		if bot._huntPrey == nil then
			X.LogHunt("cancel-outnumbered", target)
		end
		X.EndHunt("outnumbered")
		bot._huntTarget = nil
		bot._huntOffUntil = DotaTime() + 5
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
				X.EndHunt("tower")
				bot._huntTarget = nil
				bot._clinkzHuntUntil = nil
				return false
			end
		end
		-- 0.6 s: a think skipped by a cast or the heavy-think throttle must not let the other modes in.
		bot._clinkzHuntUntil = DotaTime() + 0.6
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
	X.EndHunt("revealed", true)
	-- The target stays locked for the first hits (after Strafe he is still invisible and comes back here).
	bot._huntLockAt, bot._huntLockFor = DotaTime(), 3
	if huntReveal == nil then
		huntReveal = {
			target = target,
			name = (string.gsub(target:GetUnitName(), "npc_dota_hero_", "")),
			hp = target:GetHealth(),
			at = DotaTime(),
			by = step,
		}
	end
	-- Keep the other modes out until the first hit lands (renewed above while the hit is pending).
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
-- Escape (#94, game 050 10:47-10:53: he ran with Skeleton Walk from Lich and Tinker and died with no pact). Game
-- files (7.42): charges 1/1/2/2, no cooldown, 700 range, +175-400 HP; it doesn't end Skeleton Walk. Hurt under
-- 60% with an enemy hero within 900 while retreating, just hit or rooted: eat the biggest creep in range, pact up or
-- not. Checked before his other spells: game 063, 8:18-8:25, rooted at 17% HP he fought back with Searing Arrows
-- (checked first) and died with the charge back. A unit-target spell, so a root doesn't stop it.
function X.ConsiderEscapePact()
	if deathPactAbility:GetLevel() < 1 or Fu.GetHP(bot) >= 0.6 then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	if not (Fu.IsRetreating(bot) or bot:WasRecentlyDamagedByAnyHero(2.0) or bot:IsRooted()) then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local enemiesNear = math.max(
		#(bot:GetNearbyHeroes(900, true, BOT_MODE_NONE) or {}),
		#(Fu.GetEnemiesNearLoc(bot:GetLocation(), 900) or {})
	)
	if enemiesNear < 1 then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local why = nil
	local creep = nil
	if not X.HasPactCharge() then
		why = "no-charge"
	else
		creep = GetMostHPCreepLevel(
			bot:GetNearbyCreeps(deathPactAbility:GetCastRange(), true),
			deathPactAbility:GetSpecialValueInt("creep_level")
		)
		if creep == nil or creep:IsAncientCreep() then
			why = "no-creep"
		end
	end
	local logKey = why or "escape"
	if DotaTime() >= (bot._pactLogAt or -999) or logKey ~= bot._pactLogKey then
		bot._pactLogAt, bot._pactLogKey = DotaTime() + 3, logKey
		if why ~= nil then
			pcall(
				print,
				string.format(
					"[OHA-CLINKZ] t=%.0f death-pact-skip why=%s hp=%.2f enemies=%d rooted=%s charges=%s",
					DotaTime(),
					why,
					Fu.GetHP(bot),
					enemiesNear,
					tostring(bot:IsRooted()),
					tostring(pactState.n)
				)
			)
		else
			pcall(
				print,
				string.format(
					"[OHA-CLINKZ] t=%.0f death-pact why=escape hp=%.2f creep=%s rooted=%s charges=%s",
					DotaTime(),
					Fu.GetHP(bot),
					creep:GetUnitName(),
					tostring(bot:IsRooted()),
					tostring(pactState.n)
				)
			)
		end
	end
	if why ~= nil then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	return BOT_ACTION_DESIRE_HIGH, creep
end
function X.ConsiderDeathPact()
	if not X.HasPactCharge() then
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
	-- Last hits with Searing Arrows (#48, maintainer): in lane, offer the arrow's bonus to the last-hit prediction while
	-- mana stays 20% above the reserve for his spells (game files: damage_bonus 20/35/50/65, mana 10). When a last
	-- hit needs it and Clinkz is on that creep, turn autocast on for the hit.
	bot._lastHitBonus = 0
	if Fu.IsLaning(bot) and manaAfter > manaThreshold + 0.2 then
		bot._lastHitBonus = searingArrowsAbility:GetSpecialValueInt("damage_bonus")
		local need = bot._lastHitNeedsBonus
		if
			need ~= nil
			and DotaTime() - need.at < 1.5
			and Fu.IsValid(need.creep)
			and botTarget == need.creep
			and Fu.IsInRange(bot, need.creep, attackRange + 100)
		then
			if not isAutoCastOn then
				searingArrowsAbility:ToggleAutoCast()
			end
			if DotaTime() >= (bot._searingLhLogAt or -999) then
				bot._searingLhLogAt = DotaTime() + 10
				pcall(
					print,
					string.format(
						"[OHA-CLINKZ] t=%.0f searing-lasthit creep-hp=%d bonus=%d",
						DotaTime(),
						need.creep:GetHealth(),
						bot._lastHitBonus
					)
				)
			end
			return BOT_ACTION_DESIRE_NONE
		end
	end
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
