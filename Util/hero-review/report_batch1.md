HERO: antimage | STATUS: FLAGGED
- FLAG: antimage_counterspell_ally and antimage_mana_overload (ConsiderCounterSpellAlly, ConsiderBlinkFragment) not in the datafeed | WHY: datafeed lists mana_break, blink, counterspell, persectur (innate), mana_void; Shard now makes a blinked fragment on reflect, Scepter powers Mana Break after Blink, so the Blink Fragment branch (gated on HasScepter) looks dead; SafeAbility dummy, no crash
HERO: axe | STATUS: CHANGED
- CHANGE: ConsiderR Culling Blade threshold from r:GetSpecialValueInt("damage") (fallback 175 + 100*level) instead of 150 + 100*level, no longer adds talent f[5] | WHY: datafeed damage = 275/375/475 pure; talent 5 is special_bonus_strength_15 (Culling Blade talent is T8)
- CHANGE: ConsiderR no longer skips magic-immune heroes | WHY: datafeed axe_culling_blade immunity 3 = pierces debuff immunity
- CHANGE: ConsiderW Battle Hunger kill check with DAMAGE_TYPE_PURE via c.WillKillTarget | WHY: datafeed axe_battle_hunger damage = 4 (pure); was magical
- FLAG: Berserker's Call AoE talent (f[7]) read with key "value" | WHY: datafeed key bonus_radius, adds 0; unclear whether "radius" already includes it
HERO: bane | STATUS: CHANGED
- CHANGE: Brain Sap with changed target type (Shard AoE) cast with ActionQueue_UseAbilityOnLocation | WHY: it passed x:GetLocation() to ActionQueue_UseAbilityOnEntity; the Shard point order itself is unverified (datafeed base behavior 8)
- CHANGE: ConsiderW uses PURE damage for Brain Sap (c.CanKillTarget(Y, R, PURE)) | WHY: datafeed bane_brain_sap damage = 4 (pure); was magical
- FLAG: Brain Sap damage talent (f[7]) read with key "value" | WHY: datafeed key bonus_brain_sap_damage, adds 0
HERO: bloodseeker | STATUS: CHANGED
- CHANGE: ConsiderW push/defend condition parenthesised as (N == nil or #N == 0) | WHY: operator precedence let it fire whenever no enemy hero was near, even when not pushing or defending
- FLAG: bloodseeker_blood_mist (ConsiderBloodMist) not in the datafeed | WHY: Scepter now grants Rupture charges; dead branch (dummy, no crash). ConsiderThirst targets a passive (behavior 2), harmless
HERO: crystal_maiden | STATUS: CHANGED
- CHANGE: Crystal Clone fetched by name ("crystal_maiden_crystal_clone") instead of sAbilityList[4] | WHY: Shard-granted ability; innate glacial_guard means entry 4 may not be the clone
HERO: drow_ranger | STATUS: FLAGGED
- FLAG: ConsiderGlacier returns BOT_ACTION_DESIRE_LOW (> 0) for "ally within 500" and "retreating while attacked"; the caller casts on any value > 0 | WHY: Glacier (Shard, cd 25) gets cast whenever an ally is near, even out of combat; intent unclear
HERO: earthshaker | STATUS: OK - ability names, special values (fissure_damage, echo_slam_*, scepter_leap_duration, distance_scepter), magical damage, skill build, items checked; recent Echo Slam logic untouched
HERO: juggernaut | STATUS: CHANGED
- CHANGE: Swift Slash fetched by name ("juggernaut_swift_slash") instead of sAbilityList[4] | WHY: Scepter-granted ability; innate bladeform means entry 4 may not be Swift Slash
HERO: mirana | STATUS: OK - ability names, special values (starfall_*, arrow_*, leap_distance, quiver bonus_damage), magical damage, skill build, items checked; recent Leap logic untouched
HERO: nevermore | STATUS: CHANGED
- CHANGE: Shadowraze damage = shadowraze_damage + damage_per_soul * Necromastery souls (fallback 20 + 65*level), instead of 20 + 70*level + talent f[4] "value" | WHY: datafeed shadowraze_damage = 85/150/215/280, damage_per_soul = 2; talent 4 is now the Feast of Souls souls-per-hero talent
- CHANGE: removed the "souls < 25" gate in ConsiderFeastOfSouls | WHY: datafeed necromastery_max_souls = 20, and nevermore_frenzy (Feast of Souls) gathers souls, so it was almost never cast
- FLAG: datafeed lists only nevermore_shadowraze1 (raze2/raze3 exist in game, Rubick stole them in game-005) | WHY: slot order of frenzy/dark_lord (sAbilityList 4/5) can't be read from the datafeed; build maxes both, works either way
- FLAG: ultimate at entries 9 and 11 (levels 9 and 12), not 6 and 11 | WHY: still learnable there; left
HERO: morphling | STATUS: CHANGED
- CHANGE: ConsiderWaveform damage from p:GetAbilityDamage() | WHY: GetSpecialValueInt("#AbilityDamage") is not a valid key and read 0; datafeed waveform AbilityDamage = 75/150/225/300
- FLAG: morphling_adaptive_strike_str / morphling_morph_replicate not in the datafeed; build never takes index 3 and the second ultimate rank is at entry 12 | WHY: slot order of morph_agi/morph_str can't be checked
HERO: phantom_lancer | STATUS: CHANGED
- CHANGE: ConsiderR (Juxtapose active) re-enabled: gate "not c.CanCastAbility(t)" instead of "... or not HasScepter() or true" | WHY: datafeed puts the Juxtapose active (invisibility, cd 18) on the Shard, and the branch was switched off with "or true"; cast type unverified; fails safe while Juxtapose is passive
- FLAG: talent f[5] (Spirit Lance damage) added to the Phantom Edge distance with key "value" | WHY: wrong talent and key, reads 0, harmless
HERO: puck | STATUS: CHANGED
- CHANGE: Phase Shift duration read with GetSpecialValueFloat in ConsiderPhaseShift and ConsiderPhaseOrb | WHY: datafeed duration = 1/1.75/2.5/3.25s; Int cut the fraction
- FLAG: Illusory Orb is now vector-targeted (datafeed text "Vector Targeted") but cast with UseAbilityOnLocation | WHY: the bot API has no vector order (runtime dump); puck_ethereal_jaunt not in the datafeed (linked ability)
HERO: pudge | STATUS: OK - names, Meat Hook pure, Rot/Dismember values, skill build, items checked; recent combo logic untouched (Dismember kill estimate conservative)
HERO: razor | STATUS: CHANGED
- CHANGE: ConsiderQ Plasma Field range from o:GetSpecialValueInt("radius") (fallback 700) instead of 777 | WHY: datafeed razor_plasma_field radius = 700
HERO: sand_king | STATUS: CHANGED
- CHANGE: ConsiderR Epicenter radius from epicenter_radius_base + epicenter_radius_increment | WHY: "epicenter_radius" doesn't exist in the datafeed and read 0; datafeed base 450, +13 per pulse
FILES: BotsLib/hero_axe.lua, BotsLib/hero_bane.lua, BotsLib/hero_bloodseeker.lua, BotsLib/hero_crystal_maiden.lua, BotsLib/hero_juggernaut.lua, BotsLib/hero_nevermore.lua, BotsLib/hero_morphling.lua, BotsLib/hero_phantom_lancer.lua, BotsLib/hero_puck.lua, BotsLib/hero_razor.lua, BotsLib/hero_sand_king.lua
