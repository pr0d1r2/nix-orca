#!/usr/bin/env bats
# scripts/build/linux-install.sh (nix/linux T2): the install phase of the
# Linux source build, sourced by stdenv under its `set -eu -o pipefail`.
# wrapProgram, patchShebangs, gappsWrapperArgsHook, runHook and patchelf
# are stubs; the unpacked app is a small fake.
# Each @test runs in its own subshell, so its exports are meant to be local.
# shellcheck disable=SC2030,SC2031

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
    for arch in x64 arm64; do
      echo bundled >"$unpacked/resources/agent-browser-linux-$arch"
      sherpa=$unpacked/resources/node_modules/sherpa-onnx-linux-$arch
      mkdir -p "$sherpa"
      touch "$sherpa/sherpa-onnx.node" "$sherpa/index.js" "$sherpa/libonnxruntime.so" \
        "$sherpa/libsherpa-onnx-c-api.so" "$sherpa/libsherpa-onnx-cxx-api.so"
    done
  done
  mkdir -p node_modules/agent-browser stubs
  echo '{"name": "agent-browser", "version": "0.27.0"}' >node_modules/agent-browser/package.json
  cat >stubs/patchelf <<'STUB'
#!/usr/bin/env bash
echo "patchelf $*" >>"$BATS_TEST_TMPDIR/log"
STUB
  cat >stubs/icns2png <<'STUB'
#!/usr/bin/env bash
echo "icns2png $*" >>"$BATS_TEST_TMPDIR/log"
while [ "$#" -gt 1 ]; do [ "$1" = -o ] && dir=$2; shift; done
for s in 32 64 128 256 512 1024; do echo "$s" >"$dir/icon_${s}x${s}x32.png"; done
STUB
  chmod +x stubs/patchelf stubs/icns2png
  mkdir -p resources/build
  touch resources/build/icon.icns
  export PATH="$BATS_TEST_TMPDIR/stubs:$PATH"
  export out=$BATS_TEST_TMPDIR/out
  export ORCA_ARCH=x64
  export ORCA_TEMPLATE=/store/orcad-template
  export ORCA_PATH=/store/agent/bin
  export ORCA_AGENT_BROWSER=/store/agent-browser/bin/agent-browser
  export ORCA_AGENT_BROWSER_VERSION=0.27.0
  export ORCA_SHERPA_RPATH=/store/sherpa-onnx/lib:/store/gcc-lib/lib
  export ORCA_PACKAGE_TYPE=deb ORCA_TELEMETRY=true
  export ORCA_RUNTIME_PATH=/store/git/bin:/store/procps/bin
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
  grep -qF "wrapProgram $app/orca-ide --prefix XDG_DATA_DIRS : /store/schemas --set CHROME_DEVEL_SANDBOX $app/chrome-sandbox --prefix PATH : /store/agent/bin" "$log"
}

@test "Orca's runtime commands come after the user's own PATH" {
  run install_phase
  [ "$status" -eq 0 ]
  grep "^wrapProgram " "$log" | grep -qF -- "--suffix PATH : /store/git/bin:/store/procps/bin"
}

@test "Wayland flags behind NIXOS_OZONE_WL, never in Electron's node mode" {
  run install_phase
  [ "$status" -eq 0 ]
  wrap=$(grep "^wrapProgram " "$log")
  [[ "$wrap" == *"--run "*'ELECTRON_RUN_AS_NODE'*'NIXOS_OZONE_WL'*'WAYLAND_DISPLAY'*"--ozone-platform-hint=auto"* ]]
  # shellcheck disable=SC2016 # the wrapper expands it, not this test.
  [[ "$wrap" == *'--add-flags $orca_wayland_flags'* ]]
}

@test "telemetry off sets ORCA_TELEMETRY_DISABLED on Electron" {
  export ORCA_TELEMETRY=false
  run install_phase
  [ "$status" -eq 0 ]
  grep "^wrapProgram " "$log" | grep -qF -- "--set ORCA_TELEMETRY_DISABLED 1"
}

