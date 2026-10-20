#!/usr/bin/env bash
# Did sherpa-onnx's C API header change between the version upstream Orca
# bundles and the pin's (D25)? The Linux package loads upstream's addon
# against the pin's libraries only while sherpa-onnx/c-api/c-api.h is
# unchanged; otherwise it keeps the bundled ones.
# Exit 0: unchanged; exit 3: changed.
# Usage: sherpa-diff.sh BUNDLED-VERSION PIN-VERSION
# Env: GH names gh (default gh).
set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "usage: sherpa-diff.sh BUNDLED-VERSION PIN-VERSION" >&2
  exit 2
fi
bundled=$1 pin=$2
gh=${GH:-gh}

if [ "$bundled" != "$pin" ] &&
  "$gh" api "repos/k2-fsa/sherpa-onnx/compare/v$bundled...v$pin" |
  jq -e '[.files[].filename] | index("sherpa-onnx/c-api/c-api.h")' >/dev/null; then
  echo "sherpa-onnx c-api.h changed from $bundled to $pin; keep the bundled libraries (D25)"
  exit 3
fi
echo "sherpa-onnx c-api.h unchanged from $bundled to $pin"
