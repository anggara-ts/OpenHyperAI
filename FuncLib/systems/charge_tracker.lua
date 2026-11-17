-- [OHA-CHARGES] lines off (charges work, 1123 lines in game 029); [OHA-ERROR] still prints.
local rawPrint = print
local print = function(msg, ...)
	if type(msg) == "string" and string.find(msg, "[OHA-CHARGES]", 1, true) then
		return
	end
	return rawPrint(msg, ...)
end
-- Charge count for charge-based hero abilities, for every bot.
-- The bot API documents GetCurrentCharges for items only, and GetCurrentAbilityCharges does not
-- exist (every Techies log showed the fallback value). So the count is kept here: from the
-- restore time, our own casts, and what the API does show (not castable while free to cast means
-- 0 left). ChargeTracker.Tick runs once per think for each bot (ItemUsageThink); hero scripts read
-- ChargeTracker.Count and mark their cast orders with ChargeTracker.Issued.
--
-- Some abilities are charge-based only with Shard, Scepter or a talent. Max charges are re-read
-- each think; at 1 or less the ability is not tracked and Count returns nil.
--
-- GetCurrentCharges must not be called on abilities: the engine prints "called on an ability
-- that isn't an item!" every call (game 014). [OHA-CHARGES] probe lines print castable, cooldown
-- and GetSpecialValueInt("AbilityCharges") next to the tracked count.
local ChargeTracker = {}

-- From Valve's datafeed (2026-11-15). base: charges; shard/scepter: charges with it; talent:
-- extra charges once that talent is learned; restore/restoreShard: seconds per charge by level.
local DATA = {
	bloodseeker_rupture = { base = 0, scepter = 2 },
	broodmother_spin_web = { base = { 3, 5, 7, 9 }, restore = { 27 } },
	broodmother_sticky_snare = { base = 2, restore = { 30 } },
	clinkz_death_pact = { base = { 1, 1, 2, 2 }, restore = { 40 } },
	dark_seer_ion_shell = { base = 0, talent = { "special_bonus_unique_dark_seer_14", 2 } },
	death_prophet_spirit_siphon = { base = { 1, 2, 3, 4 }, restore = { 40 } },
	disruptor_glimpse = { base = 0, talent = { "special_bonus_unique_disruptor_4", 2 } },
	doom_bringer_devour = { base = 0, shard = 2, restoreShard = { 66 } },
	earth_spirit_stone_caller = { base = 7, restore = { 18 } },
	ember_spirit_fire_remnant = { base = 3, restore = { 35 } },
	ember_spirit_sleight_of_fist = {
		base = 0,
		talent = { "special_bonus_unique_ember_spirit_4", 2 },
		restore = { 13, 11, 9, 7 },
	},
	hoodwink_acorn_shot = { base = 0, talent = { "special_bonus_unique_hoodwink_acorn_shot_charges", 2 } },
	hoodwink_scurry = {
		base = 2,
		talent = { "special_bonus_unique_hoodwink_scurry_charges", 1 },
		restore = { 30, 24, 18, 12 },
	},
	keeper_of_the_light_radiant_bind = { base = 0, shard = 2, restoreShard = { 14 } },
	kunkka_tidebringer = { base = 0, talent = { "special_bonus_unique_kunkka_tidebringer_charges", 2 } },
	largo_catchy_lick = { base = 0, talent = { "special_bonus_unique_largo_8", 2 } },
	lich_death_charge = { base = 2, restore = { 120 }, startEmpty = true },
	lich_frost_shield = { base = 0, talent = { "special_bonus_unique_lich_4", 2 }, restore = { 30, 25, 20, 15 } },
	mirana_celestial_quiver = { base = 2, restore = { 7 } },
	mirana_leap = { base = 2, restore = { 45, 35, 25, 15 } },
	muerta_dead_shot = { base = 0, talent = { "special_bonus_unique_muerta_dead_shot_charges", 2 } },
	phantom_assassin_phantom_strike = { base = 2, restore = { 21, 18, 15, 12 } },
	rattletrap_rocket_flare = {
		base = 0,
		talent = { "special_bonus_unique_clockwerk_rocket_flare_charges", 3 },
		restore = { 20, 18, 16, 14 },
	},
	ringmaster_impalement = {
		base = 3,
		talent = { "special_bonus_unique_ringmaster_dagger_charge", 1 },
		restore = { 17 },
	},
	shadow_demon_disruption = {
		base = 0,
		talent = { "special_bonus_unique_shadow_demon_7", 2 },
		restore = { 26, 24, 22, 20 },
	},
	snapfire_firesnap_cookie = {
		base = 0,
		talent = { "special_bonus_unique_snapfire_firesnap_cookie_additional_charge", 2 },
		restore = { 21, 19, 17, 15 },
	},
	sniper_shrapnel = { base = 3, restore = { 35 } },
	techies_land_mines = { base = 3, restore = { 15 } },
	tiny_toss = { base = 0, talent = { "special_bonus_unique_tiny_2", 2 } },
	treant_eyes_in_the_forest = { base = 2, restore = { 135 } },
	ursa_earthshock = { base = 0, talent = { "special_bonus_unique_ursa_3", 2 }, restore = { 15, 13, 11, 9 } },
	void_spirit_astral_step = { base = 2, restore = { 25, 20, 15 } },
	zuus_heavenly_jump = {
		base = 0,
		talent = { "special_bonus_unique_zeus_jump_charges", 3 },
		restore = { 26, 22, 18, 14 },
	},
}

