#!/bin/sh
# Install (or upgrade) the Twitch Live plasmoid for the current user.
set -e

PKG="$(cd "$(dirname "$0")" && pwd)/package"

if ! command -v kpackagetool6 >/dev/null 2>&1; then
    echo "kpackagetool6 not found. Install plasma-sdk / plasma-workspace first." >&2
    exit 1
fi

if kpackagetool6 --type Plasma/Applet --show com.kevin.twitchlive >/dev/null 2>&1; then
    echo "Upgrading existing install…"
    kpackagetool6 --type Plasma/Applet --upgrade "$PKG"
else
    echo "Installing…"
    kpackagetool6 --type Plasma/Applet --install "$PKG"
fi

echo
echo "Done. Add it via 'Add Widgets…' → search \"Twitch Live\","
echo "or drop it on the desktop/panel."
echo "If it doesn't show up, restart the shell:"
echo "    kquitapp6 plasmashell && (kstart plasmashell >/dev/null 2>&1 &)"
