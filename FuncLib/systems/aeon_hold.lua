-- Aeon Disk hold (#47). 7.42 game files, item_aeon_disk "Combo Breaker": below 70% HP after damage a strong
-- dispel, then a 2.5s buff (modifier_item_aeon_disk_buff) on the holder: +75% status resistance and "all damage
-- you deal and are dealt [is] reduced to zero" (dota_english tooltip; buff_duration 2.5, status_resistance 75).
--   (a) A bot holding the buff deals no damage: its pure damage spells (the list below) are held while the buff
--       lasts longer than the spell needs to land. Disables, items, wards and summons stay allowed (they land
--       in full or outlast the buff).
--   (b) An enemy holding the buff takes no damage: a listed spell aimed at him (unit target, or an area where
--       he is the only enemy hero) is refused and held until his buff ends. Unit-target spells were already
--       held on him where the hero file calls Fu.CanCastOnTargetAdvanced; this catches the point / AoE casts.
-- How: IsFullyCastable reads false for a held spell, so the hero file's own Consider skips it and goes on to
-- its next spell (every hero file gates its casts on IsFullyCastable or Fu.CanCastAbility, which calls it).
-- The cast wrappers are the backstop and do the (b) target check. Logs:
--   [OHA-CAST] t= <hero> hold why=aeon-self|aeon-target spell= left= via=ready|cast
-- via=ready: IsFullyCastable read false for it (the spell was asked about, not necessarily about to be cast);
-- via=cast: a cast order was refused.
local AeonHold = {}

local AEON = "modifier_item_aeon_disk_buff"
AeonHold.MODIFIER = AEON

-- Pure damage spells: damage and nothing that outlasts the buff (no stun, slow, debuff, damage over time,
-- summon, movement of the caster). Read from the 7.42 hero files (scripts/npc/heroes/*.txt, AbilityValues):
-- every hostile spell with a damage value and no other effect, hand-checked. Unknown spells are never held.
-- land: seconds after the cast point until the damage lands (the file's delay / damage_delay, or the
-- projectile's travel at a typical range). radius: the area the damage covers around the target point (or the
-- caster for a no-target spell), used for the enemy-holder check; nil means one target (or global).
AeonHold.SPELLS = {
	lina_dragon_slave = { land = 0.5, radius = 275 }, -- width 275 -> 200, speed 1200, distance 1075
	lina_laguna_blade = { land = 0.25 }, -- damage_delay 0.25
	lion_finger_of_death = { land = 0.25 }, -- damage_delay 0.25
	zuus_arc_lightning = { land = 0, radius = 450 }, -- bounce radius 450
	zuus_thundergods_wrath = { land = 0 }, -- every enemy hero on the map
	skywrath_mage_arcane_bolt = { land = 1.2 }, -- bolt_speed 500
	shadow_shaman_ether_shock = { land = 0, radius = 300 }, -- cone, end_radius 300
	earthshaker_echo_slam = { land = 0, radius = 700 }, -- echo_slam_damage_range 700
	queenofpain_scream_of_pain = { land = 0.4, radius = 600 }, -- area_of_effect 600, projectile_speed 900
	pugna_nether_blast = { land = 0.8, radius = 400 }, -- delay 0.8, radius 400
	invoker_sun_strike = { land = 1.7, radius = 175 }, -- delay 1.7, area_of_effect 175
	tinker_heat_seeking_missile = { land = 1.0, radius = 1500 }, -- speed 700, radius 1500
	sniper_assassinate = { land = 1.0 }, -- projectile_speed 2500
	centaur_double_edge = { land = 0, radius = 220 }, -- radius 220
	visage_soul_assumption = { land = 0.6 }, -- bolt_speed 1000
}

-- Pure rules -------------------------------------------------------------------------------------------------

-- (a) Hold a listed spell while the caster's own buff lasts past the moment the damage lands.
function AeonHold.SelfHold(spell, buffLeft, castPoint)
	if spell == nil or type(buffLeft) ~= "number" then
		return false
	end
	return buffLeft > (castPoint or 0) + (spell.land or 0)
end

-- (b) Hold an area spell when it would hit at least one enemy holder (whose buff lasts past the landing) and
-- no other enemy hero (illusions count as others: they take the damage).
function AeonHold.AreaHold(holders, others)
	return (holders or 0) >= 1 and (others or 0) == 0
end

-- State ------------------------------------------------------------------------------------------------------

-- active: true while some hold may apply (a bot of this team has the buff, or a spell is held for an enemy's
-- buff). IsFullyCastable is called hundreds of times per think, so its fast path reads only this upvalue.
local active = false
local activeUntil = -999
-- held[playerID .. "|" .. spell] = DotaTime until which the spell stays held (an enemy holder's buff).
local held = {}
local loggedAt = {}

local function Activate(untilTime)
	active = true
	if untilTime > activeUntil then
		activeUntil = untilTime
	end
end

function AeonHold.IsActive()
	return active
end

local function BuffLeft(unit)
	local ok, left = pcall(function()
		if not unit:HasModifier(AEON) then
			return 0
		end
		local index = unit:GetModifierByName(AEON)
		if index == nil or index < 0 then
			return 2.5
		end
		return unit:GetModifierRemainingDuration(index) or 0
	end)
	return ok and type(left) == "number" and left or 0
end
AeonHold.BuffLeft = BuffLeft

-- True when the unit holds the Aeon buff: it deals and takes no damage.
function AeonHold.HasBuff(unit)
	return BuffLeft(unit) > 0
end

local function HeroName(unit)
	local ok, name = pcall(function()
		return unit:GetUnitName()
	end)
	return ok and (string.gsub(tostring(name), "npc_dota_hero_", "")) or "?"
end

local function Log(caster, why, spellName, left, via)
	local hero = HeroName(caster)
	local key = hero .. "|" .. spellName .. "|" .. why
	local now = DotaTime()
	if now < (loggedAt[key] or -999) then
		return
	end
	loggedAt[key] = now + 3
	pcall(
		print,
		string.format(
			"[OHA-CAST] t=%.0f %s hold why=%s spell=%s left=%.1f via=%s",
			now,
			hero,
			why,
			spellName,
			left,
			via
		)
	)
end

local function HeldKey(caster, spellName)
	local ok, pid = pcall(function()
		return caster:GetPlayerID()
	end)
	return tostring(ok and pid or "?") .. "|" .. spellName
end

-- Called once per think for every bot (ItemUsageThink): notices the bot's own buff and clears expired holds.
function AeonHold.Track(bot)
	local now = DotaTime()
	local left = BuffLeft(bot)
	if left > 0 then
		Activate(now + left)
	end
	if active and now >= activeUntil then
		active = false
		held = {}
	end
end

-- The spell's name and list entry, or nil for an item or an unlisted spell.
local function Listed(ability)
	local ok, name, isItem = pcall(function()
		return ability:GetName(), ability:IsItem()
	end)
	if not ok or isItem or type(name) ~= "string" then
		return nil
	end
	local spell = AeonHold.SPELLS[name]
	if spell == nil then
		return nil
	end
	return name, spell
end

local function CastPoint(ability)
	local ok, castPoint = pcall(function()
		return ability:GetCastPoint()
	end)
	return ok and type(castPoint) == "number" and castPoint or 0
end

-- IsFullyCastable's slow path (only while active): true when the spell is held now.
function AeonHold.HeldNow(ability)
	local name, spell = Listed(ability)
	if name == nil then
		return false
	end
	local okCaster, caster = pcall(function()
		return ability:GetCaster()
	end)
	if not okCaster or caster == nil then
		return false
	end
	local now = DotaTime()
	local heldUntil = held[HeldKey(caster, name)]
	if heldUntil ~= nil and now < heldUntil then
		Log(caster, "aeon-target", name, heldUntil - now, "ready")
		return true
	end
	local left = BuffLeft(caster)
	if left > 0 and AeonHold.SelfHold(spell, left, CastPoint(ability)) then
		Log(caster, "aeon-self", name, left, "ready")
		return true
	end
	return false
end

local function IsEnemyHero(caster, unit)
	local ok, result = pcall(function()
		return unit:IsHero() and unit:GetTeam() ~= caster:GetTeam()
	end)
	return ok and result == true
end

-- Enemy heroes in radius of center: holders whose buff outlasts the landing, and the rest.
local function CountAround(center, radius, needLeft)
	local holders, others, maxLeft = 0, 0, 0
	local okList, enemies = pcall(GetUnitList, UNIT_LIST_ENEMY_HEROES)
	if not okList or type(enemies) ~= "table" then
		return 0, 1, 0
	end
	for _, enemy in pairs(enemies) do
		local okDist, dist = pcall(function()
			-- The global, not the unit method: global_overrides wraps the method as (self, unit, location), so a
			-- one-argument method call reads 200 for every unit.
			return enemy:IsAlive() and GetUnitToLocationDistance(enemy, center) or 99999
		end)
		if okDist and dist <= radius then
			local left = BuffLeft(enemy)
			if left > needLeft then
				holders = holders + 1
				maxLeft = math.max(maxLeft, left)
			else
				others = others + 1
			end
		end
	end
	return holders, others, maxLeft
end

-- The cast wrappers' check: true when this cast is refused. kind: "location", "entity" or "none".
function AeonHold.RefuseCast(caster, ability, kind, target)
	local name, spell = Listed(ability)
	if name == nil then
		return false
	end
	local now = DotaTime()
	local castPoint = CastPoint(ability)
	local selfLeft = BuffLeft(caster)
	if selfLeft > 0 and AeonHold.SelfHold(spell, selfLeft, castPoint) then
		Activate(now + selfLeft)
		Log(caster, "aeon-self", name, selfLeft, "cast")
		return true
	end
	local needLeft = castPoint + (spell.land or 0)
	local holdLeft = 0
	if kind == "entity" then
		if target == nil or not IsEnemyHero(caster, target) then
			return false
		end
		local targetLeft = BuffLeft(target)
		if targetLeft <= needLeft then
			return false
		end
		if spell.radius ~= nil then
			local okLoc, loc = pcall(function()
				return target:GetLocation()
			end)
			if okLoc and loc ~= nil then
				local holders, others = CountAround(loc, spell.radius, needLeft)
				if not AeonHold.AreaHold(holders, others) then
					return false
				end
			end
		end
		holdLeft = targetLeft
	elseif spell.radius ~= nil then
		local center = target
		if kind == "none" then
			local okLoc, loc = pcall(function()
				return caster:GetLocation()
			end)
			center = okLoc and loc or nil
		end
		if center == nil then
			return false
		end
		local holders, others, maxLeft = CountAround(center, spell.radius, needLeft)
		if not AeonHold.AreaHold(holders, others) then
			return false
		end
		holdLeft = maxLeft
	else
		return false
	end
	held[HeldKey(caster, name)] = now + holdLeft
	Activate(now + holdLeft)
	Log(caster, "aeon-target", name, holdLeft, "cast")
	return true
end

-- Installs the IsFullyCastable patch and the cast wrappers (global_overrides.lua, after its own cast guards).
function AeonHold.Install()
	if AeonHold.installed then
		return
	end
	AeonHold.installed = true
	local AbilityClass = CDOTABaseAbility_BotScript
	if AbilityClass ~= nil and AbilityClass.IsFullyCastable ~= nil then
		local originalIsFullyCastable = AbilityClass.IsFullyCastable
		AbilityClass.IsFullyCastable = function(self)
			local castable = originalIsFullyCastable(self)
			if not active or not castable then
				return castable
			end
			local ok, isHeld = pcall(AeonHold.HeldNow, self)
			return not (ok and isHeld)
		end
	end
	local UnitClass = CDOTA_Bot_Script
	if UnitClass == nil then
		return
	end
	for _, spec in ipairs({
		{ "Action_UseAbilityOnLocation", "location" },
		{ "ActionQueue_UseAbilityOnLocation", "location" },
		{ "ActionPush_UseAbilityOnLocation", "location" },
		{ "Action_UseAbilityOnEntity", "entity" },
		{ "ActionQueue_UseAbilityOnEntity", "entity" },
		{ "ActionPush_UseAbilityOnEntity", "entity" },
	}) do
		local method, kind = spec[1], spec[2]
		local original = UnitClass[method]
		if original ~= nil then
			UnitClass[method] = function(self, ability, target, ...)
				if ability ~= nil then
					local ok, refused = pcall(AeonHold.RefuseCast, self, ability, kind, target)
					if ok and refused then
						return nil
					end
				end
				return original(self, ability, target, ...)
			end
		end
	end
	-- No-target casts take only the ability; do not hand the engine an extra nil.
	for _, method in ipairs({ "Action_UseAbility", "ActionQueue_UseAbility", "ActionPush_UseAbility" }) do
		local original = UnitClass[method]
		if original ~= nil then
			UnitClass[method] = function(self, ability)
				if ability ~= nil then
					local ok, refused = pcall(AeonHold.RefuseCast, self, ability, "none", nil)
					if ok and refused then
						return nil
					end
				end
				return original(self, ability)
			end
		end
	end
end

return AeonHold
