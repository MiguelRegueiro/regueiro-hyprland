#!/bin/bash

qs_bin="${QS_BIN:-$(command -v qs 2>/dev/null || true)}"
backend_script="${INPUT_BACKEND_SCRIPT:-$HOME/.config/hypr/scripts/fcitx-toggle.sh}"

if [ -n "$qs_bin" ]; then
    if "$qs_bin" ipc call input cycleNext >/dev/null 2>&1; then
        exit 0
    fi
fi

"$backend_script" cycle-next >/dev/null
status=$?

if [ $status -eq 0 ] && [ -n "$qs_bin" ]; then
    "$qs_bin" ipc call input refresh >/dev/null 2>&1 || true
fi

exit $status
