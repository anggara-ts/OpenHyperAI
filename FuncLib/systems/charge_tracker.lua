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
	ringmaster_impalement = { base = 3, talent = { "special_bonus_unique_ringmaster_dagger_charge", 1 }, restore = { 17 } },
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
	zuus_heavenly_jump = { base = 0, talent = { "special_bonus_unique_zeus_jump_charges", 3 }, restore = { 26, 22, 18, 14 } },
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

local function Has(bot, fn)
	local ok, v = pcall(function()
		return bot[fn](bot)
	end)
	return ok and v == true
end

local function TalentLearned(bot, name)
	local ok, v = pcall(function()
		local t = bot:GetAbilityByName(name)
		return t ~= nil and t:IsTrained()
	end)
	return ok and v == true
end


local function RuntimeMax(ability)
	local ok, v = pcall(function()
		return ability:GetSpecialValueInt("AbilityCharges")
	end)
	if ok and type(v) == "number" and v > 0 and v < 20 then
		return v
	end
	return 0
end

local function MaxCharges(bot, ability, d)
	local level = ability:GetLevel()
	local max = ByLevel(d.base, level) or 0
	local hasShard = false
	pcall(function()
		hasShard = bot:HasModifier("modifier_item_aghanims_shard")
	end)
	if d.shard ~= nil and hasShard then
		max = d.shard
	end
	if d.scepter ~= nil and Has(bot, "HasScepter") then
		max = d.scepter
	end
	if d.talent ~= nil and TalentLearned(bot, d.talent[1]) then
		max = max + d.talent[2]
	end
	return math.max(max, RuntimeMax(ability))
end

local function RestoreTime(bot, ability, d)
	local level = ability:GetLevel()
	local ok, v = pcall(function()
		return ability:GetSpecialValueFloat("AbilityChargeRestoreTime")
	end)
	if ok and type(v) == "number" and v > 0 then
		return v
	end
	local hasShard = false
	pcall(function()
		hasShard = bot:HasModifier("modifier_item_aghanims_shard")
	end)
	local r = (hasShard and ByLevel(d.restoreShard, level)) or ByLevel(d.restore, level)
	if r ~= nil and r > 0 then
		return r
	end
	local okCd, cd = pcall(function()
		return ability:GetCooldown()
	end)
	if okCd and type(cd) == "number" and cd > 0 then
		return cd
	end
	return 20
end

local function Log(bot, ability, s, why)
	pcall(print, string.format(
		"[OHA-CHARGES] t=%.0f %s %s n=%d/%d why=%s next=%s",
		DotaTime(),
		Short(bot),
		ability:GetName(),
		s.n,
		s.max,
		why,
		s.nextAt ~= nil and string.format("%.0f", s.nextAt) or "-"
	))
end

local function Spend(bot, ability, s, restoreTime, why)
	s.n = math.max(0, s.n - 1)
	if s.nextAt == nil and s.n < s.max then
		s.nextAt = DotaTime() + restoreTime
	end
	s.pending = math.max(0, (s.pending or 0) - 1)
	s.spentAt = DotaTime()
	Log(bot, ability, s, why)
end

local function Probe(bot, ability, s, castable)
	local okCd, cd = pcall(function()
		return ability:GetCooldownTimeRemaining()
	end)
	cd = okCd and type(cd) == "number" and cd or -1
	local key = string.format("%s|%s|%d|%d", tostring(castable), tostring(cd > 0), RuntimeMax(ability), s.n)
	if key == s.probeKey or DotaTime() < (s.probeAt or -999) then
		return
	end
	s.probeKey = key
	s.probeAt = DotaTime() + 1
	pcall(print, string.format(
		"[OHA-CHARGES] t=%.0f %s %s probe castable=%s cd=%.1f runtimeMax=%d max=%d tracked=%d",
		DotaTime(),
		Short(bot),
		ability:GetName(),
		tostring(castable),
		cd,
		RuntimeMax(ability),
		s.max,
		s.n
	))
end

