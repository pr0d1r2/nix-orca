#!/usr/bin/env bash
# Install phase of the darwin orca-ide (nix/darwin T1), sourced by stdenv
# from the unpacked zip's directory: makeWrapper and runHook are stdenv's
# functions there. Sourced, so it sets no shell options: they would leak
# into stdenv's own phases.
# Env: out (the store path), ORCA_PATH (runtime PATH prefix),
# ORCA_TELEMETRY (`false` sets ORCA_TELEMETRY_DISABLED=1, D27).

# shellcheck disable=SC2154 # out: set by stdenv for every phase.
: "${out:?}" "${ORCA_PATH:?}" "${ORCA_TELEMETRY:?}"

runHook preInstall

# Upstream's signed bundle, moved and never touched (D38).
mkdir -p "$out/Applications" "$out/bin"
mv Orca.app "$out/Applications/"

# bin/orca-ide is upstream's CLI launcher, renamed (D5).
wrap=(--prefix PATH : "$ORCA_PATH")
if [ "$ORCA_TELEMETRY" = false ]; then
  wrap+=(--set ORCA_TELEMETRY_DISABLED 1)
fi
makeWrapper "$out/Applications/Orca.app/Contents/Resources/bin/orca" "$out/bin/orca-ide" "${wrap[@]}"

runHook postInstall
