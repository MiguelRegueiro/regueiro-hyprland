#!/bin/sh

qs_bin="${QS_BIN:-$(command -v qs 2>/dev/null || true)}"

pkill -x rofi >/dev/null 2>&1 || true

if [ -n "$qs_bin" ] && "$qs_bin" ipc call launcher toggle >/dev/null 2>&1; then
    exit 0
fi

exec rofi -show drun
