#!/usr/bin/env bats
# scripts/check/linux-app.sh (nix/linux T2, T3): checks on the Linux orca-ide.
# Each mode compares one fact with its pinned value and writes $out on a
# pass, so a check derivation is one call. The package is a small fake.

bats_require_minimum_version 1.5.0

setup() {
  check="$BATS_TEST_DIRNAME/../../../../scripts/check/linux-app.sh"
  cd "$BATS_TEST_TMPDIR" || exit 1
  mkdir -p pkg/bin src
  cat >pkg/bin/orca-ide <<'STUB'
#!/usr/bin/env bash
[ "$1" = --version ] && echo "${STUB_VERSION:-1.4.232}"
STUB
  chmod +x pkg/bin/orca-ide
  printf '{"devDependencies": {"electron": "43.7.8"}}\n' >src/package.json
  resources=pkg/libexec/orca-ide/resources
  mkdir -p "$resources/node_modules/sherpa-onnx-linux-x64" "$resources/orcad-template" \
    "$resources/ripgrep/linux-x64" "$resources/ripgrep/win32-x64" pin/bin
  cat >pkg/libexec/orca-ide/orca-ide <<'STUB'
#!/usr/bin/env bash
[ "$ELECTRON_RUN_AS_NODE" = 1 ] && [ "$1" = -e ] || exit 9
case "$2" in
*sherpa*|*require\(process.argv*) echo "${STUB_SHERPA:-1.12.38}" ;;
*command\ -v*) [ -n "${PATH:-}" ] && exit 8; printf '%s\n' ${STUB_MISSING:-} ;;
esac
STUB
  touch "$resources/node_modules/sherpa-onnx-linux-x64/sherpa-onnx.node"
  echo linux >"$resources/ripgrep/linux-x64/rg"
  echo windows >"$resources/ripgrep/win32-x64/rg.exe"
  jq -n --arg l "$(sha256sum <"$resources/ripgrep/linux-x64/rg" | cut -d' ' -f1)" \
    --arg w "$(sha256sum <"$resources/ripgrep/win32-x64/rg.exe" | cut -d' ' -f1)" \
    '{commonSha256: {"ripgrep/linux-x64/rg": $l, "ripgrep/win32-x64/rg.exe": $w, "orcad.js": "00"}}' \
    >"$resources/orcad-template/orcad-template.json"
  cat >pin/bin/agent-browser <<'STUB'
#!/usr/bin/env bash
echo "agent-browser ${STUB_BROWSER:-0.27.0}"
STUB
  chmod +x pkg/libexec/orca-ide/orca-ide pin/bin/agent-browser
  ln -s "$PWD/pin/bin/agent-browser" "$resources/agent-browser-linux-x64"
  export out=$BATS_TEST_TMPDIR/out
}

@test "version: bin/orca-ide --version prints the pinned version" {
  run --separate-stderr "$check" version pkg 1.4.232
  [ "$status" -eq 0 ]
  [ -e "$out" ]
}

@test "version: another version fails and names V4" {
  export STUB_VERSION=1.4.230
  run --separate-stderr "$check" version pkg 1.4.232
  [ "$status" -eq 1 ]
  [ "$stderr" = "linux-app: bin/orca-ide --version printed 1.4.230, want 1.4.232 (nix/linux V4)" ]
  [ ! -e "$out" ]
}

@test "electron-major: upstream's package.json against the pin's Electron" {
  run --separate-stderr "$check" electron-major src 43.7.11
  [ "$status" -eq 0 ]
  [ -e "$out" ]
}

@test "electron-major: another major fails with the guard's message" {
  run --separate-stderr "$check" electron-major src 44.0.0
  [ "$status" -eq 1 ]
  [[ "$stderr" == *"orca-ide-bin"* ]]
  [ ! -e "$out" ]
}

@test "sherpa-load: the addon loads in Electron's node mode and reports the pin's version" {
  run --separate-stderr "$check" sherpa-load pkg 1.12.38
  [ "$status" -eq 0 ]
  [ -e "$out" ]
}

