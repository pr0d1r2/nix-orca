#!/usr/bin/env bash
# Re-record the demos into docs/demo/ (scripts T6, tests T4): build the dev
# flake's checks.x86_64-linux.agents-gate and .onboarding, replace
# docs/demo/{demo.mp4,preview.webp,shot.png} and
# docs/demo/onboarding.{mp4,webp,png} with their files and commit them
# alone. The check
# needs an x86_64-linux host with KVM: STORE (such as
# ssh-ng://root@nix-builder.local) builds it there and the files are read
# from it. A check already built is not run again, so the files
# change only when its inputs do.
# Usage: demo-assets.sh [STORE]
# Exit: 0 committed, 3 docs/demo/ unchanged, 1 refused, 2 usage.
# Env: NIX names the tool (default nix).
set -euo pipefail

if [ "$#" -gt 1 ]; then
  echo "usage: demo-assets.sh [STORE]" >&2
  exit 2
fi
fail() {
  echo "demo-assets: $*" >&2
  exit 1
}
nix=${NIX:-nix}
dir=docs/demo
# check, then each output file and the name it gets in docs/demo/.
demos=(
  "agents-gate demo.mp4:demo.mp4 preview.webp:preview.webp shot.png:shot.png"
  "onboarding demo.mp4:onboarding.mp4 preview.webp:onboarding.webp shot.png:onboarding.png"
)

cd "$(git rev-parse --show-toplevel)"
git diff --cached --quiet || fail "changes are staged; the commit holds the demo files alone"

store=() eval_store=()
if [ "$#" -eq 1 ]; then
  store=(--store "$1") eval_store=(--eval-store auto)
fi

# Read from the store that built each: importing a remote output needs its
# signature trusted, which an untrusted user cannot waive. Every file is
# read before any is replaced.
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
names=() outs=()
for demo in "${demos[@]}"; do
  read -r check pairs <<<"$demo"
  out=$("$nix" build --no-link --print-out-paths "${store[@]}" "${eval_store[@]}" "./dev#checks.x86_64-linux.$check")
  outs+=("$(basename "$out")")
  for pair in $pairs; do
    from=${pair%%:*} to=${pair#*:}
    "$nix" store cat "${store[@]}" "$out/$from" >"$tmp/$to" 2>/dev/null || fail "$out has no $from"
    names+=("$to")
  done
done
mkdir -p "$dir"
for f in "${names[@]}"; do
  cp "$tmp/$f" "$dir/$f"
done

git add "${names[@]/#/$dir/}"
if git diff --cached --quiet; then
  echo "demo-assets: $dir/ unchanged" >&2
  exit 3
fi
version=$(jq -r .version nix/sources.json)
# The trailer every commit here carries (docs/LLM-DISCLAIMER.md).
git commit -q -m "docs(demo): re-record orca-ide $version" \
  -m "scripts/demo-assets.sh from ${outs[*]}." \
  -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
