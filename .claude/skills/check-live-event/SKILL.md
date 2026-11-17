---
name: check-live-event
description: Check events the maintainer reports during a live OpenHyperAI game (e.g. "2:50 kez and tusk won't hit dawnbreaker trapped in ice shards") against the running console log, find the cause early, and record it on the right issue card. Use when the user posts in-game observations with game times while a game is running.
---

# Check a live event

The maintainer watches the game and tails the log themselves; don't stream or narrate the log. Rules:
`AGENTS.md` (Logging, Issue -> PR -> game test -> merge). Checklist:

1. **Find the running log:** the newest `console*.log` in `.../dota 2 beta/game/dota` (Dota tears off to
   `console.<matchid>.log` once the match has an ID). Read its `[OHA-MATCH] game ... version=` / `[OHA-BUILD]`
   line for the build and lineup.
2. **For each reported event** convert the game time to seconds (`2:50` -> `t=170`) and grep a window around it
   for the heroes involved, e.g.
   `grep -a -E "t=(1[6-8][0-9])[ .]" <log> | grep -a -iE "kez|tusk|dawnbreaker"` - look at mode flips
   (`[OHA-FLIP]`), retreat/evasive (`[OHA-RETREAT]`, `[OHA-EVASIVE]`), TP (`[OHA-TP]`), the hero's own
   `[OHA-<HERO>]` lines, and errors. Game times the maintainer gives are approximate: widen the window to
   +/- 30 s when nothing matches.
3. **Explain each event** in one or two lines: what the bot did (mode, desire, reason), why, and whether it is
   a bug, a known issue, or expected. Check Dota mechanics against game data / the datafeed before calling it.
4. **Record it** (don't fix code during the game; the game runs the checked-out files):
   - matches an existing issue card -> add a task item `- [ ] (game NNN, m:ss) ...` and a short comment with the
     log lines;
   - about a PR under test -> comment on that PR;
   - new -> keep it for `/review-game` to file as a grouped card.
5. Reply to the maintainer with the per-event explanation and where it was recorded.
