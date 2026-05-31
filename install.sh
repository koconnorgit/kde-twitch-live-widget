#!/bin/sh
# Install or upgrade the Who's Live widget for the current user.
# Works on any KDE Plasma 6 system; no paths are hardcoded.
set -e

PLUGIN_ID="io.github.koconnorgit.whoslive"
# Former id (the widget used to be "Twitch Live"); removed on install so the
# old entry doesn't linger in "Add Widgets…" alongside the renamed one.
OLD_PLUGIN_ID="io.github.koconnorgit.twitchlive"
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

# Clean up the pre-rename package if it's still installed.
if kpackagetool6 --type Plasma/Applet --show "$OLD_PLUGIN_ID" >/dev/null 2>&1; then
    echo "Removing the old \"Twitch Live\" package ($OLD_PLUGIN_ID) …"
    kpackagetool6 --type Plasma/Applet --remove "$OLD_PLUGIN_ID" || true
    echo "Note: if a \"Twitch Live\" widget is still on your desktop/panel, remove it"
    echo "      and add \"Who's Live\" instead (your settings don't carry over)."
fi

echo
echo "Done. Add it via 'Add Widgets…' and search for \"Who's Live\"."
echo "If it doesn't appear yet, restart Plasma:"
echo "    kquitapp6 plasmashell && kstart plasmashell"