local function TickAbility(bot, ability, slot)
	local d = DATA[ability:GetName()]
	if d == nil or not ability:IsTrained() then
		return
	end
	local name = ability:GetName()
	local now = DotaTime()
	local max = MaxCharges(bot, ability, d)
	local s = slot[name]
	if max <= 1 then
		slot[name] = nil
		return
	end
	local restoreTime = RestoreTime(bot, ability, d)
	if s == nil then
		s = { n = max, max = max, inPhase = false, pending = 0 }
		if d.startEmpty then
			s.n = 0
			s.nextAt = now + restoreTime
		end
		slot[name] = s
		Log(bot, ability, s, "learned")
	elseif max ~= s.max then
		s.max = max
		s.n = math.min(s.n, max)
		if s.n < max and s.nextAt == nil then
			s.nextAt = now + restoreTime
		end
		Log(bot, ability, s, "max-changed")
	end
	while s.nextAt ~= nil and now >= s.nextAt and s.n < s.max do
		s.n = s.n + 1
		s.nextAt = s.n < s.max and s.nextAt + restoreTime or nil
		Log(bot, ability, s, "restore")
	end
	-- Casts. 1) The cast phase was seen and ended. 2) Zero cast point spells (Leap, Land Mines)
	-- have no phase to see: a cast order we issued (Issued) followed by a mana drop close to the
	-- spell's cost, or by the death of the ordered target.
	local phase = ability:IsInAbilityPhase()
	local mana = bot:GetMana()
	if s.inPhase and not phase then
		Spend(bot, ability, s, restoreTime, "cast")
	elseif (s.pending or 0) > 0 then
		if now > (s.pendingUntil or -999) then
			s.pending = 0
			s.pendingTarget = nil
		elseif now - (s.spentAt or -999) > 0.3 then
			local cost = ability:GetManaCost()
			local drop = (s.lastMana or mana) - mana
			if cost > 0 and drop >= cost * 0.75 and drop <= cost * 1.25 + 10 then
				Spend(bot, ability, s, restoreTime, "cast-mana")
			elseif s.pendingTarget ~= nil and not phase and not s.pendingTarget:IsAlive() then
				s.pendingTarget = nil
				Spend(bot, ability, s, restoreTime, "cast-target-died")
			end
		end
	end
	s.inPhase = phase
	s.lastMana = mana
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
		if not castable and s.n > 0 then
			s.emptySince = s.emptySince or now
			if now - s.emptySince >= 1 then
				s.n = 0
				if s.nextAt == nil then
					s.nextAt = now + restoreTime
				end
				Log(bot, ability, s, "resync-empty")
			end
		else
			s.emptySince = nil
			if castable and s.n == 0 then
				-- A charge just came in, so the next one starts restoring now (game 014: the timer
				-- from learn time gave Sacrifice a second charge 90s early).
				s.n = 1
				s.nextAt = s.n < s.max and now + restoreTime or nil
				Log(bot, ability, s, "resync-one")
			end
		end
	else
		s.emptySince = nil
	end
	Probe(bot, ability, s, castable)
end

-- Once per think per bot.
function ChargeTracker.Tick(bot)
	if bot == nil or not bot:IsHero() or bot:IsIllusion() then
		return
	end
	local id = bot:GetPlayerID()
	local now = DotaTime()
	state[id] = state[id] or {}
	if tracked[id] == nil or now >= (scanAt[id] or -999) then
		scanAt[id] = now + 5
		local list = {}
		for i = 0, 23 do
			local ab = bot:GetAbilityInSlot(i)
			if ab ~= nil and not ab:IsNull() and DATA[ab:GetName()] ~= nil then
				list[#list + 1] = ab
			end
		end
		tracked[id] = list
	end
	for _, ab in ipairs(tracked[id]) do
		if ab ~= nil and not ab:IsNull() then
			local ok, err = pcall(TickAbility, bot, ab, state[id])
			if not ok and not state[id]._errLogged then
				state[id]._errLogged = true
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
	local s = slot and slot[ability:GetName()]
	return s and s.n or nil
end

-- Mark a cast order (count = how many casts were queued), so a cast with no visible cast phase
-- is still counted.
function ChargeTracker.Issued(bot, ability, target, count)
	if bot == nil or ability == nil or ability:IsNull() then
		return
	end
	local slot = state[bot:GetPlayerID()]
	local s = slot and slot[ability:GetName()]
	if s ~= nil then
		count = count or 1
		s.pending = (s.pending or 0) + count
		s.pendingUntil = DotaTime() + 1 + count * 0.6
		s.pendingTarget = target
	end
end

return ChargeTracker
