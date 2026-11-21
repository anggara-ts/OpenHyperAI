-- Shared bot system: pure rules for Alchemist's Unstable Concoction (#34), no bot API calls, so they can be tested
-- with plain numbers. Used by BotsLib/hero_alchemist.lua.
--
-- Game data, 7.42: Valve datafeed hero 73 (alchemist_unstable_concoction): brew_time 5.0, brew_explosion 5.5,
-- min_stun 0.25, max_stun 1.7/2.2/2.7/3.2, max_damage 150/220/290/360, radius 250, AbilityCooldown 17,
-- AbilityManaCost 100. npc_heroes.txt in pak01_dir.vpk (read 2026-11-21), alchemist_unstable_concoction_throw:
-- AbilityCastPoint 0.2, projectile_speed 900. The hero file reads the values from the abilities at run time; the
-- numbers here are only the fallbacks and the tests.
local ConcoctionRules = {}

-- Stun of a throw after `brewed` seconds. The datafeed gives only the ends (min_stun at 0s, max_stun at brew_time)
-- and says the stun grows with the brew time; a straight line between them is assumed.
function ConcoctionRules.StunAt(brewed, minStun, maxStun, brewTime)
	if brewTime == nil or brewTime <= 0 then
		return maxStun
	end
	local share = math.max(0, math.min(1, brewed / brewTime))
	return minStun + (maxStun - minStun) * share
end

-- Seconds from the throw order until the stun lands: the cast point, then the projectile's flight.
ConcoctionRules.CAST_POINT = 0.2
ConcoctionRules.PROJECTILE_SPEED = 900
function ConcoctionRules.LandTime(distance, castPoint, projectileSpeed)
	castPoint = castPoint or ConcoctionRules.CAST_POINT
	projectileSpeed = projectileSpeed or ConcoctionRules.PROJECTILE_SPEED
	return castPoint + math.max(0, distance) / math.max(1, projectileSpeed)
end

-- Allies are finishing a low hero: under FINISH_HP of its HP and an allied hero is attacking it (game 063: 30% was
-- too low, Earth Spirit at 35% died in the start second).
ConcoctionRules.FINISH_HP = 0.4
function ConcoctionRules.AlliesFinishing(targetHp, alliesOnTarget)
	return targetHp < ConcoctionRules.FINISH_HP and alliesOnTarget >= 1
end

