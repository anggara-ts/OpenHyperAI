---
name: merge-pr
description: Merge an OpenHyperAI PR whose in-game checks all passed - tick the checks, mute proven logs, squash-merge, clean up the tracker, lineup and branch. Use when Util/verify.js shows a PR as READY TO MERGE.
---

# Merge a verified PR

Rules: `AGENTS.md` (workflow step 9). The agent decides and merges without asking (maintainer approval,
2026-11-17), then reports what it merged. Checklist:

1. **Ready?** `node Util/verify.js show <pr>` says READY TO MERGE (every item pass or skip) and the PR's CI is
   green (`gh pr checks <pr>`), and no PR it contains (stacked base) is still unready. Otherwise stop and say why.
2. **Mute proven noise:** `node Util/verify.js mute-suggest <pr>` lists the passed `[OHA-*]` tags; add the
   noisy ones to `OHA_MUTED` in `FuncLib/systems/global_overrides.lua` in this PR (keep logs that report
   errors or rare decisions). Commit, push, wait for CI.
3. **Tick the checks** in the PR description ("Tested in a local game (game NNN)" and the verify items) with
   `gh pr edit <pr> --body-file ...`; mark ready if it is a draft (`gh pr ready <pr>`).
4. **Merge:** `gh pr merge <pr> --squash --delete-branch`. Stacked PRs: merge the base first.
5. **Issues:** for every issue the PR refers to (`Refs #N`), tick the task items this PR fixed and verified,
   and comment on the issue: which items, the PR link and the game that proved them. **Close the issue only
   when every task item in it is ticked**; otherwise leave it open (the PR never uses `Closes #N`).
6. **Clean up:** `node Util/verify.js done <pr>`; set its lineup slots back to `"Random"` (`verify.js lineup`
   shows them as "can free"); for any later PR built on this one, `git merge origin/main` into it and push.
7. Tell the user what was merged, which issue items were ticked or closed, and what is still testing.
