#!/usr/bin/env bash
# Install phase of a fixed-output piece cut from upstream's .deb (nix/bin
# T2, D33, D38), sourced by stdenv with no unpack phase: the subtree
# ORCA_PIECE names, copied as it is, so the piece is byte for byte
# upstream's and keeps its store path while that subtree does not change.
# runHook is stdenv's. Sourced, so it sets no shell options.
# Env: src (the .deb), out, ORCA_PIECE (a path inside the .deb).

# shellcheck disable=SC2154 # set by stdenv and the derivation.
: "${src:?}" "${out:?}" "${ORCA_PIECE:?}"

runHook preInstall

dpkg-deb -x "$src" deb
cp -r "deb/$ORCA_PIECE" "$out"

runHook postInstall
