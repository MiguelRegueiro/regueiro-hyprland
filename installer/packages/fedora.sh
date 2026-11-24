#!/bin/sh
set -eu
exec sudo dnf install git stow "$@"
