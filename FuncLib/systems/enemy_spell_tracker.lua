-- Shared bot system (#34, game 067): when our team last saw an enemy hero use a spell or item, and whether it can
-- be ready again. Used by BotsLib/hero_alchemist.lua (escape-ready and disable-risk rules).
--
-- Bot API fact (game 067, Docs/BOT_API_RUNTIME.md): GetCooldownTimeRemaining() on an enemy hero's ability reads 0.
-- Nyx Assassin's Vendetta read ready 4s and 6s after it was cast (cooldown 80/70/60, datafeed hero 88), and no
-- listed spell of five enemy heroes read above 0 in 68 minutes. GetLevel() and GetMana() do read. So "ready" is
-- worked out here from what the team sees:
--   modifier  a visible enemy hero has the spell's modifier (Shadow Realm, Skeleton Walk's fade, ...)
--   vanish    an enemy hero that has an invisibility escape learned was seen within the last half second, and is
--             gone from sight while the spot it stood on is still in our vision (not fog, not a TP, not dead)
--   callback  InstallCastCallback reported the cast (a probe: whether it fires for enemy casts is unverified)
-- State of a spell: "ready" (seen used, and its cooldown has passed since), "cooldown" (seen used, cooldown not
-- passed), "unknown" (never seen used, or the cooldown is not known).
-- One table per team's Lua state (require caches the module), shared by every bot that reads it.
local EnemySpells = {}

-- Cooldowns by level, game data. Abilities: Valve datafeed (herodata, 2026-11-21): Nyx 88, Clinkz 56, Dark Willow
-- 119, Bounty Hunter 62, Weaver 63, Templar Assassin 46, Puck 13, Riki 32, Mirana 9, Sand King 16, Invoker 74,
-- Death Prophet 43. Items: 7.42 items.txt in pak01_dir.vpk (read 2026-11-21), AbilityCooldown.
EnemySpells.COOLDOWNS = {
	nyx_assassin_vendetta = { 80, 70, 60 },
	clinkz_wind_walk = { 24, 21, 18 },
	dark_willow_shadow_realm = { 21, 19, 17, 15 },
	bounty_hunter_wind_walk = { 18, 17, 16, 15 },
	weaver_shukuchi = { 15, 12, 9, 6 },
	templar_assassin_meld = { 11, 9, 7, 5 },
	puck_phase_shift = { 8, 7.5, 7, 6.5 },
	riki_tricks_of_the_trade = { 21, 18, 15, 12 },
	mirana_invis = { 120, 110, 100 },
	sandking_sand_storm = { 40, 34, 28, 22 },
	invoker_ghost_walk = { 40 },
	death_prophet_silence = { 17, 15, 13, 11 },
	item_invis_sword = { 25 },
	item_silver_edge = { 23 },
	item_glimmer_cape = { 15 },
	item_shadow_amulet = { 18 },
	item_trickster_cloak = { 25 },
	item_cyclone = { 23 },
	item_wind_waker = { 19 },
}

-- Modifier on the enemy hero -> the spell or item that put it there. Names from the 7.42 ability strings
-- (DOTA_Tooltip_modifier_<name> in the English ability tooltips, pak01_dir.vpk); Riki's Tricks of the Trade has no
-- listed modifier and is left to the callback.
EnemySpells.MODIFIERS = {
	modifier_nyx_assassin_vendetta = "nyx_assassin_vendetta",
	modifier_clinkz_wind_walk = "clinkz_wind_walk",
	modifier_dark_willow_shadow_realm_buff = "dark_willow_shadow_realm",
	modifier_bounty_hunter_wind_walk = "bounty_hunter_wind_walk",
	modifier_weaver_shukuchi = "weaver_shukuchi",
	modifier_templar_assassin_meld = "templar_assassin_meld",
	modifier_puck_phase_shift = "puck_phase_shift",
	modifier_mirana_moonlight_shadow = "mirana_invis",
	modifier_sandking_sand_storm = "sandking_sand_storm",
	modifier_invoker_ghost_walk_self = "invoker_ghost_walk",
	modifier_item_invisibility_edge_windwalk = "item_invis_sword",
	modifier_item_silver_edge_windwalk = "item_silver_edge",
	modifier_item_glimmer_cape_fade = "item_glimmer_cape",
	modifier_item_shadow_amulet_fade = "item_shadow_amulet",
	modifier_item_trickster_cloak_invis = "item_trickster_cloak",
}

