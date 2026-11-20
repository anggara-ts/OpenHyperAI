-- FuncLib/general_utils/projectile.lua: the Find* variants (#134, [OHA-DODGE]) return the projectile or the casting
-- enemy that the Is* helpers saw, and the Is* helpers still return exactly true / false.
local T = ...
local Stub = T.stub

local function load()
	local bot = Stub.reset({ hero = "npc_dota_hero_lich" })
	local Fu = require(GetScriptDirectory() .. "/FuncLib/func_utils")
	local enemy = Stub.teams[TEAM_DIRE][1]
	local ally = Stub.teams[TEAM_RADIANT][2]
	return Fu, bot, enemy, ally
end

-- A tracking projectile `distance` units in front of `unit`.
local function projectileAt(unit, distance, abilityName, caster, fields)
	local projectile = {
		is_dodgeable = true,
		is_attack = false,
		location = unit:GetLocation() + Vector(distance, 0, 0),
		caster = caster,
		ability = abilityName and Stub.newAbility(abilityName, caster, false) or nil,
	}
	for key, value in pairs(fields or {}) do
		projectile[key] = value
	end
	return projectile
end

local function incoming(unit, list)
	unit.GetIncomingTrackingProjectiles = function()
		return list
	end
end

T.test("projectile finders: return the projectile the Is* helpers saw", function()
	local Fu, bot, enemy = load()
	local bolt = projectileAt(bot, 300, "sven_storm_bolt", enemy)
	incoming(bot, { bolt })
	T.eq(Fu.FindProjectileIncoming(bot, 1200), bolt, "FindProjectileIncoming")
	T.eq(Fu.FindUnitTargetProjectileIncoming(bot, 800), bolt, "FindUnitTargetProjectileIncoming")
	T.eq(Fu.FindNotAttackProjectileIncoming(bot, 350), bolt, "FindNotAttackProjectileIncoming")
	T.eq(Fu.IsProjectileIncoming(bot, 1200), true, "IsProjectileIncoming")
	T.eq(Fu.IsUnitTargetProjectileIncoming(bot, 800), true, "IsUnitTargetProjectileIncoming")
	T.eq(Fu.IsNotAttackProjectileIncoming(bot, 350), true, "IsNotAttackProjectileIncoming")
	T.eq(Fu.IsStunProjectileSpell(bolt.ability:GetName()), true, "storm bolt is a stun projectile (why=stun)")
	-- Out of range: nil from Find*, false (not nil) from Is*.
	T.eq(Fu.FindNotAttackProjectileIncoming(bot, 250), nil, "out of range")
	T.eq(Fu.IsNotAttackProjectileIncoming(bot, 250), false, "out of range: false")
	T.eq(Fu.IsProjectileIncoming(bot, 200), false, "IsProjectileIncoming out of range")
end)

T.test("projectile finders: skip what the Is* helpers skipped", function()
	local Fu, bot, enemy, ally = load()
	local attack = projectileAt(bot, 300, nil, enemy, { is_attack = true })
	incoming(bot, { attack })
	T.eq(Fu.FindProjectileIncoming(bot, 1200), nil, "attack: FindProjectileIncoming")
	T.eq(Fu.FindUnitTargetProjectileIncoming(bot, 1200), nil, "attack: FindUnitTargetProjectileIncoming")
	T.eq(Fu.FindNotAttackProjectileIncoming(bot, 1200), nil, "attack: FindNotAttackProjectileIncoming")
	-- An ally's spell.
	incoming(bot, { projectileAt(bot, 300, "lich_chain_frost", ally) })
	T.eq(Fu.IsProjectileIncoming(bot, 1200), false, "ally caster: IsProjectileIncoming")
	T.eq(Fu.IsUnitTargetProjectileIncoming(bot, 1200), false, "ally caster: IsUnitTargetProjectileIncoming")
	T.eq(Fu.IsNotAttackProjectileIncoming(bot, 1200), false, "ally caster: IsNotAttackProjectileIncoming")
	-- Death Pulse is on the "only a projectile" list: not worth a dodge item.
	incoming(bot, { projectileAt(bot, 300, "necrolyte_death_pulse", enemy) })
	T.eq(Fu.FindProjectileIncoming(bot, 1200), nil, "death pulse: FindProjectileIncoming")
	T.eq(Fu.IsUnitTargetProjectileIncoming(bot, 1200), false, "death pulse: IsUnitTargetProjectileIncoming")
	-- Not dodgeable: only FindProjectileIncoming checks it.
	local undodgeable = projectileAt(bot, 300, "sven_storm_bolt", enemy, { is_dodgeable = false })
	incoming(bot, { undodgeable })
	T.eq(Fu.FindProjectileIncoming(bot, 1200), nil, "not dodgeable: FindProjectileIncoming")
	T.eq(Fu.FindUnitTargetProjectileIncoming(bot, 1200), undodgeable, "not dodgeable: unit-target still sees it")
	-- Anti-Mage's projectiles are left to the unit-target check's caster filter.
	local antimage = Stub.newUnit({ name = "npc_dota_hero_antimage", team = TEAM_DIRE })
	incoming(bot, { projectileAt(bot, 300, "antimage_mana_void", antimage) })
	T.eq(Fu.FindUnitTargetProjectileIncoming(bot, 1200), nil, "anti-mage caster")
	T.eq(Fu.IsUnitTargetProjectileIncoming(bot, 1200), false, "anti-mage caster: false")
	-- The first match is returned when several fly at once.
	local snake = projectileAt(bot, 500, "medusa_mystic_snake", enemy)
	local bolt = projectileAt(bot, 200, "sven_storm_bolt", enemy)
	incoming(bot, { attack, snake, bolt })
	T.eq(Fu.FindNotAttackProjectileIncoming(bot, 1200), bolt, "snake from a non-Medusa caster is skipped")
end)

T.test("will-cast finders: return the casting enemy and its spell", function()
	local Fu, bot, enemy = load()
	enemy._loc = bot:GetLocation() + Vector(500, 0, 0)
	T.eq(Fu.FindWillBeCastUnitTargetSpell(bot, 1200), nil, "nobody casting")
	T.eq(Fu.IsWillBeCastUnitTargetSpell(bot, 1200), false, "nobody casting: false")
	T.eq(Fu.IsWillBeCastPointSpell(bot, 1200), false, "nobody casting: point false")
	local finger = Stub.newAbility("lion_finger_of_death", enemy, true)
	finger.GetBehavior = function()
		return ABILITY_BEHAVIOR_UNIT_TARGET
	end
	enemy.IsCastingAbility = function()
		return true
	end
	enemy.IsBot = function()
		return true
	end
	enemy.GetCurrentActiveAbility = function()
		return finger
	end
	local caster, ability = Fu.FindWillBeCastUnitTargetSpell(bot, 1200)
	T.eq(caster, enemy, "unit-target caster")
	T.eq(ability, finger, "unit-target ability")
	T.eq(Fu.IsWillBeCastUnitTargetSpell(bot, 1200), true, "unit-target: true")
	T.eq(Fu.FindWillBeCastUnitTargetSpell(bot, 400), nil, "caster out of range")
	-- A point / no-target spell (behaviour 48 is one of the accepted values).
	local blast = Stub.newAbility("lina_light_strike_array", enemy, false)
	blast.GetBehavior = function()
		return 48
	end
	enemy.GetCurrentActiveAbility = function()
		return blast
	end
	caster, ability = Fu.FindWillBeCastPointSpell(bot, 1200)
	T.eq(caster, enemy, "point caster")
	T.eq(ability, blast, "point ability")
	T.eq(Fu.IsWillBeCastPointSpell(bot, 1200), true, "point: true")
end)
