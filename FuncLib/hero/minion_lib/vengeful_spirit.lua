-- Thinking for summoned units: vengeful spirit.
local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
local MinionUtils = require(GetScriptDirectory() .. "/FuncLib/hero/minion_lib/utils")
local Illusions = require(GetScriptDirectory() .. "/FuncLib/hero/minion_lib/illusions")
local IllusionRules = require(GetScriptDirectory() .. "/FuncLib/systems/illusion_rules")
local X = {}
local bot
local nearbyAllies, nearbyEnemies
-- Modifiers of the Scepter death illusion (Vengeance Aura, "strong illusion"). The names are the
-- modifier_vengefulspirit_* strings in the installed game's server.dll (7.42, read 2026-11-21); which of them sits on
-- the illusion is not confirmed yet: the [OHA-ILLUSION] line says via=modifier or via=owner-dead.
local DEATH_ILLUSION_MODIFIERS = {
	"modifier_vengefulspirit_hybrid_special",
	"modifier_vengefulspirit_command_aura_illusion",
	"modifier_vengefulspirit_hybrid_xp_earn",
}
local function HasDeathModifier(minion)
	for _, name in ipairs(DEATH_ILLUSION_MODIFIERS) do
		if minion:HasModifier(name) then
			return true
		end
	end
	return false
end
-- Did the illusion start the cast it was ordered: cast phase, channel, or the spell went on cooldown. Not
-- IsUsingAbility: it may already be true for an order that is only queued, and then every order would read as started.
local function CastStarted(minion, ability)
	if minion:IsCastingAbility() or minion:IsChanneling() then
		return true
	end
	return ability ~= nil
		and not ability:IsNull()
		and (ability:IsInAbilityPhase() or (ability:GetCooldownTimeRemaining() or 0) > 0)
end
local function ShortName(unit)
	if unit == nil or unit:IsNull() then
		return "none"
	end
	return (string.gsub(string.gsub(unit:GetUnitName(), "^npc_dota_hero_", ""), "^npc_dota_", ""))
end
-- What Illusions.Think did this think, from the fields it sets: attack, move (to a fight / lane / the hero) or idle.
local function ThinkResult(minion)
	if minion.attack_desire ~= nil and minion.attack_desire > 0 and MinionUtils.IsValidTarget(minion.attack_target) then
		return ShortName(minion.attack_target), "attack"
	end
	if minion.move_desire ~= nil and minion.move_desire > 0 then
		return "none", "move"
	end
	return "none", "no-target"
end
-- [OHA-ILLUSION] t= vengefulspirit illusion kind= via= cast= attack=<target|none> why= owner-alive= spells= (#48,
-- game 066). At most once per 5s per illusion, or when kind / cast / why changes.
local function LogIllusion(minion, kind, via, cast, attack, why, ownerAlive)
	local key = kind .. "|" .. cast .. "|" .. why
	if DotaTime() < (minion._vsLogAt or -999) and key == minion._vsLogKey then
		return
	end
	minion._vsLogAt = DotaTime() + 5
	minion._vsLogKey = key
	pcall(
		print,
		string.format(
			"[OHA-ILLUSION] t=%.0f vengefulspirit illusion kind=%s via=%s cast=%s attack=%s why=%s owner-alive=%s spells=%s hp=%.2f",
			DotaTime(),
			kind,
			via,
			cast,
			attack,
			why,
			tostring(ownerAlive),
			minion._vsSpellsOff and "off" or "on",
			Fu.GetHP(minion)
		)
	)
end
-- Only a cast that can start now: the target inside cast range (+50), so a cast that doesn't start within the timeout
-- means the illusion can't cast, not that it is still walking to range (Magic Missile's strongest-target pick has no
-- range check of its own).
local function InCastRange(minion, ability, target, isLocation)
	local range = (ability:GetCastRange() or 0) + 50
	if isLocation then
		return GetUnitToLocationDistance(minion, target) <= range
	end
	return GetUnitToUnitDistance(minion, target) <= range
