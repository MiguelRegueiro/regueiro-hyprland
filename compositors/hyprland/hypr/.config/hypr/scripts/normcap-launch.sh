#!/usr/bin/env bash
set -euo pipefail
if command -v normcap >/dev/null 2>&1; then
    exec normcap "$@"
elif command -v flatpak >/dev/null 2>&1 && flatpak info com.github.dynobo.normcap >/dev/null 2>&1; then
    exec flatpak run com.github.dynobo.normcap "$@"
fi
echo "NormCap is not installed (native or com.github.dynobo.normcap)." >&2
exit 127
