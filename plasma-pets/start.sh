#!/bin/sh
set -eu
cd -- "$(dirname -- "$0")"
# KWin's primary output can differ from Qt's first (leftmost) screen.
if command -v kscreen-doctor >/dev/null && command -v python3 >/dev/null; then
    DESKTOP_PETS_OUTPUT=$(kscreen-doctor -j | python3 -c '
import json, sys
outputs = [o for o in json.load(sys.stdin)["outputs"] if o.get("enabled")]
if outputs:
    print(min(outputs, key=lambda o: o.get("priority") or 999)["name"])
') || DESKTOP_PETS_OUTPUT=
    export DESKTOP_PETS_OUTPUT
fi
exec qs --no-duplicate --daemonize --path "$PWD/shell.qml"
