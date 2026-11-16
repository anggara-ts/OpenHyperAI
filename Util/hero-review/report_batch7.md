HERO: shredder | STATUS: FLAGGED
- FLAG: shredder_twisted_chakram (ConsiderTwistedChakram) is not in the datafeed; Scepter now makes Reactive Armor an active. Resolves to NIL_ABILITY proxy so harmless but dead code + warning log | WHY: datafeed abilities: whirling_death, timber_chain, reactive_armor, flamethrower (shard), chakram, exposure_therapy
- FLAG: Timber Chain retreat branch never fires: FuncLib/general_utils/positioning.lua GetBestRetreatTree sets `aI = loc` (undefined global) so it always returns nil | WHY: shared lib file, outside the hero files
HERO: bristleback | STATUS: OK - ability names, Quill Spray physical (dmg=1), Scepter active point-cast, skill build, items, sell pairs checked
HERO: tusk | STATUS: FLAGGED
- FLAG: Walrus Kick (Scepter) behavior has the vector-targeting bit (1<<30), datafeed says "in the drawn direction"; code casts it with Action_UseAbilityOnEntity | WHY: the bot API has no vector-target order (runtime dump), so the direction can't be chosen
HERO: skywrath_mage | STATUS: CHANGED
- CHANGE: ConsiderQ Arcane Bolt damage estimate INT multiplier 1.6 -> 1.5 | WHY: datafeed int_multiplier=1.5
HERO: abaddon | STATUS: CHANGED
- CHANGE: ConsiderMistCoil reads special "damage_heal" instead of "target_damage" | WHY: datafeed only has damage_heal=95/170/245/320; "target_damage" read 0, so the hero-kill and creep last-hit checks never fired
- FLAG: Borrowed Time is never cast manually (only its auto-trigger at the HP threshold) | WHY: new logic, not a fix
HERO: elder_titan | STATUS: CHANGED
- CHANGE: pos_1 skill build: Earth Splitter at entries 6/11/15 instead of entry 9 and 14-15 | WHY: the ultimate was first taken at level 9, rank 2 at level 16
HERO: legion_commander | STATUS: CHANGED
- CHANGE: Duel combo: clear actions once, then ActionQueue Press the Attack -> Blade Mail -> Duel | WHY: Duel used Action_UseAbilityOnEntity, which clears the queue, so the queued Press the Attack and Blade Mail never went out
- CHANGE: Press the Attack always unit-targeted (both places); removed the `v:IsTrained()` point-cast branch | WHY: datafeed behavior=8 (unit target); f[5] is special_bonus_unique_legion_commander_duel_duration, not an AoE talent, so the point cast could never work
HERO: ember_spirit | STATUS: CHANGED
- CHANGE: skill build 1: Fire Remnant at entries 6/11/15 (was 6/14/15 with Searing Chains at 11) | WHY: ultimate rank 2 was delayed from level 12 to 16
HERO: earth_spirit | STATUS: CHANGED
- CHANGE: ConsiderGeomagneticGrip engage branch checks IsStoneNearTarget(K) instead of IsStoneNearTarget(Z) | WHY: Z (kill-scan result) can be nil there -> crash (Z:GetLocation())
- FLAG: ConsiderEchantRemnant (Petrify, Scepter) always returns NONE; Petrify never cast | WHY: new logic
- FLAG: Geomagnetic Grip on allies gated on HasAghanimsShard; datafeed says allies always targetable (Shard only adds ally range/speed) | WHY: missed use, not a bug
HERO: terrorblade | STATUS: CHANGED
- CHANGE: Demon Zeal HP cost uses health_cost_pct/100 (special "value" doesn't exist) | WHY: datafeed health_cost_pct=20
- CHANGE: Demon Zeal only cast outside Metamorphosis (it required modifier_terrorblade_metamorphosis_transform) | WHY: datafeed "Can't be cast while in Metamorphosis and Metamorphosis will remove Demon Zeal" -> it was never cast
HERO: phoenix | STATUS: CHANGED
- CHANGE: ConsiderFireSpiritsLaunch kill damage uses Fire Spirits "duration" instead of "burn_duration" | WHY: datafeed burn_duration is an Icarus Dive key; Fire Spirits duration=4; old value read 0 -> kill check never fired
- CHANGE: ConsiderSupernova with Scepter falls back to a self-cast when no ally is low | WHY: the Scepter branch only cast on an ally, so a Scepter Phoenix otherwise never cast Supernova in a fight
- FLAG: ConsiderIcarusDiveStop returns NONE while Phoenix has modifier_phoenix_icarus_dive, the time Dive Stop is usable; looks like it never fires | WHY: could not verify modifier name/timing
HERO: oracle | STATUS: CHANGED
- CHANGE: Rain of Destiny handle fetched by name "oracle_rain_of_destiny" instead of g[4] | WHY: datafeed: Shard ability (hidden, NOT_LEARNABLE), so GetAbilityList skips it and g[4] can be the innate Prognosticate or nil; the reworked dispel/Edict/Rain/Flames logic unchanged
HERO: techies | STATUS: OK - reworked logic kept; ability names match the datafeed (techies_focused_detonate, reactive_tazer_stop are sub-abilities seen in game); skill build and items valid
HERO: winter_wyvern | STATUS: CHANGED
- CHANGE: Cold Embrace heal_percentage read with GetSpecialValueFloat instead of Int | WHY: datafeed 1.5/2.5/3.5/4.5; Int truncated them
- FLAG: ConsiderSplinterBlast kill branch requires `not c.IsInRange(b, M, P)` for heroes taken within P, so it almost never fires | WHY: unclear intent, left as is
HERO: arc_warden | STATUS: CHANGED
- CHANGE: ConsiderSparkWraith reads spark_damage_base and base_activation_delay (Float) | WHY: datafeed keys renamed; old spark_damage/activation_delay read 0 -> kill check never fired, lead time missed the 1.5s delay
HERO: abyssal_underlord | STATUS: CHANGED
- CHANGE: ConsiderFiendsGate ally-gank branch uses V:GetExtrapolatedLocation(1) directly | WHY: it passed a Vector to c.GetCenterOfUnits (expects a unit list) -> Vector(0,0) (map centre) or error
FILES: BotsLib/hero_skywrath_mage.lua, BotsLib/hero_abaddon.lua, BotsLib/hero_elder_titan.lua, BotsLib/hero_legion_commander.lua, BotsLib/hero_ember_spirit.lua, BotsLib/hero_earth_spirit.lua, BotsLib/hero_terrorblade.lua, BotsLib/hero_phoenix.lua, BotsLib/hero_oracle.lua, BotsLib/hero_winter_wyvern.lua, BotsLib/hero_arc_warden.lua, BotsLib/hero_abyssal_underlord.lua
