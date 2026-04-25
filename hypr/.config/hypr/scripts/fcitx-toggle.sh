#!/bin/bash

if ! fcitx5-remote --check >/dev/null 2>&1; then
    exit 1
fi

current=$(fcitx5-remote -n 2>/dev/null || true)

if [ "$current" = "mozc" ]; then
    fcitx5-remote -s keyboard-es >/dev/null 2>&1
    fcitx5-remote -c >/dev/null 2>&1
else
    fcitx5-remote -s mozc >/dev/null 2>&1
    fcitx5-remote -o >/dev/null 2>&1
fi
