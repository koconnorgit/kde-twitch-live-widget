#!/bin/sh
# Install or upgrade the Twitch Live widget for the current user.
# Works on any KDE Plasma 6 system; no paths are hardcoded.
set -e

PLUGIN_ID="io.github.koconnorgit.twitchlive"
PKG_DIR="$(cd "$(dirname "$0")" && pwd)/package"

if ! command -v kpackagetool6 >/dev/null 2>&1; then
    echo "Error: 'kpackagetool6' not found." >&2
    echo "Install your distribution's Plasma packages (e.g. plasma-workspace) and retry." >&2
    exit 1
fi

if [ ! -f "$PKG_DIR/metadata.json" ]; then
    echo "Error: widget package not found at $PKG_DIR" >&2
    exit 1
fi

if kpackagetool6 --type Plasma/Applet --show "$PLUGIN_ID" >/dev/null 2>&1; then
    echo "Upgrading $PLUGIN_ID …"
    kpackagetool6 --type Plasma/Applet --upgrade "$PKG_DIR"
else
    echo "Installing $PLUGIN_ID …"
    kpackagetool6 --type Plasma/Applet --install "$PKG_DIR"
fi

echo
echo "Done. Add it via 'Add Widgets…' and search for \"Twitch Live\"."
echo "If it doesn't appear yet, restart Plasma:"
echo "    kquitapp6 plasmashell && kstart plasmashell"
