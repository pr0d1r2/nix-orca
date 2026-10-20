#!/usr/bin/env bash
# Attestation subjects for a release (root §I release, D30): one line per
# system in sha256sum form, `<hex NAR sha256>  orca-ide-<system>.nar`, for
# attest-build-provenance's `subject-checksums`. The NAR hash is what a
# consumer reproduces with `nix build --rebuild` and `nix path-info`.
# Usage: release-subjects.sh SYSTEM=PATH...
# Env: NIX names nix (default nix).
set -euo pipefail

if [ "$#" -lt 1 ]; then
  echo "usage: release-subjects.sh SYSTEM=PATH..." >&2
  exit 2
fi
nix=${NIX:-nix}

for arg in "$@"; do
  system=${arg%%=*}
  path=${arg#*=}
  sri=$("$nix" path-info --json --json-format 1 "$path" | jq -er '.[].narHash')
  echo "$("$nix" hash convert --to base16 "$sri")  orca-ide-$system.nar"
done
