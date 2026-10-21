#!/usr/bin/env bash
# Checks on the Linux orca-ide (nix/linux T2). Each mode compares one fact
# with its pinned value; a pass writes $out when it is set, so a check
# derivation is a single call. A failure names the invariant.
# Usage: linux-app.sh version|electron-major PATH EXPECTED
#   version:        PATH is the package; EXPECTED the upstream version (V4)
#   electron-major: PATH is upstream's source; EXPECTED the pin's Electron
#                   version (D21, scripts/check/electron-major.sh)
# Env: ELECTRON_MAJOR_CHECK names the guard (default electron-major.sh
# beside this script; a store copy of this script stands alone); out is
# written on a pass.
set -euo pipefail

usage() {
  echo "usage: linux-app.sh version|electron-major PATH EXPECTED" >&2
  exit 2
}
if [ "$#" -ne 3 ]; then
  usage
fi
mode=$1 path=$2 want=$3
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
guard=${ELECTRON_MAJOR_CHECK:-$here/electron-major.sh}

case "$mode" in
version)
  got=$("$path/bin/orca-ide" --version)
  if [ "$got" != "$want" ]; then
    echo "linux-app: bin/orca-ide --version printed $got, want $want (nix/linux V4)" >&2
    exit 1
  fi
  ;;
electron-major)
  bash "$guard" "$path/package.json" "$want"
  ;;
*)
  usage
  ;;
esac

if [ -n "${out:-}" ]; then
  : >"$out"
fi
