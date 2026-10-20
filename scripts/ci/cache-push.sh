#!/usr/bin/env bash
# Push one Linux system's orca-ide closure to the fleet cache and pin it
# (root V5, D40, D41). Only packages.<system>.orca-ide: never darwin, the
# agents, anything unfree, or orca-ide-bin. A system that has no orca-ide
# package yet pushes nothing.
# Usage: cache-push.sh SYSTEM
# Env: NIX, CACHIX name the tools (default nix, cachix); CACHIX_PIN the pin
# script (default scripts/cachix-pin.sh); CACHIX_CACHE the cache (default
# pr0d1r2); CACHIX_AUTH_TOKEN authenticates cachix.
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "usage: cache-push.sh SYSTEM" >&2
  exit 2
fi
system=$1
case "$system" in
*-linux) ;;
*)
  echo "cache-push: $system is never pushed (root V5, D41)" >&2
  exit 1
  ;;
esac
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
nix=${NIX:-nix}
cachix=${CACHIX:-cachix}
pin=${CACHIX_PIN:-$here/../cachix-pin.sh}
cache=${CACHIX_CACHE:-pr0d1r2}

if [ "$("$nix" eval --json ".#packages.$system" --apply 'p: p ? orca-ide')" != true ]; then
  exit 0
fi
path=$("$nix" build --no-link --print-out-paths ".#packages.$system.orca-ide")
"$cachix" push "$cache" "$path"
bash "$pin" "$system" "$path"
