(Besides the datafeed, this reviewer read the installed game's ability files, scripts/npc/heroes/npc_dota_hero_<name>.txt in pak01_dir.vpk, for slot order, sub-abilities and per-ability special values.)
HERO: monkey_king | STATUS: CHANGED
- CHANGE: ConsiderBoundlessStrike kill check MAGICAL -> PHYSICAL | WHY: datafeed monkey_king_boundless_strike damage=1 (physical, a crit on his attack)
- CHANGE: ConsiderPrimalSpring range GetSpecialValueInt("max_distance") -> q:GetCastRange() | WHY: game files: Primal Spring has no "max_distance" (impact_damage/slow/radius only), cast range 800; the old lookup read 0, so the spring never aimed anywhere
- FLAG: ultimate at levels 9/17/18 (pos1) or 11/17/18, Tree Dance listed 5 times | WHY: all learnable, looks like a design choice; index 4 = Jingu is correct
HERO: pangolier | STATUS: OK - names valid (rollup/gyroshell stop in game files), Swashbuckle physical, indices and items valid; Swashbuckle is vector-targeted but cast at a point (no vector order in the API)
HERO: dark_willow | STATUS: FLAGGED
- FLAG: Terrorize (index 6) never in the skill list; Bedlam (index 4) taken at 6/12/17 | WHY: game files link Bedlam and Terrorize, likely level together; unconfirmed, edit reverted
- FLAG: ConsiderBedlam reads "destination_status_duration" (Bedlam doesn't have it, reads 0) and a no-target spell's cast range | WHY: harmless
HERO: grimstroke | STATUS: CHANGED
- CHANGE: ConsiderPhantomsEmbrace kill check PHYSICAL -> MAGICAL | WHY: datafeed grimstroke_ink_creature damage=2 (magical)
- FLAG: grimstroke_return (ConsiderInkExplosion) exists in the game files but not on his slots | WHY: probably dead code, harmless
HERO: mars | STATUS: OK - names, damage types (Spear magical, Rebuke physical), cast types, indices, items correct; pos_4/5 reuse pos_3 (weights 5 and 0)
HERO: void_spirit | STATUS: OK - names, damage types (magical), special values match
- FLAG: ultimate rank 2 at level 13 instead of 12 | WHY: one level late, minor
HERO: snapfire | STATUS: CHANGED
- CHANGE: pos_4/pos_5 items were aliases of the carry list (Maelstrom, Mjollnir, Daedalus, BKB); now support lists in Hoodwink's style: priest/mage outfit, Mekansm and Greaves or Janggo, Bearing and Pipe, Glimmer, Force Staff, Shard, Scepter, Sheepstick, Octarine or Moon Shard | WHY: her position weights put pos 4 highest (60), so the carry list was a role mismatch; datafeed: Scepter grants Gobble Up, Shard improves the cookie; item names valid
HERO: hoodwink | STATUS: OK - names, damage types (Acorn physical, Bushwhack magical), cast types, items correct
- FLAG: ultimate rank 2 at level 13 instead of 12 | WHY: minor
HERO: dawnbreaker | STATUS: OK - names (incl. dawnbreaker_converge), damage types, indices, items, sell pairs correct
- FLAG: talent "value" lookup reads 0 | WHY: multiplies by 1, harmless
HERO: marci | STATUS: CHANGED
- CHANGE: sell pairs swapped: pos_1/2 { magic_wand, greater_crit, armlet, abyssal_blade } -> { greater_crit, magic_wand, abyssal_blade, armlet }; pos_3 { magic_wand, nullifier } -> { nullifier, magic_wand } | WHY: pairs are { owned, sold }; the old order sold Daedalus once she had a Wand, Abyssal once she had Armlet, Nullifier once she had a Wand
- FLAG: marci_guardian (ConsiderSidekick) is the old Sidekick; Bodyguard already handled | WHY: dead code, harmless
HERO: primal_beast | STATUS: CHANGED
- CHANGE: ConsiderTrample kill check PHYSICAL -> MAGICAL | WHY: datafeed primal_beast_trample damage=2 (magical)
HERO: muerta | STATUS: CHANGED
- CHANGE: ConsiderW (The Calling) V.cout -> V.count | WHY: the AoE result field is "count"; the typo was always nil so the branch never fired (found by the batch 3 reviewer)
- earlier rework kept; Dead Shot, Calling, Slug magical per datafeed
HERO: ringmaster | STATUS: OK - Crystal Ball, Weighted Pie, empty souvenir slot, Tame the Beasts crack exist in game files; magical damage; cast types and indices (4 souvenir, 5 Spotlight, 6 Wheel) and items valid
HERO: kez | STATUS: CHANGED
- CHANGE: ConsiderTalonToss kill checks (hero and lane creep) MAGICAL -> PHYSICAL | WHY: datafeed kez_talon_toss damage=1
- CHANGE: ConsiderKazuraiKatana range from o:GetSpecialValueInt("katana_attack_range") (o = kez_switch_weapons) instead of r | WHY: game files put katana_attack_range (225) on Switch Discipline; old lookup read 0, so the impale was never cast
- FLAG: "katana_bonus_damage" doesn't exist; variable unused | WHY: harmless (Echo Slash physical, Raptor Dance pure, indices 4 Switch / 6 Raptor Dance OK)
HERO: largo | STATUS: OK - all names incl. the three songs match the datafeed; Lick/Frogstomp magical; songs used for their effects; indices and items valid
FILES: BotsLib/hero_monkey_king.lua, BotsLib/hero_grimstroke.lua, BotsLib/hero_snapfire.lua, BotsLib/hero_marci.lua, BotsLib/hero_primal_beast.lua, BotsLib/hero_muerta.lua, BotsLib/hero_kez.lua
