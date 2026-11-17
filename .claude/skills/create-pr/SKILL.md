---
name: create-pr
description: Finish work on an OpenHyperAI branch and open or update its PR - checks, signed commit, push, CI, change-log description, and tracker entry. Use when code for an issue or fix is done.
---

# Create or update a PR

Rules: `AGENTS.md` (Branches and pull requests, Commits, Checks, Logging). Checklist:

1. **Branch.** Work on the issue's branch (from `Util/issue-prs.js`) or a new `<fix|feat|docs|chore>/<topic>`
   from `origin/main`. If `main` moved, `git merge origin/main` first (merge commits are allowed; never
   force-push).
2. **Code rules.** Readable names, no new globals, team slots not player IDs, guard nil handles, Dota facts from
   game data. Every new or uncertain behaviour gets a throttled `[OHA-<TAG>] t=%.0f <hero> ...` log.
3. **Checks before committing:**
   - `luajit Tests/run.lua` if LuaJIT is available (CI runs it anyway);
   - parse all Lua; StyLua formats on commit (pre-commit hook), re-run `stylua --check` if it changed files;
   - luacheck rules by hand if luacheck isn't installed (CI is the gate).
4. **Commit** with a conventional message (what was wrong, what changed, which log shows it). Commits are
   signed automatically. Never stage `Customize/general.lua` (test lineup). The build number is generated
   (`Customize/build_info.lua`); don't bump versions by hand.
5. **Push** and confirm the CI run for the commit is green (Syntax, Lint, Format, Tests).
6. **Description** from `.github/pull_request_template.md`, change-log format: one entry per change with
   type (crash/mechanic/behaviour/cleanup), **Before:** and **Now:** in one or two sentences; group same-issue
   objects but give each hero/object its own sub-bullet. "How to verify in game" lists the `[OHA-*]` lines; add
   `<!-- expect: ...; heroes: ... -->` to a bullet when a machine can check it (see `Util/verify.js`).
   Create with `gh pr create --body-file ...` or update with `gh pr edit <n> --body-file ...`; mark ready with
   `gh pr ready <n>` when the code is done.
7. **Track it:** `node Util/verify.js add <pr>` for anything visible in a game; if it needs specific heroes, run
   `node Util/verify.js lineup --suggest` (and `--write` when slots are free).
