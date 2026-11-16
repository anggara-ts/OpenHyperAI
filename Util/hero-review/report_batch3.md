HERO: tinker | STATUS: FLAGGED
- FLAG: tinker_keen_teleport (local s; ConsiderKeenConveyance, Rearm / heal-in-base logic) not in the datafeed (laser, march_of_the_machines, deploy_turrets, warp_grenade, rearm, eureka; no facets) | WHY: a talent still reads "Keen Conveyance Channel Time" (special_bonus_unique_tinker_5), so not removed; through the safe proxy it does nothing: Tinker never teleports and the healInBase plan relies on it
- FLAG: q fallback "or SafeAbility(...tinker_defense_matrix...)" (lines 108, 155) is dead code | WHY: defense_matrix not in the datafeed and SafeAbility returns a truthy proxy; deploy_turrets exists, harmless
HERO: sniper | STATUS: CHANGED
- CHANGE: ConsiderQ (Shrapnel) W.cout -> W.count | WHY: FindAoELocation's field is "count"; ".cout" was always nil, so the 2+ heroes team-fight Shrapnel branch never fired
- FLAG: same typo in BotsLib/hero_muerta.lua:241 (V.cout) | WHY: batch 8's file (passed on)
- FLAG: Assassinate rank 2 at entry 13 (level 14) instead of 11 | WHY: still learnable
- FLAG: pos_3/4/5 = pos_1 (carry build) | WHY: alias style
HERO: necrolyte | STATUS: CHANGED
- CHANGE: ConsiderW (Ghost Shroud) removed "and false" from the IsGoingOnSomeone branch | WHY: branch was switched off; it has its own guards (target running, out of 430 range and fleeing or Necro under 25% HP, alone, inside the datafeed slow_aoe of 700). Dormant behaviour restored; veto if it was off on purpose
HERO: warlock | STATUS: OK - names, builds, items, spell behaviours check out; the "s:IsTrained() and false" Shadow Word branch stays off on purpose (it would aim a unit-target spell at a location)
HERO: beastmaster | STATUS: OK - names in the datafeed, build maxed (axes, boar, hawk); items valid; Axes and Roar magical, cast types match; earlier fixes kept
HERO: queenofpain | STATUS: CHANGED
- CHANGE: ConsiderE (Scream of Pain) O = q:GetSpecialValueInt("damage") instead of GetAbilityDamage() | WHY: datafeed Scream has no AbilityDamage; "damage" 90/175/260/345; it read 0, so the kill and lane last-hit checks never fired
- CHANGE: ConsiderW (Blink) Z reads "damage" too; the lane-travel "return BOT_ACTION_DESIRE_VERYHIGH" also returns S, T | WHY: Z = 0 kept that branch dead; fixed, it would return no location and Blink would be cast at nil
- CHANGE: ConsiderR (Sonic Wave) removed the HasScepter damage_scepter override | WHY: datafeed Sonic Wave has no damage_scepter (Scepter now upgrades Shadow Strike), so with a Scepter the damage read 0; damage stays PURE (dmg 4)
HERO: venomancer | STATUS: CHANGED
- CHANGE: ConsiderVenomousGale kill check = strike + tick * (duration / tick_interval) instead of strike * tick | WHY: datafeed strike_damage 25-100, tick_damage 10-100 every 3s for 15s; old formula gave 250 at level 1 vs a real 75. Build correct (index 3 plague_ward; Poison Sting is innate at 4)
- FLAG: ConsiderPlagueWard hard-codes a0 = 20 (dead self-cast branches, which would also be wrong: point-target ward); wards only placed when engaging or retreating | WHY: widening it would be a redesign
HERO: faceless_void | STATUS: FLAGGED
- FLAG: faceless_void_time_zone (local s, ConsiderTimezone, q swap when Chronosphere is hidden, 7.37 chat line) not in the datafeed; Chronosphere is the ultimate | WHY: stale 7.37 facet code; does nothing (proxy), not removed
- FLAG: pos_2/3/4/5 = pos_1 (carry build) | WHY: alias style
HERO: skeleton_king | STATUS: CHANGED
- CHANGE: p fetched as skeleton_king_bone_guard instead of skeleton_king_spectral_blade | WHY: spectral_blade not in the datafeed; W is bone_guard (no-target); the "if not p or p:IsHidden()" fallback never ran (NIL_ABILITY is truthy, IsHidden false), so ConsiderW could not cast Bone Guard
- FLAG: pos_2/4/5 = pos_3 (core build) | WHY: alias style
HERO: death_prophet | STATUS: CHANGED
- CHANGE: ConsiderQ (Crypt Swarm) O = p:GetSpecialValueInt("damage") instead of GetAbilityDamage() | WHY: datafeed has no AbilityDamage; "damage" 100/175/250/325; with 0 the kill check never fired and the lane last-hit had no HP cap
- FLAG: generic "Q" branch at the end of ConsiderQ still off ("and false") | WHY: it spams Swarm at any enemy hero from level 15 with no mana guard; likely off on purpose
HERO: phantom_assassin | STATUS: CHANGED
- CHANGE: ConsiderE (Blur) "an == 0" -> "#an == 0" | WHY: an is the tower table; a table == 0 is always false, so the "blur in the enemy area with no heroes and towers near" branch never fired
- FLAG: pos_2/3/4/5 = pos_1 | WHY: alias style
HERO: pugna | STATUS: CHANGED
- CHANGE: "local hNetherWard" moved above a.MinionThink | WHY: declared after MinionThink, so MinionThink wrote a global and ConsiderW's Decrepify-the-ward check read an always-nil local; datafeed pugna_decrepify notes "Can be used on your Nether Ward"
- CHANGE: ConsiderQ reads the delay with GetSpecialValueFloat("delay") | WHY: datafeed Nether Blast delay 0.8; Int truncated it to 0
- FLAG: talent f[7] "value" added to Nether Blast damage | WHY: datafeed key bonus_blast_damage; likely adds 0
HERO: templar_assassin | STATUS: CHANGED
- CHANGE: MinionThink wraps the trap unit's templar_assassin_self_trap in SafeAbility | WHY: not in the datafeed; if gone, p:IsFullyCastable() on nil would error every MinionThink
- FLAG: templar_assassin_trap / self_trap not in the datafeed (only psionic_trap, trap_teleport) | WHY: possibly unlisted sub-abilities
- FLAG: pos_2/3/4/5 = pos_1 | WHY: alias style
HERO: viper | STATUS: OK - names in the datafeed, both builds valid, items valid, Nose Dive point-cast, magical damage; reworked Viper Strike / Poison Attack untouched; pos_4/5 = pos_3 (core build, alias style)
HERO: luna | STATUS: CHANGED
- CHANGE: ConsiderMoonGlaives returns NONE when p:IsPassive() | WHY: datafeed luna_moon_glaive is passive (behavior 2); a passive read as castable would order a cast and skip Lunar Orbit, Eclipse and Lucent Beam that think
- FLAG: talent f[6] "value" added to Lucent Beam damage | WHY: datafeed beam talent is the 4th (key bonus_beam_damage); likely adds 0
- FLAG: pos_2/3/4/5 = pos_1 | WHY: alias style
HERO: dragon_knight | STATUS: OK - names in the datafeed, builds valid (Shard Fireball not levelled), items valid, Breathe Fire / Dragon Tail / Fireball / Elder Dragon Form cast types match, magical damage; pos_4/5 = pos_2 (core build, alias style)
FILES: BotsLib/hero_sniper.lua, BotsLib/hero_necrolyte.lua, BotsLib/hero_queenofpain.lua, BotsLib/hero_venomancer.lua, BotsLib/hero_skeleton_king.lua, BotsLib/hero_death_prophet.lua, BotsLib/hero_phantom_assassin.lua, BotsLib/hero_pugna.lua, BotsLib/hero_templar_assassin.lua, BotsLib/hero_luna.lua
