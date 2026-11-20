-- Nyx Assassin: skill build, item build, and ability use for this hero.
-- Accidental globals made file-local (#13): every bot shares one Lua state, so these were shared.
local Pos4SellList, Pos5SellList
local X = {}
local bot = GetBot()
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local AbilityContext = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local Minion = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local sTalentList = Fu.Skill.GetTalentList(bot)
local sAbilityList = Fu.Skill.GetAbilityList(bot)
local sRole = Fu.Item.GetRoleItemsBuyList(bot)
local tTalentTreeList = { ["t25"] = { 10, 0 }, ["t20"] = { 10, 0 }, ["t15"] = { 10, 0 }, ["t10"] = { 0, 10 } }
local tAllAbilityBuildList = { { 1, 3, 1, 2, 1, 6, 1, 2, 2, 2, 6, 3, 3, 3, 6 } }
local nAbilityBuildList = Fu.Skill.GetRandomBuild(tAllAbilityBuildList)
local nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList)
local sRoleItemsBuyList = {}
-- Stratz 7.41f, week of 9 Nov 2026: pos 4, 95,516 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_4"] = {
	"item_tango",
	"item_blood_grenade",
	"item_double_branches",
	"item_magic_stick",
	"item_enchanted_mango",
	"item_magic_wand",
	"item_arcane_boots",
	"item_ultimate_scepter",
	"item_soul_booster",
	"item_blink",
	"item_aether_lens",
	"item_ultimate_scepter_2",
	"item_octarine_core",
	"item_wind_waker",
	"item_aghanims_shard",
	"item_moon_shard",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 5, 32,993 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_5"] = {
	"item_tango",
	"item_blood_grenade",
	"item_double_branches",
	"item_magic_stick",
	"item_enchanted_mango",
	"item_magic_wand",
	"item_arcane_boots",
	"item_ultimate_scepter",
	"item_soul_booster",
	"item_aether_lens",
	"item_blink",
	"item_octarine_core",
	"item_ultimate_scepter_2",
	"item_wind_waker",
	"item_aghanims_shard",
	"item_moon_shard",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 3, 14,128 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_3"] = {
	"item_tango",
	"item_double_branches",
	"item_circlet",
	"item_quelling_blade",
	"item_null_talisman",
	"item_magic_wand",
	"item_arcane_boots",
	"item_phylactery",
	"item_aghanims_shard",
	"item_ultimate_scepter",
	"item_octarine_core",
	"item_ultimate_scepter_2",
	"item_soul_booster",
	"item_blink",
	"item_aether_lens",
	"item_moon_shard",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 1 has 852 matches, built from pos 2 (47,859) (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_1"] = {
	"item_tango",
	"item_double_branches",
	"item_faerie_fire",
	"item_quelling_blade",
	"item_circlet",
	"item_magic_wand",
	"item_arcane_boots",
	"item_phylactery",
	"item_aghanims_shard",
	"item_ultimate_scepter",
	"item_cyclone",
	"item_octarine_core",
	"item_soul_booster",
	"item_ultimate_scepter_2",
	"item_wind_waker",
	"item_yasha_and_kaya",
	"item_moon_shard",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 2, 47,859 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_2"] = {
	"item_tango",
	"item_double_branches",
	"item_faerie_fire",
	"item_quelling_blade",
	"item_circlet",
	"item_magic_wand",
	"item_arcane_boots",
	"item_phylactery",
	"item_aghanims_shard",
	"item_ultimate_scepter",
	"item_cyclone",
	"item_octarine_core",
	"item_soul_booster",
	"item_ultimate_scepter_2",
	"item_wind_waker",
	"item_yasha_and_kaya",
	"item_moon_shard",
}
X["sBuyList"] = sRoleItemsBuyList[sRole]
Pos4SellList = { "item_magic_wand" }
Pos5SellList = { "item_magic_wand" }
X["sSellList"] = {}
if sRole == "pos_4" then
	X["sSellList"] = Pos4SellList
else
	X["sSellList"] = Pos5SellList
