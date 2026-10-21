#!/usr/bin/env bats
# scripts/build/linux-install.sh (nix/linux T2): the install phase of the
# Linux source build, sourced by stdenv under its `set -eu -o pipefail`.
# wrapProgram, patchShebangs, gappsWrapperArgsHook and runHook are stubs;
# the unpacked app is a small fake.

bats_require_minimum_version 1.5.0

setup() {
  script="$BATS_TEST_DIRNAME/../../../../scripts/build/linux-install.sh"
  log=$BATS_TEST_TMPDIR/log
  cd "$BATS_TEST_TMPDIR" || exit 1
  for unpacked in dist/linux-unpacked dist/linux-arm64-unpacked; do
    mkdir -p "$unpacked/resources/bin" "$unpacked/resources/node_modules/qrcode/bin" \
      "$unpacked/resources/relay/wsl"
    echo "$unpacked" >"$unpacked/orca-ide"
    touch "$unpacked/chrome-sandbox" "$unpacked/resources/app.asar" "$unpacked/resources/default_app.asar"
    printf '#!/usr/bin/env bash\n' >"$unpacked/resources/bin/orca-ide"
    printf '#!/nix/store/0abc-nodejs-24.21.0/bin/node\nrequire("x")\n' \
      >"$unpacked/resources/node_modules/qrcode/bin/qrcode"
    printf '#!/usr/bin/env node\n' >"$unpacked/resources/relay/wsl/relay.js"
  done
  export out=$BATS_TEST_TMPDIR/out
  export ORCA_ARCH=x64
  export ORCA_TEMPLATE=/store/orcad-template
  export ORCA_PATH=/store/agent/bin
}

runHook() {
  echo "runHook $*" >>"$log"
}

wrapProgram() {
  echo "wrapProgram $*" >>"$log"
}

patchShebangs() {
  echo "patchShebangs $*" >>"$log"
}

gappsWrapperArgsHook() {
  # shellcheck disable=SC2034 # read by the script.
  gappsWrapperArgs=(--prefix XDG_DATA_DIRS : /store/schemas)
}

# Its own shell: bats runs a function inside `||`, where errexit is off.
install_phase() {
  export -f runHook wrapProgram patchShebangs gappsWrapperArgsHook
  export log
  bash -eu -o pipefail -c '. "$1"' _ "$script"
}

@test "the unpacked app lands under libexec, without Electron's default app" {
  run install_phase
  [ "$status" -eq 0 ]
  app=$out/libexec/orca-ide
  [ "$(cat "$app/orca-ide")" = dist/linux-unpacked ]
  [ -e "$app/resources/app.asar" ]
  [ ! -e "$app/resources/default_app.asar" ]
  [ -e "$app/chrome-sandbox" ]
}

@test "arm64 installs electron-builder's arm64 directory" {
  export ORCA_ARCH=arm64
  run install_phase
  [ "$status" -eq 0 ]
  [ "$(cat "$out/libexec/orca-ide/orca-ide")" = dist/linux-arm64-unpacked ]
}

@test "node_modules scripts get upstream's interpreter line back; others are untouched" {
  run install_phase
  [ "$status" -eq 0 ]
  resources=$out/libexec/orca-ide/resources
  [ "$(head -1 "$resources/node_modules/qrcode/bin/qrcode")" = "#!/usr/bin/env node" ]
  [ "$(sed -n 2p "$resources/node_modules/qrcode/bin/qrcode")" = 'require("x")' ]
  [ "$(head -1 "$resources/relay/wsl/relay.js")" = "#!/usr/bin/env node" ]
}

@test "the orcad template is the piece, linked" {
  run install_phase
  [ "$status" -eq 0 ]
  [ "$(readlink "$out/libexec/orca-ide/resources/orcad-template")" = /store/orcad-template ]
}

@test "Electron is wrapped with the GApps environment, its sandbox and the agents' PATH" {
  run install_phase
  [ "$status" -eq 0 ]
  app=$out/libexec/orca-ide
  grep -qxF "wrapProgram $app/orca-ide --prefix XDG_DATA_DIRS : /store/schemas --set CHROME_DEVEL_SANDBOX $app/chrome-sandbox --prefix PATH : /store/agent/bin" "$log"
}

@test "bin/orca-ide is upstream's launcher, the only shebang patched" {
  run install_phase
  [ "$status" -eq 0 ]
  app=$out/libexec/orca-ide
  [ "$(readlink "$out/bin/orca-ide")" = "$app/resources/bin/orca-ide" ]
  [ "$(grep -c patchShebangs "$log")" -eq 1 ]
  grep -qxF "patchShebangs $app/resources/bin/orca-ide" "$log"
}

@test "pre and post install hooks run around it" {
  run install_phase
  [ "$status" -eq 0 ]
  [ "$(head -1 "$log")" = "runHook preInstall" ]
  [ "$(tail -1 "$log")" = "runHook postInstall" ]
}

@test "without the template piece the phase fails" {
  unset ORCA_TEMPLATE
  run install_phase
  [ "$status" -ne 0 ]
}
