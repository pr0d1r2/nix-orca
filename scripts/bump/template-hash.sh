#!/usr/bin/env bash
# The hash of the orcad template piece for one Linux system (scripts T1,
# nix/bin T2): builds nix/bin/orcad-template.nix through template-hash.nix
# with a fake hash and prints the hash nix reports as `got:`. Any other
# failure stops it with nix's output. It fetches the system's .deb (about
# 175 MB) and cuts the piece on the host's own system.
# Usage: template-hash.sh TAG SYSTEM DEB-NAME DEB-HASH
# Env: NIX names nix (default nix).
set -euo pipefail

if [ "$#" -ne 4 ]; then
  echo "usage: template-hash.sh TAG SYSTEM DEB-NAME DEB-HASH" >&2
  exit 2
fi
tag=$1 system=$2 name=$3 hash=$4
nix=${NIX:-nix}
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

log=$("$nix" build --no-link --impure --file "$here/template-hash.nix" \
  --argstr tag "$tag" --argstr system "$system" \
  --argstr debName "$name" --argstr debHash "$hash" 2>&1) || true
got=$(sed -n 's/^ *got: *\(sha256-[A-Za-z0-9+/=]*\).*/\1/p' <<<"$log")
if [ -z "$got" ]; then
  printf '%s\n' "$log" >&2
  echo "template-hash: no hash mismatch from the fake-hash build of $tag $system" >&2
  exit 1
fi
echo "$got"
