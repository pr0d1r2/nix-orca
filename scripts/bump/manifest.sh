#!/usr/bin/env bash
# One release asset as nix/sources.json holds it (scripts T1, D12): its
# name, size and SRI sha512, read from upstream's electron-builder
# manifest (latest-mac.yml, latest-linux.yml, ...) at TAG. Refuses an asset
# the manifest does not list, and a manifest size that differs from the
# size GitHub reports for the asset. The parser is awk, in manifest.awk.
# Usage: manifest.sh TAG MANIFEST ASSET
# Env: CURL, GH name the tools (default curl, gh); ORCA_REPO the
# repository (default stablyai/orca).
set -euo pipefail

if [ "$#" -ne 3 ]; then
  echo "usage: manifest.sh TAG MANIFEST ASSET" >&2
  exit 2
fi
tag=$1 manifest=$2 asset=$3
curl=${CURL:-curl}
gh=${GH:-gh}
repo=${ORCA_REPO:-stablyai/orca}
here=$(dirname "${BASH_SOURCE[0]}")

entry=$("$curl" -fsSL "https://github.com/$repo/releases/download/$tag/$manifest" |
  awk -v asset="$asset" -f "$here/manifest.awk")
if [ -z "$entry" ]; then
  echo "manifest: $manifest at $tag lists no $asset (D12)" >&2
  exit 1
fi
size=${entry%% *}
sha=${entry#* }

github=$("$gh" api "repos/$repo/releases/tags/$tag" |
  jq -r --arg a "$asset" '.assets[] | select(.name == $a) | .size')
if [ "$github" != "$size" ]; then
  echo "manifest: $asset: $manifest says $size bytes, GitHub says ${github:-nothing} (D12)" >&2
  exit 1
fi

jq -n --arg name "$asset" --argjson size "$size" --arg hash "sha512-$sha" \
  '{name: $name, size: $size, hash: $hash}'
