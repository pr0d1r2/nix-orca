#!/usr/bin/env bash
# The orcad template manifest with the Linux rg hashes rewritten (nix/linux
# §C, root T18): every target's ripgrep/linux-x64/rg and
# ripgrep/linux-arm64/rg get the sha256 of the pin's builds, so the relay's
# check of what it uploads still holds. darwin, win32 and every other entry
# stay as upstream wrote them. Prints the manifest on stdout.
# Usage: template-ripgrep.sh MANIFEST RG-LINUX-X64 RG-LINUX-ARM64
set -euo pipefail

if [ "$#" -ne 3 ]; then
  echo "usage: template-ripgrep.sh MANIFEST RG-LINUX-X64 RG-LINUX-ARM64" >&2
  exit 2
fi
manifest=$1 x64=$2 arm64=$3
fail() {
  echo "template-ripgrep: $*" >&2
  exit 1
}

for file in "$manifest" "$x64" "$arm64"; do
  [ -f "$file" ] || fail "no file $file"
done
for key in ripgrep/linux-x64/rg ripgrep/linux-arm64/rg; do
  jq -e --arg k "$key" '[.targets[].files | has($k)] | any' "$manifest" >/dev/null ||
    fail "$manifest names no $key"
done

jq --arg x64 "$(sha256sum <"$x64" | cut -d' ' -f1)" \
  --arg arm64 "$(sha256sum <"$arm64" | cut -d' ' -f1)" '
  .targets |= map_values(
    if .files["ripgrep/linux-x64/rg"] then .files["ripgrep/linux-x64/rg"] = $x64 else . end
    | if .files["ripgrep/linux-arm64/rg"] then .files["ripgrep/linux-arm64/rg"] = $arm64 else . end
  )' "$manifest"
