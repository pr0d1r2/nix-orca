#!/usr/bin/env bash
# The new-agent watch (nix/agents V5, round 11): an Orca agent id that is
# neither packaged nor on nix/agents/no-package.txt gets one issue, titled
# "new Orca agent: <id>", never reopened while open. Report-only: it never
# fails the build.
# Usage: agents-watch.sh SYSTEM
# Env: NIX, UNKNOWN, GH name the tools (defaults: nix,
# scripts/agents/unknown.sh, gh); GH_TOKEN needs `issues: write`.
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "usage: agents-watch.sh SYSTEM" >&2
  exit 2
fi
system=$1
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
nix=${NIX:-nix}
unknown=${UNKNOWN:-$here/../agents/unknown.sh}
gh=${GH:-gh}

ids=$("$nix" build --no-link --print-out-paths ".#legacyPackages.$system.agent-ids")
mapfile -t packaged < <("$nix" eval --json ".#legacyPackages.$system.agents" --apply builtins.attrNames | jq -r '.[]')
mapfile -t new < <(bash "$unknown" "$ids" "$here/../../nix/agents/no-package.txt" "${packaged[@]}")

for id in "${new[@]}"; do
  [ -n "$id" ] || continue
  title="new Orca agent: $id"
  if [ "$("$gh" issue list --state open --search "\"$title\" in:title" --json number --jq length)" = 0 ]; then
    "$gh" issue create --title "$title" --body "Orca's agent table now has \`$id\`. Package it, or add it to nix/agents/no-package.txt with the reason (nix/agents V5)."
  fi
done
