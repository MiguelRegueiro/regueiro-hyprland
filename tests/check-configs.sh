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
done < <(find desktop/quickshell/.config/quickshell -type f -name '*.qml' ! -name 'NotificationStore.qml' -print0 | sort -z)

while IFS= read -r -d '' file; do
    qmllint "$file" >/dev/null
done < <(find desktop/quickshell/.config/quickshell -type f -name '*.qml' -print0 | sort -z)

bash -n compositors/hyprland/hypr/.config/hypr/scripts/*.sh
sh -n desktop/platforms/linux/.local/bin/triton-linux-power
sh -n desktop/platforms/linux/.local/bin/triton-linux-service
sh -n desktop/platforms/linux/.local/bin/triton-linux-session-cleanup
sh -n tests/test-session-cleanup.sh
bash -n desktop/platforms/linux/.local/bin/triton-fcitx-toggle
sh -n desktop/platforms/linux/.local/bin/triton-linux-bluetooth
bash -n desktop/platforms/linux/.local/bin/triton-linux-system-details
sh -n desktop/platforms/linux/.local/bin/triton-linux-drives
sh -n desktop/platforms/freebsd/.local/bin/triton-freebsd-battery
sh -n desktop/platforms/freebsd/.local/bin/triton-freebsd-build-hardware
sh -n desktop/platforms/freebsd/.local/bin/triton-freebsd-power
sh -n desktop/platforms/freebsd/.local/bin/triton-freebsd-network
sh -n desktop/platforms/freebsd/.local/bin/triton-freebsd-bluetooth
sh -n desktop/platforms/freebsd/.local/bin/triton-freebsd-system-details
sh -n desktop/platforms/freebsd/.local/bin/triton-freebsd-drives
sh -n desktop/platforms/freebsd/.local/bin/triton-freebsd-drive-eject
sh -n desktop/platforms/freebsd/.local/bin/triton-freebsd-power-profile
sh -n desktop/scripts/.local/bin/triton-connect-session
sh -n installer/install.sh
python -m py_compile compositors/hyprland/hypr/.config/hypr/scripts/powerctl
PYTHONPYCACHEPREFIX="${TMPDIR:-/tmp}/triton-pycache" \
    python -m py_compile compositors/hyprland/hypr/.local/bin/elio-filemanager1
git diff --check

echo "Formatting and syntax checks passed."
