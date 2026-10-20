#!/usr/bin/env bash
# Release SBOMs (scripts T3, D29): CycloneDX and SPDX for a system's
# runtime closure, written as orca-ide-<system>.{cdx,spdx}.json into
# OUT-DIR for the release files. sbomnix's CSV goes to a temporary file.
# Usage: sbom.sh SYSTEM STORE-PATH OUT-DIR
# Env: SBOMNIX names sbomnix (default sbomnix).
set -euo pipefail

if [ "$#" -ne 3 ]; then
  echo "usage: sbom.sh SYSTEM STORE-PATH OUT-DIR" >&2
  exit 2
fi
system=$1 path=$2 out=$3
sbomnix=${SBOMNIX:-sbomnix}

csv=$(mktemp)
trap 'rm -f "$csv"' EXIT
"$sbomnix" "$path" \
  --cdx "$out/orca-ide-$system.cdx.json" \
  --spdx "$out/orca-ide-$system.spdx.json" \
  --csv "$csv"
