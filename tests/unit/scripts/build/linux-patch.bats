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
  export ORCA_COMMIT=49109f362f057cd2dc3d81cd378cb84d140c3dc5
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
  [ "$(grep -c "// nix:" config/electron-builder.config.cjs)" -eq 4 ]
  run ! grep -q "ensureWaylandClipboard(context.arch)" config/electron-builder.config.cjs
  run ! grep -q "placeAppImageNodeRuntime(" config/electron-builder.config.cjs
  run ! grep -q "verifyLinuxGlibcFloor(" config/electron-builder.config.cjs
}

@test "node_modules stays out of app.asar, right after the src exclusion" {
  run patch_phase
  [ "$status" -eq 0 ]
  grep -A2 -F "'!src{,/**/*}'," config/electron-builder.config.cjs | tail -1 | grep -qF "'!node_modules{,/**/*}',"
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
