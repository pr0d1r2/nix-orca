#!/usr/bin/env bash
# After the push on main, every Linux orca-ide store path answers from the
# cache (`release` §C round 8, D20, root T19): a cachix push failure does
# not fail its job, so this check does. Darwin is never cached (root V5).
# Usage: verify-cache.sh LINUX-SYSTEM...
# Env: NIX, CURL name the tools (default nix, curl); CACHIX_CACHE the cache
# (default pr0d1r2).
set -euo pipefail

nix=${NIX:-nix}
curl=${CURL:-curl}
cache=${CACHIX_CACHE:-pr0d1r2}

if [ "$#" -lt 1 ]; then
  echo "usage: verify-cache.sh LINUX-SYSTEM..." >&2
  exit 2
fi
for system in "$@"; do
  case "$system" in
  *-linux) ;;
  *)
    echo "usage: verify-cache.sh LINUX-SYSTEM..." >&2
    exit 2
    ;;
  esac
done

for system in "$@"; do
  path=$("$nix" eval --raw ".#packages.$system.orca-ide.outPath" 2>/dev/null || true)
  if [ -z "$path" ]; then
    echo "verify-cache: $system has no orca-ide package" >&2
    exit 1
  fi
  hash=$(basename "$path" | cut -c1-32)
  if ! "$curl" -fsS -o /dev/null "https://$cache.cachix.org/$hash.narinfo"; then
    echo "verify-cache: $system $path is not in $cache.cachix.org" >&2
    exit 1
  fi
done
