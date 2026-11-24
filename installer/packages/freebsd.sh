#!/bin/sh
set -eu
exec sudo pkg install git stow "$@"
