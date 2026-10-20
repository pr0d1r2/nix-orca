#!/usr/bin/env bash
# Update the agent inputs (scripts T5, nix/agents T4): every root flake
# input except nixpkgs and nixpkgs-lock, in one `nix flake update`, read
# from the lock so a new agent input needs no edit here. The pin moves in
# its own PR (D19).
# Usage: agents-update.sh
# Env: NIX names nix (default nix).
set -euo pipefail

nix=${NIX:-nix}

mapfile -t inputs < <("$nix" flake metadata --json |
  jq -r '.locks.nodes.root.inputs | keys[] | select(. != "nixpkgs" and . != "nixpkgs-lock")')
"$nix" flake update "${inputs[@]}"