@test "sherpa-load: another version fails and names V3" {
  export STUB_SHERPA=1.12.37
  run --separate-stderr "$check" sherpa-load pkg 1.12.38
  [ "$status" -eq 1 ]
  [ "$stderr" = "linux-app: sherpa-onnx addon reports 1.12.37, want the pin's 1.12.38 (nix/linux V3)" ]
}

@test "sherpa-load: a bundled library left beside the addon fails" {
  touch pkg/libexec/orca-ide/resources/node_modules/sherpa-onnx-linux-x64/libonnxruntime.so
  run --separate-stderr "$check" sherpa-load pkg 1.12.38
  [ "$status" -eq 1 ]
  [[ "$stderr" == *"libonnxruntime.so"*"(nix/linux V3)" ]]
}

@test "ripgrep: every rg the template manifest names is there, with its sha256" {
  run --separate-stderr "$check" ripgrep pkg -
  [ "$status" -eq 0 ]
  [ -e "$out" ]
}

@test "ripgrep: an rg that differs from the manifest fails and names V2" {
  echo swapped >pkg/libexec/orca-ide/resources/ripgrep/linux-x64/rg
  run --separate-stderr "$check" ripgrep pkg -
  [ "$status" -eq 1 ]
  [ "$stderr" = "linux-app: ripgrep/linux-x64/rg differs from orcad-template.json; remote deploys would refuse it (nix/linux V2)" ]
}

@test "ripgrep: a missing rg fails" {
  rm pkg/libexec/orca-ide/resources/ripgrep/win32-x64/rg.exe
  run --separate-stderr "$check" ripgrep pkg -
  [ "$status" -eq 1 ]
  [[ "$stderr" == *"ripgrep/win32-x64/rg.exe"* ]]
}

@test "agent-browser: the pin's binary at the pin's version" {
  run --separate-stderr "$check" agent-browser pkg 0.27.0
  [ "$status" -eq 0 ]
  [ -e "$out" ]
}

@test "agent-browser: upstream's kept binary is reported" {
  rm pkg/libexec/orca-ide/resources/agent-browser-linux-x64
  echo bundled >pkg/libexec/orca-ide/resources/agent-browser-linux-x64
  run --separate-stderr "$check" agent-browser pkg 0.27.0
  [ "$status" -eq 1 ]
  [ "$stderr" = "linux-app: agent-browser-linux-x64 is upstream's, not the pin's 0.27.0; the versions differ (D24)" ]
}

@test "runtime-commands: each command resolves with an empty PATH" {
  run --separate-stderr "$check" runtime-commands pkg "git ps xdg-open"
  [ "$status" -eq 0 ]
  [ -e "$out" ]
}

@test "runtime-commands: a missing command fails and names V8" {
  export STUB_MISSING="xdg-open Xvfb"
  run --separate-stderr "$check" runtime-commands pkg "git xdg-open Xvfb"
  [ "$status" -eq 1 ]
  [ "$stderr" = "linux-app: not on the wrapper's PATH: xdg-open Xvfb (nix/linux V8)" ]
}

@test "updater-off: a package type Orca reports as unusable" {
  echo nix >pkg/libexec/orca-ide/resources/package-type
  run --separate-stderr "$check" updater-off pkg -
  [ "$status" -eq 0 ]
}

@test "updater-off: deb, rpm or AppImage fail and name V9" {
  for type in deb rpm AppImage; do
    echo "$type" >pkg/libexec/orca-ide/resources/package-type
    run --separate-stderr "$check" updater-off pkg -
    [ "$status" -eq 1 ]
    [ "$stderr" = "linux-app: package-type is $type, which Orca's updater uses (nix/linux V9)" ]
  done
}

@test "without out set, a pass writes nothing" {
  unset out
  run --separate-stderr "$check" version pkg 1.4.232
  [ "$status" -eq 0 ]
}

@test "an unknown mode or wrong arguments are a usage error, exit 2" {
  run --separate-stderr "$check" colour pkg 1
  [ "$status" -eq 2 ]
  [ "$stderr" = "usage: linux-app.sh version|electron-major|sherpa-load|ripgrep|agent-browser|runtime-commands|updater-off PATH EXPECTED" ]
  run --separate-stderr "$check" version pkg
  [ "$status" -eq 2 ]
}
