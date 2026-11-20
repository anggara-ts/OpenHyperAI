-- Shared helper: projectile.
local function installProjectile(Fu)
	function Fu.IsAllyUnitSpell(abilityName)
		return Fu.Skill["sAllyUnitAbilityIndex"][abilityName] == true
	end
	function Fu.IsProjectileUnitSpell(abilityName)
		return Fu.Skill["sProjectileAbilityIndex"][abilityName] == true
	end
	function Fu.IsOnlyProjectileSpell(abilityName)
		return Fu.Skill["sOnlyProjectileAbilityIndex"][abilityName] == true
	end
	function Fu.IsStunProjectileSpell(abilityName)
		return Fu.Skill["sStunProjectileAbilityIndex"][abilityName] == true
	end
	-- Find* return what the Is* helpers saw (the projectile, or the casting enemy and its ability), for the
	-- [OHA-DODGE] log; each Is* is Find* ~= nil, so its callers get the same true/false as before.
	function Fu.IsWillBeCastUnitTargetSpell(unit, range)
		return Fu.FindWillBeCastUnitTargetSpell(unit, range) ~= nil
	end
	function Fu.FindWillBeCastUnitTargetSpell(unit, range)
		if range > 1600 then
			range = 1600
		end
		local nearbyEnemies = Fu.GetNearbyHeroes(unit, range, true, BOT_MODE_NONE)
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				enemyHero ~= nil
				and enemyHero:IsAlive()
				and (enemyHero:IsCastingAbility() or enemyHero:IsUsingAbility())
				and enemyHero:IsFacingLocation(unit:GetLocation(), 20)
			then
				local activeAbility = enemyHero:GetCurrentActiveAbility()
				if activeAbility ~= nil and activeAbility:GetBehavior() == ABILITY_BEHAVIOR_UNIT_TARGET then
					local abilityName = activeAbility:GetName()
					if not Fu.IsAllyUnitSpell(abilityName) then
						if Fu.IsInRange(enemyHero, unit, 330) or not Fu.IsProjectileUnitSpell(abilityName) then
							if not Fu.IsHumanPlayer(enemyHero) then
								return enemyHero, activeAbility
							else
								local animCycle = enemyHero:GetAnimCycle()
								local castPoint = activeAbility:GetCastPoint()
								if animCycle > 0.1 and castPoint * (1 - animCycle) < 0.27 then
									return enemyHero, activeAbility
								end
							end
						end
					end
				end
			end
		end
		return nil
	end
	function Fu.IsWillBeCastPointSpell(unit, range)
		return Fu.FindWillBeCastPointSpell(unit, range) ~= nil
	end
	function Fu.FindWillBeCastPointSpell(unit, range)
		local nearbyEnemies = Fu.GetNearbyHeroes(unit, range, true, BOT_MODE_NONE)
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				enemyHero ~= nil
				and enemyHero:IsAlive()
				and (enemyHero:IsCastingAbility() or enemyHero:IsUsingAbility())
				and enemyHero:IsFacingLocation(unit:GetLocation(), 50)
			then
				local activeAbility = enemyHero:GetCurrentActiveAbility()
				if activeAbility ~= nil then
					if
						activeAbility:GetBehavior() == ABILITY_BEHAVIOR_POINT
						or activeAbility:GetBehavior() == ABILITY_BEHAVIOR_NO_TARGET
						or activeAbility:GetBehavior() == 48
					then
						return enemyHero, activeAbility
					end
				end
			end
		end
		return nil
	end
	function Fu.IsProjectileIncoming(unit, range)
		return Fu.FindProjectileIncoming(unit, range) ~= nil
	end
	-- accept (optional, #134): a function(projectile) -> true|false; the finder then returns the first projectile
	-- that passes its own filter and accept (the dodge items pass a time-to-impact check). Without it: as before.
	function Fu.FindProjectileIncoming(unit, range, accept)
		local projectiles = unit:GetIncomingTrackingProjectiles()
		for _, projectile in pairs(projectiles) do
			if
				projectile.is_dodgeable
				and not projectile.is_attack
				and GetUnitToLocationDistance(unit, projectile.location) < range
				and (projectile.caster == nil or projectile.caster:GetTeam() ~= GetTeam())
				and (projectile.ability ~= nil and not Fu.IsOnlyProjectileSpell(projectile.ability:GetName()) and (projectile.ability:GetName() ~= "medusa_mystic_snake" or projectile.caster == nil or projectile.caster:GetUnitName() == "npc_dota_hero_medusa"))
				and (accept == nil or accept(projectile))
			then
				return projectile
			end
		end
		return nil
	end
	function Fu.IsUnitTargetProjectileIncoming(unit, range)
		return Fu.FindUnitTargetProjectileIncoming(unit, range) ~= nil
	end
	function Fu.FindUnitTargetProjectileIncoming(unit, range, accept)
		local projectiles = unit:GetIncomingTrackingProjectiles()
		for _, projectile in pairs(projectiles) do
			if
				not projectile.is_attack
				and GetUnitToLocationDistance(unit, projectile.location) < range
				and (projectile.caster == nil or projectile.caster:GetTeam() ~= unit:GetTeam() and projectile.caster:IsHero() and projectile.caster:GetUnitName() ~= "npc_dota_hero_antimage" and projectile.caster:GetUnitName() ~= "npc_dota_hero_templar_assassin")
				and (projectile.ability ~= nil and (projectile.ability:GetName() ~= "medusa_mystic_snake" or projectile.caster == nil or projectile.caster:GetUnitName() == "npc_dota_hero_medusa"))
				and (projectile.ability:GetBehavior() == ABILITY_BEHAVIOR_UNIT_TARGET or not Fu.IsOnlyProjectileSpell(
					projectile.ability:GetName()
				))
				and (accept == nil or accept(projectile))
			then
				return projectile
			end
		end
		return nil
	end
	function Fu.IsStunProjectileIncoming(unit, range)
		local projectiles = unit:GetIncomingTrackingProjectiles()
		for _, projectile in pairs(projectiles) do
			if
				not projectile.is_attack
				and GetUnitToLocationDistance(unit, projectile.location) < range
				and projectile.ability ~= nil
				and Fu.IsStunProjectileSpell(projectile.ability:GetName())
			then
				return true
			end
		end
		return false
	end
	function Fu.IsAttackProjectileIncoming(unit, range)
		local projectiles = unit:GetIncomingTrackingProjectiles()
		for _, projectile in pairs(projectiles) do
			if projectile.is_attack and GetUnitToLocationDistance(unit, projectile.location) < range then
				return true
			end
		end
		return false
	end
	function Fu.IsNotAttackProjectileIncoming(unit, range)
		return Fu.FindNotAttackProjectileIncoming(unit, range) ~= nil
	end
	function Fu.FindNotAttackProjectileIncoming(unit, range, accept)
		local projectiles = unit:GetIncomingTrackingProjectiles()
		for _, projectile in pairs(projectiles) do
			if
				not projectile.is_attack
				and GetUnitToLocationDistance(unit, projectile.location) < range
				and (projectile.caster == nil or projectile.caster:GetTeam() ~= unit:GetTeam())
				and (projectile.ability ~= nil and (projectile.ability:GetName() ~= "medusa_mystic_snake" or projectile.caster == nil or projectile.caster:GetUnitName() == "npc_dota_hero_medusa"))
				and (accept == nil or accept(projectile))
			then
				return projectile
			end
		end
		return nil
	end

	-- Projectile timing for the dodge items (#134). Pure math in FuncLib/systems/dodge_rules.lua.
	local DodgeRules = require(GetScriptDirectory() .. "/FuncLib/systems/dodge_rules")
	Fu.DodgeRules = DodgeRules
	-- [OHA-API] (#134): the fields a projectile table really has (the docs and this API differ), once per script
	-- VM and kind, e.g. "location=userdata ability=table velocity=userdata radius=number".
	local fieldsLogged = {}
	local function logProjectileFields(kind, projectile)
		if fieldsLogged[kind] or type(projectile) ~= "table" then
			return
		end
		fieldsLogged[kind] = true
		local parts = {}
		for key, value in pairs(projectile) do
			parts[#parts + 1] = tostring(key) .. "=" .. type(value)
		end
		table.sort(parts)
		print(
			string.format(
				"[OHA-API] t=%.0f %s %s-projectile fields: %s",
				DotaTime(),
				(string.gsub(GetBot():GetUnitName(), "npc_dota_hero_", "")),
				kind,
				table.concat(parts, " ")
			)
		)
	end
	local function vectorXY(value)
		if value == nil then
			return nil
		end
		local ok, x, y = pcall(function()
			return value.x, value.y
		end)
		if ok and type(x) == "number" and type(y) == "number" then
			return x, y
		end
		return nil
	end
	local function unitRadius(unit)
		local ok, radius = pcall(unit.GetBoundingRadius, unit)
		if ok and type(radius) == "number" and radius > 0 then
			return radius
		end
		return DodgeRules.HERO_HULL
	end
	-- Whose projectile is it: true = our team, false = the enemy's, nil = can't tell. The caster's team first,
	-- then a player id field, then the ability name against our heroes' names (ability names start with the hero
	-- name: mirana_arrow). Field names other than ability / location / caster are not verified for linear
	-- projectiles (mode_retreat_generic.lua's IsAlliedSource reads them the same way).
	function Fu.IsAlliedProjectileSource(source, team)
		local caster = source.caster
		if caster ~= nil and caster.GetTeam ~= nil then
			local ok, casterTeam = pcall(caster.GetTeam, caster)
			if ok and casterTeam ~= nil then
				return casterTeam == team
			end
		end
		local playerId = source.playerid or source.player
		if type(playerId) == "number" and playerId >= 0 then
			return GetTeamForPlayer(playerId) == team
		end
		local abilityName = source.ability ~= nil and source.ability:GetName() or nil
		if abilityName ~= nil then
			for _, ally in pairs(GetUnitList(UNIT_LIST_ALLIED_HEROES) or {}) do
				if ally ~= nil and not ally:IsNull() then
					local short = string.gsub(ally:GetUnitName(), "npc_dota_hero_", "")
					if string.sub(abilityName, 1, #short + 1) == short .. "_" then
						return ally:GetTeam() == team
					end
				end
			end
		end
		return nil
	end
	-- Samples per bot (the dodge items of one bot read the same projectile several times per think).
	local function samples(name)
		local bot = GetBot()
		bot._dodgeSamples = bot._dodgeSamples or {}
		local store = bot._dodgeSamples[name]
		if store == nil then
			store = {}
			bot._dodgeSamples[name] = store
		end
		local now = DotaTime()
		if now >= (store._prunedAt or -99) + 1 then
			store._prunedAt = now
			for key, sample in pairs(store) do
				if type(sample) == "table" and now - sample.t > 2 then
					store[key] = nil
				end
			end
		end
		return store, now
	end
	-- A tracking projectile flying at `unit`: its time to impact and the window for a tool of this cast point.
	-- Returns window ("now" | "wait" | "late", see DodgeRules.Window), tti, src (measured | default). The speed
	-- is the closing speed between two thinks (distance change / time); a projectile seen for the first time
	-- uses DodgeRules.DEFAULT_SPEED.
	function Fu.TrackingProjectileWindow(unit, projectile, castPoint)
		if projectile == nil or projectile.location == nil then
			return "wait", nil, "none"
		end
		local dist = GetUnitToLocationDistance(unit, projectile.location)
		local store, now = samples("tracking")
		local abilityName = projectile.ability ~= nil and projectile.ability:GetName() or "?"
		local casterName = projectile.caster ~= nil and projectile.caster:GetUnitName() or "?"
		local key = unit:GetUnitName() .. "|" .. abilityName .. "|" .. casterName
		local sample = store[key]
		if sample == nil or now - sample.t > 0.5 or dist > sample.d + 50 then
			sample = { d = dist, t = now }
			store[key] = sample
		elseif now > sample.t then
			local measured = DodgeRules.ClosingSpeed(sample.d, sample.t, dist, now)
			if measured ~= nil then
				sample.speed = measured
			end
			sample.d, sample.t = dist, now
		end
		local speed, src = sample.speed, "measured"
		if speed == nil then
			speed, src = DodgeRules.DEFAULT_SPEED, "default"
		end
		local tti = DodgeRules.TimeToImpact(math.max(0, dist - unitRadius(unit)), speed)
		return DodgeRules.Window(tti, castPoint), tti, src
	end
	-- GetLinearProjectiles once per think per bot, with each projectile's velocity: the API's velocity field when
	-- it has one (src=api), else the move since the last think (src=measured), else caster -> projectile at the
	-- spell's speed (src=caster).
	local function readLinear()
		local bot = GetBot()
		local now = DotaTime()
		local cache = bot._linearRead
		if cache ~= nil and cache.t == now then
			return cache.list
		end
		local ok, raw = pcall(GetLinearProjectiles)
		local list = {}
		local store = samples("linear")
		for _, projectile in pairs(ok and raw or {}) do
			if type(projectile) == "table" then
				logProjectileFields("linear", projectile)
				local px, py = vectorXY(projectile.location)
				local abilityName = projectile.ability ~= nil and projectile.ability:GetName() or nil
				if px ~= nil and abilityName ~= nil then
					local key = type(projectile.handle) == "number" and projectile.handle or abilityName
					local vx, vy = vectorXY(projectile.velocity)
					local src = "api"
					if vx == nil or vx * vx + vy * vy < 1 then
						vx, vy, src = nil, nil, nil
						local prev = store[key]
						if prev ~= nil and prev.t < now and now - prev.t <= 0.5 then
							local dt = now - prev.t
							vx, vy, src = (px - prev.x) / dt, (py - prev.y) / dt, "measured"
						elseif prev ~= nil and prev.t == now then
							vx, vy, src = prev.vx, prev.vy, prev.src
						end
					end
					store[key] = { x = px, y = py, t = now, vx = vx, vy = vy, src = src }
					list[#list + 1] = {
						projectile = projectile,
						name = abilityName,
						x = px,
						y = py,
						vx = vx,
						vy = vy,
						src = src,
					}
				end
			end
		end
		bot._linearRead = { t = now, list = list }
		return list
	end
	-- The dangerous linear skillshot (DodgeRules.LINEAR) that will hit `unit` soonest and that `tool`
	-- ("blink" | "cyclone" | "bkb") can answer. Returns a table { projectile, name, spec, tti, miss, window,
	-- vx, vy, src } or nil. window as DodgeRules.Window for a tool of this cast point.
	function Fu.FindLinearProjectileIncoming(unit, castPoint, tool)
		local best = nil
		local hpRatio = unit:GetHealth() / math.max(1, unit:GetMaxHealth())
		for _, entry in ipairs(readLinear()) do
			local spec = DodgeRules.LINEAR[entry.name]
			if
				spec ~= nil
				and DodgeRules.ToolAnswers(spec, tool)
				and DodgeRules.WorthDodging(spec, hpRatio)
				and Fu.IsAlliedProjectileSource(entry.projectile, unit:GetTeam()) ~= true
			then
				local vx, vy, src = entry.vx, entry.vy, entry.src
				local caster = entry.projectile.caster
				local casterValid = caster ~= nil and caster.GetLocation ~= nil and not caster:IsNull()
				if src == "measured" then
					-- Two samples of different casts of the same spell (no handle field) give a jump, not a speed.
					local speed = math.sqrt(vx * vx + vy * vy)
					if speed > spec.speed * 2 or speed < spec.speed * 0.4 then
						vx, vy, src = nil, nil, nil
					end
				end
				if vx == nil and casterValid then
					local cx, cy = vectorXY(caster:GetLocation())
					local dx, dy = entry.x - (cx or entry.x), entry.y - (cy or entry.y)
					local len = math.sqrt(dx * dx + dy * dy)
					if len > 1 then
						vx, vy, src = dx / len * spec.speed, dy / len * spec.speed, "caster"
					end
				end
				local radius = type(entry.projectile.radius) == "number"
						and entry.projectile.radius > 0
						and entry.projectile.radius
					or spec.radius
				local reach = radius + unitRadius(unit)
				local inRange = not casterValid or GetUnitToUnitDistance(caster, unit) <= spec.range + reach
				if vx ~= nil and inRange then
					local bx, by = vectorXY(unit:GetLocation())
					local hit, tti, miss =
						DodgeRules.LinearImpact(entry.x, entry.y, vx, vy, bx, by, radius, unitRadius(unit))
					if hit and tti ~= nil and (best == nil or tti < best.tti) then
						best = {
							projectile = entry.projectile,
							name = entry.name,
							spec = spec,
							tti = tti,
							miss = miss,
							window = DodgeRules.Window(tti, castPoint),
							vx = vx,
							vy = vy,
							src = src,
						}
					end
				end
			end
		end
		return best
	end
	-- For the tracking-projectile [OHA-API] field dump: the dodge items call this with what they read.
	function Fu.LogTrackingProjectileFields(projectile)
		logProjectileFields("tracking", projectile)
	end
	local ignoredSelfCasts = {
		["antimage_blink"] = true,
		["arc_warden_magnetic_field"] = true,
		["arc_warden_spark_wraith"] = true,
		["arc_warden_tempest_double"] = true,
		["chaos_knight_phantasm"] = true,
		["clinkz_burning_army"] = true,
		["death_prophet_exorcism"] = true,
		["dragon_knight_elder_dragon_form"] = true,
		["juggernaut_healing_ward"] = true,
		["necrolyte_death_pulse"] = true,
		["necrolyte_sadist"] = true,
		["omniknight_guardian_angel"] = true,
		["phantom_assassin_blur"] = true,
		["pugna_nether_ward"] = true,
		["skeleton_king_mortal_strike"] = true,
		["sven_warcry"] = true,
		["sven_gods_strength"] = true,
		["templar_assassin_refraction"] = true,
		["templar_assassin_psionic_trap"] = true,
		["windrunner_windrun"] = true,
		["witch_doctor_voodoo_restoration"] = true,
	}
	function Fu.DidEnemyCastAbility()
		local bot = GetBot()
		local nearbyEnemies = Fu.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE)
		for _, enemyHero in pairs(nearbyEnemies) do
			if
				enemyHero ~= nil
				and enemyHero:IsAlive()
				and enemyHero:IsFacingLocation(bot:GetLocation(), 30)
				and (enemyHero:IsCastingAbility() or enemyHero:IsUsingAbility())
			then
				local activeAbility = enemyHero:GetCurrentActiveAbility()
				if activeAbility ~= nil then
					local behavior = activeAbility:GetBehavior()
					local abilityName = activeAbility:GetName()
					if
						behavior ~= ABILITY_BEHAVIOR_UNIT_TARGET
						and (enemyHero:IsBot() or enemyHero:GetLevel() >= 5)
						and not ignoredSelfCasts[abilityName]
					then
						return true
					end
					if
						behavior == ABILITY_BEHAVIOR_UNIT_TARGET
						and enemyHero:GetLevel() >= 6
						and not enemyHero:IsBot()
						and not Fu.IsAllyUnitSpell(abilityName)
						and (not Fu.IsProjectileUnitSpell(abilityName) or Fu.IsInRange(bot, enemyHero, 400))
					then
						return true
					end
				end
			end
		end
		return false
	end
end
return installProjectile
