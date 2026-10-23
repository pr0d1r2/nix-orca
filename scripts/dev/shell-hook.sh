#!/usr/bin/env bash
# The dev shell's entry hook (dev V1, D34), run by dev/flake.nix's
# shellHook. Hooks on every entry: git points at the tracked .githooks/
# pklith seeds, which run hk; not before hk.pkl exists, so no empty config
# ever gates a commit (paradigm/V22). Without hk it says so and never
# falls back to another hook runner (paradigm/V23). On darwin, Linux work
# goes to nix-builder.local: say so when nix does not list it as a
# builder. Fleet tools with no build on SYSTEM are named: gates that need
# them fail, never skip. It never fails the shell's entry.
# Usage: shell-hook.sh SYSTEM [ABSENT-TOOL...]
set -uo pipefail

if [ "$#" -lt 1 ]; then
  echo "usage: shell-hook.sh SYSTEM [ABSENT-TOOL...]" >&2
  exit 2
fi
system=$1
shift

root=$(git rev-parse --show-toplevel 2>/dev/null || true)
if [ -n "$root" ] && [ -f "$root/hk.pkl" ] && [ -d "$root/.githooks" ]; then
  if command -v hk >/dev/null; then
    [ "$(git -C "$root" config --local core.hooksPath)" = .githooks ] ||
      git -C "$root" config --local core.hooksPath .githooks
  else
    echo "nix-orca(shell): no hk on PATH, git hooks NOT installed" >&2
  fi
fi

case "$system" in
*-darwin)
  case "$(nix config show builders 2>/dev/null)" in
  *nix-builder.local*) ;;
  *) echo "nix-orca(shell): nix-builder.local is not a nix builder here -- Linux builds will not run from this machine" >&2 ;;
  esac
  ;;
esac

if [ "$#" -gt 0 ]; then
  absent=$(printf '%s, ' "$@")
  echo "nix-orca(shell): no $system build of: ${absent%, } -- gates that need them FAIL here" >&2
fi
exit 0
