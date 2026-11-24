#!/bin/sh
set -eu
exec sudo xbps-install -S git stow "$@"
