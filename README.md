# Supercharged OpenHyperAI

Dota 2 bot scripts for patch **7.42**: smarter laning, fights, retreats, runes and objectives, with up-to-date item
and skill builds for every hero.

- **Steam Workshop:** [Supercharged OpenHyperAI for 7.42](https://steamcommunity.com/sharedfiles/filedetails/?id=3843444501)
- **What's new:** [releases](https://github.com/anggara-ts/Supercharged-OpenHyperAI/releases)
- **Known limitations** (what bots can't do because of the bot API): [discussion #50](https://github.com/anggara-ts/Supercharged-OpenHyperAI/discussions/50)
- **Questions and feedback:** [discussions](https://github.com/anggara-ts/Supercharged-OpenHyperAI/discussions) or [issues](https://github.com/anggara-ts/Supercharged-OpenHyperAI/issues)

---

## Play

1. Subscribe to [Supercharged OpenHyperAI for 7.42](https://steamcommunity.com/sharedfiles/filedetails/?id=3843444501)
   on the Steam Workshop and let Steam finish the download.
2. In Dota 2: **Play** → **Custom Lobbies** → **+ Create**, then **Edit Lobby Settings**:
   - Server location: **Local Host** (third-party bot scripts only run on a local server; the "Play vs Bots" menu
     can't use them).
   - Bot Settings: choose the subscribed script for both Radiant and Dire.
3. Join a team. The slot you take is your role: 1 carry (safe lane), 2 mid, 3 offlane, 4 soft support, 5 hard
   support. The bots fill the other roles.
4. Start the game. When the script loaded, the bots' names end with **`.OHA-DEV`**.

If the bots play with Valve's default names, the script didn't load: see
[Run from this repository](#run-from-this-repository), or link the Workshop folder the same way (step 2 there,
with the Workshop folder `<Steam>/steamapps/workshop/content/570/3843444501` as the source).

## Settings

Picks, bans, the bot language, chat and other options are in `Customize/general.lua` (comments explain each one).
A Workshop update replaces that file. To keep your settings, copy the whole `Customize` folder to

```text
<Steam>/steamapps/common/dota 2 beta/game/dota/scripts/vscripts/game/Customize
```

and edit the copy there; it wins over the one in the script. Per-hero overrides go in `Customize/hero/`
(see `Customize/hero/viper.lua` for an example).

## In-game chat commands

| Command | What it does |
|---|---|
| `!pos X` | Swap your role with a bot (e.g. `!pos 2` for mid); before the horn |
| `!Xpos Y` | Move bot X to position Y (e.g. `!3pos 5`); before the horn |
| `!pick HERO` | Force a bot pick |
| `!ban HERO` | Ban a hero from bot picks; during the draft |
| `!sp XX` | Bot language: `en`, `zh`, `ru`, `ja` |

---

## Run from this repository

For the newest changes before they reach the Workshop, or to work on the scripts.

1. **Get the code**: `git clone https://github.com/anggara-ts/Supercharged-OpenHyperAI.git`, or download
   [the `main` zip](https://github.com/anggara-ts/Supercharged-OpenHyperAI/archive/refs/heads/main.zip) and extract it.
2. **Put it where Dota loads bot scripts**: `<Steam>/steamapps/common/dota 2 beta/game/dota/scripts/vscripts/bots`.
   The files must sit directly in `bots` (`.../vscripts/bots/bot_generic.lua`, not `.../bots/<folder>/bot_generic.lua`).
   Rename an existing `bots` folder first (e.g. `bots_old`). Either move the extracted folder there and name it
   `bots`, or link it so updates apply at once:
   - Windows (Command Prompt as Administrator):
     ```bat
     mklink /d "C:\Program Files (x86)\Steam\steamapps\common\dota 2 beta\game\dota\scripts\vscripts\bots" "C:\path\to\Supercharged-OpenHyperAI"
     ```
   - macOS / Linux:
     ```bash
     ln -s "/path/to/Supercharged-OpenHyperAI" "<Steam>/steamapps/common/dota 2 beta/game/dota/scripts/vscripts/bots"
     ```
   Contributors use `node Util/export-bots.js` instead, which copies only the bot scripts (see
   [`CONTRIBUTING.md`](CONTRIBUTING.md)).
3. **Play** as above, but choose **Local Dev Script** in Bot Settings.

The helper scripts in [`Install-to-vscript/`](Install-to-vscript/README.md) do step 2 for the Workshop folder.

## Project layout

| Path | What it is |
|---|---|
| `BotsLib/` | One file per hero: skill build, item build, ability use |
| `FuncLib/` | Shared libraries and systems (push, defend, wards, items, roles, ...) |
| `Customize/` | Player settings (picks, bans, language) |
| `mode_*_generic.lua` | Bot modes (laning, farm, retreat, push, defend, roshan, runes, ...) |
| `Util/` | Developer tools (log splitter, game review, test tracker, bot-script export) |
| `Tests/` | LuaJIT tests against a stub bot API |
| `Docs/` | Notes, e.g. what the bot API really exposes |
| `Install-to-vscript/` | Link helpers for the Workshop folder |

More on the libraries: [`FuncLib/README.md`](FuncLib/README.md). The optional Fretbots / Buff plugin (extra gold,
XP and neutral items for bots) lives on the [`plugin-fretbots`](../../tree/plugin-fretbots) branch.

## Contributing

[`CONTRIBUTING.md`](CONTRIBUTING.md) covers the setup (git hooks, signed commits, getting the scripts into Dota),
test games and the issue → PR → game test → merge flow. The rules for code and PRs are in
[`AGENTS.md`](AGENTS.md).

## Credits

Supercharged OpenHyperAI continues **Open Hyper AI (OHA)** by **forest0xia**
([dota2bot-OpenHyperAI](https://github.com/forest0xia/dota2bot-OpenHyperAI)), which itself builds on Valve's
default bots and earlier community scripts: jmz / New Beginner AI, ryndrb, adamqqq, fretmute (Fretbots) and others.
The Linux install script is based on ashoktamang's
[dota2bot-OpenHyperAI-linux-patcher](https://github.com/ashoktamang/dota2bot-OpenHyperAI-linux-patcher).
Thanks to all of them.
