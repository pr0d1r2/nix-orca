#!/usr/bin/env bash
# The release notes, markdown on stdout (scripts T3, root §I release). Text
# only: the release attaches no binaries (V4, D13); a consumer fetches each
# store path from the cache, or builds it. Per system: store path, NAR hash
# and size, closure size, nixpkgs rev, commit, closure diff (D14), vulnix
# findings and Electron lag, both report-only (D15), and the --rebuild
# result (D30). The SBOM files (D29) and attestations travel as release
# files that CI writes.
# Usage: release-notes.sh SYSTEM=PATH[:PREVIOUS]...
# Env: NIX, NVD, VULNIX, GIT name the tools; FLAKE_LOCK the lock (default
# flake.lock at the repository root); ORCA_VERSION the upstream version;
# REBUILD_<system, - as _> each system's --rebuild result; ELECTRON_UPSTREAM
# and ELECTRON_PIN the Electron versions.
set -euo pipefail

if [ "$#" -lt 1 ]; then
  echo "usage: release-notes.sh SYSTEM=PATH[:PREVIOUS]..." >&2
  exit 2
fi
nix=${NIX:-nix}
nvd=${NVD:-nvd}
vulnix=${VULNIX:-vulnix}
git=${GIT:-git}
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
lock=${FLAKE_LOCK:-$here/../flake.lock}

nixpkgs=$(jq -r .nodes.nixpkgs.locked.rev "$lock")
commit=$("$git" rev-parse HEAD)

echo "# orca-ide ${ORCA_VERSION:-}"
echo
echo "This release attaches no binaries. Linux paths come from https://pr0d1r2.cachix.org or build from source; darwin builds from upstream's zip."
if [ -n "${ELECTRON_UPSTREAM:-}" ]; then
  echo
  echo "Electron: upstream ${ELECTRON_UPSTREAM}, pin ${ELECTRON_PIN:-unknown} (report-only, D15)"
fi

for arg in "$@"; do
  system=${arg%%=*}
  paths=${arg#*=}
  path=${paths%%:*}
  previous=
  if [ "$paths" != "$path" ]; then
    previous=${paths#*:}
  fi
  info=$("$nix" path-info --json --json-format 1 "$path")
  closure=$("$nix" path-info -S "$path" | awk '{ print $2 }')
  rebuild_var=REBUILD_${system//-/_}

  echo
  echo "## $system"
  echo
  case "$system" in
  *-darwin) echo "upstream's signed Orca.app; not in the binary cache, nix fetches the zip from GitHub (D41)" && echo ;;
  esac
  echo "- store path: \`$path\`"
  echo "- NAR hash: \`$(jq -r '.[].narHash' <<<"$info")\`, NAR size: $(jq -r '.[].narSize' <<<"$info") bytes"
  echo "- closure size: $closure bytes"
  echo "- nixpkgs: \`$nixpkgs\`"
  echo "- commit: \`$commit\`"
  echo "- \`--rebuild\`: ${!rebuild_var:-not run}"

  if [ -n "$previous" ]; then
    echo "- closure diff against \`$previous\`:"
    echo
    echo '```'
    "$nvd" diff "$previous" "$path"
    echo '```'
  else
    echo "- closure diff: first release, nothing to compare"
  fi

  # vulnix exits non-zero when it finds something; report-only (D15).
  findings=$("$vulnix" --json "$path" || true)
  count=$(jq 'length' <<<"${findings:-[]}")
  echo "- vulnix (report-only): $count finding$([ "$count" = 1 ] || echo s)"
  jq -r '.[] | . as $f | "  - \(.name): " + ([.affected_by[] | "\(.) (CVSS \($f.cvssv3_basescore[.] // "?"))"] | join(", "))' <<<"${findings:-[]}"
done
