---
name: prepare-game
description: Get the local OpenHyperAI checkout ready for the next test game - build the test/next integration branch from main plus every tracked PR, set the test lineup, copy the build (with the uncommitted lineup) into Dota's vscripts/bots, and tell the user what the game will test. Use before the user plays, or when asked "what does the next game test".
---

# Prepare the next game

Rules: `AGENTS.md` (workflow steps 4-6). Checklist:

1. **Status:** `node Util/verify.js show` - which PRs are still testing and which items are pending.
2. **Build:** `node Util/test-build.js --dry-run`, then `node Util/test-build.js` (add `--with <branch>` for an
   untracked branch you need, e.g. tooling not yet on main), then `node Util/build-info.js`. It resets the local
   `test/next` branch to `origin/main`, merges every tracked PR branch, reports conflicts (fix those in the PR,
   not in test/next), and switches the working tree to it. Never push `test/next`. The maintainer's uncommitted
   `Customize/general.lua` stays as it is.
3. **Lineup:** `node Util/verify.js lineup`, then `lineup --suggest`; apply with `--write` only into free slots
   (Random / unset / "can free"); if none are free, the hero waits for a later game.
4. **Copy the build into Dota** (last, after the lineup is final): `node Util/export-bots.js --test-game`, run in
   the main clone. It copies only the bot scripts of `HEAD` (`test/next`), plus the uncommitted lineup and a
   `Customize/build_info.lua` for that commit, into `vscripts/bots`, so `[OHA-BUILD]` names the build and editing
   or switching branches in the clone during the game changes nothing in it. Check its output:
   - `NOT in the copy: ...` lists uncommitted code changes the game will not run. Commit them in their PR and
     rebuild, or tell the maintainer.
   - `is a link`: `vscripts/bots` is still the old dev link to the clone. Ask the maintainer before renaming it
     (e.g. to `bots-dev`); renaming changes what the game loads.
   - `has files this tool did not write`: list them to the maintainer. Use `--force` only after they agree.
   Any later change to the lineup or the build needs this step again before the game.
5. **Tell the user:** branch and build that will run (the `[OHA-BUILD]` version the export printed), the lineup
   table (pos / hero / what it tests), and the log lines to expect. Remind them to launch with `-condebug` in a
   Local Host lobby with Local Dev Script.
