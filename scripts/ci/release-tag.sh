#!/usr/bin/env bash
# The tag a release run publishes, or none (`release` §C, rounds 7 and 8;
# root V4). Tags are `v<upstream>-nix.<n>`.
# - push (a merge to main): `-nix.1` when the pinned version has no tag
#   yet; otherwise exit 3, nothing to release, so a merge that keeps the
#   version, or a rerun, publishes nothing.
# - workflow_dispatch (the owner's packaging fix): the highest `-nix.<n>`
#   of the version plus one, or `-nix.1`.
# Usage: release-tag.sh push|workflow_dispatch
# Env: GIT names git (default git); SOURCES the pinned file (default
# nix/sources.json).
set -euo pipefail

if [ "$#" -ne 1 ] || { [ "$1" != push ] && [ "$1" != workflow_dispatch ]; }; then
  echo "usage: release-tag.sh push|workflow_dispatch" >&2
  exit 2
fi
event=$1
git=${GIT:-git}
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
sources=${SOURCES:-$here/../../nix/sources.json}

version=$(jq -r .version "$sources")
last=$("$git" tag --list "v$version-nix.*" |
  sed -n "s/^v$version-nix\.\([0-9][0-9]*\)$/\1/p" | sort -n | tail -n 1)

if [ -n "$last" ] && [ "$event" = push ]; then
  exit 3
fi
echo "v$version-nix.$((${last:-0} + 1))"
