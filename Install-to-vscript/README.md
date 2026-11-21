## Quick Install Scripts

These scripts put the Steam Workshop download (`workshop/content/570/3843444501`) into Dota's `vscripts/bots`
folder (a link on Windows and macOS, a copy on Linux), for players whose bots don't load from the Workshop folder
alone. Then choose **Local Dev Script** in the lobby's Bot Settings, with server location **Local Host**.

The Workshop download holds only the bot scripts, not this folder: get the scripts from GitHub (this folder, or the
[repository zip](https://github.com/anggara-ts/Supercharged-OpenHyperAI/archive/refs/heads/main.zip)).

### Available Scripts

| File                         | OS      | Language |
| ---------------------------- | ------- | -------- |
| `quick-install-oha.bat`      | Windows | English  |
| `quick-install-oha-cn.bat`   | Windows | Chinese  |
| `quick-install-oha-mac.sh`   | macOS   | English  |
| `quick-install-oha-linux.sh` | Linux   | English  |

---

## Usage — Windows

1. In Dota 2, subscribe to **Supercharged OpenHyperAI** in the Steam Workshop. Wait for the download to complete.
2. Put this `Install-to-vscript` folder inside the Workshop folder, so the script sits at
   `Steam\steamapps\workshop\content\570\3843444501\Install-to-vscript\quick-install-oha.bat` (the Windows script
   finds Steam from its own location).
3. Double-click `quick-install-oha.bat` to install.

**Finding the folder:** Right-click Dota 2 in your Steam Library → Properties → Installed Files → Browse. This opens `Steam\steamapps\common\dota 2 beta`. In the address bar, replace `common\dota 2 beta` with `workshop\content\570\3843444501` and press Enter.

---

## Usage — macOS

1. Subscribe to **Supercharged OpenHyperAI** in the Steam Workshop and wait for download.
2. Open Terminal.
3. Go to the folder where you saved the script (it finds the Workshop folder by itself):
    ```bash
    cd ~/Downloads/Install-to-vscript
    ```
4. Make it executable and run:
    ```bash
    chmod +x quick-install-oha-mac.sh
    sudo ./quick-install-oha-mac.sh
    ```

---

## Usage — Linux

1. Subscribe to **Supercharged OpenHyperAI** in the Steam Workshop and wait for download.
2. Open a terminal.
3. Go to the folder where you saved the script:
    ```bash
    cd ~/Downloads/Install-to-vscript
    ```
4. Make it executable and run:
    ```bash
    chmod +x quick-install-oha-linux.sh
    sudo ./quick-install-oha-linux.sh
    ```

The Linux script automatically checks multiple common Steam install locations (`~/.steam/steam`, `~/.local/share/Steam`, `~/.steam/debian-installation`).

---

## How It Works

The script creates a **symbolic link** from the Workshop folder to the Dota 2 vscripts directory:

```
Workshop:  Steam/steamapps/workshop/content/570/3843444501
     ↓ (symlink)
Target:    Steam/steamapps/common/dota 2 beta/game/dota/scripts/vscripts/bots
```

Any Workshop updates to the script will automatically appear in the local dev folder.

## Why Is This Needed?

Some players experience issues where bots fail to load correctly from the Workshop folder alone. Installing the scripts to the vscripts/bots folder via symlink resolves these issues while keeping auto-updates from Workshop.

## Uninstall

To uninstall, simply delete the symbolic link in the target folder:

**Windows:**

```cmd
rmdir "C:\Program Files (x86)\Steam\steamapps\common\dota 2 beta\game\dota\scripts\vscripts\bots"
```

**macOS:**

```bash
rm ~/Library/Application\ Support/Steam/steamapps/common/dota\ 2\ beta/game/dota/scripts/vscripts/bots
```

**Linux:**

```bash
rm ~/.steam/steam/steamapps/common/dota\ 2\ beta/game/dota/scripts/vscripts/bots
```

This only removes the shortcut — your Workshop subscription and Dota 2 files are not affected.

---

## Troubleshooting

-   **"Steam folder not found"**: Make sure Steam and Dota 2 are installed. If Steam is in a custom location, edit the script and set the path manually.
-   **"Workshop folder not found"**: Subscribe to Supercharged OpenHyperAI in Workshop and wait for the download to complete before running the script.
-   **Permission errors**: Run with administrator privileges (`Run as Administrator` on Windows, `sudo` on Mac/Linux).
-   **Bots still not loading**: Create a Custom Lobby and select **Local Host** as the server location.

For more detailed guides: https://github.com/anggara-ts/Supercharged-OpenHyperAI/discussions
