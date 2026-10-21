#!/usr/bin/env bash
# Patch phase of the Linux orca-ide (nix/linux T2), sourced by stdenv from
# the unpacked tag: substituteInPlace is stdenv's, and --replace-fail stops
# the build when upstream changes a line this relies on. Sourced, so it
# sets no shell options.
# Env: ORCA_COMMIT (the tag's commit, nix/sources.json).

# shellcheck disable=SC2154 # ORCA_COMMIT: set by the derivation.
: "${ORCA_COMMIT:?}"

# The skills an Orca build installs pin to its source commit, which upstream
# reads from git; the tag's commit is in nix/sources.json (round 9).
substituteInPlace config/scripts/build-source-commit.mjs \
  --replace-fail "execFileSync('git', ['rev-parse', 'HEAD'], { encoding: 'utf8' }).trim()" "'$ORCA_COMMIT'"

config=config/electron-builder.config.cjs
substituteInPlace "$config" \
  --replace-fail "      ensureWaylandClipboard(context.arch)" \
  "      // nix: the derivation builds the helper; upstream builds it in docker" \
  --replace-fail "      appImageNodeRuntime = await placeAppImageNodeRuntime(resourcesDir, targetArch)" \
  "      // nix: no AppImage Node; upstream downloads one, and its .deb ships none" \
  --replace-fail "      verifyLinuxGlibcFloor(context.appOutDir, { targetArch })" \
  "      // nix: binaries link the store's glibc, not Ubuntu 20.04's" \
  --replace-fail "    '!src{,/**/*}'," \
  "    '!src{,/**/*}',
    // nix: runtime deps ship as extraResources only, as in upstream's .deb
    '!node_modules{,/**/*}',"
