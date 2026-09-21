#!/usr/bin/env bash
set -euo pipefail

# Let UWSM stop clients and session services only when it owns a compositor.
# `uwsm check is-active` also succeeds for a plain graphical-session.target,
# including the target started by our portal helper in a non-UWSM login.
if command -v uwsm >/dev/null 2>&1; then
    uwsm_units=$(systemctl --user list-units --type=service \
        --state=active,activating --plain --no-legend --no-pager \
        'wayland-wm@*.service' 2>/dev/null) || uwsm_units=""
    if [[ -n "$uwsm_units" ]]; then
        exec uwsm stop
    fi
fi

# Lua-enabled hyprctl advertises eval. Keep compatibility with older installs.
help_text=$(hyprctl --help 2>&1 || true)
if grep -Eq '^[[:space:]]+eval[[:space:]]' <<< "$help_text"; then
    exec hyprctl dispatch 'hl.dsp.exit()'
else
    exec hyprctl dispatch exit
fi
