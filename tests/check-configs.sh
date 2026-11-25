#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

if ! command -v qmlformat >/dev/null 2>&1; then
    echo "qmlformat is required but not installed" >&2
    exit 1
fi

if ! command -v qmllint >/dev/null 2>&1; then
    echo "qmllint is required but not installed" >&2
    exit 1
fi

while IFS= read -r -d '' file; do
    qmlformat -n "$file" >/dev/null
done < <(find desktop/quickshell/.config/quickshell platforms/linux/.config/quickshell -type f -name '*.qml' ! -name 'NotificationStore.qml' -print0 | sort -z)

while IFS= read -r -d '' file; do
    qmllint "$file" >/dev/null
done < <(find desktop/quickshell/.config/quickshell platforms/linux/.config/quickshell -type f -name '*.qml' -print0 | sort -z)

bash -n compositors/hyprland/hypr/.config/hypr/scripts/*.sh
sh -n platforms/linux/.local/bin/triton-linux-power
sh -n platforms/linux/.local/bin/triton-linux-service
bash -n platforms/linux/.local/bin/triton-fcitx-toggle
sh -n platforms/linux/.local/bin/triton-linux-bluetooth
bash -n platforms/linux/.local/bin/triton-linux-system-details
python -m py_compile compositors/hyprland/hypr/.config/hypr/scripts/powerctl
git diff --check

echo "Formatting and syntax checks passed."
