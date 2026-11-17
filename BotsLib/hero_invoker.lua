-- Invoker: skill build, item build, and ability use for this hero.
-- Accidental globals made file-local (#13): every bot shares one Lua state, so these were shared.
local botTarget, CataclysmDesire, ConsiderFirstSpell, CheckAbilityUsage
local X = {}
local bot = GetBot()
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local AbilityContext = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local Utils = require(GetScriptDirectory() .. "/FuncLib/systems/utils")
local Minion = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local sTalentList = Fu.Skill.GetTalentList(bot)
local sAbilityList = Fu.Skill.GetAbilityList(bot)
local sRole = Fu.Item.GetRoleItemsBuyList(bot)
local tTalentTreeList = {
	-- 7.41b replaced +1 Orb Levels (right) with Forged Spirit armor reduction; take +Chaos Meteors (left).
	{ ["t25"] = { 10, 0 }, ["t20"] = { 0, 10 }, ["t15"] = { 10, 0 }, ["t10"] = { 10, 0 } },
	{ ["t25"] = { 0, 10 }, ["t20"] = { 0, 10 }, ["t15"] = { 10, 0 }, ["t10"] = { 10, 0 } },
}
-- 8 levels per orb: 7.41b's extra points at levels 6, 12 and 18 fund the 8th orb level.
local tAllAbilityBuildList = {
	{ 2, 1, 2, 1, 3, 1, 2, 1, 2, 2, 3, 3, 3, 3, 3, 3, 2, 2, 1, 1, 1, 2, 1, 3 },
	{ 3, 1, 3, 1, 2, 3, 1, 3, 1, 3, 2, 3, 2, 3, 2, 2, 2, 2, 1, 1, 1, 3, 1, 2 },
}
local nAbilityBuildList = tAllAbilityBuildList[1]
local nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList[1])
local sRoleItemsBuyList = {}
-- 7.41: Invoker's Aghanim's Scepter and Shard stay inert until he activates them and picks one
-- of three upgrades. Tested (games 016 and 017): bought, they sit in the inventory as castable
-- items with no buff; cast by the bot, nothing changes (same abilities, still inert). The bot API
-- cannot make the pick, so he does not buy them.
sRoleItemsBuyList["pos_2"] = {
	"item_ranged_carry_outfit",
	"item_urn_of_shadows",
	"item_spirit_vessel",
	"item_orchid",
	"item_sphere",
	"item_black_king_bar",
	"item_dragon_lance",
	"item_hurricane_pike",
	"item_travel_boots",
	"item_bloodthorn",
	"item_sheepstick",
	"item_moon_shard",
	"item_travel_boots_2",
}
sRoleItemsBuyList["pos_2_qe"] = {
	"item_tango",
	"item_double_branches",
	"item_null_talisman",
	"item_magic_wand",
	"item_boots",
	"item_hand_of_midas",
	"item_power_treads",
	"item_meteor_hammer",
	"item_sphere",
	"item_black_king_bar",
	"item_travel_boots",
	"item_octarine_core",
	"item_sheepstick",
	"item_refresher",
	"item_moon_shard",
	"item_travel_boots_2",
}
sRoleItemsBuyList["pos_1"] = sRoleItemsBuyList["pos_2"]
sRoleItemsBuyList["pos_3"] = sRoleItemsBuyList["pos_2"]
sRoleItemsBuyList["pos_4"] = sRoleItemsBuyList["pos_2"]
sRoleItemsBuyList["pos_5"] = sRoleItemsBuyList["pos_2"]
X["sBuyList"] = sRoleItemsBuyList[sRole]
if Utils["GameStates"]["invoker"] == nil then
	if (sRole == "pos_2" or sRole == "pos_1") and RandomInt(1, 9) >= 3 then
		Utils["GameStates"]["invoker"] = { roleType = "pos_2_qe" }
	else
		Utils["GameStates"]["invoker"] = { roleType = "pos_2" }
	end
else
	if Utils["GameStates"]["invoker"].roleType == "pos_2_qe" then
		X["sBuyList"] = sRoleItemsBuyList["pos_2_qe"]
		nAbilityBuildList = tAllAbilityBuildList[2]
		nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList[2])
	end
