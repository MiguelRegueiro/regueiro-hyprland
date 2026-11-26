#!/bin/sh
set -eu

# MimeClip does not publish a release package yet. Build both binaries from a
# reviewed, immutable upstream commit; cargo installs into the user's own bin.
repo=https://github.com/MiguelRegueiro/mimeclip
revision=7f64fc05332abfc52ffee0b2dca79e27da5711c2

if command -v mimeclip >/dev/null 2>&1 && command -v mimeclipd >/dev/null 2>&1; then
    echo "MimeClip client and daemon are already installed."
    exit 0
fi
if ! command -v cargo >/dev/null 2>&1; then
    echo "Cargo is required to install MimeClip. Select the core package profile first." >&2
    exit 1
fi

cargo install --git "$repo" --rev "$revision" --locked --bins

if [ ! -x "${CARGO_HOME:-$HOME/.cargo}/bin/mimeclip" ] || \
    [ ! -x "${CARGO_HOME:-$HOME/.cargo}/bin/mimeclipd" ]; then
    echo "Cargo completed without installing both MimeClip binaries." >&2
    exit 1
fi
echo "Installed MimeClip from $revision."
