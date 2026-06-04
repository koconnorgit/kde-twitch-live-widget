#!/bin/sh
# Build the installable .plasmoid artifact from the package/ directory.
# The .plasmoid is just a zip of package/ with metadata.json at the archive
# root, which is what both `kpackagetool6 --install` and the KDE Store expect.
# The version comes straight from metadata.json so it can't drift from the tag.
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PKG_DIR="$SCRIPT_DIR/package"
META="$PKG_DIR/metadata.json"

if [ ! -f "$META" ]; then
    echo "Error: $META not found" >&2
    exit 1
fi

VERSION=$(sed -n 's/.*"Version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$META")
if [ -z "$VERSION" ]; then
    echo "Error: could not read \"Version\" from $META" >&2
    exit 1
fi

OUT="$SCRIPT_DIR/whos-live-v$VERSION.plasmoid"
rm -f "$OUT"

# Build the archive with paths relative to package/, so metadata.json lands at
# the archive root (what kpackagetool6 and the KDE Store expect). Prefer the
# `zip` tool; fall back to Python's zipfile when it isn't installed, so the same
# script works on a bare desktop and on a CI runner. Dotfiles / editor clutter
# are excluded either way.
if command -v zip >/dev/null 2>&1; then
    ( cd "$PKG_DIR" && zip -r -q -X "$OUT" . -x '.*' '*/.*' '*~' '*.swp' )
elif command -v python3 >/dev/null 2>&1; then
    OUT="$OUT" PKG_DIR="$PKG_DIR" python3 - <<'PY'
import os, zipfile
out, pkg = os.environ["OUT"], os.environ["PKG_DIR"]
with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
    for root, dirs, files in os.walk(pkg):
        dirs[:] = sorted(d for d in dirs if not d.startswith("."))
        for name in sorted(files):
            if name.startswith(".") or name.endswith(("~", ".swp")):
                continue
            full = os.path.join(root, name)
            z.write(full, os.path.relpath(full, pkg))
PY
else
    echo "Error: need either 'zip' or 'python3' to build the .plasmoid" >&2
    exit 1
fi

echo "Built $OUT"
