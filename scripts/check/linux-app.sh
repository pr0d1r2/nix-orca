#!/usr/bin/env bash
# Checks on the Linux orca-ide (nix/linux T2, T3). Each mode compares one
# fact with its pinned value; a pass writes $out when it is set, so a check
# derivation is a single call. A failure names the invariant.
# Usage: linux-app.sh MODE PATH EXPECTED
#   version:        PATH is the package; EXPECTED the upstream version (V4)
#   electron-major: PATH is upstream's source; EXPECTED the pin's Electron
#                   version (D21, scripts/check/electron-major.sh)
#   sherpa-load:    PATH is the package; EXPECTED the pin's sherpa-onnx
#                   version, which the addon reports (V3)
#   ripgrep:        PATH is the package; EXPECTED is unused (-): each rg
#                   the orcad template's manifest names matches it (V2)
#   agent-browser:  PATH is the package; EXPECTED the pin's agent-browser
#                   version (D24)
#   runtime-commands: PATH is the package; EXPECTED the commands, space
#                   separated, that must resolve with an empty PATH (V8)
#   updater-off:    PATH is the package; EXPECTED is unused (-):
#                   package-type is one Orca's updater refuses (V9)
# Env: ELECTRON_MAJOR_CHECK names the guard (default electron-major.sh
# beside this script; a store copy of this script stands alone); out is
# written on a pass.
set -euo pipefail

usage() {
  echo "usage: linux-app.sh version|electron-major|sherpa-load|ripgrep|agent-browser|runtime-commands|updater-off PATH EXPECTED" >&2
  exit 2
}
if [ "$#" -ne 3 ]; then
  usage
fi
mode=$1 path=$2 want=$3
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
guard=${ELECTRON_MAJOR_CHECK:-$here/electron-major.sh}
app=$path/libexec/orca-ide
resources=$app/resources

case "$mode" in
version)
  got=$("$path/bin/orca-ide" --version)
  if [ "$got" != "$want" ]; then
    echo "linux-app: bin/orca-ide --version printed $got, want $want (nix/linux V4)" >&2
    exit 1
  fi
  ;;
electron-major)
  bash "$guard" "$path/package.json" "$want"
  ;;
sherpa-load)
  addon=$(echo "$resources"/node_modules/sherpa-onnx-linux-*)
  bundled=$(cd "$addon" && find . -name '*.so*' | sort | tr '\n' ' ')
  if [ -n "$bundled" ]; then
    echo "linux-app: bundled ${bundled% } beside the sherpa-onnx addon (nix/linux V3)" >&2
    exit 1
  fi
  # shellcheck disable=SC2016 # JavaScript, expanded by node.
  got=$(ELECTRON_RUN_AS_NODE=1 "$app/orca-ide" -e 'console.log(require(process.argv[1]).version)' "$addon")
  if [ "$got" != "$want" ]; then
    echo "linux-app: sherpa-onnx addon reports $got, want the pin's $want (nix/linux V3)" >&2
    exit 1
  fi
  ;;
ripgrep)
  manifest=$resources/orcad-template/orcad-template.json
  while read -r file sum; do
    if [ ! -e "$resources/$file" ] || [ "$(sha256sum <"$resources/$file" | cut -d' ' -f1)" != "$sum" ]; then
      echo "linux-app: $file differs from orcad-template.json; remote deploys would refuse it (nix/linux V2)" >&2
      exit 1
    fi
  done < <(jq -r '[.. | objects | to_entries[] | select(.key | test("^ripgrep/[^/]+/rg(\\.exe)?$")) | "\(.key) \(.value)"] | unique | .[]' "$manifest")
  ;;
agent-browser)
  binary=$(echo "$resources"/agent-browser-linux-*)
  case "$(realpath "$binary")" in
  "$(realpath "$path")"/*)
    echo "linux-app: $(basename "$binary") is upstream's, not the pin's $want; the versions differ (D24)" >&2
    exit 1
    ;;
  esac
  got=$("$binary" --version)
  if [ "$got" != "agent-browser $want" ]; then
    echo "linux-app: $(basename "$binary") prints $got, want agent-browser $want (D24)" >&2
    exit 1
  fi
  ;;
runtime-commands)
  # An empty environment: only the wrapper's PATH counts.
  # shellcheck disable=SC2016,SC2086 # JavaScript for node; one word per command.
  missing=$(env -i HOME="${TMPDIR:-/tmp}" ELECTRON_RUN_AS_NODE=1 "$app/orca-ide" -e '
    const { execFileSync } = require("child_process")
    for (const c of process.argv.slice(1)) {
      try { execFileSync("/bin/sh", ["-c", "command -v \"$1\"", "sh", c], { stdio: "ignore" }) }
      catch { console.log(c) }
    }' $want)
  if [ -n "$missing" ]; then
    echo "linux-app: not on the wrapper's PATH: ${missing//$'\n'/ } (nix/linux V8)" >&2
    exit 1
  fi
  ;;
updater-off)
  type=$(cat "$resources/package-type")
  case "$type" in
  deb | rpm | AppImage)
    echo "linux-app: package-type is $type, which Orca's updater uses (nix/linux V9)" >&2
    exit 1
    ;;
  esac
  ;;
*)
  usage
  ;;
esac

if [ -n "${out:-}" ]; then
  : >"$out"
fi
