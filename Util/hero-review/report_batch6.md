HERO: meepo | STATUS: OK - ability names (earthbind/poof/petrify/megameepo/fling) and special values match the datafeed; Meepo's special skill-list path; items valid; Poof/Earthbind targets correct
HERO: treant | STATUS: CHANGED
- CHANGE: ConsiderLeechSeed + caller: Leech Seed always cast on a unit (engage-group branch returns the hero G, range-checked; Roshan/Tormentor return the creature); point-cast path removed; caller checks a valid target | WHY: datafeed treant_leech_seed behavior 135176 = unit target + autocast + attack, range 150; Action_UseAbilityOnLocation on it could never cast
HERO: ogre_magi | STATUS: CHANGED
- CHANGE: r/s fetched by name ("ogre_magi_unrefined_fireblast", "ogre_magi_smash") instead of g[4]/g[5] | WHY: datafeed: both are granted (Scepter/Shard) abilities with the hidden bit; slot indexes depend on how the ability list is built
- FLAG: Fireblast damage adds u:GetSpecialValueInt("value") with u = f[8] (Multicast-chance talent) | WHY: the Fireblast-damage talent is special_bonus_unique_ogre_magi_2 (key bonus_fireblast_damage); reads 0 today, left alone
HERO: undying | STATUS: CHANGED
- CHANGE: ConsiderSoulRip kill branch returns the enemy N (it returned b, healing Undying); damage = damage_per_unit * min(heroes + creeps, max_units) (was heroes * creeps, compounding); N must be in cast range | WHY: datafeed undying_soul_rip damage_per_unit 14/26/38/50, max_units 10, cast range 750 (search radius was 1300)
- FLAG: skill build puts no point in Soul Rip until level 11 and maxes Tombstone second, though pos 4/5 rely on the heal | WHY: role/taste, unchanged
HERO: rubick | STATUS: CHANGED
- CHANGE: SkillsComplement channel guard uses radius 1200 instead of `nRadius + 300` | WHY: nRadius is a local of ConsiderFadeBolt (undefined here) -> "arithmetic on nil" whenever Rubick cast or channelled above 30% HP
- FLAG: rubick_telekinesis_land / rubick_empty1 / rubick_empty2 not in the datafeed | WHY: engine sub-ability/placeholder names, can't be verified there
HERO: disruptor | STATUS: OK - earlier-session work intact (Field then Storm, storm on a group or pos 1-2 core, Glimpse combo, Scepter build); names and special values match; items valid; harmless duplicated Tormentor block in ConsiderThunderStrike
HERO: nyx_assassin | STATUS: OK - names match (Jolt unit-target AoE, Impale point, Vendetta pure = ComboDamage); nyx_assassin_unburrow is an engine sub-ability; build/items valid
HERO: naga_siren | STATUS: OK - Mirror Image/Song no-target, Ensnare unit-target match; Reel In / song cancel are sub-abilities; items valid
HERO: keeper_of_the_light | STATUS: OK - Illuminate, Blinding Light, Chakra Magic, Solar/Radiant Bind, Will-o-Wisp targeting match; Recall is a facet ability; items valid
HERO: wisp | STATUS: FLAGGED
- FLAG: items table has only pos_1/pos_4/pos_5; hero_builder falls back to an arbitrary list for pos_2/pos_3 | WHY: a pos 2/3 Io gets a support or carry list at random; design decision
- FLAG: wisp_tether_break fetched without SafeAbility | WHY: sub-ability not in the datafeed
HERO: visage | STATUS: CHANGED
- CHANGE: ConsiderSoulAssumption engage branch picks the lowest-HP hero (`X < W`) | WHY: with W = 20000 and `W < X`, only a hero above 20000 HP qualified -> the full-stack engage cast never fired
HERO: slark | STATUS: CHANGED
- CHANGE: skill build {1,2,3,1,1,6,1,4,2,2,6,2,4,4,6} -> {1,2,3,1,1,6,1,3,2,2,6,2,3,3,6} | WHY: datafeed: Essence Shift is innate; learnable basics are Dark Pact, Pounce, Saltwater Shiv; index 4 is not a learnable basic, so Shiv got 1 point
- CHANGE: Depth Shroud local s from GetAbilityByName("slark_depth_shroud") instead of g[4] | WHY: granted point/AoE ability; ConsiderAS point-casts s
HERO: medusa | STATUS: OK - Gorgon Grasp physical (datafeed 1) matches; Snake/Stone Gaze/Split Shot names and values match; earlier Snake nil-target fix intact; items valid
HERO: troll_warlord | STATUS: CHANGED
- CHANGE: ConsiderWhirlingAxesMelee reads max_range and damage from r (melee axes) instead of q (ranged axes) | WHY: datafeed: max_range 450 and damage 75-210 exist only on troll_warlord_whirling_axes_melee; from the ranged axes they read 0 (search radius 0)
- FLAG: skill build {2,5,4,...} never takes Whirling Axes (Melee) (index 3), so ConsiderWhirlingAxesMelee never runs | WHY: 4 basics for 12 slots, build choice
HERO: centaur | STATUS: CHANGED
- CHANGE: ConsiderDoubleEdge Roshan and Tormentor branches return the target C (returned only the desire); the cast also requires c.IsValid(x) | WHY: the "nil-target" refusals in game 032; Double Edge is unit-target (datafeed behavior 40, range 175)
- FLAG: centaur_mount (Hitch a Ride) not in the datafeed | WHY: sub-ability of centaur_work_horse; SafeAbility covers it if absent
HERO: magnataur | STATUS: CHANGED
- CHANGE: pos_2/pos_3 skill builds: ultimate moved from entry 10 to 11; pos_4/pos_5: entries 14/15 swapped (6,2 -> 2,6) | WHY: ultimate ranks need levels 6/12/18; entry 10 is level 11 and entry 14 is level 16, so those points fell to the fallback
FILES: BotsLib/hero_centaur.lua, BotsLib/hero_treant.lua, BotsLib/hero_ogre_magi.lua, BotsLib/hero_undying.lua, BotsLib/hero_rubick.lua, BotsLib/hero_visage.lua, BotsLib/hero_slark.lua, BotsLib/hero_troll_warlord.lua, BotsLib/hero_magnataur.lua
