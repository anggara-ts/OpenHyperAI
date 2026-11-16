# Util

Developer tools for OpenHyperAI. None of this is loaded by the game; run them with Node.js from the repo root.

| Tool | What it does |
|---|---|
| `split-console.js` | Splits Dota's `-condebug` console logs into one `game-NNN_<result>.log` per match plus a `.summary.txt` (deaths, buildings, pushes, Roshan, lotus, script errors). Output goes to `Util/match-logs/` (git-ignored). `node Util/split-console.js [path\to\dota 2 beta\game\dota] [--out <dir>]` |
| `luabal.js` | Rough block-balance check for Lua files (`function`/`if`/`do` against `end`). Compare with the committed file rather than trusting the number. `node Util/luabal.js <file.lua> ...` |
| `role-weights/` | Rebuilds `FuncLib/data/hero_pos_weights.lua` from Dotabuff's 7-day All Pick meta table (`dotabuff_7d.txt`). `gen.js` holds the formula and the source URLs; `supcheck.js` lists heroes drafted as pos 4/5 whose support build is really a core build. |
| `hero-review/` | The 2026-11-16 review of all 127 heroes against the patch: the brief the reviewers followed, their eight reports, and `gen.js`, which builds the `hero-review.html` report page. |

`match-logs/`, `role-weights/rows.json` and `hero-review/hero-review.html` are generated and git-ignored.
