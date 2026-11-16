HERO: chen | STATUS: CHANGED
- CHANGE: Zealot cast with Action_UseAbilityOnEntity(s, b) instead of Action_UseAbility | WHY: datafeed chen_zealot behavior 8 (unit target); "If Chen is targeted, it will teleport all units you control", what ConsiderZealot wants
- CHANGE: ConsiderDivineFavor retreat branches return the ally (L) or Chen (b) instead of the chasing enemy | WHY: datafeed chen_divine_favor target_team 1 (allies only); it was cast on enemies
- FLAG: chen_summon_convert not in the datafeed; ConsiderSummonConvert never fires | WHY: removed ability; FuncLib/data/spell_list.lua:109 still lists it
- FLAG: pos_1/pos_2 build (Dagon, Travel Boots, Octarine) | WHY: odd for a support but valid
HERO: spectre | STATUS: CHANGED
- CHANGE: ConsiderSpectralDagger kill check MAGICAL instead of PURE | WHY: datafeed spectre_spectral_dagger damage 2 (magical)
- CHANGE: both kill branches aim at c.GetCorrectLoc(T, travel time) | WHY: U was a travel time passed to Action_UseAbilityOnLocation as a location; datafeed speed 800
- FLAG: sell pair { black_king_bar, quelling_blade } | WHY: BKB not in the build, Quelling Blade never sold
HERO: doom_bringer | STATUS: CHANGED
- CHANGE: ConsiderDevour eats Ancients when devour can_target_ancient > 0 or HasAghanimsShard (was special_bonus_unique_doom_2:IsTrained()) | WHY: that talent isn't among Doom's datafeed talents; Ancient Devour is now the Shard
- CHANGE: ConsiderScorchedEarth farming branch tested the undefined global nEnemyLaneCreeps; now tests O ~= nil | WHY: Scorched Earth was never used for farming
- CHANGE: ConsiderInfernalBlade reads burn_damage_pct as Float | WHY: datafeed 0.5/1.75/3/4.25; Int truncated it
- FLAG: sell pair { power_treads, quelling_blade } | WHY: Doom buys Phase Boots, Quelling Blade never sold
HERO: ancient_apparition | STATUS: CHANGED
- CHANGE: talent handle t = special_bonus_unique_ancient_apparition_1 (was _7) | WHY: datafeed _1 is "AoE Cold Feet", _7 is now Chilling Touch range; the AoE cast logic unchanged
- CHANGE: ConsiderIceVortex team-fight check `#R` (always true) -> `#R >= 1` | WHY: it could cast with no enemy hero in the vortex
- FLAG: ConsiderIceBlastRelease calls a3.ability:GetName() with no nil check | WHY: possible runtime error
HERO: ursa | STATUS: CHANGED
- CHANGE: ConsiderEarthshock reads hop_duration as Float | WHY: datafeed 0.25; Int gave 0
- CHANGE: Earthshock lane-creep last-hit check MAGICAL instead of PHYSICAL | WHY: datafeed ursa_earthshock damage 2
HERO: spirit_breaker | STATUS: CHANGED
- CHANGE: Planar Pocket cast with Action_UseAbilityOnEntity; ConsiderPlanarPocket returns a target (team fight: most hurt recently damaged ally in range, else a nearby enemy hero; engaging: the target; retreating: the chaser) | WHY: datafeed spirit_breaker_planar_pocket behavior 8, target_team 3, heroes only, range 700; it was cast with no target
- CHANGE: ConsiderNetherStrike reads "damage" instead of GetAbilityDamage() | WHY: datafeed damage 150/250/350, no AbilityDamage
- CHANGE: ConsiderChargeOfDarkness farming branch returned T[3] (neutral list, can be nil); now S[3], the lane creep it checked | WHY: wrong variable
- CHANGE: ConsiderChargeOfDarkness "help an ally" branch returned C (unchecked); now Y, the ally's validated target | WHY: wrong variable
HERO: gyrocopter | STATUS: CHANGED
- CHANGE: ConsiderRocketBarrage reads "rocket_damage" instead of "value" | WHY: datafeed 8/14/20/26, no "value"; kill check used 0
- CHANGE: ConsiderHomingMissile reads "hit_damage" instead of GetAbilityDamage() | WHY: datafeed 90/180/270/360, no AbilityDamage
- CHANGE: ConsiderCallDown reads "damage" instead of "damage_first" | WHY: datafeed damage 200/350/500; damage_first doesn't exist
HERO: alchemist | STATUS: CHANGED
- CHANGE: ConsiderAcidSpray engaging branch defines local nInRangeEnemy (enemy heroes within 900) | WHY: it tested an undefined global, so Acid Spray was never used when engaging
- FLAG: sell list has three pairs triggered by item_assault, not in the build | WHY: Wand, Drum, Soul Ring never sold
HERO: invoker | STATUS: FLAGGED
- FLAG: CastInvokerSpell casts Deafening Blast no-target from level 25, which needs the Radial Deafening Blast talent (special_bonus_unique_invoker_2, 7th in the datafeed); the default talent build j[1] takes the 8th (_13) | WHY: a j[1] Invoker would issue a no-target cast of a point spell at 25 (fixed by the coordinator, see integration notes)
HERO: silencer | STATUS: CHANGED
- CHANGE: ConsiderW returned the undefined global WeakestEnemy (nil); now returns ad, the unit it checked | WHY: Glaives cast on a nil target
- CHANGE: sil_RealDamage counts the Glaives bonus as MAGICAL instead of PURE | WHY: datafeed silencer_glaives_of_wisdom damage 2
- FLAG: ConsiderE reads the AoE Last Word radius via talent "value" | WHY: talent uses bonus_radius; probably 0; unverified
HERO: obsidian_destroyer | STATUS: CHANGED
- CHANGE: sell pairs were reversed (a Wand sold BKB; a Null Talisman sold Scythe and Shiva's); now { black_king_bar, magic_wand, sheepstick, null_talisman, shivas_guard, null_talisman } | WHY: pairs are { owned, sold }
- CHANGE: ConsiderAstralImprisonment reads prison_duration as Float | WHY: datafeed 1.75/2.5/3.25/4; Int truncated it
- CHANGE: ConsiderArcaneOrb kill checks use WillMixedDamageKillTarget(attack as physical, mana*pct as pure) instead of all-magical | WHY: datafeed arcane_orb damage 4 (pure); the attack is physical
- CHANGE: ConsiderSanitysEclipse uses max(0, OD max mana - target max mana) instead of the current-mana difference | WHY: datafeed "difference between your max mana and the target's max mana"; prison + Meteor Hammer timing and build untouched
HERO: lycan | STATUS: CHANGED
- CHANGE: skill build 1: Shapeshift's second point moved from entry 12 (level 13) to entry 11 (level 12) | WHY: ultimate at levels 6/12
- FLAG: lycan_wolf_bite (Scepter, on an allied hero) fetched but never cast though every build buys the Blessing | WHY: new logic needed
HERO: brewmaster | STATUS: CHANGED
- CHANGE: ConsiderLiquidCourage defines a local nAllyHeroes | WHY: pairs() on an undefined global errors every think once the Shard makes it castable
- CHANGE: Liquid Courage cast with ActionQueue_UseAbilityOnEntity instead of OnLocation | WHY: the target is a hero handle; Shard text "Toss a strong drink to a teammate or drink it yourself"
- FLAG: brewmaster_primal_companion not in the datafeed; ConsiderPrimalCompanion never fires (its caller would also cast Primal Split) | WHY: removed ability
HERO: shadow_demon | STATUS: CHANGED
- CHANGE: ConsiderDemonicCleanse targets an ally in range who is disabled or taunted (not illusions) and returns that ally | WHY: datafeed demonic_cleanse target_team 1 (allies); old code scanned enemies, required disabled AND taunted, returned the undefined global enemyHero (nil)
- CHANGE: ConsiderShadowPoison checked "modifier_dazzle_shallow_graves" (typo) -> "modifier_dazzle_shallow_grave" | WHY: never matched; poison-on-disrupted logic untouched
HERO: lone_druid | STATUS: CHANGED
- CHANGE: skill build k { 2,2,6,2,2,3,6,3,3,3,6,1,1,1,1 } -> { 2,2,3,2,2,6,3,3,3,1,6,1,1,1,6 } | WHY: the ultimate was at entry 3 (level 3, unlearnable) and missing at 6
- CHANGE: added ConsiderEntangle (team fight AoE spot with 2+ heroes, the target when engaging, a chaser when retreating) | WHY: datafeed lone_druid_entangle active, behavior 48 (point/AoE), range 700, radius 350; never cast
- FLAG: build l maxes index 1 (now Entangle) first and replaces k on every reload (roleType always "pos_1_w_bear") | WHY: looks written when index 1 was the Spirit Bear
- FLAG: `SafeAbility(...) ~= nil` on line 42 is always true | WHY: o["pos_1"] never reached; harmless
HERO: chaos_knight | STATUS: CHANGED
- CHANGE: ConsiderQ kill threshold = "damage_min" (90/120/150/180) instead of 30 + 30*lvl + 45.6 | WHY: datafeed damage is random between damage_min and damage_max; old formula ran above the minimum
- CHANGE: ConsiderW Roshan and Tormentor branches return y as the target | WHY: datafeed reality_rift behavior 8; these branches passed no target
FILES: BotsLib/hero_chen.lua, BotsLib/hero_spectre.lua, BotsLib/hero_doom_bringer.lua, BotsLib/hero_ancient_apparition.lua, BotsLib/hero_ursa.lua, BotsLib/hero_spirit_breaker.lua, BotsLib/hero_gyrocopter.lua, BotsLib/hero_alchemist.lua, BotsLib/hero_silencer.lua, BotsLib/hero_obsidian_destroyer.lua, BotsLib/hero_lycan.lua, BotsLib/hero_brewmaster.lua, BotsLib/hero_shadow_demon.lua, BotsLib/hero_lone_druid.lua, BotsLib/hero_chaos_knight.lua
