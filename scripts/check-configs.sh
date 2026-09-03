#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

if [[ -d /usr/local/lib/qt6/bin ]]; then
    PATH="/usr/local/lib/qt6/bin:$PATH"
fi

if ! command -v qmlformat >/dev/null 2>&1; then
    echo "qmlformat is required but not installed" >&2
    exit 1
fi

if ! command -v qmllint >/dev/null 2>&1; then
    echo "qmllint is required but not installed" >&2
    exit 1
fi

if ! command -v Hyprland >/dev/null 2>&1; then
    echo "Hyprland is required but not installed" >&2
    exit 1
fi

Hyprland --verify-config --config "$repo_root/hypr/.config/hypr/hyprland.lua"

while IFS= read -r -d '' file; do
    qmlformat -n "$file" >/dev/null
done < <(find quickshell/.config/quickshell -type f -name '*.qml' ! -name 'NotificationStore.qml' -print0 | sort -z)

while IFS= read -r -d '' file; do
    qmllint "$file" >/dev/null
done < <(find quickshell/.config/quickshell -type f -name '*.qml' -print0 | sort -z)

bash -n hypr/.config/hypr/scripts/*.sh
sh -n scripts/setup-freebsd-realtime.sh
git diff --check

echo "Formatting and syntax checks passed."
