#!/usr/bin/env bash
# Electron major guard (nix/linux T2, D21): the Linux source build runs
# upstream's app.asar on the pin's Electron, which holds only while both
# share a major. A mismatch stops the build and names the fallback.
# Usage: electron-major.sh PACKAGE-JSON PIN-ELECTRON-VERSION
set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "usage: electron-major.sh PACKAGE-JSON PIN-ELECTRON-VERSION" >&2
  exit 2
fi
want=$(jq -r '.devDependencies.electron // .dependencies.electron // empty' "$1")
if [ -z "$want" ]; then
  echo "electron-major: $1 names no electron dependency" >&2
  exit 1
fi
want_major=$(sed 's/^[^0-9]*//; s/\..*//' <<<"$want")
pin_major=${2%%.*}
if [ "$want_major" != "$pin_major" ]; then
  echo "electron-major: upstream wants Electron $want, the pin has $2;" \
    "build orca-ide-bin (upstream's .deb with its own Electron) until the pin catches up" >&2
  exit 1
fi
