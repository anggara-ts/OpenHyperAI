-- Puck: skill build, item build, and ability use for this hero.
local X = {}
local bot = GetBot()
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local AbilityContext = require(GetScriptDirectory() .. "/FuncLib/systems/ability_context")
local Minion = require(GetScriptDirectory() .. "/FuncLib/hero/minion")
local EscapeRules = require(GetScriptDirectory() .. "/FuncLib/systems/escape_rules")
local sTalentList = Fu.Skill.GetTalentList(bot)
local sAbilityList = Fu.Skill.GetAbilityList(bot)
local sRole = Fu.Item.GetRoleItemsBuyList(bot)
local tTalentTreeList = { ["t25"] = { 0, 10 }, ["t20"] = { 0, 10 }, ["t15"] = { 10, 0 }, ["t10"] = { 0, 10 } }
local tAllAbilityBuildList = { { 1, 3, 1, 2, 1, 6, 1, 2, 2, 2, 6, 3, 3, 3, 6 } }
local nAbilityBuildList = Fu.Skill.GetRandomBuild(tAllAbilityBuildList)
local nTalentBuildList = Fu.Skill.GetTalentBuild(tTalentTreeList)
local sMagicImmuneItem = RandomInt(1, 2) == 1 and "item_black_king_bar" or "item_sphere"
local sRoleItemsBuyList = {}
-- Stratz 7.41f, week of 9 Nov 2026: pos 2, 50,775 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_2"] = {
	"item_tango",
	"item_double_branches",
	"item_faerie_fire",
	"item_magic_wand",
	"item_null_talisman",
	"item_power_treads",
	"item_witch_blade",
	"item_blink",
	"item_aghanims_shard",
	"item_devastator",
	sMagicImmuneItem,
	"item_ultimate_scepter",
	"item_greater_crit",
	"item_ultimate_scepter_2",
	"item_overwhelming_blink",
	"item_wind_waker",
	"item_moon_shard",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 1 has 251 matches, built from pos 2 (50,775) (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_1"] = sRoleItemsBuyList["pos_2"]
-- Stratz 7.41f, week of 9 Nov 2026: pos 3 has 532 matches, built from pos 2 (50,775) (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_3"] = sRoleItemsBuyList["pos_2"]
-- Pos 4/5: a support start (Stratz 7.41f pos 4, n=902: Tango 100%, Blood Grenade 47%, Magic Stick 47%,
-- Branches 70%) and the same core items (Blink 105%, Witch Blade 59%, Eul's 59%).
-- Stratz 7.41f, week of 9 Nov 2026: pos 4, 1,196 matches (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_4"] = {
	"item_tango",
	"item_blood_grenade",
	"item_double_branches",
	"item_magic_stick",
	"item_faerie_fire",
	"item_null_talisman",
	"item_magic_wand",
	"item_power_treads",
	"item_blink",
	"item_cyclone",
	"item_aghanims_shard",
	"item_ultimate_scepter",
	"item_travel_boots",
	"item_octarine_core",
	"item_maelstrom",
	"item_mjollnir",
	"item_moon_shard",
	"item_ultimate_scepter_2",
}
-- Stratz 7.41f, week of 9 Nov 2026: pos 5 has 728 matches, built from pos 4 (1,196) (Util/item-builds/generate.js).
sRoleItemsBuyList["pos_5"] = sRoleItemsBuyList["pos_4"]
X["sBuyList"] = sRoleItemsBuyList[sRole]
X["sSellList"] = { "item_black_king_bar", "item_quelling_blade" }
if Fu.Role.IsPvNMode() or Fu.Role.IsAllShadow() then
	X["sBuyList"], X["sSellList"] = { "PvN_mid" }, {}
end
nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"] =
	Fu.SetUserHeroInit(nAbilityBuildList, nTalentBuildList, X["sBuyList"], X["sSellList"])
X["sSkillList"] = Fu.Skill.GetSkillList(sAbilityList, nAbilityBuildList, sTalentList, nTalentBuildList)
X["bDeafaultAbility"] = false
-- Cast when cornered (retreating into 3+ enemies with no way out), before running further.
X["LastStandSpells"] = { { name = "puck_dream_coil", kind = "point" } }
X["bDeafaultItem"] = false
function X.MinionThink(minionUnit)
	Minion.MinionThink(minionUnit)
end
local illusoryOrbAbility = SafeAbility(bot:GetAbilityByName("puck_illusory_orb"), "puck_illusory_orb", "puck")
local waningRiftAbility = SafeAbility(bot:GetAbilityByName("puck_waning_rift"), "puck_waning_rift", "puck")
local phaseShiftAbility = SafeAbility(bot:GetAbilityByName("puck_phase_shift"), "puck_phase_shift", "puck")
local etherealJauntAbility = SafeAbility(bot:GetAbilityByName("puck_ethereal_jaunt"), "puck_ethereal_jaunt", "puck")
local dreamCoilAbility = SafeAbility(bot:GetAbilityByName("puck_dream_coil"), "puck_dream_coil", "puck")
local illusoryOrbDesire, illusoryOrbLocation
local waningRiftDesire, waningRiftLocation
local phaseShiftDesire
local etherealJauntDesire
local dreamCoilDesire, dreamCoilLocation
local phaseOrbDesire, phaseOrbLocation
local isOrbEscaping = false
local botTarget
local isGoingOnSomeone
local isRetreating
local isAttacking
local mpRatio
-- Diagnostic (#15): Phase Shift is channelled (game files: DOTA_ABILITY_BEHAVIOR_CHANNELLED), so any new order ends
-- it. Does Puck stay shifted for the full duration, or does the next mode order cut it short? One line per shift.
function X.TrackPhaseShift()
	if bot._phaseProbeAt ~= nil and DotaTime() >= bot._phaseProbeAt then
		local since = DotaTime() - (bot._phaseOrderAt or DotaTime())
		-- Two probes inside the shift: 0.3s after the order and 0.15s before its end (duration 1 / 1.75 / 2.5 /
		-- 3.25s). Game 051: the one probe at 1.0s came after a rank 1 shift was over, so it said nothing.
		bot._phaseProbeAt = since < 0.5
				and bot._phaseOrderAt + math.max(0.6, phaseShiftAbility:GetSpecialValueFloat("duration") - 0.15)
			or nil
		local mods = {}
		for i = 0, bot:NumModifiers() - 1 do
			mods[#mods + 1] = tostring(bot:GetModifierName(i))
		end
		local activeNow = bot:GetCurrentActiveAbility()
		pcall(
			print,
			string.format(
				"[OHA-PUCK] t=%.0f phase-probe after=%.1f moved=%d action=%s cd=%.1f invuln=%s damaged=%s channelling=%s active=%s mods=%s",
				DotaTime(),
				since,
				-- Distance from where she ordered the shift and what she is doing now: a move or another order
				-- inside the shift means something broke the channel.
				bot._phaseOrderLoc ~= nil and GetUnitToLocationDistance(bot, bot._phaseOrderLoc) or -1,
				tostring(bot:GetCurrentActionType()),
				phaseShiftAbility:GetCooldownTimeRemaining(),
				tostring(bot:IsInvulnerable()),
				tostring(X.HurtSincePhaseOrder()),
				tostring(bot:IsChanneling()),
				activeNow ~= nil and not activeNow:IsNull() and activeNow:GetName() or "-",
				table.concat(mods, ",")
			)
		)
	end
	local active = bot:IsChanneling() and bot:GetCurrentActiveAbility() or nil
	local channelling = active ~= nil and not active:IsNull() and active:GetName() == "puck_phase_shift"
	local shifted = bot:HasModifier("modifier_puck_phase_shift") or channelling
	local track = bot._phaseTrack
	if shifted and track == nil then
		bot._phaseTrack = {
			at = DotaTime(),
			full = phaseShiftAbility:GetSpecialValueFloat("duration"),
			mode = bot:GetActiveMode(),
			by = channelling and "channel" or "modifier",
		}
	elseif shifted and track ~= nil and not track.leftLogged and bot:GetActiveMode() ~= (BOT_MODE_OUTPOST or 26) then
		-- Game 057: 4 shifts inside the hold ended at 0.3-0.7s when the mode left the hold (to attack or roam). Which
		-- mode took over, with what desire, and whether the hold was still meant to run.
		track.leftLogged = true
		pcall(
			print,
			string.format(
				"[OHA-PUCK] t=%.0f phase hold-left after=%.2f mode=%d desire=%.2f hold-for=%.2f hurt=%s hold-desire=%.2f age=%.2f invuln=%s",
				DotaTime(),
				DotaTime() - track.at,
				bot:GetActiveMode(),
				bot:GetActiveModeDesire(),
				(bot._castHoldUntil or 0) - DotaTime(),
				tostring(X.HurtSincePhaseOrder()),
				bot._outpostLastDesire or -1,
				DotaTime() - (bot._outpostLastDesireAt or -99),
				tostring(bot:IsInvulnerable())
			)
		)
	elseif not shifted and track ~= nil then
		bot._phaseTrack = nil
		pcall(
			print,
			string.format(
				"[OHA-PUCK] t=%.0f phase held=%.2f of=%.2f mode=%d->%d hp=%.2f by=%s exit=%s",
				DotaTime(),
				DotaTime() - track.at,
				track.full or -1,
				track.mode or -1,
				bot:GetActiveMode(),
				Fu.GetHP(bot),
				track.by or "?",
				-- She ended it herself (X.ShiftExit): a short held= then is not a broken hold.
				bot._phaseExitHow or "-"
			)
		)
		bot._phaseExitHow = nil
	end
end
-- Escape order (#15, game 044, 38:47): Puck Eul'd herself against Pudge's hook while her orb flew away unused,
-- landed among 8 enemies, was rooted and died. Her own escapes come first: tell the generic self-Eul rule
-- (bot._puckEscapeReady) and Jaunt to an orb in flight when in danger. Jaunt is ROOT_DISABLES (game files), so it
-- has to come before a root.
function X.OrbInFlight()
	for _, projectile in pairs(GetLinearProjectiles() or {}) do
		if
			projectile ~= nil
			and projectile.ability ~= nil
			and projectile.ability:GetName() == "puck_illusory_orb"
			and not Fu.IsLocationInChrono(projectile.location)
		then
			return projectile.location
		end
	end
	return nil
end
function X.DangerJaunt()
	if
		not etherealJauntAbility:IsFullyCastable()
		or bot:IsRooted()
		or DotaTime() < (bot._dangerJauntAt or -999) + 3
	then
		return false
	end
	local orbAt = X.OrbInFlight()
	if orbAt == nil or GetUnitToLocationDistance(bot, orbAt) < 500 then
		return false
	end
	local enemiesHere = #Fu.GetEnemiesNearLoc(bot:GetLocation(), 900)
	local enemiesThere = #Fu.GetEnemiesNearLoc(orbAt, 700)
	local alliesHere = #Fu.GetAlliesNearLoc(bot:GetLocation(), 900)
	local danger = bot:WasRecentlyDamagedByAnyHero(1.5) and (enemiesHere > alliesHere or Fu.GetHP(bot) < 0.5)
		or Fu.IsStunProjectileIncoming(bot, 800)
	-- Only to an orb on the escape side (away from the nearest enemies, toward our fountain). Game 064, t=2600: a
	-- danger Jaunt took her to an orb flying away from base, and she died at 43:23 farther from the fountain.
	local here = bot:GetLocation()
	local _, dirX, dirY = X.EscapePoint(1)
	local escapeSide = EscapeRules.IsOnEscapeSide(here.x, here.y, orbAt.x, orbAt.y, dirX, dirY)
	if danger and enemiesThere < enemiesHere and not escapeSide then
		if DotaTime() >= (bot._jauntSideLogAt or -999) then
			bot._jauntSideLogAt = DotaTime() + 3
			pcall(
				print,
				string.format(
					"[OHA-PUCK] t=%.0f escape-order skip=jaunt why=wrong-side enemies=%d->%d hp=%.2f",
					DotaTime(),
					enemiesHere,
					enemiesThere,
					Fu.GetHP(bot)
				)
			)
		end
		return false
	end
	if danger and enemiesThere < enemiesHere then
		X.LogEscapeAction("jaunt", "danger", orbAt)
		pcall(
			print,
			string.format(
				"[OHA-PUCK] t=%.0f escape-order used=jaunt enemies=%d->%d hp=%.2f",
				DotaTime(),
				enemiesHere,
				enemiesThere,
				Fu.GetHP(bot)
			)
		)
		bot._dangerJauntAt = DotaTime()
		bot:Action_UseAbility(etherealJauntAbility)
		return true
	end
	return false
end
-- Diagnostic (#15, game 048 64:10: Puck used Eul, not Phase Shift or Blink). In danger, what escapes she has.
-- Blink: damage puts it on a 3s cooldown (game files: blink_damage_cooldown 3.0). Every 3s at most.
function X.LogEscapeCheck(orbOut, canCast)
	if
		DotaTime() < (bot._escapeCheckLogAt or -999)
		or not bot:WasRecentlyDamagedByAnyHero(1.5)
		or Fu.GetHP(bot) > 0.5
	then
		return
	end
	bot._escapeCheckLogAt = DotaTime() + 3
	local blinkItem = X.BlinkItem()
	local blinkCd = blinkItem ~= nil and blinkItem:GetCooldownTimeRemaining() or -1
	pcall(
		print,
		string.format(
			"[OHA-PUCK] t=%.0f escape-check hp=%.2f silenced=%s canCast=%s phaseCd=%.1f orbOut=%s jauntOk=%s rooted=%s blinkCd=%.1f blink=%s siphoned=%s ready=%s enemies=%d",
			DotaTime(),
			Fu.GetHP(bot),
			tostring(bot:IsSilenced()),
			tostring(canCast),
			phaseShiftAbility:GetCooldownTimeRemaining(),
			tostring(orbOut),
			tostring(etherealJauntAbility:IsFullyCastable()),
			tostring(bot:IsRooted()),
			blinkCd,
			X.BlinkState(blinkItem),
			tostring(bot:HasModifier("modifier_death_prophet_spirit_siphon_slow")),
			tostring(bot._puckEscapeReady),
			#Fu.GetEnemiesNearLoc(bot:GetLocation(), 1000)
		)
	)
end
-- Her Blink Dagger (or an upgrade) in the main slots, or nil.
function X.BlinkItem()
	for _, name in ipairs({ "item_blink", "item_overwhelming_blink", "item_swift_blink", "item_arcane_blink" }) do
		local slot = bot:FindItemSlot(name)
		if slot >= 0 and slot <= 5 then
			local item = bot:GetItemInSlot(slot)
			if item ~= nil and not item:IsNull() then
				return item
			end
		end
	end
	return nil
end
-- ready | damage-block (hero damage puts Blink on cooldown for blink_damage_cooldown 3.0s, 7.42 items) | cooldown
-- | none. Game 064, 43:18-43:23: blinkCd=3.0 twice, the block renewed by every hit.
function X.BlinkState(blinkItem)
	if blinkItem == nil then
		return "none"
	end
	local cd = blinkItem:GetCooldownTimeRemaining()
	if cd <= 0 then
		return "ready"
	end
	if cd <= 3.0 and bot:WasRecentlyDamagedByAnyHero(3.0) then
		return "damage-block"
	end
	return "cooldown"
end
-- The point for an escape jump of `distance`: away from the visible enemy heroes within 1600 (the nearest counts
-- most) and toward our fountain (EscapeRules.Direction). Replaces Fu.GetEscapeLoc() (our Ancient once 2500 from the
-- fountain) for her escapes: game 064, 43:23, she died moving away from base.
function X.EscapePoint(distance)
	local here = bot:GetLocation()
	local enemies = {}
	for _, enemyHero in pairs(Fu.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE) or {}) do
		if Fu.IsValidHero(enemyHero) and not Fu.IsSuspiciousIllusion(enemyHero) then
			local at = enemyHero:GetLocation()
			enemies[#enemies + 1] = { x = at.x, y = at.y }
		end
	end
	local home = Fu.GetTeamFountain()
	local dx, dy = EscapeRules.Direction(here.x, here.y, enemies, home.x, home.y)
	return Vector(here.x + dx * distance, here.y + dy * distance, here.z), dx, dy
end
-- One line per escape action (#36, game 064: no line named the escape action or where it went).
-- jump: how far the point is; home: distance to our fountain now -> from the point; nearest: the nearest enemy
-- hero and its distance now -> to the point.
function X.LogEscapeAction(spell, why, point)
	local here = bot:GetLocation()
	local fountain = Fu.GetTeamFountain()
	local nearest, nearestDist = nil, math.huge
	for _, enemyHero in pairs(Fu.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE) or {}) do
		if Fu.IsValidHero(enemyHero) then
			local dist = GetUnitToUnitDistance(bot, enemyHero)
			if dist < nearestDist then
				nearest, nearestDist = enemyHero, dist
			end
		end
	end
	pcall(
		print,
		string.format(
			"[OHA-PUCK] t=%.0f escape-action spell=%s why=%s to=%.0f,%.0f jump=%.0f home=%.0f->%.0f nearest=%s:%.0f->%.0f enemies=%d hp=%.2f blink=%s",
			DotaTime(),
			spell,
			why,
			point.x,
			point.y,
			(point - here):Length2D(),
			(fountain - here):Length2D(),
			(fountain - point):Length2D(),
			nearest ~= nil and (string.gsub(nearest:GetUnitName(), "npc_dota_hero_", "")) or "-",
			nearest ~= nil and nearestDist or -1,
			nearest ~= nil and GetUnitToLocationDistance(nearest, point) or -1,
			#Fu.GetEnemiesNearLoc(here, 1200),
			Fu.GetHP(bot),
			X.BlinkState(X.BlinkItem())
		)
	)
end
-- The enemy Death Prophet whose Spirit Siphon is on her (the slow modifier is on Puck: game 064 phase-probe mods=
-- ...modifier_death_prophet_spirit_siphon_slow), or nil. Within 1200 so a far one doesn't count.
function X.SiphonSource()
	if not bot:HasModifier("modifier_death_prophet_spirit_siphon_slow") then
		return nil
	end
	for _, enemyHero in pairs(Fu.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE) or {}) do
		if Fu.IsValidHero(enemyHero) and enemyHero:GetUnitName() == "npc_dota_hero_death_prophet" then
			return enemyHero
		end
	end
	return nil
end
-- Under Spirit Siphon (game 064, 4:00: siphoned at 42% HP with Phase Shift ready, she used Waning Rift and TP'd home
-- at 29%, drained during the channel). The link breaks past EscapeRules.SIPHON_BREAK (750) from Death Prophet; a Rift
-- (350) doesn't get there. In danger: Orb away first (Orb and Rift can't be cast inside the shift), then Phase Shift
-- (ConsiderPhaseShift why=siphon) blocks the drain, and the Jaunt goes once the orb is past the break distance
-- (X.ShiftExit inside the shift, here otherwise). No TP while she has one of these escapes up (bot._noTpUntil, read
-- by the TP rule in ability_item_usage_generic.lua). Returns true when it gave an order.
function X.ConsiderSiphonEscape()
	local siphoner = X.SiphonSource()
	if siphoner == nil or not (Fu.GetHP(bot) < 0.7 or Fu.IsRetreating(bot)) then
		bot._siphonEscapeFrom = nil
		return false
	end
	local mana = bot:GetMana()
	local jauntReady = etherealJauntAbility:IsFullyCastable() and not bot:IsRooted()
	local orbReady = illusoryOrbAbility:IsFullyCastable() and jauntReady and mana >= illusoryOrbAbility:GetManaCost()
	local phaseReady = phaseShiftAbility:IsFullyCastable()
	if orbReady or phaseReady or bot._siphonEscapeFrom ~= nil then
		bot._noTpUntil = DotaTime() + 0.5
	end
	if DotaTime() >= (bot._siphonLogAt or -999) then
		bot._siphonLogAt = DotaTime() + 3
		pcall(
			print,
			string.format(
				"[OHA-PUCK] t=%.0f siphoned dist=%d hp=%.2f orb=%s phase=%s jaunt=%s tp-held=%s",
				DotaTime(),
				GetUnitToUnitDistance(bot, siphoner),
				Fu.GetHP(bot),
				tostring(orbReady),
				tostring(phaseReady),
				tostring(jauntReady),
				tostring(DotaTime() < (bot._noTpUntil or -999))
			)
		)
	end
	-- The orb is past the break distance: Jaunt to it.
	local orbAt = X.OrbInFlight()
	if
		bot._siphonEscapeFrom ~= nil
		and orbAt ~= nil
		and jauntReady
		and DotaTime() - (bot._siphonOrbAt or -999) < 3
		and GetUnitToLocationDistance(siphoner, orbAt) > EscapeRules.SIPHON_BREAK + 50
	then
		bot._siphonEscapeFrom = nil
		X.LogEscapeAction("jaunt", "siphon", orbAt)
		bot:Action_UseAbility(etherealJauntAbility)
		return true
	end
	if orbReady and DotaTime() - (bot._siphonOrbAt or -999) > 3 then
		local castRange = Fu.GetProperCastRange(false, bot, illusoryOrbAbility:GetCastRange())
		local point = X.EscapePoint(castRange)
		bot._siphonOrbAt = DotaTime()
		bot._siphonEscapeFrom = siphoner
		X.LogEscapeAction("orb", "siphon", point)
		bot:Action_UseAbilityOnLocation(illusoryOrbAbility, point)
		return true
	end
	return false
end
-- A Phase Shift's hold ends early (she jumped out of it): free the item think, this script and the outpost hold.
function X.ReleasePhaseHold()
	bot._castHoldUntil = nil
	bot._phaseOrderAt = nil
	bot._phaseWantAt = nil
	bot._phaseProbeAt = nil
end
-- Inside the shift (only CastHoldTick runs then). Two ways out, each once per shift:
-- 1. Spirit Siphon: the orb she threw before the shift is past the break distance from Death Prophet: Jaunt to it.
-- 2. The shift's last 0.2s with an enemy on her: Blink away first, before a projectile that waited for the shift's
--    end lands and renews Blink's damage block (game 064, 43:16: Death Coil landed as the shift ended, tti=0.04,
--    and Blink read 3.0 for the rest of the fight).
function X.ShiftExit()
	local orderAt = bot._phaseOrderAt
	if orderAt == nil or bot._phaseExitFor == orderAt then
		return
	end
	local since = DotaTime() - orderAt
	if since < 0.15 then
		return
	end
	local siphoner = bot._siphonEscapeFrom
	if
		siphoner ~= nil
		and not siphoner:IsNull()
		and etherealJauntAbility:IsFullyCastable()
		and not bot:IsRooted()
		and DotaTime() - (bot._siphonOrbAt or -999) < 3
	then
		local orbAt = X.OrbInFlight()
		if orbAt ~= nil and GetUnitToLocationDistance(siphoner, orbAt) > EscapeRules.SIPHON_BREAK + 50 then
			bot._phaseExitFor = orderAt
			bot._phaseExitHow = "jaunt"
			bot._siphonEscapeFrom = nil
			X.LogEscapeAction("jaunt", "siphon", orbAt)
			X.ReleasePhaseHold()
			bot:Action_UseAbility(etherealJauntAbility)
			return true
		end
	end
	local duration = phaseShiftAbility:GetSpecialValueFloat("duration")
	-- The shift must still be on (TrackPhaseShift keeps bot._phaseTrack while it is), and it must have been an escape
	-- shift: after a dodge in a fight she is winning, Blink (her initiation item) stays unless she is under 35%.
	local castWhy = tostring(bot._phaseCastWhy)
	if
		since < duration - 0.2
		or since > duration + 0.1
		or bot._phaseTrack == nil
		or string.sub(castWhy, 1, 5) == "dodge" and Fu.GetHP(bot) >= 0.35
	then
		return
	end
	local blinkItem = X.BlinkItem()
	if blinkItem == nil or not blinkItem:IsFullyCastable() then
		return
	end
	local enemies = #Fu.GetEnemiesNearLoc(bot:GetLocation(), 1200)
	local allies = #Fu.GetAlliesNearLoc(bot:GetLocation(), 1200)
	if enemies < 1 or (Fu.GetHP(bot) >= 0.6 and enemies <= allies) then
		return
	end
	bot._phaseExitFor = orderAt
	bot._phaseExitHow = "blink"
	-- 1150: inside blink_range 1200 (7.42 items_all.txt; a point beyond it lands at blink_range_clamp 960).
	local point = X.EscapePoint(1150)
	X.LogEscapeAction("blink", "phase-end", point)
	X.ReleasePhaseHold()
	bot:Action_UseAbilityOnLocation(blinkItem, point)
	return true
end
-- Hit by a hero after the Phase Shift order (0.1s for the cast): the shift is not on, so stop holding
-- (game 048, t=752: Puck died at 31% HP within a second of the order, under the hold).
function X.HurtSincePhaseOrder()
	if bot._phaseOrderAt == nil then
		return false
	end
	local since = DotaTime() - bot._phaseOrderAt - 0.1
	return since > 0.05 and bot:WasRecentlyDamagedByAnyHero(since)
end
-- The cast hold (bot._castHoldUntil) pauses the item think, and with it SkillsComplement. The item think calls
-- this instead, so the Phase Shift probe and the "hit: release the hold" check keep running inside the shift
-- (game 051: every probe printed only after the hold, 1.1s to 3.3s after the order).
function X.CastHoldTick()
	pcall(X.TrackPhaseShift)
	pcall(X.ShiftExit)
	if bot._castHoldUntil ~= nil and X.HurtSincePhaseOrder() then
		bot._castHoldUntil = nil
	end
end
function X.SkillsComplement()
	pcall(X.TrackPhaseShift)
	local okExit, exited = pcall(X.ShiftExit)
	if okExit and exited then
		return
	end
	-- Hit after the order: the shift is not on, so nothing is held any more.
	if bot._castHoldUntil ~= nil and X.HurtSincePhaseOrder() then
		bot._castHoldUntil = nil
	end
	-- Hold every other cast while Phase Shift starts and lasts (#15, game 046: 15 orders, never channelling 0.3s later;
	-- 5 of 8 probes found Puck already casting Waning Rift or the orb: our own next think broke the channel).
	if bot._phaseOrderAt ~= nil and DotaTime() - bot._phaseOrderAt < 0.4 then
		return
	end
	if
		bot._phaseOrderAt ~= nil
		and DotaTime() - bot._phaseOrderAt < phaseShiftAbility:GetSpecialValueFloat("duration") + 0.05
		and phaseShiftAbility:GetCooldownTimeRemaining() > 0
		and not X.HurtSincePhaseOrder()
	then
		return
	end
	local activeNow = bot:IsChanneling() and bot:GetCurrentActiveAbility() or nil
	if
		bot:HasModifier("modifier_puck_phase_shift")
		or activeNow ~= nil and not activeNow:IsNull() and activeNow:GetName() == "puck_phase_shift"
	then
		return
	end
	local okReady, orbOut = pcall(X.OrbInFlight)
	local canCast = not Fu.CanNotUseAbility(bot)
	bot._puckEscapeReady = canCast
		and (
			phaseShiftAbility:IsFullyCastable()
			or okReady and orbOut ~= nil and etherealJauntAbility:IsFullyCastable() and not bot:IsRooted()
		)
	pcall(X.LogEscapeCheck, okReady and orbOut ~= nil, canCast)
	if not canCast then
		return
	end
	local okJ, jaunted = pcall(X.DangerJaunt)
	if okJ and jaunted then
		return
	end
	local okS, siphonOrder = pcall(X.ConsiderSiphonEscape)
	if okS and siphonOrder then
		return
	end
	isGoingOnSomeone = Fu.IsGoingOnSomeone(bot)
	isRetreating = Fu.IsRetreating(bot)
	isAttacking = Fu.IsAttacking(bot)
	mpRatio = Fu.GetMP(bot)
	phaseShiftDesire = X.ConsiderPhaseShift()
	-- Hold first, cast one frame later (game 055: 12 of 33 shifts held the full duration; 20 ended after
	-- 0.03-0.17s, in retreat or attack mode). For Puck both modes are Valve's own: our retreat file has no Think
	-- and our attack mode only replaces Valve's for a few heroes, so neither can be paused by the cast hold, and
	-- their Think replaced the cast order. The outpost mode's hold (desire 1.5, Think gives no order) is asked for
	-- first; the cast goes out once it is the active mode, or after 0.2s at most.
	local outpostMode = BOT_MODE_OUTPOST or 26
	-- Game 064: two casts went out after the 0.2s wait in attack mode and broke at 0.1s; the outpost GetDesire had
	-- last run 0.27-0.3s earlier (hold-left age=0.30/0.33, hold-desire=0.00), so the hold had not been asked yet.
	-- A dodge can't wait (the disjoint on cast is the point); any other shift waits up to 0.4s for the hold.
	local isDodge = string.sub(tostring(X.phaseWhy), 1, 5) == "dodge"
	local maxWait = isDodge and 0.2 or 0.4
	if phaseShiftDesire > 0 and bot:GetActiveMode() ~= outpostMode then
		if bot._phaseWantAt == nil or DotaTime() - bot._phaseWantAt > maxWait + 0.3 then
			bot._phaseWantAt = DotaTime()
			bot._phaseWantMode = bot:GetActiveMode()
			return
		end
		if DotaTime() - bot._phaseWantAt < maxWait then
			return
		end
	end
	if phaseShiftDesire > 0 then
		pcall(
			print,
			string.format(
				"[OHA-PUCK] t=%.0f phase cast hp=%.2f enemies=%d retreating=%s why=%s from-mode=%s mode=%d waited=%.2f outpost-age=%.2f",
				DotaTime(),
				Fu.GetHP(bot),
				#Fu.GetEnemiesNearLoc(bot:GetLocation(), 1000),
				tostring(isRetreating),
				tostring(X.phaseWhy),
				tostring(bot._phaseWantMode),
				bot:GetActiveMode(),
				bot._phaseWantAt ~= nil and DotaTime() - bot._phaseWantAt or -1,
				-- How long ago the outpost GetDesire last ran to its end (what the hold had seen).
				DotaTime() - (bot._outpostLastDesireAt or -99)
			)
		)
		bot._phaseWantAt = nil
		bot._phaseWantMode = nil
		bot._phaseProbeAt = DotaTime() + 0.3
		bot._phaseOrderAt = DotaTime()
		bot._phaseCastWhy = X.phaseWhy
		bot._phaseOrderLoc = bot:GetLocation()
		-- Item orders and every wrapped mode Think wait too (OhaCastGuard, ItemUsageThink).
		bot._castHoldUntil = DotaTime() + phaseShiftAbility:GetSpecialValueFloat("duration") + 0.05
		bot:Action_UseAbility(phaseShiftAbility)
		return
	end
	local phaseDuration
	phaseOrbDesire, phaseOrbLocation, phaseDuration = X.ConsiderPhaseOrb()
	if phaseOrbDesire > 0 then
		bot:Action_ClearActions(false)
		bot:ActionQueue_UseAbilityOnLocation(illusoryOrbAbility, phaseOrbLocation)
		bot:ActionQueue_Delay(0.1)
		bot:ActionQueue_UseAbility(phaseShiftAbility)
		bot:ActionQueue_Delay(phaseDuration - 0.3)
		bot:ActionQueue_UseAbility(etherealJauntAbility)
		return
	end
	illusoryOrbDesire, illusoryOrbLocation = X.ConsiderIllusoryOrb()
	if illusoryOrbDesire > 0 then
		-- Bots can't make the orb fly straight: no alt-cast, and neither a full-range aim nor facing the point first
		-- changed the curve (games 044-045, discussion #50). Aim at the target point.
		bot:Action_UseAbilityOnLocation(illusoryOrbAbility, illusoryOrbLocation)
		return
	end
	etherealJauntDesire = X.ConsiderEtherealJaunt()
	if etherealJauntDesire > 0 then
		bot:Action_UseAbility(etherealJauntAbility)
		return
	end
	dreamCoilDesire, dreamCoilLocation = X.ConsiderDreamCoil()
	if dreamCoilDesire > 0 then
		bot:Action_UseAbilityOnLocation(dreamCoilAbility, dreamCoilLocation)
		return
	end
	waningRiftDesire, waningRiftLocation = X.ConsiderWaningRift()
	if waningRiftDesire > 0 then
		pcall(
			print,
			string.format(
				"[OHA-PUCK] t=%.0f rift why=%s heroes=%d dist=%d",
				DotaTime(),
				X.riftWhy or "other",
				#Fu.GetEnemiesNearLoc(waningRiftLocation, waningRiftAbility:GetSpecialValueInt("radius")),
				GetUnitToLocationDistance(bot, waningRiftLocation)
			)
		)
		bot:Action_UseAbilityOnLocation(waningRiftAbility, waningRiftLocation)
		return
	end
end
function X.ConsiderIllusoryOrb()
	if not illusoryOrbAbility:IsFullyCastable() or bot:HasModifier("modifier_puck_phase_shift") then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local castRange = Fu.GetProperCastRange(false, bot, illusoryOrbAbility:GetCastRange())
	local castPoint = illusoryOrbAbility:GetCastPoint()
	local radius = illusoryOrbAbility:GetSpecialValueInt("radius")
	local damage = illusoryOrbAbility:GetSpecialValueInt("damage")
	botTarget = Fu.GetProperTarget(bot)
	local nearbyEnemies = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and Fu.CanKillTarget(enemyHero, damage, DAMAGE_TYPE_MAGICAL)
			and not Fu.IsSuspiciousIllusion(enemyHero)
			and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
			and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
			and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
			and not enemyHero:HasModifier("modifier_templar_assassin_refraction_absorb")
		then
			return BOT_ACTION_DESIRE_HIGH, enemyHero:GetLocation()
		end
	end
	if Fu.IsStuck(bot) then
		local escapeLocation = Fu.GetEscapeLoc()
		return BOT_ACTION_DESIRE_HIGH, Fu.Site.GetXUnitsTowardsLocation(bot, escapeLocation, castRange)
	end
	if isGoingOnSomeone then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, 1000, false, BOT_MODE_NONE)
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
			and not botTarget:HasModifier("modifier_templar_assassin_refraction_absorb")
		then
			local targetAllies = Fu.GetNearbyHeroes(botTarget, 1000, false, BOT_MODE_NONE)
			if nearbyAllies ~= nil and targetAllies ~= nil and #nearbyAllies >= #targetAllies then
				return BOT_ACTION_DESIRE_HIGH, botTarget:GetExtrapolatedLocation(castPoint)
			end
		end
	end
	if isRetreating then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, 800, false, BOT_MODE_NONE)
		local nearbyEnemyHeroes = Fu.GetNearbyHeroes(bot, 1000, true, BOT_MODE_NONE)
		if
			nearbyAllies ~= nil
			and nearbyEnemyHeroes ~= nil
			and Fu.IsValidHero(nearbyEnemyHeroes[1])
			and not Fu.IsSuspiciousIllusion(nearbyEnemyHeroes[1])
		then
			local enemyAllies = Fu.GetNearbyHeroes(nearbyEnemyHeroes[1], 1000, false, BOT_MODE_NONE)
			if enemyAllies ~= nil and #enemyAllies > #nearbyAllies then
				isOrbEscaping = true
				local escapePoint = X.EscapePoint(castRange)
				X.LogEscapeAction("orb", "retreat", escapePoint)
				return BOT_ACTION_DESIRE_HIGH, escapePoint
			else
				isOrbEscaping = false
			end
		end
	end
	if Fu.IsPushing(bot) or Fu.IsDefending(bot) then
		local aoeLocation = bot:FindAoELocation(true, false, bot:GetLocation(), castRange, radius, castPoint, 0)
		local laneCreeps = bot:GetNearbyLaneCreeps(castRange, true)
		if laneCreeps ~= nil and #laneCreeps >= 4 and aoeLocation.count >= 4 then
			return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
		end
		aoeLocation = bot:FindAoELocation(true, true, bot:GetLocation(), castRange, radius, castPoint, 0)
		if aoeLocation.count >= 1 then
			return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
		end
	end
	if Fu.IsFarming(bot) then
		local aoeLocation = bot:FindAoELocation(true, false, bot:GetLocation(), castRange, radius, castPoint, 0)
		if isAttacking then
			local neutralCreeps = bot:GetNearbyNeutralCreeps(castRange)
			if
				neutralCreeps ~= nil
				and (
					#neutralCreeps >= 3 and aoeLocation.count >= 3
					or #neutralCreeps >= 2 and neutralCreeps[1]:IsAncientCreep() and aoeLocation.count >= 2
				)
			then
				return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
			end
			local laneCreeps = bot:GetNearbyLaneCreeps(castRange, true)
			if laneCreeps ~= nil and #laneCreeps >= 3 and aoeLocation.count >= 3 then
				return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
			end
		end
	end
	if Fu.IsLaning(bot) then
		local killableCreepCount = 0
		local killableCreeps = {}
		local laneCreeps = bot:GetNearbyLaneCreeps(castRange, true)
		local nearbyEnemyHeroes = Fu.GetNearbyHeroes(bot, castRange, true, BOT_MODE_NONE)
		for _, creep in pairs(laneCreeps) do
			if Fu.IsValid(creep) and creep:GetHealth() <= damage then
				killableCreepCount = killableCreepCount + 1
				table.insert(killableCreeps, creep)
			end
		end
		if killableCreepCount >= 2 and mpRatio > 0.25 and nearbyEnemyHeroes ~= nil and #nearbyEnemyHeroes >= 1 then
			return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(killableCreeps)
		end
		-- Harass on spare mana (game 064: 3 orbs in 5 minutes of lane; the rule above needs 2 killable creeps): mana
		-- for Rift stays after the orb, and the pool is nearly full or the regen pays the orb back over its cooldown
		-- (datafeed hero 13: Orb 90-120 mana, 12-9s; Phase Shift costs none). Aimed at the nearest enemy hero within
		-- 1100 where it will be when the orb arrives (orb_speed 750); through= counts killable creeps on the way.
		local okSpare, spare = pcall(
			EscapeRules.SpareManaOrb,
			bot:GetMana(),
			bot:GetMaxMana(),
			bot:GetManaRegen(),
			illusoryOrbAbility:GetManaCost(),
			waningRiftAbility:GetManaCost(),
			illusoryOrbAbility:GetCooldown()
		)
		if okSpare and spare and not Fu.IsRetreating(bot) then
			local target, targetDist = nil, 1100
			for _, enemyHero in pairs(nearbyEnemyHeroes or {}) do
				if
					Fu.IsValidHero(enemyHero)
					and Fu.CanCastOnNonMagicImmune(enemyHero)
					and not Fu.IsSuspiciousIllusion(enemyHero)
					and GetUnitToUnitDistance(bot, enemyHero) < targetDist
				then
					target, targetDist = enemyHero, GetUnitToUnitDistance(bot, enemyHero)
				end
			end
			if target ~= nil and #(target:GetNearbyTowers(700, false) or {}) == 0 then
				local orbSpeed = illusoryOrbAbility:GetSpecialValueInt("orb_speed")
				if orbSpeed == nil or orbSpeed <= 0 then
					orbSpeed = 750
				end
				local aim = target:GetExtrapolatedLocation(castPoint + targetDist / orbSpeed)
				local through = 0
				for _, creep in pairs(killableCreeps) do
					local lineInfo = PointToLineDistance(bot:GetLocation(), aim, creep:GetLocation())
					if lineInfo ~= nil and lineInfo.within and lineInfo.distance <= radius then
						through = through + 1
					end
				end
				pcall(
					print,
					string.format(
						"[OHA-PUCK] t=%.0f orb-harass target=%s dist=%d mana=%.2f regen=%.1f through=%d",
						DotaTime(),
						(string.gsub(target:GetUnitName(), "npc_dota_hero_", "")),
						targetDist,
						Fu.GetMP(bot),
						bot:GetManaRegen(),
						through
					)
				)
				return BOT_ACTION_DESIRE_HIGH, aim
			end
		end
	end
	if Fu.IsDoingRoshan(bot) then
		if
			Fu.IsRoshan(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, 500)
			and isAttacking
		then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, 400) and isAttacking then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.ConsiderWaningRift()
	if not waningRiftAbility:IsFullyCastable() or bot:HasModifier("modifier_puck_phase_shift") then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local castPoint = waningRiftAbility:GetCastPoint()
	local radius = waningRiftAbility:GetSpecialValueInt("radius")
	-- Game files: Puck moves up to max_distance (350, +350 talent) and hits radius (400) around where she lands.
	local moveDistance = waningRiftAbility:GetSpecialValueInt("max_distance")
	if moveDistance == nil or moveDistance <= 0 then
		moveDistance = 350
	end
	local reach = moveDistance + radius
	local damage = waningRiftAbility:GetSpecialValueInt("damage")
	botTarget = Fu.GetProperTarget(bot)
	X.riftWhy = "kill"
	local nearbyEnemies = Fu.GetNearbyHeroes(bot, reach, true, BOT_MODE_NONE)
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and Fu.CanKillTarget(enemyHero, damage, DAMAGE_TYPE_MAGICAL)
			and not Fu.IsSuspiciousIllusion(enemyHero)
			and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
			and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
			and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
			and not enemyHero:HasModifier("modifier_templar_assassin_refraction_absorb")
		then
			return BOT_ACTION_DESIRE_HIGH, enemyHero:GetLocation()
		end
	end
	X.riftWhy = "stuck"
	if Fu.IsStuck(bot) then
		local escapeLocation = Fu.GetEscapeLoc()
		return BOT_ACTION_DESIRE_HIGH, Fu.Site.GetXUnitsTowardsLocation(bot, escapeLocation, moveDistance)
	end
	-- Silence a group, or a channelling hero, from where she lands (game files: radius 400 around the landing
	-- point, max_distance 350): the best point for 2+ heroes within max_distance of Puck.
	if (isGoingOnSomeone or Fu.IsInTeamFight(bot, 1200)) and mpRatio > 0.25 then
		local aoe = bot:FindAoELocation(true, true, bot:GetLocation(), moveDistance, radius - 50, castPoint, 0)
		if aoe ~= nil and aoe.count >= 2 and #Fu.GetEnemiesNearLoc(aoe.targetloc, radius - 50) >= 2 then
			X.riftWhy = "group"
			return BOT_ACTION_DESIRE_HIGH, aoe.targetloc
		end
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				Fu.IsValidHero(enemyHero)
				and enemyHero:IsChanneling()
				and Fu.CanCastOnNonMagicImmune(enemyHero)
				and not Fu.IsSuspiciousIllusion(enemyHero)
			then
				X.riftWhy = "channel"
				return BOT_ACTION_DESIRE_HIGH, enemyHero:GetLocation()
			end
		end
	end
	X.riftWhy = "target"
	if isGoingOnSomeone then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, 1200, false, BOT_MODE_NONE)
		if
			Fu.IsValidTarget(botTarget)
			and Fu.CanCastOnNonMagicImmune(botTarget)
			and Fu.IsInRange(bot, botTarget, reach)
			and not Fu.IsSuspiciousIllusion(botTarget)
			and not botTarget:HasModifier("modifier_necrolyte_reapers_scythe")
			and not botTarget:HasModifier("modifier_templar_assassin_refraction_absorb")
		then
			local targetAllies = Fu.GetNearbyHeroes(botTarget, 1200, false, BOT_MODE_NONE)
			if nearbyAllies ~= nil and targetAllies ~= nil and #nearbyAllies >= #targetAllies then
				return BOT_ACTION_DESIRE_HIGH, botTarget:GetExtrapolatedLocation(castPoint)
			end
		end
	end
	X.riftWhy = "escape"
	if isRetreating then
		-- An escape jump needs someone to escape from (game 050, 14:06: she jumped 349 with no enemy in sight,
		-- still in retreat mode from a fight 30s before): an enemy hero chasing her within 600, and she was hit in
		-- the last 2s or a stun is flying at her.
		local hitNow = bot:WasRecentlyDamagedByAnyHero(2) or Fu.IsStunProjectileIncoming(bot, 600)
		for _, enemyHero in pairs(Fu.GetNearbyHeroes(bot, 600, true, BOT_MODE_NONE) or {}) do
			if
				hitNow
				and Fu.IsValidHero(enemyHero)
				and not Fu.IsSuspiciousIllusion(enemyHero)
				and not Fu.IsDisabled(enemyHero)
				and Fu.IsChasingTarget(enemyHero, bot)
			then
				local escapePoint = X.EscapePoint(moveDistance)
				X.LogEscapeAction("rift", "escape", escapePoint)
				return BOT_ACTION_DESIRE_HIGH, escapePoint
			end
		end
	end
	-- Rift moves Puck to the point (game 050, 46:19: a creep-clear Rift put her back on a wave she was walking
	-- away from). Creep clears only on a point she is facing.
	X.riftWhy = "push"
	if Fu.IsPushing(bot) or Fu.IsDefending(bot) then
		local aoeLocation =
			bot:FindAoELocation(true, false, bot:GetLocation(), bot:GetAttackRange() + 150, radius, 0, 0)
		local laneCreeps = bot:GetNearbyLaneCreeps(radius, true)
		if
			laneCreeps ~= nil
			and #laneCreeps >= 4
			and aoeLocation.count >= 4
			and bot:IsFacingLocation(aoeLocation.targetloc, 60)
		then
			return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
		end
	end
	X.riftWhy = "farm"
	if Fu.IsFarming(bot) then
		local aoeLocation =
			bot:FindAoELocation(true, false, bot:GetLocation(), bot:GetAttackRange() + 150, radius, 0, 0)
		if isAttacking and bot:IsFacingLocation(aoeLocation.targetloc, 60) then
			local neutralCreeps = bot:GetNearbyNeutralCreeps(radius)
			if
				neutralCreeps ~= nil
				and (
					#neutralCreeps >= 3 and aoeLocation.count >= 3
					or #neutralCreeps >= 2 and neutralCreeps[1]:IsAncientCreep() and aoeLocation.count >= 2
				)
			then
				return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
			end
			local laneCreeps = bot:GetNearbyLaneCreeps(radius, true)
			if laneCreeps ~= nil and #laneCreeps >= 3 and aoeLocation.count >= 3 then
				return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
			end
		end
	end
	X.riftWhy = "lane"
	if Fu.IsLaning(bot) then
		local killableCreepCount = 0
		local killableCreeps = {}
		local laneCreeps = bot:GetNearbyLaneCreeps(radius, true)
		local nearbyEnemyHeroes = Fu.GetNearbyHeroes(bot, 1000, true, BOT_MODE_NONE)
		for _, creep in pairs(laneCreeps) do
			if Fu.IsValid(creep) and creep:GetHealth() <= damage then
				killableCreepCount = killableCreepCount + 1
				table.insert(killableCreeps, creep)
			end
		end
		if killableCreepCount >= 2 and mpRatio > 0.25 and nearbyEnemyHeroes ~= nil and #nearbyEnemyHeroes >= 1 then
			return BOT_ACTION_DESIRE_HIGH, bot:GetLocation()
		end
	end
	X.riftWhy = "roshan"
	if Fu.IsDoingRoshan(bot) then
		if Fu.IsRoshan(botTarget) and Fu.IsInRange(bot, botTarget, 500) and isAttacking then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	if Fu.IsDoingTormentor(bot) then
		if Fu.IsTormentor(botTarget) and Fu.IsInRange(bot, botTarget, 400) and isAttacking then
			return BOT_ACTION_DESIRE_HIGH, botTarget:GetLocation()
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.ConsiderPhaseShift()
	X.phaseWhy = "hero"
	if not phaseShiftAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
	end
	-- datafeed: Phase Shift duration is fractional (1/1.75/2.5/3.25s).
	local duration = phaseShiftAbility:GetSpecialValueFloat("duration")
	if Fu.IsStunProjectileIncoming(bot, 600) then
		X.phaseWhy = "dodge-stun"
		return BOT_ACTION_DESIRE_HIGH
	end
	-- Spirit Siphon draining her (X.ConsiderSiphonEscape threw the orb first when it could): the shift blocks the
	-- drain, then the Jaunt or a walk breaks the link.
	if
		X.SiphonSource() ~= nil
		and bot:WasRecentlyDamagedByAnyHero(1.0)
		and (Fu.GetHP(bot) < 0.7 or Fu.IsRetreating(bot))
	then
		X.phaseWhy = "siphon"
		return BOT_ACTION_DESIRE_HIGH
	end
	if Fu.IsUnitTargetProjectileIncoming(bot, 400) then
		X.phaseWhy = "dodge-projectile"
		return BOT_ACTION_DESIRE_HIGH
	end
	if not bot:HasModifier("modifier_sniper_assassinate") and not bot:IsMagicImmune() then
		if Fu.IsWillBeCastUnitTargetSpell(bot, 400) then
			X.phaseWhy = "dodge-will-cast"
			return BOT_ACTION_DESIRE_HIGH
		end
	end
	-- Roshan on her under 40% HP (game 050, 29:49-29:53: she died to Roshan from 58% with Phase Shift unused; every
	-- rule above reacts to heroes). The shift drops his attack; she walks out after it.
	local roshanHandle = Fu.Utils.GameStates and Fu.Utils.GameStates.roshHandle
	if
		Fu.GetHP(bot) < 0.4
		and roshanHandle ~= nil
		and not roshanHandle:IsNull()
		and roshanHandle:IsAlive()
		and roshanHandle:GetAttackTarget() == bot
	then
		X.phaseWhy = "roshan"
		return BOT_ACTION_DESIRE_HIGH
	end
	if isRetreating then
		-- Phase only to wait out a short blink lockout (damage puts Blink on a 3s cooldown) with an enemy
		-- near: a READY blink (cooldown 0) also passed "< duration", so Puck stood in Phase Shift
		-- instead of blinking away. The build buys Overwhelming Blink, so look for it too.
		local blinkSlot = bot:FindItemSlot("item_blink")
		if blinkSlot < 0 then
			blinkSlot = bot:FindItemSlot("item_overwhelming_blink")
		end
		local blinkItem = blinkSlot >= 0 and blinkSlot <= 5 and bot:GetItemInSlot(blinkSlot) or nil
		if
			blinkItem ~= nil
			and blinkItem:GetCooldownTimeRemaining() > 0
			and blinkItem:GetCooldownTimeRemaining() < duration
			and bot:WasRecentlyDamagedByAnyHero(1.0)
		then
			return BOT_ACTION_DESIRE_HIGH
		end
		local linearProjectiles = GetLinearProjectiles()
		for _, projectile in pairs(linearProjectiles) do
			-- ability can be nil on a linear projectile (hero_ancient_apparition guards it too)
			if
				projectile ~= nil
				and projectile.ability ~= nil
				and projectile.ability:GetName() == "puck_illusory_orb"
			then
				if GetUnitToLocationDistance(bot, projectile.location) < 300 then
					return BOT_ACTION_DESIRE_HIGH
				end
			end
		end
	end
	local nearbyEnemies = Fu.GetEnemiesNearLoc(bot:GetLocation(), 800)
	local nearbyAllies = Fu.GetNearbyHeroes(bot, 800, false, BOT_MODE_NONE)
	if
		nearbyEnemies ~= nil
		and #nearbyEnemies >= 2
		and nearbyAllies ~= nil
		and #nearbyEnemies > #nearbyAllies
		and bot:WasRecentlyDamagedByAnyHero(1.5)
	then
		return BOT_ACTION_DESIRE_HIGH
	end
	return BOT_ACTION_DESIRE_NONE
end
function X.ConsiderEtherealJaunt()
	if not etherealJauntAbility:IsFullyCastable() then
		return BOT_ACTION_DESIRE_NONE
	end
	local attackRange = bot:GetAttackRange()
	botTarget = Fu.GetProperTarget(bot)
	if isGoingOnSomeone then
		if Fu.IsValidTarget(botTarget) and not Fu.IsInRange(bot, botTarget, attackRange) then
			local linearProjectiles = GetLinearProjectiles()
			local targetAllies = Fu.GetNearbyHeroes(botTarget, 1200, false, BOT_MODE_NONE)
			local targetEnemies = Fu.GetNearbyHeroes(botTarget, 1200, true, BOT_MODE_NONE)
			if targetEnemies ~= nil and targetAllies ~= nil and #targetEnemies >= #targetAllies then
				local targetTowers = botTarget:GetNearbyTowers(700, false)
				for _, projectile in pairs(linearProjectiles) do
					if
						projectile ~= nil
						and projectile.ability ~= nil
						and projectile.ability:GetName() == "puck_illusory_orb"
						and not Fu.IsLocationInChrono(projectile.location)
					then
						if Fu.IsInLaningPhase() then
							if targetTowers ~= nil and #targetTowers == 0 then
								if GetUnitToLocationDistance(botTarget, projectile.location) < attackRange * 1.15 then
									return BOT_ACTION_DESIRE_HIGH
								end
							end
						else
							if GetUnitToLocationDistance(botTarget, projectile.location) < attackRange * 1.15 then
								local alliesNearOrb = Fu.GetAlliesNearLoc(projectile.location, 700)
								local enemiesNearOrb = Fu.GetEnemiesNearLoc(projectile.location, 700)
								if #alliesNearOrb >= #enemiesNearOrb then
									if
										#alliesNearOrb <= 1
										and #enemiesNearOrb == 1
										and targetTowers ~= nil
										and #targetTowers == 0
									then
										-- was "#targetAllies == 0", never true (the target counts itself);
										-- the laning branch above checks the towers the same way.
										X.LogJaunt("solo-no-tower", botTarget)
										return BOT_ACTION_DESIRE_HIGH
									end
									if #alliesNearOrb >= 2 then
										return BOT_ACTION_DESIRE_HIGH
									end
								end
							end
						end
					end
				end
			end
		end
	end
	if isRetreating and isOrbEscaping then
		local linearProjectiles = GetLinearProjectiles()
		for _, projectile in pairs(linearProjectiles) do
			if
				projectile ~= nil
				and projectile.ability ~= nil
				and projectile.ability:GetName() == "puck_illusory_orb"
				and not Fu.IsLocationInChrono(projectile.location)
			then
				if GetUnitToLocationDistance(bot, projectile.location) > 600 then
					return BOT_ACTION_DESIRE_HIGH
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE
end
-- [OHA-PUCK] Jaunt to the orb onto a lone target with no tower near it, at most once per 10s.
function X.LogJaunt(reason, target)
	if DotaTime() < (bot._jauntLogAt or -999) then
		return
	end
	bot._jauntLogAt = DotaTime() + 10
	pcall(
		print,
		string.format(
			"[OHA-PUCK] t=%.0f jaunt why=%s target=%s hp=%.2f",
			DotaTime(),
			reason,
			(string.gsub(target:GetUnitName(), "npc_dota_hero_", "")),
			Fu.GetHP(target)
		)
	)
end
-- [OHA-PUCK] pick-off Dream Coil on a lone target, at most once per 10s.
function X.LogCoil(reason, target)
	if DotaTime() < (bot._coilLogAt or -999) then
		return
	end
	bot._coilLogAt = DotaTime() + 10
	pcall(
		print,
		string.format(
			"[OHA-PUCK] t=%.0f coil why=%s target=%s hp=%.2f",
			DotaTime(),
			reason,
			(string.gsub(target:GetUnitName(), "npc_dota_hero_", "")),
			Fu.GetHP(target)
		)
	)
end
function X.ConsiderDreamCoil()
	if not dreamCoilAbility:IsFullyCastable() or bot:HasModifier("modifier_puck_phase_shift") then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local castRange = Fu.GetProperCastRange(false, bot, dreamCoilAbility:GetCastRange())
	local radius = dreamCoilAbility:GetSpecialValueInt("coil_radius")
	local duration = dreamCoilAbility:GetSpecialValueInt("coil_duration")
	if Fu.IsInTeamFight(bot, 1200) then
		local aoeLocation = bot:FindAoELocation(true, true, bot:GetLocation(), castRange, radius, 0, 0)
		local enemiesInRadius = Fu.GetEnemiesNearLoc(aoeLocation.targetloc, radius)
		if
			enemiesInRadius ~= nil
			and #enemiesInRadius >= 2
			and not Fu.IsLocationInChrono(aoeLocation.targetloc)
			and not Fu.IsLocationInBlackHole(aoeLocation.targetloc)
		then
			return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
		end
	end
	if isGoingOnSomeone then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, 1000, false, BOT_MODE_NONE)
		local strongestTarget = Fu.GetStrongestUnit(castRange, bot, true, false, duration)
		if
			Fu.IsValidTarget(strongestTarget)
			and Fu.CanCastOnNonMagicImmune(strongestTarget)
			and not Fu.IsSuspiciousIllusion(strongestTarget)
			and not Fu.IsDisabled(strongestTarget)
			and not Fu.IsLocationInChrono(strongestTarget:GetLocation())
			and not Fu.IsLocationInBlackHole(strongestTarget:GetLocation())
			and not strongestTarget:HasModifier("modifier_abaddon_borrowed_time")
			and not strongestTarget:HasModifier("modifier_dazzle_shallow_grave")
			and not strongestTarget:HasModifier("modifier_necrolyte_reapers_scythe")
			and not strongestTarget:HasModifier("modifier_oracle_false_promise_timer")
		then
			-- enemiesNearTarget was Puck's own allies again (same list as nearbyAllies), so "#enemiesNearTarget == 0" could never hold and this
			-- pick-off coil never fired. Now it is the enemy heroes near the target (the target included):
			-- coil a lone target.
			local enemiesNearTarget = Fu.GetEnemiesNearLoc(strongestTarget:GetLocation(), 1000)
			if nearbyAllies ~= nil and enemiesNearTarget and #nearbyAllies >= #enemiesNearTarget then
				if
					#nearbyAllies == 1
					and #enemiesNearTarget <= 1
					and Fu.GetHP(strongestTarget) > 0.55
					and isAttacking
				then
					X.LogCoil("solo", strongestTarget)
					return BOT_ACTION_DESIRE_HIGH, strongestTarget:GetLocation()
				end
				if
					#nearbyAllies >= 2
					and #enemiesNearTarget <= 1
					and Fu.GetHP(strongestTarget) > 0.2
					and Fu.IsRunning(strongestTarget)
					and not strongestTarget:IsFacingLocation(bot:GetLocation(), 90)
				then
					X.LogCoil("runner", strongestTarget)
					return BOT_ACTION_DESIRE_HIGH, strongestTarget:GetLocation()
				end
			end
		end
	end
	if isRetreating then
		local nearbyAllies = Fu.GetNearbyHeroes(bot, 1000, false, BOT_MODE_NONE)
		local aoeLocation = bot:FindAoELocation(true, true, bot:GetLocation(), castRange, radius, 0, 0)
		local enemiesInRadius = Fu.GetEnemiesNearLoc(aoeLocation.targetloc, radius)
		local allyTowers = bot:GetNearbyTowers(700, false)
		if nearbyAllies ~= nil and enemiesInRadius ~= nil then
			if
				allyTowers ~= nil
				and #allyTowers == 0
				and #enemiesInRadius > #nearbyAllies
				and #enemiesInRadius >= 3
				and #nearbyAllies <= 1
				and GetUnitToLocationDistance(bot, aoeLocation.targetloc) < 700
				and GetUnitToLocationDistance(bot, GetAncient(GetTeam()):GetLocation()) > 3200
			then
				return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
