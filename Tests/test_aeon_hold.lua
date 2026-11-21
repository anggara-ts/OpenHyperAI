-- FuncLib/systems/aeon_hold.lua (issue #47): pure damage spells are held while the caster, or the enemy they are
-- aimed at, holds the Aeon Disk buff (7.42: 2.5s, all damage dealt and taken is zero).
local T = ...

local AEON = "modifier_item_aeon_disk_buff"

local function load(time)
	local bot = T.stub.reset({ hero = "npc_dota_hero_lina", time = time or 600 })
	require(GetScriptDirectory() .. "/FuncLib/systems/global_overrides")
	local AeonHold = require(GetScriptDirectory() .. "/FuncLib/systems/aeon_hold")
	return AeonHold, bot
end

-- Gives a unit the Aeon buff with `left` seconds remaining.
local function giveAeon(unit, left)
	unit.HasModifier = function(_, name)
		return name == AEON
	end
	unit.GetModifierByName = function(_, name)
		return name == AEON and 0 or -1
	end
	unit.GetModifierRemainingDuration = function()
		return left
	end
end

local function spell(name, caster, castPoint)
	local ability = T.stub.newAbility(name, caster, false)
	ability.GetCastPoint = function()
		return castPoint or 0.3
	end
	return ability
end

T.test("aeon hold: the rules", function()
	local AeonHold = load()
	local slave = AeonHold.SPELLS.lina_dragon_slave
	T.eq(AeonHold.SelfHold(slave, 2.4, 0.35), true, "2.4s left, lands at 0.85s")
	T.eq(AeonHold.SelfHold(slave, 0.5, 0.35), false, "lands after the buff ends")
	T.eq(AeonHold.SelfHold(nil, 2.4, 0.35), false, "unlisted spell")
	T.eq(AeonHold.AreaHold(1, 0), true, "only the holder in the area")
	T.eq(AeonHold.AreaHold(1, 1), false, "another enemy hero is hit too")
	T.eq(AeonHold.AreaHold(0, 2), false, "no holder")
	T.eq(AeonHold.SPELLS.lina_light_strike_array, nil, "a stun is not held")
	T.eq(AeonHold.SPELLS.item_dagon, nil, "items are not held")
end)

T.test("aeon hold: own buff - Dragon Slave reads not castable, Light Strike Array still castable", function()
	-- The stub's own IsFullyCastable reads false: make the engine's read true, then install over it.
	T.stub.reset({ hero = "npc_dota_hero_lina", time = 600 })
	CDOTABaseAbility_BotScript.IsFullyCastable = function()
		return true
	end
	local AeonHold = require(GetScriptDirectory() .. "/FuncLib/systems/aeon_hold")
	AeonHold.Install()
	local bot = GetBot()
	local slave = spell("lina_dragon_slave", bot, 0.35)
	local lsa = spell("lina_light_strike_array", bot, 0.45)
	T.eq(slave:IsFullyCastable(), true, "no buff: castable")
	giveAeon(bot, 2.2)
	AeonHold.Track(bot)
	T.eq(AeonHold.IsActive(), true, "the bot's buff turns the hold on")
	T.eq(slave:IsFullyCastable(), false, "Dragon Slave held under the bot's own buff")
	T.eq(lsa:IsFullyCastable(), true, "Light Strike Array (stun) still castable")
	local logged = false
	for _, line in ipairs(T.stub.printed) do
		if
			string.find(line, "[OHA-CAST]", 1, true)
			and string.find(line, "why=aeon-self spell=lina_dragon_slave", 1, true)
		then
			logged = true
		end
	end
	T.ok(logged, "hold logged")
	-- Buff about to end: the damage would land after it, so no hold.
	giveAeon(bot, 0.4)
	T.eq(slave:IsFullyCastable(), true, "0.4s left: cast")
end)

T.test("aeon hold: a cast order of a listed spell under the bot's own buff is refused, a stun goes out", function()
	local AeonHold, bot = load()
	local slave = spell("lina_dragon_slave", bot, 0.35)
	local lsa = spell("lina_light_strike_array", bot, 0.45)
	giveAeon(bot, 2.0)
	local loc = Vector(0, 0, 0)
	T.eq(AeonHold.RefuseCast(bot, slave, "location", loc), true, "Dragon Slave refused")
	T.eq(AeonHold.RefuseCast(bot, lsa, "location", loc), false, "Light Strike Array allowed")
end)

T.test("aeon hold: an enemy holder alone in the area is not nuked, a second enemy hero there lets it go", function()
	local AeonHold, bot = load()
	local slave = spell("lina_dragon_slave", bot, 0.35)
	local enemies = GetUnitList(UNIT_LIST_ENEMY_HEROES)
	local holder, other = enemies[1], enemies[2]
	holder._loc = Vector(1000, 1000, 0)
	other._loc = Vector(3000, 3000, 0)
	giveAeon(holder, 2.4)
	T.eq(AeonHold.RefuseCast(bot, slave, "location", holder:GetLocation()), true, "only the holder in the wave")
	T.eq(AeonHold.IsActive(), true, "the hold is on")
	other._loc = Vector(1100, 1000, 0)
	T.eq(AeonHold.RefuseCast(bot, slave, "location", holder:GetLocation()), false, "another hero in the wave")
	-- Unit target: the holder himself.
	local laguna = spell("lina_laguna_blade", bot, 0.3)
	T.eq(AeonHold.RefuseCast(bot, laguna, "entity", holder), true, "Laguna Blade on the holder")
	T.eq(AeonHold.RefuseCast(bot, laguna, "entity", other), false, "Laguna Blade on another hero")
	-- An ally with the buff is not an enemy holder.
	local ally = GetTeamMember(2)
	giveAeon(ally, 2.4)
	T.eq(AeonHold.RefuseCast(bot, laguna, "entity", ally), false, "ally target")
end)

T.test("aeon hold: the hold ends with the buff", function()
	local AeonHold, bot = load(600)
	local enemies = GetUnitList(UNIT_LIST_ENEMY_HEROES)
	local holder = enemies[1]
	giveAeon(holder, 1.5)
	local laguna = spell("lina_laguna_blade", bot, 0.3)
	T.eq(AeonHold.RefuseCast(bot, laguna, "entity", holder), true, "refused")
	T.stub.time = 602
	AeonHold.Track(bot)
	T.eq(AeonHold.IsActive(), false, "cleared after the buff")
end)

T.test("aeon hold: installed from global_overrides, tracked from ItemUsageThink", function()
	local src = T.read("FuncLib/systems/global_overrides.lua")
	T.ok(src:find('FuncLib/systems/aeon_hold").Install()', 1, true) ~= nil, "no Install() in global_overrides")
	local usage = T.read("ability_item_usage_generic.lua")
	T.ok(usage:find("pcall(AeonHold.Track, bot)", 1, true) ~= nil, "no Track in ItemUsageThink")
end)
