#!/bin/sh

qs_bin="${QS_BIN:-$(command -v qs 2>/dev/null || true)}"

pkill -x rofi >/dev/null 2>&1 || true

if [ -z "$qs_bin" ]; then
    echo "qs not found" >&2
    exit 1
fi

exec "$qs_bin" ipc call launcher toggle
