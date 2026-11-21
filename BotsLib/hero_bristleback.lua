-- Bristleback: skill build, item build, and ability use for this hero.
local X = {}
local bot = GetBot()
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local AbilityContext = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local Minion = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local sTalentList = Fu.Skill.GetTalentList(bot)
local sAbilityList = Fu.Skill.GetAbilityList(bot)
local sRole = Fu.Item.GetRoleItemsBuyList(bot)
local tTalentTreeList = { ["t25"] = { 0, 10 }, ["t20"] = { 10, 0 }, ["t15"] = { 10, 0 }, ["t10"] = { 10, 0 } }
local tAllAbilityBuildList = { { 2, 3, 2, 1, 2, 6, 2, 3, 3, 3, 6, 1, 1, 1, 6 } }
local nAbilityBuildList = Fu.Skill.GetRandomBuild(tAllAbilityBuildList)
local nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList)
-- Heaven's Halberd only against heavy right-click damage that does not come through
-- illusions; otherwise the slot is skipped. It used to be a random pick, a second BKB 1 in 3.
local heavyPhysical, physicalHeroes =
	require(GetScriptDirectory() .. "/FuncLib/systems/item_strategy").EnemyHeavyPhysical()
local sHalberd = heavyPhysical and "item_heavens_halberd" or false
if sRole == "pos_3" then
	pcall(
		print,
		string.format(
			"[OHA-BUY] t=%.0f bristleback halberd=%s physical=%s",
			DotaTime(),
			tostring(heavyPhysical),
			table.concat(physicalHeroes, ",")
		)
	)
end
local sRoleItemsBuyList = {}
-- Stratz 7.41f, week of 9 Nov 2026: pos 1, 3,179 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_1"] = {
	"item_tango",
	"item_double_branches",
	"item_gauntlets",
	"item_magic_stick",
	"item_bracer",
	"item_magic_wand",
	"item_power_treads",
	"item_aghanims_shard",
	"item_sange",
	"item_ultimate_scepter",
	"item_sange_and_yasha",
	"item_heart",
	"item_travel_boots",
	"item_ultimate_scepter_2",
	"item_consecrated_wraps",
	"item_shivas_guard",
	"item_abyssal_blade",
	"item_moon_shard",
	"item_travel_boots_2",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 3, 109,210 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_3"] = {
	"item_tango",
	"item_double_branches",
	"item_gauntlets",
	"item_magic_stick",
	"item_bracer",
	"item_magic_wand",
	"item_soul_ring",
	"item_vanguard",
	"item_power_treads",
	"item_blade_mail",
	"item_aghanims_shard",
	"item_ultimate_scepter",
	sHalberd,
	"item_heart",
	"item_travel_boots",
	"item_ultimate_scepter_2",
	"item_shivas_guard",
	"item_moon_shard",
	"item_travel_boots_2",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 2, 2,997 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_2"] = {
	"item_tango",
	"item_double_branches",
	"item_gauntlets",
	"item_magic_stick",
	"item_bracer",
	"item_magic_wand",
	"item_soul_ring",
	"item_power_treads",
	"item_blade_mail",
	"item_ultimate_scepter",
	"item_sange",
	"item_aghanims_shard",
	"item_sange_and_yasha",
	"item_heart",
	"item_black_king_bar",
	"item_ultimate_scepter_2",
	"item_assault",
	"item_moon_shard",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 4, 3,755 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_4"] = {
	"item_tango",
	"item_branches",
	"item_gauntlets",
	"item_magic_stick",
	"item_bracer",
	"item_magic_wand",
	"item_power_treads",
	"item_vanguard",
	"item_blade_mail",
	"item_aghanims_shard",
	"item_crimson_guard",
	"item_ultimate_scepter",
	"item_heart",
	"item_travel_boots",
	"item_ultimate_scepter_2",
	"item_black_king_bar",
	"item_pipe",
	"item_moon_shard",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 5, 1,499 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_5"] = {
	"item_tango",
	"item_branches",
	"item_magic_stick",
	"item_gauntlets",
	"item_bracer",
	"item_magic_wand",
	"item_power_treads",
	"item_vanguard",
	"item_aghanims_shard",
	"item_blade_mail",
	"item_crimson_guard",
	"item_heart",
	"item_ultimate_scepter",
	"item_travel_boots",
	"item_ultimate_scepter_2",
	"item_consecrated_wraps",
	"item_shivas_guard",
	"item_moon_shard",
}
-- Drop the skipped Halberd slot (false) so the list has no holes.
for _, list in pairs(sRoleItemsBuyList) do
	for idx = #list, 1, -1 do
		if list[idx] == false then
			table.remove(list, idx)
		end
	end
