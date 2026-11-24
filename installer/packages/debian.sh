#!/bin/sh
set -eu
exec sudo apt install git stow "$@"
