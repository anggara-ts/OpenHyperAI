HERO: dazzle | STATUS: FLAGGED
- FLAG: dazzle_nothl_projection_end not in the datafeed | WHY: probably the hidden recast sub-ability; SafeAbility makes it inert if missing. Names, skill build, items, Poison Touch / Shadow Wave physical, Poison Touch unit-target, Nothl point-target all match
HERO: rattletrap | STATUS: CHANGED
- CHANGE: ConsiderHookshot retreat branch tests c.IsNotSelf(b, M) (was `not c.IsNotSelf(b, M)`) | WHY: the old test was true only for Clockwerk himself, so with the "distance > 1200" check the hook-to-ally escape could never fire; datafeed note: "Hookshot will latch and take Clockwerk to allies". Newly live, untested
- CHANGE: ConsiderBatteryAssault and ConsiderRocketFlare Tormentor branches use c.IsTormentor(E) (was c.IsRoshan(E)) | WHY: copy-paste bug, never true at the Tormentor
HERO: leshrac | STATUS: CHANGED
- CHANGE: pos_2 skill build swaps entries 11 and 12 so Pulse Nova is at level 12 | WHY: it was at level 13; datafeed leshrac_pulse_nova is the ultimate
HERO: furion | STATUS: FLAGGED
- FLAG: ConsiderSprout retreat branch reads "radius" (furion_sprout has none, reads 0, the test always passes) | WHY: harmless, no equivalent key; Teleportation HP gate untouched; damage and cast types match
HERO: life_stealer | STATUS: CHANGED
- CHANGE: SkillsComplement calls a.ConsiderInfest() after Rage and casts with Action_UseAbilityOnEntity(D, K) | WHY: ConsiderInfest existed but was never called (git history: never), so Infest was never cast; datafeed life_stealer_infest is unit-target. Newly live, untested
- CHANGE: skill build Infest from entry 12 to 11 (level 12) | WHY: ultimate one level late
- FLAG: life_stealer_consume / life_stealer_control not in the datafeed | WHY: plausibly hidden Infest sub-abilities
- FLAG: pos_4/pos_5 support builds full of carry items (Basher, MKB, Assault, Abyssal) | WHY: redesign needed
HERO: dark_seer | STATUS: CHANGED
- CHANGE: CanDoVacuumWall failure path sets b.shouldBlink = false (set true) | WHY: the flag stayed on and ability_item_usage_generic.lua:1602 then skipped the generic engage blink; Batrider/Beastmaster reset it the same way
- CHANGE: Wall of Replica from entry 12 to 11 (level 12) | WHY: ultimate one level late
HERO: clinkz | STATUS: CHANGED
- CHANGE: ConsiderBurningArmy castability gate checks s (Burning Army), not r (Burning Barrage) | WHY: wrong variable. Newly live, untested
- CHANGE: ConsiderBurningBarrage range = max(GetCastRange(), "range"), width = "projectile_width" | WHY: datafeed cast range 0 and no "radius"; range 850, projectile_width 200; the engage test could never pass
- CHANGE: pos_2 items lose the second item_dragon_lance | WHY: listed twice; Pike consumes one
- CHANGE: skill build j[2] Skeleton Walk from entry 12 to 11 | WHY: clinkz_wind_walk is the ultimate
- FLAG: clinkz_tar_bomb not in the datafeed; ConsiderTarBomb dead | WHY: harmless, not removed
- FLAG: ConsiderDeathPact laning test mixes and/or without parentheses | WHY: siege creeps skip the validity check; minor
HERO: omniknight | STATUS: CHANGED
- CHANGE: ConsiderW (Martyr) reads "base_hpregen" (was "hp_regen") | WHY: datafeed base_hpregen 8/12/16/20, no hp_regen; reading 0 meant every missing-HP check passed
- FLAG: cores' skill build takes the ultimate at entries 10/11, not 6 | WHY: looks deliberate
- FLAG: Martyr ally filter checks "modifier_omniknight_repel" | WHY: modifier name unverifiable
HERO: enchantress | STATUS: CHANGED
- CHANGE: ConsiderSproink reads Impetus "distance_damage_pct" (was "value") | WHY: datafeed 5/10/15/20, no "value"; kill estimate was 0, Bunny Hop kill branch never fired
- CHANGE: skill build j[2] Untouchable from entry 12 to 11 | WHY: ultimate one level late
HERO: huskar | STATUS: CHANGED
- CHANGE: Life Break from entry 12 to 11 (level 12) | WHY: ultimate one level late; damage types magical as coded
- FLAG: Berserker's Blood Shard active never cast | WHY: new logic
HERO: night_stalker | STATUS: CHANGED
- CHANGE: Void always unit-cast; removed the HasScepter point-cast paths (ConsiderVoid and dispatcher) | WHY: datafeed night_stalker_void behavior 8; its area effect is the Shard's and the Scepter belongs to Hunter in the Night, so Void broke with a Scepter
- CHANGE: ConsiderVoid ally-save branch returns Z[1] (the enemy chasing the ally), not D | WHY: wrong variable
- CHANGE: ConsiderHunterInTheNight range = max("shard_cast_range", GetCastRange()) | WHY: no shard_cast_range in the datafeed, read 0, so the Shard creep-eat never found a creep. Newly live, untested
HERO: broodmother | STATUS: OK - names, ultimate at index 6, Hunger at 1, cast types, magical damage, items match
HERO: bounty_hunter | STATUS: OK - names, layout, magical Shuriken, unit-target Track, items, sell pairs match
HERO: weaver | STATUS: OK - names, build, magical Shukuchi, point Swarm, Time Lapse, items match
HERO: jakiro | STATUS: CHANGED
- CHANGE: Liquid Frost handle fetches "jakiro_liquid_ice" (was "jakiro_liquid_frost") | WHY: datafeed internal name jakiro_liquid_ice; old name returned nil. Newly live, untested
- CHANGE: ConsiderAS (Liquid Frost) loses its tower/barracks branches | WHY: datafeed: "does not apply to buildings" (target_type 19); Liquid Fire covers buildings
- CHANGE: ConsiderR (Macropyre) reads "path_width" / 2 (was "path_radius") | WHY: datafeed path_width 500, no path_radius; read 0, area checks never worked
- FLAG: skill build never takes index 4 (Liquid Frost) | WHY: unclear whether it takes its own points
- FLAG: FuncLib/data/spell_list.lua:287 still says jakiro_liquid_frost | WHY: outside scope
HERO: batrider | STATUS: CHANGED
- CHANGE: removed the per-position overwrite of a["sSellList"] and the globals Pos2SellList / Pos3SellList | WHY: pairs are {owned, sold}; pos_2 sold the Bottle once Branches were held, pos_3 had a one-entry list; the well-formed list now applies
- CHANGE: skill build j[2] Flaming Lasso from entry 12 to 11 | WHY: ultimate one level late
FILES: BotsLib/hero_rattletrap.lua, BotsLib/hero_leshrac.lua, BotsLib/hero_life_stealer.lua, BotsLib/hero_dark_seer.lua, BotsLib/hero_clinkz.lua, BotsLib/hero_omniknight.lua, BotsLib/hero_enchantress.lua, BotsLib/hero_huskar.lua, BotsLib/hero_night_stalker.lua, BotsLib/hero_jakiro.lua, BotsLib/hero_batrider.lua
