#!/usr/bin/env bash
# Pin a Linux orca-ide store path in the fleet cache (scripts T2, D40):
# pin `orca-ide-<system>`, keeping its 2 newest revisions, so older ones
# age out under the cache's own retention. Never pins the path the newest
# revision already holds (V3), never darwin (root V5, D41), and never
# deletes from the cache or changes its retention (root V6).
# Usage: cachix-pin.sh SYSTEM STORE-PATH
# Env: CACHIX, CURL name the tools (default cachix, curl); CACHIX_CACHE
# the cache (default pr0d1r2); CACHIX_AUTH_TOKEN authenticates cachix.
set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "usage: cachix-pin.sh SYSTEM STORE-PATH" >&2
  exit 2
fi
system=$1 path=$2
cachix=${CACHIX:-cachix}
curl=${CURL:-curl}
cache=${CACHIX_CACHE:-pr0d1r2}
name=orca-ide-$system

case "$system" in
*-linux) ;;
*)
  echo "cachix-pin: $system is not cached (root V5, D41)" >&2
  exit 1
  ;;
esac

# The newest revision of this pin, from the cache's pin API; its JSON shape
# is unverified until the first pin exists.
newest=$("$curl" -fsSL "https://app.cachix.org/api/v1/cache/$cache/pin" |
  jq -r --arg n "$name" '.[] | select(.name == $n) | .lastRevision.storePath')
if [ "$newest" = "$path" ]; then
  echo "cachix-pin: $name already pins $path (scripts V3)" >&2
  exit 0
fi

"$cachix" pin "$cache" "$name" "$path" --keep-revisions 2
