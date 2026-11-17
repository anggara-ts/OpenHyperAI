---
name: prepare-game
description: Get the local OpenHyperAI checkout ready for the next test game - build the test/next integration branch from main plus every tracked PR, set the test lineup, and tell the user what the game will test. Use before the user plays, or when asked "what does the next game test".
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
4. **Tell the user:** branch and build that will run, the lineup table (pos / hero / what it tests), and the
   log lines to expect. Remind them to launch with `-condebug` in a Local Host lobby with Local Dev Script.
