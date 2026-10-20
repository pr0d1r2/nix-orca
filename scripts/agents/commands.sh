#!/usr/bin/env bash
# Each packaged agent ships the command Orca looks for (nix/agents V1):
# for every ID=STORE-PATH, STORE-PATH/bin holds the id's detectCmd or one
# of its aliases, as listed in IDS-FILE (scripts/agents/tui-ids.sh output
# for the pinned tag). Every problem is a line on stderr, then exit 1; a
# pass writes $out when it is set.
# Usage: commands.sh IDS-FILE ID=STORE-PATH...
set -euo pipefail

if [ "$#" -lt 2 ]; then
  echo "usage: commands.sh IDS-FILE ID=STORE-PATH..." >&2
  exit 2
fi
table=$1
shift

status=0
for pair in "$@"; do
  id=${pair%%=*}
  path=${pair#*=}
  wanted=$(awk -v id="$id" '$1 == id { $1 = ""; print substr($0, 2) }' "$table")
  if [ -z "$wanted" ]; then
    echo "commands: $id: not an agent id in Orca's table (nix/agents V1)" >&2
    status=1
    continue
  fi
  found=no
  for cmd in $wanted; do
    if [ -e "$path/bin/$cmd" ]; then
      found=yes
    fi
  done
  if [ "$found" = no ]; then
    echo "commands: $id: $path/bin has none of: $wanted (nix/agents V1)" >&2
    status=1
  fi
done

if [ "$status" -eq 0 ] && [ -n "${out:-}" ]; then
  : >"$out"
fi
exit "$status"
