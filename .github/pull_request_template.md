## Summary
<!-- One or two sentences: what this PR changes and why (e.g. "Fixes from the game 037 review"). -->

## Changes
<!--
One entry per change, grouped by area (Crashes / Shared code / Heroes / Items / Modes / CI & docs).
Each entry: **<what>** (<type>) - Before: <old behaviour, 1 sentence>. Now: <new behaviour, 1 sentence>.
<type> is one of:
  crash     - a runtime error in game
  mechanic  - how an ability or item is used: targeting, cast rules, ranges/values from game data
  behaviour - a decision: when to fight, retreat, push, farm, which target or ally to pick
  cleanup   - no in-game effect (dead code, accidental globals, logs, refactors)
Several objects with the same issue may share one entry (e.g. "Crashes: stolen-spell handles"), but every hero
or object still gets its own sub-bullet with its own Before/Now.
-->
### Crashes
-

### Heroes
- **<Hero> - <ability or decision>** (mechanic | behaviour) - Before: ... Now: ...

### Shared code / modes / items
-

## Not changed
<!-- Items looked at and skipped on purpose, with the reason. -->
-

## How to verify in game
<!-- One checkbox per [OHA-*] log line to look for in the next game, and what a good result looks like. When a
machine can check an item, end it with an HTML comment holding "expect: seen>=1; key<=X" and/or "heroes: a,b".
Util/verify.js ticks a box when its item passes (or is skipped) in a game; do not tick them by hand. -->
- [ ] 

## Checks
- [ ] CI green: LuaJIT syntax, luacheck, StyLua, Tests
- [ ] Build checked: the test game's `[OHA-BUILD]` commit contains this PR (its branch, or a `test/next` build with it; `Util/after-game.js` lists the PRs in the build)
- [ ] No `Customize/general.lua` test lineup, no match logs committed
- [ ] Dota mechanics checked against game data / datafeed (not memory)
- [ ] Tested in a local game (game NNN) / not yet tested
