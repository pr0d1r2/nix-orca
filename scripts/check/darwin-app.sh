#!/usr/bin/env bash
# Checks on the darwin store Orca.app (nix/darwin T1). Each mode compares
# one fact with its pinned value; a pass writes $out when it is set, so a
# check derivation is a single call. A failure names the invariant.
# Usage: darwin-app.sh codesign|arch|version|tree APP EXPECTED
#   codesign: EXPECTED is the pinned TeamIdentifier (V1, V5)
#   arch:     EXPECTED is the lipo arch (V2)
#   version:  EXPECTED is the upstream version
#   tree:     EXPECTED is upstream's zip; APP must equal it unpacked (V3)
# Env: CODESIGN, LIPO, PLISTBUDDY, UNZIP name the tools (macOS defaults);
# out is written on a pass.
set -euo pipefail

codesign=${CODESIGN:-/usr/bin/codesign}
lipo=${LIPO:-/usr/bin/lipo}
plistbuddy=${PLISTBUDDY:-/usr/libexec/PlistBuddy}
unzip=${UNZIP:-unzip}

if [ "$#" -ne 3 ]; then
  echo "usage: darwin-app.sh codesign|arch|version|tree APP EXPECTED" >&2
  exit 2
fi
mode=$1 app=$2 want=$3

case "$mode" in
codesign)
  if ! "$codesign" --verify --deep --strict "$app"; then
    echo "darwin-app: codesign --verify --deep --strict failed (nix/darwin V1)" >&2
    exit 1
  fi
  team=$("$codesign" -dv "$app" 2>&1 | sed -n 's/^TeamIdentifier=//p')
  if [ "$team" != "$want" ]; then
    echo "darwin-app: TeamIdentifier $team, pinned $want; review before re-pinning (nix/darwin V5)" >&2
    exit 1
  fi
  ;;
arch)
  got=$("$lipo" -archs "$app/Contents/MacOS/Orca")
  if [ "$got" != "$want" ]; then
    echo "darwin-app: Contents/MacOS/Orca is $got, want $want (nix/darwin V2)" >&2
    exit 1
  fi
  ;;
version)
  got=$("$plistbuddy" -c 'Print CFBundleShortVersionString' "$app/Contents/Info.plist")
  if [ "$got" != "$want" ]; then
    echo "darwin-app: Info.plist says $got, want $want" >&2
    exit 1
  fi
  ;;
tree)
  unpacked=$(mktemp -d)
  trap 'rm -rf "$unpacked"' EXIT
  "$unzip" -q "$want" -d "$unpacked"
  if ! diff -r --no-dereference "$unpacked/Orca.app" "$app" >&2; then
    echo "darwin-app: Orca.app differs from upstream's zip (nix/darwin V3)" >&2
    exit 1
  fi
  ;;
*)
  echo "usage: darwin-app.sh codesign|arch|version|tree APP EXPECTED" >&2
  exit 2
  ;;
esac

if [ -n "${out:-}" ]; then
  : >"$out"
fi
