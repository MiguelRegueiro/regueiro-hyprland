#!/bin/sh

/usr/local/bin/qs ipc --newest call brightness decrease
sleep 0.2
"$HOME/.config/hypr/scripts/brightness-store.sh" current
