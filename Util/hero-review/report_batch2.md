HERO: storm_spirit | STATUS: OK - all 4 ability names exist; Static Remnant point-cast (datafeed is_point_targeted=1); Remnant/Ball Lightning/Vortex keys exist; Overload passive filtered; skill build and items valid
HERO: sven | STATUS: FLAGGED
- FLAG: pos_4/pos_5 alias the pos_1 carry build (MoM, Daedalus, Satanic, Bloodthorn) | WHY: role mismatch if drafted as support; alias left. Storm Hammer 80*lvl matches datafeed; build and items valid
HERO: tiny | STATUS: CHANGED
- CHANGE: ConsiderAvalanche damage reads "avalanche_damage" instead of "value" | WHY: datafeed avalanche_damage 90/180/270/360, no "value"; damage read 0, kill checks never fired
- CHANGE: ConsiderTreeVolley needs the Scepter (`not b:HasScepter()` return; was `b:HasScepter()`) | WHY: datafeed tiny_tree_channel is granted by Scepter; the old check meant Tree Volley could never be cast
- FLAG: Blink + Toss combo never runs (F only set in HasBlink(), never called) | WHY: enabling it would stop the close-range engage Toss while Blink is ready and throw at an allied hero (untested); left
- FLAG: pos_3/4/5 alias the pos_4 carry list | WHY: alias left
HERO: vengefulspirit | STATUS: CHANGED
- CHANGE: ConsiderWaveOfTerror damage from GetSpecialValueInt("damage") instead of GetAbilityDamage() | WHY: datafeed damage 60/80/100/120, no AbilityDamage; kill and last-hit checks saw 0
- CHANGE: removed the second item_aghanims_shard from pos_4 | WHY: listed twice
HERO: windrunner | STATUS: FLAGGED
- FLAG: builds 1 and 2: ult rank 2 at entry 12 (level 13) | WHY: still learnable
- FLAG: pos_4/5 alias the pos_3 core build | WHY: alias
- FLAG: Gale Force is vector-targeted (behavior 9663676433) but cast with Action_UseAbilityOnLocation | WHY: the API has no vector order (runtime dump)
HERO: zuus | STATUS: CHANGED
- CHANGE: Nimbus (r) by name "zuus_cloud" instead of sAbilityList[4] | WHY: granted by Scepter (hidden until then)
- CHANGE: Static Field share P read every frame from zuus_static_field damage_health_pct/100 (was 0.09, only when sAbilityList[5] trained) | WHY: datafeed: innate, always active, 3.45% current health; feeds Lightning Bolt last-hits and the Wrath kill check
- CHANGE: Lightning Bolt damage from GetSpecialValueInt("damage") instead of GetAbilityDamage() (ConsiderW, ConsiderW2) | WHY: datafeed 140/220/300/380, no AbilityDamage. Effect: ConsiderW2's first branch now fires only on heroes at or below bolt damage (0 meant any hero before); the ranged-creep last-hit branch now works
- FLAG: ConsiderR adds talent f[5] (Arc Lightning damage) to Wrath damage via "value" | WHY: Wrath talent is f[3]; key unverifiable
HERO: kunkka | STATUS: CHANGED
- CHANGE: pos_4/pos_5 (support builds starting with item_priest_outfit): Hand of Midas, Basher, MKB, Assault Cuirass, Abyssal Blade replaced with Force Staff, Lotus Orb, Scythe of Vyse; kept Mekansm/Greaves/Pipe/Glimmer/Halberd/Shard/Scepter | WHY: support builds full of carry items
- CHANGE: SkillsComplement wait guard `U ~= 0 or V ~= 0 or W ~= 0` (was V twice) | WHY: typo; W (X Marks + Torrent combo timer) was never checked
- FLAG: kunkka_return not in the datafeed | WHY: hidden sub-ability
- FLAG: build 1 ult rank 2 at level 13 | WHY: still learnable
HERO: lina | STATUS: CHANGED
- CHANGE: Dragon Slave damage reads "dragon_slave_damage" instead of "AbilityDamage" | WHY: datafeed 65/125/185/245, no AbilityDamage; checks read 0. Effect: two FindAoELocation branches now count only creeps Dragon Slave can kill (0 meant any creep)
- CHANGE: ConsiderR damage always MAGICAL (was PURE with Scepter); CanCastAbilityROnTarget always needs a non-magic-immune target | WHY: datafeed lina_laguna_blade damage 2 (magical), no Scepter text (Scepter now grants lina_flame_cloak); a Scepter Lina tried to Laguna through BKB
- FLAG: generic level-15 "Q" branch off with `and false` | WHY: left (Dragon Slave spam); decide if intended
HERO: lich | STATUS: CHANGED
- CHANGE: Ice Spire (r) by name "lich_ice_spire" instead of sAbilityList[4] | WHY: Shard-granted (hidden until then); innate lich_death_charge (unit-target) can sit at index 4, so the spire combo could cast Sacrifice at a location
- CHANGE: ConsiderQ Frost Blast damage from GetSpecialValueInt("damage") instead of S * 50 | WHY: datafeed 40/80/120/160 (aoe_damage separate); S*50 overrated it
HERO: lion | STATUS: CHANGED
- CHANGE: Earth Spike damage from GetSpecialValueInt("damage") instead of GetAbilityDamage() | WHY: datafeed 105/170/235/300, no AbilityDamage; kill check read 0
- CHANGE: ConsiderR base damage r:GetSpecialValueInt("damage") (600/725/850); removed +100 with Scepter; Scepter AoE radius reads "splash_radius" (no splash_radius_scepter) | WHY: datafeed; the Scepter only adds AoE damage on the initial cast; Finger was overrated by 100
- FLAG: Hex cast at a location when talent f[8] is trained | WHY: f[8] is Earth Spike cast range, AoE Hex is f[7]; the talent build picks f[7], so the branch never runs
HERO: shadow_shaman | STATUS: OK - names incl. Shard shadow_shaman_urnaconda exist; Ether Shock "damage" and magical type match; Hex/Shackles unit-target, Wards point-target; build and items valid
HERO: slardar | STATUS: CHANGED
- CHANGE: ConsiderW (Slithereen Crush) damage "crush_damage" instead of GetAbilityDamage(), type PHYSICAL instead of MAGICAL | WHY: datafeed damage 1 (physical), crush_damage 60/140/220/300, no AbilityDamage
HERO: tidehunter | STATUS: CHANGED
- CHANGE: pos_1 "item_great_scepter" -> "item_greater_crit" | WHY: not in items.txt (came with 7077b54); closest valid name, a damage item like pos_2's MKB in the same place
- CHANGE: ConsiderE Anchor Smash radius = attack range + "additional_range" instead of "radius" | WHY: datafeed has no radius ("radius is Tidehunter's attack range plus additional_range (225)"); read 0, every check in ConsiderE came up empty
- FLAG: Gush adds talent f[3] via "value" | WHY: right talent, key unverifiable
HERO: witch_doctor | STATUS: CHANGED
- CHANGE: ConsiderQ new ally-save rule (after kill/channel, before Q-Aoe): enemy hero in Cask range attacking an allied hero, or chasing an ally within 900, with that ally under 75% HP or hit by it in the last 2s, and mana for Cask -> Cask on the enemy ("Q-Save"), logged [OHA-WD] cask-save | WHY: user report, game 033 1:00: Anti-Mage harassed Pudge, WD next to them with Cask ready did nothing. Datafeed Cask: range 600, mana 80/100/120/140, 0.8s hero stun, bounce_range 575
- CHANGE: bounce radius reads Cask "bounce_range" instead of Death Ward | WHY: datafeed bounce_range 575 is on witch_doctor_paralyzing_cask; Death Ward has none, so the radius was 0 and the Q-Aoe / Q-Attack / Q-Retreat group checks never counted anyone
- CHANGE: Cask damage from "base_damage" (55/70/85/100) instead of 50 + T*25 | WHY: datafeed (+20 per bounce); old formula 75/100/125/150
- CHANGE: ConsiderR damage type local PURE (was PHYSICAL) | WHY: datafeed death_ward damage 4 (pure); local unused
HERO: riki | STATUS: CHANGED
- CHANGE: Backstab damage from riki_innate_backstab damage_multiplier (0.55) instead of the ultimate's | WHY: datafeed moved Backstab to the innate; riki_backstab (Cloak and Dagger) has no damage_multiplier, bonus read 0
- CHANGE: Blink Strike bonus_damage counted as physical in WillMixedDamageKillTarget (3 calls); T local PHYSICAL | WHY: datafeed riki_blink_strike damage 1 (physical)
- CHANGE: Tricks of the Trade radius reads "radius" instead of "range" | WHY: datafeed radius 425, no "range"; team-fight AoE check had radius 0
- CHANGE: ConsiderAS uses c.CanCastAbility(r) instead of IsTrained/IsFullyCastable | WHY: no Riki Shard active any more (Shard upgrades Smoke Screen); sAbilityList[4] is the passive innate or nothing, so it could order a passive cast every frame while retreating
- FLAG: pos_2..pos_5 alias the pos_1 carry build | WHY: alias
- FLAG: talents u = f[6], v = f[8] added to wrong values via "value" | WHY: likely read 0, harmless
HERO: enigma | STATUS: CHANGED
- CHANGE: ConsiderMalefice instance count reads "stun_instances" instead of "value" | WHY: datafeed stun_instances 3, no "value"; kill damage was always 0
- FLAG: Midnight Pulse radius talent check uses special_bonus_unique_enigma_6 (Black Hole DPS); pulse radius talent is enigma_9 | WHY: reads 0, harmless
FILES: BotsLib/hero_tiny.lua, BotsLib/hero_vengefulspirit.lua, BotsLib/hero_zuus.lua, BotsLib/hero_kunkka.lua, BotsLib/hero_lina.lua, BotsLib/hero_lich.lua, BotsLib/hero_lion.lua, BotsLib/hero_slardar.lua, BotsLib/hero_tidehunter.lua, BotsLib/hero_witch_doctor.lua, BotsLib/hero_riki.lua, BotsLib/hero_enigma.lua