end
X["sSellList"] = {
	"item_black_king_bar",
	"item_quelling_blade",
	"item_sheepstick",
	"item_hand_of_midas",
	"item_octarine_core",
	"item_null_talisman",
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
	if Utils.IsUnitWithName(hMinionUnit, "forged_spirit") then
		botTarget = Fu.GetProperTarget(bot)
		local attackTarget = hMinionUnit:GetAttackTarget()
		if attackTarget == nil then
			hMinionUnit:GetTarget()
		end
		local enemyTowers = bot:GetNearbyTowers(700, true)
		if botTarget ~= nil and (#enemyTowers < 1 or Fu.GetHP(botTarget) < 0.2) then
			if botTarget ~= nil then
				hMinionUnit:Action_AttackUnit(botTarget, false)
				return
			end
		end
		if attackTarget ~= nil and (#enemyTowers < 1 or Fu.GetHP(attackTarget) < 0.2) then
			if attackTarget ~= nil then
				hMinionUnit:Action_AttackUnit(attackTarget, false)
				return
			end
			Minion.MinionThink(hMinionUnit)
		end
		if
			Fu.GetHP(hMinionUnit) < 0.5
			and botTarget ~= nil
			and Fu.IsInRange(hMinionUnit, botTarget, botTarget:GetAttackRange())
		then
			hMinionUnit:Action_MoveToLocation(Fu.GetTeamFountain())
			return
		end
		if Fu.IsLaning(bot) or Fu.IsFarming(bot) then
			if GetUnitToUnitDistance(hMinionUnit, bot) > 500 then
				hMinionUnit:Action_AttackMove(bot:GetLocation() + RandomVector(220))
			end
		end
	else
		Minion.MinionThink(hMinionUnit)
	end
end
local quasAbility = SafeAbility(bot:GetAbilityByName("invoker_quas"), "invoker_quas", "invoker")
local wexAbility = SafeAbility(bot:GetAbilityByName("invoker_wex"), "invoker_wex", "invoker")
local exortAbility = SafeAbility(bot:GetAbilityByName("invoker_exort"), "invoker_exort", "invoker")
local invokeAbility = SafeAbility(bot:GetAbilityByName("invoker_invoke"), "invoker_invoke", "invoker")
local coldSnapAbility = SafeAbility(bot:GetAbilityByName("invoker_cold_snap"), "invoker_cold_snap", "invoker")
local ghostWalkAbility = SafeAbility(bot:GetAbilityByName("invoker_ghost_walk"), "invoker_ghost_walk", "invoker")
local tornadoAbility = SafeAbility(bot:GetAbilityByName("invoker_tornado"), "invoker_tornado", "invoker")
local empAbility = SafeAbility(bot:GetAbilityByName("invoker_emp"), "invoker_emp", "invoker")
local alacrityAbility = SafeAbility(bot:GetAbilityByName("invoker_alacrity"), "invoker_alacrity", "invoker")
local chaosMeteorAbility = SafeAbility(bot:GetAbilityByName("invoker_chaos_meteor"), "invoker_chaos_meteor", "invoker")
local sunstrikeAbility = SafeAbility(bot:GetAbilityByName("invoker_sun_strike"), "invoker_sun_strike", "invoker")
local forgeSpiritAbility = SafeAbility(bot:GetAbilityByName("invoker_forge_spirit"), "invoker_forge_spirit", "invoker")
local iceWallAbility = SafeAbility(bot:GetAbilityByName("invoker_ice_wall"), "invoker_ice_wall", "invoker")
local deafeningBlastAbility =
	SafeAbility(bot:GetAbilityByName("invoker_deafening_blast"), "invoker_deafening_blast", "invoker")
local cataclysmName = "Cataclysm"
local modifierWindWaker = "modifier_wind_waker"
local modifierItemWindWaker = "modifier_item_wind_waker"
local modifierItemCyclone = "modifier_item_cyclone"
local modifierEulCyclone = "modifier_eul_cyclone"
local modifierColdSnap = "modifier_invoker_cold_snap"
local modifierColdSnapFreeze = "modifier_invoker_cold_snap_freeze"
local modifierGhostWalkSelf = "modifier_invoker_ghost_walk_self"
local modifierGhostWalkEnemy = "modifier_invoker_ghost_walk_enemy"
local modifierTornado = "modifier_invoker_tornado"
local modifierEmp = "modifier_invoker_emp"
local modifierEmpPullThinker = "modifier_invoker_emp_pull_thinker"
local modifierEmpPull = "modifier_invoker_emp_pull"
local modifierAlacrity = "modifier_invoker_alacrity"
local modifierChaosMeteorLand = "modifier_invoker_chaos_meteor_land"
local modifierChaosMeteorBurn = "modifier_invoker_chaos_meteor_burn"
local modifierIceWallThinker = "modifier_invoker_ice_wall_thinker"
local modifierIceWallSlowAura = "modifier_invoker_ice_wall_slow_aura"
local modifierDeafeningBlastDisarm = "modifier_invoker_deafening_blast_disarm"
local modifierAttackVisuals = "modifier_invoker_attack_visuals"
local airborneModifiers = {
	modifierTornado,
	"modifier_item_cyclone",
	"modifier_eul_cyclone",
	"modifier_wind_waker",
	"modifier_item_wind_waker",
	"modifier_brewmaster_storm_cyclone",
}
local coldSnapDesire, coldSnapTarget
local ghostWalkDesire
local tornadoDesire, tornadoLocation
local empDesire, empLocation
local alacrityDesire, alacrityTarget
local chaosMeteorDesire, chaosMeteorLocation
local sunstrikeDesire, sunstrikeLocation
local forgeSpiritDesire
local iceWallDesire
local deafeningBlastDesire, deafeningBlastLocation
local unusedSpellWeights = {
	ColdSnap = 20,
	GhostWalk = 35,
	Tornado = 30,
	EMP = 30,
	Alacrity = 17,
	ChaosMeteor = 55,
	Sunstrike = 25,
	ForgeSpirit = 30,
	IceWall = 25,
	DeafeningBlast = 40,
	Cataclysm = 100,
	Verified = {},
}
local lastCastTime = {
	ColdSnap = -100,
	GhostWalk = -100,
	Tornado = -100,
	EMP = -100,
	Alacrity = -100,
	ChaosMeteor = -100,
	Sunstrike = -100,
	ForgeSpirit = -100,
	IceWall = -100,
	DeafeningBlast = -100,
	Cataclysm = -100,
}
local spellKeyByAbilityName = {
	invoker_cold_snap = "ColdSnap",
	invoker_ghost_walk = "GhostWalk",
	invoker_tornado = "Tornado",
	invoker_emp = "EMP",
	invoker_alacrity = "Alacrity",
	invoker_chaos_meteor = "ChaosMeteor",
	invoker_sun_strike = "Sunstrike",
	invoker_forge_spirit = "ForgeSpirit",
	invoker_ice_wall = "IceWall",
	invoker_deafening_blast = "DeafeningBlast",
}
local comboRightClick = { "Right Click Combo", true }
local comboCycloneMeteorBlast = { "Eul/Cyclone, Meteor & Blast Combo", true }
local comboTornadoMeteorBlast = { "Tornado, Meteor & Blast Combo", true }
local comboDot = { "DoT Combo", true }
local comboTornadoEmp = { "Tornado & emp", true }
local comboCycloneColdSnap = { "Eul/Cyclone, Cold Snap Combo", true }
local comboColdSnap = { "Cold Snap Combo", true }
local comboFixedPosition = { "Fixed Position Combo", true }
local comboSlowed = { "Slowed Combo", true }
local optionInstanceHelper = { "Instance Helper", true }
local optionKillSteal = { "Kill Steal", true }
local optionLinkenBreaker = { "Linken Breaker", true }
local optionInterrupt = { "Interrupt", true }
local optionSpellProtection = { "Spell Protection", true }
local optionDefend = { "Defend", true }
local optionIceWallHelper = { "Ice Wall Helper", true }
local comboTornadoSunstrike = { "Tornado & Sunstrike/Cataclysm", true }
local empDelay
local tornadoLiftDuration
local botTarget
local laningManaReserve = 280
local lastMana = -1
local nearbyEnemies, nearbyAllies, isLaningPhase
local isEngaging
local isRetreating
local isAttacking
local hpRatio
local mpRatio
local isTeamFight
function X.SkillsComplement()
	CheckAbilityUsage()
	if Fu.CanNotUseAbility(bot) then
		return
	end
	local context = AbilityContext.Build(bot)
	isEngaging = context.isEngaging
	isRetreating = context.isRetreating
	isAttacking = Fu.IsAttacking(bot)
	hpRatio = context.hp
	mpRatio = context.mp
	isTeamFight = context.isTeamFight
	nearbyEnemies = Fu.GetNearbyHeroes(bot, 1600, true)
	nearbyAllies = Fu.GetNearbyHeroes(bot, 1600, false)
	isLaningPhase = Fu.IsInLaningPhase(bot)
	if
		bot:HasModifier(modifierGhostWalkSelf)
		and not bot:HasModifier("modifier_item_dustofappearance")
		and isRetreating
	then
		return
	end
	botTarget = context.target
	tornadoLiftDuration = tornadoAbility:GetSpecialValueFloat("lift_duration")
	ConsiderFirstSpell()
	X.ConsiderClearActions()
	X.ConsiderPreInvoke()
	CataclysmDesire = X.ConsiderCataclysm()
	if CataclysmDesire > 0 then
		X.CastInvokerSpell(cataclysmName)
		return
	end
	sunstrikeDesire, sunstrikeLocation = X.ConsiderSunstrike()
	if sunstrikeDesire > 0 then
		X.CastInvokerSpell(sunstrikeAbility, sunstrikeLocation)
		return
	end
	ghostWalkDesire = X.ConsiderGhostWalk()
	if ghostWalkDesire > 0 then
		X.CastInvokerSpell(ghostWalkAbility)
		return
	end
	local comboWindow = 2
	if wexAbility:GetLevel() >= 4 then
		tornadoDesire, tornadoLocation = X.ConsiderTornado()
		if tornadoDesire > 0 then
			X.CastInvokerSpell(tornadoAbility, tornadoLocation)
			return
		end
		empDesire, empLocation = X.ConsiderEMP()
		if empDesire > 0 then
			X.CastInvokerSpell(empAbility, empLocation)
			return
		end
	end
	if exortAbility:GetLevel() >= 4 then
		chaosMeteorDesire, chaosMeteorLocation = X.ConsiderChaosMeteor()
		if chaosMeteorDesire > 0 then
			X.CastInvokerSpell(chaosMeteorAbility, chaosMeteorLocation)
			return
		end
		deafeningBlastDesire, deafeningBlastLocation = X.ConsiderDeafeningBlast()
		if deafeningBlastDesire > 0 then
			X.CastInvokerSpell(deafeningBlastAbility, deafeningBlastLocation)
			return
		end
	end
	if DotaTime() - lastCastTime["Tornado"] <= comboWindow then
		empDesire, empLocation = X.ConsiderEMP()
		if empDesire > 0 then
			X.CastInvokerSpell(empAbility, empLocation)
			return
		end
		chaosMeteorDesire, chaosMeteorLocation = X.ConsiderChaosMeteor()
		if chaosMeteorDesire > 0 then
			X.CastInvokerSpell(chaosMeteorAbility, chaosMeteorLocation)
			return
		end
	end
	if DotaTime() - lastCastTime["ChaosMeteor"] <= comboWindow then
		deafeningBlastDesire, deafeningBlastLocation = X.ConsiderDeafeningBlast()
		if deafeningBlastDesire > 0 then
			X.CastInvokerSpell(deafeningBlastAbility, deafeningBlastLocation)
			return
		end
		CataclysmDesire = X.ConsiderCataclysm()
		if CataclysmDesire > 0 then
			X.CastInvokerSpell(cataclysmName)
			return
		end
		coldSnapDesire, coldSnapTarget = X.ConsiderColdSnap()
		if coldSnapDesire > 0 then
			X.CastInvokerSpell(coldSnapAbility, coldSnapTarget)
			return
		end
	end
	if DotaTime() - lastCastTime["ColdSnap"] <= comboWindow then
		alacrityDesire, alacrityTarget = X.ConsiderAlacrity()
		if alacrityDesire > 0 then
			X.CastInvokerSpell(alacrityAbility, alacrityTarget)
			return
		end
		chaosMeteorDesire, chaosMeteorLocation = X.ConsiderChaosMeteor()
		if chaosMeteorDesire > 0 then
			X.CastInvokerSpell(chaosMeteorAbility, chaosMeteorLocation)
			return
		end
		tornadoDesire, tornadoLocation = X.ConsiderTornado()
		if tornadoDesire > 0 then
			X.CastInvokerSpell(tornadoAbility, tornadoLocation)
			return
		end
	end
	if DotaTime() - lastCastTime["Alacrity"] <= comboWindow then
		coldSnapDesire, coldSnapTarget = X.ConsiderColdSnap()
		if coldSnapDesire > 0 then
			X.CastInvokerSpell(coldSnapAbility, coldSnapTarget)
			return
		end
		forgeSpiritDesire = X.ConsiderForgeSpirit()
		if forgeSpiritDesire > 0 then
			X.CastInvokerSpell(forgeSpiritAbility)
			return
		end
	end
	if DotaTime() - lastCastTime["ForgeSpirit"] <= comboWindow then
		coldSnapDesire, coldSnapTarget = X.ConsiderColdSnap()
		if coldSnapDesire > 0 then
			X.CastInvokerSpell(coldSnapAbility, coldSnapTarget)
			return
		end
		alacrityDesire, alacrityTarget = X.ConsiderAlacrity()
		if alacrityDesire > 0 then
			X.CastInvokerSpell(alacrityAbility, alacrityTarget)
			return
		end
	end
	if DotaTime() - lastCastTime["IceWall"] <= comboWindow then
		coldSnapDesire, coldSnapTarget = X.ConsiderColdSnap()
		if coldSnapDesire > 0 then
			X.CastInvokerSpell(coldSnapAbility, coldSnapTarget)
			return
		end
		chaosMeteorDesire, chaosMeteorLocation = X.ConsiderChaosMeteor()
		if chaosMeteorDesire > 0 then
			X.CastInvokerSpell(chaosMeteorAbility, chaosMeteorLocation)
			return
		end
		empDesire, empLocation = X.ConsiderEMP()
		if empDesire > 0 then
			X.CastInvokerSpell(empAbility, empLocation)
			return
		end
	end
	if DotaTime() - lastCastTime["DeafeningBlast"] <= comboWindow then
		sunstrikeDesire, sunstrikeLocation = X.ConsiderSunstrike()
		if sunstrikeDesire > 0 then
			X.CastInvokerSpell(sunstrikeAbility, sunstrikeLocation)
			return
		end
		coldSnapDesire, coldSnapTarget = X.ConsiderColdSnap()
		if coldSnapDesire > 0 then
			X.CastInvokerSpell(coldSnapAbility, coldSnapTarget)
			return
		end
	end
	forgeSpiritDesire = X.ConsiderForgeSpirit()
	if forgeSpiritDesire > 0 then
		X.CastInvokerSpell(forgeSpiritAbility)
		return
	end
	coldSnapDesire, coldSnapTarget = X.ConsiderColdSnap()
	if coldSnapDesire > 0 then
		X.CastInvokerSpell(coldSnapAbility, coldSnapTarget)
		return
	end
	alacrityDesire, alacrityTarget = X.ConsiderAlacrity()
	if alacrityDesire > 0 then
		X.CastInvokerSpell(alacrityAbility, alacrityTarget)
		return
	end
	tornadoDesire, tornadoLocation = X.ConsiderTornado()
	if tornadoDesire > 0 then
		X.CastInvokerSpell(tornadoAbility, tornadoLocation)
		return
	end
	empDesire, empLocation = X.ConsiderEMP()
	if empDesire > 0 then
		X.CastInvokerSpell(empAbility, empLocation)
		return
	end
	iceWallDesire = X.ConsiderIceWall()
	if iceWallDesire > 0 then
		X.CastInvokerSpell(iceWallAbility)
		return
	end
	if
		isLaningPhase
		and bot:GetLevel() >= 2
		and bot:GetLevel() <= 12
		and hpRatio > 0.75
		and #nearbyEnemies <= #nearbyAllies
		and not isRetreating
		and not isEngaging
		and not isTeamFight
	then
		local nearbyLaneCreeps = bot:GetNearbyLaneCreeps(300, true)
		local enemyTowers = bot:GetNearbyTowers(700, true)
		if nearbyLaneCreeps ~= nil and #nearbyLaneCreeps > 3 and enemyTowers ~= nil and #enemyTowers >= 1 then
			return
		end
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValidHero(enemyHero)
				and hpRatio >= Fu.GetHP(enemyHero)
				and bot:GetAttackTarget() ~= enemyHero
				and (
					bot:HasModifier(modifierAlacrity)
					or enemyHero:HasModifier(modifierColdSnapFreeze)
					or enemyHero:HasModifier(modifierChaosMeteorBurn)
				)
			then
				bot:ActionQueue_AttackUnit(enemyHero, true)
				return
			end
		end
	end
end
function X.ConsiderInvoke()
	if not invokeAbility:IsFullyCastable() then
		return
	end
end
local lastPreInvokeTime = 0
function X.ConsiderPreInvoke()
	if quasAbility:IsTrained() and wexAbility:IsTrained() and exortAbility:IsTrained() then
		local firstSpellSlot = bot:GetAbilityInSlot(3)
		local secondSpellSlot = bot:GetAbilityInSlot(4)
		if
			firstSpellSlot ~= nil
			and secondSpellSlot ~= nil
			and not firstSpellSlot:IsFullyCastable()
			and secondSpellSlot:IsFullyCastable()
			and invokeAbility:IsFullyCastable()
		then
			if secondSpellSlot == coldSnapAbility then
				X.InvokeActualSpell(coldSnapAbility)
			elseif secondSpellSlot == tornadoAbility then
				X.InvokeActualSpell(tornadoAbility)
			elseif secondSpellSlot == ghostWalkAbility then
				X.InvokeActualSpell(ghostWalkAbility)
			elseif secondSpellSlot == iceWallAbility then
				X.InvokeActualSpell(iceWallAbility)
			elseif secondSpellSlot == empAbility then
				X.InvokeActualSpell(empAbility)
			elseif secondSpellSlot == alacrityAbility then
				X.InvokeActualSpell(alacrityAbility)
			elseif secondSpellSlot == sunstrikeAbility then
				X.InvokeActualSpell(sunstrikeAbility)
			elseif secondSpellSlot == forgeSpiritAbility then
				X.InvokeActualSpell(forgeSpiritAbility)
			elseif secondSpellSlot == chaosMeteorAbility then
				X.InvokeActualSpell(chaosMeteorAbility)
			elseif secondSpellSlot == deafeningBlastAbility then
				X.InvokeActualSpell(deafeningBlastAbility)
			end
		end
	end
	if DotaTime() - lastPreInvokeTime > 1 then
		if
			isEngaging
			and not isAttacking
			and not bot:WasRecentlyDamagedByAnyHero(4)
			and invokeAbility:IsFullyCastable()
		then
			if nearbyEnemies == nil or #nearbyEnemies <= 0 then
				if X.CanAbilityPossiblyBeCasted(tornadoAbility) and not X.IsAbilityAvailableOnSlots(tornadoAbility) then
					log("Invoke Tornado as idel spell")
					X.InvokeActualSpell(tornadoAbility)
				end
				if
					X.CanAbilityPossiblyBeCasted(coldSnapAbility) and not X.IsAbilityAvailableOnSlots(coldSnapAbility)
				then
					log("Invoke ColdSnap as idel spell")
					X.InvokeActualSpell(coldSnapAbility)
				end
			end
		end
		if hpRatio < 0.6 then
			if
				wexAbility:IsTrained()
				and isRetreating
				and (
					bot:HasModifier("modifier_invoker_quas_instance")
					or bot:HasModifier("modifier_invoker_exort_instance")
				)
			then
				X.QueueElements(wexAbility, wexAbility, wexAbility)
			elseif
				quasAbility:IsTrained()
				and (
					bot:HasModifier("modifier_invoker_wex_instance")
					or bot:HasModifier("modifier_invoker_exort_instance")
				)
			then
				X.QueueElements(quasAbility, quasAbility, quasAbility)
			end
		else
			if wexAbility:IsTrained() then
				if
					(not exortAbility:IsTrained() or wexAbility:GetLevel() >= exortAbility:GetLevel())
					and (
						bot:HasModifier("modifier_invoker_quas_instance")
						or bot:HasModifier("modifier_invoker_exort_instance")
					)
				then
					X.QueueElements(wexAbility, wexAbility, wexAbility)
				elseif
					bot:HasModifier("modifier_invoker_quas_instance")
					or bot:HasModifier("modifier_invoker_wex_instance")
				then
					X.QueueElements(exortAbility, exortAbility, exortAbility)
				end
			elseif
				exortAbility:IsTrained()
				and (
					bot:HasModifier("modifier_invoker_quas_instance")
					or bot:HasModifier("modifier_invoker_wex_instance")
				)
			then
				X.QueueElements(exortAbility, exortAbility, exortAbility)
			end
		end
		lastPreInvokeTime = DotaTime()
	end
end
function X.InvokeElements(element1, element2, element3)
	bot:ActionPush_UseAbility(element1)
	bot:ActionPush_UseAbility(element2)
	bot:ActionPush_UseAbility(element3)
end
function X.QueueElements(element1, element2, element3)
	bot:ActionQueue_UseAbility(element1)
	bot:ActionQueue_UseAbility(element2)
	bot:ActionQueue_UseAbility(element3)
end
function X.CanUseRefresherShard()
	local chaosMeteorManaCost = chaosMeteorAbility:GetManaCost()
	local sunstrikeManaCost = sunstrikeAbility:GetManaCost()
	if
		sunstrikeAbility:GetCooldownTimeRemaining() >= 10
		and (sunstrikeAbility:GetCooldownTimeRemaining() / sunstrikeAbility:GetCooldown() <= 0.7 or X.CanAbilityPossiblyBeCasted(
			cataclysmName
		))
		and X.IsAbilityAvailableOnSlots(sunstrikeAbility)
		and bot:GetMana() >= sunstrikeManaCost * 2 + sunstrikeManaCost
	then
		local cataclysmDesire, _ = X.GoodTimeToUseCataclysmGlobally()
		if cataclysmDesire > 0 then
			return true
		end
	end
	if
		chaosMeteorAbility:GetCooldownTimeRemaining() >= 10
		and chaosMeteorAbility:GetCooldownTimeRemaining() / chaosMeteorAbility:GetCooldown() <= 0.7
		and X.IsAbilityAvailableOnSlots(chaosMeteorAbility)
		and #nearbyEnemies > 0
		and (isEngaging or Fu.IsInTeamFight(bot))
		and bot:GetMana() >= chaosMeteorManaCost * 2 + chaosMeteorManaCost
	then
		return true
	end
	return false
end
function X.ConsiderClearActions()
	if DotaTime() <= 10 then
		return
	end
	local queuedActionCount = bot:NumQueuedActions()
	if queuedActionCount > 0 then
		if queuedActionCount >= 6 then
			log("Clear Invokers queued actions")
			bot:Action_ClearActions(false)
			return
		end
		for i = 1, queuedActionCount do
			local actionType = bot:GetQueuedActionType(i)
			log("Enqueued actions i=%s, type=%s", i, actionType)
			if actionType == -1 then
				log("Invokers has queued invalid action (-1). Clear action queue.")
				bot:Action_ClearActions(false)
				return
			end
		end
	end
end
function X.CastInvokerSpell(ability, target)
	local abilityName
	if type(ability) == "string" and ability == "Cataclysm" then
		abilityName = ability
		ability = sunstrikeAbility
	else
		abilityName = ability:GetName()
	end
	log("%s - Invoker checking to cast %s", DotaTime(), abilityName)
	if X.IsAbilityReadyForInvoke(ability) then
		X.InvokeActualSpell(ability)
	end
	if X.IsAbilityReadyForCast(ability) then
		log("%s - Invoker has it on slot, going to cast %s", DotaTime(), abilityName)
		bot:Action_ClearActions(false)
		if abilityName == cataclysmName then
			bot:ActionQueue_UseAbilityOnEntity(ability, bot)
		elseif ability == forgeSpiritAbility or ability == iceWallAbility or ability == ghostWalkAbility then
			bot:ActionQueue_UseAbility(ability)
		-- Radial (no-target) Deafening Blast only with its talent, special_bonus_unique_invoker_2 (datafeed),
		-- not at any level 25: the default talent build takes the other level-25 talent, and a no-target
		-- order for the point-cast blast does nothing.
		elseif
			ability == deafeningBlastAbility
			and (function()
				local radialBlastTalent = bot:GetAbilityByName("special_bonus_unique_invoker_2")
				return radialBlastTalent ~= nil and radialBlastTalent:IsTrained()
			end)()
		then
			bot:ActionQueue_UseAbility(ability)
		elseif
			ability == deafeningBlastAbility
			or ability == sunstrikeAbility
			or ability == chaosMeteorAbility
			or ability == empAbility
			or ability == tornadoAbility
		then
			bot:ActionQueue_UseAbilityOnLocation(ability, target)
		elseif ability == alacrityAbility or ability == coldSnapAbility then
			bot:ActionQueue_UseAbilityOnEntity(ability, target)
		else
			log("%s - [ERROR] Tried to cast unsupported spell: %s", DotaTime(), abilityName)
			log("Stack Trace:", debug.traceback())
		end
		log("%s - Invoker tried to cast %s", DotaTime(), abilityName)
	else
	end
end
function X.ConsiderColdSnap()
	if not X.CanAbilityPossiblyBeCasted(coldSnapAbility) then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local rangeBuffer = 60
	local castRange = Fu.GetProperCastRange(false, bot, coldSnapAbility:GetCastRange())
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and Fu.IsInRange(bot, enemyHero, castRange - rangeBuffer)
			and (not isLaningPhase or isLaningPhase and Fu.GetManaAfter(coldSnapAbility:GetManaCost()) > 0.5 or Fu.GetHP(
				enemyHero
			) < 0.5)
			and (enemyHero:IsChanneling() or enemyHero:HasModifier("modifier_item_urn_damage") or enemyHero:HasModifier(
				"modifier_item_spirit_vessel_damage"
			) or enemyHero:HasModifier("modifier_invoker_chaos_meteor_burn") or Fu.IsChasingTarget(bot, enemyHero))
			and not Fu.IsSuspiciousIllusion(enemyHero)
		then
			return BOT_ACTION_DESIRE_HIGH, enemyHero
		end
	end
	if isEngaging then
		if
			Fu.IsValidHero(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange - rangeBuffer)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and (
				not isLaningPhase
				or isLaningPhase and Fu.GetManaAfter(coldSnapAbility:GetManaCost()) > 0.5 and isAttacking
				or isLaningPhase and mpRatio > 0.5 and Fu.IsAttacking(botTarget)
				or Fu.GetHP(botTarget) < 0.5
			)
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end
	if Fu.IsLaning(bot) then
		local enemyHero
		if nearbyEnemies ~= nil and #nearbyEnemies >= 1 then
			enemyHero = nearbyEnemies[1]
		else
			return BOT_ACTION_DESIRE_NONE, nil
		end
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and Fu.IsInRange(bot, enemyHero, bot:GetAttackRange() - rangeBuffer)
			and not Fu.IsSuspiciousIllusion(enemyHero)
			and bot:GetMana() - coldSnapAbility:GetManaCost() >= laningManaReserve
			and (
				Fu.GetManaAfter(coldSnapAbility:GetManaCost()) > 0.4 and isAttacking
				or mpRatio > 0.5 and Fu.IsAttacking(enemyHero)
			)
		then
			return BOT_ACTION_DESIRE_HIGH, enemyHero, "对线消耗:" .. Fu.Chat.GetNormName(enemyHero)
		end
	end
	if isRetreating then
		local enemyHero
		if nearbyEnemies ~= nil and #nearbyEnemies >= 1 then
			enemyHero = nearbyEnemies[1]
		else
			return BOT_ACTION_DESIRE_NONE, nil
		end
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and Fu.IsChasingTarget(enemyHero, bot)
			and GetUnitToUnitDistance(enemyHero, bot) > enemyHero:GetAttackRange() - 200
			and Fu.IsInRange(bot, enemyHero, castRange - rangeBuffer)
			and not Fu.IsSuspiciousIllusion(enemyHero)
		then
			if bot:WasRecentlyDamagedByAnyHero(2) then
				return BOT_ACTION_DESIRE_HIGH, enemyHero
			end
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if Fu.IsRoshan(botTarget) and Fu.IsInRange(bot, botTarget, castRange) then
			return BOT_ACTION_DESIRE_HIGH, botTarget
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function X.ConsiderGhostWalk()
	if not X.CanAbilityPossiblyBeCasted(ghostWalkAbility) then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	if isRetreating or hpRatio <= 0.4 and #nearbyEnemies >= #nearbyAllies then
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValidHero(enemyHero)
				and (Fu.IsChasingTarget(enemyHero, bot) or GetUnitToUnitDistance(enemyHero, bot) < enemyHero:GetAttackRange() + 100)
				and (isLaningPhase and bot:WasRecentlyDamagedByAnyHero(2) and hpRatio < 0.7 or not isLaningPhase)
				and not isAttacking
			then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	if Fu.IsStunProjectileIncoming(bot, 1200) then
		return BOT_ACTION_DESIRE_HIGH
	end
	if
		#nearbyEnemies >= 2
		and #nearbyEnemies > #nearbyAllies
		and Fu.IsValidHero(nearbyEnemies[1])
		and nearbyEnemies[1]:GetLevel() >= bot:GetLevel() - 2
	then
		return BOT_ACTION_DESIRE_HIGH
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderTornado()
	local comboWindow = 4
	if
		not X.CanAbilityPossiblyBeCasted(tornadoAbility)
		or (
			DotaTime() - lastCastTime["ChaosMeteor"] <= comboWindow
			or DotaTime() - lastCastTime["DeafeningBlast"] <= comboWindow
			or DotaTime() - lastCastTime["Sunstrike"] <= comboWindow
			or DotaTime() - lastCastTime["Cataclysm"] <= comboWindow
		)
	then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local castRange = Fu.GetProperCastRange(false, bot, tornadoAbility:GetCastRange())
	local castPoint = tornadoAbility:GetCastPoint()
	local radius = tornadoAbility:GetSpecialValueInt("area_of_effect")
	local travelSpeed = tornadoAbility:GetSpecialValueInt("travel_speed")
	if isTeamFight then
		local aoeLocation = bot:FindAoELocation(true, true, bot:GetLocation(), castRange, radius, castPoint, 0)
		local enemiesInRadius = Fu.GetEnemiesNearLoc(aoeLocation.targetloc, radius)
		local alliesInRadius = Fu.GetAlliesNearLoc(aoeLocation.targetloc, radius)
		local enemyCenter = Fu.GetCenterOfUnits(enemiesInRadius)
		local distanceToCenter = GetUnitToLocationDistance(bot, enemyCenter)
		if
			#enemiesInRadius >= 2
			and #alliesInRadius < #enemiesInRadius
			and not Fu.IsLocationInChrono(enemyCenter)
			and not Fu.IsLocationInBlackHole(enemyCenter)
			and distanceToCenter <= castRange
			and distanceToCenter > bot:GetAttackRange()
		then
			return BOT_ACTION_DESIRE_HIGH, enemyCenter
		end
	end
	if
		botTarget ~= nil
		and botTarget:IsChanneling()
		and Fu.IsValidHero(botTarget)
		and Fu.CanCastOnNonMagicImmune(botTarget)
		and Fu.IsInRange(bot, botTarget, castRange)
	then
		return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
	end
	if isEngaging then
		if
			Fu.IsValidHero(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and (not isLaningPhase or isLaningPhase and Fu.GetManaAfter(tornadoAbility:GetManaCost()) > 0.5 or Fu.GetHP(
				botTarget
			) < 0.5)
			and not Fu.IsInRange(bot, botTarget, bot:GetAttackRange())
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not Fu.IsDisabled(botTarget)
			and not botTarget:HasModifier("modifier_brewmaster_storm_cyclone")
			and not botTarget:HasModifier("modifier_enigma_black_hole_pull")
			and not botTarget:HasModifier("modifier_eul_cyclone")
			and not botTarget:HasModifier("modifier_faceless_void_chronosphere_freeze")
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
			and not botTarget:HasModifier("modifier_invoker_chaos_meteor_burn")
			and not botTarget:HasModifier("modifier_invoker_deafening_blast_disarm")
		then
			if Fu.IsRunning(botTarget) then
				local delay = GetUnitToUnitDistance(bot, botTarget) / travelSpeed + castPoint
				return BOT_ACTION_DESIRE_HIGH, Fu.GetCorrectLoc(botTarget, delay)
			else
				return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
			end
		end
	end
	if Fu.IsLaning(bot) and bot:GetMana() - tornadoAbility:GetManaCost() >= laningManaReserve then
		local enemyHero
		if nearbyEnemies ~= nil and #nearbyEnemies <= 2 and nearbyEnemies[1] ~= nil then
			enemyHero = nearbyEnemies[1]
		else
			return BOT_ACTION_DESIRE_NONE, nil
		end
		if enemyHero ~= nil and mpRatio > 0.7 then
			local delay = GetUnitToUnitDistance(bot, enemyHero) / travelSpeed + castPoint
			return BOT_ACTION_DESIRE_HIGH, Fu.GetCorrectLoc(enemyHero, delay), "对线消耗"
		end
	end
	if isRetreating then
		local enemyHero
		if nearbyEnemies ~= nil and #nearbyEnemies >= 1 and nearbyEnemies[1] ~= nil then
			enemyHero = nearbyEnemies[1]
		else
			return BOT_ACTION_DESIRE_NONE, 0
		end
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and Fu.IsChasingTarget(enemyHero, bot)
			and Fu.IsInRange(bot, enemyHero, castRange - 200)
			and (not isLaningPhase or isLaningPhase and hpRatio < 0.7)
		then
			if bot:WasRecentlyDamagedByAnyHero(3) then
				local enemiesNearTarget = Fu.GetEnemiesNearLoc(enemyHero:GetLocation(), radius)
				if enemiesNearTarget ~= nil and #enemiesNearTarget >= 1 then
					return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(enemiesNearTarget)
				else
					local delay = GetUnitToUnitDistance(bot, enemyHero) / travelSpeed + castPoint
					return BOT_ACTION_DESIRE_HIGH, Fu.GetCorrectLoc(enemyHero, delay)
				end
			end
		end
	end
	if Fu.IsDefending(bot) then
		local aoeLocation = bot:FindAoELocation(true, true, bot:GetLocation(), castRange, radius, castPoint, 0)
		local enemiesInRadius = Fu.GetEnemiesNearLoc(aoeLocation.targetloc, radius)
		if
			enemiesInRadius ~= nil
			and #enemiesInRadius >= 1
			and not Fu.IsLocationInChrono(aoeLocation.targetloc)
			and not Fu.IsLocationInBlackHole(aoeLocation.targetloc)
		then
			return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.ConsiderEMP()
	if not X.CanAbilityPossiblyBeCasted(empAbility) then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	empDelay = empAbility:GetSpecialValueFloat("delay")
	local castRange = empAbility:GetCastRange()
	local castPoint = empAbility:GetCastPoint()
	local radius = empAbility:GetSpecialValueInt("area_of_effect")
	local delay = empDelay + castPoint
	if Fu.IsInTeamFight(bot, 1300) then
		local aoeLocation = bot:FindAoELocation(true, true, bot:GetLocation(), castRange, radius, delay, 0)
		if aoeLocation.count >= 2 and GetUnitToLocationDistance(bot, aoeLocation.targetloc) <= castRange then
			return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
		end
	end
	if isEngaging then
		if
			Fu.IsValidHero(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and (not isLaningPhase or isLaningPhase and Fu.GetManaAfter(empAbility:GetManaCost()) > 0.5 or Fu.GetHP(
				botTarget
			) < 0.5)
			and Fu.IsInRange(bot, botTarget, castRange)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not botTarget:HasModifier("modifier_brewmaster_storm_cyclone")
			and not botTarget:HasModifier("modifier_eul_cyclone")
		then
			local aoeLocation = bot:FindAoELocation(true, true, bot:GetLocation(), castRange, radius, delay, 0)
			if aoeLocation.count >= 1 and GetUnitToLocationDistance(bot, aoeLocation.targetloc) <= castRange then
				return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
			end
		end
	end
	if
		Fu.IsValidHero(botTarget)
		and Fu.CanCastOnNonMagicImmune(botTarget)
		and Fu.IsInRange(bot, botTarget, castRange)
		and (not isLaningPhase or isLaningPhase and Fu.GetManaAfter(empAbility:GetManaCost()) > 0.5 or Fu.GetHP(
			botTarget
		) < 0.5)
		and botTarget:HasModifier(modifierTornado)
	then
		return BOT_ACTION_DESIRE_HIGH, Fu.GetCorrectLoc(botTarget, delay)
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.ConsiderAlacrity()
	if not X.CanAbilityPossiblyBeCasted(alacrityAbility) then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castRange = Fu.GetProperCastRange(false, bot, alacrityAbility:GetCastRange())
	local bestAlly = bot
	local bestAttackDamage = 0
	local alliesInRange = Fu.GetNearbyHeroes(bot, castRange, false)
	for _, allyHero in pairs(alliesInRange) do
		if
			Fu.IsValidHero(allyHero)
			and Fu.IsAttacking(allyHero)
			and not allyHero:IsIllusion()
			and not Fu.IsDisabled(allyHero)
			and not Fu.IsWithoutTarget(allyHero)
			and not allyHero:HasModifier("modifier_invoker_alacrity")
			and allyHero:GetAttackDamage() > bestAttackDamage
		then
			bestAlly = allyHero
			bestAttackDamage = allyHero:GetAttackDamage()
		end
	end
	if isEngaging then
		if
			Fu.IsValidTarget(botTarget)
			and isAttacking
			and Fu.CanBeAttacked(botTarget)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and (not isLaningPhase or isLaningPhase and Fu.GetManaAfter(alacrityAbility:GetManaCost()) > 0.5 or Fu.GetHP(
				botTarget
			) < 0.5)
			and not botTarget:HasModifier("modifier_abaddon_borrowed_time")
			and not botTarget:HasModifier("modifier_brewmaster_storm_cyclone")
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			if
				Fu.IsInRange(bestAlly, botTarget, castRange)
				and (
					nearbyEnemies ~= nil
						and #nearbyEnemies >= 2
						and not X.CanAbilityPossiblyBeCasted(chaosMeteorAbility)
					or nearbyEnemies ~= nil and #nearbyEnemies == 1
				)
			then
				return BOT_ACTION_DESIRE_HIGH, bestAlly
			end
		end
	end
	if Fu.IsPushing(bot) then
		local nearbyLaneCreeps = bot:GetNearbyLaneCreeps(700, true)
		if nearbyLaneCreeps ~= nil and #nearbyLaneCreeps >= 2 then
			return BOT_ACTION_DESIRE_HIGH, bot
		end
		local enemyTowers = bot:GetNearbyTowers(700, true)
		if enemyTowers ~= nil and #enemyTowers >= 1 and bestAlly ~= nil then
			local allyAttackTarget = bestAlly:GetAttackTarget()
			if
				Fu.IsValidBuilding(allyAttackTarget)
				and Fu.IsAttacking(bestAlly)
				and not bestAlly:HasModifier("modifier_invoker_alacrity")
			then
				return BOT_ACTION_DESIRE_HIGH, bestAlly
			end
		end
	end
	if Fu.IsLaning(bot) and bot:GetMana() - alacrityAbility:GetManaCost() >= laningManaReserve then
		local nearbyLaneCreeps = bot:GetNearbyLaneCreeps(700, true)
		if nearbyLaneCreeps ~= nil and #nearbyLaneCreeps >= 2 and isAttacking then
			return BOT_ACTION_DESIRE_HIGH, bot
		end
		local enemyHero
		if nearbyEnemies ~= nil and #nearbyEnemies <= 2 and nearbyEnemies[1] ~= nil then
			enemyHero = nearbyEnemies[1]
		else
			return BOT_ACTION_DESIRE_NONE, nil
		end
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and isAttacking
			and botTarget == enemyHero
		then
			return BOT_ACTION_DESIRE_HIGH, bot, "对线消耗:" .. Fu.Chat.GetNormName(enemyHero)
		end
	end
	if Fu.IsFarming(bot) then
		if isAttacking then
			return BOT_ACTION_DESIRE_HIGH, bot
		end
	end
	if Fu.IsDoingRoshan(bot) and bestAlly ~= nil then
		if Fu.IsRoshan(botTarget) and Fu.IsInRange(bestAlly, botTarget, 1000) and isAttacking then
			return BOT_ACTION_DESIRE_HIGH, bestAlly
		end
	end
	if Fu.IsDoingTormentor(bot) and bestAlly ~= nil then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(bestAlly, botTarget, 1000) and isAttacking then
			return BOT_ACTION_DESIRE_HIGH, bestAlly
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function X.ConsiderCmToTarget(target, delay, travelDistance, radius)
	if
		(
			Fu.IsValidHero(target)
			or Fu.IsValidTarget(target)
				and (Fu.Unit.IsUnitWithName(target, "roshan") or Fu.Unit.IsUnitWithName(target, "boss"))
		)
		and Fu.CanCastOnNonMagicImmune(target)
		and not Fu.IsSuspiciousIllusion(target)
		and (not isLaningPhase or isLaningPhase and Fu.GetManaAfter(chaosMeteorAbility:GetManaCost()) > 0.5 or Fu.GetHP(
			target
		) < 0.5)
		and not target:HasModifier("modifier_abaddon_borrowed_time")
		-- Steady movement is an alternative to the HP window only. It used to be OR'ed with the
		-- whole condition, so any enemy walking straight got a Meteor, magic immune, an
		-- illusion or with laning mana under half included.
		and (Fu.GetHP(target) <= 0.9 and Fu.GetHP(target) > 0.15 or target:GetMovementDirectionStability() >= 0.75)
	then
		if target:HasModifier(modifierTornado) then
			if DotaTime() >= lastCastTime["Tornado"] + tornadoLiftDuration - delay then
				return BOT_ACTION_DESIRE_HIGH, X.AdjustCMLocation(target:GetLocation(), target)
			end
		elseif X.CheckTempModifiers(airborneModifiers, target, delay) > 0 then
			return BOT_ACTION_DESIRE_HIGH, X.AdjustCMLocation(target:GetLocation(), target)
		end
		if
			target:IsStunned()
			or target:IsRooted()
			or target:IsHexed()
			or target:IsChanneling()
			or X.IsUnderLongDurationStun(target)
		then
			if Fu.IsRunning(target) then
				return BOT_ACTION_DESIRE_HIGH, Fu.GetCorrectLoc(target, delay)
			end
		end
		local aoeLocation = bot:FindAoELocation(true, true, bot:GetLocation(), travelDistance, radius, delay, 0)
		if aoeLocation.count >= 2 then
			return BOT_ACTION_DESIRE_HIGH, X.AdjustCMLocation(aoeLocation.targetloc, target)
		end
		return BOT_ACTION_DESIRE_HIGH, X.AdjustCMLocation(Fu.GetCorrectLoc(target, delay), target)
	end
	return 0, nil
end
function X.ConsiderChaosMeteor()
	if not X.CanAbilityPossiblyBeCasted(chaosMeteorAbility) then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local castRange = Fu.GetProperCastRange(false, bot, chaosMeteorAbility:GetCastRange())
	local landTime = chaosMeteorAbility:GetSpecialValueFloat("land_time")
	local radius = chaosMeteorAbility:GetSpecialValueInt("area_of_effect")
	local travelDistance = chaosMeteorAbility:GetSpecialValueInt("travel_distance")
	local delay = landTime
	if DotaTime() - lastCastTime["Tornado"] <= tornadoLiftDuration - landTime then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	if isTeamFight then
		local aoeLocation = Fu.GetAoeEnemyHeroLocation(bot, castRange, radius, 2)
		if
			aoeLocation ~= nil
			and GetUnitToLocationDistance(bot, aoeLocation) <= castRange
			and Fu.GetEnemiesAroundLoc(aoeLocation, radius) >= 2
		then
			return BOT_ACTION_DESIRE_HIGH, X.AdjustCMLocation(aoeLocation, nil)
		end
	end
	if not isRetreating then
		for _, enemyHero in pairs(GetUnitList(UNIT_LIST_ENEMY_HEROES)) do
			if Fu.IsInRange(bot, enemyHero, castRange) then
				local desire, target = X.ConsiderCmToTarget(enemyHero, delay, travelDistance, radius)
				if desire > 0 then
					return desire, target
				end
			end
		end
	end
	if isEngaging and Fu.IsValidTarget(botTarget) and isAttacking and Fu.IsInRange(bot, botTarget, castRange) then
		local desire, target = X.ConsiderCmToTarget(botTarget, delay, travelDistance, radius)
		if desire > 0 then
			return desire, target
		end
	end
	if Fu.IsLaning(bot) then
		local nearbyLaneCreeps = bot:GetNearbyLaneCreeps(1400, true)
		if nearbyLaneCreeps ~= nil and #nearbyLaneCreeps >= 5 then
			local creepAoeLocation = bot:FindAoELocation(true, false, bot:GetLocation(), castRange, radius, 0, 500)
			if creepAoeLocation.count >= 3 then
				return BOT_ACTION_DESIRE_HIGH, X.AdjustCMLocation(creepAoeLocation.targetloc, nil)
			end
		end
		local enemyHero
		if nearbyEnemies ~= nil and #nearbyEnemies <= 2 and nearbyEnemies[1] ~= nil then
			enemyHero = nearbyEnemies[1]
		else
			return BOT_ACTION_DESIRE_NONE, nil
		end
		if
			Fu.IsValidHero(enemyHero)
			and isAttacking
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and Fu.IsInRange(bot, enemyHero, castRange)
			and not Fu.IsSuspiciousIllusion(enemyHero)
			and Fu.GetHP(enemyHero) <= 0.8
		then
			if Fu.IsRunning(enemyHero) then
				return BOT_ACTION_DESIRE_HIGH, X.AdjustCMLocation(Fu.GetCorrectLoc(enemyHero, delay), enemyHero)
			else
				return BOT_ACTION_DESIRE_HIGH, X.AdjustCMLocation(enemyHero:GetLocation(), enemyHero)
			end
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if Fu.IsRoshan(botTarget) and Fu.IsInRange(bot, botTarget, castRange) and isAttacking then
			return BOT_ACTION_DESIRE_HIGH, X.AdjustCMLocation(botTarget:GetLocation(), botTarget)
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, 700) and isAttacking then
			return BOT_ACTION_DESIRE_HIGH, X.AdjustCMLocation(botTarget:GetLocation(), botTarget)
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.AdjustCMLocation(location, target)
	if target == nil or Fu.IsChasingTarget(bot, target) then
		return location
	end
	local offsetDistance = 250
	local distanceToTarget = GetUnitToUnitDistance(bot, target)
	if
		target:IsFacingLocation(bot:GetLocation(), 20)
		and Fu.IsRunning(target)
		and distanceToTarget < offsetDistance
	then
		return Utils.GetOffsetLocationTowardsTargetLocation(
			target:GetLocation(),
			bot:GetLocation(),
			distanceToTarget + 120
		)
	end
	if distanceToTarget < offsetDistance + 50 then
		return location
	end
	return Utils.GetOffsetLocationTowardsTargetLocation(location, bot:GetLocation(), offsetDistance)
end
function X.CheckTempModifiers(modifierList, target, delay)
	local modifierCount = 0
	if target == nil then
		return BOT_ACTION_DESIRE_NONE, modifierCount
	end
	for _, modifierName in pairs(modifierList) do
		if target:HasModifier(modifierName) then
			modifierCount = modifierCount + 1
			local remainingTime = Fu.GetModifierTime(target, modifierName)
			log(
				"%s - Target has modifier %s, the remaining time: %s seconds, delay: %s",
				DotaTime(),
				modifierName,
				remainingTime,
				delay
			)
			if remainingTime > 0 and remainingTime <= delay then
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	if modifierCount == 0 then
		return BOT_ACTION_DESIRE_HIGH
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderCataclysm()
	-- Cataclysm (Sun Strike cast on himself) is an Aghanim's Scepter upgrade, and he no longer
	-- buys Scepter. Without it this rule, first in his spell order, would spend Sun Strike on his
	-- own spot (or an invalid order).
	if not bot:HasScepter() then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	if not X.CanAbilityPossiblyBeCasted(cataclysmName) then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local desire, _ = X.GoodTimeToUseCataclysmGlobally()
	if desire > 0 then
		return BOT_ACTION_DESIRE_HIGH, 0
	end
	local castPoint = sunstrikeAbility:GetCastPoint()
	local delay = sunstrikeAbility:GetSpecialValueFloat("delay") + castPoint
	if isEngaging then
		if
			Fu.IsValidHero(botTarget)
			and Fu.GetHP(botTarget) <= 0.85
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not botTarget:HasModifier("modifier_abaddon_borrowed_time")
			and not botTarget:HasModifier("modifier_brewmaster_storm_cyclone")
			and not botTarget:HasModifier("modifier_eul_cyclone")
			and not botTarget:HasModifier(modifierTornado)
			and not botTarget:HasModifier("modifier_templar_assassin_refraction_absorb")
			and not botTarget:HasModifier("modifier_item_aeon_disk_buff")
			and (X.IsUnderLongDurationStun(botTarget) or botTarget:IsStunned() or botTarget:IsRooted())
		then
			return BOT_ACTION_DESIRE_HIGH, 0
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.GoodTimeToUseCataclysmGlobally()
	local damage = sunstrikeAbility:GetSpecialValueInt("damage")
	local castPoint = sunstrikeAbility:GetCastPoint()
	local delay = sunstrikeAbility:GetSpecialValueFloat("delay") + castPoint
	for _, enemyHero in pairs(GetUnitList(UNIT_LIST_ENEMY_HEROES)) do
		if
			Fu.IsValidHero(enemyHero)
			and damage * 2 > enemyHero:GetHealth()
			and not Fu.IsSuspiciousIllusion(enemyHero)
			and (X.IsUnderLongDurationStun(enemyHero) or enemyHero:IsStunned() or enemyHero:IsRooted())
		then
			return BOT_ACTION_DESIRE_HIGH, 0
		end
		if
			Fu.IsValidHero(enemyHero)
			and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
			and not enemyHero:HasModifier("modifier_brewmaster_storm_cyclone")
			and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
			and not enemyHero:HasModifier("modifier_eul_cyclone")
			and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
			and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
			and not enemyHero:HasModifier("modifier_templar_assassin_refraction_absorb")
			and not enemyHero:HasModifier("modifier_item_aeon_disk_buff")
			and not Fu.IsSuspiciousIllusion(enemyHero)
			and (X.IsUnderLongDurationStun(enemyHero) or enemyHero:IsStunned() or enemyHero:IsRooted())
		then
			return BOT_ACTION_DESIRE_HIGH, 0
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.IsUnderLongDurationStun(enemyHero)
	return enemyHero:HasModifier("modifier_bane_fiends_grip")
		or enemyHero:HasModifier("modifier_legion_commander_duel")
		or enemyHero:HasModifier("modifier_enigma_black_hole_pull")
		or enemyHero:HasModifier("modifier_faceless_void_chronosphere_freeze")
		or enemyHero:HasModifier("modifier_magnataur_reverse_polarity")
		or enemyHero:HasModifier("modifier_tidehunter_ravage")
end
function X.ConsiderSunstrike()
	if not X.CanAbilityPossiblyBeCasted(sunstrikeAbility) then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	if DotaTime() - (lastCastTime["Tornado"] or 0) <= (tornadoLiftDuration or 0) then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local delay = sunstrikeAbility:GetSpecialValueFloat("delay")
	local damage = sunstrikeAbility:GetSpecialValueInt("damage")
	local attackRange = bot:GetAttackRange()
	local enemyHeroes = GetUnitList(UNIT_LIST_ENEMY_HEROES)
	for _, enemyHero in pairs(enemyHeroes) do
		if
			Fu.IsValidHero(enemyHero)
			and not Fu.IsSuspiciousIllusion(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
			and not enemyHero:HasModifier("modifier_brewmaster_storm_cyclone")
			and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
			and not enemyHero:HasModifier("modifier_eul_cyclone")
			and not enemyHero:HasModifier(modifierTornado)
			and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
			and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
			and not enemyHero:HasModifier("modifier_templar_assassin_refraction_absorb")
			and not enemyHero:HasModifier("modifier_item_aeon_disk_buff")
		then
			local directionStability = enemyHero:GetMovementDirectionStability()
			local predictionDelay = RemapValClamped(directionStability, 0.0, 1.0, 0.0, delay)
			local unusedDelay = predictionDelay
			if enemyHero:HasModifier("modifier_teleporting") then
				local remainingTime = Fu.GetModifierTime(enemyHero, "modifier_teleporting")
				if remainingTime ~= nil and remainingTime > delay + 0.05 then
					if damage > enemyHero:GetHealth() then
						return BOT_ACTION_DESIRE_HIGH, enemyHero:GetLocation()
					end
				else
					if damage > enemyHero:GetHealth() then
						return BOT_ACTION_DESIRE_HIGH, Utils.GetEnemyFountainTpPoint()
					end
				end
			end
			if damage > enemyHero:GetHealth() and GetUnitToUnitDistance(bot, enemyHero) > attackRange + 50 then
				return BOT_ACTION_DESIRE_HIGH, Fu.GetCorrectLoc(enemyHero, delay)
			end
			if
				#Fu.GetHeroesNearLocation(false, enemyHero:GetLocation(), 600) >= 1
				and GetUnitToUnitDistance(bot, enemyHero) > attackRange + 50
				and Fu.GetHP(enemyHero) < 0.4
			then
				return BOT_ACTION_DESIRE_HIGH, Fu.GetCorrectLoc(enemyHero, delay)
			end
		end
	end
	if Fu.IsDoingRoshan(bot) and Fu.IsRoshan(botTarget) and isAttacking then
		return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
	end
	if Fu.IsDoingTormentor(bot) and Fu.IsTormentor(botTarget) and isAttacking then
		return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.ConsiderForgeSpirit()
	if not X.CanAbilityPossiblyBeCasted(forgeSpiritAbility) then
		return BOT_ACTION_DESIRE_NONE
	end
	if isEngaging then
		if Fu.IsValidTarget(botTarget) and Fu.IsInRange(bot, botTarget, 1200) then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if
		(Fu.IsLaning(bot) or Fu.IsFarming(bot))
		and isAttacking
		and bot:GetMana() - forgeSpiritAbility:GetManaCost() >= laningManaReserve
	then
		return BOT_ACTION_DESIRE_HIGH
	end
	if Fu.IsPushing(bot) or Fu.IsDefending(bot) then
		if isAttacking then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if Fu.IsRoshan(botTarget) and isAttacking then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and isAttacking then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderIceWall()
	if not X.CanAbilityPossiblyBeCasted(iceWallAbility) then
		return BOT_ACTION_DESIRE_NONE
	end
	local wallPlaceDistance = iceWallAbility:GetSpecialValueInt("wall_place_distance")
	local engageRange = 300
	local castRange = 300
	local radius = 1000
	if isEngaging then
		if
			Fu.IsValidHero(botTarget)
			and Fu.IsInRange(bot, botTarget, engageRange)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsRunning(botTarget)
			and (not isLaningPhase or isLaningPhase and mpRatio > 0.7 or Fu.GetHP(botTarget) < 0.3)
			and bot:IsFacingLocation(botTarget:GetLocation(), 30)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not Fu.IsDisabled(botTarget)
		then
			return BOT_ACTION_DESIRE_HIGH
		end
		if
			nearbyEnemies ~= nil
			and #nearbyEnemies >= 1
			and Fu.IsValidHero(nearbyEnemies[1])
			and X.CheckTempModifiers(airborneModifiers, nearbyEnemies[1], 1) > 0
			and Fu.IsInRange(bot, nearbyEnemies[1], engageRange)
			and (not isLaningPhase or isLaningPhase and mpRatio > 0.7 or Fu.GetHP(nearbyEnemies[1]) < 0.3)
			and Fu.CanCastOnNonMagicImmune(nearbyEnemies[1])
			and bot:IsFacingLocation(nearbyEnemies[1]:GetLocation(), 30)
		then
			return BOT_ACTION_DESIRE_HIGH, nearbyEnemies[1]:GetLocation()
		end
	end
	if isTeamFight then
		local aoeLocation = Fu.GetAoeEnemyHeroLocation(bot, castRange, radius, 2)
		if aoeLocation ~= nil then
			return BOT_ACTION_DESIRE_HIGH, aoeLocation
		end
		if nearbyEnemies ~= nil then
			for _, enemyHero in pairs(nearbyEnemies) do
				if
					Fu.IsValidHero(enemyHero)
					and Fu.CanCastOnNonMagicImmune(enemyHero)
					and Fu.IsInRange(bot, enemyHero, engageRange)
				then
					return BOT_ACTION_DESIRE_HIGH, Fu.GetCorrectLoc(enemyHero, 0.5)
				end
				if
					X.CheckTempModifiers(airborneModifiers, enemyHero, 1) > 0
					and Fu.IsInRange(bot, enemyHero, engageRange)
					and Fu.CanCastOnNonMagicImmune(enemyHero)
					and bot:IsFacingLocation(enemyHero:GetLocation(), 30)
				then
					return BOT_ACTION_DESIRE_HIGH, enemyHero:GetLocation()
				end
			end
		end
	end
	if isRetreating then
		if
			nearbyEnemies ~= nil
			and #nearbyEnemies >= 1
			and Fu.IsValidHero(nearbyEnemies[1])
			and Fu.IsInRange(bot, nearbyEnemies[1], engageRange)
			and Fu.CanCastOnNonMagicImmune(nearbyEnemies[1])
			and Fu.IsChasingTarget(nearbyEnemies[1], bot)
			and bot:WasRecentlyDamagedByAnyHero(2)
			and not Fu.IsSuspiciousIllusion(nearbyEnemies[1])
			and not Fu.IsDisabled(nearbyEnemies[1])
			and (hpRatio < 0.6 or Fu.GetTotalEstimatedDamageToTarget(nearbyEnemies, bot) > bot:GetHealth())
			and not isLaningPhase
			and bot:IsFacingLocation(Fu.GetTeamFountain(), 30)
		then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderDeafeningBlast()
	if not X.CanAbilityPossiblyBeCasted(deafeningBlastAbility) then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local castRange = Fu.GetProperCastRange(false, bot, deafeningBlastAbility:GetCastRange())
	local castPoint = deafeningBlastAbility:GetCastPoint()
	local damage = deafeningBlastAbility:GetSpecialValueInt("damage")
	local radius = deafeningBlastAbility:GetSpecialValueInt("radius_end")
	local travelSpeed = deafeningBlastAbility:GetSpecialValueInt("travel_speed")
	if travelSpeed == nil then
		travelSpeed = 1000
	end
	local aoeLocation = bot:FindAoELocation(true, true, bot:GetLocation(), castRange, radius, castPoint, 0)
	if Fu.IsInTeamFight(bot, 1500) then
		local enemiesInRadius = Fu.GetEnemiesNearLoc(aoeLocation.targetloc, radius)
		local enemyCenter = Fu.GetCenterOfUnits(enemiesInRadius)
		if
			enemiesInRadius ~= nil
			and #enemiesInRadius >= 2
			and not Fu.IsLocationInChrono(enemyCenter)
			and GetUnitToLocationDistance(bot, enemyCenter) <= castRange
		then
			return BOT_ACTION_DESIRE_HIGH, enemyCenter
		end
	end
	if isEngaging then
		if
			Fu.IsValidHero(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, castRange)
			and (not isLaningPhase or isLaningPhase and Fu.GetManaAfter(deafeningBlastAbility:GetManaCost()) > 0.5 or Fu.GetHP(
				botTarget
			) < 0.5)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not botTarget:HasModifier("modifier_brewmaster_storm_cyclone")
			and not botTarget:HasModifier("modifier_eul_cyclone")
			and (
				botTarget:HasModifier("modifier_invoker_chaos_meteor_burn")
				or bot:IsFacingLocation(botTarget:GetLocation(), 30) and #nearbyAllies >= #nearbyEnemies
			)
		then
			local delay = GetUnitToUnitDistance(bot, botTarget) / travelSpeed + castPoint
			if botTarget:HasModifier(modifierTornado) then
				if DotaTime() >= lastCastTime["Tornado"] + tornadoLiftDuration - delay then
					return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
				end
			elseif X.CheckTempModifiers(airborneModifiers, botTarget, delay) > 0 then
				return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
			end
			if Fu.IsRunning(botTarget) then
				return BOT_ACTION_DESIRE_HIGH, Fu.GetCorrectLoc(botTarget, delay)
			end
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	if
		isRetreating
		and Fu.IsValidHero(nearbyEnemies[1])
		and Fu.IsChasingTarget(nearbyEnemies[1], bot)
		and bot:WasRecentlyDamagedByAnyHero(2)
		and Fu.IsInRange(bot, nearbyEnemies[1], castRange - 300)
	then
		return BOT_ACTION_DESIRE_HIGH, nearbyEnemies[1]:GetLocation()
	end
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and Fu.Utils.IsWithoutSpellShield(enemyHero)
			and Fu.CanKillTarget(enemyHero, damage, DAMAGE_TYPE_MAGICAL)
		then
			local delay = GetUnitToUnitDistance(bot, enemyHero) / travelSpeed + castPoint
			return BOT_ACTION_DESIRE_HIGH, Fu.GetCorrectLoc(enemyHero, delay)
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function ConsiderFirstSpell()
	if bot:GetLevel() == 1 then
		if quasAbility:IsTrained() and not X.IsAbilityAvailableOnSlots(coldSnapAbility) then
			X.InvokeSpell(quasAbility, quasAbility, quasAbility)
		elseif wexAbility:IsTrained() and not X.IsAbilityAvailableOnSlots(empAbility) then
			X.InvokeSpell(wexAbility, wexAbility, wexAbility)
		elseif exortAbility:IsTrained() and not X.IsAbilityAvailableOnSlots(sunstrikeAbility) then
			X.InvokeSpell(exortAbility, exortAbility, exortAbility)
		end
		return
	end
end
function X.InvokeActualSpell(ability)
	local abilityName
	if type(ability) == "string" and ability == "Cataclysm" then
		abilityName = ability
	else
		abilityName = ability:GetName()
	end
	log("%s - Invoker going to invoke %s", DotaTime(), abilityName)
	if abilityName == cataclysmName or ability == sunstrikeAbility then
		X.InvokeSpell(exortAbility, exortAbility, exortAbility)
	elseif ability == deafeningBlastAbility then
		X.InvokeSpell(quasAbility, wexAbility, exortAbility)
	elseif ability == chaosMeteorAbility then
		X.InvokeSpell(exortAbility, exortAbility, wexAbility)
	elseif ability == forgeSpiritAbility then
		X.InvokeSpell(exortAbility, exortAbility, quasAbility)
	elseif ability == alacrityAbility then
		X.InvokeSpell(wexAbility, wexAbility, exortAbility)
	elseif ability == empAbility then
		X.InvokeSpell(wexAbility, wexAbility, wexAbility)
	elseif ability == iceWallAbility then
		X.InvokeSpell(quasAbility, quasAbility, exortAbility)
	elseif ability == ghostWalkAbility then
		X.InvokeSpell(quasAbility, quasAbility, wexAbility)
	elseif ability == tornadoAbility then
		X.InvokeSpell(wexAbility, wexAbility, quasAbility)
	elseif ability == coldSnapAbility then
		X.InvokeSpell(quasAbility, quasAbility, quasAbility)
	else
		log("[ERROR] Tried to invoke unsupported ability: %s", abilityName)
		log("Stack Trace:", debug.traceback())
	end
	log("%s - Invoker tried to invoke %s", DotaTime(), abilityName)
end
function X.InvokeSpell(element1, element2, element3)
	bot:ActionPush_UseAbility(invokeAbility)
	bot:ActionPush_UseAbility(element1)
	bot:ActionPush_UseAbility(element2)
	bot:ActionPush_UseAbility(element3)
end
function X.IsAbilityReadyForInvoke(ability)
	return not X.IsAbilityAvailableOnSlots(ability)
		and X.CanAbilityPossiblyBeCasted(ability)
		and invokeAbility:IsFullyCastable()
end
function X.IsAbilityReadyForCast(ability)
	return X.IsAbilityAvailableOnSlots(ability) and ability:IsFullyCastable()
end
function X.CanAbilityPossiblyBeCasted(ability)
	local castAbility
	if type(ability) == "string" and ability == "Cataclysm" then
		castAbility = sunstrikeAbility
	else
		castAbility = ability
	end
	if not X.HaveElementsTrainedToInvokeAbility(ability) then
		return false
	end
	return castAbility:IsFullyCastable()
end
function X.HaveElementsTrainedToInvokeAbility(ability)
	if type(ability) == "string" and ability == cataclysmName then
		return bot:HasScepter() and X.HaveElementsTrainedToInvokeAbility(sunstrikeAbility)
	elseif ability == deafeningBlastAbility then
		return quasAbility:IsTrained() and wexAbility:IsTrained() and exortAbility:IsTrained()
	elseif ability == chaosMeteorAbility then
		return wexAbility:IsTrained() and exortAbility:IsTrained()
	elseif ability == forgeSpiritAbility then
		return quasAbility:IsTrained() and exortAbility:IsTrained()
	elseif ability == sunstrikeAbility then
		return exortAbility:IsTrained()
	elseif ability == alacrityAbility then
		return wexAbility:IsTrained() and exortAbility:IsTrained()
	elseif ability == empAbility then
		return wexAbility:IsTrained()
	elseif ability == iceWallAbility then
		return quasAbility:IsTrained() and exortAbility:IsTrained()
	elseif ability == ghostWalkAbility then
		return quasAbility:IsTrained() and wexAbility:IsTrained()
	elseif ability == tornadoAbility then
		return quasAbility:IsTrained() and wexAbility:IsTrained()
	elseif ability == coldSnapAbility then
		return quasAbility:IsTrained()
	else
		log("[ERROR] Checks invokability on an unsupported ability")
		log("Stack Trace:", debug.traceback())
	end
	return nil
end
function X.IsAbilityAvailableOnSlots(ability)
	return not ability:IsHidden()
end
function CheckAbilityUsage()
	local spellSlots = { bot:GetAbilityInSlot(3), bot:GetAbilityInSlot(4) }
	for _, ability in pairs(spellSlots) do
		local cooldownRatio = ability:GetCooldownTimeRemaining() / ability:GetCooldown()
		local cooldownThreshold = 0.9
		if
			X.IsAbilityAvailableOnSlots(ability)
			and not ability:IsCooldownReady()
			and cooldownRatio >= cooldownThreshold
		then
			local abilityName = spellKeyByAbilityName[ability:GetName()]
			local timeSinceCast = DotaTime() - lastCastTime[abilityName]
			if
				DotaTime() - lastCastTime[abilityName] <= 1
				or timeSinceCast >= ability:GetCooldown() * 0.5
				or lastCastTime[abilityName] == -100
			then
				local expectedMana = lastMana - ability:GetManaCost()
				local manaTolerance = 20
				if bot:GetMana() <= expectedMana + manaTolerance and bot:GetMana() >= expectedMana - manaTolerance then
					if ability == sunstrikeAbility and ability:GetCooldownTimeRemaining() > 50 then
						abilityName = "Cataclysm"
					end
					log("%s - Invoker just used ability %s, reset the cooldown tracking time.", DotaTime(), abilityName)
					lastCastTime[abilityName] = DotaTime()
				end
			end
		end
	end
	lastMana = bot:GetMana()
end
return X
