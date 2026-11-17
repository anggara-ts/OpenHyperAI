# AGENTS.md

Working rules for anyone (people or AI coding agents) changing this repo. Read this before the first change.

OpenHyperAI is a set of Lua bot scripts for Dota 2. The game runs them with LuaJIT. There is no build step and
no unit-test harness: the checks below plus a real bot game are the test.

## Repo map

| Path | What it is |
|---|---|
| `BotsLib/hero_<name>.lua` | One file per hero: skill build, item build, ability use (`X.SkillsComplement`, `X.Consider*`). |
| `FuncLib/func_utils.lua` (`Fu`) | Shared helpers, assembled from `FuncLib/general_utils/*.lua`. |
| `FuncLib/systems/` | Shared systems: push, defend, wards, items, roles, logging, version. |
| `FuncLib/hero/` | Shared hero code: minions/illusions, Rubick's stolen spells (`rubick_hero/`), sub-units. |
| `FuncLib/data/` | Static tables (hero names, matchups, position weights, spell lists). |
| `FuncLib/dota/` | Dota API names and constants (`index`, `enums`, `interfaces`, `heroes`). |
| `FuncLib/lib/` | Generic libraries: `json` (dkjson), `http_req`, `native_operators`. |
| `mode_*_generic.lua` | Bot modes (laning, farm, retreat, push, defend, roshan, rune, ward, ...). |
| `ability_item_usage_generic.lua`, `item_purchase_generic.lua`, `hero_selection.lua`, `bot_generic.lua` | Item/ability use, buying, drafting, per-bot think. |
| `Customize/general.lua` | User settings and **local test lineups**. |
| `Customize/version.lua` | Build number shown in game. |
| `Util/` | Node.js developer tools (log splitter, build checks); see `Util/README.md`. |
| `Docs/` | Notes such as `BOT_API_RUNTIME.md` (what the bot API really exposes). |

Folders use PascalCase (`BotsLib`, `FuncLib`, `Customize`, `Util`, `Docs`); files inside use snake_case.
The optional Fretbots / Buff plugin lives on the orphan branch `plugin-fretbots`, not here.

### Files the engine loads from the root

