---
name: start-issue
description: File findings or requests as grouped GitHub issue cards for OpenHyperAI and open a draft PR for each. Use after a game review, when the user reports bot behaviour, or when asked to "create an issue/card".
---

# Start an issue

Rules live in `AGENTS.md` ("Issue -> PR -> game test -> merge", step 1-2). This is the checklist.

1. **Group first.** Put findings that share a cause or an area into one card (one hero, one mode, one system).
   Never one card per log line; never a card mixing unrelated areas.
2. **Write each card** with: Source (game NNN / PR comment / review), every problem as a **task item**
   `- [ ] (game NNN, m:ss) ...` with its log line where possible, Where (files/functions), and "Done when" (the
   `[OHA-*]` lines or game outcome that prove it). Task items are how the card gets closed: one item per thing
   to fix or confirm. New findings for an existing card are added as new task items, not new cards.
   Dota facts must come from game data or the Valve datafeed, not memory.
3. **Labels:** `bug` or `enhancement`, plus `game-review` (from watching/reviewing a game),
   `needs-confirmation` (verify next game), `design` (needs the maintainer's decision), `no-pr` (no draft PR).
4. **Create** with `gh issue create --title ... --body-file ... --label ...` (gh is logged in; on Windows use
   `C:\Program Files\GitHub CLI\gh.exe`).
5. **Open draft PRs:** `node Util/issue-prs.js --dry-run`, then `node Util/issue-prs.js`. They say `Refs #N`,
   never `Closes #N`: a merged PR must not close the issue.
6. Tell the user the issue and PR numbers in a short table.
