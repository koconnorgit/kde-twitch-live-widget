#!/bin/sh
# Remove the Who's Live widget for the current user.
set -e

PLUGIN_ID="io.github.koconnorgit.whoslive"

if ! command -v kpackagetool6 >/dev/null 2>&1; then
    echo "Error: 'kpackagetool6' not found." >&2
    exit 1
fi

kpackagetool6 --type Plasma/Applet --remove "$PLUGIN_ID"
echo "Removed $PLUGIN_ID."
echo "If the widget is still on your desktop or panel, remove it there too."