@test "telemetry on leaves it unset" {
  run install_phase
  [ "$status" -eq 0 ]
  run ! grep -q ORCA_TELEMETRY_DISABLED "$log"
}

@test "resources/package-type says what ORCA_PACKAGE_TYPE says" {
  run install_phase
  [ "$status" -eq 0 ]
  [ "$(cat "$out/libexec/orca-ide/resources/package-type")" = deb ]
  export ORCA_PACKAGE_TYPE=nix
  rm -rf "$out"
  run install_phase
  [ "$status" -eq 0 ]
  [ "$(cat "$out/libexec/orca-ide/resources/package-type")" = nix ]
}

@test "hicolor icons at every size upstream's icns holds" {
  run install_phase
  [ "$status" -eq 0 ]
  grep -q "icns2png -x -o .* resources/build/icon.icns" "$log"
  for s in 32 64 128 256 512 1024; do
    [ "$(cat "$out/share/icons/hicolor/${s}x${s}/apps/orca-ide.png")" = "$s" ]
  done
}

@test "the desktop entry is upstream's, starting the store's Electron" {
  run install_phase
  [ "$status" -eq 0 ]
  entry=$out/share/applications/orca-ide.desktop
  grep -qxF "Exec=$out/libexec/orca-ide/orca-ide %U" "$entry"
  grep -qxF "StartupWMClass=orca" "$entry"
  grep -qxF "Icon=orca-ide" "$entry"
  grep -qxF "MimeType=text/markdown;text/csv;text/tab-separated-values;x-scheme-handler/orca;" "$entry"
}

@test "the AppArmor profile names the store's Electron and allows user namespaces" {
  run install_phase
  [ "$status" -eq 0 ]
  profile=$out/share/apparmor/orca-ide
  grep -qxF "profile \"orca-ide\" \"$out/libexec/orca-ide/.orca-ide-wrapped\" flags=(unconfined) {" "$profile"
  grep -qxF "  userns," "$profile"
  grep -qxF "abi <abi/4.0>," "$profile"
}

@test "bin/orca-ide is upstream's launcher, the only shebang patched" {
  run install_phase
  [ "$status" -eq 0 ]
  app=$out/libexec/orca-ide
  [ "$(readlink "$out/bin/orca-ide")" = "$app/resources/bin/orca-ide" ]
  [ "$(grep -c patchShebangs "$log")" -eq 1 ]
  grep -qxF "patchShebangs $app/resources/bin/orca-ide" "$log"
}

@test "agent-browser is the pin's when it is upstream's version" {
  run install_phase
  [ "$status" -eq 0 ]
  [ "$(readlink "$out/libexec/orca-ide/resources/agent-browser-linux-x64")" = /store/agent-browser/bin/agent-browser ]
}

@test "arm64 swaps the arm64 agent-browser" {
  export ORCA_ARCH=arm64
  run install_phase
  [ "$status" -eq 0 ]
  [ "$(readlink "$out/libexec/orca-ide/resources/agent-browser-linux-arm64")" = /store/agent-browser/bin/agent-browser ]
}

@test "another agent-browser version keeps upstream's and says so" {
  export ORCA_AGENT_BROWSER_VERSION=0.28.0
  run --separate-stderr install_phase
  [ "$status" -eq 0 ]
  [ "$(cat "$out/libexec/orca-ide/resources/agent-browser-linux-x64")" = bundled ]
  [[ "$stderr" == *"agent-browser: upstream bundles 0.27.0, the pin has 0.28.0; keeping upstream's"* ]]
}

@test "sherpa-onnx's addon loads the pin's libraries; the bundled ones are gone" {
  run install_phase
  [ "$status" -eq 0 ]
  sherpa=$out/libexec/orca-ide/resources/node_modules/sherpa-onnx-linux-x64
  grep -qxF "patchelf --set-rpath /store/sherpa-onnx/lib:/store/gcc-lib/lib $sherpa/sherpa-onnx.node" "$log"
  [ -z "$(cd "$sherpa" && find . -name '*.so')" ]
  [ -e "$sherpa/index.js" ]
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
