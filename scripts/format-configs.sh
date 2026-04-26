#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

if ! command -v qmlformat >/dev/null 2>&1; then
    echo "qmlformat is required but not installed" >&2
    exit 1
fi

mapfile -d '' qml_files < <(
    find quickshell/.config/quickshell -type f -name '*.qml' \
        ! -name 'NotificationStore.qml' \
        -print0 | sort -z
)

if [ "${#qml_files[@]}" -gt 0 ]; then
    qmlformat -n -i "${qml_files[@]}"
fi

echo "Skipped quickshell/.config/quickshell/services/NotificationStore.qml on purpose."
echo "That file stays manually formatted because forcing qmlformat on it caused runtime regressions."

if command -v shfmt >/dev/null 2>&1; then
    shfmt -w hypr/.config/hypr/scripts/*.sh
else
    echo "shfmt not installed; shell scripts left unchanged." >&2
fi
