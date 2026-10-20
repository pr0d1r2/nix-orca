#!/usr/bin/env bash
# The flake.lock graph guard (gate:V1, root V1): exactly one nixpkgs node,
# and every input with a nixpkgs input follows it. Each problem is a line
# on stderr, then exit 1. The rules are jq, in lock-graph.jq beside this
# script.
# Usage: lock-graph.sh FLAKE-LOCK
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "usage: lock-graph.sh FLAKE-LOCK" >&2
  exit 2
fi
lock=$1
here=$(dirname "${BASH_SOURCE[0]}")

if ! problems=$(jq -r -f "$here/lock-graph.jq" "$lock" 2>/dev/null) ||
  ! jq -e '.nodes | type == "object"' "$lock" >/dev/null 2>&1; then
  echo "lock-graph: $lock: not a flake lock (root V1)" >&2
  exit 1
fi
[ -z "$problems" ] && exit 0
while IFS= read -r problem; do
  echo "lock-graph: $lock: $problem (root V1)" >&2
done <<<"$problems"
exit 1
