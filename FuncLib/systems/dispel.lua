-- Shared bot system: dispel.
local function objectEntries(object)
	local result = {}
	local count = 0
	for key in pairs(object) do
		count = count + 1
		result[count] = { key, object[key] }
	end
	return result
end
local createSymbol, Symbol
do
	local symbolMetatable = {
		__tostring = function(self)
			return ("Symbol(" .. (self.description or "")) .. ")"
		end,
	}
	function createSymbol(description)
		return setmetatable({ description = description }, symbolMetatable)
	end
	Symbol = {
		asyncDispose = createSymbol("Symbol.asyncDispose"),
		dispose = createSymbol("Symbol.dispose"),
		iterator = createSymbol("Symbol.iterator"),
		hasInstance = createSymbol("Symbol.hasInstance"),
		species = createSymbol("Symbol.species"),
		toStringTag = createSymbol("Symbol.toStringTag"),
	}
end
local iterate
do
	local function iteratorGeneratorStep(self)
		local coroutineObject = self.____coroutine
		local ok, value = coroutine.resume(coroutineObject)
		if not ok then
			error(value, 0)
		end
		if coroutine.status(coroutineObject) == "dead" then
			return
		end
		return true, value
	end
	local function iteratorIteratorStep(self)
		local result = self:next()
		if result.done then
			return
		end
		return true, result.value
	end
	local function iteratorStringStep(self, index)
		index = index + 1
		if index > #self then
			return
		end
		return index, string.sub(self, index, index)
	end
	function iterate(iterable)
		if type(iterable) == "string" then
			return iteratorStringStep, iterable, 0
		elseif iterable.____coroutine ~= nil then
			return iteratorGeneratorStep, iterable
		elseif iterable[Symbol.iterator] then
			local iterator = iterable[Symbol.iterator](iterable)
			return iteratorIteratorStep, iterator
		else
			return ipairs(iterable)
		end
	end
