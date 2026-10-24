#!/usr/bin/env bash
# Patch phase of the Linux orca-ide (nix/linux T2), sourced by stdenv from
# the unpacked tag: substituteInPlace is stdenv's, and --replace-fail stops
# the build when upstream changes a line this relies on. Sourced, so it
# sets no shell options.
# Env: ORCA_COMMIT (the tag's commit, nix/sources.json), ORCA_BASH and
# ORCA_PS (the store's bash and ps), ORCA_COREUTILS (its bin directory).

# shellcheck disable=SC2154 # set by the derivation.
: "${ORCA_COMMIT:?}" "${ORCA_BASH:?}" "${ORCA_PS:?}" "${ORCA_COREUTILS:?}"

# The skills an Orca build installs pin to its source commit, which upstream
# reads from git; the tag's commit is in nix/sources.json (round 9).
substituteInPlace config/scripts/build-source-commit.mjs \
  --replace-fail "execFileSync('git', ['rev-parse', 'HEAD'], { encoding: 'utf8' }).trim()" "'$ORCA_COMMIT'"

config=config/electron-builder.config.cjs
# Orca Mobile is opt-in (root T18): without its web bundle the packaging
# check for it goes; upstream's app treats a missing bundle as an install
# without Orca Mobile.
if [ "${ORCA_MOBILE:-}" != 1 ]; then
  substituteInPlace "$config" \
    --replace-fail "    assertMobileWebBundleBuilt(mobileWebBundleDir)" \
    "    // nix: Orca Mobile is opt-in; no bundle unless mobile = true"
fi
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

# Paths NixOS does not have (V8): orca.yaml hooks, the PID-1 reaper of
# `orca serve`, the tmux attachment probe.
substituteInPlace src/main/hooks.ts \
  --replace-fail "  return '/bin/bash'" "  return '$ORCA_BASH'"
substituteInPlace src/cli/runtime/serve-pid1-init-reaper.ts \
  --replace-fail "const BASH_CANDIDATES = ['/bin/bash'," "const BASH_CANDIDATES = ['$ORCA_BASH', '/bin/bash',"
# The launcher resolves its own symlinks with dirname and readlink; a
# systemd unit's PATH may hold neither.
# shellcheck disable=SC2016 # the launcher's own shell text, literal.
substituteInPlace resources/linux/bin/orca-ide \
  --replace-fail '$(dirname "$SOURCE")' '$('"$ORCA_COREUTILS"'/dirname "$SOURCE")' \
  --replace-fail '$(readlink "$SOURCE")' '$('"$ORCA_COREUTILS"'/readlink "$SOURCE")'
substituteInPlace src/shared/tmux-host-attachment-probe.ts \
  --replace-fail "    program: '/bin/ps'," "    program: '$ORCA_PS',"

# serve binds every interface; ORCA_SERVE_BIND_HOST pins it to one, through
# the runtime's own pinnedBindHost, which pairing never widens. The NixOS
# service sets it to loopback (nix/modules T2). Upstream: stablyai/orca#31387.
substituteInPlace src/main/startup/main-process-runtime-launch.ts \
  --replace-fail "    exposeNetworkByDefault: Boolean(serveOptions) || isE2E," \
  "    exposeNetworkByDefault: Boolean(serveOptions) || isE2E,
    ...(serveOptions && process.env.ORCA_SERVE_BIND_HOST ? { pinnedBindHost: process.env.ORCA_SERVE_BIND_HOST } : {}),"
