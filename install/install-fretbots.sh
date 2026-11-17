#!/usr/bin/env bash
# Installs the Fretbots / Buff plugin into the Open Hyper AI bots folder (macOS / Linux).
# Usage:
#   ./install-fretbots.sh                         (default Steam location)
#   ./install-fretbots.sh "/path/to/dota 2 beta"
#   ./install-fretbots.sh uninstall [dota path]
# Needs the Open Hyper AI bot script already installed (vscripts/bots exists).
set -euo pipefail

MODE=install
if [ "${1:-}" = "uninstall" ]; then
	MODE=uninstall
	shift
fi

PLUGIN="$(cd "$(dirname "$0")/.." && pwd)"
DOTA="${1:-}"
if [ -z "$DOTA" ]; then
	for c in \
		"$HOME/Library/Application Support/Steam/steamapps/common/dota 2 beta" \
		"$HOME/.steam/steam/steamapps/common/dota 2 beta" \
		"$HOME/.local/share/Steam/steamapps/common/dota 2 beta"; do
		if [ -d "$c" ]; then DOTA="$c"; break; fi
	done
fi
VS="$DOTA/game/dota/scripts/vscripts"
BOTS="$VS/bots"
if [ -z "$DOTA" ] || [ ! -d "$BOTS" ]; then
	echo "Could not find the bots folder: $BOTS"
	echo "Install Open Hyper AI first, or pass your 'dota 2 beta' folder as the first argument."
	exit 1
fi

if [ "$MODE" = "uninstall" ]; then
	echo "Removing Fretbots plugin from $BOTS"
	rm -rf "$BOTS/FretBots" "$BOTS/Buff" "$BOTS/FretBots.lua" "$BOTS/Customize/fretbots.lua"
	echo "Done. Your settings in $VS/game/Customize/fretbots.lua were kept."
	exit 0
fi

echo "Installing Fretbots plugin into $BOTS"
mkdir -p "$BOTS/Customize" "$VS/game/Customize"
rm -rf "$BOTS/FretBots" "$BOTS/Buff"
cp -R "$PLUGIN/FretBots" "$BOTS/FretBots"
cp -R "$PLUGIN/Buff" "$BOTS/Buff"
cp "$PLUGIN/FretBots.lua" "$BOTS/FretBots.lua"
cp "$PLUGIN/Customize/fretbots.lua" "$BOTS/Customize/fretbots.lua"
if [ -f "$VS/game/Customize/fretbots.lua" ]; then
	echo "Keeping your existing settings: $VS/game/Customize/fretbots.lua"
else
	cp "$PLUGIN/Customize/fretbots.lua" "$VS/game/Customize/fretbots.lua"
	echo "Settings: $VS/game/Customize/fretbots.lua"
fi
echo
echo "Done. In a Local Host lobby with cheats enabled, after hero selection starts, open the console and run:"
echo "  sv_cheats 1"
echo "  script_reload_code bots/FretBots"
echo "(or script_reload_code bots/Buff/buff for the lighter Buff script)"