-- Spells and items that take the hero out of sight (a vanish counts as their use). Not Shadow Realm: Dark Willow
-- stays visible in it (its modifier is read instead).
EnemySpells.VANISH = {
	nyx_assassin_vendetta = true,
	clinkz_wind_walk = true,
	bounty_hunter_wind_walk = true,
	weaver_shukuchi = true,
	templar_assassin_meld = true,
	puck_phase_shift = true,
	riki_tricks_of_the_trade = true,
	mirana_invis = true,
	sandking_sand_storm = true,
	invoker_ghost_walk = true,
	item_invis_sword = true,
	item_silver_edge = true,
	item_shadow_amulet = true,
	item_trickster_cloak = true,
}

-- A use seen within NEW_CAST_GAP seconds of the last sighting of the same use is the same cast (a modifier read on
-- every think while it lasts).
EnemySpells.NEW_CAST_GAP = 2.0
-- A vanish counts only for a hero seen within VANISH_SEEN_WITHIN seconds, whose last spot is still visible within
-- VANISH_VISIBLE_RADIUS (it can't have walked out of our vision in that time: 250 is under a second at any speed).
EnemySpells.VANISH_SEEN_WITHIN = 0.5
EnemySpells.VANISH_VISIBLE_RADIUS = 250

-- Game-data cooldown of a spell at a level (the last listed level for higher ones), or nil. Level unknown (nil or 0):
-- the shortest listed cooldown, so the spell reads ready again early rather than late (a brew held back once too often
-- costs less than one that blows up on him).
function EnemySpells.DataCooldown(name, level)
	local values = EnemySpells.COOLDOWNS[name]
	if values == nil then
		return nil
	end
	if level == nil or level <= 0 then
		return values[#values]
	end
	return values[math.min(#values, level)]
end

-- The cooldown to assume: the API's own GetCooldown() when it reads above 0 (it counts cooldown reduction), else
-- the game data. Returns the seconds (or nil) and the source: "api", "data" or "none".
function EnemySpells.CooldownFor(name, level, apiCooldown)
	if apiCooldown ~= nil and apiCooldown > 0 then
		return apiCooldown, "api"
	end
	local cooldown = EnemySpells.DataCooldown(name, level)
	if cooldown ~= nil then
		return cooldown, "data"
	end
	return nil, "none"
end

-- State of a use seen at `castAt` with `cooldown` seconds, at `now`.
function EnemySpells.StateAt(castAt, cooldown, now)
	if castAt == nil or cooldown == nil or cooldown <= 0 then
		return "unknown"
	end
	if now - castAt < cooldown then
		return "cooldown"
	end
	return "ready"
end

local casts = {} -- casts[heroName][spellName] = { at=, lastObs=, cooldown=, source=, via=, level= }

-- Note a use of `spell` by `heroName` seen at `now`. Returns true when it is a new cast (a gap of more than
-- NEW_CAST_GAP since the last sighting), false when it only extends the one already noted.
function EnemySpells.Record(heroName, spell, now, level, apiCooldown, via)
	local byHero = casts[heroName]
	if byHero == nil then
		byHero = {}
		casts[heroName] = byHero
	end
	local entry = byHero[spell]
	if entry ~= nil and now - entry.lastObs <= EnemySpells.NEW_CAST_GAP then
		entry.lastObs = now
		return false
	end
	local cooldown, source = EnemySpells.CooldownFor(spell, level, apiCooldown)
	byHero[spell] = { at = now, lastObs = now, cooldown = cooldown, source = source, via = via, level = level or 0 }
	return true
end

-- State of `spell` of `heroName` at `now` ("ready", "cooldown", "unknown") and the entry it was read from (nil
-- when never seen).
function EnemySpells.State(heroName, spell, now)
	local entry = casts[heroName] and casts[heroName][spell]
	if entry == nil then
		return "unknown", nil
	end
	return EnemySpells.StateAt(entry.at, entry.cooldown, now), entry
end

local function HeroName(unit)
	local ok, name = pcall(function()
		return unit:GetUnitName()
	end)
	return ok and name or "?"
end

local function LogSeen(observer, heroName, spell, via, entry)
	pcall(
		print,
		string.format(
			"[OHA-ENEMYCD] t=%.0f %s seen hero=%s spell=%s via=%s level=%d cd=%.1f cdSrc=%s",
			DotaTime(),
			observer,
			heroName,
			spell,
			via,
			entry.level or 0,
			entry.cooldown or -1,
			entry.source or "none"
		)
	)
end

-- The level and GetCooldown() of a listed ability or item of the hero (items count as level 1), or nil.
local function SpellOf(hero, spell)
	if string.sub(spell, 1, 5) == "item_" then
		for slot = 0, 5 do
			local item = hero:GetItemInSlot(slot)
			if item ~= nil and not item:IsNull() and item:GetName() == spell then
				return 1, item:GetCooldown()
			end
		end
		return nil
	end
	local ability = hero:GetAbilityByName(spell)
	if ability == nil or ability:IsNull() then
		return nil
	end
	return ability:GetLevel(), ability:GetCooldown()
end

-- level / apiCooldown: read while the hero was visible (a vanish), else read from the hero now.
local function RecordAndLog(observer, hero, heroName, spell, via, now, level, apiCooldown)
	if level == nil then
		local okSpell, readLevel, readCooldown = pcall(SpellOf, hero, spell)
		if okSpell then
			level, apiCooldown = readLevel, readCooldown
		end
	end
	if EnemySpells.Record(heroName, spell, now, level, apiCooldown, via) then
		LogSeen(observer, heroName, spell, via, casts[heroName][spell])
	end
end

-- The vanish spell a visible enemy hero could use now: the first learned one (items: carried) with its level and
-- GetCooldown(), or nil. Read while it is visible: a handle out of vision may not answer (discussion #50, item 10).
local function VanishSpellOf(hero)
	for slot = 0, 9 do
		local ability = hero:GetAbilityInSlot(slot)
		if ability ~= nil and not ability:IsNull() and not ability:IsHidden() then
			local name = ability:GetName()
			if EnemySpells.VANISH[name] and ability:GetLevel() > 0 then
				return name, ability:GetLevel(), ability:GetCooldown()
			end
		end
	end
	for slot = 0, 5 do
		local item = hero:GetItemInSlot(slot)
		if item ~= nil and not item:IsNull() and EnemySpells.VANISH[item:GetName()] then
			return item:GetName(), 1, item:GetCooldown()
		end
	end
	return nil
end

local sightings = {} -- sightings[heroName] = { hero=, at=, loc=, pid=, tp=, vanish=, vanishAt= }
local observeAt = -999

-- For the tests: forget every cast and sighting.
function EnemySpells.Reset()
	casts, sightings, observeAt = {}, {}, -999
end

-- Runs from a bot's think. `enemies`: the real (not illusion) enemy heroes it sees, already filtered by the caller.
-- At most every 0.1s. `observer` names the bot in the log lines:
--   [OHA-ENEMYCD] t= <observer> seen hero= spell= via=modifier|vanish|callback level= cd= cdSrc=api|data|none
function EnemySpells.Observe(observer, enemies)
	local now = DotaTime()
	if now - observeAt < 0.1 then
		return
	end
	observeAt = now
	local visibleNow = {}
	for _, hero in pairs(enemies or {}) do
		pcall(function()
			local heroName = hero:GetUnitName()
			visibleNow[heroName] = true
			for modifier, spell in pairs(EnemySpells.MODIFIERS) do
				if hero:HasModifier(modifier) then
					RecordAndLog(observer, hero, heroName, spell, "modifier", now)
				end
			end
			local sighting = sightings[heroName]
			if sighting == nil then
				sighting = { vanishAt = -999 }
				sightings[heroName] = sighting
			end
			sighting.hero, sighting.at, sighting.loc = hero, now, hero:GetLocation()
			sighting.pid = hero:GetPlayerID()
			sighting.tp = hero:HasModifier("modifier_teleporting")
			-- The learned vanish spell changes rarely: re-read once per second.
			if now - sighting.vanishAt >= 1.0 then
				sighting.vanish, sighting.vanishLevel, sighting.vanishCooldown = VanishSpellOf(hero)
				sighting.vanishAt = now
			end
		end)
	end
	for heroName, sighting in pairs(sightings) do
		if
			not visibleNow[heroName]
			and sighting.vanish ~= nil
			and not sighting.tp
			and now - sighting.at <= EnemySpells.VANISH_SEEN_WITHIN
		then
			pcall(function()
				-- Out of the caller's list but still in sight (e.g. it walked beyond the list radius): no vanish.
				if sighting.hero ~= nil and not sighting.hero:IsNull() and sighting.hero:CanBeSeen() then
					return
				end
				-- Dead: no vanish (IsHeroAlive on an enemy player ID: FuncLib/systems/kill_window.lua relies on it too).
				-- A failed read records nothing.
				local okAlive, alive = pcall(IsHeroAlive, sighting.pid)
				if not okAlive or not alive then
					return
				end
				if not IsRadiusVisible(sighting.loc, EnemySpells.VANISH_VISIBLE_RADIUS) then
					return
				end
				RecordAndLog(
					observer,
					sighting.hero,
					heroName,
					sighting.vanish,
					"vanish",
					now,
					sighting.vanishLevel,
					sighting.vanishCooldown
				)
			end)
			-- One check per disappearance.
			sighting.at = -999
		end
	end
end

-- Probe: does InstallCastCallback report enemy casts? Installed once per team's Lua state. Lines:
--   [OHA-ENEMYCD] t= cast-probe installed=yes|no error=
--   [OHA-ENEMYCD] t= cast-callback n= enemyN= arg=<type> keys=<fields> caster= spell= team=ally|enemy
--                                                         the first 5 calls, and the first 5 calls for an enemy caster
-- An enemy hero's cast of a spell in COOLDOWNS or in the caller's `interest` name set is recorded with via=callback.
local probeInstalled = false
local callbackCount = 0
local enemyCallbackCount = 0
local probeInterest = {}
local function OnCast(info)
	callbackCount = callbackCount + 1
	local caster, ability = nil, nil
	if type(info) == "table" then
		caster = info.unit or info.caster or info.player
		ability = info.ability
	end
	local spell = nil
	if ability ~= nil and type(ability) ~= "string" then
		local okName, name = pcall(function()
			return ability:GetName()
		end)
		spell = okName and name or nil
	elseif type(ability) == "string" then
		spell = ability
	end
	local enemy = false
	if caster ~= nil and type(caster) ~= "number" then
		local okTeam, team = pcall(function()
			return caster:GetTeam()
		end)
		enemy = okTeam and team ~= GetTeam()
	end
	if enemy then
		enemyCallbackCount = enemyCallbackCount + 1
	end
	if callbackCount <= 5 or (enemy and enemyCallbackCount <= 5) then
		local keys = {}
		if type(info) == "table" then
			for key in pairs(info) do
				keys[#keys + 1] = tostring(key)
			end
			table.sort(keys)
		end
		pcall(
			print,
			string.format(
				"[OHA-ENEMYCD] t=%.0f cast-callback n=%d enemyN=%d arg=%s keys=%s caster=%s spell=%s team=%s",
				DotaTime(),
				callbackCount,
				enemyCallbackCount,
				type(info),
				table.concat(keys, ","),
				caster ~= nil and type(caster) ~= "number" and HeroName(caster) or tostring(caster),
				tostring(spell),
				enemy and "enemy" or "ally"
			)
		)
	end
	if enemy and spell ~= nil and (EnemySpells.COOLDOWNS[spell] ~= nil or probeInterest[spell]) then
		local okHero, isHero = pcall(function()
			return caster:IsHero()
		end)
		if okHero and isHero then
			RecordAndLog("callback", caster, HeroName(caster), spell, "callback", DotaTime())
		end
	end
end
function EnemySpells.InstallCastProbe(interest)
	for name in pairs(interest or {}) do
		probeInterest[name] = true
	end
	if probeInstalled then
		return
	end
	probeInstalled = true
	local ok, err = false, "no-function"
	if type(InstallCastCallback) == "function" then
		ok, err = pcall(InstallCastCallback, -1, function(info)
			pcall(OnCast, info)
		end)
	end
	pcall(
		print,
		string.format(
			"[OHA-ENEMYCD] t=%.0f cast-probe installed=%s error=%s",
			DotaTime(),
			ok and "yes" or "no",
			ok and "-" or tostring(err)
		)
	)
end

return EnemySpells
