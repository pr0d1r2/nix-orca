#!/usr/bin/env bash
# The release's text files (`release` T1, root §I release): DIR holds one
# symlink per system, named for it, to that system's orca-ide; this writes
# DIR/notes.md (scripts/release-notes.sh) and each system's CycloneDX and
# SPDX SBOMs (scripts/sbom.sh) into DIR.
# Usage: release-files.sh DIR
# Env: RELEASE_TOOLS names the directory holding release-notes.sh and
# sbom.sh (default scripts/); PREVIOUS_<system, - as _> a previous release's
# path for the closure diff; the notes' own env passes through.
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "usage: release-files.sh DIR" >&2
  exit 2
fi
dir=$1
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
tools=${RELEASE_TOOLS:-$here/..}

systems=()
for link in "$dir"/*-linux "$dir"/*-darwin; do
  [ -L "$link" ] || continue
  system=$(basename "$link")
  path=$(readlink "$link")
  previous_var=PREVIOUS_${system//-/_}
  systems+=("$system=$path${!previous_var:+:${!previous_var}}")
  bash "$tools/sbom.sh" "$system" "$path" "$dir"
done
if [ "${#systems[@]}" -eq 0 ]; then
  echo "release-files: $dir links no system's orca-ide" >&2
  exit 1
fi
bash "$tools/release-notes.sh" "${systems[@]}" >"$dir/notes.md"
