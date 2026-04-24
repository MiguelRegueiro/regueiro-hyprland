#!/bin/bash
sleep 2
gsettings set org.freedesktop.ibus.general preload-engines "['xkb:es::spa', 'anthy']"
gsettings set org.freedesktop.ibus.general engines-order "['xkb:es::spa', 'anthy']"
ibus engine xkb:es::spa 2>/dev/null || true
