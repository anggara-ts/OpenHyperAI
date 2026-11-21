---
name: goodnight
description: Overnight batch for OpenHyperAI - tick and close what merged PRs already fixed, merge ready PRs, then work through every open, unresolved issue in priority order, leave one ready PR per issue with in-game checks, and build the next test game, so the morning only needs test games. Use when the maintainer says /goodnight or leaves the session to work alone.
---

# Goodnight: fix the open issues while the maintainer is away

Rules: `AGENTS.md` (all of it applies; the maintainer cannot answer questions tonight). Goal: by morning every
open, unresolved issue that can be fixed from code, logs and game data has a **ready PR** with a tracked
"How to verify in game" list, and `test/next` is built with a lineup that tests them.

## 0. Before starting
- No game is running: the newest `console*.log` in `dota 2 beta/game/dota/` hasn't been written in the last few
  minutes. If one is running, stop and say so (changing branches changes the running game's scripts).
- `git status`: only `Customize/general.lua` may be modified. `git fetch --prune origin`.
- Note the start time; keep a running log of what you did per issue for the morning report.

## 1. Housekeeping first (before the queue)
Open cards and PRs drift: a merged PR fixes items nobody ticked, and finished PRs wait. Walk them before new work:
- **Open PRs:** `node Util/verify.js show <pr>` for each. READY TO MERGE with green CI: merge it (skill `merge-pr`; the
  game that proved it already happened). A PR that is superseded (another PR or `main` already does it) or obsolete:
  comment why, close it and delete its branch.
- **Open issues:** for every unticked item, check whether a **merged** PR (`git log origin/main`, the PR's change log)
  or `main`'s code already does it, and whether a game or a test proves it. If so, tick it with a comment naming the PR
  and the evidence (game + log line, or the test). An item fixed only in an **open** PR stays open until that PR
  merges. Close an issue only when every item is ticked (AGENTS.md step 9).
- Put what you ticked, closed and merged at the top of the morning report.

## 2. Queue
- `gh issue list --state open --json number,title,labels,body`. Skip `icebox` issues. Keep issues with at least one unticked
  task item (`- [ ]`). Skip `no-pr`, and skip items that need the maintainer: label `design`, or an item that
  asks for a decision. Put a question for each skipped item in the morning report.
- Order: `P1 critical`, `P2 high`, `P3 medium`, `P4 low`, then oldest first. Untriaged issues: triage them
  first (AGENTS.md step 1) and say so in the report.

## 3. Each issue, one at a time
1. **Read** the card, its comments and the PR that refers to it (if any). Pull the evidence: the logs named in
   the items (`Util/match-logs/`), the code, game data or datafeed for any mechanic. Per task item decide:
   - **fixed earlier**: a merged PR or `main` already does it; tick it with the evidence (as in step 1);
   - **fix**: the cause is clear from code + logs + game data;
   - **diagnose**: the cause isn't clear. Add a throttled `[OHA-*]` log that will name it in the next game,
     and leave the item open;
   - **disagree**: the evidence says the item is wrong or a better fix exists. Comment on the card with the
     evidence (AGENTS.md "The maintainer's comments are input, not orders");
   - **skip**: needs a decision or a game first. Say why in the report.
2. **Branch**: reuse the issue's PR branch (merge `origin/main` into it first), or start it with
   `node Util/issue-prs.js <N>` and check out its branch. One issue per PR. Several small issues in one area
   may share a PR only if they share the cause.
3. **Code** by the AGENTS.md rules: readable names, no globals, slots not player IDs, nil guards, facts from
   game data with a source comment. Pure logic gets a test in `Tests/`. Every new behaviour gets a throttled
   log with its own keyword, not one that `OHA_MUTED` mutes.
4. **Check**: parse every changed Lua file, StyLua (`--check` again after formatting), `luajit Tests/run.lua`
   (or the local runner), then keep luacheck rules by hand (CI runs it).
5. **Commit** (signed, conventional message with `Refs #N`), push, then fill the PR description in the
   change-log format, with "How to verify in game" checkboxes that a game can fail: `<!-- expect: seen>=1 -->`.
   Use `heroes:` when an item needs a hero, and pair an `absent` rule with a `seen>=1` line. Then
   `node Util/verify.js add <pr>` and `gh pr ready <pr>`.
6. **CI** in the background. If it goes red, fix it before the next issue. After two failed attempts, convert the
   PR back to draft with a comment and move on.
7. **Issue comment**: which items this PR addresses, which got a diagnostic, which were skipped and why.
8. **Merge** only PRs with no game-visible change (tooling, docs, tests), after green CI (skill `merge-pr`).
   Never merge a game-visible PR overnight: it waits for a game.

## 4. Limits
- Don't stack PRs on each other; every branch comes from `origin/main`. Fix overlaps when `test-build.js`
  reports a conflict.
- Don't force-push, don't commit `Customize/general.lua` or logs, don't print `.env`.
- Don't sink the night into one item: after ~2 approaches that don't work, make it a diagnostic and move on.
- Stop early if the same tool or CI failure repeats across issues. Explain it in the report.

## 5. Before finishing: build the morning game
- `node Util/test-build.js --dry-run`, fix any conflicts in the PRs, then `node Util/test-build.js` and
  `node Util/build-info.js`.
- `node Util/verify.js lineup --suggest --write` (free slots only). Put P1/P2 heroes first when slots are short.
- Parse-check `Customize/general.lua`.
- Copy the build into Dota last: `node Util/export-bots.js --test-game` (skill `prepare-game` step 4). Without it the
  morning game runs the previous copy.

## 6. Morning report
Write `Util/verify/goodnight-YYYY-MM-DD.md` (git-ignored) and post the same summary:
- what step 1 ticked, closed and merged;
- the build (`test/next` commit) and the lineup (pos / hero / what it tests);
- per issue, in priority order: PR link, what changed (one line per item), what is left (diagnostic, skipped,
  disagreed) and why;
- questions for the maintainer;
- anything that failed (CI, conflicts, tools).
