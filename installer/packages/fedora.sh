#!/bin/sh
set -eu
. "$(dirname "$0")/root.sh"
run_as_root dnf install git stow "$@"
