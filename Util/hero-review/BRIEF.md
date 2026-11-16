# Hero review brief (OpenHyperAI Dota 2 bots)

Repo: the repo root (Lua bot scripts for Dota 2). Each hero has one file:
BotsLib/hero_<short_name>.lua (e.g. BotsLib/hero_antimage.lua). You review ONLY the heroes in your batch file
and edit ONLY their BotsLib/hero_<name>.lua files.

HARD RULES
- Do not edit any other file. Do not run git commands that change state (no add/commit/checkout/stash/reset).
  The coordinator commits everything once at the end.
- Facts about Dota (ability names, damage types, ranges, cooldowns, item names and effects) come ONLY from
  Valve's datafeed, never from memory:
    - heroes: https://www.dota2.com/datafeed/herodata?language=english&hero_id=<id>  (ids in your batch file)
      result.data.heroes[0].abilities[]: name, desc_loc, damage (1 physical, 2 magical, 4 pure),
      behavior (bitmask), cooldowns, mana_costs, cast_ranges, cast_points, special_values,
      shard_loc / scepter_loc (Aghanim texts). talents[] are also there.
    - items: https://www.dota2.com/datafeed/itemdata?language=english&item_id=<id>
    - the list of every valid item name is already saved at
      items.txt (every item name from the datafeed itemlist; not kept)
  Fetch with curl from Bash (e.g. curl -s "<url>" | node -e '...'). If something can't be verified, don't change it;
  flag it instead.
- Edits must keep Lua valid: tabs for indentation, balanced function/if/for/do ... end. Keep the existing code style
  (single-letter locals are normal here). Make small, targeted edits; don't rewrite files.
- Comment every change in the code with a short reason ("datafeed: ..." where it applies), like the existing
  comments in the repo.

HOW THE FILES WORK
- Skill build: tables like `local j = { { 1, 3, 3, 2, 3, 6, 3, 2, 2, 2, 6, 1, 1, 1, 6 } }` (one or more variants;
  `k = c.Skill.GetRandomBuild(j)` or picked by position). Each number is an index into the hero's ability list,
  which FuncLib/systems/skill.lua builds from the engine's ability slots: the learnable, non-hidden basic
  abilities in slot order (Q=1, W=2, E=3, sometimes 4/5 for extra learnables), and the ULTIMATE IS ALWAYS INDEX 6.
  Entry n of the 15-entry array is the skill point for level n for levels 1-9, then levels 11-14, then 16-17
  (levels 10/15/20/25 are talents). So the ultimate belongs at entries 6 and 11 (levels 6 and 12); level 18's
  rank is taken automatically by a fallback, and an ultimate at entry 15 (level 17) can't be learned there.
  The level-up code already skips/falls back on unlearnable entries, so only fix orders that are clearly wrong
  (an index that doesn't exist for this hero, maxing a now-useless or innate ability, the ultimate placed where it
  can't be learned, a basic ability never taken).
- Talents: `local i = { ["t25"] = { 0, 10 }, ["t20"] = ..., ["t15"] = ..., ["t10"] = ... }` - which side
  (left/right) at each tier. Only change if clearly wrong for the build; talents are lower priority.
- Items: `m["pos_1"] = { ... }` .. `m["pos_5"]` (sometimes aliases like m["pos_4"] = m["pos_3"]). Names may be
  real items (must be in items.txt) or composite "virtual" names defined in FuncLib/systems/item.lua as
  b["item_xxx"] = { ... } (outfits such as item_mage_outfit, item_ranged_carry_outfit, item_double_branches,
  item_power_treads_agi, ...) or the strategy slot "item_team_aura". item_recipe_* entries are allowed.
  Listing an upgraded item after its parts is normal (the buyer builds components). A second
  item_ultimate_scepter_2 entry after item_ultimate_scepter means the Aghanim's Blessing.
  `a["sSellList"]` is a list of PAIRS: { bought, sold, bought, sold, ... } (sell the 2nd when the 1st is owned).
- Ability use: functions like a.ConsiderQ()/ConsiderW()/... return desire, target. Look for obvious bugs:
  wrong DAMAGE_TYPE_* vs the datafeed damage type, returning nil or the wrong variable as a target, branches
  switched off with `and false`, abilities fetched by a name that no longer exists, an ability never cast at all,
  a unit-target spell aimed at a location or vice versa (check behavior: 4 no-target, 8 unit-target,
  16 point-target, 32 AoE).

WHAT TO DO PER HERO (your checklist)
1. Fetch the hero's datafeed entry. Note its abilities (name, damage type, behavior, Shard/Scepter texts).
2. Check every hard-coded ability name in the file (GetAbilityByName("...") etc.) exists in the datafeed for this
   hero (talents and Shard/Scepter sub-abilities count). Fix or flag missing ones.
3. Skill build sanity (see above). Fix only clearly wrong orders, for the role(s) this hero is built for.
4. Item builds: every name valid (items.txt / virtual / recipe). Fix invalid or removed items. Fix obvious role
   mismatches (e.g. a support build full of carry items, a core with no defensive item at all when the hero's
   kit clearly needs one, a hero buying an item its kit can't use). Keep the overall style of the build; this is
   about obvious gaps, not personal taste.
5. Ability-use logic: fix obvious bugs from the list above. Don't redesign.
6. Sanity check the Lua after editing. A rough block-balance checker is at
   Util/luabal.js
   (node luabal.js <file>). Compare against the original with
   `git show HEAD:BotsLib/hero_<name>.lua > <tmp>` and the same checker; the "gap" must not change. It is rough:
   the words function/end inside strings containing the letter n, or in comments, can skew the counts, so judge
   the delta, not the absolute.

REPORT (your final answer) - plain text, one block per hero, exactly:
HERO: <short_name> | STATUS: OK or CHANGED or FLAGGED
- CHANGE: <what changed, file area> | WHY: <reason with datafeed evidence>
- FLAG: <problem you saw but did not fix> | WHY: <reason>
(OK heroes: one line "HERO: x | STATUS: OK - <one-line summary of what you checked>".)
End with a line "FILES: <comma-separated list of files you edited>".