end
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
local impaleAbility = SafeAbility(bot:GetAbilityByName("nyx_assassin_impale"), "nyx_assassin_impale", "nyx_assassin")
local mindFlareAbility = SafeAbility(bot:GetAbilityByName("nyx_assassin_jolt"), "nyx_assassin_jolt", "nyx_assassin")
local spikedCarapaceAbility =
	SafeAbility(bot:GetAbilityByName("nyx_assassin_spiked_carapace"), "nyx_assassin_spiked_carapace", "nyx_assassin")
local burrowAbility = SafeAbility(bot:GetAbilityByName("nyx_assassin_burrow"), "nyx_assassin_burrow", "nyx_assassin")
local unburrowAbility =
	SafeAbility(bot:GetAbilityByName("nyx_assassin_unburrow"), "nyx_assassin_unburrow", "nyx_assassin")
local vendettaAbility =
	SafeAbility(bot:GetAbilityByName("nyx_assassin_vendetta"), "nyx_assassin_vendetta", "nyx_assassin")
local impaleDesire, impaleLocation
local mindFlareDesire, mindFlareTarget
local spikedCarapaceDesire
local burrowDesire
local unburrowDesire
local vendettaDesire
if bot.canVendettaKill == nil then
	bot.canVendettaKill = false
end
if bot.vendettaTarget == nil then
	bot.vendettaTarget = nil
end
local botTarget
local isGoingOnSomeone
local mpRatio
function X.SkillsComplement()
	if Fu.CanNotUseAbility(bot) then
		return
	end
	local context = AbilityContext.Build(bot)
	isGoingOnSomeone = context.isEngaging
	mpRatio = context.mp
	-- The chase target (outpost-mode hook walks him to it and attacks while Vendetta is up) is
	-- cleared once Vendetta is over, so a later escape Vendetta does not chase an old target.
	if
		bot.canVendettaKill
		and not bot:HasModifier("modifier_nyx_assassin_vendetta")
		and not vendettaAbility:IsInAbilityPhase()
		and DotaTime() - (bot._vendettaAt or -99) > 1
	then
		bot.canVendettaKill = false
		bot.vendettaTarget = nil
	end
	vendettaDesire = X.ConsiderVendetta()
	if vendettaDesire > 0 then
		bot._vendettaAt = DotaTime()
		bot:Action_UseAbility(vendettaAbility)
		return
	end
	spikedCarapaceDesire = X.ConsiderSpikedCarapace()
	if spikedCarapaceDesire > 0 then
		bot:Action_UseAbility(spikedCarapaceAbility)
		return
	end
	impaleDesire, impaleLocation = X.ConsiderImpale()
	if impaleDesire > 0 then
		X.RecordImpale(impaleLocation)
		bot:Action_UseAbilityOnLocation(impaleAbility, impaleLocation)
		return
	end
	-- Impale -> Dagon -> Mind Flare: Dagon on the stunned target, so Mind Flare's echo (15% of
	-- the damage Nyx dealt in the last 15s) includes it.
	local dagon, dagonTarget = X.ConsiderDagonCombo()
	if dagon ~= nil then
		X.AddDealt(dagonTarget, dagon:GetSpecialValueInt("damage"))
		X.LogNyx("dagon-combo", dagonTarget)
		bot:Action_UseAbilityOnEntity(dagon, dagonTarget)
		return
	end
	local blink, blinkLoc = X.ConsiderBlinkCombo()
	if blink ~= nil then
		bot:Action_UseAbilityOnLocation(blink, blinkLoc)
		return
	end
	mindFlareDesire, mindFlareTarget = X.ConsiderMindflare()
	if mindFlareDesire > 0 then
		bot:Action_UseAbilityOnEntity(mindFlareAbility, mindFlareTarget)
		return
	end
	burrowDesire = X.ConsiderBurrow()
	if burrowDesire > 0 then
		bot:Action_UseAbility(burrowAbility)
		return
	end
	unburrowDesire = X.ConsiderUnBurrow()
	if unburrowDesire > 0 then
		bot:Action_UseAbility(unburrowAbility)
		return
	end
