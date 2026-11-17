# Util

Developer tools for OpenHyperAI. None of this is loaded by the game; run them with Node.js from the repo root.

| Tool | What it does |
|---|---|
| `split-console.js` | Splits Dota's `-condebug` console logs into one `game-NNN_<result>.log` per match plus a `.summary.txt` (scoreboard, every bot death, buildings, pushes, Roshan, lotus, script errors). Output goes to `Util/match-logs/` (git-ignored). `node Util/split-console.js [path\to\dota 2 beta\game\dota] [--out <dir>]` |
| `issue-prs.js` | Opens a draft PR for every open GitHub issue that has none: branch `<fix/feat/docs/chore>/issue-<N>-<slug>` from `origin/main`, one signed empty commit, the PR template with `Closes #N`. `node Util/issue-prs.js [--dry-run]` (needs `gh` logged in). |
| `verify.js` | In-game verification tracker for PRs not tested in a game yet (`Util/verify/tracker.json`, git-ignored). `add <pr>` imports the PR’s "How to verify in game" list, `check <game.log> --game NNN` counts each item’s log tags with sample lines, `set <pr> <item or all> pass/fail/skip [note]`, `show`, `done <pr>`. |
| `luabal.js` | Rough block-balance check for Lua files (`function`/`if`/`do` against `end`). Compare with the committed file rather than trusting the number. `node Util/luabal.js <file.lua> ...` |
| `boots-check.js` | Lists hero positions whose build ends up with more than one pair of boots (outfits expanded). `node Util/boots-check.js` |
| `urn-builds.js` | Regenerates `URN_BUILDS` in `FuncLib/systems/item_strategy.lua` (which positions' builds carry Urn / Spirit Vessel / Essence Distiller) from the hero files. Run after any build change: `node Util/urn-builds.js --write`. |
| `role-weights/` | Rebuilds `FuncLib/data/hero_pos_weights.lua` from Dotabuff's 7-day All Pick meta table (`dotabuff_7d.txt`). `gen.js` holds the formula and the source URLs; `supcheck.js` lists heroes drafted as pos 4/5 whose support build is really a core build. |
| `hero-review/` | The 2026-11-16 review of all 127 heroes against the patch: the brief the reviewers followed, their eight reports, and `gen.js`, which builds the `hero-review.html` report page. |
| `meta-builds/` | The 2026-11-17 item / skill build review against Dotabuff: the data (most played items and most picked skill per level for all 127 heroes), `build.js` to make one review file per hero, the reviewers' brief and their eight reports. |

`match-logs/`, `verify/`, `role-weights/rows.json`, `hero-review/hero-review.html` and `meta-builds/heroes/` are generated and git-ignored.
