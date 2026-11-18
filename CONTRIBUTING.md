# Contributing to Open Hyper AI

Thanks for helping make the Dota 2 bots better. This guide gets a contributor from a fresh machine to a merged
pull request. The detailed rules (naming, logging, PR format, the full workflow) are in [`AGENTS.md`](AGENTS.md),
which both people and AI coding agents follow. Read it once before your first PR.

## What you need

| Tool | Why | Required? |
|---|---|---|
| Dota 2 (Steam) | the bots run inside the game | yes |
| Git 2.40+ | version control; commits must be **signed** | yes |
| Node.js 18+ | the developer tools in `Util/` (log splitter, tracker, build helpers) | yes |
| Python 3.9+ and [pre-commit](https://pre-commit.com) | git hooks: StyLua formatting, no commits on `main`, file-size limit, build info | yes |
| [GitHub CLI](https://cli.github.com) (`gh`) | issues and PRs from the terminal, used by `Util/issue-prs.js` and `Util/after-game.js` | recommended |
| LuaJIT | run the tests locally (`luajit Tests/run.lua`); CI runs them anyway | optional |
| luacheck | lint locally; CI runs it anyway | optional |

StyLua is installed and pinned automatically by pre-commit (version 2.6.0, the same as CI). For editor support,
the VS Code extension **StyLua** (JohnnyMorganz.stylua) formats on save with the repo's `stylua.toml`.

## One-time setup

### 1. Get the code

```bash
git clone git@github.com:anggara-ts/OpenHyperAI-too.git
cd OpenHyperAI-too
```

Contributors without write access fork the repo on GitHub, clone their fork, and open PRs from it.

### 2. Install the git hooks

```bash
pip install pre-commit
pre-commit install --install-hooks
```

This installs:
- **On every commit:**
  - refuse commits on `main`;
  - refuse new files over 500 KB;
  - format staged `.lua` files with StyLua. If StyLua changed something, the commit stops: `git add` the formatted files and commit again.
- **After every checkout, commit, merge or rebase:** write `Customize/build_info.lua` (git-ignored), so every game prints the exact commit it runs (`[OHA-BUILD]`).

### 3. Sign your commits

Branch rules reject unsigned commits. The simplest way is SSH signing with your existing SSH key:

```bash
git config gpg.format ssh
git config user.signingkey ~/.ssh/id_ed25519.pub
git config commit.gpgsign true
```

Then on GitHub go to **Settings → SSH and GPG keys → New SSH key**, set **Key type: Signing Key**, and paste the same public key. Commits show **Verified** on GitHub once this is done. (GPG keys work too, but GitHub must have verified the email in the key.)

### 4. Point Dota at your checkout

Dota loads bot scripts from `dota 2 beta/game/dota/scripts/vscripts/bots`. Make that folder a link to your clone, so the game runs whatever branch you have checked out. Rename an existing `bots` folder first.

- **Windows** (Command Prompt):
  ```bat
  mklink /J "C:\Program Files (x86)\Steam\steamapps\common\dota 2 beta\game\dota\scripts\vscripts\bots" "C:\path\to\OpenHyperAI-too"
  ```
- **macOS:**
  ```bash
  ln -s ~/path/to/OpenHyperAI-too "$HOME/Library/Application Support/Steam/steamapps/common/dota 2 beta/game/dota/scripts/vscripts/bots"
  ```
- **Linux:**
  ```bash
  ln -s ~/path/to/OpenHyperAI-too "$HOME/.local/share/Steam/steamapps/common/dota 2 beta/game/dota/scripts/vscripts/bots"
  ```

Settings come from `vscripts/game/Customize/general.lua` when that file exists (the Workshop installer creates it), otherwise from the repo's `Customize/general.lua`. While developing, rename `vscripts/game/Customize`, so your edits to the repo copy take effect.

### 5. Log the console

Add `-condebug` to Dota's launch options (Steam → Dota 2 → Properties → Launch Options). The console is then written to `game/dota/console*.log`. The review tools read those logs.

### 6. API tokens (optional)

Some developer tools read API tokens from a `.env` file in the repo root. It is git-ignored, so the tokens stay
on your machine. Start from the template:

```sh
cp .env.example .env
```

then fill in the values. Each one is explained in `.env.example`. Today there is one:

| Variable | Used by | How to get it |
|---|---|---|
| `STRATZ_TOKEN` | item-build second opinion (`Util/item-builds/`, issues #9, #38): its only data source, per position and week | log in to [stratz.com](https://stratz.com) with Steam, open your account's API section, copy the token |

Without a token, the tools that need it stop with a message saying so.
Never commit `.env`, paste a token into an issue or PR, or print it in a log. If a token leaks, revoke it on
the site and make a new one.

## Playing a test game

1. Dota 2 → **Play → Custom Lobbies → Create**.
2. **Server location: Local Host.** Bot scripts other than Valve's only load on a local server.
3. **Bot Settings: Local Dev Script** for Radiant and Dire.
4. Fill the slots with bots and start.

To test specific heroes, put them in `Customize.Radiant_Heros` / `Customize.Dire_Heros` in `Customize/general.lua`. That's a local test lineup: **never commit it**. `node Util/verify.js lineup --suggest` can fill free slots with the heroes that open PRs need.

After the game:

```bash
node Util/after-game.js    # split the console, map the build, check tracked PRs, write a review skeleton
```

Match logs go to `Util/match-logs/` (git-ignored). They contain your Steam account ID and server IPs, so never commit or share them.

## Making a change

1. **Start from an issue.** Every change starts as a GitHub issue. Problems in an area are grouped into one card, with one task item per problem.
   - When work on an issue starts, maintainers run `node Util/issue-prs.js <N>` to create its branch and draft PR.
   - Otherwise create a branch from `main`: `fix/<topic>`, `feat/<topic>`, `chore/<topic>` or `docs/<topic>`.
2. **Write the code** following `AGENTS.md`:
   - readable names, no new globals;
   - `GetTeamMember` takes team slots 1-5, not player IDs;
   - Dota facts from the game files or the [Valve datafeed](https://www.dota2.com/datafeed/herodata?language=english&hero_id=1), never from memory;
   - a throttled `[OHA-<TAG>] t=... <hero> ...` log line for every new or uncertain behaviour.
3. **Check locally.**
   - StyLua runs on commit.
   - Run `luajit Tests/run.lua` if you have LuaJIT.
   - There's no manual version bump: the build is identified from git.
4. **Commit and push.**
   - Use a conventional commit message (`fix(scope): ...`, `feat: ...`) whose body says what was wrong and what changed.
   - Never stage `Customize/general.lua` test lineups.
5. **Open the PR** with the template, using the change-log format:
   - each change is one entry with its type (crash / mechanic / behaviour / cleanup), **Before:** and **Now:**, in one or two sentences;
   - list the `[OHA-*]` lines that prove it in "How to verify in game";
   - reference the issue with `Refs #N`, never `Closes #N`.
6. **CI must be green:** LuaJIT syntax, luacheck, StyLua and Tests (`.github/workflows/lua-check.yml`).
7. **Test it in a game.**
   - Changes the bots act on are tracked (`node Util/verify.js add <pr>`) until a game proves them.
   - `node Util/test-build.js` builds a local `test/next` branch with every PR under test, so one game checks several PRs.
8. **Merge.** When every item passes, the PR is squash-merged.
   - The issue's task items are ticked.
   - The issue is closed only when all of its items are done.

## Repo layout

| Path | What it is |
|---|---|
| `BotsLib/hero_<name>.lua` | one file per hero: builds and ability use |
| `FuncLib/` | shared code: helpers (`Fu`), systems (push, defend, wards, items, roles, logging), hero helpers, Dota constants and libraries |
| `mode_*_generic.lua`, `hero_selection.lua`, `ability_item_usage_generic.lua`, `item_purchase_generic.lua`, `bot_generic.lua` | engine entry points. Dota loads them only from the repo root, by exact name |
| `Customize/` | user settings (`general.lua`) and the release version |
| `Util/` | Node.js developer tools; see [`Util/README.md`](Util/README.md) |
| `Tests/` | LuaJIT tests with a stub bot API |
| `Docs/` | notes such as what the bot API really exposes |
| `.claude/skills/` | step-by-step playbooks for AI agents (Claude Code) |

The optional Fretbots / Buff plugin (extra gold, XP and neutral items for bots) lives on the `plugin-fretbots` branch, with its own README and installer.

## Reporting bugs and ideas

Open a GitHub issue. Include:
- the game time;
- the heroes involved;
- what the bot did and what you expected;
- if you have it, the build line (`[OHA-BUILD]` or `[OHA-MATCH] ... version=`) and the relevant console lines.

You can also comment observations on the PR you are testing, with game times (e.g. "20:30 radiant team dove behind the dire bottom T1").

## Credits

Open Hyper AI builds on [forest0xia/dota2bot-OpenHyperAI](https://github.com/forest0xia/dota2bot-OpenHyperAI) and earlier community bot scripts. If a fix belongs upstream, consider contributing it back there too.
