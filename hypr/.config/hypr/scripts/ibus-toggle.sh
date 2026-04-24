#!/bin/bash
current=$(ibus engine 2>/dev/null)
if [ "$current" = "anthy" ]; then
    ibus engine xkb:es::spa
else
    ibus engine anthy
fi
