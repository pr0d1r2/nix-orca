#!/usr/bin/env bash
# Critical CVEs in owned paths (scripts §C, round 9; D15): each vulnix
# finding with CVSS >= 9.0 in a derivation this package owns (pname
# orca-ide or orcad-*) opens one issue, never reopened while open. Pin
# paths are nixpkgs' to track. Report-only: it never fails the build.
# Usage: vulnix-watch.sh STORE-PATH...
# Env: VULNIX, GH name the tools (default vulnix, gh); GH_TOKEN needs
# `issues: write`.
set -euo pipefail

if [ "$#" -lt 1 ]; then
  echo "usage: vulnix-watch.sh STORE-PATH..." >&2
  exit 2
fi
vulnix=${VULNIX:-vulnix}
gh=${GH:-gh}

# vulnix exits non-zero when it finds anything; the findings are the point.
findings=$(for path in "$@"; do "$vulnix" --json "$path" || true; done | jq -s 'add // []')
mapfile -t critical < <(jq -r 'unique_by(.name) | .[]
  | select(.pname | test("^(orca-ide|orcad-)"))
  | . as $f | .affected_by[]
  | select(($f.cvssv3_basescore[.] // 0) >= 9.0)
  | "\(.)\t\($f.name)\t\($f.cvssv3_basescore[.])"' <<<"$findings" | sort -u -t$'\t' -k1,1)

for line in "${critical[@]}"; do
  IFS=$'\t' read -r cve name score <<<"$line"
  title="$cve in $name (CVSS $score)"
  if [ "$("$gh" issue list --state open --search "\"$cve\" in:title" --json number --jq length)" = 0 ]; then
    "$gh" issue create --title "$title" --body "vulnix found $cve (CVSS $score) in $name, a path this package owns. Report-only: the build on main pushed it to the cache (scripts §C)."
  fi
done