end
-- Spells for the death illusion: the ability it was ordered to cast, or nil. Abilities by name: the old code indexed
-- minion.abilities[6] for Nether Swap, but MinionUtils.InitiateAbility packs the castable slots with no gaps, so
-- abilities[6] is nil. Game 066 t=2101.5: "[OHA-ERROR] ... MinionThink: ...vengeful_spirit.lua:32: attempt to index
-- a nil value" on every think, after the Missile / Wave checks and before Illusions.Think: her illusions cast but
-- never attacked.
local function ConsiderSpells(minion)
	local missile = minion:GetAbilityByName("vengefulspirit_magic_missile")
	if missile ~= nil and not missile:IsNull() then
		local desire, target = X.ConsiderMagicMissile(minion, missile)
		if desire > 0 and target ~= nil and InCastRange(minion, missile, target) then
			minion:Action_UseAbilityOnEntity(missile, target)
			return missile
		end
	end
	local wave = minion:GetAbilityByName("vengefulspirit_wave_of_terror")
	if wave ~= nil and not wave:IsNull() then
		local desire, location = X.ConsiderWaveOfTerror(minion, wave)
		if desire > 0 and location ~= nil and location ~= 0 and InCastRange(minion, wave, location, true) then
			minion:Action_UseAbilityOnLocation(wave, location)
			return wave
		end
	end
	local swap = minion:GetAbilityByName("vengefulspirit_nether_swap")
	if swap ~= nil and not swap:IsNull() then
		local desire, target = X.ConsiderNetherSwap(minion, swap)
		if desire > 0 and target ~= nil and InCastRange(minion, swap, target) then
			minion:Action_UseAbilityOnEntity(swap, target)
			return swap
		end
	end
	return nil
end
-- Every Vengeful Spirit illusion comes here (FuncLib/hero/minion.lua). Game 066: her Scepter death illusion (40:08)
-- and her Manta illusions (44:00) stood without attacking. Besides the nil abilities[6] above, this returned at once
-- when Fu.CanNotUseAbility was true (also with a queued action or silenced), and returned after every cast order.
-- Now only the death illusion tries spells, a cast that didn't start within IllusionRules.CAST_START_TIMEOUT turns
-- them off for that illusion, and every other think goes to Illusions.Think (attack / move) unless a cast is
-- starting.
function X.Think(ownerBot, minion)
	bot = ownerBot
	if not MinionUtils.IsValidUnit(minion) then
		return
	end
	local now = DotaTime()
	local ownerAlive = bot ~= nil and bot:IsAlive()
	local kind, via = IllusionRules.Kind(HasDeathModifier(minion), ownerAlive)
	local cast = "-"
	local pending = minion._vsCast
	if pending ~= nil then
		local outcome = IllusionRules.CastOutcome(now - pending.at, CastStarted(minion, pending.ability))
		if outcome == "pending" then
			-- Give the order its time; an attack order now would cancel it.
			LogIllusion(minion, kind, via, "wait:" .. pending.name, "none", "casting", ownerAlive)
			return
		end
		minion._vsCast = nil
		if outcome == "failed" then
			minion._vsSpellsOff = true
		end
		cast = outcome .. ":" .. pending.name
	end
	if kind == "death" and not minion._vsSpellsOff and not Fu.CanNotUseAbility(minion) then
		nearbyAllies = minion:GetNearbyHeroes(1600, false, BOT_MODE_NONE) or {}
		nearbyEnemies = minion:GetNearbyHeroes(1600, true, BOT_MODE_NONE) or {}
		local ordered = ConsiderSpells(minion)
		if ordered ~= nil then
			local name = string.gsub(ordered:GetName(), "^vengefulspirit_", "")
			minion._vsCast = { at = now, ability = ordered, name = name }
			LogIllusion(minion, kind, via, "order:" .. name, "none", "cast-order", ownerAlive)
			return
		end
	end
	-- A cast under way (cast point or channel): leave it.
	if minion:IsCastingAbility() or minion:IsChanneling() then
		LogIllusion(minion, kind, via, cast, "none", "casting", ownerAlive)
		return
	end
	Illusions.Think(bot, minion)
	local attack, why = ThinkResult(minion)
	LogIllusion(minion, kind, via, cast, attack, why, ownerAlive)
