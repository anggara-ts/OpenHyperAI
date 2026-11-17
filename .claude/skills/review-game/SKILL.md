---
name: review-game
description: Review the latest OpenHyperAI bot game after the user says a game ended - split logs, check tracked PRs, read the maintainer's PR comments, find problems, update the tracker and issues. Use when the user says "game ended", "review the game", or similar.
---

# Review a game

Rules: `AGENTS.md` ("Reviewing a game", workflow steps 7-8). Checklist:

1. **Collect:** `node Util/after-game.js` - splits the console, finds the newest game and its build/commit,
   runs the tracker check, groups script errors, ranks log spam, pulls the scoreboard/deaths and the
   maintainer's PR comments since the last review, and writes `Util/match-logs/game-NNN_review.md`.
2. **Read the skeleton**, then go deeper only where needed (spawn parallel read-only reviewers for big games:
   one for heroes/features, one for team behaviour; give them the review file, the build commit and what is
   already fixed).
3. **Tracker:** for every item `verify.js check` left pending or flagged, read the sample lines and set
   `node Util/verify.js set <pr> <item> pass|fail|skip [note]`. Items whose situation didn't happen stay pending.
   `set` and `check` also update the PR: its "How to verify in game" checkboxes and, once every item is done,
   "Tested in a local game", the **Ready to merge** label and a "Ready to merge (blocked by #N)" line.
4. **Maintainer comments:** each observation becomes either a fix in the PR it is about, or part of a grouped
   issue card (skill `start-issue`).
5. **Findings:** write them as time + log line / why it matters / code location / suggested fix / confidence.
   Verify Dota mechanics against game data. File grouped issues (no PR until work starts).
5b. **Re-triage:** check the priority labels of the issues this game touched (raise what keeps happening,
   lower what was rare), then `node Util/issue-prs.js` so the PRs follow.
6. **Lineup for the next game:** `node Util/verify.js lineup` and `lineup --suggest [--write]` (free slots
   only; wait a game if none are free).
7. **Merge what passed:** skill `merge-pr` for every PR that `node Util/verify.js show` marks READY.
8. **Report** to the user: how the game went in 3-4 lines, what passed/failed per PR, new issues, the next
   lineup, and what you'll fix next.
