#!/bin/sh
set -eu
. "$(dirname "$0")/root.sh"
run_as_root xbps-install -S git stow "$@"
