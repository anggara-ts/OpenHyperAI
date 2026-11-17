# AGENTS.md

Working rules for anyone (people or AI coding agents) changing this repo. Read this before the first change.
Setting up a machine (hooks, signing, linking Dota to the clone) is in [`CONTRIBUTING.md`](CONTRIBUTING.md).

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
- **No manual version bump.** The git hooks (see pre-commit hooks) run `Util/build-info.js` after every checkout,
  commit, merge and rebase; it writes the git-ignored `Customize/build_info.lua`, and the game prints
  `[OHA-BUILD] version=<commit date>-<sha>[+dirty] commit= branch= dirty=` at the start of every game, so each
  log names the exact build. `Customize/version.lua`'s `number` is only the fallback for Workshop installs
  (no git): bump it, and `FuncLib/systems/version.lua` (`"0.7.41 - YYYY/MM/DD"`), only for a Workshop release.
- **Never commit test lineups** in `Customize/general.lua` (forced picks, unbans, `Weak_Hero_Cap` debug values).
  Only commit real setting changes there, staged on their own.

## Checks (CI blocks on all of them)

`.github/workflows/lua-check.yml` runs on pushes to `main`, `release-*`, `fix/**`, `feat/**`, `chore/**`,
`docs/**` and on every PR:

1. **Syntax** - every tracked `.lua` compiled with LuaJIT (the game's Lua, so `goto` is fine).
2. **Lint** - `luacheck` with `.luacheckrc`. No unused locals or values, no new globals,
   write `x < y` not `not (x >= y)`, never `not a == b` (it means `(not a) == b`).
3. **Format** - `stylua --check .` (StyLua 2.6.0, `stylua.toml`: LuaJIT, tabs, 120 columns, double quotes).
   Run `stylua <files>` before committing; some files need a second pass, so re-run `--check`.
4. **Tests** - `luajit Tests/run.lua`: a stub bot API loads every hero file, checks every `require` path,
   team-slot helpers (stub player IDs are deliberately not 1-5) and pure helpers. Add a test when you fix a bug
   a test could have caught. Tests live in `Tests/test_*.lua` and get the runner as `local T = ...`
   (`T.test`, `T.xfail`, `T.eq`, `T.near`, `T.ok`, `T.stub`, `T.files`, `T.read`); `luajit Tests/run.lua <word>`
   runs matching files. An API call the stub doesn't cover fails with `stub missing: <name>`: add it to
   `Tests/stub_api.lua`. A real bug that isn't fixed in the same PR stays as `T.xfail(name, reason, fn)` plus an
   issue; an XPASS means it got fixed, so remove the xfail.

Run them locally before pushing. After pushing, don't block on CI: start a background wait (e.g. `gh pr checks <pr> --watch` run in the background) and keep working; look at the result before merging or when it reports a failure.

**pre-commit hooks.** Once per clone: `pip install pre-commit` then `pre-commit install --install-hooks`
(`.pre-commit-config.yaml`; installs the commit hooks and the post-checkout/commit/merge/rewrite hooks that
write `Customize/build_info.lua`). Keep `.pre-commit-config.yaml` staged when you edit it (an unstaged config
makes the post-* hooks fail). On every commit:
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
   checked-out branch. Start a Custom Lobby, server **Local Host**, bots set to **Local Dev Script** (Valve
   only offers bot scripts in lobbies, and third-party scripts only load on a Local Host server).
2. Launch Dota with `-condebug` so the console is written to `game/dota/console*.log`.
3. The game prints `[OHA-BUILD]` (exact commit) at the start. After the game, `node Util/after-game.js` splits
   the console (`Util/split-console.js`) and writes the review skeleton (see Reviewing a game).
   `Util/match-logs/` is git-ignored: the logs contain the host's Steam account ID and server IPs, never commit
   or publish them.

## Issue -> PR -> game test -> merge (the regular workflow)

Tools: `gh` (GitHub CLI, logged in), `Util/issue-prs.js`, `Util/verify.js`, `Util/test-build.js`,
`Util/after-game.js`, `Util/build-info.js`. Claude Code skills in `.claude/skills/` run each step
(see Skills below).

1. **Issues.** Every bug, finding or request is a GitHub issue. Group findings that share a cause or an area into
   one card (e.g. "Meepo: Poof and retreat", "Rubick stolen spells: leftover globals"), so a card is one focused
   fix. Each problem in a card is a **task item** `- [ ] (game NNN, m:ss) ...`; a new finding for an existing card
   is a new task item there, not a new card. Labels: `bug`, `enhancement`, `needs-confirmation` (seen once,
   verify next game), `design` (needs a decision), `game-review` (came from watching a game), `chore`; `no-pr`
   skips step 2.
2. **Draft PR per issue, automatically.** `node Util/issue-prs.js` opens a draft PR for every open issue without
   one: branch `<fix|feat|docs|chore>/issue-<N>-<slug>` from `origin/main`, one signed empty commit, the PR
   template and **`Refs #N`** (never `Closes #N`: merging a PR must not close the issue). Run it right after
   filing issues. It runs locally, not as a GitHub Action, because commits must be signed with the maintainer's
   key.
3. **Work on the PR branch.** Before the first real commit, merge `origin/main` into it if `main` moved. Commit
   (signed, pre-commit hooks), push, keep CI green, and fill the PR description in the change-log format
   (see Branches and pull requests). Mark the PR ready for review when the code is done.
4. **Track what is not tested in a game yet.** `node Util/verify.js add <pr>` imports the PR's
   "How to verify in game" list into `Util/verify/tracker.json` (git-ignored). Every PR with game-visible
   changes goes there until a game proves it. Make items machine-checkable where possible: end the bullet with
   `<!-- expect: seen>=1; allyDist<=500 -->` (rules: `seen>=N`, `absent`, `key<=X` / `>=` / `==` / `!=` / `<`
   / `>` on `key=value` fields; give such an item one tagged pattern) and/or `<!-- heroes: lion,mirana -->`, or
   set them later with `node Util/verify.js expect <pr> <item> "<rules>"` / `heroes <pr> <item> a,b`.
5. **Set the test lineup** (local only, `Customize/general.lua`, never committed). `node Util/verify.js lineup`
   shows each slot as keep (still testing a PR) or can free; `lineup --suggest [--write]` puts the heroes that
   pending items need into **free** slots (`"Random"`, unset, or can free) at the hero's best free position by
   pick rate (`Util/role-weights/rows.json`), tagged `"npc_dota_hero_x", -- pos N -- TEST #<pr>: <what>`
   (set `LUAPARSE` to a luaparse install to parse-check the written file). It never replaces a slot still
   testing another PR: if nothing is free, the hero **waits for the next game**. Check
   `Customize.Weak_Hero_Cap` when stacking test heroes. Set a PR's slots back to `"Random"` when it merges.
6. **Build and play.** `node Util/test-build.js [--with <branch>]` makes the local branch `test/next` =
   `origin/main` + every tracked PR (+ any `--with` branch, e.g. a tooling PR whose scripts you need), skips and
   lists PRs that conflict (fix the conflict in that PR, not in test/next), writes `Util/verify/test-build.json`
   and switches the working tree to it, carrying `Customize/general.lua` (other modified files make it refuse;
   `--dry-run` only reports, `--no-switch` builds without switching). Never push `test/next`. Then run
   `node Util/build-info.js` (a reset fires no hook) so `[OHA-BUILD]` names the build, and play. PRs no longer
   need to be stacked to be tested together: branch each one from `main`.
7. **During the game** the maintainer may post observations with game times ("2:50 kez and tusk won't hit
   dawnbreaker trapped in ice shards"). Check each against the running log (newest `console*.log`, grep a
   window around the time for the heroes involved), explain the cause, and record it: a task item on the
   matching issue card, a comment on the PR under test, or a note for the review. Don't change code while the
   game runs. Comments can be wrong: check them (see "The maintainer's comments are input, not orders").
8. **Review the game** (below), then for the tracked PRs:
   - `after-game.js` works out which tracked PRs were in the game from git: a PR counts when all its own
     (non-merge) commits that change Lua are ancestors of the `[OHA-BUILD]` commit, so one `test/next` game tests many PRs and a
     rebuilt `test/next` doesn't lose the mapping. It runs `node Util/verify.js check <log> --game NNN --prs <those>`,
     which auto-passes or auto-fails items with
     `expect` rules, keeps items pending when none of their `heroes` played, and shows sample lines for the rest;
     set those with `node Util/verify.js set <pr> <item> pass|fail|skip [note]`. PRs not in the build are skipped
     (an `absent` rule would otherwise pass trivially).
   - Read the maintainer's PR comments (`after-game.js` lists those since the last review). Each observation is
     either fixed in the PR it is about or added to a grouped issue card (step 1).
   - An item that failed: fix it in the same PR and keep it tracked; an item whose situation didn't happen stays
     pending for the next game.
9. **Merge.** The agent decides which PRs are ready and squash-merges them itself, without asking (standing
   approval from the maintainer, 2026-11-17); it reports what it merged and why. A PR is ready when
   `node Util/verify.js show <pr>` says READY TO MERGE (every item pass or skip), CI is green, and every PR it is
   stacked on is merged or merges first in the same go (a PR that contains an unready PR waits).
   The PR shows its state by itself: "How to verify in game" is a checkbox list, and `verify.js set`, `check` and
   `sync` tick an item's box when it passes or is skipped. When every item is done they also tick
   "Tested in a local game (game NNN)", add the **Ready to merge** label and put a status line at the top of
   the description: "Ready to merge", or "Ready to merge, blocked by #N" when it is stacked on a PR that is not
   ready. Don't tick those by hand. Then:
   - `node Util/verify.js mute-suggest <pr>` prints `OHA_MUTED` entries for the proven log lines
     (`FuncLib/systems/global_overrides.lua`); add the noisy ones in the PR (avoid whole-tag mutes; keep error and
     rare-decision logs).
   - Tick the PR's checks (including "Tested in a local game (game NNN)"), `gh pr merge <pr> --squash
     --delete-branch`, `node Util/verify.js done <pr>`, free its lineup slots.
   - For each issue the PR refers to: tick the task items it fixed and verified, and comment the PR link and the
     game. **Close an issue only when every task item in it is ticked**; a PR never closes an issue by itself.
   - If a later PR was built on this one, merge `origin/main` into it so its PR shows only its own changes.
   - **Delete branches that are no longer used** (the agent does this without asking): the merged PR's branch
     (`--delete-branch`), local branches whose upstream is gone (`git branch -vv` shows `[gone]`; squash-merged,
     so `git branch -D`), and remote branches with no open PR whose content is already in `main` or identical to
     another branch (check with `git diff --stat`). Never delete `main`, `plugin-fretbots`, `release-*`, a branch
     with an open PR, or the local `test/next`.

### The maintainer's comments are input, not orders

Observations and requests from the maintainer (in chat, PR comments or issues) can be wrong: a misread of the
game, an outdated mechanic, or an idea that has a better alternative. Not every comment has to be implemented.
- Check each one against the log, the game data and, where it helps, online sources (the Valve datafeed,
  Liquipedia / the Dota 2 wiki, patch notes) before acting on it. Cite what you found.
- If the evidence disagrees, or you see a better approach, say so plainly and suggest the alternative instead
  of implementing the comment as written. Record the disagreement on the issue card or PR so the decision is
  visible, and let the maintainer decide when it is a judgement call.
- When the comment is right, say what confirmed it.

## Reviewing a game (regular task)

- `node Util/after-game.js` splits the console, picks the newest game, maps its build (`[OHA-BUILD]`, or an old
  `version` to its commit range) and the PRs in it (`test-build.json`), runs `verify.js check`, groups script
  errors, ranks log spam by peak lines per second, lists deaths and the scoreboard, collects the maintainer's PR
  comments since the last review, and writes `Util/match-logs/game-NNN_review.md`. Fill in its Findings and
  Issues to file sections.
- Then go deeper where the skeleton points: every tracked `[OHA-*]` item and every line added since the last
  game (did the feature fire, with sane values?), death patterns, objectives (towers, barracks, Roshan,
  Tormentor, buybacks), mode flip-flops (`[OHA-FLIP]`, `[OHA-STUCK]`). Map log line numbers to the build's
  commit (`git show <sha>:<file>`).
- Write findings as: what happened (time + log line) / why it matters / code location / suggested fix /
  confidence. File them as task items on grouped issue cards (step 1) and let `Util/issue-prs.js` open PRs for
  new cards; a single `fix/game-NNN` PR is fine for many small fixes from one review.

## Skills (Claude Code)

`.claude/skills/` holds step-by-step playbooks for the steps above; `AGENTS.md` stays the source of the rules.

| Skill | When |
|---|---|
| `/start-issue` | file findings or requests as grouped issue cards with task items, open draft PRs |
| `/create-pr` | code done: checks, signed commit, CI, change-log description, tracker entry |
| `/prepare-game` | before playing: tracker status, `test-build.js`, lineup, what the game tests |
| `/check-live-event` | the maintainer reports an event during a live game |
| `/review-game` | the game ended: `after-game.js`, tracker, PR comments, findings, issues, next lineup |
| `/merge-pr` | a PR is READY TO MERGE: mute proven logs, tick checks, squash-merge, tick issue items |

## Things not to do

- Do not commit `Customize/general.lua` test lineups, match logs, or anything with the Steam ID.
- Do not force-push, rewrite published history, or skip signing.
- Do not change a mechanic from memory; check the game data.
- Do not stack branches on unmerged branches; use `test-build.js` to test several PRs together.
- Do not merge a PR with game-visible changes before its tracker items pass in a game.
- Do not close an issue while any of its task items is open; do not write `Closes #N` in a PR.
- Do not push `test/next`, and do not change code while a test game is running.
