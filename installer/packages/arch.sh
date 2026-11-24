#!/bin/sh
set -eu
exec sudo pacman -S --needed git stow "$@"
