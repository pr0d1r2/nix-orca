#!/usr/bin/env bash
# Build one system's packages and checks (`release` T1): every
# packages.<system>.* and checks.<system>.*, named, in one nix build, so a
# runner can build a system that is not its own, as the x86_64-darwin job
# does under Rosetta (D39).
# Usage: build-system.sh SYSTEM
# Env: NIX names nix (default nix).
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "usage: build-system.sh SYSTEM" >&2
  exit 2
fi
system=$1
nix=${NIX:-nix}

targets=()
for set in packages checks; do
  mapfile -t names < <("$nix" eval --json ".#$set.$system" --apply builtins.attrNames | jq -r '.[]')
  for name in "${names[@]}"; do
    targets+=(".#$set.$system.$name")
  done
done
"$nix" build --no-link --print-build-logs "${targets[@]}"