-- #34, game 064 (t=2056): a kill brew on Tiny at 7% HP, 280 away and running; Hoodwink's Acorn Shot was on its way
-- and Tiny died that second, so the brew had no target and blew up on him 5.5s later. No kill or engage brew on a
-- hero that dies before any throw lands, runners included:
--   health       the target's HP
--   ownHit       the damage one of his attacks does to it (after armor)
--   ownInReach   it is within his attack range (+150): his next hit lands about at once
--   allyPending  damage of our team already on its way to it (projectiles in flight, allies' next hits)
-- Returns "own-hit", "ally-damage" or nil (brew as usual).
function ConcoctionRules.FinishedWithoutBrew(health, ownHit, ownInReach, allyPending)
	if health == nil or health <= 0 then
		return nil
	end
	if ownInReach and (ownHit or 0) >= health then
		return "own-hit"
	end
	if (allyPending or 0) >= health then
		return "ally-damage"
	end
	return nil
end

-- What to do with a brew for a hero the allies are finishing (maintainer, 2026-11-21):
--   escapeKind     "runner" (moving, not facing him), "tp" (teleporting or channeling), "blink" (Blink ready and
--                  moving), or nil (held / not escaping)
--   otherEnemyNear another enemy hero within SAVE_RADIUS of him
-- Returns "help" (brew and throw early, timed to the escape), "save" (no brew: keep it for the other hero), or
-- "held" (nobody else to keep it for, so the cooldown is free: brew and throw early anyway).
ConcoctionRules.SAVE_RADIUS = 1200
function ConcoctionRules.FinishingPlan(escapeKind, otherEnemyNear)
	if escapeKind ~= nil then
		return "help"
	end
	if otherEnemyNear then
		return "save"
	end
	return "held"
end

-- Is a help throw due now?
--   kind      the escape kind ("runner", "blink", "tp") or "held"
--   brewed    seconds brewed; stun the stun a throw now gives (ConcoctionRules.StunAt)
--   tpLeft    seconds left of the target's teleport / channel (nil or 0: unknown)
--   landTime  seconds until a throw now lands (ConcoctionRules.LandTime)
-- runner / blink: once the stun covers about ESCAPE_STUN seconds, enough for the allies to finish it.
-- tp: the latest moment the stun still lands before the teleport ends, with TP_MARGIN to spare (the longer
-- brew gives a longer stun); at once when the time left is unknown or too short already.
-- held: as soon as the brew has started (HELD_MIN_BREWED): nobody else is near, a quick throw only helps.
ConcoctionRules.ESCAPE_STUN = 1.0
ConcoctionRules.TP_MARGIN = 0.6
ConcoctionRules.HELD_MIN_BREWED = 0.3
function ConcoctionRules.HelpThrowNow(kind, brewed, stun, tpLeft, landTime)
	if kind == "tp" then
		if tpLeft == nil or tpLeft <= 0 then
			return true
		end
		return tpLeft - (landTime or 0) <= ConcoctionRules.TP_MARGIN
	end
	if kind == "runner" or kind == "blink" then
		return stun >= ConcoctionRules.ESCAPE_STUN
	end
	return brewed >= ConcoctionRules.HELD_MIN_BREWED
end

-- Time left of an enemy Town Portal. Game 063 (t=1834) read 3.00 left on a Zeus TP, the full channel, so it is not
-- known whether the modifier read is the time left or the full duration. The hero file reads it twice, 0.2-0.5s
-- apart: TpReadIsReal says whether the read dropped (by at least half the time between the reads); nil when it
-- can't tell yet.
--   first, second  the two reads; dt the seconds between them
function ConcoctionRules.TpReadIsReal(first, second, dt)
	if first == nil or second == nil or dt == nil or dt <= 0 then
		return nil
	end
	return first - second >= dt * 0.5
end
-- Channel times (7.42 items.txt in pak01_dir.vpk): item_tpscroll AbilityChannelTime 3.0; item_travel_boots_2
-- tp_channel_time 2 (item_travel_boots lists none: the scroll's 3.0).
ConcoctionRules.TP_CHANNEL = 3.0
ConcoctionRules.TP_CHANNEL_BOOTS2 = 2.0
-- Seconds left of a teleport first seen at seenAt (channelTime: the target's channel). A read that proved real
-- (readIsReal true) is used as it is; otherwise (not proven yet, or not dropping) the time since it was first seen
-- decides, with the read only as an upper bound.
function ConcoctionRules.TpTimeLeft(seenAt, now, channelTime, read, readIsReal)
	local fromSeen = math.max(0, (channelTime or ConcoctionRules.TP_CHANNEL) - (now - seenAt))
	if read ~= nil and read > 0 then
		if readIsReal == true then
			return read
		end
		return math.min(fromSeen, read)
	end
	return fromSeen
end

-- A set from a list of names separated by spaces or line breaks.
local function NameSet(text)
	local set = {}
	for name in string.gmatch(text, "%S+") do
		set[name] = true
	end
	return set
end

-- #34, game 065: 5 of 10 brews that blew up on him had a target that turned invisible or hid as the brew started
-- (Clinkz Skeleton Walk t=1079 / 2559 / 2964, Nyx Vendetta t=3199, Dark Willow Shadow Realm t=2827), with nobody else
-- in sight. No kill, engage or help brew on a hero that has one of these ready, unless it can't use it now.
-- Names checked in the 7.42 game files (pak01_dir.vpk: scripts/npc/heroes/*.txt, scripts/npc/items.txt; the
-- tooltips in the English ability strings say each makes the hero invisible, hidden or untargetable):
-- clinkz_wind_walk, nyx_assassin_vendetta, dark_willow_shadow_realm, bounty_hunter_wind_walk, weaver_shukuchi,
-- templar_assassin_meld, puck_phase_shift, riki_tricks_of_the_trade, mirana_invis, sandking_sand_storm,
-- invoker_ghost_walk; Shadow Blade, Silver Edge, Glimmer Cape, Shadow Amulet, Trickster Cloak.
-- Not riki_permanent_invisibility: it is passive (DOTA_ABILITY_BEHAVIOR_PASSIVE), so it would block every brew on Riki.
ConcoctionRules.ESCAPE_NAMES = NameSet([[
clinkz_wind_walk nyx_assassin_vendetta dark_willow_shadow_realm bounty_hunter_wind_walk weaver_shukuchi
templar_assassin_meld puck_phase_shift riki_tricks_of_the_trade mirana_invis sandking_sand_storm
invoker_ghost_walk item_invis_sword item_silver_edge item_glimmer_cape item_shadow_amulet
item_trickster_cloak
]])

-- #34, game 065: 4 brews blew up on him because a stun, silence or Eul's caught him mid-brew (t=126, 1111, 1204,
-- 1856). Spells and items that stun, silence, hex, cyclone, fear, taunt or otherwise keep him from throwing.
-- Taken from the 7.42 game files: every active (not passive) hero ability whose tooltip (English ability strings)
-- or AbilityValues name a stun, silence, hex, sleep, fear, taunt or petrify, minus self-stuns and talents; plus
-- channelled and other disables whose tooltip says the target can't act (Shackles, Dismember, Fiend's Grip,
-- Chronosphere, Black Hole, Duel, Electric Vortex, Winter's Curse, Astral Imprisonment, Tornado, Cold Snap, Walrus
-- Punch, Flaming Lasso, Will-O-Wisp, Kez's Talon Toss); items: Eul's, Wind Waker, Scythe of Vyse, Orchid,
-- Bloodthorn, Abyssal Blade (items.txt tooltips: cyclone, hex, silence, stun).
ConcoctionRules.DISABLE_NAMES = NameSet([[
ancient_apparition_cold_feet ancient_apparition_ice_blast antimage_mana_void arc_warden_spark_wraith
axe_berserkers_call bane_fiends_grip bane_nightmare batrider_flamebreak batrider_flaming_lasso
beastmaster_primal_roar bloodseeker_blood_bath brewmaster_cinder_brew brewmaster_earth_hurl_boulder
centaur_hoof_stomp chaos_knight_chaos_bolt dark_willow_cursed_crown dark_willow_terrorize
dawnbreaker_fire_wreath dawnbreaker_solar_guardian death_prophet_silence disruptor_glimpse
disruptor_static_storm doom_bringer_doom doom_bringer_infernal_blade dragon_knight_dragon_tail
drow_ranger_silence drow_ranger_wave_of_silence earth_spirit_boulder_smash earth_spirit_geomagnetic_grip
earth_spirit_magnetize earth_spirit_rolling_boulder earthshaker_fissure elder_titan_echo_stomp
enigma_black_hole enigma_malefice faceless_void_chronosphere grimstroke_ink_creature grimstroke_spirit_walk
gyrocopter_homing_missile hoodwink_bushwhack huskar_inner_fire huskar_life_break invoker_cold_snap
invoker_tornado jakiro_ice_path keeper_of_the_light_will_o_wisp kez_talon_toss kunkka_ghostship
kunkka_torrent largo_frogstomp legion_commander_duel leshrac_split_earth lina_light_strike_array lion_impale
lion_voodoo luna_lucent_beam lycan_howl magnataur_reverse_polarity marci_companion_run marci_unleash
mars_spear medusa_stone_gaze mirana_arrow monkey_king_boundless_strike morphling_adaptive_strike_agi
muerta_dead_shot muerta_the_calling necrolyte_reapers_scythe nevermore_requiem night_stalker_crippling_fear
night_stalker_void nyx_assassin_impale nyx_assassin_spiked_carapace obsidian_destroyer_astral_imprisonment
ogre_magi_fireblast pangolier_gyroshell phoenix_supernova primal_beast_onslaught primal_beast_pulverize
puck_dream_coil puck_waning_rift pudge_dismember pudge_meat_hook rattletrap_hookshot riki_smoke_screen
ringmaster_tame_the_beasts ringmaster_the_box ringmaster_wheel rubick_telekinesis sandking_burrowstrike
shadow_shaman_shackles shadow_shaman_voodoo silencer_curse_of_the_silent silencer_glaives_of_wisdom
silencer_global_silence silencer_last_word skeleton_king_hellfire_blast skywrath_mage_ancient_seal
slardar_slithereen_crush snapfire_firesnap_cookie snapfire_scatterblast snapfire_spit_creep
sniper_assassinate spectre_haunt spirit_breaker_charge_of_darkness storm_spirit_electric_vortex
sven_storm_bolt techies_stasis_trap techies_sticky_bomb techies_suicide templar_assassin_psionic_trap
terrorblade_terror_wave tidehunter_ravage tiny_avalanche tusk_snowball tusk_walrus_punch undying_bite
vengefulspirit_magic_missile venomancer_latent_poison venomancer_venomous_gale visage_summon_familiars
void_spirit_resonant_pulse warlock_rain_of_chaos windrunner_shackleshot winter_wyvern_splinter_blast
winter_wyvern_winters_curse witch_doctor_paralyzing_cask zuus_lightning_bolt item_cyclone item_wind_waker
item_sheepstick item_orchid item_bloodthorn item_abyssal_blade
]])

-- A spell of an enemy hero is ready: learned, off cooldown, enough mana (as far as the bot API shows it on an
-- enemy handle; mana nil: unknown, not checked).
function ConcoctionRules.SpellReady(level, cooldownLeft, manaCost, mana)
	if level == nil or level <= 0 then
		return false
	end
	return (cooldownLeft or 0) <= 0 and (mana == nil or manaCost == nil or mana >= manaCost)
end

-- #34, game 065 t=126: a retreat brew on Nyx at 310 was held to 5.5s (the retreat throw needs the retreat mode,
-- and his mode changed) and he was stunned at 5.4s. A brew started by the retreat rule is thrown at the first hero
-- in range from RETREAT_BREW_THROW seconds brewed, whatever his mode is then.
ConcoctionRules.RETREAT_BREW_THROW = 1.5
function ConcoctionRules.RetreatBrewThrowNow(brewWhy, brewed, targetInRange)
	return brewWhy == "retreat" and brewed >= ConcoctionRules.RETREAT_BREW_THROW and targetInRange == true
end

-- #34, game 065: throw early instead of holding the brew while a disable can catch him. From DISABLE_RISK_AFTER
-- seconds brewed (game data, datafeed hero 73: 2s is 40% of max_damage and, on a straight line, a 0.83-1.43s stun (min_stun 0.25, max_stun 1.7-3.2)):
--   disableReady  the name of a disable an enemy hero within DISABLE_RISK_RANGE has ready, or nil
--   hpLost        share of his max HP lost within the last second (being hit)
-- Returns "disable-ready", "hit" or nil.
ConcoctionRules.DISABLE_RISK_AFTER = 2.0
ConcoctionRules.DISABLE_RISK_RANGE = 900
ConcoctionRules.HIT_HP_SHARE = 0.1
function ConcoctionRules.DisableRisk(brewed, disableReady, hpLost)
	if brewed < ConcoctionRules.DISABLE_RISK_AFTER then
		return nil
	end
	if disableReady ~= nil then
		return "disable-ready"
	end
	if (hpLost or 0) >= ConcoctionRules.HIT_HP_SHARE then
		return "hit"
	end
	return nil
end

-- #34, game 065 t=1198: retreat said 0.51 and blocked an engage brew for one think; the next think (t=1199) an
-- engage brew started at his 31% HP and blew up on him once he was stunned. The block holds RETREAT_HOLD seconds
-- after the retreat mode last wanted him out.
ConcoctionRules.RETREAT_HOLD = 2.0
function ConcoctionRules.RetreatHeld(wantedNow, lastWantedAt, now)
	if wantedNow then
		return true
	end
	return lastWantedAt ~= nil and now - lastWantedAt <= ConcoctionRules.RETREAT_HOLD
end

return ConcoctionRules