Dota loads these only from the root of the `bots` folder, by exact name; a copy in a subfolder is never run
(the bot silently falls back to Valve's default): `mode_<mode>_generic.lua`, `bot_generic.lua`,
`hero_selection.lua`, `ability_item_usage_generic.lua`, `item_purchase_generic.lua`. Keep them in the root and
put shared logic in `FuncLib/`. A mode file whose name doesn't match a real mode (e.g. `mode_roam_generic_wip`)
is never loaded either; don't keep such copies.

### Valve default modes we keep on purpose

Adding `mode_<name>_generic.lua` replaces Valve's built-in mode **entirely**: the script cannot call Valve's own
`GetDesire`/`Think` for that mode. Two modes stay Valve's on purpose; do not add files for them:

- **Item mode (`mode_item_generic.lua`)** - Valve's item mode is what picks up the river bounty and water runes
  (`mode_rune_generic.lua` walks a bot to the river spot and holds it for the item mode). Our own item mode
  (own drops, Gem, Rapier, tokens only) stopped the river gold being taken, so it was removed (2026-11-17).
  The cost: bots may still pick up another hero's dropped item.
- **Evasive maneuvers (`mode_evasive_maneuvers_generic.lua`)** - Valve's projectile/AoE dodging. Overriding
  it would drop the dodging. Where it gets bots killed (low HP, outnumbered), `mode_retreat_generic.lua`
  returns a desire above it instead (`[OHA-RETREAT] over-evasive`).

Prefix a file with `--` only for a short local test, never as a long-term "disabled" copy: delete it instead.

## Branches and pull requests

- Branch every change from the **current `origin/main`**. Never stack a branch on an unmerged branch: PRs are
  **squash-merged**, so a stacked branch conflicts with `main` afterwards. If `main` moved under your branch,
  merge `origin/main` into it (merge commits are allowed on feature branches) or replay your commits onto
  `origin/main` in a new branch. Do not force-push.
- Branch names: `fix/<topic>`, `feat/<topic>`, `chore/<topic>`, `docs/<topic>`, releases `release-vX.Y`.
- Every commit must be **signed** (the branch rules reject unverified commits).
- PR title: a conventional-commit style summary, e.g. `fix: bugs found in game 037`.
- PR description: use `.github/pull_request_template.md`. The change log is the important part:
  - One entry per change: **what** changed, its **type**, **Before:** the old behaviour and **Now:** the new
    behaviour, each in one or two plain sentences a player understands (no code names needed).
  - Type is one of `crash` (runtime error), `mechanic` (how an ability/item is used: targeting, cast rules,
    values from game data), `behaviour` (a decision: fight, retreat, push, farm, which target or ally),
    `cleanup` (no in-game effect).
  - Objects with the same issue may share a group heading (e.g. "Crashes: stolen-spell handles"), but every
    hero / object in the group still gets its own sub-bullet with its own Before/Now. Never write a bare list
    like "Tusk, Grimstroke, Ogre Magi" without saying what changed for each.
  - List what was looked at and skipped on purpose, with the reason, and the `[OHA-*]` lines to check in game.
- CI must be green before merging (see Checks).

## Commits

- Conventional messages: `fix(scope): ...`, `feat(scope): ...`, `refactor: ...`, `style: ...`, `ci: ...`,
  `docs: ...`, `chore: ...`. The body says what was wrong, what changed, and which `[OHA-*]` log shows it.
- Bump `Customize/version.lua` on every commit that changes Lua: `number = "YYYY.MM.DD-NNN"`, `NNN` +1 per
  change, reset to `001` on a new date. Bump `FuncLib/systems/version.lua` (`"0.7.41 - YYYY/MM/DD"`) when the
  date changes.
- **Never commit test lineups** in `Customize/general.lua` (forced picks, unbans, `Weak_Hero_Cap` debug values).
  Only commit real setting changes there, staged on their own.

## Checks (CI blocks on all three)

`.github/workflows/lua-check.yml` runs on pushes to `main`, `release-*`, `fix/**` and on every PR:

1. **Syntax** - every tracked `.lua` compiled with LuaJIT (the game's Lua, so `goto` is fine).
2. **Lint** - `luacheck` with `.luacheckrc`. No unused locals or values, no new globals,
   write `x < y` not `not (x >= y)`, never `not a == b` (it means `(not a) == b`).
3. **Format** - `stylua --check .` (StyLua 2.6.0, `stylua.toml`: LuaJIT, tabs, 120 columns, double quotes).
   Run `stylua <files>` before committing; some files need a second pass, so re-run `--check`.

Run them locally before pushing, then confirm the CI run for your commit is green.

**pre-commit hooks.** Once per clone: `pip install pre-commit` then `pre-commit install`
(`.pre-commit-config.yaml`). On every commit:
- `no-commit-to-branch`: commits directly on `main` are refused. Work on a branch and open a PR.
- `check-added-large-files`: a new file over 500 KB is refused (match logs, dumps, binaries).
- `stylua-github`: StyLua 2.6.0 formats the staged `.lua` files. If it changed anything the commit stops:
  check the changes, `git add` them and commit again. `pre-commit run --all-files`
formats the whole repo. A branch without `.pre-commit-config.yaml` (older branches cut before it was added)
needs `PRE_COMMIT_ALLOW_NO_CONFIG=1` to commit.

## Code conventions

- Readable names. Hero files: `X` (the returned table), `bot`, `Fu` (func_utils), `AbilityContext`, `Minion`,
  `<spell>Ability`, `<spell>Desire` / `<spell>Target` / `<spell>Location`, `hpRatio`, `nearbyEnemies`, ...
  Short names only for loop counters (`i`, `j`), unused values (`_`) and coordinates.
- Locals only. A helper used before its definition goes on the module table (`X.Helper`) or is forward-declared;
  never add a global (several heroes once shared a global `HasBlink` / `CanBKB` and ran each other's copy).
- `GetTeamMember(i)` takes a team **slot** 1..5, not a player ID from `GetTeamPlayers()`.
- Guard handles that may be nil (stolen spells, optional items) before calling methods on them.
- **Dota facts come from game data, not memory**: ability values, target types, radii and item data from the
  installed game files (`scripts/npc` inside the VPKs) or the Valve datafeed
  (`https://www.dota2.com/datafeed/herodata?language=english&hero_id=N`). Cite the source in a comment when it
  drives a number.
- The bot API differs from online docs; see `Docs/BOT_API_RUNTIME.md` (e.g. no vector-targeted cast order).

## Logging

- Diagnostic lines use `print(string.format("[OHA-<TAG>] t=%.0f <hero> <what> key=value ...", DotaTime(), ...))`.
  Always include `t=` (game seconds) and the hero name.
- Throttle: at most once per few seconds per bot, or only when the decision changes. A line printed every think
  is a bug (it floods the console and costs FPS).
- Add a log to every new or uncertain behaviour so the next game proves it works. Remove or mute logs for
  features that are proven to work (`OHA_MUTED` in `FuncLib/systems/global_overrides.lua`).

## Testing in a game

1. The local dev setup links `dota 2 beta/game/dota/scripts/vscripts/bots` to this repo, so the game runs the
   checked-out branch. Start a Custom Lobby, server **Local Host**, bots set to **Local Dev Script**.
2. Launch Dota with `-condebug` so the console is written to `game/dota/console*.log`.
3. After the game: `node Util/split-console.js "<...>/dota 2 beta/game/dota" --out Util/match-logs`.
   This writes `game-NNN_<result>.log` and a `.summary.txt` (scoreboard, deaths with mode/HP/allies/enemies,
   buildings, pushes, Roshan, lotus, script errors). `Util/match-logs/` is git-ignored: the logs contain the
   host's Steam account ID and server IPs, never commit or publish them.

## Issue -> PR -> game test -> merge (the regular workflow)

Tools: `gh` (GitHub CLI, logged in), `Util/issue-prs.js`, `Util/verify.js`.

1. **Issues.** Every bug, finding or request is a GitHub issue. Group findings that share a cause or an area into
   one card (e.g. "Meepo: Poof and retreat", "Rubick stolen spells: leftover globals"), so a card is one focused
   fix. Labels: `bug`, `enhancement`, `needs-confirmation` (seen once, verify next game), `design` (needs a
   decision), `game-review` (came from watching a game). `no-pr` skips step 2.
2. **Draft PR per issue, automatically.** `node Util/issue-prs.js` opens a draft PR for every open issue without
   one: branch `<fix|feat|docs|chore>/issue-<N>-<slug>` from `origin/main`, one signed empty commit, the PR
   template and `Closes #N`. Run it after creating issues (agents run it right after they file issues). It runs
   locally, not as a GitHub Action, because commits must be signed with the maintainer's key.
3. **Work on the PR branch.** Before the first real commit, merge `origin/main` into it if `main` moved. Commit
   (signed, pre-commit hooks), push, keep CI green, and fill the PR description in the change-log format
   (see Branches and pull requests). Mark the PR ready for review when the code is done.
4. **Track what is not tested in a game yet.** `node Util/verify.js add <pr>` imports the PR's
   "How to verify in game" list into `Util/verify/tracker.json` (git-ignored). Every PR with game-visible
   changes goes there until a game proves it.
5. **Play a game** on a branch that contains the PRs under test (or `main` once merged). Note which build ran.
6. **Review the game** (below). Then for the tracked PRs:
   - `node Util/verify.js check Util/match-logs/game-NNN_*.log --game NNN` counts each item's log tags and shows
     sample lines; read them and set each item: `node Util/verify.js set <pr> <item> pass|fail|skip [note]`.
   - Read the maintainer's PR comments (`gh pr view <pr> --comments`): game-review PRs get comments written while
     watching the game, e.g. "20:30 radiant team went yolo behind bottom t1". Each observation is either fixed
     in that PR (if it is about that PR's change) or filed as an issue (grouped as in step 1).
   - An item that failed or did not fire: fix it in the same PR and keep it in the tracker; an item that never
     triggered (the situation didn't happen) stays pending for the next game.
7. **Merge.** When `node Util/verify.js show <pr>` says READY TO MERGE (every item pass or skip) and CI is green:
   tick the PR's checks (including "Tested in a local game (game NNN)"), squash-merge with `gh pr merge <pr>
   --squash`, delete the branch, and `node Util/verify.js done <pr>`. Stacked PRs merge in order (base first);
   after each squash-merge, merge `origin/main` into the next branch so its PR shows only its own changes.

## Reviewing a game (regular task)

- Split the console (`Util/split-console.js`), note the build the game ran (`version` in the summary) and map
  log line numbers to that commit (`git show <sha>:<file>`).
- Check: script errors (`attempt to`, `stack traceback`), every tracked `[OHA-*]` item (`Util/verify.js check`)
  and every other line added since the last game (did the feature fire, with sane values?), log spam (lines per
  second per tag), death patterns, objectives (towers, barracks, Roshan, Tormentor, buybacks), mode flip-flops
  (`[OHA-FLIP]`, `[OHA-STUCK]`), and the maintainer's comments on the PRs under test.
- Write findings as: what happened (time + log line) / why it matters / code location / suggested fix /
  confidence. File them as grouped issues (step 1) and let `Util/issue-prs.js` open their PRs; a single
  `fix/game-NNN` PR is fine for many small fixes from one review.

## Things not to do

- Do not commit `Customize/general.lua` test lineups, match logs, or anything with the Steam ID.
- Do not force-push, rewrite published history, or skip signing.
- Do not change a mechanic from memory; check the game data.
- Do not stack branches on unmerged branches unless the work depends on them; then say so in the PR and merge
  in order.
- Do not merge a PR with game-visible changes before its tracker items pass in a game.