local function CanDoPhaseOrb()
	if phaseShiftAbility:IsFullyCastable() and illusoryOrbAbility:IsFullyCastable() then
		local comboManaCost = phaseShiftAbility:GetManaCost() + illusoryOrbAbility:GetManaCost()
		if bot:GetMana() >= comboManaCost then
			return true
		end
	end
	return false
end
function X.ConsiderPhaseOrb()
	if CanDoPhaseOrb() then
		local castRange = Fu.GetProperCastRange(false, bot, illusoryOrbAbility:GetCastRange())
		-- datafeed: Phase Shift duration is 1/1.75/2.5/3.25s; read as a float so the Jaunt delay is not cut short.
		local phaseDuration = phaseShiftAbility:GetSpecialValueFloat("duration")
		local nearbyEnemies = Fu.GetEnemiesNearLoc(bot:GetLocation(), 800)
		local nearbyAllies = Fu.GetNearbyHeroes(bot, 800, false, BOT_MODE_NONE)
		-- Escape combo only when fleeing or hurt: without this Puck orbed away from every even 2v2+
		-- fight (it runs first, before Dream Coil) even while it was the one attacking.
		if
			nearbyEnemies ~= nil
			and #nearbyEnemies >= 2
			and nearbyAllies ~= nil
			and #nearbyEnemies >= #nearbyAllies
			and (isRetreating or Fu.GetHP(bot) < 0.4 and bot:WasRecentlyDamagedByAnyHero(2))
		then
			local escapePoint = X.EscapePoint(castRange)
			X.LogEscapeAction("phase-orb", "outnumbered", escapePoint)
			return BOT_ACTION_DESIRE_HIGH, escapePoint, phaseDuration
		end
		if isRetreating then
			local nearbyEnemyHeroes = Fu.GetNearbyHeroes(bot, 1000, true, BOT_MODE_NONE)
			if
				nearbyAllies ~= nil
				and nearbyEnemyHeroes ~= nil
				and Fu.IsValidHero(nearbyEnemyHeroes[1])
				and not Fu.IsSuspiciousIllusion(nearbyEnemyHeroes[1])
			then
				local enemyAllies = Fu.GetNearbyHeroes(nearbyEnemyHeroes[1], 1000, false, BOT_MODE_NONE)
				if enemyAllies ~= nil and #enemyAllies > #nearbyAllies then
					local escapePoint = X.EscapePoint(castRange)
					X.LogEscapeAction("phase-orb", "retreat", escapePoint)
					return BOT_ACTION_DESIRE_HIGH, escapePoint, phaseDuration
				end
			end
		end
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
return X
