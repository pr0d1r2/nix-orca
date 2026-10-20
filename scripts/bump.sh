#!/usr/bin/env bash
# The upstream bump (scripts T1). Writes nix/sources.json and nothing else
# (V1, nix V3), and only for the newest stable tag (V2):
# - exit 3: the pinned version is still the latest
# - exit 4: upstream moved the pinned tag or replaced a pinned asset; the
#   workflow opens an issue, and nothing is rewritten (round 9)
# - exit 1: a tool refused, e.g. an asset missing from a manifest (D12)
# - exit 0: nix/sources.json now pins the new version
# The steps are the scripts in scripts/bump/.
# Usage: bump.sh
# Env: BUMP_TOOLS names the step scripts' directory (default
# scripts/bump); SOURCES the file (default nix/sources.json).
set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
tools=${BUMP_TOOLS:-$here/bump}
sources=${SOURCES:-$here/../nix/sources.json}

pinned_tag=$(jq -r .tag "$sources")
pinned_commit=$(jq -r .commit "$sources")

# Upstream immutability, checked on every run (round 9).
now=$(bash "$tools/source.sh" "$pinned_tag" | jq -r .commit)
if [ "$now" != "$pinned_commit" ]; then
  echo "bump: $pinned_tag now points at $now, pinned $pinned_commit; upstream moved a released tag (round 9)" >&2
  exit 4
fi
assets=$(jq -r '[.linux[], .darwin[] | objects | .[] | "\(.name) \(.hash)"] | .[]' "$sources")
while read -r name hash; do
  case "$name" in
  *_amd64.deb) manifest=latest-linux.yml ;;
  *_arm64.deb) manifest=latest-linux-arm64.yml ;;
  *) manifest=latest-mac.yml ;;
  esac
  if [ "$(bash "$tools/manifest.sh" "$pinned_tag" "$manifest" "$name" | jq -r .hash)" != "$hash" ]; then
    echo "bump: $name changed under $pinned_tag; upstream replaced a released asset (round 9)" >&2
    exit 4
  fi
done <<<"$assets"

tag=$(bash "$tools/latest-tag.sh")
if [ "$tag" = "$pinned_tag" ]; then
  exit 3
fi
version=${tag#v}

src=$(bash "$tools/source.sh" "$tag")
deps=$(bash "$tools/deps-hash.sh" "$tag" "$(jq -r .hash <<<"$src")")
amd64=$(bash "$tools/manifest.sh" "$tag" latest-linux.yml "orca-ide_${version}_amd64.deb")
arm64=$(bash "$tools/manifest.sh" "$tag" latest-linux-arm64.yml "orca-ide_${version}_arm64.deb")
mac_arm64=$(bash "$tools/manifest.sh" "$tag" latest-mac.yml "Orca-${version}-arm64-mac.zip")
mac_x64=$(bash "$tools/manifest.sh" "$tag" latest-mac.yml "Orca-${version}-mac.zip")

next=$(jq \
  --arg version "$version" --arg tag "$tag" \
  --argjson src "$src" --arg deps "$deps" \
  --argjson amd64 "$amd64" --argjson arm64 "$arm64" \
  --argjson mac_arm64 "$mac_arm64" --argjson mac_x64 "$mac_x64" \
  -f "$here/bump/sources.jq" "$sources")
printf '%s\n' "$next" >"$sources"
