# Item and skill builds vs the current Dotabuff meta

Repo: C:\Users\ANGGARA\Documents\OpenHyperAI (Lua bot scripts for Dota 2). Each hero has one file,
BotsLib/hero_<name>.lua, with item builds per position (tables like `m["pos_1"] = { "item_...", ... }`,
some positions are aliases such as `m["pos_4"] = m["pos_1"]`), a sell list `a["sSellList"]` read in pairs
{owned, sold}, and skill builds (arrays of ability indices such as `{ 1, 3, 1, 2, 1, 6, ... }` = the order
abilities are levelled; read the file to see how indices map to abilities — usually the hero's ability
slots, 6 = ultimate).

For each of your heroes there is a data file in
C:\Users\ANGGARA\AppData\Local\Temp\claude\dd83bb95a98a6874\78631228-580b-4093-8e8e-7286c4feda37\scratchpad\meta\heroes\<hero>.txt
with Dotabuff's most played items for that hero (last patch data, all positions together; share of matches played, no win rate) and the most
picked ability at each level.

## How to read the Dotabuff data (user's rules)

- Look at MATCHES PLAYED (popularity), not win rate. Win rate is survivorship-biased: Aegis, Divine Rapier and
  late luxury items show a high win rate because the team was already winning; cheap items and components
  (Bracer, Magic Wand, Wraith Band) show a low win rate because they are sold or held in lost games. Never
  add or drop an item because of its win rate.
- The list mixes all positions. A support item popular on a core hero may come from its support games, and
  the other way round; judge which of our positions each item belongs to.
- Ignore neutral items and neutral enchantments (names that are not shop items, e.g. "Tough"), Aegis,
  Cheese, Refresher Shard, Roshan's Banner, consumables (Tango, Clarity, Healing Salve, Dust, wards, Smoke,
  TP Scroll) and pure components that our build already gets through a recipe.
- Skill table: "level=Ability@pct". At levels where a talent is usually taken the top ability shows a low
  percentage (e.g. 10%); ignore those columns. Compare our main skill build with the most picked order,
  especially: which basic ability is maxed first, and when the ultimate is taken (6/12/18).

## What to decide for each hero

1. Items: an item in the top ~15 by matches played that is missing from our build for the position it fits.
   Decide from the hero's mechanics (the game's own ability data, e.g. the Valve datafeed
   https://www.dota2.com/datafeed/herodata?language=english&hero_id=N, or knowledge of what the item does
   for this hero's spells) whether it is worth replacing an item we have. Replace only when the case is
   clear (e.g. the meta core item for the hero is missing, or we build something nobody builds any more).
   Keep the list length and rough order (early items first). Keep the build valid: every item name must
   exist in C:\Users\ANGGARA\AppData\Local\Temp\claude\dd83bb95a98a6874\78631228-580b-4093-8e8e-7286c4feda37\scratchpad\review\items.txt.
   Do not put two copies of an item that does not stack. Upgrades (e.g. item_ultimate_scepter_2,
   item_travel_boots_2, item_moon_shard) follow the existing file conventions.
2. Skills: if our max order clearly differs from the meta (a different basic ability maxed first, or the
   ultimate not at 6/12/18) and the meta order makes sense for the hero's role in our build, change it.
   Keep the array length and format. Do not touch talent arrays unless they are plainly wrong.
3. Sell list: if you remove an item that the sell list references, fix the pair.

Do not change ability logic (Consider functions); only item lists, skill build arrays and sell pairs.
Do not run git. Do not edit any file other than your heroes' BotsLib/hero_<name>.lua files.

## Report (your final message)

For each hero, one block:
HERO: <name> | STATUS: CHANGED | OK | FLAGGED
- CHANGE: <what> | WHY: <mechanics reason + matches-played evidence, e.g. "Blink Dagger 2.05M matches, #2">
- FLAG: <something worth a human look> | WHY: ...
Then FILES: <list of files you edited>.
