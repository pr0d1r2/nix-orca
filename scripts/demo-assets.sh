#!/usr/bin/env bash
# Re-record the demo into docs/demo/ (scripts T6, tests T4): build
# checks.x86_64-linux.agents-stub, replace docs/demo/{demo.mp4,
# preview.webp,shot.png} with its files and commit them alone. The check
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
check=.#checks.x86_64-linux.agents-stub
dir=docs/demo
files=(demo.mp4 preview.webp shot.png)

cd "$(git rev-parse --show-toplevel)"
git diff --cached --quiet || fail "changes are staged; the commit holds the demo files alone"

store=() eval_store=()
if [ "$#" -eq 1 ]; then
  store=(--store "$1") eval_store=(--eval-store auto)
fi
out=$("$nix" build --no-link --print-out-paths "${store[@]}" "${eval_store[@]}" "$check")

# Read from the store that built it: importing a remote output needs its
# signature trusted, which an untrusted user cannot waive.
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
for f in "${files[@]}"; do
  "$nix" store cat "${store[@]}" "$out/$f" >"$tmp/$f" 2>/dev/null || fail "$out has no $f"
done
mkdir -p "$dir"
for f in "${files[@]}"; do
  cp "$tmp/$f" "$dir/$f"
done

git add "${files[@]/#/$dir/}"
if git diff --cached --quiet; then
  echo "demo-assets: $dir/ unchanged" >&2
  exit 3
fi
version=$(jq -r .version nix/sources.json)
git commit -q -m "docs(demo): re-record orca-ide $version" \
  -m "scripts/demo-assets.sh from $(basename "$out")."