end
local Dispel = {}
local Dota = require(GetScriptDirectory() .. "/FuncLib/dota/index")
local BotMode = Dota.BotMode
local debuffInfo = {
	modifier_stunned = {
		severity = 9,
		isDisable = true,
		isSilence = false,
		isRoot = false,
		isDot = false,
		isArmor = false,
		basicDispel = false,
		strongDispel = true,
	},
	modifier_bashed = {
		severity = 9,
		isDisable = true,
		isSilence = false,
		isRoot = false,
		isDot = false,
		isArmor = false,
		basicDispel = false,
		strongDispel = true,
	},
	modifier_sheepstick_debuff = {
		severity = 9,
		isDisable = true,
		isSilence = false,
		isRoot = false,
		isDot = false,
		isArmor = false,
		basicDispel = false,
		strongDispel = true,
	},
	modifier_lion_voodoo = {
		severity = 9,
		isDisable = true,
		isSilence = false,
		isRoot = false,
		isDot = false,
		isArmor = false,
		basicDispel = false,
		strongDispel = true,
	},
	modifier_shadow_shaman_voodoo = {
		severity = 9,
		isDisable = true,
		isSilence = false,
		isRoot = false,
		isDot = false,
		isArmor = false,
		basicDispel = false,
		strongDispel = true,
	},
	modifier_bane_nightmare = {
		severity = 8,
		isDisable = true,
		isSilence = false,
		isRoot = false,
		isDot = false,
		isArmor = false,
		basicDispel = false,
		strongDispel = true,
	},
	modifier_doom_bringer_doom = {
		severity = 10,
		isDisable = false,
		isSilence = true,
		isRoot = false,
		isDot = true,
		isArmor = false,
		basicDispel = false,
		strongDispel = true,
	},
	modifier_orchid_malevolence_debuff = {
		severity = 7,
		isDisable = false,
		isSilence = true,
		isRoot = false,
		isDot = false,
		isArmor = false,
		basicDispel = true,
		strongDispel = true,
	},
	modifier_bloodthorn_debuff = {
		severity = 8,
		isDisable = false,
		isSilence = true,
		isRoot = false,
		isDot = false,
		isArmor = false,
		basicDispel = true,
		strongDispel = true,
	},
	modifier_silencer_last_word = {
		severity = 6,
		isDisable = false,
		isSilence = true,
		isRoot = false,
		isDot = false,
		isArmor = false,
		basicDispel = true,
		strongDispel = true,
	},
	modifier_skywrath_mage_ancient_seal = {
		severity = 7,
		isDisable = false,
		isSilence = true,
		isRoot = false,
		isDot = false,
		isArmor = false,
		basicDispel = true,
		strongDispel = true,
	},
	modifier_death_prophet_silence = {
		severity = 6,
		isDisable = false,
		isSilence = true,
		isRoot = false,
		isDot = false,
		isArmor = false,
		basicDispel = true,
		strongDispel = true,
	},
	modifier_night_stalker_crippling_fear = {
		severity = 6,
		isDisable = false,
		isSilence = true,
		isRoot = false,
		isDot = false,
		isArmor = false,
		basicDispel = true,
		strongDispel = true,
	},
	modifier_riki_smoke_screen = {
		severity = 6,
		isDisable = false,
		isSilence = true,
		isRoot = false,
		isDot = false,
		isArmor = false,
		basicDispel = false,
		strongDispel = false,
	},
	modifier_disruptor_static_storm = {
		severity = 7,
		isDisable = false,
		isSilence = true,
		isRoot = false,
		isDot = true,
		isArmor = false,
		basicDispel = false,
		strongDispel = false,
	},
	modifier_rod_of_atos_debuff = {
		severity = 5,
		isDisable = false,
		isSilence = false,
		isRoot = true,
		isDot = false,
		isArmor = false,
		basicDispel = true,
		strongDispel = true,
	},
	modifier_crystal_maiden_frostbite = {
		severity = 5,
		isDisable = false,
		isSilence = false,
		isRoot = true,
		isDot = true,
		isArmor = false,
		basicDispel = false,
		strongDispel = true,
	},
	modifier_treant_overgrowth = {
		severity = 6,
		isDisable = false,
		isSilence = false,
		isRoot = true,
		isDot = false,
		isArmor = false,
		basicDispel = false,
		strongDispel = true,
	},
	modifier_slardar_amplify_damage = {
		severity = 5,
		isDisable = false,
		isSilence = false,
		isRoot = false,
		isDot = false,
		isArmor = true,
		basicDispel = true,
		strongDispel = true,
	},
	modifier_bounty_hunter_track = {
		severity = 4,
		isDisable = false,
		isSilence = false,
		isRoot = false,
		isDot = false,
		isArmor = true,
		basicDispel = true,
		strongDispel = true,
	},
	modifier_spirit_vessel_damage = {
		severity = 5,
		isDisable = false,
		isSilence = false,
		isRoot = false,
		isDot = true,
		isArmor = false,
		basicDispel = true,
		strongDispel = true,
	},
	modifier_item_spirit_vessel_damage = {
		severity = 5,
		isDisable = false,
		isSilence = false,
		isRoot = false,
		isDot = true,
		isArmor = false,
		basicDispel = true,
		strongDispel = true,
	},
	modifier_razor_static_link_debuff = {
		severity = 5,
		isDisable = false,
		isSilence = false,
		isRoot = false,
		isDot = false,
		isArmor = true,
		basicDispel = true,
		strongDispel = true,
	},
	modifier_viper_viper_strike_slow = {
		severity = 4,
		isDisable = false,
		isSilence = false,
		isRoot = false,
		isDot = true,
		isArmor = false,
		basicDispel = true,
		strongDispel = true,
	},
	modifier_axe_battle_hunger_self = {
		severity = 3,
		isDisable = false,
		isSilence = false,
		isRoot = false,
		isDot = true,
		isArmor = false,
		basicDispel = true,
		strongDispel = true,
	},
	modifier_venomancer_venomous_gale = {
		severity = 3,
		isDisable = false,
		isSilence = false,
		isRoot = false,
		isDot = true,
		isArmor = false,
		basicDispel = true,
		strongDispel = true,
	},
	modifier_bristleback_viscous_nasal_goo = {
		severity = 2,
		isDisable = false,
		isSilence = false,
		isRoot = false,
		isDot = false,
		isArmor = true,
		basicDispel = true,
		strongDispel = true,
	},
	modifier_phoenix_fire_spirit_burn = {
		severity = 2,
		isDisable = false,
		isSilence = false,
		isRoot = false,
		isDot = true,
		isArmor = false,
		basicDispel = true,
		strongDispel = true,
	},
	modifier_earth_spirit_magnetize = {
		severity = 3,
		isDisable = false,
		isSilence = false,
		isRoot = false,
		isDot = true,
		isArmor = false,
		basicDispel = true,
		strongDispel = true,
	},
	modifier_warlock_fatal_bonds = {
		severity = 3,
		isDisable = false,
		isSilence = false,
		isRoot = false,
		isDot = false,
		isArmor = false,
		basicDispel = true,
		strongDispel = true,
	},
	modifier_life_stealer_open_wounds = {
		severity = 3,
		isDisable = false,
		isSilence = false,
		isRoot = false,
		isDot = false,
		isArmor = false,
		basicDispel = true,
		strongDispel = true,
	},
	modifier_ice_blast = {
		severity = 4,
		isDisable = false,
		isSilence = false,
		isRoot = false,
		isDot = true,
		isArmor = false,
		basicDispel = false,
		strongDispel = false,
	},
}
local strippableBuffs = {
	"modifier_ghost_state",
	"modifier_item_ghost",
	"modifier_windrunner_windrun",
	"modifier_ogre_magi_bloodlust",
	"modifier_ursa_overpower",
	"modifier_legion_commander_press_the_attack",
	"modifier_omniknight_repel",
	"modifier_haste_rune_speed",
	"modifier_double_damage",
	"modifier_ember_spirit_flame_guard",
	"modifier_abaddon_aphotic_shield",
}
local protectionModifiers = {
	"modifier_dazzle_shallow_grave",
	"modifier_oracle_false_promise_timer",
	"modifier_abaddon_borrowed_time",
	"modifier_skeleton_king_reincarnation_scepter_active",
	"modifier_item_aeon_disk_buff",
}
-- The debuff table as a list, built once (#52). AnalyzeDebuffs used to rebuild it on every call: 33 new tables per
-- bot per item think, for a table that never changes. Same entries, same order; nothing goes stale.
local debuffEntries = objectEntries(debuffInfo)
function Dispel.AnalyzeDebuffs(unit)
	local score = 0
	local worstSeverity = 0
	local hasSilence = false
	local hasDisable = false
	local hasRoot = false
	local canBasicDispel = false
	local canStrongDispel = false
	for _, entry in ipairs(debuffEntries) do
		local modifierName = entry[1]
		local info = entry[2]
		do
			local continueLoop
			repeat
				if unit:HasModifier(modifierName) then
					local remaining
					-- Was unit.GetModifierRemainingDuration(modifierName): a dot call with a modifier name
					-- ("called with 1 arguments - expected 2", game 015). The API takes the
					-- modifier index from GetModifierByName.
					remaining = 999
					local okIdx, idx = pcall(function()
						return unit:GetModifierByName(modifierName)
					end)
					if okIdx and type(idx) == "number" and idx >= 0 then
						local okDur, dur = pcall(function()
							return unit:GetModifierRemainingDuration(idx)
						end)
						if okDur and type(dur) == "number" then
							remaining = dur
						end
					end
					local remainingDuration = remaining
					if remainingDuration < 0.5 then
						continueLoop = true
						break
					end
					score = score + info.severity
					if info.severity > worstSeverity then
						worstSeverity = info.severity
					end
					if info.isSilence then
						hasSilence = true
					end
					if info.isDisable then
						hasDisable = true
					end
					if info.isRoot then
						hasRoot = true
					end
					if info.basicDispel then
						canBasicDispel = true
					end
					if info.strongDispel then
						canStrongDispel = true
					end
				end
				continueLoop = true
			until true
			if not continueLoop then
				break
			end
		end
	end
	return {
		score = score,
		worstSeverity = worstSeverity,
		hasSilence = hasSilence,
		hasDisable = hasDisable,
		hasRoot = hasRoot,
		canBasicDispel = canBasicDispel,
		canStrongDispel = canStrongDispel,
	}
end
function Dispel.IsProtected(unit)
	for _, modifierName in ipairs(protectionModifiers) do
		if unit:HasModifier(modifierName) then
			return true
		end
	end
	return false
end
local function hasReadyAbility(bot)
	do
		local slot = 0
		while slot < 6 do
			local ability = bot:GetAbilityInSlot(slot)
			if ability and ability:IsTrained() and not ability:IsPassive() and ability:IsCooldownReady() then
				return true
			end
			slot = slot + 1
		end
	end
	return false
end
-- Worth a self-dispel: humans and cores (pos 1-2) always; others not when the fight is hopeless.
-- Was bot.IsBot() / bot.GetHealth() (dot calls): "IsBot called with 0 arguments" aborted
-- ItemUsageThink every time this ran (game 014).
local func_utils = nil
local function isWorthSelfDispel(bot)
	if not bot:IsBot() then
		return true
	end
	if func_utils == nil then
		local ok, loadedModule = pcall(require, GetScriptDirectory() .. "/FuncLib/func_utils")
		func_utils = ok and loadedModule or false
	end
	local okPos, pos = pcall(function()
		return func_utils and func_utils.GetPosition(bot) or nil
	end)
	if okPos and type(pos) == "number" and pos <= 2 then
		return true
	end
	local hpRatio = bot:GetHealth() / bot:GetMaxHealth()
	local nearbyEnemies = bot:GetNearbyHeroes(1200, true, BotMode.None)
	local nearbyAllies = bot:GetNearbyHeroes(1200, false, BotMode.None)
	if hpRatio < 0.1 and nearbyEnemies and #nearbyEnemies >= 3 and (not nearbyAllies or #nearbyAllies <= 1) then
		return false
	end
	return true
end
-- Every item ShouldUseSelfDispelItem can answer with (its strong and its basic list together).
local selfDispelItems = {
	"item_black_king_bar",
	"item_satanic",
	"item_aeon_disk",
	"item_manta",
	"item_cyclone",
	"item_guardian_greaves",
	"item_lotus_orb",
}
-- Does the bot hold one of them ready to cast? The same test ShouldUseSelfDispelItem applies to each item before
-- it answers with its slot, so without one the answer is always -1.
function Dispel.HasReadySelfDispelItem(bot)
	for _, itemName in ipairs(selfDispelItems) do
		local slot = bot:FindItemSlot(itemName)
		if slot >= 0 then
			local item = bot:GetItemInSlot(slot)
			if item and item:IsFullyCastable() then
				return true
			end
		end
	end
	return false
end
function Dispel.ShouldUseSelfDispelItem(bot)
	-- Asked first (#52): this runs at the end of every item think of every bot, and without a ready item the 32
	-- HasModifier reads of AnalyzeDebuffs (plus the protection and worth checks) could only end in -1. Saves them
	-- for every bot that holds none of the seven items, or has them on cooldown; no staleness, the item is read
	-- in the same think.
	if not Dispel.HasReadySelfDispelItem(bot) then
		return -1
	end
	if Dispel.IsProtected(bot) then
		return -1
	end
	if not isWorthSelfDispel(bot) then
		return -1
	end
	local analysis = Dispel.AnalyzeDebuffs(bot)
	if analysis.score < 4 then
		return -1
	end
	if analysis.hasSilence and not analysis.hasDisable and not hasReadyAbility(bot) then
		if analysis.score < 7 then
			return -1
		end
	end
	local needsStrong = analysis.hasDisable or not analysis.canBasicDispel
	local itemNames = needsStrong
			and {
				"item_black_king_bar",
				"item_satanic",
				"item_aeon_disk",
				"item_manta",
				"item_cyclone",
				"item_guardian_greaves",
			}
		or { "item_manta", "item_cyclone", "item_guardian_greaves", "item_lotus_orb", "item_black_king_bar" }
	for _, itemName in ipairs(itemNames) do
		do
			local continueLoop
			repeat
				local slot = bot:FindItemSlot(itemName)
				if slot >= 0 then
					local item = bot:GetItemInSlot(slot)
					if item and item:IsFullyCastable() then
						if itemName == "item_black_king_bar" and analysis.worstSeverity < 6 then
							continueLoop = true
							break
						end
						if itemName == "item_cyclone" then
							local nearbyEnemies = bot:GetNearbyHeroes(900, true, BotMode.None)
							if nearbyEnemies and #nearbyEnemies >= 2 then
								continueLoop = true
								break
							end
						end
						return slot
					end
				end
				continueLoop = true
			until true
			if not continueLoop then
				break
			end
		end
	end
	return -1
end
function Dispel.ShouldUseAllyDispelItem(bot)
	local lotusSlot = bot:FindItemSlot("item_lotus_orb")
	if lotusSlot < 0 then
		return -1, nil
	end
	local lotusOrb = bot:GetItemInSlot(lotusSlot)
	if not lotusOrb or not lotusOrb:IsFullyCastable() then
		return -1, nil
	end
	local nearbyAllies = bot:GetNearbyHeroes(900, false, BotMode.None)
	if not nearbyAllies then
		return -1, nil
	end
	local bestAlly = nil
	local bestScore = 0
	for _, ally in ipairs(nearbyAllies) do
		do
			local continueLoop
			repeat
				if ally == bot or not ally:IsAlive() or Dispel.IsProtected(ally) then
					continueLoop = true
					break
				end
				local analysis = Dispel.AnalyzeDebuffs(ally)
				if analysis.score > bestScore and analysis.score >= 5 then
					bestScore = analysis.score
					bestAlly = ally
				end
				if not ally:HasModifier("modifier_item_lotus_orb_active") then
					local allyNearbyEnemies = ally:GetNearbyHeroes(800, true, BotMode.None)
					if allyNearbyEnemies ~= nil then
						for _, enemyHero in ipairs(allyNearbyEnemies) do
							if enemyHero and not enemyHero:IsNull() and enemyHero:IsAlive() then
								local enemyName = enemyHero:GetUnitName()
								if
									enemyName == "npc_dota_hero_doom_bringer"
									or enemyName == "npc_dota_hero_lion"
									or enemyName == "npc_dota_hero_lina"
									or enemyName == "npc_dota_hero_necrolyte"
									or enemyName == "npc_dota_hero_bane"
								then
									if enemyHero:IsFacingLocation(ally:GetLocation(), 30) then
										bestAlly = ally
										bestScore = 10
									end
								end
							end
						end
					end
				end
				continueLoop = true
			until true
			if not continueLoop then
				break
			end
		end
	end
	if bestAlly then
		return lotusSlot, bestAlly
	end
	return -1, nil
end
function Dispel.ShouldMantaDodge(bot)
	local mantaSlot = bot:FindItemSlot("item_manta")
	if mantaSlot < 0 then
		return -1
	end
	local manta = bot:GetItemInSlot(mantaSlot)
	if not manta or not manta:IsFullyCastable() then
		return -1
	end
	local projectiles = bot:GetIncomingTrackingProjectiles()
	if projectiles then
		for _, projectile in iterate(projectiles) do
			if projectile and projectile.is_attack == false and projectile.is_dodgeable then
				local distance = GetUnitToLocationDistance(bot, projectile.location)
				local speed = projectile.speed or 1000
				local timeToHit = distance / speed
				if timeToHit < 0.3 and timeToHit > 0.05 then
					return mantaSlot
				end
			end
		end
	end
	return -1
end
function Dispel.HasStrippableBuff(enemyHero)
	for _, modifierName in ipairs(strippableBuffs) do
		if enemyHero:HasModifier(modifierName) then
			return true
		end
	end
	return false
end
function Dispel.GetBestEnemyToPurge(bot, radius)
	local nearbyEnemies = bot:GetNearbyHeroes(radius, true, BotMode.None)
	if not nearbyEnemies then
		return nil
	end
	for _, enemyHero in ipairs(nearbyEnemies) do
		if enemyHero and not enemyHero:IsNull() and enemyHero:IsAlive() and not enemyHero:IsMagicImmune() then
			if Dispel.HasStrippableBuff(enemyHero) then
				return enemyHero
			end
		end
	end
	return nil
end
function Dispel.GetBestAllyToDispel(bot, radius, allowStrong)
	if allowStrong == nil then
		allowStrong = false
	end
	local nearbyAllies = bot:GetNearbyHeroes(radius, false, BotMode.None)
	if not nearbyAllies then
		return nil
	end
	local bestAlly = nil
	local bestScore = 0
	for _, ally in ipairs(nearbyAllies) do
		do
			local continueLoop
			repeat
				if ally == bot or not ally:IsAlive() or Dispel.IsProtected(ally) then
					continueLoop = true
					break
				end
				local analysis = Dispel.AnalyzeDebuffs(ally)
				if analysis.score < 4 then
					continueLoop = true
					break
				end
				if not allowStrong and not analysis.canBasicDispel then
					continueLoop = true
					break
				end
				if analysis.score > bestScore then
					bestScore = analysis.score
					bestAlly = ally
				end
				continueLoop = true
			until true
			if not continueLoop then
				break
			end
		end
	end
	return bestAlly
end
function Dispel.ShouldSelfDispel(bot, allowStrong)
	if Dispel.IsProtected(bot) then
		return false
	end
	local analysis = Dispel.AnalyzeDebuffs(bot)
	if allowStrong then
		return analysis.hasDisable or analysis.worstSeverity >= 9
	end
	if analysis.hasSilence and hasReadyAbility(bot) then
		return true
	end
	return analysis.score >= 5 and analysis.canBasicDispel
end
function Dispel.GetDebuffSeverity(unit)
	return Dispel.AnalyzeDebuffs(unit).score
end
function Dispel.HasDispellableDebuff(unit, minSeverity)
	if minSeverity == nil then
		minSeverity = 1
	end
	return Dispel.GetDebuffSeverity(unit) >= minSeverity
end
function Dispel.NeedsStrongDispel(unit)
	return Dispel.AnalyzeDebuffs(unit).hasDisable
end
return Dispel