end
-- [OHA-NYX] lines, at most once per 3s per kind.
function X.LogNyx(kind, target)
	bot._nyxLogAt = bot._nyxLogAt or {}
	local key = string.match(kind, "^[%w%-]+") or kind
	if DotaTime() < (bot._nyxLogAt[key] or -999) then
		return
	end
	bot._nyxLogAt[key] = DotaTime() + 3
	pcall(
		print,
		string.format(
			"[OHA-NYX] t=%.0f %s target=%s mp=%.2f",
			DotaTime(),
			kind,
			target ~= nil and (string.gsub(target:GetUnitName(), "npc_dota_hero_", "")) or "-",
			Fu.GetMP(bot)
		)
	)
end
-- Damage Nyx dealt to each enemy hero from his spells and Dagon, for Mind Flare's echo
-- (15% of the damage he dealt the target in the last 15s, Valve data). Attacks are not counted.
local dealt = {}
function X.AddDealt(target, damage)
	if target == nil or damage == nil or damage <= 0 or not target:IsHero() then
		return
	end
	local id = target:GetPlayerID()
	dealt[id] = dealt[id] or {}
	table.insert(dealt[id], { t = DotaTime(), dmg = damage })
end
function X.EchoDamage(target)
	local list = dealt[target:GetPlayerID()]
	if list == nil then
		return 0
	end
	local echoPct = mindFlareAbility:GetSpecialValueInt("damage_echo_pct")
	if echoPct == nil or echoPct <= 0 then
		echoPct = 15
	end
	local echoWindow = mindFlareAbility:GetSpecialValueInt("damage_echo_duration")
	if echoWindow == nil or echoWindow <= 0 then
		echoWindow = 15
	end
	local sum, kept = 0, {}
	for _, entry in ipairs(list) do
		if DotaTime() - entry.t <= echoWindow then
			sum = sum + entry.dmg
			kept[#kept + 1] = entry
		end
	end
	dealt[target:GetPlayerID()] = kept
	return sum * echoPct / 100
end
-- Not worth a combo: the target cannot die right now.
function X.SafeToCombo(target)
	return Fu.CanCastOnNonMagicImmune(target)
		and not target:HasModifier("modifier_abaddon_borrowed_time")
		and not target:HasModifier("modifier_dazzle_shallow_grave")
		and not target:HasModifier("modifier_oracle_false_promise_timer")
		and not target:HasModifier("modifier_templar_assassin_refraction_absorb")
		and not target:HasModifier("modifier_skeleton_king_reincarnation_scepter_active")
end
-- Damage of his combo on the target after resists, spending mana in cast order, and whether it kills.
-- Order: [Vendetta hit (pure bonus + attack)], Impale, Dagon, Mind Flare (max-mana part plus the
-- echo of everything before it and of the last 15s). Only spells ready now count.
function X.ComboDamage(target, withVendetta)
	local mana = bot:GetMana()
	local total = 0
	local dealtNow = 0
	local function spend(ability)
		if ability == nil or not ability:IsFullyCastable() then
			return false
		end
		local cost = ability:GetManaCost()
		if cost > mana then
			return false
		end
		mana = mana - cost
		return true
	end
	if withVendetta then
		if not spend(vendettaAbility) then
			return 0, false
		end
		local bonus = vendettaAbility:GetSpecialValueInt("bonus_damage")
		local hit = target:GetActualIncomingDamage(bonus, DAMAGE_TYPE_PURE)
			+ target:GetActualIncomingDamage(bot:GetAttackDamage(), DAMAGE_TYPE_PHYSICAL)
		total = total + hit
		dealtNow = dealtNow + hit
	end
	if spend(impaleAbility) then
		local hit =
			target:GetActualIncomingDamage(impaleAbility:GetSpecialValueInt("impale_damage"), DAMAGE_TYPE_MAGICAL)
		total = total + hit
		dealtNow = dealtNow + hit
	end
	for slot = 0, 5 do
		local item = bot:GetItemInSlot(slot)
		if item ~= nil and string.find(item:GetName(), "item_dagon", 1, true) then
			if spend(item) then
				local hit = target:GetActualIncomingDamage(item:GetSpecialValueInt("damage"), DAMAGE_TYPE_MAGICAL)
				total = total + hit
				dealtNow = dealtNow + hit
			end
			break
		end
	end
	if spend(mindFlareAbility) then
		local maxManaPct = mindFlareAbility:GetSpecialValueInt("max_mana_as_damage_pct")
		local echoPct = mindFlareAbility:GetSpecialValueInt("damage_echo_pct")
		if echoPct == nil or echoPct <= 0 then
			echoPct = 15
		end
		local rawDamage = target:GetMaxMana() * maxManaPct / 100 + X.EchoDamage(target) + dealtNow * echoPct / 100
		total = total + target:GetActualIncomingDamage(rawDamage, DAMAGE_TYPE_MAGICAL)
	end
	local neededDamage = target:GetHealth() + target:GetHealthRegen() * 3
	return total, total >= neededDamage
end
-- Vendetta not ready: Blink in next to a target his combo kills, then Impale. Same limits as the
-- Vendetta combo (up to 2 enemy heroes near the target, him above 50% HP).
function X.ConsiderBlinkCombo()
	if
		vendettaAbility:IsFullyCastable()
		or not impaleAbility:IsFullyCastable()
		or Fu.GetHP(bot) < 0.5
		or Fu.IsRetreating(bot)
	then
		return nil
	end
	if bot:HasModifier("modifier_nyx_assassin_vendetta") then
		return nil
	end
	local blink = nil
	for slot = 0, 5 do
		local item = bot:GetItemInSlot(slot)
		if item ~= nil and string.find(item:GetName(), "blink", 1, true) and item:IsFullyCastable() then
			blink = item
			break
		end
	end
	if blink == nil then
		return nil
	end
	local range = 1200
	if blink:GetName() ~= "item_blink" then
		range = 1400
	end
	for _, enemyHero in pairs(Fu.GetNearbyHeroes(bot, range + 300, true, BOT_MODE_NONE) or {}) do
		if
			Fu.IsValidHero(enemyHero)
			and not Fu.IsSuspiciousIllusion(enemyHero)
			and X.SafeToCombo(enemyHero)
			and not Fu.IsInRange(bot, enemyHero, 600)
			and #(Fu.GetNearbyHeroes(enemyHero, 1200, false, BOT_MODE_NONE) or {}) <= 2
		then
			local comboDamage, enough = X.ComboDamage(enemyHero, false)
			if enough then
				local blinkDistance = math.min(range, GetUnitToUnitDistance(bot, enemyHero) - 250)
				local blinkLocation = Fu.GetUnitTowardDistanceLocation(bot, enemyHero, blinkDistance)
				if IsLocationPassable(blinkLocation) then
					X.LogNyx(string.format("blink-combo hp=%d dmg=%d", enemyHero:GetHealth(), comboDamage), enemyHero)
					return blink, blinkLocation
				end
			end
		end
	end
	return nil
end
-- Enemies on the Impale line at cast time get its damage recorded.
function X.RecordImpale(loc)
	if loc == nil then
		return
	end
	local botLocation = bot:GetLocation()
	local deltaX, deltaY = loc.x - botLocation.x, loc.y - botLocation.y
	local distance = math.sqrt(deltaX * deltaX + deltaY * deltaY)
	if distance < 1 then
		return
	end
	local directionX, directionY = deltaX / distance, deltaY / distance
	local length = impaleAbility:GetSpecialValueInt("length")
	if length == nil or length <= 0 then
		length = 750
	end
	local width = impaleAbility:GetSpecialValueInt("width")
	if width == nil or width <= 0 then
		width = 140
	end
	local damage = impaleAbility:GetSpecialValueInt("impale_damage")
	for _, enemyHero in pairs(Fu.GetNearbyHeroes(bot, length + 200, true, BOT_MODE_NONE) or {}) do
		if Fu.IsValidHero(enemyHero) then
			local enemyLocation = enemyHero:GetLocation()
			local along = (enemyLocation.x - botLocation.x) * directionX
				+ (enemyLocation.y - botLocation.y) * directionY
			local sideOffset = math.abs(
				(enemyLocation.x - botLocation.x) * directionY - (enemyLocation.y - botLocation.y) * directionX
			)
			if along >= 0 and along <= length + 100 and sideOffset <= width + 60 then
				X.AddDealt(enemyHero, damage)
			end
		end
	end
end
-- Dagon on a stunned enemy hero while engaging, before Mind Flare.
function X.ConsiderDagonCombo()
	if not isGoingOnSomeone then
		return nil
	end
	local dagon = nil
	for slot = 0, 5 do
		local item = bot:GetItemInSlot(slot)
		if item ~= nil and string.find(item:GetName(), "item_dagon", 1, true) and item:IsFullyCastable() then
			dagon = item
			break
		end
	end
	if dagon == nil then
		return nil
	end
	local range = dagon:GetCastRange() + 50
	for _, enemyHero in pairs(Fu.GetNearbyHeroes(bot, range, true, BOT_MODE_NONE) or {}) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and Fu.CanCastOnTargetAdvanced(enemyHero)
			and not Fu.IsSuspiciousIllusion(enemyHero)
			and Fu.IsDisabled(enemyHero)
			and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
			and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
			and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
			and not enemyHero:HasModifier("modifier_templar_assassin_refraction_absorb")
		then
			return dagon, enemyHero
		end
	end
	return nil
end
function X.ConsiderImpale()
	if not impaleAbility:IsFullyCastable() or bot:HasModifier("modifier_nyx_assassin_vendetta") then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local castRange = Fu.GetProperCastRange(false, bot, impaleAbility:GetCastRange())
	local castPoint = impaleAbility:GetCastPoint()
	local duration = impaleAbility:GetSpecialValueInt("duration")
	local damage = impaleAbility:GetSpecialValueInt("impale_damage")
	botTarget = Fu.GetProperTarget(bot)
	local nearbyEnemies = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and not Fu.IsSuspiciousIllusion(enemyHero)
		then
			if enemyHero:IsChanneling() or Fu.IsCastingUltimateAbility(enemyHero) then
				return BOT_ACTION_DESIRE_HIGH, enemyHero:GetLocation()
			end
			if
				Fu.CanKillTarget(enemyHero, damage, DAMAGE_TYPE_MAGICAL)
				and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
				and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
				and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
				and not enemyHero:HasModifier("modifier_templar_assassin_refraction_absorb")
			then
				return BOT_ACTION_DESIRE_HIGH, enemyHero:GetExtrapolatedLocation(castPoint)
			end
		end
	end
	local nearbyAllies = Fu.GetNearbyHeroes(bot, castRange, false, BOT_MODE_NONE)
	for _, allyHero in pairs(nearbyAllies) do
		local enemiesNearAlly = Fu.GetNearbyHeroes(allyHero, castRange, true, BOT_MODE_NONE)
		if
			Fu.IsRetreating(allyHero)
			and allyHero:WasRecentlyDamagedByAnyHero(2.1)
			and not allyHero:IsIllusion()
			and mpRatio > 0.31
		then
			if
				enemiesNearAlly ~= nil
				and #enemiesNearAlly >= 1
				and Fu.IsValidHero(enemiesNearAlly[1])
				and Fu.CanCastOnNonMagicImmune(enemiesNearAlly[1])
				and Fu.IsInRange(allyHero, enemiesNearAlly[1], 400)
				and Fu.IsInRange(bot, enemiesNearAlly[1], castRange)
				and Fu.IsRunning(allyHero)
				and enemiesNearAlly[1]:IsFacingLocation(allyHero:GetLocation(), 30)
				and not Fu.IsDisabled(enemiesNearAlly[1])
				and not Fu.IsTaunted(enemiesNearAlly[1])
				and not Fu.IsSuspiciousIllusion(enemiesNearAlly[1])
				and not enemiesNearAlly[1]:HasModifier("modifier_enigma_black_hole_pull")
				and not enemiesNearAlly[1]:HasModifier("modifier_faceless_void_chronosphere_freeze")
				and not enemiesNearAlly[1]:HasModifier("modifier_necrolyte_reapers_scythe")
			then
				return BOT_ACTION_DESIRE_HIGH, enemiesNearAlly[1]:GetExtrapolatedLocation(castPoint)
			end
		end
	end
	if isGoingOnSomeone then
		local strongestEnemy = Fu.GetStrongestUnit(castRange, bot, true, false, duration)
		local nearbyAllies = Fu.GetNearbyHeroes(bot, 1200, false, BOT_MODE_NONE)
		if strongestEnemy == nil then
			strongestEnemy = Fu.GetStrongestUnit(castRange, bot, true, true, duration)
		end
		if
			Fu.IsValidTarget(strongestEnemy)
			and Fu.IsInRange(bot, strongestEnemy, castRange)
			and not Fu.IsSuspiciousIllusion(strongestEnemy)
			and not Fu.IsDisabled(strongestEnemy)
			and not Fu.IsTaunted(strongestEnemy)
			and not strongestEnemy:HasModifier("modifier_abaddon_borrowed_time")
			and not strongestEnemy:HasModifier("modifier_dazzle_shallow_grave")
			and not strongestEnemy:HasModifier("modifier_enigma_black_hole_pull")
			and not strongestEnemy:HasModifier("modifier_faceless_void_chronosphere_freeze")
			and not strongestEnemy:HasModifier("modifier_necrolyte_reapers_scythe")
			and not strongestEnemy:HasModifier("modifier_templar_assassin_refraction_absorb")
		then
			local targetAllies = Fu.GetNearbyHeroes(strongestEnemy, 1200, false, BOT_MODE_NONE)
			if nearbyAllies ~= nil and targetAllies ~= nil and #nearbyAllies >= #targetAllies then
				return BOT_ACTION_DESIRE_HIGH, strongestEnemy:GetExtrapolatedLocation(castPoint)
			end
		end
	end
	if Fu.IsRetreating(bot) then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, 800, false, BOT_MODE_NONE)
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, 800, true, BOT_MODE_NONE)
		if
			nearbyAllies ~= nil
			and nearbyEnemies
			and Fu.IsValidHero(nearbyEnemies[1])
			and Fu.CanCastOnNonMagicImmune(nearbyEnemies[1])
			and Fu.IsInRange(bot, nearbyEnemies[1], castRange)
			and Fu.IsRunning(nearbyEnemies[1])
			and nearbyEnemies[1]:IsFacingLocation(bot:GetLocation(), 30)
			and not Fu.IsSuspiciousIllusion(nearbyEnemies[1])
		then
			local enemyAllies = Fu.GetNearbyHeroes(nearbyEnemies[1], 800, false, BOT_MODE_NONE)
			if
				enemyAllies ~= nil
				and (#enemyAllies > #nearbyAllies or Fu.GetHP(bot) < 0.82 and bot:WasRecentlyDamagedByAnyHero(1.5))
			then
				return BOT_ACTION_DESIRE_HIGH, nearbyEnemies[1]:GetExtrapolatedLocation(castPoint)
			end
		end
	end
	if Fu.IsLaning(bot) and not Fu.IsThereNonSelfCoreNearby(1200) then
		local killableCount = 0
		local killableCreeps = {}
		local nearbyLaneCreeps = bot:GetNearbyLaneCreeps(castRange, true)
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
		for _, creep in pairs(nearbyLaneCreeps) do
			if Fu.IsValid(creep) and creep:GetHealth() <= damage then
				killableCount = killableCount + 1
				table.insert(killableCreeps, creep)
			end
		end
		if killableCount >= 2 and mpRatio > 0.25 and nearbyEnemies ~= nil and #nearbyEnemies >= 1 then
			return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(killableCreeps)
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if
			Fu.IsRoshan(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, 500)
			and Fu.IsAttacking(bot)
			and not Fu.IsDisabled(botTarget)
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, 400) and Fu.IsAttacking(bot) then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.ConsiderMindflare()
	if not mindFlareAbility:IsFullyCastable() or bot:HasModifier("modifier_nyx_assassin_vendetta") then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castRange = Fu.GetProperCastRange(false, bot, mindFlareAbility:GetCastRange())
	local maxManaPct = mindFlareAbility:GetSpecialValueInt("max_mana_as_damage_pct")
	local nearbyEnemies = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and Fu.CanKillTarget(
				enemyHero,
				enemyHero:GetMaxMana() * maxManaPct / 100 + X.EchoDamage(enemyHero),
				DAMAGE_TYPE_MAGICAL
			)
			and not Fu.IsSuspiciousIllusion(enemyHero)
			and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
			and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
			and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
			and not enemyHero:HasModifier("modifier_templar_assassin_refraction_absorb")
		then
			return BOT_ACTION_DESIRE_HIGH, enemyHero
		end
	end
	if isGoingOnSomeone then
		local weakestEnemy = Fu.GetVulnerableWeakestUnit(bot, true, true, castRange)
		local nearbyAllies = Fu.GetNearbyHeroes(bot, 800, false, BOT_MODE_NONE)
		if
			Fu.IsValidTarget(weakestEnemy)
			and not Fu.IsSuspiciousIllusion(weakestEnemy)
			and not weakestEnemy:HasModifier("modifier_abaddon_borrowed_time")
			and not weakestEnemy:HasModifier("modifier_dazzle_shallow_grave")
			and not weakestEnemy:HasModifier("modifier_necrolyte_reapers_scythe")
			and not weakestEnemy:HasModifier("modifier_templar_assassin_refraction_absorb")
		then
			local targetAllies = Fu.GetNearbyHeroes(weakestEnemy, 800, false, BOT_MODE_NONE)
			if nearbyAllies ~= nil and targetAllies ~= nil and #nearbyAllies >= #targetAllies then
				return BOT_ACTION_DESIRE_HIGH, weakestEnemy
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function X.ConsiderSpikedCarapace()
	-- Allowed under Vendetta: activating it does not break the invisibility (Valve data).
	if not spikedCarapaceAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
	end
	-- Burrowed, Carapace stuns enemies around him at once (Valve data, 400 radius). It was
	-- never cast while burrowed.
	if bot:HasModifier("modifier_nyx_assassin_burrow") then
		local radius = burrowAbility:GetSpecialValueInt("carapace_radius")
		if radius == nil or radius <= 0 then
			radius = 400
		end
		local enemyCount = 0
		for _, enemyHero in pairs(Fu.GetNearbyHeroes(bot, radius, true, BOT_MODE_NONE) or {}) do
			if
				Fu.IsValidHero(enemyHero)
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and not Fu.IsSuspiciousIllusion(enemyHero)
			then
				enemyCount = enemyCount + 1
			end
		end
		if enemyCount >= 1 then
			X.LogNyx("carapace-burrowed enemies=" .. enemyCount, nil)
			return BOT_ACTION_DESIRE_HIGH
		end
		return BOT_ACTION_DESIRE_NONE
	end
	if Fu.IsUnitTargetProjectileIncoming(bot, 400) then
		return BOT_ACTION_DESIRE_HIGH
	end
	-- Right-clicks, melee included: any damage source is stunned (once each). Two heroes hitting
	-- him, or one when he is below 80% HP.
	local hitters = 0
	for _, enemyHero in pairs(Fu.GetNearbyHeroes(bot, 700, true, BOT_MODE_NONE) or {}) do
		if
			Fu.IsValidHero(enemyHero)
			and not Fu.IsSuspiciousIllusion(enemyHero)
			and enemyHero:GetAttackTarget() == bot
			and not enemyHero:IsDisarmed()
		then
			hitters = hitters + 1
		end
	end
	if hitters >= 2 or hitters >= 1 and Fu.GetHP(bot) < 0.8 then
		X.LogNyx("carapace-attacked hitters=" .. hitters, nil)
		return BOT_ACTION_DESIRE_HIGH
	end
	if not bot:HasModifier("modifier_sniper_assassinate") and not bot:IsMagicImmune() then
		if Fu.IsWillBeCastUnitTargetSpell(bot, 1400) then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderBurrow()
	if bot:HasModifier("modifier_nyx_assassin_burrow") or not Fu.CanBeCast(burrowAbility) then
		return BOT_ACTION_DESIRE_NONE
	end
	local carapaceRadius = burrowAbility:GetSpecialValueInt("carapace_radius")
	if Fu.IsInTeamFight(bot, 1200) then
		local nearbyEnemies = Fu.GetEnemiesNearLoc(bot:GetLocation(), carapaceRadius)
		if nearbyEnemies ~= nil and #nearbyEnemies >= 2 then
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderUnBurrow()
	if not bot:HasModifier("modifier_nyx_assassin_burrow") or not Fu.CanBeCast(unburrowAbility) then
		return BOT_ACTION_DESIRE_NONE
	end
	local nearbyEnemies = Fu.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE)
	if #nearbyEnemies < 1 then
		return BOT_ACTION_DESIRE_HIGH
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderVendetta()
	if
		not vendettaAbility:IsFullyCastable()
		or bot:HasModifier("modifier_nyx_assassin_burrow")
		or Fu.IsRealInvisible(bot)
	then
		return BOT_ACTION_DESIRE_NONE
	end
	botTarget = Fu.GetProperTarget(bot)
	-- Combo kill: Vendetta hit + Impale + Dagon + Mind Flare (with echo), as far as his mana goes,
	-- kills the target. It used to count the Vendetta hit alone, and needed his side to match the
	-- target's within 800, so one enemy next to the target called it off. Now up to 2 enemy heroes
	-- near the target is fine (Carapace and the stuns cover the way out), if he is above 50% HP.
	-- Range 2500: Vendetta's speed walks him there.
	if Fu.GetHP(bot) >= 0.5 and not Fu.IsRetreating(bot) then
		local bestTarget, bestHp = nil, math.huge
		for _, enemyHero in pairs(Fu.GetNearbyHeroes(bot, 2500, true, BOT_MODE_NONE) or {}) do
			if
				Fu.IsValidHero(enemyHero)
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and X.SafeToCombo(enemyHero)
				and #(Fu.GetNearbyHeroes(enemyHero, 1200, false, BOT_MODE_NONE) or {}) <= 2
				and enemyHero:GetHealth() < bestHp
			then
				local comboDamage, enough = X.ComboDamage(enemyHero, true)
				if enough then
					bestTarget, bestHp = enemyHero, enemyHero:GetHealth()
				end
			end
		end
		if bestTarget ~= nil then
			bot.canVendettaKill = true
			bot.vendettaTarget = bestTarget
			X.LogNyx(string.format("vendetta-combo hp=%d", bestTarget:GetHealth()), bestTarget)
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	-- Escape only under real pressure: hit by a hero in the last 3s and below 50% HP or
	-- outnumbered. Every retreat used to spend it.
	if Fu.IsRetreating(bot) and not Fu.IsRealInvisible(bot) and bot:WasRecentlyDamagedByAnyHero(3) then
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE) or {}
		local nearbyAllies = Fu.GetNearbyHeroes(bot, 1200, false, BOT_MODE_NONE) or {}
		if #nearbyEnemies >= 1 and (Fu.GetHP(bot) < 0.5 or #nearbyEnemies > #nearbyAllies) then
			bot.canVendettaKill = false
			bot.vendettaTarget = nil
			X.LogNyx("vendetta-escape", nil)
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	if isGoingOnSomeone then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, 1600, false, BOT_MODE_NONE)
		if
			Fu.IsValidTarget(botTarget)
			and Fu.IsInRange(bot, botTarget, 2200)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not Fu.IsDisabled(botTarget)
			and not Fu.IsTaunted(botTarget)
			and not botTarget:HasModifier("modifier_dazzle_shallow_grave")
			and not botTarget:HasModifier("modifier_enigma_black_hole_pull")
			and not botTarget:HasModifier("modifier_faceless_void_chronosphere_freeze")
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
			and not botTarget:HasModifier("modifier_templar_assassin_refraction_absorb")
		then
			local targetAllies = Fu.GetNearbyHeroes(botTarget, 1600, false, BOT_MODE_NONE)
			if nearbyAllies ~= nil and targetAllies ~= nil and #nearbyAllies >= #targetAllies then
				-- Walk to the target and break the invisibility on it (it used to only go
				-- invisible here, with nothing steering him).
				bot.canVendettaKill = true
				bot.vendettaTarget = botTarget
				X.LogNyx("vendetta-engage", botTarget)
				return BOT_ACTION_DESIRE_HIGH
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
return X
