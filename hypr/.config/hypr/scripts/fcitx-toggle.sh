#!/bin/bash
if ! fcitx5-remote --check >/dev/null 2>&1; then
    exit 1
fi
fcitx5-remote -t
