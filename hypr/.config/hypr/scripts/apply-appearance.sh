#!/bin/sh

set -eu

icon_theme=MacTahoe-dark
gtk_theme=adw-gtk3-dark

if command -v gsettings >/dev/null 2>&1; then
    gsettings set org.gnome.desktop.interface icon-theme "$icon_theme" || true
    gsettings set org.gnome.desktop.interface gtk-theme "$gtk_theme" || true
    gsettings set org.gnome.desktop.interface color-scheme prefer-dark || true
fi

if command -v xfconf-query >/dev/null 2>&1; then
    xfconf-query -c xsettings -p /Net/IconThemeName -s "$icon_theme" --create -t string || true
fi
