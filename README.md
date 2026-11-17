# Open Hyper AI: Fretbots plugin

Optional server-side scripts for the [Open Hyper AI](https://github.com/anggara-ts/OpenHyperAI-too) Dota 2 bots. They give bots extra gold and XP, neutral items, a difficulty vote and sounds, to make the game harder. They are not part of the bot AI: the bots play without them, and they only run when you start them from the console.

This branch (`plugin-fretbots`) holds only the plugin. The bot script itself lives on the main branches.

| Path | What it is |
|---|---|
| `FretBots/`, `FretBots.lua` | Enhanced Fretbots mode: difficulty vote, bonus gold/XP by role, neutral items, death bonuses, sounds |
| `Buff/` | Lighter alternative: more GPM/XPM for core bots and random neutral items (see [`Buff/README.md`](Buff/README.md)) |
| `Customize/fretbots.lua` | Fretbots settings (difficulty, ally scale, vote, sounds) |
| `install/` | Install / uninstall scripts |

## Requirements

Open Hyper AI installed so that `dota 2 beta/game/dota/scripts/vscripts/bots` exists (Workshop quick install or a local dev-script link). The plugin uses the bot script's own libraries (`FuncLib`, `ts_libs`, `Customize`), so it must be the same or a compatible version.

## Install

Get this branch (download the ZIP of `plugin-fretbots`, or `git clone -b plugin-fretbots <repo>`), then:

- **Windows:** run `install\install-fretbots.bat`. It finds Dota through Steam. For another Steam library pass the folder: `install-fretbots.bat "D:\SteamLibrary\steamapps\common\dota 2 beta"`. Run it as Administrator if Dota is under Program Files and the copy fails.
- **macOS / Linux:** `bash install/install-fretbots.sh` (or pass the `dota 2 beta` folder as the first argument).

The installer copies `FretBots/`, `FretBots.lua`, `Buff/` and `Customize/fretbots.lua` into the `bots` folder, and puts your editable settings at `vscripts/game/Customize/fretbots.lua` (kept if it already exists).

If your `bots` folder is a link to the Steam Workshop download, a Workshop update can replace it: run the installer again after updates.

Uninstall: `install-fretbots.bat uninstall` or `install-fretbots.sh uninstall`. Your settings file is kept.

## Enable in a game

1. Play → Custom Lobbies → Create. Server location **Local Host**, **Enable Cheats** checked, bots set to the Local Dev Script (or Open Hyper AI).
2. Start the game. Once hero selection has started, open the console and run:
   ```
   sv_cheats 1
   script_reload_code bots/FretBots
   ```
   For the lighter Buff script instead: `script_reload_code bots/Buff/buff`. Run only one of the two, once per game.

## Settings

Edit `vscripts/game/Customize/fretbots.lua`:

| Setting | Meaning |
|---|---|
| `Default_Difficulty` | 0 to 10, used when nobody votes. 0 is almost no bonus, 1 a small edge, 2 heavy (a carry toward ~300 GPM), 5 about 1.2x, 10 about 2x |
| `Default_Ally_Scale` | 0 to 1, bonus for allied bots compared to enemy bots |
| `Allow_To_Vote` | `false` skips the chat vote and uses the default difficulty |
| `Play_Sounds` | `false` turns off all Fretbots sounds |
| `Player_Death_Sound` | chat-wheel taunt when a human player dies |

An old `Customize.Fretbots = { ... }` table in `general.lua` is still read when no `fretbots.lua` is found.

More about Fretbots mode: <https://github.com/forest0xia/dota2bot-OpenHyperAI/discussions/68>

## Credits

Fretbots by fretmute, adapted for Open Hyper AI by forest0xia. Buff script inspired by Fretbots.
