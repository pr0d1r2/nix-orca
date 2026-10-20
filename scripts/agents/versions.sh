#!/usr/bin/env bash
# Each agent answers `--version` (nix/agents V3): every ID=COMMAND runs
# `COMMAND --version` with stdin closed and a fresh empty HOME, so no key,
# login or config is found; the nix sandbox the check runs in keeps it
# offline. Every failure is a line on stderr, then exit 1; a pass writes
# $out when it is set.
# Usage: versions.sh ID=COMMAND...
set -euo pipefail

if [ "$#" -lt 1 ]; then
  echo "usage: versions.sh ID=COMMAND..." >&2
  exit 2
fi

status=0
for pair in "$@"; do
  id=${pair%%=*}
  cmd=${pair#*=}
  home=$(mktemp -d)
  rc=0
  output=$(cd "$home" && HOME=$home "$cmd" --version </dev/null 2>&1) || rc=$?
  rm -rf "$home"
  if [ "$rc" -ne 0 ]; then
    echo "versions: $id: \`$cmd --version\` exited $rc: ${output%%$'\n'*} (nix/agents V3)" >&2
    status=1
  fi
done

if [ "$status" -eq 0 ] && [ -n "${out:-}" ]; then
  : >"$out"
fi
exit "$status"
