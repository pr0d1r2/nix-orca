#!/usr/bin/env bash
# A package closure stays within its system's budget (scripts T4, D14,
# nix/linux V6): the closure size from `nix path-info -S` against the
# system's line in .closure-budget (`system bytes`, `#` comments). Over
# budget fails; raising a budget is its own reviewed commit.
# Usage: closure-budget.sh SYSTEM STORE-PATH
# Env: NIX names nix (default nix); CLOSURE_BUDGET the budget file
# (default .closure-budget at the repository root).
set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "usage: closure-budget.sh SYSTEM STORE-PATH" >&2
  exit 2
fi
system=$1 path=$2
nix=${NIX:-nix}
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
file=${CLOSURE_BUDGET:-$here/../.closure-budget}

limit=$(awk -v s="$system" '$1 == s { print $2 }' "$file")
if [ -z "$limit" ]; then
  echo "closure-budget: no budget for $system in $file" >&2
  exit 1
fi
size=$("$nix" path-info -S "$path" | awk '{ print $2 }')
if [ "$size" -gt "$limit" ]; then
  echo "closure-budget: $system $size bytes, budget $limit; raise it in its own reviewed commit (D14)" >&2
  exit 1
fi
echo "closure-budget: $system $size of $limit bytes ($((size * 100 / limit))%)"
