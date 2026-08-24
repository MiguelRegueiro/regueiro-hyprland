#!/bin/sh

set -eu

state="${CLIPBOARD_STATE:-data}"

if [ "$state" != "data" ]; then
    exit 0
fi

# Only record the selection. Re-copying it from inside a wl-paste watcher makes
# the watcher replace the source application's clipboard ownership while a
# paste may already be in progress, which intermittently produces an empty
# Ctrl-V. History entries are restored explicitly by the clipboard picker.
exec /usr/local/bin/cliphist store
