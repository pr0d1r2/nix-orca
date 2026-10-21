#!/usr/bin/env bats
# scripts/build/linux-patch.sh (nix/linux T2): the patch phase of the Linux
# source build, sourced by stdenv under its `set -eu -o pipefail`.
# substituteInPlace is a stand-in for stdenv's with --replace-fail: a
# missing pattern fails.

bats_require_minimum_version 1.5.0

setup() {
  script="$BATS_TEST_DIRNAME/../../../../scripts/build/linux-patch.sh"
  cd "$BATS_TEST_TMPDIR" || exit 1
  mkdir -p config/scripts
  cat >config/scripts/build-source-commit.mjs <<'EOF'
  try {
    commit = execFileSync('git', ['rev-parse', 'HEAD'], { encoding: 'utf8' }).trim()
  } catch (error) {
EOF
  cat >config/electron-builder.config.cjs <<'EOF'
  files: [
    '!**/.vscode/*',
    '!src{,/**/*}',
    '!out/orcad{,/**/*}',
  ],
    if (context.electronPlatformName === 'linux') {
      ensureWaylandClipboard(context.arch)
    }
      appImageNodeRuntime = await placeAppImageNodeRuntime(resourcesDir, targetArch)
      finalizePackagedWaylandClipboard(resourcesDir)
      verifyLinuxGlibcFloor(context.appOutDir, { targetArch })
EOF
  mkdir -p src/main src/shared src/cli/runtime
  printf "function getHookShell() {\n  return '/bin/bash'\n}\n" >src/main/hooks.ts
  printf "    program: '/bin/ps',\n" >src/shared/tmux-host-attachment-probe.ts
  mkdir -p resources/linux/bin
  # shellcheck disable=SC2016 # the launcher's own lines, tab-indented.
  printf '\tDIR="$(cd "$(dirname "$SOURCE")" >/dev/null 2>&1 && pwd)"\n\tSOURCE="$(readlink "$SOURCE")"\nSCRIPT_DIR="$(cd "$(dirname "$SOURCE")" >/dev/null 2>&1 && pwd)"\n' \
    >resources/linux/bin/orca-ide
  mkdir -p src/main/startup
  printf "    exposeNetworkByDefault: Boolean(serveOptions) || isE2E,\n" >src/main/startup/main-process-runtime-launch.ts
  printf "const BASH_CANDIDATES = ['/bin/bash', '/usr/bin/bash']\n" >src/cli/runtime/serve-pid1-init-reaper.ts
  export ORCA_COMMIT=49109f362f057cd2dc3d81cd378cb84d140c3dc5
  export ORCA_BASH=/store/bash/bin/bash ORCA_PS=/store/procps/bin/ps ORCA_COREUTILS=/store/coreutils/bin
}

substituteInPlace() {
  local file=$1 text
  shift
  text=$(<"$file")
  while [ "$#" -gt 0 ]; do
    [ "$1" = --replace-fail ] || return 1
    if [[ "$text" != *"$2"* ]]; then
      echo "substituteInPlace: pattern not found in $file: $2" >&2
      return 1
    fi
    text=${text//"$2"/"$3"}
    shift 3
  done
  printf '%s\n' "$text" >"$file"
}

# Its own shell: bats runs a function inside `||`, where errexit is off.
patch_phase() {
  export -f substituteInPlace
  bash -eu -o pipefail -c '. "$1"' _ "$script"
}

@test "the source commit is the tag's, not git's" {
  run patch_phase
  [ "$status" -eq 0 ]
  grep -qF "commit = '$ORCA_COMMIT'" config/scripts/build-source-commit.mjs
  run ! grep -q "rev-parse" config/scripts/build-source-commit.mjs
}

@test "packaging builds no clipboard helper, places no Node, checks no Ubuntu glibc" {
  run patch_phase
  [ "$status" -eq 0 ]
  grep -q "finalizePackagedWaylandClipboard(resourcesDir)" config/electron-builder.config.cjs
  [ "$(grep -c "// nix:" config/electron-builder.config.cjs)" -eq 5 ]
  run ! grep -q "ensureWaylandClipboard(context.arch)" config/electron-builder.config.cjs
  run ! grep -q "placeAppImageNodeRuntime(" config/electron-builder.config.cjs
  run ! grep -q "verifyLinuxGlibcFloor(" config/electron-builder.config.cjs
}

@test "node_modules stays out of app.asar, right after the src exclusion" {
  run patch_phase
  [ "$status" -eq 0 ]
  grep -A2 -F "'!src{,/**/*}'," config/electron-builder.config.cjs | tail -1 | grep -qF "'!node_modules{,/**/*}',"
}

@test "upstream's root configs stay out of app.asar" {
  run patch_phase
  [ "$status" -eq 0 ]
  grep -qF "'!{.oxfmtrc.json,.oxlintrc.json,components.json,opencode.json,orca.yaml,pnpm-workspace.yaml,vite.web.config.ts}'," config/electron-builder.config.cjs
}

@test "serve's listener can be pinned through ORCA_SERVE_BIND_HOST" {
  run patch_phase
  [ "$status" -eq 0 ]
  f=src/main/startup/main-process-runtime-launch.ts
  grep -qxF "    exposeNetworkByDefault: Boolean(serveOptions) || isE2E," "$f"
  grep -qxF "    ...(serveOptions && process.env.ORCA_SERVE_BIND_HOST ? { pinnedBindHost: process.env.ORCA_SERVE_BIND_HOST } : {})," "$f"
}

@test "the launcher runs the store's dirname and readlink, whatever PATH holds" {
  run patch_phase
  [ "$status" -eq 0 ]
  # shellcheck disable=SC2016 # the launcher's own shell text, literal.
  [ "$(grep -c '/store/coreutils/bin/dirname "$SOURCE"' resources/linux/bin/orca-ide)" -eq 2 ]
  # shellcheck disable=SC2016
  grep -qF '$(/store/coreutils/bin/readlink "$SOURCE")' resources/linux/bin/orca-ide
}

@test "hooks run the store's bash: NixOS has no /bin/bash" {
  run patch_phase
  [ "$status" -eq 0 ]
  grep -qxF "  return '/store/bash/bin/bash'" src/main/hooks.ts
  grep -qxF "const BASH_CANDIDATES = ['/store/bash/bin/bash', '/bin/bash', '/usr/bin/bash']" src/cli/runtime/serve-pid1-init-reaper.ts
}

@test "the tmux probe runs the store's ps" {
  run patch_phase
  [ "$status" -eq 0 ]
  grep -qxF "    program: '/store/procps/bin/ps'," src/shared/tmux-host-attachment-probe.ts
}

@test "an upstream line that moved fails the phase" {
  sed -i.bak 's/verifyLinuxGlibcFloor/verifyGlibcFloor/' config/electron-builder.config.cjs
  run patch_phase
  [ "$status" -ne 0 ]
  [[ "$output" == *"pattern not found"* ]]
}

@test "a moved commit line fails before the config is touched" {
  sed -i.bak 's/rev-parse/describe/' config/scripts/build-source-commit.mjs
  run patch_phase
  [ "$status" -ne 0 ]
  run ! grep -q "// nix:" config/electron-builder.config.cjs
}

@test "without ORCA_COMMIT the phase fails" {
  unset ORCA_COMMIT
  run patch_phase
  [ "$status" -ne 0 ]
}