end
function X.ConsiderMagicMissile(minion, ability)
	if not Fu.CanCastAbility(ability) then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castRange = Fu.GetProperCastRange(false, minion, ability:GetCastRange())
	local damage = ability:GetSpecialValueInt("magic_missile_damage")
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and Fu.CanCastOnTargetAdvanced(enemyHero)
		then
			if enemyHero:IsChanneling() and Fu.IsInRange(minion, enemyHero, castRange + 300) then
				return BOT_ACTION_DESIRE_HIGH, enemyHero
			end
			if
				Fu.CanKillTarget(enemyHero, damage, DAMAGE_TYPE_MAGICAL)
				and Fu.IsInRange(minion, enemyHero, castRange + 150)
				and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
				and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
				and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
				and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
			then
				return BOT_ACTION_DESIRE_HIGH, enemyHero
			end
		end
	end
	for _, allyHero in pairs(nearbyAllies) do
		if
			Fu.IsValidHero(allyHero)
			and Fu.IsRetreating(allyHero)
			and allyHero:WasRecentlyDamagedByAnyHero(3.0)
			and not allyHero:IsIllusion()
		then
			local allyNearbyEnemies = allyHero:GetNearbyHeroes(1600, true, BOT_MODE_NONE)
			if
				Fu.IsValidHero(allyNearbyEnemies[1])
				and Fu.CanCastOnNonMagicImmune(allyNearbyEnemies[1])
				and Fu.CanCastOnTargetAdvanced(allyNearbyEnemies[1])
				and Fu.IsInRange(minion, allyNearbyEnemies[1], castRange)
				and Fu.IsChasingTarget(allyNearbyEnemies[1], allyHero)
				and not Fu.IsDisabled(allyNearbyEnemies[1])
				and not allyNearbyEnemies[1]:HasModifier("modifier_legion_commander_duel")
				and not allyNearbyEnemies[1]:HasModifier("modifier_enigma_black_hole_pull")
				and not allyNearbyEnemies[1]:HasModifier("modifier_faceless_void_chronosphere_freeze")
				and not allyNearbyEnemies[1]:HasModifier("modifier_necrolyte_reapers_scythe")
			then
				return BOT_ACTION_DESIRE_HIGH, allyNearbyEnemies[1]
			end
		end
	end
	local strongestTarget = nil
	local maxDamage = 0
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and Fu.CanCastOnTargetAdvanced(enemyHero)
			and not Fu.IsDisabled(enemyHero)
			and not enemyHero:HasModifier("modifier_enigma_black_hole_pull")
			and not enemyHero:HasModifier("modifier_faceless_void_chronosphere_freeze")
			and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			local estimatedDamage = enemyHero:GetEstimatedDamageToTarget(false, minion, 5, DAMAGE_TYPE_ALL)
			if maxDamage < estimatedDamage then
				maxDamage = estimatedDamage
				strongestTarget = enemyHero
			end
		end
	end
	if strongestTarget ~= nil then
		return BOT_ACTION_DESIRE_HIGH, strongestTarget
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
function X.ConsiderWaveOfTerror(minion, ability)
	if not Fu.CanCastAbility(ability) then
		return BOT_ACTION_DESIRE_NONE, 0
	end
	local castRange = Fu.GetProperCastRange(false, minion, ability:GetCastRange())
	local castPoint = ability:GetCastPoint()
	local waveWidth = ability:GetSpecialValueInt("wave_width")
	local waveSpeed = ability:GetSpecialValueInt("wave_speed")
	local damage = ability:GetAbilityDamage()
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and Fu.CanKillTarget(enemyHero, damage, DAMAGE_TYPE_MAGICAL)
			and Fu.IsChasingTarget(minion, enemyHero)
			and not enemyHero:HasModifier("modifier_abaddon_borrowed_time")
			and not enemyHero:HasModifier("modifier_dazzle_shallow_grave")
			and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
			and not enemyHero:HasModifier("modifier_oracle_false_promise_timer")
		then
			local aoeLocation = minion:FindAoELocation(true, true, enemyHero:GetLocation(), waveWidth, waveWidth, 0, 0)
			if aoeLocation.count >= 2 then
				return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
			else
				local delay = GetUnitToUnitDistance(minion, enemyHero) / waveSpeed + castPoint
				return BOT_ACTION_DESIRE_HIGH, Fu.GetCorrectLoc(enemyHero, delay)
			end
		end
	end
	local strongestTarget = nil
	local maxDamage = 0
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and not Fu.IsDisabled(enemyHero)
			and not enemyHero:HasModifier("modifier_enigma_black_hole_pull")
			and not enemyHero:HasModifier("modifier_faceless_void_chronosphere_freeze")
			and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
		then
			local estimatedDamage = enemyHero:GetEstimatedDamageToTarget(false, minion, 5, DAMAGE_TYPE_ALL)
			if maxDamage < estimatedDamage then
				maxDamage = estimatedDamage
				strongestTarget = enemyHero
			end
		end
	end
	if strongestTarget ~= nil then
		local aoeLocation =
			minion:FindAoELocation(true, true, strongestTarget:GetLocation(), waveWidth, waveWidth, 0, 0)
		if aoeLocation.count >= 2 then
			return BOT_ACTION_DESIRE_HIGH, aoeLocation.targetloc
		else
			local delay = GetUnitToUnitDistance(minion, strongestTarget) / waveSpeed + castPoint
			return BOT_ACTION_DESIRE_HIGH, Fu.GetCorrectLoc(strongestTarget, delay)
		end
	end
	local nearbyLaneCreeps = minion:GetNearbyLaneCreeps(castRange, true)
	if
		#nearbyLaneCreeps >= 3
		and Fu.CanBeAttacked(nearbyLaneCreeps[1])
		and not Fu.IsRunning(nearbyLaneCreeps[1])
		and not Fu.IsThereCoreNearby(1200)
	then
		return BOT_ACTION_DESIRE_HIGH, Fu.GetCenterOfUnits(nearbyLaneCreeps)
	end
	return BOT_ACTION_DESIRE_NONE, 0
