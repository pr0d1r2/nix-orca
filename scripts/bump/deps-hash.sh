#!/usr/bin/env bash
# The hash of a JS deps fetch for an upstream tag (scripts T1): builds the
# fetch from deps-hash.nix with a fake hash and prints the hash nix reports
# as `got:`. Any other failure stops it with nix's output. pnpmDeps is the
# root's full pnpm store (nix/linux R2), about a minute and 1.84 GB;
# mobilePnpmDeps is mobile/'s (R3), 25 s and 736 MiB.
# Usage: deps-hash.sh TAG SRC-HASH [pnpmDeps|mobilePnpmDeps]
# Env: NIX names nix (default nix).
set -euo pipefail

usage() {
  echo "usage: deps-hash.sh TAG SRC-HASH [pnpmDeps|mobilePnpmDeps]" >&2
  exit 2
}
if [ "$#" -lt 2 ] || [ "$#" -gt 3 ]; then
  usage
fi
tag=$1 src=$2 fetch=${3:-pnpmDeps}
case "$fetch" in
pnpmDeps | mobilePnpmDeps) ;;
*) usage ;;
esac
nix=${NIX:-nix}
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

log=$("$nix" build --no-link --impure --file "$here/deps-hash.nix" \
  --argstr tag "$tag" --argstr srcHash "$src" --argstr fetch "$fetch" 2>&1) || true
got=$(sed -n 's/^ *got: *\(sha256-[A-Za-z0-9+/=]*\).*/\1/p' <<<"$log")
if [ -z "$got" ]; then
  printf '%s\n' "$log" >&2
  echo "deps-hash: no hash mismatch from the fake-hash build of $tag" >&2
  exit 1
fi
echo "$got"
