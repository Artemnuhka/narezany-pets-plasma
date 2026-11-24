#!/bin/sh
set -eu
cd -- "$(dirname -- "$0")"

for dependency in qs python3; do
    if ! command -v "$dependency" >/dev/null 2>&1; then
        printf 'Установи зависимость: %s\n' "$dependency" >&2
        exit 1
    fi
done
if ! python3 -c 'from gi.repository import Gio, GLib' 2>/dev/null; then
    printf 'Установи PyGObject для Python 3.\n' >&2
    exit 1
fi

data_dir="${XDG_DATA_HOME:-$HOME/.local/share}"
app_dir="$data_dir/plasma-pets"
install -d "$app_dir/assets" "$data_dir/applications"
install -m 644 plasma-pets/*.qml plasma-pets/*.js plasma-pets/tray.py "$app_dir/"
install -m 644 plasma-pets/assets/* "$app_dir/assets/"
install -m 755 plasma-pets/start.sh "$app_dir/start.sh"

python3 - "$app_dir/start.sh" "$data_dir/applications/plasma-pets.desktop" <<'PY'
import sys
from pathlib import Path

launcher, destination = sys.argv[1:]
exec_arg = "".join("\\" + c if c in '\\"$`' else c for c in launcher)
exec_arg = exec_arg.replace("\\", "\\\\").replace("%", "%%")
Path(destination).write_text(f"""[Desktop Entry]
Type=Application
Name=plasma-pets
Comment=Питомцы для KDE Plasma
Exec="{exec_arg}"
Icon=face-smile
Terminal=false
Categories=Game;
""", encoding="utf-8")
PY

if command -v kbuildsycoca6 >/dev/null 2>&1; then
    kbuildsycoca6 >/dev/null 2>&1 || true
fi
printf 'plasma-pets установлен. Открой его из меню приложений KDE.\n'
