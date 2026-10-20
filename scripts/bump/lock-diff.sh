#!/usr/bin/env bash
# The bump PR body's dependency report (scripts §C, round 9), markdown on
# stdout: npm packages added, removed and version-changed between two
# pnpm-lock.yaml files, and the packages whose install scripts the new
# pnpm-workspace.yaml newly allows. Report-only: it never blocks the merge.
# The parsers are awk, beside this script.
# Usage: lock-diff.sh OLD-LOCK NEW-LOCK OLD-WORKSPACE NEW-WORKSPACE
set -euo pipefail

if [ "$#" -ne 4 ]; then
  echo "usage: lock-diff.sh OLD-LOCK NEW-LOCK OLD-WORKSPACE NEW-WORKSPACE" >&2
  exit 2
fi
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

awk -f "$here/lock-packages.awk" "$1" | sort -u >"$work/old"
awk -f "$here/lock-packages.awk" "$2" | sort -u >"$work/new"
awk -f "$here/allow-builds.awk" "$3" | sort -u >"$work/old-builds"
awk -f "$here/allow-builds.awk" "$4" | sort -u >"$work/new-builds"

echo "### npm packages"
echo
cut -d' ' -f1 "$work/old" | sort -u >"$work/old-names"
cut -d' ' -f1 "$work/new" | sort -u >"$work/new-names"
report=$(
  comm -13 "$work/old" "$work/new" | while read -r name version; do
    if grep -qxF "$name" "$work/old-names"; then
      echo "- changed: \`$name\` $(awk -v n="$name" '$1 == n { print $2 }' "$work/old" | paste -sd, -) -> $version"
    else
      echo "- added: \`$name@$version\`"
    fi
  done
  comm -23 "$work/old" "$work/new" | while read -r name version; do
    if ! grep -qxF "$name" "$work/new-names"; then
      echo "- removed: \`$name@$version\`"
    fi
  done
)
if [ -n "$report" ]; then
  printf '%s\n' "$report"
else
  echo "No npm package changed."
fi

echo
echo "### Install scripts"
echo
tick='`'
allowed=$(comm -13 "$work/old-builds" "$work/new-builds" | sed "s/.*/$tick&$tick/" | paste -sd, - | sed 's/,/, /g')
if [ -n "$allowed" ]; then
  echo "- install scripts newly allowed: $allowed"
else
  echo "No install script newly allowed."
fi