local state = {} -- [playerId][abilityName] = { n, max, nextAt, ... }
local scanAt = {} -- [playerId] = next ability rescan time
local tracked = {} -- [playerId] = { ability handles }

local function ByLevel(list, level)
	if type(list) ~= "table" then
		return list
	end
	if #list == 0 then
		return nil
	end
	return list[math.max(1, math.min(#list, level))]
end

local function Short(bot)
	return (string.gsub(bot:GetUnitName(), "npc_dota_hero_", ""))
end

local function Has(bot, methodName)
	local ok, result = pcall(function()
		return bot[methodName](bot)
	end)
	return ok and result == true
end

local function TalentLearned(bot, name)
	local ok, result = pcall(function()
		local talent = bot:GetAbilityByName(name)
		return talent ~= nil and talent:IsTrained()
	end)
	return ok and result == true
end

local function RuntimeMax(ability)
	local ok, result = pcall(function()
		return ability:GetSpecialValueInt("AbilityCharges")
	end)
	if ok and type(result) == "number" and result > 0 and result < 20 then
		return result
	end
	return 0
end

local function MaxCharges(bot, ability, chargeData)
	local level = ability:GetLevel()
	local max = ByLevel(chargeData.base, level) or 0
	local hasShard = false
	pcall(function()
		hasShard = bot:HasModifier("modifier_item_aghanims_shard")
	end)
	if chargeData.shard ~= nil and hasShard then
		max = chargeData.shard
	end
	if chargeData.scepter ~= nil and Has(bot, "HasScepter") then
		max = chargeData.scepter
	end
	if chargeData.talent ~= nil and TalentLearned(bot, chargeData.talent[1]) then
		max = max + chargeData.talent[2]
	end
	return math.max(max, RuntimeMax(ability))
end

local function RestoreTime(bot, ability, chargeData)
	local level = ability:GetLevel()
	local ok, result = pcall(function()
		return ability:GetSpecialValueFloat("AbilityChargeRestoreTime")
	end)
	if ok and type(result) == "number" and result > 0 then
		return result
	end
	local hasShard = false
	pcall(function()
		hasShard = bot:HasModifier("modifier_item_aghanims_shard")
	end)
	local tableRestore = (hasShard and ByLevel(chargeData.restoreShard, level)) or ByLevel(chargeData.restore, level)
	if tableRestore ~= nil and tableRestore > 0 then
		return tableRestore
	end
	local okCd, cooldown = pcall(function()
		return ability:GetCooldown()
	end)
	if okCd and type(cooldown) == "number" and cooldown > 0 then
		return cooldown
	end
	return 20
end

local function Log(bot, ability, chargeState, why)
	pcall(
		print,
		string.format(
			"[OHA-CHARGES] t=%.0f %s %s n=%d/%d why=%s next=%s",
			DotaTime(),
			Short(bot),
			ability:GetName(),
			chargeState.n,
			chargeState.max,
			why,
			chargeState.nextAt ~= nil and string.format("%.0f", chargeState.nextAt) or "-"
		)
	)
end

local function Spend(bot, ability, chargeState, restoreTime, why)
	chargeState.n = math.max(0, chargeState.n - 1)
	if chargeState.nextAt == nil and chargeState.n < chargeState.max then
		chargeState.nextAt = DotaTime() + restoreTime
	end
	chargeState.pending = math.max(0, (chargeState.pending or 0) - 1)
	chargeState.spentAt = DotaTime()
	Log(bot, ability, chargeState, why)
end

local function Probe(bot, ability, chargeState, castable)
	local okCd, cooldown = pcall(function()
		return ability:GetCooldownTimeRemaining()
	end)
	cooldown = okCd and type(cooldown) == "number" and cooldown or -1
	local key =
		string.format("%s|%s|%d|%d", tostring(castable), tostring(cooldown > 0), RuntimeMax(ability), chargeState.n)
	if key == chargeState.probeKey or DotaTime() < (chargeState.probeAt or -999) then
		return
	end
	chargeState.probeKey = key
	chargeState.probeAt = DotaTime() + 1
	pcall(
		print,
		string.format(
			"[OHA-CHARGES] t=%.0f %s %s probe castable=%s cd=%.1f runtimeMax=%d max=%d tracked=%d",
			DotaTime(),
			Short(bot),
			ability:GetName(),
			tostring(castable),
			cooldown,
			RuntimeMax(ability),
			chargeState.max,
			chargeState.n
		)
	)
end

local function TickAbility(bot, ability, slot)
	local chargeData = DATA[ability:GetName()]
	if chargeData == nil or not ability:IsTrained() then
		return
	end
	local name = ability:GetName()
	local now = DotaTime()
	local max = MaxCharges(bot, ability, chargeData)
	local chargeState = slot[name]
	if max <= 1 then
		slot[name] = nil
		return
	end
	local restoreTime = RestoreTime(bot, ability, chargeData)
	if chargeState == nil then
		chargeState = { n = max, max = max, inPhase = false, pending = 0 }
		if chargeData.startEmpty then
			chargeState.n = 0
			chargeState.nextAt = now + restoreTime
		end
		slot[name] = chargeState
		Log(bot, ability, chargeState, "learned")
	elseif max ~= chargeState.max then
		chargeState.max = max
		chargeState.n = math.min(chargeState.n, max)
		if chargeState.n < max and chargeState.nextAt == nil then
			chargeState.nextAt = now + restoreTime
		end
		Log(bot, ability, chargeState, "max-changed")
	end
	while chargeState.nextAt ~= nil and now >= chargeState.nextAt and chargeState.n < chargeState.max do
		chargeState.n = chargeState.n + 1
		chargeState.nextAt = chargeState.n < chargeState.max and chargeState.nextAt + restoreTime or nil
		Log(bot, ability, chargeState, "restore")
	end
	-- Casts. 1) The cast phase was seen and ended. 2) Zero cast point spells (Leap, Land Mines)
	-- have no phase to see: a cast order we issued (Issued) followed by a mana drop close to the
	-- spell's cost, or by the death of the ordered target.
	local phase = ability:IsInAbilityPhase()
	local mana = bot:GetMana()
	if chargeState.inPhase and not phase then
		Spend(bot, ability, chargeState, restoreTime, "cast")
	elseif (chargeState.pending or 0) > 0 then
		if now > (chargeState.pendingUntil or -999) then
			chargeState.pending = 0
			chargeState.pendingTarget = nil
		elseif now - (chargeState.spentAt or -999) > 0.3 then
			local cost = ability:GetManaCost()
			local drop = (chargeState.lastMana or mana) - mana
			if cost > 0 and drop >= cost * 0.75 and drop <= cost * 1.25 + 10 then
				Spend(bot, ability, chargeState, restoreTime, "cast-mana")
			elseif chargeState.pendingTarget ~= nil and not phase and not chargeState.pendingTarget:IsAlive() then
				chargeState.pendingTarget = nil
				Spend(bot, ability, chargeState, restoreTime, "cast-target-died")
			end
		end
	end
	chargeState.inPhase = phase
	chargeState.lastMana = mana
	-- Correct with what the API shows, only when the hero is free to cast and it has stayed that
	-- way for 1s (no flicker).
	local free = bot:IsAlive()
		and not phase
		and not bot:IsSilenced()
		and not bot:IsStunned()
		and not bot:IsHexed()
		and not bot:IsChanneling()
		and bot:GetMana() >= ability:GetManaCost()
	local castable = ability:IsFullyCastable()
	if free then
		if not castable and chargeState.n > 0 then
			chargeState.emptySince = chargeState.emptySince or now
			if now - chargeState.emptySince >= 1 then
				chargeState.n = 0
				if chargeState.nextAt == nil then
					chargeState.nextAt = now + restoreTime
				end
				Log(bot, ability, chargeState, "resync-empty")
			end
		else
			chargeState.emptySince = nil
			if castable and chargeState.n == 0 then
				-- A charge just came in, so the next one starts restoring now (game 014: the timer
				-- from learn time gave Sacrifice a second charge 90s early).
				chargeState.n = 1
				chargeState.nextAt = chargeState.n < chargeState.max and now + restoreTime or nil
				Log(bot, ability, chargeState, "resync-one")
			end
		end
	else
		chargeState.emptySince = nil
	end
	Probe(bot, ability, chargeState, castable)
end

-- Once per think per bot.
function ChargeTracker.Tick(bot)
	if bot == nil or not bot:IsHero() or bot:IsIllusion() then
		return
	end
	local playerId = bot:GetPlayerID()
	local now = DotaTime()
	state[playerId] = state[playerId] or {}
	if tracked[playerId] == nil or now >= (scanAt[playerId] or -999) then
		scanAt[playerId] = now + 5
		local list = {}
		for i = 0, 23 do
			local ability = bot:GetAbilityInSlot(i)
			if ability ~= nil and not ability:IsNull() and DATA[ability:GetName()] ~= nil then
				list[#list + 1] = ability
			end
		end
		tracked[playerId] = list
	end
	for _, ability in ipairs(tracked[playerId]) do
		if ability ~= nil and not ability:IsNull() then
			local ok, err = pcall(TickAbility, bot, ability, state[playerId])
			if not ok and not state[playerId]._errLogged then
				state[playerId]._errLogged = true
				pcall(print, "[OHA-ERROR] charge_tracker: " .. tostring(err))
			end
		end
	end
end

-- Charges left, or nil when the ability is not charge-based right now (or not learned).
function ChargeTracker.Count(bot, ability)
	if bot == nil or ability == nil or ability:IsNull() then
		return nil
	end
	local slot = state[bot:GetPlayerID()]
	local chargeState = slot and slot[ability:GetName()]
	return chargeState and chargeState.n or nil
end

-- Mark a cast order (count = how many casts were queued), so a cast with no visible cast phase
-- is still counted.
function ChargeTracker.Issued(bot, ability, target, count)
	if bot == nil or ability == nil or ability:IsNull() then
		return
	end
	local slot = state[bot:GetPlayerID()]
	local chargeState = slot and slot[ability:GetName()]
	if chargeState ~= nil then
		count = count or 1
		chargeState.pending = (chargeState.pending or 0) + count
		chargeState.pendingUntil = DotaTime() + 1 + count * 0.6
		chargeState.pendingTarget = target
	end
end

return ChargeTracker