end
function X.ConsiderNetherSwap(minion, ability)
	if not Fu.CanCastAbility(ability) then
		return BOT_ACTION_DESIRE_NONE, nil
	end
	local castRange = Fu.GetProperCastRange(false, minion, ability:GetCastRange())
	for _, allyHero in pairs(nearbyAllies) do
		if
			Fu.IsValidHero(allyHero)
			and Fu.IsInRange(minion, allyHero, castRange + 300)
			and Fu.IsCore(allyHero)
			and not Fu.IsSuspiciousIllusion(allyHero)
		then
			if
				Fu.IsInTeamFight(allyHero, 1200)
				and not Fu.IsInRange(minion, allyHero, castRange)
				and MinionUtils.CantMove(allyHero)
			then
				return BOT_ACTION_DESIRE_HIGH, allyHero
			end
			if
				allyHero:HasModifier("modifier_faceless_void_chronosphere_freeze")
				or allyHero:HasModifier("modifier_enigma_black_hole_pull")
				or allyHero:HasModifier("modifier_mars_arena_of_blood_leash")
					and not minion:HasModifier("modifier_mars_arena_of_blood_leash")
			then
				return BOT_ACTION_DESIRE_HIGH, allyHero
			end
		end
	end
	local strongestTarget = nil
	local maxDamage = 0
	for _, enemyHero in pairs(nearbyEnemies) do
		if
			Fu.IsValidHero(enemyHero)
			and Fu.IsInRange(minion, enemyHero, castRange)
			and Fu.CanCastOnNonMagicImmune(enemyHero)
			and Fu.CanCastOnTargetAdvanced(enemyHero)
			and not Fu.IsInRange(minion, enemyHero, castRange / 2)
			and not Fu.IsDisabled(enemyHero)
			and not enemyHero:HasModifier("modifier_enigma_black_hole_pull")
			and not enemyHero:HasModifier("modifier_faceless_void_chronosphere_freeze")
			and not enemyHero:HasModifier("modifier_legion_commander_duel")
			and not enemyHero:HasModifier("modifier_necrolyte_reapers_scythe")
			and not enemyHero:WasRecentlyDamagedByAnyHero(2.0)
		then
			local estimatedDamage = enemyHero:GetEstimatedDamageToTarget(false, minion, 5, DAMAGE_TYPE_ALL)
			if
				#nearbyAllies >= #nearbyEnemies
				and #nearbyAllies >= 1
				and #nearbyAllies <= #nearbyEnemies + 2
				and maxDamage < estimatedDamage
			then
				maxDamage = estimatedDamage
				strongestTarget = enemyHero
			end
		end
	end
	if strongestTarget ~= nil then
		return BOT_ACTION_DESIRE_HIGH, strongestTarget
	end
	return BOT_ACTION_DESIRE_NONE, nil
end
return X
