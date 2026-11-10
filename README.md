# OpenHyperAI

Custom Dota 2 bot scripts based on **Open Hyper AI (OHA)**.

This repository is a fork / continued work of the original project by **forest0xia**:

- Original author & upstream: [https://github.com/forest0xia/dota2bot-OpenHyperAI](https://github.com/forest0xia/dota2bot-OpenHyperAI)
- Steam Workshop (upstream): [Open Hyper AI](https://steamcommunity.com/sharedfiles/filedetails/?id=3246316298)

> Create a **Custom Lobby** and set the server location to **Local Host**. When the scripts load correctly, bot names usually end with **`.OHA`** / **`OHA-DEV`**.

---

## Setup (from this GitHub repo)

Dota only loads bot scripts from:

```text
<Steam>/steamapps/common/dota 2 beta/game/dota/scripts/vscripts/bots
```

### 1. Clone the repo

```bash
git clone https://github.com/anggara-ts/OpenHyperAI.git
```

Put the clone wherever you like (for example `Documents\OpenHyperAI`).

### 2. Install into Dota’s `vscripts/bots` folder

**Option A — symlink (recommended for development)**

Point Dota’s `bots` folder at this repo so edits apply immediately.

**Windows** (run Command Prompt / PowerShell **as Administrator**):

```bat
mklink /d "C:\Program Files (x86)\Steam\steamapps\common\dota 2 beta\game\dota\scripts\vscripts\bots" "C:\Users\<YOU>\Documents\OpenHyperAI"
```

Adjust both paths if your Steam library or clone location differs. If a `bots` folder already exists, rename or remove it first.

**macOS / Linux:**

```bash
ln -s "/path/to/OpenHyperAI" "$HOME/.steam/steam/steamapps/common/dota 2 beta/game/dota/scripts/vscripts/bots"
```

**Option B — use the included install scripts**

If you also have the Workshop copy, see [`Install-to-vscript/README.md`](Install-to-vscript/README.md) for Windows / macOS / Linux helper scripts that symlink Workshop → `vscripts/bots`.

For a pure Git install, Option A is enough.

### 3. (Optional) Permanent Customize folder

To keep settings across updates/copies, copy `Customize/` to:

```text
<Steam>/steamapps/common/dota 2 beta/game/dota/scripts/vscripts/game/Customize
```

Edit picks, bans, language, and related options in `Customize/general.lua`.

### 4. Play

1. Open Dota 2  
2. **Play** → **Custom Lobby** → create lobby  
3. Server location: **Local Host**  
4. Fill empty slots with bots and start  

---

## Alternative: Steam Workshop (upstream)

You can still install the upstream Workshop build:

1. Subscribe to [Open Hyper AI on Steam Workshop](https://steamcommunity.com/sharedfiles/filedetails/?id=3246316298)  
2. Run the installer under `Install-to-vscript` (see [`Install-to-vscript/README.md`](Install-to-vscript/README.md))  
3. Use a **Local Host** custom lobby  

This GitHub repo is for local development and changes on top of that work.

---

## Useful in-game commands

| Command | Description |
|---|---|
| `!pos X` | Swap your role with a bot (e.g. `!pos 2` for mid) |
| `!Xpos Y` | Reassign bot positions (e.g. `!3pos 5`) |
| `!pick HERO` | Force-pick a hero |
| `!ban HERO` | Ban a hero from bot picks |
| `!sp XX` | Bot language (`en`, `zh`, `ru`, `ja`) |

---

## Project layout (short)

| Path | Role |
|---|---|
| `BotsLib/` | Per-hero builds & ability logic |
| `FuncLib/` | Shared bot libraries & systems |
| `FretBots/` | Optional harder / bonus mode |
| `Customize/` | User settings (picks, bans, locale) |
| `Install-to-vscript/` | Symlink install helpers |
| `mode_*_generic.lua` | Mode scripts (farm, push, defend, roam, …) |

More detail on libraries: [`FuncLib/README.md`](FuncLib/README.md).

---

## Credits

- **Original Open Hyper AI** — [forest0xia / dota2bot-OpenHyperAI](https://github.com/forest0xia/dota2bot-OpenHyperAI)  
- Built on Valve’s default bots and earlier community scripts (jmz / New Beginner AI, ryndrb, adamqqq, fretmute / fretbots, and others — see the upstream README for the full list)

If you improve something here that belongs upstream, consider contributing back to [forest0xia/dota2bot-OpenHyperAI](https://github.com/forest0xia/dota2bot-OpenHyperAI).
