#!/usr/bin/env bats
# scripts/check/linux-app.sh (nix/linux T2-T5): checks on the Linux orca-ide.
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
*readdirSync*) printf '%s\n' ${STUB_ASAR:-LICENSE out package.json resources} ;;
*sherpa*|*require\(process.argv*) echo "${STUB_SHERPA:-1.12.38}" ;;
*command\ -v*)
  [ -z "${HOME_FROM_CALLER:-}" ] || exit 8
  for c in "${@:3}"; do case "$c" in missing-*) echo "$c" ;; esac; done
  ;;
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
  # hygiene: a fake ELF, patchelf reading its sidecar files, a closure.
  mkdir -p stubs
  printf '\177ELFfake' >"$resources/bin-elf"
  echo /nix/store/aaaa-glibc-2.42/lib/ld-linux-x86-64.so.2 >"$resources/bin-elf.interp"
  # shellcheck disable=SC2016 # $ORIGIN is literal in a RUNPATH.
  echo '$ORIGIN:/nix/store/bbbb-gcc-15.3.0-lib/lib' >"$resources/bin-elf.rpath"
  cat >stubs/patchelf <<'STUB'
#!/usr/bin/env bash
case "$1" in
--print-interpreter) [ -e "$2.interp" ] && cat "$2.interp" || exit 1 ;;
--print-rpath) cat "$2.rpath" 2>/dev/null ;;
esac
STUB
  chmod +x stubs/patchelf
  export PATH="$BATS_TEST_TMPDIR/stubs:$PATH"
  printf '/nix/store/aaaa-glibc-2.42\n/nix/store/bbbb-gcc-15.3.0-lib\n/nix/store/cccc-orca-ide-1.4.232\n' >closure
  printf 'glibc\ngcc\norca-ide\n' >allow
  export ORCA_CLOSURE=$BATS_TEST_TMPDIR/closure
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
  export HOME_FROM_CALLER=leaked
  run --separate-stderr "$check" runtime-commands pkg "git ps xdg-open"
  [ "$status" -eq 0 ]
  [ -e "$out" ]
}

@test "runtime-commands: a missing command fails and names V8" {
  run --separate-stderr "$check" runtime-commands pkg "git missing-xdg-open missing-Xvfb"
  [ "$status" -eq 1 ]
  [ "$stderr" = "linux-app: not on the wrapper's PATH: missing-xdg-open missing-Xvfb (nix/linux V8)" ]
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

@test "hygiene: a clean package passes" {
  run --separate-stderr "$check" hygiene pkg allow
  [ "$status" -eq 0 ]
  [ -e "$out" ]
}

@test "hygiene: upstream root configs in app.asar fail V1" {
  export STUB_ASAR="LICENSE orca.yaml out package.json resources"
  run --separate-stderr "$check" hygiene pkg allow
  [ "$status" -eq 1 ]
  [ "$stderr" = "linux-app: app.asar carries orca.yaml (nix/linux V1)" ]
}

@test "hygiene: ssh2's Windows pageant helper fails V1" {
  mkdir -p pkg/libexec/orca-ide/resources/node_modules/ssh2/util
  touch pkg/libexec/orca-ide/resources/node_modules/ssh2/util/pagent.exe
  run --separate-stderr "$check" hygiene pkg allow
  [ "$status" -eq 1 ]
  [[ "$stderr" == *"node_modules/ssh2/util/pagent.exe ships (nix/linux V1)" ]]
}

@test "hygiene: a world-writable file fails V5" {
  chmod 0666 pkg/libexec/orca-ide/resources/ripgrep/linux-x64/rg
  run --separate-stderr "$check" hygiene pkg allow
  [ "$status" -eq 1 ]
  [[ "$stderr" == *"ripgrep/linux-x64/rg is setuid, setgid or world-writable (nix/linux V5)" ]]
}

@test "hygiene: a dangling symlink fails V5" {
  ln -s nowhere pkg/libexec/orca-ide/resources/gone
  run --separate-stderr "$check" hygiene pkg allow
  [ "$status" -eq 1 ]
  [[ "$stderr" == *"resources/gone points nowhere (nix/linux V5)" ]]
}

@test "hygiene: a build host path in a file fails V5" {
  echo "rpath /home/runner/work/x/lib" >pkg/libexec/orca-ide/resources/leak.node # nolocalpath
  run --separate-stderr "$check" hygiene pkg allow
  [ "$status" -eq 1 ]
  [[ "$stderr" == *"resources/leak.node names a build host path (nix/linux V5)" ]]
}

@test "hygiene: an ELF interpreter outside the store fails V5" {
  echo /lib64/ld-linux-x86-64.so.2 >pkg/libexec/orca-ide/resources/bin-elf.interp
  run --separate-stderr "$check" hygiene pkg allow
  [ "$status" -eq 1 ]
  [[ "$stderr" == *"resources/bin-elf: interpreter /lib64/ld-linux-x86-64.so.2 is outside the store (nix/linux V5)" ]]
}

@test "hygiene: a RUNPATH entry outside the store fails V5" {
  # shellcheck disable=SC2016 # $ORIGIN is literal in a RUNPATH.
  echo '$ORIGIN:/usr/lib' >pkg/libexec/orca-ide/resources/bin-elf.rpath
  run --separate-stderr "$check" hygiene pkg allow
  [ "$status" -eq 1 ]
  [[ "$stderr" == *"resources/bin-elf: RUNPATH entry /usr/lib is outside the store (nix/linux V5)" ]]
}

@test "hygiene: a closure path off the allow list fails V5" {
  echo /nix/store/dddd-nodejs-24.21.0 >>closure
  run --separate-stderr "$check" hygiene pkg allow
  [ "$status" -eq 1 ]
  [ "$stderr" = "linux-app: nodejs-24.21.0 is in the closure, not on the allow list (nix/linux V5)" ]
}

@test "without out set, a pass writes nothing" {
  unset out
  run --separate-stderr "$check" version pkg 1.4.232
  [ "$status" -eq 0 ]
}

@test "an unknown mode or wrong arguments are a usage error, exit 2" {
  run --separate-stderr "$check" colour pkg 1
  [ "$status" -eq 2 ]
  [ "$stderr" = "usage: linux-app.sh version|electron-major|sherpa-load|ripgrep|agent-browser|runtime-commands|updater-off|hygiene PATH EXPECTED" ]
  run --separate-stderr "$check" version pkg
  [ "$status" -eq 2 ]
}
