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
5. **No PR yet.** Filing a card opens no PR. Work starts later with `node Util/issue-prs.js <N>` (branch + draft PR,
   `Refs #N`, never `Closes #N`), from `/create-pr` or `/goodnight`.
6. Tell the user the issue numbers and priorities in a short table.

**Priority:** give every new card exactly one of `P1 critical`, `P2 high`, `P3 medium`, `P4 low` (definitions
in AGENTS.md step 1), with the reason in one line on the card. `node Util/issue-prs.js` (no numbers) copies it
to the issue's PRs and lists untriaged issues.