end
X["sBuyList"] = sRoleItemsBuyList[sRole]
X["sSellList"] = {
	"item_power_treads",
	"item_quelling_blade",
	"item_basher",
	"item_quelling_blade",
	"item_satanic",
	"item_magic_wand",
	"item_consecrated_wraps",
	"item_bracer",
	"item_assault",
	"item_bottle",
	"item_satanic",
	"item_bracer",
}
if Fu.Role.IsPvNMode() or Fu.Role.IsAllShadow() then
	X["sBuyList"], X["sSellList"] = { "PvN_tank" }, { "item_power_treads", "item_quelling_blade" }
end
nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"] =
	Fu.SetUserHeroInit(nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"])
X["sSkillList"] = Fu.Skill.GetSkillList(sAbilityList, nAbilityBuildList, sTalentList, nTalentBuildList)
X["bDeafaultAbility"] = false
X["bDeafaultItem"] = false
function X.MinionThink(hMinionUnit)
	Minion.MinionThink(hMinionUnit)
end
local viscousNasalGooAbility =
	SafeAbility(bot:GetAbilityByName("bristleback_viscous_nasal_goo"), "bristleback_viscous_nasal_goo", "bristleback")
local quillSprayAbility =
	SafeAbility(bot:GetAbilityByName("bristleback_quill_spray"), "bristleback_quill_spray", "bristleback")
local bristlebackAbility =
	SafeAbility(bot:GetAbilityByName("bristleback_bristleback"), "bristleback_bristleback", "bristleback")
local hairballAbility = SafeAbility(bot:GetAbilityByName("bristleback_hairball"), "bristleback_hairball", "bristleback")
local warpathAbility = SafeAbility(bot:GetAbilityByName("bristleback_warpath"), "bristleback_warpath", "bristleback")
local viscousNasalGooDesire, viscousNasalGooTarget
local quillSprayDesire
local hairballDesire, hairballLocation
local bristlebackDesire, bristlebackLocation
local warpathDesire
local isAttacking = false
local botTarget, botHp
local nearbyAllies, nearbyEnemies
local isEngaging
local isRetreating
local hpRatio
local isTeamFight
function X.SkillsComplement()
	bot = GetBot()
	if Fu.CanNotUseAbility(bot) then
		return
	end
	local context = AbilityContext.Build(bot)
	isEngaging = context.isEngaging
	isRetreating = context.isRetreating
	hpRatio = context.hp
	isTeamFight = context.isTeamFight
	isAttacking = Fu.IsAttacking(bot)
	botHp = hpRatio
	botTarget = context.target
	nearbyAllies = context.allies
	nearbyEnemies = context.enemies
	hairballDesire, hairballLocation = X.ConsiderHairball()
	if hairballDesire > 0 then
		Fu.SetQueuePtToINT(bot, true)
		bot:ActionQueue_UseAbilityOnLocation(hairballAbility, hairballLocation)
		return
	end
	bristlebackDesire, bristlebackLocation = X.ConsiderBristleback()
	if bristlebackDesire > 0 then
		Fu.SetQueuePtToINT(bot, false)
		bot:ActionQueue_UseAbilityOnLocation(bristlebackAbility, bristlebackLocation)
		return
	end
	viscousNasalGooDesire, viscousNasalGooTarget = X.ConsiderViscousNasalGoo()
	if viscousNasalGooDesire > 0 then
		Fu.SetQueuePtToINT(bot, false)
		bot:ActionQueue_UseAbilityOnEntity(viscousNasalGooAbility, viscousNasalGooTarget)
		return
	end
	warpathDesire = X.ConsiderWarpath()
	if warpathDesire > 0 then
		bot:Action_UseAbility(warpathAbility)
		return
	end
	quillSprayDesire = X.ConsiderQuillSpray()
	if quillSprayDesire > 0 then
		Fu.SetQueuePtToINT(bot, true)
		bot:ActionQueue_UseAbility(quillSprayAbility)
		return
	end
end
function X.ConsiderViscousNasalGoo()
	if not Fu.CanCastAbility(viscousNasalGooAbility) then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidHero(enemyHero)
			and hpRatio < 0.6
			and hpRatio < Fu.GetHP(enemyHero)
			and Fu.IsInRange(bot, enemyHero, 900)
			and enemyHero:IsFacingLocation(bot:GetLocation(), 40)
		then
			return BOT_ACTION_DESIRE_NONE, nil
		end
	end
	local castRange = Fu.GetProperCastRange(false, bot, viscousNasalGooAbility:GetCastRange())
	local manaCost = viscousNasalGooAbility:GetManaCost()
	local manaAfter = Fu.GetManaAfter(manaCost)
	local manaThreshold = Fu.GetManaThreshold(bot, manaCost, { bristlebackAbility, hairballAbility })
	if isTeamFight then
		if
			Fu.IsValidHero(nearbyEnemies[1])
			-- fix: no range check, so in a fight he walked up to 1600 toward G[1] to goo it
			and Fu.IsInRange(bot, nearbyEnemies[1], castRange)
			and Fu.CanBeAttacked(nearbyEnemies[1])
			and Fu.CanCastOnNonMagicImmune(nearbyEnemies[1])
			and not nearbyEnemies[1]:HasModifier("modifier_necrolyte_reapers_scythe")
			and manaAfter > manaThreshold
		then
			return BOT_ACTION_DESIRE_HIGH, nearbyEnemies[1]
		end
	end
	if isEngaging then
		if
			Fu.IsValidHero(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and Fu.CanBeAttacked(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
			and manaAfter > manaThreshold
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end
	if isRetreating and not Fu.IsRealInvisible(bot) then
		if Fu.IsValidHero(nearbyEnemies[1]) and Fu.IsInRange(bot, nearbyEnemies[1], castRange) then
			if isTeamFight or not Fu.IsInLaningPhase() then
				return BOT_ACTION_DESIRE_HIGH, nearbyEnemies[1]
			end
			if
				Fu.CanCastOnNonMagicImmune(nearbyEnemies[1])
				and Fu.CanCastOnTargetAdvanced(nearbyEnemies[1])
				and bot:WasRecentlyDamagedByHero(nearbyEnemies[1], 3.0)
			then
				if
					Fu.IsChasingTarget(nearbyEnemies[1], bot)
					or #nearbyEnemies > #nearbyAllies and nearbyEnemies[1]:GetAttackTarget() == bot
				then
					return BOT_ACTION_DESIRE_HIGH, nearbyEnemies[1]
				end
			end
		end
		for _, allyHero in pairs(nearbyAllies) do
			if
				bot ~= allyHero
				and Fu.IsValidHero(allyHero)
				and Fu.IsRetreating(allyHero)
				and allyHero:WasRecentlyDamagedByAnyHero(3.0)
				and not Fu.IsSuspiciousIllusion(allyHero)
				and not Fu.IsRealInvisible(allyHero)
				and not Fu.IsRealInvisible(bot)
			then
				for _, enemyHero in ipairs(nearbyEnemies) do
					if
						Fu.IsValidHero(enemyHero)
						and Fu.IsInRange(bot, enemyHero, castRange)
						and Fu.CanCastOnNonMagicImmune(enemyHero)
						and Fu.CanCastOnTargetAdvanced(enemyHero)
						and Fu.IsChasingTarget(enemyHero, allyHero)
						and not Fu.IsDisabled(enemyHero)
					then
						return BOT_ACTION_DESIRE_HIGH, enemyHero
					end
				end
			end
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if
			Fu.IsRoshan(botTarget)
			and Fu.CanBeAttacked(botTarget)
			and Fu.CanCastOnMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and manaAfter > 0.4
			and manaAfter > manaThreshold
			and isAttacking
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if
			Fu.IsTormentor(botTarget)
			and Fu.CanCastOnMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and manaAfter > 0.4
			and manaAfter > manaThreshold
			and isAttacking
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
-- Enemy lane creeps in range that one spray kills. Damage is base plus 30 per quill stack
-- already on the creep (capped at max_damage), physical, so armor applies.
function X.QuillLaneKills(radius)
	local base = quillSprayAbility:GetSpecialValueInt("quill_base_damage")
	if base == nil or base <= 0 then
		return 0
	end
	local perStack = quillSprayAbility:GetSpecialValueInt("quill_stack_damage") or 0
	local maxDamage = quillSprayAbility:GetSpecialValueInt("max_damage") or 0
	local kills = 0
	for _, enemyHero in pairs(bot:GetNearbyLaneCreeps(radius, true) or {}) do
		if Fu.IsValid(enemyHero) and Fu.CanBeAttacked(enemyHero) then
			local stacks = Fu.GetModifierCount(enemyHero, "modifier_bristleback_quill_spray") or 0
			local raw = base + perStack * stacks
			if maxDamage > 0 then
				raw = math.min(raw, maxDamage)
			end
			if enemyHero:GetHealth() <= enemyHero:GetActualIncomingDamage(raw, DAMAGE_TYPE_PHYSICAL) then
				kills = kills + 1
			end
		end
	end
	return kills
end
-- [OHA-QUILL]: each Quill Spray cast with why, at most once per 10s per reason.
function X.LogQuill(why, kills, heroes, mana)
	bot._quillLogAt = bot._quillLogAt or {}
	if DotaTime() < (bot._quillLogAt[why] or -999) then
		return
	end
	bot._quillLogAt[why] = DotaTime() + 10
	pcall(
		print,
		string.format(
			"[OHA-QUILL] t=%.0f %s %s kills=%d heroes=%d mana=%.2f",
			DotaTime(),
			(string.gsub(bot:GetUnitName(), "npc_dota_hero_", "")),
			why,
			kills,
			heroes,
			mana
		)
	)
end
function X.ConsiderQuillSpray()
	if not Fu.CanCastAbility(quillSprayAbility) then
		return BOT_ACTION_DESIRE_NONE
	end
	if quillSprayAbility:GetAutoCastState() == true then
		quillSprayAbility:ToggleAutoCast()
	end
	local radius = quillSprayAbility:GetSpecialValueInt("radius")
	local manaAfter = Fu.GetManaAfter(quillSprayAbility:GetManaCost())
	if isTeamFight then
		if Fu.IsValidHero(nearbyEnemies[1]) then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if isEngaging then
		if
			Fu.IsValidHero(botTarget)
			and Fu.IsInRange(bot, botTarget, radius - 100)
			and Fu.CanBeAttacked(botTarget)
			and Fu.CanCastOnMagicImmune(botTarget)
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if isRetreating and not Fu.IsRealInvisible(bot) then
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.CanBeAttacked(enemyHero)
				and Fu.IsInRange(bot, enemyHero, radius)
				and (
					bot:WasRecentlyDamagedByHero(enemyHero, 4.0)
					or enemyHero:HasModifier("modifier_bristleback_quill_spray")
				)
			then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	local foesInRange = 0
	for _, enemyHero in pairs(bot:GetNearbyHeroes(radius - 50, true, BOT_MODE_NONE) or {}) do
		if Fu.IsValidHero(enemyHero) and Fu.CanBeAttacked(enemyHero) and not Fu.IsSuspiciousIllusion(enemyHero) then
			foesInRange = foesInRange + 1
		end
	end
	-- Engaging: any enemy hero inside the spray, not only the chosen target.
	if isEngaging and foesInRange >= 1 then
		X.LogQuill("engage", 0, foesInRange, manaAfter)
		return BOT_ACTION_DESIRE_HIGH
	end
	-- Lane: 35 mana on a 3s cooldown. Finish creeps the quills will kill, and poke a laner
	-- in range; a spell on a hero does not pull creep aggro the way a right-click does.
	if Fu.IsInLaningPhase() and manaAfter > 0.3 then
		local kills = X.QuillLaneKills(radius - 50)
		if kills >= 2 or kills >= 1 and foesInRange >= 1 then
			X.LogQuill("lane-lasthit", kills, foesInRange, manaAfter)
			return BOT_ACTION_DESIRE_HIGH
		end
		if foesInRange >= 1 and manaAfter > 0.5 then
			X.LogQuill("lane-poke", kills, foesInRange, manaAfter)
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	local nearbyCreeps = bot:GetNearbyCreeps(radius, true)
	if Fu.IsPushing(bot) or Fu.IsDefending(bot) or isEngaging or Fu.IsFarming(bot) then
		if Fu.CanBeAttacked(nearbyCreeps[1]) and manaAfter > 0.25 then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsFarming(bot) and manaAfter > 0.25 then
		if Fu.IsValid(botTarget) and Fu.CanBeAttacked(botTarget) and botTarget:IsCreep() then
			if botTarget:GetHealth() > bot:GetAttackDamage() * 3 then
				return BOT_ACTION_DESIRE_HIGH
			end
			if Fu.IsValid(nearbyCreeps[1]) and Fu.CanBeAttacked(nearbyCreeps[1]) and #nearbyCreeps >= 2 then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	if Fu.IsDoingRoshan(bot) and isAttacking then
		if
			Fu.IsRoshan(botTarget)
			and Fu.CanBeAttacked(botTarget)
			and Fu.CanCastOnMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, radius)
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsDoingTormentor(bot) and isAttacking then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, radius) then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if manaAfter > 0.9 and not Fu.IsInLaningPhase() and bot:DistanceFromFountain() > 2400 then
		return BOT_ACTION_DESIRE_HIGH
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderBristleback()
	if not Fu.CanCastAbility(bristlebackAbility) then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local radius = 350
	local manaCost = bristlebackAbility:GetManaCost()
	local manaAfter = Fu.GetManaAfter(manaCost)
	local manaThreshold = Fu.GetManaThreshold(bot, manaCost, { bristlebackAbility, hairballAbility })
	if isEngaging then
		if
			Fu.IsValidHero(botTarget)
			and Fu.CanBeAttacked(botTarget)
			and Fu.IsInRange(bot, botTarget, radius)
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
			and (Fu.IsDisabled(botTarget) or botTarget:GetCurrentMovementSpeed() <= 250 or not Fu.IsMoving(botTarget))
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	if isRetreating and not Fu.IsRealInvisible(bot) and bot:WasRecentlyDamagedByAnyHero(3.0) then
		for _, enemyHero in ipairs(nearbyEnemies) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.CanBeAttacked(enemyHero)
				and Fu.IsInRange(bot, enemyHero, radius)
				and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
				and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
				and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
				and enemyHero:GetAttackTarget() == bot
			then
				local alliesNearBot = Fu.GetAlliesNearLoc(bot:GetLocation(), 1200)
				local enemiesNearBot = Fu.GetEnemiesNearLoc(bot:GetLocation(), 1200)
				if #enemiesNearBot < #alliesNearBot + 2 then
					return BOT_ACTION_DESIRE_HIGH, enemyHero:GetLocation()
				end
			end
		end
	end
	local nearbyCreeps = bot:GetNearbyCreeps(800, true)
	if
		(Fu.IsPushing(bot) or Fu.IsDefending(bot))
		and manaAfter > manaThreshold + 0.1
		and isAttacking
		and #nearbyEnemies == 0
	then
		for _, creep in pairs(nearbyCreeps) do
			if Fu.IsValid(creep) and Fu.CanBeAttacked(creep) and not Fu.IsRunning(creep) then
				local aoeLocation = bot:FindAoELocation(true, false, creep:GetLocation(), 0, radius, 0, 0)
				if aoeLocation.count >= 4 or aoeLocation.count >= 1 and creep:GetHealth() >= 1000 then
					return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
				end
			end
		end
	end
	if Fu.IsFarming(bot) and manaAfter > manaThreshold and isAttacking then
		for _, creep in pairs(nearbyCreeps) do
			if Fu.IsValid(creep) and Fu.CanBeAttacked(creep) and not Fu.IsRunning(creep) then
				local aoeLocation = bot:FindAoELocation(true, false, creep:GetLocation(), 0, radius, 0, 0)
				if aoeLocation.count >= 5 or aoeLocation.count >= 2 and creep:IsAncientCreep() then
					return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
				end
			end
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if
			Fu.IsRoshan(botTarget)
			and Fu.CanBeAttacked(botTarget)
			and Fu.IsInRange(bot, botTarget, radius * 2)
			and manaAfter > manaThreshold
			and isAttacking
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if
			Fu.IsTormentor(botTarget)
			and Fu.IsInRange(bot, botTarget, radius * 2)
			and manaAfter > manaThreshold
			and isAttacking
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.ConsiderHairball()
	if not Fu.CanCastAbility(hairballAbility) then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local castRange = Fu.GetProperCastRange(false, bot, hairballAbility:GetCastRange())
	local radius = hairballAbility:GetSpecialValueInt("radius")
	local manaCost = hairballAbility:GetManaCost()
	local manaAfter = Fu.GetManaAfter(manaCost)
	local manaThreshold = Fu.GetManaThreshold(bot, manaCost, { bristlebackAbility })
	if Fu.IsInTeamFight(bot, 1400) then
		local castLocation = Fu.GetAoeEnemyHeroLocation(bot, castRange, radius, 2)
		if castLocation ~= nil and manaAfter > manaThreshold then
			return BOT_ACTION_DESIRE_HIGH, castLocation
		end
	end
	if isEngaging then
		if
			Fu.IsValidHero(botTarget)
			and Fu.CanBeAttacked(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
			and manaAfter > manaThreshold
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	if isRetreating and not Fu.IsRealInvisible(bot) and bot:WasRecentlyDamagedByAnyHero(3.0) then
		for _, enemyHero in ipairs(nearbyEnemies) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.CanBeAttacked(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and Fu.IsInRange(bot, enemyHero, castRange)
				and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
			then
				if
					Fu.IsChasingTarget(enemyHero, bot)
					or #nearbyEnemies > #nearbyAllies and enemyHero:GetAttackTarget() == bot
				then
					return BOT_ACTION_DESIRE_HIGH, (bot:GetLocation() + enemyHero:GetLocation()) / 2
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.ConsiderWarpath()
	if not Fu.CanCastAbility(warpathAbility) then
		return BOT_ACTION_DESIRE_NONE
	end
	local enemiesWithin1200 = Fu.GetEnemiesNearLoc(bot:GetLocation(), 1200)
	local enemiesWithin800 = Fu.GetEnemiesNearLoc(bot:GetLocation(), 800)
	if isTeamFight then
		if #enemiesWithin800 > #enemiesWithin1200 or botHp < 0.5 and bot:WasRecentlyDamagedByAnyHero(4.0) then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if isRetreating and not Fu.IsRealInvisible(bot) then
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.IsInRange(bot, enemyHero, 500)
				and Fu.IsChasingTarget(enemyHero, bot)
			then
				if
					Fu.GetTotalEstimatedDamageToTarget(nearbyEnemies, bot, 8.0) > bot:GetHealth() * 1.15
					or #nearbyEnemies > #nearbyAllies and botHp < 0.4
				then
					return BOT_ACTION_DESIRE_HIGH
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
return X
