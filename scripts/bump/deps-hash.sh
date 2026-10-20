#!/usr/bin/env bash
# The JS deps hash for an upstream tag (scripts T1): builds the deps fetch
# from deps-hash.nix with a fake hash and prints the hash nix reports as
# `got:`. Any other failure stops it with nix's output. The fetch is the
# full pnpm store (nix/linux R2), about a minute and 1.84 GB.
# Usage: deps-hash.sh TAG SRC-HASH
# Env: NIX names nix (default nix).
set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "usage: deps-hash.sh TAG SRC-HASH" >&2
  exit 2
fi
tag=$1 src=$2
nix=${NIX:-nix}
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

log=$("$nix" build --no-link --impure --file "$here/deps-hash.nix" \
  --argstr tag "$tag" --argstr srcHash "$src" 2>&1) || true
got=$(sed -n 's/^ *got: *\(sha256-[A-Za-z0-9+/=]*\).*/\1/p' <<<"$log")
if [ -z "$got" ]; then
  printf '%s\n' "$log" >&2
  echo "deps-hash: no hash mismatch from the fake-hash build of $tag" >&2
  exit 1
fi
echo "$got"
