---
name: prepare-workshop
description: Put a clean, ready-to-upload copy of the OpenHyperAI bot scripts (origin/main or a release tag, exactly as committed - no lineup, no git, env, tests, tools or logs) into Dota's vscripts/bots for the Steam Workshop uploader. Use when the maintainer wants to publish or update the bot script on the Workshop, or asks for a clean copy.
---

# Prepare a Workshop upload

Tool: `Util/export-bots.js` (`--help`). Rules: `AGENTS.md` (Commits: version files; Things not to do).
The Workshop Tools uploader publishes the contents of `vscripts/bots`, so that folder must hold only the bot
scripts. Never upload the clone or a link to it: it has `.git`, `.env` (API tokens), `Util/match-logs/` (the
host's Steam ID and server IPs) and the local test lineup.

1. **Ask first:** is a test game prepared or about to be played? The export replaces what Local Dev Script runs,
   so do this between games and run `/prepare-game` again afterwards.
2. **What to publish:** a release tag (after `/release publish`, so the version files carry the release number
   the Workshop copy shows: it has no `build_info.lua`, `[OHA-BUILD]` prints `commit=release`) or `origin/main`.
   `git fetch origin --tags`, then `node Util/export-bots.js --dry-run [--ref vX.Y]`.
3. **Check the dry run:**
   - the ref and commit are the ones to publish, `left out` lists the non-script folders, no `required files
     missing` error;
   - `is a link`: `vscripts/bots` is the old dev link to the clone. Ask the maintainer before renaming it (e.g. to
     `bots-dev`);
   - `has files this tool did not write`: show them to the maintainer; `--force` (deletes them) only after they
     agree.
4. **Export:** the same command without `--dry-run`. A copy left by `/prepare-game` is updated in place (the tool
   deletes only files it wrote; the lineup and `build_info.lua` go away).
5. **Optional smoke test:** a Local Host lobby with Local Dev Script; `[OHA-BUILD]` shows `commit=release` and the
   release number, the default lineup drafts.
6. **Upload (the maintainer does it; publishing is outward-facing, never do it yourself):** Dota 2 Workshop Tools →
   Bot Scripting → create a new bot script or pick the existing one → title, description, preview image →
   submit. (From Valve's 22 July 2017 patch notes; the menu may have moved since.) The Steam account must not be a
   limited account.
7. **After:** leave the copy, or `node Util/export-bots.js --remove`, then `/prepare-game` before the next test
   game.

Not in the copy on purpose (maintainer's decision, #177): `Install-to-vscript/` and docs. The Workshop copy is
the bot scripts only. `Customize/general.lua` and `Customize/hero/viper.lua` still link the upstream Workshop item
3246316298 in their comments; a first upload of this fork gets a new ID.

New Lua files: a committed file under the root, `BotsLib/`, `FuncLib/` or `Customize/` is in the copy
automatically. A `.lua` file in any other new folder stops the export until the folder is added to
`RUNTIME_DIRS` or `NOT_RUNTIME_DIRS` in `Util/export-bots.js`.
