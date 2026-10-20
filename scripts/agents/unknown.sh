#!/usr/bin/env bash
# Orca agent ids nobody has decided on (nix/agents V5, round 11): each id
# in the tui-ids table that is neither packaged nor on the no-package list,
# one per line. claude-agent-teams is Orca itself and never reported. An
# empty output means every agent is accounted for.
# Usage: unknown.sh IDS-FILE NO-PACKAGE-FILE PACKAGED-ID...
set -euo pipefail

if [ "$#" -lt 3 ]; then
  echo "usage: unknown.sh IDS-FILE NO-PACKAGE-FILE PACKAGED-ID..." >&2
  exit 2
fi
ids=$1 none=$2
shift 2

known=$(
  printf '%s\n' claude-agent-teams "$@"
  grep -v '^ *#' "$none" | grep -v '^ *$' || true
)
awk '{ print $1 }' "$ids" | grep -vxF -f <(printf '%s\n' "$known") || true
