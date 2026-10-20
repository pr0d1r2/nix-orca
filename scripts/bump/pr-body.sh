#!/usr/bin/env bash
# The bump PR body (scripts §C, round 9): a heading, the dependency report
# (lock-diff.sh) between the two tags' pnpm-lock.yaml and
# pnpm-workspace.yaml, fetched through the GitHub API, and whether
# sherpa-onnx's C API header changed between the version the new tag
# bundles and the pin's (sherpa-diff.sh, D25).
# Usage: pr-body.sh FROM-TAG TO-TAG
# Env: GH, NIX name the tools (default gh, nix); LOCK_DIFF, SHERPA_DIFF the
# report scripts (default: beside this one); ORCA_REPO the repository
# (default stablyai/orca).
set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "usage: pr-body.sh FROM-TAG TO-TAG" >&2
  exit 2
fi
from=$1 to=$2
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
gh=${GH:-gh}
diff=${LOCK_DIFF:-$here/lock-diff.sh}
sherpa=${SHERPA_DIFF:-$here/sherpa-diff.sh}
nix=${NIX:-nix}
repo=${ORCA_REPO:-stablyai/orca}
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

for tag in "$from" "$to"; do
  for file in pnpm-lock.yaml pnpm-workspace.yaml; do
    "$gh" api "repos/$repo/contents/$file?ref=$tag" -H "Accept: application/vnd.github.raw" >"$work/$tag-$file"
  done
done

echo "Upstream $from -> $to, written by scripts/bump.sh. Report-only; it never blocks the merge."
echo
bash "$diff" "$work/$from-pnpm-lock.yaml" "$work/$to-pnpm-lock.yaml" \
  "$work/$from-pnpm-workspace.yaml" "$work/$to-pnpm-workspace.yaml"

echo
echo "### sherpa-onnx"
echo
bundled=$("$gh" api "repos/$repo/contents/package.json?ref=$to" -H "Accept: application/vnd.github.raw" |
  jq -r '[.. | objects | to_entries[] | select(.key | startswith("sherpa-onnx-linux")) | .value][0] // empty')
pin=$("$nix" eval --raw --inputs-from . nixpkgs#sherpa-onnx.version)
bash "$sherpa" "$bundled" "$pin" || true
